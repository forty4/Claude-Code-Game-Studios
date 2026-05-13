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


# ─── Data-driven player_hero_ids resolution ─────────────────────────────────


func test_player_hero_ids_chapter_field_takes_priority() -> void:
	# Chapter authors the mapping → used regardless of legacy const overlap.
	var scene: BattleScene = _instantiate_battle_scene()
	var chapter: ChapterDefinition = ChapterDefinition.new()
	chapter.player_unit_ids = PackedInt64Array([0, 1])
	chapter.player_hero_ids = {0: "shu_002_guan_yu", 1: "shu_001_liu_bei"}
	assert_str(String(scene._resolve_player_hero_id(chapter, 0))).is_equal("shu_002_guan_yu")
	assert_str(String(scene._resolve_player_hero_id(chapter, 1))).is_equal("shu_001_liu_bei")


func test_player_hero_ids_falls_back_to_legacy_const() -> void:
	# Chapter has no entry → legacy PLAYER_HERO_BY_UNIT_ID const for uids 0, 1.
	var scene: BattleScene = _instantiate_battle_scene()
	var chapter: ChapterDefinition = ChapterDefinition.new()
	chapter.player_unit_ids = PackedInt64Array([0, 1])
	chapter.player_hero_ids = {}
	assert_str(String(scene._resolve_player_hero_id(chapter, 0))).is_equal("shu_001_liu_bei")
	assert_str(String(scene._resolve_player_hero_id(chapter, 1))).is_equal("shu_003_zhang_fei")


func test_player_hero_ids_unknown_uid_falls_back_to_zhang_fei() -> void:
	# Chapter empty + legacy const has no uid=99 → final fallback.
	var scene: BattleScene = _instantiate_battle_scene()
	var chapter: ChapterDefinition = ChapterDefinition.new()
	assert_str(String(scene._resolve_player_hero_id(chapter, 99))).is_equal("shu_003_zhang_fei")


# ─── Class-derived passive + attack_range (wired in same patch) ─────────────


func test_commander_carries_command_aura_passive() -> void:
	# COMMANDER class units (유비, 허저) need passive == &"command_aura" so the
	# GridBattleController._has_adjacent_command_aura adjacency check actually
	# fires the +15% damage buff for adjacent allies. Without this the buff
	# system was dead code (see session 6 P0 wiring).
	var scene: BattleScene = _instantiate_battle_scene()
	var liu_bei: BattleUnit = scene._make_battle_unit(0, &"shu_001_liu_bei", true, Vector2i.ZERO, &"tank", &"aggressor")
	assert_str(String(liu_bei.passive)).is_equal("command_aura")
	var xu_chu: BattleUnit = scene._make_battle_unit(5, &"wei_008_xu_chu", false, Vector2i.ZERO, &"boss", &"coordinator")
	assert_str(String(xu_chu.passive)).is_equal("command_aura")


func test_non_commander_classes_carry_no_default_passive() -> void:
	# INFANTRY 장비, STRATEGIST 장료, ARCHER 우금 — none get an auto passive.
	# The unit_roles.json passive_tag (passive_charge / passive_shield_wall /
	# etc.) is an advisory tag for future systems, not the damage-pipeline
	# `passive` value, so it stays empty until those systems land.
	var scene: BattleScene = _instantiate_battle_scene()
	for hid: StringName in [&"shu_003_zhang_fei", &"wei_006_zhang_liao", &"wei_007_yu_jin"]:
		var unit: BattleUnit = scene._make_battle_unit(99, hid, false, Vector2i.ZERO, &"", &"aggressor")
		assert_str(String(unit.passive)).override_failure_message(
			"%s should NOT auto-get a passive (got '%s')" % [String(hid), String(unit.passive)]
		).is_equal("")


