## grid_battle_controller_ally_items_test.gd
##
## S94 — cross-hero ALLY-target items (Pillar #5 "다른 장수를 도와주거나" axis).
## Two new items extend the strategy layer with the previously-absent ALLY
## target mode:
##   - aid_potion (구호약): immediate heal AID_POTION_AMOUNT (20) to a chosen
##     ALLY (NOT self) within Manhattan ALLY_SUPPORT_RANGE (3).
##   - rally_scroll (독려권): grant a chosen ALLY (NOT self) a next-attack
##     × RALLY_SCROLL_MULT (1.30) pending_buff (same "strength" carry as
##     strength_scroll, consumed at the ally's next attack-resolve).
##
## Coverage:
##   - happy paths: heal/buff lands on the target ally, slot decremented,
##     USE_ITEM token spent, unit_item_used emitted, buff goes to TARGET (not caster)
##   - reject paths: no ally at tile / enemy at tile / self / out of range /
##     default sentinel / target at max HP (aid) → no side effects, slot intact
##   - get_item_target_tiles ALLY filter: only alive, same-side, NON-self,
##     in-range allies appear in the overlay set
##
## Mirrors grid_battle_controller_use_item_test.gd setup pattern.
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
	unit.unit_class = 0  # CAVALRY (class irrelevant — ALLY items have no class gate)
	unit.position = pos
	unit.side = side
	unit.attack_range = 1
	unit.move_range = 3
	unit.raw_atk = 50
	unit.raw_def = 20
	unit.inventory = []  # callers set per-test
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


# ─── aid_potion (구호약) — cross-hero immediate heal ──────────────────────────


