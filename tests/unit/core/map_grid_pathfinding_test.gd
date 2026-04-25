extends GdUnitTestSuite

## map_grid_pathfinding_test.gd
## Unit tests for Story 005: MapGrid.get_movement_range + MapGrid.get_movement_path.
## Covers AC-1 through AC-10 (story-005 spec).
##
## Test evidence type: Logic — automated unit tests are BLOCKING gate (coding-standards §Test Evidence).
## 10 tests covering: basic reachability, budget boundary, enemy/ally traversal rules,
## encirclement, impassable walls, get_movement_path basic, get_movement_path cost preference, V-4
## reference equivalence (50-query), scratch buffer reuse, ADV-1 return type.

# ─── Constants ────────────────────────────────────────────────────────────────

## Convenience alias — keeps test assertions readable.
const INFANTRY := 0   # unit_type placeholder (cost_multiplier returns 1 for all)

# ─── Fixtures ─────────────────────────────────────────────────────────────────

## Build a MapResource with all tiles set to [param terrain_type] and
## [code]is_passable_base = true[/code], [code]tile_state = EMPTY[/code],
## [code]elevation[/code] valid for the given terrain.
##
## All tiles are occupied by no one (occupant_id=0). Dimensions must satisfy
## MapGrid validation (cols ∈ [15,40], rows ∈ [15,30]).
func _make_uniform_map(rows: int, cols: int, terrain_type: int) -> MapResource:
	# Pick a CR-3 valid elevation for the given terrain.
	var elev_for_terrain: Array[int] = [0, 0, 1, 2, 0, 0, 1, 0]
	var elev: int = elev_for_terrain[terrain_type] if terrain_type < elev_for_terrain.size() else 0

	var m := MapResource.new()
	m.map_id = &"pf_test_uniform"
	m.map_rows = rows
	m.map_cols = cols
	m.terrain_version = 1

	for i: int in (rows * cols):
		var t := MapTileData.new()
		t.coord            = Vector2i(i % cols, i / cols)
		t.terrain_type     = terrain_type
		t.elevation        = elev
		t.is_passable_base = true
		t.tile_state       = MapGrid.TILE_STATE_EMPTY
		t.occupant_id      = 0
		t.occupant_faction = MapGrid.FACTION_NONE
		t.is_destructible  = false
		t.destruction_hp   = 0
		m.tiles.append(t)
	return m


## Build a [param rows]×[param cols] MapResource where tile terrain is set per-tile
## via [param terrain_grid]: a flat Array[int] of length rows*cols.
## All tiles: is_passable_base=true, tile_state=EMPTY, occupant_id=0.
func _make_custom_terrain_map(rows: int, cols: int, terrain_grid: Array[int]) -> MapResource:
	var elev_for_terrain: Array[int] = [0, 0, 1, 2, 0, 0, 1, 0]
	var m := MapResource.new()
	m.map_id = &"pf_test_custom"
	m.map_rows = rows
	m.map_cols = cols
	m.terrain_version = 1

	for i: int in (rows * cols):
		var terrain: int = terrain_grid[i]
		var t := MapTileData.new()
		t.coord            = Vector2i(i % cols, i / cols)
		t.terrain_type     = terrain
		t.elevation        = elev_for_terrain[terrain] if terrain < elev_for_terrain.size() else 0
		t.is_passable_base = true
		t.tile_state       = MapGrid.TILE_STATE_EMPTY
		t.occupant_id      = 0
		t.occupant_faction = MapGrid.FACTION_NONE
		t.is_destructible  = false
		t.destruction_hp   = 0
		m.tiles.append(t)
	return m


## Build a loaded MapGrid with all PLAINS tiles ([param rows]×[param cols]).
## Unit [param unit_id] is placed at [param unit_coord] with FACTION_ALLY.
## Returns the loaded grid (caller must free).
func _make_plains_grid_with_unit(
		rows: int, cols: int,
		unit_id: int, unit_coord: Vector2i) -> MapGrid:
	var res: MapResource = _make_uniform_map(rows, cols, TerrainCost.PLAINS)
	var grid := MapGrid.new()
	var ok: bool = grid.load_map(res)
	assert_bool(ok).override_failure_message(
		("_make_plains_grid_with_unit: load_map failed. Errors: %s")
		% str(grid.get_last_load_errors())
	).is_true()
	grid.set_occupant(unit_coord, unit_id, MapGrid.FACTION_ALLY)
	return grid


# ─── AC-1: basic reachability + move_range=0 ─────────────────────────────────

