extends GdUnitTestSuite

## terrain_effect_queries_test.gd
## Unit tests for Story 004 (terrain-effect epic): get_terrain_modifiers() and
## get_terrain_score() — CR-1 table coverage, defensive copy contract, lazy-init
## idempotency, OOB zero-fill, EC-13 RIVER, AC-13 F-3 formula, and EC-5 signature.
##
## Covers AC-1 through AC-10 from story-004 §Acceptance Criteria.
##
## Governing ADR: ADR-0008 Terrain Effect System (Accepted 2026-04-25).
## Related TRs:   TR-terrain-effect-001, TR-terrain-effect-002,
##                TR-terrain-effect-008, TR-terrain-effect-016.
##
## ISOLATION DISCIPLINE (ADR-0008 §Risks line 562):
##   before_test() calls TerrainEffect.reset_for_tests() unconditionally so that
##   each test starts from pristine defaults regardless of prior state.
##   NOTE: must be `before_test()` (canonical GdUnit4 v6.1.2 hook); `before_each()` is
##   silently ignored by the runner (gotcha G-15).
##
## STATIC-VAR INSPECTION PATTERN:
##   Static vars are read/written via (load(PATH) as GDScript).get/set("_var") per the
##   save_migration_registry_test.gd precedent (established project pattern).
##
## GRID FIXTURE MINIMUM SIZE:
##   MapGrid.MAP_COLS_MIN == 15 and MAP_ROWS_MIN == 15. All fixtures use 15×15.
##   Forced deviation from the story spec's "1×1 fixture" wording — MapGrid's
##   column-minimum validation rejects sub-15 dimensions. The behaviour under test
##   (terrain_type lookup for a single tile) is identical; only the fixture footprint
##   changes. All tile positions outside (0, 0) are PLAINS/elevation=0 (neutral filler).
##
## GRID NODE LIFECYCLE:
##   Each test instantiates MapGrid via MapGrid.new(), calls load_map(), and frees
##   the node after assertions. Using free() (not queue_free()) so the node is
##   destroyed synchronously — GdUnit4's orphan detector fires between test body
##   exit and after_test(), so deferred deletion would register as orphans (G-6).

const TERRAIN_EFFECT_PATH: String = "res://src/core/terrain_effect.gd"


func before_test() -> void:
	TerrainEffect.reset_for_tests()


# ── Grid fixture factory ──────────────────────────────────────────────────────


## Builds a valid 15×15 MapResource suitable for load_map().
##
## The tile at [param special_col], [param special_row] is assigned
## [param terrain_type] and [param elevation].
## All other tiles are PLAINS (terrain_type=0, elevation=0, is_passable_base=true).
##
## Callers are responsible for freeing the returned MapGrid after use:
##   var grid := _make_grid(...)
##   # ... assertions ...
##   grid.free()
func _make_grid(
		special_col: int,
		special_row: int,
		terrain_type: int,
		elevation: int
) -> MapGrid:
	const COLS: int = 15
	const ROWS: int = 15
	var res := MapResource.new()
	res.map_id = &"test_fixture"
	res.map_rows = ROWS
	res.map_cols = COLS
	res.terrain_version = 1
	for row: int in ROWS:
		for col: int in COLS:
			var t := MapTileData.new()
			t.coord            = Vector2i(col, row)
			t.is_passable_base = true
			t.tile_state       = 0   # EMPTY
			t.occupant_id      = 0
			t.occupant_faction = 0
			t.is_destructible  = false
			t.destruction_hp   = 0
			if col == special_col and row == special_row:
				t.terrain_type = terrain_type
				t.elevation    = elevation
			else:
				t.terrain_type = TerrainEffect.PLAINS   # 0
				t.elevation    = 0
			res.tiles.append(t)
	var grid := MapGrid.new()
	var ok: bool = grid.load_map(res)
	assert_bool(ok).override_failure_message(
		("_make_grid: load_map failed — fixture invalid for terrain_type=%d elevation=%d;"
		+ " check ELEVATION_RANGES compliance") % [terrain_type, elevation]
	).is_true()
	return grid


# ── AC-1: HILLS returns canonical defense modifier ────────────────────────────


