## MapGrid — runtime grid host for one battle map (ADR-0004 §Decision 4).
##
## Lifecycle: instantiated as a child of BattleScene; freed when BattleScene is freed.
## Never registered as an autoload (ADR-0002 battle-scoped contract).
##
## ADV-1 return-type decision (story-005): pathfinding methods return [PackedVector2Array]
## with [code]Vector2(int(coord.x), int(coord.y))[/code] construction.
## Callers cast back to [code]Vector2i[/code] at the consumer boundary:
##   [code]var coord: Vector2i = Vector2i(result[i])[/code]
## Rationale: [PackedVector2Array] is the only packed array of 2D coordinates in Godot
## 4.6 — there is no [PackedVector2iArray]. Using [Array[Vector2i]] would pay per-element
## boxing overhead on every access. Integer coordinate precision is preserved because
## float32 is exact for integers up to 2^24 (>> 40*30 max index). (ADR-0004 §Decision 7.)
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
##   var range_tiles: PackedVector2Array = grid.get_movement_range(1, 3, TerrainCost.PLAINS)
##   var path: PackedVector2Array = grid.get_movement_path(Vector2i(0,0), Vector2i(4,4), TerrainCost.PLAINS)
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

## TileState enum assumed values (locked by story-004 / GDD §ST-1; formalised by ADR-0008):
##   EMPTY=0, ALLY_OCCUPIED=1, ENEMY_OCCUPIED=2,
##   IMPASSABLE=3 (added story-004), DESTRUCTIBLE=4 (added story-004),
##   DESTROYED=5 (renumbered from 3 by story-004 to make room for IMPASSABLE/DESTRUCTIBLE)
##
## NOTE (story-004 deviation): spec §Implementation Notes used STATE_* prefix for brevity.
## We preserve the TILE_STATE_* prefix from stories-002/003 to avoid breaking the 19
## existing tests that reference MapGrid.TILE_STATE_ALLY_OCCUPIED / ENEMY_OCCUPIED.
const TILE_STATE_EMPTY: int          = 0
const TILE_STATE_ALLY_OCCUPIED: int  = 1
const TILE_STATE_ENEMY_OCCUPIED: int = 2
const TILE_STATE_IMPASSABLE: int     = 3  ## Added story-004 (GDD §ST-1). Terrain that cannot be occupied or passed.
const TILE_STATE_DESTRUCTIBLE: int   = 4  ## Added story-004 (GDD §ST-1). Destructible terrain with remaining HP.
const TILE_STATE_DESTROYED: int      = 5  ## Renumbered story-004 (was 3). Terrain destroyed; passable but gone.

## Faction constants (added story-004, GDD §ST-1).
## GridBattleController passes these to set_occupant().
const FACTION_NONE: int  = 0  ## No occupant faction.
const FACTION_ALLY: int  = 1  ## Player-controlled unit.
const FACTION_ENEMY: int = 2  ## AI-controlled unit.

## Attack-direction enum (story-006, GDD §F-5).
## Result of [method get_attack_direction] — angular relationship between attacker
## and defender's facing.
const ATK_DIR_FRONT: int = 0  ## Attacker is in defender's front arc.
const ATK_DIR_FLANK: int = 1  ## Attacker is to defender's flank (left or right).
const ATK_DIR_REAR:  int = 2  ## Attacker is behind defender.

## Defender facing enum (story-006, GDD §CR-5).
## NORTH = decreasing row (up); EAST = increasing col (right); etc.
## Used as input to [method get_attack_direction].
const FACING_NORTH: int = 0
const FACING_EAST:  int = 1
const FACING_SOUTH: int = 2
const FACING_WEST:  int = 3

## Illegal state-transition error code (story-004 AC-ST-3 / AC-ST-4).
## Emitted via push_error when set_occupant or apply_tile_damage is called on a
## tile whose current state forbids the requested transition.
const ERR_ILLEGAL_STATE_TRANSITION := "ERR_ILLEGAL_STATE_TRANSITION"

# ─── Load-time clamp warning codes (TD-032 A-12) ──────────────────────────────
#
# Symmetric to ERR_* constants above. Populated into _last_load_warnings by
# _apply_load_time_clamps() so tests can assert the V-2 invariant narrative
# ("we clamped but we told you") rather than relying on push_warning side effects.

## A tile had destruction_hp < 0 on disk; clamped to 0. Format: WARN...(col,row)
const WARN_NEGATIVE_DESTRUCTION_HP := "WARN_NEGATIVE_DESTRUCTION_HP"

## A destructible tile arrived with destruction_hp == 0; tile_state set to DESTROYED.
## Format: WARN...(col,row)
const WARN_DESTRUCTIBLE_ZERO_HP_SET_DESTROYED := "WARN_DESTRUCTIBLE_ZERO_HP_SET_DESTROYED"

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

## Warnings from the most recent load_map() call (TD-032 A-12). Symmetric to
## _last_load_errors but for non-fatal clamp warnings (negative destruction_hp,
## destructible tile loaded with hp=0). Populated by _apply_load_time_clamps.
## Access via get_last_load_warnings(); never modify this array directly.
var _last_load_warnings: PackedStringArray = PackedStringArray()

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

# ─── Pathfinding scratch buffers (ADR-0004 §Decision 7 / story-005) ──────────
#
# Declared at class scope so get_movement_range and get_path can clear-and-reuse
# them across calls without per-call allocation (zero-alloc hot-path rule).
# Both methods clear at entry — no re-entrance concern (no coroutines / threading
# per ADR-0004). (Approved: C-1.)

## Sorted priority-queue scratch for Dijkstra.
## Entry format: (cost << 16) | tile_index — packed into one Int32.
## Cleared (not reallocated) at the start of each query.
var _priority_queue_scratch: PackedInt32Array = PackedInt32Array()

## Visited-set scratch: one byte per tile, index = row * cols + col.
## Resized to rows*cols on each query (no-op if size unchanged); filled 0 at entry.
## Byte = 1 once a tile is finalised (popped from queue).
var _visited_scratch: PackedByteArray = PackedByteArray()

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
	_last_load_warnings = PackedStringArray()  # TD-032 A-12: clear warnings before re-populate.

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
## available via [method get_last_load_warnings] and do not contribute to the error list.
##
## Example:
##   var ok: bool = grid.load_map(res)
##   if not ok:
##       for err in grid.get_last_load_errors():
##           print(err)
func get_last_load_errors() -> PackedStringArray:
	return _last_load_errors


