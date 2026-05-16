## Session-30 — ESCORT victory-condition tests for GridBattleController.
##
## ESCORT semantics:
##   - WIN: all enemies dead AND every unit in target_unit_ids alive.
##   - LOSS (escort): any target dies → DEFEAT_ESCORT_LOST (precedes WIN
##     so mutual-kill rounds resolve loss).
##   - LOSS (wipe): all player units dead → DEFEAT_ANNIHILATION.
##   - Empty target_unit_ids → degrades to ANNIHILATION + push_warning.
##
## Coverage:
##   - target dies before enemy wipe → DEFEAT_ESCORT_LOST
##   - enemy wipe + alive target → VICTORY_ESCORT
##   - mutual-kill (target dies + enemy zero same tick) → DEFEAT_ESCORT_LOST
##     precedes (LOSS precedence)
##   - player wipe + alive target + alive enemy → DEFEAT_ANNIHILATION
##   - empty target_unit_ids → ANNIHILATION fallback
##   - unknown target_unit_id in vc → silently skipped (degenerate authoring)
##   - outcome_was_win recognises VICTORY_ESCORT
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
	controller._max_turns = 999  # avoid TURN_LIMIT_REACHED interference
	return {"controller": controller, "hp": hp}


func _make_escort_vc(targets: PackedInt64Array) -> VictoryConditions:
	var vc: VictoryConditions = VictoryConditions.new()
	vc.primary_condition_type = VictoryConditions.ConditionType.ESCORT
	vc.target_unit_ids = targets
	return vc


# ─── ESCORT: target death ───────────────────────────────────────────────────


## Target dies → DEFEAT_ESCORT_LOST regardless of enemy/player counts.
func test_escort_target_death_emits_defeat_escort_lost() -> void:
	var player: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var escort: BattleUnit = _make_unit(2, Vector2i(1, 0), 0)
	var enemy: BattleUnit = _make_unit(3, Vector2i(7, 7), 1)
	var hp: DeadAwareHPStub = DeadAwareHPStub.new()
	var bag: Dictionary = _setup([player, escort, enemy], hp)
	var controller: GridBattleController = bag["controller"]
	var targets: PackedInt64Array = PackedInt64Array()
	targets.append(2)
	controller.set_victory_conditions(_make_escort_vc(targets))
	hp.mark_dead(2)  # escort target dies
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._on_unit_died(2)

	assert_int(captures.size()).is_equal(1)
	assert_str(String(captures[0] as StringName)).override_failure_message(
		"ESCORT: target death must emit DEFEAT_ESCORT_LOST"
	).is_equal("DEFEAT_ESCORT_LOST")
	assert_bool(controller._battle_over).is_true()


# ─── ESCORT: enemy wipe + alive target ──────────────────────────────────────


## All enemies dead + all targets alive → VICTORY_ESCORT.
func test_escort_enemy_wipe_with_alive_target_emits_victory_escort() -> void:
	var player: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var escort: BattleUnit = _make_unit(2, Vector2i(1, 0), 0)
	var enemy: BattleUnit = _make_unit(3, Vector2i(7, 7), 1)
	var hp: DeadAwareHPStub = DeadAwareHPStub.new()
	var bag: Dictionary = _setup([player, escort, enemy], hp)
	var controller: GridBattleController = bag["controller"]
	var targets: PackedInt64Array = PackedInt64Array()
	targets.append(2)
	controller.set_victory_conditions(_make_escort_vc(targets))
	hp.mark_dead(3)  # only enemy dies; escort + player alive
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._on_unit_died(3)

	assert_int(captures.size()).is_equal(1)
	assert_str(String(captures[0] as StringName)).override_failure_message(
		"ESCORT: enemy wipe + alive target must emit VICTORY_ESCORT"
	).is_equal("VICTORY_ESCORT")


# ─── ESCORT: LOSS precedence on mutual-kill ────────────────────────────────


## Target dies AND enemy zero simultaneously (same _check_battle_end call) →
## DEFEAT_ESCORT_LOST emitted (LOSS precedence over WIN — opposite of the
## ANNIHILATION CR-7 rule which favors VICTORY on mutual-kill).
func test_escort_mutual_kill_prefers_defeat() -> void:
	var player: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var escort: BattleUnit = _make_unit(2, Vector2i(1, 0), 0)
	var enemy: BattleUnit = _make_unit(3, Vector2i(7, 7), 1)
	var hp: DeadAwareHPStub = DeadAwareHPStub.new()
	var bag: Dictionary = _setup([player, escort, enemy], hp)
	var controller: GridBattleController = bag["controller"]
	var targets: PackedInt64Array = PackedInt64Array()
	targets.append(2)
	controller.set_victory_conditions(_make_escort_vc(targets))
	hp.mark_dead(2)  # escort dies
	hp.mark_dead(3)  # enemy also dies same tick
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._on_unit_died(2)

	assert_int(captures.size()).is_equal(1)
	assert_str(String(captures[0] as StringName)).override_failure_message(
		"ESCORT mutual-kill: DEFEAT_ESCORT_LOST must precede VICTORY_ESCORT"
	).is_equal("DEFEAT_ESCORT_LOST")


