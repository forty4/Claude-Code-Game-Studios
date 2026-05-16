## Session-28 — SURVIVE_N_ROUNDS victory-condition tests for GridBattleController.
##
## Covers the new condition-type dispatcher in `_check_battle_end` + the SURVIVE
## victory check hook in `_on_round_started`. Pre-S28 behaviour (ANNIHILATION
## default) is regression-tested via existing turn_limit_test; this file adds
## the SURVIVE-specific paths:
##
##   - VictoryConditions resource: enum default + survive_rounds field shape
##   - Dispatcher SURVIVE: enemy wipeout → no early-WIN shortcut
##   - Dispatcher SURVIVE: player wipeout → DEFEAT_ANNIHILATION
##   - Round-hook SURVIVE: round_num <= survive_rounds → no outcome
##   - Round-hook SURVIVE: round_num > survive_rounds → VICTORY_SURVIVE
##   - Round-hook SURVIVE: _battle_over short-circuit
##   - Default (null vc): no false-positive SURVIVE check (ANNIHILATION path)
##   - outcome_was_win heuristic recognises VICTORY_SURVIVE as a WIN
##
## Gotchas applied:
##   G-15: before_test (NOT before_each)
##   G-6:  auto_free on Node deps
##   G-4:  Array.append capture pattern for signal observers

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
	# Reset BalanceConstants cache so _max_turns load picks up MAX_TURNS_PER_BATTLE
	# from the entities JSON cleanly (mirrors turn_limit_test).
	(load("res://src/foundation/balance/balance_constants.gd") as GDScript).set("_cache_loaded", false)


# ─── Helpers ────────────────────────────────────────────────────────────────


func _make_unit(unit_id: int, pos: Vector2i, side: int = 0) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.position = pos
	unit.side = side
	unit.facing = 0
	unit.move_range = 3
	unit.attack_range = 1
	return unit


## HP stub with per-unit dead-flag override (mirrors turn_limit_test).
class DeadAwareHPStub extends HPStatusControllerStub:
	var _dead_units: Dictionary[int, bool] = {}

	func mark_dead(unit_id: int) -> void:
		_dead_units[unit_id] = true

	func is_alive(unit_id: int) -> bool:
		return not _dead_units.get(unit_id, false)


func _setup(roster: Array[BattleUnit], hp_controller: HPStatusController = null) -> Dictionary:
	var map_grid: MapGridStub = MapGridStubScript.new()
	map_grid.set_dimensions_for_test(Vector2i(8, 8))
	auto_free(map_grid)
	var camera: BattleCameraStub = BattleCameraStubScript.new()
	auto_free(camera)
	var hero_db: HeroDatabaseStub = HeroDatabaseStubScript.new()
	var turn_runner: TurnOrderRunnerStub = TurnOrderRunnerStubScript.new()
	auto_free(turn_runner)
	var hp: HPStatusController = hp_controller if hp_controller != null else HPStatusControllerStubScript.new()
	auto_free(hp)
	var terrain_effect: TerrainEffectStub = TerrainEffectStubScript.new()
	var unit_role: UnitRoleStub = UnitRoleStubScript.new()
	var controller: GridBattleController = GridBattleControllerScript.new()
	auto_free(controller)
	controller.setup(roster, map_grid, camera, hero_db, turn_runner, hp, terrain_effect, unit_role)
	# _max_turns is _ready-loaded; tests bypass tree → set explicitly (mirrors
	# turn_limit_test) to a value high enough that ROUND_CAP doesn't fire
	# during SURVIVE round-threshold tests.
	controller._max_turns = 999
	return {"controller": controller, "hp": hp}


func _make_survive_vc(rounds: int) -> VictoryConditions:
	var vc: VictoryConditions = VictoryConditions.new()
	vc.primary_condition_type = VictoryConditions.ConditionType.SURVIVE_N_ROUNDS
	vc.survive_rounds = rounds
	return vc


# ─── VictoryConditions resource shape ───────────────────────────────────────


func test_victory_conditions_default_is_annihilation() -> void:
	var vc: VictoryConditions = VictoryConditions.new()
	assert_int(vc.primary_condition_type).override_failure_message(
		"VictoryConditions default must be ANNIHILATION (0); got %d" % vc.primary_condition_type
	).is_equal(int(VictoryConditions.ConditionType.ANNIHILATION))
	assert_int(vc.survive_rounds).is_equal(0)
	assert_int(vc.target_unit_ids.size()).is_equal(0)


func test_victory_conditions_enum_distinct_values() -> void:
	assert_int(int(VictoryConditions.ConditionType.ANNIHILATION)).is_equal(0)
	assert_int(int(VictoryConditions.ConditionType.SURVIVE_N_ROUNDS)).is_equal(1)


# ─── Dispatcher: SURVIVE branch ─────────────────────────────────────────────


