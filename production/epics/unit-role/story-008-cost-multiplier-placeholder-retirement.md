# Story 008: ADR-0008 cost_multiplier placeholder retirement (replace uniform=1 with UnitRole accessor)

> **Epic**: unit-role
> **Status**: Complete (2026-04-28) ✅ — 7 new tests + 481 regression = 488/488 full-suite green; first cross-epic Integration story in the project
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-20
> **Estimate**: 2-3 hours (S) — actual ~45min orchestrator + 1 specialist round (story-blocking architectural decision surfaced + resolved + executed in one specialist pass)
> **Implementation commit**: `0a0c5f0` (2026-04-28)

## Post-completion notes

### Story-blocking architectural discovery (8th implementation-time discovery this session)
Pre-implementation cross-check surfaced a CROSS-EPIC drift: TerrainEffect's terrain_type ordering (PLAINS=0..ROAD=7, 8 entries) differs from UnitRole's terrain_cost_table indexing (ROAD=0..BRIDGE=5, 6 entries — per ADR-0009 §5). Without translation, Map/Grid calling `cost_multiplier(CAVALRY, MOUNTAIN=3)` would silently return UnitRole's FOREST cost (2.0→int 2), NOT MOUNTAIN cost (3.0→int 3). **Silent data corruption averted.**

Resolution (Option 1 — Translate at TerrainEffect boundary, user-approved): static `_UNIT_ROLE_TERRAIN_IDX` const Dictionary in TerrainEffect maps 6 of 8 TerrainEffect terrain_types → UnitRole indices. RIVER + FORTRESS_WALL intentionally absent (impassable per CR-4a; Map/Grid short-circuits via `is_passable_base` BEFORE this call); defensive `push_error` + return 1 fallback if reached.

This is the FIRST cross-epic drift this session (5 prior were intra-epic GDD/ADR/data drift). Recommend codifying as process rule for /architecture-review: "must cross-reference all enum/const integer values referenced across ADR boundaries against existing source code constants, not just other ADR text."

### Latent gap caught in existing terrain_cost_migration_test.gd
The existing test had `range(5)` instead of `range(6)` in AC-6 — only looped 5 of the 6 UnitClass values. Fixed in the in-place update. (No tracking burden — silent under-coverage now closed.)

### Files modified/created
- `src/core/terrain_effect.gd`: 3 targeted edits (translation table const + cost_multiplier body + doc-comment); +69 LoC region
- `tests/integration/core/terrain_cost_migration_test.gd`: in-place updates (AC-1 36-cell rewrite + AC-3 split for failure-isolation + AC-4 expected-value update + AC-6 range fix + before_test UnitRole reset); +178/-186 LoC
- `tests/integration/foundation/unit_role_terrain_cost_integration_test.gd` (NEW, ~310 LoC, 6 test functions): cross-system integration coverage including impassable-terrain push_error fallback verification

### Code quality notes
- TerrainEffect's `cost_multiplier` doc-comment now cites ADR-0009 §5 ratification + the translation table rationale + CR-4a impassability contract
- Removed `@warning_ignore("unused_parameter")` decoration (args become live)
- Removed `TODO(ADR-0009)` comment (obligation satisfied)
- All 36 mapped translation cells verified in parametric test (Array[Dictionary] per G-16)
- R-1 mitigation (PackedFloat32Array per-call copy) preserved at the integration boundary — agent extended story-004's R-1 test pattern

### Calibration
- TerrainEffect modification: ~70 LoC (consistent with single-method scope)
- Integration test: 310 LoC vs orchestrator's 270-360 estimate (within range; ~52 LoC/AC for cross-epic Integration with parametric coverage)
- terrain_cost_migration_test.gd updates: net-flat (~zero LoC delta; rewrites + comment updates roughly balance)

## Context

**GDD**: `design/gdd/unit-role.md` + `design/gdd/terrain-effect.md` (cross-system integration)
**Requirement**: `TR-unit-role-006` (ratifies ADR-0008 §Context item 5 deferral) + `TR-terrain-effect-018` (cost_multiplier matrix structure consumer)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 — Unit Role System (§5 Cost Matrix Unit-Class Dimension Ratification) + ADR-0008 — Terrain Effect (§Context item 5 + Decision 5 + §Migration Plan)
**ADR Decision Summary**: ADR-0008 shipped `src/core/terrain_effect.gd::cost_multiplier(unit_type: int, terrain_type: int) -> int` with placeholder `return 1` (TR-terrain-effect-018) explicitly pending ADR-0009 Unit Role. ADR-0009 §5 ratifies the cost-matrix unit-class dimension via `get_class_cost_table(unit_class) -> PackedFloat32Array` (Story 004). This story retires ADR-0008's placeholder by replacing it with either (a) a thin pass-through to `UnitRole.get_class_cost_table(unit_class)[terrain_type]` indexed read OR (b) direct Map/Grid Dijkstra read of UnitRole's accessor. Choice deferred to story implementation per design freedom; both options preserve ADR-0008's architectural seam.