## AC-1 (GDD AC-1): HILLS tile returns defense_bonus=15, evasion_bonus=0,
## special_rules=[].
## Given: reset_for_tests(); 15×15 fixture with (0,0)=HILLS (terrain_type=2, elevation=1).
## When:  var m := TerrainEffect.get_terrain_modifiers(grid, Vector2i(0, 0)).
## Then:  m.defense_bonus==15, m.evasion_bonus==0, m.special_rules.size()==0.
func test_terrain_effect_queries_hills_returns_canonical_defense_modifier() -> void:
	# Arrange
	var grid: MapGrid = _make_grid(0, 0, TerrainEffect.HILLS, 1)

	# Act
	var m: TerrainModifiers = TerrainEffect.get_terrain_modifiers(grid, Vector2i(0, 0))

	# Assert
	assert_int(m.defense_bonus).override_failure_message(
		"AC-1: HILLS defense_bonus must be 15; got %d" % m.defense_bonus
	).is_equal(15)
	assert_int(m.evasion_bonus).override_failure_message(
		"AC-1: HILLS evasion_bonus must be 0; got %d" % m.evasion_bonus
	).is_equal(0)
	assert_int(m.special_rules.size()).override_failure_message(
		"AC-1: HILLS special_rules must be empty; size=%d" % m.special_rules.size()
	).is_equal(0)

	grid.free()


# ── AC-2: All 8 terrain types return canonical CR-1 values ───────────────────


## AC-2 (GDD AC-11): All 8 terrain types return the correct CR-1 table values.
## Uses a single 15×15 grid with 8 tiles placed in row 0, columns 0-7.
## Given: one 15×15 fixture covering all 8 terrain types in row 0.
## When:  get_terrain_modifiers called at each terrain tile.
## Then:  PLAINS 0/0/[]; FOREST 5/15/[]; HILLS 15/0/[]; MOUNTAIN 20/5/[];
##        RIVER 0/0/[]; BRIDGE 5/0/[&"bridge_no_flank"]; FORTRESS_WALL 25/0/[]; ROAD 0/0/[].
func test_terrain_effect_queries_all_eight_terrain_types_return_canonical_cr1_values() -> void:
	# Arrange: 15×15 grid, row 0 cols 0-7 carry the 8 terrain types.
	# Valid elevations per MapGrid.ELEVATION_RANGES:
	#   PLAINS(0)=0, FOREST(1)=0, HILLS(2)=1, MOUNTAIN(3)=2,
	#   RIVER(4)=0, BRIDGE(5)=0, FORTRESS_WALL(6)=1, ROAD(7)=0
	const COLS: int = 15
	const ROWS: int = 15
	var terrain_row_types: Array[int] = [
		TerrainEffect.PLAINS,        # col 0, elevation 0
		TerrainEffect.FOREST,        # col 1, elevation 0
		TerrainEffect.HILLS,         # col 2, elevation 1
		TerrainEffect.MOUNTAIN,      # col 3, elevation 2
		TerrainEffect.RIVER,         # col 4, elevation 0
		TerrainEffect.BRIDGE,        # col 5, elevation 0
		TerrainEffect.FORTRESS_WALL, # col 6, elevation 1
		TerrainEffect.ROAD           # col 7, elevation 0
	]
	# CR-3 valid elevation per terrain in the same order
	var terrain_row_elevations: Array[int] = [0, 0, 1, 2, 0, 0, 1, 0]

	var res := MapResource.new()
	res.map_id = &"test_all_terrains"
	res.map_rows = ROWS
	res.map_cols = COLS
	res.terrain_version = 1
	for row: int in ROWS:
		for col: int in COLS:
			var t := MapTileData.new()
			t.coord            = Vector2i(col, row)
			t.is_passable_base = true
			t.tile_state       = 0
			t.occupant_id      = 0
			t.occupant_faction = 0
			t.is_destructible  = false
			t.destruction_hp   = 0
			if row == 0 and col < terrain_row_types.size():
				t.terrain_type = terrain_row_types[col]
				t.elevation    = terrain_row_elevations[col]
			else:
				t.terrain_type = TerrainEffect.PLAINS
				t.elevation    = 0
			res.tiles.append(t)
	var grid := MapGrid.new()
	assert_bool(grid.load_map(res)).override_failure_message(
		"AC-2: load_map must succeed for 8-terrain fixture"
	).is_true()

	# Expected CR-1 values: [defense_bonus, evasion_bonus, special_rules_size]
	# BRIDGE special_rules must contain exactly &"bridge_no_flank" — checked separately.
	var expected: Array = [
		[0,  0,  0],   # PLAINS
		[5,  15, 0],   # FOREST
		[15, 0,  0],   # HILLS
		[20, 5,  0],   # MOUNTAIN
		[0,  0,  0],   # RIVER
		[5,  0,  1],   # BRIDGE — size 1 here; content checked below
		[25, 0,  0],   # FORTRESS_WALL
		[0,  0,  0],   # ROAD
	]
	var terrain_names: Array[String] = [
		"PLAINS", "FOREST", "HILLS", "MOUNTAIN", "RIVER", "BRIDGE", "FORTRESS_WALL", "ROAD"
	]

	for col: int in terrain_row_types.size():
		var m: TerrainModifiers = TerrainEffect.get_terrain_modifiers(
			grid, Vector2i(col, 0)
		)
		var name_str: String = terrain_names[col]
		var exp: Array = expected[col]
		assert_int(m.defense_bonus).override_failure_message(
			("AC-2: %s defense_bonus must be %d; got %d")
			% [name_str, exp[0], m.defense_bonus]
		).is_equal(exp[0] as int)
		assert_int(m.evasion_bonus).override_failure_message(
			("AC-2: %s evasion_bonus must be %d; got %d")
			% [name_str, exp[1], m.evasion_bonus]
		).is_equal(exp[1] as int)
		assert_int(m.special_rules.size()).override_failure_message(
			("AC-2: %s special_rules.size() must be %d; got %d")
			% [name_str, exp[2], m.special_rules.size()]
		).is_equal(exp[2] as int)

	# BRIDGE special_rules content: must contain exactly &"bridge_no_flank"
	var bridge_m: TerrainModifiers = TerrainEffect.get_terrain_modifiers(
		grid, Vector2i(5, 0)
	)
	assert_bool(bridge_m.special_rules.has(&"bridge_no_flank")).override_failure_message(
		"AC-2: BRIDGE special_rules must contain &\"bridge_no_flank\" (StringName, not String)"
	).is_true()
	# Type-identity check: GDScript's `==` and `has()` coerce StringName ↔ String,
	# so `has(&"bridge_no_flank")` would PASS even if the impl stored String "bridge_no_flank".
	# Explicit typeof check catches a String-vs-StringName regression that pure equality misses.
	assert_int(typeof(bridge_m.special_rules[0])).override_failure_message(
		("AC-2: BRIDGE special_rules[0] must be TYPE_STRING_NAME (got type %d);"
		+ " regression risk if impl ever returns String instead of StringName.")
		% typeof(bridge_m.special_rules[0])
	).is_equal(TYPE_STRING_NAME)

	grid.free()


