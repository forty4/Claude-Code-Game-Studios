## ai_system_new_archetypes_test.gd
##
## Tests for berserker + protector archetypes (session-11 additions).
##
## Berserker:
##   - Below low-HP threshold: ATTACK score gets a flat bonus
##   - Always rejects DEFEND/USE_SKILL (returns -100)
##   - WAIT also rejected (-100) — berserker never sits still
##   - MOVE: penalty per remaining distance (scaled by tolerance constant)
##
## Protector:
##   - With ally COMMANDER (command_aura) present: prefers MOVE adjacent to it
##   - ATTACK on a player unit close to the commander: gets intercept bonus
##   - DEFEND when guarding wounded commander: positive
##   - Without ally COMMANDER: degrades to aggressor scoring (no warning)
extends GdUnitTestSuite


# ─── Berserker scoring ────────────────────────────────────────────────────────


func test_berserker_below_threshold_picks_attack_over_anything_else() -> void:
	# Berserker @ HP 30/100 (= 0.30 < threshold 0.50) adjacent to player.
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(100, &"berserker", Vector2i(5, 5),
				30, 100, {"attack_range": 1}),
	]
	var players: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(5, 6), 50, 100),
	]
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(enemies, players)

	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(100, snap)

	assert_int(cmd.action_type).override_failure_message(
		"low-HP berserker adjacent to player must pick ATTACK; got %d" % cmd.action_type
	).is_equal(int(AIActionCommand.ActionType.ATTACK))
	assert_int(cmd.attack_target_unit_id).is_equal(0)


func test_berserker_above_threshold_still_attacks_when_in_range() -> void:
	# HP 80/100 (above threshold) — base attack score is enough to beat MOVE.
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(100, &"berserker", Vector2i(5, 5),
				80, 100, {"attack_range": 1}),
	]
	var players: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(5, 6), 50, 100),
	]
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(enemies, players)

	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(100, snap)

	assert_int(cmd.action_type).override_failure_message(
		"healthy berserker with target in range must still ATTACK; got %d" % cmd.action_type
	).is_equal(int(AIActionCommand.ActionType.ATTACK))


func test_berserker_never_defends() -> void:
	# Even when wounded + adjacent to many threats, berserker refuses DEFEND.
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(100, &"berserker", Vector2i(5, 5),
				15, 100, {"attack_range": 1}),
	]
	var players: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(5, 6), 50, 100),
		BattleStateSnapshotFactory.unit(1, &"", Vector2i(6, 5), 50, 100),
	]
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(enemies, players)

	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(100, snap)

	assert_int(cmd.action_type).override_failure_message(
		"berserker must never DEFEND; got %d" % cmd.action_type
	).is_not_equal(int(AIActionCommand.ActionType.DEFEND))


func test_berserker_moves_when_no_target_in_range() -> void:
	# No player within attack_range → must MOVE (and not WAIT).
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(100, &"berserker", Vector2i(2, 2),
				100, 100, {"attack_range": 1, "move_range": 3}),
	]
	var players: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(7, 7), 50, 100),
	]
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(enemies, players)

	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(100, snap)

	assert_int(cmd.action_type).override_failure_message(
		"berserker with no target in range must MOVE (closes distance); got %d" % cmd.action_type
	).is_equal(int(AIActionCommand.ActionType.MOVE))


# ─── Protector scoring ────────────────────────────────────────────────────────


func test_protector_moves_adjacent_to_ally_commander_when_distant() -> void:
	# Protector at (2,2); ally commander at (5,5). Should MOVE toward commander.
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(100, &"protector", Vector2i(2, 2),
				100, 100, {"attack_range": 1, "move_range": 3}),
		BattleStateSnapshotFactory.unit(101, &"coordinator", Vector2i(5, 5),
				100, 100, {"passive_id": &"command_aura"}),
	]
	var players: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(8, 8), 50, 100),
	]
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(enemies, players)

	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(100, snap)

	assert_int(cmd.action_type).override_failure_message(
		"protector distant from commander must MOVE toward; got %d" % cmd.action_type
	).is_equal(int(AIActionCommand.ActionType.MOVE))
	# Destination must be closer to commander than starting position (distance 6).
	var dest: Vector2i = cmd.move_target
	var commander_pos: Vector2i = Vector2i(5, 5)
	var dest_dist: int = absi(dest.x - commander_pos.x) + absi(dest.y - commander_pos.y)
	assert_int(dest_dist).override_failure_message(
		"protector MOVE destination must be closer to commander; dest=%s dist=%d (was 6)"
		% [dest, dest_dist]
	).is_less(6)


