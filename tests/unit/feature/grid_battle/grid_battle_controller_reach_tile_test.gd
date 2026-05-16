## Session-31 — REACH_TILE victory-condition tests for GridBattleController.
##
## REACH_TILE semantics:
##   - WIN: target_unit_ids[0] occupies target_tile (checked on unit_moved).
##   - LOSS (target dead): target_unit_ids[0] dies → DEFEAT_REACH_FAILED.
##   - LOSS (player wipe): all player units dead → DEFEAT_ANNIHILATION.
##   - Enemy wipeout does NOT shortcut to WIN — REACH-only, mirror SURVIVE.
##   - Empty target_unit_ids → degrades to ANNIHILATION + push_warning.
##
## Coverage:
##   - Target unit reaches target_tile via _do_move → VICTORY_REACH_TILE
##   - Target unit moves to OTHER tile (not target) → no outcome
##   - Non-target unit reaches target_tile → no outcome (only [0] counts)
##   - Target unit death (via _check_battle_end) → DEFEAT_REACH_FAILED
##   - Enemy wipeout while target alive but not at tile → no outcome
##   - Player wipe (target also dead) → DEFEAT_REACH_FAILED (target check
##     precedes player-wipe check)
##   - Empty target_unit_ids → ANNIHILATION fallback
##   - _battle_over short-circuit on _check_reach_tile_victory
##   - outcome_was_win recognises VICTORY_REACH_TILE

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
	unit.move_range = 5
	unit.attack_range = 1
	return unit


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
	controller._max_turns = 999
	return {"controller": controller, "hp": hp, "map_grid": map_grid}


func _make_reach_vc(target_id: int, tile: Vector2i) -> VictoryConditions:
	var vc: VictoryConditions = VictoryConditions.new()
	vc.primary_condition_type = VictoryConditions.ConditionType.REACH_TILE
	var ids: PackedInt64Array = PackedInt64Array()
	ids.append(target_id)
	vc.target_unit_ids = ids
	vc.target_tile = tile
	return vc


# ─── WIN: target reaches target_tile ─────────────────────────────────────────


func test_reach_tile_target_arrival_emits_victory() -> void:
	var target: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([target, enemy])
	var controller: GridBattleController = bag["controller"]
	controller.set_victory_conditions(_make_reach_vc(1, Vector2i(3, 3)))
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._do_move(target, Vector2i(3, 3))

	assert_int(captures.size()).is_equal(1)
	assert_str(String(captures[0] as StringName)).override_failure_message(
		"REACH_TILE: target arrival must emit VICTORY_REACH_TILE"
	).is_equal("VICTORY_REACH_TILE")
	assert_bool(controller._battle_over).is_true()


## Target moves but not to target_tile → no outcome.
func test_reach_tile_target_moves_off_tile_emits_no_outcome() -> void:
	var target: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([target, enemy])
	var controller: GridBattleController = bag["controller"]
	controller.set_victory_conditions(_make_reach_vc(1, Vector2i(3, 3)))
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._do_move(target, Vector2i(2, 2))  # not the target_tile

	assert_int(captures.size()).is_equal(0)
	assert_bool(controller._battle_over).is_false()


