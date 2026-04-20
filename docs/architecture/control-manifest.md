# Control Manifest

> **Engine**: Godot 4.6
> **Last Updated**: 2026-04-20
> **Manifest Version**: 2026-04-20
> **ADRs Covered**: ADR-0001, ADR-0002, ADR-0003, ADR-0004 (all Accepted Foundation-layer)
> **Status**: Active — regenerate with `/create-control-manifest update` when ADRs change

`Manifest Version` is the date this manifest was generated. Story files embed
this date when created. `/story-readiness` compares a story's embedded version
to this field to detect stories written against stale rules.

This manifest is a programmer's quick-reference extracted from all Accepted ADRs,
technical preferences, and engine reference docs. For the reasoning behind each
rule, see the referenced ADR.

---

## Foundation Layer Rules

*Applies to: GameBus signal architecture, scene management, save/load, map data model, engine initialisation, autoload contracts*

### Required Patterns

**GameBus (ADR-0001)**
- **All cross-system signals declared on `/root/GameBus` autoload** — single grep-able file — source: ADR-0001
- **GameBus holds ZERO game state; pure signal relay only** — no `var`, no `func`, only signal declarations + doc comments — source: ADR-0001
- **Signal naming: `{domain}_{event}_{past_tense}`** (e.g. `battle_outcome_resolved`, `chapter_started`, `unit_turn_ended`) — source: ADR-0001
- **Payload typing rule**: ≥2 fields → typed `Resource` class in `src/core/payloads/`; 1 primitive field → typed primitive directly in signature; 0 fields → mandatory `String reason` for log traceability — source: ADR-0001 (TR-gamebus-001)
- **Every payload `Resource` class round-trips via `ResourceSaver.save` → `ResourceLoader.load`** with identical data (test: `tests/unit/core/payload_serialization_test.gd`) — source: ADR-0001
- **`CONNECT_DEFERRED` mandatory for cross-scene connects** — source: ADR-0001
- **Every `connect(...)` in `_ready` has matching `disconnect(...)` in `_exit_tree` guarded by `is_connected`** — source: ADR-0001
- **Every signal handler guards `Resource` payloads with `is_instance_valid`** — source: ADR-0001
- **Autoload order in `project.godot`**: `GameBus="*res://src/core/game_bus.gd"` first, then `SceneManager`, then `SaveManager` — source: ADR-0001 + ADR-0002 + ADR-0003
- **GameBus stub injectable via `before_test`/`after_test`** in GdUnit4 — source: ADR-0001

**SceneManager (ADR-0002)**
- **SceneManager autoload at `/root/SceneManager`, load order 2 (after GameBus)** — source: ADR-0002 (TR-scene-manager-001)
- **5-state machine**: IDLE, LOADING_BATTLE, IN_BATTLE, RETURNING_FROM_BATTLE, ERROR — source: ADR-0002
- **Overworld retained during battle (never freed)**: `process_mode = PROCESS_MODE_DISABLED` + `visible = false` + `set_process_input(false)` + root Control recursive `mouse_filter = MOUSE_FILTER_IGNORE` — source: ADR-0002 (TR-scene-manager-002)
- **BattleScene instantiated as `/root` peer** via `ResourceLoader.load_threaded_request(path, "PackedScene", true)` — source: ADR-0002 (TR-scene-manager-003)
- **Load status polled via Timer node at 100 ms cadence** — never per-frame — source: ADR-0002
- **On `battle_outcome_resolved`, BattleScene freed via `call_deferred("_free_battle_scene_and_restore_overworld")`** — defers free one additional frame to preserve co-subscriber node refs — source: ADR-0002 (TR-scene-manager-004)
- **On async-load failure: emit `scene_transition_failed(context, reason)` via GameBus + transition to ERROR; recovery only via re-emit of `battle_launch_requested`** — source: ADR-0002 (TR-scene-manager-005)
- **SceneManager holds ZERO gameplay state** — pure transition lifecycle — source: ADR-0002

