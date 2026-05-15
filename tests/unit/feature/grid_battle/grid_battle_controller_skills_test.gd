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
##   - skill_piercing_volley: 28 damage to up to 3 nearest in range (황충)
##   - skill_charm: marks adjacent enemies as already-acted (초선)
##   - skill_strategist: 15 damage to all enemies on the map (조조)
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
		unit_class: int = 1, attack_range: int = 1) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.hero_id = StringName("test_hero_%d" % unit_id)
	unit.unit_class = unit_class
	unit.position = pos
	unit.side = side
	unit.attack_range = attack_range
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


# ─── skill_piercing_volley (황충) ────────────────────────────────────────────


func test_piercing_volley_damages_up_to_three_nearest_enemies() -> void:
	# 황충 at (5,5), attack_range=2. Enemies at: (5,6) dist 1, (5,4) dist 1,
	# (5,7) dist 2, (5,3) dist 2 — 4 candidates within range. Cap = 3 hits ×
	# 28 dmg = 84. 5th enemy at (5,8) is dist 3 (out of range) — not hit.
	var caster: BattleUnit = _make_unit(1, Vector2i(5, 5), 0, &"skill_piercing_volley",
		int(UnitRole.UnitClass.ARCHER), 2)
	var e_close_a: BattleUnit = _make_unit(2, Vector2i(5, 6), 1, &"",
		int(UnitRole.UnitClass.INFANTRY))
	var e_close_b: BattleUnit = _make_unit(3, Vector2i(5, 4), 1, &"",
		int(UnitRole.UnitClass.INFANTRY))
	var e_mid_a: BattleUnit = _make_unit(4, Vector2i(5, 7), 1, &"",
		int(UnitRole.UnitClass.INFANTRY))
	var e_mid_b: BattleUnit = _make_unit(5, Vector2i(5, 3), 1, &"",
		int(UnitRole.UnitClass.INFANTRY))
	var e_far: BattleUnit = _make_unit(6, Vector2i(5, 8), 1, &"",
		int(UnitRole.UnitClass.INFANTRY))
	var controller: GridBattleController = _setup(
		[caster, e_close_a, e_close_b, e_mid_a, e_mid_b, e_far])
	assert_bool(controller.use_skill(1)).is_true()
	# 3 hits × 28 dmg = 84 total. Closer enemies sorted ahead of farther ones.
	assert_int(controller._damage_dealt_by_unit.get(1, 0)).override_failure_message(
		"piercing_volley should hit 3 nearest enemies; got %d" % controller._damage_dealt_by_unit.get(1, 0)
	).is_equal(84)


func test_piercing_volley_ignores_out_of_range_enemies() -> void:
	# 황충 attack_range=2; only enemy is at distance 3 — no hit, no damage.
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_piercing_volley",
		int(UnitRole.UnitClass.ARCHER), 2)
	var e_far: BattleUnit = _make_unit(2, Vector2i(5, 2), 1)
	var controller: GridBattleController = _setup([caster, e_far])
	controller.use_skill(1)
	assert_int(controller._damage_dealt_by_unit.get(1, 0)).is_equal(0)


func test_piercing_volley_spends_action_token() -> void:
	# Skill firing is the terminal action — spends ATK regardless of hit count.
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_piercing_volley",
		int(UnitRole.UnitClass.ARCHER), 2)
	var e: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var controller: GridBattleController = _setup([caster, e])
	controller.use_skill(1)
	assert_bool(controller._acted_this_turn.get(1, false)).is_true()


# ─── skill_charm (초선) ──────────────────────────────────────────────────────


func test_charm_marks_adjacent_unacted_enemies_as_acted() -> void:
	# 초선 at (2,2) with adjacent enemy (3,2) unacted. After charm, enemy is
	# marked acted (wastes their turn this round).
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_charm",
		int(UnitRole.UnitClass.SCOUT))
	var enemy_adj: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var enemy_far: BattleUnit = _make_unit(3, Vector2i(5, 5), 1)
	var controller: GridBattleController = _setup([caster, enemy_adj, enemy_far])
	assert_bool(controller.use_skill(1)).is_true()
	assert_bool(controller._acted_this_turn.get(2, false)).override_failure_message(
		"adjacent enemy should be marked acted after charm"
	).is_true()
	# Far enemy unaffected (not adjacent).
	assert_bool(controller._acted_this_turn.get(3, false)).is_false()


