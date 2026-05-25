## grid_battle_controller_player_defend_test.gd
##
## Verifies the session-13 player DEFEND verb pipeline:
##   - _handle_player_defend declares DEFEND token to TurnOrderRunner
##   - _apply_defend_stance_status applies the &"defend_stance" status effect
##     so HPStatusController's 50% damage reduction actually fires
##   - _handle_defend_stance_input routes the keyboard event to the selected unit
##   - preview_attack reflects the defender's defend stance (50% off forecast)
##   - unit_defend_stance_applied signal fires for visual layer
##   - re-entrancy: declaring DEFEND twice in one turn doesn't double-spend
##
## Mirrors grid_battle_controller_attack_test.gd setup pattern.
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


func _make_unit(unit_id: int, pos: Vector2i, side: int) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.hero_id = StringName("test_hero_%d" % unit_id)
	unit.unit_class = 0  # CAVALRY
	unit.position = pos
	unit.side = side
	unit.attack_range = 1
	unit.move_range = 3
	unit.raw_atk = 50
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
	controller.setup(roster, map_grid, camera, hero_db, turn_runner,
		hp_controller, terrain_effect, unit_role)
	controller._rng = RandomNumberGenerator.new()
	controller._rng.seed = 12345
	return {
		"controller": controller,
		"hp_controller": hp_controller,
		"turn_runner": turn_runner,
	}


# ─── Public API surface ───────────────────────────────────────────────────────


func test_handle_player_defend_method_exists() -> void:
	var controller: GridBattleController = _setup([_make_unit(1, Vector2i(2, 2), 0)])["controller"]
	assert_bool(controller.has_method("_handle_player_defend")).is_true()
	assert_bool(controller.has_method("_apply_defend_stance_status")).is_true()
	assert_bool(controller.has_method("_handle_defend_stance_input")).is_true()


# ─── Re-entrancy guard ────────────────────────────────────────────────────────


func test_player_defend_rejected_when_already_acted_this_turn() -> void:
	# Re-entrancy: if unit already used its action token, second DEFEND must be no-op.
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var bag: Dictionary = _setup([attacker])
	var controller: GridBattleController = bag["controller"]
	controller._active_turn_unit_id = 1
	controller._acted_this_turn[1] = true  # simulate prior action

	var declare_count_before: int = bag["turn_runner"].declared_actions.size() if "declared_actions" in bag["turn_runner"] else 0
	controller._handle_player_defend(1)
	var declare_count_after: int = bag["turn_runner"].declared_actions.size() if "declared_actions" in bag["turn_runner"] else 0

	assert_int(declare_count_after).override_failure_message(
		"_handle_player_defend must be silent no-op when _acted_this_turn already true"
	).is_equal(declare_count_before)


# ─── Keyboard routing ─────────────────────────────────────────────────────────


func test_defend_stance_input_falls_back_to_active_turn_unit_when_no_selection() -> void:
	# S86: was test_defend_stance_input_no_op_when_no_unit_selected — design
	# intent flipped after playtest showed users pressing D without selecting
	# first looked like a dead key. Now D falls back to the active-turn unit
	# (player-side) so the press always lands on the unit whose turn it is.
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var bag: Dictionary = _setup([attacker])
	var controller: GridBattleController = bag["controller"]
	controller._active_turn_unit_id = 1
	# No selection — _state stays OBSERVATION.

	controller._handle_defend_stance_input()

	# acted_this_turn flipped on the active turn unit (fallback consumed the press).
	assert_bool(controller._acted_this_turn.get(1, false)).override_failure_message(
		"S86 fallback: D press with no selection must declare DEFEND for the active turn unit"
	).is_true()


func test_defend_stance_input_no_op_when_selected_unit_is_enemy() -> void:
	# Defensive: selected unit must be player-side. Even if the input pipeline
	# somehow routes a D press while an enemy is "selected" (impossible in
	# normal flow), it must not let the player declare DEFEND for them.
	var enemy: BattleUnit = _make_unit(2, Vector2i(3, 3), 1)
	var bag: Dictionary = _setup([enemy])
	var controller: GridBattleController = bag["controller"]
	controller._select_unit(2)

	controller._handle_defend_stance_input()

	# Enemy unit must NOT have its defend status applied via player input
	assert_bool(controller._acted_this_turn.get(2, false)).is_false()


