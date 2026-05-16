## Verifies BattleCamera._apply_pan_clamp centers the camera correctly on the
## ch02 (10×7) map. Regression for "ch02 grid renders in screen bottom-right
## corner instead of centered" (user report 2026-05-16).
extends GdUnitTestSuite

const BattleCameraScript: GDScript = preload("res://src/feature/camera/battle_camera.gd")
const MapGridStubScript: GDScript = preload("res://tests/helpers/map_grid_stub.gd")


func before_test() -> void:
	(load("res://src/foundation/balance/balance_constants.gd") as GDScript).set("_cache_loaded", false)


func test_pan_clamp_centers_camera_on_ch02_dimensions() -> void:
	# Arrange — ch02 dims = 10 cols × 7 rows = 640×448 world units.
	# Headless viewport defaults to ~1152×648 (varies by host); whatever it is,
	# the map should center horizontally. Test reads the actual viewport size.
	var stub: MapGridStub = MapGridStubScript.new()
	stub.set_dimensions_for_test(Vector2i(10, 7))
	add_child(stub)
	auto_free(stub)
	var cam: BattleCamera = BattleCameraScript.new()
	cam.setup(stub)
	add_child(cam)
	auto_free(cam)
	# _ready ran → _apply_pan_clamp ran. Compute expected using the same source
	# (ProjectSettings reference resolution) that the production code now reads
	# from — deterministic regardless of test viewport quirks.
	var tile_size: float = 64.0
	var map_w: float = 10.0 * tile_size  # 640
	var map_h: float = 7.0 * tile_size   # 448
	var ref_w: float = float(ProjectSettings.get_setting("display/window/size/viewport_width", 1920))
	var ref_h: float = float(ProjectSettings.get_setting("display/window/size/viewport_height", 1080))
	var viewport_size: Vector2 = Vector2(ref_w, ref_h) / cam.zoom.x
	# When map_world_size <= viewport_size, position = map_world_size * 0.5.
	# When map > viewport, position is clamped to [half_view, map - half_view].
	var expected_x: float
	if map_w <= viewport_size.x:
		expected_x = map_w * 0.5
	else:
		var half: float = viewport_size.x * 0.5
		expected_x = clampf(cam.position.x, half, map_w - half)
	var expected_y: float
	if map_h <= viewport_size.y:
		expected_y = map_h * 0.5
	else:
		var half: float = viewport_size.y * 0.5
		expected_y = clampf(cam.position.y, half, map_h - half)
	# Assert
	assert_float(cam.position.x).override_failure_message(
		"Camera x=%.2f != expected %.2f (map_w=%.0f viewport_w=%.0f zoom=%.2f)"
		% [cam.position.x, expected_x, map_w, viewport_size.x, cam.zoom.x]
	).is_equal_approx(expected_x, 0.5)
	assert_float(cam.position.y).override_failure_message(
		"Camera y=%.2f != expected %.2f (map_h=%.0f viewport_h=%.0f zoom=%.2f)"
		% [cam.position.y, expected_y, map_h, viewport_size.y, cam.zoom.x]
	).is_equal_approx(expected_y, 0.5)
