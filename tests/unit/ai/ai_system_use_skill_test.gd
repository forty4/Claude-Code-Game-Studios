## ai_system_use_skill_test.gd
##
## Session-27 — verifies the AI USE_SKILL scoring upgrade. Pre-S27, all 6
## archetypes returned -100.0 for USE_SKILL except the coordinator's hardcoded
## rally check (which itself never actually fired because rally was a placeholder
## with no wired handler). Post-S27:
##   - _enumerate_candidates emits USE_SKILL only when the unit has a wired
##     skill_id AND skill_used==false (was hardcoded `&"rally"` for everyone).
##   - Each archetype's USE_SKILL branch scores against game-state context
##     (adjacent enemies / chokepoint+attack-range / commander wound / etc.)
##     so AI bosses actually fire their innate skills when the moment fits.
##
## Coverage matrix:
##   * Enumeration: skill_id empty → no candidate
##   * Enumeration: skill_used true → no candidate
##   * Enumeration: skill_id wired + !used → candidate w/ unit's skill_id
##   * Aggressor adjacent enemy → USE_SKILL beats ATTACK
##   * Skirmisher adjacent enemy (threatened) → USE_SKILL beats kite-MOVE
##   * Holder at chokepoint + enemy in range → USE_SKILL beats DEFEND
##   * Coordinator ≥2 adjacent allies → USE_SKILL (formation context)
##   * Coordinator 0 adjacent allies → falls through to ATTACK/MOVE (no skill)
##   * Berserker adjacent enemy → USE_SKILL beats ATTACK (death-throes burst)
##   * Protector wounded protectee → USE_SKILL beats DEFEND
extends GdUnitTestSuite


# ─── Enumeration gates ───────────────────────────────────────────────────────


## skill_id missing/empty → no USE_SKILL candidate enumerated → AI cannot
## pick USE_SKILL → falls through to other actions.
func test_no_use_skill_candidate_when_skill_id_empty() -> void:
	# Aggressor adjacent to a player target, NO skill wired → USE_SKILL not in
	# the candidate set, so the AI picks ATTACK on the only player.
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(2, &"aggressor", Vector2i(5, 5), 100, 100),
	]
	var players: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(5, 6), 50, 100),
	]
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(enemies, players)
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(2, snap)
	assert_int(cmd.action_type).override_failure_message(
		"S27: with no skill_id, USE_SKILL must not enumerate — AI should pick ATTACK"
	).is_equal(int(AIActionCommand.ActionType.ATTACK))


## skill_used==true → no USE_SKILL candidate (one-shot already exhausted).
func test_no_use_skill_candidate_when_skill_used_true() -> void:
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(2, &"aggressor", Vector2i(5, 5), 100, 100,
				{"skill_id": &"skill_thunder_roar", "skill_used": true}),
	]
	var players: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(5, 6), 50, 100),
	]
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(enemies, players)
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(2, snap)
	assert_int(cmd.action_type).override_failure_message(
		"S27: skill_used==true must exclude USE_SKILL from enumeration"
	).is_equal(int(AIActionCommand.ActionType.ATTACK))


# ─── Per-archetype scoring ────────────────────────────────────────────────────


## Aggressor adjacent to enemy + wired skill → USE_SKILL beats ATTACK base (20).
func test_aggressor_with_adjacent_enemy_picks_use_skill() -> void:
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(2, &"aggressor", Vector2i(5, 5), 100, 100,
				{"skill_id": &"skill_thunder_roar", "skill_used": false}),
	]
	var players: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(5, 6), 100, 100),
	]
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(enemies, players)
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(2, snap)
	assert_int(cmd.action_type).override_failure_message(
		"S27: aggressor + adjacent enemy must pick USE_SKILL over ATTACK; got %d" % cmd.action_type
	).is_equal(int(AIActionCommand.ActionType.USE_SKILL))
	assert_str(String(cmd.skill_id)).is_equal("skill_thunder_roar")


## Aggressor with skill but NO adjacent enemies → falls through (USE_SKILL -50)
## → ATTACK wins if a player is in attack_range; else MOVE toward nearest.
func test_aggressor_with_skill_but_no_adjacent_enemy_does_not_pick_use_skill() -> void:
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(2, &"aggressor", Vector2i(5, 5), 100, 100,
				{"skill_id": &"skill_thunder_roar", "skill_used": false}),
	]
	var players: Array[Dictionary] = [
		# Distance 4 — well outside both attack_range AND adjacency.
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(9, 5), 100, 100),
	]
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(enemies, players)
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(2, snap)
	assert_int(cmd.action_type).override_failure_message(
		"S27: aggressor with skill but no adjacent enemy must NOT pick USE_SKILL; got %d" % cmd.action_type
	).is_not_equal(int(AIActionCommand.ActionType.USE_SKILL))


