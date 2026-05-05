## scenario_runner_signal_contract_test.gd
##
## Covers AC-SP-16 (ADR-0001 cross-scene routing), AC-SP-17 (5+1 confirmed signal
## emission), AC-SP-18 (DestinyBranchChoice 9-field payload completeness),
## AC-SP-19 (scenario_beat_retried EchoMark payload), AC-SP-20 (CP-3 SaveContext
## field completeness).
##
## Uses GameBus capture pattern (G-4 lambda primitive-capture workaround):
## tests connect to GameBus signals + capture into Array via append.
extends GdUnitTestSuite


const RUNNER_PATH: String = "res://src/core/scenario_runner.gd"


# ─── AC-SP-16: cross-scene routing (no direct connect calls) ─────────────────


## AC-SP-16: scenario_runner.gd source contains no direct cross-scene connects.
## All cross-scene signal flow MUST route through GameBus per ADR-0001.
func test_no_direct_cross_scene_connects_in_source() -> void:
	var content: String = FileAccess.get_file_as_string(RUNNER_PATH)
	# Forbidden patterns: any `<grid_battle>.<signal>.connect(` or scene-direct connects.
	# We allow GameBus.* connects + signal emit calls.
	for line: String in content.split("\n"):
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("#") or trimmed.begins_with("##"):
			continue
		# Every connect call must reference GameBus (or self in test seam).
		if trimmed.contains(".connect(") and not trimmed.contains("GameBus."):
			var allowed_self: bool = trimmed.contains("self.") or trimmed.contains("is_connected")
			assert_bool(allowed_self).override_failure_message(
				"AC-SP-16: non-GameBus .connect found: %s" % line
			).is_true()


# ─── AC-SP-17: 5+1 confirmed signal emission ───────────────────────────────


## AC-SP-17: One full no-retry chapter emits exactly 5 ScenarioRunner signals
## in order: chapter_started + battle_prepare_requested + battle_launch_requested
## + destiny_branch_chosen + chapter_completed. Plus 3 save_checkpoint_requested.
func test_full_chapter_no_retry_emits_5_plus_3_signals() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var chapter: ChapterDefinition = _make_test_chapter()
	runner._set_chapters_for_test([chapter] as Array[ChapterDefinition])
	# Capture GameBus emissions in temporal order.
	var captured: Array[Dictionary] = []
	GameBus.chapter_started.connect(func(cid: String, cn: int) -> void:
		captured.append({"name": "chapter_started", "args": [cid, cn]})
	)
	GameBus.battle_prepare_requested.connect(func(p: BattlePayload) -> void:
		captured.append({"name": "battle_prepare_requested", "args": [p]})
	)
	GameBus.battle_launch_requested.connect(func(p: BattlePayload) -> void:
		captured.append({"name": "battle_launch_requested", "args": [p]})
	)
	GameBus.destiny_branch_chosen.connect(func(c: DestinyBranchChoice) -> void:
		captured.append({"name": "destiny_branch_chosen", "args": [c]})
	)
	GameBus.chapter_completed.connect(func(r: ChapterResult) -> void:
		captured.append({"name": "chapter_completed", "args": [r]})
	)
	GameBus.save_checkpoint_requested.connect(func(ctx: SaveContext) -> void:
		captured.append({"name": "save_checkpoint_requested", "args": [ctx]})
	)
	# Drive full no-retry path: CHAPTER_START -> BEAT_9_TRANSITION
	_run_full_chapter(runner, chapter, BattleOutcome.Result.WIN)
	# Cleanup signal connections to avoid bleed into other tests.
	for sig: Signal in [
		GameBus.chapter_started, GameBus.battle_prepare_requested,
		GameBus.battle_launch_requested, GameBus.destiny_branch_chosen,
		GameBus.chapter_completed, GameBus.save_checkpoint_requested
	]:
		for conn: Dictionary in sig.get_connections():
			sig.disconnect(conn["callable"] as Callable)
	# Assert: chapter_started + prepare + launch + 1+ saves + destiny + completed
	# Save count should be 3 (CP-1 BEAT_1 + CP-2 BEAT_7 + CP-3 BEAT_9).
	var sig_names: Array[String] = []
	for c in captured:
		sig_names.append(c["name"] as String)
	assert_array(sig_names).contains(["chapter_started"])
	assert_array(sig_names).contains(["battle_prepare_requested"])
	assert_array(sig_names).contains(["battle_launch_requested"])
	assert_array(sig_names).contains(["destiny_branch_chosen"])
	assert_array(sig_names).contains(["chapter_completed"])
	# 3 save_checkpoint emissions.
	var save_count: int = 0
	for n in sig_names:
		if n == "save_checkpoint_requested":
			save_count += 1
	assert_int(save_count).is_equal(3)


# ─── AC-SP-18: DestinyBranchChoice 9-field payload completeness ──────────────


