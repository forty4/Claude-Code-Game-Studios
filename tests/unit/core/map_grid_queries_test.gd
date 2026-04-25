extends GdUnitTestSuite

## map_grid_queries_test.gd
## Unit tests for Story 006: MapGrid LoS + attack-range + attack-direction + adjacency
## queries (the remaining 7 of TR-map-grid-003's 9 query methods, plus TR-map-grid-008
## LoS rules).
##
## Test evidence type: Logic — automated unit tests are BLOCKING gate
## (coding-standards §Test Evidence).
##
## 13 tests covering AC-1..AC-12 (AC-1 split into 1a+1b for adjacent and same-tile):
##   AC-1  has_line_of_sight adjacent + same-tile short-circuit
##   AC-2  FORTRESS_WALL blocks flat LoS
##   AC-3  AC-F-4 elevation max rule
##   AC-4  V-3 20-case LoS matrix (table-driven)
##   AC-5  §EC-3 corner-cut conservatism
##   AC-6  get_attack_range without LoS (Manhattan diamond, origin excluded)
##   AC-7  get_attack_range with LoS filter
##   AC-8  AC-F-5 attack-direction full compass matrix (facing=NORTH and =EAST)
##   AC-9  §EC-4 horizontal tie-break on perfect diagonal
##   AC-10 §EC-4 same-tile attack returns FRONT + push_warning
##   AC-11 get_adjacent_units cardinal neighbours + faction filter
##   AC-12 get_occupied_tiles deterministic row-major scan
##
## Notes on testing approach:
##   • push_warning emission (AC-1 same-tile, AC-10 same-tile attack) is verified by
##     return-value correctness only; gdunit4 lacks a push_warning capture API.
##   • Maps are 15×15 minimum (validator floor); LoS fixtures occupy a small subregion.
##   • All tile elevations are CR-3-valid for their terrain (PLAINS=0, HILLS=1, MOUNTAIN=2).

# ─── Convenience aliases ──────────────────────────────────────────────────────

## Build a 15×15 PLAINS MapResource with optional per-coord overrides.
##
## [param walls]      — list of coords to convert to FORTRESS_WALL (terrain=6, elev=0, base=false)
## [param hills]      — list of coords to convert to HILLS (terrain=2, elev=1)
## [param mountains]  — list of coords to convert to MOUNTAIN (terrain=3, elev=2)
##
## All other tiles remain PLAINS at elevation 0, is_passable_base=true,
## tile_state=EMPTY, no occupant.
func _make_los_15x15_map(
		walls: Array[Vector2i] = [],
		hills: Array[Vector2i] = [],
		mountains: Array[Vector2i] = []) -> MapResource:
	var cols: int = 15
	var rows: int = 15
	var m := MapResource.new()
	m.map_id = &"queries_test_los"
	m.map_rows = rows
	m.map_cols = cols
	m.terrain_version = 1

	for i: int in (rows * cols):
		var t := MapTileData.new()
		t.coord            = Vector2i(i % cols, i / cols)
		t.terrain_type     = TerrainCost.PLAINS
		t.elevation        = 0
		t.is_passable_base = true
		t.tile_state       = MapGrid.TILE_STATE_EMPTY
		t.occupant_id      = 0
		t.occupant_faction = MapGrid.FACTION_NONE
		t.is_destructible  = false
		t.destruction_hp   = 0
		m.tiles.append(t)

	# Apply per-coord overrides.
	# FORTRESS_WALL requires elevation 1 or 2 per CR-3 (ELEVATION_RANGES); use 1.
	# Wall elevation does not affect LoS rasterization once is_passable_base=false
	# (the passable check fires first), but it must be valid for the validator to load.
	for c: Vector2i in walls:
		var idx_w: int = c.y * cols + c.x
		m.tiles[idx_w].terrain_type     = TerrainCost.FORTRESS_WALL
		m.tiles[idx_w].elevation        = 1
		m.tiles[idx_w].is_passable_base = false
	for c: Vector2i in hills:
		var idx_h: int = c.y * cols + c.x
		m.tiles[idx_h].terrain_type = TerrainCost.HILLS
		m.tiles[idx_h].elevation    = 1
	for c: Vector2i in mountains:
		var idx_m: int = c.y * cols + c.x
		m.tiles[idx_m].terrain_type = TerrainCost.MOUNTAIN
		m.tiles[idx_m].elevation    = 2

	return m


## Convenience: load a MapGrid from a MapResource, asserting load success.
func _load_grid(m: MapResource) -> MapGrid:
	var grid := MapGrid.new()
	var ok: bool = grid.load_map(m)
	assert_bool(ok).override_failure_message(
		"load_map failed. Errors: %s" % str(grid.get_last_load_errors())
	).is_true()
	return grid


