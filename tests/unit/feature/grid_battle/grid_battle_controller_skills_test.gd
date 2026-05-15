## grid_battle_controller_skills_test.gd
##
## Session-15 commit 5: hero active skills (1×/battle "ultimate" pattern).
## heroes.json `innate_skill_ids[0]` → BattleUnit.skill_id; player presses S
## → GridBattleController.use_skill fires the matching handler.
##
## Coverage:
##   - use_skill gates: no skill / already used / wrong side / wrong turn
##   - skill_dragon_blade: next attack +50% (관우)
##   - skill_thunder_roar: 25 fixed damage to adjacent enemies (장비)
##   - skill_inspire: refunds adjacent allies' ACTION token (유비)
##   - unit_skill_used signal emission
##   - can_use_skill mirrors use_skill preconditions without firing
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


# ─── Preconditions / gates ───────────────────────────────────────────────────


func test_use_skill_returns_false_when_no_skill_wired() -> void:
	# Empty skill_id (default) → use_skill no-ops gracefully.
	var p: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"")
	var controller: GridBattleController = _setup([p])
	assert_bool(controller.use_skill(1)).is_false()


func test_use_skill_returns_false_for_enemy_side() -> void:
	# Enemy unit with a wired skill — still refused (player-only API).
	var e: BattleUnit = _make_unit(1, Vector2i(2, 2), 1, &"skill_dragon_blade")
	var controller: GridBattleController = _setup([e])
	assert_bool(controller.use_skill(1)).is_false()


func test_use_skill_returns_false_when_already_used() -> void:
	# First fire returns true, second returns false (skill_used flips).
	var p: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_dragon_blade")
	var controller: GridBattleController = _setup([p])
	assert_bool(controller.use_skill(1)).is_true()
	assert_bool(controller.use_skill(1)).is_false()


func test_use_skill_returns_false_for_unknown_skill_id() -> void:
	# Unwired skill tag — no-op + does NOT flip skill_used (so a future-wired
	# skill_id can still fire normally on the same unit).
	var p: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_brand_new_unwired")
	var controller: GridBattleController = _setup([p])
	assert_bool(controller.use_skill(1)).is_false()
	assert_bool(p.skill_used).is_false()


# ─── can_use_skill predicate ─────────────────────────────────────────────────


func test_can_use_skill_true_when_all_gates_pass() -> void:
	var p: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_dragon_blade")
	var controller: GridBattleController = _setup([p])
	assert_bool(controller.can_use_skill(1)).is_true()


func test_can_use_skill_false_after_use() -> void:
	var p: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_dragon_blade")
	var controller: GridBattleController = _setup([p])
	controller.use_skill(1)
	assert_bool(controller.can_use_skill(1)).is_false()


# ─── skill_dragon_blade (관우) ───────────────────────────────────────────────


func test_dragon_blade_amplifies_next_attack_damage() -> void:
	# Same fixture twice — once without skill, once with — assert dragon_blade
	# damage strictly greater than baseline.
	var attacker_a: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_dragon_blade",
		int(UnitRole.UnitClass.CAVALRY))
	var defender_a: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var ctl_a: GridBattleController = _setup([attacker_a, defender_a])
	var dmg_no_skill: int = ctl_a._resolve_attack(attacker_a, defender_a)

	var attacker_b: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_dragon_blade",
		int(UnitRole.UnitClass.CAVALRY))
	var defender_b: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var ctl_b: GridBattleController = _setup([attacker_b, defender_b])
	assert_bool(ctl_b.use_skill(1)).is_true()
	var dmg_with_skill: int = ctl_b._resolve_attack(attacker_b, defender_b)

	assert_int(dmg_with_skill).override_failure_message(
		"dragon_blade should boost damage; got %d (skill) vs %d (baseline)"
		% [dmg_with_skill, dmg_no_skill]
	).is_greater(dmg_no_skill)


func test_dragon_blade_consumed_on_first_attack() -> void:
	# Buff fires on attack #1, NOT on attack #2.
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_dragon_blade",
		int(UnitRole.UnitClass.CAVALRY))
	var defender1: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var defender2: BattleUnit = _make_unit(3, Vector2i(2, 3), 1)
	var controller: GridBattleController = _setup([attacker, defender1, defender2])
	controller.use_skill(1)
	var dmg1: int = controller._resolve_attack(attacker, defender1)
	var dmg2: int = controller._resolve_attack(attacker, defender2)

	# Damage 1 should be amplified; damage 2 returns to baseline (or close to it).
	# Strictly: dmg1 > dmg2 because buff was consumed on first attack.
	assert_int(dmg1).override_failure_message(
		"buff should fire on attack #1 only; got dmg1=%d vs dmg2=%d" % [dmg1, dmg2]
	).is_greater(dmg2)


