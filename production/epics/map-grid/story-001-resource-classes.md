# Story 001: MapResource + MapTileData Resource classes

> **Epic**: map-grid
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 2-3 hours (2 Resource classes + 1 unit test; spec verbatim from ADR-0004 §Decision 1)

## Context

**GDD**: `design/gdd/map-grid.md`
**Requirement**: `TR-map-grid-001`, `TR-map-grid-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0004 Map/Grid Data Model
**ADR Decision Summary**: `MapResource` + `TileData` typed Resources with `@export` fields; flat-array indexing `tiles[row*cols+col]`; TileData inline-only (no UID references) as an R-3 hard constraint preventing `duplicate_deep()` leak between maps.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `@export`-typed `Array[TileData]` semantics are 4.6-stable. `Resource.duplicate_deep(DUPLICATE_DEEP_ALL_BUT_SCRIPTS)` is 4.5+ post-cutoff but precedent-verified via ADR-0003 (SaveContext). This story does NOT exercise duplicate_deep — that lands in story-002.

**Control Manifest Rules (Foundation layer)**:
- Required: Tile storage: flat `Array[TileData]` inside `MapResource`; indexing `tiles[coord.y * map_cols + coord.x]` (TR-map-grid-001)
- Required: TileData MUST remain inline inside `MapResource.tres` — no external UID references (TR-map-grid-010 / R-3 hard constraint)
- Required: All gameplay Resources use typed `@export` fields (ADR-0003 convention, mirrored here)
- Forbidden: Shared TileData presets by UID from `MapResource.tres` — `duplicate_deep()` returns shared instance; destruction state leaks between maps
- Guardrail: ~64 B per TileData × 1200 tiles = ~77 KB per map at rest

---

## Acceptance Criteria

*From GDD `design/gdd/map-grid.md` §CR-2 + ADR-0004 §Decision 1, scoped to Resource schema only (no runtime node behaviour):*

- [ ] `src/core/map_resource.gd` declares `class_name MapResource extends Resource` with `@export` fields: `map_id: StringName`, `map_rows: int`, `map_cols: int`, `tiles: Array[TileData]`, `terrain_version: int = 1`
- [ ] `src/core/tile_data.gd` declares `class_name TileData extends Resource` with `@export` fields per CR-2: `coord: Vector2i`, `terrain_type: int`, `elevation: int`, `tile_state: int`, `is_destructible: bool`, `destruction_hp: int`, `occupant_id: int = 0`, `occupant_faction: int = 0`, `is_passable_base: bool = true`
- [ ] MapResource instance round-trips via `ResourceSaver.save(path)` → `ResourceLoader.load(path, "", CACHE_MODE_IGNORE)` with identical field values including the full `tiles` array
- [ ] Round-trip preserves `Vector2i`, enum-mirror `int`, and `bool` field types (no silent `Variant` coercion)
- [ ] Inline-only invariant documented in `map_resource.gd` header doc-comment: "TileData MUST remain inline; never reference an external `.tres` preset by UID (ADR-0004 R-3)."

---

## Implementation Notes

*Derived from ADR-0004 §Decision 1 + §Consequences + R-3:*

- Both classes are `extends Resource`. No `Node` involvement at this story's scope — that's story-002.
- Use `@export` on every serialized field. Non-`@export` fields are silently dropped by `ResourceSaver` (same gotcha ADR-0003 EchoMark surfaced).
- No enums declared inside `TileData` — use `int` mirrors; the authoritative enum source is documented in GDD CR-3 (terrain_type) and ST-1 (tile_state). A future story may extract them to a dedicated enums module; do not do so opportunistically here.
- Default values for `occupant_id = 0`, `occupant_faction = 0`, `is_passable_base = true` match ADR-0004 §Decision 1.
- `terrain_version: int = 1` — bump on schema change; mirrors ADR-0003 `CURRENT_SCHEMA_VERSION` pattern but is stored *on the MapResource*, not globally.
- This story does not author any `.tres` asset — that's story-008. The test uses an in-memory `MapResource` built programmatically.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `MapGrid extends Node` runtime class, `load_map()`, `duplicate_deep()` clone, 6 packed caches, `get_tile()`, `get_map_dimensions()`
- Story 003: Map-load validation errors (bounds, elevation-terrain mismatch, array-size mismatch)
- Story 008: Actual `.tres` map assets authored in Godot inspector

---

## QA Test Cases

*Authored from GDD + ADR directly (lean mode — QL-STORY-READY gate skipped). Developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: MapResource class declaration with all `@export` fields
  - Given: freshly-loaded test script
  - When: `var m := MapResource.new(); m.map_id = &"test"; m.map_rows = 3; m.map_cols = 3; m.tiles = [] as Array[TileData]; m.terrain_version = 1`
  - Then: `assert_that(m.map_id).is_equal(&"test")`, `assert_int(m.map_rows).is_equal(3)`, field types preserved
  - Edge cases: empty `tiles` array is a valid construction (validation lives in story-003, not here)

- **AC-2**: TileData class declaration with all `@export` fields
  - Given: freshly-loaded test script
  - When: `var t := TileData.new(); t.coord = Vector2i(5, 3); t.terrain_type = 0; t.elevation = 1; t.tile_state = 0; t.is_destructible = true; t.destruction_hp = 100; t.occupant_id = 42; t.occupant_faction = 1; t.is_passable_base = true`
  - Then: each field readable with the exact value set; `t.coord.x == 5` and `t.coord.y == 3`
  - Edge cases: default construction `TileData.new()` yields `occupant_id == 0`, `occupant_faction == 0`, `is_passable_base == true`

- **AC-3**: MapResource ResourceSaver/ResourceLoader round-trip (9-tile fixture)
  - Given: MapResource with 3×3 = 9 distinct TileData entries (each with unique coord + terrain_type + elevation + hp values)
  - When: `ResourceSaver.save(m, "user://test_map.tres")` then `ResourceLoader.load("user://test_map.tres", "", ResourceLoader.CACHE_MODE_IGNORE)` as MapResource
  - Then: loaded.map_rows/map_cols/terrain_version match saved; loaded.tiles.size() == 9; each loaded tile's coord, terrain_type, elevation, tile_state, is_destructible, destruction_hp, occupant_id, occupant_faction, is_passable_base match the corresponding saved tile field-by-field
  - Edge cases: temp file cleaned up in after_test; CACHE_MODE_IGNORE consistent with ADR-0003 convention

- **AC-4**: Vector2i / enum-mirror int / bool field-type preservation across save/load
  - Given: MapResource round-trip from AC-3
  - When: `typeof(loaded.tiles[0].coord)` and `typeof(loaded.tiles[0].terrain_type)` and `typeof(loaded.tiles[0].is_destructible)` inspected
  - Then: `TYPE_VECTOR2I`, `TYPE_INT`, `TYPE_BOOL` respectively — no silent conversion to float or Variant
  - Edge cases: this guards against the non-`@export` silent-drop gotcha ADR-0003 surfaced

- **AC-5**: Inline-only invariant documented
  - Given: `src/core/map_resource.gd` opened
  - When: header doc-comment read
  - Then: contains reference to ADR-0004 R-3 and the instruction not to reference TileData by UID
  - Edge cases: lint-detectable for future automation, but manual verification at review time is acceptable

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/map_resource_test.gd` — must exist and pass (5 tests covering AC-1..4; AC-5 is doc-level)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (greenfield Resource schema; ADR-0004 Accepted; GameBus already shipped for later stories)
- Unlocks: Story 002 (MapGrid skeleton + load_map), Story 008 (.tres fixture authoring)

