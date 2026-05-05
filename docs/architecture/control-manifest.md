# Control Manifest

> **Engine**: Godot 4.6
> **Last Updated**: 2026-05-05
> **Manifest Version**: 2026-05-05
> **ADRs Covered**: ADR-0001..0019 (all 19 Accepted ADRs covered with dedicated subsections; sprint-7 S7-08 backfill closed the prior advisory note covering ADR-0005..0013)
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

**Input Handling (ADR-0005)**
- **InputRouter is a non-autoload `Node` instantiated by BattleScene** (`/root/BattleScene/InputRouter`) — battle-scoped lifecycle; freed with BattleScene; not a singleton — source: ADR-0005 §Decision §Module Form
- **InputRouter is the SOLE consumer of Godot raw `InputEvent` for grid + UI domains**; emits semantic actions through GameBus `input_action_fired(action: String, context: InputContext)` — downstream consumers (GridBattleController + BattleHUD) subscribe to GameBus, never to `_input(event)` directly — source: ADR-0005 §Decision §Signal Contract
- **InputContext payload is a typed Resource** (`src/core/payloads/input_context.gd`): `target_coord: Vector2i + target_unit_id: int + source_device: int` — payload type discipline per ADR-0001 — source: ADR-0005 §Decision §Payload Form
- **InputRouter state machine (`_state` enum)**: 5 states for two-tap protocol per CR-4a (S0_OBSERVATION / S1_PRIMARY_TAPPED / S2_CONFIRM_WAIT / S3_DISMISSED / S4_BLOCKED); transitions strictly by `_handle_event` dispatch — source: ADR-0005 §Decision §State Machine + input-handling.md §6
- **Touch Tap Preview Protocol** (CR-4a) — primary tap shows panel via `BattleHUD.show_unit_info(unit_id)` / `show_tile_info(coord)` direct call (NOT signal); confirm tap commits action via GameBus emit. BattleHUD methods are direct-call read API — source: ADR-0005 + battle-hud.md §3 UI-GB-03/06
- **`_input_blocked_reasons: PackedStringArray` instance var** tracks blocking layers (modal-open / scene-loading / animation-playing); `input_action_fired` not emitted while non-empty — source: ADR-0005 §Decision §Block Stack

**Balance/Data (ADR-0006)**
- **`BalanceConstants extends RefCounted`** — pure-function class form (NOT autoload, NOT static-utility) per 5-precedent stateless utility pattern — source: ADR-0006 §Decision §Class Form
- **All gameplay constants loaded from `assets/data/balance/balance_entities.json`** (flat `{KEY: value}` map per data-files.md constants-registry exception) — UPPER_SNAKE_CASE keys 1:1 with `const X = ...` GDScript identifiers — source: ADR-0006 §Decision §File Format + data-files.md
- **`BalanceConstants.get_const(key: String, default: Variant) -> Variant`** is the SOLE consumer API; consumers MUST pass a default for graceful degradation (returns default + push_warning if key missing) — source: ADR-0006 §Decision §Consumer Contract
- **JSON envelope-vs-flat detection** at parse time — MVP ships flat; future `{schema_version, category, data}` envelope adoption requires loader-detection (no consumer change) — source: ADR-0006 §Migration Plan + data-files.md
- **Constants registry hard cap (informal)**: ≤200 entries before considering JSON envelope split — source: ADR-0006 §Risks

**Hero Database (ADR-0007)**
- **`HeroDatabase` is `@abstract` (Godot 4.5+) with static-only methods** per 5-precedent stateless utility pattern (ADR-0008→0006→0012→0009→0007); blocks `HeroDatabase.new()` at parse-time on typed reference per G-22 — source: ADR-0007 §Decision §Class Form
- **`HeroDatabase.get_hero(hero_id: StringName) -> HeroData`** is the SOLE consumer API; returns null + push_error on unknown hero_id — source: ADR-0007 §Decision §Consumer Contract
- **`HeroData extends Resource` with 26 `@export` fields** matching `assets/data/heroes/heroes.json` keys 1:1 (snake_case per Entity Data File Exception in data-files.md) — `Resource.set(key, value)` reflective load — source: ADR-0007 §3 + data-files.md
- **Lazy-init via `static var _heroes_loaded: bool`**; first `get_hero` call triggers `_load_heroes()` from heroes.json — subsequent calls return immediately — source: ADR-0007 §Decision §Lazy Load
- **CR-1 FATAL load-reject**: any duplicate hero_id OR malformed regex (^[a-z][a-z0-9_]*$) rejects ENTIRE load (push_error + `_heroes.clear()` + `_heroes_loaded` stays false) — source: ADR-0007 §Decision §Validation
- **`HeroData` consumer mutation forbidden** — returned HeroData instances are shared references; mutating fields corrupts subsequent reads (forbidden_pattern: `hero_data_consumer_mutation`) — source: ADR-0007 §Decision §Read-Only Contract

**Terrain Effect (ADR-0008) — Foundation portion**
- **`TerrainEffect extends RefCounted`** — pure-function class form per 5-precedent stateless utility pattern; NOT autoload, NOT static-utility — source: ADR-0008 §Decision §Class Form
- **Terrain modifier data loaded from `assets/data/terrain/terrain_config.json`** at first `get_modifiers(terrain_type: int) -> TerrainModifiers` call; lazy-init pattern mirrors HeroDatabase — source: ADR-0008 §2
- **`TerrainModifiers extends Resource` with `@export` field set** matching JSON keys 1:1 (snake_case per Entity Data File Exception per data-files.md) — source: ADR-0008 §2 + data-files.md
- **`get_combat_modifiers(terrain_type, attacker_class, defender_class) -> CombatModifiers`** is the SOLE per-attack-resolve consumer API; called ONCE per DamageCalc.resolve invocation — source: ADR-0008 §Decision §Consumer Contract

**Unit Role (ADR-0009)**
- **`UnitRole` is `@abstract` (Godot 4.5+) with static-only methods** per 5-precedent stateless utility pattern; blocks `UnitRole.new()` at parse-time on typed reference per G-22 — source: ADR-0009 §Decision §Class Form
- **6 unit classes** (INFANTRY / CAVALRY / SCOUT / ARCHER / COMMANDER / DUELIST) keyed by enum int values per `BattleUnit.unit_class` — APPEND-ONLY discipline; reordering requires SaveMigrationRegistry entry — source: ADR-0009 §Decision §Class Enum
- **`get_class_direction_multiplier(unit_class: int, direction: int) -> float`** returns the D_mult identity-element for damage-calc Stage 2; SCOUT class is the identity (1.00 across all 3 directions) per EC-7 — source: ADR-0009 §EC-7 + damage-calc.md F-DC-2
- **Per-class coefficients loaded from `assets/data/units/unit_roles.json`** at first call (file authored when unit-role epic implementation begins; not yet on disk as of 2026-05-02 per data-files.md note)
- **Returned `Array[T]` from any UnitRole API is read-only** — consumer mutation corrupts shared state (forbidden_pattern: `unit_role_returned_array_mutation`) — source: ADR-0009 §Decision §Read-Only Contract

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

