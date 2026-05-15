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
## Story-008: unit_at_coord field + get_unit_at method for InputRouter touch
## coord→unit_id resolution (AC-10 DI seam).
class_name MapGridStub
extends MapGrid

var _stub_dimensions: Vector2i = Vector2i(8, 8)
var _occupants: Dictionary = {}  # coord (Vector2i) → unit_id (int)
var _impassable: Dictionary = {}  # coord (Vector2i) → true if NOT passable
## Session-15: per-coord terrain_type override. Tests set
## set_terrain_type_for_test(coord, terrain_type) to populate; lookups in
## get_tile() default to 0 (PLAINS) per the existing stub contract.
var _terrain_types: Dictionary = {}  # coord (Vector2i) → terrain_type (int)
## Story-007 (S10-02): force get_tile to return null for AC-2 edge-case coverage
## (battle_hud.show_tile_info "tile data missing" branch).
var _force_null_get_tile: bool = false
## Test seam: set_occupant + clear_occupant calls captured for assertion.
var set_occupant_calls: Array[Dictionary] = []
var clear_occupant_calls: Array[Vector2i] = []


func get_map_dimensions() -> Vector2i:
	return _stub_dimensions


func get_tile(coord: Vector2i) -> MapTileData:
	if _force_null_get_tile:
		return null
	var tile := MapTileData.new()
	tile.coord = coord
	tile.occupant_id = _occupants.get(coord, 0)  # 0 = unoccupied per MapTileData @export default
	tile.is_passable_base = not _impassable.get(coord, false)
	tile.terrain_type = _terrain_types.get(coord, 0)  # default PLAINS=0
	# Production checks tile_state (not occupant_id) for occupancy because unit_id 0
	# is a valid id (the commander) and would alias to "empty". Mirror that here so
	# tests using set_occupant_for_test see the tile read as ALLY_OCCUPIED.
	if _occupants.has(coord):
		tile.tile_state = MapGrid.TILE_STATE_ALLY_OCCUPIED
	return tile


## Session-15: populates per-coord terrain_type. get_tile() reads from this
## map and falls back to 0 (PLAINS) when a coord has no override. Used by
## tests that need HILLS / FOREST / etc. lookups (ARCHER high-ground gating).
func set_terrain_type_for_test(coord: Vector2i, terrain_type: int) -> void:
	_terrain_types[coord] = terrain_type


## Story-007 (S10-02): force get_tile to return null. Exercises the
## battle_hud.show_tile_info "tile data missing" early-return branch (AC-2 edge).
func set_force_null_get_tile_for_test(force: bool) -> void:
	_force_null_get_tile = force


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


## Per-coord unit lookup for InputRouter touch coord→unit_id resolution
## (story-008 AC-10). Uses -1 sentinel for "no unit at coord" — matches
## InputContext.target_unit_id semantics. Distinct from production MapGrid's
## occupant_id=0 "unoccupied" sentinel.
var unit_at_coord: Dictionary[Vector2i, int] = {}


## Returns the unit_id at coord per fixture data. -1 if not fixtured.
func get_unit_at(coord: Vector2i) -> int:
	return unit_at_coord.get(coord, -1)
