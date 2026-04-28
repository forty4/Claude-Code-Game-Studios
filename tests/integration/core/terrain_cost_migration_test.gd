extends GdUnitTestSuite

## terrain_cost_migration_test.gd
## Integration tests for Story 006 (terrain-effect epic): TerrainEffect.cost_multiplier
## + terrain_cost.gd:32 migration + Map/Grid regression sanity.
##
## Updated by Story 008 (unit-role epic): placeholder retirement. The MVP uniform-1
## behaviour (CR-1d) has been replaced by per-class-per-terrain values via
## UnitRole.get_class_cost_table(). Tests asserting the old uniform-1 behaviour
## are updated to reflect the new per-class-per-terrain contract. The TerrainCost
## delegate parity tests (AC-4, AC-6 Part 1) remain structurally unchanged — both
## call paths now return per-class-per-terrain values consistently.
##
## Governing ADR: ADR-0008 Terrain Effect System (Accepted 2026-04-25), §Decision 5
##                + §Migration Plan.
## ADR-0009 §5 (story-008): cost matrix unit-class dimension ratification; placeholder
##                retired; UnitRole.get_class_cost_table() is now the data source.
## Related TRs:   TR-terrain-effect-018 (cost_matrix structure),
##                TR-terrain-effect-002 (CR-1d uniform — superseded by ADR-0009 §5).
##
## TERRAIN_TYPE ORDERING NOTE (story-008 discovery):
##   TerrainEffect canonical ordering: PLAINS=0, FOREST=1, HILLS=2, MOUNTAIN=3,
##   RIVER=4, BRIDGE=5, FORTRESS_WALL=6, ROAD=7.
##   UnitRole terrain_cost_table index: ROAD=0, PLAINS=1, HILLS=2, FOREST=3,
##   MOUNTAIN=4, BRIDGE=5.
##   Translation happens inside TerrainEffect.cost_multiplier() via _UNIT_ROLE_TERRAIN_IDX.
##   All terrain_type values in this test use TerrainEffect's canonical ordering.
##
## STORY TYPE: Integration — verifies BOTH the new TerrainEffect.cost_multiplier
## method AND the terrain_cost.gd:32 delegate AND the Map/Grid regression sanity
## check via get_movement_range (map-grid Dijkstra story-005 is landed on this branch).
##
## ISOLATION (ADR-0008 §Notes §1 + §Risks line 562):
##   before_test() calls TerrainEffect.reset_for_tests() + UnitRole cache reset
##   unconditionally — every test starts from pristine defaults. Per gotcha G-15:
##   hook MUST be `before_test()`, NOT `before_each()`.

const TERRAIN_EFFECT_PATH: String = "res://src/core/terrain_effect.gd"

var _fixture_path: String = ""


func before_test() -> void:
	TerrainEffect.reset_for_tests()
	UnitRole._coefficients_loaded = false
	UnitRole._coefficients = {}
	_fixture_path = ""


func after_test() -> void:
	if not _fixture_path.is_empty():
		DirAccess.remove_absolute(_fixture_path)
		_fixture_path = ""


# ── Helpers ──────────────────────────────────────────────────────────────────


## Writes [param content] to user://<filename>, records the absolute path for
## cleanup in after_test(), and returns the user:// path for passing to load_config().
func _write_fixture(filename: String, content: String) -> String:
	var fa: FileAccess = FileAccess.open("user://" + filename, FileAccess.WRITE)
	fa.store_string(content)
	fa.close()
	_fixture_path = ProjectSettings.globalize_path("user://" + filename)
	return "user://" + filename


## Build a [param rows]×[param cols] MapResource with per-tile terrain types
## from flat Array[int] [param terrain_grid] of length rows*cols.
## All tiles: is_passable_base=true, tile_state=EMPTY.
func _make_custom_terrain_map(rows: int, cols: int, terrain_grid: Array[int]) -> MapResource:
	var elev_for_terrain: Array[int] = [0, 0, 1, 2, 0, 0, 1, 0]
	var m := MapResource.new()
	m.map_id = &"tc_migration_custom"
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


