extends GdUnitTestSuite

## turn_order_declare_action_test.gd
## Unit tests for Story 004 (turn-order epic): TurnOrderRunner.declare_action()
## token validation + DEFEND_STANCE locks + 5 ActionType enum.
##
## Covers AC-1 through AC-13 from story-004 §Acceptance Criteria.
## AC-14 (regression baseline) verified via full-suite run after all tests pass.
##
## Governing ADR: ADR-0011 — Turn Order / Action Management (Accepted 2026-04-30).
## Also governs: ADR-0001 (GameBus single-emitter) + TR-turn-order-012 (CR-3) + TR-turn-order-013 (CR-4).
##
## TEST APPROACH:
##   G-10: subscribe to REAL /root/GameBus, NOT a stub. All signal connections use
##   the production GameBus autoload identifier directly.
##   G-4 sidestep: method-reference capture handlers (NOT lambdas) are used for all
##   signal subscriptions. Method references are safe for connect + disconnect.
##   G-15: before_test() resets all 5 runner instance fields + creates fresh runner.
##   after_test() MUST disconnect all signal connections to prevent accumulation.
##
## ISOLATION DISCIPLINE (G-15):
##   before_test() creates a fresh TurnOrderRunner per test, resets all 5 fields,
##   clears _signal_log, and connects unit_turn_ended capture handler to real GameBus.
##   after_test() disconnects all handlers unconditionally (is_connected guard).
##
## GOTCHA AWARENESS:
##   G-2  — typed-array preservation: .assign() not .duplicate()
##   G-4  — lambda primitive capture: use method refs instead of lambdas
##   G-9  — % operator precedence: wrap multi-line concat in parens before %
##   G-10 — subscribe to real GameBus (NOT stub) per autoload binding semantics
##   G-15 — before_test() is the canonical GdUnit4 v6.1.2 hook (NOT before_each)
##   G-16 — typed Array[Dictionary] for signal log
##   G-23 — GdUnit4 v6.1.2 has no is_not_equal_approx(); use is_not_equal() or manual
##   G-24 — as-operator precedence: wrap RHS cast in parens in == expressions

# ── Constants ─────────────────────────────────────────────────────────────────

## MVP hero IDs (heroes.json verified 2026-05-01).
const _HERO_LIU_BEI: StringName    = &"shu_001_liu_bei"
const _HERO_GUAN_YU: StringName    = &"shu_002_guan_yu"
const _HERO_ZHANG_FEI: StringName  = &"shu_003_zhang_fei"
const _HERO_CAO_CAO: StringName    = &"wei_001_cao_cao"

## UnitRole.UnitClass int backing values (unit_role.gd — locked per ADR-0009).
const _CLASS_CAVALRY: int    = 0
const _CLASS_INFANTRY: int   = 1
const _CLASS_COMMANDER: int  = 4
const _CLASS_SCOUT: int      = 5

# ── Suite state ───────────────────────────────────────────────────────────────

var _runner: TurnOrderRunner
## Unified signal log — unit_turn_ended capture handler appends here.
## G-4: method refs avoid lambda primitive-capture hazard entirely.
## G-16: typed Array[Dictionary] preserves element type.
var _signal_log: Array[Dictionary] = []

# ── Signal capture handlers (method-reference form — sidesteps G-4) ──────────

func _capture_unit_turn_ended(unit_id: int, acted: bool) -> void:
	_signal_log.append({"signal": "unit_turn_ended", "unit_id": unit_id, "acted": acted})


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func before_test() -> void:
	## G-15: canonical GdUnit4 v6.1.2 per-test hook (NOT before_each).
	## Creates a fresh TurnOrderRunner and resets all 5 instance fields.
	## Connects the unit_turn_ended capture handler to the real GameBus (G-10).
	_signal_log.clear()
	_runner = auto_free(TurnOrderRunner.new())
	add_child(_runner)
	# Reset all 5 instance fields (defensive even on fresh runner).
	_runner._unit_states.clear()
	_runner._queue.clear()
	_runner._round_number = 0
	_runner._queue_index = 0
	_runner._round_state = TurnOrderRunner.RoundState.BATTLE_NOT_STARTED
	# Connect unit_turn_ended capture handler to real GameBus (G-10: NOT a stub).
	GameBus.unit_turn_ended.connect(_capture_unit_turn_ended)


func after_test() -> void:
	## CRITICAL G-15: disconnect ALL handlers to prevent accumulation across tests.
	## is_connected guard prevents double-disconnect errors on out-of-order teardown.
	if GameBus.unit_turn_ended.is_connected(_capture_unit_turn_ended):
		GameBus.unit_turn_ended.disconnect(_capture_unit_turn_ended)


# ── Helpers ───────────────────────────────────────────────────────────────────

## Constructs a BattleUnit with the specified fields.
## G-2: typed-array preservation — callers use roster.append(_make_unit(...)).
func _make_unit(
		unit_id: int,
		hero_id: StringName,
		unit_class: int,
		is_player: bool) -> BattleUnit:
	var u: BattleUnit = BattleUnit.new()
	u.unit_id = unit_id
	u.hero_id = hero_id
	u.unit_class = unit_class
	u.is_player_controlled = is_player
	return u


