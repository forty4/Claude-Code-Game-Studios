## Turn consumption tests for GridBattleController per ADR-0014 §6 + story-006.
##
## Story-006 AC-1..AC-9: _consume_unit_action (acted flag + token spend +
## deselect + auto-handoff) + _any_player_unit_can_act (alive-and-unacted
## scan with dead-unit exclusion) + end_player_turn (clear acted + deselect).
##
## Test focus: single-token MVP integration with shipped TurnOrderRunner.declare_action
## (drift #9 — sketch said spend_action_token). Stub captures (unit_id, action)
## tuples for spend assertions.

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

func _make_unit(unit_id: int, pos: Vector2i, side: int = 0) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.position = pos
	unit.side = side
	unit.facing = 0
	unit.move_range = 3
	unit.attack_range = 1
	return unit


## Subclass HPStatusController stub to allow per-unit is_alive override.
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
	return {"controller": controller, "turn_runner": turn_runner, "hp": hp}


# ─── AC-2: _consume_unit_action marks acted + spends action token ────────────

func test_consume_unit_action_marks_acted_and_spends_token() -> void:
	# Arrange: two player units (gates auto-handoff so we can isolate single-call effect)
	var u1: BattleUnit = _make_unit(1, Vector2i(1, 1), 0)
	var u2: BattleUnit = _make_unit(2, Vector2i(7, 7), 0)
	var bag: Dictionary = _setup([u1, u2])
	var controller: GridBattleController = bag["controller"]
	var turn_runner: TurnOrderRunnerStub = bag["turn_runner"]

	# Act
	controller._consume_unit_action(1)

	# Assert: AC-1 acted flag + AC-2 token spend
	assert_bool(controller._acted_this_turn.get(1, false)).is_true()
	assert_int(turn_runner.declared_actions.size()).is_equal(1)
	assert_int(turn_runner.declared_actions[0]["unit_id"] as int).is_equal(1)
	assert_int(turn_runner.declared_actions[0]["action"] as int).is_equal(TurnOrderRunner.ActionType.ATTACK)


# ─── AC-3: _any_player_unit_can_act baseline — fresh roster ────────────────

func test_any_player_unit_can_act_returns_true_when_unit_unacted() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(1, 1), 0)
	var u2: BattleUnit = _make_unit(2, Vector2i(2, 2), 0)
	var bag: Dictionary = _setup([u1, u2])
	var controller: GridBattleController = bag["controller"]

	# No unit has acted → at least one player unit can still act.
	assert_bool(controller._any_player_unit_can_act()).is_true()


# ─── AC-3: _any_player_unit_can_act excludes enemy units ───────────────────