**SaveManager (ADR-0003)**
- **SaveManager autoload at `/root/SaveManager`, load order 3 (after GameBus + SceneManager)** — source: ADR-0003 (TR-save-load-001)
- **All SaveContext fields annotated `@export`; EchoMark `extends Resource` + `class_name EchoMark` + full `@export` coverage** — non-@export fields silently dropped by ResourceSaver — source: ADR-0003 (TR-save-load-002)
- **Save write pipeline**: `duplicate_deep(DUPLICATE_DEEP_ALL_BUT_SCRIPTS)` → `ResourceSaver.save(tmp_path)` → `DirAccess.rename_absolute(tmp_path, final_path)` (atomic) — source: ADR-0003 (TR-save-load-003)
- **All save loads use `ResourceLoader.load(path, "", CACHE_MODE_IGNORE)`** — cached loads return stale post-overwrite objects — source: ADR-0003 (TR-save-load-004)
- **Save root is `user://saves` ONLY** — no SAF / external-storage paths (atomicity not guaranteed on Android SAF) — source: ADR-0003 (TR-save-load-006)
- **Migration Callables in `SaveMigrationRegistry` are pure functions** — no captured node/singleton/object refs (leak for registry lifetime) — source: ADR-0003 (TR-save-load-007)
- **3 save slots from MVP**; slots independent under `user://saves/slot_{1,2,3}/ch_{MM}_cp_{N}.res` — source: ADR-0003
- **3-CP-per-chapter checkpoint policy**: CP-1 Beat 1 entry, CP-2 post-Beat 7 (on SceneManager RETURNING_FROM_BATTLE → IDLE boundary via `battle_outcome_resolved`), CP-3 next-chapter Beat 1 entry — source: ADR-0003
- **`BattleOutcome.Result` enum is append-only**; reorder requires migration registry entry + `schema_version` bump — source: ADR-0003 (TR-save-load-005)
- **Every schema change bumps `CURRENT_SCHEMA_VERSION`** + adds migration function in `SaveMigrationRegistry._migrations` — source: ADR-0003

**Map/Grid (ADR-0004)**
- **MapGrid is a plain `Node` (not `Node2D`, not autoload); battle-scoped as BattleScene child** — freed with BattleScene; zero cross-battle state — source: ADR-0004 (TR-map-grid-007)
- **Tile storage: flat `Array[TileData]` inside `MapResource`**; indexing `tiles[coord.y * map_cols + coord.x]` — source: ADR-0004 (TR-map-grid-001)
- **Authoritative source-of-truth is `Array[TileData]`**; packed caches (6 parallel `PackedInt32Array` / `PackedByteArray`) are built at `load_map()` after `duplicate_deep()` — source: ADR-0004
- **Every mutation writes through to both `Array[TileData]` AND matching packed cache in the same call** — R-4 correctness hazard — source: ADR-0004 (TR-map-grid-004)
- **9 public read-only query methods**: `get_tile`, `get_movement_range`, `get_path`, `get_attack_range`, `get_attack_direction`, `get_adjacent_units`, `get_occupied_tiles`, `has_line_of_sight`, `get_map_dimensions` — source: ADR-0004 (TR-map-grid-003)
- **Mutation API (`set_occupant`, `clear_occupant`, `apply_tile_damage`) called only by `GridBattleController`** by convention — enforced in code review — source: ADR-0004 (TR-map-grid-004)
- **MapGrid emits exactly one GameBus signal: `tile_destroyed(coord: Vector2i)`** — single-primitive payload per TR-gamebus-001 canonical form — source: ADR-0004 (TR-map-grid-005)
- **Map loading via `ResourceLoader.load(path, "", CACHE_MODE_IGNORE)`** — mirrors ADR-0003 pattern — source: ADR-0004 (TR-map-grid-009)
- **TileData MUST remain inline inside `MapResource.tres`** — no external UID references (R-3 hard constraint: `duplicate_deep()` returns shared instance for UID-referenced sub-resources, leaks destruction state between maps) — source: ADR-0004 (TR-map-grid-010)
- **Map authoring format**: `.tres` at `res://data/maps/[map_id].tres`, edited via Godot inspector; shipped builds use binary `.res` via export pipeline — source: ADR-0004

