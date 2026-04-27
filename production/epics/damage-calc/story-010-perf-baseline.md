# Story 010: Performance baseline — headless CI throughput + mobile p99 (Polish-deferral candidate)

> **Epic**: damage-calc
> **Status**: Complete (2026-04-27)
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 2-3 hours headless throughput + 1.5-2 hours mobile p99 (or ~2h Polish-deferral admin pass if minimum-spec device unavailable)

## Context

**GDD**: `design/gdd/damage-calc.md`
**Requirement**: `TR-damage-calc-013` (performance budgets)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012 Damage Calc
**ADR Decision Summary**: AC-DC-40 split into two-tier validation per damage-calc.md rev 2 — (a) CI throughput check 10,000 calls under 500ms (50µs avg) on Linux headless runner; (b) Mobile p99 < 1ms on minimum-spec device (ARMv8, ≥4GB RAM, Adreno 610 / Mali-G57 class). (a) is Vertical Slice blocker; (b) is Beta blocker, KEEP-through-implementation. Per ADR-0012 R-2 + 4 prior precedents in this project (save-manager/story-007, map-grid/story-007, scene-manager/story-007, terrain-effect/story-008), (b) is a Polish-deferral candidate if minimum-spec device is unavailable at story time.

**Engine**: Godot 4.6 | **Risk**: LOW (CI throughput) / MEDIUM (mobile p99 — 5th candidate for Polish-deferral pattern)
**Engine Notes**: Headless CI cannot validate ARMv8 perf — these are intentionally separate ACs per damage-calc.md rev 2 (the previous combined formulation was untestable). RefCounted free is deterministic at scope exit (no GC pause) per godot-specialist Item 12, so 4 wrapper allocs per resolve() call are bounded.

**Control Manifest Rules (Feature layer)**:
- Required: AC-DC-40(a) CI throughput is a regression gate (Vertical Slice blocker); failure blocks merge
- Required: AC-DC-40(b) mobile p99 evidence captured on minimum-spec device (Beta blocker, KEEP-through-implementation)
- Guardrail: Polish-deferral allowed for AC-DC-40(b) ONLY if reactivation trigger is documented + ready-to-ship fallback noted (per save-manager/story-007 + map-grid/story-007 + scene-manager/story-007 + terrain-effect/story-008 precedent — pattern stable at 4 invocations)

---

## Acceptance Criteria

*From damage-calc.md AC-DC-40 + ADR-0012 R-2:*

- [ ] **AC-DC-40(a) headless CI throughput**: `tests/unit/damage_calc/damage_calc_perf_test.gd::test_perf_resolve_throughput_ci` — 10,000 `resolve()` calls in headless CI on Linux runner; assert wall-clock total < 500ms (50µs avg). This is a regression gate; CI fails merge if exceeded.
- [ ] **AC-DC-40(b) mobile p99 latency**: minimum-spec device matching the mobile reference class (ARMv8, ≥4GB RAM, Adreno 610 / Mali-G57 or better GPU class, Android 12+/iOS 15+); 10,000-call benchmark via in-game debug command; assert p99 latency < 1ms via `Time.get_ticks_usec()` deltas. Evidence: `production/qa/evidence/damage_calc_perf_mobile.md` with screenshot of debug overlay + device model + OS version recorded.
- [ ] AC-DC-40(b) **Polish-deferral fallback** (if minimum-spec device unavailable): document reactivation trigger ("when first Android export build is green AND minimum-spec device available"); estimated Polish-phase effort 2-3h; ready-to-ship fallback (none required — perf budget is hard gate at Beta only). Pattern matches scene-manager/story-007 (V-7/V-8 on-device portions deferred 2026-04-26) and terrain-effect/story-008 (perf budget mobile deferred per Polish-deferral pattern).
- [ ] Performance baseline summary written to `production/qa/evidence/damage_calc_perf_summary.md` with both AC-DC-40(a) headless results + AC-DC-40(b) mobile (or Polish-deferral) results

---

## Implementation Notes

*Derived from ADR-0012 Performance Implications + R-2 + damage-calc.md AC-DC-40 rev 2:*

- **AC-DC-40(a) headless CI throughput** test pattern:
  ```gdscript
  func test_perf_resolve_throughput_ci():
      var atk := AttackerContext.make(&"attacker", 0, false, false, [])
      var def := DefenderContext.make(&"defender", 0, 0)
      var rng := RandomNumberGenerator.new()
      var mod := ResolveModifiers.make(PHYSICAL, rng, &"FRONT", 1)
      var msec_start := Time.get_ticks_msec()
      for i in 10000:
          DamageCalc.resolve(atk, def, mod)
      var elapsed := Time.get_ticks_msec() - msec_start
      assert(elapsed < 500, "10,000 resolve() calls in <500ms (got %dms)" % elapsed)
  ```
