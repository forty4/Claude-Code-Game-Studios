extends GdUnitTestSuite

## input_router_perf_test.gd
## Story 010 epic-terminal performance baseline per ADR-0005 §Performance
## Implications + Validation Criteria. 4 tests targeting headless CI gates
## (3-25× generous over on-device 0.05ms headline budget per damage-calc /
## hp-status / turn-order epic-terminal precedent).
##
## Governing ADR: ADR-0005 — Input Handling §Performance + AC-1 from
## production/epics/input-handling/story-010-epic-terminal-perf-lints-evidence.md
##
## Headless-only: on-device perf measurement is Polish-deferred per damage-calc
## story-010 + hp-status story-008 + turn-order story-007 4-precedent. The
## SKIP_PERF_BUDGETS env var (set in .github/workflows/tests.yml) bypasses the
## strict bounds on Linux runners which lack vsynced display.
##
## G-15: before_test() resets BalanceConstants cache + all 17 InputRouter
## fields per `tools/ci/lint_input_router_g15_reset.sh` enforcement.
## G-9:  multi-line failure messages wrap the concat in parens before %.

# ── Constants ─────────────────────────────────────────────────────────────────

const PERF_ITERATIONS: int = 1000
const THROUGHPUT_COUNT: int = 10000

## Headless CI gates — generous to absorb CI variance.
## On-device target: _handle_event < 0.05ms p99. Headless gate at 5×
## (0.25ms) follows damage-calc + hp-status precedent of 3-25× generosity.
const HANDLE_EVENT_GATE_MS: float = 0.25
const HANDLE_ACTION_GATE_MS: float = 0.10
const THROUGHPUT_TOTAL_GATE_MS: int = 500
const READY_INIT_GATE_MS: float = 5.0


# ── G-15 cache reset path ─────────────────────────────────────────────────────

const _BC_PATH: String = "res://src/foundation/balance/balance_constants.gd"

var _bc_script: GDScript = load(_BC_PATH) as GDScript


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func before_test() -> void:
	# G-15 canonical hook (NOT before_each).
	# Reset BalanceConstants cache — perf methods read TOUCH_TARGET_MIN_PX +
	# TILE_WORLD_SIZE + DISAMBIG_EDGE_PX + DISAMBIG_TILE_PX + PAN_ACTIVATION_PX +
	# MIN_TOUCH_DURATION_MS + TPP_DOUBLE_TAP_WINDOW_MS via BalanceConstants.get_const.
	_bc_script.set("_cache_loaded", false)
	# Reset all 17 InputRouter fields per lint_input_router_g15_reset.sh.
	# Architectural (story-001):
	InputRouter._state = InputRouter.InputState.OBSERVATION
	InputRouter._active_mode = InputRouter.InputMode.KEYBOARD_MOUSE
	InputRouter._pre_menu_state = InputRouter.InputState.OBSERVATION
	InputRouter._undo_windows.clear()
	InputRouter._input_blocked_reasons.clear()
	InputRouter._bindings.clear()
	# Transient (story-004 + story-007):
	InputRouter._pending_end_phase = false
	InputRouter._pre_block_state = InputRouter.InputState.OBSERVATION
	# Transient (story-008):
	InputRouter._last_tap_unit_id = -1
	InputRouter._last_tap_time_ms = 0
	InputRouter._camera = null
	InputRouter._map_grid = null
	# Transient (story-009):
	InputRouter._touch_start_pos = Vector2.ZERO
	InputRouter._touch_start_time_ms = 0
	InputRouter._touch_travel_px = 0.0
	InputRouter._active_touch_indices = PackedInt32Array()
	# Test seam (story-003+):
	InputRouter._grid_battle = null
	# Repopulate InputMap for handle_event match-loop (cleared by _bindings.clear)
	var bindings_dict: Dictionary = InputRouter._load_bindings_from_path(InputRouter.DEFAULT_BINDINGS_PATH)
	InputRouter._populate_input_map(bindings_dict)


# ── AC-1 Test 1: _handle_event p99 timing ────────────────────────────────────


