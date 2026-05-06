extends GdUnitTestSuite

## input_router_fsm_attack_st2_test.gd
## Story 004 tests — S3 ATTACK_TARGET_SELECT + S4 ATTACK_CONFIRM + ST-2 demotion
## + AC-11 end-player-turn 2-beat safety gate.
## Covers AC-1 through AC-11 per story QA Test Cases.
##
## Pattern mirrors input_router_fsm_core_test.gd (story-003):
##   - G-15: before_test() not before_each()
##   - G-4: lambda captures via Array.append (not primitive reassignment)
##   - G-10: emit on real GameBus autoload (no GameBusStub.swap_in)
##   - G-16: sweep tests use Array[Dictionary] for typed parametric lists
##   - G-22: structural source-scan assertions use line-anchored regex skipping #
##
## LIFECYCLE:
##   before_test — resets all 10 InputRouter fields (8 from story-003 +
##                 _pending_end_phase + _did_visible_work) + signal lambdas
##   after_test  — disconnects test-side signal lambdas (safety net)

const _IR_PATH: String = "res://src/foundation/input_router.gd"

## Shared signal capture arrays — populated by lambda subscribers.
## Reset each before_test() to prevent cross-test contamination.
var _state_changed_captures: Array = []
var _action_fired_captures: Array = []

## Lambda callables stored for proper disconnection in after_test.
var _state_changed_lambda: Callable
var _action_fired_lambda: Callable


func before_test() -> void:
	# G-15 reset — full 10-field clear (6 ADR-0005 §1 fields + _last_matched_action
	# + _grid_battle + _pending_end_phase + _did_visible_work added story-003/004)
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

	# Reset capture arrays
	_state_changed_captures.clear()
	_action_fired_captures.clear()

	# Disconnect any lingering lambdas from prior test
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
	if _state_changed_lambda.is_valid():
		if GameBus.input_state_changed.is_connected(_state_changed_lambda):
			GameBus.input_state_changed.disconnect(_state_changed_lambda)
	if _action_fired_lambda.is_valid():
		if GameBus.input_action_fired.is_connected(_action_fired_lambda):
			GameBus.input_action_fired.disconnect(_action_fired_lambda)


# ── AC-1 S1 → S3 ATTACK_TARGET_SELECT transition ────────────────────────────


## AC-1: attack_target_select in S1 with in-range coord transitions to S3.
func test_s1_attack_target_select_with_in_range_coord_transitions_to_s3() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.UNIT_SELECTED
	var stub := GridBattleStub.new()  # fixture_in_attack_coords includes (4,4) + (5,5)
	InputRouter.set_grid_battle_for_tests(stub)
	var ctx := InputContext.new()
	ctx.target_coord = Vector2i(4, 4)

	# Act
	InputRouter._handle_action(&"attack_target_select", ctx)

	# Assert — state transitioned to S3
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-1: attack_target_select with in-range coord (4,4) must transition S1→S3"
	).is_equal(int(InputRouter.InputState.ATTACK_TARGET_SELECT))


## AC-1 EC-7: attack_target_select with out-of-range coord is silently rejected.
func test_s1_attack_target_select_with_out_of_range_coord_no_transition() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.UNIT_SELECTED
	var stub := GridBattleStub.new()  # (99,99) NOT in fixture_in_attack_coords
	InputRouter.set_grid_battle_for_tests(stub)
	GameBus.input_state_changed.connect(_state_changed_lambda)
	var ctx := InputContext.new()
	ctx.target_coord = Vector2i(99, 99)

	# Act
	InputRouter._handle_action(&"attack_target_select", ctx)

	# Assert — state unchanged
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-1/EC-7: attack_target_select with out-of-range coord must NOT transition"
	).is_equal(int(InputRouter.InputState.UNIT_SELECTED))

	# Assert — no signal emitted
	assert_int(_state_changed_captures.size()).override_failure_message(
		"AC-1/EC-7: no input_state_changed emit for out-of-range attack target"
	).is_equal(0)


# ── AC-2 S3 ATTACK_TARGET_SELECT arm transitions ─────────────────────────────