## Return the clamp-warning list from the most recent load_map() call (TD-032 A-12).
##
## Returns an empty PackedStringArray when no clamp-worthy tiles were encountered
## (or load_map() has never been called). Each entry is a warning-code string of
## the form "WARN_CODE(col,row)", e.g.:
##   "WARN_NEGATIVE_DESTRUCTION_HP(5,3)"
##   "WARN_DESTRUCTIBLE_ZERO_HP_SET_DESTROYED(2,7)"
##
## Symmetric to [method get_last_load_errors] but for non-fatal clamp warnings
## emitted by [method _apply_load_time_clamps]. Tests can assert exact counts and
## per-coord identification — silent clamps are no longer possible.
##
## Example:
##   grid.load_map(res)
##   for warn in grid.get_last_load_warnings():
##       print(warn)
func get_last_load_warnings() -> PackedStringArray:
	return _last_load_warnings

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
##   - destruction_hp < 0 → clamp to 0; warning per offending tile in
##     [member _last_load_warnings] (TD-032 A-12 changed from once-per-map to
##     per-tile so tests can assert exact counts and per-coord identification).
##   - is_destructible == true && destruction_hp == 0 → set tile_state to DESTROYED;
##     warning per offending tile.
##
## These are warnings only; they do not contribute to the error list and do not
## prevent the map from loading. Both push_warning (visible in editor / CI logs)
## and [member _last_load_warnings] (testable contract) are populated.
func _apply_load_time_clamps(map: MapResource) -> void:
	var pushed_negative_hp_summary: bool = false
	var pushed_zero_hp_destructible_summary: bool = false

	for t: MapTileData in map.tiles:
		# Clamp negative destruction_hp to 0.
		if t.destruction_hp < 0:
			t.destruction_hp = 0
			_last_load_warnings.append(
				"%s(%d,%d)" % [WARN_NEGATIVE_DESTRUCTION_HP, t.coord.x, t.coord.y]
			)
			if not pushed_negative_hp_summary:
				push_warning(
					"MapGrid: one or more tiles had destruction_hp < 0; clamped to 0 (GDD §EC-5)"
				)
				pushed_negative_hp_summary = true

		# Treat is_destructible=true + destruction_hp=0 as DESTROYED state.
		if t.is_destructible and t.destruction_hp == 0:
			t.tile_state = TILE_STATE_DESTROYED
			_last_load_warnings.append(
				"%s(%d,%d)" % [WARN_DESTRUCTIBLE_ZERO_HP_SET_DESTROYED, t.coord.x, t.coord.y]
			)
			if not pushed_zero_hp_destructible_summary:
				push_warning(
					"MapGrid: one or more destructible tiles had destruction_hp == 0;" \
					+ " tile_state set to DESTROYED (GDD §EC-7)"
				)
				pushed_zero_hp_destructible_summary = true


# ─── Mutation API (GridBattleController-only by convention — ADR-0004 §Decision 6) ──
#
# WARNING: These methods are NOT private (GDScript has no access control) but
# MUST only be called from GridBattleController per ADR-0004 §Decision 6. Any
# other caller is an architecture violation caught in code review, not at runtime.

## Place [param unit_id] with [param faction] on the tile at [param coord].
##
## State-machine transition rules (GDD §ST-1, AC-ST-1, AC-ST-3, §EC-6):
##   - EMPTY → ALLY_OCCUPIED (faction=FACTION_ALLY) or ENEMY_OCCUPIED (faction=FACTION_ENEMY)
##   - IMPASSABLE → rejected with [constant ERR_ILLEGAL_STATE_TRANSITION] (AC-ST-4)
##   - ALLY_OCCUPIED → ENEMY_OCCUPIED (or any cross-faction): rejected (AC-ST-3)
##   - ALLY_OCCUPIED → ALLY_OCCUPIED (same faction, different unit): rejected (§EC-6 strict-sync)
##   - ENEMY_OCCUPIED → ALLY_OCCUPIED (or any cross-faction): rejected (AC-ST-3)
##   - DESTROYED: allowed (unit can stand on rubble). State → ALLY_OCCUPIED / ENEMY_OCCUPIED.
##
## Writes through to [code]_map.tiles[idx][/code] AND all 6 packed caches in the same call (TR-map-grid-004).
## Coord out-of-bounds or null map → push_error + no-op.
##
## Example:
##   grid.set_occupant(Vector2i(3, 5), 42, MapGrid.FACTION_ALLY)
func set_occupant(coord: Vector2i, unit_id: int, faction: int) -> void:
	if _map == null:
		push_error("%s: set_occupant called before load_map — coord %s" % [ERR_UNIT_COORD_OUT_OF_BOUNDS, str(coord)])
		return
	if coord.x < 0 or coord.x >= _map.map_cols \
			or coord.y < 0 or coord.y >= _map.map_rows:
		push_error("%s: set_occupant coord %s out of bounds (%dx%d)" % [ERR_UNIT_COORD_OUT_OF_BOUNDS, str(coord), _map.map_cols, _map.map_rows])
		return

	var idx: int = coord.y * _map.map_cols + coord.x
	var td: MapTileData = _map.tiles[idx]
	var current_state: int = td.tile_state

	# AC-ST-4: IMPASSABLE tiles reject all occupancy.
	if current_state == TILE_STATE_IMPASSABLE:
		push_error(
			("%s: set_occupant on IMPASSABLE tile at %s —" \
			+ " caller must not place units on impassable terrain") % [ERR_ILLEGAL_STATE_TRANSITION, str(coord)]
		)
		return

	# AC-ST-3 / §EC-6: reject cross-faction transitions AND same-faction overwrites.
	# Occupied tiles (ALLY or ENEMY) must be cleared before a new occupant is placed.
	if current_state == TILE_STATE_ALLY_OCCUPIED or current_state == TILE_STATE_ENEMY_OCCUPIED:
		push_error(
			("%s: set_occupant on already-occupied tile at %s" \
			+ " — caller must clear_occupant first (§EC-6 strict-sync)") % [ERR_ILLEGAL_STATE_TRANSITION, str(coord)]
		)
		return

	# Determine new tile_state from faction.
	var new_state: int
	if faction == FACTION_ALLY:
		new_state = TILE_STATE_ALLY_OCCUPIED
	else:
		new_state = TILE_STATE_ENEMY_OCCUPIED

	# Mutate TileData, then sync caches (R-4 write-through choke-point).
	td.occupant_id      = unit_id
	td.occupant_faction = faction
	td.tile_state       = new_state
	_write_tile(idx, td)


