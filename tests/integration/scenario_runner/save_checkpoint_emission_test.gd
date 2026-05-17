## save_checkpoint_emission_test.gd
##
## Integration tests for the three CP emission call sites in ScenarioRunner:
##   - CP-1: _enter_beat_1_anchor (AC-SL-1)
##   - CP-2: _enter_beat_7_judgment (AC-SL-2 WIN/LOSS/DRAW)
##   - CP-3: _enter_beat_9_transition (AC-SL-3)
##   - 4-file disk accumulation across Ch1+Ch2 cycle (AC-SL-4)
##
## Pattern: G-4 Array[SaveContext] capture + G-28 per-callable disconnect +
##          G-15 before_test/after_test + G-6 in-body stub swap_out.
extends GdUnitTestSuite


const RUNNER_PATH: String = "res://src/core/scenario_runner.gd"


# ─── Per-test state ───────────────────────────────────────────────────────────

var _runner: Node
## Array[SaveContext] capture for save_checkpoint_requested emissions (G-4 pattern).
var _captured: Array[SaveContext] = []
## The test-side callable connected to GameBus.save_checkpoint_requested.
## Stored as a member so after_test can disconnect ONLY this callable (G-28).
var _capture_callable: Callable
## The active SaveManagerStub for Test 5. Null in all other tests.
var _stub: Node = null


# ─── Lifecycle ────────────────────────────────────────────────────────────────

func before_test() -> void:
	_runner = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(_runner)
	_captured = []
	_capture_callable = func(ctx: SaveContext) -> void:
		_captured.append(ctx)
	GameBus.save_checkpoint_requested.connect(_capture_callable)


func after_test() -> void:
	# G-28: disconnect ONLY the test-side capture; production autoload
	# subscriptions (SaveManager) remain intact.
	if GameBus.save_checkpoint_requested.is_connected(_capture_callable):
		GameBus.save_checkpoint_requested.disconnect(_capture_callable)
	# G-6: idempotent stub cleanup safety net for any test that uses it.
	SaveManagerStub.swap_out()
	_stub = null


# ─── Helpers ──────────────────────────────────────────────────────────────────

## Builds a minimal ChapterDefinition for use in emission tests.
## Use chapter_id="ch06_changbanpo", chapter_number=1 for AC-SL-1/SL-2 string
## assertions; use distinct ids for multi-chapter tests.
func _make_test_chapter(chapter_id: String, chapter_number: int, canonical: String) -> ChapterDefinition:
	var c: ChapterDefinition = ChapterDefinition.new()
	c.chapter_id = chapter_id
	c.chapter_number = chapter_number
	c.map_id = "test_map"
	c.author_draw_branch = false
	c.echo_threshold = 0
	c.branch_table = {
		"WIN_default":  canonical,
		"LOSS_default": "LOSS_%s_default" % chapter_id,
		"DRAW_default": "DRAW_%s_default" % chapter_id,
	}
	c.canonical_branch_key = canonical
	return c


## Drives the runner from LOADING (post-_set_chapters_for_test) through
## CHAPTER_START and into BEAT_1_ANCHOR, which fires CP-1.
## Returns immediately after the transition that fires CP-1.
func _drive_to_beat_1(runner: Node) -> void:
	var state_enum: Dictionary = ScenarioRunnerTestSeam.get_state_enum()
	# _transition_to(CHAPTER_START) fires _enter_chapter_start() which calls
	# _transition_to(BEAT_1_ANCHOR), which calls _enter_beat_1_anchor() → CP-1.
	runner._transition_to(state_enum["CHAPTER_START"] as int)


## Drives the runner from BEAT_1_ANCHOR through BEAT_5_BATTLE.
## Does not fire CP-1 again (that already happened at BEAT_1_ANCHOR entry).
func _advance_to_beat_5(runner: Node) -> void:
	runner.advance_beat()  # BEAT_1 -> BEAT_2
	runner.advance_beat()  # BEAT_2 -> BEAT_3
	runner.advance_beat()  # BEAT_3 -> BEAT_4
	runner.confirm_deployment()  # BEAT_4 -> BATTLE_LOADING -> BEAT_5


