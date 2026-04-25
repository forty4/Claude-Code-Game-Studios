extends GdUnitTestSuite

## map_grid_perf_test.gd — Story 007: MapGrid pathfinding perf baseline (V-1 desktop substitute).
##
## ADR-0004 §Verification Required + AC-PERF-2:
##   `get_movement_range(move_range=10)` < 16 ms on 40×30 mid-range Android. Expected
##   <5 ms with packed caches + 4-dir + early termination. ADR-0004 R-1 fallbacks
##   pre-authorized if mobile target missed: map cap 32×24, flow-field precompute,
##   GDExtension C++.
##
## SCOPE (4 of 5 ACs; AC-TARGET explicitly DEFERRED per story-007 §7 deferral pattern):
##   - AC-DESKTOP: 100 iterations of get_movement_range(move_range=10); p95 < 16 ms HARD,
##     <20 ms advisory; report p50/p95/max/mean for debuggability.
##   - AC-WARMUP: first-iteration time / steady-state p50 ≤ 3.0 advisory; >5.0 hard fail.
##   - AC-FRAME-TIME: 100 sequential calls; no 3-consecutive-sample window all >16.6 ms
##     (desktop substitute for AC-PERF-1 on-device frame-time stability).
##   - STRESS FIXTURE: stress_40x30.tres loads cleanly + dimensions + 5 enemy occupants
##     present.
##
## DEFERRED (not in this suite):
##   - AC-TARGET: on-device mid-range Android validation. Documented in story §7;
##     reactivation trigger = first Android export build green on CI.
##   - AC-BREAKDOWN: per-subcomponent (queue seed / land-tile filter / scratch reset)
##     timing — requires test-exposed seam in MapGrid that does not exist. Aggregate-only
##     for now; per-stage breakdown queued to story-007 TD with reactivation tied to a
##     future MapGrid refactor.
##   - REPRODUCIBILITY (story spec line 41 / ±10% variance over 10 consecutive runs):
##     manually verifiable via repeated CI invocation but NOT automated — running 10
##     full suites back-to-back is CI-impractical. The 100-iteration p95 within a
##     single run is the proxy. Reactivation: only if a perf-trend dashboard is
##     introduced that can ingest multi-run JSON artifacts (see TD-032 A-30).
##
## ASSERTION DISCIPLINE (matches save_perf_test.gd convention):
##   - ADVISORY thresholds (20 ms desktop p95, 3× warmup ratio) use push_warning() so CI
##     logs the advisory but doesn't fail the PR.
##   - HARD (catastrophic) thresholds use assert_int() to fail the test — they catch
##     regressions so severe that even desktop shouldn't exhibit them.
##
## DESKTOP-vs-MOBILE ASYMMETRIC SIGNAL: desktop PASS does NOT imply mobile PASS;
## desktop FAIL >50 ms GUARANTEES mobile FAIL. Story §AC-DESKTOP rationale.
##
## ADR references:   ADR-0004 §Decision 7, §Verification Required (V-1), AC-PERF-2
## Story reference:  production/epics/map-grid/story-007-perf-baseline.md
## Fixture:          res://tests/fixtures/maps/stress_40x30.tres
## Generator:        res://tests/fixtures/generate_stress_40x30.gd (one-shot, NOT run per-test)

const STRESS_FIXTURE_PATH: String = "res://tests/fixtures/maps/stress_40x30.tres"

## V-1 mandates 100-iteration measurement with warmup (per story-007 line 83 — 100 is the
## save-manager story-007 precedent count).
const ITERATIONS: int = 100

## Warmup samples are discarded, not folded into p95 computation. 10 warmup iters drives
## any cold-cache effects out of the steady-state distribution.
const WARMUP_ITERATIONS: int = 10

## Desktop-substitute hard threshold — AC-PERF-2 mandate (16 ms = mobile target).
## On desktop arm64 / x86_64 we expect <5 ms per ADR-0004 (3-5× headroom for desktop-vs-mobile).
const DESKTOP_P95_BUDGET_USEC: int = 16_000  # 16 ms HARD

## Advisory threshold — desktop p95 >20 ms triggers a push_warning + TD investigation
## per story-007 line 59. Below 20 ms = within expected envelope; 20-50 ms = warn; >50 ms = hard fail.
const DESKTOP_ADVISORY_USEC: int = 20_000  # 20 ms

## Catastrophic threshold — if desktop p95 ≥ 50 ms, the implementation has a real bug.
const DESKTOP_CATASTROPHIC_USEC: int = 50_000  # 50 ms HARD upper bound

