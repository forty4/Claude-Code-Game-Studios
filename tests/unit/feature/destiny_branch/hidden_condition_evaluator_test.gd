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


# ─── signature_relief — 영걸전식 cascade-aware threshold easing (S65+) ────────


## ch25 칠성단 회생 매력 보강 — 활성 시그니처 N개당 threshold -1 (min clamp 3).
## 0 시그니처: 6턴 (원본 어려움), 3 시그니처: 4턴 (절반 cascade), 5 시그니처: 3턴 (min).


## When signature_relief is declared AND fate_data.active_signature_count == 0,
## the threshold is unchanged — relief only kicks in for players who built
## cascading signatures in prior chapters.
func test_signature_relief_no_active_signatures_keeps_base_threshold() -> void:
	var cond: Dictionary = {
		"type": "fate_threshold", "field": "qixing_turns", "op": ">=", "value": 6,
		"signature_relief": {"per_active_signature": 1, "min_value": 3},
	}
	# 5턴 stand — 0 시그니처면 6턴 필요 → fail.
	assert_bool(HiddenConditionEvaluator.evaluate(
		cond, {"qixing_turns": 5, "active_signature_count": 0}
	)).override_failure_message(
		"0 시그니처 → threshold=6 → 5턴은 fail"
	).is_false()
	# 6턴 stand — 0 시그니처면 6턴 필요 → pass.
	assert_bool(HiddenConditionEvaluator.evaluate(
		cond, {"qixing_turns": 6, "active_signature_count": 0}
	)).is_true()


## Linear relief: each active signature lowers the threshold by per_active_signature.
## 2 시그니처 활성 → threshold 6 - 2*1 = 4. 4턴 stand 충분, 3턴은 부족.
func test_signature_relief_two_active_lowers_threshold_to_four() -> void:
	var cond: Dictionary = {
		"type": "fate_threshold", "field": "qixing_turns", "op": ">=", "value": 6,
		"signature_relief": {"per_active_signature": 1, "min_value": 3},
	}
	# 4턴 stand — 2 시그니처면 effective threshold 4 → pass.
	assert_bool(HiddenConditionEvaluator.evaluate(
		cond, {"qixing_turns": 4, "active_signature_count": 2}
	)).override_failure_message(
		"2 시그니처 → effective threshold 4 → 4턴 stand pass"
	).is_true()
	# 3턴 stand — 2 시그니처면 4턴 필요 → fail.
	assert_bool(HiddenConditionEvaluator.evaluate(
		cond, {"qixing_turns": 3, "active_signature_count": 2}
	)).is_false()


## min_value clamp: relief cannot push threshold below min_value. 5 시그니처
## naively → 6 - 5 = 1, but min_value 3 clamps. 칠성단이 "최소한의 천명"으로 유지.
func test_signature_relief_clamps_at_min_value() -> void:
	var cond: Dictionary = {
		"type": "fate_threshold", "field": "qixing_turns", "op": ">=", "value": 6,
		"signature_relief": {"per_active_signature": 1, "min_value": 3},
	}
	# 5 시그니처 + 3턴 stand: clamp 적용 (min 3) → pass.
	assert_bool(HiddenConditionEvaluator.evaluate(
		cond, {"qixing_turns": 3, "active_signature_count": 5}
	)).override_failure_message(
		"5 시그니처 → effective threshold min 3 (not 1) → 3턴 stand pass"
	).is_true()
	# 5 시그니처 + 2턴 stand: min_value 3 clamp → fail (천명의 최소선).
	assert_bool(HiddenConditionEvaluator.evaluate(
		cond, {"qixing_turns": 2, "active_signature_count": 5}
	)).override_failure_message(
		"5 시그니처여도 min_value 3 clamp 적용 → 2턴 stand fail"
	).is_false()


## When op is "<=" / "<" / "==", signature_relief is IGNORED. Easing those
## inverts intent (smaller threshold = harder) or moves the success window.
func test_signature_relief_ignored_for_lte_and_eq_ops() -> void:
	# "<=" with relief should be IGNORED (base 5 threshold).
	var lte_cond: Dictionary = {
		"type": "fate_threshold", "field": "formation_turns", "op": "<=", "value": 5,
		"signature_relief": {"per_active_signature": 1, "min_value": 1},
	}
	# 5 active sigs would NAIVELY lower threshold to 1, failing the formation_turns=4 check.
	# Correct behavior: relief ignored, threshold stays at 5, 4 <= 5 passes.
	assert_bool(HiddenConditionEvaluator.evaluate(
		lte_cond, {"formation_turns": 4, "active_signature_count": 5}
	)).override_failure_message(
		"'<=' op MUST ignore signature_relief — threshold stays at 5"
	).is_true()


## Missing active_signature_count in fate_data defaults to 0 → no relief applied.
## Backward compat: pre-S65 fate_data snapshots safely fall through.
func test_signature_relief_missing_count_field_defaults_to_no_relief() -> void:
	var cond: Dictionary = {
		"type": "fate_threshold", "field": "qixing_turns", "op": ">=", "value": 6,
		"signature_relief": {"per_active_signature": 1, "min_value": 3},
	}
	# 5턴 stand, no active_signature_count key → defaults to 0 → 6턴 필요 → fail.
	assert_bool(HiddenConditionEvaluator.evaluate(
		cond, {"qixing_turns": 5}
	)).override_failure_message(
		"active_signature_count missing → no relief applied"
	).is_false()


## Malformed signature_relief (non-numeric per_active or min_value) → relief
## not applied; base threshold returned. Defensive against author typos.
func test_signature_relief_malformed_falls_through_to_base() -> void:
	var cond: Dictionary = {
		"type": "fate_threshold", "field": "qixing_turns", "op": ">=", "value": 6,
		"signature_relief": {"per_active_signature": "one", "min_value": 3},
	}
	# 5턴 stand + 3 sigs would lower to 3 if relief applied, but malformed
	# string per_active_signature → relief skipped → 6 needed → fail.
	assert_bool(HiddenConditionEvaluator.evaluate(
		cond, {"qixing_turns": 5, "active_signature_count": 3}
	)).is_false()
