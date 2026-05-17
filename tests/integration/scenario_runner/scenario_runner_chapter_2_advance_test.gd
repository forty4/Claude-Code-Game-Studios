## scenario_runner_chapter_2_advance_test.gd
##
## Integration test: chapter 1 -> chapter 2 automatic advance via mvp_shu.json
## fixture. Verifies that adding a second chapter entry to the scenario JSON
## drives the multi-chapter pipeline end-to-end without code changes.
extends GdUnitTestSuite


const SCENARIO_JSON: String = "res://assets/data/scenarios/mvp_shu.json"


func _drive_chapter_to_beat_9(runner: Node, chapter_id: String, result: BattleOutcome.Result = BattleOutcome.Result.WIN) -> void:
	runner.advance_beat()  # BEAT_1 -> BEAT_2
	runner.advance_beat()  # BEAT_2 -> BEAT_3
	runner.advance_beat()  # BEAT_3 -> BEAT_4
	runner.confirm_deployment()  # BEAT_4 -> BEAT_5 (via BATTLE_LOADING)
	var outcome: BattleOutcome = BattleOutcome.new()
	outcome.result = result
	outcome.chapter_id = chapter_id
	runner._on_battle_outcome_resolved(outcome)  # -> BEAT_6_RESULT
	runner.accept_outcome()  # BEAT_6 -> BEAT_7 -> BEAT_8
	runner.advance_beat()  # BEAT_8 -> BEAT_9 (advances or SCENARIO_END)


func test_scenario_advances_from_chapter_1_to_chapter_2_after_win() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var loaded: bool = runner.load_scenario(SCENARIO_JSON)
	assert_bool(loaded).override_failure_message(
		"mvp_shu.json must load with 2 chapters cleanly"
	).is_true()
	assert_int(runner.get_current_chapter_index()).is_equal(0)
	assert_str(runner.get_current_chapter().chapter_id).is_equal("ch01_taoyuan_yellow_turban")

	_drive_chapter_to_beat_9(runner, "ch01_taoyuan_yellow_turban")

	# After chapter 1 BEAT_9 with WIN, runner advances to chapter 2 (CHAPTER_START
	# synchronously chains into BEAT_1_ANCHOR per _enter_chapter_start).
	assert_int(runner.get_current_chapter_index()).is_equal(1)
	assert_str(runner.get_current_chapter().chapter_id).is_equal("ch02_hulao_gate")
	var state_enum: Dictionary = ScenarioRunnerTestSeam.get_state_enum()
	assert_int(runner.get_state()).is_equal(state_enum["BEAT_1_ANCHOR"] as int)


func test_scenario_completes_after_final_chapter_win() -> void:
	# Drives all chapters in mvp_shu.json (ch1 장판파 → ch2 장판교 → ch3 강하
	# 외곽 → ch4 적벽 prelude → ch5 적벽 본전) to a canonical-WIN finish and
	# asserts scenario_complete fires exactly once with every chapter outcome
	# archived. Updated as new chapters land — the semantic ("scenario ends
	# after the FINAL chapter") survives; the chapter count is data-driven
	# from the scenario JSON. Session-21: ch5 added.
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	runner.load_scenario(SCENARIO_JSON)
	var captured_chapters: Array[ChapterResult] = []
	var ch_capture: Callable = func(r: ChapterResult) -> void:
		captured_chapters.append(r)
	GameBus.chapter_completed.connect(ch_capture)
	var captured_scenario: Array[ScenarioResult] = []
	var sr_capture: Callable = func(r: ScenarioResult) -> void:
		captured_scenario.append(r)
	GameBus.scenario_complete.connect(sr_capture)

	# Phase A — drives all 10 chapters (prequel 황건적~신야 + 장판~적벽 main).
	_drive_chapter_to_beat_9(runner, "ch01_taoyuan_yellow_turban")
	_drive_chapter_to_beat_9(runner, "ch02_hulao_gate")
	_drive_chapter_to_beat_9(runner, "ch03_xuzhou_rescue")
	_drive_chapter_to_beat_9(runner, "ch04_bowang_slope")
	_drive_chapter_to_beat_9(runner, "ch05_xinye_fire")
	_drive_chapter_to_beat_9(runner, "ch06_changbanpo")
	_drive_chapter_to_beat_9(runner, "ch07_changban_bridge")
	_drive_chapter_to_beat_9(runner, "ch08_xiakou_outskirts")
	_drive_chapter_to_beat_9(runner, "ch09_chibi_prelude")
	_drive_chapter_to_beat_9(runner, "ch10_chibi_main")

	# Disconnect only our test captures (avoid severing production subscribers).
	if GameBus.chapter_completed.is_connected(ch_capture):
		GameBus.chapter_completed.disconnect(ch_capture)
	if GameBus.scenario_complete.is_connected(sr_capture):
		GameBus.scenario_complete.disconnect(sr_capture)

	assert_int(captured_chapters.size()).is_equal(10)
	# Prequel (Phase A).
	assert_str(captured_chapters[0].chapter_id).is_equal("ch01_taoyuan_yellow_turban")
	assert_str(captured_chapters[0].branch_path_id).is_equal("WIN_taoyuan_oath_held")
	assert_str(captured_chapters[1].chapter_id).is_equal("ch02_hulao_gate")
	assert_str(captured_chapters[1].branch_path_id).is_equal("WIN_hulao_lubu_held_off")
	assert_str(captured_chapters[2].chapter_id).is_equal("ch03_xuzhou_rescue")
	assert_str(captured_chapters[2].branch_path_id).is_equal("WIN_xuzhou_relieved")
	assert_str(captured_chapters[3].chapter_id).is_equal("ch04_bowang_slope")
	assert_str(captured_chapters[3].branch_path_id).is_equal("WIN_bowang_xiahoudun_routed")
	assert_str(captured_chapters[4].chapter_id).is_equal("ch05_xinye_fire")
	assert_str(captured_chapters[4].branch_path_id).is_equal("WIN_xinye_burning_retreat")
	# Main (장판~적벽).
	assert_str(captured_chapters[5].chapter_id).is_equal("ch06_changbanpo")
	assert_str(captured_chapters[5].branch_path_id).is_equal("WIN_changbanpo_default")
	assert_str(captured_chapters[6].chapter_id).is_equal("ch07_changban_bridge")
	assert_str(captured_chapters[6].branch_path_id).is_equal("WIN_changban_bridge_default")
	assert_str(captured_chapters[7].chapter_id).is_equal("ch08_xiakou_outskirts")
	assert_str(captured_chapters[7].branch_path_id).is_equal("WIN_xiakou_breakthrough")
	assert_str(captured_chapters[8].chapter_id).is_equal("ch09_chibi_prelude")
	assert_str(captured_chapters[8].branch_path_id).is_equal("WIN_chibi_prelude_alliance")
	assert_str(captured_chapters[9].chapter_id).is_equal("ch10_chibi_main")
	assert_str(captured_chapters[9].branch_path_id).is_equal("WIN_chibi_main_burn")
	assert_int(captured_scenario.size()).is_equal(1)
	assert_int(captured_scenario[0].chapter_outcomes.size()).is_equal(10)
	var state_enum: Dictionary = ScenarioRunnerTestSeam.get_state_enum()
	assert_int(runner.get_state()).is_equal(state_enum["SCENARIO_END"] as int)


