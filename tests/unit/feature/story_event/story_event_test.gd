## story_event_test.gd
##
## Covers AC-SE-1..11 from design/gdd/story-event.md (rev 1.0):
##   branch-state variant resolution (AC-SE-1..6) +
##   D1 BLOCKING invalid-gate contract (AC-SE-7..11).
##
## Test pattern: emit on real GameBus, observe production /root/StoryEvent
## handler. reset_for_tests() in before_test() prevents state bleed (G-15) +
## resists scenario_runner_signal_contract_test bulk-disconnect (S8-10 lesson).
extends GdUnitTestSuite


const STORY_EVENT_PATH: String = "res://src/feature/story_event/story_event.gd"


func before_test() -> void:
	var se: Node = get_node_or_null("/root/StoryEvent")
	if se != null:
		se.reset_for_tests()


# ─── F-SE-1 variant resolution (AC-SE-1..6) — pure-function tests ────────────


func test_canonical_win_variant_resolves() -> void:
	var se: Node = get_node_or_null("/root/StoryEvent")
	var choice: DestinyBranchChoice = DestinyBranchChoice.new()
	choice.outcome = BattleOutcome.Result.WIN
	choice.is_canonical_history = true
	choice.is_draw_fallback = false
	choice.is_invalid = false
	var vk: StringName = se.resolve_variant_key(choice)
	assert_str(String(vk)).is_equal("canonical_win")


func test_rewritten_win_variant_resolves() -> void:
	var se: Node = get_node_or_null("/root/StoryEvent")
	var choice: DestinyBranchChoice = DestinyBranchChoice.new()
	choice.outcome = BattleOutcome.Result.WIN
	choice.is_canonical_history = false
	choice.is_draw_fallback = false
	choice.is_invalid = false
	var vk: StringName = se.resolve_variant_key(choice)
	assert_str(String(vk)).is_equal("rewritten_win")


func test_draw_fallback_variant_resolves() -> void:
	var se: Node = get_node_or_null("/root/StoryEvent")
	var choice: DestinyBranchChoice = DestinyBranchChoice.new()
	choice.outcome = BattleOutcome.Result.DRAW
	choice.is_draw_fallback = true
	choice.echo_count = 5  # ignored — is_draw_fallback dominates
	choice.is_invalid = false
	var vk: StringName = se.resolve_variant_key(choice)
	assert_str(String(vk)).is_equal("draw_fallback")


func test_defeat_variant_resolves() -> void:
	var se: Node = get_node_or_null("/root/StoryEvent")
	var choice: DestinyBranchChoice = DestinyBranchChoice.new()
	choice.outcome = BattleOutcome.Result.LOSS
	choice.is_canonical_history = true  # ignored — LOSS dominates per EC-SE-8
	choice.is_invalid = false
	var vk: StringName = se.resolve_variant_key(choice)
	assert_str(String(vk)).is_equal("defeat")


func test_unknown_outcome_returns_empty_variant() -> void:
	# Bypass-seam style: inject out-of-range outcome via direct field assignment.
	var se: Node = get_node_or_null("/root/StoryEvent")
	var choice: DestinyBranchChoice = DestinyBranchChoice.new()
	@warning_ignore("int_as_enum_without_cast")
	choice.outcome = -1  # invalid enum value
	choice.is_invalid = false
	var vk: StringName = se.resolve_variant_key(choice)
	assert_str(String(vk)).is_equal("")


# ─── F-SE-1 invalid-gate (AC-SE-7) — invalid choice returns empty variant ────


func test_invalid_choice_returns_empty_variant_without_field_read() -> void:
	var se: Node = get_node_or_null("/root/StoryEvent")
	# Factory sets outcome=LOSS as default — would misclassify if is_invalid
	# wasn't checked first.
	var choice: DestinyBranchChoice = DestinyBranchChoice.invalid(&"invariant_violation:test")
	var vk: StringName = se.resolve_variant_key(choice)
	assert_str(String(vk)).is_equal("")


# ─── F-SE-3 destiny_branch_chosen handler — invalid-path UI (AC-SE-8, AC-SE-11) ────


func test_destiny_branch_chosen_invalid_emits_invalid_path_signal() -> void:
	var resolved_emits: Array = []
	var invalid_emits: Array = []
	GameBus.story_event_resolved.connect(func(_b: int, _v: StringName, _t: String, _c: StringName) -> void:
		resolved_emits.append("resolved")
	)
	GameBus.story_event_invalid_path_detected.connect(func(reason: StringName, cid: String) -> void:
		invalid_emits.append({"reason": String(reason), "chapter_id": cid})
	)
	var choice: DestinyBranchChoice = DestinyBranchChoice.invalid(&"invariant_violation:test_reason")
	choice.chapter_id = "ch_test"
	GameBus.destiny_branch_chosen.emit(choice)
	await get_tree().process_frame
	assert_int(resolved_emits.size()).is_equal(0)
	assert_int(invalid_emits.size()).is_equal(1)
	assert_str(invalid_emits[0].reason).is_equal("invariant_violation:test_reason")


# ─── F-DB-3 invariant_reason vocabulary propagation (AC-SE-9 sample) ──────────


