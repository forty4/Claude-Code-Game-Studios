## destiny_branch_judge_invariants_test.gd
##
## Covers F-DB-3 12-entry invariant_violation:* vocabulary per AC-DB-16..AC-DB-20g
## + F-DB-4 invariants AC-DB-21..AC-DB-23.
##
## Closed vocabulary (12 entries):
##   chapter_null + chapter_id_missing + default_branch_key_missing +
##   branch_table_null_or_malformed + branch_table_empty +
##   branch_table_missing_outcome + branch_key_type_invalid +
##   is_draw_fallback_type_invalid + is_canonical_history_type_invalid +
##   is_draw_fallback_outcome_mismatch + outcome_unknown +
##   cr13_echo_threshold_on_ch1
extends GdUnitTestSuite


const VOCABULARY: Array[String] = [
	"invariant_violation:chapter_null",
	"invariant_violation:chapter_id_missing",
	"invariant_violation:default_branch_key_missing",
	"invariant_violation:branch_table_null_or_malformed",
	"invariant_violation:branch_table_empty",
	"invariant_violation:branch_table_missing_outcome",
	"invariant_violation:branch_key_type_invalid",
	"invariant_violation:is_draw_fallback_type_invalid",
	"invariant_violation:is_canonical_history_type_invalid",
	"invariant_violation:is_draw_fallback_outcome_mismatch",
	"invariant_violation:outcome_unknown",
	"invariant_violation:cr13_echo_threshold_on_ch1",
]


# ─── F-DB-3 12-entry invariant_violation vocabulary ──────────────────────────


# AC-DB-16
func test_chapter_null_violation() -> void:
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(null, BattleOutcome.Result.WIN, 0, true)
	assert_bool(choice.is_invalid).is_true()
	assert_str(String(choice.invalid_reason)).is_equal("invariant_violation:chapter_null")


# AC-DB-20a
func test_chapter_id_missing_violation() -> void:
	var chapter: ChapterDefinition = _make_valid_chapter()
	chapter.chapter_id = ""
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(chapter, BattleOutcome.Result.WIN, 0, true)
	assert_bool(choice.is_invalid).is_true()
	assert_str(String(choice.invalid_reason)).is_equal("invariant_violation:chapter_id_missing")


# AC-DB-17
func test_default_branch_key_missing_violation() -> void:
	var chapter: ChapterDefinition = _make_valid_chapter()
	chapter.canonical_branch_key = ""
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(chapter, BattleOutcome.Result.WIN, 0, true)
	assert_bool(choice.is_invalid).is_true()
	assert_str(String(choice.invalid_reason)).is_equal("invariant_violation:default_branch_key_missing")


# AC-DB-20f
func test_branch_table_empty_violation() -> void:
	var chapter: ChapterDefinition = _make_valid_chapter()
	chapter.branch_table = {}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(chapter, BattleOutcome.Result.WIN, 0, true)
	assert_bool(choice.is_invalid).is_true()
	assert_str(String(choice.invalid_reason)).is_equal("invariant_violation:branch_table_empty")


# AC-DB-18
func test_branch_table_missing_outcome_violation() -> void:
	var chapter: ChapterDefinition = _make_valid_chapter()
	chapter.branch_table = {"DRAW_default": "DRAW_only"}  # No WIN_default key
	chapter.canonical_branch_key = "DRAW_only"
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(chapter, BattleOutcome.Result.WIN, 0, true)
	assert_bool(choice.is_invalid).is_true()
	assert_str(String(choice.invalid_reason)).is_equal(
		"invariant_violation:branch_table_missing_outcome"
	)


# AC-DB-19 — outcome_unknown
func test_outcome_unknown_violation() -> void:
	var chapter: ChapterDefinition = _make_valid_chapter()
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	# outcome=99 is out of {0,1,2}. Cast through int to bypass typed-enum compile-time check.
	@warning_ignore("int_as_enum_without_cast")
	var choice: DestinyBranchChoice = judge.resolve(chapter, 99 as BattleOutcome.Result, 0, true)
	assert_bool(choice.is_invalid).is_true()
	assert_str(String(choice.invalid_reason)).is_equal("invariant_violation:outcome_unknown")


# AC-DB-20 / AC-DB-06 — CR-13 echo_threshold on Ch1
func test_cr13_echo_threshold_on_ch1_violation() -> void:
	var chapter: ChapterDefinition = _make_valid_chapter()
	chapter.chapter_number = 1
	chapter.echo_threshold = 1
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(chapter, BattleOutcome.Result.DRAW, 1, false)
	assert_bool(choice.is_invalid).is_true()
	assert_str(String(choice.invalid_reason)).is_equal(
		"invariant_violation:cr13_echo_threshold_on_ch1"
	)


# AC-DB-20c — branch_key_type_invalid (via stub injection)
func test_branch_key_non_string_via_stub() -> void:
	var stub: TestDestinyBranchJudgeWithSp1Stub = TestDestinyBranchJudgeWithSp1Stub.new()
	stub.set_sp1_output({
		"branch_key": 42,  # Int instead of String
		"is_draw_fallback": false,
		"is_canonical_history": false,
	})
	var chapter: ChapterDefinition = _make_valid_chapter()
	var choice: DestinyBranchChoice = stub.resolve(chapter, BattleOutcome.Result.WIN, 0, true)
	assert_bool(choice.is_invalid).is_true()
	assert_str(String(choice.invalid_reason)).is_equal("invariant_violation:branch_key_type_invalid")


