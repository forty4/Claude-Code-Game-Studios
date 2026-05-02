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
	# Per ADR-0013 §Validation §1 item 4: same click position returns same grid coord
	# at zoom 0.70, 1.00, 2.00. We test that the SAME screen position resolves to
	# the SAME tile after zoom changes (cursor-stable zoom recipe preserves world pos).
	var cam: BattleCamera = _make_camera_with_stub(Vector2i(8, 8))
	var screen_pt: Vector2 = cam.get_viewport_rect().size * 0.5  # screen center
	var coord_at_default: Vector2i = cam.screen_to_grid(screen_pt)
	# Zoom in via internal helper
	cam._apply_zoom_delta(0.50, screen_pt)  # zoom 1.0 + 0.5 = 1.5 (clamped to 1.5 within range)
	var coord_at_zoom_in: Vector2i = cam.screen_to_grid(screen_pt)
	assert_that(coord_at_zoom_in).is_equal(coord_at_default)
	# Zoom back + further out
	cam._apply_zoom_delta(-0.80, screen_pt)  # 1.5 - 0.8 = 0.7 (clamped to 0.70 floor)
	var coord_at_zoom_out: Vector2i = cam.screen_to_grid(screen_pt)
	assert_that(coord_at_zoom_out).is_equal(coord_at_default)
