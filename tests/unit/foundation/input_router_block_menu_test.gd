extends GdUnitTestSuite

## input_router_block_menu_test.gd
## Story 007 tests — S5 INPUT_BLOCKED + S6 MENU_OPEN + GameBus subscriptions +
## nested PackedStringArray block stack + set_input_as_handled() + ST-2 menu
## restoration + verification evidence #4 (recursive Control disable).
## Covers AC-1..AC-11.
##
## Pattern mirrors input_router_undo_window_test.gd (story-006 canonical precedent):
##   - G-3:  no class_name — InputRouter is an autoload without class_name
##   - G-4:  Array capture pattern for signal arg collection
##   - G-10: use REAL GameBus autoload for emits (not a stub)
##   - G-15: before_test() not before_each() — GdUnit4 v6.1.2 lifecycle
##   - G-22: structural source-scan assertions use FileAccess.get_file_as_string
##   - G-25: no nested typed collections at declaration site
##   - G-26: no class_name on this test file — avoids collision with global registry
##   - G-28: disconnect only test-side lambdas in after_test (never bulk-disconnect-all)

const _IR_PATH: String = "res://src/foundation/input_router.gd"
const _EVIDENCE_PATH: String = "res://production/qa/evidence/input_router_verification_04_recursive_control_disable.md"

## Test-side captures for signal observation (G-4 pattern; disconnected in after_test).
var _state_changed_captures: Array = []
var _action_fired_captures: Array = []
var _state_changed_lambda: Callable
var _action_fired_lambda: Callable


func before_test() -> void:
	# G-15 canonical reset (5th-precedent autoload helper, story-010 epic-terminal).
	# Covers all 17 fields per `tools/ci/lint_input_router_g15_reset.sh`.
	InputRouter.reset_for_tests()
	# G-15 reset — full 11-field clear (story-007 adds _pre_block_state)
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
	InputRouter._pre_block_state = InputRouter.InputState.OBSERVATION
	# Reset capture arrays
	_state_changed_captures = []
	_action_fired_captures = []
	# Wire test-side captures (G-28: cache Callable references to disconnect only these)
	_state_changed_lambda = func(from: int, to: int) -> void:
		_state_changed_captures.append({"from": from, "to": to})
	_action_fired_lambda = func(action: String, _ctx: InputContext) -> void:
		_action_fired_captures.append({"action": action})
	GameBus.input_state_changed.connect(_state_changed_lambda)
	GameBus.input_action_fired.connect(_action_fired_lambda)


func after_test() -> void:
	# G-28: disconnect ONLY test-side lambdas; never bulk-disconnect production subs
	if GameBus.input_state_changed.is_connected(_state_changed_lambda):
		GameBus.input_state_changed.disconnect(_state_changed_lambda)
	if GameBus.input_action_fired.is_connected(_action_fired_lambda):
		GameBus.input_action_fired.disconnect(_action_fired_lambda)
	# Safety: restore process flags in case AC-9 test left them disabled
	InputRouter.set_process_input(true)
	InputRouter.set_process_unhandled_input(true)
	# Reset block state
	InputRouter._input_blocked_reasons.clear()
	InputRouter._pre_block_state = InputRouter.InputState.OBSERVATION


# ── AC-1: GameBus subscriptions wired in _ready() ────────────────────────────


## AC-1: Source-scan confirms 2 CONNECT_DEFERRED subscriptions in _ready() body.
## Structural assertion per G-22 — does not require mounting InputRouter.
func test_ac1_gamebus_subscriptions_present_in_ready_source() -> void:
	var content: String = FileAccess.get_file_as_string(_IR_PATH)
	assert_bool(
		content.contains(
			"GameBus.ui_input_block_requested.connect(_on_ui_input_block_requested, Object.CONNECT_DEFERRED)"
		)
	).override_failure_message(
		"AC-1: _ready() must wire ui_input_block_requested with CONNECT_DEFERRED"
	).is_true()
	assert_bool(
		content.contains(
			"GameBus.ui_input_unblock_requested.connect(_on_ui_input_unblock_requested, Object.CONNECT_DEFERRED)"
		)
	).override_failure_message(
		"AC-1: _ready() must wire ui_input_unblock_requested with CONNECT_DEFERRED"
	).is_true()


