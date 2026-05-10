## chapter_1_full_arc_test.gd
##
## Sprint-8 S8-11 — chapter-1 (장판파) end-to-end integration vertical-slice run.
##
## Validates the architecture chain shipped sprint-7+8 coordinates end-to-end:
##   ScenarioRunner (state machine + signal emit)
##   → DestinyBranchJudge (branch_key resolution at Beat 7)
##   → Story Event #10 (Beat 1/8/9 narrative emit + invalid-path UI carve-out)
##   → Destiny State #16 (echo archive + flag effects + SaveContext population)
##
## Pattern: emit/drive on real GameBus, observe production /root/StoryEvent +
## /root/DestinyState autoload handlers via test-side capture lambdas.
## reset_for_tests() in before_test() resists scenario_runner_signal_contract_test
## bulk-disconnect interference (S8-10 lesson — applies to both autoloads).
##
## ADR cross-refs: ADR-0017 ScenarioRunner + ADR-0018 DestinyBranch +
## ADR-0019 AISystem + ADR-0001 GameBus + ADR-0003 SaveContext.
extends GdUnitTestSuite


const SCENARIO_JSON: String = "res://assets/data/scenarios/mvp_shu.json"
const CHAPTER_1_ID: String = "ch01_changbanpo"
const CHAPTER_1_CANONICAL_BRANCH: String = "WIN_changbanpo_default"
const CHAPTER_1_LOSS_BRANCH: String = "LOSS_changbanpo_retreat"


# ─── Test-side capture state ─────────────────────────────────────────────────

var _resolved_emits: Array = []
var _invalid_path_emits: Array = []
var _revelation_committed_emits: Array = []
var _save_checkpoint_emits: Array = []
var _echo_added_emits: Array = []
var _flag_set_emits: Array = []
var _connections: Array = []


func before_test() -> void:
	# Reset Story Event + Destiny State autoload state. Their reset_for_tests()
	# also re-establishes GameBus subscriptions per S8-10 discovered pattern.
	var se: Node = get_node_or_null("/root/StoryEvent")
	if se != null:
		se.reset_for_tests()
	var ds: Node = get_node_or_null("/root/DestinyState")
	if ds != null:
		ds.reset_for_tests()
	# Reset capture state.
	_resolved_emits = []
	_invalid_path_emits = []
	_revelation_committed_emits = []
	_save_checkpoint_emits = []
	_echo_added_emits = []
	_flag_set_emits = []
	_connections = []


func after_test() -> void:
	# Disconnect ONLY the test-side captures — never bulk-disconnect autoload
	# subscribers (would sever DestinyState + StoryEvent for subsequent tests).
	for entry: Dictionary in _connections:
		var sig: Signal = entry["signal"] as Signal
		var cb: Callable = entry["callable"] as Callable
		if sig.is_connected(cb):
			sig.disconnect(cb)
	# Reset /root/ScenarioRunner to clean LOADING state so subsequent tests
	# (e.g. battle_scene_smoke) see an empty-chapter ScenarioRunner.
	var runner: Node = get_node_or_null("/root/ScenarioRunner")
	if runner != null and runner.has_method("reset_for_tests"):
		runner.reset_for_tests()


