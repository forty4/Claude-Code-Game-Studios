# Damage Calc — AC-DC-40(b) Mobile p99 Evidence (POLISH-DEFERRED)

> **Story**: `production/epics/damage-calc/story-010-perf-baseline.md`
> **AC**: AC-DC-40(b) — mobile p99 latency < 1ms on minimum-spec device
> **ADR**: `docs/architecture/ADR-0012-damage-calc.md` §R-2 asymmetric-signal rationale
> **Story Type**: Logic (Polish-deferral candidate for AC-DC-40(b))
> **Gate Level**: ADVISORY (AC-DC-40(b) is a Beta blocker; not a Vertical Slice blocker)
> **Status**: DEFERRED to Polish phase
> **Date**: 2026-04-27
> **Author**: Dowan Kim

---

## Summary

This document is the Polish-deferral evidence artifact for AC-DC-40(b) (mobile p99 < 1ms
on minimum-spec device). At story time, no minimum-spec mobile device is available for
benchmark deployment:

- Developer session is on macOS desktop (Apple Silicon)
- No Adreno 610 / Mali-G57 class Android device connected
- No iOS dev certificate + minimum-spec iOS device available at story time

This is the **5th invocation** of the project's stable Polish-deferral pattern
(established at 4 prior precedents — see §Cross-references). The 4-element deferral
template follows.

AC-DC-40(a) headless CI throughput is NOT affected by this deferral and continues to
run as a Vertical Slice regression gate on every push to main + every PR per
`.github/workflows/tests.yml`.

---

## 1. Polish-deferral reason

Minimum-spec mobile device unavailable at story time.

**Android**: No Adreno 610 / Mali-G57 class device (ARMv8, ≥4GB RAM, Android 12+)
connected or available for benchmark deployment. Developer session is macOS desktop
(Apple Silicon). Android export pipeline is not yet green (no committed export preset
as of 2026-04-27).

**iOS**: No iOS developer certificate active + no minimum-spec iOS device (A12 Bionic
or equivalent, iOS 15+) available at story time.

Desktop CI cannot substitute: macOS desktop uses Metal renderer; Android uses Vulkan /
OpenGL ES; iOS uses Metal but at different GPU microarchitecture. Per ADR-0012 R-2,
desktop CI PASS does not prove mobile PASS. The asymmetric-signal coverage from
AC-DC-40(a) provides the negative-signal bound: desktop CI FAIL would have GUARANTEED
mobile FAIL.

---

## 2. Reactivation trigger

AC-DC-40(b) re-enters the active sprint backlog when BOTH of the following are true:

**Android branch**: The first Android export build is green (export preset committed to
repo; CI matrix or local-machine export produces a runnable APK without errors) AND a
minimum-spec class Android device is available for benchmark deployment — minimum spec:
Adreno 610 / Mali-G57 class GPU, ARMv8 CPU, ≥4GB RAM, Android 12+.

**iOS branch**: An active iOS developer certificate is provisioned AND a minimum-spec
iOS device is available — minimum spec: A12 Bionic class SoC or equivalent, iOS 15+.

Either branch independently satisfies the reactivation trigger for its respective
platform. The Beta gate requires evidence from at least one minimum-spec device in each
target class before the Beta milestone closes.

---

## 3. Ready-to-ship fallback

No fallback required.

AC-DC-40(b) is a **Beta blocker only** — not a Vertical Slice blocker, not an Alpha
blocker. This Polish-deferral does not block story-010's Complete status, does not block
the Vertical Slice gate, and does not block the Alpha gate.

AC-DC-40(a) headless CI throughput continues to provide the negative-signal coverage
per ADR-0012 R-2 asymmetric-signal rationale: desktop CI PASS does not prove mobile
PASS, but desktop CI FAIL would have GUARANTEED mobile FAIL. The regression gate
remains active and blocking on every push.

---

## 4. Estimated Polish-phase effort

**Total estimate**: 2–3 hours per platform branch.

| Task | Estimate |
|---|---|
| Device setup (APK export + deploy OR iOS provisioning + deploy) | ~30 min |
| In-game debug benchmark UI hookup (verify debug command reachable on device) | ~45 min |
| Run 10,000-call benchmark, capture p99 via debug overlay + screenshot | ~30 min |
| Evidence file update (device model + OS version + GPU class + screenshot ref) | ~30 min |
| **Total** | **~2h 15min** |

If AC-DC-40(b) FAILS on the minimum-spec device (p99 ≥ 1ms), add:
- Root-cause investigation: ~30 min
- Fix iteration + retest: ~1 hour additional

Basis: matches save-manager/story-007 AC-TARGET estimate (3-4h) adjusted for the
narrower scope of this AC (single benchmark function vs. full save pipeline breakdown).

---

## Cross-references

- **ADR**: `docs/architecture/ADR-0012-damage-calc.md` §R-2 (asymmetric-signal rationale)
- **AC**: AC-DC-40(b) — `production/epics/damage-calc/story-010-perf-baseline.md`
- **TR**: `TR-damage-calc-013` (performance budgets, `docs/architecture/tr-registry.yaml`)
- **Prior precedents (4 invocations before this)**:
  1. `production/epics/save-manager/story-007-perf-target-device.md` — AC-TARGET deferred 2026-04-24
  2. `production/epics/map-grid/story-007-perf-baseline.md` — AC-TARGET deferred 2026-04-25
  3. `production/epics/scene-manager/story-007-target-device-verification.md` — V-7/V-8 deferred 2026-04-26; evidence: `production/qa/evidence/scene-manager-android-verification.md`
  4. `production/epics/terrain-effect/story-008-perf-baseline.md` — AC-TARGET deferred 2026-04-26 (on-device Android validation)
- **Companion summary**: `production/qa/evidence/damage_calc_perf_summary.md`

---

## When reactivated: evidence to capture here

When a minimum-spec device becomes available and AC-DC-40(b) is re-run, this file
is revised in-place (not replaced) with the following additions:

- Device model + OS version + GPU class
- Build version + export template version used
- 10,000-call benchmark raw p99 + min + max + avg (from `Time.get_ticks_usec()` deltas)
- Screenshot of in-game debug overlay showing p99 result
- Pass/Fail verdict vs. 1ms budget
- Date of on-device run + verifier name

Status line at the top of this file will be updated from `DEFERRED to Polish phase` to
`PASS — ON-DEVICE VERIFIED` or `FAIL — INVESTIGATION REQUIRED` accordingly.
