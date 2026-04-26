# Scene Manager — V-7/V-8 Target-Device Verification (DESKTOP-PARTIAL + POLISH-DEFERRED)

> **Story**: `production/epics/scene-manager/story-007-target-device-verification.md`
> **ADR**: `docs/architecture/ADR-0002-scene-manager.md` §Engine Compatibility Verification Required + §Validation Criteria V-7, V-8 + §Performance Implications + §Neutral Consequences (V-7 fallback path)
> **Story Type**: Integration (manual playtest evidence)
> **Status**: **DESKTOP-VERIFIED PORTIONS COMPLETE** / **ON-DEVICE PORTIONS DEFERRED to Polish phase**
> **Last updated**: 2026-04-26
> **Branch**: `feature/scene-manager-story-007-target-device-deferral` (off main, via Sprint 1 S1-01)
> **Verifier**: Sprint 1 S1-01 close-out (Polish-deferral path — 4th invocation of pattern; precedents: save-manager/story-007 closed 2026-04-24, map-grid/story-007 closed 2026-04-25, AC-TARGET deferral pattern)

---

## Summary

This document is the manual verification artifact for scene-manager epic Definition-of-Done items **V-7** (Android recursive Control disable) and **V-8** (memory profile ≤250 MB during IN_BATTLE). Per Sprint 1 plan R3 mitigation ("scene-manager story-007 needs unavailable hardware — mitigation: Polish-deferral precedent"), this session does NOT have access to a physical Android device (Snapdragon 7-gen class) or a touch-event-capable Android emulator. The closure path is the **Polish-deferral pattern** established by save-manager/story-007 (closed 2026-04-24) and reused by map-grid/story-007 (closed 2026-04-25).

**Verified this session (DESKTOP/HEADLESS)**:
- AC-5 CONNECT_DEFERRED ordering — story-005's `test_co_subscriber_reads_battle_scene_ref_in_deferred_handler` test passes on current main
- AC-4 async load partial substitute — `test_scene_manager_async_load_happy_path_idle_to_in_battle` passes; async pipeline observably non-blocking on macOS desktop

**Deferred to Polish phase (TARGET-DEVICE-ONLY)**:
- AC-1 V-7 recursive Control disable on Android export (touch ≠ mouse — desktop NOT a substitute)
- AC-2 V-7 fallback (conditional — fires only if AC-1 detects need)
- AC-3 V-8 memory profile ≤250 MB during IN_BATTLE on Snapdragon 7-gen
- AC-6 retry loop memory stability (full validation requires Android profiler)

**Reactivation trigger**: "When the first Android export build is green AND a Snapdragon 7-gen class device (or approved emulator with touch-event generation) is available." Estimated Polish-phase effort: 3-4 hours (device setup + Godot Android export preset + manual evidence doc authoring + 6 AC playtest cycles).

**Scene-manager epic Definition of Done** is satisfied per project precedent: all desktop-verifiable items pass; on-device items are explicitly deferred with documented reactivation trigger and ready-to-ship V-7 fallback path (per-Control mouse_filter recursive walk, code-ready in §D below).

---

## A. AC-5 CONNECT_DEFERRED Ordering — DESKTOP-VERIFIED PASS

**Story-005's test asserts**: When `battle_outcome_resolved(outcome)` is emitted, a co-subscriber's CONNECT_DEFERRED handler can read `battle_scene_ref` (the BattleScene Node) before SceneManager's deferred-free fires. This validates the 1-frame defer invariant from ADR-0002 §Neutral Consequences (the deferred-free pattern that pushes BattleScene teardown one extra frame so co-subscribers' same-frame handlers can complete safely).

**Headless run (this session, 2026-04-26)**:

```
$ SKIP_PERF_BUDGETS=1 godot --headless --path . \
    -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --add tests/integration/core/scene_handoff_timing_test.gd \
    --ignoreHeadlessMode

Run Test Suite: res://tests/integration/core/scene_handoff_timing_test.gd
  > test_scene_manager_async_load_happy_path_idle_to_in_battle  PASSED  8ms
  > test_scene_manager_async_load_nonexistent_path_reaches_error  PASSED 15ms
  > test_co_subscriber_reads_battle_scene_ref_in_deferred_handler  PASSED 19ms

Statistics: 3 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 48ms
Exit code: 0
```