## Sets up runner with a 1-unit roster (liu_bei, commander, player-controlled) and
## manually sets the unit's turn_state to ACTING (simulating post-T4 state).
## This bypasses the deferred _begin_round chain and avoids GameBus signal noise.
## Clears _signal_log after setup so tests start with a clean log.
func _setup_single_unit_at_t4(uid: int) -> void:
	var roster: Array[BattleUnit] = []
	roster.append(_make_unit(uid, _HERO_LIU_BEI, _CLASS_COMMANDER, true))
	_runner.initialize_battle(roster)
	# Manually set ROUND_ACTIVE to bypass deferred _begin_round chain.
	_runner._round_state = TurnOrderRunner.RoundState.ROUND_ACTIVE
	# Manually set ACTING to simulate post-T4 state (token-reset already done
	# by initialize_battle's BI-3 defaults; turn_state transitions to ACTING here).
	_runner._unit_states[uid].turn_state = TurnOrderRunner.TurnState.ACTING
	# Ensure tokens are FRESH (defensive — initialize_battle already sets these).
	_runner._unit_states[uid].move_token_spent = false
	_runner._unit_states[uid].action_token_spent = false
	_runner._unit_states[uid].defend_stance_active = false
	_signal_log.clear()


## Compares two UnitTurnState instances field-by-field.
## Returns true if all 10 fields are equal.
## Used by AC-8 no-mutation assertions.
func _states_equal(a: UnitTurnState, b: UnitTurnState) -> bool:
	return (
		a.unit_id == b.unit_id
		and a.move_token_spent == b.move_token_spent
		and a.action_token_spent == b.action_token_spent
		and a.accumulated_move_cost == b.accumulated_move_cost
		and a.acted_this_turn == b.acted_this_turn
		and (a.turn_state as int) == (b.turn_state as int)
		and a.initiative == b.initiative
		and a.stat_agility == b.stat_agility
		and a.is_player_controlled == b.is_player_controlled
		and a.defend_stance_active == b.defend_stance_active
	)


# ── AC-1: invalid ActionType rejected ────────────────────────────────────────


## AC-1 (TR-005, TR-013): declare_action with out-of-range int (99) returns
## ActionResult{success: false, error_code: INVALID_ACTION_TYPE}.
## UnitTurnState is unchanged after the failed call.
## Given: unit in ACTING state, both tokens FRESH.
## When:  declare_action(uid, 99, null) — 99 is not a valid ActionType value.
## Then:  result.success == false; result.error_code == INVALID_ACTION_TYPE;
##        UnitTurnState fields unchanged.
func test_declare_action_invalid_action_type_rejected_with_error_code() -> void:
	# Arrange
	var uid: int = 1
	_setup_single_unit_at_t4(uid)
	var pre_snap: UnitTurnState = _runner._unit_states[uid].snapshot()

	# Act — 99 is out of range [0, ActionType.size()-1] = [0, 4]
	var result: ActionResult = _runner.declare_action(uid, 99, null)

	# Assert — rejected with INVALID_ACTION_TYPE
	assert_bool(result.success).override_failure_message(
		"AC-1: declare_action(99) must return success=false for invalid ActionType"
	).is_false()

	assert_int(result.error_code).override_failure_message(
		("AC-1: error_code must be INVALID_ACTION_TYPE (%d); got %d")
		% [(TurnOrderRunner.ActionError.INVALID_ACTION_TYPE as int), result.error_code]
	).is_equal(TurnOrderRunner.ActionError.INVALID_ACTION_TYPE as int)

	# AC-8 corollary: state unchanged
	assert_bool(_states_equal(pre_snap, _runner._unit_states[uid])).override_failure_message(
		"AC-1/AC-8: failed declare_action(99) must not mutate UnitTurnState"
	).is_true()


## AC-1 negative-int branch coverage: the line-259 guard `action < 0 or action
## >= ActionType.size()` has TWO branches; the >=size branch is covered by 99,
## the <0 branch is covered here with -1.
## Given: unit in ACTING state.
## When:  declare_action(uid, -1, null).
## Then:  success=false; error_code=INVALID_ACTION_TYPE; state unchanged.
func test_declare_action_invalid_action_type_negative_int_rejected() -> void:
	# Arrange
	var uid: int = 1
	_setup_single_unit_at_t4(uid)
	var pre_snap: UnitTurnState = _runner._unit_states[uid].snapshot()

	# Act — -1 is out of range [0, ActionType.size()-1] = [0, 4]; covers the
	# `action < 0` branch of the guard at runner.gd line 259 (the >=size branch
	# is covered by the 99-input test above).
	var result: ActionResult = _runner.declare_action(uid, -1, null)

	# Assert — rejected with INVALID_ACTION_TYPE
	assert_bool(result.success).override_failure_message(
		"AC-1: declare_action(-1) must return success=false for negative ActionType int"
	).is_false()

	assert_int(result.error_code).override_failure_message(
		("AC-1: error_code must be INVALID_ACTION_TYPE (%d); got %d")
		% [(TurnOrderRunner.ActionError.INVALID_ACTION_TYPE as int), result.error_code]
	).is_equal(TurnOrderRunner.ActionError.INVALID_ACTION_TYPE as int)

	# AC-8 corollary: state unchanged
	assert_bool(_states_equal(pre_snap, _runner._unit_states[uid])).override_failure_message(
		"AC-1/AC-8: failed declare_action(-1) must not mutate UnitTurnState"
	).is_true()