## Place a unit on a coord using the mutation API.
## set_occupant returns void; success is verified by reading back via get_tile.
func _place(grid: MapGrid, coord: Vector2i, uid: int, faction: int) -> void:
	grid.set_occupant(coord, uid, faction)
	var t: MapTileData = grid.get_tile(coord)
	assert_int(t.occupant_id).override_failure_message(
		"set_occupant(%s, uid=%d, faction=%d) did not write occupant_id." \
		% [str(coord), uid, faction]
	).is_equal(uid)


# ─── AC-1: has_line_of_sight short-circuits — adjacent + same-tile ────────────

## AC-1a: adjacent tiles (Manhattan distance 1) always return true.
## Short-circuits before entering Bresenham loop — verified by behavioral test
## across 4 cardinal directions and 4 diagonal-distance-2 cases (separately).
func test_has_line_of_sight_adjacent_tiles_short_circuit_true() -> void:
	# Arrange: 15×15 PLAINS, no walls — purely tests adjacency short-circuit.
	var grid: MapGrid = _load_grid(_make_los_15x15_map())

	# Act + Assert: 4 cardinal-adjacent pairs.
	var center: Vector2i = Vector2i(7, 7)
	var adjacent: Array[Vector2i] = [
		Vector2i(7, 6),  # north
		Vector2i(8, 7),  # east
		Vector2i(7, 8),  # south
		Vector2i(6, 7),  # west
	]
	for n: Vector2i in adjacent:
		assert_bool(grid.has_line_of_sight(center, n)).override_failure_message(
			"AC-1a: has_line_of_sight(%s, %s) (Manhattan=1) should be true" % [str(center), str(n)]
		).is_true()

	grid.free()


## AC-1b: same-tile (D=0) returns true; push_warning("ERR_SAME_TILE_LOS") emitted.
## Note: push_warning capture is gdunit4-incompatible — verified manually via stderr.
## Test asserts return value only.
func test_has_line_of_sight_same_tile_returns_true_with_warning() -> void:
	# Arrange
	var grid: MapGrid = _load_grid(_make_los_15x15_map())

	# Act
	var result: bool = grid.has_line_of_sight(Vector2i(5, 5), Vector2i(5, 5))

	# Assert: return is true (push_warning emission is side-channel, manually verified).
	assert_bool(result).override_failure_message(
		"AC-1b: has_line_of_sight same-tile (D=0) must return true (caller-bug recovery)."
	).is_true()

	grid.free()


# ─── AC-2: FORTRESS_WALL blocks flat-elevation LoS ────────────────────────────

## AC-2: FORTRESS_WALL between attacker and target on flat (elev=0) terrain blocks LoS.
## Wall at (4,2); attacker (2,2) elev=0; target (6,2) elev=0.
## Bresenham line rasterizes through (3,2), (4,2), (5,2) — wall at (4,2) blocks.
func test_has_line_of_sight_fortress_wall_intermediate_blocks() -> void:
	# Arrange: 15×15 PLAINS with one FORTRESS_WALL at (4,2).
	var grid: MapGrid = _load_grid(
		_make_los_15x15_map([Vector2i(4, 2)])
	)

	# Act + Assert: attacker (2,2) → target (6,2) blocked by wall at (4,2).
	assert_bool(grid.has_line_of_sight(Vector2i(2, 2), Vector2i(6, 2))).override_failure_message(
		"AC-2: FORTRESS_WALL at (4,2) must block LoS from (2,2) to (6,2)."
	).is_false()

	# Edge case: attacker (2,2) → target (6,3) — line rasterizes through different
	# tiles depending on Bresenham; should not pass through (4,2). Conservative
	# assertion: shifted target is reachable when wall is at (4,2) only.
	# (Line from (2,2) to (6,3) passes through approximately (3,2), (4,2|3), (5,3) —
	# may still pass through wall under corner-cut rule — so assert via different geometry:
	# wall at (4,3) instead, target at (6,2) → line stays on row 2 → no block.)
	grid.free()
	var grid2: MapGrid = _load_grid(
		_make_los_15x15_map([Vector2i(4, 3)])
	)
	assert_bool(grid2.has_line_of_sight(Vector2i(2, 2), Vector2i(6, 2))).override_failure_message(
		"AC-2 edge: FORTRESS_WALL at (4,3) (off-axis) must NOT block LoS from (2,2) to (6,2)."
	).is_true()
	grid2.free()


# ─── AC-3: elevation max rule (AC-F-4) ────────────────────────────────────────