# ── AC-11: _pre_block_state field declared as transient-internal ──────────────


## AC-11: Source-scan confirms _pre_block_state field with correct type and default.
func test_ac11_pre_block_state_field_declared_in_source() -> void:
	var content: String = FileAccess.get_file_as_string(_IR_PATH)
	assert_bool(
		content.contains("var _pre_block_state: InputState = InputState.OBSERVATION")
	).override_failure_message(
		"AC-11: _pre_block_state must be declared as `var _pre_block_state: InputState = InputState.OBSERVATION`"
	).is_true()


## AC-11 reset obligation: before_test() resets _pre_block_state to OBSERVATION.
func test_ac11_pre_block_state_reset_to_observation_by_before_test() -> void:
	# If before_test() ran correctly, _pre_block_state is OBSERVATION
	assert_int(int(InputRouter._pre_block_state)).override_failure_message(
		"AC-11: before_test() must reset _pre_block_state to OBSERVATION"
	).is_equal(int(InputRouter.InputState.OBSERVATION))


# ── AC-2: First block entry → S5 + captures _pre_block_state ─────────────────


## AC-2: First ui_input_block_requested transitions OBSERVATION → S5 + emits 1 state_changed.
func test_ac2_first_block_entry_transitions_to_s5_and_emits() -> void:
	# Arrange — state is OBSERVATION (via before_test reset)
	assert_int(int(InputRouter._state)).is_equal(int(InputRouter.InputState.OBSERVATION))

	# Act — emit via REAL GameBus; CONNECT_DEFERRED requires await
	GameBus.ui_input_block_requested.emit("transition")
	await get_tree().process_frame

	# Assert — state transitioned to S5
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-2: first block entry must set _state to INPUT_BLOCKED (S5)"
	).is_equal(int(InputRouter.InputState.INPUT_BLOCKED))

	# Assert — _pre_block_state captured OBSERVATION
	assert_int(int(InputRouter._pre_block_state)).override_failure_message(
		"AC-2: _pre_block_state must capture prior state (OBSERVATION) on first block entry"
	).is_equal(int(InputRouter.InputState.OBSERVATION))

	# Assert — exactly 1 state_changed emit
	assert_int(_state_changed_captures.size()).override_failure_message(
		"AC-2: exactly 1 input_state_changed must emit on first block entry"
	).is_equal(1)
	assert_int(_state_changed_captures[0]["from"] as int).override_failure_message(
		"AC-2: state_changed 'from' must be OBSERVATION (0)"
	).is_equal(int(InputRouter.InputState.OBSERVATION))
	assert_int(_state_changed_captures[0]["to"] as int).override_failure_message(
		"AC-2: state_changed 'to' must be INPUT_BLOCKED (5)"
	).is_equal(int(InputRouter.InputState.INPUT_BLOCKED))

	# Assert — _input_blocked_reasons has 1 entry
	assert_int(InputRouter._input_blocked_reasons.size()).override_failure_message(
		"AC-2: _input_blocked_reasons must have exactly 1 entry after first block"
	).is_equal(1)


## AC-2 edge: second block stacks size=2; state stays S5; 0 additional emits.
func test_ac2_second_block_is_idempotent_no_additional_emit() -> void:
	# Arrange — emit first block
	GameBus.ui_input_block_requested.emit("transition")
	await get_tree().process_frame
	assert_int(InputRouter._input_blocked_reasons.size()).is_equal(1)
	var emit_count_after_first: int = _state_changed_captures.size()

	# Act — emit second block reason
	GameBus.ui_input_block_requested.emit("dialog")
	await get_tree().process_frame

	# Assert — stack size 2; state still S5; no additional emit
	assert_int(InputRouter._input_blocked_reasons.size()).override_failure_message(
		"AC-2 edge: second block must grow stack to size 2"
	).is_equal(2)
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-2 edge: state must remain INPUT_BLOCKED after second block"
	).is_equal(int(InputRouter.InputState.INPUT_BLOCKED))
	assert_int(_state_changed_captures.size()).override_failure_message(
		"AC-2 edge: second block must emit 0 additional state_changed signals"
	).is_equal(emit_count_after_first)