## Remove the current occupant from the tile at [param coord].
##
## Post-state rules (GDD §ST-1, AC-2):
##   - If tile was ALLY_OCCUPIED or ENEMY_OCCUPIED → tile_state → EMPTY; occupant fields → 0.
##   - If tile was DESTROYED with occupant → tile_state → DESTROYED (terrain state preserved).
##   - Already-EMPTY tile → no-op (idempotent, no error).
##   - IMPASSABLE → no-op (idempotent, no error).
##
## Writes through to [code]_map.tiles[idx][/code] AND all 6 packed caches (TR-map-grid-004).
## Coord out-of-bounds or null map → push_error + no-op.
##
## Example:
##   grid.clear_occupant(Vector2i(3, 5))
func clear_occupant(coord: Vector2i) -> void:
	if _map == null:
		push_error("%s: clear_occupant called before load_map — coord %s" % [ERR_UNIT_COORD_OUT_OF_BOUNDS, str(coord)])
		return
	if coord.x < 0 or coord.x >= _map.map_cols \
			or coord.y < 0 or coord.y >= _map.map_rows:
		push_error("%s: clear_occupant coord %s out of bounds (%dx%d)" % [ERR_UNIT_COORD_OUT_OF_BOUNDS, str(coord), _map.map_cols, _map.map_rows])
		return

	var idx: int = coord.y * _map.map_cols + coord.x
	var td: MapTileData = _map.tiles[idx]
	var current_state: int = td.tile_state

	# Idempotent no-op cases.
	if current_state == TILE_STATE_EMPTY or current_state == TILE_STATE_IMPASSABLE \
			or current_state == TILE_STATE_DESTRUCTIBLE:
		return

	# Clear occupant fields.
	td.occupant_id      = 0
	td.occupant_faction = 0

	# Preserve DESTROYED state if the tile was destroyed while occupied.
	# Otherwise, return tile to EMPTY (occupant gone; terrain normal).
	if current_state != TILE_STATE_DESTROYED:
		td.tile_state = TILE_STATE_EMPTY

	_write_tile(idx, td)


## Apply [param damage] to the destructible tile at [param coord].
##
## Returns [code]true[/code] if this call destroyed the tile (destruction_hp dropped to 0
## for the first time). Returns [code]false[/code] in all other cases (non-destructible,
## partial damage, already-destroyed, or out-of-bounds).
##
## Destruction rules (AC-ST-2, AC-EDGE-4, V-6, GDD §ST-1):
##   - Non-destructible ([code]is_destructible == false[/code]) → push_warning + return false. No state change.
##   - IMPASSABLE + non-destructible → push_warning + return false (AC-ST-4).
##   - IMPASSABLE + is_destructible → allowed; on hp→0 transitions to DESTROYED with signal.
##   - Already DESTROYED ([code]tile_state == TILE_STATE_DESTROYED[/code] or
##     [code]destruction_hp == 0[/code] post-clamp) → idempotent; return false; no signal.
##   - Partial damage (hp > 0 after subtraction) → update hp + caches; return false; no signal.
##   - Destroying damage: hp → 0. Set is_passable_base=true. Set tile_state to DESTROYED
##     UNLESS the tile had an occupant (AC-EDGE-4) — in that case preserve ALLY/ENEMY_OCCUPIED.
##     Emit [code]GameBus.tile_destroyed(coord)[/code] exactly once (V-6). Return true.
##
## Writes through to [code]_map.tiles[idx][/code] AND all 6 packed caches (TR-map-grid-004).
## Coord out-of-bounds or null map → push_error + return false.
##
## Example:
##   var destroyed: bool = grid.apply_tile_damage(Vector2i(3, 5), 10)
##   if destroyed:
##       print("tile at (3,5) is gone!")
func apply_tile_damage(coord: Vector2i, damage: int) -> bool:
	if _map == null:
		push_error("%s: apply_tile_damage called before load_map — coord %s" % [ERR_UNIT_COORD_OUT_OF_BOUNDS, str(coord)])
		return false
	if coord.x < 0 or coord.x >= _map.map_cols \
			or coord.y < 0 or coord.y >= _map.map_rows:
		push_error("%s: apply_tile_damage coord %s out of bounds (%dx%d)" % [ERR_UNIT_COORD_OUT_OF_BOUNDS, str(coord), _map.map_cols, _map.map_rows])
		return false

	var idx: int = coord.y * _map.map_cols + coord.x
	var td: MapTileData = _map.tiles[idx]

	# Guard: non-destructible tiles reject damage (AC-8 / AC-ST-4 non-destructible branch).
	if not td.is_destructible:
		push_warning(
			"MapGrid: apply_tile_damage — damage on non-destructible tile at %s (is_destructible=false)" % str(coord)
		)
		return false

	# AC-ST-4: IMPASSABLE + non-destructible was caught above. Execution here means
	# is_destructible == true, so apply_tile_damage on IMPASSABLE is ALLOWED.

	# V-6 idempotence: already-destroyed tile returns false with no emit.
	if td.tile_state == TILE_STATE_DESTROYED or td.destruction_hp == 0:
		return false

	# Capture occupant state BEFORE mutation (AC-EDGE-4 — occupant survives destruction).
	var prior_state: int = td.tile_state
	var occupant_was_present: bool = (prior_state == TILE_STATE_ALLY_OCCUPIED \
			or prior_state == TILE_STATE_ENEMY_OCCUPIED)

	# Apply damage.
	var new_hp: int = max(0, td.destruction_hp - damage)
	td.destruction_hp = new_hp

	if new_hp > 0:
		# Partial damage — no destruction. Sync caches and return false.
		_write_tile(idx, td)
		return false

	# ── Tile destroyed this call ──────────────────────────────────────────────────
	# terrain is now rubble → always passable from here on.
	td.is_passable_base = true

	if occupant_was_present:
		# AC-EDGE-4: occupant outlives the tile. Preserve ALLY/ENEMY_OCCUPIED state.
		# tile_state already equals prior_state (ALLY or ENEMY_OCCUPIED); leave it.
		# occupant_id / occupant_faction already in td; leave them.
		pass
	else:
		td.tile_state = TILE_STATE_DESTROYED

	# Write through to TileData AND all 6 caches (R-4 choke-point).
	_write_tile(idx, td)

	# Emit exactly once per destruction event (V-6 contract — ADR-0004 §Decision 9).
	# Direct emit per ADR-0001 §Implementation Guidelines: emitter calls .emit() directly;
	# consumers use CONNECT_DEFERRED. Forbidden in _process/_physics_process (GameBus per-frame ban).
	GameBus.tile_destroyed.emit(coord)

	return true


