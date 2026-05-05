## scenario_runner_retry_loop_test.gd
##
## Covers AC-SP-5 (CR-7 echo accumulation + retry signal emission) per F-SP-3
## v2.2 systems-designer B-1 invariant.
extends GdUnitTestSuite


# ─── AC-SP-5: echo_count++ on retry, reset at Beat 9 ─────────────────────────


## AC-SP-5: 3 retries accumulate echo_count == 3.
func test_three_retries_accumulate_echo_count() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var chapter: ChapterDefinition = _make_test_chapter()
	runner._set_chapters_for_test([chapter] as Array[ChapterDefinition])
	# Drive 3 retry cycles, each preceded by re-running BEAT_4 -> BEAT_5 -> BEAT_6.
	for i in 3:
		_advance_to_beat_6_loss(runner, chapter)
		runner.retry_outcome()
	# echo_count should be 3 at this point.
	assert_int(runner.get_current_echo_count()).is_equal(3)


## AC-SP-5: echo_count resets to 0 at BEAT_9_TRANSITION.
func test_echo_count_resets_at_beat_9() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var chapter: ChapterDefinition = _make_test_chapter()
	runner._set_chapters_for_test([chapter] as Array[ChapterDefinition])
	_advance_to_beat_6_loss(runner, chapter)
	runner.retry_outcome()
	# echo_count == 1 now. Drive forward to BEAT_9.
	_advance_to_beat_6_with_outcome(runner, chapter, BattleOutcome.Result.WIN)
	runner.accept_outcome()  # BEAT_6 -> BEAT_7 -> BEAT_8 (synchronous)
	runner.advance_beat()    # BEAT_8 -> BEAT_9 (emits chapter_completed + resets echo)
	assert_int(runner.get_current_echo_count()).is_equal(0)


## AC-SP-5: retry on WIN outcome blocked (CR-8 violation).
func test_retry_on_win_blocked() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var chapter: ChapterDefinition = _make_test_chapter()
	runner._set_chapters_for_test([chapter] as Array[ChapterDefinition])
	_advance_to_beat_6_with_outcome(runner, chapter, BattleOutcome.Result.WIN)
	# retry_outcome on WIN should NOT increment echo_count.
	runner.retry_outcome()
	assert_int(runner.get_current_echo_count()).is_equal(0)


## AC-SP-5: scenario_beat_retried emitted exactly N times for N retries.
func test_scenario_beat_retried_emitted_per_retry() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var chapter: ChapterDefinition = _make_test_chapter()
	runner._set_chapters_for_test([chapter] as Array[ChapterDefinition])
	var captured: Array[EchoMark] = []
	GameBus.scenario_beat_retried.connect(func(m: EchoMark) -> void:
		captured.append(m)
	)
	for i in 3:
		_advance_to_beat_6_loss(runner, chapter)
		runner.retry_outcome()
	for conn: Dictionary in GameBus.scenario_beat_retried.get_connections():
		GameBus.scenario_beat_retried.disconnect(conn["callable"] as Callable)
	assert_int(captured.size()).is_equal(3)


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


## Drives runner state to BEAT_6_RESULT with LOSS outcome, ready for retry.
func _advance_to_beat_6_loss(runner: Node, chapter: ChapterDefinition) -> void:
	_advance_to_beat_6_with_outcome(runner, chapter, BattleOutcome.Result.LOSS)


func _advance_to_beat_6_with_outcome(runner: Node, chapter: ChapterDefinition, outcome_result: BattleOutcome.Result) -> void:
	var state_enum: Dictionary = ScenarioRunnerTestSeam.get_state_enum()
	# If runner is at BEAT_4_PREP (post-retry), drive directly forward.
	if runner.get_state() == (state_enum["BEAT_4_PREP"] as int):
		runner.confirm_deployment()  # BEAT_4 -> BATTLE_LOADING -> BEAT_5
	elif runner.get_state() == (state_enum["LOADING"] as int):
		runner._transition_to(state_enum["CHAPTER_START"] as int)
		runner.advance_beat()
		runner.advance_beat()
		runner.advance_beat()
		runner.confirm_deployment()
	# Inject outcome at BEAT_5_BATTLE.
	var outcome: BattleOutcome = BattleOutcome.new()
	outcome.result = outcome_result
	outcome.chapter_id = chapter.chapter_id
	runner._on_battle_outcome_resolved(outcome)