## AC-FRAME-TIME — 1 frame at 60fps = 16.6 ms. Desktop substitute for AC-PERF-1.
const FRAME_BUDGET_USEC: int = 16_600  # 16.6 ms

## AC-WARMUP — first-iter / steady-state p50 ratio threshold.
const WARMUP_RATIO_ADVISORY: float = 3.0
const WARMUP_RATIO_HARD: float = 5.0

## Test unit placement — origin coord for the get_movement_range query.
## Story-007 line 80 specifies (20, 15) as a non-corner mid-map position with full
## attack-radius coverage on a 40×30 map.
const PLAYER_UNIT_ID: int = 1
const PLAYER_COORD: Vector2i = Vector2i(20, 15)

## Move-range parameter — story-007 + AC-PERF-2 fix this at 10 (the mandate value).
const MOVE_RANGE: int = 10

## INFANTRY unit_type — placeholder until ADR-0008 Terrain Effect (cost_multiplier returns 1).
const INFANTRY: int = 0

## Tracked grid for after_test cleanup (G-6 orphan safety net).
var _current_grid: MapGrid = null


func after_test() -> void:
	# Idempotent safety net for tests that crash before explicit free.
	if is_instance_valid(_current_grid):
		_current_grid.free()
		_current_grid = null


# ─── Statistics helpers (mirrored from save_perf_test.gd convention) ──────────

## Computes the 95th-percentile value from a sorted Array[int] of usec timings.
## Uses index = floor(n * 0.95). For n=100, index=95 — i.e. the 96th smallest
## sample. This is a conservative P95 (slightly stricter than textbook "95th of 100");
## same convention as save_perf_test.gd. The clampi guard handles n<21 boundary.
func _p95(sorted_timings: Array[int]) -> int:
	if sorted_timings.is_empty():
		return 0
	var index: int = int(float(sorted_timings.size()) * 0.95)
	index = clampi(index, 0, sorted_timings.size() - 1)
	return sorted_timings[index]


## Computes a 50th-percentile-equivalent (upper-median for even-length arrays).
## For n=100 this returns the 51st smallest sample (index=50). Adequate as a
## representative central tendency for perf reporting; the difference from a
## true median (avg of indices 49 and 50) is sub-microsecond at our scale.
func _p50(sorted_timings: Array[int]) -> int:
	if sorted_timings.is_empty():
		return 0
	var index: int = sorted_timings.size() / 2
	return sorted_timings[index]


func _mean(timings: Array[int]) -> int:
	if timings.is_empty():
		return 0
	var sum: int = 0
	for v: int in timings:
		sum += v
	return sum / timings.size()


func _max(timings: Array[int]) -> int:
	var m: int = 0
	for v: int in timings:
		if v > m:
			m = v
	return m


# ─── Fixture loader ──────────────────────────────────────────────────────────

## Load the 40×30 stress fixture. Asserts the fixture file exists; otherwise
## tests in this suite cannot meaningfully run.
##
## Returns a fully-loaded MapGrid with:
##   - 40×30 dimensions
##   - Mixed terrain distribution
##   - 5 ENEMY_OCCUPIED tiles at deterministic coords
##   - PLAYER_UNIT_ID placed at PLAYER_COORD as FACTION_ALLY
func _load_stress_grid() -> MapGrid:
	# Verify fixture exists. If not, the generator wasn't run.
	if not ResourceLoader.exists(STRESS_FIXTURE_PATH):
		assert_bool(false).override_failure_message(
			("Stress fixture missing at %s. Run once: " \
			+ "godot --headless --path . -s res://tests/fixtures/generate_stress_40x30.gd") \
			% STRESS_FIXTURE_PATH
		).is_true()
		return null

	var res: MapResource = load(STRESS_FIXTURE_PATH) as MapResource
	assert_that(res).override_failure_message(
		"Failed to load %s as MapResource — fixture may be corrupt or stale." % STRESS_FIXTURE_PATH
	).is_not_null()

	var grid: MapGrid = MapGrid.new()
	var ok: bool = grid.load_map(res)
	assert_bool(ok).override_failure_message(
		"load_map(stress_40x30.tres) FAILED. Errors: %s" % str(grid.get_last_load_errors())
	).is_true()

	# Place the player unit at the test query origin (FACTION_ALLY).
	grid.set_occupant(PLAYER_COORD, PLAYER_UNIT_ID, MapGrid.FACTION_ALLY)

	_current_grid = grid
	return grid


# ─── STRESS FIXTURE — fixture integrity check ─────────────────────────────────

