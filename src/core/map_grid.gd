## MapGrid — runtime grid host for one battle map (ADR-0004 §Decision 4).
##
## Lifecycle: instantiated as a child of BattleScene; freed when BattleScene is freed.
## Never registered as an autoload (ADR-0002 battle-scoped contract).
##
## Usage example:
##   var grid := MapGrid.new()
##   add_child(grid)
##   var res: MapResource = ResourceLoader.load(
##       "res://data/maps/chapter_01.tres", "", ResourceLoader.CACHE_MODE_IGNORE
##   ) as MapResource
##   grid.load_map(res)
##   var tile: MapTileData = grid.get_tile(Vector2i(3, 5))
##   var dims: Vector2i = grid.get_map_dimensions()  # Vector2i(cols, rows)
class_name MapGrid
extends Node

# ─── Private state ────────────────────────────────────────────────────────────

## Cloned MapResource (duplicate_deep). Null before load_map() is called.
var _map: MapResource = null

## Packed terrain-type values — one int per tile, index = row * cols + col.
var _terrain_type_cache: PackedInt32Array = PackedInt32Array()

## Packed elevation values.
var _elevation_cache: PackedInt32Array = PackedInt32Array()

## Packed base-passability bytes (0 = impassable, 1 = passable).
var _passable_base_cache: PackedByteArray = PackedByteArray()

## Packed occupant entity-id values (0 = unoccupied).
var _occupant_id_cache: PackedInt32Array = PackedInt32Array()

## Packed occupant faction-id values (0 = no faction).
var _occupant_faction_cache: PackedInt32Array = PackedInt32Array()

## Packed tile-state enum mirror values.
var _tile_state_cache: PackedInt32Array = PackedInt32Array()

# ─── Lifecycle ────────────────────────────────────────────────────────────────

## Load a map resource into this grid node.
##
## Clones [param res] via duplicate_deep so runtime mutations (occupancy, tile
## damage) never pollute the disk asset.  Builds all 6 packed caches from the
## clone.  Calling load_map() a second time fully replaces caches with no
## carry-over from the previous resource (re-entry safe).
##
## [param res] must be a valid MapResource whose tiles array has
## map_rows * map_cols entries (validated by story-003 MapValidator).
##
## Example:
##   grid.load_map(ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
##       as MapResource)
func load_map(res: MapResource) -> void:
	# Clone so disk asset is never mutated by runtime destruction / occupancy.
	# NOTE: Resource.DEEP_DUPLICATE_ALL_BUT_SCRIPTS does NOT exist in Godot 4.6's
	# DeepDuplicateMode enum (values: NONE / INTERNAL / ALL only).
	# DEEP_DUPLICATE_ALL is the correct max-depth mode — duplicates embedded
	# sub-resources including non-local-to-scene references.
	# ADR errata: TD-024 (save_manager.gd precedent) + TD-032 (map-grid batch).
	_map = res.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as MapResource

	# Build packed caches — pre-size then index-assign; never append in a loop
	# (append pays realloc cost on every element; resize+index is O(n) total).
	var n: int = _map.map_rows * _map.map_cols

	_terrain_type_cache.resize(n)
	_elevation_cache.resize(n)
	_passable_base_cache.resize(n)
	_occupant_id_cache.resize(n)
	_occupant_faction_cache.resize(n)
	_tile_state_cache.resize(n)

	for i: int in n:
		var t: MapTileData = _map.tiles[i]
		_terrain_type_cache[i]     = t.terrain_type
		_elevation_cache[i]        = t.elevation
		_passable_base_cache[i]    = 1 if t.is_passable_base else 0
		_occupant_id_cache[i]      = t.occupant_id
		_occupant_faction_cache[i] = t.occupant_faction
		_tile_state_cache[i]       = t.tile_state

# ─── Query API ────────────────────────────────────────────────────────────────

## Return the MapTileData at [param coord], or null if out-of-bounds or before
## load_map() is called.
##
## This is the cold-path query (ADR-0004 §Decision 2): callers that need full
## tile detail pay one dereference.  Hot-path queries (pathfinding, LoS) read
## only from the packed caches.
##
## Flat-array formula (TR-map-grid-001 / GDD CR-2):
##   index = coord.y * map_cols + coord.x
##
## Example:
##   var t: MapTileData = grid.get_tile(Vector2i(3, 5))
##   if t != null:
##       print(t.terrain_type)
func get_tile(coord: Vector2i) -> MapTileData:
	if _map == null:
		return null
	if coord.x < 0 or coord.x >= _map.map_cols \
			or coord.y < 0 or coord.y >= _map.map_rows:
		return null
	return _map.tiles[coord.y * _map.map_cols + coord.x]


## Return map dimensions as Vector2i(map_cols, map_rows).
##
## Per GDD Interactions table: .x = cols (width), .y = rows (height).
## Returns Vector2i.ZERO before load_map() is called (inert-until-loaded contract).
##
## Example:
##   var dims: Vector2i = grid.get_map_dimensions()
##   print("cols=%d rows=%d" % [dims.x, dims.y])
func get_map_dimensions() -> Vector2i:
	if _map == null:
		return Vector2i.ZERO
	return Vector2i(_map.map_cols, _map.map_rows)
