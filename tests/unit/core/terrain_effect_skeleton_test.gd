extends GdUnitTestSuite

## terrain_effect_skeleton_test.gd
## Unit tests for Story 002 (terrain-effect epic): TerrainEffect skeleton,
## static state, lazy-init guard, reset_for_tests(), and terrain-type constants.
##
## Covers AC-1 through AC-6 from story-002 §Acceptance Criteria.
## AC-7 (multi-suite isolation regression) lives in terrain_effect_isolation_test.gd.
## AC-8 (doc-comment content) is verified by code review at /code-review time.
##
## Governing ADR: ADR-0008 Terrain Effect System (Accepted 2026-04-25).
## Related TRs:   TR-terrain-effect-010.
##
## ISOLATION DISCIPLINE (ADR-0008 §Risks line 562):
##   before_each() calls TerrainEffect.reset_for_tests() unconditionally.
##   This ensures each test starts from pristine defaults regardless of prior state.
##
## STATIC-VAR INSPECTION PATTERN:
##   Static vars are read/written via (load(PATH) as GDScript).get/set("_var")
##   per the save_migration_registry_test.gd precedent (established project pattern
##   for static-var seam access without instantiation).

const TERRAIN_EFFECT_PATH: String = "res://src/core/terrain_effect.gd"


func before_each() -> void:
	TerrainEffect.reset_for_tests()


# ── AC-1: Class declaration + RefCounted inheritance ─────────────────────────


## AC-1: TerrainEffect resolves as a class_name and constants are accessible
## without instantiation.
## Given: freshly reset state.
## When:  MAX_DEFENSE_REDUCTION_DEFAULT accessed via class name.
## Then:  compilation succeeds; constant access returns 30.
func test_terrain_effect_class_declaration_constant_accessible_without_instantiation() -> void:
	# Arrange — nothing needed; class-name resolution is a compile-time property.

	# Act + Assert
	assert_int(TerrainEffect.MAX_DEFENSE_REDUCTION_DEFAULT).override_failure_message(
		"TerrainEffect.MAX_DEFENSE_REDUCTION_DEFAULT must equal 30 (compile-time const); got %d"
		% TerrainEffect.MAX_DEFENSE_REDUCTION_DEFAULT
	).is_equal(30)


# ── AC-2: 8 terrain-type integer constants ───────────────────────────────────


## AC-2: All 8 terrain-type constants declared in canonical MapGrid order.
## Given: TerrainEffect class loaded.
## When:  each constant accessed.
## Then:  PLAINS=0, FOREST=1, HILLS=2, MOUNTAIN=3, RIVER=4, BRIDGE=5,
##        FORTRESS_WALL=6, ROAD=7 (ADR-0008 §Key Interfaces lines 437-445).
func test_terrain_effect_terrain_type_constants_canonical_order() -> void:
	assert_int(TerrainEffect.PLAINS).override_failure_message(
		"PLAINS must be 0; got %d" % TerrainEffect.PLAINS
	).is_equal(0)
	assert_int(TerrainEffect.FOREST).override_failure_message(
		"FOREST must be 1; got %d" % TerrainEffect.FOREST
	).is_equal(1)
	assert_int(TerrainEffect.HILLS).override_failure_message(
		"HILLS must be 2; got %d" % TerrainEffect.HILLS
	).is_equal(2)
	assert_int(TerrainEffect.MOUNTAIN).override_failure_message(
		"MOUNTAIN must be 3; got %d" % TerrainEffect.MOUNTAIN
	).is_equal(3)
	assert_int(TerrainEffect.RIVER).override_failure_message(
		"RIVER must be 4; got %d" % TerrainEffect.RIVER
	).is_equal(4)
	assert_int(TerrainEffect.BRIDGE).override_failure_message(
		"BRIDGE must be 5; got %d" % TerrainEffect.BRIDGE
	).is_equal(5)
	assert_int(TerrainEffect.FORTRESS_WALL).override_failure_message(
		"FORTRESS_WALL must be 6; got %d" % TerrainEffect.FORTRESS_WALL
	).is_equal(6)
	assert_int(TerrainEffect.ROAD).override_failure_message(
		"ROAD must be 7; got %d" % TerrainEffect.ROAD
	).is_equal(7)


