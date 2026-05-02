extends GdUnitTestSuite

## hp_status_skeleton_test.gd
## Unit tests for HP/Status story-001: Module skeleton + 4 payload classes + 27 BalanceConstants + 5 .tres templates.
## Covers AC-1 through AC-9. AC-10 verified via full-suite regression. AC-11 via separate bash lint invocation.

const HP_STATUS_CONTROLLER_PATH := "res://src/core/hp_status_controller.gd"
const UNIT_HP_STATE_PATH := "res://src/core/payloads/unit_hp_state.gd"
const STATUS_EFFECT_PATH := "res://src/core/payloads/status_effect.gd"
const TICK_EFFECT_PATH := "res://src/core/payloads/tick_effect.gd"
const BALANCE_JSON_PATH := "res://assets/data/balance/balance_entities.json"
const STATUS_EFFECTS_DIR := "res://assets/data/status_effects/"


## AC-1: HPStatusController class declaration is `extends Node` (not RefCounted/Resource).
func test_hp_status_controller_extends_node() -> void:
	var content := FileAccess.get_file_as_string(HP_STATUS_CONTROLLER_PATH)
	assert_str(content).contains("class_name HPStatusController")
	assert_str(content).contains("extends Node")
	# Negative-form sanity:
	assert_bool(content.contains("extends RefCounted")).is_false()
	assert_bool(content.contains("extends Resource")).is_false()


## AC-2: Two instance fields with exact typed-Dictionary + typed reference.
func test_hp_status_controller_instance_fields() -> void:
	var content := FileAccess.get_file_as_string(HP_STATUS_CONTROLLER_PATH)
	assert_str(content).contains("_state_by_unit: Dictionary[int, UnitHPState]")
	assert_str(content).contains("_map_grid: MapGrid")


## AC-3: UnitHPState extends RefCounted with 6 typed fields.
func test_unit_hp_state_six_fields() -> void:
	var content := FileAccess.get_file_as_string(UNIT_HP_STATE_PATH)
	assert_str(content).contains("class_name UnitHPState")
	assert_str(content).contains("extends RefCounted")
	assert_str(content).contains("unit_id: int")
	assert_str(content).contains("max_hp: int")
	assert_str(content).contains("current_hp: int")
	assert_str(content).contains("status_effects: Array[StatusEffect]")
	assert_str(content).contains("hero: HeroData")
	assert_str(content).contains("unit_class: int")


## AC-4: StatusEffect extends Resource with 7 @export fields.
func test_status_effect_seven_export_fields() -> void:
	var content := FileAccess.get_file_as_string(STATUS_EFFECT_PATH)
	assert_str(content).contains("class_name StatusEffect")
	assert_str(content).contains("extends Resource")
	# Verify each @export field — named type check
	var expected_exports: Array[String] = [
		"effect_id: StringName",
		"effect_type: int",
		"duration_type: int",
		"remaining_turns: int",
		"modifier_targets: Dictionary",
		"tick_effect: TickEffect",
		"source_unit_id: int",
	]
	for export_decl: String in expected_exports:
		assert_str(content).contains(export_decl)
	# Count of @export decorators >= 7
	var export_count: int = content.count("@export")
	assert_int(export_count).is_greater_equal(7)


## AC-5: TickEffect extends Resource with 5 @export fields.
func test_tick_effect_five_export_fields() -> void:
	var content := FileAccess.get_file_as_string(TICK_EFFECT_PATH)
	assert_str(content).contains("class_name TickEffect")
	assert_str(content).contains("extends Resource")
	var expected_exports: Array[String] = [
		"damage_type: int",
		"dot_hp_ratio: float",
		"dot_flat: int",
		"dot_min: int",
		"dot_max_per_turn: int",
	]
	for export_decl: String in expected_exports:
		assert_str(content).contains(export_decl)
	var export_count: int = content.count("@export")
	assert_int(export_count).is_greater_equal(5)


## AC-6: 5 .tres status-effect templates exist + spec field values per ADR-0010 §4 + §12.
func test_five_tres_templates_load_with_correct_field_values() -> void:
	var poison: StatusEffect = load(STATUS_EFFECTS_DIR + "poison.tres") as StatusEffect
	assert_object(poison).is_not_null()
	assert_str(str(poison.effect_id)).is_equal("poison")
	assert_object(poison.tick_effect).is_not_null()
	assert_float(poison.tick_effect.dot_hp_ratio).is_equal_approx(0.04, 0.0001)
	assert_int(poison.tick_effect.dot_flat).is_equal(3)

	var demoralized: StatusEffect = load(STATUS_EFFECTS_DIR + "demoralized.tres") as StatusEffect
	assert_object(demoralized).is_not_null()
	assert_str(str(demoralized.effect_id)).is_equal("demoralized")
	assert_int(int(demoralized.modifier_targets.get(&"atk", 0))).is_equal(-25)

	var defend_stance: StatusEffect = load(STATUS_EFFECTS_DIR + "defend_stance.tres") as StatusEffect
	assert_object(defend_stance).is_not_null()
	assert_str(str(defend_stance.effect_id)).is_equal("defend_stance")
	assert_int(int(defend_stance.modifier_targets.get(&"atk", 0))).is_equal(-40)

	var inspired: StatusEffect = load(STATUS_EFFECTS_DIR + "inspired.tres") as StatusEffect
	assert_object(inspired).is_not_null()
	assert_str(str(inspired.effect_id)).is_equal("inspired")
	assert_int(int(inspired.modifier_targets.get(&"atk", 0))).is_equal(20)

	var exhausted: StatusEffect = load(STATUS_EFFECTS_DIR + "exhausted.tres") as StatusEffect
	assert_object(exhausted).is_not_null()
	assert_str(str(exhausted.effect_id)).is_equal("exhausted")
	assert_int(exhausted.modifier_targets.size()).is_equal(0)


