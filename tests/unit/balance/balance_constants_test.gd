## Unit tests for BalanceConstants — provisional JSON wrapper for tuning constants.
## Covers story-006b: AC-1 (wrapper shape), AC-2 (all 12 keys), AC-7 (string-key handling).
## Story-002 extensions: AC-1 all-keys expansion (18 scalar+dict), TR annotations,
## AC-3 (file-exists precheck behaviour doc), AC-4 (idempotent-guard two-call hardening),
## AC-5 (cross-suite isolation canary).
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
# AC-5 / TR-balance-data-020 — cross-suite isolation canary
# ---------------------------------------------------------------------------

## AC-5 / TR-balance-data-020 — isolation canary:
## On entry to every test (after before_test() runs), _cache_loaded MUST be false
## and _cache MUST be empty. This meta-test protects against G-15 violations
## (e.g., before_test() renamed to before_each()) and against future state-reset
## logic regressions. If before_test() ever drifts, this test fails first.
## It is listed first so it runs before any state-mutating test in this suite.
func test_get_const_pre_test_state_resets_static_vars() -> void:
	# Assert preconditions — before_test() must have run before we get here
	var cache_loaded: bool = _bc_script.get("_cache_loaded") as bool
	var cache: Dictionary = _bc_script.get("_cache") as Dictionary

	assert_bool(cache_loaded).override_failure_message(
			("AC-5/TR-020 canary: _cache_loaded must be false on test entry — "
			+ "before_test() did not reset it (check for G-15 before_each typo)")
	).is_false()
	assert_bool(cache.is_empty()).override_failure_message(
			("AC-5/TR-020 canary: _cache must be empty on test entry — "
			+ "before_test() did not reset it (check for G-15 before_each typo)")
	).is_true()


# ---------------------------------------------------------------------------
# AC-1 / AC-2 — wrapper shape + lazy-load
# ---------------------------------------------------------------------------

## TR-balance-data-019: AC-1 / lazy-load fires on first call:
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


## TR-balance-data-019: AC-1 / cache is stable: second get_const() call returns the same value without re-parsing.
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
# AC-2 / TR-balance-data-007 — all 18 top-level keys return expected values
# ---------------------------------------------------------------------------

## TR-balance-data-007: AC-2 scalar keys: all 18 scalar constants match entities.json values.
## Post-ADR-0010 + ADR-0011 same-patch appends added HP_CAP, HP_SCALE, HP_FLOOR,
## INIT_CAP, INIT_SCALE, MOVE_RANGE_MIN, MOVE_RANGE_MAX, MOVE_BUDGET_PER_RANGE (8 new).
## JSON delivers all numbers as floats. Integer-valued constants (BASE_CEILING=83, etc.)
## are exactly representable in IEEE-754 → 0.001 tolerance is a defensive choice.
## Non-integer fractions (0.40, 1.31, 1.20, 1.15, 0.5, 2.0) use 0.0001 to pin exact value.
## AC-1 guard: assert cases.size() >= total scalar key count to catch future JSON additions.
func test_get_const_all_scalar_keys_return_expected_values() -> void:
	# Each entry: [key, expected_value, tolerance].
	var cases: Array[Dictionary] = [
		{"key": "BASE_CEILING",              "expected": 83.0,  "tol": 0.001},
		{"key": "MIN_DAMAGE",                "expected": 1.0,   "tol": 0.001},
		{"key": "ATK_CAP",                   "expected": 200.0, "tol": 0.001},
		{"key": "DEF_CAP",                   "expected": 105.0, "tol": 0.001},
		{"key": "DEFEND_STANCE_ATK_PENALTY", "expected": 0.40,  "tol": 0.0001},
		{"key": "P_MULT_COMBINED_CAP",       "expected": 1.31,  "tol": 0.0001},
		{"key": "CHARGE_BONUS",              "expected": 1.20,  "tol": 0.0001},
		{"key": "AMBUSH_BONUS",              "expected": 1.15,  "tol": 0.0001},
		{"key": "DAMAGE_CEILING",            "expected": 180.0, "tol": 0.001},
		{"key": "COUNTER_ATTACK_MODIFIER",   "expected": 0.5,   "tol": 0.0001},
		# ADR-0010 HP/Status same-patch appends
		{"key": "HP_CAP",                    "expected": 300.0, "tol": 0.001},
		{"key": "HP_SCALE",                  "expected": 2.0,   "tol": 0.0001},
		{"key": "HP_FLOOR",                  "expected": 50.0,  "tol": 0.001},
		# ADR-0011 Turn Order same-patch appends
		{"key": "INIT_CAP",                  "expected": 200.0, "tol": 0.001},
		{"key": "INIT_SCALE",                "expected": 2.0,   "tol": 0.0001},
		{"key": "MOVE_RANGE_MIN",            "expected": 2.0,   "tol": 0.001},
		{"key": "MOVE_RANGE_MAX",            "expected": 6.0,   "tol": 0.001},
		{"key": "MOVE_BUDGET_PER_RANGE",     "expected": 10.0,  "tol": 0.001},
	]

	# AC-1 count guard: if JSON gains new scalar keys, this assertion fails first,
	# forcing the test author to expand the cases table before the regression passes.
	assert_int(cases.size()).override_failure_message(
			("AC-1 count guard: expected >= 18 scalar cases (10 original + 8 post-ADR-0010/0011); "
			+ "got %d — update cases table if balance_entities.json added new scalar keys")
			% cases.size()
	).is_greater_equal(18)

	for case: Dictionary in cases:
		var key: String = case["key"] as String
		var expected: float = case["expected"] as float
		var tol: float = case["tol"] as float
		var result: Variant = BalanceConstants.get_const(key)
		assert_float(result as float).override_failure_message(
				("AC-2 scalar: key='%s' expected=%f got=%f")
				% [key, expected, result as float]
		).is_equal_approx(expected, tol)