# ── AC-2: MOVE spends move token only ────────────────────────────────────────


## AC-2 (TR-012): MOVE action spends move_token_spent only; action_token_spent unchanged.
## Given: unit in ACTING state, both tokens FRESH.
## When:  declare_action(uid, ActionType.MOVE, null).
## Then:  success=true; move_token_spent=true; action_token_spent unchanged (false).
func test_declare_action_move_spends_move_token_only() -> void:
	# Arrange
	var uid: int = 1
	_setup_single_unit_at_t4(uid)

	# Act
	var result: ActionResult = _runner.declare_action(
		uid, TurnOrderRunner.ActionType.MOVE as int, null)

	# Assert — success
	assert_bool(result.success).override_failure_message(
		"AC-2: declare_action(MOVE) must succeed when MOVE token is FRESH"
	).is_true()

	assert_int(result.error_code).override_failure_message(
		("AC-2: error_code must be NONE (%d) on success; got %d")
		% [(TurnOrderRunner.ActionError.NONE as int), result.error_code]
	).is_equal(TurnOrderRunner.ActionError.NONE as int)

	# Assert — move_token_spent = true; action_token_spent unchanged
	assert_bool(_runner._unit_states[uid].move_token_spent).override_failure_message(
		"AC-2: move_token_spent must be true after declare_action(MOVE)"
	).is_true()

	assert_bool(_runner._unit_states[uid].action_token_spent).override_failure_message(
		"AC-2: action_token_spent must remain false after declare_action(MOVE)"
	).is_false()


# ── AC-3a: ATTACK spends action token only ───────────────────────────────────


## AC-3a (TR-012): ATTACK action spends action_token_spent only; move_token_spent unchanged.
## Given: unit in ACTING state, both tokens FRESH, no DEFEND_STANCE active.
## When:  declare_action(uid, ActionType.ATTACK, null).
## Then:  success=true; action_token_spent=true; move_token_spent unchanged (false).
func test_declare_action_attack_spends_action_token_only() -> void:
	# Arrange
	var uid: int = 1
	_setup_single_unit_at_t4(uid)

	# Act
	var result: ActionResult = _runner.declare_action(
		uid, TurnOrderRunner.ActionType.ATTACK as int, null)

	# Assert
	assert_bool(result.success).override_failure_message(
		"AC-3a: declare_action(ATTACK) must succeed when ACTION token is FRESH"
	).is_true()

	assert_bool(_runner._unit_states[uid].action_token_spent).override_failure_message(
		"AC-3a: action_token_spent must be true after declare_action(ATTACK)"
	).is_true()

	assert_bool(_runner._unit_states[uid].move_token_spent).override_failure_message(
		"AC-3a: move_token_spent must remain false after declare_action(ATTACK)"
	).is_false()


# ── AC-3b: USE_SKILL spends action token only ────────────────────────────────


## AC-3b (TR-012): USE_SKILL action spends action_token_spent only; move_token_spent unchanged.
## Given: unit in ACTING state, both tokens FRESH.
## When:  declare_action(uid, ActionType.USE_SKILL, null).
## Then:  success=true; action_token_spent=true; move_token_spent unchanged (false).
func test_declare_action_use_skill_spends_action_token_only() -> void:
	# Arrange
	var uid: int = 1
	_setup_single_unit_at_t4(uid)

	# Act
	var result: ActionResult = _runner.declare_action(
		uid, TurnOrderRunner.ActionType.USE_SKILL as int, null)

	# Assert
	assert_bool(result.success).override_failure_message(
		"AC-3b: declare_action(USE_SKILL) must succeed when ACTION token is FRESH"
	).is_true()

	assert_bool(_runner._unit_states[uid].action_token_spent).override_failure_message(
		"AC-3b: action_token_spent must be true after declare_action(USE_SKILL)"
	).is_true()

	assert_bool(_runner._unit_states[uid].move_token_spent).override_failure_message(
		"AC-3b: move_token_spent must remain false after declare_action(USE_SKILL)"
	).is_false()


# ── AC-4 + AC-12: DEFEND spends ACTION token + locks MOVE ────────────────────


