extends GdUnitTestSuite

## input_router_fsm_core_test.gd
## Story 003 tests — 7-state FSM core S0/S1/S2 (OBSERVATION ↔ UNIT_SELECTED ↔
## MOVEMENT_PREVIEW) move flow + transition signal emit + 2-beat move confirmation.
## Covers AC-1 through AC-11 per story QA Test Cases.
##
## Pattern: structural source-scan via FileAccess.get_file_as_string + content.contains
## per G-22 precedent. Runtime assertions via direct InputRouter field/method access
## and GameBus signal-capture lambdas (G-4 Array-append pattern).
##
## LIFECYCLE:
##   before_test — clears all 8 InputRouter fields (_state/_active_mode/_pre_menu_state/
##                 _undo_windows/_input_blocked_reasons/_bindings/_last_matched_action
##                 + new _grid_battle) + resets grid battle stub + disconnects test-side
##                 signal captures from prior test
##   after_test  — disconnects test-side signal subscribers (safety net for tests that
##                 connect lambdas to GameBus signals)
##
## G-15: uses before_test() NOT before_each() — GdUnit4 v6.1.2 only recognises
##        before_test() as the per-test setup hook.
## G-4: lambda captures use Array.append pattern (primitive outer locals are NOT
##       propagated from lambdas).
## G-10: tests that need signal subscribers to FIRE must emit on the REAL GameBus
##        identifier — no GameBusStub.swap_in() for handler-fires tests.
## G-16: sweep test uses Array[Dictionary] for parametric case list.

const _IR_PATH: String = "res://src/foundation/input_router.gd"

## Shared signal capture arrays — populated by lambda subscribers in tests.
## Reset each before_test() to prevent cross-test contamination.
var _state_changed_captures: Array = []
var _action_fired_captures: Array = []

## Lambda callables stored for proper disconnection in after_test.
## Reused across before_test() calls.
var _state_changed_lambda: Callable
var _action_fired_lambda: Callable


func before_test() -> void:
	# G-15 reset — full 8-field clear (6 ADR-0005 §1 fields + _last_matched_action
	# + _grid_battle added story-003)
	InputRouter._state = InputRouter.InputState.OBSERVATION
	InputRouter._active_mode = InputRouter.InputMode.KEYBOARD_MOUSE
	InputRouter._pre_menu_state = InputRouter.InputState.OBSERVATION
	InputRouter._undo_windows.clear()
	InputRouter._input_blocked_reasons.clear()
	InputRouter._bindings.clear()
	InputRouter._last_matched_action = &""
	InputRouter._grid_battle = null

	# Reset signal capture arrays
	_state_changed_captures.clear()
	_action_fired_captures.clear()

	# Disconnect any lambdas left from a prior test (safety net — after_test handles
	# normally, but before_test ensures clean state even if a test skips cleanup)
	if _state_changed_lambda.is_valid():
		if GameBus.input_state_changed.is_connected(_state_changed_lambda):
			GameBus.input_state_changed.disconnect(_state_changed_lambda)
	if _action_fired_lambda.is_valid():
		if GameBus.input_action_fired.is_connected(_action_fired_lambda):
			GameBus.input_action_fired.disconnect(_action_fired_lambda)

	# Build fresh lambdas for this test
	_state_changed_lambda = func(from: int, to: int) -> void:
		_state_changed_captures.append({"from": from, "to": to})
	_action_fired_lambda = func(action: String, context: InputContext) -> void:
		_action_fired_captures.append({"action": action, "context": context})


func after_test() -> void:
	# Disconnect test-side signal subscribers to prevent cross-test interference
	if _state_changed_lambda.is_valid():
		if GameBus.input_state_changed.is_connected(_state_changed_lambda):
			GameBus.input_state_changed.disconnect(_state_changed_lambda)
	if _action_fired_lambda.is_valid():
		if GameBus.input_action_fired.is_connected(_action_fired_lambda):
			GameBus.input_action_fired.disconnect(_action_fired_lambda)


# ── AC-1 structural source assertions ────────────────────────────────────────


