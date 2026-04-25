extends GdUnitTestSuite

## terrain_cost_migration_test.gd
## Integration tests for Story 006 (terrain-effect epic): TerrainEffect.cost_multiplier
## + terrain_cost.gd:32 migration + Map/Grid regression sanity.
##
## Covers AC-1 through AC-6 from story-006 §Acceptance Criteria + §QA Test Cases.
##
## Governing ADR: ADR-0008 Terrain Effect System (Accepted 2026-04-25), §Decision 5
##                + §Migration Plan.
## Related TRs:   TR-terrain-effect-018 (cost_matrix structure),
##                TR-terrain-effect-002 (CR-1d uniform).
##
## STORY TYPE: Integration — verifies BOTH the new TerrainEffect.cost_multiplier
## method AND the terrain_cost.gd:32 delegate AND the Map/Grid regression sanity
## check via get_movement_range (map-grid Dijkstra story-005 is landed on this branch).
##
## ISOLATION (ADR-0008 §Notes §1 + §Risks line 562):
##   before_test() calls TerrainEffect.reset_for_tests() unconditionally — every
##   test starts from pristine defaults. AC-3 writes a per-test fixture to user://
##   and cleans up in after_test() (same pattern as terrain_effect_config_test.gd).
##   Per gotcha G-15: hook MUST be `before_test()`, NOT `before_each()`.

const TERRAIN_EFFECT_PATH: String = "res://src/core/terrain_effect.gd"

var _fixture_path: String = ""


func before_test() -> void:
	TerrainEffect.reset_for_tests()
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


## Writes a fixture JSON with cost_matrix.default_multiplier overridden to
## [param default_multiplier] and ALL other fields set to canonical CR-1 values.
## Returns the user:// path.
func _write_ac3_fixture(default_multiplier: int) -> String:
	var json: String = ("""{
  "schema_version": 1,
  "terrain_modifiers": {
    "0": { "name": "PLAINS",        "defense_bonus": 0,  "evasion_bonus": 0,  "special_rules": [] },
    "1": { "name": "FOREST",        "defense_bonus": 5,  "evasion_bonus": 15, "special_rules": [] },
    "2": { "name": "HILLS",         "defense_bonus": 15, "evasion_bonus": 0,  "special_rules": [] },
    "3": { "name": "MOUNTAIN",      "defense_bonus": 20, "evasion_bonus": 5,  "special_rules": [] },
    "4": { "name": "RIVER",         "defense_bonus": 0,  "evasion_bonus": 0,  "special_rules": [] },
    "5": { "name": "BRIDGE",        "defense_bonus": 5,  "evasion_bonus": 0,  "special_rules": ["bridge_no_flank"] },
    "6": { "name": "FORTRESS_WALL", "defense_bonus": 25, "evasion_bonus": 0,  "special_rules": [] },
    "7": { "name": "ROAD",          "defense_bonus": 0,  "evasion_bonus": 0,  "special_rules": [] }
  },
  "elevation_modifiers": {
    "-2": { "attack_mod": -15, "defense_mod": 15 },
    "-1": { "attack_mod": -8,  "defense_mod": 8  },
    "0":  { "attack_mod": 0,   "defense_mod": 0  },
    "1":  { "attack_mod": 8,   "defense_mod": -8 },
    "2":  { "attack_mod": 15,  "defense_mod": -15 }
  },
  "caps": { "max_defense_reduction": 30, "max_evasion": 30 },
  "ai_scoring": { "evasion_weight": 1.2, "max_possible_score": 43.0 },
  "cost_matrix": { "default_multiplier": %d }
}""") % default_multiplier
	return _write_fixture("terrain_config_ac3_story006.json", json)


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


# ── AC-1: Uniform 1 across 5×8 matrix ────────────────────────────────────────


## AC-1 (TR-018 + CR-1d): TerrainEffect.cost_multiplier returns 1 for all
## 5×8 = 40 (unit_type, terrain_type) pairs after default config load.
##
## Given: reset_for_tests() in before_test(); default config load (lazy-triggered).
## When:  nested loop unit_type in [0,5) × terrain_type in [0,8).
## Then:  every call returns 1.
##
## Override failure messages include the (unit_type, terrain_type) pair so a
## regression in ADR-0009 value-population work is immediately localised.
func test_terrain_cost_migration_uniform_one_across_5x8_matrix() -> void:
	for unit_type: int in range(5):
		for terrain_type: int in range(8):
			var result: int = TerrainEffect.cost_multiplier(unit_type, terrain_type)
			assert_int(result).override_failure_message(
				("AC-1: TerrainEffect.cost_multiplier(%d, %d) must return 1 in MVP;"
				+ " got %d") % [unit_type, terrain_type, result]
			).is_equal(1)