## AC-4 + AC-12 (TR-013, CR-3e, GDD AC-06): DEFEND spends ACTION token, applies
## DEFEND_STANCE (defend_stance_active=true), and subsequent MOVE declaration
## returns MOVE_LOCKED_BY_DEFEND_STANCE.
## Given: unit in ACTING state, both tokens FRESH.
## When:  declare_action(DEFEND) THEN declare_action(MOVE).
## Then:  DEFEND succeeds + action_token_spent=true + defend_stance_active=true;
##        MOVE returns error_code MOVE_LOCKED_BY_DEFEND_STANCE.
func test_declare_action_defend_spends_action_token_and_locks_move() -> void:
	# Arrange
	var uid: int = 1
	_setup_single_unit_at_t4(uid)

	# Act — first: DEFEND
	var defend_result: ActionResult = _runner.declare_action(
		uid, TurnOrderRunner.ActionType.DEFEND as int, null)

	# Assert DEFEND success
	assert_bool(defend_result.success).override_failure_message(
		"AC-4: declare_action(DEFEND) must succeed when ACTION token is FRESH"
	).is_true()

	assert_bool(_runner._unit_states[uid].action_token_spent).override_failure_message(
		"AC-4: action_token_spent must be true after declare_action(DEFEND)"
	).is_true()

	assert_bool(_runner._unit_states[uid].defend_stance_active).override_failure_message(
		"AC-4: defend_stance_active must be true after declare_action(DEFEND)"
	).is_true()

	# Act — second: MOVE (should be locked by DEFEND_STANCE)
	var move_result: ActionResult = _runner.declare_action(
		uid, TurnOrderRunner.ActionType.MOVE as int, null)

	# Assert MOVE locked
	assert_bool(move_result.success).override_failure_message(
		"AC-12: declare_action(MOVE) after DEFEND must fail (MOVE_LOCKED_BY_DEFEND_STANCE)"
	).is_false()

	assert_int(move_result.error_code).override_failure_message(
		("AC-12: error_code must be MOVE_LOCKED_BY_DEFEND_STANCE (%d); got %d")
		% [(TurnOrderRunner.ActionError.MOVE_LOCKED_BY_DEFEND_STANCE as int),
			move_result.error_code]
	).is_equal(TurnOrderRunner.ActionError.MOVE_LOCKED_BY_DEFEND_STANCE as int)

	# move_token_spent must remain false (DEFEND does not consume MOVE token)
	assert_bool(_runner._unit_states[uid].move_token_spent).override_failure_message(
		"AC-12: move_token_spent must remain false after DEFEND+failed-MOVE sequence"
	).is_false()


# ── AC-6: WAIT spends no token, sets DONE ────────────────────────────────────


## AC-6 (TR-013, CR-8, GDD AC-05): WAIT spends NO token and sets turn_state = DONE.
## Given: unit in ACTING state, both tokens FRESH.
## When:  declare_action(WAIT).
## Then:  success=true; move_token_spent=false; action_token_spent=false;
##        turn_state == DONE; _queue and _queue_index unmodified by WAIT itself.
func test_declare_action_wait_spends_no_token_and_sets_done() -> void:
	# Arrange
	var uid: int = 1
	_setup_single_unit_at_t4(uid)

	# Act
	var result: ActionResult = _runner.declare_action(
		uid, TurnOrderRunner.ActionType.WAIT as int, null)

	# Assert
	assert_bool(result.success).override_failure_message(
		"AC-6: declare_action(WAIT) must always succeed"
	).is_true()

	assert_bool(_runner._unit_states[uid].move_token_spent).override_failure_message(
		"AC-6: move_token_spent must remain false after WAIT (CR-8 no token spend)"
	).is_false()

	assert_bool(_runner._unit_states[uid].action_token_spent).override_failure_message(
		"AC-6: action_token_spent must remain false after WAIT (CR-8 no token spend)"
	).is_false()

	assert_int(
		_runner._unit_states[uid].turn_state as int
	).override_failure_message(
		("AC-6: turn_state must be DONE (%d) after WAIT; got %d")
		% [(TurnOrderRunner.TurnState.DONE as int),
			(_runner._unit_states[uid].turn_state as int)]
	).is_equal(TurnOrderRunner.TurnState.DONE as int)


# ── AC-7: token re-spend rejected ────────────────────────────────────────────


