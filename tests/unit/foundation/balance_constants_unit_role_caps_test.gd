## balance_constants_unit_role_caps_test.gd
## Story 007 — Unit-role global caps balance_entities.json append (8 keys).
## Verifies all 8 unit-role-related global caps resolve via BalanceConstants.get_const(key)
## per ADR-0009 §4 + ADR-0006 wrapper contract.
##
## ACs covered: AC-1 (8 caps return expected values) + AC-2 (no regression on pre-existing
## damage-calc + general caps) + AC-3 (data-driven per coding-standards.md "no hardcoded
## gameplay values").
##
## G-15 obligation: tests reset BalanceConstants._cache_loaded + _cache in before_test.
extends GdUnitTestSuite


const _BC_PATH: String = "res://src/feature/balance/balance_constants.gd"

## GDScript handle for static-state isolation per G-15.
var _bc_script: GDScript = load(_BC_PATH)


func before_test() -> void:
	# G-15: reset BalanceConstants static state to force fresh load per test
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})


func after_test() -> void:
	# Idempotent cleanup — safe even if test never triggered the lazy-load
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})


# ── AC-1: 8 unit-role-related caps return expected values ──────────────────


## AC-1: HP_CAP returns int 300 per ADR-0009 §4 + GDD §Global Constant Summary.
func test_hp_cap_returns_300() -> void:
	var actual: int = BalanceConstants.get_const("HP_CAP") as int
	assert_int(actual).override_failure_message(
		"AC-1: BalanceConstants.get_const('HP_CAP') expected 300; got %d" % actual
	).is_equal(300)


## AC-1: HP_SCALE returns float 2.0 per ADR-0009 §4 (consumed by F-3 max_hp).
func test_hp_scale_returns_2_0() -> void:
	var actual: float = BalanceConstants.get_const("HP_SCALE") as float
	assert_float(actual).override_failure_message(
		"AC-1: BalanceConstants.get_const('HP_SCALE') expected 2.0; got %f" % actual
	).is_equal(2.0)


## AC-1: HP_FLOOR returns int 50 per ADR-0009 §4 (consumed by F-3 max_hp; EC-14 boundary).
func test_hp_floor_returns_50() -> void:
	var actual: int = BalanceConstants.get_const("HP_FLOOR") as int
	assert_int(actual).override_failure_message(
		"AC-1: BalanceConstants.get_const('HP_FLOOR') expected 50; got %d" % actual
	).is_equal(50)


## AC-1: INIT_CAP returns int 200 per ADR-0009 §4 (consumed by F-4 initiative).
func test_init_cap_returns_200() -> void:
	var actual: int = BalanceConstants.get_const("INIT_CAP") as int
	assert_int(actual).override_failure_message(
		"AC-1: BalanceConstants.get_const('INIT_CAP') expected 200; got %d" % actual
	).is_equal(200)


## AC-1: INIT_SCALE returns float 2.0 per ADR-0009 §4 (consumed by F-4 initiative).
func test_init_scale_returns_2_0() -> void:
	var actual: float = BalanceConstants.get_const("INIT_SCALE") as float
	assert_float(actual).override_failure_message(
		"AC-1: BalanceConstants.get_const('INIT_SCALE') expected 2.0; got %f" % actual
	).is_equal(2.0)


## AC-1: MOVE_RANGE_MIN returns int 2 per ADR-0009 §4 (F-5 floor; EC-1 Strategist absorption).
func test_move_range_min_returns_2() -> void:
	var actual: int = BalanceConstants.get_const("MOVE_RANGE_MIN") as int
	assert_int(actual).override_failure_message(
		"AC-1: BalanceConstants.get_const('MOVE_RANGE_MIN') expected 2; got %d" % actual
	).is_equal(2)


## AC-1: MOVE_RANGE_MAX returns int 6 per ADR-0009 §4 (F-5 cap; EC-2 Cavalry absorption).
func test_move_range_max_returns_6() -> void:
	var actual: int = BalanceConstants.get_const("MOVE_RANGE_MAX") as int
	assert_int(actual).override_failure_message(
		"AC-1: BalanceConstants.get_const('MOVE_RANGE_MAX') expected 6; got %d" % actual
	).is_equal(6)


## AC-1: MOVE_BUDGET_PER_RANGE returns int 10 per ADR-0009 §Migration Plan §4.
## Cross-doc obligation closure: `move_budget = effective_move_range × MOVE_BUDGET_PER_RANGE`
## is a consumer-side compute (Grid Battle); UnitRole exposes get_effective_move_range only.
func test_move_budget_per_range_returns_10() -> void:
	var actual: int = BalanceConstants.get_const("MOVE_BUDGET_PER_RANGE") as int
	assert_int(actual).override_failure_message(
		"AC-1: BalanceConstants.get_const('MOVE_BUDGET_PER_RANGE') expected 10; got %d" % actual
	).is_equal(10)


# ── AC-2: No regression on pre-existing scalar caps ────────────────────────


## AC-2: 4 pre-existing scalar caps still resolve correctly (regression check).
## Existing balance_constants_test.gd covers these in detail; this is a smoke
## check ensuring the 8-key append did not break the JSON parse or shift values.
func test_pre_existing_caps_no_regression() -> void:
	# ATK_CAP — pre-existing damage-calc + unit-role consumer
	assert_int(BalanceConstants.get_const("ATK_CAP") as int).override_failure_message(
		"AC-2: ATK_CAP regression — expected 200"
	).is_equal(200)

	# DEF_CAP — pre-existing damage-calc + unit-role consumer
	assert_int(BalanceConstants.get_const("DEF_CAP") as int).override_failure_message(
		"AC-2: DEF_CAP regression — expected 105"
	).is_equal(105)

	# BASE_CEILING — pre-existing damage-calc consumer
	assert_int(BalanceConstants.get_const("BASE_CEILING") as int).override_failure_message(
		"AC-2: BASE_CEILING regression — expected 83"
	).is_equal(83)

	# DAMAGE_CEILING — pre-existing damage-calc consumer
	assert_int(BalanceConstants.get_const("DAMAGE_CEILING") as int).override_failure_message(
		"AC-2: DAMAGE_CEILING regression — expected 180"
	).is_equal(180)


# ── AC-3: Data-driven (no hardcoded gameplay values in src/foundation/) ────


## AC-3: BalanceConstants is the single read path; no hardcoded literals
## matching cap values exist in src/foundation/unit_role.gd. (Story 010 will
## codify this as a CI lint script; this test is a smoke check.)
func test_balance_constants_is_single_read_path() -> void:
	# Smoke check: verify the wrapper exists and responds correctly.
	# Story 010 will add the static-lint script for hardcoded-value detection.
	var sentinel: Variant = BalanceConstants.get_const("HP_CAP")
	assert_bool(sentinel != null).override_failure_message(
		"AC-3: BalanceConstants.get_const must return non-null for shipped keys"
	).is_true()
