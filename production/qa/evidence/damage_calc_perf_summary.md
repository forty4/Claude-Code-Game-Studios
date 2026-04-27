# Damage Calc — Performance Baseline Summary (Story-010)

> **Story**: `production/epics/damage-calc/story-010-perf-baseline.md`
> **ACs covered**: AC-DC-40(a) headless CI throughput + AC-DC-40(b) mobile p99
> **TR**: `TR-damage-calc-013` (performance budgets, `docs/architecture/tr-registry.yaml`)
> **ADR**: `docs/architecture/ADR-0012-damage-calc.md` §R-2 asymmetric-signal rationale
> **Date**: 2026-04-27
> **Author**: Dowan Kim

---

## AC-DC-40(a) — Headless CI Throughput

**Status**: Implemented (handled by godot-gdscript-specialist in parallel with this
admin pass).

**Test**: `tests/unit/damage_calc/damage_calc_perf_test.gd::test_perf_resolve_throughput_ci`

**Budget**: 10,000 `resolve()` calls < 500ms total (50µs avg per call) on Linux
headless CI runner.

**CI gate**: Regression gate — CI fails merge if budget exceeded. Runs on every push
to main and every PR per `.github/workflows/tests.yml`.

**CI run URL**: [pending — fill in after first PR CI run completes]

**Asymmetric-signal rationale** (ADR-0012 R-2): desktop CI PASS does not prove mobile
PASS, but desktop CI FAIL would have GUARANTEED mobile FAIL. This AC provides the
negative-signal coverage that remains active throughout Polish phase while
AC-DC-40(b) is deferred.

---

## AC-DC-40(b) — Mobile p99 Latency

**Status**: Polish-deferred (5th invocation of stable 4-precedent pattern).

**Budget**: p99 < 1ms on minimum-spec device (ARMv8, ≥4GB RAM, Adreno 610 / Mali-G57
class, Android 12+ / iOS 15+).

**Gate level**: Beta blocker only — not a Vertical Slice blocker, not an Alpha blocker.

**Deferral evidence**: Full 4-element Polish-deferral template at
`production/qa/evidence/damage_calc_perf_mobile.md`.

---

## Evidence Cross-reference Table

| AC | Evidence artifact | Status | Gate level |
|---|---|---|---|
| AC-DC-40(a) headless CI throughput | `tests/unit/damage_calc/damage_calc_perf_test.gd` | Implemented — CI blocking | BLOCKING (Vertical Slice) |
| AC-DC-40(b) mobile p99 | `production/qa/evidence/damage_calc_perf_mobile.md` | Polish-deferred | ADVISORY (Beta gate) |

---

## Traceability

- **TR-damage-calc-013**: `docs/architecture/tr-registry.yaml` — performance budgets
  requirement traceability
- **ADR-0012 R-2**: asymmetric-signal rationale governing the two-tier AC-DC-40 split
- **Story-010**: `production/epics/damage-calc/story-010-perf-baseline.md` — full AC
  definitions, implementation notes, and QA test cases

---

## Rev History

| Date | Author | Change |
|---|---|---|
| 2026-04-27 | Dowan Kim | Initial — story-010 admin pass; AC-DC-40(a) implemented; AC-DC-40(b) Polish-deferred (5th invocation) |