### Forbidden Approaches

**GameBus (ADR-0001)**
- **Never emit signals from `_process(delta)` or `_physics_process(delta)`** — per-frame ban violates 16.6 ms budget; creates physics→idle ordering hazards — source: ADR-0001
- **Never emit high-frequency inputs (mouse motion, touch drag) through GameBus from `_input(event)`** — use InputRouter batching — source: ADR-0001
- **Never declare `var` or `func` in `game_bus.gd` beyond signal declarations + doc comments** — CI-lint-enforced pure-relay — source: ADR-0001
- **Never use untyped `Dictionary`, `Array`, or `Variant` for signal payloads** — breaks static typing, IDE autocomplete, Save/Load round-trip — source: ADR-0001
- **Never use per-domain autoload buses** (Alt 1 rejected) — breaks grep-ability; banner comments within one file are sufficient — source: ADR-0001
- **Never use parent-node signal chains without autoload** (Alt 2 rejected) — breaks scene-boundary survival — source: ADR-0001
- **Never adopt third-party EventBus addons** (Alt 3 rejected) — MVP scale unjustified; approved libraries list is currently empty — source: ADR-0001
- **Never use `get_tree().get_root().get_node(...)` for cross-scene signal dispatch** (Alt 4 rejected) — scene destruction silently invalidates cached refs — source: ADR-0001

**SceneManager (ADR-0002)**
- **Never nest BattleScene as Overworld's child** (Alt 1 rejected) — couples lifecycles; retry loop re-parenting overhead — source: ADR-0002
- **Never use `SceneTree.change_scene_to_packed` for Overworld ↔ BattleScene** (Alt 2 rejected) — destroys ScenarioRunner state; Echo retry loop requires Overworld retention — source: ADR-0002
- **Never preload all BattleScenes at scenario-select** (Alt 3 rejected) — 5 × ~80 MB = 400 MB blows 512 MB ceiling — source: ADR-0002
- **Never use synchronous `PackedScene.instantiate()` with cross-fade** (Alt 4 rejected) — 500 ms frame spike on mid-range Android — source: ADR-0002
- **Never reorder autoloads** without recognizing `GameBus` must be first — null-reference crashes in other autoloads' `_ready` — source: ADR-0001 + ADR-0002
- **Never add gameplay state to SceneManager** — pure transition lifecycle only — source: ADR-0002

**SaveManager (ADR-0003)**
- **Never use JSON via FileAccess for save persistence** (Alt 1 rejected) — manual type coercion for `StringName`, `Array[EchoMark]` — source: ADR-0003
- **Never use SQLite via GDExtension for saves** (Alt 2 rejected) — overkill for <50 KB payloads — source: ADR-0003
- **Never ship with a single save slot** (Alt 3 rejected) — mobile devices commonly shared; 1-slot is hostile — source: ADR-0003
- **Never skip schema versioning** (Alt 4 rejected) — retrofitting versioning into v1 saves is fragile — source: ADR-0003
- **Never write saves to SAF / external-storage paths** — `DirAccess.rename_absolute()` atomicity NOT guaranteed — source: ADR-0003
- **Never load saves without `CACHE_MODE_IGNORE`** — cached loads return stale post-overwrite objects — source: ADR-0003
- **Never capture node/singleton/object refs inside migration Callables** — held for registry lifetime; leaks refs into freed scenes — source: ADR-0003
- **Never reorder `BattleOutcome.Result` enum values** without migration function + `schema_version` bump — integer serialization contract — source: ADR-0003