## AC-7 (TR-012): re-spending an already-spent token returns TOKEN_ALREADY_SPENT.
## Tests both MOVE token re-spend and ACTION token re-spend sub-cases.
## Given: MOVE token already spent (move_token_spent=true).
## When:  declare_action(MOVE) second call.
## Then:  success=false; error_code == TOKEN_ALREADY_SPENT; state field-equal to pre-call snapshot.
func test_declare_action_token_re_spend_rejected_with_error_code() -> void:
	# Arrange
	var uid: int = 1
	_setup_single_unit_at_t4(uid)

	# Sub-case A: MOVE token re-spend
	# Spend MOVE token via first call
	var first_move: ActionResult = _runner.declare_action(
		uid, TurnOrderRunner.ActionType.MOVE as int, null)
	assert_bool(first_move.success).override_failure_message(
		"AC-7 setup: first MOVE must succeed"
	).is_true()

	# Snapshot AFTER first successful spend (before failed re-spend)
	var pre_snap_move: UnitTurnState = _runner._unit_states[uid].snapshot()

	# Attempt re-spend
	var second_move: ActionResult = _runner.declare_action(
		uid, TurnOrderRunner.ActionType.MOVE as int, null)

	assert_bool(second_move.success).override_failure_message(
		"AC-7 MOVE: second declare_action(MOVE) must fail (already spent)"
	).is_false()

	assert_int(second_move.error_code).override_failure_message(
		("AC-7 MOVE: error_code must be TOKEN_ALREADY_SPENT (%d); got %d")
		% [(TurnOrderRunner.ActionError.TOKEN_ALREADY_SPENT as int), second_move.error_code]
	).is_equal(TurnOrderRunner.ActionError.TOKEN_ALREADY_SPENT as int)

	# AC-8 corollary: no mutation on failed re-spend
	assert_bool(_states_equal(pre_snap_move, _runner._unit_states[uid])).override_failure_message(
		"AC-7/AC-8 MOVE: failed MOVE re-spend must not mutate UnitTurnState"
	).is_true()

	# Sub-case B: ACTION token re-spend
	# Spend ACTION token via first call
	var first_attack: ActionResult = _runner.declare_action(
		uid, TurnOrderRunner.ActionType.ATTACK as int, null)
	assert_bool(first_attack.success).override_failure_message(
		"AC-7 setup: first ATTACK must succeed"
	).is_true()

	# Snapshot AFTER first successful spend (before failed re-spend)
	var pre_snap_action: UnitTurnState = _runner._unit_states[uid].snapshot()

	# Attempt ACTION token re-spend via USE_SKILL
	var second_skill: ActionResult = _runner.declare_action(
		uid, TurnOrderRunner.ActionType.USE_SKILL as int, null)

	assert_bool(second_skill.success).override_failure_message(
		"AC-7 ACTION: second declare_action(USE_SKILL) must fail (ACTION token already spent)"
	).is_false()

	assert_int(second_skill.error_code).override_failure_message(
		("AC-7 ACTION: error_code must be TOKEN_ALREADY_SPENT (%d); got %d")
		% [(TurnOrderRunner.ActionError.TOKEN_ALREADY_SPENT as int), second_skill.error_code]
	).is_equal(TurnOrderRunner.ActionError.TOKEN_ALREADY_SPENT as int)

	# AC-8 corollary: no mutation on failed re-spend
	assert_bool(_states_equal(pre_snap_action, _runner._unit_states[uid])).override_failure_message(
		"AC-7/AC-8 ACTION: failed USE_SKILL re-spend must not mutate UnitTurnState"
	).is_true()


# ── AC-8: failed validation does not mutate state ────────────────────────────


## AC-8 (TR-005): failed validation does NOT mutate UnitTurnState (no half-validated state).
## Uses UnitTurnState.snapshot() field-by-field comparison.
## Given: unit in ACTING state, both tokens FRESH.
## When:  declare_action with an invalid action type (99).
## Then:  pre-call snapshot field-equal to post-failed-call state.
func test_declare_action_failed_validation_does_not_mutate_state() -> void:
	# Arrange
	var uid: int = 1
	_setup_single_unit_at_t4(uid)
	var pre_snap: UnitTurnState = _runner._unit_states[uid].snapshot()

	# Act — invalid action type triggers INVALID_ACTION_TYPE rejection
	var result: ActionResult = _runner.declare_action(uid, 99, null)

	# Assert — result is a failure
	assert_bool(result.success).override_failure_message(
		"AC-8 setup: declare_action(99) must fail"
	).is_false()

	# Assert — field-by-field equality via snapshot comparison
	var post_state: UnitTurnState = _runner._unit_states[uid]
	assert_bool(_states_equal(pre_snap, post_state)).override_failure_message(
		("AC-8: failed declare_action must not mutate any UnitTurnState field; "
		+ "pre=%s post=%s") % [str(pre_snap), str(post_state)]
	).is_true()


# ── AC-9: Attack→Move order flexibility (GDD AC-03) ──────────────────────────


## AC-9 (GDD AC-03): Attack→Move order both succeed; acted_this_turn=true at T6.
## Given: unit in ACTING state, both tokens FRESH.
## When:  declare_action(ATTACK) then declare_action(MOVE).
## Then:  both succeed; action_token_spent=true + move_token_spent=true;
##        trigger _mark_acted → acted_this_turn=true.
func test_declare_action_attack_then_move_both_succeed_acted_true_at_t6() -> void:
	# Arrange
	var uid: int = 1
	_setup_single_unit_at_t4(uid)

	# Act — ATTACK first (ACTION spent, no DEFEND_STANCE applied)
	var attack_result: ActionResult = _runner.declare_action(
		uid, TurnOrderRunner.ActionType.ATTACK as int, null)

	assert_bool(attack_result.success).override_failure_message(
		"AC-9: declare_action(ATTACK) must succeed when ACTION token is FRESH"
	).is_true()

	# Act — MOVE second (MOVE token still FRESH, no DEFEND_STANCE block)
	var move_result: ActionResult = _runner.declare_action(
		uid, TurnOrderRunner.ActionType.MOVE as int, null)

	assert_bool(move_result.success).override_failure_message(
		"AC-9: declare_action(MOVE) after ATTACK must succeed (MOVE token still FRESH)"
	).is_true()

	# Verify both tokens spent
	assert_bool(_runner._unit_states[uid].action_token_spent).override_failure_message(
		"AC-9: action_token_spent must be true after ATTACK"
	).is_true()

	assert_bool(_runner._unit_states[uid].move_token_spent).override_failure_message(
		"AC-9: move_token_spent must be true after MOVE"
	).is_true()

	# Trigger T6 via _mark_acted (simulates end of T5 action budget phase)
	_runner._mark_acted(uid)

	# Assert — acted_this_turn=true (at least one token spent: both in this case)
	assert_bool(_runner._unit_states[uid].acted_this_turn).override_failure_message(
		("AC-9: acted_this_turn must be true after Attack+Move (both tokens spent); "
		+ "CR-3f: acted_this_turn = move_token_spent OR action_token_spent")
	).is_true()


