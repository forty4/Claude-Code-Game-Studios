## Attack action tests for GridBattleController per ADR-0014 §5 + story-005.
##
## Story-005 AC-1..AC-10: is_tile_in_attack_range + multiplier helpers
## (formation/angle/aura) + _resolve_attack chain + DamageCalc + HPStatusController
## integration + damage_applied signal + ResolveModifiers schema extension.
##
## Test focus: multiplier helper verification (AC-8 expected values) +
## is_tile_in_attack_range matrix + integration via stubbed HPStatusController.
## Full DamageCalc + HPStatusController integration test deferred to per-epic
## integration suite (qa-plan cross-cutting recommendation).

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
		passive: StringName = &"", attack_range: int = 1) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.hero_id = StringName("test_hero_%d" % unit_id)
	unit.unit_class = 0  # CAVALRY (AttackerContext.Class.CAVALRY = 0; in DamageCalc bridge dict)
	unit.position = pos
	unit.side = side
	unit.facing = facing
	unit.passive = passive
	unit.attack_range = attack_range
	unit.move_range = 3
	unit.raw_atk = 50  # mid-range raw_atk; clamps to ATK_CAP=200 internally
	unit.raw_def = 20
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
	controller.setup(roster, map_grid, camera, hero_db, turn_runner, hp_controller, terrain_effect, unit_role)
	# RNG initialization normally happens in _ready(); inject here for tests that
	# don't add_child the controller (avoids _ready assertions).
	controller._rng = RandomNumberGenerator.new()
	controller._rng.seed = 12345  # deterministic RNG seed for replay
	return {"controller": controller, "hp_controller": hp_controller}


# ─── AC-8: formation_mult verification (chapter-prototype shape) ──────────

func test_compute_formation_mult_zero_adj_returns_1_0() -> void:
	# Lone attacker, no adjacent allies → formation_mult = 1.0.
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var bag: Dictionary = _setup([attacker])
	var controller: GridBattleController = bag["controller"]

	var mult: float = controller._compute_formation_mult(attacker)

	assert_float(mult).is_equal_approx(1.0, 0.001)


func test_compute_formation_mult_2_adj_returns_1_10() -> void:
	# Per AC-8: attacker with 2 adjacent allies → formation_mult == 1.10.
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var ally1: BattleUnit = _make_unit(2, Vector2i(1, 2), 0)  # W of attacker
	var ally2: BattleUnit = _make_unit(3, Vector2i(3, 2), 0)  # E of attacker
	var bag: Dictionary = _setup([attacker, ally1, ally2])
	var controller: GridBattleController = bag["controller"]

	var mult: float = controller._compute_formation_mult(attacker)

	assert_float(mult).is_equal_approx(1.10, 0.001)


func test_compute_formation_mult_4_adj_caps_at_1_20() -> void:
	# Per AC-8: attacker with 4 adjacent allies → formation_mult capped at 1.20.
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var ally_n: BattleUnit = _make_unit(2, Vector2i(2, 1), 0)
	var ally_s: BattleUnit = _make_unit(3, Vector2i(2, 3), 0)
	var ally_e: BattleUnit = _make_unit(4, Vector2i(3, 2), 0)
	var ally_w: BattleUnit = _make_unit(5, Vector2i(1, 2), 0)
	var bag: Dictionary = _setup([attacker, ally_n, ally_s, ally_e, ally_w])
	var controller: GridBattleController = bag["controller"]

	var mult: float = controller._compute_formation_mult(attacker)

	# 1.0 + 0.05 * 4 = 1.20 (also matches cap exactly)
	assert_float(mult).is_equal_approx(1.20, 0.001)


# ─── AC-8: angle_mult verification (4 cases per chapter-prototype) ────────

func test_compute_angle_mult_front_returns_1_0() -> void:
	# Defender faces N (0); attacker is to the N of defender (attacker_dir=N).
	# attacker_dir == defender.facing → "front" → 1.0.
	var defender: BattleUnit = _make_unit(2, Vector2i(2, 2), 1, 0)  # facing N
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 1), 0)  # north of defender
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]

	var mult: float = controller._compute_angle_mult(attacker, defender)

	assert_float(mult).is_equal_approx(1.0, 0.001)


