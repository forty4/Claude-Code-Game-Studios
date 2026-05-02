# Story 004: _handle_camera_pan + _drag_active anchor + edge clamp

> **Epic**: Camera | **Status**: Complete | **Layer**: Feature | **Type**: Logic | **Estimate**: 1h
> **ADR**: ADR-0013 §3 + R-5 + ADR-0005 OQ-2 resolution

## Acceptance Criteria

- [x] `_handle_camera_pan()` implementation — Camera owns drag state per ADR-0005 OQ-2 resolution
- [x] `&"camera_pan"` action treated as TRIGGER (not delta source); Camera reads `get_viewport().get_mouse_position()` itself
- [x] First pan event captures `_drag_start_screen_pos` + `_drag_start_camera_pos` anchors (R-5 touch ordering mitigation)
- [x] Subsequent events compute `world_delta = screen_delta / zoom.x` and apply
- [x] `end_drag()` public method to reset `_drag_active = false` (called by tests + future BattleScene drag-end)
- [x] `_apply_pan_clamp()` keeps map visible — centers if map smaller than viewport, clamps if larger

## Implementation

`src/feature/camera/battle_camera.gd::_handle_camera_pan + _apply_pan_clamp + end_drag` (~25 LoC).

## Test Evidence

**Story Type**: Logic. Pan logic indirectly tested via lifecycle tests (zoom changes invoke pan_clamp); dedicated pan integration tests deferred to grid-battle-controller epic where end-to-end click→pan flow exists.