## STRESS FIXTURE: validates the committed .tres has the expected structure.
## Story-007 §QA Test Cases STRESS FIXTURE.
func test_map_grid_perf_stress_fixture_loads_with_expected_structure() -> void:
	# Arrange + Act
	var grid: MapGrid = _load_stress_grid()

	# Assert: dimensions match story-007 spec (40×30).
	var dims: Vector2i = grid.get_map_dimensions()
	assert_int(dims.x).override_failure_message(
		"STRESS FIXTURE: map_cols expected 40, got %d" % dims.x
	).is_equal(40)
	assert_int(dims.y).override_failure_message(
		"STRESS FIXTURE: map_rows expected 30, got %d" % dims.y
	).is_equal(30)

	# Assert: 5 enemy occupants present (story-007 line 56).
	var enemy_tiles: PackedVector2Array = grid.get_occupied_tiles(MapGrid.FACTION_ENEMY)
	assert_int(enemy_tiles.size()).override_failure_message(
		"STRESS FIXTURE: expected 5 enemy occupants, got %d. Result: %s" \
		% [enemy_tiles.size(), str(enemy_tiles)]
	).is_greater_equal(5)

	# Assert: full-map terrain distribution matches the deterministic 60/15/10/10/5
	# pattern. Drift-resistance: if a developer regenerates the fixture with a
	# different distribution, this catches the silent perf-baseline shift.
	var terrain_counts: Dictionary = {0: 0, 1: 0, 2: 0, 3: 0, 6: 0, 7: 0}
	for r: int in 30:
		for c: int in 40:
			var tile: MapTileData = grid.get_tile(Vector2i(c, r))
			var tt: int = tile.terrain_type
			terrain_counts[tt] = terrain_counts.get(tt, 0) + 1
			# Full-map FORTRESS_WALL scan — story-007 line 40 prohibition (would
			# bias the perf measurement; partial-row scans miss off-row walls).
			assert_int(tt).override_failure_message(
				"STRESS FIXTURE: FORTRESS_WALL found at (%d, %d) — pathfinding-unfriendly bias forbidden by story-007 line 40" \
				% [c, r]
			).is_not_equal(6)
	# Expected counts from 60/15/10/10/5 modulo cycling on 1200 tiles:
	# base PLAINS=720, FOREST=120, HILLS=180, ROAD=120, MOUNTAIN=60.
	# Generator overrides 5 enemy coords to PLAINS (story-007 line 56). Of the 5
	# coords, modulo placement makes (5,5),(12,8),(25,12),(30,20) originally
	# PLAINS (4) and (8,22) originally ROAD (1) — see generator file. So the
	# committed fixture has PLAINS=720+1=721 and ROAD=120-1=119; others unchanged.
	assert_int(terrain_counts[0] as int).override_failure_message(
		"STRESS FIXTURE distribution: PLAINS expected 721 (720 base + 1 ROAD→PLAINS override at enemy coord (8,22)), got %d. Fixture may have been regenerated with different enemy coord pattern." \
		% (terrain_counts[0] as int)
	).is_equal(721)
	assert_int(terrain_counts[2] as int).override_failure_message(
		"STRESS FIXTURE distribution: HILLS expected 180, got %d." % (terrain_counts[2] as int)
	).is_equal(180)
	assert_int(terrain_counts[1] as int).override_failure_message(
		"STRESS FIXTURE distribution: FOREST expected 120, got %d." % (terrain_counts[1] as int)
	).is_equal(120)
	assert_int(terrain_counts[7] as int).override_failure_message(
		"STRESS FIXTURE distribution: ROAD expected 119 (120 base − 1 enemy at (8,22)), got %d." % (terrain_counts[7] as int)
	).is_equal(119)
	assert_int(terrain_counts[3] as int).override_failure_message(
		"STRESS FIXTURE distribution: MOUNTAIN expected 60, got %d." % (terrain_counts[3] as int)
	).is_equal(60)

	# Player unit was placed by _load_stress_grid; verify.
	var player_tile: MapTileData = grid.get_tile(PLAYER_COORD)
	assert_int(player_tile.occupant_id).override_failure_message(
		"STRESS FIXTURE: player unit placement at %s did not register; tile occupant_id=%d" \
		% [str(PLAYER_COORD), player_tile.occupant_id]
	).is_equal(PLAYER_UNIT_ID)

	grid.free()
	_current_grid = null


# ─── AC-DESKTOP + AC-WARMUP — main perf measurement ───────────────────────────