## AC-2: attack_confirm in S3 transitions to S4.
func test_s3_attack_confirm_transitions_to_s4() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.ATTACK_TARGET_SELECT
	var ctx := InputContext.new()

	# Act
	InputRouter._handle_action(&"attack_confirm", ctx)

	# Assert
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-2: attack_confirm in S3 must transition to S4 (ATTACK_CONFIRM)"
	).is_equal(int(InputRouter.InputState.ATTACK_CONFIRM))


## AC-2: action_confirm in S3 is aliased to attack_confirm (CR-3a).
func test_s3_action_confirm_aliased_to_attack_confirm() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.ATTACK_TARGET_SELECT
	var ctx := InputContext.new()

	# Act
	InputRouter._handle_action(&"action_confirm", ctx)

	# Assert
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-2: action_confirm in S3 must also transition to S4 (CR-3a alias)"
	).is_equal(int(InputRouter.InputState.ATTACK_CONFIRM))


## AC-2: attack_cancel in S3 returns to S1.
func test_s3_attack_cancel_returns_to_s1() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.ATTACK_TARGET_SELECT
	var ctx := InputContext.new()

	# Act
	InputRouter._handle_action(&"attack_cancel", ctx)

	# Assert
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-2: attack_cancel in S3 must return to S1 (UNIT_SELECTED)"
	).is_equal(int(InputRouter.InputState.UNIT_SELECTED))


## AC-2: open_game_menu in S3 sets _pre_menu_state = S3 and transitions to S6.
func test_s3_open_game_menu_sets_pre_menu_state_and_transitions_to_s6() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.ATTACK_TARGET_SELECT
	var ctx := InputContext.new()

	# Act
	InputRouter._handle_action(&"open_game_menu", ctx)

	# Assert — state is S6 MENU_OPEN
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-2: open_game_menu in S3 must transition to S6 (MENU_OPEN)"
	).is_equal(int(InputRouter.InputState.MENU_OPEN))

	# Assert — _pre_menu_state recorded as S3 for ST-2 restore path
	assert_int(int(InputRouter._pre_menu_state)).override_failure_message(
		"AC-2: _pre_menu_state must be S3 (ATTACK_TARGET_SELECT) after S3→S6 transition"
	).is_equal(int(InputRouter.InputState.ATTACK_TARGET_SELECT))


# ── AC-8 S3 re-targeting (emit without state change) ─────────────────────────


## AC-8: re-targeting in S3 emits input_action_fired without input_state_changed.
## State remains S3; ctx-update conveyed via action_fired only.
func test_s3_retargeting_emits_action_fired_without_state_changed() -> void:
	# Arrange — set up in S3 with stub
	InputRouter._state = InputRouter.InputState.ATTACK_TARGET_SELECT
	var stub := GridBattleStub.new()
	InputRouter.set_grid_battle_for_tests(stub)

	# Connect both signal lambdas
	GameBus.input_state_changed.connect(_state_changed_lambda)
	GameBus.input_action_fired.connect(_action_fired_lambda)

	var ctx := InputContext.new()
	ctx.target_coord = Vector2i(5, 5)  # (5,5) is in stub's fixture_in_attack_coords

	# Act — re-target to a different valid attack-range coord
	InputRouter._handle_action(&"attack_target_select", ctx)

	# Assert — state still S3 (no state change)
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-8: re-targeting attack_target_select in S3 must retain S3 state"
	).is_equal(int(InputRouter.InputState.ATTACK_TARGET_SELECT))

	# Assert — no state_changed emit
	assert_int(_state_changed_captures.size()).override_failure_message(
		"AC-8: no input_state_changed must fire for S3 re-targeting (no state transition)"
	).is_equal(0)

	# Assert — action_fired DID emit (with the new ctx)
	assert_int(_action_fired_captures.size()).override_failure_message(
		"AC-8: input_action_fired must fire for S3 re-targeting (ctx-update notification)"
	).is_equal(1)

	# Assert — emitted ctx is the new one
	assert_object(_action_fired_captures[0]["context"] as InputContext).override_failure_message(
		"AC-8: emitted ctx must be the re-targeting ctx (with coord (5,5))"
	).is_same(ctx)


