extends GdUnitTestSuite

## hero_database_mvp_roster_test.gd
## Story 003 — MVP roster authoring + happy-path integration test.
## Covers AC-1 through AC-9 per story-003 QA Test Cases.
##
## Integration scope: exercises the real heroes.json on disk (assets/data/heroes/heroes.json)
## through the full HeroDatabase lazy-load pipeline. No synthetic fixtures — tests prove
## that the authored roster satisfies all roster invariants and all public API queries.
##
## TEST ISOLATION (G-15 + ADR-0006 §6):
##   before_test() resets BOTH HeroDatabase._heroes_loaded = false
##                          AND HeroDatabase._heroes = {}
##   This forces a fresh file-read for each test that calls any HeroDatabase method.
##
## GOTCHAS APPLIED:
##   G-15 — before_test() / after_test() (NOT before_each)
##   G-2  — typed arrays: Array[Dictionary], Array[StringName]
##   G-7  — verify Overall Summary count; grep stderr for Parse Error / Failed to load
##   G-22 — _hd_script reflective pattern for static-var reset
##   G-23 — no is_not_equal_approx; use is_not_equal for exact
##   G-24 — wrap `as Type` casts in parens on RHS of ==
##   G-20 — StringName/String coercion at == is real; assert structural shape, not type rejection
##   G-14 — godot --headless --import --path . run before first test run

const _HD_PATH: String = "res://src/foundation/hero_database.gd"
const _HEROES_JSON_PATH: String = "res://assets/data/heroes/heroes.json"

## Canonical 26 field names per ADR-0007 §2 hero_data schema.
## Used by AC-5 to verify no missing and no extra fields per record.
const _CANONICAL_FIELDS: Array[String] = [
	"hero_id",
	"name_ko",
	"name_zh",
	"name_courtesy",
	"faction",
	"portrait_id",
	"battle_sprite_id",
	"stat_might",
	"stat_intellect",
	"stat_command",
	"stat_agility",
	"base_hp_seed",
	"base_initiative_seed",
	"move_range",
	"default_class",
	"equipment_slot_override",
	"growth_might",
	"growth_intellect",
	"growth_command",
	"growth_agility",
	"innate_skill_ids",
	"skill_unlock_levels",
	"join_chapter",
	"join_condition_tag",
	"is_available_mvp",
	"relationships",
]

var _hd_script: GDScript = load(_HD_PATH) as GDScript


# ── G-15: per-test isolation reset ───────────────────────────────────────────


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


# ── JSON helper ───────────────────────────────────────────────────────────────


## Reads and parses heroes.json; returns the top-level Dictionary.
## Returns empty Dictionary on any read/parse failure — callers detect via .is_empty().
func _parse_heroes_json() -> Dictionary:
	var raw_text: String = FileAccess.get_file_as_string(_HEROES_JSON_PATH)
	if raw_text.is_empty():
		return {}
	var json: JSON = JSON.new()
	if json.parse(raw_text) != OK:
		return {}
	return json.data as Dictionary


# ── AC-1: heroes.json parses cleanly ─────────────────────────────────────────


## AC-1: heroes.json file exists, JSON.parse succeeds, and top-level value is a Dictionary.
func test_heroes_json_parses_cleanly_top_level_dict() -> void:
	var raw_text: String = FileAccess.get_file_as_string(_HEROES_JSON_PATH)

	assert_bool(raw_text.is_empty()).override_failure_message(
		"AC-1: heroes.json must exist and be non-empty at %s" % _HEROES_JSON_PATH
	).is_false()

	var json: JSON = JSON.new()
	assert_int(json.parse(raw_text)).override_failure_message(
		("AC-1: JSON.parse must return OK for heroes.json. "
		+ "Error at line %d: %s") % [json.get_error_line(), json.get_error_message()]
	).is_equal(OK)

	assert_bool(json.data is Dictionary).override_failure_message(
		"AC-1: parsed heroes.json top-level value must be a Dictionary"
	).is_true()


# ── AC-2: record count in [8, 10] ────────────────────────────────────────────


## AC-2: MVP roster record count must be within [8, 10] inclusive.
func test_record_count_within_mvp_bounds_8_to_10() -> void:
	var heroes: Dictionary = _parse_heroes_json()

	assert_bool(heroes.is_empty()).override_failure_message(
		"AC-2 precondition: heroes.json must parse cleanly before checking record count"
	).is_false()

	var count: int = heroes.size()
	assert_bool(count >= 8).override_failure_message(
		"AC-2: record count %d must be >= 8" % count
	).is_true()

	assert_bool(count <= 10).override_failure_message(
		"AC-2: record count %d must be <= 10" % count
	).is_true()


# ── AC-3: 4-faction coverage SHU/WEI/WU/QUNXIONG ────────────────────────────


