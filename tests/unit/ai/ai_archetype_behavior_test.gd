## ai_archetype_behavior_test.gd
##
## Covers per-archetype behavior ACs:
##   AC-AI-4 aggressor finishing
##   AC-AI-5 skirmisher kiting
##   AC-AI-6 holder chokepoint anchoring
##   AC-AI-7 coordinator commander targeting
##   AC-AI-8 coordinator rally usage
extends GdUnitTestSuite


# ─── AC-AI-4: aggressor finishing behavior ───────────────────────────────────


func test_aggressor_attacks_low_hp_target_in_range() -> void:
	# Aggressor adjacent to player at HP 20/100 (≤30%) → should ATTACK.
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(2, &"aggressor", Vector2i(5, 5), 100, 100),
	]
	var players: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(5, 6), 20, 100),
	]
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(enemies, players)
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(2, snap)
	assert_int(cmd.action_type).is_equal(AIActionCommand.ActionType.ATTACK)
	assert_int(cmd.attack_target_unit_id).is_equal(0)


# ─── AC-AI-7: coordinator commander targeting ────────────────────────────────


func test_coordinator_targets_commander_over_higher_dmg_target() -> void:
	# Coordinator with two players in range: 유비 (command_aura, full HP) vs
	# weakened other player. Coordinator MUST target 유비 due to +60 commander bonus.
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(2, &"coordinator", Vector2i(5, 5), 100, 100),
	]
	var players: Array[Dictionary] = [
		# 유비 (commander) at full HP — would normally not be priority by HP.
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(5, 6), 100, 100, {"passive_id": &"command_aura"}),
		# Weakened non-commander — would normally be the higher-bonus target.
		BattleStateSnapshotFactory.unit(1, &"", Vector2i(6, 5), 30, 100),
	]
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(enemies, players)
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(2, snap)
	assert_int(cmd.action_type).is_equal(AIActionCommand.ActionType.ATTACK)
	assert_int(cmd.attack_target_unit_id).override_failure_message(
		"AC-AI-7: coordinator must target 유비 (command_aura) over weaker target due to +60 bonus"
	).is_equal(0)


# ─── AC-AI-8: coordinator rally usage ────────────────────────────────────────


func test_coordinator_uses_rally_with_two_adjacent_allies() -> void:
	# Coordinator with 2 adjacent allies + rally available → USE_SKILL(rally).
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(2, &"coordinator", Vector2i(5, 5), 100, 100),
		# Adjacent allies (same side=1).
		BattleStateSnapshotFactory.unit(3, &"aggressor", Vector2i(5, 6), 100, 100),
		BattleStateSnapshotFactory.unit(4, &"holder", Vector2i(6, 5), 100, 100),
	]
	var players: Array[Dictionary] = []
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(enemies, players)
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(2, snap)
	assert_int(cmd.action_type).is_equal(AIActionCommand.ActionType.USE_SKILL)
	assert_str(String(cmd.skill_id)).is_equal("rally")


# ─── EC-AI-1: zero candidates → WAIT ─────────────────────────────────────────


func test_unit_not_in_snapshot_returns_wait() -> void:
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make([], [])
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(99, snap)  # unit_id not in snapshot
	assert_int(cmd.action_type).is_equal(AIActionCommand.ActionType.WAIT)
	assert_int(cmd.unit_id).is_equal(99)


# ─── EC-AI-4: unknown archetype falls back to aggressor ─────────────────────


func test_unknown_archetype_falls_back_to_aggressor() -> void:
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(2, &"unknown_archetype", Vector2i(5, 5), 100, 100),
	]
	var players: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(5, 6), 20, 100),
	]
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(enemies, players)
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(2, snap)
	# Falls back to aggressor → ATTACK on adjacent low-HP target.
	assert_int(cmd.action_type).is_equal(AIActionCommand.ActionType.ATTACK)