## AC-1 (source-scan): _handle_action(action: StringName, ctx: InputContext) -> void
## is declared in input_router.gd. G-22 line-anchored regex skipping # lines.
func test_handle_action_method_exists_with_correct_signature() -> void:
	# Arrange
	var content: String = FileAccess.get_file_as_string(_IR_PATH)
	assert_bool(content.length() > 0).override_failure_message(
		"AC-1 pre-condition: failed to read %s" % _IR_PATH
	).is_true()

	# Assert — _handle_action signature present (line-anchored: not in a comment)
	var has_decl: bool = false
	for line: String in content.split("\n"):
		var stripped: String = line.lstrip(" \t")
		if stripped.begins_with("#"):
			continue  # skip doc-comment + regular comment lines per G-22
		if stripped.begins_with("func _handle_action(action: StringName, ctx: InputContext) -> void:"):
			has_decl = true
			break
	assert_bool(has_decl).override_failure_message(
		"AC-1: input_router.gd must declare 'func _handle_action(action: StringName, ctx: InputContext) -> void:'"
	).is_true()


## AC-1 (source-scan): _handle_event body calls _handle_action(action, ...).
## Verifies the dispatch wiring replaced the story-002 _last_matched_action store.
func test_handle_event_dispatches_via_handle_action() -> void:
	# Arrange
	var content: String = FileAccess.get_file_as_string(_IR_PATH)
	assert_bool(content.length() > 0).override_failure_message(
		"AC-1 pre-condition: failed to read %s" % _IR_PATH
	).is_true()

	# Assert — _handle_action call site present in non-comment code
	var has_call: bool = false
	for line: String in content.split("\n"):
		var stripped: String = line.lstrip(" \t")
		if stripped.begins_with("#"):
			continue
		if stripped.contains("_handle_action(action,"):
			has_call = true
			break
	assert_bool(has_call).override_failure_message(
		"AC-1: _handle_event body must call _handle_action(action, ...) — dispatch wiring missing"
	).is_true()


# ── AC-2 S0 OBSERVATION arm ───────────────────────────────────────────────────


## AC-2: unit_select in S0 with valid unit_id transitions to S1 + emits signal pair.
func test_s0_unit_select_transitions_to_s1() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.OBSERVATION
	GameBus.input_state_changed.connect(_state_changed_lambda)
	var ctx := InputContext.new()
	ctx.target_unit_id = 1

	# Act
	InputRouter._handle_action(&"unit_select", ctx)

	# Assert — state transition
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-2: unit_select with target_unit_id=1 must transition S0→S1"
	).is_equal(int(InputRouter.InputState.UNIT_SELECTED))

	# Assert — input_state_changed emitted with prev=0 (OBSERVATION) new=1 (UNIT_SELECTED)
	assert_int(_state_changed_captures.size()).override_failure_message(
		"AC-2: input_state_changed must fire exactly once on S0→S1 transition"
	).is_equal(1)
	assert_int(_state_changed_captures[0]["from"] as int).override_failure_message(
		"AC-2: input_state_changed prev must be 0 (OBSERVATION)"
	).is_equal(0)
	assert_int(_state_changed_captures[0]["to"] as int).override_failure_message(
		"AC-2: input_state_changed new must be 1 (UNIT_SELECTED)"
	).is_equal(1)


## AC-2 edge: unit_select with target_unit_id=-1 (no unit targeted) must not transition.
func test_s0_unit_select_with_invalid_unit_id_no_transition() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.OBSERVATION
	GameBus.input_state_changed.connect(_state_changed_lambda)
	var ctx := InputContext.new()  # target_unit_id defaults to -1

	# Act
	InputRouter._handle_action(&"unit_select", ctx)

	# Assert — state unchanged
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-2 edge: unit_select with target_unit_id=-1 must NOT transition (invalid context)"
	).is_equal(int(InputRouter.InputState.OBSERVATION))

	# Assert — no signal emitted
	assert_int(_state_changed_captures.size()).override_failure_message(
		"AC-2 edge: no input_state_changed emit for invalid unit_select"
	).is_equal(0)


