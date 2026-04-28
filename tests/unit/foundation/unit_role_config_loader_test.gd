extends GdUnitTestSuite

## unit_role_config_loader_test.gd
## Story 002 — JSON config loader + safe-default fallback.
## Covers AC-1 through AC-5 (5 ACs per story QA Test Cases).
##
## TESTABILITY: _load_coefficients(path) accepts an optional path parameter
## (dependency injection per coding-standards.md) so failure-path tests
## (AC-2/AC-3/AC-4) write temp fixture files to user:// without touching
## the production assets/data/config/unit_roles.json.
##
## LIFECYCLE:
##   before_test — reset _coefficients_loaded + _coefficients (G-15 static-cache isolation)
##   after_test  — reset again as safety net; no file cleanup needed (user:// temp files
##                 are ephemeral and do not persist between sessions)


const _PROD_PATH: String = "assets/data/config/unit_roles.json"
## Guaranteed non-existent path (no file written here — used for AC-2 missing-file test)
const _TMP_MISSING: String = "user://unit_role_test_guaranteed_missing_path_s002.json"
const _TMP_MALFORMED: String = "user://unit_role_test_malformed_s002.json"
const _TMP_PARTIAL: String = "user://unit_role_test_partial_schema_s002.json"


func before_test() -> void:
	# G-15: reset static cache between tests for isolation
	UnitRole._coefficients_loaded = false
	UnitRole._coefficients = {}


func after_test() -> void:
	# Safety net: reset again after each test
	UnitRole._coefficients_loaded = false
	UnitRole._coefficients = {}


# ── AC-1: Happy-path JSON load ────────────────────────────────────────────────


## AC-1: Production unit_roles.json loads successfully; _coefficients_loaded becomes true.
func test_load_coefficients_happy_path_sets_loaded_flag() -> void:
	# Arrange: cache is reset in before_test

	# Act
	UnitRole._load_coefficients(_PROD_PATH)

	# Assert — flag set
	assert_bool(UnitRole._coefficients_loaded).override_failure_message(
		"AC-1: _coefficients_loaded should be true after successful load"
	).is_true()


## AC-1: cavalry class_atk_mult reads 1.1 from production JSON (ADR-0009 §4 example value).
func test_load_coefficients_cavalry_atk_mult_is_1_1() -> void:
	# Arrange + Act
	UnitRole._load_coefficients(_PROD_PATH)

	# Assert
	var cavalry: Dictionary = UnitRole._coefficients.get("cavalry", {}) as Dictionary
	var actual: float = cavalry.get("class_atk_mult", -1.0) as float
	assert_float(actual).override_failure_message(
		"AC-1: cavalry.class_atk_mult should be 1.1 (ADR-0009 §4 example); got %f" % actual
	).is_equal(1.1)


## AC-1: All 6 class keys present after successful load.
func test_load_coefficients_all_six_classes_present() -> void:
	# Arrange + Act
	UnitRole._load_coefficients(_PROD_PATH)

	# Assert — each expected key exists
	var expected_keys: Array[String] = [
		"cavalry", "infantry", "archer", "strategist", "commander", "scout"
	]
	for key: String in expected_keys:
		assert_bool(UnitRole._coefficients.has(key)).override_failure_message(
			"AC-1: _coefficients missing class key '%s' after successful load" % key
		).is_true()


## AC-1: Re-calling _load_coefficients is a no-op (early-return on _coefficients_loaded flag).
func test_load_coefficients_second_call_is_noop() -> void:
	# Arrange: first load succeeds
	UnitRole._load_coefficients(_PROD_PATH)
	# Corrupt the cache manually to detect if second call re-loads
	UnitRole._coefficients["cavalry"] = {"class_atk_mult": -999.0}

	# Act: second call should early-return without overwriting the corrupted cache
	UnitRole._load_coefficients(_PROD_PATH)

	# Assert — sentinel value persists (flag blocked the reload)
	var cavalry: Dictionary = UnitRole._coefficients.get("cavalry", {}) as Dictionary
	var sentinel: float = cavalry.get("class_atk_mult", 0.0) as float
	assert_float(sentinel).override_failure_message(
		("AC-1: second _load_coefficients call should be a no-op (flag guard); "
		+ "cache was overwritten (got %f instead of -999.0)") % sentinel
	).is_equal(-999.0)


