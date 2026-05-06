# InputRouter Verification #1 — Dual-Focus End-to-End

**Epic**: input-handling
**Story**: story-005-mode-determination-cr2
**ADR**: ADR-0005 §Verification Required §1
**Status**: Polish-deferred

## Test Procedure

1. Open project on macOS Metal AND Android 14+ emulator
2. Construct test scene with 1 Control node `focus_mode = FOCUS_ALL`
3. Mount InputRouter autoload
4. Tap the Control via touch (mobile) / mouse click (mac); verify `InputRouter.get_active_input_mode() == TOUCH` (mobile) / `KEYBOARD_MOUSE` (mac)
5. Press arrow key without removing focus from Control
6. Confirm `InputRouter.get_active_input_mode() == KEYBOARD_MOUSE` (per most-recent-event-class rule)
7. Confirm Control STILL has its prior visual focus (dual-focus split: keyboard focus moves; mouse focus stays)
8. Capture screenshots demonstrating focus state vs `active_input_mode` divergence

## Expected Result

`active_input_mode` follows most-recent event class regardless of dual-focus channel ownership. Engine does NOT subvert event-class identity at dual-focus layer.

## Polish-Deferral Rationale

Headless GdUnit4 test in `tests/unit/foundation/input_router_mode_test.gd::test_mode_switch_preserves_state_and_undo_windows` already verifies the most-recent-event-class rule against synthetic events. On-device verification confirms engine doesn't subvert this; without device available, headless test is sufficient for MVP.

**Reactivation trigger**: when first Android export build is green AND mac dev box available.

**Ready-to-ship fallback**: Test runs deterministically in headless GdUnit4 via DI seam — see `tests/unit/foundation/input_router_mode_test.gd`; on-device verification only confirms engine doesn't subvert the event-class identity at the dual-focus layer. The `test_mode_switch_preserves_state_and_undo_windows` test in particular covers the state-preservation guarantee (CR-2c) with synthetic events, which is the most-critical invariant.

**Estimated Polish-phase effort**: ~30min on first available device (Android 14+ emulator + macOS Metal).
