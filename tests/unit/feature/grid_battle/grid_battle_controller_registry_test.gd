## Registry tests for GridBattleController — BattleUnit Resource population +
## tag-based fate-counter unit detection per ADR-0014 §3 + story-002.
##
## Story-002: BattleUnit (~11 fields, Resource) + _units Dictionary registry +
## tag-based fate detection. Tag taxonomy (MVP): &"tank" / &"assassin" / &"boss".
## Untagged → fate slot remains -1.

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
	# G-15 isolation — reset BalanceConstants cache between tests.
	(load("res://src/foundation/balance/balance_constants.gd") as GDScript).set("_cache_loaded", false)


# ─── Helper: build a 4-unit fixture (1 tank + 1 assassin + 1 boss + 1 untagged) ─

func _make_tagged_fixture() -> Array[BattleUnit]:
	var roster: Array[BattleUnit] = []
	var tank: BattleUnit = BattleUnit.new()
	tank.unit_id = 1
	tank.tag = &"tank"
	tank.side = 0  # player tank (장비)
	roster.append(tank)
	var assassin: BattleUnit = BattleUnit.new()
	assassin.unit_id = 2
	assassin.tag = &"assassin"
	assassin.side = 0  # player assassin (조운)
	roster.append(assassin)
	var boss: BattleUnit = BattleUnit.new()
	boss.unit_id = 3
	boss.tag = &"boss"
	boss.side = 1  # enemy boss
	roster.append(boss)
	var untagged: BattleUnit = BattleUnit.new()
	untagged.unit_id = 4
	untagged.tag = &""
	untagged.side = 0
	roster.append(untagged)
	return roster


func _setup_controller_with_roster(roster: Array[BattleUnit]) -> GridBattleController:
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
	controller.setup(roster, map_grid, camera, hero_db, turn_runner, hp_controller, terrain_effect, unit_role)
	return controller


# ─── AC-1: BattleUnit Resource instantiates with all 11 @export fields ─────

func test_battle_unit_resource_instantiates_with_all_fields() -> void:
	# Per AC-1: BattleUnit class_name + Resource + 11 @export fields populated
	# with sensible defaults. Verify each field is settable + readable.
	var unit: BattleUnit = BattleUnit.new()
	# ADR-0011 LOCKED fields
	unit.unit_id = 42
	unit.hero_id = &"shu_001_liu_bei"
	unit.unit_class = 3
	unit.is_player_controlled = true
	# ADR-0014 §3 NEW fields
	unit.name = "유비"
	unit.side = 0
	unit.position = Vector2i(2, 3)
	unit.facing = 1  # E
	unit.passive = &"command_aura"
	unit.tag = &"tank"
	unit.move_range = 4
	unit.attack_range = 1

	assert_int(unit.unit_id).is_equal(42)
	assert_str(String(unit.hero_id)).is_equal("shu_001_liu_bei")
	assert_int(unit.unit_class).is_equal(3)
	assert_bool(unit.is_player_controlled).is_true()
	assert_str(unit.name).is_equal("유비")
	assert_int(unit.side).is_equal(0)
	assert_vector(unit.position).is_equal(Vector2i(2, 3))
	assert_int(unit.facing).is_equal(1)
	assert_str(String(unit.passive)).is_equal("command_aura")
	assert_str(String(unit.tag)).is_equal("tank")
	assert_int(unit.move_range).is_equal(4)
	assert_int(unit.attack_range).is_equal(1)


# ─── AC-2: setup() populates _units Dictionary from roster ──────────────────

func test_setup_populates_units_dictionary_from_roster() -> void:
	# Per AC-2: setup() iterates units array → _units[u.unit_id] = u.
	var roster: Array[BattleUnit] = _make_tagged_fixture()
	var controller: GridBattleController = _setup_controller_with_roster(roster)

	assert_int(controller._units.size()).is_equal(4)
	assert_object(controller._units[1]).is_equal(roster[0])  # tank
	assert_object(controller._units[2]).is_equal(roster[1])  # assassin
	assert_object(controller._units[3]).is_equal(roster[2])  # boss
	assert_object(controller._units[4]).is_equal(roster[3])  # untagged


# ─── AC-3, AC-6: tag-based fate-counter detection at setup() ───────────────

func test_setup_detects_three_fate_unit_ids_by_tag() -> void:
	# Per AC-3 + AC-6: 4-unit fixture (1 tank + 1 assassin + 1 boss + 1 untagged)
	# → all 3 fate slots populated; the 4th (untagged) has no slot to fill.
	var roster: Array[BattleUnit] = _make_tagged_fixture()
	var controller: GridBattleController = _setup_controller_with_roster(roster)

	assert_int(controller._fate_tank_unit_id).is_equal(1)
	assert_int(controller._fate_assassin_unit_id).is_equal(2)
	assert_int(controller._fate_boss_unit_id).is_equal(3)


# ─── AC-4: _find_unit_by_tag returns -1 if no match ─────────────────────────

func test_find_unit_by_tag_returns_minus_one_when_tag_missing() -> void:
	# Per AC-4 + AC-6: untagged-only roster → all 3 fate slots = -1.
	var roster: Array[BattleUnit] = []
	var u1: BattleUnit = BattleUnit.new()
	u1.unit_id = 10
	u1.tag = &""
	roster.append(u1)
	var u2: BattleUnit = BattleUnit.new()
	u2.unit_id = 11
	u2.tag = &"unknown_tag"  # not one of {tank, assassin, boss}
	roster.append(u2)
	var controller: GridBattleController = _setup_controller_with_roster(roster)

	# All 3 fate slots should be -1 (no tank, assassin, boss tags in roster)
	assert_int(controller._fate_tank_unit_id).is_equal(-1)
	assert_int(controller._fate_assassin_unit_id).is_equal(-1)
	assert_int(controller._fate_boss_unit_id).is_equal(-1)


# ─── AC-5: BattleUnit type binding stable across DI seam ────────────────────

func test_battle_unit_resource_extends_resource_not_refcounted() -> void:
	# Per AC-1: Resource conversion (was RefCounted at story-001 reference).
	# Verify class hierarchy: Resource extends RefCounted in Godot, so a BattleUnit
	# IS-A both Resource AND RefCounted — but `is Resource` is the canonical check.
	var unit: BattleUnit = BattleUnit.new()
	assert_bool(unit is Resource).override_failure_message(
		"BattleUnit must extend Resource for @export field support per story-002 AC-1"
	).is_true()
	# Resource extends RefCounted — sanity check
	assert_bool(unit is RefCounted).is_true()
