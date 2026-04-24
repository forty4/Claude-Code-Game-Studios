extends GdUnitTestSuite

## map_grid_test.gd
## Unit tests for Story 002: MapGrid skeleton + load_map + 6 packed caches + trivial queries.
## Covers AC-1 through AC-7 (Logic story — blocking gate before story is Done).

const TEMP_MAP_PATH: String = "user://map_grid_test_v2_round_trip.tres"


func after_test() -> void:
	# Safety net: remove temp file left by round-trip tests (G-6 pattern).
	if FileAccess.file_exists(TEMP_MAP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_MAP_PATH))


## Factory helper: builds a MapResource of [rows] x [cols] with distinct per-tile
## values so cache-match assertions verify field-by-field, not just length.
func _make_map(rows: int, cols: int) -> MapResource:
	var m := MapResource.new()
	m.map_id = &"test_map"
	m.map_rows = rows
	m.map_cols = cols
	m.terrain_version = 1
	var n: int = rows * cols
	for i: int in n:
		var t := MapTileData.new()
		t.coord           = Vector2i(i % cols, i / cols)
		t.terrain_type    = i % 5           # 0..4, distinct by position
		t.elevation       = i % 3           # 0..2
		t.tile_state      = i % 4           # 0..3
		t.is_destructible = (i % 2 == 0)
		t.destruction_hp  = (i + 1) * 10
		t.occupant_id     = i + 1           # unique, non-zero
		t.occupant_faction = i % 3
		t.is_passable_base = (i % 3 != 0)  # mix of true/false
		m.tiles.append(t)
	return m


# ─── AC-1: class declaration + inert-until-loaded contract ────────────────────

## AC-1: Fresh MapGrid (no load_map) — get_tile returns null, get_map_dimensions
## returns Vector2i.ZERO, no crash.
func test_map_grid_before_load_map_queries_return_inert_values() -> void:
	# Arrange
	var grid := MapGrid.new()

	# Act + Assert — must not crash; returns defined inert values
	var tile: MapTileData = grid.get_tile(Vector2i.ZERO)
	assert_bool(tile == null).override_failure_message(
		"get_tile before load_map should return null; got non-null"
	).is_true()

	var dims: Vector2i = grid.get_map_dimensions()
	assert_bool(dims == Vector2i.ZERO).override_failure_message(
		"get_map_dimensions before load_map should return Vector2i.ZERO; got %s" % str(dims)
	).is_true()

	grid.free()


## AC-1 edge: double load_map call re-builds caches from the new resource,
## no stale carry-over.
func test_map_grid_double_load_map_rebuilds_caches_no_stale_carryover() -> void:
	# Arrange
	var grid := MapGrid.new()
	var res_a: MapResource = _make_map(3, 3)  # 9 tiles
	var res_b: MapResource = _make_map(2, 4)  # 8 tiles — different size AND values

	# Act — first load
	grid.load_map(res_a)
	assert_int(grid._terrain_type_cache.size()).is_equal(9)

	# Act — second load (re-entry)
	grid.load_map(res_b)

	# Assert — caches sized for the NEW resource (2x4 = 8), not the old one
	assert_int(grid._terrain_type_cache.size()).override_failure_message(
		"After second load_map, _terrain_type_cache size should be 8 (2x4)"
	).is_equal(8)
	assert_int(grid._passable_base_cache.size()).override_failure_message(
		"After second load_map, _passable_base_cache size should be 8"
	).is_equal(8)
	assert_int(grid._elevation_cache.size()).override_failure_message(
		"After second load_map, _elevation_cache size should be 8"
	).is_equal(8)

	# Assert — get_map_dimensions reflects the new resource (cols=4, rows=2)
	var dims: Vector2i = grid.get_map_dimensions()
	assert_bool(dims == Vector2i(4, 2)).override_failure_message(
		"After second load_map, dims should be Vector2i(4,2); got %s" % str(dims)
	).is_true()

	grid.free()


# ─── AC-2: duplicate_deep isolation ───────────────────────────────────────────

