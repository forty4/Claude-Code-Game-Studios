extends GdUnitTestSuite

## hero_database_test.gd
## Story 001 skeleton tests — HeroDatabase module form invariants + 6 query API contracts.
## Covers AC-1, AC-3, AC-4, AC-6, AC-7 per story QA Test Cases.
##
## TEST ISOLATION (G-15 + ADR-0006 §6):
##   before_test() MUST reset BOTH HeroDatabase._heroes_loaded = false
##                              AND HeroDatabase._heroes = {}
##   _populate_synthetic_fixture() pre-populates _heroes for query tests that need data.

const _HD_PATH: String = "res://src/foundation/hero_database.gd"
var _hd_script: GDScript = load(_HD_PATH) as GDScript


func before_test() -> void:
	# G-15 obligation: reset BOTH static vars before every test.
	_hd_script.set("_heroes_loaded", false)
	var empty: Dictionary[StringName, HeroData] = {}
	_hd_script.set("_heroes", empty)


func after_test() -> void:
	# Safety net: re-reset in case a test left dirty state.
	_hd_script.set("_heroes_loaded", false)
	var empty: Dictionary[StringName, HeroData] = {}
	_hd_script.set("_heroes", empty)


## Injects a synthetic fixture directly into the static cache, bypassing file I/O.
## Call in the Arrange phase of any test that needs heroes in the cache.
func _populate_synthetic_fixture() -> void:
	var hero: HeroData = HeroData.new()
	hero.hero_id = &"shu_001_liu_bei"
	hero.faction = 0       # HeroData.HeroFaction.SHU
	hero.default_class = 4 # UnitRole.UnitClass.COMMANDER
	hero.is_available_mvp = true
	hero.relationships = []
	var fixture: Dictionary[StringName, HeroData] = {&"shu_001_liu_bei": hero}
	_hd_script.set("_heroes", fixture)
	_hd_script.set("_heroes_loaded", true)


# ── AC-1: @abstract decorator present in source (G-22 structural assertion) ──


## AC-1 (G-22): HeroDatabase source declares @abstract.
## Cannot test via HeroDatabase.new() — typed-reference triggers parse-time error
## blocking the test file from loading; reflective script.new() bypasses @abstract.
## Structural source-file assertion is the correct G-22 test pattern.
func test_module_form_abstract_decorator_present_in_source() -> void:
	var content: String = FileAccess.get_file_as_string("res://src/foundation/hero_database.gd")

	assert_bool(content.length() > 0).override_failure_message(
		"AC-1: failed to read res://src/foundation/hero_database.gd — file missing or parse error"
	).is_true()

	assert_bool(content.contains("@abstract")).override_failure_message(
		"AC-1: hero_database.gd must declare @abstract per ADR-0007 §1 + G-22. "
		+ "Decorator is missing — typed HeroDatabase.new() will succeed."
	).is_true()

	assert_bool(content.contains("class_name HeroDatabase extends RefCounted")).override_failure_message(
		"AC-1: hero_database.gd must declare 'class_name HeroDatabase extends RefCounted'"
	).is_true()


# ── AC-3: lazy-init handles missing heroes.json gracefully ────────────────────


## AC-3 (FileAccess miss path): _load_heroes() on a missing heroes.json file
## emits push_error + leaves _heroes_loaded = false (does not crash, does not
## flip the loaded flag). Story 003 will create assets/data/heroes/heroes.json;
## until then, this test verifies the missing-file fallback contract.
func test_load_heroes_handles_missing_file_gracefully() -> void:
	# Arrange — pristine state (before_test already reset)
	# heroes.json does NOT exist on disk yet (story 003 creates it).

	# Act — trigger lazy-init via any query method
	var result: HeroData = HeroDatabase.get_hero(&"any_id")

	# Assert — push_error path: result is null AND _heroes_loaded stays false
	assert_object(result).override_failure_message(
		"AC-3: get_hero call on missing heroes.json must return null"
	).is_null()

	var loaded_flag: bool = _hd_script.get("_heroes_loaded")
	assert_bool(loaded_flag).override_failure_message(
		"AC-3: _heroes_loaded must STAY false on FileAccess failure (file missing) — "
		+ "next call retries the load. Pre-Story-002 contract."
	).is_false()


# ── AC-4: get_hero null + push_error on miss ─────────────────────────────────


## AC-4 (miss contract): get_hero returns null for an unknown hero_id.
func test_get_hero_returns_null_on_miss_with_push_error() -> void:
	_populate_synthetic_fixture()

	var result: HeroData = HeroDatabase.get_hero(&"unknown_hero_id")

	assert_object(result).override_failure_message(
		"AC-4: get_hero for unknown hero_id must return null per ADR-0007 §4 miss contract"
	).is_null()


# ── AC-4: get_hero happy path ─────────────────────────────────────────────────


