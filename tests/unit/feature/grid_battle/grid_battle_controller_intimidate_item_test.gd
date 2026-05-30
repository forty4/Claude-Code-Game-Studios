## grid_battle_controller_intimidate_item_test.gd
##
## S97 — ENEMY-target debuff item (Pillar #5 "적을 교란" axis). intimidate_scroll
## (협박권) sets a NEGATIVE pending_buff carry on a chosen ENEMY within
## ENEMY_DISRUPT_RANGE (3): that enemy's next attack deals × INTIMIDATE_MULT
## (0.70 = -30%). Reuses the pending_buff field + _resolve_pending_buff_magnitude
## consumption path (no separate field, no damage-calc change); kind="intimidate"
## routes the cleared signal to unit_pending_debuff_changed (red ▼ DebuffBadge).
##
## Coverage:
##   - happy path: debuff lands on the TARGET enemy (kind/magnitude/expiry),
##     caster's own buff stays empty, slot decremented, USE_ITEM token spent,
##     unit_item_used + unit_pending_debuff_changed(TARGET, true) emitted
##   - reject paths: no enemy at tile / ally (same-side) at tile / self / out of
##     range / default sentinel / dead enemy → no side effects, slot intact
##   - get_item_target_tiles ENEMY filter: only alive, opposite-side, in-range
##   - consumption: _resolve_pending_buff_magnitude returns 0.70 for an
##     intimidated unit AND routes the cleared signal to unit_pending_debuff_changed
##
## Mirrors grid_battle_controller_ally_items_test.gd setup pattern.
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


func _make_unit(unit_id: int, pos: Vector2i, side: int) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.hero_id = StringName("test_hero_%d" % unit_id)
	unit.unit_class = 0  # class irrelevant — intimidate_scroll has no class gate
	unit.position = pos
	unit.side = side
	unit.attack_range = 1
	unit.move_range = 3
	unit.raw_atk = 50
	unit.raw_def = 20
	unit.inventory = []
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
	return {
		"controller": controller,
		"hp_controller": hp_controller,
		"turn_runner": turn_runner,
	}


# ─── intimidate_scroll (협박권) — ENEMY next-attack debuff ─────────────────────