## TR-balance-data-007: AC-2 dict keys: BASE_DIRECTION_MULT and CLASS_DIRECTION_MULT return Dictionaries.
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

## TR-balance-data-007: AC-2 / unknown key: get_const("NONEXISTENT_KEY") returns null.
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
# GAP-1 / TR-balance-data-019 — stable-empty-cache contract
# ---------------------------------------------------------------------------

## TR-balance-data-019: Pins the graceful-degradation contract from `_load_cache()`:
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
# AC-4 / TR-balance-data-019 — idempotent-guard two-call hardening
# ---------------------------------------------------------------------------

## TR-balance-data-019: AC-4 / idempotent-guard hardening — two successive get_const() calls
## in post-failure state both return null AND leave _cache empty (proving _load_cache() was
## NOT re-invoked between them). Extends the stable-empty-cache contract to verify the guard
## holds for multiple consecutive calls, guarding against future regressions where the guard
## might short-circuit only on the first re-entry attempt.
func test_get_const_failed_parse_does_not_re_attempt() -> void:
	# Arrange — simulate post-failure state (same as GAP-1 test above)
	_bc_script.set("_cache", {})
	_bc_script.set("_cache_loaded", true)

	# Act — call get_const() TWICE in succession
	var result_1: Variant = BalanceConstants.get_const("CHARGE_BONUS")
	var result_2: Variant = BalanceConstants.get_const("BASE_CEILING")

	# Assert first call
	assert_bool(result_1 == null).override_failure_message(
			"AC-4: first get_const() after simulated failed parse must return null"
	).is_true()
	# Assert second call — same guard must hold on the second call
	assert_bool(result_2 == null).override_failure_message(
			"AC-4: second get_const() after simulated failed parse must return null"
	).is_true()
	# Assert _cache is still empty — proves _load_cache() was not re-invoked
	assert_bool((_bc_script.get("_cache") as Dictionary).is_empty()).override_failure_message(
			("AC-4: _cache must remain empty after two get_const() calls on an empty-loaded cache — "
			+ "if non-empty, _load_cache() was re-invoked (disk-hammering regression)")
	).is_true()
	# Assert _cache_loaded stayed true throughout
	assert_bool(_bc_script.get("_cache_loaded") as bool).override_failure_message(
			"AC-4: _cache_loaded must remain true after both calls (guard must not reset)"
	).is_true()


# ---------------------------------------------------------------------------
# AC-3 / TR-balance-data-013 — file-exists precheck behaviour documentation
# ---------------------------------------------------------------------------