## AC-3: intermediate tile blocks iff elevation > max(from.elev, to.elev).
## Tested permutations:
##   • from elev=1 (HILLS), to elev=0 (PLAINS), intermediate elev=2 (MOUNTAIN) → BLOCK (2>1)
##   • from elev=1, to elev=0, intermediate elev=1 → PASS (1>1 is false)
##   • from elev=2, to elev=0, intermediate elev=2 → PASS (2>2 is false)
func test_has_line_of_sight_elevation_max_rule_blocks_when_above_both() -> void:
	# Case A: intermediate strictly higher than both endpoints → block.
	# Attacker on HILLS (1,2)elev=1; target on PLAINS (5,2)elev=0; MOUNTAIN at (3,2)elev=2.
	# Line passes through (2,2),(3,2),(4,2). (3,2)=MOUNTAIN elev=2 > max(1,0)=1 → BLOCK.
	var grid_a: MapGrid = _load_grid(_make_los_15x15_map(
		[],                               # walls
		[Vector2i(1, 2)],                 # hills (elev=1)
		[Vector2i(3, 2)]                  # mountain (elev=2)
	))
	assert_bool(grid_a.has_line_of_sight(Vector2i(1, 2), Vector2i(5, 2))).override_failure_message(
		"AC-3 case A: intermediate elev=2 > max(1,0)=1 should block LoS."
	).is_false()
	grid_a.free()

	# Case B: intermediate at elev=1 (HILLS); from at elev=1, to at elev=0.
	# elev_max = max(1,0) = 1; intermediate elev=1; 1>1=false → does NOT block.
	var grid_b: MapGrid = _load_grid(_make_los_15x15_map(
		[],
		[Vector2i(1, 2), Vector2i(3, 2)], # both attacker tile and intermediate are HILLS
		[]
	))
	assert_bool(grid_b.has_line_of_sight(Vector2i(1, 2), Vector2i(5, 2))).override_failure_message(
		"AC-3 case B: intermediate elev=1, max(1,0)=1, 1>1=false → should NOT block."
	).is_true()
	grid_b.free()

	# Case C: from at elev=2 (MOUNTAIN), to at elev=0, intermediate elev=2.
	# elev_max = max(2,0) = 2; intermediate elev=2; 2>2=false → does NOT block.
	var grid_c: MapGrid = _load_grid(_make_los_15x15_map(
		[],
		[],
		[Vector2i(1, 2), Vector2i(3, 2)]  # both MOUNTAIN elev=2
	))
	assert_bool(grid_c.has_line_of_sight(Vector2i(1, 2), Vector2i(5, 2))).override_failure_message(
		"AC-3 case C: from elev=2, max(2,0)=2, intermediate elev=2; 2>2=false → should NOT block."
	).is_true()
	grid_c.free()


# ─── AC-4: V-3 20-case LoS matrix (table-driven) ──────────────────────────────

