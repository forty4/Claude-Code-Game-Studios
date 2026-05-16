## hidden_condition_evaluator_test.gd
##
## Pure-function evaluator covering fate_threshold predicate + structural-guard
## fall-throughs (missing field, unknown op, malformed spec).
extends GdUnitTestSuite


# ─── fate_threshold — happy path per op ───────────────────────────────────────


func test_fate_threshold_gte_passes_when_actual_meets_threshold() -> void:
	# Arrange
	var cond: Dictionary = {"type": "fate_threshold", "field": "assassin_kills", "op": ">=", "value": 2}
	var fate: Dictionary = {"assassin_kills": 2}
	# Act
	var result: bool = HiddenConditionEvaluator.evaluate(cond, fate)
	# Assert
	assert_bool(result).is_true()


func test_fate_threshold_gte_passes_when_actual_above_threshold() -> void:
	var cond: Dictionary = {"type": "fate_threshold", "field": "assassin_kills", "op": ">=", "value": 2}
	var fate: Dictionary = {"assassin_kills": 5}
	assert_bool(HiddenConditionEvaluator.evaluate(cond, fate)).is_true()


func test_fate_threshold_gte_fails_when_actual_below_threshold() -> void:
	var cond: Dictionary = {"type": "fate_threshold", "field": "assassin_kills", "op": ">=", "value": 2}
	var fate: Dictionary = {"assassin_kills": 1}
	assert_bool(HiddenConditionEvaluator.evaluate(cond, fate)).is_false()


func test_fate_threshold_gt_strict() -> void:
	var cond: Dictionary = {"type": "fate_threshold", "field": "rear_attacks", "op": ">", "value": 0}
	assert_bool(HiddenConditionEvaluator.evaluate(cond, {"rear_attacks": 0})).is_false()
	assert_bool(HiddenConditionEvaluator.evaluate(cond, {"rear_attacks": 1})).is_true()


func test_fate_threshold_eq_uses_approx_for_float() -> void:
	var cond: Dictionary = {"type": "fate_threshold", "field": "tank_alive_hp_pct", "op": "==", "value": 1.0}
	# Float-approx tolerance is the only sane equality for fractional HP.
	assert_bool(HiddenConditionEvaluator.evaluate(cond, {"tank_alive_hp_pct": 1.0})).is_true()
	assert_bool(HiddenConditionEvaluator.evaluate(cond, {"tank_alive_hp_pct": 0.99})).is_false()


func test_fate_threshold_lte() -> void:
	var cond: Dictionary = {"type": "fate_threshold", "field": "formation_turns", "op": "<=", "value": 1}
	assert_bool(HiddenConditionEvaluator.evaluate(cond, {"formation_turns": 0})).is_true()
	assert_bool(HiddenConditionEvaluator.evaluate(cond, {"formation_turns": 1})).is_true()
	assert_bool(HiddenConditionEvaluator.evaluate(cond, {"formation_turns": 2})).is_false()


func test_fate_threshold_lt_strict() -> void:
	var cond: Dictionary = {"type": "fate_threshold", "field": "rear_attacks", "op": "<", "value": 3}
	assert_bool(HiddenConditionEvaluator.evaluate(cond, {"rear_attacks": 2})).is_true()
	assert_bool(HiddenConditionEvaluator.evaluate(cond, {"rear_attacks": 3})).is_false()


# ─── Structural guards (fall-through to false, never error) ───────────────────


func test_empty_condition_returns_false() -> void:
	assert_bool(HiddenConditionEvaluator.evaluate({}, {"assassin_kills": 99})).is_false()


func test_unknown_condition_type_returns_false() -> void:
	var cond: Dictionary = {"type": "fate_xor_meta", "field": "x", "op": ">=", "value": 0}
	assert_bool(HiddenConditionEvaluator.evaluate(cond, {"x": 1})).is_false()


func test_missing_fate_field_returns_false() -> void:
	# field "boss_killed" not present in this fate snapshot — guards down to false.
	var cond: Dictionary = {"type": "fate_threshold", "field": "boss_killed", "op": ">=", "value": 1}
	assert_bool(HiddenConditionEvaluator.evaluate(cond, {"assassin_kills": 5})).is_false()


func test_unknown_op_returns_false() -> void:
	var cond: Dictionary = {"type": "fate_threshold", "field": "x", "op": "BOGUS_OP", "value": 0}
	assert_bool(HiddenConditionEvaluator.evaluate(cond, {"x": 99})).is_false()


func test_missing_value_returns_false() -> void:
	# value key absent — get() returns null → guard returns false.
	var cond: Dictionary = {"type": "fate_threshold", "field": "x", "op": ">="}
	assert_bool(HiddenConditionEvaluator.evaluate(cond, {"x": 99})).is_false()


func test_non_numeric_actual_returns_false() -> void:
	# fate_data field present but not a number (e.g., boss_killed is bool) — false.
	var cond: Dictionary = {"type": "fate_threshold", "field": "boss_killed", "op": ">=", "value": 1}
	assert_bool(HiddenConditionEvaluator.evaluate(cond, {"boss_killed": true})).is_false()


func test_non_numeric_threshold_returns_false() -> void:
	var cond: Dictionary = {"type": "fate_threshold", "field": "x", "op": ">=", "value": "two"}
	assert_bool(HiddenConditionEvaluator.evaluate(cond, {"x": 5})).is_false()


# ─── Determinism — same inputs, same output across many runs ──────────────────


func test_evaluator_is_deterministic_across_repeated_calls() -> void:
	var cond: Dictionary = {"type": "fate_threshold", "field": "assassin_kills", "op": ">=", "value": 2}
	var fate: Dictionary = {"assassin_kills": 2}
	for i in 100:
		assert_bool(HiddenConditionEvaluator.evaluate(cond, fate)).is_true()