**Input Handling (ADR-0005)**
- **Never declare `static var` in InputRouter** — battle-scoped lifecycle requires instance state only (forbidden_pattern: `input_router_static_var`); 5-precedent stateless utility pattern (ADR-0008/0006/0012/0009/0007) explicitly NOT applicable per Alternative 4 rejected for engine-level structural incompatibility — source: ADR-0005 §Decision §Module Form
- **Never bypass InputRouter for grid + UI input** — GridBattleController + BattleHUD MUST NOT call `Input.get_action_*` or `_input(event)` directly; semantic actions only via GameBus subscription — source: ADR-0005 §Decision §Sole Consumer
- **Never emit `input_action_fired` while `_input_blocked_reasons` is non-empty** — block-stack discipline preserves modal isolation — source: ADR-0005 §Decision §Block Stack

**Balance/Data (ADR-0006)**
- **Never declare `static var` in BalanceConstants** — RefCounted instance form preserved per stateless utility pattern (forbidden_pattern: `balance_constants_static_var`) — source: ADR-0006 §Risks
- **Never hardcode gameplay constants in source files** — all tuning values MUST come from balance_entities.json via `BalanceConstants.get_const(KEY)`; lint enforced per per-system `lint_*_no_hardcoded_constants.sh` scripts (damage-calc + camera + grid_battle_controller + hp-status + foundation_balance precedents) — source: ADR-0006 §Decision §Consumer Contract
- **Never extend constants registry to entity-shape data** — Constants Registry Exception in data-files.md applies ONLY to flat `{KEY: value}` cross-system tuning maps — source: data-files.md + ADR-0006

**Hero Database (ADR-0007)**
- **Never emit GameBus signals from HeroDatabase** (forbidden_pattern: `hero_database_signal_emission`) — pure read API per 9-precedent stateless-emit / non-emitter discipline — source: ADR-0007 §Decision §Read-Only Contract
- **Never mutate returned HeroData fields** (forbidden_pattern: `hero_data_consumer_mutation`) — instances are shared references; mutation corrupts subsequent reads — source: ADR-0007 §Decision §Read-Only Contract
- **Never instantiate HeroDatabase via `HeroDatabase.new()` on typed reference** — `@abstract` (Godot 4.5+) blocks parse-time per G-22; reflective `load(path).new()` bypass exists for test seam ONLY — source: ADR-0007 §Decision §Class Form + tooling-gotchas G-22

**Terrain Effect (ADR-0008)**
- **Never declare `static var` in TerrainEffect** — RefCounted instance form preserved per stateless utility pattern — source: ADR-0008 §Risks
- **Never bypass `get_combat_modifiers` per-attack** — DamageCalc.resolve() consumer contract REQUIRES exactly one TerrainEffect call per resolve invocation; multiple calls per resolve breaks F-DC-3 P_mult composition contract — source: ADR-0008 §Decision §Consumer Contract + damage-calc.md F-DC-3

**Unit Role (ADR-0009)**
- **Never mutate Array[T] returned by UnitRole APIs** (forbidden_pattern: `unit_role_returned_array_mutation`) — shared state corruption; treat as read-only — source: ADR-0009 §Decision §Read-Only Contract
- **Never instantiate UnitRole via `UnitRole.new()` on typed reference** — `@abstract` (Godot 4.5+) blocks parse-time per G-22 + ADR-0009 §1 wording-history note (3-step correction journey: parse-time → runtime → parse-time-on-typed-reference with reflective bypass) — source: ADR-0009 §1 + tooling-gotchas G-22
- **Never write Stage-N tests using non-identity-element class+direction combos** — SCOUT class is the D_mult identity for damage-calc per EC-7; using INFANTRY+FRONT (D_mult=1.10) invalidates assertion when Stage-N+1 lands per G-19 — source: tooling-gotchas G-19 + ADR-0009 EC-7

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
- **Turn Order emits only**: `round_started(int)`, `unit_turn_started(int)`, `unit_turn_ended(int, bool)`, `victory_condition_detected` — source: ADR-0001 + ADR-0011 (TR-turn-order-001)
- **Battle termination signal ownership lives in Grid Battle, not Turn Order** — single-emitter rule; Grid Battle emits `battle_outcome_resolved(BattleOutcome)` on CLEANUP — source: ADR-0001 + ADR-0014

**Terrain Effect — Core consumer (ADR-0008)**
- **DamageCalc.resolve() invokes `TerrainEffect.get_combat_modifiers(terrain_type, attacker_class, defender_class)` exactly ONCE per attack resolution** — composition discipline preserves F-DC-3 P_mult cap invariant — source: ADR-0008 §Decision §Consumer Contract + damage-calc.md F-DC-3
- **Terrain modifiers are computed at attack-resolve time, NOT cached per-tile** — terrain_type is sourced from MapResource.tiles[coord]; modifiers themselves are pure-function output — source: ADR-0008 §Migration Plan

**HP/Status Controller (ADR-0010)**
- **HPStatusController is a battle-scoped Node** (1st invocation of battle-scoped Node pattern; predates ADR-0011/0013/0014/0015/0019 which followed) — instantiated by BattleScene root, freed with BattleScene; zero cross-battle state — source: ADR-0010 §Decision §Module Form
- **`_state_by_unit: Dictionary[int, UnitState]` is the SOLE authoritative state source** for HP + status effects + DEFEND-stance flag — all 4 mutator methods (`apply_damage` / `apply_heal` / `apply_status` / `_apply_turn_start_tick`) write through `_state_by_unit` — source: ADR-0010 §3
- **6 public read-only query methods**: `get_current_hp`, `get_max_hp`, `is_alive`, `get_status_effects`, `get_modified_stat`, `get_defend_stance` — source: ADR-0010 §Decision §Public API
- **`get_modified_stat(unit_id, stat_name)`** applies F-4 modifier composition; DEFEND_STANCE_ATK_PENALTY pre-folded per damage-calc.md line 89-93 contract — source: ADR-0010 §F-4 + damage-calc.md
- **3 emitted GameBus signals**: `unit_died(int)`, `unit_hp_changed(int, int, int)`, `unit_status_applied(int, StringName)` — non-emitter discipline for all OTHER 22 GameBus signals across 8 domains — source: ADR-0010 §Signal Contract
- **`_exit_tree()` body MUST disconnect all GameBus subscriptions** + free transient state per battle-scoped Node 6-precedent discipline — source: ADR-0010 §Risks