# ── AC-2: First call triggers lazy load ──────────────────────────────────────


## AC-2 (TR-002): cost_multiplier has the same lazy-init contract as the other
## public query methods — first call triggers load_config() if _config_loaded is false.
##
## Given: reset_for_tests() called in before_test() → _config_loaded == false.
## When:  TerrainEffect.cost_multiplier(0, 0) called.
## Then:  returns 1; _config_loaded == true after the call.
func test_terrain_cost_migration_first_call_triggers_lazy_load() -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript

	# Precondition: reset_for_tests() was called in before_test() → _config_loaded false.
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		("AC-2: _config_loaded must be false after reset_for_tests() — "
		+ "before the first cost_multiplier call")
	).is_false()

	# Act
	var result: int = TerrainEffect.cost_multiplier(0, 0)

	# Assert return value
	assert_int(result).override_failure_message(
		"AC-2: cost_multiplier(0, 0) must return 1 (default config); got %d" % result
	).is_equal(1)

	# Assert lazy-init side effect
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"AC-2: _config_loaded must be true after first cost_multiplier call (lazy-init fired)"
	).is_true()


# ── AC-3: Respects tuned default_multiplier from config ──────────────────────


## AC-3: cost_multiplier respects a config-driven _cost_default_multiplier override.
##
## Given: fixture JSON with cost_matrix.default_multiplier=3 (all other fields canonical);
##        reset_for_tests() + load_config(fixture_path).
## When:  TerrainEffect.cost_multiplier(0, 0).
## Then:  returns 3 — verifies the config-driven path, not the compile-time default.
##
## This is the key data-driven promise: tuning the multiplier happens in JSON config,
## not in code. ADR-0009 will replace the uniform default with per-pair lookups; this
## test verifies the default-multiplier fallback path remains correct for unpopulated pairs.
func test_terrain_cost_migration_respects_tuned_default_multiplier() -> void:
	# Arrange: write fixture with default_multiplier=3
	var fixture_path: String = _write_ac3_fixture(3)

	# Act: load custom config (reset_for_tests already called in before_test)
	var load_ok: bool = TerrainEffect.load_config(fixture_path)
	assert_bool(load_ok).override_failure_message(
		"AC-3: load_config() must return true for the AC-3 fixture (all fields valid)"
	).is_true()

	# Assert: cost_multiplier reflects tuned value
	var result: int = TerrainEffect.cost_multiplier(0, 0)
	assert_int(result).override_failure_message(
		("AC-3: cost_multiplier(0, 0) must return 3 after loading fixture with "
		+ "default_multiplier=3; got %d") % result
	).is_equal(3)

	# Spot-check a second pair — the override is uniform across all (unit, terrain)
	var result2: int = TerrainEffect.cost_multiplier(4, 7)
	assert_int(result2).override_failure_message(
		("AC-3: cost_multiplier(4, 7) must also return 3 (uniform default); got %d")
		% result2
	).is_equal(3)


# ── AC-4: terrain_cost.gd delegates to TerrainEffect ─────────────────────────


