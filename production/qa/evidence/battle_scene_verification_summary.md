# Battle Scene Epic — Verification Summary

> **Epic**: `production/epics/battle-scene/EPIC.md`
> **Closed**: 2026-05-04 (Sprint 6, post-S6-07; story-002 + story-003 shipped same-day)
> **ADR**: `docs/architecture/ADR-0016-battle-scene-wiring.md` (Accepted 2026-05-03 via `/architecture-review` delta #11)
> **Verifier**: Dowan Kim (orchestrator)
> **Verification precedent**: Same shape as `grid_battle_controller_verification_summary.md` (epic-terminal aggregation pattern, 2nd invocation)

---

## §A. Stories shipped

| # | Story | Type | Status | TR-IDs | Test Evidence |
|---|-------|------|--------|--------|---------------|
| 001 | BattleScene class skeleton + 3-node `.tscn` + 6-step `_ready()` mount sequence + sprint-6 mock encoder | Integration | Complete (2026-05-04) | TR-001/002/003/004/006/007/009 | `tests/integration/feature/battle_scene/battle_scene_smoke_test.gd` (260 LoC, 7 functions, all PASS) |
| 002 | `project.godot` `main_scene` flip + cross-launch-source smoke evidence | Integration | Complete (2026-05-04) | TR-005/008 | `production/qa/evidence/battle_scene_smoke_2026-05-04.md` (162 lines; §A 18-cell matrix complete) |
| 003 | 3 lint scripts + CI wiring + 3 forbidden_patterns + epic terminal | Config/Data | Complete (2026-05-04) | TR-010/011 | This doc (§C lint pass output) |

---

## §B. TR coverage matrix (11/11)

| TR-ID | Requirement (summary) | Story | Status |
|-------|----------------------|-------|--------|
| TR-battle-scene-wiring-001 | NEW pattern: scene-root-as-orchestrator (`class_name BattleScene extends Node2D`) | 001 | ✅ |
| TR-battle-scene-wiring-002 | 3-node `.tscn` skeleton (BattleScene + GridLayer + HUDLayer) | 001 + 003 (lint) | ✅ |
| TR-battle-scene-wiring-003 | 6-step `_ready()` mount sequence in DI dependency order | 001 | ✅ |
| TR-battle-scene-wiring-004 | Sprint-6 inline mock encoder between explicit markers | 001 + 003 (lint) | ✅ |
| TR-battle-scene-wiring-005 | `project.godot` `main_scene` flip with revert comment | 002 | ✅ |
| TR-battle-scene-wiring-006 | NO `_exit_tree()` body (auto-tree-free + per-child `_exit_tree`) | 001 | ✅ |
| TR-battle-scene-wiring-007 | Non-emitter + non-subscriber discipline on root | 001 + 003 (lint) | ✅ |
| TR-battle-scene-wiring-008 | Idempotent `_ready()` under 3 launch sources (no branching) | 002 | ✅ (b/c PASS; a DEFERRED to Vertical Slice per V-11 option (ii)) |
| TR-battle-scene-wiring-009 | <50ms `_ready()` wall-clock perf gate | 001 | ✅ (×5 permissive headless gate at 250ms; reference-hardware <50ms target) |
| TR-battle-scene-wiring-010 | 3 forbidden_patterns registered + ADR-trace | 003 | ✅ (registered same-patch with delta #11; verified at AC-5) |
| TR-battle-scene-wiring-011 | 3 lint scripts + CI wiring + smoke evidence + epic terminal | 003 | ✅ |

**11/11 TR coverage achieved.** Untraced requirements: 0.

---

## §C. Lint pass output (AC-1/AC-2/AC-3/AC-6 verification)

All 3 lint scripts run locally on shipped post-story-001 + post-story-002 source state. Each script returned exit code 0.

### Lint 1 — `lint_battle_scene_pre_instanced_children.sh` (TR-002 + R-2)

```
$ bash tools/ci/lint_battle_scene_pre_instanced_children.sh
PASS: scenes/battle/battle_scene.tscn has exactly 3 nodes (battle_scene_pre_instanced_children compliant)
exit=0
```

Asserts the `.tscn` file contains EXACTLY 3 `[node name=` declarations: `BattleScene` (root Node2D) + `GridLayer` (Node2D child) + `HUDLayer` (CanvasLayer child at `layer=1`). A 4th node (or higher) means a child was pre-instanced via the Godot editor — silently violating the setup-before-`add_child()` mandate from 5 prior ADRs.

### Lint 2 — `lint_battle_scene_no_gamebus_subscriptions.sh` (TR-007 + R-7)

```
$ bash tools/ci/lint_battle_scene_no_gamebus_subscriptions.sh
PASS: BattleScene has zero GameBus.<X>.connect/emit (battle_scene_root_signal_subscription compliant)
exit=0
```

Asserts `src/feature/battle_scene/battle_scene.gd` has zero `GameBus.<X>.connect` AND zero `GameBus.<X>.emit` matches. BattleScene root is non-emitter AND non-subscriber by design — cross-system signal flow goes through the 6 mounted children, not through the scene-root orchestrator. Same precedent as ADR-0015 BattleHUD non-emitter discipline.

### Lint 3 — `lint_battle_scene_sprint6_mock_marker.sh` (TR-004 + TR-010)

```
$ bash tools/ci/lint_battle_scene_sprint6_mock_marker.sh
PASS: src/feature/battle_scene/battle_scene.gd contains all 4 SPRINT-6 mock markers (will flip semantic at ADR-0017 acceptance)
exit=0
```

Asserts all 4 marker substrings are present:
- `# === SPRINT-6 MOCK ENCOUNTER ===`
- `# === END MOCK ===`
- `# === SPRINT-6 MOCK ENCOUNTER HELPERS ===`
- `# === END SPRINT-6 MOCK ENCOUNTER HELPERS ===`

These markers bracket the inline mock encounter loader region in `_ready()` and the 4 mock helper methods (`_build_mock_roster_sprint6`, `_make_mock_unit`, `_build_mock_map_resource_sprint6`, `_make_uniform_grass_tiles`). Sprint-7+ semantic flip per Migration Plan §1: same patch as ADR-0017 acceptance flips this lint to "MUST NOT exist" semantic.

### CI wiring (AC-4 verification)

`.github/workflows/tests.yml` — 3 lint steps wired in order after the existing GridBattleController + Camera + DamageCalc + HP_status + Foundation lint groups, before the `Run GdUnit4 tests` step:

```yaml
- name: 'Battle Scene lints — pre-instanced children (ADR-0016 §2 R-2 / battle_scene_pre_instanced_children)'
  run: bash tools/ci/lint_battle_scene_pre_instanced_children.sh
- name: 'Battle Scene lints — no GameBus subscriptions (ADR-0016 R-7 / battle_scene_root_signal_subscription)'
  run: bash tools/ci/lint_battle_scene_no_gamebus_subscriptions.sh
- name: 'Battle Scene lints — sprint-6 mock marker presence (ADR-0016 §4 / battle_scene_sprint6_mock_marker_must_exist; SEMANTIC FLIPS AT ADR-0017)'
  run: bash tools/ci/lint_battle_scene_sprint6_mock_marker.sh
```

### Registry verification (AC-5)

3 forbidden_patterns confirmed present in `docs/registry/architecture.yaml` (registered same-patch with ADR-0016 acceptance via `/architecture-review` delta #11; lines 1689 / 1697 / 1705):

```
$ grep -nE '^\s+- pattern: battle_scene_(pre_instanced_children|root_signal_subscription|sprint6_mock_marker_must_exist)' docs/registry/architecture.yaml
1689:  - pattern: battle_scene_pre_instanced_children
1697:  - pattern: battle_scene_root_signal_subscription
1705:  - pattern: battle_scene_sprint6_mock_marker_must_exist
```

3/3 forbidden_patterns match the 3 lint scripts 1:1 per the per-`tools/ci/lint_*.sh` convention.

---

## §D. Regression baseline (AC-9)

**Pre-epic-close baseline**: 883/883 PASS / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0 (story-002 close, 24th consecutive failure-free baseline).

**Post-epic-close baseline (this story 2026-05-04)**:

```
Overall Summary: 883 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | exit_code=0
```

**25th consecutive failure-free regression baseline.** +0 vs story-002 (this story added zero new test functions or production code paths — purely tooling + CI + docs).

**Lint runtime cost**: 3 scripts × <100ms each = <300ms additional CI cost (within the cumulative <5s CI lint pipeline budget). Same precedent as grid-battle-controller's 4 lints + camera's 5 lints — well within performance guardrail.

---

## §E. Migration Plan revert (sprint-7+ when ADR-0017 lands)

At ADR-0017 Scenario Progression acceptance, the sprint-6 standalone-launch artifacts revert in a single coordinated patch. The 4 mechanical steps (per `production/qa/evidence/battle_scene_smoke_2026-05-04.md` §D + ADR-0016 §Migration Plan §1):

1. **`project.godot` line edit** — `run/main_scene` reverts to title-screen / overworld entry per ADR-0017. The `; SPRINT-6 ONLY — REVERT WHEN ADR-0017 LANDS (TR-battle-scene-wiring-005)` comment line is also deleted in the same patch. Affected file: `project.godot:12-13`.
2. **`src/feature/battle_scene/battle_scene.gd` mock encoder deletion** — delete content between `# === SPRINT-6 MOCK ENCOUNTER ===` / `# === END MOCK ===` markers (~50 LoC) + delete entire `# === SPRINT-6 MOCK ENCOUNTER HELPERS ===` block (`_build_mock_roster_sprint6` + `_make_mock_unit` + `_build_mock_map_resource_sprint6` + `_make_uniform_grass_tiles`). Replace mock-roster `.append()` block with single-line `var battle_config = ScenarioRunner.get_active_battle_config()`.
3. **Lint semantic flip** — `tools/ci/lint_battle_scene_sprint6_mock_marker.sh` flips from "marker MUST exist" (sprint-6) to "marker MUST NOT exist" (sprint-7+). Same patch as steps 1+2. Mechanical edit: change the loop body to FAIL when any marker is FOUND, update the inline header comment, update the PASS/FAIL output strings.
4. **Smoke evidence doc re-author** — `battle_scene_smoke_2026-05-04.md` is superseded by a new evidence doc capturing the ScenarioRunner-driven launch path (launch source (a), currently DEFERRED). Old doc archived for traceability, not deleted. This `battle_scene_verification_summary.md` is **NOT** re-authored — it is the epic-terminal record and remains pinned to the sprint-6 closure state.

The mechanical edit footprint is ~50 LoC + 1 project.godot line + 1 lint flip + 1 doc re-author. No semantic rewiring of `BattleScene._ready()` mount sequence required — the 6-step DI-DAG remains identical; only the source of the BattleConfig changes.

**ADR-0016 IN-N implementation drift trail** (preserved for sprint-7+ rebase context): IN-1..IN-5 from authoring-time review (godot-specialist 2026-05-03); IN-6..IN-13 from S6-07 implementation (production-signature drifts; resolved via "production-signature wins" precedent); IN-14 from this epic's story-002 (mock encoder hero-id swap from fictional ids to real `heroes.json` ids — fully resolves at ADR-0017 acceptance when mock encoder deletes entirely).

---

## §F. Epic close-out signals

- **+1 playable-surface delta target HIT** — first runnable BattleScene shipped at story-001 close (S6-07 2026-05-04). Story-002 documents the cross-launch-source matrix evidentially; story-003 hardens via lint enforcement.
- **6th invocation of battle-scoped Node lineage** completed; **NEW pattern: scene-root-as-orchestrator** stable at 1 invocation. Future scene-root orchestrators (`OverworldScene`, `MainMenuScene`, `BattlePrepScene`) follow the same code-driven `_ready()` mount sequence + DI-DAG-ordered child instantiation + reliance on auto-tree-free for teardown.
- **Battle-scene epic at 3/3 stories shipped (100%)**.
- **Sprint-6 progress (post-epic-close)**: 9/12 sprint-status.yaml entries marked done + this epic's 3 stories closed (story-001 = S6-07 yaml entry; story-002 + story-003 are epic sub-stories, not enumerated as sprint-level S6-NN). Battle-hud epic at 3/8 stories shipped. ADR-0017 Scenario Progression (S6-10, should-have, UNBLOCKED) is the natural next architecture work for sprint-6 close OR sprint-7 critical path.
- **Tech-debt candidates carried forward** (NOT logged formally this epic):
  - **Production-launch path coverage gap** (qa-tester suggestion at story-002): smoke test must cover production `_load_heroes()` path, not only DI-injected path. Add `test_mock_hero_ids_exist_in_production_roster` reading `assets/data/heroes/heroes.json` via real load path. Catches future IN-14-class drift automatically.
  - **GameBus diagnostics soft-cap warning**: `WARNING: soft cap exceeded: 271 emits` from TurnOrderRunner.initialize_battle first-frame burst. Pre-existing diagnostics behavior; not a mount-error. Worth tracking as potential operational concern (test-runner log noise; possible legitimate batching opportunity in TurnOrderRunner).

Both candidates are non-blocking; suitable for incorporation into a future TD entry OR sprint-7+ story.

---

## §G. Cross-references

- `production/epics/battle-scene/EPIC.md` — epic Status flipped to Complete this turn
- `production/epics/battle-scene/story-001-class-skeleton-and-mount-sequence.md` — Status: Complete (2026-05-04)
- `production/epics/battle-scene/story-002-standalone-launch-and-smoke-evidence.md` — Status: Complete (2026-05-04)
- `production/epics/battle-scene/story-003-lints-and-epic-terminal.md` — Status: Complete (this turn)
- `production/qa/evidence/battle_scene_smoke_2026-05-04.md` — story-002 cross-launch-source smoke evidence (162 lines, §A 18-cell matrix)
- `tests/integration/feature/battle_scene/battle_scene_smoke_test.gd` — story-001 integration smoke test (260 LoC, 7 functions)
- `docs/architecture/ADR-0016-battle-scene-wiring.md` — governing ADR (Accepted 2026-05-03; 14 IN-N entries documenting full implementation drift trail)
- `docs/registry/architecture.yaml` lines 1689 / 1697 / 1705 — 3 forbidden_patterns
- `tools/ci/lint_battle_scene_pre_instanced_children.sh` + `lint_battle_scene_no_gamebus_subscriptions.sh` + `lint_battle_scene_sprint6_mock_marker.sh` — 3 lint scripts (this story)
- `.github/workflows/tests.yml` — CI wiring (this story)
- Sibling epic-terminal precedent: `production/qa/evidence/grid_battle_controller_verification_summary.md`
