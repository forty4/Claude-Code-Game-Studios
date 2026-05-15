## grid_battle_controller_ambush_test.gd
##
## Verifies session-14 SCOUT AMBUSH wiring:
##   - SCOUT units carry passive_ambush via BattleScene._passive_for_class
##   - GridBattleController._resolve_attack + preview_attack pass the real
##     round_number (from TurnOrderRunner) and an acted_this_turn callable
##     into DamageCalc so AMBUSH_BONUS (1.15) can actually fire
##   - Ambush requires: SCOUT/ARCHER class + passive_ambush + round >= 2 +
##     defender has not yet acted this round + not a counter
##   - Counter eligibility (_preview_counter_eligible) suppresses the counter
##     when ambush conditions are met (target cannot counter-attack the SCOUT)
##
## Mirrors grid_battle_controller_charge_test.gd setup pattern (session-13).
extends GdUnitTestSuite

const GridBattleControllerScript: GDScript = preload("res://src/feature/grid_battle/grid_battle_controller.gd")
const BattleSceneScript: GDScript = preload("res://src/feature/battle_scene/battle_scene.gd")
const MapGridStubScript: GDScript = preload("res://tests/helpers/map_grid_stub.gd")
const HPStatusControllerStubScript: GDScript = preload("res://tests/helpers/hp_status_controller_stub.gd")
const TurnOrderRunnerStubScript: GDScript = preload("res://tests/helpers/turn_order_runner_stub.gd")
const HeroDatabaseStubScript: GDScript = preload("res://tests/helpers/hero_database_stub.gd")
const TerrainEffectStubScript: GDScript = preload("res://tests/helpers/terrain_effect_stub.gd")
const UnitRoleStubScript: GDScript = preload("res://tests/helpers/unit_role_stub.gd")
const BattleCameraStubScript: GDScript = preload("res://tests/helpers/battle_camera_stub.gd")


func before_test() -> void:
	(load("res://src/foundation/balance/balance_constants.gd") as GDScript).set("_cache_loaded", false)


func _make_unit(unit_id: int, unit_class: int, pos: Vector2i, side: int,
		passive: StringName = &"") -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.hero_id = StringName("test_hero_%d" % unit_id)
	unit.unit_class = unit_class
	unit.position = pos
	unit.side = side
	unit.attack_range = 1
	unit.move_range = 4
	unit.raw_atk = 50
	unit.raw_def = 20
	unit.passive = passive
	return unit


func _setup(roster: Array[BattleUnit]) -> Dictionary:
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
	return {"controller": controller, "turn_runner": turn_runner}


# ─── BattleScene._passive_for_class wiring ───────────────────────────────────


func test_scout_class_resolves_to_passive_ambush() -> void:
	# BattleScene._passive_for_class is the production source — SCOUT (enum
	# value 5) → &"passive_ambush". CAVALRY → &"passive_charge".
	# COMMANDER → &"command_aura". INFANTRY/ARCHER/STRATEGIST → &"".
	var scene: BattleScene = BattleSceneScript.new()
	auto_free(scene)
	assert_str(String(scene._passive_for_class(int(UnitRole.UnitClass.SCOUT)))).is_equal("passive_ambush")
	assert_str(String(scene._passive_for_class(int(UnitRole.UnitClass.CAVALRY)))).is_equal("passive_charge")
	assert_str(String(scene._passive_for_class(int(UnitRole.UnitClass.COMMANDER)))).is_equal("command_aura")
	assert_str(String(scene._passive_for_class(int(UnitRole.UnitClass.INFANTRY)))).is_equal("")


# ─── Ambush firing conditions ────────────────────────────────────────────────


func test_preview_damage_higher_when_scout_ambushes_unacted_target_round_2() -> void:
	# Build a SCOUT attacker with passive_ambush, adjacent INFANTRY defender
	# (no passive). Take preview damage twice: once with round_number=1 (ambush
	# locked) and once with round_number=2 (ambush available + defender not
	# yet acted). Damage MUST be higher in round 2.
	var attacker: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.SCOUT),
		Vector2i(2, 2), 0, &"passive_ambush")
	var defender: BattleUnit = _make_unit(2, int(UnitRole.UnitClass.INFANTRY),
		Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]
	var turn_runner: TurnOrderRunnerStub = bag["turn_runner"]

	turn_runner.set_round_number_for_test(1)
	var damage_round_1: int = int(controller.preview_attack(1, 2)["damage"])

	turn_runner.set_round_number_for_test(2)
	var damage_round_2: int = int(controller.preview_attack(1, 2)["damage"])

	assert_int(damage_round_2).override_failure_message(
		"SCOUT ambush damage (round 2, %d) must exceed pre-ambush baseline (round 1, %d) by ~15%%"
		% [damage_round_2, damage_round_1]
	).is_greater(damage_round_1)


