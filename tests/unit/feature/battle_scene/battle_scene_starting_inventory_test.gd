## battle_scene_starting_inventory_test.gd
##
## S91 Phase B step 8 — exercises BattleScene._apply_starting_inventory, the
## helper that copies the chapter-authored starting_inventory_by_hero entry
## onto a freshly-constructed player BattleUnit at battle init. Strategy
## Systems v0.3 §3.4 + AC-SS-2.
##
## Mirrors battle_scene_hero_id_override_test.gd pattern — direct instance
## method call on BattleSceneScript.new() without booting the full scene.
extends GdUnitTestSuite

const BattleSceneScript: GDScript = preload("res://src/feature/battle_scene/battle_scene.gd")


func _instantiate_battle_scene() -> BattleScene:
	var scene: BattleScene = BattleSceneScript.new()
	auto_free(scene)
	return scene


func _make_player_unit(hero_id: StringName) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = 0
	unit.hero_id = hero_id
	unit.side = 0
	unit.is_player_controlled = true
	# inventory starts at BattleUnit default ([]) — _apply must replace it.
	return unit


func _make_chapter_with_inventory(inv: Dictionary) -> ChapterDefinition:
	var chapter: ChapterDefinition = ChapterDefinition.new()
	chapter.starting_inventory_by_hero = inv
	return chapter


# ─── Happy path: hero entry present ──────────────────────────────────────────


## When chapter authored an inventory for this hero_id, the unit's inventory
## is replaced with a copy of the authored array.
func test_apply_starting_inventory_populates_unit_inventory_from_chapter() -> void:
	var scene: BattleScene = _instantiate_battle_scene()
	var unit: BattleUnit = _make_player_unit(&"shu_003_zhang_fei")
	var chapter: ChapterDefinition = _make_chapter_with_inventory({
		&"shu_003_zhang_fei": [&"heal_potion", &"strength_scroll", &""] as Array[StringName],
	})

	scene._apply_starting_inventory(unit, chapter)

	assert_int(unit.inventory.size()).override_failure_message(
		"AC-SS-2: authored inventory must populate all 3 slots"
	).is_equal(3)
	assert_str(String(unit.inventory[0])).is_equal("heal_potion")
	assert_str(String(unit.inventory[1])).is_equal("strength_scroll")
	assert_str(String(unit.inventory[2])).is_equal("")


# ─── No-op: hero not in chapter inventory map ─────────────────────────────────


## When the chapter authored inventory for OTHER heroes but not this unit,
## the unit's inventory is unchanged (stays at BattleUnit default = []).
func test_apply_starting_inventory_noop_when_hero_not_authored() -> void:
	var scene: BattleScene = _instantiate_battle_scene()
	var unit: BattleUnit = _make_player_unit(&"shu_002_guan_yu")
	# Authored chapter has 유비 + 장비 but NOT 관우.
	var chapter: ChapterDefinition = _make_chapter_with_inventory({
		&"shu_001_liu_bei":  [&"heal_potion", &"", &""] as Array[StringName],
		&"shu_003_zhang_fei": [&"strength_scroll", &"", &""] as Array[StringName],
	})

	scene._apply_starting_inventory(unit, chapter)

	assert_bool(unit.inventory.is_empty()).override_failure_message(
		"AC-SS-2: unit whose hero_id is not in chapter map must keep default empty inventory"
	).is_true()


# ─── No-op: chapter null defensive ─────────────────────────────────────────────


## Defensive guard — null chapter does not crash; unit inventory unchanged.
func test_apply_starting_inventory_noop_when_chapter_null() -> void:
	var scene: BattleScene = _instantiate_battle_scene()
	var unit: BattleUnit = _make_player_unit(&"shu_003_zhang_fei")

	scene._apply_starting_inventory(unit, null)

	assert_bool(unit.inventory.is_empty()).is_true()


# ─── No-op: empty inventory dictionary ─────────────────────────────────────────


## Chapter authored as `starting_inventory_by_hero = {}` (empty) → unit
## inventory stays at default empty. Common case for ch01-ch16 pre-Phase B
## chapters that never need starting items.
func test_apply_starting_inventory_noop_when_chapter_dict_empty() -> void:
	var scene: BattleScene = _instantiate_battle_scene()
	var unit: BattleUnit = _make_player_unit(&"shu_003_zhang_fei")
	var chapter: ChapterDefinition = ChapterDefinition.new()
	# chapter.starting_inventory_by_hero stays at field default = {}.

	scene._apply_starting_inventory(unit, chapter)

	assert_bool(unit.inventory.is_empty()).is_true()


# ─── Isolation: per-unit copy not aliased ──────────────────────────────────────


## A subsequent in-battle use_item slot-decrement on the unit's inventory must
## NOT leak back into the chapter resource's authored array (which would
## corrupt the per-run state if the battle is retried or saved+loaded).
func test_apply_starting_inventory_does_not_alias_chapter_array() -> void:
	var scene: BattleScene = _instantiate_battle_scene()
	var unit: BattleUnit = _make_player_unit(&"shu_003_zhang_fei")
	var authored: Array[StringName] = [&"heal_potion", &"strength_scroll", &""]
	var chapter: ChapterDefinition = _make_chapter_with_inventory({
		&"shu_003_zhang_fei": authored,
	})

	scene._apply_starting_inventory(unit, chapter)

	# Simulate a use_item slot decrement on the unit.
	unit.inventory[0] = &""

	# Chapter's authored array must be UNCHANGED.
	var still_authored: Array = chapter.starting_inventory_by_hero[&"shu_003_zhang_fei"] as Array
	assert_str(String(still_authored[0] as StringName)).override_failure_message(
		"AC-SS-2: per-unit inventory must be a copy (mutation must not leak back "
		+ "to chapter resource)"
	).is_equal("heal_potion")
