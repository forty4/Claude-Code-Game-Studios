## Hidden fate-condition tests for GridBattleController per ADR-0014 §8 + story-008.
##
## Story-008 AC-1..AC-9: 5 hidden counter increments + signal emission +
## fate_data snapshot completeness. Pillar 2 ("운명은 바꿀 수 있다") UX
## relies on these counters being HIDDEN from Battle HUD — Destiny Branch
## ADR (sprint-6) is the sole consumer of the hidden_fate_condition_progressed
## signal channel.
##
## Coverage:
##   AC-2: rear_attacks (validated by story-005 attack_test; this file adds
##         a focused signal-capture test for completeness)
##   AC-3: formation_turns
##   AC-4: assassin_kills
##   AC-5: boss_killed
##   AC-7: fate_data snapshot includes tank_alive_hp_pct + 7 other fields
##   AC-9: full sweep — 4 condition types in one battle fixture

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

func _make_unit(unit_id: int, pos: Vector2i, side: int, tag: StringName = &"") -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.position = pos
	unit.side = side
	unit.facing = 0
	unit.move_range = 3
	unit.attack_range = 1
	unit.tag = tag
	return unit


## HP stub with per-unit dead-flag + per-unit HP override. Extends
## HPStatusControllerStub so the typed `_hp_controller: HPStatusController`
## field on GridBattleController accepts it.
class FateAwareHPStub extends HPStatusControllerStub:
	var _dead_units: Dictionary[int, bool] = {}
	var _current_hp: Dictionary[int, int] = {}
	var _max_hp: Dictionary[int, int] = {}

	func mark_dead(unit_id: int) -> void:
		_dead_units[unit_id] = true

	func set_hp(unit_id: int, current: int, maximum: int) -> void:
		_current_hp[unit_id] = current
		_max_hp[unit_id] = maximum

	func is_alive(unit_id: int) -> bool:
		return not _dead_units.get(unit_id, false)

	func get_current_hp(unit_id: int) -> int:
		return _current_hp.get(unit_id, 0)

	func get_max_hp(unit_id: int) -> int:
		return _max_hp.get(unit_id, 0)


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
	controller._max_turns = 5  # mirror _ready load (not invoked in unit tests)
	return {"controller": controller, "hp": hp}


# ─── AC-3: formation_turns increments when player has adjacent ally ────────

func test_on_round_started_with_adjacent_allies_increments_formation_turns() -> void:
	# Two adjacent player units form a formation → counter increments.
	var u1: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var u2: BattleUnit = _make_unit(2, Vector2i(2, 3), 0)  # Manhattan 1 from u1
	var enemy: BattleUnit = _make_unit(3, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, u2, enemy])
	var controller: GridBattleController = bag["controller"]
	# Filter to formation_turns only — Phase F added per-round counters
	# (retreat_path_clear_turns / discipline_turns etc.) that fire on the same
	# round but are unrelated to this AC-3 formation test.
	var captures: Array = []
	controller.hidden_fate_condition_progressed.connect(func(condition: StringName, value: int) -> void:
		if condition == &"formation_turns":
			captures.append({"condition": condition, "value": value})
	)

	controller._on_round_started(1)

	assert_int(controller._fate_formation_turns).is_equal(1)
	assert_int(captures.size()).is_equal(1)
	assert_str(String(captures[0].condition as StringName)).is_equal("formation_turns")
	assert_int(captures[0].value as int).is_equal(1)


# ─── AC-3: no adjacent allies → no increment ───────────────────────────────

func test_on_round_started_no_adjacent_allies_no_increment() -> void:
	# Player units far apart → no formation → no counter increment.
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var u2: BattleUnit = _make_unit(2, Vector2i(7, 7), 0)
	var enemy: BattleUnit = _make_unit(3, Vector2i(4, 4), 1)
	var bag: Dictionary = _setup([u1, u2, enemy])
	var controller: GridBattleController = bag["controller"]
	# Filter to formation_turns only — Phase F per-round counters fire too.
	var captures: Array = []
	controller.hidden_fate_condition_progressed.connect(func(condition: StringName, value: int) -> void:
		if condition == &"formation_turns":
			captures.append({"condition": condition, "value": value})
	)

	controller._on_round_started(1)

	assert_int(controller._fate_formation_turns).is_equal(0)
	assert_int(captures.size()).is_equal(0)


