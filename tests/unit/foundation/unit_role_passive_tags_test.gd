extends GdUnitTestSuite

## unit_role_passive_tags_test.gd
## Story 006 — PASSIVE_TAG_BY_CLASS const Dictionary + Array[StringName] consumer pattern.
## Covers 6 ACs per story-006:
##   AC-1 (Const Dictionary correctness — 6 entries with int keys 0..5)
##   AC-2 (Per-class StringName values exact match — all 6 classes vs GDD §CR-2 + ADR-0009 §7)
##   AC-3 (StringName interning — process-global identity; typeof() returns TYPE_STRING_NAME)
##   AC-4 (Array[StringName] consumer pattern — typed-array assignment + in-operator)
##   AC-5 (JSON-vs-const drift — unit_roles.json passive_tag String matches const value per class)
##   AC-6 (Activation logic OUT OF SCOPE — grep: no activation predicates in unit_role.gd)
##
## G-15: BOTH BalanceConstants AND UnitRole caches reset in before_test() — mandatory
##       even though PASSIVE_TAG_BY_CLASS is parse-time const that reads neither cache.
##       Discipline obligation consistent with stories 003/004/005.
## G-9:  Multi-line failure messages wrap concat in parens before % operator.
## G-20: StringName == String returns true in Godot 4.6; typed-array boundary is the real defense.

# ── G-15 cache-reset paths ────────────────────────────────────────────────────

const _BC_PATH: String = "res://src/foundation/balance/balance_constants.gd"
const _UR_PATH: String = "res://src/foundation/unit_role.gd"

var _bc_script: GDScript = load(_BC_PATH) as GDScript
var _ur_script: GDScript = load(_UR_PATH) as GDScript


func before_test() -> void:
	# G-15: reset BalanceConstants static cache — mandatory for all unit_role test suites
	# even when the tested const does not read BalanceConstants directly (consistency obligation).
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})
	# G-15: reset UnitRole static cache so each test starts with a clean coefficient load.
	_ur_script.set("_coefficients_loaded", false)
	_ur_script.set("_coefficients", {})


func after_test() -> void:
	# Safety net: same reset after each test.
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})
	_ur_script.set("_coefficients_loaded", false)
	_ur_script.set("_coefficients", {})


# ── AC-1: Const Dictionary correctness — 6 entries ────────────────────────────

## AC-1: PASSIVE_TAG_BY_CLASS has exactly 6 entries with int keys 0..5.
## Keys are UnitClass enum int values (CAVALRY=0..SCOUT=5) — parse-time literal const.
func test_passive_tag_by_class_has_exactly_6_entries() -> void:
	assert_int(UnitRole.PASSIVE_TAG_BY_CLASS.size()).override_failure_message(
		"AC-1: PASSIVE_TAG_BY_CLASS must have exactly 6 entries (one per UnitClass enum value)."
	).is_equal(6)


## AC-1: All 6 int keys (0..5) are present in PASSIVE_TAG_BY_CLASS.
func test_passive_tag_by_class_contains_all_6_unit_class_int_keys() -> void:
	for expected_key: int in 6:
		assert_bool(UnitRole.PASSIVE_TAG_BY_CLASS.has(expected_key)).override_failure_message(
			("AC-1: PASSIVE_TAG_BY_CLASS is missing key %d "
			+ "(UnitClass enum int value 0..5 must all be present).")
			% expected_key
		).is_true()


# ── AC-2: Per-class StringName values exact match ─────────────────────────────

## AC-2: All 6 per-class StringName values match GDD §CR-2 + ADR-0009 §7 exactly.
## Uses parametric fixture — locked tag set per ADR-0009 §7.
func test_passive_tag_by_class_all_6_values_match_gdd_cr2() -> void:
	var cases: Array[Dictionary] = [
		{
			"unit_class": UnitRole.UnitClass.CAVALRY,
			"label": "CAVALRY",
			"expected_str": "passive_charge",
		},
		{
			"unit_class": UnitRole.UnitClass.INFANTRY,
			"label": "INFANTRY",
			"expected_str": "passive_shield_wall",
		},
		{
			"unit_class": UnitRole.UnitClass.ARCHER,
			"label": "ARCHER",
			"expected_str": "passive_high_ground_shot",
		},
		{
			"unit_class": UnitRole.UnitClass.STRATEGIST,
			"label": "STRATEGIST",
			"expected_str": "passive_tactical_read",
		},
		{
			"unit_class": UnitRole.UnitClass.COMMANDER,
			"label": "COMMANDER",
			"expected_str": "passive_rally",
		},
		{
			"unit_class": UnitRole.UnitClass.SCOUT,
			"label": "SCOUT",
			"expected_str": "passive_ambush",
		},
	]
	for case: Dictionary in cases:
		var unit_class: UnitRole.UnitClass = case["unit_class"] as int
		var label: String = case["label"] as String
		var expected: String = case["expected_str"] as String
		var actual: Variant = UnitRole.PASSIVE_TAG_BY_CLASS[unit_class]
		# G-20: StringName == String returns true in Godot 4.6 — this comparison is intentional
		# for cross-doc consistency (GDD/JSON use String; const uses StringName; both match).
		assert_str(actual as String).override_failure_message(
			("AC-2: PASSIVE_TAG_BY_CLASS[%s] expected '%s'; got '%s'. "
			+ "Tag set locked per ADR-0009 §7 + GDD §CR-2.")
			% [label, expected, actual as String]
		).is_equal(expected)


