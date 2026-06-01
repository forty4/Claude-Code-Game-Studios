## Turn-limit + battle-outcome tests for GridBattleController per ADR-0014 §7 +
## story-007.
##
## Story-007 AC-1..AC-9: _max_turns load + _on_round_started turn-limit check +
## _emit_battle_outcome (battle_outcome_resolved + _battle_over terminal flag) +
## _check_battle_end (annihilation victory check on _on_unit_died) +
## terminal-state input guard.
##
## Test focus: outcome dispatch correctness (single-emit guarantee) + CR-7
## evaluation order (VICTORY before DEFEAT) + fate_data Dictionary snapshot
## shape + terminal-state guard idempotency.

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


## HP stub with per-unit dead-flag override (mirrors turn_consumption_test pattern).
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
	# _max_turns is loaded in _ready() from BalanceConstants. Tests bypass scene
	# tree mounting (no add_child), so _ready never fires. Set _max_turns
	# directly to mirror the production load (MAX_TURNS_PER_BATTLE = 5).
	controller._max_turns = 5
	return {"controller": controller, "hp": hp}


# ─── AC-3: _on_round_started turn-limit threshold ──────────────────────────

func test_on_round_started_within_limit_emits_no_outcome() -> void:
	# Round 3 of 5-turn battle → no outcome.
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, enemy])
	var controller: GridBattleController = bag["controller"]
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._on_round_started(3)

	assert_int(captures.size()).is_equal(0)
	assert_bool(controller._battle_over).is_false()


func test_on_round_started_at_limit_emits_no_outcome() -> void:
	# Round 5 == _max_turns → still no outcome (round 6 = first over-limit).
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, enemy])
	var controller: GridBattleController = bag["controller"]
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._on_round_started(5)

	assert_int(captures.size()).is_equal(0)


func test_on_round_started_over_limit_emits_turn_limit_reached() -> void:
	# Round 6 (>5) → emit TURN_LIMIT_REACHED + _battle_over set.
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, enemy])
	var controller: GridBattleController = bag["controller"]
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, data: Dictionary) -> void:
		captures.append({"outcome": outcome, "data": data})
	)

	controller._on_round_started(6)

	assert_int(captures.size()).is_equal(1)
	assert_str(String(captures[0].outcome as StringName)).is_equal("TURN_LIMIT_REACHED")
	assert_bool(controller._battle_over).is_true()


# ─── AC-4: fate_data snapshot shape ────────────────────────────────────────

func test_emit_battle_outcome_includes_fate_data_snapshot() -> void:
	# Pre-populate fate counters; verify they appear in fate_data.
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, enemy])
	var controller: GridBattleController = bag["controller"]
	controller._fate_rear_attacks = 2
	controller._fate_assassin_kills = 1
	controller._fate_boss_killed = true
	# G-4: lambda CANNOT reassign outer locals (even Dictionary references).
	# Use captures-array pattern: append the dict so we can read it post-emit.
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(_outcome: StringName, data: Dictionary) -> void:
		captures.append(data)
	)

	controller._emit_battle_outcome(&"TURN_LIMIT_REACHED")

	# AC-4: 7 keys in fate_data snapshot.
	assert_int(captures.size()).is_equal(1)
	var captured_data: Dictionary = captures[0] as Dictionary
	assert_int(captured_data["rear_attacks"] as int).is_equal(2)
	assert_int(captured_data["assassin_kills"] as int).is_equal(1)
	assert_bool(captured_data["boss_killed"] as bool).is_true()
	assert_bool(captured_data.has("formation_turns")).is_true()
	assert_bool(captured_data.has("tank_unit_id")).is_true()
	assert_bool(captured_data.has("assassin_unit_id")).is_true()
	assert_bool(captured_data.has("boss_unit_id")).is_true()


# ─── AC-5 + AC-6: _check_battle_end VICTORY annihilation ───────────────────

