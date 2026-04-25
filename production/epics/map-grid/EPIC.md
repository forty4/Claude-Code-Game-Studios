# Epic: Map/Grid System

> **Layer**: Foundation
> **GDD**: design/gdd/map-grid.md (Designed, APPROVED)
> **Architecture Module**: MapGrid (docs/architecture/architecture.md §Foundation layer)
> **Status**: Ready
> **Manifest Version**: 2026-04-20
> **Stories**: 8 — see table below

## Overview

Map/Grid is the battle-scoped Foundation system that owns the 2D tile grid on which all combat unfolds. It implements `CR-2` flat-array storage (`tiles[row*cols+col]`) with an `Array[TileData]` authoritative source-of-truth inside a `MapResource` typed Resource, backed by 6 parallel packed caches (`PackedInt32Array` / `PackedByteArray`) built at `load_map()` after `duplicate_deep()`. Pathfinding uses custom Dijkstra with per-unit-type × per-terrain-type integer cost matrix (Godot's `AStarGrid2D` and `NavigationServer2D` are explicitly forbidden — their per-cell scalar weight model cannot carry the 2D cost matrix). Line-of-sight uses integer Bresenham with elevation + destroyed-wall rules. MapGrid exposes 9 public read-only query methods and a 3-method mutation API called only by Grid Battle. It emits exactly one GameBus signal (`tile_destroyed(coord: Vector2i)`) — single-primitive canonical form per TR-gamebus-001. MapGrid is a plain `Node` (not `Node2D`, not autoload), battle-scoped as a BattleScene child, freed with BattleScene. Zero cross-battle state.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0004: Map/Grid Data Model | `Array[TileData]` + 6 packed caches hybrid storage; custom Dijkstra inline with `PackedByteArray` visited set + sorted `PackedInt32Array` priority queue; Bresenham LoS with elevation; `.tres` authoring at `res://data/maps/[map_id].tres`; TileData inline-only (no UID) hard constraint | LOW (TileMapLayer 4.3 pre-cutoff; Dijkstra inline; `Resource.duplicate_deep` 4.5+ is the only post-cutoff API and is verified via ADR-0003 precedent) |
| ADR-0001: GameBus Autoload | Emitted: `tile_destroyed(coord: Vector2i)` — single-primitive payload; Environment domain amendment (signals 26→27, domains 7→8) | LOW |
| ADR-0002: Scene Manager | MapGrid as BattleScene child; freed on IN_BATTLE → IDLE transition; zero cross-battle state | MEDIUM (inherits) |
| ADR-0003: Save/Load | Schema pattern mirrored: `terrain_version` field, `CACHE_MODE_IGNORE` load, `@export`-typed Resource. Mid-battle save out of scope for MVP | MEDIUM (inherits; duplicate_deep R-3 hard constraint documented) |

**Highest engine risk**: LOW (MapGrid-specific); MEDIUM (inherited from dependencies)

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-map-grid-001 | CR-2 flat-array `tiles[row*cols+col]`; authoritative `Array[TileData]`; packed caches are read-optimization | ADR-0004 ✅ |
| TR-map-grid-002 | CR-6 custom Dijkstra only; `AStarGrid2D` and `NavigationServer2D` forbidden | ADR-0004 ✅ |
| TR-map-grid-003 | 9 public read-only query methods (`get_tile`, `get_movement_range`, `get_path`, `get_attack_range`, `get_attack_direction`, `get_adjacent_units`, `get_occupied_tiles`, `has_line_of_sight`, `get_map_dimensions`) | ADR-0004 ✅ |
| TR-map-grid-004 | Mutation API (`set_occupant`, `clear_occupant`, `apply_tile_damage`) called only by GridBattleController; write-through to packed caches | ADR-0004 ✅ |
| TR-map-grid-005 | `tile_destroyed(coord: Vector2i)` single-primitive GameBus signal; Environment domain amendment landed | ADR-0004 + ADR-0001 ✅ |
| TR-map-grid-006 | AC-PERF-2: `get_movement_range()` <16 ms on 40×30 map, move_range=10, mid-range Android | ADR-0004 ✅ |
| TR-map-grid-007 | Battle-scoped Node; freed with BattleScene; zero cross-battle state | ADR-0004 ✅ |
| TR-map-grid-008 | Elevation 0/1/2 supported; integer Bresenham LoS with destroyed-walls-unblock rule + endpoints-never-self-block | ADR-0004 ✅ |
| TR-map-grid-009 | `.tres` authoring at `res://data/maps/[map_id].tres`; `CACHE_MODE_IGNORE` load; shipped builds use binary `.res` | ADR-0004 ✅ |
| TR-map-grid-010 | TileData inline-only inside `MapResource.tres` — no external UID references (`duplicate_deep` R-3 hard constraint) | ADR-0004 ✅ |

**Untraced Requirements**: None.

## Scope

**Implements**:
- `src/core/map_resource.gd` — typed `MapResource extends Resource` with `@export` fields (`map_id`, `map_rows`, `map_cols`, `tiles: Array[TileData]`, `terrain_version`)
- `src/core/tile_data.gd` — typed `TileData extends Resource` with all `@export` fields per CR-2 schema
- `src/core/map_grid.gd` — `MapGrid extends Node` with 9 query methods, 3 mutation methods, 6 packed caches, custom Dijkstra, Bresenham LoS
- `src/core/terrain_cost.gd` — constant cost table (per-unit-type × per-terrain-type) — will be refactored to source from Terrain Effect ADR-0008 when that lands
- `res://data/maps/` — folder structure (no actual maps yet; authored later via `/dev-story`)
- `tests/unit/core/map_grid_test.gd` — V-2 round-trip, V-3 LoS matrix (20 cases), V-4 Dijkstra path equivalence (50 queries vs reference), V-5 cache-sync per mutation, V-6 signal emission
- `tests/performance/map_grid_perf_test.gd` — V-1 `get_movement_range()` <16 ms benchmark on 40×30 fixture
- Manual verification: V-7 inspector loads 40×30 `.tres` without hang (documented in `production/qa/evidence/`)

**Does not implement**:
- Per-unit-type × per-terrain-type cost matrix values — deferred to ADR-0008 Terrain Effect (blocks story for TerrainCost concrete values, but TerrainCost contract struct can be implemented with placeholder values)
- Unit placement logic — belongs to Grid Battle epic (Feature layer)
- Map rendering (visuals) — belongs to MapRenderer sibling module (out of this ADR's scope, likely Presentation layer)
- Mid-battle save (`MapRuntimeState`) — deferred per ADR-0004 §Decision 10

## Dependencies

**Depends on (must be Accepted before stories can start)**:
- ADR-0001 (GameBus) ✅ Accepted 2026-04-18 — `tile_destroyed` signal
- ADR-0002 (SceneManager) ✅ Accepted 2026-04-18 — BattleScene child lifecycle
- ADR-0003 (Save/Load) ✅ Accepted 2026-04-18 — typed-Resource pattern + `CACHE_MODE_IGNORE` mirror
- ADR-0004 (this epic's governing ADR) ✅ Accepted 2026-04-20

**Soft-dependency (can start without, but cost values need resolution before shipped content)**:
- ADR-0008 Terrain Effect (not yet written) — per-unit-type × per-terrain-type cost matrix values. MapGrid can ship with placeholder costs until ADR-0008 lands.

**Enables** (unblocks implementation of):
- Terrain Effect #2 (consumes `get_tile()` + terrain_type)
- Grid Battle #1 (consumes `get_movement_range`, `get_path`, `get_attack_range`, `get_attack_direction`)
- Formation Bonus #3 (consumes `get_adjacent_units`)
- Damage/Combat Calc #11 (consumes `get_attack_direction`)
- AI #8 (consumes `get_movement_range`, `get_attack_range`, `get_occupied_tiles`, `has_line_of_sight`, `tile_destroyed`)
- HP/Status #12 (positional checks)
- Input Handling #29 (tile-tap routing via `get_tile`)
- Camera #22 (consumes `get_map_dimensions`)

## Implementation Decisions Deferred (from control-manifest)

- **`get_movement_range()` return type**: `PackedVector2Array` (float, requires `Vector2i` cast) vs `Array[Vector2i]` (integer precision preserved). Resolution: godot-gdscript-specialist at first `/dev-story` for this method. Either choice is consistent with the architectural contract.

## Cross-System Consumer Contracts (from ADR-0004 + GDD)

These are consumer-side rules other epics must honor when subscribing to MapGrid:

- **AI**: invalidate cached paths on `GameBus.tile_destroyed(coord)` — recompute on next query
- **Formation Bonus**: re-check adjacency for formations touching `coord` on `GameBus.tile_destroyed(coord)`; self-cache `coord_to_unit_id: Dictionary[Vector2i, int]` from `units: Array[UnitState]` at `round_started` (never call non-existent `MapGrid.get_unit_at`)
- **VFX**: play destruction effect at `coord` on `GameBus.tile_destroyed(coord)`

These contracts are enforced at the consumer epic — this epic implements only the emitter side.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria from `design/gdd/map-grid.md` (AC-CR-1..7, AC-F-1..5, AC-ST-1..4, AC-EDGE-1..4, AC-PERF-1..2) are verified via tests
- V-1 performance: `get_movement_range()` <16 ms on 40×30, move_range=10, mid-range Android (benchmark 100 iterations, p95 < 16 ms)
- V-2 round-trip: `MapResource` → `duplicate_deep()` → apply 10 `apply_tile_damage()` → disk asset unchanged on reload
- V-3 LoS: 20-case elevation + destroyed-wall matrix passes
- V-4 Dijkstra: 50-path equivalence vs reference Python implementation
- V-5 cache-sync: every mutation method verifies both `Array[TileData]` + matching packed cache updated
- V-6 signal emission: `GameBus.tile_destroyed(coord)` fires exactly once per destruction, subscriber receives correct `Vector2i`
- V-7 inspector: 40×30 `MapResource.tres` loads without editor hang (manual verification documented)
- Placeholder TerrainCost table acceptable; final values land when ADR-0008 Terrain Effect is Accepted

## Stories

| # | Story | Type | Status | ADR | Covers |
|---|-------|------|--------|-----|--------|
| 001 | MapResource + MapTileData Resource classes | Logic | Complete | ADR-0004 | TR-001, TR-010 |
| 002 | MapGrid skeleton + load_map + 6 packed caches + trivial queries | Logic | Complete | ADR-0004 | TR-001, TR-007, TR-009 (partial), V-2 partial |
| 003 | Map loading validation + error collection | Logic | Complete | ADR-0004 | TR-009, AC-CR-4, AC-EDGE-1, §EC-7 |
| 004 | Mutation API + packed cache write-through + tile_destroyed signal | Integration | Complete | ADR-0004 + ADR-0001 | TR-004, TR-005, V-5, V-6, AC-ST-1..4, AC-EDGE-4 |
| 005 | Custom Dijkstra — get_movement_range + get_movement_path | Logic | **Complete** (2026-04-25) | ADR-0004 | TR-002, TR-003 (2/9), TR-006, V-4, AC-CR-6, AC-F-1..3 |
| 006 | LoS + attack queries + adjacency (remaining 7 queries) | Logic | **Complete** (2026-04-25) | ADR-0004 | TR-003 (7/9), TR-008, V-3, AC-CR-5, AC-CR-7, AC-F-4, AC-F-5, AC-EDGE-3 |
| 007 | Performance baseline (desktop substitute) | Integration | **Complete** (2026-04-25) | ADR-0004 | TR-006, AC-PERF-1, AC-PERF-2, V-1 (desktop; mobile deferred) |
| 008 | Inspector authoring + 40×30 fixture manual QA | UI | **Complete** (2026-04-25; manual sign-off pending) | ADR-0004 | TR-009 (authoring), V-7 |

**Dependency chain**: 001 → 002 → {003, 004 sequential} → 005 → 006 → 007 → 008. Story 008 may be moved earlier (after 001) since it only needs the Resource schema. Story 005 resolves ADR-0004 ADV-1 (`get_movement_range` return type decision). Story 007 AC-TARGET mobile on-device deferred to Polish phase per save-manager/story-007 precedent.

## Next Step

Run `/story-readiness production/epics/map-grid/story-001-resource-classes.md` to validate the first story, then `/dev-story` to implement.
