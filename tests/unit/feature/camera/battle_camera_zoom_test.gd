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


func test_default_zoom_is_one() -> void:
	var cam: BattleCamera = _make_camera()
	assert_float(cam.get_zoom_value()).is_equal_approx(1.0, 0.001)


func test_zoom_in_increments_by_step() -> void:
	var cam: BattleCamera = _make_camera()
	var screen_center: Vector2 = cam.get_viewport_rect().size * 0.5
	cam._apply_zoom_delta(0.10, screen_center)  # CAMERA_ZOOM_STEP = 0.10
	assert_float(cam.get_zoom_value()).is_equal_approx(1.10, 0.001)


func test_zoom_out_decrements_by_step() -> void:
	var cam: BattleCamera = _make_camera()
	var screen_center: Vector2 = cam.get_viewport_rect().size * 0.5
	cam._apply_zoom_delta(-0.10, screen_center)
	assert_float(cam.get_zoom_value()).is_equal_approx(0.90, 0.001)


func test_zoom_clamps_to_floor() -> void:
	var cam: BattleCamera = _make_camera()
	var screen_center: Vector2 = cam.get_viewport_rect().size * 0.5
	# Try to zoom out past floor (1.0 → 0.5 attempted, but floor is 0.70)
	cam._apply_zoom_delta(-0.50, screen_center)
	assert_float(cam.get_zoom_value()).is_equal_approx(0.70, 0.001)


func test_zoom_clamps_to_ceiling() -> void:
	var cam: BattleCamera = _make_camera()
	var screen_center: Vector2 = cam.get_viewport_rect().size * 0.5
	# Try to zoom in past ceiling (1.0 → 3.0 attempted, but ceiling is 2.00)
	cam._apply_zoom_delta(2.0, screen_center)
	assert_float(cam.get_zoom_value()).is_equal_approx(2.00, 0.001)


func test_zoom_at_floor_no_op_on_further_zoom_out() -> void:
	# Per ADR-0013 R-4: at zoom = 0.70 (floor), additional zoom-out is no-op
	var cam: BattleCamera = _make_camera()
	var screen_center: Vector2 = cam.get_viewport_rect().size * 0.5
	cam._apply_zoom_delta(-1.00, screen_center)  # clamp to 0.70
	var pos_before: Vector2 = cam.position
	cam._apply_zoom_delta(-0.10, screen_center)  # already at floor — should no-op
	assert_float(cam.get_zoom_value()).is_equal_approx(0.70, 0.001)
	assert_vector(cam.position).is_equal_approx(pos_before, Vector2(0.001, 0.001))