# AC-DB-20d — is_draw_fallback_type_invalid (via stub)
func test_is_draw_fallback_non_bool_via_stub() -> void:
	var stub: TestDestinyBranchJudgeWithSp1Stub = TestDestinyBranchJudgeWithSp1Stub.new()
	stub.set_sp1_output({
		"branch_key": "TEST_branch",
		"is_draw_fallback": "false",  # String instead of bool
		"is_canonical_history": false,
	})
	var chapter: ChapterDefinition = _make_valid_chapter()
	var choice: DestinyBranchChoice = stub.resolve(chapter, BattleOutcome.Result.WIN, 0, true)
	assert_bool(choice.is_invalid).is_true()
	assert_str(String(choice.invalid_reason)).is_equal(
		"invariant_violation:is_draw_fallback_type_invalid"
	)


# AC-DB-20e — is_canonical_history_type_invalid (via stub)
func test_is_canonical_history_non_bool_via_stub() -> void:
	var stub: TestDestinyBranchJudgeWithSp1Stub = TestDestinyBranchJudgeWithSp1Stub.new()
	stub.set_sp1_output({
		"branch_key": "TEST_branch",
		"is_draw_fallback": false,
		"is_canonical_history": "true",  # String instead of bool
	})
	var chapter: ChapterDefinition = _make_valid_chapter()
	var choice: DestinyBranchChoice = stub.resolve(chapter, BattleOutcome.Result.WIN, 0, true)
	assert_bool(choice.is_invalid).is_true()
	assert_str(String(choice.invalid_reason)).is_equal(
		"invariant_violation:is_canonical_history_type_invalid"
	)


# AC-DB-20g — is_draw_fallback + outcome mismatch
func test_is_draw_fallback_outcome_mismatch_via_stub() -> void:
	var stub: TestDestinyBranchJudgeWithSp1Stub = TestDestinyBranchJudgeWithSp1Stub.new()
	stub.set_sp1_output({
		"branch_key": "TEST_branch",
		"is_draw_fallback": true,  # Says fallback...
		"is_canonical_history": false,
	})
	var chapter: ChapterDefinition = _make_valid_chapter()
	# ...but outcome is WIN, not DRAW. Cross-field invariant violated.
	var choice: DestinyBranchChoice = stub.resolve(chapter, BattleOutcome.Result.WIN, 0, true)
	assert_bool(choice.is_invalid).is_true()
	assert_str(String(choice.invalid_reason)).is_equal(
		"invariant_violation:is_draw_fallback_outcome_mismatch"
	)


# ─── AC-DB-21: reserved_color_treatment false when is_invalid=true ───────────


func test_reserved_color_treatment_always_false_when_invalid() -> void:
	# Test on 3 representative invalid paths.
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var paths: Array[Dictionary] = [
		{"chapter": null, "outcome": BattleOutcome.Result.WIN},
		{"chapter": _make_valid_chapter_with("", 1, 0), "outcome": BattleOutcome.Result.WIN},  # chapter_id empty
		{"chapter": _make_valid_chapter_with("ch1", 1, 1), "outcome": BattleOutcome.Result.DRAW},  # CR-13
	]
	for p in paths:
		var choice: DestinyBranchChoice = judge.resolve(
			p["chapter"], p["outcome"] as BattleOutcome.Result, 1, false
		)
		assert_bool(choice.is_invalid).is_true()
		assert_bool(choice.reserved_color_treatment).is_false()


# ─── AC-DB-23: closed vocabulary membership ──────────────────────────────────


func test_invalid_reason_in_closed_vocabulary() -> void:
	# Trigger 5 different violations, verify each invalid_reason is in the 12-entry set.
	var triggers: Array[Callable] = [
		func() -> DestinyBranchChoice:
			return DefaultDestinyBranchJudge.new().resolve(null, BattleOutcome.Result.WIN, 0, true),
		func() -> DestinyBranchChoice:
			var c: ChapterDefinition = _make_valid_chapter()
			c.chapter_id = ""
			return DefaultDestinyBranchJudge.new().resolve(c, BattleOutcome.Result.WIN, 0, true),
		func() -> DestinyBranchChoice:
			var c: ChapterDefinition = _make_valid_chapter()
			c.canonical_branch_key = ""
			return DefaultDestinyBranchJudge.new().resolve(c, BattleOutcome.Result.WIN, 0, true),
		func() -> DestinyBranchChoice:
			var c: ChapterDefinition = _make_valid_chapter()
			c.branch_table = {}
			return DefaultDestinyBranchJudge.new().resolve(c, BattleOutcome.Result.WIN, 0, true),
		func() -> DestinyBranchChoice:
			var c: ChapterDefinition = _make_valid_chapter()
			c.chapter_number = 1
			c.echo_threshold = 1
			return DefaultDestinyBranchJudge.new().resolve(c, BattleOutcome.Result.DRAW, 1, false),
	]
	for trig: Callable in triggers:
		var choice: DestinyBranchChoice = trig.call()
		assert_bool(choice.is_invalid).is_true()
		assert_array(VOCABULARY).contains([String(choice.invalid_reason)])


# ─── Helpers ──────────────────────────────────────────────────────────────────


func _make_valid_chapter() -> ChapterDefinition:
	return _make_valid_chapter_with("ch_test", 2, 1)


func _make_valid_chapter_with(chapter_id: String, chapter_number: int, echo_threshold: int) -> ChapterDefinition:
	var c: ChapterDefinition = ChapterDefinition.new()
	c.chapter_id = chapter_id
	c.chapter_number = chapter_number
	c.author_draw_branch = false
	c.echo_threshold = echo_threshold
	c.branch_table = {
		"WIN_default":  "WIN_test_default",
		"LOSS_default": "LOSS_test_default",
	}
	c.canonical_branch_key = "WIN_test_default"
	return c
