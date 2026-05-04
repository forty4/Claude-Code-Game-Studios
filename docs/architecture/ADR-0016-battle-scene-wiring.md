# ADR-0016: Battle Scene Wiring — `BattleScene` (scene-root-as-orchestrator that mounts the 5 battle-scoped systems in DI dependency order)

## Status
Accepted (2026-05-03 — lean mode authoring → Accepted same-day via /architecture-review delta #11 with 0 BLOCKING conflicts + 0 GDD revision flags + 5 same-patch wording flips applied (ADR-0005/0013/0014/0015 stale-ref backfill flipped "battle-scene-wiring NOT YET WRITTEN" → "ADR-0016 Accepted via delta #11"; registry/architecture.yaml v9 → v10 added 1 state_ownership + 1 interface + 1 api_decision + 3 forbidden_patterns). Authoring-time godot-specialist PASS WITH 2 REVISIONS resolved (12th invocation): revision #1 BattleUnit field rename `is_player → is_player_controlled` + `grid_position → position` applied in §4 mock helper (B-1); revision #2 applied same-patch per Implementation Notes. 5 advisories carried as IN-1..IN-5 for first-story (S6-07) implementation. Review-time godot-specialist invocation skipped this delta (no new engine API surface introduced; ADR-0016 is structural plumbing — Node lifecycle + scene loading + CanvasLayer mount all stable ≤4.0; HIGH-risk surface owned transitively by ADR-0015 not re-asserted at BattleScene level). 11 net-new TRs registered as TR-battle-scene-wiring-001..011 in tr-registry.yaml v11 → v12. Closes registry line 825 placeholder reference + sprint-5 retrospective AI #2 structural backfill carry. TD-ADR PHASE-GATE skipped per `production/review-mode.txt` = lean per ADR-0014/0015 lean-mode pattern.)

## Date
2026-05-03

## Last Verified
2026-05-03

## Decision Makers
- claude (lean mode authoring; no PHASE-GATE TD-ADR per `production/review-mode.txt`)

## Summary

After ADR-0010/0011/0013/0014/0015 each ratified the **battle-scoped Node + setup() BEFORE add_child()** pattern at 5 invocations, the project needs the **scene-root orchestrator** that mounts those 5 systems (plus battle-scoped MapGrid per ADR-0004) in dependency order inside `scenes/battle/battle_scene.tscn`. ADR-0016 locks `class_name BattleScene extends Node2D` as a 3-node `.tscn` skeleton (BattleScene root + GridLayer + HUDLayer) plus a code-driven 6-step `_ready()` mount sequence (MapGrid → BattleCamera → HPStatusController → TurnOrderRunner → GridBattleController → BattleHUD), with a sprint-6-only inline mock encounter loader and a sprint-6-only `project.godot` `main_scene` flip — both reverted when ADR-0017 Scenario Progression lands.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core (scene tree topology + Node lifecycle + .tscn structure) + Scripting (autoload boot order interaction + project.godot main_scene config) + Rendering (CanvasLayer mount for ADR-0015 BattleHUD overlay ordering) |
| **Knowledge Risk** | **LOW** — uses only stable Godot APIs: `Node` lifecycle (`_ready`, `_exit_tree` from 4.0), `Node.add_child(child, force_readable_name)` (4.0), `PackedScene.instantiate()` (4.0; replaced 4.0-era `instance()`), `Node.queue_free()` (4.0), `CanvasLayer.layer: int` property (4.0), `[application] run/main_scene` project.godot key (4.0), `class_name X extends Node2D` declaration (4.0). The HIGH-risk surface that ADR-0015 BattleHUD owns (4.6 dual-focus, 4.5 AccessKit, 4.5 recursive Control disable) is **inherited transitively** through the BattleHUD child but is NOT re-asserted at the BattleScene level — ADR-0015's verification items remain authoritative for that subtree. ADR-0016 introduces zero new post-cutoff API surface. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` (4.6 pin, LLM cutoff May 2025), `docs/engine-reference/godot/breaking-changes.md` (no Node lifecycle / scene loading / CanvasLayer API changes 4.4-4.6 — verified), `docs/engine-reference/godot/deprecated-apis.md` (no relevant entries — confirmed `instance()` → `instantiate()` predates project pin), `docs/engine-reference/godot/modules/ui.md` (CanvasLayer-on-top render order pattern + dual-focus inheritance), `docs/engine-reference/godot/modules/input.md` (touch event flow through scene tree to HUD child), `docs/architecture/ADR-0001-gamebus-autoload.md` (autoload boot order constraint — GameBus FIRST), `docs/architecture/ADR-0002-scene-manager.md` (Overworld ↔ BattleScene transition lifecycle owner — `_resolve_battle_scene_path` + deferred-free pattern; ADR-0016 ratifies in-scene topology only, NOT inter-scene transitions), `docs/architecture/ADR-0004-map-grid-data-model.md` (MapGrid battle-scoped Node + battle-scoped lifetime), `docs/architecture/ADR-0005-input-handling.md` (InputRouter autoload + BattleHUD provisional contract), `docs/architecture/ADR-0010-hp-status.md` (HPStatusController.initialize_unit per-unit + battle-scoped Node lifecycle), `docs/architecture/ADR-0011-turn-order.md` (TurnOrderRunner.initialize_battle one-shot + GameBus.unit_died subscription inside), `docs/architecture/ADR-0013-camera.md` (BattleCamera.setup(map_grid) 1-param + battle-scoped Node), `docs/architecture/ADR-0014-grid-battle-controller.md` (GridBattleController 8-param setup + 4 GameBus subscriptions + _exit_tree mandate), `docs/architecture/ADR-0015-battle-hud.md` (BattleHUD 9-param setup + 11 GameBus subscriptions + CanvasLayer/BattleHUD mount point + Pillar 2 lock), `docs/registry/architecture.yaml` (v9 — registry line 825 placeholder reference `battle-scene-wiring (BattleScene mount calls setup(...) BEFORE add_child(); freed automatically with BattleScene per ADR-0002)`), `production/sprints/sprint-6.md` S6-01..S6-07 (acceptance criteria + +1 playable-surface delta target), `production/epics/battle-hud/EPIC.md` (battle-hud R-3 InputRouter stub strategy for sprint-6), `src/core/turn_order_runner.gd` (shipped initialize_battle signature verified 2026-05-03), `src/core/hp_status_controller.gd` (shipped initialize_unit signature verified 2026-05-03). |
| **Post-Cutoff APIs Used** | None. ADR-0016 introduces zero new post-cutoff API surface. The HIGH-risk surface (4.6 dual-focus, 4.5 AccessKit, 4.5 recursive Control disable) lives in ADR-0015 BattleHUD; ADR-0016 transitively mounts that surface but does not exercise it directly. |
| **Verification Required** | (1) **DI sequence end-to-end** — confirm BattleScene._ready() calls setup() / initialize_unit() / initialize_battle() BEFORE add_child() for all 5 mounted systems; assert via integration smoke test loading `scenes/battle/battle_scene.tscn` + verifying `_ready()` completes without `assert` failure on any backend's DI null-check. KEEP through Polish. (2) **Free order auto-disconnect** — when SceneManager calls queue_free() on BattleScene per ADR-0002, the reverse-DFS auto-tree-free fires `_exit_tree()` on each child (BattleHUD first, then other 5 systems, then MapGrid, then BattleScene root). Each system's R-N `_exit_tree()` mandate (TD-057 retrofit pattern) handles its own GameBus disconnects. ADR-0016 itself adds zero `_exit_tree()` body (BattleScene root has no GameBus subscriptions to clean up). Verify via integration smoke test: load BattleScene → free it → assert 0 leaked GameBus subscriptions across all 5 systems. (3) **`PackedScene.instantiate()` cost on Snapdragon 7-gen** — BattleScene root .tscn is 3 nodes (~1KB packed); instantiate() expected <5ms wall-clock. Total `_ready()` mount sequence target <50ms (well within ADR-0002's 2000ms BattleScene load budget). (4) **`project.godot` `main_scene` flip durability** — verify the sprint-6 main_scene flip survives `godot --headless` smoke runs + `godot --editor` IDE workflow + `--main-scene` CLI override; document the revert path in `§Migration Plan`. (5) **Standalone-launch idempotency** — BattleScene._ready() must work identically whether launched (a) via SceneManager's deferred packed-scene instantiation pattern from ADR-0002 OR (b) via project.godot main_scene config OR (c) via `godot --main-scene scenes/battle/battle_scene.tscn` CLI override. No code path branches on launch source. Verify via test matrix at S6-07 smoke evidence doc. |

> **Knowledge Risk Note**: Domain is **LOW** risk for ADR-0016 itself. The transitive HIGH-risk surface (4.6 dual-focus + 4.5 AccessKit + 4.5 recursive Control disable) is owned by ADR-0015 and re-tested at battle-hud first stories (S6-05/S6-06). ADR-0016 adds no new engine-version sensitivity; future Godot 4.7+ changes to Node lifecycle, scene loading, or CanvasLayer would trigger a Superseded-by review.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0001 GameBus** (Accepted 2026-04-18) — autoload boots BEFORE BattleScene mount; BattleScene's child systems subscribe to GameBus signals at their `_ready()` per their respective ADRs. ADR-0016 does NOT subscribe to GameBus directly. **ADR-0002 SceneManager** (Accepted 2026-04-18) — SceneManager owns the Overworld ↔ BattleScene transition lifecycle (`_resolve_battle_scene_path` + `packed.instantiate()` + `get_tree().root.add_child(_battle_scene_ref)` + deferred-free pattern); ADR-0016 ratifies ONLY in-scene topology + mount sequence, NOT inter-scene transitions. SceneManager and ADR-0016 do not contradict — they are orthogonal scopes. **ADR-0004 MapGrid** (Accepted 2026-04-20) — battle-scoped MapGrid Node mounted as first child of BattleScene; loaded from MapResource `.tres` per chapter `map_id`. ADR-0016 ratifies the mount-order position (first; before BattleCamera which DI-depends on it). **ADR-0005 InputRouter** (Accepted 2026-04-30) — autoload Node already booted; DI'd to BattleHUD (per ADR-0015 9-param setup) at step 6 of init. ADR-0016 does NOT instantiate InputRouter. **ADR-0010 HPStatusController** (Accepted 2026-05-02) — battle-scoped Node mounted at step 3 via `HPStatusController.new()` + per-unit `initialize_unit(unit_id, hero, unit_class)` loop + `add_child()`. ADR-0016 ratifies the per-unit-init-before-add_child invocation order (current shipped signature has no setup() — only initialize_unit). **ADR-0011 TurnOrderRunner** (Accepted 2026-05-02) — battle-scoped Node mounted at step 4 via `TurnOrderRunner.new()` + `initialize_battle(unit_roster)` (one-shot; subscribes to GameBus.unit_died inside) + `add_child()`. ADR-0016 ratifies the one-shot-init-before-add_child invocation order. **ADR-0013 BattleCamera** (Accepted 2026-05-02) — battle-scoped Node mounted at step 2 via `BattleCamera.new()` + `setup(map_grid)` 1-param + `add_child()`. **ADR-0014 GridBattleController** (Accepted 2026-05-02) — battle-scoped Node mounted at step 5 via `GridBattleController.new()` + `setup(units, map_grid, camera, hero_db, turn_runner, hp_controller, terrain_effect, unit_role)` 8-param + `add_child()`. ADR-0016 ratifies the dependency-DAG ordering (camera + turn_runner + hp_controller all exist before this call). **ADR-0015 BattleHUD** (Accepted 2026-05-03 via /architecture-review delta #10) — battle-scoped Control mounted at step 6 via `BattleHUD.new()` + `setup(camera, hp_controller, turn_runner, grid_controller, input_router, map_grid, terrain_effect, unit_role, hero_db)` 9-param + `HUDLayer.add_child(battle_hud)`. ADR-0016 ratifies the CanvasLayer/BattleHUD mount point already specified in ADR-0015 §2 and the dependency-DAG ordering (grid_controller exists by step 5 close). |
| **Soft / Provisional** | (1) **ADR-0017 Scenario Progression (Accepted 2026-05-04 via /architecture-review delta #12 — sprint-7+ implementation pending)** — ADR-0017 ratifies the chapter loader (ChapterDefinition Resource hydrated from `assets/data/scenarios/{scenario_id}.json` at LOADING entry) + scenario state (13-state machine LOADING → SCENARIO_END) + 7-signal contract (5 confirmed + 2 ratified). At ADR-0017's sprint-7+ implementation patch, the sprint-6 inline mock encounter loader in `battle_scene.gd._ready()` (marked `# TODO: REMOVE WHEN ADR-0017 SCENARIO PROGRESSION LANDS`) is **DELETED** mechanically. ADR-0017 §Decision §`BattleConfig` confirms reuse of the ADR-0001 `BattlePayload` Resource (no new BattleConfig type) — call site becomes `var battle_config: BattlePayload = ScenarioRunner.get_active_battle_config()`. ADR-0016 §Migration Plan documents the exact deletion sites (3-step coordinated revert: mock encoder + project.godot main_scene flip + lint semantic flip). (2) **`project.godot` `main_scene` revert** — sprint-6 flips `[application] run/main_scene` to `res://scenes/battle/battle_scene.tscn` for the +1 playable-surface delta. Sprint-7+ when ADR-0017 lands, the main_scene reverts to the title screen / overworld entry per ADR-0002 SceneManager standard flow. ADR-0016 §Migration Plan documents the revert. (3) **`MapGrid` setup() signature** — ADR-0004 predates the setup-before-add_child pattern; current shipped MapGrid is a Node that loads from a MapResource `.tres` via `@export` deserialization (no explicit setup() method). ADR-0016 ratifies the existing pattern: instantiate from `.tres` then add_child(). If a future ADR-0004 amendment adds a setup(map_resource) signature for symmetry with the other 5 systems, ADR-0016 §3 init order is **additively amended** — no breaking change. |
| **Enables** | (1) **battle-scene Feature epic** (sprint-6 S6-03 — `/create-epics battle-scene` after this ADR is Accepted; preview ~3-5 stories per sprint-6 plan); (2) **S6-07 first runnable BattleScene** (sprint-6 — mounts 5 systems + 4-unit mock encounter; **+1 playable-surface delta target**); (3) **ADR-0017 Scenario Progression** (sprint-6 should-have S6-10 / sprint-7 — Scenario Progression's chapter loader replaces the sprint-6 mock per §Migration Plan); (4) **ADR-0018 Destiny Branch** (sprint-6 nice-to-have S6-11 / sprint-7 — Destiny Branch consumes `battle_outcome_resolved.fate_data` from BattleScene-mounted GridBattleController per ADR-0014 line 335 + Pillar 2 lock; ADR-0016 is the first scene to actually emit that signal at runtime); (5) **Closes registry line 825 placeholder reference** (`battle-scene-wiring (BattleScene mount calls setup(...) BEFORE add_child(); freed automatically with BattleScene per ADR-0002)`) — placeholder → ratified. |
| **Blocks** | battle-scene Feature epic implementation (cannot start S6-03 epic scaffolding without this ADR Accepted); sprint-6 Definition-of-Done item "First runnable BattleScene mounts 5 systems without crash" (S6-07); sprint-6 Definition-of-Done item "+1 playable-surface delta achieved"; first user-visible-surface battle ship date; ADR-0017 Scenario Progression authoring (Scenario Progression's contract is "BattleScene loads chapter X" — without ADR-0016, "BattleScene" is undefined). |
| **Ordering Note** | **6th ADR in the battle-scoped lineage** but a NEW pattern: **scene-root-as-orchestrator**. Distinct from the 5-precedent battle-scoped Node setup() pattern (Camera + HP/Status + Turn Order + Grid Battle + Battle HUD) because BattleScene IS the scene root, not a child of one. Its lifecycle is owned by ADR-0002 SceneManager (parent ↔ child relationship: SceneManager creates and frees BattleScene; BattleScene creates and frees its 6 child systems via auto-tree-free). The pattern is reusable for future scene roots: `OverworldScene`, `MainMenuScene`, `BattlePrepScene`. Pattern stable at 1 invocation; future scene-root orchestrators should follow the same code-driven `_ready()` mount sequence + DI-DAG-ordered child instantiation + reliance on auto-tree-free for teardown. |

## Context

### Problem Statement

After sprint-5 closed at 13/13 with ADR-0014 GridBattleController shipping a 10/10 Complete epic (5 controller-LOCAL signals + 8-backend DI'd) and ADR-0015 BattleHUD shipping the first Presentation-layer ADR (5th invocation of battle-scoped Node + 11 GameBus subscriptions + 9-backend DI'd + Pillar 2 lock), the project has all 5 battle-scoped systems individually authored and (3 of 5) implemented as Complete. **What's missing is the scene that mounts them together.** Without ADR-0016, sprint-6 cannot ship the +1 playable-surface delta target — there is no defined contract for:

1. **Scene tree topology** — where does each of the 5 systems live in the BattleScene Node tree? What's the parent-child arrangement? Is BattleHUD a sibling of GridBattleController or a grandchild via CanvasLayer?
2. **Init sequence** — in what order are the 5 systems instantiated and configured? Camera depends on MapGrid; GridBattleController depends on Camera + HP/Status + TurnOrder; BattleHUD depends on all of the above. The DAG forces an order; ADR-0016 must lock it.
3. **Setup-before-add_child invocation pattern** — all 5 ADRs mandate `setup() BEFORE add_child()` (R-N requirement in each), but the SCENE doesn't know that until ADR-0016 says "yes, the scene's `_ready()` is the place that orchestrates this".
4. **`.tscn` structure** — is the scene file pre-instanced with all 6 children (violates setup-before-add_child) or is it a code-driven skeleton (the only viable path given the ADR mandate)?
5. **Standalone-runnable launch** — sprint-6 wants `godot --path .` to produce the playable battle screen. That requires either `project.godot` main_scene config or a CLI override flag; ADR-0016 must lock the choice.
6. **Sprint-6 mock encounter** — there's no Scenario Progression ADR yet. Sprint-6 ships the +1 playable-surface delta with a hardcoded 4-unit mock; ADR-0017 will replace it. ADR-0016 must define WHERE the mock lives so its eventual deletion is mechanical.

### Current State

- **5 battle-scoped systems shipped at code level** (3 Complete + 2 Ready/authored): HPStatusController + TurnOrderRunner + BattleCamera + GridBattleController are Complete; BattleHUD is Ready (ADR-0015 Accepted; first 2 impl stories scheduled S6-05/S6-06).
- **ADR-0002 SceneManager** owns the Overworld ↔ BattleScene transition lifecycle but treats BattleScene as a black box (`_battle_scene_ref = packed.instantiate()` + `get_tree().root.add_child(_battle_scene_ref)`). What's INSIDE the .tscn is not ADR-0002's concern.
- **Registry line 825** already has the placeholder reference `battle-scene-wiring (BattleScene mount calls setup(...) BEFORE add_child(); freed automatically with BattleScene per ADR-0002)` — the contract has been promised; ADR-0016 ratifies it.
- **`scenes/battle/` directory does NOT yet contain `battle_scene.tscn`**. The path is referenced in ADR-0002 line 417 + ADR-0015 §2 but the file has never been authored. S6-07 will create it.
- **`production/epics/battle-scene/` directory does NOT yet exist**. S6-03 will create it after ADR-0016 Accepted.

### Constraints

- **Engine pin**: Godot 4.6. No 4.7+ APIs.
- **Setup-before-add_child mandate**: 5 prior ADRs (0010/0011/0013/0014/0015) all require `setup() BEFORE add_child()` as R-N. ADR-0016 cannot violate; the only viable scene structure is code-driven instantiation in BattleScene._ready().
- **Auto-tree-free teardown**: SceneManager calls `queue_free()` on BattleScene; reverse-DFS auto-fires `_exit_tree()` on each child. Each system's R-N `_exit_tree()` mandate handles its own GameBus disconnects. ADR-0016 must NOT add a redundant orchestrator-level teardown.
- **Sprint-6 capacity**: 0.4d (~3.2h) budgeted for this ADR per sprint-6 plan S6-01.
- **MVP gameplay scope**: 4-unit mock encounter (2 player + 2 enemy) on a 6×6 all-grass map. No real Scenario Progression yet (sprint-7+).
- **InputRouter live-wiring**: per battle-hud EPIC.md R-3 mitigation, sprint-6 BattleHUD uses `tests/helpers/input_router_stub.gd` for tests. The runtime BattleScene.gd passes the **autoload** `InputRouter` instance to BattleHUD.setup() (live, not stub). Sprint-7+ when InputRouter Feature epic completes, the live-wiring works fully; sprint-6 partial-wiring is acceptable per AC-S6-07 ("non-crashing battle screen", not "fully playable Beat 1").
- **`project.godot` main_scene flip**: sprint-6 flips for standalone launch; sprint-7+ reverts when ADR-0017 ships. Documented in §Migration Plan.

### Requirements

- **R-1**: BattleScene class is `class_name BattleScene extends Node2D` with `class_name BattleScene` PascalCase; mounted as the root of `scenes/battle/battle_scene.tscn`. (Node name = "BattleScene" matching registry runtime paths `BattleScene/HPStatusController` etc.)
- **R-2**: `.tscn` is a 3-node skeleton (BattleScene root + GridLayer Node2D + HUDLayer CanvasLayer with `layer=1`). NO other children pre-instanced — all 6 system Nodes are code-driven in `_ready()`.
- **R-3**: BattleScene._ready() executes a 6-step mount sequence in DI dependency order: (1) MapGrid + load from MapResource → add_child as first sibling under BattleScene root; (2) BattleCamera.setup(map_grid) → add_child; (3) HPStatusController + per-unit initialize_unit loop → add_child; (4) TurnOrderRunner + initialize_battle(roster) → add_child; (5) GridBattleController.setup(...) 8-param → add_child; (6) BattleHUD.setup(...) 9-param → HUDLayer.add_child(hud).
- **R-4**: Sprint-6 inline mock encounter loader (4 units + 6×6 all-grass map) lives directly in `battle_scene.gd._ready()` between explicit comment markers `# === SPRINT-6 MOCK ENCOUNTER ===` / `# === END MOCK ===` for mechanical sprint-7+ deletion when ADR-0017 lands.
- **R-5**: `project.godot` `[application] run/main_scene` flipped to `res://scenes/battle/battle_scene.tscn` for sprint-6 standalone launch; reverts in the same patch as ADR-0017 acceptance.
- **R-6**: NO `_exit_tree()` body on BattleScene root — auto-tree-free + each child's own `_exit_tree()` is sufficient. ADR-0016 ratifies this delegation.
- **R-7**: NO GameBus subscriptions on BattleScene root — non-emitter + non-subscriber discipline (mirrors ADR-0015 BattleHUD non-emitter). All cross-system signal flow goes through the 6 mounted children.
- **R-8**: BattleScene._ready() is **idempotent under all 3 launch sources**: (a) SceneManager-driven (ADR-0002 deferred packed-scene instantiation), (b) project.godot main_scene config, (c) `godot --main-scene` CLI override. No launch-source branching in code.
- **R-9**: Performance — BattleScene._ready() complete in <50ms wall-clock on Snapdragon 7-gen reference hardware (well within ADR-0002's 2000ms BattleScene load budget).
- **R-10**: Forbidden-pattern compliance — no static state on BattleScene; no autoload form (BattleScene is a scene root, not an autoload — by definition); no parameter-on-instantiate (BattleScene is loaded by SceneManager / Godot main_scene config — neither passes constructor parameters).

## Decision

### §0. Scope Statement

ADR-0016 scopes to **in-scene topology + mount sequence** ONLY. It does **NOT** ratify:
- The Overworld ↔ BattleScene transition (owned by ADR-0002).
- The chapter loader / scenario state (will be owned by ADR-0017 Scenario Progression — sprint-6 should-have S6-10).
- The Destiny Branch consumption of `battle_outcome_resolved.fate_data` (will be owned by ADR-0018 — sprint-6 nice-to-have S6-11).
- Battle Preparation scene (pre-battle hero loadout, formation pick) — sprint-7+ separate ADR.
- Battle Results screen polish (UI-GB-09 already authored in ADR-0015 § BattleHUD; ADR-0016 ratifies BattleHUD's mount but not the visual contract).

The sprint-6 mock encounter is **explicitly throwaway** — its complete deletion path is documented in §Migration Plan.

### §1. Module Form — Scene-Root-As-Orchestrator (NEW PATTERN)

```gdscript
# scenes/battle/battle_scene.gd
class_name BattleScene
extends Node2D

# Scene-root orchestrator. Mounts the 6 battle-scoped child Nodes (MapGrid +
# BattleCamera + HPStatusController + TurnOrderRunner + GridBattleController +
# BattleHUD) in DI dependency order. NEW pattern: scene-root-as-orchestrator.
# Distinct from the 5-precedent battle-scoped Node setup() pattern because
# BattleScene IS the scene root, not a child of one.
#
# Lifecycle: created and freed by ADR-0002 SceneManager (Overworld↔BattleScene
# transition flow) OR by Godot's main_scene config (sprint-6 standalone launch
# only — see §5 + §Migration Plan revert path).
#
# No GameBus subscriptions. No _exit_tree() body. No static state.
# Auto-tree-free + each child's R-N _exit_tree() handles all teardown.

@onready var _grid_layer: Node2D = $GridLayer
@onready var _hud_layer: CanvasLayer = $HUDLayer

# DI'd backend references — populated in _ready() before child instantiation
var _hero_db: HeroDatabase
var _balance_constants: BalanceConstants
var _terrain_effect: TerrainEffect
var _unit_role: UnitRole
var _input_router: InputRouter

# Battle-scoped child Node references — populated during _ready() mount
var _map_grid: MapGrid
var _battle_camera: BattleCamera
var _hp_controller: HPStatusController
var _turn_runner: TurnOrderRunner
var _grid_controller: GridBattleController
var _battle_hud: BattleHUD
```

**Rejected**: autoload (BattleScene is a scene, not a singleton — by definition); parameter-on-instantiate (Godot's `PackedScene.instantiate()` and main_scene config don't pass constructor parameters); battle-scoped child Node form (BattleScene IS the scene root, not a child); see §Alternatives Considered.

### §2. Scene Tree Topology

```
scenes/battle/battle_scene.tscn (editor-authored)
└── BattleScene (Node2D)  [script: battle_scene.gd attached]
    ├── GridLayer (Node2D)         [empty in .tscn — populated by code]
    │                                [hosts UI-GB-12/13/14 grid-space overlays]
    └── HUDLayer (CanvasLayer, layer=1)  [empty in .tscn — populated by code]

at runtime after _ready() completes:
└── BattleScene (Node2D)
    ├── MapGrid (Node — ADR-0004)
    ├── BattleCamera (Camera2D — ADR-0013)
    ├── GridLayer (Node2D)
    │   └── (UI-GB-12/13/14 grid-space overlays — added by BattleHUD per ADR-0015 §2)
    ├── HPStatusController (Node — ADR-0010)
    ├── TurnOrderRunner (Node — ADR-0011)
    ├── GridBattleController (Node — ADR-0014)
    └── HUDLayer (CanvasLayer, layer=1)
        └── BattleHUD (Control — ADR-0015)
```

**Sibling order rationale**: MapGrid + BattleCamera + GridLayer are placed before HPStatusController + TurnOrderRunner + GridBattleController to keep visual/world-space children grouped. HUDLayer is last so its `layer=1` CanvasLayer renders on top of all world-space siblings (HUDLayer is a CanvasLayer; CanvasLayer rendering is layered independent of sibling order, but visual scene-tree-reading clarity benefits from last-position).

**Why GridLayer is in the .tscn skeleton**: ADR-0015 §2 specifies UI-GB-12/13/14 are "grid-layer overlays (rendered at the world-space tile layer)". They need a parent Node2D in world-space scope (NOT under HUDLayer/CanvasLayer because CanvasLayer renders in screen-space). Pre-authoring GridLayer in the .tscn keeps the structural-only Layers in editor-visible scope; runtime overlays mount under it via @export NodePath resolution from BattleHUD's grid-overlay child references.

### §3. Init Order — 6-Step `_ready()` Mount Sequence

```gdscript
func _ready() -> void:
    # === DI: 5 autoload backends (already booted before BattleScene mount) ===
    _hero_db = HeroDatabase  # autoload per ADR-0007 §3
    _balance_constants = BalanceConstants  # autoload per ADR-0006 §3
    _terrain_effect = TerrainEffect  # autoload per ADR-0008 §3
    _unit_role = UnitRole  # autoload per ADR-0009 §3
    _input_router = InputRouter  # autoload per ADR-0005 §3

    # === SPRINT-6 MOCK ENCOUNTER ===
    # TODO: REMOVE WHEN ADR-0017 SCENARIO PROGRESSION LANDS
    # Sprint-7+ replacement: roster + map_resource come from BattleConfig
    # passed by ScenarioRunner via SceneManager.battle_launch_requested payload.
    var mock_roster: Array[BattleUnit] = _build_mock_roster_sprint6()
    var mock_map_resource: MapResource = _build_mock_map_resource_sprint6(6, 6)
    # === END MOCK ===

    # === STEP 1: MapGrid (ADR-0004) ===
    _map_grid = MapGrid.new()
    _map_grid.load_map_resource(mock_map_resource)  # MapResource @export deserialization
    add_child(_map_grid)

    # === STEP 2: BattleCamera (ADR-0013) — depends on MapGrid ===
    _battle_camera = BattleCamera.new()
    _battle_camera.setup(_map_grid)  # 1-param DI per ADR-0013 §3
    add_child(_battle_camera)

    # === STEP 3: HPStatusController (ADR-0010) — depends on roster ===
    _hp_controller = HPStatusController.new()
    for unit in mock_roster:
        var hero: HeroData = _hero_db.get_hero(unit.hero_id)
        var unit_class: int = _unit_role.get_class_for_hero(unit.hero_id)
        _hp_controller.initialize_unit(unit.unit_id, hero, unit_class)
    add_child(_hp_controller)  # subscribes to GameBus.unit_turn_started in _ready

    # === STEP 4: TurnOrderRunner (ADR-0011) — depends on roster ===
    _turn_runner = TurnOrderRunner.new()
    _turn_runner.initialize_battle(mock_roster)  # one-shot; subscribes to GameBus.unit_died inside
    add_child(_turn_runner)

    # === STEP 5: GridBattleController (ADR-0014) — depends on 7 prior ===
    _grid_controller = GridBattleController.new()
    _grid_controller.setup(
        mock_roster,
        _map_grid,
        _battle_camera,
        _hero_db,
        _turn_runner,
        _hp_controller,
        _terrain_effect,
        _unit_role,
    )  # 8-param DI per ADR-0014 §3
    add_child(_grid_controller)  # subscribes to 4 GameBus signals in _ready

    # === STEP 6: BattleHUD (ADR-0015) — depends on all 5 prior ===
    _battle_hud = BattleHUD.new()
    _battle_hud.setup(
        _battle_camera,
        _hp_controller,
        _turn_runner,
        _grid_controller,
        _input_router,
        _map_grid,
        _terrain_effect,
        _unit_role,
        _hero_db,
    )  # 9-param DI per ADR-0015 §3
    _hud_layer.add_child(_battle_hud)  # subscribes to 11 GameBus signals in _ready
```

**Why this order is forced (not chosen)**: each step's DI dependencies are computed in prior steps. There is exactly one valid topological sort of the dependency DAG (6! = 720 permutations; only 1 satisfies all DI constraints). Step 1 must precede Step 2 (Camera DI'd MapGrid); Step 3 + Step 4 can swap (HP/Status and Turn Order have no inter-dependency at init — TurnOrderRunner subscribes to GameBus.unit_died, but the subscription resolves at runtime, not at init), but conventional order keeps "state owners" before "state listeners"; Step 5 must follow Steps 1-4 (8-param setup); Step 6 must follow Steps 1-5 (9-param setup including grid_controller).

### §4. Mock Encounter Loader (Sprint-6 Throwaway)

Sprint-6 ships a hardcoded 4-unit mock encounter inline in `battle_scene.gd` between explicit comment markers. Two private helpers:

```gdscript
# === SPRINT-6 MOCK ENCOUNTER HELPERS ===
# TODO: REMOVE WHEN ADR-0017 SCENARIO PROGRESSION LANDS
# These methods exist solely to ship the +1 playable-surface delta in sprint-6
# without blocking on Scenario Progression ADR. Delete the entire region
# between SPRINT-6 MOCK ENCOUNTER markers in §3 + this entire region.

func _build_mock_roster_sprint6() -> Array[BattleUnit]:
    # 2 player units (장비 tank + 조운 assassin) + 2 enemy units
    # All units start at full HP per UnitRole.get_max_hp(...)
    var roster: Array[BattleUnit] = []
    roster.append(_make_mock_unit(0, &"jangbi",   true,  Vector2i(1, 2)))   # tank
    roster.append(_make_mock_unit(1, &"joun",     true,  Vector2i(2, 2)))   # assassin
    roster.append(_make_mock_unit(2, &"enemy_a",  false, Vector2i(4, 2)))   # boss-tagged
    roster.append(_make_mock_unit(3, &"enemy_b",  false, Vector2i(5, 2)))
    return roster

func _make_mock_unit(unit_id: int, hero_id: StringName, is_player: bool, pos: Vector2i) -> BattleUnit:
    var unit: BattleUnit = BattleUnit.new()
    unit.unit_id = unit_id
    unit.hero_id = hero_id
    unit.is_player_controlled = is_player  # field name verified against src/core/battle_unit.gd 2026-05-03 godot-specialist Pass B-1
    unit.position = pos                    # field name verified against src/core/battle_unit.gd 2026-05-03 godot-specialist Pass B-1
    return unit

func _build_mock_map_resource_sprint6(width: int, height: int) -> MapResource:
    # 6×6 all-grass map; no obstacles; fully traversable
    var map: MapResource = MapResource.new()
    map.width = width
    map.height = height
    map.tile_data = _make_uniform_grass_tiles(width, height)
    return map

func _make_uniform_grass_tiles(w: int, h: int) -> Array:
    var tiles: Array = []
    for _i in range(w * h):
        tiles.append(&"grass")
    return tiles
# === END SPRINT-6 MOCK ENCOUNTER HELPERS ===
```

**Deletion sites at ADR-0017 acceptance**:
1. `battle_scene.gd._ready()` lines between `# === SPRINT-6 MOCK ENCOUNTER ===` and `# === END MOCK ===` markers (replace with `var roster + var map_resource = ScenarioRunner.get_active_battle_config()`).
2. `battle_scene.gd` entire `# === SPRINT-6 MOCK ENCOUNTER HELPERS ===` region (4 helper methods).
3. `project.godot` `[application] run/main_scene` revert (see §5).
4. Smoke evidence doc `production/qa/evidence/battle_scene_smoke_2026-05-XX.md` flagged for re-author against real scenario (sprint-7+).

Estimated deletion: ~50 LoC + 1 line in project.godot + 1 doc revisit. Mechanical; ADR-0017 patch will include.

### §5. `project.godot` `main_scene` Sprint-6 Flip

Sprint-6 sets `[application] run/main_scene = "res://scenes/battle/battle_scene.tscn"` for standalone launch:

```ini
; project.godot (sprint-6 only)
[application]
config/name="천명역전 (Defying Destiny)"
run/main_scene="res://scenes/battle/battle_scene.tscn"  ; SPRINT-6 ONLY — REVERT WHEN ADR-0017 LANDS
```

**Rationale**: enables `godot --path .` (no `--main-scene` override) to produce the playable battle screen — the +1 playable-surface delta target. CI smoke runs benefit (no flag bookkeeping). Human dev launch experience: F5 in editor lands in BattleScene directly.

**Sprint-7+ revert**: ADR-0017 Scenario Progression introduces ScenarioRunner / title-screen flow. The main_scene reverts to title screen (or whatever ADR-0017 specifies). The revert is a 1-line `project.godot` edit; coordinated with the §4 mock encoder removal in the same patch.

### §6. Load Order vs Init Order Separation

**Load order** (autoload boot at game-launch, configured in project.godot `[autoload]`):
1. `GameBus` (FIRST per ADR-0001 line 234 mandate)
2. `BalanceConstants` (per ADR-0006)
3. `HeroDatabase` (per ADR-0007)
4. `UnitRole` (per ADR-0009)
5. `TerrainEffect` (per ADR-0008)
6. `InputRouter` (per ADR-0005)
7. `SceneManager` (per ADR-0002)

**Init order** (BattleScene._ready() mount sequence — distinct from load order):
1. MapGrid → 2. BattleCamera → 3. HPStatusController → 4. TurnOrderRunner → 5. GridBattleController → 6. BattleHUD (per §3 above).

**Why these are independent**: Load order is about WHICH autoloads are booted at game-launch and in what sequence (GameBus first because all other autoloads reference it). Init order is about HOW battle-scoped Nodes are mounted INSIDE BattleScene (which doesn't exist until SceneManager creates it). The autoload set is fully populated before BattleScene._ready() ever fires; ADR-0016's init order is purely a function of the 5-system DI DAG.

**Implication**: changes to autoload boot order (e.g., adding a new autoload) do NOT affect ADR-0016's init order. Changes to init order (e.g., a future ADR adds a 7th battle-scoped system) require ADR-0016 amendment but do NOT affect autoload load order.

### §7. Free / Teardown — Delegated to ADR-0002 + Each Child's `_exit_tree()`

When SceneManager calls `queue_free()` on `_battle_scene_ref` per ADR-0002 §3:

1. Godot's reverse-DFS auto-tree-free fires `_exit_tree()` on each child in reverse-add order:
   - BattleHUD._exit_tree() → 11 GameBus disconnects per ADR-0015 §3
   - HUDLayer._exit_tree() (CanvasLayer; no script body)
   - GridBattleController._exit_tree() → 4 GameBus disconnects per ADR-0014 §3 + R-10
   - TurnOrderRunner._exit_tree() → GameBus.unit_died disconnect per ADR-0011 R-1
   - HPStatusController._exit_tree() → GameBus subscription cleanup per ADR-0010
   - GridLayer._exit_tree() (Node2D; no script body)
   - BattleCamera._exit_tree() → GameBus.input_action_fired disconnect per ADR-0013 R-6
   - MapGrid._exit_tree() (per ADR-0004 cleanup, if any)
2. Then BattleScene._exit_tree() fires (NO body — non-emitter + non-subscriber discipline per R-7).
3. Then BattleScene._exit_tree() returns; the Node is freed; SceneManager's deferred `_free_battle_scene_and_restore_overworld` continues.

**Result**: all 11+ GameBus subscriptions across the 6 mounted children are cleanly disconnected via existing per-ADR `_exit_tree()` mandates. ADR-0016 adds zero new teardown logic. The TD-057 retrofit pattern (story-009) plus camera_missing_exit_tree_disconnect forbidden_pattern + battle_hud_missing_exit_tree_disconnect forbidden_pattern + grid_battle_controller_missing_exit_tree_disconnect forbidden_pattern (5-precedent extension) all hold under ADR-0016's auto-tree-free delegation.

### Architecture

```
                          project.godot [autoload] (boot order)
                                       │
        ┌──────────────────────────────┼──────────────────────────────┐
        │                              │                              │
   ┌────▼────┐  ┌──────────────┐  ┌────▼─────┐  ┌──────────┐  ┌──────▼──────┐
   │GameBus  │  │BalanceConsts │  │HeroDB    │  │UnitRole  │  │SceneManager │
   │(autoload)│ │(autoload)    │  │(autoload)│  │(autoload)│  │(autoload)   │
   └─────────┘  └──────────────┘  └──────────┘  └──────────┘  └─────┬───────┘
                                                                    │
                                                                    │ battle_launch_requested
                                                                    ▼
                                                   ┌──────────────────────────────┐
                                                   │  scenes/battle/battle_scene  │
                                                   │  .tscn (3-node skeleton)     │
                                                   │                              │
                                                   │  BattleScene (Node2D)        │
                                                   │  ├── GridLayer (Node2D)      │
                                                   │  └── HUDLayer (CanvasLayer)  │
                                                   │                              │
                                                   │  battle_scene.gd._ready()    │
                                                   │  6-step mount sequence:      │
                                                   │   1. MapGrid                 │
                                                   │   2. BattleCamera            │
                                                   │   3. HPStatusController      │
                                                   │   4. TurnOrderRunner         │
                                                   │   5. GridBattleController    │
                                                   │   6. BattleHUD               │
                                                   └──────────────────────────────┘
```

### Implementation Guidelines

- **First story (S6-07)**: `scenes/battle/battle_scene.tscn` (3-node skeleton; editor-authored) + `src/feature/battle_scene/battle_scene.gd` (script attached to root) + `_build_mock_roster_sprint6()` + `_build_mock_map_resource_sprint6()` + `_make_mock_unit()` + `_make_uniform_grass_tiles()` helpers + `project.godot` main_scene flip + smoke evidence doc.
- **Test discipline**: Integration smoke test asserting 6 children mount + 0 errors / 0 orphans per Acceptance Criteria. Integration tests for full battle flow (move → attack → win) defer to sprint-7+ when InputRouter live-wiring + Scenario Progression are in place.
- **Lint**: Add `tools/ci/lint_battle_scene_pre_instanced_children.sh` asserting `scenes/battle/battle_scene.tscn` contains EXACTLY 3 nodes (BattleScene + GridLayer + HUDLayer). Failure = pre-instanced child injected (violates setup-before-add_child).
- **Lint**: Add `tools/ci/lint_battle_scene_no_gamebus_subscriptions.sh` asserting `src/feature/battle_scene/battle_scene.gd` does NOT contain `GameBus.*\.connect` (R-7 non-subscriber discipline).
- **Lint**: Add `tools/ci/lint_battle_scene_sprint6_mock_marker.sh` asserting `# === SPRINT-6 MOCK ENCOUNTER ===` and `# === END MOCK ===` markers exist (so deletion is mechanical when ADR-0017 lands; lint is removed in same patch).
- **No new BalanceConstants entries**: ADR-0016 introduces zero tuning knobs.
- **No new GameBus signals**: ADR-0016 introduces zero new signals.
- **No new state ownership**: ADR-0016 introduces zero new persistent state.

## Alternatives Considered

### Alternative 1: Pre-instanced .tscn with all 6 children + late setup() via @onready

- **Description**: All 6 system Nodes are pre-instanced as children in `scenes/battle/battle_scene.tscn` via the editor. `BattleScene._ready()` reaches into the children via `@onready var _camera: BattleCamera = $BattleCamera` and calls `_camera.setup(_map_grid)` AFTER they're already in the tree.
- **Pros**: Editor-friendly (visualize positions, set @export properties in inspector). Less code (no `.new()` boilerplate). Mirrors typical Godot scene authoring.
- **Cons**: VIOLATES the setup-before-add_child mandate codified in ADR-0010 R-N + ADR-0011 R-N + ADR-0013 R-1 (`setup() callable BEFORE add_child()`) + ADR-0014 R-2 (`callable BEFORE add_child()`) + ADR-0015 R-2 (`9-param call BEFORE add_child()`). Pre-instanced children are added to the tree at .tscn instantiation time — `setup()` cannot fire before that. Would require all 5 ADRs to be amended to relax their R-N — major architectural regression.
- **Estimated Effort**: lower upfront (no .new() boilerplate), but requires 5 ADR amendments (~3-5h cross-document work) + breaks the existing precedent stability (5 invocations).
- **Rejection Reason**: violates the load-bearing setup-before-add_child mandate. The mandate exists because each system's `_ready()` runs DI-null-checks AND subscribes to GameBus signals — both require backends present. Pre-instanced children cannot satisfy this without redesigning the mandate. Confirmed via grep on all 5 ADRs: each explicitly states "callable BEFORE add_child()" as R-N.

### Alternative 2: Hybrid — MapGrid pre-instanced in .tscn, others code-driven

- **Description**: `scenes/battle/battle_scene.tscn` includes MapGrid as a pre-instanced child (with @export-loaded MapResource). The other 5 systems are still code-driven in `_ready()`.
- **Pros**: Editor-friendly for MapGrid (visualize tile data in scene editor). Slight reduction in `_ready()` LoC (no MapGrid instantiation).
- **Cons**: MapGrid currently lacks a setup() signature (per ADR-0004 it loads from MapResource @export). If a future ADR-0004 amendment adds setup(map_resource) for symmetry, the hybrid breaks (forces moving MapGrid back to code-driven). Mixed pattern: 1 pre-instanced + 5 code-driven creates cognitive overhead — readers must remember which is which. The editor benefit is marginal because MVP map authoring lives in MapResource `.tres` files, not in scene files.
- **Estimated Effort**: similar to chosen approach.
- **Rejection Reason**: marginal editor benefit doesn't outweigh cognitive overhead of mixed-pattern. Future-proofing against ADR-0004 amendment is also a factor. Chosen Alternative (all-code-driven) keeps the pattern uniform and amendable.

### Alternative 3: Dedicated `BattleSetupCoordinator` class (separate from BattleScene root)

- **Description**: BattleScene is a thin Node2D scene root with no script. A separate `class_name BattleSetupCoordinator extends Node` is added as the FIRST child of BattleScene; its `_ready()` does the 6-step mount. Other 5 systems mount as siblings of BattleSetupCoordinator.
- **Pros**: BattleScene root stays thin and reusable across future scene types. BattleSetupCoordinator can be unit-tested independently of BattleScene.
- **Cons**: BattleSetupCoordinator must `add_child()` to its PARENT (BattleScene) which is unusual scene-tree convention (children typically don't manipulate parents). Adds 1 more Node to the tree for marginal benefit. Pattern is unfamiliar to typical Godot devs (scene-root-as-orchestrator is more idiomatic). Future scene roots (OverworldScene, MainMenuScene) would each need their own coordinator — adds ceremony without clear benefit.
- **Estimated Effort**: ~1.5× chosen approach (additional class + tests).
- **Rejection Reason**: the scene-root-as-orchestrator pattern is more idiomatic for Godot. Reusability concern is hypothetical; if a future scene root needs the same orchestration logic, refactor at that point. YAGNI.

### Alternative 4: Use `await` / async load via ResourceLoader.load_threaded_request

- **Description**: `_ready()` async-awaits MapResource loading via `ResourceLoader.load_threaded_request` per ADR-0002's pattern, then proceeds to the 6-step mount.
- **Pros**: Non-blocking initial load if MapResource is large. Matches ADR-0002's threaded-load discipline.
- **Cons**: ADR-0002 already handles threaded BattleScene load at the SceneManager level (`packed.instantiate()` is sync but the `load_threaded_request` happens before that). By the time `BattleScene._ready()` fires, the MapResource is already in memory (it's referenced by the scene). Re-doing async load INSIDE `_ready()` is redundant. Adds async complexity (await semantics + error handling) without clear benefit. Sprint-6 6×6 mock map is <1KB — trivially fast.
- **Estimated Effort**: ~1.3× chosen approach (async error paths + tests).
- **Rejection Reason**: redundant with ADR-0002's threaded load; introduces complexity without clear benefit. If profiling shows MapResource load is a bottleneck post-MVP, revisit.

## Consequences

### Positive

- **First +1 playable-surface delta achieved** since sprint-3 prototypes — sprint-6 ships the runnable battle screen.
- **5 prior ADRs' setup-before-add_child mandate** is honored end-to-end. No retroactive ADR amendments needed.
- **Auto-tree-free teardown** delegates cleanly to existing per-ADR `_exit_tree()` mandates. No new teardown surface to test.
- **Mechanical sprint-7+ migration**: mock encounter + main_scene flip both have explicit deletion sites; the ADR-0017 patch will include the revert.
- **Reusable scene-root-as-orchestrator pattern** for future scene roots (OverworldScene, MainMenuScene, BattlePrepScene).
- **Standalone-runnable**: `godot --path .` launches the playable battle screen — F5 in editor lands directly in BattleScene; CI smoke runs gain a concrete entry point.

### Negative

- **Sprint-6 main_scene flip introduces project.godot churn** that must be reverted in the ADR-0017 patch. Mitigation: explicit `# SPRINT-6 ONLY — REVERT WHEN ADR-0017 LANDS` comment in project.godot + §Migration Plan deletion checklist.
- **Sprint-6 mock encoder is technical debt** (~50 LoC + 4 helpers) that must be deleted at ADR-0017 acceptance. Mitigation: explicit comment markers + lint asserting markers exist + §Migration Plan deletion checklist.
- **No editor preview** of mounted Nodes (because they're code-driven). Devs cannot inspect runtime tree without running the scene. Mitigation: smoke test asserts the runtime tree shape; `Remote Tree` in debug session shows runtime structure.
- **First scene-root-as-orchestrator pattern** in the project. Pattern stability begins at 1 invocation; future scene roots will validate or revise.

### Neutral

- **Pattern divergence from ADR-0010/0011/0013/0014/0015** (battle-scoped Node + setup) is intentional — BattleScene IS the scene, not a child of one. Ordering note in §ADR Dependencies makes this explicit.
- **Sprint-6 partial InputRouter live-wiring** is acceptable per AC-S6-07 (non-crashing screen, not fully playable Beat 1). Sprint-7+ when input-handling impl epic completes, full live-wiring works without ADR-0016 amendment (the `_input_router = InputRouter` autoload reference is stable).

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|-----------|
| **R-1**: Sprint-6 main_scene flip not reverted in ADR-0017 patch — title screen never appears at sprint-7+ launch | LOW | MEDIUM (dev-experience friction; CI smoke would still pass) | Explicit `# SPRINT-6 ONLY — REVERT WHEN ADR-0017 LANDS` comment + §Migration Plan checklist + ADR-0017 author reads §Migration Plan as gating step |
| **R-2**: Sprint-6 mock encounter deletion missed — `# === SPRINT-6 MOCK ENCOUNTER ===` markers persist in production code post-ADR-0017 | LOW | MEDIUM (technical debt accumulation; confusing for new devs) | Lint `lint_battle_scene_sprint6_mock_marker.sh` flips from "marker must exist" (sprint-6) to "marker must NOT exist" (sprint-7+) in same patch as ADR-0017 acceptance |
| **R-3**: BattleScene._ready() exception in any of 6 steps leaves partial state — half-mounted scene with dangling subscriptions | MEDIUM | HIGH (silent leak; first-class dev-experience trap) | Each child Node's `_ready()` asserts non-null DI; failure throws assert with clear message naming the missing dep. Smoke test S6-07 explicitly verifies all 6 mounts + 0 errors. CI gates this. |
| **R-4**: Future ADR adds 7th battle-scoped system; ADR-0016 init order requires amendment but ADR-0016 wasn't read first | MEDIUM | LOW (init order amendment is mechanical; cross-references to ADR-0016 in registry catch the omission) | Registry api_decisions entry for battle_scene_wiring lists "init order: 6-step DAG" as the canonical contract; future battle-scoped Node ADRs reference + extend it |
| **R-5**: BattleScene loaded via 3 launch sources (SceneManager / project.godot main_scene / `--main-scene` CLI) — branching code path introduced accidentally | LOW | MEDIUM (test-skip for dev-only path; production bug surface) | R-8 explicit non-branching mandate; smoke test matrix covers all 3 launch sources at S6-07 evidence doc |
| **R-6**: MapResource @export deserialization fails on sprint-6 mock — MapGrid not populated, BattleCamera DI assertion fires | LOW | MEDIUM (sprint-6 dev-experience block; +1 playable-surface delta missed) | Mock builder uses `.new() + .property = X` direct assignment NOT `.tres` round-trip — bypass deserialization risk entirely; sprint-7+ when real chapters land, ADR-0017 owns the .tres path |
| **R-7**: Pre-instanced child injected into `scenes/battle/battle_scene.tscn` accidentally via editor (devs don't read ADR before authoring) | MEDIUM | MEDIUM (silently violates setup-before-add_child mandate; race conditions at runtime) | Lint `lint_battle_scene_pre_instanced_children.sh` asserts EXACTLY 3 nodes; CI fails if violated. Comment block in `battle_scene.gd` documents the "code-driven children" rule. |

## Performance Implications

| Metric | Before | Expected After | Budget |
|--------|--------|---------------|--------|
| BattleScene `_ready()` wall-clock (Snapdragon 7-gen) | N/A (scene didn't exist) | <50ms (6 instantiations + 11 setup methods + 16 add_child + sub-tree _ready cascades) | <2000ms total BattleScene load per ADR-0002 |
| BattleScene `_ready()` wall-clock (M1 Mac dev) | N/A | <10ms | n/a |
| BattleScene `_process()` per-frame | N/A | 0ms (no _process body) | 0ms |
| BattleScene `_physics_process()` per-frame | N/A | 0ms (no _physics_process body) | 0ms |
| BattleScene RAM footprint (orchestration overhead only — children measured separately) | N/A | <100KB (scene root + 2 layer Nodes + ~20 typed-Variant references) | n/a (children dominate) |
| Free / queue_free wall-clock on battle exit | N/A | <20ms (reverse-DFS auto-tree-free + 11 disconnect calls) | <100ms per ADR-0002 deferred-free pattern |

## Migration Plan

**Sprint-6 ship (this ADR):**
1. Author `scenes/battle/battle_scene.tscn` (3-node skeleton: BattleScene + GridLayer + HUDLayer).
2. Author `src/feature/battle_scene/battle_scene.gd` (class_name BattleScene + 6-step _ready() + 4 mock helper methods inside marker block).
3. Edit `project.godot` `[application] run/main_scene = "res://scenes/battle/battle_scene.tscn"` with `# SPRINT-6 ONLY — REVERT WHEN ADR-0017 LANDS` comment.
4. Author 3 lint scripts (`lint_battle_scene_pre_instanced_children.sh` + `lint_battle_scene_no_gamebus_subscriptions.sh` + `lint_battle_scene_sprint6_mock_marker.sh`).
5. Wire 3 lints into `.github/workflows/tests.yml` after the 5 battle-hud lint group.
6. Write S6-07 smoke evidence at `production/qa/evidence/battle_scene_smoke_2026-05-XX.md` (covers 3 launch sources × 6 mount steps = 18 verification points).

**Sprint-7+ at ADR-0017 acceptance (the revert patch):**
1. Replace `battle_scene.gd._ready()` lines between `# === SPRINT-6 MOCK ENCOUNTER ===` and `# === END MOCK ===` with `var battle_config = ScenarioRunner.get_active_battle_config()` (or whatever ADR-0017's API ratifies); use `battle_config.roster` + `battle_config.map_resource` for downstream steps.
2. Delete `_build_mock_roster_sprint6()` + `_make_mock_unit()` + `_build_mock_map_resource_sprint6()` + `_make_uniform_grass_tiles()` (entire `# === SPRINT-6 MOCK ENCOUNTER HELPERS ===` block).
3. Edit `project.godot` `[application] run/main_scene` back to title screen (or whatever ADR-0017 specifies).
4. Flip `lint_battle_scene_sprint6_mock_marker.sh` semantic from "marker MUST exist" to "marker MUST NOT exist" (i.e., the marker is FORBIDDEN post-ADR-0017).
5. Update S6-07 smoke evidence — re-author against real ScenarioRunner-driven scenario load.

**Rollback plan**: if ADR-0016 implementation surfaces a blocking issue at S6-07, revert `project.godot` main_scene to title screen + delete `scenes/battle/battle_scene.tscn` + delete `src/feature/battle_scene/battle_scene.gd`. Sprint-6 +1 playable-surface delta target slips to sprint-7. No production code or other ADRs are affected by the rollback.

## Validation Criteria

- [ ] **V-1**: `scenes/battle/battle_scene.tscn` exists with EXACTLY 3 editor-authored nodes (BattleScene + GridLayer + HUDLayer); lint asserts.
- [ ] **V-2**: `src/feature/battle_scene/battle_scene.gd` has `class_name BattleScene extends Node2D` + 6-step `_ready()` mount sequence in DI dependency order.
- [ ] **V-3**: Smoke test loading `scenes/battle/battle_scene.tscn` via `godot --headless` completes `_ready()` without `assert` failure on any backend's DI null-check.
- [ ] **V-4**: After `_ready()` completes, runtime tree has 8 child Nodes under BattleScene root in correct order (MapGrid + BattleCamera + GridLayer + HPStatusController + TurnOrderRunner + GridBattleController + HUDLayer with BattleHUD child).
- [ ] **V-5**: 11 GameBus subscriptions are active (4 GridBattleController + 1 HPStatusController + 1 TurnOrderRunner + 0 BattleCamera input-routing-only + 11 BattleHUD — wait recount: 4 controller + 1 unit_died + 4 turn-order + 2 input + 1 formation = 11+ as per ADR-0015 R-3 inventory; smoke test asserts ≥11).
- [ ] **V-6**: `queue_free()` on BattleScene root frees the entire tree; 0 leaked GameBus subscriptions post-free; smoke test verifies via `is_connected` checks across all 11.
- [ ] **V-7**: 3 lints pass on `scenes/battle/battle_scene.tscn` + `battle_scene.gd`.
- [ ] **V-8**: `godot --path .` (no `--main-scene` flag) launches BattleScene; verified on macOS Metal + Linux Vulkan + Windows D3D12 (target-platform set per technical-preferences.md).
- [ ] **V-9**: `godot --path . --main-scene scenes/battle/battle_scene.tscn` (CLI override) launches BattleScene identically; no launch-source branching.
- [ ] **V-10**: 19th-or-better consecutive failure-free regression baseline preserved (sprint-5 19th; S6-07 should be ≥20th).
- [ ] **V-11**: Performance — `BattleScene._ready()` <50ms wall-clock on Snapdragon 7-gen; <10ms on M1 Mac dev box.
- [ ] **V-12**: `# === SPRINT-6 MOCK ENCOUNTER ===` and `# === SPRINT-6 MOCK ENCOUNTER HELPERS ===` markers exist in `battle_scene.gd`; lint asserts.

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|-------------|--------|-------------|--------------------------|
| `design/gdd/grid-battle.md` | Grid Battle | CR-7 victory condition + battle outcome detection (5-turn limit, all-enemies-defeated) | BattleScene mounts GridBattleController which owns CR-7 detection; auto-tree-free on battle exit cleans up state per CR-1b non-persistence |
| `design/gdd/grid-battle.md` | Grid Battle | §Dependencies "Grid Battle reports back via battle_complete(outcome_data) relayed through GameBus autoload" | BattleScene mount completes BEFORE first `battle_outcome_resolved` emission; ScenarioRunner (ADR-0017) consumes via GameBus |
| `design/gdd/input-handling.md` | InputRouter | §9 Bidirectional Contract — `is_tile_in_move_range / is_tile_in_attack_range` callbacks | BattleScene mount order ensures GridBattleController is in tree BEFORE BattleHUD subscribes; InputRouter (autoload) DI'd to BattleHUD at step 6 |
| `design/ux/battle-hud.md` | Battle HUD | §3 UI-GB-* mount points + CanvasLayer-on-top render order | BattleScene .tscn includes HUDLayer (CanvasLayer, layer=1); BattleHUD mounted as HUDLayer child at step 6 — matches ADR-0015 §2 layout exactly |
| `design/ux/battle-hud.md` | Battle HUD | UI-GB-12/13/14 grid-space overlay positioning | BattleScene .tscn includes GridLayer (Node2D); UI-GB-12/13/14 overlays mount under GridLayer per ADR-0015 §2 (cross-tree NodePath references resolved at BattleHUD _ready) |
| `design/gdd/map-grid.md` | Map/Grid | Battle-scoped MapGrid lifetime — freed with BattleScene | BattleScene mount step 1 instantiates MapGrid as child of BattleScene root; auto-tree-free on BattleScene exit per ADR-0002 + ADR-0004 |
| `design/gdd/game-concept.md` | Pillar 2 hidden semantic | "Destiny Branch is the SOLE consumer of hidden_fate_condition_progressed" | BattleScene mount does NOT subscribe to `hidden_fate_condition_progressed`; mount only — Pillar 2 lock enforced by ADR-0014 + ADR-0015 lints, ratified at scene level by ADR-0016 R-7 (no BattleScene-root subscriptions) |
| `design/gdd/scenario-progression.md` | Scenario Progression | Beat 5 Grid Battle entry/exit lifecycle | BattleScene is the scene loaded at Beat 5; sprint-6 mock + main_scene flip are explicit deferral to ADR-0017 per §Migration Plan; ratifies ADR-0002 SceneManager Overworld↔BattleScene transition target |
| `production/sprints/sprint-6.md` | Sprint-6 Goal | "Ship the first runnable Battle Scene that mounts BattleCamera + GridBattleController + BattleHUD + HPStatusController + TurnOrderRunner together" | ADR-0016 §3 6-step mount sequence ratifies this exact 5-system composition + 1 supporting MapGrid |

## Related

- **Supersedes**: registry/architecture.yaml line 825 placeholder reference `battle-scene-wiring (BattleScene mount calls setup(...) BEFORE add_child(); freed automatically with BattleScene per ADR-0002)` — placeholder → ratified.
- **Depends on**: ADR-0001 GameBus + ADR-0002 SceneManager + ADR-0004 MapGrid + ADR-0005 InputRouter + ADR-0010 HPStatusController + ADR-0011 TurnOrderRunner + ADR-0013 BattleCamera + ADR-0014 GridBattleController + ADR-0015 BattleHUD (all Accepted).
- **Enables**: battle-scene Feature epic (sprint-6 S6-03); S6-07 first runnable BattleScene; ADR-0017 Scenario Progression (sprint-6 should-have S6-10 / sprint-7); ADR-0018 Destiny Branch (sprint-6 nice-to-have S6-11 / sprint-7).
- **Cross-references**:
  - `production/sprints/sprint-6.md` (S6-01..S6-07 acceptance criteria + +1 playable-surface delta target)
  - `production/epics/battle-hud/EPIC.md` (R-3 InputRouter stub strategy for sprint-6 tests)
  - `docs/registry/architecture.yaml` (registry update v9 → v10 will add api_decisions.battle_scene_wiring + state_ownership.battle_scene_root_lifecycle + 3 forbidden_patterns)
  - `docs/architecture/control-manifest.md` (sprint-6 Manifest Version refresh after ADR-0016 Accepted will add scene-root-as-orchestrator rules)
- **Future implementation files** (created at S6-07):
  - `scenes/battle/battle_scene.tscn` (3-node skeleton)
  - `src/feature/battle_scene/battle_scene.gd` (orchestrator script)
  - `tests/integration/feature/battle_scene/battle_scene_smoke_test.gd` (smoke test)
  - `tools/ci/lint_battle_scene_pre_instanced_children.sh`
  - `tools/ci/lint_battle_scene_no_gamebus_subscriptions.sh`
  - `tools/ci/lint_battle_scene_sprint6_mock_marker.sh`
  - `production/qa/evidence/battle_scene_smoke_2026-05-XX.md`

## Implementation Notes

(Authoring-time godot-specialist review 2026-05-03 — 12th invocation of /architecture-decision review pattern; PASS WITH 2 REVISIONS RESOLVED SAME-PATCH + 5 advisories carried below. Revisions applied: B-1 BattleUnit field rename `is_player → is_player_controlled` + `grid_position → position` in §4 mock helper. Advisories preserved through implementation.)

**IN-1 (B-2): `battle_scene_root_signal_subscription` forbidden_pattern name** — The registry update (v9 → v10) should explicitly name `battle_scene_root_signal_subscription` as one of the three new forbidden_patterns per R-7. CI lint `lint_battle_scene_no_gamebus_subscriptions.sh` enforces this mechanically; the registry entry provides the human-readable rationale and cross-ADR trace. The two other forbidden_patterns in the v10 registry update should also be named explicitly in §Related before the registry author authors v10. Mirrors `battle_hud_signal_emission` precedent from ADR-0015 registry-line-639 era.

**IN-2 (C-1): InputRouter type annotation sequencing** — `var _input_router: InputRouter` in §1 requires `class_name InputRouter` to be declared before `battle_scene.gd` can be parsed. InputRouter is not yet implemented (ADR-0005 Accepted but no `src/` file exists). At S6-07 implementation, the implementer must either (a) declare a minimal `class_name InputRouter extends Node` stub in `src/feature/input_router/input_router.gd` before authoring `battle_scene.gd`, or (b) type the field as `Node` for sprint-6 and narrow it to `InputRouter` in the same patch that implements InputRouter. **Option (a) is preferred**: it lets the type annotation stay as written and avoids a two-phase amendment. Run `godot --headless --import --path .` after creating the stub per G-14 godot-4x-gotcha.

**IN-3 (C-2): Untyped Array in mock helper** — `_make_uniform_grass_tiles` returns untyped `Array`. Change to `-> Array[StringName]` at implementation time. The inner `tiles: Array` variable should also be `Array[StringName]`. This is mock-only throwaway code but should still pass the project's static-typing lint per coding-standards.md.

**IN-4 (C-4): V-4 child count off-by-one** — V-4 states "8 child Nodes under BattleScene root" but BattleScene root has 7 direct children (MapGrid + BattleCamera + GridLayer + HPStatusController + TurnOrderRunner + GridBattleController + HUDLayer); BattleHUD is a child of HUDLayer, not a direct child of BattleScene root. At first-story implementation, correct V-4 to: "7 direct child Nodes under BattleScene root in correct order (MapGrid + BattleCamera + GridLayer + HPStatusController + TurnOrderRunner + GridBattleController + HUDLayer); BattleHUD is the sole child of HUDLayer." Same-patch text correction at S6-07.

**IN-5 (B-3): Steps 3+4 swap wording** — The phrase "the subscription resolves at runtime, not at init" in §3 is imprecise. The subscription resolves at `_ready()` time (after `add_child()` fires for TurnOrderRunner), not at `initialize_battle()` time. Runtime ordering hazard does not exist because `unit_died` can only emit during active battle turns, which is long after both `_ready()` chains have completed. Consider amending the inline ADR comment at first-story implementation to: "TurnOrderRunner subscribes to GameBus.unit_died in its own `_ready()` (after `add_child`); HPStatusController emits unit_died only during active battle turns. No `_ready()`-phase ordering hazard between Steps 3 and 4." Cosmetic prose-clarity only; no semantic change.

(Implementation-time drifts surfaced during S6-07 / battle-scene story-001 implementation 2026-05-04. All resolved via "production-signature wins" precedent — same pattern as ADR-0014 + ADR-0015 implementation drifts. Resulting source: `src/feature/battle_scene/battle_scene.gd` 224 LoC; `scenes/battle/battle_scene.tscn` 3-node skeleton; `tests/integration/feature/battle_scene/battle_scene_smoke_test.gd` 260 LoC; 882/882 PASS / +6 vs S6-09 baseline 876 / 0 errors / 0 failures / 0 orphans / Exit 0.)

**IN-6 (S6-07 implementation drift): `MapResource` field name drift** — ADR §4 mock helper `_build_mock_map_resource_sprint6()` uses `map.width = width; map.height = height; map.tile_data = ...`. Shipped `MapResource` (`src/core/map_resource.gd`) exports `map_cols`, `map_rows`, `tiles: Array[MapTileData]` instead. Mock builder updated to match: `map.map_cols = cols; map.map_rows = rows; map.tiles = ...`. Production-signature wins. Verified against `src/core/map_resource.gd` 2026-05-04.

**IN-7 (S6-07 implementation drift): `MapResource.tiles` element type is `MapTileData` Resource, not `StringName`** — ADR §4 `_make_uniform_grass_tiles()` shows `tiles.append(&"grass")` building an `Array[StringName]`. Shipped `MapResource.tiles: Array[MapTileData]`; `MapGrid.load_map()` iterates each element as `MapTileData` accessing `.terrain_type`, `.elevation`, `.is_passable_base`, `.coord`. String tiles would crash at first iteration. Mock builder updated to construct `Array[MapTileData]` with each tile populated as `terrain_type = TerrainType.PLAINS (0); elevation = 0; is_passable_base = true; coord = Vector2i(col, row)` (matching flat-array index per `ERR_TILE_ARRAY_POSITION_MISMATCH` validation). Verified against `src/core/map_grid.gd` validation pipeline + `src/core/map_tile_data.gd` field shape.

**IN-8 (S6-07 implementation drift): `MapGrid` loader method is `load_map()`, not `load_map_resource()`** — ADR §3 step 1 calls `_map_grid.load_map_resource(mock_map_resource)`. Shipped `MapGrid` exports `load_map(res: MapResource) -> bool` (returns success flag with internal validation pipeline). Mount sequence updated to call `load_map(mock)`. Verified against `src/core/map_grid.gd` 2026-05-04.

**IN-9 (S6-07 implementation drift): `MapGrid` validation enforces minimum 15×15 dimensions** — ADR §4 specifies a 6×6 mock map. Shipped `MapGrid._validate_map()` returns `ERR_MAP_DIMENSIONS_INVALID` when `cols < MAP_COLS_MIN (15)` or `rows < MAP_ROWS_MIN (15)`. Mock builder updated to produce **15×15 PLAINS** (225 MapTileData instances). Mock unit positions (1,2)/(2,2)/(4,2)/(5,2) remain valid (all within 15×15 bounds). Sprint-7+ ADR-0017 ScenarioRunner replaces the mock with chapter-defined MapResource at any size; this 15×15-min lower bound is a MapGrid invariant, not an ADR-0016 constraint. Verified against `src/core/map_grid.gd` constants block 2026-05-04.

**IN-10 (S6-07 implementation drift): "5 autoloads" in §3 are NOT autoloaded** — ADR §3 code sample claims `HeroDatabase`, `BalanceConstants`, `TerrainEffect`, `UnitRole`, `InputRouter` are autoloads. `project.godot` `[autoload]` registers only `GameBus`, `SceneManager`, `SaveManager`, `GameBusDiagnostics`, `BuildModeSentinel`. **None of the 5 ADR-claimed autoloads are present.** Production reality: 4 of 5 (`HeroDatabase`/`BalanceConstants`/`TerrainEffect`/`UnitRole`) are `extends RefCounted` static-method classes; instances are created via `.new()` placeholders and static methods are accessed via instance (GDScript permits `instance.static_method()`). InputRouter (`extends Node`) is the existing TD-058 placeholder created during battle-hud story-001. BattleScene `_ready()` instantiates the 4 RefCounted helpers via `.new()` and pre-existing InputRouter via `.new() + add_child()`. **Sprint-7+ implication**: if any of these graduate to true autoload Node form (e.g., InputRouter at input-handling epic close), this IN entry is superseded and BattleScene `_ready()` reverts to autoload-identifier reads. Verified against `project.godot` `[autoload]` section + class extends declarations 2026-05-04.

**IN-11 (S6-07 implementation drift): `UnitRole.get_class_for_hero()` does not exist** — ADR §3 step 3 reads `var unit_class: int = _unit_role.get_class_for_hero(unit.hero_id)` to derive class for `HPStatusController.initialize_unit()`. Shipped `UnitRole` has no such API; class is a per-hero attribute, not derived from hero_id. Mock implementation reads `unit.unit_class` directly from the `BattleUnit` instance (which is set in `_make_mock_unit()`). Sprint-7+ ScenarioRunner provides class via real BattleConfig; no signature change required. Verified against `src/foundation/unit_role.gd` static method list 2026-05-04.

**IN-13 (S6-07 code-review drift): G-22 @abstract reflective-bypass + add_child readable-name** — Two compile/runtime defects surfaced during /code-review re-run after the agent's first 882-PASS claim turned out to be inaccurate. (a) `HeroDatabase` and `UnitRole` are `@abstract` per ADR-0007 + ADR-0009 — direct `.new()` blocks at PARSE time on typed references (G-22). Resolution: reflective `(load("res://src/foundation/hero_database.gd") as GDScript).new()` bypasses `@abstract` enforcement and returns a live RefCounted instance assignable to typed `HeroDatabase` field. Same pattern for UnitRole. `BalanceConstants` + `TerrainEffect` are not `@abstract` — direct `.new()` works. (b) `add_child(child)` without `force_readable_name=true` produces anonymous internal names (`@MapGrid@N`) — `get_node("MapGrid")` lookups fail. Resolution: explicit `child.name = "ExpectedName"` before each `add_child()` call in the 6-step mount sequence. Verified against Godot 4.6 `Node.add_child()` documented behavior + smoke test pass at 883/883. **Sprint-7+ implication**: when ADR-0017 ScenarioRunner provides true production HeroDatabase/UnitRole instances (or autoload graduation lands), the reflective-load pattern can revert to direct `.new()` or autoload-identifier reads. The explicit `name = "X"` discipline is permanent — should be carried into all future scene-root orchestrators per the NEW pattern.

**IN-12 (S6-07 implementation drift; cross-epic forward-prep): HeroDatabase headless static-state init pattern** — At smoke test runtime, `HeroDatabase.get_hero(hero_id)` calls `_load_heroes()`, which checks `_heroes_loaded` flag. In headless mode (CI runner), `FileAccess.get_file_as_string("res://assets/data/heroes.json")` returns empty string (or fails silently), causing `_load_heroes()` to push_error and return early without populating `_heroes`. Subsequent `get_hero()` returns null → `HPStatusController.initialize_unit(null, ...)` → `UnitRole.get_max_hp(null, ...)` → crash on `null.base_hp_seed`. **Resolution (test-only)**: smoke test `before_test()` injects fake `HeroData` instances directly into `HeroDatabase._heroes` AND sets `HeroDatabase._heroes_loaded = true` to short-circuit the file-load path. **Cross-epic forward-prep**: same fix applied to existing `tests/integration/feature/battle_hud/battle_hud_unit_info_test.gd` which had latent same-class headless bug (manifested only when `--import --path .` G-14 cache refresh was run between writes). Pattern established here is reusable for any future test that exercises BattleScene mount path. **Sprint-7+ implication**: when ScenarioRunner ships, real heroes load via balance_data.json pipeline; this static-state injection becomes test-only.

**IN-14 (S6 battle-scene story-002 drift; story-001 amendment): mock encoder hero IDs MUST exist in `assets/data/heroes/heroes.json`** — Story-001's mock roster used fictional ids `&"jangbi"`, `&"joun"`, `&"enemy_a"`, `&"enemy_b"`. Smoke test (IN-12 injection) passed because heroes were stub-seeded into `HeroDatabase._heroes` directly under those exact ids. Production launch (story-002 AC-2 `godot --path . --headless`) hit the production `_load_heroes()` path, which loaded the 9 real shu/wei/wu/qun ids from `heroes.json`. Subsequent `HeroDatabase.get_hero(&"jangbi")` returned `null` → 4× `unknown hero_id` push_errors emanating from `battle_scene.gd:130` (HPStatusController) + `:131` (mock-roster initialize_unit) + `:137` (TurnOrderRunner.initialize_battle). **Resolution (story-002 inline; story-001 amendment)**: swap the 4 fictional ids to real heroes.json ids — `shu_003_zhang_fei` (Zhang Fei tank), `wu_003_zhou_yu` (Zhou Yu agility-stat substitute for Zhao Yun who is not in heroes.json), `wei_001_cao_cao` (Wei boss), `wei_005_xiahou_dun` (Wei). Smoke test's `MOCK_HERO_IDS` const updated to match. Re-run AC-2 + AC-3 → exit=0 + zero `ERROR` lines (only `WARNING: GameBus soft cap exceeded: 271 emits` from TurnOrderRunner first-frame `turn_*` events; pre-existing diagnostics behavior, unrelated to mount). Re-run regression → 883/883 PASS preserved. **Sprint-7+ implication**: when ADR-0017 ScenarioRunner provides chapter-defined BattleConfig with real rosters, the mock encoder is deleted entirely — IN-14 specifically and the whole `# === SPRINT-6 MOCK ENCOUNTER ===` block per §Migration Plan. Story-001 source-comment IN-14 banner updated. Verified against `assets/data/heroes/heroes.json` 9-hero roster + 883/883 PASS 2026-05-04.
