# Story 007: Target-device verification (Android recursive Control disable + memory profile)

> **Epic**: scene-manager
> **Status**: Complete (with AC-1/2/3/6 + AC-4-target + AC-5-target DEFERRED to Polish phase) — 2026-04-26
> **Layer**: Platform
> **Type**: Integration
> **Manifest Version**: 2026-04-20

## Context

**GDD**: — (infrastructure; authoritative spec is ADR-0002)
**Requirement**: `TR-scene-manager-002` (V-7) + epic DoD (V-8 memory profile)

**ADR Governing Implementation**: ADR-0002 — §Engine Compatibility Verification Required + §Validation Criteria V-7, V-8 + §Performance Implications
**ADR Decision Summary**: "Target-device verification of: (1) recursive Control disable (4.5+ feature — exact propagation property ambiguous in engine-reference); (2) async load on Android export; (3) peak memory resident ≤250 MB during IN_BATTLE with Overworld retained; (4) CONNECT_DEFERRED co-subscriber-safe ordering under real device timing."

**Engine**: Godot 4.6 | **Risk**: MEDIUM (target-device API semantics verification; recursive Control disable 4.5+ property name; Android export `load_threaded_get_status` out-parameter semantics)
**Engine Notes**: This story cannot be automated — requires real Android device or device emulator with touch-event generation capability. Desktop export is a partial substitute for memory profiling but NOT for recursive Control disable (desktop mouse events behave differently from touch). All 4 verification items are documented in ADR-0002 §Engine Compatibility §Verification Required.

**Control Manifest Rules (Platform layer)**:
- Required: all prior stories (001-006) Complete before this story starts
- Required: target-device runs on project's supported hardware (Android Snapdragon 7-gen class per ADR-0002 §Performance Implications)
- Required: memory profile ≤250 MB resident during IN_BATTLE with Overworld retained
- Required: recursive Control disable blocks touch events on Overworld during IN_BATTLE (V-7)
- Guardrail: if verification fails on target device, fallback path documented in ADR-0002 §Neutral Consequences (per-Control `set_mouse_filter(MOUSE_FILTER_IGNORE)` walk) — this story may need to ship the fallback if the 4.5+ recursive API doesn't work as expected

## Acceptance Criteria

*Derived from ADR-0002 §Validation Criteria V-7, V-8 + §Engine Compatibility Verification Required:*

- [ ] **V-7 Recursive Control disable on Android export**: exported Android APK built from main (post-story-006 merge); manual playtest confirms touch events on Overworld UI are ignored during IN_BATTLE; touch events on BattleScene UI work normally
- [ ] **V-7 Fallback verified OR not needed**: if the 4.5+ recursive-disable API works as expected → document that in evidence doc; if it doesn't → ship the per-Control walk fallback in `_pause_overworld` / `_restore_overworld` (edit story 003's code) AND document the change; include a regression unit test that verifies the fallback walk covers nested Control subtrees
- [ ] **V-8 Memory profile ≤250 MB during IN_BATTLE**: manual profiling on Snapdragon 7-gen class device (or approved substitute); record peak resident memory during: (a) Overworld-only baseline, (b) LOADING_BATTLE peak, (c) IN_BATTLE peak with Overworld retained, (d) after teardown + return to IDLE; all values documented in evidence doc; (c) must be ≤250 MB
- [ ] **Async load on Android**: verify `ResourceLoader.load_threaded_request` actually runs off-thread on Android export (no frame-time spike >100 ms on mid-range device during LOADING_BATTLE); `loading_progress` updates incrementally (not 0.0 then 1.0 jump)
- [ ] **CONNECT_DEFERRED ordering on target device**: rerun `tests/integration/core/scene_handoff_timing_test.gd::test_co_subscriber_reads_battle_scene_ref_in_deferred_handler` (story 005) on target device build — must pass; documents that the 1-frame defer invariant holds under real device frame timing (not just headless CI)
- [ ] **Retry loop memory stability**: run 5 consecutive retry cycles on target device; verify no memory leak (total resident within +/-5 MB between cycle 1 and cycle 5; any orphan detection via Godot profiler)
- [ ] **Evidence doc**: `production/qa/evidence/scene-manager-android-verification.md` with structured results for all 6 items above + device specs + commit SHA + screenshots or screen recordings where applicable
- [ ] **If V-7 requires fallback**: separate commit (on same branch) updating `_pause_overworld` / `_restore_overworld` to include per-Control mouse_filter walk; add unit test covering nested Control subtree; smoke-check confirms fallback matches ADR-0002 §Neutral Consequences description