## AC-2: camera actions in S0 pass through without state change.
func test_s0_camera_actions_pass_through() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.OBSERVATION
	GameBus.input_state_changed.connect(_state_changed_lambda)
	var ctx := InputContext.new()

	# Act — test each camera action
	for cam_action: StringName in [
		&"camera_pan", &"camera_zoom_in", &"camera_zoom_out", &"camera_snap_to_unit"
	]:
		InputRouter._handle_action(cam_action, ctx)

	# Assert — state still OBSERVATION
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-2: camera actions must not change state from S0"
	).is_equal(int(InputRouter.InputState.OBSERVATION))

	# Assert — no signal emitted
	assert_int(_state_changed_captures.size()).override_failure_message(
		"AC-2: no input_state_changed emits for camera pass-through actions"
	).is_equal(0)


# ── AC-3 S1 UNIT_SELECTED arm ─────────────────────────────────────────────────


## AC-3: move_target_select in S1 with valid coord in range transitions to S2.
func test_s1_move_target_select_transitions_to_s2_with_valid_coord() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.UNIT_SELECTED
	var stub := GridBattleStub.new()
	InputRouter.set_grid_battle_for_tests(stub)  # fixture_in_range_coords includes (1,1)
	var ctx := InputContext.new()
	ctx.target_coord = Vector2i(1, 1)

	# Act
	InputRouter._handle_action(&"move_target_select", ctx)

	# Assert — state transition
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-3: move_target_select with in-range coord must transition S1→S2"
	).is_equal(int(InputRouter.InputState.MOVEMENT_PREVIEW))


## AC-3: move_target_select with Vector2i(0,0) IS a valid destination when in
## stub fixture range — verifies the spec-deviation that removed the Vector2i.ZERO
## sentinel guard (grid origins are legitimate playfield cells).
func test_s1_move_target_select_with_zero_coord_in_range_succeeds() -> void:
	# Arrange — populate stub fixture with (0,0) as in-range
	InputRouter._state = InputRouter.InputState.UNIT_SELECTED
	var stub := GridBattleStub.new()
	stub.fixture_in_range_coords = [Vector2i(0, 0)]  # only (0,0) in range
	InputRouter.set_grid_battle_for_tests(stub)
	var ctx := InputContext.new()
	ctx.target_coord = Vector2i.ZERO  # the controversial coord

	# Act
	InputRouter._handle_action(&"move_target_select", ctx)

	# Assert — transition succeeded (Vector2i.ZERO no longer rejected by sentinel guard)
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-3: Vector2i(0,0) IS a valid move destination when in stub range"
		+ " (story-003 deviated from spec's Vector2i.ZERO sentinel guard — grid"
		+ " origins are legitimate cells; range check is the only validity gate)"
	).is_equal(int(InputRouter.InputState.MOVEMENT_PREVIEW))


## AC-3 EC-7: move_target_select with out-of-range coord silently rejected (no transition).
func test_s1_move_target_select_with_out_of_range_coord_no_transition() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.UNIT_SELECTED
	var stub := GridBattleStub.new()
	InputRouter.set_grid_battle_for_tests(stub)  # (99,99) NOT in fixture_in_range_coords
	GameBus.input_state_changed.connect(_state_changed_lambda)
	var ctx := InputContext.new()
	ctx.target_coord = Vector2i(99, 99)

	# Act
	InputRouter._handle_action(&"move_target_select", ctx)

	# Assert — state unchanged
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-3/EC-7: move_target_select with out-of-range coord must NOT transition"
	).is_equal(int(InputRouter.InputState.UNIT_SELECTED))

	# Assert — no signal emitted
	assert_int(_state_changed_captures.size()).override_failure_message(
		"AC-3/EC-7: no input_state_changed emit for out-of-range destination"
	).is_equal(0)


## AC-3: move_cancel in S1 returns to S0.
func test_s1_move_cancel_returns_to_s0() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.UNIT_SELECTED
	var ctx := InputContext.new()

	# Act
	InputRouter._handle_action(&"move_cancel", ctx)

	# Assert
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-3: move_cancel in S1 must transition to S0 (OBSERVATION)"
	).is_equal(int(InputRouter.InputState.OBSERVATION))