## AC-4 (Migration verification): TerrainCost.cost_multiplier delegates correctly
## to TerrainEffect.cost_multiplier — both return identical values for every call.
##
## Given: reset_for_tests() + default config (lazy-loaded on first call).
## When:  TerrainCost.cost_multiplier(u, t) vs TerrainEffect.cost_multiplier(u, t)
##        for representative pairs (u=2,t=3), (u=0,t=7), (u=4,t=5).
## Then:  direct == delegated for each pair; both return 1 in MVP.
##
## MVP limitation note: because all pairs return 1 in MVP, args-swap regressions
## in the delegate (e.g. accidentally passing terrain_type as unit_type) are NOT
## detectable here — both orderings return 1. The structural wiring is verified;
## value-symmetry testing becomes meaningful after ADR-0009 populates per-pair values.
## TODO (ADR-0009): add an asymmetric-value test when cost_matrix entries are populated.
func test_terrain_cost_migration_terrain_cost_delegates_to_terrain_effect() -> void:
	# Three representative pairs to catch obvious wiring errors.
	# Vector2i.x = unit_type, Vector2i.y = terrain_type.
	var pairs: Array[Vector2i] = [
		Vector2i(2, 3),   # unit_type=2 (placeholder), terrain_type=MOUNTAIN
		Vector2i(0, 7),   # unit_type=0, terrain_type=ROAD
		Vector2i(4, 5),   # unit_type=4, terrain_type=BRIDGE
	]

	for pair: Vector2i in pairs:
		var u: int = pair.x
		var t: int = pair.y
		var direct: int = TerrainEffect.cost_multiplier(u, t)
		var delegated: int = TerrainCost.cost_multiplier(u, t)
		assert_int(delegated).override_failure_message(
			("AC-4: TerrainCost.cost_multiplier(%d, %d) must equal "
			+ "TerrainEffect.cost_multiplier(%d, %d) = %d; got %d")
			% [u, t, u, t, direct, delegated]
		).is_equal(direct)
		assert_int(direct).override_failure_message(
			("AC-4: TerrainEffect.cost_multiplier(%d, %d) must return 1 in MVP;"
			+ " got %d") % [u, t, direct]
		).is_equal(1)


# ── AC-5: Full-suite baseline documentation marker ────────────────────────────


## AC-5 (Map/Grid regression — integration verification marker):
## Full pre/post-migration suite counts must match; zero regression.
##
## This function documents the AC-5 contract and asserts the baseline MVP values
## for both call paths. The orchestrator-level verification (276 PASS pre-migration →
## 282 PASS post-migration, 0 errors, 0 failures, 0 orphans, EXIT 0) is performed
## via the GdUnitCmdTool regression run and captured in active.md story-006 extract.
##
## NOTE: this function ASSERTS THE VALUE CONTRACT ONLY (both call paths return 1
## in MVP). The count contract (full-suite regression count match pre vs post
## migration) is NOT automatically verified inside this function — it is verified
## externally via the orchestrator's GdUnitCmdTool regression run and the captured
## count delta is recorded in production/session-state/active.md story-006 extract.
## A future regression that silently reduces the test count (e.g., G-7 parse-fail)
## would NOT turn this test red; it would only show up as a count mismatch in the
## orchestrator's external comparison. AC-5 protection is hybrid: this function
## guards the value contract; active.md guards the count contract.
func test_terrain_cost_migration_documents_full_suite_baseline() -> void:
	# Baseline: both call paths return 1 for default config (MVP regression guard).
	var via_terrain_effect: int = TerrainEffect.cost_multiplier(0, 0)
	var via_terrain_cost: int = TerrainCost.cost_multiplier(0, 0)

	assert_int(via_terrain_effect).override_failure_message(
		("AC-5: TerrainEffect.cost_multiplier(0, 0) baseline must be 1;"
		+ " got %d") % via_terrain_effect
	).is_equal(1)

	assert_int(via_terrain_cost).override_failure_message(
		("AC-5: TerrainCost.cost_multiplier(0, 0) baseline must be 1;"
		+ " got %d") % via_terrain_cost
	).is_equal(1)


# ── AC-6: Smoke path via TerrainCost into Map/Grid Dijkstra ──────────────────


