# Story 004: Relationship WARNING tier (EC-4/5/6) + R-1 consumer-mutation regression

> **Epic**: Hero Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 2-3h (3 WARNING-tier branches + R-1 mitigation regression test + forbidden_pattern verification)
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/hero-database.md`
**Requirement**: `TR-hero-database-005`, `TR-hero-database-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007 — Hero Database — HeroData Resource + HeroDatabase Static Query Layer (MVP scope)
**ADR Decision Summary**: Relationship WARNING tier — runtime non-fatal validation at load time. EC-4 self-referencing (`hero_b_id == hero_id`) → drop offending entry + `push_warning`. EC-5 orphan `hero_b_id` (FK target missing from `_heroes`) → drop offending entry + `push_warning` listing unresolved id. EC-6 asymmetric conflict (A→B is RIVAL, B→A is SWORN_BROTHER, both `is_symmetric=true`) → load BOTH entries independently + `push_warning` (Hero DB does NOT adjudicate; Formation Bonus / Battle owns conflict resolution). Hero record itself loads normally on any of EC-4/5/6 — only specific relationship entries are dropped or flagged. Read-only contract per §Interactions: consumers MUST NOT mutate returned `HeroData` fields. R-1 mitigation regression test asserts mutation IS visible across `get_hero` calls — proving convention is sole defense (`duplicate_deep()` rejected for performance per ADR-0007 §5).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `push_warning` (Godot 3.x+ stable) writes to debugger console + GdUnit4 v6.1.2 captures via `assert_warning_pushed` if available; otherwise tests assert state (offending entry absent from `get_relationships` return). `Resource.duplicate_deep()` (Godot 4.5+) NOT used per §5 performance rejection.

