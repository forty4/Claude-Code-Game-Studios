extends GdUnitTestSuite

## input_router_mode_test.gd
## Story 005 tests — last-device-wins mode determination (CR-2) + input_mode_changed
## emit + state preservation across mode switch + idempotency.
## Covers AC-1..AC-6 + AC-9 + AC-11 per story QA Test Cases.
##
## Pattern mirrors input_router_fsm_attack_st2_test.gd (story-004):
##   - G-15: before_test() not before_each()
##   - G-4: lambda captures via Array.append (primitive outer locals NOT propagated)
##   - G-10: emit on real GameBus autoload (no GameBusStub.swap_in)
##   - G-16: sweep test uses Array[Dictionary] for typed parametric list
##   - G-22: structural source assertions use line-anchored regex skipping # lines
##
## LIFECYCLE:
##   before_test — resets all 10 InputRouter fields (6 ADR-0005 §1 + _last_matched_action
##                 + _grid_battle + _pending_end_phase + _did_visible_work) +
##                 disconnects any leftover input_mode_changed lambda from prior test
##   after_test  — disconnects input_mode_changed lambda (safety net)

const _IR_PATH: String = "res://src/foundation/input_router.gd"

## Lambda callable stored for proper disconnection in after_test.
var _mode_changed_lambda: Callable


func before_test() -> void:
	# G-15 reset — full 10-field clear (6 ADR-0005 §1 fields + _last_matched_action
	# + _grid_battle + _pending_end_phase + _did_visible_work)
	InputRouter._state = InputRouter.InputState.OBSERVATION
	InputRouter._active_mode = InputRouter.InputMode.KEYBOARD_MOUSE
	InputRouter._pre_menu_state = InputRouter.InputState.OBSERVATION
	InputRouter._undo_windows.clear()
	InputRouter._input_blocked_reasons.clear()
	InputRouter._bindings.clear()
	InputRouter._last_matched_action = &""
	InputRouter._grid_battle = null
	InputRouter._pending_end_phase = false
	InputRouter._did_visible_work = false

	# Disconnect any leftover lambda from a prior test (safety net before fresh lambda)
	if _mode_changed_lambda.is_valid():
		if GameBus.input_mode_changed.is_connected(_mode_changed_lambda):
			GameBus.input_mode_changed.disconnect(_mode_changed_lambda)

	# Invalidate so after_test doesn't try to disconnect an already-gone lambda
	_mode_changed_lambda = Callable()


func after_test() -> void:
	# Disconnect test-side subscriber to prevent cross-test interference
	if _mode_changed_lambda.is_valid():
		if GameBus.input_mode_changed.is_connected(_mode_changed_lambda):
			GameBus.input_mode_changed.disconnect(_mode_changed_lambda)


# ── AC-1: _determine_mode_from_event helper routing ──────────────────────────


## AC-1: ScreenTouch event returns TOUCH mode.
func test_determine_mode_from_screen_touch_returns_touch() -> void:
	# Arrange
	var event := InputEventScreenTouch.new()

	# Act
	var result: InputRouter.InputMode = InputRouter._determine_mode_from_event(event)

	# Assert
	assert_int(int(result)).override_failure_message(
		"AC-1: InputEventScreenTouch must return TOUCH (int 1), got %d" % int(result)
	).is_equal(int(InputRouter.InputMode.TOUCH))


## AC-1: ScreenDrag event returns TOUCH mode.
func test_determine_mode_from_screen_drag_returns_touch() -> void:
	# Arrange
	var event := InputEventScreenDrag.new()

	# Act
	var result: InputRouter.InputMode = InputRouter._determine_mode_from_event(event)

	# Assert
	assert_int(int(result)).override_failure_message(
		"AC-1: InputEventScreenDrag must return TOUCH (int 1), got %d" % int(result)
	).is_equal(int(InputRouter.InputMode.TOUCH))


## AC-1: Mouse and key events return KEYBOARD_MOUSE mode.
## Uses InputEventMouseButton as the representative keyboard/mouse event subtype.
func test_determine_mode_from_mouse_or_key_returns_keyboard_mouse() -> void:
	# Arrange
	var mouse_event := InputEventMouseButton.new()

	# Act
	var result: InputRouter.InputMode = InputRouter._determine_mode_from_event(mouse_event)

	# Assert
	assert_int(int(result)).override_failure_message(
		"AC-1: InputEventMouseButton must return KEYBOARD_MOUSE (int 0), got %d" % int(result)
	).is_equal(int(InputRouter.InputMode.KEYBOARD_MOUSE))