## p99 of `_handle_event` over 1000 iterations must be < HANDLE_EVENT_GATE_MS.
## Uses synthetic InputEventKey (KEY_ENTER) which matches `move_confirm` etc.
## via InputMap; the dispatch reaches `_handle_action` in S0 which silently
## drops (no `move_confirm` arm in S0) — measures full path including dispatch.
func test_handle_event_p99_under_gate() -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = true
	var times: PackedFloat32Array = PackedFloat32Array()
	for i in PERF_ITERATIONS:
		var t0: int = Time.get_ticks_usec()
		InputRouter._handle_event(event)
		var t1: int = Time.get_ticks_usec()
		times.append(float(t1 - t0) / 1000.0)  # μs → ms
	times.sort()
	var p99: float = times[int(PERF_ITERATIONS * 0.99)]
	assert_float(p99).override_failure_message(
		(
			"AC-1: _handle_event p99 = %.4f ms; headless gate = %.2f ms "
			+ "(on-device target 0.05ms; %dx generous gate per damage-calc/hp-status precedent)"
		)
		% [p99, HANDLE_EVENT_GATE_MS, int(HANDLE_EVENT_GATE_MS * 20)]
	).is_less(HANDLE_EVENT_GATE_MS)


# ── AC-1 Test 2: _handle_action p99 timing ───────────────────────────────────


## p99 of `_handle_action` (direct dispatch, no event-match overhead) must be
## < HANDLE_ACTION_GATE_MS. Lower gate than _handle_event because action-match
## loop is bypassed — pure per-state arm dispatch + emit-pair.
func test_handle_action_p99_under_gate() -> void:
	var ctx := InputContext.new()
	var times: PackedFloat32Array = PackedFloat32Array()
	for i in PERF_ITERATIONS:
		var t0: int = Time.get_ticks_usec()
		InputRouter._handle_action(&"camera_pan", ctx)
		var t1: int = Time.get_ticks_usec()
		times.append(float(t1 - t0) / 1000.0)
	times.sort()
	var p99: float = times[int(PERF_ITERATIONS * 0.99)]
	assert_float(p99).override_failure_message(
		(
			"AC-1: _handle_action p99 = %.4f ms; headless gate = %.2f ms "
			+ "(camera_pan in S0 — no state change, _did_visible_work emit only)"
		)
		% [p99, HANDLE_ACTION_GATE_MS]
	).is_less(HANDLE_ACTION_GATE_MS)


# ── AC-1 Test 3: 10k synthetic events throughput ─────────────────────────────


## 10,000 synthetic events through `_handle_event` must complete in
## < THROUGHPUT_TOTAL_GATE_MS milliseconds. Throughput proxy for in-game
## sustained input load (touch storms, key autorepeat, etc.).
func test_10k_synthetic_events_throughput_under_gate() -> void:
	var events: Array[InputEvent] = []
	for i in THROUGHPUT_COUNT:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = true
		events.append(event)
	var t0: int = Time.get_ticks_msec()
	for event: InputEvent in events:
		InputRouter._handle_event(event)
	var elapsed: int = Time.get_ticks_msec() - t0
	assert_int(elapsed).override_failure_message(
		(
			"AC-1: 10k synthetic events throughput = %d ms; gate = %d ms "
			+ "(per-event mean = %.4f ms over %d events)"
		)
		% [elapsed, THROUGHPUT_TOTAL_GATE_MS, float(elapsed) / float(THROUGHPUT_COUNT), THROUGHPUT_COUNT]
	).is_less(THROUGHPUT_TOTAL_GATE_MS)


# ── AC-1 Test 4: _ready() init time (JSON parse + InputMap populate + R-5) ──


## Single-shot autoload init-equivalent time (JSON load + InputMap populate +
## R-5 parity validation) must be < READY_INIT_GATE_MS. Measures the bulk of
## `_ready()` minus GameBus signal subscription (which would cause duplicate
## connections if re-invoked). p50 of 5 runs to absorb single-run noise.
func test_ready_init_under_gate() -> void:
	var times: PackedFloat32Array = PackedFloat32Array()
	for i in 5:
		var t0: int = Time.get_ticks_usec()
		var bindings_dict: Dictionary = InputRouter._load_bindings_from_path(InputRouter.DEFAULT_BINDINGS_PATH)
		InputRouter._populate_input_map(bindings_dict)
		var _mismatch: int = InputRouter._validate_r5_parity(bindings_dict)
		var t1: int = Time.get_ticks_usec()
		times.append(float(t1 - t0) / 1000.0)
	times.sort()
	var p50: float = times[2]  # median of 5
	assert_float(p50).override_failure_message(
		(
			"AC-1: _ready() init equivalent (load + populate + r5 parity) p50 = %.4f ms; "
			+ "gate = %.2f ms"
		)
		% [p50, READY_INIT_GATE_MS]
	).is_less(READY_INIT_GATE_MS)