**Map/Grid (ADR-0004)**
- **Never use `TileMapLayer` + parallel `Array[TileData]` overlay** (Alt 1 rejected) — dual source-of-truth sync cost; atlas workflow unidiomatic for ink-wash aesthetic — source: ADR-0004
- **Never use pure Struct-of-Arrays (`PackedInt32Array`-only) as primary tile storage** (Alt 2 rejected) — violates `@export` / `.tres` authoring + ADR-0003 typed-Resource convention — source: ADR-0004
- **Never create an autoload `/root/MapGrid`** (Alt 3 rejected) — violates ADR-0002 battle-scoped lifecycle — source: ADR-0004
- **Never use Resource-only MapGrid (no wrapping Node)** (Alt 4 rejected) — cannot `emit_signal` from Resource without Node host — source: ADR-0004
- **Never use `AStarGrid2D` or `NavigationServer2D` for grid pathfinding** — per-unit-type × per-terrain-type cost matrix incompatible with `set_point_weight_scale` per-cell scalar model — source: ADR-0004 (CR-6) (TR-map-grid-002)
- **Never reference shared TileData presets by UID** from `MapResource.tres` — `duplicate_deep()` returns shared instance; destruction state leaks between maps — source: ADR-0004 (R-3 hard constraint)
- **Never dereference TileData objects in the Dijkstra hot loop** — pay virtual-dispatch cost ~1200× per query; use packed caches — source: ADR-0004
- **Never call `MapGrid.get_unit_at(coord)`** — that API does not exist; Formation Bonus + other consumers must self-cache `coord_to_unit_id: Dictionary[Vector2i, int]` from `units: Array[UnitState]` at `round_started` — source: `design/gdd/map-grid.md` §Dependencies v1.1 + `design/gdd/formation-bonus.md` F-FB-1

### Performance Guardrails

| System | Metric | Budget | Source |
|--------|--------|--------|--------|
| GameBus dispatch | CPU per emit | <0.05 ms on Snapdragon 7-gen | ADR-0001 |
| GameBus total | CPU per frame | <0.5 ms (1/30th of 16.6 ms) | ADR-0001 |
| GameBus soft cap | Emits per frame | 50 (push_warning on exceed) | ADR-0001 |
| GameBus memory | Node + signal tables | <0.05 MB | ADR-0001 |
| SceneManager IDLE | CPU per frame | 0 ms | ADR-0002 |
| SceneManager LOADING | CPU per tick | <0.05 ms × 10 ticks/sec = 0.5 ms/sec | ADR-0002 |
| Overworld retained | Memory | ~50 MB | ADR-0002 |
| BattleScene peak | Memory | ~80 MB | ADR-0002 |
| Combined peak | Memory | ~230 MB (45% of 512 MB; 280 MB headroom) | ADR-0002 |
| BattleScene load | Async time | 300–1500 ms (<2000 ms with visible progress) | ADR-0002 |
| Frame spike during load | Frame time | <1 ms (off-thread) | ADR-0002 |
| `duplicate_deep(SaveContext)` | CPU | ~1 ms (O(|echo_marks_archive|)) | ADR-0003 |
| `ResourceSaver.save(SaveContext)` | CPU | 2–10 ms (<20 KB payload) | ADR-0003 |
| SaveContext serialized | Size | 5–15 KB typical; <50 KB (FLAG_COMPRESS threshold) | ADR-0003 |
| Full save cycle | Wall clock | <50 ms on mid-range Android | ADR-0003 (V-11) |
| CP-1 load at Beat 1 | Wall clock | 5–15 ms | ADR-0003 |
| `get_movement_range()` | CPU | <16 ms on 40×30, move_range=10, mid-range Android | ADR-0004 (AC-PERF-2) (TR-map-grid-006) |
| Dijkstra with packed caches | CPU | <5 ms expected (4-dir + early termination) | ADR-0004 |
| MapResource at rest | Memory | ~77 KB | ADR-0004 |
| Packed caches | Memory | ~36 KB (6 arrays × ~6 KB) | ADR-0004 |
| Active battle map total | Memory | <150 KB | ADR-0004 |
| `.tres` map load | Wall clock | <100 ms | ADR-0004 |
| Binary `.res` map load (shipped) | Wall clock | <50 ms | ADR-0004 |

### Engine API Constraints (Post-Cutoff Verification)

