## FSM tests for GridBattleController — 2-state FSM + 10-grid-action filter +
## click hit-test routing per ADR-0014 §2 + §4 + story-003.
##
## Story-003 AC-1..AC-9: BattleState enum + _is_grid_action + _on_input_action_fired
## filter + handle_grid_click dispatch + Camera fallback + acted-this-turn guard.
##
## Test stub strategy: stubs override is_tile_in_move_range / is_tile_in_attack_range
## via TestableGridBattleController subclass to verify dispatch wiring without
## requiring story-004/005 to be implemented first.

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


# ─── Helpers ────────────────────────────────────────────────────────────────

func _make_player_unit(unit_id: int) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.side = 0  # player
	return unit


func _make_enemy_unit(unit_id: int) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.side = 1  # enemy
	return unit


func _setup_controller(roster: Array[BattleUnit]) -> GridBattleController:
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


# ─── AC-4: _is_grid_action filter — 10 grid actions + non-grid sanity ──────

func test_is_grid_action_returns_true_for_all_10_grid_actions() -> void:
	# Per ADR-0014 §4 + input-handling GDD §93 — 10 grid-domain actions.
	var roster: Array[BattleUnit] = [_make_player_unit(1)]
	var controller: GridBattleController = _setup_controller(roster)
	var grid_actions: Array[String] = [
		"unit_select", "move_target_select", "move_confirm", "move_cancel",
		"attack_target_select", "attack_confirm", "attack_cancel",
		"undo_last_move", "end_unit_turn", "grid_hover",
	]
	for action: String in grid_actions:
		assert_bool(controller._is_grid_action(action)).override_failure_message(
			"_is_grid_action('%s') should return true (grid-domain action per ADR-0014 §4)" % action
		).is_true()


func test_is_grid_action_returns_false_for_non_grid_actions() -> void:
	# Camera + menu actions are NOT grid actions; controller should silently ignore.
	var roster: Array[BattleUnit] = [_make_player_unit(1)]
	var controller: GridBattleController = _setup_controller(roster)
	var non_grid_actions: Array[String] = [
		"camera_pan", "camera_zoom_in", "camera_zoom_out",
		"menu_open", "menu_close", "pause", "unrecognized_action", "",
	]
	for action: String in non_grid_actions:
		assert_bool(controller._is_grid_action(action)).override_failure_message(
			"_is_grid_action('%s') should return false (non-grid action)" % action
		).is_false()


# ─── AC-3: _on_input_action_fired filter — non-grid silent ─────────────────

func test_on_input_action_fired_silently_ignores_non_grid_actions() -> void:
	# Non-grid actions must not change FSM state nor emit signals.
	var roster: Array[BattleUnit] = [_make_player_unit(1)]
	var controller: GridBattleController = _setup_controller(roster)
	var captures: Array = []
	controller.unit_selected_changed.connect(func(unit_id: int, was_selected: int) -> void:
		captures.append({"unit_id": unit_id, "was_selected": was_selected})
	)
	var ctx: InputContext = InputContext.new()
	ctx.target_coord = Vector2i(2, 3)
	ctx.target_unit_id = 1

	controller._on_input_action_fired("camera_pan", ctx)

	assert_int(controller._state).is_equal(GridBattleController.BattleState.OBSERVATION)
	assert_int(captures.size()).is_equal(0)


# ─── AC-5: OBSERVATION → UNIT_SELECTED on clicking own unit ────────────────

