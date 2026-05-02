# Story 005: GameBus.input_action_fired CONNECT_DEFERRED + _exit_tree disconnect

> **Epic**: Camera | **Status**: Complete | **Layer**: Feature | **Type**: Integration | **Estimate**: 1h
> **ADR**: ADR-0013 §5 + R-6 (godot-specialist 2026-05-02 review concern #2 — BLOCKING)

## Acceptance Criteria

- [x] `_ready()` subscribes to `GameBus.input_action_fired` via `Object.CONNECT_DEFERRED` (re-entrancy mitigation per ADR-0001 §5)
- [x] `_on_input_action_fired(action: String, _ctx: InputContext)` handler with `match` dispatch on 3 camera actions (`camera_pan` / `camera_zoom_in` / `camera_zoom_out`); non-camera actions silently ignored
- [x] `_exit_tree()` body explicitly disconnects the subscription (per godot-specialist concern #2)
- [x] Without `_exit_tree()` disconnect: GameBus (autoload, never freed) retains callable pointing at freed BattleCamera Node = leak + potential crash on next emit
- [x] Action signature uses `String` (not `StringName`) per shipped `GameBus.input_action_fired` signature on line 49 of `src/core/game_bus.gd` (carried advisory — ADR-0001 line 168 amendment to `StringName` not yet applied per delta #6 Item 10a)

## Implementation

`src/feature/camera/battle_camera.gd::_ready + _exit_tree + _on_input_action_fired` (~20 LoC). Tested via `tests/unit/feature/camera/battle_camera_lifecycle_test.gd::test_exit_tree_disconnects_gamebus_subscription` (verifies live subscription pre-free + 0 subscriptions post-free).

## Test Evidence

**Story Type**: Integration (multi-system: BattleCamera ↔ GameBus autoload signal lifecycle). Required: integration test verifying disconnect. Status: dedicated test PASS in lifecycle test suite.