These APIs require verification against the pinned Godot 4.6 before implementation:

| API | Version | ADR | Verification |
|-----|---------|-----|--------------|
| Typed signals with Resource payloads | 4.2+ (strictness tightened 4.5) | ADR-0001 | Confirmed stable per `current-best-practices.md` |
| `ResourceLoader.load_threaded_request` / `load_threaded_get_status` | 4.2+ (signature stable 4.4/4.5/4.6) | ADR-0002 | Verify on Android export (out-param semantics) |
| Recursive Control disable (mouse_filter inheritance) | 4.5+ | ADR-0002 | Verify exact property name on Godot 4.6 |
| `Resource.duplicate_deep(DUPLICATE_DEEP_ALL_BUT_SCRIPTS)` | 4.5+ | ADR-0001, ADR-0003, ADR-0004 | Confirmed per `breaking-changes.md` |
| `DirAccess.rename_absolute()` atomicity | Pre-cutoff | ADR-0003 | POSIX rename(2) on `user://` only; NOT SAF |
| `DirAccess.get_files_at` | 4.6-idiomatic | ADR-0003 | Replaces legacy `list_dir_begin` loop |
| `ResourceSaver.FLAG_COMPRESS` | 4.0+ | ADR-0003 | Pre-cutoff stable |

---

## Core Layer Rules

*Applies to: core gameplay loop, pathfinding, LoS, attack-direction calculation, turn-order signal plumbing*

### Required Patterns

**Pathfinding & LoS (ADR-0004 Core-side)**
- **Pathfinding algorithm: custom Dijkstra** — 4-directional adjacency, per-unit-type × per-terrain-type integer cost lookup — source: ADR-0004 (CR-6)
- **Cost scale**: `move_budget = move_range × 10`; `step_cost = base_terrain_cost(terrain_type) × cost_multiplier(unit_type, terrain_type)` — source: `design/gdd/map-grid.md` F-2/F-3 + ADR-0004
- **Visited set**: `PackedByteArray` of length `rows * cols`, indexed by `row * cols + col`; flag byte = 1 once finalized — avoids `Dictionary` allocation in hot loop — source: ADR-0004
- **Priority queue**: sorted `PackedInt32Array` scratch buffer with packed `(cost << 16) | tile_index` entries; `bsearch` for insertion — heap class adds GDScript dispatch overhead, frontier peaks <100 at move_range=10 — source: ADR-0004
- **Static typing throughout inner loop**; no `is_instance_valid()` or `typeof()` in hot path; cost table pre-validated at `load_map()` time — source: ADR-0004
- **Early termination**: abort exploration when `cost_so_far > move_budget` for `get_movement_range`; for `get_path` use admissible heuristic lower bound — source: ADR-0004
- **LoS via Bresenham** over `_elevation_cache` — block iff `elevation > max(from.elev, to.elev)`; destroyed walls NO LONGER block; endpoints never self-block — source: ADR-0004 + `design/gdd/map-grid.md` F-4 (TR-map-grid-008)
- **LoS corner-cut conservatism**: Bresenham line passing through a tile corner treats both adjacent tiles as intermediates — either blocking condition blocks LoS (prevents "shoot through wall gap" exploit) — source: `design/gdd/map-grid.md` EC-3
- **Attack direction tie-break**: on `abs(dc) == abs(dr)` (perfect diagonal), horizontal axis wins (EAST/WEST) — deterministic cross-system rule — source: `design/gdd/map-grid.md` F-5 EC + cross-system contract to `damage-calc.md`

**Turn Order signal ownership (ADR-0001 Core-side)**
- **Turn Order emits only**: `round_started(int)`, `unit_turn_started(int)`, `unit_turn_ended(int, bool)` — source: ADR-0001 (TR-turn-order-001)
- **Battle termination signal ownership lives in Grid Battle, not Turn Order** — single-emitter rule; Grid Battle emits `battle_outcome_resolved(BattleOutcome)` on CLEANUP — source: ADR-0001

### Performance Guardrails