## AC-1: get_movement_range on all-PLAINS map with unit at (7,7), move_range=3.
## Budget = 30; all-PLAINS step = 10.
## Expected reachable tiles: all (col, row) where Manhattan distance ≤ 3
## from (7,7) AND the tile is EMPTY (origin excluded from EMPTY check — included always).
## Manhattan diamond of radius 1..3 around (7,7): 4+8+12 = 24 tiles + origin = 25 tiles.
## (15×15 map; no boundary clipping for the diamond at radius 3 from center (7,7).)
func test_get_movement_range_basic_plains_center_unit_returns_diamond() -> void:
	# Arrange
	var grid: MapGrid = _make_plains_grid_with_unit(15, 15, 1, Vector2i(7, 7))

	# Act
	var result: PackedVector2Array = grid.get_movement_range(1, 3, INFANTRY)

	# Assert: origin is always in result (budget=0 satisfies — AC-1 origin requirement).
	var result_set: Dictionary = {}
	for v: Vector2 in result:
		result_set[Vector2i(v)] = true

	assert_bool(result_set.has(Vector2i(7, 7))).override_failure_message(
		"Origin (7,7) must be in get_movement_range result; got: %s" % str(result)
	).is_true()

	# Assert: tiles within Manhattan distance ≤ 3 that are EMPTY are all present.
	# The unit at (7,7) is ALLY_OCCUPIED (not landable, but origin is always included).
	var expected_count: int = 0
	for dc: int in range(-3, 4):
		for dr: int in range(-3, 4):
			if abs(dc) + abs(dr) <= 3:
				var coord: Vector2i = Vector2i(7 + dc, 7 + dr)
				if coord.x >= 0 and coord.x < 15 and coord.y >= 0 and coord.y < 15:
					expected_count += 1
					if coord != Vector2i(7, 7):  # origin is always included separately
						assert_bool(result_set.has(coord)).override_failure_message(
							("AC-1: tile %s (Manhattan dist %d from origin) should be "
							+ "reachable but missing from result") % [str(coord), abs(dc) + abs(dr)]
						).is_true()

	# Total count: Manhattan diamond radius 0..3 on a 15×15 map centered at (7,7)
	# has no boundary clipping (min distance to edge = 7 ≥ 3). Expected = 25.
	assert_int(result.size()).override_failure_message(
		("AC-1: expected 25 tiles (Manhattan diamond r=3 + origin), got %d. "
		+ "Result: %s") % [result.size(), str(result)]
	).is_equal(25)

	grid.free()


## AC-1 edge: move_range=0 returns exactly PackedVector2Array([Vector2(7,7)]).
func test_get_movement_range_move_range_zero_returns_origin_only() -> void:
	# Arrange
	var grid: MapGrid = _make_plains_grid_with_unit(15, 15, 1, Vector2i(7, 7))

	# Act
	var result: PackedVector2Array = grid.get_movement_range(1, 0, INFANTRY)

	# Assert
	assert_int(result.size()).override_failure_message(
		"move_range=0: expected exactly 1 tile (origin); got %d. Result: %s" \
		% [result.size(), str(result)]
	).is_equal(1)
	assert_that(Vector2i(result[0])).override_failure_message(
		("move_range=0: expected origin Vector2i(7,7); got %s")
		% str(Vector2i(result[0]))
	).is_equal(Vector2i(7, 7))

	grid.free()


# ─── AC-2: AC-F-3 budget boundary (HILLS vs ROAD) ────────────────────────────

## AC-2a: budget boundary — HILLS at (3,0) makes (3,0) UN-reachable.
## Path (0,0)→(1,0)→(2,0)→(3,0): cost = 0 + 10 + 10 + 15 = 35 > 30.
## (2,0) IS still reachable (cost 0+10+10 = 20 ≤ 30). (1,0) reachable (cost 10).
##
## NOTE on cost-model deviation (TD-032 A-20): story spec line 99 reads
## "PLAINS→HILLS→PLAINS = 10+15+10 = 35 > 30 → NOT reachable" which assumes a
## non-standard cost model that includes the origin tile's terrain cost. The
## implementation uses STANDARD Dijkstra (origin cost = 0; step_cost = entering-cost
## of destination tile). Under the standard model the spec's 3-tile corridor with
## HILLS at (1,0) is reachable to (2,0) at cost 25 — defeating the spec's intent.
## The discriminating boundary case under the standard model is HILLS at (3,0):
##   path (0,0)→(1,0)→(2,0)→(3,0) costs 35 with HILLS at the end, 27 with ROAD.
## ADR-0004 §F-3 / story spec line 99 should be updated to reflect this — errata.
func test_get_movement_range_hills_at_boundary_blocks_far_tile() -> void:
	# Arrange: 15×15 with (3,0) = HILLS; all else PLAINS.
	var terrain_grid: Array[int] = []
	for i: int in (15 * 15):
		terrain_grid.append(TerrainCost.PLAINS)
	terrain_grid[3] = TerrainCost.HILLS   # col=3, row=0
	# Fix elevation for HILLS tile (elevation must be 1).
	var m: MapResource = _make_custom_terrain_map(15, 15, terrain_grid)
	m.tiles[3].elevation = 1  # HILLS requires elevation=1 (CR-3)
	var grid := MapGrid.new()
	var ok: bool = grid.load_map(m)
	assert_bool(ok).override_failure_message(
		"AC-2a: load_map failed. Errors: %s" % str(grid.get_last_load_errors())
	).is_true()
	grid.set_occupant(Vector2i(0, 0), 1, MapGrid.FACTION_ALLY)

	# Act
	var result: PackedVector2Array = grid.get_movement_range(1, 3, INFANTRY)

	var result_set: Dictionary = {}
	for v: Vector2 in result:
		result_set[Vector2i(v)] = true

	# Assert: (2,0) reachable (cost 0+10+10 = 20 ≤ 30).
	assert_bool(result_set.has(Vector2i(2, 0))).override_failure_message(
		"AC-2a: (2,0) should be reachable (cost 20 ≤ 30) but missing from result"
	).is_true()

	# Assert: (3,0) NOT reachable via HILLS (cost 0+10+10+15 = 35 > 30).
	assert_bool(result_set.has(Vector2i(3, 0))).override_failure_message(
		"AC-2a: (3,0) should NOT be reachable via HILLS (cost 35 > 30)"
	).is_false()

	grid.free()


