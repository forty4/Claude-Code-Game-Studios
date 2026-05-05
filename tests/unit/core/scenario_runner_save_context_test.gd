## scenario_runner_save_context_test.gd
##
## Covers AC-SP-21 (3-CP save emission timing per ADR-0017 §Decision §Risks R-4
## + ADR-0003 §3-CP policy). Asserts CP-1, CP-2, CP-3 emit at the correct
## state-transition boundaries with all required SaveContext fields populated.
extends GdUnitTestSuite


# ─── AC-SP-21: 3-CP timing ────────────────────────────────────────────────────


## AC-SP-21: CP-1 emits at BEAT_1_ANCHOR entry.
func test_cp_1_emits_at_beat_1_anchor() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var chapter: ChapterDefinition = _make_test_chapter()
	runner._set_chapters_for_test([chapter] as Array[ChapterDefinition])
	var captured: Array[SaveContext] = []
	GameBus.save_checkpoint_requested.connect(func(ctx: SaveContext) -> void:
		captured.append(ctx)
	)
	var state_enum: Dictionary = ScenarioRunnerTestSeam.get_state_enum()
	runner._transition_to(state_enum["CHAPTER_START"] as int)
	# CHAPTER_START handler auto-advances to BEAT_1_ANCHOR which emits CP-1.
	for conn: Dictionary in GameBus.save_checkpoint_requested.get_connections():
		GameBus.save_checkpoint_requested.disconnect(conn["callable"] as Callable)
	assert_int(captured.size()).is_greater_equal(1)
	assert_int(captured[0].last_cp).is_equal(1)


## AC-SP-21: CP-1 + CP-2 + CP-3 emit in order with last_cp values 1 / 2 / 3.
func test_three_cps_emit_in_order() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var chapter: ChapterDefinition = _make_test_chapter()
	runner._set_chapters_for_test([chapter] as Array[ChapterDefinition])
	var captured: Array[SaveContext] = []
	GameBus.save_checkpoint_requested.connect(func(ctx: SaveContext) -> void:
		captured.append(ctx)
	)
	_run_full_chapter(runner, chapter, BattleOutcome.Result.WIN)
	for conn: Dictionary in GameBus.save_checkpoint_requested.get_connections():
		GameBus.save_checkpoint_requested.disconnect(conn["callable"] as Callable)
	assert_int(captured.size()).is_equal(3)
	assert_int(captured[0].last_cp).is_equal(1)
	assert_int(captured[1].last_cp).is_equal(2)
	assert_int(captured[2].last_cp).is_equal(3)


## AC-SP-21: CP-2 SaveContext.outcome matches BattleOutcome received at BEAT_5.
func test_cp_2_outcome_matches_battle_result() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var chapter: ChapterDefinition = _make_test_chapter()
	runner._set_chapters_for_test([chapter] as Array[ChapterDefinition])
	var captured: Array[SaveContext] = []
	GameBus.save_checkpoint_requested.connect(func(ctx: SaveContext) -> void:
		captured.append(ctx)
	)
	_run_full_chapter(runner, chapter, BattleOutcome.Result.LOSS)
	for conn: Dictionary in GameBus.save_checkpoint_requested.get_connections():
		GameBus.save_checkpoint_requested.disconnect(conn["callable"] as Callable)
	assert_int(captured.size()).is_equal(3)
	var cp_2: SaveContext = captured[1]
	assert_int(cp_2.outcome).is_equal(BattleOutcome.Result.LOSS)


## AC-SP-21: CP-3 SaveContext fields fully populated (chapter_id + branch_key + echo_count).
func test_cp_3_fields_populated() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var chapter: ChapterDefinition = _make_test_chapter()
	runner._set_chapters_for_test([chapter] as Array[ChapterDefinition])
	var captured: Array[SaveContext] = []
	GameBus.save_checkpoint_requested.connect(func(ctx: SaveContext) -> void:
		captured.append(ctx)
	)
	_run_full_chapter(runner, chapter, BattleOutcome.Result.WIN)
	for conn: Dictionary in GameBus.save_checkpoint_requested.get_connections():
		GameBus.save_checkpoint_requested.disconnect(conn["callable"] as Callable)
	var cp_3: SaveContext = captured[2]
	assert_str(String(cp_3.chapter_id)).is_equal(chapter.chapter_id)
	assert_str(String(cp_3.branch_key)).is_not_empty()
	assert_int(cp_3.echo_count).is_equal(0)


# ─── Helpers ──────────────────────────────────────────────────────────────────


func _make_test_chapter() -> ChapterDefinition:
	var c: ChapterDefinition = ChapterDefinition.new()
	c.chapter_id = "test_ch"
	c.chapter_number = 1
	c.map_id = "test_map"
	c.author_draw_branch = false
	c.echo_threshold = 0
	c.branch_table = {
		"WIN_default":  "WIN_test_default",
		"LOSS_default": "LOSS_test_default",
	}
	c.canonical_branch_key = "WIN_test_default"
	return c


func _run_full_chapter(runner: Node, chapter: ChapterDefinition, outcome_result: BattleOutcome.Result) -> void:
	var state_enum: Dictionary = ScenarioRunnerTestSeam.get_state_enum()
	runner._transition_to(state_enum["CHAPTER_START"] as int)
	runner.advance_beat()
	runner.advance_beat()
	runner.advance_beat()
	runner.confirm_deployment()
	var outcome: BattleOutcome = BattleOutcome.new()
	outcome.result = outcome_result
	outcome.chapter_id = chapter.chapter_id
	runner._on_battle_outcome_resolved(outcome)
	runner.accept_outcome()
	runner.advance_beat()