## AC-DESKTOP: get_movement_range(move_range=10) p95 < 16 ms desktop substitute.
## AC-WARMUP: first-iter time vs steady-state p50 ratio ≤ 3.0 advisory.
##
## Combined into one test because both consume the same 100+10 iteration measurement —
## splitting would double the runtime cost without isolation benefit.
func test_map_grid_perf_get_movement_range_p95_under_desktop_budget() -> void:
	# Arrange
	var grid: MapGrid = _load_stress_grid()

	# Warmup phase — discard these timings.
	var warmup_first_iter_usec: int = 0
	for i: int in WARMUP_ITERATIONS:
		var t0: int = Time.get_ticks_usec()
		var _r: PackedVector2Array = grid.get_movement_range(PLAYER_UNIT_ID, MOVE_RANGE, INFANTRY)
		var dt: int = Time.get_ticks_usec() - t0
		if i == 0:
			warmup_first_iter_usec = dt

	# Measurement phase — collect 100 timing samples.
	var timings: Array[int] = []
	timings.resize(ITERATIONS)
	for i: int in ITERATIONS:
		var t0: int = Time.get_ticks_usec()
		var _r: PackedVector2Array = grid.get_movement_range(PLAYER_UNIT_ID, MOVE_RANGE, INFANTRY)
		timings[i] = Time.get_ticks_usec() - t0

	# Compute statistics.
	var sorted_timings: Array[int] = timings.duplicate()
	sorted_timings.sort()
	var p50_usec: int = _p50(sorted_timings)
	var p95_usec: int = _p95(sorted_timings)
	var max_usec: int = _max(timings)
	var mean_usec: int = _mean(timings)

	# Diagnostic: always print stats for visibility (test output captures stdout).
	print(("AC-DESKTOP map_grid_perf — get_movement_range(move_range=%d) on 40×30:\n" \
		+ "  iterations=%d warmup=%d\n" \
		+ "  p50=%.3fms p95=%.3fms max=%.3fms mean=%.3fms\n" \
		+ "  warmup_first=%.3fms (ratio=%.2f×)") \
		% [MOVE_RANGE, ITERATIONS, WARMUP_ITERATIONS,
		   p50_usec / 1000.0, p95_usec / 1000.0, max_usec / 1000.0, mean_usec / 1000.0,
		   warmup_first_iter_usec / 1000.0,
		   (warmup_first_iter_usec / float(maxi(p50_usec, 1)))])

	# AC-DESKTOP advisory threshold (push_warning above 20 ms but don't fail).
	if p95_usec >= DESKTOP_ADVISORY_USEC:
		push_warning(("AC-DESKTOP ADVISORY: p95=%.2fms exceeds %.0fms desktop advisory budget. " \
			+ "Mobile target (16 ms on Android) is at risk; consider profiling.") \
			% [p95_usec / 1000.0, DESKTOP_ADVISORY_USEC / 1000.0])

	# AC-DESKTOP HARD (16 ms) — desktop should be well below mobile target.
	# This is the AC-PERF-2 mandate translated to desktop-substitute territory.
	# This is the perf canary for story-007. If this previously passed and now
	# fails, suspect a regression in the Dijkstra inner loop, scratch buffer
	# reuse, packed-cache reads, or a newly-introduced allocation in the hot path
	# — NOT a test misconfiguration.
	assert_int(p95_usec).override_failure_message(
		("AC-DESKTOP: get_movement_range p95=%.2fms on 40×30 (move_range=%d) " \
		+ "exceeds %.0fms hard threshold (mobile AC-PERF-2 target). " \
		+ "REGRESSION SUSPECTED — investigate Dijkstra hot loop, scratch buffer " \
		+ "reuse, or new allocations in MapGrid.get_movement_range. " \
		+ "Stats: p50=%.2fms max=%.2fms mean=%.2fms warmup=%.2fms.") \
		% [p95_usec / 1000.0, MOVE_RANGE, DESKTOP_P95_BUDGET_USEC / 1000.0,
		   p50_usec / 1000.0, max_usec / 1000.0, mean_usec / 1000.0,
		   warmup_first_iter_usec / 1000.0]
	).is_less(DESKTOP_P95_BUDGET_USEC)

	# AC-DESKTOP catastrophic — clear regression signal.
	assert_int(p95_usec).override_failure_message(
		("AC-DESKTOP CATASTROPHIC: p95=%.2fms exceeds %.0fms — implementation likely has " \
		+ "a hot-loop allocation or virtual-dispatch regression. Investigate immediately.") \
		% [p95_usec / 1000.0, DESKTOP_CATASTROPHIC_USEC / 1000.0]
	).is_less(DESKTOP_CATASTROPHIC_USEC)

	# AC-WARMUP — ratio of first-iteration vs steady-state p50.
	# Guard against p50_usec=0 (impossible at this scale, but defensive).
	if p50_usec > 0:
		var warmup_ratio: float = float(warmup_first_iter_usec) / float(p50_usec)

		if warmup_ratio > WARMUP_RATIO_ADVISORY:
			push_warning(("AC-WARMUP ADVISORY: warmup ratio=%.2f× exceeds %.1f× advisory threshold. " \
				+ "Cold-start pathology suspected — likely cache/JIT warmup. Acceptable on desktop, " \
				+ "noteworthy on mobile.") \
				% [warmup_ratio, WARMUP_RATIO_ADVISORY])

		# Hard failure only at egregious cold-start ratios.
		assert_float(warmup_ratio).override_failure_message(
			("AC-WARMUP HARD: warmup_first=%.2fms / p50=%.2fms = ratio=%.2f× exceeds %.1f×. " \
			+ "Implementation has severe cold-start cost; investigate scratch-buffer or " \
			+ "type-coercion path.") \
			% [warmup_first_iter_usec / 1000.0, p50_usec / 1000.0, warmup_ratio, WARMUP_RATIO_HARD]
		).is_less(WARMUP_RATIO_HARD)

	grid.free()
	_current_grid = null