func test_compute_angle_mult_side_returns_1_25() -> void:
	# Defender faces N; attacker is to the E (FLANK side from defender perspective).
	# attacker_dir = E (1); defender.facing = N (0); not front, not rear → "side" → 1.25.
	var defender: BattleUnit = _make_unit(2, Vector2i(2, 2), 1, 0)
	var attacker: BattleUnit = _make_unit(1, Vector2i(3, 2), 0)  # east of defender
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]

	var mult: float = controller._compute_angle_mult(attacker, defender)

	assert_float(mult).is_equal_approx(1.25, 0.001)


func test_compute_angle_mult_rear_normal_returns_1_50() -> void:
	# Defender faces N (0); attacker is to the S of defender (attacker_dir=S=2).
	# (defender.facing + 2) % 4 = 2; attacker_dir == 2 → "rear" → 1.50 (no rear_specialist).
	var defender: BattleUnit = _make_unit(2, Vector2i(2, 2), 1, 0)
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 3), 0)  # south of defender
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]

	var mult: float = controller._compute_angle_mult(attacker, defender)

	assert_float(mult).is_equal_approx(1.50, 0.001)


func test_compute_angle_mult_rear_with_rear_specialist_returns_1_75() -> void:
	# Per AC-8: 황충 (rear_specialist passive) attacking from rear → 1.75.
	var defender: BattleUnit = _make_unit(2, Vector2i(2, 2), 1, 0)  # facing N
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 3), 0, 0, &"rear_specialist")
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]

	var mult: float = controller._compute_angle_mult(attacker, defender)

	assert_float(mult).is_equal_approx(1.75, 0.001)


# ─── AC-8: aura_mult verification (command_aura adjacency) ─────────────────

func test_compute_aura_mult_command_aura_adjacent_returns_1_15() -> void:
	# Per AC-8: 유비 (command_aura passive) adjacent to attacker → aura_mult == 1.15.
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var liu_bei: BattleUnit = _make_unit(2, Vector2i(1, 2), 0, 0, &"command_aura")
	var bag: Dictionary = _setup([attacker, liu_bei])
	var controller: GridBattleController = bag["controller"]

	var mult: float = controller._compute_aura_mult(attacker)

	assert_float(mult).is_equal_approx(1.15, 0.001)


func test_compute_aura_mult_no_command_aura_returns_1_0() -> void:
	# No command_aura ally adjacent → aura_mult = 1.0.
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var ally_no_aura: BattleUnit = _make_unit(2, Vector2i(1, 2), 0, 0, &"")  # no passive
	var bag: Dictionary = _setup([attacker, ally_no_aura])
	var controller: GridBattleController = bag["controller"]

	var mult: float = controller._compute_aura_mult(attacker)

	assert_float(mult).is_equal_approx(1.0, 0.001)


# ─── AC-1: is_tile_in_attack_range matrix ──────────────────────────────────

func test_is_tile_in_attack_range_valid_enemy_target_returns_true() -> void:
	# Attacker at (2,2) attack_range=1; enemy at (2,3) (Manhattan=1) → true.
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(2, 3), 1)
	var bag: Dictionary = _setup([attacker, enemy])
	var controller: GridBattleController = bag["controller"]

	assert_bool(controller.is_tile_in_attack_range(Vector2i(2, 3), 1)).is_true()


func test_is_tile_in_attack_range_own_unit_returns_false() -> void:
	# Cannot attack own units (both side 0).
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var ally: BattleUnit = _make_unit(2, Vector2i(2, 3), 0)
	var bag: Dictionary = _setup([attacker, ally])
	var controller: GridBattleController = bag["controller"]

	assert_bool(controller.is_tile_in_attack_range(Vector2i(2, 3), 1)).is_false()


func test_is_tile_in_attack_range_out_of_range_returns_false() -> void:
	# Attacker at (2,2) attack_range=1; enemy at (5,5) Manhattan=6 > 1.
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(5, 5), 1)
	var bag: Dictionary = _setup([attacker, enemy])
	var controller: GridBattleController = bag["controller"]

	assert_bool(controller.is_tile_in_attack_range(Vector2i(5, 5), 1)).is_false()


