## ai_system_status_aware_test.gd
##
## Session-18 — AI status awareness. The per-archetype ATTACK candidate
## scoring functions add `_target_status_score_modifier(target)` to favour
## or avoid targets carrying status effects:
##
##   STUN on target  → -AI_TARGET_STUN_PENALTY (action already gone)
##   SLOW on target  → +AI_TARGET_SLOW_BONUS (weaker counter)
##   POISON + dying  → -AI_TARGET_POISON_DYING_PENALTY (don't waste ATK)
##   POISON + healthy → +AI_TARGET_POISON_HEALTHY_BONUS (vulnerable)
##   Multiple statuses sum additively.
##
## Coverage:
##   - Modifier helper isolation: 0 for empty / missing status_ids
##   - Modifier helper isolation: each single status returns expected value
##   - Modifier helper isolation: multiple statuses sum
##   - Integration (decide): aggressor avoids dying-poisoned over fresh target
##   - Integration (decide): aggressor prefers slowed over clean target
##   - Integration (decide): aggressor deprioritizes stunned target
##   - Integration (decide): no-status snapshot behaves identically to pre-S18
extends GdUnitTestSuite


func before_test() -> void:
	(load("res://src/foundation/balance/balance_constants.gd") as GDScript).set("_cache_loaded", false)


# ─── Helper isolation (pure-function over target Dictionary) ─────────────────


func test_modifier_returns_zero_for_empty_status_ids() -> void:
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var target: Dictionary = {"status_ids": [], "hp_current": 80, "hp_max": 100}
	assert_float(ai._target_status_score_modifier(target)).is_equal_approx(0.0, 0.001)


func test_modifier_returns_zero_when_status_ids_missing() -> void:
	# Target dict without "status_ids" key — default empty Array via get(default).
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var target: Dictionary = {"hp_current": 80, "hp_max": 100}
	assert_float(ai._target_status_score_modifier(target)).is_equal_approx(0.0, 0.001)


func test_modifier_returns_negative_for_stun() -> void:
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var target: Dictionary = {
		"status_ids": [&"stun"] as Array[StringName],
		"hp_current": 80, "hp_max": 100,
	}
	var expected: float = -float(BalanceConstants.get_const("AI_TARGET_STUN_PENALTY"))
	assert_float(ai._target_status_score_modifier(target)).is_equal_approx(expected, 0.001)


func test_modifier_returns_positive_for_slow() -> void:
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var target: Dictionary = {
		"status_ids": [&"slow"] as Array[StringName],
		"hp_current": 80, "hp_max": 100,
	}
	var expected: float = float(BalanceConstants.get_const("AI_TARGET_SLOW_BONUS"))
	assert_float(ai._target_status_score_modifier(target)).is_equal_approx(expected, 0.001)


func test_modifier_negative_for_poison_dying_target() -> void:
	# hp_pct = 20/100 = 0.20, below the 0.30 dying threshold → DYING_PENALTY applied.
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var target: Dictionary = {
		"status_ids": [&"poison"] as Array[StringName],
		"hp_current": 20, "hp_max": 100,
	}
	var expected: float = -float(BalanceConstants.get_const("AI_TARGET_POISON_DYING_PENALTY"))
	assert_float(ai._target_status_score_modifier(target)).is_equal_approx(expected, 0.001)


func test_modifier_positive_for_poison_healthy_target() -> void:
	# hp_pct = 80/100 = 0.80, above threshold → HEALTHY_BONUS applied.
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var target: Dictionary = {
		"status_ids": [&"poison"] as Array[StringName],
		"hp_current": 80, "hp_max": 100,
	}
	var expected: float = float(BalanceConstants.get_const("AI_TARGET_POISON_HEALTHY_BONUS"))
	assert_float(ai._target_status_score_modifier(target)).is_equal_approx(expected, 0.001)


func test_modifier_sums_multiple_statuses_additively() -> void:
	# STUN + SLOW + POISON (healthy) → -PENALTY + BONUS + BONUS
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var target: Dictionary = {
		"status_ids": [&"stun", &"slow", &"poison"] as Array[StringName],
		"hp_current": 80, "hp_max": 100,
	}
	var expected: float = (
		-float(BalanceConstants.get_const("AI_TARGET_STUN_PENALTY"))
		+ float(BalanceConstants.get_const("AI_TARGET_SLOW_BONUS"))
		+ float(BalanceConstants.get_const("AI_TARGET_POISON_HEALTHY_BONUS"))
	)
	assert_float(ai._target_status_score_modifier(target)).is_equal_approx(expected, 0.001)


# ─── Integration via decide() — aggressor archetype ──────────────────────────


