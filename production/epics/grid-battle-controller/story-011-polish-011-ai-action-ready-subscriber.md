# Story 011: POLISH-011 absorption — AISystem.ai_action_ready subscriber + declare_action plumbing for AI commands

> **Epic**: Grid Battle Controller
> **Status**: Ready
> **Layer**: Feature (battle orchestrator)
> **Type**: Integration
> **Estimate**: 2-4h (~0.3d)
> **Manifest Version**: 2026-05-05
> **Sprint**: sprint-15 (S15-B) — POLISH-011 absorption #2 of 3
> **Backlog**: POLISH-011 (CRITICAL release-blocker; gates Production advancement)

## Context

**GDD**: `design/gdd/grid-battle.md` (CR-3 + CR-3a `ai_action_requested` / `ai_action_ready` signal protocol + 500ms timeout + WAIT-substitution)
**Requirement**: `TR-grid-battle-controller-007` (closest existing TR — covers DEFERRED-connect subscription discipline + `_exit_tree()` disconnect; the new `ai_action_ready` LOCAL subscription extends the 4-GameBus-subscription pattern to a 5th subscriber for the LOCAL signal from AISystem) + ADR-0019 §Decision §Payload Form (AIActionCommand) + ADR-0014 §8 (LOCAL signal contract — story-011 amends with new ai_action_ready subscriber)

**ADR Governing Implementation**: ADR-0014 §8 (LOCAL signal contract — adds `ai_action_ready` consumer subscription + handler); ADR-0019 §Decision §Payload Form (AIActionCommand consumer contract); ADR-0011 §Amendment 2026-05-09 (T5 await mechanism via S15-A — handler must call `declare_action` to release T5)

**ADR Decision Summary**: Per ADR-0014 + ADR-0019, `GridBattleController` emits `ai_action_requested(unit_id, BattleStateSnapshot)` LOCAL signal at T4 when active unit is non-player-controlled (line 441 of `grid_battle_controller.gd`). `AISystem._on_ai_action_requested` consumes it, runs utility scoring, and emits `ai_action_ready(unit_id, AIActionCommand)` LOCAL signal back. S15-B closes the **subscriber gap**: `GridBattleController` does NOT currently subscribe to `ai_action_ready` — the AI's command is emitted but never consumed → AI turns drain to ROUND_CAP DRAW. POLISH-011 root cause #2 of 3.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (AIActionCommand.ActionType has 6 values vs TurnOrderRunner.ActionType has 5 — MOVE_AND_ATTACK requires 2 declare_action calls; USE_SKILL is deferred per ADR-0014 §0 MVP scope)
**Engine Notes**: `Object.CONNECT_DEFERRED` for `ai_action_ready` subscription per ADR-0001 §5 mandate (AISystem source outlives GridBattleController target). `AIActionCommand` is a typed Resource (Godot 4.0+ stable). Idempotent `is_connected` guard pattern per ADR-0014 R-7.

**Control Manifest Rules (Feature layer — ADR-0014 §8)**:
- Required: 5 LOCAL signals stay LOCAL (no GameBus emission); `ai_action_ready` subscription via DI'd AISystem reference; CONNECT_DEFERRED + `_exit_tree()` disconnect
- Forbidden: `grid_battle_controller_signal_emission_outside_battle_domain` (no GameBus.*.emit); `grid_battle_controller_static_state` (no static var); `grid_battle_controller_external_combat_math` (formation/angle math stays in `_resolve_attack`)
- Guardrail: 500ms timeout substitution (WAIT) when AI doesn't respond; `ai_soft_lock_counter` escalation per CR-3 protocol (deferred to S15-B+ scope if surfaced)

---

## Acceptance Criteria

*From sprint-15.md S15-B acceptance criteria + ADR-0014 §8 + ADR-0019 §Decision §Payload Form:*

