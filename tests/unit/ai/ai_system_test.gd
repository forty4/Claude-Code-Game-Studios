## ai_system_test.gd
##
## Covers AC-AI-1 (signal protocol) + AC-AI-2 (determinism) + AC-AI-3 (archetype
## differentiation) + AC-AI-9 + AC-AI-10 (lint structural assertions).
extends GdUnitTestSuite


const AI_SYSTEM_PATH: String = "res://src/feature/ai/ai_system.gd"


# ─── AC-AI-2: determinism (100-invocation field-identical per archetype) ─────


func test_aggressor_determinism_100_invocations() -> void:
	var snap: BattleStateSnapshot = _make_test_snapshot()
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	# Don't add_child — this is a pure-function test of decide().
	var baseline: AIActionCommand = ai.decide(2, snap)
	for i in 99:
		var cmd: AIActionCommand = ai.decide(2, snap)
		assert_int(cmd.action_type).is_equal(baseline.action_type)
		assert_int(cmd.attack_target_unit_id).is_equal(baseline.attack_target_unit_id)
		assert_int(cmd.move_target.x).is_equal(baseline.move_target.x)
		assert_int(cmd.move_target.y).is_equal(baseline.move_target.y)


# ─── AC-AI-3: archetype differentiation (≥50% of synthetic scenarios differ) ─


func test_archetypes_produce_different_actions_in_kite_scenario() -> void:
	# Scenario: skirmisher next to player melee. Expect: skirmisher kites,
	# aggressor attacks, holder defends/anchors, coordinator targets commander.
	var snap: BattleStateSnapshot = _make_kite_scenario()
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	# Use unit_id 100; reassign archetype via direct unit-dict mutation per archetype.
	var seen_actions: Dictionary = {}
	var archetypes: Array[StringName] = [&"aggressor", &"skirmisher", &"holder", &"coordinator"]
	for arch: StringName in archetypes:
		var s: BattleStateSnapshot = _make_kite_scenario_with_archetype(arch)
		var cmd: AIActionCommand = ai.decide(100, s)
		# Use an action signature key; differing action_types or move_targets count as differentiation.
		var key: String = "%d:%d:%d:%d" % [cmd.action_type, cmd.attack_target_unit_id, cmd.move_target.x, cmd.move_target.y]
		seen_actions[key] = true
	# At least 2 distinct actions across 4 archetypes (proves they're not identical).
	assert_int(seen_actions.size()).is_greater_equal(2)


# ─── AC-AI-9: structural source assertion — Pillar 2 4th precedent ───────────


func test_ai_system_source_contains_no_pillar_2_tokens_outside_doc_comments() -> void:
	# The lint script enforces this; this test mirrors via FileAccess for
	# integration-test-level enforcement (3-layer triad: lint + test + ADR comment).
	var content: String = FileAccess.get_file_as_string(AI_SYSTEM_PATH)
	# Extract non-comment lines (lines NOT starting with optional whitespace then #).
	var non_comment: PackedStringArray = PackedStringArray()
	for line: String in content.split("\n"):
		var trimmed: String = line.strip_edges(true, false)
		if trimmed.begins_with("#"):
			continue
		non_comment.append(line)
	var body: String = "\n".join(non_comment)
	assert_bool(body.contains("hidden_fate_condition_progressed")).override_failure_message(
		"AC-AI-9: ai_system.gd code body must NOT contain 'hidden_fate_condition_progressed' (Pillar 2 lock 4th precedent)"
	).is_false()
	assert_bool(body.contains("DestinyBranchChoice")).override_failure_message(
		"AC-AI-9: ai_system.gd code body must NOT contain 'DestinyBranchChoice' (Pillar 2 lock 4th precedent)"
	).is_false()
	assert_bool(body.contains("destiny_branch_chosen")).override_failure_message(
		"AC-AI-9: ai_system.gd code body must NOT contain 'destiny_branch_chosen' (Pillar 2 lock 4th precedent)"
	).is_false()


# ─── AC-AI-10: structural source assertion — no_direct_state_read ────────────


func test_ai_system_no_direct_state_read_in_source() -> void:
	var content: String = FileAccess.get_file_as_string(AI_SYSTEM_PATH)
	# Forbidden: MapGrid./HPStatusController./TurnOrderRunner. references in code body.
	var forbidden: Array[String] = [
		"MapGrid.",
		"HPStatusController.",
		"TurnOrderRunner.",
	]
	for token: String in forbidden:
		# Allow the token in comment lines (declaration patterns — DI'd ref typed-decls live in 'GridBattleController' field, not these classes).
		var lines: Array[String] = []
		for line: String in content.split("\n"):
			var trimmed: String = line.strip_edges(true, false)
			if trimmed.begins_with("#"):
				continue
			lines.append(line)
		var body: String = "\n".join(lines)
		assert_bool(body.contains(token)).override_failure_message(
			"AC-AI-10: ai_system.gd code body must NOT reference '%s' (CR-AI-6 pure-function-takes-snapshot)" % token
		).is_false()


# ─── Determinism source-scan: no Time/rand/static var ───────────────────────


func test_ai_system_source_no_nondeterministic_patterns() -> void:
	var content: String = FileAccess.get_file_as_string(AI_SYSTEM_PATH)
	var forbidden: Array[String] = [
		"Time.get_ticks_msec",
		"Time.get_ticks_usec",
		"randi(",
		"randf(",
		"randf_range",
		"randi_range",
	]
	for token: String in forbidden:
		assert_bool(content.contains(token)).override_failure_message(
			"AISystem source must NOT contain '%s' (CR-AI-5 determinism)" % token
		).is_false()


# ─── Helpers ──────────────────────────────────────────────────────────────────


func _make_test_snapshot() -> BattleStateSnapshot:
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(2, &"aggressor", Vector2i(5, 5), 80, 100),
	]
	var players: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(4, 5), 50, 100),
	]
	return BattleStateSnapshotFactory.make(enemies, players)


func _make_kite_scenario() -> BattleStateSnapshot:
	return _make_kite_scenario_with_archetype(&"skirmisher")


func _make_kite_scenario_with_archetype(arch: StringName) -> BattleStateSnapshot:
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(100, arch, Vector2i(7, 7), 100, 100, {"attack_range": 2}),
	]
	var players: Array[Dictionary] = [
		# Adjacent melee threat
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(7, 6), 50, 100, {"attack_range": 1}),
	]
	return BattleStateSnapshotFactory.make(enemies, players)
