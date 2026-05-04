# Epic: Battle Scene (battle-scene-wiring)

> **Layer**: Feature (scene-root) — **NEW pattern: scene-root-as-orchestrator** (distinct from 5-precedent battle-scoped Node `setup()` pattern)
> **GDD**: None — architectural-only epic (ADR-0016 is source-of-truth; same precedent as `camera/` epic where the system is small enough that the ADR carries the contract without a dedicated GDD)
> **Architecture Module**: `BattleScene` — `class_name BattleScene extends Node2D`, mounted as root of `scenes/battle/battle_scene.tscn`; orchestrates 6 children (MapGrid + BattleCamera + HPStatusController + TurnOrderRunner + GridBattleController + BattleHUD) via 6-step DI-DAG-ordered `_ready()` mount sequence
> **Status**: **Complete** (epic closed 2026-05-04; all 3 stories shipped; 11/11 TR coverage; +1 playable-surface delta target HIT)
> **Stories**: 3 stories created 2026-05-04 (Sprint 6 S6-03) — see Stories table below
> **Created**: 2026-05-04 (Sprint 6 S6-03)
> **Closed**: 2026-05-04 (Sprint 6, post-S6-07; story-002 + story-003 shipped same-day)
> **Manifest Version**: 2026-04-20 (`docs/architecture/control-manifest.md`)

## Overview

The Battle Scene epic implements `BattleScene` — the **scene root that mounts all 5 battle-scoped systems plus battle-scoped MapGrid** in DI dependency order, producing the **+1 playable-surface delta target** for sprint-6 (the first user-visible runnable battle screen). The epic ships a 3-node `.tscn` skeleton (`BattleScene` Node2D + `GridLayer` Node2D + `HUDLayer` CanvasLayer at `layer=1`), a code-driven 6-step `_ready()` mount sequence honoring the setup-before-`add_child()` mandate from 5 prior ADRs, a sprint-6-only inline mock encoder (4-unit roster on a 6×6 all-grass map), a sprint-6-only `project.godot` `main_scene` flip, 3 lint scripts enforcing the new pattern's invariants, and an integration smoke test asserting all 6 children mount + 0 errors / 0 orphans.

This is the **6th invocation of the battle-scoped Node lineage but a NEW pattern** — *scene-root-as-orchestrator* — because `BattleScene` IS the scene root, not a child of one. Pattern stable at 1 invocation; future scene-root orchestrators (`OverworldScene`, `MainMenuScene`, `BattlePrepScene`) follow the same code-driven `_ready()` mount sequence + DI-DAG-ordered child instantiation + reliance on auto-tree-free for teardown. Closes registry line 825 placeholder reference and unblocks ADR-0017 Scenario Progression (which will replace the sprint-6 mock in the same patch as its acceptance).

## Pattern Boundary Precedent

**6th invocation of the battle-scoped Node lineage** but a **distinct new pattern**: scene-root-as-orchestrator. Lifecycle is owned by ADR-0002 SceneManager (parent ↔ child relationship: SceneManager creates and frees `BattleScene`; `BattleScene` creates and frees its 6 child systems via auto-tree-free). Pattern boundary versus the 5 prior invocations:

| Invocation | System | Layer | ADR | Pattern Form |
|---|---|---|---|---|
| #1 | HPStatusController | Core | ADR-0010 | battle-scoped child `Node` + `setup()` BEFORE `add_child()` |
| #2 | TurnOrderRunner | Core | ADR-0011 | battle-scoped child `Node` + `initialize_battle()` BEFORE `add_child()` |
| #3 | BattleCamera | Feature | ADR-0013 | battle-scoped child `Node` (`Camera2D`) + `setup(map_grid)` BEFORE `add_child()` |
| #4 | GridBattleController | Feature | ADR-0014 | battle-scoped child `Node` + 8-param `setup()` BEFORE `add_child()` |
| #5 | BattleHUD | Presentation | ADR-0015 | battle-scoped child `Control` + 9-param `setup()` BEFORE `HUDLayer.add_child()` |
| **#6** | **BattleScene** | **Feature (scene-root)** | **ADR-0016** | **scene-root `Node2D`; orchestrates the 5 above + MapGrid via code-driven `_ready()` mount sequence; NO `setup()` (loaded by SceneManager OR `main_scene` config — neither passes constructor params)** |