# ── AC-2: Missing file → safe-default fallback ────────────────────────────────


## AC-2: Non-existent file path → fallback populated; _coefficients_loaded becomes true.
## push_error is logged (not asserted — GdUnit4 v6.1.2 captures push_error in stdout only;
## functional outcome — fallback population — is the behavioral assertion).
func test_load_coefficients_missing_file_uses_fallback() -> void:
	# Arrange: _TMP_MISSING path is guaranteed not to exist (no file written at that path)

	# Act
	UnitRole._load_coefficients(_TMP_MISSING)

	# Assert — loaded flag set despite missing file (game continues; Pillar 1 preserved)
	assert_bool(UnitRole._coefficients_loaded).override_failure_message(
		"AC-2: _coefficients_loaded should be true even after missing-file fallback"
	).is_true()

	# Assert — all 6 fallback classes present
	var expected_keys: Array[String] = [
		"cavalry", "infantry", "archer", "strategist", "commander", "scout"
	]
	for key: String in expected_keys:
		assert_bool(UnitRole._coefficients.has(key)).override_failure_message(
			"AC-2: fallback _coefficients missing class key '%s'" % key
		).is_true()


## AC-2: Fallback cavalry class_atk_mult matches GDD CR-1 value (1.1).
func test_load_coefficients_missing_file_fallback_cavalry_atk_mult() -> void:
	# Act
	UnitRole._load_coefficients(_TMP_MISSING)

	# Assert
	var cavalry: Dictionary = UnitRole._coefficients.get("cavalry", {}) as Dictionary
	var actual: float = cavalry.get("class_atk_mult", -1.0) as float
	assert_float(actual).override_failure_message(
		"AC-2: fallback cavalry.class_atk_mult should be 1.1 (GDD CR-1); got %f" % actual
	).is_equal(1.1)


# ── AC-3: Malformed JSON → safe-default fallback with line/col diagnostics ────


## AC-3: Malformed JSON file → fallback populated; _coefficients_loaded becomes true.
## The push_error emitted by _load_coefficients includes line/col from JSON parser
## (verified behaviorally: fallback population confirms the malformed-JSON code path ran).
func test_load_coefficients_malformed_json_uses_fallback() -> void:
	# Arrange — write a malformed JSON fixture (trailing comma = invalid JSON)
	var malformed: String = '{"cavalry": {"class_atk_mult": 1.1,}}'
	var file: FileAccess = FileAccess.open(_TMP_MALFORMED, FileAccess.WRITE)
	assert_bool(file != null).override_failure_message(
		"AC-3 pre-condition: could not write malformed fixture to %s" % _TMP_MALFORMED
	).is_true()
	file.store_string(malformed)
	file.close()

	# Act
	UnitRole._load_coefficients(_TMP_MALFORMED)

	# Assert — loaded flag set despite parse failure
	assert_bool(UnitRole._coefficients_loaded).override_failure_message(
		"AC-3: _coefficients_loaded should be true even after malformed JSON fallback"
	).is_true()

	# Assert — all 6 fallback classes present
	var expected_keys: Array[String] = [
		"cavalry", "infantry", "archer", "strategist", "commander", "scout"
	]
	for key: String in expected_keys:
		assert_bool(UnitRole._coefficients.has(key)).override_failure_message(
			"AC-3: fallback _coefficients missing class key '%s' after malformed JSON" % key
		).is_true()


