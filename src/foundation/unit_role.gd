## unit_role.gd
## Foundation-layer stateless gameplay rules calculator per ADR-0009 §Engine Compatibility.
## 4-precedent class_name+RefCounted+all-static pattern (ADR-0008 → ADR-0006 → ADR-0012 → ADR-0009).
## non-emitter per ADR-0001 line 375: zero signal declarations, zero signal emissions,
## zero signal subscriptions. All methods are static. UnitRole.new() is blocked at
## parse time on typed references by @abstract (typed `var x: UnitRole = UnitRole.new()`
## triggers "Cannot construct abstract class" at GDScript reload). Reflective paths
## (`script.new()`) bypass @abstract entirely — see G-22 in .claude/rules/godot-4x-gotchas.md.
## Call static methods directly (e.g. UnitRole.UnitClass.CAVALRY).
@abstract
class_name UnitRole
extends RefCounted


## UnitClass enum — 6 class profiles with explicit integer backing values.
## Backing values 0..5 match entities.yaml + Dictionary key expectations.
enum UnitClass {
	CAVALRY    = 0,
	INFANTRY   = 1,
	ARCHER     = 2,
	STRATEGIST = 3,
	COMMANDER  = 4,
	SCOUT      = 5,
}


## Lazy-init guard flag for the coefficient data cache.
## Set to true after first successful load OR after fallback population.
## Persists for the GDScript engine session (MVP limitation: editor restart
## required to pick up unit_roles.json changes — matches ADR-0006 §6 behavior).
## AC-21: hot-reload deferred to a future Alpha-tier ADR; editor restart required.
static var _coefficients_loaded: bool = false

## Per-class coefficient cache populated by _load_coefficients().
## Keys: lowercase class name strings ("cavalry", "infantry", etc.)
## Values: Dictionary of 12 fields per ADR-0009 §4 schema.
static var _coefficients: Dictionary = {}


## Loads per-class coefficients from unit_roles.json into _coefficients cache.
## Lazy-init: early-returns immediately if already loaded (_coefficients_loaded flag).
## On missing or malformed file: push_error + populate hardcoded safe-default fallback.
## On missing schema field for a class: push_error + replace that class with fallback.
## Optional path parameter supports dependency injection for tests (per coding-standards.md).
##
## terrain_cost_table index: [ROAD=0, PLAINS=1, HILLS=2, FOREST=3, MOUNTAIN=4, BRIDGE=5]
## class_direction_mult index: [FRONT=0, FLANK=1, REAR=2]
static func _load_coefficients(path: String = "assets/data/config/unit_roles.json") -> void:
	if _coefficients_loaded:
		return
	var json_text: String = FileAccess.get_file_as_string(path)
	if json_text.is_empty():
		push_error(
			"UnitRole: unit_roles.json not found at '%s'; using fallback defaults" % path
		)
		_populate_fallback_defaults()
		_coefficients_loaded = true
		return
	var parser: JSON = JSON.new()
	var parse_error: int = parser.parse(json_text)
	if parse_error != OK:
		push_error(
			("UnitRole: unit_roles.json parse failed at line %d: %s; using fallback defaults")
			% [parser.get_error_line(), parser.get_error_message()]
		)
		_populate_fallback_defaults()
		_coefficients_loaded = true
		return
	var loaded: Dictionary = parser.data as Dictionary
	# Schema validation: per-class partial fallback on missing required fields
	var fallback: Dictionary = _build_fallback_dict()
	var required_fields: Array[String] = [
		"primary_stat", "secondary_stat", "w_primary", "w_secondary",
		"class_atk_mult", "class_phys_def_mult", "class_mag_def_mult",
		"class_hp_mult", "class_init_mult", "class_move_delta",
		"passive_tag", "terrain_cost_table", "class_direction_mult",
	]
	var expected_classes: Array[String] = [
		"cavalry", "infantry", "archer", "strategist", "commander", "scout"
	]
	_coefficients = {}
	for cls: String in expected_classes:
		if not loaded.has(cls):
			push_error(
				"UnitRole: unit_roles.json missing class entry '%s'; using fallback for that class" % cls
			)
			_coefficients[cls] = fallback[cls]
			continue
		var entry: Dictionary = loaded[cls] as Dictionary
		var valid: bool = true
		for field: String in required_fields:
			if not entry.has(field):
				push_error(
					("UnitRole: unit_roles.json class '%s' missing required field '%s';"
					+ " using fallback for that class") % [cls, field]
				)
				valid = false
				break
		if valid:
			_coefficients[cls] = entry
		else:
			_coefficients[cls] = fallback[cls]
	_coefficients_loaded = true