## AC-3: end_unit_turn in S1 returns to S0.
func test_s1_end_unit_turn_returns_to_s0() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.UNIT_SELECTED
	var ctx := InputContext.new()

	# Act
	InputRouter._handle_action(&"end_unit_turn", ctx)

	# Assert
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-3: end_unit_turn in S1 must transition to S0 (OBSERVATION)"
	).is_equal(int(InputRouter.InputState.OBSERVATION))


# ── AC-4 S2 MOVEMENT_PREVIEW arm ──────────────────────────────────────────────


## AC-4: move_confirm in S2 calls grid_battle.confirm_move and returns to S0.
func test_s2_move_confirm_calls_grid_battle_and_returns_to_s0() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.MOVEMENT_PREVIEW
	var stub := GridBattleStub.new()
	InputRouter.set_grid_battle_for_tests(stub)
	var ctx := InputContext.new()
	ctx.target_unit_id = 42
	ctx.target_coord = Vector2i(2, 2)

	# Act
	InputRouter._handle_action(&"move_confirm", ctx)

	# Assert — state returned to S0
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-4: move_confirm must transition S2→S0 (OBSERVATION)"
	).is_equal(int(InputRouter.InputState.OBSERVATION))

	# Assert — confirm_move called with correct args
	assert_int(stub.confirm_move_calls.size()).override_failure_message(
		"AC-4: stub.confirm_move must be called exactly once"
	).is_equal(1)
	assert_int(stub.confirm_move_calls[0]["unit_id"] as int).override_failure_message(
		"AC-4: confirm_move unit_id must be 42"
	).is_equal(42)
	assert_bool(stub.confirm_move_calls[0]["coord"] == Vector2i(2, 2)).override_failure_message(
		"AC-4: confirm_move coord must be (2, 2)"
	).is_true()


## AC-4: action_confirm in S2 is aliased to move_confirm — same behavior.
func test_s2_action_confirm_aliased_to_move_confirm() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.MOVEMENT_PREVIEW
	var stub := GridBattleStub.new()
	InputRouter.set_grid_battle_for_tests(stub)
	var ctx := InputContext.new()
	ctx.target_unit_id = 7
	ctx.target_coord = Vector2i(3, 3)

	# Act
	InputRouter._handle_action(&"action_confirm", ctx)

	# Assert — state returned to S0
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-4: action_confirm in S2 must also transition S2→S0 (alias for move_confirm)"
	).is_equal(int(InputRouter.InputState.OBSERVATION))

	# Assert — confirm_move called
	assert_int(stub.confirm_move_calls.size()).override_failure_message(
		"AC-4: action_confirm alias must also call stub.confirm_move"
	).is_equal(1)


## AC-4: move_cancel in S2 returns to S1.
func test_s2_move_cancel_returns_to_s1() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.MOVEMENT_PREVIEW
	var ctx := InputContext.new()

	# Act
	InputRouter._handle_action(&"move_cancel", ctx)

	# Assert
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-4: move_cancel in S2 must transition to S1 (UNIT_SELECTED)"
	).is_equal(int(InputRouter.InputState.UNIT_SELECTED))


# ── AC-5 Signal-pair emit ordering ───────────────────────────────────────────


