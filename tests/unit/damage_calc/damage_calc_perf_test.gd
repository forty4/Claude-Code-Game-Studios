## Perf test for DamageCalc.resolve() CI throughput — AC-DC-40(a).
## Covers story-010 (Performance baseline — headless CI throughput).
## No scene-tree dependency — extends GdUnitTestSuite (RefCounted-based).
extends GdUnitTestSuite


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

## Budget: 10,000 resolve() calls must complete in under 500ms on a Linux
## headless CI runner (50µs avg per call). Vertical Slice blocker per ADR-0012 R-2.
const _CALL_COUNT: int = 10_000
const _BUDGET_MS: int = 500


# ---------------------------------------------------------------------------
# Shared fixtures
# ---------------------------------------------------------------------------

var _balance_constants_script: GDScript = load("res://src/foundation/balance/balance_constants.gd")


# ---------------------------------------------------------------------------
# Lifecycle hooks (G-15: before_test / after_test only)
# ---------------------------------------------------------------------------

## Resets BalanceConstants static cache before each test for isolation (G-15 + story-006b).
func before_test() -> void:
	_balance_constants_script.set("_cache_loaded", false)
	_balance_constants_script.set("_cache", {})


## Restores BalanceConstants cache to pristine state after each test.
func after_test() -> void:
	_balance_constants_script.set("_cache_loaded", false)
	_balance_constants_script.set("_cache", {})


# ---------------------------------------------------------------------------
# AC-DC-40(a) — headless CI throughput: 10,000 calls < 500ms
# ---------------------------------------------------------------------------

## AC-1 (AC-DC-40(a) headless CI throughput):
## Given 10,000 resolve() calls in a tight loop on a Linux headless runner,
## the wall-clock total must be under 500ms (50µs avg per call).
## This is a regression gate — CI fails merge if budget is exceeded.
func test_perf_resolve_throughput_ci_under_budget() -> void:
	# Arrange — construct contexts OUTSIDE the timed loop (AC-DC-41: no Dict
	# allocs inside the hot path; wrapper allocations here are amortised).
	var atk: AttackerContext = AttackerContext.make(
			&"unit_a", AttackerContext.Class.INFANTRY, 0, false, false, [])
	var def: DefenderContext = DefenderContext.make(&"unit_b", 0, 0, 0)
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var mod: ResolveModifiers = ResolveModifiers.make(
			ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1)

	# Act — timed section; only resolve() calls inside the loop.
	var msec_start: int = Time.get_ticks_msec()
	for _i: int in _CALL_COUNT:
		DamageCalc.resolve(atk, def, mod)
	var elapsed: int = Time.get_ticks_msec() - msec_start

	# Assert — GdUnit4 typed assertion with diagnostic message (G-9: parens
	# around concat before % to avoid "not all arguments converted" error).
	assert_int(elapsed).override_failure_message(
		("AC-DC-40(a) budget exceeded: 10,000 resolve() calls took %dms "
		+ "(budget: %dms, overage: %dms). "
		+ "If this is a flaky CI runner spike, see TD-035 precedent.")
		% [elapsed, _BUDGET_MS, elapsed - _BUDGET_MS]
	).is_less(_BUDGET_MS)
