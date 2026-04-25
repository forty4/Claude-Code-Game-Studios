extends GdUnitTestSuite

## map_grid_inspector_fixtures_test.gd — Story 008 fixture-validity smoke.
##
## Confirms that the two committed inspector authoring fixtures load via
## ResourceLoader AND pass the story-003 validator. This is the programmatic
## counterpart to story-008's manual inspector verification.
##
## ACs covered (programmatic portion only — manual AC-2/3/4/6 require Godot
## editor GUI and are tracked in production/qa/evidence/map-grid-inspector-v7.md):
##   - AC-SAMPLE-15x15: sample_small.tres loads + validates + has expected dims
##   - AC-STRESS-40x30 (runtime portion only): stress_40x30.tres loads + validates
##     + 1200 tiles. Inspector load time is the manual portion.
##   - AC-R3-INLINE-ASSERT: TileData entries are inline (verified via plain-text
##     grep; structural property of generated .tres). This test re-verifies via
##     successful load (external TileData refs would fail load on missing files).
##
## Story reference: production/epics/map-grid/story-008-inspector-fixture-manual-qa.md
## Manual evidence:  production/qa/evidence/map-grid-inspector-v7.md

const SAMPLE_SMALL_PATH: String = "res://data/maps/sample_small.tres"
const STRESS_40X30_PATH: String = "res://data/maps/stress_40x30.tres"


## AC-SAMPLE-15x15: sample_small.tres loads + validator accepts it.
func test_inspector_fixture_sample_small_loads_and_validates() -> void:
	# Arrange + Act
	assert_bool(ResourceLoader.exists(SAMPLE_SMALL_PATH)).override_failure_message(
		("AC-SAMPLE-15x15: %s missing. Run: " \
		+ "godot --headless --path . -s res://tests/fixtures/generate_sample_small.gd") \
		% SAMPLE_SMALL_PATH
	).is_true()

	var res: MapResource = load(SAMPLE_SMALL_PATH) as MapResource
	assert_that(res).override_failure_message(
		"AC-SAMPLE-15x15: %s did not load as MapResource" % SAMPLE_SMALL_PATH
	).is_not_null()

	var grid: MapGrid = MapGrid.new()
	var ok: bool = grid.load_map(res)

	# Assert: validator accepted.
	assert_bool(ok).override_failure_message(
		"AC-SAMPLE-15x15: validator REJECTED %s. Errors: %s" \
		% [SAMPLE_SMALL_PATH, str(grid.get_last_load_errors())]
	).is_true()

	# Assert: dimensions match story spec.
	var dims: Vector2i = grid.get_map_dimensions()
	assert_int(dims.x).override_failure_message(
		"AC-SAMPLE-15x15: map_cols expected 15, got %d" % dims.x
	).is_equal(15)
	assert_int(dims.y).override_failure_message(
		"AC-SAMPLE-15x15: map_rows expected 15, got %d" % dims.y
	).is_equal(15)

	# Assert: at least one destructible FORTRESS_WALL present (story-008 spec).
	# FORTRESS_WALL terrain_type = 6.
	var has_destructible_wall: bool = false
	for r: int in 15:
		for c: int in 15:
			var tile: MapTileData = grid.get_tile(Vector2i(c, r))
			if tile.terrain_type == 6 and tile.is_destructible:
				has_destructible_wall = true
				break
		if has_destructible_wall:
			break
	assert_bool(has_destructible_wall).override_failure_message(
		"AC-SAMPLE-15x15: at least one destructible FORTRESS_WALL required; none found"
	).is_true()

	grid.free()


## AC-STRESS-40x30 runtime portion: stress_40x30.tres loads + validator accepts.
## The inspector load-time portion is manual (production/qa/evidence/map-grid-inspector-v7.md).
func test_inspector_fixture_stress_40x30_loads_and_validates() -> void:
	# Arrange + Act
	assert_bool(ResourceLoader.exists(STRESS_40X30_PATH)).override_failure_message(
		"AC-STRESS-40x30: %s missing. Copy from tests/fixtures/maps/stress_40x30.tres" \
		% STRESS_40X30_PATH
	).is_true()

	var res: MapResource = load(STRESS_40X30_PATH) as MapResource
	assert_that(res).override_failure_message(
		"AC-STRESS-40x30: %s did not load as MapResource" % STRESS_40X30_PATH
	).is_not_null()

	var grid: MapGrid = MapGrid.new()
	var ok: bool = grid.load_map(res)
	assert_bool(ok).override_failure_message(
		"AC-STRESS-40x30: validator REJECTED %s. Errors: %s" \
		% [STRESS_40X30_PATH, str(grid.get_last_load_errors())]
	).is_true()

	# Assert: 40×30 dimensions.
	var dims: Vector2i = grid.get_map_dimensions()
	assert_int(dims.x).override_failure_message(
		"AC-STRESS-40x30: map_cols expected 40, got %d" % dims.x
	).is_equal(40)
	assert_int(dims.y).override_failure_message(
		"AC-STRESS-40x30: map_rows expected 30, got %d" % dims.y
	).is_equal(30)

	grid.free()
