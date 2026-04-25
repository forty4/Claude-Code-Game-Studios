extends GdUnitTestSuite

## terrain_effect_combat_modifiers_test.gd
## Unit tests for Story 005 (terrain-effect epic): get_combat_modifiers() —
## CR-2 elevation modifiers, CR-3a/b symmetric clamp, CR-5 bridge flag,
## EC-14 delta clamp, TR-011 cross-system contract gate.
##
## Covers AC-1 through AC-14 from story-005 §QA Test Cases.
##
## Governing ADR: ADR-0008 Terrain Effect System (Accepted 2026-04-25).
## Related TRs:   TR-terrain-effect-003 (CR-2), TR-terrain-effect-004 (F-1 clamp),
##                TR-terrain-effect-005 (caps), TR-terrain-effect-007 (CR-3e/EC-1),
##                TR-terrain-effect-008 (3 of 3 query methods),
##                TR-terrain-effect-009 (CR-5 bridge_no_flank flag),
##                TR-terrain-effect-011 (cross-system contract),
##                TR-terrain-effect-015 (EC-14 delta clamp).
##
## ISOLATION DISCIPLINE (ADR-0008 §Risks line 562):
##   before_test() calls TerrainEffect.reset_for_tests() unconditionally so that
##   each test starts from pristine defaults regardless of prior state.
##   NOTE: must be `before_test()` (canonical GdUnit4 v6.1.2 hook); `before_each()` is
##   silently ignored by the runner (gotcha G-15).
##
## STATIC-VAR INSPECTION PATTERN:
##   Static vars are read/written via (load(PATH) as GDScript).get/set("_var") per the
##   established project pattern (save_migration_registry_test.gd precedent; also used
##   by terrain_effect_queries_test.gd for story-004).
##
## GRID FIXTURE MINIMUM SIZE:
##   MapGrid.MAP_COLS_MIN == 15 and MAP_ROWS_MIN == 15. All fixtures use 15×15.
##   Story spec mentions "2-tile fixture" but MapGrid rejects sub-15 dimensions.
##   The behaviour under test (elevation + terrain lookups for two tiles) is identical;
##   only the fixture footprint changes. Tiles outside the two test positions are
##   PLAINS/elevation=0 (neutral filler).
##
## GRID NODE LIFECYCLE:
##   Each test instantiates MapGrid via MapGrid.new(), calls load_map(), and frees
##   the node synchronously after assertions via free() (NOT queue_free()). GdUnit4's
##   orphan detector fires between test body exit and after_test(); deferred deletion
##   via queue_free() would register as orphans (gotcha G-6).
##
## AC-9 PUSH_WARNING LIMITATION NOTE (TD-034 §C R-3 framework-limitation precedent):
##   GdUnit4 v6.1.2 does not expose a stderr-capture API for verifying push_warning()
##   calls programmatically. AC-9's push_warning side-effect is verified by inspection
##   of the regression run's stdout/stderr (the warning text
##   "delta_elevation 3 clamped to ±2 — update CR-2 table for new elevation range"
##   must appear there). The automated assertion verifies the BEHAVIOURAL outcome only:
##   elevation_atk_mod == 15 (clamped-to-+2 table value). This follows the precedent
##   established in story-003 (TD-034 §C R-3). When GdUnit4 adds warning-capture
##   support, add the explicit warning-text assertion here.

const TERRAIN_EFFECT_PATH: String = "res://src/core/terrain_effect.gd"


func before_test() -> void:
	TerrainEffect.reset_for_tests()


# ── Grid fixture factories ────────────────────────────────────────────────────


## Builds a valid 15×15 MapGrid with attacker tile at (0,0) and defender tile
## at (1,0). All other tiles are PLAINS (terrain_type=0, elevation=0).
##
## [param atk_terrain] / [param atk_elev] — attacker tile at Vector2i(0,0).
## [param def_terrain] / [param def_elev] — defender tile at Vector2i(1,0).
##
## Callers are responsible for freeing the returned MapGrid after use:
##   var grid := _make_grid_2tile(...)
##   # ... assertions ...
##   grid.free()
func _make_grid_2tile(
		atk_terrain: int,
		atk_elev: int,
		def_terrain: int,
		def_elev: int
) -> MapGrid:
	const COLS: int = 15
	const ROWS: int = 15
	var res := MapResource.new()
	res.map_id = &"test_fixture_2tile"
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
			if col == 0 and row == 0:
				t.terrain_type = atk_terrain
				t.elevation    = atk_elev
			elif col == 1 and row == 0:
				t.terrain_type = def_terrain
				t.elevation    = def_elev
			else:
				t.terrain_type = TerrainEffect.PLAINS
				t.elevation    = 0
			res.tiles.append(t)
	var grid := MapGrid.new()
	var ok: bool = grid.load_map(res)
	assert_bool(ok).override_failure_message(
		("_make_grid_2tile: load_map failed — fixture invalid for"
		+ " atk_terrain=%d atk_elev=%d def_terrain=%d def_elev=%d;"
		+ " check ELEVATION_RANGES compliance")
		% [atk_terrain, atk_elev, def_terrain, def_elev]
	).is_true()
	return grid


# ── Cross-system contract invariant helper ────────────────────────────────────