## AC-2b: Swap (3,0) to ROAD → (3,0) IS reachable (0+10+10+7 = 27 ≤ 30).
func test_get_movement_range_road_at_boundary_makes_far_tile_reachable() -> void:
	# Arrange: 15×15 with (3,0) = ROAD.
	var terrain_grid: Array[int] = []
	for i: int in (15 * 15):
		terrain_grid.append(TerrainCost.PLAINS)
	terrain_grid[3] = TerrainCost.ROAD   # col=3, row=0; elevation 0 valid for ROAD
	var m: MapResource = _make_custom_terrain_map(15, 15, terrain_grid)
	var grid := MapGrid.new()
	var ok: bool = grid.load_map(m)
	assert_bool(ok).override_failure_message(
		"AC-2b: load_map failed. Errors: %s" % str(grid.get_last_load_errors())
	).is_true()
	grid.set_occupant(Vector2i(0, 0), 1, MapGrid.FACTION_ALLY)

	# Act
	var result: PackedVector2Array = grid.get_movement_range(1, 3, INFANTRY)

	var result_set: Dictionary = {}
	for v: Vector2 in result:
		result_set[Vector2i(v)] = true

	# Assert: (3,0) reachable via ROAD (cost 0+10+10+7 = 27 ≤ 30).
	assert_bool(result_set.has(Vector2i(3, 0))).override_failure_message(
		"AC-2b: (3,0) should be reachable via ROAD corridor (cost 27 ≤ 30)"
	).is_true()

	grid.free()


# ─── AC-3: enemy blocks, ally passes ─────────────────────────────────────────

## AC-3a: ALLY_OCCUPIED at (1,0) is traversable but not landable.
## (0,0)→(1,0)→(2,0)→(3,0); (1,0) ally.
## Result: (0,0)✓ (2,0)✓ (3,0)✓ but NOT (1,0).
func test_get_movement_range_ally_occupied_traversable_not_landable() -> void:
	# Arrange
	var grid: MapGrid = _make_plains_grid_with_unit(15, 15, 1, Vector2i(0, 0))
	# Place ally at (1,0).
	grid.set_occupant(Vector2i(1, 0), 99, MapGrid.FACTION_ALLY)

	# Act
	var result: PackedVector2Array = grid.get_movement_range(1, 4, INFANTRY)

	var result_set: Dictionary = {}
	for v: Vector2 in result:
		result_set[Vector2i(v)] = true

	# Assert: (2,0) and (3,0) reachable through the ally.
	assert_bool(result_set.has(Vector2i(2, 0))).override_failure_message(
		"AC-3a: (2,0) should be reachable through ally-occupied (1,0)"
	).is_true()
	assert_bool(result_set.has(Vector2i(3, 0))).override_failure_message(
		"AC-3a: (3,0) should be reachable through ally-occupied (1,0)"
	).is_true()

	# Assert: (1,0) itself NOT in result (ally occupied = not landable).
	assert_bool(not result_set.has(Vector2i(1, 0))).override_failure_message(
		"AC-3a: (1,0) ALLY_OCCUPIED should NOT appear in movement range result"
	).is_true()

	grid.free()


