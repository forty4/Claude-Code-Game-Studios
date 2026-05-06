## GridBattleStub — RefCounted test stub for InputRouter's `_grid_battle: Variant`
## injection seam. Distinct from grid_battle_controller_stub.gd (which extends
## the Node-based GridBattleController for BattleHUD test fixtures).
##
## Story coverage:
##   story-003: is_tile_in_move_range + confirm_move
##   story-004: is_tile_in_attack_range + confirm_attack
##   story-006: is_tile_occupied + restore_unit_to_pre_move + get_unit_coord +
##              get_unit_facing + occupied_coords + unit_coords + unit_facings +
##              restore_calls
class_name GridBattleStub
extends RefCounted

## Coordinates considered "in move range" by the stub. Tests populate this
## directly to fixture specific scenarios.
var fixture_in_range_coords: Array[Vector2i] = [
	Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3),
]

## Coordinates considered "in attack range" by the stub. Story-004 uses.
var fixture_in_attack_coords: Array[Vector2i] = [
	Vector2i(4, 4), Vector2i(5, 5),
]

## Records of confirm_move calls — tests assert call count + params.
var confirm_move_calls: Array[Dictionary] = []

## Records of confirm_attack calls — story-004 will exercise.
var confirm_attack_calls: Array[Dictionary] = []

## Coordinates considered "occupied" by the stub — story-006 EC-5 occupied-tile
## rejection uses this.
var occupied_coords: Array[Vector2i] = []

## Records of restore_unit_to_pre_move calls — story-006 EC-5 + AC-3 happy path uses.
var restore_calls: Array[Dictionary] = []

## Per-unit pre-move coords captured by S2 confirm arm (story-006 AC-1).
## Tests populate this directly to fixture per-unit pre-move state.
## NOTE: declared as Dictionary[int, Vector2i] — depth-1 typed Dictionary (G-25 safe).
var unit_coords: Dictionary[int, Vector2i] = {}

## Per-unit pre-move facings captured by S2 confirm arm (story-006 AC-1).
## NOTE: declared as Dictionary[int, int] — depth-1 typed Dictionary (G-25 safe).
var unit_facings: Dictionary[int, int] = {}


## Returns whether a coord is in move range per fixture data.
func is_tile_in_move_range(coord: Vector2i) -> bool:
	return coord in fixture_in_range_coords


## Returns whether a coord is in attack range per fixture data. Story-004 uses.
func is_tile_in_attack_range(coord: Vector2i) -> bool:
	return coord in fixture_in_attack_coords


## Records a move confirmation call.
func confirm_move(unit_id: int, coord: Vector2i) -> void:
	confirm_move_calls.append({"unit_id": unit_id, "coord": coord})


## Records an attack confirmation call. Story-004 will exercise.
func confirm_attack(unit_id: int, coord: Vector2i) -> void:
	confirm_attack_calls.append({"unit_id": unit_id, "coord": coord})


## Returns whether a coord is occupied per fixture data. Story-006 EC-5 uses.
func is_tile_occupied(coord: Vector2i) -> bool:
	return coord in occupied_coords


## Returns the unit's current coord (story-006 S2 confirm arm uses this to capture
## pre-move state). Defaults to Vector2i.ZERO when unit not in fixture.
func get_unit_coord(unit_id: int) -> Vector2i:
	return unit_coords.get(unit_id, Vector2i.ZERO)


## Returns the unit's current facing (story-006 S2 confirm arm uses).
## Defaults to 0 when unit not in fixture.
func get_unit_facing(unit_id: int) -> int:
	return unit_facings.get(unit_id, 0)


## Records a restore call (story-006 _apply_undo invokes when EC-5 not blocked).
func restore_unit_to_pre_move(unit_id: int, coord: Vector2i, facing: int) -> void:
	restore_calls.append({"unit_id": unit_id, "coord": coord, "facing": facing})
