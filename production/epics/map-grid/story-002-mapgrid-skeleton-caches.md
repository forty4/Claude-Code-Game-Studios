# Story 002: MapGrid skeleton + load_map + 6 packed caches + trivial queries

> **Epic**: map-grid
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 3-4 hours (MapGrid class + load_map + 6 packed caches + 2 trivial queries + duplicate_deep round-trip test; precedent: save-manager story-003 autoload skeleton took ~3h)

## Context

**GDD**: `design/gdd/map-grid.md`
**Requirement**: `TR-map-grid-001`, `TR-map-grid-007`, `TR-map-grid-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 Map/Grid Data Model
**ADR Decision Summary**: `MapGrid extends Node` (not Node2D, not autoload), battle-scoped as BattleScene child; on `load_map()` clones MapResource via `duplicate_deep()` and builds 6 parallel packed caches (5 `PackedInt32Array` + 1 `PackedByteArray`) as the hot-path read surface.

**Engine**: Godot 4.6 | **Risk**: LOW (this story) / MEDIUM (Map/Grid epic overall)
**Engine Notes**: `Resource.duplicate_deep(DUPLICATE_DEEP_ALL_BUT_SCRIPTS)` is the one post-cutoff API exercised here (4.5+). Precedent-verified via ADR-0003 SaveContext path — reuse the same flag constant. `PackedInt32Array` / `PackedByteArray` are pre-cutoff stable.

**Control Manifest Rules (Foundation layer)**:
- Required: MapGrid is a plain `Node` (not `Node2D`, not autoload); battle-scoped as BattleScene child — freed with BattleScene; zero cross-battle state (TR-map-grid-007)
- Required: Authoritative source-of-truth is `Array[TileData]`; packed caches (6 parallel `PackedInt32Array` / `PackedByteArray`) are built at `load_map()` after `duplicate_deep()`
- Required: Map loading via `ResourceLoader.load(path, "", CACHE_MODE_IGNORE)` — mirrors ADR-0003 pattern (TR-map-grid-009)
- Forbidden: Autoload `/root/MapGrid` — violates ADR-0002 battle-scoped lifecycle
- Forbidden: Dereference TileData objects in the Dijkstra hot loop (enforced in story-005; pre-emptively ensure caches carry all hot-path fields so story-005 has no reason to reach back into `TileData`)
- Guardrail: Packed caches ~36 KB (6 arrays × ~6 KB max); MapResource at rest ~77 KB; active battle map total <150 KB

---

## Acceptance Criteria

*From GDD `design/gdd/map-grid.md` §CR-1/CR-2 + ADR-0004 §Decision 2/4/5, scoped to skeleton + load + trivial queries:*

- [ ] `src/core/map_grid.gd` declares `class_name MapGrid extends Node` with no `_ready()` auto-load behaviour — `load_map(res: MapResource)` is the sole entry point
- [ ] `load_map(res)` assigns `_map = res.duplicate_deep(DUPLICATE_DEEP_ALL_BUT_SCRIPTS)` — the disk asset is NOT mutated by runtime destruction (V-2 partial)
- [ ] `load_map(res)` builds 6 packed caches from `_map.tiles`: `_terrain_type_cache: PackedInt32Array`, `_elevation_cache: PackedInt32Array`, `_passable_base_cache: PackedByteArray` (0/1), `_occupant_id_cache: PackedInt32Array`, `_occupant_faction_cache: PackedInt32Array`, `_tile_state_cache: PackedInt32Array`
- [ ] Every packed cache has length exactly `map_rows * map_cols` after `load_map()`
- [ ] `get_tile(coord: Vector2i) -> TileData` returns the cloned TileData at `tiles[coord.y * map_cols + coord.x]` when coord is in-bounds, `null` when out-of-bounds (AC-CR-1)
- [ ] `get_map_dimensions() -> Vector2i` returns `Vector2i(map_cols, map_rows)` (GDD Interactions table contract)
- [ ] Cache-values-at-construction test: for each cached field, every index `i` satisfies `cache[i] == int(_map.tiles[i].<field>)` (bool→byte 0/1 for `_passable_base_cache`)
- [ ] Disk asset unchanged on reload after `duplicate_deep`: save a MapResource → load into MapGrid → mutate `_map.tiles[0].destruction_hp` directly → reload from disk → destruction_hp unchanged (V-2 core assertion)

---

## Implementation Notes

*Derived from ADR-0004 §Decision 2/4/5 + §Consequences §Negative + R-3:*

- `_map: MapResource` is private; expose only `get_tile` + `get_map_dimensions` at this story's scope. Later stories add mutation API (004) and query suite (005, 006).
- `duplicate_deep(DUPLICATE_DEEP_ALL_BUT_SCRIPTS)` — use the flag constant, not the no-arg form. Script references on Resources bloat the clone unnecessarily on mobile.
- Build each packed cache by single pass over `_map.tiles` — pre-`resize()` the PackedArray to `rows * cols` then index-assign, do not use `append` in a loop (append pays re-alloc cost).
- `get_tile(coord)` bounds check: `coord.x < 0 or coord.x >= _map.map_cols or coord.y < 0 or coord.y >= _map.map_rows` → return `null`. This mirrors GDD §Edge Cases 1 "범위 밖 좌표 전달: null 반환. 호출자가 null 체크해야 함."
- `get_tile` returns the `TileData` object from `_map.tiles` directly (the cold-path contract per ADR-0004 §Decision 2 second-to-last paragraph). This is intentional — callers that need full detail pay one dereference. Hot-path queries in later stories read packed caches only.
- `get_map_dimensions()` returns `Vector2i(cols, rows)` — note the order: `.x = cols`, `.y = rows`. GDD Interactions table specifies `(map_cols, map_rows)`.
- Do not emit any signals in this story. Story 004 adds the `tile_destroyed` emitter path.
- Do not register as autoload — MapGrid is always instantiated as a BattleScene child in production; tests instantiate directly via `MapGrid.new()`.
- `ADV-1` (return type of `get_movement_range`: `PackedVector2Array` vs `Array[Vector2i]`) is resolved in story-005, not here. `get_tile` returns `TileData` regardless.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: `load_map()` validation error collection (bounds, elevation-terrain mismatch, array size mismatch, collect-all pattern)
- Story 004: `set_occupant`, `clear_occupant`, `apply_tile_damage` mutation API + write-through + `tile_destroyed` signal
- Story 005: `get_movement_range`, `get_path` Dijkstra queries
- Story 006: `has_line_of_sight`, `get_attack_range`, `get_attack_direction`, `get_adjacent_units`, `get_occupied_tiles`

---

## QA Test Cases

*Authored from GDD + ADR directly (lean mode — QL-STORY-READY gate skipped). Developer implements against these.*

- **AC-1**: MapGrid class declaration + load_map as sole entry point
  - Given: fresh `MapGrid.new()` instance
  - When: accessed before `load_map()` called
  - Then: queries (`get_tile`, `get_map_dimensions`) return null / Vector2i.ZERO respectively — no crash; public surface intentionally inert until loaded
  - Edge cases: double `load_map()` call re-builds caches from the new resource (no stale cache carry-over)

- **AC-2**: load_map clones via duplicate_deep
  - Given: MapResource with a known tile at coord (0,0) having `destruction_hp = 100`
  - When: `grid.load_map(res)` then `grid._map.tiles[0].destruction_hp = 999` (runtime mutation of clone)
  - Then: `res.tiles[0].destruction_hp` remains 100 — the clone is independent
  - Edge cases: `duplicate_deep(DUPLICATE_DEEP_ALL_BUT_SCRIPTS)` flag specifically; verify via `grid._map != res` identity check

- **AC-3**: 6 packed caches built with correct length
  - Given: MapResource of dimensions 15×15 (225 tiles)
  - When: `grid.load_map(res)`
  - Then: `_terrain_type_cache.size() == 225`, same for `_elevation_cache`, `_passable_base_cache`, `_occupant_id_cache`, `_occupant_faction_cache`, `_tile_state_cache`
  - Edge cases: 40×30 (1200) size respected; PackedByteArray length assertion for `_passable_base_cache`

- **AC-4**: Cache values match TileData field-by-field at construction
  - Given: 3×3 MapResource with distinct values per tile
  - When: `grid.load_map(res)`
  - Then: for each index `i` in `0..8`, `_terrain_type_cache[i] == _map.tiles[i].terrain_type`, `_elevation_cache[i] == _map.tiles[i].elevation`, `_passable_base_cache[i] == (1 if _map.tiles[i].is_passable_base else 0)`, and same for occupant_id/faction/tile_state
  - Edge cases: bool→byte coercion verified (is_passable_base=true → 1, false → 0)

- **AC-5**: get_tile bounds + return value
  - Given: 15×15 map loaded
  - When: `get_tile(Vector2i(14, 14))` vs `get_tile(Vector2i(15, 0))` vs `get_tile(Vector2i(-1, 0))` vs `get_tile(Vector2i(3, 5))`
  - Then: first returns non-null TileData at index `14*15+14 = 224`; second, third return `null` (out-of-bounds); fourth returns the TileData at `5*15+3 = 78` (AC-CR-2 flat-array formula)
  - Edge cases: `Vector2i(0, 15)` also out-of-bounds (row bound); exactly `map_cols-1, map_rows-1` is in-bounds

- **AC-6**: get_map_dimensions returns (cols, rows)
  - Given: 40×30 map loaded
  - When: `get_map_dimensions()`
  - Then: returns `Vector2i(40, 30)` — `.x == cols`, `.y == rows` (GDD Interactions table order)
  - Edge cases: 15×15 returns `Vector2i(15, 15)`

- **AC-7**: V-2 disk asset unchanged after duplicate_deep mutation (round-trip)
  - Given: MapResource saved to `user://test_map_v2.tres`; MapGrid loaded from disk; runtime mutation of `grid._map.tiles[0].destruction_hp` to a sentinel value
  - When: `ResourceLoader.load("user://test_map_v2.tres", "", ResourceLoader.CACHE_MODE_IGNORE)` re-loaded from disk
  - Then: the freshly-loaded resource's `tiles[0].destruction_hp` equals the original saved value, NOT the sentinel — the disk asset was not mutated by runtime play
  - Edge cases: CACHE_MODE_IGNORE critical here (stale-cache would hide the check); same assertion across multiple tile indices to guard against partial-share leak

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/map_grid_test.gd` — must exist and pass (7 tests covering AC-1..7)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (MapResource + TileData classes) must be Complete
- Unlocks: Story 003 (validator hooks into load_map), Story 004 (mutation API builds on cache structure), Story 005/006 (queries read from caches)

---

## Completion Notes

**Completed**: 2026-04-25
**Actual effort**: ~1h (within 3-4h estimate; benefited from story-001 establishing `MapResource` + `MapTileData` + test precedent patterns)
**Criteria**: 8/8 passing — all automated via `tests/unit/core/map_grid_test.gd`

**Test Evidence**:
- `tests/unit/core/map_grid_test.gd` — NEW, 391 LoC, 11 test functions (AC edge splits)
- Story suite: **11/11 PASSED** (100 ms)
- Full regression: **158/158 PASSED** — 0 errors, 0 failures, 0 orphans

**Deviations** (all ADVISORY; zero runtime impact — logged to TD-032 batch):
- **DEP-1 (ADR-0004 §Decision 4)**: `duplicate_deep(Resource.DEEP_DUPLICATE_ALL)` used instead of ADR-prescribed `DEEP_DUPLICATE_ALL_BUT_SCRIPTS`. The prescribed enum value does not exist in Godot 4.6's `DeepDuplicateMode` (only NONE/INTERNAL/ALL). Documented in-code (map_grid.gd:58–62); matches save_manager.gd TD-024 precedent. TD-032 A-9.
- **DEP-2 (story-002 QA cases)**: AC-7 test file path is `user://map_grid_test_v2_round_trip.tres`; story-authored path was `user://test_map_v2.tres`. Impl choice is better (self-documenting, matches map_resource_test.gd naming). Story-doc audit-trail update deferred. TD-032 A-10.
- **DEP-3 (story-003 scope)**: `load_map(null)` has no null-guard and no test. Validator story-003 is the intended gating point per story §Implementation Notes; cheap defensive null-guard deferred to that story. Not added as errata — normal scope handoff.
- **Code-review SUGGESTIONS (optional test polish)**: 4× `assert_bool(vec == ...)` could be `assert_that(vec).is_equal(...)` for better failure diffs; 3× redundant `as int` casts on `PackedByteArray` access. Both low-priority. TD-032 A-7 + A-8.

**Code Review**: Complete (standalone `/code-review` returned APPROVED WITH SUGGESTIONS; godot-gdscript-specialist: CLEAN with 4 low-priority suggestions; qa-tester: TESTABLE with 2 advisories).

**Gates skipped (lean mode)**: QL-TEST-COVERAGE, LP-CODE-REVIEW — standalone `/code-review` already covered both tracks.

**Map-grid epic progress**: **2/8 Complete**. Story-003 (validator + error collection) now unlocked.
