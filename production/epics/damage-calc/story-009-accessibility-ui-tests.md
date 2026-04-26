# Story 009: Accessibility UI tests — TalkBack + Reduce Motion + monochrome distinguishability

> **Epic**: damage-calc
> **Status**: Ready
> **Layer**: Feature
> **Type**: Visual/Feel
> **Manifest Version**: 2026-04-20
> **Estimate**: 5-6 hours (3 accessibility ACs across headed CI + manual walkthrough + lead sign-off)

## Context

**GDD**: `design/gdd/damage-calc.md`
**Requirement**: `TR-damage-calc-010` (test infrastructure — headed CI portion)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012 Damage Calc
**ADR Decision Summary**: ADR scope locks the test infrastructure prerequisite (headed `xvfb-run` CI for AC-DC-46 frame-trace + AC-DC-47 monochrome screenshot capture); UI implementation is deferred to the future Battle HUD ADR. This story implements the test infrastructure that observes UI accessibility behavior via Damage Calc's `ResolveResult.source_flags` provenance + popup lifecycle.

**Engine**: Godot 4.6 | **Risk**: LOW (test infrastructure) / MEDIUM (cross-platform UI on Android/iOS for AC-DC-45 manual)
**Engine Notes**: AC-DC-46 wall-clock-deltas pattern (NOT frame-counts) per damage-calc.md rev 2.6 BLK-7-3 — frame-count assertions are non-deterministic under `xvfb-run` virtual display where Godot does not vsync-lock. Use `Time.get_ticks_msec()` snapshots at lifecycle events with ±33ms tolerance per assertion.

**Control Manifest Rules (Feature layer)**:
- Required: All accessibility tests run on **release-config builds** (not debug) — AC-DC-45 build-mode sentinel mandatory per damage-calc.md rev 2.4 BLK-6
- Required: All AC-DC-46 frame-trace assertions use wall-clock deltas (`Time.get_ticks_msec()`), NOT frame counts (per AC-DC-46 rev 2.6 BLK-7-3)
- Required: All AC-DC-47 monochrome distinguishability tests use deterministic factory functions for popup state preconditions (per AC-DC-47 rev 2.6 BLK-7-6 stagable-preconditions fix)
- Forbidden: `OS.is_debug_build()` gate on user-facing accessibility text (per AC-DC-45 rev 2.5 BLK-6-10 — WCAG 2.1 SC 4.1.3 compliance)
- Forbidden: Stub copy ("not yet implemented", "TODO", "placeholder") in user-facing strings (per AC-DC-45 rev 2.5 BLK-6-10 + CI-lint guard)

---

## Acceptance Criteria

*From damage-calc.md AC-DC-45/46/47 + UI-4 commitments:*

- [ ] **AC-DC-45 (TalkBack/VoiceOver)**: HIT path emits `"<defender_name> hit for <raw>, <provenance>"` (e.g., `"Lu Bu hit for 64, REAR Charge"`); MISS path emits `"<defender_name> evaded"` (terrain evasion only — invariant-violation MISSes produce no announcement); skill_unresolved emits **player-safe** `"Skill unavailable"` in **all builds** (no debug gate). Walkthrough on release-config Android + iOS with build-mode sentinel evidence; throttle 1 announcement per 500ms during rapid hits.
- [ ] **AC-DC-46 (Reduce Motion lifecycle)**: With Reduce Motion toggle enabled, HIT_DEVASTATING popup: (a) `Control.scale.x == 1.0` at first `process` tick post-spawn (no spawn animation tween); (b) `Control.visible == true` at first `process` tick; (c) total lifecycle `msec_free - msec_spawn ∈ [1517, 1583]` ms (1550ms ± 33ms); (d) `position.y` delta from spawn to free ≤ 8.0 Godot units; (e) hold-phase wall-clock duration `[1167, 1233]` ms (1200ms ± 33ms) for ALL tiers including HIT_NORMAL (confirms `max(baseline_hold, 1200ms)` elevation per UI-4)
- [ ] **AC-DC-47 (Monochrome distinguishability)**: 4 popup tiers (HIT_NORMAL=28sp/55%, HIT_DIRECTIONAL=34sp/45%, HIT_DEVASTATING=42sp/80%, MISS=22sp/no-backing) — instantiate via deterministic factory; apply Godot `Viewport.canvas_item_default_texture_filter` grayscale post-process; capture 4 screenshots; assert (a) text height differs by ≥ 4px between every tier pair (size primary channel); (b) backing opacity differs by ≥ 10% between neighboring tiers (lowered from 15% per rev 2.6 — non-monotonic NORMAL→DIRECTIONAL intentional). QA lead reviews screenshots + signs off; sign-off explicitly confirms non-monotonic DIRECTIONAL opacity reads as intentional.
- [ ] AC-DC-45 build-mode sentinel implemented: autoload bootstrap emits one-time `[BUILD_MODE] release` or `[BUILD_MODE] debug` boot log line + renders the same string in top-right accessibility-debug overlay chip (visible only when "Show build mode" toggle enabled, defaults ON for QA builds)
- [ ] AC-DC-45 stub-copy CI-lint guard: grep `not yet implemented|TODO|placeholder|stub` against user-facing string literals in `src/feature/damage_calc/` returns 0 matches
- [ ] All 3 walkthrough/sign-off evidence files written to `production/qa/evidence/`

