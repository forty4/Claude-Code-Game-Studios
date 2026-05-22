## Critical chain momentum tests for GridBattleController.
##
## S73 backfill — S72 Critical chain (commit `66576b6`). Per-side chain
## counter increments on REAR HIT, resets at round boundary, scales damage
## via lv1=+10% / lv2=+25% / lv3+=+50% cap. Signal critical_chain_changed
## fires (side, level) on every chain advance.

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


# ─── Helpers ────────────────────────────────────────────────────────────────

func _make_unit(unit_id: int, pos: Vector2i, side: int, facing: int = 0,
		attack_range: int = 1) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.hero_id = StringName("test_hero_%d" % unit_id)
	unit.unit_class = 0  # CAVALRY
	unit.position = pos
	unit.side = side
	unit.facing = facing
	unit.attack_range = attack_range
	unit.move_range = 3
	unit.raw_atk = 50
	unit.raw_def = 20
	return unit


func _setup(roster: Array[BattleUnit]) -> GridBattleController:
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
	controller._rng = RandomNumberGenerator.new()
	controller._rng.seed = 12345
	return controller


# ─── _critical_chain_bonus_for (static, pure function) ─────────────────────

func test_critical_chain_bonus_for_level_0_returns_0() -> void:
	# Level 0 = no chain active = no bonus.
	var bonus: float = GridBattleControllerScript._critical_chain_bonus_for(0)
	assert_float(bonus).is_equal_approx(0.0, 0.001)


func test_critical_chain_bonus_for_level_1_returns_0_10() -> void:
	# Level 1 = first REAR CRIT this round = +10% damage.
	var bonus: float = GridBattleControllerScript._critical_chain_bonus_for(1)
	assert_float(bonus).is_equal_approx(0.10, 0.001)


func test_critical_chain_bonus_for_level_2_returns_0_25() -> void:
	# Level 2 = second consecutive REAR CRIT = +25% damage.
	var bonus: float = GridBattleControllerScript._critical_chain_bonus_for(2)
	assert_float(bonus).is_equal_approx(0.25, 0.001)


func test_critical_chain_bonus_for_level_3_caps_at_0_50() -> void:
	# Level 3 = +50% cap (S72 design choice — runaway momentum bounded).
	var bonus: float = GridBattleControllerScript._critical_chain_bonus_for(3)
	assert_float(bonus).is_equal_approx(0.50, 0.001)


func test_critical_chain_bonus_for_level_5_still_caps_at_0_50() -> void:
	# Cap holds for arbitrary higher levels — no further escalation.
	var bonus: float = GridBattleControllerScript._critical_chain_bonus_for(5)
	assert_float(bonus).is_equal_approx(0.50, 0.001)


func test_critical_chain_bonus_for_negative_level_returns_0() -> void:
	# Defensive: negative level (shouldn't happen, but guard against int underflow).
	var bonus: float = GridBattleControllerScript._critical_chain_bonus_for(-1)
	assert_float(bonus).is_equal_approx(0.0, 0.001)


# ─── Chain state: initial + reset semantics ────────────────────────────────

func test_critical_chain_per_side_initial_state_is_zero() -> void:
	# Fresh controller: both sides start at chain level 0.
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var defender: BattleUnit = _make_unit(2, Vector2i(2, 3), 1)
	var controller: GridBattleController = _setup([attacker, defender])

	assert_int(controller._critical_chain_per_side[0] as int).is_equal(0)
	assert_int(controller._critical_chain_per_side[1] as int).is_equal(0)


func test_round_started_resets_chain_state_both_sides() -> void:
	# Simulate prior round chain accumulation, then verify _on_round_started
	# clears both sides (S72 design — momentum lives within a round).
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var defender: BattleUnit = _make_unit(2, Vector2i(2, 3), 1)
	var controller: GridBattleController = _setup([attacker, defender])
	controller._critical_chain_per_side[0] = 3  # simulate prior chain
	controller._critical_chain_per_side[1] = 1

	controller._on_round_started(2)

	assert_int(controller._critical_chain_per_side[0] as int).is_equal(0)
	assert_int(controller._critical_chain_per_side[1] as int).is_equal(0)


func test_round_started_reset_emits_critical_chain_changed_for_both_sides() -> void:
	# Reset must emit critical_chain_changed(side, 0) for both sides so HUD
	# indicators can clear synchronously with the round transition.
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var defender: BattleUnit = _make_unit(2, Vector2i(2, 3), 1)
	var controller: GridBattleController = _setup([attacker, defender])
	controller._critical_chain_per_side[0] = 2
	var captures: Array = []
	controller.critical_chain_changed.connect(func(side: int, level: int) -> void:
		captures.append({"side": side, "level": level})
	)

	controller._on_round_started(2)

	# Expect at least 2 emissions: one for side 0 (level 0), one for side 1 (level 0).
	assert_int(captures.size()).is_greater_equal(2)
	var side_0_reset: bool = false
	var side_1_reset: bool = false
	for c: Dictionary in captures:
		if (c.side as int) == 0 and (c.level as int) == 0:
			side_0_reset = true
		if (c.side as int) == 1 and (c.level as int) == 0:
			side_1_reset = true
	assert_bool(side_0_reset).is_true()
	assert_bool(side_1_reset).is_true()