func test_unit_select_observation_to_unit_selected_emits_signal() -> void:
	# Per AC-5: clicking own unit in OBSERVATION → state UNIT_SELECTED + emit.
	var roster: Array[BattleUnit] = [_make_player_unit(1)]
	var controller: GridBattleController = _setup_controller(roster)
	var captures: Array = []
	controller.unit_selected_changed.connect(func(unit_id: int, was_selected: int) -> void:
		captures.append({"unit_id": unit_id, "was_selected": was_selected})
	)

	controller.handle_grid_click("unit_select", Vector2i(0, 0), 1)

	assert_int(controller._state).is_equal(GridBattleController.BattleState.UNIT_SELECTED)
	assert_int(controller._selected_unit_id).is_equal(1)
	assert_int(captures.size()).is_equal(1)
	assert_int(captures[0].unit_id as int).is_equal(1)
	assert_int(captures[0].was_selected as int).is_equal(-1)


# ─── AC-5: UNIT_SELECTED → OBSERVATION on clicking selected unit again ─────

func test_unit_select_unit_selected_same_unit_deselects() -> void:
	var roster: Array[BattleUnit] = [_make_player_unit(1)]
	var controller: GridBattleController = _setup_controller(roster)
	# Pre-select unit 1 to bypass selection mechanics
	controller.handle_grid_click("unit_select", Vector2i(0, 0), 1)
	var captures: Array = []
	controller.unit_selected_changed.connect(func(unit_id: int, was_selected: int) -> void:
		captures.append({"unit_id": unit_id, "was_selected": was_selected})
	)

	controller.handle_grid_click("unit_select", Vector2i(0, 0), 1)

	assert_int(controller._state).is_equal(GridBattleController.BattleState.OBSERVATION)
	assert_int(controller._selected_unit_id).is_equal(-1)
	assert_int(captures.size()).is_equal(1)
	assert_int(captures[0].unit_id as int).is_equal(-1)
	assert_int(captures[0].was_selected as int).is_equal(1)


# ─── AC-5: enemy unit cannot be selected from OBSERVATION ──────────────────

func test_unit_select_observation_enemy_unit_silent() -> void:
	# Per AC-5 first arm: only side=0 (player) units can be selected.
	var roster: Array[BattleUnit] = [_make_enemy_unit(99)]
	var controller: GridBattleController = _setup_controller(roster)
	var captures: Array = []
	controller.unit_selected_changed.connect(func(unit_id: int, was_selected: int) -> void:
		captures.append({"unit_id": unit_id, "was_selected": was_selected})
	)

	controller.handle_grid_click("unit_select", Vector2i(0, 0), 99)

	assert_int(controller._state).is_equal(GridBattleController.BattleState.OBSERVATION)
	assert_int(controller._selected_unit_id).is_equal(-1)
	assert_int(captures.size()).is_equal(0)


# ─── AC-5: move_cancel + attack_cancel deselect ─────────────────────────────

func test_move_cancel_in_unit_selected_deselects() -> void:
	var roster: Array[BattleUnit] = [_make_player_unit(1)]
	var controller: GridBattleController = _setup_controller(roster)
	controller.handle_grid_click("unit_select", Vector2i(0, 0), 1)
	assert_int(controller._state).is_equal(GridBattleController.BattleState.UNIT_SELECTED)

	controller.handle_grid_click("move_cancel", Vector2i(2, 3), -1)

	assert_int(controller._state).is_equal(GridBattleController.BattleState.OBSERVATION)
	assert_int(controller._selected_unit_id).is_equal(-1)


func test_attack_cancel_in_unit_selected_deselects() -> void:
	var roster: Array[BattleUnit] = [_make_player_unit(1)]
	var controller: GridBattleController = _setup_controller(roster)
	controller.handle_grid_click("unit_select", Vector2i(0, 0), 1)

	controller.handle_grid_click("attack_cancel", Vector2i(2, 3), -1)

	assert_int(controller._state).is_equal(GridBattleController.BattleState.OBSERVATION)


# ─── AC-7: acted-this-turn click guard — silent no-op ──────────────────────

