extends GdUnitTestSuite

## terrain_resource_classes_test.gd
## Unit tests for Story 001 (terrain-effect epic): TerrainModifiers and
## CombatModifiers Resource schema — default construction + ResourceSaver/Loader
## round-trips including Array[StringName] element-type preservation.
##
## Governing ADR: ADR-0008 §Decision 6 + §Key Interfaces.
## Related TRs:   TR-terrain-effect-001 (CR-1 8-terrain modifier table),
##                TR-terrain-effect-009 (CR-5 bridge_no_flank flag).
##
## AC-5 design choice: implemented as a dedicated test function
## (test_terrain_resource_classes_type_preservation_after_roundtrip) rather than
## inlined into AC-3/AC-4 bodies. This separates "field values match" from
## "field types are correct" so that failures attribute to the right concern
## without ambiguity.
##
## Cleanup discipline: every tmp file path is registered in _tmp_paths and
## deleted unconditionally in after_test — mirrors payload_serialization_test.gd
## (AC-7 pattern). No shared fixtures with that test suite.
##
## Determinism: all field values are compile-time constants — no randi(), no
## time-dependent field values. Time.get_ticks_usec() is used for tmp-path
## uniqueness only (same pattern as payload_serialization_test.gd).


# ── Tmp-path management ───────────────────────────────────────────────────────

## Tracks every tmp file path created in the current test function.
## Reset to empty in before_test; iterated and deleted in after_test.
var _tmp_paths: Array[String] = []

## Per-test monotonic counter — combined with Time.get_ticks_usec() to guarantee
## no path collisions even if two allocations occur within the same microsecond.
var _path_counter: int = 0


func before_test() -> void:
	_tmp_paths = []
	_path_counter = 0
	DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path("user://tmp/")
	)


func after_test() -> void:
	for path: String in _tmp_paths:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_tmp_paths = []


## Allocates a unique tmp path and registers it for cleanup in after_test.
func _make_tmp_path(prefix: String) -> String:
	_path_counter += 1
	var path: String = "user://tmp/terrain_res_%s_%d_%d.tres" % [
		prefix, Time.get_ticks_usec(), _path_counter
	]
	_tmp_paths.append(path)
	return path


# ── Save/load helper ──────────────────────────────────────────────────────────


## Saves a Resource to tmp_path, asserts the save succeeded, and returns the
## loaded Resource (with CACHE_MODE_IGNORE per ADR-0003/0004 convention).
## Returns null and leaves the calling test to abort via the failed assertion.
func _save_and_load(resource: Resource, tmp_path: String) -> Resource:
	var err: int = ResourceSaver.save(resource, tmp_path)
	assert_int(err).override_failure_message(
		(("ResourceSaver.save() failed for path '%s' with error code %d"
		+ " — check that user://tmp/ is writable and all fields use @export.")
		% [tmp_path, err])
	).is_equal(OK)
	if err != OK:
		return null
	var loaded: Resource = ResourceLoader.load(
		tmp_path, "", ResourceLoader.CACHE_MODE_IGNORE
	)
	assert_bool(loaded != null).override_failure_message(
		(("ResourceLoader.load() returned null for '%s'"
		+ " — file may be corrupted or class_name not registered.") % tmp_path)
	).is_true()
	return loaded


# ── Tests ─────────────────────────────────────────────────────────────────────


## AC-1: TerrainModifiers default construction yields all-zero / empty defaults.
## Also verifies Array[StringName] element typing via append + typeof check.
func test_terrain_modifiers_default_construction_yields_correct_defaults() -> void:
	# Arrange / Act
	var m := TerrainModifiers.new()

	# Assert — numeric defaults
	assert_int(m.defense_bonus).override_failure_message(
		"TerrainModifiers.defense_bonus default should be 0, got %d" % m.defense_bonus
	).is_equal(0)

	assert_int(m.evasion_bonus).override_failure_message(
		"TerrainModifiers.evasion_bonus default should be 0, got %d" % m.evasion_bonus
	).is_equal(0)

	# Assert — special_rules empty
	assert_int(m.special_rules.size()).override_failure_message(
		"TerrainModifiers.special_rules.size() should be 0 on default construction, got %d" % m.special_rules.size()
	).is_equal(0)

	# Assert — Array[StringName] element typing: append a StringName and verify
	# the stored element is a StringName (not silently coerced to String).
	m.special_rules.append(&"test")
	assert_int(m.special_rules.size()).override_failure_message(
		"TerrainModifiers.special_rules.size() should be 1 after append, got %d" % m.special_rules.size()
	).is_equal(1)
	assert_int(typeof(m.special_rules[0])).override_failure_message(
		(("TerrainModifiers.special_rules[0] typeof should be TYPE_STRING_NAME (%d), got %d"
		+ " — array element type demotion detected.") % [TYPE_STRING_NAME, typeof(m.special_rules[0])])
	).is_equal(TYPE_STRING_NAME)


