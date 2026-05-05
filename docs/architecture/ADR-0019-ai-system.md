# ADR-0019: AI System (`AISystem` battle-scoped Node + per-archetype utility-scoring dispatch)

## Status
Accepted (2026-05-05 — escalated Proposed → Accepted same-day fresh-session per same-session-ban discipline via `/architecture-review` delta #14 = **4th-precedent same-day-fresh-session escalation pattern** after delta #11/#12/#13. PASS WITH 1 BLOCKING + 1 ADVISORY CORRECTIONS resolved same-patch — ADR-0014 §8 5-LOCAL-signal set vs ADR-0019 6th `ai_action_requested` signal additive amendment to ADR-0014 (5th project precedent of "ratification widening at upstream-ADR acceptance" after save_checkpoint_requested + scenario_complete + scenario_beat_retried + ADR-0017 line 209 instance-form widening) + ai-system.md CR-AI-1 step "6.5" → "5.5" wording reconciliation. Pillar 2 architectural lock pattern stable at **4 invocations** (`ai_system_reads_destiny_branch_state` follows `battle_hud_subscribes_to_hidden_fate_signal` + `scenario_runner_deferred_seal_in_beat_7_entry` + `destiny_branch_judge_reads_scenario_runner_state`). Battle-scoped Node pattern stable at **6 invocations**. Combined-session pattern (escalation + structural append in single fresh session) stable at 4 invocations. Source: `docs/architecture/architecture-review-2026-05-05.md`. GDD shipped 2026-05-04 commit `b9acb98`; ADR-0019 originally Proposed 2026-05-04 commit `6dfd962`.)

## Date
2026-05-04

## Last Verified
2026-05-04 against `docs/engine-reference/godot/VERSION.md` (Godot 4.6, pinned 2026-04-16).

## Decision Makers
Solo dev — autonomous authoring per gate-check directive. ADR ratifies AI System GDD's MVP scope (4 archetypes × utility scoring) into architecture binding suitable for sprint-7+ implementation.

## Summary

Define **AISystem** as a battle-scoped `Node` (6th invocation of battle-scoped Node pattern after HPStatusController + TurnOrderRunner + BattleCamera + GridBattleController + BattleHUD) that subscribes to GridBattleController's `ai_action_requested(unit_id, snapshot)` LOCAL signal, runs per-archetype utility scoring on a `BattleStateSnapshot` Resource, and emits `ai_action_ready(unit_id, command)` LOCAL signal back with a typed `AIActionCommand` Resource. **Single-class match-dispatch** (NOT strategy-class hierarchy) — `_score_candidate(archetype, candidate, snapshot) -> float` body is a `match archetype` statement routing to one of 4 per-archetype scoring functions. Solo-dev MVP scope: 1 source file (~300 LoC), 4 utility functions, 1 `BattleStateSnapshot` Resource, 1 `AIActionCommand` Resource. Mounted in BattleScene `_ready()` mount sequence as **step 5.5** (post-GridBattleController, pre-BattleHUD) — BattleHUD's AI-thinking-indicator subscription requires AISystem present at HUD `_ready()`. Synchronous main-thread execution for MVP; WorkerThreadPool deferral is a post-MVP option per AI System GDD §EC-AI-12. 4 forbidden_patterns proposed: `ai_system_signal_emission_outside_action_ready` + `ai_system_static_var` + `ai_system_reads_destiny_branch_state` (Pillar 2 architectural lock — 4th project precedent of pillar-anchored lint pattern) + `ai_system_direct_battle_state_read` (CR-AI-6 enforcement).

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Feature (battle-scoped subsystem) |
| **Knowledge Risk** | LOW (Godot 4.6 pinned; no post-cutoff APIs required by this ADR) |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/deprecated-apis.md`, `design/gdd/ai-system.md` (CR-AI-1..8, F-AI-1..4, EC-AI-1..12, AC-AI-1..14, OQ-AI-1..5), `design/gdd/grid-battle.md` (CR-3 + CR-3a `ai_action_requested` / `ai_action_ready` signal protocol + 500ms timeout + WAIT-substitution + soft_lock_counter), `design/gdd/turn-order.md` (`unit_turn_started` consumed transitively via Grid Battle), `design/gdd/damage-calc.md` (`DamageCalc.preview()` read-only path), `design/gdd/scenario-progression.md` (`ChapterDefinition` enemy-roster archetype assignment), `docs/architecture/ADR-0014-grid-battle-controller.md` (5 LOCAL signals — AISystem subscribes to 1 + emits 1 LOCAL response), `docs/architecture/ADR-0015-battle-hud.md` (battle-scoped Node 5th invocation precedent + AI-thinking-indicator subscription), `docs/architecture/ADR-0016-battle-scene-wiring.md` (6-step mount sequence — this ADR inserts step 5.5), `docs/architecture/ADR-0017-scenario-progression.md` (ChapterDefinition typed Resource carrying archetype assignments), `docs/architecture/ADR-0018-destiny-branch.md` (Pillar 2 architectural lock pattern + `destiny_branch_judge_reads_scenario_runner_state` 3rd-precedent — this ADR is 4th). |
| **Post-Cutoff APIs Used** | NONE. AISystem uses pre-4.4 stable APIs only: `Node` lifecycle (`_ready` / `_exit_tree`), typed `signal` declarations (4.2+ stable), `match` statements (1.0+), `@export` typed properties on `Resource` (4.0+ stable). The GDD's optional post-MVP `WorkerThreadPool` offload (EC-AI-12) is NOT in scope of this ADR — same-patch deferral. |
| **Verification Required** | (1) `BattleStateSnapshot extends Resource` with 5 typed `@export` fields (units / map_state / queue / hp_table / formation_tags) round-trips through `ResourceSaver.save` / `ResourceLoader.load` for save/load determinism replay (AC-AI-14). (2) `AIActionCommand extends Resource` with `@export var action_type: ActionType` (typed enum) + optional move_target / attack_target / skill_id fields parses + serializes correctly. (3) AISystem `_exit_tree()` disconnects the GridBattleController `ai_action_requested` subscription (battle-scoped Node 6-precedent _exit_tree discipline — mirrors HPStatusController + TurnOrderRunner + BattleCamera + GridBattleController + BattleHUD). (4) Static lint `tools/ci/lint_ai_system_no_destiny_branch_reference.sh` rejects any `hidden_fate_condition_progressed` / `DestinyBranchChoice` / `destiny_branch_chosen` token in `src/feature/ai/*.gd` (Pillar 2 lock 4th precedent). (5) Static lint `tools/ci/lint_ai_system_no_direct_state_read.sh` rejects any `MapGrid.` / `HPStatusController.` / `TurnOrderRunner.` reference in `src/feature/ai/ai_system.gd` outside the snapshot-parameter binding (CR-AI-6). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0014 Grid Battle Controller** (Accepted 2026-05-03 via `/architecture-review` delta #11) — owns `ai_action_requested(unit_id, BattleStateSnapshot)` LOCAL signal emission + `ai_action_ready(unit_id, AIActionCommand)` LOCAL signal consumption + 500ms timeout + WAIT substitution + `ai_soft_lock_counter` escalation. AISystem is a pure responder. **ADR-0017 Scenario Progression** (Accepted 2026-05-04 via delta #12) — `ChapterDefinition` typed Resource carries `enemy_roster: Array[Dictionary]` where each entry has `archetype: StringName` field. **ADR-0011 Turn Order** (Accepted) — `is_player_controlled: bool` flag distinguishes AI units; AI System does not subscribe to turn-order signals directly (consumed transitively via Grid Battle's `ai_action_requested` emission). **ADR-0010 HP/Status** + **ADR-0004 Map/Grid** + **ADR-0012 Damage Calc** + **ADR-0006 Balance/Data** — read-only consumers via `BattleStateSnapshot` (no direct queries). **ADR-0016 Battle Scene Wiring** (Accepted) — 6-step mount sequence; this ADR proposes inserting AISystem as new step 5.5 (post-GridBattleController, pre-BattleHUD). |
| **Enables** | **Chapter-1 (장판파) implementation story** — cannot ship without enemy AI behavior; chapter-prototype's naive AI (battle_v2.gd:596-678 greedy step + nearest target) is single-archetype, NOT MVP-grade. **ScenarioRunner sprint-7+ impl** — ScenarioRunner emits `chapter_started` + GridBattleController's `ai_action_requested` flow requires AISystem to respond. **Sprint-7 sprint plan** (path-to-PASS item #6) — confident AI scheduling depends on this ADR landing. |
| **Blocks** | **ai-system implementation story** (sprint-7+ scope) — cannot open until this ADR Accepted via `/architecture-review`. **chapter-1 enemy roster authoring** — until archetype StringName vocabulary is architecture-locked (CR-AI-3), chapter authors cannot assign enemy archetypes. |
| **Ordering Note** | This ADR is authored after the AI System GDD (2026-05-04, commit `b9acb98`) per project precedent (GDD Designed → ADR Proposed → ADR Accepted; mirrors ADR-0018 sequence). The integration interface `ai_action_requested` / `ai_action_ready` is already locked by grid-battle.md CR-3 + ADR-0014, so this ADR's scope is the **internal architecture** of AISystem — NOT the cross-system signal protocol. |

## Context

### Problem Statement

The AI System (#8 MVP per `design/gdd/systems-index.md`) is the only MVP-tier system flagged as a **cross-director convergent blocker** by the 2026-05-04 gate-check (Creative Director: Pillar 3 cannot be proven without enemy AI that pressures roles asymmetrically; Technical Director: no ADR for the architectural module form; Producer: no epic for sprint planning). Without this ADR, the AI System GDD (2026-05-04 commit `b9acb98`) is a design specification with no architecture binding — sprint-7+ implementation cannot begin.

The GDD already specifies the **decision logic** (4 archetypes × utility scoring × deterministic dispatch). What it does NOT specify is the **module form**:

1. **Class form** — `Node`? `RefCounted`? Static utility? Autoload? Battle-scoped vs persistent?
2. **Archetype dispatch structure** — Strategy-class hierarchy? Single class with `match` dispatch? Per-archetype subclass with `@abstract` test seam (mirrors ADR-0018 `DestinyBranchJudge` pattern)?
3. **Snapshot Resource shape** — what fields, what type discipline, save/load implications?
4. **AIActionCommand Resource shape** — match grid-battle.md CR-3a action vocabulary {MOVE, ATTACK, USE_SKILL, DEFEND, WAIT}.
5. **Mount order** — where in BattleScene's 6-step `_ready()` mount sequence (ADR-0016)?
6. **Threading** — main thread for MVP, or pre-emptively design for `WorkerThreadPool` offload?
7. **Forbidden patterns** — what lint scripts must protect the 4 invariants from CR-AI-5/6/8 + the no-emit discipline?

This ADR closes those 7 questions.

### Constraints

**Technical (engine-pinned per Godot 4.6 reference docs):**

- `Node` is the correct base for a battle-scoped subsystem with signal subscriptions + `_exit_tree` lifetime hooks (matches HPStatusController + TurnOrderRunner + BattleCamera + GridBattleController + BattleHUD precedent). `RefCounted` is wrong (no scene-tree presence → cannot subscribe to GridBattleController's signal via `_ready` / `_exit_tree`).
- `Resource` is the correct base for `BattleStateSnapshot` + `AIActionCommand` (typed `@export` fields + ResourceSaver/Loader compatibility for save/load determinism per AC-AI-14).
- `match` statement is GDScript 1.0+ stable — used for archetype dispatch in `_score_candidate()`. NOT strategy-class hierarchy (would add 5+ source files for solo dev with no coverage benefit; archetype set is closed at MVP per CR-AI-3).
- `AIActionCommand.action_type` enum order MUST be append-only (mirrors `BattleOutcome.Result` discipline from ADR-0014 + ADR-0003 SaveMigrationRegistry contract).
- `WorkerThreadPool` (4.0+ stable) is NOT used by this ADR — same-patch deferral per GDD EC-AI-12. Future amendment (NOT supersession) would add it.
- `static var` is FORBIDDEN in `ai_system.gd` (CR-AI-5 determinism + AC-AI-2 — instance-level state only). CI lint enforces.

**Architecture-registry constraints (read from `docs/registry/architecture.yaml` v12 post-delta-#13):**

- **`battle_hud_subscribes_to_hidden_fate_signal` forbidden_pattern** — Pillar 2 architectural lock 1st precedent. Mirrored at AI System: AI MUST NOT reference `hidden_fate_condition_progressed` / `DestinyBranchChoice` / `destiny_branch_chosen` (CR-AI-8). New forbidden_pattern proposed: `ai_system_reads_destiny_branch_state` (Pillar 2 lock 4th precedent).
- **`destiny_branch_judge_reads_scenario_runner_state` forbidden_pattern** — pattern for executor classes that take a snapshot parameter and MUST NOT reach back to global state. Mirrored at AI System: `ai_system_direct_battle_state_read` (CR-AI-6 enforcement).
- **`scenario_runner_outcome_synthesis` forbidden_pattern** — single-emitter rule for typed payloads. AI System emits ONLY `ai_action_ready(unit_id, AIActionCommand)` LOCAL signal (NOT GameBus). Forbidden_pattern proposed: `ai_system_signal_emission_outside_action_ready` (defense-in-depth lint).
- **`grid_battle_controller_static_state` forbidden_pattern** — battle-scoped Node lifecycle requires instance state only. Mirrored: `ai_system_static_var` (CR-AI-5 + battle-scoped 6th invocation discipline).
- **GameBus single-emitter rule** — AI System adds 0 new GameBus signals (uses GridBattleController's LOCAL signal channel). Defense-in-depth lint via `ai_system_signal_emission_outside_action_ready`.

**Performance budget:**

- `_score_candidate()` is O(1) per call (utility formula = constant-time arithmetic).
- Candidate enumeration: O(reachable_tiles × attack_targets) bounded by MapGrid (typical: ~30 tiles × ~4 targets = ~120 candidates; cap at 200 per CR-AI-4 step 2).
- Total decision time: 200 candidates × ~0.5ms = ~100ms typical, P99 < 200ms target on mid-tier Android (AC-AI-11). Well within the 500ms timeout (grid-battle.md CR-3).
- `BattleStateSnapshot` allocation: one Resource instance per AI turn = ~5 allocations/round (4 enemies + 1 spare) × 5-7 rounds/battle ≈ ~30 allocations/battle. Negligible.
- `AIActionCommand` allocation: one per AI turn = same churn. Negligible.

**Compatibility requirements:**

- `BattleStateSnapshot` round-trips through `ResourceSaver`/`ResourceLoader` on all 5 export targets (Linux Editor + Windows D3D12 + macOS Metal + iOS Metal + Android Vulkan) per AC-AI-14 save/load determinism contract. Field types restricted to `Array[Dictionary]` / `Array[int]` / `Vector2i` / `int` / `float` (no nested `Resource` references that would require deep-duplication).
- `AIActionCommand` round-trips for replay/debug serialization. Same field discipline.

### Requirements

- **Must subscribe** to GridBattleController `ai_action_requested(unit_id: int, snapshot: BattleStateSnapshot)` LOCAL signal at AISystem `_ready()` per ADR-0014 §8 LOCAL signal contract.
- **Must emit** `ai_action_ready(unit_id: int, command: AIActionCommand)` LOCAL signal back to GridBattleController per grid-battle.md CR-3 protocol.
- **Must NOT emit** any GameBus signal (defense-in-depth: `ai_system_signal_emission_outside_action_ready` lint enforces).
- **Must dispatch** decision logic via `match archetype: StringName` statement on the 4 archetype tags from CR-AI-3 vocabulary.
- **Must enforce** the 4 forbidden_patterns proposed in this ADR via CI lint scripts.
- **Must mount** as BattleScene `_ready()` mount-sequence step 5.5 (post-GridBattleController, pre-BattleHUD) — coordinated with ADR-0016 update (Migration Plan §1).
- **Must disconnect** GridBattleController subscription in `_exit_tree()` (battle-scoped 6th invocation discipline).
- **Must round-trip** `BattleStateSnapshot` + `AIActionCommand` through ResourceSaver/Loader per save/load determinism (AC-AI-14).
- **Must remain** main-thread synchronous for MVP. Post-MVP `WorkerThreadPool` offload deferred to future amendment (NOT supersession).
- **Must validate** archetype StringName at chapter-load (caller responsibility; AISystem fallback per EC-AI-4).

## Decision

Define **AISystem** as `class_name AISystem extends Node` (battle-scoped, 6th invocation of battle-scoped Node pattern). **Single source file** (`src/feature/ai/ai_system.gd`, target ~300 LoC). **No subclass hierarchy** for archetypes — `match` statement dispatch in `_score_candidate(archetype: StringName, candidate: AICandidateAction, snapshot: BattleStateSnapshot) -> float`. **`BattleStateSnapshot` and `AIActionCommand` are typed `Resource` classes** with `@export` fields (per ADR-0001 cross-scene serialization contract). **Mount order**: BattleScene `_ready()` mount-sequence step 5.5 (between GridBattleController step 5 and BattleHUD step 6 — coordinated with ADR-0016 Migration Plan §1). **Subscriptions**: 1 LOCAL signal connection (`grid_battle_controller.ai_action_requested.connect(_on_ai_action_requested)` with `CONNECT_DEFERRED`). **Emissions**: 1 LOCAL signal (`ai_action_ready` declared on AISystem class itself; GridBattleController subscribes via DI'd reference). **Threading**: main thread synchronous for MVP. **State**: instance vars only (no `static var`); no cross-battle state.

### Class Form: `AISystem extends Node` (battle-scoped, 6th invocation)

`Node` is the base. Justifications:

- **Lifecycle hooks needed** (`_ready` to subscribe; `_exit_tree` to disconnect) — `RefCounted` has neither.
- **Scene-tree presence required** for BattleScene to mount via `add_child()` per ADR-0016 6-step sequence.
- **Battle-scoped lifecycle** matches the data: archetype assignments are chapter-scoped; no cross-battle state needed.
- **Mirrors HPStatusController + TurnOrderRunner + BattleCamera + GridBattleController + BattleHUD** — 5 prior battle-scoped Nodes; AISystem is 6th invocation. Pattern stable.

NOT chosen:
- `Autoload` (rejected per Alternative §1) — would persist across battles; archetype assignments would leak between chapters; AC-AI-5 determinism would require explicit reset every chapter-load (vs auto-reset via fresh `.new()` per battle).
- `RefCounted` pure-function class (rejected per Alternative §2) — no scene-tree presence → cannot subscribe to LOCAL signals via `_ready`/`_exit_tree` lifecycle.
- Static utility module (rejected per Alternative §3) — same scene-tree issue + would require `static var` for any per-battle state.

### Archetype Dispatch: Single class with `match` statement (NOT subclass hierarchy)

```gdscript
# src/feature/ai/ai_system.gd

class_name AISystem extends Node

signal ai_action_ready(unit_id: int, command: AIActionCommand)

# DI: GridBattleController set by BattleScene before add_child()
var _grid_battle_controller: GridBattleController = null

func setup(controller: GridBattleController) -> void:
    _grid_battle_controller = controller

func _ready() -> void:
    assert(_grid_battle_controller != null, "AISystem: setup() must be called before add_child()")
    var err: int = _grid_battle_controller.ai_action_requested.connect(
        _on_ai_action_requested, CONNECT_DEFERRED
    )
    assert(err == OK)

func _exit_tree() -> void:
    if _grid_battle_controller != null and _grid_battle_controller.ai_action_requested.is_connected(_on_ai_action_requested):
        _grid_battle_controller.ai_action_requested.disconnect(_on_ai_action_requested)

func _on_ai_action_requested(unit_id: int, snapshot: BattleStateSnapshot) -> void:
    var unit: Dictionary = snapshot.get_unit(unit_id)
    var archetype: StringName = unit.get("archetype", &"aggressor")
    var candidates: Array = _enumerate_candidates(unit, snapshot)
    if candidates.is_empty():
        push_warning("AI_ZERO_CANDIDATES: unit=%d archetype=%s — submitting WAIT" % [unit_id, archetype])
        ai_action_ready.emit(unit_id, AIActionCommand.wait(unit_id))
        return
    var scored: Array = []
    for cand in candidates:
        var score: float = _score_candidate(archetype, cand, snapshot, unit)
        scored.append({"score": score, "cand": cand, "tie_keys": _tie_break_keys(cand)})
    scored.sort_custom(_descending_then_tie_break)
    var best: Dictionary = scored[0]
    if best["score"] <= -100.0:  # all suicidal — submit WAIT (EC-AI-2)
        ai_action_ready.emit(unit_id, AIActionCommand.wait(unit_id))
        return
    ai_action_ready.emit(unit_id, _materialize_command(unit_id, best["cand"]))

func _score_candidate(archetype: StringName, cand: AICandidateAction, snapshot: BattleStateSnapshot, unit: Dictionary) -> float:
    match archetype:
        &"aggressor": return _score_aggressor(cand, snapshot, unit)
        &"skirmisher": return _score_skirmisher(cand, snapshot, unit)
        &"holder": return _score_holder(cand, snapshot, unit)
        &"coordinator": return _score_coordinator(cand, snapshot, unit)
        _:
            push_warning("AI_UNKNOWN_ARCHETYPE: %s — falling back to aggressor" % archetype)
            return _score_aggressor(cand, snapshot, unit)

# 4 per-archetype scoring functions per AI System GDD §F-AI-1..4.
# Each is a pure function over (candidate, snapshot, unit) — no class-level state read.
```

Justifications for single-class match-dispatch over subclass hierarchy:

- **Solo dev productivity** — 1 file vs 5 (1 base + 4 subclasses + 1 factory). Adding/tuning an archetype = 1 function edit.
- **Test discoverability** — all 4 utility functions live next to each other; cross-archetype edge cases visible in one read.
- **No `@abstract` test seam needed** — DamageCalc.preview() is the only mockable boundary; AI's scoring functions take pure data and don't need stubs.
- **Closed archetype set** at MVP (CR-AI-3) — extensibility benefit of subclasses unrealized; YAGNI applies.

If post-MVP a 5th+ archetype is added AND the scoring functions diverge dramatically AND test stubbing becomes complex, an amendment to this ADR could refactor to subclass hierarchy with `@abstract func _score_candidate` test seam (mirrors ADR-0018 DestinyBranchJudge pattern). MVP path: keep simple.

### Payload Form: `BattleStateSnapshot` + `AIActionCommand` typed Resources

```gdscript
# src/core/payloads/battle_state_snapshot.gd

class_name BattleStateSnapshot extends Resource

@export var units: Array[Dictionary] = []  # one entry per unit; archetype + position + hp + ...
@export var map_dimensions: Vector2i = Vector2i.ZERO
@export var terrain_grid: PackedInt32Array = PackedInt32Array()
@export var queue_unit_ids: Array[int] = []  # turn-order queue snapshot
@export var round_number: int = 0
@export var chokepoints: Array[Vector2i] = []  # from ChapterDefinition; empty if none
@export var formation_center: Vector2i = Vector2i.ZERO  # centroid of allied units

func get_unit(unit_id: int) -> Dictionary:
    for u in units:
        if int(u.get("id", -1)) == unit_id: return u
    return {}

# Constructed by GridBattleController._make_battle_state_snapshot() before emitting ai_action_requested.
```

```gdscript
# src/core/payloads/ai_action_command.gd

class_name AIActionCommand extends Resource

enum ActionType { WAIT = 0, MOVE = 1, ATTACK = 2, MOVE_AND_ATTACK = 3, DEFEND = 4, USE_SKILL = 5 }

@export var unit_id: int = -1
@export var action_type: ActionType = ActionType.WAIT
@export var move_target: Vector2i = Vector2i.ZERO  # used iff action_type in [MOVE, MOVE_AND_ATTACK]
@export var attack_target_unit_id: int = -1  # used iff action_type in [ATTACK, MOVE_AND_ATTACK]
@export var skill_id: StringName = &""  # used iff action_type == USE_SKILL

static func wait(unit_id: int) -> AIActionCommand:
    var cmd: AIActionCommand = AIActionCommand.new()
    cmd.unit_id = unit_id
    cmd.action_type = ActionType.WAIT
    return cmd

# 4 more static factories: move, attack, move_and_attack, defend, use_skill.
```

`BattleStateSnapshot` field discipline: NO nested `Resource` references — flat data only (Dictionary / int / Vector2i / packed arrays). This avoids `duplicate_deep` / shared-instance hazards and makes ResourceSaver/Loader round-trip trivial.

`AIActionCommand.ActionType` enum is **append-only** per ADR-0003 SaveMigrationRegistry contract. Reordering values requires migration registry entry + `schema_version` bump — same discipline as `BattleOutcome.Result`.

### Mount Order: BattleScene step 5.5 (between GridBattleController and BattleHUD)

ADR-0016's 6-step mount sequence becomes 7 steps:

```
1. MapGrid
2. BattleCamera
3. HPStatusController
4. TurnOrderRunner
5. GridBattleController
5.5. AISystem  ← NEW per ADR-0019
6. BattleHUD
```

Renumber rationale (Migration Plan §1 in this ADR):
- AISystem MUST mount AFTER GridBattleController (step 5) — its `setup()` requires the controller reference for signal subscription.
- AISystem MUST mount BEFORE BattleHUD (step 6) — BattleHUD's "AI thinking" indicator (UI-GB-N to be added by battle-hud GDD revision) connects to AISystem's `ai_action_ready` signal at HUD `_ready()`. If AISystem is not present at HUD `_ready()`, the connection fails.
- Numbering as "5.5" preserves the 1-6 historical contract for ADRs 0016 documentation; alternative is to renumber 1-7 (cleaner) — DEFERRED to /architecture-review delta.

### Determinism Contract

Per CR-AI-5 + AC-AI-2:
- No `randf()` / `randi()` / `Time.get_ticks_msec()` / wall-clock reads in scoring functions.
- No `static var` (forbidden_pattern enforces).
- No instance-var state mutation between calls (scoring functions take their inputs as parameters; no caching of prior results).
- Tie-break cascade: `(score DESC, target_unit_id ASC, target_coord.y ASC, target_coord.x ASC)` — always produces unique winner since unit_ids are unique (CR-AI-4 step 4).
- Identical `BattleStateSnapshot` + identical `unit_id` + identical archetype assignment → field-identical `AIActionCommand` output.

Save/load replay (AC-AI-14) is structurally guaranteed by this contract. A saved battle reloaded mid-AI-turn produces the same action because the AI's only inputs are the snapshot Resource + immutable archetype assignment.

### Threading: Main Thread Synchronous (MVP)

`_on_ai_action_requested` runs on the main thread. Decision time budget: P99 < 200ms (AC-AI-11) within 500ms timeout. No `WorkerThreadPool` use for MVP.

If P99 exceeds 200ms on reference Android hardware (Pixel 7-class Adreno 610) per profiling, future amendment (NOT supersession) refactors `_on_ai_action_requested` to `WorkerThreadPool.add_task(_score_threaded, snapshot)` + main-thread emit on `task_completed`. The determinism contract (no shared state) makes this trivially thread-safe — but adds task-scheduling overhead that may not be worth it at MVP scale.

### Forbidden Patterns Proposed (4 net-new for /architecture-review delta)

1. **`ai_system_signal_emission_outside_action_ready`** — `src/feature/ai/ai_system.gd` MUST NOT emit any GameBus signal (`grep -c 'GameBus\..*\.emit' src/feature/ai/ai_system.gd` returns 0). Defense-in-depth against accidental cross-domain emission. Mirrors `damage_calc_signal_emission` + `unit_role_signal_emission` 5-precedent stateless-emit lint pattern.

2. **`ai_system_static_var`** — `src/feature/ai/ai_system.gd` MUST NOT declare any `static var` (`grep -E '^static var' src/feature/ai/ai_system.gd` returns 0). Battle-scoped lifecycle requires instance state only. Mirrors `grid_battle_controller_static_state` + `hp_status_static_var_state_addition` + `turn_order_static_var_state_addition` + `destiny_branch_judge_static_var` 4-precedent battle-scoped + RefCounted lint pattern.

3. **`ai_system_reads_destiny_branch_state`** — `src/feature/ai/ai_system.gd` MUST NOT contain any `hidden_fate_condition_progressed` / `DestinyBranchChoice` / `destiny_branch_chosen` token (`grep -E 'hidden_fate_condition_progressed|DestinyBranchChoice|destiny_branch_chosen' src/feature/ai/*.gd` returns 0). **Pillar 2 architectural lock — 4th project precedent of pillar-anchored lint pattern** after `battle_hud_subscribes_to_hidden_fate_signal` + `scenario_runner_deferred_seal_in_beat_7_entry` + `destiny_branch_judge_reads_scenario_runner_state`.

4. **`ai_system_direct_battle_state_read`** — `src/feature/ai/ai_system.gd` MUST NOT reference `MapGrid.` / `HPStatusController.` / `TurnOrderRunner.` outside the `BattleStateSnapshot` parameter binding (`grep -E 'MapGrid\.|HPStatusController\.|TurnOrderRunner\.' src/feature/ai/ai_system.gd` returns 0 outside DI binding lines). CR-AI-6 enforcement. Mirrors `destiny_branch_judge_reads_scenario_runner_state` 1-precedent pure-function-takes-snapshot pattern.

## Alternatives Considered

### Alternative 1: AISystem as `Autoload` Node (`/root/AISystem`)

**Rejected.** Persisting across battles would leak archetype assignments + per-battle state between chapters. Determinism replay (AC-AI-14) would require explicit `_reset()` call at chapter-load (mirrors ADR-0006 BalanceConstants `static var` reset hazard). Battle-scoped form auto-resets via fresh `.new()` per battle. No cross-battle data needs to persist.

### Alternative 2: AISystem as `RefCounted` pure-function class (mirrors ADR-0018 DestinyBranchJudge pattern)

**Rejected.** No scene-tree presence → cannot subscribe to LOCAL signals via `_ready()` / `_exit_tree()` lifecycle. Would require either GridBattleController constructing a fresh AISystem per `ai_action_requested` (no observable benefit over per-call function execution) OR storing AISystem reference somewhere with manual lifecycle management (defeats RefCounted purpose). DestinyBranchJudge works as RefCounted because it's invoked synchronously at one moment per chapter and discarded; AISystem is invoked many times per battle and needs persistent subscription.

### Alternative 3: Static utility module (`AISystem.score(unit, snapshot) -> AIActionCommand`)

**Rejected.** Would require either (a) per-`ai_action_requested` instantiation via static call from GridBattleController (couples controller to AI logic; defeats DI separation) OR (b) static class-level state for archetype configuration (forbidden per CR-AI-5 determinism). Static modules work for stateless calculators (DamageCalc / UnitRole / HeroDatabase / BalanceConstants) but AI is LISTENING for signals — calculator pattern is the wrong shape.

### Alternative 4: Strategy-class hierarchy (1 base AISystem + 4 subclasses per archetype)

**Rejected for MVP, deferred to post-MVP if vocabulary grows.** Would add 5 source files for solo dev with no coverage benefit at the closed 4-archetype MVP set. `match` dispatch on StringName archetype is simpler, faster to iterate, and equally testable. If post-MVP archetype count exceeds ~6 OR scoring functions diverge dramatically (e.g., one archetype uses look-ahead while others don't), an amendment to this ADR refactors to subclass hierarchy with `@abstract func _score_candidate` test seam.

### Alternative 5: Behavior tree (BehaviorTreeRoot + composite/leaf nodes)

**Rejected.** Behavior trees suit emergent multi-step plans with state (e.g., "patrol path → see player → chase → flank"). MVP AI is single-action-per-turn (one MOVE + one ATTACK or DEFEND or WAIT) with no intra-turn planning. Behavior tree machinery (composites / decorators / blackboards) adds complexity for zero MVP benefit. systems-index.md #8 risk mitigation explicitly says "규칙 기반 AI부터 시작" (start with rule-based AI). Behavior trees are a post-Alpha consideration if AI feels too predictable.

### Alternative 6: Goal-Oriented Action Planning (GOAP) / Min-Max / MCTS

**Rejected as out of MVP scope.** All three add 3-5× implementation complexity for an MVP where the bottleneck is **archetype variety** (Pillar 3) NOT **AI cleverness** (anti-Pillar: NOT 밸런스 붕괴 허용 — too-clever AI defeats the player consistently). Solo dev cannot validate the player-fantasy of "the enemy reads the same battle I do" with stronger AI; a too-strong AI feels arbitrary, not aware. Rule-based + utility + per-archetype-tuning is the right complexity tier for solo-dev MVP.

## Consequences

### Positive

- **Pillar 3 (모든 무장에게 자리가 있다) becomes provable** at chapter-1 implementation. Different player party compositions face the same enemy roster but get pressured asymmetrically by 4 archetypes. Without this ADR, Pillar 3 is theoretical.
- **Cross-director gate-check blocker closes** (CD + TD + PR convergent). Sprint-7 plan can confidently include AI implementation (with this ADR Accepted) OR defer to sprint-8 (with this ADR Proposed-only as blocking gate).
- **chapter-prototype's naive AI graduates to Production-grade architecture** — chapter-prototype/battle_v2.gd:596-678 (single archetype, greedy step) becomes one of 4 archetypes with utility scoring. Design judgment from prototype carries forward.
- **Pillar 2 isolation 4th-precedent codification** — `ai_system_reads_destiny_branch_state` extends the pillar-anchored lint pattern from 3 (BattleHUD + ScenarioRunner + DestinyBranchJudge) to 4 occurrences. Pattern stable as project discipline.
- **Determinism contract enables replay testing** — AC-AI-14 save/load determinism is structurally guaranteed by no-static-var + no-randf design. Saves restored mid-AI-turn produce same actions.
- **6th invocation of battle-scoped Node pattern** — pattern is stable; mount sequence becomes 7 steps (was 6). Future scene-root-as-orchestrator additions (Battle Preparation / Story Event scenes) inherit the discipline cleanly.

### Negative

- **Mount sequence renumbering** — ADR-0016 6-step becomes 7-step with AISystem at step 5.5 (or full 1-7 renumber per /architecture-review delta decision). Cross-doc update touches ADR-0016 + battle-scene-wiring tests.
- **2 new typed Resources to maintain** — `BattleStateSnapshot` + `AIActionCommand` add ~50 LoC of payload-class boilerplate. ResourceSaver/Loader tests required for both.
- **Single-class match-dispatch limits archetype variety** at MVP — adding a 5th archetype is one `match` arm + one scoring function; adding the 6th and beyond may strain the file. Refactor threshold at post-MVP per Alternative 4.
- **No `@abstract` test seam** — scoring functions take pure-data parameters and aren't stubbable in the DamageCalc.preview() sense. Tests use synthetic `BattleStateSnapshot` fixtures (manageable; ~20 fixture files target).

### Neutral

- **AI quality is not engineered** by this ADR — it is **tuned** via the 10 constants in F-AI table. ADR specifies the architecture; tuning workflow per GDD §Tuning Knobs delivers the player-fantasy quality.
- **Threading deferral** — main-thread MVP is intentional. If profiling shows pain on reference hardware, future amendment refactors. Premature WorkerThreadPool optimization is not in this ADR's scope.

## Risks

- **R-1 (LOW)**: archetype scoring constants poorly tuned → chapter-1 ending distribution drifts away from gate target (25-40% REWRITTEN). **Mitigation**: AC-AI-12 chapter-1 distribution test runs 100 simulations; tuning workflow per GDD §Tuning Knobs catches drift before ship.
- **R-2 (LOW)**: P99 decision time exceeds 200ms on low-end Android → 500ms timeout fires too often → soft-lock counter escalates → battle softlocks. **Mitigation**: AC-AI-11 perf test on reference Android; if P99 > 200ms, defer to WorkerThreadPool via amendment (no breaking change).
- **R-3 (MEDIUM)**: BattleStateSnapshot Resource shape changes during impl → save/load determinism breaks → AC-AI-14 fails. **Mitigation**: snapshot field types restricted to flat data (no nested Resources); SaveMigrationRegistry per ADR-0003 covers schema evolution.
- **R-4 (LOW)**: `ai_system_reads_destiny_branch_state` Pillar 2 lock false positive on innocent grep matches (e.g., a comment mentioning "destiny branch" for context). **Mitigation**: lint script uses precise grep patterns (`grep -E 'hidden_fate_condition_progressed|DestinyBranchChoice|destiny_branch_chosen'`) targeting the 3 specific tokens; comment-only mentions allowed via line-prefix check (`grep -v '^#'` modification).
- **R-5 (LOW)**: AISystem mounted at step 5.5 breaks ADR-0016's `lint_battle_scene_pre_instanced_children.sh` (asserts EXACTLY 3 nodes pre-instanced via .tscn). **Mitigation**: AISystem is code-instantiated in `_ready()` mount sequence — does NOT add to .tscn pre-instanced count. Lint passes.

## Performance Implications

- AISystem `_ready()` cost: 1 signal connect + 1 assert ≈ <0.1 ms.
- AISystem `_exit_tree()` cost: 1 signal disconnect ≈ <0.1 ms.
- Per `ai_action_requested` decision: P99 < 200ms target on mid-tier Android (AC-AI-11).
- Per battle: ~5-7 rounds × ~4 enemies × ~100ms typical = ~2-3 seconds total AI compute time (out of ~5-15 minute battle wall-clock).
- Memory: instance vars only; no static caching; ~100B per AISystem instance + ~200B per `BattleStateSnapshot` instance (transient, garbage-collected per call).
- Frame impact: AI runs synchronously between turn boundaries — does NOT consume the 16.6ms gameplay frame budget. Long AI think (>500ms) is a soft-lock, not a frame drop.

## Migration Plan

1. **ADR-0016 update**: insert step 5.5 "Mount AISystem" between current steps 5 (GridBattleController) and 6 (BattleHUD). Same-patch with this ADR's Acceptance via /architecture-review delta. Alternative: full renumber 1-7 (cleaner) — defer decision to /architecture-review.
2. **3 new source files** at sprint-7+ implementation patch:
   - `src/feature/ai/ai_system.gd` (~300 LoC) — AISystem class with 4 archetype scoring functions
   - `src/core/payloads/battle_state_snapshot.gd` (~30 LoC) — BattleStateSnapshot Resource
   - `src/core/payloads/ai_action_command.gd` (~50 LoC) — AIActionCommand Resource + 6 static factories
3. **2 test helper files** at sprint-7+:
   - `tests/helpers/battle_state_snapshot_factory.gd` (~50 LoC) — synthetic snapshot construction for unit tests
   - `tests/helpers/ai_action_command_assertions.gd` (~30 LoC) — typed action_command equality helpers
4. **5 unit + integration test files** at sprint-7+:
   - `tests/unit/ai/ai_system_test.gd` (~200 LoC) — AC-AI-1..3 + AC-AI-13
   - `tests/unit/ai/ai_aggressor_test.gd` (~100 LoC) — AC-AI-4
   - `tests/unit/ai/ai_skirmisher_test.gd` (~100 LoC) — AC-AI-5
   - `tests/unit/ai/ai_holder_test.gd` (~80 LoC) — AC-AI-6
   - `tests/unit/ai/ai_coordinator_test.gd` (~120 LoC) — AC-AI-7 + AC-AI-8
   - `tests/integration/ai/ai_chapter_1_distribution_test.gd` (~150 LoC) — AC-AI-12 (deferred until ScenarioRunner ships)
   - `tests/integration/ai/ai_save_load_determinism_test.gd` (~100 LoC) — AC-AI-14 (deferred until Save/Load #17 GDD)
5. **4 new CI lint scripts** at sprint-7+:
   - `tools/ci/lint_ai_system_no_gamebus_emit.sh` — forbidden_pattern #1
   - `tools/ci/lint_ai_system_no_static_var.sh` — forbidden_pattern #2
   - `tools/ci/lint_ai_system_no_destiny_branch_reference.sh` — forbidden_pattern #3 (Pillar 2)
   - `tools/ci/lint_ai_system_no_direct_state_read.sh` — forbidden_pattern #4
6. **GridBattleController extension** (sprint-7+ pre-implementation): add `_make_battle_state_snapshot() -> BattleStateSnapshot` private method that constructs the snapshot from MapGrid + HPStatusController + TurnOrderRunner queries. Called once at `ai_action_requested` emission.
7. **BattleHUD extension** (sprint-7+): UI-GB-N "AI thinking" indicator subscribes to AISystem.ai_action_ready (visible iff not received within 100ms after ai_action_requested). Same-patch with battle-hud GDD revision.
8. **ChapterDefinition extension** (sprint-7+): `enemy_roster: Array[Dictionary]` entries gain `archetype: StringName` field. ScenarioRunner validates archetype on chapter-load. chapter-1 (장판파) data: 하후돈=`&"aggressor"`, 장요=`&"skirmisher"`, 우금=`&"holder"`, 허저=`&"coordinator"` (boss).
9. **Architecture registry update** at /architecture-review delta: 1 net-new state_ownership (`ai_system_runtime_state`) + 1 net-new interface (`ai_action_signal_contract` — LOCAL signal, not GameBus) + 1 net-new api_decision (`ai_system_module_form` with 6 alternatives) + 4 net-new forbidden_patterns (above).
10. **TR registry update**: ~10-12 net-new TR-ai-system-001..N entries appended to tr-registry.yaml.
11. **Architecture traceability update**: AISystem row added; mount-sequence diagram updated.

All migration items above are sprint-7+ scope (deferred from this ADR's authoring). This ADR's Acceptance unlocks them.

## Validation Criteria

- **V-1**: AISystem `_ready()` asserts `_grid_battle_controller != null` (DI null-check) — fail-loud if BattleScene mount sequence skips `setup()`.
- **V-2**: AISystem `_exit_tree()` disconnects all signal subscriptions (battle-scoped 6th invocation `_exit_tree` discipline). Lint via `grep -E 'is_connected.*disconnect' src/feature/ai/ai_system.gd` returns ≥1 match within `_exit_tree` body.
- **V-3**: `BattleStateSnapshot` round-trips through `ResourceSaver.save()` → `ResourceLoader.load()` with field-identical content on all 5 export targets (Linux Editor + Windows D3D12 + macOS Metal + iOS Metal + Android Vulkan). Test: `tests/unit/ai/battle_state_snapshot_serialization_test.gd`.
- **V-4**: `AIActionCommand` round-trips on all 5 export targets with `ActionType` enum integer-value preservation. Test: `tests/unit/ai/ai_action_command_serialization_test.gd`.
- **V-5**: 4 lint scripts (per Migration Plan §5) green on initial implementation patch.
- **V-6**: AC-AI-1 signal protocol compliance — fresh battle with 4 enemies; all 4 emit `ai_action_ready` within 500ms.
- **V-7**: AC-AI-2 determinism — 100 invocations of each archetype with cloned snapshots return field-identical commands.
- **V-8**: AC-AI-3 archetype differentiation — 4 different archetype assignments to same unit produce different commands in ≥50% of synthetic scenarios.
- **V-9**: AC-AI-11 P99 < 200ms on reference Android.
- **V-10**: AC-AI-12 chapter-1 distribution within target range (deferred until ScenarioRunner + chapter-1 ship).
- **V-11**: AC-AI-13 soft-lock recovery — fault-injected AI never returning triggers GridBattleController CR-3 timeout + WAIT substitution + counter increment.
- **V-12**: Mount sequence integration — BattleScene `_ready()` mounts 7 systems in order; AISystem mounted at step 5.5 (or step 6 in renumbered scheme); BattleHUD's AI-thinking-indicator subscription succeeds at HUD `_ready()`.

## GDD Requirements Addressed

| TR | Requirement | Source |
|---|---|---|
| TR-ai-system-001 | AISystem class form: `extends Node` (battle-scoped, 6th invocation) | this ADR §Decision §Class Form |
| TR-ai-system-002 | Single-source-file with `match` dispatch on archetype StringName (NOT subclass hierarchy) | this ADR §Decision §Archetype Dispatch |
| TR-ai-system-003 | `BattleStateSnapshot extends Resource` typed payload (flat data — no nested Resources) | this ADR §Decision §Payload Form |
| TR-ai-system-004 | `AIActionCommand extends Resource` typed payload + 6 static factories + ActionType enum append-only | this ADR §Decision §Payload Form |
| TR-ai-system-005 | Mount order: BattleScene `_ready()` step 5.5 (post-GridBattleController, pre-BattleHUD) | this ADR §Decision §Mount Order + Migration Plan §1 |
| TR-ai-system-006 | LOCAL signal subscription to GridBattleController.ai_action_requested with CONNECT_DEFERRED | this ADR §Decision §Decision body + GDD CR-AI-1 |
| TR-ai-system-007 | LOCAL signal emission `ai_action_ready` declared on AISystem class (not GameBus) | this ADR §Decision §Decision body + grid-battle.md CR-3 |
| TR-ai-system-008 | `_exit_tree()` disconnects subscription (battle-scoped 6th invocation discipline) | this ADR §Decision + V-2 |
| TR-ai-system-009 | Determinism contract: no static var + no randf + no Time.get_ticks_msec + no instance-var caching across calls | this ADR §Decision §Determinism Contract + GDD CR-AI-5 |
| TR-ai-system-010 | Main-thread synchronous execution for MVP; WorkerThreadPool deferred to post-MVP amendment | this ADR §Decision §Threading + GDD EC-AI-12 |
| TR-ai-system-011 | Forbidden pattern: ai_system_signal_emission_outside_action_ready | this ADR §Forbidden Patterns Proposed |
| TR-ai-system-012 | Forbidden pattern: ai_system_static_var | this ADR §Forbidden Patterns Proposed |
| TR-ai-system-013 | Forbidden pattern: ai_system_reads_destiny_branch_state (Pillar 2 lock 4th precedent) | this ADR §Forbidden Patterns Proposed |
| TR-ai-system-014 | Forbidden pattern: ai_system_direct_battle_state_read | this ADR §Forbidden Patterns Proposed |
| TR-ai-system-015 | DI null-check assert in `_ready()` (GridBattleController reference required pre-add_child) | this ADR §Decision body + V-1 |

## Related

- `design/gdd/ai-system.md` — the GDD this ADR ratifies (CR-AI-1..8, F-AI-1..4, EC-AI-1..12, AC-AI-1..14, OQ-AI-1..5)
- `design/gdd/grid-battle.md` CR-3 + CR-3a — `ai_action_requested` / `ai_action_ready` signal protocol locked here
- `design/gdd/game-concept.md` §Pillar 3 — "모든 무장에게 자리가 있다" (the player-fantasy this ADR's architecture serves)
- `design/gdd/scenario-progression.md` — `ChapterDefinition.enemy_roster` carries archetype assignments (sprint-7+ pre-impl extension per Migration Plan §8)
- `docs/architecture/ADR-0014-grid-battle-controller.md` — battle-scoped Node 4th invocation precedent + LOCAL signal pattern this ADR mirrors
- `docs/architecture/ADR-0015-battle-hud.md` — battle-scoped Node 5th invocation precedent + AI-thinking-indicator subscription target
- `docs/architecture/ADR-0016-battle-scene-wiring.md` — 6-step mount sequence becomes 7 steps per Migration Plan §1
- `docs/architecture/ADR-0017-scenario-progression.md` — ChapterDefinition typed Resource carrying archetype assignments
- `docs/architecture/ADR-0018-destiny-branch.md` — Pillar 2 architectural lock 3-precedent pattern (this ADR is 4th invocation) + `destiny_branch_judge_reads_scenario_runner_state` precedent for `ai_system_direct_battle_state_read`
- `prototypes/chapter-prototype/battle_v2.gd:596-678` — naive single-archetype prototype AI; design reference for Aggressor archetype but NOT migrated directly per prototype-code rules
- `production/gate-checks/pre-prod-to-prod-2026-05-04.md` — gate-check that requested this ADR (path-to-PASS item #4)
- `docs/registry/architecture.yaml` v12 — to be updated to v13 at /architecture-review delta with this ADR's 4 forbidden_patterns + 1 state_ownership + 1 interface + 1 api_decision

## Changelog

| Date | Change |
|------|--------|
| 2026-05-04 | Initial draft. Status: Proposed. AI System architecture decision codifying the AI System GDD's MVP scope (4 archetypes × utility scoring × deterministic dispatch) into module form (battle-scoped Node 6th invocation + single-class match-dispatch + 2 typed Resources + 4 forbidden_patterns). Authored fresh-session per `/gate-check pre-production` 2026-05-04 path-to-PASS item #4 ADR completion. Ready for fresh-session `/architecture-review` for Accepted escalation per same-session-ban discipline. |
| 2026-05-05 | Status flipped Proposed → Accepted via `/architecture-review` delta #14 (sprint-7 S7-01 — 4th-precedent same-day-fresh-session escalation pattern after delta #11/#12/#13). PASS WITH 1 BLOCKING + 1 ADVISORY CORRECTIONS resolved same-patch: (1) BLOCKING — ADR-0014 §8 ratified only 5 LOCAL signals (per ADR-0015 BattleHUD delta #10) but ADR-0019 §Decision body assumed 6th `ai_action_requested(unit_id: int, snapshot: BattleStateSnapshot)` signal on GridBattleController; resolved via same-patch additive amendment to ADR-0014 §8 + R-1 (5 → 6 signals) + Enables block + §9 architecture diagram + 2 architecture.yaml entry updates (`battle_runtime_state` interface field + `grid_battle_controller_signal_emission_outside_battle_domain` forbidden_pattern description); 5th project precedent of "ratification widening at upstream-ADR acceptance" after save_checkpoint_requested 2026-04-18 + scenario_complete delta #12 + scenario_beat_retried delta #12 + ADR-0017 line 209 instance-form widening delta #13. (2) ADVISORY — ai-system.md CR-AI-1 line 28 wording "post-MVP step 6.5" → "step 5.5" reconciliation (ADR-0016 6-step sequence has GridBattleController at step 5 + BattleHUD at step 6, so insertion is "5.5" not "6.5"). Mount sequence renumber decision (ADR-0019 §Mount Order line 254): **Path A — insert "step 5.5"** preserving 1-6 numbering; full 1-7 renumber deferred to sprint-7+ S7-02 when ADR-0016 is touched anyway for sprint-6 mock encoder deletion + lint phase-flip + main_scene revert. Architecture registry updates v12 → v13: 1 state_ownership added (ai_system_runtime_state) + 1 state_ownership amended (battle_runtime_state — 5 → 6 LOCAL signals) + 1 interface added (ai_action_signal_contract — LOCAL signal pattern, NOT GameBus) + 1 api_decision added (ai_system_module_form — battle-scoped Node 6th invocation + single-class match-dispatch + 2 typed Resources + main-thread synchronous MVP) + 4 forbidden_patterns added (ai_system_signal_emission_outside_action_ready + ai_system_static_var + **ai_system_reads_destiny_branch_state — Pillar 2 architectural lock 4th project precedent** + ai_system_direct_battle_state_read) + 1 forbidden_pattern amended (grid_battle_controller_signal_emission_outside_battle_domain — 5 → 6 signals). tr-registry.yaml v14 → v15: 15 net-new TR-ai-system-001..015 entries (total 239 → 254). Combined-session pattern (escalation + structural append in single fresh session) stable at 4 invocations. Battle-scoped Node pattern stable at 6 invocations. LOCAL-signal-not-GameBus pattern stable at 2 invocations (GridBattleController + AISystem). Total accepted ADR count 18 → 19. Feature layer 3/4 → **4/4 Complete** (AI System closes the MVP Feature-layer chain; Battle Preparation deferred to post-MVP). Pre-Production → Production gate now eligible (mandatory ADR list = 0; AI System closes the cross-director convergent blocker per gate-check 2026-05-04 path-to-PASS item #4). Source: `docs/architecture/architecture-review-2026-05-05.md`. |