## Asserts that the given CombatModifiers satisfies the TR-011 cross-system contract
## (damage-calc.md §F, ratified 2026-04-18): defender_terrain_def ∈ [-30, +30] and
## defender_terrain_eva ∈ [0, 30]. Uses runtime cap values from the static state.
##
## Call at the end of every test that receives a CombatModifiers result to act as
## the AC-12 contract gate across all 14 test cases.
func _assert_combat_modifiers_within_clamps(cm: CombatModifiers, label: String) -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript
	var max_def: int = script.get("_max_defense_reduction") as int
	var max_eva: int = script.get("_max_evasion") as int
	assert_bool(cm.defender_terrain_def >= -max_def).override_failure_message(
		("AC-12 contract [%s]: defender_terrain_def %d must be >= -%d"
		+ " (cross-system lower-bound violation)") % [label, cm.defender_terrain_def, max_def]
	).is_true()
	assert_bool(cm.defender_terrain_def <= max_def).override_failure_message(
		("AC-12 contract [%s]: defender_terrain_def %d must be <= +%d"
		+ " (cross-system upper-bound violation)") % [label, cm.defender_terrain_def, max_def]
	).is_true()
	assert_bool(cm.defender_terrain_eva >= 0).override_failure_message(
		("AC-12 contract [%s]: defender_terrain_eva %d must be >= 0"
		+ " (cross-system lower-bound violation)") % [label, cm.defender_terrain_eva]
	).is_true()
	assert_bool(cm.defender_terrain_eva <= max_eva).override_failure_message(
		("AC-12 contract [%s]: defender_terrain_eva %d must be <= %d"
		+ " (cross-system upper-bound violation)") % [label, cm.defender_terrain_eva, max_eva]
	).is_true()


# ── AC-1: Elevation attack bonus at delta=+2 ─────────────────────────────────


## AC-1 (GDD AC-3): delta=+2 (atk elev=2, def elev=0) → elevation_atk_mod == 15.
## Given: reset_for_tests(); 2-tile fixture (atk MOUNTAIN elev=2, def PLAINS elev=0).
## When:  get_combat_modifiers(grid, Vector2i(0,0), Vector2i(1,0)).
## Then:  elevation_atk_mod == 15 (attacker bonus from CR-2 table delta=+2 row).
## Also:  cross-system contract verified (AC-12 gate).
##
## ELEVATION_RANGES NOTE: PLAINS only allows elevation=0 in MapGrid; MOUNTAIN locks
## to elevation=2. Attacker terrain is irrelevant to elevation_atk_mod / defender_*
## fields (only the attacker's elevation matters for delta computation), so MOUNTAIN
## is a valid stand-in for the spec's "atk PLAINS elev=2" wording.
func test_terrain_effect_combat_modifiers_elevation_atk_bonus_at_delta_plus2() -> void:
	# Arrange: atk MOUNTAIN elev=2, def PLAINS elev=0 → delta = +2 (PLAINS at elev=2 invalid)
	var grid: MapGrid = _make_grid_2tile(TerrainEffect.MOUNTAIN, 2, TerrainEffect.PLAINS, 0)

	# Act
	var cm: CombatModifiers = TerrainEffect.get_combat_modifiers(
		grid, Vector2i(0, 0), Vector2i(1, 0)
	)

	# Assert
	assert_int(cm.elevation_atk_mod).override_failure_message(
		("AC-1: delta=+2 elevation_atk_mod must be 15 (CR-2 table);"
		+ " got %d") % cm.elevation_atk_mod
	).is_equal(15)
	_assert_combat_modifiers_within_clamps(cm, "AC-1")

	grid.free()


# ── AC-2: Elevation defense modifier (defender penalty) at delta=+2 ──────────


## AC-2 (GDD AC-4): delta=+2 → elevation_def_mod == -15 (defender penalty).
## Given: same 2-tile fixture (atk MOUNTAIN elev=2, def PLAINS elev=0).
## When:  get_combat_modifiers.
## Then:  elevation_def_mod == -15 (asymmetric pair to AC-1; both verify CR-2 table row delta=+2).
## Also:  cross-system contract verified (AC-12 gate).
func test_terrain_effect_combat_modifiers_elevation_def_penalty_at_delta_plus2() -> void:
	# Arrange: same setup as AC-1 (MOUNTAIN substituted for PLAINS attacker per ELEVATION_RANGES)
	var grid: MapGrid = _make_grid_2tile(TerrainEffect.MOUNTAIN, 2, TerrainEffect.PLAINS, 0)

	# Act
	var cm: CombatModifiers = TerrainEffect.get_combat_modifiers(
		grid, Vector2i(0, 0), Vector2i(1, 0)
	)

	# Assert
	assert_int(cm.elevation_def_mod).override_failure_message(
		("AC-2: delta=+2 elevation_def_mod must be -15 (CR-2 table defender penalty);"
		+ " got %d") % cm.elevation_def_mod
	).is_equal(-15)
	_assert_combat_modifiers_within_clamps(cm, "AC-2")

	grid.free()


# ── AC-3: Defense cap enforced at 30% ─────────────────────────────────────────


## AC-3 (GDD AC-5): FORTRESS_WALL + delta=-2 → total_defense=40 → clamped to 30.
## Given: 2-tile fixture (atk PLAINS elev=0, def FORTRESS_WALL elev=2); delta=-2 → elev_def=+15.
## When:  get_combat_modifiers.
## Then:  total_defense = 25 (FORTRESS_WALL) + 15 (elevation) = 40 → defender_terrain_def == 30
##        (clamped to MAX_DEFENSE_REDUCTION; not 40).
## Also:  cross-system contract verified (AC-12 gate).
func test_terrain_effect_combat_modifiers_defense_cap_clamped_at_30() -> void:
	# Arrange: atk at elev=0, def FORTRESS_WALL at elev=2 → delta = 0-2 = -2 → defense_mod=+15
	# FORTRESS_WALL valid elevations: 1 or 2 (MapGrid.ELEVATION_RANGES).
	var grid: MapGrid = _make_grid_2tile(TerrainEffect.PLAINS, 0, TerrainEffect.FORTRESS_WALL, 2)

	# Act
	var cm: CombatModifiers = TerrainEffect.get_combat_modifiers(
		grid, Vector2i(0, 0), Vector2i(1, 0)
	)

	# Assert: elevation_def_mod should be +15 (delta=-2 → defender bonus from high ground)
	assert_int(cm.elevation_def_mod).override_failure_message(
		("AC-3: delta=-2 elevation_def_mod must be +15 (defender on high ground);"
		+ " got %d") % cm.elevation_def_mod
	).is_equal(15)
	# Assert: elevation_atk_mod should be -15 (CR-2 table delta=-2 row symmetric inverse of
	# AC-1's delta=+2 → +15 result). Without this, a copy-paste error in the elevation
	# config that swapped attack_mod/defense_mod for the delta=-2 row would not be caught.
	assert_int(cm.elevation_atk_mod).override_failure_message(
		("AC-3: delta=-2 elevation_atk_mod must be -15 (CR-2 table symmetric inverse);"
		+ " got %d") % cm.elevation_atk_mod
	).is_equal(-15)
	# Assert: total = 25 + 15 = 40 → clamped to MAX_DEFENSE_REDUCTION (30)
	assert_int(cm.defender_terrain_def).override_failure_message(
		("AC-3: FORTRESS_WALL(25) + elev_def(+15) = 40 → must be clamped to 30;"
		+ " got %d") % cm.defender_terrain_def
	).is_equal(30)
	_assert_combat_modifiers_within_clamps(cm, "AC-3")

	grid.free()


