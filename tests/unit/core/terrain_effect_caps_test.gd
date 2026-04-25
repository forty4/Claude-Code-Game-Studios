extends GdUnitTestSuite

## terrain_effect_caps_test.gd
## Unit tests for Story 007 (terrain-effect epic): max_defense_reduction +
## max_evasion shared accessors.
##
## Covers AC-1 through AC-6 from story-007 §Acceptance Criteria + §QA Test Cases.
##
## Governing ADR: ADR-0008 Terrain Effect System (Accepted 2026-04-25), §Decision 7
##                + GDD §CR-3a/b + TR-terrain-effect-017.
##
## STORY TYPE: Logic — verifies the 2 public accessor methods + their lazy-load
## + idempotent-guard contract + the data-driven config override path.
##
## ISOLATION (ADR-0008 §Risks line 562 + G-15):
##   before_test() calls TerrainEffect.reset_for_tests() unconditionally — every
##   test starts from pristine defaults. AC-2 writes a per-test fixture to user://
##   and cleans up in after_test() (same pattern as terrain_effect_config_test.gd
##   and terrain_cost_migration_test.gd story-006).
##   G-15 reminder: hook MUST be `before_test()`, NOT `before_each()`.

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


## Writes a fixture JSON with cap overrides to [param max_def] / [param max_eva]
## and ALL other fields set to canonical CR-1 / CR-2 / TR-005 values.
## Returns the user:// path.
func _write_caps_fixture(max_def: int, max_eva: int) -> String:
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
  "caps": { "max_defense_reduction": %d, "max_evasion": %d },
  "ai_scoring": { "evasion_weight": 1.2, "max_possible_score": 43.0 },
  "cost_matrix": { "default_multiplier": 1 }
}""") % [max_def, max_eva]
	return _write_fixture("terrain_config_ac2_story007.json", json)


# ── AC-1: Default config caps ────────────────────────────────────────────────


## AC-1: Default config load yields cap = 30 from both accessors.
##
## NOTE: spec's Given says "load_config() (default fixture)" explicitly. This
## test instead exercises the LAZY-LOAD path (first accessor call triggers
## load_config internally), which IS the contract per AC-1/AC-2 §AC checkboxes.
## The explicit-load_config path is exercised by AC-2 (which calls it directly).
func test_terrain_effect_caps_default_config_yields_thirty() -> void:
	# reset already done in before_test; trigger lazy-load implicitly via accessor
	assert_int(TerrainEffect.max_defense_reduction()).override_failure_message(
		"AC-1: max_defense_reduction() must return 30 after default config load"
	).is_equal(30)
	assert_int(TerrainEffect.max_evasion()).override_failure_message(
		"AC-1: max_evasion() must return 30 after default config load"
	).is_equal(30)


# ── AC-2 (TR-017): Tuned config propagates ───────────────────────────────────


## AC-2 (TR-017): tuned caps from config propagate through accessors.
func test_terrain_effect_caps_tuned_config_propagates() -> void:
	# Arrange: fixture overrides caps to 25 / 35
	var fixture_path: String = _write_caps_fixture(25, 35)

	# Act: load custom config (reset_for_tests already done in before_test)
	var load_ok: bool = TerrainEffect.load_config(fixture_path)
	assert_bool(load_ok).override_failure_message(
		"AC-2: load_config() must return true for the AC-2 fixture (all fields valid)"
	).is_true()

	# Assert: accessors reflect tuned values (NOT the compile-time 30 defaults)
	assert_int(TerrainEffect.max_defense_reduction()).override_failure_message(
		"AC-2: max_defense_reduction() must return 25 (tuned), not 30 (default)"
	).is_equal(25)
	assert_int(TerrainEffect.max_evasion()).override_failure_message(
		"AC-2: max_evasion() must return 35 (tuned), not 30 (default)"
	).is_equal(35)


# ── AC-3: Lazy-init triggers load_config on first accessor call ──────────────


## AC-3: max_defense_reduction() lazy-triggers load_config when _config_loaded == false.
func test_terrain_effect_caps_max_defense_reduction_triggers_lazy_load() -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript

	# Precondition: reset_for_tests() in before_test set _config_loaded = false.
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		("AC-3: _config_loaded must be false after reset_for_tests() — "
		+ "before the first max_defense_reduction call")
	).is_false()

	# Act
	var result: int = TerrainEffect.max_defense_reduction()

	# Assert
	assert_int(result).override_failure_message(
		("AC-3: max_defense_reduction() must return 30 (default config); got %d") % result
	).is_equal(30)
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"AC-3: _config_loaded must be true after first max_defense_reduction call"
	).is_true()


## AC-3b (symmetric coverage per AC-5 §AC checkbox + AC-3 Edge Cases):
## max_evasion() lazy-triggers load_config when called as the FIRST accessor.
##
## Without this symmetric test, a future refactor that removes the lazy guard
## from max_evasion() but leaves it in max_defense_reduction() would not be
## caught — the regression count and AC-3 test would still pass while the
## "both accessors must independently trigger" contract is silently broken.
func test_terrain_effect_caps_max_evasion_triggers_lazy_load() -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript

	# Precondition: reset_for_tests() in before_test set _config_loaded = false.
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		("AC-3b: _config_loaded must be false after reset_for_tests() — "
		+ "before the first max_evasion call")
	).is_false()

	# Act
	var result: int = TerrainEffect.max_evasion()

	# Assert
	assert_int(result).override_failure_message(
		("AC-3b: max_evasion() must return 30 (default config); got %d") % result
	).is_equal(30)
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"AC-3b: _config_loaded must be true after first max_evasion call"
	).is_true()


# ── AC-4: Idempotent guard — second accessor does NOT re-parse ───────────────


## AC-4: second accessor call after first does NOT re-trigger load_config.
##
## Strategy: after the first call lazy-loads, mutate _max_defense_reduction
## directly to a sentinel value (99). If the second accessor (max_evasion)
## triggered load_config a second time, the sentinel would be reset to 30
## (because _apply_config restores from the JSON's caps section). If the
## idempotent guard holds, the sentinel survives the second accessor call.
func test_terrain_effect_caps_idempotent_no_second_parse() -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript

	# Trigger first lazy load via max_defense_reduction()
	var first: int = TerrainEffect.max_defense_reduction()
	assert_int(first).is_equal(30)

	# Mutate the runtime value directly to a sentinel (99) to detect re-parse
	script.set("_max_defense_reduction", 99)

	# Call max_evasion() — should hit the idempotent guard and NOT re-trigger load
	var eva: int = TerrainEffect.max_evasion()
	assert_int(eva).override_failure_message(
		"AC-4: max_evasion() must still return 30 after first accessor's lazy load"
	).is_equal(30)

	# Verify _max_defense_reduction sentinel survived (= guard prevented re-parse)
	assert_int(script.get("_max_defense_reduction") as int).override_failure_message(
		("AC-4: _max_defense_reduction must remain 99 (sentinel) — if it reset to 30, "
		+ "the second accessor re-triggered load_config (idempotent guard violated)")
	).is_equal(99)

	# Explicit guard-state assertion: _config_loaded must remain true (sentinel
	# survival proves no re-parse, but spec's "Then" also requires an explicit
	# _config_loaded check — making the guard state visible rather than implicit).
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"AC-4: _config_loaded must be true after both accessor calls (idempotent guard not reset)"
	).is_true()


# ── AC-5: Compile-time consts accessible without triggering load_config ──────


## AC-5: const access does NOT trigger lazy load (bootstrap fallback path).
func test_terrain_effect_caps_compile_time_consts_no_lazy_load() -> void:
	var script: GDScript = load(TERRAIN_EFFECT_PATH) as GDScript

	# Precondition: _config_loaded == false after before_test
	assert_bool(script.get("_config_loaded") as bool).is_false()

	# Read consts directly (no method call → no lazy load)
	assert_int(TerrainEffect.MAX_DEFENSE_REDUCTION_DEFAULT).override_failure_message(
		"AC-5: MAX_DEFENSE_REDUCTION_DEFAULT must equal 30"
	).is_equal(30)
	assert_int(TerrainEffect.MAX_EVASION_DEFAULT).override_failure_message(
		"AC-5: MAX_EVASION_DEFAULT must equal 30"
	).is_equal(30)

	# Verify _config_loaded STILL false (const read does not trigger load)
	assert_bool(script.get("_config_loaded") as bool).override_failure_message(
		"AC-5: _config_loaded must remain false — const access must NOT trigger lazy load"
	).is_false()


# ── AC-6 (Doc-level): Source file header documents cross-system contract ─────


## AC-6: terrain_effect.gd header doc-comment documents the shared-cap convention.
##
## Verifies the file's leading doc-comment block contains the three required
## elements per story §AC-6: (a) Formation Bonus + Damage Calc consumer names,
## (b) static-accessor convention, (c) compile-time-vs-runtime distinction.
##
## NOTE: this is an INTENTIONAL doc-coupling test — it reads the source file's
## text content directly. If this test fails after a header refactor, the fix
## is to restore the cross-system contract language in the header, NOT to
## relax this test. The substring-grep approach is deliberately tight: a
## refactor that removes the contract from this file (e.g., moves it to a
## separate ADR cross-reference) MUST update this test in the same change.
func test_terrain_effect_caps_header_documents_shared_cap_contract() -> void:
	var fa: FileAccess = FileAccess.open(TERRAIN_EFFECT_PATH, FileAccess.READ)
	var content: String = fa.get_as_text()
	fa.close()

	# Take only the leading doc-comment block (everything before `class_name`).
	var class_idx: int = content.find("class_name TerrainEffect")
	assert_int(class_idx).override_failure_message(
		"AC-6 setup: class_name TerrainEffect declaration not found"
	).is_greater(0)
	var header: String = content.substr(0, class_idx)

	# (a) Consumer names
	assert_bool(header.contains("Formation Bonus") and header.contains("Damage Calc")).override_failure_message(
		"AC-6 (a): header must name Formation Bonus AND Damage Calc as cross-system consumers"
	).is_true()

	# (b) Static-accessor convention — must reference both methods by name
	assert_bool(header.contains("max_defense_reduction") and header.contains("max_evasion")).override_failure_message(
		"AC-6 (b): header must reference max_defense_reduction and max_evasion accessors by name"
	).is_true()

	# (c) Compile-time vs runtime distinction
	assert_bool(header.contains("compile-time") or header.contains("BOOTSTRAP") or header.contains("bootstrap")).override_failure_message(
		"AC-6 (c-1): header must reference compile-time or bootstrap (the const fallback role)"
	).is_true()
	assert_bool(header.contains("runtime")).override_failure_message(
		"AC-6 (c-2): header must reference runtime (the post-load_config authoritative value)"
	).is_true()
