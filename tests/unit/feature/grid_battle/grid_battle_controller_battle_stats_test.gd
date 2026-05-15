## grid_battle_controller_battle_stats_test.gd
##
## Session-15 commit 4: GridBattleController.get_battle_stats() — player-side
## aggregate stats surfaced on UI-GB-09 after battle_outcome_resolved fires.
## Categorical-aggregate only (Pillar 2 lock per ADR-0015 §8); no fate counter
## values exposed.
##
## Coverage:
##   - Damage attribution (_resolve_attack) accumulates per-attacker into
##     _damage_dealt_by_unit; player-side aggregate flows through get_battle_stats
##   - Kill attribution (_on_unit_died via _last_attacker_id) credits player kills
##   - MVP picks the player unit with the highest damage (-1 / &"" when none)
##   - star_rating curve: 0 mid-battle / 0 on loss / 1 on win / 2 on clean OR fast / 3 on both
##   - outcome_was_win mirrors _emit_battle_outcome("VICTORY_ANNIHILATION")
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


func _make_unit(unit_id: int, pos: Vector2i, side: int, unit_class: int = 1) -> BattleUnit:
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


# ─── Initial / empty state ───────────────────────────────────────────────────


func test_get_battle_stats_initial_state_returns_zeros() -> void:
	# Before any attacks / deaths, all aggregate fields are zero / sentinel.
	var player: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var controller: GridBattleController = _setup([player, enemy])

	var stats: Dictionary = controller.get_battle_stats()
	assert_int(stats["total_player_damage"] as int).is_equal(0)
	assert_int(stats["mvp_unit_id"] as int).is_equal(-1)
	assert_str(String(stats["mvp_hero_id"] as StringName)).is_equal("")
	assert_int(stats["player_kills"] as int).is_equal(0)
	assert_int(stats["star_rating"] as int).is_equal(0)
	assert_bool(stats["outcome_was_win"] as bool).is_false()


# ─── Damage attribution + MVP ────────────────────────────────────────────────


func test_resolve_attack_accumulates_damage_for_player_attacker() -> void:
	# Player attacks enemy → player's damage tally grows.
	var player: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var controller: GridBattleController = _setup([player, enemy])

	controller._resolve_attack(player, enemy)
	var stats: Dictionary = controller.get_battle_stats()
	assert_int(stats["total_player_damage"] as int).is_greater(0)
	assert_int(stats["mvp_unit_id"] as int).is_equal(1)


func test_mvp_picks_player_with_higher_damage_when_multiple_attackers() -> void:
	# Two player attackers + one enemy. MVP = higher damage dealer.
	var p_high: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	p_high.raw_atk = 90  # boosts damage
	var p_low: BattleUnit = _make_unit(3, Vector2i(2, 3), 0)
	p_low.raw_atk = 40
	# Fresh enemy fixtures per attack so HP mutation from the first attack
	# does not skew the second one's resolved damage.
	var enemy1: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var enemy2: BattleUnit = _make_unit(4, Vector2i(3, 3), 1)
	var controller: GridBattleController = _setup([p_high, p_low, enemy1, enemy2])

	controller._resolve_attack(p_high, enemy1)
	controller._resolve_attack(p_low, enemy2)
	var stats: Dictionary = controller.get_battle_stats()
	assert_int(stats["mvp_unit_id"] as int).override_failure_message(
		"MVP should be unit_id=1 (raw_atk=90), got %d" % (stats["mvp_unit_id"] as int)
	).is_equal(1)


func test_mvp_excludes_enemy_side_even_if_damage_higher() -> void:
	# Enemy deals more damage than any player → MVP still picks player only,
	# or returns -1 if no player attacks happened.
	var p: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var e: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	e.raw_atk = 110  # massive
	var controller: GridBattleController = _setup([p, e])

	controller._resolve_attack(e, p)  # enemy attacks player
	var stats: Dictionary = controller.get_battle_stats()
	# total_player_damage is the PLAYER's damage, not the enemy's
	assert_int(stats["total_player_damage"] as int).is_equal(0)
	assert_int(stats["mvp_unit_id"] as int).is_equal(-1)