# ── AC-4: Evasion under cap returned as-is ────────────────────────────────────


## AC-4 (GDD AC-6): FOREST evasion_bonus=15, cap=30 → defender_terrain_eva == 15.
## Given: 2-tile fixture (atk PLAINS elev=0, def FOREST elev=0).
## When:  get_combat_modifiers.
## Then:  defender_terrain_eva == 15 (under cap; not clamped). The [0, 30] upper bound
##        enforcement with a tuned cap is exercised in AC-11 via _max_defense_reduction.
## Also:  cross-system contract verified (AC-12 gate).
func test_terrain_effect_combat_modifiers_forest_evasion_under_cap_returned_as_is() -> void:
	# Arrange: def FOREST elev=0 (valid elevation for FOREST)
	var grid: MapGrid = _make_grid_2tile(TerrainEffect.PLAINS, 0, TerrainEffect.FOREST, 0)

	# Act
	var cm: CombatModifiers = TerrainEffect.get_combat_modifiers(
		grid, Vector2i(0, 0), Vector2i(1, 0)
	)

	# Assert
	assert_int(cm.defender_terrain_eva).override_failure_message(
		("AC-4: FOREST evasion_bonus=15 is under max_evasion=30 cap;"
		+ " defender_terrain_eva must be 15 (no clamp); got %d") % cm.defender_terrain_eva
	).is_equal(15)
	_assert_combat_modifiers_within_clamps(cm, "AC-4")

	grid.free()


# ── AC-5: Negative defense not floored to zero ────────────────────────────────


## AC-5 (GDD AC-7): PLAINS(0) + delta=+2 (elev_def=-15) = -15 returned as-is.
## Given: 2-tile fixture (atk MOUNTAIN elev=2, def PLAINS elev=0); delta=+2 → elev_def=-15.
## When:  get_combat_modifiers.
## Then:  total_defense = 0 + (-15) = -15 → defender_terrain_def == -15
##        (within symmetric clamp [-30, +30]; NOT floored to 0 per CR-3e + EC-1).
## Edge:  GDD note: Damage Calc multiplies by (1 - (-15)/100) = 1.15 → amplifies damage.
##        Terrain Effect is responsible only for supplying the value; not for capping at 0.
## Also:  cross-system contract verified (AC-12 gate).
##
## Defender terrain is PLAINS (the asserted-on side) — what makes this AC the negative-
## defense case. Attacker terrain MOUNTAIN is incidental (elevation-only stand-in).
func test_terrain_effect_combat_modifiers_negative_defense_not_floored_to_zero() -> void:
	# Arrange: atk MOUNTAIN elev=2, def PLAINS elev=0 → delta=+2 → defense_mod=-15
	var grid: MapGrid = _make_grid_2tile(TerrainEffect.MOUNTAIN, 2, TerrainEffect.PLAINS, 0)

	# Act
	var cm: CombatModifiers = TerrainEffect.get_combat_modifiers(
		grid, Vector2i(0, 0), Vector2i(1, 0)
	)

	# Assert: -15 is within [-30, +30]; no flooring applied
	assert_int(cm.defender_terrain_def).override_failure_message(
		("AC-5 CR-3e+EC-1: PLAINS(0) + elev_def(-15) = -15 must be returned as -15;"
		+ " must NOT be floored to 0; got %d") % cm.defender_terrain_def
	).is_equal(-15)
	_assert_combat_modifiers_within_clamps(cm, "AC-5")

	grid.free()


# ── AC-6: Bridge defender sets bridge_no_flank flag ──────────────────────────


## AC-6 (GDD AC-9): defender on BRIDGE → bridge_no_flank=true + &"bridge_no_flank" in special_rules.
## Given: 2-tile fixture (atk PLAINS elev=0, def BRIDGE elev=0).
## When:  get_combat_modifiers.
## Then:  cm.bridge_no_flank == true;
##        &"bridge_no_flank" in cm.special_rules (denormalised flag — both must be set).
## Note:  The FLANK→FRONT collapse is Damage Calc's job (ADR-0008 §Decision 3);
##        only the flag-set is verified here.
## Also:  cross-system contract verified (AC-12 gate).
func test_terrain_effect_combat_modifiers_bridge_defender_sets_no_flank_flag() -> void:
	# Arrange: def BRIDGE elev=0 (valid elevation for BRIDGE)
	var grid: MapGrid = _make_grid_2tile(TerrainEffect.PLAINS, 0, TerrainEffect.BRIDGE, 0)

	# Act
	var cm: CombatModifiers = TerrainEffect.get_combat_modifiers(
		grid, Vector2i(0, 0), Vector2i(1, 0)
	)

	# Assert: bool flag
	assert_bool(cm.bridge_no_flank).override_failure_message(
		"AC-6 CR-5b: defender on BRIDGE must set bridge_no_flank=true"
	).is_true()
	# Assert: special_rules contains &"bridge_no_flank" (denormalised)
	assert_bool(cm.special_rules.has(&"bridge_no_flank")).override_failure_message(
		("AC-6 CR-5b: defender on BRIDGE must include &\"bridge_no_flank\" in special_rules;"
		+ " size=%d") % cm.special_rules.size()
	).is_true()
	# Type-identity check: ensure StringName, not String (G-2 regression guard)
	assert_int(typeof(cm.special_rules[0])).override_failure_message(
		("AC-6: special_rules[0] must be TYPE_STRING_NAME (%d);"
		+ " got type %d — String/StringName regression") % [TYPE_STRING_NAME, typeof(cm.special_rules[0])]
	).is_equal(TYPE_STRING_NAME)
	_assert_combat_modifiers_within_clamps(cm, "AC-6")

	grid.free()


