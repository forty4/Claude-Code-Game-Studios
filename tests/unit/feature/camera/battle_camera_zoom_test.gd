## Zoom range clamp + cursor-stable recipe per ADR-0013 §Validation §1 item 4 + R-4

extends GdUnitTestSuite

const BattleCameraScript: GDScript = preload("res://src/feature/camera/battle_camera.gd")
const MapGridStubScript: GDScript = preload("res://tests/helpers/map_grid_stub.gd")


func _make_camera() -> BattleCamera:
	(load("res://src/foundation/balance/balance_constants.gd") as GDScript).set("_cache_loaded", false)
	var stub: MapGridStub = MapGridStubScript.new()
	stub.set_dimensions_for_test(Vector2i(8, 8))
	add_child(stub)
	auto_free(stub)
	var cam: BattleCamera = BattleCameraScript.new()
	cam.setup(stub)
	add_child(cam)
	auto_free(cam)
	return cam


func test_default_zoom_matches_balance_constant() -> void:
	# Session-16: CAMERA_ZOOM_DEFAULT bumped from 1.0 to 1.40 so hero overlays
	# read at typical viewing distance without manual zoom.
	var cam: BattleCamera = _make_camera()
	assert_float(cam.get_zoom_value()).is_equal_approx(1.40, 0.001)


func test_zoom_in_increments_by_step() -> void:
	var cam: BattleCamera = _make_camera()
	var screen_center: Vector2 = cam.get_viewport_rect().size * 0.5
	cam._apply_zoom_delta(0.15, screen_center)  # CAMERA_ZOOM_STEP = 0.15
	assert_float(cam.get_zoom_value()).is_equal_approx(1.55, 0.001)


func test_zoom_out_decrements_by_step() -> void:
	var cam: BattleCamera = _make_camera()
	var screen_center: Vector2 = cam.get_viewport_rect().size * 0.5
	cam._apply_zoom_delta(-0.15, screen_center)
	assert_float(cam.get_zoom_value()).is_equal_approx(1.25, 0.001)


func test_zoom_clamps_to_floor() -> void:
	var cam: BattleCamera = _make_camera()
	var screen_center: Vector2 = cam.get_viewport_rect().size * 0.5
	# Try to zoom out past floor (1.40 → 0.40 attempted, but floor is 0.70)
	cam._apply_zoom_delta(-1.00, screen_center)
	assert_float(cam.get_zoom_value()).is_equal_approx(0.70, 0.001)


func test_zoom_clamps_to_ceiling() -> void:
	var cam: BattleCamera = _make_camera()
	var screen_center: Vector2 = cam.get_viewport_rect().size * 0.5
	# Try to zoom in past ceiling (1.40 → 3.40 attempted, but ceiling is 2.50)
	cam._apply_zoom_delta(2.0, screen_center)
	assert_float(cam.get_zoom_value()).is_equal_approx(2.50, 0.001)


func test_zoom_at_floor_no_op_on_further_zoom_out() -> void:
	# Per ADR-0013 R-4: at zoom = 0.70 (floor), additional zoom-out is no-op
	var cam: BattleCamera = _make_camera()
	var screen_center: Vector2 = cam.get_viewport_rect().size * 0.5
	cam._apply_zoom_delta(-1.50, screen_center)  # clamp to 0.70
	var pos_before: Vector2 = cam.position
	cam._apply_zoom_delta(-0.15, screen_center)  # already at floor — should no-op
	assert_float(cam.get_zoom_value()).is_equal_approx(0.70, 0.001)
	assert_vector(cam.position).is_equal_approx(pos_before, Vector2(0.001, 0.001))