## AC-2: CombatModifiers default construction yields all-zero / false / empty defaults.
func test_combat_modifiers_default_construction_yields_correct_defaults() -> void:
	# Arrange / Act
	var c := CombatModifiers.new()

	# Assert — int fields
	assert_int(c.defender_terrain_def).override_failure_message(
		"CombatModifiers.defender_terrain_def default should be 0, got %d" % c.defender_terrain_def
	).is_equal(0)

	assert_int(c.defender_terrain_eva).override_failure_message(
		"CombatModifiers.defender_terrain_eva default should be 0, got %d" % c.defender_terrain_eva
	).is_equal(0)

	assert_int(c.elevation_atk_mod).override_failure_message(
		"CombatModifiers.elevation_atk_mod default should be 0, got %d" % c.elevation_atk_mod
	).is_equal(0)

	assert_int(c.elevation_def_mod).override_failure_message(
		"CombatModifiers.elevation_def_mod default should be 0, got %d" % c.elevation_def_mod
	).is_equal(0)

	# Assert — bool field
	assert_bool(c.bridge_no_flank).override_failure_message(
		"CombatModifiers.bridge_no_flank default should be false"
	).is_false()

	# Assert — special_rules empty
	assert_int(c.special_rules.size()).override_failure_message(
		"CombatModifiers.special_rules.size() should be 0 on default construction, got %d" % c.special_rules.size()
	).is_equal(0)


## AC-3: TerrainModifiers ResourceSaver round-trip — all fields including
## Array[StringName] content and element count.
func test_terrain_modifiers_roundtrip_preserves_all_fields() -> void:
	# Arrange
	var original := TerrainModifiers.new()
	original.defense_bonus = 25
	original.evasion_bonus = 5
	original.special_rules = [&"bridge_no_flank", &"siege_terrain"]
	var tmp_path: String = _make_tmp_path("terrain_modifiers")

	# Act
	var loaded: Resource = _save_and_load(original, tmp_path)
	if loaded == null:
		return

	# Assert — class identity
	assert_bool(loaded is TerrainModifiers).override_failure_message(
		"Loaded resource is not TerrainModifiers — class_name may be unregistered."
	).is_true()
	var lo: TerrainModifiers = loaded as TerrainModifiers

	# Assert — instance identity: loaded must be a fresh instance, not a cached
	# reuse of `original`. Guards against accidental CACHE_MODE_REUSE flip in
	# _save_and_load that would make every value/type assertion trivially pass.
	assert_bool(loaded != original).override_failure_message(
		"Loaded TerrainModifiers is the same instance as original — "
		+ "CACHE_MODE_IGNORE may have regressed to CACHE_MODE_REUSE."
	).is_true()

	# Assert — int fields
	assert_int(lo.defense_bonus).override_failure_message(
		"TerrainModifiers.defense_bonus diverged: expected 25, got %d" % lo.defense_bonus
	).is_equal(25)

	assert_int(lo.evasion_bonus).override_failure_message(
		"TerrainModifiers.evasion_bonus diverged: expected 5, got %d" % lo.evasion_bonus
	).is_equal(5)

	# Assert — Array[StringName] size and content
	assert_int(lo.special_rules.size()).override_failure_message(
		"TerrainModifiers.special_rules.size() diverged: expected 2, got %d" % lo.special_rules.size()
	).is_equal(2)

	assert_bool(lo.special_rules[0] == &"bridge_no_flank").override_failure_message(
		(("TerrainModifiers.special_rules[0] diverged: expected &\"bridge_no_flank\","
		+ " got '%s'") % str(lo.special_rules[0]))
	).is_true()

	assert_bool(lo.special_rules[1] == &"siege_terrain").override_failure_message(
		(("TerrainModifiers.special_rules[1] diverged: expected &\"siege_terrain\","
		+ " got '%s'") % str(lo.special_rules[1]))
	).is_true()

	# Assert — element type preservation (both elements must be StringName)
	assert_int(typeof(lo.special_rules[0])).override_failure_message(
		(("TerrainModifiers.special_rules[0] typeof should be TYPE_STRING_NAME (%d), got %d"
		+ " — element type demotion after round-trip.") % [TYPE_STRING_NAME, typeof(lo.special_rules[0])])
	).is_equal(TYPE_STRING_NAME)

	assert_int(typeof(lo.special_rules[1])).override_failure_message(
		(("TerrainModifiers.special_rules[1] typeof should be TYPE_STRING_NAME (%d), got %d"
		+ " — element type demotion after round-trip.") % [TYPE_STRING_NAME, typeof(lo.special_rules[1])])
	).is_equal(TYPE_STRING_NAME)