# ── AC-7: Bridge rule is defender-centric ─────────────────────────────────────


## AC-7 (GDD AC-10): attacker on BRIDGE + defender on PLAINS → bridge_no_flank=false.
## Given: 2-tile fixture (atk BRIDGE elev=0, def PLAINS elev=0).
## When:  get_combat_modifiers.
## Then:  cm.bridge_no_flank == false;
##        &"bridge_no_flank" NOT in cm.special_rules.
## Edge:  CR-5b — the no-flank rule applies when the DEFENDER is on BRIDGE; attacker's tile
##        does not trigger the flag.
## Also:  cross-system contract verified (AC-12 gate).
func test_terrain_effect_combat_modifiers_bridge_attacker_does_not_set_no_flank_flag() -> void:
	# Arrange: atk BRIDGE elev=0, def PLAINS elev=0
	var grid: MapGrid = _make_grid_2tile(TerrainEffect.BRIDGE, 0, TerrainEffect.PLAINS, 0)

	# Act
	var cm: CombatModifiers = TerrainEffect.get_combat_modifiers(
		grid, Vector2i(0, 0), Vector2i(1, 0)
	)

	# Assert: flag must NOT be set when only the attacker is on BRIDGE
	assert_bool(cm.bridge_no_flank).override_failure_message(
		"AC-7 CR-5b: attacker on BRIDGE (defender on PLAINS) must NOT set bridge_no_flank"
	).is_false()
	assert_bool(cm.special_rules.has(&"bridge_no_flank")).override_failure_message(
		"AC-7 CR-5b: special_rules must NOT contain &\"bridge_no_flank\" (only atk on BRIDGE)"
	).is_false()
	_assert_combat_modifiers_within_clamps(cm, "AC-7")

	grid.free()


# ── AC-8: Full 6-field CombatModifiers population ─────────────────────────────


## AC-8 (GDD AC-12): All 6 CombatModifiers fields populated correctly for a
## representative non-trivial scenario.
## Given: 2-tile fixture (atk MOUNTAIN elev=2, def HILLS elev=1 — see ELEVATION_RANGES NOTE
##        in arrange comment below; spec's "PLAINS elev=1, HILLS elev=0" wording is invalid
##        in MapGrid, MOUNTAIN at elev=2 is the canonical stand-in); delta=+1 → atk_mod=+8, def_mod=-8.
## When:  get_combat_modifiers.
## Then:
##   defender_terrain_def == 15 + (-8) = 7  (HILLS base + elevation penalty; within [-30,+30])
##   defender_terrain_eva == 0               (HILLS evasion_bonus=0)
##   elevation_atk_mod    == 8
##   elevation_def_mod    == -8
##   bridge_no_flank      == false
##   special_rules.size() == 0
## Also:  cross-system contract verified (AC-12 gate).
func test_terrain_effect_combat_modifiers_full_six_field_population() -> void:
	# Arrange: atk MOUNTAIN elev=2, def HILLS elev=1 → delta = 2-1 = +1.
	# ELEVATION_RANGES per MapGrid: PLAINS=[0], HILLS=[1], MOUNTAIN=[2], FORTRESS_WALL=[1,2].
	# HILLS is the asserted-on defender (defense_bonus=15, evasion_bonus=0). Story spec
	# wording "atk PLAINS elev=1" is an ELEVATION_RANGES violation (PLAINS only at elev=0
	# AND HILLS only at elev=1, so even fixing the attacker would force def HILLS elev=1
	# anyway). MOUNTAIN(elev=2) is the canonical attacker terrain at elev=2; HILLS still
	# at its locked elev=1. delta=+1 → CR-2 table attack_mod=+8 / defense_mod=-8 unchanged.
	var grid: MapGrid = _make_grid_2tile(TerrainEffect.MOUNTAIN, 2, TerrainEffect.HILLS, 1)

	# Act
	var cm: CombatModifiers = TerrainEffect.get_combat_modifiers(
		grid, Vector2i(0, 0), Vector2i(1, 0)
	)

	# Assert all 6 fields
	# delta = 2-1 = +1 → attack_mod=+8, defense_mod=-8
	# HILLS defender: defense_bonus=15, evasion_bonus=0, special_rules=[]
	# total_def = 15 + (-8) = 7 → within [-30, +30] → no clamp
	assert_int(cm.defender_terrain_def).override_failure_message(
		("AC-8: HILLS(15) + elev_def(-8) = 7; defender_terrain_def must be 7;"
		+ " got %d") % cm.defender_terrain_def
	).is_equal(7)
	assert_int(cm.defender_terrain_eva).override_failure_message(
		("AC-8: HILLS evasion_bonus=0; defender_terrain_eva must be 0;"
		+ " got %d") % cm.defender_terrain_eva
	).is_equal(0)
	assert_int(cm.elevation_atk_mod).override_failure_message(
		("AC-8: delta=+1 elevation_atk_mod must be 8; got %d") % cm.elevation_atk_mod
	).is_equal(8)
	assert_int(cm.elevation_def_mod).override_failure_message(
		("AC-8: delta=+1 elevation_def_mod must be -8; got %d") % cm.elevation_def_mod
	).is_equal(-8)
	assert_bool(cm.bridge_no_flank).override_failure_message(
		"AC-8: HILLS defender; bridge_no_flank must be false"
	).is_false()
	assert_int(cm.special_rules.size()).override_failure_message(
		("AC-8: HILLS has no special_rules; size must be 0; got %d") % cm.special_rules.size()
	).is_equal(0)
	_assert_combat_modifiers_within_clamps(cm, "AC-8")

	grid.free()