# ── AC-1: Per-class-per-terrain values (placeholder retired) ─────────────────


## AC-1 (TR-018 + ADR-0009 §5): TerrainEffect.cost_multiplier returns per-class-per-terrain
## int-truncated values after story-008 placeholder retirement.
##
## Old behaviour (MVP CR-1d): all (unit_type, terrain_type) pairs returned 1.
## New behaviour: values come from UnitRole.get_class_cost_table(unit_class)[terrain_idx],
## int-truncated. RIVER (terrain_type=4) and FORTRESS_WALL (terrain_type=6) are
## impassable per CR-4a; covered separately in AC-3.
##
## TerrainEffect terrain_type ordering used here: PLAINS=0, FOREST=1, HILLS=2, MOUNTAIN=3,
## BRIDGE=5, ROAD=7. UnitRole index translation happens inside cost_multiplier().
##
## Expected values (int(float) truncation; from unit_roles.json + ADR-0009 §5 table):
##   CAVALRY(0):    PLAINS=1, FOREST=2, HILLS=1, MOUNTAIN=3, BRIDGE=1, ROAD=1
##   INFANTRY(1):   PLAINS=1, FOREST=1, HILLS=1, MOUNTAIN=1, BRIDGE=1, ROAD=1
##   ARCHER(2):     PLAINS=1, FOREST=1, HILLS=1, MOUNTAIN=2, BRIDGE=1, ROAD=1
##   STRATEGIST(3): PLAINS=1, FOREST=1, HILLS=1, MOUNTAIN=2, BRIDGE=1, ROAD=1
##   COMMANDER(4):  PLAINS=1, FOREST=1, HILLS=1, MOUNTAIN=2, BRIDGE=1, ROAD=1
##   SCOUT(5):      PLAINS=1, FOREST=0, HILLS=1, MOUNTAIN=1, BRIDGE=1, ROAD=1
##
## int() truncation notes:
##   CAVALRY HILLS: 1.5→1  |  CAVALRY FOREST: 2.0→2  |  CAVALRY MOUNTAIN: 3.0→3
##   INFANTRY MOUNTAIN: 1.5→1  |  SCOUT FOREST: 0.7→0
func test_terrain_cost_migration_per_class_per_terrain_values() -> void:
	# Per-class expected values keyed by TerrainEffect terrain_type int.
	# Uses TerrainEffect canonical ordering (PLAINS=0, FOREST=1, HILLS=2, MOUNTAIN=3,
	# BRIDGE=5, ROAD=7). RIVER(4) and FORTRESS_WALL(6) absent — tested in AC-3.
	var expected: Array[Dictionary] = [
		# { "unit_class": int, "terrain_type": int (TerrainEffect ordering), "expected": int }
		# CAVALRY (0)
		{"unit_class": 0, "terrain_type": 0, "expected": 1},  # PLAINS
		{"unit_class": 0, "terrain_type": 1, "expected": 2},  # FOREST (2.0 → 2)
		{"unit_class": 0, "terrain_type": 2, "expected": 1},  # HILLS  (1.5 → 1)
		{"unit_class": 0, "terrain_type": 3, "expected": 3},  # MOUNTAIN (3.0 → 3)
		{"unit_class": 0, "terrain_type": 5, "expected": 1},  # BRIDGE
		{"unit_class": 0, "terrain_type": 7, "expected": 1},  # ROAD
		# INFANTRY (1)
		{"unit_class": 1, "terrain_type": 0, "expected": 1},
		{"unit_class": 1, "terrain_type": 1, "expected": 1},
		{"unit_class": 1, "terrain_type": 2, "expected": 1},
		{"unit_class": 1, "terrain_type": 3, "expected": 1},  # MOUNTAIN (1.5 → 1)
		{"unit_class": 1, "terrain_type": 5, "expected": 1},
		{"unit_class": 1, "terrain_type": 7, "expected": 1},
		# ARCHER (2)
		{"unit_class": 2, "terrain_type": 0, "expected": 1},
		{"unit_class": 2, "terrain_type": 1, "expected": 1},
		{"unit_class": 2, "terrain_type": 2, "expected": 1},
		{"unit_class": 2, "terrain_type": 3, "expected": 2},  # MOUNTAIN (2.0 → 2)
		{"unit_class": 2, "terrain_type": 5, "expected": 1},
		{"unit_class": 2, "terrain_type": 7, "expected": 1},
		# STRATEGIST (3)
		{"unit_class": 3, "terrain_type": 0, "expected": 1},
		{"unit_class": 3, "terrain_type": 1, "expected": 1},  # FOREST (1.5 → 1)
		{"unit_class": 3, "terrain_type": 2, "expected": 1},  # HILLS (1.5 → 1)
		{"unit_class": 3, "terrain_type": 3, "expected": 2},  # MOUNTAIN (2.0 → 2)
		{"unit_class": 3, "terrain_type": 5, "expected": 1},
		{"unit_class": 3, "terrain_type": 7, "expected": 1},
		# COMMANDER (4)
		{"unit_class": 4, "terrain_type": 0, "expected": 1},
		{"unit_class": 4, "terrain_type": 1, "expected": 1},  # FOREST (1.5 → 1)
		{"unit_class": 4, "terrain_type": 2, "expected": 1},
		{"unit_class": 4, "terrain_type": 3, "expected": 2},  # MOUNTAIN (2.0 → 2)
		{"unit_class": 4, "terrain_type": 5, "expected": 1},
		{"unit_class": 4, "terrain_type": 7, "expected": 1},
		# SCOUT (5)
		{"unit_class": 5, "terrain_type": 0, "expected": 1},
		{"unit_class": 5, "terrain_type": 1, "expected": 0},  # FOREST (0.7 → 0)
		{"unit_class": 5, "terrain_type": 2, "expected": 1},
		{"unit_class": 5, "terrain_type": 3, "expected": 1},  # MOUNTAIN (1.5 → 1)
		{"unit_class": 5, "terrain_type": 5, "expected": 1},
		{"unit_class": 5, "terrain_type": 7, "expected": 1},
	]

	for case: Dictionary in expected:
		var u: int = case["unit_class"] as int
		var t: int = case["terrain_type"] as int
		var ex: int = case["expected"] as int
		var result: int = TerrainEffect.cost_multiplier(u, t)
		assert_int(result).override_failure_message(
			("AC-1: TerrainEffect.cost_multiplier(unit_class=%d, terrain_type=%d) "
			+ "expected %d; got %d") % [u, t, ex, result]
		).is_equal(ex)


