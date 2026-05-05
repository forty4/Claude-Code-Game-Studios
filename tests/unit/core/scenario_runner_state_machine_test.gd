## scenario_runner_state_machine_test.gd
##
## Covers AC-SP-3 (CR-3 tri-state preservation), AC-SP-13 (forward-only invariant),
## AC-SP-25 (no _process body) per ADR-0017 §Decision §State Machine Form.
##
## Uses isolated runner instances (via load(...).new()) per G-3 + G-10 to avoid
## polluting the live /root/ScenarioRunner autoload.
extends GdUnitTestSuite


const RUNNER_PATH: String = "res://src/core/scenario_runner.gd"


# ─── AC-SP-25: no _process body (event-driven invariant) ──────────────────────


## AC-SP-25: ScenarioRunner has no _process or _physics_process body.
func test_scenario_runner_no_process_body() -> void:
	var content: String = FileAccess.get_file_as_string(RUNNER_PATH)
	assert_str(content).is_not_empty()
	# grep -E '^func _process\(' returns 0 matches.
	var has_process: bool = false
	var has_physics: bool = false
	for line: String in content.split("\n"):
		if line.begins_with("func _process(") or line.begins_with("func _process ("):
			has_process = true
		if line.begins_with("func _physics_process(") or line.begins_with("func _physics_process ("):
			has_physics = true
	assert_bool(has_process).override_failure_message(
		"AC-SP-25: ScenarioRunner must NOT declare func _process()"
	).is_false()
	assert_bool(has_physics).override_failure_message(
		"AC-SP-25: ScenarioRunner must NOT declare func _physics_process()"
	).is_false()


# ─── AC-SP-13(b): no `_state =` outside _transition_to / load_scenario ──────


## AC-SP-13(b): grep verifies no direct `_state =` assignment exists outside
## the _transition_to() / load_scenario() / _set_chapters_for_test() bodies.
## This is a structural lint mirror — same check as
## tools/ci/lint_scenario_runner_state_match_exhaustive.sh.
func test_no_arbitrary_state_jump_in_source() -> void:
	var content: String = FileAccess.get_file_as_string(RUNNER_PATH)
	var lines: PackedStringArray = content.split("\n")
	var in_safe_func: bool = false
	var violations: Array[String] = []
	for i in lines.size():
		var line: String = lines[i]
		# Track function-scope. Safe functions: _transition_to, load_scenario, _set_chapters_for_test,
		# reset_for_tests (test seam mirroring DestinyState + StoryEvent + BalanceConstants pattern).
		if line.begins_with("func _transition_to") \
				or line.begins_with("func load_scenario") \
				or line.begins_with("func _set_chapters_for_test") \
				or line.begins_with("func reset_for_tests"):
			in_safe_func = true
			continue
		if line.begins_with("func "):
			in_safe_func = false
		# Skip comments and var declarations.
		var trimmed: String = line.strip_edges()
		if trimmed.begins_with("#") or trimmed.begins_with("##"):
			continue
		if trimmed.begins_with("var _state"):
			continue
		# Match `_state =` followed by non-`=` (excludes `_state ==` comparisons).
		if not in_safe_func:
			var re: RegEx = RegEx.new()
			re.compile("_state\\s*=[^=]")
			if re.search(line) != null:
				violations.append("line %d: %s" % [i + 1, line])
	assert_array(violations).override_failure_message(
		"AC-SP-13(b): _state assignments outside safe functions: %s" % str(violations)
	).is_empty()


# ─── AC-SP-3: CR-3 tri-state preservation (no synthesis / no override) ───────


## AC-SP-3: WIN outcome at BEAT_5 propagates through to BEAT_7 with result==WIN.
func test_cr_3_win_outcome_preserved_through_beat_7() -> void:
	var runner: Node = load(RUNNER_PATH).new()
	auto_free(runner)
	var chapter: ChapterDefinition = _make_minimal_chapter()
	runner._set_chapters_for_test([chapter] as Array[ChapterDefinition])
	# Drive to BEAT_5_BATTLE
	_advance_to_beat_5(runner)
	# Inject WIN outcome
	var outcome: BattleOutcome = BattleOutcome.new()
	outcome.result = BattleOutcome.Result.WIN
	outcome.chapter_id = chapter.chapter_id
	runner._on_battle_outcome_resolved(outcome)
	# accept_outcome drives BEAT_6 -> BEAT_7 -> BEAT_8 (synchronous)
	runner.accept_outcome()
	# Verify _last_battle_outcome.result preserved
	assert_int(runner._last_battle_outcome.result).is_equal(BattleOutcome.Result.WIN)


