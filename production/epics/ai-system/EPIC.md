# Epic: AI System (ai-system)

> **Layer**: Feature
> **GDD**: `design/gdd/ai-system.md` (rev 1.0 — Designed; CR-AI-1..8 + F-AI-1..4 + EC-AI-1..12 + AC-AI-1..14 + OQ-AI-1..5; CR-AI-1 step number reconciled "6.5" → "5.5" via delta #14 same-patch wording flip)
> **Architecture Module**: `AISystem` — `class_name AISystem extends Node` battle-scoped **6th invocation of battle-scoped Node pattern** after HPStatusController + TurnOrderRunner + BattleCamera + GridBattleController + BattleHUD. **Single source file** (`src/feature/ai/ai_system.gd`, target ~300 LoC) with **single-class match-dispatch on archetype StringName** (NOT subclass hierarchy per Alternative §4 rejection — closed 4-archetype MVP set per CR-AI-3; YAGNI applies for solo-dev productivity). Mounted in BattleScene `_ready()` mount sequence at **step 5.5** (post-GridBattleController step 5, pre-BattleHUD step 6 per ADR-0016 §3 R-3 amended via /architecture-review delta #14 2026-05-05; Path A insert preserves existing 1-6 numbering, full 1-7 renumber deferred to sprint-7+ S7-02). Battle-scoped lifecycle (vs autoload) chosen because archetype assignments are chapter-scoped; no cross-battle state needed.
> **Status**: Complete (1/1 stories shipped 2026-05-05 — single coordinated patch; epic-terminal close)
> **Stories**: 1 epic-terminal story — see Stories table below
> **Created**: 2026-05-05 (Sprint 7 — same session as ADR-0019 acceptance via /architecture-review delta #14)
> **Manifest Version**: 2026-05-04 (`docs/architecture/control-manifest.md` — refreshed via gate-check pre-prod-to-prod-2026-05-04 path-to-PASS item #3)

## Overview

The AI System epic implements `AISystem` — the **per-unit decision layer** that produces battle actions for non-player-controlled units via **rule-based utility scoring** across 4 archetypes (aggressor / skirmisher / holder / coordinator per CR-AI-3 closed MVP vocabulary). The epic ships 3 source files (`src/feature/ai/ai_system.gd` ~300 LoC + `src/core/payloads/battle_state_snapshot.gd` ~30 LoC + `src/core/payloads/ai_action_command.gd` ~50 LoC), 2 test helpers (`tests/helpers/battle_state_snapshot_factory.gd` ~50 LoC + `tests/helpers/ai_action_command_assertions.gd` ~30 LoC), 5 unit/integration test files covering AC-AI-1..14 (except AC-AI-12 chapter-1 distribution + AC-AI-14 save/load determinism deferred until ScenarioRunner + Save/Load ship), 4 CI lint scripts enforcing the 4 forbidden_patterns proposed in delta #14 (`ai_system_signal_emission_outside_action_ready` + `ai_system_static_var` + `ai_system_reads_destiny_branch_state` Pillar 2 lock 4th precedent + `ai_system_direct_battle_state_read` CR-AI-6 enforcement), GridBattleController extension `_make_battle_state_snapshot()` private method, BattleScene mount sequence step 5.5 insertion, and chapter-1 ChapterDefinition.enemy_roster archetype assignments (하후돈=`&"aggressor"`, 장요=`&"skirmisher"`, 우금=`&"holder"`, 허저=`&"coordinator"` boss).

This is the **6th invocation of the battle-scoped Node pattern** + **1st invocation of single-class match-dispatch over subclass hierarchy pattern** in the project (vs ADR-0018 DestinyBranchJudge @abstract subclass hierarchy precedent — establishes pattern boundary for closed enum-keyed dispatch with closed MVP scope vs open extensibility + complex test stubbing requirements) + **2nd invocation of LOCAL-signal-not-GameBus pattern** (after GridBattleController's 6 LOCAL signals; AISystem emits 1 LOCAL signal `ai_action_ready` declared on AISystem class itself). Pillar 2 architectural lock pattern stable at **4 invocations** with `ai_system_reads_destiny_branch_state` (4th precedent after BattleHUD + ScenarioRunner + DestinyBranchJudge per delta #15 + #12 + #13). Closes the cross-director convergent blocker per gate-check 2026-05-04 path-to-PASS item #4 (CD Pillar 3 + TD no-ADR + PR no-epic).

## Pattern Boundary Precedent

**6th invocation of battle-scoped Node pattern** + **1st invocation of single-class match-dispatch over subclass hierarchy pattern** + **2nd invocation of LOCAL-signal-not-GameBus pattern** + **4th invocation of pillar-anchored lint pattern (Pillar 2 architectural lock)**:

| Pattern Aspect | Invocation # | Predecessor | Form |
|---|---|---|---|
| Battle-scoped Node | **6th** | HPStatusController (ADR-0010 1st) + TurnOrderRunner (ADR-0011 2nd) + BattleCamera (ADR-0013 3rd) + GridBattleController (ADR-0014 4th) + BattleHUD (ADR-0015 5th) | `class_name AISystem extends Node` mounted at BattleScene step 5.5 + setup-before-add_child mandate + `_exit_tree()` GameBus disconnect discipline + battle-scoped non-persistence (no static var; battle-scoped instance state only) |
| Single-class match-dispatch over subclass hierarchy | **1st** | (no precedent — establishes pattern boundary) | `_score_candidate(archetype, ...) -> float` body is a `match archetype` statement routing to one of 4 per-archetype scoring functions (_score_aggressor / _score_skirmisher / _score_holder / _score_coordinator); contrasts with ADR-0018 DestinyBranchJudge @abstract subclass hierarchy for open extensibility + complex test stubbing — establishes pattern boundary: single-class match-dispatch for closed enum-keyed dispatch with closed MVP scope (4 archetypes per CR-AI-3); subclass hierarchy with @abstract test seam for open extensibility + complex test stubbing requirements (post-MVP refactor option per Alternative §4 deferred path) |
| LOCAL-signal-not-GameBus | **2nd** | GridBattleController 6 LOCAL signals (ADR-0014 1st) | AISystem 1 LOCAL signal `ai_action_ready(unit_id: int, command: AIActionCommand)` declared on AISystem class itself (NOT GameBus); defense-in-depth lint via ai_system_signal_emission_outside_action_ready forbidden_pattern; preserves GameBus 50-emits/frame budget per ADR-0001 §445 |
| Pillar-anchored lint pattern (Pillar 2 architectural lock) | **4th** | battle_hud_subscribes_to_hidden_fate_signal (ADR-0015 1st) + scenario_runner_deferred_seal_in_beat_7_entry (ADR-0017 2nd) + destiny_branch_judge_reads_scenario_runner_state (ADR-0018 3rd) | `ai_system_reads_destiny_branch_state` — AISystem MUST NEVER reference `hidden_fate_condition_progressed` / `DestinyBranchChoice` / `destiny_branch_chosen` tokens per CR-AI-8; AI plays the mechanical battle, fate progress is invisible to it |

**5th project precedent of "ratification widening at upstream-ADR acceptance"**: Same-patch additive amendment to ADR-0014 §8 (5 LOCAL signals → 6 LOCAL signals; `ai_action_requested(unit_id: int, snapshot: BattleStateSnapshot)` added per delta #14 same-patch flip) after save_checkpoint_requested 2026-04-18 + scenario_complete delta #12 + scenario_beat_retried delta #12 + ADR-0017 line 209 instance-form widening delta #13. Pattern firmly stable at 5 invocations.

## MVP Scope (per ADR-0019 §Migration Plan §2..§5 — single coordinated patch)

This epic implements the MVP subset for sprint-7 S7-04 (single coordinated patch — battle-scoped Node 6th invocation + 4 archetypes + 4 lint scripts + Pillar 2 lock 4th precedent enforced):

- ✅ **3 new source files** at `src/feature/ai/` + `src/core/payloads/`:
  - `ai_system.gd` (~300 LoC) — `class_name AISystem extends Node` with 4 archetype scoring functions (_score_aggressor / _score_skirmisher / _score_holder / _score_coordinator) + match-dispatch + DI'd setup() + `_ready()` LOCAL signal subscription + `_exit_tree()` LOCAL signal disconnect + tie-break cascade (score DESC + target_unit_id ASC + target_coord.y ASC + target_coord.x ASC) + EC-AI-1 zero-candidates handling + EC-AI-2 all-suicidal handling + EC-AI-4 unknown-archetype fallback
  - `battle_state_snapshot.gd` (~30 LoC) — `class_name BattleStateSnapshot extends Resource` with 7 typed @export fields (units / map_dimensions / terrain_grid / queue_unit_ids / round_number / chokepoints / formation_center) + `get_unit(unit_id)` accessor; flat-data only (no nested Resources)
  - `ai_action_command.gd` (~50 LoC) — `class_name AIActionCommand extends Resource` with 5 typed @export fields + 6 static factories (wait + move + attack + move_and_attack + defend + use_skill) + ActionType enum append-only per ADR-0003 SaveMigrationRegistry contract
- ✅ **2 test helpers** at `tests/helpers/`:
  - `battle_state_snapshot_factory.gd` (~50 LoC) — synthetic snapshot construction for unit tests
  - `ai_action_command_assertions.gd` (~30 LoC) — typed action_command equality helpers
- ✅ **5 unit + integration test files** covering AC-AI-1..14 (except AC-AI-12 + AC-AI-14 deferred):
  - `tests/unit/ai/ai_system_test.gd` (~200 LoC) — AC-AI-1 signal protocol compliance + AC-AI-2 determinism (100-invocation field-identical) + AC-AI-3 archetype differentiation (≥50% of synthetic scenarios) + AC-AI-13 soft-lock recovery
  - `tests/unit/ai/ai_aggressor_test.gd` (~100 LoC) — AC-AI-4 finishing behavior (5/5 ATTACK on kill target across 5 counter-attack-risk scenarios)
  - `tests/unit/ai/ai_skirmisher_test.gd` (~100 LoC) — AC-AI-5 kiting (MOVE to distance ≥3 + ATTACK only if kite leaves valid attack target)
  - `tests/unit/ai/ai_holder_test.gd` (~80 LoC) — AC-AI-6 chokepoint anchoring (MOVE-to-chokepoint OR WAIT, NOT advance toward player)
  - `tests/unit/ai/ai_coordinator_test.gd` (~120 LoC) — AC-AI-7 commander targeting (priority on `passive_id == &"command_aura"` overrides expected-damage maximization) + AC-AI-8 rally usage (USE_SKILL(rally) on first available turn with ≥2 adjacent allies)
- ✅ **4 CI lint scripts** at `tools/ci/` per ADR-0019 §Migration Plan §5:
  - `lint_ai_system_no_gamebus_emit.sh` — `ai_system_signal_emission_outside_action_ready` (9-precedent stateless-emit / non-emitter discipline mirror)
  - `lint_ai_system_no_static_var.sh` — `ai_system_static_var` (5-precedent battle-scoped + RefCounted lint pattern mirror)
  - `lint_ai_system_no_destiny_branch_reference.sh` — `ai_system_reads_destiny_branch_state` **Pillar 2 architectural lock 4th precedent**
  - `lint_ai_system_no_direct_state_read.sh` — `ai_system_direct_battle_state_read` (CR-AI-6 enforcement; 1-precedent pure-function-takes-snapshot mirror)
- ✅ **GridBattleController extension** at `src/feature/grid_battle/grid_battle_controller.gd` per ADR-0019 §Migration Plan §6:
  - Add `signal ai_action_requested(unit_id: int, snapshot: BattleStateSnapshot)` declaration (currently 5 signals at lines 85-99 → 6 signals; sprint-7+ source-code-side change ratified via /architecture-review delta #14 2026-05-05)
  - Add `_make_battle_state_snapshot() -> BattleStateSnapshot` private helper method that constructs snapshot from MapGrid + HPStatusController + TurnOrderRunner queries
  - Add `ai_action_requested.emit(unit_id, snapshot)` call site at AI-turn entry point per grid-battle.md CR-3
  - Add `ai_action_ready.connect(...)` subscription to AISystem instance via DI'd reference
- ✅ **BattleScene mount sequence step 5.5 insertion** per ADR-0016 §3 R-3 amended via delta #14:
  - Insert `var ai_system := AISystem.new(); ai_system.setup(_grid_controller); add_child(ai_system)` between current step 5 (GridBattleController) and step 6 (BattleHUD); preserves existing 1-6 numbering per Path A
- ✅ **Chapter-1 (장판파) ChapterDefinition.enemy_roster archetype assignments**: 하후돈=`&"aggressor"` + 장요=`&"skirmisher"` + 우금=`&"holder"` + 허저=`&"coordinator"` boss (sprint-7 S7-05 chapter-1 .tres authoring may co-ship; or this epic's .tres scaffold ships first as ChapterDefinition extension + S7-05 fills out narrative content)
- ✅ **10 BalanceConstants entries** per F-AI-Constants table (AGGRESSOR_KILL_BONUS / AGGRESSOR_WEAKNESS_WEIGHT / SKIRMISHER_RANGED_TARGET_BONUS / SKIRMISHER_SAFE_DISTANCE_BONUS / SKIRMISHER_MELEE_PENALTY / HOLDER_CHOKEPOINT_BONUS / HOLDER_OVEREXTEND_PENALTY / COORDINATOR_COMMANDER_TARGET_BONUS / COORDINATOR_RALLY_BONUS / AI_DECISION_TIMEOUT_MS) read via `BalanceConstants.get_const(key)` per ADR-0006

**Explicit deferrals**:

- ❌ **AC-AI-12 chapter-1 ending distribution test** — deferred until ScenarioRunner ships (sprint-7 S7-02) + chapter-1 ChapterDefinition .tres authored (sprint-7 S7-05); test scaffold may ship at S7-04 with `@warning_ignore("unused_test")` annotation pending integration runway
- ❌ **AC-AI-14 save/load determinism replay** — deferred until Save/Load #17 VS GDD lands (CUT from sprint-7 per Producer pressure-cut decision); structurally guaranteed by determinism contract (no static var + no randf + no Time.get_ticks_msec + no instance-var caching across calls), so test exists as documentation of structural guarantee
- ❌ **WorkerThreadPool offload** (EC-AI-12) — deferred to post-MVP amendment (NOT supersession) if P99 > 200ms profiling surfaces on reference Android; main-thread synchronous MVP execution per CR-AI-1
- ❌ **5th+ archetype** — deferred per CR-AI-3 closed 4-archetype MVP scope; if post-MVP archetype count exceeds ~6 OR scoring functions diverge dramatically, an amendment to ADR-0019 refactors to subclass hierarchy with @abstract func _score_candidate test seam per Alternative §4 deferred path
- ❌ **AI difficulty levels** (easy / normal / hard per OQ-AI-5) — POST-MVP; MVP ships single difficulty tuned to "어렵지만 가능"
- ❌ **AI status-effect awareness** (OQ-AI-2 — POISON tick prediction, DEMORALIZED radius) — POST-MVP; defer until post-MVP if AI feels too dumb in status-heavy fights
- ❌ **Behavior trees / GOAP / Min-Max / MCTS** — REJECTED per ADR-0019 Alternatives §5 + §6 (out of MVP scope; rule-based + utility + per-archetype-tuning is the right complexity tier for solo-dev MVP)

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| **ADR-0019 AI System** (Accepted 2026-05-05 via /architecture-review delta #14) | Battle-scoped Node 6th invocation + single-class match-dispatch on archetype StringName (1st invocation of this pattern; closed 4-archetype MVP scope per CR-AI-3) + 2 typed Resource payloads (BattleStateSnapshot 7-field flat-data + AIActionCommand 5-field with append-only ActionType enum mirroring BattleOutcome.Result discipline) + BattleScene mount step 5.5 insertion (Path A — preserves existing 1-6 numbering) + LOCAL signal subscription to GridBattleController.ai_action_requested with CONNECT_DEFERRED + LOCAL signal emission ai_action_ready (NOT GameBus) + main-thread synchronous MVP execution (WorkerThreadPool deferred to post-MVP amendment per EC-AI-12) + 4 forbidden_patterns including ai_system_reads_destiny_branch_state Pillar 2 architectural lock 4th precedent | **LOW** (Godot 4.6 pinned; no post-cutoff APIs required by this ADR — pre-4.4 stable APIs only: Node lifecycle + typed signal + match + Resource @export) |
| ADR-0014 GridBattleController (depends-on; amended via delta #14) | Owns `ai_action_requested(unit_id: int, snapshot: BattleStateSnapshot)` LOCAL signal emission (6th LOCAL signal added via /architecture-review delta #14 same-patch additive amendment to §8 + R-9 budget revision 5 → 6 signals + Enables block ADR-0019 entry + §9 architecture diagram row + 2 architecture.yaml entry updates) + `ai_action_ready(unit_id: int, command: AIActionCommand)` LOCAL signal consumption + 500ms timeout per CR-3 + WAIT substitution per CR-3a + `ai_soft_lock_counter` escalation per CR-3b. AISystem is a pure responder. **5th project precedent of "ratification widening at upstream-ADR acceptance"**. | LOW |
| ADR-0017 Scenario Progression (depends-on) | `ChapterDefinition` typed Resource carries `enemy_roster: Array[Dictionary]` where each entry has `archetype: StringName` field (sprint-7+ S7-05 chapter-1 .tres authoring populates this); ScenarioRunner validates archetype on chapter-load (caller responsibility per EC-AI-4 fallback) | LOW |
| ADR-0011 Turn Order (depends-on) | `is_player_controlled: bool` flag distinguishes AI units; AI System does not subscribe to turn-order signals directly (consumed transitively via Grid Battle's `ai_action_requested` emission per CR-AI-6) | LOW |
| ADR-0010 HP/Status (depends-on) | Read-only consumer via BattleStateSnapshot.units (current_hp + status_effects per CR-AI-6); no direct HPStatusController.X read per ai_system_direct_battle_state_read forbidden_pattern | LOW |
| ADR-0004 Map/Grid (depends-on) | Read-only consumer via BattleStateSnapshot.terrain_grid + map_dimensions (Dijkstra movement-range queries snapshot-bound per CR-AI-6) | LOW |
| ADR-0012 Damage Calc (depends-on) | `DamageCalc.preview()` read-only path used in utility scoring per F-AI-1..4; AISystem does NOT replicate damage math (EC-AI-7 command_aura interaction handled transitively via DamageCalc.preview which already accounts for aura) | LOW |
| ADR-0006 Balance/Data (depends-on) | 10 net-new tuning constants per F-AI-Constants table; `BalanceConstants.get_const(key)` lookup per ADR-0006 lazy-load pattern | LOW |
| ADR-0016 Battle Scene Wiring (depends-on; amended via delta #14) | 6-step mount sequence amended to insert step 5.5 AISystem mount per ADR-0019 §Mount Order (Path A — preserves existing 1-6 numbering; full 1-7 renumber deferred to sprint-7+ S7-02 same-patch as sprint-6 mock encoder deletion + lint phase-flip + main_scene revert per ADR-0017 Migration Plan §1) | LOW |
| ADR-0018 Destiny Branch (depends-on) | Pillar 2 architectural lock pattern 3-precedent extends to 4-precedent at this epic — `ai_system_reads_destiny_branch_state` mirrors `destiny_branch_judge_reads_scenario_runner_state` (1-precedent pure-function-takes-snapshot mirror); AISystem MUST NOT reference hidden_fate_condition_progressed / DestinyBranchChoice / destiny_branch_chosen tokens per CR-AI-8 | LOW |
| ADR-0001 GameBus | AISystem adds 0 entries to GameBus signal contract per ADR-0019 §Engine Compatibility verification; defense-in-depth lint via ai_system_signal_emission_outside_action_ready forbidden_pattern; LOCAL signal pattern preserves GameBus 50-emits/frame budget per ADR-0001 §445 | LOW |

**Highest Engine Risk among governing ADRs**: **LOW** for the AISystem-direct surface (ADR-0019 introduces zero new post-cutoff API surface). All APIs used are pre-4.4 stable.

## GDD / TR Requirements

15 net-new TRs registered as TR-ai-system-001..015 in `tr-registry.yaml` v15 (delta #14).

| TR-ID | Requirement (summary) | ADR Coverage |
|-------|----------------------|--------------|
| TR-ai-system-001 | AISystem `class_name AISystem extends Node` battle-scoped 6th invocation of pattern (after HPStatusController + TurnOrderRunner + BattleCamera + GridBattleController + BattleHUD); Autoload + RefCounted + static utility forms all REJECTED per Alternatives §1/§2/§3 | ADR-0019 ✅ |
| TR-ai-system-002 | Single-source-file with `match archetype` dispatch (NOT subclass hierarchy per Alternative §4 rejection); 1st invocation of single-class match-dispatch pattern in project; closed 4-archetype MVP vocabulary per CR-AI-3 | ADR-0019 ✅ |
| TR-ai-system-003 | `BattleStateSnapshot extends Resource` typed payload with 7 typed @export fields — flat-data only (no nested Resources) for trivial ResourceSaver round-trip per V-3 | ADR-0019 ✅ |
| TR-ai-system-004 | `AIActionCommand extends Resource` typed payload + 6 static factories + ActionType enum append-only per ADR-0003 SaveMigrationRegistry contract; 5 typed @export fields | ADR-0019 ✅ |
| TR-ai-system-005 | Mount order: BattleScene `_ready()` step 5.5 (Path A — preserves existing 1-6 numbering; full 1-7 renumber deferred to sprint-7+ S7-02 same-patch as sprint-6 mock encoder deletion + lint phase-flip + main_scene revert) | ADR-0019 ✅ |
| TR-ai-system-006 | LOCAL signal subscription to GridBattleController.ai_action_requested with CONNECT_DEFERRED; 6th LOCAL signal added to GridBattleController via /architecture-review delta #14 same-patch additive amendment; 5th project precedent of "ratification widening at upstream-ADR acceptance" | ADR-0019 ✅ |
| TR-ai-system-007 | LOCAL signal emission `ai_action_ready(unit_id: int, command: AIActionCommand)` declared on AISystem class itself (NOT GameBus); 2nd invocation of LOCAL-signal-not-GameBus pattern after GridBattleController; defense-in-depth lint via ai_system_signal_emission_outside_action_ready forbidden_pattern | ADR-0019 ✅ |
| TR-ai-system-008 | MANDATORY `_exit_tree()` body explicitly disconnects GridBattleController.ai_action_requested subscription (battle-scoped 6th invocation discipline mirrors HPStatusController + TurnOrderRunner + BattleCamera + GridBattleController + BattleHUD 5-precedent project pattern) | ADR-0019 ✅ |
| TR-ai-system-009 | Determinism contract: NO randf/randi/Time.get_ticks_msec/wall-clock + NO static var + NO instance-var caching across calls + NO external state read; lint-enforced via 4 forbidden_patterns; structurally guarantees AC-AI-14 save/load determinism replay | ADR-0019 ✅ |
| TR-ai-system-010 | Main-thread synchronous execution for MVP; WorkerThreadPool deferred to post-MVP amendment (NOT supersession) per EC-AI-12 if P99 > 200ms profiling surfaces on reference Android | ADR-0019 ✅ |
| TR-ai-system-011 | Forbidden pattern: ai_system_signal_emission_outside_action_ready (9-precedent stateless-emit / non-emitter discipline mirror; lint-enforced) | ADR-0019 ✅ |
| TR-ai-system-012 | Forbidden pattern: ai_system_static_var (5-precedent battle-scoped + RefCounted lint pattern mirror; lint-enforced) | ADR-0019 ✅ |
| TR-ai-system-013 | Forbidden pattern: ai_system_reads_destiny_branch_state — **Pillar 2 architectural lock — 4th project precedent of pillar-anchored lint pattern** after battle_hud_subscribes_to_hidden_fate_signal + scenario_runner_deferred_seal_in_beat_7_entry + destiny_branch_judge_reads_scenario_runner_state; 3-layer enforcement triad (lint + ADR annotation + integration test) per control-manifest §Pillar 2 Architectural Locks | ADR-0019 ✅ |
| TR-ai-system-014 | Forbidden pattern: ai_system_direct_battle_state_read (CR-AI-6 enforcement; 2nd invocation of pure-function-takes-snapshot pattern after destiny_branch_judge_reads_scenario_runner_state; lint-enforced) | ADR-0019 ✅ |
| TR-ai-system-015 | DI null-check assert in `_ready()` (GridBattleController reference required pre-add_child); mirrors 5-precedent battle-scoped Node DI null-check discipline from ADR-0010/0011/0013/0014/0015 | ADR-0019 ✅ |

**Untraced Requirements**: None (15/15 covered by ADR-0019).

## Same-Patch Obligations from ADR-0019 §Migration Plan §2..§5

These obligations land at the implementation story (S7-04) and ship together — single coordinated patch:

1. **3 new source files** at `src/feature/ai/` + `src/core/payloads/` (ai_system.gd ~300 LoC + battle_state_snapshot.gd ~30 LoC + ai_action_command.gd ~50 LoC per MVP Scope above)
2. **2 test helpers** at `tests/helpers/` (battle_state_snapshot_factory.gd ~50 LoC + ai_action_command_assertions.gd ~30 LoC)
3. **5 unit + integration test files** at `tests/unit/ai/` covering AC-AI-1..14 (except AC-AI-12 + AC-AI-14 deferred per Explicit deferrals above)
4. **4 CI lint scripts** at `tools/ci/` wired into `.github/workflows/tests.yml` (no_gamebus_emit + no_static_var + no_destiny_branch_reference Pillar 2 lock 4th precedent + no_direct_state_read CR-AI-6)
5. **GridBattleController extension** per ADR-0019 §Migration Plan §6: add `signal ai_action_requested(unit_id: int, snapshot: BattleStateSnapshot)` declaration (5 → 6 signals at lines 85-99) + `_make_battle_state_snapshot() -> BattleStateSnapshot` private helper + `ai_action_requested.emit(unit_id, snapshot)` call site at AI-turn entry + `ai_action_ready.connect(...)` subscription to AISystem
6. **BattleScene mount sequence step 5.5 insertion** per ADR-0019 §Mount Order + ADR-0016 §3 R-3 amended via delta #14: insert AISystem mount between current step 5 (GridBattleController) and step 6 (BattleHUD)
7. **ChapterDefinition.enemy_roster archetype field** + chapter-1 (장판파) archetype assignments (하후돈=&"aggressor" + 장요=&"skirmisher" + 우금=&"holder" + 허저=&"coordinator" boss) — sprint-7 S7-05 chapter-1 .tres authoring may co-ship
8. **10 BalanceConstants entries** appended per F-AI-Constants table (AGGRESSOR_KILL_BONUS through AI_DECISION_TIMEOUT_MS) read via `BalanceConstants.get_const(key)` per ADR-0006
9. **Verification summary doc** at `production/qa/evidence/ai_system_verification_summary.md` covering all 15 TR satisfaction proofs

## Pillar 2 Architectural Lock (4th Project Precedent)

`ai_system_reads_destiny_branch_state` is the **4th project precedent of pillar-anchored lint pattern** (after `battle_hud_subscribes_to_hidden_fate_signal` ADR-0015 1st + `scenario_runner_deferred_seal_in_beat_7_entry` ADR-0017 2nd + `destiny_branch_judge_reads_scenario_runner_state` ADR-0018 3rd — pattern firmly stable at 4 invocations).

3-layer enforcement triad codified per control-manifest.md §Pillar 2 Architectural Locks (2026-05-04 path-to-PASS item #3):

1. **Source-grep lint** — `tools/ci/lint_ai_system_no_destiny_branch_reference.sh` greps for `hidden_fate_condition_progressed|DestinyBranchChoice|destiny_branch_chosen` patterns; all matches FAIL (zero token occurrences in AI source)
2. **ADR-0019 §CR-AI-8 + Forbidden Patterns Proposed §3 inline annotation** + this epic's source-comment annotation in `ai_system.gd`
3. **Integration test** (sprint-7+ S7-04 implementation) asserting AISystem.scripts contain zero matches via FileAccess source-scan per G-22 structural assertion pattern

The lock prevents AI exposure of fate-state in scoring decisions — would create a feedback loop where AI difficulty correlates with player's fate progress, eliminating the surprise/weight/recognition that destiny-branch.md OQ-DB-10 makes a >10% miss-rate Pillar 2 failure threshold against. AI plays the mechanical battle; fate progress is invisible to it.

If a future AI System designer believes they need to surface fate progress to AI decision-making, they MUST first revise ADR-0019 (Superseded-by) AND `design/gdd/destiny-branch.md` Section B AND `design/gdd/game-concept.md` Pillar 2 — three coordinated revisions are intentionally hard.

## Stories

| # | Story | Type | Status | TR-IDs | Estimate |
|---|-------|------|--------|--------|----------|
| [001](story-001-ai-system-impl-and-pillar-2-lock-4th-precedent.md) | AISystem implementation per ADR-0019 Migration Plan §2..§5 + Pillar 2 architectural lock 4th precedent enforcement (epic-terminal) | Logic + Integration | **Complete** (S7-04 sprint-7 close 2026-05-05; 953/953 tests + 4/4 lints PASS; Pillar 2 lock 4th precedent enforced; Stories table row backfill via S11-02 2026-05-07 — 4th activation of sprint-10 retro AI #3) | TR-ai-system-001..015 (all 15) + AC-LINT-AI-1..2 + AC-GBC-1..4 + AC-MOUNT-1 + AC-CHAPTER-1 + AC-BC-1 | ~5-6h (0.5d nominal per sprint-7 plan; intermediate scale between scenario-progression story-001 multi-spawn and destiny-branch story-001 single-spawn — likely 1 SendMessage continuation) |

**Decision applied (per `/create-stories ai-system` 2026-05-05)**: **Option A — single epic-terminal story**. Rationale:
- ADR-0019 §Migration Plan §2..§5 explicit single coordinated patch atomicity (mirrors scenario-progression + destiny-branch story-001 framing)
- Sprint-7 plan S7-04 framing: "AISystem implementation per ADR-0019 §Migration Plan §2..§5 single coordinated patch"
- Intermediate scope: ~17-19 files vs scenario-progression story-001's ~22-26 files vs destiny-branch story-001's ~14 files
- 7 pre-resolved coordination decisions A-G embedded in story file (Decision A BattleScene._ready() rewrite atomicity with scenario-progression story-001 + Decision B chapter-1 .tres archetype field coordination + Decision C DestinyBranchJudge stub usage [no-op — Pillar 2 lock prevents] + Decision D BalanceConstants caching strategy + Decision E P99 perf scope per sprint-7 R-3 + Decision F Pillar 2 lock 4th precedent triad + Decision G single-class match-dispatch pattern stability) reduce SendMessage round-trip count
- Logic + Integration test ratio: ~70% Logic (4 archetype scoring functions + match-dispatch + tie-break cascade + determinism contract); ~30% Integration (GridBattleController LOCAL signal protocol + BattleScene mount step 5.5 + 4 lints + chapter-1 archetype assignments + 10 BalanceConstants)

**Total estimate**: ~5-6h = ~0.6-0.75 working days (within sprint-7 S7-04 0.5d nominal budget; per 4th-consecutive AI #1 ratchet baseline of 5× velocity multiplier from sprint-5/6, projected actual ~0.12-0.15 calendar day = ~1-1.5h wall-clock).

**Implementation order**: Depends on scenario-progression story-001 completion (S7-02 must close first per Decision A + Decision B). Once unblocked: story-001 (single epic-terminal) → `/code-review` (lean-mode orchestrator-direct per 13-precedent project default) → `/story-done` (closes epic at 1/1 Complete). Coordinate atomicity with scenario-progression story-001 BattleScene._ready() rewrite per Decision A — both stories may land in same sprint-7 commit window.

**Sprint allocation**: epic preview (this artifact) at S7-01 post-acceptance scaffold batch (delta #14 same-session-as-S7-01); implementation at S7-04 (sprint-7 critical path; 0.5d nominal per sprint-7 plan; depends on S7-01 + S7-02).

## Definition of Done

This epic is complete when:

- All stories are implemented, reviewed, and closed via `/story-done`
- All 15 TR-ai-system-* requirements are satisfied (verified against `docs/architecture/tr-registry.yaml`)
- The 9 same-patch obligations above are shipped (3 source files + 2 test helpers + 5 unit/integration tests + 4 lints + GridBattleController extension + BattleScene mount step 5.5 + ChapterDefinition.enemy_roster archetype assignments + 10 BalanceConstants + verification summary)
- AISystem battle-scoped Node 6th invocation mounted + 4 archetypes scoring functions + signal protocol AC-AI-1 + determinism AC-AI-2 + archetype differentiation AC-AI-3 + per-archetype behavior AC-AI-4..8 verified
- 4 lint scripts pass in CI (Pillar 2 architectural lock 4th-precedent enforcement triad: source-grep lint + ADR annotation + integration test for `ai_system_reads_destiny_branch_state`)
- `ai_action_requested` 6th LOCAL signal added to GridBattleController source per ADR-0019 §Migration Plan §6 + `_make_battle_state_snapshot()` private helper + `ai_action_requested.emit()` call site at AI-turn entry
- BattleScene mount sequence inserts step 5.5 AISystem mount per ADR-0016 §3 R-3 amended via delta #14
- Chapter-1 (장판파) ChapterDefinition.enemy_roster archetype assignments populated (sprint-7 S7-05 chapter-1 .tres co-ship or scaffold)
- 10 BalanceConstants entries appended per F-AI-Constants table
- The full regression baseline remains failure-free (target: ~960 PASS at sprint-7 close per sprint-7 plan; +10-12 from this epic alone)

## Next Step

Run `/create-stories ai-system` to break this epic into implementable stories. Decision pending: 1 epic-terminal story (Option A — matches "single coordinated patch" framing) vs 2-story decomposition (Option B — code-review checkpoint between AISystem internal architecture and integration plumbing) vs 3-story decomposition (Option C — separate per-archetype tuning iteration). Sprint-7 S7-04 is the critical path; depends on S7-01 + S7-02 ScenarioRunner ChapterDefinition.enemy_roster archetype field consumer. Once stories created, run `/dev-story [story-path]` per implementation order.

**Unblocks**: chapter-1 (장판파) end-to-end playable arc per sprint-7 +1 playable-surface delta target (AISystem responds to GridBattleController per CR-3 protocol; 4-archetype enemy roster pressures player roles asymmetrically per Pillar 3); chapter-prototype graduation from naive single-archetype AI (battle_v2.gd:596-678 greedy step + nearest target) to Production-grade architecture; cross-director gate-check upgrade CONCERNS → PASS (closes the cross-director convergent blocker per gate-check 2026-05-04 path-to-PASS item #4).
