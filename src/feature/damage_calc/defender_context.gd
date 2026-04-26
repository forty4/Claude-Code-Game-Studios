## DefenderContext — immutable-by-convention snapshot of the defending unit's terrain modifiers.
## terrain_def and terrain_evasion are pre-clamped upstream by Terrain Effect (ADR-0008);
## this wrapper does NOT re-validate ranges. Constructed exclusively via make() in production code.
class_name DefenderContext extends RefCounted

var unit_id: StringName
var terrain_def: int = 0       # already clamped [-30, +30] by Terrain Effect (ADR-0008 opaque contract)
var terrain_evasion: int = 0   # already clamped [0, 30] by Terrain Effect (ADR-0008 opaque contract)


## Factory — the only sanctioned construction path in production code.
## Parameter order mirrors field declaration order.
static func make(
		unit_id: StringName,
		terrain_def: int,
		terrain_evasion: int) -> DefenderContext:
	var result := DefenderContext.new()
	result.unit_id = unit_id
	result.terrain_def = terrain_def
	result.terrain_evasion = terrain_evasion
	return result
