## HiddenConditionEvaluator — pure predicate evaluator for chapter hidden conditions.
##
## Reads (condition_spec, fate_data) → bool. Used by DefaultDestinyBranchJudge
## at BEAT_7 to decide whether a hidden-WIN branch fires instead of WIN_default.
##
## Determinism (CR-DB-2 alignment): no static var, no instance state across calls,
## no RNG, no wall-clock dependency, no autoload state read. All inputs travel
## explicitly through the static method signature.
##
## Pillar 2 (운명은 바꿀 수 있다) — the predicate-evaluation surface is the
## minimum primitive needed to express "hidden condition" without requiring
## per-chapter code. New condition types are added here, not in chapter data.
##
## Supported condition types (closed enumeration; extend at addition time):
##   - "fate_threshold": numeric threshold check against a fate_data field.
##     Spec: { "type": "fate_threshold", "field": String, "op": String, "value": Number,
##             "signature_relief"?: { "per_active_signature": int, "min_value": Number } }
##     Ops: ">=", ">", "==", "<=", "<"
##     Returns false if field is missing from fate_data, op is unknown, or
##     the comparison would coerce types ambiguously.
##
##     Optional signature_relief (영걸전식 cascade-aware threshold easing, S65+):
##     when present AND fate_data.active_signature_count > 0, the threshold is
##     reduced by (per_active_signature * active_signature_count), clamped to
##     min_value. Embodies the "역사를 더 많이 바꿨을수록 천명의 무게가
##     가벼워진다" finale design — ch25 칠성단 회생이 활성 시그니처 N개에
##     따라 점진적으로 쉬워진다. relief is applied for ">=" / ">" ops where
##     "smaller threshold = easier"; ignored for "<=" / "<" / "==".
##
## Future condition types (NOT yet implemented; add when authored):
##   - "fate_all": every sub-condition must pass (AND)
##   - "fate_any": at least one sub-condition passes (OR)
class_name HiddenConditionEvaluator
extends RefCounted


## Evaluates the condition Dictionary against the fate_data snapshot.
## Returns true iff the predicate is satisfied; returns false on any
## structural shortcoming (missing field, unknown op, malformed spec).
##
## [param condition] Predicate spec Dictionary; see class doc for shape.
## [param fate_data] Battle-end fate-counter snapshot (BattleOutcome.fate_data).
## [return] true iff the predicate fires.
static func evaluate(condition: Dictionary, fate_data: Dictionary) -> bool:
	if condition.is_empty():
		return false
	var cond_type: String = condition.get("type", "") as String
	match cond_type:
		"fate_threshold":
			return _eval_fate_threshold(condition, fate_data)
		_:
			return false


static func _eval_fate_threshold(condition: Dictionary, fate_data: Dictionary) -> bool:
	var field: String = condition.get("field", "") as String
	if field.is_empty() or not fate_data.has(field):
		return false
	var op: String = condition.get("op", "") as String
	var threshold: Variant = condition.get("value", null)
	if threshold == null:
		return false
	var actual: Variant = fate_data[field]
	# Numeric coercion: int/float only. Reject other types defensively.
	if not (actual is int or actual is float):
		return false
	if not (threshold is int or threshold is float):
		return false
	var lhs: float = float(actual)
	var rhs: float = _apply_signature_relief(float(threshold), op, condition, fate_data)
	match op:
		">=": return lhs >= rhs
		">":  return lhs > rhs
		"==": return is_equal_approx(lhs, rhs)
		"<=": return lhs <= rhs
		"<":  return lhs < rhs
		_:    return false


## Reduces the threshold by (per_active_signature * active_signature_count),
## clamped to min_value, when signature_relief is declared AND op is an
## "easier when smaller" comparator (">=" / ">"). Other ops are returned
## verbatim — easing a "<=" / "<" threshold would invert intent, and "=="
## relief would silently move the success window.
static func _apply_signature_relief(
	base_threshold: float,
	op: String,
	condition: Dictionary,
	fate_data: Dictionary,
) -> float:
	if not (op == ">=" or op == ">"):
		return base_threshold
	if not condition.has("signature_relief"):
		return base_threshold
	var relief: Dictionary = condition["signature_relief"] as Dictionary
	var per_var: Variant = relief.get("per_active_signature", null)
	var min_var: Variant = relief.get("min_value", null)
	if per_var == null or min_var == null:
		return base_threshold
	if not (per_var is int or per_var is float):
		return base_threshold
	if not (min_var is int or min_var is float):
		return base_threshold
	var per_active: float = float(per_var)
	var min_value: float = float(min_var)
	var count_var: Variant = fate_data.get("active_signature_count", 0)
	var active_count: float = float(count_var) if (count_var is int or count_var is float) else 0.0
	if active_count <= 0.0:
		return base_threshold
	var eased: float = base_threshold - per_active * active_count
	return maxf(eased, min_value)