func test_charm_does_not_double_spend_already_acted_enemy() -> void:
	# Adjacent enemy who already acted is left alone (charm cannot waste a
	# turn that's already spent).
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_charm",
		int(UnitRole.UnitClass.SCOUT))
	var enemy: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var controller: GridBattleController = _setup([caster, enemy])
	controller._acted_this_turn[2] = true
	controller.use_skill(1)
	# Stays true — but the test guards against an accidental "reset to false".
	assert_bool(controller._acted_this_turn.get(2, false)).is_true()


func test_charm_does_not_spend_caster_action_token() -> void:
	# Combo enabler: 초선 charms then attacks/moves. Caster ATK NOT spent.
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_charm",
		int(UnitRole.UnitClass.SCOUT))
	var enemy: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var controller: GridBattleController = _setup([caster, enemy])
	controller.use_skill(1)
	assert_bool(controller._acted_this_turn.get(1, false)).override_failure_message(
		"charm should NOT spend caster's action token"
	).is_false()


# ─── skill_strategist (조조) ─────────────────────────────────────────────────


func test_strategist_damages_all_enemies_on_map() -> void:
	# 조조 at (2,2). Enemies at (5,5), (8,8), (1,9) — all distant. Each takes
	# 15 dmg regardless of position. 3 × 15 = 45 total credited to caster.
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_strategist",
		int(UnitRole.UnitClass.COMMANDER))
	var e1: BattleUnit = _make_unit(2, Vector2i(5, 5), 1)
	var e2: BattleUnit = _make_unit(3, Vector2i(8, 8), 1)
	var e3: BattleUnit = _make_unit(4, Vector2i(1, 9), 1)
	var controller: GridBattleController = _setup([caster, e1, e2, e3])
	assert_bool(controller.use_skill(1)).is_true()
	assert_int(controller._damage_dealt_by_unit.get(1, 0)).override_failure_message(
		"strategist should hit every alive enemy; got %d" % controller._damage_dealt_by_unit.get(1, 0)
	).is_equal(45)


func test_strategist_excludes_dead_enemies() -> void:
	# Dead enemies are not hit — _hp_controller.is_alive(uid)=false gates them out.
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_strategist",
		int(UnitRole.UnitClass.COMMANDER))
	var alive: BattleUnit = _make_unit(2, Vector2i(5, 5), 1)
	var dead: BattleUnit = _make_unit(3, Vector2i(8, 8), 1)
	var controller: GridBattleController = _setup([caster, alive, dead])
	# Mark dead enemy as dead via HP stub override.
	(controller._hp_controller as HPStatusControllerStub).set_alive_for_test(3, false)
	controller.use_skill(1)
	# Only the alive enemy was hit → 15 dmg credited.
	assert_int(controller._damage_dealt_by_unit.get(1, 0)).is_equal(15)


func test_strategist_excludes_friendly_units() -> void:
	# Allies on the same side never take damage even when caster has wide reach.
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_strategist",
		int(UnitRole.UnitClass.COMMANDER))
	var ally: BattleUnit = _make_unit(2, Vector2i(3, 3), 0)
	var enemy: BattleUnit = _make_unit(3, Vector2i(7, 7), 1)
	var controller: GridBattleController = _setup([caster, ally, enemy])
	controller.use_skill(1)
	# Only the enemy was hit → 15 dmg credited (not 30).
	assert_int(controller._damage_dealt_by_unit.get(1, 0)).is_equal(15)


func test_strategist_spends_action_token() -> void:
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0, &"skill_strategist",
		int(UnitRole.UnitClass.COMMANDER))
	var enemy: BattleUnit = _make_unit(2, Vector2i(5, 5), 1)
	var controller: GridBattleController = _setup([caster, enemy])
	controller.use_skill(1)
	assert_bool(controller._acted_this_turn.get(1, false)).is_true()


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
