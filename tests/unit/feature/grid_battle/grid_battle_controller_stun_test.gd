## grid_battle_controller_stun_test.gd
##
## Session-17 — STUN status + 주유 책략 (skill_naval_strategy). The skill
## stuns every Manhattan-1 enemy. Phase split per victim acted-state at
## apply time:
##   - victim has NOT acted yet → _acted_this_turn flipped (current-round
##     turn theft, like charm)
##   - victim HAS already acted → _pending_stun gate so their NEXT turn
##     force-WAITs via _on_turn_runner_action_request (cross-round lock)
##
## Caster ATK token NOT consumed (tempo skill — charm-style). Visual badge
## ("기" red) handled by battle_scene; not exercised here.
##
## Coverage:
##   - apply_status fired for each adjacent enemy (poison-pattern mirror)
##   - diagonal / distant enemies skipped
##   - friendly fire blocked
##   - dead enemies skipped
##   - phase A: not-yet-acted victim → _acted_this_turn
##   - phase B: already-acted victim → _pending_stun
##   - caster _acted_this_turn NOT flipped (charm-style tempo)
##   - _on_turn_runner_action_request consumes _pending_stun and declares WAIT
##   - second call after consume falls through to normal dispatch path
##   - player-side stunned unit also force-WAITed (no special-case bypass)
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


func _make_unit(unit_id: int, pos: Vector2i, side: int, skill_id: StringName = &"",
		unit_class: int = 1) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.hero_id = StringName("test_hero_%d" % unit_id)
	unit.unit_class = unit_class
	unit.position = pos
	unit.side = side
	unit.attack_range = 1
	unit.move_range = 3
	unit.raw_atk = 60
	unit.raw_def = 18
	unit.skill_id = skill_id
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


# ─── _skill_naval_strategy targeting + status application ────────────────────


func test_naval_strategy_applies_stun_to_all_adjacent_enemies() -> void:
	# 주유 at (2,2) with 3 adjacent enemies at (3,2), (2,3), (1,2) and a far
	# enemy at (5,5). apply_status fired 3× with effect_id=&"stun".
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_naval_strategy")
	var e_right: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var e_down: BattleUnit = _make_unit(3, Vector2i(2, 3), 1)
	var e_left: BattleUnit = _make_unit(4, Vector2i(1, 2), 1)
	var far: BattleUnit = _make_unit(5, Vector2i(5, 5), 1)
	var controller: GridBattleController = _setup([caster, e_right, e_down, e_left, far])
	var hp_stub: HPStatusControllerStub = controller._hp_controller
	assert_bool(controller.use_skill(1)).is_true()
	var stun_calls: int = 0
	for entry: Dictionary in hp_stub.applied_status_calls:
		if (entry["effect_id"] as StringName) == &"stun":
			stun_calls += 1
	assert_int(stun_calls).override_failure_message(
		"expected 3 stun apply_status calls for adjacent enemies; got %d" % stun_calls
	).is_equal(3)


func test_naval_strategy_ignores_diagonal_and_distant_enemies() -> void:
	# Diagonal at (3,3) is Manhattan-2; distant at (5,5) is Manhattan-6.
	# Neither is adjacent — apply_status never called for either.
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_naval_strategy")
	var diagonal: BattleUnit = _make_unit(2, Vector2i(3, 3), 1)
	var distant: BattleUnit = _make_unit(3, Vector2i(5, 5), 1)
	var controller: GridBattleController = _setup([caster, diagonal, distant])
	var hp_stub: HPStatusControllerStub = controller._hp_controller
	controller.use_skill(1)
	for entry: Dictionary in hp_stub.applied_status_calls:
		var uid: int = entry["unit_id"] as int
		assert_int(uid).override_failure_message(
			"non-adjacent enemy %d must not receive stun" % uid
		).is_not_equal(2)
		assert_int(uid).is_not_equal(3)


func test_naval_strategy_skips_same_side_allies() -> void:
	# Adjacent ally must NOT be stunned. Friendly fire forbidden.
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_naval_strategy")
	var ally_adj: BattleUnit = _make_unit(2, Vector2i(3, 2), 0)
	var enemy_adj: BattleUnit = _make_unit(3, Vector2i(2, 3), 1)
	var controller: GridBattleController = _setup([caster, ally_adj, enemy_adj])
	var hp_stub: HPStatusControllerStub = controller._hp_controller
	controller.use_skill(1)
	for entry: Dictionary in hp_stub.applied_status_calls:
		assert_int(entry["unit_id"] as int).override_failure_message(
			"ally must never receive stun (friendly fire forbidden)"
		).is_not_equal(2)


func test_naval_strategy_skips_dead_enemies() -> void:
	# A dead adjacent enemy (is_alive=false) must NOT be stunned.
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_naval_strategy")
	var dead: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var alive: BattleUnit = _make_unit(3, Vector2i(2, 3), 1)
	var controller: GridBattleController = _setup([caster, dead, alive])
	var hp_stub: HPStatusControllerStub = controller._hp_controller
	hp_stub.set_alive_for_test(2, false)
	controller.use_skill(1)
	for entry: Dictionary in hp_stub.applied_status_calls:
		assert_int(entry["unit_id"] as int).override_failure_message(
			"dead enemy must not receive stun"
		).is_not_equal(2)


# ─── Phase split: current-round vs cross-round lock ──────────────────────────