| System | Metric | Budget | Source |
|--------|--------|--------|--------|
| `get_movement_range()` | CPU | <16 ms on 40×30 map, move_range=10 | ADR-0004 (AC-PERF-2) |
| 60fps combat turn | Frame time | no 3 consecutive frames >16.6 ms on max map | `design/gdd/map-grid.md` AC-PERF-1 |

---

## Feature Layer Rules

*Applies to: AI pathfinding consumer, Formation Bonus, HP/Status, Damage Calc, Destiny Branch, secondary mechanics*

### Required Patterns (Consumer Contracts from ADR-0004 + ADR-0001)

- **AI must invalidate cached paths on receiving `GameBus.tile_destroyed(coord: Vector2i)`** — affected path cache entries recomputed on next query — source: ADR-0004 §Decision 9 consumer contract
- **Formation Bonus must re-check adjacency on receiving `GameBus.tile_destroyed(coord: Vector2i)`** for any formation cell adjacent to `coord` — source: ADR-0004 §Decision 9 consumer contract
- **Formation Bonus self-caches `coord_to_unit_id: Dictionary[Vector2i, int]` from `units: Array[UnitState]` at `round_started`** — never calls `MapGrid.get_unit_at()` (no such API exists) — source: `design/gdd/formation-bonus.md` F-FB-1 v1.1 + `design/gdd/map-grid.md` §Dependencies
- **HP/Status emits `unit_died(unit_id: int)` via GameBus** when HP reaches 0 — consumed by Turn Order (queue removal), Grid Battle (victory check), AI — source: ADR-0001 (TR-hp-status-001)

### Forbidden Approaches

- **Never call a non-existent `MapGrid.get_unit_at(coord)` API** — consumers must self-cache from `units` array at round boundary — source: `design/gdd/map-grid.md` §Dependencies v1.1

---

## Presentation Layer Rules

*Applies to: Battle HUD, VFX, rendering, audio, UI*

### Required Patterns

- **VFX system subscribes to `GameBus.tile_destroyed(coord: Vector2i)`** and plays destruction effect at that coord — source: ADR-0004 §Decision 9 consumer contract
- **Battle HUD reads `SceneManager.loading_progress: float` as a property query (not via bus)** — displays progress bar during LOADING_BATTLE — source: ADR-0002 §Key Interfaces
- **UI accessibility (if committed tier requires it)**: use AccessKit screen reader integration on Control nodes — Godot 4.5+ — source: `docs/engine-reference/godot/current-best-practices.md` §Accessibility

---

## Global Rules (All Layers)

### Naming Conventions

| Element | Convention | Example |
|---------|-----------|---------|
| Classes | PascalCase | `PlayerController`, `BattleOutcome`, `MapGrid` |
| Variables | snake_case | `move_speed`, `active_slot`, `_overworld_ref` |
| Signals / Events | snake_case past tense | `battle_outcome_resolved`, `chapter_completed`, `tile_destroyed` |
| Files | snake_case matching class | `player_controller.gd`, `battle_outcome.gd`, `save_manager.gd` |
| Scenes / Prefabs | PascalCase matching root node | `PlayerController.tscn`, `BattleScene.tscn` |
| Constants | UPPER_SNAKE_CASE | `MAX_HEALTH`, `P_MULT_COMBINED_CAP`, `SAVE_ROOT`, `SLOT_COUNT` |

Source: `.claude/docs/technical-preferences.md`

### Performance Budgets

| Target | Value |
|--------|-------|
| Framerate | 60 fps |
| Frame budget | 16.6 ms |
| Draw calls (2D mobile) | <500 |
| Memory ceiling (mobile) | 512 MB |
| Memory ceiling (PC) | 1 GB |

Source: `.claude/docs/technical-preferences.md`

### Approved Libraries / Addons

*(None currently approved — empty list per `technical-preferences.md` §Allowed Libraries. All dependencies must be added to the approved list before use.)*

### Forbidden APIs (Godot 4.6)

These APIs are deprecated. Replace with the listed alternative before committing code.

