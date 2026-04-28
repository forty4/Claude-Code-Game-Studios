extends GdUnitTestSuite

## unit_role_cost_table_test.gd
## Story 004 — get_class_cost_table + R-1 caller-mutation isolation regression test.
## Covers 7 ACs per story-004:
##   AC-1 (6×6 cost matrix correctness — all 36 cells via parametric fixture)
##   AC-2 (R-1 mitigation — caller-mutation isolation — BLOCKING regression test, ADR-0009 §Validation Criteria §6)
##   AC-3 (AC-13 Cavalry MOUNTAIN multiplier = 3.0)
##   AC-4 (AC-14 Scout FOREST multiplier = 0.7)
##   AC-5 (AC-15 array length = 6; RIVER/FORTRESS_WALL absent)
##   AC-6 (source-comment present in unit_role.gd above method declaration)
##   AC-7 (forbidden_pattern unit_role_returned_array_mutation registered in architecture.yaml)
##
## G-15: BOTH BalanceConstants AND UnitRole caches reset in before_test() — mandatory
##       even though get_class_cost_table does not call BalanceConstants directly
##       (reset discipline must be consistent across all unit_role test suites).
## G-16: Parametric cases use Array[Dictionary] (typed outer).
## G-9:  Multi-line failure messages wrap concat in parens before % operator.

# ── G-15 cache-reset paths ────────────────────────────────────────────────────

const _BC_PATH: String = "res://src/feature/balance/balance_constants.gd"
const _UR_PATH: String = "res://src/foundation/unit_role.gd"

var _bc_script: GDScript = load(_BC_PATH) as GDScript
var _ur_script: GDScript = load(_UR_PATH) as GDScript


func before_test() -> void:
	# G-15: reset BalanceConstants static cache — mandatory for all unit_role test suites
	# even when the tested method does not read BalanceConstants directly (consistency obligation).
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


# ── AC-1: 6×6 cost matrix correctness (36 cells via parametric fixture) ───────

## AC-1: Returns PackedFloat32Array typed result for every class.
func test_get_class_cost_table_returns_packed_float32_array_for_all_classes() -> void:
	var classes: Array[UnitRole.UnitClass] = [
		UnitRole.UnitClass.CAVALRY,
		UnitRole.UnitClass.INFANTRY,
		UnitRole.UnitClass.ARCHER,
		UnitRole.UnitClass.STRATEGIST,
		UnitRole.UnitClass.COMMANDER,
		UnitRole.UnitClass.SCOUT,
	]
	for unit_class: UnitRole.UnitClass in classes:
		var result: PackedFloat32Array = UnitRole.get_class_cost_table(unit_class)
		assert_bool(result is PackedFloat32Array).override_failure_message(
			"AC-1: get_class_cost_table(%d) must return PackedFloat32Array; got type %d" % [unit_class, typeof(result)]
		).is_true()
		assert_int(result.size()).override_failure_message(
			"AC-1: get_class_cost_table(%d) must have 6 entries; got %d" % [unit_class, result.size()]
		).is_equal(6)


## AC-1: Full 36-cell parametric fixture — all 6 classes × 6 terrain types.
## Values match GDD §CR-4 table exactly (cross-checked against unit_roles.json).
## terrain index: [ROAD=0, PLAINS=1, HILLS=2, FOREST=3, MOUNTAIN=4, BRIDGE=5]
func test_get_class_cost_table_all_36_cells_match_gdd_cr4() -> void:
	var cases: Array[Dictionary] = [
		{
			"unit_class": UnitRole.UnitClass.CAVALRY,
			"label": "CAVALRY",
			"expected": [1.0, 1.0, 1.5, 2.0, 3.0, 1.0],
		},
		{
			"unit_class": UnitRole.UnitClass.INFANTRY,
			"label": "INFANTRY",
			"expected": [1.0, 1.0, 1.0, 1.0, 1.5, 1.0],
		},
		{
			"unit_class": UnitRole.UnitClass.ARCHER,
			"label": "ARCHER",
			"expected": [1.0, 1.0, 1.0, 1.0, 2.0, 1.0],
		},
		{
			"unit_class": UnitRole.UnitClass.STRATEGIST,
			"label": "STRATEGIST",
			"expected": [1.0, 1.0, 1.5, 1.5, 2.0, 1.0],
		},
		{
			"unit_class": UnitRole.UnitClass.COMMANDER,
			"label": "COMMANDER",
			"expected": [1.0, 1.0, 1.0, 1.5, 2.0, 1.0],
		},
		{
			"unit_class": UnitRole.UnitClass.SCOUT,
			"label": "SCOUT",
			"expected": [1.0, 1.0, 1.0, 0.7, 1.5, 1.0],
		},
	]
	var terrain_names: Array[String] = ["ROAD", "PLAINS", "HILLS", "FOREST", "MOUNTAIN", "BRIDGE"]
	for case: Dictionary in cases:
		var unit_class: UnitRole.UnitClass = case["unit_class"] as int
		var label: String = case["label"] as String
		var expected: Array = case["expected"] as Array
		var result: PackedFloat32Array = UnitRole.get_class_cost_table(unit_class)
		for i: int in 6:
			var expected_val: float = expected[i] as float
			var actual_val: float = result[i]
			assert_float(actual_val).override_failure_message(
				("AC-1: %s[%s] expected %.4f; got %.4f")
				% [label, terrain_names[i], expected_val, actual_val]
			).is_equal_approx(expected_val, 0.0001)


