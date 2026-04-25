extends GdUnitTestSuite

## terrain_effect_config_test.gd
## Unit tests for Story 003 (terrain-effect epic): load_config() full implementation,
## _validate_config(), _apply_config(), and _fall_back_to_defaults().
##
## Covers AC-1 through AC-8 from story-003 §Acceptance Criteria.
##
## Governing ADR: ADR-0008 Terrain Effect System (Accepted 2026-04-25).
## Related TRs:   TR-terrain-effect-012, TR-terrain-effect-014.
##
## ISOLATION DISCIPLINE (ADR-0008 §Notes §1 + §Risks line 562):
##   before_test() calls TerrainEffect.reset_for_tests() unconditionally so that
##   each test starts from pristine defaults regardless of prior state.
##   Tests AC-3..AC-7 write per-test fixtures to user:// and clean up in after_test().
##   NOTE: must be `before_test()` (canonical GdUnit4 v6.1.2 hook); `before_each()` is
##   silently ignored by the runner (gotcha G-15).
##
## STATIC-VAR INSPECTION PATTERN:
##   Static vars are read via (load(PATH) as GDScript).get("_var") per the
##   save_migration_registry_test.gd precedent (established project pattern).
##
## LOG-OUTPUT ASSERTION LIMITATION:
##   GdUnit4 v6.1.2 provides no hook to capture or assert on push_error/push_warning
##   output. Tests verify side effects (return value + fallback table state) instead
##   of diagnostic message content. Message-format regressions are out of automated
##   coverage; manual log review is the fallback channel.
##
## USER:// FIXTURE CLEANUP:
##   Each invalid-config test (AC-3..7) writes a fixture to user:// and removes
##   it in after_test() via DirAccess.remove_absolute(). The _fixture_path var
##   tracks which file to remove; it is set to "" in before_test() and each
##   test sets it before writing.

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


## Writes content to user://<filename>, records the absolute path for cleanup,
## and returns the user:// path for passing to load_config().
func _write_fixture(filename: String, content: String) -> String:
	var fa: FileAccess = FileAccess.open("user://" + filename, FileAccess.WRITE)
	fa.store_string(content)
	fa.close()
	_fixture_path = ProjectSettings.globalize_path("user://" + filename)
	return "user://" + filename


# ── AC-1: Real config loads successfully ─────────────────────────────────────


## AC-1: Production fixture at default path loads successfully and populates state.
## Given: production fixture at res://assets/data/terrain/terrain_config.json;
##        reset_for_tests() called in before_each().
## When:  TerrainEffect.load_config() called with default path.
## Then:  returns true; _config_loaded==true; _terrain_table.size()==8;
##        _elevation_table.size()==5; _max_defense_reduction==30; _max_evasion==30;
##        _evasion_weight≈1.2; _max_possible_score≈43.0; _cost_default_multiplier==1.
func test_terrain_effect_config_real_config_loads_successfully() -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript

	# Act
	var result: bool = TerrainEffect.load_config()

	# Assert — return value
	assert_bool(result).override_failure_message(
		"load_config() must return true for the production fixture; got false"
	).is_true()

	# Assert — _config_loaded
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"_config_loaded must be true after successful load"
	).is_true()

	# Assert — table sizes
	assert_int((script.get("_terrain_table") as Dictionary).size()).override_failure_message(
		("_terrain_table must have 8 entries after load; got %d")
		% (script.get("_terrain_table") as Dictionary).size()
	).is_equal(8)

	assert_int((script.get("_elevation_table") as Dictionary).size()).override_failure_message(
		("_elevation_table must have 5 entries after load; got %d")
		% (script.get("_elevation_table") as Dictionary).size()
	).is_equal(5)

	# Assert — caps
	assert_int(script.get("_max_defense_reduction") as int).override_failure_message(
		("_max_defense_reduction must be 30 from config; got %d")
		% (script.get("_max_defense_reduction") as int)
	).is_equal(30)

	assert_int(script.get("_max_evasion") as int).override_failure_message(
		("_max_evasion must be 30 from config; got %d")
		% (script.get("_max_evasion") as int)
	).is_equal(30)

	# Assert — ai_scoring
	assert_float(script.get("_evasion_weight") as float).override_failure_message(
		("_evasion_weight must be approx 1.2 from config; got %f")
		% (script.get("_evasion_weight") as float)
	).is_equal_approx(1.2, 0.00001)

	assert_float(script.get("_max_possible_score") as float).override_failure_message(
		("_max_possible_score must be approx 43.0 from config; got %f")
		% (script.get("_max_possible_score") as float)
	).is_equal_approx(43.0, 0.00001)

	# Assert — cost_matrix
	assert_int(script.get("_cost_default_multiplier") as int).override_failure_message(
		("_cost_default_multiplier must be 1 from config; got %d")
		% (script.get("_cost_default_multiplier") as int)
	).is_equal(1)


