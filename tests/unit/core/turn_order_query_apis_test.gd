extends GdUnitTestSuite

## turn_order_query_apis_test.gd
##
## Sprint-7 S7-09 prereq: tests for 4 TurnOrderRunner query APIs that were
## stub-only (return null / 0 / false) in production through S7-08:
##   - get_current_round_number() -> int
##   - get_acted_this_turn(unit_id) -> bool
##   - get_unit_turn_state(unit_id) -> UnitTurnState
##   - get_turn_order_snapshot() -> TurnOrderSnapshot
##
## Stubs replaced with proper instance-state reads to unblock battle-hud
## story-004 (S7-09) initiative queue rendering. These tests prevent regression
## to the stub-default values.

const TurnState = TurnOrderRunner.TurnState

var _runner: TurnOrderRunner


func before_test() -> void:
	# G-15: per-test reset.
	_runner = auto_free(TurnOrderRunner.new())
	add_child(_runner)
	_runner._unit_states.clear()
	_runner._queue.clear()
	_runner._round_number = 0
	_runner._queue_index = 0
	_runner._round_state = TurnOrderRunner.RoundState.BATTLE_NOT_STARTED


# ── Helper: seed a UnitTurnState directly (bypass initialize_battle path) ─────

func _seed_unit_state(unit_id: int, initiative: int, acted: bool, ts: TurnState) -> void:
	var s: UnitTurnState = UnitTurnState.new()
	s.unit_id = unit_id
	s.initiative = initiative
	s.acted_this_turn = acted
	s.turn_state = ts
	_runner._unit_states[unit_id] = s


# ── get_current_round_number ──────────────────────────────────────────────────


func test_get_current_round_number_returns_zero_before_battle_start() -> void:
	# Default state — _round_number == 0.
	assert_int(_runner.get_current_round_number()).is_equal(0)


func test_get_current_round_number_returns_round_number_field() -> void:
	# Seed _round_number = 5 (simulating mid-battle state); query returns 5.
	_runner._round_number = 5
	assert_int(_runner.get_current_round_number()).is_equal(5)


# ── get_acted_this_turn ───────────────────────────────────────────────────────


func test_get_acted_this_turn_unknown_unit_returns_false() -> void:
	assert_bool(_runner.get_acted_this_turn(999)).is_false()


func test_get_acted_this_turn_returns_unit_state_field() -> void:
	_seed_unit_state(7, 50, true, TurnState.ACTING)
	_seed_unit_state(8, 40, false, TurnState.IDLE)
	assert_bool(_runner.get_acted_this_turn(7)).is_true()
	assert_bool(_runner.get_acted_this_turn(8)).is_false()


# ── get_unit_turn_state ───────────────────────────────────────────────────────


func test_get_unit_turn_state_unknown_unit_returns_null() -> void:
	assert_object(_runner.get_unit_turn_state(999)).is_null()


func test_get_unit_turn_state_returns_snapshot_copy() -> void:
	_seed_unit_state(7, 50, true, TurnState.ACTING)
	var snap: UnitTurnState = _runner.get_unit_turn_state(7)
	assert_object(snap).is_not_null()
	assert_int(snap.unit_id).is_equal(7)
	assert_int(snap.initiative).is_equal(50)
	assert_bool(snap.acted_this_turn).is_true()
	# Mutation isolation — modifying snap MUST NOT affect _runner._unit_states[7].
	snap.acted_this_turn = false
	assert_bool(_runner._unit_states[7].acted_this_turn).is_true()


# ── get_turn_order_snapshot ───────────────────────────────────────────────────


func test_get_turn_order_snapshot_empty_before_battle_start() -> void:
	var snap: TurnOrderSnapshot = _runner.get_turn_order_snapshot()
	assert_object(snap).is_not_null()
	assert_int(snap.round_number).is_equal(0)
	assert_int(snap.queue.size()).is_equal(0)


func test_get_turn_order_snapshot_returns_round_and_queue() -> void:
	# Seed 3 units in queue order.
	_seed_unit_state(7, 80, false, TurnState.IDLE)
	_seed_unit_state(3, 70, true, TurnState.DONE)
	_seed_unit_state(11, 60, false, TurnState.IDLE)
	_runner._queue.append(7)
	_runner._queue.append(3)
	_runner._queue.append(11)
	_runner._round_number = 4
	var snap: TurnOrderSnapshot = _runner.get_turn_order_snapshot()
	assert_int(snap.round_number).is_equal(4)
	assert_int(snap.queue.size()).is_equal(3)
	assert_int(snap.queue[0].unit_id).is_equal(7)
	assert_int(snap.queue[0].initiative).is_equal(80)
	assert_bool(snap.queue[0].acted_this_turn).is_false()
	assert_int(snap.queue[1].unit_id).is_equal(3)
	assert_bool(snap.queue[1].acted_this_turn).is_true()
	assert_int(snap.queue[2].unit_id).is_equal(11)


func test_get_turn_order_snapshot_skips_dead_units_not_in_unit_states() -> void:
	# _queue references uid 999 but _unit_states does NOT — defensive skip.
	_seed_unit_state(7, 80, false, TurnState.IDLE)
	_runner._queue.append(7)
	_runner._queue.append(999)
	_runner._round_number = 1
	var snap: TurnOrderSnapshot = _runner.get_turn_order_snapshot()
	assert_int(snap.queue.size()).is_equal(1)
	assert_int(snap.queue[0].unit_id).is_equal(7)