## AC-8 EC: re-targeting to out-of-range coord in S3 silently rejected — no emits.
func test_s3_retargeting_to_out_of_range_coord_no_emit() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.ATTACK_TARGET_SELECT
	var stub := GridBattleStub.new()
	InputRouter.set_grid_battle_for_tests(stub)

	GameBus.input_state_changed.connect(_state_changed_lambda)
	GameBus.input_action_fired.connect(_action_fired_lambda)

	var ctx := InputContext.new()
	ctx.target_coord = Vector2i(99, 99)  # NOT in fixture_in_attack_coords

	# Act
	InputRouter._handle_action(&"attack_target_select", ctx)

	# Assert — state still S3
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-8/EC: out-of-range re-target in S3 must retain S3 state"
	).is_equal(int(InputRouter.InputState.ATTACK_TARGET_SELECT))

	# Assert — NO emits at all (silent rejection)
	assert_int(_state_changed_captures.size()).override_failure_message(
		"AC-8/EC: no input_state_changed for out-of-range re-target"
	).is_equal(0)
	assert_int(_action_fired_captures.size()).override_failure_message(
		"AC-8/EC: no input_action_fired for out-of-range re-target (silent rejection)"
	).is_equal(0)


# ── AC-3 S4 ATTACK_CONFIRM arm ────────────────────────────────────────────────


## AC-3: attack_confirm in S4 calls grid_battle.confirm_attack and returns to S0.
func test_s4_attack_confirm_calls_grid_battle_and_returns_to_s0() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.ATTACK_CONFIRM
	var stub := GridBattleStub.new()
	InputRouter.set_grid_battle_for_tests(stub)
	var ctx := InputContext.new()
	ctx.target_unit_id = 1
	ctx.target_coord = Vector2i(4, 4)

	# Act
	InputRouter._handle_action(&"attack_confirm", ctx)

	# Assert — state returned to S0
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-3: attack_confirm in S4 must transition to S0 (OBSERVATION)"
	).is_equal(int(InputRouter.InputState.OBSERVATION))

	# Assert — confirm_attack called with correct args
	assert_int(stub.confirm_attack_calls.size()).override_failure_message(
		"AC-3: stub.confirm_attack must be called exactly once"
	).is_equal(1)
	assert_int(stub.confirm_attack_calls[0]["unit_id"] as int).override_failure_message(
		"AC-3: confirm_attack unit_id must be 1"
	).is_equal(1)
	assert_bool(stub.confirm_attack_calls[0]["coord"] == Vector2i(4, 4)).override_failure_message(
		"AC-3: confirm_attack coord must be (4, 4)"
	).is_true()


## AC-3: S4 attack_confirm with no Grid Battle stub still transitions S2→S0.
## Mirrors story-003's permissive-null pattern (test_s2_move_confirm_with_no_stub).
## Verifies the production scenario where _grid_battle is unset before the Grid
## Battle ADR ships at story-014.
func test_s4_attack_confirm_with_no_stub_still_transitions_to_s0() -> void:
	# Arrange — explicitly NO stub injection
	InputRouter._state = InputRouter.InputState.ATTACK_CONFIRM
	InputRouter._grid_battle = null
	var ctx := InputContext.new()
	ctx.target_unit_id = 1
	ctx.target_coord = Vector2i(4, 4)

	# Act
	InputRouter._handle_action(&"attack_confirm", ctx)

	# Assert — transition completed despite null stub
	assert_int(int(InputRouter._state)).override_failure_message(
		"S4 attack_confirm must transition S4→S0 even when _grid_battle is null"
	).is_equal(int(InputRouter.InputState.OBSERVATION))


## AC-3: S4 attack_confirm with target_unit_id=-1 silently rejects (mirrors S0
## unit_select guard). Locks the I-2 fix from /code-review pass.
func test_s4_attack_confirm_with_invalid_unit_id_no_transition() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.ATTACK_CONFIRM
	var stub := GridBattleStub.new()
	InputRouter.set_grid_battle_for_tests(stub)
	var ctx := InputContext.new()  # target_unit_id defaults to -1

	# Act
	InputRouter._handle_action(&"attack_confirm", ctx)

	# Assert — state unchanged
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-3: attack_confirm with target_unit_id=-1 must NOT transition (invalid context)"
	).is_equal(int(InputRouter.InputState.ATTACK_CONFIRM))

	# Assert — confirm_attack stub NOT called
	assert_int(stub.confirm_attack_calls.size()).override_failure_message(
		"AC-3: confirm_attack must not be called for invalid unit_id"
	).is_equal(0)