## Non-target unit reaches target_tile → no outcome (only target_unit_ids[0] counts).
func test_reach_tile_non_target_unit_reaches_tile_emits_no_outcome() -> void:
	var target: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var other_player: BattleUnit = _make_unit(2, Vector2i(0, 5), 0)
	var enemy: BattleUnit = _make_unit(3, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([target, other_player, enemy])
	var controller: GridBattleController = bag["controller"]
	controller.set_victory_conditions(_make_reach_vc(1, Vector2i(3, 3)))  # target is unit 1
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	# Other player reaches the tile — should NOT trigger WIN.
	controller._do_move(other_player, Vector2i(3, 3))

	assert_int(captures.size()).is_equal(0)


# ─── LOSS: target death ─────────────────────────────────────────────────────


func test_reach_tile_target_death_emits_defeat_reach_failed() -> void:
	var target: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var other_player: BattleUnit = _make_unit(2, Vector2i(0, 5), 0)
	var enemy: BattleUnit = _make_unit(3, Vector2i(7, 7), 1)
	var hp: DeadAwareHPStub = DeadAwareHPStub.new()
	var bag: Dictionary = _setup([target, other_player, enemy], hp)
	var controller: GridBattleController = bag["controller"]
	controller.set_victory_conditions(_make_reach_vc(1, Vector2i(3, 3)))
	hp.mark_dead(1)  # target dies
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._on_unit_died(1)

	assert_int(captures.size()).is_equal(1)
	assert_str(String(captures[0] as StringName)).override_failure_message(
		"REACH_TILE: target death must emit DEFEAT_REACH_FAILED"
	).is_equal("DEFEAT_REACH_FAILED")


# ─── No shortcut: enemy wipe alone does NOT win ──────────────────────────────


func test_reach_tile_enemy_wipeout_without_target_arrival_emits_no_outcome() -> void:
	var target: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var hp: DeadAwareHPStub = DeadAwareHPStub.new()
	var bag: Dictionary = _setup([target, enemy], hp)
	var controller: GridBattleController = bag["controller"]
	controller.set_victory_conditions(_make_reach_vc(1, Vector2i(3, 3)))
	hp.mark_dead(2)  # enemy dies; target still at (0,0), not at tile
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._on_unit_died(2)

	assert_int(captures.size()).override_failure_message(
		"REACH_TILE: enemy wipeout must NOT shortcut to WIN — target must arrive"
	).is_equal(0)
	assert_bool(controller._battle_over).is_false()


# ─── LOSS: player wipe with target also dead ────────────────────────────────


func test_reach_tile_target_dead_check_precedes_player_wipe() -> void:
	var target: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(3, Vector2i(7, 7), 1)
	var hp: DeadAwareHPStub = DeadAwareHPStub.new()
	var bag: Dictionary = _setup([target, enemy], hp)
	var controller: GridBattleController = bag["controller"]
	controller.set_victory_conditions(_make_reach_vc(1, Vector2i(3, 3)))
	hp.mark_dead(1)  # target dead = player wipe (only one player)
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._on_unit_died(1)

	assert_int(captures.size()).is_equal(1)
	# Target check precedes the player-wipe check, so DEFEAT_REACH_FAILED wins.
	assert_str(String(captures[0] as StringName)).override_failure_message(
		"REACH_TILE: target check must precede player-wipe — DEFEAT_REACH_FAILED, not DEFEAT_ANNIHILATION"
	).is_equal("DEFEAT_REACH_FAILED")


# ─── Empty target_unit_ids → degenerate ─────────────────────────────────────


func test_reach_tile_empty_targets_degrades_to_annihilation() -> void:
	var player: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var hp: DeadAwareHPStub = DeadAwareHPStub.new()
	var bag: Dictionary = _setup([player, enemy], hp)
	var controller: GridBattleController = bag["controller"]
	# REACH_TILE type but empty target_unit_ids — degenerate.
	var vc: VictoryConditions = VictoryConditions.new()
	vc.primary_condition_type = VictoryConditions.ConditionType.REACH_TILE
	vc.target_tile = Vector2i(3, 3)
	controller.set_victory_conditions(vc)
	hp.mark_dead(2)
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._on_unit_died(2)

	assert_int(captures.size()).is_equal(1)
	assert_str(String(captures[0] as StringName)).override_failure_message(
		"REACH_TILE with empty target_unit_ids must degrade to VICTORY_ANNIHILATION"
	).is_equal("VICTORY_ANNIHILATION")


# ─── _battle_over short-circuit ─────────────────────────────────────────────


## After _battle_over is set, _check_reach_tile_victory must not re-emit.
func test_reach_tile_check_short_circuits_when_battle_over() -> void:
	var target: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([target, enemy])
	var controller: GridBattleController = bag["controller"]
	controller.set_victory_conditions(_make_reach_vc(1, Vector2i(3, 3)))
	controller._battle_over = true  # simulate prior outcome
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._do_move(target, Vector2i(3, 3))  # would normally trigger WIN

	assert_int(captures.size()).override_failure_message(
		"REACH_TILE check must short-circuit when _battle_over is true"
	).is_equal(0)


# ─── outcome_was_win heuristic ──────────────────────────────────────────────


func test_outcome_was_win_recognises_victory_reach_tile() -> void:
	var target: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([target, enemy])
	var controller: GridBattleController = bag["controller"]
	controller.set_victory_conditions(_make_reach_vc(1, Vector2i(3, 3)))
	controller._do_move(target, Vector2i(3, 3))

	var stats: Dictionary = controller.get_battle_stats()
	assert_bool(stats.get("outcome_was_win", false) as bool).override_failure_message(
		"outcome_was_win must recognise VICTORY_REACH_TILE as a WIN"
	).is_true()


# ─── Hydration: target_tile JSON round-trip ─────────────────────────────────


func test_hydrate_chapter_reach_tile_target_tile_round_trip() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var record: Dictionary = {
		"chapter_id": "test_ch",
		"chapter_number": 1,
		"map_id": "test_map",
		"author_draw_branch": false,
		"echo_threshold": 0,
		"branch_table": {
			"WIN_default":  "WIN_test_default",
			"LOSS_default": "LOSS_test_default",
		},
		"canonical_branch_key": "WIN_test_default",
		"victory_conditions": {
			"primary_condition_type": int(VictoryConditions.ConditionType.REACH_TILE),
			"target_unit_ids": [0],
			"target_tile": [11, 4],
		},
	}

	var chapter: ChapterDefinition = runner._hydrate_chapter(record)

	assert_object(chapter.victory_conditions).is_not_null()
	assert_int(chapter.victory_conditions.primary_condition_type).is_equal(
		int(VictoryConditions.ConditionType.REACH_TILE)
	)
	assert_int(chapter.victory_conditions.target_unit_ids[0]).is_equal(0)
	assert_vector(chapter.victory_conditions.target_tile).override_failure_message(
		"REACH_TILE: target_tile JSON [11, 4] must hydrate to Vector2i(11, 4)"
	).is_equal(Vector2i(11, 4))