## Skirmisher threatened by adjacent enemy → USE_SKILL beats kite-MOVE.
## Pre-S27 skirmisher always picked MOVE-away. Post-S27 they spend their skill
## (skill_charm — turn-waste + slow on adjacent enemies) defensively.
func test_skirmisher_with_adjacent_enemy_picks_use_skill_for_disruption() -> void:
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(2, &"skirmisher", Vector2i(5, 5), 100, 100,
				{"skill_id": &"skill_charm", "skill_used": false, "attack_range": 2}),
	]
	var players: Array[Dictionary] = [
		# Adjacent — skirmisher is threatened.
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(5, 6), 100, 100),
	]
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(enemies, players)
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(2, snap)
	assert_int(cmd.action_type).override_failure_message(
		"S27: threatened skirmisher must pick USE_SKILL (charm disrupts adjacent threat); got %d"
				% cmd.action_type
	).is_equal(int(AIActionCommand.ActionType.USE_SKILL))


## Holder at chokepoint with enemy in attack_range → USE_SKILL beats DEFEND.
func test_holder_at_chokepoint_with_enemy_in_range_picks_use_skill() -> void:
	var chokepoints: Array[Vector2i] = [Vector2i(5, 5)]
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(2, &"holder", Vector2i(5, 5), 100, 100,
				{"skill_id": &"skill_naval_strategy", "skill_used": false}),
	]
	var players: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(5, 6), 100, 100),
	]
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(enemies, players, Vector2i(15, 15), chokepoints)
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(2, snap)
	assert_int(cmd.action_type).override_failure_message(
		"S27: holder at chokepoint + enemy in attack_range must pick USE_SKILL; got %d" % cmd.action_type
	).is_equal(int(AIActionCommand.ActionType.USE_SKILL))


## Holder away from chokepoint → USE_SKILL falls back to -50 → other actions win.
func test_holder_away_from_chokepoint_does_not_pick_use_skill() -> void:
	# Chokepoint at (5,5) but holder is at (5,7) — NOT at chokepoint.
	var chokepoints: Array[Vector2i] = [Vector2i(5, 5)]
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(2, &"holder", Vector2i(5, 7), 100, 100,
				{"skill_id": &"skill_naval_strategy", "skill_used": false}),
	]
	var players: Array[Dictionary] = [
		# Adjacent — would otherwise trigger DEFEND (any_in_range=true).
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(5, 8), 100, 100),
	]
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(enemies, players, Vector2i(15, 15), chokepoints)
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(2, snap)
	assert_int(cmd.action_type).override_failure_message(
		"S27: holder NOT at chokepoint must not pick USE_SKILL; got %d" % cmd.action_type
	).is_not_equal(int(AIActionCommand.ActionType.USE_SKILL))


## Berserker adjacent to player → USE_SKILL beats ATTACK base (25 vs 25+); 30
## from skill > 25 base + 0 low-HP-bonus when healthy → skill wins.
func test_berserker_with_adjacent_enemy_picks_use_skill() -> void:
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(2, &"berserker", Vector2i(5, 5), 100, 100,
				{"skill_id": &"skill_thunder_roar", "skill_used": false}),
	]
	var players: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(5, 6), 100, 100),
	]
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(enemies, players)
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(2, snap)
	assert_int(cmd.action_type).override_failure_message(
		"S27: berserker + adjacent enemy must pick USE_SKILL (death-throes burst); got %d" % cmd.action_type
	).is_equal(int(AIActionCommand.ActionType.USE_SKILL))


## Protector with wounded protectee (HP < 50%) → USE_SKILL beats DEFEND/ATTACK.
func test_protector_with_wounded_protectee_picks_use_skill() -> void:
	var enemies: Array[Dictionary] = [
		# Protector
		BattleStateSnapshotFactory.unit(2, &"protector", Vector2i(5, 5), 100, 100,
				{"skill_id": &"skill_thunder_roar", "skill_used": false}),
		# Wounded ally COMMANDER (the protectee).
		BattleStateSnapshotFactory.unit(3, &"coordinator", Vector2i(5, 4), 30, 100,
				{"passive_id": &"command_aura"}),
	]
	var players: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(5, 6), 100, 100),
	]
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(enemies, players)
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(2, snap)
	assert_int(cmd.action_type).override_failure_message(
		"S27: protector with wounded protectee must pick USE_SKILL; got %d" % cmd.action_type
	).is_equal(int(AIActionCommand.ActionType.USE_SKILL))


## Protector with healthy protectee → USE_SKILL -50 → other actions win.
func test_protector_with_healthy_protectee_does_not_pick_use_skill() -> void:
	var enemies: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(2, &"protector", Vector2i(5, 5), 100, 100,
				{"skill_id": &"skill_thunder_roar", "skill_used": false}),
		# Healthy ally COMMANDER (the protectee).
		BattleStateSnapshotFactory.unit(3, &"coordinator", Vector2i(5, 4), 100, 100,
				{"passive_id": &"command_aura"}),
	]
	var players: Array[Dictionary] = [
		BattleStateSnapshotFactory.unit(0, &"", Vector2i(5, 6), 100, 100),
	]
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(enemies, players)
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(2, snap)
	assert_int(cmd.action_type).override_failure_message(
		"S27: protector with healthy protectee must NOT pick USE_SKILL; got %d" % cmd.action_type
	).is_not_equal(int(AIActionCommand.ActionType.USE_SKILL))
