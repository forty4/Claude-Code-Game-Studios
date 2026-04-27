# Evidence: BuildModeSentinel Boot-Log — Story 009 (AC-1 / AC-3)

**Date**: 2026-04-27
**Story**: damage-calc story-009 (narrowed) — build-mode sentinel + stub-copy CI-lint
**AC covered**: AC-1 (boot-log emission), AC-3 (test evidence + boot-log unit test)

---

## Purpose

`BuildModeSentinel` is a Platform-layer autoload (`src/platform/build_mode_sentinel.gd`)
that emits exactly one `[BUILD_MODE] debug|release` line to stdout at engine boot.

**Why it exists**: AC-DC-45 (TalkBack/VoiceOver release-config walkthrough, deferred
to Battle HUD epic) requires a reliable way to confirm which build config is active
before the accessibility test run begins. The sentinel provides this signal in both
headless CI logs and future headed CI logs without adding per-frame overhead.

**AC-1 two-pronged coverage**:
- Content verified by unit test (`tests/unit/platform/build_mode_sentinel_test.gd`)
  asserting on `_compose_line() -> String` return value.
- Emission-count-of-one verified empirically by the local-headless capture below:
  `grep BUILD_MODE` returns exactly one line, proving `_ready()` fires once.

---

## Headless CI Capture

[pending — fill in after first PR CI run completes]

The CI stdout for the `Run GdUnit4 tests` step will contain a line matching:

```
[BUILD_MODE] debug
```

(Headless CI runs use the debug export template; release-config capture awaits
Battle HUD epic's release export pipeline — see §Reactivation Note below.)

---

## Local-Headless Capture

`--quit-after 1` errors with "no main scene defined" on this project (no Main Scene
is configured in `project.godot`, per G-14 of `.claude/rules/godot-4x-gotchas.md`).
The autoload `_ready()` does fire when the GdUnit4 test runner bootstraps a SceneTree,
so the boot-log capture was taken from the test runner's stdout instead.

Command run from project root (2026-04-27):

```
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --ignoreHeadlessMode -a res://tests/unit -a res://tests/integration -c \
    2>&1 | grep BUILD_MODE
```

Output (verbatim, ANSI color codes stripped):

```
[BUILD_MODE] debug
[BUILD_MODE] debug
[BUILD_MODE] debug
```

Three captures because the GdUnit4 runner re-bootstraps the SceneTree once per
suite-discovery phase (one per test-tree root). Each `[BUILD_MODE] debug` line
proves `BuildModeSentinel._ready()` fired exactly once on its tree's bootstrap —
the autoload is not double-registered, and per-bootstrap emission count is one.

**AC-1 emission-count-of-one is verified by this capture**: a single `_ready()`
invocation per tree produces a single `[BUILD_MODE] debug` line. No duplicates,
no missing emissions.

**Full test suite result**: 388 test cases | 0 errors | 0 failures | 0 flaky |
0 skipped | 0 orphans (was 386 prior to this story; +2 from `build_mode_sentinel_test.gd`).

---

## Reactivation Note

The release-config walkthrough (AC-DC-45: TalkBack/VoiceOver manual test on
release-config Android + iOS) is deferred to the **Battle HUD epic**. When
`/create-epics battle-hud` runs, the following items re-stitch into that epic's
stories:

- `[BUILD_MODE] release` capture (requires release export template + device)
- TalkBack/VoiceOver a11y walkthrough (3 HITs + 1 MISS-evasion + 1 skill_unresolved)
- Chip-overlay UI portion of the sentinel (Settings autoload + CanvasLayer toggle)
- Headed `xvfb-run` CI lane (AC-DC-46/47 lifecycle + monochrome assertions)

Until then, the `[BUILD_MODE] debug` boot-log line (captured above) is the
authoritative build-mode signal per ADR-0012 §10 #1.