func test_check_battle_end_all_enemies_dead_emits_victory() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var hp: DeadAwareHPStub = DeadAwareHPStub.new()
	var bag: Dictionary = _setup([u1, enemy], hp)
	var controller: GridBattleController = bag["controller"]
	hp.mark_dead(2)  # enemy dies
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	# Drive _on_unit_died (story-008 wires fate counter; story-007 wires victory check).
	controller._on_unit_died(2)

	assert_int(captures.size()).is_equal(1)
	assert_str(String(captures[0] as StringName)).is_equal("VICTORY_ANNIHILATION")
	assert_bool(controller._battle_over).is_true()


# ─── AC-5 + AC-6: _check_battle_end DEFEAT annihilation ────────────────────

func test_check_battle_end_all_players_dead_emits_defeat() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var hp: DeadAwareHPStub = DeadAwareHPStub.new()
	var bag: Dictionary = _setup([u1, enemy], hp)
	var controller: GridBattleController = bag["controller"]
	hp.mark_dead(1)  # player dies
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._on_unit_died(1)

	assert_int(captures.size()).is_equal(1)
	assert_str(String(captures[0] as StringName)).is_equal("DEFEAT_ANNIHILATION")


# ─── CR-7 evaluation order: mutual annihilation → VICTORY wins ─────────────

func test_check_battle_end_mutual_annihilation_player_wins() -> void:
	# Both sides 0 alive → VICTORY_ANNIHILATION (CR-7 / EC-GB-02 player-side precedence).
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var hp: DeadAwareHPStub = DeadAwareHPStub.new()
	var bag: Dictionary = _setup([u1, enemy], hp)
	var controller: GridBattleController = bag["controller"]
	hp.mark_dead(1)
	hp.mark_dead(2)
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._on_unit_died(2)

	# CR-7: VICTORY checked BEFORE DEFEAT → player wins on mutual-kill.
	assert_int(captures.size()).is_equal(1)
	assert_str(String(captures[0] as StringName)).is_equal("VICTORY_ANNIHILATION")


# ─── AC-7: terminal-state idempotency — second emit suppressed ─────────────

func test_battle_over_blocks_second_outcome_emit() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, enemy])
	var controller: GridBattleController = bag["controller"]
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	# First emit: TURN_LIMIT_REACHED via _on_round_started.
	controller._on_round_started(6)
	# Attempt second emit via direct call.
	controller._emit_battle_outcome(&"VICTORY_ANNIHILATION")

	# AC-7: only the first outcome stuck; second was suppressed.
	assert_int(captures.size()).is_equal(1)
	assert_str(String(captures[0] as StringName)).is_equal("TURN_LIMIT_REACHED")


# ─── AC-7: terminal-state input guard — handle_grid_click silent ───────────

func test_handle_grid_click_silent_after_battle_over() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(1, 1), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, enemy])
	var controller: GridBattleController = bag["controller"]
	# Force terminal state.
	controller._on_round_started(6)
	var captures: Array = []
	controller.unit_selected_changed.connect(func(unit_id: int, was: int) -> void:
		captures.append({"unit_id": unit_id, "was": was})
	)

	# Click that would normally select unit 1.
	controller.handle_grid_click("unit_select", Vector2i(1, 1), 1)

	# AC-7: input ignored — no FSM transition, no signal emit.
	assert_int(captures.size()).is_equal(0)
	assert_int(controller.get_selected_unit_id()).is_equal(-1)


# ─── AC-3 + AC-7: round_started after battle_over is silent ────────────────

func test_on_round_started_silent_after_battle_over() -> void:
	# After TURN_LIMIT_REACHED resolves, subsequent round_started must be inert
	# (no second emit, no fate counter pollution from late round signals).
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, enemy])
	var controller: GridBattleController = bag["controller"]
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._on_round_started(6)  # first emit
	controller._on_round_started(7)  # would-be second emit — suppressed

	assert_int(captures.size()).is_equal(1)


# ─── S99: per-chapter turn_budget override via set_victory_conditions ─────────