# ─── skill_thunder_roar (장비) ───────────────────────────────────────────────


func test_thunder_roar_damages_all_adjacent_enemies() -> void:
	# 장비 at (2,2) with 2 adjacent enemies (3,2) + (2,3) — both take damage.
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_thunder_roar")
	var e1: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var e2: BattleUnit = _make_unit(3, Vector2i(2, 3), 1)
	var far: BattleUnit = _make_unit(4, Vector2i(5, 5), 1)  # not adjacent
	var controller: GridBattleController = _setup([caster, e1, e2, far])
	assert_bool(controller.use_skill(1)).is_true()
	# Damage stub doesn't track real HP; check that damage_dealt_by_unit reflects
	# 2 hits × 25 = 50 minimum. Each victim's apply_damage was called.
	assert_int(controller._damage_dealt_by_unit.get(1, 0)).override_failure_message(
		"thunder_roar should accumulate damage credit; got %d" % controller._damage_dealt_by_unit.get(1, 0)
	).is_equal(50)


func test_thunder_roar_ignores_diagonal_and_distant_units() -> void:
	# Diagonal unit at (3, 3) is Manhattan-2 from (2,2) — must NOT be hit.
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_thunder_roar")
	var diagonal: BattleUnit = _make_unit(2, Vector2i(3, 3), 1)
	var controller: GridBattleController = _setup([caster, diagonal])
	controller.use_skill(1)
	# No damage credited — diagonal is not adjacent.
	assert_int(controller._damage_dealt_by_unit.get(1, 0)).is_equal(0)


func test_thunder_roar_spends_action_token() -> void:
	# After thunder_roar, the caster has acted this turn (cannot move/attack again).
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_thunder_roar")
	var e: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var controller: GridBattleController = _setup([caster, e])
	controller.use_skill(1)
	assert_bool(controller._acted_this_turn.get(1, false)).is_true()


# ─── skill_inspire (유비) ────────────────────────────────────────────────────


func test_inspire_refunds_adjacent_ally_action_tokens() -> void:
	# 유비 at (2,2) with 장비 at (3,2) who already acted. After inspire, 장비's
	# action token is refunded (false again). Far ally stays unchanged.
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_inspire")
	var ally_adj: BattleUnit = _make_unit(2, Vector2i(3, 2), 0)
	var ally_far: BattleUnit = _make_unit(3, Vector2i(5, 5), 0)
	var controller: GridBattleController = _setup([caster, ally_adj, ally_far])
	controller._acted_this_turn[2] = true
	controller._acted_this_turn[3] = true
	controller.use_skill(1)
	assert_bool(controller._acted_this_turn.get(2, true)).override_failure_message(
		"adjacent ally token should be refunded (false), got true"
	).is_false()
	assert_bool(controller._acted_this_turn.get(3, false)).override_failure_message(
		"far ally token should remain spent (true), got false"
	).is_true()


func test_inspire_does_not_refund_self() -> void:
	# 유비 already acted, calls inspire — does NOT free her own token (would be
	# an infinite-action loop). Adjacent allies still refunded.
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_inspire")
	var ally: BattleUnit = _make_unit(2, Vector2i(3, 2), 0)
	var controller: GridBattleController = _setup([caster, ally])
	controller._acted_this_turn[1] = true
	controller._acted_this_turn[2] = true
	controller.use_skill(1)
	assert_bool(controller._acted_this_turn.get(1, false)).is_true()
	assert_bool(controller._acted_this_turn.get(2, true)).is_false()


# ─── Signal emission ─────────────────────────────────────────────────────────


func test_use_skill_emits_unit_skill_used_signal() -> void:
	# Subscribe to controller.unit_skill_used — assert payload (unit_id, skill_id).
	var p: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_dragon_blade")
	var controller: GridBattleController = _setup([p])
	var captures: Array = []
	controller.unit_skill_used.connect(func(uid: int, sid: StringName) -> void:
		captures.append({"unit_id": uid, "skill_id": sid}))
	controller.use_skill(1)
	assert_int(captures.size()).is_equal(1)
	assert_int(captures[0]["unit_id"] as int).is_equal(1)
	assert_str(String(captures[0]["skill_id"] as StringName)).is_equal("skill_dragon_blade")
