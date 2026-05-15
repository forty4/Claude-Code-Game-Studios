## grid_battle_controller_is_action_available_test.gd
##
## Session-24 — `is_action_available(unit_id, action_name) -> bool` proper
## implementation. Closes the has_method-fallback gap left in S20: the HUD
## queried this method for all 6 UI-GB-02 buttons but the controller never
## implemented it, so the fallback path was always-permissive and the buttons
## stayed enabled even after their tokens were spent.
##
## Coverage:
##   - Fresh turn — all 6 actions available
##   - Post-MOVE — move disabled, others still available
##   - Post-ATTACK — attack/use_skill/defend disabled, move/wait/end_turn ok
##   - Post-DEFEND — action token spent + defend lock blocks subsequent MOVE
##   - turn_state==DONE (post-WAIT) — everything disabled
##   - AI unit (is_player_controlled=false) — everything disabled
##   - Battle over — everything disabled
##   - Non-active turn unit — everything disabled
##   - Dead unit — everything disabled
##   - Unknown action name — false
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


func _make_unit(unit_id: int, is_player: bool) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.hero_id = StringName("test_hero_%d" % unit_id)
	unit.unit_class = 1
	unit.position = Vector2i(2, 2)
	unit.side = 0 if is_player else 1
	unit.is_player_controlled = is_player
	unit.attack_range = 1
	unit.move_range = 3
	unit.raw_atk = 60
	unit.raw_def = 18
	return unit


func _setup(roster: Array[BattleUnit]) -> GridBattleController:
	var map_grid: MapGridStub = MapGridStubScript.new()
	map_grid.set_dimensions_for_test(Vector2i(10, 10))
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
	return controller


func _make_state(move_spent: bool, action_spent: bool, defend_lock: bool, turn_state: int) -> UnitTurnState:
	var state: UnitTurnState = UnitTurnState.new()
	state.unit_id = 1
	state.move_token_spent = move_spent
	state.action_token_spent = action_spent
	state.defend_stance_active = defend_lock
	state.turn_state = turn_state
	return state


func _seed_active(controller: GridBattleController, unit_id: int, state: UnitTurnState) -> void:
	# Authoritative active-turn unit + fixture state on the turn runner stub.
	controller._active_turn_unit_id = unit_id
	(controller._turn_runner as TurnOrderRunnerStub).set_unit_turn_state_for_test(unit_id, state)


# ─── Fresh-turn baseline ─────────────────────────────────────────────────────


func test_fresh_turn_all_six_actions_available() -> void:
	var player: BattleUnit = _make_unit(1, true)
	var controller: GridBattleController = _setup([player])
	var fresh: UnitTurnState = _make_state(false, false, false, TurnOrderRunner.TurnState.ACTING)
	_seed_active(controller, 1, fresh)
	assert_bool(controller.is_action_available(1, &"move")).override_failure_message("fresh turn: move").is_true()
	assert_bool(controller.is_action_available(1, &"attack")).override_failure_message("fresh turn: attack").is_true()
	assert_bool(controller.is_action_available(1, &"use_skill")).override_failure_message("fresh turn: use_skill").is_true()
	assert_bool(controller.is_action_available(1, &"defend")).override_failure_message("fresh turn: defend").is_true()
	assert_bool(controller.is_action_available(1, &"wait")).override_failure_message("fresh turn: wait").is_true()
	assert_bool(controller.is_action_available(1, &"end_turn")).override_failure_message("fresh turn: end_turn").is_true()


# ─── Token state combinations ────────────────────────────────────────────────


func test_post_move_disables_move_only() -> void:
	var player: BattleUnit = _make_unit(1, true)
	var controller: GridBattleController = _setup([player])
	var post_move: UnitTurnState = _make_state(true, false, false, TurnOrderRunner.TurnState.ACTING)
	_seed_active(controller, 1, post_move)
	assert_bool(controller.is_action_available(1, &"move")).is_false()
	assert_bool(controller.is_action_available(1, &"attack")).is_true()
	assert_bool(controller.is_action_available(1, &"use_skill")).is_true()
	assert_bool(controller.is_action_available(1, &"defend")).is_true()
	assert_bool(controller.is_action_available(1, &"wait")).is_true()
	assert_bool(controller.is_action_available(1, &"end_turn")).is_true()


func test_post_attack_disables_attack_use_skill_defend() -> void:
	var player: BattleUnit = _make_unit(1, true)
	var controller: GridBattleController = _setup([player])
	var post_attack: UnitTurnState = _make_state(false, true, false, TurnOrderRunner.TurnState.ACTING)
	_seed_active(controller, 1, post_attack)
	assert_bool(controller.is_action_available(1, &"move")).is_true()
	assert_bool(controller.is_action_available(1, &"attack")).is_false()
	assert_bool(controller.is_action_available(1, &"use_skill")).is_false()
	assert_bool(controller.is_action_available(1, &"defend")).is_false()
	assert_bool(controller.is_action_available(1, &"wait")).is_true()
	assert_bool(controller.is_action_available(1, &"end_turn")).is_true()


