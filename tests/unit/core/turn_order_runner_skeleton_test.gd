extends GdUnitTestSuite

## turn_order_runner_skeleton_test.gd
## Unit tests for Story 001 (turn-order epic): TurnOrderRunner module skeleton,
## 2 nested enums (RoundState 6-value + TurnState 4-value), 5 instance fields,
## 3 RefCounted typed wrappers (UnitTurnState / TurnOrderSnapshot / TurnOrderEntry),
## and UnitTurnState.snapshot() identity + value parity + mutation independence.
##
## Covers AC-1 through AC-6 from story-001 §Acceptance Criteria.
## AC-7 (class cache resolution) is implicit: test file successfully instantiates
##   TurnOrderRunner + UnitTurnState; G-14 import pass verified pre-run.
## AC-8 (regression baseline) is verified by the full-suite run post-implementation.
##
## Governing ADR: ADR-0011 — Turn Order / Action Management (Accepted 2026-04-30).
## Related TRs:   TR-turn-order-002, TR-turn-order-003, TR-turn-order-004,
##                TR-turn-order-022.
##
## TEST APPROACH:
##   AC-1..AC-5 use structural FileAccess.get_file_as_string + content.contains()
##   assertions — mirrors terrain_effect_skeleton_test.gd precedent (G-22 pattern).
##   AC-6 uses direct instantiation + identity / value / mutation-independence
##   assertions on a live UnitTurnState instance.
##
## ISOLATION DISCIPLINE (ADR-0011 §Risks R-5):
##   before_test() is included as a no-op per G-15 discipline for forward
##   compatibility (story-002+ will add _unit_states / _queue / signal-disconnect
##   resets here per the G-15 6-element list in ADR-0011 §Decision).
##   NOTE: must be `before_test()` (canonical GdUnit4 v6.1.2 hook);
##   `before_each()` is silently ignored by the runner (gotcha G-15).

const TURN_ORDER_RUNNER_PATH: String = "res://src/core/turn_order_runner.gd"
const UNIT_TURN_STATE_PATH: String = "res://src/core/unit_turn_state.gd"
const TURN_ORDER_SNAPSHOT_PATH: String = "res://src/core/turn_order_snapshot.gd"
const TURN_ORDER_ENTRY_PATH: String = "res://src/core/turn_order_entry.gd"


func before_test() -> void:
	# No-op for skeleton story. Story-002+ will add G-15 reset list here:
	#   _runner._unit_states.clear()
	#   _runner._queue.clear()
	#   _runner._round_number = 0
	#   _runner._queue_index = 0
	#   _runner._round_state = TurnOrderRunner.RoundState.BATTLE_NOT_STARTED
	#   if GameBus.unit_died.is_connected(_runner._on_unit_died):
	#       GameBus.unit_died.disconnect(_runner._on_unit_died)
	pass


# ── AC-1: TurnOrderRunner class declaration + Node inheritance ────────────────


## AC-1: TurnOrderRunner is declared as `class_name TurnOrderRunner extends Node`
## (NOT extends RefCounted; NOT stateless-static).
## Given: src/core/turn_order_runner.gd exists post-write.
## When:  file content inspected via FileAccess structural assertion.
## Then:  contains literal `class_name TurnOrderRunner` AND `extends Node`
##        (battle-scoped Node form per ADR-0011 §Decision).
func test_turn_order_runner_class_declaration_extends_node() -> void:
	var content: String = FileAccess.get_file_as_string(TURN_ORDER_RUNNER_PATH)

	assert_bool(content.contains("class_name TurnOrderRunner")).override_failure_message(
		"turn_order_runner.gd must declare `class_name TurnOrderRunner`; "
		+ "not found in source"
	).is_true()

	assert_bool(content.contains("extends Node")).override_failure_message(
		"turn_order_runner.gd must extend Node (battle-scoped per ADR-0011); "
		+ "NOT RefCounted, NOT stateless-static — `extends Node` not found in source"
	).is_true()


# ── AC-2: 5 instance fields with exact types ──────────────────────────────────


## AC-2: All 5 instance fields declared with exact types per ADR-0011 §Decision.
## Given: src/core/turn_order_runner.gd exists post-write.
## When:  file content inspected for each field declaration substring.
## Then:  _queue: Array[int], _queue_index: int, _round_number: int,
##        _unit_states: Dictionary[int, UnitTurnState], _round_state: RoundState
##        all present as typed declarations.
func test_turn_order_runner_five_instance_fields_typed() -> void:
	var content: String = FileAccess.get_file_as_string(TURN_ORDER_RUNNER_PATH)

	assert_bool(content.contains("_queue: Array[int]")).override_failure_message(
		"turn_order_runner.gd must declare `_queue: Array[int]`; not found"
	).is_true()

	assert_bool(content.contains("_queue_index: int")).override_failure_message(
		"turn_order_runner.gd must declare `_queue_index: int`; not found"
	).is_true()

	assert_bool(content.contains("_round_number: int")).override_failure_message(
		"turn_order_runner.gd must declare `_round_number: int`; not found"
	).is_true()

	assert_bool(content.contains("_unit_states: Dictionary[int, UnitTurnState]")).override_failure_message(
		("turn_order_runner.gd must declare "
		+ "`_unit_states: Dictionary[int, UnitTurnState]`; not found")
	).is_true()

	assert_bool(content.contains("_round_state: RoundState")).override_failure_message(
		"turn_order_runner.gd must declare `_round_state: RoundState`; not found"
	).is_true()


