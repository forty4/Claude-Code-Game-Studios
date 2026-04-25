extends GdUnitTestSuite

## terrain_effect_perf_test.gd — Story 008: Terrain Effect perf baseline (V-1 desktop substitute).
##
## ADR-0008 §Performance Implications + GDD AC-21 (query latency):
##   `get_combat_modifiers()` <0.1 ms per call on mid-range Android target
##   (100 calls per frame at 60fps budget). ADR-0008 expected <0.01 ms (10× headroom)
##   — two O(1) Dictionary lookups + arithmetic + defensive Resource alloc.
##
## SCOPE (6 ACs from story-008 §QA Test Cases — AC-TARGET DEFERRED per project precedent):
##   - AC-1 (GDD AC-21): get_combat_modifiers p95 < 100µs HARD on desktop substitute
##   - AC-2: 100 sequential calls within single-frame budget (16.6 ms / 16,600µs)
##   - AC-3 (Warmup): first 10 iterations discarded; warmup ratio printed for visibility
##   - AC-4 (Stats):  p50 / p95 / max / mean printed in greppable CI format
##   - AC-5 (Polish DEFERRED marker): this header documents AC-TARGET deferral + reactivation trigger
##   - AC-6 (Regression canary): main perf test's hard threshold serves as a regression canary
##
## DEFERRED (not in this suite):
##   - AC-TARGET: on-device mid-range Android validation. Reactivation trigger:
##     when Android export pipeline lands and a mid-range device is available, run
##     this test on-device with the same fixture (per save-manager/story-007 +
##     map-grid/story-007 + terrain-effect/story-008 precedent).
##   - REPRODUCIBILITY (±10% variance over 10 consecutive runs): CI-impractical;
##     queued to perf-trend dashboard work (TD-032 A-30 from map-grid story-007).
##   - PERF-TREND JSON ARTIFACT: print() suffices until a consumer exists
##     (TD-032 A-29 carry-over from map-grid story-007).
##
## ASSERTION DISCIPLINE (matches save_perf_test.gd + map_grid_perf_test.gd convention):
##   - HARD threshold (100µs p95, 16.6ms frame budget) uses assert_int() — fails CI
##     on regression. AC-21 is a BLOCKING test-evidence rule per coding-standards.md.
##   - ADVISORY threshold (50% of budget) uses push_warning() — logs for trend visibility
##     without failing the build.
##
## DESKTOP-vs-MOBILE ASYMMETRIC SIGNAL: desktop PASS does NOT imply mobile PASS;
## desktop FAIL >50µs guarantees mobile FAIL given Android is ~3-5× slower for
## GDScript dispatch. ADR-0008's <0.01ms expected estimate provides 10× desktop
## headroom — if desktop p95 approaches 100µs, the design FAILS the AC at deploy
## and the test catches it as an early-warning canary (AC-6 purpose).
##
## ADR references:    ADR-0008 §Decision (get_combat_modifiers contract),
##                    ADR-0008 §Performance Implications, ADR-0008 §Validation Criteria §3
## GDD reference:     design/gdd/terrain-effect.md §AC-21
## TR reference:      TR-terrain-effect-013
## Story reference:   production/epics/terrain-effect/story-008-perf-baseline.md
## Pattern source:    tests/integration/core/map_grid_perf_test.gd (3rd reuse of perf-baseline pattern)


# ─── Constants ───────────────────────────────────────────────────────────────

## V-1 mandates 100-iteration measurement with warmup (project standard from
## save-manager/story-007 + map-grid/story-007). Any change here breaks
## cross-story perf-trend comparisons.
const ITERATIONS: int = 100

## Warmup samples are discarded, not folded into p95 computation. 10 warmup iters
## drives any cold-cache effects out of the steady-state distribution.
## Naming aligns with map_grid_perf_test.gd / save_perf_test.gd for cross-story
## perf-trend grep consistency (post-/code-review I-1 alignment, story-008).
const WARMUP_ITERATIONS: int = 10

## Advisory threshold for the warmup ratio (story spec AC-3 edge note: ratio
## close to 1.0 = negligible cold-cache; >2.0 worth investigating).
## When the mean-of-warmup vs steady-state-p50 ratio exceeds this, emit
## push_warning for CI-visible visibility (post-/code-review GAP-4).
const WARMUP_RATIO_ADVISORY: float = 2.0