func test_post_defend_disables_action_token_actions_and_move_via_lock() -> void:
	# DEFEND spends ACTION token AND sets defend_stance_active (CR-4c MOVE lock).
	var player: BattleUnit = _make_unit(1, true)
	var controller: GridBattleController = _setup([player])
	var post_defend: UnitTurnState = _make_state(false, true, true, TurnOrderRunner.TurnState.ACTING)
	_seed_active(controller, 1, post_defend)
	assert_bool(controller.is_action_available(1, &"move")).override_failure_message(
		"DEFEND must lock subsequent MOVE (CR-4c)"
	).is_false()
	assert_bool(controller.is_action_available(1, &"attack")).is_false()
	assert_bool(controller.is_action_available(1, &"defend")).is_false()
	assert_bool(controller.is_action_available(1, &"wait")).is_true()
	assert_bool(controller.is_action_available(1, &"end_turn")).is_true()


func test_turn_done_disables_everything() -> void:
	# Post-WAIT: turn_state == DONE → all actions unavailable.
	var player: BattleUnit = _make_unit(1, true)
	var controller: GridBattleController = _setup([player])
	var done: UnitTurnState = _make_state(false, false, false, TurnOrderRunner.TurnState.DONE)
	_seed_active(controller, 1, done)
	for action: StringName in [&"move", &"attack", &"use_skill", &"defend", &"wait", &"end_turn"]:
		assert_bool(controller.is_action_available(1, action)).override_failure_message(
			"turn_state=DONE: %s should be unavailable" % action
		).is_false()


# ─── Unit-level gates ────────────────────────────────────────────────────────


func test_ai_unit_all_actions_disabled() -> void:
	# is_player_controlled=false → player can't action through HUD buttons.
	var ai: BattleUnit = _make_unit(2, false)
	var controller: GridBattleController = _setup([ai])
	var fresh: UnitTurnState = _make_state(false, false, false, TurnOrderRunner.TurnState.ACTING)
	_seed_active(controller, 2, fresh)
	for action: StringName in [&"move", &"attack", &"use_skill", &"defend", &"wait", &"end_turn"]:
		assert_bool(controller.is_action_available(2, action)).override_failure_message(
			"AI unit: %s must be unavailable" % action
		).is_false()


func test_non_active_turn_unit_all_actions_disabled() -> void:
	# Player1 is active; player2 is in the registry but it's not their turn.
	var player1: BattleUnit = _make_unit(1, true)
	var player2: BattleUnit = _make_unit(2, true)
	var controller: GridBattleController = _setup([player1, player2])
	var fresh: UnitTurnState = _make_state(false, false, false, TurnOrderRunner.TurnState.ACTING)
	# Active turn = player1; querying player2 must reject all actions.
	_seed_active(controller, 1, fresh)
	(controller._turn_runner as TurnOrderRunnerStub).set_unit_turn_state_for_test(2, fresh)
	for action: StringName in [&"move", &"attack", &"defend", &"wait", &"end_turn"]:
		assert_bool(controller.is_action_available(2, action)).override_failure_message(
			"non-active turn unit: %s must be unavailable" % action
		).is_false()


func test_dead_unit_all_actions_disabled() -> void:
	var player: BattleUnit = _make_unit(1, true)
	var controller: GridBattleController = _setup([player])
	var fresh: UnitTurnState = _make_state(false, false, false, TurnOrderRunner.TurnState.ACTING)
	_seed_active(controller, 1, fresh)
	(controller._hp_controller as HPStatusControllerStub).set_alive_for_test(1, false)
	for action: StringName in [&"move", &"attack", &"defend", &"wait", &"end_turn"]:
		assert_bool(controller.is_action_available(1, action)).override_failure_message(
			"dead unit: %s must be unavailable" % action
		).is_false()


func test_unknown_unit_id_returns_false() -> void:
	var player: BattleUnit = _make_unit(1, true)
	var controller: GridBattleController = _setup([player])
	assert_bool(controller.is_action_available(999, &"move")).is_false()


func test_battle_over_disables_everything() -> void:
	var player: BattleUnit = _make_unit(1, true)
	var controller: GridBattleController = _setup([player])
	var fresh: UnitTurnState = _make_state(false, false, false, TurnOrderRunner.TurnState.ACTING)
	_seed_active(controller, 1, fresh)
	controller._battle_over = true
	for action: StringName in [&"move", &"attack", &"defend", &"wait", &"end_turn"]:
		assert_bool(controller.is_action_available(1, action)).override_failure_message(
			"battle_over: %s must be unavailable" % action
		).is_false()


# ─── Edge cases ──────────────────────────────────────────────────────────────


func test_unknown_action_name_returns_false() -> void:
	var player: BattleUnit = _make_unit(1, true)
	var controller: GridBattleController = _setup([player])
	var fresh: UnitTurnState = _make_state(false, false, false, TurnOrderRunner.TurnState.ACTING)
	_seed_active(controller, 1, fresh)
	assert_bool(controller.is_action_available(1, &"nonsense_action")).is_false()
	assert_bool(controller.is_action_available(1, &"")).is_false()


func test_null_turn_state_returns_false() -> void:
	# Defensive: stub returns null for unit_id without a fixture state.
	var player: BattleUnit = _make_unit(1, true)
	var controller: GridBattleController = _setup([player])
	controller._active_turn_unit_id = 1
	# No set_unit_turn_state_for_test call — stub returns null per its override.
	for action: StringName in [&"move", &"attack", &"defend", &"wait", &"end_turn"]:
		assert_bool(controller.is_action_available(1, action)).override_failure_message(
			"null turn state: %s must be unavailable" % action
		).is_false()
