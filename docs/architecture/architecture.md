# 천명역전 (Defying Destiny) — Master Architecture

## Document Status

| Field | Value |
|---|---|
| Version | 0.4 (partial-update: 5 ADR drift closed; Module Ownership refresh; Phase 5 ADR Audit populated; Phase 6 refreshed) |
| Last Updated | 2026-04-30 |
| Engine | Godot 4.6 (pinned 2026-04-16) |
| Language | GDScript |
| Review Mode | lean |
| GDDs Covered | 10 of 14 MVP (scan source: `design/gdd/`, 2026-04-18) |
| ADRs Referenced | 9 Accepted: ADR-0001/0002/0003 (2026-04-18) · ADR-0004 (2026-04-20) · ADR-0008 (2026-04-25) · ADR-0006/0012 (2026-04-26) · ADR-0009 (2026-04-28) · ADR-0007 (2026-04-30) |
| Technical Director Sign-Off | 2026-04-30 — **APPROVED WITH CONDITIONS** (partial-update v0.4 only; full sign-off pending Phase 3 Data Flow + Phase 4 API Boundaries + Phase 7 Architecture Principles authoring + Blocker §1 Turn Order → AI inversion via ADR-0011 + ADR-0001 line 372 prose drift cleanup) |
| Lead Programmer Feasibility | _deferred — LP-FEASIBILITY skipped per lean mode (`production/review-mode.txt`)_ |

### Completeness tracker

