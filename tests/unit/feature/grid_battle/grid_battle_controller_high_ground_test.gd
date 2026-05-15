## grid_battle_controller_high_ground_test.gd
##
## Session-15: ARCHER HIGH_GROUND_BONUS wiring at the controller layer.
##   - BattleScene._passive_for_class returns &"passive_high_ground_shot" for ARCHER
##   - _resolve_attack + preview_attack query MapGrid for attacker terrain_type
##     and pass on_high_ground into AttackerContext so DamageCalc gates the +15%
##   - Public helper is_high_ground_ready(unit_id) mirrors the same gate
##     (class + passive + on HILLS) for the ChapterVisuals halo
##
## Mirrors grid_battle_controller_ambush_test.gd / charge_test.gd setup pattern.
extends GdUnitTestSuite

const GridBattleControllerScript: GDScript = preload("res://src/feature/grid_battle/grid_battle_controller.gd")
const BattleSceneScript: GDScript = preload("res://src/feature/battle_scene/battle_scene.gd")
const MapGridStubScript: GDScript = preload("res://tests/helpers/map_grid_stub.gd")
const HPStatusControllerStubScript: GDScript = preload("res://tests/helpers/hp_status_controller_stub.gd")
const TurnOrderRunnerStubScript: GDScript = preload("res://tests/helpers/turn_order_runner_stub.gd")
const HeroDatabaseStubScript: GDScript = preload("res://tests/helpers/hero_database_stub.gd")
const TerrainEffectStubScript: GDScript = preload("res://tests/helpers/terrain_effect_stub.gd")
const UnitRoleStubScript: GDScript = preload("res://tests/helpers/unit_role_stub.gd")
const BattleCameraStubScript: GDScript = preload("res://tests/helpers/battle_camera_stub.gd")


func before_test() -> void:
	(load("res://src/foundation/balance/balance_constants.gd") as GDScript).set("_cache_loaded", false)


func _make_archer(unit_id: int, pos: Vector2i, side: int,
		passive: StringName = &"passive_high_ground_shot") -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.hero_id = StringName("test_archer_%d" % unit_id)
	unit.unit_class = int(UnitRole.UnitClass.ARCHER)
	unit.position = pos
	unit.side = side
	unit.attack_range = 2  # ARCHER ranged baseline
	unit.move_range = 3
	unit.raw_atk = 60
	unit.raw_def = 18
	unit.passive = passive
	return unit


func _make_target(unit_id: int, pos: Vector2i, side: int) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.hero_id = StringName("test_target_%d" % unit_id)
	unit.unit_class = int(UnitRole.UnitClass.INFANTRY)
	unit.position = pos
	unit.side = side
	unit.attack_range = 1
	unit.move_range = 3
	unit.raw_atk = 40
	unit.raw_def = 18
	return unit


func _setup(roster: Array[BattleUnit], hills_coords: Array[Vector2i] = []) -> Dictionary:
	var map_grid: MapGridStub = MapGridStubScript.new()
	map_grid.set_dimensions_for_test(Vector2i(10, 10))
	for coord: Vector2i in hills_coords:
		map_grid.set_terrain_type_for_test(coord, TerrainCost.HILLS)
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
	return {"controller": controller, "map_grid": map_grid}


# ─── BattleScene._passive_for_class wiring ───────────────────────────────────


func test_archer_class_resolves_to_passive_high_ground_shot() -> void:
	var scene: BattleScene = BattleSceneScript.new()
	auto_free(scene)
	assert_str(String(scene._passive_for_class(int(UnitRole.UnitClass.ARCHER)))).is_equal("passive_high_ground_shot")
	# Other class mappings unaffected
	assert_str(String(scene._passive_for_class(int(UnitRole.UnitClass.CAVALRY)))).is_equal("passive_charge")
	assert_str(String(scene._passive_for_class(int(UnitRole.UnitClass.SCOUT)))).is_equal("passive_ambush")
	assert_str(String(scene._passive_for_class(int(UnitRole.UnitClass.INFANTRY)))).is_equal("")


# ─── Damage shifts when ARCHER stands on HILLS ───────────────────────────────