---

## Completion Notes

**Completed**: 2026-04-25
**Actual effort**: ~1h 30min (within 2-3h estimate; 3 sub-agent rounds: draft+approve, parse-error diagnosis, class-name rename)
**Criteria**: 5/5 passing (AC-1..4 auto-tested via map_resource_test.gd 4/4 PASS; AC-5 doc-level verified in /code-review)
**Test Evidence**: Logic story — `tests/unit/core/map_resource_test.gd` (271 LoC, 4 test functions). Full regression: 166/166 PASS, 0 errors, 0 failures, 0 orphans.
**Code Review**: Complete — `/code-review` ran godot-gdscript-specialist (APPROVED) + qa-tester (TESTABLE). Verdict: APPROVED WITH SUGGESTIONS.

**Deviations** (all advisory, logged in TD-032):
- **ADR-0004 §Decision 1 class rename**: `TileData` → `MapTileData` — Godot 4.6 built-in `TileData` class collision (TileSet/TileMapLayer API). Documented in both source file headers with errata-batch pattern.
- **ADR-0004 §Decision 1 field ordering**: `terrain_version` placed first in `MapResource` (ADR lists last). Mirrors `save_context.gd::schema_version` loader-first convention.

**New gotcha discovered — G-12 candidate**: User `class_name` must not collide with Godot built-in classes. Silent class_name registration + misleading "Could not resolve external class member" parse error. Codification pending at TD-032 A-3.

**Files delivered**:
- `src/core/map_resource.gd` (NEW, 44 LoC) — 5 @export fields; R-3 inline-only invariant in header
- `src/core/map_tile_data.gd` (NEW, 51 LoC) — 9 @export fields; class-rename errata documented in header
- `tests/unit/core/map_resource_test.gd` (NEW, 271 LoC) — 4 test functions covering AC-1..4

**TD-032 batched items** (6 total, advisory):
1. ADR-0004 §Decision 1 text update: `TileData` → `MapTileData` (code block + prose + §Key Interfaces signatures + R-5 mention)
2. ADR-0004 §Decision 1 field-ordering errata (`terrain_version` first)
3. `.claude/rules/godot-4x-gotchas.md` G-12 new entry (built-in class_name collision)
4. Story 001 §QA Test Cases AC-2 `TileData.new()` → `MapTileData.new()` text update
5. (Optional test polish) AC-2 default-value assertions for `coord` + `is_destructible`
6. (Optional test polish) AC-4 "intentionally independent from AC-3" intent comment

**Gates skipped** (lean mode): QL-STORY-READY (create-stories), QL-TEST-COVERAGE (story-done), LP-CODE-REVIEW (story-done). Standalone `/code-review` covered both specialist tracks.

**EPIC.md update**: story-001 row → Complete.