| Deprecated | Use Instead | Since |
|------------|-------------|-------|
| `TileMap` | `TileMapLayer` | 4.3 |
| `VisibilityNotifier2D` / `VisibilityNotifier3D` | `VisibleOnScreenNotifier2D` / `VisibleOnScreenNotifier3D` | 4.0 |
| `YSort` | `Node2D.y_sort_enabled` | 4.0 |
| `Navigation2D` / `Navigation3D` | `NavigationServer2D` / `NavigationServer3D` | 4.0 |
| `EditorSceneFormatImporterFBX` | `EditorSceneFormatImporterFBX2GLTF` | 4.3 |
| `yield()` | `await signal` | 4.0 |
| `connect("signal", obj, "method")` | `signal.connect(callable)` | 4.0 |
| `instance()` / `PackedScene.instance()` | `instantiate()` | 4.0 |
| `get_world()` | `get_world_3d()` | 4.0 |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` | 4.0 |
| `duplicate()` for nested resources | `duplicate_deep()` | 4.5 |
| `Skeleton3D.bone_pose_updated` signal | `skeleton_updated` | 4.3 |
| `AnimationPlayer.method_call_mode` | `AnimationMixer.callback_mode_method` | 4.3 |
| `AnimationPlayer.playback_active` | `AnimationMixer.active` | 4.3 |

Source: `docs/engine-reference/godot/deprecated-apis.md`

**Project-specific override**: `NavigationServer2D` is listed as "use instead" for `Navigation2D`, but **ADR-0004 explicitly forbids both `AStarGrid2D` and `NavigationServer2D` for grid pathfinding** — custom Dijkstra only.

### Forbidden Patterns

| Deprecated Pattern | Use Instead | Why |
|--------------------|-------------|-----|
| String-based `connect()` | Typed signal connections | Type-safe, refactor-friendly |
| `$NodePath` in `_process()` | `@onready var` cached reference | Performance — path lookup every frame |
| Untyped `Array` / `Dictionary` | `Array[Type]`, typed variables | GDScript compiler optimisations |
| `Texture2D` in shader parameters | `Texture` base type | Changed in 4.4 |
| Manual post-process viewport chains | `Compositor` + `CompositorEffect` | Structured post-processing (4.3+) |
| GodotPhysics3D for new projects | Jolt Physics 3D | Default since 4.6; better stability |

Source: `docs/engine-reference/godot/deprecated-apis.md` §Patterns

### Current Best Practices (Required — from engine-reference)

- **Static typing mandatory** across all GDScript (`Array[Type]`, typed locals, typed signal params) — source: technical-preferences + deprecated-apis patterns
- **Use `@abstract` annotation** for classes/methods requiring override (GDScript 4.5+) — source: current-best-practices §GDScript
- **Jolt Physics is default 3D engine** in Godot 4.6 — do not switch back without ADR — source: current-best-practices §Physics
- **Known Jolt limitation**: `HingeJoint3D.damp` property only works with GodotPhysics3D (not Jolt) — if needed, the ADR governing that feature must flag it — source: current-best-practices §Physics
- **D3D12 is default rendering backend on Windows** in Godot 4.6 (was Vulkan) — source: current-best-practices §Rendering + technical-preferences
- **Dual-focus system (mouse/touch vs keyboard/gamepad)** on Godot 4.6 — custom focus behavior must account for separated focus tracking — source: current-best-practices §UI
- **`duplicate_deep()` for nested resource trees** (4.5+) — explicit per-instance copy control — source: current-best-practices §Resources

### Cross-Cutting Constraints

**From `CLAUDE.md` coding-standards:**
- Doc comments on all public APIs (GDScript `##` triple-hash)
- Every system has a corresponding ADR in `docs/architecture/`
- Gameplay values data-driven (external config) — never hardcoded
- Public methods unit-testable via dependency injection — singletons forbidden where DI is viable
- Commits reference relevant design doc or task ID
- **Verification-driven development**: tests first for gameplay systems; screenshots for UI; compare expected to actual output before marking complete

