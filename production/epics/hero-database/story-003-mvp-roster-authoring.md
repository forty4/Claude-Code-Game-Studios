# Story 003: MVP roster authoring (`heroes.json`) + happy-path integration test

> **Epic**: Hero Database
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 2-3h (8-10 record authoring + 4-faction coverage + happy-path integration test)
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/hero-database.md`
**Requirement**: `TR-hero-database-002`, `TR-hero-database-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007 — Hero Database — HeroData Resource + HeroDatabase Static Query Layer (MVP scope)
**ADR Decision Summary**: Storage form ratified — single JSON file at `assets/data/heroes/heroes.json`, top-level Dictionary keyed by hero_id String, per-hero record literals as values. 8-10 MVP records all flagged `is_available_mvp = true`. 4-faction coverage required (SHU=0, WEI=1, WU=2, QUNXIONG=3). `HeroData.default_class` stored as `int` (1:1 alignment with `UnitRole.UnitClass` enum 0..5) per ADR-0007 §2 + N3 cross-doc convention.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: JSON Dictionary literals support nested `Array[Dictionary]` for relationships (Godot 4.4+ stable); `Array[StringName]` from JSON requires explicit StringName conversion at load time (already handled by story 002's `_build_hero_data` helper); `Resource.duplicate_deep()` (4.5+) NOT used at this story's scope (relationships stay as plain `Array[Dictionary]` per provisional shape ADR-0007 §2 deferral note).

**Control Manifest Rules (Foundation layer)**:
- Required: data-driven authoring per CR-10 — no hardcoded hero records in `.gd` source
- Required: 4-faction coverage in MVP roster (SHU + WEI + WU + QUNXIONG; NEUTRAL optional)
- Required: 4-distinct-dominant_stat coverage per F-4 (manual authoring discipline at MVP; lint enforces in story 005 Polish-tier scaffold)
- Forbidden: `is_available_mvp = false` on any record in this MVP file (file is the MVP roster definition; non-MVP records belong to a future Alpha-tier file split per ADR-0007 §3)
- Guardrail: 8-10 records targets ~50KB cache footprint vs 512MB mobile ceiling — comfortable margin

---

## Acceptance Criteria

*From ADR-0007 §3 (Storage form) + GDD §Detailed Design + GDD AC-06 + AC-15 (happy-path slice), scoped to this story:*

- [ ] **AC-1** (file exists at canonical path): `assets/data/heroes/heroes.json` exists, parses cleanly via `JSON.new().parse()`, top-level type is Dictionary
- [ ] **AC-2** (record count): 8 ≤ record count ≤ 10 (CR-2 explicit per ADR-0007 §2 + GDD MVP scope §1)
- [ ] **AC-3** (4-faction coverage): each of SHU=0, WEI=1, WU=2, QUNXIONG=3 has ≥1 record. NEUTRAL=4 optional (0 or more).
- [ ] **AC-4** (all `is_available_mvp = true`): every record in this file flags is_available_mvp true (Polish-tier lint will validate this; manual authoring for now)
- [ ] **AC-5** (TR-002 26-field shape compliance): every record has all 26 fields populated per ADR-0007 §2 (7 identity + 4 core stats + 2 derived seeds + 1 movement + 2 role + 4 growth + 2 skill parallel arrays + 3 scenario + 1 relationships) — no missing fields, no extra fields. Field-level type compliance (int / String / float / Array[StringName] / Array[Dictionary]) validated by story-002's `_build_hero_data` helper at load time.
- [ ] **AC-6** (TR-012 default_class int convention): every record's `default_class` is an int in [0, 5] (CAVALRY=0..SCOUT=5) — NOT a typed `UnitRole.UnitClass` enum reference (cross-script enum reference forbidden per ADR-0007 §2 + N3)
- [ ] **AC-7** (validation pipeline PASS): full `_load_heroes()` invocation against this file results in `_heroes_loaded = true` + `_heroes.size() == record_count` + zero `push_error` matches in stderr — confirming all 26-field records pass story-002's CR-1 + CR-2 + EC-1 + EC-2 FATAL gates
- [ ] **AC-8** (GDD AC-06 — relationship structure round-trip): at least 2 records have non-empty `relationships` Array[Dictionary] with all 4 fields per relationship entry: `hero_b_id` (String) + `relation_type` (String, e.g. "SWORN_BROTHER" / "RIVAL") + `effect_tag` (String) + `is_symmetric` (bool). Calling `HeroDatabase.get_relationships(hero_id)` after load returns the same 4-field entries.
- [ ] **AC-9** (GDD AC-15 happy-path slice — query interface):
  - `get_hero(&"shu_001_liu_bei")` returns the canonical Liu Bei record (assuming roster includes him; substitute with another canonical hero_id if not)
  - `get_mvp_roster().size() == record_count`
  - `get_heroes_by_faction(0).size() ≥ 1` (SHU)
  - `get_heroes_by_class(1).size() ≥ 1` (INFANTRY — substitute with a class actually present in the roster)
  - `get_all_hero_ids().size() == record_count` + return type is `Array[StringName]` (G-2 typed-array discipline)
- [ ] **AC-10** (integration test passes): `tests/integration/foundation/hero_database_mvp_roster_test.gd` covers AC-7..AC-9 against the real `heroes.json` (no fixture); test invokes `HeroDatabase._heroes_loaded = false` reset in `before_test()` + calls real `_load_heroes()` + asserts query results
- [ ] **AC-11** (regression PASS): full GdUnit4 regression maintains story-002's baseline post-story; 0 errors / ≤1 carried failure / 0 orphans

---

## Implementation Notes

*Derived from ADR-0007 §3 (Storage), §2 (HeroData 26-field shape), N3 (default_class convention) + GDD §Detailed Design §Record Block Templates:*

1. **JSON file structure** — top-level Dictionary keyed by hero_id String:
   ```json
   {
     "shu_001_liu_bei": {
       "hero_id": "shu_001_liu_bei",
       "name_ko": "유비", "name_zh": "刘备", "name_courtesy": "玄德",
       "faction": 0,
       "portrait_id": "portrait_shu_liu_bei",
       "battle_sprite_id": "sprite_shu_liu_bei",
       "stat_might": 70, "stat_intellect": 75, "stat_command": 90, "stat_agility": 65,
       "base_hp_seed": 80, "base_initiative_seed": 65,
       "move_range": 4,
       "default_class": 4,
       "equipment_slot_override": [],
       "growth_might": 1.0, "growth_intellect": 1.1, "growth_command": 1.4, "growth_agility": 0.9,
       "innate_skill_ids": ["skill_inspire", "skill_benevolence"],
       "skill_unlock_levels": [1, 5],
       "join_chapter": 1,
       "join_condition_tag": "story_ch1_intro",
       "is_available_mvp": true,
       "relationships": [
         {"hero_b_id": "shu_002_guan_yu", "relation_type": "SWORN_BROTHER", "effect_tag": "bond_oath_peach_garden", "is_symmetric": true},
         {"hero_b_id": "shu_003_zhang_fei", "relation_type": "SWORN_BROTHER", "effect_tag": "bond_oath_peach_garden", "is_symmetric": true}
       ]
     },
     "shu_002_guan_yu": { ... },
     ...
   }
   ```

2. **Recommended MVP roster** (8-10 heroes; 4-faction + 4-dominant-stat coverage):
   - **SHU**: shu_001_liu_bei (COMMANDER, dominant=command), shu_002_guan_yu (CAVALRY, dominant=might), shu_004_zhuge_liang (STRATEGIST, dominant=intellect)
   - **WEI**: wei_001_cao_cao (COMMANDER, dominant=command), wei_005_xiahou_dun (INFANTRY, dominant=might)
   - **WU**: wu_001_sun_quan (COMMANDER, dominant=command), wu_003_zhou_yu (STRATEGIST, dominant=intellect)
   - **QUNXIONG**: qun_001_lu_bu (CAVALRY, dominant=might), qun_004_diao_chan (SCOUT, dominant=agility)
   - 9 records total — comfortably in [8, 10] bound; covers all 4 dominant stats × all 4 factions.
   - Stat values are illustrative; designer authoring final values during the implementation pass. Boundary discipline: each record stays inside [1,100] / [2,6] / [0.5, 2.0] ranges per story-002 FATAL gates.

3. **Relationship authoring** — at minimum 2 records with non-empty relationships (e.g. shu_001 + shu_002 + shu_003 in the Peach Garden Oath bond). Future Alpha will expand; MVP focuses on the canonical Three-Brothers triangle to exercise the round-trip path.

4. **Skill arrays** — keep `innate_skill_ids` length ≤ 3 per CR-2 cap (Polish-tier lint enforces; MVP authoring discipline). `skill_unlock_levels` parallel + length-equal. Use placeholder StringName values like `&"skill_inspire"` / `&"skill_benevolence"` — actual skill catalog ships in a future Skill GDD (per GDD §Open Questions §2).

5. **`portrait_id` + `battle_sprite_id`** — placeholder strings (e.g. `"portrait_shu_liu_bei"`); actual asset paths resolve in a Vertical-Slice-tier asset-pipeline ADR. Empty strings ACCEPTABLE for MVP records that don't yet have art (no FATAL gate on these fields per ADR-0007 §5).

6. **Integration test seam** — `tests/integration/foundation/hero_database_mvp_roster_test.gd` reads the REAL `heroes.json` (no fixture) and asserts:
   - `before_test()` resets `_heroes_loaded = false` + `_heroes = {}`
   - calls `HeroDatabase.get_all_hero_ids()` (which triggers `_load_heroes()` on the real file)
   - asserts `_heroes_loaded == true` post-call (no FATAL trips against the authored file)
   - asserts size + faction coverage + dominant_stat coverage + per-record field-level checks
   - calls `get_relationships(&"shu_001_liu_bei")` and asserts 2 entries with the 4-field shape

7. **GDD Status field same-patch verification** (ADR-0007 §Migration Plan §4) — confirm `design/gdd/hero-database.md` Status reads "Accepted via ADR-0007 (2026-04-30)" — flip in this same patch if still "Designed". Story-001 readiness check should already have caught this; this story is the safety net.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: FATAL validation pipeline (CR-1 regex + CR-2 ranges + EC-1 duplicate + EC-2 skill arrays) — already shipped; this story RELIES on it
- **Story 004**: Relationship WARNING tier (EC-4 self-ref, EC-5 orphan FK, EC-6 asymmetric conflict) — this story authors well-formed relationships only; story 004 adds the WARNING-tier dropper for malformed entries
- **Story 005**: Perf measurement against this roster + non-emitter lint + Polish-tier validation lint scaffold

---

## QA Test Cases

*Lean mode — orchestrator-authored. Convergent /code-review at story close-out validates these.*

**AC-1..AC-3** (file structure + faction coverage):
- Given: `assets/data/heroes/heroes.json` post-authoring
- When: parsed via `JSON.new().parse() + json.data` in a test
- Then: top-level is Dictionary; size in [8, 10]; iteration over values' `faction` field yields a set covering {0, 1, 2, 3}
- Edge case: NEUTRAL=4 absent is acceptable; faction>4 is a violation (no enum value defined)

**AC-4** (is_available_mvp):
- Given: parsed records
- When: filter for `record.is_available_mvp == true`
- Then: count == record_count (every record is MVP-flagged)

**AC-5** (26-field shape):
- Given: each parsed record
- When: keys() inspected
- Then: keys set is exactly 26 expected names from ADR-0007 §2 — no missing, no extras
- Edge case: typo in a field name surfaces as either a missing-key assertion failure or a `push_error` from `_build_hero_data` if the key is misspelled

**AC-6** (default_class int):
- Given: each parsed record
- When: type-check `record.default_class`
- Then: int value in [0, 5]
- Edge case: 6 or -1 trips story-002's range check (out-of-band class enum value); JSON typing as float (e.g. `4.0`) is a violation per CR-4 int-stored convention

**AC-7** (validation pipeline PASS):
- Given: real `heroes.json` post-authoring + `HeroDatabase._heroes_loaded = false`
- When: any `HeroDatabase.*` query method called for the first time
- Then: `_heroes_loaded == true` + `_heroes.size() == record_count` + stderr captures zero `push_error` matches under the `HeroDatabase:` prefix
- Edge case: any FATAL trip in story-002's pipeline indicates an authoring error in heroes.json — must be fixed before close-out

**AC-8** (relationship structure round-trip):
- Given: post-load state
- When: `get_relationships(&"shu_001_liu_bei")` called
- Then: returns `Array[Dictionary]` of size ≥ 2; each entry has exactly 4 keys: `hero_b_id` (String), `relation_type` (String), `effect_tag` (String), `is_symmetric` (bool)
- Edge case: typo in a relationship key (e.g. `"is_symetric"`) trips assertion; record's other fields still load (relationships are best-effort per WARNING-tier story 004)

**AC-9** (happy-path queries):
- Given: post-load state
- When: 5 query methods called (get_hero / get_mvp_roster / get_heroes_by_faction / get_heroes_by_class / get_all_hero_ids)
- Then: each returns the contract-correct value type with non-empty result; G-2 typed-array discipline verified (return type assignment to `var result: Array[HeroData] = ...` succeeds without warning)

**AC-10** (integration test):
- Given: post-implementation state
- When: `godot --headless ... -a tests/integration/foundation/hero_database_mvp_roster_test.gd` runs
- Then: all tests pass; suite count ≥ 8 (one per AC + boundary cases)

**AC-11** (regression PASS):
- Given: full regression run
- Then: ≥ story-002's baseline + this story's additions; 0 errors; ≤1 carried failure; 0 orphans

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `assets/data/heroes/heroes.json` — new file, 8-10 records, hand-validated for syntax via `JSON.new().parse()` smoke check
- `tests/integration/foundation/hero_database_mvp_roster_test.gd` — new file covering AC-7..AC-10
- Smoke check: `production/qa/smoke-hero-database-story-003-YYYY-MM-DD.md` (optional; required if any FATAL trip surfaces during authoring iteration)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (module skeleton) + Story 002 (validation pipeline must gate the authored records cleanly)
- Unlocks: Story 004 (WARNING-tier validators need real records with relationships authored to exercise drop-paths); Story 005 (perf measurement needs the real roster loaded)

---

## Completion Notes

**Completed**: 2026-05-01
**Criteria**: 11/11 passing (100% test coverage; no UNTESTED ACs)
**Test Evidence**: Integration BLOCKING gate satisfied — `tests/integration/foundation/hero_database_mvp_roster_test.gd` (375 LoC / 13 tests / all passing). Smoke check optional and not required (no FATAL trips during authoring; AC-7 pass-through confirms full pipeline).
**Regression**: 539 → **551 / 0 errors / 1 failures / 0 orphans** ✅
- Math: 539 baseline + 13 new (mvp_roster integration) − 1 deleted (obsolete missing-file test from story-001) = 551
- Sole failure = pre-existing carried orthogonal `test_hero_data_doc_comment_contains_required_strings` (in `tests/unit/foundation/unit_role_skeleton_test.gd`) — NOT introduced by story-003

**Code Review**: Complete — APPROVED WITH SUGGESTIONS (lean mode; manual review). 4 forward-looking suggestions S-1..S-4 captured below.

**Files changed**:
- `assets/data/heroes/heroes.json` (NEW, 7551 bytes, 9 records) — 4-faction × 4-distinct-dominant-stat coverage; Three-Brothers Peach Garden Oath bond on shu_001/002/003 (mutual SWORN_BROTHER, all symmetric, shared `bond_oath_peach_garden` effect_tag)
- `tests/integration/foundation/hero_database_mvp_roster_test.gd` (NEW, 375 LoC, 13 tests) — covers AC-1..AC-9 against the real heroes.json; uses `_hd_script.set("_heroes_loaded", false)` reflective pattern + `_parse_heroes_json()` private helper
- `tests/unit/foundation/hero_database_test.gd` (MODIFIED) — deleted obsolete `test_load_heroes_handles_missing_file_gracefully` (story-001 author tagged it as transient: "until then, this test verifies the missing-file fallback contract"); replaced with explanatory comment block (lines 68-78) citing rationale + production defensive miss-path stays intact + integration test as file-present canary

**Engine gotchas applied**: G-2 typed arrays (`Array[HeroData]` / `Array[StringName]` / `Array[Dictionary]` / `Array[String]`), G-7 verified Overall Summary count grew (539 → 552 → 551 after stale-test deletion) + zero parse errors, G-14 ran `godot --headless --import --path .` post-write to refresh class cache + register heroes.json `.uid` sidecar, G-15 `before_test()` (NOT `before_each`) reset both `_heroes_loaded` AND `_heroes` typed Dictionary, G-16 typed `Array[Dictionary]`, G-20 implicit StringName/String coercion noted; tests assert structural shape not type-rejection at `==`, G-22 `_hd_script.set()` reflective pattern, G-23 used only `is_equal`/`is_not_null`/`is_null`/`is_between`/`is_greater_equal`/`is_less_equal` (no `is_not_equal_approx`), G-24 wrapped `as bool` cast in parens

**Deviations** (advisory, none blocking):

- **OUT OF SCOPE (user-approved)**: Modified story-001's test file to delete obsolete `test_load_heroes_handles_missing_file_gracefully`. Original author tagged the test as transient ("until then, this test verifies the missing-file fallback contract" + "story 003 will create assets/data/heroes/heroes.json"). User selected Option A at orchestrator decision point — rationale: heroes.json existence is the DIRECT and EXPECTED consequence of story-003's deliverable; production defensive miss-path (FileAccess "" → push_error → early return) stays intact in source; integration test is the file-present canary on every CI run.

- **ADVISORY (S-1, forward-looking, deferred to TD-042)**: heroes.json uses snake_case keys (`hero_id`, `stat_might`, `name_ko`, ...) which conflicts with `.claude/rules/data-files.md` "Entity-shape data files (heroes, maps, scenarios, equipment) — these MUST follow camelCase per the default rule." ADR-0007 §3 explicitly designs snake_case for cross-doc grep-ability with HeroData @export field names; pattern is established at 4-precedent (`terrain_config.json`, `unit_roles.json`, heroes.json, plus the existing Constants Registry Exception for `balance_entities.json`). Resolution path: amend `data-files.md` to add an "Entity Data File Exception" enumerating the affected files. **Logged as TD-042**.

- **ADVISORY (S-2, test perf — minor)**: `_parse_heroes_json()` re-reads + re-parses heroes.json on every test invocation (~5-10ms × 11 of 13 tests ≈ 55-110ms of redundant I/O). Consider memoizing via a `var _cached_json: Dictionary` lazy-init in `before_test`. Defer to story-005 perf baseline if budget allows.

- **ADVISORY (S-3, default_class missing-field detection)**: `record.get("default_class", -1) as int` followed by `assert_bool(cls >= 0)` would print "default_class -1 must be >= 0" on a missing-field record (misleading vs the actual cause). AC-5's exact-26-key check catches missing fields directly with a clearer message; cosmetic.

- **ADVISORY (S-4, test naming consistency — cosmetic)**: per `.claude/rules/test-standards.md` the canonical pattern is `test_[system]_[scenario]_[expected_result]`. Most integration test names omit the leading `[system]` segment (project precedent now stable at "system context implied by file location" — story-002 uses the same pattern). Future test-standards.md clarification opportunity.

- **ADVISORY (raw-JSON dedup E2E — story-002 AC-7 follow-up, deferred to TD-043)**: Story-002's AC-7 was structural+functional-non-collision only; story-003's AC-7 fold-in (`test_load_heroes_pipeline_passes_for_authored_roster`) exercises the real-file happy path. Literal duplicate-keys-at-JSON-text-level remains untestable through normal `JSON.parse` (silent dedup at parse time + Dictionary collapse). The `seen_ids` guard remains structurally tested via story-002's reflective bypass. **Logged as TD-043**.

**Story-001 forward-looking S-4 (test seam) closure status**: story-002 added the `_load_heroes_from_dict` test seam; story-003's AC-7 integration test exercises the real-file end-to-end path on top of that seam. Story-001's S-4 is now closed by composition.

**Sprint impact**: S2-04 progress 3/5 stories Complete; sprint-status.yaml updated with progress comment. S2-04 stays `backlog` per established precedent (epic-level done = all 5 stories Complete).

**Next**: story-004 (WARNING-tier validators: EC-4 self-ref, EC-5 orphan FK, EC-6 asymmetric conflict) — story-003's Peach Garden Oath bond fixture in heroes.json provides the well-formed-relationship baseline for story-004's drop-path tests. Story-005 (perf baseline + lints) is parallel-eligible after story-003.
