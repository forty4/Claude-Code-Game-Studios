extends GdUnitTestSuite

## save_context_test.gd
## Unit tests for Story 001: SaveContext + EchoMark Resource classes.
## Covers AC-1 through AC-7 (ADR-0003 §Key Interfaces + §Schema Stability).

const GAME_BUS_PATH: String = "res://src/core/game_bus.gd"

## Expected @export field names for SaveContext (AC-3).
const SAVE_CONTEXT_EXPORT_FIELDS: Array[String] = [
	"schema_version",
	"slot_id",
	"chapter_id",
	"chapter_number",
	"last_cp",
	"outcome",
	"branch_key",
	"echo_count",
	"echo_marks_archive",
	"flags_to_set",
	"saved_at_unix",
	"play_time_seconds",
]

## Expected @export field names for EchoMark (AC-5).
const ECHO_MARK_EXPORT_FIELDS: Array[String] = [
	"beat_index",
	"outcome",
	"tag",
]


## AC-1: SaveContext class_name resolves globally; script path is correct.
func test_save_context_class_registers_globally() -> void:
	# Arrange / Act
	var ctx := SaveContext.new()

	# Assert — class_name globally resolvable (no parse/import error)
	assert_bool(ctx != null).is_true()
	assert_str(ctx.get_script().resource_path).is_equal("res://src/core/payloads/save_context.gd")


## AC-2: SaveContext default values match ADR-0003 §Key Interfaces exactly.
func test_save_context_defaults_match_adr_spec() -> void:
	# Arrange
	var ctx := SaveContext.new()

	# Assert — integer defaults
	assert_int(ctx.schema_version).is_equal(1)
	assert_int(ctx.slot_id).is_equal(1)
	assert_int(ctx.chapter_number).is_equal(1)
	assert_int(ctx.last_cp).is_equal(1)
	assert_int(ctx.outcome).is_equal(0)
	assert_int(ctx.echo_count).is_equal(0)
	assert_int(ctx.saved_at_unix).is_equal(0)
	assert_int(ctx.play_time_seconds).is_equal(0)

	# Assert — StringName defaults
	assert_bool(ctx.chapter_id == &"").is_true()
	assert_bool(ctx.branch_key == &"").is_true()

	# Assert — collection defaults
	assert_bool(ctx.echo_marks_archive == []).is_true()
	assert_bool(ctx.flags_to_set == PackedStringArray()).is_true()


## AC-3: SaveContext has exactly 12 @export fields, verified via dynamic baseline
## subtraction (same pattern as G-1 signal baseline). Catches BOTH missing fields
## AND undeclared additions — if a developer adds a 13th @export without updating
## SAVE_CONTEXT_EXPORT_FIELDS, user_fields.size() == 13 and the test FAILS.
func test_save_context_has_12_export_fields() -> void:
	# Arrange / Act
	var ctx := SaveContext.new()
	var user_fields: Array[String] = _get_user_storage_fields(ctx)

	# Assert — every expected field is present
	for expected_name: String in SAVE_CONTEXT_EXPORT_FIELDS:
		assert_bool(expected_name in user_fields).override_failure_message(
			("SaveContext @export field '%s' missing from user STORAGE fields. " +
			"Found: %s") % [expected_name, str(user_fields)]
		).is_true()

	# Assert — user-declared field count is exactly 12 (catches undeclared extras).
	assert_int(user_fields.size()).override_failure_message(
		("SaveContext expected 12 user @export fields; got %d. " +
		"Full user fields: %s. If this is an intentional schema change, " +
		"update SAVE_CONTEXT_EXPORT_FIELDS + bump CURRENT_SCHEMA_VERSION " +
		"per ADR-0003 §Schema Stability.") % [user_fields.size(), str(user_fields)]
	).is_equal(12)


## AC-4: EchoMark class_name resolves globally; script path is correct.
func test_echo_mark_class_registers_globally() -> void:
	# Arrange / Act
	var mark := EchoMark.new()

	# Assert — class_name globally resolvable (no parse/import error)
	assert_bool(mark != null).is_true()
	assert_str(mark.get_script().resource_path).is_equal("res://src/core/payloads/echo_mark.gd")