## AC-21 budget (mobile target: <0.1 ms per call). Desktop substitute uses the
## SAME budget so a desktop pass with comfortable headroom strongly suggests
## mobile pass. ADR-0008 estimates <0.01 ms expected — 10× headroom.
const BUDGET_USEC: int = 100  # 0.1 ms

## ADVISORY threshold: 50% of budget. If desktop p95 climbs above 50µs (still
## well under hard fail), push_warning() — likely indicates a regression worth
## investigating before it crosses the hard threshold.
const ADVISORY_USEC: int = 50  # 0.05 ms

## AC-2 frame-budget check: 100 sequential calls must fit in one 60fps frame.
## 16.6 ms = 16,600µs (rounded; 1/60 = 16.666...).
const FRAME_BUDGET_USEC: int = 16_600

## Fixture dimensions. NOTE: story spec calls for "5×5 mixed terrain", but
## MapGrid.MAP_COLS_MIN / MAP_ROWS_MIN = 15. The mixed-terrain content lives in
## a 5×5 region anchored at (0,0); the surrounding ring is PLAINS filler. This
## matches the established fixture-vs-engine drift mitigation from story-006.
const COLS: int = 15
const ROWS: int = 15

## Representative scenario: FORTRESS_WALL defender at (1,0) elev=2,
## PLAINS attacker at (0,0) elev=0 → delta = 0-2 = -2.
## Per story-008 §Implementation Notes line 99, this single scenario hits ~all
## the get_combat_modifiers code paths: _terrain_table[FORTRESS_WALL] (slowest
## lookup), F-1 symmetric clamp (25 + 15 = 40 → clamped to 30), elevation table
## at delta=-2 boundary. A second scenario would add diversity but the AC-21
## budget is per-call worst-case, so single representative is correct.
const ATK_COORD: Vector2i = Vector2i(0, 0)
const DEF_COORD: Vector2i = Vector2i(1, 0)


# ─── Suite state ─────────────────────────────────────────────────────────────

## Tracked grid for after_test cleanup (G-6 orphan safety net + G-15 disciplined
## hook naming — before_test / after_test, NOT before_each / after_each).
var _grid: MapGrid = null


func before_test() -> void:
	# Reset config state so each test starts from a clean lazy-load slate
	# (matches caps_test + queries_test convention in this epic).
	TerrainEffect.reset_for_tests()
	# Eager load — the perf measurement should NOT include lazy-init cost on
	# the first iteration (would bias warmup massively).
	TerrainEffect.load_config()
	_grid = _build_fixture()


func after_test() -> void:
	# G-6: explicit free even though tests free their own grid; this is the
	# crash-safety net for early test-body exits.
	if is_instance_valid(_grid):
		_grid.free()
		_grid = null
	TerrainEffect.reset_for_tests()


# ─── Fixture builder ─────────────────────────────────────────────────────────

