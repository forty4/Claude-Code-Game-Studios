## ai_system_caster_status_aware_test.gd
##
## Session-22 — AI caster-side status awareness. Mirror of session-18
## target-side work: when the AI unit itself carries SLOW or POISON, the
## ATTACK candidate scoring is adjusted via `_caster_status_score_modifier`:
##
##   SLOW on caster  → -AI_CASTER_SLOW_PENALTY (atk reduced 20%, weaker hit)
##   POISON + dying  → +AI_CASTER_POISON_DYING_BONUS ("go down swinging")
##   POISON + healthy → -AI_CASTER_POISON_HEALTHY_PENALTY (avoid risk)
##   Multiple statuses sum additively. STUN omitted — stunned units don't act.
##
## Coverage:
##   - Modifier helper isolation: 0 for empty / missing status_ids
##   - Modifier helper isolation: each single status returns expected value
##   - Modifier helper isolation: multiple statuses sum
##   - Integration (decide): poison-dying holder flips DEFEND → ATTACK
##   - Regression: no-status caster behaves identically to pre-S22
extends GdUnitTestSuite


func before_test() -> void:
	(load("res://src/foundation/balance/balance_constants.gd") as GDScript).set("_cache_loaded", false)


# ─── Helper isolation (pure-function over caster unit Dictionary) ────────────


func test_modifier_returns_zero_for_empty_status_ids() -> void:
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var unit: Dictionary = {"status_ids": [], "hp_current": 80, "hp_max": 100}
	assert_float(ai._caster_status_score_modifier(unit)).is_equal_approx(0.0, 0.001)


func test_modifier_returns_zero_when_status_ids_missing() -> void:
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var unit: Dictionary = {"hp_current": 80, "hp_max": 100}
	assert_float(ai._caster_status_score_modifier(unit)).is_equal_approx(0.0, 0.001)


func test_modifier_returns_negative_for_slow_caster() -> void:
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var unit: Dictionary = {
		"status_ids": [&"slow"] as Array[StringName],
		"hp_current": 80, "hp_max": 100,
	}
	var expected: float = -float(BalanceConstants.get_const("AI_CASTER_SLOW_PENALTY"))
	assert_float(ai._caster_status_score_modifier(unit)).is_equal_approx(expected, 0.001)


func test_modifier_returns_positive_for_poison_dying_caster() -> void:
	# hp_pct = 20/100 = 0.20, below the 0.30 dying threshold → DYING_BONUS applied.
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var unit: Dictionary = {
		"status_ids": [&"poison"] as Array[StringName],
		"hp_current": 20, "hp_max": 100,
	}
	var expected: float = float(BalanceConstants.get_const("AI_CASTER_POISON_DYING_BONUS"))
	assert_float(ai._caster_status_score_modifier(unit)).is_equal_approx(expected, 0.001)


func test_modifier_returns_negative_for_poison_healthy_caster() -> void:
	# hp_pct = 80/100 = 0.80, above threshold → HEALTHY_PENALTY applied.
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var unit: Dictionary = {
		"status_ids": [&"poison"] as Array[StringName],
		"hp_current": 80, "hp_max": 100,
	}
	var expected: float = -float(BalanceConstants.get_const("AI_CASTER_POISON_HEALTHY_PENALTY"))
	assert_float(ai._caster_status_score_modifier(unit)).is_equal_approx(expected, 0.001)


func test_modifier_sums_slow_and_poison_healthy_additively() -> void:
	# SLOW + POISON (healthy) → -SLOW_PENALTY - HEALTHY_PENALTY
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var unit: Dictionary = {
		"status_ids": [&"slow", &"poison"] as Array[StringName],
		"hp_current": 80, "hp_max": 100,
	}
	var expected: float = (
		-float(BalanceConstants.get_const("AI_CASTER_SLOW_PENALTY"))
		- float(BalanceConstants.get_const("AI_CASTER_POISON_HEALTHY_PENALTY"))
	)
	assert_float(ai._caster_status_score_modifier(unit)).is_equal_approx(expected, 0.001)


func test_modifier_sums_slow_and_poison_dying_additively() -> void:
	# SLOW + POISON (dying) → -SLOW_PENALTY + DYING_BONUS
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var unit: Dictionary = {
		"status_ids": [&"slow", &"poison"] as Array[StringName],
		"hp_current": 20, "hp_max": 100,
	}
	var expected: float = (
		-float(BalanceConstants.get_const("AI_CASTER_SLOW_PENALTY"))
		+ float(BalanceConstants.get_const("AI_CASTER_POISON_DYING_BONUS"))
	)
	assert_float(ai._caster_status_score_modifier(unit)).is_equal_approx(expected, 0.001)


# ─── Integration via decide() — caster-status flips action choice ────────────


func test_poison_dying_holder_flips_from_defend_to_attack() -> void:
	# Holder at chokepoint with adjacent target. Without caster status:
	#   ATTACK = 18 + 0 + 0 = 18
	#   DEFEND = 20 (any_in_range)
	#   WAIT = -30 (any_in_range, so chokepoint doesn't trigger anchor reward)
	#   → DEFEND wins (20 > 18)
	# With POISON_DYING caster (+AI_CASTER_POISON_DYING_BONUS=8 on ATTACK):
	#   ATTACK = 18 + 0 + 8 = 26
	#   DEFEND = 20 (unchanged — caster modifier ATTACK-only)
	#   → ATTACK wins (26 > 20). The dying holder commits to one last swing.
	var holder: Dictionary = BattleStateSnapshotFactory.unit(
		200, &"holder", Vector2i(5, 5), 20, 100,
		{"status_ids": [&"poison"] as Array[StringName]})
	var target: Dictionary = BattleStateSnapshotFactory.unit(
		1, &"", Vector2i(6, 5), 80, 100)
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(
		[holder], [target], Vector2i(15, 15), [Vector2i(5, 5)])
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(200, snap)
	assert_int(cmd.action_type).override_failure_message(
		"poison-dying holder should flip from DEFEND to ATTACK due to caster DYING_BONUS"
	).is_equal(AIActionCommand.ActionType.ATTACK)
	assert_int(cmd.attack_target_unit_id).is_equal(1)


func test_clean_holder_picks_defend_over_attack_baseline() -> void:
	# Regression: same scenario as above but with NO status on the holder.
	# Establishes the baseline ATTACK(18) < DEFEND(20) — proves the flip in
	# the previous test is caused specifically by the caster status modifier,
	# not by some other scoring change.
	var holder: Dictionary = BattleStateSnapshotFactory.unit(
		200, &"holder", Vector2i(5, 5), 20, 100)
	var target: Dictionary = BattleStateSnapshotFactory.unit(
		1, &"", Vector2i(6, 5), 80, 100)
	var snap: BattleStateSnapshot = BattleStateSnapshotFactory.make(
		[holder], [target], Vector2i(15, 15), [Vector2i(5, 5)])
	var ai: AISystem = AISystem.new()
	auto_free(ai)
	var cmd: AIActionCommand = ai.decide(200, snap)
	assert_int(cmd.action_type).override_failure_message(
		"clean holder with adjacent target should pick DEFEND (20) over ATTACK (18)"
	).is_equal(AIActionCommand.ActionType.DEFEND)


func test_no_status_caster_aggressor_behaves_identically_to_pre_session_22() -> void:
	# Sanity: an aggressor with NO status_ids and a single adjacent target picks
	# that target unchanged. Confirms the new modifier is a no-op when absent.
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