# ─── ESCORT: player wipe ────────────────────────────────────────────────────


## All player units dead + escort target also dead → DEFEAT_ESCORT_LOST.
## (Target check precedes player-wipe check; either way it's a LOSS.)
func test_escort_player_wipe_with_dead_target_emits_escort_lost() -> void:
	var player: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var escort: BattleUnit = _make_unit(2, Vector2i(1, 0), 0)
	var enemy: BattleUnit = _make_unit(3, Vector2i(7, 7), 1)
	var hp: DeadAwareHPStub = DeadAwareHPStub.new()
	var bag: Dictionary = _setup([player, escort, enemy], hp)
	var controller: GridBattleController = bag["controller"]
	var targets: PackedInt64Array = PackedInt64Array()
	targets.append(2)
	controller.set_victory_conditions(_make_escort_vc(targets))
	hp.mark_dead(1)
	hp.mark_dead(2)  # escort dies with everyone else
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._on_unit_died(2)

	assert_int(captures.size()).is_equal(1)
	assert_str(String(captures[0] as StringName)).is_equal("DEFEAT_ESCORT_LOST")


# ─── ESCORT: empty target_unit_ids → fallback ───────────────────────────────


## Degenerate authoring (ESCORT type but no targets) falls back to
## ANNIHILATION semantics — enemy wipe → VICTORY_ANNIHILATION.
func test_escort_empty_target_ids_degrades_to_annihilation() -> void:
	var player: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(3, Vector2i(7, 7), 1)
	var hp: DeadAwareHPStub = DeadAwareHPStub.new()
	var bag: Dictionary = _setup([player, enemy], hp)
	var controller: GridBattleController = bag["controller"]
	var targets: PackedInt64Array = PackedInt64Array()  # empty
	controller.set_victory_conditions(_make_escort_vc(targets))
	hp.mark_dead(3)
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._on_unit_died(3)

	assert_int(captures.size()).is_equal(1)
	assert_str(String(captures[0] as StringName)).override_failure_message(
		"ESCORT with empty target_unit_ids must degrade to VICTORY_ANNIHILATION"
	).is_equal("VICTORY_ANNIHILATION")


# ─── ESCORT: unknown target_unit_id silently skipped ────────────────────────


## ESCORT targets unit_id 99 (not in roster). Target-death check skips
## unknown ids silently rather than crashing, so the enemy-wipe-WIN path
## fires normally for the units that ARE in the roster.
func test_escort_unknown_target_id_silently_skipped() -> void:
	var player: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(3, Vector2i(7, 7), 1)
	var hp: DeadAwareHPStub = DeadAwareHPStub.new()
	var bag: Dictionary = _setup([player, enemy], hp)
	var controller: GridBattleController = bag["controller"]
	var targets: PackedInt64Array = PackedInt64Array()
	targets.append(99)  # unknown — not in roster
	controller.set_victory_conditions(_make_escort_vc(targets))
	hp.mark_dead(3)
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		captures.append(outcome)
	)

	controller._on_unit_died(3)

	assert_int(captures.size()).is_equal(1)
	assert_str(String(captures[0] as StringName)).override_failure_message(
		"ESCORT with unknown target_id must skip and emit VICTORY_ESCORT on enemy wipe"
	).is_equal("VICTORY_ESCORT")


# ─── outcome_was_win heuristic ──────────────────────────────────────────────


func test_outcome_was_win_recognises_victory_escort() -> void:
	var player: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var escort: BattleUnit = _make_unit(2, Vector2i(1, 0), 0)
	var enemy: BattleUnit = _make_unit(3, Vector2i(7, 7), 1)
	var hp: DeadAwareHPStub = DeadAwareHPStub.new()
	var bag: Dictionary = _setup([player, escort, enemy], hp)
	var controller: GridBattleController = bag["controller"]
	var targets: PackedInt64Array = PackedInt64Array()
	targets.append(2)
	controller.set_victory_conditions(_make_escort_vc(targets))
	hp.mark_dead(3)
	controller._on_unit_died(3)

	var stats: Dictionary = controller.get_battle_stats()
	assert_bool(stats.get("outcome_was_win", false) as bool).override_failure_message(
		"outcome_was_win must recognise VICTORY_ESCORT as a WIN"
	).is_true()
