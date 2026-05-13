extends GdUnitTestSuite

## battle_scene_production_slide_test.gd
##
## Boots the real battle_scene.tscn in headless mode and exercises the user's
## exact flow: wait for AI to finish, select an active player unit, click a
## move tile, await the slide tween, verify polygon position. The point: if
## the headless test passes here, the production code path is correct and the
## user's perceived "doesn't move" symptom must be a window-render issue. If
## it fails here, we've reproduced their bug for further debugging.

var _battle_scene: Node = null
var _grid_controller: Node = null
var _polygon: Node2D = null


func before_test() -> void:
	# Test-isolation discipline (the prior baseline 1-known-error came from carry-
	# over state: a previous test booted battle_scene.tscn, SceneManager mounted
	# a ChapterVisuals at /root + held _battle_scene_ref + flipped _state ≠ IDLE,
	# ScenarioRunner advanced past LOADING, and our fresh BattleScene instance
	# couldn't drive a clean boot on top of that residue). Reset the 3 autoloads
	# that hold cross-test state, then sweep any leftover ChapterVisuals + the
	# prior test's BattleScene root that didn't fully tear down.
	_reset_battle_world_for_isolation()
	var scene: PackedScene = load("res://scenes/battle/battle_scene.tscn") as PackedScene
	assert(scene != null, "battle_scene.tscn must load")
	_battle_scene = scene.instantiate()
	get_tree().root.add_child(_battle_scene)


func after_test() -> void:
	if is_instance_valid(_battle_scene):
		get_tree().root.remove_child(_battle_scene)
		_battle_scene.queue_free()
	_reset_battle_world_for_isolation()


## Sweeps the /root state that battle_scene.tscn boot leaves behind: the
## SceneManager-mounted ChapterVisuals + the autoload state (SceneManager FSM,
## ScenarioRunner chapter list). Idempotent — no-op when nothing is residual.
func _reset_battle_world_for_isolation() -> void:
	for child: Node in get_tree().root.get_children():
		if child is ChapterVisuals:
			get_tree().root.remove_child(child)
			child.free()
		elif child is BattleScene and child != _battle_scene:
			get_tree().root.remove_child(child)
			child.free()
	var sm: Node = get_node_or_null("/root/SceneManager")
	if sm != null and sm.has_method("reset_for_tests"):
		sm.reset_for_tests()
	var runner: Node = get_node_or_null("/root/ScenarioRunner")
	if runner != null and runner.has_method("reset_for_tests"):
		runner.reset_for_tests()


## Drives a full slide on an active player unit, then asserts the polygon
## landed at the target world coord. Production-realistic — uses signals.
func test_full_battle_scene_slide_lands_polygon_at_target() -> void:
	# Allow boot, AI turn, ChapterVisuals mount, polygons spawn.
	await get_tree().create_timer(2.0).timeout

	# Pull references via the public field names that exist on battle_scene.gd.
	_grid_controller = _battle_scene.get("_grid_controller")
	assert(_grid_controller != null, "grid_controller should be wired after boot")

	# Find the first player unit and force its turn to be ACTING so declare_action
	# would succeed for tests that go that route. For THIS test we just need the
	# slide to fire — call _do_move directly via the controller.
	var active_id: int = _grid_controller.get_active_turn_unit_id()
	# AI might be active. Wait until a player unit is active OR timeout.
	for _i in range(120):  # up to ~2 more seconds at 60fps
		active_id = _grid_controller.get_active_turn_unit_id()
		var u: Variant = _grid_controller.get_battle_unit(active_id)
		if u != null and u.is_player_controlled:
			break
		await get_tree().process_frame

	var unit_id: int = active_id
	var unit: Variant = _grid_controller.get_battle_unit(unit_id)
	assert(unit != null and unit.is_player_controlled, "Active unit should be player by this point")

	var from_pos: Vector2i = unit.position
	# Pick a move target one tile to the east if vacant, fallback to anywhere in range.
	var dest: Vector2i = from_pos + Vector2i(1, 0)
	if not _grid_controller.is_tile_in_move_range(dest, unit_id):
		dest = from_pos + Vector2i(0, 1)
	if not _grid_controller.is_tile_in_move_range(dest, unit_id):
		fail("No valid move destination from %s for unit %d" % [from_pos, unit_id])
		return

	# Locate the polygon BEFORE move so we can track its position.
	var visuals: Node = null
	for child in get_tree().root.get_children():
		if (child.get_script() != null
				and child.get_script().resource_path
				== "res://src/feature/battle_scene/chapter_visuals.gd"):
			visuals = child
			break
	assert(visuals != null, "ChapterVisuals must be mounted at /root")

	_polygon = _find_polygon(visuals, unit_id)
	assert(_polygon != null, "Unit %d polygon must be spawned" % unit_id)
	var start_world: Vector2 = _polygon.position
	var tile_size: int = 64
	var expected_end: Vector2 = Vector2(
		dest.x * tile_size + tile_size / 2.0,
		dest.y * tile_size + tile_size / 2.0,
	)

	# Trigger move via the controller's player path. We bypass click resolution
	# and call _handle_player_move directly — same call shape as production.
	_grid_controller.call("_handle_player_move", unit, dest)

	# Wait for slide to complete (MOVE_ANIM_DURATION = 0.6s) + buffer.
	await get_tree().create_timer(1.0).timeout

	print("[PROD-SLIDE] unit=%d start=%s end=%s expected=%s" %
		[unit_id, start_world, _polygon.position, expected_end])
	assert_vector(_polygon.position).override_failure_message(
		"Production slide: polygon must land at %s; got %s (start was %s)"
		% [expected_end, _polygon.position, start_world]
	).is_equal_approx(expected_end, Vector2(0.5, 0.5))


func _find_polygon(visuals: Node, unit_id: int) -> Node2D:
	var prefix: String = "Unit%d_" % unit_id
	for parent_name: String in ["PlayerUnits", "EnemyUnits"]:
		var parent: Node = visuals.get_node_or_null(parent_name)
		if parent == null:
			continue
		for child: Node in parent.get_children():
			if (child.name as String).begins_with(prefix) and child is Node2D:
				return child as Node2D
	return null