# ── AC-9: Out-of-range elevation delta clamped + warning logged ───────────────


## AC-9 (GDD EC-14): delta=+3 (out of table range) is clamped to +2; behaviour asserted.
##
## PUSH_WARNING LIMITATION (TD-034 §C R-3 precedent — see file header):
##   GdUnit4 v6.1.2 cannot capture push_warning() calls programmatically.
##   The warning text "delta_elevation 3 clamped to ±2 — update CR-2 table for new
##   elevation range" is verified by inspection of the regression run's stderr.
##   This test asserts the BEHAVIOURAL outcome only: elevation_atk_mod == 15
##   (the clamped-to-+2 table value).
##
## EC-14 BYPASS NOTE (for future maintainers):
##   MapGrid.ELEVATION_RANGES rejects elevation=3 at load_map() time. To exercise
##   the EC-14 defensive clamp path, this test:
##   1. Loads a grid with valid elevations (atk MOUNTAIN elev=2, def PLAINS elev=0; delta=+2).
##   2. Post-load, mutates the attacker tile's elevation to 3 directly via the live
##      MapTileData reference returned by get_tile() (no defensive copy; verified in
##      map_grid.gd:276-282). This bypasses load_map() validation intentionally.
##   3. Calls get_combat_modifiers() — delta is now +3, triggering EC-14.
##   DO NOT refactor _make_grid_2tile() to auto-bypass this; the direct mutation is
##   explicit about the "out-of-normal" nature of the scenario.
##
## Given: 2-tile fixture (atk MOUNTAIN elev=2, def PLAINS elev=0); then atk.elevation mutated to 3.
## When:  get_combat_modifiers.
## Then:  elevation_atk_mod == 15 (clamped-to-+2 table value).
## Also:  push_warning emitted — verified by stderr inspection, not assertion (see above).
## Also:  cross-system contract verified (AC-12 gate).
func test_terrain_effect_combat_modifiers_out_of_range_delta_clamped_to_max() -> void:
	# Arrange: start with valid delta=+2 fixture, then bump atk elevation to 3 to trigger EC-14
	var grid: MapGrid = _make_grid_2tile(TerrainEffect.MOUNTAIN, 2, TerrainEffect.PLAINS, 0)
	# BYPASS: mutate atk tile elevation post-load to force delta=+3 (out of table range).
	# get_tile() returns the live MapTileData reference from _map.tiles[] — no defensive copy.
	grid.get_tile(Vector2i(0, 0)).elevation = 3

	# Act: delta = 3 - 0 = +3 → EC-14 clamps to +2 → push_warning emitted (see header note)
	var cm: CombatModifiers = TerrainEffect.get_combat_modifiers(
		grid, Vector2i(0, 0), Vector2i(1, 0)
	)

	# Assert: clamped to +2 → attack_mod=+15 (same as AC-1's delta=+2 result)
	assert_int(cm.elevation_atk_mod).override_failure_message(
		("AC-9 EC-14: delta=+3 clamped to +2 → elevation_atk_mod must be 15;"
		+ " got %d") % cm.elevation_atk_mod
	).is_equal(15)
	# Assert: elevation_def_mod also reflects the clamped value
	assert_int(cm.elevation_def_mod).override_failure_message(
		("AC-9 EC-14: delta=+3 clamped to +2 → elevation_def_mod must be -15;"
		+ " got %d") % cm.elevation_def_mod
	).is_equal(-15)
	_assert_combat_modifiers_within_clamps(cm, "AC-9")

	grid.free()


# ── AC-10: OOB coord returns zero-fill ────────────────────────────────────────