## AC-4: CombatModifiers ResourceSaver round-trip — all 6 fields including
## signed int, bool, and Array[StringName].
func test_combat_modifiers_roundtrip_preserves_all_fields() -> void:
	# Arrange
	var original := CombatModifiers.new()
	original.defender_terrain_def = -15   # signed — guards against unsigned coercion
	original.defender_terrain_eva = 30
	original.elevation_atk_mod = 8
	original.elevation_def_mod = -8
	original.bridge_no_flank = true
	original.special_rules = [&"bridge_no_flank"]
	var tmp_path: String = _make_tmp_path("combat_modifiers")

	# Act
	var loaded: Resource = _save_and_load(original, tmp_path)
	if loaded == null:
		return

	# Assert — class identity
	assert_bool(loaded is CombatModifiers).override_failure_message(
		"Loaded resource is not CombatModifiers — class_name may be unregistered."
	).is_true()
	var lo: CombatModifiers = loaded as CombatModifiers

	# Assert — instance identity: loaded must be a fresh instance, not a cached
	# reuse of `original` (CACHE_MODE_IGNORE invariant — see AC-3 commentary).
	assert_bool(loaded != original).override_failure_message(
		"Loaded CombatModifiers is the same instance as original — "
		+ "CACHE_MODE_IGNORE may have regressed to CACHE_MODE_REUSE."
	).is_true()

	# Assert — all int fields including signed values
	assert_int(lo.defender_terrain_def).override_failure_message(
		(("CombatModifiers.defender_terrain_def diverged: expected -15, got %d"
		+ " — signed integer may have been coerced to unsigned.") % lo.defender_terrain_def)
	).is_equal(-15)

	assert_int(lo.defender_terrain_eva).override_failure_message(
		"CombatModifiers.defender_terrain_eva diverged: expected 30, got %d" % lo.defender_terrain_eva
	).is_equal(30)

	assert_int(lo.elevation_atk_mod).override_failure_message(
		"CombatModifiers.elevation_atk_mod diverged: expected 8, got %d" % lo.elevation_atk_mod
	).is_equal(8)

	assert_int(lo.elevation_def_mod).override_failure_message(
		(("CombatModifiers.elevation_def_mod diverged: expected -8, got %d"
		+ " — signed integer may have been coerced to unsigned.") % lo.elevation_def_mod)
	).is_equal(-8)

	# Assert — bool field
	assert_bool(lo.bridge_no_flank).override_failure_message(
		"CombatModifiers.bridge_no_flank diverged: expected true, got false"
	).is_true()

	# Assert — Array[StringName]
	assert_int(lo.special_rules.size()).override_failure_message(
		"CombatModifiers.special_rules.size() diverged: expected 1, got %d" % lo.special_rules.size()
	).is_equal(1)

	assert_bool(lo.special_rules[0] == &"bridge_no_flank").override_failure_message(
		(("CombatModifiers.special_rules[0] diverged: expected &\"bridge_no_flank\","
		+ " got '%s'") % str(lo.special_rules[0]))
	).is_true()

	assert_int(typeof(lo.special_rules[0])).override_failure_message(
		(("CombatModifiers.special_rules[0] typeof should be TYPE_STRING_NAME (%d), got %d"
		+ " — element type demotion after round-trip.") % [TYPE_STRING_NAME, typeof(lo.special_rules[0])])
	).is_equal(TYPE_STRING_NAME)