# ── AC-10: MOVE-only → acted=true at T6 (GDD AC-04) ─────────────────────────


## AC-10 (GDD AC-04): MOVE-only → acted_this_turn=true at T6; unit_turn_ended.acted=true.
## Given: unit in ACTING state, both tokens FRESH.
## When:  declare_action(MOVE) only, then _mark_acted.
## Then:  acted_this_turn=true; signal_log unit_turn_ended.acted=true.
func test_declare_action_move_only_acted_true_at_t6() -> void:
	# Arrange
	var uid: int = 1
	_setup_single_unit_at_t4(uid)

	# Act — MOVE only (ACTION token forfeited)
	var result: ActionResult = _runner.declare_action(
		uid, TurnOrderRunner.ActionType.MOVE as int, null)
	assert_bool(result.success).override_failure_message(
		"AC-10 setup: declare_action(MOVE) must succeed"
	).is_true()

	# Trigger T6
	_runner._mark_acted(uid)

	# Assert acted_this_turn via state field
	assert_bool(_runner._unit_states[uid].acted_this_turn).override_failure_message(
		("AC-10: acted_this_turn must be true after MOVE-only turn; "
		+ "CR-3f: move_token_spent=true → acted=true")
	).is_true()

	# Assert unit_turn_ended signal
	var ended_entries: Array[Dictionary] = []
	for entry: Dictionary in _signal_log:
		if (entry.get("signal", "") as String) == "unit_turn_ended":
			ended_entries.append(entry)

	assert_int(ended_entries.size()).override_failure_message(
		("AC-10: _mark_acted must emit exactly 1 unit_turn_ended signal; got %d")
		% ended_entries.size()
	).is_equal(1)

	assert_bool(
		ended_entries[0].get("acted", false) as bool
	).override_failure_message(
		"AC-10: unit_turn_ended.acted must be true after MOVE-only turn"
	).is_true()


# ── AC-11: WAIT → acted=false at T6, queue unchanged (GDD AC-05) ─────────────


## AC-11 (GDD AC-05): WAIT → acted_this_turn=false at T6; unit_turn_ended.acted=false;
## queue content unchanged; _queue_index advances normally.
## Given: unit in ACTING state, WAIT declared.
## When:  _mark_acted called after WAIT.
## Then:  acted_this_turn=false; unit_turn_ended.acted=false;
##        both tokens remain FRESH (unspent by WAIT).
func test_declare_action_wait_acted_false_at_t6() -> void:
	# Arrange
	var uid: int = 1
	_setup_single_unit_at_t4(uid)

	# Act — WAIT (no token spent; turn_state set to DONE by declare_action)
	var result: ActionResult = _runner.declare_action(
		uid, TurnOrderRunner.ActionType.WAIT as int, null)
	assert_bool(result.success).override_failure_message(
		"AC-11 setup: declare_action(WAIT) must succeed"
	).is_true()

	# WAIT sets turn_state = DONE; _mark_acted reads the token flags (both false)
	# to compute acted_this_turn. But _mark_acted also SETS turn_state = DONE again
	# and emits unit_turn_ended — safe to call even after WAIT's state.turn_state = DONE.
	_runner._mark_acted(uid)

	# Assert acted_this_turn == false
	assert_bool(_runner._unit_states[uid].acted_this_turn).override_failure_message(
		("AC-11: acted_this_turn must be false after WAIT; "
		+ "CR-3f: move_token_spent=false OR action_token_spent=false = false")
	).is_false()

	# Assert tokens remain FRESH (WAIT does not spend tokens per CR-8)
	assert_bool(_runner._unit_states[uid].move_token_spent).override_failure_message(
		"AC-11: move_token_spent must remain false after WAIT"
	).is_false()

	assert_bool(_runner._unit_states[uid].action_token_spent).override_failure_message(
		"AC-11: action_token_spent must remain false after WAIT"
	).is_false()

	# Assert unit_turn_ended.acted=false signal
	var ended_entries: Array[Dictionary] = []
	for entry: Dictionary in _signal_log:
		if (entry.get("signal", "") as String) == "unit_turn_ended":
			ended_entries.append(entry)

	assert_int(ended_entries.size()).override_failure_message(
		("AC-11: _mark_acted must emit exactly 1 unit_turn_ended signal; got %d")
		% ended_entries.size()
	).is_equal(1)

	assert_bool(
		ended_entries[0].get("acted", true) as bool
	).override_failure_message(
		"AC-11: unit_turn_ended.acted must be false after WAIT"
	).is_false()


# ── AC-13: WAIT does not reposition queue (GDD AC-11) ────────────────────────


