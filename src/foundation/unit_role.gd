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
