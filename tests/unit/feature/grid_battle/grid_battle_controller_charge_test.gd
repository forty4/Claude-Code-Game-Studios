## grid_battle_controller_charge_test.gd
##
## Verifies session-13 CHARGE wiring:
##   - CAVALRY units have passive_charge passive (set by BattleScene._passive_for_class)
##   - GridBattleController._resolve_attack + preview_attack query the turn
##     runner for charge eligibility and pass it to DamageCalc as charge_active
##   - When charge eligible: damage is +20% (CHARGE_BONUS=1.20)
##   - When NOT eligible: damage unchanged
##   - Forecast (preview_attack) reflects the charge bonus correctly
##
## Mirrors grid_battle_controller_attack_test.gd setup pattern.
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


func _make_cavalry(unit_id: int, pos: Vector2i, side: int, passive: StringName = &"passive_charge") -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.hero_id = StringName("test_hero_%d" % unit_id)
	unit.unit_class = 0  # CAVALRY (matches AttackerContext.Class.CAVALRY)
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


func test_cavalry_class_resolves_to_passive_charge() -> void:
	# BattleScene._passive_for_class is the production source — UnitClass.CAVALRY
	# (enum value 0) → &"passive_charge". COMMANDER → &"command_aura". Others → &"".
	var scene: BattleScene = BattleSceneScript.new()
	auto_free(scene)
	assert_str(String(scene._passive_for_class(int(UnitRole.UnitClass.CAVALRY)))).is_equal("passive_charge")
	assert_str(String(scene._passive_for_class(int(UnitRole.UnitClass.COMMANDER)))).is_equal("command_aura")
	assert_str(String(scene._passive_for_class(int(UnitRole.UnitClass.INFANTRY)))).is_equal("")


# ─── Charge eligibility query path ────────────────────────────────────────────


func test_preview_damage_higher_when_charge_eligible() -> void:
	# Build a CAVALRY attacker with passive_charge passive, adjacent CAVALRY-typed
	# defender. Take preview damage twice: once with charge eligibility false,
	# once with it forced true via the stub. Damage MUST be higher with charge.
	var attacker: BattleUnit = _make_cavalry(1, Vector2i(2, 2), 0)
	var defender: BattleUnit = _make_cavalry(2, Vector2i(3, 2), 1, &"")  # no passive
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]
	var turn_runner: TurnOrderRunnerStub = bag["turn_runner"]

	# Default stub state — charge_eligible returns false.
	turn_runner.set_charge_eligible_for_test(1, false)
	var preview_no_charge: Dictionary = controller.preview_attack(1, 2)
	var damage_no_charge: int = int(preview_no_charge["damage"])

	# Force charge eligibility via stub seam.
	turn_runner.set_charge_eligible_for_test(1, true)
	var preview_with_charge: Dictionary = controller.preview_attack(1, 2)
	var damage_with_charge: int = int(preview_with_charge["damage"])

	assert_int(damage_with_charge).override_failure_message(
		"charge-eligible CAVALRY damage (%d) must exceed non-eligible (%d) by ~20%%"
		% [damage_with_charge, damage_no_charge]
	).is_greater(damage_no_charge)


func test_resolve_attack_higher_damage_when_charge_eligible() -> void:
	# Same scenario as preview, but hits the production damage path.
	var attacker_a: BattleUnit = _make_cavalry(1, Vector2i(2, 2), 0)
	var defender_a: BattleUnit = _make_cavalry(2, Vector2i(3, 2), 1, &"")
	var bag_a: Dictionary = _setup([attacker_a, defender_a])
	var ctl_a: GridBattleController = bag_a["controller"]
	var tr_a: TurnOrderRunnerStub = bag_a["turn_runner"]
	tr_a.set_charge_eligible_for_test(1, false)
	var damage_no_charge: int = ctl_a._resolve_attack(attacker_a, defender_a)

	# Fresh fixture so the prior _resolve_attack's HP mutation doesn't leak.
	var attacker_b: BattleUnit = _make_cavalry(1, Vector2i(2, 2), 0)
	var defender_b: BattleUnit = _make_cavalry(2, Vector2i(3, 2), 1, &"")
	var bag_b: Dictionary = _setup([attacker_b, defender_b])
	var ctl_b: GridBattleController = bag_b["controller"]
	var tr_b: TurnOrderRunnerStub = bag_b["turn_runner"]
	tr_b.set_charge_eligible_for_test(1, true)
	var damage_with_charge: int = ctl_b._resolve_attack(attacker_b, defender_b)

	assert_int(damage_with_charge).override_failure_message(
		"charge-eligible _resolve_attack damage (%d) must exceed non-eligible (%d)"
		% [damage_with_charge, damage_no_charge]
	).is_greater(damage_no_charge)