## Builds a 15×15 MapGrid with a 5×5 mixed-terrain region at (0..4, 0..4)
## covering PLAINS, FOREST, HILLS, MOUNTAIN, BRIDGE, FORTRESS_WALL (per story-008
## fixture spec). The remaining 200 tiles are PLAINS filler (engine-min padding).
##
## Tile placements within the 5×5 region (chosen to satisfy
## MapGrid.ELEVATION_RANGES — see src/core/map_grid.gd:64):
##   (0,0) PLAINS    elev=0   ← representative scenario attacker (ATK_COORD)
##   (1,0) FORTRESS  elev=2   ← representative scenario defender (DEF_COORD)
##   (2,0) HILLS     elev=1
##   (3,0) MOUNTAIN  elev=2
##   (4,0) BRIDGE    elev=0
##   (0,1) FOREST    elev=0
##   (1,1) FOREST    elev=1
##   (2,1) HILLS     elev=1
##   (3,1) MOUNTAIN  elev=2
##   (4,1) BRIDGE    elev=0
##   ... PLAINS for the remaining 5×5 cells and the 15×15 padding.
##
## Returns a fully loaded MapGrid (caller is responsible for freeing it via
## after_test, or in-test via _grid.free()).
func _build_fixture() -> MapGrid:
	var res: MapResource = MapResource.new()
	res.map_id = &"perf_fixture_15x15_with_5x5_mixed"
	res.map_rows = ROWS
	res.map_cols = COLS
	res.terrain_version = 1

	for row: int in ROWS:
		for col: int in COLS:
			var t: MapTileData = MapTileData.new()
			t.coord            = Vector2i(col, row)
			t.is_passable_base = true
			t.tile_state       = 0  # EMPTY
			t.occupant_id      = 0
			t.occupant_faction = 0
			t.is_destructible  = false
			t.destruction_hp   = 0
			# Mixed terrain in 5×5 region; PLAINS filler outside.
			# Anchor placements ensure the representative scenario at (0,0) → (1,0)
			# tests FORTRESS_WALL defender + PLAINS attacker delta=-2.
			var terrain: int = TerrainEffect.PLAINS
			var elev: int = 0
			if row == 0 and col == 0:
				terrain = TerrainEffect.PLAINS
				elev = 0
			elif row == 0 and col == 1:
				terrain = TerrainEffect.FORTRESS_WALL
				elev = 2
			elif row == 0 and col == 2:
				terrain = TerrainEffect.HILLS
				elev = 1
			elif row == 0 and col == 3:
				terrain = TerrainEffect.MOUNTAIN
				elev = 2
			elif row == 0 and col == 4:
				terrain = TerrainEffect.BRIDGE
				elev = 0
			elif row == 1 and col == 0:
				terrain = TerrainEffect.FOREST
				elev = 0
			elif row == 1 and col == 1:
				terrain = TerrainEffect.FOREST
				elev = 1
			elif row == 1 and col == 2:
				terrain = TerrainEffect.HILLS
				elev = 1
			elif row == 1 and col == 3:
				terrain = TerrainEffect.MOUNTAIN
				elev = 2
			elif row == 1 and col == 4:
				terrain = TerrainEffect.BRIDGE
				elev = 0
			# All other tiles default to PLAINS elev=0 (already initialised above).
			t.terrain_type = terrain
			t.elevation = elev
			res.tiles.append(t)

	var grid: MapGrid = MapGrid.new()
	var ok: bool = grid.load_map(res)
	assert_bool(ok).override_failure_message(
		("_build_fixture: load_map FAILED — fixture invalid."
		+ " Errors: %s") % str(grid.get_last_load_errors())
	).is_true()
	return grid


# ─── Statistics helpers (mirrored from map_grid_perf_test.gd convention) ─────

## P95 via index = floor(n * 0.95). For n=100, index=95 (96th smallest sample).
## Conservative P95; same convention as save_perf_test.gd + map_grid_perf_test.gd
## for cross-story perf-trend comparability.
func _p95(sorted_timings: Array[int]) -> int:
	if sorted_timings.is_empty():
		return 0
	var index: int = int(float(sorted_timings.size()) * 0.95)
	index = clampi(index, 0, sorted_timings.size() - 1)
	return sorted_timings[index]


## P50 (upper-median for even-length arrays). For n=100 returns index 50.
func _p50(sorted_timings: Array[int]) -> int:
	if sorted_timings.is_empty():
		return 0
	var index: int = sorted_timings.size() / 2
	return sorted_timings[index]


## Returns mean as float to preserve sub-microsecond precision (post-/code-review
## BLOCK-1 / W-3: int division was truncating sub-µs means to 0 on fast desktop
## hardware; spec format `mean=N.Nµs` mandates float output for CI grep contract
## parity with peer perf tests).
func _mean(timings: Array[int]) -> float:
	if timings.is_empty():
		return 0.0
	var sum: int = 0
	for v: int in timings:
		sum += v
	return float(sum) / float(timings.size())


func _max(timings: Array[int]) -> int:
	var m: int = 0
	for v: int in timings:
		if v > m:
			m = v
	return m


# ─── Fixture sanity check ────────────────────────────────────────────────────

