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
class_name MapGridStub
extends MapGrid

var _stub_dimensions: Vector2i = Vector2i(8, 8)
var _occupants: Dictionary = {}  # coord (Vector2i) → unit_id (int)


func get_map_dimensions() -> Vector2i:
	return _stub_dimensions


func get_tile(coord: Vector2i) -> MapTileData:
	var tile := MapTileData.new()
	tile.coord = coord
	tile.occupant_id = _occupants.get(coord, 0)  # 0 = unoccupied per MapTileData @export default
	return tile


func set_occupant_for_test(coord: Vector2i, unit_id: int) -> void:
	_occupants[coord] = unit_id


func set_dimensions_for_test(dims: Vector2i) -> void:
	_stub_dimensions = dims