**From `CLAUDE.md` testing-standards:**
- Framework: GdUnit4
- Coverage floor: 100% for balance formulas, 80% for gameplay systems
- Test file naming: `[system]_[feature]_test.[ext]` (e.g. `damage_calc_test.gd`)
- Test function naming: `test_[scenario]_[expected]` (e.g. `test_rear_attack_applies_cavalry_bonus`)
- Tests must be **deterministic** — no random seeds, no time-dependent assertions
- Tests must be **isolated** — per-test setup/teardown; no execution-order dependency
- No hardcoded test data — use constant files or factory functions (exception: boundary-value tests where the exact number IS the point)
- Unit tests do not call external APIs, databases, or file I/O — use DI
- CI: headless runner `godot --headless --script tests/gdunit4_runner.gd` runs on every push + PR
- No merge on test failure; never skip failing tests to make CI pass — fix the underlying issue

**From collaborative-design principle:**
- Design documents written incrementally: skeleton → one section at a time → user approval → write each approved section to file immediately
- No unilateral multi-file changes without explicit approval for the full changeset
- No commits without user instruction

**Formation Bonus / Damage Calc process insights (triad adopted from damage-calc review log)**:
- **"Recursive fabrication trap"** (pass-5): fabricated helper functions often depend on fabricated engine APIs — verify against engine-reference before asserting an API exists
- **"Compute, don't read"** (pass-6): numerical invariants stated in prose must be verified by arithmetic before revision close-out
- **"Change the cell, forget the citer"** (pass-9): any numeric constant change in one GDD must trigger grep-level cross-doc audit in all citing GDDs; sweep + narrow re-review is the minimum safe unit for numeric changes touching 2+ documents

---

## Implementation Decisions Deferred

These are intentionally-deferred decisions carried from ADR advisories; they will be resolved by the relevant specialist at `/dev-story` time.

| Decision | Context | Owner at resolution | Source |
|----------|---------|---------------------|--------|
| `get_movement_range()` return type: `PackedVector2Array` vs `Array[Vector2i]` | Packed stores `Vector2` (float); `Vector2i` integer precision requires conversion at API boundary | godot-gdscript-specialist | ADR-0004 ADV-1 (review 2026-04-20) |
| `Resource.FLAG_COMPRESS` for SaveContext | On-by-default threshold is payload >50 KB; MVP expected 5–15 KB — likely OFF | godot-gdscript-specialist after first realistic save benchmark | ADR-0003 §Open Questions |
| iCloud backup exclusion (`NSUbiquitousItemIsExcludedFromBackupKey`) | Default: saves backed up. Product decision deferred. | producer / release-manager | ADR-0003 §Open Questions |
| Recursive Control disable exact property name on Godot 4.6 | 4.5+ feature; exact property for mouse_filter propagation not fully specified in engine-reference | godot-specialist pre-implementation | ADR-0002 §Engine Compatibility |

---

## ADR Coverage Summary

| ADR | Title | Status | Layer | TRs |
|-----|-------|--------|-------|-----|
| ADR-0001 | GameBus Autoload | Accepted 2026-04-18 | Foundation | TR-gamebus-001, TR-scenario-progression-001..003, TR-grid-battle-001, TR-turn-order-001, TR-hp-status-001, TR-input-handling-001 |
| ADR-0002 | Scene Manager | Accepted 2026-04-18 | Foundation | TR-scene-manager-001..005 |
| ADR-0003 | Save/Load | Accepted 2026-04-18 | Foundation | TR-save-load-001..007 |
| ADR-0004 | Map/Grid Data Model | Accepted 2026-04-20 | Foundation + Core | TR-map-grid-001..010 |

---

## Changelog

| Date | Change |
|------|--------|
| 2026-04-20 | Initial manifest. 4 Accepted Foundation-layer ADRs covered. Re-run when ADR-0005 (Input), ADR-0006 (Balance/Data), ADR-0007 (Hero DB), ADR-0008 (Terrain Effect), ADR-0009+ (Formation, Destiny) land. |