# ── AC-2: First call triggers lazy load ──────────────────────────────────────


## AC-2 (TR-002): cost_multiplier has the same lazy-init contract as the other
## public query methods — first call triggers load_config() if _config_loaded is false.
##
## Given: reset_for_tests() called in before_test() → _config_loaded == false.
## When:  TerrainEffect.cost_multiplier(0, 0) called (CAVALRY × PLAINS).
## Then:  returns 1 (CAVALRY × PLAINS = 1.0 → int 1); _config_loaded == true after.
##
## Note (story-008): CAVALRY × PLAINS uses TerrainEffect.PLAINS=0 → UnitRole index 1
## → cavalry terrain_cost_table[1] = 1.0 → int(1.0) = 1. Return value unchanged from
## MVP; only the code path changed (UnitRole delegation vs _cost_default_multiplier).
func test_terrain_cost_migration_first_call_triggers_lazy_load() -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript

	# Precondition: reset_for_tests() was called in before_test() → _config_loaded false.
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		("AC-2: _config_loaded must be false after reset_for_tests() — "
		+ "before the first cost_multiplier call")
	).is_false()

	# Act: CAVALRY(0) × PLAINS(0) → UnitRole index 1 → 1.0 → int 1
	var result: int = TerrainEffect.cost_multiplier(0, 0)

	# Assert return value
	assert_int(result).override_failure_message(
		"AC-2: cost_multiplier(CAVALRY=0, PLAINS=0) must return 1; got %d" % result
	).is_equal(1)

	# Assert lazy-init side effect
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"AC-2: _config_loaded must be true after first cost_multiplier call (lazy-init fired)"
	).is_true()


