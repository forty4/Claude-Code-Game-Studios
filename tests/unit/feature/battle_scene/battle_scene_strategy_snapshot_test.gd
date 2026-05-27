## battle_scene_strategy_snapshot_test.gd
##
## S91 Phase B step 8b follow-up — exercises BattleScene's get + apply per-unit
## Strategy Systems snapshot helpers, the data-pull/-restore boundary that
## ScenarioRunner consumes for SaveContext.per_hero_inventory_snapshot +
## per_hero_pending_buff_snapshot population. Strategy Systems v0.3 §3.3 +
## EC-SS-9 round-trip.
##
## Mirrors battle_scene_starting_inventory_test.gd pattern — direct instance
## method call on BattleSceneScript.new() without booting the full scene. A
## GridBattleControllerStub is injected so `_units` is populated for the
## snapshot helpers to read/write.
extends GdUnitTestSuite

const BattleSceneScript: GDScript = preload("res://src/feature/battle_scene/battle_scene.gd")
const GridBattleControllerStubScript: GDScript = preload("res://tests/helpers/grid_battle_controller_stub.gd")


func _instantiate_battle_scene() -> BattleScene:
	var scene: BattleScene = BattleSceneScript.new()
	auto_free(scene)
	return scene


func _make_unit(unit_id: int, side: int, inv: Array[StringName], buff: Dictionary) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.hero_id = StringName("test_hero_%d" % unit_id)
	unit.side = side
	unit.inventory = inv
	unit.pending_buff = buff
	return unit


## Inject a stub controller with a `_units` Dictionary so the snapshot helpers
## have data to read/write. Stub extends GridBattleController and exposes the
## protected `_units` field for direct write access.
func _attach_controller_with_units(scene: BattleScene, units: Array[BattleUnit]) -> GridBattleControllerStub:
	var stub: GridBattleControllerStub = GridBattleControllerStubScript.new()
	auto_free(stub)
	for unit: BattleUnit in units:
		stub._units[unit.unit_id] = unit
	scene._grid_controller = stub
	return stub


# ─── get_per_unit_strategy_snapshot ──────────────────────────────────────────


## Snapshot collects non-empty inventories + pending_buffs from PLAYER units only.
## Enemy units (side != 0) are excluded; empty inventories are omitted from the
## output (minimum-row policy matching the "no permanent accumulation" rule).
func test_get_per_unit_strategy_snapshot_collects_player_state_only() -> void:
	var scene: BattleScene = _instantiate_battle_scene()
	var p1: BattleUnit = _make_unit(1, 0, [&"heal_potion", &"fire_scroll", &""] as Array[StringName], {})
	var p2: BattleUnit = _make_unit(2, 0, [&"", &"", &""] as Array[StringName], {
		&"kind": &"strength",
		&"magnitude": 1.5,
		&"expires_at_turn": 3,
	})
	var enemy: BattleUnit = _make_unit(3, 1, [&"heal_potion", &"", &""] as Array[StringName], {})
	_attach_controller_with_units(scene, [p1, p2, enemy])

	var snapshot: Dictionary = scene.get_per_unit_strategy_snapshot()

	# Inventory: p1 (has heal_potion + fire_scroll) included; p2 (all empty)
	# omitted; enemy excluded entirely.
	var inv_dict: Dictionary = snapshot["inventory"] as Dictionary
	assert_int(inv_dict.size()).override_failure_message(
		"step 8b: snapshot inventory dict must contain ONLY units with non-empty inventory + side=0"
	).is_equal(1)
	assert_bool(inv_dict.has(1)).is_true()
	assert_bool(inv_dict.has(2)).override_failure_message(
		"step 8b: unit with all-empty inventory must NOT appear in snapshot"
	).is_false()
	assert_bool(inv_dict.has(3)).override_failure_message(
		"step 8b: enemy unit (side=1) must NOT appear in snapshot"
	).is_false()
	# Pending buff: p2 included; p1 (no buff) omitted; enemy excluded.
	var buff_dict: Dictionary = snapshot["pending_buff"] as Dictionary
	assert_int(buff_dict.size()).is_equal(1)
	assert_bool(buff_dict.has(2)).is_true()


## Returns empty sub-dicts when no grid controller is attached — defensive
## against early-call before BattleScene STEP 1 wiring + against test paths
## that bypass the grid_controller.
func test_get_per_unit_strategy_snapshot_empty_when_no_controller() -> void:
	var scene: BattleScene = _instantiate_battle_scene()
	# scene._grid_controller is null at this point — never attached.

	var snapshot: Dictionary = scene.get_per_unit_strategy_snapshot()

	assert_bool((snapshot["inventory"] as Dictionary).is_empty()).is_true()
	assert_bool((snapshot["pending_buff"] as Dictionary).is_empty()).is_true()