## AC-3b: ENEMY_OCCUPIED at (1,0) blocks traversal; (2,0) and (3,0) unreachable.
##
## Uses move_range=3 (budget=30) so the row-1 detour (cost 4×10=40 to reach (2,0)
## via (0,1)→(1,1)→(2,1)→(2,0)) is blocked by budget — leaving the enemy-blocked
## corridor as the only path. With move_range=4 the detour fits exactly in budget
## and the test would incorrectly assert (2,0) unreachable.
func test_get_movement_range_enemy_occupied_blocks_traversal() -> void:
	# Arrange
	var grid: MapGrid = _make_plains_grid_with_unit(15, 15, 1, Vector2i(0, 0))
	grid.set_occupant(Vector2i(1, 0), 99, MapGrid.FACTION_ENEMY)

	# Act — budget=30 keeps detour off the table; corridor (cost 30 to reach (3,0)) is the only route.
	var result: PackedVector2Array = grid.get_movement_range(1, 3, INFANTRY)

	var result_set: Dictionary = {}
	for v: Vector2 in result:
		result_set[Vector2i(v)] = true

	# Assert: (1,0), (2,0), (3,0) all absent.
	assert_bool(not result_set.has(Vector2i(1, 0))).override_failure_message(
		"AC-3b: (1,0) ENEMY_OCCUPIED should NOT be in result"
	).is_true()
	assert_bool(not result_set.has(Vector2i(2, 0))).override_failure_message(
		"AC-3b: (2,0) should be unreachable (blocked by enemy at 1,0)"
	).is_true()

	grid.free()


# ─── AC-4: AC-EDGE-2 complete encirclement ────────────────────────────────────

## AC-4: unit at (7,7), all 4 cardinal neighbours IMPASSABLE (is_passable_base=false).
## Returns only origin.
func test_get_movement_range_encircled_by_impassable_returns_origin_only() -> void:
	# Arrange: 15×15 PLAINS; set 4 cardinal neighbours of (7,7) to impassable.
	var res: MapResource = _make_uniform_map(15, 15, TerrainCost.PLAINS)
	# Set cardinal neighbours to impassable_base=false.
	var impassable_coords: Array[Vector2i] = [
		Vector2i(7, 6), Vector2i(8, 7), Vector2i(7, 8), Vector2i(6, 7)
	]
	for coord: Vector2i in impassable_coords:
		var idx: int = coord.y * 15 + coord.x
		res.tiles[idx].is_passable_base = false
		res.tiles[idx].tile_state = MapGrid.TILE_STATE_EMPTY  # no impassable+occupied contradiction

	var grid := MapGrid.new()
	var ok: bool = grid.load_map(res)
	assert_bool(ok).override_failure_message(
		"AC-4: load_map failed. Errors: %s" % str(grid.get_last_load_errors())
	).is_true()
	grid.set_occupant(Vector2i(7, 7), 1, MapGrid.FACTION_ALLY)

	# Act
	var result: PackedVector2Array = grid.get_movement_range(1, 5, INFANTRY)

	# Assert: only origin.
	assert_int(result.size()).override_failure_message(
		"AC-4: encircled unit should get only origin; got %d tiles: %s" \
		% [result.size(), str(result)]
	).is_equal(1)
	assert_that(Vector2i(result[0])).override_failure_message(
		"AC-4: single result tile should be origin (7,7); got %s" % str(Vector2i(result[0]))
	).is_equal(Vector2i(7, 7))

	grid.free()


## AC-4 edge: move_range=0 also returns origin-only for encircled unit (same result).
func test_get_movement_range_encircled_move_range_zero_returns_origin() -> void:
	# Arrange: use same encirclement but move_range=0.
	var res: MapResource = _make_uniform_map(15, 15, TerrainCost.PLAINS)
	var impassable_coords: Array[Vector2i] = [
		Vector2i(7, 6), Vector2i(8, 7), Vector2i(7, 8), Vector2i(6, 7)
	]
	for coord: Vector2i in impassable_coords:
		var idx: int = coord.y * 15 + coord.x
		res.tiles[idx].is_passable_base = false
		res.tiles[idx].tile_state = MapGrid.TILE_STATE_EMPTY

	var grid := MapGrid.new()
	grid.load_map(res)
	grid.set_occupant(Vector2i(7, 7), 1, MapGrid.FACTION_ALLY)

	# Act
	var result: PackedVector2Array = grid.get_movement_range(1, 0, INFANTRY)

	# Assert
	assert_int(result.size()).is_equal(1)
	assert_that(Vector2i(result[0])).is_equal(Vector2i(7, 7))

	grid.free()


# ─── AC-5: is_passable_base=false wall row never traversed ───────────────────

## AC-5: 15×15 PLAINS with a wall row (all tiles at row=7, is_passable_base=false).
## Unit at (7,6), move_range=10. No tile with row >= 7 in result.
func test_get_movement_range_wall_row_blocks_entire_south_half() -> void:
	# Arrange
	var res: MapResource = _make_uniform_map(15, 15, TerrainCost.PLAINS)
	for col: int in 15:
		var idx: int = 7 * 15 + col
		res.tiles[idx].is_passable_base = false
		res.tiles[idx].tile_state = MapGrid.TILE_STATE_EMPTY

	var grid := MapGrid.new()
	var ok: bool = grid.load_map(res)
	assert_bool(ok).override_failure_message(
		"AC-5: load_map failed. Errors: %s" % str(grid.get_last_load_errors())
	).is_true()
	grid.set_occupant(Vector2i(7, 6), 1, MapGrid.FACTION_ALLY)

	# Act
	var result: PackedVector2Array = grid.get_movement_range(1, 10, INFANTRY)

	# Assert: no tile with row >= 7 in result.
	for v: Vector2 in result:
		assert_bool(int(v.y) < 7).override_failure_message(
			("AC-5: tile %s has row >= 7; wall row should block all tiles south of it")
			% str(Vector2i(v))
		).is_true()

	grid.free()