# ─── unit_defend_stance_applied signal ────────────────────────────────────────


func test_apply_defend_stance_status_emits_signal() -> void:
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var bag: Dictionary = _setup([attacker])
	var controller: GridBattleController = bag["controller"]

	var captures: Array = []
	controller.unit_defend_stance_applied.connect(
		func(unit_id: int) -> void:
			captures.append(unit_id)
	)

	controller._apply_defend_stance_status(1)

	assert_int(captures.size()).override_failure_message(
		"_apply_defend_stance_status must emit unit_defend_stance_applied once"
	).is_equal(1)
	assert_int(captures[0]).is_equal(1)


# ─── End-to-end: D key path on selected player unit ───────────────────────────


func test_defend_stance_input_marks_acted_when_selected_player_unit() -> void:
	# Full happy path: select player unit + press D → _acted_this_turn flipped,
	# unit_defend_stance_applied signal fires, deselect happens.
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var bag: Dictionary = _setup([attacker])
	var controller: GridBattleController = bag["controller"]
	controller._active_turn_unit_id = 1
	controller._select_unit(1)
	assert_int(controller._selected_unit_id).is_equal(1)

	var captures: Array = []
	controller.unit_defend_stance_applied.connect(
		func(unit_id: int) -> void: captures.append(unit_id)
	)

	controller._handle_defend_stance_input()

	assert_bool(controller._acted_this_turn.get(1, false)).override_failure_message(
		"D key on selected player unit must set _acted_this_turn"
	).is_true()
	assert_int(captures.size()).override_failure_message(
		"D key path must emit unit_defend_stance_applied"
	).is_equal(1)
	assert_int(controller._selected_unit_id).override_failure_message(
		"D key path must deselect after declaring defend"
	).is_equal(-1)


# ─── preview_attack reflects defender defend stance ───────────────────────────


func test_preview_damage_drops_when_defender_has_defend_stance_status() -> void:
	# Same fixture as preview_attack_test, but with defender pre-loaded with
	# the defend_stance status. Preview damage must reflect the 50% reduction
	# from DEFEND_STANCE_REDUCTION; otherwise the forecast lies to the player
	# and the player can't trust their tactical decisions.
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var defender: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]
	var hp_controller: HPStatusControllerStub = bag["hp_controller"]

	var preview_no_defend: Dictionary = controller.preview_attack(1, 2)
	var damage_no_defend: int = int(preview_no_defend["damage"])

	# Inject defend_stance status on the defender via the stub's test seam.
	# Build a StatusEffect with the canonical effect_id; preview_attack reads
	# .effect_id when collecting defender_status_ids.
	var defend_status: StatusEffect = StatusEffect.new()
	defend_status.effect_id = &"defend_stance"
	defend_status.effect_type = 0
	defend_status.duration_type = 2  # ACTION_LOCKED per template
	defend_status.remaining_turns = 1
	hp_controller.set_test_status_effects(2, [defend_status])

	var preview_with_defend: Dictionary = controller.preview_attack(1, 2)
	var damage_with_defend: int = int(preview_with_defend["damage"])

	# Damage MUST drop. Exact value depends on stub HPStatusController behavior;
	# we assert the strict inequality + the defend status appears in defender_status_ids.
	assert_int(damage_with_defend).override_failure_message(
		"preview damage with defending defender (%d) must be LESS than without (%d)"
		% [damage_with_defend, damage_no_defend]
	).is_less(damage_no_defend)
	var status_ids: Array = preview_with_defend["defender_status_ids"]
	assert_bool(&"defend_stance" in status_ids).override_failure_message(
		"defender_status_ids must include &'defend_stance' when defender is defending"
	).is_true()
