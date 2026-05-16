## battle_scene_hero_id_override_test.gd
##
## Exercises BattleScene._resolve_player_hero_id_with_override — the per-prior-
## branch hero swap-in that surfaces branch_overrides on the actual grid. This
## is the wiring that makes ch02 WIN_changbanpo_lord_unharmed actually deploy
## 관우 (and LOSS_changbanpo_retreat actually deploy 장비-alone) instead of
## reading the chapter's default player_hero_ids verbatim.
extends GdUnitTestSuite

const BattleSceneScript: GDScript = preload("res://src/feature/battle_scene/battle_scene.gd")


func _instantiate_battle_scene() -> BattleScene:
	var scene: BattleScene = BattleSceneScript.new()
	auto_free(scene)
	return scene


func _make_chapter_with_heroes(player_hero_ids: Dictionary) -> ChapterDefinition:
	var chapter: ChapterDefinition = ChapterDefinition.new()
	chapter.player_unit_ids = PackedInt64Array([0, 1])
	chapter.player_hero_ids = player_hero_ids
	return chapter


# ─── Override wins over chapter ───────────────────────────────────────────────


func test_override_hero_id_supersedes_chapter_hero_id_for_same_uid() -> void:
	# Arrange — chapter says uid=0 is Liu Bei; override says Zhang Fei.
	var scene: BattleScene = _instantiate_battle_scene()
	var chapter: ChapterDefinition = _make_chapter_with_heroes(
		{0: "shu_001_liu_bei", 1: "shu_003_zhang_fei"}
	)
	var override_heroes: Dictionary = {0: "shu_003_zhang_fei"}
	# Act
	var hero: StringName = scene._resolve_player_hero_id_with_override(
		chapter, 0, override_heroes
	)
	# Assert
	assert_str(String(hero)).is_equal("shu_003_zhang_fei")


func test_override_adds_hero_for_uid_not_in_chapter_default() -> void:
	# This is the ch02 WIN_changbanpo_lord_unharmed shape: chapter default
	# doesn't include uid=6, but the override does → 관우 surfaces.
	var scene: BattleScene = _instantiate_battle_scene()
	var chapter: ChapterDefinition = _make_chapter_with_heroes(
		{0: "shu_001_liu_bei", 1: "shu_003_zhang_fei"}
	)
	var override_heroes: Dictionary = {6: "shu_002_guan_yu"}
	var hero: StringName = scene._resolve_player_hero_id_with_override(
		chapter, 6, override_heroes
	)
	assert_str(String(hero)).is_equal("shu_002_guan_yu")


# ─── Override falls through to chapter when no entry ──────────────────────────


func test_override_without_uid_falls_through_to_chapter_hero_id() -> void:
	var scene: BattleScene = _instantiate_battle_scene()
	var chapter: ChapterDefinition = _make_chapter_with_heroes(
		{0: "shu_001_liu_bei", 1: "shu_003_zhang_fei"}
	)
	var override_heroes: Dictionary = {6: "shu_002_guan_yu"}  # not uid=0
	var hero: StringName = scene._resolve_player_hero_id_with_override(
		chapter, 0, override_heroes
	)
	assert_str(String(hero)).is_equal("shu_001_liu_bei")


func test_empty_override_falls_through_to_chapter_hero_id() -> void:
	var scene: BattleScene = _instantiate_battle_scene()
	var chapter: ChapterDefinition = _make_chapter_with_heroes(
		{0: "shu_001_liu_bei"}
	)
	var hero: StringName = scene._resolve_player_hero_id_with_override(
		chapter, 0, {}
	)
	assert_str(String(hero)).is_equal("shu_001_liu_bei")


# ─── Override with empty-string value falls through (defensive) ───────────────


func test_override_with_empty_hero_string_falls_through() -> void:
	var scene: BattleScene = _instantiate_battle_scene()
	var chapter: ChapterDefinition = _make_chapter_with_heroes(
		{0: "shu_001_liu_bei"}
	)
	var override_heroes: Dictionary = {0: ""}  # malformed JSON authoring
	var hero: StringName = scene._resolve_player_hero_id_with_override(
		chapter, 0, override_heroes
	)
	assert_str(String(hero)).is_equal("shu_001_liu_bei")


# ─── Back-compat: _resolve_player_hero_id (no override) still routes correctly


func test_resolve_player_hero_id_back_compat_path_unchanged() -> void:
	# The original public-shaped method should behave as before when override
	# is not threaded through (legacy callers + tests).
	var scene: BattleScene = _instantiate_battle_scene()
	var chapter: ChapterDefinition = _make_chapter_with_heroes(
		{6: "shu_002_guan_yu"}
	)
	var hero: StringName = scene._resolve_player_hero_id(chapter, 6)
	assert_str(String(hero)).is_equal("shu_002_guan_yu")