- [ ] **AC-1** `_on_ai_action_ready(unit_id: int, command: AIActionCommand)` handler exists in `grid_battle_controller.gd`. Subscribed to `_ai_system.ai_action_ready` (DI'd AISystem reference) at battle init via `setup()` or `_ready()` with `Object.CONNECT_DEFERRED`. Idempotent `is_connected` guard per ADR-0014 R-7 pattern. Disconnect in `_exit_tree()`.
- [ ] **AC-2** Handler maps `AIActionCommand.action_type` → `TurnOrderRunner.ActionType` correctly for the 5 supported actions:
  - `WAIT` → `TurnOrderRunner.ActionType.WAIT` (no game action; just declare_action)
  - `MOVE` → `_handle_move(unit, target)` then `declare_action(unit_id, MOVE, target)`
  - `ATTACK` → `_handle_attack(attacker_id, defender_id)` then `declare_action(unit_id, ATTACK, target)`
  - `DEFEND` → `declare_action(unit_id, DEFEND, null)` (no separate game action; sets `defend_stance_active`)
  - `MOVE_AND_ATTACK` → `_handle_move` + `declare_action(MOVE)` then `_handle_attack` + `declare_action(ATTACK)` (sequential; second call triggers T6+T7 deferred via S15-A's `_maybe_defer_turn_completion`)
  - `USE_SKILL` → substitute with `WAIT` per ADR-0014 §0 MVP scope deferral; log at `push_warning` level; future story re-enables
- [ ] **AC-3** Handler executes the actual game action via existing `_handle_move(unit, target)` / `_handle_attack(attacker_id, defender_id)` methods BEFORE calling `declare_action`. State mutations (HP, position, etc.) occur first; declare_action reflects token spend; T6+T7 fire from S15-A deferred path.
- [ ] **AC-4** Handler calls `_turn_runner.declare_action(unit_id, action_type, target)` with appropriate `ActionTarget` payload (constructed from AIActionCommand fields). For MOVE: target.move_target = command.move_target; for ATTACK: target.target_unit_id = command.attack_target_unit_id.
- [ ] **AC-5** ADR-0014 amendment documents the `ai_action_ready` subscriber contract + handler dispatch table (5 supported ActionTypes + USE_SKILL deferral + 500ms timeout WAIT substitution).
- [ ] **AC-6** Integration test `tests/integration/feature/grid_battle/grid_battle_controller_ai_action_ready_test.gd` drives AI-only battle to non-DRAW resolution: 2-unit roster (1 AI Aggressor, 1 AI Holder OR mock-controlled) → `initialize_battle` + `set_action_controller` + AISystem wired → battle progresses through deferred chain → `victory_condition_detected` emits non-DRAW result.
- [ ] **AC-7** Test count delta: 1295 baseline + ~3-5 new tests = ~1298-1300; 0 NEW failures introduced (pre-existing hp_status_perf flap remains unrelated).
- [ ] **AC-8** Backward compat: existing 5 LOCAL signals + 9 GameBus subscriptions (per ADR-0014 §8) preserved; existing grid-battle-controller story-001..010 tests continue to PASS without regression.

---

## Implementation Notes

*Derived from ADR-0014 §8 + ADR-0019 §Decision §Payload Form + S15-A T5 await mechanism (commit `ab924aa`):*

1. **Subscriber wiring** — add to `grid_battle_controller.gd` `setup()` (or `_ready()` after DI is complete):
   ```gdscript
   if not _ai_system.ai_action_ready.is_connected(_on_ai_action_ready):
       _ai_system.ai_action_ready.connect(_on_ai_action_ready, Object.CONNECT_DEFERRED)
   ```
   Verify DI sequence: `_ai_system` must be non-null before connect (asserted in `_ready` per ADR-0014 R-1 DI discipline pattern).

2. **`_exit_tree()` disconnect** (per ADR-0014 R-7 + battle-scoped Node 4-precedent discipline):
   ```gdscript
   if is_instance_valid(_ai_system) and _ai_system.ai_action_ready.is_connected(_on_ai_action_ready):
       _ai_system.ai_action_ready.disconnect(_on_ai_action_ready)
   ```

3. **Handler dispatch table** — match-statement on `command.action_type`:
   ```gdscript
   func _on_ai_action_ready(unit_id: int, command: AIActionCommand) -> void:
       if not _units.has(unit_id):
           push_warning("ai_action_ready for unknown unit_id %d — ignoring" % unit_id)
           return
       var unit: BattleUnit = _units[unit_id]
       match command.action_type:
           AIActionCommand.ActionType.WAIT:
               _turn_runner.declare_action(unit_id, TurnOrderRunner.ActionType.WAIT, null)
           AIActionCommand.ActionType.MOVE:
               _handle_move(unit, command.move_target)
               var target: ActionTarget = _make_move_target(command.move_target)
               _turn_runner.declare_action(unit_id, TurnOrderRunner.ActionType.MOVE, target)
           AIActionCommand.ActionType.ATTACK:
               _handle_attack(unit_id, command.attack_target_unit_id)
               var target: ActionTarget = _make_attack_target(command.attack_target_unit_id)
               _turn_runner.declare_action(unit_id, TurnOrderRunner.ActionType.ATTACK, target)
           AIActionCommand.ActionType.MOVE_AND_ATTACK:
               _handle_move(unit, command.move_target)
               var move_target: ActionTarget = _make_move_target(command.move_target)
               _turn_runner.declare_action(unit_id, TurnOrderRunner.ActionType.MOVE, move_target)
               _handle_attack(unit_id, command.attack_target_unit_id)
               var atk_target: ActionTarget = _make_attack_target(command.attack_target_unit_id)
               _turn_runner.declare_action(unit_id, TurnOrderRunner.ActionType.ATTACK, atk_target)
           AIActionCommand.ActionType.DEFEND:
               _turn_runner.declare_action(unit_id, TurnOrderRunner.ActionType.DEFEND, null)
           AIActionCommand.ActionType.USE_SKILL:
               # Per ADR-0014 §0 MVP scope: USE_SKILL deferred; substitute WAIT.
               push_warning("AIActionCommand.USE_SKILL deferred per ADR-0014 §0 — substituting WAIT")
               _turn_runner.declare_action(unit_id, TurnOrderRunner.ActionType.WAIT, null)
   ```

4. **ActionTarget construction** — verify `ActionTarget` typed Resource shape:
   - `target.move_target: Vector2i` for MOVE
   - `target.target_unit_id: int` for ATTACK
   - `target.movement_cost: int` for MOVE (used by F-2 charge accumulation per ADR-0011 line 318 — populate via `MapGrid.get_movement_cost(from, to)` or `_handle_move`'s computed path cost)

5. **Integration test pattern** — mirrors `tests/integration/core/turn_order_t5_await_test.gd` structure (S15-A precedent):
   - Use real GameBus + real TurnOrderRunner (with controller injected)
   - Mock or use real AISystem (depending on test isolation needs)
   - Drive: `initialize_battle(roster)` → `set_action_controller(_dispatch_handler)` → `initialize_battle` → wait for deferred chain → assert AIActionCommand triggered + battle progressed
   - G-30 mitigation: drive natural deferred chain; NO direct `_advance_turn` calls

6. **Performance budget** — no perf impact expected. Handler dispatch is O(1) match statement; no hot-path allocations beyond the existing `_handle_move`/`_handle_attack` paths (already perf-tested in story-004/005). MOVE_AND_ATTACK adds 1 extra declare_action call per AI turn (still O(1) per turn).

---

## Dependencies

- **Depends On**: S15-A (story-008; T5 await + `set_action_controller` + `_maybe_defer_turn_completion`) — ✅ Complete (2026-05-10 commit `ab924aa`)
- **Blocks**: S15-D (natural-loop integration test for AI-only + mixed battles), S15-E (gate-check rerun-4 PASS), S15-G (S8-15 §1.3 third re-attestation)

## Test Evidence

- **Type**: Integration (cross-system: AISystem ↔ GridBattleController ↔ TurnOrderRunner)
- **Location**: `tests/integration/feature/grid_battle/grid_battle_controller_ai_action_ready_test.gd` (NEW)
- **Gate Level**: BLOCKING per coding-standards.md Test Evidence Matrix

## Out of Scope

- Player declare_action plumbing in grid-click handlers (S15-C scope)
- Full natural-loop battle-end-to-end integration test (S15-D scope; this story's test is AI-only single-action verification)
- 500ms AI timeout + WAIT-substitution per CR-3b (deferred to follow-up story; currently AISystem responds synchronously)
- USE_SKILL action implementation (deferred per ADR-0014 §0 MVP scope)
- `ai_soft_lock_counter` escalation per CR-3 (deferred)
- ADR-0011 / ADR-0019 amendments (only ADR-0014 amendment in this story)

## Risks

- **R1**: ActionTarget construction — may surface gap if `_make_move_target` / `_make_attack_target` factories don't exist (would need to be added or refactored from existing `_handle_grid_click_unit_selected` arms). Mitigation: inspect existing target construction in `_handle_grid_click_unit_selected` first; reuse pattern.
- **R2**: MOVE_AND_ATTACK 2-call sequence may trigger turn-end prematurely if first declare_action(MOVE) somehow sets action_token_spent=true. Verify against S15-A `_maybe_defer_turn_completion` predicate: MOVE only sets `move_token_spent`; predicate requires `action_token_spent` OR `turn_state == DONE` — so MOVE alone won't trigger. Validated in S15-A `test_t5_holds_for_move_does_not_complete_turn`.
- **R3**: AISystem subscriber may re-fire if same unit_id has multiple deferred ai_action_ready emits. Mitigation: idempotent `is_connected` guard prevents duplicate subscription; AISystem should emit at most once per ai_action_requested per turn.