func test_archer_attack_range_is_two() -> void:
	# 우금 ARCHER → range 2 (was hardcoded 1 before P0 wiring).
	var scene: BattleScene = _instantiate_battle_scene()
	var yu_jin: BattleUnit = scene._make_battle_unit(4, &"wei_007_yu_jin", false, Vector2i.ZERO, &"holder", &"holder")
	assert_int(yu_jin.attack_range).is_equal(2)


func test_non_archer_attack_range_is_one() -> void:
	var scene: BattleScene = _instantiate_battle_scene()
	for hid: StringName in [&"shu_001_liu_bei", &"shu_003_zhang_fei", &"wei_005_xiahou_dun", &"wei_006_zhang_liao", &"wei_008_xu_chu"]:
		var unit: BattleUnit = scene._make_battle_unit(99, hid, false, Vector2i.ZERO, &"", &"aggressor")
		assert_int(unit.attack_range).override_failure_message(
			"%s (class=%d) should be melee (range 1); got %d" % [String(hid), unit.unit_class, unit.attack_range]
		).is_equal(1)


# ─── Class-derived move_range (was hardcoded 3 prior to session-8 fix) ───────


func test_move_range_archer_yu_jin_is_three() -> void:
	# 우금: hero.move_range=3, ARCHER class_move_delta=0 → effective 3.
	var scene: BattleScene = _instantiate_battle_scene()
	var unit: BattleUnit = scene._make_battle_unit(4, &"wei_007_yu_jin", false, Vector2i.ZERO, &"holder", &"holder")
	assert_int(unit.move_range).override_failure_message(
		"우금 (archer) should have effective move_range 3 (hero=3 + delta=0); got %d" % unit.move_range
	).is_equal(3)


func test_move_range_cavalry_guan_yu_is_five() -> void:
	# 관우: hero.move_range=4, CAVALRY class_move_delta=+1 → effective 5.
	var scene: BattleScene = _instantiate_battle_scene()
	var unit: BattleUnit = scene._make_battle_unit(6, &"shu_002_guan_yu", true, Vector2i.ZERO, &"tank", &"aggressor")
	assert_int(unit.move_range).override_failure_message(
		"관우 (cavalry) should have effective move_range 5 (hero=4 + delta=+1); got %d" % unit.move_range
	).is_equal(5)


func test_move_range_strategist_zhang_liao_is_four() -> void:
	# 장료: hero.move_range=5, STRATEGIST class_move_delta=-1 → effective 4.
	var scene: BattleScene = _instantiate_battle_scene()
	var unit: BattleUnit = scene._make_battle_unit(3, &"wei_006_zhang_liao", false, Vector2i.ZERO, &"skirmisher", &"skirmisher")
	assert_int(unit.move_range).override_failure_message(
		"장료 (strategist) should have effective move_range 4 (hero=5 + delta=-1); got %d" % unit.move_range
	).is_equal(4)


func test_move_range_unknown_hero_falls_back_to_three() -> void:
	# Unknown hero_id → HeroDatabase.get_hero returns null → fallback 3.
	var scene: BattleScene = _instantiate_battle_scene()
	var unit: BattleUnit = scene._make_battle_unit(99, &"shu_999_phantom", true, Vector2i.ZERO, &"", &"aggressor")
	assert_int(unit.move_range).is_equal(3)


# ─── Session-8 atk/def re-tune for 유비 survivability ─────────────────────────
#
# Sanity that the coefficients in _make_battle_unit produce the new values:
#   raw_atk = stat_might × 1.0         (was × 1.5; halved the BASE_CEILING saturation)
#   raw_def = stat_command × 0.20      (was × 0.05; raw_def now matters under ceiling)
#   +10 raw_def for COMMANDER          (commanders anchor formation; defeat condition tank)
#
# Heroes referenced live in assets/data/heroes/heroes.json (consumed by the
# /root/HeroDatabase autoload at boot).