## AC-2: S3 action_cancel falls through to silent no-op (no state change, no emit).
## Locks the documented "all other actions in S3: silent no-op" contract per AC-8
## invalid-action discipline. Prevents accidental future addition of an action_cancel
## arm that fires unintended side effects.
func test_s3_action_cancel_is_silent_no_op() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.ATTACK_TARGET_SELECT
	GameBus.input_state_changed.connect(_state_changed_lambda)
	GameBus.input_action_fired.connect(_action_fired_lambda)
	var ctx := InputContext.new()

	# Act
	InputRouter._handle_action(&"action_cancel", ctx)

	# Assert — state retained
	assert_int(int(InputRouter._state)).override_failure_message(
		"S3 action_cancel must NOT change state (silent no-op)"
	).is_equal(int(InputRouter.InputState.ATTACK_TARGET_SELECT))

	# Assert — no signals emitted
	assert_int(_state_changed_captures.size()).override_failure_message(
		"S3 action_cancel must NOT emit input_state_changed"
	).is_equal(0)
	assert_int(_action_fired_captures.size()).override_failure_message(
		"S3 action_cancel must NOT emit input_action_fired"
	).is_equal(0)


## AC-3 edge: attack_cancel in S4 returns to S3.
func test_s4_attack_cancel_returns_to_s3() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.ATTACK_CONFIRM
	var ctx := InputContext.new()

	# Act
	InputRouter._handle_action(&"attack_cancel", ctx)

	# Assert
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-3 edge: attack_cancel in S4 must return to S3 (ATTACK_TARGET_SELECT)"
	).is_equal(int(InputRouter.InputState.ATTACK_TARGET_SELECT))


# ── AC-4 + AC-7 ST-2 demotion helper ─────────────────────────────────────────


## AC-4: _apply_st2_demotion demotes S2 (MOVEMENT_PREVIEW) to S1 (UNIT_SELECTED).
func test_apply_st2_demotion_demotes_s2_to_s1() -> void:
	var result: InputRouter.InputState = InputRouter._apply_st2_demotion(
		InputRouter.InputState.MOVEMENT_PREVIEW
	)
	assert_int(int(result)).override_failure_message(
		"AC-4: _apply_st2_demotion(S2) must return S1 (UNIT_SELECTED)"
	).is_equal(int(InputRouter.InputState.UNIT_SELECTED))


## AC-4: _apply_st2_demotion demotes S4 (ATTACK_CONFIRM) to S1 (UNIT_SELECTED).
func test_apply_st2_demotion_demotes_s4_to_s1() -> void:
	var result: InputRouter.InputState = InputRouter._apply_st2_demotion(
		InputRouter.InputState.ATTACK_CONFIRM
	)
	assert_int(int(result)).override_failure_message(
		"AC-4: _apply_st2_demotion(S4) must return S1 (UNIT_SELECTED)"
	).is_equal(int(InputRouter.InputState.UNIT_SELECTED))