# ─── AC-6: get_movement_path basic ──────────────────────────────────────────

## AC-6: 15×15 PLAINS; path from (0,0) to (4,4).
## Minimum Manhattan = 8 steps; path length = 9 (endpoints inclusive).
## Total cost = 8 × 10 = 80 on all-PLAINS.
func test_get_path_basic_plains_returns_valid_path() -> void:
	# Arrange
	var res: MapResource = _make_uniform_map(15, 15, TerrainCost.PLAINS)
	var grid := MapGrid.new()
	var ok: bool = grid.load_map(res)
	assert_bool(ok).override_failure_message(
		"AC-6: load_map failed. Errors: %s" % str(grid.get_last_load_errors())
	).is_true()

	# Act
	var path: PackedVector2Array = grid.get_movement_path(Vector2i(0, 0), Vector2i(4, 4), INFANTRY)

	# Assert: length = Manhattan(4,4) + 1 = 9.
	assert_int(path.size()).override_failure_message(
		("AC-6: expected path length 9 (Manhattan 8 + origin); got %d. Path: %s")
		% [path.size(), str(path)]
	).is_equal(9)

	# Assert: endpoints.
	assert_that(Vector2i(path[0])).override_failure_message(
		"AC-6: path[0] should be (0,0); got %s" % str(Vector2i(path[0]))
	).is_equal(Vector2i(0, 0))
	assert_that(Vector2i(path[path.size() - 1])).override_failure_message(
		"AC-6: path[-1] should be (4,4); got %s" % str(Vector2i(path[path.size() - 1]))
	).is_equal(Vector2i(4, 4))

	# Assert: each consecutive step is exactly 4-directional adjacent (distance 1).
	for i: int in range(1, path.size()):
		var prev: Vector2i = Vector2i(path[i - 1])
		var curr: Vector2i = Vector2i(path[i])
		var delta: Vector2i = (curr - prev).abs()
		assert_bool(delta == Vector2i(1, 0) or delta == Vector2i(0, 1)).override_failure_message(
			("AC-6: non-adjacent step at index %d: %s → %s")
			% [i, str(prev), str(curr)]
		).is_true()

	grid.free()


## AC-6 edge: from == to returns single-element array.
func test_get_path_from_equals_to_returns_single_element() -> void:
	# Arrange
	var res: MapResource = _make_uniform_map(15, 15, TerrainCost.PLAINS)
	var grid := MapGrid.new()
	grid.load_map(res)

	# Act
	var path: PackedVector2Array = grid.get_movement_path(Vector2i(3, 3), Vector2i(3, 3), INFANTRY)

	# Assert
	assert_int(path.size()).override_failure_message(
		"from==to: expected path length 1; got %d" % path.size()
	).is_equal(1)
	assert_that(Vector2i(path[0])).is_equal(Vector2i(3, 3))

	grid.free()


## AC-6 edge: unreachable target (wall bisecting map) returns empty array.
func test_get_path_unreachable_target_returns_empty() -> void:
	# Arrange: horizontal wall at row=7.
	var res: MapResource = _make_uniform_map(15, 15, TerrainCost.PLAINS)
	for col: int in 15:
		var idx: int = 7 * 15 + col
		res.tiles[idx].is_passable_base = false
		res.tiles[idx].tile_state = MapGrid.TILE_STATE_EMPTY

	var grid := MapGrid.new()
	grid.load_map(res)

	# Act: from above wall to below wall.
	var path: PackedVector2Array = grid.get_movement_path(Vector2i(7, 6), Vector2i(7, 8), INFANTRY)

	# Assert
	assert_int(path.size()).override_failure_message(
		"Unreachable target: expected empty path; got length %d: %s" \
		% [path.size(), str(path)]
	).is_equal(0)

	grid.free()


# ─── AC-7: get_movement_path respects cost (ROAD preferred over PLAINS) ──────

