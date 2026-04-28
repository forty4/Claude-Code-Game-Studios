extends GdUnitTestSuite

## unit_role_direction_mult_test.gd
## Story 005 — get_class_direction_mult + 6×3 table read from unit_roles.json.
## Covers 6 ACs per story-005:
##   AC-1 (6×3 = 18 cells correctness — all cells via parametric fixture, GDD §CR-6a)
##   AC-2 (AC-16 Cavalry REAR rev 2.8 value = 1.09 — load-bearing regression sentinel)
##   AC-3 (AC-17 Scout REAR composition baseline = 1.1)
##   AC-4 (Runtime read source — unit_roles.json NOT entities.yaml; sentinel 9.99 propagation)
##   AC-5 (No BalanceConstants read in method body — static source-file assertion)
##   AC-6 (STRATEGIST + COMMANDER no-op rows = all 1.0 by design)
##
## G-15: BOTH BalanceConstants AND UnitRole caches reset in before_test() — mandatory
##       even though get_class_direction_mult does not call BalanceConstants directly.
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


# ── AC-1: 6×3 = 18 cells correctness (parametric fixture, GDD §CR-6a) ────────

## AC-1: Full 18-cell parametric fixture — all 6 classes × 3 directions.
## Values match GDD §CR-6a rev 2.8 + ADR-0009 §6 table exactly.
## direction index: [FRONT=0, FLANK=1, REAR=2] per ADR-0004 §5b ATK_DIR constants.
## Cavalry REAR = 1.09 (NOT 1.20 — rev 2.8 Rally-ceiling-fix; load-bearing per AC-2).
## ARCHER FLANK = 1.375 (exactly representable in binary float; use approx uniformly regardless).
func test_get_class_direction_mult_all_18_cells_match_gdd_cr6a() -> void:
	var cases: Array[Dictionary] = [
		{
			"unit_class": UnitRole.UnitClass.CAVALRY,
			"label": "CAVALRY",
			"expected": [1.0, 1.1, 1.09],
		},
		{
			"unit_class": UnitRole.UnitClass.INFANTRY,
			"label": "INFANTRY",
			"expected": [0.9, 1.0, 1.1],
		},
		{
			"unit_class": UnitRole.UnitClass.ARCHER,
			"label": "ARCHER",
			"expected": [1.0, 1.375, 0.9],
		},
		{
			"unit_class": UnitRole.UnitClass.STRATEGIST,
			"label": "STRATEGIST",
			"expected": [1.0, 1.0, 1.0],
		},
		{
			"unit_class": UnitRole.UnitClass.COMMANDER,
			"label": "COMMANDER",
			"expected": [1.0, 1.0, 1.0],
		},
		{
			"unit_class": UnitRole.UnitClass.SCOUT,
			"label": "SCOUT",
			"expected": [1.0, 1.0, 1.1],
		},
	]
	var direction_names: Array[String] = ["FRONT", "FLANK", "REAR"]
	for case: Dictionary in cases:
		var unit_class: UnitRole.UnitClass = case["unit_class"] as int
		var label: String = case["label"] as String
		var expected: Array = case["expected"] as Array
		for dir: int in 3:
			var expected_val: float = expected[dir] as float
			var actual_val: float = UnitRole.get_class_direction_mult(unit_class, dir)
			assert_float(actual_val).override_failure_message(
				("AC-1: %s[%s] expected %.4f; got %.4f")
				% [label, direction_names[dir], expected_val, actual_val]
			).is_equal_approx(expected_val, 0.0001)


# ── AC-2: AC-16 Cavalry REAR rev 2.8 value = 1.09 (load-bearing regression) ──

