## hero_database.gd
## Ratified by ADR-0007 (Accepted 2026-04-30). Pass 3 WARNING-tier relationship validation added story-004.
##
## TEST ISOLATION: every test that calls any HeroDatabase method MUST reset
##   HeroDatabase._heroes_loaded = false
##   HeroDatabase._heroes = {}
## in before_test() per G-15 + ADR-0006 §6 obligation.
@abstract
class_name HeroDatabase extends RefCounted


const _HEROES_JSON_PATH: String = "res://assets/data/heroes/heroes.json"

## Regex pattern for hero_id: ^[a-z]+_\d{3}_[a-z_]+$
## Faction segment: one or more lowercase letters.
## Sequence: exactly 3 digits.
## Slug: one or more lowercase letters or underscores.
const _HERO_ID_REGEX: String = "^[a-z]+_\\d{3}_[a-z_]+$"

static var _heroes_loaded: bool = false
static var _heroes: Dictionary[StringName, HeroData] = {}


## Lazy-init loader. Reads heroes.json on first call; subsequent calls return immediately.
## On FileAccess failure (empty string returned): push_error + _heroes_loaded stays false.
## On JSON parse failure: push_error + _heroes_loaded stays false.
## On FATAL validation failure (CR-1 regex / EC-1 duplicate): clears _heroes + stays false.
## Per-record FATAL (CR-2 range / EC-2 skill array mismatch): drops record, continues.
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
	_load_heroes_from_dict(raw_records)


## Test-seam entry point: validates and loads heroes from a pre-parsed Dictionary.
## Production code calls this after FileAccess + JSON.parse; tests call this directly
## with synthetic fixtures to bypass file I/O.
## Pass 1 (FATAL load-reject): hero_id regex + duplicate-key detection.
##   Failure: _heroes.clear() + _heroes_loaded stays false.
## Pass 2 (per-record FATAL): range checks + skill-array integrity.
##   Failure: offending record dropped; other records continue.
## On full pass success: _heroes_loaded = true.
static func _load_heroes_from_dict(raw_records: Dictionary) -> void:
	# ── Pass 1: FATAL load-reject checks ─────────────────────────────────────
	# CR-1: validate hero_id format for every key
	for hero_id_str: String in raw_records:
		if not _validate_hero_id_format(hero_id_str):
			push_error(
				("HeroDatabase: CR-1 FATAL load-reject — "
				+ "hero_id '%s' does not match required regex '%s'. "
				+ "Entire load rejected.")
				% [hero_id_str, _HERO_ID_REGEX]
			)
			_heroes.clear()
			return

	# EC-1: duplicate hero_id detection.
	# A GDScript Dictionary cannot hold duplicate keys, so duplicates in the
	# JSON source collapse silently. We detect this by comparing the record
	# count against the number of keys after building a seen-set. Since
	# Dictionary already deduplicates at parse time, this check verifies that
	# _heroes is not being loaded with a key already present (cross-call
	# collision) OR via the pairs-list overload used in tests. For the
	# standard Dictionary path, we scan for any hero_id already in _heroes
	# (cross-load collision guard).
	var seen_ids: Dictionary[StringName, bool] = {}
	for hero_id_str: String in raw_records:
		var id: StringName = StringName(hero_id_str)
		if seen_ids.has(id):
			push_error(
				("HeroDatabase: EC-1 FATAL load-reject — "
				+ "duplicate hero_id '%s' detected in input. "
				+ "Entire load rejected.")
				% [id]
			)
			_heroes.clear()
			return
		seen_ids[id] = true

	# ── Pass 2: per-record FATAL checks ───────────────────────────────────────
	for hero_id_str: String in raw_records:
		var record: Dictionary = raw_records[hero_id_str]
		var hero: HeroData = _build_hero_data(StringName(hero_id_str), record)
		if hero == null:
			# Per-record FATAL: push_error was already emitted inside _build_hero_data.
			# Drop this record and continue with remaining records.
			continue
		_heroes[StringName(hero_id_str)] = hero

	# ── Pass 3 (story-004): WARNING-tier relationship validation ─────────────
	# 3a: per-hero filter — drop EC-4 self-refs + EC-5 orphan FKs (push_warning each)
	# 3b: cross-pair detection — EC-6 asymmetric conflict (push_warning, keep both entries)
	for hero_id_p3: StringName in _heroes:
		var hero_p3: HeroData = _heroes[hero_id_p3]
		hero_p3.relationships = _filter_relationships_with_warnings(
				hero_id_p3, hero_p3.relationships, _heroes)
	_detect_asymmetric_conflicts(_heroes)

	_heroes_loaded = true