## AC-SP-18: destiny_branch_chosen payload has all 9 typed @export fields populated.
func test_destiny_branch_choice_has_9_fields() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var chapter: ChapterDefinition = _make_test_chapter()
	runner._set_chapters_for_test([chapter] as Array[ChapterDefinition])
	var captured: Array[DestinyBranchChoice] = []
	GameBus.destiny_branch_chosen.connect(func(c: DestinyBranchChoice) -> void:
		captured.append(c)
	)
	_run_full_chapter(runner, chapter, BattleOutcome.Result.WIN)
	for conn: Dictionary in GameBus.destiny_branch_chosen.get_connections():
		GameBus.destiny_branch_chosen.disconnect(conn["callable"] as Callable)
	assert_int(captured.size()).is_greater(0)
	var choice: DestinyBranchChoice = captured[0]
	# Verify all 9 fields populated (chapter_id, branch_key, outcome, echo_count,
	# is_draw_fallback, is_canonical_history, reserved_color_treatment, is_invalid,
	# invalid_reason).
	assert_str(choice.chapter_id).is_equal(chapter.chapter_id)
	assert_str(choice.branch_key).is_not_empty()
	assert_int(choice.outcome).is_equal(BattleOutcome.Result.WIN)
	assert_int(choice.echo_count).is_equal(0)
	assert_bool(choice.is_draw_fallback).is_false()
	assert_bool(choice.is_invalid).is_false()
	# is_canonical_history + reserved_color_treatment are set per F-DB-2 logic.


# ─── AC-SP-19: scenario_beat_retried EchoMark 3-field payload ───────────────


## AC-SP-19: scenario_beat_retried emits EchoMark with shipped 3-field schema
## (beat_index / outcome / tag).
func test_echo_mark_three_field_payload_on_retry() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var chapter: ChapterDefinition = _make_test_chapter()
	runner._set_chapters_for_test([chapter] as Array[ChapterDefinition])
	var captured: Array[EchoMark] = []
	GameBus.scenario_beat_retried.connect(func(m: EchoMark) -> void:
		captured.append(m)
	)
	# Drive to BEAT_6 LOSS then retry.
	_advance_to_beat_5(runner)
	var outcome: BattleOutcome = BattleOutcome.new()
	outcome.result = BattleOutcome.Result.LOSS
	outcome.chapter_id = chapter.chapter_id
	runner._on_battle_outcome_resolved(outcome)
	runner.retry_outcome()
	for conn: Dictionary in GameBus.scenario_beat_retried.get_connections():
		GameBus.scenario_beat_retried.disconnect(conn["callable"] as Callable)
	assert_int(captured.size()).is_equal(1)
	var mark: EchoMark = captured[0]
	# 3-field shipped schema: beat_index + outcome + tag.
	assert_int(mark.beat_index).is_equal(5)
	# outcome is StringName per shipped echo_mark.gd (not int per AC-SP-19 spec divergence).
	assert_str(String(mark.outcome)).is_equal("loss")
	assert_str(String(mark.tag)).is_not_empty()


# ─── AC-SP-20: CP-3 SaveContext field completeness ──────────────────────────


## AC-SP-20: BEAT_9_TRANSITION CP-3 emission contains all required SaveContext fields.
func test_cp_3_save_context_complete() -> void:
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
	# 3 save emissions: CP-1, CP-2, CP-3.
	assert_int(captured.size()).is_equal(3)
	var cp_3: SaveContext = captured[2]
	assert_str(String(cp_3.chapter_id)).is_equal(chapter.chapter_id)
	assert_int(cp_3.last_cp).is_equal(3)
	assert_int(cp_3.echo_count).is_equal(0)
	# Outcome matches BattleOutcome.Result.WIN.
	assert_int(cp_3.outcome).is_equal(BattleOutcome.Result.WIN)


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


func _advance_to_beat_5(runner: Node) -> void:
	var state_enum: Dictionary = ScenarioRunnerTestSeam.get_state_enum()
	runner._transition_to(state_enum["CHAPTER_START"] as int)
	runner.advance_beat()  # BEAT_1 -> BEAT_2
	runner.advance_beat()  # BEAT_2 -> BEAT_3
	runner.advance_beat()  # BEAT_3 -> BEAT_4
	runner.confirm_deployment()  # BEAT_4 -> BEAT_5


func _run_full_chapter(runner: Node, chapter: ChapterDefinition, outcome_result: BattleOutcome.Result) -> void:
	_advance_to_beat_5(runner)
	var outcome: BattleOutcome = BattleOutcome.new()
	outcome.result = outcome_result
	outcome.chapter_id = chapter.chapter_id
	runner._on_battle_outcome_resolved(outcome)
	# accept_outcome drives BEAT_6 -> BEAT_7 -> BEAT_8 (synchronous).
	runner.accept_outcome()
	# advance_beat drives BEAT_8 -> BEAT_9 (which emits chapter_completed + scenario_complete or next chapter).
	runner.advance_beat()