# ─── Chain increment on REAR HIT (integration with _resolve_attack) ────────

func test_rear_hit_increments_chain_to_level_1() -> void:
	# Attacker south of defender; defender faces N → REAR exposed from S.
	# First REAR HIT must increment chain to level 1.
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 3), 0)
	var defender: BattleUnit = _make_unit(2, Vector2i(2, 2), 1, 0)  # facing N
	var controller: GridBattleController = _setup([attacker, defender])

	controller._resolve_attack(attacker, defender)

	assert_int(controller._critical_chain_per_side[0] as int).is_equal(1)


func test_two_consecutive_rear_hits_same_side_advance_chain_to_level_2() -> void:
	# Same attacker side performs 2 REAR HITs in same round (no reset
	# between) → chain advances to level 2.
	var attacker_a: BattleUnit = _make_unit(1, Vector2i(2, 3), 0)
	var attacker_b: BattleUnit = _make_unit(3, Vector2i(4, 3), 0)
	var defender_a: BattleUnit = _make_unit(2, Vector2i(2, 2), 1, 0)  # facing N
	var defender_b: BattleUnit = _make_unit(4, Vector2i(4, 2), 1, 0)  # facing N
	var controller: GridBattleController = _setup([attacker_a, attacker_b, defender_a, defender_b])

	controller._resolve_attack(attacker_a, defender_a)
	controller._resolve_attack(attacker_b, defender_b)

	assert_int(controller._critical_chain_per_side[0] as int).is_equal(2)


func test_rear_hits_on_opposite_sides_do_not_share_chain() -> void:
	# Player and enemy each land REAR — chains are per-side independent.
	var player_attacker: BattleUnit = _make_unit(1, Vector2i(2, 3), 0)
	var player_defender: BattleUnit = _make_unit(3, Vector2i(4, 3), 0, 0)  # facing N, rear=S
	var enemy_attacker: BattleUnit = _make_unit(2, Vector2i(4, 4), 1)
	var enemy_defender: BattleUnit = _make_unit(4, Vector2i(2, 2), 1, 0)  # facing N
	var controller: GridBattleController = _setup([player_attacker, player_defender, enemy_attacker, enemy_defender])

	# Player side 0 hits enemy_defender from REAR
	controller._resolve_attack(player_attacker, enemy_defender)
	# Enemy side 1 hits player_defender from REAR
	controller._resolve_attack(enemy_attacker, player_defender)

	assert_int(controller._critical_chain_per_side[0] as int).is_equal(1)
	assert_int(controller._critical_chain_per_side[1] as int).is_equal(1)


func test_front_hit_does_not_increment_chain() -> void:
	# Attacker NORTH of defender; defender also faces N → FRONT angle.
	# FRONT must NOT increment chain (only REAR is critical).
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 1), 0)
	var defender: BattleUnit = _make_unit(2, Vector2i(2, 2), 1, 0)  # facing N
	var controller: GridBattleController = _setup([attacker, defender])

	controller._resolve_attack(attacker, defender)

	assert_int(controller._critical_chain_per_side[0] as int).is_equal(0)


func test_rear_hit_emits_critical_chain_changed_with_new_level() -> void:
	# Signal critical_chain_changed must fire with (side, new_level) on every
	# REAR HIT chain advance — view layer needs this for HUD indicator.
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 3), 0)
	var defender: BattleUnit = _make_unit(2, Vector2i(2, 2), 1, 0)  # facing N
	var controller: GridBattleController = _setup([attacker, defender])
	var captures: Array = []
	controller.critical_chain_changed.connect(func(side: int, level: int) -> void:
		captures.append({"side": side, "level": level})
	)

	controller._resolve_attack(attacker, defender)

	# Expect at least one emit with side=0, level=1.
	var found: bool = false
	for c: Dictionary in captures:
		if (c.side as int) == 0 and (c.level as int) == 1:
			found = true
			break
	assert_bool(found).override_failure_message(
		"Expected critical_chain_changed(side=0, level=1) emit; captured: %s" % str(captures)
	).is_true()


func test_critical_hit_landed_carries_chain_level_payload() -> void:
	# critical_hit_landed signal carries chain_level as final arg so view layer
	# can render the chain badge ("치명타 ×N!") synchronously with the hit.
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 3), 0)
	var defender: BattleUnit = _make_unit(2, Vector2i(2, 2), 1, 0)  # facing N
	var controller: GridBattleController = _setup([attacker, defender])
	var captures: Array = []
	controller.critical_hit_landed.connect(
		func(_a: int, _d: int, _dmg: int, _angle: StringName, chain_level: int) -> void:
			captures.append({"chain_level": chain_level})
	)

	controller._resolve_attack(attacker, defender)

	assert_int(captures.size()).is_equal(1)
	assert_int(captures[0].chain_level as int).is_equal(1)