## Single write-through helper: sync all 6 packed caches from [param td] (the
## already-mutated [code]_map.tiles[idx][/code] reference).
##
## This is the single choke-point that ADR-0004 R-4 defends against cache-sync drift.
## ALL mutation methods (set_occupant, clear_occupant, apply_tile_damage) MUST call
## this helper after mutating [param td] fields — never write cache entries ad-hoc.
##
## [param idx] is the flat-array index ([code]coord.y * map_cols + coord.x[/code]).
## [param td] must equal [code]_map.tiles[idx][/code] — passing any other reference
## is a contract violation.
##
## NOTE (story-004 / Option A per spec): caller passes [param td] explicitly to make
## data-flow visible at call sites. td MUST equal _map.tiles[idx]; the constraint is
## documented, not runtime-checked (no extra dereference in the hot path).
func _write_tile(idx: int, td: MapTileData) -> void:
	_terrain_type_cache[idx]     = td.terrain_type
	_elevation_cache[idx]        = td.elevation
	_passable_base_cache[idx]    = 1 if td.is_passable_base else 0
	_occupant_id_cache[idx]      = td.occupant_id
	_occupant_faction_cache[idx] = td.occupant_faction
	_tile_state_cache[idx]       = td.tile_state


# ─── Pathfinding API (story-005 / ADR-0004 §Decision 7) ──────────────────────

## Return all tiles reachable and landable by the unit at its current position
## given [param move_range] movement points.
##
## Implements custom Dijkstra on packed caches (ADR-0004 §Decision 7).
## 4-directional adjacency; integer cost budget [code]move_budget = move_range × 10[/code].
## Step cost formula: [code]BASE_TERRAIN_COST[terrain] × cost_multiplier(unit_type, terrain)[/code]
## ([TerrainCost]; ADR-0008 will replace the placeholder multiplier).
##
## Origin tile ([code]origin_coord[/code] from [code]_occupant_id_cache[/code]) is ALWAYS
## included in the result — origin cost = 0 satisfies any budget including move_range=0.
## This means [code]move_range=0[/code] returns exactly [code]PackedVector2Array([origin_coord])[/code].
##
## Traversal rules (GDD §CR-6, AC-CR-6):
##   - ENEMY_OCCUPIED tiles block traversal (and all tiles reachable only through them).
##   - ALLY_OCCUPIED tiles are traversable (can pass through) but NOT landable (excluded
##     from the returned set).
##   - IMPASSABLE tiles ([code]_passable_base_cache == 0[/code]) are never entered.
##   - EMPTY and DESTROYED tiles are both landable.
##
## Return type: [PackedVector2Array] — each element [code]Vector2(col, row)[/code] with
## integer precision (ADV-1; see class header). Callers cast: [code]Vector2i(result[i])[/code].
##
## Scratch buffers [member _priority_queue_scratch] and [member _visited_scratch]
## are cleared at entry and reused across calls (zero-alloc hot path).
##
## [param unit_id] — occupant id used to locate the unit's origin tile.
## [param move_range] — movement points (budget = move_range × 10).
## [param unit_type] — unit-type id forwarded to [method TerrainCost.cost_multiplier].
##
## Returns empty [PackedVector2Array] when:
##   - [member _map] is null (before [method load_map]).
##   - [param unit_id] is not found in [member _occupant_id_cache].
##
## Example:
##   var reachable: PackedVector2Array = grid.get_movement_range(1, 3, TerrainCost.PLAINS)
##   for v: Vector2 in reachable:
##       highlight_tile(Vector2i(v))
func get_movement_range(unit_id: int, move_range: int, unit_type: int) -> PackedVector2Array:
	if _map == null:
		return PackedVector2Array()

	# Locate the unit's origin tile by scanning occupant cache.
	var cols: int = _map.map_cols
	var rows: int = _map.map_rows
	var n: int = rows * cols
	var origin_idx: int = -1
	for i: int in n:
		if _occupant_id_cache[i] == unit_id:
			origin_idx = i
			break
	if origin_idx == -1:
		return PackedVector2Array()

	var move_budget: int = move_range * 10

	# ── Scratch reset (C-1: shared with get_movement_path; both clear at entry) ─
	_priority_queue_scratch.clear()
	_visited_scratch.resize(n)
	_visited_scratch.fill(0)

	# ── Dijkstra ──────────────────────────────────────────────────────────────
	# Priority queue entry: (cost << 16) | tile_index.
	# Max cost bounded by move_budget ≤ 100 (move_range max 10 × 10); tile_index
	# max 1200 (40×30). Both fit cleanly in Int32 with 16-bit split.
	# Enqueue origin at cost 0.
	_priority_queue_scratch.append(origin_idx)   # 0 << 16 | origin_idx

	# 4-directional neighbour offsets: (dcol, drow).
	# Stored as flat delta to avoid per-iteration array construction.
	var result: PackedVector2Array = PackedVector2Array()

	while _priority_queue_scratch.size() > 0:
		# Pop lowest-cost entry (front of sorted array).
		var entry: int = _priority_queue_scratch[0]
		_priority_queue_scratch.remove_at(0)

		var cost_so_far: int = entry >> 16
		var idx: int = entry & 0xFFFF

		# Skip if already finalised (may have been inserted multiple times at
		# lower cost before a duplicate higher-cost entry is popped).
		if _visited_scratch[idx] == 1:
			continue
		_visited_scratch[idx] = 1

		# Early exit: nothing reachable beyond this cost.
		if cost_so_far > move_budget:
			break

		# Determine landability: EMPTY or DESTROYED are landable (GDD §ST-1).
		var state: int = _tile_state_cache[idx]
		var landable: bool = (state == TILE_STATE_EMPTY or state == TILE_STATE_DESTROYED)
		# Origin tile (cost=0) is always returned even if occupied by this unit.
		if landable or idx == origin_idx:
			var col: int = idx % cols
			var row: int = idx / cols
			result.append(Vector2(col, row))

		# Expand neighbours.
		var cur_col: int = idx % cols
		var cur_row: int = idx / cols

		# Unrolled 4-directional offsets: (0,-1), (1,0), (0,1), (-1,0).
		for _dir: int in 4:
			var dcol: int
			var drow: int
			match _dir:
				0: dcol =  0; drow = -1
				1: dcol =  1; drow =  0
				2: dcol =  0; drow =  1
				3: dcol = -1; drow =  0

			var ncol: int = cur_col + dcol
			var nrow: int = cur_row + drow

			# Bounds check.
			if ncol < 0 or ncol >= cols or nrow < 0 or nrow >= rows:
				continue

			var nidx: int = nrow * cols + ncol

			# Already finalised.
			if _visited_scratch[nidx] == 1:
				continue

			# Impassable base — walls never entered.
			if _passable_base_cache[nidx] == 0:
				continue

			# Enemy-occupied — blocks traversal entirely.
			var nstate: int = _tile_state_cache[nidx]
			if nstate == TILE_STATE_ENEMY_OCCUPIED or nstate == TILE_STATE_IMPASSABLE:
				continue

			# Compute step cost.
			var terrain: int = _terrain_type_cache[nidx]
			var step: int = TerrainCost.BASE_TERRAIN_COST[terrain] \
					* TerrainCost.cost_multiplier(unit_type, terrain)
			var new_cost: int = cost_so_far + step

			if new_cost > move_budget:
				continue

			# Insert into sorted priority queue (ascending cost).
			var packed: int = (new_cost << 16) | nidx
			var insert_pos: int = _priority_queue_scratch.bsearch(packed)
			_priority_queue_scratch.insert(insert_pos, packed)

	return result