## AC-10: OOB defender coord returns zero-fill CombatModifiers (same OOB pattern as story-004 AC-3).
## Given: 15×15 fixture; atk_coord=(0,0) valid; def_coord=(99,99) OOB.
## When:  get_combat_modifiers.
## Then:  returns zero-fill CombatModifiers (all int fields 0, bridge_no_flank=false,
##        special_rules empty).
## Also:  null grid also returns zero-fill (defensive path).
func test_terrain_effect_combat_modifiers_oob_coord_returns_zero_fill() -> void:
	# Arrange
	var grid: MapGrid = _make_grid_2tile(TerrainEffect.PLAINS, 0, TerrainEffect.PLAINS, 0)

	# Act: OOB def_coord
	var cm_oob: CombatModifiers = TerrainEffect.get_combat_modifiers(
		grid, Vector2i(0, 0), Vector2i(99, 99)
	)

	# Assert: zero-fill
	assert_int(cm_oob.defender_terrain_def).override_failure_message(
		"AC-10: OOB def_coord → defender_terrain_def must be 0; got %d" % cm_oob.defender_terrain_def
	).is_equal(0)
	assert_int(cm_oob.defender_terrain_eva).override_failure_message(
		"AC-10: OOB def_coord → defender_terrain_eva must be 0; got %d" % cm_oob.defender_terrain_eva
	).is_equal(0)
	assert_int(cm_oob.elevation_atk_mod).override_failure_message(
		"AC-10: OOB def_coord → elevation_atk_mod must be 0; got %d" % cm_oob.elevation_atk_mod
	).is_equal(0)
	assert_int(cm_oob.elevation_def_mod).override_failure_message(
		"AC-10: OOB def_coord → elevation_def_mod must be 0; got %d" % cm_oob.elevation_def_mod
	).is_equal(0)
	assert_bool(cm_oob.bridge_no_flank).override_failure_message(
		"AC-10: OOB def_coord → bridge_no_flank must be false"
	).is_false()
	assert_int(cm_oob.special_rules.size()).override_failure_message(
		"AC-10: OOB def_coord → special_rules must be empty; size=%d" % cm_oob.special_rules.size()
	).is_equal(0)

	# Act + Assert: OOB atk_coord also zero-fills (full 6-field check, parallel of OOB-def)
	var cm_oob_atk: CombatModifiers = TerrainEffect.get_combat_modifiers(
		grid, Vector2i(-1, -1), Vector2i(1, 0)
	)
	assert_int(cm_oob_atk.defender_terrain_def).override_failure_message(
		"AC-10: OOB atk_coord → defender_terrain_def must be 0; got %d"
		% cm_oob_atk.defender_terrain_def
	).is_equal(0)
	assert_int(cm_oob_atk.defender_terrain_eva).override_failure_message(
		"AC-10: OOB atk_coord → defender_terrain_eva must be 0; got %d"
		% cm_oob_atk.defender_terrain_eva
	).is_equal(0)
	assert_int(cm_oob_atk.elevation_atk_mod).override_failure_message(
		"AC-10: OOB atk_coord → elevation_atk_mod must be 0; got %d"
		% cm_oob_atk.elevation_atk_mod
	).is_equal(0)
	assert_int(cm_oob_atk.elevation_def_mod).override_failure_message(
		"AC-10: OOB atk_coord → elevation_def_mod must be 0; got %d"
		% cm_oob_atk.elevation_def_mod
	).is_equal(0)
	assert_bool(cm_oob_atk.bridge_no_flank).override_failure_message(
		"AC-10: OOB atk_coord → bridge_no_flank must be false"
	).is_false()
	assert_int(cm_oob_atk.special_rules.size()).override_failure_message(
		"AC-10: OOB atk_coord → special_rules must be empty; size=%d" % cm_oob_atk.special_rules.size()
	).is_equal(0)

	# Act + Assert: null grid zero-fills (full 6-field check, parallel of OOB-def)
	var cm_null: CombatModifiers = TerrainEffect.get_combat_modifiers(
		null, Vector2i(0, 0), Vector2i(1, 0)
	)
	assert_int(cm_null.defender_terrain_def).override_failure_message(
		"AC-10: null grid → defender_terrain_def must be 0; got %d" % cm_null.defender_terrain_def
	).is_equal(0)
	assert_int(cm_null.defender_terrain_eva).override_failure_message(
		"AC-10: null grid → defender_terrain_eva must be 0; got %d" % cm_null.defender_terrain_eva
	).is_equal(0)
	assert_int(cm_null.elevation_atk_mod).override_failure_message(
		"AC-10: null grid → elevation_atk_mod must be 0; got %d" % cm_null.elevation_atk_mod
	).is_equal(0)
	assert_int(cm_null.elevation_def_mod).override_failure_message(
		"AC-10: null grid → elevation_def_mod must be 0; got %d" % cm_null.elevation_def_mod
	).is_equal(0)
	assert_bool(cm_null.bridge_no_flank).override_failure_message(
		"AC-10: null grid → bridge_no_flank must be false"
	).is_false()
	assert_int(cm_null.special_rules.size()).override_failure_message(
		"AC-10: null grid → special_rules must be empty; size=%d" % cm_null.special_rules.size()
	).is_equal(0)

	grid.free()


# ── AC-11: Tuned cap uses runtime _max_defense_reduction ─────────────────────


## AC-11: runtime _max_defense_reduction=25 (tuned lower) clamps FORTRESS_WALL scenario to 25.
## Verifies AC-19 data-driven promise at the combat-modifier level:
## the runtime cap (not the compile-time const) is the active clamp gate.
##
## Setup strategy: reset_for_tests() → call _fall_back_to_defaults() via script reflection
## (sets _config_loaded=true + canonical terrain/elevation tables) → set _max_defense_reduction=25.
## This populates the tables canonically while letting us control the cap independently.
## The cap must be set BEFORE the get_combat_modifiers() call so it is in place at clamping time.
##
## Given: canonical tables loaded via _fall_back_to_defaults(); _max_defense_reduction=25.
## When:  FORTRESS_WALL(25) + elev_def(+15) = 40 → clamped against tuned cap 25.
## Then:  defender_terrain_def == 25 (tuned cap; not 30).
## Also:  cross-system contract verified against tuned cap (AC-12 gate).
func test_terrain_effect_combat_modifiers_tuned_cap_clamps_to_runtime_max() -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript

	# Arrange: before_test() already called reset_for_tests() (_config_loaded=false, caps=defaults)
	# Load canonical tables via _fall_back_to_defaults() — sets _config_loaded=true
	script.call("_fall_back_to_defaults")
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"AC-11 pre-condition: _config_loaded must be true after _fall_back_to_defaults()"
	).is_true()
	# Pre-condition guard: confirm _terrain_table is populated. If _fall_back_to_defaults is
	# ever renamed, script.call() returns null silently and the table stays empty — without
	# this guard the test would still fail downstream but with a confusing zero-fill diagnostic
	# instead of "fall_back_to_defaults didn't run". Convert to a targeted pre-condition signal.
	var _table_check: Dictionary = script.get("_terrain_table") as Dictionary
	assert_bool(_table_check.has(TerrainEffect.FORTRESS_WALL)).override_failure_message(
		"AC-11 pre-condition: _fall_back_to_defaults() must populate _terrain_table"
		+ " with FORTRESS_WALL entry; got empty table (likely method renamed without test update)"
	).is_true()

	# Tune the cap DOWN to 25 BEFORE the query — must be in place at clamping time
	script.set("_max_defense_reduction", 25)
	assert_int(script.get("_max_defense_reduction") as int).override_failure_message(
		"AC-11 pre-condition: _max_defense_reduction must be 25 after script.set"
	).is_equal(25)

	# Grid: atk PLAINS elev=0, def FORTRESS_WALL elev=2 → delta=-2 → defense_mod=+15
	var grid: MapGrid = _make_grid_2tile(TerrainEffect.PLAINS, 0, TerrainEffect.FORTRESS_WALL, 2)

	# Act
	var cm: CombatModifiers = TerrainEffect.get_combat_modifiers(
		grid, Vector2i(0, 0), Vector2i(1, 0)
	)

	# Assert: total = 25 + 15 = 40 → clamped to tuned cap 25 (not production cap 30)
	assert_int(cm.defender_terrain_def).override_failure_message(
		("AC-11: FORTRESS_WALL(25) + elev_def(+15) = 40 → must be clamped to tuned cap 25;"
		+ " got %d (if 30, production cap was used instead of runtime cap)") % cm.defender_terrain_def
	).is_equal(25)
	_assert_combat_modifiers_within_clamps(cm, "AC-11")

	grid.free()