# ─── AC-3: one increment per round (not per qualifying unit) ───────────────

func test_on_round_started_increments_once_per_round_not_per_unit() -> void:
	# 4 player units in a 2x2 cluster — all 4 have ≥1 adjacent ally.
	# Counter must increment ONCE (round-scoped), not 4× (unit-scoped).
	var u1: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var u2: BattleUnit = _make_unit(2, Vector2i(3, 2), 0)
	var u3: BattleUnit = _make_unit(3, Vector2i(2, 3), 0)
	var u4: BattleUnit = _make_unit(4, Vector2i(3, 3), 0)
	var enemy: BattleUnit = _make_unit(5, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, u2, u3, u4, enemy])
	var controller: GridBattleController = bag["controller"]

	controller._on_round_started(1)

	assert_int(controller._fate_formation_turns).is_equal(1)


# ─── AC-5: boss kill sets flag + emits ─────────────────────────────────────

func test_on_unit_died_boss_sets_killed_flag_and_emits() -> void:
	var player: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var boss: BattleUnit = _make_unit(2, Vector2i(7, 7), 1, &"boss")
	var bag: Dictionary = _setup([player, boss])
	var controller: GridBattleController = bag["controller"]
	# _fate_boss_unit_id is populated in setup() via _find_unit_by_tag.
	assert_int(controller._fate_boss_unit_id).is_equal(2)
	var captures: Array = []
	controller.hidden_fate_condition_progressed.connect(func(condition: StringName, value: int) -> void:
		captures.append({"condition": condition, "value": value})
	)

	controller._on_unit_died(2)

	assert_bool(controller._fate_boss_killed).is_true()
	# 1 emit for boss_killed (battle-end victory check is a separate signal channel).
	assert_int(captures.size()).is_equal(1)
	assert_str(String(captures[0].condition as StringName)).is_equal("boss_killed")
	assert_int(captures[0].value as int).is_equal(1)


# ─── AC-5: non-boss death does not flip flag ───────────────────────────────

func test_on_unit_died_non_boss_no_flag_change() -> void:
	var player: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var boss: BattleUnit = _make_unit(2, Vector2i(7, 7), 1, &"boss")
	var grunt: BattleUnit = _make_unit(3, Vector2i(6, 6), 1)  # plain enemy
	var bag: Dictionary = _setup([player, boss, grunt])
	var controller: GridBattleController = bag["controller"]
	var captures: Array = []
	controller.hidden_fate_condition_progressed.connect(func(condition: StringName, value: int) -> void:
		captures.append({"condition": condition, "value": value})
	)

	controller._on_unit_died(3)

	assert_bool(controller._fate_boss_killed).is_false()
	# No fate signal emit (assassin_kills only triggers if last_attacker matches).
	assert_int(captures.size()).is_equal(0)


# ─── AC-4: assassin kill increments counter ────────────────────────────────

func test_on_unit_died_assassin_kill_increments_counter() -> void:
	var assassin: BattleUnit = _make_unit(1, Vector2i(0, 0), 0, &"assassin")
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([assassin, enemy])
	var controller: GridBattleController = bag["controller"]
	assert_int(controller._fate_assassin_unit_id).is_equal(1)
	# Set _last_attacker_id as if assassin just attacked + apply_damage emitted unit_died.
	controller._last_attacker_id = 1
	var captures: Array = []
	controller.hidden_fate_condition_progressed.connect(func(condition: StringName, value: int) -> void:
		captures.append({"condition": condition, "value": value})
	)

	controller._on_unit_died(2)

	assert_int(controller._fate_assassin_kills).is_equal(1)
	assert_int(captures.size()).is_equal(1)
	assert_str(String(captures[0].condition as StringName)).is_equal("assassin_kills")
	assert_int(captures[0].value as int).is_equal(1)


# ─── AC-4: kill by non-assassin does not increment counter ─────────────────

