## screen_to_grid invariance + off-grid sentinel + 3-zoom fixture per ADR-0013 §Validation §1

extends GdUnitTestSuite

const BattleCameraScript: GDScript = preload("res://src/feature/camera/battle_camera.gd")
const MapGridStubScript: GDScript = preload("res://tests/helpers/map_grid_stub.gd")


func _make_camera_with_stub(map_dims: Vector2i = Vector2i(8, 8)) -> BattleCamera:
	# Reset BalanceConstants cache per G-15 isolation discipline
	(load("res://src/foundation/balance/balance_constants.gd") as GDScript).set("_cache_loaded", false)
	var stub: MapGridStub = MapGridStubScript.new()
	stub.set_dimensions_for_test(map_dims)
	add_child(stub)
	auto_free(stub)
	var cam: BattleCamera = BattleCameraScript.new()
	cam.setup(stub)
	add_child(cam)
	auto_free(cam)
	return cam


func test_screen_to_grid_returns_sentinel_for_negative_world_pos() -> void:
	# Test screen_to_grid with a screen position that GUARANTEEDLY maps to negative
	# world coords regardless of viewport size: massively-negative screen position.
	var cam: BattleCamera = _make_camera_with_stub()
	var coord: Vector2i = cam.screen_to_grid(Vector2(-99999, -99999))
	assert_that(coord).is_equal(Vector2i(-1, -1))


func test_screen_to_grid_returns_sentinel_for_far_off_grid() -> void:
	var cam: BattleCamera = _make_camera_with_stub(Vector2i(4, 4))
	# Click far beyond the 4x4 map
	var coord: Vector2i = cam.screen_to_grid(Vector2(99999, 99999))
	assert_that(coord).is_equal(Vector2i(-1, -1))


func test_screen_to_grid_returns_valid_coord_for_in_grid_click() -> void:
	var cam: BattleCamera = _make_camera_with_stub(Vector2i(8, 8))
	# Click on camera's current world position (which is centered on map by clamp)
	# should resolve to a tile inside [0, 8) × [0, 8)
	var center_screen: Vector2 = cam.get_viewport_rect().size * 0.5
	var coord: Vector2i = cam.screen_to_grid(center_screen)
	assert_that(coord.x).is_between(0, 7)
	assert_that(coord.y).is_between(0, 7)


func test_screen_to_grid_invariance_across_zoom_levels() -> void:
	# Per ADR-0013 §Validation §1 item 4: same click position returns same grid
	# coord across zoom levels. Session-16: default bumped 1.0 → 1.40; this test
	# exercises one zoom-in + one zoom-to-floor to cover the path.
	#
	# Session-45 — map_dims bumped 8 → 50 so the map (50×64=3200 world units)
	# exceeds the post-S45 viewport size (1920×1080, stretch_mode=canvas_items).
	# Pre-S45 headless viewport was effectively (0, 0) so the small 8×8 map
	# always exceeded viewport; pan_clamp left position untouched. Post-S45
	# viewport is real, so pan_clamp on an 8×8 map FORCES position to map
	# center every zoom — destroying the invariance the test asserts. A larger
	# map keeps pan_clamp in the "position stays put" branch.
	var cam: BattleCamera = _make_camera_with_stub(Vector2i(50, 50))
	# Session-45 — pre-position the camera at a clamp-safe coord for all 3
	# zoom levels exercised below (0.70 / 1.40 / 1.90). Without this, the
	# default position (0, 0) falls outside the clamp range at every zoom
	# step, so the first zoom delta snaps position into the range and the
	# rest of the test asserts against a moving target.
	#   zoom 0.70: half_view = 1371, range [1371, 1829]
	#   zoom 1.40: half_view =  685, range [ 685, 2515]
	#   zoom 1.90: half_view =  505, range [ 505, 2695]
	# (1620, 1620) is comfortably inside all three intersections AND off the
	# tile boundary at 1600=25*64 (avoids floating-point bin-flip risk where
	# floor(1599.999999/64) yields 24 instead of 25).
	cam.position = Vector2(1620.0, 1620.0)
	# Camera2D's canvas_transform updates on the next process_frame; force it
	# here so screen_to_grid (which reads get_canvas_transform()) sees the new
	# position immediately rather than the post-_ready (685, 685) clamp value.
	cam.force_update_scroll()
	var screen_pt: Vector2 = cam.get_viewport_rect().size * 0.5  # screen center
	var coord_at_default: Vector2i = cam.screen_to_grid(screen_pt)
	# Zoom in: 1.40 + 0.50 = 1.90 (within [0.70, 2.50])
	cam._apply_zoom_delta(0.50, screen_pt)
	cam.force_update_scroll()  # canvas_transform refresh after position math
	var coord_at_zoom_in: Vector2i = cam.screen_to_grid(screen_pt)
	assert_that(coord_at_zoom_in).is_equal(coord_at_default)
	# Zoom out past floor: 1.90 - 1.50 = 0.40 attempted, clamped to 0.70 floor
	cam._apply_zoom_delta(-1.50, screen_pt)
	cam.force_update_scroll()
	var coord_at_zoom_out: Vector2i = cam.screen_to_grid(screen_pt)
	assert_that(coord_at_zoom_out).is_equal(coord_at_default)