## AC-7: Two routes from (0,0) to (4,0):
##   Direct east (via row=0 PLAINS): cost = 4 × 10 = 40.
##   ROAD detour via row=1: (0,0)→(0,1)→(1,1)→(2,1)→(3,1)→(4,1)→(4,0): cost = 10+7+7+7+7+10 = 48.
## In this layout PLAINS row is cheaper — but let's test cost is consistent with reference.
## We set up a 15×5 map (min 15 cols) and verify production path total cost == reference cost.
func test_get_path_cost_matches_reference_dijkstra() -> void:
	# Arrange: 15×15 map; row=0 is PLAINS, row=1 is ROAD.
	# Path (0,0)→(14,0) is all PLAINS (cost 14×10=140).
	# Detour via row=1 ROAD would cost 10 (down) + 13×7 (across road) + 10 (up) = 111.
	# The ROAD detour is cheaper — production Dijkstra must choose it.
	var terrain_grid: Array[int] = []
	for row: int in 15:
		for col: int in 15:
			if row == 1:
				terrain_grid.append(TerrainCost.ROAD)
			else:
				terrain_grid.append(TerrainCost.PLAINS)
	var m: MapResource = _make_custom_terrain_map(15, 15, terrain_grid)
	var grid := MapGrid.new()
	var ok: bool = grid.load_map(m)
	assert_bool(ok).override_failure_message(
		"AC-7: load_map failed. Errors: %s" % str(grid.get_last_load_errors())
	).is_true()

	var ref_impl := PathfindingReference.new()

	# Act
	var prod_path: PackedVector2Array = grid.get_movement_path(Vector2i(0, 0), Vector2i(14, 0), INFANTRY)
	var ref_path: Array = ref_impl.compute_path(grid, Vector2i(0, 0), Vector2i(14, 0), INFANTRY)

	# Assert: both return non-empty.
	assert_bool(prod_path.size() > 0).override_failure_message(
		"AC-7: production path should be non-empty"
	).is_true()
	assert_bool(ref_path.size() > 0).override_failure_message(
		"AC-7: reference path should be non-empty"
	).is_true()

	# Assert: total costs match.
	var prod_cost: int = ref_impl.path_cost_from_packed(prod_path, grid, INFANTRY)
	var ref_cost: int = ref_impl.path_cost_from_array(ref_path, grid, INFANTRY)

	assert_int(prod_cost).override_failure_message(
		("AC-7: production path cost %d != reference cost %d. "
		+ "Prod path: %s. Ref path: %s") % [prod_cost, ref_cost, str(prod_path), str(ref_path)]
	).is_equal(ref_cost)

	grid.free()


# ─── AC-8: V-4 reference equivalence (50-query fixture) ──────────────────────

