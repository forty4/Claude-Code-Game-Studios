## battle_scene_unit_class_propagation_test.gd
##
## Verifies that BattleScene._make_battle_unit + _build_battle_units_from_chapter
## populate `BattleUnit.unit_class` from the corresponding HeroData.default_class
## (rather than leaving it at the BattleUnit zero default = CAVALRY, which made
## every spawned unit render as a triangle).
##
## Sibling to battle_scene_archetype_propagation_test.gd — same helper-call
## pattern, different field. Heroes referenced live in assets/data/heroes/heroes.json
## (consumed by the production /root/HeroDatabase autoload at boot).
extends GdUnitTestSuite

const BattleSceneScript: GDScript = preload("res://src/feature/battle_scene/battle_scene.gd")


func _instantiate_battle_scene() -> BattleScene:
	# Same pattern as the archetype test: instantiate without adding to tree —
	# the helpers exercised here are pure-data and don't touch scene-tree nodes.
	var scene: BattleScene = BattleSceneScript.new()
	auto_free(scene)
	return scene


func _make_test_chapter(player_uids: PackedInt64Array, enemy_roster: Array[Dictionary]) -> ChapterDefinition:
	var chapter: ChapterDefinition = ChapterDefinition.new()
	chapter.player_unit_ids = player_uids
	chapter.deployment_positions_default = {}
	chapter.enemy_roster = enemy_roster
	return chapter


# ─── _make_battle_unit ────────────────────────────────────────────────────────


func test_make_battle_unit_picks_default_class_from_hero_database() -> void:
	# 유비 default_class = 4 (COMMANDER).
	var scene: BattleScene = _instantiate_battle_scene()
	var unit: BattleUnit = scene._make_battle_unit(0, &"shu_001_liu_bei", true, Vector2i(1, 3), &"tank", &"aggressor")
	assert_int(unit.unit_class).override_failure_message(
		"유비 should resolve to COMMANDER (4); got %d (likely the BattleUnit default 0 = CAVALRY)" % unit.unit_class
	).is_equal(int(UnitRole.UnitClass.COMMANDER))


func test_make_battle_unit_infantry_for_zhang_fei() -> void:
	# 장비 default_class = 1 (INFANTRY).
	var scene: BattleScene = _instantiate_battle_scene()
	var unit: BattleUnit = scene._make_battle_unit(1, &"shu_003_zhang_fei", true, Vector2i(2, 3), &"assassin", &"aggressor")
	assert_int(unit.unit_class).is_equal(int(UnitRole.UnitClass.INFANTRY))


func test_make_battle_unit_strategist_for_zhang_liao() -> void:
	# 장료 default_class = 3 (STRATEGIST).
	var scene: BattleScene = _instantiate_battle_scene()
	var unit: BattleUnit = scene._make_battle_unit(3, &"wei_006_zhang_liao", false, Vector2i(5, 2), &"skirmisher", &"skirmisher")
	assert_int(unit.unit_class).is_equal(int(UnitRole.UnitClass.STRATEGIST))


func test_make_battle_unit_archer_for_yu_jin() -> void:
	# 우금 default_class = 2 (ARCHER).
	var scene: BattleScene = _instantiate_battle_scene()
	var unit: BattleUnit = scene._make_battle_unit(4, &"wei_007_yu_jin", false, Vector2i(5, 4), &"holder", &"holder")
	assert_int(unit.unit_class).is_equal(int(UnitRole.UnitClass.ARCHER))


func test_make_battle_unit_falls_back_to_infantry_when_hero_unknown() -> void:
	# Unknown hero_id → HeroDatabase.get_hero returns null → INFANTRY (1) fallback.
	var scene: BattleScene = _instantiate_battle_scene()
	var unit: BattleUnit = scene._make_battle_unit(99, &"shu_999_phantom", true, Vector2i.ZERO, &"", &"aggressor")
	assert_int(unit.unit_class).is_equal(int(UnitRole.UnitClass.INFANTRY))


# ─── _build_battle_units_from_chapter ─────────────────────────────────────────


func test_build_battle_units_propagates_class_for_full_chapter_1_roster() -> void:
	# Mirrors mvp_shu.json chapter 1: player 유비+장비 + 4 Wei generals across
	# all four AI archetypes.
	var scene: BattleScene = _instantiate_battle_scene()
	var chapter: ChapterDefinition = _make_test_chapter(
		PackedInt64Array([0, 1]),
		[
			{"unit_id": 2, "hero_id": "wei_005_xiahou_dun", "archetype": "aggressor"},
			{"unit_id": 3, "hero_id": "wei_006_zhang_liao", "archetype": "skirmisher"},
			{"unit_id": 4, "hero_id": "wei_007_yu_jin",     "archetype": "holder"},
			{"unit_id": 5, "hero_id": "wei_008_xu_chu",     "archetype": "coordinator"},
		],
	)

	var built: Array[BattleUnit] = scene._build_battle_units_from_chapter(chapter)

	# Expected per heroes.json default_class fields:
	var expected: Dictionary = {
		0: int(UnitRole.UnitClass.COMMANDER),  # 유비
		1: int(UnitRole.UnitClass.INFANTRY),   # 장비
		2: int(UnitRole.UnitClass.INFANTRY),   # 하후돈
		3: int(UnitRole.UnitClass.STRATEGIST), # 장료
		4: int(UnitRole.UnitClass.ARCHER),     # 우금
		5: int(UnitRole.UnitClass.COMMANDER),  # 허저
	}
	for unit: BattleUnit in built:
		var want: int = expected.get(unit.unit_id, -1) as int
		assert_int(unit.unit_class).override_failure_message(
			"unit_id %d (%s): expected class %d, got %d"
			% [unit.unit_id, String(unit.hero_id), want, unit.unit_class]
		).is_equal(want)


func test_build_battle_units_yields_at_least_three_distinct_classes_for_chapter_1() -> void:
	# Sanity: the chapter-1 roster covers enough class variety that the visuals
	# differentiate. Today's roster uses 4 distinct classes (commander, infantry,
	# strategist, archer); regress if someone drops it below 3.
	var scene: BattleScene = _instantiate_battle_scene()
	var chapter: ChapterDefinition = _make_test_chapter(
		PackedInt64Array([0, 1]),
		[
			{"unit_id": 2, "hero_id": "wei_005_xiahou_dun", "archetype": "aggressor"},
			{"unit_id": 3, "hero_id": "wei_006_zhang_liao", "archetype": "skirmisher"},
			{"unit_id": 4, "hero_id": "wei_007_yu_jin",     "archetype": "holder"},
			{"unit_id": 5, "hero_id": "wei_008_xu_chu",     "archetype": "coordinator"},
		],
	)

	var built: Array[BattleUnit] = scene._build_battle_units_from_chapter(chapter)
	var classes: Dictionary = {}
	for unit: BattleUnit in built:
		classes[unit.unit_class] = true
	assert_int(classes.size()).override_failure_message(
		"chapter 1 roster yields only %d distinct classes — visual differentiation regressed"
		% classes.size()
	).is_greater_equal(3)
