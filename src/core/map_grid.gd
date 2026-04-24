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
##   var ok: bool = grid.load_map(res)
##   if not ok:
##       print("Validation errors: ", grid.get_last_load_errors())
##   var tile: MapTileData = grid.get_tile(Vector2i(3, 5))
##   var dims: Vector2i = grid.get_map_dimensions()  # Vector2i(cols, rows)
class_name MapGrid
extends Node

# ─── Error code constants (UPPER_SNAKE_CASE — grep-able in test assertions and bug reports) ──

## Dimension out-of-range: cols ∉ [15,40] or rows ∉ [15,30]. Format: ERR...(cols,rows)
const ERR_MAP_DIMENSIONS_INVALID := "ERR_MAP_DIMENSIONS_INVALID"

## Tile array length != map_rows * map_cols. Format: ERR...(expected,actual)
const ERR_TILE_ARRAY_SIZE_MISMATCH := "ERR_TILE_ARRAY_SIZE_MISMATCH"

## Tile elevation outside CR-3 allowed range for its terrain_type.
## Format: ERR...(col,row,terrain,elevation)
const ERR_ELEVATION_TERRAIN_MISMATCH := "ERR_ELEVATION_TERRAIN_MISMATCH"

## Tile is_passable_base=false but tile_state is ALLY_OCCUPIED or ENEMY_OCCUPIED.
## Format: ERR...(col,row)
const ERR_IMPASSABLE_OCCUPIED := "ERR_IMPASSABLE_OCCUPIED"

## Tile coord field does not match its array position under flat-array formula.
## Format: ERR...(expected_col,expected_row,actual_col,actual_row,index)
const ERR_TILE_ARRAY_POSITION_MISMATCH := "ERR_TILE_ARRAY_POSITION_MISMATCH"

## occupant_id >= 0 and coord field mismatches array position (caught by position check above).
## Kept as a distinct constant for future use (story-004 mutation validation).
const ERR_UNIT_COORD_OUT_OF_BOUNDS := "ERR_UNIT_COORD_OUT_OF_BOUNDS"

# ─── CR-3 elevation-per-terrain allowed ranges ────────────────────────────────
##
## TerrainType enum assumed order (to be formalised by ADR-0008 in story-005/006):
##   PLAINS=0, FOREST=1, HILLS=2, MOUNTAIN=3, RIVER=4, BRIDGE=5, FORTRESS_WALL=6, ROAD=7
## Assumption documented for TD-032 batch. Index = terrain_type int value;
## inner array = allowed elevation values for that terrain.
## GDScript const limitation: PackedInt32Array() is not a literal expression, so
## we use a nested Array literal (all ints, no constructor calls) which IS
## const-expressible. The validator reads these as plain Array[int] at runtime.
const ELEVATION_RANGES: Array = [
	[0],      # 0 PLAINS: elevation must be 0
	[0, 1],   # 1 FOREST: elevation must be 0 or 1
	[1],      # 2 HILLS: elevation must be 1
	[2],      # 3 MOUNTAIN: elevation must be 2
	[0],      # 4 RIVER: elevation must be 0
	[0],      # 5 BRIDGE: elevation must be 0
	[1, 2],   # 6 FORTRESS_WALL: elevation must be 1 or 2
	[0],      # 7 ROAD: elevation must be 0
]

## TileState enum assumed values (to be formalised by ADR-0008 in story-005/006):
##   EMPTY=0, ALLY_OCCUPIED=1, ENEMY_OCCUPIED=2, DESTROYED=3
## Assumption documented for TD-032 batch.
const TILE_STATE_EMPTY: int        = 0
const TILE_STATE_ALLY_OCCUPIED: int  = 1
const TILE_STATE_ENEMY_OCCUPIED: int = 2
const TILE_STATE_DESTROYED: int    = 3

## Valid map dimension bounds (GDD §EC-1 / §EC-7).
const MAP_COLS_MIN: int = 15
const MAP_COLS_MAX: int = 40
const MAP_ROWS_MIN: int = 15
const MAP_ROWS_MAX: int = 30

# ─── Private state ────────────────────────────────────────────────────────────

## Cloned MapResource (duplicate_deep). Null before load_map() is called or after
## a validation failure.
var _map: MapResource = null