## AC-3: all 4 factions (0=SHU, 1=WEI, 2=WU, 3=QUNXIONG) must appear in the roster.
func test_4_faction_coverage_shu_wei_wu_qunxiong() -> void:
	var heroes: Dictionary = _parse_heroes_json()
	var factions_present: Dictionary[int, bool] = {}

	for hero_id: String in heroes:
		var record: Dictionary = heroes[hero_id] as Dictionary
		var faction: int = record.get("faction", -1) as int
		factions_present[faction] = true

	for required_faction: int in [0, 1, 2, 3]:
		assert_bool(factions_present.has(required_faction)).override_failure_message(
			"AC-3: faction %d must be present in the MVP roster" % required_faction
		).is_true()


# ── AC-4: all records have is_available_mvp = true ───────────────────────────


## AC-4: every record in heroes.json must have is_available_mvp = true.
func test_all_records_flag_is_available_mvp_true() -> void:
	var heroes: Dictionary = _parse_heroes_json()

	for hero_id: String in heroes:
		var record: Dictionary = heroes[hero_id] as Dictionary
		assert_bool((record.get("is_available_mvp", false) as bool)).override_failure_message(
			"AC-4: hero '%s' must have is_available_mvp = true" % hero_id
		).is_true()


# ── AC-5: every record has exactly 26 canonical fields ───────────────────────


## AC-5: each record must contain exactly the 26 canonical field names — no missing, no extras.
## Asserts expected_keys.size() == 26 first to guard against a stale constant.
func test_every_record_has_26_canonical_fields_no_extras() -> void:
	# Guard: the constant itself must have exactly 26 entries.
	assert_int(_CANONICAL_FIELDS.size()).override_failure_message(
		"AC-5 guard: _CANONICAL_FIELDS constant must have exactly 26 entries"
	).is_equal(26)

	var heroes: Dictionary = _parse_heroes_json()

	for hero_id: String in heroes:
		var record: Dictionary = heroes[hero_id] as Dictionary

		# Check no missing fields.
		for field: String in _CANONICAL_FIELDS:
			assert_bool(record.has(field)).override_failure_message(
				"AC-5: hero '%s' is missing required field '%s'" % [hero_id, field]
			).is_true()

		# Check no extra fields.
		for key: String in record.keys():
			assert_bool(_CANONICAL_FIELDS.has(key)).override_failure_message(
				"AC-5: hero '%s' has unexpected extra field '%s'" % [hero_id, key]
			).is_true()

		# Check count matches exactly.
		assert_int(record.size()).override_failure_message(
			"AC-5: hero '%s' record has %d fields; expected exactly 26" % [hero_id, record.size()]
		).is_equal(26)


# ── AC-6: default_class within unit class enum range [0, 5] ──────────────────


## AC-6: every record's default_class must be an int within [0, 5] inclusive.
func test_default_class_int_within_unit_class_enum_range() -> void:
	var heroes: Dictionary = _parse_heroes_json()

	for hero_id: String in heroes:
		var record: Dictionary = heroes[hero_id] as Dictionary
		var cls: int = record.get("default_class", -1) as int

		assert_bool(cls >= 0).override_failure_message(
			"AC-6: hero '%s' default_class %d must be >= 0" % [hero_id, cls]
		).is_true()

		assert_bool(cls <= 5).override_failure_message(
			"AC-6: hero '%s' default_class %d must be <= 5" % [hero_id, cls]
		).is_true()


# ── AC-7: full pipeline load passes for the authored roster ──────────────────


## AC-7: calling HeroDatabase.get_all_hero_ids() against the real heroes.json must succeed.
## Verifies _heroes_loaded == true and _heroes.size() == record count from JSON.
func test_load_heroes_pipeline_passes_for_authored_roster() -> void:
	var json_heroes: Dictionary = _parse_heroes_json()
	var expected_count: int = json_heroes.size()

	# Trigger lazy load via public API.
	var ids: Array[StringName] = HeroDatabase.get_all_hero_ids()

	assert_bool((_hd_script.get("_heroes_loaded") as bool)).override_failure_message(
		"AC-7: _heroes_loaded must be true after loading the authored heroes.json"
	).is_true()

	assert_int(ids.size()).override_failure_message(
		("AC-7: loaded hero count %d must match heroes.json record count %d")
		% [ids.size(), expected_count]
	).is_equal(expected_count)


# ── AC-8: relationships round-trip — 4-field shape ───────────────────────────


