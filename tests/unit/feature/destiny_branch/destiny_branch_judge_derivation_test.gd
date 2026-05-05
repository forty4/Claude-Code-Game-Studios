## destiny_branch_judge_derivation_test.gd
##
## Covers F-DB-2 reserved_color_treatment derivation per AC-DB-14 (positive case)
## + AC-DB-15 (negative case + step 4a fallback override).
##
## F-DB-2 rule:
##   reserved_color_treatment = (branch_key != canonical_branch_key) AND (NOT is_draw_fallback)
## Step 4a override:
##   is_draw_fallback == true ⟹ reserved_color_treatment = false (regardless of branch_key)
extends GdUnitTestSuite


# ─── AC-DB-14: positive case (non-canonical branch + not fallback) ───────────


func test_reserved_color_treatment_true_for_non_canonical_branch() -> void:
	var stub: TestDestinyBranchJudgeWithSp1Stub = TestDestinyBranchJudgeWithSp1Stub.new()
	stub.set_sp1_output({
		"branch_key": "DRAW_ch3_echo",  # Non-canonical
		"is_draw_fallback": false,
		"is_canonical_history": false,
	})
	var chapter: ChapterDefinition = _make_chapter("WIN_ch3_default")
	var choice: DestinyBranchChoice = stub.resolve(chapter, BattleOutcome.Result.DRAW, 1, false)
	assert_bool(choice.reserved_color_treatment).is_true()
	assert_bool(choice.is_invalid).is_false()


# ─── AC-DB-15 row 1: negative case (canonical branch) ────────────────────────


func test_reserved_color_treatment_false_when_branch_matches_canonical() -> void:
	var stub: TestDestinyBranchJudgeWithSp1Stub = TestDestinyBranchJudgeWithSp1Stub.new()
	stub.set_sp1_output({
		"branch_key": "WIN_ch2_default",  # Equals canonical
		"is_draw_fallback": false,
		"is_canonical_history": true,
	})
	var chapter: ChapterDefinition = _make_chapter("WIN_ch2_default")
	var choice: DestinyBranchChoice = stub.resolve(chapter, BattleOutcome.Result.WIN, 0, true)
	assert_bool(choice.reserved_color_treatment).is_false()


# ─── AC-DB-15 row 2: step 4a fallback override (is_draw_fallback=true) ──────


func test_reserved_color_treatment_false_via_fallback_override() -> void:
	var stub: TestDestinyBranchJudgeWithSp1Stub = TestDestinyBranchJudgeWithSp1Stub.new()
	stub.set_sp1_output({
		"branch_key": "WIN_ch2_default",  # Equals canonical
		"is_draw_fallback": true,         # Fallback active
		"is_canonical_history": true,
	})
	var chapter: ChapterDefinition = _make_chapter("WIN_ch2_default")
	# Step 4a: is_draw_fallback=true forces reserved_color_treatment=false
	# even when branch_key equals canonical (which would normally already be false).
	var choice: DestinyBranchChoice = stub.resolve(chapter, BattleOutcome.Result.DRAW, 0, true)
	assert_bool(choice.reserved_color_treatment).is_false()


# Edge case: stub returns non-canonical branch + is_draw_fallback=true
# Step 4a override fires; reserved_color_treatment must be false.
func test_fallback_override_supersedes_non_canonical_branch() -> void:
	var stub: TestDestinyBranchJudgeWithSp1Stub = TestDestinyBranchJudgeWithSp1Stub.new()
	stub.set_sp1_output({
		"branch_key": "WIN_ch2_default",  # Non-canonical alternative
		"is_draw_fallback": true,
		"is_canonical_history": false,
	})
	var chapter: ChapterDefinition = _make_chapter("CANON_branch")
	var choice: DestinyBranchChoice = stub.resolve(chapter, BattleOutcome.Result.DRAW, 0, true)
	# Without step 4a, would be true (branch_key != canonical_branch_key).
	# With step 4a, is_draw_fallback=true forces it to false.
	assert_bool(choice.reserved_color_treatment).is_false()


# ─── Helpers ──────────────────────────────────────────────────────────────────


func _make_chapter(canonical_key: String) -> ChapterDefinition:
	var c: ChapterDefinition = ChapterDefinition.new()
	c.chapter_id = "test_ch"
	c.chapter_number = 2
	c.author_draw_branch = false
	c.echo_threshold = 1
	c.branch_table = {
		"WIN_default":  "WIN_ch2_default",
		"LOSS_default": "LOSS_ch2_default",
	}
	c.canonical_branch_key = canonical_key
	return c