func test_protector_intercepts_threat_near_commander() -> void:
	# Protector adjacent to commander; player unit also close to commander AND
	# in protector's attack range. Expected: ATTACK (intercept the threat).
	#   layout: commander @ (5,5); protector @ (5,4); player @ (5,3)
	#   protector→player dist = 1 (in attack range), player→commander dist = 2
	#   (within "threatening" radius ≤ 2 → intercept_bonus fires).
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(100, &"protector", Vector2i(5, 4),
				100, 100, {"attack_range": 1}),
		BattleStateSnapshotFactory.unit(101, &"coordinator", Vector2i(5, 5),
				100, 100, {"passive_id": &"command_aura"}),
	]
	var players: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(5, 3), 50, 100),
	]
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(enemies, players)

	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(100, snap)

	assert_int(cmd.action_type).override_failure_message(
		"protector with player adjacent to commander must ATTACK (intercept); got %d"
		% cmd.action_type
	).is_equal(int(AIActionCommand.ActionType.ATTACK))
	assert_int(cmd.attack_target_unit_id).is_equal(0)


func test_protector_without_ally_commander_falls_back_to_aggressor() -> void:
	# No ally with command_aura present → protector behaves like aggressor.
	# Aggressor adjacent to player → ATTACK.
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(100, &"protector", Vector2i(5, 5),
				100, 100, {"attack_range": 1}),
	]
	var players: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(5, 6), 50, 100),
	]
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(enemies, players)

	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(100, snap)

	# No ally commander → degrades to aggressor → adjacent player → ATTACK.
	assert_int(cmd.action_type).override_failure_message(
		"protector with no ally commander must fall back to aggressor (ATTACK); got %d"
		% cmd.action_type
	).is_equal(int(AIActionCommand.ActionType.ATTACK))


func test_protector_defends_when_adjacent_to_wounded_commander_and_no_threat() -> void:
	# Protector adjacent to a wounded commander; no player in attack range of protector.
	# DEFEND should outscore WAIT under those conditions.
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(100, &"protector", Vector2i(5, 4),
				100, 100, {"attack_range": 1}),
		BattleStateSnapshotFactory.unit(101, &"coordinator", Vector2i(5, 5),
				40, 100, {"passive_id": &"command_aura"}),  # wounded (HP=40/100=0.40)
	]
	var players: Array[Dictionary] = [
		# Far from protector — no ATTACK candidate
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(0, 0), 50, 100),
	]
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(enemies, players)

	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(100, snap)

	# DEFEND is the highest-scoring choice when the only nearby option is to
	# guard the wounded commander.
	assert_int(cmd.action_type).override_failure_message(
		"protector guarding wounded commander with no ATTACK target must DEFEND; got %d"
		% cmd.action_type
	).is_equal(int(AIActionCommand.ActionType.DEFEND))


# ─── Determinism (mirror existing AC-AI-2 pattern for the new archetypes) ────


func test_berserker_decide_is_deterministic_100_invocations() -> void:
	var snap: BattleStateSnapshot = _make_berserker_scenario()
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var baseline: AIActionCommand = ai.decide(100, snap)
	for i in 99:
		var cmd: AIActionCommand = ai.decide(100, snap)
		assert_int(cmd.action_type).is_equal(baseline.action_type)
		assert_int(cmd.attack_target_unit_id).is_equal(baseline.attack_target_unit_id)
		assert_int(cmd.move_target.x).is_equal(baseline.move_target.x)
		assert_int(cmd.move_target.y).is_equal(baseline.move_target.y)


func test_protector_decide_is_deterministic_100_invocations() -> void:
	var snap: BattleStateSnapshot = _make_protector_scenario()
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var baseline: AIActionCommand = ai.decide(100, snap)
	for i in 99:
		var cmd: AIActionCommand = ai.decide(100, snap)
		assert_int(cmd.action_type).is_equal(baseline.action_type)
		assert_int(cmd.attack_target_unit_id).is_equal(baseline.attack_target_unit_id)
		assert_int(cmd.move_target.x).is_equal(baseline.move_target.x)
		assert_int(cmd.move_target.y).is_equal(baseline.move_target.y)


# ─── Helpers ──────────────────────────────────────────────────────────────────


func _make_berserker_scenario() -> BattleStateSnapshot:
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(100, &"berserker", Vector2i(5, 5),
				40, 100, {"attack_range": 1}),
	]
	var players: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(5, 6), 50, 100),
	]
	return BattleStateSnapshotFactory.make(enemies, players)


func _make_protector_scenario() -> BattleStateSnapshot:
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(100, &"protector", Vector2i(2, 2),
				100, 100, {"attack_range": 1, "move_range": 3}),
		BattleStateSnapshotFactory.unit(101, &"coordinator", Vector2i(5, 5),
				100, 100, {"passive_id": &"command_aura"}),
	]
	var players: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(8, 8), 50, 100),
	]
	return BattleStateSnapshotFactory.make(enemies, players)