## Drives the runner from BEAT_5 through BEAT_7 (which fires CP-2), injecting
## the given outcome. Returns after CP-2 has fired synchronously.
func _advance_to_beat_7(runner: Node, chapter_id: String, outcome_result: BattleOutcome.Result) -> void:
	var outcome: BattleOutcome = BattleOutcome.new()
	outcome.result = outcome_result
	outcome.chapter_id = chapter_id
	runner._on_battle_outcome_resolved(outcome)
	# accept_outcome: BEAT_6 -> BEAT_7 (CP-2 fires synchronously in _enter_beat_7_judgment)
	#                 -> BEAT_8 (synchronous chained transition).
	runner.accept_outcome()


## Drives from BEAT_8 to BEAT_9 (which fires CP-3). For a single-chapter fixture
## this then chains to SCENARIO_END. For multi-chapter it chains to next CHAPTER_START
## which fires CP-1 for the next chapter.
func _advance_to_beat_9(runner: Node) -> void:
	runner.advance_beat()  # BEAT_8 -> BEAT_9_TRANSITION (CP-3 fires) -> SCENARIO_END or next ch


## Full single-chapter traversal that fires CP-1 + CP-2 + CP-3 in order.
func _run_full_chapter(runner: Node, chapter: ChapterDefinition, outcome_result: BattleOutcome.Result) -> void:
	_drive_to_beat_1(runner)
	_advance_to_beat_5(runner)
	_advance_to_beat_7(runner, chapter.chapter_id, outcome_result)
	_advance_to_beat_9(runner)


# ─── AC-SL-1: CP-1 emits at Beat 1 anchor with correct payload ───────────────


## AC-SL-1: CP-1 emits exactly once at BEAT_1_ANCHOR entry with
## ctx.chapter_id == "ch06_changbanpo", ctx.last_cp == 1, ctx.chapter_number == 1.
func test_cp_1_emits_at_beat_1_anchor_with_correct_payload() -> void:
	var ch: ChapterDefinition = _make_test_chapter(
		"ch06_changbanpo", 1, "WIN_changbanpo_default"
	)
	_runner._set_chapters_for_test([ch] as Array[ChapterDefinition], "test_ch1")

	_drive_to_beat_1(_runner)

	# CP-1 fires synchronously during _transition_to(CHAPTER_START).
	assert_int(_captured.size()).override_failure_message(
		"CP-1 must emit exactly once at BEAT_1_ANCHOR entry"
	).is_equal(1)
	var ctx: SaveContext = _captured[0]
	assert_str(String(ctx.chapter_id)).override_failure_message(
		"CP-1 chapter_id must match fixture"
	).is_equal("ch06_changbanpo")
	assert_int(ctx.chapter_number).override_failure_message(
		"CP-1 chapter_number must be 1"
	).is_equal(1)
	assert_int(ctx.last_cp).override_failure_message(
		"CP-1 last_cp must be 1"
	).is_equal(1)


# ─── AC-SL-2: CP-2 WIN/LOSS/DRAW emission ────────────────────────────────────


## AC-SL-2 (WIN): CP-2 emits at BEAT_7 with outcome WIN and correct branch_key.
func test_cp_2_emits_at_beat_7_with_win_outcome_and_branch_key() -> void:
	var ch: ChapterDefinition = _make_test_chapter(
		"ch06_changbanpo", 1, "WIN_changbanpo_default"
	)
	_runner._set_chapters_for_test([ch] as Array[ChapterDefinition], "test_ch1")

	_drive_to_beat_1(_runner)
	_advance_to_beat_5(_runner)
	_advance_to_beat_7(_runner, ch.chapter_id, BattleOutcome.Result.WIN)

	# After _advance_to_beat_7: _captured has CP-1 (index 0) + CP-2 (index 1).
	assert_int(_captured.size()).override_failure_message(
		"Must have CP-1 + CP-2 after Beat 7"
	).is_equal(2)
	var ctx: SaveContext = _captured[1]
	assert_int(ctx.last_cp).override_failure_message(
		"CP-2 last_cp must be 2"
	).is_equal(2)
	assert_int(ctx.outcome).override_failure_message(
		"CP-2 outcome must be WIN"
	).is_equal(BattleOutcome.Result.WIN)
	assert_str(String(ctx.branch_key)).override_failure_message(
		"CP-2 branch_key must match canonical WIN branch"
	).is_equal("WIN_changbanpo_default")


