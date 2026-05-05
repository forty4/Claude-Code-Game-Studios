## destiny_branch_judge_determinism_test.gd
##
## Covers AC-DB-07 (CR-DB-2 / CR-DB-11 determinism) + AC-DB-08 (CR-DB-3 transient
## lifecycle via WeakRef).
##
## Determinism: two independently-constructed judges + identical inputs MUST
## produce field-identical 9-field DestinyBranchChoice. Verified at 3 levels:
##   1. Functional: 2 instances, identical inputs, all 9 fields field-equal
##   2. Source-scan: judge files contain no Time.* / rand* / Engine.* / etc.
##   3. Lifecycle: judge held by WeakRef cleared after scope drop
extends GdUnitTestSuite


const JUDGE_PATH: String = "res://src/feature/destiny_branch/destiny_branch_judge.gd"
const DEFAULT_JUDGE_PATH: String = "res://src/feature/destiny_branch/default_destiny_branch_judge.gd"


# ─── AC-DB-07: determinism across instances ──────────────────────────────────


func test_two_instances_produce_field_equal_output() -> void:
	var chapter: ChapterDefinition = _make_chapter()
	var judge1: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var result1: DestinyBranchChoice = judge1.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true
	)
	var judge2: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var result2: DestinyBranchChoice = judge2.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true
	)
	# All 9 typed @export fields field-equal.
	assert_str(result1.chapter_id).is_equal(result2.chapter_id)
	assert_str(result1.branch_key).is_equal(result2.branch_key)
	assert_int(result1.outcome).is_equal(result2.outcome)
	assert_int(result1.echo_count).is_equal(result2.echo_count)
	assert_bool(result1.is_draw_fallback).is_equal(result2.is_draw_fallback)
	assert_bool(result1.is_canonical_history).is_equal(result2.is_canonical_history)
	assert_bool(result1.reserved_color_treatment).is_equal(result2.reserved_color_treatment)
	assert_bool(result1.is_invalid).is_equal(result2.is_invalid)
	assert_str(String(result1.invalid_reason)).is_equal(String(result2.invalid_reason))


# AC-DB-07 source-scan: no forbidden API patterns
func test_judge_source_contains_no_nondeterministic_patterns() -> void:
	var sources: Array[String] = [JUDGE_PATH, DEFAULT_JUDGE_PATH]
	var forbidden: Array[String] = [
		"Time.get_ticks_msec",
		"Time.get_ticks_usec",
		"Time.get_unix_time_from_system",
		"randi(",
		"randf(",
		"randf_range",
		"randi_range",
		"Engine.get_process_frames",
		"Engine.get_physics_frames",
		"DisplayServer.window_",
		"OS.get_processor_count",
	]
	for src: String in sources:
		var content: String = FileAccess.get_file_as_string(src)
		for pattern: String in forbidden:
			assert_bool(content.contains(pattern)).override_failure_message(
				"%s must not contain '%s' (CR-DB-2 determinism)" % [src, pattern]
			).is_false()


# Same inputs produce same outputs across 100 sequential calls on same instance.
func test_one_hundred_repeat_calls_produce_identical_output() -> void:
	var chapter: ChapterDefinition = _make_chapter()
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var baseline: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.LOSS, 0, true
	)
	for i in 99:
		var result: DestinyBranchChoice = judge.resolve(
			chapter, BattleOutcome.Result.LOSS, 0, true
		)
		assert_str(result.branch_key).is_equal(baseline.branch_key)
		assert_int(result.outcome).is_equal(baseline.outcome)
		assert_bool(result.is_canonical_history).is_equal(baseline.is_canonical_history)
		assert_str(String(result.invalid_reason)).is_equal(String(baseline.invalid_reason))


# ─── AC-DB-08: transient lifecycle via WeakRef ────────────────────────────────


func test_judge_weakref_cleared_after_scope_drop() -> void:
	var weak: WeakRef = _construct_and_release_judge()
	# Wait one idle frame for RefCounted scope drop to take effect.
	await get_tree().process_frame
	# weak.get_ref() should return null since judge has no other references.
	assert_object(weak.get_ref()).is_null()


# Constructs a judge, calls resolve(), returns a WeakRef. Judge falls out of
# scope when this function returns, allowing RefCounted to reclaim memory.
func _construct_and_release_judge() -> WeakRef:
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var chapter: ChapterDefinition = _make_chapter()
	judge.resolve(chapter, BattleOutcome.Result.WIN, 0, true)
	return weakref(judge)


# ─── Helpers ──────────────────────────────────────────────────────────────────


func _make_chapter() -> ChapterDefinition:
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