## AC-4 + AC-7: ST-2 demotion sweep — 7 states; S2 and S4 demote to S1; all others pass through.
## G-16: uses Array[Dictionary] for typed parametric case list.
func test_apply_st2_demotion_passes_through_non_pending_states() -> void:
	# Arrange — 7-case sweep (AC-7 GDD requirement)
	var cases: Array[Dictionary] = [
		{"state": InputRouter.InputState.OBSERVATION,         "expected": InputRouter.InputState.OBSERVATION},
		{"state": InputRouter.InputState.UNIT_SELECTED,       "expected": InputRouter.InputState.UNIT_SELECTED},
		{"state": InputRouter.InputState.MOVEMENT_PREVIEW,    "expected": InputRouter.InputState.UNIT_SELECTED},
		{"state": InputRouter.InputState.ATTACK_TARGET_SELECT,"expected": InputRouter.InputState.ATTACK_TARGET_SELECT},
		{"state": InputRouter.InputState.ATTACK_CONFIRM,      "expected": InputRouter.InputState.UNIT_SELECTED},
		{"state": InputRouter.InputState.INPUT_BLOCKED,       "expected": InputRouter.InputState.INPUT_BLOCKED},
		{"state": InputRouter.InputState.MENU_OPEN,           "expected": InputRouter.InputState.MENU_OPEN},
	]

	# Capture _state BEFORE the sweep — purity invariant verification (qa-tester gap 1)
	var state_before_sweep: int = int(InputRouter._state)

	for case: Dictionary in cases:
		var input_state: InputRouter.InputState = case["state"] as InputRouter.InputState
		var expected_state: InputRouter.InputState = case["expected"] as InputRouter.InputState
		var result: InputRouter.InputState = InputRouter._apply_st2_demotion(input_state)
		assert_int(int(result)).override_failure_message(
			("AC-7: _apply_st2_demotion(%d) must return %d but returned %d")
			% [int(input_state), int(expected_state), int(result)]
		).is_equal(int(expected_state))

	# Assert — purity invariant: _state must not be modified by the helper.
	# (qa-tester gap 1; gdscript-specialist M-1) Doc comment claims pure; this
	# locks it as a regression net for story-007's S6 close-path wiring.
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-4 purity: _apply_st2_demotion must NOT modify InputRouter._state"
	).is_equal(state_before_sweep)


# ── AC-5 Full attack flow end-to-end ─────────────────────────────────────────


## AC-5: full attack flow — S1 → S3 → S4 → S0 emits 3 signal pairs (6 total).
## Per ADR-0020 §1 Phase 4: state_changed FIRST + action_fired SECOND for each
## transition. Test asserts both capture counts AND the action names per emit.
func test_full_attack_flow_s1_to_s3_to_s4_to_s0_emits_three_pairs() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.UNIT_SELECTED
	var stub := GridBattleStub.new()
	InputRouter.set_grid_battle_for_tests(stub)
	GameBus.input_state_changed.connect(_state_changed_lambda)
	GameBus.input_action_fired.connect(_action_fired_lambda)

	var ctx := InputContext.new()
	ctx.target_coord = Vector2i(4, 4)  # in stub's fixture_in_attack_coords
	ctx.target_unit_id = 1

	# Act — Step 1: attack_target_select S1 → S3
	InputRouter._handle_action(&"attack_target_select", ctx)

	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-5 step-1: attack_target_select must reach S3"
	).is_equal(int(InputRouter.InputState.ATTACK_TARGET_SELECT))

	# Act — Step 2: attack_confirm S3 → S4
	InputRouter._handle_action(&"attack_confirm", ctx)

	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-5 step-2: attack_confirm must reach S4"
	).is_equal(int(InputRouter.InputState.ATTACK_CONFIRM))

	# Act — Step 3: attack_confirm S4 → S0
	InputRouter._handle_action(&"attack_confirm", ctx)

	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-5 step-3: second attack_confirm must return to S0"
	).is_equal(int(InputRouter.InputState.OBSERVATION))

	# Assert — 3 state_changed captures (1→3, 3→4, 4→0)
	assert_int(_state_changed_captures.size()).override_failure_message(
		"AC-5: exactly 3 input_state_changed signals for S1→S3→S4→S0 flow"
	).is_equal(3)
	assert_int(_state_changed_captures[0]["from"] as int).is_equal(1)  # S1
	assert_int(_state_changed_captures[0]["to"] as int).is_equal(3)    # S3
	assert_int(_state_changed_captures[1]["from"] as int).is_equal(3)  # S3
	assert_int(_state_changed_captures[1]["to"] as int).is_equal(4)    # S4
	assert_int(_state_changed_captures[2]["from"] as int).is_equal(4)  # S4
	assert_int(_state_changed_captures[2]["to"] as int).is_equal(0)    # S0

	# Assert — 3 action_fired captures with correct action names per transition
	assert_int(_action_fired_captures.size()).override_failure_message(
		"AC-5: exactly 3 input_action_fired signals for 3-transition attack flow"
	).is_equal(3)
	assert_str(_action_fired_captures[0]["action"] as String).override_failure_message(
		"AC-5: capture[0] action must be attack_target_select (S1→S3 trigger)"
	).is_equal("attack_target_select")
	assert_str(_action_fired_captures[1]["action"] as String).override_failure_message(
		"AC-5: capture[1] action must be attack_confirm (S3→S4 trigger)"
	).is_equal("attack_confirm")
	assert_str(_action_fired_captures[2]["action"] as String).override_failure_message(
		"AC-5: capture[2] action must be attack_confirm (S4→S0 trigger)"
	).is_equal("attack_confirm")