# ── AC-3: 4 compile-time cap defaults ────────────────────────────────────────


## AC-3: All 4 compile-time cap constants declared with correct values.
## Given: TerrainEffect class loaded.
## When:  each const accessed.
## Then:  MAX_DEFENSE_REDUCTION_DEFAULT=30, MAX_EVASION_DEFAULT=30,
##        EVASION_WEIGHT_DEFAULT≈1.2, MAX_POSSIBLE_SCORE_DEFAULT≈43.0.
func test_terrain_effect_cap_defaults_correct_values() -> void:
	assert_int(TerrainEffect.MAX_DEFENSE_REDUCTION_DEFAULT).override_failure_message(
		"MAX_DEFENSE_REDUCTION_DEFAULT must be 30; got %d"
		% TerrainEffect.MAX_DEFENSE_REDUCTION_DEFAULT
	).is_equal(30)
	assert_int(TerrainEffect.MAX_EVASION_DEFAULT).override_failure_message(
		"MAX_EVASION_DEFAULT must be 30; got %d" % TerrainEffect.MAX_EVASION_DEFAULT
	).is_equal(30)
	assert_float(TerrainEffect.EVASION_WEIGHT_DEFAULT).override_failure_message(
		"EVASION_WEIGHT_DEFAULT must be approx 1.2; got %f" % TerrainEffect.EVASION_WEIGHT_DEFAULT
	).is_equal_approx(1.2, 0.00001)
	assert_float(TerrainEffect.MAX_POSSIBLE_SCORE_DEFAULT).override_failure_message(
		"MAX_POSSIBLE_SCORE_DEFAULT must be approx 43.0; got %f"
		% TerrainEffect.MAX_POSSIBLE_SCORE_DEFAULT
	).is_equal_approx(43.0, 0.00001)


# ── AC-4: Static state vars initialize to declared defaults ──────────────────


## AC-4: After reset_for_tests() all static vars are at compile-time defaults.
## Uses (load(PATH) as GDScript).get("_var") per save_migration_registry precedent.
## Given: reset_for_tests() called by before_each().
## When:  each static var inspected via GDScript seam.
## Then:  _config_loaded=false, _terrain_table.size()=0, _elevation_table.size()=0,
##        _max_defense_reduction=30, _max_evasion=30, _evasion_weight≈1.2,
##        _max_possible_score≈43.0, _cost_default_multiplier=1.
func test_terrain_effect_static_defaults_pristine_on_first_load() -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript

	var config_loaded: bool = script.get("_config_loaded") as bool
	assert_bool(config_loaded).override_failure_message(
		"_config_loaded must be false after reset; got %s" % str(config_loaded)
	).is_false()

	var terrain_table: Dictionary = script.get("_terrain_table") as Dictionary
	assert_int(terrain_table.size()).override_failure_message(
		"_terrain_table must be empty after reset; size = %d" % terrain_table.size()
	).is_equal(0)

	var elevation_table: Dictionary = script.get("_elevation_table") as Dictionary
	assert_int(elevation_table.size()).override_failure_message(
		"_elevation_table must be empty after reset; size = %d" % elevation_table.size()
	).is_equal(0)

	var max_dr: int = script.get("_max_defense_reduction") as int
	assert_int(max_dr).override_failure_message(
		"_max_defense_reduction must be 30 after reset; got %d" % max_dr
	).is_equal(30)

	var max_ev: int = script.get("_max_evasion") as int
	assert_int(max_ev).override_failure_message(
		"_max_evasion must be 30 after reset; got %d" % max_ev
	).is_equal(30)

	var ev_weight: float = script.get("_evasion_weight") as float
	assert_float(ev_weight).override_failure_message(
		"_evasion_weight must be approx 1.2 after reset; got %f" % ev_weight
	).is_equal_approx(1.2, 0.00001)

	var max_score: float = script.get("_max_possible_score") as float
	assert_float(max_score).override_failure_message(
		"_max_possible_score must be approx 43.0 after reset; got %f" % max_score
	).is_equal_approx(43.0, 0.00001)

	var cost_mult: int = script.get("_cost_default_multiplier") as int
	assert_int(cost_mult).override_failure_message(
		"_cost_default_multiplier must be 1 after reset; got %d" % cost_mult
	).is_equal(1)