func test_on_unit_died_non_assassin_attacker_no_increment() -> void:
	var assassin: BattleUnit = _make_unit(1, Vector2i(0, 0), 0, &"assassin")
	var ally: BattleUnit = _make_unit(2, Vector2i(1, 0), 0)
	var enemy: BattleUnit = _make_unit(3, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([assassin, ally, enemy])
	var controller: GridBattleController = bag["controller"]
	# Last attacker was the ally (unit 2), NOT the assassin.
	controller._last_attacker_id = 2

	controller._on_unit_died(3)

	assert_int(controller._fate_assassin_kills).is_equal(0)


# ─── AC-4: assassin kill on ally (friendly fire) does not count ────────────

func test_on_unit_died_assassin_friendly_fire_no_increment() -> void:
	var assassin: BattleUnit = _make_unit(1, Vector2i(0, 0), 0, &"assassin")
	var ally: BattleUnit = _make_unit(2, Vector2i(1, 0), 0)
	var bag: Dictionary = _setup([assassin, ally])
	var controller: GridBattleController = bag["controller"]
	controller._last_attacker_id = 1  # assassin attacked

	controller._on_unit_died(2)  # ally dies (side==0, not enemy)

	# AC-4: defender must be enemy (side==1) — friendly-fire kills don't count.
	assert_int(controller._fate_assassin_kills).is_equal(0)


# ─── AC-7: fate_data snapshot includes tank_alive_hp_pct ───────────────────

func test_fate_data_snapshot_includes_tank_alive_hp_pct() -> void:
	var tank: BattleUnit = _make_unit(1, Vector2i(0, 0), 0, &"tank")
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var hp: FateAwareHPStub = FateAwareHPStub.new()
	hp.set_hp(1, 75, 100)  # tank at 75% HP
	var bag: Dictionary = _setup([tank, enemy], hp)
	var controller: GridBattleController = bag["controller"]
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(_outcome: StringName, data: Dictionary) -> void:
		captures.append(data)
	)

	controller._emit_battle_outcome(&"VICTORY_ANNIHILATION")

	assert_int(captures.size()).is_equal(1)
	var fate_data: Dictionary = captures[0] as Dictionary
	assert_float(fate_data["tank_alive_hp_pct"] as float).is_equal_approx(0.75, 0.001)
	assert_int(fate_data["tank_unit_id"] as int).is_equal(1)


# ─── AC-7: fate_data tank_pct=0 when no tank in roster ─────────────────────

func test_fate_data_snapshot_tank_pct_zero_when_no_tank_unit() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)  # no tag
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, enemy])
	var controller: GridBattleController = bag["controller"]
	# _fate_tank_unit_id is -1 (no tank-tagged unit found).
	assert_int(controller._fate_tank_unit_id).is_equal(-1)
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(_outcome: StringName, data: Dictionary) -> void:
		captures.append(data)
	)

	controller._emit_battle_outcome(&"DEFEAT_ANNIHILATION")

	var fate_data: Dictionary = captures[0] as Dictionary
	assert_float(fate_data["tank_alive_hp_pct"] as float).is_equal_approx(0.0, 0.001)


# ─── AC-9: full sweep — all 4 trackable conditions in one battle ───────────