func _wire_captures() -> void:
	var c1: Callable = func(beat: int, vk: StringName, tk: String, ct: StringName) -> void:
		_resolved_emits.append({"beat": beat, "variant": String(vk), "text": tk, "cue": String(ct)})
	GameBus.story_event_resolved.connect(c1)
	_connections.append({"signal": GameBus.story_event_resolved, "callable": c1})

	var c2: Callable = func(reason: StringName, cid: String) -> void:
		_invalid_path_emits.append({"reason": String(reason), "chapter_id": cid})
	GameBus.story_event_invalid_path_detected.connect(c2)
	_connections.append({"signal": GameBus.story_event_invalid_path_detected, "callable": c2})

	var c3: Callable = func(cid: String, bk: String, reg: StringName) -> void:
		_revelation_committed_emits.append({"chapter_id": cid, "branch_key": bk, "register": String(reg)})
	GameBus.story_event_revelation_committed.connect(c3)
	_connections.append({"signal": GameBus.story_event_revelation_committed, "callable": c3})

	var c4: Callable = func(ctx: SaveContext) -> void:
		_save_checkpoint_emits.append({
			"chapter_id": String(ctx.chapter_id),
			"last_cp": ctx.last_cp,
			"chapter_number": ctx.chapter_number,
		})
	GameBus.save_checkpoint_requested.connect(c4)
	_connections.append({"signal": GameBus.save_checkpoint_requested, "callable": c4})

	var c5: Callable = func(mark: EchoMark) -> void:
		_echo_added_emits.append({"beat_index": mark.beat_index, "outcome": String(mark.outcome)})
	GameBus.destiny_state_echo_added.connect(c5)
	_connections.append({"signal": GameBus.destiny_state_echo_added, "callable": c5})

	var c6: Callable = func(flag: String, value: bool) -> void:
		_flag_set_emits.append({"flag": flag, "value": value})
	GameBus.destiny_state_flag_set.connect(c6)
	_connections.append({"signal": GameBus.destiny_state_flag_set, "callable": c6})


# ─── Helper: drive ScenarioRunner through chapter-1 with a given outcome ─────


func _drive_chapter_1(runner: Node, result: int) -> void:
	# Pump frames between drive steps so CONNECT_DEFERRED autoload handlers
	# (StoryEvent + DestinyState) fire within active-chapter context. Without
	# the awaits, handlers all fire AFTER SCENARIO_END and get_current_chapter()
	# returns null.
	await get_tree().process_frame  # drain chapter_started deferred handlers
	runner.advance_beat()  # BEAT_1 -> BEAT_2
	runner.advance_beat()  # BEAT_2 -> BEAT_3
	runner.advance_beat()  # BEAT_3 -> BEAT_4
	runner.confirm_deployment()  # BEAT_4 -> BATTLE_LOADING -> BEAT_5
	var outcome: BattleOutcome = BattleOutcome.new()
	outcome.result = result
	outcome.chapter_id = CHAPTER_1_ID
	runner._on_battle_outcome_resolved(outcome)
	runner.accept_outcome()  # BEAT_6 -> BEAT_7 -> BEAT_8 (synchronous seal)
	# CRITICAL: pump deferred handlers BEFORE advancing past BEAT_8.
	# StoryEvent's _on_destiny_branch_chosen handler must read get_current_chapter()
	# while chapter is still active (state == BEAT_8_REVEAL), not SCENARIO_END.
	await get_tree().process_frame
	runner.advance_beat()  # BEAT_8 -> BEAT_9 -> SCENARIO_END (single-chapter)
	# Pump again for chapter_completed + scenario_complete deferred handlers.
	await get_tree().process_frame


# ─── AC: chapter-1 canonical WIN path full arc ──────────────────────────────


func test_chapter_1_canonical_win_full_arc() -> void:
	var runner: Node = get_node_or_null("/root/ScenarioRunner")
	assert_object(runner).is_not_null()
	_wire_captures()
	# Load on production autoload so StoryEvent/DestinyState see the chapter
	# via their _current_chapter_or_null() lookups against /root/ScenarioRunner.
	runner.load_scenario(SCENARIO_JSON)
	await _drive_chapter_1(runner, BattleOutcome.Result.WIN)
	# Final drain for any remaining deferred handlers.
	await get_tree().process_frame

	# After chapter 1 BEAT_9, runner advances to chapter 2 BEAT_1_ANCHOR (mvp_shu.json
	# is now a 2-chapter scenario). Chapter index moves 0 -> 1.
	var state_enum: Dictionary = ScenarioRunnerTestSeam.get_state_enum()
	assert_int(runner.get_state()).is_equal(state_enum["BEAT_1_ANCHOR"] as int)
	assert_int(runner.get_current_chapter_index()).is_equal(1)

	# Verify Story Event emitted Beat 1 + Beat 8 + Beat 9 narrative resolutions.
	# (Note: isolated runner emits chapter_started at load_scenario; Beat 1
	# anchor fires from StoryEvent's chapter_started handler. Beat 8 + Beat 9
	# fire from destiny_branch_chosen + chapter_completed handlers.)
	var beat_numbers: Array = []
	for e: Dictionary in _resolved_emits:
		beat_numbers.append(int(e["beat"]))
	# At minimum: Beat 8 (canonical_win) + Beat 9 (chapter_transition) MUST fire.
	assert_bool(beat_numbers.has(8)).override_failure_message(
		"Story Event Beat 8 emit missing — variant resolution failed"
	).is_true()
	assert_bool(beat_numbers.has(9)).override_failure_message(
		"Story Event Beat 9 emit missing — chapter_completed handler not firing"
	).is_true()