## AC-SP-3: LOSS outcome propagates without coercion to DRAW.
func test_cr_3_loss_outcome_preserved() -> void:
	var runner: Node = load(RUNNER_PATH).new()
	auto_free(runner)
	var chapter: ChapterDefinition = _make_minimal_chapter()
	runner._set_chapters_for_test([chapter] as Array[ChapterDefinition])
	_advance_to_beat_5(runner)
	var outcome: BattleOutcome = BattleOutcome.new()
	outcome.result = BattleOutcome.Result.LOSS
	outcome.chapter_id = chapter.chapter_id
	runner._on_battle_outcome_resolved(outcome)
	assert_int(runner._last_battle_outcome.result).is_equal(BattleOutcome.Result.LOSS)


## AC-SP-3: DRAW outcome propagates without promotion to WIN or LOSS.
func test_cr_3_draw_outcome_preserved() -> void:
	var runner: Node = load(RUNNER_PATH).new()
	auto_free(runner)
	var chapter: ChapterDefinition = _make_minimal_chapter()
	runner._set_chapters_for_test([chapter] as Array[ChapterDefinition])
	_advance_to_beat_5(runner)
	var outcome: BattleOutcome = BattleOutcome.new()
	outcome.result = BattleOutcome.Result.DRAW
	outcome.chapter_id = chapter.chapter_id
	runner._on_battle_outcome_resolved(outcome)
	assert_int(runner._last_battle_outcome.result).is_equal(BattleOutcome.Result.DRAW)


# ─── AC-SP-13(a): forward-only invariant ──────────────────────────────────────


## AC-SP-13(a): The only legal backward transition is BEAT_6_RESULT -> BEAT_4_PREP.
func test_legal_backward_transition_beat_6_to_beat_4_succeeds() -> void:
	var runner: Node = load(RUNNER_PATH).new()
	auto_free(runner)
	var chapter: ChapterDefinition = _make_minimal_chapter()
	runner._set_chapters_for_test([chapter] as Array[ChapterDefinition])
	_advance_to_beat_5(runner)
	var outcome: BattleOutcome = BattleOutcome.new()
	outcome.result = BattleOutcome.Result.LOSS
	outcome.chapter_id = chapter.chapter_id
	runner._on_battle_outcome_resolved(outcome)
	# At BEAT_6_RESULT now. Retry transitions back to BEAT_4_PREP.
	var state_enum: Dictionary = ScenarioRunnerTestSeam.get_state_enum()
	assert_int(runner.get_state()).is_equal(state_enum["BEAT_6_RESULT"] as int)
	runner.retry_outcome()
	assert_int(runner.get_state()).is_equal(state_enum["BEAT_4_PREP"] as int)


# ─── Helpers ──────────────────────────────────────────────────────────────────


func _make_minimal_chapter() -> ChapterDefinition:
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


## Drives runner state from CHAPTER_START to BEAT_5_BATTLE.
func _advance_to_beat_5(runner: Node) -> void:
	var state_enum: Dictionary = ScenarioRunnerTestSeam.get_state_enum()
	# Manual transition through CHAPTER_START -> BEAT_1 -> ... -> BEAT_5
	# Use _transition_to since runner is fresh.
	runner._transition_to(state_enum["CHAPTER_START"] as int)
	# CHAPTER_START handler auto-advances to BEAT_1_ANCHOR.
	runner.advance_beat()  # BEAT_1 -> BEAT_2
	runner.advance_beat()  # BEAT_2 -> BEAT_3
	runner.advance_beat()  # BEAT_3 -> BEAT_4
	runner.confirm_deployment()  # BEAT_4 -> BATTLE_LOADING -> BEAT_5