## AC-1 defensive: unknown event class preserves current _active_mode (no flip).
## InputEventAction is a concrete subtype that is NOT in the 7-routed classes
## (it's not ScreenTouch/ScreenDrag/MouseButton/MouseMotion/Key/JoypadButton/JoypadMotion).
func test_determine_mode_from_unknown_event_class_preserves_current_mode() -> void:
	# Arrange — set active mode to TOUCH so we can observe that it is preserved
	InputRouter._active_mode = InputRouter.InputMode.TOUCH
	var unknown_event := InputEventAction.new()

	# Act
	var result: InputRouter.InputMode = InputRouter._determine_mode_from_event(unknown_event)

	# Assert — must preserve TOUCH (the current _active_mode), not flip to KEYBOARD_MOUSE
	assert_int(int(result)).override_failure_message(
		"AC-1: Unknown event class must preserve current _active_mode (TOUCH=1), got %d" % int(result)
	).is_equal(int(InputRouter.InputMode.TOUCH))


# ── AC-2 + AC-3: _handle_event emits input_mode_changed on mode switch ───────


## AC-2 + AC-3: touch event after keyboard mode updates _active_mode synchronously
## AND emits input_mode_changed with int(TOUCH)=1 exactly once.
## G-4: uses Array.append capture (not primitive increment) for emit counting.
func test_handle_event_emits_input_mode_changed_on_touch_after_keyboard() -> void:
	# Arrange — start in KEYBOARD_MOUSE (before_test default)
	var captures: Array = []
	_mode_changed_lambda = func(mode: int) -> void:
		captures.append(mode)
	GameBus.input_mode_changed.connect(_mode_changed_lambda)

	# Act
	var touch_event := InputEventScreenTouch.new()
	touch_event.pressed = true
	InputRouter._handle_event(touch_event)

	# Assert — synchronous field update (no await needed per AC-3 spec)
	assert_int(int(InputRouter._active_mode)).override_failure_message(
		"AC-2+AC-3: _active_mode must be TOUCH (int 1) after touch event, got %d" % int(InputRouter._active_mode)
	).is_equal(int(InputRouter.InputMode.TOUCH))

	# Assert — exactly 1 emit captured
	assert_int(captures.size()).override_failure_message(
		"AC-2+AC-3: input_mode_changed must emit exactly 1 time on KEYBOARD_MOUSE→TOUCH switch, got %d" % captures.size()
	).is_equal(1)

	# Assert — emitted payload is int(TOUCH) = 1
	assert_int(captures[0] as int).override_failure_message(
		"AC-2+AC-3: input_mode_changed payload must be int(TOUCH)=1, got %d" % (captures[0] as int)
	).is_equal(int(InputRouter.InputMode.TOUCH))


# ── AC-4: state + undo_windows preserved across mode switch ──────────────────


## AC-4 (CR-2c): switching mode via key event preserves _state and _undo_windows.
## Pre-condition: TOUCH + UNIT_SELECTED + one undo entry.
## Post-condition: KEYBOARD_MOUSE + same state + same undo entry reference.
func test_mode_switch_preserves_state_and_undo_windows() -> void:
	# Arrange: TOUCH mode + S1 (UNIT_SELECTED) + one undo entry
	InputRouter._active_mode = InputRouter.InputMode.TOUCH
	InputRouter._state = InputRouter.InputState.UNIT_SELECTED
	var undo := UndoEntry.new()
	undo.unit_id = 1
	undo.pre_move_coord = Vector2i(2, 2)
	undo.pre_move_facing = 0
	InputRouter._undo_windows[1] = undo

	# Act: keyboard event triggers mode switch TOUCH → KEYBOARD_MOUSE
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_ENTER
	key_event.pressed = true
	InputRouter._handle_event(key_event)

	# Assert — mode switched
	assert_int(int(InputRouter._active_mode)).override_failure_message(
		"AC-4: _active_mode must be KEYBOARD_MOUSE (int 0) after key event, got %d" % int(InputRouter._active_mode)
	).is_equal(int(InputRouter.InputMode.KEYBOARD_MOUSE))

	# Assert — FSM state preserved (CR-2c)
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-4 CR-2c: _state must remain UNIT_SELECTED (int 1) across mode switch, got %d" % int(InputRouter._state)
	).is_equal(int(InputRouter.InputState.UNIT_SELECTED))

	# Assert — undo window preserved (CR-2c)
	assert_bool(InputRouter._undo_windows.has(1)).override_failure_message(
		"AC-4 CR-2c: _undo_windows[1] must still exist after mode switch"
	).is_true()

	# Assert — same reference (not a copy)
	assert_object(InputRouter._undo_windows[1]).override_failure_message(
		"AC-4 CR-2c: _undo_windows[1] must be the exact same UndoEntry reference (not a copy)"
	).is_same(undo)


