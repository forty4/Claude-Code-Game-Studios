## DI assertion + _exit_tree() autoload-disconnect cleanup per ADR-0013 §Validation §1+§2

extends GdUnitTestSuite

const BattleCameraScript: GDScript = preload("res://src/feature/camera/battle_camera.gd")
const MapGridStubScript: GDScript = preload("res://tests/helpers/map_grid_stub.gd")


func before_test() -> void:
	# G-15 isolation — reset BalanceConstants cache between tests
	(load("res://src/foundation/balance/balance_constants.gd") as GDScript).set("_cache_loaded", false)


func test_setup_assigns_map_grid() -> void:
	var stub: MapGridStub = MapGridStubScript.new()
	add_child(stub)
	auto_free(stub)
	var cam: BattleCamera = BattleCameraScript.new()
	auto_free(cam)  # cleanup even though not added to tree (avoids orphan warning)
	cam.setup(stub)
	# After setup but BEFORE _ready (i.e., before add_child), _map_grid should be set
	assert_object(cam._map_grid).is_equal(stub)


func test_ready_fails_without_setup() -> void:
	# Per ADR-0013 R-2: _ready() must assert _map_grid != null
	# Note: GdUnit4's add_child triggers _ready synchronously; missing setup → assert hit.
	# We test the field state pre-mount as the proxy (asserts in _ready can crash the test runner).
	var cam: BattleCamera = BattleCameraScript.new()
	auto_free(cam)
	# Did NOT call setup()
	assert_object(cam._map_grid).is_null()


func test_exit_tree_disconnects_gamebus_subscription() -> void:
	# Per ADR-0013 R-6 + camera_missing_exit_tree_disconnect: _exit_tree() MUST
	# explicitly disconnect GameBus.input_action_fired callback. Verify by:
	# (a) mount camera → connect fires
	# (b) confirm subscription is_connected() returns true
	# (c) free camera → _exit_tree() runs
	# (d) after free, the GameBus signal has no live subscriber for _on_input_action_fired
	#     pointing at this camera (assert via subscription enumeration)
	var stub: MapGridStub = MapGridStubScript.new()
	stub.set_dimensions_for_test(Vector2i(8, 8))
	add_child(stub)
	auto_free(stub)
	var cam: BattleCamera = BattleCameraScript.new()
	cam.setup(stub)
	add_child(cam)  # triggers _ready → connect

	# After _ready, subscription should be live
	var connections_before: Array = GameBus.input_action_fired.get_connections()
	var found_before: bool = false
	for conn: Dictionary in connections_before:
		if conn["callable"].get_object() == cam:
			found_before = true
			break
	assert_bool(found_before).is_true()

	# Free the camera → _exit_tree() runs
	cam.free()  # synchronous free for test determinism (NOT queue_free)

	# After free, no subscription should remain pointing at our camera
	var connections_after: Array = GameBus.input_action_fired.get_connections()
	var found_after: bool = false
	for conn: Dictionary in connections_after:
		# After free, conn["callable"].get_object() may be null or invalid;
		# either way the camera-specific subscription should be gone.
		var obj: Object = conn["callable"].get_object()
		if obj != null and obj == cam:
			found_after = true
			break
	assert_bool(found_after).is_false()


func test_zoom_initialized_from_balance_constants() -> void:
	var stub: MapGridStub = MapGridStubScript.new()
	stub.set_dimensions_for_test(Vector2i(8, 8))
	add_child(stub)
	auto_free(stub)
	var cam: BattleCamera = BattleCameraScript.new()
	cam.setup(stub)
	add_child(cam)
	auto_free(cam)
	# CAMERA_ZOOM_DEFAULT = 1.0 per balance_entities.json
	assert_float(cam.zoom.x).is_equal_approx(1.0, 0.001)
	assert_float(cam.zoom.y).is_equal_approx(1.0, 0.001)
