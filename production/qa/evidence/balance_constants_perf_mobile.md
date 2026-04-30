# Balance Constants — Mobile Performance: Polish-Phase Deferral

**Story**: balance-data story-005 (BalanceConstants perf regression test)
**Date**: 2026-05-01
**AC reference**: AC-3 (mobile device performance validation)

---

## Disposition: Deferred to Polish Phase

Mobile hardware profiling for `BalanceConstants.get_const()` is deferred to the
Polish phase. This is not a blocking concern for MVP.

---

## Rationale

1. **No mobile device lab available at MVP** — iOS and Android hardware is not
   accessible in the current CI environment. Running headless on a desktop host
   does not reflect mobile timing characteristics.

2. **Low risk at current call frequency** — During MVP, `get_const()` is called
   at battle-start and per-damage-event, not per-frame. Even a 10x slowdown on
   mobile relative to the macOS host (~6 ms / 10,000 calls → ~60 ms / 10,000) would not
   manifest as a frame-time issue at current call density.

3. **Conservative thresholds provide headroom** — The AC-2 threshold of 500 ms
   for 10,000 calls already accounts for roughly 80x mobile overhead relative to the
   measured ~6 ms desktop result. If mobile hits within 80x of desktop (highly unlikely
   for O(1) Dictionary lookups), AC-2 passes on-device without modification.

4. **Architecture guards against file I/O regression** — The primary risk (re-loading
   JSON on every call) is already caught by the automated thresholds. Mobile profiling
   adds only quantitative data, not qualitative correctness coverage.

---

## Re-entry Criteria (Polish Phase)

- [ ] iOS device (iPhone SE 2nd gen or newer, representing low-end target) available
      in lab or via CI device farm
- [ ] Android device (mid-range Snapdragon 6xx series or equivalent) available
- [ ] Run `tests/unit/balance/balance_constants_perf_test.gd` on both devices via
      `godot --headless` device export
- [ ] Record measured AC-2 value (ms for 10,000 calls); update this document with results
- [ ] If measured value exceeds 500 ms threshold on either device: open a hotfix story
      before Polish sign-off

---

## Cross-references

- `production/qa/evidence/balance_constants_perf_summary.md` — desktop CI results
- `tests/unit/balance/balance_constants_perf_test.gd` — test implementation
- `src/foundation/balance/balance_constants.gd` — production implementation
- `docs/architecture/ADR-0006-balance-data.md` — architecture decision