func test_resolve_attack_higher_damage_when_scout_ambushes() -> void:
	# Production damage path counterpart of the preview test above.
	var attacker_a: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.SCOUT),
		Vector2i(2, 2), 0, &"passive_ambush")
	var defender_a: BattleUnit = _make_unit(2, int(UnitRole.UnitClass.INFANTRY),
		Vector2i(3, 2), 1)
	var bag_a: Dictionary = _setup([attacker_a, defender_a])
	var ctl_a: GridBattleController = bag_a["controller"]
	var tr_a: TurnOrderRunnerStub = bag_a["turn_runner"]
	tr_a.set_round_number_for_test(1)
	var damage_round_1: int = ctl_a._resolve_attack(attacker_a, defender_a)

	# Fresh fixture so HP mutation from the prior _resolve_attack does not leak.
	var attacker_b: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.SCOUT),
		Vector2i(2, 2), 0, &"passive_ambush")
	var defender_b: BattleUnit = _make_unit(2, int(UnitRole.UnitClass.INFANTRY),
		Vector2i(3, 2), 1)
	var bag_b: Dictionary = _setup([attacker_b, defender_b])
	var ctl_b: GridBattleController = bag_b["controller"]
	var tr_b: TurnOrderRunnerStub = bag_b["turn_runner"]
	tr_b.set_round_number_for_test(2)
	var damage_round_2: int = ctl_b._resolve_attack(attacker_b, defender_b)

	assert_int(damage_round_2).override_failure_message(
		"SCOUT _resolve_attack ambush damage (round 2, %d) must exceed pre-ambush (round 1, %d)"
		% [damage_round_2, damage_round_1]
	).is_greater(damage_round_1)


func test_ambush_blocked_when_defender_already_acted() -> void:
	# Even on round 2+, ambush does NOT fire if defender has already taken its
	# terminal action this round. The acted_this_turn callable (session-14)
	# bridges the controller's _acted_this_turn dictionary into the gate.
	var attacker_a: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.SCOUT),
		Vector2i(2, 2), 0, &"passive_ambush")
	var defender_a: BattleUnit = _make_unit(2, int(UnitRole.UnitClass.INFANTRY),
		Vector2i(3, 2), 1)
	var bag_a: Dictionary = _setup([attacker_a, defender_a])
	var ctl_a: GridBattleController = bag_a["controller"]
	var tr_a: TurnOrderRunnerStub = bag_a["turn_runner"]
	tr_a.set_round_number_for_test(2)
	# Mark defender as already acted — ambush MUST suppress.
	ctl_a._acted_this_turn[2] = true
	var damage_acted: int = int(ctl_a.preview_attack(1, 2)["damage"])

	# Same fixture but defender NOT acted — ambush fires.
	var attacker_b: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.SCOUT),
		Vector2i(2, 2), 0, &"passive_ambush")
	var defender_b: BattleUnit = _make_unit(2, int(UnitRole.UnitClass.INFANTRY),
		Vector2i(3, 2), 1)
	var bag_b: Dictionary = _setup([attacker_b, defender_b])
	var ctl_b: GridBattleController = bag_b["controller"]
	var tr_b: TurnOrderRunnerStub = bag_b["turn_runner"]
	tr_b.set_round_number_for_test(2)
	var damage_unacted: int = int(ctl_b.preview_attack(1, 2)["damage"])

	assert_int(damage_unacted).override_failure_message(
		"ambush damage (unacted defender, %d) must exceed acted-defender baseline (%d)"
		% [damage_unacted, damage_acted]
	).is_greater(damage_acted)


func test_non_scout_archer_class_ignores_passive_ambush() -> void:
	# Class mutex per DamageCalc._ambush_factor: only SCOUT and ARCHER can fire
	# ambush even with the passive present. An INFANTRY with passive_ambush
	# (which production code never produces, but the test seam allows) should
	# yield damage identical across round 1 vs round 2 — no ambush, no shift.
	var attacker_a: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.INFANTRY),
		Vector2i(2, 2), 0, &"passive_ambush")
	var defender_a: BattleUnit = _make_unit(2, int(UnitRole.UnitClass.INFANTRY),
		Vector2i(3, 2), 1)
	var bag_a: Dictionary = _setup([attacker_a, defender_a])
	var ctl_a: GridBattleController = bag_a["controller"]
	var tr_a: TurnOrderRunnerStub = bag_a["turn_runner"]
	tr_a.set_round_number_for_test(1)
	var dmg_round_1: int = int(ctl_a.preview_attack(1, 2)["damage"])
	tr_a.set_round_number_for_test(2)
	var dmg_round_2: int = int(ctl_a.preview_attack(1, 2)["damage"])

	assert_int(dmg_round_2).override_failure_message(
		"INFANTRY damage must NOT shift between round 1 (%d) and round 2 (%d) — class mutex"
		% [dmg_round_1, dmg_round_2]
	).is_equal(dmg_round_1)


