extends GdUnitTestSuite

## Boots battle_scene.tscn headlessly, drives chapter 1's battle to its natural
## end (injecting player WAITs), and verifies the chapter-progression wiring:
##   1. BattleScene's scenario bootstrap put ScenarioRunner in BEAT_5_BATTLE on
##      chapter 1.
##   2. When the battle resolves, BattleOutcomeBridge publishes the BattleOutcome
##      on GameBus, so ScenarioRunner advances to BEAT_6_RESULT.
##   3. BattleScene._proceed_scenario() walks ScenarioRunner BEAT_6→7→8→9 and
##      lands on chapter 2's BEAT_1_ANCHOR (chapter index 0 → 1).
##
## The actual scene reload at the end of _proceed_scenario is a no-op here
## (current_scene is the GdUnit runner, not the BattleScene), which is exactly
## what we want — it lets us observe ScenarioRunner's post-transition state.

var _battle_scene: Node = null


func before_test() -> void:
	# Start ScenarioRunner from a clean slate so the BattleScene's bootstrap
	# loads shu_canon_full.json fresh on chapter 1 (not whatever a prior test left).
	ScenarioRunner.reset_for_tests()
	var scene: PackedScene = load("res://scenes/battle/battle_scene.tscn") as PackedScene
	assert(scene != null, "battle_scene.tscn must load")
	_battle_scene = scene.instantiate()
	get_tree().root.add_child(_battle_scene)
	# Allow boot + SceneManager async ChapterVisuals mount + polygon spawn.
	await get_tree().create_timer(2.0).timeout


func after_test() -> void:
	if is_instance_valid(_battle_scene):
		get_tree().root.remove_child(_battle_scene)
		# free() (not queue_free) per G-6: the BattleScene tree has no external
		# Callable references (lint_battle_scene_no_gamebus_subscriptions confirms
		# zero GameBus connections), so immediate free avoids leaving the whole
		# subtree as orphans for GdUnit4's between-test-and-after_test detector.
		_battle_scene.free()
	_battle_scene = null
	# Also drop the /root ChapterVisuals SceneManager mounted (it normally frees
	# this itself on battle_outcome_resolved, but free it defensively in case the
	# battle didn't resolve cleanly within the test deadline).
	for child: Node in get_tree().root.get_children():
		if child is ChapterVisuals:
			get_tree().root.remove_child(child)
			child.free()
	ScenarioRunner.reset_for_tests()


func test_battle_end_advances_scenario_then_proceed_reaches_chapter_2() -> void:
	# --- Arrange: confirm the bootstrap landed us in ch1's battle ---
	assert_int(ScenarioRunner.get_current_chapter_index()).override_failure_message(
		"BattleScene bootstrap should put ScenarioRunner on chapter 0; got %d"
		% ScenarioRunner.get_current_chapter_index()
	).is_equal(0)
	assert_int(ScenarioRunner.get_state() as int).override_failure_message(
		"BattleScene bootstrap should reach BEAT_5_BATTLE; got %s"
		% ScenarioRunner.State.keys()[ScenarioRunner.get_state()]
	).is_equal(ScenarioRunner.State.BEAT_5_BATTLE as int)

	var grid: Node = _battle_scene.get("_grid_controller")
	assert(grid != null, "grid_controller wired after boot")
	var turn_runner: Node = _battle_scene.get("_turn_runner")
	assert(turn_runner != null, "turn_runner wired after boot")

	# --- Act 1: drive the battle to its natural end (inject player WAITs) ---
	var outcome_seen: Array = []
	grid.battle_outcome_resolved.connect(func(o: StringName, _d: Dictionary) -> void:
		outcome_seen.append(o))
	var deadline_ms: int = Time.get_ticks_msec() + 30000
	while outcome_seen.is_empty() and Time.get_ticks_msec() < deadline_ms:
		var active: int = grid.get_active_turn_unit_id()
		if active == -1:
			await get_tree().create_timer(0.05).timeout
			continue
		var unit: Variant = grid.get_battle_unit(active)
		if unit != null and unit.is_player_controlled:
			turn_runner.declare_action(active, 4, null)  # 4 = WAIT
		await get_tree().create_timer(0.08).timeout
	assert_bool(outcome_seen.is_empty()).override_failure_message(
		"Battle never resolved within 30s — chapter-progression path can't be exercised"
	).is_false()
	print("[CHAPTER-PROG] ch1 battle ended: outcome=%s" % outcome_seen[0])

	# --- Assert 1: BattleOutcomeBridge published → ScenarioRunner at BEAT_6_RESULT ---
	var reached_beat6: bool = false
	for _i: int in 60:
		if ScenarioRunner.get_state() == ScenarioRunner.State.BEAT_6_RESULT:
			reached_beat6 = true
			break
		await get_tree().process_frame
	assert_bool(reached_beat6).override_failure_message(
		"ScenarioRunner should advance to BEAT_6_RESULT after the battle (BattleOutcomeBridge "
		+ "→ GameBus.battle_outcome_resolved); state is %s"
		% ScenarioRunner.State.keys()[ScenarioRunner.get_state()]
	).is_true()

	# --- Act 2 + Assert 2: proceed → ScenarioRunner walks to chapter 2's first beat ---
	await _battle_scene._proceed_scenario()
	assert_int(ScenarioRunner.get_current_chapter_index()).override_failure_message(
		"After _proceed_scenario, ScenarioRunner should be on chapter 1 (0-based index 1); got %d"
		% ScenarioRunner.get_current_chapter_index()
	).is_equal(1)
	assert_int(ScenarioRunner.get_state() as int).override_failure_message(
		"After _proceed_scenario, chapter 2 should be at BEAT_1_ANCHOR; got %s"
		% ScenarioRunner.State.keys()[ScenarioRunner.get_state()]
	).is_equal(ScenarioRunner.State.BEAT_1_ANCHOR as int)