## Validates the programmatic fixture has the structure get_combat_modifiers
## expects. If this test fails, downstream perf measurements would be measuring
## the wrong scenario (silent perf-baseline drift if fixture changes).
func test_terrain_effect_perf_fixture_structure_matches_representative_scenario() -> void:
	# Arrange + Act
	var atk_tile: MapTileData = _grid.get_tile(ATK_COORD)
	var def_tile: MapTileData = _grid.get_tile(DEF_COORD)

	# Assert: attacker at (0,0) is PLAINS elev=0
	assert_int(atk_tile.terrain_type).override_failure_message(
		"FIXTURE: atk tile at (0,0) terrain_type expected PLAINS=%d, got %d"
		% [TerrainEffect.PLAINS, atk_tile.terrain_type]
	).is_equal(TerrainEffect.PLAINS)
	assert_int(atk_tile.elevation).override_failure_message(
		"FIXTURE: atk tile elev expected 0, got %d" % atk_tile.elevation
	).is_equal(0)

	# Assert: defender at (1,0) is FORTRESS_WALL elev=2 → delta = -2
	assert_int(def_tile.terrain_type).override_failure_message(
		"FIXTURE: def tile at (1,0) terrain_type expected FORTRESS_WALL=%d, got %d"
		% [TerrainEffect.FORTRESS_WALL, def_tile.terrain_type]
	).is_equal(TerrainEffect.FORTRESS_WALL)
	assert_int(def_tile.elevation).override_failure_message(
		"FIXTURE: def tile elev expected 2, got %d" % def_tile.elevation
	).is_equal(2)

	# Assert: 5×5 region has all 6 mandated terrain types per story-008 spec
	# (PLAINS, FOREST, HILLS, MOUNTAIN, BRIDGE, FORTRESS_WALL).
	var found: Dictionary[int, bool] = {}
	for row: int in 5:
		for col: int in 5:
			var tile: MapTileData = _grid.get_tile(Vector2i(col, row))
			found[tile.terrain_type] = true
	for required: int in [
			TerrainEffect.PLAINS, TerrainEffect.FOREST, TerrainEffect.HILLS,
			TerrainEffect.MOUNTAIN, TerrainEffect.BRIDGE, TerrainEffect.FORTRESS_WALL]:
		assert_bool(found.has(required)).override_failure_message(
			("FIXTURE: 5×5 mixed-terrain region missing terrain_type=%d."
			+ " Story-008 fixture spec mandates all 6 types for code-path coverage.")
			% required
		).is_true()


# ─── AC-1 + AC-3 + AC-4 — main perf measurement (combined) ──────────────────