# ─── AC-FRAME-TIME — synthetic frame-time stability ───────────────────────────

## AC-FRAME-TIME: 100 sequential get_movement_range calls; no 3-consecutive-sample
## window where all 3 exceed 16.6 ms. Desktop substitute for AC-PERF-1 on-device
## frame-time stability per story-007.
func test_map_grid_perf_frame_time_no_three_consecutive_above_16ms() -> void:
	# Arrange
	var grid: MapGrid = _load_stress_grid()

	# Quick warmup — single iteration to push any first-call cold-start out of the data.
	var _w: PackedVector2Array = grid.get_movement_range(PLAYER_UNIT_ID, MOVE_RANGE, INFANTRY)

	# Measurement: 100 sequential calls, capture per-sample duration.
	var durations: Array[int] = []
	durations.resize(ITERATIONS)
	for i: int in ITERATIONS:
		var t0: int = Time.get_ticks_usec()
		var _r: PackedVector2Array = grid.get_movement_range(PLAYER_UNIT_ID, MOVE_RANGE, INFANTRY)
		durations[i] = Time.get_ticks_usec() - t0

	# Scan for 3-consecutive-sample windows above frame budget.
	var bad_windows: Array[int] = []  # list of starting indices i where durations[i..i+2] all > FRAME_BUDGET_USEC
	for i: int in range(ITERATIONS - 2):
		if (durations[i] > FRAME_BUDGET_USEC
				and durations[i + 1] > FRAME_BUDGET_USEC
				and durations[i + 2] > FRAME_BUDGET_USEC):
			bad_windows.append(i)

	# Diagnostic: also count 2-consecutive >budget runs as advisory (story-007 spec).
	var two_consecutive_runs: Array[int] = []
	for i: int in range(ITERATIONS - 1):
		if durations[i] > FRAME_BUDGET_USEC and durations[i + 1] > FRAME_BUDGET_USEC:
			two_consecutive_runs.append(i)

	# Single-sample over-budget count (logged for trend analysis, not asserted).
	var over_budget_count: int = 0
	for d: int in durations:
		if d > FRAME_BUDGET_USEC:
			over_budget_count += 1

	if two_consecutive_runs.size() > 0:
		push_warning(("AC-FRAME-TIME ADVISORY: %d 2-consecutive-window(s) >16.6ms detected. " \
			+ "First indices: %s") \
			% [two_consecutive_runs.size(), str(two_consecutive_runs.slice(0, 5))])

	print(("AC-FRAME-TIME map_grid_perf — single-sample over-budget count: %d / %d " \
		+ "(%.1f%%); 2-consecutive runs: %d; 3-consecutive runs: %d") \
		% [over_budget_count, ITERATIONS,
		   100.0 * over_budget_count / ITERATIONS,
		   two_consecutive_runs.size(), bad_windows.size()])

	# HARD: no 3-consecutive-sample window above frame budget.
	assert_int(bad_windows.size()).override_failure_message(
		("AC-FRAME-TIME: %d 3-consecutive >16.6ms window(s) detected at start indices %s. " \
		+ "On-device frame-time stability is at risk. Sample size %d. " \
		+ "Single-sample over-budget count: %d (%.1f%%).") \
		% [bad_windows.size(), str(bad_windows.slice(0, 5)),
		   ITERATIONS, over_budget_count, 100.0 * over_budget_count / ITERATIONS]
	).is_equal(0)

	grid.free()
	_current_grid = null
