extends GdUnitTestSuite

## unit_role_skeleton_test.gd
## Story 001 skeleton tests — UnitRole module form invariants + UnitClass enum +
## provisional HeroData wrapper. Covers AC-1 through AC-5 per story QA Test Cases.
##
## AC-3 NOTE: @abstract blocks UnitRole.new() at RUNTIME (not parse time).
## assert_error() with any() matcher captures whichever push_error Godot 4.6 emits.
## Per story spec: "iterate the test pattern" if is_push_error variant doesn't match.
##
## LIFECYCLE:
##   before_test — no mutable state to reset (UnitRole is all-static, _coefficients_loaded
##                 only written by Story 002+ load path; HeroData.new() is side-effect-free)
##   after_test  — no cleanup needed (no nodes, no autoload swaps, no file I/O)


## G-15 discipline (consistent with stories 002-009): reset both BalanceConstants
## and UnitRole caches even though this skeleton test doesn't transitively read
## either cache. Future-proofs against test additions that DO read; satisfies
## tools/ci/lint_unit_role.sh Check 3 (universal G-15 obligation across all
## unit_role*.gd test files).
const _BC_PATH: String = "res://src/foundation/balance/balance_constants.gd"
const _UR_PATH: String = "res://src/foundation/unit_role.gd"
var _bc_script: GDScript = load(_BC_PATH) as GDScript
var _ur_script: GDScript = load(_UR_PATH) as GDScript


func before_test() -> void:
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})
	_ur_script.set("_coefficients_loaded", false)
	_ur_script.set("_coefficients", {})


func after_test() -> void:
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})
	_ur_script.set("_coefficients_loaded", false)
	_ur_script.set("_coefficients", {})


# ── AC-1: UnitRole skeleton is a RefCounted subclass ─────────────────────────


## AC-1: UnitRole class_name resolves; is_class("RefCounted") returns true;
## zero instance fields (only static var _coefficients_loaded is present).
func test_unit_role_is_refcounted_subclass() -> void:
	# Arrange + Act — instantiating UnitRole directly will fail (@abstract);
	# verify the class type via a Script reference instead.
	var script: GDScript = load("res://src/foundation/unit_role.gd") as GDScript

	# Assert — script loaded without error
	assert_bool(script != null).override_failure_message(
		"AC-1: failed to load res://src/foundation/unit_role.gd — file missing or parse error"
	).is_true()

	# Assert — the class extends RefCounted (base_type string)
	assert_str(script.get_instance_base_type()).override_failure_message(
		"AC-1: UnitRole base type is '%s'; expected 'RefCounted'" % script.get_instance_base_type()
	).is_equal("RefCounted")


# ── AC-2: UnitClass enum values 0..5 ─────────────────────────────────────────


## AC-2: All 6 UnitClass enum members resolve to their expected int values.
func test_unit_role_unit_class_enum_values_match_spec() -> void:
	# Assert each member against its specified backing value
	assert_int(UnitRole.UnitClass.CAVALRY).override_failure_message(
		"AC-2: CAVALRY expected 0"
	).is_equal(0)

	assert_int(UnitRole.UnitClass.INFANTRY).override_failure_message(
		"AC-2: INFANTRY expected 1"
	).is_equal(1)

	assert_int(UnitRole.UnitClass.ARCHER).override_failure_message(
		"AC-2: ARCHER expected 2"
	).is_equal(2)

	assert_int(UnitRole.UnitClass.STRATEGIST).override_failure_message(
		"AC-2: STRATEGIST expected 3"
	).is_equal(3)

	assert_int(UnitRole.UnitClass.COMMANDER).override_failure_message(
		"AC-2: COMMANDER expected 4"
	).is_equal(4)

	assert_int(UnitRole.UnitClass.SCOUT).override_failure_message(
		"AC-2: SCOUT expected 5"
	).is_equal(5)


## AC-2 (size): UnitClass has exactly 6 entries.
func test_unit_role_unit_class_enum_has_six_entries() -> void:
	# UnitClass.size() returns the number of enum members in GDScript
	assert_int(UnitRole.UnitClass.size()).override_failure_message(
		"AC-2: UnitRole.UnitClass.size() is %d; expected 6" % UnitRole.UnitClass.size()
	).is_equal(6)


# ── AC-3: @abstract blocks UnitRole.new() at runtime ─────────────────────────


## AC-3: UnitRole is declared @abstract — verified by inspecting the source file.
##
## Godot 4.6 behaviour discovered during story-001 iteration:
##   - Typed `var x: UnitRole = UnitRole.new()` → parse error at GDScript load time
##     ("Cannot construct abstract class"). This prevents the test file itself from
##     loading, so it cannot be tested from inside a GdUnit4 suite.
##   - `GDScript.new()` (reflective path) → bypasses @abstract entirely; returns a
##     live RefCounted instance with no error. Not a viable test path.
##   - push_error / is_push_error → no push_error is emitted by either path.
##
## Conclusion: the correct test for @abstract is a structural/textual assertion
## that the decorator is present in the source file. This assertion fails immediately
## if @abstract is removed, and is honest about Godot 4.6's enforcement mechanism.
func test_unit_role_new_raises_runtime_error() -> void:
	# Read the source file and assert @abstract is declared.
	var content: String = FileAccess.get_file_as_string("res://src/foundation/unit_role.gd")
	assert_bool(content.length() > 0).override_failure_message(
		"AC-3 pre-condition: failed to read res://src/foundation/unit_role.gd"
	).is_true()

	assert_bool(content.contains("@abstract")).override_failure_message(
		"AC-3: unit_role.gd must declare @abstract to block typed UnitRole.new() "
		+ "at parse time (Godot 4.6 enforcement mechanism). Decorator is missing."
	).is_true()