# ─── Non-CAVALRY ignores charge eligibility ──────────────────────────────────


func test_infantry_ignores_charge_eligibility_flag() -> void:
	# Class mutex per DamageCalc._charge_factor: SCOUT/INFANTRY/ARCHER never
	# fire charge regardless of charge_active. INFANTRY attacker with
	# passive_charge AND charge_eligible=true should still produce baseline damage.
	var attacker: BattleUnit = _make_cavalry(1, Vector2i(2, 2), 0, &"passive_charge")
	attacker.unit_class = 1  # INFANTRY (overrides _make_cavalry's CAVALRY default)
	var defender: BattleUnit = _make_cavalry(2, Vector2i(3, 2), 1, &"")
	defender.unit_class = 1
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]
	var turn_runner: TurnOrderRunnerStub = bag["turn_runner"]

	turn_runner.set_charge_eligible_for_test(1, false)
	var dmg_no: int = int(controller.preview_attack(1, 2)["damage"])
	turn_runner.set_charge_eligible_for_test(1, true)
	var dmg_yes: int = int(controller.preview_attack(1, 2)["damage"])

	assert_int(dmg_yes).override_failure_message(
		"INFANTRY damage must NOT shift with charge eligibility (class mutex); got %d vs %d"
		% [dmg_yes, dmg_no]
	).is_equal(dmg_no)


# ─── Session-15 verb-feedback: is_charge_ready ───────────────────────────────


func test_is_charge_ready_true_for_cavalry_passive_charge_threshold_met() -> void:
	# All three gates pass: CAVALRY class + passive_charge + turn-runner reports
	# eligible. Mirrors the gate DamageCalc uses for the +20% bonus.
	var attacker: BattleUnit = _make_cavalry(1, Vector2i(2, 2), 0)
	var defender: BattleUnit = _make_cavalry(2, Vector2i(3, 2), 1, &"")
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]
	var turn_runner: TurnOrderRunnerStub = bag["turn_runner"]
	turn_runner.set_charge_eligible_for_test(1, true)

	assert_bool(controller.is_charge_ready(1)).is_true()


func test_is_charge_ready_false_when_threshold_not_met() -> void:
	# CAVALRY + passive_charge BUT accumulated_move hasn't reached threshold —
	# turn runner reports false, helper returns false.
	var attacker: BattleUnit = _make_cavalry(1, Vector2i(2, 2), 0)
	var defender: BattleUnit = _make_cavalry(2, Vector2i(3, 2), 1, &"")
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]
	var turn_runner: TurnOrderRunnerStub = bag["turn_runner"]
	turn_runner.set_charge_eligible_for_test(1, false)

	assert_bool(controller.is_charge_ready(1)).is_false()


func test_is_charge_ready_false_for_non_cavalry_class() -> void:
	# INFANTRY (or any non-CAVALRY) with passive_charge (test-only seam) still
	# fails because the class gate is part of is_charge_ready, matching the
	# class mutex DamageCalc applies to the charge bonus.
	var attacker: BattleUnit = _make_cavalry(1, Vector2i(2, 2), 0)
	attacker.unit_class = int(UnitRole.UnitClass.INFANTRY)
	var defender: BattleUnit = _make_cavalry(2, Vector2i(3, 2), 1, &"")
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]
	var turn_runner: TurnOrderRunnerStub = bag["turn_runner"]
	turn_runner.set_charge_eligible_for_test(1, true)

	assert_bool(controller.is_charge_ready(1)).is_false()


func test_is_charge_ready_false_without_passive_charge() -> void:
	# CAVALRY whose passive was never wired (e.g., production code branch
	# that strips it) fails the passive gate even though the class is correct.
	var attacker: BattleUnit = _make_cavalry(1, Vector2i(2, 2), 0, &"")
	var defender: BattleUnit = _make_cavalry(2, Vector2i(3, 2), 1, &"")
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]
	var turn_runner: TurnOrderRunnerStub = bag["turn_runner"]
	turn_runner.set_charge_eligible_for_test(1, true)

	assert_bool(controller.is_charge_ready(1)).is_false()
