# Battle Scene Smoke Evidence — 2026-05-04

> **Story**: `production/epics/battle-scene/story-002-standalone-launch-and-smoke-evidence.md`
> **Epic**: `production/epics/battle-scene/EPIC.md`
> **ADR**: `docs/architecture/ADR-0016-battle-scene-wiring.md` (V-8 / V-9 / R-8 / Migration Plan)
> **Verifier**: Dowan Kim (orchestrator)
> **Date**: 2026-05-04
> **Test runner platform**: macOS (host); Godot 4.6.2.stable.official.71f334935; build mode = debug
> **Verification precedent**: 1st invocation of cross-launch-source smoke matrix evidence pattern (sibling pattern: `scene-manager-android-verification.md` + `battle-hud-story-003-evidence.md`)

---

## Summary

This document is the manual-verification artifact for battle-scene story-002 acceptance criteria **AC-1..AC-8**, covering the `project.godot` `[application] run/main_scene` flip and the cross-launch-source smoke matrix that proves `BattleScene._ready()` is idempotent under all 3 launch sources without launch-source branching in code.

**Verified this turn (HEADLESS Godot CLI invocations + GdUnit4 regression suite)**:

- **AC-1**: `project.godot` `run/main_scene` set to `"res://scenes/battle/battle_scene.tscn"` with adjacent `; SPRINT-6 ONLY — REVERT WHEN ADR-0017 LANDS (TR-battle-scene-wiring-005)` comment line — verified by `grep -E '^run/main_scene' project.godot` + `grep -i 'sprint-6' project.godot` (both match; lines 12-13 of `project.godot`).
- **AC-2**: Launch source (b) main_scene config — `godot --path . --headless --quit-after 60` exits 0 with zero `ERROR:` lines pointing to BattleScene mount sequence; `_ready()` completes mount of all 6 children + sprint-6 mock encounter.
- **AC-3**: Launch source (c) `--main-scene` CLI override — identical exit-0 + zero-mount-error result; **no launch-source branching** confirmed structurally (same source path → same outcome).
- **AC-4**: Launch source (a) SceneManager-driven — DEFERRED to Vertical Slice when ScenarioRunner provides `battle_launch_requested` payload; option (ii) per ADR-0016 V-11 (see §C below).
- **AC-5..AC-7**: This evidence document covers the 18-row matrix + verification commands + deferral notes + Migration Plan revert path (§A through §D below).
- **AC-8**: Regression baseline — **883/883 PASS / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0** preserved post-flip (24th consecutive failure-free baseline). The main_scene flip introduces no CI regression — the test framework's `gdunit4_runner.gd` invocation owns its own scene lifecycle and does not consult `main_scene`.

**Non-blocking findings surfaced during verification (resolved in same patch)**:

- **IN-14 amendment** (story-001 mock encoder hero IDs): production launch surfaced `unknown hero_id` push_errors for fictional ids `jangbi` / `joun` / `enemy_a` / `enemy_b`. Smoke test was passing only because IN-12 injected those exact ids into `HeroDatabase._heroes` directly. Resolution: swap to real `heroes.json` ids (`shu_003_zhang_fei`, `wu_003_zhou_yu`, `wei_001_cao_cao`, `wei_005_xiahou_dun`). Smoke test `MOCK_HERO_IDS` const updated to match. Per story IN-6 ("launch-source-specific bug surfaced during smoke → fix belongs to story-001 as an amendment"). ADR-0016 IN-14 entry appended documenting the swap. Re-run AC-2/AC-3/AC-8 all clean.

---

## §A. Launch source × mount step matrix

The 6-step `_ready()` mount sequence is per ADR-0016 §3 step order: MapGrid → BattleCamera → HPStatusController → TurnOrderRunner → GridBattleController → BattleHUD. Each cell records PASS / FAIL / DEFERRED with 1-line evidence reference.

| Mount step \ Launch source           | (a) SceneManager-driven | (b) main_scene config             | (c) `--main-scene` CLI            |
|--------------------------------------|-------------------------|-----------------------------------|-----------------------------------|
| 1. MapGrid                           | DEFERRED (see §C)       | PASS — `load_map()` 15×15 PLAINS  | PASS — same source path           |
| 2. BattleCamera                      | DEFERRED                | PASS — node attach + center_to    | PASS — same source path           |
| 3. HPStatusController                | DEFERRED                | PASS — initialize_unit ×4 (post-IN-14) | PASS — same source path     |
| 4. TurnOrderRunner                   | DEFERRED                | PASS — initialize_battle 4-roster | PASS — same source path           |
| 5. GridBattleController              | DEFERRED                | PASS — initialize 4-roster + map  | PASS — same source path           |
| 6. BattleHUD                         | DEFERRED                | PASS — setup() 9-backend DI mount | PASS — same source path           |