## Happy path: caster intimidates an enemy in range. The pending_buff lands on
## the TARGET enemy (kind=intimidate, magnitude=INTIMIDATE_MULT 0.70, expires=
## round+1); the caster's own pending_buff stays empty; slot decremented;
## USE_ITEM token spent; unit_pending_debuff_changed(TARGET, true) emitted
## (NOT the positive unit_pending_buff_changed).
func test_use_item_intimidate_scroll_debuffs_enemy_in_range() -> void:
	# Arrange — caster(1) at (2,2), enemy(2) at (3,2) (Manhattan 1)
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.inventory = [&"intimidate_scroll", &"", &""]
	var enemy: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([caster, enemy] as Array[BattleUnit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	var turn_stub: TurnOrderRunnerStub = bag["turn_runner"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 100)
	hp_stub.set_test_max_hp(2, 100)
	hp_stub.set_test_current_hp(2, 100)
	controller._active_turn_unit_id = 1

	var item_emitted: Array = []
	controller.unit_item_used.connect(func(uid: int, item_id: StringName, slot_idx: int, effect: int) -> void:
		item_emitted.append({"uid": uid, "item": item_id, "slot": slot_idx, "effect": effect})
	)
	var debuff_emitted: Array = []
	controller.unit_pending_debuff_changed.connect(func(uid: int, has_debuff: bool) -> void:
		debuff_emitted.append({"uid": uid, "has_debuff": has_debuff})
	)
	var buff_emitted: Array = []
	controller.unit_pending_buff_changed.connect(func(uid: int, has_buff: bool) -> void:
		buff_emitted.append({"uid": uid, "has_buff": has_buff})
	)

	# Act — target the enemy's tile (3,2)
	var fired: bool = controller.use_item(1, 0, Vector2i(3, 2))

	# Assert
	assert_bool(fired).override_failure_message(
		"intimidate_scroll targeting an enemy in range must fire"
	).is_true()
	# Debuff landed on the TARGET enemy (unit 2)
	var enemy_pb: Dictionary = controller._units[2].pending_buff
	assert_bool(enemy_pb.is_empty()).override_failure_message(
		"intimidate_scroll must set the TARGET enemy's pending_buff"
	).is_false()
	assert_str(String(enemy_pb.get(&"kind", &"") as StringName)).override_failure_message(
		"intimidate_scroll carry kind must be 'intimidate' (routes the debuff signal)"
	).is_equal("intimidate")
	assert_float(enemy_pb.get(&"magnitude", 0.0) as float).override_failure_message(
		"intimidate_scroll magnitude must be INTIMIDATE_MULT (0.70)"
	).is_equal_approx(0.70, 0.001)
	var expected_expiry: int = (turn_stub.get_current_round_number() as int) + 1
	assert_int(enemy_pb.get(&"expires_at_turn", 0) as int).override_failure_message(
		"intimidate_scroll expires_at_turn must equal current_round + 1"
	).is_equal(expected_expiry)
	# The CASTER's own buff must stay empty (debuff goes to enemy, not self)
	assert_bool(controller._units[1].pending_buff.is_empty()).override_failure_message(
		"intimidate_scroll must NOT touch the caster's pending_buff"
	).is_true()
	# Slot decremented + USE_ITEM token spent
	assert_str(String(controller._units[1].inventory[0])).is_equal("")
	assert_int(turn_stub.declared_actions.size()).is_equal(1)
	assert_int(turn_stub.declared_actions[0]["action"] as int).is_equal(
		TurnOrderRunner.ActionType.USE_ITEM as int
	)
	# unit_item_used emitted
	assert_int(item_emitted.size()).is_equal(1)
	assert_str(String(item_emitted[0]["item"] as StringName)).is_equal("intimidate_scroll")
	# unit_pending_DEBUFF_changed(TARGET, true) — NOT the positive buff signal
	assert_int(debuff_emitted.size()).override_failure_message(
		"intimidate_scroll must emit unit_pending_debuff_changed for the TARGET enemy"
	).is_equal(1)
	assert_int(debuff_emitted[0]["uid"] as int).is_equal(2)
	assert_bool(debuff_emitted[0]["has_debuff"] as bool).is_true()
	assert_int(buff_emitted.size()).override_failure_message(
		"intimidate_scroll must NOT emit the positive unit_pending_buff_changed (gold ▶) on an enemy"
	).is_equal(0)


## Reject: no enemy at the target tile (empty tile). No debuff, slot intact.
func test_use_item_intimidate_scroll_no_enemy_at_target_rejected() -> void:
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.inventory = [&"intimidate_scroll", &"", &""]
	var bag: Dictionary = _setup([caster])
	var controller: GridBattleController = bag["controller"]
	var turn_stub: TurnOrderRunnerStub = bag["turn_runner"]
	controller._active_turn_unit_id = 1

	var fired: bool = controller.use_item(1, 0, Vector2i(3, 2))

	assert_bool(fired).override_failure_message(
		"intimidate_scroll on an empty tile (no enemy) must reject"
	).is_false()
	assert_str(String(controller._units[1].inventory[0])).is_equal("intimidate_scroll")
	assert_int(turn_stub.declared_actions.size()).is_equal(0)


## Reject: target tile holds an ALLY (same side). intimidate only reaches enemies.
func test_use_item_intimidate_scroll_ally_at_target_rejected() -> void:
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.inventory = [&"intimidate_scroll", &"", &""]
	var ally: BattleUnit = _make_unit(2, Vector2i(3, 2), 0)
	var bag: Dictionary = _setup([caster, ally] as Array[BattleUnit])
	var controller: GridBattleController = bag["controller"]
	controller._active_turn_unit_id = 1

	var fired: bool = controller.use_item(1, 0, Vector2i(3, 2))

	assert_bool(fired).override_failure_message(
		"intimidate_scroll on an ally-occupied tile must reject (enemies only)"
	).is_false()
	assert_bool(controller._units[2].pending_buff.is_empty()).override_failure_message(
		"intimidate_scroll must not touch an ally's pending_buff"
	).is_true()
	assert_str(String(controller._units[1].inventory[0])).is_equal("intimidate_scroll")


## Reject: caster targets its OWN tile (always same-side → never an enemy).
func test_use_item_intimidate_scroll_self_target_rejected() -> void:
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.inventory = [&"intimidate_scroll", &"", &""]
	var bag: Dictionary = _setup([caster])
	var controller: GridBattleController = bag["controller"]
	controller._active_turn_unit_id = 1

	var fired: bool = controller.use_item(1, 0, Vector2i(2, 2))

	assert_bool(fired).override_failure_message(
		"intimidate_scroll must reject self-target (self is never an enemy)"
	).is_false()
	assert_str(String(controller._units[1].inventory[0])).is_equal("intimidate_scroll")


## Reject: enemy exists but beyond ENEMY_DISRUPT_RANGE (Manhattan 3).
func test_use_item_intimidate_scroll_enemy_out_of_range_rejected() -> void:
	# caster(1) at (2,2), enemy(2) at (6,2) (Manhattan 4 — out of reach)
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.inventory = [&"intimidate_scroll", &"", &""]
	var enemy: BattleUnit = _make_unit(2, Vector2i(6, 2), 1)
	var bag: Dictionary = _setup([caster, enemy] as Array[BattleUnit])
	var controller: GridBattleController = bag["controller"]
	controller._active_turn_unit_id = 1

	var fired: bool = controller.use_item(1, 0, Vector2i(6, 2))

	assert_bool(fired).override_failure_message(
		"intimidate_scroll on an enemy beyond Manhattan ENEMY_DISRUPT_RANGE (3) must reject"
	).is_false()
	assert_bool(controller._units[2].pending_buff.is_empty()).is_true()
	assert_str(String(controller._units[1].inventory[0])).is_equal("intimidate_scroll")


## Reject: default sentinel target_pos (-1,-1) — ENEMY items require an explicit
## target tile.
func test_use_item_intimidate_scroll_default_sentinel_target_rejected() -> void:
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.inventory = [&"intimidate_scroll", &"", &""]
	var enemy: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([caster, enemy] as Array[BattleUnit])
	var controller: GridBattleController = bag["controller"]
	controller._active_turn_unit_id = 1

	# Act — no target_pos → default Vector2i(-1, -1)
	var fired: bool = controller.use_item(1, 0)

	assert_bool(fired).override_failure_message(
		"intimidate_scroll without an explicit target tile must reject"
	).is_false()
	assert_bool(controller._units[2].pending_buff.is_empty()).is_true()
	assert_str(String(controller._units[1].inventory[0])).is_equal("intimidate_scroll")


## Reject: enemy at tile is DEAD — no debuff on a corpse.
func test_use_item_intimidate_scroll_dead_enemy_rejected() -> void:
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.inventory = [&"intimidate_scroll", &"", &""]
	var enemy: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([caster, enemy] as Array[BattleUnit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_alive_for_test(2, false)  # dead enemy
	controller._active_turn_unit_id = 1

	var fired: bool = controller.use_item(1, 0, Vector2i(3, 2))

	assert_bool(fired).override_failure_message(
		"intimidate_scroll on a dead enemy must reject"
	).is_false()
	assert_str(String(controller._units[1].inventory[0])).is_equal("intimidate_scroll")


# ─── get_item_target_tiles ENEMY filter ──────────────────────────────────────


## intimidate_scroll overlay returns only tiles occupied by alive, OPPOSITE-side
## units within ENEMY_DISRUPT_RANGE. Ally / self / out-of-range / dead excluded.
func test_get_item_target_tiles_intimidate_filters_to_reachable_enemies() -> void:
	# caster(1) at (4,4)
	#   enemy(2) at (5,4)  — Manhattan 1, alive, enemy → INCLUDED
	#   enemy(3) at (0,4)  — Manhattan 4, out of range → excluded
	#   ally(4)  at (4,5)  — same distance but same side → excluded
	#   enemy(5) at (4,3)  — Manhattan 1 but DEAD → excluded
	var caster: BattleUnit = _make_unit(1, Vector2i(4, 4), 0)
	var enemy_in: BattleUnit = _make_unit(2, Vector2i(5, 4), 1)
	var enemy_far: BattleUnit = _make_unit(3, Vector2i(0, 4), 1)
	var ally: BattleUnit = _make_unit(4, Vector2i(4, 5), 0)
	var enemy_dead: BattleUnit = _make_unit(5, Vector2i(4, 3), 1)
	var bag: Dictionary = _setup([caster, enemy_in, enemy_far, ally, enemy_dead] as Array[BattleUnit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_alive_for_test(5, false)  # dead enemy excluded

	var tiles: PackedVector2Array = controller.get_item_target_tiles(1, &"intimidate_scroll")

	assert_int(tiles.size()).override_failure_message(
		"intimidate overlay must include ONLY the 1 reachable living enemy tile; got %d" % tiles.size()
	).is_equal(1)
	assert_bool(Vector2(5, 4) in tiles).override_failure_message(
		"intimidate overlay must contain the in-range living enemy tile (5,4)"
	).is_true()
	assert_bool(Vector2(4, 5) in tiles).override_failure_message(
		"intimidate overlay must NOT include the ally tile (4,5)"
	).is_false()
	assert_bool(Vector2(4, 4) in tiles).override_failure_message(
		"intimidate overlay must NOT include the caster's own tile"
	).is_false()


## No reachable enemy → empty overlay (player can cancel; no crash).
func test_get_item_target_tiles_intimidate_empty_when_no_reachable_enemy() -> void:
	var caster: BattleUnit = _make_unit(1, Vector2i(4, 4), 0)
	var ally: BattleUnit = _make_unit(2, Vector2i(5, 4), 0)
	var bag: Dictionary = _setup([caster, ally] as Array[BattleUnit])
	var controller: GridBattleController = bag["controller"]

	var tiles: PackedVector2Array = controller.get_item_target_tiles(1, &"intimidate_scroll")

	assert_int(tiles.size()).override_failure_message(
		"intimidate overlay must be empty when no reachable enemy exists"
	).is_equal(0)


# ─── consumption: _resolve_pending_buff_magnitude routes by kind ──────────────


## An intimidated unit's next attack consumes the carry: magnitude returns 0.70
## (weakens via the SAME path as positive buffs — _passive_multiplier has no
## lower clamp) AND the cleared signal routes to unit_pending_debuff_changed
## (false), NOT the positive unit_pending_buff_changed.
func test_resolve_pending_magnitude_consumes_intimidate_and_routes_debuff_signal() -> void:
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.inventory = [&"intimidate_scroll", &"", &""]
	var enemy: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([caster, enemy] as Array[BattleUnit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 100)
	hp_stub.set_test_max_hp(2, 100)
	hp_stub.set_test_current_hp(2, 100)
	controller._active_turn_unit_id = 1
	# Apply the debuff via the real handler (sets enemy.pending_buff intimidate).
	assert_bool(controller.use_item(1, 0, Vector2i(3, 2))).is_true()

	var debuff_emitted: Array = []
	controller.unit_pending_debuff_changed.connect(func(uid: int, has_debuff: bool) -> void:
		debuff_emitted.append({"uid": uid, "has_debuff": has_debuff})
	)
	var buff_emitted: Array = []
	controller.unit_pending_buff_changed.connect(func(uid: int, has_buff: bool) -> void:
		buff_emitted.append({"uid": uid, "has_buff": has_buff})
	)

	# Act — the intimidated enemy (unit 2) resolves an attack → consume the carry.
	var magnitude: float = controller._resolve_pending_buff_magnitude(2)

	# Assert — magnitude weakens to 0.70, carry cleared, DEBUFF signal routed.
	assert_float(magnitude).override_failure_message(
		"intimidated unit's next-attack magnitude must be INTIMIDATE_MULT (0.70)"
	).is_equal_approx(0.70, 0.001)
	assert_bool(controller._units[2].pending_buff.is_empty()).override_failure_message(
		"the intimidate carry must be cleared on consumption"
	).is_true()
	assert_int(debuff_emitted.size()).override_failure_message(
		"consuming an intimidate carry must emit unit_pending_debuff_changed(false)"
	).is_equal(1)
	assert_bool(debuff_emitted[0]["has_debuff"] as bool).is_false()
	assert_int(buff_emitted.size()).override_failure_message(
		"consuming an intimidate carry must NOT emit the positive buff signal"
	).is_equal(0)
