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
##     Spec: { "type": "fate_threshold", "field": String, "op": String, "value": Number }
##     Ops: ">=", ">", "==", "<=", "<"
##     Returns false if field is missing from fate_data, op is unknown, or
##     the comparison would coerce types ambiguously.
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
	var rhs: float = float(threshold)
	match op:
		">=": return lhs >= rhs
		">":  return lhs > rhs
		"==": return is_equal_approx(lhs, rhs)
		"<=": return lhs <= rhs
		"<":  return lhs < rhs
		_:    return false