**Result**: 12/18 PASS + 6/18 DEFERRED (launch source (a) per ADR-0016 V-11 deferral). 0/18 FAIL.

---

## §B. Verification commands

All commands run from project root on 2026-05-04. Outputs captured to `/tmp/launch_b.log` + `/tmp/launch_c.log` + `/tmp/regression2.log` for trace.

### Launch source (b): `main_scene` config (AC-2)

```bash
godot --path . --headless --quit-after 60
echo "exit=$?"
```

Expected: exit code 0; zero `ERROR:` lines pointing to `battle_scene.gd` mount sequence; only legitimate `WARNING:` lines acceptable per AC-2 edge case.

**Actual (post-IN-14 swap)**:

```text
Godot Engine v4.6.2.stable.official.71f334935 - https://godotengine.org

[BUILD_MODE] debug
WARNING: GameBus soft cap exceeded: 271 emits this frame (cap=50). Top domains: [scenario=0, battle=0, turn=271, unit=0, destiny=0, beat=0, input=0, ui=0, save=0, environment=0]
     at: push_warning (core/variant/variant_utility.cpp:1034)
     GDScript backtrace (most recent call first):
         [0] _fire_soft_cap_warning (res://src/core/game_bus_diagnostics.gd:179)
         [1] _process (res://src/core/game_bus_diagnostics.gd:99)
exit=0
```

The single `WARNING` is from `GameBusDiagnostics._fire_soft_cap_warning()` reacting to TurnOrderRunner's first-frame burst of `turn_*` domain events during `initialize_battle()` (271 emits in 1 frame; soft cap = 50). This is pre-existing diagnostics behavior, **not a BattleScene mount sequence error**, and is acceptable per AC-2 edge case ("only `ERROR:` and `assert` failures fail this AC"). Tracking note: if the soft-cap warning becomes pollution-of-concern at the test runner tier, file a follow-up to investigate whether TurnOrderRunner.initialize_battle should batch its emits or whether the diagnostics cap should be raised; out-of-scope for this story.

### Launch source (c): `--main-scene` CLI override (AC-3)

```bash
godot --path . --headless --main-scene scenes/battle/battle_scene.tscn --quit-after 60
echo "exit=$?"
```

Expected: identical to AC-2 (no launch-source branching).

**Actual**: byte-identical `WARNING` line + `exit=0`. Confirms zero divergence between launch sources (b) and (c) — `BattleScene._ready()` runs the same code path regardless of how the engine resolved the initial scene.

### AC-1 grep verification

```bash
grep -E '^run/main_scene' project.godot
grep -i 'sprint-6' project.godot
```

**Actual**:

```text
run/main_scene="res://scenes/battle/battle_scene.tscn"
; SPRINT-6 ONLY — REVERT WHEN ADR-0017 LANDS (TR-battle-scene-wiring-005)
```