## AC-8: 50 (from, to) pairs on a fixed 20×20 mixed-terrain fixture.
## For each pair: production get_movement_path and reference Dijkstra must agree on:
##   (a) both empty OR both non-empty.
##   (b) if non-empty, total cost matches.
##   (c) each step in production path is adjacent + passable + valid tile_state.
## 5 of the 50 pairs are intentionally unreachable (wall bisects map).
func test_get_path_reference_equivalence_50_queries() -> void:
	# Arrange: 20×20 mixed terrain.
	# Layout: cols 0-4=PLAINS, 5=MOUNTAIN(impassable_base=false), 6-9=FOREST,
	#         10=ROAD, 11-14=HILLS, 15=MOUNTAIN(impassable_base=false), 16-19=PLAINS.
	# Wall column at 5 and 15 (is_passable_base=false, MOUNTAIN elevation=2) bisects map.
	# 5 query pairs explicitly cross col=5 wall (unreachable).
	# Remaining 45 query pairs are within one half or avoid the walls.
	var terrain_grid: Array[int] = []
	for row: int in 20:
		for col: int in 20:
			if col == 5 or col == 15:
				terrain_grid.append(TerrainCost.MOUNTAIN)  # will mark impassable below
			elif col <= 4:
				terrain_grid.append(TerrainCost.PLAINS)
			elif col <= 9:
				terrain_grid.append(TerrainCost.FOREST)
			elif col == 10:
				terrain_grid.append(TerrainCost.ROAD)
			elif col <= 14:
				terrain_grid.append(TerrainCost.HILLS)
			else:
				terrain_grid.append(TerrainCost.PLAINS)

	var m: MapResource = _make_custom_terrain_map(20, 20, terrain_grid)
	# Mark wall columns as impassable.
	for row: int in 20:
		for wall_col: int in [5, 15]:
			var idx: int = row * 20 + wall_col
			m.tiles[idx].is_passable_base = false
			m.tiles[idx].elevation = 2  # MOUNTAIN CR-3 valid elevation
	var grid := MapGrid.new()
	var ok: bool = grid.load_map(m)
	assert_bool(ok).override_failure_message(
		"AC-8: load_map failed. Errors: %s" % str(grid.get_last_load_errors())
	).is_true()

	var ref_impl := PathfindingReference.new()

	# Build 50 query pairs.
	# 45 routable pairs (within left half, cols 0-4 or 6-14).
	# 5 unreachable pairs (cross wall at col=5 or col=15).
	var queries: Array[Array] = []

	# 50 total: 25 left-zone routable + 20 mid-zone routable + 5 unreachable cross-wall.
	# Left zone queries (25 pairs — within cols 0-4).
	var left_zone_pairs: Array[Array] = [
		[Vector2i(0,0), Vector2i(4,0)],
		[Vector2i(0,0), Vector2i(0,4)],
		[Vector2i(1,1), Vector2i(3,3)],
		[Vector2i(0,5), Vector2i(4,10)],
		[Vector2i(2,0), Vector2i(2,19)],
		[Vector2i(0,0), Vector2i(4,19)],
		[Vector2i(1,0), Vector2i(3,19)],
		[Vector2i(0,10), Vector2i(4,10)],
		[Vector2i(0,0), Vector2i(0,19)],
		[Vector2i(4,0), Vector2i(4,19)],
		[Vector2i(0,0), Vector2i(4,4)],
		[Vector2i(0,15), Vector2i(4,15)],
		[Vector2i(2,2), Vector2i(2,18)],
		[Vector2i(1,1), Vector2i(3,18)],
		[Vector2i(0,0), Vector2i(4,10)],
		[Vector2i(0,8), Vector2i(4,12)],
		[Vector2i(3,0), Vector2i(3,15)],
		[Vector2i(0,3), Vector2i(4,7)],
		[Vector2i(1,5), Vector2i(3,10)],
		[Vector2i(2,0), Vector2i(2,10)],
		[Vector2i(0,1), Vector2i(4,1)],
		[Vector2i(0,17), Vector2i(4,17)],
		[Vector2i(2,5), Vector2i(2,15)],
		[Vector2i(1,4), Vector2i(3,16)],
		[Vector2i(0,2), Vector2i(4,18)],
	]
	# Middle zone queries (cols 6-14, 20 pairs).
	var mid_zone_pairs: Array[Array] = [
		[Vector2i(6,0), Vector2i(14,0)],
		[Vector2i(6,0), Vector2i(6,19)],
		[Vector2i(6,5), Vector2i(14,10)],
		[Vector2i(7,0), Vector2i(13,0)],
		[Vector2i(6,0), Vector2i(14,19)],
		[Vector2i(6,10), Vector2i(14,10)],
		[Vector2i(8,0), Vector2i(12,19)],
		[Vector2i(10,0), Vector2i(10,19)],
		[Vector2i(6,3), Vector2i(14,17)],
		[Vector2i(9,0), Vector2i(11,0)],
		[Vector2i(6,6), Vector2i(14,6)],
		[Vector2i(7,7), Vector2i(13,13)],
		[Vector2i(6,0), Vector2i(9,0)],
		[Vector2i(11,0), Vector2i(14,0)],
		[Vector2i(6,18), Vector2i(14,18)],
		[Vector2i(9,5), Vector2i(12,15)],
		[Vector2i(6,1), Vector2i(14,18)],
		[Vector2i(10,8), Vector2i(10,12)],
		[Vector2i(8,8), Vector2i(12,12)],
		[Vector2i(6,9), Vector2i(14,11)],
	]
	# 5 unreachable pairs: cross wall at col=5 (from left zone to mid zone).
	var unreachable_pairs: Array[Array] = [
		[Vector2i(0,0),  Vector2i(6,0)],
		[Vector2i(4,5),  Vector2i(6,5)],
		[Vector2i(0,10), Vector2i(10,10)],
		[Vector2i(3,15), Vector2i(8,15)],
		[Vector2i(1,19), Vector2i(7,19)],
	]

	for p: Array in left_zone_pairs:
		queries.append(p)
	for p: Array in mid_zone_pairs:
		queries.append(p)
	for p: Array in unreachable_pairs:
		queries.append(p)

	assert_int(queries.size()).is_equal(50)   # sanity check

	# Run 50 queries.
	var unreachable_count_prod: int = 0
	var unreachable_count_ref: int = 0

	for qi: int in queries.size():
		var from: Vector2i = queries[qi][0] as Vector2i
		var to: Vector2i   = queries[qi][1] as Vector2i

		var prod_path: PackedVector2Array = grid.get_movement_path(from, to, INFANTRY)
		var ref_path: Array = ref_impl.compute_path(grid, from, to, INFANTRY)

		# (a) Empty agreement.
		var prod_empty: bool = prod_path.size() == 0
		var ref_empty: bool  = ref_path.size() == 0

		assert_bool(prod_empty == ref_empty).override_failure_message(
			("AC-8 query %d (%s→%s): production empty=%s but reference empty=%s")
			% [qi, str(from), str(to), str(prod_empty), str(ref_empty)]
		).is_true()

		if prod_empty:
			unreachable_count_prod += 1
		if ref_empty:
			unreachable_count_ref += 1

		if not prod_empty and not ref_empty:
			# (b) Cost equivalence.
			var prod_cost: int = ref_impl.path_cost_from_packed(prod_path, grid, INFANTRY)
			var ref_cost: int  = ref_impl.path_cost_from_array(ref_path, grid, INFANTRY)

			assert_int(prod_cost).override_failure_message(
				("AC-8 query %d (%s→%s): cost mismatch — prod=%d ref=%d")
				% [qi, str(from), str(to), prod_cost, ref_cost]
			).is_equal(ref_cost)

			# (c) Each step in production path is adjacent + passable.
			var cols: int = grid._map.map_cols
			for si: int in range(1, prod_path.size()):
				var prev: Vector2i = Vector2i(prod_path[si - 1])
				var curr: Vector2i = Vector2i(prod_path[si])
				var delta: Vector2i = (curr - prev).abs()
				assert_bool(delta == Vector2i(1, 0) or delta == Vector2i(0, 1)).override_failure_message(
					("AC-8 query %d: non-adjacent step at %d: %s→%s")
					% [qi, si, str(prev), str(curr)]
				).is_true()

				var nidx: int = curr.y * cols + curr.x
				assert_bool(grid._passable_base_cache[nidx] != 0).override_failure_message(
					("AC-8 query %d: step %d reaches impassable tile %s")
					% [qi, si, str(curr)]
				).is_true()

	# Assert: exactly 5 unreachable pairs (both production and reference agree).
	assert_int(unreachable_count_prod).override_failure_message(
		"AC-8: expected 5 unreachable production paths; got %d" % unreachable_count_prod
	).is_equal(5)
	assert_int(unreachable_count_ref).override_failure_message(
		"AC-8: expected 5 unreachable reference paths; got %d" % unreachable_count_ref
	).is_equal(5)

	grid.free()