## AC-SL-2 (LOSS): CP-2 emits at BEAT_7 with outcome LOSS.
func test_cp_2_emits_with_loss_outcome() -> void:
	var ch: ChapterDefinition = _make_test_chapter(
		"ch06_changbanpo", 1, "WIN_changbanpo_default"
	)
	_runner._set_chapters_for_test([ch] as Array[ChapterDefinition], "test_ch1")

	_drive_to_beat_1(_runner)
	_advance_to_beat_5(_runner)
	_advance_to_beat_7(_runner, ch.chapter_id, BattleOutcome.Result.LOSS)

	assert_int(_captured.size()).override_failure_message(
		"Must have CP-1 + CP-2 after Beat 7 (LOSS)"
	).is_equal(2)
	var ctx: SaveContext = _captured[1]
	assert_int(ctx.last_cp).override_failure_message(
		"CP-2 last_cp must be 2"
	).is_equal(2)
	assert_int(ctx.outcome).override_failure_message(
		"CP-2 outcome must be LOSS"
	).is_equal(BattleOutcome.Result.LOSS)
	# Per F-DB-1 Row 4: LOSS resolves to branch_table["LOSS_default"] verbatim.
	assert_str(String(ctx.branch_key)).override_failure_message(
		"CP-2 branch_key for LOSS must resolve to LOSS_default branch per F-DB-1 Row 4"
	).is_equal("LOSS_ch06_changbanpo_default")


## AC-SL-2 (DRAW): CP-2 emits at BEAT_7 with outcome DRAW.
func test_cp_2_emits_with_draw_outcome() -> void:
	var ch: ChapterDefinition = _make_test_chapter(
		"ch06_changbanpo", 1, "WIN_changbanpo_default"
	)
	_runner._set_chapters_for_test([ch] as Array[ChapterDefinition], "test_ch1")

	_drive_to_beat_1(_runner)
	_advance_to_beat_5(_runner)
	_advance_to_beat_7(_runner, ch.chapter_id, BattleOutcome.Result.DRAW)

	assert_int(_captured.size()).override_failure_message(
		"Must have CP-1 + CP-2 after Beat 7 (DRAW)"
	).is_equal(2)
	var ctx: SaveContext = _captured[1]
	assert_int(ctx.last_cp).override_failure_message(
		"CP-2 last_cp must be 2"
	).is_equal(2)
	assert_int(ctx.outcome).override_failure_message(
		"CP-2 outcome must be DRAW"
	).is_equal(BattleOutcome.Result.DRAW)
	# Per F-DB-1 Row 1: DRAW outcome + author_draw_branch=false (fixture default)
	# falls BACK to the WIN_default key (NOT the DRAW_default key in branch_table).
	# Asserting WIN-canonical key documents the fallback path is wired.
	assert_str(String(ctx.branch_key)).override_failure_message(
		"CP-2 branch_key for DRAW (with author_draw_branch=false) must fallback to canonical WIN_default key per F-DB-1 Row 1"
	).is_equal("WIN_changbanpo_default")


# ─── AC-SL-3: CP-3 emits with completing chapter_number ──────────────────────