func test_full_fate_sweep_all_conditions_trigger_independently() -> void:
	# Roster: tank + assassin + ally + boss + grunt.
	# Drives: formation_turns (assassin+ally adjacent) + boss_killed +
	# assassin_kills + tank_alive_hp_pct.
	var tank: BattleUnit = _make_unit(1, Vector2i(0, 0), 0, &"tank")
	var assassin: BattleUnit = _make_unit(2, Vector2i(3, 3), 0, &"assassin")
	var ally: BattleUnit = _make_unit(3, Vector2i(3, 4), 0)  # adjacent to assassin
	var boss: BattleUnit = _make_unit(4, Vector2i(7, 7), 1, &"boss")
	var grunt: BattleUnit = _make_unit(5, Vector2i(6, 6), 1)
	var hp: FateAwareHPStub = FateAwareHPStub.new()
	hp.set_hp(1, 50, 100)  # tank at 50%
	var bag: Dictionary = _setup([tank, assassin, ally, boss, grunt], hp)
	var controller: GridBattleController = bag["controller"]
	# Filter to legacy 3 fields — Phase F added per-round counters that fire
	# alongside formation_turns; this AC-9 sweep is scoped to the original
	# 4 trackable conditions (formation_turns + assassin_kills + boss_killed).
	var _legacy_fields: Array[StringName] = [
		&"formation_turns", &"assassin_kills", &"boss_killed", &"rear_attacks",
	]
	var fate_emits: Array = []
	controller.hidden_fate_condition_progressed.connect(func(condition: StringName, value: int) -> void:
		if condition in _legacy_fields:
			fate_emits.append({"condition": condition, "value": value})
	)
	var outcome_captures: Array = []
	controller.battle_outcome_resolved.connect(func(_outcome: StringName, data: Dictionary) -> void:
		outcome_captures.append(data)
	)

	# Round 1 → formation_turns increments (assassin+ally adjacent).
	controller._on_round_started(1)
	# Assassin kills grunt.
	controller._last_attacker_id = 2  # assassin
	controller._on_unit_died(5)
	# Player kills boss.
	controller._last_attacker_id = 3  # ally (not assassin)
	controller._on_unit_died(4)
	# Force outcome emission to capture fate_data snapshot.
	controller._emit_battle_outcome(&"VICTORY_ANNIHILATION")

	# Assert counters reached expected values.
	assert_int(controller._fate_formation_turns).is_equal(1)
	assert_int(controller._fate_assassin_kills).is_equal(1)
	assert_bool(controller._fate_boss_killed).is_true()
	# 3 hidden fate emits: formation_turns + assassin_kills + boss_killed.
	assert_int(fate_emits.size()).is_equal(3)
	# fate_data snapshot reflects final state.
	var snap: Dictionary = outcome_captures[0] as Dictionary
	assert_int(snap["formation_turns"] as int).is_equal(1)
	assert_int(snap["assassin_kills"] as int).is_equal(1)
	assert_bool(snap["boss_killed"] as bool).is_true()
	assert_float(snap["tank_alive_hp_pct"] as float).is_equal_approx(0.5, 0.001)


# ─── AC-8: hidden semantic preservation — no implicit subscribers ──────────

func test_hidden_fate_signal_has_zero_default_subscribers() -> void:
	# Per ADR-0014 §8: hidden_fate_condition_progressed is consumed ONLY by
	# Destiny Branch ADR (sprint-6) — Battle HUD MUST NOT subscribe. This
	# structural test ensures a fresh controller has zero subscribers; future
	# Battle HUD authors must explicitly opt in (which would fail this test
	# until the hidden semantic is formally relaxed).
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, enemy])
	var controller: GridBattleController = bag["controller"]

	# Inspect signal connections directly (G-8: get_connections returns
	# untyped Array).
	var connections: Array = controller.hidden_fate_condition_progressed.get_connections()

	assert_int(connections.size()).is_equal(0)


# ─── Phase F (영걸전식 25챕터 hidden destiny fate field tracking) ────────────


## Phase F — fate_data dict snapshot includes all 13 new fate fields with their
## initial values. Schema completeness sentinel: hidden_condition_evaluator
## reads `fate_data[field]` and returns false if field is MISSING (not just
## zero) — the schema must include every field referenced by shu_canon_full hidden
## conditions for the evaluator to operate on a present-but-zero value.
func test_fate_data_snapshot_includes_all_phase_f_fields() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, enemy])
	var controller: GridBattleController = bag["controller"]
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(_outcome: StringName, data: Dictionary) -> void:
		captures.append(data)
	)

	controller._emit_battle_outcome(&"DEFEAT_ANNIHILATION")

	assert_int(captures.size()).is_equal(1)
	var fate_data: Dictionary = captures[0] as Dictionary
	var phase_f_fields: Array[StringName] = [
		&"dmg_to_lubu", &"escort_alive_turns", &"win_within_turns",
		&"civilians_escorted", &"wei_yan_spared_turns", &"scout_first_turns",
		&"huang_zhong_xiahou_yuan_kill", &"retreat_path_clear_turns",
		&"discipline_turns", &"counter_fire_turns", &"menghuo_captures",
		&"masu_supervised_turns", &"qixing_turns",
	]
	for field: StringName in phase_f_fields:
		assert_bool(fate_data.has(field)).override_failure_message(
			"Phase F: fate_data snapshot must include field '%s' (HiddenConditionEvaluator returns false on missing field)"
				% String(field)
		).is_true()