## AC-6 (Smoke integration test): Map/Grid Dijkstra produces identical
## get_movement_range results whether using the migrated TerrainCost delegate
## or the direct TerrainEffect.cost_multiplier path.
##
## Map-grid story-005 (Dijkstra) is landed on this branch; get_movement_range is
## available and directly exercises the TerrainCost.cost_multiplier call site at
## map_grid.gd line 827. Since cost_multiplier now delegates to TerrainEffect,
## this test is the end-to-end smoke that migration introduces no off-by-one or
## routing change.
##
## Approach: build a 15×15 mixed-terrain fixture (PLAINS/HILLS/FOREST), place a
## unit at (7,7), call get_movement_range(1, 3, INFANTRY) which exercises the
## Dijkstra path including TerrainCost.cost_multiplier. Verify reachable count
## matches expectations (same terrain mix gives deterministic diamond). Then
## exhaustively verify TerrainCost.cost_multiplier == TerrainEffect.cost_multiplier
## for every terrain type present on the fixture map.
##
## AC-6 also cross-checks: for all (unit_type in [0,5)) × (terrain_type in [0,8)),
## TerrainCost.cost_multiplier == TerrainEffect.cost_multiplier, verifying no drift
## between the delegate and direct call paths at the full matrix level.
func test_terrain_cost_migration_smoke_path_via_terrain_cost() -> void:
	# ── Part 1: full matrix delegate == direct check ─────────────────────────
	# AC-6 mandates: every (unit, terrain) pair returns identical values via
	# both paths. In MVP all pairs return 1, so this also acts as a regression
	# guard for any future ADR-0009 work that updates one path but not the other.
	for unit_type: int in range(5):
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
	# a FOREST (1) patch near the unit's origin to exercise multiple terrain costs
	# in the same Dijkstra expansion.
	#
	# Layout (15 cols × 15 rows, flat row-major): rows 5-9 are HILLS, col 11-14
	# are FOREST, everything else PLAINS. Unit placed at (7,7) (center).
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

	# With cost_multiplier returning 1 for all terrain types (MVP/CR-1d), step costs
	# are: PLAINS=10, HILLS=15, FOREST=15. move_range=3 → budget=30.
	# The result set is deterministic from the terrain layout.
	var result: PackedVector2Array = grid.get_movement_range(1, 3, 0)

	# Sanity: origin tile (7,7) is always included.
	var result_set: Dictionary[Vector2i, bool] = {}
	for v: Vector2 in result:
		result_set[Vector2i(v)] = true

	assert_bool(result_set.has(Vector2i(7, 7))).override_failure_message(
		"AC-6: origin (7,7) must be in get_movement_range result"
	).is_true()

	# Sanity: result is non-empty and plausible (at least the Manhattan-1 neighbours
	# at PLAINS cost=10 must be reachable from budget=30).
	assert_int(result.size()).override_failure_message(
		("AC-6: get_movement_range must return more than just origin; got %d tiles")
		% result.size()
	).is_greater(1)

	# Confirm a known HILLS neighbour at (6,7) — one step west of origin (7,7),
	# also in the HILLS band (rows 5-9 inclusive). Step cost 15, reachable within budget=30.
	assert_bool(result_set.has(Vector2i(6, 7))).override_failure_message(
		("AC-6: tile (6,7) (HILLS, step=15) should be reachable from (7,7) "
		+ "with budget=30; missing from result")
	).is_true()

	# Confirm a HILLS tile at the exact cost-budget boundary IS reachable:
	# (5,7) is 2 steps west of (7,7): (7,7) → (6,7) HILLS=15 → (5,7) HILLS=15.
	# Cumulative=30=budget. Verifies Dijkstra correctly accumulates terrain costs
	# through the migrated TerrainCost.cost_multiplier delegate at the boundary.
	assert_bool(result_set.has(Vector2i(5, 7))).override_failure_message(
		("AC-6: tile (5,7) (HILLS, 2 steps at cost 15 each = 30 = budget) "
		+ "should be reachable; missing from result")
	).is_true()

	# Confirm a PLAINS tile beyond the HILLS band is correctly NOT reachable:
	# Origin (7,7) is in the HILLS band (rows 5-9). To reach (7,4) PLAINS requires
	# crossing 2 HILLS rows first: (7,7) → (7,6) HILLS=15 → (7,5) HILLS=30 (budget
	# exhausted) → (7,4) PLAINS would need +10 = 40 total, exceeding budget=30.
	# This negative assertion proves the HILLS band acts as a budget barrier — a
	# regression catching off-by-one in the migrated cost-multiplier delegate.
	assert_bool(result_set.has(Vector2i(7, 4))).override_failure_message(
		"AC-6: tile (7,4) (PLAINS beyond HILLS band, total cost 40) must NOT be "
		+ "reachable from (7,7) with budget=30; HILLS band must form a barrier"
	).is_false()

	# G-6 cleanup: MapGrid was Node.new()'d above; must be freed before test exit
	# to avoid GdUnit4 orphan detection between test body and after_test.
	grid.free()