## AC-SL-3: CP-3 emits at BEAT_9_TRANSITION BEFORE _chapter_index advances.
## chapter_number must be 1 (the completing chapter), NOT 2 (the next).
func test_cp_3_emits_at_beat_9_with_completing_chapter_number() -> void:
	var ch: ChapterDefinition = _make_test_chapter(
		"ch06_changbanpo", 1, "WIN_changbanpo_default"
	)
	_runner._set_chapters_for_test([ch] as Array[ChapterDefinition], "test_ch1")

	_run_full_chapter(_runner, ch, BattleOutcome.Result.WIN)

	# After full traversal: captured = [CP-1, CP-2, CP-3].
	assert_int(_captured.size()).override_failure_message(
		"Single-chapter run must emit exactly 3 checkpoints"
	).is_equal(3)
	var cp_3: SaveContext = _captured[2]
	assert_int(cp_3.last_cp).override_failure_message(
		"CP-3 last_cp must be 3"
	).is_equal(3)
	assert_int(cp_3.chapter_number).override_failure_message(
		("CP-3 chapter_number must be 1 (the completing chapter, captured BEFORE "
		+ "_chapter_index advances)")
	).is_equal(1)
	# Single-chapter fixture: after CP-3 emits, runner must route to SCENARIO_END
	# (NOT LOADING — there's no next chapter to advance to). Guards the post-CP-3
	# routing branch in _enter_beat_9_transition (scenario_runner.gd:507-514).
	var state_enum: Dictionary = ScenarioRunnerTestSeam.get_state_enum()
	assert_int(_runner.get_state()).override_failure_message(
		"After CP-3 with single-chapter fixture, runner must transition to SCENARIO_END"
	).is_equal(state_enum["SCENARIO_END"] as int)


# ─── Ordering: CP-1 → CP-2 → CP-3 within a single chapter ───────────────────


## Asserts that all three checkpoints fire in CP-1 → CP-2 → CP-3 order within
## a single chapter traversal, and that no extra emissions occur.
func test_full_chapter_emits_three_checkpoints_in_order() -> void:
	var ch: ChapterDefinition = _make_test_chapter(
		"ch06_changbanpo", 1, "WIN_changbanpo_default"
	)
	_runner._set_chapters_for_test([ch] as Array[ChapterDefinition], "test_ch1")

	_run_full_chapter(_runner, ch, BattleOutcome.Result.WIN)

	assert_int(_captured.size()).override_failure_message(
		"Full single-chapter must emit exactly 3 save_checkpoint_requested signals"
	).is_equal(3)
	assert_int(_captured[0].last_cp).override_failure_message(
		"First emission must be CP-1"
	).is_equal(1)
	assert_int(_captured[1].last_cp).override_failure_message(
		"Second emission must be CP-2"
	).is_equal(2)
	assert_int(_captured[2].last_cp).override_failure_message(
		"Third emission must be CP-3"
	).is_equal(3)


# ─── AC-SL-1 idempotency: CP-1 fires exactly once ────────────────────────────


## AC-SL-1 idempotency: a complete chapter traversal fires EXACTLY 3 total
## checkpoint emissions — CP-1 is emitted exactly once at BEAT_1_ANCHOR entry,
## not on any subsequent beat transitions. Total == 3 proves no duplicate CP-1.
func test_cp_1_emits_exactly_once_not_on_subsequent_beats() -> void:
	var ch: ChapterDefinition = _make_test_chapter(
		"ch06_changbanpo", 1, "WIN_changbanpo_default"
	)
	_runner._set_chapters_for_test([ch] as Array[ChapterDefinition], "test_ch1")

	_run_full_chapter(_runner, ch, BattleOutcome.Result.WIN)

	# If CP-1 fired more than once, total would be > 3.
	assert_int(_captured.size()).override_failure_message(
		("Full single-chapter must emit exactly 3 checkpoints total — "
		+ "CP-1 must not re-fire on beats 2..9")
	).is_equal(3)
	# Additionally confirm only one emission has last_cp == 1.
	var cp1_count: int = 0
	for ctx: SaveContext in _captured:
		if ctx.last_cp == 1:
			cp1_count += 1
	assert_int(cp1_count).override_failure_message(
		"Exactly one CP-1 emission across the full chapter"
	).is_equal(1)


# ─── AC-SL-4: 4 distinct save files across Ch1 + Ch2 cycle ──────────────────