# ─── Kill attribution ────────────────────────────────────────────────────────


func test_player_kill_credit_when_last_attacker_kills_enemy() -> void:
	# _on_unit_died checks _last_attacker_id (populated by _resolve_attack).
	# Simulate by setting _last_attacker_id directly then firing _on_unit_died.
	var p: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var e: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var controller: GridBattleController = _setup([p, e])
	controller._last_attacker_id = 1  # player killed enemy

	controller._on_unit_died(2)
	var stats: Dictionary = controller.get_battle_stats()
	assert_int(stats["player_kills"] as int).is_equal(1)


func test_friendly_fire_does_not_count_as_kill_credit() -> void:
	# Same-side death (e.g. friendly fire / status tick) MUST NOT increment
	# player_kills — guards against double-counting on map effects or bugs.
	var p1: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var p2: BattleUnit = _make_unit(3, Vector2i(2, 3), 0)
	var controller: GridBattleController = _setup([p1, p2])
	controller._last_attacker_id = 1  # ally killed ally somehow

	controller._on_unit_died(3)
	var stats: Dictionary = controller.get_battle_stats()
	assert_int(stats["player_kills"] as int).is_equal(0)


# ─── Session-16: unit_killed mid-battle signal ───────────────────────────────


func test_unit_killed_fires_on_cross_side_kill() -> void:
	# Cross-side death with valid killer → unit_killed emits with payload.
	var p: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var e: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var controller: GridBattleController = _setup([p, e])
	controller._last_attacker_id = 1
	var captures: Array = []
	controller.unit_killed.connect(
		func(killer: int, victim: int, hero: StringName) -> void:
			captures.append({"killer": killer, "victim": victim, "hero": hero})
	)

	controller._on_unit_died(2)

	assert_int(captures.size()).override_failure_message(
		"Cross-side kill should fire unit_killed exactly once"
	).is_equal(1)
	assert_int(captures[0].killer as int).is_equal(1)
	assert_int(captures[0].victim as int).is_equal(2)
	assert_str(String(captures[0].hero as StringName)).is_equal(String(e.hero_id))


func test_unit_killed_does_not_fire_on_friendly_fire() -> void:
	# Same-side death must NOT emit unit_killed (mirrors kill-credit rule).
	var p1: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var p2: BattleUnit = _make_unit(3, Vector2i(2, 3), 0)
	var controller: GridBattleController = _setup([p1, p2])
	controller._last_attacker_id = 1
	var captures: Array = []
	controller.unit_killed.connect(
		func(_k: int, _v: int, _h: StringName) -> void: captures.append(true)
	)

	controller._on_unit_died(3)

	assert_int(captures.size()).override_failure_message(
		"Friendly-fire death must NOT emit unit_killed"
	).is_equal(0)


func test_unit_killed_does_not_fire_when_battle_over() -> void:
	# Terminal-state guard mirrors _on_unit_died's _battle_over short-circuit.
	# Once battle_over flips true, no further unit_killed emits — result
	# screen takes over.
	var p: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var e: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var controller: GridBattleController = _setup([p, e])
	controller._last_attacker_id = 1
	controller._battle_over = true
	var captures: Array = []
	controller.unit_killed.connect(
		func(_k: int, _v: int, _h: StringName) -> void: captures.append(true)
	)

	controller._on_unit_died(2)

	assert_int(captures.size()).override_failure_message(
		"Battle-over deaths must NOT emit unit_killed"
	).is_equal(0)


# ─── Surviving / total counts ────────────────────────────────────────────────


func test_surviving_player_count_reflects_hp_controller_alive_state() -> void:
	# Two player units; one alive, one dead per HPStatusControllerStub.
	var p1: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var p2: BattleUnit = _make_unit(3, Vector2i(2, 3), 0)
	var controller: GridBattleController = _setup([p1, p2])
	controller._hp_controller.set_alive_for_test(1, true)
	controller._hp_controller.set_alive_for_test(3, false)

	var stats: Dictionary = controller.get_battle_stats()
	assert_int(stats["total_player_count"] as int).is_equal(2)
	assert_int(stats["surviving_player_count"] as int).is_equal(1)