**Engine**: Godot 4.6 | **Risk**: LOW (TerrainEffect + UnitRole are both `class_name X extends RefCounted` with all-static methods; cross-class call has zero engine surprise; existing `terrain_cost_migration_test.gd` provides regression baseline from terrain-effect epic story-005/006)
**Engine Notes**: Verify `floori(base_terrain_cost × class_multiplier)` is applied at the **Map/Grid Dijkstra layer** per CR-4b — NOT in `cost_multiplier()` body. ADR-0008's `cost_multiplier(unit_type, terrain_type) -> int` returns the raw multiplier (was hardcoded to `1` placeholder; now returns `int(UnitRole.get_class_cost_table(unit_class)[terrain_type])` OR a refactored `float` return type if Map/Grid is updated to call UnitRole directly).

**Control Manifest Rules (Foundation layer + direct ADR cites)**:
- Required (direct, ADR-0008 §Migration Plan): TerrainEffect's `cost_multiplier` placeholder retirement requires either (a) thin pass-through preserving the int return type signature OR (b) refactor to UnitRole-direct call from Map/Grid Dijkstra
- Required (direct, ADR-0009 §5 + Story 004 R-1 mitigation): If option (a) is chosen, the pass-through MUST NOT cache the returned PackedFloat32Array — call UnitRole.get_class_cost_table(unit_class) on every invocation OR cache the int value per (unit_class, terrain_type) pair (NOT the array)
- Required (direct, ADR-0008 + ADR-0009): existing `tests/unit/core/terrain_cost_migration_test.gd` regression baseline must continue to pass post-retirement (verifies the API-stable transition)
- Required (manifest, ADR-0004 line 109): Map/Grid Dijkstra hot loop MUST avoid per-cell virtual dispatch — `UnitRole.get_class_cost_table(unit_class)` is called ONCE per `get_movement_range` invocation, then index-reads in inner loop (per Story 004 R-1 mitigation comment + ADR-0009 §5 hot-path performance design)
- Forbidden (direct, ADR-0009 §5 R-1 + forbidden_pattern): caching the returned `PackedFloat32Array` in TerrainEffect or Map/Grid in a way that creates shared backing memory across calls
- Forbidden (direct, ADR-0008): re-introducing the `return 1` placeholder OR adding new placeholder logic in `cost_multiplier` body

---

## Acceptance Criteria

*From ADR-0008 §Migration Plan ratification + ADR-0009 §5 + GDD CR-4 + EC-3, EC-4, EC-5:*

- [ ] `src/core/terrain_effect.gd::cost_multiplier(unit_type: int, terrain_type: int) -> int` placeholder `return 1` is **retired**. Body either calls `UnitRole.get_class_cost_table(unit_class_from_unit_type)[terrain_type]` and returns `int(...)` OR is documented as deprecated with consumers migrated to direct UnitRole call
- [ ] If option (a) thin pass-through chosen: `cost_multiplier(CAVALRY=0, MOUNTAIN=4)` returns 3 (matches `floori(3.0 × 1) = 3` if base multiplier returned, OR matches per-call cost computation if applied here — choice documented inline)
- [ ] If option (b) Map/Grid direct UnitRole call chosen: `terrain_effect.gd::cost_multiplier` is deprecated with a doc-comment + `push_warning` on call; Map/Grid `get_movement_range` Dijkstra inner loop reads `UnitRole.get_class_cost_table(unit_class)[terrain_type]` directly
- [ ] Existing `tests/unit/core/terrain_cost_migration_test.gd` regression baseline passes post-retirement (per terrain-effect epic story-005/006 close-out)
- [ ] New integration test: `tests/integration/foundation/unit_role_terrain_cost_integration_test.gd` verifies the 6×6 cost matrix is reachable through both UnitRole + TerrainEffect (whichever option chosen) — sample cells: CAVALRY MOUNTAIN, INFANTRY MOUNTAIN, SCOUT FOREST, ARCHER MOUNTAIN
- [ ] Map/Grid Dijkstra `get_movement_range` test (existing per map-grid epic) verifies per-class movement variance:
  - CAVALRY with budget=50 cannot enter MOUNTAIN (cost=60) per AC-13/EC-3
  - SCOUT in FOREST has effective cost=10 (matches PLAINS) per AC-14/EC-5
  - INFANTRY in any non-MOUNTAIN terrain has cost ≤ 15 (low penalty) per CR-3 tactical identity
