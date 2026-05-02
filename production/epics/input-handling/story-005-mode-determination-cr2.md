# Story 005: Last-device-wins mode determination (CR-2) + most-recent-event-class rule + state preservation across mode switch + input_mode_changed emit + verification evidence #1 (dual-focus) + #2 (SDL3 gamepad)

> **Epic**: Input Handling
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic (mode-determination logic) + 2 Polish-deferable verification evidence docs
> **Estimate**: 3h (+ 2h verification evidence; #1+#2 may Polish-defer per pattern)
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/input-handling.md`
**Requirement**: `TR-input-handling-005`, `TR-input-handling-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005 — Input Handling — InputRouter Autoload + 7-State FSM (MVP scope)
**ADR Decision Summary**: TR-005 = §3 + CR-2 — most-recent-event-class rule: `InputEventMouseButton`/`InputEventMouseMotion`/`InputEventKey` → KEYBOARD_MOUSE; `InputEventScreenTouch`/`InputEventScreenDrag` → TOUCH; `InputEventJoypadButton`/`InputEventJoypadMotion` → KEYBOARD_MOUSE (MVP per §6, OQ-1 partial). godot-specialist 2026-04-30 Item 1 PASS — Godot 4.6 dual-focus does NOT alter event-class identity (InputRouter operates BELOW Control focus layer via `_unhandled_input`). Mode switch fires once per event (no debounce). CR-2c preserves `_state` + `_undo_windows` across mode switch. HUD hint icons update next frame via `input_mode_changed` signal. TR-011 = §6 SDL3 gamepad pass-through; no 3rd GAMEPAD mode for MVP; OQ-1 partially resolved (full gamepad support deferred post-MVP).

**Engine**: Godot 4.6 | **Risk**: HIGH (governed by ADR-0005)
**Engine Notes**: Event-class detection via `event is InputEventMouseButton` etc. (4.0+ stable; `is` operator supports type-narrow per godot-specialist Item 1). InputEventScreenTouch / InputEventScreenDrag (4.0+ stable); InputEventJoypadButton / InputEventJoypadMotion (4.5+ uses SDL3 backend per godot-specialist Item 3 — API surface unchanged but per-controller button index remap may differ from SDL2; does not affect MVP routing-to-KEYBOARD_MOUSE). **6 mandatory verification items** documented in EPIC.md — story-005 covers items #1 (dual-focus end-to-end Android+macOS) and #2 (SDL3 gamepad detection Android+iOS); Polish-deferable per the standing pattern if minimum-spec device unavailable.

**Control Manifest Rules (Foundation layer + Global)**:
- Required: most-recent-event-class rule for mode determination (no debounce, no temporal smoothing); `_active_mode` field is the wire-format authority (downstream Battle HUD reads via `InputRouter.get_active_input_mode()`); state preservation across mode switch (CR-2c); GameBus emit `input_mode_changed(int(new_mode))` ONCE per mode change (NOT per event)
- Forbidden: per-frame mode polling (event-driven only); resetting `_state` or `_undo_windows` on mode switch (CR-2c); 3rd GAMEPAD mode for MVP (OQ-1 deferred); `_active_mode` write outside `_handle_event` (test isolation enforced via convention + story-010 G-15 lint)
- Guardrail: `_handle_event` total length ≤30 LoC after this story's additions (mode-detect + match dispatch); `_determine_mode_from_event` <15 LoC; mode-change emit is exactly 1 per visible mode transition (not 1 per event in same mode); 6 verification evidence files at `production/qa/evidence/input_router_verification_*.md` (2 added this story; 4 added across stories 007/008/009)

---

## Acceptance Criteria

*From GDD §Acceptance Criteria AC-3 + AC-4 + ADR-0005 §3 + §6 + CR-2 + CR-2c + OQ-1:*

- [ ] **AC-1** `_determine_mode_from_event(event: InputEvent) -> InputMode` helper added on InputRouter — returns `InputMode.TOUCH` when event is `InputEventScreenTouch` or `InputEventScreenDrag`; returns `InputMode.KEYBOARD_MOUSE` for all other concrete `InputEvent` subtypes (Mouse / Key / Joypad). Uses `is` type-narrowing per godot-specialist Item 1 PASS. Returns current `_active_mode` for unknown event types (defensive — preserves last known mode)
- [ ] **AC-2** `_handle_event` extended to call `_determine_mode_from_event(event)` BEFORE action match; if returned mode != `_active_mode`, set `_active_mode = new_mode` + emit `GameBus.input_mode_changed.emit(int(new_mode))` (delta #6 wire-format obligation — explicit `int()` cast). Mode-change emit happens BEFORE action dispatch per ADR-0005 §3 + GDD AC-3 "within the same frame" timing
- [ ] **AC-3** AC-3 GDD test: GIVEN `_active_mode = KEYBOARD_MOUSE`, WHEN `InputEventScreenTouch.new()` arrives via `_handle_event` — THEN `_active_mode == TOUCH` after the call AND `input_mode_changed.emit(int(TOUCH)) == int(1)` was captured by signal subscriber. Verify within-same-frame timing: subscriber assertions run synchronously after `_handle_event` returns (no `await get_tree().process_frame` needed for the `_active_mode` field check; emit capture uses `await` only for delivery via CONNECT_DEFERRED downstream subscribers)
- [ ] **AC-4** AC-4 GDD test (state preservation): GIVEN `_state = UNIT_SELECTED` AND `_active_mode = TOUCH` (achieved by sending touch event after touch-mode setup); inject `_undo_windows[1] = UndoEntry...`; WHEN `InputEventKey.new()` (mode switch trigger) arrives via `_handle_event` — THEN `_active_mode == KEYBOARD_MOUSE` AND `_state == UNIT_SELECTED` (unchanged) AND `_undo_windows[1]` still present (CR-2c preservation guarantee)
- [ ] **AC-5** Idempotency test: GIVEN `_active_mode = KEYBOARD_MOUSE`, WHEN multiple `InputEventKey` events arrive in sequence — THEN `input_mode_changed` is emitted ZERO times (mode unchanged); `_active_mode` remains KEYBOARD_MOUSE; first non-key (touch) event triggers exactly 1 emit
- [ ] **AC-6** Joypad routing test (TR-011): GIVEN `InputEventJoypadButton.new()` with button_index=0 (A button typically) arrives via `_handle_event` — THEN `_determine_mode_from_event` returns `InputMode.KEYBOARD_MOUSE` (NOT a new GAMEPAD value); confirms MVP OQ-1 partial resolution; subsequent keyboard event preserves KEYBOARD_MOUSE without redundant emit
- [ ] **AC-7** Verification evidence #1: `production/qa/evidence/input_router_verification_01_dual_focus.md` exists describing dual-focus end-to-end test on Android 14+ emulator + macOS Metal: tap a Control with `focus_mode = FOCUS_ALL`, then press an arrow key → confirm `active_input_mode` switches per most-recent-event-class rule, NOT per focus-channel ownership. Polish-deferable: if no Android emulator + macOS available, doc records "Polish-deferred" with reactivation trigger ("when first Android export build is green AND mac dev box available") + ready-to-ship fallback ("Test runs deterministically in headless GdUnit4 via DI seam — see input_router_mode_test.gd; on-device verification only confirms engine doesn't subvert the event-class identity at the dual-focus layer").
- [ ] **AC-8** Verification evidence #2: `production/qa/evidence/input_router_verification_02_sdl3_gamepad.md` exists describing SDL3 gamepad detection on Android 15 / iOS 17: connect Bluetooth controller mid-scene → confirm `InputEventJoypadButton` events arrive AND that `_active_mode` STAYS `KEYBOARD_MOUSE` (no MVP gamepad mode promotion). Polish-deferable per same pattern; reactivation trigger ("when Bluetooth gamepad available AND first Android export"); ready-to-ship fallback ("KEYBOARD_MOUSE routing verified in headless via synthetic InputEventJoypadButton injection — see AC-6 test").
- [ ] **AC-9** Mode-detection sweep test: parametric Array[Dictionary] cases — for each (event_class, expected_mode) pair: (InputEventMouseButton, KEYBOARD_MOUSE), (InputEventMouseMotion, KEYBOARD_MOUSE), (InputEventKey, KEYBOARD_MOUSE), (InputEventScreenTouch, TOUCH), (InputEventScreenDrag, TOUCH), (InputEventJoypadButton, KEYBOARD_MOUSE), (InputEventJoypadMotion, KEYBOARD_MOUSE) → 7 cases; assert `_determine_mode_from_event(event) == expected_mode`
- [ ] **AC-10** Regression baseline maintained: full GdUnit4 suite passes ≥781 cases (story-004 baseline) + new tests / 0 errors / 0 failures / 0 orphans / Exit 0; new test file `tests/unit/foundation/input_router_mode_test.gd` adds ≥8 tests covering AC-1..AC-6 + AC-9
- [ ] **AC-11** `_active_mode` getter exists: `func get_active_input_mode() -> InputMode: return _active_mode` — already stubbed in story-001; this story confirms it now returns the actual updated value across mode switches

---

## Implementation Notes

*Derived from ADR-0005 §3 + §6 + CR-2 + CR-2c + OQ-1 + delta #6 Item 1 (godot-specialist PASS):*

1. **`_determine_mode_from_event` helper**:
   ```gdscript
   func _determine_mode_from_event(event: InputEvent) -> InputMode:
       if event is InputEventScreenTouch or event is InputEventScreenDrag:
           return InputMode.TOUCH
       if event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventKey:
           return InputMode.KEYBOARD_MOUSE
       if event is InputEventJoypadButton or event is InputEventJoypadMotion:
           # OQ-1 partial: MVP routes joypad to KEYBOARD_MOUSE; future GAMEPAD ADR may add 3rd mode at int 2
           return InputMode.KEYBOARD_MOUSE
       # Defensive: unknown event class — preserve current mode (no flip)
       return _active_mode
   ```

2. **`_handle_event` updated** (extends story-002's matching loop):
   ```gdscript
   func _handle_event(event: InputEvent) -> void:
       # Step 1: mode determination (BEFORE action match per ADR-0005 §3 timing)
       var detected_mode: InputMode = _determine_mode_from_event(event)
       if detected_mode != _active_mode:
           _active_mode = detected_mode
           GameBus.input_mode_changed.emit(int(_active_mode))
       # Step 2: action match (story-002's loop)
       for category: StringName in ACTIONS_BY_CATEGORY.keys():
           for action: StringName in ACTIONS_BY_CATEGORY[category]:
               if InputMap.action_has_event(action, event):
                   var ctx := _construct_input_context(event)  # story-008 implements TPP context enrichment
                   _handle_action(action, ctx)
                   return
       # No action match — silently consume (no error, no warning)
   ```

3. **`_construct_input_context` placeholder**: story-005 returns `InputContext.new()` with default values (Vector2i.ZERO + unit_id=-1). Story-008 implements full context enrichment (extracts `coord` from touch position via Camera stub `screen_to_grid`; extracts `unit_id` from MapGrid stub tile lookup).

4. **Idempotency test** (AC-5):
   ```gdscript
   func test_repeated_keyboard_events_emit_mode_changed_zero_times() -> void:
       InputRouter._active_mode = InputRouter.InputMode.KEYBOARD_MOUSE
       var emit_count: int = 0
       GameBus.input_mode_changed.connect(func(_m): emit_count += 1)
       for i in 5:
           var event := InputEventKey.new()
           event.keycode = KEY_A
           event.pressed = true
           InputRouter._handle_event(event)
       await get_tree().process_frame
       assert_int(emit_count).is_equal(0)  # no emit since mode unchanged
   ```

5. **State preservation test** (AC-4):
   ```gdscript
   func test_mode_switch_preserves_state_and_undo_windows() -> void:
       # Setup: TOUCH mode + S1 + an undo entry
       InputRouter._active_mode = InputRouter.InputMode.TOUCH
       InputRouter._state = InputRouter.InputState.UNIT_SELECTED
       var undo := UndoEntry.new()
       undo.unit_id = 1
       undo.pre_move_coord = Vector2i(2, 2)
       undo.pre_move_facing = 0
       InputRouter._undo_windows[1] = undo
       # Trigger mode switch via key event
       var key_event := InputEventKey.new()
       key_event.keycode = KEY_ENTER
       key_event.pressed = true
       InputRouter._handle_event(key_event)
       # CR-2c preservation
       assert_int(int(InputRouter._active_mode)).is_equal(int(InputRouter.InputMode.KEYBOARD_MOUSE))
       assert_int(int(InputRouter._state)).is_equal(int(InputRouter.InputState.UNIT_SELECTED))
       assert_bool(InputRouter._undo_windows.has(1)).is_true()
       assert_object(InputRouter._undo_windows[1]).is_same(undo)  # same reference
   ```

6. **Sweep test pattern** (AC-9):
   ```gdscript
   func test_mode_detection_event_class_sweep() -> void:
       var cases: Array[Dictionary] = [
           {"event_factory": func(): return InputEventMouseButton.new(), "expected": InputRouter.InputMode.KEYBOARD_MOUSE, "name": "MouseButton"},
           {"event_factory": func(): return InputEventMouseMotion.new(), "expected": InputRouter.InputMode.KEYBOARD_MOUSE, "name": "MouseMotion"},
           {"event_factory": func(): return InputEventKey.new(), "expected": InputRouter.InputMode.KEYBOARD_MOUSE, "name": "Key"},
           {"event_factory": func(): return InputEventScreenTouch.new(), "expected": InputRouter.InputMode.TOUCH, "name": "ScreenTouch"},
           {"event_factory": func(): return InputEventScreenDrag.new(), "expected": InputRouter.InputMode.TOUCH, "name": "ScreenDrag"},
           {"event_factory": func(): return InputEventJoypadButton.new(), "expected": InputRouter.InputMode.KEYBOARD_MOUSE, "name": "JoypadButton"},
           {"event_factory": func(): return InputEventJoypadMotion.new(), "expected": InputRouter.InputMode.KEYBOARD_MOUSE, "name": "JoypadMotion"},
       ]
       for case: Dictionary in cases:
           var event: InputEvent = case["event_factory"].call()
           var expected: InputRouter.InputMode = case["expected"]
           var actual: InputRouter.InputMode = InputRouter._determine_mode_from_event(event)
           assert_int(int(actual)).override_failure_message("case %s: expected %d, got %d" % [case["name"], int(expected), int(actual)]).is_equal(int(expected))
   ```

7. **Verification evidence #1 template** (`production/qa/evidence/input_router_verification_01_dual_focus.md`):
   ```markdown
   # InputRouter Verification #1 — Dual-Focus End-to-End

   **Epic**: input-handling
   **Story**: story-005-mode-determination-cr2
   **ADR**: ADR-0005 §Verification Required §1
   **Status**: [Polish-deferred | Verified macOS | Verified Android | Verified Both]

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

   ## Polish-Deferral Rationale (if applicable)
   Headless GdUnit4 test in `tests/unit/foundation/input_router_mode_test.gd::test_mode_switch_preserves_state_and_undo_windows` already verifies the most-recent-event-class rule against synthetic events. On-device verification confirms engine doesn't subvert this; without device available, headless test is sufficient for MVP. Reactivation trigger: when Android export build is green AND mac dev box configured.
   ```

8. **Verification evidence #2 template** (`production/qa/evidence/input_router_verification_02_sdl3_gamepad.md`):
   ```markdown
   # InputRouter Verification #2 — SDL3 Gamepad Detection

   **Epic**: input-handling
   **Story**: story-005-mode-determination-cr2
   **ADR**: ADR-0005 §Verification Required §2
   **Status**: [Polish-deferred | Verified Android | Verified iOS | Verified Both]

   ## Test Procedure
   1. Boot Android 15 / iOS 17 device with running app
   2. Pair Bluetooth Xbox/PS5 controller mid-scene (after first non-gamepad input fires)
   3. Press a controller button
   4. Verify `InputEventJoypadButton` event arrives (capture via debug log)
   5. Verify `InputRouter.get_active_input_mode() == KEYBOARD_MOUSE` (NOT a new GAMEPAD value)
   6. Verify subsequent keyboard event preserves KEYBOARD_MOUSE without redundant emit

   ## Expected Result
   SDL3 backend correctly delivers Joypad events; InputRouter routes to KEYBOARD_MOUSE per OQ-1 MVP scope.

   ## Polish-Deferral Rationale (if applicable)
   Headless test `test_mode_detection_event_class_sweep` includes the `JoypadButton → KEYBOARD_MOUSE` case. Device verification confirms SDL3 backend doesn't introduce new event class names. Reactivation: when Bluetooth gamepad available + Android export green.
   ```

9. **Test file**: `tests/unit/foundation/input_router_mode_test.gd` — 8-10 tests covering AC-1..AC-6 + AC-9 + AC-11. `before_test()` G-15 reset of all 6 fields + `_pending_end_phase` (story-004 addition). Use lambda `event_factory` pattern to avoid creating event instances at test-class load time (lazy construction inside test body).

10. **G-4 captures pattern**: signal subscriber lambdas use `Array.append` for capture (G-4 — lambdas can't reassign captured primitive locals, but `Array.append` works via reference mutation):
    ```gdscript
    var emit_count: Array = []  # use Array.append to track count via reference
    GameBus.input_mode_changed.connect(func(_m): emit_count.append(_m))
    # ... trigger events ...
    assert_int(emit_count.size()).is_equal(1)
    ```

11. **Polish-deferral pattern (5+ precedent)**: AC-7 + AC-8 verification evidence MAY use Polish-deferral admin pass per established discipline (4 prior precedents: scene-manager/story-007 + map-grid/story-007 + damage-calc/story-010 + hp-status/story-008 cross-platform determinism). Polish-deferred docs include: (a) reactivation trigger, (b) ready-to-ship fallback, (c) estimated Polish-phase effort. Story-010 epic terminal closes verification status across all 6 items.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 006**: Per-unit undo window OPEN/CLOSE logic (this story's AC-4 just verifies undo windows are PRESERVED, not modified, across mode switch)
- **Story 007**: S5/S6 + GameBus subscriptions; ADR-0002 SceneManager `set_process_input(false)` interaction (story-005 mode determination is not gated by INPUT_BLOCKED — events still arrive but action match falls through; verification evidence #4 in story-007)
- **Story 008**: `_construct_input_context` full implementation with Camera/MapGrid stub queries
- **Story 010**: `_active_mode` G-15 reset enforcement lint; epic-terminal verification rollup

---

## QA Test Cases

*Authored inline (lean mode QL-STORY-READY skip).*

- **AC-1**: `_determine_mode_from_event` helper exists + correct routing
  - Given: 7 InputEvent subclass instances
  - When: `_determine_mode_from_event(event)` invoked for each
  - Then: returns expected mode per Implementation Note 1 routing table
- **AC-2**: `_handle_event` mode-detect-then-emit ordering
  - Given: `_active_mode = KEYBOARD_MOUSE`; subscriber connected to `input_mode_changed`
  - When: `InputEventScreenTouch.new()` injected via `_handle_event`
  - Then: `_active_mode == TOUCH` AFTER call returns; `input_mode_changed.emit(1)` captured
- **AC-3**: AC-3 GDD test (touch arrives in keyboard-mode)
  - Given: `_active_mode = KEYBOARD_MOUSE`
  - When: touch event injected
  - Then: `_active_mode == TOUCH`; `input_mode_changed` emitted with int(1)
  - Edge cases: assert "within same frame" — emit captured synchronously after _handle_event returns (subscriber may use CONNECT_DEFERRED for HUD updates separately)
- **AC-4**: AC-4 GDD test (state preservation)
  - Given: TOUCH + S1 + undo entry for unit 1
  - When: KEY_ENTER injected
  - Then: KEYBOARD_MOUSE active; S1 retained; undo entry retained
- **AC-5**: Idempotency
  - Given: KEYBOARD_MOUSE active
  - When: 5 keyboard events injected
  - Then: 0 `input_mode_changed` emits captured
  - Edge cases: 6th event = touch → exactly 1 emit
- **AC-6**: Joypad → KEYBOARD_MOUSE routing
  - Given: any prior mode
  - When: `InputEventJoypadButton.new()` injected
  - Then: `_active_mode == KEYBOARD_MOUSE`; if prior mode was already KEYBOARD_MOUSE, 0 emits; if prior was TOUCH, 1 emit
- **AC-7**: Verification evidence #1 doc exists
  - Given: project filesystem
  - When: check `production/qa/evidence/input_router_verification_01_dual_focus.md`
  - Then: file exists; contains test procedure + expected result + status field (Polish-deferred OR verified)
- **AC-8**: Verification evidence #2 doc exists
  - Given: same as AC-7 for `_02_sdl3_gamepad.md`
- **AC-9**: Sweep
  - Given: 7-case parametric Array[Dictionary]
  - When: each event class detected
  - Then: result matches expected mode
- **AC-10**: Regression baseline
  - Given: full suite invoked
  - When: 781 + new tests run
  - Then: ≥789 tests / 0 errors / 0 failures / 0 orphans / Exit 0
- **AC-11**: `get_active_input_mode()` returns updated value
  - Given: any mode switch
  - When: call `InputRouter.get_active_input_mode()`
  - Then: returns current `_active_mode` (verified via post-switch assertion in AC-3)

---

## Test Evidence

**Story Type**: Logic (mode detection logic) + 2 Polish-deferable verification evidence docs (Visual/Feel-adjacent — on-device confirmation)
**Required evidence**:
- Logic: `tests/unit/foundation/input_router_mode_test.gd` — must exist + ≥8 tests + must pass
- Visual/Feel: `production/qa/evidence/input_router_verification_01_dual_focus.md` + `_02_sdl3_gamepad.md` — must exist; status may be "Polish-deferred" with reactivation trigger documented per established 5+ precedent pattern

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 002 (`_handle_event` matching loop must exist for extension)
- **Unlocks**: Story 008 (touch protocol — `_construct_input_context` extends `_handle_event` with Camera stub query for `coord`); Battle HUD epic (consumes `input_mode_changed` for hint icon updates)