# ── AC-3: Impassable-terrain contract-violation fallback ─────────────────────


## AC-3: cost_multiplier returns 1 and emits push_error for impassable terrain types.
##
## RIVER (TerrainEffect.RIVER=4) and FORTRESS_WALL (TerrainEffect.FORTRESS_WALL=6)
## are absent from _UNIT_ROLE_TERRAIN_IDX because they are impassable per CR-4a.
## Map/Grid short-circuits via is_passable_base before cost_multiplier is reached.
## If cost_multiplier IS called with those terrain_types, it is a contract violation:
## the method emits push_error and returns 1 as a safe fallback.
##
## Story-008 deviation note: this test was originally AC-3 (config-driven
## default_multiplier override). That behaviour is now moot — cost_multiplier() no
## longer reads _cost_default_multiplier. The test is repurposed to cover the
## impassable-terrain contract-violation guard added in story-008.
func test_terrain_cost_migration_impassable_terrain_river_returns_fallback() -> void:
	# RIVER = TerrainEffect.RIVER = 4; not in _UNIT_ROLE_TERRAIN_IDX
	var result: int = TerrainEffect.cost_multiplier(0, TerrainEffect.RIVER)
	assert_int(result).override_failure_message(
		("AC-3a: cost_multiplier(CAVALRY=0, RIVER=4) must return 1 (safe fallback for "
		+ "impassable terrain); got %d") % result
	).is_equal(1)

	# push_error captured via GdUnit4 assert_error + is_push_error(any())
	await assert_error(func() -> void:
		var _r: int = TerrainEffect.cost_multiplier(0, TerrainEffect.RIVER)
	).is_push_error(any())


func test_terrain_cost_migration_impassable_terrain_fortress_wall_returns_fallback() -> void:
	# FORTRESS_WALL = TerrainEffect.FORTRESS_WALL = 6; not in _UNIT_ROLE_TERRAIN_IDX
	var result: int = TerrainEffect.cost_multiplier(0, TerrainEffect.FORTRESS_WALL)
	assert_int(result).override_failure_message(
		("AC-3b: cost_multiplier(CAVALRY=0, FORTRESS_WALL=6) must return 1 (safe fallback "
		+ "for impassable terrain); got %d") % result
	).is_equal(1)

	await assert_error(func() -> void:
		var _r: int = TerrainEffect.cost_multiplier(0, TerrainEffect.FORTRESS_WALL)
	).is_push_error(any())


# ── AC-4: terrain_cost.gd delegates to TerrainEffect ─────────────────────────


## AC-4 (Migration verification): TerrainCost.cost_multiplier delegates correctly
## to TerrainEffect.cost_multiplier — both return identical values for every call.
##
## Given: reset_for_tests() + default config (lazy-loaded on first call).
## When:  TerrainCost.cost_multiplier(u, t) vs TerrainEffect.cost_multiplier(u, t)
##        for representative pairs.
## Then:  direct == delegated for each pair.
##
## Pairs and their post-story-008 expected values
## (TerrainEffect terrain_type ordering: PLAINS=0, FOREST=1, HILLS=2, MOUNTAIN=3,
##  BRIDGE=5, ROAD=7):
##   (unit=2=ARCHER,    terrain=3=MOUNTAIN): MOUNTAIN→UnitRole idx 4→archer[4]=2.0→int 2
##   (unit=0=CAVALRY,   terrain=7=ROAD):    ROAD→UnitRole idx 0→cavalry[0]=1.0→int 1
##   (unit=4=COMMANDER, terrain=5=BRIDGE):  BRIDGE→UnitRole idx 5→commander[5]=1.0→int 1
func test_terrain_cost_migration_terrain_cost_delegates_to_terrain_effect() -> void:
	# Vector2i.x = unit_type (UnitClass int), Vector2i.y = terrain_type (TerrainEffect ordering)
	var pairs: Array[Vector2i] = [
		Vector2i(2, 3),   # ARCHER × MOUNTAIN
		Vector2i(0, 7),   # CAVALRY × ROAD
		Vector2i(4, 5),   # COMMANDER × BRIDGE
	]
	var expected_direct: Array[int] = [2, 1, 1]

	for i: int in pairs.size():
		var u: int = pairs[i].x
		var t: int = pairs[i].y
		var direct: int = TerrainEffect.cost_multiplier(u, t)
		var delegated: int = TerrainCost.cost_multiplier(u, t)

		assert_int(delegated).override_failure_message(
			("AC-4: TerrainCost.cost_multiplier(%d, %d) must equal "
			+ "TerrainEffect.cost_multiplier(%d, %d) = %d; got %d")
			% [u, t, u, t, direct, delegated]
		).is_equal(direct)

		assert_int(direct).override_failure_message(
			("AC-4: TerrainEffect.cost_multiplier(%d, %d) expected %d; got %d")
			% [u, t, expected_direct[i], direct]
		).is_equal(expected_direct[i])