# ── AC-3: Final unblock restores _pre_block_state + emits 1 state_changed ────


## AC-3: Final unblock restores prior state + emits 1 state_changed.
func test_ac3_final_unblock_restores_pre_block_state() -> void:
	# Arrange — block transition
	GameBus.ui_input_block_requested.emit("transition")
	await get_tree().process_frame
	assert_int(int(InputRouter._state)).is_equal(int(InputRouter.InputState.INPUT_BLOCKED))
	var emit_count_before_unblock: int = _state_changed_captures.size()

	# Act — final unblock
	GameBus.ui_input_unblock_requested.emit("transition")
	await get_tree().process_frame

	# Assert — state restored to OBSERVATION
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-3: final unblock must restore _state to OBSERVATION (_pre_block_state)"
	).is_equal(int(InputRouter.InputState.OBSERVATION))

	# Assert — stack empty
	assert_bool(InputRouter._input_blocked_reasons.is_empty()).override_failure_message(
		"AC-3: _input_blocked_reasons must be empty after final unblock"
	).is_true()

	# Assert — _pre_block_state reset to OBSERVATION
	assert_int(int(InputRouter._pre_block_state)).override_failure_message(
		"AC-3: _pre_block_state must be reset to OBSERVATION after final unblock"
	).is_equal(int(InputRouter.InputState.OBSERVATION))

	# Assert — exactly 1 additional state_changed emit
	assert_int(_state_changed_captures.size()).override_failure_message(
		"AC-3: exactly 1 additional input_state_changed must emit on final unblock"
	).is_equal(emit_count_before_unblock + 1)


## AC-3 edge: unknown unblock reason fires push_warning + no state change + stack unchanged.
func test_ac3_unknown_unblock_reason_no_state_change() -> void:
	# Arrange — block first so we have a known state
	GameBus.ui_input_block_requested.emit("transition")
	await get_tree().process_frame
	assert_int(int(InputRouter._state)).is_equal(int(InputRouter.InputState.INPUT_BLOCKED))
	var stack_size_before: int = InputRouter._input_blocked_reasons.size()
	var emit_count_before: int = _state_changed_captures.size()

	# Act — unblock with unknown reason (push_warning fires in production code)
	GameBus.ui_input_unblock_requested.emit("unknown_reason_xyz")
	await get_tree().process_frame

	# Assert — state unchanged
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-3 edge: unknown unblock reason must NOT change _state"
	).is_equal(int(InputRouter.InputState.INPUT_BLOCKED))

	# Assert — stack size unchanged
	assert_int(InputRouter._input_blocked_reasons.size()).override_failure_message(
		"AC-3 edge: unknown unblock reason must NOT modify _input_blocked_reasons stack"
	).is_equal(stack_size_before)

	# Assert — no additional emit
	assert_int(_state_changed_captures.size()).override_failure_message(
		"AC-3 edge: unknown unblock reason must emit 0 additional state_changed signals"
	).is_equal(emit_count_before)


# ── AC-4: S5 grid action silent-drop + permitted camera actions ───────────────


## AC-4: S5 grid action (unit_select) is silently dropped — no state change, no emit.
func test_ac4_s5_grid_action_silently_dropped() -> void:
	# Arrange — force S5
	InputRouter._state = InputRouter.InputState.INPUT_BLOCKED
	var ctx := InputContext.new()
	ctx.target_unit_id = 1
	var emit_count_before: int = _action_fired_captures.size()

	# Act — dispatch unit_select directly via _handle_action
	InputRouter._handle_action(&"unit_select", ctx)

	# Assert — state unchanged (still S5)
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-4: unit_select in S5 must NOT change _state (must remain INPUT_BLOCKED)"
	).is_equal(int(InputRouter.InputState.INPUT_BLOCKED))

	# Assert — no action_fired emit (silent drop)
	assert_int(_action_fired_captures.size()).override_failure_message(
		"AC-4: unit_select in S5 must emit 0 input_action_fired signals"
	).is_equal(emit_count_before)