## AC-2: load_map clones via duplicate_deep — runtime mutation of the clone
## does NOT mutate the original resource.
func test_map_grid_load_map_clone_is_independent_of_original() -> void:
	# Arrange — original resource with known destruction_hp
	var res: MapResource = _make_map(2, 2)
	res.tiles[0].destruction_hp = 100

	# Act — load then mutate the internal clone
	var grid := MapGrid.new()
	grid.load_map(res)
	grid._map.tiles[0].destruction_hp = 999  # mutate clone directly

	# Assert — original unchanged
	assert_int(res.tiles[0].destruction_hp).override_failure_message(
		"Original resource tiles[0].destruction_hp should remain 100 after clone mutation"
	).is_equal(100)

	# Assert — clone reference is a distinct object instance from original
	assert_bool(grid._map != res).override_failure_message(
		"grid._map should be a different object instance than res after duplicate_deep"
	).is_true()

	grid.free()


# ─── AC-3: 6 packed caches built with correct length ─────────────────────────

## AC-3: 15x15 map (225 tiles) — all 6 caches sized exactly 225.
func test_map_grid_load_map_6_caches_sized_correctly_15x15() -> void:
	# Arrange
	var grid := MapGrid.new()
	var res: MapResource = _make_map(15, 15)

	# Act
	grid.load_map(res)

	# Assert — all 6 caches
	assert_int(grid._terrain_type_cache.size()).override_failure_message(
		"_terrain_type_cache size should be 225 for 15x15 map"
	).is_equal(225)
	assert_int(grid._elevation_cache.size()).override_failure_message(
		"_elevation_cache size should be 225"
	).is_equal(225)
	assert_int(grid._passable_base_cache.size()).override_failure_message(
		"_passable_base_cache (PackedByteArray) size should be 225"
	).is_equal(225)
	assert_int(grid._occupant_id_cache.size()).override_failure_message(
		"_occupant_id_cache size should be 225"
	).is_equal(225)
	assert_int(grid._occupant_faction_cache.size()).override_failure_message(
		"_occupant_faction_cache size should be 225"
	).is_equal(225)
	assert_int(grid._tile_state_cache.size()).override_failure_message(
		"_tile_state_cache size should be 225"
	).is_equal(225)

	grid.free()


## AC-3 edge: 40x30 map (1200 tiles) — max-scale cache sizing.
func test_map_grid_load_map_6_caches_sized_correctly_40x30() -> void:
	# Arrange
	var grid := MapGrid.new()
	var res: MapResource = _make_map(30, 40)

	# Act
	grid.load_map(res)

	# Assert — all 6 caches at max scale
	assert_int(grid._terrain_type_cache.size()).override_failure_message(
		"_terrain_type_cache size should be 1200 for 40x30 map"
	).is_equal(1200)
	assert_int(grid._elevation_cache.size()).is_equal(1200)
	assert_int(grid._passable_base_cache.size()).is_equal(1200)
	assert_int(grid._occupant_id_cache.size()).is_equal(1200)
	assert_int(grid._occupant_faction_cache.size()).is_equal(1200)
	assert_int(grid._tile_state_cache.size()).is_equal(1200)

	grid.free()


# ─── AC-4: cache values match TileData field-by-field ─────────────────────────

## AC-4: 3x3 map — every cache index matches its MapTileData field; bool->byte verified.
func test_map_grid_cache_values_match_tile_data_field_by_field() -> void:
	# Arrange — 3x3 with distinct per-tile values
	var grid := MapGrid.new()
	var res: MapResource = _make_map(3, 3)
	grid.load_map(res)

	# Act + Assert — field-by-field for each of the 9 tiles
	for i: int in 9:
		var t: MapTileData = grid._map.tiles[i]

		assert_int(grid._terrain_type_cache[i]).override_failure_message(
			"_terrain_type_cache[%d] should match tiles[%d].terrain_type" % [i, i]
		).is_equal(t.terrain_type)

		assert_int(grid._elevation_cache[i]).override_failure_message(
			"_elevation_cache[%d] should match tiles[%d].elevation" % [i, i]
		).is_equal(t.elevation)

		var expected_passable: int = 1 if t.is_passable_base else 0
		assert_int(grid._passable_base_cache[i] as int).override_failure_message(
			"_passable_base_cache[%d] should be %d (is_passable_base=%s)" \
			% [i, expected_passable, str(t.is_passable_base)]
		).is_equal(expected_passable)

		assert_int(grid._occupant_id_cache[i]).override_failure_message(
			"_occupant_id_cache[%d] should match tiles[%d].occupant_id" % [i, i]
		).is_equal(t.occupant_id)

		assert_int(grid._occupant_faction_cache[i]).override_failure_message(
			"_occupant_faction_cache[%d] should match tiles[%d].occupant_faction" % [i, i]
		).is_equal(t.occupant_faction)

		assert_int(grid._tile_state_cache[i]).override_failure_message(
			"_tile_state_cache[%d] should match tiles[%d].tile_state" % [i, i]
		).is_equal(t.tile_state)

	grid.free()