---

## Implementation Notes

*Derived from damage-calc.md UI-4 + AC-DC-45/46/47 rev histories + ADR-0012 §10:*

- **Test base class**: extends `GdUnitTestSuite` (Node base) for UI tests in this story (AC-DC-46/47) — required for `Viewport` capture, `Control` node observation, and `process` tick callbacks. Other Damage Calc tests (Logic) may use the lighter RefCounted base.
- **Headed CI runner**: `xvfb-run` virtual display on Linux (per Story 001 prerequisite). AC-DC-46/47 use `Engine.max_fps = 60` and `Engine.physics_ticks_per_second = 60` at fixture setup to bound scheduling jitter; assertions are wall-clock deltas, not frame counts.
- **AC-DC-45 build-mode sentinel** (per damage-calc.md rev 2.4 BLK-6 + Phase-5 DevOps Cross-System Patches Queued #12):
  - Add autoload `BuildModeSentinel` (or equivalent name) — emits `print("[BUILD_MODE] %s" % ("release" if not OS.is_debug_build() else "debug"))` at `_ready()`.
  - Add accessibility-debug overlay chip showing the same string; visible only when in-game Settings → "Show build mode" toggle is enabled (defaults ON for QA builds, OFF for production builds).
  - Walkthrough evidence file `production/qa/evidence/damage_calc_talkback_walkthrough.md` header MUST include either (a) captured `[BUILD_MODE] release` log line OR (b) build-mode-chip screenshot — proves release-config testing.
- **AC-DC-45 walkthrough (manual)**: tester captures TalkBack/VoiceOver enabled on release-config Android (TalkBack) + release-config iOS (VoiceOver); fires 3 representative HITs (with Charge, with Ambush, with terrain_penalty); fires 1 MISS via terrain evasion; fires 1 skill_unresolved (skill_id != ""); confirms each announcement matches spec exactly:
  - HIT format: `"<defender_name> hit for <raw>, <provenance>"` — provenance derived from `result.source_flags` per CR-11 vocabulary
  - MISS evasion: `"<defender_name> evaded"` (no announcement for invariant-violation MISSes — silent guard)
  - skill_unresolved: `"Skill unavailable"` (NOT `"<attacker_name> skill not yet implemented"` — per rev 2.5 BLK-6-10 stub-copy guard)
- **AC-DC-46 Reduce Motion test pattern** (rev 2.6 BLK-7-3 wall-clock rewrite):
  ```gdscript
  func test_reduce_motion_lifecycle():
      Settings.reduce_motion_enabled = true
      var msec_spawn := Time.get_ticks_msec()
      var popup := damage_popup_factory.spawn(HIT_DEVASTATING, …)
      await popup.scale_settled  # custom signal at first process tick
      assert(popup.scale.x == 1.0, "Reduce Motion: no spawn animation")
      assert(popup.visible == true, "Reduce Motion: visible at spawn")
      var msec_scale_settled := Time.get_ticks_msec()
      await popup.fade_started  # custom signal at hold-phase end
      var msec_fade_start := Time.get_ticks_msec()
      var hold_duration := msec_fade_start - msec_scale_settled
      assert(hold_duration >= 1167 and hold_duration <= 1233, "Hold phase 1200ms ±33ms")
      await popup.tree_exited
      var msec_free := Time.get_ticks_msec()
      var lifecycle := msec_free - msec_spawn
      assert(lifecycle >= 1517 and lifecycle <= 1583, "Total lifecycle 1550ms ±33ms")
      var drift := abs(popup.position.y - msec_spawn_position_y)
      assert(drift <= 8.0, "Position drift ≤ 8 units")
  ```
- **AC-DC-47 Monochrome distinguishability** (rev 2.6 BLK-7-6 stagable-preconditions fix):
  ```gdscript
  func test_colorblind_monochrome_distinguishable():
      var popups := [
          damage_popup_factory.create_static(HIT_NORMAL, 28, 0.55),
          damage_popup_factory.create_static(HIT_DIRECTIONAL, 34, 0.45),
          damage_popup_factory.create_static(HIT_DEVASTATING, 42, 0.80),
          damage_popup_factory.create_static(MISS, 22, 0.0),
      ]
      Viewport.canvas_item_default_texture_filter = Viewport.CanvasItemTextureFilter.GRAYSCALE
      var screenshots := popups.map(func(p): return Viewport.get_texture().get_image())
      # save screenshots to production/qa/evidence/damage_calc_colorblind_screenshot.md
      # assert size+opacity composite distinguishability per AC criteria
  ```
- **AC-DC-47 size+opacity assertions**:
  - Size deltas: 22→28 (=6px), 28→34 (=6px), 34→42 (=8px). All ≥ 4px ✅
  - Opacity deltas (neighboring tiers): NORMAL→DIRECTIONAL = |55-45| = 10% (passes ≥10% exact); DIRECTIONAL→DEVASTATING = |45-80| = 35% (wide margin); DEVASTATING→MISS = |80-0| = 80% (max margin)
  - QA lead reviews `production/qa/evidence/damage_calc_colorblind_screenshot.md` + signs off — sign-off explicitly confirms non-monotonic DIRECTIONAL 45% reads as intentional lightness, not a visual bug
- **AC-DC-45 stub-copy CI-lint guard**: integrate `grep -i "not yet implemented\\|TODO\\|placeholder\\|stub" src/feature/damage_calc/` as a CI step that fails on any user-facing string-literal match. Pattern matches existing CI lint precedents.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 010: AC-DC-40(a)/(b) performance baseline (separate test category — Logic, not Visual/Feel)
- Future Battle HUD ADR + epic: actual UI implementation of damage popups (this story tests the lifecycle infrastructure; popup rendering implementation is downstream)

---

## QA Test Cases

*Authored from damage-calc.md AC-DC-45/46/47 directly. Manual walkthroughs + automated headed tests + lead sign-off.*

- **AC-1 (AC-DC-45 TalkBack/VoiceOver — manual walkthrough)**:
  - Setup: release-config Android + iOS builds with TalkBack/VoiceOver enabled; build-mode sentinel verified (log line OR chip screenshot)
  - Verify: 3 HIT scenarios, 1 MISS evasion, 1 skill_unresolved fire on each platform; announcements match spec exactly
  - Pass condition: tester signs off in `production/qa/evidence/damage_calc_talkback_walkthrough.md` with build-mode sentinel evidence; supplementary CI-lint AC-DC-45 stub-copy guard returns 0 matches

- **AC-2 (AC-DC-46 Reduce Motion lifecycle — automated headed CI)**:
  - Given: headed `xvfb-run` Linux job; Reduce Motion toggle enabled; HIT_DEVASTATING popup factory
  - When: 5 lifecycle events captured via `Time.get_ticks_msec()` snapshots
  - Then: scale.x=1.0 at first tick; visible=true at first tick; total lifecycle 1550ms ±33ms; position drift ≤ 8 units; hold phase 1200ms ±33ms across all 4 tiers
  - Edge cases: HIT_NORMAL hold elevated to 1200ms (confirms `max(baseline_hold, 1200ms)` per UI-4)

- **AC-3 (AC-DC-47 Monochrome distinguishability — automated + lead sign-off)**:
  - Given: 4 popup tiers via deterministic factory; grayscale post-process applied
  - When: 4 screenshots captured + saved to evidence file
  - Then: text height ≥ 4px delta between every tier pair; backing opacity ≥ 10% delta between neighboring tiers; QA lead signs off in `production/qa/evidence/damage_calc_colorblind_screenshot.md` confirming intentional non-monotonic DIRECTIONAL opacity
  - Edge cases: forced monotonic opacity would erase design semantics (DIRECTIONAL 청회 blue carries glyph-level contrast) — sign-off explicitly addresses this

- **AC-4 (Build-mode sentinel)**:
  - Given: release-config build
  - When: app starts
  - Then: log contains `[BUILD_MODE] release` exactly once; chip overlay (when enabled) displays `release`; verify same on debug-config build with `debug`

- **AC-5 (AC-DC-45 stub-copy CI-lint)**:
  - Given: completed `src/feature/damage_calc/` source files
  - When: `grep -i "not yet implemented\\|TODO\\|placeholder\\|stub" src/feature/damage_calc/`
  - Then: 0 matches in user-facing string literals (TODOs in source comments are allowed; user-facing string LITERALS are not)

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- `tests/integration/damage_calc/damage_calc_ui_test.gd` — headed CI (xvfb-run) tests for AC-DC-46/47
- `production/qa/evidence/damage_calc_talkback_walkthrough.md` — manual walkthrough with build-mode sentinel evidence; tester sign-off
- `production/qa/evidence/damage_calc_reduce_motion_walkthrough.md` — manual visual confirmation alongside automated AC-DC-46
- `production/qa/evidence/damage_calc_colorblind_screenshot.md` — 4 grayscale screenshots + QA lead sign-off

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006 (completed `damage_calc.gd` pipeline — provenance from `result.source_flags` feeds TalkBack format) + Story 001 (CI infrastructure — headed `xvfb-run` job)
- Unlocks: Battle HUD epic (future) — popup-rendering UI implementation downstream