func test_preview_damage_higher_when_archer_on_hills_terrain() -> void:
	# Same ARCHER, same target — only difference is the attacker tile's terrain.
	var attacker_a: BattleUnit = _make_archer(1, Vector2i(2, 2), 0)
	var defender_a: BattleUnit = _make_target(2, Vector2i(3, 2), 1)
	var bag_a: Dictionary = _setup([attacker_a, defender_a])  # no HILLS
	var ctl_a: GridBattleController = bag_a["controller"]
	var damage_off: int = int(ctl_a.preview_attack(1, 2)["damage"])

	var attacker_b: BattleUnit = _make_archer(1, Vector2i(2, 2), 0)
	var defender_b: BattleUnit = _make_target(2, Vector2i(3, 2), 1)
	var bag_b: Dictionary = _setup([attacker_b, defender_b], [Vector2i(2, 2)])  # attacker on HILLS
	var ctl_b: GridBattleController = bag_b["controller"]
	var damage_on: int = int(ctl_b.preview_attack(1, 2)["damage"])

	assert_int(damage_on).override_failure_message(
		"ARCHER on HILLS damage (%d) must exceed off-HILLS baseline (%d) by ~15%%"
		% [damage_on, damage_off]
	).is_greater(damage_off)


func test_resolve_attack_higher_damage_when_archer_on_hills() -> void:
	# Production damage path counterpart of the preview test above.
	var attacker_a: BattleUnit = _make_archer(1, Vector2i(2, 2), 0)
	var defender_a: BattleUnit = _make_target(2, Vector2i(3, 2), 1)
	var bag_a: Dictionary = _setup([attacker_a, defender_a])
	var ctl_a: GridBattleController = bag_a["controller"]
	var dmg_off: int = ctl_a._resolve_attack(attacker_a, defender_a)

	var attacker_b: BattleUnit = _make_archer(1, Vector2i(2, 2), 0)
	var defender_b: BattleUnit = _make_target(2, Vector2i(3, 2), 1)
	var bag_b: Dictionary = _setup([attacker_b, defender_b], [Vector2i(2, 2)])
	var ctl_b: GridBattleController = bag_b["controller"]
	var dmg_on: int = ctl_b._resolve_attack(attacker_b, defender_b)

	assert_int(dmg_on).is_greater(dmg_off)


# ─── is_high_ground_ready helper (visual feedback gate) ──────────────────────


func test_is_high_ground_ready_true_when_archer_on_hills_with_passive() -> void:
	var attacker: BattleUnit = _make_archer(1, Vector2i(2, 2), 0)
	var defender: BattleUnit = _make_target(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender], [Vector2i(2, 2)])
	var controller: GridBattleController = bag["controller"]

	assert_bool(controller.is_high_ground_ready(1)).is_true()


func test_is_high_ground_ready_false_when_off_hills() -> void:
	# ARCHER + passive carried, but not on HILLS — visual gate must close.
	var attacker: BattleUnit = _make_archer(1, Vector2i(2, 2), 0)
	var defender: BattleUnit = _make_target(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender])  # no HILLS coords
	var controller: GridBattleController = bag["controller"]

	assert_bool(controller.is_high_ground_ready(1)).is_false()


func test_is_high_ground_ready_false_for_non_archer_class() -> void:
	# CAVALRY on HILLS — class mutex; helper returns false even on HILLS.
	var attacker: BattleUnit = _make_archer(1, Vector2i(2, 2), 0)
	attacker.unit_class = int(UnitRole.UnitClass.CAVALRY)
	var defender: BattleUnit = _make_target(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender], [Vector2i(2, 2)])
	var controller: GridBattleController = bag["controller"]

	assert_bool(controller.is_high_ground_ready(1)).is_false()


func test_is_high_ground_ready_false_without_passive() -> void:
	# ARCHER on HILLS without passive_high_ground_shot (e.g., stripped) — gate closes.
	var attacker: BattleUnit = _make_archer(1, Vector2i(2, 2), 0, &"")
	var defender: BattleUnit = _make_target(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender], [Vector2i(2, 2)])
	var controller: GridBattleController = bag["controller"]

	assert_bool(controller.is_high_ground_ready(1)).is_false()


# ─── Forecast surfaces high_ground in source_flags / passives ────────────────


func test_preview_source_flags_include_high_ground_when_bonus_fires() -> void:
	var attacker: BattleUnit = _make_archer(1, Vector2i(2, 2), 0)
	var defender: BattleUnit = _make_target(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender], [Vector2i(2, 2)])
	var controller: GridBattleController = bag["controller"]

	var preview: Dictionary = controller.preview_attack(1, 2)
	var passives_arr: Array = preview["passives"] as Array
	assert_bool(&"passive_high_ground_shot" in passives_arr).override_failure_message(
		"preview.passives must include passive_high_ground_shot; got %s" % str(passives_arr)
	).is_true()
