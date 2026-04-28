# Unit Role Perf — Polish-Deferred On-Device Measurement

> **Epic**: unit-role
> **Story**: 010 (epic close-out)
> **Pattern Precedent**: damage-calc story-010 close-out 2026-04-27 (Polish-deferral pattern, 5+ instances stable in this project)
> **Date Deferred**: 2026-04-28
> **Headless CI Baseline**: `tests/unit/foundation/unit_role_perf_test.gd` (commit landing this evidence doc)

## What's deferred

On-device performance measurement of UnitRole methods on minimum-spec mobile (Adreno 610 / Mali-G57 class, Snapdragon 7-gen target):

- `get_atk` / `get_phys_def` / `get_mag_def` / `get_max_hp` / `get_initiative` / `get_effective_move_range` — **<0.05ms (50µs) per call**
- `get_class_cost_table` — **<0.01ms (10µs) per call** (PackedFloat32Array per-call copy is the expected dominant cost; R-1 mitigation per ADR-0009 §5)
- `get_class_direction_mult` — **<0.01ms (10µs) per call** (single bracket-index lookup; expected fastest of all UnitRole methods)
- Per-battle init pass (12 units × 5 derived-stat methods = 60 sequential calls) — **<0.6ms (600µs) total**

All budgets per ADR-0009 §Performance Implications + technical-preferences.md mobile budgets (16.6ms one-frame budget at 60fps; 0.6ms per-battle init = 3.6% of one-frame budget — well inside).

## Why deferred

Headless CI baseline (this story-010 — `tests/unit/foundation/unit_role_perf_test.gd`) provides macOS x86 throughput proof. On-device validation requires:

1. **CI export pipeline produces a working Android APK**
2. **Target device(s) physically available** (Snapdragon 7-gen / Adreno 610 / Mali-G57 class via procurement OR dev kit)

Both conditions are Polish-phase prerequisites per Sprint 1 R3 + project-wide Polish-deferral pattern. The pattern is now stable at **5+ invocations** in this project.

## Reactivation trigger

When **BOTH** conditions are met:

1. CI export pipeline produces a working Android APK
2. Target device(s) available

Then:
- Re-run `tests/unit/foundation/unit_role_perf_test.gd` on device
- Assert per-budget (same thresholds as headless baseline; values in `unit_role_perf_test.gd` constants)
- Document evidence in this file's "Polish-phase result" section below
- Cross-reference against ADR-0009 §Performance Implications

If on-device measurements EXCEED budgets:
- Profile via Godot's debug + Android profiler (likely culprits: PackedFloat32Array allocation overhead on ARM JIT; JSON parse cost)
- Consider R-1 mitigation refinement (cache + freeze pattern? requires ADR-0009 amendment)
- Consider lazy-init batching (load all 6 classes' cost tables eagerly at first call to amortize)
- Document mitigation strategy + re-measure

## Estimated Polish-phase effort

**~2-3 hours**:
- Test scaffolding already exists (`unit_role_perf_test.gd` ready as-is)
- Only on-device execution + evidence capture needed
- If budgets exceed: ~4-6h additional for profiling + mitigation per the Polish-phase precedents

## Polish-phase result

*(To be filled in when reactivation trigger fires.)*

| Method | Budget | Headless x86 (CI baseline) | On-device (Polish) | Pass/Fail |
|---|---|---|---|---|
| `get_atk` | <50µs | TBD | TBD | TBD |
| `get_phys_def` | <50µs | TBD | TBD | TBD |
| `get_mag_def` | <50µs | TBD | TBD | TBD |
| `get_max_hp` | <50µs | TBD | TBD | TBD |
| `get_initiative` | <50µs | TBD | TBD | TBD |
| `get_effective_move_range` | <50µs | TBD | TBD | TBD |
| `get_class_cost_table` | <10µs | TBD | TBD | TBD |
| `get_class_direction_mult` | <10µs | TBD | TBD | TBD |
| Per-battle init pass | <600µs | TBD | TBD | TBD |

**Headless x86 (CI baseline)** values land at the test-run timestamp; check the most recent green CI run for `tests/unit/foundation/unit_role_perf_test.gd`.

## Cross-references

- ADR-0009 §Performance Implications — budget specifications
- `tests/unit/foundation/unit_role_perf_test.gd` — headless CI test (this story)
- damage-calc story-010 close-out 2026-04-27 — pattern precedent
- `.claude/rules/godot-4x-gotchas.md` G-15 — `_cache_loaded` reset obligation honored by perf test fixture