## AC-4 edge: explicit bool->byte coercion — is_passable_base=true->1, false->0.
func test_map_grid_passable_base_cache_bool_to_byte_coercion() -> void:
	# Arrange — two tiles with explicit passable values
	var res := MapResource.new()
	res.map_id = &"bool_coercion_test"
	res.map_rows = 1
	res.map_cols = 2
	res.terrain_version = 1

	var t0 := MapTileData.new()
	t0.is_passable_base = true
	var t1 := MapTileData.new()
	t1.is_passable_base = false
	res.tiles.append(t0)
	res.tiles.append(t1)

	var grid := MapGrid.new()
	grid.load_map(res)

	# Assert — true -> 1, false -> 0
	assert_int(grid._passable_base_cache[0] as int).override_failure_message(
		"is_passable_base=true should store as byte 1"
	).is_equal(1)
	assert_int(grid._passable_base_cache[1] as int).override_failure_message(
		"is_passable_base=false should store as byte 0"
	).is_equal(0)

	grid.free()


# ─── AC-5: get_tile bounds + return value ─────────────────────────────────────

## AC-5: 15x15 map — in-bounds, out-of-bounds, mid-grid, and row-bound cases.
func test_map_grid_get_tile_bounds_and_flat_array_formula() -> void:
	# Arrange
	var grid := MapGrid.new()
	var res: MapResource = _make_map(15, 15)
	grid.load_map(res)

	# (14, 14) — last valid corner, flat index = 14*15+14 = 224
	var tile_corner: MapTileData = grid.get_tile(Vector2i(14, 14))
	assert_bool(tile_corner != null).override_failure_message(
		"get_tile(14,14) should return non-null for 15x15 map"
	).is_true()
	var expected_corner: MapTileData = grid._map.tiles[14 * 15 + 14]
	assert_bool(tile_corner == expected_corner).override_failure_message(
		"get_tile(14,14) should equal tiles[224] (flat-array formula check)"
	).is_true()

	# (15, 0) — col out-of-bounds (>= map_cols)
	var tile_oob_col: MapTileData = grid.get_tile(Vector2i(15, 0))
	assert_bool(tile_oob_col == null).override_failure_message(
		"get_tile(15,0) should return null (col >= map_cols=15)"
	).is_true()

	# (-1, 0) — negative col
	var tile_neg: MapTileData = grid.get_tile(Vector2i(-1, 0))
	assert_bool(tile_neg == null).override_failure_message(
		"get_tile(-1,0) should return null (negative col)"
	).is_true()

	# (0, 15) — row out-of-bounds (>= map_rows)
	var tile_oob_row: MapTileData = grid.get_tile(Vector2i(0, 15))
	assert_bool(tile_oob_row == null).override_failure_message(
		"get_tile(0,15) should return null (row >= map_rows=15)"
	).is_true()

	# (3, 5) — mid-grid, flat index = 5*15+3 = 78
	var tile_mid: MapTileData = grid.get_tile(Vector2i(3, 5))
	assert_bool(tile_mid != null).override_failure_message(
		"get_tile(3,5) should return non-null"
	).is_true()
	var expected_mid: MapTileData = grid._map.tiles[5 * 15 + 3]
	assert_bool(tile_mid == expected_mid).override_failure_message(
		"get_tile(3,5) should equal tiles[78] (flat-array formula: 5*15+3)"
	).is_true()

	grid.free()


