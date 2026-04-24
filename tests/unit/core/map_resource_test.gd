extends GdUnitTestSuite

## map_resource_test.gd
## Unit tests for Story 001: MapResource + TileData Resource classes.
## Covers AC-1 through AC-4 (AC-5 is doc-level; verified at review time).
##
## Test evidence type: Logic (blocking gate — must pass before story is Done).

const TEMP_MAP_PATH: String = "user://map_resource_test_round_trip.tres"

## Expected @export field names for MapResource (AC-1).
const MAP_RESOURCE_EXPORT_FIELDS: Array[String] = [
	"terrain_version",
	"map_id",
	"map_rows",
	"map_cols",
	"tiles",
]

## Expected @export field names for TileData (AC-2).
const TILE_DATA_EXPORT_FIELDS: Array[String] = [
	"coord",
	"terrain_type",
	"elevation",
	"tile_state",
	"is_destructible",
	"destruction_hp",
	"occupant_id",
	"occupant_faction",
	"is_passable_base",
]


func after_test() -> void:
	# Safety net: remove temp file left by round-trip tests (G-6 pattern).
	if FileAccess.file_exists(TEMP_MAP_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_MAP_PATH))


## AC-1: MapResource declares all 5 @export fields and correct defaults.
func test_map_resource_class_declaration_fields_and_defaults() -> void:
	# Arrange / Act
	var m := MapResource.new()

	# Assert — class_name globally resolvable
	assert_bool(m != null).is_true()
	assert_str(m.get_script().resource_path).is_equal("res://src/core/map_resource.gd")

	# Assert — default values
	assert_int(m.terrain_version).is_equal(1)
	assert_bool(m.map_id == &"").is_true()
	assert_int(m.map_rows).is_equal(0)
	assert_int(m.map_cols).is_equal(0)
	assert_bool(m.tiles.is_empty()).is_true()

	# Assert — all expected @export fields present; exact count guards against
	# undeclared additions (same pattern as save_context_test.gd AC-3).
	var user_fields: Array[String] = _get_user_storage_fields(m)
	for expected: String in MAP_RESOURCE_EXPORT_FIELDS:
		assert_bool(expected in user_fields).override_failure_message(
			("MapResource @export field '%s' missing. " +
			"Found: %s") % [expected, str(user_fields)]
		).is_true()
	assert_int(user_fields.size()).override_failure_message(
		("MapResource expected %d user @export fields; got %d. " +
		"Full list: %s") % [MAP_RESOURCE_EXPORT_FIELDS.size(), user_fields.size(), str(user_fields)]
	).is_equal(MAP_RESOURCE_EXPORT_FIELDS.size())


## AC-2: MapTileData declares all 9 @export fields and correct defaults.
func test_tile_data_class_declaration_fields_and_defaults() -> void:
	# Arrange / Act
	var t := MapTileData.new()

	# Assert — class_name globally resolvable
	assert_bool(t != null).is_true()
	assert_str(t.get_script().resource_path).is_equal("res://src/core/map_tile_data.gd")

	# Assert — field values when set explicitly
	t.coord = Vector2i(5, 3)
	t.terrain_type = 2
	t.elevation = 1
	t.tile_state = 0
	t.is_destructible = true
	t.destruction_hp = 100
	t.occupant_id = 42
	t.occupant_faction = 1
	t.is_passable_base = true

	assert_bool(t.coord == Vector2i(5, 3)).is_true()
	assert_int(t.coord.x).is_equal(5)
	assert_int(t.coord.y).is_equal(3)
	assert_int(t.terrain_type).is_equal(2)
	assert_int(t.elevation).is_equal(1)
	assert_int(t.tile_state).is_equal(0)
	assert_bool(t.is_destructible).is_true()
	assert_int(t.destruction_hp).is_equal(100)
	assert_int(t.occupant_id).is_equal(42)
	assert_int(t.occupant_faction).is_equal(1)
	assert_bool(t.is_passable_base).is_true()

	# Assert — default construction yields correct zero-values (edge case from AC-2)
	var d := MapTileData.new()
	assert_int(d.occupant_id).is_equal(0)
	assert_int(d.occupant_faction).is_equal(0)
	assert_bool(d.is_passable_base).is_true()

	# Assert — all expected @export fields present; exact count guards against extras.
	var user_fields: Array[String] = _get_user_storage_fields(t)
	for expected: String in TILE_DATA_EXPORT_FIELDS:
		assert_bool(expected in user_fields).override_failure_message(
			("TileData @export field '%s' missing. " +
			"Found: %s") % [expected, str(user_fields)]
		).is_true()
	assert_int(user_fields.size()).override_failure_message(
		("TileData expected %d user @export fields; got %d. " +
		"Full list: %s") % [TILE_DATA_EXPORT_FIELDS.size(), user_fields.size(), str(user_fields)]
	).is_equal(TILE_DATA_EXPORT_FIELDS.size())


