# Story 002: `project.godot` `main_scene` Flip + Cross-Launch-Source Smoke Evidence

> **Epic**: Battle Scene
> **Status**: Ready
> **Layer**: Feature (scene-root)
> **Type**: Integration
> **Manifest Version**: 2026-04-20
> **Sprint**: sprint-6 (post-S6-07; capacity permitting) OR sprint-7

## Context

**GDD**: None — architecture-only epic
**Requirement**: `TR-battle-scene-wiring-005`, `TR-battle-scene-wiring-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0016 Battle Scene Wiring (Accepted 2026-05-03)
**ADR Decision Summary**: Sprint-6 sets `[application] run/main_scene = "res://scenes/battle/battle_scene.tscn"` in `project.godot` for standalone launch (enables `godot --path .` to produce playable battle screen — +1 playable-surface delta target). `BattleScene._ready()` is **idempotent under all 3 launch sources**: (a) SceneManager-driven, (b) `main_scene` config, (c) `--main-scene` CLI override. NO launch-source branching in code. Smoke matrix at evidence doc covers 3 launch sources × 6 mount steps = 18 verification points.

**Engine**: Godot 4.6 | **Risk**: LOW (zero new post-cutoff API surface)
**Engine Notes**:
- Uses only stable Godot APIs: `[application] run/main_scene` project.godot key (4.0), `--main-scene` CLI override (4.0), `--path .` working directory flag (4.0).
- Per-platform render backend (Godot 4.6 defaults — Windows D3D12, Linux Vulkan, macOS Metal) is orthogonal to launch source; smoke evidence may capture per-platform where available but is NOT a BLOCKING gate at this story (deferred to Polish per ADR-0016 V-11).
- Sprint-6 main_scene flip is REVERTED in same patch as ADR-0017 acceptance (sprint-7+); the comment marker `# SPRINT-6 ONLY — REVERT WHEN ADR-0017 LANDS` makes the revert site mechanical.