- **AC-DC-40(b) mobile p99 measurement** (production code path):
  - In-game debug command (or test-build menu) triggers a 10,000-call benchmark
  - Each call wrapped in `Time.get_ticks_usec()` snapshot before/after
  - Histogram of latencies; p99 computed as 99th percentile
  - Debug overlay displays p99 + min + max + avg
  - Evidence file captures: device model + OS version + GPU class + screenshot of debug overlay
- **Polish-deferral pattern** (5th invocation if invoked — pattern is stable at 4):
  - Document reactivation trigger explicitly (e.g., "when first Android export build is green AND a Snapdragon 7-gen / Adreno 610 device is available")
  - Document ready-to-ship fallback: AC-DC-40(b) is a Beta blocker only (not Vertical Slice); Polish-deferral does not block AC-DC-40(a) which is the Vertical Slice gate
  - Document estimated Polish-phase effort (2-3h)
  - Update story-010 status to "Complete (Polish-deferral)" + `EPIC.md` Stories table reflects same
- **Asymmetric-signal rationale** (per session-state insight from prior Polish-deferral closures): "desktop CI PASS does not prove mobile PASS, but desktop CI FAIL would have GUARANTEED mobile FAIL". AC-DC-40(a) headless throughput as a regression gate provides the negative-signal coverage; AC-DC-40(b) mobile p99 provides the positive-signal coverage when device is available.
- **`damage_calc_perf_test.gd` location**: `tests/unit/damage_calc/damage_calc_perf_test.gd` (separate file from `damage_calc_test.gd` per project convention — perf tests can be quarantined if flaky per TD-035 save_perf precedent).
- **Cross-reference TD-035**: `tests/unit/save_load/save_perf_test.gd` flakiness was tracked as TD-035 (per active.md Sprint 1 plan). If `damage_calc_perf_test.gd` exhibits similar CI flakiness, mark with `# TODO(TD-XXX): perf test flakiness` and triage similarly.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 008: AC-DC-41 no-Dictionary-alloc static lint (separate concern — static analysis, not perf benchmark)
- Story 009: AC-DC-46 Reduce Motion lifecycle wall-clock assertions (different test category — UI accessibility, not perf)
- Future Beta gate: AC-DC-40(b) mobile p99 enforcement at release-candidate level (this story scaffolds the test; gate enforcement is at the release-checklist level)

---

## QA Test Cases

*Authored from damage-calc.md AC-DC-40 directly. Developer implements against these.*

- **AC-1 (AC-DC-40(a) headless CI throughput)**:
  - Given: 10,000-call benchmark fixture in `damage_calc_perf_test.gd`
  - When: CI runs the test on Linux headless runner
  - Then: wall-clock total < 500ms (50µs avg per resolve()); CI fails build if exceeded
  - Edge cases: variance across runs ≤ 50ms (3 consecutive runs all < 500ms before flakiness escalation per TD-035 precedent)

- **AC-2 (AC-DC-40(b) mobile p99 — direct case)**:
  - Setup: minimum-spec device (Adreno 610 / Mali-G57 class, ARMv8, ≥4GB RAM, Android 12+/iOS 15+); release-config build deployed
  - Verify: in-game debug command triggers 10,000-call benchmark; p99 latency captured
  - Pass condition: p99 < 1ms; evidence file `damage_calc_perf_mobile.md` includes device model + OS version + GPU class + screenshot of debug overlay

- **AC-2-deferred (AC-DC-40(b) Polish-deferral case)**:
  - Setup: minimum-spec device unavailable at story time
  - Verify: reactivation trigger documented; ready-to-ship fallback noted (none required — Beta gate only); estimated Polish-phase effort recorded
  - Pass condition: `damage_calc_perf_mobile.md` evidence file documents the deferral with the standard 4-element template (Polish-deferral pattern, 5th invocation): (1) Polish-deferral reason, (2) reactivation trigger, (3) ready-to-ship fallback (or "no fallback required" if Beta-only), (4) estimated Polish-phase effort
  - Edge cases: Polish-deferral does NOT block this story's Complete status; story closes with the deferral evidence as a sufficient artifact per project precedent

- **AC-3 (Performance baseline summary)**:
  - Setup: AC-DC-40(a) headless throughput results + AC-DC-40(b) mobile (or deferral) results
  - Verify: `production/qa/evidence/damage_calc_perf_summary.md` exists with both sub-results
  - Pass condition: summary file has structured headers for AC-DC-40(a) + AC-DC-40(b); includes timestamps + run URLs (CI) + device evidence (mobile)

---

## Test Evidence