## AC-2 (AC-16): Cavalry REAR = 1.09 — the rev 2.8 Rally-ceiling-fix value.
## Any regression to 1.20 (pre-rev-2.8) activates DAMAGE_CEILING=180 per
## damage-calc.md ninth-pass desync audit BLK-G-2, collapsing Pillar-1+3 hierarchies.
## This is an explicit load-bearing cell — AC-16 in GDD unit-role.md.
func test_get_class_direction_mult_cavalry_rear_is_1_09_rev_2_8_value() -> void:
	var result: float = UnitRole.get_class_direction_mult(UnitRole.UnitClass.CAVALRY, 2)
	assert_float(result).override_failure_message(
		("AC-2 (AC-16 LOAD-BEARING): CAVALRY REAR (direction=2) must be 1.09 (rev 2.8 value). "
		+ "Got %.6f. Any regression to 1.20 activates DAMAGE_CEILING=180 per BLK-G-2.")
		% result
	).is_equal_approx(1.09, 0.0001)


## AC-2: Explicitly verify 1.09 is NOT returned as 1.20 — regression sentinel for the specific
## pre-rev-2.8 stale value that collapses Pillar-1+3 hierarchies.
func test_get_class_direction_mult_cavalry_rear_is_not_the_stale_1_20_value() -> void:
	var result: float = UnitRole.get_class_direction_mult(UnitRole.UnitClass.CAVALRY, 2)
	assert_float(result).override_failure_message(
		("AC-2 REGRESSION SENTINEL: CAVALRY REAR must NOT be 1.20 (stale pre-rev-2.8 value). "
		+ "Got %.6f. Rev 2.8 lowered to 1.09 per Rally-ceiling fix BLK-G-2.")
		% result
	).is_not_equal(1.20)


# ── AC-3: AC-17 Scout REAR composition baseline = 1.1 ────────────────────────

## AC-3 (AC-17): Scout REAR = 1.1 — per-cell value returned by UnitRole.
## Damage Calc applies the full composition: base REAR×1.5 + AMBUSH_BONUS=1.15
## → 1.5 × 1.1 × 1.15 = 1.897 per GDD §CR-6b.
## This test verifies UnitRole's contribution (1.1); full composition is Story 009.
func test_get_class_direction_mult_scout_rear_baseline_is_1_1() -> void:
	var result: float = UnitRole.get_class_direction_mult(UnitRole.UnitClass.SCOUT, 2)
	assert_float(result).override_failure_message(
		("AC-3 (AC-17): SCOUT REAR (direction=2) must be 1.1. Got %.6f. "
		+ "Full composition 1.5×1.1×1.15=1.897 is Story 009 (Damage Calc integration).")
		% result
	).is_equal_approx(1.1, 0.0001)


# ── AC-4: Runtime read source — unit_roles.json NOT entities.yaml ─────────────

