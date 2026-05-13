extends GdUnitTestSuite

## Boots battle_scene.tscn headlessly and runs multiple rounds of the natural
## turn loop. Verifies the turn keeps advancing — reproduces the user-reported
## "after several attacks the AI hangs" symptom if it actually exists in the
## logic layer (vs. being a window-only oddity).

var _battle_scene: Node = null


func before_test() -> void:
	var scene: PackedScene = load("res://scenes/battle/battle_scene.tscn") as PackedScene
	_battle_scene = scene.instantiate()
	get_tree().root.add_child(_battle_scene)
	# Allow boot + ChapterVisuals mount.
	await get_tree().create_timer(2.0).timeout


func after_test() -> void:
	if is_instance_valid(_battle_scene):
		get_tree().root.remove_child(_battle_scene)
		_battle_scene.queue_free()


## Drive the loop by injecting player declare_actions when it's the player's
## turn. Record every active_unit_changed transition to confirm the loop keeps
## advancing through MANY turns, including after AI MOVE_AND_ATTACKs that
## target dead defenders or fail attack-range post-move.
func test_multiple_rounds_keep_advancing_through_natural_loop() -> void:
	var grid: Node = _battle_scene.get("_grid_controller")
	assert(grid != null, "grid_controller wired after boot")

	var unit_turn_log: Array = []
	var battle_outcome: Array = []
	grid.active_unit_changed.connect(func(uid: int) -> void:
		unit_turn_log.append({"unit": uid, "ts": Time.get_ticks_msec()}))
	grid.battle_outcome_resolved.connect(func(outcome: StringName, _data: Dictionary) -> void:
		battle_outcome.append(outcome))

	# Run for up to 30 simulated seconds, accelerating by injecting player
	# WAIT declare_actions when the active unit is player-controlled.
	var deadline_ms: int = Time.get_ticks_msec() + 30000
	var max_turns: int = 60
	var seen_player_turns: int = 0
	var last_active_change_ms: int = Time.get_ticks_msec()
	var stall_threshold_ms: int = 4000  # 4s of no turn change = HANG

	while unit_turn_log.size() < max_turns and Time.get_ticks_msec() < deadline_ms:
		var active: int = grid.get_active_turn_unit_id()
		if active == -1:
			await get_tree().create_timer(0.05).timeout
			continue
		var unit: Variant = grid.get_battle_unit(active)
		if unit == null:
			await get_tree().create_timer(0.05).timeout
			continue
		if unit.is_player_controlled:
			# Inject WAIT so player turn ends cleanly (no manual click).
			var turn_runner: Node = _battle_scene.get("_turn_runner")
			turn_runner.declare_action(active, 4, null)  # 4 = WAIT
			seen_player_turns += 1
			await get_tree().create_timer(0.1).timeout
		else:
			# Wait for AI to act (or hang) — natural loop should advance.
			await get_tree().create_timer(0.1).timeout

		# If the battle resolved, this is NOT a hang — just clean termination.
		if battle_outcome.size() > 0:
			print("[MULTI-ROUND] battle ended: outcome=%s after %d turns"
				% [battle_outcome[0], unit_turn_log.size()])
			break

		# Detect stall: no active_unit_changed for stall_threshold_ms.
		if unit_turn_log.size() > 0:
			var last_log_ts: int = unit_turn_log[unit_turn_log.size() - 1].ts
			if Time.get_ticks_msec() - last_log_ts > stall_threshold_ms:
				fail("Turn loop STALLED on unit=%d after %d turns. last activity %dms ago"
					% [active, unit_turn_log.size(), Time.get_ticks_msec() - last_log_ts])
				return

	print("[MULTI-ROUND] saw %d turn changes, %d player turns acted"
		% [unit_turn_log.size(), seen_player_turns])

	# Success criterion: at least N turns advanced (loop didn't stall).
	assert_int(unit_turn_log.size()).override_failure_message(
		"Turn loop should have advanced ≥10 turns; only saw %d" % unit_turn_log.size()
	).is_greater_equal(10)
	assert_int(seen_player_turns).override_failure_message(
		"Should have completed ≥3 player turns; only completed %d" % seen_player_turns
	).is_greater_equal(3)