# ── AC-2: R-1 mitigation — caller-mutation isolation (BLOCKING regression test) ─

## AC-2 (R-1 BLOCKING): Mutating caller A's returned array MUST NOT corrupt
## subsequent calls. This is the mandatory regression test per ADR-0009 §Validation Criteria §6.
## If this test fails, UnitRole.get_class_cost_table() has a caching bug and story-004 cannot close.
func test_get_class_cost_table_caller_mutation_isolated() -> void:
	# Arrange + Act: fetch table A and mutate MOUNTAIN entry (index 4)
	var table_a: PackedFloat32Array = UnitRole.get_class_cost_table(UnitRole.UnitClass.CAVALRY)
	table_a[4] = 99.0  # mutate MOUNTAIN — would corrupt a shared backing array

	# Act: fetch table B fresh
	var table_b: PackedFloat32Array = UnitRole.get_class_cost_table(UnitRole.UnitClass.CAVALRY)

	# Assert: caller B sees the original value (3.0), not the mutation (99.0)
	assert_float(table_b[4]).override_failure_message(
		("R-1 REGRESSION: table_b[MOUNTAIN] should be 3.0 (original) after table_a mutation; "
		+ "got %.4f — UnitRole is returning a shared backing array (caching bug).")
		% table_b[4]
	).is_equal_approx(3.0, 0.0001)

	# Assert: caller A's local copy retains the mutation (proves they're separate arrays,
	# not that the mutation was silently dropped by copy-on-write)
	assert_float(table_a[4]).override_failure_message(
		("R-1 REGRESSION: table_a[MOUNTAIN] should retain caller's mutation 99.0; "
		+ "got %.4f — COW semantics did not preserve local mutation")
		% table_a[4]
	).is_equal_approx(99.0, 0.0001)


## AC-2 extended: 100 rapid alternating fetches with mutations across all 6 classes.
## No cross-contamination after sustained mutation pressure per QA Test Cases AC-2 edge case.
func test_get_class_cost_table_sustained_mutation_no_cross_contamination() -> void:
	# Terrain index 4 = MOUNTAIN. Expected values per GDD CR-4:
	var expected_mountain: Array[float] = [3.0, 1.5, 2.0, 2.0, 2.0, 1.5]
	var classes: Array[UnitRole.UnitClass] = [
		UnitRole.UnitClass.CAVALRY, UnitRole.UnitClass.INFANTRY,
		UnitRole.UnitClass.ARCHER, UnitRole.UnitClass.STRATEGIST,
		UnitRole.UnitClass.COMMANDER, UnitRole.UnitClass.SCOUT,
	]
	# 100 rounds of fetch-mutate-refetch across all classes
	for _round: int in 100:
		for idx: int in 6:
			var unit_class: UnitRole.UnitClass = classes[idx]
			var t: PackedFloat32Array = UnitRole.get_class_cost_table(unit_class)
			t[4] = 999.0  # mutate MOUNTAIN on every fetched copy
			var fresh: PackedFloat32Array = UnitRole.get_class_cost_table(unit_class)
			assert_float(fresh[4]).override_failure_message(
				("AC-2 sustained: class=%d round=%d — MOUNTAIN expected %.4f; got %.4f")
				% [idx, _round, expected_mountain[idx], fresh[4]]
			).is_equal_approx(expected_mountain[idx], 0.0001)


# ── AC-3: AC-13 Cavalry MOUNTAIN multiplier = 3.0 ────────────────────────────

## AC-3 (AC-13): Cavalry MOUNTAIN multiplier is exactly 3.0.
## Combined with Map/Grid base MOUNTAIN cost 20 → floor(20 × 3.0) = 60.
## Cavalry move_budget=50 cannot enter (60 > 50) — Map/Grid enforces, not UnitRole.
func test_get_class_cost_table_cavalry_mountain_is_3_0() -> void:
	var result: PackedFloat32Array = UnitRole.get_class_cost_table(UnitRole.UnitClass.CAVALRY)
	# Index 4 = MOUNTAIN per terrain_cost_table index mapping
	assert_float(result[4]).override_failure_message(
		"AC-3 (AC-13): CAVALRY[MOUNTAIN=4] must be 3.0; got %.4f" % result[4]
	).is_equal_approx(3.0, 0.0001)