# ── AC-6 End-player-turn 2-beat confirmation (AC-11) ─────────────────────────


## AC-6 first beat: end_player_turn arms _pending_end_phase without state change.
func test_end_player_turn_arms_pending_flag_no_state_change() -> void:
	# Arrange
	InputRouter._state = InputRouter.InputState.OBSERVATION
	InputRouter._pending_end_phase = false
	GameBus.input_state_changed.connect(_state_changed_lambda)
	GameBus.input_action_fired.connect(_action_fired_lambda)
	var ctx := InputContext.new()

	# Act
	InputRouter._handle_action(&"end_player_turn", ctx)

	# Assert — flag armed
	assert_bool(InputRouter._pending_end_phase).override_failure_message(
		"AC-6 first-beat: end_player_turn must set _pending_end_phase = true"
	).is_true()

	# Assert — state unchanged (no transition)
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-6 first-beat: end_player_turn must NOT change state (stays S0)"
	).is_equal(int(InputRouter.InputState.OBSERVATION))

	# Assert — state_changed NOT emitted (no state transition)
	assert_int(_state_changed_captures.size()).override_failure_message(
		"AC-6 first-beat: no input_state_changed for end_player_turn (no state change)"
	).is_equal(0)

	# Assert — action_fired IS emitted (visible work — flag armed)
	assert_int(_action_fired_captures.size()).override_failure_message(
		"AC-6 first-beat: input_action_fired must emit once for end_player_turn"
	).is_equal(1)


## AC-6 second beat: end_phase_confirm when armed resets flag and emits action_fired.
func test_end_phase_confirm_when_armed_resets_flag_and_emits() -> void:
	# Arrange — arm the gate first
	InputRouter._state = InputRouter.InputState.OBSERVATION
	InputRouter._pending_end_phase = true
	GameBus.input_state_changed.connect(_state_changed_lambda)
	GameBus.input_action_fired.connect(_action_fired_lambda)
	var ctx := InputContext.new()

	# Act
	InputRouter._handle_action(&"end_phase_confirm", ctx)

	# Assert — flag reset
	assert_bool(InputRouter._pending_end_phase).override_failure_message(
		"AC-6 second-beat: end_phase_confirm must reset _pending_end_phase to false"
	).is_false()

	# Assert — action_fired emitted (Battle HUD executes phase-end)
	assert_int(_action_fired_captures.size()).override_failure_message(
		"AC-6 second-beat: input_action_fired must emit once for armed end_phase_confirm"
	).is_equal(1)

	# Assert — state_changed NOT emitted (no state transition)
	assert_int(_state_changed_captures.size()).override_failure_message(
		"AC-6 second-beat: no input_state_changed for end_phase_confirm (no state change)"
	).is_equal(0)


## AC-6 EC: end_phase_confirm when unarmed is a silent no-op — no emits.
func test_end_phase_confirm_when_unarmed_silent_no_emit() -> void:
	# Arrange — gate is NOT armed
	InputRouter._state = InputRouter.InputState.OBSERVATION
	InputRouter._pending_end_phase = false
	GameBus.input_state_changed.connect(_state_changed_lambda)
	GameBus.input_action_fired.connect(_action_fired_lambda)
	var ctx := InputContext.new()

	# Act
	InputRouter._handle_action(&"end_phase_confirm", ctx)

	# Assert — no emits
	assert_int(_state_changed_captures.size()).override_failure_message(
		"AC-6/EC: unarmed end_phase_confirm must NOT emit input_state_changed"
	).is_equal(0)
	assert_int(_action_fired_captures.size()).override_failure_message(
		"AC-6/EC: unarmed end_phase_confirm must NOT emit input_action_fired"
	).is_equal(0)


