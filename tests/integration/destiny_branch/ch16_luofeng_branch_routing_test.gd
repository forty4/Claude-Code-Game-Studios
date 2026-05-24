## ch16_luofeng_branch_routing_test.gd
##
## Integration tests for ch16 방통 생존 ★ trigger routing (Plan §4.5
## reference ★). Drives fate_data shape matching grid_battle_controller.gd:3365
## emit through DefaultDestinyBranchJudge with ch16 fixture chapter.
##
##   scout_first_turns=2 + WIN → WIN_luofeng_pang_tong_lives (★ hidden)
##   scout_first_turns=1 + WIN → WIN_luofeng_kongming_arrives (canonical)
##   LOSS → LOSS_luofeng_ambush_complete (regression sentinel)
extends GdUnitTestSuite


func test_ch16_scout_first_2_triggers_hidden_branch() -> void:
	var chapter: ChapterDefinition = _make_ch16_fixture()
	var fate_data: Dictionary = {"scout_first_turns": 2}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true, fate_data
	)
	assert_str(choice.branch_key).override_failure_message(
		"Expected 'WIN_luofeng_pang_tong_lives' at scout_first_turns>=2; got '%s'"
		% choice.branch_key
	).is_equal("WIN_luofeng_pang_tong_lives")
	assert_bool(choice.reserved_color_treatment).is_true()
	assert_bool(choice.is_invalid).is_false()


func test_ch16_scout_first_1_falls_back_to_canonical() -> void:
	var chapter: ChapterDefinition = _make_ch16_fixture()
	var fate_data: Dictionary = {"scout_first_turns": 1}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true, fate_data
	)
	assert_str(choice.branch_key).is_equal("WIN_luofeng_kongming_arrives")
	assert_bool(choice.reserved_color_treatment).is_false()
	assert_bool(choice.is_canonical_history).is_true()


func test_ch16_loss_routes_to_ambush_complete() -> void:
	var chapter: ChapterDefinition = _make_ch16_fixture()
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.LOSS, 0, true, {}
	)
	assert_str(choice.branch_key).is_equal("LOSS_luofeng_ambush_complete")
	assert_bool(choice.is_invalid).is_false()


func _make_ch16_fixture() -> ChapterDefinition:
	var c: ChapterDefinition = ChapterDefinition.new()
	c.chapter_id = "ch16_luofeng_slope"
	c.chapter_number = 16
	c.author_draw_branch = false
	c.echo_threshold = 3
	c.branch_table = {
		"WIN_default":  "WIN_luofeng_kongming_arrives",
		"WIN_hidden":   "WIN_luofeng_pang_tong_lives",
		"LOSS_default": "LOSS_luofeng_ambush_complete",
	}
	c.canonical_branch_key = "WIN_luofeng_kongming_arrives"
	c.hidden_branch_key = "WIN_hidden"
	c.hidden_condition = {
		"type": "fate_threshold",
		"field": "scout_first_turns",
		"op": ">=",
		"value": 2,
	}
	return c