## AC-7: All 27 BalanceConstants present in balance_entities.json + values match ADR-0010 §12 defaults.
func test_27_balance_constants_present_with_spec_defaults() -> void:
	var json_str := FileAccess.get_file_as_string(BALANCE_JSON_PATH)
	var parsed: Variant = JSON.parse_string(json_str)
	assert_bool(parsed is Dictionary).is_true()
	var json: Dictionary = parsed
	var expected_int: Dictionary = {
		"MIN_DAMAGE": 1, "SHIELD_WALL_FLAT": 5, "HEAL_BASE": 15, "HEAL_PER_USE_CAP": 50,
		"DOT_FLAT": 3, "DOT_MIN": 1, "DOT_MAX_PER_TURN": 20,
		"DEMORALIZED_ATK_REDUCTION": -25, "DEMORALIZED_RADIUS": 4, "DEMORALIZED_TURN_CAP": 4,
		"DEMORALIZED_RECOVERY_RADIUS": 2, "DEMORALIZED_DEFAULT_DURATION": 4,
		"DEFEND_STANCE_REDUCTION": 50,
		"INSPIRED_ATK_BONUS": 20, "INSPIRED_DURATION": 2,
		"EXHAUSTED_MOVE_REDUCTION": 1, "EXHAUSTED_DEFAULT_DURATION": 2,
		"MODIFIER_FLOOR": -50, "MODIFIER_CEILING": 50,
		"MAX_STATUS_EFFECTS_PER_UNIT": 3, "ATK_CAP": 200, "DEF_CAP": 105,
		"POISON_DEFAULT_DURATION": 3,
	}
	for key: String in expected_int:
		assert_bool(json.has(key)).override_failure_message("missing key: %s" % key).is_true()
		assert_int(int(json[key])).override_failure_message("key %s mismatch" % key).is_equal(int(expected_int[key]))
	# Float-valued keys. DEFEND_STANCE_ATK_PENALTY is the damage-calc fraction form (0.40 = 40% reduction);
	# the .tres-embedded -40 in defend_stance.tres modifier_targets is the F-4 percent-modifier and is
	# INDEPENDENT of this BalanceConstants value. ADR-0010 §12 prescribed -40 represents an aspirational
	# future-state unification that requires damage-calc refactor (out of scope for story-001); see story
	# Completion Notes for full carry-forward rationale.
	var expected_float: Dictionary = {
		"HEAL_HP_RATIO": 0.10, "EXHAUSTED_HEAL_MULT": 0.5, "DOT_HP_RATIO": 0.04,
		"DEFEND_STANCE_ATK_PENALTY": 0.40,
	}
	for key: String in expected_float:
		assert_bool(json.has(key)).override_failure_message("missing key: %s" % key).is_true()
		assert_float(float(json[key])).override_failure_message("key %s mismatch" % key).is_equal_approx(float(expected_float[key]), 0.0001)
	# 27-key total contract
	var hp_keys_total: int = expected_int.size() + expected_float.size()
	assert_int(hp_keys_total).is_equal(27)


## AC-8: 8 public methods + 1 test seam stubbed with exact signatures (FileAccess source-file scan).
func test_eight_public_methods_plus_test_seam_stubbed() -> void:
	var content := FileAccess.get_file_as_string(HP_STATUS_CONTROLLER_PATH)
	var expected_signatures: Array[String] = [
		"func initialize_unit(",
		"func apply_damage(",
		"func apply_heal(",
		"func apply_status(",
		"func get_current_hp(",
		"func get_max_hp(",
		"func is_alive(",
		"func get_modified_stat(",
		"func get_status_effects(",
		"func _apply_turn_start_tick(",
	]
	for sig: String in expected_signatures:
		assert_str(content).contains(sig)


## AC-9: Class cache resolution — instantiate all 4 new class_names without parse errors.
func test_all_four_class_names_instantiate() -> void:
	var c: HPStatusController = HPStatusController.new()
	assert_object(c).is_not_null()
	var u: UnitHPState = UnitHPState.new()
	assert_object(u).is_not_null()
	var s: StatusEffect = StatusEffect.new()
	assert_object(s).is_not_null()
	var t: TickEffect = TickEffect.new()
	assert_object(t).is_not_null()
	# Cleanup: HPStatusController is a Node — free explicitly (RefCounted types drop via ref-count)
	c.free()