# ─── AC: chapter-1 canonical WIN → canonical_win variant ──────────────────────


func test_chapter_1_win_resolves_canonical_win_variant() -> void:
	var runner: Node = get_node_or_null("/root/ScenarioRunner")
	assert_object(runner).is_not_null()
	_wire_captures()
	# Load on production autoload so StoryEvent/DestinyState see the chapter
	# via their _current_chapter_or_null() lookups against /root/ScenarioRunner.
	runner.load_scenario(SCENARIO_JSON)
	await _drive_chapter_1(runner, BattleOutcome.Result.WIN)
	await get_tree().process_frame

	# Find the Beat 8 emit + assert variant_key is canonical_win.
	var beat_8_emit: Dictionary = {}
	for e: Dictionary in _resolved_emits:
		if int(e["beat"]) == 8:
			beat_8_emit = e
			break
	assert_int(beat_8_emit.size()).override_failure_message(
		"Beat 8 emit not captured"
	).is_greater(0)
	assert_str(String(beat_8_emit["variant"])).is_equal("canonical_win")
	# text_key should match chapter authoring.
	assert_str(String(beat_8_emit["text"])).is_equal("ch01.beat8.win_changbanpo_default")


# ─── AC: chapter-1 LOSS → defeat variant ─────────────────────────────────────


func test_chapter_1_loss_resolves_defeat_variant() -> void:
	var runner: Node = get_node_or_null("/root/ScenarioRunner")
	assert_object(runner).is_not_null()
	_wire_captures()
	# Load on production autoload so StoryEvent/DestinyState see the chapter
	# via their _current_chapter_or_null() lookups against /root/ScenarioRunner.
	runner.load_scenario(SCENARIO_JSON)
	await _drive_chapter_1(runner, BattleOutcome.Result.LOSS)
	await get_tree().process_frame

	var beat_8_emit: Dictionary = {}
	for e: Dictionary in _resolved_emits:
		if int(e["beat"]) == 8:
			beat_8_emit = e
			break
	assert_int(beat_8_emit.size()).is_greater(0)
	assert_str(String(beat_8_emit["variant"])).is_equal("defeat")
	assert_str(String(beat_8_emit["text"])).is_equal("ch01.beat8.loss_changbanpo_retreat")


# ─── AC: revelation_committed register tag (canonical → solemn) ──────────────


func test_chapter_1_canonical_win_revelation_register_solemn() -> void:
	var runner: Node = get_node_or_null("/root/ScenarioRunner")
	assert_object(runner).is_not_null()
	_wire_captures()
	# Load on production autoload so StoryEvent/DestinyState see the chapter
	# via their _current_chapter_or_null() lookups against /root/ScenarioRunner.
	runner.load_scenario(SCENARIO_JSON)
	await _drive_chapter_1(runner, BattleOutcome.Result.WIN)
	await get_tree().process_frame

	assert_int(_revelation_committed_emits.size()).is_greater(0)
	var first: Dictionary = _revelation_committed_emits[0]
	assert_str(String(first["register"])).is_equal("solemn")
	assert_str(String(first["branch_key"])).is_equal(CHAPTER_1_CANONICAL_BRANCH)


# ─── AC: chapter_completed → SaveContext.last_cp populated ───────────────────