## AC-3: Fallback scout class_init_mult matches GDD F-4 value (1.2) after malformed JSON.
func test_load_coefficients_malformed_json_fallback_scout_init_mult() -> void:
	# Arrange — write malformed JSON fixture
	var malformed: String = '{"bad json": missing brace'
	var file: FileAccess = FileAccess.open(_TMP_MALFORMED, FileAccess.WRITE)
	assert_bool(file != null).override_failure_message(
		"AC-3 pre-condition: could not write malformed fixture to %s" % _TMP_MALFORMED
	).is_true()
	file.store_string(malformed)
	file.close()

	# Act
	UnitRole._load_coefficients(_TMP_MALFORMED)

	# Assert — scout fallback value correct
	var scout: Dictionary = UnitRole._coefficients.get("scout", {}) as Dictionary
	var actual: float = scout.get("class_init_mult", -1.0) as float
	assert_float(actual).override_failure_message(
		"AC-3: fallback scout.class_init_mult should be 1.2 (GDD F-4); got %f" % actual
	).is_equal(1.2)


# ── AC-4: Schema validation — partial fallback per class ─────────────────────


## AC-4: Valid JSON but cavalry missing class_atk_mult → cavalry replaced with fallback;
## other classes (infantry) retain their JSON values.
func test_load_coefficients_partial_schema_per_class_fallback() -> void:
	# Arrange — write fixture: cavalry missing class_atk_mult; all other classes complete
	# G-9: wrap multi-line string concat in parens before % format operator
	var partial_json: String = (
		'{"cavalry": {'
		+ '"primary_stat": "stat_might", "secondary_stat": null, "w_primary": 1.0,'
		+ '"w_secondary": 0.0, "class_phys_def_mult": 0.8, "class_mag_def_mult": 0.7,'
		+ '"class_hp_mult": 0.9, "class_init_mult": 0.9, "class_move_delta": 1,'
		+ '"passive_tag": "passive_charge",'
		+ '"terrain_cost_table": [1.0, 1.0, 1.5, 2.0, 3.0, 1.0],'
		+ '"class_direction_mult": [1.0, 1.1, 1.09]},'
		+ '"infantry": {"primary_stat": "stat_might", "secondary_stat": null,'
		+ '"w_primary": 1.0, "w_secondary": 0.0, "class_atk_mult": 0.9,'
		+ '"class_phys_def_mult": 1.3, "class_mag_def_mult": 0.8, "class_hp_mult": 1.3,'
		+ '"class_init_mult": 0.7, "class_move_delta": 0, "passive_tag": "passive_shield_wall",'
		+ '"terrain_cost_table": [1.0, 1.0, 1.0, 1.0, 1.5, 1.0],'
		+ '"class_direction_mult": [0.9, 1.0, 1.1]},'
		+ '"archer": {"primary_stat": "stat_might", "secondary_stat": "stat_agility",'
		+ '"w_primary": 0.6, "w_secondary": 0.4, "class_atk_mult": 1.0,'
		+ '"class_phys_def_mult": 0.7, "class_mag_def_mult": 0.9, "class_hp_mult": 0.8,'
		+ '"class_init_mult": 0.85, "class_move_delta": 0, "passive_tag": "passive_high_ground_shot",'
		+ '"terrain_cost_table": [1.0, 1.0, 1.0, 1.0, 2.0, 1.0],'
		+ '"class_direction_mult": [1.0, 1.375, 0.9]},'
		+ '"strategist": {"primary_stat": "stat_intellect", "secondary_stat": null,'
		+ '"w_primary": 1.0, "w_secondary": 0.0, "class_atk_mult": 1.0,'
		+ '"class_phys_def_mult": 0.5, "class_mag_def_mult": 1.2, "class_hp_mult": 0.7,'
		+ '"class_init_mult": 0.8, "class_move_delta": -1, "passive_tag": "passive_tactical_read",'
		+ '"terrain_cost_table": [1.0, 1.0, 1.5, 1.5, 2.0, 1.0],'
		+ '"class_direction_mult": [1.0, 1.0, 1.0]},'
		+ '"commander": {"primary_stat": "stat_command", "secondary_stat": "stat_might",'
		+ '"w_primary": 0.7, "w_secondary": 0.3, "class_atk_mult": 0.8,'
		+ '"class_phys_def_mult": 1.0, "class_mag_def_mult": 1.0, "class_hp_mult": 1.1,'
		+ '"class_init_mult": 0.75, "class_move_delta": 0, "passive_tag": "passive_rally",'
		+ '"terrain_cost_table": [1.0, 1.0, 1.0, 1.5, 2.0, 1.0],'
		+ '"class_direction_mult": [1.0, 1.0, 1.0]},'
		+ '"scout": {"primary_stat": "stat_agility", "secondary_stat": "stat_might",'
		+ '"w_primary": 0.6, "w_secondary": 0.4, "class_atk_mult": 1.05,'
		+ '"class_phys_def_mult": 0.6, "class_mag_def_mult": 0.6, "class_hp_mult": 0.75,'
		+ '"class_init_mult": 1.2, "class_move_delta": 1, "passive_tag": "passive_ambush",'
		+ '"terrain_cost_table": [1.0, 1.0, 1.0, 0.7, 1.5, 1.0],'
		+ '"class_direction_mult": [1.0, 1.0, 1.1]}}'
	)
	var file: FileAccess = FileAccess.open(_TMP_PARTIAL, FileAccess.WRITE)
	assert_bool(file != null).override_failure_message(
		"AC-4 pre-condition: could not write partial schema fixture to %s" % _TMP_PARTIAL
	).is_true()
	file.store_string(partial_json)
	file.close()

	# Act
	UnitRole._load_coefficients(_TMP_PARTIAL)

	# Assert — loaded flag set
	assert_bool(UnitRole._coefficients_loaded).override_failure_message(
		"AC-4: _coefficients_loaded should be true after partial-schema load"
	).is_true()

	# Assert — cavalry replaced with fallback (class_atk_mult=1.1 from fallback dict)
	var cavalry: Dictionary = UnitRole._coefficients.get("cavalry", {}) as Dictionary
	var cavalry_atk: float = cavalry.get("class_atk_mult", -1.0) as float
	assert_float(cavalry_atk).override_failure_message(
		("AC-4: cavalry.class_atk_mult should be 1.1 (fallback — field was absent in fixture);"
		+ " got %f") % cavalry_atk
	).is_equal(1.1)

	# Assert — infantry retains its JSON value (0.9), not overwritten by fallback
	var infantry: Dictionary = UnitRole._coefficients.get("infantry", {}) as Dictionary
	var infantry_atk: float = infantry.get("class_atk_mult", -1.0) as float
	assert_float(infantry_atk).override_failure_message(
		("AC-4: infantry.class_atk_mult should be 0.9 (from JSON fixture, not fallback);"
		+ " got %f") % infantry_atk
	).is_equal(0.9)