# ── AC-3: OOB coord returns zero-fill modifiers ───────────────────────────────


## AC-3 (GDD AC-14): OOB coord returns zero-fill TerrainModifiers; no error/crash.
## Given: 15×15 fixture loaded.
## When:  get_terrain_modifiers called with (-1,-1) and (99,99) and null grid.
## Then:  all return defense_bonus=0, evasion_bonus=0, special_rules=[].
func test_terrain_effect_queries_oob_coord_returns_zero_fill_modifiers() -> void:
	# Arrange
	var grid: MapGrid = _make_grid(0, 0, TerrainEffect.PLAINS, 0)

	# Act + Assert: negative OOB
	var m_neg: TerrainModifiers = TerrainEffect.get_terrain_modifiers(
		grid, Vector2i(-1, -1)
	)
	assert_int(m_neg.defense_bonus).override_failure_message(
		"AC-3: (-1,-1) OOB defense_bonus must be 0; got %d" % m_neg.defense_bonus
	).is_equal(0)
	assert_int(m_neg.evasion_bonus).override_failure_message(
		"AC-3: (-1,-1) OOB evasion_bonus must be 0; got %d" % m_neg.evasion_bonus
	).is_equal(0)
	assert_int(m_neg.special_rules.size()).override_failure_message(
		"AC-3: (-1,-1) OOB special_rules must be empty"
	).is_equal(0)

	# Act + Assert: far positive OOB
	var m_far: TerrainModifiers = TerrainEffect.get_terrain_modifiers(
		grid, Vector2i(99, 99)
	)
	assert_int(m_far.defense_bonus).override_failure_message(
		"AC-3: (99,99) OOB defense_bonus must be 0; got %d" % m_far.defense_bonus
	).is_equal(0)
	assert_int(m_far.evasion_bonus).override_failure_message(
		"AC-3: (99,99) OOB evasion_bonus must be 0; got %d" % m_far.evasion_bonus
	).is_equal(0)
	assert_int(m_far.special_rules.size()).override_failure_message(
		"AC-3: (99,99) OOB special_rules must be empty; got size %d" % m_far.special_rules.size()
	).is_equal(0)

	# Act + Assert: get_terrain_score() must also zero-fill on OOB (parallels modifier path).
	# Score formula F-3 over zero-fill modifiers: (0 + 0 * 1.2) / 43.0 == 0.0.
	var score_oob: float = TerrainEffect.get_terrain_score(grid, Vector2i(-1, -1))
	assert_float(score_oob).override_failure_message(
		"AC-3: get_terrain_score(-1,-1) must return 0.0 (zero-fill modifiers → F-3 == 0); got %f"
		% score_oob
	).is_equal(0.0)

	# Act + Assert: null grid (defensive-only path; production never calls with null)
	var m_null: TerrainModifiers = TerrainEffect.get_terrain_modifiers(
		null, Vector2i(0, 0)
	)
	assert_int(m_null.defense_bonus).override_failure_message(
		"AC-3: null grid defense_bonus must be 0; got %d" % m_null.defense_bonus
	).is_equal(0)
	assert_int(m_null.evasion_bonus).override_failure_message(
		"AC-3: null grid evasion_bonus must be 0; got %d" % m_null.evasion_bonus
	).is_equal(0)
	assert_int(m_null.special_rules.size()).override_failure_message(
		"AC-3: null grid special_rules must be empty"
	).is_equal(0)

	grid.free()


