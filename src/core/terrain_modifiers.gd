## TerrainModifiers — raw (uncapped) terrain defence/evasion values for one tile.
##
## Returned by TerrainEffect.get_terrain_modifiers() for HUD display (EC-12).
## Values are uncapped — do NOT apply MAX_DEFENSE_REDUCTION / MAX_EVASION clamps
## here; clamping is the responsibility of CombatModifiers (story-005).
##
## Ratified by ADR-0008 §Decision 6 + §Key Interfaces. MUST extend Resource,
## declare class_name TerrainModifiers, and annotate every persisted field with
## @export. Non-@export fields are SILENTLY DROPPED by ResourceSaver — see
## ADR-0003 §Schema Stability and the EchoMark precedent in src/core/payloads/.
##
## class_name collision check: TerrainModifiers verified collision-free with
## Godot 4.6 built-ins on 2026-04-25 (ADR-0008 Verification Required §3, CLOSED).
##
## WARNING (G-2 — typed-array .duplicate() demotion): When story-005 populates
## special_rules arrays from JSON in TerrainEffect._apply_config(), do NOT use
## .duplicate() on a source Array[StringName]. Use explicit typed assignment:
##   var rules: Array[StringName] = []
##   rules.assign(source_array)
## or fresh-construction element-by-element. .duplicate() demotes typed arrays
## to untyped Array in Godot 4.x and will silently break ResourceSaver typing.
class_name TerrainModifiers
extends Resource

## Defence bonus provided to the defending unit on this tile (percentage points,
## uncapped). Range: 0..25 per CR-1 terrain table; negative values are not used
## by TerrainModifiers (CombatModifiers carries signed elevation deltas).
@export var defense_bonus: int = 0

## Evasion bonus provided to the defending unit on this tile (percentage points,
## uncapped). Range: 0..15 per CR-1 terrain table.
@export var evasion_bonus: int = 0

## Named rule tokens active on this tile (e.g. &"bridge_no_flank",
## &"siege_terrain"). Array[StringName] preserves element typing through
## ResourceSaver/Loader round-trips in Godot 4.6 when declared with @export.
@export var special_rules: Array[StringName] = []