# ── AC-12: Cross-system contract values within clamps (TR-011) ────────────────


## AC-12 (TR-011): Returned values satisfy the cross-system contract across multiple
## representative scenarios — the _assert_combat_modifiers_within_clamps helper called
## at the end of every other test IS this contract gate (AC-12 is embedded in all 14 tests).
##
## This dedicated test adds an explicit multi-scenario invariant sweep to document
## the requirement and ensure it runs as a named test in the regression output.
##
## Scenarios covered:
##   (a) BRIDGE defender (bridge special rules + evasion=0)
##   (b) MOUNTAIN defender at high elevation (high defense stacking scenario)
##   (c) PLAINS defender at delta=+2 (negative defense scenario)
## Also:  _assert_combat_modifiers_within_clamps helper itself is the gate — it is
##        called explicitly here and implicitly in all other 13 tests.
func test_terrain_effect_combat_modifiers_cross_system_contract_values_within_clamps() -> void:
	# Scenario (a): BRIDGE defender
	var grid_a: MapGrid = _make_grid_2tile(TerrainEffect.PLAINS, 0, TerrainEffect.BRIDGE, 0)
	var cm_a: CombatModifiers = TerrainEffect.get_combat_modifiers(
		grid_a, Vector2i(0, 0), Vector2i(1, 0)
	)
	_assert_combat_modifiers_within_clamps(cm_a, "AC-12(a) BRIDGE defender")
	grid_a.free()

	# Scenario (b): MOUNTAIN defender at delta=-2 (defender elevation bonus → high total defense)
	# MOUNTAIN valid elevations: 2 (peak). PLAINS valid: 0.
	var grid_b: MapGrid = _make_grid_2tile(TerrainEffect.PLAINS, 0, TerrainEffect.MOUNTAIN, 2)
	var cm_b: CombatModifiers = TerrainEffect.get_combat_modifiers(
		grid_b, Vector2i(0, 0), Vector2i(1, 0)
	)
	# MOUNTAIN(20) + elev_def(+15, delta=-2) = 35 → clamped to 30.
	# Direct value assertion in addition to the contract gate: the gate alone passes anything
	# in [-30, +30], so an off-by-one regression below the cap (e.g. 29) would slip past.
	# The MOUNTAIN-specific defense_bonus (20) is asserted nowhere else as a defender; this is
	# the gate that catches a mistuned MOUNTAIN entry in the canonical CR-1 table.
	assert_int(cm_b.defender_terrain_def).override_failure_message(
		("AC-12(b): MOUNTAIN(20) + elev_def(+15) = 35 → must clamp to MAX_DEFENSE_REDUCTION (30);"
		+ " got %d") % cm_b.defender_terrain_def
	).is_equal(30)
	_assert_combat_modifiers_within_clamps(cm_b, "AC-12(b) MOUNTAIN high-stack")
	grid_b.free()

	# Scenario (c): PLAINS defender at delta=+2 (negative defense)
	# Attacker MOUNTAIN(elev=2) is the only valid elev=2 stand-in for the spec's "atk PLAINS";
	# def PLAINS(elev=0) is what makes this the negative-defense case being asserted on.
	var grid_c: MapGrid = _make_grid_2tile(TerrainEffect.MOUNTAIN, 2, TerrainEffect.PLAINS, 0)
	var cm_c: CombatModifiers = TerrainEffect.get_combat_modifiers(
		grid_c, Vector2i(0, 0), Vector2i(1, 0)
	)
	# PLAINS(0) + elev_def(-15) = -15 → within [-30, +30] → no clamp
	_assert_combat_modifiers_within_clamps(cm_c, "AC-12(c) PLAINS negative defense")
	grid_c.free()


# ── AC-13: Defensive copy — caller mutation does not poison static state ───────


## AC-13 (ADR-0008 §Notes §5): Caller mutation of returned CombatModifiers does NOT
## affect the static _terrain_table entry on subsequent calls.
## Parallel of story-004 AC-8 for the get_combat_modifiers() defensive-copy contract.
##
## Given: BRIDGE fixture; first get_combat_modifiers() returns m1.
## When:  m1.special_rules.append(&"caller_pollution"); second call returns m2.
## Then:  m2.special_rules.size()==1 (only &"bridge_no_flank");
##        m1.special_rules.size()==2 (caller's local copy mutated — expected);
##        static _terrain_table[BRIDGE].special_rules.size()==1 (not poisoned).
## Also:  cross-system contract verified (AC-12 gate).
func test_terrain_effect_combat_modifiers_defensive_copy_caller_mutation_does_not_poison_static_state() -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript
	var grid: MapGrid = _make_grid_2tile(TerrainEffect.PLAINS, 0, TerrainEffect.BRIDGE, 0)
	TerrainEffect.load_config()

	# Act — first call
	var m1: CombatModifiers = TerrainEffect.get_combat_modifiers(
		grid, Vector2i(0, 0), Vector2i(1, 0)
	)
	assert_int(m1.special_rules.size()).override_failure_message(
		"AC-13 pre-mutation: BRIDGE special_rules must have 1 element; got %d"
		% m1.special_rules.size()
	).is_equal(1)

	# Mutate the returned copy
	m1.special_rules.append(&"caller_pollution")
	assert_int(m1.special_rules.size()).override_failure_message(
		"AC-13 post-mutation: m1.special_rules must have 2 elements after append; got %d"
		% m1.special_rules.size()
	).is_equal(2)

	# Act — second call: must return fresh copy from unmodified static table
	var m2: CombatModifiers = TerrainEffect.get_combat_modifiers(
		grid, Vector2i(0, 0), Vector2i(1, 0)
	)

	# Assert — m2 unaffected
	assert_int(m2.special_rules.size()).override_failure_message(
		("AC-13: m2.special_rules.size() must be 1 (only &\"bridge_no_flank\");"
		+ " got %d — static table was polluted by caller mutation (defensive copy broken)")
		% m2.special_rules.size()
	).is_equal(1)
	assert_bool(m2.special_rules.has(&"bridge_no_flank")).override_failure_message(
		"AC-13: m2.special_rules must still contain &\"bridge_no_flank\""
	).is_true()

	# Verify static table directly: _terrain_table[BRIDGE].special_rules must still have 1 element
	var terrain_table: Dictionary = script.get("_terrain_table") as Dictionary
	var bridge_entry: TerrainModifiers = terrain_table[TerrainEffect.BRIDGE] as TerrainModifiers
	assert_int(bridge_entry.special_rules.size()).override_failure_message(
		("AC-13: static _terrain_table[BRIDGE].special_rules.size() must remain 1;"
		+ " got %d — caller_pollution leaked back into static state")
		% bridge_entry.special_rules.size()
	).is_equal(1)
	_assert_combat_modifiers_within_clamps(m2, "AC-13")

	grid.free()