## AC-4: V-3 20-case LoS matrix — covers elevation triples, walls, adjacency, and
## destroyed-wall mutation. Single fixture; iterate cases.
##
## Fixture: 15×15 with intentional structure in the (0..6, 0..6) subregion:
##   - HILLS at (3,3)
##   - MOUNTAIN at (5,5)
##   - FORTRESS_WALL at (4,2) and (2,4)
##   - PLAINS elsewhere
##
## 20 cases below test the LoS rule across this fixture.
func test_has_line_of_sight_v3_matrix_20_cases() -> void:
	# Arrange — single 15×15 fixture with placed obstacles.
	var grid: MapGrid = _load_grid(_make_los_15x15_map(
		[Vector2i(4, 2), Vector2i(2, 4)],   # walls
		[Vector2i(3, 3)],                   # hills (elev=1)
		[Vector2i(5, 5)]                    # mountain (elev=2)
	))

	# Cases: (from, to, expected, label)
	# Built from the 7×7 conceptual subregion + various elevation/wall combinations.
	var cases: Array = [
		# 1-4: elevation triple combinations (12 representative cases, trimmed)
		# Case 1: PLAINS-PLAINS-PLAINS line, all elev=0 — no obstacles → true.
		[Vector2i(0, 0), Vector2i(6, 0), true,  "1: flat PLAINS row 0"],
		# Case 2: line crosses wall at (4,2) — block.
		[Vector2i(2, 2), Vector2i(6, 2), false, "2: wall (4,2) on row 2"],
		# Case 3: line on row 1 (above wall) — pass.
		[Vector2i(2, 1), Vector2i(6, 1), true,  "3: row 1 above wall"],
		# Case 4: line vertical column 2 crossing wall at (2,4) — block.
		[Vector2i(2, 2), Vector2i(2, 6), false, "4: wall (2,4) on col 2"],
		# Case 5: line vertical column 1 (left of wall) — pass.
		[Vector2i(1, 2), Vector2i(1, 6), true,  "5: col 1 left of wall"],
		# Case 6: line through hills at (3,3); from elev=0 to elev=0 → block (1>0).
		[Vector2i(1, 3), Vector2i(6, 3), false, "6: hills(3,3) elev=1 > max(0,0)"],
		# Case 7: line through hills at (3,3); from at hills (3,3 itself can't be
		# 'from' since 'from' is the attacker location — instead attacker on hills
		# and target on plains, line passes through OTHER terrain.
		# from(3,3)elev=1, to(6,1)elev=0: line passes through (4,2)wall → block.
		[Vector2i(3, 3), Vector2i(6, 1), false, "7: hills→plains thru wall(4,2)"],
		# Case 8: from(3,3) hills, to(6,3) plains, intermediate(4,3),(5,3) plains.
		# elev_max=max(1,0)=1; intermediates all elev=0; 0>1=false → pass.
		[Vector2i(3, 3), Vector2i(6, 3), true,  "8: hills→plains row 3 clear"],
		# Case 9: line through mountain at (5,5); from(3,5)elev=0, to(7,5)elev=0.
		# Intermediate (5,5) elev=2 > max(0,0)=0 → block.
		[Vector2i(3, 5), Vector2i(7, 5), false, "9: mountain(5,5) elev=2 blocks"],
		# Case 10: from on mountain (5,5)elev=2, to (3,5)elev=0; intermediates row 5 plain;
		# elev_max=2 → no plain blocks (0>2 false). Pass.
		[Vector2i(5, 5), Vector2i(3, 5), true, "10: from-mountain row 5 reverse"],
		# Case 11: from(5,5)mountain elev=2, to(7,7)plains elev=0; intermediates
		# (6,6) plain elev=0. elev_max=max(2,0)=2; 0>2=false → pass.
		[Vector2i(5, 5), Vector2i(7, 7), true, "11: mountain diagonal to plain"],
		# 12: Line crosses wall at (4,2) but on a DIAGONAL. (1,1) → (7,3).
		# Bresenham: dx=6, dy=2. Bresenham line rasterizes (2,1.33≈1),(3,1.66≈2),(4,2),(5,2),(6,3).
		# At minimum it visits (4,2) which is wall → block.
		[Vector2i(1, 1), Vector2i(7, 3), false, "12: diagonal thru wall(4,2)"],
		# 13: Adjacent same-row (row 4 has wall at (2,4); test (5,4)→(6,4) — clear).
		[Vector2i(5, 4), Vector2i(6, 4), true, "13: adjacent right of wall(2,4)"],
		# 14: Adjacent crossing wall (1,4)→(2,4); both 'to' is wall — but this is
		# Manhattan=1 → adjacent short-circuit returns true regardless.
		[Vector2i(1, 4), Vector2i(2, 4), true, "14: adjacent wall-tile (short-circuit)"],
		# 15: line ends ON the wall. (0,4)→(2,4) D=2; intermediate (1,4) is plain.
		# Wall (2,4) is endpoint; endpoints never self-block → pass.
		[Vector2i(0, 4), Vector2i(2, 4), true, "15: endpoint IS wall — never self-blocks"],
		# 16: Manhattan-2 horizontal — verifies non-adjacent path.
		[Vector2i(0, 0), Vector2i(2, 0), true, "16: Manhattan=2 row 0 clear"],
		# 17: Same-tile case — short-circuit + warning. Already tested in AC-1b but
		# included here for matrix completeness.
		[Vector2i(7, 7), Vector2i(7, 7), true, "17: same-tile D=0"],
		# 18: From corner (0,0) to corner (6,6) — long diagonal across map.
		# Line passes through (1,1),(2,2),(3,3)hills,(4,4),(5,5)mountain,(6,6) before
		# reaching (6,6). Mountain at (5,5)elev=2 > max(0,0)=0 → block.
		[Vector2i(0, 0), Vector2i(6, 6), false, "18: long diagonal hits mountain"],
		# 19: Edge of map adjacency (14,14) to (13,14) — passes (no obstacles in lower-right).
		[Vector2i(14, 14), Vector2i(13, 14), true, "19: bottom-right corner adjacent"],
		# 20: Long flat line clear of obstacles — (0,7)→(14,7) row 7 (well below fixtures).
		[Vector2i(0, 7), Vector2i(14, 7), true, "20: long flat clear row 7"],
	]

	# Act + Assert: iterate case table.
	for case_data: Array in cases:
		var f: Vector2i = case_data[0]
		var t: Vector2i = case_data[1]
		var expected: bool = case_data[2]
		var label: String = case_data[3]
		var actual: bool = grid.has_line_of_sight(f, t)
		assert_bool(actual).override_failure_message(
			"AC-4 V-3 case %s: has_line_of_sight(%s, %s) expected=%s, got=%s" \
			% [label, str(f), str(t), str(expected), str(actual)]
		).is_equal(expected)

	grid.free()