## Builds and returns the hardcoded fallback Dictionary (same shape as JSON schema).
## Values match GDD CR-1 + CR-4 + CR-6a exactly. Must stay in sync with
## assets/data/config/unit_roles.json — CI lint compares on every push.
## Called by _populate_fallback_defaults() (total fallback) and _load_coefficients()
## (per-class partial fallback) to avoid duplicating 60+ lines of hardcoded literals.
static func _build_fallback_dict() -> Dictionary:
	return {
		"cavalry": {
			"primary_stat": "stat_might", "secondary_stat": null,
			"w_primary": 1.0, "w_secondary": 0.0,
			"class_atk_mult": 1.1, "class_phys_def_mult": 0.8, "class_mag_def_mult": 0.7,
			"class_hp_mult": 0.9, "class_init_mult": 0.9, "class_move_delta": 1,
			"passive_tag": "passive_charge",
			"terrain_cost_table": [1.0, 1.0, 1.5, 2.0, 3.0, 1.0],
			"class_direction_mult": [1.0, 1.1, 1.09],
		},
		"infantry": {
			"primary_stat": "stat_might", "secondary_stat": null,
			"w_primary": 1.0, "w_secondary": 0.0,
			"class_atk_mult": 0.9, "class_phys_def_mult": 1.3, "class_mag_def_mult": 0.8,
			"class_hp_mult": 1.3, "class_init_mult": 0.7, "class_move_delta": 0,
			"passive_tag": "passive_shield_wall",
			"terrain_cost_table": [1.0, 1.0, 1.0, 1.0, 1.5, 1.0],
			"class_direction_mult": [0.9, 1.0, 1.1],
		},
		"archer": {
			"primary_stat": "stat_might", "secondary_stat": "stat_agility",
			"w_primary": 0.6, "w_secondary": 0.4,
			"class_atk_mult": 1.0, "class_phys_def_mult": 0.7, "class_mag_def_mult": 0.9,
			"class_hp_mult": 0.8, "class_init_mult": 0.85, "class_move_delta": 0,
			"passive_tag": "passive_high_ground_shot",
			"terrain_cost_table": [1.0, 1.0, 1.0, 1.0, 2.0, 1.0],
			"class_direction_mult": [1.0, 1.375, 0.9],
		},
		"strategist": {
			"primary_stat": "stat_intellect", "secondary_stat": null,
			"w_primary": 1.0, "w_secondary": 0.0,
			"class_atk_mult": 1.0, "class_phys_def_mult": 0.5, "class_mag_def_mult": 1.2,
			"class_hp_mult": 0.7, "class_init_mult": 0.8, "class_move_delta": -1,
			"passive_tag": "passive_tactical_read",
			"terrain_cost_table": [1.0, 1.0, 1.5, 1.5, 2.0, 1.0],
			"class_direction_mult": [1.0, 1.0, 1.0],
		},
		"commander": {
			"primary_stat": "stat_command", "secondary_stat": "stat_might",
			"w_primary": 0.7, "w_secondary": 0.3,
			"class_atk_mult": 0.8, "class_phys_def_mult": 1.0, "class_mag_def_mult": 1.0,
			"class_hp_mult": 1.1, "class_init_mult": 0.75, "class_move_delta": 0,
			"passive_tag": "passive_rally",
			"terrain_cost_table": [1.0, 1.0, 1.0, 1.5, 2.0, 1.0],
			"class_direction_mult": [1.0, 1.0, 1.0],
		},
		"scout": {
			"primary_stat": "stat_agility", "secondary_stat": "stat_might",
			"w_primary": 0.6, "w_secondary": 0.4,
			"class_atk_mult": 1.05, "class_phys_def_mult": 0.6, "class_mag_def_mult": 0.6,
			"class_hp_mult": 0.75, "class_init_mult": 1.2, "class_move_delta": 1,
			"passive_tag": "passive_ambush",
			"terrain_cost_table": [1.0, 1.0, 1.0, 0.7, 1.5, 1.0],
			"class_direction_mult": [1.0, 1.0, 1.1],
		},
	}


## Populates _coefficients with hardcoded GDD CR-1 + CR-4 + CR-6a fallback values.
## Called when unit_roles.json is missing or malformed. Game remains playable (Pillar 1).
static func _populate_fallback_defaults() -> void:
	_coefficients = _build_fallback_dict()


## Maps UnitClass enum value to its lowercase JSON key string.
## Used by Story 003+ coefficient lookups (_coefficients[_class_to_key(unit_class)]).
## Unknown enum values push_error and return "cavalry" to fail visibly but safely.
static func _class_to_key(unit_class: UnitClass) -> String:
	match unit_class:
		UnitClass.CAVALRY:    return "cavalry"
		UnitClass.INFANTRY:   return "infantry"
		UnitClass.ARCHER:     return "archer"
		UnitClass.STRATEGIST: return "strategist"
		UnitClass.COMMANDER:  return "commander"
		UnitClass.SCOUT:      return "scout"
		_:
			push_error("UnitRole._class_to_key: unknown UnitClass %d" % unit_class)
			return "cavalry"