func test_is_tile_in_attack_range_empty_tile_returns_false() -> void:
	# No enemy at target tile → false.
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var bag: Dictionary = _setup([attacker])
	var controller: GridBattleController = bag["controller"]

	assert_bool(controller.is_tile_in_attack_range(Vector2i(2, 3), 1)).is_false()


func test_is_tile_in_attack_range_huangzhong_range_2_ranged() -> void:
	# 황충 ranged exception per ADR-0014 §0: attack_range=2.
	var huangzhong: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, 0, &"rear_specialist", 2)
	var enemy: BattleUnit = _make_unit(2, Vector2i(4, 2), 1)  # Manhattan=2
	var bag: Dictionary = _setup([huangzhong, enemy])
	var controller: GridBattleController = bag["controller"]

	assert_bool(controller.is_tile_in_attack_range(Vector2i(4, 2), 1)).is_true()


# ─── AC-2, AC-6: _handle_attack full chain emits damage_applied ────────────

func test_handle_attack_full_chain_emits_damage_applied() -> void:
	# Attacker at (2,2) facing N attacks adjacent enemy at (2,3) facing N
	# (defender's rear is exposed from south). Full DamageCalc chain runs.
	# Verify: damage_applied signal emitted exactly once with positive damage.
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)  # player
	var defender: BattleUnit = _make_unit(2, Vector2i(2, 3), 1, 0)  # enemy facing N
	# Story-006: 2nd alive player unit gates auto-handoff so _acted_this_turn
	# persists for assertion. Placed at (7, 7) — out of attack range.
	var ally: BattleUnit = _make_unit(3, Vector2i(7, 7), 0)  # player
	var bag: Dictionary = _setup([attacker, defender, ally])
	var controller: GridBattleController = bag["controller"]
	var captures: Array = []
	controller.damage_applied.connect(func(att_id: int, def_id: int, dmg: int) -> void:
		captures.append({"att_id": att_id, "def_id": def_id, "dmg": dmg})
	)

	controller._handle_attack(1, 2)

	# Exactly 1 damage_applied emit
	assert_int(captures.size()).is_equal(1)
	assert_int(captures[0].att_id as int).is_equal(1)
	assert_int(captures[0].def_id as int).is_equal(2)
	# Damage > 0 on HIT (RNG-seeded; deterministic; should not roll evasion at terrain_evasion=0)
	assert_int(captures[0].dmg as int).is_greater(0)
	# Acted-this-turn populated by _consume_unit_action
	assert_bool(controller._acted_this_turn.get(1, false)).is_true()
	# _last_attacker_id tracked for story-008
	assert_int(controller._last_attacker_id).is_equal(1)


# ─── Story-008 hook: rear-attack increments _fate_rear_attacks ─────────────

func test_resolve_attack_rear_increments_fate_rear_attacks() -> void:
	# Story-008 partial integration: rear attack increments _fate_rear_attacks +
	# emits hidden_fate_condition_progressed.
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 3), 0)  # south of defender
	var defender: BattleUnit = _make_unit(2, Vector2i(2, 2), 1, 0)  # facing N (rear=S)
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]
	var fate_captures: Array = []
	controller.hidden_fate_condition_progressed.connect(func(condition: StringName, value: int) -> void:
		fate_captures.append({"condition": condition, "value": value})
	)

	controller._resolve_attack(attacker, defender)

	assert_int(controller._fate_rear_attacks).is_equal(1)
	assert_int(fate_captures.size()).is_equal(1)
	assert_str(String(fate_captures[0].condition)).is_equal("rear_attacks")
	assert_int(fate_captures[0].value as int).is_equal(1)


# ─── Re-entrancy: _handle_attack silent on already-acted unit ──────────────

func test_handle_attack_re_entrancy_silent_after_act() -> void:
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var defender: BattleUnit = _make_unit(2, Vector2i(2, 3), 1, 0)
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]
	# Pre-mark attacker as acted-this-turn
	controller._acted_this_turn[1] = true
	var captures: Array = []
	controller.damage_applied.connect(func(att_id: int, def_id: int, dmg: int) -> void:
		captures.append({"att_id": att_id})
	)

	controller._handle_attack(1, 2)

	# No damage_applied emit (re-entrancy guard)
	assert_int(captures.size()).is_equal(0)