# ── AC-4: RIVER tile query returns valid 0/0 modifiers (EC-13) ───────────────


## AC-4 (GDD EC-13): RIVER tile returns valid (0/0/[]) — no special-case error path.
## Modifier query and movement rule are independent concerns.
## Given: 15×15 fixture with (0,0)=RIVER (terrain_type=4, elevation=0).
## When:  get_terrain_modifiers(grid, Vector2i(0, 0)).
## Then:  defense_bonus==0, evasion_bonus==0, special_rules==[].
func test_terrain_effect_queries_river_returns_valid_zero_modifiers() -> void:
	# Arrange
	var grid: MapGrid = _make_grid(0, 0, TerrainEffect.RIVER, 0)

	# Act
	var m: TerrainModifiers = TerrainEffect.get_terrain_modifiers(grid, Vector2i(0, 0))

	# Assert
	assert_int(m.defense_bonus).override_failure_message(
		"AC-4 EC-13: RIVER defense_bonus must be 0; got %d" % m.defense_bonus
	).is_equal(0)
	assert_int(m.evasion_bonus).override_failure_message(
		"AC-4 EC-13: RIVER evasion_bonus must be 0; got %d" % m.evasion_bonus
	).is_equal(0)
	assert_int(m.special_rules.size()).override_failure_message(
		"AC-4 EC-13: RIVER special_rules must be empty; size=%d" % m.special_rules.size()
	).is_equal(0)

	grid.free()


# ── AC-5: CR-1d / TR-002 — no unit_type parameter in signatures ───────────────


## AC-5 (CR-1d / TR-002): Both query methods have no unit_type parameter.
## Structural verification — if the signature changes, this test fails to compile.
## Given: TerrainEffect source compiled.
## When:  get_terrain_modifiers and get_terrain_score called with (MapGrid, Vector2i) only.
## Then:  compilation succeeds; no extra parameters accepted (verified by calling with
##        exactly 2 arguments — extra args would cause an "unexpected argument" parse error).
func test_terrain_effect_queries_signatures_have_no_unit_type_parameter() -> void:
	# Arrange
	var grid: MapGrid = _make_grid(0, 0, TerrainEffect.PLAINS, 0)

	# Act — if signatures had extra required params, these calls would fail to compile
	var m: TerrainModifiers = TerrainEffect.get_terrain_modifiers(grid, Vector2i(0, 0))
	var s: float = TerrainEffect.get_terrain_score(grid, Vector2i(0, 0))

	# Assert — verify calls returned meaningful values (not just that they compiled)
	assert_object(m).override_failure_message(
		"AC-5 CR-1d: get_terrain_modifiers must return non-null with 2 args"
	).is_not_null()
	assert_float(s).override_failure_message(
		"AC-5 CR-1d: get_terrain_score must return a float with 2 args; got %f" % s
	).is_greater_equal(0.0)

	grid.free()