## Errors from the most recent load_map() call. Empty if validation passed.
## Access via get_last_load_errors(); never modify this array directly.
var _last_load_errors: PackedStringArray = PackedStringArray()

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
## Validates [param res] against all GDD §EC-7 constraints before building caches.
## Returns [code]true[/code] if validation passed and the map was loaded; returns
## [code]false[/code] if validation failed — in that case [member _map] is NOT
## assigned and no caches are built (no partial state).
##
## On success: clones [param res] via duplicate_deep so runtime mutations (occupancy,
## tile damage) never pollute the disk asset. Builds all 6 packed caches from the
## clone. Calling load_map() a second time resets to inert state first, then loads
## the new map — re-entry safe in both success AND failure paths.
##
## On failure: call [method get_last_load_errors] to retrieve the full error list.
## All errors are collected in one pass (collect-all, not short-circuit). The grid
## is left in inert state ([code]_map == null[/code]); queries return null / Vector2i.ZERO
## until a subsequent load_map() call succeeds.
##
## [param res] must be a valid MapResource. See [method _validate_map] for rules.
##
## Example:
##   var ok: bool = grid.load_map(
##       ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MapResource
##   )
##   if not ok:
##       print(grid.get_last_load_errors())
func load_map(res: MapResource) -> bool:
	# Reset to inert BEFORE validation — ensures a failed load leaves no stale
	# state from a prior successful call. Public queries (get_tile, get_map_dimensions)
	# guard on _map == null, so only _map needs resetting for the inert contract;
	# packed caches are rebuilt wholesale on the success path below.
	_map = null

	_last_load_errors = _validate_map(res)
	if not _last_load_errors.is_empty():
		for err: String in _last_load_errors:
			push_error(err)
		return false

	# Clone so disk asset is never mutated by runtime destruction / occupancy.
	# NOTE: Resource.DEEP_DUPLICATE_ALL_BUT_SCRIPTS does NOT exist in Godot 4.6's
	# DeepDuplicateMode enum (values: NONE / INTERNAL / ALL only).
	# DEEP_DUPLICATE_ALL is the correct max-depth mode — duplicates embedded
	# sub-resources including non-local-to-scene references.
	# ADR errata: TD-024 (save_manager.gd precedent) + TD-032 (map-grid batch).
	_map = res.duplicate_deep(Resource.DEEP_DUPLICATE_ALL) as MapResource

	# Apply load-time clamps to the clone (V-2 invariant: disk asset unchanged).
	_apply_load_time_clamps(_map)

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

	return true

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
## Returns Vector2i.ZERO before load_map() is called or after a validation
## failure (inert-until-loaded contract).
##
## Example:
##   var dims: Vector2i = grid.get_map_dimensions()
##   print("cols=%d rows=%d" % [dims.x, dims.y])
func get_map_dimensions() -> Vector2i:
	if _map == null:
		return Vector2i.ZERO
	return Vector2i(_map.map_cols, _map.map_rows)


## Return the error list from the most recent load_map() call.
##
## Returns an empty PackedStringArray if the last load_map() call succeeded (or if
## load_map() has never been called).  Each entry is an error-code string of the
## form "ERR_CODE(positional_context)", e.g.:
##   "ERR_MAP_DIMENSIONS_INVALID(14,15)"
##   "ERR_ELEVATION_TERRAIN_MISMATCH(0,0,0,2)"
##
## Clamp warnings (§EC-5 negative destruction_hp) do NOT appear here — they are
## emitted via push_warning and do not contribute to the error list.
##
## Example:
##   var ok: bool = grid.load_map(res)
##   if not ok:
##       for err in grid.get_last_load_errors():
##           print(err)
func get_last_load_errors() -> PackedStringArray:
	return _last_load_errors

# ─── Private helpers ──────────────────────────────────────────────────────────