## Phase F — wei_yan_spared_turns increments each round unit 15 (ch13 위연) is alive.
func test_wei_yan_spared_turns_increments_when_unit_15_alive() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var wei_yan: BattleUnit = _make_unit(15, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, wei_yan])
	var controller: GridBattleController = bag["controller"]

	controller._on_round_started(1)
	controller._on_round_started(2)
	controller._on_round_started(3)

	assert_int(controller._fate_wei_yan_spared_turns).override_failure_message(
		"Phase F: wei_yan_spared_turns must increment each round unit 15 is alive (got %d, expected 3)"
			% controller._fate_wei_yan_spared_turns
	).is_equal(3)


## Phase F — wei_yan_spared_turns stays 0 when unit 15 absent (other chapters).
func test_wei_yan_spared_turns_stays_zero_when_unit_15_absent() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, enemy])
	var controller: GridBattleController = bag["controller"]

	controller._on_round_started(1)
	controller._on_round_started(2)

	assert_int(controller._fate_wei_yan_spared_turns).is_equal(0)


## Phase F — discipline_turns counts rounds 2+ where friendly alive count
## unchanged since previous round (ch21 시그니처). Round 1 sets baseline.
func test_discipline_turns_increments_rounds_with_no_friendly_loss() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var u2: BattleUnit = _make_unit(2, Vector2i(1, 0), 0)
	var enemy: BattleUnit = _make_unit(3, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, u2, enemy])
	var controller: GridBattleController = bag["controller"]

	controller._on_round_started(1)  # baseline (2 friendly alive)
	controller._on_round_started(2)  # 2 alive → discipline=1
	controller._on_round_started(3)  # 2 alive → discipline=2
	controller._on_round_started(4)  # 2 alive → discipline=3

	assert_int(controller._fate_discipline_turns).override_failure_message(
		"Phase F: discipline_turns should be 3 (rounds 2/3/4 with no friendly losses since baseline round 1)"
	).is_equal(3)


## Phase F — discipline_turns does NOT increment when a friendly death happened.
func test_discipline_turns_resets_baseline_when_friendly_dies() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var u2: BattleUnit = _make_unit(2, Vector2i(1, 0), 0)
	var enemy: BattleUnit = _make_unit(3, Vector2i(7, 7), 1)
	var hp: FateAwareHPStub = FateAwareHPStub.new()
	var bag: Dictionary = _setup([u1, u2, enemy], hp)
	var controller: GridBattleController = bag["controller"]

	controller._on_round_started(1)  # baseline (2 friendly alive)
	controller._on_round_started(2)  # 2 alive → discipline=1
	hp.mark_dead(2)  # u2 dies between rounds
	controller._on_round_started(3)  # 1 alive — different from baseline → no increment + reset
	controller._on_round_started(4)  # 1 alive → matches new baseline → discipline=2

	assert_int(controller._fate_discipline_turns).override_failure_message(
		"Phase F: discipline_turns should be 2 (round 2 increment + round 3 reset + round 4 new-baseline increment)"
	).is_equal(2)


## Phase F — qixing_turns increments each round 제갈량 (unit 13) on tile [7,5] (ch25).
func test_qixing_turns_increments_when_zhuge_holds_position() -> void:
	var zhuge: BattleUnit = _make_unit(13, Vector2i(7, 5), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(0, 0), 1)
	var bag: Dictionary = _setup([zhuge, enemy])
	var controller: GridBattleController = bag["controller"]

	controller._on_round_started(1)
	controller._on_round_started(2)

	assert_int(controller._fate_qixing_turns).is_equal(2)


## Phase F — qixing_turns stays 0 when 제갈량 (unit 13) NOT on the칠성단 tile.
func test_qixing_turns_stays_zero_when_zhuge_off_position() -> void:
	var zhuge: BattleUnit = _make_unit(13, Vector2i(6, 5), 0)  # adjacent, not [7,5]
	var enemy: BattleUnit = _make_unit(2, Vector2i(0, 0), 1)
	var bag: Dictionary = _setup([zhuge, enemy])
	var controller: GridBattleController = bag["controller"]

	controller._on_round_started(1)
	controller._on_round_started(2)

	assert_int(controller._fate_qixing_turns).is_equal(0)