## AC-5: every valid transition emits input_state_changed exactly once, paired
## with input_action_fired, in the declared ordering (state-changed FIRST).
## Uses ordered capture array via a single combined-index list to verify order.
func test_signal_pair_emitted_on_valid_transition() -> void:
	# Arrange — connect both signal lambdas; use an ordered list to detect ordering
	var ordered_events: Array = []
	var state_lambda: Callable = func(from: int, to: int) -> void:
		ordered_events.append({"type": "state_changed", "from": from, "to": to})
	var action_lambda: Callable = func(action: String, _context: InputContext) -> void:
		ordered_events.append({"type": "action_fired", "action": action})

	GameBus.input_state_changed.connect(state_lambda)
	GameBus.input_action_fired.connect(action_lambda)

	InputRouter._state = InputRouter.InputState.OBSERVATION
	var ctx := InputContext.new()
	ctx.target_unit_id = 1

	# Act — trigger S0 → S1 via unit_select
	InputRouter._handle_action(&"unit_select", ctx)

	# Assert — exactly 2 events (state_changed + action_fired)
	assert_int(ordered_events.size()).override_failure_message(
		"AC-5: exactly 2 events must be captured (input_state_changed + input_action_fired)"
	).is_equal(2)

	# Assert — state_changed FIRST
	assert_str(ordered_events[0]["type"] as String).override_failure_message(
		"AC-5: input_state_changed must fire FIRST (before input_action_fired)"
	).is_equal("state_changed")
	assert_int(ordered_events[0]["from"] as int).is_equal(0)
	assert_int(ordered_events[0]["to"] as int).is_equal(1)

	# Assert — action_fired SECOND
	assert_str(ordered_events[1]["type"] as String).override_failure_message(
		"AC-5: input_action_fired must fire SECOND (after input_state_changed)"
	).is_equal("action_fired")
	assert_str(ordered_events[1]["action"] as String).override_failure_message(
		"AC-5: action_fired must carry the action StringName as String"
	).is_equal("unit_select")

	# Cleanup
	GameBus.input_state_changed.disconnect(state_lambda)
	GameBus.input_action_fired.disconnect(action_lambda)


## AC-5 edge: invalid action in a state (no transition) → 0 emits captured.
func test_signal_pair_not_emitted_on_invalid_action() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.OBSERVATION
	GameBus.input_state_changed.connect(_state_changed_lambda)
	GameBus.input_action_fired.connect(_action_fired_lambda)
	var ctx := InputContext.new()

	# Act — move_confirm is invalid in S0
	InputRouter._handle_action(&"move_confirm", ctx)

	# Assert — no signals emitted
	assert_int(_state_changed_captures.size()).override_failure_message(
		"AC-5 edge: move_confirm in S0 must NOT emit input_state_changed"
	).is_equal(0)
	assert_int(_action_fired_captures.size()).override_failure_message(
		"AC-5 edge: move_confirm in S0 must NOT emit input_action_fired"
	).is_equal(0)


# ── AC-6 Full move flow end-to-end ────────────────────────────────────────────


## AC-6: AC-10 GDD test (move portion) — full S1→S2→S0 flow emits 2 signal pairs.
func test_full_move_flow_s1_to_s2_to_s0_emits_two_signal_pairs() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.UNIT_SELECTED
	var stub := GridBattleStub.new()
	InputRouter.set_grid_battle_for_tests(stub)
	GameBus.input_state_changed.connect(_state_changed_lambda)
	GameBus.input_action_fired.connect(_action_fired_lambda)

	var ctx_move := InputContext.new()
	ctx_move.target_coord = Vector2i(2, 2)
	ctx_move.target_unit_id = 5

	# Act — Step 1: move_target_select S1→S2
	InputRouter._handle_action(&"move_target_select", ctx_move)

	# Assert S2
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-6: move_target_select must reach S2 (MOVEMENT_PREVIEW)"
	).is_equal(int(InputRouter.InputState.MOVEMENT_PREVIEW))

	# Act — Step 2: move_confirm S2→S0
	InputRouter._handle_action(&"move_confirm", ctx_move)

	# Assert S0
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-6: move_confirm must return to S0 (OBSERVATION)"
	).is_equal(int(InputRouter.InputState.OBSERVATION))

	# Assert — 2 state-changed captures (1→2 then 2→0)
	assert_int(_state_changed_captures.size()).override_failure_message(
		"AC-6: exactly 2 input_state_changed signals for S1→S2→S0 flow"
	).is_equal(2)
	assert_int(_state_changed_captures[0]["from"] as int).is_equal(1)  # S1
	assert_int(_state_changed_captures[0]["to"] as int).is_equal(2)    # S2
	assert_int(_state_changed_captures[1]["from"] as int).is_equal(2)  # S2
	assert_int(_state_changed_captures[1]["to"] as int).is_equal(0)    # S0

	# Assert — 2 action-fired captures
	assert_int(_action_fired_captures.size()).override_failure_message(
		"AC-6: exactly 2 input_action_fired signals for S1→S2→S0 flow"
	).is_equal(2)

	# Assert — stub.confirm_move called once
	assert_int(stub.confirm_move_calls.size()).override_failure_message(
		"AC-6: stub.confirm_move must be called exactly once (in S2 confirm arm)"
	).is_equal(1)