func test_set_victory_conditions_positive_turn_budget_overrides_max_turns() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, enemy])
	var controller: GridBattleController = bag["controller"]
	# _setup primed _max_turns = 5 (the global-default mirror).
	var vc: VictoryConditions = VictoryConditions.new()
	vc.primary_condition_type = int(VictoryConditions.ConditionType.ANNIHILATION)
	vc.turn_budget = 6

	controller.set_victory_conditions(vc)

	assert_int(controller._max_turns).override_failure_message(
		"S99: positive turn_budget must override _max_turns (6, not the global 5)"
	).is_equal(6)


func test_set_victory_conditions_zero_turn_budget_keeps_global_default() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, enemy])
	var controller: GridBattleController = bag["controller"]
	var vc: VictoryConditions = VictoryConditions.new()
	vc.turn_budget = 0  # sentinel — use global default

	controller.set_victory_conditions(vc)

	assert_int(controller._max_turns).override_failure_message(
		"S99: turn_budget=0 sentinel must leave the global default (5) intact"
	).is_equal(5)


func test_set_victory_conditions_null_keeps_global_default() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, enemy])
	var controller: GridBattleController = bag["controller"]

	controller.set_victory_conditions(null)

	assert_int(controller._max_turns).override_failure_message(
		"S99: null victory_conditions must leave the global default (5) intact"
	).is_equal(5)


## Behavioural end-to-end: a turn_budget=6 chapter does NOT draw at round 6
## (which WAS over the old global 5), and DOES draw at round 7. This is the
## ch11/12/14 equalization made observable at the outcome layer.
func test_turn_budget_6_does_not_draw_at_round_6_draws_at_round_7() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, enemy])
	var controller: GridBattleController = bag["controller"]
	var vc: VictoryConditions = VictoryConditions.new()
	vc.turn_budget = 6
	controller.set_victory_conditions(vc)
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._on_round_started(6)  # over-limit at global 5; within budget 6 now
	assert_int(captures.size()).override_failure_message(
		"S99: round 6 must NOT draw when turn_budget=6 (it drew at the global 5)"
	).is_equal(0)

	controller._on_round_started(7)  # over budget 6 → TURN_LIMIT_REACHED
	assert_int(captures.size()).is_equal(1)
	assert_str(String(captures[0] as StringName)).is_equal("TURN_LIMIT_REACHED")


## G-30 regression — production order is setup → set_victory_conditions →
## add_child (→ _ready). _ready re-loads the global MAX_TURNS default; without
## the S99 re-apply it would CLOBBER the chapter budget set before mounting.
## The bypass-tree tests above never fire _ready (no add_child), so they passed
## while windowed mode was broken (g30_turn_budget_smoke caught it). This test
## mounts the controller to reproduce the windowed-only clobber path.
func test_ready_after_set_victory_conditions_does_not_clobber_turn_budget() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var map_grid: MapGridStub = MapGridStubScript.new()
	map_grid.set_dimensions_for_test(Vector2i(8, 8))
	auto_free(map_grid)
	var camera: BattleCameraStub = BattleCameraStubScript.new()
	auto_free(camera)
	var hero_db: HeroDatabaseStub = HeroDatabaseStubScript.new()
	var turn_runner: TurnOrderRunnerStub = TurnOrderRunnerStubScript.new()
	auto_free(turn_runner)
	var hp: HPStatusController = HPStatusControllerStubScript.new()
	auto_free(hp)
	var terrain_effect: TerrainEffectStub = TerrainEffectStubScript.new()
	var unit_role: UnitRoleStub = UnitRoleStubScript.new()
	var controller: GridBattleController = GridBattleControllerScript.new()
	controller.setup([u1, enemy], map_grid, camera, hero_db, turn_runner, hp, terrain_effect, unit_role)
	var vc: VictoryConditions = VictoryConditions.new()
	vc.turn_budget = 6
	controller.set_victory_conditions(vc)  # production order: BEFORE add_child

	# Mount → fires _ready → loads global default (5), then S99 re-applies 6.
	add_child(controller)
	await get_tree().process_frame

	assert_int(controller._max_turns).override_failure_message(
		"S99/G-30: _ready() must NOT clobber the chapter turn_budget (6) set before add_child"
	).is_equal(6)

	# Explicit in-body teardown per G-6 (orphan detector fires before after_test).
	remove_child(controller)
	controller.free()