| Phase | Section | Status |
|---|---|---|
| 0 | Engine Knowledge Gap Summary | ✅ written |
| 0 | Technical Requirements Baseline | ✅ written (summary) + linked to `architecture-traceability.md` |
| 1 | System Layer Map | ✅ written |
| 2 | Module Ownership | ✅ Platform + Foundation + Core (12 modules) + first Feature module (Damage Calc, ADR-0012) written; 22 modules still deferred |
| 3 | Data Flow | ⏳ deferred |
| 4 | API Boundaries | ⏳ deferred |
| 5 | ADR Audit | ✅ written (9 Accepted ADRs audited 2026-04-30; 0 cross-conflicts blocking) |
| 6 | Required ADRs | ✅ refreshed 2026-04-30 (Foundation 4/5; net-new 4-8 before Pre-Prod gate) |
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
| **Foundation** | Map/Grid System (#14) | MVP | design/gdd/map-grid.md (ADR-0004 ✅ 2026-04-20) | LOW (TileMapLayer 4.3) |
| **Foundation** | Hero Database (#25) | MVP | design/gdd/hero-database.md (ADR-0007 ✅ 2026-04-30) | LOW (Resource system stable) |
| **Foundation** | Balance/Data System (#26) | MVP | design/gdd/balance-data.md (ADR-0006 ✅ 2026-04-26, MVP-scoped BalanceConstants ratification) | MEDIUM (FileAccess 4.4) |
| **Foundation** | Input Handling System (#29) | MVP | design/gdd/input-handling.md | **HIGH** (dual-focus 4.6, SDL3 4.5, Android edge-to-edge 4.5) |
| **Core** | Terrain Effect System (#2) | MVP | design/gdd/terrain-effect.md (ADR-0008 ✅ 2026-04-25) | LOW |
| **Core** | Unit Role System (#5) | MVP | design/gdd/unit-role.md (ADR-0009 ✅ 2026-04-28) | LOW |
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
| **Feature** | Damage/Combat Calculation (#11) | MVP | design/gdd/damage-calc.md rev 2.9.3 (ADR-0012 ✅ 2026-04-26 — first Feature-layer ADR) | LOW |
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
- ADR-0005 Input Handling — HIGH engine risk (dual-focus, SDL3, Android) — **sole Foundation gap (4/5 → 5/5 on landing)**
- ~~ADR-0006 Balance/Data~~ ✅ Accepted 2026-04-26 (MVP-scoped BalanceConstants ratification; full DataRegistry pipeline deferred to Alpha)
- ~~ADR-0007 Hero DB~~ ✅ Accepted 2026-04-30 (HeroData Resource + HeroDatabase static query layer)
- ~~ADR-0008 Terrain Effect~~ ✅ Accepted 2026-04-25 (note: Core layer, not Foundation as originally drafted)

**Core layer (must exist before the relevant system is built):**
- ADR-0010 HP/Status (status-effect stacking, mutual-exclusion contract; soft-dep'd by ADR-0012)
- ADR-0011 Turn Order signal ownership finalization + AI inversion (Blocker §1; soft-dep'd by ADR-0012)
- ADR for Save/Load #17 schema versioning (depends on Save/Load GDD authoring; may be covered by ADR-0003 follow-up)

**Feature layer (authored during Pre-Production):**
- ~~ADR-0012 Damage Calc formula ownership~~ ✅ Accepted 2026-04-26
- ADR for AI decision architecture (behavior-tree vs. utility-AI vs. state-machine; consumer of `get_class_passives`/`get_class_cost_table`)
- ADR for Grid Battle finalization (battle_ended ownership per ADR-0001 single-owner; SP-1 epic blocker)
- ADR for Destiny Branch resolution + Echo-gate signal contract
- ADR for Formation Bonus (consumer of HeroDatabase relationships + shared cap MAX_DEFENSE_REDUCTION=30)

**Presentation layer (authored before UI implementation):**
- ADR for UI dual-focus pattern (applies to all 6 UI screens)
- ADR for ink-wash shader pipeline + glow-before-tonemap interaction

**Count estimate (refreshed 2026-04-30):** 4–8 additional ADRs before Pre-Production → Production gate (down from 8–12 at v0.1; 5 ADRs landed since).

---

## Module Ownership

**Scope**: Platform + Foundation + Core layers + first Feature module (13 modules total). The remaining 22 Feature / Presentation / Polish modules are deferred to a subsequent `/create-architecture` session and marked as TODO at the end of this section.

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
| **Map/Grid** (ADR-0004 ✅ Accepted 2026-04-20) | `MapResource` (`Resource`, `Array[TileData]` flat-indexed `row * cols + col`); runtime `MapGrid extends Node` (child of BattleScene, battle-scoped lifecycle per ADR-0002); tile-state transitions (`EMPTY ↔ ALLY_OCCUPIED ↔ ENEMY_OCCUPIED ↔ DESTROYED`); packed hot-path caches (`PackedInt32Array` frontier, `PackedByteArray` visited); Dijkstra pathfinding + Bresenham LoS + elevation check. | `get_tile(coord: Vector2i) -> TileData`; `get_movement_range(unit, budget: int) -> Dictionary[Vector2i, int]`; `has_line_of_sight(a: Vector2i, b: Vector2i) -> bool`; mutation methods (all write-through to packed caches); emits **only** `tile_destroyed(coord: Vector2i)` via GameBus. Documented exception: this is the single Map/Grid signal ever permitted — all other Map/Grid communication is direct call. | **Nothing at runtime** (Foundation, by invariant). At init: loads `.tres` via `ResourceLoader.load`; reads terrain cost constants from Balance/Data's `balance_constants.json` once. | `Resource` + `@export` **inline sub-resources** (forbidden pattern `tile_data_external_subresource` — external UID-referenced TileData breaks `duplicate_deep` isolation per ADR-0004 R-3); `PackedInt32Array`, `PackedByteArray` (stable); `Vector2i`; **no** `AStarGrid2D` / `NavigationServer2D` (explicitly banned per CR-6 — forbidden pattern `astar_grid2d_for_tactical_pathfinding`); `TileMapLayer` for authoring preview only (4.3 stable — not runtime). LOW engine risk overall, MEDIUM on Resource `duplicate_deep` 4.5 dependency. |
| **Hero Database** (ADR-0007 ✅ Accepted 2026-04-30) | `assets/data/heroes/heroes.json` catalog → 26-field `HeroData` Resource per record, keyed in `Dictionary[StringName, HeroData]` lazy-cache (8–10 MVP / 50–100 Alpha; ~5KB/record × 100 = ~500KB << 512MB mobile ceiling). 3-tier severity validation: load-reject FATAL (hero_id format `^[a-z]+_\d{3}_[a-z_]+$`, duplicate hero_id, parallel-array length mismatch); per-record FATAL (stat ranges [1,100] / seed ranges / move_range [2,6] / growth [0.5,2.0]); WARNING (relationship self-ref / orphan FK / asymmetric conflict — load continues). F-1..F-4 stat-balance + SPI + growth-ceiling + MVP-roster validation **deferred to Polish-tier `tools/ci/lint_hero_database_validation.sh`** (BalanceConstants thresholds via ADR-0006 forward-compat). | 6 static query methods: `get_hero(hero_id: StringName) -> HeroData`; `get_heroes_by_faction(faction: HeroFaction) -> Array[HeroData]`; `get_heroes_by_class(unit_class: int) -> Array[HeroData]`; `get_all_hero_ids() -> Array[StringName]`; `get_mvp_roster() -> Array[HeroData]`; `get_relationships(hero_id: StringName) -> Array[Dictionary]`. Read-only contract — `forbidden_pattern hero_data_consumer_mutation` (R-1 mitigation regression test asserts mutation IS visible, proving convention is sole defense). **Non-emitter** per ADR-0001 line 372. | ADR-0006 Balance/Data (`BalanceConstants.get_const(key)` for forward-compat validation thresholds; **NOT consumed at runtime** in MVP — Polish-tier lint only). ADR-0009 Unit Role (`HeroData.default_class: int` 1:1 with `UnitRole.UnitClass` enum 0..5; semantic alignment, no call coupling). | `class_name HeroDatabase extends RefCounted` + `@abstract` (G-22 typed-reference parse-time block) + all-static + lazy-init; `HeroData extends Resource` + 26 `@export` fields incl. `Array[Dictionary]` for relationships + `Array[StringName]` for innate skills (Godot 4.4+ typed Dictionary stable); `FileAccess.get_file_as_string` (pre-4.4 stable, READ path only — 4.4 `store_*` change does NOT apply); `JSON.new().parse()` instance form for line/col diagnostics; `Resource.duplicate_deep()` (4.5+) for the `Array[Dictionary]` relationships field; G-15 `_heroes_loaded` reset in `before_test()` mandatory. **LOW engine risk** — 5th-precedent stateless-static pattern (ADR-0008→0006→0012→0009→0007). |
| **Balance/Data** (ADR-0006 ✅ Accepted 2026-04-26 — **MVP-scoped: BalanceConstants pattern**) | `BalanceConstants` static singleton (read-only); single lazy-load `Dictionary` cache; `assets/data/balance/balance_entities.json` (12+ keys; **renamed from `entities.json`** per Q3 design decision — `[system]_[name].json` rule compliance); 16 balance_constants registered via `entities.yaml` (source-of-truth registry separate from runtime data file). **MVP scope only** — full GDD `DataRegistry` 4-phase pipeline / VCR ≥ 1.0 / hot reload / `MINIMUM_SCHEMA_VERSION` gate / 9 `REQUIRED_CATEGORIES` / `PIPELINE_TIMEOUT_MS` is **Alpha-tier deferred** per ADR-0006 §Decision §MVP Scope. Ratifies the 2-precedent provisional pattern shipped in damage-calc story-006b PR #65 (2026-04-27) + terrain-effect story-003 PR #43. | `static func get_const(key: String) -> Variant` (sole public accessor). **No signals** — non-emitter per ADR-0001 line 372. **No reload** at MVP scope (Alpha addition). | `FileAccess` on `res://assets/data/balance/balance_entities.json`. Nothing else — root of Foundation. | `class_name BalanceConstants extends RefCounted` + `@abstract` + all-static + `static var _cache: Dictionary`; `FileAccess.get_file_as_string()` (pre-4.4 stable, READ path — 4.4 `store_*` change does NOT apply); `JSON.parse_string()` (pre-4.0 stable); G-15 `_cache_loaded` reset in `before_test()` mandatory for every consumer test (codified in `.claude/rules/godot-4x-gotchas.md`). **LOW engine risk** — no post-cutoff API. **Forward-compat migration**: future Alpha rename to `DataRegistry.get_const(key)` is mechanical (~5–8 call sites in `src/feature/damage_calc/` + `src/core/terrain_config.gd`; no semantic change). |
| **Input Handling** (⏳ ADR-0005) | `InputStateMachine` (7 states: `Observation`, `UnitSelected`, `MovementPreview`, `AttackTargetSelect`, `AttackConfirm`, `MenuOpen`, `InputBlocked`); 22-action vocabulary (10 grid + 4 camera + 5 menu + 3 meta); device-mode auto-detect (`KEYBOARD_MOUSE` / `TOUCH`, last-device-wins); Touch Tap Preview Protocol (80–120 px floating stats panel); per-unit undo window (1 move, closes on attack/wait/end-turn); 44 × 44 px touch-target enforcement via `camera_zoom_min = 0.70`. | Emits `input_action_fired(ctx: InputContext)`, `input_state_changed(from, to)`, `input_mode_changed(mode)` via GameBus. `default_bindings.json` lives at `assets/data/input/` for remapping. | `DisplayServer` query for screen metrics + safe-area insets. Listens to no other game system (consumes device events only). | `Input` singleton (stable); `InputMap` (⚠️ **4.5 SDL3 gamepad driver** changed the gamepad code path — verify against `docs/engine-reference/godot/modules/input.md` before ADR-0005); `InputEventMouseButton` / `InputEventScreenTouch` / `InputEventScreenDrag` / `InputEventKey` (stable); **Godot 4.6 dual-focus system** — Control focus for mouse/touch is now separate from keyboard/gamepad focus (⚠️ affects state-machine assumption that focus is single-valued — see blocker note below); Android **edge-to-edge / safe-area** APIs (4.5, HIGH); `DisplayServer.screen_get_size` for dynamic touch-target clamp. **HIGH engine risk** overall — see blocker note. |

### Core layer (5 modules — 4 MVP with GDDs, 1 VS Not Started)

| Module | Owns | Exposes | Consumes | Engine APIs used |
|---|---|---|---|---|
| **Terrain Effect** (#2 — MVP, Designed; ADR-0008 ✅ Accepted 2026-04-25) | 8 terrain types per CR-1 table (PLAINS 0/0, HILLS 15/0, MOUNTAIN 20/5, FOREST 5/15, RIVER 0/0, BRIDGE 5/0 + `bridge_no_flank` flag, FORTRESS_WALL 25/0, ROAD 0/0) — `defense_bonus` / `evasion_bonus` / `special_rules`; `MAX_DEFENSE_REDUCTION = 30` symmetric clamp [-30,+30] (negative defense allowed per CR-3e + EC-1); `MAX_EVASION = 30`; asymmetric elevation modifiers (delta ±1 → ±8%, ±2 → ±15%, sub-linear per CR-2); `cost_multiplier(unit_type, terrain_type)` matrix STRUCTURE owned here (uniform=1 MVP placeholder; ADR-0009 ratifies unit-class dimension via `get_class_cost_table`); `bridge_no_flank` semantics — BRIDGE converts FLANK → FRONT for defender (CR-5b), REAR remains REAR (CR-5c). **Stateless** — pure rules calculator. | 3 static query methods per CR-4: `TerrainEffect.get_terrain_modifiers(coord) -> TerrainModifiers`; `get_combat_modifiers(atk, def) -> CombatModifiers` (returns already-clamped `terrain_def ∈ [-30,+30]` + `terrain_evasion ∈ [0,30]` per cross-system contract with damage-calc.md §F); `get_terrain_score(coord) -> float` (AI use, elevation-agnostic). Shared cap accessors `max_defense_reduction()` / `max_evasion()` — single source of truth for Formation Bonus + Damage Calc. **No signals** — non-emitter per ADR-0001; `terrain_changed` was rejected at /architecture-review (cache-invalidation pattern via direct subscription to `tile_destroyed`). | Map/Grid (`get_tile(coord)` for `terrain_type` + `elevation`; ADR-0004 §5b 3-arg `get_attack_direction` for FLANK→FRONT decoration — the bridge override happens HERE, not in Map/Grid). Balance/Data (reads `assets/data/terrain/terrain_config.json` — this system OWNS the file); subscribes to GameBus `tile_destroyed(coord)` from Map/Grid (cache invalidation when caching is later added). | `class_name TerrainEffect extends RefCounted` + `@abstract` + all-static + lazy-init JSON config (1st of 5-precedent stateless-static pattern: ADR-0008→0006→0012→0009→0007); `Resource` + `@export` for `TerrainModifiers` + `CombatModifiers` typed wrappers; `JSON.new().parse()` instance form for line/col diagnostics; `Vector2i`; `Dictionary[int, TerrainModifiers]` keyed by terrain enum int; G-15 `_config_loaded` reset in `before_test()` mandatory; performance budget AC-21 `get_combat_modifiers()` <0.1ms (100 calls/frame at 60fps). **LOW risk** — no post-cutoff API. |
| **Unit Role** (#5 — MVP, Designed; ADR-0009 ✅ Accepted 2026-04-28) | 6 classes per CR-1 — typed `enum UnitClass { CAVALRY=0, INFANTRY=1, ARCHER=2, STRATEGIST=3, COMMANDER=4, SCOUT=5 }` (improved over ADR-0008's raw `int terrain_type` per godot-specialist 2026-04-28 — typed-enum parameter binding produces stricter parse-time errors at call sites); `assets/data/config/unit_roles.json` 6×12 schema (per-class coefficients + cost matrix unit-class dimension + 6×3 `CLASS_DIRECTION_MULT` table); F-1..F-5 derived-stat formulas with explicit clamp ranges (`[1,ATK_CAP]`, `[1,DEF_CAP]`, `[HP_FLOOR+1,HP_CAP]`, `[1,INIT_CAP]`, `[MOVE_RANGE_MIN,MOVE_RANGE_MAX]`); 1 const `PASSIVE_TAG_BY_CLASS` Dictionary mapping each class to its canonical StringName tag (`&"passive_charge"`, `&"passive_shield_wall"`, `&"passive_high_ground_shot"`, `&"passive_tactical_read"`, `&"passive_rally"`, `&"passive_ambush"`); STRATEGIST/COMMANDER `CLASS_DIRECTION_MULT` rows are all-1.0 no-ops by design (their class identity is expressed elsewhere — Tactical Read evasion bypass + Rally adjacency aura). **Stateless** — pure calculator; produces derived stats on demand. | 8 static methods + 1 const per CR-3: `UnitRole.get_atk(hero: HeroData, unit_class: UnitClass) -> int`; `get_phys_def(...)`; `get_mag_def(...)`; `get_max_hp(...)`; `get_initiative(...)`; `get_effective_move_range(...) -> int`; `get_class_cost_table(unit_class: UnitClass) -> PackedFloat32Array` (6-entry, indexed by terrain_type — ratifies ADR-0008 cost-matrix unit-class dimension placeholder); `get_class_direction_mult(unit_class: UnitClass, dir: int) -> float`; const `PASSIVE_TAG_BY_CLASS: Dictionary` (read-only). Orthogonal per-stat (NOT bundled `UnitStats` Resource — rejected as Alternative 4). **No signals** — non-emitter per ADR-0001 line 375 (codified `forbidden_pattern unit_role_signal_emission`). | ADR-0007 Hero DB (`HeroData` typed Resource parameter — 7 fields read: `stat_might`, `stat_intellect`, `stat_command`, `stat_agility`, `base_hp_seed`, `base_initiative_seed`, `move_range`; soft-dep ratified 2026-04-30). ADR-0006 Balance/Data (`BalanceConstants.get_const(key)` for 10 global caps: `ATK_CAP`, `DEF_CAP`, `HP_CAP`, `HP_SCALE`, `HP_FLOOR`, `INIT_CAP`, `INIT_SCALE`, `MOVE_RANGE_MIN`, `MOVE_RANGE_MAX`, `MOVE_BUDGET_PER_RANGE`). ADR-0008 Terrain Effect (cost-matrix STRUCTURE — terrain_type dimension; UnitRole owns the unit-class dimension and exposes per-class table). | `class_name UnitRole extends RefCounted` + `@abstract` (G-22 parse-time-on-typed-reference enforcement, runtime error on `.new()`; reflective bypass with no `push_error`) + all-static + lazy-init `JSON.new().parse()`; typed `enum UnitClass`; `PackedFloat32Array` per-call copy (Godot 4.x COW); `Array[StringName]` typed-array discipline (per ADR-0012 EC-DC-25 precedent); `clampi`/`clamp`/`floori` for cap enforcement. **R-1 mitigation**: `forbidden_pattern unit_role_returned_array_mutation` codified — caller-mutation regression test mandatory per §Validation Criteria §6. G-15 `_cache_loaded` reset in `before_test()` per ADR-0006 §6 obligation; per-method latency budget <0.05ms headless CI. **LOW engine risk** — no post-cutoff API; 4-precedent stateless-static pattern (ADR-0008→0006→0012→0009). |
| **HP/Status** (#12 — MVP, Designed; ⏳ ADR needed for status-effect stacking contract) | Per-unit `current_hp` / `max_hp` / `status_effects[]` (StatusEffect Resource with `id`, `icon`, `remaining_turns`, `modifier_values`); DoT pipeline (POISON: `DOT_HP_RATIO`, `DOT_FLAT`, `DOT_MIN`, `DOT_MAX_PER_TURN`); healing pipeline (`HEAL_BASE`, `HEAL_HP_RATIO`, `HEAL_PER_USE_CAP`, `EXHAUSTED_HEAL_MULT`); morale system (DEMORALIZED / INSPIRED / DEFEND_STANCE with radius, turn-cap, recovery); stat-modifier arithmetic with `MODIFIER_FLOOR` / `MODIFIER_CEILING` clamp. | `is_alive(unit) -> bool`; `apply_damage(unit, amount, source) -> int` (returns actual damage after mitigation); `apply_heal(unit, amount) -> int`; `tick_dot_effects(unit_id) -> bool` (returns true if unit died); `get_status_effects(unit) -> Array[StatusEffect]`; `modified_move_range(unit) -> int`. Emits `unit_died(unit_id)` via GameBus (single authoritative emitter per ADR-0001). | Hero DB (`base_hp_seed`, `is_morale_anchor`); Unit Role (`get_max_hp`, Core peer — permitted by invariant #4b case (a) stateless rules module); Balance/Data (`hp_status_config.json`, `balance_constants.json`). Mutations arrive via direct method calls from Damage Calc (Feature, above) — **upward call inversion required**: Damage Calc must call `apply_damage()` as a downward call, not HP/Status calling into Damage Calc. | `Resource` for `StatusEffect`; `signal unit_died(unit_id: int)`; `Dictionary[int, Array[StatusEffect]]`. No post-cutoff API. **LOW risk.** |
| **Turn Order / Action Management** (#13 — MVP, Needs Revision; ⏳ ADR needed for AI-inversion signal contract) | Initiative queue (sorted by `(initiative DESC, stat_agility DESC, is_player_controlled DESC, unit_id ASC)`); `current_round_number`; per-unit `acted_this_turn` flag + `turn_state` enum (IDLE / ACTING / DONE / DEAD); `ROUND_CAP = 30` (DRAW trigger); `CHARGE_THRESHOLD = 40` (Scout Ambush); round-start/round-end FSM (`ROUND_ACTIVE` ↔ `ROUND_ENDING`); CR-7a unit-removal-on-death semantics. | `get_acted_this_turn(unit_id) -> bool`; `get_current_round_number() -> int`; `get_current_unit() -> int`; `get_queue_snapshot() -> Array[UnitSlot]`. Emits via GameBus: `round_started(round: int)`, `unit_turn_started(unit_id)`, `unit_turn_ended(unit_id, acted_this_turn: bool)`. **Does NOT emit `battle_ended`** — ownership moved to Grid Battle (Feature) per ADR-0001 single-owner rule (systems-index row 13). | GameBus `unit_died(unit_id)` from HP/Status (CR-7a removes unit from queue + Grid Battle re-checks win condition); Unit Role (`get_initiative` at queue-build time, Core peer — permitted by invariant #4b case (a)); Hero DB (`stat_agility`); Balance/Data (`turn_order_config.json`). **INVARIANT TENSION**: GDD `turn-order.md:442` specifies a direct call `ai_system.request_action(unit_id, queue_snapshot) → ActionDecision` into AI (Feature) — violates invariant #4, must be inverted to signal-based. See blocker §1 below. | `signal` (3 emitted, 1 consumed via GameBus); `enum` for `turn_state`; `Array[UnitSlot]` with custom `sort_custom`. No post-cutoff API. **LOW risk.** |
| **Save/Load system** (#17 — VS, **Not Started**; GDD pending; ADR-0003 infra only) | `SaveContext` Resource (`schema_version: int`, `destiny_state: Dictionary`, `echo_marks: Array[EchoMark]`, scenario/party/chapter state); `EchoMark` payload Resource; `BattleOutcome.Result` enum (append-only rule per ADR-0001); `SaveMigrationRegistry: Dictionary[int, Callable]`; `MINIMUM_SCHEMA_VERSION` gate. Owns **what** is saved (schemas); SaveManager owns **how**. | `build_save_context() -> SaveContext` (collects current state from contributing Feature systems); `apply_loaded_context(ctx: SaveContext)` (restores to Feature systems); `register_migration(from_ver: int, migrator: Callable)`. Save/Load does NOT emit signals — it is invoked synchronously by ScenarioRunner (Feature) before SaveManager is asked to persist. | SaveManager (Platform) via its public API (`save_checkpoint(ctx)`, `load_slot(slot)`); Balance/Data (`MINIMUM_SCHEMA_VERSION`); contributing Feature-layer state (Scenario Progression, Destiny State, etc.) — **via opaque Resource references only** (invariant #6 reinforcement). | `Resource` + `@export` typed fields; `Resource.duplicate_deep()` (MEDIUM — 4.5+); `Dictionary[int, Callable]` for migration registry. **MEDIUM risk** via `duplicate_deep`. |

### Feature layer (1 module ratified — 12 still deferred)

The first Feature-layer ADR (Damage Calc, ADR-0012 Accepted 2026-04-26) is the only Feature module with full ownership specified at this time. The remaining 12 Feature modules (Grid Battle, Formation Bonus, Destiny Branch, Scenario Progression, Battle Prep, AI, Character Growth, Story Event, Equipment, Destiny State, Class Conversion, Camera) remain deferred — see §Deferred scope below.

| Module | Owns | Exposes | Consumes | Engine APIs used |
|---|---|---|---|---|
| **Damage Calc** (#11 — MVP, Designed rev 2.9.3; ADR-0012 ✅ Accepted 2026-04-26 — first Feature-layer ADR) | 4 typed `RefCounted` wrapper classes (`AttackerContext`, `DefenderContext`, `ResolveModifiers`, `ResolveResult`) replacing the legacy Dictionary payload; 12 ordered Core Rules CR-1..CR-12 + 7 sub-formulas F-DC-1..F-DC-7; **3-tier cap layering in NON-NEGOTIABLE order**: `BASE_CEILING = 83` (pre-multipliers, F-DC-3) → `P_MULT_COMBINED_CAP = 1.31` (post-passive composition, F-DC-5) → `DAMAGE_CEILING = 180` (post-direction-passive, F-DC-6); apex hardest primary-path hit (Cavalry REAR + Charge + Rally(+10%) + Formation(+5%) ATK 200 vs DEF 10) = `floori(83 × 1.64 × 1.31) = 178` post P_MULT_COMBINED_CAP; 2 owned tuning constants in `entities.yaml` (`TK-DC-1 CHARGE_BONUS = 1.20`, `TK-DC-2 AMBUSH_BONUS = 1.15`); F-GB-PROV (Grid Battle provisional formula in `grid-battle.md` §CR-5 Step 7) **retired in same patch** as `damage_resolve` registration in `entities.yaml` — CI grep gate AC-DC-44. **Stateless** — no internal mutable state, no I/O, no signals. Same inputs → same output (deterministic). | Single static entry point: `DamageCalc.resolve(atk: AttackerContext, def: DefenderContext, mods: ResolveModifiers) -> ResolveResult`. Direct-call interface from Grid Battle ONLY — no other caller permitted; `apply_damage()` is invoked by Grid Battle on the result, never by DamageCalc itself (CR-1 stateless invariant). Per-call seeded RNG via `ResolveModifiers.rng` (typed `RandomNumberGenerator` injection) — call-count-stable contract: 1/0/0 per non-counter/counter/skill-stub. `source_flags`: always-new-Array semantics; never mutate caller; error-flag vocabulary via `.has(&"invariant_violation:reason")`. **No signals emitted, no signal subscriptions** — on ADR-0001 non-emitter list line 375; codified as `forbidden_pattern damage_calc_signal_emission`. | 5 upstream READ-ONLY interfaces: **HP/Status** (⏳ ADR-0010 soft / provisional) — `get_modified_stat(unit_id: StringName, stat_name: String) -> int` returning effective stats with all buffs/debuffs and DEFEND_STANCE penalty pre-folded; MIN_DAMAGE ≥ 1 contract. **Terrain Effect** (ADR-0008) — `get_combat_modifiers(atk, def) -> CombatModifiers` returning already-clamped `terrain_def ∈ [-30,+30]` + `terrain_evasion ∈ [0,30]`. **Unit Role** (ADR-0009) — `CLASS_DIRECTION_MULT[6][3]` table + `BASE_DIRECTION_MULT[3]` vector via `get_class_direction_mult(unit_class, dir)`; runtime read goes through `assets/data/config/unit_roles.json` (per-class data locality), NOT through BalanceConstants. **Turn Order** (⏳ ADR-0011 soft / provisional) — `get_acted_this_turn(unit_id: StringName) -> bool` for the Scout Ambush gate. **Balance/Data** (ADR-0006) — `BalanceConstants.get_const(key)` for 11 constants (9 consumed + 2 owned via TK-DC-1/2). | `class_name DamageCalc extends RefCounted` + all-static (sole entry point: static `resolve()`); 4 typed `RefCounted` wrapper classes (`@export` on wrapper Resources for inspector + test fixture authoring); `Array[StringName]` typed-array discipline + StringName literal release-build defense (`damage_calc_dictionary_payload` forbidden_pattern); `RandomNumberGenerator` per-call injection; `randi_range(from, to)` inclusive both ends (mandatory CI pin via AC-DC-49); `snappedf(0.005, 0.01) == 0.01` AND `snappedf(-0.005, 0.01) == -0.01` (round-half-away-from-zero, mandatory CI pin via AC-DC-50). `AttackerContext.unit_class` field renamed from `class` (GDScript reserved keyword since 4.0 / GDScript 2.0 — not 4.6 as GDD rev 2.4 changelog implies). **Test infrastructure prerequisites locked**: headless CI per push + headed CI via `xvfb-run` weekly + `rc/*` tag; cross-platform matrix macOS-Metal/Windows-D3D12/Linux-Vulkan (divergence = WARN, not hard ship-block per AC-DC-37 softened contract); GdUnitTestSuite extends Node base for AC-DC-51(b) bypass-seam; gdUnit4 addon pinned to **v6.1.2** matching Godot 4.6 LTS. **Performance**: 50µs avg headless / <1ms p99 mobile (AC-DC-40b — minimum-spec ARMv8 ≥4GB RAM Adreno 610 / Mali-G57 class, Android 12+/iOS 15+); zero Dictionary alloc inside `resolve()` body except `build_vfx_tags`. **LOW engine risk** — no post-cutoff API; 3rd of 5-precedent stateless-static pattern. |

### Layer-invariant verification for the 13 modules (Platform + Foundation + Core + first Feature)

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

- **Feature layer (12 modules; Damage Calc ratified 2026-04-26 by ADR-0012, see §Feature layer above)**: Grid Battle, Formation Bonus, Destiny Branch, Scenario Progression, Battle Prep, AI, Character Growth, Story Event, Equipment, Destiny State, Class Conversion, Camera
- **Presentation layer (6 modules)**: Battle HUD, Battle Prep UI, Story Event UI, Main Menu, Battle VFX, Sound/Music
- **Polish layer (3 modules)**: Tutorial, Settings/Options, Localization

Pre-requisite for Feature ownership: GDDs for Damage/Combat Calc, Formation Bonus, Destiny Branch, AI must exist (currently Not Started). Authoring them in Track B unblocks Feature-layer Phase 2 continuation.

## Data Flow

_**TODO — Phase 3:** Not yet authored. Required flows: (1) Frame update path, (2) Event/signal path via GameBus, (3) Save/load path, (4) Initialisation order (GameBus → SceneManager → SaveManager → balance-data load → scene). Fill in next session._

## API Boundaries

_**TODO — Phase 4:** Not yet authored. Specific contracts needed for: Grid Battle↔HP/Status (unit_died), Grid Battle↔Turn Order (queue, acted_this_turn), Terrain Effect↔Damage Calc (stacking), Scenario Progression↔Save/Load (SaveContext), Input↔Camera (zoom clamp), UI dual-focus (all Presentation)._

## ADR Audit

**9 Accepted ADRs as of 2026-04-30**. Audit derived from `/architecture-review` chain (2026-04-18 baseline + 5 delta passes 2026-04-20 / -25 / -26 / -28 / -30 — all PASS verdicts) cross-referenced against `architecture-traceability.md` v0.6 + `tr-registry.yaml` v7. Pattern stable at **5 invocations** of fresh-session /architecture-review for single-ADR escalation.

| ADR | Engine Compat | Version | GDD Linkage (TR coverage) | Conflicts / Corrections | Valid |
|---|---|---|---|---|---|
| **ADR-0001** GameBus | ✅ LOW (signals stable since 4.0) | 4.6 | ✅ TR-gamebus-001 + 7 cross-system signal ratifications (TR-scenario-progression-001..003, TR-grid-battle-001, TR-turn-order-001, TR-hp-status-001, TR-input-handling-001) | ⚠️ Line 372 prose drift `hero_database.get(unit_id)` vs ratified `HeroDatabase.get_hero(hero_id: StringName)` — **advisory carried** (non-blocking; defer to next ADR-0001 amendment) | ✅ Accepted 2026-04-18 |
| **ADR-0002** SceneManager | ✅ MEDIUM (recursive Control disable 4.5) | 4.6 | ✅ TR-scene-manager-001..005 (5/5) | None | ✅ Accepted 2026-04-18 |
| **ADR-0003** SaveManager | ✅ MEDIUM (FileAccess 4.4 + duplicate_deep 4.5) | 4.6 | ✅ TR-save-load-001..007 (7/7) | None | ✅ Accepted 2026-04-18 |
| **ADR-0004** Map/Grid | ✅ LOW (TileMapLayer 4.3 + duplicate_deep 4.5 R-3 inline-only constraint) | 4.6 | ✅ TR-map-grid-001..010 (10/10) | None (delta review #1 PASS) | ✅ Accepted 2026-04-20 |
| **ADR-0006** Balance/Data | ✅ LOW (FileAccess READ path 4.4 unaffected; ratifies shipped+test-verified PR #65) | 4.6 | ⚠️ **MVP scope only** — `BalanceConstants.get_const(key)` pattern ratified; full GDD `DataRegistry` 4-phase pipeline + VCR + hot reload + 9 categories deferred to Alpha (9 candidate `balance-data.*` TRs partially covered; full TR registration pending Alpha-tier ADR superseding) | None | ✅ Accepted 2026-04-26 (MVP-scoped) |
| **ADR-0007** Hero DB | ✅ LOW (no post-cutoff API) | 4.6 | ✅ TR-hero-database-001..015 (15/15) | 2 wording corrections applied pre-acceptance (Item 3: §2 `default_class` rationale "silent fallback to int storage" → "inspector-authoring instability when cross-script enum fails to resolve"; Item 8: §2 Resource overhead ~5KB/record × 100 vs 512MB ceiling acknowledgement + asymmetry rationale with ADR-0012 RefCounted) | ✅ Accepted 2026-04-30 |
| **ADR-0008** Terrain Effect | ✅ LOW (no post-cutoff API; JSON int/float coercion CLOSED 2026-04-25) | 4.6 | ✅ TR-terrain-effect-001..018 (18/18) | None (delta review #2 PASS; godot-specialist APPROVED WITH SUGGESTIONS, all suggestions applied this pass) | ✅ Accepted 2026-04-25 |
| **ADR-0009** Unit Role | ✅ LOW (typed enum parameter binding stable since 4.0; improved over ADR-0008's raw int) | 4.6 | ✅ TR-unit-role-001..012 (12/12); 23 GDD ACs map at finer granularity to ADR-0009 §GDD Requirements Addressed | 2 corrections applied: §1 line 130 `parse-time error` → `runtime error` for `UnitRole.new()` under `@abstract` (per G-22 empirical discovery, story-001 round 3); ADR-0012 line 42 dependency `CLASS_DIRECTION_MULT[4][3]` → `[6][3]` same-patch amendment (no behavioral change) | ✅ Accepted 2026-04-28 |
| **ADR-0012** Damage Calc | ✅ LOW (randi_range/snappedf pinned via mandatory CI tests AC-DC-49 + AC-DC-50; no post-cutoff API) | 4.6 | ✅ TR-damage-calc-001..013 (13/13); 53 GDD ACs map to ADR-0012 §GDD Requirements Addressed via 11-category coverage matrix | 2 wording corrections applied (AF-1 + Item 3); 1 advisory carried (AF-3 — non-blocking) | ✅ Accepted 2026-04-26 |

### Audit summary

- **9/9 Accepted ADRs** have Engine Compatibility section (LOW/MEDIUM risk classified; no HIGH-risk ADR has shipped yet — next ADR-0005 Input Handling will be the first HIGH-risk).
- **9/9 ADRs** have GDD Requirements Addressed linkage to `tr-registry.yaml` (88/88 registered TRs are 1-to-1 mapped).
- **0 cross-ADR layer-consistency violations** detected by `/architecture-review` chain (Phase 1 layer assignments respected by every ADR's Depends On / Enables / Blocks edges).
- **0 circular dependencies** in Depends On graph (verified by `/architecture-review` 2026-04-30 cross-conflict scan).
- **1 advisory carried**: ADR-0001 line 372 prose drift (`hero_database.get(unit_id)` → `HeroDatabase.get_hero(hero_id: StringName)`) — non-blocking, defer to next ADR-0001 amendment.
- **1 design-time invariant violation open**: Blocker §1 (Turn Order → AI direct call per `turn-order.md:442` violates layer invariant #4) — awaits ADR-0011 Turn Order signal-inversion ratification.
- **Stateless-static utility class form** is now the project-wide pattern at **5 invocations** (ADR-0008 → 0006 → 0012 → 0009 → 0007); future Foundation/Core data-layer ADRs (Skill/Ability, Formation Bonus, Equipment/Item, Character Growth) should adopt unless domain-specific divergence is justified.

## Required ADRs

Refreshed 2026-04-30 against `architecture-traceability.md` v0.6 coverage summary. Foundation layer at **4/5 Complete** (only Input Handling remaining); Core at **1/2** (Terrain Effect Accepted; HP/Status + Turn Order pending); Feature at **1/3** (Damage Calc Accepted; AI / Grid Battle / Destiny Branch / Formation Bonus pending); Presentation at **0/1** (dual-focus pattern); Polish at **0/1** (Accessibility, gated on tier commit — already resolved 2026-04-18).

### Must have before coding starts (Foundation & Core decisions)

- **ADR-0005 Input Handling** — **HIGH engine risk** (dual-focus 4.6 + SDL3 4.5 + Android edge-to-edge 4.5); **sole Foundation gap**; landing brings layer 4/5 → 5/5 Complete; required consultation: `godot-specialist` against `docs/engine-reference/godot/modules/input.md` + `modules/ui.md`. Resolves Open Question on dual-focus × auto-detect (CR-2) coherence.
- **ADR-0010 HP/Status** — Core gap; status-effect stacking + DEFEND_STANCE / EXHAUSTED mutual-exclusion contract; DoT pipeline; morale system; `unit_died` signal emitter authority per ADR-0001 single-owner. **Soft-dep'd by ADR-0012** §Dependencies (`get_modified_stat` interface); ADR-0012 will hard-pin on landing.
- **ADR-0011 Turn Order** — Core gap; signal ownership finalization (`round_started`, `unit_turn_started`, `unit_turn_ended`); resolves **Blocker §1** (Turn Order → AI direct-call invariant violation per `turn-order.md:442` — must invert to signal-driven `ai_action_decided` contract). **Soft-dep'd by ADR-0012** §Dependencies (`get_acted_this_turn` interface).

### Should have before the relevant system is built

- **ADR for Save/Load #17 schema versioning** — depends on Save/Load GDD authoring (Vertical Slice tier per systems-index #17); may be covered by ADR-0003 follow-up amendment rather than a standalone ADR. Treat the inferred Save/Load row in §Module Ownership above as provisional until the GDD lands.
- **ADR for AI decision architecture** — behavior-tree vs. utility-AI vs. state-machine; consumer of `get_class_passives` (PASSIVE_TAG_BY_CLASS) + `get_class_cost_table` from ADR-0009. Required for Grid Battle Vertical Slice + Blocker §1 inversion (must subscribe to `unit_turn_started` and emit `ai_action_decided`).
- **ADR for Grid Battle finalization** — `battle_ended` ownership per ADR-0001 single-owner rule (Turn Order does NOT emit it; Grid Battle owns); `BattleOutcome` Result enum (append-only per ADR-0003); SP-1 epic blocker.
- **ADR for Formation Bonus** — consumer of HeroDatabase `get_relationships` + shared cap `MAX_DEFENSE_REDUCTION = 30` from ADR-0008; per-unit cap `0.05` formation_def_bonus; integration with Damage Calc `ResolveModifiers.formation_atk_bonus` / `formation_def_bonus` fields.
- **ADR for Destiny Branch resolution + Echo-gate signal contract** — pillar-defining system (game pillar #2); must lock 15–20 destiny branch conditions with cascading impact + EchoMark payload contract.
- **ADR for UI dual-focus pattern** — applies to all 6 Presentation-layer UI screens (Battle HUD, Battle Prep UI, Story Event UI, Main Menu, plus Settings/Options + Tutorial); **the first UI ADR establishes the pattern** for the rest, or the project accepts that every screen gets its own ADR. HIGH engine risk per Knowledge Gap Summary.

### Can defer to implementation

- **ADR for ink-wash shader pipeline + glow-before-tonemap interaction** — Battle VFX-tier; HIGH engine risk (4.6 glow rework processes BEFORE tonemapping). Hybrid shader strategy (heroes individual ShaderMaterial + soldiers baked textures) may need ratification too.
- **ADR for SDL3 gamepad strategy** — post-MVP Polish-tier; tech-preferences already pins gamepad as Partial (future addition). Defer until gamepad becomes a primary input.
- **ADR for Localization / i18n** — Full Vision tier per systems-index #30; MEDIUM engine risk (CSV plural forms 4.6 changes).
- **ADR for Accessibility** — tier commit already at **Intermediate** (resolved 2026-04-18 per `design/accessibility-requirements.md` v1.0); HIGH engine risk only on AccessKit Advanced-tier promotion (out of scope at MVP). Settings/Options tier elevation also resolved 2026-04-18 (Full Vision → Alpha).

### Net-new count to Pre-Production → Production gate

**4–8 ADRs** required before gate (down from 8–12 at v0.1 baseline; 5 ADRs landed 2026-04-20 through 2026-04-30):

- **Mandatory** (3): ADR-0005 Input Handling + ADR-0010 HP/Status + ADR-0011 Turn Order
- **Strongly recommended** (3): AI + Grid Battle + Formation Bonus (all on Vertical Slice critical path)
- **Recommended-if-VS-includes-them** (1–2): UI dual-focus pattern + Destiny Branch (Destiny Branch is pillar-defining; UI dual-focus deferrable if VS uses single-screen layout)

Per traceability v0.6: `hero-database` Foundation epic now eligible for `/create-epics` (ADR-0007 just landed); Foundation layer can complete to 5/5 with one more ADR pass (ADR-0005). Core layer + first 2 Feature ADRs (HP/Status + Turn Order) are the next-3-ADR critical path.

## Architecture Principles

_**TODO — Phase 7:** 3–5 binding principles derived from game pillars + technical preferences + GDD themes. Draft candidates:_
- _**Data-driven by default** — no gameplay constant hardcoded; all in `assets/data/*.json` (AC-20, balance-data TR-004)_
- _**Signals over singletons for game systems, autoloads only for infrastructure** — GameBus is the only cross-system communication path (ADR-0001)_
- _**Determinism in combat math** — no `randf()` without seeded RNG; every formula reproducible from SaveContext (implied by TR-gridbattle-\*, TR-hp-status-\*, TR-unit-role-\*)_
- _**Scene boundaries ≡ SceneManager transitions** — no direct `get_tree().change_scene_to_packed()` calls outside SceneManager (ADR-0002)_
- _**Budget before beauty** — mobile (512MB, 60fps, <500 draw calls) is the hard target; PC gets upscaled presentation (hybrid shader strategy)_

## Open Questions

Refreshed 2026-04-30 against /architecture-review chain + Module Ownership Blocker notes. Phase 7 full Architecture Principles authoring still deferred; Open Questions list is the running cross-system tracker.

### Closed since v0.1 baseline

- ~~**ADR for Damage/Combat Calculation**~~ ✅ resolved 2026-04-26 — ADR-0012 Accepted; F-GB-PROV retired same-patch with `damage_resolve` registration in `entities.yaml`.
- ~~**Accessibility tier commitment**~~ ✅ resolved 2026-04-18 — **Intermediate** locked (`design/accessibility-requirements.md` v1.0); OQ-3 Settings/Options tier elevation resolved same day (Full Vision → Alpha in `design/gdd/systems-index.md`).
- ~~**D3D12-on-Windows reconciliation**~~ ✅ resolved 2026-04-18 — per-platform backends committed.
- ~~**HeroData Resource shape**~~ ✅ resolved 2026-04-30 — ADR-0007 Accepted; 26 fields ratified; closed ADR-0009's only outstanding upstream soft-dep.
- ~~**Cost-matrix unit-class dimension**~~ ✅ resolved 2026-04-28 — ADR-0009 ratified ADR-0008's placeholder via `get_class_cost_table(UnitClass) -> PackedFloat32Array`.
- ~~**`battle_outcome_resolved` rename cascade**~~ ✅ resolved per ADR-0001 §Changelog 2026-04-18 — Grid Battle / Turn Order / Scenario Progression aligned.

### Open — must resolve before relevant ADR lands

- **Dual-focus system (4.6) × Input Handling auto-detect (CR-2) coherence** — Godot 4.6 splits mouse/touch focus from keyboard/gamepad focus; Input GDD CR-2 ("auto-detect, last-device-wins, single mode") assumes single focus-owning device. Must verify against `docs/engine-reference/godot/modules/input.md` + `modules/ui.md` BEFORE ADR-0005 lands; may force 7-state machine to mode-per-focus-channel split.
- **Blocker §1 — Turn Order → AI direct-call invariant violation** (`turn-order.md:442` specifies `ai_system.request_action(unit_id, queue_snapshot)` as synchronous Feature-layer call from Core; violates layer invariant #4). Proposed inversion: Turn Order emits `unit_turn_started(unit_id)` → AI subscribes → AI emits `ai_action_decided(unit_id, decision)` → Turn Order advances on receipt. Awaits ADR-0011 ratification + AI ADR adoption.
- **Save/Load system #17 inferred ownership** — current §Module Ownership Core row is inferred from ADR-0003 + Scenario Progression v2.0; `design/gdd/save-load.md` not yet authored (Vertical Slice tier per systems-index #17). Treat the entire row as "⚠️ inferred — re-verify on GDD landing".

### Open — non-blocking, defer to next relevant amendment

- **ADR-0001 line 372 prose API name drift** — current text reads `hero_database.get(unit_id)`; ratified API per ADR-0007 §4 is the 6-method `HeroDatabase.get_hero(hero_id: StringName)` etc. Advisory carried from /architecture-review 2026-04-30; non-blocking. Defer to next ADR-0001 amendment (likely paired with new signal additions when AI / Grid Battle / Formation Bonus ADRs land).
- **Scenario Progression v2.0 OQ bucket 3** — Godot 4.6 engine-reference verifications still pending (dual-focus, recursive Control disable, Android 15 edge-to-edge safe-area, AccessKit reduced-motion hook). Some overlap with the Input Handling dual-focus question above; resolve in same /architecture-decision pass if scope permits.

### Open — ratification-pattern policy

- **Stateless-static utility class form** is now stable at **5 invocations** (ADR-0008 → 0006 → 0012 → 0009 → 0007). Should this be codified as default for all future Foundation/Core data-layer ADRs? Candidate ADRs that would adopt: Skill/Ability, Formation Bonus, Equipment/Item, Character Growth. Decision deferred to the first such ADR's /architecture-decision Step 4 (Alternatives Considered).

---

## Changelog

| Date | Version | Change |
|---|---|---|
| 2026-04-18 | 0.1 | Skeleton created. Phase 0 (knowledge gap + TR baseline) + Phase 1 (layer map) written. Phases 2–7 stubbed as TODO. |
| 2026-04-18 | 0.2 | Phase 2 Module Ownership written for Platform + Foundation layers (7 modules). Layer-invariant verification added. Core/Feature/Presentation/Polish ownership (24 modules) remains deferred. 2 new blocker notes logged (Input dual-focus verification, Vulkan/D3D12 reconciliation). |
| 2026-04-18 | 0.3 | Phase 2 Module Ownership extended to Core layer (5 modules — Terrain Effect, Unit Role, HP/Status, Turn Order, Save/Load system #17). Invariant #4 refined into #4 + #4b to permit stateless-rules same-layer peer calls. 3 new blocker notes logged (Turn Order → AI invariant violation requiring signal inversion; Save/Load GDD not yet authored — row is inferred; invariant #4 refinement). Feature/Presentation/Polish (22 modules) remain deferred. |
| 2026-04-30 | 0.4 | **Partial-update sweep — closes 5 ADR drift** (ADR-0004 Proposed → Accepted + ADR-0006/0007/0008/0009/0012 net-new Accepted, 2026-04-20 through 2026-04-30 via /architecture-review chain — 5 PASS deltas). Document Status: ADRs Referenced 4 → **9 Accepted**. System Layer Map: ADR refs refreshed across Layer assignments table; "Systems requiring additional ADRs" preview list pruned (4 of 8 prior items now ✅ Accepted). Module Ownership refresh: Map/Grid header status flip; Hero Database / Balance/Data / Terrain Effect / Unit Role rows fully rewritten with ratified ADR specifics; **new Damage Calc Feature-layer entry added** (first Feature module ratified — 12 still deferred); module count 12 → 13. Phase 5 ADR Audit populated (was TODO) — 9-row table with Engine Compat / Version / GDD Linkage (TR coverage) / Conflicts / Valid columns + summary; **0 cross-conflicts blocking**; 1 advisory carried (ADR-0001 line 372 prose drift). Phase 6 Required ADRs refreshed (was TODO) — **4–8 net-new ADRs before Pre-Prod gate** (down from 8–12 at v0.1); 3 mandatory (ADR-0005 Input + ADR-0010 HP/Status + ADR-0011 Turn Order). Open Questions rewritten with Closed / Open-blocking / Open-non-blocking / Policy sections. **Layer status: Foundation 4/5; Core 1/2; Feature 1/3; Presentation 0/1; Polish 0/1**. Stateless-static utility class form pattern stable at **5 invocations** (ADR-0008 → 0006 → 0012 → 0009 → 0007). Phases 3 (Data Flow) + 4 (API Boundaries) + 7 (Architecture Principles) remain deferred per partial-update scope. |