func test_invalid_reason_propagates_through_handler() -> void:
	var captured: Array = []
	GameBus.story_event_invalid_path_detected.connect(func(reason: StringName, _cid: String) -> void:
		captured.append(String(reason))
	)
	# Sample 3 of the 12 F-DB-3 invariant_reason vocabulary entries.
	var sample_reasons: Array[StringName] = [
		&"invariant_violation:chapter_null",
		&"invariant_violation:branch_table_empty",
		&"invariant_violation:canonical_branch_key_missing",
	]
	for r in sample_reasons:
		var choice: DestinyBranchChoice = DestinyBranchChoice.invalid(r)
		GameBus.destiny_branch_chosen.emit(choice)
		await get_tree().process_frame
	assert_int(captured.size()).is_equal(3)
	assert_bool(captured.has("invariant_violation:chapter_null")).is_true()
	assert_bool(captured.has("invariant_violation:branch_table_empty")).is_true()
	assert_bool(captured.has("invariant_violation:canonical_branch_key_missing")).is_true()


# ─── F-SE-3 valid choice with no chapter authoring → defensive fallback ──────


func test_valid_choice_with_no_chapter_routes_to_invalid_path() -> void:
	# Without an active scenario loaded, _current_chapter_or_null returns null
	# → F-SE-2 returns {} → handler emits invalid_path with beat_8_revelation_missing.
	var resolved_emits: Array = []
	var invalid_emits: Array = []
	GameBus.story_event_resolved.connect(func(_b: int, _v: StringName, _t: String, _c: StringName) -> void:
		resolved_emits.append("resolved")
	)
	GameBus.story_event_invalid_path_detected.connect(func(reason: StringName, _cid: String) -> void:
		invalid_emits.append(String(reason))
	)
	var choice: DestinyBranchChoice = DestinyBranchChoice.new()
	choice.chapter_id = "ch_no_active_scenario"
	choice.branch_key = "WIN_default"
	choice.outcome = BattleOutcome.Result.WIN
	choice.is_canonical_history = true
	choice.is_invalid = false
	GameBus.destiny_branch_chosen.emit(choice)
	await get_tree().process_frame
	# When ScenarioRunner has no active chapter, invalid-path-defensive route fires.
	# (Test runs in isolated mode — no scenario loaded in /root/ScenarioRunner.)
	assert_int(resolved_emits.size()).is_equal(0)
	assert_int(invalid_emits.size()).is_equal(1)
	assert_str(invalid_emits[0]).is_equal("beat_8_revelation_missing")


# ─── F-SE-4 chapter_started handler — invalid-payload guard ──────────────────


func test_chapter_started_empty_id_dropped() -> void:
	var emits: Array = []
	GameBus.story_event_resolved.connect(func(_b: int, _v: StringName, _t: String, _c: StringName) -> void:
		emits.append("resolved")
	)
	GameBus.chapter_started.emit("", 1)  # invalid: empty chapter_id
	await get_tree().process_frame
	assert_int(emits.size()).is_equal(0)


func test_chapter_started_zero_chapter_number_dropped() -> void:
	var emits: Array = []
	GameBus.story_event_resolved.connect(func(_b: int, _v: StringName, _t: String, _c: StringName) -> void:
		emits.append("resolved")
	)
	GameBus.chapter_started.emit("ch_test", 0)  # invalid: chapter_number<=0
	await get_tree().process_frame
	assert_int(emits.size()).is_equal(0)


# ─── F-SE-4 chapter_completed handler — invalid-payload guard ────────────────


func test_chapter_completed_null_dropped() -> void:
	var emits: Array = []
	GameBus.story_event_resolved.connect(func(_b: int, _v: StringName, _t: String, _c: StringName) -> void:
		emits.append("resolved")
	)
	# null result emit — handler must early-return.
	GameBus.chapter_completed.emit(null)
	await get_tree().process_frame
	assert_int(emits.size()).is_equal(0)


# ─── Closed variant-key vocabulary (CR-SE-13) ────────────────────────────────


func test_variant_key_namespace_size_six() -> void:
	var se: Node = get_node_or_null("/root/StoryEvent")
	var script: GDScript = (se as Object).get_script() as GDScript
	var ns: Variant = script.get_script_constant_map().get("VARIANT_KEY_NAMESPACE", null)
	assert_object(ns).is_not_null()
	var arr: Array = ns as Array
	assert_int(arr.size()).is_equal(6)


# ─── G-22 Pillar 2 lock structural source assertion (mirror of lint) ─────────


func test_story_event_source_contains_no_underscored_scenario_runner_reads() -> void:
	var content: String = FileAccess.get_file_as_string(STORY_EVENT_PATH)
	var non_comment_lines: PackedStringArray = PackedStringArray()
	for line: String in content.split("\n"):
		var trimmed: String = line.strip_edges(true, false)
		if not trimmed.begins_with("#"):
			non_comment_lines.append(line)
	var non_comment_body: String = "\n".join(non_comment_lines)
	assert_bool(non_comment_body.contains("ScenarioRunner._state")).is_false()
	assert_bool(non_comment_body.contains("ScenarioRunner._echo_count")).is_false()
	assert_bool(non_comment_body.contains("ScenarioRunner._chapter_index")).is_false()
	assert_bool(non_comment_body.contains("ScenarioRunner.advance_beat")).is_false()


func test_story_event_source_contains_no_hidden_fate_token() -> void:
	var content: String = FileAccess.get_file_as_string(STORY_EVENT_PATH)
	var non_comment_lines: PackedStringArray = PackedStringArray()
	for line: String in content.split("\n"):
		var trimmed: String = line.strip_edges(true, false)
		if not trimmed.begins_with("#"):
			non_comment_lines.append(line)
	var non_comment_body: String = "\n".join(non_comment_lines)
	assert_bool(non_comment_body.contains("hidden_fate")).is_false()