## Chapter 1 WIN -> chapter 2 BattlePayload includes both 유비 (unit 0) and 장비
## (unit 1) per branch_overrides["WIN_changbanpo_default"]. Heroic branch.
func test_chapter_1_win_unlocks_chapter_2_heroic_deployment() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	runner.load_scenario(SCENARIO_JSON)
	# Phase A — advance through prequel chapters ch01~ch05 with WIN to reach ch06.
	_drive_chapter_to_beat_9(runner, "ch01_taoyuan_yellow_turban", BattleOutcome.Result.WIN)
	_drive_chapter_to_beat_9(runner, "ch02_hulao_gate", BattleOutcome.Result.WIN)
	_drive_chapter_to_beat_9(runner, "ch03_xuzhou_rescue", BattleOutcome.Result.WIN)
	_drive_chapter_to_beat_9(runner, "ch04_bowang_slope", BattleOutcome.Result.WIN)
	_drive_chapter_to_beat_9(runner, "ch05_xinye_fire", BattleOutcome.Result.WIN)
	_drive_chapter_to_beat_9(runner, "ch06_changbanpo", BattleOutcome.Result.WIN)
	# Now at ch07_changban_bridge BEAT_1_ANCHOR. Inspect the BattlePayload that BEAT_4 would emit.
	var payload: BattlePayload = runner.get_active_battle_config()
	# Heroic branch: 유비 (0) + 장비 (1) + 위 enemies (2, 3) = 4 units total.
	assert_int(payload.unit_roster.size()).override_failure_message(
		"WIN branch should deploy 2 player units + 2 enemies = 4; got %d" % payload.unit_roster.size()
	).is_equal(4)
	assert_bool(payload.unit_roster.has(0)).override_failure_message(
		"WIN branch must include 유비 (unit 0) in roster"
	).is_true()
	assert_bool(payload.deployment_positions.has(0)).override_failure_message(
		"WIN branch must include deployment position for 유비 (unit 0)"
	).is_true()


## Chapter 1 LOSS -> chapter 2 BattlePayload defaults: 장비 alone vs 2 enemies.
## Tragic branch (장비의 최후 setup).
func test_chapter_1_loss_keeps_chapter_2_tragic_deployment() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	runner.load_scenario(SCENARIO_JSON)
	# Phase A — advance through prequel chapters ch01~ch05 with WIN to reach ch06.
	_drive_chapter_to_beat_9(runner, "ch01_taoyuan_yellow_turban", BattleOutcome.Result.WIN)
	_drive_chapter_to_beat_9(runner, "ch02_hulao_gate", BattleOutcome.Result.WIN)
	_drive_chapter_to_beat_9(runner, "ch03_xuzhou_rescue", BattleOutcome.Result.WIN)
	_drive_chapter_to_beat_9(runner, "ch04_bowang_slope", BattleOutcome.Result.WIN)
	_drive_chapter_to_beat_9(runner, "ch05_xinye_fire", BattleOutcome.Result.WIN)
	# Then ch06 LOSS sets up ch07 tragic deployment via branch_overrides.
	_drive_chapter_to_beat_9(runner, "ch06_changbanpo", BattleOutcome.Result.LOSS)
	var payload: BattlePayload = runner.get_active_battle_config()
	# Tragic branch (default): 장비 (1) alone + 위 enemies (2, 3) = 3 units total.
	assert_int(payload.unit_roster.size()).override_failure_message(
		"LOSS branch should deploy 1 player unit + 2 enemies = 3; got %d" % payload.unit_roster.size()
	).is_equal(3)
	assert_bool(payload.unit_roster.has(0)).override_failure_message(
		"LOSS branch must NOT include 유비 (unit 0) in roster"
	).is_false()
	assert_bool(payload.unit_roster.has(1)).override_failure_message(
		"LOSS branch must include 장비 (unit 1) in roster"
	).is_true()