# ── AC-7 Re-entrancy contract-locking test ────────────────────────────────────


## AC-7: subscriber connected WITHOUT CONNECT_DEFERRED that synchronously re-enters
## _handle_action mid-dispatch. This test locks the contract — behavior must be
## well-defined and deterministic. Per ADR-0001 §5 deferred-connect mandate,
## PRODUCTION subscribers use CONNECT_DEFERRED; this test documents the re-entrancy
## behavior for the exceptional synchronous case.
func test_reentrancy_synchronous_subscriber_well_defined() -> void:
	# Arrange — inject a stub so S0→S1 can transition
	var stub := GridBattleStub.new()
	InputRouter.set_grid_battle_for_tests(stub)
	InputRouter._state = InputRouter.InputState.OBSERVATION

	var captures: Array = []
	var reentrant_lambda: Callable = func(from: int, to: int) -> void:
		captures.append({"from": from, "to": to})
		if captures.size() == 1:
			# Synchronously re-enter (NOT CONNECT_DEFERRED) — this is the hazard case
			# Per ADR-0001 §5, production code NEVER does this; this test documents
			# the contract-observable behavior for the boundary condition.
			var ctx2 := InputContext.new()
			InputRouter._handle_action(&"move_cancel", ctx2)  # move_cancel in S1→S0

	GameBus.input_state_changed.connect(reentrant_lambda)

	var ctx1 := InputContext.new()
	ctx1.target_unit_id = 1

	# Act — trigger first transition S0→S1; subscriber synchronously re-enters
	InputRouter._handle_action(&"unit_select", ctx1)

	# Assert — exactly 2 captures: first S0→S1 transition + re-entrant S1→S0.
	# Godot 4.6 GDScript executes signal callbacks synchronously — both transitions
	# complete before this line is reached. Sequential execution is the AC-7 spec
	# behavioral option (a) ("both events process successfully sequentially").
	# Production safety: ADR-0001 §5 deferred-connect mandate prevents this scenario
	# in production code (downstream-consumer obligation, not InputRouter).
	#
	# Locked at 2 (not >= 1) per /code-review pass: a regression that silently
	# dropped the re-entrant second event would otherwise pass undetected.
	assert_int(captures.size()).override_failure_message(
		("AC-7: re-entrant subscriber must complete BOTH transitions sequentially"
		+ " (first S0→S1 + re-entrant S1→S0). Observed %d captures.")
		% captures.size()
	).is_equal(2)

	# Verify the actual sequence — first capture is S0→S1, second is S1→S0
	assert_int(captures[0]["from"] as int).override_failure_message(
		"AC-7: capture[0].from must be 0 (OBSERVATION)"
	).is_equal(0)
	assert_int(captures[0]["to"] as int).override_failure_message(
		"AC-7: capture[0].to must be 1 (UNIT_SELECTED)"
	).is_equal(1)
	assert_int(captures[1]["from"] as int).override_failure_message(
		"AC-7: capture[1].from must be 1 (UNIT_SELECTED) — re-entrant transition"
	).is_equal(1)
	assert_int(captures[1]["to"] as int).override_failure_message(
		"AC-7: capture[1].to must be 0 (OBSERVATION) — move_cancel back to S0"
	).is_equal(0)

	# Cleanup
	GameBus.input_state_changed.disconnect(reentrant_lambda)


# ── AC-8 All-(state, action) sweep no-crash ───────────────────────────────────


