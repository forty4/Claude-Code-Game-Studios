## Perf tests for BalanceConstants — lazy-load first-call cost + 10k cached-call throughput.
## Covers balance-data/story-005: AC-1 (TR-balance-data-015(a)) + AC-2 (TR-balance-data-015(b)).
## ADR reference: ADR-0006 §Performance Implications (lazy-load ~0.5-2ms; O(1) hash lookups).
## No scene-tree dependency — extends GdUnitTestSuite (RefCounted-based).
##
## ADR-0006 §Decision 1: BalanceConstants is a static utility class with class_name access,
## NOT an autoload. Cache reset via reflection (G-15 + ADR-0006 §Decision 6) mandatory in before_test.
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## AC-1 budget: first-call lazy-load must complete under 2ms (2000us) on headless CI.
## Threshold includes CI variance headroom (mirrors damage-calc story-010 conservative-threshold practice).
const _LAZY_LOAD_BUDGET_US: int = 2000

## AC-2 budget: 10,000 cached get_const() calls must complete under 500ms (500,000us) total.
## Per-call amortised budget: < 50us avg.
const _THROUGHPUT_CALL_COUNT: int = 10_000
const _THROUGHPUT_BUDGET_US: int = 500_000


# ---------------------------------------------------------------------------
# Shared fixtures
# ---------------------------------------------------------------------------

## GDScript handle for cache reset reflection (G-15 + ADR-0006 §Decision 6).
var _bc_script: GDScript = load("res://src/foundation/balance/balance_constants.gd")


# ---------------------------------------------------------------------------
# Lifecycle hooks (G-15: before_test / after_test only — before_each is silently ignored)
# ---------------------------------------------------------------------------

## Resets BalanceConstants static cache before each test for cold-cache isolation.
## Required for AC-1: without this, the cache populated by a prior test would skip
## _load_cache(), and AC-1 would measure cache-hit cost instead of cold-cache first-call.
func before_test() -> void:
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})


## Restores BalanceConstants cache to pristine state after each test.
func after_test() -> void:
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})


# ---------------------------------------------------------------------------
# AC-1 / TR-balance-data-015(a) — lazy-load first-call cost under 2ms
# ---------------------------------------------------------------------------

## TR-balance-data-015(a): AC-1 / lazy-load first-call cost.
## Given a cold cache (reset by before_test()), a single get_const() call triggers
## _load_cache() (FileAccess.get_file_as_string + JSON.parse_string for balance_entities.json).
## The total elapsed time must be under 2000us (2ms) on headless CI.
## Note: warm-up effect — if this is the first test in the suite, GDScript JIT warm-up
## may affect timing; the threshold is conservative enough to absorb this variance.
func test_get_const_first_call_lazy_load_cost_under_2ms() -> void:
	# Arrange — before_test() has set _cache_loaded=false, _cache={} (cold cache)
	var start_us: int = Time.get_ticks_usec()

	# Act — single get_const call triggers _load_cache() (cold-cache path)
	var _result: Variant = BalanceConstants.get_const("CHARGE_BONUS")

	# Assert
	var elapsed_us: int = Time.get_ticks_usec() - start_us
	assert_int(elapsed_us).override_failure_message(
		("AC-1 (TR-015(a)): lazy-load first-call cost %d us exceeds %d us target (2ms). "
		+ "Check CI runner load or balance_entities.json file size growth.")
		% [elapsed_us, _LAZY_LOAD_BUDGET_US]
	).is_less(_LAZY_LOAD_BUDGET_US)


# ---------------------------------------------------------------------------
# AC-2 / TR-balance-data-015(b) — 10k cached-call throughput under 500ms
# ---------------------------------------------------------------------------

## TR-balance-data-015(b): AC-2 / 10k cached-call throughput.
## Given a pre-warmed cache (post-load), 10,000 get_const() calls cycling through
## 10 different keys must complete in under 500,000us (500ms) total.
## Different keys defeat any branch-predictor short-circuit and exercise the
## Dictionary lookup hot path per ADR-0006 §Architecture Diagram.
## Per-call amortised budget: < 50us avg.
func test_get_const_cached_call_throughput_10k_under_500ms() -> void:
	# Arrange — pre-load cache to isolate hot-path cost from lazy-load cost
	var _warmup: Variant = BalanceConstants.get_const("CHARGE_BONUS")

	# 10 different REAL scalar keys from balance_entities.json (verified 2026-05-01)
	var keys: Array[String] = [
		"BASE_CEILING", "MIN_DAMAGE", "ATK_CAP",
		"DEF_CAP", "DEFEND_STANCE_ATK_PENALTY",
		"P_MULT_COMBINED_CAP", "CHARGE_BONUS",
		"AMBUSH_BONUS", "DAMAGE_CEILING",
		"COUNTER_ATTACK_MODIFIER",
	]

	# Act — timed section; only the loop is inside the timed window
	var start_us: int = Time.get_ticks_usec()
	for i: int in _THROUGHPUT_CALL_COUNT:
		var _v: Variant = BalanceConstants.get_const(keys[i % keys.size()])
	var elapsed_us: int = Time.get_ticks_usec() - start_us

	# Assert
	assert_int(elapsed_us).override_failure_message(
		("AC-2 (TR-015(b)): 10k cached calls took %d us (budget: %d us). "
		+ "Per-call avg: %d us (budget: < 50 us). "
		+ "Check CI runner load or unexpected _load_cache() re-invocation.")
		% [elapsed_us, _THROUGHPUT_BUDGET_US, elapsed_us / _THROUGHPUT_CALL_COUNT]
	).is_less(_THROUGHPUT_BUDGET_US)
