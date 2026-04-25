# ADR-0004: Map/Grid Data Model

## Status
Accepted (2026-04-20, via `/architecture-review`)

## Date
2026-04-18

## Last Verified
2026-04-20

## Decision Makers
- Technical Director (architecture owner)
- User (final approval, 2026-04-20)
- godot-specialist (engine validation, 2026-04-20)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core — gameplay foundation data model |
| **Knowledge Risk** | MEDIUM — uses Godot 4.5+ `duplicate_deep()` and relies on 4.6-stable `@export`-typed `Array[Resource]` semantics; all other APIs are pre-cutoff. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/modules/navigation.md`, `design/gdd/map-grid.md`, `docs/architecture/ADR-0001-gamebus-autoload.md`, `docs/architecture/ADR-0002-scene-manager.md`, `docs/architecture/ADR-0003-save-load.md` |
| **Post-Cutoff APIs Used** | `Resource.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)` (4.5+) — used once per battle enter on the authoritative `MapResource` clone. **Errata (2026-04-25)**: earlier drafts referenced a `DEEP_DUPLICATE_ALL_BUT_SCRIPTS` flag — this enum value does NOT exist in Godot 4.6. The `DeepDuplicateMode` enum has three values only: `NONE`, `INTERNAL`, `ALL`. `ALL` is the correct max-depth mode for this use case. See save_manager.gd precedent (TD-024). |
| **Verification Required** | (1) Benchmark `get_movement_range()` on 40×30 map, move_range=10, unit_type=infantry: must be <16ms on mid-range Android target per AC-PERF-2. (2) Round-trip test: load `MapResource` → `duplicate_deep()` → apply destruction mutations → confirm disk asset unchanged. (3) Confirm Godot 4.6 inspector can edit a 1200-element `Array[MapTileData]` without editor stalls (acceptable if scrolling is slow, blocking if inspector hangs). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None (Foundation layer) |
| **Enables** | ADR-0008 Terrain Effect (consumes `MapTileData.terrain_type` + terrain-cost matrix contract); future Formation Bonus ADR; future AI ADR (consumes `tile_destroyed` signal for cached-path invalidation) |
| **Blocks** | Grid Battle, Terrain Effect, AI, Formation Bonus, HP/Status (positional checks), Input Handling (tile-tap routing) implementation — all 6 cannot start implementation until this ADR is Accepted |
| **Ordering Note** | Must be Accepted before ADR-0008 Terrain Effect. This ADR carries a concurrent amendment to ADR-0001 (Accepted 2026-04-18) adding an Environment domain banner + `tile_destroyed(coord: Vector2i)` signal — the amendment is part of this ADR's write pass, not a follow-up. |

## Context

### Problem Statement

`design/gdd/map-grid.md` defines the tile grid as MVP system #2 (foundation
layer) and is an upstream dependency for 9 downstream systems. Six of those
systems — Grid Battle, Terrain Effect, AI, Formation Bonus, HP/Status,
Input Handling — cannot begin implementation until four questions are
locked:

1. **Storage layout** — how the 15–40 col × 15–30 row tile grid is represented in memory (Array[Resource]? TileMapLayer? SoA packed arrays?)
2. **Map-authoring data format** — GDD Open Question #2 ("맵 에디터 / 맵 데이터 포맷") is explicitly owned by Architecture (ADR)
3. **Runtime lifecycle** — autoload vs battle-scoped Node vs pure Resource
4. **Pathfinding placement** — inline on MapGrid vs separate PathfindingService

Implementation cannot start without these decisions. This ADR resolves all
four and records the concurrent ADR-0001 amendment required to make Map/Grid
a signal emitter for the `tile_destroyed(coord)` event.

### Constraints

**From `design/gdd/map-grid.md` (locked by Game Designer):**

- **CR-2**: Flat-array storage, indexed as `row * map_cols + col`
- **CR-6**: Custom Dijkstra only — Godot's `AStarGrid2D` and
  `NavigationServer2D` are explicitly forbidden
- **AC-PERF-2**: `get_movement_range()` must return in <16ms on a 40×30 map
  at `move_range=10` (mid-range mobile target)
- **GDD Interactions §**: 9 public query methods must be exposed (read-only)
- **Aesthetic constraint**: ink-wash 2D art style is not compatible with
  atlas-tileset authoring workflows — TileMapLayer-based visuals are
  unidiomatic for this project
- **1 GameBus signal**: `tile_destroyed(coord)` emitted when a destructible
  tile is destroyed — consumed by AI (path cache invalidation), Formation
  Bonus (adjacency re-check), and VFX

**From `.claude/docs/technical-preferences.md`:**

- GDScript, static typing mandatory
- Mobile performance budgets: 512MB memory ceiling, 60fps / 16.6ms frame budget
- Test coverage floor: 100% for balance formulas (pathfinding cost formula
  included); 80% for gameplay systems

**From Accepted ADRs:**

- **ADR-0001** (GameBus): Cross-system signals must be on `/root/GameBus`.
  Payloads with ≥2 fields must be typed Resources (TR-gamebus-001). A
  single-primitive payload is the canonical form for single-value signals.
- **ADR-0002** (Scene Manager): Battle subsystems are scene-scoped — no
  cross-battle state persists in autoloads. BattleScene's child nodes are
  freed on return to overworld.
- **ADR-0003** (Save/Load): Typed Resources with `@export` fields are the
  canonical serialization shape. Schema evolution requires version bumps +
  migration registry. Loads use `CACHE_MODE_IGNORE`.

### Requirements

- Store a tile grid up to 40 cols × 30 rows = 1200 tiles
- Expose 9 typed query methods (read-only from outside MapGrid)
- Support tile mutation (occupancy change, destruction) via mutation API
  called only by Grid Battle
- Emit `tile_destroyed(coord: Vector2i)` on GameBus when a destructible tile
  is destroyed
- Per-unit-type × per-terrain-type cost matrix consumption (matrix
  definition deferred to ADR-0008 Terrain Effect)
- Elevation support (0/1/2) for line-of-sight
- Battle-scoped lifetime — MapGrid instance is freed when BattleScene is
  freed; zero cross-battle state
- Achieve AC-PERF-2 <16ms `get_movement_range()` on mobile target

## Decision

### 1. Tile Storage — `Array[MapTileData]` inside `MapResource`

```gdscript
class_name MapResource extends Resource

