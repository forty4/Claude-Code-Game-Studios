extends GdUnitTestSuite

# Sentinel test — confirms the GdUnit4 framework is installed and executing.
# Delete this file after adding the first real system-under-test unit suite
# (e.g. tests/unit/map_grid_pathfinding_test.gd) or keep as a CI smoke check.


func test_framework_arithmetic_works() -> void:
	assert_int(2 + 2).is_equal(4)


func test_framework_string_assertion_works() -> void:
	assert_str("천명역전").is_not_empty()


func test_framework_array_assertion_works() -> void:
	var actions := ["move", "attack", "wait", "end_turn"]
	assert_array(actions).has_size(4)
	assert_array(actions).contains(["attack"])