# ── AC-2: Tuned value flows through ──────────────────────────────────────────


## AC-2 (GDD AC-19): Config-driven tuning — HILLS defense_bonus tuned 15→20 flows through.
## Given: user:// fixture with HILLS defense_bonus: 20 (all other fields canonical).
## When:  reset_for_tests() + load_config(fixture_path).
## Then:  returns true; _terrain_table[HILLS].defense_bonus == 20.
## Validates the data-driven promise: tuning happens in JSON, not in code.
func test_terrain_effect_config_tuned_value_flows_through() -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript
	var json_tuned: String = """{
  "schema_version": 1,
  "terrain_modifiers": {
    "0": { "name": "PLAINS",        "defense_bonus": 0,  "evasion_bonus": 0,  "special_rules": [] },
    "1": { "name": "FOREST",        "defense_bonus": 5,  "evasion_bonus": 15, "special_rules": [] },
    "2": { "name": "HILLS",         "defense_bonus": 20, "evasion_bonus": 0,  "special_rules": [] },
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
  "cost_matrix": { "default_multiplier": 1 }
}"""
	var fixture_path: String = _write_fixture("test_terrain_config_tuned.json", json_tuned)

	# Act
	var result: bool = TerrainEffect.load_config(fixture_path)

	# Assert — load succeeded
	assert_bool(result).override_failure_message(
		"load_config() must return true for tuned fixture"
	).is_true()

	# Assert — HILLS entry reflects tuned value
	var terrain_table: Dictionary = script.get("_terrain_table") as Dictionary
	assert_bool(terrain_table.has(TerrainEffect.HILLS)).override_failure_message(
		"_terrain_table must contain HILLS key after load"
	).is_true()

	var hills_mod: TerrainModifiers = terrain_table[TerrainEffect.HILLS] as TerrainModifiers
	assert_int(hills_mod.defense_bonus).override_failure_message(
		("_terrain_table[HILLS].defense_bonus must be 20 (tuned value); got %d")
		% hills_mod.defense_bonus
	).is_equal(20)


# ── AC-3: Malformed JSON falls back ──────────────────────────────────────────


## AC-3: Malformed JSON triggers push_error + fallback; game remains playable.
## Given: malformed JSON (truncated/unclosed brace) at user:// fixture path.
## When:  load_config(fixture_path).
## Then:  returns false; _config_loaded==true (set by fallback);
##        _terrain_table.size()==8 (canonical fallback values);
##        _max_defense_reduction==30 (compile-time default preserved).
func test_terrain_effect_config_malformed_json_falls_back() -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript
	# Definitively malformed: truncated at mid-string — Godot's JSON parser cannot accept this.
	var malformed: String = '{ "schema_version": 1, '
	var fixture_path: String = _write_fixture("test_terrain_config_malformed.json", malformed)

	# Act
	var result: bool = TerrainEffect.load_config(fixture_path)

	# Assert — returns false (parse failure)
	assert_bool(result).override_failure_message(
		"load_config() must return false for malformed JSON"
	).is_false()

	# Assert — fallback sets _config_loaded=true (prevents re-parse loops)
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"_config_loaded must be true after fallback (prevents re-parse loops)"
	).is_true()

	# Assert — fallback populates canonical values (game remains playable)
	assert_int((script.get("_terrain_table") as Dictionary).size()).override_failure_message(
		("_terrain_table must have 8 canonical fallback entries after malformed JSON; got %d")
		% (script.get("_terrain_table") as Dictionary).size()
	).is_equal(8)

	assert_int(script.get("_max_defense_reduction") as int).override_failure_message(
		"_max_defense_reduction must be 30 (compile-time default) after fallback"
	).is_equal(30)