func test_raw_atk_uses_might_times_one() -> void:
	# 유비 stat_might=70 → raw_atk=70 (was 105 at the 1.5 coefficient).
	var scene: BattleScene = _instantiate_battle_scene()
	var liu_bei: BattleUnit = scene._make_battle_unit(0, &"shu_001_liu_bei", true, Vector2i.ZERO, &"tank", &"aggressor")
	assert_int(liu_bei.raw_atk).override_failure_message(
		"유비 raw_atk should be might(70)×1.0 = 70 (was 105 pre-session-8 retune); got %d" % liu_bei.raw_atk
	).is_equal(70)


func test_enemy_units_get_enemy_atk_mult_penalty() -> void:
	# 하후돈 stat_might=88 → raw_atk = floori(88 × 1.0 × ENEMY_ATK_MULT=0.7) = 61.
	# Player units (is_player=true) skip the multiplier — 장비 raw_atk stays at 92.
	var scene: BattleScene = _instantiate_battle_scene()
	var xiahou_dun: BattleUnit = scene._make_battle_unit(
		2, &"wei_005_xiahou_dun", false, Vector2i.ZERO, &"skirmisher", &"aggressor")
	assert_int(xiahou_dun.raw_atk).override_failure_message(
		"적 하후돈 raw_atk should be int(88×1.0×0.7) = 61 after ENEMY_ATK_MULT penalty; got %d"
		% xiahou_dun.raw_atk
	).is_equal(61)


func test_player_units_do_not_get_enemy_atk_mult_penalty() -> void:
	var scene: BattleScene = _instantiate_battle_scene()
	var zhang_fei: BattleUnit = scene._make_battle_unit(
		1, &"shu_003_zhang_fei", true, Vector2i.ZERO, &"assassin", &"aggressor")
	assert_int(zhang_fei.raw_atk).override_failure_message(
		"Player 장비 raw_atk should stay at might(92)×1.0 = 92 (no enemy penalty); got %d"
		% zhang_fei.raw_atk
	).is_equal(92)


func test_raw_def_uses_command_times_one_fifth_with_commander_bonus() -> void:
	# 유비 stat_command=90, COMMANDER → raw_def = floori(90×0.20) + 10 = 18+10 = 28
	# (was 4 at the 0.05 coefficient — sub-MIN; pushed every attack to BASE_CEILING).
	var scene: BattleScene = _instantiate_battle_scene()
	var liu_bei: BattleUnit = scene._make_battle_unit(0, &"shu_001_liu_bei", true, Vector2i.ZERO, &"tank", &"aggressor")
	assert_int(liu_bei.raw_def).override_failure_message(
		"유비 raw_def should be command(90)×0.20 + COMMANDER bonus(+10) = 28; got %d" % liu_bei.raw_def
	).is_equal(28)


func test_raw_def_no_commander_bonus_for_infantry() -> void:
	# 장비 stat_command=70, INFANTRY → raw_def = floori(70×0.20) = 14 (no +10).
	var scene: BattleScene = _instantiate_battle_scene()
	var zhang_fei: BattleUnit = scene._make_battle_unit(1, &"shu_003_zhang_fei", true, Vector2i.ZERO, &"assassin", &"aggressor")
	assert_int(zhang_fei.raw_def).override_failure_message(
		"장비 raw_def should be command(70)×0.20 = 14 (no COMMANDER bonus); got %d" % zhang_fei.raw_def
	).is_equal(14)


func test_enemy_commander_also_gets_bonus_def() -> void:
	# Cao Cao 조조 (COMMANDER, command=92) → raw_def = floori(92×0.20) + 10 = 18+10 = 28
	# The bonus is class-based, not faction-based — symmetry preserved.
	var scene: BattleScene = _instantiate_battle_scene()
	var cao_cao: BattleUnit = scene._make_battle_unit(7, &"wei_001_cao_cao", false, Vector2i.ZERO, &"boss", &"coordinator")
	assert_int(cao_cao.raw_def).is_equal(28)


# ─── Existing class-distinction sanity ───────────────────────────────────────


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