## AC-4: S5 camera_pan permitted — _did_visible_work set + action_fired emits.
func test_ac4_s5_camera_pan_permitted_emits_action_fired() -> void:
	# Arrange — force S5
	InputRouter._state = InputRouter.InputState.INPUT_BLOCKED
	var ctx := InputContext.new()
	var emit_count_before: int = _action_fired_captures.size()

	# Act — dispatch camera_pan (permitted in S5)
	InputRouter._handle_action(&"camera_pan", ctx)

	# Assert — state unchanged (camera actions don't change state in S5)
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-4: camera_pan in S5 must NOT change _state"
	).is_equal(int(InputRouter.InputState.INPUT_BLOCKED))

	# Assert — _did_visible_work was set → action_fired emitted
	assert_int(_action_fired_captures.size()).override_failure_message(
		"AC-4: camera_pan in S5 must emit 1 input_action_fired (permitted action)"
	).is_equal(emit_count_before + 1)


## AC-4: S5 open_unit_info permitted — action_fired emits.
func test_ac4_s5_open_unit_info_permitted_emits_action_fired() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.INPUT_BLOCKED
	var ctx := InputContext.new()
	var emit_count_before: int = _action_fired_captures.size()

	# Act
	InputRouter._handle_action(&"open_unit_info", ctx)

	# Assert — state unchanged
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-4: open_unit_info in S5 must NOT change _state"
	).is_equal(int(InputRouter.InputState.INPUT_BLOCKED))

	# Assert — action_fired emitted
	assert_int(_action_fired_captures.size()).override_failure_message(
		"AC-4: open_unit_info in S5 must emit 1 input_action_fired"
	).is_equal(emit_count_before + 1)


## AC-4: Source-scan structural test — _handle_action_in_s5 silent-drop arms
## must call get_viewport().set_input_as_handled() per Advisory C forbidden_pattern.
##
## At least 2 calls expected: one for the grid-action drop arm + one for the
## unrecognised-action fallthrough arm. Permitted-action arm must NOT call it
## (propagation needed for Camera + BattleHUD _unhandled_input handlers).
##
## Story-010 lint will eventually enforce structurally; this test documents the
## requirement until the lint script ships.
func test_ac4_s5_silent_drop_arms_call_set_input_as_handled_in_source() -> void:
	var content: String = FileAccess.get_file_as_string(_IR_PATH)
	# Locate _handle_action_in_s5 body bounded by the next func declaration
	var s5_start: int = content.find("func _handle_action_in_s5(")
	assert_int(s5_start).override_failure_message(
		"_handle_action_in_s5 not found in source"
	).is_greater_equal(0)
	var s5_end: int = content.find("\nfunc ", s5_start + 1)
	assert_int(s5_end).override_failure_message(
		"Could not locate end of _handle_action_in_s5 body"
	).is_greater(s5_start)
	var s5_body: String = content.substr(s5_start, s5_end - s5_start)
	var call_count: int = s5_body.split("get_viewport().set_input_as_handled()").size() - 1
	assert_int(call_count).override_failure_message(
		(
			"AC-4 Advisory C: _handle_action_in_s5 must call get_viewport()."
			+ "set_input_as_handled() in at least 2 silent-drop arms (grid-drop + "
			+ "fallthrough); found %d. Story-010 lint will enforce structurally."
		)
		% call_count
	).is_greater_equal(2)


# ── AC-5: 4-event nested block sequence — exactly 2 emits total ───────────────