- [ ] R-1 mitigation preserved: any caching in TerrainEffect or Map/Grid does NOT share backing memory of UnitRole's PackedFloat32Array (verified by extending Story 004's mutation-isolation test to the integration boundary)

---

## Implementation Notes

*From ADR-0008 §Decision 5 + §Migration Plan + ADR-0009 §5 + GDD CR-4:*

1. **Decision: option (a) or option (b)**:
   - **Option (a) thin pass-through**: minimal disruption to existing TerrainEffect + Map/Grid tests; preserves the `cost_multiplier(unit_type, terrain_type) -> int` API; UnitRole becomes TerrainEffect's data source via the pass-through. Trade-off: extra indirection per call (negligible since UnitRole.get_class_cost_table is <0.01ms per Story 004 perf budget); requires per-call int(float) cast.
   - **Option (b) Map/Grid direct UnitRole call**: removes the indirection layer; TerrainEffect's `cost_multiplier` becomes deprecated. Trade-off: existing TerrainEffect tests need updates; Map/Grid Dijkstra inner loop refactored.
   - Recommendation: **Option (a)** for minimum disruption + clearer ADR-0008 ratification semantics. Story implementation can choose, but document the choice in implementation note + EPIC.md story Status field.
2. Option (a) implementation shape:
   ```gdscript
   # src/core/terrain_effect.gd  (modified)
   static func cost_multiplier(unit_type: int, terrain_type: int) -> int:
       # ADR-0008 placeholder retired by ADR-0009 ratification (Story 008).
       # unit_type maps 1:1 to UnitRole.UnitClass enum int (CAVALRY=0..SCOUT=5).
       var unit_class: UnitRole.UnitClass = unit_type as UnitRole.UnitClass
       var cost_row := UnitRole.get_class_cost_table(unit_class)
       return int(cost_row[terrain_type])  # raw multiplier int (CR-4b floor applied at Map/Grid)
   ```
   Note: if the multiplier is fractional (e.g., 0.7 SCOUT FOREST, 1.5 CAVALRY HILLS), `int()` truncates — this matches the `return 1` placeholder semantics (always int return). Map/Grid applies `floori(base × multiplier)` per CR-4b. **Verify** the existing terrain_cost_migration_test.gd assertions are aware of int vs float — may need test updates.
3. Option (b) implementation shape (alternative; documented for completeness):
   ```gdscript
   # src/core/map_grid.gd Dijkstra inner loop (refactored)
   var cost_table := UnitRole.get_class_cost_table(unit_class)  # one fetch per get_movement_range
   for each cell:
       var multiplier := cost_table[terrain_type]  # float
       var cell_cost := floori(base_cost * multiplier)
   # terrain_effect.gd::cost_multiplier marked deprecated:
   static func cost_multiplier(unit_type: int, terrain_type: int) -> int:
       push_warning("ADR-0008 cost_multiplier deprecated; consumers should call UnitRole.get_class_cost_table directly")
       var unit_class: UnitRole.UnitClass = unit_type as UnitRole.UnitClass
       return int(UnitRole.get_class_cost_table(unit_class)[terrain_type])
   ```
4. The integration test validates the cross-system contract — sample cells (avoid testing all 36 here, that's Story 004's job):
   - CAVALRY MOUNTAIN: returns 3 (cost matrix cell)
   - INFANTRY MOUNTAIN: returns 1 (1.5 truncated to int OR float 1.5 if int(1.5) is the call site)
   - Watch out: int truncation `int(1.5) = 1` matches `floori(1.5) = 1` for positive values; verify behavior aligns with terrain_cost_migration_test.gd expectations.
5. **Do not** introduce new logic unrelated to the placeholder retirement — this story is bounded to the ADR-0008 ratification.
6. **Do not** modify Story 004's `get_class_cost_table` body — this story consumes it, not authors it.
7. **Do not** introduce a new GameBus signal for cost matrix changes — TerrainEffect + UnitRole are both on the non-emitter list per ADR-0001 line 375.

---

## Out of Scope

*Handled by neighbouring stories or earlier epics:*

