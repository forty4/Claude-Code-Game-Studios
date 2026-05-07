# Epic: Scenario Progression (scenario-progression)

> **Layer**: Core
> **GDD**: `design/gdd/scenario-progression.md` (rev 2.2 — Designed; F-SP-3 v2.2 synchronous seal + F-SP-4 ScenarioResult 4-field shape; CR-7 4th-argument invariant)
> **Architecture Module**: `ScenarioRunner` autoload Node — `extends Node` (NO `class_name` per godot-4x-gotchas G-3 — autoload-registered identifier IS the global name); single autoload registered at `*res://src/core/scenario_runner.gd`; lifecycle owned by SceneTree; persistent across Overworld ↔ BattleScene transitions per ADR-0002. Boot order position **6** (after GameBus → SceneManager → SaveManager → GameBusDiagnostics → BuildModeSentinel — 6th-precedent autoload pattern extension).
> **Status**: Complete (1/1 stories shipped — story-001 single coordinated patch via S7-02 commit `ba02e02` 2026-05-05; epic graduation backfill via S10-04 2026-05-07 drift-correction sweep — 2nd activation of sprint-10 retro AI #3 "story-spec doc-correction at /story-readiness time")
> **Stories**: 1 epic-terminal story — see Stories table below
> **Created**: 2026-05-05 (Sprint 7 — post-S7-01 ADR-0019 acceptance unblocks the 3-epic scaffold batch)
> **Manifest Version**: 2026-05-04 (`docs/architecture/control-manifest.md` — refreshed via gate-check pre-prod-to-prod-2026-05-04 path-to-PASS item #3)

## Overview

The Scenario Progression epic implements `ScenarioRunner` — the **chapter / scenario state machine + 9-beat per-chapter rhythm** that drives the entire narrative arc from chapter-start through Beat 7 destiny-branch judgment to Beat 8 reveal to Beat 9 outro. The epic ships a 13-state enum machine (`enum State { LOADING, CHAPTER_START, BEAT_1_ANCHOR, BEAT_2_ECHO, BEAT_3_BRIEF, BEAT_4_PREP, BATTLE_LOADING, BEAT_5_BATTLE, BEAT_6_RESULT, BEAT_7_JUDGMENT, BEAT_8_REVEAL, BEAT_9_TRANSITION, SCENARIO_END }`) with single authoritative `_state: State` field + `_transition_to(target: State)` method per `scenario_runner_arbitrary_state_jump` forbidden_pattern, a typed `ChapterDefinition` Resource hydrated from `assets/data/scenarios/{scenario_id}.json` at LOADING entry (with EC-SP-8 validation pipeline FATAL on malformed branch_table or missing canonical_branch_key), 7-signal contract emission (5 confirmed + 2 ratified via delta #12: chapter_started + battle_prepare_requested + battle_launch_requested + chapter_completed + scenario_complete + scenario_beat_retried + save_checkpoint_requested), retry-loop guard (BEAT_6_RESULT LOSS/DRAW → BEAT_4_PREP only with echo_count++ + scenario_beat_retried emit + ECHO_COUNT_HARD_CAP=100 from BalanceConstants), F-SP-3 v2.2 **synchronous** seal of `first_attempt_resolved` at BEAT_7 entry per `scenario_runner_deferred_seal_in_beat_7_entry` Pillar 2 architectural lock (2nd project precedent), F-SP-1/F-SP-2 delegation to `DestinyBranchJudge.resolve(...)` per ADR-0018 boundary, 3-CP save integration (CP-1 BEAT_1 entry + CP-2 BEAT_7 entry post-seal + CP-3 BEAT_9 entry), and the **sprint-6 inline mock encoder DELETION** with phase-flipping lint flip (`battle_scene_sprint6_mock_marker_must_exist` semantic flip from "marker MUST exist" → "marker MUST NOT exist" per ADR-0016 §Migration Plan §1 — 1st-precedent semantic switch in the project).

This is the **6th invocation of the autoload Node lineage** (after GameBus + SceneManager + SaveManager + GameBusDiagnostics + BuildModeSentinel) and the **2nd invocation of the enum + match state machine pattern** (after SceneManager ADR-0002 5-state FSM). ScenarioRunner closes the Core layer narrative-pillar substrate (alongside DestinyBranchJudge per ADR-0018 delta #13) and unblocks chapter-1 (장판파) end-to-end playable arc — the +1 playable-surface delta target for sprint-7.

## Pattern Boundary Precedent

**6th invocation of autoload Node lineage** + **2nd invocation of enum + match state machine pattern**:

| Invocation | Autoload | ADR | Pattern Form |
|---|---|---|---|
| #1 | GameBus | ADR-0001 | Autoload Node + signal-only API |
| #2 | SceneManager | ADR-0002 | Autoload Node + 5-state enum FSM |
| #3 | SaveManager | ADR-0003 | Autoload Node + ResourceSaver/Loader pipeline |
| #4 | GameBusDiagnostics | (sprint-2 dev tool) | Autoload Node + dev-tier observability |
| #5 | BuildModeSentinel | (sprint-2 dev tool) | Autoload Node + build-mode flag |
| **#6** | **ScenarioRunner** | **ADR-0017** | **Autoload Node + 13-state enum FSM (2nd invocation of enum+match pattern after ADR-0002 SceneManager 5-state FSM)** |

**1st invocation of phase-flipping lint pattern**: `battle_scene_sprint6_mock_marker_must_exist` flips its assertion semantic (from "marker MUST exist" sprint-6-throwaway-protection mode → "marker MUST NOT exist" sprint-7+-mock-deleted mode) at this epic's terminal patch per ADR-0016 §Migration Plan §1. Future scaffold-then-clean lint patterns inherit this discipline.

## MVP Scope (per ADR-0017 §Migration Plan §1..§11 — single coordinated patch)

This epic implements the MVP subset for sprint-7 S7-02 (single coordinated patch — autoload registration + 13-state machine + chapter-1 .tres data + 7-signal contract + sprint-6 mock encoder DELETION same-patch with phase-flipping lint):

- ✅ **Autoload registration** at `*res://src/core/scenario_runner.gd` boot order position 6 (after GameBus → SceneManager → SaveManager → GameBusDiagnostics → BuildModeSentinel) per ADR-0017 §Decision §Module Form
- ✅ **13-state enum machine** + `_transition_to(target: State)` validated transition method (legal-transition table per scenario-progression.md §States and Transitions; single backward edge BEAT_6_RESULT → BEAT_4_PREP for retry loop; all others forward-only per AC-SP-13)
- ✅ **`ChapterDefinition` typed Resource** hydrated from `assets/data/scenarios/{scenario_id}.json` at LOADING entry; 13 @export fields including `chapter_id` + `branch_table: Dictionary` (UNTYPED per GDScript 4.6 G-2 prohibition) + `canonical_branch_key: String` + `chokepoints: Array[Vector2i]` + `enemy_roster: Array[Dictionary]` (entries gain `archetype: StringName` field per ADR-0019 §Migration Plan §8)
- ✅ **JSON validation pipeline** at LOADING entry per EC-SP-8 (FATAL on malformed branch_table or missing canonical_branch_key or DRAW invariant violations; ChapterDefinition hydrated only from VALIDATED JSON)
- ✅ **9-beat per-chapter rhythm** machine logic + per-beat entry/exit handlers (BEAT_1_ANCHOR through BEAT_9_TRANSITION + SCENARIO_END terminal)
- ✅ **7-signal contract emission** (5 confirmed + 2 ratified via delta #12): chapter_started(chapter_id, chapter_number) + battle_prepare_requested(BattlePayload) + battle_launch_requested(BattlePayload) + chapter_completed(ChapterResult) + scenario_complete(ScenarioResult — 4-field typed Resource per delta #12 widening from String) + scenario_beat_retried(EchoMark — 3-field shipped form per delta #12 ratification) + save_checkpoint_requested(SaveContext)
- ✅ **Retry-loop guard** (two-layer defense — enum-state + outcome assertion; BEAT_6_RESULT → BEAT_4_PREP only; LOSS/DRAW only; echo_count++ + scenario_beat_retried emit + ECHO_COUNT_HARD_CAP=100 from BalanceConstants)
- ✅ **F-SP-3 v2.2 SYNCHRONOUS seal** of `first_attempt_resolved` at BEAT_7 entry per `scenario_runner_deferred_seal_in_beat_7_entry` Pillar 2 architectural lock (no `call_deferred` / no `CONNECT_DEFERRED` / no `await` between BEAT_6 exit and BEAT_7 seal)
- ✅ **F-SP-1/F-SP-2 delegation to `DestinyBranchJudge.resolve(...)`** per ADR-0018 §Decision §Class Form 4-arg signature (`chapter, outcome, echo_count, first_attempt_resolved`); ScenarioRunner constructs `var judge: DestinyBranchJudge = DefaultDestinyBranchJudge.new()` + `var choice: DestinyBranchChoice = judge.resolve(...)` per ADR-0017 line 209 instance-form widening (delta #13 same-patch flip)
- ✅ **3-CP save integration** (CP-1 BEAT_1 entry + CP-2 BEAT_7 entry post-seal + CP-3 BEAT_9 entry) via single `_make_save_context(cp_kind: SaveCheckpoint) -> SaveContext` helper per `scenario_runner_save_context_partial_emit` forbidden_pattern (asserts all required fields populated before returning)
- ✅ **`destiny_branch_chosen(DestinyBranchChoice)` emission** at BEAT_7 exit per `destiny_branch_judge_emits_gamebus_signal` forbidden_pattern (CR-DB-4 emission ownership in ScenarioRunner, NOT DestinyBranchJudge); 9-field RATIFIED payload per ADR-0001 minor amendment delta #13
- ✅ **Sprint-6 inline mock encoder DELETION** per ADR-0016 §Migration Plan §1 (~50 LoC + 4 helper methods removed from `src/feature/battle_scene/battle_scene.gd`); call site replaced with `var battle_config: BattlePayload = ScenarioRunner.get_active_battle_config()` per ADR-0017 §Decision §`BattleConfig` (REUSE BattlePayload Resource — no new type)
- ✅ **`project.godot` main_scene revert** from `res://scenes/battle/battle_scene.tscn` back to title-screen / overworld entry per ADR-0002 SceneManager standard flow
- ✅ **Phase-flipping lint flip**: `tools/ci/lint_battle_scene_sprint6_mock_marker.sh` semantic flips from "marker MUST exist" → "marker MUST NOT exist" per ADR-0016 §Migration Plan §1; `battle_scene_sprint6_mock_marker_must_exist` forbidden_pattern semantic inversion same-patch (1st-precedent phase-flipping lint pattern in project)
- ✅ **5 forbidden_pattern lints** wired into `.github/workflows/tests.yml`: `lint_scenario_runner_state_match_exhaustive.sh` (state machine arbitrary-jump prevention) + `lint_scenario_runner_branch_table_immutable.sh` (runtime mutation prevention) + `lint_scenario_runner_save_context_complete.sh` (partial-emit prevention via single-helper enforcement) + `lint_scenario_runner_no_deferred_in_beat_7_seal.sh` (Pillar 2 architectural lock 2nd-precedent) + `lint_scenario_runner_outcome_synthesis.sh` (CR-3 single-emitter ownership enforcement)
- ✅ **~25-30 unit tests** covering state machine transitions + JSON validation + 9-beat rhythm + retry-loop + 3-CP save emission + F-SP-3 v2.2 seal + DestinyBranchJudge delegation + 7-signal contract emission + EC-SP-1..N edge cases

**Explicit deferrals**:

- ❌ **Mid-battle save** (CR-15 #10) — explicitly forbidden per ADR-0017 + ADR-0003; CP anchors are between-turns or post-Beat 7 only
- ❌ **Cross-chapter save migration** — `SaveContext.schema_version` + `SaveMigrationRegistry` per ADR-0003 cover schema evolution; not in this epic's scope
- ❌ **Save/Load #17 VS GDD authoring** — CUT from sprint-7 per Producer pressure-cut decision (in-memory CP-1/2/3 satisfies sprint-7 demo); deferred to sprint-8 or later
- ❌ **Battle Preparation Resource (BattlePayload extension)** — REUSE existing `BattlePayload` per ADR-0017 §Decision §`BattleConfig`; future Battle Preparation ADR (post-MVP) may extend payload with hero loadout + formation pick fields
- ❌ **Story Event #10 + Destiny State #16 GDD content** — sprint-7 should-have S7-06 + S7-07 design authoring (separate /design-system invocations); chapter-1 narrative beat content authored at S7-05 chapter-1 .tres
- ❌ **Multi-scenario authoring** — chapter-1 (장판파) only for MVP per CR-AI-3 closed scope; chapter-2..N authoring is separate post-MVP scenario authoring pass

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| **ADR-0017 Scenario Progression** (Accepted 2026-05-04 via /architecture-review delta #12) | Autoload Node + 13-state enum FSM + ChapterDefinition typed Resource + 7-signal contract (5 confirmed + 2 ratified) + F-SP-3 v2.2 SYNCHRONOUS seal at BEAT_7 entry (Pillar 2 architectural lock 2nd precedent) + F-SP-1/F-SP-2 delegation to DestinyBranchJudge + retry-loop guard + 3-CP save + 5 forbidden_patterns; line 209 instance-form widening via delta #13 same-patch flip (DefaultDestinyBranchJudge.new() + judge.resolve(...) per ADR-0018 RefCounted ratification) | **LOW** (autoload + state machine + JSON parse + signal emission — all pre-4.4 stable APIs) |
| ADR-0001 GameBus (depends-on) | Signal contract source-of-truth; ScenarioRunner is sole emitter of 7 Scenario-domain signals; `scenario_complete` widened String → ScenarioResult via delta #12; `scenario_beat_retried` ratified PROVISIONAL → Accepted with shipped 3-field EchoMark via delta #12; `destiny_branch_chosen` ratified PROVISIONAL 5-field → 9-field via delta #13 | LOW |
| ADR-0002 SceneManager (depends-on) | SceneManager subscribes to `battle_launch_requested` + `scenario_fault` for player-facing retry/abort dialog; 5-state enum FSM precedent for ScenarioRunner's 13-state machine pattern | LOW |
| ADR-0003 Save/Load (depends-on) | SaveManager subscribes to `save_checkpoint_requested` at 3 CPs (CP-1 BEAT_1 entry, CP-2 BEAT_7 entry post-seal, CP-3 BEAT_9 entry); SaveContext schema + SaveMigrationRegistry covers schema evolution | LOW |
| ADR-0014 GridBattleController (depends-on) | GridBattleController emits `battle_outcome_resolved(BattleOutcome)` consumed at BEAT_5_BATTLE → BEAT_6_RESULT transition via `GameBus.battle_outcome_resolved.connect(_on_battle_outcome, CONNECT_DEFERRED)` at autoload `_ready()`; ScenarioRunner never mutates or overrides outcome per CR-3 invariant + `scenario_runner_outcome_synthesis` forbidden_pattern | LOW |
| ADR-0016 BattleSceneWiring (depends-on) | BattleScene._ready() will call `get_active_battle_config()` at sprint-7+ post-mock-encoder-deletion patch (Migration Plan §1); sprint-6 inline mock encoder DELETED same-patch with this epic's terminal story; phase-flipping lint flips semantic same-patch | LOW |
| ADR-0018 DestinyBranch (depends-on) | DestinyBranchJudge.resolve(...) called at BEAT_7_JUDGMENT entry for F-SP-1/F-SP-2; ScenarioRunner constructs DefaultDestinyBranchJudge.new() + invokes resolve(...) per ADR-0017 line 209 instance-form (delta #13) + emits `destiny_branch_chosen(DestinyBranchChoice)` at BEAT_7 exit (CR-DB-4 emission ownership) | HIGH (transitively — ADR-0018 owns @abstract test-seam + parameterless duplicate_deep + StringName field-type preservation through ResourceSaver/ResourceLoader on 5 export targets per OQ-DB-6; NOT re-asserted at ScenarioRunner level) |
| ADR-0019 AISystem (depends-on) | ChapterDefinition.enemy_roster Dictionary entries gain `archetype: StringName` field at sprint-7+ S7-05 chapter-1 .tres authoring per ADR-0019 §Migration Plan §8; ScenarioRunner validates archetype on chapter-load (caller responsibility per EC-AI-4 fallback) | LOW |
| ADR-0006 BalanceConstants (depends-on) | `ECHO_COUNT_HARD_CAP=100` BalanceConstants entry for retry-loop guard | LOW |

**Highest Engine Risk among governing ADRs**: **HIGH** transitively via ADR-0018 DestinyBranch consumer pattern. The HIGH-risk surface (StringName field-type preservation through ResourceSaver/Loader on 5 export targets per OQ-DB-6) is owned by ADR-0018 destiny-branch epic stories + verified there, NOT re-asserted at ScenarioRunner level. ADR-0017's own engine surface is **LOW** (zero new post-cutoff API surface).

## GDD / TR Requirements

15 net-new TRs registered as TR-scenario-progression-001..015 in `tr-registry.yaml` v13 (delta #12). Original 3 TRs (001..003) registered 2026-04-18 per ADR-0001 GameBus relay pattern + 5-signal cross-scene contract + EC-SP-5 duplicate-emit guard.

| TR-ID | Requirement (summary) | ADR Coverage |
|-------|----------------------|--------------|
| TR-scenario-progression-001 | OQ-SP-01: GameBus signal relay pattern ratified before Scenario impl | ADR-0001 ✅ |
| TR-scenario-progression-002 | 5 outbound signals cross scene boundaries | ADR-0001 ✅ |
| TR-scenario-progression-003 | EC-SP-5 duplicate battle-complete guard | ADR-0001 ✅ |
| TR-scenario-progression-004 | ScenarioRunner autoload Node form (extends Node, NO class_name per G-3); boot order position 6 after GameBus/SceneManager/SaveManager/GameBusDiagnostics/BuildModeSentinel; 5-precedent autoload pattern extension | ADR-0017 ✅ |
| TR-scenario-progression-005 | 13-state enum + match-statement state machine (LOADING → SCENARIO_END); single `_state: State` field; transitions via `_transition_to(target)` only; SceneManager precedent stable at 2 invocations | ADR-0017 ✅ |
| TR-scenario-progression-006 | ChapterDefinition typed Resource (13 @export fields) hydrated from `assets/data/scenarios/{scenario_id}.json` at LOADING entry; branch_table UNTYPED Dictionary per GDScript 4.6 G-2 prohibition | ADR-0017 ✅ |
| TR-scenario-progression-007 | 7-signal contract (5 confirmed + 2 ratified at delta #12); scenario_complete payload widened String → ScenarioResult per CR-16 + F-SP-4 GDD intent; scenario_beat_retried RATIFIED with shipped 3-field EchoMark | ADR-0017 ✅ |
| TR-scenario-progression-008 | F-SP-3 v2.2 SYNCHRONOUS seal of first_attempt_resolved at BEAT_7 entry; NO call_deferred / CONNECT_DEFERRED / await between BEAT_6 exit and BEAT_7 seal; second project precedent of pillar-anchored lint pattern | ADR-0017 ✅ |
| TR-scenario-progression-009 | F-SP-1/F-SP-2 delegated to DestinyBranchJudge.resolve(...) per ADR-0018; ScenarioRunner owns formula spec, ADR-0018 owns executor + DestinyBranchChoice payload | ADR-0017 ✅ |
| TR-scenario-progression-010 | Retry-loop guard two-layer defense (enum-state + outcome assertion); BEAT_6_RESULT → BEAT_4_PREP only; LOSS/DRAW only; echo_count++ + scenario_beat_retried emit; ECHO_COUNT_HARD_CAP=100 from BalanceConstants | ADR-0017 ✅ |
| TR-scenario-progression-011 | 3-CP save emission (CP-1 BEAT_1 entry / CP-2 BEAT_7 entry post-seal / CP-3 BEAT_9 entry); single `_make_save_context(cp_kind)` helper enforces SaveContext completeness; NO mid-battle save (CR-15 #10) | ADR-0017 ✅ |
| TR-scenario-progression-012 | BattleConfig = REUSE BattlePayload Resource (no new type); `get_active_battle_config(): BattlePayload`; ratifies ADR-0016 §Migration Plan §1 placeholder name | ADR-0017 ✅ |
| TR-scenario-progression-013 | JSON validation pipeline at LOADING entry per EC-SP-8; FATAL on malformed branch_table / missing canonical_branch_key / DRAW invariant violations; ChapterDefinition hydrated only from VALIDATED JSON | ADR-0017 ✅ |
| TR-scenario-progression-014 | 5 ScenarioRunner-domain forbidden_patterns registered v10→v11 (delta #12): scenario_runner_arbitrary_state_jump + branch_table_runtime_mutation + save_context_partial_emit + deferred_seal_in_beat_7_entry + outcome_synthesis | ADR-0017 ✅ |
| TR-scenario-progression-015 | Migration Plan §1 atomicity — 11 mechanical changes ship in single sprint-7+ patch (autoload reg + 3 new payloads + JSON data + ADR-0016 mock encoder revert + main_scene revert + lint flip + smoke evidence + verification summary §E close) | ADR-0017 ✅ |

**Untraced Requirements**: None (15/15 covered by ADR-0017 + ADR-0001).

## Same-Patch Obligations from ADR-0017 §Migration Plan §1..§11

These obligations land at the implementation story (S7-02) and ship together — single coordinated patch atomicity per TR-scenario-progression-015:

1. **ScenarioRunner autoload registration** — `*res://src/core/scenario_runner.gd` registered in project.godot autoloads at boot order position 6 (after GameBus + SceneManager + SaveManager + GameBusDiagnostics + BuildModeSentinel)
2. **3 new typed Resource payloads** at `src/core/payloads/`: `scenario_result.gd` (ScenarioResult — 4-field per F-SP-4 + delta #12 widening) + `chapter_result.gd` (ChapterResult — per ADR-0001 line 146) + `chapter_definition.gd` (ChapterDefinition — 13 @export fields per ADR-0017 §Decision §ChapterDefinition)
3. **Chapter-1 JSON data** at `assets/data/scenarios/scenario_01.json` containing chapter-1 (장판파) ChapterDefinition payload (sprint-7 S7-05 chapter-1 .tres authoring may co-ship; or this epic's chapter-1 .tres ships first as scaffold + S7-05 fills out narrative content)
4. **Sprint-6 inline mock encoder DELETION** from `src/feature/battle_scene/battle_scene.gd` (~50 LoC mock encoder block + 4 helper methods removed; call site replaced with `var battle_config: BattlePayload = ScenarioRunner.get_active_battle_config()`)
5. **`project.godot` main_scene revert** from `res://scenes/battle/battle_scene.tscn` back to title-screen / overworld entry per ADR-0002 SceneManager standard flow
6. **Phase-flipping lint flip**: `tools/ci/lint_battle_scene_sprint6_mock_marker.sh` semantic flips from "marker MUST exist" → "marker MUST NOT exist"; `battle_scene_sprint6_mock_marker_must_exist` forbidden_pattern semantic inversion same-patch
7. **5 lint scripts** at `tools/ci/`: lint_scenario_runner_state_match_exhaustive.sh + lint_scenario_runner_branch_table_immutable.sh + lint_scenario_runner_save_context_complete.sh + lint_scenario_runner_no_deferred_in_beat_7_seal.sh + lint_scenario_runner_outcome_synthesis.sh — wired into `.github/workflows/tests.yml`
8. **~25-30 unit + integration tests** at `tests/unit/core/scenario_runner_*_test.gd` + `tests/integration/scenario_runner/` covering state machine transitions + JSON validation + 9-beat rhythm + retry-loop + 3-CP save emission + F-SP-3 v2.2 seal + DestinyBranchJudge delegation + 7-signal contract emission
9. **Test helpers** at `tests/helpers/scenario_runner_test_seam.gd` (constant-map for State enum access per IN-1 G-3 §Test consequence — autoload-registered identifier IS the global name; tests cannot import the script directly per G-3)
10. **Smoke evidence doc** at `production/qa/evidence/scenario_runner_smoke_2026-XX-XX.md` covering 13-state machine traversal + 9-beat rhythm + retry-loop + 3-CP save emission + DestinyBranchJudge delegation
11. **Verification summary doc** at `production/qa/evidence/scenario_runner_verification_summary.md` covering all 15 TR satisfaction proofs

## Pillar 2 Architectural Lock (2nd Project Precedent)

`scenario_runner_deferred_seal_in_beat_7_entry` is the **2nd project precedent of pillar-anchored lint pattern** (after `battle_hud_subscribes_to_hidden_fate_signal` ADR-0015 1st precedent + before `destiny_branch_judge_reads_scenario_runner_state` ADR-0018 3rd precedent + `ai_system_reads_destiny_branch_state` ADR-0019 4th precedent — pattern firmly stable at 4 invocations as of delta #14).

3-layer enforcement triad codified per control-manifest.md §Pillar 2 Architectural Locks (2026-05-04 path-to-PASS item #3):

1. **Source-grep lint** — `tools/ci/lint_scenario_runner_no_deferred_in_beat_7_seal.sh` greps for `call_deferred.*beat_7|beat_7.*call_deferred|CONNECT_DEFERRED.*beat_7` patterns; all matches FAIL
2. **ADR-0017 §Decision §F-SP-1/F-SP-2 inline source-comment annotation** + this epic's `_enter_beat_7_judgment()` body inline comment annotation
3. **Integration test** asserting BEAT_6_RESULT.accept → BEAT_7_JUDGMENT.entry happens in 1 frame (no frame boundary)

The lock prevents asynchronous seal of `first_attempt_resolved` — a value visible to F-SP-1 at BEAT_7 differs from value at BEAT_6 accept time would corrupt echo-gated branch resolution (CR-6); player who retried 0 times sees the WIN branch the first time, then on second playthrough the late seal sees them STILL on the WIN branch instead of the echo-gated alternative — silent narrative divergence + Pillar 2 (운명은 바꿀 수 있다) hidden-fate semantics breakage.

## Stories

| # | Story | Type | Status | TR-IDs | Estimate |
|---|-------|------|--------|--------|----------|
| [001](story-001-scenario-runner-implementation-and-mock-encoder-deletion.md) | ScenarioRunner implementation per ADR-0017 Migration Plan §1..§11 + sprint-6 mock encoder DELETION (epic-terminal) | Integration | **Complete** (S7-02 ba02e02 2026-05-05; epic graduation backfill via S10-04 2026-05-07) | TR-scenario-progression-001..015 (all 15) + AC-MIGRATE-1..5 + AC-ATOMIC-1 | ~6h (0.6d nominal per sprint-7 plan; multi-spawn-on-scale precedent expects 2-3 SendMessage continuations per hp-status story-008 12-file precedent) |

**Decision applied (per `/create-stories scenario-progression` 2026-05-05)**: **Option A — single epic-terminal story**. Rationale per autonomy memory:
- ADR-0017 §Migration Plan line 525 explicitly mandates "Steps 1-11 ship in a single commit" — atomicity is contractual, not stylistic
- Sprint-7 plan S7-02 framing: "ScenarioRunner implementation per ADR-0017 §Migration Plan §1..§11 single coordinated patch" — ratifies single-story decomposition
- Sprint-6 mock encoder DELETION + phase-flipping lint flip + main_scene revert MUST ship same-patch with ScenarioRunner mount (BattleScene wiring contract; partial completion = broken build)
- hp-status story-008 12-file deliverable precedent: single coordinated patch via /dev-story across 2-3 SendMessage continuations — proven workable
- Pre-resolved coordination decisions A-F embedded in story file (Decision A DestinyBranchJudge stub scope + Decision B chapter-1 .tres scope + Decision C AISystem hooks + Decision D Save/Load CUT + Decision E lint scope promotion + Decision F phase-flip atomicity) reduce SendMessage round-trip count

**Total estimate**: ~6h = ~0.75 working days (within sprint-7 S7-02 0.6d nominal budget; per 4th-consecutive AI #1 ratchet baseline of 5× velocity multiplier from sprint-5/6, projected actual ~0.12-0.15 calendar day = ~1-1.5h wall-clock).

**Implementation order**: story-001 (single epic-terminal) → `/code-review` (lean-mode orchestrator-direct per 13-precedent project default) → `/story-done` (closes epic at 1/1 Complete) → next story is destiny-branch story-001 (S7-03 sprint-7 critical path; depends on this story per Decision A coordination — DestinyBranchJudge stub from this story replaced by S7-03's authoritative impl).

**Sprint allocation**: epic preview (this artifact) at S7-01 post-acceptance scaffold batch (delta #14 same-session-as-S7-01); implementation at S7-02 (sprint-7 critical path; 0.6d nominal per sprint-7 plan).

## Definition of Done

This epic is complete when:

- All stories are implemented, reviewed, and closed via `/story-done`
- All 15 TR-scenario-progression-* requirements are satisfied (verified against `docs/architecture/tr-registry.yaml`)
- The 11 same-patch obligations above are shipped (autoload reg + 3 Resource payloads + JSON data + mock encoder DELETION + main_scene revert + lint flip + 5 lints + ~25-30 tests + test helpers + smoke evidence + verification summary)
- Integration smoke test passes (13-state machine traversal + 9-beat rhythm + retry-loop + 3-CP save emission + DestinyBranchJudge delegation + 7-signal contract emission per ScenarioRunner-domain interface contract)
- 5 lint scripts pass in CI
- Sprint-6 mock encoder DELETED + phase-flipping lint flipped semantic same-patch
- Smoke evidence doc covers state machine traversal + 9-beat rhythm + DestinyBranchJudge delegation
- ADR-0017 §Migration Plan §1..§11 single coordinated patch atomicity verified — all 11 items in one PR
- The full regression baseline remains failure-free (target: ~960 PASS at sprint-7 close per sprint-7 plan; +25-30 from this epic alone)

## Next Step

Run `/create-stories scenario-progression` to break this epic into implementable stories. Decision pending: 1 epic-terminal story (Option A — matches "single coordinated patch" sprint-7 framing) vs 3-story decomposition (Option B — intermediate code-review checkpoints). Sprint-7 S7-02 is the critical path; once stories created, run `/dev-story [story-path]` per implementation order.

**Unblocks**: chapter-1 (장판파) end-to-end playable arc per sprint-7 +1 playable-surface delta target; AISystem implementation S7-04 (depends on ScenarioRunner per ADR-0019 §Migration Plan §8 ChapterDefinition.enemy_roster archetype field consumer); chapter-1 ChapterDefinition .tres authoring S7-05 (the integration test target for ScenarioRunner + DestinyBranchJudge + AISystem coordination).