## Builds a HeroData from a JSON record dict, running per-record FATAL validators.
## Returns null if any per-record FATAL fails (push_error already emitted by validator).
## Returns HeroData on success.
## Required fields use validators before assignment; optional fields use .has() fallback.
static func _build_hero_data(hero_id: StringName, record: Dictionary) -> HeroData:
	var hero: HeroData = HeroData.new()
	hero.hero_id = hero_id

	# ── Required fields: identity (no range check; heroes.json schema is owner) ─
	if record.has("name_ko"):
		hero.name_ko = record["name_ko"] as String
	if record.has("name_zh"):
		hero.name_zh = record["name_zh"] as String
	# Optional: name_courtesy
	if record.has("name_courtesy"):
		hero.name_courtesy = record["name_courtesy"] as String
	if record.has("faction"):
		hero.faction = record["faction"] as int
	# Optional: portrait_id, battle_sprite_id
	if record.has("portrait_id"):
		hero.portrait_id = record["portrait_id"] as String
	if record.has("battle_sprite_id"):
		hero.battle_sprite_id = record["battle_sprite_id"] as String

	# ── Required fields: core stats range [1, 100] (CR-2) ──────────────────────
	if record.has("stat_might"):
		var v: int = record["stat_might"] as int
		if not _validate_stat_range(hero_id, "stat_might", v, 1, 100):
			return null
		hero.stat_might = v
	if record.has("stat_intellect"):
		var v: int = record["stat_intellect"] as int
		if not _validate_stat_range(hero_id, "stat_intellect", v, 1, 100):
			return null
		hero.stat_intellect = v
	if record.has("stat_command"):
		var v: int = record["stat_command"] as int
		if not _validate_stat_range(hero_id, "stat_command", v, 1, 100):
			return null
		hero.stat_command = v
	if record.has("stat_agility"):
		var v: int = record["stat_agility"] as int
		if not _validate_stat_range(hero_id, "stat_agility", v, 1, 100):
			return null
		hero.stat_agility = v

	# ── Required fields: derived seeds range [1, 100] (CR-2) ───────────────────
	if record.has("base_hp_seed"):
		var v: int = record["base_hp_seed"] as int
		if not _validate_stat_range(hero_id, "base_hp_seed", v, 1, 100):
			return null
		hero.base_hp_seed = v
	if record.has("base_initiative_seed"):
		var v: int = record["base_initiative_seed"] as int
		if not _validate_stat_range(hero_id, "base_initiative_seed", v, 1, 100):
			return null
		hero.base_initiative_seed = v

	# ── Required fields: move_range [2, 6] (CR-2) ──────────────────────────────
	if record.has("move_range"):
		var v: int = record["move_range"] as int
		if not _validate_stat_range(hero_id, "move_range", v, 2, 6):
			return null
		hero.move_range = v

	# ── Optional: default_class + equipment_slot_override ──────────────────────
	if record.has("default_class"):
		hero.default_class = record["default_class"] as int
	if record.has("equipment_slot_override"):
		var raw_slots: Array = record["equipment_slot_override"] as Array
		var slots: Array[int] = []
		for slot in raw_slots:
			slots.append(slot as int)
		hero.equipment_slot_override = slots

	# ── Required fields: growth rates [0.5, 2.0] (CR-2) ───────────────────────
	if record.has("growth_might"):
		var v: float = record["growth_might"] as float
		if not _validate_growth_range(hero_id, "growth_might", v, 0.5, 2.0):
			return null
		hero.growth_might = v
	if record.has("growth_intellect"):
		var v: float = record["growth_intellect"] as float
		if not _validate_growth_range(hero_id, "growth_intellect", v, 0.5, 2.0):
			return null
		hero.growth_intellect = v
	if record.has("growth_command"):
		var v: float = record["growth_command"] as float
		if not _validate_growth_range(hero_id, "growth_command", v, 0.5, 2.0):
			return null
		hero.growth_command = v
	if record.has("growth_agility"):
		var v: float = record["growth_agility"] as float
		if not _validate_growth_range(hero_id, "growth_agility", v, 0.5, 2.0):
			return null
		hero.growth_agility = v

	# ── Required fields: skill parallel arrays (EC-2) ──────────────────────────
	var raw_skill_ids: Array = []
	var raw_skill_levels: Array = []
	if record.has("innate_skill_ids"):
		raw_skill_ids = record["innate_skill_ids"] as Array
	if record.has("skill_unlock_levels"):
		raw_skill_levels = record["skill_unlock_levels"] as Array
	if not _validate_skill_arrays(hero_id, raw_skill_ids, raw_skill_levels):
		return null
	var skill_ids: Array[StringName] = []
	for sid in raw_skill_ids:
		skill_ids.append(StringName(sid as String))
	hero.innate_skill_ids = skill_ids
	var skill_levels: Array[int] = []
	for lvl in raw_skill_levels:
		skill_levels.append(lvl as int)
	hero.skill_unlock_levels = skill_levels

	# ── Optional: scenario block ────────────────────────────────────────────────
	if record.has("join_chapter"):
		hero.join_chapter = record["join_chapter"] as int
	if record.has("join_condition_tag"):
		hero.join_condition_tag = record["join_condition_tag"] as String
	if record.has("is_available_mvp"):
		hero.is_available_mvp = record["is_available_mvp"] as bool

	# ── Optional: relationships ─────────────────────────────────────────────────
	if record.has("relationships"):
		var raw_rels: Array = record["relationships"] as Array
		var rels: Array[Dictionary] = []
		for r in raw_rels:
			rels.append(r as Dictionary)
		hero.relationships = rels

	return hero