## AC-8: records with non-empty relationships must have all 4 required keys per entry.
## Also verifies HeroDatabase.get_relationships(&"shu_001_liu_bei") returns >= 2 entries.
func test_relationships_round_trip_4_field_shape() -> void:
	var heroes: Dictionary = _parse_heroes_json()
	var records_with_rels: int = 0

	for hero_id: String in heroes:
		var record: Dictionary = heroes[hero_id] as Dictionary
		var rels: Array = record.get("relationships", []) as Array

		if rels.size() == 0:
			continue

		records_with_rels += 1
		for rel_entry: Dictionary in rels:
			assert_bool(rel_entry.has("hero_b_id")).override_failure_message(
				"AC-8: hero '%s' relationship entry missing 'hero_b_id'" % hero_id
			).is_true()
			assert_bool(rel_entry.has("relation_type")).override_failure_message(
				"AC-8: hero '%s' relationship entry missing 'relation_type'" % hero_id
			).is_true()
			assert_bool(rel_entry.has("effect_tag")).override_failure_message(
				"AC-8: hero '%s' relationship entry missing 'effect_tag'" % hero_id
			).is_true()
			assert_bool(rel_entry.has("is_symmetric")).override_failure_message(
				"AC-8: hero '%s' relationship entry missing 'is_symmetric'" % hero_id
			).is_true()

	assert_bool(records_with_rels >= 2).override_failure_message(
		"AC-8: at least 2 records must have non-empty relationships; found %d" % records_with_rels
	).is_true()

	# Verify via HeroDatabase public API: Liu Bei must have >= 2 sworn-brother entries.
	var liu_bei_rels: Array[Dictionary] = HeroDatabase.get_relationships(&"shu_001_liu_bei")
	assert_bool(liu_bei_rels.size() >= 2).override_failure_message(
		("AC-8: HeroDatabase.get_relationships(&'shu_001_liu_bei') must return >= 2 entries; "
		+ "got %d") % liu_bei_rels.size()
	).is_true()


# ── AC-9.1: get_hero returns correct Liu Bei record ──────────────────────────


## AC-9.1: HeroDatabase.get_hero(&"shu_001_liu_bei") returns non-null record
## with faction == 0 and hero_id == &"shu_001_liu_bei".
func test_get_hero_returns_canonical_liu_bei_record() -> void:
	var hero: HeroData = HeroDatabase.get_hero(&"shu_001_liu_bei")

	assert_object(hero).override_failure_message(
		"AC-9.1: HeroDatabase.get_hero(&'shu_001_liu_bei') must return non-null HeroData"
	).is_not_null()

	assert_int(hero.faction).override_failure_message(
		"AC-9.1: Liu Bei's faction must be 0 (SHU)"
	).is_equal(0)

	assert_bool(hero.hero_id == &"shu_001_liu_bei").override_failure_message(
		"AC-9.1: Liu Bei's hero_id must equal &'shu_001_liu_bei'"
	).is_true()


# ── AC-9.2: get_mvp_roster returns full record count ─────────────────────────


## AC-9.2: HeroDatabase.get_mvp_roster() must return all records (all have is_available_mvp=true).
func test_get_mvp_roster_returns_full_record_count() -> void:
	var json_heroes: Dictionary = _parse_heroes_json()
	var expected_count: int = json_heroes.size()

	var roster: Array[HeroData] = HeroDatabase.get_mvp_roster()

	assert_int(roster.size()).override_failure_message(
		("AC-9.2: get_mvp_roster must return %d heroes (all have is_available_mvp=true); "
		+ "got %d") % [expected_count, roster.size()]
	).is_equal(expected_count)


# ── AC-9.3: get_heroes_by_faction returns at least one SHU hero ──────────────


## AC-9.3: HeroDatabase.get_heroes_by_faction(0) must return at least one SHU hero.
func test_get_heroes_by_faction_shu_returns_at_least_one() -> void:
	var shu_heroes: Array[HeroData] = HeroDatabase.get_heroes_by_faction(0)

	assert_bool(shu_heroes.size() >= 1).override_failure_message(
		("AC-9.3: get_heroes_by_faction(0) must return >= 1 SHU hero; "
		+ "got %d") % shu_heroes.size()
	).is_true()


# ── AC-9.4: get_heroes_by_class returns at least one INFANTRY hero ────────────


## AC-9.4: HeroDatabase.get_heroes_by_class(1) must return at least one INFANTRY hero.
## shu_003_zhang_fei and wei_005_xiahou_dun both have default_class = 1 (INFANTRY).
func test_get_heroes_by_class_infantry_returns_at_least_one() -> void:
	var infantry: Array[HeroData] = HeroDatabase.get_heroes_by_class(1)

	assert_bool(infantry.size() >= 1).override_failure_message(
		("AC-9.4: get_heroes_by_class(1) (INFANTRY) must return >= 1 hero; "
		+ "got %d") % infantry.size()
	).is_true()


# ── AC-9.5: get_all_hero_ids returns typed Array[StringName] of full record count ─


## AC-9.5: get_all_hero_ids() must return a typed Array[StringName] with size == record count.
func test_get_all_hero_ids_returns_typed_array_record_count() -> void:
	var json_heroes: Dictionary = _parse_heroes_json()
	var expected_count: int = json_heroes.size()

	var ids: Array[StringName] = HeroDatabase.get_all_hero_ids()

	assert_int(ids.size()).override_failure_message(
		("AC-9.5: get_all_hero_ids must return %d StringName entries; "
		+ "got %d") % [expected_count, ids.size()]
	).is_equal(expected_count)

	# Verify the array is typed Array[StringName] by checking element access works
	# as StringName. G-20 note: StringName == String coercion is real in Godot 4.6;
	# we assert structural shape (typed access succeeds) not type-rejection at ==.
	for id: StringName in ids:
		assert_bool(id.length() > 0).override_failure_message(
			"AC-9.5: every hero_id StringName in get_all_hero_ids must be non-empty"
		).is_true()