## Return the lowest-cost path from [param from] to [param to] for [param unit_type].
##
## Named [code]get_movement_path[/code] (not [code]get_path[/code]) to avoid colliding
## with the inherited [code]Node.get_path() -> NodePath[/code] built-in method.
## GDScript treats same-name overrides of Node built-ins as warning-as-error in Godot 4.6
## strict mode; renaming avoids the collision. (Session-discovered; candidate G-14.)
##
## Implements standard Dijkstra with predecessor map (ADR-0004 §Decision 7).
## Returns a [PackedVector2Array] of tiles from [param from] (inclusive) to
## [param to] (inclusive) along the minimum-cost route, or an empty array if
## [param to] is unreachable from [param from].
##
## Special cases:
##   - [code]from == to[/code]: returns [code]PackedVector2Array([from])[/code] (length 1).
##   - Unreachable [param to]: returns empty [PackedVector2Array].
##
## Traversal rules are identical to [method get_movement_range]: impassable base tiles
## and ENEMY_OCCUPIED / IMPASSABLE tile-states are never entered.
## ALLY_OCCUPIED tiles ARE traversable for path planning (the path goes through them
## but the movement-range layer decides landability).
##
## Return type: [PackedVector2Array] (ADV-1 — see class header). Each element is
## [code]Vector2(col, row)[/code]; callers cast: [code]Vector2i(result[i])[/code].
##
## Scratch buffers [member _priority_queue_scratch] and [member _visited_scratch]
## are cleared at entry (C-1 shared pattern). [code]predecessor[/code] is allocated
## per-call (per-call alloc; promote to class-scope [code]_predecessor_scratch[/code]
## if [code]get_movement_path[/code] enters AI hot path — C-2 decision).
##
## [param from] — start coordinate (must be within map bounds).
## [param to] — target coordinate (must be within map bounds).
## [param unit_type] — unit-type id forwarded to [method TerrainCost.cost_multiplier].
##
## Returns empty [PackedVector2Array] when [member _map] is null or coordinates are
## out of bounds.
##
## Example:
##   var path: PackedVector2Array = grid.get_movement_path(Vector2i(0,0), Vector2i(4,4), TerrainCost.PLAINS)
##   for v: Vector2 in path:
##       move_unit_to(Vector2i(v))
func get_movement_path(from: Vector2i, to: Vector2i, unit_type: int) -> PackedVector2Array:
	if _map == null:
		return PackedVector2Array()

	var cols: int = _map.map_cols
	var rows: int = _map.map_rows

	# Bounds checks.
	if from.x < 0 or from.x >= cols or from.y < 0 or from.y >= rows:
		return PackedVector2Array()
	if to.x < 0 or to.x >= cols or to.y < 0 or to.y >= rows:
		return PackedVector2Array()

	# from == to short-circuit.
	if from == to:
		return PackedVector2Array([Vector2(from.x, from.y)])

	var n: int = rows * cols
	var from_idx: int = from.y * cols + from.x
	var to_idx: int = to.y * cols + to.x

	# ── Scratch reset (C-1: shared with get_movement_range; both clear at entry) ─
	_priority_queue_scratch.clear()
	_visited_scratch.resize(n)
	_visited_scratch.fill(0)

	# Per-call predecessor map (C-2: acceptable for MVP; see doc comment above).
	var predecessor: PackedInt32Array = PackedInt32Array()
	predecessor.resize(n)
	predecessor.fill(-1)

	# Enqueue origin.
	_priority_queue_scratch.append(from_idx)   # 0 << 16 | from_idx

	# TODO (story-007 / AC-PERF-2): plain Dijkstra — no admissible heuristic
	# lower-bound applied. ADR-0004 §Decision 7 recommends a Manhattan-distance
	# heuristic for `get_movement_path`. Correctness is unaffected; performance
	# delta only matters at the 40×30 m=10 benchmark scale (TR-map-grid-006).
	var found: bool = false

	while _priority_queue_scratch.size() > 0:
		var entry: int = _priority_queue_scratch[0]
		_priority_queue_scratch.remove_at(0)

		var cost_so_far: int = entry >> 16
		var idx: int = entry & 0xFFFF

		if _visited_scratch[idx] == 1:
			continue
		_visited_scratch[idx] = 1

		if idx == to_idx:
			found = true
			break

		var cur_col: int = idx % cols
		var cur_row: int = idx / cols

		for _dir: int in 4:
			var dcol: int
			var drow: int
			match _dir:
				0: dcol =  0; drow = -1
				1: dcol =  1; drow =  0
				2: dcol =  0; drow =  1
				3: dcol = -1; drow =  0

			var ncol: int = cur_col + dcol
			var nrow: int = cur_row + drow

			if ncol < 0 or ncol >= cols or nrow < 0 or nrow >= rows:
				continue

			var nidx: int = nrow * cols + ncol

			if _visited_scratch[nidx] == 1:
				continue

			if _passable_base_cache[nidx] == 0:
				continue

			var nstate: int = _tile_state_cache[nidx]
			if nstate == TILE_STATE_ENEMY_OCCUPIED or nstate == TILE_STATE_IMPASSABLE:
				continue

			var terrain: int = _terrain_type_cache[nidx]
			var step: int = TerrainCost.BASE_TERRAIN_COST[terrain] \
					* TerrainCost.cost_multiplier(unit_type, terrain)
			var new_cost: int = cost_so_far + step

			# Record predecessor on first reach (and only on first reach: the
			# `predecessor[nidx] == -1` guard skips re-enqueues). Safe under
			# non-negative integer costs because Dijkstra's monotone exploration
			# guarantees the first enqueue is along the minimum-cost path —
			# duplicate higher-cost entries inserted later are filtered by the
			# `_visited_scratch[nidx] == 1` guard at pop time. Equal-cost ties
			# resolve to whichever direction was expanded first; total cost is
			# identical so the V-4 reference-equivalence test asserts on cost,
			# not on tile sequence.
			if predecessor[nidx] == -1:
				predecessor[nidx] = idx

			var packed: int = (new_cost << 16) | nidx
			var insert_pos: int = _priority_queue_scratch.bsearch(packed)
			_priority_queue_scratch.insert(insert_pos, packed)

	if not found:
		return PackedVector2Array()

	# Walk predecessor chain from to_idx back to from_idx, then reverse.
	var path_indices: PackedInt32Array = PackedInt32Array()
	var cur: int = to_idx
	while cur != -1:
		path_indices.append(cur)
		if cur == from_idx:
			break
		cur = predecessor[cur]

	# Reverse to get from→to order.
	var result: PackedVector2Array = PackedVector2Array()
	var path_len: int = path_indices.size()
	for i: int in path_len:
		var tile_idx: int = path_indices[path_len - 1 - i]
		result.append(Vector2(tile_idx % cols, tile_idx / cols))

	return result


