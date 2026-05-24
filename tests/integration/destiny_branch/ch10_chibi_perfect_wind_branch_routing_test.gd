## ch10_chibi_perfect_wind_branch_routing_test.gd
##
## Integration tests for ch10 적벽 동남풍 perfect timing ★ trigger routing
## per design/quick-specs/ch10-chibi-perfect-wind.md AC-7 + §7 tests #5/6/7.
##
##   player_casualties=0 + WIN → WIN_chibi_perfect_southeast_wind (★ hidden)
##   player_casualties=1 + WIN → WIN_chibi_main_burn (default canonical)
##   LOSS → LOSS_chibi_main_wind_fails (regression sentinel)
##
## ch08/ch13/ch16 e2e pattern reuse (programmatic ChapterDefinition fixture +
## DefaultDestinyBranchJudge.resolve, no controller wiring). 4th/5th instance
## of entity-less e2e recipe.
extends GdUnitTestSuite


func test_ch10_perfect_wind_triggers_hidden_branch_at_zero_casualties() -> void:
	var chapter: ChapterDefinition = _make_ch10_fixture()
	var fate_data: Dictionary = {"player_casualties": 0}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true, fate_data
	)
	assert_str(choice.branch_key).override_failure_message(
		("Expected 'WIN_chibi_perfect_southeast_wind' at player_casualties<=0; got '%s'. "
		+ "fate_data.player_casualties=%d, hidden_condition.value=%d")
		% [choice.branch_key, fate_data["player_casualties"] as int,
			int(chapter.hidden_condition.get("value", -1))]
	).is_equal("WIN_chibi_perfect_southeast_wind")
	assert_bool(choice.reserved_color_treatment).override_failure_message(
		"★ hidden branch must set reserved_color_treatment=true (F-DB-2)"
	).is_true()
	assert_bool(choice.is_invalid).is_false()


func test_ch10_falls_back_to_canonical_at_any_casualty() -> void:
	var chapter: ChapterDefinition = _make_ch10_fixture()
	var fate_data: Dictionary = {"player_casualties": 1}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true, fate_data
	)
	assert_str(choice.branch_key).override_failure_message(
		("Expected 'WIN_chibi_main_burn' (canonical) at player_casualties=1; got '%s'")
		% choice.branch_key
	).is_equal("WIN_chibi_main_burn")
	assert_bool(choice.reserved_color_treatment).is_false()
	assert_bool(choice.is_canonical_history).is_true()
	assert_bool(choice.is_invalid).is_false()


func test_ch10_loss_routes_to_wind_fails() -> void:
	var chapter: ChapterDefinition = _make_ch10_fixture()
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.LOSS, 0, true, {}
	)
	assert_str(choice.branch_key).override_failure_message(
		"Expected 'LOSS_chibi_main_wind_fails' on LOSS outcome; got '%s'" % choice.branch_key
	).is_equal("LOSS_chibi_main_wind_fails")
	assert_bool(choice.is_invalid).is_false()


func _make_ch10_fixture() -> ChapterDefinition:
	# Mirrors shu_canon_main.json ch10_chibi_main routing-relevant fields
	# after S84 ★ entry authoring.
	var c: ChapterDefinition = ChapterDefinition.new()
	c.chapter_id = "ch10_chibi_main"
	c.chapter_number = 10
	c.author_draw_branch = false
	c.echo_threshold = 2
	c.branch_table = {
		"WIN_default":  "WIN_chibi_main_burn",
		"WIN_hidden":   "WIN_chibi_perfect_southeast_wind",
		"LOSS_default": "LOSS_chibi_main_wind_fails",
	}
	c.canonical_branch_key = "WIN_chibi_main_burn"
	c.hidden_branch_key = "WIN_hidden"
	c.hidden_condition = {
		"type": "fate_threshold",
		"field": "player_casualties",
		"op": "<=",
		"value": 0,
	}
	return c