## AC-3: MapResource round-trips through ResourceSaver/ResourceLoader (9-tile fixture).
## Verifies the complete save/load cycle with a 3×3 map of distinct TileData entries.
func test_map_resource_round_trip_9_tile_fixture() -> void:
	# Arrange — build a 3×3 MapResource with distinct tile values
	var m := MapResource.new()
	m.map_id = &"test_map_3x3"
	m.map_rows = 3
	m.map_cols = 3
	m.terrain_version = 1

	for row: int in range(3):
		for col: int in range(3):
			var t := MapTileData.new()
			t.coord = Vector2i(col, row)
			t.terrain_type = row * 3 + col          # unique 0..8
			t.elevation = col + 1                    # unique per column
			t.tile_state = row                       # unique per row
			t.is_destructible = (col % 2 == 0)
			t.destruction_hp = (row + 1) * 10        # 10, 20, 30
			t.occupant_id = row * 3 + col + 1        # unique 1..9
			t.occupant_faction = col
			t.is_passable_base = (row != 2)
			m.tiles.append(t)

	# Act — save then reload with CACHE_MODE_IGNORE (ADR-0003 convention)
	var save_err: int = ResourceSaver.save(m, TEMP_MAP_PATH)
	assert_int(save_err).override_failure_message(
		"ResourceSaver.save failed with error: %d" % save_err
	).is_equal(OK)

	var loaded: MapResource = ResourceLoader.load(
		TEMP_MAP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as MapResource
	assert_bool(loaded != null).override_failure_message(
		"ResourceLoader.load returned null — file may not have been written"
	).is_true()

	# Assert — top-level fields preserved
	assert_bool(loaded.map_id == &"test_map_3x3").is_true()
	assert_int(loaded.map_rows).is_equal(3)
	assert_int(loaded.map_cols).is_equal(3)
	assert_int(loaded.terrain_version).is_equal(1)
	assert_int(loaded.tiles.size()).is_equal(9)

	# Assert — each tile's fields match field-by-field
	for i: int in range(9):
		var src: MapTileData = m.tiles[i]
		var dst: MapTileData = loaded.tiles[i]
		assert_bool(dst.coord == src.coord).override_failure_message(
			("tiles[%d].coord mismatch: expected %s got %s") % [i, str(src.coord), str(dst.coord)]
		).is_true()
		assert_int(dst.terrain_type).override_failure_message(
			"tiles[%d].terrain_type mismatch" % i
		).is_equal(src.terrain_type)
		assert_int(dst.elevation).override_failure_message(
			"tiles[%d].elevation mismatch" % i
		).is_equal(src.elevation)
		assert_int(dst.tile_state).override_failure_message(
			"tiles[%d].tile_state mismatch" % i
		).is_equal(src.tile_state)
		assert_bool(dst.is_destructible == src.is_destructible).override_failure_message(
			"tiles[%d].is_destructible mismatch" % i
		).is_true()
		assert_int(dst.destruction_hp).override_failure_message(
			"tiles[%d].destruction_hp mismatch" % i
		).is_equal(src.destruction_hp)
		assert_int(dst.occupant_id).override_failure_message(
			"tiles[%d].occupant_id mismatch" % i
		).is_equal(src.occupant_id)
		assert_int(dst.occupant_faction).override_failure_message(
			"tiles[%d].occupant_faction mismatch" % i
		).is_equal(src.occupant_faction)
		assert_bool(dst.is_passable_base == src.is_passable_base).override_failure_message(
			"tiles[%d].is_passable_base mismatch" % i
		).is_true()

	# Cleanup — explicit removal at end of test body (G-6: orphan detector fires
	# before after_test; DirAccess.remove_absolute is not a Node so no orphan risk)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_MAP_PATH))


## AC-4: Vector2i / int / bool field types preserved across round-trip (no Variant coercion).
## Uses a fresh load from AC-3's path pattern to verify typeof() results.
func test_map_resource_round_trip_preserves_field_types() -> void:
	# Arrange — minimal MapResource with one tile containing typed values
	var m := MapResource.new()
	m.map_id = &"type_check_map"
	m.map_rows = 1
	m.map_cols = 1
	m.terrain_version = 1

	var t := MapTileData.new()
	t.coord = Vector2i(7, 2)
	t.terrain_type = 3
	t.is_destructible = true
	m.tiles.append(t)

	# Act — save and reload
	var save_err: int = ResourceSaver.save(m, TEMP_MAP_PATH)
	assert_int(save_err).override_failure_message(
		"ResourceSaver.save failed: %d" % save_err
	).is_equal(OK)

	var loaded: MapResource = ResourceLoader.load(
		TEMP_MAP_PATH, "", ResourceLoader.CACHE_MODE_IGNORE
	) as MapResource
	assert_bool(loaded != null).is_true()
	assert_int(loaded.tiles.size()).is_equal(1)

	var lt: MapTileData = loaded.tiles[0]

	# Assert — typeof checks guard against silent Variant / float coercion
	assert_int(typeof(lt.coord)).override_failure_message(
		("coord should be TYPE_VECTOR2I (%d); got typeof=%d") % [TYPE_VECTOR2I, typeof(lt.coord)]
	).is_equal(TYPE_VECTOR2I)

	assert_int(typeof(lt.terrain_type)).override_failure_message(
		("terrain_type should be TYPE_INT (%d); got typeof=%d") % [TYPE_INT, typeof(lt.terrain_type)]
	).is_equal(TYPE_INT)

	assert_int(typeof(lt.is_destructible)).override_failure_message(
		("is_destructible should be TYPE_BOOL (%d); got typeof=%d") % [TYPE_BOOL, typeof(lt.is_destructible)]
	).is_equal(TYPE_BOOL)

	# Cleanup
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEMP_MAP_PATH))


## Helper: returns user-declared STORAGE field names on obj, excluding inherited
## Resource bookkeeping (resource_path, resource_name, resource_local_to_scene, etc.).
##
## Dynamic baseline subtraction via fresh Resource.new() — version-agnostic
## (mirrors G-1 signal-baseline pattern; same implementation as save_context_test.gd).
## Resource extends RefCounted — do NOT call .free() on the baseline (RefCounted crash).
func _get_user_storage_fields(obj: Object) -> Array[String]:
	var baseline: Resource = Resource.new()
	var inherited_names: Array[String] = []
	for prop: Dictionary in baseline.get_property_list():
		var usage: int = prop.get("usage", 0) as int
		if usage & PROPERTY_USAGE_STORAGE:
			inherited_names.append(prop.get("name", "") as String)

	var user_names: Array[String] = []
	for prop: Dictionary in obj.get_property_list():
		var usage: int = prop.get("usage", 0) as int
		if usage & PROPERTY_USAGE_STORAGE:
			var n: String = prop.get("name", "") as String
			if not (n in inherited_names):
				user_names.append(n)
	return user_names