# ─── Counter suppression ─────────────────────────────────────────────────────


func test_counter_eligible_suppressed_when_scout_ambush_active() -> void:
	# GDD: SCOUT ambush "target cannot counter-attack". When all ambush
	# conditions are met (SCOUT/ARCHER + passive_ambush + round >= 2 +
	# defender not acted), _preview_counter_eligible MUST return false.
	var attacker: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.SCOUT),
		Vector2i(2, 2), 0, &"passive_ambush")
	var defender: BattleUnit = _make_unit(2, int(UnitRole.UnitClass.INFANTRY),
		Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]
	var turn_runner: TurnOrderRunnerStub = bag["turn_runner"]
	turn_runner.set_round_number_for_test(2)

	var preview: Dictionary = controller.preview_attack(1, 2)
	assert_bool(preview["counter_eligible"] as bool).override_failure_message(
		"counter_eligible should be false when SCOUT ambush conditions are met"
	).is_false()


func test_counter_eligible_NOT_suppressed_when_round_1_blocks_ambush() -> void:
	# Same fixture, but round_number=1 — ambush gate fails (round < 2), so
	# the counter goes back to normal eligibility (range + acted only).
	var attacker: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.SCOUT),
		Vector2i(2, 2), 0, &"passive_ambush")
	var defender: BattleUnit = _make_unit(2, int(UnitRole.UnitClass.INFANTRY),
		Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]
	var turn_runner: TurnOrderRunnerStub = bag["turn_runner"]
	turn_runner.set_round_number_for_test(1)

	var preview: Dictionary = controller.preview_attack(1, 2)
	assert_bool(preview["counter_eligible"] as bool).override_failure_message(
		"counter_eligible should be true when ambush is blocked by round 1 (defender in range, not acted)"
	).is_true()


func test_counter_eligible_NOT_suppressed_for_non_scout_class() -> void:
	# An INFANTRY attacker carrying passive_ambush (test-only state — production
	# _passive_for_class never produces this) does NOT fire ambush due to class
	# mutex, so the counter eligibility falls through to the standard range
	# check — true.
	var attacker: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.INFANTRY),
		Vector2i(2, 2), 0, &"passive_ambush")
	var defender: BattleUnit = _make_unit(2, int(UnitRole.UnitClass.INFANTRY),
		Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]
	var turn_runner: TurnOrderRunnerStub = bag["turn_runner"]
	turn_runner.set_round_number_for_test(2)

	var preview: Dictionary = controller.preview_attack(1, 2)
	assert_bool(preview["counter_eligible"] as bool).override_failure_message(
		"counter_eligible should be true when attacker class fails ambush mutex (INFANTRY with passive_ambush)"
	).is_true()


# ─── Forecast passives subpanel surfacing ────────────────────────────────────


func test_preview_passives_array_includes_passive_ambush_for_scout() -> void:
	# The Combat Forecast Section-6 subpanel sources passive tags from
	# preview_attack()'s "passives" array. SCOUT with passive_ambush MUST appear
	# so the UI can render the localized "기습" label (or fallback string id).
	var attacker: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.SCOUT),
		Vector2i(2, 2), 0, &"passive_ambush")
	var defender: BattleUnit = _make_unit(2, int(UnitRole.UnitClass.INFANTRY),
		Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]
	var turn_runner: TurnOrderRunnerStub = bag["turn_runner"]
	turn_runner.set_round_number_for_test(2)

	var preview: Dictionary = controller.preview_attack(1, 2)
	var passives_arr: Array = preview["passives"] as Array
	assert_bool(&"passive_ambush" in passives_arr).override_failure_message(
		"passive_ambush must appear in preview.passives for SCOUT attacker; got %s"
		% str(passives_arr)
	).is_true()


# ─── Session-15 verb-feedback: get_ambush_eligible_target_tiles ──────────────


