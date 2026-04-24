# Story 007: Performance baseline (desktop substitute)

> **Epic**: map-grid
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-20
> **Estimate**: 2-3 hours desktop (stress fixture generator + perf test harness + p50/p95/max stats + AC-WARMUP ratio); mobile AC-TARGET deferred to Polish — matches save-manager story-007 ~30min-3h actual

## Context

**GDD**: `design/gdd/map-grid.md`
**Requirement**: `TR-map-grid-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 Map/Grid Data Model
**ADR Decision Summary**: AC-PERF-2 mandates `get_movement_range(move_range=10)` completes in <16 ms on a 40×30 map, mid-range Android. ADR-0004 §Verification Required documents this as a blocking pre-ship check; expected <5 ms with packed caches + 4-dir + early termination. ADR-0004 R-1 pre-authorizes fallback strategies (map cap 32×24, flow-field precompute, GDExtension C++) if mobile target isn't met — the public API stays stable.

**Engine**: Godot 4.6 | **Risk**: LOW (desktop), MEDIUM (mobile — deferred)
**Engine Notes**: `Time.get_ticks_usec()` for microsecond timing (pre-cutoff stable). Desktop substitute on macOS arm64 / Linux x86_64 establishes a correctness + order-of-magnitude baseline; mobile AC-TARGET validation deferred to Polish phase per save-manager story-007 precedent.

**Control Manifest Rules (Foundation layer + Core layer)**:
- Guardrail: `get_movement_range()` CPU <16 ms on 40×30, move_range=10, mid-range Android (ADR-0004 AC-PERF-2 / TR-map-grid-006)
- Guardrail: Dijkstra with packed caches CPU <5 ms expected (4-dir + early termination)
- Guardrail: Active battle map total memory <150 KB; per-query scratch buffers reused (no per-query allocation)
- Required: Benchmark uses a fixed fixture, not randomized input — deterministic perf comparison across runs
- Forbidden: Shrink max map size below 40×30 in production without ADR amendment — R-1 fallback option reserved for Polish phase if mobile target missed

---

## Acceptance Criteria

*From GDD `design/gdd/map-grid.md` §AC-PERF-1, §AC-PERF-2 + ADR-0004 V-1, §Verification Required, §Risks R-1:*

- [ ] **AC-DESKTOP**: `get_movement_range(unit_id=1, move_range=10, unit_type=INFANTRY)` on the 40×30 stress fixture completes with p95 < 16 ms on the developer desktop (macOS arm64 or Linux x86_64); 100-iteration measurement with warmup
- [ ] **AC-BREAKDOWN**: per-subcomponent timings captured — (a) Dijkstra inner loop (initial queue seed → queue exhaustion), (b) result filtering (land-tile collection), (c) scratch buffer reset cost; each subcomponent p95 reported in test output
- [ ] **AC-WARMUP**: warmup ratio (first-iteration time vs steady-state p50) ≤ 3× — detects pathological cold-start behaviour; aligned with save-manager story-007 convention
- [ ] **AC-FRAME-TIME**: AC-PERF-1 synthetic frame-time sampling — 100 sequential `get_movement_range` calls with `Engine.get_frames_drawn()` + `Time.get_ticks_usec()` between; no 3-consecutive-sample run exceeds 16.6 ms (desktop substitute for on-device frame-time stability)
- [ ] **AC-TARGET**: on-device (mid-range Android) AC-PERF-2 validation — **DEFERRED** to Polish phase per save-manager story-007 precedent. Deferral sanctioned with documented trigger: "unblock target-device verification when Android export pipeline is first green". Tracked explicitly in story §7 below.
- [ ] Stress fixture authored at `tests/fixtures/maps/stress_40x30.tres` — full 40×30 map with mixed terrain distribution: 60% PLAINS, 15% HILLS, 10% FOREST, 10% ROAD, 5% MOUNTAIN; NO FORTRESS_WALL (pathfinding-unfriendly tiles bias results); 5-10 scattered ENEMY_OCCUPIED obstacles to exercise the enemy-blocks-ally-passes rule
- [ ] Benchmark reproducible — 10 consecutive full-suite runs produce p95 values within ±10% variance; measurement framework documented in test file header

---

## Implementation Notes

*Derived from ADR-0004 §Verification Required, save-manager story-007 precedent, GDD §AC-PERF-1/2:*

- Test file location: `tests/integration/core/map_grid_perf_test.gd` (integration layer, NOT unit — per save-manager story-007 convention; integration tree is where whole-system timing tests live)
- Alternative: `tests/performance/map_grid_perf_test.gd` — if the project's test runner conventions prefer a dedicated `performance/` subtree; check existing save-manager story-007 location and mirror. The scope/scaffolding GDD notes `tests/performance/` so default there; if no such folder exists, create it here.
- Measurement primitives: `Time.get_ticks_usec()` (microsecond resolution); wrap measured-region entry/exit in a helper `_measure_usec(callable: Callable) -> int`.
- Statistics: compute p50, p95, max, mean across 100 iterations; report all four in the failure message if AC fails (debuggability). Use an in-memory `PackedInt64Array` of timing samples; sort; pick percentile indices.
- Warmup: first 10 iterations discarded OR measured separately and compared for AC-WARMUP. DO NOT feed warmup samples into the p95 computation.
- Stress fixture authoring: write a Python-free GDScript helper that procedurally builds the 40×30 `MapResource` with the specified terrain distribution, then calls `ResourceSaver.save(res, "res://tests/fixtures/maps/stress_40x30.tres")`. Check in the `.tres` file as a fixed asset (deterministic perf baseline across runs + machines). Fixture-generation helper lives at `tests/fixtures/generate_stress_40x30.gd` — invoked once during story-007 implementation, not at every test run.
- If `tests/fixtures/maps/stress_40x30.tres` already exists at story kickoff, skip generation; use the existing file.
- The 5-10 enemy obstacles: place at deterministic coords (e.g., `[(5,5), (12,8), (20,15), (30,20), (8,22)]`) — NOT randomized — for reproducibility.
- AC-BREAKDOWN subcomponent measurement: instrument the Dijkstra inner loop in `map_grid.gd` with optional `#DEBUG_TIMING` conditional blocks is NOT the approach (violates zero-overhead-in-prod principle). Instead: in the test, call the three phases via a test-exposed seam. If the production API doesn't expose seam points, measure at `get_movement_range` entry/exit only and document AC-BREAKDOWN as a single aggregate number with breakdown deferred to Polish.
- AC-TARGET deferral documentation: in story §7 below, include: (a) deferral rationale (no Android export pipeline online yet in Production phase), (b) reactivation trigger ("when first Android export build is green"), (c) fallback per ADR-0004 R-1 if mobile target missed. Same pattern as save-manager story-007 TD-031.
- Regression sensitivity: AC-DESKTOP p95 bound is DEFENSIVE (50–100× overhead allowed for desktop-vs-mobile gap). Hard bound is 50 ms desktop p95; advisory bound is 20 ms. Any p95 >20 ms triggers a `push_warning` + a story-007 TD batch entry for investigation before epic close.
- Regression suite: this test lives in `tests/integration/core/` and MUST run on every CI (not `tests/performance/` which may be excluded from fast CI path).