**Control Manifest Rules (Foundation layer)**:
- Required: WARNING-tier drops happen at load time, NOT at query time (relationships in `_heroes[hero_id].relationships` are pre-filtered)
- Required: every WARNING emits `push_warning` listing context (hero_id + offending hero_b_id + reason)
- Required: hero record itself MUST load normally on any WARNING — only the specific relationship entry is dropped (or, for EC-6, flagged but kept)
- Forbidden: WARNING-tier escalating to FATAL (must not block load on EC-4/5/6 — that's an explicit ADR-0007 §5 design decision)
- Forbidden: `duplicate_deep()` on returned HeroData (rejected for 10× hot-path cost per ADR-0007 §5; convention is sole R-1 defense)
- Guardrail: WARNING-tier overhead negligible — O(R × M) where R = total relationship entries (~2-5 per hero × 10 heroes = ~30 entries) and M = membership check cost (Dictionary.has = O(1))

---

## Acceptance Criteria

*From ADR-0007 §5 (Validation Pipeline WARNING tier) + §Interactions (Read-only contract) + GDD AC-14, scoped to this story:*

- [ ] **AC-1** (TR-010 / GDD AC-14 — EC-4 self-reference WARNING): record with hero_id `shu_001_liu_bei` containing a relationship entry where `hero_b_id == "shu_001_liu_bei"` → entry dropped from final `_heroes[shu_001_liu_bei].relationships`; record loads normally; `push_warning` lists the self-ref hero_id
- [ ] **AC-2** (TR-010 — EC-5 orphan FK WARNING): record with hero_id `shu_001_liu_bei` containing a relationship entry where `hero_b_id == "qun_099_fictional"` (not present in `_heroes` post-load) → entry dropped; record loads normally; `push_warning` lists the unresolved hero_b_id. **Excluded-from-MVP heroes are an expected EC-5 source per GDD** — FK miss is non-fatal by design.
- [ ] **AC-3** (TR-010 — EC-6 asymmetric conflict WARNING): records A and B both have a relationship entry referring to the other, both with `is_symmetric=true`, but `relation_type` differs (e.g. A says RIVAL, B says SWORN_BROTHER) → BOTH entries kept (Hero DB does NOT adjudicate); `push_warning` lists the conflict. Verifies the design-warning-not-data-error contract.
- [ ] **AC-4** (load-order independence): EC-5 orphan check happens AFTER all valid records have been inserted into `_heroes` — verified by a fixture where the FK target appears in JSON BEFORE its referrer (passes WARNING tier) AND another where the target appears AFTER (also passes — pipeline does a second pass for FK validation post-insertion)
- [ ] **AC-5** (record load resilience): in a fixture with 3 records — A (with EC-4 self-ref), B (with EC-5 orphan), C (with EC-6 conflict pair to A) — all 3 records still appear in `_heroes` post-load; only the specific relationship entries are dropped (EC-4) or flagged-and-kept (EC-6); 3 push_warning calls minimum
- [ ] **AC-6** (TR-005 R-1 mitigation regression — shared reference contract): `tests/unit/foundation/hero_database_consumer_mutation_test.gd` asserts that mutating a `HeroData` field returned from `get_hero` IS visible to a subsequent `get_hero` call with the same id. **Test name MUST signal the contract**: e.g. `test_get_hero_returns_shared_reference_mutation_is_visible_convention_is_sole_defense`. The test PASSING (mutation visible) is the desired outcome — it proves the convention is convention-only, not enforced.
- [ ] **AC-7** (forbidden_pattern registration verified): `docs/registry/architecture.yaml` contains entries for `hero_data_consumer_mutation` AND `hero_database_signal_emission` — both registered same-patch with ADR-0007 acceptance per §Migration Plan §6. Story verifies presence (read-only check; if missing, escalate to a same-patch fix).
- [ ] **AC-8** (`get_relationships` typed-array return): `get_relationships(hero_id)` returns `Array[Dictionary]` (typed) — story-001 already declared the signature; this story confirms the WARNING-tier pre-filter doesn't accidentally demote typing
- [ ] **AC-9** (test isolation): all new tests reset `_heroes_loaded = false` AND `_heroes = {}` in `before_test()` per G-15
- [ ] **AC-10** (regression PASS): full GdUnit4 regression maintains story-003's baseline post-story; 0 errors / ≤1 carried failure / 0 orphans

---

## Implementation Notes

*Derived from ADR-0007 §5 (Validation Pipeline WARNING tier) + §7 (forbidden patterns) + Migration Plan §6:*

1. **Two-pass relationship validation** — extend `_load_heroes()` from story 002:
   ```
   pass 1: regex + duplicate FATAL → empty _heroes on trip
   pass 2: per-record FATAL (range + skill array) → drop offending records
   pass 3 (NEW this story): WARNING-tier relationship validation
     for hero in _heroes.values():
       hero.relationships = _filter_relationships_with_warnings(hero.hero_id, hero.relationships, _heroes)
     # _filter_relationships_with_warnings drops EC-4 + EC-5 entries; flags EC-6 in-place + push_warning
   ```

2. **`_filter_relationships_with_warnings(hero_id, relationships, all_heroes)` shape**:
   ```gdscript
   static func _filter_relationships_with_warnings(
       hero_id: StringName,
       relationships: Array[Dictionary],
       all_heroes: Dictionary[StringName, HeroData]
   ) -> Array[Dictionary]:
       var result: Array[Dictionary] = []
       for rel in relationships:
           var hero_b: String = rel.get("hero_b_id", "")
           # EC-4 self-reference
           if StringName(hero_b) == hero_id:
               push_warning("HeroDatabase: %s has self-referencing relationship — dropped" % hero_id)
               continue
           # EC-5 orphan FK
           if not all_heroes.has(StringName(hero_b)):
               push_warning("HeroDatabase: %s relationship references unresolved hero_b_id '%s' — dropped" % [hero_id, hero_b])
               continue
           result.append(rel)
       return result
   # EC-6 asymmetric conflict detection runs as a separate pass over result-pairs
   # (cross-hero check; flags both entries via push_warning but keeps both)
   ```

3. **EC-6 asymmetric detection** — second sub-pass after EC-4/EC-5 filtering:
   ```gdscript
   # For each hero A, for each rel in A.relationships, find B = rel.hero_b_id;
   # check if B has a corresponding rel back to A; if both is_symmetric=true and
   # relation_type differs → push_warning for the pair (don't drop either side).
   ```

4. **R-1 mitigation regression test** (`tests/unit/foundation/hero_database_consumer_mutation_test.gd`) — proves convention is sole defense:
   ```gdscript
   func test_get_hero_returns_shared_reference_mutation_is_visible_convention_is_sole_defense() -> void:
       # Arrange: load fixture with shu_001_liu_bei stat_might = 70
       HeroDatabase._heroes = {&"shu_001_liu_bei": _build_test_hero(70)}
       HeroDatabase._heroes_loaded = true
       var hero1 := HeroDatabase.get_hero(&"shu_001_liu_bei")
       assert_int(hero1.stat_might).is_equal(70)
       # Act: mutate the returned reference (THIS IS THE FORBIDDEN OPERATION; we do it deliberately)
       hero1.stat_might = 99
       # Assert: subsequent get_hero call sees the mutation — proving shared reference
       var hero2 := HeroDatabase.get_hero(&"shu_001_liu_bei")
       assert_int(hero2.stat_might).is_equal(99) \
           .override_failure_message("If this assertion fails, HeroDatabase is now defending against mutation. " \
               + "Either duplicate_deep() was added (10× hot-path cost; rejected per ADR-0007 §5) " \
               + "or some other defense landed. The R-1 mitigation contract changed — re-evaluate.")
   ```
   The test passing is the desired outcome; the override_failure_message guides future maintainers if someone adds defense without updating ADR-0007.

5. **Forbidden pattern verification** — read `docs/registry/architecture.yaml` and grep for `hero_data_consumer_mutation` + `hero_database_signal_emission`. Both should be present (added 2026-04-30 same-patch with ADR-0007). If missing, escalate to a same-patch fix (write to architecture.yaml + cite ADR-0007 §7 + §Migration Plan §6).

6. **Source comments verification** — re-confirm story-001's `# RETURNS SHARED REFERENCE — consumers MUST NOT mutate fields. Use base+modifier pattern.` is present above all 6 query methods. The R-1 test makes this contract teeth-bare; the source comments document it.

7. **Test fixture pattern for WARNING tier** — directly populate `_heroes` post-`_load_heroes_from_dict()` invocation with a known-bad fixture, then assert post-state:
   - EC-4 fixture: A with `relationships=[{hero_b_id: "A_self", ...}]` → after load, A.relationships has 0 entries + 1 push_warning
   - EC-5 fixture: A with `relationships=[{hero_b_id: "qun_099_fictional", ...}]`, no `qun_099_fictional` in roster → after load, A.relationships has 0 entries + 1 push_warning
   - EC-6 fixture: A with rel-to-B `RIVAL is_symmetric=true`; B with rel-to-A `SWORN_BROTHER is_symmetric=true` → after load, BOTH retain their entries + 1+ push_warning describing the conflict pair

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 003**: MVP roster authoring (`heroes.json`) + happy-path integration — already shipped; this story RELIES on the canonical roster being valid (story-004 fixtures introduce DELIBERATE WARNING-tier violations in test-only Dictionary fixtures, NOT in the production heroes.json file)
- **Story 005**: Perf baseline + non-emitter lint script + Polish-tier validation lint scaffold

---

## QA Test Cases

*Lean mode — orchestrator-authored. Convergent /code-review at story close-out validates these.*

**AC-1** (EC-4 self-reference):
- Given: fixture A has relationship `{hero_b_id: "shu_001_liu_bei", ...}` and A.hero_id == &"shu_001_liu_bei"
- When: `_load_heroes_from_dict(fixture)` runs
- Then: `_heroes[&"shu_001_liu_bei"].relationships.size() == 0` + 1 push_warning emitted citing self-ref + the hero_id

**AC-2** (EC-5 orphan FK):
- Given: fixture A has relationship to "qun_099_fictional"; no `qun_099_fictional` record in fixture
- When: load runs
- Then: A.relationships drops the orphan entry + 1 push_warning cites the unresolved id
- Edge case: orphan to a record that EXISTS in fixture but was DROPPED by per-record FATAL (e.g. invalid stat) — also drops as orphan post-pass-2 (intentional: pass 3 runs against the post-pass-2 `_heroes` state)

**AC-3** (EC-6 asymmetric conflict):
- Given: A has rel-to-B `RIVAL is_symmetric=true`; B has rel-to-A `SWORN_BROTHER is_symmetric=true`
- When: load runs
- Then: BOTH A.relationships and B.relationships retain their entries (no drop) + ≥1 push_warning cites the conflict pair
- Edge case: if `is_symmetric=false` on either side, conflict detection skips (one-way relationships are valid by design)

**AC-4** (load-order independence):
- Given: fixture with B's record listed BEFORE A's record in the JSON Dictionary, and A's relationship references B
- When: load runs
- Then: pass 3 finds B in `_heroes` (since pass 2 already inserted it); A's relationship to B is kept
- Edge case: declaration order in JSON has no semantic meaning — both forward-ref and back-ref relationships work

**AC-5** (record load resilience):
- Given: 3-record fixture exercising EC-4 + EC-5 + EC-6 simultaneously
- When: load runs
- Then: `_heroes.size() == 3` (all 3 records loaded) + relationships counts reflect the dropped/flagged entries + ≥3 push_warning emissions

**AC-6** (R-1 mitigation regression):
- Given: shared-reference contract (no `duplicate_deep`)
- When: caller mutates `hero1.stat_might = 99` after `get_hero(&"shu_001_liu_bei")`
- Then: subsequent `get_hero(&"shu_001_liu_bei").stat_might == 99` (mutation visible)
- Failure semantics: if assertion fails, ADR-0007 §5 was changed without updating the test — re-evaluate

**AC-7** (forbidden_pattern registration):
- Given: `docs/registry/architecture.yaml` post-ADR-0007 acceptance
- When: grep for `hero_data_consumer_mutation` AND `hero_database_signal_emission`
- Then: both return ≥1 match each
- Edge case: if missing, story scope expands to add them same-patch (citing ADR-0007 §7 + §Migration Plan §6)

**AC-8** (typed-array return):
- Given: post-WARNING-tier filtering
- When: `var rels: Array[Dictionary] = HeroDatabase.get_relationships(&"shu_001_liu_bei")`
- Then: assignment succeeds without warning + `rels.get_typed_class_name() == &"Dictionary"` (or equivalent typed-array check)

**AC-9** (test isolation):
- Given: all new test files in this story
- When: grep for `before_test`
- Then: every file's `before_test` body resets `_heroes_loaded = false` AND `_heroes = {}`

**AC-10** (regression PASS):
- Given: full regression run
- Then: ≥ story-003's baseline + this story's additions; 0 errors; ≤1 carried failure; 0 orphans

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/hero_database_warning_tier_test.gd` — covers AC-1..AC-5 (EC-4/5/6 fixtures + load-order independence + record resilience)
- `tests/unit/foundation/hero_database_consumer_mutation_test.gd` — covers AC-6 (R-1 mitigation)
- AC-7 verification can land as a brief assertion in either test file OR a separate smoke check
- Smoke check: optional unless forbidden_pattern registration was missing

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (module skeleton) + Story 002 (FATAL pipeline) + Story 003 (MVP roster + integration test pattern)
- Unlocks: Story 005 (lint scripts will reference all WARNING-tier branches when generating coverage report)