**Turn Order Runner (ADR-0011)**
- **TurnOrderRunner is a battle-scoped Node** (2nd invocation of battle-scoped Node pattern after HPStatusController) — instantiated by BattleScene root, freed with BattleScene; zero cross-battle state — source: ADR-0011 §Decision §Module Form
- **Initiative ordering**: descending `BattleUnit.initiative` (typed int seed from HeroData.base_initiative_seed); ties broken by ascending `unit_id` — deterministic per replay-determinism contract — source: ADR-0011 §F-1
- **Round lifecycle**: R0 BATTLE_START → R1 ROUND_INIT → R2 QUEUE_BUILT → R3 TURN_START → R4 ACTION_DECLARED → R5 ACTION_RESOLVED → R6 TURN_END → (R3 next unit OR R7 ROUND_END) — emits 4 GameBus signals at R4 (unit_turn_started) / T6 (unit_turn_ended) / T7 + RE2 (round_started) / RE3 (victory_condition_detected) — source: ADR-0011 §States and Transitions
- **`declare_action(unit_id, action_type)` is the SOLE action mutator API**; rejects with error_code per declared-action-invalid path (token re-spend / unknown action_type / out-of-turn) — source: ADR-0011 §Decision §Consumer Contract
- **`unit_died` consumer**: TurnOrderRunner subscribes to GameBus.unit_died for queue removal; does NOT emit unit_died (single-emitter rule per ADR-0010) — source: ADR-0011 §Subscriptions

**Grid Battle Controller (ADR-0014)**
- **GridBattleController is a battle-scoped Node** (4th invocation of battle-scoped Node pattern after HPStatusController + TurnOrderRunner + BattleCamera) — instantiated by BattleScene root, freed with BattleScene; zero cross-battle state — source: ADR-0014 §1
- **5 signals are LOCAL on the controller class, NOT routed through GameBus**: `unit_selected_changed`, `unit_moved`, `damage_applied`, `battle_outcome_resolved`, `hidden_fate_condition_progressed` — consumers (Battle HUD + Scenario Progression + Destiny Branch) connect directly to the controller instance via DI'd reference — source: ADR-0014 §8
- **`battle_outcome_resolved(BattleOutcome)` is the SOLE controller of battle-end emission** — single-emitter rule; Turn Order emits `victory_condition_detected` (bridge signal) which controller consumes + emits authoritative `BattleOutcome` Resource — source: ADR-0014 + ADR-0011
- **`hidden_fate_condition_progressed` is consumed ONLY by Destiny Branch** — Battle HUD MUST NEVER subscribe (Pillar 2 architectural lock — see Pillar 2 Locks section) — source: ADR-0014 + ADR-0015 + design/gdd/destiny-branch.md
- **All combat math (formation +5%/adj-ally cap +20%; angle 1.0/1.25/1.50/1.75-for-rear-specialist; command_aura +15%) lives in TWO places only**: (a) `GridBattleController._resolve_attack()` inline math, (b) `DamageCalc.resolve()` (sole-caller contract per ADR-0012). No third implementation permitted — source: ADR-0014 R-2 + ADR-0012
- **`_exit_tree()` body MUST disconnect all GameBus subscriptions** + free child references (battle-scoped Node 4-precedent discipline) — source: ADR-0014 R-4