## Reads a hero stat by field name using GDScript Object.get() reflection.
## Returns the integer value of the named @export field on the HeroData resource.
## Returns 0 for any unrecognised stat_name (safe-fail: contributes 0 to formulas).
## Used by F-1 get_atk() to resolve primary_stat / secondary_stat field names from JSON.
## NOT used by F-2 — phys_def / mag_def access hero fields directly (GDD hardcodes stat names).
static func _read_hero_stat(hero: HeroData, stat_name: String) -> int:
	if stat_name.is_empty():
		return 0
	var value: Variant = hero.get(stat_name)
	if value == null:
		push_error(
			"UnitRole._read_hero_stat: unknown stat field '%s' on HeroData" % stat_name
		)
		return 0
	return value as int


## F-1: Attack Power (ATK).
## atk = clampi(floori((primary × w_primary + secondary × w_secondary) × class_atk_mult), 1, ATK_CAP)
## Per GDD unit-role.md §F-1 + ADR-0009 §3.
## primary_stat and secondary_stat names come from unit_roles.json (JSON-configurable per AC-20).
## ATK_CAP read via BalanceConstants per ADR-0006 (no hardcoded cap literal).
static func get_atk(hero: HeroData, unit_class: UnitRole.UnitClass) -> int:
	_load_coefficients()
	var class_key: String = _class_to_key(unit_class)
	var entry: Dictionary = _coefficients[class_key]
	var primary_value: int = _read_hero_stat(hero, entry["primary_stat"] as String)
	var secondary_value: int = 0
	if entry["secondary_stat"] != null:
		secondary_value = _read_hero_stat(hero, entry["secondary_stat"] as String)
	var raw: int = floori(
		(primary_value * (entry["w_primary"] as float)
		+ secondary_value * (entry["w_secondary"] as float))
		* (entry["class_atk_mult"] as float)
	)
	var atk_cap: int = BalanceConstants.get_const("ATK_CAP") as int
	return clampi(raw, 1, atk_cap)


## F-2 (physical): Physical Defense (phys_def).
## phys_def_base = floori(stat_might × 0.3 + stat_command × 0.7)
## phys_def = clampi(floori(phys_def_base × class_phys_def_mult), 1, DEF_CAP)
## Per GDD unit-role.md §F-2 + ADR-0009 §3.
## Stat names and weights are HARDCODED in the GDD formula (not JSON-configurable) — direct
## field access is used instead of _read_hero_stat reflection (type-safe at parse time).
## Orthogonal from get_mag_def — each method has its own derivation per ADR-0009 Alt 4 rejection.
## DEF_CAP read via BalanceConstants per ADR-0006 (returns 105 per balance_entities.json rev 2.9.3).
static func get_phys_def(hero: HeroData, unit_class: UnitRole.UnitClass) -> int:
	_load_coefficients()
	var class_key: String = _class_to_key(unit_class)
	var entry: Dictionary = _coefficients[class_key]
	var phys_def_base: int = floori(hero.stat_might * 0.3 + hero.stat_command * 0.7)
	var raw: int = floori(phys_def_base * (entry["class_phys_def_mult"] as float))
	var def_cap: int = BalanceConstants.get_const("DEF_CAP") as int
	return clampi(raw, 1, def_cap)


## F-2 (magical): Magical Defense (mag_def).
## mag_def_base = floori(stat_intellect × 0.7 + stat_command × 0.3)
## mag_def = clampi(floori(mag_def_base × class_mag_def_mult), 1, DEF_CAP)
## Per GDD unit-role.md §F-2 + ADR-0009 §3.
## Stat names and weights are HARDCODED in the GDD formula (not JSON-configurable) — direct
## field access is used instead of _read_hero_stat reflection (type-safe at parse time).
## Orthogonal from get_phys_def — each method has its own derivation per ADR-0009 Alt 4 rejection.
## DEF_CAP read via BalanceConstants per ADR-0006 (returns 105 per balance_entities.json rev 2.9.3).
static func get_mag_def(hero: HeroData, unit_class: UnitRole.UnitClass) -> int:
	_load_coefficients()
	var class_key: String = _class_to_key(unit_class)
	var entry: Dictionary = _coefficients[class_key]
	var mag_def_base: int = floori(hero.stat_intellect * 0.7 + hero.stat_command * 0.3)
	var raw: int = floori(mag_def_base * (entry["class_mag_def_mult"] as float))
	var def_cap: int = BalanceConstants.get_const("DEF_CAP") as int
	return clampi(raw, 1, def_cap)


