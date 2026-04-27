# Story 009: Accessibility infrastructure prerequisites — build-mode sentinel + stub-copy CI-lint

> **Epic**: damage-calc
> **Status**: Complete (2026-04-27)
> **Layer**: Platform (autoload) + Feature (lint scope)
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 1.5-2 hours (build-mode sentinel autoload + boot-log test + stub-copy lint script + CI step + evidence doc)
> **Scope-split note (2026-04-27)**: Original story spanned 6 ACs across TalkBack + Reduce Motion + monochrome + sentinel + lint. Per ADR-0012 §GDD Requirements Addressed (AC-DC-45..47 line: *"ADR scope: locks the test infrastructure prerequisite, defers UI implementation to Battle HUD ADR"*), AC-DC-45/46/47 + chip-overlay UI portion of original AC-4 are deferred to the future Battle HUD epic — see §Deferred to Battle HUD Epic below. This story now ships only the headless prerequisites: boot-log sentinel + stub-copy lint guard.

## Context

**GDD**: `design/gdd/damage-calc.md`
**Requirement**: `TR-damage-calc-010` (test infrastructure prerequisites — partial coverage; the headed `xvfb-run` portion remains deferred to Battle HUD epic per scope-split). The stub-copy CI-lint guard is the headless portion of AC-DC-45 rev 2.5 BLK-6-10 stub-copy enforcement.
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012 Damage Calc
**ADR Decision Summary**: ADR §10 #1 (headless CI per push) is already in place from story-001. This story adds two narrow infrastructure pieces: (a) boot-log build-mode sentinel autoload — required precondition for AC-DC-45 release-config testing in the future Battle HUD epic; (b) stub-copy CI-lint guard — pre-emptive grep over `src/feature/damage_calc/` user-facing strings per AC-DC-45 rev 2.5 BLK-6-10 + WCAG 2.1 SC 4.1.3 compliance.

**Engine**: Godot 4.6 | **Risk**: LOW (autoload + shell lint, no engine-API surface beyond `_ready()` + `OS.is_debug_build()`)
**Engine Notes**: `OS.is_debug_build()` is pre-4.4 stable; `print()` to standard output is pre-4.4 stable. No post-cutoff API risk.

**Control Manifest Rules (Platform + Feature layer cross-cut)**:
- Required: Static typing on autoload class (per Global Rules §Current Best Practices — `Static typing mandatory across all GDScript`)
- Required: User-facing strings in `src/feature/damage_calc/` MUST NOT contain stub copy ("not yet implemented", "TODO", "placeholder", "stub") — CI grep enforced (AC-2 of this story)
- Forbidden: `OS.is_debug_build()` gate on user-facing accessibility text (per AC-DC-45 rev 2.5 BLK-6-10) — sentinel itself uses `OS.is_debug_build()` only for the `[BUILD_MODE]` discriminator, NOT for gating user-facing text

---

## Acceptance Criteria

*From damage-calc.md AC-DC-45 prerequisites portion (boot-log half of build-mode sentinel) + stub-copy CI-lint guard:*

- [ ] **AC-1 (Build-mode sentinel autoload — boot log)**: `BuildModeSentinel` autoload (registered in `project.godot`) emits exactly one log line at `_ready()`: `[BUILD_MODE] release` if `not OS.is_debug_build()`, else `[BUILD_MODE] debug`. The line is captured in CI stdout for headless test runs (and future headed CI runs). Headless evidence (CI log capture or local headless run) saved to `production/qa/evidence/damage_calc_build_mode_sentinel.md`.
- [ ] **AC-2 (Stub-copy CI-lint guard)**: `tools/ci/lint_damage_calc_no_stub_copy.sh` grep-recurses `src/feature/damage_calc/` for case-insensitive matches of `not yet implemented|TODO|placeholder|stub` in user-facing string literals (i.e., quoted GDScript string contents — `"..."` and `'...'`); excludes GDScript `#` line comments. Exits 0 with 0 matches; exits 1 with any match. Wired as a CI step in `.github/workflows/tests.yml` mirroring existing 3 damage-calc lint precedents.
- [ ] **AC-3 (Test evidence + boot-log unit test)**: Unit test `tests/unit/platform/build_mode_sentinel_test.gd` asserts the autoload emits exactly one `[BUILD_MODE] %s` line at `_ready()`, where `%s` matches `OS.is_debug_build()` truth value. Evidence doc `production/qa/evidence/damage_calc_build_mode_sentinel.md` captures (a) CI log line excerpt OR (b) local headless run capture, demonstrating the sentinel fires correctly under headless config + a Reactivation note pointing to Battle HUD epic for release-config walkthrough.

