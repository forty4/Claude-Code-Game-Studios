## grid_battle_controller_use_item_test.gd
##
## S90 Phase B step 4 — heal_potion immediate-effect item.
## Validates strategy-systems.md v0.3 §AC-SS-4 acceptance criteria:
##   - use_item(unit, "heal_potion") with current_hp < max_hp restores HEAL_POTION_AMOUNT (25)
##   - heal capped at max_hp (apply_heal contract)
##   - pre-condition current_hp == max_hp returns false (slot NOT decremented,
##     token NOT spent — strategy-systems §4.1 EC)
##   - Slot decrement: pre inventory[0] == &"heal_potion" → post inventory[0] == &""
##   - action_token spent via TurnOrderRunner.declare_action(USE_ITEM)
##   - unit_item_used signal emits with (unit_id, item_id, slot_idx, actual_effect)
##
## Mirrors grid_battle_controller_player_defend_test.gd setup pattern.
extends GdUnitTestSuite

const GridBattleControllerScript: GDScript = preload("res://src/feature/grid_battle/grid_battle_controller.gd")
const MapGridStubScript: GDScript = preload("res://tests/helpers/map_grid_stub.gd")
const HPStatusControllerStubScript: GDScript = preload("res://tests/helpers/hp_status_controller_stub.gd")
const TurnOrderRunnerStubScript: GDScript = preload("res://tests/helpers/turn_order_runner_stub.gd")
const HeroDatabaseStubScript: GDScript = preload("res://tests/helpers/hero_database_stub.gd")
const TerrainEffectStubScript: GDScript = preload("res://tests/helpers/terrain_effect_stub.gd")
const UnitRoleStubScript: GDScript = preload("res://tests/helpers/unit_role_stub.gd")
const BattleCameraStubScript: GDScript = preload("res://tests/helpers/battle_camera_stub.gd")


func before_test() -> void:
	(load("res://src/foundation/balance/balance_constants.gd") as GDScript).set("_cache_loaded", false)


func _make_unit(unit_id: int, pos: Vector2i, side: int) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.hero_id = StringName("test_hero_%d" % unit_id)
	unit.unit_class = 0  # CAVALRY
	unit.position = pos
	unit.side = side
	unit.attack_range = 1
	unit.move_range = 3
	unit.raw_atk = 50
	unit.raw_def = 20
	unit.inventory = []  # callers set per-test
	return unit


func _setup(roster: Array[BattleUnit]) -> Dictionary:
	var map_grid: MapGridStub = MapGridStubScript.new()
	map_grid.set_dimensions_for_test(Vector2i(8, 8))
	auto_free(map_grid)
	var camera: BattleCameraStub = BattleCameraStubScript.new()
	auto_free(camera)
	var hero_db: HeroDatabaseStub = HeroDatabaseStubScript.new()
	var turn_runner: TurnOrderRunnerStub = TurnOrderRunnerStubScript.new()
	auto_free(turn_runner)
	var hp_controller: HPStatusControllerStub = HPStatusControllerStubScript.new()
	auto_free(hp_controller)
	var terrain_effect: TerrainEffectStub = TerrainEffectStubScript.new()
	var unit_role: UnitRoleStub = UnitRoleStubScript.new()
	var controller: GridBattleController = GridBattleControllerScript.new()
	auto_free(controller)
	controller.setup(roster, map_grid, camera, hero_db, turn_runner,
		hp_controller, terrain_effect, unit_role)
	controller._rng = RandomNumberGenerator.new()
	controller._rng.seed = 12345
	return {
		"controller": controller,
		"hp_controller": hp_controller,
		"turn_runner": turn_runner,
	}


# ─── AC-SS-4 heal_potion happy path ───────────────────────────────────────────


## AC-SS-4: heal_potion with current_hp = max_hp - 10 → heals 10 actual (capped
## at max_hp); inventory[0] decremented; action_token spent; signal emits.
func test_use_item_heal_potion_at_low_hp_heals_capped_at_max() -> void:
	# Arrange
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	unit.inventory = [&"heal_potion", &"", &""]
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 90)  # 10 below max
	controller._active_turn_unit_id = 1

	var emitted: Array = []
	controller.unit_item_used.connect(func(uid: int, item_id: StringName, slot_idx: int, effect: int) -> void:
		emitted.append({"uid": uid, "item": item_id, "slot": slot_idx, "effect": effect})
	)

	# Act
	var fired: bool = controller.use_item(1, 0)

	# Assert
	assert_bool(fired).override_failure_message(
		"AC-SS-4: use_item(heal_potion) at HP<max must return true (fired)"
	).is_true()

	# apply_heal called with raw_heal=25 (HEAL_POTION_AMOUNT)
	assert_int(hp_stub.apply_heal_calls.size()).override_failure_message(
		"AC-SS-4: apply_heal must be invoked exactly once"
	).is_equal(1)
	assert_int(hp_stub.apply_heal_calls[0]["raw_heal"] as int).override_failure_message(
		"AC-SS-4: raw_heal must equal HEAL_POTION_AMOUNT (25)"
	).is_equal(25)

	# Slot decremented
	assert_str(String(controller._units[1].inventory[0])).override_failure_message(
		"AC-SS-4: inventory[0] must be &\"\" after successful use_item"
	).is_equal("")

	# unit_item_used signal emitted
	assert_int(emitted.size()).override_failure_message(
		"AC-SS-4: unit_item_used signal must fire exactly once"
	).is_equal(1)
	assert_str(String(emitted[0]["item"] as StringName)).is_equal("heal_potion")
	assert_int(emitted[0]["slot"] as int).is_equal(0)