## AC-5: 4-event nested block sequence (block T, block D, unblock D, unblock T)
## produces exactly 2 input_state_changed emits (first block + final unblock).
func test_ac5_nested_block_sequence_exactly_two_emits() -> void:
	# Arrange — initial state is OBSERVATION
	assert_int(int(InputRouter._state)).is_equal(int(InputRouter.InputState.OBSERVATION))

	# Event 1: block "transition" → S5 + 1 emit
	GameBus.ui_input_block_requested.emit("transition")
	await get_tree().process_frame

	# Event 2: block "dialog" → stack size 2; no emit
	GameBus.ui_input_block_requested.emit("dialog")
	await get_tree().process_frame

	# Verify mid-sequence: stack size 2; state S5; only 1 emit so far
	assert_int(InputRouter._input_blocked_reasons.size()).is_equal(2)
	assert_int(int(InputRouter._state)).is_equal(int(InputRouter.InputState.INPUT_BLOCKED))
	assert_int(_state_changed_captures.size()).override_failure_message(
		"AC-5: after 2 block events, only 1 emit should have fired"
	).is_equal(1)

	# Event 3: unblock "dialog" → stack size 1; no emit
	GameBus.ui_input_unblock_requested.emit("dialog")
	await get_tree().process_frame

	# Verify: stack size 1; state still S5; still 1 emit
	assert_int(InputRouter._input_blocked_reasons.size()).is_equal(1)
	assert_int(int(InputRouter._state)).is_equal(int(InputRouter.InputState.INPUT_BLOCKED))
	assert_int(_state_changed_captures.size()).override_failure_message(
		"AC-5: after partial unblock, still only 1 emit should have fired"
	).is_equal(1)

	# Event 4: unblock "transition" → stack empty; state restores; 1 more emit
	GameBus.ui_input_unblock_requested.emit("transition")
	await get_tree().process_frame

	# Assert final: state OBSERVATION; exactly 2 emits total
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-5: after final unblock, state must be OBSERVATION"
	).is_equal(int(InputRouter.InputState.OBSERVATION))
	assert_int(_state_changed_captures.size()).override_failure_message(
		"AC-5: 4-event nested sequence must produce exactly 2 input_state_changed emits"
	).is_equal(2)
	assert_bool(InputRouter._input_blocked_reasons.is_empty()).override_failure_message(
		"AC-5: _input_blocked_reasons must be empty after final unblock"
	).is_true()


# ── AC-6: S6 close_menu with ST-2 demotion ───────────────────────────────────


## AC-6: close_menu from S6 with _pre_menu_state=S2 demotes to S1 via ST-2.
func test_ac6_close_menu_from_s2_demotes_to_s1() -> void:
	# Arrange — S6 with _pre_menu_state = MOVEMENT_PREVIEW (S2)
	InputRouter._state = InputRouter.InputState.MENU_OPEN
	InputRouter._pre_menu_state = InputRouter.InputState.MOVEMENT_PREVIEW
	var ctx := InputContext.new()
	var emit_count_before: int = _state_changed_captures.size()

	# Act
	InputRouter._handle_action(&"close_menu", ctx)

	# Assert — state → S1 (ST-2 demotion: S2 → S1)
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-6: close_menu from S6 (pre=S2) must demote to UNIT_SELECTED (S1) via ST-2"
	).is_equal(int(InputRouter.InputState.UNIT_SELECTED))

	# Assert — state_changed emitted (S6 → S1 transition)
	assert_int(_state_changed_captures.size()).override_failure_message(
		"AC-6: close_menu must emit 1 input_state_changed"
	).is_equal(emit_count_before + 1)


## AC-6 edge: _pre_menu_state=S0 → close_menu restores S0 directly (no demotion).
func test_ac6_close_menu_from_s0_restores_s0_directly() -> void:
	# Arrange — S6 with _pre_menu_state = OBSERVATION (S0)
	InputRouter._state = InputRouter.InputState.MENU_OPEN
	InputRouter._pre_menu_state = InputRouter.InputState.OBSERVATION
	var ctx := InputContext.new()

	# Act
	InputRouter._handle_action(&"close_menu", ctx)

	# Assert — state → S0 (no demotion needed for S0)
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-6 edge: close_menu from S6 (pre=S0) must restore OBSERVATION (S0) directly"
	).is_equal(int(InputRouter.InputState.OBSERVATION))


# ── AC-7: AC-16 GDD test — menu state preservation with ST-2 demotion ─────────