# ─── Star rating curve ───────────────────────────────────────────────────────


func test_star_rating_zero_when_battle_not_over() -> void:
	var p: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var controller: GridBattleController = _setup([p])

	# _battle_over == false → 0 stars regardless of state
	assert_int(controller.get_battle_stats()["star_rating"] as int).is_equal(0)


func test_star_rating_zero_on_defeat() -> void:
	var p: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var controller: GridBattleController = _setup([p])
	controller._battle_over = true
	controller._last_outcome = &"DEFEAT_ANNIHILATION"

	assert_int(controller.get_battle_stats()["star_rating"] as int).is_equal(0)


func test_star_rating_three_on_fast_clean_victory() -> void:
	# Victory + all alive + round <= 8 → 3 stars.
	var p: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var controller: GridBattleController = _setup([p])
	controller._hp_controller.set_alive_for_test(1, true)
	controller._battle_over = true
	controller._last_outcome = &"VICTORY_ANNIHILATION"
	(controller._turn_runner as TurnOrderRunnerStub).set_round_number_for_test(5)

	assert_int(controller.get_battle_stats()["star_rating"] as int).is_equal(3)


func test_star_rating_two_on_clean_but_slow_victory() -> void:
	# Victory + all alive + round > 8 → 2 stars (clean only, not fast).
	var p: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var controller: GridBattleController = _setup([p])
	controller._hp_controller.set_alive_for_test(1, true)
	controller._battle_over = true
	controller._last_outcome = &"VICTORY_ANNIHILATION"
	(controller._turn_runner as TurnOrderRunnerStub).set_round_number_for_test(15)

	assert_int(controller.get_battle_stats()["star_rating"] as int).is_equal(2)


func test_star_rating_two_on_fast_but_lossy_victory() -> void:
	# Victory + 1 of 2 dead + round <= 8 → 2 stars (fast only).
	var p1: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var p2: BattleUnit = _make_unit(3, Vector2i(2, 3), 0)
	var controller: GridBattleController = _setup([p1, p2])
	controller._hp_controller.set_alive_for_test(1, true)
	controller._hp_controller.set_alive_for_test(3, false)
	controller._battle_over = true
	controller._last_outcome = &"VICTORY_ANNIHILATION"
	(controller._turn_runner as TurnOrderRunnerStub).set_round_number_for_test(7)

	assert_int(controller.get_battle_stats()["star_rating"] as int).is_equal(2)


func test_star_rating_one_on_slow_lossy_victory() -> void:
	# Victory + casualty + slow → 1 star (consolation).
	var p1: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var p2: BattleUnit = _make_unit(3, Vector2i(2, 3), 0)
	var controller: GridBattleController = _setup([p1, p2])
	controller._hp_controller.set_alive_for_test(1, true)
	controller._hp_controller.set_alive_for_test(3, false)
	controller._battle_over = true
	controller._last_outcome = &"VICTORY_ANNIHILATION"
	(controller._turn_runner as TurnOrderRunnerStub).set_round_number_for_test(20)

	assert_int(controller.get_battle_stats()["star_rating"] as int).is_equal(1)


# ─── outcome_was_win flag ────────────────────────────────────────────────────


func test_outcome_was_win_only_true_on_victory_annihilation() -> void:
	var p: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var controller: GridBattleController = _setup([p])
	controller._battle_over = true
	controller._last_outcome = &"VICTORY_ANNIHILATION"
	assert_bool(controller.get_battle_stats()["outcome_was_win"] as bool).is_true()

	controller._last_outcome = &"DEFEAT_ANNIHILATION"
	assert_bool(controller.get_battle_stats()["outcome_was_win"] as bool).is_false()

	controller._last_outcome = &"TURN_LIMIT_REACHED"
	assert_bool(controller.get_battle_stats()["outcome_was_win"] as bool).is_false()