## AC-1 (GDD AC-21): get_combat_modifiers p95 < 100µs on desktop substitute.
## AC-3 (Warmup):    first 10 iterations discarded; warmup ratio printed.
## AC-4 (Stats):     p50 / p95 / max / mean printed in greppable format.
##
## Combined into one test because all three consume the same 110-iteration
## measurement — splitting would triple the runtime cost without isolation
## benefit (matches map_grid_perf_test.gd combined-AC convention).
##
## AC-6 REGRESSION CANARY: the assert_int(p95).is_less(BUDGET_USEC) at the
## bottom of this function is the regression canary for terrain-effect perf.
## If a future change to get_combat_modifiers introduces a hot-path allocation,
## an extra Dictionary lookup, or a defensive Resource clone, this assertion
## fires immediately. The desktop p95 is the EARLY-WARNING bound, NOT the
## production AC-21 deploy gate (which is on-device Android, deferred to
## Polish phase).
func test_terrain_effect_perf_get_combat_modifiers_p95_under_budget() -> void:
	# Self-documenting warmup-discipline assertion (post-/code-review qa-F-4):
	# if WARMUP_ITERATIONS is ever set to 0 (e.g., during cargo-cult tuning), the
	# warmup_first_iter_usec / warmup_sum_usec computation below becomes
	# meaningless and the AC-3 advisory branch (line ~390) goes unreachable.
	# Asserting at the contract level prevents silent loss of the warmup-discipline
	# AC vs leaving the WARMUP_ITERATIONS const as the only enforcement point.
	assert_int(WARMUP_ITERATIONS).override_failure_message(
		"AC-3 contract: WARMUP_ITERATIONS must be > 0 for warmup discipline to apply."
	).is_greater(0)
	# Warmup phase — discard these timings.
	# Track first-iteration time to compute warmup ratio (cold-cache visibility).
	var warmup_first_iter_usec: int = 0
	var warmup_sum_usec: int = 0
	for i: int in WARMUP_ITERATIONS:
		var t0: int = Time.get_ticks_usec()
		var _cm: CombatModifiers = TerrainEffect.get_combat_modifiers(_grid, ATK_COORD, DEF_COORD)
		var dt: int = Time.get_ticks_usec() - t0
		if i == 0:
			warmup_first_iter_usec = dt
		warmup_sum_usec += dt

	# Measurement phase — collect 100 timing samples.
	var timings: Array[int] = []
	timings.resize(ITERATIONS)
	for i: int in ITERATIONS:
		var t0: int = Time.get_ticks_usec()
		var _cm: CombatModifiers = TerrainEffect.get_combat_modifiers(_grid, ATK_COORD, DEF_COORD)
		timings[i] = Time.get_ticks_usec() - t0

	# Compute statistics.
	var sorted_timings: Array[int] = []
	sorted_timings.assign(timings)  # G-2: .assign() preserves Array[int]; .duplicate() demotes
	sorted_timings.sort()
	var p50_usec: int = _p50(sorted_timings)
	var p95_usec: int = _p95(sorted_timings)
	var max_usec: int = _max(timings)
	var mean_usec: float = _mean(timings)

	# AC-3 warmup ratio: first iter vs steady-state p50.
	# Guard p50_usec=0 (sub-microsecond resolution can produce zero samples on
	# fast desktop hardware — get_combat_modifiers runs in nanoseconds at the C++
	# level so usec-resolution timing may underflow). Use maxi(p50_usec, 1) for
	# the ratio denominator so the print line is always sensible.
	#
	# UNDERFLOW CAVEAT (post-/code-review BLOCK-2): when warmup_first_iter_usec
	# itself underflows to 0, ratio_first prints as 0.00× — this is a TIMER
	# UNDERFLOW artifact, NOT an "instantaneous warmup" signal. Combined with the
	# p50_safe denominator clamp, ratio_first=0.00× means "first iteration was
	# sub-µs and the timer rounded down" — read it as "negligible cold-cache,
	# but precision is below measurement floor." A non-zero ratio (e.g. 3.50×)
	# is the only signal that warmup had a measurable cost worth investigating.
	var p50_safe: int = maxi(p50_usec, 1)
	var warmup_mean_usec: int = (
		warmup_sum_usec / WARMUP_ITERATIONS if WARMUP_ITERATIONS > 0 else 0
	)
	var warmup_ratio_first: float = float(warmup_first_iter_usec) / float(p50_safe)
	var warmup_ratio_mean: float = float(warmup_mean_usec) / float(p50_safe)

	# AC-4 stats output — format matches save-manager/story-007 + map-grid/story-007
	# greppable convention so a future perf-trend dashboard can ingest all three.
	# G-9: paren-wrap multi-line string + % to bind to the full concat.
	# Mean format intentionally diverges from map_grid_perf_test.gd (which returns
	# _mean as int and prints %dms): terrain-effect AC-4 spec mandates `mean=N.Nµs`
	# float precision because sub-µs samples on fast desktop hardware would
	# truncate to 0 with int division. Cross-story dashboard ingestors must
	# tolerate the per-test mean-format variance (terrain-effect=float-µs,
	# map-grid=int-ms, save-manager=int-µs).
	print(("[terrain-effect AC-21] p50=%dµs p95=%dµs max=%dµs mean=%.1fµs"
		+ " (n=%d, warmup=%d, warmup_first=%dµs warmup_mean=%dµs"
		+ " ratio_first=%.2f× ratio_mean=%.2f×)")
		% [p50_usec, p95_usec, max_usec, mean_usec,
		   ITERATIONS, WARMUP_ITERATIONS, warmup_first_iter_usec, warmup_mean_usec,
		   warmup_ratio_first, warmup_ratio_mean])

	# AC-3 advisory: warmup ratio_mean > 2.0 is "worth investigating" per spec
	# edge note. Emit push_warning for CI visibility (post-/code-review GAP-4).
	# Use ratio_mean (not ratio_first) so single-iteration timer noise doesn't
	# trip false positives — only a sustained cold-cache effect over the full
	# warmup window will exceed this threshold.
	if warmup_ratio_mean > WARMUP_RATIO_ADVISORY:
		push_warning(("AC-3 ADVISORY: warmup_ratio_mean=%.2f× exceeds %.1f×"
			+ " advisory threshold (mean of %d warmup iters / steady-state p50)."
			+ " Cold-cache cost is measurable; profile if this trend persists.")
			% [warmup_ratio_mean, WARMUP_RATIO_ADVISORY, WARMUP_ITERATIONS])

	# ADVISORY threshold (50% of budget) — push_warning for trend visibility.
	if p95_usec >= ADVISORY_USEC:
		# G-9: paren-wrap multi-line concat before %.
		push_warning(("AC-21 ADVISORY: p95=%dµs exceeds %dµs advisory threshold"
			+ " (50%% of %dµs budget). Mobile target at risk; profile before"
			+ " desktop p95 climbs further.")
			% [p95_usec, ADVISORY_USEC, BUDGET_USEC])

	# AC-1 / AC-21 HARD assertion — desktop p95 must clear the budget with headroom.
	# This is the AC-6 regression canary for the terrain-effect epic. If this
	# fires after previously passing, suspect: hot-path Resource allocation
	# regression in get_combat_modifiers, new Dictionary lookup, or virtual
	# dispatch overhead. NOT a test misconfiguration — investigate the production
	# code change that landed since the last green run.
	assert_int(p95_usec).override_failure_message(
		("AC-21 (story-008 AC-1): get_combat_modifiers p95=%dµs exceeds %dµs"
		+ " budget (FORTRESS_WALL defender + PLAINS attacker delta=-2 scenario)."
		+ " REGRESSION CANARY FIRED — investigate hot-path allocations,"
		+ " new Dict lookups, or defensive Resource clones in"
		+ " src/core/terrain_effect.gd::get_combat_modifiers."
		+ " Stats: p50=%dµs max=%dµs mean=%.1fµs warmup_first=%dµs.")
		% [p95_usec, BUDGET_USEC, p50_usec, max_usec, mean_usec, warmup_first_iter_usec]
	).is_less(BUDGET_USEC)


