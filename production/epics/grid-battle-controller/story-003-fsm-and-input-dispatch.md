# Story 003: 2-state FSM + input action dispatch + click hit-test routing

> **Epic**: Grid Battle Controller | **Status**: Ready | **Layer**: Feature | **Type**: Logic | **Estimate**: 3h
> **ADR**: ADR-0014 §2, §4

## Acceptance Criteria

- [ ] **AC-1** `enum BattleState { OBSERVATION, UNIT_SELECTED }` declared on GridBattleController (2-state MVP per ADR-0014 §0; full grid-battle.md FSM with AI substates deferred to Battle AI ADR)
- [ ] **AC-2** `_state: BattleState = BattleState.OBSERVATION` instance field; `_selected_unit_id: int = -1` (sentinel for none-selected)
- [ ] **AC-3** `_on_input_action_fired(action: String, ctx: InputContext)` handler subscribed via CONNECT_DEFERRED in `_ready()` (story-001) — first action: `_is_grid_action(action)` filter; non-grid actions silently ignored
- [ ] **AC-4** `_is_grid_action(action: String) -> bool` returns true for the 10 grid-domain actions per input-handling GDD §93 list: `unit_select`, `move_target_select`, `move_confirm`, `move_cancel`, `attack_target_select`, `attack_confirm`, `attack_cancel`, `undo_last_move`, `end_unit_turn`, `grid_hover` (PC-only — silently ignored on TOUCH per CR-1c)
- [ ] **AC-5** `_handle_grid_click(action: String, coord: Vector2i, unit_id: int)` dispatch via `match _state`:
  - `OBSERVATION` arm: clicking own unit → `_select_unit(unit_id)` → state transitions to UNIT_SELECTED + emits `unit_selected_changed(unit_id, was_selected=-1)` signal
  - `UNIT_SELECTED` arm: clicking selected unit again → `_deselect()` (state → OBSERVATION + signal); clicking valid move target → handoff to story-004 `_handle_move`; clicking valid attack target → handoff to story-005 `_handle_attack`
- [ ] **AC-6** Click hit-test re-resolution: if `ctx.target_coord == Vector2i.ZERO` (sentinel from InputRouter when raw event couldn't resolve), Camera fallback: `coord = _camera.screen_to_grid(get_viewport().get_mouse_position())`. Off-grid sentinel `Vector2i(-1, -1)` early-returns
- [ ] **AC-7** Acted-this-turn check: clicking a player unit that's in `_acted_this_turn` (story-006) is silent no-op (no state change, no signal)
- [ ] **AC-8** Test sweep: 10 grid actions × 2 states = 20 (action, state) combinations. For each: assert state transition + signal emission (or no-emit) match the FSM per ADR-0014 §2 (most are silent no-ops; only the documented transitions actually fire)
- [ ] **AC-9** Regression baseline maintained: ≥757 + new tests / 0 errors / 0 orphans / Exit 0; new test file `tests/unit/feature/grid_battle/grid_battle_controller_fsm_test.gd` adds ≥6 tests covering AC-1..AC-8

## Implementation Notes

*Derived from ADR-0014 §2 + §4 + chapter-prototype's _handle_click + input-handling GDD §93:*

1. **2-state FSM** is intentionally simpler than input-handling's 7-state FSM (S0..S6). Per ADR-0014 §0 MVP scope: GridBattleController doesn't track INPUT_BLOCKED (S5) or MENU_OPEN (S6) — those are owned by InputRouter (sprint-5+ work). When InputRouter emits actions, S5/S6 are already filtered upstream.
2. **Action filter**: only 10 grid-domain actions trigger this controller. Camera/menu/meta actions silently ignored (Camera epic owns camera actions; Battle HUD will own menu actions).
3. **State + signal contract**: every state transition emits `unit_selected_changed(new_unit_id, prev_unit_id)` exactly once BEFORE downstream processing. Mirrors damage-calc's emit-pair discipline (signal capture via G-4 Array-append).
4. **Acted-this-turn guard**: prevents double-action exploits. Story-006 implements `_acted_this_turn` Dictionary; story-003 just adds the guard check at click entry.
5. **Test pattern**: 20-combination sweep uses parametric Array[Dictionary]; per turn-order epic AC-GB-16 closed-signal-set precedent (assert exact ordered signal set with monitor_signals).

## Test Evidence

**Story Type**: Logic (FSM + dispatch are pure deterministic logic)
**Required evidence**: `tests/unit/feature/grid_battle/grid_battle_controller_fsm_test.gd` — must exist + ≥6 tests + must pass
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: Story 001 (skeleton + GameBus subscription); Story 002 (BattleUnit registry for unit lookup)
- **Unlocks**: Story 004 (move action handoff), Story 005 (attack action handoff), Story 006 (acted-this-turn integration), Story 007 (turn flow), Story 008 (fate condition tracking)