## F-3: Maximum Hit Points (max_hp).
## max_hp = clampi(floori(base_hp_seed × class_hp_mult × HP_SCALE) + HP_FLOOR, HP_FLOOR, HP_CAP)
## Per GDD unit-role.md §F-3 + EC-14.
## HP_FLOOR is additive INSIDE the expression (before the outer clamp) — practical minimum is
## HP_FLOOR + 1 = 51 (seed=1, lowest class_hp_mult). Clamp lower bound is HP_FLOOR so a
## pathological negative floori() result still floors to 50 (EC-14 boundary invariant).
## HP_CAP, HP_SCALE, HP_FLOOR read via BalanceConstants per ADR-0006 (no hardcoded literals).
static func get_max_hp(hero: HeroData, unit_class: UnitRole.UnitClass) -> int:
	_load_coefficients()
	var class_key: String = _class_to_key(unit_class)
	var entry: Dictionary = _coefficients[class_key]
	var hp_scale: float = BalanceConstants.get_const("HP_SCALE") as float
	var hp_floor: int = BalanceConstants.get_const("HP_FLOOR") as int
	var hp_cap: int = BalanceConstants.get_const("HP_CAP") as int
	var raw: int = floori(
		hero.base_hp_seed * (entry["class_hp_mult"] as float) * hp_scale
	) + hp_floor
	return clampi(raw, hp_floor, hp_cap)


## F-4: Initiative.
## initiative = clampi(floori(base_initiative_seed × class_init_mult × INIT_SCALE), 1, INIT_CAP)
## Per GDD unit-role.md §F-4 + ADR-0009 §3.
## Scout class_init_mult=1.2 ensures highest initiative per AC-4 (seed=80 → 192).
## INIT_SCALE, INIT_CAP read via BalanceConstants per ADR-0006 (no hardcoded literals).
static func get_initiative(hero: HeroData, unit_class: UnitRole.UnitClass) -> int:
	_load_coefficients()
	var class_key: String = _class_to_key(unit_class)
	var entry: Dictionary = _coefficients[class_key]
	var init_scale: float = BalanceConstants.get_const("INIT_SCALE") as float
	var init_cap: int = BalanceConstants.get_const("INIT_CAP") as int
	var raw: int = floori(
		hero.base_initiative_seed * (entry["class_init_mult"] as float) * init_scale
	)
	return clampi(raw, 1, init_cap)


## F-5: Effective Move Range.
## effective_move_range = clampi(hero.move_range + class_move_delta, MOVE_RANGE_MIN, MOVE_RANGE_MAX)
## Per GDD unit-role.md §F-5 + CR-1b.
## EC-1 (Strategist floor): move_range=2 + class_move_delta=-1 = 1 → clamped to MOVE_RANGE_MIN=2.
## EC-2 (Cavalry cap): move_range=6 + class_move_delta=+1 = 7 → clamped to MOVE_RANGE_MAX=6.
## move_budget (effective_move_range × MOVE_BUDGET_PER_RANGE) is a consumer-side compute per ADR-0009 §3.
## MOVE_RANGE_MIN, MOVE_RANGE_MAX read via BalanceConstants per ADR-0006 (no hardcoded literals).
static func get_effective_move_range(hero: HeroData, unit_class: UnitRole.UnitClass) -> int:
	_load_coefficients()
	var class_key: String = _class_to_key(unit_class)
	var entry: Dictionary = _coefficients[class_key]
	var range_min: int = BalanceConstants.get_const("MOVE_RANGE_MIN") as int
	var range_max: int = BalanceConstants.get_const("MOVE_RANGE_MAX") as int
	return clampi(hero.move_range + (entry["class_move_delta"] as int), range_min, range_max)


# RETURNS PER-CALL COPY — DO NOT cache and return shared array. R-1 mitigation per ADR-0009 §5.
## get_class_cost_table: Cost matrix unit-class dimension (ADR-0009 §5 + GDD CR-4).
## Returns the 6-entry terrain cost multiplier row for the given class as a PackedFloat32Array.
## Index mapping: [ROAD=0, PLAINS=1, HILLS=2, FOREST=3, MOUNTAIN=4, BRIDGE=5]
## Callers MUST NOT mutate the returned array (forbidden_pattern unit_role_returned_array_mutation).
## Map/Grid Dijkstra pattern: one fetch per get_movement_range call; index in inner loop.
## Per-call fresh PackedFloat32Array construction is the R-1 mitigation — DO NOT add caching.
static func get_class_cost_table(unit_class: UnitRole.UnitClass) -> PackedFloat32Array:
	_load_coefficients()
	var class_key: String = _class_to_key(unit_class)
	var entry: Dictionary = _coefficients[class_key]
	var table_array: Array = entry["terrain_cost_table"] as Array
	# Construct fresh PackedFloat32Array per call — do NOT cache and return shared array.
	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(6)
	for i: int in 6:
		result[i] = table_array[i] as float
	return result