# ─── AC-2 — frame-budget check ──────────────────────────────────────────────

## AC-2: 100 sequential get_combat_modifiers calls within single-frame budget
## (16.6 ms = 16,600µs). This is the aggregated form of AC-21 — verifies the
## per-call budget multiplied by 100 stays under one frame. If AC-1's p95 is
## well under budget, AC-2 is automatic; the redundancy is intentional (catches
## cases where p95 is OK but mean is degraded by a heavy tail).
func test_terrain_effect_perf_frame_budget_for_100_calls() -> void:
	# Warmup: single iteration to push cold-start out of the data.
	# Note: AC-1 uses 10 warmups (per spec) for steady-state p95 statistics; AC-2
	# uses only 1 warmup because the 16,600µs frame budget provides ~166× headroom
	# over the expected ~100µs total — even a 10× cold-cache inflation on the
	# first sample would be absorbed (post-/code-review GAP-1 documentation).
	#
	# IMPORTANT — AC-2 IS NOT AN INDEPENDENT GATE. The single-warmup choice means
	# this test relies on AC-1's p95 being WELL CLEAR of budget: if AC-1's p95
	# ever climbs near the 100µs threshold, the diluted-cold-call signal here
	# (1 cold + 100 warm = ~1% inflation contribution) would still pass while the
	# per-call regression manifests only via AC-1. AC-1 is the canonical canary
	# for AC-21; AC-2 is the supplementary frame-aggregation check.
	var _w: CombatModifiers = TerrainEffect.get_combat_modifiers(_grid, ATK_COORD, DEF_COORD)

	var t0: int = Time.get_ticks_usec()
	# Loop bound uses ITERATIONS constant for cross-test consistency; if
	# ITERATIONS is ever tuned the AC-1 / AC-2 measurements stay in lockstep
	# (post-/code-review W-1).
	for i: int in ITERATIONS:
		var _cm: CombatModifiers = TerrainEffect.get_combat_modifiers(_grid, ATK_COORD, DEF_COORD)
	var elapsed_usec: int = Time.get_ticks_usec() - t0

	print(("[terrain-effect AC-FRAME-TIME] 100 calls = %dµs"
		+ " (frame budget = %dµs, %.1f%% of frame)")
		% [elapsed_usec, FRAME_BUDGET_USEC,
		   100.0 * float(elapsed_usec) / float(FRAME_BUDGET_USEC)])

	assert_int(elapsed_usec).override_failure_message(
		("AC-2 (story-008): 100 sequential get_combat_modifiers calls took %dµs,"
		+ " exceeds %dµs (16.6 ms / one 60fps frame). Aggregated form of AC-21"
		+ " indicates per-call budget regression even if p95 alone passes.")
		% [elapsed_usec, FRAME_BUDGET_USEC]
	).is_less(FRAME_BUDGET_USEC)