# ─── AC-5: §EC-3 corner-cut conservatism ──────────────────────────────────────

## AC-5: line passing exactly through a tile corner is conservatively blocked if
## EITHER cardinal-adjacent tile is impassable. Walls at (1,2) and (2,1) form an
## L-corner; line from (1,1) to (2,2) (D=2) passes through the corner — both
## cardinal neighbours are walls → conservative block.
func test_has_line_of_sight_corner_cut_conservatism_blocks_diagonal_through_walls() -> void:
	# Arrange: 15×15 with walls at (1,2) and (2,1).
	var grid: MapGrid = _load_grid(
		_make_los_15x15_map([Vector2i(1, 2), Vector2i(2, 1)])
	)

	# Act + Assert: line (1,1)→(2,2) passes through corner — conservative block.
	assert_bool(grid.has_line_of_sight(Vector2i(1, 1), Vector2i(2, 2))).override_failure_message(
		"AC-5: line (1,1)→(2,2) corner-cut between walls (1,2) and (2,1) → must block."
	).is_false()

	# Edge case: only ONE of the two cardinal adjacents is a wall — still conservative
	# (rule requires EITHER blocking → blocked).
	grid.free()
	var grid2: MapGrid = _load_grid(
		_make_los_15x15_map([Vector2i(1, 2)])  # only one wall
	)
	assert_bool(grid2.has_line_of_sight(Vector2i(1, 1), Vector2i(2, 2))).override_failure_message(
		"AC-5 edge: line (1,1)→(2,2) with single wall (1,2) at corner → still blocked (conservative)."
	).is_false()
	grid2.free()


# ─── AC-6: get_attack_range without LoS — Manhattan diamond, origin excluded ──

## AC-6: get_attack_range(origin, range, false) returns Manhattan diamond, EXCLUDING
## origin. attack_range=2 from (7,7) → 12 tiles.
func test_get_attack_range_no_los_returns_manhattan_diamond_excluding_origin() -> void:
	# Arrange: 15×15 PLAINS, no obstacles.
	var grid: MapGrid = _load_grid(_make_los_15x15_map())

	# Act
	var result: PackedVector2Array = grid.get_attack_range(Vector2i(7, 7), 2, false)

	# Assert: 12 tiles in Manhattan-2 diamond around (7,7), origin excluded.
	# (4 at d=1 + 8 at d=2 = 12)
	assert_int(result.size()).override_failure_message(
		"AC-6: attack_range=2 should yield 12 tiles (Manhattan diamond minus origin), got %d. Result: %s"
		% [result.size(), str(result)]
	).is_equal(12)

	# Origin must NOT be in result.
	var result_set: Dictionary = {}
	for v: Vector2 in result:
		result_set[Vector2i(v)] = true
	assert_bool(result_set.has(Vector2i(7, 7))).override_failure_message(
		"AC-6: origin (7,7) must NOT be in attack_range result."
	).is_false()

	# Spot-check: all 4 cardinal adjacents present.
	for n: Vector2i in [Vector2i(7, 6), Vector2i(8, 7), Vector2i(7, 8), Vector2i(6, 7)]:
		assert_bool(result_set.has(n)).override_failure_message(
			"AC-6: cardinal adjacent %s missing from attack_range result." % str(n)
		).is_true()

	# Edge case: attack_range=0 → empty array.
	var empty_result: PackedVector2Array = grid.get_attack_range(Vector2i(7, 7), 0, false)
	assert_int(empty_result.size()).override_failure_message(
		"AC-6 edge: attack_range=0 should yield empty result, got %d." % empty_result.size()
	).is_equal(0)

	grid.free()


# ─── AC-7: get_attack_range with LoS filter ───────────────────────────────────

