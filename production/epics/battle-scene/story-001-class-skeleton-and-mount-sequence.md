# Story 001: BattleScene Class Skeleton + 3-Node `.tscn` + 6-Step `_ready()` Mount Sequence + Sprint-6 Mock Encoder

> **Epic**: Battle Scene
> **Status**: Complete
> **Layer**: Feature (scene-root)
> **Type**: Integration
> **Manifest Version**: 2026-04-20
> **Sprint**: S6-07 (sprint-6 +1 playable-surface delta target)
> **Completed**: 2026-05-04

## Context

**GDD**: None — architecture-only epic (ADR-0016 is source-of-truth, same precedent as `camera/` epic)
**Requirement**: `TR-battle-scene-wiring-001`, `TR-battle-scene-wiring-002`, `TR-battle-scene-wiring-003`, `TR-battle-scene-wiring-004`, `TR-battle-scene-wiring-006`, `TR-battle-scene-wiring-007`, `TR-battle-scene-wiring-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0016 Battle Scene Wiring (Accepted 2026-05-03)
**ADR Decision Summary**: NEW pattern: scene-root-as-orchestrator. `class_name BattleScene extends Node2D` mounted as root of `scenes/battle/battle_scene.tscn`. 3-node `.tscn` skeleton (BattleScene + GridLayer + HUDLayer; NO pre-instanced children); code-driven 6-step `_ready()` mount sequence (MapGrid → BattleCamera → HPStatusController → TurnOrderRunner → GridBattleController → BattleHUD); sprint-6 inline mock encoder helpers between explicit comment markers; NO `_exit_tree()` body (auto-tree-free + each child's R-N `_exit_tree()` mandate handles teardown); non-emitter + non-subscriber discipline (zero GameBus subscriptions on BattleScene root).

**Engine**: Godot 4.6 | **Risk**: LOW (zero new post-cutoff API surface; HIGH-risk surface owned transitively by ADR-0015 BattleHUD child, NOT re-asserted at BattleScene level)
**Engine Notes**:
- Uses only stable Godot APIs: `Node` lifecycle (`_ready`, `_exit_tree` from 4.0), `Node.add_child(child)` (4.0), `PackedScene.instantiate()` (4.0; replaces 4.0-era `instance()`), `CanvasLayer.layer: int` property (4.0), `class_name X extends Node2D` declaration (4.0).
- HIGH-risk surface (4.6 dual-focus, 4.5 AccessKit, 4.5 recursive Control disable) is **inherited transitively** through the BattleHUD child but is NOT re-asserted at BattleScene level — ADR-0015's verification items remain authoritative for that subtree.
- Field name verification (per godot-specialist Pass B-1, 2026-05-03): `BattleUnit.is_player_controlled` (NOT `is_player`) and `BattleUnit.position` (NOT `grid_position`) — verified against shipped `src/core/battle_unit.gd`. Mock encoder helpers MUST match these field names.

**Control Manifest Rules (Feature layer + scene-root)**:
- Required: setup-before-`add_child()` mandate from 5 prior ADRs (R-N requirement) — orchestrator script honors this for every child mount step.
- Forbidden (registry, registered same-patch with ADR-0016): `battle_scene_pre_instanced_children` (`.tscn` MUST contain EXACTLY 3 nodes); `battle_scene_root_signal_subscription` (zero `GameBus.*.connect` / `GameBus.*.emit`); `battle_scene_sprint6_mock_marker_must_exist` (markers MUST exist in source — semantic flips at ADR-0017 acceptance).
- Guardrail: `BattleScene._ready()` <50ms wall-clock on Snapdragon 7-gen reference hardware (within ADR-0002's 2000ms BattleScene load budget). `_process` / `_physics_process` = 0ms (no body). RAM footprint <100KB orchestration overhead only.

---

## Acceptance Criteria

*From ADR-0016 §1, §2, §3, §4, §7 + R-1 / R-2 / R-3 / R-4 / R-6 / R-7 / R-9, scoped to skeleton + mount + mock:*

- [ ] **AC-1**: `src/feature/battle_scene/battle_scene.gd` exists with `class_name BattleScene extends Node2D`. (TR-001)
- [ ] **AC-2**: `scenes/battle/battle_scene.tscn` exists as a 3-node skeleton: `BattleScene` (Node2D, root) + `GridLayer` (Node2D, child) + `HUDLayer` (CanvasLayer, child, `layer=1`). NO other children pre-instanced. (TR-002)
- [ ] **AC-3**: `_ready()` resolves 5 autoload backends (`HeroDatabase`, `BalanceConstants`, `TerrainEffect`, `UnitRole`, `InputRouter`) into typed private fields BEFORE child instantiation. (TR-003)
- [ ] **AC-4**: `_ready()` executes the 6-step mount sequence in order: (1) `MapGrid.new()` + `load_map_resource(mock_map_resource)` + `add_child`; (2) `BattleCamera.new()` + `setup(_map_grid)` + `add_child`; (3) `HPStatusController.new()` + per-unit `initialize_unit(unit_id, hero, unit_class)` loop + `add_child`; (4) `TurnOrderRunner.new()` + `initialize_battle(roster)` + `add_child`; (5) `GridBattleController.new()` + 8-param `setup(...)` + `add_child`; (6) `BattleHUD.new()` + 9-param `setup(...)` + `_hud_layer.add_child(hud)`. (TR-003)
- [ ] **AC-5**: Sprint-6 inline mock encoder lives between explicit comment markers `# === SPRINT-6 MOCK ENCOUNTER ===` / `# === END MOCK ===` in `_ready()` and `# === SPRINT-6 MOCK ENCOUNTER HELPERS ===` / `# === END SPRINT-6 MOCK ENCOUNTER HELPERS ===` for the 4 helpers. Roster = 4 BattleUnit instances (`jangbi` tank + `joun` assassin player-controlled at (1,2) + (2,2); `enemy_a` + `enemy_b` enemy at (4,2) + (5,2)) on a 6×6 all-grass `MapResource`. Helper field assignments use `is_player_controlled` and `position` (NOT `is_player` / `grid_position`). (TR-004)
- [ ] **AC-6**: `BattleScene` has NO `_exit_tree()` body (the function may be declared with empty body OR omitted entirely). After `queue_free()`, reverse-DFS auto-tree-free fires `_exit_tree()` on each of the 6 mounted children in reverse-add order, cleanly disconnecting all GameBus subscriptions via existing per-ADR mandates. (TR-006)
- [ ] **AC-7**: `BattleScene` source contains zero `GameBus.*.connect` and zero `GameBus.*.emit` substrings (non-emitter + non-subscriber discipline; story-003 lint enforces). (TR-007)
- [ ] **AC-8**: Integration smoke test at `tests/integration/feature/battle_scene/battle_scene_smoke_test.gd` instantiates `BattleScene` via `PackedScene.instantiate()`, asserts 6 children mount (1 BattleHUD under HUDLayer; 5 siblings under root: MapGrid + BattleCamera + HPStatusController + TurnOrderRunner + GridBattleController; plus the 2 layer Nodes pre-existing in skeleton), and asserts `_ready()` completes with 0 errors / 0 orphans. (TR-003 + TR-009)
- [ ] **AC-9**: `BattleScene._ready()` completes <50ms wall-clock on the test runner (advisory perf assertion; CI gate set permissive ×3-5 over headline per camera/grid-battle-controller precedent). (TR-009)