# ─── AC-5 — Polish-deferral marker doc-grep ─────────────────────────────────

## AC-5: this test file's header documents the AC-TARGET deferral + reactivation
## trigger. Verifies via substring grep on the file's own contents — same
## doc-coupling pattern as story-006 + story-007 used for ADR cross-refs.
##
## If a future maintainer deletes the deferral marker (e.g. when Android lands
## and the AC is reactivated), this test fires as a forcing function: the
## deletion is intentional, but the test ensures whoever does it CONSCIOUSLY
## removes the AC-5 contract — not silently dropping documentation.
func test_terrain_effect_perf_header_documents_polish_deferral_and_reactivation_trigger() -> void:
	var path: String = "res://tests/integration/core/terrain_effect_perf_test.gd"
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_that(f).override_failure_message(
		"AC-5: cannot open %s for self-doc-grep" % path
	).is_not_null()
	# Crash-safety: assert_that().is_not_null() records failure but does NOT halt
	# execution; without this guard the next get_as_text() call would null-deref
	# and convert a clean assertion failure into a runtime error (counted as
	# "errors" not "failures" in the GdUnit4 Overall Summary — see G-11 family).
	if f == null:
		return
	var contents: String = f.get_as_text()
	f.close()

	# Substring-grep for the contract terms. Using lowercase comparison to
	# tolerate minor wording drift while still requiring all key concepts.
	var lc: String = contents.to_lower()
	for term: String in [
			"ac-target",
			"deferred",
			"polish",
			"android",
			"reactivation trigger"]:
		assert_bool(lc.contains(term)).override_failure_message(
			("AC-5: header doc must contain term '%s' to document the"
			+ " on-device Android deferral + reactivation trigger contract.")
			% term
		).is_true()


# ─── AC-6 — regression-canary purpose doc-grep ──────────────────────────────

## AC-6: the perf test's hard threshold serves as a regression canary —
## explicit comment noting this purpose so future maintainers understand that
## desktop p95 is the EARLY-WARNING bound, not the AC-21 production deploy
## gate. Same doc-coupling pattern as AC-5.
func test_terrain_effect_perf_documents_regression_canary_purpose() -> void:
	var path: String = "res://tests/integration/core/terrain_effect_perf_test.gd"
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	assert_that(f).override_failure_message(
		"AC-6: cannot open %s for self-doc-grep" % path
	).is_not_null()
	# Crash-safety: see AC-5 test for rationale (GdUnit4 assert_that records
	# failure but does NOT halt execution).
	if f == null:
		return
	var contents: String = f.get_as_text()
	f.close()

	# Require the term "regression canary" — a specific phrase callers can grep
	# for to find the canary contract anywhere in the project.
	var lc: String = contents.to_lower()
	assert_bool(lc.contains("regression canary")).override_failure_message(
		"AC-6: must document 'regression canary' purpose so future maintainers"
		+ " understand desktop p95 is the early-warning bound, not the production"
		+ " deploy gate (which is on-device mobile, deferred to Polish)."
	).is_true()

	# Also require the early-warning framing to make the desktop-vs-mobile
	# asymmetry explicit (paired with the deferral marker grepped in AC-5).
	assert_bool(lc.contains("early-warning") or lc.contains("early warning")).override_failure_message(
		"AC-6: must frame the desktop p95 threshold as an 'early-warning' or"
		+ " 'early warning' bound — explicit contrast with the production"
		+ " on-device deploy gate."
	).is_true()
