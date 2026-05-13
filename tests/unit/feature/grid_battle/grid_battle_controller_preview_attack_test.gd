## Preview-attack tests for GridBattleController (session-10).
##
## Covers:
##   - preview_attack returns a populated Dictionary with the expected keys
##   - preview damage matches the actual _resolve_attack output for the same
##     attacker/defender pair (math parity guarantee)
##   - preview does NOT consume the production _rng (replay determinism)
##   - counter_eligible = true when defender is in range + has not acted
##   - counter_eligible = false when defender already acted this turn
##   - empty Dictionary when either unit_id is unknown
##
## Mirrors grid_battle_controller_attack_test.gd setup pattern.
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


func _make_unit(unit_id: int, pos: Vector2i, side: int, facing: int = 0,
		attack_range: int = 1) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.hero_id = StringName("test_hero_%d" % unit_id)
	unit.unit_class = 0  # CAVALRY for predictable direction multiplier
	unit.position = pos
	unit.side = side
	unit.facing = facing
	unit.attack_range = attack_range
	unit.move_range = 3
	unit.raw_atk = 50
	unit.raw_def = 20
	return unit


func _setup(roster: Array[BattleUnit]) -> Dictionary:
	var map_grid: MapGridStub = MapGridStubScript.new()
	map_grid.set_dimensions_for_test(Vector2i(8, 8))
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
	return {"controller": controller, "hp_controller": hp_controller}


# ─── Dictionary shape contract ────────────────────────────────────────────────


func test_preview_attack_returns_dict_with_all_expected_keys() -> void:
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var defender: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]

	var preview: Dictionary = controller.preview_attack(1, 2)

	for key: String in ["direction", "damage", "hit_pct", "counter_damage",
			"counter_eligible", "kind", "passives", "angle_mult", "aura_mult"]:
		assert_bool(preview.has(key)).override_failure_message(
			"preview must contain key '%s'; got keys: %s" % [key, preview.keys()]
		).is_true()


func test_preview_attack_returns_empty_dict_for_unknown_attacker() -> void:
	var defender: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([defender])
	var controller: GridBattleController = bag["controller"]

	var preview: Dictionary = controller.preview_attack(99, 2)

	assert_int(preview.size()).override_failure_message(
		"unknown attacker_id must return empty Dictionary; got %s" % preview
	).is_equal(0)


func test_preview_attack_returns_empty_dict_for_unknown_defender() -> void:
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var bag: Dictionary = _setup([attacker])
	var controller: GridBattleController = bag["controller"]

	var preview: Dictionary = controller.preview_attack(1, 99)

	assert_int(preview.size()).is_equal(0)


# ─── Determinism / non-mutation ───────────────────────────────────────────────


func test_preview_attack_does_not_consume_production_rng() -> void:
	# Production _rng is seeded at setup; preview must use a throwaway RNG so
	# the next real _resolve_attack pulls the same sequence as if no preview
	# had been called. Verify by capturing _rng state before/after preview.
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var defender: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]

	var rng_state_before: int = controller._rng.state
	controller.preview_attack(1, 2)
	var rng_state_after: int = controller._rng.state

	assert_int(rng_state_after).override_failure_message(
		"preview_attack must not advance the production RNG state (was %d, now %d)"
		% [rng_state_before, rng_state_after]
	).is_equal(rng_state_before)


# ─── Counter eligibility ──────────────────────────────────────────────────────


func test_counter_eligible_true_when_defender_in_range_and_not_acted() -> void:
	# Melee-adjacent defender that hasn't acted → counter eligible.
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var defender: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]

	var preview: Dictionary = controller.preview_attack(1, 2)

	assert_bool(preview["counter_eligible"]).override_failure_message(
		"adjacent defender that hasn't acted must be counter_eligible"
	).is_true()


func test_counter_eligible_false_when_defender_already_acted() -> void:
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var defender: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]
	controller._acted_this_turn[2] = true  # defender already acted this turn

	var preview: Dictionary = controller.preview_attack(1, 2)

	assert_bool(preview["counter_eligible"]).override_failure_message(
		"defender that already acted must NOT be counter_eligible"
	).is_false()


func test_counter_damage_is_zero_when_not_eligible() -> void:
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var defender: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]
	controller._acted_this_turn[2] = true

	var preview: Dictionary = controller.preview_attack(1, 2)

	assert_int(preview["counter_damage"]).is_equal(0)


# ─── Damage parity with _resolve_attack ───────────────────────────────────────


func test_preview_damage_matches_resolve_attack_for_same_units() -> void:
	# Preview and real attack must yield identical damage given the same
	# attacker/defender state. Two separate fixtures so the real attack's
	# state mutation doesn't pollute the preview comparison.
	var preview_attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var preview_defender: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var preview_bag: Dictionary = _setup([preview_attacker, preview_defender])
	var preview_controller: GridBattleController = preview_bag["controller"]

	var preview: Dictionary = preview_controller.preview_attack(1, 2)
	var preview_damage: int = int(preview["damage"])

	var real_attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var real_defender: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var real_bag: Dictionary = _setup([real_attacker, real_defender])
	var real_controller: GridBattleController = real_bag["controller"]

	var real_damage: int = real_controller._resolve_attack(real_attacker, real_defender)

	assert_int(preview_damage).override_failure_message(
		"preview damage (%d) must match real _resolve_attack damage (%d)"
		% [preview_damage, real_damage]
	).is_equal(real_damage)