---

## Implementation Notes

*Derived from damage-calc.md rev 2.4 BLK-6 + Phase-5 DevOps Cross-System Patches Queued #12; narrowed per scope-split:*

- **Build-mode sentinel autoload** (`src/platform/build_mode_sentinel.gd`):
  ```gdscript
  ## Boot-time build-mode sentinel — emits one [BUILD_MODE] log line at _ready().
  ## Release-config testing precondition for AC-DC-45 (TalkBack/VoiceOver walkthrough,
  ## deferred to Battle HUD epic). Chip-overlay UI portion is also Battle-HUD-deferred.
  ## NO class_name declaration — autoload name IS the global identifier (G-3:
  ## declaring class_name on an autoload script hides the singleton).
  extends Node

  func _ready() -> void:
      var mode: String = "release" if not OS.is_debug_build() else "debug"
      print("[BUILD_MODE] %s" % mode)
  ```
  - Registered as autoload `BuildModeSentinel` in `project.godot` (singleton instance loaded at boot).
  - Static-typed per Global §Current Best Practices.
  - One-time emission only — no `_process` overhead, no recurring work.

- **Stub-copy CI-lint script** (`tools/ci/lint_damage_calc_no_stub_copy.sh`):
  - Mirrors `tools/ci/lint_damage_calc_no_dictionary_alloc.sh` (story-008 precedent) and `lint_damage_calc_no_hardcoded_constants.sh` (story-006b precedent) in shape: bash + grep + exit-code + descriptive failure message.
  - Pattern grep: case-insensitive `not yet implemented|TODO|placeholder|stub` against quoted string literals only. GDScript `#` line comments are excluded (TODOs in source comments are allowed; user-facing string LITERALS are not — per story spec).
  - Implementation hint: extract quoted-string literals from `.gd` files (via grep with capture or sed), then grep for stub-copy patterns within those captures. Specialist may select the cleanest BSD/GNU-portable pattern.
  - Exit codes: 0 = clean, 1 = matches found (CI fails the job). Print matched filename + line number on failure.

- **CI workflow integration** (`.github/workflows/tests.yml`):
  - Add a step `name: AC-DC-45 stub-copy lint guard` after the existing 3 damage-calc lint steps (no-dictionary-alloc, no-hardcoded-constants, etc.). Run on every push.

- **Test for build-mode sentinel** (`tests/unit/platform/build_mode_sentinel_test.gd`):
  - GdUnitTestSuite extending Node (autoload behaviour requires `_ready()` lifecycle).
  - Strategy: instantiate a fresh `BuildModeSentinel` Node via `BuildModeSentinel.new()` + `add_child` and verify the resulting log/print behavior. Project autoload itself runs once at game boot before tests start, so the test exercises a fresh instance.
  - Assertions: instantiate → `add_child` triggers `_ready()` → exactly one `[BUILD_MODE]` line emitted; mode string is `OS.is_debug_build() ? "debug" : "release"` (matches `OS.is_debug_build()` truth value at test-time, not hardcoded).
  - Print-capture pattern: GdUnit4 provides `assert_str` with stdout/print interception helpers; specialist chooses the cleanest available primitive. If no first-class print-capture API exists in GdUnit4 4.x, alternative pattern: refactor sentinel to expose a typed `_emit_line() -> String` method that returns the exact line, with `_ready()` calling `print(_emit_line())` — test asserts on the returned string. Specialist decides at implementation time.