# ── AC-5: idempotency — no repeated emit when mode unchanged ─────────────────


## AC-5 idempotency: 5 keyboard events in KEYBOARD_MOUSE mode → 0 emits.
## G-4: Array.append capture pattern.
func test_repeated_keyboard_events_emit_mode_changed_zero_times() -> void:
	# Arrange — start in KEYBOARD_MOUSE (before_test default)
	var captures: Array = []
	_mode_changed_lambda = func(mode: int) -> void:
		captures.append(mode)
	GameBus.input_mode_changed.connect(_mode_changed_lambda)

	# Act — 5 keyboard events, all same mode
	for i: int in 5:
		var event := InputEventKey.new()
		event.keycode = KEY_A
		event.pressed = true
		InputRouter._handle_event(event)

	# Assert — zero emits (mode unchanged throughout)
	assert_int(captures.size()).override_failure_message(
		"AC-5 idempotency: 5 keyboard events in KEYBOARD_MOUSE mode must emit 0 times, got %d" % captures.size()
	).is_equal(0)


## AC-5 secondary boundary: KEYBOARD → TOUCH → KEYBOARD emits exactly twice.
## G-4: Array.append capture pattern.
func test_keyboard_then_touch_then_keyboard_emits_mode_changed_twice() -> void:
	# Arrange — start in KEYBOARD_MOUSE (before_test default)
	var captures: Array = []
	_mode_changed_lambda = func(mode: int) -> void:
		captures.append(mode)
	GameBus.input_mode_changed.connect(_mode_changed_lambda)

	# Act — keyboard (no change), then touch (→ TOUCH = 1st emit), then keyboard (→ KBM = 2nd emit)
	var key_event := InputEventKey.new()
	key_event.keycode = KEY_A
	key_event.pressed = true
	InputRouter._handle_event(key_event)  # no emit — already KEYBOARD_MOUSE

	var touch_event := InputEventScreenTouch.new()
	touch_event.pressed = true
	InputRouter._handle_event(touch_event)  # 1st emit: KEYBOARD_MOUSE → TOUCH

	var key_event2 := InputEventKey.new()
	key_event2.keycode = KEY_B
	key_event2.pressed = true
	InputRouter._handle_event(key_event2)  # 2nd emit: TOUCH → KEYBOARD_MOUSE

	# Assert — exactly 2 emits
	assert_int(captures.size()).override_failure_message(
		"AC-5 boundary: KEYBOARD→TOUCH→KEYBOARD must emit 2 times total, got %d" % captures.size()
	).is_equal(2)

	# Assert — first emit was TOUCH (int 1)
	assert_int(captures[0] as int).override_failure_message(
		"AC-5 boundary: first emit must be TOUCH (int 1), got %d" % (captures[0] as int)
	).is_equal(int(InputRouter.InputMode.TOUCH))

	# Assert — second emit was KEYBOARD_MOUSE (int 0)
	assert_int(captures[1] as int).override_failure_message(
		"AC-5 boundary: second emit must be KEYBOARD_MOUSE (int 0), got %d" % (captures[1] as int)
	).is_equal(int(InputRouter.InputMode.KEYBOARD_MOUSE))


# ── AC-6: joypad routes to KEYBOARD_MOUSE (TR-011 OQ-1 MVP) ──────────────────