## Happy path: caster heals a wounded ally one tile away. apply_heal targets the
## ALLY (not caster), raw_heal = AID_POTION_AMOUNT (20); slot decremented;
## USE_ITEM token spent; unit_item_used emitted with effect = 20.
func test_use_item_aid_potion_heals_ally_in_range() -> void:
	# Arrange — caster(1) at (2,2), wounded ally(2) at (3,2) (Manhattan 1)
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.inventory = [&"aid_potion", &"", &""]
	var ally: BattleUnit = _make_unit(2, Vector2i(3, 2), 0)
	var bag: Dictionary = _setup([caster, ally] as Array[BattleUnit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	var turn_stub: TurnOrderRunnerStub = bag["turn_runner"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 100)
	hp_stub.set_test_max_hp(2, 100)
	hp_stub.set_test_current_hp(2, 70)  # wounded ally
	controller._active_turn_unit_id = 1

	var emitted: Array = []
	controller.unit_item_used.connect(func(uid: int, item_id: StringName, slot_idx: int, effect: int) -> void:
		emitted.append({"uid": uid, "item": item_id, "slot": slot_idx, "effect": effect})
	)

	# Act — target the ally's tile (3,2)
	var fired: bool = controller.use_item(1, 0, Vector2i(3, 2))

	# Assert
	assert_bool(fired).override_failure_message(
		"aid_potion targeting a wounded ally in range must fire"
	).is_true()
	# apply_heal landed on the ALLY (unit_id 2), not the caster
	assert_int(hp_stub.apply_heal_calls.size()).is_equal(1)
	assert_int(hp_stub.apply_heal_calls[0]["unit_id"] as int).override_failure_message(
		"aid_potion must heal the TARGET ally (unit 2), not the caster"
	).is_equal(2)
	assert_int(hp_stub.apply_heal_calls[0]["raw_heal"] as int).override_failure_message(
		"aid_potion raw_heal must equal AID_POTION_AMOUNT (20)"
	).is_equal(20)
	assert_int(hp_stub.apply_heal_calls[0]["source_unit_id"] as int).is_equal(1)
	# Slot decremented
	assert_str(String(controller._units[1].inventory[0])).is_equal("")
	# USE_ITEM token spent
	assert_int(turn_stub.declared_actions.size()).is_equal(1)
	assert_int(turn_stub.declared_actions[0]["action"] as int).is_equal(
		TurnOrderRunner.ActionType.USE_ITEM as int
	)
	# Signal emit with effect = 20
	assert_int(emitted.size()).is_equal(1)
	assert_str(String(emitted[0]["item"] as StringName)).is_equal("aid_potion")
	assert_int(emitted[0]["effect"] as int).is_equal(20)


## Reject: no ally at the target tile (empty tile). No heal, slot intact, token
## unspent.
func test_use_item_aid_potion_no_ally_at_target_rejected() -> void:
	# Arrange
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.inventory = [&"aid_potion", &"", &""]
	var bag: Dictionary = _setup([caster])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	var turn_stub: TurnOrderRunnerStub = bag["turn_runner"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 100)
	controller._active_turn_unit_id = 1

	# Act — target an empty in-range tile (3,2)
	var fired: bool = controller.use_item(1, 0, Vector2i(3, 2))

	# Assert
	assert_bool(fired).override_failure_message(
		"aid_potion on an empty tile (no ally) must reject"
	).is_false()
	assert_int(hp_stub.apply_heal_calls.size()).is_equal(0)
	assert_str(String(controller._units[1].inventory[0])).is_equal("aid_potion")
	assert_int(turn_stub.declared_actions.size()).is_equal(0)


## Reject: caster targets its OWN tile. ALLY items exclude self — heal_potion
## owns self-heal. No heal, slot intact.
func test_use_item_aid_potion_self_target_rejected() -> void:
	# Arrange
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.inventory = [&"aid_potion", &"", &""]
	var bag: Dictionary = _setup([caster])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 50)  # wounded — but still cannot self-target
	controller._active_turn_unit_id = 1

	# Act — target caster's own tile (2,2)
	var fired: bool = controller.use_item(1, 0, Vector2i(2, 2))

	# Assert
	assert_bool(fired).override_failure_message(
		"aid_potion must reject self-target (cross-hero only; use heal_potion for self)"
	).is_false()
	assert_int(hp_stub.apply_heal_calls.size()).is_equal(0)
	assert_str(String(controller._units[1].inventory[0])).is_equal("aid_potion")


## Reject: ally exists but is beyond ALLY_SUPPORT_RANGE (Manhattan 3). No heal.
func test_use_item_aid_potion_ally_out_of_range_rejected() -> void:
	# Arrange — caster(1) at (2,2), ally(2) at (6,2) (Manhattan 4 — out of reach)
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.inventory = [&"aid_potion", &"", &""]
	var ally: BattleUnit = _make_unit(2, Vector2i(6, 2), 0)
	var bag: Dictionary = _setup([caster, ally] as Array[BattleUnit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(2, 100)
	hp_stub.set_test_current_hp(2, 50)
	controller._active_turn_unit_id = 1

	# Act — target the out-of-range ally tile (6,2)
	var fired: bool = controller.use_item(1, 0, Vector2i(6, 2))

	# Assert
	assert_bool(fired).override_failure_message(
		"aid_potion on an ally beyond Manhattan ALLY_SUPPORT_RANGE (3) must reject"
	).is_false()
	assert_int(hp_stub.apply_heal_calls.size()).is_equal(0)
	assert_str(String(controller._units[1].inventory[0])).is_equal("aid_potion")


## Reject: target tile holds an ENEMY (different side). ALLY items only reach
## same-side units.
func test_use_item_aid_potion_enemy_at_target_rejected() -> void:
	# Arrange — caster(1) at (2,2), enemy(2) at (3,2)
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.inventory = [&"aid_potion", &"", &""]
	var enemy: BattleUnit = _make_unit(2, Vector2i(3, 2), 1)
	var bag: Dictionary = _setup([caster, enemy] as Array[BattleUnit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(2, 100)
	hp_stub.set_test_current_hp(2, 50)
	controller._active_turn_unit_id = 1

	# Act
	var fired: bool = controller.use_item(1, 0, Vector2i(3, 2))

	# Assert
	assert_bool(fired).override_failure_message(
		"aid_potion on an enemy-occupied tile must reject (same-side only)"
	).is_false()
	assert_int(hp_stub.apply_heal_calls.size()).is_equal(0)


## Reject: ally already at max HP — mirrors heal_potion's at-max reject; slot
## not consumed.
func test_use_item_aid_potion_ally_at_max_hp_rejected_slot_intact() -> void:
	# Arrange
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.inventory = [&"aid_potion", &"", &""]
	var ally: BattleUnit = _make_unit(2, Vector2i(3, 2), 0)
	var bag: Dictionary = _setup([caster, ally] as Array[BattleUnit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(2, 100)
	hp_stub.set_test_current_hp(2, 100)  # ally at full HP
	controller._active_turn_unit_id = 1

	# Act
	var fired: bool = controller.use_item(1, 0, Vector2i(3, 2))

	# Assert
	assert_bool(fired).override_failure_message(
		"aid_potion on a full-HP ally must reject (no waste — slot intact)"
	).is_false()
	assert_int(hp_stub.apply_heal_calls.size()).is_equal(0)
	assert_str(String(controller._units[1].inventory[0])).is_equal("aid_potion")


## Reject: default sentinel target_pos (-1,-1) — ALLY items require an explicit
## target tile, so the I/slot self-cast path (no coord) rejects.
func test_use_item_aid_potion_default_sentinel_target_rejected() -> void:
	# Arrange — ally present and in range, but no target_pos passed
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.inventory = [&"aid_potion", &"", &""]
	var ally: BattleUnit = _make_unit(2, Vector2i(3, 2), 0)
	var bag: Dictionary = _setup([caster, ally] as Array[BattleUnit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(2, 100)
	hp_stub.set_test_current_hp(2, 50)
	controller._active_turn_unit_id = 1

	# Act — no target_pos → default Vector2i(-1, -1)
	var fired: bool = controller.use_item(1, 0)

	# Assert
	assert_bool(fired).override_failure_message(
		"aid_potion without an explicit target tile must reject (ALLY requires target)"
	).is_false()
	assert_int(hp_stub.apply_heal_calls.size()).is_equal(0)
	assert_str(String(controller._units[1].inventory[0])).is_equal("aid_potion")


# ─── rally_scroll (독려권) — cross-hero next-attack buff ──────────────────────


## Happy path: caster rallies an ally in range. The pending_buff lands on the
## TARGET ally (kind=strength, magnitude=RALLY_SCROLL_MULT 1.30, expires=round+1);
## the caster's own pending_buff stays empty; slot decremented; USE_ITEM token
## spent; unit_pending_buff_changed emitted for the TARGET.
func test_use_item_rally_scroll_buffs_ally_in_range() -> void:
	# Arrange — caster(1) at (2,2), ally(2) at (3,2)
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.inventory = [&"rally_scroll", &"", &""]
	var ally: BattleUnit = _make_unit(2, Vector2i(3, 2), 0)
	var bag: Dictionary = _setup([caster, ally] as Array[BattleUnit])
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
	var buff_emitted: Array = []
	controller.unit_pending_buff_changed.connect(func(uid: int, has_buff: bool) -> void:
		buff_emitted.append({"uid": uid, "has_buff": has_buff})
	)

	# Act — target the ally's tile (3,2)
	var fired: bool = controller.use_item(1, 0, Vector2i(3, 2))

	# Assert
	assert_bool(fired).override_failure_message(
		"rally_scroll targeting an ally in range must fire"
	).is_true()
	# Buff landed on the TARGET ally (unit 2)
	var ally_pb: Dictionary = controller._units[2].pending_buff
	assert_bool(ally_pb.is_empty()).override_failure_message(
		"rally_scroll must set the TARGET ally's pending_buff"
	).is_false()
	assert_str(String(ally_pb.get(&"kind", &"") as StringName)).is_equal("strength")
	assert_float(ally_pb.get(&"magnitude", 0.0) as float).override_failure_message(
		"rally_scroll magnitude must be RALLY_SCROLL_MULT (1.30)"
	).is_equal_approx(1.30, 0.001)
	# expires_at_turn = current_round + 1 (same carry semantics as strength_scroll).
	# Stub defaults to round 0 (production cold-start), so derive rather than hardcode.
	var expected_expiry: int = (turn_stub.get_current_round_number() as int) + 1
	assert_int(ally_pb.get(&"expires_at_turn", 0) as int).override_failure_message(
		"rally_scroll expires_at_turn must equal current_round + 1"
	).is_equal(expected_expiry)
	# The CASTER's own buff must stay empty (buff goes to ally, not self)
	assert_bool(controller._units[1].pending_buff.is_empty()).override_failure_message(
		"rally_scroll must NOT buff the caster — cross-hero only"
	).is_true()
	# Slot decremented + USE_ITEM token spent
	assert_str(String(controller._units[1].inventory[0])).is_equal("")
	assert_int(turn_stub.declared_actions.size()).is_equal(1)
	assert_int(turn_stub.declared_actions[0]["action"] as int).is_equal(
		TurnOrderRunner.ActionType.USE_ITEM as int
	)
	# unit_item_used + unit_pending_buff_changed(TARGET, true)
	assert_int(item_emitted.size()).is_equal(1)
	assert_str(String(item_emitted[0]["item"] as StringName)).is_equal("rally_scroll")
	assert_int(buff_emitted.size()).is_equal(1)
	assert_int(buff_emitted[0]["uid"] as int).override_failure_message(
		"unit_pending_buff_changed must fire for the TARGET ally (unit 2)"
	).is_equal(2)
	assert_bool(buff_emitted[0]["has_buff"] as bool).is_true()


## Reject: no ally at the target tile. No buff, slot intact, token unspent.
func test_use_item_rally_scroll_no_ally_at_target_rejected() -> void:
	# Arrange
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.inventory = [&"rally_scroll", &"", &""]
	var bag: Dictionary = _setup([caster])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	var turn_stub: TurnOrderRunnerStub = bag["turn_runner"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 100)
	controller._active_turn_unit_id = 1

	# Act
	var fired: bool = controller.use_item(1, 0, Vector2i(3, 2))

	# Assert
	assert_bool(fired).override_failure_message(
		"rally_scroll on an empty tile must reject"
	).is_false()
	assert_str(String(controller._units[1].inventory[0])).is_equal("rally_scroll")
	assert_int(turn_stub.declared_actions.size()).is_equal(0)


## Reject: caster targets its OWN tile. ALLY buff excludes self (strength_scroll
## owns self-buff).
func test_use_item_rally_scroll_self_target_rejected() -> void:
	# Arrange
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.inventory = [&"rally_scroll", &"", &""]
	var bag: Dictionary = _setup([caster])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_test_max_hp(1, 100)
	hp_stub.set_test_current_hp(1, 100)
	controller._active_turn_unit_id = 1

	# Act — target caster's own tile
	var fired: bool = controller.use_item(1, 0, Vector2i(2, 2))

	# Assert
	assert_bool(fired).override_failure_message(
		"rally_scroll must reject self-target (use strength_scroll for self)"
	).is_false()
	assert_bool(controller._units[1].pending_buff.is_empty()).is_true()
	assert_str(String(controller._units[1].inventory[0])).is_equal("rally_scroll")


## Reject: target ally is dead — revive is a separate Phase C+ item, not rally.
func test_use_item_rally_scroll_dead_ally_rejected() -> void:
	# Arrange — ally present at target tile but marked dead
	var caster: BattleUnit = _make_unit(1, Vector2i(2, 2), 0)
	caster.inventory = [&"rally_scroll", &"", &""]
	var ally: BattleUnit = _make_unit(2, Vector2i(3, 2), 0)
	var bag: Dictionary = _setup([caster, ally] as Array[BattleUnit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_alive_for_test(2, false)  # dead ally
	controller._active_turn_unit_id = 1

	# Act
	var fired: bool = controller.use_item(1, 0, Vector2i(3, 2))

	# Assert
	assert_bool(fired).override_failure_message(
		"rally_scroll on a dead ally must reject (revive is Phase C+, not rally)"
	).is_false()
	assert_bool(controller._units[2].pending_buff.is_empty()).is_true()
	assert_str(String(controller._units[1].inventory[0])).is_equal("rally_scroll")


# ─── get_item_target_tiles — ALLY overlay filter ─────────────────────────────


## aid_potion overlay returns only tiles occupied by alive, same-side, NON-self
## allies within ALLY_SUPPORT_RANGE. Self / enemy / out-of-range / dead excluded.
func test_get_item_target_tiles_aid_potion_filters_to_reachable_allies() -> void:
	# Arrange — caster(1) at (4,4)
	#   ally(2) at (5,4)  — Manhattan 1, alive, same side → INCLUDED
	#   ally(3) at (0,4)  — Manhattan 4, out of range → excluded
	#   enemy(4) at (4,5) — same distance but enemy → excluded
	#   ally(5) at (4,3)  — Manhattan 1 but DEAD → excluded
	var caster: BattleUnit = _make_unit(1, Vector2i(4, 4), 0)
	var ally_in: BattleUnit = _make_unit(2, Vector2i(5, 4), 0)
	var ally_far: BattleUnit = _make_unit(3, Vector2i(0, 4), 0)
	var enemy: BattleUnit = _make_unit(4, Vector2i(4, 5), 1)
	var ally_dead: BattleUnit = _make_unit(5, Vector2i(4, 3), 0)
	var bag: Dictionary = _setup([caster, ally_in, ally_far, enemy, ally_dead] as Array[BattleUnit])
	var controller: GridBattleController = bag["controller"]
	var hp_stub: HPStatusControllerStub = bag["hp_controller"]
	hp_stub.set_alive_for_test(5, false)  # dead ally excluded

	# Act
	var tiles: PackedVector2Array = controller.get_item_target_tiles(1, &"aid_potion")

	# Assert — exactly one reachable ally tile (5,4)
	assert_int(tiles.size()).override_failure_message(
		"aid_potion overlay must include ONLY the 1 reachable living ally tile; got %d" % tiles.size()
	).is_equal(1)
	assert_bool(Vector2(5, 4) in tiles).override_failure_message(
		"aid_potion overlay must contain the in-range living ally tile (5,4)"
	).is_true()
	# Self tile NOT included
	assert_bool(Vector2(4, 4) in tiles).override_failure_message(
		"aid_potion overlay must NOT include the caster's own tile"
	).is_false()


## rally_scroll overlay uses the same ALLY filter as aid_potion.
func test_get_item_target_tiles_rally_scroll_filters_to_reachable_allies() -> void:
	# Arrange — caster(1) at (4,4), one in-range ally(2) at (3,4), one enemy(3) at (5,4)
	var caster: BattleUnit = _make_unit(1, Vector2i(4, 4), 0)
	var ally_in: BattleUnit = _make_unit(2, Vector2i(3, 4), 0)
	var enemy: BattleUnit = _make_unit(3, Vector2i(5, 4), 1)
	var bag: Dictionary = _setup([caster, ally_in, enemy] as Array[BattleUnit])
	var controller: GridBattleController = bag["controller"]

	# Act
	var tiles: PackedVector2Array = controller.get_item_target_tiles(1, &"rally_scroll")

	# Assert — only the ally tile (3,4); enemy tile (5,4) excluded
	assert_int(tiles.size()).override_failure_message(
		"rally_scroll overlay must include only the 1 reachable ally tile; got %d" % tiles.size()
	).is_equal(1)
	assert_bool(Vector2(3, 4) in tiles).is_true()
	assert_bool(Vector2(5, 4) in tiles).override_failure_message(
		"rally_scroll overlay must NOT include the enemy tile (5,4)"
	).is_false()


## No reachable ally → empty overlay (player can cancel; no crash).
func test_get_item_target_tiles_ally_item_empty_when_no_reachable_ally() -> void:
	# Arrange — lone caster, no allies
	var caster: BattleUnit = _make_unit(1, Vector2i(4, 4), 0)
	var bag: Dictionary = _setup([caster])
	var controller: GridBattleController = bag["controller"]

	# Act
	var aid_tiles: PackedVector2Array = controller.get_item_target_tiles(1, &"aid_potion")
	var rally_tiles: PackedVector2Array = controller.get_item_target_tiles(1, &"rally_scroll")

	# Assert
	assert_int(aid_tiles.size()).override_failure_message(
		"aid_potion overlay must be empty when no reachable ally exists"
	).is_equal(0)
	assert_int(rally_tiles.size()).is_equal(0)
