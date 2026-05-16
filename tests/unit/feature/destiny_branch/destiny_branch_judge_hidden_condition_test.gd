## destiny_branch_judge_hidden_condition_test.gd
##
## Covers DefaultDestinyBranchJudge Row 2a (hidden-condition WIN) — the
## Pillar 2 (운명은 바꿀 수 있다) surface. Verifies:
##   • Hidden branch fires when predicate passes (WIN + condition met).
##   • Falls through to WIN_default when predicate fails.
##   • Falls through to WIN_default when fate_data empty.
##   • Falls through to WIN_default when hidden_branch_key absent.
##   • Hidden branch row is WIN-scoped — DRAW / LOSS unaffected.
##   • reserved_color_treatment flips correctly (hidden branch != canonical).
extends GdUnitTestSuite


# ─── Row 2a: hidden branch fires on WIN + predicate pass ──────────────────────


func test_win_with_hidden_condition_met_routes_to_hidden_branch() -> void:
	# Arrange — ch1 fixture with hidden_condition: assassin_kills >= 2.
	var chapter: ChapterDefinition = _make_ch1_with_hidden_fixture()
	var fate: Dictionary = {"assassin_kills": 2}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	# Act
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true, fate
	)
	# Assert
	assert_str(choice.branch_key).is_equal("WIN_ch1_lord_unharmed")
	assert_bool(choice.is_invalid).is_false()
	assert_bool(choice.is_canonical_history).is_false()
	# Hidden branch differs from canonical → reserved_color_treatment ON.
	assert_bool(choice.reserved_color_treatment).is_true()


func test_win_with_hidden_condition_far_exceeded_still_routes_hidden() -> void:
	var chapter: ChapterDefinition = _make_ch1_with_hidden_fixture()
	var fate: Dictionary = {"assassin_kills": 99}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true, fate
	)
	assert_str(choice.branch_key).is_equal("WIN_ch1_lord_unharmed")


# ─── Row 2a fall-through to Row 2 (WIN_default) ───────────────────────────────


func test_win_with_hidden_condition_below_threshold_routes_to_win_default() -> void:
	var chapter: ChapterDefinition = _make_ch1_with_hidden_fixture()
	var fate: Dictionary = {"assassin_kills": 1}  # below threshold
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true, fate
	)
	assert_str(choice.branch_key).is_equal("WIN_ch1_default")
	assert_bool(choice.is_canonical_history).is_true()
	assert_bool(choice.reserved_color_treatment).is_false()


func test_win_with_empty_fate_data_routes_to_win_default() -> void:
	var chapter: ChapterDefinition = _make_ch1_with_hidden_fixture()
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	# fate_data omitted → defaults to {} per resolve() signature.
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true
	)
	assert_str(choice.branch_key).is_equal("WIN_ch1_default")


func test_win_with_hidden_branch_key_absent_uses_win_default() -> void:
	# Chapter with NO hidden_branch_key authored — even if fate_data has the
	# threshold value, no hidden row exists to route to.
	var chapter: ChapterDefinition = _make_ch1_no_hidden_fixture()
	var fate: Dictionary = {"assassin_kills": 99}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true, fate
	)
	assert_str(choice.branch_key).is_equal("WIN_ch1_default")


func test_win_with_hidden_key_declared_but_no_branch_table_entry_falls_through() -> void:
	# Authoring drift: hidden_branch_key declared but branch_table missing the
	# corresponding entry. Resolver falls through to WIN_default rather than
	# emitting an empty branch_key (which would trip post-call guard).
	var chapter: ChapterDefinition = _make_ch1_with_hidden_fixture()
	chapter.branch_table = {
		"WIN_default":  "WIN_ch1_default",
		"LOSS_default": "LOSS_ch1_default",
		# "WIN_hidden" entry deliberately removed
	}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true, {"assassin_kills": 99}
	)
	assert_str(choice.branch_key).is_equal("WIN_ch1_default")
	assert_bool(choice.is_invalid).is_false()


# ─── Row 2a is WIN-scoped — DRAW / LOSS bypass hidden row ─────────────────────


func test_loss_with_hidden_condition_met_still_routes_to_loss_default() -> void:
	var chapter: ChapterDefinition = _make_ch1_with_hidden_fixture()
	var fate: Dictionary = {"assassin_kills": 99}  # would meet condition
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.LOSS, 0, true, fate
	)
	assert_str(choice.branch_key).is_equal("LOSS_ch1_default")


func test_draw_fallback_with_hidden_condition_met_still_routes_to_win_default() -> void:
	# DRAW outcome on a chapter that does NOT author_draw_branch → fallback to
	# WIN row per Row 1. Even with hidden condition met in fate_data, the
	# DRAW-fallback path takes precedence (Row 1 fires before Row 2a).
	var chapter: ChapterDefinition = _make_ch1_with_hidden_fixture()
	var fate: Dictionary = {"assassin_kills": 99}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.DRAW, 0, true, fate
	)
	assert_str(choice.branch_key).is_equal("WIN_ch1_default")
	assert_bool(choice.is_draw_fallback).is_true()


# ─── Back-compat: resolve() default fate_data arg ─────────────────────────────


func test_resolve_with_default_fate_data_arg_still_works_on_non_hidden_chapter() -> void:
	# Ensures the new 5th param (fate_data: Dictionary = {}) is fully back-
	# compatible with the prior 4-arg call pattern used by existing tests.
	var chapter: ChapterDefinition = _make_ch1_no_hidden_fixture()
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true
	)
	assert_str(choice.branch_key).is_equal("WIN_ch1_default")
	assert_bool(choice.is_invalid).is_false()


# ─── Fixtures ─────────────────────────────────────────────────────────────────


func _make_ch1_with_hidden_fixture() -> ChapterDefinition:
	var c: ChapterDefinition = ChapterDefinition.new()
	c.chapter_id = "ch1"
	c.chapter_number = 1
	c.author_draw_branch = false
	c.echo_threshold = 0
	c.branch_table = {
		"WIN_default":  "WIN_ch1_default",
		"WIN_hidden":   "WIN_ch1_lord_unharmed",
		"LOSS_default": "LOSS_ch1_default",
	}
	c.canonical_branch_key = "WIN_ch1_default"
	c.hidden_branch_key = "WIN_hidden"
	c.hidden_condition = {
		"type": "fate_threshold",
		"field": "assassin_kills",
		"op": ">=",
		"value": 2,
	}
	return c


func _make_ch1_no_hidden_fixture() -> ChapterDefinition:
	var c: ChapterDefinition = ChapterDefinition.new()
	c.chapter_id = "ch1"
	c.chapter_number = 1
	c.author_draw_branch = false
	c.echo_threshold = 0
	c.branch_table = {
		"WIN_default":  "WIN_ch1_default",
		"LOSS_default": "LOSS_ch1_default",
	}
	c.canonical_branch_key = "WIN_ch1_default"
	# hidden_branch_key + hidden_condition left at defaults (empty)
	return c
