## civilian_tokens_visuals_test.gd
##
## ADR-0022 visualization smoke — verifies CivilianTokensVisuals refresh()
## reconciles polygon children + carrier overlay state from a controller
## snapshot. Pure state-machine smoke; full visual fidelity is verified by
## windowed manual playtest (S81 / S82 candidate).
extends GdUnitTestSuite

const _GridControllerScript: GDScript = preload("res://src/feature/grid_battle/grid_battle_controller.gd")


# ─── Controller + ChapterVisuals stubs ────────────────────────────────────────


class _ChapterVisualsStub:
	extends Node2D

	## carrier_unit_id -> bool (last-set overlay state)
	var overlay_state: Dictionary = {}

	func set_carrier_escort_overlay(carrier_unit_id: int, active: bool) -> void:
		overlay_state[carrier_unit_id] = active


# ─── Tests ────────────────────────────────────────────────────────────────────


func test_civilian_visuals_spawns_polygon_per_token_after_first_refresh() -> void:
	# Arrange — controller with 3 IDLE tokens
	var controller: Node = _GridControllerScript.new()
	controller.set_civilian_config({
		"positions": [[3, 2], [5, 3], [4, 5]],
		"evacuate_zone_max_col": 0,
	})
	var stub_visuals: _ChapterVisualsStub = _ChapterVisualsStub.new()
	var civ_vis: CivilianTokensVisuals = CivilianTokensVisuals.new()
	add_child(civ_vis)  # needed for add_child(polygon) within civ_vis

	# Act
	civ_vis.set_controller(controller, stub_visuals)

	# Assert — 3 Polygon2D children spawned
	var polys: int = 0
	for child: Node in civ_vis.get_children():
		if child is Polygon2D:
			polys += 1
	assert_int(polys).override_failure_message(
		"Expected 3 polygon children (1 per IDLE token); got %d" % polys
	).is_equal(3)
	assert_int(stub_visuals.overlay_state.size()).is_equal(0)

	civ_vis.free()
	controller.free()
	stub_visuals.free()


func test_civilian_visuals_hides_polygon_on_escorted_transition_and_sets_overlay() -> void:
	# Arrange — 1 IDLE token + initial refresh
	var controller: Node = _GridControllerScript.new()
	controller.set_civilian_config({
		"positions": [[3, 2]],
		"evacuate_zone_max_col": 0,
	})
	var stub_visuals: _ChapterVisualsStub = _ChapterVisualsStub.new()
	var civ_vis: CivilianTokensVisuals = CivilianTokensVisuals.new()
	add_child(civ_vis)
	civ_vis.set_controller(controller, stub_visuals)

	# Act — bind the token to a carrier directly (mirrors what
	# _civilian_check_pickup_for_unit would do in the natural flow) + refresh
	var tokens: Array[CivilianToken] = controller._civilian_tokens
	tokens[0].bind_to_carrier(7)
	civ_vis.refresh()

	# Assert — polygon hidden + carrier overlay turned on for unit_id=7
	var poly: Polygon2D = civ_vis.get_node_or_null("Civilian_0") as Polygon2D
	assert_object(poly).is_not_null()
	assert_bool(poly.visible).override_failure_message(
		"Expected IDLE→ESCORTED polygon visible=false (carrier overlay takes over)"
	).is_false()
	assert_bool(stub_visuals.overlay_state.get(7, false) as bool).override_failure_message(
		"Expected set_carrier_escort_overlay(7, true) call on IDLE→ESCORTED"
	).is_true()

	civ_vis.free()
	controller.free()
	stub_visuals.free()


func test_civilian_visuals_clears_overlay_and_fades_polygon_on_saved_transition() -> void:
	# Arrange — 1 ESCORTED token (post-pickup state) + initial refresh
	var controller: Node = _GridControllerScript.new()
	controller.set_civilian_config({
		"positions": [[1, 2]],
		"evacuate_zone_max_col": 0,
	})
	var stub_visuals: _ChapterVisualsStub = _ChapterVisualsStub.new()
	var civ_vis: CivilianTokensVisuals = CivilianTokensVisuals.new()
	add_child(civ_vis)
	civ_vis.set_controller(controller, stub_visuals)
	# Force ESCORTED via direct bind + refresh to capture as the "prev" state.
	var tokens: Array[CivilianToken] = controller._civilian_tokens
	tokens[0].bind_to_carrier(3)
	civ_vis.refresh()
	# Sanity precondition — overlay enabled for carrier 3
	assert_bool(stub_visuals.overlay_state.get(3, false) as bool).is_true()

	# Act — commit save + refresh (mirrors _civilian_check_save_for_unit's flow)
	tokens[0].commit_save()
	controller._civilian_commit_save(0)
	civ_vis.refresh()

	# Assert — overlay disabled for carrier 3; polygon will fade (start visible
	# so the tween has something to animate)
	assert_bool(stub_visuals.overlay_state.get(3, true) as bool).override_failure_message(
		"Expected set_carrier_escort_overlay(3, false) call on ESCORTED→SAVED"
	).is_false()
	var poly: Polygon2D = civ_vis.get_node_or_null("Civilian_0") as Polygon2D
	assert_object(poly).is_not_null()
	# Polygon is set visible at start of fade so the tween can animate the alpha.
	# Tween scheduler may not have advanced inside this test (no process_frame),
	# so we don't assert final alpha here — only the synchronous visibility flip
	# and the overlay-clear are deterministic.
	assert_bool(poly.visible).is_true()

	civ_vis.free()
	controller.free()
	stub_visuals.free()


func test_civilian_visuals_repositions_polygon_on_idle_recovery() -> void:
	# Arrange — 1 ESCORTED token bound to carrier; pre-recovery refresh
	var controller: Node = _GridControllerScript.new()
	controller.set_civilian_config({
		"positions": [[5, 5]],
		"evacuate_zone_max_col": 0,
	})
	var stub_visuals: _ChapterVisualsStub = _ChapterVisualsStub.new()
	var civ_vis: CivilianTokensVisuals = CivilianTokensVisuals.new()
	add_child(civ_vis)
	civ_vis.set_controller(controller, stub_visuals)
	var tokens: Array[CivilianToken] = controller._civilian_tokens
	tokens[0].bind_to_carrier(2)
	civ_vis.refresh()

	# Act — carrier dies at (7, 9); token recovers to that cell as IDLE
	tokens[0].recover_to_idle(Vector2i(7, 9))
	civ_vis.refresh()

	# Assert — polygon visible at the new cell's world position
	var poly: Polygon2D = civ_vis.get_node_or_null("Civilian_0") as Polygon2D
	assert_object(poly).is_not_null()
	assert_bool(poly.visible).is_true()
	var expected_pos: Vector2 = Vector2(
		7 * CivilianTokensVisuals.TILE_SIZE + CivilianTokensVisuals.TILE_SIZE / 2.0,
		9 * CivilianTokensVisuals.TILE_SIZE + CivilianTokensVisuals.TILE_SIZE / 2.0,
	)
	assert_vector(poly.position).is_equal(expected_pos)
	# Overlay for carrier 2 cleared since token is no longer ESCORTED.
	assert_bool(stub_visuals.overlay_state.get(2, true) as bool).is_false()

	civ_vis.free()
	controller.free()
	stub_visuals.free()
