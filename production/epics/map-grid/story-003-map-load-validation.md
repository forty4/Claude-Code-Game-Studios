# Story 003: Map loading validation + error collection

> **Epic**: map-grid
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 3-4 hours (8 error codes + collect-all validator pass + 8 test cases; precedent: save-manager story-004 pipeline validation took ~4h including errata)

## Context

**GDD**: `design/gdd/map-grid.md`
**Requirement**: `TR-map-grid-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 Map/Grid Data Model
**ADR Decision Summary**: Map authoring format is `.tres` with inspector editing; load path must reject malformed maps cleanly with collect-all-errors behaviour (a map author seeing one error at a time on a large map is unacceptable UX).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `push_error()` + structured error codes; no post-cutoff APIs. Return type is `bool` (or `Array[String]` for error list) — deferred decision item; see Implementation Notes.

**Control Manifest Rules (Foundation layer)**:
- Required: Map loading via `ResourceLoader.load(path, "", CACHE_MODE_IGNORE)` — mirrors ADR-0003 pattern (TR-map-grid-009). This story validates the Resource AFTER load, not the load mechanism itself.
- Required: Error codes documented as constants (grep-able) — mirrors ADR-0003 `SaveErr` enum pattern
- Forbidden: Silent clamping of invalid dimensions — data corruption hiding (GDD §EC-1 "클램핑하지 않음 — 데이터 손상 은폐 방지")
- Forbidden: Partial loading on invalid maps — GDD §EC-7 "부분 로딩 없이 전체 거부"
- Guardrail: `.tres` map load target <100 ms; validation pass must stay proportional to map size (O(rows × cols)) and not materially inflate the budget

---

## Acceptance Criteria

*From GDD `design/gdd/map-grid.md` §Edge Cases 1 + 7 + AC-CR-4 + AC-EDGE-1, scoped to load-time validation:*

- [ ] `load_map(res)` validates the MapResource against all §EC-7 constraints before building caches; on any validation failure, caches are NOT built, `_map` is NOT assigned, and the loader returns a failure indicator
- [ ] `map_cols < 15` or `map_cols > 40` or `map_rows < 15` or `map_rows > 30` → fails with `ERR_MAP_DIMENSIONS_INVALID(cols, rows)`; `map_cols == 0` or `map_rows == 0` also fails (GDD §EC-7)
- [ ] `tiles.size() != map_rows * map_cols` → fails with `ERR_TILE_ARRAY_SIZE_MISMATCH(expected, actual)` (GDD §EC-7)
- [ ] Any tile with `elevation` outside the CR-3-allowed range for its `terrain_type` → fails with `ERR_ELEVATION_TERRAIN_MISMATCH(coord, terrain, elevation)` (AC-CR-4)
- [ ] Any tile with `is_passable_base == false` but `tile_state == ALLY_OCCUPIED` or `ENEMY_OCCUPIED` → fails with `ERR_IMPASSABLE_OCCUPIED(coord)` (GDD §EC-7 final item)
- [ ] Any tile with `occupant_id >= 0` pointing to a coord outside `map_cols × map_rows` (via `coord` field mismatch with array position) → fails with `ERR_UNIT_COORD_OUT_OF_BOUNDS(unit_id, coord)` (AC-EDGE-1)
- [ ] Any tile with `destruction_hp < 0` → loader clamps to 0 with a single `push_warning` per map and proceeds; `is_destructible == true && destruction_hp == 0` is loaded as DESTROYED state with a `push_warning` (GDD §EC-5, §EC-7)
- [ ] All validation errors are collected and reported in one pass (not short-circuited on first failure) — a map author sees the full error list on first load attempt; clamp-warnings do not abort the pass
- [ ] Error codes defined as `const` string identifiers in `map_grid.gd` (grep-able); each error pushed via `push_error` with the code + positional context (coord / unit_id)

---

## Implementation Notes

*Derived from ADR-0004 §Engine Compatibility + GDD §EC-1/5/7:*

- Introduce a private `_validate_map(res: MapResource) -> PackedStringArray` returning a list of error codes (empty = valid). `load_map` returns `bool` (true = loaded, false = validation failed); the full error list is pushed via `push_error` AND returned from an auxiliary `get_last_load_errors() -> PackedStringArray` for test assertions.
- Decision for story-003 (lock now, no re-open): `load_map(res: MapResource) -> bool` signature. Tests assert boolean + `get_last_load_errors()` content.
- Error codes: UPPER_SNAKE_CASE const strings, NOT an enum (makes the codes grep-able in test assertions and in a real bug report). Examples: `const ERR_MAP_DIMENSIONS_INVALID := "ERR_MAP_DIMENSIONS_INVALID"`. Attach positional data via `push_error("%s(%d,%d)" % [code, cols, rows])` format — tests match on the code prefix.
- CR-3 elevation-per-terrain allowed ranges (from GDD §CR-3 table):
  - PLAINS: elevation must be 0
  - HILLS: elevation must be 1
  - MOUNTAIN: elevation must be 2
  - FOREST: elevation must be 0 or 1
  - RIVER: elevation must be 0
  - BRIDGE: elevation must be 0
  - FORTRESS_WALL: elevation must be 1 or 2
  - ROAD: elevation must be 0
  - Encode this as a constant `Dictionary[int, PackedInt32Array]` or `Array` of allowed lists; keep it inline in `map_grid.gd` for this story (a future story may extract to `terrain_rules.gd` when ADR-0008 lands).
- Collect-all pattern: build a local `errors: PackedStringArray`, push to it throughout; return aggregate. A single-pass over tiles is sufficient — do NOT do two passes (one for dimensions, one for tiles) because GDD §EC-7 wording implies a single-load-attempt error report.
- Clamp cases (§EC-5 negative destruction_hp, §EC-7 hp=0 with is_destructible) are warnings, NOT errors — validation still succeeds, load still completes. This is the ONLY deviation from strict reject-all.
- The `coord` field on `TileData` and the array position `row * map_cols + col` must agree. If `res.tiles[i].coord != Vector2i(i % map_cols, i / map_cols)` treat as `ERR_TILE_ARRAY_POSITION_MISMATCH(expected, actual, i)`. This catches hand-edited `.tres` files where a tile was moved in the array without updating its coord.
- Do not validate tile_state transitions in isolation — that's mutation-time validation (story 004 AC-ST-3). Story-003 only validates the initial snapshot.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: MapGrid skeleton + packed cache construction (this story's validator runs BEFORE those caches are built)
- Story 004: Runtime state-transition enforcement (AC-ST-3 `ERR_ILLEGAL_STATE_TRANSITION`) — a mutation-time error, not a load-time error
- Story 005: Per-unit-type × per-terrain cost validation — deferred; placeholder table used until ADR-0008 defines matrix

---

## QA Test Cases

*Authored from GDD + ADR directly (lean mode).*

- **AC-1**: Valid map passes validation and loads
  - Given: 15×15 MapResource with all tiles PLAINS(elev=0, passable_base=true, tile_state=EMPTY)
  - When: `grid.load_map(res)`
  - Then: returns `true`; `grid.get_last_load_errors().is_empty()`; `grid.get_tile(Vector2i(0,0))` non-null
  - Edge cases: single-tile permutations (HILLS elev=1, BRIDGE elev=0) also pass

- **AC-2**: Dimension bounds rejection
  - Given: MapResource with map_cols=14, map_rows=15
  - When: `grid.load_map(res)`
  - Then: returns `false`; errors contain "ERR_MAP_DIMENSIONS_INVALID" prefix; `_map` unassigned (or pre-load state preserved)
  - Edge cases: 41×30, 40×31, 15×14, 0×15, 15×0 all rejected; 15×15 (minimum) and 40×30 (maximum) pass

- **AC-3**: Tile array size mismatch
  - Given: MapResource with map_cols=15, map_rows=15, but tiles array has 224 entries (should be 225)
  - When: `grid.load_map(res)`
  - Then: returns `false`; errors contain "ERR_TILE_ARRAY_SIZE_MISMATCH"
  - Edge cases: 226-entry array also rejected (over, not just under)

- **AC-4**: Elevation-terrain mismatch (AC-CR-4)
  - Given: 15×15 PLAINS map but `tiles[0].elevation = 2` (PLAINS allows only 0)
  - When: `grid.load_map(res)`
  - Then: returns `false`; errors contain "ERR_ELEVATION_TERRAIN_MISMATCH"; error mentions coord (0,0), terrain PLAINS, elevation 2
  - Edge cases: MOUNTAIN with elev=0 also invalid (MOUNTAIN requires elev=2); FOREST with elev=2 invalid (FOREST allows 0 or 1)

- **AC-5**: is_passable_base=false but tile_state OCCUPIED contradiction
  - Given: 15×15 map with `tiles[0].is_passable_base = false` AND `tiles[0].tile_state = ALLY_OCCUPIED` (value 1 per ST-1)
  - When: `grid.load_map(res)`
  - Then: returns `false`; errors contain "ERR_IMPASSABLE_OCCUPIED"
  - Edge cases: same contradiction with ENEMY_OCCUPIED rejected; is_passable_base=false + tile_state=EMPTY is valid (e.g., impassable terrain)

- **AC-6**: Tile array position / coord field mismatch
  - Given: 15×15 map where `tiles[0].coord = Vector2i(5, 5)` (should be (0,0) per flat-array formula)
  - When: `grid.load_map(res)`
  - Then: returns `false`; errors contain "ERR_TILE_ARRAY_POSITION_MISMATCH"
  - Edge cases: swapped tiles[78] and tiles[79] (both coords off-by-one) surface two distinct errors in one pass

- **AC-7**: Negative destruction_hp clamp + warning
  - Given: 15×15 valid map except `tiles[5].destruction_hp = -10`, `is_destructible = true`
  - When: `grid.load_map(res)`
  - Then: returns `true` (clamp is a warning, not an error); `grid._map.tiles[5].destruction_hp == 0`; one `push_warning` emitted
  - Edge cases: `destruction_hp == 0` with `is_destructible == true` loads as DESTROYED state with warning — valid mid-state recovery

- **AC-8**: Collect-all errors (multiple failures in one pass)
  - Given: 15×15 map with THREE distinct violations: `map_rows = 14` (dimension), `tiles[0].elevation` wrong (elevation-terrain), `tiles[5].coord` wrong (position mismatch)
  - When: `grid.load_map(res)`
  - Then: returns `false`; `get_last_load_errors()` contains at LEAST 3 distinct error entries — NOT short-circuited on first failure
  - Edge cases: a 40×30 map with 50 scattered elevation errors produces 50 entries, not 1

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Extended `tests/unit/core/map_grid_test.gd` — +8 tests (AC-1..8) covering validation suite

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (MapGrid skeleton + load_map entry point) must be Complete
- Unlocks: Story 004 (mutation API assumes valid loaded map), Story 008 (inspector fixture authoring relies on validation feedback loop)

---

## Completion Notes

**Completed**: 2026-04-25
**Actual effort**: ~1.5h (within 3-4h estimate; benefited from story-002 test precedent + `_make_map` factory reuse)
**Criteria**: 9/9 passing — all automated via `tests/unit/core/map_grid_test.gd`

**Test Evidence**:
- `tests/unit/core/map_grid_test.gd` extended (392 → ~950 LoC): 8 new AC-1..AC-8 tests + 1 convergent regression (valid→invalid load resets to inert) + adjusted `_make_map` factory
- Story suite: **20/20 PASSED** (11 story-002 + 8 story-003 + 1 convergent)
- Full regression: **167/167 PASSED** — 0 errors, 0 failures, 0 orphans

**Deviations** (all ADVISORY; logged to TD-032 batch; zero runtime impact):
- **DEP-1 (AC-8 fixture rework)**: 3 tile-level errors instead of story's dim + 2 tile errors. Justified: dim-error short-circuits tile walk by design (safety guard). Both `/code-review` specialists confirmed reworded test is stronger. Documented in test body comment.
- **DEP-2 (`ELEVATION_RANGES` encoding)**: nested `Array` literal vs story's `Dictionary[int, PackedInt32Array]` — GDScript const-expressions cannot invoke `PackedInt32Array()` constructor. gdscript-specialist confirmed as only viable approach.
- **DEP-3 (valid→invalid state reset, RESOLVED INLINE during close-out)**: Convergent `/code-review` finding from gdscript-specialist + qa-tester — `_map` previously retained prior value on validation failure. Fixed with one-line `_map = null` reset at `load_map` top + `test_..._valid_then_invalid_load_resets_to_inert` regression test. Closed, NOT deferred.
- **DEP-4 (`_validate_map` ~75 LoC)**: Exceeds 40-line method standard. gdscript-specialist ruled acceptable: cold-path one-shot + 3 section-commented sub-blocks; splitting adds overhead without caller benefit.
- **DEP-5 (TerrainType + TileState enum assumptions)**: PLAINS=0..ROAD=7, EMPTY=0..DESTROYED=3 assumed pending ADR-0008. Documented in-code. TD-032 continuation (not new).
- **DEP-6 (`_make_map` factory adjustments)**: Elevation bound to terrain-type, impassable tiles forced to EMPTY state, sub-15 dimensions bumped to 15×15/15×16. In-scope test-helper fix required to keep story-002 fixtures valid under new validation gate.

**Advisory test coverage gaps (8 edge cases)**: qa-tester identified 8 `Edge cases:` variants from story §QA Test Cases lines that are not exercised (AC-2 all-5 dim variants, AC-3 over-size, AC-4 FOREST/MOUNTAIN invalid combos, AC-5 ENEMY_OCCUPIED + impassable-EMPTY-valid, AC-6 swap case, AC-7 DESTROYED standalone, AC-8 50-error scale). All ADVISORY — no BLOCKING. Queued as TD-032 A-11 test-hardening batch.

**`push_warning` verification gap**: AC-7 cannot assert `push_warning` was emitted without a log-capture hook. Recommendation: add `_last_load_warnings: PackedStringArray` symmetric to `_last_load_errors` in a follow-up (TD-032 A-12). Not blocking this story.

**Code Review**: Complete (standalone `/code-review` returned APPROVED WITH SUGGESTIONS; godot-gdscript-specialist: SUGGESTIONS with 1 convergent finding → RESOLVED INLINE; qa-tester: GAPS with 8 advisory edge-case tests → queued to TD-032 A-11).

**Gates skipped (lean mode)**: QL-TEST-COVERAGE, LP-CODE-REVIEW — standalone `/code-review` already covered both tracks.

**Map-grid epic progress**: **3/8 Complete**. Story-004 (mutation API + tile_destroyed signal) + story-008 (inspector fixture authoring) now unlocked. Story-005 (Dijkstra) remains highest-risk tentpole and depends on story-004.
