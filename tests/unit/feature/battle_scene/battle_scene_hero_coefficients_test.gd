## battle_scene_hero_coefficients_test.gd
##
## Pins the BalanceConstants-driven hero stat → raw_atk/raw_def coefficients
## promoted out of inline `* 1.0` / `* 0.20` / `+= 10` constants at session 9.
##
##   raw_atk = stat_might  × HERO_ATK_COEFF
##   raw_def = stat_command × HERO_DEF_COEFF (+ HERO_COMMANDER_DEF_BONUS for COMMANDER)
##
## These tests are the regression sentinel: if the JSON keys disappear, or
## the inline coefficients drift back into _make_battle_unit, the assertions
## here catch it. Companion to battle_scene_unit_class_propagation_test.gd's
## "Session-8 atk/def re-tune" block — same pattern, different focus.
extends GdUnitTestSuite

const BattleSceneScript: GDScript = preload("res://src/feature/battle_scene/battle_scene.gd")


func _instantiate_battle_scene() -> BattleScene:
	var scene: BattleScene = BattleSceneScript.new()
	auto_free(scene)
	return scene


# ─── Constants exist in balance_entities.json ─────────────────────────────────


func test_hero_atk_coeff_is_registered_in_balance_constants() -> void:
	# Variant of primitive type — typeof != TYPE_NIL pins "present"; downstream
	# is_equal_approx pins value. assert_object refuses non-Object Variants.
	var v: Variant = BalanceConstants.get_const("HERO_ATK_COEFF")
	assert_int(typeof(v)).override_failure_message(
		"HERO_ATK_COEFF must be registered in balance_entities.json (session 9 promotion)"
	).is_not_equal(TYPE_NIL)
	assert_float(v as float).is_equal_approx(1.0, 0.0001)


func test_hero_def_coeff_is_registered_in_balance_constants() -> void:
	var v: Variant = BalanceConstants.get_const("HERO_DEF_COEFF")
	assert_int(typeof(v)).is_not_equal(TYPE_NIL)
	assert_float(v as float).is_equal_approx(0.20, 0.0001)


func test_hero_commander_def_bonus_is_registered_in_balance_constants() -> void:
	# Bumped 10 → 18 in session 15 balance pass: ch1 was unwinnable for the
	# 2v4 garrison; a beefier COMMANDER lets 유비 hold the line one more turn.
	var v: Variant = BalanceConstants.get_const("HERO_COMMANDER_DEF_BONUS")
	assert_int(typeof(v)).is_not_equal(TYPE_NIL)
	assert_int(v as int).is_equal(18)


# ─── BattleScene._make_battle_unit reads the constants ───────────────────────


func test_raw_def_uses_command_times_def_coeff_for_non_commander() -> void:
	# 장비 stat_command=70, HERO_DEF_COEFF=0.20 → raw_def = int(70×0.20) = 14.
	# INFANTRY class → no commander bonus applied.
	var scene: BattleScene = _instantiate_battle_scene()
	var zhang_fei: BattleUnit = scene._make_battle_unit(
		1, &"shu_003_zhang_fei", true, Vector2i.ZERO, &"assassin", &"aggressor")
	assert_int(zhang_fei.raw_def).override_failure_message(
		"장비 raw_def should be command(70)×0.20 = 14 (no commander bonus); got %d"
		% zhang_fei.raw_def
	).is_equal(14)


func test_raw_def_applies_commander_bonus_for_commanders() -> void:
	# 유비 stat_command=90, HERO_DEF_COEFF=0.20, COMMANDER bonus +18 → 36.
	# (COMMANDER bonus bumped 10 → 18 in session-15 balance pass.)
	var scene: BattleScene = _instantiate_battle_scene()
	var liu_bei: BattleUnit = scene._make_battle_unit(
		0, &"shu_001_liu_bei", true, Vector2i.ZERO, &"tank", &"aggressor")
	assert_int(liu_bei.raw_def).override_failure_message(
		"유비 raw_def should be command(90)×0.20 + 18 (COMMANDER) = 36; got %d"
		% liu_bei.raw_def
	).is_equal(36)


func test_raw_atk_uses_might_times_atk_coeff() -> void:
	# 관우 (shu_002_guan_yu) stat_might=92, HERO_ATK_COEFF=1.0 → raw_atk=92.
	# Player unit → no enemy multiplier applied.
	var scene: BattleScene = _instantiate_battle_scene()
	var guan_yu: BattleUnit = scene._make_battle_unit(
		6, &"shu_002_guan_yu", true, Vector2i.ZERO, &"tank", &"aggressor")
	assert_int(guan_yu.raw_atk).override_failure_message(
		"관우 raw_atk should be might(95)×1.0 = 95 (HERO_ATK_COEFF); got %d"
		% guan_yu.raw_atk
	).is_equal(95)
