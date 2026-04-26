## ResolveModifiers — per-call attack parameters injected by Grid Battle into DamageCalc.resolve().
## rng is mandatory and must be a live RandomNumberGenerator instance (never null).
## Constructed exclusively via make() in production code.
class_name ResolveModifiers extends RefCounted

enum AttackType { PHYSICAL, MAGICAL }

var attack_type: AttackType = AttackType.PHYSICAL
var source_flags: Array[StringName] = []
var direction_rel: StringName = &"FRONT"   # FRONT / FLANK / REAR — StringName literals only
var is_counter: bool = false
var skill_id: String = ""                  # "" = not a skill stub
var rng: RandomNumberGenerator             # typed; never Variant — null triggers invariant_violation:rng_null
var round_number: int = 1                  # >= 1; gate asserts in DamageCalc.resolve() (story-003)
var rally_bonus: float = 0.0               # [0.0, 0.10] — upstream-capped in Grid Battle CR-15
var formation_atk_bonus: float = 0.0       # [0.0, 0.05] — upstream-capped in Formation Bonus F-FB-3
var formation_def_bonus: float = 0.0       # [0.0, 0.05] — upstream-capped in Formation Bonus F-FB-3

## Turn Order interface stub — provisional ADR-0011 workaround per ADR-0012 §8.
## Defaults to a no-op returning false (defender has not acted this turn).
## Production wiring (story-007 Grid Battle integration) will inject TurnOrder.get_acted_this_turn.
## Test fixtures inject a fresh Callable per test per AC-DC-09.
var acted_this_turn_callable: Callable = Callable()


## Factory — the only sanctioned construction path in production code.
## Required params first (attack_type, rng, direction_rel, round_number); optional params follow
## with defaults matching field defaults. Parameter order mirrors field declaration order.
static func make(
		attack_type: AttackType,
		rng: RandomNumberGenerator,
		direction_rel: StringName,
		round_number: int,
		is_counter: bool = false,
		skill_id: String = "",
		source_flags: Array[StringName] = [],
		rally_bonus: float = 0.0,
		formation_atk_bonus: float = 0.0,
		formation_def_bonus: float = 0.0,
		acted_this_turn_callable: Callable = Callable()) -> ResolveModifiers:
	var result := ResolveModifiers.new()
	result.attack_type = attack_type
	result.rng = rng
	result.direction_rel = direction_rel
	result.round_number = round_number
	result.is_counter = is_counter
	result.skill_id = skill_id
	# source_flags assigned directly — caller constructs per-call (production) or per-test (tests).
	# DamageCalc.resolve() copies via assign() (G-2 pattern) before appending provenance tags.
	result.source_flags = source_flags
	result.rally_bonus = rally_bonus
	result.formation_atk_bonus = formation_atk_bonus
	result.formation_def_bonus = formation_def_bonus
	result.acted_this_turn_callable = acted_this_turn_callable
	return result