# ── AC-5: 6×12 schema completeness ───────────────────────────────────────────


## AC-5: Per-field spot-checks across all 6 classes verifying GDD CR-1 + CR-4 + CR-6a
## locked values from the production unit_roles.json.
func test_load_coefficients_schema_completeness_cavalry_fields() -> void:
	# Arrange + Act
	UnitRole._load_coefficients(_PROD_PATH)

	var cavalry: Dictionary = UnitRole._coefficients.get("cavalry", {}) as Dictionary

	# class_atk_mult (GDD CR-1 F-1 table: 1.1)
	assert_float(cavalry.get("class_atk_mult", -1.0) as float).override_failure_message(
		"AC-5: cavalry.class_atk_mult expected 1.1 (GDD F-1)"
	).is_equal(1.1)

	# terrain_cost_table[4] = MOUNTAIN (GDD CR-4: ×3.0)
	var cav_terrain: Array = cavalry.get("terrain_cost_table", []) as Array
	assert_float(cav_terrain[4] as float).override_failure_message(
		"AC-5: cavalry.terrain_cost_table[4] (MOUNTAIN) expected 3.0 (GDD CR-4)"
	).is_equal(3.0)

	# class_direction_mult[2] = REAR (GDD CR-6a rev 2.8: ×1.09)
	var cav_dir: Array = cavalry.get("class_direction_mult", []) as Array
	assert_float(cav_dir[2] as float).override_failure_message(
		"AC-5: cavalry.class_direction_mult[2] (REAR) expected 1.09 (GDD CR-6a rev 2.8)"
	).is_equal(1.09)


