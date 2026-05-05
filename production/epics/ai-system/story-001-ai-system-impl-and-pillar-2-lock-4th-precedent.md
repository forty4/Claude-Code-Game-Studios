# Story 001: AISystem implementation per ADR-0019 Migration Plan §2..§5 + Pillar 2 architectural lock 4th precedent enforcement

> **Epic**: ai-system
> **Status**: Complete (2026-05-05 — single coordinated patch; 953/953 tests + 4/4 lints PASS; Pillar 2 lock 4th precedent enforced)
> **Layer**: Feature
> **Type**: Logic + Integration (Logic for 4 archetype scoring functions + match-dispatch + tie-break cascade + determinism contract; Integration for GridBattleController LOCAL signal protocol + BattleScene mount step 5.5 + 4 lints including Pillar 2 architectural lock 4th precedent + ChapterDefinition.enemy_roster archetype field consumer + 10 BalanceConstants entries)
> **Manifest Version**: 2026-05-04 (`docs/architecture/control-manifest.md`)
> **Sprint Slot**: S7-04 (sprint-7 critical path; 0.5d nominal estimate per sprint-7 plan; depends on S7-01 + S7-02)
> **Epic-terminal**: Yes — closes ai-system epic at story completion

## Context

**GDD**: `design/gdd/ai-system.md` rev 1.0 (Designed; CR-AI-1..8 + F-AI-1..4 + EC-AI-1..12 + AC-AI-1..14 + OQ-AI-1..5; CR-AI-1 step number reconciled "6.5" → "5.5" via /architecture-review delta #14 same-patch wording flip 2026-05-05)

**Requirements**: `TR-ai-system-001..015` (all 15 — per epic terminal scope; tr-registry.yaml v15)

*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0019 AI System (Accepted 2026-05-05 via /architecture-review delta #14)

**ADR Decision Summary**: Battle-scoped Node 6th invocation + single-class match-dispatch on archetype StringName (1st invocation of this pattern; closed 4-archetype MVP scope per CR-AI-3) + 2 typed Resource payloads (BattleStateSnapshot 7-field flat-data + AIActionCommand 5-field with append-only ActionType enum mirroring BattleOutcome.Result discipline) + BattleScene mount step 5.5 insertion (Path A — preserves existing 1-6 numbering) + LOCAL signal subscription to GridBattleController.ai_action_requested with CONNECT_DEFERRED + LOCAL signal emission ai_action_ready (NOT GameBus) + main-thread synchronous MVP execution (WorkerThreadPool deferred to post-MVP amendment per EC-AI-12) + 4 forbidden_patterns including ai_system_reads_destiny_branch_state Pillar 2 architectural lock 4th precedent.

**Engine**: Godot 4.6 | **Risk**: LOW (zero new post-cutoff API surface; pre-4.4 stable APIs only — Node lifecycle + typed signal + match + Resource @export)

**Engine Notes**: Per ADR-0019 §Engine Compatibility table. NONE post-cutoff APIs used. The GDD's optional post-MVP `WorkerThreadPool` offload (EC-AI-12) is NOT in scope of this story — same-patch deferral. Verification Required: (1) BattleStateSnapshot extends Resource with 7 typed @export fields round-trips through ResourceSaver/ResourceLoader; (2) AIActionCommand extends Resource with @export action_type: ActionType (typed enum) + optional fields parses + serializes correctly; (3) AISystem `_exit_tree()` disconnects the GridBattleController ai_action_requested subscription per battle-scoped Node 6-precedent _exit_tree discipline; (4) Static lint `lint_ai_system_no_destiny_branch_reference.sh` rejects any hidden_fate_condition_progressed / DestinyBranchChoice / destiny_branch_chosen token (Pillar 2 lock 4th precedent); (5) Static lint `lint_ai_system_no_direct_state_read.sh` rejects any MapGrid. / HPStatusController. / TurnOrderRunner. reference outside the snapshot-parameter binding (CR-AI-6). HIGH-risk surface owned by ADR-0015 (4.6 dual-focus + 4.5 AccessKit + 4.5 recursive Control disable) is NOT re-asserted at AISystem level — AISystem has no UI surface.

**Control Manifest Rules (Feature layer + AI System domain)**:
- **Required**: `class_name AISystem extends Node` battle-scoped Node 6th invocation (after HPStatusController + TurnOrderRunner + BattleCamera + GridBattleController + BattleHUD); single-class match-dispatch on archetype StringName (NOT subclass hierarchy per Alternative §4 rejection); setup-before-add_child mandate inherited from 5-precedent project discipline; 1 LOCAL signal subscription to GridBattleController.ai_action_requested with CONNECT_DEFERRED at AISystem `_ready()`; 1 LOCAL signal emission `ai_action_ready(unit_id: int, command: AIActionCommand)` declared on AISystem class (NOT GameBus); MANDATORY `_exit_tree()` body explicitly disconnects the subscription per battle-scoped 6th invocation `_exit_tree` discipline.
- **Forbidden**: GameBus signal emission from AISystem (lint-enforced via `ai_system_signal_emission_outside_action_ready` 9-precedent stateless-emit / non-emitter discipline mirror). `static var` ANYWHERE in AISystem class hierarchy (lint-enforced via `ai_system_static_var` 5-precedent battle-scoped + RefCounted lint pattern mirror). Reading `hidden_fate_condition_progressed` / `DestinyBranchChoice` / `destiny_branch_chosen` tokens (lint-enforced via `ai_system_reads_destiny_branch_state` **Pillar 2 architectural lock 4th project precedent** of pillar-anchored lint pattern after battle_hud_subscribes_to_hidden_fate_signal + scenario_runner_deferred_seal_in_beat_7_entry + destiny_branch_judge_reads_scenario_runner_state). Reading `MapGrid.` / `HPStatusController.` / `TurnOrderRunner.` outside BattleStateSnapshot parameter binding (lint-enforced via `ai_system_direct_battle_state_read` CR-AI-6 enforcement; 1-precedent pure-function-takes-snapshot mirror from `destiny_branch_judge_reads_scenario_runner_state`).
- **Guardrail**: Determinism BY CONSTRUCTION per CR-AI-5 — identical (BattleStateSnapshot, unit_id, archetype assignment, round_number) → field-identical AIActionCommand output (AC-AI-2 100-invocation determinism); NO RNG (no randf/randi) / NO wall-clock (no Time.get_ticks_msec) / NO instance-var caching across calls / NO external state read. P99 decision time < 200ms on mid-tier Android per AC-AI-11 within 500ms timeout (grid-battle.md CR-3). Per battle: ~5-7 rounds × ~4 enemies × ~100ms typical = ~2-3 seconds total AI compute time (out of ~5-15 minute battle wall-clock).

---

## Acceptance Criteria

*From GDD `design/gdd/ai-system.md` §AC-AI-1..AC-AI-14; story scoped to ~12 ACs covering signal protocol + determinism + archetype differentiation + per-archetype behavior + 2 lints + perf + soft-lock recovery. AC-AI-12 chapter-1 distribution + AC-AI-14 save/load determinism deferred per Out of Scope.*

### Signal protocol + determinism + archetype differentiation (AC-AI-1..3)

- [ ] **AC-AI-1** (signal protocol compliance) — Given a fresh battle with 4 enemy units of mixed archetypes (aggressor/skirmisher/holder/coordinator per chapter-1 (장판파) roster), when `ai_action_requested(unit_id, snapshot)` fires for each (via mocked GridBattleController + DI'd reference), then `ai_action_ready(unit_id, command)` MUST be emitted within 500ms for each, in arbitrary order.
- [ ] **AC-AI-2** (determinism) — Given identical `BattleStateSnapshot` + identical archetype assignment + identical `unit_id` + identical `round_number`, AISystem.decide(...) MUST return field-identical `AIActionCommand`. Test runs 100 invocations of each archetype (4 archetypes × 100 = 400 invocations) with cloned snapshots, asserts all 100 return same `action_type`, `move_target`, `attack_target_unit_id` per archetype.
- [ ] **AC-AI-3** (archetype differentiation) — Given identical battle state + 4 different archetype assignments to the SAME unit (aggressor / skirmisher / holder / coordinator), the 4 resulting `AIActionCommand` outputs MUST differ in at least 1 field for at least 50% of synthetic test scenarios (proves archetypes actually behave differently, not converging to same action under standard conditions). ~10 synthetic scenarios sampled per archetype-pair → ≥50% differentiation rate.

### Per-archetype behavior (AC-AI-4..8)

- [ ] **AC-AI-4** (aggressor finishing behavior) — Given aggressor adjacent to a player unit at HP_pct ≤ 0.30 + that attack would kill, AI MUST submit ATTACK (not MOVE / not WAIT / not DEFEND). Tested across 5 scenarios with different counter-attack risks; 5/5 must return ATTACK on the kill target.
- [ ] **AC-AI-5** (skirmisher kiting) — Given skirmisher with range 2 + player melee unit at distance 1, AI MUST submit MOVE to a tile at distance ≥ 3 (kite away) and ATTACK only if the kite leaves a valid attack target in range.
- [ ] **AC-AI-6** (holder chokepoint anchoring) — Given holder at distance 1 from designated chokepoint + 0 player units in attack range, AI MUST submit MOVE-to-chokepoint OR WAIT (if already at chokepoint), NOT advance toward the player.
- [ ] **AC-AI-7** (coordinator commander targeting) — Given coordinator with 유비 (`passive_id == &"command_aura"`) in attack range AND another non-commander player unit also in attack range with HIGHER expected damage, AI MUST submit ATTACK on 유비 (commander priority overrides expected-damage maximization).
- [ ] **AC-AI-8** (coordinator rally usage) — Given coordinator with ≥2 adjacent allies + rally skill off-cooldown, AI MUST submit USE_SKILL(rally) on its first available turn.

### Pillar 2 architectural lock + CR-AI-6 enforcement (AC-AI-9, 10)

- [ ] **AC-AI-9** (Pillar 2 architectural lock 4th precedent) — Static lint `lint_ai_system_no_destiny_branch_reference.sh` asserts `grep -E 'hidden_fate_condition_progressed|DestinyBranchChoice|destiny_branch_chosen' src/feature/ai/ai_system.gd` returns 0 matches. Codifies CR-AI-8 Pillar 2 architectural lock — AI MUST NOT introspect Pillar 2 hidden-fate state. **4th project precedent of pillar-anchored lint pattern** after battle_hud_subscribes_to_hidden_fate_signal (ADR-0015 1st) + scenario_runner_deferred_seal_in_beat_7_entry (ADR-0017 2nd) + destiny_branch_judge_reads_scenario_runner_state (ADR-0018 3rd). Pattern firmly stable at 4 invocations.
- [ ] **AC-AI-10** (no direct GameBus state read) — Static lint `lint_ai_system_no_direct_state_read.sh` asserts `grep -rE "MapGrid\\.|HPStatusController\\.|TurnOrderRunner\\." src/feature/ai/ai_system.gd` returns 0 matches outside `_on_ai_action_requested` snapshot parameter usage (the `_grid_battle_controller: GridBattleController` field declaration is exempt — it's the DI'd reference, not a state read). Codifies CR-AI-6 pure-function-takes-snapshot pattern; **2nd invocation of pure-function-takes-snapshot pattern** after destiny_branch_judge_reads_scenario_runner_state.

### Performance + soft-lock recovery (AC-AI-11, 13)

- [ ] **AC-AI-11** (decision time budget) — P99 decision time across 100 randomized snapshots MUST be < 200ms on mid-tier Android reference hardware (Pixel 7-class Adreno 610). Test at `tests/performance/ai/ai_decision_p99_test.gd` (deferred Android device test; sprint-7 ships P99 < 200ms on Linux Editor + Windows D3D12 reference per sprint-7 R-3 — full Android perf verification deferred to release-prep sprint).
- [ ] **AC-AI-13** (soft-lock recovery) — Given an AISystem with deliberate fault injection (force `decide()` to throw or never return), GridBattleController's CR-3 timeout MUST fire at 500ms + WAIT substitution MUST occur + `ai_soft_lock_counter` MUST increment. Test verifies the GridBattleController-side defense (this story's AISystem implementation must not emit a faulted ai_action_ready; must not crash; must let GridBattleController's timer-based fallback handle).

### Additional ADR-0019 §Decision validation criteria (V-1..V-12 — sprint-7 scope subset)

- [ ] **V-1** (DI null-check assert in `_ready()`) — `assert(_grid_battle_controller != null, "AISystem: setup() must be called before add_child()")` per battle-scoped Node 6-precedent setup-before-add_child mandate
- [ ] **V-2** (`_exit_tree()` disconnect) — `if _grid_battle_controller != null and _grid_battle_controller.ai_action_requested.is_connected(_on_ai_action_requested): _grid_battle_controller.ai_action_requested.disconnect(_on_ai_action_requested)` — verified via grep on source
- [ ] **V-5** (4 lint scripts green on initial implementation patch) — covered by AC-AI-9 + AC-AI-10 + AC-LINT-AI-1 + AC-LINT-AI-2 below
- [ ] **V-6** (AC-AI-1 signal protocol compliance) — covered above
- [ ] **V-7** (AC-AI-2 determinism) — covered above
- [ ] **V-8** (AC-AI-3 archetype differentiation) — covered above
- [ ] **V-9** (AC-AI-11 P99 < 200ms) — covered above (sprint-7 scope: Linux + Windows lanes; Android deferred)
- [ ] **V-11** (AC-AI-13 soft-lock recovery) — covered above
- [ ] **V-12** (mount sequence integration — BattleScene `_ready()` mounts 7 systems in order; AISystem mounted at step 5.5; BattleHUD's AI-thinking-indicator subscription succeeds at HUD `_ready()`) — covered by AC-MOUNT-1 below

### 4 forbidden_pattern lints (per ADR-0019 §Migration Plan §5)

- [ ] **AC-LINT-AI-1** (`lint_ai_system_no_gamebus_emit.sh`) — `grep -c 'GameBus\..*\.emit' src/feature/ai/ai_system.gd` returns 0 matches; defense-in-depth lint mirroring 9-precedent stateless-emit / non-emitter discipline (damage_calc + unit_role + hero_database + balance_constants + camera + battle_hud + grid_battle_controller_outside_battle_domain + destiny_branch_judge_emits_gamebus_signal); pattern stable at 9 invocations
- [ ] **AC-LINT-AI-2** (`lint_ai_system_no_static_var.sh`) — `grep -E '^static var' src/feature/ai/ai_system.gd` returns 0 matches; 5-precedent battle-scoped + RefCounted lint pattern mirror (grid_battle_controller + hp_status + turn_order + destiny_branch_judge); CR-AI-5 determinism contract enforcement

### GridBattleController extension (per ADR-0019 §Migration Plan §6)

- [ ] **AC-GBC-1** (6th LOCAL signal declaration) — `signal ai_action_requested(unit_id: int, snapshot: BattleStateSnapshot)` added to `src/feature/grid_battle/grid_battle_controller.gd` lines 85-99 (currently 5 signals → 6 signals); per ADR-0014 §8 amended via /architecture-review delta #14 2026-05-05
- [ ] **AC-GBC-2** (`_make_battle_state_snapshot()` private helper) — `_make_battle_state_snapshot() -> BattleStateSnapshot` private method added to GridBattleController; constructs snapshot from MapGrid + HPStatusController + TurnOrderRunner queries (read-only); populates 7 typed @export fields (units / map_dimensions / terrain_grid / queue_unit_ids / round_number / chokepoints / formation_center); flat-data only (no nested Resources)
- [ ] **AC-GBC-3** (emit call site at AI-turn entry) — `ai_action_requested.emit(unit_id, snapshot)` call site added at GridBattleController AI-turn entry point per grid-battle.md CR-3; emission triggered when current turn unit has `is_player_controlled == false` per ADR-0011 turn-order TurnOrderEntry; `ai_action_ready` subscriber (AISystem instance via DI'd reference) consumes within 500ms per CR-3 timeout
- [ ] **AC-GBC-4** (subscription to AISystem.ai_action_ready) — GridBattleController subscribes to AISystem.ai_action_ready(unit_id, command) per ADR-0019 §Decision body via DI'd reference; consumes the AIActionCommand and routes to action validator (CR-3a) + execution pipeline; on 500ms timeout substitutes WAIT (CR-3b) + increments ai_soft_lock_counter

### BattleScene mount step 5.5 insertion (per ADR-0019 §Mount Order + ADR-0016 §3 R-3 amended via delta #14)

- [ ] **AC-MOUNT-1** — `src/feature/battle_scene/battle_scene.gd._ready()` mount sequence inserts step 5.5 between current step 5 (GridBattleController) and step 6 (BattleHUD): `var ai_system := AISystem.new(); ai_system.setup(_grid_controller); add_child(ai_system)`. Path A insert preserves existing 1-6 numbering per /architecture-review delta #14 decision; full 1-7 renumber deferred to sprint-7+ scenario-progression story-001 (S7-02) when ADR-0016 is touched anyway for sprint-6 mock encoder deletion + lint phase-flip + main_scene revert. NOTE: Coordinate atomicity with scenario-progression story-001's mock encoder DELETION — both stories may land in same sprint-7 commit window; confirm at /dev-story spawn time which story is shipping the BattleScene._ready() edit (likely scenario-progression story-001 ships the full BattleScene._ready() rewrite per its Migration Plan, with this story's step 5.5 insertion as a same-patch addition OR in a follow-up commit if scenario-progression ships first).

### ChapterDefinition.enemy_roster archetype field consumer (per ADR-0019 §Migration Plan §8)

- [ ] **AC-CHAPTER-1** — `ChapterDefinition.enemy_roster: Array[Dictionary]` entries gain `archetype: StringName` field (one of 4 CR-AI-3 vocabulary StringNames: `&"aggressor"` / `&"skirmisher"` / `&"holder"` / `&"coordinator"`); ScenarioRunner validates archetype on chapter-load per EC-AI-4 (caller responsibility); AISystem reads via `unit.get("archetype", &"aggressor")` default fallback at `_on_ai_action_requested` handler. Chapter-1 (장판파) archetype assignments populated: 하후돈=`&"aggressor"` + 장요=`&"skirmisher"` + 우금=`&"holder"` + 허저=`&"coordinator"` (boss) per ADR-0019 §Migration Plan §8. Coordinate with chapter-1 .tres authoring (sprint-7 should-have S7-05) — this story may ship MINIMAL chapter-1 .tres scaffolding with archetype assignments; S7-05 fills out full narrative content per scenario-progression story-001 Decision B coordination.

### 10 BalanceConstants entries (per ADR-0019 §F-AI-Constants table)

- [ ] **AC-BC-1** (10 net-new BalanceConstants entries) — Append to `assets/data/balance/balance_entities.json` 10 keys per F-AI-Constants table:
  - `AGGRESSOR_KILL_BONUS = 50.0` (range 30-80; finishing weight)
  - `AGGRESSOR_WEAKNESS_WEIGHT = 20.0` (range 10-40; weakness magnet)
  - `SKIRMISHER_RANGED_TARGET_BONUS = 30.0` (range 15-50; ranged targeting)
  - `SKIRMISHER_SAFE_DISTANCE_BONUS = 25.0` (range 15-40; kite preference)
  - `SKIRMISHER_MELEE_PENALTY = 40.0` (range 25-60; melee panic)
  - `HOLDER_CHOKEPOINT_BONUS = 40.0` (range 25-60; chokepoint anchor)
  - `HOLDER_OVEREXTEND_PENALTY = 60.0` (range 40-80; formation cohesion)
  - `COORDINATOR_COMMANDER_TARGET_BONUS = 60.0` (range 40-90; commander priority)
  - `COORDINATOR_RALLY_BONUS = 80.0` (range 60-100; rally usage)
  - `AI_DECISION_TIMEOUT_MS = 500` (range 250-1000; per grid-battle.md CR-3)
- All read via `BalanceConstants.get_const(key)` per ADR-0006 lazy-load pattern at AISystem class-level constants resolution OR per-call lookup (implementer choice; if class-level, ensure G-15 reset discipline matches BalanceConstants pattern)

---

## Implementation Notes

*Derived from ADR-0019 §Migration Plan §2..§5 + delta #14 same-patch wording flips:*

### File Layout (3 source + 2 test helpers + 5 test files + 4 lints + 2 modified existing + 10 BalanceConstants)

**New source files** (Migration Plan §2):

1. `src/feature/ai/ai_system.gd` (~300 LoC) — `class_name AISystem extends Node` battle-scoped Node 6th invocation:
   - DI'd `_grid_battle_controller: GridBattleController` field (set by BattleScene at step 5.5 mount via `setup(controller)` BEFORE add_child per setup-before-add_child mandate; null-check assert in `_ready()` per V-1)
   - `signal ai_action_ready(unit_id: int, command: AIActionCommand)` LOCAL signal declared on AISystem class itself (NOT GameBus per ai_system_signal_emission_outside_action_ready forbidden_pattern)
   - `_ready()` body: `_grid_battle_controller.ai_action_requested.connect(_on_ai_action_requested, CONNECT_DEFERRED)` + null-check assert + `assert(err == OK)`
   - `_exit_tree()` body: `if _grid_battle_controller != null and _grid_battle_controller.ai_action_requested.is_connected(_on_ai_action_requested): _grid_battle_controller.ai_action_requested.disconnect(_on_ai_action_requested)` per battle-scoped 6th invocation `_exit_tree` discipline
   - `_on_ai_action_requested(unit_id: int, snapshot: BattleStateSnapshot)` handler: extract unit + archetype from snapshot.get_unit(unit_id) + enumerate candidates + score each via `_score_candidate(archetype, candidate, snapshot, unit) -> float` + tie-break cascade `(score DESC, target_unit_id ASC, target_coord.y ASC, target_coord.x ASC)` + EC-AI-1 zero-candidates handling (emit AIActionCommand.wait(unit_id)) + EC-AI-2 all-suicidal-≤-100 handling (emit WAIT) + emit ai_action_ready with materialized command
   - `_score_candidate(archetype, candidate, snapshot, unit) -> float`: `match archetype` body routing to one of 4 per-archetype scoring functions:
     - `_score_aggressor(cand, snapshot, unit) -> float` per F-AI-1 (expected_damage_dealt + AGGRESSOR_KILL_BONUS × P(kill) + AGGRESSOR_WEAKNESS_WEIGHT × (1-target_hp_pct) - 0.7 × expected_counter_damage_taken - 0.5 × distance + bonus_for_charge; WAIT=-100, DEFEND=-50)
     - `_score_skirmisher(cand, snapshot, unit) -> float` per F-AI-2 (expected_damage_dealt + SKIRMISHER_RANGED_TARGET_BONUS × ranged-target + SKIRMISHER_SAFE_DISTANCE_BONUS × safe-distance - SKIRMISHER_MELEE_PENALTY × melee-proximity - 0.4 × counter; WAIT=-50, DEFEND=-30)
     - `_score_holder(cand, snapshot, unit) -> float` per F-AI-3 (expected_damage_dealt + HOLDER_CHOKEPOINT_BONUS × chokepoint + 30 × adjacent-ally - HOLDER_OVEREXTEND_PENALTY × overextend - 0.3 × counter; WAIT=10 if at-chokepoint+no-player-in-range else -30; DEFEND=20 if attack-inbound)
     - `_score_coordinator(cand, snapshot, unit) -> float` per F-AI-4 (expected_damage_dealt + COORDINATOR_COMMANDER_TARGET_BONUS × command_aura-target + 35 × adjacent-ally + RALLY_USAGE_BONUS - 0.5 × counter; USE_SKILL(rally)=COORDINATOR_RALLY_BONUS if ≥2-adjacent-allies+off-cooldown else -100; WAIT=-10; DEFEND=30 if HP_pct<0.4)
     - `_:` default arm: push_warning("AI_UNKNOWN_ARCHETYPE: %s — falling back to aggressor" % archetype) + return _score_aggressor(...) per EC-AI-4
   - All scoring functions are pure functions over (candidate, snapshot, unit) — NO class-level state read per CR-AI-6 + ai_system_direct_battle_state_read forbidden_pattern; NO RNG / NO wall-clock / NO instance-var caching per CR-AI-5 determinism contract + ai_system_static_var forbidden_pattern
   - `_enumerate_candidates(unit, snapshot) -> Array[AICandidateAction]` private helper: compute reachable tiles via snapshot's terrain_grid (Dijkstra MOVE budget) + pair with attack targets in range OR WAIT/DEFEND/USE_SKILL; cap at 200 candidates per CR-AI-4 step 2; uses `effective_move_budget` from snapshot (already includes bridge_blocker per EC-AI-6)
   - `_materialize_command(unit_id, candidate) -> AIActionCommand` private helper: construct AIActionCommand instance from selected candidate via static factory (wait / move / attack / move_and_attack / defend / use_skill)
   - `_tie_break_keys(candidate) -> Dictionary` + `_descending_then_tie_break(a, b) -> bool` private helpers: per CR-AI-4 step 4 cascade
   - 10 BalanceConstants reads via `BalanceConstants.get_const(key)` cached at class-level OR per-call (implementer choice per ADR-0006 lazy-load pattern + G-15 reset discipline)

2. `src/core/payloads/battle_state_snapshot.gd` (~30 LoC) — `class_name BattleStateSnapshot extends Resource` with 7 typed @export fields per ADR-0019 §Decision §Payload Form: `units: Array[Dictionary]` (one entry per unit; archetype + position + hp + ...) + `map_dimensions: Vector2i` + `terrain_grid: PackedInt32Array` + `queue_unit_ids: Array[int]` (turn-order queue snapshot) + `round_number: int` + `chokepoints: Array[Vector2i]` (from ChapterDefinition; empty if none) + `formation_center: Vector2i` (centroid of allied units). Plus `get_unit(unit_id: int) -> Dictionary` accessor method. **Flat-data only** — NO nested Resource references for trivial ResourceSaver/Loader round-trip per V-3 verification. Constructed by GridBattleController._make_battle_state_snapshot() per AC-GBC-2.

3. `src/core/payloads/ai_action_command.gd` (~50 LoC) — `class_name AIActionCommand extends Resource` with 5 typed @export fields + 6 static factories + ActionType enum:
   - `enum ActionType { WAIT = 0, MOVE = 1, ATTACK = 2, MOVE_AND_ATTACK = 3, DEFEND = 4, USE_SKILL = 5 }` (append-only per ADR-0003 SaveMigrationRegistry contract — same discipline as BattleOutcome.Result; reordering values requires migration registry entry + schema_version bump)
   - `@export var unit_id: int = -1` + `@export var action_type: ActionType = ActionType.WAIT` + `@export var move_target: Vector2i = Vector2i.ZERO` (used iff MOVE/MOVE_AND_ATTACK) + `@export var attack_target_unit_id: int = -1` (used iff ATTACK/MOVE_AND_ATTACK) + `@export var skill_id: StringName = &""` (used iff USE_SKILL)
   - `static func wait(unit_id: int) -> AIActionCommand` + static factories for move + attack + move_and_attack + defend + use_skill (6 total per ADR-0019 §Decision §Payload Form)

**New test helpers** (Migration Plan §3):

4. `tests/helpers/battle_state_snapshot_factory.gd` (~50 LoC) — synthetic snapshot construction for unit tests; provides `BattleStateSnapshotFactory.make(units_dict, map_dimensions, ...)` builder pattern with default-fill of all 7 fields; covers chapter-1 enemy roster scenarios (4 archetypes × varied positions/HP) + edge case scenarios (zero-candidates fixture per EC-AI-1 + all-suicidal fixture per EC-AI-2 + unknown-archetype fixture per EC-AI-4)

5. `tests/helpers/ai_action_command_assertions.gd` (~30 LoC) — typed action_command equality helpers: `assert_action_command_equals(actual, expected)` + `assert_action_type(cmd, expected_type)` + `assert_targets_unit(cmd, target_unit_id)` + `assert_at_position(cmd, target_pos)` for clean test assertions

**New test files** (~10-12 net-new tests across 5 files per sprint-7 plan):

6. `tests/unit/ai/ai_system_test.gd` (~200 LoC) — AC-AI-1 signal protocol compliance + AC-AI-2 determinism (100-invocation field-identical per archetype) + AC-AI-3 archetype differentiation (≥50% across 10 synthetic scenarios) + AC-AI-13 soft-lock recovery (fault injection); ~4-6 tests
7. `tests/unit/ai/ai_aggressor_test.gd` (~100 LoC) — AC-AI-4 finishing behavior (5/5 ATTACK on kill target across 5 counter-attack-risk scenarios) + edge cases (all-suicidal kill paths verify EC-AI-2 forfeit-the-turn); ~2-3 tests
8. `tests/unit/ai/ai_skirmisher_test.gd` (~100 LoC) — AC-AI-5 kiting (MOVE to distance ≥3 + ATTACK only if kite leaves valid attack target) + edge cases (no kite available verify falls through to MOVE-and-attack OR WAIT); ~2-3 tests
9. `tests/unit/ai/ai_holder_test.gd` (~80 LoC) — AC-AI-6 chokepoint anchoring (MOVE-to-chokepoint OR WAIT, NOT advance toward player); ~2 tests
10. `tests/unit/ai/ai_coordinator_test.gd` (~120 LoC) — AC-AI-7 commander targeting (priority on `passive_id == &"command_aura"` 유비 overrides expected-damage maximization) + AC-AI-8 rally usage (USE_SKILL(rally) on first available turn with ≥2 adjacent allies); ~3-4 tests

**4 new lint scripts** at `tools/ci/` (per ADR-0019 §Migration Plan §5):

11. `tools/ci/lint_ai_system_no_gamebus_emit.sh` — AC-LINT-AI-1 (9-precedent stateless-emit / non-emitter discipline mirror)
12. `tools/ci/lint_ai_system_no_static_var.sh` — AC-LINT-AI-2 (5-precedent battle-scoped + RefCounted lint pattern mirror)
13. `tools/ci/lint_ai_system_no_destiny_branch_reference.sh` — AC-AI-9 **Pillar 2 architectural lock 4th project precedent** (3-layer enforcement triad: source-grep lint + ADR-0019 §CR-AI-8 inline annotation + integration test via FileAccess source-scan per G-22 structural assertion pattern)
14. `tools/ci/lint_ai_system_no_direct_state_read.sh` — AC-AI-10 (CR-AI-6 enforcement; 2nd invocation of pure-function-takes-snapshot pattern after destiny_branch_judge_reads_scenario_runner_state)

All 4 lints wired into `.github/workflows/tests.yml` after the existing 5 hp-status + 5 scenario-progression + 3 destiny-branch lint groups (from prior sprint-7 stories same-sprint).

**Modified existing files** (Migration Plan §6 + ADR-0019 §Mount Order):

15. `src/feature/grid_battle/grid_battle_controller.gd` — add 6th LOCAL signal `ai_action_requested(unit_id: int, snapshot: BattleStateSnapshot)` declaration at lines 85-99 (currently 5 signals; per AC-GBC-1) + `_make_battle_state_snapshot() -> BattleStateSnapshot` private helper method (per AC-GBC-2) + `ai_action_requested.emit(unit_id, snapshot)` call site at AI-turn entry per CR-3 (per AC-GBC-3) + `ai_action_ready.connect(...)` subscription to AISystem instance via DI'd reference (per AC-GBC-4)

16. `src/feature/battle_scene/battle_scene.gd._ready()` — insert step 5.5 AISystem mount: `var ai_system := AISystem.new(); ai_system.setup(_grid_controller); add_child(ai_system)` between current step 5 (GridBattleController) and step 6 (BattleHUD); per AC-MOUNT-1. Coordinate with scenario-progression story-001 BattleScene._ready() rewrite atomicity (Decision A below).

17. `assets/data/balance/balance_entities.json` — append 10 BalanceConstants entries per AC-BC-1 (F-AI-Constants table)

**Chapter-1 .tres scaffolding** (Migration Plan §8 — coordinate with scenario-progression story-001 Decision B + S7-05 chapter-1 full content authoring):

18. `assets/data/scenarios/scenario_01.json` (or chapter-1 ChapterDefinition .tres) — `enemy_roster: Array[Dictionary]` entries gain `archetype: StringName` field; populate chapter-1 archetype assignments: 하후돈=`&"aggressor"` + 장요=`&"skirmisher"` + 우금=`&"holder"` + 허저=`&"coordinator"` (boss). NOTE: scenario-progression story-001 ships MINIMAL chapter-1 .tres scaffolding per Decision B; this story EXTENDS that scaffolding with archetype assignments. If scenario-progression story-001 ships chapter-1 .tres without archetype field, this story adds the field same-patch.

**Verification summary** (epic terminal):

19. `production/qa/evidence/ai_system_verification_summary.md` — covers all 15 TR-ai-system-* satisfaction proofs + Pillar 2 architectural lock 4th-precedent enforcement triad (source-grep lint + ADR annotation + integration test) + battle-scoped Node 6th invocation pattern verification + LOCAL-signal-not-GameBus 2nd invocation verification

### Pre-resolved coordination decisions (per dev-story spawn prompt)

- **Decision A (BattleScene._ready() rewrite atomicity with scenario-progression story-001)**: scenario-progression story-001 (S7-02) ships full BattleScene._ready() rewrite including sprint-6 mock encoder DELETION + main_scene revert + Migration Plan §1 atomicity. This story (S7-04) inserts step 5.5 AISystem mount into the BattleScene._ready() body. **Coordinate**: if scenario-progression story-001 ships first (expected per sprint-7 dependency chain), this story's step 5.5 insertion is a same-patch addition to the post-rewrite BattleScene._ready(). If both stories ship in same commit window, the implementer of whichever ships last MUST verify the BattleScene._ready() body includes BOTH the mock encoder DELETION (per scenario-progression story-001 AC-MIGRATE-1) AND the AISystem step 5.5 mount (per this story AC-MOUNT-1). Atomicity is preserved by single-commit Migration Plan §1 framing inherited from scenario-progression story-001.

- **Decision B (chapter-1 .tres archetype field coordination with scenario-progression story-001 + S7-05)**: scenario-progression story-001 ships MINIMAL chapter-1 .tres scaffolding per its Decision B (full chapter-1 narrative content authoring is sprint-7 should-have S7-05). This story extends the chapter-1 .tres scaffolding with `enemy_roster` archetype field assignments (4 archetype values per ADR-0019 §Migration Plan §8). If S7-05 chapter-1 full authoring ships within the same sprint window, S7-05 MAY ship the archetype assignments instead — coordinate at /dev-story spawn-time which story owns the archetype field population.

- **Decision C (DestinyBranchJudge stub usage — coordinate with destiny-branch story-001)**: destiny-branch story-001 (S7-03) REPLACES the stub bodies from scenario-progression story-001 with authoritative impl. This story (S7-04) does NOT interact with DestinyBranchJudge at all — AI System has no DestinyBranch dependency per Pillar 2 architectural lock 4th precedent (`ai_system_reads_destiny_branch_state` lint enforces zero hidden_fate_condition_progressed / DestinyBranchChoice / destiny_branch_chosen tokens). Verify via AC-AI-9 lint test.

- **Decision D (BalanceConstants caching strategy)**: 10 F-AI-Constants reads can be cached at AISystem class-level (read once at class-load via `static const`) OR per-call (read each time via `BalanceConstants.get_const(key)`). Implementer choice; if class-level, ensure G-15 reset discipline matches BalanceConstants pattern (per-test fresh reset of cache_loaded flag). Per-call lookup is simpler and matches grid-battle-controller / camera precedents; recommend per-call unless profiling shows hotspot.

- **Decision E (P99 perf verification scope per sprint-7 R-3)**: AC-AI-11 P99 < 200ms target on Linux Editor + Windows D3D12 lanes only (CI-active per existing GdUnit4 setup); macOS / iOS / Android lanes are manual-test fallback for sprint-7. Full Android device perf verification deferred to release-prep sprint per CI lane gap. Document partial closure in verification summary.

- **Decision F (Pillar 2 architectural lock 4th precedent triad)**: 3-layer enforcement per control-manifest.md §Pillar 2 Architectural Locks: (1) source-grep lint per AC-AI-9; (2) ADR-0019 §CR-AI-8 inline annotation + this story's source-comment annotation in `ai_system.gd`; (3) integration test asserting `FileAccess.get_file_as_string("res://src/feature/ai/ai_system.gd").contains(...)` zero matches per G-22 structural assertion pattern. Mirror enforcement triad from destiny-branch story-001 AC-LINT-3 implementation.

- **Decision G (single-class match-dispatch over subclass hierarchy — pattern stability)**: This story is the **1st invocation of single-class match-dispatch over subclass hierarchy pattern** in the project (vs ADR-0018 DestinyBranchJudge @abstract subclass hierarchy precedent). Implementer: implement `_score_candidate(archetype, ...)` body as `match archetype:` statement routing to 4 per-archetype scoring functions (NOT 4 separate subclasses). If post-MVP archetype count exceeds ~6 OR scoring functions diverge dramatically, an amendment to ADR-0019 refactors to subclass hierarchy with @abstract func _score_candidate test seam per Alternative §4 deferred path — but for sprint-7 MVP, single-class match-dispatch is the locked decision per ADR-0019 §Decision §Archetype Dispatch.

### Multi-spawn-on-scale precedent

This story's deliverable scale is **smaller than scenario-progression story-001 (~22-26 files) but larger than destiny-branch story-001 (~14 files)**:

- ~17-19 files (3 source + 2 test helpers + 5 test files + 4 lints + 2 modified existing source + 10 BalanceConstants append + 1 chapter-1 .tres extension + 1 verification summary)
- ~300 LoC AISystem source code + ~10-12 test functions + ~50 LoC GridBattleController extension + 10 BalanceConstants entries
- Single coordinated patch atomicity per ADR-0019 §Migration Plan §2..§5

**Expected /dev-story spawn pattern**: 1 initial spawn + possibly 1 SendMessage continuation (intermediate scale between hp-status story-008 multi-spawn precedent and destiny-branch story-001 single-spawn-likely scale). Pre-resolved coordination decisions A-G above reduce SendMessage round-trip count.

---

## Out of Scope

*Handled by neighbouring stories or future sprints — do not implement here:*

- **AC-AI-12 chapter-1 ending distribution test** — deferred until ScenarioRunner ships (sprint-7 S7-02 — already shipping concurrently) + chapter-1 ChapterDefinition .tres authored (sprint-7 S7-05 should-have). Test scaffold MAY ship at this story with `@warning_ignore("unused_test")` annotation pending integration runway; if S7-05 ships in same sprint window, AC-AI-12 may execute as bonus coverage.
- **AC-AI-14 save/load determinism replay** — deferred until Save/Load #17 VS GDD lands (CUT from sprint-7 per Producer pressure-cut decision). Structurally guaranteed by determinism contract (CR-AI-5 + AC-AI-2 verification), so test exists as documentation of structural guarantee.
- **WorkerThreadPool offload (EC-AI-12)** — deferred to post-MVP amendment (NOT supersession) if P99 > 200ms profiling surfaces on reference Android. Main-thread synchronous MVP execution per CR-AI-1.
- **5th+ archetype** — deferred per CR-AI-3 closed 4-archetype MVP scope. If post-MVP archetype count exceeds ~6 OR scoring functions diverge dramatically, an amendment to ADR-0019 refactors to subclass hierarchy with @abstract func _score_candidate test seam per Alternative §4 deferred path.
- **AI difficulty levels** (easy / normal / hard per OQ-AI-5) — POST-MVP; MVP ships single difficulty tuned to "어렵지만 가능".
- **AI status-effect awareness** (OQ-AI-2 — POISON tick prediction, DEMORALIZED radius) — POST-MVP; defer until post-MVP if AI feels too dumb in status-heavy fights.
- **Behavior trees / GOAP / Min-Max / MCTS** — REJECTED per ADR-0019 Alternatives §5 + §6 (out of MVP scope; rule-based + utility + per-archetype-tuning is the right complexity tier for solo-dev MVP).
- **Chapter-2..N enemy roster archetype assignments** — POST-MVP; chapter-1 (장판파) only for sprint-7 scope per CR-AI-3 closed scope.
- **Battle Preparation epic dependency** — post-MVP per scenario-progression.md interaction §Battle Preparation; this story does NOT modify Battle Prep.
- **Full Android device P99 perf verification** — sprint-7 R-3 mitigation: Linux Editor + Windows D3D12 lanes only (manual-fallback for Android); full Android device perf verification deferred to release-prep sprint per CI lane gap noted in sprint-7 plan.
- **BattleHUD AI-thinking-indicator UI-GB-N subscription** — owned by sprint-7+ battle-hud GDD revision per ADR-0019 §Migration Plan §7; this story does NOT modify BattleHUD source.

---

## QA Test Cases

*Authored at story creation per skill Step 4b — QA Lead gate skipped in lean mode; orchestrator-direct authoring per project precedent. The developer implements against these test specs — do not invent new test cases during implementation.*

### Logic + Integration test specs (signal protocol + determinism + archetype differentiation — automated)

**AC-AI-1** (signal protocol compliance):
- Given: Mocked GridBattleController with 4 enemy units of mixed archetypes (1 aggressor + 1 skirmisher + 1 holder + 1 coordinator) on 6×6 stub map with 2 player units at varied positions; AISystem instance setup() with the mock controller + add_child()
- When: For each of the 4 enemy units, mock controller emits `ai_action_requested(unit_id, snapshot)` — snapshot captures the same battle state for each unit (verify same snapshot reused intentionally)
- Then: GameBus signal capture (or LOCAL signal capture on AISystem instance) shows `ai_action_ready(unit_id, command)` emitted within 500ms for each of the 4 unit_ids; emission order may vary (no order requirement); each command is a valid AIActionCommand instance with non-default unit_id matching the request
- Edge cases: 0-enemy battle (verify no ai_action_requested emitted; AISystem mounted but inactive) + 1-enemy battle (verify single ai_action_ready emitted) + 100-enemy stress test (verify all 100 ai_action_ready emitted; sub-200ms-each per AC-AI-11)

**AC-AI-2** (determinism — 100-invocation field-identical per archetype):
- Given: Single fixed BattleStateSnapshot (deep-copied for each call to prevent mutation leak) + single unit_id + single archetype (parameterized over 4 archetypes); first call captures baseline AIActionCommand
- When: Call AISystem._on_ai_action_requested 100 times with the same (snapshot.duplicate_deep, unit_id) inputs
- Then: All 100 returned AIActionCommand instances are field-identical to baseline across all 5 fields (action_type + move_target + attack_target_unit_id + skill_id + unit_id); failure on any field assertion = test fail
- Edge cases: Different round_number (verify distinct outputs per round_number; per CR-AI-5 round_number is part of determinism input) + parameterized over all 4 archetypes (verify each archetype produces deterministic output) + source-scan via FileAccess on `src/feature/ai/ai_system.gd` returns 0 matches for forbidden API patterns: `Time.get_ticks_msec`, `Time.get_ticks_usec`, `randi`, `randf`, `randf_range`, `randi_range`, `static var`

**AC-AI-3** (archetype differentiation — ≥50% across 10 synthetic scenarios):
- Given: 10 synthetic BattleStateSnapshot fixtures covering varied tactical situations (kite-vulnerable melee target / chokepoint defense / commander-in-range / surrounded coordinator / etc.) + same unit_id + 4 archetype assignments (aggressor / skirmisher / holder / coordinator)
- When: For each of 10 snapshots, call AISystem._on_ai_action_requested 4 times with 4 different archetype assignments to the SAME unit
- Then: For each snapshot, count the number of unique AIActionCommand outputs across the 4 archetype runs; assert that across 10 snapshots, ≥5 produce ≥3 unique outputs (= 50% threshold for archetype differentiation; proves archetypes don't all converge to same action)
- Edge cases: Pathological snapshot where all archetypes correctly converge to same action (e.g., zero-candidates scenario per EC-AI-1 — all archetypes WAIT) — verify counted as "0 unique" but doesn't fail the 50%-of-10 threshold

### Logic test specs (per-archetype behavior — automated)

**AC-AI-4** (aggressor finishing behavior — 5/5 ATTACK):
- Given: 5 BattleStateSnapshot fixtures covering aggressor adjacent to player unit at HP_pct ≤ 0.30 (kill-range) with varied counter-attack risks (low/medium/high counter-damage); AGGRESSOR_KILL_BONUS=50.0 applied per F-AI-1
- When: AISystem.decide() called for each fixture with aggressor archetype
- Then: All 5 returned AIActionCommand have action_type == ATTACK + attack_target_unit_id == kill-target unit_id; 5/5 must satisfy (no exceptions even on high-counter-risk; per F-AI-1 expected behavior — aggressor commits to kills)
- Edge cases: HP_pct = 0.31 (just above kill-range; verify NOT a finishing situation, normal aggressor behavior) + HP_pct = 0.0 (already-dead target, snapshot stale; verify EC-AI-3 GridBattleController-side WAIT substitution) + counter_damage > self.current_hp (kill-trade scenario; verify F-AI-1's 0.7 × counter_discount still allows ATTACK if expected_damage_dealt + bonuses outweigh the discounted counter-loss)

**AC-AI-5** (skirmisher kiting):
- Given: BattleStateSnapshot with skirmisher (range=2) + player melee unit (range=1) at distance=1 from skirmisher; map has reachable tiles at distance ≥ 3 from melee target via skirmisher's MOVE budget; SKIRMISHER_RANGED_TARGET_BONUS=30 + SKIRMISHER_SAFE_DISTANCE_BONUS=25 + SKIRMISHER_MELEE_PENALTY=40 per F-AI-2
- When: AISystem.decide() called with skirmisher archetype
- Then: Returned AIActionCommand has action_type ∈ {MOVE, MOVE_AND_ATTACK} + move_target at distance ≥ 3 from melee target (kite away); ATTACK target chosen only if kite-tile leaves a valid attack-range target
- Edge cases: No kite-tile available (verify falls through to ATTACK + DEFEND OR WAIT per F-AI-2 priority) + multiple kite-tiles at distance ≥ 3 (verify tie-break cascade picks deterministic winner) + ranged player target also in range (verify SKIRMISHER_RANGED_TARGET_BONUS prioritizes ranged player over melee even on kite path)

**AC-AI-6** (holder chokepoint anchoring):
- Given: BattleStateSnapshot with holder at distance 1 from designated chokepoint (e.g., (3,2) when chokepoint is (3,3)) + 0 player units in attack range; HOLDER_CHOKEPOINT_BONUS=40 + HOLDER_OVEREXTEND_PENALTY=60 per F-AI-3
- When: AISystem.decide() called with holder archetype
- Then: Returned AIActionCommand has action_type ∈ {MOVE, WAIT} where MOVE.move_target == chokepoint OR action_type == WAIT (if already at chokepoint); MUST NOT advance toward player (overextend penalty fires)
- Edge cases: Holder already at chokepoint with no player in range (verify WAIT_score=10 per F-AI-3 selects WAIT; not always-MOVE) + holder forced to choose between two chokepoints (verify tie-break cascade) + holder with player in attack range (verify ATTACK takes precedence over chokepoint anchor; F-AI-3 includes expected_damage_dealt in score)

**AC-AI-7** (coordinator commander targeting):
- Given: BattleStateSnapshot with coordinator + 유비 (`unit.get("passive_id") == &"command_aura"`) in coordinator's attack range AND another non-commander player unit also in attack range with HIGHER expected_damage_dealt than 유비; COORDINATOR_COMMANDER_TARGET_BONUS=60 per F-AI-4
- When: AISystem.decide() called with coordinator archetype
- Then: Returned AIActionCommand has action_type == ATTACK + attack_target_unit_id == 유비 unit_id (commander priority overrides expected-damage maximization due to +60 bonus on command_aura targets per F-AI-4)
- Edge cases: 유비 not in party (verify EC-AI-8 — coordinator falls back to standard utility + target_has_command_aura == false; bonus path is silently zero) + multiple command_aura targets (impossible per chapter-1 design but verify tie-break) + coordinator USE_SKILL(rally) preferred over ATTACK if rally off-cooldown (verify per AC-AI-8 priority over commander-target)

**AC-AI-8** (coordinator rally usage):
- Given: BattleStateSnapshot with coordinator + ≥2 adjacent allies + rally skill off-cooldown; COORDINATOR_RALLY_BONUS=80 per F-AI-4
- When: AISystem.decide() called with coordinator archetype
- Then: Returned AIActionCommand has action_type == USE_SKILL + skill_id == &"rally" (USE_SKILL(rally)_score=80 wins per F-AI-4 over WAIT/DEFEND/ATTACK)
- Edge cases: 1 adjacent ally (verify USE_SKILL_score=-100 per F-AI-4 — rally requires ≥2 adjacents; ATTACK or DEFEND chosen instead) + rally on-cooldown (verify USE_SKILL_score=-100; ATTACK chosen) + 0 adjacent allies + low HP (verify DEFEND_score=30 per F-AI-4 if HP<0.4 wins)

### Lint test specs (Pillar 2 architectural lock 4th precedent + CR-AI-6 + 9-precedent stateless-emit + 5-precedent battle-scoped-static-var — automated)

**AC-AI-9** (Pillar 2 architectural lock 4th precedent — no_destiny_branch_reference lint):
- Given: `tools/ci/lint_ai_system_no_destiny_branch_reference.sh` exists + chmod +x
- When: Script invoked from project root
- Then: Exits 0 (PASS); `grep -E 'hidden_fate_condition_progressed|DestinyBranchChoice|destiny_branch_chosen' src/feature/ai/ai_system.gd` returns 0 matches
- Negative test: Inject `var foo = DestinyBranchChoice.new()` into ai_system.gd → verify lint FAILS with Pillar 2 architectural lock 4th-precedent error message; revert injection
- Pass condition: 3-layer enforcement triad satisfied per Decision F (lint + ADR annotation + integration test via FileAccess source-scan)

**AC-AI-10** (CR-AI-6 — no_direct_state_read lint):
- Given: `tools/ci/lint_ai_system_no_direct_state_read.sh` exists + chmod +x
- When: Script invoked
- Then: Exits 0 PASS; `grep -E "MapGrid\\.|HPStatusController\\.|TurnOrderRunner\\." src/feature/ai/ai_system.gd` returns 0 matches outside the `_grid_battle_controller: GridBattleController` field declaration line (which is the DI'd reference, not a state read)
- Negative test: Inject `var hp = HPStatusController.get_current_hp(unit_id)` into ai_system.gd scoring function → verify lint FAILS with CR-AI-6 violation; revert injection

**AC-LINT-AI-1** (no_gamebus_emit lint):
- Given: `tools/ci/lint_ai_system_no_gamebus_emit.sh` exists + chmod +x
- When: Script invoked
- Then: Exits 0 PASS; `grep -c 'GameBus\..*\.emit' src/feature/ai/ai_system.gd` returns 0
- Negative test: Inject `GameBus.unit_died.emit(unit_id)` into ai_system.gd → verify lint FAILS; revert

**AC-LINT-AI-2** (no_static_var lint):
- Given: `tools/ci/lint_ai_system_no_static_var.sh` exists + chmod +x
- When: Script invoked
- Then: Exits 0 PASS; `grep -E '^static var' src/feature/ai/ai_system.gd` returns 0
- Negative test: Inject `static var _archetype_cache: Dictionary = {}` → verify lint FAILS; revert

### Performance test specs (AC-AI-11 P99 — automated where possible)

**AC-AI-11** (P99 < 200ms):
- Given: 100 randomized BattleStateSnapshot fixtures (varied unit counts, archetypes, terrain complexity within MVP scope)
- When: AISystem.decide() called for each fixture; record per-call wall-clock duration via `Time.get_ticks_usec()` start/end delta
- Then: Sort durations ascending; assert `durations[99] < 200_000` (200ms in microseconds) — P99 within budget
- Edge cases: Worst-case scenario (200 candidates per CR-AI-4 step 2 cap) timing measurement (verify within 200ms even at cap) + Linux Editor + Windows D3D12 lanes only per Decision E (Android device perf deferred to release-prep sprint per CI lane gap)
- Pass condition: P99 < 200ms on reference hardware (Linux Editor + Windows D3D12 CI runners; Android Pixel 7-class manual fallback if available)

### Integration test specs (soft-lock recovery + mount sequence — automated)

**AC-AI-13** (soft-lock recovery):
- Given: AISystem with deliberate fault injection — patch _on_ai_action_requested via test seam to never emit ai_action_ready (block on `await get_tree().create_timer(10000).timeout` simulating frozen AI); GridBattleController instance subscribed per CR-3
- When: GridBattleController emits ai_action_requested for the faulty AI unit
- Then: After 500ms (per AI_DECISION_TIMEOUT_MS BalanceConstants), GridBattleController's CR-3 timeout fires + WAIT substitution occurs (verify via mock action validator) + ai_soft_lock_counter increments by 1; AI unit does NOT crash; subsequent AI units (non-faulty) execute normally
- Edge cases: Faulty AI emits late (after 500ms) — verify GridBattleController's CR-3a discards the late ai_action_ready (already substituted WAIT) + counter still incremented + no double-action
- Pass condition: GridBattleController-side defense is the soft-lock recovery mechanism; this story's AISystem only ensures it does NOT crash + does NOT prevent the timer fallback

**AC-MOUNT-1** (BattleScene step 5.5 mount integration):
- Given: BattleScene._ready() body includes step 5.5 AISystem mount per ADR-0016 §3 R-3 amended via delta #14
- When: BattleScene loaded (via test scene OR `godot --headless --quit-after 1 --main-scene scenes/battle/battle_scene.tscn` smoke run)
- Then: 7 systems mounted in order (1.MapGrid → 2.BattleCamera → 3.HPStatusController → 4.TurnOrderRunner → 5.GridBattleController → 5.5.AISystem → 6.BattleHUD); verify via scene tree node enumeration after _ready() completes; AISystem._ready() completes without crash on `_grid_battle_controller != null` assert (DI'd before add_child); 0 errors / 0 orphans
- Edge cases: Coordinate atomicity with scenario-progression story-001 BattleScene._ready() rewrite per Decision A (verify both this story's AISystem mount AND scenario-progression story-001's mock encoder DELETION present in the same BattleScene._ready() body)

### Configuration test specs (10 BalanceConstants entries — automated)

**AC-BC-1** (10 BalanceConstants entries):
- Given: `assets/data/balance/balance_entities.json` updated with 10 F-AI-Constants entries
- When: `BalanceConstants.get_const(key)` invoked for each of 10 keys
- Then: Returns the expected default value per F-AI-Constants table (e.g., AGGRESSOR_KILL_BONUS=50.0); types match (float for utility weights + int for AI_DECISION_TIMEOUT_MS)
- Edge cases: Missing key returns 0/null (verify; per ADR-0006 lazy-load pattern + key-presence lint enforcement) + tuning override (verify designer can change JSON values without source code change per data-driven balance discipline) + key-presence lint at `tools/ci/` ensures all 10 keys present in balance_entities.json (verify via existing balance-entities key-presence lint pattern from camera epic)

### Manual verification (none — story is fully automated Logic + Integration)

No manual verification required for this story. AC-AI-12 chapter-1 distribution (Visual/Feel ADVISORY) deferred per Out of Scope.

---

## Test Evidence

**Story Type**: Logic + Integration

**Required evidence**:
- **Unit tests** (BLOCKING gate per Logic story-type): `tests/unit/ai/ai_system_test.gd` + `tests/unit/ai/ai_aggressor_test.gd` + `tests/unit/ai/ai_skirmisher_test.gd` + `tests/unit/ai/ai_holder_test.gd` + `tests/unit/ai/ai_coordinator_test.gd` (5 files, ~10-12 test functions total)
- **Integration tests** (BLOCKING gate per Integration story-type): AC-MOUNT-1 BattleScene mount integration + AC-AI-13 soft-lock recovery (may share `tests/integration/ai/ai_system_integration_test.gd`)
- **Performance test** (per AC-AI-11): `tests/performance/ai/ai_decision_p99_test.gd` (Linux Editor + Windows D3D12 lanes only per Decision E)
- **Lint scripts** (BLOCKING gate per ADR-0019 §V-5): 4 lint scripts at `tools/ci/lint_ai_system_*.sh` all exit 0 PASS
- **Verification summary** (epic terminal): `production/qa/evidence/ai_system_verification_summary.md` covering all 15 TR-ai-system-* satisfaction proofs + Pillar 2 architectural lock 4th-precedent enforcement triad
- **Full regression**: target ~960 PASS at sprint-7 close per sprint-7 plan (+10-12 from this story alone)

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**:
  - **scenario-progression story-001** (S7-02 sprint-7 critical path) — ChapterDefinition.enemy_roster archetype field consumer per ADR-0019 §Migration Plan §8 (this story extends the chapter-1 .tres scaffolding from scenario-progression story-001 with archetype assignments per Decision B); also depends on BattleScene._ready() rewrite for AISystem step 5.5 mount insertion atomicity per Decision A
  - **(Indirect via scenario-progression story-001) destiny-branch story-001** (S7-03) — DestinyBranchJudge full impl shipped by S7-03 is NOT a direct dependency for AISystem (Pillar 2 architectural lock 4th precedent enforces zero DestinyBranch references), but the same sprint-7 critical path means S7-03 likely ships before S7-04
- **Unlocks**:
  - **chapter-1 (장판파) end-to-end playable arc** per sprint-7 +1 playable-surface delta target — AISystem responds to GridBattleController per CR-3 protocol; 4-archetype enemy roster pressures player roles asymmetrically per Pillar 3
  - **chapter-prototype graduation from naive single-archetype AI** (battle_v2.gd:596-678 greedy step + nearest target) to Production-grade architecture — design judgment from prototype carries forward but production AI is data-driven per CR-AI-2 archetype assignment
  - **Cross-director gate-check upgrade CONCERNS → PASS** — closes the cross-director convergent blocker per gate-check 2026-05-04 path-to-PASS item #4 (CD Pillar 3 + TD no-ADR + PR no-epic)
  - **chapter-1 ChapterDefinition .tres full content authoring** (S7-05 sprint-7 should-have) — chapter-1 archetype assignments shipped by this story may be extended with full narrative content per scenario-progression story-001 Decision B coordination
  - **Pre-Production → Production gate upgrade** — gate-check 2026-05-04 path-to-PASS item #6 (sprint-7 plan execution); after S7-01..S7-07 close + S7-11 user attestation captured, expect upgrade CONCERNS → PASS + `production/stage.txt` written = "Production"
  - **Sprint-7 Definition of Done item** "AISystem battle-scoped Node 6th invocation mounted + 4 archetypes + 4 lint scripts green + Pillar 2 lock 4th precedent enforced (S7-04)" per sprint-7 plan
