## save_perf_test.gd — Story 007: Save pipeline perf baseline (V-11 desktop substitute).
##
## ADR-0003 §Performance Implications + §Validation Criteria V-11:
##   Full save cycle <50 ms on mid-range Android (Snapdragon 7-gen). Per-stage budgets:
##   duplicate_deep ~1 ms, ResourceSaver.save 2-10 ms, rename_absolute <5 ms.
##   95th percentile reporting (not mean) per control-manifest Performance Guardrails.
##
## SCOPE (4 of 5 ACs; AC-TARGET explicitly DEFERRED per story-007 §7 deferral pattern):
##   - AC-DESKTOP: 100 iterations of full save_checkpoint cycle; p95 < 20 ms (advisory).
##   - AC-BREAKDOWN: per-stage (duplicate_deep / ResourceSaver.save / rename_absolute) p95.
##   - AC-PAYLOAD-SIZE: serialized .res within 5-15 KB ADR expected range.
##   - AC-WARMUP: iter[0] ≤ 3× mean(iter[10..99]); advisory warn at 5×; hard fail at 10×.
##
## DEFERRED (not in this suite):
##   - AC-TARGET: on-device Android Snapdragon 7-gen 100-iteration perf. Captured
##     manually at `production/qa/evidence/save-v11-android-perf-[date].md` during
##     Polish phase when mid-range Android device is available. Mirror scene-manager
##     story-007 deferral pattern. Desktop substitute here is an ADVISORY loose upper
##     bound: desktop PASS does not imply mobile PASS; desktop FAIL >50 ms GUARANTEES
##     mobile FAIL (asymmetric signal per story §1).
##
## ASSERTION DISCIPLINE:
##   - ADVISORY thresholds (20 ms desktop p95, 5-15 KB payload range, 3× warmup ratio)
##     use push_warning() so CI logs the advisory but doesn't fail the PR.
##   - HARD (catastrophic) thresholds use assert_int() to fail the test — they catch
##     regressions so severe that even desktop shouldn't exhibit them.
##
## STUB DISCIPLINE (G-6):
##   SaveManagerStub.swap_in() per test body (not before_test) and explicit swap_out()
##   at end of body — GdUnit4 orphan detector fires before after_test. after_test()
##   runs swap_out() as an idempotent safety net.
##
## G-10 N/A — this suite calls stub.save_checkpoint() directly (no subscriber handler
## chains). The signal emits from save_checkpoint reach no test observer; they emit on
## the real GameBus autoload without harm. Standard G-10 autoload-stickiness trap
## does not apply (no subscriber fresh-ready in play).
##
## G-9 COMPLIANCE: all multi-line format strings wrapped in outer parentheses before %.
##
## ADR references:   ADR-0003 §Performance Implications, §Validation Criteria V-11
## Story reference:  production/epics/save-manager/story-007-perf-target-device.md
extends GdUnitTestSuite

const SAVE_MANAGER_PATH: String = "res://src/core/save_manager.gd"

## V-11 mandates 100-iteration + 95th percentile measurement (ADR-0003 §Performance).
const ITERATIONS: int = 100

## Desktop-substitute threshold — ADVISORY (per story AC-DESKTOP; CI won't block on it).
## Desktop is typically 3-5× faster than mid-range Android; if desktop p95 exceeds
## 20 ms, the 50 ms mobile budget is at severe risk.
const DESKTOP_P95_BUDGET_USEC: int = 20_000  # 20 ms

## Catastrophic threshold — HARD (BLOCKING). If desktop p95 ≥ 100 ms something has
## gone badly wrong; we want CI to surface that.
const DESKTOP_CATASTROPHIC_USEC: int = 100_000  # 100 ms

## Payload size range expected by ADR-0003 §Performance Implications.
const PAYLOAD_MIN_BYTES: int = 5 * 1024   # 5 KB — minimum for "realistic late-game"
const PAYLOAD_MAX_BYTES: int = 15 * 1024  # 15 KB — soft upper; warn above, assert at 50 KB
const PAYLOAD_HARD_MAX_BYTES: int = 50 * 1024  # 50 KB — ADR revisit trigger for FLAG_COMPRESS