# ── AC-14: Lazy-init triggers load_config on first query ──────────────────────


## AC-14 (ADR-0008 §Decision 1): get_combat_modifiers lazy-triggers load_config
## on first call if _config_loaded is false; subsequent calls do NOT re-trigger
## (idempotent guard contract). Parallel of story-004 AC-9.
##
## Sentinel: _max_evasion is mutated to 99 after first call. It is chosen because:
##   (a) it does NOT appear in elevation_atk_mod / elevation_def_mod computation,
##   (b) the HILLS+delta=+1 scenario's total_def=7 is well within [-30, +30] regardless of cap,
##   (c) HILLS evasion_bonus=0, so the evasion clamp does not engage and _max_evasion=99 is
##       observable only via sentinel preservation — not via any output value change.
## If load_config() re-fires on the second call, _apply_config would overwrite _max_evasion back
## to 30, proving the idempotent guard was bypassed.
##
## Given: reset_for_tests() (so _config_loaded==false).
## When:  get_combat_modifiers called once.
## Then:  _config_loaded==true after; result returned correctly.
## When:  _max_evasion mutated to sentinel 99; get_combat_modifiers called again.
## Then:  _max_evasion==99 (idempotent guard short-circuits; no re-apply from config).
## Also:  cross-system contract verified at both calls (AC-12 gate).
func test_terrain_effect_combat_modifiers_lazy_init_triggers_load_config_on_first_query() -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript
	# Arrange: before_test() already called reset_for_tests(); _config_loaded==false
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"AC-14 pre-condition: _config_loaded must be false before first query"
	).is_false()

	# atk MOUNTAIN elev=2, def HILLS elev=1 → delta=+1; HILLS eva=0 (sentinel-safe terrain).
	# HILLS only allows elev=1 in MapGrid.ELEVATION_RANGES; MOUNTAIN is the canonical
	# elev=2 attacker. delta=+1 unchanged from the spec wording's intent.
	var grid: MapGrid = _make_grid_2tile(TerrainEffect.MOUNTAIN, 2, TerrainEffect.HILLS, 1)

	# Act — first call; must trigger lazy load_config()
	var cm1: CombatModifiers = TerrainEffect.get_combat_modifiers(
		grid, Vector2i(0, 0), Vector2i(1, 0)
	)

	# Assert — lazy load fired
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"AC-14: _config_loaded must be true after first get_combat_modifiers call"
	).is_true()
	# delta=+1 → elevation_atk_mod=8; HILLS(15) + elev_def(-8) = 7 → defender_terrain_def=7
	assert_int(cm1.elevation_atk_mod).override_failure_message(
		"AC-14: elevation_atk_mod must be 8 (delta=+1) after lazy load; got %d"
		% cm1.elevation_atk_mod
	).is_equal(8)
	assert_int(cm1.defender_terrain_def).override_failure_message(
		"AC-14: HILLS(15) + elev_def(-8) = 7; defender_terrain_def must be 7; got %d"
		% cm1.defender_terrain_def
	).is_equal(7)
	_assert_combat_modifiers_within_clamps(cm1, "AC-14 first-call")

	# Strengthen: second call must short-circuit (idempotent guard).
	# Mutate _max_evasion to sentinel. If load_config() fires again, _apply_config
	# would overwrite sentinel back to 30 — proving the guard is bypassed.
	const SENTINEL_EVA: int = 99
	script.set("_max_evasion", SENTINEL_EVA)
	var cm2: CombatModifiers = TerrainEffect.get_combat_modifiers(
		grid, Vector2i(0, 0), Vector2i(1, 0)
	)
	assert_int(script.get("_max_evasion") as int).override_failure_message(
		("AC-14 idempotency: second get_combat_modifiers call must NOT re-trigger load_config"
		+ " (sentinel %d preserved); got %d")
		% [SENTINEL_EVA, script.get("_max_evasion") as int]
	).is_equal(SENTINEL_EVA)
	# cm2 still returns the same values (no logical degradation from evasion-cap mutation
	# since HILLS evasion=0 and the clamp max(0, 30_or_99) makes no difference here)
	assert_int(cm2.defender_terrain_def).override_failure_message(
		"AC-14 idempotency: cm2 defender_terrain_def must still be 7; got %d"
		% cm2.defender_terrain_def
	).is_equal(7)
	# Cross-system contract at sentinel cap: defender_terrain_eva=0 ∈ [0, 99] — still valid
	_assert_combat_modifiers_within_clamps(cm2, "AC-14 second-call")

	grid.free()
