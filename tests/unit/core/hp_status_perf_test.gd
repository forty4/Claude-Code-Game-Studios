extends GdUnitTestSuite

## hp_status_perf_test.gd
## Perf baseline tests for HP/Status story-008: 4 methods at ×3-25 generous CI gates.
## Gates are headless-CI-only; on-device 1ms headline budget is deferred per TD-052.
##
## Governing ADR: ADR-0010 — HP/Status §Performance + Verification + Validation §8.
## Design reference: production/epics/hp-status/story-008-perf-lints-and-td-entries.md §1
##
## G-15: before_test() / after_test() canonical hooks with BalanceConstants + UnitRole reset.
## G-9:  Multi-line failure messages wrap concat in parens before % operator.


# ── Constants ─────────────────────────────────────────────────────────────────

const PERF_ITERATIONS: int = 1000

## ADR-0010 §Performance headline budgets × generous gates (3-25× for headless CI).
## 3×  over 0.05ms headline → apply_damage gate <0.15ms
## 25× over 0.05ms headline → get_modified_stat gate <1.25ms (generous: stat lookup is pure query)
## 10× over 0.10ms headline → apply_status gate <1.0ms
## 5×  over 0.20ms headline → turn_start_tick gate <1.0ms
const APPLY_DAMAGE_GATE_MS: float = 0.15
const GET_MODIFIED_STAT_GATE_MS: float = 1.25
const APPLY_STATUS_GATE_MS: float = 1.0
const TURN_START_TICK_GATE_MS: float = 1.0


# ── G-15 cache-reset paths ────────────────────────────────────────────────────

const _BC_PATH: String = "res://src/foundation/balance/balance_constants.gd"
const _UR_PATH: String = "res://src/foundation/unit_role.gd"

var _bc_script: GDScript = load(_BC_PATH) as GDScript
var _ur_script: GDScript = load(_UR_PATH) as GDScript


# ── Suite state ───────────────────────────────────────────────────────────────

var _controller: HPStatusController
var _map_grid_stub: MapGridStub


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func before_test() -> void:
	## G-15: canonical GdUnit4 v6.1.2 per-test hook (NOT before_each).
	## Resets BalanceConstants + UnitRole static caches (mandatory — perf methods invoke
	## BalanceConstants.get_const for MIN_DAMAGE / DEFEND_STANCE_REDUCTION / MODIFIER_FLOOR etc.).
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})
	_ur_script.set("_coefficients_loaded", false)
	_ur_script.set("_coefficients", {})
	_controller = HPStatusController.new()
	_map_grid_stub = MapGridStub.new()
	_controller._map_grid = _map_grid_stub
	# G-6: parent stub to controller so orphan detector (fires BETWEEN test body and after_test)
	# sees it as tree-attached. Freed automatically when controller is freed by GdUnit4 teardown.
	_controller.add_child(_map_grid_stub)
	add_child(_controller)
	_map_grid_stub.set_dimensions_for_test(Vector2i(8, 8))
	_map_grid_stub.set_occupant_for_test(Vector2i(0, 0), 1)
	_controller.initialize_unit(1, _make_hero(50), UnitRole.UnitClass.INFANTRY)


func after_test() -> void:
	_bc_script.set("_cache_loaded", false)
	_bc_script.set("_cache", {})
	_ur_script.set("_coefficients_loaded", false)
	_ur_script.set("_coefficients", {})


# ── Hero fixture builder ──────────────────────────────────────────────────────

## Builds a minimal HeroData with explicitly specified base_hp_seed.
## Matches established pattern from hp_status_apply_damage_test.gd.
func _make_hero(p_base_hp_seed: int = 50) -> HeroData:
	var hero: HeroData = HeroData.new()
	hero.base_hp_seed = p_base_hp_seed
	hero.stat_might = 80
	hero.stat_command = 80
	hero.stat_intellect = 80
	hero.base_initiative_seed = 60
	hero.move_range = 4
	return hero


# ── AC-1a: apply_damage perf gate <0.15ms (3× over 0.05ms headline) ──────────