func test_acted_this_turn_unit_click_silent_no_op() -> void:
	# Per AC-7: clicking a unit in _acted_this_turn → no state change, no signal.
	var roster: Array[BattleUnit] = [_make_player_unit(1)]
	var controller: GridBattleController = _setup_controller(roster)
	# Mark unit 1 as acted-this-turn (story-006 will populate this via _consume_unit_action;
	# here we set it directly via test seam)
	controller._acted_this_turn[1] = true
	var captures: Array = []
	controller.unit_selected_changed.connect(func(unit_id: int, was_selected: int) -> void:
		captures.append({"unit_id": unit_id, "was_selected": was_selected})
	)

	controller.handle_grid_click("unit_select", Vector2i(0, 0), 1)

	assert_int(controller._state).is_equal(GridBattleController.BattleState.OBSERVATION)
	assert_int(captures.size()).is_equal(0)


# ─── AC-6: off-grid sentinel early-returns ──────────────────────────────────

func test_off_grid_coord_sentinel_early_returns() -> void:
	# Per AC-6: ctx.target_coord == Vector2i(-1, -1) (post Camera-fallback or
	# direct sentinel) → silent return; no FSM transition.
	var roster: Array[BattleUnit] = [_make_player_unit(1)]
	var controller: GridBattleController = _setup_controller(roster)
	var captures: Array = []
	controller.unit_selected_changed.connect(func(unit_id: int, was_selected: int) -> void:
		captures.append({"unit_id": unit_id, "was_selected": was_selected})
	)
	var ctx: InputContext = InputContext.new()
	ctx.target_coord = Vector2i(-1, -1)
	ctx.target_unit_id = 1

	controller._on_input_action_fired("unit_select", ctx)

	assert_int(controller._state).is_equal(GridBattleController.BattleState.OBSERVATION)
	assert_int(captures.size()).is_equal(0)


# ─── AC-5: clicking different own unit while selected — silent (MVP) ───────

func test_unit_select_unit_selected_different_unit_silent_in_mvp() -> void:
	# MVP: clicking a DIFFERENT own unit while UNIT_SELECTED is silent (must
	# deselect first). Future story may add re-select-without-deselect; today silent.
	var roster: Array[BattleUnit] = [_make_player_unit(1), _make_player_unit(2)]
	var controller: GridBattleController = _setup_controller(roster)
	controller.handle_grid_click("unit_select", Vector2i(0, 0), 1)
	# Connect capture AFTER initial selection — only capture the SECOND click's emission (or lack thereof)
	var captures: Array = []
	controller.unit_selected_changed.connect(func(unit_id: int, was_selected: int) -> void:
		captures.append({"unit_id": unit_id, "was_selected": was_selected})
	)

	controller.handle_grid_click("unit_select", Vector2i(1, 0), 2)

	# State unchanged (still UNIT_SELECTED on unit 1)
	assert_int(controller._state).is_equal(GridBattleController.BattleState.UNIT_SELECTED)
	assert_int(controller._selected_unit_id).is_equal(1)
	assert_int(captures.size()).is_equal(0)


# ─── AC-3 + AC-6: full pipeline via _on_input_action_fired with own-unit click ─

func test_on_input_action_fired_full_pipeline_selects_own_unit() -> void:
	# End-to-end: _on_input_action_fired("unit_select", ctx) with own-unit ctx
	# → handle_grid_click → _select_unit → state UNIT_SELECTED + signal.
	var roster: Array[BattleUnit] = [_make_player_unit(1)]
	var controller: GridBattleController = _setup_controller(roster)
	var captures: Array = []
	controller.unit_selected_changed.connect(func(unit_id: int, was_selected: int) -> void:
		captures.append({"unit_id": unit_id, "was_selected": was_selected})
	)
	var ctx: InputContext = InputContext.new()
	ctx.target_coord = Vector2i(2, 3)  # non-zero, not -1/-1
	ctx.target_unit_id = 1

	controller._on_input_action_fired("unit_select", ctx)

	assert_int(controller._state).is_equal(GridBattleController.BattleState.UNIT_SELECTED)
	assert_int(captures.size()).is_equal(1)
