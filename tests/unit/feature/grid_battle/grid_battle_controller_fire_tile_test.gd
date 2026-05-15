## grid_battle_controller_fire_tile_test.gd
##
## Session-21 — ch5 적벽 본전 FIRE terrain (terrain_type=8). At round start,
## every alive unit standing on a FIRE tile takes FIRE_DAMAGE_PER_TURN as
## MAGICAL damage via _apply_fire_damage_on_round_start. The mechanic is
## the signature gameplay hook of the chibi-main chapter: pin/push enemies
## into burning ship debris and watch the tick finish them off.
##
## Coverage:
##   - apply_damage called for unit on FIRE tile at round start
##   - apply_damage NOT called for unit on PLAINS / RIVER / BRIDGE / HILLS
##   - apply_damage NOT called for dead units (is_alive=false)
##   - apply_damage flags carry &"fire" and &"terrain"
##   - apply_damage uses MAGICAL attack_type (1) so shield_wall flat
##     reduction is bypassed (INFANTRY units burn for the full amount)
##   - Both player and enemy units burn if on FIRE (side-agnostic)
##   - BalanceConstant FIRE_DAMAGE_PER_TURN is the resolved damage value
extends GdUnitTestSuite

const GridBattleControllerScript: GDScript = preload("res://src/feature/grid_battle/grid_battle_controller.gd")
const MapGridStubScript: GDScript = preload("res://tests/helpers/map_grid_stub.gd")
const HPStatusControllerStubScript: GDScript = preload("res://tests/helpers/hp_status_controller_stub.gd")
const TurnOrderRunnerStubScript: GDScript = preload("res://tests/helpers/turn_order_runner_stub.gd")
const HeroDatabaseStubScript: GDScript = preload("res://tests/helpers/hero_database_stub.gd")
const TerrainEffectStubScript: GDScript = preload("res://tests/helpers/terrain_effect_stub.gd")
const UnitRoleStubScript: GDScript = preload("res://tests/helpers/unit_role_stub.gd")
const BattleCameraStubScript: GDScript = preload("res://tests/helpers/battle_camera_stub.gd")

const FIRE_TERRAIN_TYPE: int = 8


func before_test() -> void:
	(load("res://src/foundation/balance/balance_constants.gd") as GDScript).set("_cache_loaded", false)


func _make_unit(unit_id: int, pos: Vector2i, side: int) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.hero_id = StringName("test_hero_%d" % unit_id)
	unit.unit_class = 1  # INFANTRY
	unit.position = pos
	unit.side = side
	unit.attack_range = 1
	unit.move_range = 3
	unit.raw_atk = 60
	unit.raw_def = 18
	return unit


func _setup(roster: Array[BattleUnit], fire_coords: Array[Vector2i]) -> GridBattleController:
	var map_grid: MapGridStub = MapGridStubScript.new()
	map_grid.set_dimensions_for_test(Vector2i(10, 10))
	auto_free(map_grid)
	for coord: Vector2i in fire_coords:
		map_grid.set_terrain_type_for_test(coord, FIRE_TERRAIN_TYPE)
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
	return controller


# ─── Direct fire damage trigger (round start path) ───────────────────────────


func test_fire_damage_applies_to_player_unit_standing_on_fire_tile() -> void:
	var player: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var fire_coord: Vector2i = Vector2i(2, 2)
	var controller: GridBattleController = _setup([player], [fire_coord])
	var hp_stub: HPStatusControllerStub = controller._hp_controller
	controller._apply_fire_damage_on_round_start()
	var fire_hits: int = 0
	for entry: Dictionary in hp_stub.apply_damage_calls:
		if (entry["unit_id"] as int) == 1:
			fire_hits += 1
	assert_int(fire_hits).override_failure_message(
		"player unit on FIRE must receive apply_damage call; got %d" % fire_hits
	).is_equal(1)


func test_fire_damage_applies_to_enemy_unit_standing_on_fire_tile() -> void:
	# Side-agnostic — enemies burn too. The whole tactical hook is "push the
	# Wei general into FIRE via STUN", not "shield the player from FIRE".
	var enemy: BattleUnit = _make_unit(2, Vector2i(3, 3), 1)
	var controller: GridBattleController = _setup([enemy], [Vector2i(3, 3)])
	var hp_stub: HPStatusControllerStub = controller._hp_controller
	controller._apply_fire_damage_on_round_start()
	var fire_hits: int = 0
	for entry: Dictionary in hp_stub.apply_damage_calls:
		if (entry["unit_id"] as int) == 2:
			fire_hits += 1
	assert_int(fire_hits).override_failure_message(
		"enemy unit on FIRE must also receive apply_damage call"
	).is_equal(1)