## AC-8: 7 states × 22 actions = 154 combinations — none must crash.
## Per G-16, uses Array[Dictionary] for the parametric sweep.
## No signal captures in this test — sweep is about stability, not emit counting.
func test_all_state_action_combinations_no_crash() -> void:
	# Arrange — inject stub so range checks resolve (permissive-null or in-range)
	var stub := GridBattleStub.new()
	InputRouter.set_grid_battle_for_tests(stub)

	# Build default ctx with a non-zero coord and valid unit_id so some
	# transitions CAN fire (AC-8 verifies "no crash", not "no transition")
	var ctx := InputContext.new()
	ctx.target_unit_id = 1
	ctx.target_coord = Vector2i(1, 1)  # in stub's fixture_in_range_coords

	# Sweep all 7 state ints × 22 actions
	for state_int: int in range(7):
		for category: StringName in InputRouter.ACTIONS_BY_CATEGORY.keys():
			for action: StringName in InputRouter.ACTIONS_BY_CATEGORY[category]:
				# Reset state each iteration to the target state
				InputRouter._state = state_int as InputRouter.InputState
				# MUST NOT crash — any transition is acceptable
				InputRouter._handle_action(action, ctx)

	# If we reach here, no crash occurred across all 154 combinations
	assert_bool(true).override_failure_message(
		"AC-8: sweep across all 7×22=154 (state, action) combinations must not crash"
	).is_true()


# ── Pass-through and no-op edge tests (per /code-review qa-tester gaps) ───────


## S1 action_confirm explicitly no-ops (coord binding deferred to story-008-009).
## Sentinel test prevents accidental story-008 wiring from silently transitioning.
func test_s1_action_confirm_is_noop() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.UNIT_SELECTED
	GameBus.input_state_changed.connect(_state_changed_lambda)
	var ctx := InputContext.new()

	# Act
	InputRouter._handle_action(&"action_confirm", ctx)

	# Assert — state retained
	assert_int(int(InputRouter._state)).override_failure_message(
		"S1 action_confirm must no-op (story-008-009 wires coord binding); state must remain UNIT_SELECTED"
	).is_equal(int(InputRouter.InputState.UNIT_SELECTED))

	# Assert — no signal emitted (no transition occurred)
	assert_int(_state_changed_captures.size()).override_failure_message(
		"S1 action_confirm must NOT emit input_state_changed (no transition)"
	).is_equal(0)


## S1 open_unit_info pass-through retains S1 (no transition).
func test_s1_open_unit_info_no_state_change() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.UNIT_SELECTED
	GameBus.input_state_changed.connect(_state_changed_lambda)
	var ctx := InputContext.new()

	# Act
	InputRouter._handle_action(&"open_unit_info", ctx)

	# Assert — state retained
	assert_int(int(InputRouter._state)).override_failure_message(
		"S1 open_unit_info must NOT change state (read-only inspection)"
	).is_equal(int(InputRouter.InputState.UNIT_SELECTED))
	assert_int(_state_changed_captures.size()).is_equal(0)


## S2 move_confirm with no Grid Battle stub injected still transitions S2→S0.
## Verifies the permissive-null path: production scenarios where _grid_battle is
## not yet wired (pre-Grid-Battle-ADR) must still allow S2→S0 transitions to
## happen — the actual move-application no-ops harmlessly until the stub lands.
func test_s2_move_confirm_with_no_stub_still_transitions_to_s0() -> void:
	# Arrange — explicitly NO stub injection (_grid_battle == null)
	InputRouter._state = InputRouter.InputState.MOVEMENT_PREVIEW
	InputRouter._grid_battle = null
	var ctx := InputContext.new()
	ctx.target_unit_id = 1
	ctx.target_coord = Vector2i(1, 1)

	# Act
	InputRouter._handle_action(&"move_confirm", ctx)

	# Assert — transition completed despite null stub
	assert_int(int(InputRouter._state)).override_failure_message(
		"S2 move_confirm must transition S2→S0 even when _grid_battle is null"
		+ " (permissive-null production path; confirm_move call no-ops harmlessly)"
	).is_equal(int(InputRouter.InputState.OBSERVATION))