## SURVIVE: enemy wipeout does NOT shortcut to victory — the player must hold
## position through the full round count. Only DEFEAT can short-circuit.
func test_survive_mode_enemy_wipeout_does_not_emit_victory() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var hp: DeadAwareHPStub = DeadAwareHPStub.new()
	var bag: Dictionary = _setup([u1, enemy], hp)
	var controller: GridBattleController = bag["controller"]
	controller.set_victory_conditions(_make_survive_vc(3))
	hp.mark_dead(2)  # enemy dies
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._on_unit_died(2)

	assert_int(captures.size()).override_failure_message(
		"SURVIVE: enemy wipeout must NOT emit any outcome (player must wait the round count)"
	).is_equal(0)
	assert_bool(controller._battle_over).is_false()


## SURVIVE: player wipeout still emits DEFEAT_ANNIHILATION — losing condition
## is identical to ANNIHILATION.
func test_survive_mode_player_wipeout_emits_defeat() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var hp: DeadAwareHPStub = DeadAwareHPStub.new()
	var bag: Dictionary = _setup([u1, enemy], hp)
	var controller: GridBattleController = bag["controller"]
	controller.set_victory_conditions(_make_survive_vc(3))
	hp.mark_dead(1)  # player dies
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._on_unit_died(1)

	assert_int(captures.size()).is_equal(1)
	assert_str(String(captures[0] as StringName)).is_equal("DEFEAT_ANNIHILATION")
	assert_bool(controller._battle_over).is_true()


# ─── Round-hook: SURVIVE victory threshold ──────────────────────────────────


## SURVIVE survive_rounds=3, round_num=3 → still in the wait window; no outcome.
func test_survive_mode_round_num_at_threshold_emits_no_outcome() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, enemy])
	var controller: GridBattleController = bag["controller"]
	controller.set_victory_conditions(_make_survive_vc(3))
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._on_round_started(3)  # AT threshold — still need to PLAY round 3

	assert_int(captures.size()).override_failure_message(
		"SURVIVE survive_rounds=3, round 3 starting must NOT emit (player must play round 3)"
	).is_equal(0)
	assert_bool(controller._battle_over).is_false()


## SURVIVE survive_rounds=3, round_num=4 → player has survived rounds 1-3 → WIN.
func test_survive_mode_round_num_over_threshold_emits_victory_survive() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, enemy])
	var controller: GridBattleController = bag["controller"]
	controller.set_victory_conditions(_make_survive_vc(3))
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._on_round_started(4)  # OVER threshold — player survived 1,2,3

	assert_int(captures.size()).is_equal(1)
	assert_str(String(captures[0] as StringName)).override_failure_message(
		"SURVIVE survive_rounds=3, round 4 must emit VICTORY_SURVIVE"
	).is_equal("VICTORY_SURVIVE")
	assert_bool(controller._battle_over).is_true()


## SURVIVE survive_rounds=3, _battle_over already true → no re-emit.
func test_survive_mode_battle_over_short_circuits_round_hook() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, enemy])
	var controller: GridBattleController = bag["controller"]
	controller.set_victory_conditions(_make_survive_vc(3))
	controller._battle_over = true
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._on_round_started(4)

	assert_int(captures.size()).override_failure_message(
		"SURVIVE: _battle_over short-circuit must prevent re-emit of VICTORY_SURVIVE"
	).is_equal(0)


# ─── Default (null vc) ──────────────────────────────────────────────────────


## Null vc → ANNIHILATION default preserved; no false-positive SURVIVE emit
## on round_started, no shortcut elision in _check_battle_end.
func test_null_vc_falls_through_to_annihilation_behavior() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var hp: DeadAwareHPStub = DeadAwareHPStub.new()
	var bag: Dictionary = _setup([u1, enemy], hp)
	var controller: GridBattleController = bag["controller"]
	# DO NOT set_victory_conditions — _victory_conditions stays null.
	hp.mark_dead(2)  # enemy dies
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._on_unit_died(2)

	assert_int(captures.size()).is_equal(1)
	assert_str(String(captures[0] as StringName)).override_failure_message(
		"Null vc: enemy wipeout must STILL emit VICTORY_ANNIHILATION (pre-S28 baseline)"
	).is_equal("VICTORY_ANNIHILATION")


## Null vc + round_started high → no false-positive VICTORY_SURVIVE emit.
func test_null_vc_round_started_does_not_emit_survive() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, enemy])
	var controller: GridBattleController = bag["controller"]
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._on_round_started(50)  # arbitrary high round

	# Only outcome would be TURN_LIMIT_REACHED if _max_turns < 50, but our fixture
	# sets _max_turns=999. Verify no SURVIVE leak.
	for capture: StringName in captures:
		assert_str(String(capture)).override_failure_message(
			"Null vc: must NOT emit VICTORY_SURVIVE; got %s" % String(capture)
		).is_not_equal("VICTORY_SURVIVE")


# ─── outcome_was_win heuristic ──────────────────────────────────────────────


## VICTORY_SURVIVE must register as a WIN in get_player_battle_stats.
func test_outcome_was_win_recognises_victory_survive() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, enemy])
	var controller: GridBattleController = bag["controller"]
	controller.set_victory_conditions(_make_survive_vc(3))
	controller._on_round_started(4)  # triggers VICTORY_SURVIVE

	var stats: Dictionary = controller.get_battle_stats()
	assert_bool(stats.get("outcome_was_win", false) as bool).override_failure_message(
		"outcome_was_win must recognise VICTORY_SURVIVE as a WIN"
	).is_true()