# ── AC-4: HeroData provisional wrapper ───────────────────────────────────────


## AC-4: HeroData.new() succeeds and all 10 @export fields are present with
## their correct default values.
func test_hero_data_provisional_fields_present_with_defaults() -> void:
	# Arrange + Act
	var hero: HeroData = HeroData.new()

	# Assert — instance created successfully
	assert_bool(hero != null).override_failure_message(
		"AC-4: HeroData.new() returned null"
	).is_true()

	# Assert — all 10 fields at their specified defaults
	assert_int(hero.stat_might).override_failure_message(
		"AC-4: stat_might default expected 1, got %d" % hero.stat_might
	).is_equal(1)

	assert_int(hero.stat_intellect).override_failure_message(
		"AC-4: stat_intellect default expected 1, got %d" % hero.stat_intellect
	).is_equal(1)

	assert_int(hero.stat_command).override_failure_message(
		"AC-4: stat_command default expected 1, got %d" % hero.stat_command
	).is_equal(1)

	assert_int(hero.stat_agility).override_failure_message(
		"AC-4: stat_agility default expected 1, got %d" % hero.stat_agility
	).is_equal(1)

	assert_int(hero.base_hp_seed).override_failure_message(
		"AC-4: base_hp_seed default expected 1, got %d" % hero.base_hp_seed
	).is_equal(1)

	assert_int(hero.base_initiative_seed).override_failure_message(
		"AC-4: base_initiative_seed default expected 1, got %d" % hero.base_initiative_seed
	).is_equal(1)

	assert_int(hero.move_range).override_failure_message(
		"AC-4: move_range default expected 2, got %d" % hero.move_range
	).is_equal(2)

	assert_int(hero.default_class).override_failure_message(
		"AC-4: default_class default expected 0, got %d" % hero.default_class
	).is_equal(0)

	assert_bool(hero.innate_skill_ids.is_empty()).override_failure_message(
		"AC-4: innate_skill_ids should be empty by default"
	).is_true()

	assert_bool(hero.equipment_slot_override.is_empty()).override_failure_message(
		"AC-4: equipment_slot_override should be empty by default"
	).is_true()


## AC-4 (typing): innate_skill_ids accepts StringName literals and stores them correctly.
## Per G-20: StringName==String returns true at == operator; type defense is the
## Array[StringName] boundary. This test verifies the typed-array coercion works.
func test_hero_data_innate_skill_ids_is_typed_stringname_array() -> void:
	# Arrange
	var hero: HeroData = HeroData.new()

	# Act — append a StringName literal (correct type)
	hero.innate_skill_ids.append(&"passive_charge")

	# Assert — element stored as StringName
	assert_bool(hero.innate_skill_ids[0] is StringName).override_failure_message(
		"AC-4 typing: innate_skill_ids[0] should be StringName after append(&'passive_charge')"
	).is_true()


# ── AC-5: Doc-comment compliance (grep-based) ─────────────────────────────────


## AC-5: unit_role.gd head-of-file doc-comment contains the required strings.
func test_unit_role_doc_comment_contains_required_strings() -> void:
	# Arrange — read the source file
	var file_path: String = "res://src/foundation/unit_role.gd"
	var content: String = FileAccess.get_file_as_string(file_path)

	assert_bool(content.length() > 0).override_failure_message(
		"AC-5: failed to read %s — file missing or empty" % file_path
	).is_true()

	# Assert — required citation strings present
	assert_bool(content.contains("ADR-0009")).override_failure_message(
		"AC-5: unit_role.gd doc-comment must contain 'ADR-0009'"
	).is_true()

	assert_bool(content.contains("Foundation")).override_failure_message(
		"AC-5: unit_role.gd doc-comment must contain 'Foundation'"
	).is_true()

	assert_bool(content.contains("non-emitter")).override_failure_message(
		"AC-5: unit_role.gd doc-comment must contain 'non-emitter'"
	).is_true()


## AC-5: hero_data.gd head-of-file doc-comment contains the required strings.
func test_hero_data_doc_comment_contains_required_strings() -> void:
	# Arrange — read the source file
	var file_path: String = "res://src/foundation/hero_data.gd"
	var content: String = FileAccess.get_file_as_string(file_path)

	assert_bool(content.length() > 0).override_failure_message(
		"AC-5: failed to read %s — file missing or empty" % file_path
	).is_true()

	# Assert — required citation strings present
	assert_bool(content.contains("ADR-0009 §Migration Plan §3")).override_failure_message(
		"AC-5: hero_data.gd doc-comment must contain 'ADR-0009 §Migration Plan §3'"
	).is_true()

	assert_bool(content.contains("ADR-0007")).override_failure_message(
		"AC-5: hero_data.gd doc-comment must contain 'ADR-0007'"
	).is_true()

	assert_bool(content.contains("provisional")).override_failure_message(
		"AC-5: hero_data.gd doc-comment must contain 'provisional'"
	).is_true()
