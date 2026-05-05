## destiny_branch_judge_worked_examples_test.gd
##
## Covers F-DB-1 worked examples E1-E6 per ADR-0018 §AC-DB-01..06:
## E1 Ch1 WIN default + E2 Ch3 DRAW default + E3 Ch3 DRAW echo-gated +
## E4 Ch2 DRAW fallback + E5 null chapter + E6 CR-13 runtime violation.
extends GdUnitTestSuite


# ─── AC-DB-01: E1 Ch1 WIN default ─────────────────────────────────────────────


func test_ch1_win_default_returns_canonical_branch() -> void:
	var chapter: ChapterDefinition = _make_ch1_fixture()
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true
	)
	assert_str(choice.chapter_id).is_equal("ch1")
	assert_str(choice.branch_key).is_equal("WIN_ch1_default")
	assert_int(choice.outcome).is_equal(BattleOutcome.Result.WIN)
	assert_int(choice.echo_count).is_equal(0)
	assert_bool(choice.is_draw_fallback).is_false()
	assert_bool(choice.is_canonical_history).is_true()
	assert_bool(choice.reserved_color_treatment).is_false()
	assert_bool(choice.is_invalid).is_false()
	assert_str(String(choice.invalid_reason)).is_empty()


# ─── AC-DB-02: E2 Ch3 DRAW default ────────────────────────────────────────────


func test_ch3_draw_default_returns_draw_branch() -> void:
	var chapter: ChapterDefinition = _make_ch3_draw_fixture()
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.DRAW, 0, true
	)
	assert_str(choice.branch_key).is_equal("DRAW_ch3_default")
	assert_bool(choice.is_draw_fallback).is_false()
	assert_bool(choice.reserved_color_treatment).is_true()
	assert_bool(choice.is_invalid).is_false()


# ─── AC-DB-03: E3 Ch3 DRAW echo-gated (Pillar 2 observable) ──────────────────


func test_ch3_draw_echo_gated_returns_distinct_branch() -> void:
	var chapter: ChapterDefinition = _make_ch3_draw_fixture()
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.DRAW, 1, false
	)
	# Echo-gate open: echo_count >= echo_threshold AND first_attempt_resolved=false
	assert_str(choice.branch_key).is_equal("DRAW_ch3_echo")
	assert_bool(choice.reserved_color_treatment).is_true()
	assert_bool(choice.is_invalid).is_false()


# ─── AC-DB-04: E4 Ch2 DRAW fallback ──────────────────────────────────────────


func test_ch2_draw_falls_back_to_win_branch() -> void:
	var chapter: ChapterDefinition = _make_ch2_no_draw_fixture()
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.DRAW, 0, true
	)
	assert_str(choice.branch_key).is_equal("WIN_ch2_default")
	assert_bool(choice.is_draw_fallback).is_true()
	# F-DB-2 step 4a fallback override: is_draw_fallback=true ⟹ reserved_color_treatment=false
	assert_bool(choice.reserved_color_treatment).is_false()
	assert_int(choice.outcome).is_equal(BattleOutcome.Result.DRAW)
	assert_bool(choice.is_invalid).is_false()


# ─── AC-DB-05: E5 null chapter ───────────────────────────────────────────────


func test_null_chapter_returns_invalid() -> void:
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		null, BattleOutcome.Result.WIN, 0, true
	)
	assert_bool(choice.is_invalid).is_true()
	assert_str(String(choice.invalid_reason)).is_equal("invariant_violation:chapter_null")
	assert_bool(choice.reserved_color_treatment).is_false()


# ─── AC-DB-06: E6 CR-13 runtime violation (Ch1 with echo_threshold > 0) ─────


func test_cr13_ch1_echo_threshold_violation() -> void:
	var chapter: ChapterDefinition = _make_ch1_fixture()
	chapter.echo_threshold = 1  # CR-13 violation
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.DRAW, 1, false
	)
	assert_bool(choice.is_invalid).is_true()
	assert_str(String(choice.invalid_reason)).is_equal(
		"invariant_violation:cr13_echo_threshold_on_ch1"
	)


# ─── Helpers ──────────────────────────────────────────────────────────────────


func _make_ch1_fixture() -> ChapterDefinition:
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
	return c


func _make_ch3_draw_fixture() -> ChapterDefinition:
	var c: ChapterDefinition = ChapterDefinition.new()
	c.chapter_id = "ch3"
	c.chapter_number = 3
	c.author_draw_branch = true
	c.echo_threshold = 1
	c.branch_table = {
		"WIN_default":   "WIN_ch3_default",
		"LOSS_default":  "LOSS_ch3_default",
		"DRAW_default":  "DRAW_ch3_default",
		"DRAW_echo":     "DRAW_ch3_echo",
	}
	c.canonical_branch_key = "WIN_ch3_default"
	return c


func _make_ch2_no_draw_fixture() -> ChapterDefinition:
	var c: ChapterDefinition = ChapterDefinition.new()
	c.chapter_id = "ch2"
	c.chapter_number = 2
	c.author_draw_branch = false
	c.echo_threshold = 1
	c.branch_table = {
		"WIN_default":  "WIN_ch2_default",
		"LOSS_default": "LOSS_ch2_default",
	}
	c.canonical_branch_key = "WIN_ch2_default"
	return c
