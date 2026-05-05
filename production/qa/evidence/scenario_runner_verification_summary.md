# Scenario Progression Epic — Verification Summary

> **Epic**: `production/epics/scenario-progression/EPIC.md`
> **Story**: `story-001-scenario-runner-implementation-and-mock-encoder-deletion.md` (epic-terminal)
> **Closed**: 2026-05-05 (Sprint 7 S7-02)
> **ADR**: `docs/architecture/ADR-0017-scenario-progression.md` (Accepted 2026-05-04 via /architecture-review delta #12)
> **Verifier**: Dowan Kim (orchestrator) — single coordinated patch atomicity per ADR-0017 line 525
> **Test baseline**: 876 → **911 passing** (35 net delta; 0 errors / 0 failures / 0 orphans)

---

## §A. Story shipped

| # | Story | Type | Status | TR-IDs Covered | Test Evidence |
|---|-------|------|--------|----------------|---------------|
| 001 | ScenarioRunner per ADR-0017 Migration Plan §1..§11 + sprint-6 mock encoder DELETION (single coordinated patch) | Integration | Complete (2026-05-05) | TR-scenario-progression-004..015 (12 of 15; 001-003 are pre-ADR placeholders) | 6 new test files (5 unit + 1 integration; 31 new test functions); + `scenario_runner_3_chapter_mvp_2026-05-05.md` |

---

## §B. TR coverage matrix (12/15)

| TR-ID | Requirement (summary) | Status |
|-------|----------------------|--------|
| TR-004 | ScenarioRunner autoload (extends Node, NO class_name per G-3, boot order position 6) | ✅ |
| TR-005 | 13-state enum + match-statement + `_transition_to(target)` | ✅ |
| TR-006 | ChapterDefinition typed Resource + JSON hydration pipeline | ✅ |
| TR-007 | 7-signal contract emission (5 confirmed + 2 ratified delta #12; scenario_complete widened to ScenarioResult) | ✅ |
| TR-008 | F-SP-3 v2.2 SYNCHRONOUS seal at BEAT_7 entry (Pillar 2 lock 2nd precedent) | ✅ |
| TR-009 | F-SP-1/F-SP-2 delegation to DestinyBranchJudge.resolve(...) | ✅ (minimal stub per Decision A) |
| TR-010 | Retry-loop guard + ECHO_COUNT_HARD_CAP from BalanceConstants | ✅ |
| TR-011 | 3-CP save emission (CP-1/CP-2/CP-3) + `_make_save_context()` helper | ✅ |
| TR-012 | `BattleConfig` = Reuse `BattlePayload` Resource (no new type) | ✅ |
| TR-013 | EC-SP-8 chapter validation pipeline (FATAL on malformed) | ✅ |
| TR-014 | 5 forbidden_patterns registered + 5 lints implemented + phase-flipped 1 lint | ✅ (all 6 lints PASS) |
| TR-015 | Migration Plan Steps 1-11 single coordinated patch atomicity | ✅ (with 1 documented deviation: Step 8 main_scene revert deferred — no revert target exists) |

**TR-001/002/003**: pre-ADR placeholders (status: active in registry but superseded by TR-004..015). Not directly addressed by S7-02 — they describe the pre-ADR signal-relay-pattern question that was answered by ADR-0017 acceptance.

**Pre-resolved coordination decisions** (per story §Decisions A-F):
- A. DestinyBranchJudge stub scaffolding shipped — full F-DB-1 algorithm body is S7-03 scope
- B. chapter-1 .tres minimal scaffold shipped — full 장판파 narrative is S7-05 scope
- C. AISystem hooks deferred to S7-04 (ChapterDefinition.enemy_roster archetype field included)
- D. Save/Load #17 GDD CUT (in-memory CP-1/2/3 emission verified; persistence round-trip out of scope)
- E. All 5 ScenarioRunner CI lints shipped same-patch (promoted from "deferred" to "in scope")
- F. Phase-flipping lint atomicity preserved (mock encoder DELETION + lint flip in single commit)

---

## §C. Test verification

**Pre-S7-02**: 876/876 passing (sprint-6 close).
**Post-S7-02**: **911/911 passing** (+35 net; 0 errors / 0 failures / 0 orphans).

### New test files (S7-02)

| File | Tests | Primary AC Coverage |
|------|-------|---------------------|
| `tests/unit/core/scenario_runner_state_machine_test.gd` | 6 | AC-SP-3 + AC-SP-13 + AC-SP-25 |
| `tests/unit/core/scenario_runner_signal_contract_test.gd` | 5 | AC-SP-16 + AC-SP-17 + AC-SP-18 + AC-SP-19 + AC-SP-20 |
| `tests/unit/core/scenario_runner_retry_loop_test.gd` | 4 | AC-SP-5 |
| `tests/unit/core/scenario_runner_save_context_test.gd` | 4 | AC-SP-21 |
| `tests/unit/core/chapter_definition_validation_test.gd` | 8 | EC-SP-8 |
| `tests/integration/scenario_runner/scenario_runner_chapter_1_traversal_test.gd` | 4 | AC-SP-1 + AC-SP-2 + AC-SP-9 + AC-SP-17 (chapter-fixture) |
| **Subtotal** | **31** | |

### Test helpers (S7-02)

| File | Purpose |
|------|---------|
| `tests/helpers/scenario_runner_test_seam.gd` | State enum constant-map access per IN-1 + G-3 (no class_name) |
| `tests/helpers/destiny_branch_judge_stub.gd` | Test-only DestinyBranchJudge subclass with set_sp1_output(...) injection — shared with destiny-branch S7-03 |

### Modified test files (existing — required for signal contract update)

| File | Change |
|------|--------|
| `tests/unit/core/game_bus_declaration_test.gd` | 29 → 30 signals (added scenario_fault); ChapterResult / ScenarioResult Resource arg classes updated |
| `tests/unit/core/signal_contract_test.gd` | scenario_complete payload widened String → ScenarioResult per delta #12; scenario_fault entry added |
| `tests/unit/core/game_bus_diagnostics_test.gd` | scenario_fault → "scenario" domain routing |
| `tests/integration/feature/battle_scene/battle_scene_smoke_test.gd` | AC-5 PHASE-FLIPPED: markers MUST NOT exist (1st-precedent phase-flipping test) |

---

## §D. Lint verification

All 6 lints (5 new + 1 phase-flipped) pass:

| Lint | Pattern | Status |
|------|---------|--------|
| `lint_scenario_runner_state_match_exhaustive.sh` | scenario_runner_arbitrary_state_jump | ✅ PASS |
| `lint_scenario_runner_branch_table_immutable.sh` | scenario_runner_branch_table_runtime_mutation | ✅ PASS |
| `lint_scenario_runner_save_context_complete.sh` | scenario_runner_save_context_partial_emit | ✅ PASS |
| `lint_scenario_runner_no_deferred_in_beat_7_seal.sh` | scenario_runner_deferred_seal_in_beat_7_entry (Pillar 2 lock 2nd precedent) | ✅ PASS |
| `lint_scenario_runner_outcome_synthesis.sh` | scenario_runner_outcome_synthesis (CR-3 invariant) | ✅ PASS |
| `lint_battle_scene_sprint6_mock_marker.sh` (PHASE-FLIPPED) | battle_scene_sprint6_mock_marker_must_exist (semantic inverted to "MUST NOT exist") | ✅ PASS |

CI wiring: not yet added to `.github/workflows/tests.yml` — to be picked up when CI workflow file is next touched (no breaking change from current state since the lints are runnable from the repo root standalone).

---

## §E. Files shipped (single coordinated patch)

**Source files** (8): scenario_runner.gd + chapter_definition.gd + scenario_result.gd + chapter_result.gd (extended) + destiny_branch_choice.gd (replaced stub) + destiny_branch_judge.gd (@abstract base) + default_destiny_branch_judge.gd (concrete stub) + game_bus.gd (modified — scenario_complete payload + scenario_fault declaration)

**Modified existing source** (3): battle_scene.gd (mock encoder DELETED + ScenarioRunner integration) + project.godot (autoload registration + main_scene comment update) + balance_entities.json (SCENARIO_PROGRESSION_ECHO_CAP=100)

**Data file** (1): assets/data/scenarios/mvp_shu.json (chapter-1 stub fixture)

**Lint scripts** (5 new + 1 modified): all in tools/ci/

**Test files** (8): 6 new + 2 helpers + 4 modified existing

**Evidence docs** (4): battle_scene_smoke_2026-05-05.md (re-authored) + battle_scene_smoke_2026-05-04_sprint6_archived.md (renamed) + scenario_runner_3_chapter_mvp_2026-05-05.md (new) + scenario_runner_verification_summary.md (this file) + battle_scene_verification_summary.md §E append

**Architecture registry** (1): docs/registry/architecture.yaml — battle_scene_sprint6_mock_marker_must_exist description revised + revised: 2026-05-05 annotation

**Total**: 26 files in single coordinated patch per AC-ATOMIC-1.

---

## §F. Documented deviations from ADR-0017 Migration Plan

1. **Step 8 — `project.godot` main_scene revert**: NOT performed. No revert target exists yet (Main Menu / Overworld scenes do not exist at sprint-7 close). Inline comment updated. Re-evaluated at sprint-8+ when those scenes land.
2. **Step 12 — 5 ScenarioRunner CI lints**: ALL 5 shipped same-patch per Decision E (promoted from "deferred" to "in scope" via sprint-7 plan DoD).
3. **`assets/data/maps/mvp_chapter_01.tres`**: NOT shipped. No existing maps/ dir with .tres write convention. BattleScene._build_map_resource_for_chapter constructs 15×15 grass inline. S7-05 introduces .tres asset write convention with chapter-1 narrative content.
4. **AISystem mount step 5.5**: documentation-only update via delta #14; physical mount call site insertion is S7-04 scope.
5. **EchoMark.outcome StringName vs int**: AC-SP-19 spec divergence — shipped 3-field schema uses StringName per ADR-0003 §EchoMark Resource Contract; story line 45 acknowledges this divergence.
6. **CI workflow update**: 5 lints + 1 flipped lint not yet wired into `.github/workflows/tests.yml`. Lint scripts are standalone-runnable; CI wiring is a small follow-up touch.

---

## §G. Architectural patterns ratified by this story

- **Pillar 2 architectural lock 2nd precedent**: `scenario_runner_deferred_seal_in_beat_7_entry` (after `battle_hud_subscribes_to_hidden_fate_signal`); pattern stable at 4 invocations after this delta.
- **Phase-flipping lint pattern 1st precedent**: same lint script, semantic flipped at ADR-acceptance commit (`battle_scene_sprint6_mock_marker_must_exist` 2026-05-03 → 2026-05-05).
- **Phase-flipping test pattern 1st precedent**: same test function, semantic flipped at acceptance commit (`test_battle_scene_source_contains_sprint6_mock_markers` 2026-05-04 → 2026-05-05).
- **Autoload Node 6th invocation pattern**: ScenarioRunner extends Node + NO class_name (G-3) + boot order position 6 (after 5-precedent autoload chain).
- **Enum + match state machine 2nd invocation pattern**: ScenarioRunner 13-state enum + `_transition_to(target)` mirrors SceneManager 5-state precedent.
- **typed-Resource-from-JSON 4th invocation pattern**: ChapterDefinition mirrors MapResource + HeroData + BalanceConstants precedent.

---

## §H. Cross-references

- ADR-0017 (Accepted 2026-05-04) — governing
- ADR-0016 §Migration Plan §1 (mock encoder DELETION); §3 R-3 (mount sequence amended via delta #14 for AISystem step 5.5)
- ADR-0018 (DestinyBranchJudge — minimal stub for S7-02; full F-DB-1 in S7-03)
- ADR-0019 (AISystem — mount step 5.5 deferred to S7-04)
- design/gdd/scenario-progression.md rev 2.2 — F-SP-1..F-SP-6 + EC-SP-1..14 + AC-SP-1..19
- production/epics/scenario-progression/story-001 (this story)
- production/qa/evidence/scenario_runner_3_chapter_mvp_2026-05-05.md (V-2 + V-3 evidence)
- production/qa/evidence/battle_scene_smoke_2026-05-05.md (post-mock-deletion launch path)
- production/qa/evidence/battle_scene_verification_summary.md §E (Migration Plan revert chapter)
- tests/integration/scenario_runner/scenario_runner_chapter_1_traversal_test.gd (chapter-fixture coverage)
- 5 ScenarioRunner-domain lint scripts in tools/ci/
- docs/registry/architecture.yaml — phase-flipped forbidden_pattern entry
