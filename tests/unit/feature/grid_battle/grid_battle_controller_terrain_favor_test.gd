## grid_battle_controller_terrain_favor_test.gd
##
## Session-55: per-(unit_class, terrain) ternary favor signal exposed via
## get_terrain_favor_for_unit() + get_movable_favors() batch helper. Used by
## ChapterVisuals to tint movement-range preview tiles green/red/blue based
## on whether the terrain HELPS this specific unit class.
##
## Coverage:
##   - CAVALRY × MOUNTAIN (cost 3.0)        → -1 disadvantage
##   - CAVALRY × FOREST  (cost 2.0)         → -1 (cost dominates even with surv=20)
##   - CAVALRY × HILLS   (cost 1.5)         → 0  (float precision; not int-trunc'd to 1)
##   - INFANTRY × FOREST (cost 1.0, surv 20)→ +1 (no penalty + survivable)
##   - SCOUT × FOREST    (cost 0.7)         → +1 (faster than plains)
##   - ARCHER × MOUNTAIN (cost 2.0)         → -1
##   - any × PLAINS                          → 0
##   - get_movable_favors batch length-matches input
##   - Defensive: missing unit / null tile / OOB → 0
##
## Mirrors grid_battle_controller_high_ground_test.gd setup pattern.
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


func _make_unit(unit_id: int, unit_class: int, pos: Vector2i) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.hero_id = StringName("test_unit_%d" % unit_id)
	unit.unit_class = unit_class
	unit.position = pos
	unit.side = 0
	unit.attack_range = 1
	unit.move_range = 4
	unit.raw_atk = 40
	unit.raw_def = 18
	return unit


## Builds a 10x10 stub grid with per-coord terrain overrides supplied via the
## terrains Dict (Vector2i → TerrainCost int). Returns the wired controller and
## the map_grid for assertion helpers.
func _setup(roster: Array[BattleUnit], terrains: Dictionary = {}) -> Dictionary:
	var map_grid: MapGridStub = MapGridStubScript.new()
	map_grid.set_dimensions_for_test(Vector2i(10, 10))
	for coord: Vector2i in terrains.keys():
		map_grid.set_terrain_type_for_test(coord, terrains[coord] as int)
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


# ─── DISADVANTAGE cases: cost >= 2.0 dominates ───────────────────────────────


func test_terrain_favor_cavalry_on_mountain_returns_disadvantage() -> void:
	var unit: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.CAVALRY), Vector2i(2, 2))
	var bag: Dictionary = _setup([unit], {Vector2i(3, 2): TerrainCost.MOUNTAIN})
	var controller: GridBattleController = bag["controller"]

	var favor: int = controller.get_terrain_favor_for_unit(1, Vector2i(3, 2))

	assert_int(favor).override_failure_message(
		"CAVALRY × MOUNTAIN (cost 3.0) must be DISADVANTAGE (-1); got %d" % favor
	).is_equal(-1)


func test_terrain_favor_cavalry_on_forest_returns_disadvantage_despite_survivability() -> void:
	# CAVALRY/FOREST: cost=2.0 (penalty), defense+evasion=20 (survivable).
	# Mobility loss MUST dominate the favor signal — the player must see "your
	# cavalry will be slowed", not "your cavalry will be hidden".
	var unit: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.CAVALRY), Vector2i(2, 2))
	var bag: Dictionary = _setup([unit], {Vector2i(3, 2): TerrainCost.FOREST})
	var controller: GridBattleController = bag["controller"]

	var favor: int = controller.get_terrain_favor_for_unit(1, Vector2i(3, 2))

	assert_int(favor).is_equal(-1)


func test_terrain_favor_archer_on_mountain_returns_disadvantage() -> void:
	var unit: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.ARCHER), Vector2i(2, 2))
	var bag: Dictionary = _setup([unit], {Vector2i(3, 2): TerrainCost.MOUNTAIN})
	var controller: GridBattleController = bag["controller"]

	var favor: int = controller.get_terrain_favor_for_unit(1, Vector2i(3, 2))

	assert_int(favor).is_equal(-1)


# ─── ADVANTAGE cases: cost < 1.0 OR (cost <= 1.0 AND survivability >= 15) ───


func test_terrain_favor_scout_on_forest_returns_advantage_from_speed() -> void:
	# SCOUT/FOREST: cost=0.7 (faster than plains) — pure speed advantage.
	var unit: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.SCOUT), Vector2i(2, 2))
	var bag: Dictionary = _setup([unit], {Vector2i(3, 2): TerrainCost.FOREST})
	var controller: GridBattleController = bag["controller"]

	var favor: int = controller.get_terrain_favor_for_unit(1, Vector2i(3, 2))

	assert_int(favor).override_failure_message(
		"SCOUT × FOREST (cost 0.7) must be ADVANTAGE (+1); got %d" % favor
	).is_equal(1)