Both substrings present; comment human-greppable on its own line above the setting (alternative inline `;` placement also acceptable per IN-1; chose own-line for visual consistency with the file's existing comment style).

### AC-8 regression baseline

```bash
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --ignoreHeadlessMode -a res://tests/unit -a res://tests/integration -c
```

**Actual**: `Overall Summary: 883 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | exit_code=0` — **24th consecutive failure-free baseline**.

---

## §C. Deferred verification

### Launch source (a) SceneManager-driven — DEFERRED to Vertical Slice

Per ADR-0002 line 417 + ADR-0015 §2, the SceneManager owns `_resolve_battle_scene_path` + `packed.instantiate()` + `get_tree().root.add_child(_battle_scene_ref)`. End-to-end test of this path requires a `battle_launch_requested` GameBus signal emission with valid payload — this is owned by Scenario Progression / Battle Preparation epics (sprint-7+; ADR-0017 land target). For sprint-6, smoke evidence records launch source (a) as DEFERRED with cross-reference to the future ScenarioRunner test coverage. This is acceptable per ADR-0016 V-11 + the sprint-6 Definition-of-Done item ("non-crashing battle screen", not "fully playable Beat 1").

### Cross-platform smoke — DEFERRED to Polish per ADR-0016 V-11

Per `.claude/docs/technical-preferences.md`, the project's per-platform render backends are Godot 4.6 defaults: **macOS Metal**, **Linux Vulkan**, **Windows D3D12**. This evidence captures the test-runner platform only (macOS Metal). The 3-platform smoke matrix is deferred to Polish per ADR-0016 V-11 — same precedent as the `scene-manager-android-verification.md` deferral pattern. Reason: CI hardware availability across all three render backends + cost of full-matrix verification on every story close. Polish-phase evidence will re-execute AC-2 + AC-3 on each target platform and record per-platform PASS/FAIL.

---

## §D. Migration Plan revert path

At ADR-0017 Scenario Progression acceptance (sprint-7+), the sprint-6 standalone-launch artifacts revert in a single coordinated patch. The 4 mechanical steps:

1. **`project.godot` line edit** — `run/main_scene` reverts to title-screen / overworld entry (or whatever ADR-0017 specifies). The `; SPRINT-6 ONLY — REVERT WHEN ADR-0017 LANDS (TR-battle-scene-wiring-005)` comment line is also deleted in the same patch. Affected file: `project.godot` lines 12-13.
2. **`src/feature/battle_scene/battle_scene.gd` mock encoder deletion** — delete content between `# === SPRINT-6 MOCK ENCOUNTER ===` / `# === END MOCK ===` markers (~50 LoC) + delete entire `# === SPRINT-6 MOCK ENCOUNTER HELPERS ===` block (`_build_mock_roster_sprint6` + `_make_mock_unit` + `_build_mock_map_resource_sprint6` + `_make_uniform_grass_tiles`). Replace mock-roster `.append()` block with single-line `var battle_config = ScenarioRunner.get_active_battle_config()`.
3. **Lint semantic flip** — `tools/ci/lint_battle_scene_sprint6_mock_marker.sh` (story-003 deliverable) flips from "marker MUST exist" (sprint-6) to "marker MUST NOT exist" (sprint-7+). Same patch as steps 1+2.
4. **Smoke evidence doc re-author** — this file (`battle_scene_smoke_2026-05-04.md`) is superseded by a new evidence doc that captures the ScenarioRunner-driven launch path (launch source (a) above, currently DEFERRED). Old doc archived, not deleted, for traceability.

The mechanical edit footprint is ~50 LoC + 1 project.godot line + 1 lint flip + 1 doc re-author. No semantic rewiring of `BattleScene._ready()` mount sequence required — the 6-step DI-DAG remains identical; only the source of the BattleConfig changes.

---

## §E. Regression baseline

**Pre-flip baseline**: 883/883 PASS / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0 (S6-07 close 2026-05-04, 23rd consecutive).

**Post-flip baseline** (this story 2026-05-04, after IN-14 mock encoder hero-id swap + smoke test `MOCK_HERO_IDS` const update):

```text
Overall Summary: 883 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | exit_code=0
```

**24th consecutive failure-free regression baseline.** `+0 vs S6-07` (this story is launch-config + evidence; no new test functions; no production-source-line additions outside the 4-string-literal IN-14 swap and the test file's matching const update).

---

## §F. Cross-references

- `production/epics/battle-scene/story-001-class-skeleton-and-mount-sequence.md` (Status: Complete 2026-05-04) — the BattleScene root + .tscn skeleton + 6-step mount sequence + sprint-6 mock encoder this story exercises.
- `production/epics/battle-scene/story-003-lints-and-epic-terminal.md` (Status: Ready) — 3 CI lints + `forbidden_patterns` registry update + epic terminal close. Lint 1 (`lint_battle_scene_sprint6_mock_marker.sh`) is the mechanical revert-flip companion to §D step 3.
- `docs/architecture/ADR-0016-battle-scene-wiring.md` §V-8 / §V-9 / §R-8 / §Migration Plan / §IN-14 — the design source these ACs trace to.
- `docs/architecture/tr-registry.yaml` TR-battle-scene-wiring-005 + TR-battle-scene-wiring-008 — the requirement IDs this evidence satisfies.
- `tests/integration/feature/battle_scene/battle_scene_smoke_test.gd` — the headless GdUnit4 regression artifact that proves AC-8 baseline preservation; `MOCK_HERO_IDS` const updated this turn to match the IN-14 production swap.
- `assets/data/heroes/heroes.json` — the production hero roster the mock encoder now references (4 of 9 IDs used: `shu_003_zhang_fei`, `wu_003_zhou_yu`, `wei_001_cao_cao`, `wei_005_xiahou_dun`).
