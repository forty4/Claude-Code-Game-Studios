# InputRouter Verification #6 — Touch Event Index Stability (Physical Hardware)

**Epic**: input-handling
**Story**: story-009-touch-protocol-pan-tap-gestures-panel
**ADR**: ADR-0005 §Verification Required §6 + Implementation Notes Advisory B
**Status**: Polish-deferred (physical hardware required)

## Test Procedure (Physical Device — Polish-deferable)

1. Boot iOS 17 device + Android 14+ device with running app
2. Place 2 fingers on screen sequentially: finger 1 first, finger 2 second
3. Verify `InputEventScreenTouch.index == 0` for finger 1 + `index == 1` for finger 2
4. Lift finger 1 (still finger 2 down)
5. Verify finger 2 STILL has `index == 1` (NOT reassigned to 0)
6. Lift finger 2; place 2 fresh fingers
7. Verify indices restart from 0 (post-clear)

## Expected Result

OS-assigned indices stable through multi-touch sequence; not reassigned on any single-finger lift. Confirms CR-4g + EC-1 multi-touch cancel logic in story-009 (`_handle_two_finger_gesture` + `_handle_touch_tracking` + `_active_touch_indices` tracking) operates correctly under real OS-driven index assignment.

## Polish-Deferral Rationale

Headless GdUnit4 tests in `tests/unit/foundation/input_router_touch_part_b_test.gd` inject synthetic `InputEventScreenTouch` and `InputEventScreenDrag` events with manually-set `.index` field and verify the cancel logic (`test_two_finger_arrival_cancels_first_finger_tpp_state`, `test_two_finger_tap_emits_camera_two_finger_tap_cancel`, `test_two_finger_drag_emits_camera_pinch_zoom`).

Production correctness depends on OS-assigned index stability which only physical hardware can confirm. Synthetic injection trusts the manually-set index to behave as the OS would; the runtime-on-device test is what confirms the OS actually keeps indices stable across single-finger lifts in the same multi-touch sequence.

Reactivation trigger: when iOS 17 + Android 14+ device available AND first iOS/Android export build is green.

## Headless Coverage (Story-009)

The synthetic-event tests cover the InputRouter-side dispatch contract:
- `test_two_finger_tap_emits_camera_two_finger_tap_cancel` — second-finger tap (index=1, pressed=true) emits `&"camera_two_finger_tap_cancel"` via `_handle_two_finger_gesture`
- `test_two_finger_drag_emits_camera_pinch_zoom` — second-finger drag (index=1) emits `&"camera_pinch_zoom"`
- `test_two_finger_arrival_cancels_first_finger_tpp_state` — second-finger arrival resets `_last_tap_unit_id = -1` and `_last_tap_time_ms = 0` per EC-1 multi-touch cancel
- `test_classify_pan_or_tap_*` (3 tests + parametric sweep) — single-finger classifier (index=0 only)

These tests verify the InputRouter responds correctly to events that have indices set per OS contract; verification #6 confirms the OS contract itself.

## Status

**Polish-deferred** per ADR-0005 §Verification Required §6 + Implementation Notes Advisory B. Pattern follows the 5+ precedent of physical-hardware-required deferrals (verification §5a Android, §6 iOS/Android multi-touch).

## Reactivation Checklist

When physical hardware becomes available:
- [ ] Boot first iOS 17 device with running app via Xcode export
- [ ] Boot first Android 14+ device with running app via Android Studio export
- [ ] Run the 7-step Test Procedure above on each device
- [ ] Update Status to "Verified (iOS 17 + Android 14+)"
- [ ] Document any per-platform divergence in this file (e.g. iOS reassigns indices on single-finger lift; Android does not)
- [ ] If divergence observed, file follow-up story to add per-platform compensation logic in `_handle_touch_tracking`