## AC-13 (GDD AC-11, CR-8): WAIT does not reposition the queue — unit stays at
## original queue position; _queue_index advances to next unit.
## Given: 4-unit queue [U1, U2, U3, U4]; current _queue_index = 2 (U3's turn).
## When:  U3 declare_action(WAIT) → DONE state.
## Then:  _queue content == [U1, U2, U3, U4] unchanged; U3.turn_state == DONE;
##        no queue.append() or queue repositioning occurred.
func test_declare_action_wait_does_not_reposition_queue_in_4unit_roster() -> void:
	# Arrange — 4-unit roster with synthetic initiatives to control queue order.
	var roster: Array[BattleUnit] = []
	roster.append(_make_unit(1, _HERO_LIU_BEI,   _CLASS_COMMANDER, true))
	roster.append(_make_unit(2, _HERO_GUAN_YU,   _CLASS_INFANTRY,  false))
	roster.append(_make_unit(3, _HERO_ZHANG_FEI, _CLASS_INFANTRY,  false))
	roster.append(_make_unit(4, _HERO_CAO_CAO,   _CLASS_CAVALRY,   false))
	_runner.initialize_battle(roster)

	# Seed synthetic initiatives to force queue order [1, 2, 3, 4].
	_runner._seed_unit_state_for_test(1, 200, 65, true)   # uid=1 highest
	_runner._seed_unit_state_for_test(2, 160, 70, false)
	_runner._seed_unit_state_for_test(3, 120, 60, false)
	_runner._seed_unit_state_for_test(4, 80,  70, false)  # uid=4 lowest

	# Rebuild queue with seeded values and set state to ROUND_ACTIVE.
	_runner._rebuild_queue()
	_runner._round_state = TurnOrderRunner.RoundState.ROUND_ACTIVE
	_runner._queue_index = 2  # U3's turn (third in queue [1, 2, 3, 4])

	# Manually set U3 to ACTING (simulating post-T4 state).
	_runner._unit_states[3].turn_state = TurnOrderRunner.TurnState.ACTING
	_runner._unit_states[3].move_token_spent = false
	_runner._unit_states[3].action_token_spent = false
	_runner._unit_states[3].defend_stance_active = false
	_signal_log.clear()

	# Capture queue BEFORE WAIT
	var queue_before: Array[int] = []
	queue_before.assign(_runner._queue)

	# Act — U3 declares WAIT
	var result: ActionResult = _runner.declare_action(
		3, TurnOrderRunner.ActionType.WAIT as int, null)

	# Assert WAIT succeeded
	assert_bool(result.success).override_failure_message(
		"AC-13: declare_action(WAIT) must succeed for U3"
	).is_true()

	# Assert queue content unchanged (no repositioning)
	assert_int(_runner._queue.size()).override_failure_message(
		("AC-13: queue size must remain 4 after WAIT; got %d — no units added/removed")
		% _runner._queue.size()
	).is_equal(4)

	for i: int in range(4):
		assert_int(_runner._queue[i]).override_failure_message(
			("AC-13: queue[%d] must be %d (unchanged by WAIT); got %d")
			% [i, (queue_before[i] as int), (_runner._queue[i] as int)]
		).is_equal(queue_before[i] as int)

	# Assert U3.turn_state == DONE (WAIT set it)
	assert_int(
		_runner._unit_states[3].turn_state as int
	).override_failure_message(
		("AC-13: U3 turn_state must be DONE (%d) after WAIT; got %d")
		% [(TurnOrderRunner.TurnState.DONE as int),
			(_runner._unit_states[3].turn_state as int)]
	).is_equal(TurnOrderRunner.TurnState.DONE as int)

	# Assert _queue_index is still 2 (WAIT does not advance the index itself;
	# CR-8: WAIT does NOT trigger _advance_to_next_queued_unit — that is done
	# by _advance_turn after _execute_action_budget returns; story-004 tests
	# declare_action in isolation, not via the full _advance_turn chain).
	assert_int(_runner._queue_index).override_failure_message(
		("AC-13: _queue_index must remain 2 after declare_action(WAIT) in isolation; "
		+ "queue repositioning is _advance_turn's responsibility, not declare_action's")
	).is_equal(2)


# ── UNIT_NOT_FOUND: invalid unit_id rejected ─────────────────────────────────


## UNIT_NOT_FOUND defense: declare_action for unknown unit_id returns UNIT_NOT_FOUND.
## Given: runner initialized with uid=1; declare_action called with uid=9999.
## When:  declare_action(9999, ActionType.MOVE, null).
## Then:  success=false; error_code == UNIT_NOT_FOUND.
func test_declare_action_unit_not_found_rejected() -> void:
	# Arrange
	var uid: int = 1
	_setup_single_unit_at_t4(uid)

	# Act — uid=9999 is not in _unit_states
	var result: ActionResult = _runner.declare_action(
		9999, TurnOrderRunner.ActionType.MOVE as int, null)

	# Assert
	assert_bool(result.success).override_failure_message(
		"UNIT_NOT_FOUND: declare_action(9999) must fail for unknown unit_id"
	).is_false()

	assert_int(result.error_code).override_failure_message(
		("UNIT_NOT_FOUND: error_code must be UNIT_NOT_FOUND (%d); got %d")
		% [(TurnOrderRunner.ActionError.UNIT_NOT_FOUND as int), result.error_code]
	).is_equal(TurnOrderRunner.ActionError.UNIT_NOT_FOUND as int)