## AC-5: Type preservation across save/load — no silent Variant coercion.
## Verifies typeof() on loaded primitive fields and the array itself.
## Separate from AC-3/AC-4 so "field values match" and "types are correct"
## failures attribute to the right concern without ambiguity.
func test_terrain_resource_classes_type_preservation_after_roundtrip() -> void:
	# Arrange — TerrainModifiers instance
	var tm := TerrainModifiers.new()
	tm.defense_bonus = 25
	tm.evasion_bonus = 5
	tm.special_rules = [&"bridge_no_flank"]
	var tm_path: String = _make_tmp_path("type_preservation_tm")

	# Arrange — CombatModifiers instance
	var cm := CombatModifiers.new()
	cm.defender_terrain_def = -15
	cm.bridge_no_flank = true
	cm.special_rules = [&"bridge_no_flank"]
	var cm_path: String = _make_tmp_path("type_preservation_cm")

	# Act
	var loaded_tm: Resource = _save_and_load(tm, tm_path)
	var loaded_cm: Resource = _save_and_load(cm, cm_path)
	if loaded_tm == null or loaded_cm == null:
		return

	var lo_tm: TerrainModifiers = loaded_tm as TerrainModifiers
	var lo_cm: CombatModifiers = loaded_cm as CombatModifiers

	# Assert — TerrainModifiers field types (all int fields + array)
	assert_int(typeof(lo_tm.defense_bonus)).override_failure_message(
		(("TerrainModifiers.defense_bonus typeof should be TYPE_INT (%d), got %d"
		+ " — Variant/float coercion detected.") % [TYPE_INT, typeof(lo_tm.defense_bonus)])
	).is_equal(TYPE_INT)

	assert_int(typeof(lo_tm.evasion_bonus)).override_failure_message(
		(("TerrainModifiers.evasion_bonus typeof should be TYPE_INT (%d), got %d"
		+ " — Variant/float coercion detected.") % [TYPE_INT, typeof(lo_tm.evasion_bonus)])
	).is_equal(TYPE_INT)

	assert_int(typeof(lo_tm.special_rules)).override_failure_message(
		(("TerrainModifiers.special_rules typeof should be TYPE_ARRAY (%d), got %d"
		+ " — array type lost after round-trip.") % [TYPE_ARRAY, typeof(lo_tm.special_rules)])
	).is_equal(TYPE_ARRAY)

	# Assert — CombatModifiers field types (all 4 int fields + bool + array)
	assert_int(typeof(lo_cm.defender_terrain_def)).override_failure_message(
		(("CombatModifiers.defender_terrain_def typeof should be TYPE_INT (%d), got %d"
		+ " — Variant/float coercion detected.") % [TYPE_INT, typeof(lo_cm.defender_terrain_def)])
	).is_equal(TYPE_INT)

	assert_int(typeof(lo_cm.defender_terrain_eva)).override_failure_message(
		(("CombatModifiers.defender_terrain_eva typeof should be TYPE_INT (%d), got %d"
		+ " — Variant/float coercion detected.") % [TYPE_INT, typeof(lo_cm.defender_terrain_eva)])
	).is_equal(TYPE_INT)

	assert_int(typeof(lo_cm.elevation_atk_mod)).override_failure_message(
		(("CombatModifiers.elevation_atk_mod typeof should be TYPE_INT (%d), got %d"
		+ " — Variant/float coercion detected.") % [TYPE_INT, typeof(lo_cm.elevation_atk_mod)])
	).is_equal(TYPE_INT)

	assert_int(typeof(lo_cm.elevation_def_mod)).override_failure_message(
		(("CombatModifiers.elevation_def_mod typeof should be TYPE_INT (%d), got %d"
		+ " — Variant/float coercion detected.") % [TYPE_INT, typeof(lo_cm.elevation_def_mod)])
	).is_equal(TYPE_INT)

	assert_int(typeof(lo_cm.bridge_no_flank)).override_failure_message(
		(("CombatModifiers.bridge_no_flank typeof should be TYPE_BOOL (%d), got %d"
		+ " — bool coerced to int or Variant after round-trip.") % [TYPE_BOOL, typeof(lo_cm.bridge_no_flank)])
	).is_equal(TYPE_BOOL)

	assert_int(typeof(lo_cm.special_rules)).override_failure_message(
		(("CombatModifiers.special_rules typeof should be TYPE_ARRAY (%d), got %d"
		+ " — array type lost after round-trip.") % [TYPE_ARRAY, typeof(lo_cm.special_rules)])
	).is_equal(TYPE_ARRAY)