## AC-4: Runtime read source is unit_roles.json, NOT entities.yaml / BalanceConstants.
## Method: write a minimal fixture JSON with cavalry class_direction_mult[2] = 9.99 (sentinel).
## Inject via the optional path parameter of _load_coefficients (DI pattern, story-002 precedent).
## Assert that get_class_direction_mult(CAVALRY, 2) returns 9.99 (sentinel from fixture JSON).
## This proves the runtime source is unit_roles.json and NOT the stale [4][3] entities.yaml entry.
func test_get_class_direction_mult_runtime_source_is_unit_roles_json_not_entities_yaml() -> void:
	# Arrange: write minimal fixture JSON with sentinel value 9.99 for cavalry REAR
	var fixture_json: String = """{
  "cavalry": {
    "primary_stat": "stat_might", "secondary_stat": null,
    "w_primary": 1.0, "w_secondary": 0.0,
    "class_atk_mult": 1.1, "class_phys_def_mult": 0.8, "class_mag_def_mult": 0.7,
    "class_hp_mult": 0.9, "class_init_mult": 0.9, "class_move_delta": 1,
    "passive_tag": "passive_charge",
    "terrain_cost_table": [1.0, 1.0, 1.5, 2.0, 3.0, 1.0],
    "class_direction_mult": [1.0, 1.1, 9.99]
  },
  "infantry": {
    "primary_stat": "stat_might", "secondary_stat": null,
    "w_primary": 1.0, "w_secondary": 0.0,
    "class_atk_mult": 0.9, "class_phys_def_mult": 1.3, "class_mag_def_mult": 0.8,
    "class_hp_mult": 1.3, "class_init_mult": 0.7, "class_move_delta": 0,
    "passive_tag": "passive_shield_wall",
    "terrain_cost_table": [1.0, 1.0, 1.0, 1.0, 1.5, 1.0],
    "class_direction_mult": [0.9, 1.0, 1.1]
  },
  "archer": {
    "primary_stat": "stat_might", "secondary_stat": "stat_agility",
    "w_primary": 0.6, "w_secondary": 0.4,
    "class_atk_mult": 1.0, "class_phys_def_mult": 0.7, "class_mag_def_mult": 0.9,
    "class_hp_mult": 0.8, "class_init_mult": 0.85, "class_move_delta": 0,
    "passive_tag": "passive_high_ground_shot",
    "terrain_cost_table": [1.0, 1.0, 1.0, 1.0, 2.0, 1.0],
    "class_direction_mult": [1.0, 1.375, 0.9]
  },
  "strategist": {
    "primary_stat": "stat_intellect", "secondary_stat": null,
    "w_primary": 1.0, "w_secondary": 0.0,
    "class_atk_mult": 1.0, "class_phys_def_mult": 0.5, "class_mag_def_mult": 1.2,
    "class_hp_mult": 0.7, "class_init_mult": 0.8, "class_move_delta": -1,
    "passive_tag": "passive_tactical_read",
    "terrain_cost_table": [1.0, 1.0, 1.5, 1.5, 2.0, 1.0],
    "class_direction_mult": [1.0, 1.0, 1.0]
  },
  "commander": {
    "primary_stat": "stat_command", "secondary_stat": "stat_might",
    "w_primary": 0.7, "w_secondary": 0.3,
    "class_atk_mult": 0.8, "class_phys_def_mult": 1.0, "class_mag_def_mult": 1.0,
    "class_hp_mult": 1.1, "class_init_mult": 0.75, "class_move_delta": 0,
    "passive_tag": "passive_rally",
    "terrain_cost_table": [1.0, 1.0, 1.0, 1.5, 2.0, 1.0],
    "class_direction_mult": [1.0, 1.0, 1.0]
  },
  "scout": {
    "primary_stat": "stat_agility", "secondary_stat": "stat_might",
    "w_primary": 0.6, "w_secondary": 0.4,
    "class_atk_mult": 1.05, "class_phys_def_mult": 0.6, "class_mag_def_mult": 0.6,
    "class_hp_mult": 0.75, "class_init_mult": 1.2, "class_move_delta": 1,
    "passive_tag": "passive_ambush",
    "terrain_cost_table": [1.0, 1.0, 1.0, 0.7, 1.5, 1.0],
    "class_direction_mult": [1.0, 1.0, 1.1]
  }
}"""
	var fixture_path: String = "user://unit_role_ac4_sentinel_fixture.json"
	var file: FileAccess = FileAccess.open(fixture_path, FileAccess.WRITE)
	assert_bool(file != null).override_failure_message(
		"AC-4: Failed to open fixture path for writing: " + fixture_path
	).is_true()
	file.store_string(fixture_json)
	file.close()

	# Act: load coefficients via DI path (bypasses production path; loads sentinel fixture).
	# _coefficients_loaded is already false from before_test(); call _load_coefficients directly.
	_ur_script.call("_load_coefficients", fixture_path)

	# Assert: sentinel 9.99 propagated from fixture JSON (proves unit_roles.json is runtime source)
	var result: float = UnitRole.get_class_direction_mult(UnitRole.UnitClass.CAVALRY, 2)
	assert_float(result).override_failure_message(
		("AC-4: CAVALRY REAR after sentinel-fixture load must be 9.99; got %.6f. "
		+ "Proves runtime source is unit_roles.json, NOT entities.yaml "
		+ "(BalanceConstants.get_const('CLASS_DIRECTION_MULT') would return the stale [4][3] value).")
		% result
	).is_equal_approx(9.99, 0.0001)

	# Cleanup: remove temp fixture file (after_test also resets the cache)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(fixture_path))