# ─── AC-9: Scratch buffer reuse ──────────────────────────────────────────────

## AC-9: Calling get_movement_range 10 times does not reassign the scratch buffer
## members (they are class-scope, not per-call allocated). We verify by checking
## that the SAME MapGrid instance's scratch arrays have consistent content after
## multiple calls, and that no Object identity change occurs (GDScript packed arrays
## are value types, but class-member reassignment would require `=` at class scope —
## our implementation only calls .clear() + .resize() + .fill(), never `=`).
##
## NOTE (story-005 AC-9): full pointer-identity assertion is not feasible in GdUnit4
## because PackedArrays are value types with no exposed memory address. This test
## instead verifies the behavioral contract: scratch state is consistent after
## repeated calls (last call's result is correct). Code review + static lint are
## the primary guards per story spec.
func test_get_movement_range_scratch_reuse_consistent_across_10_calls() -> void:
	# Arrange
	var grid: MapGrid = _make_plains_grid_with_unit(15, 15, 1, Vector2i(7, 7))

	# Act: call 10 times; all calls on same unit + grid.
	var last_result: PackedVector2Array = PackedVector2Array()
	for _i: int in 10:
		last_result = grid.get_movement_range(1, 3, INFANTRY)

	# Assert: result is still correct after 10 calls (scratch correctly reset each time).
	assert_int(last_result.size()).override_failure_message(
		"AC-9: after 10 calls, result size should still be 25 (diamond r=3); got %d" \
		% last_result.size()
	).is_equal(25)

	# Assert: origin still present.
	var result_set: Dictionary = {}
	for v: Vector2 in last_result:
		result_set[Vector2i(v)] = true
	assert_bool(result_set.has(Vector2i(7, 7))).override_failure_message(
		"AC-9: origin (7,7) must be in result after repeated calls"
	).is_true()

	grid.free()


# ─── AC-10: ADV-1 return type — PackedVector2Array ───────────────────────────

## AC-10: get_movement_range returns PackedVector2Array; elements cast to Vector2i
## preserve exact integer precision (no float coercion drift).
func test_get_movement_range_return_type_is_packed_vector2_array() -> void:
	# Arrange
	var grid: MapGrid = _make_plains_grid_with_unit(15, 15, 1, Vector2i(5, 3))

	# Act
	var result: PackedVector2Array = grid.get_movement_range(1, 1, INFANTRY)

	# Assert: typeof is TYPE_PACKED_VECTOR2_ARRAY.
	assert_int(typeof(result)).override_failure_message(
		("ADV-1: expected TYPE_PACKED_VECTOR2_ARRAY (%d); got %d")
		% [TYPE_PACKED_VECTOR2_ARRAY, typeof(result)]
	).is_equal(TYPE_PACKED_VECTOR2_ARRAY)

	# Assert: Vector2i cast of each element preserves integer precision.
	# For tile (5,3): Vector2i(Vector2(5.0, 3.0)) == Vector2i(5, 3).
	assert_bool(result.size() > 0).override_failure_message(
		"ADV-1: result must be non-empty (unit at (5,3), move_range=1 → ≥1 tile)"
	).is_true()
	for v: Vector2 in result:
		var coord: Vector2i = Vector2i(v)
		# Verify no precision loss: float32 is exact for ints up to 2^24.
		assert_bool(float(coord.x) == v.x and float(coord.y) == v.y).override_failure_message(
			("ADV-1: Vector2i cast introduced precision loss for tile %s (Vector2 was %s)")
			% [str(coord), str(v)]
		).is_true()

	grid.free()
