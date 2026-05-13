extends GdUnitTestSuite

## Reproduces the user-reported "after a unit acts in Round 1 it cannot be
## re-selected in Round 2" bug: _acted_this_turn / _moved_this_turn carry
## over from Round 1 into Round 2, blocking selection.

const _GridControllerScript: GDScript = preload("res://src/feature/grid_battle/grid_battle_controller.gd")


func test_round_started_clears_acted_and_moved_flags() -> void:
	var controller: Node = _GridControllerScript.new()
	# Don't add_child — _ready asserts DI deps non-null. We're testing the
	# round-reset bookkeeping in isolation, no DI needed for that branch.
	# Populate the typed-dict fields directly (Dictionary is a reference type).
	var acted: Dictionary = controller._acted_this_turn
	acted[0] = true
	acted[1] = true
	var moved: Dictionary = controller._moved_this_turn
	moved[0] = true

	# Sanity — pre-condition.
	assert_int((controller._acted_this_turn as Dictionary).size()).is_equal(2)
	assert_int((controller._moved_this_turn as Dictionary).size()).is_equal(1)

	# _on_round_started should clear both dictionaries before its other work.
	# Note: pass round_num=2 (not 6+ which would trigger turn-limit emit).
	controller._on_round_started(2)

	assert_int((controller._acted_this_turn as Dictionary).size()).override_failure_message(
		"_on_round_started must clear _acted_this_turn so units can re-select; size=%d"
		% (controller._acted_this_turn as Dictionary).size()
	).is_equal(0)
	assert_int((controller._moved_this_turn as Dictionary).size()).override_failure_message(
		"_on_round_started must clear _moved_this_turn so units can re-move; size=%d"
		% (controller._moved_this_turn as Dictionary).size()
	).is_equal(0)

	controller.free()
