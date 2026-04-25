## test_helpers.gd — shared static helpers for tests/unit/core/*.
##
## Extracted to avoid duplication across signal_contract_test.gd,
## game_bus_diagnostics_test.gd, and game_bus_stub_self_test.gd. When
## Godot adds new inherited Node signals in a future version, only
## get_user_signals needs updating — and this file is the only place.
##
## Usage:
##   for sig: Dictionary in TestHelpers.get_user_signals(node):
##       ...
##
## NOTE: game_bus_declaration_test.gd uses a different helper shape
## (_get_node_inherited_signal_names, returning inherited names rather
## than user signals) and is intentionally NOT updated to use this module.
class_name TestHelpers
extends RefCounted


## Returns only user-declared signals on a Node, filtering inherited Node signals.
## Uses a dynamic baseline (bare Node.new()) so Godot version upgrades that add
## new built-in Node signals never require a manual update here.
## Matches the pattern from game_bus_declaration_test.gd for consistency.
static func get_user_signals(node: Node) -> Array[Dictionary]:
	var baseline: Node = Node.new()
	var inherited: Array[String] = []
	for sig: Dictionary in baseline.get_signal_list():
		inherited.append(sig["name"] as String)
	baseline.free()
	var result: Array[Dictionary] = []
	for sig: Dictionary in node.get_signal_list():
		if not (sig["name"] as String) in inherited:
			result.append(sig)
	return result


## Assert that all 6 packed caches in [param grid] match the corresponding
## [code]_map.tiles[idx][/code] field values for every coord in [param coords].
##
## Originally local to [code]map_grid_mutation_test.gd[/code] (story-004 V-5 cache-sync
## parametric). Promoted to shared test-helper per TD-032 A-14 because story-005
## (Dijkstra) and story-006 (LoS) read the same 6 packed caches and benefit from
## a consistent cache-integrity assertion. Call sites become:
##   TestHelpers.assert_all_caches_match_tiledata(self, grid, check_coords, step_count)
##
## [param test_suite] must be the calling [GdUnitTestSuite] instance — pass [code]self[/code]
## from the test method. GdUnit4 v6.1.2 binds [code]assert_int[/code] as an instance method,
## so the helper must invoke it on a test-suite reference.
##
## [param step] is included in failure messages (e.g., "Step 5: _tile_state_cache[78] mismatch")
## to identify which mutation in a sequence introduced the desync.
static func assert_all_caches_match_tiledata(
		test_suite: GdUnitTestSuite,
		grid: MapGrid,
		coords: Array[Vector2i],
		step: int) -> void:

	for coord: Vector2i in coords:
		var idx: int = coord.y * grid._map.map_cols + coord.x
		var td: MapTileData = grid._map.tiles[idx]

		test_suite.assert_int(grid._terrain_type_cache[idx]).override_failure_message(
			("Step %d: _terrain_type_cache[%d] (%s) mismatch. cache=%d td=%d") \
			% [step, idx, str(coord), grid._terrain_type_cache[idx], td.terrain_type]
		).is_equal(td.terrain_type)

		test_suite.assert_int(grid._elevation_cache[idx]).override_failure_message(
			("Step %d: _elevation_cache[%d] (%s) mismatch. cache=%d td=%d") \
			% [step, idx, str(coord), grid._elevation_cache[idx], td.elevation]
		).is_equal(td.elevation)

		var expected_passable: int = 1 if td.is_passable_base else 0
		test_suite.assert_int(grid._passable_base_cache[idx]).override_failure_message(
			("Step %d: _passable_base_cache[%d] (%s) mismatch. cache=%d td=%s") \
			% [step, idx, str(coord), grid._passable_base_cache[idx], str(td.is_passable_base)]
		).is_equal(expected_passable)

		test_suite.assert_int(grid._occupant_id_cache[idx]).override_failure_message(
			("Step %d: _occupant_id_cache[%d] (%s) mismatch. cache=%d td=%d") \
			% [step, idx, str(coord), grid._occupant_id_cache[idx], td.occupant_id]
		).is_equal(td.occupant_id)

		test_suite.assert_int(grid._occupant_faction_cache[idx]).override_failure_message(
			("Step %d: _occupant_faction_cache[%d] (%s) mismatch. cache=%d td=%d") \
			% [step, idx, str(coord), grid._occupant_faction_cache[idx], td.occupant_faction]
		).is_equal(td.occupant_faction)

		test_suite.assert_int(grid._tile_state_cache[idx]).override_failure_message(
			("Step %d: _tile_state_cache[%d] (%s) mismatch. cache=%d td=%d") \
			% [step, idx, str(coord), grid._tile_state_cache[idx], td.tile_state]
		).is_equal(td.tile_state)