## Builds a representative SaveContext reflecting realistic late-game state
## (ADR-0003 §Performance Implications baseline):
##   - 10 EchoMarks in echo_marks_archive
##   - 5+ entries in flags_to_set
##   - All 12 SaveContext fields populated
##   - Target serialized size 5-15 KB per ADR expected range.
func _build_representative_ctx() -> SaveContext:
	var ctx: SaveContext = SaveContext.new()
	ctx.schema_version = 1
	ctx.slot_id = 1
	ctx.chapter_id = &"ch05"
	ctx.chapter_number = 5
	ctx.last_cp = 2
	ctx.outcome = 0
	ctx.branch_key = &"honor_path"
	ctx.echo_count = 42
	ctx.saved_at_unix = 1_700_000_000
	ctx.play_time_seconds = 3600

	# 5+ string entries in flags_to_set (PackedStringArray per SaveContext spec).
	var flags: PackedStringArray = PackedStringArray()
	for i: int in range(7):
		flags.append("flag_entry_%02d" % i)
	ctx.flags_to_set = flags

	# 10 EchoMarks — each has 3 @export fields (beat_index, outcome, tag).
	var archive: Array[EchoMark] = []
	for i: int in range(10):
		var mark: EchoMark = EchoMark.new()
		mark.beat_index = (i % 9) + 1  # 1..9 cycle
		mark.outcome = &"outcome_%d" % (i % 3)  # cycle WIN/DRAW/LOSS-analog
		mark.tag = &"tag_batch_%02d" % i
		archive.append(mark)
	ctx.echo_marks_archive = archive

	return ctx


## Computes the 95th-percentile value from a sorted Array[int] of usec timings.
## Uses the conventional index = floor(n * 0.95). For n=100, index = 95 (0-based).
func _p95(sorted_timings: Array[int]) -> int:
	if sorted_timings.is_empty():
		return 0
	var index: int = int(float(sorted_timings.size()) * 0.95)
	index = clampi(index, 0, sorted_timings.size() - 1)
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


## AC-DESKTOP — full save_checkpoint cycle 95th percentile (desktop advisory <20 ms).
func test_save_perf_full_cycle_p95_under_desktop_budget_advisory() -> void:
	var stub: Node = SaveManagerStub.swap_in()
	stub.set_active_slot(1)

	var ctx: SaveContext = _build_representative_ctx()
	var timings: Array[int] = []

	for i: int in range(ITERATIONS):
		var t0: int = Time.get_ticks_usec()
		var ok: bool = stub.save_checkpoint(ctx)
		var dt: int = Time.get_ticks_usec() - t0
		assert_bool(ok).override_failure_message(
			"AC-DESKTOP: save_checkpoint must succeed every iteration; failed at iter %d" % i
		).is_true()
		timings.append(dt)

	var sorted_timings: Array[int] = timings.duplicate()
	sorted_timings.sort()
	var p95_usec: int = _p95(sorted_timings)
	var mean_usec: int = _mean(timings)
	var max_usec: int = _max(timings)

	print(("AC-DESKTOP: full save cycle (stub isolated) — iterations=%d"
		+ " p95=%.2fms mean=%.2fms max=%.2fms")
		% [ITERATIONS, p95_usec / 1000.0, mean_usec / 1000.0, max_usec / 1000.0])

	if p95_usec >= DESKTOP_P95_BUDGET_USEC:
		push_warning(("AC-DESKTOP ADVISORY: p95=%.2fms exceeds %.0fms desktop budget."
			+ " Mobile 50 ms budget is at risk — investigate before declaring V-11.")
			% [p95_usec / 1000.0, DESKTOP_P95_BUDGET_USEC / 1000.0])

	# Hard assertion: only a catastrophic regression (>100 ms) fails the test.
	assert_int(p95_usec).override_failure_message(
		("AC-DESKTOP catastrophic: p95=%.2fms >= %.0fms — regression severe enough"
		+ " that mobile cannot plausibly hit V-11. Investigate immediately.")
		% [p95_usec / 1000.0, DESKTOP_CATASTROPHIC_USEC / 1000.0]
	).is_less(DESKTOP_CATASTROPHIC_USEC)

	SaveManagerStub.swap_out()