## AC-5: EchoMark has exactly 3 @export fields, verified via dynamic baseline
## subtraction. Catches BOTH missing fields AND undeclared additions — primary
## schema-stability gate for EchoMark (ADR-0003 §Schema Stability BLOCKING).
func test_echo_mark_has_3_export_fields() -> void:
	# Arrange / Act
	var mark := EchoMark.new()
	var user_fields: Array[String] = _get_user_storage_fields(mark)

	# Assert — every expected field is present
	for expected_name: String in ECHO_MARK_EXPORT_FIELDS:
		assert_bool(expected_name in user_fields).override_failure_message(
			("EchoMark @export field '%s' missing from user STORAGE fields. " +
			"Found: %s") % [expected_name, str(user_fields)]
		).is_true()

	# Assert — user-declared field count is exactly 3 (catches undeclared extras).
	assert_int(user_fields.size()).override_failure_message(
		("EchoMark expected 3 user @export fields; got %d. " +
		"Full user fields: %s. If this is an intentional schema change, " +
		"update ECHO_MARK_EXPORT_FIELDS + author migration Callable per " +
		"ADR-0003 §Schema Stability §EchoMark Resource Contract.") % [user_fields.size(), str(user_fields)]
	).is_equal(3)


## AC-6: echo_marks_archive elements are EchoMark instances (typed array enforced).
##
## Note: story §AC-6 Edge Case "appending a non-EchoMark Resource should fail type check"
## is DEFERRED to story-004 serialization tests. Godot 4.6 Array[T] runtime
## rejection raises push_error + silently drops — reliable interception in
## GdUnit4 v6.1.2 is non-trivial (push_error is not a signal in this version).
## Story-004 round-trip tests cover the adjacent invariant: non-EchoMark elements
## cannot survive ResourceSaver round-trip (deserialization enforces type).
func test_save_context_echo_marks_archive_element_type_is_echo_mark() -> void:
	# Arrange
	var ctx := SaveContext.new()
	var mark := EchoMark.new()

	# Act
	ctx.echo_marks_archive.append(mark)

	# Assert — element is an EchoMark instance
	assert_int(ctx.echo_marks_archive.size()).is_equal(1)
	assert_bool(ctx.echo_marks_archive[0] is EchoMark).override_failure_message(
		"echo_marks_archive[0] expected to be EchoMark; got type: %s" %
		str(ctx.echo_marks_archive[0].get_class() if ctx.echo_marks_archive[0] != null else "<null>")
	).is_true()


## AC-7: GameBus.save_checkpoint_requested signal takes a SaveContext-typed argument.
## Verifies ADR-0003 GameBus Signal Amendment: payload shape is locked.
func test_gamebus_save_checkpoint_requested_uses_save_context_typed_payload() -> void:
	# Arrange — load game_bus.gd (no class_name; it is an autoload — G-3 applies)
	var game_bus_script: GDScript = load(GAME_BUS_PATH) as GDScript
	assert_bool(game_bus_script != null).is_true()
	var bus: Node = game_bus_script.new() as Node

	# Act — search signal list for save_checkpoint_requested
	var signal_list: Array = bus.get_signal_list()
	var target_sig: Dictionary = {}
	for sig: Dictionary in signal_list:
		if (sig.get("name", "") as String) == "save_checkpoint_requested":
			target_sig = sig
			break

	# Assert — signal exists
	assert_bool(target_sig.is_empty()).override_failure_message(
		"save_checkpoint_requested signal not found on GameBus"
	).is_false()

	# Assert — signal has exactly 1 argument
	var args: Array = target_sig.get("args", [])
	assert_int(args.size()).override_failure_message(
		("save_checkpoint_requested expected 1 arg; " +
		"got %d. Args: %s") % [args.size(), str(args)]
	).is_equal(1)

	# Assert — argument class_name is SaveContext
	var arg: Dictionary = args[0] as Dictionary
	var class_name_val: String = arg.get("class_name", "") as String
	assert_str(class_name_val).override_failure_message(
		("save_checkpoint_requested arg class_name expected 'SaveContext'; " +
		"got '%s'. Full arg dict: %s") % [class_name_val, str(arg)]
	).is_equal("SaveContext")

	# Cleanup — free the instantiated bus node (no tree; free() not queue_free() per G-6)
	bus.free()


## Helper: returns USER-DECLARED STORAGE field names on obj, excluding inherited
## Resource bookkeeping (resource_path, resource_name, resource_local_to_scene, etc.).
##
## Dynamic baseline subtraction via fresh Resource.new() — version-agnostic
## (mirrors G-1 signal-baseline pattern from test_helpers.gd). Resource extends
## RefCounted; baseline is auto-freed when local ref drops (NO explicit .free()
## call — calling .free() on RefCounted crashes).
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