func test_chapter_1_save_checkpoint_emits_during_arc() -> void:
	var runner: Node = get_node_or_null("/root/ScenarioRunner")
	assert_object(runner).is_not_null()
	_wire_captures()
	# Load on production autoload so StoryEvent/DestinyState see the chapter
	# via their _current_chapter_or_null() lookups against /root/ScenarioRunner.
	runner.load_scenario(SCENARIO_JSON)
	await _drive_chapter_1(runner, BattleOutcome.Result.WIN)
	await get_tree().process_frame

	# At least 1 save_checkpoint_requested fires during chapter-1 arc (CP-1 at Beat 1).
	# CP-2/CP-3 require SceneManager transition wiring not exercised in isolated runner.
	assert_int(_save_checkpoint_emits.size()).is_greater_equal(1)
	var first: Dictionary = _save_checkpoint_emits[0]
	assert_str(String(first["chapter_id"])).is_equal(CHAPTER_1_ID)


# ─── AC: chapter_completed-driven Destiny State chapter_id flow ──────────────


func test_chapter_1_completes_without_destiny_state_errors() -> void:
	# Smoke test: full chapter-1 arc completes without Destiny State pushing
	# error/warning related to invalid-payload guards or chapter_id mismatch.
	# (The 4 invalid-payload guards on DestinyState should NOT trigger during
	# a clean chapter-1 traversal.)
	var runner: Node = get_node_or_null("/root/ScenarioRunner")
	assert_object(runner).is_not_null()
	_wire_captures()
	# Load on production autoload so StoryEvent/DestinyState see the chapter
	# via their _current_chapter_or_null() lookups against /root/ScenarioRunner.
	runner.load_scenario(SCENARIO_JSON)
	await _drive_chapter_1(runner, BattleOutcome.Result.WIN)
	await get_tree().process_frame

	# DestinyState archive should still be empty (no scenario_beat_retried fired
	# in this single-WIN-attempt flow).
	var ds: Node = get_node_or_null("/root/DestinyState")
	assert_int(ds.get_full_archive().size()).is_equal(0)
	# Story Event chain produced at least Beat 8 + Beat 9 emits.
	assert_int(_resolved_emits.size()).is_greater_equal(2)


# ─── AC: invalid-path injection routes to Story Event invalid_path_detected ──


func test_chapter_1_invalid_destiny_branch_choice_routes_to_invalid_path_ui() -> void:
	# Inject a pre-fabricated invalid DestinyBranchChoice via direct GameBus emit.
	# Verifies F-SE-3 D1 BLOCKING contract: is_invalid checked FIRST.
	_wire_captures()
	var bad: DestinyBranchChoice = DestinyBranchChoice.invalid(&"invariant_violation:test_e2e_inject")
	bad.chapter_id = CHAPTER_1_ID
	GameBus.destiny_branch_chosen.emit(bad)
	await get_tree().process_frame
	await get_tree().process_frame

	# Story Event MUST emit invalid_path_detected, NOT story_event_resolved(8, ...).
	var beat_8_resolved_count: int = 0
	for e: Dictionary in _resolved_emits:
		if int(e["beat"]) == 8:
			beat_8_resolved_count += 1
	assert_int(beat_8_resolved_count).is_equal(0)
	assert_int(_invalid_path_emits.size()).is_equal(1)
	assert_str(String(_invalid_path_emits[0]["reason"])).is_equal("invariant_violation:test_e2e_inject")


# ─── AC: full traversal → Destiny State chapter_completed handler fires ─────


func test_chapter_1_completion_triggers_destiny_state_handler() -> void:
	# Verifies that DestinyState's _on_chapter_completed handler fires during
	# a clean chapter-1 traversal (smoke-level: no crash, no warnings,
	# subsequent get_echo_count returns 0 default for ch01).
	var runner: Node = get_node_or_null("/root/ScenarioRunner")
	assert_object(runner).is_not_null()
	_wire_captures()
	# Load on production autoload so StoryEvent/DestinyState see the chapter
	# via their _current_chapter_or_null() lookups against /root/ScenarioRunner.
	runner.load_scenario(SCENARIO_JSON)
	await _drive_chapter_1(runner, BattleOutcome.Result.WIN)
	await get_tree().process_frame

	var ds: Node = get_node_or_null("/root/DestinyState")
	# No retries → echo_count for chapter-1 stays 0.
	assert_int(ds.get_echo_count(CHAPTER_1_ID)).is_equal(0)
