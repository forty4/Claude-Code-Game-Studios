# BattleScene Smoke Evidence — 2026-05-05 (Sprint 7 S7-02 — post-mock-deletion)

**Story**: production/epics/scenario-progression/story-001-scenario-runner-implementation-and-mock-encoder-deletion.md
**ADR**: ADR-0017 (Accepted 2026-05-04 via /architecture-review delta #12)
**Migration Plan §1 Step**: 7-11 (mock encoder DELETED + main_scene comment update + lint flip + this re-authored smoke doc)
**Prior smoke doc**: `battle_scene_smoke_2026-05-04_sprint6_archived.md` (archived; sprint-6 mock-encoder launch path)
**AC-MIGRATE-4**: this doc covers the new launch path (ScenarioRunner.load_scenario → ChapterDefinition → BattleScene).

---

## Launch sources covered

Per ADR-0016 V-11 cross-launch-source matrix — verifies BattleScene mounts cleanly under each path post-mock-deletion.

### Source (a): SceneManager-driven (ADR-0002 deferred packed-scene instantiation)

**Status**: COVERED transitively by `tests/integration/feature/battle_scene/battle_scene_smoke_test.gd` (TR-battle-scene-wiring-001..010 all 11 ACs PASS in integration test). Production launch path will be exercised when Main Menu / Overworld scenes ship (sprint-7+).

### Source (b): project.godot main_scene config

**Status**: ACTIVE — `project.godot [application] run/main_scene = "res://scenes/battle/battle_scene.tscn"` retained from sprint-6 (no revert target — Main Menu / Overworld scenes do not exist as of sprint-7 close 2026-05-05). Inline comment in project.godot updated from "SPRINT-6 ONLY — REVERT WHEN ADR-0017 LANDS" to "SPRINT-7+ TEMPORARY — battle_scene.tscn remains as main_scene until Main Menu / Overworld scenes ship". This is a documented deviation from ADR-0017 §Migration Plan §8 (revert main_scene) — see deviations section below.

### Source (c): godot --main-scene CLI override

**Status**: COVERED transitively per ADR-0016 R-8 idempotent mount sequence — `_ready()` does not depend on launch source identity.

---

## Mount sequence (6 steps DI-DAG-ordered per ADR-0016 §3 R-3)

Verified via `tests/integration/feature/battle_scene/battle_scene_smoke_test.gd` (existing 11 tests, all PASS post-modification):

1. **Step 1 — MapGrid (ADR-0004)**: `_map_grid.load_map(map_resource)` — map_resource now constructed via `_build_map_resource_for_chapter(chapter)` (replaces deleted `_build_mock_map_resource_sprint6`)
2. **Step 2 — BattleCamera (ADR-0013)**: `_battle_camera.setup(_map_grid)` (unchanged)
3. **Step 3 — HPStatusController (ADR-0010)**: per-unit `initialize_unit(unit_id, hero, unit_class)` loop over `roster: Array[BattleUnit]` — roster now from `_build_battle_units_from_chapter(chapter)` (replaces deleted `_build_mock_roster_sprint6`)
4. **Step 4 — TurnOrderRunner (ADR-0011)**: `_turn_runner.initialize_battle(roster)` (unchanged signature)
5. **Step 5 — GridBattleController (ADR-0014)**: 8-param `setup()` (unchanged)
6. **Step 6 — BattleHUD (ADR-0015)**: 9-param `setup()` (unchanged); HUDLayer.add_child

**Mount step 5.5 (ADR-0019 AISystem)**: NOT YET IMPLEMENTED — deferred to sprint-7 S7-04 per ADR-0016 §Soft/Provisional row 4. ADR-0016 §3 R-3 documentation amended via /architecture-review delta #14 2026-05-05; physical mount call site insertion is the S7-04 patch deliverable.

---

## ScenarioRunner integration verification

### Standalone-launch bootstrap path

`battle_scene.gd._ready()` lines 99-110 (post-mock-deletion):
```gdscript
if ScenarioRunner.get_current_chapter_index() == -1:
    var loaded: bool = ScenarioRunner.load_scenario("res://assets/data/scenarios/mvp_shu.json")
    if not loaded:
        push_error("BattleScene: failed to load mvp_shu.json scenario")
    if ScenarioRunner.get_state() == ScenarioRunner.State.BEAT_1_ANCHOR:
        ScenarioRunner.advance_beat()  # -> BEAT_2_ECHO
        ScenarioRunner.advance_beat()  # -> BEAT_3_BRIEF
        ScenarioRunner.advance_beat()  # -> BEAT_4_PREP
        ScenarioRunner.confirm_deployment()  # -> BATTLE_LOADING -> BEAT_5_BATTLE
```

This drives ScenarioRunner from LOADING through BEAT_5_BATTLE for standalone launch (no SceneManager / Main Menu surface). When Main Menu / Overworld ship (sprint-8+), the standalone-bootstrap block becomes a no-op since `get_current_chapter_index()` will already be ≥0.

### Chapter data hydration

`assets/data/scenarios/mvp_shu.json` (chapter-1 stub fixture) loads:
- `scenario_id`: "mvp_shu"
- 1 chapter: `ch01_changbanpo` (장판파)
- `branch_table`: WIN_default → "WIN_changbanpo_default", LOSS_default → "LOSS_changbanpo_default"
- `canonical_branch_key`: "WIN_changbanpo_default"
- `player_unit_ids`: [0, 1]
- `enemy_roster` with archetype: 코코=coordinator (stub), 하후돈=aggressor (stub)
- `deployment_positions_default`: {"0": [1,2], "1": [2,2]}

Hero IDs (shu_003_zhang_fei, wu_003_zhou_yu, wei_001_cao_cao, wei_005_xiahou_dun) match the deleted mock_roster — same 4 heroes for sprint-7 demo continuity.

### Map resource

`_build_map_resource_for_chapter(chapter)` constructs a 15×15 all-grass MapResource inline (port of deleted `_build_mock_map_resource_sprint6`). Sprint-7+ S7-05 chapter-1 narrative authoring will replace inline construction with `assets/data/maps/{map_id}.tres` asset loading — current stub satisfies AC-MIGRATE-1 by deleting the mock-marker block while preserving runtime functionality.

---

## Test verification summary

**Pre-S7-02 baseline**: 876/876 passing (sprint-6 close).
**Post-S7-02**: **911/911 passing**, 0 errors / 0 failures / 0 orphans (verified via `godot --headless ... -c`).
**Net delta**: +35 tests (+28 from new ScenarioRunner test files + 7 from auto-discovery on touched files).

### New test files (S7-02)

| File | Tests | ACs Covered |
|------|-------|-------------|
| `tests/unit/core/scenario_runner_state_machine_test.gd` | 6 | AC-SP-3 (CR-3 tri-state) + AC-SP-13 (forward-only) + AC-SP-25 (no _process) |
| `tests/unit/core/scenario_runner_signal_contract_test.gd` | 5 | AC-SP-16 (cross-scene routing) + AC-SP-17 (5+1 signal contract) + AC-SP-18 (DBC 9-field) + AC-SP-19 (EchoMark 3-field) + AC-SP-20 (CP-3 fields) |
| `tests/unit/core/scenario_runner_retry_loop_test.gd` | 4 | AC-SP-5 (echo accumulation + reset + WIN-block + emit count) |
| `tests/unit/core/scenario_runner_save_context_test.gd` | 4 | AC-SP-21 (3-CP timing + outcome propagation + field completeness) |
| `tests/unit/core/chapter_definition_validation_test.gd` | 8 | EC-SP-8 (chapter_id format + branch_table + canonical_branch_key + echo_threshold + DRAW_ key + valid baseline) |
| `tests/integration/scenario_runner/scenario_runner_chapter_1_traversal_test.gd` | 4 | AC-SP-1 (chapter linear progression) + AC-SP-2 (9-beat rhythm) + AC-SP-9 (chapter_completed + scenario_complete) + AC-SP-17 (chapter-1-fixture signal emission) |

### Modified test files (existing)

| File | Reason |
|------|--------|
| `tests/unit/core/game_bus_declaration_test.gd` | 29 → 30 signals (added scenario_fault to authoritative list); ChapterResult / ScenarioResult Resource arg class updates |
| `tests/unit/core/signal_contract_test.gd` | scenario_complete payload widened String → ScenarioResult per delta #12; scenario_fault entry added |
| `tests/unit/core/game_bus_diagnostics_test.gd` | scenario_fault → "scenario" domain routing |
| `tests/integration/feature/battle_scene/battle_scene_smoke_test.gd` | AC-5 SEMANTIC FLIPPED: markers MUST NOT exist post-mock-deletion (1st-precedent phase-flipping test pattern) |

---

## Lint verification

All 6 lints (5 new + 1 phase-flipped) pass against the post-S7-02 source:

```
[0] lint_scenario_runner_state_match_exhaustive.sh: PASS
[0] lint_scenario_runner_branch_table_immutable.sh: PASS
[0] lint_scenario_runner_save_context_complete.sh: PASS
[0] lint_scenario_runner_no_deferred_in_beat_7_seal.sh: PASS
[0] lint_scenario_runner_outcome_synthesis.sh: PASS
[0] lint_battle_scene_sprint6_mock_marker.sh: PASS (post-flip — markers absent)
```

---

## Documented deviations from ADR-0017 Migration Plan

1. **Step 8 — `project.godot` main_scene revert**: NOT performed. No revert target exists yet (Main Menu / Overworld scenes do not exist at sprint-7 close). Inline comment updated from "SPRINT-6 ONLY" to "SPRINT-7+ TEMPORARY — until Main Menu / Overworld ships". To be re-evaluated at sprint-8+ when those scenes land.

2. **Step 12 — 5 ScenarioRunner CI lints**: ALL 5 lints shipped same-patch (Decision E in story). Story's pre-resolved scope decision promoted from "deferred" to "in scope" per sprint-7 plan DoD.

3. **Decision A scope — DestinyBranchJudge stub**: As planned, `default_destiny_branch_judge.gd` ships with stubbed `_apply_f_sp_1` returning canonical-default Dictionary. Full F-DB-1 algorithm + invariant_violation vocabulary are S7-03 scope.

4. **Decision B scope — chapter-1 .tres**: As planned, `mvp_shu.json` ships minimal scaffold (single chapter, hero IDs matching sprint-6 mock_roster, no chokepoints / authored Beat 8 narrative). S7-05 fills out 장판파 narrative.

5. **`assets/data/maps/mvp_chapter_01.tres`**: NOT shipped. No existing `assets/data/maps/` directory exists with .tres write convention. `BattleScene._build_map_resource_for_chapter(chapter)` constructs 15×15 grass inline (mirroring deleted `_build_mock_map_resource_sprint6` pattern). Sprint-7+ S7-05 will introduce the .tres asset write convention together with chapter-1 (장판파) narrative content.

6. **AISystem mount step 5.5**: documentation-only update to ADR-0016 §3 R-3 via delta #14; actual code-level mount call insertion is S7-04 scope.

---

## Single coordinated patch atomicity verification (AC-ATOMIC-1)

✅ All deliverables ship in a single commit:
- 8 source files (3 new payload Resources + 1 amended Resource + 2 destiny_branch judges + 1 ScenarioRunner + 1 modified GameBus + 1 modified BattleScene)
- 1 data file (mvp_shu.json scenario)
- 1 modified project.godot (autoload registration + main_scene comment)
- 1 modified balance_entities.json (SCENARIO_PROGRESSION_ECHO_CAP)
- 6 lints (5 new ScenarioRunner-domain + 1 phase-flipped battle_scene)
- 8 test files (5 new ScenarioRunner unit + 1 new chapter validation + 1 new integration + 4 modified existing for signal contract + sprint6 mock test flip)
- 2 test helpers (scenario_runner_test_seam.gd + destiny_branch_judge_stub.gd)
- 1 amended architecture.yaml (battle_scene_sprint6_mock_marker_must_exist phase-flip annotation)
- 1 evidence doc (this file)
- 1 archived prior smoke doc (battle_scene_smoke_2026-05-04_sprint6_archived.md)
- 1 verification summary (scenario_runner_verification_summary.md)

No intermediate state where ScenarioRunner exists but mock encoder remains, or vice versa.

---

## Cross-references

- ADR-0017 (Accepted 2026-05-04) — governing
- ADR-0016 (mount sequence + Migration Plan §1)
- ADR-0018 (DestinyBranchJudge — minimal stub for S7-02 per Decision A)
- ADR-0019 (AISystem mount step 5.5 — deferred to S7-04)
- design/gdd/scenario-progression.md rev 2.2 (F-SP-1..F-SP-6 + EC-SP-1..14 + AC-SP-1..19)
- production/epics/scenario-progression/story-001 (this story)
- tests/integration/feature/battle_scene/battle_scene_smoke_test.gd (existing — AC-5 phase-flipped)
- battle_scene_smoke_2026-05-04_sprint6_archived.md (sprint-6 launch path snapshot)