# ─── Query API — line of sight (story-006 / ADR-0004 §Decision 8) ────────────

## Return [code]true[/code] if [param from] has unobstructed line of sight to [param to].
##
## Uses integer Bresenham rasterization over [member _elevation_cache] and
## [member _passable_base_cache]. An intermediate tile blocks LoS iff:
## [br]• its elevation is strictly greater than [code]max(from.elevation, to.elevation)[/code], OR
## [br]• [member _passable_base_cache] is 0 (impassable wall — destroyed walls have base=1 per
## [method apply_tile_damage] and are NOT blocking, satisfying §Decision 8 "destroyed walls
## no longer block").
##
## Endpoints never self-block: the [param from] and [param to] tiles themselves are never
## evaluated as blockers. For Manhattan distance ≤ 1 (adjacent or same tile) this returns
## immediately without entering the Bresenham loop (AC-EDGE-3, GDD §EC-3).
##
## Same-tile case ([code]from == to[/code], D=0): emits
## [code]push_warning("ERR_SAME_TILE_LOS")[/code] and returns [code]true[/code]
## (caller bug, deterministic recovery).
##
## §EC-3 corner-cut conservatism: when the Bresenham step is diagonal (both axes step in the
## same iteration), the line passes exactly through the corner shared by four tiles. To prevent
## the "shoot through wall gap" exploit, BOTH cardinal-adjacent tiles
## [code](prev_x, y)[/code] and [code](x, prev_y)[/code] are evaluated as intermediates — if
## either blocks, LoS is blocked.
##
## Hot-path discipline: the loop reads only [member _elevation_cache] and
## [member _passable_base_cache] — no [method get_tile] calls, no [MapTileData] dereference.
##
## Returns [code]false[/code] if [member _map] is null or coordinates are out of bounds
## (defensive — should not occur in normal use as caller is the authoritative GridBattle).
##
## Example:
## [codeblock]
## # Check if archer at (3,5) can fire at enemy at (8,5) with intervening forest.
## if grid.has_line_of_sight(Vector2i(3, 5), Vector2i(8, 5)):
##     # Archer can attack — proceed with damage calc.
## [/codeblock]
func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool:
	if _map == null:
		return false

	var cols: int = _map.map_cols
	var rows: int = _map.map_rows

	# Bounds check — defensive guard.
	if from.x < 0 or from.x >= cols or from.y < 0 or from.y >= rows:
		return false
	if to.x < 0 or to.x >= cols or to.y < 0 or to.y >= rows:
		return false

	# Same-tile guard (D=0): caller bug, warn, return true.
	if from == to:
		push_warning("ERR_SAME_TILE_LOS")
		return true

	# Manhattan distance ≤ 1: adjacent tiles always have LoS (AC-EDGE-3).
	# No intermediate tiles exist — short-circuit before entering the Bresenham loop.
	var manhattan: int = absi(to.x - from.x) + absi(to.y - from.y)
	if manhattan <= 1:
		return true

	# Cache the elevation max once before the loop.
	var from_elev: int = _elevation_cache[from.y * cols + from.x]
	var to_elev:   int = _elevation_cache[to.y * cols + to.x]
	var elev_max:  int = maxi(from_elev, to_elev)

	# Integer Bresenham — sign-agnostic form. We advance from `from` toward `to`,
	# checking each intermediate tile. Endpoints are never checked.
	var x: int  = from.x
	var y: int  = from.y
	var dx: int = absi(to.x - from.x)
	var dy: int = absi(to.y - from.y)
	var sx: int = 1 if to.x > from.x else -1
	var sy: int = 1 if to.y > from.y else -1
	var err: int = dx - dy

	# Loop guarded by step count — Manhattan distance is the upper bound on iterations.
	# Belt-and-braces: bound at dx+dy+1 to prevent infinite loop on any algorithmic flaw.
	var max_steps: int = dx + dy + 1
	var step: int = 0

	while step < max_steps:
		step += 1
		var e2: int = 2 * err
		var prev_x: int = x
		var prev_y: int = y

		# Determine which axes step this iteration.
		var step_x: bool = e2 > -dy
		var step_y: bool = e2 < dx

		if step_x:
			err -= dy
			x += sx
		if step_y:
			err += dx
			y += sy

		# Order matters: corner-cut tiles are OFF-LINE cardinal neighbours of the
		# corner (NOT endpoints) — they must be checked BEFORE the destination guard,
		# because a D=2 diagonal (e.g. (1,1)→(2,2)) lands on `to` in a single iteration
		# and would otherwise skip the corner-cut check entirely.
		if step_x and step_y:
			# Diagonal step: line passed exactly through the corner shared by
			# (prev_x, prev_y), (prev_x, y), (x, prev_y), and (x, y). Per §EC-3
			# conservative rule, check the two OFF-LINE cardinal-adjacent tiles —
			# if either blocks, LoS blocked.
			if _tile_blocks_los(prev_x, y, elev_max, cols):
				return false
			if _tile_blocks_los(x, prev_y, elev_max, cols):
				return false

		# Reached destination — endpoint never self-blocks.
		if x == to.x and y == to.y:
			return true

		# Check the new (x, y) tile as an intermediate. Applies to BOTH cardinal
		# AND diagonal steps — on a diagonal step we have already advanced THROUGH
		# the corner (handled above) into (x, y), and (x, y) is on the line and
		# must be evaluated as an intermediate blocker like any other.
		if _tile_blocks_los(x, y, elev_max, cols):
			return false

	# Unreachable under correct Bresenham termination, but GDScript requires a return.
	return true


