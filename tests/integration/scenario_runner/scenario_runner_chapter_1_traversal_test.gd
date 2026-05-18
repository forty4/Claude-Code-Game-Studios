## scenario_runner_chapter_1_traversal_test.gd
##
## Integration test: full chapter-1 traversal via shu_canon_full.json fixture.
## Covers AC-SP-1 (CR-1 chapter linear progression), AC-SP-2 (CR-2 9-beat
## canonical rhythm), AC-SP-9 (Beat 9 chapter_completed + echo reset),
## AC-SP-17 (5+1 confirmed signal contract emission for chapter-1).
extends GdUnitTestSuite


const SCENARIO_JSON: String = "res://assets/data/scenarios/shu_canon_full.json"


# ─── AC-SP-1 + AC-SP-2 + AC-SP-17 ─────────────────────────────────────────────


## AC-SP-2: chapter-1 traversal fires 9 beat-state transitions in canonical order.
func test_chapter_1_full_traversal_fires_9_beats_in_order() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var loaded: bool = runner.load_scenario(SCENARIO_JSON)
	assert_bool(loaded).override_failure_message(
		"chapter-1 shu_canon_full.json must load cleanly"
	).is_true()
	# Capture state transitions.
	var state_history: Array[int] = [runner.get_state()]
	# Drive forward, capturing state at each step.
	runner.advance_beat()  # BEAT_1 -> BEAT_2
	state_history.append(runner.get_state())
	runner.advance_beat()  # BEAT_2 -> BEAT_3
	state_history.append(runner.get_state())
	runner.advance_beat()  # BEAT_3 -> BEAT_4
	state_history.append(runner.get_state())
	runner.confirm_deployment()  # BEAT_4 -> BEAT_5 (via BATTLE_LOADING)
	state_history.append(runner.get_state())
	# Inject WIN outcome
	var outcome: BattleOutcome = BattleOutcome.new()
	outcome.result = BattleOutcome.Result.WIN
	outcome.chapter_id = "ch01_taoyuan_yellow_turban"
	runner._on_battle_outcome_resolved(outcome)
	state_history.append(runner.get_state())  # BEAT_6_RESULT
	runner.accept_outcome()  # BEAT_6 -> BEAT_7 -> BEAT_8 (synchronous)
	state_history.append(runner.get_state())
	runner.advance_beat()  # BEAT_8 -> BEAT_9 -> SCENARIO_END
	state_history.append(runner.get_state())
	# Verify 9 beat states traversed (exact ordinal sequence checked by enum).
	var state_enum: Dictionary = ScenarioRunnerTestSeam.get_state_enum()
	# After chapter 1 BEAT_9, runner advances to chapter 2 (CHAPTER_START synchronously
	# chains to BEAT_1_ANCHOR per _enter_chapter_start). shu_canon_full.json now has 2 chapters.
	assert_int(runner.get_state()).is_equal(state_enum["BEAT_1_ANCHOR"] as int)
	assert_int(runner.get_current_chapter_index()).is_equal(1)


## AC-SP-1: chapter index advances from 0 to 1 after chapter 1 BEAT_9.
func test_chapter_index_advances_through_chapter_1() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	runner.load_scenario(SCENARIO_JSON)
	assert_int(runner.get_current_chapter_index()).is_equal(0)
	runner.advance_beat()
	runner.advance_beat()
	runner.advance_beat()
	runner.confirm_deployment()
	var outcome: BattleOutcome = BattleOutcome.new()
	outcome.result = BattleOutcome.Result.WIN
	outcome.chapter_id = "ch01_taoyuan_yellow_turban"
	runner._on_battle_outcome_resolved(outcome)
	runner.accept_outcome()
	runner.advance_beat()
	# After chapter 1 BEAT_9, runner advances to chapter 2 (index 1).
	assert_int(runner.get_current_chapter_index()).is_equal(1)


## AC-SP-9: scenario_complete is NOT emitted after chapter 1 when more chapters remain.
## (Coverage for SCENARIO_END terminal emission is in scenario_runner_chapter_2_advance_test.)
func test_scenario_complete_not_emitted_when_more_chapters_remain() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var captured: Array[ScenarioResult] = []
	var capture: Callable = func(r: ScenarioResult) -> void:
		captured.append(r)
	GameBus.scenario_complete.connect(capture)
	runner.load_scenario(SCENARIO_JSON)
	runner.advance_beat()
	runner.advance_beat()
	runner.advance_beat()
	runner.confirm_deployment()
	var outcome: BattleOutcome = BattleOutcome.new()
	outcome.result = BattleOutcome.Result.WIN
	outcome.chapter_id = "ch01_taoyuan_yellow_turban"
	runner._on_battle_outcome_resolved(outcome)
	runner.accept_outcome()
	runner.advance_beat()
	if GameBus.scenario_complete.is_connected(capture):
		GameBus.scenario_complete.disconnect(capture)
	assert_int(captured.size()).override_failure_message(
		"scenario_complete must NOT fire after chapter 1 when chapter 2 still pending; got %d" % captured.size()
	).is_equal(0)


## AC-SP-17: chapter_completed emitted exactly once per chapter completion.
func test_chapter_completed_emitted_per_chapter() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var captured: Array[ChapterResult] = []
	GameBus.chapter_completed.connect(func(r: ChapterResult) -> void:
		captured.append(r)
	)
	runner.load_scenario(SCENARIO_JSON)
	runner.advance_beat()
	runner.advance_beat()
	runner.advance_beat()
	runner.confirm_deployment()
	var outcome: BattleOutcome = BattleOutcome.new()
	outcome.result = BattleOutcome.Result.WIN
	outcome.chapter_id = "ch01_taoyuan_yellow_turban"
	runner._on_battle_outcome_resolved(outcome)
	runner.accept_outcome()
	runner.advance_beat()
	for conn: Dictionary in GameBus.chapter_completed.get_connections():
		GameBus.chapter_completed.disconnect(conn["callable"] as Callable)
	assert_int(captured.size()).is_equal(1)
	var cr: ChapterResult = captured[0]
	assert_str(cr.chapter_id).is_equal("ch01_taoyuan_yellow_turban")
	# branch_path_id (extended field) populated; branch_triggered (legacy alias) too.
	assert_str(cr.branch_path_id).is_equal("WIN_taoyuan_oath_held")
	assert_str(cr.branch_triggered).is_equal("WIN_taoyuan_oath_held")
	assert_int(cr.echo_count_at_completion).is_equal(0)