# ── AC-5: No BalanceConstants read in method body ────────────────────────────

## AC-5: get_class_direction_mult must NOT call BalanceConstants.get_const(...).
## Static source-file assertion — grep method body for "BalanceConstants" returns zero matches.
## Per ADR-0009 §6: runtime read goes through unit_roles.json for per-class data locality.
## Any future refactor adding a BalanceConstants read here breaks this test immediately.
func test_get_class_direction_mult_does_not_read_balance_constants() -> void:
	var content: String = FileAccess.get_file_as_string("res://src/foundation/unit_role.gd")
	# Locate the method signature line
	var method_start: int = content.find("func get_class_direction_mult(")
	assert_bool(method_start >= 0).override_failure_message(
		"AC-5: 'func get_class_direction_mult(' not found in src/foundation/unit_role.gd — method not implemented?"
	).is_true()
	# Extract up to 500 chars after the signature (comfortably covers the method body)
	var snippet: String = content.substr(method_start, 500)
	# Trim to the next top-level static func declaration (no leading tab) to isolate the body
	var next_func_pos: int = snippet.find("\nstatic func ", 10)
	if next_func_pos > 0:
		snippet = snippet.substr(0, next_func_pos)
	assert_bool(not snippet.contains("BalanceConstants")).override_failure_message(
		("AC-5 (ADR-0009 §6): get_class_direction_mult must NOT call BalanceConstants. "
		+ "Found 'BalanceConstants' in method body. "
		+ "Runtime read must go through unit_roles.json (per-class data locality).")
	).is_true()


# ── AC-6: STRATEGIST + COMMANDER no-op rows = all 1.0 ────────────────────────

## AC-6: STRATEGIST direction multipliers are all 1.0 by design.
## STRATEGIST class identity = Tactical Read evasion bypass — not direction-based damage scaling.
## Per ADR-0009 §6: "no-op rows by design". Any non-1.0 value here is a design violation.
func test_get_class_direction_mult_strategist_all_directions_are_1_0() -> void:
	var direction_names: Array[String] = ["FRONT", "FLANK", "REAR"]
	for dir: int in 3:
		var result: float = UnitRole.get_class_direction_mult(UnitRole.UnitClass.STRATEGIST, dir)
		assert_float(result).override_failure_message(
			("AC-6: STRATEGIST[%s] must be 1.0 (no-op row by design — class identity = "
			+ "Tactical Read evasion bypass, not direction scaling). Got %.6f.")
			% [direction_names[dir], result]
		).is_equal_approx(1.0, 0.0001)


## AC-6: COMMANDER direction multipliers are all 1.0 by design.
## COMMANDER class identity = Rally adjacency aura — not direction-based damage scaling.
## Per ADR-0009 §6: "no-op rows by design". Any non-1.0 value here is a design violation.
func test_get_class_direction_mult_commander_all_directions_are_1_0() -> void:
	var direction_names: Array[String] = ["FRONT", "FLANK", "REAR"]
	for dir: int in 3:
		var result: float = UnitRole.get_class_direction_mult(UnitRole.UnitClass.COMMANDER, dir)
		assert_float(result).override_failure_message(
			("AC-6: COMMANDER[%s] must be 1.0 (no-op row by design — class identity = "
			+ "Rally adjacency aura, not direction scaling). Got %.6f.")
			% [direction_names[dir], result]
		).is_equal_approx(1.0, 0.0001)