# ── AC-5: Full-suite baseline documentation marker ────────────────────────────


## AC-5 (Map/Grid regression — integration verification marker):
## Full pre/post-story-008 suite counts must match; zero regression.
##
## This function asserts baseline values for both call paths. The orchestrator-level
## verification (suite count match pre vs post story-008) is performed via the
## GdUnitCmdTool regression run captured in active.md story-008 extract.
##
## CAVALRY × PLAINS (unit_type=0, terrain_type=0): UnitRole index 1, cavalry[1]=1.0 → int 1.
## This pair produces 1 before and after story-008 retirement — no regression on this cell.
func test_terrain_cost_migration_documents_full_suite_baseline() -> void:
	# Baseline: CAVALRY × PLAINS → 1 via both paths (unchanged after story-008).
	var via_terrain_effect: int = TerrainEffect.cost_multiplier(0, 0)
	var via_terrain_cost: int = TerrainCost.cost_multiplier(0, 0)

	assert_int(via_terrain_effect).override_failure_message(
		("AC-5: TerrainEffect.cost_multiplier(CAVALRY=0, PLAINS=0) baseline must be 1;"
		+ " got %d") % via_terrain_effect
	).is_equal(1)

	assert_int(via_terrain_cost).override_failure_message(
		("AC-5: TerrainCost.cost_multiplier(CAVALRY=0, PLAINS=0) baseline must be 1;"
		+ " got %d") % via_terrain_cost
	).is_equal(1)


# ── AC-6: Smoke path via TerrainCost into Map/Grid Dijkstra ──────────────────


