## hero_database.gd
## Ratified by ADR-0007 (Accepted 2026-04-30).
##
## TEST ISOLATION: every test that calls any HeroDatabase method MUST reset
##   HeroDatabase._heroes_loaded = false
##   HeroDatabase._heroes = {}
## in before_test() per G-15 + ADR-0006 §6 obligation.
@abstract
class_name HeroDatabase extends RefCounted


const _HEROES_JSON_PATH: String = "res://assets/data/heroes/heroes.json"

static var _heroes_loaded: bool = false
static var _heroes: Dictionary[StringName, HeroData] = {}


## Lazy-init loader. Reads heroes.json on first call; subsequent calls return immediately.
## On FileAccess failure (empty string returned): push_error + _heroes_loaded stays false.
## On JSON parse failure: push_error + _heroes_loaded stays false.
## Story 001 placeholder: NO validation pipeline. Story 002 injects CR-1/CR-2/EC-1/EC-2
## FATAL checks between parse and _heroes population.
static func _load_heroes() -> void:
	if _heroes_loaded:
		return
	var raw_text: String = FileAccess.get_file_as_string(_HEROES_JSON_PATH)
	if raw_text.is_empty():
		push_error(
			"HeroDatabase: failed to read heroes.json at %s" % _HEROES_JSON_PATH
		)
		return
	var json: JSON = JSON.new()
	var parse_err: int = json.parse(raw_text)
	if parse_err != OK:
		push_error(
			("HeroDatabase: JSON parse error at line %d: %s")
			% [json.get_error_line(), json.get_error_message()]
		)
		return
	var raw_records: Dictionary = json.data
	# Story 001 placeholder: NO validation. Story 002 will inject the FATAL pipeline here.
	# Minimal happy-path: every record builds via field-by-field assignment.
	for hero_id_str: String in raw_records:
		var record: Dictionary = raw_records[hero_id_str]
		var hero: HeroData = _build_hero_data_minimal(StringName(hero_id_str), record)
		_heroes[StringName(hero_id_str)] = hero
	_heroes_loaded = true


## Minimal hero construction from JSON record.
## Story 002 replaces this with _build_hero_data() carrying the validation pipeline.
## Accepts all records unconditionally — no range checks, no format validation.
static func _build_hero_data_minimal(hero_id: StringName, record: Dictionary) -> HeroData:
	var hero: HeroData = HeroData.new()
	hero.hero_id = hero_id
	if record.has("name_ko"):
		hero.name_ko = record["name_ko"] as String
	if record.has("name_zh"):
		hero.name_zh = record["name_zh"] as String
	if record.has("name_courtesy"):
		hero.name_courtesy = record["name_courtesy"] as String
	if record.has("faction"):
		hero.faction = record["faction"] as int
	if record.has("portrait_id"):
		hero.portrait_id = record["portrait_id"] as String
	if record.has("battle_sprite_id"):
		hero.battle_sprite_id = record["battle_sprite_id"] as String
	if record.has("stat_might"):
		hero.stat_might = record["stat_might"] as int
	if record.has("stat_intellect"):
		hero.stat_intellect = record["stat_intellect"] as int
	if record.has("stat_command"):
		hero.stat_command = record["stat_command"] as int
	if record.has("stat_agility"):
		hero.stat_agility = record["stat_agility"] as int
	if record.has("base_hp_seed"):
		hero.base_hp_seed = record["base_hp_seed"] as int
	if record.has("base_initiative_seed"):
		hero.base_initiative_seed = record["base_initiative_seed"] as int
	if record.has("move_range"):
		hero.move_range = record["move_range"] as int
	if record.has("default_class"):
		hero.default_class = record["default_class"] as int
	if record.has("growth_might"):
		hero.growth_might = record["growth_might"] as float
	if record.has("growth_intellect"):
		hero.growth_intellect = record["growth_intellect"] as float
	if record.has("growth_command"):
		hero.growth_command = record["growth_command"] as float
	if record.has("growth_agility"):
		hero.growth_agility = record["growth_agility"] as float
	if record.has("join_chapter"):
		hero.join_chapter = record["join_chapter"] as int
	if record.has("join_condition_tag"):
		hero.join_condition_tag = record["join_condition_tag"] as String
	if record.has("is_available_mvp"):
		hero.is_available_mvp = record["is_available_mvp"] as bool
	return hero


# RETURNS SHARED REFERENCE — consumers MUST NOT mutate fields. Use base+modifier pattern.
## Returns the HeroData for the given hero_id, or null + push_error if not found.
## Per ADR-0007 §4: null + push_error on miss (NOT degrade-with-default).
static func get_hero(hero_id: StringName) -> HeroData:
	_load_heroes()
	if not _heroes.has(hero_id):
		push_error(
			"HeroDatabase.get_hero: unknown hero_id '%s'" % hero_id
		)
		return null
	return _heroes[hero_id]


# RETURNS SHARED REFERENCE — consumers MUST NOT mutate fields. Use base+modifier pattern.
## Returns all heroes matching the given faction int (HeroData.HeroFaction enum value).
## Linear scan — pre-built faction index deferred to Alpha tier per ADR-0007 §4 N4.
static func get_heroes_by_faction(faction: int) -> Array[HeroData]:
	_load_heroes()
	var result: Array[HeroData] = []
	for hero: HeroData in _heroes.values():
		if hero.faction == faction:
			result.append(hero)
	return result


# RETURNS SHARED REFERENCE — consumers MUST NOT mutate fields. Use base+modifier pattern.
## Returns all heroes matching the given UnitRole.UnitClass int value stored in default_class.
## Linear scan — pre-built class index deferred to Alpha tier per ADR-0007 §4 N4.
static func get_heroes_by_class(unit_class: int) -> Array[HeroData]:
	_load_heroes()
	var result: Array[HeroData] = []
	for hero: HeroData in _heroes.values():
		if hero.default_class == unit_class:
			result.append(hero)
	return result


# RETURNS SHARED REFERENCE — consumers MUST NOT mutate fields. Use base+modifier pattern.
## Returns all hero_id StringNames currently loaded in the cache.
static func get_all_hero_ids() -> Array[StringName]:
	_load_heroes()
	var result: Array[StringName] = []
	for hero_id: StringName in _heroes.keys():
		result.append(hero_id)
	return result


# RETURNS SHARED REFERENCE — consumers MUST NOT mutate fields. Use base+modifier pattern.
## Returns all heroes with is_available_mvp == true for MVP roster selection.
static func get_mvp_roster() -> Array[HeroData]:
	_load_heroes()
	var result: Array[HeroData] = []
	for hero: HeroData in _heroes.values():
		if hero.is_available_mvp:
			result.append(hero)
	return result


# RETURNS SHARED REFERENCE — consumers MUST NOT mutate fields. Use base+modifier pattern.
## Returns the relationships Array[Dictionary] for the given hero_id.
## Returns empty array + push_error if hero not found.
## Provisional Array[Dictionary] shape — Formation Bonus ADR migrates to typed Array[HeroRelationship].
static func get_relationships(hero_id: StringName) -> Array[Dictionary]:
	_load_heroes()
	if not _heroes.has(hero_id):
		push_error(
			"HeroDatabase.get_relationships: unknown hero_id '%s'" % hero_id
		)
		return []
	return _heroes[hero_id].relationships