---

## Implementation Notes

*Derived from ADR-0016 §1, §2, §3, §4, §6, §7 + Implementation Guidelines:*

1. **NEW pattern: scene-root-as-orchestrator**. `BattleScene` IS the scene root, NOT a child of one. Lifecycle owned by ADR-0002 SceneManager (parent ↔ child relationship) OR by Godot's `main_scene` config (sprint-6 standalone launch — story-002). NO `setup()` method on `BattleScene` itself: Godot's `PackedScene.instantiate()` and `main_scene` config don't pass constructor parameters. All DI happens INSIDE `_ready()` by reading autoloads.

2. **Field declarations**:
   ```gdscript
   @onready var _grid_layer: Node2D = $GridLayer
   @onready var _hud_layer: CanvasLayer = $HUDLayer

   # 5 autoload backends — populated in _ready() before child instantiation
   var _hero_db: HeroDatabase
   var _balance_constants: BalanceConstants
   var _terrain_effect: TerrainEffect
   var _unit_role: UnitRole
   var _input_router: InputRouter

   # 6 battle-scoped child Node references — populated during _ready() mount
   var _map_grid: MapGrid
   var _battle_camera: BattleCamera
   var _hp_controller: HPStatusController
   var _turn_runner: TurnOrderRunner
   var _grid_controller: GridBattleController
   var _battle_hud: BattleHUD
   ```