## AC-2 (enum values): RoundState enum contains all 6 required values.
## Given: src/core/turn_order_runner.gd exists post-write.
## When:  file content inspected for each RoundState enum value.
## Then:  BATTLE_NOT_STARTED, BATTLE_INITIALIZING, ROUND_STARTING, ROUND_ACTIVE,
##        ROUND_ENDING, BATTLE_ENDED all present in enum declaration.
func test_turn_order_runner_round_state_enum_six_values() -> void:
	var content: String = FileAccess.get_file_as_string(TURN_ORDER_RUNNER_PATH)

	for value: String in [
		"BATTLE_NOT_STARTED",
		"BATTLE_INITIALIZING",
		"ROUND_STARTING",
		"ROUND_ACTIVE",
		"ROUND_ENDING",
		"BATTLE_ENDED",
	]:
		assert_bool(content.contains(value)).override_failure_message(
			("turn_order_runner.gd RoundState enum must contain `%s`; "
			+ "not found in source") % value
		).is_true()


# ── AC-3: UnitTurnState class declaration + 6 fields ─────────────────────────


## AC-3: UnitTurnState is declared as `class_name UnitTurnState extends RefCounted`
## with exactly 6 typed fields per ADR-0011 §Decision.
## Given: src/core/unit_turn_state.gd exists post-write.
## When:  file content inspected via FileAccess structural assertion.
## Then:  class_name UnitTurnState + extends RefCounted + all 6 field names present.
func test_unit_turn_state_class_declaration_and_six_fields() -> void:
	var content: String = FileAccess.get_file_as_string(UNIT_TURN_STATE_PATH)

	assert_bool(content.contains("class_name UnitTurnState")).override_failure_message(
		"unit_turn_state.gd must declare `class_name UnitTurnState`; not found"
	).is_true()

	assert_bool(content.contains("extends RefCounted")).override_failure_message(
		"unit_turn_state.gd must extend RefCounted (NOT Resource per ADR-0011 CR-1b); "
		+ "`extends RefCounted` not found"
	).is_true()

	for field: String in [
		"unit_id",
		"move_token_spent",
		"action_token_spent",
		"accumulated_move_cost",
		"acted_this_turn",
		"turn_state",
	]:
		assert_bool(content.contains(field)).override_failure_message(
			("unit_turn_state.gd must declare field `%s`; not found in source") % field
		).is_true()


# ── AC-4 + AC-5: TurnOrderSnapshot + TurnOrderEntry classes ──────────────────


## AC-4: TurnOrderSnapshot is declared as `class_name TurnOrderSnapshot extends RefCounted`
## with exactly 2 fields: round_number: int and queue: Array[TurnOrderEntry].
## Given: src/core/turn_order_snapshot.gd exists post-write.
## When:  file content inspected via FileAccess structural assertion.
## Then:  class_name + extends RefCounted + both field names present.
func test_turn_order_snapshot_class_declaration_and_two_fields() -> void:
	var content: String = FileAccess.get_file_as_string(TURN_ORDER_SNAPSHOT_PATH)

	assert_bool(content.contains("class_name TurnOrderSnapshot")).override_failure_message(
		"turn_order_snapshot.gd must declare `class_name TurnOrderSnapshot`; not found"
	).is_true()

	assert_bool(content.contains("extends RefCounted")).override_failure_message(
		"turn_order_snapshot.gd must extend RefCounted (NOT Resource per ADR-0011 CR-1b); "
		+ "`extends RefCounted` not found"
	).is_true()

	assert_bool(content.contains("round_number")).override_failure_message(
		"turn_order_snapshot.gd must declare field `round_number`; not found"
	).is_true()

	assert_bool(content.contains("queue")).override_failure_message(
		"turn_order_snapshot.gd must declare field `queue`; not found"
	).is_true()

	assert_bool(content.contains("Array[TurnOrderEntry]")).override_failure_message(
		("turn_order_snapshot.gd queue field must be typed `Array[TurnOrderEntry]`; "
		+ "not found in source")
	).is_true()