**Scenario Progression (ADR-0017)**
- **ScenarioRunner is an autoload `Node` (NOT `class_name`-declared) per G-3** at `/root/ScenarioRunner` — source: ADR-0017 §State Machine Form
- **13-state machine via `enum + match`** (forward-only except single backward edge BEAT_6_RESULT → BEAT_4_PREP retry loop) — source: ADR-0017 §States and Transitions
- **9-beat per-chapter rhythm** (Beat 1 entry → Beat 7 judgment → Beat 8 reveal → Beat 9 outro) — source: ADR-0017 + scenario-progression.md
- **All state transitions go through `_transition_to(target: State)`** which validates legality against the §States and Transitions table — direct `_state = State.X` assignment forbidden — source: ADR-0017 §Decision §State Machine Form (forbidden_pattern: `scenario_runner_arbitrary_state_jump`)
- **7-signal contract on GameBus**: `chapter_started`, `scenario_complete(ScenarioResult)` (widened from String per /architecture-review delta #12), `scenario_beat_retried(EchoMark)`, `save_checkpoint_requested(SaveContext)`, `destiny_branch_chosen(DestinyBranchChoice)`, plus 2 additional confirmed/ratified — source: ADR-0017 + ADR-0001 (TR-scenario-progression-004..015)
- **`ChapterDefinition` is a typed `Resource` with untyped Dictionary `@export var branch_table`** (typed Dictionary export not supported in GDScript 4.6 per godot-specialist 14th invoke; runtime validation handles type-correctness) — source: ADR-0017 + tr-registry.yaml v13
- **`branch_table` is read-only after LOADING state exit** — runtime mutation forbidden (corrupts replay determinism + CP-2 save fidelity) — source: ADR-0017 §Risks §Risk 3 (forbidden_pattern: `scenario_runner_branch_table_runtime_mutation`)
- **`save_checkpoint_requested(SaveContext)` MUST emit fully-populated SaveContext** via single `_make_save_context(cp_kind: SaveCheckpoint) -> SaveContext` helper — direct `SaveContext.new()` outside the helper forbidden — source: ADR-0017 §Risks §Risk 4 (forbidden_pattern: `scenario_runner_save_context_partial_emit`)
- **Beat 7 entry seal MUST be SYNCHRONOUS with Beat 6 result accept**: `_enter_beat_7_judgment()` (or equivalent handler) called in same call frame as BEAT_6_RESULT exit; `call_deferred` / `CONNECT_DEFERRED` / `await` between Beat 6 and Beat 7 forbidden (Pillar 2 architectural lock — see Pillar 2 Locks section) — source: ADR-0017 §F-SP-1/F-SP-2 + scenario-progression.md F-SP-3 v2.2 B-1 invariant (forbidden_pattern: `scenario_runner_deferred_seal_in_beat_7_entry`)
- **ScenarioRunner MUST NOT assign or override `BattleOutcome.result`** — tri-state {WIN, DRAW, LOSS} owned exclusively by GridBattleController per ADR-0014 emission contract; ScenarioRunner reads `_last_battle_outcome.result` only for state-machine routing — source: ADR-0017 §CR-3 (forbidden_pattern: `scenario_runner_outcome_synthesis`)
- **3-CP save integration**: CP-1 Beat 1 entry, CP-2 post-Beat 7 (on `battle_outcome_resolved`), CP-3 next-chapter Beat 1 entry — source: ADR-0017 + ADR-0003

### Forbidden Approaches

**Grid Battle Controller (ADR-0014)**
- **Never emit signals via GameBus from GridBattleController** — all 5 signals LOCAL to controller class (lint: `grep -c 'GameBus\..*\.emit' src/feature/grid_battle/grid_battle_controller.gd` returns 0) — source: ADR-0014 §8 (forbidden_pattern: `grid_battle_controller_signal_emission_outside_battle_domain`)
- **Never declare `static var` in GridBattleController** — battle-scoped lifecycle requires instance state only (lint: `grep -E '^static var ' src/feature/grid_battle/grid_battle_controller.gd` returns 0) — source: ADR-0014 §3 (forbidden_pattern: `grid_battle_controller_static_state`)
- **Never implement formation count, angle classification, or command_aura check in any class other than GridBattleController + DamageCalc** — single-source-of-truth for combat math; FormationBonusSystem ADR (post-MVP) will migrate this — source: ADR-0014 R-2 (forbidden_pattern: `grid_battle_controller_external_combat_math`)

**Scenario Progression (ADR-0017)**
- **Never assign `_state = State.X` outside `_transition_to()`** — bypass corrupts 9-beat canonical rhythm + breaks CP-2 save integrity — source: forbidden_pattern `scenario_runner_arbitrary_state_jump`
- **Never mutate `chapter.branch_table` at runtime** — silent narrative divergence on save-restore — source: forbidden_pattern `scenario_runner_branch_table_runtime_mutation`
- **Never construct `SaveContext.new()` outside `_make_save_context()` helper** — partial emits corrupt restore — source: forbidden_pattern `scenario_runner_save_context_partial_emit`
- **Never use `call_deferred` / `CONNECT_DEFERRED` / `await` between BEAT_6 accept and BEAT_7 entry** — Pillar 2 architectural lock — source: forbidden_pattern `scenario_runner_deferred_seal_in_beat_7_entry`
- **Never write `BattleOutcome.result = X`** anywhere in `src/core/scenario_runner.gd` — source: forbidden_pattern `scenario_runner_outcome_synthesis`

**HP/Status Controller (ADR-0010)**
- **Never declare `static var` in HPStatusController** — battle-scoped lifecycle requires instance state only (forbidden_pattern: `hp_status_static_var_state_addition`); 5-precedent stateless utility pattern explicitly NOT applicable per Alternative 3 rejected for engine-level structural incompatibility — source: ADR-0010 §Alternatives
- **Never mutate returned `Array[StatusEffect]` from `get_status_effects(unit_id)`** (forbidden_pattern: `hp_status_consumer_mutation`) — shallow-copy returned array shares StatusEffect Resource refs; mutation corrupts ALL subsequent reads. READ-ONLY consumers (Battle HUD + AI) MUST go through apply_status / apply_damage / apply_heal mutator paths — source: ADR-0010 §5
- **Never bypass `apply_damage` for direct HP mutation** — DEFEND-stance flag composition + status-tick interaction are NOT replicable from outside the class — source: ADR-0010 §F-4

**Turn Order Runner (ADR-0011)**
- **Never declare `static var` in TurnOrderRunner** — battle-scoped lifecycle requires instance state only (forbidden_pattern: `turn_order_static_var_state_addition`); 5-precedent stateless utility pattern explicitly NOT applicable per Alternative 2 rejected — source: ADR-0011 §Alternatives
- **Never emit non-domain GameBus signals from TurnOrderRunner** (forbidden_pattern: `turn_order_signal_emission_outside_domain`) — only the 4 Turn Order Domain signals (round_started + unit_turn_started + unit_turn_ended + victory_condition_detected); 21 OTHER signals across 8 domains are non-emitter discipline — source: ADR-0001 lines 152-155 + ADR-0011 §Signal Ownership
- **Never emit `battle_outcome_resolved`** — single-emitter rule; Turn Order emits `victory_condition_detected` (bridge signal) which Grid Battle consumes + emits authoritative BattleOutcome — source: ADR-0011 + ADR-0014 + ADR-0001 line 301

### Performance Guardrails

| System | Metric | Budget | Source |
|--------|--------|--------|--------|
| `get_movement_range()` | CPU | <16 ms on 40×30 map, move_range=10 | ADR-0004 (AC-PERF-2) |
| 60fps combat turn | Frame time | no 3 consecutive frames >16.6 ms on max map | `design/gdd/map-grid.md` AC-PERF-1 |
| GridBattleController state | Memory | per-battle scoped, freed at BattleScene queue_free | ADR-0014 §3 |
| ScenarioRunner state machine | CPU per transition | <0.1 ms typical (enum + match dispatch) | ADR-0017 §State Machine Form |
| Beat 7 seal → Beat 7 entry | Frame boundary | exactly 0 frames (synchronous) | ADR-0017 §F-SP-1 + Pillar 2 lock |
| HPStatusController state | Memory | per-battle scoped, freed at BattleScene queue_free | ADR-0010 §3 |
| TurnOrderRunner state | Memory | per-battle scoped, freed at BattleScene queue_free | ADR-0011 §3 |
| TurnOrderRunner queue rebuild | CPU per round | <0.5 ms (descending sort + tie-break) | ADR-0011 §F-1 |
| TerrainEffect.get_combat_modifiers | CPU per attack-resolve | <0.05 ms (dict lookup + composition) | ADR-0008 §Decision §Consumer Contract |

---

## Feature Layer Rules

*Applies to: AI pathfinding consumer, Formation Bonus, HP/Status, Damage Calc, Destiny Branch, secondary mechanics*

### Required Patterns (Consumer Contracts from ADR-0004 + ADR-0001)

- **AI must invalidate cached paths on receiving `GameBus.tile_destroyed(coord: Vector2i)`** — affected path cache entries recomputed on next query — source: ADR-0004 §Decision 9 consumer contract
- **Formation Bonus must re-check adjacency on receiving `GameBus.tile_destroyed(coord: Vector2i)`** for any formation cell adjacent to `coord` — source: ADR-0004 §Decision 9 consumer contract
- **Formation Bonus self-caches `coord_to_unit_id: Dictionary[Vector2i, int]` from `units: Array[UnitState]` at `round_started`** — never calls `MapGrid.get_unit_at()` (no such API exists) — source: `design/gdd/formation-bonus.md` F-FB-1 v1.1 + `design/gdd/map-grid.md` §Dependencies
- **HP/Status emits `unit_died(unit_id: int)` via GameBus** when HP reaches 0 — consumed by Turn Order (queue removal), Grid Battle (victory check), AI — source: ADR-0001 (TR-hp-status-001)

### Required Patterns (Damage Calc — ADR-0012)

**DamageCalc (sole-caller contract; stateless module form)**
- **`DamageCalc extends RefCounted`** — pure-function class form per 5-precedent stateless utility pattern (sister to BalanceConstants + TerrainEffect + UnitRole + HeroDatabase) — source: ADR-0012 §Decision §Module Form
- **`DamageCalc.resolve(attacker_ctx: AttackerContext, defender: BattleUnit, modifiers: ResolveModifiers) -> DamageResult`** is the SOLE entry point — invoked exclusively by GridBattleController._resolve_attack() — source: ADR-0012 §Decision §Sole Entry (forbidden_pattern: `damage_calc_no_apply_damage`)
- **5-stage pipeline**: Stage 0 invariant guards → Stage 1 base damage F-DC-1 → Stage 2 D_mult F-DC-2 → Stage 2.5 P_mult F-DC-3 → Stage 3 raw cap F-DC-6 → Stage 4 counter halve F-DC-7 → Stage 5 floor min damage = 1 — source: damage-calc.md §Formulas
- **`AttackerContext` + `ResolveModifiers` + `DamageResult`** are typed Resources at `src/core/payloads/`; immutable inputs, fresh output per resolve — source: ADR-0012 §Decision §Payload Form
- **Determinism contract**: 1 RNG consumption per non-counter resolve (evasion roll); counter-attack resolves consume 0 RNG; replay-determinism via shared `_rng: RandomNumberGenerator` injected at GridBattleController setup — source: ADR-0012 AC-DC-26
- **Constants registry consumer**: all tuning values (BASE_CEILING + MIN_DAMAGE + P_MULT_COMBINED_CAP + CLASS_DIRECTION_MULT) loaded via `BalanceConstants.get_const(KEY)` — no hardcoded magic numbers (forbidden_pattern: `damage_calc_no_hardcoded_constants`) — source: ADR-0012 §Decision §Tuning Constants

### Required Patterns (Battle Camera — ADR-0013)

**BattleCamera (battle-scoped Node 3rd invocation)**
- **BattleCamera is a battle-scoped Node** (3rd invocation of battle-scoped Node pattern after HPStatusController + TurnOrderRunner) — instantiated by BattleScene root, freed with BattleScene; zero cross-battle state — source: ADR-0013 §Decision §Module Form
- **2 public direct-call methods**: (1) `screen_to_grid(screen_pos: Vector2) -> Vector2i` — converts screen-space to grid coords using `get_canvas_transform().affine_inverse() + tile_world_size`; returns `Vector2i(-1,-1)` sentinel for off-grid. (2) `get_zoom_value() -> float` — read-only zoom query for HUD scale-matching. Both methods are NON-emitter direct-call API (calculator-tier non-emitter pattern shared with DamageCalc) — source: ADR-0013 §Decision §Public API
- **`screen_to_grid` is the SOLE implementation in the project** — InputRouter + GridBattleController + BattleHUD all consume via DI'd reference (forbidden_pattern: `external_screen_to_grid_implementation`) — source: ADR-0013 §Decision §Sole Implementation
- **Internal state is private**: `_map_grid` (DI'd) + `_drag_*` (drag state) + `Camera2D.zoom` + `Camera2D.position` — consumers do NOT directly read these — source: ADR-0013 §Decision §State Encapsulation
- **DI seam**: `setup(map_grid: MapGrid) -> void` MUST be called BEFORE add_child per battle-scoped Node 6-precedent setup-before-add_child pattern; `_ready()` asserts `map_grid` non-null — source: ADR-0013 R-1
- **`_exit_tree()` body MUST disconnect all GameBus subscriptions** + free transient state per battle-scoped Node 6-precedent discipline (forbidden_pattern: `camera_missing_exit_tree_disconnect`) — source: ADR-0013 R-6
- **No hardcoded zoom levels** — MIN_ZOOM + MAX_ZOOM + DEFAULT_ZOOM loaded via BalanceConstants (forbidden_pattern: `camera_no_hardcoded_zoom`) — source: ADR-0013 §Decision §Tuning

### Required Patterns (Destiny Branch — ADR-0018)

**DestinyBranchJudge (RefCounted pure-function class — 1st `@abstract` test-seam pattern in project)**
- **`DestinyBranchJudge extends RefCounted`** — pure-function class form (NOT autoload, NOT static-utility, NOT Node) — source: ADR-0018 §Decision §Class Form (api_decision: `destiny_branch_judge_module_form`)
- **`@abstract func _apply_f_sp_1(...) -> Dictionary`** test seam (Godot 4.5+) — production subclass `DefaultDestinyBranchJudge` overrides to delegate to `ScenarioFormulas.resolve_branch(...)` — source: ADR-0018 §Decision §Test Seam
- **Public API: `resolve(chapter: ChapterDefinition, outcome: BattleOutcome.Result, echo_count: int, first_attempt_resolved: bool) -> DestinyBranchChoice`** — 4-arg signature; the 4th arg is the ALREADY-SEALED value passed BY ScenarioRunner per F-SP-3 v2.2 — source: ADR-0018 §Decision §Public API + ADR-0017 §F-SP-1
- **Construction**: `var judge: DestinyBranchJudge = DefaultDestinyBranchJudge.new()` then `var choice: DestinyBranchChoice = judge.resolve(...)` — RefCounted scope-drop frees instance after call — source: ADR-0017 line 209 (instance-form per /architecture-review delta #13 BLOCKING resolution) + ADR-0018 Alternative §2 EC-DB-17 thread-safety
- **`DestinyBranchChoice` is a typed `Resource` with 9 `@export` fields**: `chapter_id`, `branch_key`, `outcome`, `echo_count`, `is_draw_fallback`, `is_canonical_history`, `reserved_color_treatment`, `is_invalid`, `invalid_reason` — source: ADR-0018 §Decision §Payload Form (ratifies ADR-0001 PROVISIONAL slot 5→9 fields per Evolution Rule #4)
- **`invalid_reason: StringName`** drawn from 12-entry F-DB-3 vocabulary — source: ADR-0018 §Decision §Payload Form + design/gdd/destiny-branch.md F-DB-3
- **`static func invalid(reason: StringName) -> DestinyBranchChoice`** factory for invalid-path emission — preserves AC-SP-17 exactly-one-emission contract per chapter — source: ADR-0018 §Decision §Payload Form
- **Emission ownership**: `GameBus.destiny_branch_chosen(DestinyBranchChoice)` is emitted EXCLUSIVELY by ScenarioRunner's BEAT_7_JUDGMENT tap-exit handler — judge.resolve() returns the payload, ScenarioRunner emits — source: ADR-0018 §Decision §Emission Ownership + CR-DB-4 (interface: `destiny_branch_judge_signal_contract` — 1st `direct_call` interface contract pattern in project)
- **Determinism contract**: no RNG, no wall-clock reads, no external-state reads, no class-level mutable state (`static var` forbidden) — identical inputs → field-identical 9-field DestinyBranchChoice output — source: ADR-0018 §Decision §Determinism Contract + CR-DB-11
- **Cross-doc constraint**: `class_name BattleOutcome` MUST be top-level (NOT inner class) for `@export var outcome: BattleOutcome.Result = ...` parse-time resolution per Godot 4.6 global class registry — already SATISFIED in shipped `src/core/payloads/battle_outcome.gd:10` — source: ADR-0018 + destiny-branch GDD rev 1.2 B-7

### Forbidden Approaches

- **Never call a non-existent `MapGrid.get_unit_at(coord)` API** — consumers must self-cache from `units` array at round boundary — source: `design/gdd/map-grid.md` §Dependencies v1.1

**Damage Calc (ADR-0012)**
- **Never call any HPStatusController.apply_damage or apply_heal from DamageCalc** — DamageCalc is PURE (no side effects); GridBattleController applies the resolved damage post-resolve (forbidden_pattern: `damage_calc_no_apply_damage`) — source: ADR-0012 §Decision §Sole Entry
- **Never emit GameBus signals from DamageCalc** (forbidden_pattern: `damage_calc_no_signals`) — pure function discipline; signal emission lives in GridBattleController.damage_applied LOCAL signal — source: ADR-0012 §Decision §Module Form
- **Never allocate `Dictionary` in DamageCalc hot path** (forbidden_pattern: `damage_calc_no_dictionary_alloc`) — per-frame allocation budget; use typed Resources only — source: ADR-0012 §Performance
- **Never copy DamageCalc stub patterns into production source** (forbidden_pattern: `damage_calc_no_stub_copy`) — test-helper stubs MUST stay in tests/helpers/ — source: ADR-0012 §Test Discipline
- **Never bypass `BalanceConstants.get_const(KEY)` for tuning values** — hardcoded magic numbers in damage_calc.gd FAIL lint (forbidden_pattern: `damage_calc_no_hardcoded_constants`) — source: ADR-0012 §Decision §Tuning Constants
- **Never write Stage-N tests with non-identity-element class+direction** — SCOUT class is the D_mult identity (1.00 across 3 directions) per EC-7 + tooling-gotchas G-19; using INFANTRY+FRONT (1.10) breaks Stage-N+1 retroactive assertion stability per G-21 — source: tooling-gotchas G-19/G-21

**Battle Camera (ADR-0013)**
- **Never declare `static var` in BattleCamera** — battle-scoped lifecycle requires instance state only — source: ADR-0013 §Decision §Module Form (battle-scoped Node 3-precedent discipline)
- **Never emit GameBus signals from BattleCamera** (forbidden_pattern: `camera_signal_emission`) — calculator-tier non-emitter discipline; pure direct-call API — source: ADR-0013 §Decision §Public API
- **Never implement `screen_to_grid` outside BattleCamera** (forbidden_pattern: `external_screen_to_grid_implementation`) — single source of truth for screen↔grid math — source: ADR-0013 §Decision §Sole Implementation
- **Never hardcode zoom values** (forbidden_pattern: `camera_no_hardcoded_zoom`) — all zoom min/max/default via BalanceConstants — source: ADR-0013 §Decision §Tuning
- **Never skip `_exit_tree()` GameBus disconnect discipline** (forbidden_pattern: `camera_missing_exit_tree_disconnect`) — battle-scoped Node 6-precedent discipline; autoload outlives BattleCamera, leaks callable refs — source: ADR-0013 R-6

**Destiny Branch (ADR-0018)**
- **Never emit any GameBus signal from `DestinyBranchJudge` or `DefaultDestinyBranchJudge` or test stub or any subclass** (lint scan-set: production source files + `tests/helpers/destiny_branch_judge_stub.gd` + `$(grep -rl 'extends DestinyBranchJudge' src/ tests/)`) — source: ADR-0018 V-7 (forbidden_pattern: `destiny_branch_judge_emits_gamebus_signal`)
- **Never declare `static var` in `DestinyBranchJudge` or any subclass** (production OR test scope) — EC-DB-17 thread-safety + test-isolation guarantee — source: ADR-0018 V-8 (forbidden_pattern: `destiny_branch_judge_static_var`)
- **Never read state from ScenarioRunner autoload** (`ScenarioRunner.<member>`, `_scenario_state.<field>`, `get_tree().get_root().get_node("/root/ScenarioRunner")`) — judge accesses inputs ONLY via the 4 `resolve()` parameters — source: ADR-0018 V-9 + CR-DB-2 + Pillar 2 architectural lock (forbidden_pattern: `destiny_branch_judge_reads_scenario_runner_state`)

---

## Presentation Layer Rules

*Applies to: Battle HUD, VFX, rendering, audio, UI*

### Required Patterns

- **VFX system subscribes to `GameBus.tile_destroyed(coord: Vector2i)`** and plays destruction effect at that coord — source: ADR-0004 §Decision 9 consumer contract
- **Battle HUD reads `SceneManager.loading_progress: float` as a property query (not via bus)** — displays progress bar during LOADING_BATTLE — source: ADR-0002 §Key Interfaces
- **UI accessibility (if committed tier requires it)**: use AccessKit screen reader integration on Control nodes — Godot 4.5+ — source: `docs/engine-reference/godot/current-best-practices.md` §Accessibility

**Battle HUD (ADR-0015)**
- **BattleHUD is a battle-scoped Control** (5th invocation of battle-scoped Node pattern after HPStatusController + TurnOrderRunner + BattleCamera + GridBattleController) — instantiated by BattleScene root, freed with BattleScene; zero cross-battle state — source: ADR-0015 §1
- **9-param `setup()` DI**: BattleHUD receives 9 backend references (GridBattleController + HPStatusController + TurnOrderRunner + BattleCamera + InputRouter + MapGrid + SceneManager + DataRegistry + UIInputBlocker) before `add_child()` per setup-before-add_child mandate — source: ADR-0015 R-2 + 5-precedent battle-scoped DI discipline
- **`_ready()` MUST assert all 9 backends present** (DI null-checks fail loud) before any signal subscriptions — source: ADR-0015 §3
- **11 GameBus subscriptions all `CONNECT_DEFERRED`**: 4 from GridBattleController (`unit_selected_changed` / `unit_moved` / `damage_applied` / `battle_outcome_resolved`) + 1 from HPStatusController (`unit_died`) + 3 from TurnOrderRunner (`round_started` / `unit_turn_started` / `unit_turn_ended`) + 2 from InputRouter (`input_state_changed` / `input_mode_changed`) + 1 from GridBattleController formation_bonuses_updated — source: ADR-0015 §4 (TR-battle-hud-003)
- **`_exit_tree()` MUST disconnect all 11 GameBus subscriptions** (lint asserts ≥11 disconnect calls in `_exit_tree` body) — source: ADR-0015 R-7 + camera_missing_exit_tree_disconnect 4-precedent project discipline (forbidden_pattern: `battle_hud_missing_exit_tree_disconnect`)
- **BattleHUD MUST NEVER subscribe to `hidden_fate_condition_progressed`** — Pillar 2 architectural lock — see Pillar 2 Locks section below — source: ADR-0015 §5 (forbidden_pattern: `battle_hud_subscribes_to_hidden_fate_signal`)
- **All interactive Controls (Button / TextureButton / any Control with `mouse_filter != MOUSE_FILTER_IGNORE`) MUST have `custom_minimum_size.x ≥ 44 AND custom_minimum_size.y ≥ 44`** on touch viewport — WCAG 2.5.5 Target Size + project 44px touch target minimum — source: ADR-0015 + design/ux/accessibility-requirements.md (forbidden_pattern: `battle_hud_touch_target_below_44pt`)
- **All visible text routes through `tr(key)` localization function** — locale keys declared in project .po / .csv; no hardcoded localized strings in `src/feature/battle_hud/*.gd` — source: ADR-0015 + technical-preferences i18n obligation (forbidden_pattern: `battle_hud_hardcoded_localized_strings`)

### Forbidden Approaches

**Battle HUD (ADR-0015)**
- **Never emit any GameBus signal from BattleHUD** — HUD is pure consumer + state-reader; cross-system events flow back through InputRouter as synthetic events — source: ADR-0015 R-5 (forbidden_pattern: `battle_hud_signal_emission`)
- **Never subscribe to `hidden_fate_condition_progressed`** anywhere in `src/feature/battle_hud/battle_hud.gd` (lint: zero token occurrences in source) — Pillar 2 architectural lock — source: forbidden_pattern `battle_hud_subscribes_to_hidden_fate_signal`
- **Never ship interactive Controls with `custom_minimum_size < 44`** — fails accessibility on mobile + excludes motor-accessibility users — source: forbidden_pattern `battle_hud_touch_target_below_44pt`
- **Never hardcode localized strings** in BattleHUD source — breaks runtime locale switching — source: forbidden_pattern `battle_hud_hardcoded_localized_strings`

---

## Integration Layer Rules

*Applies to: scene roots that orchestrate other systems via DI mount sequences*

### Required Patterns

**BattleScene root (ADR-0016 — 1st invocation of scene-root-as-orchestrator pattern)**
- **`scenes/battle/battle_scene.tscn` MUST contain EXACTLY 3 nodes**: BattleScene root `Node2D` + `GridLayer Node2D` + `HUDLayer CanvasLayer` (layer=1). All 6 system Nodes are code-driven via `_ready()` mount sequence — source: ADR-0016 §3 (TR-battle-scene-wiring-003)
- **6-step `_ready()` mount sequence locks DI dependency order**: MapGrid → BattleCamera → HPStatusController → TurnOrderRunner → GridBattleController → BattleHUD — each system's `setup()` called BEFORE `add_child()` — source: ADR-0016 R-2
- **BattleScene root is pure orchestrator**: instantiates + sets up + adds children; NO GameBus interaction; NO `_exit_tree()` body (auto-tree-free + per-child `_exit_tree()` handles all teardown) — source: ADR-0016 R-7 + IN-1
- **Each child system's `_exit_tree()` is responsible for its own GameBus disconnections** — BattleScene root does NOT centralize teardown — source: ADR-0016 + battle-scoped Node 5-precedent discipline

### Forbidden Approaches

**BattleScene Root (ADR-0016)**
- **Never pre-instance child Nodes via the Godot editor in `battle_scene.tscn`** — pre-instanced children are added at .tscn instantiation time, BEFORE `setup()` can fire; breaks DI null-check + signal subscription contracts — source: ADR-0016 R-2 + R-7 (forbidden_pattern: `battle_scene_pre_instanced_children`; lint: `tools/ci/lint_battle_scene_pre_instanced_children.sh`)
- **Never subscribe to or emit any GameBus signal from BattleScene root** — pure orchestrator-only role; cross-system signal flow goes through the 6 mounted children — source: ADR-0016 R-7 + IN-1 (forbidden_pattern: `battle_scene_root_signal_subscription`)
- **Sprint-6 ONLY**: `src/feature/battle_scene/battle_scene.gd` MUST contain explicit comment markers `# === SPRINT-6 MOCK ENCOUNTER ===` / `# === END MOCK ===` / `# === SPRINT-6 MOCK ENCOUNTER HELPERS ===` / `# === END SPRINT-6 MOCK ENCOUNTER HELPERS ===` around the inline mock encounter region. **Sprint-7+ (post-ADR-0017 acceptance): the lint SEMANTIC FLIPS** — markers MUST NOT exist (mock region must be deleted at ADR-0017 acceptance per §Migration Plan §1). The lint flip is in same patch as ADR-0017 deletion — source: ADR-0016 R-2 + Migration Plan §1 (forbidden_pattern: `battle_scene_sprint6_mock_marker_must_exist` — phase-flipping lint, 1st precedent)

### Performance Guardrails

| System | Metric | Budget | Source |
|--------|--------|--------|--------|
| BattleScene mount sequence | Wall clock | <50 ms typical (5-system instantiation + setup + add_child) | ADR-0016 |
| BattleScene root state | Memory | 0 — pure orchestrator, no instance fields beyond mount refs | ADR-0016 §3 |

---

## Pillar 2 Architectural Locks

*Applies to: any code that touches the hidden-fate semantic chain*

The game's Pillar 2 (운명은 바꿀 수 있다 — Destiny Can Be Rewritten) requires that
fate progress is HIDDEN from the player during battle and surfaces only at Beat 7
reserved-color reveal. This is **NOT a stylistic preference — it is a load-bearing
game-design invariant** that converts to **3 forbidden_patterns + 3 distinct lints**
each enforced at the architecture-registry layer.

If a future designer believes the player should see fate progress earlier, they
MUST first revise (1) `design/gdd/game-concept.md` Pillar 2, (2) `design/gdd/destiny-branch.md` Section B,
and (3) the relevant ADR — three coordinated revisions are intentionally hard.

| # | Pattern | Source ADR | Enforcement |
|---|---------|-----------|-------------|
| 1 | `battle_hud_subscribes_to_hidden_fate_signal` | ADR-0015 | grep-zero-token lint on `src/feature/battle_hud/battle_hud.gd` + connection-count test on controller signal channel + architecture-registry block on future ADR amendments |
| 2 | `scenario_runner_deferred_seal_in_beat_7_entry` | ADR-0017 | grep-zero-pattern lint on `src/core/scenario_runner.gd` + ADR-0017 inline source-comment annotation + integration test asserting BEAT_6_RESULT.accept → BEAT_7_JUDGMENT.entry happens in 1 frame |
| 3 | `destiny_branch_judge_reads_scenario_runner_state` | ADR-0018 | grep-zero-pattern lint on `src/feature/destiny_branch/*.gd` + 4-arg `resolve()` signature contract + CR-DB-2 pure-function rule |

These 3 forbidden_patterns establish the **pillar-anchored lint pattern** as
project discipline. Any future Pillar-anchored architectural decision should
follow the same enforcement triad: (a) source-grep lint at static-analysis time,
(b) ADR-level inline source-comment annotation, (c) integration / connection-count
test at runtime.

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

| ADR | Title | Status | Layer | TRs (registered count in tr-registry v14) |
|-----|-------|--------|-------|---|
| ADR-0001 | GameBus Autoload | Accepted 2026-04-18 (last amended 2026-05-04 delta #13) | Foundation | TR-gamebus-001, TR-scenario-progression-001..003, TR-grid-battle-001, TR-turn-order-001, TR-hp-status-001, TR-input-handling-001 |
| ADR-0002 | Scene Manager | Accepted 2026-04-18 | Foundation | TR-scene-manager-001..005 |
| ADR-0003 | Save/Load | Accepted 2026-04-18 | Foundation | TR-save-load-001..007 |
| ADR-0004 | Map/Grid Data Model | Accepted 2026-04-20 | Foundation + Core | TR-map-grid-001..010 |
| ADR-0005 | Input Handling | Accepted | Foundation | TR-input-handling-001..N (see `docs/registry/architecture.yaml`) |
| ADR-0006 | Balance/Data | Accepted | Foundation | TR-balance-data-001..N (5-precedent stateless utility 2nd invocation) |
| ADR-0007 | Hero Database | Accepted | Foundation | TR-hero-database-001..N (`@abstract` static-only; 5th in stateless utility lineage) |
| ADR-0008 | Terrain Effect | Accepted | Foundation + Core | TR-terrain-effect-001..N (5-precedent stateless utility 1st invocation) |
| ADR-0009 | Unit Role | Accepted | Foundation | TR-unit-role-001..N (`@abstract` static-only + 4th in stateless utility lineage) |
| ADR-0010 | HP/Status | Accepted | Core | TR-hp-status-001..N (battle-scoped Node 1st invocation) |
| ADR-0011 | Turn Order | Accepted | Core | TR-turn-order-001..N (battle-scoped Node 2nd invocation) |
| ADR-0012 | Damage Calc | Accepted | Feature | TR-damage-calc-001..N (5-precedent stateless utility 3rd invocation; sole-caller contract) |
| ADR-0013 | Battle Camera | Accepted | Feature | TR-camera-001..008 (battle-scoped Node 3rd invocation) |
| ADR-0014 | Grid Battle Controller | Accepted 2026-05-03 (delta #11; amended 2026-05-05 delta #14 for 6th LOCAL signal) | Core (battle-scoped Node 4th invocation) | TR-grid-battle-controller-001..014 |
| ADR-0015 | Battle HUD | Accepted 2026-05-03 (delta #10) | Presentation (battle-scoped Node 5th invocation) | TR-battle-hud-001..017 |
| ADR-0016 | Battle Scene Wiring | Accepted 2026-05-03 (delta #11; amended 2026-05-05 delta #14 for mount step 5.5) | Integration (1st scene-root-as-orchestrator invocation) | TR-battle-scene-wiring-001..011 |
| ADR-0017 | Scenario Progression | Accepted 2026-05-04 (delta #12) | Core (1st 13-state machine + 9-beat rhythm) | TR-scenario-progression-001..015 |
| ADR-0018 | Destiny Branch | Accepted 2026-05-04 (delta #13) | Feature (1st `@abstract` test-seam + 1st `direct_call` interface contract) | TR-destiny-branch-001..015 |
| ADR-0019 | AI System | Accepted 2026-05-05 (delta #14) | Feature (battle-scoped Node 6th invocation + 1st single-class match-dispatch + Pillar 2 lock 4th precedent) | TR-ai-system-001..015 |

**Total**: 19 ADRs Accepted; 254 TRs registered in `tr-registry.yaml` v15; Core layer 5/5 Complete + Feature layer 4/4 Complete (per `architecture-traceability.md` v0.14 post-S7-01 delta #14).

---

## Changelog

| Date | Change |
|------|--------|
| 2026-04-20 | Initial manifest. 4 Accepted Foundation-layer ADRs covered (ADR-0001..0004). Re-run when subsequent ADRs land. |
| 2026-05-04 | Refresh per `/gate-check pre-production` 2026-05-04 path-to-PASS item #3. Absorbed ADRs 0014..0018: Grid Battle Controller (Core, ADR-0014, 3 forbidden_patterns) + Battle HUD (Presentation, ADR-0015, 5 forbidden_patterns incl. Pillar 2 lock #1) + Battle Scene Wiring (Integration NEW LAYER, ADR-0016, 3 forbidden_patterns incl. 1st phase-flipping lint) + Scenario Progression (Core, ADR-0017, 5 forbidden_patterns incl. Pillar 2 lock #2) + Destiny Branch (Feature, ADR-0018, 3 forbidden_patterns incl. Pillar 2 lock #3). Added new "Pillar 2 Architectural Locks" section codifying the 3-pattern triad. ADR-0001 amended to record `scenario_complete(ScenarioResult)` widening + `scenario_beat_retried(EchoMark)` ratification + `destiny_branch_chosen(DestinyBranchChoice)` ratification (PROVISIONAL signal count 4→2 across deltas #12+#13). **Coverage advisory**: ADRs 0005..0013 (Input / Balance Data / Hero DB / Terrain Effect / Unit Role / HP-Status / Turn Order / Damage Calc / Camera) remain governed by `docs/registry/architecture.yaml` structured entries; future manifest refresh should backfill dedicated subsections. |
| 2026-05-05 | Refresh per sprint-7 S7-08 (nice-to-have closure). **Coverage advisory CLOSED**: backfilled dedicated subsections for ADRs 0005..0013 (Input Handling + Balance/Data + Hero Database + Terrain Effect + Unit Role into Foundation; Terrain Effect Core portion + HP/Status + Turn Order into Core; Damage Calc + Battle Camera into Feature). Also added ADR-0019 AI System row (Accepted via /architecture-review delta #14 2026-05-05 sprint-7 S7-01). ADR-0014 + ADR-0016 changelog entries amended to reflect delta #14 amendments (6th LOCAL signal + mount step 5.5 insertion). Total ADR coverage 18 → 19; coverage advisory note in header REMOVED. Manifest grows from 513 → ~700 lines. Pillar 2 Architectural Locks section unchanged — pattern stable at 4 invocations + 2 candidates (Destiny State #16 GDD CR-DS-19 + Story Event #10 GDD CR-SE-19 per S7-06+S7-07 commits ba8da69 + 6bd359a). |
