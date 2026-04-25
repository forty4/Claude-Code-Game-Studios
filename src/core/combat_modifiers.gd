## CombatModifiers — clamped terrain + elevation modifiers for one combat pair.
##
## Returned by TerrainEffect.get_combat_modifiers() for use by Damage Calc.
## All int fields carry clamped values (MAX_DEFENSE_REDUCTION, MAX_EVASION applied
## in story-005). Elevation deltas may be negative (e.g. elevation_def_mod = -8).
##
## Ratified by ADR-0008 §Decision 6 + §Key Interfaces + TR-terrain-effect-009
## (CR-5: bridge_no_flank flag denormalises the &"bridge_no_flank" StringName
## entry from special_rules for O(1) lookup by Damage Calc). Both fields MUST
## be set consistently when populated by get_combat_modifiers() in story-005.
##
## MUST extend Resource, declare class_name CombatModifiers, and annotate every
## persisted field with @export. Non-@export fields are SILENTLY DROPPED by
## ResourceSaver — see ADR-0003 §Schema Stability.
##
## class_name collision check: CombatModifiers verified collision-free with
## Godot 4.6 built-ins on 2026-04-25 (ADR-0008 Verification Required §3, CLOSED).
##
## WARNING (G-2 — typed-array .duplicate() demotion): When story-005 populates
## special_rules arrays from JSON in TerrainEffect._apply_config(), do NOT use
## .duplicate() on a source Array[StringName]. Use explicit typed assignment:
##   var rules: Array[StringName] = []
##   rules.assign(source_array)
## or fresh-construction element-by-element. .duplicate() demotes typed arrays
## to untyped Array in Godot 4.x and will silently break ResourceSaver typing.
class_name CombatModifiers
extends Resource

## Defender's terrain defence modifier (clamped, percentage points). May be
## negative (e.g. elevation penalty). Range per ADR-0008: -MAX_DEFENSE_REDUCTION..+25.
@export var defender_terrain_def: int = 0

## Defender's terrain evasion modifier (clamped, percentage points). May be
## negative. Range per ADR-0008: 0..MAX_EVASION in normal terrain; signed for
## elevation edge cases.
@export var defender_terrain_eva: int = 0

## Attacker's elevation attack modifier (signed, percentage points). Positive
## when attacker is uphill; negative when downhill.
@export var elevation_atk_mod: int = 0

## Defender's elevation defence modifier (signed, percentage points). Positive
## when defender is uphill; negative when downhill.
@export var elevation_def_mod: int = 0

## Denormalised flag: true when the defender occupies a BRIDGE tile (CR-5,
## TR-terrain-effect-009). Damage Calc collapses FLANK → FRONT when this is true.
## Must be set alongside &"bridge_no_flank" in special_rules by story-005's
## get_combat_modifiers() — both fields must remain consistent.
@export var bridge_no_flank: bool = false

## Named rule tokens active for this combat pair. Array[StringName] preserves
## element typing through ResourceSaver/Loader round-trips in Godot 4.6 when
## declared with @export.
@export var special_rules: Array[StringName] = []