## AC-5: TurnOrderEntry is declared as `class_name TurnOrderEntry extends RefCounted`
## with exactly 5 fields per ADR-0011 §Decision.
## Given: src/core/turn_order_entry.gd exists post-write.
## When:  file content inspected via FileAccess structural assertion.
## Then:  class_name + extends RefCounted + all 5 field names present.
func test_turn_order_entry_class_declaration_and_five_fields() -> void:
	var content: String = FileAccess.get_file_as_string(TURN_ORDER_ENTRY_PATH)

	assert_bool(content.contains("class_name TurnOrderEntry")).override_failure_message(
		"turn_order_entry.gd must declare `class_name TurnOrderEntry`; not found"
	).is_true()

	assert_bool(content.contains("extends RefCounted")).override_failure_message(
		"turn_order_entry.gd must extend RefCounted (NOT Resource per ADR-0011 CR-1b); "
		+ "`extends RefCounted` not found"
	).is_true()

	for field: String in [
		"unit_id",
		"is_player_controlled",
		"initiative",
		"acted_this_turn",
		"turn_state",
	]:
		assert_bool(content.contains(field)).override_failure_message(
			("turn_order_entry.gd must declare field `%s`; not found in source") % field
		).is_true()


# ── AC-6: UnitTurnState.snapshot() identity + value parity + independence ─────


## AC-6 (identity): snapshot() returns a distinct object — NOT the same reference.
## Given: a UnitTurnState with non-default unit_id = 42.
## When:  original.snapshot() called.
## Then:  copy != original (object identity differs; not the same RefCounted instance).
func test_unit_turn_state_snapshot_returns_distinct_object() -> void:
	# Arrange
	var original: UnitTurnState = UnitTurnState.new()
	original.unit_id = 42

	# Act
	var copy: UnitTurnState = original.snapshot()

	# Assert — identity differs (not reference-equal)
	assert_bool(copy != original).override_failure_message(
		("snapshot() must return a NEW UnitTurnState (distinct object); "
		+ "got the SAME reference as the original — field-by-field copy not implemented")
	).is_true()


## AC-6 (value parity): snapshot() copies all 6 field values from the original.
## Given: a UnitTurnState with non-default values for all 6 fields.
## When:  original.snapshot() called.
## Then:  all 6 fields on the copy equal the original's values.
func test_unit_turn_state_snapshot_all_six_fields_copied() -> void:
	# Arrange — set non-default values for all 6 fields
	var original: UnitTurnState = UnitTurnState.new()
	original.unit_id = 7
	original.move_token_spent = true
	original.action_token_spent = true
	original.accumulated_move_cost = 3
	original.acted_this_turn = true
	original.turn_state = TurnOrderRunner.TurnState.ACTING

	# Act
	var copy: UnitTurnState = original.snapshot()

	# Assert — all 6 fields match
	assert_int(copy.unit_id).override_failure_message(
		"snapshot() unit_id must equal original; expected 7, got %d" % copy.unit_id
	).is_equal(7)

	assert_bool(copy.move_token_spent).override_failure_message(
		"snapshot() move_token_spent must equal original (true)"
	).is_true()

	assert_bool(copy.action_token_spent).override_failure_message(
		"snapshot() action_token_spent must equal original (true)"
	).is_true()

	assert_int(copy.accumulated_move_cost).override_failure_message(
		("snapshot() accumulated_move_cost must equal original; "
		+ "expected 3, got %d") % copy.accumulated_move_cost
	).is_equal(3)

	assert_bool(copy.acted_this_turn).override_failure_message(
		"snapshot() acted_this_turn must equal original (true)"
	).is_true()

	assert_int(copy.turn_state as int).override_failure_message(
		("snapshot() turn_state must equal TurnOrderRunner.TurnState.ACTING; "
		+ "got %d") % (copy.turn_state as int)
	).is_equal(TurnOrderRunner.TurnState.ACTING as int)


## AC-6 (mutation independence): mutating a snapshot field does NOT affect original.
## Given: a UnitTurnState original with acted_this_turn = false.
## When:  snapshot taken; copy.acted_this_turn flipped to true.
## Then:  original.acted_this_turn remains false.
func test_unit_turn_state_snapshot_mutation_independence() -> void:
	# Arrange
	var original: UnitTurnState = UnitTurnState.new()
	original.unit_id = 5
	original.acted_this_turn = false

	# Act — take snapshot, mutate the copy
	var copy: UnitTurnState = original.snapshot()
	copy.acted_this_turn = true

	# Assert — original is unaffected (RefCounted value semantics; no aliasing)
	assert_bool(original.acted_this_turn).override_failure_message(
		("Mutating snapshot.acted_this_turn must NOT affect original.acted_this_turn; "
		+ "original should be false but got true — snapshot() returned a reference, "
		+ "not a copy")
	).is_false()