## AC-5: Infantry defense multiplier (GDD F-2 table: class_phys_def_mult=1.3).
func test_load_coefficients_schema_completeness_infantry_phys_def() -> void:
	UnitRole._load_coefficients(_PROD_PATH)

	var infantry: Dictionary = UnitRole._coefficients.get("infantry", {}) as Dictionary
	assert_float(infantry.get("class_phys_def_mult", -1.0) as float).override_failure_message(
		"AC-5: infantry.class_phys_def_mult expected 1.3 (GDD F-2)"
	).is_equal(1.3)


## AC-5: Archer stat weights and direction multiplier (GDD F-1: w_primary=0.6, w_secondary=0.4;
## GDD CR-6a: FLANK=1.375 — largest class-mod bonus in matrix, Archer FLANK-specialist identity).
func test_load_coefficients_schema_completeness_archer_weights_and_flank() -> void:
	UnitRole._load_coefficients(_PROD_PATH)

	var archer: Dictionary = UnitRole._coefficients.get("archer", {}) as Dictionary
	assert_float(archer.get("w_primary", -1.0) as float).override_failure_message(
		"AC-5: archer.w_primary expected 0.6 (GDD F-1)"
	).is_equal(0.6)
	assert_float(archer.get("w_secondary", -1.0) as float).override_failure_message(
		"AC-5: archer.w_secondary expected 0.4 (GDD F-1)"
	).is_equal(0.4)

	var archer_dir: Array = archer.get("class_direction_mult", []) as Array
	assert_float(archer_dir[1] as float).override_failure_message(
		"AC-5: archer.class_direction_mult[1] (FLANK) expected 1.375 (GDD CR-6a)"
	).is_equal(1.375)


## AC-5: Strategist magical defense multiplier (GDD F-2: class_mag_def_mult=1.2).
func test_load_coefficients_schema_completeness_strategist_mag_def() -> void:
	UnitRole._load_coefficients(_PROD_PATH)

	var strategist: Dictionary = UnitRole._coefficients.get("strategist", {}) as Dictionary
	assert_float(strategist.get("class_mag_def_mult", -1.0) as float).override_failure_message(
		"AC-5: strategist.class_mag_def_mult expected 1.2 (GDD F-2)"
	).is_equal(1.2)


## AC-5: Commander ATK multiplier (GDD F-1: 0.8 — intentionally low; value is Rally).
func test_load_coefficients_schema_completeness_commander_atk_mult() -> void:
	UnitRole._load_coefficients(_PROD_PATH)

	var commander: Dictionary = UnitRole._coefficients.get("commander", {}) as Dictionary
	assert_float(commander.get("class_atk_mult", -1.0) as float).override_failure_message(
		"AC-5: commander.class_atk_mult expected 0.8 (GDD F-1)"
	).is_equal(0.8)


## AC-5: Scout initiative multiplier and FOREST terrain cost (GDD F-4: 1.2; GDD CR-4: ×0.7).
func test_load_coefficients_schema_completeness_scout_init_and_forest() -> void:
	UnitRole._load_coefficients(_PROD_PATH)

	var scout: Dictionary = UnitRole._coefficients.get("scout", {}) as Dictionary
	assert_float(scout.get("class_init_mult", -1.0) as float).override_failure_message(
		"AC-5: scout.class_init_mult expected 1.2 (GDD F-4)"
	).is_equal(1.2)

	# terrain_cost_table[3] = FOREST (GDD CR-4: ×0.7 — Scout's defining terrain advantage)
	var scout_terrain: Array = scout.get("terrain_cost_table", []) as Array
	assert_float(scout_terrain[3] as float).override_failure_message(
		"AC-5: scout.terrain_cost_table[3] (FOREST) expected 0.7 (GDD CR-4 EC-5)"
	).is_equal(0.7)