# ── AC-6: get_terrain_score F-3 formula verified for 4 terrain types ─────────


## AC-6 (GDD AC-13): get_terrain_score returns normalized [0.0, 1.0] per F-3 formula.
## F-3: score = (defense_bonus + evasion_bonus * evasion_weight) / max_possible_score
## Default config: evasion_weight=1.2, max_possible_score=43.0.
##
## Expected values:
##   FOREST        → (5 + 15*1.2) / 43.0 = 23/43 ≈ 0.53488
##   HILLS         → (15 + 0) / 43.0 ≈ 0.34884
##   PLAINS        → (0 + 0) / 43.0 = 0.0
##   FORTRESS_WALL → (25 + 0) / 43.0 ≈ 0.58140
func test_terrain_effect_queries_terrain_score_f3_formula_verified() -> void:
	# Arrange: one grid per terrain type (could be a single grid, but separate
	# grids make failures easier to diagnose — one failure per terrain type)
	var grid_forest: MapGrid       = _make_grid(0, 0, TerrainEffect.FOREST, 0)
	var grid_hills: MapGrid        = _make_grid(0, 0, TerrainEffect.HILLS, 1)
	var grid_plains: MapGrid       = _make_grid(0, 0, TerrainEffect.PLAINS, 0)
	var grid_fortress: MapGrid     = _make_grid(0, 0, TerrainEffect.FORTRESS_WALL, 1)

	# Act
	var score_forest: float   = TerrainEffect.get_terrain_score(grid_forest,   Vector2i(0, 0))
	var score_hills: float    = TerrainEffect.get_terrain_score(grid_hills,    Vector2i(0, 0))
	var score_plains: float   = TerrainEffect.get_terrain_score(grid_plains,   Vector2i(0, 0))
	var score_fortress: float = TerrainEffect.get_terrain_score(grid_fortress, Vector2i(0, 0))

	# Assert — tolerance 0.001 per story-004 spec
	assert_float(score_forest).override_failure_message(
		("AC-6 F-3: FOREST score must be ≈0.53488 (5+15*1.2)/43; got %f") % score_forest
	).is_equal_approx((5.0 + 15.0 * 1.2) / 43.0, 0.001)

	assert_float(score_hills).override_failure_message(
		("AC-6 F-3: HILLS score must be ≈0.34884 (15+0)/43; got %f") % score_hills
	).is_equal_approx(15.0 / 43.0, 0.001)

	assert_float(score_plains).override_failure_message(
		("AC-6 F-3: PLAINS score must be 0.0 (0+0)/43; got %f") % score_plains
	).is_equal_approx(0.0, 0.001)

	assert_float(score_fortress).override_failure_message(
		("AC-6 F-3: FORTRESS_WALL score must be ≈0.58140 (25+0)/43; got %f") % score_fortress
	).is_equal_approx(25.0 / 43.0, 0.001)

	# All scores in [0.0, 1.0]
	for score: float in [score_forest, score_hills, score_plains, score_fortress]:
		assert_float(score).override_failure_message(
			"AC-6 F-3: all scores must be >= 0.0; got %f" % score
		).is_greater_equal(0.0)
		assert_float(score).override_failure_message(
			"AC-6 F-3: all scores must be <= 1.0; got %f" % score
		).is_less_equal(1.0)

	grid_forest.free()
	grid_hills.free()
	grid_plains.free()
	grid_fortress.free()


# ── AC-7: EC-5 — get_terrain_score signature is elevation-agnostic ─────────────


## AC-7 (EC-5): get_terrain_score is elevation-agnostic.
## Structural verification: signature is (MapGrid, Vector2i) — no attacker_coord or
## elevation parameter. Callers must use get_combat_modifiers() for elevation-aware AI.
## Given: two grids with the same terrain_type at (0,0) but different elevations.
## When:  get_terrain_score called for each.
## Then:  both return the same score (elevation has no effect on this method).
func test_terrain_effect_queries_terrain_score_is_elevation_agnostic() -> void:
	# FORTRESS_WALL has valid elevations 1 and 2 — use those for the two grids.
	var grid_elev1: MapGrid = _make_grid(0, 0, TerrainEffect.FORTRESS_WALL, 1)
	var grid_elev2: MapGrid = _make_grid(0, 0, TerrainEffect.FORTRESS_WALL, 2)

	var score1: float = TerrainEffect.get_terrain_score(grid_elev1, Vector2i(0, 0))
	var score2: float = TerrainEffect.get_terrain_score(grid_elev2, Vector2i(0, 0))

	assert_float(score1).override_failure_message(
		("AC-7 EC-5: FORTRESS_WALL elevation=1 score must equal elevation=2 score;"
		+ " score1=%f score2=%f") % [score1, score2]
	).is_equal_approx(score2, 0.00001)

	grid_elev1.free()
	grid_elev2.free()


