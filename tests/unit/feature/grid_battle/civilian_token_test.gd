## civilian_token_test.gd
##
## Unit tests for CivilianToken state machine (ADR-0022).
## Asserts the 4 transitions specified at ADR-0022 §Decision §1:
##   IDLE → ESCORTED (bind_to_carrier)
##   ESCORTED → SAVED (commit_save)
##   ESCORTED → IDLE (recover_to_idle)
##   IDLE state on construction (factory)
##
## All tests are pure (no SceneTree, no autoload) — RefCounted only.
extends GdUnitTestSuite


func test_civilian_token_factory_initializes_idle_with_cell() -> void:
	# Arrange + Act
	var token: CivilianToken = CivilianToken.make(7, Vector2i(3, 2))

	# Assert
	assert_int(token.token_id).is_equal(7)
	assert_int(token.state as int).is_equal(CivilianToken.State.IDLE as int)
	assert_vector(token.grid_cell).is_equal(Vector2i(3, 2))
	assert_int(token.carrier_unit_id).is_equal(-1)


func test_civilian_token_bind_to_carrier_transitions_idle_to_escorted() -> void:
	# Arrange
	var token: CivilianToken = CivilianToken.make(0, Vector2i(5, 3))

	# Act
	token.bind_to_carrier(0)

	# Assert
	assert_int(token.state as int).is_equal(CivilianToken.State.ESCORTED as int)
	assert_int(token.carrier_unit_id).is_equal(0)
	# grid_cell unchanged — carrier owns position semantically
	assert_vector(token.grid_cell).is_equal(Vector2i(5, 3))


func test_civilian_token_commit_save_transitions_escorted_to_saved() -> void:
	# Arrange
	var token: CivilianToken = CivilianToken.make(1, Vector2i(4, 5))
	token.bind_to_carrier(13)

	# Act
	token.commit_save()

	# Assert
	assert_int(token.state as int).is_equal(CivilianToken.State.SAVED as int)
	assert_int(token.carrier_unit_id).is_equal(-1)


func test_civilian_token_recover_to_idle_transitions_escorted_to_idle_at_recovery_cell() -> void:
	# Arrange
	var token: CivilianToken = CivilianToken.make(2, Vector2i(6, 6))
	token.bind_to_carrier(1)

	# Act — carrier died at (8, 4); recovery cell = death cell
	token.recover_to_idle(Vector2i(8, 4))

	# Assert
	assert_int(token.state as int).is_equal(CivilianToken.State.IDLE as int)
	assert_int(token.carrier_unit_id).is_equal(-1)
	assert_vector(token.grid_cell).is_equal(Vector2i(8, 4))
