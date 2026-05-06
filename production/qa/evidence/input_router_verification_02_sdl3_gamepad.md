# InputRouter Verification #2 — SDL3 Gamepad Detection

**Epic**: input-handling
**Story**: story-005-mode-determination-cr2
**ADR**: ADR-0005 §Verification Required §2
**Status**: Polish-deferred

## Test Procedure

1. Boot Android 15 / iOS 17 device with running app
2. Pair Bluetooth Xbox/PS5 controller mid-scene (after first non-gamepad input fires)
3. Press a controller button
4. Verify `InputEventJoypadButton` event arrives (capture via debug log)
5. Verify `InputRouter.get_active_input_mode() == KEYBOARD_MOUSE` (NOT a new GAMEPAD value)
6. Verify subsequent keyboard event preserves KEYBOARD_MOUSE without redundant emit

## Expected Result

SDL3 backend correctly delivers Joypad events; InputRouter routes to KEYBOARD_MOUSE per OQ-1 MVP scope. No 3rd GAMEPAD mode is introduced. `input_mode_changed` is emitted once if prior mode was TOUCH; emitted zero times if prior mode was already KEYBOARD_MOUSE.

## Polish-Deferral Rationale

Headless tests `test_joypad_button_routes_to_keyboard_mouse` and `test_mode_detection_event_class_sweep` (cases JoypadButton + JoypadMotion) in `tests/unit/foundation/input_router_mode_test.gd` verify the KEYBOARD_MOUSE routing with synthetic `InputEventJoypadButton` / `InputEventJoypadMotion` injection. Device verification confirms SDL3 backend doesn't introduce new event class names that would bypass the routing table.

**Reactivation trigger**: when Bluetooth gamepad available AND first Android export build is green.

**Ready-to-ship fallback**: KEYBOARD_MOUSE routing verified in headless via synthetic `InputEventJoypadButton` injection — see `test_joypad_button_routes_to_keyboard_mouse` (AC-6) and the JoypadButton + JoypadMotion cases in `test_mode_detection_event_class_sweep` (AC-9).

**Estimated Polish-phase effort**: ~20min once Bluetooth gamepad available (Android 15 or iOS 17 device + controller pairing).