## AC-7 (GDD AC-16): Full sequence S0→S1→S2→S6→S1 with ST-2 demotion.
## Pending move-confirm (S2) is dropped on menu-close; state demotes to S1.
func test_ac7_gdd_ac16_menu_demotion_sequence() -> void:
	# Arrange — inject GridBattleStub so S1→S2 transition succeeds
	var stub := GridBattleStub.new()
	stub.fixture_in_range_coords.append(Vector2i(3, 3))
	InputRouter.set_grid_battle_for_tests(stub)

	# Step 1: S0 → S1 via unit_select
	InputRouter._state = InputRouter.InputState.OBSERVATION
	var ctx_s0 := InputContext.new()
	ctx_s0.target_unit_id = 1
	InputRouter._handle_action(&"unit_select", ctx_s0)
	assert_int(int(InputRouter._state)).is_equal(int(InputRouter.InputState.UNIT_SELECTED))

	# Step 2: S1 → S2 via move_target_select
	var ctx_s1 := InputContext.new()
	ctx_s1.target_coord = Vector2i(3, 3)
	InputRouter._handle_action(&"move_target_select", ctx_s1)
	assert_int(int(InputRouter._state)).is_equal(int(InputRouter.InputState.MOVEMENT_PREVIEW))

	# Step 3: S2 → S6 via open_game_menu (captures _pre_menu_state = S2)
	var ctx_menu := InputContext.new()
	InputRouter._handle_action(&"open_game_menu", ctx_menu)
	assert_int(int(InputRouter._state)).is_equal(int(InputRouter.InputState.MENU_OPEN))
	assert_int(int(InputRouter._pre_menu_state)).override_failure_message(
		"AC-7: _pre_menu_state must be MOVEMENT_PREVIEW (S2) after open_game_menu from S2"
	).is_equal(int(InputRouter.InputState.MOVEMENT_PREVIEW))

	# Step 4: S6 → S1 via close_menu (ST-2 demotion: S2 → S1)
	var ctx_close := InputContext.new()
	InputRouter._handle_action(&"close_menu", ctx_close)

	# Assert — final state is S1 (UNIT_SELECTED), NOT S2 (pending move-confirm dropped)
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-7/GDD-AC16: close_menu from S6 (pre=S2) must arrive at UNIT_SELECTED (S1), not S2"
	).is_equal(int(InputRouter.InputState.UNIT_SELECTED))


# ── AC-8: AC-17 GDD test — S5 drops grid + permits camera/info ───────────────


## AC-8 (GDD AC-17): S5 drops unit_select; camera_pan + open_unit_info still permitted.
func test_ac8_gdd_ac17_s5_drops_grid_permits_camera_and_info() -> void:
	# Arrange — force S5
	InputRouter._state = InputRouter.InputState.INPUT_BLOCKED
	var ctx := InputContext.new()
	ctx.target_unit_id = 1
	var action_fired_before: int = _action_fired_captures.size()

	# Act 1 — unit_select in S5 (silently dropped)
	InputRouter._handle_action(&"unit_select", ctx)
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-8: unit_select in S5 must NOT change state"
	).is_equal(int(InputRouter.InputState.INPUT_BLOCKED))
	assert_int(_action_fired_captures.size()).override_failure_message(
		"AC-8: unit_select in S5 must emit 0 action_fired signals"
	).is_equal(action_fired_before)

	# Act 2 — camera_pan in S5 (permitted)
	var ctx_cam := InputContext.new()
	InputRouter._handle_action(&"camera_pan", ctx_cam)
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-8: camera_pan in S5 must NOT change state"
	).is_equal(int(InputRouter.InputState.INPUT_BLOCKED))
	assert_int(_action_fired_captures.size()).override_failure_message(
		"AC-8: camera_pan in S5 must emit 1 action_fired signal"
	).is_equal(action_fired_before + 1)

	# Act 3 — open_unit_info in S5 (permitted)
	var ctx_info := InputContext.new()
	InputRouter._handle_action(&"open_unit_info", ctx_info)
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-8: open_unit_info in S5 must NOT change state"
	).is_equal(int(InputRouter.InputState.INPUT_BLOCKED))
	assert_int(_action_fired_captures.size()).override_failure_message(
		"AC-8: open_unit_info in S5 must emit 1 additional action_fired signal"
	).is_equal(action_fired_before + 2)


# ── AC-9: Verification evidence #4 exists + headless recursive-control-disable test ─