## AC-6 (Smoke integration test): Map/Grid Dijkstra produces correct
## get_movement_range results through the post-story-008 TerrainCost delegate.
##
## CAVALRY(unit_type=0) on the 15×15 terrain grid:
##   PLAINS (TerrainEffect.PLAINS=0): step = 10 × cost_multiplier(0,0) = 10 × 1 = 10
##   HILLS  (TerrainEffect.HILLS=2):  step = 15 × cost_multiplier(0,2) = 15 × int(1.5)=1 = 15
##   FOREST (TerrainEffect.FOREST=1): step = 15 × cost_multiplier(0,1) = 15 × int(2.0)=2 = 30
##
## Budget = move_range(3) × MOVE_BUDGET_PER_RANGE(10) = 30.
## CAVALRY×HILLS int-truncation (1.5→1) preserves story-006 Dijkstra geometry.
## CAVALRY×FOREST multiplier changed (1→2), but FOREST tiles (col≥11) are unreachable
## from (7,7) within budget=30 via the HILLS barrier, so all geometry assertions hold.
func test_terrain_cost_migration_smoke_path_via_terrain_cost() -> void:
	# ── Part 1: full matrix delegate == direct parity check ──────────────────
	# Verifies TerrainCost.cost_multiplier == TerrainEffect.cost_multiplier for
	# all 6 classes × 8 terrain types. RIVER(4) and FORTRESS_WALL(6) return 1
	# via push_error fallback on both paths — parity still holds.
	for unit_type: int in range(6):
		for terrain_type: int in range(8):
			var direct: int = TerrainEffect.cost_multiplier(unit_type, terrain_type)
			var delegated: int = TerrainCost.cost_multiplier(unit_type, terrain_type)
			assert_int(delegated).override_failure_message(
				("AC-6 matrix check: TerrainCost.cost_multiplier(%d, %d) = %d "
				+ "must equal TerrainEffect.cost_multiplier(%d, %d) = %d")
				% [unit_type, terrain_type, delegated, unit_type, terrain_type, direct]
			).is_equal(direct)

	# ── Part 2: get_movement_range Dijkstra smoke ─────────────────────────────
	# Build 15×15 mixed-terrain map: mostly PLAINS (0) with a HILLS (2) band and
	# a FOREST (1) patch. Layout: rows 5-9 are HILLS, col 11-14 are FOREST,
	# everything else PLAINS. Unit placed at (7,7) (center).
	var terrain_grid: Array[int] = []
	for row: int in range(15):
		for col: int in range(15):
			if row >= 5 and row <= 9:
				terrain_grid.append(TerrainCost.HILLS)
			elif col >= 11:
				terrain_grid.append(TerrainCost.FOREST)
			else:
				terrain_grid.append(TerrainCost.PLAINS)

	var res: MapResource = _make_custom_terrain_map(15, 15, terrain_grid)
	var grid := MapGrid.new()
	var load_ok: bool = grid.load_map(res)
	assert_bool(load_ok).override_failure_message(
		("AC-6: load_map() failed on mixed-terrain fixture. Errors: %s")
		% str(grid.get_last_load_errors())
	).is_true()

	grid.set_occupant(Vector2i(7, 7), 1, MapGrid.FACTION_ALLY)

	# unit_type=0 (CAVALRY). Step costs with post-story-008 multipliers:
	#   PLAINS: 10 × 1 = 10  |  HILLS: 15 × 1 = 15  |  FOREST: 15 × 2 = 30
	# move_range=3 → budget=30.
	var result: PackedVector2Array = grid.get_movement_range(1, 3, 0)

	# Sanity: origin tile (7,7) is always included.
	var result_set: Dictionary[Vector2i, bool] = {}
	for v: Vector2 in result:
		result_set[Vector2i(v)] = true

	assert_bool(result_set.has(Vector2i(7, 7))).override_failure_message(
		"AC-6: origin (7,7) must be in get_movement_range result"
	).is_true()

	assert_int(result.size()).override_failure_message(
		("AC-6: get_movement_range must return more than just origin; got %d tiles")
		% result.size()
	).is_greater(1)

	# (6,7) HILLS, 1 step west — cost 15, reachable within budget=30.
	assert_bool(result_set.has(Vector2i(6, 7))).override_failure_message(
		("AC-6: tile (6,7) (HILLS, step=15) should be reachable from (7,7) "
		+ "with budget=30; missing from result")
	).is_true()

	# (5,7) HILLS, 2 steps west — 15+15=30=budget. Boundary reachability check.
	assert_bool(result_set.has(Vector2i(5, 7))).override_failure_message(
		("AC-6: tile (5,7) (HILLS, 2 steps at cost 15 each = 30 = budget) "
		+ "should be reachable; missing from result")
	).is_true()

	# (7,4) PLAINS beyond HILLS band — cost 40 > budget=30. Negative assertion.
	assert_bool(result_set.has(Vector2i(7, 4))).override_failure_message(
		"AC-6: tile (7,4) (PLAINS beyond HILLS band, total cost 40) must NOT be "
		+ "reachable from (7,7) with budget=30; HILLS band must form a barrier"
	).is_false()

	# G-6 cleanup: MapGrid was Node.new()'d; free before test exit to avoid orphan.
	grid.free()