# ── AC-8: Defensive copy — caller mutation does not poison static state ────────


## AC-8 (ADR-0008 §Notes §5): Caller mutation of returned TerrainModifiers does
## NOT affect the static _terrain_table entry on subsequent calls.
## Given: reset_for_tests() + load_config(); BRIDGE tile at (0,0).
## When:  m := get_terrain_modifiers(bridge_grid, (0,0));
##        m.special_rules.append(&"caller_pollution");
##        m2 := get_terrain_modifiers(bridge_grid, (0,0)).
## Then:  m2.special_rules.size()==1 (only &"bridge_no_flank");
##        m.special_rules.size()==2 (caller's local copy was mutated, fine).
func test_terrain_effect_queries_defensive_copy_caller_mutation_does_not_poison_static_state() -> void:
	# Arrange
	var grid: MapGrid = _make_grid(0, 0, TerrainEffect.BRIDGE, 0)
	TerrainEffect.load_config()

	# Act — first call, mutate the returned copy
	var m: TerrainModifiers = TerrainEffect.get_terrain_modifiers(grid, Vector2i(0, 0))
	assert_int(m.special_rules.size()).override_failure_message(
		"AC-8 pre-mutation: BRIDGE special_rules must have 1 element; got %d"
		% m.special_rules.size()
	).is_equal(1)

	m.special_rules.append(&"caller_pollution")
	assert_int(m.special_rules.size()).override_failure_message(
		"AC-8 post-mutation: m.special_rules must have 2 elements after append; got %d"
		% m.special_rules.size()
	).is_equal(2)

	# Act — second call: must return fresh copy from unmodified static table
	var m2: TerrainModifiers = TerrainEffect.get_terrain_modifiers(grid, Vector2i(0, 0))

	# Assert — m2 unaffected by m's mutation (defensive copy contract)
	assert_int(m2.special_rules.size()).override_failure_message(
		("AC-8: m2.special_rules.size() must be 1 (only &\"bridge_no_flank\");"
		+ " got %d — static table was polluted by caller mutation (defensive copy broken)")
		% m2.special_rules.size()
	).is_equal(1)
	assert_bool(m2.special_rules.has(&"bridge_no_flank")).override_failure_message(
		"AC-8: m2.special_rules must contain &\"bridge_no_flank\""
	).is_true()

	grid.free()


# ── AC-9: Lazy-init — get_terrain_modifiers triggers load_config once ──────────