- Story 004: `get_class_cost_table` authoring + R-1 caller-mutation isolation regression test (this story consumes; Story 004 implements)
- Map/Grid Dijkstra `get_movement_range` algorithm itself (already implemented per map-grid epic Complete)
- Floor application `floori(base × multiplier)` per CR-4b (Map/Grid layer; existing logic; this story does not change it)
- Cavalry MOUNTAIN budget enforcement EC-3/EC-4 path-order logic (Map/Grid `remaining_budget >= tile_cost` check; existing)
- Scout FOREST `floori(15 × 0.7) = 10` per EC-5 (Map/Grid floor application; existing)
- RIVER/FORTRESS_WALL `is_passable_base = false` impassability checks (Map/Grid; existing)
- TerrainEffect modifier query methods (`get_terrain_modifiers`, `get_combat_modifiers`, `get_terrain_score`) — out of scope; only `cost_multiplier` is touched

---

## QA Test Cases

*Integration story — automated integration test required.*

- **AC-1 (TerrainEffect cost_multiplier placeholder retired)**:
  - Given: `src/core/terrain_effect.gd` has the new `cost_multiplier` body (option (a) or (b))
  - When: a test calls `TerrainEffect.cost_multiplier(unit_type=0, terrain_type=4)` (CAVALRY MOUNTAIN)
  - Then: returns 3 (truncated from 3.0 via `int()` cast); NOT 1 (the old placeholder)
  - Edge cases: `cost_multiplier(unit_type=5, terrain_type=3)` (SCOUT FOREST) returns 0 (truncated from 0.7) OR 1 if implementation rounds — verify aligns with terrain_cost_migration_test.gd expectations; this is the load-bearing edge case for option (a) int truncation behavior

- **AC-2 (Existing terrain_cost_migration_test regression baseline passes)**:
  - Given: `tests/unit/core/terrain_cost_migration_test.gd` (from terrain-effect epic story-005/006)
  - When: full test suite runs post-retirement
  - Then: all assertions pass; no regression on the migration baseline
  - Edge cases: any pre-existing test that asserted `return 1` literal will need an update — that's expected as part of this story's scope

- **AC-3 (Cross-system 6-class cost matrix sample cells)**:
  - Given: new integration test `tests/integration/foundation/unit_role_terrain_cost_integration_test.gd`
  - When: per-cell verification through TerrainEffect (or Map/Grid direct):
    - `CAVALRY × MOUNTAIN` → multiplier 3.0 (or int 3)
    - `INFANTRY × MOUNTAIN` → multiplier 1.5 (or int 1 if truncated)
    - `SCOUT × FOREST` → multiplier 0.7 (or int 0)
    - `ARCHER × MOUNTAIN` → multiplier 2.0 (or int 2)
  - Then: each cell matches GDD CR-4 table value (or its int-truncated form per option (a))
  - Edge cases: STRATEGIST + COMMANDER FOREST entries (CR-4 table values 1.5 + 1.5 respectively) — verify no off-by-one in unit_class mapping

- **AC-4 (Map/Grid Dijkstra per-class movement variance — END-TO-END)**:
  - Given: existing Map/Grid `get_movement_range` test infrastructure (from map-grid epic Complete) + new cost matrix integration
  - When: `MapGrid.get_movement_range(start_coord, unit_class=CAVALRY, move_budget=50)` is called on a map with MOUNTAIN tiles adjacent to the start coord
  - Then: returned reachable set does NOT include any MOUNTAIN tile (cost 60 > budget 50 per EC-3); CAVALRY cannot enter
  - Edge cases: `move_budget=60` with MOUNTAIN as the FIRST tile in path → CAN enter exactly one (per EC-4 path-order dependency); `SCOUT × FOREST × budget=10` → can enter (cost 10 = budget); `INFANTRY × MOUNTAIN × budget=30` → can enter (cost 30 = budget)

- **AC-5 (R-1 mitigation preserved at integration boundary)**:
  - Given: TerrainEffect or Map/Grid consumes `UnitRole.get_class_cost_table` (per option (a) or (b))
  - When: a test fetches the cost-matrix-derived value from TerrainEffect twice with mutation in between (extending Story 004's R-1 test pattern)
  - Then: no cross-call corruption; UnitRole's `_coefficients` cache is not corrupted
  - Edge cases: this verifies the R-1 mitigation extends to the consumer boundary, not just UnitRole's internal isolation

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/foundation/unit_role_terrain_cost_integration_test.gd` — must exist and pass (5 ACs above; ~150-200 LoC test file with cross-class cell coverage + Map/Grid Dijkstra end-to-end + R-1 boundary preservation)
- Existing `tests/unit/core/terrain_cost_migration_test.gd` regression suite must continue to pass
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 (consumes `get_class_cost_table` accessor + R-1 mitigation)
- Unlocks: Map/Grid `get_movement_range` end-to-end with realistic cost matrix (the placeholder uniform=1 was preventing realistic per-class movement variance); ratifies ADR-0008's §Context item 5 deferral
