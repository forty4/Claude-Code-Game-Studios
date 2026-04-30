## Unit tests for BalanceConstants — provisional JSON wrapper for tuning constants.
## Covers story-006b: AC-1 (wrapper shape), AC-2 (all 12 keys), AC-7 (string-key handling).
## Also covers wrapper unit contracts: lazy-load fires once, cache is stable,
## unknown key returns null, CLASS_DIRECTION_MULT string-key lookup per AC-7.
## No scene-tree dependency — extends GdUnitTestSuite (RefCounted-based).
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Constants + shared state
# ---------------------------------------------------------------------------

const _BALANCE_CONSTANTS_PATH: String = "res://src/foundation/balance/balance_constants.gd"

## GDScript handle used to read/write static vars for test isolation.
## Loaded once at class init; reused in before_test/after_test.
var _bc_script: GDScript = load(_BALANCE_CONSTANTS_PATH)


# ---------------------------------------------------------------------------
# Per-test lifecycle (G-15 — before_test, not before_each)
# ---------------------------------------------------------------------------

## Resets BalanceConstants static state before every test.
## Required: without this, a prior test's lazy-loaded cache bleeds into the next test,
## and mock-cache tests would never re-trigger the JSON parse path (ADR-0008 precedent).
func before_test() -> void:
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})


## Restores BalanceConstants static state after every test.
## Acts as a safety net in case a test exits early via assertion failure after
## setting _cache_loaded=true with a mock dict.
func after_test() -> void:
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})


# ---------------------------------------------------------------------------
# AC-1 / AC-2 — wrapper shape + lazy-load
# ---------------------------------------------------------------------------

## AC-1 / lazy-load fires on first call:
## Before the first get_const() call, _cache_loaded must be false (reset by before_test).
## After the call, _cache_loaded must be true and the returned value must match entities.json.
func test_get_const_lazy_load_fires_on_first_call() -> void:
	# Arrange — before_test() has set _cache_loaded=false
	var cache_loaded_before: bool = _bc_script.get("_cache_loaded") as bool

	# Act
	var result: Variant = BalanceConstants.get_const("CHARGE_BONUS")

	# Assert
	assert_bool(cache_loaded_before).override_failure_message(
			"AC-1: _cache_loaded should be false before first get_const() call"
	).is_false()
	assert_bool(_bc_script.get("_cache_loaded") as bool).override_failure_message(
			"AC-1: _cache_loaded should be true after get_const() fires the lazy-load"
	).is_true()
	assert_float(result as float).override_failure_message(
			"AC-1: CHARGE_BONUS should return 1.20 from entities.json"
	).is_equal_approx(1.20, 0.001)


## AC-1 / cache is stable: second get_const() call returns the same value without re-parsing.
## Verified by: first call loads; then manually mutate _cache to a sentinel value;
## second call returns the mutated value (proving it read from cache, not re-parsed the file).
func test_get_const_caches_after_first_call_no_reparse() -> void:
	# Arrange — trigger initial load
	var _initial: Variant = BalanceConstants.get_const("CHARGE_BONUS")

	# Mutate cache directly with a sentinel value to prove re-parse doesn't clobber it
	var mutated_cache: Dictionary = _bc_script.get("_cache") as Dictionary
	mutated_cache["CHARGE_BONUS"] = 999.0
	_bc_script.set("_cache", mutated_cache)

	# Act — second call must return the mutated cache value, not 1.20 from file
	var result: Variant = BalanceConstants.get_const("CHARGE_BONUS")

	# Assert
	assert_float(result as float).override_failure_message(
			("cache test: expected 999.0 (mutated sentinel), got %f"
			+ " — if 1.20, cache was re-parsed instead of read from _cache")
			% (result as float)
	).is_equal_approx(999.0, 0.001)


# ---------------------------------------------------------------------------
# AC-2 — all 12 keys return expected values
# ---------------------------------------------------------------------------

