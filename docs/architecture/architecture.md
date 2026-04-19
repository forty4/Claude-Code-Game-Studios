# 천명역전 (Defying Destiny) — Master Architecture

## Document Status

| Field | Value |
|---|---|
| Version | 0.3 (+ Phase 2 Core written; invariant #4 refined) |
| Last Updated | 2026-04-18 |
| Engine | Godot 4.6 (pinned 2026-04-16) |
| Language | GDScript |
| Review Mode | lean |
| GDDs Covered | 10 of 14 MVP (scan source: `design/gdd/`, 2026-04-18) |
| ADRs Referenced | ADR-0001, ADR-0002, ADR-0003 (Accepted); ADR-0004 (Proposed) |
| Technical Director Sign-Off | _pending — document is incomplete_ |
| Lead Programmer Feasibility | _pending — LP-FEASIBILITY deferred per lean mode_ |

### Completeness tracker

| Phase | Section | Status |
|---|---|---|
| 0 | Engine Knowledge Gap Summary | ✅ written |
| 0 | Technical Requirements Baseline | ✅ written (summary) + linked to `architecture-traceability.md` |
| 1 | System Layer Map | ✅ written |
| 2 | Module Ownership | ✅ Platform + Foundation + Core written (12 modules); Feature/Presentation/Polish deferred |
| 3 | Data Flow | ⏳ deferred |
| 4 | API Boundaries | ⏳ deferred |
| 5 | ADR Audit | ⏳ deferred (partial — 4 ADRs existing, 6-10 more required) |
| 6 | Required ADRs | ⏳ deferred |
| 7 | Architecture Principles | ⏳ deferred |
| 7 | Open Questions | ⏳ deferred |

---

## Engine Knowledge Gap Summary

**Engine**: Godot 4.6 | **Release**: Jan 2026 | **LLM training cutoff**: May 2025 (~Godot 4.3)

Post-cutoff versions with breaking or additive changes the LLM does not know:
**4.4** (MEDIUM risk), **4.5** (HIGH risk), **4.6** (HIGH risk).
Canonical reference: `docs/engine-reference/godot/`.

### HIGH RISK domains — verify against engine reference for every decision touching these

| Domain | Post-cutoff change | Affected systems |
|---|---|---|
| **Physics** | Jolt is default 3D engine (4.6) | — (2D project; Jolt risk is LOW for this game) |
| **UI dual-focus system** (4.6) | Mouse/touch focus now separate from keyboard/gamepad focus | Battle HUD, Input Handling, Main Menu, pause menu, all Control nodes |
| **Accessibility / AccessKit** (4.5+) | Screen reader support via Control nodes | ✅ **tier committed 2026-04-18** — `design/accessibility-requirements.md` v1.0 locks **Intermediate**. AccessKit stays HIGH risk for any future Advanced-tier promotion (out of scope at MVP). OQ-3 (Settings tier elevation) is blocking for Vertical Slice. |
| **Rendering — glow rework** (4.6) | Glow processes BEFORE tonemapping | Ink-wash shader pipeline, Battle VFX, terrain overlays |
| **Rendering — D3D12 default on Windows** (4.6) | Was Vulkan | PC target — ✅ **resolved 2026-04-18**: tech preferences committed per-platform (D3D12 Win / Vulkan Linux-Android / Metal macOS-iOS) |
| **Rendering — SMAA / Shader Baker** (4.5) | New AA option, pre-compiled shaders | Hybrid shader strategy (heroes individual ShaderMaterial, soldiers baked textures) |
| **Animation — IK restored** (4.6) + **BoneConstraint3D** (4.5) | CCDIK/FABRIK/etc. via SkeletonModifier3D | Post-MVP — flag but defer |
| **Platform — SDL3 gamepads / Android edge-to-edge / 16KB pages** (4.5) | New gamepad driver, Android 15+ mandatory | Input Handling, mobile export — Scenario Progression OQ bucket 3 already flags |
| **UI — Recursive Control disable** (4.5) | `set_process_input(false)` propagation | SceneManager overworld-retention technique (ADR-0002) |

### MEDIUM RISK domains

| Domain | Post-cutoff change | Affected systems |
|---|---|---|
| **Core / FileAccess** (4.4) | `store_*` return `bool` (was `void`) | SaveManager (ADR-0003 covers) |
| **Rendering — shader parameter types** (4.4) | `Texture2D` → `Texture` base type | Ink-wash shader parameter signatures |
| **Resources — `duplicate_deep()`** (4.5) | Explicit deep-copy method | ADR-0003 relies on it; ADR-0004 R-3 constraint depends on it |

### LOW RISK domains (in training data, safe to decide without extra verification)

- Autoloads, Resources, typed Arrays/Dictionaries, Signals (all stable since 4.0–4.1)
- TileMapLayer (4.3 — in training data; 4.6 additive scene-tile rotation only)
- PackedByteArray / PackedInt32Array (used in ADR-0004 hot-path caches)

### Reconciliations required

- ~~**Tech preferences stale on rendering backend**~~ — **resolved 2026-04-18**: `.claude/docs/technical-preferences.md` updated to per-platform backends (D3D12 Win / Vulkan Linux-Android / Metal macOS-iOS), trusting Godot 4.6 defaults. Rationale: 2D draw loads do not justify Windows `--rendering-driver vulkan` override; avoids shader-variant divergence risk.

---

## Technical Requirements Baseline

**102 technical requirements** extracted across 10 GDDs (2026-04-18, via `/create-architecture` Phase 0b).
**20 requirements** already registered in `docs/architecture/tr-registry.yaml` covering the 4 ADRs.

Full TR-to-ADR mapping: see `docs/architecture/architecture-traceability.md`.

### Domain distribution (102 TRs)

| Domain | Count | Notes |
|---|---|---|
| Core | 35 | State machines, data models, game rules |
| Physics / Math | 20 | Grid, pathfinding, damage formulas, elevation |
| Resource | 13 | Data-driven JSON, schema validation, balance constants |
| Input | 11 | Dual-platform (mouse/keyboard + touch), 22 actions |
| Signals | 8 | Cross-system communication via GameBus |
| Persistence | 5 | SaveContext, EchoMark, scenario state |
| Rendering | 3 | Silhouettes, terrain overlays, material strategy |
| UI | 1 | Stacking cap display |
| AI | 2 | Terrain scoring, scoring heuristics |
| Platform | 2 | Mobile budget (512MB), cross-platform touch/mouse |
| Audio | 2 | Evasion dodge SFX, distinct miss/hit feedback |

### Standout cross-system risks carried into this architecture session

1. **Cross-GDD contract: `battle_outcome_resolved` rename cascade** (ADR-0001 §Changelog, 2026-04-18) — affects Grid Battle v5.0, Turn Order v-next, Scenario Progression v2.0. All three GDDs must align before Feature-layer ADRs can be written.
2. **Damage/Combat Calc system is NOT STARTED** yet six other GDDs reference its formulas (Unit Role ATK/DEF, Terrain Effect evasion, HP/Status damage pipeline). Authoring this GDD is the highest-leverage next design action.
3. **Pathfinding performance contract**: ADR-0004 binds Dijkstra to <16ms on 40×30 mobile target via packed-cache hot path. This is the single largest performance-shaped decision in the architecture — verification V-1 through V-7 in ADR-0004 must pass before implementation.
4. **Accessibility tier unchosen** — blocks: screen reader ADR, colorblind mode for reserved destiny colors (주홍 #C0392B + 금색 #D4A017), input remapping depth. Must resolve before Pre-Production gate passes.
5. **UI dual-focus (4.6) × touch Input Handling** — the Input Handling GDD (11 TRs) pre-dates the dual-focus engine change. Must verify whether the auto-detect "last-device-wins" rule (CR-2) is still coherent under the 4.6 dual-focus model.

---

## System Layer Map

Every system in `design/gdd/systems-index.md` (31 systems total) is assigned to exactly one of six layers. Each layer may depend only on layers below it. Platform infrastructure singletons (GameBus, SceneManager, SaveManager) are separated from game systems into a dedicated Platform layer.

### Layer diagram

```
┌───────────────────────────────────────────────────────────────────┐
│  POLISH                                                           │
│  Tutorial · Settings/Options · Localization/i18n                  │
├───────────────────────────────────────────────────────────────────┤
│  PRESENTATION                                                     │
│  Battle HUD · Battle Prep UI · Story Event UI · Main Menu         │
│  Battle VFX · Sound/Music                                         │
├───────────────────────────────────────────────────────────────────┤
│  FEATURE                                                          │
│  Grid Battle · Formation Bonus · Destiny Branch · Scenario        │
│  Progression · Battle Prep · AI · Character Growth · Story Event  │
│  Damage Calc · Equipment · Destiny State · Class Conversion ·     │
│  Camera                                                           │
├───────────────────────────────────────────────────────────────────┤
│  CORE                                                             │
│  Terrain Effect · Unit Role · HP/Status · Turn Order ·            │
│  Save/Load (schema/migration)                                     │
├───────────────────────────────────────────────────────────────────┤
│  FOUNDATION                                                       │
│  Map/Grid · Hero DB · Balance/Data · Input Handling               │
├───────────────────────────────────────────────────────────────────┤
│  PLATFORM (infrastructure autoloads)                              │
│  /root/GameBus (ADR-0001) · /root/SceneManager (ADR-0002) ·       │
│  /root/SaveManager (ADR-0003)                                     │
├───────────────────────────────────────────────────────────────────┤
│  GODOT 4.6 ENGINE API SURFACE                                     │
└───────────────────────────────────────────────────────────────────┘
```

### Layer assignments (complete)

| Layer | System (systems-index row) | Priority | GDD | Engine risk domain |
|---|---|---|---|---|
| **Platform** | GameBus autoload | — | ADR-0001 (Accepted) | LOW (signals stable) |
| **Platform** | SceneManager autoload | — | ADR-0002 (Accepted) | MEDIUM (Recursive Control disable 4.5) |
| **Platform** | SaveManager autoload | — | ADR-0003 (Accepted) | MEDIUM (FileAccess 4.4 + duplicate_deep 4.5) |
| **Foundation** | Map/Grid System (#14) | MVP | design/gdd/map-grid.md | LOW (TileMapLayer 4.3) |
| **Foundation** | Hero Database (#25) | MVP | design/gdd/hero-database.md | LOW (Resource system stable) |
| **Foundation** | Balance/Data System (#26) | MVP | design/gdd/balance-data.md | MEDIUM (FileAccess 4.4) |
| **Foundation** | Input Handling System (#29) | MVP | design/gdd/input-handling.md | **HIGH** (dual-focus 4.6, SDL3 4.5, Android edge-to-edge 4.5) |
| **Core** | Terrain Effect System (#2) | MVP | design/gdd/terrain-effect.md | LOW |
| **Core** | Unit Role System (#5) | MVP | design/gdd/unit-role.md | LOW |
| **Core** | HP/Status System (#12) | MVP | design/gdd/hp-status.md | LOW |
| **Core** | Turn Order / Action Management (#13) | MVP | design/gdd/turn-order.md | LOW |
| **Core** | Save/Load System (#17, schema + migration) | VS | (not yet authored — ADR-0003 infra only) | MEDIUM |
| **Feature** | Grid Battle System (#1) | MVP | design/gdd/grid-battle.md (v5.0 pending) | LOW |
| **Feature** | Formation Bonus System (#3) | MVP | (not yet authored) | LOW |
| **Feature** | Destiny Branch System (#4) | MVP | (not yet authored — **pillar-defining, top priority**) | LOW |
| **Feature** | Scenario Progression (#6) | MVP | design/gdd/scenario-progression.md (v2.0 re-review pending) | LOW |
| **Feature** | Battle Preparation (#7) | VS | (not yet authored) | LOW |
| **Feature** | AI System (#8) | MVP | (not yet authored) | LOW |
| **Feature** | Character Growth (#9) | VS | (not yet authored) | LOW |
| **Feature** | Story Event (#10) | VS | (not yet authored) | LOW |
| **Feature** | Damage/Combat Calculation (#11) | MVP | (not yet authored — **referenced by 6 GDDs**) | LOW |
| **Feature** | Equipment / Item (#15) | Alpha | (not yet authored) | LOW |
| **Feature** | Destiny State (#16) | VS | (not yet authored) | LOW |
| **Feature** | Class Conversion (#31) | VS | (not yet authored) | LOW |
| **Feature** | Camera System (#22) | VS | (not yet authored) | **HIGH** (dual-focus interacts with camera input) |
| **Presentation** | Battle HUD (#18) | Alpha | design/ux/battle-hud.md | **HIGH** (dual-focus, glow rework) |
| **Presentation** | Battle Preparation UI (#19) | Alpha | (not yet authored) | HIGH (dual-focus) |
| **Presentation** | Story Event UI (#20) | Alpha | (not yet authored) | HIGH (dual-focus) |
| **Presentation** | Main Menu / Scenario Select UI (#21) | Alpha | (not yet authored) | HIGH (dual-focus) |
| **Presentation** | Battle VFX (#23) | Alpha | (not yet authored) | MEDIUM (glow rework, SMAA) |
| **Presentation** | Sound/Music System (#24) | Full Vision | (not yet authored) | LOW |
| **Polish** | Tutorial (#27) | Full Vision | (not yet authored) | LOW |
| **Polish** | Settings/Options (#28) | Full Vision | (not yet authored) | **HIGH** (AccessKit accessibility tier) |
| **Polish** | Localization / i18n (#30) | Full Vision | (not yet authored) | MEDIUM (CSV plural forms 4.6) |

### Layer invariants

1. **Downward-only dependencies.** Higher layers call, subscribe, and read lower layers; never the reverse. Lower layers communicate upward only via GameBus signals — never by direct reference to upper-layer nodes.
2. **Platform layer is aware of no game systems.** GameBus, SceneManager, SaveManager have zero imports of `design/gdd/*` concepts. They are pure infrastructure.
3. **Foundation layer systems have no game-system dependencies on each other.** Map/Grid, Hero DB, Balance/Data, Input Handling are independently buildable in any order.
4. **Core layer does not depend on Feature / Presentation / Polish.** Core may use signals on GameBus but never import symbols from layers above. Upward control flow from Core to Feature must be signal-inverted (Core emits → Feature subscribes → Feature responds via its own signal).
4b. **Same-layer Core peers may call each other directly only when** (a) the callee is a pure stateless rules module (e.g., Unit Role), OR (b) the pair is a signal-producer ↔ signal-consumer relation (e.g., HP/Status → Turn Order via `unit_died`). Circular same-layer Core dependencies are forbidden.
5. **Feature layer is the only layer allowed to emit `battle_*` and `scenario_*` signals.** Presentation subscribes to read; Polish layer is advisory (does not gate core loop).
6. **Save/Load boundary**: SaveManager (Platform, ADR-0003) owns I/O and atomicity — `ResourceSaver.save` → `rename_absolute`, `ResourceLoader.load(..., CACHE_MODE_IGNORE)`. Save/Load system #17 (Core) owns **what** is saved — SaveContext schema, EchoMark payload, BattleOutcome.Result enum append-only rule, SaveMigrationRegistry. No other system writes to disk.
7. **Three Foundation-layer systems touch HIGH engine risk**: Input Handling (dual-focus 4.6, SDL3, Android). Every ADR for Input must verify against `docs/engine-reference/godot/modules/input.md` + `ui.md`.
8. **All six Presentation-layer UI screens touch HIGH engine risk** (dual-focus 4.6). The first UI ADR must establish a dual-focus pattern that applies to all subsequent screens, or accept that every screen gets its own ADR.

### Camera (#22) justification for Feature placement

Camera depends on Map/Grid (viewport bounds, grid↔world coordinate conversion) and Input (pan gesture classification, zoom clamping — TR-input-010 hard-binds `camera_zoom_min = 0.70` to enforce 44px touch targets). These are tactical, gameplay-shaped dependencies, not visual-presentation concerns. Camera is a gameplay system whose output is rendered — similar to pathfinding. Kept in Feature layer per systems-index.

### Systems requiring additional ADRs before implementation (preview — formal list in Phase 6)

**Foundation layer (MUST exist before any coding):**
- ADR-0005 Input Handling — HIGH engine risk (dual-focus, SDL3, Android)
- ADR-0006 Balance/Data pipeline — MEDIUM risk (FileAccess 4.4)
- ADR-0007 Hero DB Resource schema + validation
- ADR-0008 Terrain Effect — _session state ordering: after ADR-0004 Map/Grid_

**Core layer (must exist before the relevant system is built):**
- ADR for Turn Order signal ownership finalization (battle_ended rename cascade)
- ADR for Save/Load schema versioning (may be covered by ADR-0003 follow-up)

**Feature layer (authored during Pre-Production):**
- ADR for Damage/Combat Calculation formula ownership (pipeline between Unit Role, Terrain, HP/Status)
- ADR for AI decision architecture (behavior-tree vs. utility-AI vs. state-machine)
- ADR for Destiny Branch resolution + Echo-gate signal contract

**Presentation layer (authored before UI implementation):**
- ADR for UI dual-focus pattern (applies to all 6 UI screens)
- ADR for ink-wash shader pipeline + glow-before-tonemap interaction

**Count estimate:** 8–12 additional ADRs before Pre-Production → Production gate.

---

## Module Ownership

**Scope**: Platform + Foundation + Core layers (12 modules). Feature / Presentation / Polish ownership is deferred to a subsequent `/create-architecture` session and marked as TODO at the end of this section.

For each module: **Owns** = state/data this module is solely responsible for. **Exposes** = entrypoints other modules may call or subscribe to. **Consumes** = what this module reads or subscribes to from below. **Engine APIs used** = specific Godot classes/methods with version + risk tagged per `docs/engine-reference/godot/` (LOW/MEDIUM/HIGH matches the Knowledge Gap Summary above).

### Platform layer (3 modules — all ADRs Accepted)

| Module | Owns | Exposes | Consumes | Engine APIs used |
|---|---|---|---|---|
| **GameBus** (ADR-0001) | 27 signal declarations across 10 domains; signal-schema table; changelog. **Zero game state** — pure relay. | All signals at `/root/GameBus.*` (typed Resource payloads for ≥2-field cases; primitives for ≤1-field). Connect/disconnect via `Callable`. | **Nothing** — invariant: GameBus reads from no module. | `Node` autoload at `/root/GameBus`, load order 1; `signal` keyword; `Resource` subclasses for typed payloads. LOW risk (core signal API stable since 4.0). |
| **SceneManager** (ADR-0002) | 5-state FSM (`IDLE`, `LOADING_BATTLE`, `IN_BATTLE`, `RETURNING_FROM_BATTLE`, `ERROR`); current Overworld node ref; current BattleScene node ref; async-load `Timer` cadence (100 ms). | State-transition handlers driven by GameBus signals `battle_launch_requested` / `battle_outcome_resolved`. Emits `scene_transition_failed(context, reason)` via GameBus on error. | GameBus (subscribes to `battle_launch_requested`, `battle_outcome_resolved`); `balance_data.loaded` (waits for catalog before first scene init). | `ResourceLoader.load_threaded_request` / `.load_threaded_get_status` (stable 4.0); `Timer` node at 100 ms cadence (**NOT** `_process` — per ADR-0002 CR-3); `Node.process_mode = PROCESS_MODE_DISABLED` + `set_process_input(false)` + recursive Control `mouse_filter = IGNORE` on retained overworld (MEDIUM — **recursive Control disable is 4.5**); `call_deferred('_free_battle_scene_and_restore_overworld')` on outcome. |
| **SaveManager** (ADR-0003) | `user://saves/*.tres` files on disk; in-memory `SaveContext` Resource; `SaveMigrationRegistry` (`Dictionary[int, Callable]` — pure `Callable`, no captured state); atomicity guarantee. | `save_checkpoint(ctx: SaveContext) -> Error`; `load_slot(slot: int) -> SaveContext`; emits `save_persisted` / `save_load_failed(severity, reason)` via GameBus. | GameBus (subscribes to `save_checkpoint_requested` — **sole emitter is ScenarioRunner** per C-1 resolution, SceneManager explicitly not allowed); `balance_data.loaded` (migration registry warmup). | `FileAccess` (MEDIUM — **`store_*` returns `bool` since 4.4**, affects any future telemetry write path); `ResourceSaver.save(tmp_path)` → `DirAccess.rename_absolute(tmp, final)` (atomic swap); `ResourceLoader.load(path, '', ResourceLoader.CACHE_MODE_IGNORE)` (stable); `Resource.duplicate_deep()` (MEDIUM — **4.5+, explicit deep-copy method**). |

### Foundation layer (4 modules — 1 ADR Proposed, 3 ADRs pending)

| Module | Owns | Exposes | Consumes | Engine APIs used |
|---|---|---|---|---|
| **Map/Grid** (ADR-0004 Proposed) | `MapResource` (`Resource`, `Array[TileData]` flat-indexed `row * cols + col`); runtime `MapGrid extends Node` (child of BattleScene, battle-scoped lifecycle per ADR-0002); tile-state transitions (`EMPTY ↔ ALLY_OCCUPIED ↔ ENEMY_OCCUPIED ↔ DESTROYED`); packed hot-path caches (`PackedInt32Array` frontier, `PackedByteArray` visited); Dijkstra pathfinding + Bresenham LoS + elevation check. | `get_tile(coord: Vector2i) -> TileData`; `get_movement_range(unit, budget: int) -> Dictionary[Vector2i, int]`; `has_line_of_sight(a: Vector2i, b: Vector2i) -> bool`; mutation methods (all write-through to packed caches); emits **only** `tile_destroyed(coord: Vector2i)` via GameBus. Documented exception: this is the single Map/Grid signal ever permitted — all other Map/Grid communication is direct call. | **Nothing at runtime** (Foundation, by invariant). At init: loads `.tres` via `ResourceLoader.load`; reads terrain cost constants from Balance/Data's `balance_constants.json` once. | `Resource` + `@export` **inline sub-resources** (forbidden pattern `tile_data_external_subresource` — external UID-referenced TileData breaks `duplicate_deep` isolation per ADR-0004 R-3); `PackedInt32Array`, `PackedByteArray` (stable); `Vector2i`; **no** `AStarGrid2D` / `NavigationServer2D` (explicitly banned per CR-6 — forbidden pattern `astar_grid2d_for_tactical_pathfinding`); `TileMapLayer` for authoring preview only (4.3 stable — not runtime). LOW engine risk overall, MEDIUM on Resource `duplicate_deep` 4.5 dependency. |
| **Hero Database** (⏳ ADR-0007) | `heroes.json` catalog → validated `Array[HeroRecord]` (~80–100 full vision; **8–10 MVP**); cross-reference validator (stat-total ∈ [180, 280], SPI ≥ 0.5, relationships FK integrity, `innate_skill_ids.length == skill_unlock_levels.length`); duplicate `hero_id` → FATAL. | `get_hero(hero_id: String) -> HeroRecord`; `list_heroes_for_chapter(ch: int) -> Array[HeroRecord]`; `list_available_mvp() -> Array[HeroRecord]`. **Read-only** — no runtime mutation (stat growth goes through a separate Character Growth system that produces new records). | Balance/Data (subscribes to `balance_data.loaded`; reads `REQUIRED_CATEGORIES.heroes` catalog). No other consumption. | `Resource` + `@export` typed fields (stable); `JSON.parse_string` (stable); `StringName` for ID lookup (stable 4.0). **LOW engine risk** — no post-cutoff API. |
| **Balance/Data** (⏳ ADR-0006) | `DataRegistry` singleton (read-only); 4-phase pipeline (Discovery → Parse → Validate → Build); `MINIMUM_SCHEMA_VERSION` gate; Validation Coverage Rate (VCR) metric, CI threshold ≥ 1.0; 16 balance_constants; `REQUIRED_CATEGORIES = {heroes, maps, unit_roles, growth, balance_constants, skills, scenarios, formations}`; `PIPELINE_TIMEOUT_MS = 5000` on 512 MB mobile. | `get_category(name: StringName) -> Array[Resource]`; `get_constant(key: StringName) -> Variant`; dev-only `reload()` (manual trigger). Emits `balance_data.loaded(vcr: float)` on success or `balance_data.load_failed(severity, category, reason)` via GameBus. | `DirAccess` for discovery under `res://data/`. Nothing else — root of Foundation. | `DirAccess.open` / `.get_files_at` (stable); `JSON.parse_string` (stable); `FileAccess.open(..., READ)` for catalog files (MEDIUM — 4.4 `store_*` return-type change applies to dev-mode hot-reload write path, not production read path); `Resource` + `@export` on wrapper Resources. **LOW–MEDIUM risk** — no 4.5/4.6 API surface touched by production path. |
| **Input Handling** (⏳ ADR-0005) | `InputStateMachine` (7 states: `Observation`, `UnitSelected`, `MovementPreview`, `AttackTargetSelect`, `AttackConfirm`, `MenuOpen`, `InputBlocked`); 22-action vocabulary (10 grid + 4 camera + 5 menu + 3 meta); device-mode auto-detect (`KEYBOARD_MOUSE` / `TOUCH`, last-device-wins); Touch Tap Preview Protocol (80–120 px floating stats panel); per-unit undo window (1 move, closes on attack/wait/end-turn); 44 × 44 px touch-target enforcement via `camera_zoom_min = 0.70`. | Emits `input_action_fired(ctx: InputContext)`, `input_state_changed(from, to)`, `input_mode_changed(mode)` via GameBus. `default_bindings.json` lives at `assets/data/input/` for remapping. | `DisplayServer` query for screen metrics + safe-area insets. Listens to no other game system (consumes device events only). | `Input` singleton (stable); `InputMap` (⚠️ **4.5 SDL3 gamepad driver** changed the gamepad code path — verify against `docs/engine-reference/godot/modules/input.md` before ADR-0005); `InputEventMouseButton` / `InputEventScreenTouch` / `InputEventScreenDrag` / `InputEventKey` (stable); **Godot 4.6 dual-focus system** — Control focus for mouse/touch is now separate from keyboard/gamepad focus (⚠️ affects state-machine assumption that focus is single-valued — see blocker note below); Android **edge-to-edge / safe-area** APIs (4.5, HIGH); `DisplayServer.screen_get_size` for dynamic touch-target clamp. **HIGH engine risk** overall — see blocker note. |

### Core layer (5 modules — 4 MVP with GDDs, 1 VS Not Started)

| Module | Owns | Exposes | Consumes | Engine APIs used |
|---|---|---|---|---|
| **Terrain Effect** (#2 — MVP, Designed; ⏳ ADR-0008) | `terrain_modifier_table` (PLAINS/FOREST/MOUNTAIN/RIVER/BRIDGE/ROAD/RUIN/WALL etc. → `defense_bonus`, `evasion_bonus`, special rule flags); `MAX_DEFENSE` / `MAX_EVASION` caps; `EVASION_WEIGHT` for scoring; `bridge_no_flank` flag semantics; elevation vs. terrain_def stacking rules. **Stateless per-unit** — pure rules calculator indexed by tile coord. | `get_terrain_modifiers(coord: Vector2i) -> TerrainModifiers`; `get_terrain_score(coord: Vector2i) -> float` (AI use only, elevation-agnostic); emits `terrain_changed(coord)` via GameBus when tile destruction changes `terrain_type`. | Map/Grid (`get_tile(coord)`, reads `terrain_type` + `elevation`); Balance/Data (reads `terrain/terrain_config.json` at init); subscribes to GameBus `tile_destroyed(coord)` from Map/Grid to invalidate cache + re-emit `terrain_changed`. | `Resource` + `@export` for `TerrainModifiers`; `Vector2i`; `Dictionary` keyed by terrain enum. No post-cutoff API. **LOW risk.** |
| **Unit Role** (#5 — MVP, Designed; ⏳ ADR needed for class-coefficient schema) | Class definitions (INFANTRY / CAVALRY / ARCHER / STRATEGIST / HEALER); per-class coefficient schema (`w_primary`, `w_secondary`, `class_atk_mult`, `class_phys_def_mult`, `class_mag_def_mult`, `class_hp_mult`, `class_init_mult`, `class_move_delta`); derived-stat formulas (ATK, PHYS_DEF, MAG_DEF, max_HP, INIT, MOVE); hard caps (`ATK_CAP`, `DEF_CAP`, `HP_CAP`, `INIT_CAP`, `MOVE_RANGE_MIN`/`MAX`); per-class passive definitions; `class_pools.json` skill-pool structure. **Stateless per-unit** — pure calculator; produces derived stats on demand. | `get_atk(hero, role) -> int`; `get_phys_def(...)`; `get_mag_def(...)`; `get_max_hp(hero, role) -> int`; `get_initiative(hero, role) -> int`; `get_move_range(hero, role) -> int`; `get_class_passives(role) -> Array[PassiveDef]`. No signals — pure query surface. | Hero DB (`get_hero(hero_id)` for stats + `base_hp_seed` + `is_morale_anchor`); Balance/Data (reads `unit_roles.json` + `balance_constants.json` + `class_pools.json`). | `Resource` + `@export`; typed `Dictionary[StringName, Variant]` for coefficient lookup; `clamp()` on caps. No post-cutoff API. **LOW risk.** |
| **HP/Status** (#12 — MVP, Designed; ⏳ ADR needed for status-effect stacking contract) | Per-unit `current_hp` / `max_hp` / `status_effects[]` (StatusEffect Resource with `id`, `icon`, `remaining_turns`, `modifier_values`); DoT pipeline (POISON: `DOT_HP_RATIO`, `DOT_FLAT`, `DOT_MIN`, `DOT_MAX_PER_TURN`); healing pipeline (`HEAL_BASE`, `HEAL_HP_RATIO`, `HEAL_PER_USE_CAP`, `EXHAUSTED_HEAL_MULT`); morale system (DEMORALIZED / INSPIRED / DEFEND_STANCE with radius, turn-cap, recovery); stat-modifier arithmetic with `MODIFIER_FLOOR` / `MODIFIER_CEILING` clamp. | `is_alive(unit) -> bool`; `apply_damage(unit, amount, source) -> int` (returns actual damage after mitigation); `apply_heal(unit, amount) -> int`; `tick_dot_effects(unit_id) -> bool` (returns true if unit died); `get_status_effects(unit) -> Array[StatusEffect]`; `modified_move_range(unit) -> int`. Emits `unit_died(unit_id)` via GameBus (single authoritative emitter per ADR-0001). | Hero DB (`base_hp_seed`, `is_morale_anchor`); Unit Role (`get_max_hp`, Core peer — permitted by invariant #4b case (a) stateless rules module); Balance/Data (`hp_status_config.json`, `balance_constants.json`). Mutations arrive via direct method calls from Damage Calc (Feature, above) — **upward call inversion required**: Damage Calc must call `apply_damage()` as a downward call, not HP/Status calling into Damage Calc. | `Resource` for `StatusEffect`; `signal unit_died(unit_id: int)`; `Dictionary[int, Array[StatusEffect]]`. No post-cutoff API. **LOW risk.** |
| **Turn Order / Action Management** (#13 — MVP, Needs Revision; ⏳ ADR needed for AI-inversion signal contract) | Initiative queue (sorted by `(initiative DESC, stat_agility DESC, is_player_controlled DESC, unit_id ASC)`); `current_round_number`; per-unit `acted_this_turn` flag + `turn_state` enum (IDLE / ACTING / DONE / DEAD); `ROUND_CAP = 30` (DRAW trigger); `CHARGE_THRESHOLD = 40` (Scout Ambush); round-start/round-end FSM (`ROUND_ACTIVE` ↔ `ROUND_ENDING`); CR-7a unit-removal-on-death semantics. | `get_acted_this_turn(unit_id) -> bool`; `get_current_round_number() -> int`; `get_current_unit() -> int`; `get_queue_snapshot() -> Array[UnitSlot]`. Emits via GameBus: `round_started(round: int)`, `unit_turn_started(unit_id)`, `unit_turn_ended(unit_id, acted_this_turn: bool)`. **Does NOT emit `battle_ended`** — ownership moved to Grid Battle (Feature) per ADR-0001 single-owner rule (systems-index row 13). | GameBus `unit_died(unit_id)` from HP/Status (CR-7a removes unit from queue + Grid Battle re-checks win condition); Unit Role (`get_initiative` at queue-build time, Core peer — permitted by invariant #4b case (a)); Hero DB (`stat_agility`); Balance/Data (`turn_order_config.json`). **INVARIANT TENSION**: GDD `turn-order.md:442` specifies a direct call `ai_system.request_action(unit_id, queue_snapshot) → ActionDecision` into AI (Feature) — violates invariant #4, must be inverted to signal-based. See blocker §1 below. | `signal` (3 emitted, 1 consumed via GameBus); `enum` for `turn_state`; `Array[UnitSlot]` with custom `sort_custom`. No post-cutoff API. **LOW risk.** |
| **Save/Load system** (#17 — VS, **Not Started**; GDD pending; ADR-0003 infra only) | `SaveContext` Resource (`schema_version: int`, `destiny_state: Dictionary`, `echo_marks: Array[EchoMark]`, scenario/party/chapter state); `EchoMark` payload Resource; `BattleOutcome.Result` enum (append-only rule per ADR-0001); `SaveMigrationRegistry: Dictionary[int, Callable]`; `MINIMUM_SCHEMA_VERSION` gate. Owns **what** is saved (schemas); SaveManager owns **how**. | `build_save_context() -> SaveContext` (collects current state from contributing Feature systems); `apply_loaded_context(ctx: SaveContext)` (restores to Feature systems); `register_migration(from_ver: int, migrator: Callable)`. Save/Load does NOT emit signals — it is invoked synchronously by ScenarioRunner (Feature) before SaveManager is asked to persist. | SaveManager (Platform) via its public API (`save_checkpoint(ctx)`, `load_slot(slot)`); Balance/Data (`MINIMUM_SCHEMA_VERSION`); contributing Feature-layer state (Scenario Progression, Destiny State, etc.) — **via opaque Resource references only** (invariant #6 reinforcement). | `Resource` + `@export` typed fields; `Resource.duplicate_deep()` (MEDIUM — 4.5+); `Dictionary[int, Callable]` for migration registry. **MEDIUM risk** via `duplicate_deep`. |

### Layer-invariant verification for the 12 modules (Platform + Foundation + Core)

Cross-checking every `Consumes` cell against the Phase 1 layer invariants (as refined below):

1. **Downward-only dependencies (invariant #1)** — every consumer is in a layer ≤ this module's layer. GameBus consumes nothing (Platform root). SceneManager + SaveManager consume only GameBus (Platform) + Balance/Data (Foundation, init-time only — acceptable; GameBus signal indirection keeps the dependency uni-directional at call-site). Map/Grid + Hero DB consume only Balance/Data (Foundation peer, init-time only — acceptable). Balance/Data + Input Handling consume nothing game-aware. Core layer consumers: Terrain Effect → Map/Grid (Foundation ✅); Unit Role → Hero DB + Balance/Data (Foundation ✅); HP/Status → Unit Role (Core peer, permitted by #4b case (a)); Turn Order → Unit Role + Hero DB + Balance/Data (#4b case (a)); Save/Load → SaveManager (Platform ✅). ✅ with one exception — see #4.
2. **Platform layer aware of no game systems (invariant #2)** — GameBus reads nothing. SceneManager + SaveManager read only infrastructure signals. ⚠️ SaveContext's **payload** contains game concepts, but SaveManager treats them as opaque Resources — schema lives in Core-layer Save/Load system #17 per invariant #6. ✅
3. **Foundation systems independent of each other (invariant #3)** — Map/Grid, Hero DB, Balance/Data, Input Handling have no inter-dependencies beyond init-time Balance/Data catalog reads. Buildable in any order provided Balance/Data lands first. ✅
4. **Core does not depend on Feature / Presentation / Polish (invariant #4, refined)** — one violation found: **Turn Order → AI** (Feature) via direct `ai_system.request_action()` call per GDD `turn-order.md:442`. Must be inverted to a signal-based contract (see blocker §1) before Turn Order ADR is written. All other Core modules comply. ❌ (blocking — must resolve)
4b. **Same-layer Core peers may call each other directly** only under stateless-rules or signal-indirection conditions (new invariant). HP/Status → Unit Role, Turn Order → Unit Role both satisfy case (a) (stateless rules module). HP/Status → Turn Order via GameBus `unit_died` satisfies case (b) (signal indirection). No circular same-layer Core dependencies. ✅
5. **Feature layer is the only layer allowed to emit `battle_*` and `scenario_*` signals** — not verified here (deferred to Feature-layer Phase 2 continuation). Turn Order does NOT emit `battle_ended` (ownership moved to Grid Battle per ADR-0001). ✅ by non-emission.
6. **Save/Load boundary (invariant #6)** — SaveManager owns I/O + atomicity; Save/Load system owns schema + migration. Confirmed. ✅

### Blocker notes raised during Phase 2

**Platform + Foundation blockers (carried from v0.2):**

- **Input Handling dual-focus × auto-detect** — Godot 4.6 introduces separate focus for mouse/touch vs. keyboard/gamepad. Input Handling GDD CR-2 ("auto-detect, last-device-wins, single mode") assumes a single focus-owning device. Before ADR-0005 is written, `godot-specialist` must verify `modules/input.md` + `modules/ui.md` and confirm whether the 7-state machine needs a mode-per-focus-channel split. Escalate as Open Question.
- ~~**Vulkan vs. D3D12 reconciliation**~~ — **resolved 2026-04-18** (committed per-platform: D3D12 Win / Vulkan Linux-Android / Metal macOS-iOS in `.claude/docs/technical-preferences.md`).

**Core blockers (new in v0.3):**

- **§1 — Turn Order → AI violates invariant #4** (hard, must resolve before Turn Order ADR lands). GDD `turn-order.md:442` specifies `ai_system.request_action(unit_id, queue_snapshot) → ActionDecision` as a direct synchronous call into a Feature-layer system. **Proposed inversion**: Turn Order emits `unit_turn_started(unit_id)` → AI System subscribes → AI emits `ai_action_decided(unit_id, decision: ActionDecision)` via GameBus → Turn Order advances on receipt (or on timeout fallback). Makes Turn Order signal-driven and layer-compliant. Must be ratified by `godot-specialist` before the Turn Order GDD revision (systems-index row 13 already says "Needs Revision"). Log as Open Question.
- **§2 — Save/Load system GDD does not exist yet**. Core-layer ownership above is **inferred from ADR-0003** + Scenario Progression v2.0 SaveContext references. Ownership row is provisional — must be validated when `design/gdd/save-load.md` is authored (Vertical Slice tier, `systems-designer` owner per design order #17). Treat entire Save/Load row as "⚠️ inferred — re-verify on GDD landing".
- **§3 — Invariant #4 refined** in this session. Original phrasing ("Core depends only on Foundation + Platform") forbade Unit Role ↔ HP/Status direct calls, which is unworkable. Split into #4 (no upward deps to Feature/Presentation/Polish) + #4b (same-layer Core peers allowed under stateless-rules or signal-indirection conditions). The System Layer Map §Layer invariants has been updated accordingly.

### Deferred scope (for next `/create-architecture` session)

Module Ownership for the remaining 22 modules is deferred:

- **Feature layer (13 modules)**: Grid Battle, Formation Bonus, Destiny Branch, Scenario Progression, Battle Prep, AI, Character Growth, Story Event, Damage Calc, Equipment, Destiny State, Class Conversion, Camera
- **Presentation layer (6 modules)**: Battle HUD, Battle Prep UI, Story Event UI, Main Menu, Battle VFX, Sound/Music
- **Polish layer (3 modules)**: Tutorial, Settings/Options, Localization

Pre-requisite for Feature ownership: GDDs for Damage/Combat Calc, Formation Bonus, Destiny Branch, AI must exist (currently Not Started). Authoring them in Track B unblocks Feature-layer Phase 2 continuation.

## Data Flow

_**TODO — Phase 3:** Not yet authored. Required flows: (1) Frame update path, (2) Event/signal path via GameBus, (3) Save/load path, (4) Initialisation order (GameBus → SceneManager → SaveManager → balance-data load → scene). Fill in next session._

## API Boundaries

_**TODO — Phase 4:** Not yet authored. Specific contracts needed for: Grid Battle↔HP/Status (unit_died), Grid Battle↔Turn Order (queue, acted_this_turn), Terrain Effect↔Damage Calc (stacking), Scenario Progression↔Save/Load (SaveContext), Input↔Camera (zoom clamp), UI dual-focus (all Presentation)._

## ADR Audit

_**TODO — Phase 5:** Partial. Existing ADRs (0001, 0002, 0003 Accepted; 0004 Proposed) are presumed compliant per `/architecture-review` PASS 2026-04-18. Phase 5 will formally audit:_
- _Engine Compatibility section on each_
- _GDD Requirements Addressed linkage against the 102-TR baseline_
- _Layer consistency with Phase 1 above_
- _Circular dependency check on "Depends On" edges_

## Required ADRs

_**TODO — Phase 6:** Will enumerate 8–12 additional ADRs grouped by priority (Must-have before coding / Should-have before relevant system / Can defer to implementation). Preview list in §System Layer Map above._

## Architecture Principles

_**TODO — Phase 7:** 3–5 binding principles derived from game pillars + technical preferences + GDD themes. Draft candidates:_
- _**Data-driven by default** — no gameplay constant hardcoded; all in `assets/data/*.json` (AC-20, balance-data TR-004)_
- _**Signals over singletons for game systems, autoloads only for infrastructure** — GameBus is the only cross-system communication path (ADR-0001)_
- _**Determinism in combat math** — no `randf()` without seeded RNG; every formula reproducible from SaveContext (implied by TR-gridbattle-\*, TR-hp-status-\*, TR-unit-role-\*)_
- _**Scene boundaries ≡ SceneManager transitions** — no direct `get_tree().change_scene_to_packed()` calls outside SceneManager (ADR-0002)_
- _**Budget before beauty** — mobile (512MB, 60fps, <500 draw calls) is the hard target; PC gets upscaled presentation (hybrid shader strategy)_

## Open Questions

_**TODO — Phase 7:** To be populated from GDD cross-references. Seed items from session state already identified:_
- _ADR for Damage/Combat Calculation — blocks 6 GDDs_
- ~~_Accessibility tier commitment_~~ ✅ resolved 2026-04-18 — **Intermediate** locked (`design/accessibility-requirements.md` v1.0); OQ-3 Settings/Options tier elevation resolved same day (Full Vision → Alpha in `design/gdd/systems-index.md`).
- _Dual-focus system (4.6) × Input Handling auto-detect (CR-2) coherence — verify before Input ADR_
- ~~_D3D12-on-Windows reconciliation_~~ ✅ resolved 2026-04-18 — per-platform backends committed
- _Scenario Progression v2.0 OQ bucket 3 → Godot 4.6 engine-reference verifications (dual-focus, recursive Control disable, Android 15 edge-to-edge safe-area, AccessKit reduced-motion hook)_

---

## Changelog

| Date | Version | Change |
|---|---|---|
| 2026-04-18 | 0.1 | Skeleton created. Phase 0 (knowledge gap + TR baseline) + Phase 1 (layer map) written. Phases 2–7 stubbed as TODO. |
| 2026-04-18 | 0.2 | Phase 2 Module Ownership written for Platform + Foundation layers (7 modules). Layer-invariant verification added. Core/Feature/Presentation/Polish ownership (24 modules) remains deferred. 2 new blocker notes logged (Input dual-focus verification, Vulkan/D3D12 reconciliation). |
| 2026-04-18 | 0.3 | Phase 2 Module Ownership extended to Core layer (5 modules — Terrain Effect, Unit Role, HP/Status, Turn Order, Save/Load system #17). Invariant #4 refined into #4 + #4b to permit stateless-rules same-layer peer calls. 3 new blocker notes logged (Turn Order → AI invariant violation requiring signal inversion; Save/Load GDD not yet authored — row is inferred; invariant #4 refinement). Feature/Presentation/Polish (22 modules) remain deferred. |
