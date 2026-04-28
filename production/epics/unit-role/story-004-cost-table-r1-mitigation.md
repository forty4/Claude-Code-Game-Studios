# Story 004: get_class_cost_table + R-1 caller-mutation isolation regression test

> **Epic**: unit-role
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 2-3 hours (S)

## Context

**GDD**: `design/gdd/unit-role.md`
**Requirement**: `TR-unit-role-006`, `TR-unit-role-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 — Unit Role System (§5 Cost Matrix Unit-Class Dimension Ratification + §R-1 mitigation + §Validation Criteria §6) + ADR-0008 — Terrain Effect (§Context item 5 deferral being ratified by this story)
**ADR Decision Summary**: `get_class_cost_table(unit_class) -> PackedFloat32Array` returns the 6-entry row from the 6×6 cost matrix per GDD CR-4. Map/Grid Dijkstra hot loop calls one fetch per `get_movement_range` invocation, then index-reads in the inner loop (no Variant boxing, no per-cell static-method dispatch). R-1 mitigation: PackedFloat32Array per-call copy COW semantics; UnitRole MUST NOT cache and return a shared backing array — codified as forbidden_pattern `unit_role_returned_array_mutation` + mandatory caller-mutation regression test.

**Engine**: Godot 4.6 | **Risk**: LOW (PackedFloat32Array COW semantics stable in Godot 4.x; per godot-specialist `/architecture-review` 2026-04-28 Item 5 confirmed; static-method PackedArray return creates per-call copy at boundary naturally)
**Engine Notes**: Godot 4.x PackedFloat32Array is COW (copy-on-write) — returning it from a static method yields a logical copy at the call boundary, but the actual memory copy is deferred until mutation. If a future "optimization" PR caches a `static var cached_row: PackedFloat32Array` and returns it, two callers share backing memory until one mutates — **silent corruption**. The R-1 regression test catches this exact scenario.

**Control Manifest Rules (Foundation layer + direct ADR cites)**:
- Required (direct, ADR-0009 §5): `get_class_cost_table(unit_class: UnitRole.UnitClass) -> PackedFloat32Array` returns 6-entry packed array indexed by terrain_type enum (0..5: ROAD, PLAINS, HILLS, FOREST, MOUNTAIN, BRIDGE)
- Required (direct, ADR-0009 §5 R-1 mitigation + Validation Criteria §6): R-1 caller-mutation isolation regression test mandatory; static-lint enforcement via `forbidden_pattern: unit_role_returned_array_mutation` registered in `docs/registry/architecture.yaml`
- Required (direct, ADR-0009 §5): Source-comment in `unit_role.gd` above the method declaration: `# RETURNS PER-CALL COPY — DO NOT cache and return shared array.`
- Forbidden (direct, ADR-0009 §5 R-1 + forbidden_pattern): cache + return shared `PackedFloat32Array` — `static var cached_row: PackedFloat32Array` field that is returned by reference. Any future attempt at this caching optimization MUST be rejected at code review per the registered forbidden_pattern
- Forbidden (manifest, ADR-0004 line 109): `MapGrid.get_unit_at(coord)` style API does not exist — Map/Grid consumers self-cache. Same principle: cost-table consumers MUST NOT mutate the returned array (would break the next consumer's read)
- Guardrail (direct, ADR-0009 §Performance): `get_class_cost_table` <0.01ms per call (called once per Map/Grid `get_movement_range` invocation); ~5-10 calls per turn typical

---

## Acceptance Criteria

*From GDD `design/gdd/unit-role.md` AC-12..AC-15 + EC-3, EC-4, EC-5:*

- [ ] **AC-12 (Cost matrix accuracy)**: `get_class_cost_table(unit_class) -> PackedFloat32Array` returns the 6-entry row matching the CR-4 table exactly. Verified for all 6 classes × 6 terrain types = 36 cells
- [ ] **AC-13 (Cavalry MOUNTAIN budget)**: `get_class_cost_table(CAVALRY)[MOUNTAIN=4] == 3.0`; combined with base MOUNTAIN cost 20 → `floor(20 × 3.0) = 60`. Cavalry move_budget=50 cannot enter (60 > 50). Cavalry move_budget=60 can enter ONE MOUNTAIN tile only if zero budget spent prior (path-order dependent per EC-3, EC-4 — Map/Grid Dijkstra owns the budget enforcement)
- [ ] **AC-14 (Scout FOREST = PLAINS)**: `get_class_cost_table(SCOUT)[FOREST=3] == 0.7`; combined with base FOREST cost 15 → `floori(15 × 0.7) = floori(10.5) = 10`, equal to base PLAINS cost. Scout traverses forest with no penalty per EC-5. **Floor operation is owned by Map/Grid layer** (NOT this story) — UnitRole returns the multiplier 0.7
- [ ] **AC-15 (RIVER / FORTRESS_WALL impassable)**: NOT in this 6-entry table per CR-4a. Map/Grid layer handles impassability via `is_passable_base = false` checks BEFORE cost-table lookup. The 6-entry table covers ROAD, PLAINS, HILLS, FOREST, MOUNTAIN, BRIDGE only
- [ ] **R-1 mitigation regression test**: `tests/unit/foundation/unit_role_test.gd::test_get_class_cost_table_caller_mutation_isolated` — fetch table for CAVALRY, mutate the returned array (e.g., `result[MOUNTAIN] = 99.0`), fetch CAVALRY table again, assert original values returned (`result2[MOUNTAIN] == 3.0`). MUST pass
- [ ] Source-comment above `get_class_cost_table` declaration reads: `# RETURNS PER-CALL COPY — DO NOT cache and return shared array. R-1 mitigation per ADR-0009 §5.`
- [ ] forbidden_pattern `unit_role_returned_array_mutation` is registered in `docs/registry/architecture.yaml` (already done at ADR-0009 authoring per commit `f4f1915` — this story verifies entry intact and matches the implementation contract)

---

## Implementation Notes

*From ADR-0009 §5, §R-1 mitigation, §Validation Criteria §6, ADR-0008 §Context item 5:*

1. Method body shape:
   ```gdscript
   # RETURNS PER-CALL COPY — DO NOT cache and return shared array. R-1 mitigation per ADR-0009 §5.
   static func get_class_cost_table(unit_class: UnitRole.UnitClass) -> PackedFloat32Array:
       _load_coefficients()
       var class_key := _class_to_key(unit_class)
       var table_array: Array = _coefficients[class_key]["terrain_cost_table"]
       # Construct fresh PackedFloat32Array per call — do NOT cache and return shared array.
       var result := PackedFloat32Array()
       result.resize(6)
       for i in 6:
           result[i] = table_array[i]
       return result
   ```
2. Returning a freshly-constructed `PackedFloat32Array` (NOT a slice of a cached one) is the simplest R-1-safe pattern. Alternative: return `_coefficients[class_key]["terrain_cost_table"].duplicate()` if the cache is already a PackedFloat32Array shape — verify per Story 002 implementation choice (JSON parse yields `Array`, not `PackedFloat32Array`, so explicit construction is needed).
3. The Map/Grid Dijkstra hot loop pattern (consumer-side, NOT this story):
   ```gdscript
   # Map/Grid Dijkstra (illustrative — actual code in Story 008)
   var cost_table := UnitRole.get_class_cost_table(unit_class)  # one fetch per get_movement_range
   for each cell in inner loop:
       var multiplier := cost_table[terrain_type]  # index read, no dispatch
       var cell_cost := floori(base_cost * multiplier)
   ```
4. The R-1 regression test (per ADR-0009 §Validation Criteria §6) is the **ONLY** way to catch a future caching regression. Static lint is preventive (forbidden_pattern grep), the regression test is detective:
   ```gdscript
   func test_get_class_cost_table_caller_mutation_isolated() -> void:
       var table_a := UnitRole.get_class_cost_table(UnitRole.UnitClass.CAVALRY)
       table_a[4] = 99.0  # mutate MOUNTAIN entry
       var table_b := UnitRole.get_class_cost_table(UnitRole.UnitClass.CAVALRY)
       assert_float(table_b[4]).is_equal(3.0)  # original value, NOT 99.0
       assert_float(table_a[4]).is_equal(99.0)  # caller's local copy retains mutation (proves they're separate arrays)
   ```
5. **Do not** add bounds-checking on `unit_class` (typed enum parameter binding from Story 001 catches invalid values at the call site per godot-specialist Item 2). **Do not** add bounds-checking on the returned array's `terrain_type` index access (caller responsibility — Map/Grid Dijkstra index is in [0, 5]).
6. **Do not** apply the floor operation in this story (CR-4b) — Map/Grid layer applies `floori(base_terrain_cost × class_multiplier)` per Story 008 ADR-0008 ratification. UnitRole returns the raw multiplier float.
7. **Do not** include RIVER or FORTRESS_WALL in the table (CR-4a) — they are not in the 6-entry table; Map/Grid handles impassability separately via `is_passable_base = false` BEFORE cost-table lookup.

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 005: `get_class_direction_mult` (similar shape but separate concern)
- Story 008: ADR-0008 `cost_multiplier` placeholder retirement — replaces TerrainEffect's `return 1` placeholder with either a thin pass-through to UnitRole.get_class_cost_table OR direct Map/Grid Dijkstra read of UnitRole accessor
- Map/Grid Dijkstra `get_movement_range` consumer logic (already exists in `src/core/map_grid.gd` per map-grid epic Complete; consumes the new cost matrix in Story 008)
- Map/Grid `is_passable_base` check for RIVER/FORTRESS_WALL (CR-4a — Map/Grid layer)
- Floor application `floori(base × multiplier)` per CR-4b (Map/Grid Dijkstra layer)
- Cavalry MOUNTAIN budget enforcement EC-3/EC-4 (Map/Grid `remaining_budget >= tile_cost` check)

---

## QA Test Cases

*Logic story — automated unit test specs.*

- **AC-1 (6×6 cost matrix correctness)**:
  - Given: `_coefficients_loaded` reset in `before_test`; valid `unit_roles.json` per Story 002
  - When: `UnitRole.get_class_cost_table(unit_class)` is called for each of the 6 classes
  - Then: each returned array has 6 entries; values match GDD CR-4 table exactly:
    - CAVALRY: `[1.0, 1.0, 1.5, 2.0, 3.0, 1.0]` (ROAD, PLAINS, HILLS, FOREST, MOUNTAIN, BRIDGE)
    - INFANTRY: `[1.0, 1.0, 1.0, 1.0, 1.5, 1.0]`
    - ARCHER: `[1.0, 1.0, 1.0, 1.0, 2.0, 1.0]`
    - STRATEGIST: `[1.0, 1.0, 1.5, 1.5, 2.0, 1.0]`
    - COMMANDER: `[1.0, 1.0, 1.0, 1.5, 2.0, 1.0]`
    - SCOUT: `[1.0, 1.0, 1.0, 0.7, 1.5, 1.0]`
  - Edge cases: each returned value is `float` (not int) per `PackedFloat32Array` typing; verify `result is PackedFloat32Array` typed return

- **AC-2 (R-1 mitigation — caller-mutation isolation)**:
  - Given: `UnitRole.get_class_cost_table(CAVALRY)` is called twice with mutation in between
  - When: caller A's returned array is mutated (`result[4] = 99.0`); caller B fetches a fresh table
  - Then: caller B's table has the original value (`result2[4] == 3.0`); caller A's local copy retains the mutation (proves they're separate arrays); UnitRole's internal `_coefficients` cache is not corrupted (verify by spot-check on `_coefficients["cavalry"]["terrain_cost_table"][4] == 3.0`)
  - Edge cases: 100+ rapid alternating fetches with mutations across all 6 classes — no cross-contamination
  - **This is the BLOCKING regression test for ADR-0009 §Validation Criteria §6**

- **AC-3 (AC-13 Cavalry MOUNTAIN multiplier)**:
  - Given: `UnitRole.get_class_cost_table(CAVALRY)`
  - When: `result[4]` (MOUNTAIN index) is read
  - Then: `result[4] == 3.0`. Combined with Map/Grid base MOUNTAIN cost 20 → effective cost 60 (Map/Grid responsibility, NOT verified here)
  - Edge cases: re-fetch returns same 3.0; floor operation NOT applied here (UnitRole returns float multiplier)

- **AC-4 (AC-14 Scout FOREST multiplier)**:
  - Given: `UnitRole.get_class_cost_table(SCOUT)`
  - When: `result[3]` (FOREST index) is read
  - Then: `result[3] == 0.7`. Combined with base FOREST 15 → `floori(15 × 0.7) = 10` (Map/Grid responsibility, NOT verified here — but document the expected downstream computation in test comments)
  - Edge cases: floating-point precision (`0.7` is not exact in binary float — verify `is_equal_approx(0.7, result[3])` if exact comparison fails)

- **AC-5 (AC-15 RIVER/FORTRESS_WALL absence)**:
  - Given: returned array length is 6
  - When: caller attempts to access `result[6]` or `result[7]` (out-of-bounds)
  - Then: out-of-bounds error (RIVER/FORTRESS_WALL not in this table); Map/Grid layer responsible for impassability checks before reaching cost-table lookup
  - Edge cases: `result.size() == 6` always

- **AC-6 (Source-comment present)**:
  - Given: `src/foundation/unit_role.gd` is written
  - When: a CI lint step greps for the R-1 source-comment marker
  - Then: `grep -B 1 "func get_class_cost_table" src/foundation/unit_role.gd` shows the `# RETURNS PER-CALL COPY` comment line
  - Edge cases: future refactor that drops the comment → CI lint fails

- **AC-7 (forbidden_pattern entry intact)**:
  - Given: `docs/registry/architecture.yaml` was populated by ADR-0009 authoring (commit `f4f1915`)
  - When: a CI lint step greps for the forbidden_pattern entry
  - Then: `grep "unit_role_returned_array_mutation" docs/registry/architecture.yaml` matches; entry text references ADR-0009 §5 + R-1
  - Edge cases: any future `/create-architecture` rebuild must preserve this entry

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/foundation/unit_role_cost_table_test.gd` — must exist and pass (7 ACs above; ~150-200 LoC test file with the **mandatory R-1 mitigation regression test** + 6×6 matrix correctness + AC-13/AC-14 boundary tests + G-15 reset in `before_test`)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (needs `_coefficients` cache populated by `_load_coefficients`)
- Unlocks: Story 008 (ADR-0008 placeholder retirement — replaces uniform=1 with this story's accessor); Map/Grid Dijkstra consumer (out of scope; verified via Story 008 integration test)