func test_get_ambush_eligible_target_tiles_returns_unacted_enemy_in_round_2() -> void:
	# SCOUT with passive_ambush + round 2 + adjacent unacted enemy → tile appears.
	var attacker: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.SCOUT),
		Vector2i(2, 2), 0, &"passive_ambush")
	var defender: BattleUnit = _make_unit(2, int(UnitRole.UnitClass.INFANTRY),
		Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]
	var turn_runner: TurnOrderRunnerStub = bag["turn_runner"]
	turn_runner.set_round_number_for_test(2)

	var tiles: PackedVector2Array = controller.get_ambush_eligible_target_tiles(1)
	assert_int(tiles.size()).override_failure_message(
		"expected exactly 1 ambush-eligible tile (the unacted INFANTRY at (3,2)); got %s"
		% str(tiles)
	).is_equal(1)
	assert_vector(tiles[0]).is_equal(Vector2(3, 2))


func test_get_ambush_eligible_target_tiles_empty_in_round_1() -> void:
	# Same fixture but round 1 — ambush gate locked, set must be empty even
	# though the defender is in range and unacted.
	var attacker: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.SCOUT),
		Vector2i(2, 2), 0, &"passive_ambush")
	var defender: BattleUnit = _make_unit(2, int(UnitRole.UnitClass.INFANTRY),
		Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]
	var turn_runner: TurnOrderRunnerStub = bag["turn_runner"]
	turn_runner.set_round_number_for_test(1)

	var tiles: PackedVector2Array = controller.get_ambush_eligible_target_tiles(1)
	assert_int(tiles.size()).override_failure_message(
		"round 1 must produce zero ambush tiles regardless of range; got %s"
		% str(tiles)
	).is_equal(0)


func test_get_ambush_eligible_target_tiles_skips_acted_defenders() -> void:
	# Two adjacent enemies, both in range; one has acted, one has not. Only
	# the unacted one should appear in the ambush set.
	var attacker: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.SCOUT),
		Vector2i(2, 2), 0, &"passive_ambush")
	var def_acted: BattleUnit = _make_unit(2, int(UnitRole.UnitClass.INFANTRY),
		Vector2i(3, 2), 1)
	var def_unacted: BattleUnit = _make_unit(3, int(UnitRole.UnitClass.INFANTRY),
		Vector2i(2, 3), 1)
	var bag: Dictionary = _setup([attacker, def_acted, def_unacted])
	var controller: GridBattleController = bag["controller"]
	var turn_runner: TurnOrderRunnerStub = bag["turn_runner"]
	turn_runner.set_round_number_for_test(2)
	controller._acted_this_turn[2] = true  # def_acted has spent its action

	var tiles: PackedVector2Array = controller.get_ambush_eligible_target_tiles(1)
	assert_int(tiles.size()).override_failure_message(
		"only unacted defender should appear; got %s" % str(tiles)
	).is_equal(1)
	assert_vector(tiles[0]).is_equal(Vector2(2, 3))


func test_get_ambush_eligible_target_tiles_empty_for_non_scout_class() -> void:
	# An INFANTRY with passive_ambush (test-only seam) does NOT qualify due
	# to the class mutex (SCOUT/ARCHER only); set must be empty.
	var attacker: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.INFANTRY),
		Vector2i(2, 2), 0, &"passive_ambush")
	var defender: BattleUnit = _make_unit(2, int(UnitRole.UnitClass.INFANTRY),
		Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]
	var turn_runner: TurnOrderRunnerStub = bag["turn_runner"]
	turn_runner.set_round_number_for_test(2)

	var tiles: PackedVector2Array = controller.get_ambush_eligible_target_tiles(1)
	assert_int(tiles.size()).override_failure_message(
		"INFANTRY must produce zero ambush tiles (class mutex); got %s" % str(tiles)
	).is_equal(0)


func test_get_ambush_eligible_target_tiles_empty_without_passive() -> void:
	# SCOUT without passive_ambush (e.g., production code branch that strips
	# the passive) does NOT qualify; set must be empty.
	var attacker: BattleUnit = _make_unit(1, int(UnitRole.UnitClass.SCOUT),
		Vector2i(2, 2), 0, &"")  # passive missing
	var defender: BattleUnit = _make_unit(2, int(UnitRole.UnitClass.INFANTRY),
		Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]
	var turn_runner: TurnOrderRunnerStub = bag["turn_runner"]
	turn_runner.set_round_number_for_test(2)

	var tiles: PackedVector2Array = controller.get_ambush_eligible_target_tiles(1)
	assert_int(tiles.size()).is_equal(0)