3. **Mount sequence ordering is FORCED, not chosen** — 6! = 720 permutations; only 1 satisfies all DI constraints. Step 1 (MapGrid) must precede Step 2 (Camera DI's MapGrid). Steps 3+4 could swap structurally but conventional order keeps "state owners" before "state listeners". Step 5 (GridBattleController) must follow steps 1-4 (8-param setup includes 4 of them). Step 6 (BattleHUD) must follow all (9-param setup includes grid_controller).

4. **setup-before-`add_child()` mandate** for every child: call `setup(...)` (or per-unit `initialize_unit()` loop for HP/Status, or `initialize_battle()` for Turn Order) BEFORE `add_child(child)`. The 5 prior ADRs (0010/0011/0013/0014/0015) all require this as their R-N requirement; child `_ready()` fires AT `add_child()` time and asserts DI fields non-null.

5. **Mock encoder field names** (per godot-specialist Pass B-1 verification 2026-05-03): use `unit.is_player_controlled = true/false` (NOT `is_player`) and `unit.position = Vector2i(x, y)` (NOT `grid_position`). These were the exact sites that would have rejected if hand-written; verified against shipped `src/core/battle_unit.gd`.

6. **Mock map builder** uses `.new() + .property = X` direct assignment, NOT `.tres` round-trip, per ADR-0016 §4 — bypasses MapResource `@export` deserialization risk for sprint-6 throwaway path. The 6×6 all-grass tiles array uses `&"grass"` StringName for each cell.

7. **Comment markers are LINT-ENFORCED** — story-003 ships the lint asserting marker presence. The semantic flips at ADR-0017 acceptance (lint changes from "marker MUST exist" to "marker MUST NOT exist"). Markers MUST be exact: `# === SPRINT-6 MOCK ENCOUNTER ===` (in `_ready()` body) + `# === END MOCK ===` + `# === SPRINT-6 MOCK ENCOUNTER HELPERS ===` (above `_build_mock_roster_sprint6`) + `# === END SPRINT-6 MOCK ENCOUNTER HELPERS ===`.

8. **NO `_exit_tree()` body**: ADR-0016 R-6 + TR-006. Auto-tree-free + each child's R-N `_exit_tree()` mandate handles teardown. The function may be declared empty OR omitted. Lint in story-003 will check that BattleScene source has zero `GameBus.*.disconnect` calls (consistent with the non-subscriber discipline).

9. **`_input_router` is read-but-not-subscribed-to** at this story — autoload reference is held only to pass into `BattleHUD.setup(...)` 9-param at step 6. BattleScene root never connects to any InputRouter signal directly.

10. **Test smoke test pattern**:
    ```gdscript
    # tests/integration/feature/battle_scene/battle_scene_smoke_test.gd
    extends GdUnitTestSuite

    func test_battle_scene_mounts_six_children() -> void:
        var packed: PackedScene = preload("res://scenes/battle/battle_scene.tscn")
        var scene: BattleScene = packed.instantiate()
        add_child(scene)  # _ready() fires; mount sequence runs
        await get_tree().process_frame  # let any deferred-connect signals settle

        # Assert 6 mounted children (excluding pre-existing GridLayer + HUDLayer)
        assert_object(scene.get_node("MapGrid")).is_not_null()
        assert_object(scene.get_node("BattleCamera")).is_not_null()
        assert_object(scene.get_node("HPStatusController")).is_not_null()
        assert_object(scene.get_node("TurnOrderRunner")).is_not_null()
        assert_object(scene.get_node("GridBattleController")).is_not_null()
        assert_object(scene.get_node("HUDLayer/BattleHUD")).is_not_null()

        # Pre-existing skeleton nodes still present
        assert_object(scene.get_node("GridLayer")).is_not_null()
        assert_object(scene.get_node("HUDLayer")).is_not_null()

        scene.queue_free()
    ```
    Test runs against the live BattleScene .tscn — no DI seam stubs; this story validates the production `_ready()` mount path end-to-end on the test runner. Use `auto_free()` for orphan-node hygiene per project test conventions.

11. **Out-of-tree call site documentation**: if any real backend (HPStatusController, TurnOrderRunner, etc.) hits an authoring-time signature drift during the smoke test (per the precedent of S6-09 finding `HeroDatabase.get_hero(StringName)` not `int`), surface to ADR-0016 §Implementation Notes as IN-N amendment rather than blocking the story. The +1 playable-surface delta is the priority; signature drifts are a 1-line story-completion-note flag.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: `project.godot` `[application] run/main_scene` flip to `res://scenes/battle/battle_scene.tscn` + 3-launch-source idempotency verification (SceneManager-driven + main_scene config + `--main-scene` CLI override) + smoke evidence doc covering 18 verification points.
- **Story 003**: 3 lint scripts (`lint_battle_scene_pre_instanced_children.sh`, `lint_battle_scene_no_gamebus_subscriptions.sh`, `lint_battle_scene_sprint6_mock_marker.sh`) + CI wiring in `.github/workflows/tests.yml` + 3 forbidden_patterns registered in `docs/registry/architecture.yaml` + epic close.
- **Cross-platform smoke** (macOS Metal + Linux Vulkan + Windows D3D12) — V-8/V-9 verification on real hardware deferred to Polish; CI runs only the test-runner-platform smoke.
- **Real chapter loader / Scenario state** — owned by ADR-0017 (sprint-7+); replaces the inline mock at acceptance.
- **Battle Results screen polish, two-tap UX timer, formation aura visuals** — owned by battle-hud epic stories 004-008.

---

## QA Test Cases

*Integration story — automated integration test required + 1 manual grep gate.*

- **AC-1: BattleScene class declaration**
  - Given: a fresh test fixture
  - When: `preload("res://src/feature/battle_scene/battle_scene.gd")` loads + `.new()` instantiates
  - Then: instance `is BattleScene` AND `is Node2D`; `class_name` resolves to `BattleScene`
  - Edge cases: confirm `is Node` returns TRUE (Node2D extends Node); confirm script attaches cleanly to `.tscn` root

- **AC-2: `.tscn` 3-node skeleton**
  - Given: project file system
  - When: test loads `preload("res://scenes/battle/battle_scene.tscn")` and instantiates
  - Then: instantiated root `is BattleScene` (Node2D); has exactly 2 children — `GridLayer` (Node2D) + `HUDLayer` (CanvasLayer with `layer == 1`); no other pre-instanced children
  - Edge cases: scene file missing → FileAccess error; test asserts file exists explicitly first

- **AC-3: 5 autoload backends resolved in `_ready()`**
  - Given: live autoload boot order intact (GameBus + BalanceConstants + HeroDatabase + UnitRole + TerrainEffect + InputRouter all present per project.godot)
  - When: `add_child(scene)` triggers `BattleScene._ready()`
  - Then: all 5 private fields (`_hero_db`, `_balance_constants`, `_terrain_effect`, `_unit_role`, `_input_router`) are non-null and reference the correct autoload instances
  - Edge cases: this assertion is implicit if AC-4 mount sequence completes without crash (BattleHUD.setup() 9-param requires all 5 to be passed)

- **AC-4: 6-step mount sequence completes**
  - Given: BattleScene instantiated and `add_child(scene)` triggered
  - When: `_ready()` runs to completion
  - Then: `scene.get_node("MapGrid") != null`; `scene.get_node("BattleCamera") != null`; `scene.get_node("HPStatusController") != null`; `scene.get_node("TurnOrderRunner") != null`; `scene.get_node("GridBattleController") != null`; `scene.get_node("HUDLayer/BattleHUD") != null`
  - Edge cases: any signature drift on a mounted child surfaces as setup() crash → captured by smoke test fail message; resolution is ADR-0016 IN-N amendment (precedent: S6-06 / S6-09)

- **AC-5: Mock encoder marker presence + roster shape**
  - Given: source file `src/feature/battle_scene/battle_scene.gd`
  - When: test reads file via `FileAccess.open(path, READ)` + `get_as_text()`
  - Then: source contains `# === SPRINT-6 MOCK ENCOUNTER ===` AND `# === END MOCK ===` AND `# === SPRINT-6 MOCK ENCOUNTER HELPERS ===` AND `# === END SPRINT-6 MOCK ENCOUNTER HELPERS ===`. Smoke test additionally asserts mounted roster has exactly 4 BattleUnit instances at expected positions
  - Edge cases: marker substring drift (e.g., extra/missing space) → test fails with marker contents in error message

- **AC-6: No `_exit_tree()` body (auto-tree-free delegation)**
  - Given: BattleScene mounted with all 6 children
  - When: `scene.queue_free()` runs to completion across one frame
  - Then: 0 leaked GameBus subscriptions across all 6 mounted children (each child's `_exit_tree()` cleans up its own); 0 orphan nodes reported by GdUnit4 runner
  - Edge cases: if any child fails to disconnect (regression in child's `_exit_tree()`), this test catches it as orphan / leaked-connection — fix belongs in the child's epic, not BattleScene

- **AC-7: Non-subscriber + non-emitter source discipline (manual grep gate this story; story-003 automates as CI lint)**
  - Setup: open `src/feature/battle_scene/battle_scene.gd`
  - Verify: `grep -c 'GameBus\.\(.*\)\.\(connect\|emit\)' src/feature/battle_scene/battle_scene.gd` returns 0
  - Pass condition: zero matches; story-003 lint formalizes

- **AC-8: Smoke test asserts 6 mounted children + 0 errors**
  - Given: test integration suite
  - When: `tests/integration/feature/battle_scene/battle_scene_smoke_test.gd::test_battle_scene_mounts_six_children` runs
  - Then: PASS exit code; full regression baseline preserved (876+ PASS / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans)
  - Edge cases: smoke test must also `auto_free` the scene to prevent orphan accumulation across test suite

- **AC-9: `_ready()` completes <50ms wall-clock**
  - Given: BattleScene instantiated on test runner
  - When: time `_ready()` start to completion via `Time.get_ticks_msec()` delta
  - Then: delta < 250ms (CI permissive gate ×5 over the 50ms headline target — same precedent as camera/grid-battle-controller perf gates)
  - Edge cases: cold cache (first run) may hit ~200ms; warm runs <50ms target; reject only on >250ms

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- Integration: `tests/integration/feature/battle_scene/battle_scene_smoke_test.gd` — must exist and pass (covers AC-1..AC-6, AC-8, AC-9)
- Manual gate AC-7 verified at code-review time; codified as CI lint by story-003

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: ADR-0016 Accepted ✅ (2026-05-03 via `/architecture-review` delta #11) + 5 prior battle-scoped ADRs Accepted ✅ (ADR-0010 / 0011 / 0013 / 0014 / 0015) + S6-06 (battle-hud story-002 — DI test seam ✅ Complete 2026-05-03). All 6 mounted child types must have shipped production signatures verifiable via `src/core/`, `src/feature/`, `src/foundation/`. Verify at first-author time: `grep -l 'class_name MapGrid\|class_name BattleCamera\|class_name HPStatusController\|class_name TurnOrderRunner\|class_name GridBattleController\|class_name BattleHUD' src/`.
- **Unlocks**: Story 002 (main_scene flip + 3-launch-source smoke evidence — needs the working BattleScene mount path); transitively unlocks Story 003 (lints + epic terminal).

---

## Completion Notes

**Completed**: 2026-05-04
**Verdict**: COMPLETE WITH NOTES (4 advisory items; none blocking; 883/883 PASS)
**Criteria**: 9/9 passing (all AC-1..AC-9 covered by 7 integration test functions in `tests/integration/feature/battle_scene/battle_scene_smoke_test.gd`)
**Test Evidence**: Integration — `tests/integration/feature/battle_scene/battle_scene_smoke_test.gd` (260 LoC, 7 functions, all PASS; 883/883 full-suite green; 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0; +7 vs S6-09 baseline 876; **23rd consecutive failure-free regression baseline**)
**Code Review**: Complete — godot-gdscript-specialist + qa-tester spawned in parallel via `/code-review`. Initial verdict CHANGES REQUIRED (2 BLOCKING + 4 ADVISORY). 2 BLOCKING fixes shipped: (a) `battle_scene.gd:103` 6×6 → 15×15 mock map per IN-9; (b) full rewrite of smoke test to actually mount BattleScene (was misrouted GridBattleController test prior). 2 additional defects discovered during verification rerun: (c) G-22 @abstract trap on HeroDatabase + UnitRole — fixed via reflective `(load(path) as GDScript).new()` bypass per G-22 Path 2; (d) `add_child()` anonymous-name trap — fixed via explicit `child.name = "X"` discipline before each add_child in 6-step mount. ADR-0016 IN-13 appended documenting (c)+(d). Final verdict APPROVED.

**Files shipped this turn (3 NEW, 1 cross-epic forward-prep)**:
- `src/feature/battle_scene/battle_scene.gd` — 228 LoC orchestrator (NEW pattern: scene-root-as-orchestrator); 6-step DI-DAG mount with explicit `child.name` discipline; reflective `load(path).new()` for @abstract HeroDatabase + UnitRole; `.new()` for non-abstract BalanceConstants + TerrainEffect; `.new() + add_child()` for InputRouter Node; sprint-6 mock encoder helpers between explicit `# === SPRINT-6 MOCK ENCOUNTER ===` markers; NO `_exit_tree()` body per R-6; NO `GameBus.*.connect/emit` per R-7
- `scenes/battle/battle_scene.tscn` — 3-node skeleton (BattleScene Node2D + GridLayer Node2D + HUDLayer CanvasLayer at `layer = 1`)
- `tests/integration/feature/battle_scene/battle_scene_smoke_test.gd` — 260 LoC integration smoke test (7 functions covering AC-1..AC-9; HeroDatabase static-state injection in `before_test()` per IN-12)

**Cross-epic forward-prep (1, OUT OF SCOPE but accepted)**:
- `tests/integration/feature/battle_hud/battle_hud_unit_info_test.gd` — added `HeroDatabase._heroes_loaded = true` after each of 8 hero injection sites. Fixes latent headless `_load_heroes()` short-circuit bug exposed by G-14 cache-refresh during S6-07 implementation. Same pattern as battle-hud story-002's 3 cross-epic forward-prep additions (TD-060 lineage). Should be tracked as TD entry or cross-referenced from battle-hud story-003 Completion Notes.

**Deviations** (4 advisory; none blocking):
- ADVISORY A-3: IN-N numbering inconsistency between source-file header comments (IN-6=load_map, IN-7=fields, IN-8=class_for_hero, IN-9=tiles) and ADR-0016 entries (IN-6=fields, IN-7=tiles, IN-8=load_map, IN-9=15×15, IN-10=autoload, IN-11=class_for_hero, IN-12=hero_db headless, IN-13=G-22+readable-name). Cosmetic; matters for story-003 lint design.
- ADVISORY A-4: AC-4 description in this story file says `load_map_resource()` but production uses `load_map()` (per ADR-0016 IN-8 amendment). Doc drift only — implementation is correct. Fixed inline in this Completion Notes block.
- ADVISORY: ADR-0016 amended with **8 new IN-N entries** (IN-6..IN-13) per the standard "production-signature wins" precedent. 7 implementation drifts surfaced + resolved during /dev-story; 1 additional drift surfaced during /code-review verification rerun.
- OUT OF SCOPE: cross-epic battle_hud_unit_info_test.gd HeroDatabase static-state injection (8 sites). See "Cross-epic forward-prep" above.

**ADR-0016 IN-N entries appended this story** (IN-6..IN-13):
- IN-6: MapResource field rename (`map_cols`/`map_rows`/`tiles`)
- IN-7: tiles element type is MapTileData Resource not StringName
- IN-8: MapGrid loader is `load_map()` not `load_map_resource()`
- IN-9: MapGrid validation enforces 15×15 minimum (mock = 15×15 PLAINS not 6×6)
- IN-10: 5 "autoloads" not autoloaded — `.new()` placeholder pattern
- IN-11: `UnitRole.get_class_for_hero()` does not exist; mock reads `unit.unit_class` directly
- IN-12: HeroDatabase headless static-state init pattern (cross-epic test fix)
- IN-13: G-22 @abstract reflective-bypass + `add_child()` readable-name discipline (added during /code-review)

**Sprint-6 progress**: 9/12 done = **75%** at this story's close. **+1 playable-surface delta target HIT** — first runnable BattleScene mounts 6 children end-to-end without crash. story-002 (project.godot main_scene flip + cross-launch-source smoke evidence) + story-003 (lints + epic terminal) still pending (~3h combined; nice-to-have for sprint-6 close).

**Cycle lesson logged**: agent's first dev-story cycle reported "882 PASS" inaccurately (production code never actually parsed due to class-identifier-vs-typed-instance-field mismatch). Orchestrator MUST verify by running tests directly when an agent reports pass after multiple context-drift cycles. Codified in active.md for future dev-story sessions.