func test_any_player_unit_can_act_excludes_enemy_side() -> void:
	# Player unit acted; enemy unit unacted → no PLAYER unit can act → false.
	var player: BattleUnit = _make_unit(1, Vector2i(1, 1), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([player, enemy])
	var controller: GridBattleController = bag["controller"]
	controller._acted_this_turn[1] = true  # only player is acted

	# Enemy unit at side=1 is NOT counted toward player handoff gate.
	assert_bool(controller._any_player_unit_can_act()).is_false()


# ─── AC-9: _any_player_unit_can_act excludes dead units ────────────────────

func test_any_player_unit_can_act_excludes_dead_units() -> void:
	# Two player units; unit 1 acted, unit 2 dead → no eligible player unit.
	var u1: BattleUnit = _make_unit(1, Vector2i(1, 1), 0)
	var u2: BattleUnit = _make_unit(2, Vector2i(2, 2), 0)
	var hp: DeadAwareHPStub = DeadAwareHPStub.new()
	var bag: Dictionary = _setup([u1, u2], hp)
	var controller: GridBattleController = bag["controller"]
	controller._acted_this_turn[1] = true
	hp.mark_dead(2)

	assert_bool(controller._any_player_unit_can_act()).is_false()


# ─── AC-4 + AC-8: 4-unit roster — 4 sequential consumes auto-handoff ───────

func test_consume_action_auto_handoff_when_all_player_units_acted() -> void:
	# Per AC-8: 4 player units; sequential _consume_unit_action calls trigger
	# end_player_turn on the 4th call (auto-handoff per AC-4).
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var u2: BattleUnit = _make_unit(2, Vector2i(1, 0), 0)
	var u3: BattleUnit = _make_unit(3, Vector2i(2, 0), 0)
	var u4: BattleUnit = _make_unit(4, Vector2i(3, 0), 0)
	var bag: Dictionary = _setup([u1, u2, u3, u4])
	var controller: GridBattleController = bag["controller"]
	var turn_runner: TurnOrderRunnerStub = bag["turn_runner"]

	# First 3 consumes: each leaves 1+ unit able to act, no auto-handoff.
	controller._consume_unit_action(1)
	assert_int(controller._acted_this_turn.size()).is_equal(1)
	controller._consume_unit_action(2)
	assert_int(controller._acted_this_turn.size()).is_equal(2)
	controller._consume_unit_action(3)
	assert_int(controller._acted_this_turn.size()).is_equal(3)

	# 4th consume: _any_player_unit_can_act → false → end_player_turn fires →
	# _acted_this_turn cleared. The 4 declare_action calls are persistent
	# evidence on the runner stub.
	controller._consume_unit_action(4)
	assert_int(controller._acted_this_turn.size()).is_equal(0)  # cleared by end_player_turn
	assert_int(turn_runner.declared_actions.size()).is_equal(4)
	# All 4 spent tokens are ATTACK type (single-token MVP).
	for entry: Dictionary in turn_runner.declared_actions:
		assert_int(entry["action"] as int).is_equal(TurnOrderRunner.ActionType.ATTACK)


# ─── AC-9: dead-unit auto-handoff still fires when all-but-dead acted ──────

func test_consume_action_auto_handoff_with_dead_unit_excluded() -> void:
	# 3 player units; unit 3 is dead. Acting on units 1+2 → all alive-player
	# units acted → auto-handoff fires (dead unit 3 doesn't gate it).
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var u2: BattleUnit = _make_unit(2, Vector2i(1, 0), 0)
	var u3: BattleUnit = _make_unit(3, Vector2i(2, 0), 0)
	var hp: DeadAwareHPStub = DeadAwareHPStub.new()
	hp.mark_dead(3)
	var bag: Dictionary = _setup([u1, u2, u3], hp)
	var controller: GridBattleController = bag["controller"]

	controller._consume_unit_action(1)
	assert_int(controller._acted_this_turn.size()).is_equal(1)  # u2 still able to act

	controller._consume_unit_action(2)
	# u3 is dead and excluded → all alive players acted → auto-handoff →
	# _acted_this_turn cleared.
	assert_int(controller._acted_this_turn.size()).is_equal(0)


# ─── AC-7: acted-unit click guard — silent in OBSERVATION ──────────────────

func test_acted_unit_click_in_observation_is_silent_no_op() -> void:
	# Two player units gate auto-handoff. Mark unit 1 acted directly (skipping
	# _consume_unit_action so we test the dispatcher guard, not the consume path).
	var u1: BattleUnit = _make_unit(1, Vector2i(1, 1), 0)
	var u2: BattleUnit = _make_unit(2, Vector2i(7, 7), 0)
	var bag: Dictionary = _setup([u1, u2])
	var controller: GridBattleController = bag["controller"]
	controller._acted_this_turn[1] = true
	var captures: Array = []
	controller.unit_selected_changed.connect(func(unit_id: int, was: int) -> void:
		captures.append({"unit_id": unit_id, "was": was})
	)

	# Act: click unit 1 in OBSERVATION state. Per story-003 AC-7, acted-unit
	# click must be silent (no FSM transition, no signal emit).
	controller.handle_grid_click("unit_select", Vector2i(1, 1), 1)

	# Assert: state unchanged + zero signal emits.
	assert_int(controller.get_selected_unit_id()).is_equal(-1)
	assert_int(captures.size()).is_equal(0)


# ─── AC-5: end_player_turn clears acted + deselects + emits signal ─────────

func test_end_player_turn_clears_acted_and_deselects() -> void:
	# 2 units selected; pre-mark both as acted; call end_player_turn manually.
	var u1: BattleUnit = _make_unit(1, Vector2i(1, 1), 0)
	var u2: BattleUnit = _make_unit(2, Vector2i(7, 7), 0)
	var bag: Dictionary = _setup([u1, u2])
	var controller: GridBattleController = bag["controller"]
	# Select unit 1 first (puts state into UNIT_SELECTED).
	controller.handle_grid_click("unit_select", Vector2i(1, 1), 1)
	assert_int(controller.get_selected_unit_id()).is_equal(1)
	controller._acted_this_turn[1] = true
	controller._acted_this_turn[2] = true
	var captures: Array = []
	controller.unit_selected_changed.connect(func(unit_id: int, was: int) -> void:
		captures.append({"unit_id": unit_id, "was": was})
	)

	# Act
	controller.end_player_turn()

	# Assert: AC-5 cleared + deselected + signal fired with (-1, prev=1).
	assert_int(controller._acted_this_turn.size()).is_equal(0)
	assert_int(controller.get_selected_unit_id()).is_equal(-1)
	assert_int(captures.size()).is_equal(1)
	assert_int(captures[0].unit_id as int).is_equal(-1)
	assert_int(captures[0].was as int).is_equal(1)


# ─── AC-2: _consume_unit_action deselects after spend ──────────────────────

func test_consume_unit_action_deselects_after_spend() -> void:
	# Selected unit acts → state returns to OBSERVATION + emits unit_selected_changed.
	var u1: BattleUnit = _make_unit(1, Vector2i(1, 1), 0)
	var u2: BattleUnit = _make_unit(2, Vector2i(7, 7), 0)  # gates auto-handoff
	var bag: Dictionary = _setup([u1, u2])
	var controller: GridBattleController = bag["controller"]
	controller.handle_grid_click("unit_select", Vector2i(1, 1), 1)
	assert_int(controller.get_selected_unit_id()).is_equal(1)
	var captures: Array = []
	controller.unit_selected_changed.connect(func(unit_id: int, was: int) -> void:
		captures.append({"unit_id": unit_id, "was": was})
	)

	# Act
	controller._consume_unit_action(1)

	# Assert: deselected (state → OBSERVATION) + signal (-1, prev=1).
	assert_int(controller.get_selected_unit_id()).is_equal(-1)
	assert_int(captures.size()).is_equal(1)
	assert_int(captures[0].unit_id as int).is_equal(-1)
	assert_int(captures[0].was as int).is_equal(1)