# ── AC-5: reset_for_tests() clears mutated state ─────────────────────────────


## AC-5: reset_for_tests() clears all static vars to compile-time defaults.
## Given: static state mutated via GDScript seam (_config_loaded=true, _max_defense_reduction=99).
## When:  TerrainEffect.reset_for_tests() called.
## Then:  _config_loaded==false, _max_defense_reduction==30, all other vars at defaults.
func test_terrain_effect_reset_for_tests_clears_state() -> void:
	# Arrange — mutate state via GDScript seam
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript
	script.set("_config_loaded", true)
	script.set("_max_defense_reduction", 99)
	script.set("_max_evasion", 88)
	script.set("_evasion_weight", 9.9)
	script.set("_max_possible_score", 999.0)
	script.set("_cost_default_multiplier", 5)
	script.set("_terrain_table", {0: "dirty"})
	script.set("_elevation_table", {1: "dirty"})

	# Act
	TerrainEffect.reset_for_tests()

	# Assert — all vars restored to defaults
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"_config_loaded must be false after reset"
	).is_false()
	assert_int(script.get("_max_defense_reduction") as int).override_failure_message(
		"_max_defense_reduction must be 30 after reset; got %d"
		% (script.get("_max_defense_reduction") as int)
	).is_equal(30)
	assert_int(script.get("_max_evasion") as int).override_failure_message(
		"_max_evasion must be 30 after reset"
	).is_equal(30)
	assert_float(script.get("_evasion_weight") as float).override_failure_message(
		"_evasion_weight must be approx 1.2 after reset"
	).is_equal_approx(1.2, 0.00001)
	assert_float(script.get("_max_possible_score") as float).override_failure_message(
		"_max_possible_score must be approx 43.0 after reset"
	).is_equal_approx(43.0, 0.00001)
	assert_int(script.get("_cost_default_multiplier") as int).override_failure_message(
		"_cost_default_multiplier must be 1 after reset"
	).is_equal(1)
	assert_int((script.get("_terrain_table") as Dictionary).size()).override_failure_message(
		"_terrain_table must be empty after reset"
	).is_equal(0)
	assert_int((script.get("_elevation_table") as Dictionary).size()).override_failure_message(
		"_elevation_table must be empty after reset"
	).is_equal(0)


# ── AC-6: load_config() skeleton + idempotent guard ──────────────────────────


## AC-6: load_config() skeleton returns false; idempotent guard skips on second call.
## Given: TerrainEffect._config_loaded == false (after reset).
## When:  load_config() called with default path.
## Then:  returns false (skeleton; story-003 changes this); _config_loaded unchanged (false).
## When (second call): load_config() called again after manually setting _config_loaded=true.
## Then:  returns true (idempotent guard, config already loaded); push_warning observable.
func test_terrain_effect_load_config_idempotent_guard_short_circuits() -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript

	# First call: skeleton returns false
	var result_first: bool = TerrainEffect.load_config()
	assert_bool(result_first).override_failure_message(
		"load_config() skeleton must return false on first call; got %s" % str(result_first)
	).is_false()

	# _config_loaded remains false (skeleton does not set it)
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"_config_loaded must remain false after skeleton load_config(); got %s"
		% str(script.get("_config_loaded"))
	).is_false()

	# Simulate story-003 setting _config_loaded = true
	script.set("_config_loaded", true)

	# Second call: idempotent guard fires, returns true early
	var result_second: bool = TerrainEffect.load_config()
	assert_bool(result_second).override_failure_message(
		("load_config() idempotent guard must return true when _config_loaded is already true;"
		+ " got %s") % str(result_second)
	).is_true()

	# _config_loaded still true (guard did not reset it)
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"_config_loaded must still be true after idempotent guard fires"
	).is_true()