| Field | Value |
|---|---|
| Godot version | 4.6.2.stable.official.71f334935 |
| Platform | macOS arm64 (host: Apple Silicon) |
| Test result | PASSED 19ms (`test_co_subscriber_reads_battle_scene_ref_in_deferred_handler`) |
| Suite total | 3/3 PASSED, 0 errors, 0 failures, 0 flaky, 0 orphans, exit 0 |
| Story-006 SHA | main @ 486c05f (post PR #44 merge — PR-not-yet-merged: #45, #46) |

**AC-5 verdict on desktop**: PASS. The CONNECT_DEFERRED ordering invariant holds under macOS desktop frame timing. **On-device run (Polish phase)**: same test must pass on Android; current desktop pass establishes the necessary precondition (test logic is correct + dispatches correctly without mock-injection bugs). Mobile-specific frame-timing behavior (e.g., 30 fps vs. 60 fps; varying deferred-call queue cadence) cannot be ruled out from desktop alone.

---

## B. AC-4 Async Load Observable on-Device — DESKTOP-PARTIAL-SUBSTITUTE PASS

**Story-004's `test_scene_manager_async_load_happy_path_idle_to_in_battle`** passes on macOS desktop in 8ms (above). This validates that:

1. `ResourceLoader.load_threaded_request` accepts the load request without blocking the test driver.
2. `loading_progress` updates incrementally (not 0.0-then-1.0 jump) — the test asserts incremental progress observability.
3. Final state reaches `IN_BATTLE` via the FSM transition without timeout.

**Desktop is a partial substitute** for mobile because:
- macOS desktop uses Metal renderer; Android uses Vulkan / OpenGL ES — different render-thread interaction with main-thread loaders.
- Desktop SSD I/O is significantly faster than mobile flash (typical ratio: 10-50× depending on device).
- Mobile mid-range devices have less RAM headroom; threaded-load main-thread spike behavior may differ under memory pressure.

**Therefore**: desktop PASS does NOT prove mobile PASS, but desktop FAIL would have GUARANTEED mobile FAIL (asymmetric signal — the same rationale save-manager/story-007 §AC-DESKTOP documented). The on-device portion (no frame spike >100 ms during LOADING_BATTLE on mid-range Android) remains a Polish-phase obligation.

**AC-4 verdict on desktop**: PASS as partial substitute. **On-device verification (Polish phase)**: confirm `loading_progress` updates incrementally on Android export; profile frame time during LOADING_BATTLE.

---

## C. AC-1 / AC-2 / AC-3 / AC-6 — DEFERRED to Polish Phase

These ACs require physical Android hardware or a touch-event-capable Android emulator. Polish-deferral pattern explicitly sanctioned by Sprint 1 plan R3 mitigation + 2 prior precedents (save-manager/story-007 + map-grid/story-007).

### AC-1 V-7 Recursive Control Disable on Android Export — DEFERRED

**Why desktop is NOT a substitute**: macOS / Linux / Windows desktop input fires through `MOUSE_BUTTON_PRESSED` events on `Control._gui_input`; Android touch fires through `InputEventScreenTouch` / `InputEventScreenDrag` via `_unhandled_input` and `_gui_input`. The Godot 4.5+ recursive Control disable (`mouse_filter` propagation through Control trees) was specifically introduced to handle the touch-input case where the input handler walks the Control tree differently from mouse-event dispatch. Desktop mouse events do NOT exercise the recursive-disable code path being verified.

**Specific verification needed on-device**:
- Android APK export targeting Snapdragon 7-gen class device (Adreno 610 / Mali-G57 class)
- Overworld scene with UIRoot Control + nested Control children (Labels, Buttons)
- Trigger battle_launch_requested via test harness; while in IN_BATTLE, attempt touch events on Overworld Button screen coordinates
- Pass condition: Button does NOT fire its `pressed` signal; logs show touch event was ignored at the Overworld Control subtree

**If recursive-disable does NOT propagate as expected**: ship the V-7 fallback (§D below).

### AC-2 V-7 Fallback (Conditional) — DEFERRED

Activates only if AC-1 detects the recursive-disable doesn't work. Implementation is **ready** (see §D Fallback Path) and shipped only if AC-1 evidence requires it.

### AC-3 V-8 Memory Profile ≤250 MB During IN_BATTLE — DEFERRED

**Why desktop is NOT authoritative**: Mobile memory pressure semantics differ — Android's `oom_killer` triggers under different thresholds, mobile heap allocators (jemalloc / scudo) have different fragmentation characteristics from glibc / macOS allocators, and the engine runtime baseline footprint differs (mobile lacks debug symbols + hot-reload threads). Desktop CAN provide a rough order-of-magnitude check but the ≤250 MB ceiling is mobile-specific.

**Specific verification needed on-device**:
- Snapdragon 7-gen class device with Godot profiler attached (debug build) OR Android Studio Profiler (release-mode-like behavior) OR `dumpsys meminfo` via adb
- Phase-by-phase peak resident memory capture: (a) Overworld-only baseline, (b) LOADING_BATTLE peak, (c) IN_BATTLE peak with Overworld retained, (d) post-teardown IDLE
- Pass condition: (c) ≤250 MB; document each phase's peak

### AC-6 Retry Loop Memory Stability — DEFERRED

**Why desktop is NOT authoritative**: Mobile retry-loop memory leaks would surface differently due to (a) Godot's shared-Resource cache behavior on memory-constrained platforms, (b) Android's GC vs. macOS / Linux memory return patterns, and (c) profiler-tool quality (Android Studio Profiler reports leaked RefCounted nodes more reliably than Godot's built-in profiler on long sessions).

**Specific verification needed on-device**:
- Same APK + profiler as AC-3
- Run 5 LOSS→retry cycles
- Pass condition: resident memory after cycle 5 within ±5 MB of cycle 1; no orphan nodes reported by profiler

---

## D. V-7 Fallback Path (Implementation-Ready — Ship if AC-1 Detects Need)

If AC-1 evidence shows the Godot 4.5+ recursive Control disable does NOT propagate `mouse_filter` through nested Control children on Android touch input, the fallback is the per-Control mouse_filter walk documented in ADR-0002 §Neutral Consequences. The implementation is **already specified** in story-007 §Implementation Notes #3 and is reproduced here for Polish-phase reference.

**Code (drop into `src/core/scene_manager.gd`)**:

```gdscript
func _pause_overworld() -> void:
    # ... existing 4 properties (process_mode, visible, set_process_input,
    # set_process_unhandled_input) plus root Control mouse_filter ...

    # FALLBACK: per-Control mouse_filter walk if 4.5+ recursive disable
    # didn't propagate to nested Controls on Android touch input
    _apply_mouse_filter_recursive(_overworld_ref, Control.MOUSE_FILTER_IGNORE)


func _restore_overworld() -> void:
    # ... existing restore ...

    _apply_mouse_filter_recursive(_overworld_ref, Control.MOUSE_FILTER_STOP)


func _apply_mouse_filter_recursive(node: Node, filter: int) -> void:
    if node is Control:
        (node as Control).mouse_filter = filter
    for child in node.get_children():
        _apply_mouse_filter_recursive(child, filter)
```

**Regression test additions** (if fallback ships):

- `tests/unit/core/scene_manager_test.gd` — new test asserting `_apply_mouse_filter_recursive` walks nested Control subtrees correctly on a synthetic 3-deep Control hierarchy fixture.
- Re-run full `tests/unit + tests/integration` suite after fallback commit; expect all prior tests still pass (the fallback is additive — it doesn't change existing behavior on platforms where 4.5+ recursive-disable already works).

**Code review obligation** if fallback ships: godot-gdscript-specialist review for static-typing + recursion-depth-safety (Control trees are typically <10 deep so stack-overflow risk is negligible, but worth a typed-Array iteration guard).

---

## E. Reactivation Trigger and Polish-Phase Estimate

**Reactivation trigger**: When BOTH conditions are met:

1. The first Android export build pipeline is green (export preset committed; CI matrix or local-machine export produces a runnable APK without errors).
2. A Snapdragon 7-gen class device OR an approved Android emulator with touch-event generation capability is available to the verifier.

**Polish-phase scope** (documented for the verifier picking up this work):

| AC | Estimated effort | Dependencies | Output |
|---|---|---|---|
| AC-1 V-7 recursive Control disable | 45 min (setup + 1 playtest cycle) | Android APK + test Overworld scene with nested Buttons | Pass/Fail evidence + screenshots; if fail, activate AC-2 |
| AC-2 V-7 fallback (conditional) | 60 min (code change + test + smoke) | If AC-1 fails | New commit on this branch with §D code + new unit test |
| AC-3 V-8 memory ≤250 MB | 90 min (4-phase profiling + documentation) | Android APK + profiler tool | Per-phase peak memory table + screenshots |
| AC-4 async load on Android | 30 min (frame-time observation) | Android APK + frame profiler | No-spike->100ms confirmation + loading_progress incremental observation |
| AC-5 CONNECT_DEFERRED on device | 15 min (run gdUnit4 on Android export) | Android APK supporting GdUnit4 runner | Same test passes on Android |
| AC-6 retry loop memory stability | 45 min (5 cycles × 5 min observation) | Android APK + profiler | Cycle-1-vs-cycle-5 memory comparison + orphan check |

**Total Polish-phase estimate**: 3-4 hours (matches save-manager/story-007 deferred estimate).

---

## F. Sign-Off

**Verifier**: Sprint 1 S1-01 close-out (Polish-deferral path)
**Date**: 2026-04-26
**Status**: DESKTOP-VERIFIED PORTIONS PASS / ON-DEVICE PORTIONS EXPLICITLY DEFERRED to Polish phase per Sprint 1 R3 mitigation
**Sanctioning precedent**: save-manager/story-007 (closed 2026-04-24, AC-TARGET deferred); map-grid/story-007 (closed 2026-04-25, AC-TARGET deferred)
**Scene-manager epic DoD**: Satisfied (desktop-verifiable items PASS; on-device items deferred with reactivation trigger; V-7 fallback ready-to-ship)

**Future-evidence path** (created during Polish-phase on-device session): `production/qa/evidence/scene-manager-android-verification-polish-[YYYY-MM-DD].md` — will append §G with per-AC on-device results, Android device specs, profiler tool used, screenshots / screen recordings, and final Pass/Fail verdict per AC.

**Lead sign-off**: pending Polish-phase completion (this evidence doc reflects the desktop-verifiable+deferred portion only).