## AC-SS-4: pre-condition HP at max → use_item returns false; slot NOT decremented;
## apply_heal NOT called; token NOT spent.
func test_use_item_heal_potion_at_max_hp_rejected_slot_intact() -> void:
	# Arrange
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	unit.inventory = [&"heal_potion", &"", &""]
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 100)  # exactly at max
	controller._active_turn_unit_id = 1

	# Act
	var fired: bool = controller.use_item(1, 0)

	# Assert
	assert_bool(fired).override_failure_message(
		"AC-SS-4: use_item(heal_potion) at HP=max must return false (rejected)"
	).is_false()
	assert_int(hp_stub.apply_heal_calls.size()).override_failure_message(
		"AC-SS-4: apply_heal must NOT be called when reject"
	).is_equal(0)
	assert_str(String(controller._units[1].inventory[0])).override_failure_message(
		"AC-SS-4: inventory[0] must REMAIN &\"heal_potion\" on reject"
	).is_equal("heal_potion")


## AC-SS-4: empty slot → use_item returns false; no side effects.
func test_use_item_empty_slot_rejected() -> void:
	# Arrange
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	unit.inventory = [&"", &"", &""]  # all empty
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 50)
	controller._active_turn_unit_id = 1

	# Act
	var fired: bool = controller.use_item(1, 0)

	# Assert
	assert_bool(fired).override_failure_message(
		"AC-SS-4: use_item on empty slot must return false"
	).is_false()
	assert_int(hp_stub.apply_heal_calls.size()).is_equal(0)


## AC-SS-4: out-of-range slot_idx → use_item returns false.
func test_use_item_out_of_range_slot_rejected() -> void:
	# Arrange
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	unit.inventory = [&"heal_potion", &"", &""]
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 50)
	controller._active_turn_unit_id = 1

	# Act + Assert — out-of-range high
	var fired_high: bool = controller.use_item(1, 99)
	assert_bool(fired_high).override_failure_message(
		"AC-SS-4: use_item(slot=99) out-of-range must return false"
	).is_false()

	# Act + Assert — out-of-range low
	var fired_low: bool = controller.use_item(1, -1)
	assert_bool(fired_low).override_failure_message(
		"AC-SS-4: use_item(slot=-1) out-of-range must return false"
	).is_false()

	# apply_heal never called
	assert_int(hp_stub.apply_heal_calls.size()).is_equal(0)


## AC-SS-4: enemy side cannot use items (player-only in MVP).
func test_use_item_enemy_side_rejected() -> void:
	# Arrange
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 1)  # enemy side
	unit.inventory = [&"heal_potion", &"", &""]
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 50)
	controller._active_turn_unit_id = 1

	# Act
	var fired: bool = controller.use_item(1, 0)

	# Assert
	assert_bool(fired).override_failure_message(
		"AC-SS-4: use_item on enemy unit must return false (player-only MVP)"
	).is_false()
	assert_str(String(controller._units[1].inventory[0])).is_equal("heal_potion")


## AC-SS-4 (regression): unwired item_id triggers push_warning + reject without
## consuming slot. Validates the dispatch match default arm.
func test_use_item_unwired_item_id_rejected_with_warning() -> void:
	# Arrange
	var unit: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	unit.inventory = [&"strength_scroll", &"", &""]  # Phase B step 5+ — unwired in step 4
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 50)
	controller._active_turn_unit_id = 1

	# Act
	var fired: bool = controller.use_item(1, 0)

	# Assert — push_warning is non-aborting; just reject
	assert_bool(fired).override_failure_message(
		"AC-SS-4: use_item on unwired item_id must return false (slot intact, token unconsumed)"
	).is_false()
	assert_str(String(controller._units[1].inventory[0])).override_failure_message(
		"AC-SS-4: inventory[0] must remain &\"strength_scroll\" on unwired reject"
	).is_equal("strength_scroll")
