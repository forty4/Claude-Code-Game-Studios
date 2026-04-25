# Story 008: Performance baseline (desktop substitute) — AC-21 <0.1ms benchmark

> **Epic**: terrain-effect
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-20
> **Estimate**: 1.5-2 hours (1 perf test file + warmup discipline + statistics output; matches save-manager/story-007 + map-grid/story-007 precedent)

## Context

**GDD**: `design/gdd/terrain-effect.md` §AC-21 (query latency)
**Requirement**: `TR-terrain-effect-013` (AC-21)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008 Terrain Effect System
**ADR Decision Summary**: `get_combat_modifiers()` <0.1ms per call on mid-range Android target (100 calls per frame at 60fps budget). ADR-0008 §Performance Implications projects <0.01ms expected (10× headroom under the AC budget); two O(1) Dictionary lookups + arithmetic + defensive Resource alloc. Per godot-specialist 2026-04-25 Item 11, this estimate is credible — Dictionary access at the C++ layer is nanoseconds, GDScript dispatch overhead is ~1-5µs per call.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Per-call timing measurement via `Time.get_ticks_usec()` deltas; statistics output (p50, p95, max, mean over warmup-discounted iterations) for CI log capture and regression-baseline comparison. Pattern reused verbatim from save-manager/story-007 + map-grid/story-007 (the third reuse — by now the pattern is canonical for the project's perf-baseline stories). On-device Android validation deferred to Polish phase per the same precedent.

**Control Manifest Rules (Core layer)**:
- Required: warmup discipline — discard the first N iterations from statistics (cold-cache, JIT compile-equivalent on GDScript side); ADR-0008 §Performance + save-manager precedent suggests N=10 minimum, possibly raise to 20 for cold-cache CI conservatism (TD-032 A-27 carry-over note from map-grid story-007 may apply once that lands)
- Required: AC-21 hard assertion — p95 < 0.1ms (100µs); failure blocks the story per BLOCKING test-evidence rule
- Required: ADVISORY thresholds via `push_warning` — e.g., p99 over 50% of budget triggers an advisory (matches save-manager/story-007 pattern)
- Required: deferred-to-Polish marker — on-device Android timing is NOT validated this story (no Android export pipeline yet); reactivation trigger documented in story §Dependencies
- Forbidden: hardware-specific assumptions — the desktop substitute timing must be MEANINGFULLY SLACK relative to the AC's mobile budget so a reasonable mid-range Android device WILL pass the production AC; if desktop p95 is at 95µs (close to 100µs) but desktop is 4× faster than target Android → the design FAILS the AC at deploy. ADR-0008's 10× headroom estimate (<0.01ms expected vs 0.1ms budget) gives plenty of slack; if observed desktop p95 is comparable to budget rather than 10× under, treat as red flag and investigate before passing

---

## Acceptance Criteria

*From GDD AC-21 + ADR-0008 §Performance Implications + §Verification Required §1 + project precedent:*

- [ ] `tests/integration/core/terrain_effect_perf_test.gd` test file exists and is discovered by GdUnit4
- [ ] Test fixture: programmatic 5×5 MapGrid with mixed terrain (PLAINS, HILLS, FOREST, MOUNTAIN, BRIDGE, FORTRESS_WALL coverage so the timed scenarios touch the elevation table + bridge flag + the cap-clamp paths)
- [ ] AC-DESKTOP: 100 iterations of `get_combat_modifiers(grid, atk, def)` on a representative scenario (FORTRESS_WALL defender + delta=−2 to exercise both lookup paths + clamp); p95 latency < 100µs (0.1ms) on desktop substitute
- [ ] AC-WARMUP: discard first 10 iterations from statistics; verify warmup discipline applied (warmup_ratio = first_10_mean / steady_state_mean printed to log)
- [ ] AC-FRAME-TIME: simulate "100 calls per frame" by running 100 sequential `get_combat_modifiers` calls within a single test function; total wall-clock time < 16.6ms (single-frame budget) — this validates the per-call AC-21 budget at the aggregated frame-budget level
- [ ] AC-STATS: stats output (p50, p95, max, mean over post-warmup iterations) printed to test log via `print()` for CI capture
- [ ] AC-TARGET (DEFERRED): on-device Android validation deferred to Polish phase per save-manager/story-007 + map-grid/story-007 precedent; reactivation trigger documented inline ("when Android export pipeline lands and a mid-range device is available, run this test on-device with the same fixture")
- [ ] AC-REGRESSION-CANARY: as in map-grid/story-007, the perf test serves as a regression canary — if a future change causes p95 to exceed budget, this test fires immediately; the desktop result is the early-warning bound, not the production gate

---

## Implementation Notes

*Derived from ADR-0008 §Performance Implications + project precedent (save-manager/story-007 + map-grid/story-007):*

- **Reference test structure** (port from map-grid/story-007 perf test, adapted to Terrain Effect):
  ```gdscript
  extends GdUnitTestSuite

  const ITERATIONS: int = 100
  const WARMUP: int = 10
  const BUDGET_USEC: int = 100  # 0.1ms = 100µs (AC-21)
  const FRAME_BUDGET_USEC: int = 16_600  # 16.6ms

  var _grid: MapGrid

  func before_test() -> void:
      TerrainEffect.reset_for_tests()
      TerrainEffect.load_config()  # explicit; perf test should not include lazy-init in stats
      _grid = _build_5x5_fixture()
      add_child(_grid)

  func after_test() -> void:
      _grid.queue_free()
      TerrainEffect.reset_for_tests()

  func test_get_combat_modifiers_p95_under_budget() -> void:
      var atk := Vector2i(0, 0)  # PLAINS elev=0
      var def := Vector2i(2, 2)  # FORTRESS_WALL elev=2 (representative)
      var samples: Array[int] = []
      for i in range(ITERATIONS + WARMUP):
          var t0 := Time.get_ticks_usec()
          TerrainEffect.get_combat_modifiers(_grid, atk, def)
          var t1 := Time.get_ticks_usec()
          if i >= WARMUP:
              samples.append(t1 - t0)
      samples.sort()
      var p50 := samples[ITERATIONS / 2]
      var p95 := samples[(ITERATIONS * 95) / 100]
      var max_us := samples[samples.size() - 1]
      var mean_us := _mean(samples)
      print("[terrain-effect AC-21] p50=%dµs p95=%dµs max=%dµs mean=%.1fµs (n=%d, warmup=%d)" % [p50, p95, max_us, mean_us, ITERATIONS, WARMUP])
      assert_int(p95).is_less(BUDGET_USEC)  # AC-DESKTOP hard assert

  func test_frame_budget_for_100_calls() -> void:
      var atk := Vector2i(0, 0)
      var def := Vector2i(2, 2)
      var t0 := Time.get_ticks_usec()
      for i in range(100):
          TerrainEffect.get_combat_modifiers(_grid, atk, def)
      var elapsed := Time.get_ticks_usec() - t0
      print("[terrain-effect AC-FRAME-TIME] 100 calls = %dµs (frame budget = %dµs)" % [elapsed, FRAME_BUDGET_USEC])
      assert_int(elapsed).is_less(FRAME_BUDGET_USEC)
  ```
- **Why FORTRESS_WALL + delta=−2 is the representative scenario**: it exercises both `_terrain_table[FORTRESS_WALL]` (the slowest lookup — values+rules) AND the F-1 symmetric clamp (25 + 15 = 40 → clamped to 30) AND the elevation table lookup at delta=−2 (the boundary EC-14 case minus the clamp itself, which is on positive delta). This single scenario hits ~all the code paths in `get_combat_modifiers`. A second scenario with BRIDGE (to exercise the `bridge_no_flank` flag set + special_rules array assignment) would add diversity but the AC-21 budget is per-call worst-case, not average — single-scenario is fine.
- **`_build_5x5_fixture()`** helper — borrow from the established `tests/unit/core/` fixture builders (story-001 set up `MapResource` programmatic construction). Reuse rather than re-author.
- **The deferred-to-Polish discipline** is a project standard now (third reuse). Document inline:
  ```gdscript
  # AC-TARGET on-device Android validation deferred to Polish phase.
  # Reactivation trigger: Android export pipeline online + mid-range test device available.
  # Reference: production/qa/evidence/perf-baselines.md (project's perf trend doc, if it exists).
  ```
- **DO NOT add a `Reproducibility ±10%` AC** to this story. Map-grid story-007 documented this as TD-032 A-30 / CI-impractical; reactivate only if a perf-trend dashboard is introduced (TD-032 A-29 from map-grid). This story matches the same "manual verification accepted as proxy" precedent.
- **Statistics output format**: print to test log via `print()` so CI captures it. Future TD if a perf-trend dashboard is built: switch to JSON-structured perf artifact (TD-032 A-29 carry-over from map-grid story-007).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Stories 001-007: Resource classes + skeleton + config + queries + cost_multiplier + cap accessors (this story validates the whole assembled pipeline at perf level)
- On-device Android benchmark — deferred to Polish per project precedent
- Perf-trend dashboard / JSON-structured perf artifact — TD when a consumer exists (TD-032 A-29 from map-grid)
- Reproducibility ±10% multi-run variance check — CI-impractical per map-grid TD-032 A-30
- `get_terrain_modifiers` and `get_terrain_score` perf — not budgeted in AC-21 (they are even simpler than `get_combat_modifiers` so trivially under any reasonable budget)

---

## QA Test Cases

*Authored from GDD AC-21 + ADR-0008 §Performance + project precedent directly (lean mode — QL-STORY-READY gate skipped). Developer implements against these — do not invent new test cases during implementation.*

- **AC-1** (GDD AC-21): get_combat_modifiers p95 < 100µs on desktop substitute
  - Given: 5×5 MapGrid fixture loaded; `TerrainEffect.load_config()` complete; FORTRESS_WALL defender at delta=−2 representative scenario
  - When: 110 iterations (10 warmup + 100 statistics) of `get_combat_modifiers`
  - Then: p95 latency < 100µs; stats line printed to test log
  - Edge cases: a single sample > 100µs is allowed (max may exceed); only p95 enforced as hard threshold (matches save-manager/story-007 + map-grid/story-007 convention)

- **AC-2**: 100 sequential calls within single-frame budget (16.6ms)
  - Given: same fixture
  - When: 100 sequential `get_combat_modifiers` calls timed as a block
  - Then: total elapsed < 16.6ms (16,600µs)
  - Edge cases: this is the aggregated form of AC-21 — verifies that the per-call budget multiplied by 100 stays under one frame; if AC-1's p95 is well under budget, AC-2 is automatic

- **AC-3** (Warmup discipline): first 10 iterations discarded from statistics; warmup ratio printed
  - Given: same fixture
  - When: 110 iterations run with first 10 separated as warmup
  - Then: stats output excludes warmup samples; warmup ratio (first_10_mean / steady_state_mean) printed to log
  - Edge cases: warmup ratio close to 1.0 indicates negligible cold-cache effect (which would be the desktop expectation given GDScript's lack of true JIT); a warmup ratio of >2.0 indicates a cold-cache cost worth investigating

- **AC-4** (Stats output): p50, p95, max, mean printed for CI log capture
  - Given: AC-1 test run
  - When: stats line output
  - Then: `[terrain-effect AC-21] p50=NNµs p95=NNµs max=NNµs mean=N.Nµs (n=100, warmup=10)` format
  - Edge cases: format must be greppable by CI scripts that aggregate perf-trend data; pattern matches save-manager/story-007 + map-grid/story-007 outputs for cross-story trend analysis

- **AC-5** (Deferred-to-Polish marker): test header documents AC-TARGET deferral + reactivation trigger
  - Given: `tests/integration/core/terrain_effect_perf_test.gd` opened
  - When: header doc-comment read
  - Then: contains the deferred-to-Polish marker and reactivation trigger ("when Android export pipeline lands…")
  - Edge cases: doc-level; manual verification at `/code-review` time

- **AC-6** (Regression canary): the perf test's hard threshold serves as a canary — explicit comment noting this purpose
  - Given: AC-1 test function opened
  - When: function comment read
  - Then: contains a comment noting the threshold's purpose as a regression canary, not as the production gate
  - Edge cases: doc-level; ensures future maintainers understand that desktop p95 is the early-warning bound, not the AC-21 production deployment gate

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/core/terrain_effect_perf_test.gd` — must exist and pass (6 ACs covering 2 hard-asserted timing tests + 4 documentation/format ACs)
- Stats output captured in test log; reasonable expected stats: p50 in 5-15µs range, p95 in 10-30µs range, max under 100µs, mean ~10µs (per ADR-0008 <0.01ms expected estimate × ~3-5× for measurement overhead)
- AC-TARGET (Polish-phase Android) reactivation trigger documented; this story does NOT validate the on-device behavior

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 001-007 (the entire epic — perf test runs against the assembled pipeline). In particular Story 005 (`get_combat_modifiers` is what's measured) and Story 003 (config must be loadable without errors)
- Reactivation trigger for AC-TARGET (Polish phase): Android export pipeline online + mid-range test device available; document re-run protocol in `production/qa/evidence/` when reactivated
- Unlocks: epic close-out — once this story passes, terrain-effect epic Definition of Done is satisfied; `/sprint-plan` may schedule the implementation work, then `/gate-check` revisits Pre-Production → Production criteria
