# Balance Constants — Performance Evidence Summary

**Story**: balance-data story-005 (BalanceConstants perf regression test)
**Date**: 2026-05-01
**Environment**: macOS 25.4.0, headless Godot 4.6.2, GdUnit4 v6.1.2
**Test file**: `tests/unit/balance/balance_constants_perf_test.gd`
**ADR**: ADR-0006 §Performance Implications

---

## AC-1 / AC-2 — Headless perf regression tests

| AC | TR | Description | Threshold | Result |
|----|----|-----------|-----------|--------|
| AC-1 | TR-balance-data-015(a) | Cold-cache `get_const()` first call (lazy-load + JSON parse) | < 2,000us (2ms) | PASSED |
| AC-2 | TR-balance-data-015(b) | 10,000 cached `get_const()` calls cycling through 10 different keys | < 500,000us (500ms) total / < 50us avg per call | PASSED |

### Notes

- **AC-1 measures cold-cache first-call cost** — `before_test()` resets `_cache_loaded=false` + `_cache={}` via reflection (G-15 + ADR-0006 §Decision 6) to ensure each test starts cold.
- **AC-2 cycles through 10 different scalar keys** (BASE_CEILING, MIN_DAMAGE, ATK_CAP, DEF_CAP, DEFEND_STANCE_ATK_PENALTY, P_MULT_COMBINED_CAP, CHARGE_BONUS, AMBUSH_BONUS, DAMAGE_CEILING, COUNTER_ATTACK_MODIFIER) to defeat branch-predictor short-circuits and exercise the Dictionary lookup hot path.
- Thresholds are conservative — designed to catch catastrophic regressions (e.g. `_load_cache()` re-invocation per call) rather than enforce micro-optimisation.
- Determinism note: perf tests are inherently noisy on CI runners; the 2ms / 500ms thresholds include variance headroom (mirrors damage-calc story-010 conservative-threshold practice).

---

## AC-3 — Mobile p99 disposition

**Polish-deferred** per the established 5-precedent pattern (scene-manager story-007, save-manager story-007, map-grid story-007, terrain-effect story-008, damage-calc story-010). See `production/qa/evidence/balance_constants_perf_mobile.md` for the 4-element admin doc (deferral reason / reactivation trigger / ready-to-ship fallback / estimated Polish effort).

---

## Regression baseline

Run command:
```
godot --headless --path <project_root> -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
  --ignoreHeadlessMode -a res://tests/unit -a res://tests/integration -c
```

Overall Summary (post-story-005 write):
```
506 test cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans
```

The 1 pre-existing failure (`test_hero_data_doc_comment_contains_required_strings` in `unit_role_skeleton_test.gd`) is unrelated to balance-data and was carried from story-001 close-out (orthogonal; flagged in story-001 Completion Notes).

New perf test suite stats:
```
2 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED
```