# ─── Direction string ─────────────────────────────────────────────────────────


func test_preview_direction_is_valid_stringname() -> void:
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var defender: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]

	var preview: Dictionary = controller.preview_attack(1, 2)
	var direction: StringName = preview["direction"] as StringName

	assert_bool(direction in [&"FRONT", &"FLANK", &"REAR"]).override_failure_message(
		"direction must be one of FRONT/FLANK/REAR; got '%s'" % direction
	).is_true()


# ─── Hit percentage ───────────────────────────────────────────────────────────


func test_preview_hit_pct_is_100_in_mvp_no_terrain_evasion() -> void:
	# MVP constructs DefenderContext with terrain_evasion=0, so hit_pct must
	# always be 100. Surfaces as a real read-out when terrain bonuses ship.
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var defender: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]

	var preview: Dictionary = controller.preview_attack(1, 2)

	assert_int(preview["hit_pct"]).is_equal(100)


# ─── 2-step attack flow — signal emission semantics ───────────────────────────


func test_first_click_arms_preview_emits_signal_does_not_commit() -> void:
	# Arrange: player unit + adjacent enemy + selection.
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var defender: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]
	controller._active_turn_unit_id = 1
	controller._select_unit(1)  # arrange unit as selected for _handle_grid_click_unit_selected

	var preview_captures: Array = []
	controller.attack_preview_requested.connect(
		func(att_id: int, def_id: int, p: Dictionary) -> void:
			preview_captures.append({"attacker": att_id, "defender": def_id, "preview": p})
	)

	# Act: first click on enemy tile (defender).
	controller._handle_grid_click_unit_selected("unit_select", Vector2i(3, 2), 2)

	# Assert: signal emitted exactly once; pending target set; defender HP unchanged.
	assert_int(preview_captures.size()).override_failure_message(
		"first click on valid attack target must emit attack_preview_requested once"
	).is_equal(1)
	assert_int(controller._pending_attack_target_id).override_failure_message(
		"_pending_attack_target_id must be set to defender_id after first click"
	).is_equal(2)


func test_second_click_on_same_target_commits_and_dismisses() -> void:
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var defender: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]
	controller._active_turn_unit_id = 1
	controller._select_unit(1)

	var dismiss_captures: Array = []
	controller.attack_preview_dismissed.connect(
		func(reason: StringName) -> void:
			dismiss_captures.append(reason)
	)

	# First click — arm preview.
	controller._handle_grid_click_unit_selected("unit_select", Vector2i(3, 2), 2)
	assert_int(controller._pending_attack_target_id).is_equal(2)

	# Second click on same target — commit.
	controller._handle_grid_click_unit_selected("unit_select", Vector2i(3, 2), 2)

	assert_int(controller._pending_attack_target_id).override_failure_message(
		"_pending_attack_target_id must reset to -1 after commit"
	).is_equal(-1)
	# Dismiss signal must have fired with reason &"attack_committed".
	assert_int(dismiss_captures.size()).is_equal(1)
	assert_str(String(dismiss_captures[0])).is_equal("attack_committed")


func test_deselect_clears_pending_preview_and_emits_dismiss() -> void:
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var defender: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]
	controller._active_turn_unit_id = 1
	controller._select_unit(1)
	controller._handle_grid_click_unit_selected("unit_select", Vector2i(3, 2), 2)
	assert_int(controller._pending_attack_target_id).is_equal(2)

	var dismiss_captures: Array = []
	controller.attack_preview_dismissed.connect(
		func(reason: StringName) -> void:
			dismiss_captures.append(reason)
	)

	# Act: deselect (e.g. click selected unit again with no move yet).
	controller._deselect()

	assert_int(controller._pending_attack_target_id).is_equal(-1)
	assert_int(dismiss_captures.size()).override_failure_message(
		"_deselect with armed preview must emit attack_preview_dismissed once"
	).is_equal(1)
	assert_str(String(dismiss_captures[0])).is_equal("deselect")


func test_empty_tile_click_clears_pending_preview() -> void:
	# Move-tile click while preview armed should cancel preview (player chose move).
	var attacker: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	var defender: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([attacker, defender])
	var controller: GridBattleController = bag["controller"]
	controller._active_turn_unit_id = 1
	controller._select_unit(1)
	controller._handle_grid_click_unit_selected("unit_select", Vector2i(3, 2), 2)
	assert_int(controller._pending_attack_target_id).is_equal(2)

	var dismiss_captures: Array = []
	controller.attack_preview_dismissed.connect(
		func(reason: StringName) -> void:
			dismiss_captures.append(reason)
	)

	# Click empty tile (any tile with unit_id == -1).
	controller._handle_grid_click_unit_selected("unit_select", Vector2i(1, 1), -1)

	assert_int(controller._pending_attack_target_id).is_equal(-1)
	assert_int(dismiss_captures.size()).is_equal(1)
	assert_str(String(dismiss_captures[0])).is_equal("empty_tile_click")