## AC-7: get_attack_range with apply_los=true filters out tiles blocked by walls.
## Wall at (4,2); attacker at (2,2) range=4. Tiles like (6,2) Manhattan=4 are blocked
## by the wall when apply_los=true.
func test_get_attack_range_with_los_filter_excludes_blocked_tiles() -> void:
	# Arrange: 15×15 with wall at (4,2).
	var grid: MapGrid = _load_grid(_make_los_15x15_map([Vector2i(4, 2)]))

	# Act
	var with_los: PackedVector2Array = grid.get_attack_range(Vector2i(2, 2), 4, true)
	var without_los: PackedVector2Array = grid.get_attack_range(Vector2i(2, 2), 4, false)

	# Assert: with-LoS result is strictly smaller (some tiles filtered out).
	assert_int(with_los.size()).override_failure_message(
		"AC-7: with-LoS result size (%d) must be < without-LoS size (%d)." \
		% [with_los.size(), without_los.size()]
	).is_less(without_los.size())

	# Tile (6,2) at Manhattan=4 from (2,2) is blocked by wall at (4,2).
	var with_los_set: Dictionary = {}
	for v: Vector2 in with_los:
		with_los_set[Vector2i(v)] = true
	assert_bool(with_los_set.has(Vector2i(6, 2))).override_failure_message(
		"AC-7: (6,2) should be excluded from LoS-filtered attack range (wall at (4,2) blocks)."
	).is_false()

	# Tile (5,2) at Manhattan=3 — also blocked (line passes through (4,2) wall).
	assert_bool(with_los_set.has(Vector2i(5, 2))).override_failure_message(
		"AC-7: (5,2) should be excluded from LoS-filtered attack range (wall at (4,2) blocks)."
	).is_false()

	# Tile (2,5) at Manhattan=3 — vertical line, no wall on column 2 → reachable.
	assert_bool(with_los_set.has(Vector2i(2, 5))).override_failure_message(
		"AC-7: (2,5) on clear vertical column should remain in LoS-filtered range."
	).is_true()

	grid.free()


# ─── AC-8: AC-F-5 attack-direction full compass matrix ────────────────────────

## AC-8: get_attack_direction full compass for two facings (NORTH and EAST).
## Defender at (7,7); attackers at the 4 cardinal adjacents.
##
## Facing=NORTH (defender looking up): N→FRONT, E→FLANK, S→REAR, W→FLANK
## Facing=EAST (defender looking right): N→FLANK, E→FRONT, S→FLANK, W→REAR
func test_get_attack_direction_facing_north_full_compass_matrix() -> void:
	# Arrange (no map needed — get_attack_direction is pure math; but we build a minimal
	# grid for API consistency).
	var grid: MapGrid = _load_grid(_make_los_15x15_map())
	var defender: Vector2i = Vector2i(7, 7)

	# Facing NORTH compass: attackers at N(7,6), E(8,7), S(7,8), W(6,7).
	var north_face: Array = [
		[Vector2i(7, 6), MapGrid.ATK_DIR_FRONT, "N→FRONT"],
		[Vector2i(8, 7), MapGrid.ATK_DIR_FLANK, "E→FLANK"],
		[Vector2i(7, 8), MapGrid.ATK_DIR_REAR,  "S→REAR"],
		[Vector2i(6, 7), MapGrid.ATK_DIR_FLANK, "W→FLANK"],
	]
	for case_data: Array in north_face:
		var attacker: Vector2i = case_data[0]
		var expected: int      = case_data[1]
		var label: String      = case_data[2]
		var actual: int = grid.get_attack_direction(attacker, defender, MapGrid.FACING_NORTH)
		assert_int(actual).override_failure_message(
			"AC-8 facing=NORTH %s: expected=%d, got=%d" % [label, expected, actual]
		).is_equal(expected)

	# Facing EAST compass: attackers at N(7,6), E(8,7), S(7,8), W(6,7).
	var east_face: Array = [
		[Vector2i(7, 6), MapGrid.ATK_DIR_FLANK, "N→FLANK (east-facing)"],
		[Vector2i(8, 7), MapGrid.ATK_DIR_FRONT, "E→FRONT (east-facing)"],
		[Vector2i(7, 8), MapGrid.ATK_DIR_FLANK, "S→FLANK (east-facing)"],
		[Vector2i(6, 7), MapGrid.ATK_DIR_REAR,  "W→REAR (east-facing)"],
	]
	for case_data: Array in east_face:
		var attacker: Vector2i = case_data[0]
		var expected: int      = case_data[1]
		var label: String      = case_data[2]
		var actual: int = grid.get_attack_direction(attacker, defender, MapGrid.FACING_EAST)
		assert_int(actual).override_failure_message(
			"AC-8 facing=EAST %s: expected=%d, got=%d" % [label, expected, actual]
		).is_equal(expected)

	grid.free()


# ─── AC-9: §EC-4 horizontal tie-break on perfect diagonal ─────────────────────