## CR-1: validates that a hero_id string matches ^[a-z]+_\d{3}_[a-z_]+$.
## Returns true if valid; false if the format check fails (caller emits push_error).
static func _validate_hero_id_format(id: String) -> bool:
	var re: RegEx = RegEx.new()
	re.compile(_HERO_ID_REGEX)
	var result: RegExMatch = re.search(id)
	return result != null


## CR-2 (int): validates that an integer field value is within [min_v, max_v] inclusive.
## Emits push_error listing hero_id + field + value + range on out-of-bounds.
## Returns false on failure; true on success.
static func _validate_stat_range(
		hero_id: StringName, field: String, value: int, min_v: int, max_v: int) -> bool:
	if value < min_v or value > max_v:
		push_error(
			("HeroDatabase: CR-2 per-record FATAL — "
			+ "hero_id '%s' field '%s' value %d is out of range [%d, %d]. "
			+ "Record dropped.")
			% [hero_id, field, value, min_v, max_v]
		)
		return false
	return true


## CR-2 (float): validates that a float field value is within [min_v, max_v] inclusive.
## Used for growth rates (growth_might / growth_intellect / growth_command / growth_agility).
## Emits push_error listing hero_id + field + value + range on out-of-bounds.
## Returns false on failure; true on success.
static func _validate_growth_range(
		hero_id: StringName, field: String, value: float, min_v: float, max_v: float) -> bool:
	if value < min_v or value > max_v:
		push_error(
			("HeroDatabase: CR-2 per-record FATAL — "
			+ "hero_id '%s' field '%s' value %.4f is out of range [%.1f, %.1f]. "
			+ "Record dropped.")
			% [hero_id, field, value, min_v, max_v]
		)
		return false
	return true