## TR-balance-data-013: AC-3 / file-exists precheck — documents the MVP behaviour:
## `_load_cache()` uses `raw.is_empty()` to detect both "file not found" and "empty file"
## as a SINGLE code path (no `FileAccess.file_exists()` precheck).
## The production file at `_ENTITIES_JSON_PATH` is reachable, so this test verifies the
## POSITIVE path: a valid JSON parse produces a non-empty cache and sets _cache_loaded=true.
##
## TODO TR-013: the godot-gdscript-specialist Item 4 advisory recommends adding a
## `FileAccess.file_exists()` precheck to separate "file not found" (path wrong, deployment
## gap) from "empty file" (corrupt write, file truncation) with distinct push_error messages.
## The refactor is deferred: implement in a follow-up story (see EPIC.md Out of Scope).
## The current single-message path (`raw.is_empty()` check) is acceptable for MVP per
## ADR-0006 §Risks R-2 + TR-013 PARTIAL-Alpha-deferred status.
func test_get_const_file_exists_precheck_diagnostic_separation() -> void:
	# Arrange — before_test() has reset _cache_loaded=false and _cache={}

	# Act — trigger lazy-load against the real file (must be present in test environment)
	var result: Variant = BalanceConstants.get_const("BASE_CEILING")

	# Assert — positive path: real file is found, parsed, cached correctly.
	# Documents that `_load_cache()` uses the `raw.is_empty()` single-path check,
	# NOT a `FileAccess.file_exists()` precheck. If the TODO above is implemented,
	# this test still passes (precheck is transparent to the happy path).
	assert_bool(_bc_script.get("_cache_loaded") as bool).override_failure_message(
			("AC-3/TR-013: _cache_loaded must be true after successful load — "
			+ "if false, _load_cache() failed to set the flag (regression)")
	).is_true()
	assert_bool(result != null).override_failure_message(
			("AC-3/TR-013: BASE_CEILING must return non-null from the real file — "
			+ "if null, the JSON parse failed or the file is missing in the test environment")
	).is_true()
	assert_float(result as float).override_failure_message(
			"AC-3/TR-013: BASE_CEILING should return 83.0 (no precheck changes the happy path)"
	).is_equal_approx(83.0, 0.001)
	# Document the current MVP behaviour: the cache is non-empty after a successful load,
	# meaning no precheck was required to reach the `if parsed is Dictionary` branch.
	assert_bool(not (_bc_script.get("_cache") as Dictionary).is_empty()).override_failure_message(
			("AC-3/TR-013: _cache must be non-empty after successful parse — "
			+ "empty cache here indicates _load_cache() failed silently")
	).is_true()


# ---------------------------------------------------------------------------
# AC-7 / TR-balance-data-007 — CLASS_DIRECTION_MULT string-key handling
# ---------------------------------------------------------------------------

## TR-balance-data-007: AC-7: CLASS_DIRECTION_MULT outer keys are JSON strings ("0", "1", "2", "3").
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
	var cases: Array[Dictionary] = [
		{"cls": "0", "dir": "FRONT", "expected": 1.00},    # CAVALRY FRONT
		{"cls": "0", "dir": "FLANK", "expected": 1.05},    # CAVALRY FLANK
		{"cls": "0", "dir": "REAR",  "expected": 1.09},    # CAVALRY REAR
		{"cls": "1", "dir": "FRONT", "expected": 1.00},    # SCOUT FRONT
		{"cls": "1", "dir": "FLANK", "expected": 1.00},    # SCOUT FLANK
		{"cls": "1", "dir": "REAR",  "expected": 1.00},    # SCOUT REAR
		{"cls": "2", "dir": "FRONT", "expected": 0.90},    # INFANTRY FRONT
		{"cls": "2", "dir": "FLANK", "expected": 1.00},    # INFANTRY FLANK
		{"cls": "2", "dir": "REAR",  "expected": 1.00},    # INFANTRY REAR
		{"cls": "3", "dir": "FRONT", "expected": 1.00},    # ARCHER FRONT
		{"cls": "3", "dir": "FLANK", "expected": 1.375},   # ARCHER FLANK (BLK-7-9/10 Pillar-3 parity)
		{"cls": "3", "dir": "REAR",  "expected": 1.00},    # ARCHER REAR
	]
	for case: Dictionary in cases:
		var cls_key: String = case["cls"] as String
		var dir_key: String = case["dir"] as String
		var expected: float = case["expected"] as float
		var inner: Dictionary = cdm[cls_key] as Dictionary
		var actual: float = inner[dir_key] as float
		assert_float(actual).override_failure_message(
				("AC-7: CLASS_DIRECTION_MULT[\"%s\"][\"%s\"] expected=%f got=%f")
				% [cls_key, dir_key, expected, actual]
		).is_equal_approx(expected, 0.0001)
