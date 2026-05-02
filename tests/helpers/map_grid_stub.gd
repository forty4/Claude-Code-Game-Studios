## MapGridStub — minimal MapGrid test stub for HP/Status DI seam (story-006).
## Provides controlled occupant_id values for ally-radius proximity checks.
## Used by tests/integration/core/hp_status_turn_start_tick_test.gd.
##
## Production contract mirror: occupant_id == 0 means "unoccupied" per MapTileData.gd:43.
## Tests use set_occupant_for_test(coord, unit_id) to populate the lookup map.
##
## EXTENDS MapGrid (not Node) so it satisfies HPStatusController._map_grid: MapGrid
## typed-field assignment. Overrides get_tile + get_map_dimensions to return stub
## data instead of MapResource-driven values; the inherited _map field stays null.
##
## Story-004 extensions: set_passable_for_test (RIVER/MOUNTAIN testing), no-op
## set_occupant + clear_occupant (avoid push_error from production class on
## "called before load_map" since _map is null in the stub).
class_name MapGridStub
extends MapGrid

var _stub_dimensions: Vector2i = Vector2i(8, 8)
var _occupants: Dictionary = {}  # coord (Vector2i) → unit_id (int)
var _impassable: Dictionary = {}  # coord (Vector2i) → true if NOT passable
## Test seam: set_occupant + clear_occupant calls captured for assertion.
var set_occupant_calls: Array[Dictionary] = []
var clear_occupant_calls: Array[Vector2i] = []


func get_map_dimensions() -> Vector2i:
	return _stub_dimensions


func get_tile(coord: Vector2i) -> MapTileData:
	var tile := MapTileData.new()
	tile.coord = coord
	tile.occupant_id = _occupants.get(coord, 0)  # 0 = unoccupied per MapTileData @export default
	tile.is_passable_base = not _impassable.get(coord, false)
	return tile


func set_occupant(coord: Vector2i, unit_id: int, faction: int) -> void:
	# Override: capture call + populate _occupants without parent's _map null-check.
	set_occupant_calls.append({"coord": coord, "unit_id": unit_id, "faction": faction})
	_occupants[coord] = unit_id


func clear_occupant(coord: Vector2i) -> void:
	# Override: capture call + clear _occupants without parent's _map null-check.
	clear_occupant_calls.append(coord)
	_occupants.erase(coord)


func set_occupant_for_test(coord: Vector2i, unit_id: int) -> void:
	_occupants[coord] = unit_id


func set_passable_for_test(coord: Vector2i, passable: bool) -> void:
	if passable:
		_impassable.erase(coord)
	else:
		_impassable[coord] = true


func set_dimensions_for_test(dims: Vector2i) -> void:
	_stub_dimensions = dims