## AC-3: Re-fetch returns same 3.0 — idempotent; floor NOT applied here (UnitRole returns float multiplier).
func test_get_class_cost_table_cavalry_mountain_refetch_is_idempotent() -> void:
	var result1: PackedFloat32Array = UnitRole.get_class_cost_table(UnitRole.UnitClass.CAVALRY)
	var result2: PackedFloat32Array = UnitRole.get_class_cost_table(UnitRole.UnitClass.CAVALRY)
	assert_float(result2[4]).override_failure_message(
		"AC-3: CAVALRY[MOUNTAIN] refetch should match first fetch %.4f; got %.4f" % [result1[4], result2[4]]
	).is_equal_approx(result1[4], 0.0001)


# ── AC-4: AC-14 Scout FOREST multiplier = 0.7 ────────────────────────────────

## AC-4 (AC-14): Scout FOREST multiplier is 0.7.
## Combined with Map/Grid base FOREST cost 15 → floori(15 × 0.7) = floori(10.5) = 10.
## This equals base PLAINS cost — Scout traverses forest with no penalty (EC-5).
## The floor operation is Map/Grid responsibility; UnitRole returns the raw multiplier 0.7.
## 0.7 is not exactly representable in binary float — is_equal_approx is required.
func test_get_class_cost_table_scout_forest_is_0_7() -> void:
	var result: PackedFloat32Array = UnitRole.get_class_cost_table(UnitRole.UnitClass.SCOUT)
	# Index 3 = FOREST per terrain_cost_table index mapping
	assert_float(result[3]).override_failure_message(
		("AC-4 (AC-14): SCOUT[FOREST=3] must be ~0.7; got %.6f. "
		+ "floori(15×0.7)=floori(10.5)=10 equals PLAINS cost (Map/Grid applies floor).")
		% result[3]
	).is_equal_approx(0.7, 0.0001)


# ── AC-5: AC-15 array length = 6; RIVER/FORTRESS_WALL absent ─────────────────

## AC-5 (AC-15): Array length is always 6 for all classes.
## RIVER and FORTRESS_WALL are NOT in this table — impassability handled by Map/Grid
## via is_passable_base = false checks BEFORE cost-table lookup.
func test_get_class_cost_table_size_is_6_for_all_classes() -> void:
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
		var result: PackedFloat32Array = UnitRole.get_class_cost_table(unit_class)
		assert_int(result.size()).override_failure_message(
			("AC-5 (AC-15): %s table must have exactly 6 entries (ROAD/PLAINS/HILLS/FOREST/"
			+ "MOUNTAIN/BRIDGE); RIVER/FORTRESS_WALL absent by design. Got size=%d")
			% [label, result.size()]
		).is_equal(6)


# ── AC-6: Source-comment present in unit_role.gd ──────────────────────────────

## AC-6: The R-1 source-comment marker must be present above the method declaration.
## Structural source-file assertion — if the comment is removed, CI lint fails.
## The marker is a single-# code comment (NOT double-## doc comment) — it is a
## static-lint guard, not API documentation. The ## doc-block below it serves API-doc.
func test_get_class_cost_table_source_comment_present() -> void:
	var content: String = FileAccess.get_file_as_string("res://src/foundation/unit_role.gd")
	assert_bool(content.contains("# RETURNS PER-CALL COPY")).override_failure_message(
		("AC-6: src/foundation/unit_role.gd must contain the R-1 source-comment marker "
		+ "'# RETURNS PER-CALL COPY' above get_class_cost_table declaration. "
		+ "Comment is the mandatory guard per ADR-0009 §5.")
	).is_true()


# ── AC-7: forbidden_pattern entry intact in architecture.yaml ─────────────────

## AC-7: The unit_role_returned_array_mutation forbidden_pattern entry must be registered
## in docs/registry/architecture.yaml (authored at ADR-0009 commit f4f1915).
## Confirms the static-lint layer is in place alongside the runtime regression test.
## Both are required per ADR-0009 §R-1: lint is preventive; regression test is detective.
func test_architecture_yaml_unit_role_returned_array_mutation_entry_intact() -> void:
	var content: String = FileAccess.get_file_as_string(
		"res://docs/registry/architecture.yaml"
	)
	assert_bool(content.contains("unit_role_returned_array_mutation")).override_failure_message(
		("AC-7: docs/registry/architecture.yaml must contain 'unit_role_returned_array_mutation' "
		+ "forbidden_pattern entry (authored at commit f4f1915 per ADR-0009). "
		+ "Static lint + runtime regression test are BOTH required per ADR-0009 §R-1.")
	).is_true()