## AC-9 (part 1): Verification evidence doc exists + contains required strings.
func test_ac9_verification_evidence_doc_exists_and_contains_required_strings() -> void:
	var content: String = FileAccess.get_file_as_string(_EVIDENCE_PATH)
	assert_bool(content.length() > 0).override_failure_message(
		"AC-9: production/qa/evidence/input_router_verification_04_recursive_control_disable.md must exist and be non-empty"
	).is_true()
	assert_bool(content.contains("Verified")).override_failure_message(
		"AC-9: evidence doc must contain 'Verified'"
	).is_true()
	assert_bool(content.contains("headless GdUnit4")).override_failure_message(
		"AC-9: evidence doc must contain 'headless GdUnit4'"
	).is_true()
	assert_bool(content.contains("set_process_input(false)")).override_failure_message(
		"AC-9: evidence doc must contain 'set_process_input(false)'"
	).is_true()
	assert_bool(content.contains("set_process_unhandled_input(false)")).override_failure_message(
		"AC-9: evidence doc must contain 'set_process_unhandled_input(false)'"
	).is_true()


## AC-9 (part 2): Headless verification — godot-specialist 2026-04-30 PASS Item 4
## requires BOTH set_process_input(false) + set_process_unhandled_input(false) to
## silence the autoload Node's input dispatch (one alone is insufficient because
## `_input` and `_unhandled_input` are separate per-frame dispatch paths).
##
## Verification strategy (hybrid):
##   1. Direct-dispatch baseline — `_handle_event(ev)` direct invocation produces
##      an action_fired capture, confirming the dispatch pipeline is wired.
##   2. Gate-flag state verification — toggling set_process_input + set_process_-
##      unhandled_input is observable via is_processing_input + is_processing_-
##      unhandled_input getters, documenting the BOTH-required matrix.
##
## Why this hybrid instead of `Input.parse_input_event` injection: in headless
## mode, `Input.parse_input_event` queues the event but does NOT reliably deliver
## it to autoload `_unhandled_input` (the engine's input dispatch loop runs
## differently when there is no main scene + main viewport). Direct dispatch via
## `_handle_event` confirms the autoload-side wiring; gate-flag state verifies
## the engine-side contract surface. Combined coverage matches the godot-
## specialist Item 4 PASS scope (autoload Node engine semantics).
func test_recursive_control_disable_silences_both_paths() -> void:
	# Arrange — build a synthetic key event matching end_player_turn (KEY_SPACE).
	# end_player_turn is the chosen probe because (a) it is bound in
	# default_bindings.json (keycode 32), (b) it emits input_action_fired in S0
	# without changing _state (sets _pending_end_phase + _did_visible_work), and
	# (c) before_test() resets _pending_end_phase, so this probe doesn't leak
	# state to subsequent tests. toggle_input_hints (F1) was considered but
	# falls through unhandled in S0 — no _did_visible_work = true → no emit.
	var ev := InputEventKey.new()
	ev.keycode = 32  # KEY_SPACE — bound to end_player_turn in default_bindings.json
	ev.pressed = true  # _handle_event filters out release/echo events

	# ── Step 1: dispatch-pipeline baseline (direct invocation) ────────────────
	var captures_baseline: int = _action_fired_captures.size()
	InputRouter._handle_event(ev)
	await get_tree().process_frame
	assert_int(_action_fired_captures.size()).override_failure_message(
		"AC-9 baseline: direct _handle_event(F1) must dispatch toggle_input_hints "
		+ "via the action-resolve loop and emit input_action_fired (confirms the "
		+ "autoload-side dispatch wiring is functional before testing the gates)"
	).is_greater(captures_baseline)

	# ── Step 2: BOTH-required gate-flag state verification ────────────────────
	# Default for autoload Node: both gates enabled (Godot 4.6 engine semantics).
	assert_bool(InputRouter.is_processing_input()).override_failure_message(
		"AC-9: default is_processing_input() must be true for autoload Node"
	).is_true()
	assert_bool(InputRouter.is_processing_unhandled_input()).override_failure_message(
		"AC-9: default is_processing_unhandled_input() must be true for autoload Node"
	).is_true()

	# SceneManager `overworld_pause_during_battle` api_decision sets BOTH to false.
	InputRouter.set_process_input(false)
	InputRouter.set_process_unhandled_input(false)
	assert_bool(InputRouter.is_processing_input()).override_failure_message(
		"AC-9: after set_process_input(false), is_processing_input() must be false"
	).is_false()
	assert_bool(InputRouter.is_processing_unhandled_input()).override_failure_message(
		"AC-9: after set_process_unhandled_input(false), is_processing_unhandled_input() must be false"
	).is_false()

	# Re-enable: SceneManager calls set_process_input(true) + set_process_unhandled_input(true)
	# on battle-end / unblock per overworld_pause_during_battle restoration.
	InputRouter.set_process_input(true)
	InputRouter.set_process_unhandled_input(true)
	assert_bool(InputRouter.is_processing_input()).override_failure_message(
		"AC-9: after set_process_input(true), is_processing_input() must be true"
	).is_true()
	assert_bool(InputRouter.is_processing_unhandled_input()).override_failure_message(
		"AC-9: after set_process_unhandled_input(true), is_processing_unhandled_input() must be true"
	).is_true()