# ── AC-4: Missing terrain key falls back ─────────────────────────────────────


## AC-4 (GDD AC-20): Validation rejects missing terrain_modifiers["3"] (MOUNTAIN).
## Given: fixture missing the MOUNTAIN entry (key "3").
## When:  load_config(fixture_path).
## Then:  returns false; _config_loaded==true; _terrain_table.size()==8 (fallback).
func test_terrain_effect_config_missing_terrain_key_falls_back() -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript
	# Valid in every way except "3" (MOUNTAIN) is omitted.
	var json_no_mountain: String = """{
  "schema_version": 1,
  "terrain_modifiers": {
    "0": { "name": "PLAINS",        "defense_bonus": 0,  "evasion_bonus": 0,  "special_rules": [] },
    "1": { "name": "FOREST",        "defense_bonus": 5,  "evasion_bonus": 15, "special_rules": [] },
    "2": { "name": "HILLS",         "defense_bonus": 15, "evasion_bonus": 0,  "special_rules": [] },
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
  "cost_matrix": { "default_multiplier": 1 }
}"""
	var fixture_path: String = _write_fixture("test_terrain_config_missing_mountain.json", json_no_mountain)

	# Act
	var result: bool = TerrainEffect.load_config(fixture_path)

	# Assert
	assert_bool(result).override_failure_message(
		"load_config() must return false when MOUNTAIN (key '3') entry is missing"
	).is_false()

	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"_config_loaded must be true after fallback"
	).is_true()

	assert_int((script.get("_terrain_table") as Dictionary).size()).override_failure_message(
		("_terrain_table must have 8 canonical fallback entries after missing-key rejection;"
		+ " got %d") % (script.get("_terrain_table") as Dictionary).size()
	).is_equal(8)


# ── AC-5: Fractional integer field falls back ─────────────────────────────────


## AC-5 (ADR-0008 §Notes §3): Fractional integer field rejected; silent truncation forbidden.
## Given: fixture with HILLS defense_bonus: 15.5.
## When:  load_config(fixture_path).
## Then:  returns false; _validate_int_field clause 2 fired (v != int(v));
##        fallback invoked; _config_loaded==true; _terrain_table.size()==8.
func test_terrain_effect_config_fractional_integer_falls_back() -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript
	var json_fractional: String = """{
  "schema_version": 1,
  "terrain_modifiers": {
    "0": { "name": "PLAINS",        "defense_bonus": 0,    "evasion_bonus": 0,  "special_rules": [] },
    "1": { "name": "FOREST",        "defense_bonus": 5,    "evasion_bonus": 15, "special_rules": [] },
    "2": { "name": "HILLS",         "defense_bonus": 15.5, "evasion_bonus": 0,  "special_rules": [] },
    "3": { "name": "MOUNTAIN",      "defense_bonus": 20,   "evasion_bonus": 5,  "special_rules": [] },
    "4": { "name": "RIVER",         "defense_bonus": 0,    "evasion_bonus": 0,  "special_rules": [] },
    "5": { "name": "BRIDGE",        "defense_bonus": 5,    "evasion_bonus": 0,  "special_rules": ["bridge_no_flank"] },
    "6": { "name": "FORTRESS_WALL", "defense_bonus": 25,   "evasion_bonus": 0,  "special_rules": [] },
    "7": { "name": "ROAD",          "defense_bonus": 0,    "evasion_bonus": 0,  "special_rules": [] }
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
  "cost_matrix": { "default_multiplier": 1 }
}"""
	var fixture_path: String = _write_fixture("test_terrain_config_fractional.json", json_fractional)

	# Act
	var result: bool = TerrainEffect.load_config(fixture_path)

	# Assert
	assert_bool(result).override_failure_message(
		"load_config() must return false for fractional defense_bonus 15.5"
	).is_false()

	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"_config_loaded must be true after fallback"
	).is_true()

	assert_int((script.get("_terrain_table") as Dictionary).size()).override_failure_message(
		("_terrain_table must have 8 canonical fallback entries after fractional-field rejection;"
		+ " got %d") % (script.get("_terrain_table") as Dictionary).size()
	).is_equal(8)