**Story Type**: Logic (with Polish-deferral candidate for AC-DC-40(b))
**Required evidence**:
- `tests/unit/damage_calc/damage_calc_perf_test.gd` — headless throughput AC-DC-40(a); must pass on every push
- `production/qa/evidence/damage_calc_perf_mobile.md` — direct mobile p99 evidence OR Polish-deferral admin pass evidence (4-element template)
- `production/qa/evidence/damage_calc_perf_summary.md` — combined summary

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006 (completed `damage_calc.gd` pipeline) + Story 001 (CI infrastructure — headless throughput integration)
- Unlocks: Beta release gate (AC-DC-40(b) mobile p99 KEEP-through-implementation hard gate at Beta tier)

---

## Completion Notes

**Completed**: 2026-04-27
**Verdict**: COMPLETE WITH NOTES
**Path chosen**: Path B (Hybrid) — AC-DC-40(a) implemented + AC-DC-40(b) Polish-deferred (5th invocation of stable 4-precedent pattern)
**Criteria**: 4/4 covered (3 direct + 1 deferred per AC-2-deferred pass condition)
**Test Evidence**:
- `tests/unit/damage_calc/damage_calc_perf_test.gd` — `test_perf_resolve_throughput_ci_under_budget` (AC-DC-40(a) regression gate; 80/76/78ms across 3 local runs vs 500ms budget = ~16% utilization)
- `production/qa/evidence/damage_calc_perf_mobile.md` — AC-DC-40(b) Polish-deferral 4-element template (Android+iOS independent reactivation triggers)
- `production/qa/evidence/damage_calc_perf_summary.md` — combined AC-3 summary (CI run URL filled in at story-done)
**PR**: #70 merged 2026-04-27 (commit `6e72793`); CI green (GdUnit4 45s, macOS Metal 27s, gdunit4-report SUCCESS)

### Files delivered (3 new + 1 .uid)

| Path | LoC | Purpose |
|---|---|---|
| `tests/unit/damage_calc/damage_calc_perf_test.gd` | 67 | AC-DC-40(a) headless CI throughput test |
| `production/qa/evidence/damage_calc_perf_mobile.md` | 135 | AC-DC-40(b) Polish-deferral evidence |
| `production/qa/evidence/damage_calc_perf_summary.md` | 71 | Combined AC-3 summary |

### /code-review verdicts (lean mode parallel)

- **godot-gdscript-specialist**: APPROVED WITH SUGGESTIONS (0 blockers; 9/10 standards passing). G-9 parens correct; G-15 `before_test`/`after_test` correct; type safety + StringName + naming all clean.
- **qa-tester**: TESTABLE (0 blockers; 4/4 ACs covered). 4-element template complete. Cross-references to all 4 prior precedents complete.

### Review fixes applied (2 mechanical, both convergent or near-convergent)

1. Test function rename: `test_perf_resolve_throughput_ci` → `test_perf_resolve_throughput_ci_under_budget` (convergent finding from both review agents — satisfies `test_[scenario]_[expected]` convention without coupling to the `_BUDGET_MS` value)
2. `damage_calc_perf_mobile.md` L117: terrain-effect/story-008 precedent date `2026-04-26` added for enumeration consistency with precedents 1-3

### Advisory deviations NOT applied (3 — accepted as-is)

1. gdscript-specialist: ResolveModifiers Direction enum verification (advisory query; current API works as written)
2. qa-tester: BalanceConstants reset comment tightening (current "G-15 + story-006b" comment acceptable)
3. (Both via /code-review): no-op since the 2 convergent fixes were applied already

### Deviations from story skeleton (3 enhancements with rationale)

None blocking. All documented in PR #70 commit message:
1. GdUnit4-idiomatic `assert_int(...).override_failure_message(...).is_less(...)` chain instead of bare `assert()`
2. Constants `_CALL_COUNT` + `_BUDGET_MS` extracted (no magic numbers)
3. `BalanceConstants` cache reset in `before_test`/`after_test` for forward-compat inter-suite isolation

### Tech debt logged

NONE NEW. TD-035 cross-reference embedded in failure message for future flakiness triage if it surfaces; no TODO required at story close. Test variance 5ms (10% of TD-035 50ms escalation threshold).

### Polish-deferral pattern — 5th invocation

Pattern remains stable. Precedent chronology updated: save-manager/007 2026-04-24 → map-grid/007 2026-04-25 → scene-manager/007 2026-04-26 → terrain-effect/008 2026-04-26 → **damage-calc/010 2026-04-27**. The pattern's 4-element template (deferral reason + reactivation trigger + ready-to-ship fallback + estimated Polish-phase effort) was applied without modification; 1 spec-driven additive change (per-platform Android+iOS branch in §2 reactivation trigger) since AC-DC-40(b) covers both target classes. Pattern continues to scale cleanly.