func test_aggressor_prefers_clean_target_over_dying_poisoned_target() -> void:
	# Aggressor at (5,5). Two adjacent targets — one healthy clean, one dying
	# poisoned. The clean target should be chosen because the dying-poisoned
	# penalty pushes the poisoned target's ATTACK score below the clean one's,
	# even though the dying target would otherwise be irresistible to aggressor
	# (low-HP kill bonus).
	#
	# Aggressor ATTACK formula: 20 + (KILL_BONUS if hp_pct ≤ 0.30) + weakness
	#   - 0.5*dist + status_modifier
	#
	# Clean (hp 100/100): 20 + 0 + 20*(1-1) - 0.5*1 = 19.5
	# Dying poisoned (hp 20/100): 20 + 50 + 20*0.8 - 0.5*1 + (-8) = 77.5
	#   → poisoned still scored higher (kill bonus dominates). Test intent
	#   is "modifier shifts the gap" — verify scoring contains the modifier
	#   by comparing pre/post status presence on identical otherwise-equal
	#   target, not absolute winner.
	#
	# Simpler test: compare two equally-positioned targets where ONE is
	# dying-poisoned and the other is also dying but clean. Both get the
	# kill bonus; the poisoned one suffers an additional -POISON_DYING_PENALTY.
	# The clean target wins.
	var enemy: Dictionary = BattleStateSnapshotFactory.unit(
		200, &"aggressor", Vector2i(5, 5), 100, 100)
	var clean_dying: Dictionary = BattleStateSnapshotFactory.unit(
		1, &"", Vector2i(6, 5), 15, 100)  # hp 15/100, no status
	var poisoned_dying: Dictionary = BattleStateSnapshotFactory.unit(
		2, &"", Vector2i(4, 5), 15, 100,
		{"status_ids": [&"poison"] as Array[StringName]})
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(
		[enemy], [clean_dying, poisoned_dying])
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(200, snap)
	assert_int(cmd.action_type).is_equal(AIActionCommand.ActionType.ATTACK)
	assert_int(cmd.attack_target_unit_id).override_failure_message(
		"aggressor should attack the clean dying target (id 1), not the poisoned one (id 2)"
	).is_equal(1)


func test_aggressor_prefers_slowed_target_over_clean_target() -> void:
	# Two equal targets at same distance/HP; one is SLOWed. SLOW_BONUS
	# breaks the tie cleanly in favor of the slowed target.
	var enemy: Dictionary = BattleStateSnapshotFactory.unit(
		200, &"aggressor", Vector2i(5, 5), 100, 100)
	var clean: Dictionary = BattleStateSnapshotFactory.unit(
		1, &"", Vector2i(6, 5), 80, 100)
	var slowed: Dictionary = BattleStateSnapshotFactory.unit(
		2, &"", Vector2i(4, 5), 80, 100,
		{"status_ids": [&"slow"] as Array[StringName]})
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(
		[enemy], [clean, slowed])
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(200, snap)
	assert_int(cmd.action_type).is_equal(AIActionCommand.ActionType.ATTACK)
	assert_int(cmd.attack_target_unit_id).override_failure_message(
		"aggressor should prefer the slowed target (id 2) over the clean one (id 1)"
	).is_equal(2)


func test_aggressor_deprioritizes_stunned_target() -> void:
	# Two equal targets; one is STUNned. STUN_PENALTY pushes the stunned
	# target's score below the clean one — aggressor picks the clean.
	var enemy: Dictionary = BattleStateSnapshotFactory.unit(
		200, &"aggressor", Vector2i(5, 5), 100, 100)
	var clean: Dictionary = BattleStateSnapshotFactory.unit(
		1, &"", Vector2i(6, 5), 80, 100)
	var stunned: Dictionary = BattleStateSnapshotFactory.unit(
		2, &"", Vector2i(4, 5), 80, 100,
		{"status_ids": [&"stun"] as Array[StringName]})
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(
		[enemy], [clean, stunned])
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(200, snap)
	assert_int(cmd.action_type).is_equal(AIActionCommand.ActionType.ATTACK)
	assert_int(cmd.attack_target_unit_id).override_failure_message(
		"aggressor should prefer the clean target (id 1) over the stunned one (id 2)"
	).is_equal(1)


func test_no_status_snapshot_behaves_identically_to_pre_session_18() -> void:
	# Sanity: snapshot with NO status_ids on any unit produces the same ATTACK
	# decision as before session-18. Uses the existing kite-scenario shape;
	# expectation: the single adjacent target is chosen unchanged.
	var enemy: Dictionary = BattleStateSnapshotFactory.unit(
		200, &"aggressor", Vector2i(5, 5), 100, 100)
	var target: Dictionary = BattleStateSnapshotFactory.unit(
		1, &"", Vector2i(6, 5), 80, 100)
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(
		[enemy], [target])
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(200, snap)
	assert_int(cmd.action_type).is_equal(AIActionCommand.ActionType.ATTACK)
	assert_int(cmd.attack_target_unit_id).is_equal(1)
