## DefenderContext — immutable-by-convention snapshot of the defending unit's terrain modifiers.
## terrain_def and terrain_evasion are pre-clamped upstream by Terrain Effect (ADR-0008);
## this wrapper does NOT re-validate ranges. Constructed exclusively via make() in production code.
class_name DefenderContext extends RefCounted

var unit_id: StringName
## Pre-Damage-Calc-clamp DEF from HP/Status. Set at Grid Battle from
## hp_status.get_modified_stat(unit_id, &"phys_def" or &"mag_def") with
## the stat name selected by Grid Battle from modifiers.attack_type.
## DamageCalc applies clampi(raw_def, 1, DEF_CAP) per ADR-0012 §8 + CR-3.
var raw_def: int = 0
var terrain_def: int = 0       # already clamped [-30, +30] by Terrain Effect (ADR-0008 opaque contract)
var terrain_evasion: int = 0   # already clamped [0, 30] by Terrain Effect (ADR-0008 opaque contract)


## Factory — the only sanctioned construction path in production code.
## Parameter order mirrors field declaration order.
static func make(
		unit_id: StringName,
		raw_def: int,
		terrain_def: int,
		terrain_evasion: int) -> DefenderContext:
	var result := DefenderContext.new()
	result.unit_id = unit_id
	result.raw_def = raw_def
	result.terrain_def = terrain_def
	result.terrain_evasion = terrain_evasion
	return result