---

## Out of Scope

*Handled by neighbouring stories / phases — do not implement here:*

- Story 005: the Dijkstra algorithm itself (this story only benchmarks it)
- Story 008: inspector 40×30 `.tres` load-without-hang manual verification (V-7 — a different failure mode than this story's perf benchmark)
- **Polish phase (deferred)**: on-device mobile AC-TARGET validation on mid-range Android (Moto G series / equivalent); Android export pipeline activation
- **Polish phase (deferred, if needed)**: ADR-0004 R-1 fallbacks — map cap 32×24, flow-field precompute, GDExtension C++

---

## QA Test Cases

*Authored from GDD + ADR directly (lean mode).*

- **AC-DESKTOP**: `get_movement_range(move_range=10)` p95 <16 ms desktop
  - Given: stress_40x30.tres loaded into MapGrid; unit placed at (20, 15); 100 measured iterations (+10 warmup)
  - When: each iteration calls `get_movement_range(unit_id=1, move_range=10, unit_type=INFANTRY)` wrapped by `Time.get_ticks_usec()` delta
  - Then: p95 timing < 16000 us (16 ms) as HARD assertion; p95 <20000 us advisory; report p50/p95/max/mean in test output
  - Edge cases: 100-iteration sample is fixed — shrinking to 10 samples risks noise; growing to 1000 risks slow CI; 100 is the precedent from save-manager story-007

- **AC-BREAKDOWN**: per-phase timing attribution (if seam available)
  - Given: same setup as AC-DESKTOP
  - When: internal seams measure (a) queue seed + pop loop, (b) land-tile filter, (c) scratch reset
  - Then: sum of subcomponents ≈ total (±5% overhead for instrumentation); each subcomponent p95 reported
  - Edge cases: if no test-exposed seam, AC marked "aggregate only — breakdown deferred"; not a blocking failure, but logged as story-007 TD

- **AC-WARMUP**: warmup ratio ≤ 3×
  - Given: first-iteration timing vs post-warmup p50
  - When: ratio computed
  - Then: `first_iter_usec / p50_usec <= 3.0`; if exceeded, `push_warning` + TD entry investigating cold-start pathology (likely JIT / cache warm-up artifact — acceptable on desktop but worth logging)
  - Edge cases: if `p50_usec == 0` (unlikely but defensive): skip ratio check, log

- **AC-FRAME-TIME**: AC-PERF-1 synthetic frame-time stability
  - Given: 100 sequential `get_movement_range` calls; for each call i, record `start_usec[i]` and `end_usec[i]`
  - When: compute per-sample `duration_usec[i]`
  - Then: NO 3-consecutive-sample window `i, i+1, i+2` where all three exceed 16600 us; report indices of any 2-consecutive >16ms runs as warnings
  - Edge cases: desktop substitute — this is an order-of-magnitude check, NOT the on-device AC-PERF-1 contract (which requires real Android frame sampling)

- **AC-TARGET**: deferred — documented, not executed
  - Given: mobile Android export pipeline not yet online
  - When: Polish-phase reactivation trigger
  - Then: this AC is explicitly marked "DEFERRED" in `/story-done`; sign-off accepts deferral with story §7 documentation of trigger + fallback plan
  - Edge cases: same deferral pattern as save-manager story-007's AC-TARGET

- **STRESS FIXTURE**: 40×30 map structure integrity
  - Given: `tests/fixtures/maps/stress_40x30.tres` loaded into MapGrid
  - When: validation + basic query
  - Then: validator returns true (no load errors); `get_map_dimensions() == Vector2i(40, 30)`; `get_occupied_tiles(FACTION_ENEMY).size() >= 5` (confirms enemy obstacles present)
  - Edge cases: if fixture missing at test start, the test skips with instruction to run `tests/fixtures/generate_stress_40x30.gd` once

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/core/map_grid_perf_test.gd` — must exist and pass AC-DESKTOP, AC-WARMUP, AC-FRAME-TIME, STRESS FIXTURE (4 hard-gate ACs); AC-BREAKDOWN may be deferred if no test-exposed seam; AC-TARGET explicitly deferred
- `tests/fixtures/maps/stress_40x30.tres` — 40×30 stress fixture committed as deterministic asset
- `tests/fixtures/generate_stress_40x30.gd` — one-shot generator script (committed for reproducibility, not run per test)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005 (Dijkstra implementation is what's being benchmarked), Story 004 (ENEMY_OCCUPIED obstacle placement uses mutation API), Story 003 (validator guarantees fixture integrity)
- Unlocks: ADR-0004 V-1 partial verification (desktop substitute); Polish-phase AC-TARGET on-device benchmark; epic DoD item "V-1 performance: get_movement_range() <16 ms on 40×30" (desktop sign-off + deferred mobile)

---

## §7 — AC-TARGET deferral documentation

Pattern mirrored from save-manager/story-007.

**Why deferred at story-007 close**: AC-PERF-2 is explicitly "mid-range Android target". As of 2026-04-24, the Android export pipeline for this project is not yet online — devops-engineer has not established an automated Android export path, and no Moto G–class test device is wired into the QA lab. A desktop substitute baseline (AC-DESKTOP) establishes correctness and an order-of-magnitude upper bound: if desktop p95 is already >16 ms, mobile will never meet target, and R-1 fallbacks must be triggered immediately. If desktop p95 is <1 ms (as ADR-0004 expects), mobile remains plausible but un-verified.

**Reactivation trigger**: first Android export build green on CI. Release-manager opens a Polish-phase AC-TARGET follow-up story at that point.

**Fallback if target missed on-device** (ADR-0004 R-1, ordered by complexity):
  (a) reduce max map size from 40×30 to 32×24 (affects GDD CR-1 bounds — triggers ADR amendment and Game Designer consultation)
  (b) precompute a flow-field for `get_movement_range()` (expected +1-2 ms per battle-enter, -10+ ms per query)
  (c) move Dijkstra to GDExtension C++ (invokes godot-gdextension-specialist)

**None of the fallbacks change the public `get_movement_range` signature or ADR-0004 decisions** — the API surface stays stable across fallback paths.