# ── S0/S1/S2 open_game_menu arm source-scan ──────────────────────────────────


## AC-1 (structural): open_game_menu arms in S0, S1, S2, S3 set _pre_menu_state + MENU_OPEN.
func test_open_game_menu_arm_present_in_s0_s1_s2_s3_source() -> void:
	var content: String = FileAccess.get_file_as_string(_IR_PATH)
	# Count occurrences of the uniform open_game_menu implementation block.
	# Each arm sets _pre_menu_state = _state + _state = InputState.MENU_OPEN
	var count: int = content.split("_pre_menu_state = _state").size() - 1
	assert_int(count).override_failure_message(
		("AC-1/Implementation Note 8: '_pre_menu_state = _state' must appear in 4 arms "
		+ "(S0, S1, S2, S3); found %d" % count)
	).is_equal(4)


## open_game_menu from S0 transitions to S6 and captures _pre_menu_state = S0.
func test_open_game_menu_from_s0_transitions_to_menu_open() -> void:
	InputRouter._state = InputRouter.InputState.OBSERVATION
	var ctx := InputContext.new()

	InputRouter._handle_action(&"open_game_menu", ctx)

	assert_int(int(InputRouter._state)).override_failure_message(
		"open_game_menu from S0 must set state to MENU_OPEN (S6)"
	).is_equal(int(InputRouter.InputState.MENU_OPEN))
	assert_int(int(InputRouter._pre_menu_state)).override_failure_message(
		"open_game_menu from S0 must capture _pre_menu_state = OBSERVATION"
	).is_equal(int(InputRouter.InputState.OBSERVATION))


## open_game_menu from S1 transitions to S6 and captures _pre_menu_state = S1.
func test_open_game_menu_from_s1_transitions_to_menu_open() -> void:
	InputRouter._state = InputRouter.InputState.UNIT_SELECTED
	var ctx := InputContext.new()

	InputRouter._handle_action(&"open_game_menu", ctx)

	assert_int(int(InputRouter._state)).override_failure_message(
		"open_game_menu from S1 must set state to MENU_OPEN (S6)"
	).is_equal(int(InputRouter.InputState.MENU_OPEN))
	assert_int(int(InputRouter._pre_menu_state)).override_failure_message(
		"open_game_menu from S1 must capture _pre_menu_state = UNIT_SELECTED"
	).is_equal(int(InputRouter.InputState.UNIT_SELECTED))


## open_game_menu from S2 transitions to S6 and captures _pre_menu_state = S2.
func test_open_game_menu_from_s2_transitions_to_menu_open() -> void:
	InputRouter._state = InputRouter.InputState.MOVEMENT_PREVIEW
	var ctx := InputContext.new()

	InputRouter._handle_action(&"open_game_menu", ctx)

	assert_int(int(InputRouter._state)).override_failure_message(
		"open_game_menu from S2 must set state to MENU_OPEN (S6)"
	).is_equal(int(InputRouter.InputState.MENU_OPEN))
	assert_int(int(InputRouter._pre_menu_state)).override_failure_message(
		"open_game_menu from S2 must capture _pre_menu_state = MOVEMENT_PREVIEW"
	).is_equal(int(InputRouter.InputState.MOVEMENT_PREVIEW))