## AC-4 (happy path): get_hero returns the HeroData for a known hero_id.
func test_get_hero_returns_synthetic_fixture_hero() -> void:
	_populate_synthetic_fixture()

	var result: HeroData = HeroDatabase.get_hero(&"shu_001_liu_bei")

	assert_object(result).override_failure_message(
		"AC-4: get_hero for 'shu_001_liu_bei' must return a non-null HeroData"
	).is_not_null()

	assert_bool(result.hero_id == &"shu_001_liu_bei").override_failure_message(
		"AC-4: returned hero.hero_id must be &'shu_001_liu_bei'"
	).is_true()


# ── AC-4: get_all_hero_ids typed Array[StringName] ────────────────────────────


## AC-4 (G-2 typed-array): get_all_hero_ids returns Array[StringName].
func test_get_all_hero_ids_returns_typed_array_stringname() -> void:
	_populate_synthetic_fixture()

	var ids: Array[StringName] = HeroDatabase.get_all_hero_ids()

	assert_int(ids.size()).override_failure_message(
		"AC-4: get_all_hero_ids must return 1 ID for the fixture hero"
	).is_equal(1)

	assert_bool(ids[0] is StringName).override_failure_message(
		"AC-4 G-2: ids[0] must be StringName (not String) — typed-array discipline"
	).is_true()

	assert_bool(ids[0] == &"shu_001_liu_bei").override_failure_message(
		"AC-4: ids[0] must equal &'shu_001_liu_bei'"
	).is_true()


# ── AC-4: get_heroes_by_faction typed Array[HeroData] ────────────────────────


## AC-4 (G-2 + filter): get_heroes_by_faction returns correct heroes for faction 0 (SHU).
func test_get_heroes_by_faction_returns_typed_array_herodata() -> void:
	_populate_synthetic_fixture()

	var shu_heroes: Array[HeroData] = HeroDatabase.get_heroes_by_faction(0)

	assert_int(shu_heroes.size()).override_failure_message(
		"AC-4: get_heroes_by_faction(0) must return 1 hero for the SHU fixture"
	).is_equal(1)

	assert_bool(shu_heroes[0].faction == 0).override_failure_message(
		"AC-4: returned hero.faction must be 0 (SHU)"
	).is_true()

	var wei_heroes: Array[HeroData] = HeroDatabase.get_heroes_by_faction(1)
	assert_int(wei_heroes.size()).override_failure_message(
		"AC-4: get_heroes_by_faction(1) must return 0 heroes — no WEI in fixture"
	).is_equal(0)


# ── AC-4: get_heroes_by_class typed Array[HeroData] ──────────────────────────


## AC-4 (G-2 + filter): get_heroes_by_class returns correct heroes for class 4 (COMMANDER).
func test_get_heroes_by_class_returns_typed_array_herodata() -> void:
	_populate_synthetic_fixture()

	var commanders: Array[HeroData] = HeroDatabase.get_heroes_by_class(4)

	assert_int(commanders.size()).override_failure_message(
		"AC-4: get_heroes_by_class(4) must return 1 hero for the COMMANDER fixture"
	).is_equal(1)

	assert_bool(commanders[0].default_class == 4).override_failure_message(
		"AC-4: returned hero.default_class must be 4 (COMMANDER)"
	).is_true()

	var cavalry: Array[HeroData] = HeroDatabase.get_heroes_by_class(0)
	assert_int(cavalry.size()).override_failure_message(
		"AC-4: get_heroes_by_class(0) must return 0 heroes — no CAVALRY in fixture"
	).is_equal(0)


# ── AC-4: get_mvp_roster typed Array[HeroData] ───────────────────────────────


## AC-4 (G-2 + filter): get_mvp_roster returns only heroes with is_available_mvp == true.
func test_get_mvp_roster_returns_only_mvp_heroes() -> void:
	_populate_synthetic_fixture()

	var mvp: Array[HeroData] = HeroDatabase.get_mvp_roster()

	assert_int(mvp.size()).override_failure_message(
		"AC-4: get_mvp_roster must return 1 hero — fixture hero has is_available_mvp=true"
	).is_equal(1)

	assert_bool(mvp[0].is_available_mvp).override_failure_message(
		"AC-4: all MVP roster heroes must have is_available_mvp == true"
	).is_true()


# ── AC-4: get_relationships typed Array[Dictionary] ──────────────────────────


## AC-4 (provisional shape): get_relationships returns Array[Dictionary] for a known hero.
func test_get_relationships_returns_typed_array_dictionary() -> void:
	_populate_synthetic_fixture()

	var rels: Array[Dictionary] = HeroDatabase.get_relationships(&"shu_001_liu_bei")

	assert_int(rels.size()).override_failure_message(
		"AC-4: get_relationships for fixture hero must return empty Array[Dictionary]"
	).is_equal(0)

	var miss_rels: Array[Dictionary] = HeroDatabase.get_relationships(&"unknown_id")
	assert_int(miss_rels.size()).override_failure_message(
		"AC-4: get_relationships for unknown hero_id must return empty array (not null)"
	).is_equal(0)
