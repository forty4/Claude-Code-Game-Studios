# Story 005: Custom Dijkstra — get_movement_range + get_path

> **Epic**: map-grid
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 5-6 hours — epic tentpole (custom Dijkstra with PackedByteArray visited + sorted PackedInt32Array priority queue + cost multiplier lookup + V-4 50-query reference-equivalence test + reference Dijkstra fixture + ADV-1 return-type resolution)

## Context

**GDD**: `design/gdd/map-grid.md`
**Requirement**: `TR-map-grid-002`, `TR-map-grid-003` (partial: 2 of 9 queries)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 Map/Grid Data Model
**ADR Decision Summary**: Custom inline Dijkstra on MapGrid (Godot's `AStarGrid2D` and `NavigationServer2D` are explicitly forbidden — per-cell scalar weight cannot carry a per-unit-type × per-terrain cost matrix). 4-directional adjacency; integer cost (`move_budget = move_range × 10`); `PackedByteArray` visited set; sorted `PackedInt32Array` priority queue with packed `(cost << 16) | tile_index` entries; static typing throughout inner loop.

**Engine**: Godot 4.6 | **Risk**: LOW (algorithm pre-cutoff; Packed arrays stable; no post-cutoff APIs)
**Engine Notes**: CR-6 AStarGrid2D rejection validated in `/architecture-review` 2026-04-20 (godot-specialist verdict: `set_point_weight_scale` is per-cell scalar, cannot carry per-unit-type matrix). `PackedInt32Array.bsearch` is the canonical insertion point for the priority-queue scratch buffer.

**Control Manifest Rules (Foundation + Core layers)**:
- Required: Pathfinding algorithm: custom Dijkstra — 4-directional adjacency, per-unit-type × per-terrain-type integer cost lookup (CR-6)
- Required: Cost scale: `move_budget = move_range × 10`; `step_cost = base_terrain_cost(terrain_type) × cost_multiplier(unit_type, terrain_type)` (GDD F-2/F-3)
- Required: Visited set — `PackedByteArray` of length `rows * cols`, indexed by `row * cols + col`; flag byte = 1 once finalized — avoids `Dictionary` allocation in hot loop
- Required: Priority queue — sorted `PackedInt32Array` scratch buffer with packed `(cost << 16) | tile_index` entries; `bsearch` for insertion
- Required: Static typing throughout inner loop; no `is_instance_valid()` or `typeof()` in hot path; cost table pre-validated at `load_map()` time
- Required: Early termination — `cost_so_far > move_budget` for `get_movement_range`; admissible heuristic lower-bound for `get_path`
- Forbidden: `AStarGrid2D` or `NavigationServer2D` for grid pathfinding (TR-map-grid-002)
- Forbidden: Dereference TileData objects in the Dijkstra hot loop — virtual-dispatch cost ~1200× per query; read packed caches only
- Guardrail: `get_movement_range` CPU <16 ms on 40×30, move_range=10, mid-range Android (AC-PERF-2 / TR-map-grid-006; empirical benchmark in story-007)

---

## Acceptance Criteria

*From GDD `design/gdd/map-grid.md` §CR-6, §AC-CR-6, §AC-F-1/2/3, §AC-EDGE-2 + ADR-0004 §Decision 7, V-4:*

- [ ] `get_movement_range(unit_id: int, move_range: int, unit_type: int) -> PackedVector2Array` returns the set of tiles the unit can reach and land on, given current grid state
- [ ] `get_path(from: Vector2i, to: Vector2i, unit_type: int) -> PackedVector2Array` returns the sequence of tiles along the lowest-cost path, or an empty array if unreachable
- [ ] ADR-0004 ADV-1 return-type decision resolved: `PackedVector2Array` with documented `Vector2(int(coord.x), int(coord.y))` construction (callers cast back to `Vector2i` at consumer boundary). Rationale documented in `map_grid.gd` header.
- [ ] AC-CR-6: `get_movement_range` excludes ENEMY_OCCUPIED tiles and every tile reachable only through them; ALLY_OCCUPIED tiles are traversable but not landable (return excludes ALLY_OCCUPIED tiles)
- [ ] AC-F-1 Manhattan distance via `|dc| + |dr|` used wherever a distance is needed
- [ ] AC-F-2 step cost formula: `step_cost = terrain_cost(terrain_type) × cost_multiplier(unit_type, terrain_type)` (placeholder `cost_multiplier` table — see Implementation Notes; ADR-0008 will populate final values)
- [ ] AC-F-3 budget boundary: move_range=3 (budget=30), PLAINS→HILLS→PLAINS = 10+15+10 = 35 > 30 → NOT reachable; PLAINS→ROAD→PLAINS = 10+7+10 = 27 ≤ 30 → reachable
- [ ] AC-EDGE-2: unit completely surrounded by IMPASSABLE + ENEMY_OCCUPIED → `get_movement_range` returns empty PackedVector2Array
- [ ] `get_path(from, to)` with `from == to` returns `PackedVector2Array([from])` (single-element); with unreachable `to` returns empty
- [ ] `is_passable_base == false` tiles (walls) never enter the priority queue
- [ ] Impassable terrain (RIVER, FORTRESS_WALL undestroyed) excluded via `is_passable_base_cache == 0` — hot-loop reads cache only, never dereferences TileData
- [ ] V-4 reference-equivalence: against a reference Dijkstra implementation (GDScript-reference in test file, NOT Python), 50 path queries produce the SAME total cost and a valid shortest path (either the same path or an equivalent-cost alternative) on a fixed 20×20 test fixture
- [ ] `_priority_queue_scratch: PackedInt32Array` declared on MapGrid class scope, cleared at start of each query (prevents per-query allocation on hot-path); `_visited_scratch: PackedByteArray` similarly reused
- [ ] `move_range == 0` returns `PackedVector2Array([origin_coord])` — unit stays in place (origin cost 0 satisfies budget 0)

---

## Implementation Notes

*Derived from ADR-0004 §Decision 7 + GDD §CR-6/F-2/F-3:*

- `src/core/terrain_cost.gd` — declares `class_name TerrainCost` (or a global-scope constants module, TBD at impl time) with:
  - `const BASE_TERRAIN_COST: Dictionary[int, int] = { PLAINS: 10, HILLS: 15, MOUNTAIN: 20, FOREST: 15, RIVER: 0, BRIDGE: 10, FORTRESS_WALL: 0, ROAD: 7 }` — RIVER/FORTRESS_WALL `0` because they are filtered upstream via `is_passable_base_cache`; their cost entry is unreachable but present to keep lookup O(1).
  - `static func cost_multiplier(unit_type: int, terrain_type: int) -> int` — PLACEHOLDER table returning 1 for all unit×terrain pairs, with a documented comment: "REPLACED WHEN ADR-0008 Terrain Effect lands; MVP ships with this placeholder". Alt: a single constant `1`. Keep the function signature stable so ADR-0008 replacement doesn't break consumers.
  - Terrain-type integer mirrors: `const PLAINS := 0, HILLS := 1, MOUNTAIN := 2, FOREST := 3, RIVER := 4, BRIDGE := 5, FORTRESS_WALL := 6, ROAD := 7` — these must match GDD §CR-3 ordering and the `TileData.terrain_type` @export int mirror.
- Priority queue entries: `(cost << 16) | tile_index`. Max cost in Dijkstra bounded by `move_range × 10 ≤ 100` (move_range max 10). 100 fits easily in 16 bits; `tile_index` max `40*30 = 1200` fits in remaining 16 bits. Packed Int32 holds both cleanly.
- `bsearch` for insertion: find insertion point, call `insert` on PackedInt32Array. PackedInt32Array has O(n) insert but frontier peaks <100 entries at move_range=10 on 40×30 — ADR-0004 performance analysis justifies this over a full heap class.
- Scratch buffer lifecycle: declare `_priority_queue_scratch := PackedInt32Array()` and `_visited_scratch := PackedByteArray()` at class scope. In each query's entry point: `_priority_queue_scratch.clear()` then `_visited_scratch.resize(_map.map_rows * _map.map_cols)` + `_visited_scratch.fill(0)`. This avoids per-query allocation on the hot path.
- Neighbour iteration: 4-directional offsets `[(0,-1), (1,0), (0,1), (-1,0)]`. Compute `nrow, ncol, nidx`. Skip if out of bounds. Skip if `_visited_scratch[nidx] == 1`. Skip if `_passable_base_cache[nidx] == 0`. Skip if `_tile_state_cache[nidx] == STATE_ENEMY_OCCUPIED` OR `STATE_IMPASSABLE`. ALLY_OCCUPIED is traversable (can be popped from queue) but not landable (excluded from result).
- `get_movement_range` result filter: pop all reached indices where `accumulated_cost <= move_budget` AND `_tile_state_cache[idx] == STATE_EMPTY` OR `STATE_DESTROYED` (landable tile_states per GDD §ST-1 table). Exclude ALLY_OCCUPIED from result even if reached.
- `get_path(from, to)`: standard Dijkstra with predecessor map (PackedInt32Array of size rows*cols, init to -1). On pop of `to`, walk predecessors back to `from`, reverse to `PackedVector2Array`. If `to` never popped (queue exhausted first), return empty array.
- V-4 reference implementation: write a second-order Dijkstra in `tests/fixtures/pathfinding_reference.gd` (or inline in the test file) that uses `Dictionary` + `Array` freely — the PRODUCTION Dijkstra is packed/typed for perf, the REFERENCE is simple/readable for correctness. Run both on the same 50 query set; assert total-cost equal and path validity (each step adjacent, each step passable, endpoint match).
- Static typing: every local variable in the inner loop explicitly typed. Specifically: `var nrow: int`, `var ncol: int`, `var nidx: int`, `var step: int`, `var new_cost: int`, etc. NO `var x = ...` implicit inference in the hot loop. This matches ADR-0004 §Decision 7 last bullet.
- Do NOT call `get_tile(coord)` from inside Dijkstra — always read the packed caches. `get_tile` allocates object refs (virtual dispatch) which kills the ~77KB cache advantage.
- For this story's tests, don't run the 40×30 move_range=10 benchmark — that's story-007. Tests here use 15×15 or 20×20 fixtures with 3-5 tile move_range sufficient for correctness.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: `get_attack_range`, `has_line_of_sight`, `get_attack_direction`, `get_adjacent_units`, `get_occupied_tiles` (the remaining 7 queries; LoS Bresenham is a separate algorithm)
- Story 007: 40×30 move_range=10 performance benchmark for AC-PERF-2 / V-1
- ADR-0008 Terrain Effect: final per-unit-type × per-terrain-type cost matrix values. MVP ships with the placeholder `1.0` multiplier; story-005 only wires the consumption contract.

---

## QA Test Cases

*Authored from GDD + ADR directly (lean mode).*

- **AC-1**: get_movement_range basic reachability (AC-F-3 boundary)
  - Given: 15×15 all-PLAINS map; unit at (7,7) with move_range=3, unit_type=INFANTRY (multiplier=1)
  - When: `grid.get_movement_range(unit_id=1, move_range=3, unit_type=INFANTRY)`
  - Then: returned PackedVector2Array contains exactly the tiles within Manhattan distance 3 of (7,7) that are reachable via 4-dir paths with accumulated cost ≤ 30; count matches the Manhattan-diamond tile count (13 tiles at dist 1..3 + origin = depending on edge trimming)
  - Edge cases: origin tile (7,7) MUST be in the result (budget=0 satisfies); `move_range=0` returns PackedVector2Array([Vector2(7,7)]) exactly

- **AC-2**: AC-F-3 budget boundary
  - Given: 3×3 strip with tiles (0,0)=PLAINS, (1,0)=HILLS, (2,0)=PLAINS, everything else non-reachable; unit at (0,0), move_range=3 (budget=30), unit_type=INFANTRY
  - When: `get_movement_range(1, 3, INFANTRY)`
  - Then: (2,0) NOT in result (cost 10+15+10=35 > 30); tile (1,0) IS in result (cost 10+15=25 ≤ 30)
  - Edge cases: swap (1,0) to ROAD → (2,0) IS reachable (cost 10+7+10=27 ≤ 30)

- **AC-3**: AC-CR-6 enemy blocks, ally passes
  - Given: straight east corridor (0,0)→(1,0)→(2,0)→(3,0), all PLAINS; (1,0) is ALLY_OCCUPIED, (2,0) is EMPTY, (3,0) is EMPTY; unit at (0,0), move_range=4
  - When: `get_movement_range`
  - Then: result contains (0,0), (2,0), (3,0); does NOT contain (1,0) (ally occupied, traversable but not landable)
  - Edge cases: change (1,0) to ENEMY_OCCUPIED → (2,0) and (3,0) also dropped (enemy blocks traversal); change (2,0) to IMPASSABLE → (3,0) dropped (impassable blocks)

- **AC-4**: AC-EDGE-2 complete encirclement
  - Given: unit at center of a 3×3 sub-grid where all 4 cardinal neighbours are IMPASSABLE or ENEMY_OCCUPIED
  - When: `get_movement_range`
  - Then: returns PackedVector2Array([center_coord]) — unit stays in place (origin always returned with cost 0)
  - Edge cases: same unit with `move_range=0` produces identical result

- **AC-5**: is_passable_base=false never traversed
  - Given: 15×15 with a wall row (all FORTRESS_WALL at row=7, is_passable_base=false); unit at (7, 6), move_range=10
  - When: `get_movement_range`
  - Then: no tile with row >= 7 appears in the result (wall row never entered); row=6 and above fully explored within budget
  - Edge cases: if a FORTRESS_WALL tile is DESTROYED (is_passable_base=true post-mutation via story-004), it becomes traversable; this test case is covered in the integration layer (story-006/007), not here

- **AC-6**: get_path basic
  - Given: 5×5 PLAINS; unit at (0,0), target (4,4), unit_type=INFANTRY
  - When: `grid.get_path(Vector2i(0,0), Vector2i(4,4), INFANTRY)`
  - Then: returns a PackedVector2Array of length 9 (Manhattan 4+4 + 1 for origin); each step is a valid 4-dir move; endpoints match
  - Edge cases: `from == to` returns `[from]` (length 1); unreachable target returns empty array

- **AC-7**: get_path respects cost (ROAD preferred)
  - Given: 3×5 grid; (0,0)→(4,0) corridor where middle row is PLAINS cost=10 but a ROAD detour (0,0)→(0,1)→(1,1)→...→(4,1)→(4,0) is cost=7 per tile
  - When: `grid.get_path(Vector2i(0,0), Vector2i(4,0), INFANTRY)`
  - Then: returned path total cost (sum of `BASE_TERRAIN_COST` lookups along path) EQUALS reference Dijkstra on same input; the path chosen may differ if multiple have same cost but must be cost-equivalent
  - Edge cases: ties accepted — assertion is on TOTAL cost, not specific tile sequence

- **AC-8**: V-4 reference equivalence (50-query fixture)
  - Given: fixed 20×20 mixed-terrain fixture (authored in test setup) with 50 `(from, to)` query pairs
  - When: for each pair, production `get_path` and reference Dijkstra both compute
  - Then: for all 50 pairs: (a) both return empty OR both non-empty; (b) if non-empty, total cost matches; (c) each step in production path is adjacent + passable + valid per `_tile_state_cache`
  - Edge cases: 5 of the 50 pairs are intentionally unreachable (wall bisects map) → both return empty

- **AC-9**: Scratch buffers reused (no per-query allocation)
  - Given: MapGrid loaded, `_priority_queue_scratch` and `_visited_scratch` accessible via test-scoped getter (or by reflection)
  - When: `get_movement_range` called 10 times in sequence
  - Then: scratch buffers' underlying memory address / identity remains consistent (Godot PackedArray doesn't expose pointer; assert by wrapping in a counter that fails if buffers reassigned — alternative: explicit `_query_count` + inspect no new `.new()` allocation)
  - Edge cases: test-scope soft assertion; primary guard is code-review, not runtime
  - Note: if assertion is infeasible in GdUnit4, mark this AC as "code review + static lint" and skip runtime check. Acceptable fallback — the correctness lives in the scratch-reset logic.

- **AC-10**: ADV-1 return type decision — PackedVector2Array, callers cast
  - Given: `get_movement_range` return value `r: PackedVector2Array`
  - When: `typeof(r)` inspected and `r[0]` cast back
  - Then: `typeof(r) == TYPE_PACKED_VECTOR2_ARRAY`; `Vector2i(r[0])` produces the expected integer-precision coord; `map_grid.gd` header doc-comment explicitly notes the cast responsibility
  - Edge cases: no silent float coercion for integer coords (x=5, y=3 stays exactly 5.0, 3.0 — no 4.999999)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/map_grid_pathfinding_test.gd` — must exist and pass (10 tests covering AC-1..10, including V-4 50-query reference equivalence)
- Reference Dijkstra implementation: `tests/fixtures/pathfinding_reference.gd` — GDScript, intentionally simple (Dictionary + Array), NOT performance-tuned; lives in test tree only

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (packed caches are the read source), Story 003 (validator guarantees pathfinding-ready state), Story 004 (mutation-driven tile_state changes are what Dijkstra must respect — tests may reuse mutation API to build scenarios)
- Unlocks: Story 006 (LoS/attack queries can reuse some caching patterns), Story 007 (performance benchmark exercises this story's Dijkstra at 40×30 move_range=10)