Future scene-root orchestrators reuse this pattern. The 5-precedent setup() form is for systems mounted AS a child; the scene-root form is for systems that ARE the scene.

## MVP Scope (per ADR-0016 §0 — explicit deferral structure)

This epic implements the MVP subset for the sprint-6 +1 playable-surface delta:

- ✅ **3-node `.tscn` skeleton** (`BattleScene` + `GridLayer` + `HUDLayer` only; no pre-instanced children — all 6 system Nodes code-driven in `_ready()`)
- ✅ **6-step DI-DAG-ordered `_ready()` mount sequence** (MapGrid → BattleCamera → HPStatusController → TurnOrderRunner → GridBattleController → BattleHUD)
- ✅ **Sprint-6 inline mock encoder** between `# === SPRINT-6 MOCK ENCOUNTER ===` markers (4-unit roster: 장비 tank + 조운 assassin + 2 enemies on 6×6 all-grass map; mechanical sprint-7+ deletion when ADR-0017 lands)
- ✅ **`project.godot` `main_scene` flip** to `res://scenes/battle/battle_scene.tscn` for sprint-6 standalone launch (`godot --path .` produces playable battle screen); reverts in same patch as ADR-0017 acceptance
- ✅ **Non-emitter + non-subscriber discipline** on `BattleScene` root (zero GameBus subscriptions; zero `_exit_tree()` body — auto-tree-free + each child's R-N `_exit_tree()` mandate handles teardown)
- ✅ **3 lint scripts** enforcing the new pattern's invariants (pre-instanced children + GameBus subscriptions + sprint-6 mock marker presence)
- ✅ **Integration smoke test** asserting 6 children mount + 0 errors / 0 orphans
- ✅ **Smoke evidence doc** covering 3 launch sources × 6 mount steps = 18 verification points

**Explicit deferrals** (each future ADR / sprint slot reserved):

- ❌ **Real chapter loader / Scenario state** — owned by ADR-0017 Scenario Progression (sprint-6 should-have S6-10 / sprint-7+ critical). When ADR-0017 lands, the inline mock encoder is **DELETED** in the same patch and replaced with `var battle_config = ScenarioRunner.get_active_battle_config()`.
- ❌ **`MapGrid` `setup()` symmetry** — ADR-0004 predates the setup-before-`add_child()` pattern; current shipped MapGrid loads from `MapResource` `.tres` via `@export` deserialization. ADR-0016 ratifies the existing pattern; if a future ADR-0004 amendment adds a `setup(map_resource)` signature, ADR-0016 §3 init order is **additively amended** — no breaking change.
- ❌ **Title screen / overworld entry as `main_scene`** — sprint-7+ revert when ADR-0017 lands and ScenarioRunner / title-screen flow exists.
- ❌ **`BattleScene._exit_tree()` body** — explicitly forbidden (R-6 + TR-007). Auto-tree-free + each child's own `_exit_tree()` is sufficient. The non-emitter + non-subscriber discipline mirrors ADR-0015 BattleHUD precedent.
- ❌ **Cross-platform smoke verification on real hardware** — V-8 (`godot --path .` standalone) on macOS Metal + Linux Vulkan + Windows D3D12 may be deferred to Polish if CI/dev-box matrix is not yet stood up; documented in V-11 verification item but not BLOCKING for sprint-6 close.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| **ADR-0016 Battle Scene Wiring** (Accepted 2026-05-03) | NEW pattern: scene-root-as-orchestrator. 3-node `.tscn` skeleton + code-driven 6-step `_ready()` mount sequence + sprint-6 inline mock encoder + sprint-6 `main_scene` flip + 3 lint scripts. NO `_exit_tree()` body; non-emitter + non-subscriber discipline. Pattern reusable for future scene roots. | **LOW** (zero new post-cutoff API surface) |
| ADR-0001 GameBus (depends-on) | Autoload boots BEFORE `BattleScene` mount; `BattleScene` root has zero GameBus subscriptions; child systems subscribe at their own `_ready()` per their respective ADRs | LOW |
| ADR-0002 SceneManager (depends-on) | SceneManager owns Overworld ↔ BattleScene transition lifecycle (`_resolve_battle_scene_path` + `packed.instantiate()` + deferred-free pattern); ADR-0016 ratifies in-scene topology only, NOT inter-scene transitions; orthogonal scopes | LOW (HIGH-risk recursive Control disable owned by ADR-0002 retained-overworld surface, not re-asserted at BattleScene level) |
| ADR-0004 MapGrid (depends-on) | Battle-scoped `MapGrid` Node mounted as first child; loaded from `MapResource` `.tres`; ADR-0016 ratifies the mount-order position (first; before BattleCamera which DI-depends on it) | LOW |
| ADR-0005 InputRouter (depends-on) | Autoload Node already booted; DI'd to BattleHUD at step 6 of init; ADR-0016 does NOT instantiate InputRouter | HIGH (governing ADR-0005); inherited LOW for BattleScene consumer surface |
| ADR-0010 HPStatusController (depends-on) | Battle-scoped Node mounted at step 3 via `HPStatusController.new()` + per-unit `initialize_unit(unit_id, hero, unit_class)` loop + `add_child()` | LOW |
| ADR-0011 TurnOrderRunner (depends-on) | Battle-scoped Node mounted at step 4 via `TurnOrderRunner.new()` + `initialize_battle(unit_roster)` (one-shot; subscribes to GameBus.unit_died inside) + `add_child()` | LOW |
| ADR-0013 BattleCamera (depends-on) | Battle-scoped Node mounted at step 2 via `BattleCamera.new()` + `setup(map_grid)` 1-param + `add_child()` | LOW |
| ADR-0014 GridBattleController (depends-on) | Battle-scoped Node mounted at step 5 via 8-param `setup()` + `add_child()` | LOW |
| ADR-0015 BattleHUD (depends-on) | Battle-scoped Control mounted at step 6 via 9-param `setup()` + `HUDLayer.add_child(battle_hud)`; ADR-0016 ratifies the CanvasLayer/BattleHUD mount point already specified in ADR-0015 §2 | **HIGH** (4.6 dual-focus, 4.5 AccessKit, 4.5 recursive Control disable — owned by ADR-0015; inherited transitively through BattleHUD child but NOT re-asserted at BattleScene level) |

**Highest Engine Risk among governing ADRs**: **LOW** for the BattleScene-direct surface (ADR-0016 introduces zero new post-cutoff API surface). HIGH-risk surface (ADR-0015 BattleHUD UI domain) is inherited transitively through the BattleHUD child but is verified at battle-hud epic stories (S6-05/S6-06/S6-09 already shipped), not re-asserted here.

## GDD / TR Requirements

This epic has no GDD (architecture-only — same as `camera/` epic). All 11 net-new TRs are registered to the synthetic system `battle-scene-wiring` and fully covered by ADR-0016:

| TR-ID | Requirement (summary) | ADR Coverage |
|-------|----------------------|--------------|
| TR-battle-scene-wiring-001 | §1 Module Form — NEW pattern: scene-root-as-orchestrator (`class_name BattleScene extends Node2D`; mounted as root of `scenes/battle/battle_scene.tscn`; lifecycle owned by ADR-0002 SceneManager; pattern stable at 1 invocation) | ADR-0016 ✅ |
| TR-battle-scene-wiring-002 | §2 Scene Tree Topology — 3-node `.tscn` skeleton (`BattleScene` + `GridLayer` Node2D + `HUDLayer` CanvasLayer at `layer=1`); NO pre-instanced children; lint `tools/ci/lint_battle_scene_pre_instanced_children.sh` asserts EXACTLY 3 nodes | ADR-0016 ✅ |
| TR-battle-scene-wiring-003 | §3 Init Order — 6-step `_ready()` mount sequence in DI dependency order (MapGrid → BattleCamera → HPStatusController → TurnOrderRunner → GridBattleController → BattleHUD); honors setup-before-`add_child()` mandate from 5 prior ADRs; only 1 valid topological sort of dependency DAG | ADR-0016 ✅ |
| TR-battle-scene-wiring-004 | §4 Mock Encounter Loader (Sprint-6 Throwaway) — hardcoded 4-unit mock encounter inline in `battle_scene.gd._ready()` between `# === SPRINT-6 MOCK ENCOUNTER ===` / `# === END MOCK ===` markers; 4 helper methods in `# === SPRINT-6 MOCK ENCOUNTER HELPERS ===` block; mechanical deletion ~50 LoC + 1 line in project.godot at ADR-0017 acceptance | ADR-0016 ✅ |
| TR-battle-scene-wiring-005 | §5 + R-1 + R-5 — Sprint-6 sets `[application] run/main_scene = "res://scenes/battle/battle_scene.tscn"` in `project.godot` for standalone launch; 1-line revert at ADR-0017 acceptance | ADR-0016 ✅ |
| TR-battle-scene-wiring-006 | §7 + R-6 + auto-tree-free delegation — NO `_exit_tree()` body on BattleScene root; reverse-DFS auto-tree-free + each child's R-N `_exit_tree()` mandate handles all teardown; result: all 11+ GameBus subscriptions cleanly disconnected via existing per-ADR mandates | ADR-0016 ✅ |
| TR-battle-scene-wiring-007 | §Decision + R-7 — NO GameBus subscriptions on BattleScene root: non-emitter + non-subscriber discipline (mirrors ADR-0015 BattleHUD precedent); lint `tools/ci/lint_battle_scene_no_gamebus_subscriptions.sh` enforces zero `GameBus.*.connect` / `GameBus.*.emit` calls; forbidden_pattern `battle_scene_root_signal_subscription` registered in registry v9 → v10 | ADR-0016 ✅ |
| TR-battle-scene-wiring-008 | §Decision §R-8 + V-8/V-9 — `BattleScene._ready()` is **idempotent under all 3 launch sources**: (a) SceneManager-driven, (b) project.godot main_scene config, (c) `--main-scene` CLI override; NO launch-source branching; smoke matrix at S6-07 evidence doc covers 3 launch sources × 6 mount steps = 18 verification points | ADR-0016 ✅ |
| TR-battle-scene-wiring-009 | §R-9 + Performance — `BattleScene._ready()` <50ms wall-clock on Snapdragon 7-gen (well within ADR-0002's 2000ms budget); `_process` / `_physics_process` = 0ms (no body); free / `queue_free` <20ms (within ADR-0002's <100ms deferred-free budget); RAM footprint <100KB orchestration overhead only | ADR-0016 ✅ |
| TR-battle-scene-wiring-010 | §R-10 — Forbidden-pattern compliance: (a) no static state; (b) no autoload form; (c) no parameter-on-instantiate. 3 forbidden_patterns registered: `battle_scene_pre_instanced_children` + `battle_scene_root_signal_subscription` + `battle_scene_sprint6_mock_marker_must_exist` (semantic flips at ADR-0017 acceptance) | ADR-0016 ✅ |
| TR-battle-scene-wiring-011 | §Implementation Guidelines + Migration Plan §1 — 3 lint scripts wired into `.github/workflows/tests.yml` after the 5 battle-hud lint group; integration smoke test at `tests/integration/feature/battle_scene/battle_scene_smoke_test.gd`; smoke evidence at `production/qa/evidence/battle_scene_smoke_2026-05-XX.md` | ADR-0016 ✅ |

**Untraced Requirements**: None (11/11 covered by ADR-0016).

## Same-Patch Obligations from ADR-0016 Acceptance

These obligations land at the implementation story (S6-07) and must ship together for the epic to close:

1. **3-node `.tscn` skeleton** — `scenes/battle/battle_scene.tscn` (`BattleScene` Node2D + `GridLayer` Node2D + `HUDLayer` CanvasLayer at `layer=1`; NO pre-instanced children)
2. **Orchestrator script** — `src/feature/battle_scene/battle_scene.gd` (~150-200 LoC; 6-step `_ready()` mount + sprint-6 mock encoder helpers + zero `_exit_tree()` body)
3. **`project.godot` main_scene flip** — `[application] run/main_scene = "res://scenes/battle/battle_scene.tscn"` with adjacent `# SPRINT-6 ONLY — REVERT WHEN ADR-0017 LANDS` comment
4. **3 lint scripts** wired into `.github/workflows/tests.yml`:
   - `tools/ci/lint_battle_scene_pre_instanced_children.sh` (TR-002)
   - `tools/ci/lint_battle_scene_no_gamebus_subscriptions.sh` (TR-007)
   - `tools/ci/lint_battle_scene_sprint6_mock_marker.sh` (TR-004 + TR-010)
5. **Integration smoke test** — `tests/integration/feature/battle_scene/battle_scene_smoke_test.gd` asserting 6 children mount + 0 errors / 0 orphans
6. **Smoke evidence doc** — `production/qa/evidence/battle_scene_smoke_2026-05-XX.md` covering 3 launch sources × 6 mount steps = 18 verification points

## Stories

| # | Story | Type | Status | TR-IDs | Estimate |
|---|-------|------|--------|--------|----------|
| [001](story-001-class-skeleton-and-mount-sequence.md) | BattleScene class skeleton + 3-node `.tscn` + 6-step `_ready()` mount sequence + sprint-6 mock encoder | Integration | **Complete** (2026-05-04) | TR-001/002/003/004/006/007/009 | 3h |
| [002](story-002-standalone-launch-and-smoke-evidence.md) | `project.godot` `main_scene` flip + cross-launch-source smoke evidence (3 launch sources × 6 mount steps = 18 verification points) | Integration | **Complete** (2026-05-04) | TR-005/008 | 1.5h |
| [003](story-003-lints-and-epic-terminal.md) | 3 lint scripts + CI wiring + 3 forbidden_patterns + epic terminal (verification summary doc) | Config/Data | **Complete** (2026-05-04) | TR-010/011 | 1.5h |

**Total estimate**: ~6h = ~0.75 working days. Within sprint-6 S6-07 budget (1.5d budgeted).

**Implementation order**: 001 (skeleton + mount; S6-07 alignment) → 002 (launch flip + smoke evidence) → 003 (epic terminal). All 3 stories are **Ready** (ADR-0016 Accepted; no Proposed deps).

**Sprint allocation**: epic preview (this artifact) at S6-03; story-001 at S6-07; story-002/003 land within sprint-6 if capacity allows OR slip to sprint-7. The +1 playable-surface delta is hit at story-001 completion (S6-07 close); story-002/003 are hardening and do not gate the delta target.

## Definition of Done

This epic is complete when:

- All stories are implemented, reviewed, and closed via `/story-done`
- All 11 TR-battle-scene-wiring-* requirements are satisfied (verified against `docs/architecture/tr-registry.yaml`)
- The 6 same-patch obligations above are shipped (`.tscn` + script + main_scene flip + 3 lints + smoke test + smoke evidence)
- Integration smoke test passes (6 children mount + 0 errors / 0 orphans / 0 leaked GameBus subscriptions when BattleScene is freed)
- 3 lint scripts pass in CI
- Smoke evidence doc covers 3 launch sources × 6 mount steps = 18 verification points
- ADR-0016 §Migration Plan revert path is documented (1-line `project.godot` edit + ~50 LoC mock encoder deletion + smoke evidence re-author at ADR-0017 acceptance)
- The full regression baseline remains failure-free (`876/876 PASS / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0` baseline preserved or extended)

## Next Step

Epic **Complete** 2026-05-04. Verification summary at `production/qa/evidence/battle_scene_verification_summary.md`. Sprint-7+ unblocked: ADR-0017 Scenario Progression (S6-10) replaces sprint-6 mock encoder + reverts `project.godot` main_scene per Migration Plan §1.