**Control Manifest Rules (Feature layer + scene-root)**:
- Required: smoke evidence doc per `tests/qa/evidence/` template; covers all 3 launch sources × 6 mount steps × pass/fail = 18 verification rows.
- Forbidden (already enforced by story-001 + story-003): no launch-source branching in `BattleScene` source (confirmed by absence of `OS.has_feature("editor")` / `Engine.is_editor_hint()` / similar guards around mount sequence).
- Guardrail: standalone-launch wall-clock <2000ms (within ADR-0002's BattleScene load budget; orchestration <50ms + child mounts dominate the rest).

---

## Acceptance Criteria

*From ADR-0016 §5, §Decision §R-8 + V-8/V-9 + R-1 + R-5 + Migration Plan, scoped to launch sources + evidence:*

- [ ] **AC-1**: `project.godot` `[application] run/main_scene` is set to `"res://scenes/battle/battle_scene.tscn"` with adjacent comment `# SPRINT-6 ONLY — REVERT WHEN ADR-0017 LANDS` (or equivalent — comment must be human-greppable for the eventual revert audit). (TR-005)
- [ ] **AC-2**: `godot --path . --headless` (no `--main-scene` flag, no `--quit`) launches `BattleScene` directly and `_ready()` completes without error (verifiable via `--quit-after 60` followed by `echo $?`). (TR-005 + TR-008 launch source (b))
- [ ] **AC-3**: `godot --path . --headless --main-scene scenes/battle/battle_scene.tscn` launches `BattleScene` identically to AC-2 (CLI override path produces same result). (TR-008 launch source (c))
- [ ] **AC-4**: SceneManager-driven path (launch source (a)) is verified via existing scene-manager epic test infrastructure OR documented as deferred-to-S6-07-via-ADR-0002-test-coverage in the smoke evidence doc. (Note: SceneManager → BattleScene transition was authored in ADR-0002 sprint 1 but is NOT yet exercised end-to-end in CI; this AC may resolve as "deferred to Vertical Slice when ScenarioRunner provides battle_launch_requested payload" — non-blocking for sprint-6 close.) (TR-008 launch source (a))
- [ ] **AC-5**: Smoke evidence doc at `production/qa/evidence/battle_scene_smoke_2026-05-XX.md` (date suffix matches `/story-done` close date) covers the 18-row verification matrix: 3 launch sources (a/b/c) × 6 mount steps (MapGrid + BattleCamera + HPStatusController + TurnOrderRunner + GridBattleController + BattleHUD). Each cell records PASS / FAIL / DEFERRED with 1-line evidence reference. (TR-008 + TR-011 evidence-doc-shape)
- [ ] **AC-6**: Smoke evidence doc explicitly notes the cross-platform test deferral per ADR-0016 V-11 (macOS Metal + Linux Vulkan + Windows D3D12 verification on real hardware deferred to Polish; CI runs only the test-runner platform). (TR-008 + V-11 traceability)
- [ ] **AC-7**: Smoke evidence doc explicitly notes the §Migration Plan revert path (1-line `project.godot` edit + ~50 LoC mock encoder deletion at ADR-0017 acceptance). (TR-005 traceability)
- [ ] **AC-8**: Existing test runner regression baseline preserved (876+ PASS / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0). The main_scene flip MUST NOT introduce CI regression (hint: any tests that load other scenes by `preload()` are unaffected; only the bare `godot --headless` invocation reaches BattleScene first). (TR-009 implicit — perf neutral)

---

## Implementation Notes

*Derived from ADR-0016 §5 + Migration Plan + V-8/V-9:*

1. **`project.godot` edit**: locate the `[application]` section in `project.godot`. Set `run/main_scene` per AC-1. Place the SPRINT-6 comment on the line immediately above OR adjacent (Godot's project.godot tolerates both placements). Sample:
   ```ini
   [application]
   config/name="천명역전 (Defying Destiny)"
   run/main_scene="res://scenes/battle/battle_scene.tscn"  ; SPRINT-6 ONLY — REVERT WHEN ADR-0017 LANDS
   ```
   Note: Godot's project.godot uses `;` for line comments inline — verify the syntax doesn't break by running `godot --headless --quit-after 1` post-edit.

2. **CI lane verification**: the project's existing `.github/workflows/tests.yml` runs the full test suite via `godot --headless --script tests/gdunit4_runner.gd`. The runner script invokes the test framework and exits without consulting `main_scene` (test framework owns its own scene lifecycle). So the flip should NOT affect the existing CI lane. Verify by running the suite locally post-flip: 876+ PASS preserved.

3. **Smoke evidence doc shape** (~80-150 lines markdown):
   ```markdown
   # Battle Scene Smoke Evidence — 2026-05-XX

   > **Story**: production/epics/battle-scene/story-002-standalone-launch-and-smoke-evidence.md
   > **ADR**: docs/architecture/ADR-0016-battle-scene-wiring.md (V-8/V-9)
   > **Verifier**: [name]
   > **Date**: 2026-05-XX

   ## §A. Launch source × mount step matrix

   | Mount step \ Launch source | (a) SceneManager-driven | (b) main_scene config | (c) --main-scene CLI |
   |----------------------------|-------------------------|----------------------|----------------------|
   | 1. MapGrid                 | DEFERRED (see §C)       | PASS                 | PASS                 |
   | 2. BattleCamera            | DEFERRED                | PASS                 | PASS                 |
   | 3. HPStatusController      | DEFERRED                | PASS                 | PASS                 |
   | 4. TurnOrderRunner         | DEFERRED                | PASS                 | PASS                 |
   | 5. GridBattleController    | DEFERRED                | PASS                 | PASS                 |
   | 6. BattleHUD               | DEFERRED                | PASS                 | PASS                 |

   ## §B. Verification commands

   ### Launch source (b): main_scene config
   ```bash
   godot --path . --headless --quit-after 3
   echo "exit=$?"  # expect 0
   ```

   ### Launch source (c): --main-scene CLI override
   ```bash
   godot --path . --headless --main-scene scenes/battle/battle_scene.tscn --quit-after 3
   echo "exit=$?"  # expect 0
   ```

   ## §C. Deferred verification

   - Launch source (a) SceneManager-driven: deferred to Vertical Slice when ScenarioRunner emits `battle_launch_requested` payload (ADR-0017 land target).
   - Cross-platform smoke (macOS Metal + Linux Vulkan + Windows D3D12): deferred to Polish per ADR-0016 V-11; CI test-runner platform only this story.

   ## §D. Migration Plan revert path

   At ADR-0017 acceptance (sprint-7+):
   1. `project.godot` line edit: `run/main_scene` reverts to title screen / overworld entry per ADR-0017.
   2. `src/feature/battle_scene/battle_scene.gd` — delete the SPRINT-6 mock encoder block + helpers (~50 LoC).
   3. Lint `lint_battle_scene_sprint6_mock_marker.sh` semantic flips from "marker MUST exist" to "marker MUST NOT exist".
   4. Smoke evidence doc re-author for the new launch path.

   ## §E. Regression baseline

   - 876+ PASS / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0 — preserved post-flip.
   ```

4. **AC-4 SceneManager-driven path resolution**: per ADR-0002 line 417 + ADR-0015 §2, the SceneManager owns `_resolve_battle_scene_path` + `packed.instantiate()` + `get_tree().root.add_child(_battle_scene_ref)`. End-to-end test of this path requires a `battle_launch_requested` GameBus signal emission — owned by Scenario Progression / Battle Preparation epics (sprint-7+). For sprint-6, the smoke evidence doc records launch source (a) as DEFERRED with cross-reference to the future ScenarioRunner test coverage. This is acceptable per ADR-0016 V-11 + the sprint-6 Definition-of-Done item ("non-crashing battle screen", not "fully playable Beat 1").

5. **Test runner exit-code interpretation**: Godot's `--quit-after N` returns 0 on clean exit, non-zero on `assert()` failure or crash. The 3-second window is sufficient for `_ready()` mount + 1-2 process frames; longer windows risk capturing legitimate game-loop behavior. Use `60` only if testing post-_ready() steady-state; otherwise `3` is plenty.

6. **No source code changes to `battle_scene.gd`**: this story is launch-config + evidence only. If a launch-source-specific bug surfaces during smoke (e.g., `_ready()` order-of-operations difference between SceneManager-driven and main_scene paths), the fix belongs to story-001 as an amendment — surface the finding to ADR-0016 §Implementation Notes IN-N pattern and split into a follow-up.

7. **Evidence doc filename**: `battle_scene_smoke_2026-05-XX.md` where `XX` is the actual completion day. Same precedent as `grid_battle_controller_verification_summary.md` (epic-terminal evidence) — but note this is a per-story evidence, not an epic-terminal. The epic-terminal evidence doc may aggregate this story-002 doc + story-003 lint evidence at /story-done time.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: BattleScene class skeleton + `.tscn` + 6-step mount + mock encoder (must be Complete before this story can run).
- **Story 003**: 3 lint scripts + CI wiring + 3 forbidden_patterns in registry + epic close.
- **Cross-platform smoke verification on real hardware** — V-8/V-9 on macOS Metal + Linux Vulkan + Windows D3D12 deferred to Polish per ADR-0016 V-11.
- **SceneManager-driven path end-to-end test** — deferred to Vertical Slice when ScenarioRunner provides `battle_launch_requested` payload.
- **Real chapter loader / Scenario state** — owned by ADR-0017 Scenario Progression (sprint-7+).
- **`project.godot` revert at ADR-0017 acceptance** — documented in evidence doc §D Migration Plan; mechanical 1-line edit at that future patch, not this story.

---

## QA Test Cases

*Integration story — automated launch verification + manual evidence doc gate.*

- **AC-1: `project.godot` main_scene flip + comment**
  - Given: project.godot file post-edit
  - When: `grep -E '^run/main_scene' project.godot` runs
  - Then: returns the line `run/main_scene="res://scenes/battle/battle_scene.tscn"` (with optional inline comment); also `grep -i 'sprint-6' project.godot` returns at least 1 line near the `run/main_scene` setting
  - Edge cases: comment placement (above vs adjacent inline) — both acceptable; only the substring presence matters for the lint

- **AC-2: Launch source (b) — main_scene config**
  - Given: clean working tree post-flip
  - When: `godot --path . --headless --quit-after 3` runs
  - Then: exit code 0; no `assert` failure in output; no `ERROR:` lines pointing to BattleScene mount sequence
  - Edge cases: pre-existing `WARNING:` lines (e.g., from autoload boot) acceptable; only `ERROR:` and `assert` failures fail this AC

- **AC-3: Launch source (c) — `--main-scene` CLI override**
  - Given: clean working tree
  - When: `godot --path . --headless --main-scene scenes/battle/battle_scene.tscn --quit-after 3` runs
  - Then: exit code 0; behavior identical to AC-2 (no launch-source branching in code)
  - Edge cases: if AC-2 passes but AC-3 fails (or vice versa), source has launch-source branching → fix belongs in story-001 amendment

- **AC-4: Launch source (a) — SceneManager-driven**
  - Setup: scene-manager epic test infrastructure (or document deferral)
  - Verify: either (i) existing test exercises `SceneManager.transition_to_battle()` end-to-end and `BattleScene` mounts identically to (b)/(c); OR (ii) smoke evidence doc §C documents the deferral with cross-reference to ScenarioRunner / `battle_launch_requested` payload epic ownership
  - Pass condition: option (i) test PASS OR option (ii) doc note present; both are acceptable per ADR-0016 V-11 (sprint-6 +1-playable-surface-delta scope, not full integration)

- **AC-5: Smoke evidence doc 18-row matrix**
  - Setup: open `production/qa/evidence/battle_scene_smoke_2026-05-XX.md`
  - Verify: §A contains the 6-row × 3-column = 18-cell matrix; each cell has PASS / FAIL / DEFERRED with brief evidence reference; verification commands in §B; deferred items in §C; revert path in §D; regression baseline in §E
  - Pass condition: all 5 sections present; no empty cells in §A matrix

- **AC-6: Cross-platform deferral note**
  - Setup: open evidence doc §C
  - Verify: explicit text "deferred to Polish per ADR-0016 V-11" + 3 platforms named (macOS Metal + Linux Vulkan + Windows D3D12)
  - Pass condition: substring match for "V-11" + 3 platform names

- **AC-7: Migration Plan revert path note**
  - Setup: open evidence doc §D
  - Verify: 4 numbered steps (project.godot revert + mock deletion + lint flip + doc re-author); each names a concrete file or line target
  - Pass condition: 4 numbered items present + each names at least one file path

- **AC-8: Regression baseline preserved**
  - Given: post-flip working tree
  - When: full test suite runs via project's CI invocation (`godot --headless --script tests/gdunit4_runner.gd` or equivalent)
  - Then: 876+ PASS / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0
  - Edge cases: any test that depends on `main_scene` config implicitly (none expected) → fail belongs in test-fix scope, not story-002

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `production/qa/evidence/battle_scene_smoke_2026-05-XX.md` — must exist and cover all 5 sections per AC-5..AC-7
- Manual gate AC-1..AC-4 + AC-8 verified at code-review time (commands run in evidence doc §B); story-003 may add automated CI lint for AC-1 marker presence

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (BattleScene class skeleton + `.tscn` + 6-step mount + mock encoder must be Complete; without a working BattleScene mount path, the launch-source verification has nothing to test)
- **Unlocks**: Story 003 (lints + epic terminal — needs BOTH the working scene from story-001 AND the launch-config from this story to be in place before lints can be authored against the final source shape)

---

## Completion Notes

*To be authored at /story-done.*