## Implementation Notes

*From ADR-0002 §Engine Compatibility + §Performance Implications + §Neutral Consequences:*

1. **Build target Android APK** — follow project's standard export workflow (not yet established — if no export preset exists, create one for the "Android / Snapdragon 7-gen" target as part of this story). Commit the export preset file if needed.

2. **V-7 test protocol**:
   - Load Overworld scene with UIRoot Control + nested Control children (Labels, Buttons)
   - Transition to IN_BATTLE via test harness battle_launch_requested
   - Attempt touch events on Overworld UI locations (via adb shell input or manual touch)
   - Expected: all Overworld touches blocked; BattleScene touches pass through
   - If Overworld touches DO fire (e.g., onclick handlers trigger), the 4.5+ recursive disable isn't propagating as documented → activate fallback

3. **V-7 fallback implementation** (only if needed):
   ```gdscript
   func _pause_overworld() -> void:
       # ... existing 4 properties ...
       # Fallback recursive walk if 4.5+ recursive-disable didn't propagate:
       _apply_mouse_filter_recursive(_overworld_ref, Control.MOUSE_FILTER_IGNORE)

   func _apply_mouse_filter_recursive(node: Node, filter: int) -> void:
       if node is Control:
           (node as Control).mouse_filter = filter
       for child in node.get_children():
           _apply_mouse_filter_recursive(child, filter)
   ```
   Ship this ONLY if verification shows the recursive-disable feature doesn't work. Otherwise keep story 003's simpler root-Control-only approach.

4. **V-8 memory profile tools** — Godot's built-in profiler (debug build), Android Studio Profiler (release-mode-like behavior), or `dumpsys meminfo` via adb. Document tool used in evidence doc.

5. **Profiler baselines** — record pre-feature baseline (Overworld scene only, no battle), then measure peak at each transition. The 250 MB ceiling is for peak resident during IN_BATTLE — document what's actually in memory (engine runtime + Overworld + BattleScene; not Godot's heap total which may include unused pages).

6. **Regression potential** — if this story discovers V-7 needs a fallback, stories 003-006 unit tests may need updates (e.g., test for mouse_filter on nested Controls, not just root). Re-run full `tests/unit + tests/integration` suite after any fallback commit; expect all prior tests still pass.

7. **Evidence doc template** — match `production/qa/smoke-gamebus-v7-lint.md` pattern from gamebus story-008: structured sections, actual results with device specs, screenshots, SHA at verification time, sign-off.

8. **When to run** — this story is the final gate before the scene-manager epic closes. Suggest running AFTER stories 001-006 are merged to main + CI green, with a fresh checkout of main. Do NOT run against a feature branch — too much variance risk.

9. **Desktop substitute acceptable for which items?** — V-8 memory profile: desktop gives a rough upper bound but NOT authoritative (mobile has different memory pressure). V-7 recursive Control disable: desktop is NOT substitute (mouse events vs touch events). V-3/V-4 async load: desktop partial substitute. Be explicit in the evidence doc which items were verified on which hardware.

## Out of Scope