# ── NOT_UNIT_TURN: rejected when turn_state != ACTING ────────────────────────


## NOT_UNIT_TURN defense: declare_action rejected when unit's turn_state is IDLE.
## Given: runner initialized with uid=1; turn_state manually left as IDLE (not ACTING).
## When:  declare_action(uid, ActionType.MOVE, null).
## Then:  success=false; error_code == NOT_UNIT_TURN.
func test_declare_action_not_unit_turn_rejected_when_idle() -> void:
	# Arrange — initialize battle BUT do NOT set ACTING (leave as IDLE default)
	var uid: int = 1
	var roster: Array[BattleUnit] = []
	roster.append(_make_unit(uid, _HERO_LIU_BEI, _CLASS_COMMANDER, true))
	_runner.initialize_battle(roster)
	_runner._round_state = TurnOrderRunner.RoundState.ROUND_ACTIVE
	# turn_state remains IDLE (BI-3 default; _activate_unit_turn not yet called)
	_signal_log.clear()

	# Verify precondition: IDLE state
	assert_int(
		_runner._unit_states[uid].turn_state as int
	).override_failure_message(
		"NOT_UNIT_TURN setup: turn_state must be IDLE for this test"
	).is_equal(TurnOrderRunner.TurnState.IDLE as int)

	# Act — declare_action during IDLE (not during T4-T5 ACTING phase)
	var result: ActionResult = _runner.declare_action(
		uid, TurnOrderRunner.ActionType.MOVE as int, null)

	# Assert
	assert_bool(result.success).override_failure_message(
		"NOT_UNIT_TURN: declare_action during IDLE must fail"
	).is_false()

	assert_int(result.error_code).override_failure_message(
		("NOT_UNIT_TURN: error_code must be NOT_UNIT_TURN (%d); got %d")
		% [(TurnOrderRunner.ActionError.NOT_UNIT_TURN as int), result.error_code]
	).is_equal(TurnOrderRunner.ActionError.NOT_UNIT_TURN as int)


## NOT_UNIT_TURN cross-action-type re-entry guard: after declare_action(WAIT)
## sets turn_state=DONE per CR-8, a subsequent declare_action(MOVE) on the same
## unit must be rejected with NOT_UNIT_TURN (the unit's turn is already over).
## Defends against accidental re-entry from the same player input frame.
##
## Given: unit ACTING, both tokens FRESH.
## When:  declare_action(WAIT) → turn_state becomes DONE.
##         then declare_action(MOVE) on the same unit.
## Then:  WAIT succeeds; MOVE returns NOT_UNIT_TURN (post-WAIT turn_state==DONE).
func test_declare_action_post_wait_move_rejected_with_not_unit_turn() -> void:
	# Arrange
	var uid: int = 1
	_setup_single_unit_at_t4(uid)

	# Act 1 — WAIT succeeds + sets turn_state=DONE
	var wait_result: ActionResult = _runner.declare_action(
		uid, TurnOrderRunner.ActionType.WAIT as int, null)
	assert_bool(wait_result.success).override_failure_message(
		"WAIT prerequisite: declare_action(WAIT) must succeed before re-entry test"
	).is_true()
	assert_int(
		_runner._unit_states[uid].turn_state as int
	).override_failure_message(
		"WAIT prerequisite: turn_state must be DONE post-WAIT before re-entry"
	).is_equal(TurnOrderRunner.TurnState.DONE as int)

	# Act 2 — MOVE attempt during DONE phase (cross-action-type re-entry)
	var move_result: ActionResult = _runner.declare_action(
		uid, TurnOrderRunner.ActionType.MOVE as int, null)

	# Assert — MOVE rejected with NOT_UNIT_TURN (turn ended via WAIT)
	assert_bool(move_result.success).override_failure_message(
		"NOT_UNIT_TURN: post-WAIT MOVE re-entry must fail"
	).is_false()

	assert_int(move_result.error_code).override_failure_message(
		("NOT_UNIT_TURN: post-WAIT MOVE error_code must be NOT_UNIT_TURN (%d); got %d "
		+ "— the NOT_UNIT_TURN guard at runner.gd line 254 must reject DONE-state re-entries")
		% [(TurnOrderRunner.ActionError.NOT_UNIT_TURN as int), move_result.error_code]
	).is_equal(TurnOrderRunner.ActionError.NOT_UNIT_TURN as int)

	# AC-6 corollary: tokens still FRESH (WAIT spent neither; failed MOVE didn't mutate)
	assert_bool(_runner._unit_states[uid].move_token_spent).override_failure_message(
		"NOT_UNIT_TURN: post-WAIT failed MOVE must not have mutated move_token_spent"
	).is_false()
	assert_bool(_runner._unit_states[uid].action_token_spent).override_failure_message(
		"NOT_UNIT_TURN: post-WAIT failed MOVE must not have mutated action_token_spent"
	).is_false()