## AC-6 (TR-011): JoypadButton routes to KEYBOARD_MOUSE, never a 3rd GAMEPAD mode.
## If prior mode was already KEYBOARD_MOUSE, 0 emits expected.
func test_joypad_button_routes_to_keyboard_mouse() -> void:
	# Arrange — start in KEYBOARD_MOUSE (before_test default); capture emits
	var captures: Array = []
	_mode_changed_lambda = func(mode: int) -> void:
		captures.append(mode)
	GameBus.input_mode_changed.connect(_mode_changed_lambda)

	# Act
	var joypad_event := InputEventJoypadButton.new()
	joypad_event.button_index = 0  # A button (generic)
	InputRouter._handle_event(joypad_event)

	# Assert — mode is KEYBOARD_MOUSE (joypad maps to KBM, not a new GAMEPAD mode)
	assert_int(int(InputRouter._active_mode)).override_failure_message(
		"AC-6 TR-011: Joypad must route to KEYBOARD_MOUSE (int 0), got %d" % int(InputRouter._active_mode)
	).is_equal(int(InputRouter.InputMode.KEYBOARD_MOUSE))

	# Assert — 0 emits because mode was already KEYBOARD_MOUSE
	assert_int(captures.size()).override_failure_message(
		"AC-6 TR-011: joypad from KEYBOARD_MOUSE baseline must emit 0 times (mode unchanged), got %d" % captures.size()
	).is_equal(0)


# ── AC-9: mode detection sweep — 7 event classes ─────────────────────────────


## AC-9: parametric sweep over all 7 event classes with expected mode per CR-2 table.
## G-16: typed Array[Dictionary] for case list.
## Uses event_factory Callable for lazy construction inside the test body.
func test_mode_detection_event_class_sweep() -> void:
	# Arrange — 7-case table per CR-2 routing rules
	var cases: Array[Dictionary] = [
		{
			"event_factory": func() -> InputEvent: return InputEventMouseButton.new(),
			"expected": InputRouter.InputMode.KEYBOARD_MOUSE,
			"name": "MouseButton"
		},
		{
			"event_factory": func() -> InputEvent: return InputEventMouseMotion.new(),
			"expected": InputRouter.InputMode.KEYBOARD_MOUSE,
			"name": "MouseMotion"
		},
		{
			"event_factory": func() -> InputEvent: return InputEventKey.new(),
			"expected": InputRouter.InputMode.KEYBOARD_MOUSE,
			"name": "Key"
		},
		{
			"event_factory": func() -> InputEvent: return InputEventScreenTouch.new(),
			"expected": InputRouter.InputMode.TOUCH,
			"name": "ScreenTouch"
		},
		{
			"event_factory": func() -> InputEvent: return InputEventScreenDrag.new(),
			"expected": InputRouter.InputMode.TOUCH,
			"name": "ScreenDrag"
		},
		{
			"event_factory": func() -> InputEvent: return InputEventJoypadButton.new(),
			"expected": InputRouter.InputMode.KEYBOARD_MOUSE,
			"name": "JoypadButton"
		},
		{
			"event_factory": func() -> InputEvent: return InputEventJoypadMotion.new(),
			"expected": InputRouter.InputMode.KEYBOARD_MOUSE,
			"name": "JoypadMotion"
		},
	]

	# Act + Assert — per-case
	for case: Dictionary in cases:
		var event: InputEvent = (case["event_factory"] as Callable).call()
		var expected: InputRouter.InputMode = case["expected"] as InputRouter.InputMode
		var actual: InputRouter.InputMode = InputRouter._determine_mode_from_event(event)
		assert_int(int(actual)).override_failure_message(
			"AC-9 sweep case %s: expected mode %d, got %d" % [case["name"] as String, int(expected), int(actual)]
		).is_equal(int(expected))


# ── AC-11: get_active_input_mode returns updated value after switch ───────────


## AC-11: get_active_input_mode() returns the updated _active_mode value after a
## mode switch (confirms the getter is wired to the live field, not a stale snapshot).
func test_get_active_input_mode_returns_updated_value_after_switch() -> void:
	# Arrange — start in KEYBOARD_MOUSE (before_test default)
	assert_int(int(InputRouter.get_active_input_mode())).override_failure_message(
		"AC-11 pre-condition: initial mode must be KEYBOARD_MOUSE (int 0), got %d" % int(InputRouter.get_active_input_mode())
	).is_equal(int(InputRouter.InputMode.KEYBOARD_MOUSE))

	# Act — send touch event to trigger mode switch
	var touch_event := InputEventScreenTouch.new()
	touch_event.pressed = true
	InputRouter._handle_event(touch_event)

	# Assert — getter returns the updated mode
	assert_int(int(InputRouter.get_active_input_mode())).override_failure_message(
		"AC-11: get_active_input_mode() must return TOUCH (int 1) after touch event, got %d" % int(InputRouter.get_active_input_mode())
	).is_equal(int(InputRouter.InputMode.TOUCH))