## Internal LoS blocking predicate. Returns [code]true[/code] iff the tile at
## [code](tx, ty)[/code] blocks line of sight given [param elev_max] (= max of from/to
## elevations).
##
## A tile blocks iff either:
## [br]• its [code]_passable_base_cache[/code] entry is 0 (impassable terrain — wall), OR
## [br]• its [code]_elevation_cache[/code] entry exceeds [param elev_max].
##
## Hot-path: reads packed caches only. No allocations.
##
## [param tx], [param ty] — tile column and row (caller must have bounds-checked).
## [param elev_max] — pre-computed [code]max(from_elev, to_elev)[/code].
## [param cols] — map column count (passed in to avoid re-reading [member _map]).
func _tile_blocks_los(tx: int, ty: int, elev_max: int, cols: int) -> bool:
	var tidx: int = ty * cols + tx
	if _passable_base_cache[tidx] == 0:
		return true
	if _elevation_cache[tidx] > elev_max:
		return true
	return false


# ─── Query API — attack range / direction / occupants (story-006) ─────────────

## Return all tiles within Manhattan distance [param attack_range] of [param origin],
## EXCLUDING [param origin] itself.
##
## When [param apply_los] is [code]true[/code], filters out tiles where
## [method has_line_of_sight](origin, tile) returns [code]false[/code]. Callers decide
## per-call: melee skips LoS (passes [code]false[/code]); ranged applies LoS
## (passes [code]true[/code]) per GDD §CR-7 ("원거리 유닛에만 적용").
##
## Bounds-clipped against [member _map].map_cols / map_rows. Returns an empty
## [PackedVector2Array] when [member _map] is null, [param attack_range] is 0, or no
## valid tiles remain after filtering.
##
## Return type: [PackedVector2Array] (ADV-1 — see [method get_movement_range]).
## Each element is [code]Vector2(col, row)[/code]; cast to [Vector2i] at call sites.
##
## Complexity: O(attack_range²) candidate enumeration; O(attack_range² × distance) when
## [param apply_los] is [code]true[/code] (one Bresenham per candidate).
##
## Example:
## [codeblock]
## # Get all attackable tiles for a ranged unit at (5,5) with range 4 and LoS rules.
## var tiles: PackedVector2Array = grid.get_attack_range(Vector2i(5, 5), 4, true)
## [/codeblock]
func get_attack_range(origin: Vector2i, attack_range: int, apply_los: bool) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	if _map == null or attack_range <= 0:
		return result

	var cols: int = _map.map_cols
	var rows: int = _map.map_rows

	# Bounds-check origin defensively.
	if origin.x < 0 or origin.x >= cols or origin.y < 0 or origin.y >= rows:
		return result

	# Manhattan-diamond enumeration centered on origin.
	for dr: int in range(-attack_range, attack_range + 1):
		var nrow: int = origin.y + dr
		if nrow < 0 or nrow >= rows:
			continue
		var dc_max: int = attack_range - absi(dr)
		for dc: int in range(-dc_max, dc_max + 1):
			# Exclude origin itself (attacker doesn't attack own tile).
			if dc == 0 and dr == 0:
				continue
			var ncol: int = origin.x + dc
			if ncol < 0 or ncol >= cols:
				continue

			var tile: Vector2i = Vector2i(ncol, nrow)
			if apply_los and not has_line_of_sight(origin, tile):
				continue
			result.append(Vector2(ncol, nrow))

	return result