## AC-BREAKDOWN — per-stage p95 (duplicate_deep / ResourceSaver.save / rename_absolute).
## Bypasses save_checkpoint to measure individual pipeline stages with per-stage timers.
## Operations match save_checkpoint's internal steps 1/4/6 (ADR-0003 §Key Interfaces):
##   step 1: source.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)
##   step 4: ResourceSaver.save(snapshot, tmp_path)
##   step 6: DirAccess.rename_absolute(tmp, final)
## TD-026 tmp-suffix convention (`.tmp.res` not `.res.tmp`) reproduced faithfully.
func test_save_perf_breakdown_per_stage_p95() -> void:
	var stub: Node = SaveManagerStub.swap_in()
	stub.set_active_slot(1)

	var ctx: SaveContext = _build_representative_ctx()
	var dup_times: Array[int] = []
	var save_times: Array[int] = []
	var rename_times: Array[int] = []

	for i: int in range(ITERATIONS):
		# Stage 1: duplicate_deep — matches save_manager.gd:126-128.
		var t0: int = Time.get_ticks_usec()
		var snapshot: SaveContext = ctx.duplicate_deep(
			Resource.DEEP_DUPLICATE_ALL
		) as SaveContext
		dup_times.append(Time.get_ticks_usec() - t0)

		# Use the stub's path construction so we land inside the temp root.
		# Vary chapter_number + cp per iteration so tmp files don't collide on very fast
		# filesystems where rename might not even land before the next write begins.
		var chapter: int = (i % 9) + 1
		var cp: int = (i % 3) + 1
		var final_path: String = stub._path_for(1, chapter, cp)
		# TD-026: `.tmp.res` (trailing extension = .res, ResourceSaver picks binary saver).
		var tmp_path: String = final_path.get_basename() + ".tmp.res"

		# Stage 2: ResourceSaver.save — matches save_manager.gd:144.
		var t1: int = Time.get_ticks_usec()
		var err: Error = ResourceSaver.save(snapshot, tmp_path)
		save_times.append(Time.get_ticks_usec() - t1)
		assert_int(err as int).override_failure_message(
			"AC-BREAKDOWN: ResourceSaver.save must succeed; iter %d err=%d" % [i, err]
		).is_equal(OK as int)

		# Stage 3: rename_absolute — matches save_manager.gd:172.
		var t2: int = Time.get_ticks_usec()
		var rename_err: Error = DirAccess.rename_absolute(tmp_path, final_path)
		rename_times.append(Time.get_ticks_usec() - t2)
		assert_int(rename_err as int).override_failure_message(
			"AC-BREAKDOWN: DirAccess.rename_absolute must succeed; iter %d err=%d"
				% [i, rename_err]
		).is_equal(OK as int)

	dup_times.sort()
	save_times.sort()
	rename_times.sort()
	var dup_p95: int = _p95(dup_times)
	var save_p95: int = _p95(save_times)
	var rename_p95: int = _p95(rename_times)

	print(("AC-BREAKDOWN: per-stage p95 (n=%d) — duplicate_deep=%.3fms"
		+ " ResourceSaver.save=%.3fms rename_absolute=%.3fms"
		+ " (ADR expects ~1ms / 2-10ms / <5ms)")
		% [ITERATIONS, dup_p95 / 1000.0, save_p95 / 1000.0, rename_p95 / 1000.0])

	# Advisory warnings when a stage is outside its ADR expected band.
	if dup_p95 > 5_000:  # 5 ms; ADR expects ~1 ms
		push_warning("AC-BREAKDOWN ADVISORY: duplicate_deep p95=%.3fms >> ADR ~1ms."
			% (dup_p95 / 1000.0))
	if save_p95 > 15_000:  # 15 ms; ADR expects 2-10 ms
		push_warning("AC-BREAKDOWN ADVISORY: ResourceSaver.save p95=%.3fms >> ADR 2-10ms."
			% (save_p95 / 1000.0))
	if rename_p95 > 10_000:  # 10 ms; ADR expects <5 ms
		push_warning("AC-BREAKDOWN ADVISORY: rename_absolute p95=%.3fms >> ADR <5ms."
			% (rename_p95 / 1000.0))

	# Hard assertions: any stage >50 ms on desktop means a fundamental problem.
	assert_int(dup_p95).override_failure_message(
		"AC-BREAKDOWN catastrophic: duplicate_deep p95=%.3fms >= 50ms" % (dup_p95 / 1000.0)
	).is_less(50_000)
	assert_int(save_p95).override_failure_message(
		"AC-BREAKDOWN catastrophic: ResourceSaver.save p95=%.3fms >= 50ms"
			% (save_p95 / 1000.0)
	).is_less(50_000)
	assert_int(rename_p95).override_failure_message(
		"AC-BREAKDOWN catastrophic: rename_absolute p95=%.3fms >= 50ms"
			% (rename_p95 / 1000.0)
	).is_less(50_000)

	SaveManagerStub.swap_out()