## AC-1a: 1000-iteration apply_damage loop on INFANTRY unit with HP reset each iteration.
## Uses CAVALRY-equivalent (PHYSICAL damage with no shield-wall) for cleaner isolation.
## Per-call mean must be < APPLY_DAMAGE_GATE_MS (0.15ms).
func test_apply_damage_perf_under_gate() -> void:
	var start: int = Time.get_ticks_usec()
	for _i: int in range(PERF_ITERATIONS):
		# Reset HP before each iteration so apply_damage always has work to do
		_controller._state_by_unit[1].current_hp = _controller._state_by_unit[1].max_hp
		_controller.apply_damage(1, 10, 0, [])
	var elapsed_ms: float = (Time.get_ticks_usec() - start) / 1000.0
	var per_call_ms: float = elapsed_ms / PERF_ITERATIONS

	assert_float(per_call_ms).override_failure_message(
		("AC-1a apply_damage perf: mean per-call %.4fms exceeds gate %.4fms "
		+ "(ADR-0010 §Performance; headless CI gate = 3× over 0.05ms headline)") % [per_call_ms, APPLY_DAMAGE_GATE_MS]
	).is_less(APPLY_DAMAGE_GATE_MS)


# ── AC-1b: get_modified_stat perf gate <1.25ms (25× over 0.05ms headline) ────

## AC-1b: 1000-iteration get_modified_stat loop querying &"atk" stat.
## 25× generous gate absorbs GdUnit4 instrumentation overhead (pure query — no mutation).
## Per-call mean must be < GET_MODIFIED_STAT_GATE_MS (1.25ms).
func test_get_modified_stat_perf_under_gate() -> void:
	var start: int = Time.get_ticks_usec()
	for _i: int in range(PERF_ITERATIONS):
		_controller.get_modified_stat(1, &"atk")
	var elapsed_ms: float = (Time.get_ticks_usec() - start) / 1000.0
	var per_call_ms: float = elapsed_ms / PERF_ITERATIONS

	assert_float(per_call_ms).override_failure_message(
		("AC-1b get_modified_stat perf: mean per-call %.4fms exceeds gate %.4fms "
		+ "(ADR-0010 §Performance; headless CI gate = 25× over 0.05ms headline; "
		+ "generous to absorb GdUnit4 instrumentation overhead)") % [per_call_ms, GET_MODIFIED_STAT_GATE_MS]
	).is_less(GET_MODIFIED_STAT_GATE_MS)


# ── AC-1c: apply_status perf gate <1.0ms (10× over 0.10ms headline) ─────────

## AC-1c: 1000-iteration apply_status loop applying DEMORALIZED with clear before each iteration.
## Status effects cleared between iterations so the apply path (not refresh) is exercised.
## Per-call mean must be < APPLY_STATUS_GATE_MS (1.0ms).
func test_apply_status_perf_under_gate() -> void:
	var start: int = Time.get_ticks_usec()
	for _i: int in range(PERF_ITERATIONS):
		# Clear status effects before each apply to exercise the append path (not CR-5c refresh)
		_controller._state_by_unit[1].status_effects.clear()
		_controller.apply_status(1, &"demoralized", -1, 99)
	var elapsed_ms: float = (Time.get_ticks_usec() - start) / 1000.0
	var per_call_ms: float = elapsed_ms / PERF_ITERATIONS

	assert_float(per_call_ms).override_failure_message(
		("AC-1c apply_status perf: mean per-call %.4fms exceeds gate %.4fms "
		+ "(ADR-0010 §Performance; headless CI gate = 10× over 0.10ms headline)") % [per_call_ms, APPLY_STATUS_GATE_MS]
	).is_less(APPLY_STATUS_GATE_MS)


# ── AC-1d: _apply_turn_start_tick perf gate <1.0ms (5× over 0.20ms headline) ─

## AC-1d: 1000-iteration _apply_turn_start_tick loop on a living unit with no status effects.
## No status effects → DoT loop is trivially empty; duration decrement loop is empty;
## DEMORALIZED check skipped. Pure overhead of null-guard + empty-array iteration.
## Per-call mean must be < TURN_START_TICK_GATE_MS (1.0ms).
func test_apply_turn_start_tick_perf_under_gate() -> void:
	# Ensure unit is alive and has no status effects throughout the perf loop
	_controller._state_by_unit[1].current_hp = _controller._state_by_unit[1].max_hp
	_controller._state_by_unit[1].status_effects.clear()

	var start: int = Time.get_ticks_usec()
	for _i: int in range(PERF_ITERATIONS):
		_controller._apply_turn_start_tick(1)
	var elapsed_ms: float = (Time.get_ticks_usec() - start) / 1000.0
	var per_call_ms: float = elapsed_ms / PERF_ITERATIONS

	assert_float(per_call_ms).override_failure_message(
		("AC-1d _apply_turn_start_tick perf: mean per-call %.4fms exceeds gate %.4fms "
		+ "(ADR-0010 §Performance; headless CI gate = 5× over 0.20ms headline)") % [per_call_ms, TURN_START_TICK_GATE_MS]
	).is_less(TURN_START_TICK_GATE_MS)