## AC-2 scalar keys: all 10 scalar constants match entities.json values.
func test_get_const_all_scalar_keys_return_expected_values() -> void:
	# Each pair: [key, expected_value, tolerance].
	# JSON delivers all numbers as floats. Integer-valued constants (BASE_CEILING=83, etc.)
	# are exactly representable in IEEE-754 → 0.001 tolerance is a defensive choice (not strictly
	# required for ints; the loose tolerance also tolerates a future re-tune of ±1 if needed).
	# Non-integer fractions (0.40, 1.31, 1.20, 1.15, 0.5) use 0.0001 to pin the exact balance value.
	var cases: Array = [
		["BASE_CEILING",             83.0,  0.001],
		["MIN_DAMAGE",                1.0,  0.001],
		["ATK_CAP",                 200.0,  0.001],
		["DEF_CAP",                 105.0,  0.001],
		["DEFEND_STANCE_ATK_PENALTY", 0.40, 0.0001],
		["P_MULT_COMBINED_CAP",       1.31, 0.0001],
		["CHARGE_BONUS",              1.20, 0.0001],
		["AMBUSH_BONUS",              1.15, 0.0001],
		["DAMAGE_CEILING",          180.0,  0.001],
		["COUNTER_ATTACK_MODIFIER",   0.5,  0.0001],
	]
	for entry: Array in cases:
		var key: String = entry[0] as String
		var expected: float = entry[1] as float
		var tol: float = entry[2] as float
		var result: Variant = BalanceConstants.get_const(key)
		assert_float(result as float).override_failure_message(
				("AC-2 scalar: key='%s' expected=%f got=%f")
				% [key, expected, result as float]
		).is_equal_approx(expected, tol)


## AC-2 dict keys: BASE_DIRECTION_MULT and CLASS_DIRECTION_MULT return Dictionaries.
func test_get_const_direction_mult_keys_return_dictionaries() -> void:
	var base_dir: Variant = BalanceConstants.get_const("BASE_DIRECTION_MULT")
	var class_dir: Variant = BalanceConstants.get_const("CLASS_DIRECTION_MULT")

	assert_bool(base_dir is Dictionary).override_failure_message(
			"AC-2: BASE_DIRECTION_MULT should return a Dictionary"
	).is_true()
	assert_bool(class_dir is Dictionary).override_failure_message(
			"AC-2: CLASS_DIRECTION_MULT should return a Dictionary"
	).is_true()

	# Spot-check BASE_DIRECTION_MULT inner values
	var bdm: Dictionary = base_dir as Dictionary
	assert_float(bdm["REAR"] as float).override_failure_message(
			"AC-2: BASE_DIRECTION_MULT[REAR] should be 1.50"
	).is_equal_approx(1.50, 0.0001)
	assert_float(bdm["FLANK"] as float).override_failure_message(
			"AC-2: BASE_DIRECTION_MULT[FLANK] should be 1.20"
	).is_equal_approx(1.20, 0.0001)
	assert_float(bdm["FRONT"] as float).override_failure_message(
			"AC-2: BASE_DIRECTION_MULT[FRONT] should be 1.00"
	).is_equal_approx(1.00, 0.0001)


# ---------------------------------------------------------------------------
# AC-2 / unknown key — null return + push_error (observable as null return)
# ---------------------------------------------------------------------------

## AC-2 / unknown key: get_const("NONEXISTENT_KEY") returns null.
## push_error fires as a side-effect (observable in the test log; not assertable in GdUnit4).
## The null return is the assertable contract.
func test_get_const_unknown_key_returns_null() -> void:
	# Act
	var result: Variant = BalanceConstants.get_const("NONEXISTENT_KEY")

	# Assert
	assert_bool(result == null).override_failure_message(
			"AC-2/unknown: expected null for missing key, got non-null"
	).is_true()


# ---------------------------------------------------------------------------
# Stable-empty-cache contract (GAP-1 from /code-review qa-tester)
# ---------------------------------------------------------------------------