@export var terrain_version: int = 1  # bump on schema change (loader-first convention per save_context.gd)
@export var map_id: StringName
@export var map_rows: int
@export var map_cols: int
@export var tiles: Array[MapTileData]  # size = map_rows * map_cols

class_name MapTileData extends Resource

@export var coord: Vector2i
@export var terrain_type: int          # enum mirror (see TerrainType)
@export var elevation: int             # 0 | 1 | 2
@export var tile_state: int            # enum mirror (EMPTY, ALLY_OCCUPIED, ENEMY_OCCUPIED, IMPASSABLE, DESTRUCTIBLE, DESTROYED)
@export var is_destructible: bool
@export var destruction_hp: int
@export var occupant_id: int = 0       # 0 = none
@export var occupant_faction: int = 0  # 0 = none
@export var is_passable_base: bool = true
```

- Indexing: `tiles[coord.y * map_cols + coord.x]` (CR-2)
- ~64 B per `MapTileData` × 1200 tiles max = **~77 KB per map at rest**
- `Array[MapTileData]` is the **authoritative source** for mutation and
  serialization

### 2. Hot-Path Packed Caches (required for AC-PERF-2)

`MapTileData` objects are GDScript `Object` subclasses. Per-tile dereference in
the Dijkstra inner loop would pay virtual-dispatch cost ~1200× per
movement-range query — that is the dominant cost, not the algorithm itself.

`MapGrid` builds **parallel `PackedInt32Array` caches** from the
`Array[MapTileData]` at battle-enter (after `duplicate_deep()`):

```gdscript
var _terrain_type_cache: PackedInt32Array      # length = rows * cols
var _elevation_cache: PackedInt32Array
var _passable_base_cache: PackedByteArray      # bool as byte (0/1)
var _occupant_id_cache: PackedInt32Array       # mutated on set_occupant
var _occupant_faction_cache: PackedInt32Array
var _tile_state_cache: PackedInt32Array        # mutated on apply_tile_damage
```

**Invariants:**

- Every mutation method that updates `Array[MapTileData]` **must also update
  the corresponding cache entry in the same call** (write-through). The
  `Array[MapTileData]` is the authoritative source; the caches are a
  structural read-optimization.
- Pathfinding, LoS, and attack-range queries **read only from the packed
  caches** — they never dereference `MapTileData` in the hot loop.
- `get_tile(coord)` (a rare cold-path query) returns the `MapTileData` object
  directly for systems that need full tile detail.

### 3. Authoring Format — `.tres` at `res://data/maps/[map_id].tres`