## Snapshot inventory is a COPY (not alias) — mutating the snapshot must NOT
## leak back into the unit. Mirrors the _apply_starting_inventory isolation
## guarantee (chapter resource doesn't get corrupted by per-battle mutations).
func test_get_per_unit_strategy_snapshot_returns_inventory_copy_not_alias() -> void:
	var scene: BattleScene = _instantiate_battle_scene()
	var p1: BattleUnit = _make_unit(1, 0, [&"heal_potion", &"", &""] as Array[StringName], {})
	_attach_controller_with_units(scene, [p1])

	var snapshot: Dictionary = scene.get_per_unit_strategy_snapshot()
	var snap_inv: Array = (snapshot["inventory"] as Dictionary)[1] as Array
	# Mutate the snapshot
	snap_inv[0] = &"mutated"

	# Original unit unchanged
	assert_str(String(p1.inventory[0])).override_failure_message(
		"step 8b: snapshot inventory must be a COPY — mutation must not leak back"
	).is_equal("heal_potion")


# ─── apply_per_unit_strategy_snapshot ────────────────────────────────────────


## Snapshot applies cleanly: snapshot's inventory + pending_buff overrides
## current unit state. This is the future mid-battle save resume entry point.
func test_apply_per_unit_strategy_snapshot_overrides_current_unit_state() -> void:
	var scene: BattleScene = _instantiate_battle_scene()
	var p1: BattleUnit = _make_unit(1, 0, [&"heal_potion", &"", &""] as Array[StringName], {})
	_attach_controller_with_units(scene, [p1])

	# Snapshot to apply
	var inv_snapshot: Dictionary = {
		1: [&"strength_scroll", &"fire_scroll", &""] as Array[StringName],
	}
	var buff_snapshot: Dictionary = {
		1: {
			&"kind": &"strength",
			&"magnitude": 1.5,
			&"expires_at_turn": 5,
		},
	}

	scene.apply_per_unit_strategy_snapshot(inv_snapshot, buff_snapshot)

	# Inventory overridden
	assert_str(String(p1.inventory[0])).is_equal("strength_scroll")
	assert_str(String(p1.inventory[1])).is_equal("fire_scroll")
	# Pending buff applied
	assert_bool(p1.pending_buff.is_empty()).is_false()
	assert_float(p1.pending_buff.get(&"magnitude", 0.0) as float).is_equal_approx(1.5, 0.001)


## Snapshot entries for non-existent unit_ids are silently skipped (defensive
## against save loaded from a chapter with different roster — current battle
## just ignores the orphan entries).
func test_apply_per_unit_strategy_snapshot_skips_unknown_unit_ids() -> void:
	var scene: BattleScene = _instantiate_battle_scene()
	var p1: BattleUnit = _make_unit(1, 0, [&"heal_potion", &"", &""] as Array[StringName], {})
	_attach_controller_with_units(scene, [p1])

	# Snapshot for unit_id=999 which isn't in the current battle.
	var inv_snapshot: Dictionary = {
		999: [&"strength_scroll", &"", &""] as Array[StringName],
	}
	var buff_snapshot: Dictionary = {}

	scene.apply_per_unit_strategy_snapshot(inv_snapshot, buff_snapshot)

	# Existing unit's inventory unchanged
	assert_str(String(p1.inventory[0])).override_failure_message(
		"step 8b: snapshot entry for unknown unit_id must be silently skipped"
	).is_equal("heal_potion")


## Snapshot apply skips enemy units (side != 0) — mirrors get-side gate.
func test_apply_per_unit_strategy_snapshot_skips_enemy_units() -> void:
	var scene: BattleScene = _instantiate_battle_scene()
	var enemy: BattleUnit = _make_unit(1, 1, [&"", &"", &""] as Array[StringName], {})
	_attach_controller_with_units(scene, [enemy])

	# Snapshot attempts to assign inventory to enemy unit (defense in depth).
	var inv_snapshot: Dictionary = {
		1: [&"heal_potion", &"", &""] as Array[StringName],
	}

	scene.apply_per_unit_strategy_snapshot(inv_snapshot, {})

	# Enemy unit's inventory remains empty
	assert_bool(enemy.inventory.is_empty() or String(enemy.inventory[0]) == "").override_failure_message(
		"step 8b: apply must not write inventory onto enemy-side units"
	).is_true()


# ─── Round-trip integrity ────────────────────────────────────────────────────


## get → apply round-trip preserves player unit state byte-for-byte.
func test_get_then_apply_snapshot_preserves_state() -> void:
	var scene: BattleScene = _instantiate_battle_scene()
	var p1: BattleUnit = _make_unit(1, 0, [&"heal_potion", &"strength_scroll", &""] as Array[StringName], {
		&"kind": &"strength",
		&"magnitude": 1.5,
		&"expires_at_turn": 4,
	})
	_attach_controller_with_units(scene, [p1])

	# Capture snapshot
	var snapshot: Dictionary = scene.get_per_unit_strategy_snapshot()
	# Reset unit state to defaults
	p1.inventory = [] as Array[StringName]
	p1.pending_buff = {}
	# Apply the captured snapshot back
	scene.apply_per_unit_strategy_snapshot(snapshot["inventory"], snapshot["pending_buff"])

	# Verify round-trip
	assert_int(p1.inventory.size()).is_equal(3)
	assert_str(String(p1.inventory[0])).is_equal("heal_potion")
	assert_str(String(p1.inventory[1])).is_equal("strength_scroll")
	assert_str(String(p1.inventory[2])).is_equal("")
	assert_bool(p1.pending_buff.is_empty()).is_false()
	assert_float(p1.pending_buff.get(&"magnitude", 0.0) as float).is_equal_approx(1.5, 0.001)