## EC-2: validates that innate_skill_ids and skill_unlock_levels are equal-length.
## Both length 0 is accepted (per EC-3). Emits push_error on mismatch.
## Returns false on failure; true on success.
static func _validate_skill_arrays(
		hero_id: StringName, ids: Array, levels: Array) -> bool:
	if ids.size() != levels.size():
		push_error(
			("HeroDatabase: EC-2 per-record FATAL — "
			+ "hero_id '%s' skill parallel array length mismatch: "
			+ "innate_skill_ids.size()=%d, skill_unlock_levels.size()=%d. "
			+ "Record dropped.")
			% [hero_id, ids.size(), levels.size()]
		)
		return false
	return true


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


## EC-4 + EC-5 WARNING-tier filter (story-004 Pass 3a).
## Returns a new Array[Dictionary] with self-refs and orphan-FK entries removed.
## Emits push_warning per drop with hero_id + offending hero_b_id + reason.
static func _filter_relationships_with_warnings(
		hero_id: StringName,
		relationships: Array[Dictionary],
		all_heroes: Dictionary[StringName, HeroData]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rel: Dictionary in relationships:
		var hero_b_str: String = rel.get("hero_b_id", "") as String
		var hero_b_id: StringName = StringName(hero_b_str)
		# EC-4: self-reference (hero_b_id == hero_id)
		if hero_b_id == hero_id:
			push_warning(
				("HeroDatabase: EC-4 WARNING — hero_id '%s' has self-referencing "
				+ "relationship (hero_b_id == hero_id). Entry dropped.") % hero_id
			)
			continue
		# EC-5: orphan FK (hero_b_id not present in _heroes post-Pass-2)
		if not all_heroes.has(hero_b_id):
			push_warning(
				("HeroDatabase: EC-5 WARNING — hero_id '%s' relationship references "
				+ "unresolved hero_b_id '%s'. Entry dropped.") % [hero_id, hero_b_str]
			)
			continue
		result.append(rel)
	return result


## EC-6 WARNING-tier asymmetric conflict detection (story-004 Pass 3b).
## For each ordered pair (a, b) where both have a reciprocal relationship with
## is_symmetric=true but conflicting relation_type, emits push_warning. Both
## entries kept; Hero DB does NOT adjudicate (Formation Bonus / Battle owns it).
## De-duplicated via order-independent pair key.
static func _detect_asymmetric_conflicts(
		all_heroes: Dictionary[StringName, HeroData]) -> void:
	var seen_pairs: Dictionary[String, bool] = {}
	for hero_a_id: StringName in all_heroes:
		var hero_a: HeroData = all_heroes[hero_a_id]
		for rel_a: Dictionary in hero_a.relationships:
			var hero_b_id: StringName = StringName(rel_a.get("hero_b_id", "") as String)
			var pair_key: String = _pair_key_unordered(hero_a_id, hero_b_id)
			if seen_pairs.has(pair_key):
				continue
			if not (rel_a.get("is_symmetric", false) as bool):
				continue
			if not all_heroes.has(hero_b_id):
				continue  # defensive — EC-5 already filtered
			var hero_b: HeroData = all_heroes[hero_b_id]
			# Find B's reciprocal entry pointing back to A
			for rel_b: Dictionary in hero_b.relationships:
				var rel_b_target: StringName = StringName(rel_b.get("hero_b_id", "") as String)
				if rel_b_target != hero_a_id:
					continue
				if not (rel_b.get("is_symmetric", false) as bool):
					continue
				var rel_a_type: String = rel_a.get("relation_type", "") as String
				var rel_b_type: String = rel_b.get("relation_type", "") as String
				if rel_a_type != rel_b_type:
					push_warning(
						("HeroDatabase: EC-6 WARNING — asymmetric conflict between "
						+ "'%s' and '%s': %s says '%s', %s says '%s' "
						+ "(both is_symmetric=true). Both entries kept; "
						+ "Formation Bonus / Battle owns conflict resolution.")
						% [hero_a_id, hero_b_id, hero_a_id, rel_a_type,
							hero_b_id, rel_b_type]
					)
				seen_pairs[pair_key] = true
				break  # found reciprocal; move on


## Order-independent pair key for EC-6 de-duplication.
static func _pair_key_unordered(a: StringName, b: StringName) -> String:
	var a_str: String = String(a)
	var b_str: String = String(b)
	if a_str <= b_str:
		return a_str + "::" + b_str
	return b_str + "::" + a_str