## Pins the graceful-degradation contract from `_load_cache()`:
## when `_cache_loaded == true` and `_cache == {}` (the post-failure state),
## subsequent get_const() calls return null without re-attempting the parse.
## This catches a future regression where someone moves `_cache_loaded = true`
## inside the `if parsed is Dictionary` branch (which would re-enable disk
## hammering on every failed-load call).
func test_get_const_stable_empty_cache_after_failure_returns_null_no_reparse() -> void:
	# Arrange — simulate the post-failure state: cache marked loaded but empty.
	# This is exactly what `_load_cache()` leaves behind when the JSON file is missing
	# or malformed. before_test() set _cache={} and _cache_loaded=false; we now flip
	# _cache_loaded=true to bypass the lazy-load path entirely.
	_bc_script.set("_cache", {})
	_bc_script.set("_cache_loaded", true)

	# Act — query any key. The lazy-load guard skips re-parse; the missing-key path fires.
	var result: Variant = BalanceConstants.get_const("CHARGE_BONUS")

	# Assert — null returned (key absent from the empty cache); _cache_loaded stays true
	# (no re-parse attempted, which is the contract).
	assert_bool(result == null).override_failure_message(
			"GAP-1: get_const must return null when _cache is empty + _cache_loaded is true"
	).is_true()
	assert_bool(_bc_script.get("_cache_loaded") as bool).override_failure_message(
			("GAP-1: _cache_loaded must remain true after a missing-key call on an empty cache "
			+ "— if false, a future caller would trigger re-parse (disk-hammering regression)")
	).is_true()


# ---------------------------------------------------------------------------
# AC-7 — CLASS_DIRECTION_MULT string-key handling
# ---------------------------------------------------------------------------

## AC-7: CLASS_DIRECTION_MULT outer keys are JSON strings ("0", "1", "2", "3").
## All 4 unit classes × all 3 directions must resolve to the correct D_mult.
## This test pins the string-key contract at the wrapper level — the call site in
## damage_calc.gd uses str(unit_class) to perform the lookup (approved design decision).
func test_get_const_class_direction_mult_all_classes_all_directions() -> void:
	var cdm: Dictionary = BalanceConstants.get_const("CLASS_DIRECTION_MULT") as Dictionary

	# Verify all 4 outer string keys exist
	for class_key: String in ["0", "1", "2", "3"]:
		assert_bool(cdm.has(class_key)).override_failure_message(
				"AC-7: CLASS_DIRECTION_MULT missing outer key '%s'" % class_key
		).is_true()

	# Expected values per entities.json schema
	# [class_string_key, direction_string, expected_mult]
	var cases: Array = [
		["0", "FRONT", 1.00],   # CAVALRY FRONT
		["0", "FLANK", 1.05],   # CAVALRY FLANK
		["0", "REAR",  1.09],   # CAVALRY REAR
		["1", "FRONT", 1.00],   # SCOUT FRONT
		["1", "FLANK", 1.00],   # SCOUT FLANK
		["1", "REAR",  1.00],   # SCOUT REAR
		["2", "FRONT", 0.90],   # INFANTRY FRONT
		["2", "FLANK", 1.00],   # INFANTRY FLANK
		["2", "REAR",  1.00],   # INFANTRY REAR
		["3", "FRONT", 1.00],   # ARCHER FRONT
		["3", "FLANK", 1.375],  # ARCHER FLANK (BLK-7-9/10 Pillar-3 parity)
		["3", "REAR",  1.00],   # ARCHER REAR
	]
	for entry: Array in cases:
		var cls_key: String = entry[0] as String
		var dir_key: String = entry[1] as String
		var expected: float = entry[2] as float
		var inner: Dictionary = cdm[cls_key] as Dictionary
		var actual: float = inner[dir_key] as float
		assert_float(actual).override_failure_message(
				("AC-7: CLASS_DIRECTION_MULT[\"%s\"][\"%s\"] expected=%f got=%f")
				% [cls_key, dir_key, expected, actual]
		).is_equal_approx(expected, 0.0001)