## Validate [param res] against all load-time constraints (GDD §EC-1, §EC-7, AC-CR-4).
##
## Collect-all pattern: all errors are gathered in one O(rows×cols) pass; the
## caller sees the full error list on the first load attempt (GDD author UX requirement).
## Does NOT short-circuit on first failure.
##
## Returns a PackedStringArray: empty = valid; non-empty = list of error strings.
## Clamp-worthy cases (§EC-5 negative destruction_hp) are NOT errors; they are
## handled in _apply_load_time_clamps() after a successful validation.
func _validate_map(res: MapResource) -> PackedStringArray:
	var errors: PackedStringArray = PackedStringArray()

	# ── Step 1: Dimension check (cols ∈ [15,40], rows ∈ [15,30]) ──────────────
	var cols: int = res.map_cols
	var rows: int = res.map_rows
	var dims_ok: bool = true

	if cols < MAP_COLS_MIN or cols > MAP_COLS_MAX \
			or rows < MAP_ROWS_MIN or rows > MAP_ROWS_MAX \
			or cols == 0 or rows == 0:
		errors.append("%s(%d,%d)" % [ERR_MAP_DIMENSIONS_INVALID, cols, rows])
		dims_ok = false

	# ── Step 2: Tile array size check ──────────────────────────────────────────
	var expected_size: int = rows * cols
	var actual_size: int = res.tiles.size()
	var size_ok: bool = true

	if actual_size != expected_size:
		errors.append("%s(%d,%d)" % [ERR_TILE_ARRAY_SIZE_MISMATCH, expected_size, actual_size])
		size_ok = false

	# ── Step 3: Tile-level checks (only when both dimensions and size are valid) ──
	# If either fails, tile indexing could produce out-of-bounds accesses or
	# incorrect coord expectations, so we skip the tile walk to avoid spurious errors.
	if not (dims_ok and size_ok):
		return errors

	# Single pass over all tiles: coord mismatch → elevation-terrain → passable-occupied.
	for i: int in expected_size:
		var t: MapTileData = res.tiles[i]
		var expected_coord: Vector2i = Vector2i(i % cols, i / cols)

		# ── 3a: Coord / position mismatch ──────────────────────────────────────
		if t.coord != expected_coord:
			errors.append(
				"%s(%d,%d,%d,%d,%d)" % [
					ERR_TILE_ARRAY_POSITION_MISMATCH,
					expected_coord.x, expected_coord.y,
					t.coord.x, t.coord.y,
					i
				]
			)
			# Continue checking other rules even for mismatched coord tiles.

		# ── 3b: Elevation-terrain mismatch (CR-3) ──────────────────────────────
		var terrain: int = t.terrain_type
		if terrain >= 0 and terrain < ELEVATION_RANGES.size():
			var allowed: Array = ELEVATION_RANGES[terrain]
			var elev: int = t.elevation
			var elev_valid: bool = false
			for allowed_elev: int in allowed:
				if elev == allowed_elev:
					elev_valid = true
					break
			if not elev_valid:
				errors.append(
					"%s(%d,%d,%d,%d)" % [
						ERR_ELEVATION_TERRAIN_MISMATCH,
						t.coord.x, t.coord.y,
						terrain, t.elevation
					]
				)

		# ── 3c: Impassable + occupied contradiction (GDD §EC-7) ────────────────
		if not t.is_passable_base:
			var state: int = t.tile_state
			if state == TILE_STATE_ALLY_OCCUPIED or state == TILE_STATE_ENEMY_OCCUPIED:
				errors.append(
					"%s(%d,%d)" % [ERR_IMPASSABLE_OCCUPIED, t.coord.x, t.coord.y]
				)

	return errors


## Apply load-time clamps to the already-cloned [param map] (V-2 invariant: disk
## asset is never touched; this runs on _map after duplicate_deep).
##
## Clamp cases (GDD §EC-5, §EC-7):
##   - destruction_hp < 0 → clamp to 0; push_warning once per map (not per tile)
##   - is_destructible == true && destruction_hp == 0 → set tile_state to DESTROYED;
##     push_warning once per map
##
## These are warnings only; they do not contribute to the error list and do not
## prevent the map from loading.
func _apply_load_time_clamps(map: MapResource) -> void:
	var warned_negative_hp: bool = false
	var warned_zero_hp_destructible: bool = false

	for t: MapTileData in map.tiles:
		# Clamp negative destruction_hp to 0.
		if t.destruction_hp < 0:
			t.destruction_hp = 0
			if not warned_negative_hp:
				push_warning(
					"MapGrid: one or more tiles had destruction_hp < 0; clamped to 0 (GDD §EC-5)"
				)
				warned_negative_hp = true

		# Treat is_destructible=true + destruction_hp=0 as DESTROYED state.
		if t.is_destructible and t.destruction_hp == 0:
			t.tile_state = TILE_STATE_DESTROYED
			if not warned_zero_hp_destructible:
				push_warning(
					"MapGrid: one or more destructible tiles had destruction_hp == 0;" \
					+ " tile_state set to DESTROYED (GDD §EC-7)"
				)
				warned_zero_hp_destructible = true
