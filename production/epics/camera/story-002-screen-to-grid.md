# Story 002: screen_to_grid implementation + 3-zoom invariance test

> **Epic**: Camera | **Status**: Complete | **Layer**: Feature | **Type**: Logic | **Estimate**: 1h
> **ADR**: ADR-0013 §4 (cross-system contract from input-handling §9)

## Acceptance Criteria

- [x] `screen_to_grid(screen_pos: Vector2) -> Vector2i` implementation using `get_canvas_transform().affine_inverse()`
- [x] Returns `Vector2i(-1, -1)` sentinel for off-grid (out of map bounds)
- [x] 3-zoom invariance: same screen position returns same grid coord at zoom 0.70, 1.00, 2.00 (cursor-stable zoom recipe preserves world position)
- [x] SOLE implementation — `external_screen_to_grid_implementation` forbidden_pattern enforced via lint

## Implementation

`src/feature/camera/battle_camera.gd::screen_to_grid` (~10 LoC). Tested via `tests/unit/feature/camera/battle_camera_screen_to_grid_test.gd` (4 tests).

## Test Evidence

**Story Type**: Logic. Required: unit tests at the specified path. Status: 4 tests PASS / 0 orphans.