- **Evidence doc** (`production/qa/evidence/damage_calc_build_mode_sentinel.md`):
  - Sections: Purpose / CI capture / Local-headless capture / Reactivation note (when Battle HUD epic re-opens AC-DC-45 release-config walkthrough).
  - Headless capture pattern: `godot --headless --quit-after 1 2>&1 | grep BUILD_MODE` produces `[BUILD_MODE] debug`. (For release-config capture, awaits Battle HUD epic's release export pipeline.)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 010: AC-DC-40(a)/(b) performance baseline (separate test category — already complete via PR #70)
- **Future Battle HUD epic** (see §Deferred to Battle HUD Epic): all Reduce Motion lifecycle (AC-DC-46), monochrome distinguishability (AC-DC-47), TalkBack/VoiceOver walkthrough (AC-DC-45), chip-overlay UI portion of build-mode sentinel, and the headed `xvfb-run` CI lane

---

## Deferred to Battle HUD Epic

The following items were originally in story-009 scope and are now deferred — to be re-stitched into Battle HUD epic stories when `/create-epics battle-hud` runs. Each row uses the Polish-deferral 4-element template (deferral reason + reactivation trigger + ready-to-ship fallback + estimated Polish-phase effort). This is the **6th invocation** of the now-stable 5-precedent pattern.

| Original AC | Deferred work | Reactivation trigger | Ready-to-ship fallback | Estimated Polish-phase effort |
|---|---|---|---|---|
| AC-DC-45 (TalkBack/VoiceOver manual walkthrough) | Manual a11y walkthrough on release-config Android (TalkBack) + iOS (VoiceOver); 3 HITs + 1 MISS-evasion + 1 skill_unresolved announcement spec verification | Battle HUD epic kickoff produces `DamagePopup` Control nodes that emit accessibility text via the engine's accessibility integration (AccessKit Godot 4.5+ OR platform-native `UIAccessibility`/`AccessibilityNodeInfo` — TBD at Battle HUD ADR time) | None — this is a Beta-blocker for AC-DC-45; cannot ship at Beta without it. Pre-Beta builds may carry a known-gap chip ("a11y unverified") | 2-3h once Battle HUD popup system exists |
| AC-DC-46 (Reduce Motion lifecycle automated headed CI) | xvfb-run Linux job + lifecycle assertions on `DamagePopup` (5 wall-clock-delta msec snapshots; ±33ms tolerance per assertion) | Battle HUD epic ships `DamagePopup` factory + `Settings.reduce_motion_enabled` autoload + `popup.scale_settled` / `popup.fade_started` signals | None — this is a Beta-blocker for AC-DC-46 | 3-4h once popup factory + Settings autoload exist |
| AC-DC-47 (Monochrome distinguishability automated + lead sign-off) | 4-tier popup screenshot capture under grayscale post-process; size-delta + opacity-delta assertions; QA-lead sign-off | Battle HUD epic ships popup tiers (HIT_NORMAL/HIT_DIRECTIONAL/HIT_DEVASTATING/MISS) with deterministic factory function | None — this is a Beta-blocker for AC-DC-47 | 3-4h once popup tier classes exist |
| AC-4 chip-overlay portion of build-mode sentinel | Top-right CanvasLayer Control showing `[BUILD_MODE]` text; visible only when `Settings.show_build_mode` toggle enabled | Battle HUD epic introduces `Settings` autoload + accessibility-debug overlay surface | None — chip is a QA convenience, not Beta-blocker. Boot log line (this story's AC-1) is the authoritative build-mode signal until chip is added. | 1-1.5h |
| Headed `xvfb-run` CI lane | Linux runner with virtual display configured; weekly + `rc/*` tag cadence; runs AC-DC-46/47 only | Battle HUD epic's first UI INTEGRATION story needing it | None — TR-damage-calc-010 §item-2 commitment carries forward intact; no contract change | 2-3h DevOps |

---

## QA Test Cases

*Authored from narrowed AC-1/2/3 directly. Headless automated + 1 evidence doc.*

- **TC-1 (AC-1 build-mode sentinel boot log — automated)**:
  - Setup: instantiate `BuildModeSentinel` Node + add to scene tree
  - Verify: `_ready()` callback fires; stdout contains exactly one `[BUILD_MODE]` line; mode string matches `OS.is_debug_build()` truth value
  - Pass condition: full-suite GdUnit4 PASS including new `build_mode_sentinel_test.gd`
- **TC-2 (AC-2 stub-copy CI-lint — automated)**:
  - Setup: clean `src/feature/damage_calc/` tree (post-story-008 state, all real strings)
  - Verify: `tools/ci/lint_damage_calc_no_stub_copy.sh` exits 0 with no output
  - Edge case: insert temporary `var msg := "TODO: implement"` in `damage_calc.gd` → script exits 1 with line-number match → revert before commit (verifies the script CAN fail when needed)
  - Pass condition: CI step `AC-DC-45 stub-copy lint guard` reports green on PR
- **TC-3 (AC-3 evidence doc)**:
  - Setup: run `godot --headless --quit-after 1` locally + capture stdout
  - Verify: stdout includes `[BUILD_MODE] debug` (debug-config) — copy excerpt into evidence doc
  - Pass condition: evidence doc exists with capture excerpt + reactivation note pointing to Battle HUD epic's release-config walkthrough

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/platform/build_mode_sentinel_test.gd` — boot-log unit test (BLOCKING per Logic Story Type rules)
- `production/qa/evidence/damage_calc_build_mode_sentinel.md` — local-headless capture + reactivation note (ADVISORY)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006 (Complete) + Story 001 (Complete) — both already merged
- Unlocks: Battle HUD epic (future) — re-stitches the 4 deferred ACs above + chip-overlay portion + headed xvfb-run CI lane into its first stories

---

## Completion Notes

**Completed**: 2026-04-27
**Verdict**: COMPLETE WITH NOTES (4 advisory deviations, all DEFER)
**Criteria**: 3/3 passing (no UNTESTED, no DEFERRED)

**Files delivered (4 new + 2 modified + 1 admin scope-split)**:
- NEW `src/platform/build_mode_sentinel.gd` (28 lines) — Platform-layer autoload, no `class_name` (G-3 compliant). `_compose_line() -> String` extracted for testability.
- NEW `tests/unit/platform/build_mode_sentinel_test.gd` (67 lines, 2 functions) — both PASS in regression.
- NEW `tools/ci/lint_damage_calc_no_stub_copy.sh` (62 lines) — quoted-string-extraction approach, set -euo pipefail.
- NEW `production/qa/evidence/damage_calc_build_mode_sentinel.md` (92 lines) — local-headless capture + reactivation note.
- M `project.godot` — added `BuildModeSentinel` autoload (after `GameBusDiagnostics`).
- M `.github/workflows/tests.yml` — added 7th damage-calc lint step `Lint DamageCalc no stub-copy in user-facing strings (AC-DC-45 TR-damage-calc-010)`.
- Admin scope-split (this story file + EPIC.md): originally Visual/Feel for AC-DC-45/46/47; narrowed to Logic-only headless prerequisites. Battle-HUD-deferred items documented in §Deferred to Battle HUD Epic.

**Verification gate passed**:
- `godot --headless --import --path .` → exit 0
- Local-headless boot capture (via GdUnit4 bootstrap): `[BUILD_MODE] debug` × 3 (one per suite tree)
- Full GdUnit4 regression: **388/388 PASS, 0 errors / 0 failures / 0 flaky / 0 orphans** (was 386; +2 new tests)
- Lint clean: exit 0
- Lint failure-injection (TC-2 edge case): exit 1 with `resolve_result.gd:46:"TODO: implement"` → revert → exit 0
- All 6 damage-calc lints: all exit 0

**Code review (lean mode)**: APPROVED WITH SUGGESTIONS — godot-gdscript-specialist + qa-tester both 0 Tier-1, 8 Tier-2 (all DEFER). 1 convergent fix applied (story spec pseudocode `class_name` removal — G-3 corrective).

**Story spec deviations (authorized)**:
1. **G-3 corrective** — omitted `class_name BuildModeSentinel` from autoload script (story spec showed it; G-3 forbids it). Tests use `load(...).new()` instead. Story spec pseudocode updated post-/code-review to match.
2. **Local-headless capture method** — `--quit-after 1` errors with "no main scene defined" on this project; substituted GdUnit4 test runner as SceneTree bootstrap. Documented in evidence doc with G-14 cross-reference.
3. **Lint script approach corrected** in-orchestrator — agent's initial whole-line grep + comment-line filter false-positived on `resolve_modifiers.gd:12` inline comment. Replaced with quoted-string extraction (`grep -oE '"[^"]*"|'\''[^'\'']*'\''`). Now zero false positives on existing tree.

**Advisory deviations (DEFER, all)**:
1. AC-1 emission-count regression detection requires evidence re-capture (unit test asserts `_compose_line()` content; print-invocation count covered only empirically). Accepted per design.
2. AC-2 lint regex doesn't handle multiline `"""..."""` strings or escaped quotes inside literals. Logged as TD-040 in `docs/tech-debt-register.md`.
3. Evidence doc `[pending] CI Capture` section — AC-3 OR clause already satisfied; fill-in deferred to post-merge.
4. Scope-split — original AC-DC-45/46/47 + chip overlay + xvfb-run CI lane deferred to Battle HUD epic. **6th invocation of stable Polish-deferral 4-element template** (pattern remains stable at 5).

**Tech debt logged**: 1 (TD-040 — lint regex multiline/escape edge cases).

**Damage-calc epic close**: 11/11 stories complete with 4 carry-forward items to Battle HUD epic. Epic CLOSES at this story's merge.