## Return the angular relationship between [param attacker] and [param defender] given
## the defender's [param defender_facing].
##
## Returns one of [constant ATK_DIR_FRONT], [constant ATK_DIR_FLANK], or
## [constant ATK_DIR_REAR] per the GDD §F-5 formula:
## [codeblock]
## attack_dir = (horizontal axis if abs(dc) >= abs(dr), else vertical axis)
## relative_angle = (attack_dir - defender_facing + 4) % 4
## lookup: 0 → FRONT, 1 → FLANK, 2 → REAR, 3 → FLANK
## [/codeblock]
##
## §EC-4 horizontal tie-break: when [code]abs(dc) == abs(dr)[/code] (perfect diagonal
## offset), the horizontal axis (EAST/WEST) wins — encoded by the [code]>=[/code]
## comparison. This is the deterministic cross-system rule shared with
## [code]design/gdd/damage-calc.md[/code].
##
## Same-tile case ([param attacker] == [param defender]): emits
## [code]push_warning("ERR_SAME_TILE_ATTACK")[/code] and returns
## [constant ATK_DIR_FRONT] (caller bug, deterministic recovery).
##
## [param defender_facing] must be one of [constant FACING_NORTH], [constant FACING_EAST],
## [constant FACING_SOUTH], [constant FACING_WEST]. Out-of-range values produce undefined
## behavior — caller is GridBattleController which guards its inputs.
##
## Example:
## [codeblock]
## # Defender at (5,5) faces NORTH; attacker at (5,4) (directly north).
## # dc=0, dr=-1 → vertical, NORTH attack_dir → relative_angle=0 → FRONT.
## var dir: int = grid.get_attack_direction(Vector2i(5, 4), Vector2i(5, 5), MapGrid.FACING_NORTH)
## # dir == MapGrid.ATK_DIR_FRONT
## [/codeblock]
func get_attack_direction(attacker: Vector2i, defender: Vector2i, defender_facing: int) -> int:
	var dc: int = defender.x - attacker.x
	var dr: int = defender.y - attacker.y

	# Same-tile guard (§EC-4): caller bug, warn, return deterministic FRONT.
	if dc == 0 and dr == 0:
		push_warning("ERR_SAME_TILE_ATTACK")
		return ATK_DIR_FRONT

	# Determine the compass direction FROM the defender's perspective of where the
	# attacker is — i.e., the direction the attack came FROM. With
	#   dc = defender.x - attacker.x  → dc > 0 means attacker.x < defender.x → attacker is WEST
	#   dr = defender.y - attacker.y  → dr > 0 means attacker.y < defender.y → attacker is NORTH
	# §EC-4 horizontal tie-break: `>=` on equal-magnitude diagonal → horizontal axis wins.
	#
	# NOTE (TD-032 A-22): story-006 spec line 70-73 wrote
	#   "EAST if dc > 0, SOUTH if dr > 0" which is internally inconsistent with the
	# AC-8 expected matrix (attacker N(7,6) of defender(7,7) facing-NORTH must yield
	# FRONT). The AC-8 expectations are canonical; spec line 70-73 has the sign
	# flipped. Story-006 spec needs errata.
	var attack_dir: int
	if absi(dc) >= absi(dr):
		# Horizontal axis dominates (or ties — §EC-4 horizontal wins).
		attack_dir = FACING_WEST if dc > 0 else FACING_EAST
	else:
		# Vertical axis dominates.
		attack_dir = FACING_NORTH if dr > 0 else FACING_SOUTH

	# `relative_angle = (attack_dir - defender_facing + 4) % 4` then lookup.
	var relative_angle: int = (attack_dir - defender_facing + 4) % 4
	match relative_angle:
		0: return ATK_DIR_FRONT
		1: return ATK_DIR_FLANK
		2: return ATK_DIR_REAR
		3: return ATK_DIR_FLANK
	# Unreachable (relative_angle ∈ [0,3]), but GDScript needs an explicit return.
	return ATK_DIR_FRONT


## Return unit IDs from the 4 cardinal neighbours of [param coord].
##
## When [param faction] is non-default ([code]-1[/code] = any faction), filters to units
## of that faction only. Reads [member _occupant_id_cache] and [member _occupant_faction_cache];
## a tile with [code]_occupant_id_cache == 0[/code] has no occupant and is skipped.
##
## Result is NOT de-duplicated — adjacency is by tile, not by unit. Under the MVP
## ADR-0004 contract (1 tile = 1 unit) this is irrelevant; if multi-tile units arrive
## later, callers must de-duplicate.
##
## Returns an empty [PackedInt32Array] when [member _map] is null, [param coord] is out of
## bounds, or no qualifying neighbours exist.
##
## Example:
## [codeblock]
## # Get all enemy units adjacent to player at (3,4) for area-of-effect targeting.
## var enemy_neighbours: PackedInt32Array = grid.get_adjacent_units(
##         Vector2i(3, 4), MapGrid.FACTION_ENEMY)
## [/codeblock]
func get_adjacent_units(coord: Vector2i, faction: int = -1) -> PackedInt32Array:
	var result: PackedInt32Array = PackedInt32Array()
	if _map == null:
		return result

	var cols: int = _map.map_cols
	var rows: int = _map.map_rows

	# Bounds-check coord defensively.
	if coord.x < 0 or coord.x >= cols or coord.y < 0 or coord.y >= rows:
		return result

	# 4-directional cardinal offsets: (dcol, drow).
	for _dir: int in 4:
		var dcol: int
		var drow: int
		match _dir:
			0: dcol =  0; drow = -1  # NORTH
			1: dcol =  1; drow =  0  # EAST
			2: dcol =  0; drow =  1  # SOUTH
			3: dcol = -1; drow =  0  # WEST

		var ncol: int = coord.x + dcol
		var nrow: int = coord.y + drow

		# Bounds-skip out-of-map.
		if ncol < 0 or ncol >= cols or nrow < 0 or nrow >= rows:
			continue

		var nidx: int = nrow * cols + ncol
		var uid: int = _occupant_id_cache[nidx]
		# No occupant → skip.
		if uid == 0:
			continue
		# Faction filter (-1 = any).
		if faction != -1 and _occupant_faction_cache[nidx] != faction:
			continue
		result.append(uid)

	return result


## Return all tiles currently occupied by a unit, in row-major order.
##
## When [param faction] is non-default ([code]-1[/code] = any faction), filters to
## occupants of that faction only. Single full-map scan over [member _occupant_id_cache];
## acceptable because callers (AI, HUD) invoke this at round boundaries, NOT per-frame.
##
## Result ordering is deterministic (row-major: ascending [code]y * cols + x[/code]),
## which is asserted by AC-12 of story-006.
##
## Returns an empty [PackedVector2Array] when [member _map] is null or no occupants
## match the filter.
##
## Return type: [PackedVector2Array] (ADV-1 — see [method get_movement_range]).
## Each element is [code]Vector2(col, row)[/code]; cast to [Vector2i] at call sites.
##
## Complexity: O(rows × cols) regardless of occupant count.
##
## Example:
## [codeblock]
## # Get all ally units' positions at end-of-turn for save-state snapshot.
## var allies: PackedVector2Array = grid.get_occupied_tiles(MapGrid.FACTION_ALLY)
## [/codeblock]
func get_occupied_tiles(faction: int = -1) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	if _map == null:
		return result

	var cols: int = _map.map_cols
	var rows: int = _map.map_rows
	var n: int = rows * cols

	# Single row-major pass — deterministic ordering required by AC-12.
	for i: int in n:
		if _occupant_id_cache[i] == 0:
			continue
		if faction != -1 and _occupant_faction_cache[i] != faction:
			continue
		result.append(Vector2(i % cols, i / cols))

	return result