- **MVP**: Godot's native Resource text format (`.tres`). Maps authored via
  Godot's built-in inspector on `MapResource` + `MapTileData` sub-resources.
- **No custom editor plugin for MVP** — Open Question #2 is resolved:
  authoring happens in the Godot inspector.
- **Shipped builds**: converted to binary `.res` for load speed (see Risks).
- Load: `ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)`
  — mirrors ADR-0003's mandate for save-loaded Resources. Map data is
  read-only, so caching would not cause correctness issues, but ignoring
  the cache keeps the pattern uniform across all battle-scoped Resource
  loads and avoids stale-asset issues during iteration.

### 4. Runtime Lifecycle — `MapGrid extends Node`, Battle-Scoped

```
BattleScene (scene root — battle-scoped per ADR-0002)
  ├── MapGrid (Node)
  │     • holds duplicate_deep() clone of MapResource
  │     • builds + owns packed caches
  │     • inline: Dijkstra, Bresenham LoS
  │     • emits GameBus.tile_destroyed(coord)
  ├── TurnOrder (Node)
  ├── UnitRoster (Node)
  └── ... other battle subsystems
```

- `MapGrid` is a plain `Node` (not `Node2D`) — it has no visual
  representation of its own; visuals are owned by a sibling `MapRenderer`
  node (out of this ADR's scope).
- On `load_map(res: MapResource)`:
  1. `_map = res.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)` — clones so destruction state does not
     pollute the disk asset
  2. Build packed caches from `_map.tiles`
- On scene free: `MapGrid` is freed with BattleScene; all state gone.

### 5. Query API (public, read-only)

```gdscript
func get_tile(coord: Vector2i) -> MapTileData
func get_movement_range(unit_id: int, move_range: int, unit_type: int) -> PackedVector2Array
func get_movement_path(from: Vector2i, to: Vector2i, unit_type: int) -> PackedVector2Array
func get_attack_range(origin: Vector2i, attack_range: int, apply_los: bool) -> PackedVector2Array
func get_attack_direction(attacker: Vector2i, defender: Vector2i, defender_facing: int) -> int  # enum
func get_adjacent_units(coord: Vector2i, faction: int = -1) -> PackedInt32Array  # unit_ids
func get_occupied_tiles(faction: int = -1) -> PackedVector2Array
func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool
func get_map_dimensions() -> Vector2i
```

> **Errata 2026-04-25 (TD-032 A-18, A-21)**: Original signatures were `get_path(...)`,
> `get_attack_range(origin, range)`, `get_attack_direction(attacker, defender)`,
> and `get_adjacent_units(coord)` / `get_occupied_tiles()` (no faction filter).
> Updated to actual implementation per stories 005, 006, 008:
> - `get_path` renamed to `get_movement_path` to avoid shadowing inherited
>   `Node.get_path() -> NodePath` (G-13 candidate gotcha).
> - `get_attack_range` adds `apply_los: bool` parameter for §CR-7 ranged-vs-melee
>   distinction.
> - `get_attack_direction` adds `defender_facing: int` parameter for §F-5 angular
>   formula (FRONT/FLANK/REAR depends on defender orientation).
> - `get_adjacent_units` and `get_occupied_tiles` add optional `faction` filter
>   (default `-1` = any faction).

### 6. Mutation API (called only by Grid Battle)

```gdscript
func set_occupant(coord: Vector2i, unit_id: int, faction: int) -> void
func clear_occupant(coord: Vector2i) -> void
func apply_tile_damage(coord: Vector2i, damage: int) -> bool
    # Returns true if the tile was destroyed by this damage.
    # On destruction: updates MapTileData + caches, emits GameBus.tile_destroyed(coord).
```

- These methods are **not marked private** (GDScript has no access control),
  but the convention is documented: only `GridBattleController` calls
  mutation methods. Violation is caught in code review; no runtime guard.

### 7. Pathfinding — Custom Dijkstra, Inline

- **Algorithm**: Dijkstra with 4-directional adjacency, per-unit-type ×
  per-terrain-type cost lookup. Cost matrix is owned by ADR-0008 Terrain
  Effect and consumed here via a constant `TerrainCost` table.
- **Integer cost** per GDD F-3: `move_budget = move_range × 10`.
  `step_cost = base_terrain_cost(terrain_type) × cost_multiplier(unit_type, terrain_type)`.
  `step_cost` is the cost of **entering** a tile (origin contributes 0; only non-origin
  tiles accumulate cost). Standard Dijkstra convention.

  > **Errata 2026-04-25 (TD-032 A-20)**: Earlier draft examples in this ADR and
  > story-005 used a non-standard "origin-included" cost model
  > (e.g. "PLAINS→HILLS→PLAINS = 10+15+10 = 35"). The implementation uses
  > **standard Dijkstra** (origin entry cost = 0), so the same path costs 25
  > (only 2 transitions; origin contributes 0). All cost-formula examples in
  > this ADR + GDD §F-3 + story-005 spec are reconciled to the standard model:
  > a 3-tile horizontal traversal costs `step_cost(tile_2) + step_cost(tile_3)`,
  > NOT `step_cost(origin) + step_cost(tile_2) + step_cost(tile_3)`.
- **Early termination**: abort exploration when
  `remaining_budget < min_remaining_cost_to_reach(goal)`. For
  `get_movement_range()` (no goal), simply stop expanding when
  `cost_so_far > move_budget`.
- **Visited set**: `PackedByteArray` of length `rows * cols`, indexed by
  `row * cols + col`. Flag byte = `1` once finalized. Avoids `Dictionary`
  allocation in the hot loop.
- **Priority queue**: sorted `PackedInt32Array` scratch buffer storing
  packed `(cost << 16) | tile_index` entries; `bsearch` for insertion.
  Rationale: a full heap class adds GDScript dispatch overhead, and
  Dijkstra frontier size at `move_range=10` peaks at <100 entries —
  insertion-sort over a small packed array outperforms heapify on mobile.
- **Static typing throughout**: every local variable typed. No
  `is_instance_valid()` or `typeof()` in the inner loop. Cost table
  pre-validated at `load_map()` time.

### 8. Line of Sight — Bresenham + Elevation

- Rasterize a line from `from` to `to` using integer Bresenham on the
  flat grid.
- For each rasterized tile between endpoints:
  - If tile is destroyed terrain type (walls, fortress_wall with state =
    DESTROYED), LoS is NOT blocked (now passable sight)
  - If tile has `elevation > max(from_elev, attacker_elev)`, LoS is blocked
  - Endpoints themselves are never blockers (attacker/defender tiles always
    allow LoS from/to themselves)
- Elevation values read from `_elevation_cache` (packed).

### 9. GameBus Signal Contract

- **One outbound signal**: `tile_destroyed(coord: Vector2i)` on
  `/root/GameBus`
- **Single-primitive payload** — compliant with TR-gamebus-001 (≥2-field
  payloads require typed Resource; 1-primitive is the canonical form)
- **Emitter**: `MapGrid` (sole emitter)
- **Consumers**: AI (path cache invalidation), Formation Bonus (adjacency
  re-check on adjacent tile destruction), VFX system (play destruction
  effect)
- **ADR-0001 amendment required**: a new "Environment" domain banner is
  added to ADR-0001's signal contract tables and code block. Total signal
  count: 26 → 27. Domain banner count: 7 → 8. Map/Grid moves from
  "non-emitter" to emitter in ADR-0001 line 354.

### 10. Save/Load Integration

- **MapResource** on disk is read-only — never serialized via SaveManager.
- **Runtime mutations** (occupancy, destruction) live in `MapGrid`'s cloned
  `_map` + caches.
- **Mid-battle saves are out of scope for MVP** (ADR-0003 CP-1/CP-2/CP-3
  all fire outside battle). A future `MapRuntimeState` typed Resource can
  be added without changing this ADR's decision — it would serialize just
  the mutated fields (tile_state, occupancy) keyed by coord.

## Architecture Diagram

```
  ┌────────────────────────────────────────────────────────────┐
  │  BattleScene  (battle-scoped, freed on return to overworld)│
  │                                                            │
  │   ┌──────────────────────────┐                             │
  │   │  MapGrid (Node)          │   load_map(res: MapResource)│
  │   │                          │◄────┐                       │
  │   │  _map: MapResource       │     │ ResourceLoader.load   │
  │   │    (duplicate_deep clone)│     │ (CACHE_MODE_IGNORE)   │
  │   │                          │     │                       │
  │   │  Packed caches:          │   res://data/maps/*.tres    │
  │   │   _terrain_type[]        │                             │
  │   │   _elevation[]           │                             │
  │   │   _passable_base[]       │                             │
  │   │   _occupant_id[]         │                             │
  │   │   _tile_state[]          │                             │
  │   │                          │                             │
  │   │  Public: 9 query methods │                             │
  │   │  Convention: mutation    │                             │
  │   │    only from GridBattle  │                             │
  │   └───────────┬──────────────┘                             │
  │               │ tile_destroyed(coord: Vector2i)            │
  │               ▼                                            │
  │       /root/GameBus  ◄─ emit                               │
  │               │                                            │
  │       (relays to AI, Formation, VFX subscribers)           │
  └────────────────────────────────────────────────────────────┘
```

## Key Interfaces

```gdscript
class_name MapGrid extends Node

# ─── Lifecycle ────────────────────────────────────────────
func load_map(map_res: MapResource) -> void
func get_map_dimensions() -> Vector2i

# ─── Query API (read-only; reads packed caches only) ──────
# Signatures reflect actual implementation per stories 005-006-008 (see §Decision 5
# errata for the rename + parameter additions).
func get_tile(coord: Vector2i) -> MapTileData
func get_movement_range(unit_id: int, move_range: int, unit_type: int) -> PackedVector2Array
func get_movement_path(from: Vector2i, to: Vector2i, unit_type: int) -> PackedVector2Array
func get_attack_range(origin: Vector2i, attack_range: int, apply_los: bool) -> PackedVector2Array
func get_attack_direction(attacker: Vector2i, defender: Vector2i, defender_facing: int) -> int
func get_adjacent_units(coord: Vector2i, faction: int = -1) -> PackedInt32Array
func get_occupied_tiles(faction: int = -1) -> PackedVector2Array
func has_line_of_sight(from: Vector2i, to: Vector2i) -> bool

# ─── Mutation API (Grid Battle only by convention) ────────
func set_occupant(coord: Vector2i, unit_id: int, faction: int) -> void
func clear_occupant(coord: Vector2i) -> void
func apply_tile_damage(coord: Vector2i, damage: int) -> bool

# ─── Signal (owned by GameBus; MapGrid emits) ─────────────
# GameBus.tile_destroyed(coord: Vector2i)
```

**Storage schema (Resources):**

```gdscript
class_name MapResource extends Resource
@export var terrain_version: int = 1  # loader-first convention (save_context.gd mirror)
@export var map_id: StringName
@export var map_rows: int
@export var map_cols: int
@export var tiles: Array[MapTileData]

class_name MapTileData extends Resource
@export var coord: Vector2i
@export var terrain_type: int
@export var elevation: int
@export var tile_state: int
@export var is_destructible: bool
@export var destruction_hp: int
@export var occupant_id: int = 0
@export var occupant_faction: int = 0
@export var is_passable_base: bool = true
```

## Alternatives Considered

### Alternative 1: TileMapLayer + parallel `Array[MapTileData]` overlay

- **Description**: Use Godot's `TileMapLayer` (4.3+) for visuals and
  authoring; maintain a parallel `Array[MapTileData]` as the gameplay
  source-of-truth.
- **Pros**: Free tile-editor UX in Godot. Atlas-based rendering.
- **Cons**: Two sources of truth requiring sync on every mutation. Atlas
  workflow is unidiomatic for ink-wash aesthetic (tiles are
  contextually-painted, not atlas-sampled). Save/load story complicates —
  which source serializes?
- **Rejection Reason**: The sync-duplication cost and aesthetic mismatch
  outweigh the editor ergonomics win. Inspector-based authoring is
  acceptable for ≤5 MVP maps.

### Alternative 2: Struct-of-Arrays (`PackedInt32Array` per field) as primary storage

- **Description**: Replace `Array[MapTileData]` entirely with parallel
  `PackedInt32Array` for each field. No `MapTileData` Resource class exists;
  tiles are "records" defined by array-index convention.
- **Pros**: Tightest memory. Fastest iteration. Expected <2ms Dijkstra on
  40×30.
- **Cons**: Not `@export`-friendly — no `.tres` authoring. Schema
  extension requires manual migration of all parallel arrays. Violates
  ADR-0003's typed-Resource convention. No editor inspection of individual
  tiles.
- **Rejection Reason**: The packed-cache layer (Decision §2) captures the
  performance win without sacrificing `.tres` authoring or ADR-0003
  consistency. SoA-as-primary is a premature optimization given the ~77KB
  storage and <16ms budget are both comfortably met by the hybrid design.

### Alternative 3: Autoload singleton `/root/MapGrid`

- **Description**: Single persistent autoload that swaps the active
  `MapResource` on battle entry.
- **Pros**: Globally queryable without node lookup.
- **Cons**: Global mutable state. Violates ADR-0002's battle-scoped
  lifecycle. Risk of state leak between battles if a mutation runs after
  battle-return.
- **Rejection Reason**: ADR-0002 intentionally scopes battle state to
  BattleScene. An autoload MapGrid would be an architectural regression.

### Alternative 4: Resource-only (no wrapping Node)

- **Description**: `MapResource` is the runtime — callers hold the
  Resource and invoke methods on it directly. No `MapGrid` Node.
- **Pros**: Minimal nesting.
- **Cons**: Cannot `emit_signal` from a Resource without a Node host.
  Cannot use `@onready` or ready-propagation for cache construction.
  Signal emission for `tile_destroyed` would require a separate
  signal-relay Node anyway.
- **Rejection Reason**: A Node host is required for the signal emission
  path; removing it only moves the complexity elsewhere.

## Consequences

### Positive

- **Consistent with ADR-0003**: typed Resources with `@export` fields
  unify the save/load and map-data storage stories.
- **`.tres` authoring for free**: Godot inspector edits maps without any
  custom editor tool. Open Question #2 resolved.
- **Battle-scoped lifetime**: zero cross-battle state leak risk; matches
  ADR-0002's IDLE → LOADING_BATTLE → IN_BATTLE → free lifecycle.
- **Packed-cache layer**: hot-path queries bypass `MapTileData`
  virtual-dispatch cost — AC-PERF-2 achievable on mobile.
- **Inline pathfinding**: matches GDD's 9-query-interface section
  literally; single test surface for benchmarks.
- **Schema evolution path**: `terrain_version` field + ADR-0003 migration
  registry pattern applies if `MapTileData` schema changes post-MVP.

### Negative

- **~1200 `MapTileData` Resource allocations per battle**: ~77KB plus
  per-Resource object overhead. Negligible on mobile (well under 512MB
  ceiling), but a noticeable `duplicate_deep()` cost (~1–3ms on low-end
  Android — must verify).
- **Dual storage (Resource + packed caches)**: mutation methods must
  write-through to both. A missed cache update is a silent correctness
  bug. Mitigation: single mutation entry point per field; unit test
  coverage on all mutation paths.
- **`.tres` inspector editing at 1200 elements is slow to scroll**: the
  Godot inspector does not choke, but authors will experience UI lag when
  scrolling a full-size map. Acceptable for MVP (≤5 maps); revisit if
  content authoring cost becomes painful.
- **`.tres` text format in version control**: 1200 inline sub-resources
  produce noisy diffs. Shipped builds use binary `.res` (see Risks);
  source-control remains `.tres` for reviewability.

### Risks

- **R-1: AC-PERF-2 may not be met on low-end Android.** Mitigation: the
  Verification Required table mandates an empirical benchmark. If
  Dijkstra exceeds 16ms, fallback options (in increasing complexity): (a)
  reduce max map size from 40×30 to 32×24, (b) precompute a flow-field for
  `get_movement_range()`, (c) move Dijkstra to GDExtension C++. None of
  these change the public API — this ADR remains valid.
- **R-2: `.tres` load time on shipped builds.** A `.tres` with 1200
  embedded sub-resources loads noticeably slower than binary `.res`.
  Mitigation: production export pipeline converts all maps in
  `res://data/maps/` to `.res` via Godot's import settings. `.tres`
  remains the source-of-truth in version control.
- **R-3: `duplicate_deep()` only clones embedded sub-resources.** If a
  future refactor extracts `MapTileData` to shared `.tres` presets with
  UIDs (e.g., "mountain_preset.tres" referenced by UID from many maps),
  `duplicate_deep()` returns the shared instance instead of cloning —
  destruction state would leak between maps. Mitigation: **hard
  constraint** — for as long as this ADR stands, `MapTileData` MUST remain
  inline inside `MapResource.tres` files with no external UID references.
  A future refactor to shared presets requires a new ADR superseding this
  one.
- **R-4: Cache-sync drift.** If a mutation method updates `Array[MapTileData]`
  without updating the matching packed cache, queries will return stale
  data. Mitigation: a single mutation method per field — no ad-hoc writes
  permitted; mutation methods are small and test-covered.
- **R-5: Inspector ergonomics.** Authoring a 40×30 map in the Godot
  inspector by scrolling through 1200 array elements is tedious.
  Mitigation: accept for MVP; if content authoring becomes a bottleneck
  during playtest content push, build a custom editor dock (tracked as
  post-MVP tooling work, not this ADR's scope).

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|---|---|---|
| `map-grid.md` | CR-2: flat-array storage indexed `row * cols + col` | `MapResource.tiles: Array[MapTileData]`; indexing formula documented in Decision §1 |
| `map-grid.md` | CR-6: custom Dijkstra, AStarGrid2D rejected | Decision §7 mandates custom Dijkstra inline on MapGrid; AStarGrid2D + NavigationServer2D explicitly rejected in Alternatives |
| `map-grid.md` | Open Question #2: map data format | Resolved: `.tres` text format at `res://data/maps/[map_id].tres`, Godot inspector authoring, binary `.res` in shipped builds |
| `map-grid.md` | Interactions §: 9 public query methods | Key Interfaces section defines all 9 with typed signatures |
| `map-grid.md` | AC-PERF-2: `get_movement_range` <16ms on 40×30 | Decision §2 (packed caches) + §7 (Dijkstra tuning) + Verification Required benchmark |
| `map-grid.md` | `tile_destroyed(coord)` signal on GameBus | Decision §9 + concurrent ADR-0001 amendment (Environment banner) |
| `map-grid.md` | Read-only external access | Query API methods are public; mutation API is convention-scoped to Grid Battle |
| `map-grid.md` | 4-directional movement | Decision §7: 4-directional adjacency |
| `map-grid.md` | Elevation 0/1/2 for LoS | MapTileData.elevation field; Decision §8 Bresenham + elevation check |
| `map-grid.md` | 15–40 col × 15–30 row map size range | MapResource.map_rows / map_cols not capped in code; max benchmarked is 40×30 |
| `grid-battle.md` | Place/remove units on tiles; apply damage to tiles | Decision §6: set_occupant / clear_occupant / apply_tile_damage |
| `terrain-effect.md` | Consume `terrain_type` and apply per-unit-type cost multipliers | MapTileData.terrain_type as int enum; ADR-0008 defines the cost matrix consumed by Decision §7 |

## Performance Implications

- **CPU**: `get_movement_range()` target <16ms on 40×30, move_range=10
  (AC-PERF-2). Expected <5ms with packed caches + 4-dir + early
  termination. Verification required on low-end Android (Moto G series or
  equivalent).
- **Memory**: ~77KB per map at rest (1200 × ~64B `MapTileData`). Packed
  caches add ~36KB per map (6 arrays × ~6KB). `duplicate_deep()` clone =
  same footprint. Total <150KB per active battle — well under 512MB
  ceiling.
- **Load Time**: `ResourceLoader.load()` of `.tres` with 1200 inline
  sub-resources: target <100ms. Binary `.res` in shipped builds: target
  <50ms. Battle-enter budget per ADR-0002 permits up to 2 seconds;
  MapResource load is a minor contributor.
- **Network**: N/A (single-player).

## Migration Plan

None — greenfield decision for an unimplemented system. Schema evolution
post-MVP follows ADR-0003's migration registry pattern
(`terrain_version` bump + migration Callable).

## Validation Criteria

- **V-1**: `get_movement_range(unit_id, 10, UnitType.INFANTRY)` on a 40×30
  stress-test map completes in <16ms on mid-range mobile target (AC-PERF-2).
- **V-2**: Round-trip test: load `MapResource` → `duplicate_deep()` →
  apply 10 `apply_tile_damage()` calls that destroy tiles → confirm disk
  asset is unchanged on reload.
- **V-3**: `has_line_of_sight(a, b)` returns correct result across a fixed
  test matrix of 20 cases covering elevation 0/1/2 combinations and
  destroyed-wall cases.
- **V-4**: Dijkstra path equivalence test — 50 path queries against a
  reference Python Dijkstra implementation produce identical paths.
- **V-5**: Cache-sync test — every mutation method is unit-tested to
  verify both `Array[MapTileData]` and the matching packed cache updated.
- **V-6**: `GameBus.tile_destroyed(coord)` fires exactly once per
  destruction event; subscriber receives correct Vector2i.
- **V-7**: Inspector loads a 40×30 `MapResource.tres` without editor hang
  (acceptable if scrolling is slow).

## Related Decisions

- **ADR-0001** (GameBus Autoload, Accepted 2026-04-18) — **amended by this
  ADR**: adds Environment domain banner with `tile_destroyed(coord:
  Vector2i)`, bumps total signal count to 27, domain count to 8. Map/Grid
  moves from non-emitter to sole emitter of this signal.
- **ADR-0002** (Scene Manager, Accepted 2026-04-18) — MapGrid is a
  BattleScene child, freed on return to overworld. Aligns with
  LOADING_BATTLE → IN_BATTLE lifecycle.
- **ADR-0003** (Save/Load, Accepted 2026-04-18) — typed-Resource +
  `@export` pattern mirrored here. `terrain_version` field follows
  schema-evolution pattern. `CACHE_MODE_IGNORE` used for MapResource
  loads. MapRuntimeState (mid-battle save) deferred.
- **ADR-0008** (Terrain Effect, not yet authored) — will define the
  per-unit-type × per-terrain-type cost matrix consumed by Decision §7.
  This ADR declares the consumption contract; ADR-0008 defines the values.

## Changelog

| Date | Change |
|------|--------|
| 2026-04-18 | Initial draft. Proposed status. Resolves map-grid.md Open Question #2. Carries concurrent amendment to ADR-0001 (Environment domain banner + `tile_destroyed` signal). |
| 2026-04-20 | Status flipped Proposed → Accepted via `/architecture-review` (context-isolated godot-specialist validation: 8/8 engine checks APPROVED). All R-1..R-5 mitigations verified consistent with Godot 4.6. CR-6 custom-Dijkstra rejection of AStarGrid2D re-confirmed (4.6 `set_point_weight_scale` is per-cell scalar, cannot carry per-unit-type × per-terrain-type cost matrix). TR-map-grid-001..010 registered in tr-registry.yaml v3. Advisory carried (non-blocking): `get_movement_range()` return type `PackedVector2Array` vs `Array[Vector2i]` — defer to GDScript specialist at implementation time per /dev-story. |
| 2026-04-25 | **Errata sweep** (TD-032 A-1 + A-2 + A-9, post-story-004 close-out batch): (1) `TileData` → `MapTileData` project-wide rename in Decision §1 + Key Interfaces + Risks + GDD Requirements table. Root cause: Godot 4.4+ built-in `TileData` class (TileSet/TileMapLayer API) silently collides with user `class_name TileData` — see `.claude/rules/godot-4x-gotchas.md` G-12. (2) `MapResource.terrain_version` moved to first field position (loader-first convention mirrors `save_context.gd::schema_version`). (3) `duplicate_deep()` flag clarified as `Resource.DEEP_DUPLICATE_ALL` — `DEEP_DUPLICATE_ALL_BUT_SCRIPTS` (mentioned in earlier drafts) does NOT exist in Godot 4.6's `DeepDuplicateMode` enum (NONE/INTERNAL/ALL only). Implementation already used the correct flag per map_grid.gd:152 inline-errata comment + save_manager.gd precedent (TD-024). |