# ── AC-3: StringName interning — process-global identity ─────────────────────

## AC-3: PASSIVE_TAG_BY_CLASS values are StringName (not String).
## typeof() returns TYPE_STRING_NAME (constant int 21 per Godot 4.x).
func test_passive_tag_by_class_values_are_string_name_type() -> void:
	var cases: Array[Dictionary] = [
		{"unit_class": UnitRole.UnitClass.CAVALRY,    "label": "CAVALRY"},
		{"unit_class": UnitRole.UnitClass.INFANTRY,   "label": "INFANTRY"},
		{"unit_class": UnitRole.UnitClass.ARCHER,     "label": "ARCHER"},
		{"unit_class": UnitRole.UnitClass.STRATEGIST, "label": "STRATEGIST"},
		{"unit_class": UnitRole.UnitClass.COMMANDER,  "label": "COMMANDER"},
		{"unit_class": UnitRole.UnitClass.SCOUT,      "label": "SCOUT"},
	]
	for case: Dictionary in cases:
		var unit_class: UnitRole.UnitClass = case["unit_class"] as int
		var label: String = case["label"] as String
		var actual: Variant = UnitRole.PASSIVE_TAG_BY_CLASS[unit_class]
		assert_int(typeof(actual)).override_failure_message(
			("AC-3: PASSIVE_TAG_BY_CLASS[%s] must be TYPE_STRING_NAME (int 21); "
			+ "got typeof=%d. Values must be &\"passive_*\" StringName literals, "
			+ "not plain String. Per ADR-0012 damage_calc_dictionary_payload precedent.")
			% [label, typeof(actual)]
		).is_equal(TYPE_STRING_NAME)


## AC-3: Process-global interning — &"passive_charge" == &"passive_charge" is reliable.
## Per godot-specialist /architecture-review 2026-04-28 Item 7: StringName interning
## is process-global in Godot 4.6.
func test_passive_tag_cavalry_interned_equals_literal_string_name() -> void:
	var actual: Variant = UnitRole.PASSIVE_TAG_BY_CLASS[UnitRole.UnitClass.CAVALRY]
	# G-20: This comparison uses StringName == StringName (both interned to same address).
	# Process-global interning makes this a stable identity comparison, not just value comparison.
	assert_bool(actual == &"passive_charge").override_failure_message(
		("AC-3: PASSIVE_TAG_BY_CLASS[CAVALRY] == &\"passive_charge\" must be true. "
		+ "StringName interning is process-global per ADR-0009 §Engine Compatibility note. "
		+ "Got: %s")
		% (actual as String)
	).is_true()


# ── AC-4: Array[StringName] consumer pattern ──────────────────────────────────

## AC-4: Typed Array[StringName] consumer pattern — assignment from PASSIVE_TAG_BY_CLASS.
## Tests the mandatory consumer form per ADR-0012 damage_calc_dictionary_payload precedent.
func test_passive_tag_array_string_name_consumer_pattern() -> void:
	# Arrange: construct typed consumer array from const values (illustrates the consumer pattern)
	var passive_set: Array[StringName] = [
		UnitRole.PASSIVE_TAG_BY_CLASS[UnitRole.UnitClass.CAVALRY],
		UnitRole.PASSIVE_TAG_BY_CLASS[UnitRole.UnitClass.SCOUT],
	]

	# Assert: size is correct
	assert_int(passive_set.size()).override_failure_message(
		"AC-4: passive_set Array[StringName] should have 2 entries after construction."
	).is_equal(2)

	# Assert: in-operator with StringName literal returns true for present values
	assert_bool(&"passive_charge" in passive_set).override_failure_message(
		"AC-4: &\"passive_charge\" in passive_set must be true (CAVALRY passive is in the array)."
	).is_true()

	assert_bool(&"passive_ambush" in passive_set).override_failure_message(
		"AC-4: &\"passive_ambush\" in passive_set must be true (SCOUT passive is in the array)."
	).is_true()

	# Assert: non-member returns false
	assert_bool(&"passive_shield_wall" in passive_set).override_failure_message(
		"AC-4: &\"passive_shield_wall\" in passive_set must be false (INFANTRY not in the 2-element set)."
	).is_false()