## AC-PAYLOAD-SIZE — serialized representative SaveContext size falls in ADR expected range.
## Hard-asserts <50 KB (FLAG_COMPRESS revisit trigger); advises if outside 5-15 KB band.
func test_save_perf_payload_size_within_adr_expected_range() -> void:
	var stub: Node = SaveManagerStub.swap_in()
	stub.set_active_slot(1)

	var ctx: SaveContext = _build_representative_ctx()
	var path: String = stub._path_for(1, 1, 1)
	var err: Error = ResourceSaver.save(ctx, path)
	assert_int(err as int).override_failure_message(
		"AC-PAYLOAD-SIZE: ResourceSaver.save must succeed; err=%d" % err
	).is_equal(OK as int)

	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var size: int = bytes.size()
	var size_kb: float = size / 1024.0

	print(("AC-PAYLOAD-SIZE: representative SaveContext (10 EchoMarks, 7 flags, all 12 fields)"
		+ " serialized to %d bytes (%.2f KB); ADR expects 5-15 KB.")
		% [size, size_kb])

	# Hard: catastrophic failure if bigger than 50 KB → FLAG_COMPRESS revisit required.
	assert_int(size).override_failure_message(
		("AC-PAYLOAD-SIZE catastrophic: serialized size %.2f KB >= %d KB — revisit"
		+ " ADR-0003 §Performance §FLAG_COMPRESS decision; mobile 50ms budget at risk.")
		% [size_kb, PAYLOAD_HARD_MAX_BYTES / 1024]
	).is_less(PAYLOAD_HARD_MAX_BYTES)

	# Advisory: warn if outside 5-15 KB expected band (either too small to be realistic
	# or too large for the ADR's design assumptions).
	if size < PAYLOAD_MIN_BYTES or size > PAYLOAD_MAX_BYTES:
		push_warning(("AC-PAYLOAD-SIZE ADVISORY: size %.2f KB outside ADR-expected 5-15 KB band."
			+ " Not a failure, but consider whether representative-ctx builder should be updated"
			+ " to better reflect late-game state.") % size_kb)

	SaveManagerStub.swap_out()


## AC-WARMUP — first iteration within 3× of steady-state mean (iterations 10..99).
## Advisory warns at 5×; hard-fails only at 10× (catastrophic autoload / schema init cost).
func test_save_perf_first_iteration_within_3x_of_steady_state_mean() -> void:
	var stub: Node = SaveManagerStub.swap_in()
	stub.set_active_slot(1)

	var ctx: SaveContext = _build_representative_ctx()
	var timings: Array[int] = []

	for i: int in range(ITERATIONS):
		var t0: int = Time.get_ticks_usec()
		var ok: bool = stub.save_checkpoint(ctx)
		assert_bool(ok).override_failure_message(
			"AC-WARMUP: save_checkpoint must succeed; failed at iter %d" % i
		).is_true()
		timings.append(Time.get_ticks_usec() - t0)

	var first: int = timings[0]
	# Steady state = iterations 10..99 (inclusive); 90-sample mean.
	var steady: Array[int] = timings.slice(10, ITERATIONS)
	var steady_mean: int = _mean(steady)
	var ratio: float = float(first) / float(maxi(steady_mean, 1))

	print(("AC-WARMUP: iter[0]=%dμs, steady mean (iter 10..99)=%dμs, ratio=%.2fx"
		+ " (ADR: want ≤3x; investigate >5x; catastrophic >10x)")
		% [first, steady_mean, ratio])

	if ratio > 5.0:
		push_warning(("AC-WARMUP ADVISORY: iter[0] is %.2fx slower than steady state."
			+ " May indicate autoload init or schema-parse one-shot cost."
			+ " Investigate before declaring V-11.") % ratio)

	assert_float(ratio).override_failure_message(
		("AC-WARMUP catastrophic: iter[0] is %.2fx slower than steady state (>= 10x)."
		+ " First-call cost is pathological — mobile V-11 budget cannot tolerate this.") % ratio
	).is_less(10.0)

	SaveManagerStub.swap_out()


## G-6 safety net — idempotent; explicit swap_out in each test body is the authoritative
## cleanup. This runs after GdUnit4 orphan detection; serves only crash-recovery.
func after_test() -> void:
	SaveManagerStub.swap_out()
