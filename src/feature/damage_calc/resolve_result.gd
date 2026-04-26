## ResolveResult — output of DamageCalc.resolve(). Constructed via hit() or miss() factories only.
## kind == HIT: resolved_damage is in [1, 180]. kind == MISS: resolved_damage is 0 (immaterial).
## source_flags carries invariant-violation tags (e.g. &"invariant_violation:rng_null") on MISS paths.
class_name ResolveResult extends RefCounted

enum Kind { HIT, MISS }
enum AttackType { PHYSICAL, MAGICAL }

var kind: Kind
var resolved_damage: int = 0
var attack_type: AttackType = AttackType.PHYSICAL
var source_flags: Array[StringName] = []   # NEVER Set, NEVER Dictionary (ADR-0012 §2)
var vfx_tags: Array[StringName] = []


## HIT factory — damage must be >= 1 (enforced by caller pipeline, not re-validated here).
## Parameter order: damage, attack type, source flags, vfx tags.
## Caller (DamageCalc.resolve) constructs flags and vfx as always-new Arrays (ADR-0012 §12);
## this factory assigns them directly (no extra copy). G-2: assign() used at the call site
## in DamageCalc to preserve typed-Array annotation when copying modifiers.source_flags.
static func hit(
		damage: int,
		atk_type: AttackType,
		flags: Array[StringName],
		vfx: Array[StringName]) -> ResolveResult:
	var result := ResolveResult.new()
	result.kind = Kind.HIT
	result.resolved_damage = damage
	result.attack_type = atk_type
	result.source_flags = flags
	result.vfx_tags = vfx
	return result


## MISS factory — resolved_damage stays 0. flags defaults to empty array (zero-args overload).
## attack_type left at field default (PHYSICAL) — immaterial on MISS per ADR-0012 §2 ("0 on MISS (immaterial)").
## Caller always passes a freshly-constructed Array[StringName] literal (never reuses across calls).
static func miss(flags: Array[StringName] = []) -> ResolveResult:
	var result := ResolveResult.new()
	result.kind = Kind.MISS
	result.resolved_damage = 0
	result.source_flags = flags
	return result