func test_terrain_favor_infantry_on_forest_returns_advantage_from_survivability() -> void:
	# INFANTRY/FOREST: cost=1.0 (no penalty), defense+evasion=20 (survivable).
	var unit: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.INFANTRY), Vector2i(2, 2))
	var bag: Dictionary = _setup([unit], {Vector2i(3, 2): TerrainCost.FOREST})
	var controller: GridBattleController = bag["controller"]

	var favor: int = controller.get_terrain_favor_for_unit(1, Vector2i(3, 2))

	assert_int(favor).is_equal(1)


func test_terrain_favor_infantry_on_hills_returns_advantage() -> void:
	# INFANTRY/HILLS: cost=1.0 (no penalty), defense=15 (good defense, eva=0).
	var unit: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.INFANTRY), Vector2i(2, 2))
	var bag: Dictionary = _setup([unit], {Vector2i(3, 2): TerrainCost.HILLS})
	var controller: GridBattleController = bag["controller"]

	var favor: int = controller.get_terrain_favor_for_unit(1, Vector2i(3, 2))

	assert_int(favor).is_equal(1)


# ─── NEUTRAL cases: 1.0 < cost < 2.0 (float precision — NOT int-trunc'd) ─────


func test_terrain_favor_cavalry_on_hills_returns_neutral_not_advantage() -> void:
	# Regression: CAVALRY/HILLS cost=1.5 must NOT be trunc'd to 1 then read as
	# advantage. The float comparison cost<=1.0 keeps this strictly neutral.
	var unit: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.CAVALRY), Vector2i(2, 2))
	var bag: Dictionary = _setup([unit], {Vector2i(3, 2): TerrainCost.HILLS})
	var controller: GridBattleController = bag["controller"]

	var favor: int = controller.get_terrain_favor_for_unit(1, Vector2i(3, 2))

	assert_int(favor).override_failure_message(
		"CAVALRY × HILLS (cost 1.5) must be NEUTRAL (0); got %d" % favor
	).is_equal(0)


func test_terrain_favor_any_unit_on_plains_returns_neutral() -> void:
	# PLAINS: cost=1.0, defense+evasion=0 — neutral for every class.
	var unit: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.INFANTRY), Vector2i(2, 2))
	var bag: Dictionary = _setup([unit], {Vector2i(3, 2): TerrainCost.PLAINS})
	var controller: GridBattleController = bag["controller"]

	var favor: int = controller.get_terrain_favor_for_unit(1, Vector2i(3, 2))

	assert_int(favor).is_equal(0)


# ─── Batch helper get_movable_favors ─────────────────────────────────────────


func test_get_movable_favors_returns_index_aligned_array() -> void:
	var unit: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.CAVALRY), Vector2i(2, 2))
	var bag: Dictionary = _setup([unit], {
		Vector2i(3, 2): TerrainCost.MOUNTAIN,  # -1
		Vector2i(2, 3): TerrainCost.PLAINS,    #  0
		Vector2i(4, 2): TerrainCost.FOREST,    # -1 (CAVALRY × FOREST)
	})
	var controller: GridBattleController = bag["controller"]

	var tiles: PackedVector2Array = PackedVector2Array([
		Vector2(3, 2), Vector2(2, 3), Vector2(4, 2)
	])
	var favors: PackedInt32Array = controller.get_movable_favors(1, tiles)

	assert_int(favors.size()).is_equal(tiles.size())
	assert_int(favors[0]).is_equal(-1)
	assert_int(favors[1]).is_equal(0)
	assert_int(favors[2]).is_equal(-1)


func test_get_movable_favors_empty_input_returns_empty_output() -> void:
	var unit: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.SCOUT), Vector2i(2, 2))
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]

	var favors: PackedInt32Array = controller.get_movable_favors(1, PackedVector2Array())

	assert_int(favors.size()).is_equal(0)


# ─── Defensive paths: missing unit / null map / impassable terrain ───────────


func test_terrain_favor_missing_unit_returns_neutral() -> void:
	var unit: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.CAVALRY), Vector2i(2, 2))
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]

	# Unknown unit_id 99 — defensive return.
	assert_int(controller.get_terrain_favor_for_unit(99, Vector2i(3, 2))).is_equal(0)


func test_terrain_favor_on_impassable_terrain_returns_neutral() -> void:
	# RIVER (4) is impassable per CR-4a — never on movable list, but the helper
	# must not crash or attempt the UnitRole lookup (terrain_cost_table lacks
	# the impassable indices).
	var unit: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.SCOUT), Vector2i(2, 2))
	var bag: Dictionary = _setup([unit], {Vector2i(3, 2): TerrainCost.RIVER})
	var controller: GridBattleController = bag["controller"]

	assert_int(controller.get_terrain_favor_for_unit(1, Vector2i(3, 2))).is_equal(0)
