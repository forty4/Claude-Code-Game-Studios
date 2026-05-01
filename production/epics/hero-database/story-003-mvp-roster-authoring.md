# Story 003: MVP roster authoring (`heroes.json`) + happy-path integration test

> **Epic**: Hero Database
> **Status**: Ready
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