# ── AC-6: Out-of-range cap falls back ────────────────────────────────────────


## AC-6: Validation rejects cap value exceeding the sanity bound (>50).
## Given: fixture with caps.max_defense_reduction: 51.
## When:  load_config(fixture_path).
## Then:  returns false; fallback invoked; _max_defense_reduction==30
##        (compile-time default, NOT the invalid 51 from the JSON).
func test_terrain_effect_config_out_of_range_cap_falls_back() -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript
	var json_bad_cap: String = """{
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
  "caps": { "max_defense_reduction": 51, "max_evasion": 30 },
  "ai_scoring": { "evasion_weight": 1.2, "max_possible_score": 43.0 },
  "cost_matrix": { "default_multiplier": 1 }
}"""
	var fixture_path: String = _write_fixture("test_terrain_config_bad_cap.json", json_bad_cap)

	# Act
	var result: bool = TerrainEffect.load_config(fixture_path)

	# Assert
	assert_bool(result).override_failure_message(
		"load_config() must return false for caps.max_defense_reduction == 51 (sanity bound ≤ 50)"
	).is_false()

	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"_config_loaded must be true after fallback"
	).is_true()

	# _max_defense_reduction must be 30 (compile-time default), not the invalid 51.
	assert_int(script.get("_max_defense_reduction") as int).override_failure_message(
		("_max_defense_reduction must be 30 (compile-time default) after fallback;"
		+ " got %d") % (script.get("_max_defense_reduction") as int)
	).is_equal(30)


# ── AC-7: Wrong schema_version falls back ─────────────────────────────────────


## AC-7: Validation rejects schema_version != 1.
## Given: fixture with schema_version: 2.
## When:  load_config(fixture_path).
## Then:  returns false; fallback invoked; _terrain_table.size()==8.
func test_terrain_effect_config_wrong_schema_version_falls_back() -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript
	var json_v2: String = """{
  "schema_version": 2,
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
  "cost_matrix": { "default_multiplier": 1 }
}"""
	var fixture_path: String = _write_fixture("test_terrain_config_v2.json", json_v2)

	# Act
	var result: bool = TerrainEffect.load_config(fixture_path)

	# Assert
	assert_bool(result).override_failure_message(
		"load_config() must return false for schema_version == 2"
	).is_false()

	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"_config_loaded must be true after fallback"
	).is_true()

	assert_int((script.get("_terrain_table") as Dictionary).size()).override_failure_message(
		("_terrain_table must have 8 canonical fallback entries after schema_version rejection;"
		+ " got %d") % (script.get("_terrain_table") as Dictionary).size()
	).is_equal(8)


# ── AC-8: Idempotent guard preserved through full implementation ──────────────


