# Story 003: _apply_zoom_delta cursor-stable recipe + range clamp [0.70, 2.00]

> **Epic**: Camera | **Status**: Complete | **Layer**: Feature | **Type**: Logic | **Estimate**: 1h
> **ADR**: ADR-0013 §2 + R-4

## Acceptance Criteria

- [x] `_apply_zoom_delta(delta: float, cursor_screen_pos: Vector2)` implementation
- [x] Range clamp `[CAMERA_ZOOM_MIN=0.70, CAMERA_ZOOM_MAX=2.00]` via `clampf()`
- [x] Step `CAMERA_ZOOM_STEP=0.10` from BalanceConstants (`hardcoded_zoom_literals` forbidden_pattern compliant)
- [x] Cursor-stable recipe: preserve cursor's world position across zoom delta via `cursor_world_before/after` adjustment
- [x] Early-return at floor/ceiling via `is_equal_approx(new_zoom, old_zoom)` (R-4 mitigation)
- [x] Re-applies pan-clamp after zoom (zoom may invalidate prior clamp)

## Implementation

`src/feature/camera/battle_camera.gd::_apply_zoom_delta` (~12 LoC). Tested via `tests/unit/feature/camera/battle_camera_zoom_test.gd` (6 tests covering default + step + floor/ceiling clamp + no-op-at-floor).

## Test Evidence

**Story Type**: Logic. Required: unit tests at the specified path. Status: 6 tests PASS / 0 orphans.
