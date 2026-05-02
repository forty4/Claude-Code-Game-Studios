# Story 001: BattleCamera class skeleton + DI setup() + _ready() + _exit_tree()

> **Epic**: Camera | **Status**: Complete | **Layer**: Feature | **Type**: Logic | **Estimate**: 1h
> **ADR**: ADR-0013 §1 + §5 + R-6 (godot-specialist concern #2)

## Acceptance Criteria

- [x] `class_name BattleCamera extends Camera2D` (NOT `Camera` per G-12 ClassDB collision)
- [x] 4 instance fields: `_map_grid`, `_drag_active`, `_drag_start_screen_pos`, `_drag_start_camera_pos`
- [x] `setup(map_grid: MapGrid)` DI seam callable BEFORE `add_child()`
- [x] `_ready()` asserts `_map_grid != null` + `make_current()` + zoom default + GameBus subscribe + initial pan_clamp
- [x] `_exit_tree()` body disconnects `GameBus.input_action_fired` (per godot-specialist concern #2 — without this, autoload retains callable on freed Node)

## Implementation

`src/feature/camera/battle_camera.gd` (~140 LoC). Tested via `tests/unit/feature/camera/battle_camera_lifecycle_test.gd` (4 tests).

## Test Evidence

**Story Type**: Logic. Required: unit tests at the specified path. Status: 4 tests PASS / 0 orphans.
