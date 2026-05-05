# Story 001: ScenarioRunner implementation per ADR-0017 Migration Plan §1..§11 + sprint-6 mock encoder DELETION

> **Epic**: scenario-progression
> **Status**: Complete (2026-05-05 — single coordinated patch ba02e02; 911/911 tests + 6/6 lints PASS)
> **Layer**: Core
> **Type**: Integration (multi-system orchestration: ScenarioRunner ↔ GameBus ↔ SceneManager ↔ SaveManager ↔ GridBattleController ↔ DestinyBranchJudge ↔ BattleScene)
> **Manifest Version**: 2026-05-04 (`docs/architecture/control-manifest.md` — refreshed via gate-check pre-prod-to-prod-2026-05-04 path-to-PASS item #3)
> **Sprint Slot**: S7-02 (sprint-7 critical path; 0.6d nominal estimate per sprint-7 plan; 4th consecutive AI #1 ratchet)
> **Epic-terminal**: Yes — closes scenario-progression epic at story completion

## Context

**GDD**: `design/gdd/scenario-progression.md` rev 2.2

**Requirements**: `TR-scenario-progression-001..015` (all 15 — per epic terminal scope; tr-registry.yaml v15)

*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0017 Scenario Progression (Accepted 2026-05-04 via /architecture-review delta #12)

**ADR Decision Summary**: ScenarioRunner autoload Node + 13-state enum FSM + ChapterDefinition typed Resource hydrated from JSON + 7-signal contract emission (5 confirmed + 2 ratified delta #12) + F-SP-3 v2.2 SYNCHRONOUS seal at BEAT_7 entry (Pillar 2 architectural lock 2nd precedent) + F-SP-1/F-SP-2 delegation to DestinyBranchJudge + retry-loop guard + 3-CP save + 5 forbidden_patterns. ADR-0017 §Migration Plan §1..§11 explicitly mandates **single coordinated patch atomicity** per line 525.

**Engine**: Godot 4.6 | **Risk**: LOW (ADR-0017 own engine surface) / HIGH (transitive via ADR-0018 DestinyBranch StringName field-type preservation through ResourceSaver/Loader)

**Engine Notes**: Pre-4.4 stable APIs only (Node autoload + Resource @export + JSON.parse_string + FileAccess.get_file_as_string + signal declarations). G-3 autoload pattern: NO `class_name` in scenario_runner.gd (autoload-registered identifier IS the global name). Implementation Notes IN-1 (test fixture State enum access via constant-map for headless tests per G-3) + IN-2 (Time.get_ticks_msec() requirement vs deprecated OS.get_ticks_msec()). `Resource.duplicate_deep()` parameterless form per breaking-changes.md 4.4→4.5 (NOT `duplicate(true)` per deprecated-apis.md). `JSON.new().parse()` instance form for line/col diagnostics per HeroDatabase precedent.

**Control Manifest Rules (Core layer + Scenario domain)**:
- **Required**: Autoload registered at boot order position 6 (after GameBus → SceneManager → SaveManager → GameBusDiagnostics → BuildModeSentinel) per ADR-0017 §Decision §Class Form. State machine transitions exclusively via `_transition_to(target: State)` method per `scenario_runner_arbitrary_state_jump` forbidden_pattern. F-SP-3 v2.2 SYNCHRONOUS seal at BEAT_7 entry (NO call_deferred / NO CONNECT_DEFERRED / NO await between BEAT_6 exit and BEAT_7 seal) per `scenario_runner_deferred_seal_in_beat_7_entry` Pillar 2 architectural lock 2nd precedent.
- **Forbidden**: `_state =` direct assignment outside `_transition_to()` (per `scenario_runner_arbitrary_state_jump`). Runtime mutation of `chapter.branch_table[key]` (per `scenario_runner_branch_table_runtime_mutation`). Partial SaveContext emission outside `_make_save_context(cp_kind)` helper (per `scenario_runner_save_context_partial_emit`). Asynchronous BEAT_7 entry (per `scenario_runner_deferred_seal_in_beat_7_entry`). Assigning or overriding `BattleOutcome.result` (per `scenario_runner_outcome_synthesis` + CR-3 invariant). Reading hidden_fate_condition_progressed / DestinyBranchChoice / destiny_branch_chosen tokens (Pillar 2 architectural lock — but ScenarioRunner IS the canonical emitter of destiny_branch_chosen, so reads are scoped to its own emission path only per CR-DB-4 emission ownership).
- **Guardrail**: <50ms one-shot at LOADING entry (JSON parse + 5-chapter validation). Per-frame cost in steady state: 0ms (event-driven; no `_process` body). Per-state-transition cost: <0.1ms (enum match + signal emit). Per-retry-loop cost: <0.5ms. Total ScenarioRunner footprint: <20 KB resident memory.

---

## Acceptance Criteria

*From GDD `design/gdd/scenario-progression.md` §AC-SP-1..AC-SP-19 (fixture-independent + chapter-1 stub fixture scope; v2.2 qa-lead 41-AC sub-classification per GDD lines 1181-1184). MVP scope ships all 10 fixture-independent ACs + 5 chapter-1-fixture ACs; remaining 26 deferred to chapter-2+ content authoring + sprint-7 S7-05 chapter-1 .tres full content authoring + sprint-7 S7-06+S7-07 Story Event #10 + Destiny State #16 GDD authoring.*

### Fixture-independent ACs (testable immediately per GDD line 1182)

- [ ] **AC-SP-3** (CR-3 tri-state preservation) — Given ScenarioRunner is in BEAT_5_BATTLE and Grid Battle emits `battle_outcome_resolved` with `result = DRAW`, when ScenarioRunner advances to BEAT_7_JUDGMENT, then `resolve_branch()` receives `outcome == DRAW` (not WIN, not LOSS). ScenarioRunner must not convert, round, or override the received tri-state value. Lint-enforced via `scenario_runner_outcome_synthesis` forbidden_pattern.
- [ ] **AC-SP-5** (CR-7 echo accumulation + retry signal) — Given a chapter where the player chooses "Retry" at Beat 6 three times, when ScenarioRunner reaches BEAT_7_JUDGMENT entry, then `state.echo_count == 3` and exactly 3 `scenario_beat_retried` signals have been emitted on GameBus. When Beat 9 fires, `state.echo_count == 0` immediately after transition.
- [ ] **AC-SP-13** (CR-15 forward-only invariant + no arbitrary-jump API) — (a) Given ScenarioRunner is in any state other than BEAT_6_RESULT, when any state transition is requested, then the resulting state has a higher ordinal than the current state (forward-only invariant). The only permitted backward transition is BEAT_6_RESULT → BEAT_4_PREP. (b) No public arbitrary-jump API exists in the implementation (verify via source-grep: `_state =` direct assignment outside `_transition_to()` body returns 0 matches).
- [ ] **AC-SP-16** (ADR-0001 cross-scene routing) — Given ScenarioRunner emits `chapter_started(ChapterContext)`, then all downstream consumers (Grid Battle, UI layer) receive the signal via `/root/GameBus` and not via a direct scene signal connection. Verify by asserting no `connect()` calls between ScenarioRunner and Grid Battle or UI scene nodes exist in source.
- [ ] **AC-SP-18** (DestinyBranchChoice payload completeness) — Given a chapter with `author_draw_branch = true` and a DRAW outcome, when `destiny_branch_chosen(DestinyBranchChoice)` is emitted, then payload contains all 9 fields: `chapter_id: String`, `branch_key: String`, `outcome: Result` (value == DRAW), `echo_count: int`, `is_draw_fallback: bool` (value == false), `is_canonical_history: bool`, `reserved_color_treatment: bool`, `is_invalid: bool` (value == false), `invalid_reason: StringName` (value == &"" empty). Per ADR-0001 9-field RATIFIED payload via Evolution Rule #4 minor amendment delta #13.
- [ ] **AC-SP-19** (scenario_beat_retried payload — RATIFIED per delta #12) — Given a player retry at Beat 6, when `scenario_beat_retried(EchoMark)` is emitted, then payload contains the SHIPPED 3-field EchoMark schema per ADR-0003 §Schema Stability + `src/core/payloads/echo_mark.gd`: `beat_index: int`, `outcome: int` (BattleOutcome.Result enum), `tag: StringName`. Note: GDD AC-SP-19 originally specified provisional 4-field shape (chapter_id/beat_number/retry_count/timestamp_unix); this was superseded by delta #12 ratification with shipped 3-field EchoMark — story implements shipped form per architecture registry.
- [ ] **AC-SP-21** (3-CP save emission timing — fixture-independent subset) — Given ScenarioRunner enters BEAT_1_ANCHOR (CP-1), when the 1s tap-lockout completes, then `save_checkpoint_requested(SaveContext)` is emitted on GameBus with all SaveContext required fields populated per `_make_save_context(SaveCheckpoint.CP_1)` helper. Same assertion at BEAT_7_JUDGMENT entry post-seal (CP-2) and BEAT_9_TRANSITION entry (CP-3). Lint-enforced via `scenario_runner_save_context_partial_emit` forbidden_pattern.
- [ ] **AC-SP-25** (state machine no `_process` body) — Verify ScenarioRunner has no `_process` or `_physics_process` body. State machine is event-driven (signal-handler + timer-callback). Verify via source-grep: `func _process` + `func _physics_process` return 0 matches in src/core/scenario_runner.gd.
- [ ] **AC-SP-32** (forbidden_pattern lint enforcement) — All 5 forbidden_pattern lints pass: `lint_scenario_runner_state_match_exhaustive.sh` (state machine arbitrary-jump prevention) + `lint_scenario_runner_branch_table_immutable.sh` (runtime mutation prevention) + `lint_scenario_runner_save_context_complete.sh` (partial-emit prevention via single-helper enforcement) + `lint_scenario_runner_no_deferred_in_beat_7_seal.sh` (Pillar 2 architectural lock 2nd-precedent) + `lint_scenario_runner_outcome_synthesis.sh` (CR-3 single-emitter ownership enforcement).
- [ ] **AC-SP-33** (ADR-0017 V-1 boot-order verification) — Verify autoload boot order in project.godot: GameBus → SceneManager → SaveManager → GameBusDiagnostics → BuildModeSentinel → **ScenarioRunner** (position 6). Test via integration test loading the autoload stack + asserting `ScenarioRunner._ready()` completes without crash on `GameBus.battle_outcome_resolved.connect(...)`.

### Chapter-1 stub fixture ACs (testable with chapter-1 .tres scaffold)

- [ ] **AC-SP-1** (CR-1 chapter linear progression) — Given chapter-1 (장판파) scenario JSON loads at LOADING entry, when ScenarioRunner processes the chapter to completion, then chapter executes in correct index order and is not skipped or repeated. (Chapter-2..N scope deferred to S7-05 chapter-1 .tres + future chapter authoring.)
- [ ] **AC-SP-2** (CR-2 9-beat canonical rhythm) — Given chapter-1 at CHAPTER_START, when the chapter runs to BEAT_9_TRANSITION, then exactly 9 beat-state transitions fire in order: BEAT_1_ANCHOR → BEAT_2_ECHO → BEAT_3_BRIEF → BEAT_4_PREP → BEAT_5_BATTLE → BEAT_6_RESULT → BEAT_7_JUDGMENT → BEAT_8_REVEAL → BEAT_9_TRANSITION. Any deviation in order or count is a test failure.
- [ ] **AC-SP-9** (Beat 9 chapter_completed emission + echo reset) — Given Beat 9 entry with more chapters remaining, when `chapter_completed(ChapterResult)` is emitted and ScenarioRunner transitions to the next chapter's LOADING, then (a) `echo_count = 0` in ScenarioRunner state, (b) `ChapterResult` payload contains `chapter_id`, `branch_path_id`, and `echo_count_at_completion` fields. Given the last chapter, `scenario_complete(ScenarioResult)` is emitted instead and ScenarioRunner enters SCENARIO_END.
- [ ] **AC-SP-17** (5+1 confirmed signal contract emission) — Given ScenarioRunner is wired to GameBus per ADR-0001, when one full chapter completes (no retry), then exactly these 5 confirmed signals are emitted in order on GameBus: `chapter_started`, `battle_prepare_requested`, `battle_launch_requested`, `destiny_branch_chosen`, `chapter_completed`. No signal named `battle_complete` is emitted (rename enforcement). Note: `destiny_branch_chosen` is emitted by ScenarioRunner at BEAT_7_JUDGMENT exit (post-tap-advance) NOT by DestinyBranchJudge per CR-DB-4 emission ownership.
- [ ] **AC-SP-20** (CP-3 SaveContext field completeness) — Given Beat 9 entry, when `save_checkpoint_requested(SaveContext)` is emitted as CP-3, then payload `SaveContext` contains at minimum: `chapter_id`, `outcome`, `branch_key`, `echo_count`, `echo_marks_archive`, `flags_to_set`. When CP-2 fires (post-Beat-7), `SaveContext.outcome` matches the `BattleOutcome.result` received at Beat 5 with no modification.

### Validation Criteria from ADR-0017 §Validation Criteria

- [ ] **V-1**: Autoload boot order verified (GameBus → SceneManager → SaveManager → GameBusDiagnostics → BuildModeSentinel → ScenarioRunner) — covered by AC-SP-33
- [ ] **V-2**: `JSON.parse_string` performance on chapter-1 stub <50ms cold load on Snapdragon 7-gen reference (Linux Editor + Windows D3D12 CI lanes only per sprint-7 R-3; macOS / iOS / Android manual-fallback)
- [ ] **V-3**: `Resource.duplicate_deep()` parameterless form semantics on `ChapterDefinition` for sprint-7+ retry-loop snapshot pattern (used to preserve original branch_table across runtime per `scenario_runner_branch_table_runtime_mutation` forbidden_pattern)

### Sprint-6 mock encoder DELETION + main_scene revert + lint flip (ADR-0016 §Migration Plan §1)

- [ ] **AC-MIGRATE-1** — Sprint-6 inline mock encoder DELETED from `src/feature/battle_scene/battle_scene.gd` (~50 LoC mock encoder block between `# === SPRINT-6 MOCK ENCOUNTER ===` / `# === END MOCK ===` markers + 4 helper methods between `# === SPRINT-6 MOCK ENCOUNTER HELPERS ===` / `# === END SPRINT-6 MOCK ENCOUNTER HELPERS ===` markers all removed). Call site replaced with `var battle_config: BattlePayload = ScenarioRunner.get_active_battle_config()` per ADR-0017 §Decision §`BattleConfig`.
- [ ] **AC-MIGRATE-2** — `project.godot` `[application] run/main_scene` reverted from `res://scenes/battle/battle_scene.tscn` back to title-screen / overworld entry per ADR-0002 SceneManager standard flow (sprint-7+ implementation-time decision per ADR-0017 §Migration Plan Step 8 — likely `scenes/main_menu/main_menu.tscn` if Main Menu epic exists, else `scenes/overworld/overworld.tscn`, else placeholder until Main Menu / Overworld epic ships).
- [ ] **AC-MIGRATE-3** — Phase-flipping lint flip: `tools/ci/lint_battle_scene_sprint6_mock_marker.sh` semantic flips from "marker MUST exist" → "marker MUST NOT exist" (mechanical edit to bash script loop body: change `if ! grep ... ; FAILED=1` to `if grep ... ; FAILED=1`); `battle_scene_sprint6_mock_marker_must_exist` forbidden_pattern semantic inversion same-patch (registry entry description amended to reflect post-mock state). **1st-precedent phase-flipping lint pattern in the project.**
- [ ] **AC-MIGRATE-4** — Re-author smoke evidence doc at `production/qa/evidence/battle_scene_smoke_2026-XX-XX.md` (sprint-7+ date) covering the new launch path (SceneManager-driven launch source (a) per ADR-0016 V-11; cross-launch-source matrix updated). Old `battle_scene_smoke_2026-05-04.md` archived (NOT deleted) for traceability.
- [ ] **AC-MIGRATE-5** — Update `production/qa/evidence/battle_scene_verification_summary.md` §E to close the Migration Plan revert chapter with a note that Steps 7-10 completed at this commit.

### Atomicity (ADR-0017 §Migration Plan line 525)

- [ ] **AC-ATOMIC-1** — Steps 1-11 of ADR-0017 §Migration Plan ship in a **single commit** (single coordinated patch atomicity per ADR explicit mandate). No intermediate state where ScenarioRunner exists but mock encoder NOT deleted (would leave dual-init paths) OR mock encoder DELETED but ScenarioRunner NOT functional (would crash BattleScene._ready()).

---

## Implementation Notes

*Derived from ADR-0017 §Decision + §Migration Plan §1..§11 + Implementation Notes IN-1 + IN-2:*

### File Layout (11 new/modified files + 1 archived)

**New source files** (Migration Plan §1-§4):

1. `src/core/scenario_runner.gd` (~600-800 LoC per ADR-0017 §Migration Plan §1) — `extends Node` (NO `class_name` per G-3 autoload rule); 13-state enum + match-statement + `_transition_to(target: State)` method + ChapterDefinition Resource hydration + JSON validation pipeline + 9-beat per-state entry/exit handlers + 7-signal emission paths + retry-loop guard + F-SP-3 v2.2 synchronous seal + DestinyBranchJudge.resolve() call site + `_make_save_context(cp_kind: SaveCheckpoint)` helper + 3-CP save integration

2. `src/core/payloads/chapter_definition.gd` (~50-80 LoC) — `class_name ChapterDefinition extends Resource` with 13 @export fields per ADR-0017 §Decision §Chapter Data Form (chapter_id: String + map_id: String + author_draw_branch: bool + echo_threshold: int + branch_table: Dictionary [UNTYPED per GDScript 4.6 G-2 prohibition; runtime keys are composite-shape Strings per F-SP-1] + canonical_branch_key: String + chokepoints: Array[Vector2i] + enemy_roster: Array[Dictionary] [archetype: StringName field per ADR-0019 §Migration Plan §8] + beat_1_text/beat_3_text/beat_8_branch_texts/beat_9_text per scenario-progression.md §Detailed Design)

3. `src/core/payloads/scenario_result.gd` (~30 LoC) — `class_name ScenarioResult extends Resource` with 4-field shape per ADR-0017 §CR-16 + F-SP-4 (chapter_outcomes: Array[ChapterResult] + canonical_delta: int + scenario_path_key: String + total_echo: int)

4. `src/core/payloads/chapter_result.gd` (~30 LoC) — `class_name ChapterResult extends Resource` with 4-field shape per ADR-0001 line 146 + F-SP-3 (chapter_id: String + branch_path_id: String + echo_count_at_completion: int + outcome: int [BattleOutcome.Result enum])

**New data file** (Migration Plan §5):

5. `assets/data/scenarios/scenario_01.json` (chapter-1 (장판파) scaffold) — minimal 1-chapter MVP authored content per ADR-0017 §JSON Schema. Sprint-7 S7-05 chapter-1 .tres authoring will fill out narrative content; this story ships the structural scaffold for ScenarioRunner integration tests. Schema MUST validate per EC-SP-8 (FATAL on malformed branch_table or missing canonical_branch_key).

**Existing files modified** (Migration Plan §6-§9):

6. `project.godot` — register `*res://src/core/scenario_runner.gd` in `[autoload]` section at boot order position 6 (after BuildModeSentinel) + `[application] run/main_scene` reverted from `res://scenes/battle/battle_scene.tscn` back to title-screen / overworld entry per AC-MIGRATE-2

7. `src/feature/battle_scene/battle_scene.gd` — sprint-6 inline mock encoder block DELETED (~50 LoC + 4 helper methods); call site replaced with `var battle_config: BattlePayload = ScenarioRunner.get_active_battle_config()` per AC-MIGRATE-1

8. `tools/ci/lint_battle_scene_sprint6_mock_marker.sh` — semantic flip from "marker MUST exist" → "marker MUST NOT exist" (mechanical edit to loop body) + inline header comment block update per AC-MIGRATE-3

**Architecture registry update** (Migration Plan implicit; integrates with delta #14 prior work):

9. `docs/registry/architecture.yaml` — `battle_scene_sprint6_mock_marker_must_exist` forbidden_pattern description amended to reflect post-mock state (semantic inversion); `revised: 2026-XX-XX` annotation added

**New test files** (~25-30 tests across ~5-7 files per sprint-7 plan + ADR §Validation Criteria):

10. `tests/unit/core/scenario_runner_state_machine_test.gd` — AC-SP-3 + AC-SP-13 + AC-SP-25 (forward-only invariant + no-arbitrary-jump + no-_process); ~6-8 tests
11. `tests/unit/core/scenario_runner_signal_contract_test.gd` — AC-SP-16 + AC-SP-17 + AC-SP-18 + AC-SP-19 + AC-SP-20 (5+1 confirmed signal emission + payload contracts); ~6-8 tests
12. `tests/unit/core/scenario_runner_retry_loop_test.gd` — AC-SP-5 + CR-7 echo accumulation + reset; ~4-5 tests
13. `tests/unit/core/scenario_runner_save_context_test.gd` — AC-SP-21 + AC-SP-20 + `_make_save_context()` helper completeness assertion (CP-1 + CP-2 + CP-3 timing + payload completeness); ~4-5 tests
14. `tests/unit/core/chapter_definition_validation_test.gd` — EC-SP-8 (FATAL on malformed branch_table + missing canonical_branch_key + DRAW invariant violations); ~4-5 tests
15. `tests/integration/scenario_runner/scenario_runner_chapter_1_traversal_test.gd` — AC-SP-1 + AC-SP-2 + AC-SP-9 (full chapter-1 traversal with mocked GridBattleController + GameBus capture; assertion of 5+1 signal emissions at correct state boundaries; 3-CP timing); ~3-4 tests

**5 new lint scripts** (per sprint-7 plan DoD; ADR-0017 §Forbidden Patterns + Migration Plan Step 12 promoted to S7-02 scope per sprint-7 plan):

16. `tools/ci/lint_scenario_runner_state_match_exhaustive.sh` — verifies match-statement exhaustively covers all 13 enum members + grep `_state =` outside `_transition_to()` body returns 0 matches
17. `tools/ci/lint_scenario_runner_branch_table_immutable.sh` — grep for `\.branch_table\[.*\] =` and `\.branch_table\.erase\|\.branch_table\.clear` patterns in src/ — all matches FAIL
18. `tools/ci/lint_scenario_runner_save_context_complete.sh` — grep for `SaveContext.new()` matches OUTSIDE `_make_save_context()` body in scenario_runner.gd — all matches FAIL
19. `tools/ci/lint_scenario_runner_no_deferred_in_beat_7_seal.sh` — grep for `call_deferred.*beat_7|beat_7.*call_deferred|CONNECT_DEFERRED.*beat_7` patterns in scenario_runner.gd — all matches FAIL (Pillar 2 architectural lock 2nd precedent)
20. `tools/ci/lint_scenario_runner_outcome_synthesis.sh` — grep for `result\s*=` in src/core/scenario_runner.gd where LHS is BattleOutcome — all matches FAIL (CR-3 single-emitter ownership)

All 5 lints wired into `.github/workflows/tests.yml` after the existing 5 hp-status / 5 destiny-branch lint groups.

**Test helpers** (per IN-1 G-3 §Test consequence):

21. `tests/helpers/scenario_runner_test_seam.gd` — constant-map for State enum access per IN-1 (`(load("res://src/core/scenario_runner.gd") as GDScript).get_script_constant_map()`); used by unit tests that load the script directly without booting the full autoload stack

22. `tests/helpers/destiny_branch_judge_stub.gd` — minimal `class_name TestDestinyBranchJudgeWithSp1Stub extends DestinyBranchJudge` with instance-level `_stub_output` Dictionary + `set_sp1_output(output: Dictionary)` setter; used by ScenarioRunner unit tests to inject F-SP-1 outputs (used at BEAT_7 entry test path); NOTE: this helper file is shared with destiny-branch S7-03 epic implementation per pre-resolved coordination decision below

**Smoke evidence + verification summary** (per ADR-0017 §Validation Criteria + §Migration Plan §10-§11):

23. `production/qa/evidence/battle_scene_smoke_2026-XX-XX.md` (re-authored per AC-MIGRATE-4) — covers the new launch path (SceneManager-driven launch source (a) per ADR-0016 V-11; cross-launch-source matrix updated)
24. `production/qa/evidence/battle_scene_verification_summary.md` (§E updated per AC-MIGRATE-5) — closes Migration Plan revert chapter
25. `production/qa/evidence/scenario_runner_3_chapter_mvp_2026-XX-XX.md` (NEW per ADR-0017 §Validation Criteria — smoke evidence) — documents full chapter-1 playthrough with Beat 7 reserved-color treatment trigger via art-bible §4.7 (Beat 7 reveal binding via reserved_color_treatment payload field); chapter-2..N coverage deferred to future chapter authoring
26. `production/qa/evidence/scenario_runner_verification_summary.md` (NEW) — covers all 15 TR-scenario-progression-* satisfaction proofs

### Pre-resolved coordination decisions (per dev-story spawn prompt)

These decisions are pre-resolved at story authoring time per multi-spawn-on-scale precedent from hp-status story-008 + ADR-0014 architectural drift retrospective:

- **Decision A (DestinyBranchJudge stub scope for S7-02)**: scenario-progression story-001 ships **MINIMAL DestinyBranchJudge scaffolding** (3 source files at `src/core/payloads/destiny_branch_choice.gd` + `src/feature/destiny_branch/destiny_branch_judge.gd` + `src/feature/destiny_branch/default_destiny_branch_judge.gd`) sufficient for ScenarioRunner BEAT_7_JUDGMENT entry call site to compile + tests to pass via TestDestinyBranchJudgeWithSp1Stub injection. The `_apply_f_sp_1` body in DefaultDestinyBranchJudge is **STUBBED** (returns hardcoded placeholder Dictionary that satisfies F-DB-3 minimal contract for chapter-1 stub fixture). destiny-branch S7-03 fills in the full F-DB-1 algorithm body + invariant_violation vocabulary + 3 lints + integration test (V-12 thread-safety) + 5-platform serialization scaffold per ADR-0018 §Migration Plan §5. **Coordinate with S7-03 author**: this story's stubbed _apply_f_sp_1 body MUST be replaced (not extended) by S7-03's authoritative impl; this story's tests MUST NOT depend on the stub body's behavior beyond the minimal F-DB-3 contract.

- **Decision B (chapter-1 .tres scope)**: this story ships a **MINIMAL chapter-1 .tres scaffold** (sufficient for AC-SP-1 + AC-SP-2 + AC-SP-9 + AC-SP-17 chapter-1-fixture ACs to pass) — full chapter-1 (장판파) narrative content authoring is sprint-7 S7-05 should-have. Coordinate scope split: this story owns the ChapterDefinition Resource shape + minimal .tres data + JSON validation pipeline; S7-05 owns the full chapter-1 narrative content (Beat 1/2/3/8/9 texts + branch_table content + chokepoints + enemy_roster archetype assignments per ADR-0019 §Migration Plan §8).

- **Decision C (AISystem hooks deferred to S7-04)**: ChapterDefinition.enemy_roster Dictionary entries MAY include `archetype: StringName` field per ADR-0019 §Migration Plan §8, but ScenarioRunner does NOT validate or consume this field at this story's scope — sprint-7 S7-04 AISystem implementation will read the field at chapter-load via `unit.get("archetype", &"aggressor")` per AI System GDD CR-AI-2 default fallback (caller responsibility per EC-AI-4). This story's chapter-1 .tres scaffold MAY include archetype assignments as scaffolding for S7-04 same-sprint integration; if scope creep, defer archetype field to S7-04.

- **Decision D (Save/Load #17 GDD CUT — in-memory CP-1/2/3 satisfies sprint-7 demo)**: per Producer pressure-cut decision in sprint-7 plan, Save/Load #17 VS GDD authoring is deferred to sprint-8. This story emits `save_checkpoint_requested(SaveContext)` per ADR-0017 §3-CP timing but does NOT verify SaveManager actually persists the SaveContext to disk (out of scope per sprint-7 plan). AC-SP-21 + AC-SP-20 verify the EMISSION + payload completeness, not the persistence round-trip.

- **Decision E (ScenarioRunner CI hardening lints inclusion)**: ADR-0017 §Migration Plan Step 12 originally deferred 3 lints (state_match_exhaustive + no_deferred_in_beat_7_seal + branch_table_immutable) to a follow-up sprint-7+ story. Sprint-7 plan promotes ALL 5 lints (including the 2 inline-enforced patterns: save_context_partial_emit + outcome_synthesis) to S7-02 scope per Definition of Done. This story ships all 5 lints same-patch.

- **Decision F (Phase-flipping lint flip atomicity)**: AC-MIGRATE-3 phase-flipping lint flip MUST happen in the same commit as AC-MIGRATE-1 (mock encoder DELETION). Otherwise: (a) intermediate state where mock encoder DELETED but lint still asserts "marker MUST exist" = lint fails immediately on commit; (b) intermediate state where lint flipped to "marker MUST NOT exist" but mock encoder NOT yet deleted = lint fails on next commit. Atomicity is mechanically enforced by the single-commit Migration Plan §1 framing.

### Multi-spawn-on-scale precedent (per hp-status story-008 + active.md)

This story's deliverable scale is **larger than hp-status story-008 (12 files / ~680s / 3-spawn precedent)**:

- ~22-26 files (3 source + 4 typed Resources + 1 JSON data + 4 modified existing files + ~7 test files + 5 lint scripts + 4 test helpers + 4 evidence/summary docs)
- ~600-800 LoC source code + ~25-30 test functions
- Single coordinated patch atomicity per ADR-0017 §Migration Plan line 525

**Expected /dev-story spawn pattern**: 1 initial spawn + 2-3 SendMessage continuations per multi-spawn-on-scale precedent. Pre-resolved coordination decisions A-F above reduce the SendMessage round-trip count by frontloading scope clarifications.

**Alternative if /dev-story context budget exceeded**: split into 3 follow-up stories per scenario-progression EPIC.md Option B (foundational scaffolding + behavior + integration cleanup). Decision deferred to /dev-story spawn-time scope verification.

---

## Out of Scope

*Handled by neighbouring stories or future sprints — do not implement here:*

- **DestinyBranchJudge full F-DB-1 algorithm body** — destiny-branch S7-03 single coordinated patch per ADR-0018 §Migration Plan §5; this story ships MINIMAL stub per Decision A
- **DestinyBranchJudge 3 forbidden_patterns lints** — destiny-branch S7-03 owns (no_gamebus_emit + no_static_var + no_scenario_runner_state_read Pillar 2 lock 3rd precedent)
- **DestinyBranchChoice 5-platform serialization scaffold** — destiny-branch S7-03 owns per ADR-0018 OQ-DB-6 (this story uses Linux Editor + Windows D3D12 lanes via stub per sprint-7 R-3)
- **AISystem implementation** — sprint-7 S7-04 single coordinated patch per ADR-0019 §Migration Plan §2..§5; this story may include `archetype: StringName` field in chapter-1 .tres scaffolding per Decision C
- **Chapter-1 (장판파) full narrative content authoring** — sprint-7 should-have S7-05 (this story ships MINIMAL .tres scaffold per Decision B)
- **Story Event #10 + Destiny State #16 GDD authoring** — sprint-7 should-have S7-06 + S7-07 (each consumes DestinyBranchChoice 9-field payload contract; UNBLOCKED by ADR-0018 acceptance via delta #13)
- **Save/Load #17 VS GDD authoring** — CUT from sprint-7 per Producer pressure-cut decision (in-memory CP-1/2/3 satisfies sprint-7 demo per Decision D)
- **Battle Preparation epic** — post-MVP per scenario-progression.md interaction §Battle Preparation; this story establishes the `battle_prepare_requested` emission point that future Battle Prep epic will subscribe to
- **Multi-chapter (chapter-2..N) authoring** — chapter-1 only for MVP per CR-AI-3 closed scope; chapter-2..N authoring is separate post-MVP scenario authoring pass
- **GDD-AC-SP-7 Visual/Feel ADVISORY** (Beat 7 reserved-color treatment digital color picker tolerance) — deferred to art-team verification at chapter-1 implementation; NOT BLOCKING for this story's Logic + Integration ACs
- **GDD-AC-SP-8 Beat 8 canonical-history contrast UI** — deferred to Story Event #10 VS GDD authoring (sprint-7 S7-06)
- **GDD-AC-SP-15(c) ADR-0002 SCENARIO_END dismissal scene-transition method** — deferred until ADR-0002 SceneManager exposes the canonical scene-transition API for SCENARIO_END exit (placeholder method MAY be used)
- **CI lint state-machine exhaustiveness verifier helper** (verifies match-statement covers all 13 enum members programmatically) — deferred; ship grep-based lint per Decision E
- **macOS / iOS / Android CI lanes for V-2 JSON parse perf verification** — sprint-7 R-3 mitigation: Linux Editor + Windows D3D12 lanes only (manual-fallback for other platforms; full 5-platform CI deferred to release-prep sprint)

---

## QA Test Cases

*Authored at story creation per skill Step 4b — QA Lead gate skipped in lean mode; orchestrator-direct authoring per project precedent. The developer implements against these test specs — do not invent new test cases during implementation.*

### Logic / Integration test specs (automated)

**AC-SP-3** (CR-3 tri-state preservation):
- Given: ScenarioRunner is in BEAT_5_BATTLE state
- When: Mocked GridBattleController emits `battle_outcome_resolved` with `BattleOutcome.result == BattleOutcome.Result.DRAW`
- Then: ScenarioRunner advances to BEAT_6_RESULT then BEAT_7_JUDGMENT (synchronous per F-SP-3 v2.2 seal); at BEAT_7_JUDGMENT entry, the ScenarioRunner's internal state shows `_last_battle_outcome.result == BattleOutcome.Result.DRAW` (not WIN, not LOSS); subsequent F-SP-1 delegation to DestinyBranchJudge.resolve(...) receives `outcome == DRAW` as 2nd argument
- Edge cases: WIN outcome (verify ScenarioRunner does not synthesize DRAW) + LOSS outcome (verify ScenarioRunner does not promote to DRAW) + bizarre outcome value (e.g., int 99) verifying preserved as-is (not coerced)

**AC-SP-5** (CR-7 echo accumulation + retry signal emission):
- Given: ScenarioRunner is in BEAT_6_RESULT state with `_last_battle_outcome.result == LOSS` and `state.echo_count == 0`
- When: `_on_player_retry()` invoked (simulating Beat 6 "Retry" tap) 3 consecutive times, each preceded by re-running BEAT_4_PREP → BEAT_5_BATTLE → BEAT_6_RESULT
- Then: At BEAT_7_JUDGMENT entry after the 3rd retry, `state.echo_count == 3`; GameBus signal capture shows exactly 3 `scenario_beat_retried(EchoMark)` emissions in temporal order; each EchoMark payload has `beat_index == 5` (BEAT_5 was the retried beat) and unique `tag` field
- Edge cases: Retry on WIN outcome (verify error pushed + no retry allowed per CR-8) + retry on echo_count == 99 (verify near-cap behavior) + retry on echo_count == 100 (verify ECHO_COUNT_HARD_CAP=100 enforcement per BalanceConstants)

**AC-SP-13** (CR-15 forward-only invariant + no arbitrary-jump API):
- Given: ScenarioRunner is in any state
- When: Test calls `_transition_to(target)` with target whose enum ordinal is LESS than current state ordinal AND target is NOT BEAT_4_PREP from BEAT_6_RESULT
- Then: `assert(false, "Illegal backward transition")` fires + state is NOT changed (verify via `get_state()` query post-call)
- Edge cases: BEAT_6_RESULT → BEAT_4_PREP retry transition (must SUCCEED — only legal backward edge) + BEAT_9_TRANSITION → LOADING next-chapter forward jump (must SUCCEED — chapter advancement) + LOADING → CHAPTER_START forward (must SUCCEED — initial chapter entry) + sub-assertion (b): `grep -E '_state\\s*=' src/core/scenario_runner.gd | grep -v '_transition_to'` returns 0 matches (verifies no direct assignment outside helper)

**AC-SP-16** (ADR-0001 cross-scene routing):
- Given: ScenarioRunner is wired to GameBus per ADR-0001
- When: `chapter_started(ChapterContext)` is emitted via `GameBus.chapter_started.emit(ctx)`
- Then: Source-scan via FileAccess + grep verifies no `connect()` calls between ScenarioRunner and Grid Battle or UI scene nodes exist (zero `<grid_battle>.<signal>.connect` or `<ui>.<signal>.connect` patterns in scenario_runner.gd); ScenarioRunner only uses `GameBus.<signal>.emit()` and `GameBus.<signal>.connect()` cross-scene routing per ADR-0001
- Edge cases: Verify all 7 ScenarioRunner-domain signals (chapter_started + battle_prepare_requested + battle_launch_requested + chapter_completed + scenario_complete + scenario_beat_retried + save_checkpoint_requested) are emitted via GameBus (not via instance signals)

**AC-SP-17** (5+1 confirmed signal contract emission):
- Given: ScenarioRunner is wired to GameBus + chapter-1 stub fixture loaded
- When: One full chapter completes (no retry; WIN outcome; canonical branch)
- Then: GameBus signal capture shows exactly these signals in order: `chapter_started` + `battle_prepare_requested` + `battle_launch_requested` + (mocked GridBattleController emits `battle_outcome_resolved` here) + `destiny_branch_chosen` + `chapter_completed` (5 ScenarioRunner-emitted + 1 consumed); NO signal named `battle_complete` is emitted (rename enforcement); `save_checkpoint_requested` emitted at CP-1 (BEAT_1_ANCHOR entry) + CP-2 (BEAT_7_JUDGMENT entry post-seal) + CP-3 (BEAT_9_TRANSITION entry)
- Edge cases: LOSS outcome with retry path (verify retry signal also emitted) + DRAW outcome (verify destiny_branch_chosen still fires) + last chapter (verify scenario_complete instead of chapter_completed at end)

**AC-SP-18** (DestinyBranchChoice 9-field payload completeness):
- Given: Chapter-1 stub fixture with `author_draw_branch = true` + DRAW outcome
- When: `destiny_branch_chosen(DestinyBranchChoice)` is emitted at BEAT_7_JUDGMENT exit (post-tap-advance)
- Then: GameBus signal capture extracts the DestinyBranchChoice payload; assert all 9 typed @export fields populated: `chapter_id: String` (== "ch1") + `branch_key: String` (matches branch_table lookup result) + `outcome: BattleOutcome.Result` (== DRAW) + `echo_count: int` (matches scenario state) + `is_draw_fallback: bool` (== false because author_draw_branch=true) + `is_canonical_history: bool` (matches branch-table row authoring) + `reserved_color_treatment: bool` (derived per F-DB-2: branch_key != canonical_branch_key AND NOT is_draw_fallback) + `is_invalid: bool` (== false on success path) + `invalid_reason: StringName` (== &"" empty StringName on success path)
- Edge cases: WIN canonical path (verify is_canonical_history=true + reserved_color_treatment=false) + WIN non-canonical path (verify is_canonical_history=false + reserved_color_treatment=true) + invalid-path emission (verify is_invalid=true + invalid_reason in F-DB-3 12-entry vocabulary; subscribers gate content reads on is_invalid==false per CR-DB-10)

**AC-SP-19** (scenario_beat_retried EchoMark payload — RATIFIED 3-field per delta #12):
- Given: ScenarioRunner is in BEAT_6_RESULT with LOSS outcome
- When: `_on_player_retry()` invoked simulating retry tap
- Then: GameBus signal capture extracts the EchoMark payload; assert SHIPPED 3-field schema per ADR-0003 §Schema Stability + `src/core/payloads/echo_mark.gd`: `beat_index: int` (== 5 — BEAT_5 was the retried beat) + `outcome: int` (BattleOutcome.Result enum value, == LOSS or DRAW per CR-8) + `tag: StringName` (chapter-scoped retry identifier; non-empty)
- Edge cases: DRAW retry (verify outcome field == DRAW) + tag uniqueness per retry (verify each retry produces a unique tag string) + provisional 4-field shape REJECTION (verify EchoMark instance does NOT have chapter_id/beat_number/retry_count/timestamp_unix fields per delta #12 ratification)

**AC-SP-21** (3-CP save emission timing):
- Given: ScenarioRunner is in CHAPTER_START
- When: Beats progress through BEAT_1_ANCHOR → BEAT_7_JUDGMENT → BEAT_9_TRANSITION (full single-chapter no-retry path)
- Then: GameBus signal capture extracts `save_checkpoint_requested(SaveContext)` emissions: exactly 3 in order: CP-1 at BEAT_1_ANCHOR entry (after 1s tap-lockout) + CP-2 at BEAT_7_JUDGMENT entry POST-seal (`first_attempt_resolved` field populated) + CP-3 at BEAT_9_TRANSITION entry; each SaveContext payload populated per `_make_save_context(cp_kind)` helper (assert all required fields per ADR-0003 SaveContext schema: chapter_id + outcome + branch_key + echo_count + echo_marks_archive + flags_to_set)
- Edge cases: Mid-battle save attempt (verify NOT emitted per CR-15 #10 — no mid-BEAT_5 emission) + retry path (verify CP-1 NOT re-emitted on retry; only emits at CHAPTER_START → BEAT_1 first entry per CR-8) + last chapter (verify CP-3 still emits before SCENARIO_END entry) + lint enforcement (`lint_scenario_runner_save_context_complete.sh` verifies `SaveContext.new()` outside `_make_save_context()` body returns 0 matches)

**AC-SP-25** (no `_process` body):
- Given: ScenarioRunner source file
- When: Source-scan via FileAccess
- Then: `grep -E '^func _process\(' src/core/scenario_runner.gd` returns 0 matches; `grep -E '^func _physics_process\(' src/core/scenario_runner.gd` returns 0 matches
- Pass condition: ScenarioRunner is event-driven (signal-handler + Timer-callback for min-dwell timing); no per-frame logic

**AC-SP-32** (5 forbidden_pattern lints PASS):
- Given: All 5 lint scripts at `tools/ci/lint_scenario_runner_*.sh` exist + `chmod +x`
- When: Each lint script invoked from project root
- Then: All 5 return exit code 0 (PASS); no SCENARIO_RUNNER_LINT_FAIL output
- Edge cases: Inject violation per lint (e.g., add `_state = State.LOADING` direct assignment outside `_transition_to()`) and verify lint correctly FAILs with descriptive error message

**AC-SP-33** (ADR-0017 V-1 boot-order verification):
- Given: project.godot autoload section
- When: Test loads project.godot via FileAccess + parses [autoload] section
- Then: ScenarioRunner appears at boot order position 6 (after GameBus + SceneManager + SaveManager + GameBusDiagnostics + BuildModeSentinel); ScenarioRunner._ready() completes without crash on `GameBus.battle_outcome_resolved.connect(...)` (verify via integration test loading the autoload stack)
- Edge cases: Out-of-order registration (verify project.godot diff if autoload order changes; surface as test failure)

**AC-SP-1** (CR-1 chapter linear progression):
- Given: chapter-1 (장판파) stub JSON loaded at LOADING entry
- When: ScenarioRunner processes chapter to completion (CHAPTER_START → SCENARIO_END if last chapter, else CHAPTER_START → next chapter LOADING)
- Then: `_chapter_index` advances correctly (0-based); chapter-1 not skipped or repeated
- Edge cases: 1-chapter scenario (this story's stub) — verify SCENARIO_END entry after BEAT_9_TRANSITION; multi-chapter scenario placeholder fixture — verify next-chapter LOADING after BEAT_9_TRANSITION (deferred to chapter-2+ authoring)

**AC-SP-2** (CR-2 9-beat canonical rhythm):
- Given: chapter-1 at CHAPTER_START
- When: Chapter runs to BEAT_9_TRANSITION (full single-chapter no-retry path with mocked GridBattleController emitting WIN outcome)
- Then: GameBus signal capture + `_state` history shows exactly 9 beat-state transitions in order: BEAT_1_ANCHOR → BEAT_2_ECHO → BEAT_3_BRIEF → BEAT_4_PREP → BEAT_5_BATTLE → BEAT_6_RESULT → BEAT_7_JUDGMENT → BEAT_8_REVEAL → BEAT_9_TRANSITION
- Edge cases: Beat skipping attempt via `_transition_to(State.BEAT_3_BRIEF)` from BEAT_1_ANCHOR (verify `assert(false, "Illegal forward jump skipping BEAT_2")` fires per AC-SP-13 forward-only invariant — but NOTE: technically the forward-only invariant ALLOWS BEAT_1 → BEAT_3 because both are higher ordinals; the skip prevention must come from per-state-handler exit rules NOT from generic forward-only check. Implementer note: each `_enter_beat_N()` handler must `_transition_to` only its successor beat, not allow callers to skip — verify via AC-SP-2 sequence assertion)

**AC-SP-9** (Beat 9 chapter_completed + echo reset):
- Given: chapter-1 at BEAT_9_TRANSITION entry
- When: BEAT_9 entry handler fires
- Then: (a) `_scenario_state.echo_count == 0` immediately after handler returns; (b) `chapter_completed(ChapterResult)` emitted on GameBus with payload populated: `chapter_id == "ch1"` + `branch_path_id` (matches branch_table resolution) + `echo_count_at_completion` (snapshot of echo_count BEFORE reset; for no-retry path this is 0)
- Edge cases: Last chapter (verify `scenario_complete(ScenarioResult)` emitted INSTEAD of chapter_completed; verify SCENARIO_END entry; verify ScenarioResult 4-field shape: chapter_outcomes + canonical_delta + scenario_path_key + total_echo)

**AC-SP-20** (CP-3 SaveContext field completeness):
- Given: ScenarioRunner at BEAT_9_TRANSITION entry
- When: CP-3 emission fires per AC-SP-21
- Then: SaveContext payload contains at minimum: `chapter_id` (== "ch1") + `outcome` (matches BattleOutcome.result received at BEAT_5) + `branch_key` (matches DestinyBranchChoice.branch_key from BEAT_7) + `echo_count` (snapshot BEFORE Beat 9 reset; = 0 for no-retry path) + `echo_marks_archive` (Array[EchoMark]; empty for no-retry path) + `flags_to_set` (Array[StringName]; chapter-completion flags); CP-2 SaveContext.outcome matches BattleOutcome.result received at BEAT_5 with no modification (verify via `_make_save_context()` helper test)
- Edge cases: CP-2 vs CP-3 outcome field consistency (both must equal `_last_battle_outcome.result`); retry path CP-2 (verify outcome reflects current attempt, not first attempt)

### Migration AC test specs (mock encoder DELETION + lint flip)

**AC-MIGRATE-1** (mock encoder DELETION):
- Setup: scenario-runner functional (per AC-SP-1..AC-SP-33); chapter-1 stub fixture available
- Verify: `grep -E '# === SPRINT-6 MOCK ENCOUNTER ===' src/feature/battle_scene/battle_scene.gd` returns 0 matches (markers removed); `grep -E '_build_mock_roster_sprint6\|_make_mock_unit\|_build_mock_map_resource_sprint6\|_make_uniform_grass_tiles' src/feature/battle_scene/battle_scene.gd` returns 0 matches (helpers removed); call site contains `var battle_config: BattlePayload = ScenarioRunner.get_active_battle_config()`
- Pass condition: BattleScene._ready() loads chapter-1 via ScenarioRunner.get_active_battle_config() instead of inline mock encoder

**AC-MIGRATE-2** (project.godot main_scene revert):
- Setup: project.godot `[application]` section
- Verify: `grep -E '^run/main_scene' project.godot` does NOT return `res://scenes/battle/battle_scene.tscn` (sprint-6 flip reverted); MAY return title-screen / overworld scene per implementation-time decision (Main Menu / Overworld / placeholder)
- Pass condition: standalone launch via `godot --path .` no longer launches directly into BattleScene

**AC-MIGRATE-3** (phase-flipping lint flip):
- Setup: tools/ci/lint_battle_scene_sprint6_mock_marker.sh
- Verify: lint script body contains `if grep ... ; FAILED=1` (marker MUST NOT exist semantic) NOT `if ! grep ... ; FAILED=1` (marker MUST exist semantic); inline header comment block reflects post-mock state; lint exits with code 0 PASS post-mock-deletion (verify via mechanical run after AC-MIGRATE-1 satisfied); lint exits with code 1 FAIL if mock markers ever return (verify via injection test with mock markers re-added)
- Pass condition: phase-flipping lint correctly enforces post-mock state; documented as 1st-precedent phase-flipping lint pattern in project; architecture.yaml `battle_scene_sprint6_mock_marker_must_exist` forbidden_pattern description amended same-patch

### Manual verification (Visual/Feel + UI ADVISORY ACs deferred per Out of Scope)

No manual verification required for this Logic + Integration story. Visual/Feel ADVISORY ACs (AC-SP-7 Beat 7 reserved-color tolerance + AC-SP-8 Beat 8 canonical-history contrast UI) deferred to art-team verification + Story Event #10 VS GDD authoring respectively.

---

## Test Evidence

**Story Type**: Integration (multi-system orchestration: ScenarioRunner ↔ GameBus ↔ SceneManager ↔ SaveManager ↔ GridBattleController ↔ DestinyBranchJudge ↔ BattleScene)

**Required evidence**:
- **Integration tests** (BLOCKING gate per coding-standards.md Testing Standards): `tests/integration/scenario_runner/scenario_runner_chapter_1_traversal_test.gd` — full chapter-1 traversal with mocked GridBattleController + GameBus capture
- **Unit tests** (BLOCKING gate per Logic story-type for state machine + signal contract + retry-loop + save context + chapter validation): `tests/unit/core/scenario_runner_*_test.gd` (5 files: state_machine + signal_contract + retry_loop + save_context + chapter_definition_validation) + `tests/helpers/scenario_runner_test_seam.gd` + `tests/helpers/destiny_branch_judge_stub.gd`
- **Smoke evidence** (per ADR-0017 §Validation Criteria): `production/qa/evidence/scenario_runner_3_chapter_mvp_2026-XX-XX.md` (chapter-1 only for sprint-7 scope; chapter-2..N coverage deferred)
- **Migration smoke evidence** (per AC-MIGRATE-4): `production/qa/evidence/battle_scene_smoke_2026-XX-XX.md` re-authored covering new launch path
- **Verification summary** (epic terminal): `production/qa/evidence/scenario_runner_verification_summary.md` covering all 15 TR-scenario-progression-* satisfaction proofs
- **Full regression**: target ~960 PASS at sprint-7 close per sprint-7 plan (+25-30 from this story alone; baseline 907 at sprint-6 close)

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: NONE (S7-01 ADR-0019 acceptance via /architecture-review delta #14 already complete; ADR-0017 already Accepted via delta #12; ADR-0018 already Accepted via delta #13; all 3 governing ADRs are Accepted as of 2026-05-05)
- **Unlocks**:
  - **destiny-branch story-001** (S7-03 sprint-7 critical path) — DestinyBranchJudge full F-DB-1 algorithm body fills in the stub from this story per Decision A coordination
  - **ai-system story-001** (S7-04 sprint-7 critical path) — ChapterDefinition.enemy_roster archetype field consumed by AISystem at chapter-load per ADR-0019 §Migration Plan §8
  - **chapter-1 (장판파) full content authoring** (S7-05 sprint-7 should-have) — chapter-1 .tres scaffold from this story extended with full narrative content per Decision B coordination
  - **Story Event #10 VS GDD** (S7-06 sprint-7 should-have) — chapter-1 narrative beat content authoring depends on ScenarioRunner functional
  - **Destiny State #16 VS GDD** (S7-07 sprint-7 should-have) — echo-archive maintenance + cross-chapter destiny-state propagation depends on ScenarioRunner functional
  - **Sprint-7 +1 playable-surface delta target** — chapter-1 end-to-end playable arc requires ScenarioRunner functional + sprint-6 mock encoder DELETED
  - **Pre-Production → Production gate upgrade** — gate-check 2026-05-04 path-to-PASS item #6 (sprint-7 plan execution); after S7-01..S7-07 close + S7-11 user attestation captured, expect upgrade CONCERNS → PASS + `production/stage.txt` written = "Production"