func test_naval_strategy_steals_current_turn_from_not_acted_enemy() -> void:
	# Adjacent enemy has NOT acted yet → _acted_this_turn flipped to true and
	# _pending_stun NOT set (cross-round lock unnecessary; current turn stolen).
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_naval_strategy")
	var enemy: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var controller: GridBattleController = _setup([caster, enemy])
	controller.use_skill(1)
	assert_bool(controller._acted_this_turn.get(2, false)).override_failure_message(
		"not-yet-acted victim's turn should be stolen via _acted_this_turn"
	).is_true()
	assert_bool(controller._pending_stun.get(2, false)).override_failure_message(
		"_pending_stun should NOT be set when current-round turn was stolen"
	).is_false()


func test_naval_strategy_marks_already_acted_enemy_for_pending_stun() -> void:
	# Adjacent enemy HAS already acted → _pending_stun flagged so next turn
	# force-WAITs. _acted_this_turn stays true (already was).
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_naval_strategy")
	var enemy: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var controller: GridBattleController = _setup([caster, enemy])
	controller._acted_this_turn[2] = true  # pre-acted
	controller.use_skill(1)
	assert_bool(controller._pending_stun.get(2, false)).override_failure_message(
		"already-acted victim must be flagged for next-turn force-WAIT"
	).is_true()


func test_naval_strategy_does_not_spend_caster_action_token() -> void:
	# After firing, caster's _acted_this_turn stays false — they can still
	# attack or move this turn (tempo skill, like charm).
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_naval_strategy")
	var enemy: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var controller: GridBattleController = _setup([caster, enemy])
	controller.use_skill(1)
	assert_bool(controller._acted_this_turn.get(1, false)).override_failure_message(
		"caster ATK token MUST be preserved (tempo skill); got acted=true"
	).is_false()


# ─── _on_turn_runner_action_request stun gate ────────────────────────────────


func test_on_turn_runner_action_request_force_waits_stunned_enemy() -> void:
	# Stunned enemy whose turn comes up via T5 dispatch — controller must
	# declare WAIT and NOT emit ai_action_requested.
	var caster: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(5, 5), 1)
	var controller: GridBattleController = _setup([caster, enemy])
	var turn_stub: TurnOrderRunnerStub = controller._turn_runner
	controller._pending_stun[2] = true
	controller._on_turn_runner_action_request(2, null)
	var found_wait: bool = false
	for entry: Dictionary in turn_stub.declared_actions:
		if (entry["unit_id"] as int) == 2 \
				and (entry["action"] as int) == TurnOrderRunner.ActionType.WAIT:
			found_wait = true
			break
	assert_bool(found_wait).override_failure_message(
		"stunned enemy must receive declare_action(WAIT); declared=%s" % str(turn_stub.declared_actions)
	).is_true()


func test_on_turn_runner_action_request_consumes_pending_stun() -> void:
	# After the gate fires, _pending_stun[unit_id] is erased so the NEXT turn
	# falls through to normal AI dispatch.
	var caster: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(5, 5), 1)
	var controller: GridBattleController = _setup([caster, enemy])
	controller._pending_stun[2] = true
	controller._on_turn_runner_action_request(2, null)
	assert_bool(controller._pending_stun.has(2)).override_failure_message(
		"_pending_stun[2] must be erased after force-WAIT"
	).is_false()
	assert_bool(controller._acted_this_turn.get(2, false)).override_failure_message(
		"stunned victim must be marked acted after WAIT consumption"
	).is_true()


func test_on_turn_runner_action_request_force_waits_player_side_too() -> void:
	# A player-side unit that's stunned (hypothetical — e.g., future enemy
	# skill that stuns player) also gets force-WAITed. Side does not bypass
	# the stun gate.
	var stunned_player: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var controller: GridBattleController = _setup([stunned_player])
	var turn_stub: TurnOrderRunnerStub = controller._turn_runner
	controller._pending_stun[1] = true
	controller._on_turn_runner_action_request(1, null)
	var found_wait: bool = false
	for entry: Dictionary in turn_stub.declared_actions:
		if (entry["unit_id"] as int) == 1 \
				and (entry["action"] as int) == TurnOrderRunner.ActionType.WAIT:
			found_wait = true
			break
	assert_bool(found_wait).override_failure_message(
		"stunned player-side unit must also be force-WAITed (no side bypass)"
	).is_true()


func test_on_turn_runner_action_request_no_stun_falls_through_to_normal_path() -> void:
	# Non-stunned enemy → declare_action(WAIT) NOT fired from the stun gate.
	# (AI dispatch path may emit ai_action_requested instead; we just verify
	# the stun gate didn't short-circuit with a WAIT.)
	var enemy: BattleUnit = _make_unit(2, Vector2i(5, 5), 1)
	var controller: GridBattleController = _setup([enemy])
	var turn_stub: TurnOrderRunnerStub = controller._turn_runner
	# No _pending_stun entry — enemy is not stunned
	controller._on_turn_runner_action_request(2, null)
	var stun_gate_wait_fired: bool = false
	for entry: Dictionary in turn_stub.declared_actions:
		if (entry["unit_id"] as int) == 2 \
				and (entry["action"] as int) == TurnOrderRunner.ActionType.WAIT:
			stun_gate_wait_fired = true
			break
	assert_bool(stun_gate_wait_fired).override_failure_message(
		"stun gate must NOT fire WAIT when _pending_stun is empty"
	).is_false()