## AC-SL-4: After a full Ch1 traversal followed by Ch2 entering BEAT_1_ANCHOR,
## SaveManager must have written 4 distinct .res files to the slot directory:
##   ch_01_cp_1.res + ch_01_cp_2.res + ch_01_cp_3.res + ch_02_cp_1.res
##
## Uses SaveManagerStub (G-6: swap_out at end of test body; after_test is safety net).
## Awaits process_frame twice to drain SaveManager's CONNECT_DEFERRED handler queue.
func test_two_chapter_cycle_writes_four_distinct_save_files() -> void:
	# G-6: swap_in before add_child; set _save_root_override before _ready() fires.
	_stub = SaveManagerStub.swap_in()
	assert_object(_stub).override_failure_message(
		"SaveManagerStub.swap_in() must return a non-null stub node"
	).is_not_null()

	var ch1: ChapterDefinition = _make_test_chapter(
		"ch06_changbanpo", 1, "WIN_changbanpo_default"
	)
	var ch2: ChapterDefinition = _make_test_chapter(
		"ch07_jiangling", 2, "WIN_ch02_jiangling_default"
	)
	_runner._set_chapters_for_test(
		[ch1, ch2] as Array[ChapterDefinition], "test_two_ch"
	)

	# Drive Ch1 through BEAT_9. ScenarioRunner then auto-chains:
	#   BEAT_9_TRANSITION (CP-3 ch1) -> LOADING -> CHAPTER_START -> BEAT_1_ANCHOR (CP-1 ch2).
	# All transitions are synchronous, so after advance_beat() all 4 emissions have fired.
	_drive_to_beat_1(_runner)        # CP-1 ch1
	_advance_to_beat_5(_runner)
	_advance_to_beat_7(_runner, ch1.chapter_id, BattleOutcome.Result.WIN)  # CP-2 ch1
	_advance_to_beat_9(_runner)      # CP-3 ch1 + CP-1 ch2 (chained synchronously)

	# Confirm 4 emissions were captured by our test listener.
	assert_int(_captured.size()).override_failure_message(
		"Two-chapter cycle must emit 4 save_checkpoint_requested signals"
	).is_equal(4)

	# Drain SaveManager's CONNECT_DEFERRED handler queue (2 frames as per architecture note).
	# SaveManager subscribes to save_checkpoint_requested with CONNECT_DEFERRED;
	# two process_frame awaits ensure both the first and second deferred turn are processed.
	await get_tree().process_frame
	await get_tree().process_frame

	# Resolve the stub's temp save root for file-existence assertions.
	# Defensive cast: `Node.get(...)` returns Variant — null-cast to String would
	# crash on .rstrip(). Type-guard with `is String` before cast.
	var raw_root: Variant = _stub.get("_save_root_override")
	var save_root: String = (raw_root as String).rstrip("/") if raw_root is String else ""
	assert_bool(save_root.length() > 0).override_failure_message(
		"Stub _save_root_override must be a non-empty String"
	).is_true()

	# Assert all 4 expected files exist (per GDD §CR-SL-6 file-accumulation).
	var ch1_cp1: String = "%s/slot_1/ch_01_cp_1.res" % save_root
	var ch1_cp2: String = "%s/slot_1/ch_01_cp_2.res" % save_root
	var ch1_cp3: String = "%s/slot_1/ch_01_cp_3.res" % save_root
	var ch2_cp1: String = "%s/slot_1/ch_02_cp_1.res" % save_root

	assert_bool(FileAccess.file_exists(ch1_cp1)).override_failure_message(
		"ch_01_cp_1.res must exist after CP-1 of chapter 1"
	).is_true()
	assert_bool(FileAccess.file_exists(ch1_cp2)).override_failure_message(
		"ch_01_cp_2.res must exist after CP-2 of chapter 1"
	).is_true()
	assert_bool(FileAccess.file_exists(ch1_cp3)).override_failure_message(
		"ch_01_cp_3.res must exist after CP-3 of chapter 1"
	).is_true()
	assert_bool(FileAccess.file_exists(ch2_cp1)).override_failure_message(
		"ch_02_cp_1.res must exist after CP-1 of chapter 2 (chained BEAT_1_ANCHOR)"
	).is_true()

	# G-6: explicit in-body cleanup to avoid orphan detection between test body
	# and after_test.
	SaveManagerStub.swap_out()
	_stub = null