## Phase F — win_within_turns set to round count on WIN outcome (ch04 시그니처).
func test_win_within_turns_set_on_victory() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, enemy])
	var controller: GridBattleController = bag["controller"]
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(_outcome: StringName, data: Dictionary) -> void:
		captures.append(data)
	)

	controller._emit_battle_outcome(&"VICTORY_ANNIHILATION")

	var fate_data: Dictionary = captures[0] as Dictionary
	# TurnOrderRunnerStub returns 0 for get_current_round_number; controller
	# defaults to 1 when round_now <= 0 per win_within_turns set-logic.
	assert_int(fate_data["win_within_turns"] as int).override_failure_message(
		"Phase F: win_within_turns must be set to round count on WIN outcome (got %d)"
			% (fate_data["win_within_turns"] as int)
	).is_equal(1)


## Phase F — win_within_turns stays sentinel 9999 on LOSS outcome.
func test_win_within_turns_stays_sentinel_on_loss() -> void:
	var u1: BattleUnit = _make_unit(1, Vector2i(0, 0), 0)
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([u1, enemy])
	var controller: GridBattleController = bag["controller"]
	var captures: Array = []
	controller.battle_outcome_resolved.connect(func(_outcome: StringName, data: Dictionary) -> void:
		captures.append(data)
	)

	controller._emit_battle_outcome(&"DEFEAT_ANNIHILATION")

	var fate_data: Dictionary = captures[0] as Dictionary
	assert_int(fate_data["win_within_turns"] as int).override_failure_message(
		"Phase F: win_within_turns must stay sentinel 9999 on LOSS (threshold 'win_within_turns <= 6' must NOT fire)"
	).is_equal(9999)


## Phase F — scout_first_turns increments each round CAVALRY friendly stands
## on a FOREST tile (ch16 방통 생존 시그니처 #2). MapGridStub provides per-coord
## terrain via set_terrain_type_for_test.
func test_scout_first_turns_increments_when_cavalry_on_forest() -> void:
	var scout: BattleUnit = _make_unit(1, Vector2i(3, 3), 0)
	scout.unit_class = 0  # CAVALRY — matches scout role predicate
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([scout, enemy])
	var controller: GridBattleController = bag["controller"]
	# Set [3,3] as FOREST (terrain_type=1) so scout predicate fires.
	var map_grid: MapGridStub = controller._map_grid as MapGridStub
	map_grid.set_terrain_type_for_test(Vector2i(3, 3), 1)

	controller._on_round_started(1)
	controller._on_round_started(2)

	assert_int(controller._fate_scout_first_turns).override_failure_message(
		"Phase F: scout_first_turns must increment each round CAVALRY friendly on FOREST (got %d, expected 2)"
			% controller._fate_scout_first_turns
	).is_equal(2)


## Phase F — scout_first_turns stays 0 when CAVALRY friendly is NOT on a FOREST tile.
func test_scout_first_turns_stays_zero_off_forest() -> void:
	var scout: BattleUnit = _make_unit(1, Vector2i(3, 3), 0)
	scout.unit_class = 0  # CAVALRY
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([scout, enemy])
	var controller: GridBattleController = bag["controller"]
	# No FOREST terrain set — [3,3] defaults to PLAINS (terrain_type=0).

	controller._on_round_started(1)
	controller._on_round_started(2)

	assert_int(controller._fate_scout_first_turns).is_equal(0)


## Phase F — scout_first_turns ignores non-CAVALRY/non-SCOUT classes (e.g.,
## STRATEGIST on FOREST does NOT count — 방통은 본진, 정찰은 조운/마초 같은 기동 무장).
func test_scout_first_turns_ignores_strategist_on_forest() -> void:
	var strategist: BattleUnit = _make_unit(1, Vector2i(3, 3), 0)
	strategist.unit_class = 3  # STRATEGIST — not scout class
	var enemy: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([strategist, enemy])
	var controller: GridBattleController = bag["controller"]
	var map_grid: MapGridStub = controller._map_grid as MapGridStub
	map_grid.set_terrain_type_for_test(Vector2i(3, 3), 1)  # FOREST

	controller._on_round_started(1)

	assert_int(controller._fate_scout_first_turns).override_failure_message(
		"Phase F: scout_first_turns must IGNORE STRATEGIST (class 3) — only CAVALRY (0) and SCOUT (5) qualify"
	).is_equal(0)