## AC-8: load_config() idempotent guard preserved through the full implementation.
## Given: reset_for_tests(); load_config() called once successfully (production fixture).
## When:  static state is mutated via the GDScript seam, then load_config() called again.
## Then:  returns true immediately (guard); the seam-mutated value is PRESERVED — proving
##        the guard short-circuits before _apply_config re-runs (story spec §AC-8 line 152-153).
func test_terrain_effect_config_idempotent_guard_preserved() -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript

	# First call — succeeds, loads production fixture
	var result_first: bool = TerrainEffect.load_config()
	assert_bool(result_first).override_failure_message(
		"First load_config() call must return true (production fixture)"
	).is_true()

	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"_config_loaded must be true after first successful load"
	).is_true()

	assert_int((script.get("_terrain_table") as Dictionary).size()).override_failure_message(
		"_terrain_table must have 8 entries after first load"
	).is_equal(8)

	# Mutate _max_defense_reduction to a sentinel via the GDScript seam — proves
	# that a subsequent load_config() does NOT re-run _apply_config (which would
	# overwrite the sentinel back to 30). This is the canonical "proof of short-circuit"
	# pattern called out in story-003 §AC-8 (line 152-153).
	const SENTINEL_CAP: int = 99
	script.set("_max_defense_reduction", SENTINEL_CAP)

	# Second call — idempotent guard fires, returns true without re-parsing
	var result_second: bool = TerrainEffect.load_config()
	assert_bool(result_second).override_failure_message(
		"Second load_config() call must return true (idempotent guard)"
	).is_true()

	# State is preserved from first load (table size + flag)
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"_config_loaded must still be true after idempotent second call"
	).is_true()

	assert_int((script.get("_terrain_table") as Dictionary).size()).override_failure_message(
		("_terrain_table must still have 8 entries after idempotent second call;"
		+ " got %d") % (script.get("_terrain_table") as Dictionary).size()
	).is_equal(8)

	# CRITICAL: sentinel preserved → proves _apply_config did NOT re-run.
	# If _apply_config had re-run, _max_defense_reduction would be 30 (canonical), not 99.
	assert_int(script.get("_max_defense_reduction") as int).override_failure_message(
		("Idempotent guard must short-circuit BEFORE _apply_config — _max_defense_reduction"
		+ " sentinel %d must be preserved on second call (got %d). If this fails, the guard"
		+ " is not actually short-circuiting; it's re-applying the config.")
		% [SENTINEL_CAP, script.get("_max_defense_reduction") as int]
	).is_equal(SENTINEL_CAP)


# ── AC-9 (R-1 follow-up): File-not-found / empty-file falls back ──────────────


## AC-9 (file-not-found path coverage; closes story-003 /code-review GAP-2).
## The implementation has TWO distinct pre-parse failure paths in load_config():
##   (1) `text.is_empty()` after FileAccess.get_file_as_string (lines ~152-155)
##   (2) `err != OK` after JSON.new().parse() (lines ~158-167)
## AC-3 covers path (2) via a malformed string. This test covers path (1) via a
## non-existent path — protects against shipped builds with missing assets.
##
## Given: a path to a fixture file that DOES NOT exist on disk.
## When:  load_config(nonexistent_path) called.
## Then:  returns false; _config_loaded == true (fallback ran); _terrain_table.size() == 8;
##        _max_defense_reduction == 30 (compile-time default preserved by fallback).
func test_terrain_effect_config_file_not_found_falls_back() -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript
	# Use a path with a clearly nonexistent filename — do NOT _write_fixture.
	# DirAccess in after_test() is a no-op when _fixture_path is empty (which is the
	# default state from before_test()), so leaving _fixture_path = "" is safe.
	var nonexistent_path: String = "user://test_terrain_config_nonexistent_xyz123.json"

	# Act
	var result: bool = TerrainEffect.load_config(nonexistent_path)

	# Assert — returns false (file-not-found path)
	assert_bool(result).override_failure_message(
		"load_config() must return false when path does not exist"
	).is_false()

	# Assert — fallback fired (idempotent guard now armed)
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"_config_loaded must be true after file-not-found fallback"
	).is_true()

	# Assert — fallback table is canonical (game remains playable per Pillar 1)
	assert_int((script.get("_terrain_table") as Dictionary).size()).override_failure_message(
		("_terrain_table must have 8 canonical fallback entries after file-not-found;"
		+ " got %d") % (script.get("_terrain_table") as Dictionary).size()
	).is_equal(8)

	# Assert — caps preserved at compile-time defaults
	assert_int(script.get("_max_defense_reduction") as int).override_failure_message(
		"_max_defense_reduction must be 30 (compile-time default) after fallback"
	).is_equal(30)