## AC-9 (ADR-0008 §Decision 1): get_terrain_modifiers lazy-triggers load_config
## on first call if _config_loaded is false; subsequent calls do NOT re-trigger
## (idempotent guard contract).
##
## Lazy-init assertion: call without prior load_config → _config_loaded becomes true.
## Idempotency assertion: mutate _max_defense_reduction to sentinel 99 via seam;
## second call must NOT overwrite it (would only happen if _apply_config re-ran).
##
## Given: reset_for_tests() (so _config_loaded==false).
## When:  get_terrain_modifiers called once.
## Then:  _config_loaded==true; HILLS returns defense_bonus==15.
## When:  _max_defense_reduction mutated to sentinel; get_terrain_modifiers called again.
## Then:  _max_defense_reduction==sentinel (idempotent guard short-circuits);
##        m2 still returns HILLS defense_bonus==15 (no logical degradation).
func test_terrain_effect_queries_lazy_init_triggers_load_config_once() -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript
	# Arrange: before_test() already called reset_for_tests(); _config_loaded==false
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"AC-9 pre-condition: _config_loaded must be false before first query"
	).is_false()

	var grid: MapGrid = _make_grid(0, 0, TerrainEffect.HILLS, 1)

	# Act — first call; must trigger lazy load_config()
	var m: TerrainModifiers = TerrainEffect.get_terrain_modifiers(grid, Vector2i(0, 0))

	# Assert — lazy load fired
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"AC-9: _config_loaded must be true after first get_terrain_modifiers call"
	).is_true()
	assert_int(m.defense_bonus).override_failure_message(
		"AC-9: HILLS defense_bonus must be 15 after lazy load; got %d" % m.defense_bonus
	).is_equal(15)

	# Strengthen: second call must short-circuit (idempotent guard).
	# Mutate _max_defense_reduction to a sentinel. If load_config() fires a second time,
	# _apply_config will overwrite the sentinel back to 30 (from production config).
	const SENTINEL_CAP: int = 99
	script.set("_max_defense_reduction", SENTINEL_CAP)
	var m2: TerrainModifiers = TerrainEffect.get_terrain_modifiers(grid, Vector2i(0, 0))
	assert_int(script.get("_max_defense_reduction") as int).override_failure_message(
		("AC-9 idempotency: second get_terrain_modifiers call must NOT re-trigger load_config"
		+ " (sentinel %d preserved); got %d") % [SENTINEL_CAP, script.get("_max_defense_reduction") as int]
	).is_equal(SENTINEL_CAP)
	# m2 still returns valid modifiers (no logical degradation from the cap mutation)
	assert_int(m2.defense_bonus).override_failure_message(
		"AC-9 idempotency: m2 must still return HILLS defense_bonus=15"
	).is_equal(15)

	grid.free()


# ── AC-10: Lazy-init — get_terrain_score triggers load_config once ─────────────


## AC-10 (ADR-0008 §Decision 1): get_terrain_score also lazy-triggers load_config
## on first call. Independent lazy entry point — neither method assumes the other
## was called first.
##
## Idempotency assertion mirrors AC-9: _max_defense_reduction sentinel must be
## preserved on the second call. _max_defense_reduction is the correct sentinel
## here because it does NOT appear in F-3 (score = (def + eva*w)/max_score) —
## mutating it leaves the score computation unchanged. (_evasion_weight and
## _max_possible_score DO appear in F-3 and must NOT be used as sentinels here.)
##
## Given: reset_for_tests() (so _config_loaded==false).
## When:  get_terrain_score called once.
## Then:  _config_loaded==true; HILLS score ≈ 0.34884.
## When:  _max_defense_reduction mutated to sentinel; get_terrain_score called again.
## Then:  _max_defense_reduction==sentinel; score2==score (deterministic, cap unused in F-3).
func test_terrain_effect_queries_lazy_init_score_triggers_load_config_once() -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript
	# Arrange: _config_loaded==false (reset by before_test())
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"AC-10 pre-condition: _config_loaded must be false before first query"
	).is_false()

	var grid: MapGrid = _make_grid(0, 0, TerrainEffect.HILLS, 1)

	# Act — first call; must trigger lazy load_config()
	var score: float = TerrainEffect.get_terrain_score(grid, Vector2i(0, 0))

	# Assert — lazy load fired
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"AC-10: _config_loaded must be true after first get_terrain_score call"
	).is_true()
	assert_float(score).override_failure_message(
		("AC-10: HILLS score must be ≈0.34884 (15/43.0) after lazy load; got %f") % score
	).is_equal_approx(15.0 / 43.0, 0.001)

	# Strengthen: second call must short-circuit (idempotent guard).
	# _max_defense_reduction is safe as sentinel: it is NOT in F-3 formula, so
	# mutating it does not affect score. If load_config() re-fires, _apply_config
	# overwrites sentinel back to 30 — proving the guard is bypassed.
	const SENTINEL_CAP: int = 99
	script.set("_max_defense_reduction", SENTINEL_CAP)
	var score2: float = TerrainEffect.get_terrain_score(grid, Vector2i(0, 0))
	assert_int(script.get("_max_defense_reduction") as int).override_failure_message(
		("AC-10 idempotency: second get_terrain_score call must NOT re-trigger load_config"
		+ " (sentinel %d preserved); got %d") % [SENTINEL_CAP, script.get("_max_defense_reduction") as int]
	).is_equal(SENTINEL_CAP)
	# score2 still equals score (deterministic regardless of cap mutation, since cap is unused in F-3)
	assert_float(score2).override_failure_message(
		"AC-10 idempotency: second call's score must equal first call's score (deterministic)"
	).is_equal(score)

	grid.free()
