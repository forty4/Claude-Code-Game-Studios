## balance_entities_battle_hud_test.gd
## Story 006 (S10-01) — UI-GB-04 Combat Forecast BalanceConstants append.
## Verifies FORECAST_RENDER_BUDGET_MS = 120 entry resolves via BalanceConstants
## per ADR-0006 5-precedent JSON pattern + ADR-0015 §"Same-Patch Obligations" item 1.
##
## ACs covered: AC-1 BalanceConstants entry presence + safe-range invariant.
##
## TR: TR-battle-hud-009 (FORECAST_RENDER_BUDGET_MS BalanceConstants) +
##     TR-battle-hud-014 (perf-budget context).
##
## Gotchas applied (per `.claude/rules/godot-4x-gotchas.md`):
##   G-15: before_test (NOT before_each) resets BalanceConstants static cache.
##   G-3 verification: this test file declares NO class_name (per project rule).
extends GdUnitTestSuite


const _BC_PATH: String = "res://src/foundation/balance/balance_constants.gd"

## GDScript handle for static-state isolation per G-15.
var _bc_script: GDScript = load(_BC_PATH)


func before_test() -> void:
	# G-15: reset BalanceConstants static state to force fresh load per test.
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})


func after_test() -> void:
	# Idempotent cleanup safety net.
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})


# ─── AC-1: FORECAST_RENDER_BUDGET_MS resolves via BalanceConstants ───────────


## AC-1a: BalanceConstants.get_const(&"FORECAST_RENDER_BUDGET_MS") returns int 120.
## Per battle-hud.md §10 Tuning Knobs + ADR-0015 same-patch obligation.
func test_balance_constants_has_forecast_render_budget_ms() -> void:
	var actual: int = BalanceConstants.get_const(&"FORECAST_RENDER_BUDGET_MS") as int
	assert_int(actual).override_failure_message(
		"AC-1a: BalanceConstants.get_const(&'FORECAST_RENDER_BUDGET_MS') expected 120; got %d" % actual
	).is_equal(120)


## AC-1b: FORECAST_RENDER_BUDGET_MS is in safe range [50, 300] ms.
## Lower bound 50ms — below this is unrealistic for cross-system damage_calc + UI populate.
## Upper bound 300ms — above this would breach the "feel responsive" expectation per
## battle-hud.md §10 + accessibility-requirements.md WCAG 2.2.2 timing.
func test_balance_constants_forecast_render_budget_in_safe_range() -> void:
	var actual: int = BalanceConstants.get_const(&"FORECAST_RENDER_BUDGET_MS") as int
	assert_int(actual).override_failure_message(
		"AC-1b: FORECAST_RENDER_BUDGET_MS = %d outside safe range [50, 300] ms" % actual
	).is_between(50, 300)