## AC-4: Typed Array[StringName] enforces the element type — runtime coercion defense.
## Array[StringName] elements are StringName by structural type enforcement.
## This verifies the typed-array element is StringName (not String) after append.
func test_passive_tag_array_string_name_element_type_is_string_name() -> void:
	var passive_set: Array[StringName] = []
	passive_set.append(UnitRole.PASSIVE_TAG_BY_CLASS[UnitRole.UnitClass.CAVALRY])
	# Per G-20: the typed-array boundary is the defense, not the == operator.
	# Verify the element is indeed StringName via is operator.
	assert_bool(passive_set[0] is StringName).override_failure_message(
		("AC-4: passive_set[0] is StringName must be true. "
		+ "Array[StringName] preserves StringName type at element boundary. "
		+ "G-20: this is the real defense against Array[String] type confusion.")
	).is_true()


# ── AC-5: JSON-vs-const drift detection ──────────────────────────────────────

## AC-5: unit_roles.json passive_tag String per class matches PASSIVE_TAG_BY_CLASS value.
## Cross-doc consistency check — CI lint obligation per ADR-0009 §4.
## Loads unit_roles.json via FileAccess + JSON.new().parse(); compares per-class strings.
## Drift between JSON documentation and const runtime is a defect per story-006 §Control Manifest.
func test_passive_tag_json_matches_const_for_all_6_classes() -> void:
	var json_path: String = "res://assets/data/config/unit_roles.json"
	var json_text: String = FileAccess.get_file_as_string(json_path)
	assert_bool(not json_text.is_empty()).override_failure_message(
		"AC-5: Could not read unit_roles.json at path: " + json_path
	).is_true()

	var parser: JSON = JSON.new()
	var parse_result: int = parser.parse(json_text)
	assert_int(parse_result).override_failure_message(
		("AC-5: unit_roles.json parse failed with error code %d. "
		+ "JSON must be valid for cross-doc consistency check.")
		% parse_result
	).is_equal(OK)

	var data: Dictionary = parser.data as Dictionary

	var class_key_map: Array[Dictionary] = [
		{"key": "cavalry",    "unit_class": UnitRole.UnitClass.CAVALRY},
		{"key": "infantry",   "unit_class": UnitRole.UnitClass.INFANTRY},
		{"key": "archer",     "unit_class": UnitRole.UnitClass.ARCHER},
		{"key": "strategist", "unit_class": UnitRole.UnitClass.STRATEGIST},
		{"key": "commander",  "unit_class": UnitRole.UnitClass.COMMANDER},
		{"key": "scout",      "unit_class": UnitRole.UnitClass.SCOUT},
	]

	for entry: Dictionary in class_key_map:
		var class_key: String = entry["key"] as String
		var unit_class: UnitRole.UnitClass = entry["unit_class"] as int

		assert_bool(data.has(class_key)).override_failure_message(
			"AC-5: unit_roles.json missing class key '%s'." % class_key
		).is_true()

		var class_entry: Dictionary = data[class_key] as Dictionary
		assert_bool(class_entry.has("passive_tag")).override_failure_message(
			"AC-5: unit_roles.json class '%s' missing 'passive_tag' field." % class_key
		).is_true()

		var json_tag: String = class_entry["passive_tag"] as String
		var const_tag: String = str(UnitRole.PASSIVE_TAG_BY_CLASS[unit_class])
		# G-20: StringName str() conversion produces the same String for comparison.
		assert_str(json_tag).override_failure_message(
			("AC-5 (JSON-vs-const drift): unit_roles.json['%s']['passive_tag'] = '%s' "
			+ "but PASSIVE_TAG_BY_CLASS[%s] = '%s'. These must match. "
			+ "Drift is a defect per ADR-0009 §4 + story-006 §Control Manifest.")
			% [class_key, json_tag, class_key, const_tag]
		).is_equal(const_tag)


# ── AC-6: Activation logic OUT OF SCOPE — verify by absence ──────────────────

## AC-6: unit_role.gd must NOT contain activation predicates.
## Activation logic (accumulated_move_cost, acted_this_turn, delta_elevation, etc.)
## is consumer-side per ADR-0009 §7. UnitRole owns ONLY the canonical tag set.
func test_unit_role_does_not_contain_activation_predicates() -> void:
	var content: String = FileAccess.get_file_as_string("res://src/foundation/unit_role.gd")
	# Exclude comment lines (lines starting with optional whitespace + "#") to avoid
	# false-positives on GDD prose references in doc comments.
	var lines: PackedStringArray = content.split("\n")
	var non_comment_content: String = ""
	for line: String in lines:
		var stripped: String = line.strip_edges()
		if not stripped.begins_with("#"):
			non_comment_content += line + "\n"

	var predicates: Array[String] = [
		"accumulated_move_cost",
		"acted_this_turn",
		"delta_elevation",
	]
	for predicate: String in predicates:
		assert_bool(not non_comment_content.contains(predicate)).override_failure_message(
			("AC-6 (ADR-0009 §7 activation-logic-out-of-scope): "
			+ "unit_role.gd must NOT contain activation predicate '%s'. "
			+ "Activation logic is consumer-side (Damage Calc / Turn Order / HP-Status). "
			+ "UnitRole owns only the canonical tag set.")
			% predicate
		).is_true()