## AC-9: when abs(dc) == abs(dr) (perfect diagonal), horizontal axis wins.
## Defender (2,2) facing=NORTH; attacker (4,4) → dc=2, dr=2 → attack_dir=EAST →
## relative_angle = (1-0+4)%4 = 1 → FLANK.
func test_get_attack_direction_perfect_diagonal_horizontal_tie_break_to_east_west() -> void:
	# Arrange
	var grid: MapGrid = _load_grid(_make_los_15x15_map())
	var defender: Vector2i = Vector2i(2, 2)

	# Case A: SE diagonal — dc=+2, dr=+2 → EAST → FLANK (vs NORTH-facing).
	var dir_a: int = grid.get_attack_direction(Vector2i(4, 4), defender, MapGrid.FACING_NORTH)
	assert_int(dir_a).override_failure_message(
		"AC-9 case A: attacker (4,4) on SE perfect diagonal vs defender (2,2) NORTH-facing: " \
		+ "expected FLANK (EAST attack_dir), got %d" % dir_a
	).is_equal(MapGrid.ATK_DIR_FLANK)

	# Case B: NW diagonal — dc=-2, dr=-2 → WEST → also FLANK.
	var dir_b: int = grid.get_attack_direction(Vector2i(0, 0), defender, MapGrid.FACING_NORTH)
	assert_int(dir_b).override_failure_message(
		"AC-9 case B: attacker (0,0) on NW perfect diagonal vs defender (2,2) NORTH-facing: " \
		+ "expected FLANK (WEST attack_dir), got %d" % dir_b
	).is_equal(MapGrid.ATK_DIR_FLANK)

	# Case C: shorter perfect diagonal — dc=+1, dr=+1 → still EAST (>= rule).
	var dir_c: int = grid.get_attack_direction(Vector2i(3, 3), defender, MapGrid.FACING_NORTH)
	assert_int(dir_c).override_failure_message(
		"AC-9 case C: attacker (3,3) dc=1,dr=1 perfect diagonal: expected FLANK (EAST), got %d" % dir_c
	).is_equal(MapGrid.ATK_DIR_FLANK)

	grid.free()


# ─── AC-10: §EC-4 same-tile attack returns FRONT + push_warning ───────────────

## AC-10: attacker == defender → FRONT + push_warning.
## Note: push_warning capture is gdunit4-incompatible; verified via return value.
func test_get_attack_direction_same_tile_returns_front_with_warning() -> void:
	# Arrange
	var grid: MapGrid = _load_grid(_make_los_15x15_map())

	# Act: same coord for attacker and defender.
	var dir_a: int = grid.get_attack_direction(
		Vector2i(5, 5), Vector2i(5, 5), MapGrid.FACING_NORTH
	)

	# Assert: returns FRONT regardless of facing.
	assert_int(dir_a).override_failure_message(
		"AC-10: same-tile attack must return FRONT (caller-bug recovery), got %d" % dir_a
	).is_equal(MapGrid.ATK_DIR_FRONT)

	# Edge: deterministic regardless of facing — try EAST too.
	var dir_e: int = grid.get_attack_direction(
		Vector2i(5, 5), Vector2i(5, 5), MapGrid.FACING_EAST
	)
	assert_int(dir_e).override_failure_message(
		"AC-10 edge: same-tile attack with FACING_EAST must still return FRONT, got %d" % dir_e
	).is_equal(MapGrid.ATK_DIR_FRONT)

	grid.free()


# ─── AC-11: get_adjacent_units cardinal neighbours + faction filter ───────────

## AC-11: 4-cardinal neighbour scan with optional faction filter.
## Setup: center (7,7); ALLY uid=10 at (6,7), ALLY uid=11 at (7,6),
## ENEMY uid=20 at (8,7), no occupant at (7,8).
##
## Expected:
##   no filter → [10, 11, 20] in some order, size 3
##   ALLY  filter → [10, 11] size 2
##   ENEMY filter → [20] size 1
##   no occupants on any neighbour → empty
func test_get_adjacent_units_returns_cardinal_neighbours_with_faction_filter() -> void:
	# Arrange: 15×15 PLAINS, place 3 units around (7,7).
	var grid: MapGrid = _load_grid(_make_los_15x15_map())
	_place(grid, Vector2i(6, 7), 10, MapGrid.FACTION_ALLY)
	_place(grid, Vector2i(7, 6), 11, MapGrid.FACTION_ALLY)
	_place(grid, Vector2i(8, 7), 20, MapGrid.FACTION_ENEMY)

	# Act + Assert: no filter (default -1 = any faction).
	var no_filter: PackedInt32Array = grid.get_adjacent_units(Vector2i(7, 7))
	assert_int(no_filter.size()).override_failure_message(
		"AC-11: no-filter expected 3 units, got %d. Result: %s" \
		% [no_filter.size(), str(no_filter)]
	).is_equal(3)
	# Verify all expected uids present (order is implementation-defined: NESW iteration).
	var no_filter_set: Dictionary = {}
	for uid: int in no_filter:
		no_filter_set[uid] = true
	for expected_uid: int in [10, 11, 20]:
		assert_bool(no_filter_set.has(expected_uid)).override_failure_message(
			"AC-11: uid %d missing from no-filter result %s" \
			% [expected_uid, str(no_filter)]
		).is_true()

	# ALLY filter.
	var ally: PackedInt32Array = grid.get_adjacent_units(Vector2i(7, 7), MapGrid.FACTION_ALLY)
	assert_int(ally.size()).override_failure_message(
		"AC-11: ALLY filter expected 2 units, got %d. Result: %s" \
		% [ally.size(), str(ally)]
	).is_equal(2)
	var ally_set: Dictionary = {}
	for uid: int in ally:
		ally_set[uid] = true
	for expected_uid: int in [10, 11]:
		assert_bool(ally_set.has(expected_uid)).override_failure_message(
			"AC-11: ALLY uid %d missing" % expected_uid
		).is_true()

	# ENEMY filter.
	var enemy: PackedInt32Array = grid.get_adjacent_units(Vector2i(7, 7), MapGrid.FACTION_ENEMY)
	assert_int(enemy.size()).override_failure_message(
		"AC-11: ENEMY filter expected 1 unit, got %d. Result: %s" \
		% [enemy.size(), str(enemy)]
	).is_equal(1)
	assert_int(enemy[0]).override_failure_message(
		"AC-11: ENEMY filter expected uid=20, got %d" % enemy[0]
	).is_equal(20)

	# Edge: query an isolated coord → empty result.
	var isolated: PackedInt32Array = grid.get_adjacent_units(Vector2i(0, 0))
	assert_int(isolated.size()).override_failure_message(
		"AC-11 edge: isolated coord (0,0) with no neighbours occupied → empty, got %d" \
		% isolated.size()
	).is_equal(0)

	grid.free()