# ─── AC-6: get_map_dimensions returns (cols, rows) ────────────────────────────

## AC-6: 40x30 map — get_map_dimensions returns Vector2i(40, 30).
func test_map_grid_get_map_dimensions_returns_cols_rows_order() -> void:
	# Arrange
	var grid := MapGrid.new()
	var res: MapResource = _make_map(30, 40)  # rows=30, cols=40
	grid.load_map(res)

	# Act
	var dims: Vector2i = grid.get_map_dimensions()

	# Assert — .x = cols, .y = rows per GDD Interactions table
	assert_bool(dims == Vector2i(40, 30)).override_failure_message(
		"get_map_dimensions for 40x30 map should be Vector2i(40,30); got %s" % str(dims)
	).is_true()
	assert_int(dims.x).override_failure_message("dims.x should be cols (40)").is_equal(40)
	assert_int(dims.y).override_failure_message("dims.y should be rows (30)").is_equal(30)

	grid.free()


## AC-6 edge: 15x15 square map returns Vector2i(15, 15).
func test_map_grid_get_map_dimensions_square_map() -> void:
	var grid := MapGrid.new()
	var res: MapResource = _make_map(15, 15)
	grid.load_map(res)

	var dims: Vector2i = grid.get_map_dimensions()
	assert_bool(dims == Vector2i(15, 15)).override_failure_message(
		"get_map_dimensions for 15x15 map should be Vector2i(15,15); got %s" % str(dims)
	).is_true()

	grid.free()


# ─── AC-7: V-2 disk asset unchanged after duplicate_deep mutation (round-trip) ─

## AC-7: Save MapResource to disk -> load into MapGrid -> mutate clone ->
## reload from disk with CACHE_MODE_IGNORE -> disk asset unchanged.
func test_map_grid_duplicate_deep_disk_asset_unchanged_after_clone_mutation() -> void:
	# Arrange — build and save a MapResource with known destruction_hp values
	var original: MapResource = _make_map(2, 3)
	original.tiles[0].destruction_hp = 100
	original.tiles[1].destruction_hp = 200
	original.tiles[2].destruction_hp = 300

	var save_err: int = ResourceSaver.save(original, TEMP_MAP_PATH)
	assert_int(save_err).override_failure_message(
		"ResourceSaver.save failed with error: %d" % save_err
	).is_equal(OK)

	# Act — load from disk, feed to MapGrid
	var disk_res: MapResource = ResourceLoader.load(
		TEMP_MAP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as MapResource
	assert_bool(disk_res != null).override_failure_message(
		"ResourceLoader.load returned null after save"
	).is_true()

	var grid := MapGrid.new()
	grid.load_map(disk_res)

	# Mutate the clone with sentinel values
	grid._map.tiles[0].destruction_hp = 9999
	grid._map.tiles[1].destruction_hp = 8888
	grid._map.tiles[2].destruction_hp = 7777

	# Act — reload from disk with CACHE_MODE_IGNORE (critical: bypasses stale cache)
	var reloaded: MapResource = ResourceLoader.load(
		TEMP_MAP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as MapResource
	assert_bool(reloaded != null).override_failure_message(
		"Second ResourceLoader.load returned null"
	).is_true()

	# Assert — disk asset was NOT mutated by the clone modification
	assert_int(reloaded.tiles[0].destruction_hp).override_failure_message(
		"tiles[0].destruction_hp on disk should be 100; sentinel 9999 must not have leaked"
	).is_equal(100)
	assert_int(reloaded.tiles[1].destruction_hp).override_failure_message(
		"tiles[1].destruction_hp on disk should be 200; not sentinel 8888"
	).is_equal(200)
	assert_int(reloaded.tiles[2].destruction_hp).override_failure_message(
		"tiles[2].destruction_hp on disk should be 300; not sentinel 7777"
	).is_equal(300)

	# Cleanup — explicit removal at end of test body (G-6 pattern; before after_test)
	grid.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_MAP_PATH))