func test_fire_damage_skipped_for_unit_on_plains() -> void:
	var player: BattleUnit = _make_unit(1, Vector2i(5, 5), 0)
	var controller: GridBattleController = _setup([player], [Vector2i(2, 2)])
	var hp_stub: HPStatusControllerStub = controller._hp_controller
	controller._apply_fire_damage_on_round_start()
	for entry: Dictionary in hp_stub.apply_damage_calls:
		assert_int(entry["unit_id"] as int).override_failure_message(
			"unit on PLAINS must not be burned (only FIRE tiles deal damage)"
		).is_not_equal(1)


func test_fire_damage_skipped_for_dead_unit_on_fire_tile() -> void:
	var dead: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var controller: GridBattleController = _setup([dead], [Vector2i(2, 2)])
	var hp_stub: HPStatusControllerStub = controller._hp_controller
	hp_stub.set_alive_for_test(1, false)
	controller._apply_fire_damage_on_round_start()
	for entry: Dictionary in hp_stub.apply_damage_calls:
		assert_int(entry["unit_id"] as int).override_failure_message(
			"dead unit must not be burned (is_alive=false skips)"
		).is_not_equal(1)


# ─── Damage shape: amount, attack_type, source_flags ─────────────────────────


func test_fire_damage_resolved_amount_matches_balance_constant() -> void:
	var player: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var controller: GridBattleController = _setup([player], [Vector2i(2, 2)])
	var hp_stub: HPStatusControllerStub = controller._hp_controller
	controller._apply_fire_damage_on_round_start()
	var expected_damage: int = BalanceConstants.get_const("FIRE_DAMAGE_PER_TURN") as int
	assert_int(hp_stub.apply_damage_calls.size()).is_equal(1)
	var entry: Dictionary = hp_stub.apply_damage_calls[0]
	assert_int(entry["resolved_damage"] as int).override_failure_message(
		"FIRE damage must equal BalanceConstant FIRE_DAMAGE_PER_TURN (%d); got %d"
			% [expected_damage, entry["resolved_damage"] as int]
	).is_equal(expected_damage)


func test_fire_damage_uses_magical_attack_type_to_bypass_shield_wall() -> void:
	# MAGICAL=1 vs PHYSICAL=0. shield_wall flat reduction only fires on PHYSICAL —
	# so MAGICAL fire damage hits INFANTRY units at full value without the
	# shield_wall_flat clamp.
	var player: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var controller: GridBattleController = _setup([player], [Vector2i(2, 2)])
	var hp_stub: HPStatusControllerStub = controller._hp_controller
	controller._apply_fire_damage_on_round_start()
	var entry: Dictionary = hp_stub.apply_damage_calls[0]
	assert_int(entry["attack_type"] as int).override_failure_message(
		"FIRE attack_type must be MAGICAL (1) to bypass shield_wall flat reduction"
	).is_equal(ResolveModifiers.AttackType.MAGICAL)


func test_fire_damage_source_flags_carry_fire_and_terrain() -> void:
	var player: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var controller: GridBattleController = _setup([player], [Vector2i(2, 2)])
	var hp_stub: HPStatusControllerStub = controller._hp_controller
	controller._apply_fire_damage_on_round_start()
	var entry: Dictionary = hp_stub.apply_damage_calls[0]
	var flags: Array = entry["source_flags"] as Array
	assert_bool(&"fire" in flags).override_failure_message(
		"FIRE damage source_flags must contain &\"fire\""
	).is_true()
	assert_bool(&"terrain" in flags).override_failure_message(
		"FIRE damage source_flags must contain &\"terrain\""
	).is_true()


# ─── Multi-unit + non-fire terrain coverage ──────────────────────────────────


func test_only_units_on_fire_are_burned_in_multi_unit_battle() -> void:
	# 4 units on the map: 2 on FIRE, 2 on PLAINS. Only the FIRE-standing
	# pair should appear in apply_damage_calls.
	var burning_player: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var safe_player: BattleUnit = _make_unit(2, Vector2i(5, 5), 0)
	var burning_enemy: BattleUnit = _make_unit(3, Vector2i(1, 0), 1)
	var safe_enemy: BattleUnit = _make_unit(4, Vector2i(6, 6), 1)
	var fire_coords: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0)]
	var controller: GridBattleController = _setup(
		[burning_player, safe_player, burning_enemy, safe_enemy], fire_coords)
	var hp_stub: HPStatusControllerStub = controller._hp_controller
	controller._apply_fire_damage_on_round_start()
	var burned_ids: Dictionary = {}
	for entry: Dictionary in hp_stub.apply_damage_calls:
		burned_ids[entry["unit_id"] as int] = true
	assert_bool(burned_ids.has(1)).override_failure_message(
		"burning_player (id 1) must be in burned set"
	).is_true()
	assert_bool(burned_ids.has(3)).override_failure_message(
		"burning_enemy (id 3) must be in burned set"
	).is_true()
	assert_bool(burned_ids.has(2)).override_failure_message(
		"safe_player (id 2) on PLAINS must NOT be in burned set"
	).is_false()
	assert_bool(burned_ids.has(4)).override_failure_message(
		"safe_enemy (id 4) on PLAINS must NOT be in burned set"
	).is_false()
