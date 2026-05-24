## ch13_changsha_branch_routing_test.gd
##
## Integration tests for ch13 위연 합류 ★ trigger routing (Plan §4.4
## reference ★). Drives fate_data shape matching grid_battle_controller.gd:3364
## emit through DefaultDestinyBranchJudge with ch13 fixture chapter.
##
##   wei_yan_spared_turns=3 + WIN → WIN_changsha_wei_yan_defects (★ hidden)
##   wei_yan_spared_turns=2 + WIN → WIN_changsha_taken (canonical)
##   LOSS → LOSS_changsha_repelled (regression sentinel)
extends GdUnitTestSuite


func test_ch13_wei_yan_spared_3_triggers_hidden_branch() -> void:
	var chapter: ChapterDefinition = _make_ch13_fixture()
	var fate_data: Dictionary = {"wei_yan_spared_turns": 3}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true, fate_data
	)
	assert_str(choice.branch_key).override_failure_message(
		("Expected 'WIN_changsha_wei_yan_defects' at wei_yan_spared_turns>=3; got '%s'")
		% choice.branch_key
	).is_equal("WIN_changsha_wei_yan_defects")
	assert_bool(choice.reserved_color_treatment).is_true()
	assert_bool(choice.is_invalid).is_false()


func test_ch13_wei_yan_spared_2_falls_back_to_canonical() -> void:
	var chapter: ChapterDefinition = _make_ch13_fixture()
	var fate_data: Dictionary = {"wei_yan_spared_turns": 2}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true, fate_data
	)
	assert_str(choice.branch_key).is_equal("WIN_changsha_taken")
	assert_bool(choice.reserved_color_treatment).is_false()
	assert_bool(choice.is_canonical_history).is_true()


func test_ch13_loss_routes_to_repelled() -> void:
	var chapter: ChapterDefinition = _make_ch13_fixture()
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.LOSS, 0, true, {}
	)
	assert_str(choice.branch_key).is_equal("LOSS_changsha_repelled")
	assert_bool(choice.is_invalid).is_false()


func _make_ch13_fixture() -> ChapterDefinition:
	# Mirrors shu_canon_main.json ch13_changsha_veteran routing-relevant fields.
	var c: ChapterDefinition = ChapterDefinition.new()
	c.chapter_id = "ch13_changsha_veteran"
	c.chapter_number = 13
	c.author_draw_branch = false
	c.echo_threshold = 2
	c.branch_table = {
		"WIN_default":  "WIN_changsha_taken",
		"WIN_hidden":   "WIN_changsha_wei_yan_defects",
		"LOSS_default": "LOSS_changsha_repelled",
	}
	c.canonical_branch_key = "WIN_changsha_taken"
	c.hidden_branch_key = "WIN_hidden"
	c.hidden_condition = {
		"type": "fate_threshold",
		"field": "wei_yan_spared_turns",
		"op": ">=",
		"value": 3,
	}
	return c