# ── AC-9 GridBattleStub structural correctness ───────────────────────────────


## AC-9: GridBattleStub instantiates correctly and is_tile_in_move_range works.
func test_grid_battle_stub_is_in_range_returns_true_for_fixture_coords() -> void:
	# Arrange
	var stub := GridBattleStub.new()

	# Assert — fixture coords return true
	assert_bool(stub.is_tile_in_move_range(Vector2i(1, 1))).override_failure_message(
		"AC-9: GridBattleStub.is_tile_in_move_range(1,1) must return true (in fixture)"
	).is_true()
	assert_bool(stub.is_tile_in_move_range(Vector2i(2, 2))).override_failure_message(
		"AC-9: GridBattleStub.is_tile_in_move_range(2,2) must return true (in fixture)"
	).is_true()
	assert_bool(stub.is_tile_in_move_range(Vector2i(3, 3))).override_failure_message(
		"AC-9: GridBattleStub.is_tile_in_move_range(3,3) must return true (in fixture)"
	).is_true()

	# Assert — non-fixture coords return false
	assert_bool(stub.is_tile_in_move_range(Vector2i(99, 99))).override_failure_message(
		"AC-9: GridBattleStub.is_tile_in_move_range(99,99) must return false (not in fixture)"
	).is_false()
	assert_bool(stub.is_tile_in_move_range(Vector2i(0, 0))).override_failure_message(
		"AC-9: GridBattleStub.is_tile_in_move_range(0,0) must return false (not in fixture)"
	).is_false()


## AC-9: GridBattleStub.confirm_move records call with correct unit_id + coord.
func test_grid_battle_stub_confirm_move_records_call() -> void:
	# Arrange
	var stub := GridBattleStub.new()
	assert_int(stub.confirm_move_calls.size()).is_equal(0)

	# Act
	stub.confirm_move(42, Vector2i(1, 1))

	# Assert — 1 recorded call
	assert_int(stub.confirm_move_calls.size()).override_failure_message(
		"AC-9: confirm_move must record exactly 1 call"
	).is_equal(1)

	# Assert — correct params
	assert_int(stub.confirm_move_calls[0]["unit_id"] as int).override_failure_message(
		"AC-9: confirm_move_calls[0].unit_id must be 42"
	).is_equal(42)
	assert_bool(stub.confirm_move_calls[0]["coord"] == Vector2i(1, 1)).override_failure_message(
		"AC-9: confirm_move_calls[0].coord must be Vector2i(1, 1)"
	).is_true()


# ── AC-11 Stub injection seam structural assertion ────────────────────────────


## AC-11 (source-scan): set_grid_battle_for_tests(stub: Variant) -> void
## is declared in input_router.gd. G-22 line-anchored check skipping # lines.
func test_set_grid_battle_for_tests_seam_present() -> void:
	# Arrange
	var content: String = FileAccess.get_file_as_string(_IR_PATH)
	assert_bool(content.length() > 0).override_failure_message(
		"AC-11 pre-condition: failed to read %s" % _IR_PATH
	).is_true()

	# Assert — set_grid_battle_for_tests signature present (line-anchored)
	var has_decl: bool = false
	for line: String in content.split("\n"):
		var stripped: String = line.lstrip(" \t")
		if stripped.begins_with("#"):
			continue  # skip comment lines per G-22
		if stripped.begins_with("func set_grid_battle_for_tests(stub: Variant) -> void:"):
			has_decl = true
			break
	assert_bool(has_decl).override_failure_message(
		"AC-11: input_router.gd must declare 'func set_grid_battle_for_tests(stub: Variant) -> void:'"
	).is_true()

	# Assert — body sets _grid_battle = stub (non-comment line)
	var has_assignment: bool = false
	for line: String in content.split("\n"):
		var stripped: String = line.lstrip(" \t")
		if stripped.begins_with("#"):
			continue
		if stripped.contains("_grid_battle = stub"):
			has_assignment = true
			break
	assert_bool(has_assignment).override_failure_message(
		"AC-11: set_grid_battle_for_tests body must assign _grid_battle = stub"
	).is_true()