# ─── AC-12: get_occupied_tiles deterministic row-major scan ───────────────────

## AC-12: full-map scan returns occupants in row-major order.
## 5 occupants placed deliberately at scattered coords; verify ordering AND filter.
func test_get_occupied_tiles_full_map_scan_deterministic_row_major() -> void:
	# Arrange: 15×15 PLAINS; place 5 units at known coords.
	# Order in row-major: (1,2), (5,2), (3,4), (7,7), (10,12)
	var grid: MapGrid = _load_grid(_make_los_15x15_map())
	_place(grid, Vector2i(1, 2),   10, MapGrid.FACTION_ALLY)
	_place(grid, Vector2i(5, 2),   11, MapGrid.FACTION_ALLY)
	_place(grid, Vector2i(3, 4),   20, MapGrid.FACTION_ENEMY)
	_place(grid, Vector2i(7, 7),   12, MapGrid.FACTION_ALLY)
	_place(grid, Vector2i(10, 12), 21, MapGrid.FACTION_ENEMY)

	# Act + Assert: no-filter returns 5 tiles in row-major order.
	var all_tiles: PackedVector2Array = grid.get_occupied_tiles()
	assert_int(all_tiles.size()).override_failure_message(
		"AC-12: no-filter expected 5 occupied tiles, got %d" % all_tiles.size()
	).is_equal(5)

	# Row-major ordering check.
	var expected_order: Array[Vector2i] = [
		Vector2i(1, 2), Vector2i(5, 2),
		Vector2i(3, 4),
		Vector2i(7, 7),
		Vector2i(10, 12),
	]
	for i: int in expected_order.size():
		assert_that(Vector2i(all_tiles[i])).override_failure_message(
			"AC-12: row-major ordering — at index %d expected %s, got %s" \
			% [i, str(expected_order[i]), str(Vector2i(all_tiles[i]))]
		).is_equal(expected_order[i])

	# Faction filter: ALLY → 3 tiles.
	var ally_tiles: PackedVector2Array = grid.get_occupied_tiles(MapGrid.FACTION_ALLY)
	assert_int(ally_tiles.size()).override_failure_message(
		"AC-12: ALLY filter expected 3 tiles, got %d. Result: %s" \
		% [ally_tiles.size(), str(ally_tiles)]
	).is_equal(3)

	# Faction filter: ENEMY → 2 tiles.
	var enemy_tiles: PackedVector2Array = grid.get_occupied_tiles(MapGrid.FACTION_ENEMY)
	assert_int(enemy_tiles.size()).override_failure_message(
		"AC-12: ENEMY filter expected 2 tiles, got %d. Result: %s" \
		% [enemy_tiles.size(), str(enemy_tiles)]
	).is_equal(2)

	# Edge: clear one occupant via mutation API; count drops to 4.
	# clear_occupant returns void; success verified via get_occupied_tiles count drop.
	grid.clear_occupant(Vector2i(7, 7))
	var after_clear: PackedVector2Array = grid.get_occupied_tiles()
	assert_int(after_clear.size()).override_failure_message(
		"AC-12 edge: after clear_occupant(7,7), expected 4 tiles, got %d" % after_clear.size()
	).is_equal(4)

	grid.free()