## AC-6 EC: action_cancel resets armed pending flag silently (no emit).
func test_action_cancel_resets_armed_pending_flag_silently() -> void:
	# Arrange — arm the gate
	InputRouter._state = InputRouter.InputState.OBSERVATION
	InputRouter._pending_end_phase = true
	GameBus.input_state_changed.connect(_state_changed_lambda)
	GameBus.input_action_fired.connect(_action_fired_lambda)
	var ctx := InputContext.new()

	# Act
	InputRouter._handle_action(&"action_cancel", ctx)

	# Assert — flag reset
	assert_bool(InputRouter._pending_end_phase).override_failure_message(
		"AC-6/EC: action_cancel must reset _pending_end_phase to false"
	).is_false()

	# Assert — NO emits (silent reset; subscribers must not see a phantom "cancel" event)
	assert_int(_state_changed_captures.size()).override_failure_message(
		"AC-6/EC: action_cancel (armed gate reset) must NOT emit input_state_changed"
	).is_equal(0)
	assert_int(_action_fired_captures.size()).override_failure_message(
		"AC-6/EC: action_cancel (armed gate reset) must NOT emit input_action_fired"
	).is_equal(0)


# ── AC-9 GridBattleStub confirm_attack + is_tile_in_attack_range ─────────────


## AC-9: GridBattleStub.confirm_attack records call with correct params.
func test_grid_battle_stub_confirm_attack_records_call() -> void:
	# Arrange
	var stub := GridBattleStub.new()
	assert_int(stub.confirm_attack_calls.size()).is_equal(0)

	# Act
	stub.confirm_attack(2, Vector2i(5, 5))

	# Assert — 1 recorded call
	assert_int(stub.confirm_attack_calls.size()).override_failure_message(
		"AC-9: confirm_attack must record exactly 1 call"
	).is_equal(1)
	assert_int(stub.confirm_attack_calls[0]["unit_id"] as int).override_failure_message(
		"AC-9: confirm_attack_calls[0].unit_id must be 2"
	).is_equal(2)
	assert_bool(stub.confirm_attack_calls[0]["coord"] == Vector2i(5, 5)).override_failure_message(
		"AC-9: confirm_attack_calls[0].coord must be (5, 5)"
	).is_true()


## AC-9: GridBattleStub.is_tile_in_attack_range returns correct values per fixture.
func test_grid_battle_stub_is_tile_in_attack_range_returns_true_for_fixture_coords() -> void:
	# Arrange
	var stub := GridBattleStub.new()

	# Assert — fixture coords return true
	assert_bool(stub.is_tile_in_attack_range(Vector2i(4, 4))).override_failure_message(
		"AC-9: GridBattleStub.is_tile_in_attack_range(4,4) must return true (in fixture)"
	).is_true()
	assert_bool(stub.is_tile_in_attack_range(Vector2i(5, 5))).override_failure_message(
		"AC-9: GridBattleStub.is_tile_in_attack_range(5,5) must return true (in fixture)"
	).is_true()

	# Assert — non-fixture coords return false
	assert_bool(stub.is_tile_in_attack_range(Vector2i(99, 99))).override_failure_message(
		"AC-9: GridBattleStub.is_tile_in_attack_range(99,99) must return false (not in fixture)"
	).is_false()


# ── AC-11 Structural source assertions ───────────────────────────────────────


## AC-11 (source-scan): _pending_end_phase: bool = false is declared in input_router.gd.
## G-22 line-anchored scan skipping # comment lines.
func test_pending_end_phase_field_declared_in_source() -> void:
	# Arrange
	var content: String = FileAccess.get_file_as_string(_IR_PATH)
	assert_bool(content.length() > 0).override_failure_message(
		"AC-11 pre-condition: failed to read %s" % _IR_PATH
	).is_true()

	# Assert — field declaration present (line-anchored: not in a comment)
	var has_decl: bool = false
	for line: String in content.split("\n"):
		var stripped: String = line.lstrip(" \t")
		if stripped.begins_with("#"):
			continue  # skip doc-comment + regular comment lines per G-22
		if stripped.begins_with("var _pending_end_phase: bool = false"):
			has_decl = true
			break
	assert_bool(has_decl).override_failure_message(
		"AC-11: input_router.gd must declare 'var _pending_end_phase: bool = false'"
		+ " (transient scratch for 2-beat end-player-turn confirmation flow)"
	).is_true()