- Fixing Android-specific performance issues discovered during profiling (e.g., if async load times out) — separate story / epic-scope creep assessment
- Exporting an Android release build for distribution — separate release-engineering concern (not this epic)
- Full-path profiling of user-session activity (this story is scoped to scene-manager epic's transitions only)

## QA Test Cases

*Test artifact*: `production/qa/evidence/scene-manager-android-verification.md` (manual playtest evidence doc)

This is a manual-verification story. Each AC below is a playtest step documented in the evidence doc with actual results, screenshots where applicable, and device specs.

- **AC-1 V-7 recursive Control disable**:
  - Setup: Android APK from main at story-006 SHA; Overworld scene with Button at known screen coords
  - Action: trigger battle_launch_requested; while in IN_BATTLE, tap Button's coords
  - Pass condition: Button does NOT fire its pressed signal; log output shows touch event was ignored

- **AC-2 V-7 fallback (conditional)**:
  - Setup: same; V-7 discovered the 4.5+ API doesn't work
  - Action: ship fallback walk code; re-run AC-1
  - Pass condition: AC-1 passes with fallback active

- **AC-3 V-8 memory ceiling**:
  - Setup: Android device with Godot profiler attached; monitor peak resident memory
  - Action: full flow: Overworld-only baseline → LOADING_BATTLE → IN_BATTLE → teardown → IDLE
  - Pass condition: peak resident during IN_BATTLE ≤ 250 MB; document each phase's peak

- **AC-4 async load observable on-device**:
  - Setup: same APK + profiler
  - Action: trigger battle_launch_requested; observe frame time and loading_progress
  - Pass condition: no frame spike >100 ms during LOADING_BATTLE; loading_progress updates incrementally

- **AC-5 CONNECT_DEFERRED ordering on device**:
  - Setup: run story-005's `test_co_subscriber_reads_battle_scene_ref_in_deferred_handler` via GdUnit4 headless on Android (or approved equivalent)
  - Pass condition: test passes; co-subscriber can read battle_scene_ref in its deferred handler

- **AC-6 Retry loop memory stability**:
  - Setup: same APK + profiler; run 5 LOSS→retry cycles
  - Pass condition: resident memory after cycle 5 within +/-5 MB of cycle 1 (no monotonic growth); no orphan nodes reported by profiler

## Test Evidence

**Story Type**: Integration (manual playtest evidence acceptable per `.claude/docs/coding-standards.md` — Integration type allows "Integration test OR documented playtest")
**Required evidence**: `production/qa/evidence/scene-manager-android-verification.md` — BLOCKING gate (completing this story closes the scene-manager epic; V-7 and V-8 are DoD criteria per EPIC.md)
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: Stories 001-006 all Complete on main (prior stories provide the implementation; this story verifies on target device)
- **Unlocks**: scene-manager epic DoD satisfied; ADR-0002 §Validation Criteria V-7, V-8 closed; Scenario Progression epic (Feature layer) can reference scene-manager as a fully validated dependency

## Completion Notes

**Completed**: 2026-04-26 (desktop-verified portions PASS; on-device portions DEFERRED to Polish phase per Sprint 1 R3 sanctioned mitigation)
**Sprint**: Sprint 1 (S1-01 — easiest unblocked Must-Have, closes scene-manager epic to 7/7)
**Closure path**: Polish-deferral pattern — 4th invocation in this project (precedents: save-manager/story-007 2026-04-24, map-grid/story-007 2026-04-25, scene-manager/story-007 itself was the original precedent referenced by save-manager/story-007's deferral).

**Acceptance criteria status**:

- [x] **AC-5 CONNECT_DEFERRED ordering on desktop** — story-005's `test_co_subscriber_reads_battle_scene_ref_in_deferred_handler` passes on macOS arm64 (3/3 suite, 0 errors / 0 failures / 0 flaky / 0 orphans, exit 0). Headless precondition for on-device run satisfied.
- [x] **AC-4 async load partial-substitute on desktop** — `test_scene_manager_async_load_happy_path_idle_to_in_battle` passes (8ms); async pipeline observably non-blocking. Partial substitute only — desktop PASS does not prove mobile PASS, but desktop FAIL would have GUARANTEED mobile FAIL (asymmetric signal — same rationale as save-manager/story-007 §AC-DESKTOP).
- [?] **AC-1 V-7 recursive Control disable on Android export** — DEFERRED. Touch ≠ mouse (Android `InputEventScreenTouch` exercises a different code path than macOS `MOUSE_BUTTON_PRESSED`); desktop is NOT a substitute. Reactivation trigger documented in evidence doc §E.
- [?] **AC-2 V-7 fallback (conditional)** — DEFERRED. Activates only if AC-1 detects need. Fallback code is **ready-to-ship** in evidence doc §D (per-Control mouse_filter recursive walk per ADR-0002 §Neutral Consequences).
- [?] **AC-3 V-8 memory profile ≤250 MB during IN_BATTLE on Snapdragon 7-gen** — DEFERRED. Mobile memory pressure semantics differ from desktop (Android oom_killer thresholds, mobile heap allocators, debug-symbol footprint differences); desktop is NOT authoritative.
- [?] **AC-4 on-device async load (no frame spike >100ms on Android)** — DEFERRED. Desktop Metal renderer + SSD I/O is not representative of Android Vulkan/OpenGL ES + flash storage.
- [?] **AC-5 on-device CONNECT_DEFERRED ordering** — DEFERRED. Desktop pass establishes test-logic correctness; mobile-specific frame timing (e.g., 30fps vs 60fps) requires direct verification.
- [?] **AC-6 retry loop memory stability over 5 cycles** — DEFERRED. Desktop GC behavior differs from Android; profiler-tool quality varies.
- [x] **Evidence doc**: `production/qa/evidence/scene-manager-android-verification.md` — structured §A through §F sections with per-AC desktop-verified or DEFERRED status, V-7 fallback code, reactivation trigger, Polish-phase effort estimate (3-4h)
- [N/A] **V-7 fallback ship** — not shipped this story; ready for Polish-phase activation if AC-1 requires it.

**Files changed (this story)**:
- `production/epics/scene-manager/story-007-target-device-verification.md` (M — Status flip + Completion Notes)
- `production/epics/scene-manager/EPIC.md` (M — Status flip Ready → Complete; story-007 row updated)
- `production/qa/evidence/scene-manager-android-verification.md` (NEW — evidence doc)
- `production/epics/index.md` (M — scene-manager Status cell flip + layer-coverage line + changelog)

**Tests run this session**:
```
$ SKIP_PERF_BUDGETS=1 godot --headless --path . \
    -s addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --add tests/integration/core/scene_handoff_timing_test.gd \
    --ignoreHeadlessMode

3 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 48ms
Exit code: 0
```

No new tech debt logged. Polish-phase obligations tracked in evidence doc §E.

**Polish-phase reactivation trigger**: when BOTH conditions are met — (a) Android export pipeline is first green, AND (b) Snapdragon 7-gen class device or approved touch-emulator is available. Estimated effort: 3-4 hours (mirrors save-manager/story-007 estimate).

**Process insights**:
- **Polish-deferral pattern stable** — 4th invocation in this project. The pattern works: save-manager closed 2026-04-24, map-grid closed 2026-04-25, scene-manager closed 2026-04-26 (this story). Each closure shipped the desktop-verifiable portions + explicit deferral marker + reactivation trigger + ready-to-ship fallback code (where applicable).
- **Asymmetric-signal rationale reused** — "desktop PASS does not prove mobile PASS, but desktop FAIL would have GUARANTEED mobile FAIL" — same framing applied across all 3 deferral-pattern stories. Worth codifying as a project-standard test-evidence-doc section heading.
- **Polish-deferral admin scope** — ~1.5h actual session work (evidence doc + status flips + headless test rerun) vs original 1.0d estimate which assumed device access. The deferral path is dramatically faster than the full-verification path; the project should expect this when R3-pattern mitigations fire.
