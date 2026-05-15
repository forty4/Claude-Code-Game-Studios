## BattleStateSnapshot — read-only flat-data Resource for AI decision input.
##
## Constructed by GridBattleController._make_battle_state_snapshot() at AI-turn
## entry. Snapshot is immutable from AI's perspective: AISystem reads via
## parameter (CR-AI-6 pure-function-takes-snapshot pattern), never mutates.
##
## Flat-data design (NO nested Resources) for trivial ResourceSaver/ResourceLoader
## round-trip per ADR-0019 §V-3 verification + serialization stability.
##
## Per ADR-0019 §Decision §Payload Form: 7 typed @export fields covering all
## battle state needed for the 4 archetype scoring functions (F-AI-1..4) without
## exposing GridBattleController's internal mutable state.
##
## ADR: ADR-0019 §Decision §Payload Form.
## TR: TR-ai-system-003.
class_name BattleStateSnapshot
extends Resource


## Per-unit data. Each entry is a Dictionary with keys:
##   unit_id: int, archetype: StringName, position: Vector2i, hp_current: int,
##   hp_max: int, atk: int, def: int, move_range: int, attack_range: int,
##   side: int (0=player, 1=enemy), is_player_controlled: bool,
##   passive_id: StringName (optional; e.g., &"command_aura"),
##   tag: StringName (e.g., &"boss"), is_alive: bool,
##   status_ids: Array[StringName] (session-18; effect_ids of all active status
##     effects on this unit — &"poison" / &"slow" / &"stun" / &"defend_stance"
##     / &"demoralized" / &"inspired" / &"exhausted"). Empty array if none.
@export var units: Array[Dictionary] = []

## Map dimensions (cols, rows).
@export var map_dimensions: Vector2i = Vector2i.ZERO

## Row-major flat terrain grid: terrain_grid[row * cols + col] = terrain_type int.
@export var terrain_grid: PackedInt32Array = PackedInt32Array()

## Turn-order queue snapshot: ordered list of unit_ids whose turns are upcoming.
@export var queue_unit_ids: Array[int] = []

## Current round number (1-indexed; increments at each new round).
@export var round_number: int = 0

## Chokepoints from chapter authoring (empty if chapter has none).
@export var chokepoints: Array[Vector2i] = []

## Centroid of allied units' positions for formation-cohesion calculations.
@export var formation_center: Vector2i = Vector2i.ZERO


## Returns the unit Dictionary for the given unit_id, or empty Dictionary if
## no matching unit (caller should check `unit.is_empty()` before access).
func get_unit(unit_id: int) -> Dictionary:
	for u: Dictionary in units:
		if (u.get("unit_id", -1) as int) == unit_id:
			return u
	return {}
