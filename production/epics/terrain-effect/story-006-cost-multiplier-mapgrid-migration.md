# Story 006: cost_multiplier + terrain_cost.gd:32 migration + Map/Grid regression

> **Epic**: terrain-effect
> **Status**: Ready
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-20
> **Estimate**: 1.5-2 hours (1 trivial method + 1 file edit + Map/Grid regression run; the integration verification is the real work)

## Context

**GDD**: `design/gdd/terrain-effect.md` §CR-1d (uniform across unit types) + `design/gdd/map-grid.md` §F-2/F-3 (Dijkstra cost matrix consumer side)
**Requirement**: `TR-terrain-effect-018` (cost_matrix structure), `TR-terrain-effect-002` (CR-1d MVP=1)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008 Terrain Effect System
**ADR Decision Summary**: `cost_multiplier(unit_type, terrain_type) -> int` returns the per-unit-type × per-terrain-type integer multiplier consumed by Map/Grid Dijkstra. MVP returns `_cost_default_multiplier` (1) for all 5×8 = 40 pairs per CR-1d uniformity. ADR-0009 Unit Role will populate concrete values later. This story migrates `src/core/terrain_cost.gd:32` from inline `return 1` placeholder to delegation: `return TerrainEffect.cost_multiplier(unit_type, terrain_type)`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: One method + one file edit + a regression-run verification. The integration test verifies Map/Grid behavior is unchanged — same 1-multiplier values, just routed through a different module. No post-cutoff APIs.

**Control Manifest Rules (Core layer)**:
- Required: `cost_multiplier` MUST be a static method on `TerrainEffect` (not on `MapGrid`); ownership lives in Terrain Effect per ADR-0008 §Decision 5
- Required: Map/Grid's `terrain_cost.gd:32` becomes a thin delegate — does NOT inline cost values
- Required: full Map/Grid regression suite (231/231 unit + integration tests per active.md narrative; actual count may differ on this branch tip — run the suite and confirm zero regression after migration) must pass unchanged
- Forbidden: hardcoding cost values inside `terrain_cost.gd` — the placeholder pattern is the anti-pattern this story replaces
- Forbidden: changing the public signature of `terrain_cost.gd::cost_multiplier(unit_type, terrain_type)` — Map/Grid's Dijkstra implementation calls it; signature stability is the migration safety guarantee

---

## Acceptance Criteria

*From ADR-0008 §Decision 5 + §Migration Plan + §GDD Requirements (TR-018):*

- [ ] `static func cost_multiplier(unit_type: int, terrain_type: int) -> int` declared on `TerrainEffect` (lazy-loads config if `_config_loaded == false`); returns `_cost_default_multiplier` for all input pairs in MVP
- [ ] `src/core/terrain_cost.gd:32` migrated from `return 1` to `return TerrainEffect.cost_multiplier(unit_type, terrain_type)`; the inline placeholder comment ("REPLACED WHEN ADR-0008 Terrain Effect lands") removed
- [ ] `terrain_cost.gd` file header doc-comment updated: removes the "ADR-0008 not yet landed" note; adds reference to ADR-0008 + ADR-0009-pending for value population
- [ ] `cost_multiplier` returns `1` for all (unit_type, terrain_type) pairs after default config load: tested across the 5 unit-type × 8 terrain-type matrix = 40 pairs
- [ ] Map/Grid regression suite passes unchanged after migration: 0 errors, 0 failures, 0 orphans, GODOT EXIT 0; specific Dijkstra-related tests (story-005-dijkstra-movement-range tests in map-grid epic — once that story has landed in code) verified to produce identical output
- [ ] CR-1d / TR-002 MVP uniformity: the implementation has no special-casing for any (unit_type, terrain_type) pair — it just returns `_cost_default_multiplier` from config; the future ADR-0009 expansion is the value-population point, not a structural change to this method
- [ ] Integration smoke: a 5×5 fixture map with a known optimal path produces the same path/cost before and after migration (sanity check that the indirection introduces no off-by-one or routing change)

---

## Implementation Notes

*Derived from ADR-0008 §Decision 5 (line 287-291) + §Migration Plan + §GDD Requirements TR-018:*

- **The reference implementation is trivial**:
  ```gdscript
  ## Returns the unit-type × terrain-type cost multiplier for Map/Grid Dijkstra.
  ## MVP: returns 1 for all (unit_type, terrain_type) pairs (CR-1d uniformity).
  ## ADR-0009 Unit Role will populate concrete values; structure already in place.
  static func cost_multiplier(unit_type: int, terrain_type: int) -> int:
      if not _config_loaded:
          load_config()
      # MVP: uniform multiplier per CR-1d. ADR-0009 will replace this with
      # _cost_matrix.get(unit_type, {}).get(terrain_type, _cost_default_multiplier).
      return _cost_default_multiplier
  ```
- **Map/Grid migration in `src/core/terrain_cost.gd`** — the placeholder file is one function:
  ```gdscript
  # BEFORE (placeholder):
  static func cost_multiplier(_unit_type: int, _terrain_type: int) -> int:
      # REPLACED WHEN ADR-0008 Terrain Effect lands; MVP ships with this placeholder.
      return 1

  # AFTER (delegation):
  static func cost_multiplier(unit_type: int, terrain_type: int) -> int:
      return TerrainEffect.cost_multiplier(unit_type, terrain_type)
  ```
- The argument names lose the leading underscore — they're now used (passed to the delegate), not unused. GDScript convention is `_name` for unused; `name` for used.
- The file header doc-comment in `terrain_cost.gd` should be updated:
  ```gdscript
  ## terrain_cost.gd — Map/Grid Dijkstra cost matrix consumer side.
  ## Delegates to TerrainEffect.cost_multiplier (per ADR-0008 §Decision 5).
  ## MVP returns 1 for all pairs per CR-1d; ADR-0009 Unit Role populates values.
  ```
- **Regression run protocol**: before the migration, capture baseline test counts (e.g., `231/231 PASS, 0 errors`). After the migration, re-run the full GdUnit4 suite and confirm identical counts. Any new failure = block the migration; investigate.
- **Future deletion**: per ADR-0008 §Migration Plan step 4, eventually `terrain_cost.gd` will be deleted entirely and all callers will use `TerrainEffect.cost_multiplier()` directly. That deletion is tracked as a separate TD when ADR-0009 lands; this story leaves `terrain_cost.gd` in place as a thin delegate.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Stories 001-005: TerrainEffect skeleton + Resource classes + config loading + queries
- Story 007: cap accessors
- Story 008: AC-21 perf benchmark
- ADR-0009 Unit Role: actual cost_matrix value population (5×8 = 40 pairs with class-specific values like Cavalry MOUNTAIN ×2)
- Future deletion of `src/core/terrain_cost.gd`: tracked as TD when ADR-0009 lands
- ADR-0008 §Decision 2 line 188 reconciliation note re: TerrainCost integer ordering (TD-032 A-16) — already documented in ADR; no action here

---

## QA Test Cases

*Authored from ADR-0008 §Decision 5 + §Migration Plan directly (lean mode — QL-STORY-READY gate skipped). Developer implements against these — do not invent new test cases during implementation.*

- **AC-1** (TR-018 + CR-1d): cost_multiplier returns 1 for all 5×8 = 40 (unit_type, terrain_type) pairs after default config load
  - Given: `reset_for_tests`; `load_config()` (default fixture)
  - When: nested loop `for unit_type in 0..5: for terrain_type in 0..8: cost_multiplier(unit_type, terrain_type)`
  - Then: every call returns `1`
  - Edge cases: this is structural — no unit-class enum exists yet (ADR-0009 not written), so unit_type values 0..4 are placeholders; the MVP's whole point is that the unit-type dimension is vestigial

- **AC-2** (TR-002): Method has lazy-init contract — first call triggers `load_config` if not loaded
  - Given: `reset_for_tests` (so `_config_loaded == false`)
  - When: `cost_multiplier(0, 0)` called
  - Then: `_config_loaded == true` after; result is `1`
  - Edge cases: same lazy-init contract pattern as stories 004/005 — all queries lazy-trigger independently

- **AC-3**: cost_multiplier respects tuned `_cost_default_multiplier` from config
  - Given: a test fixture with `cost_matrix.default_multiplier: 3` (intentional override); reset + load_config(test_path)
  - When: `cost_multiplier(0, 0)`
  - Then: returns `3`
  - Edge cases: verifies the config-driven path; future ADR-0009 will introduce per-pair lookups but the default fallback remains

- **AC-4** (Migration verification): `terrain_cost.gd::cost_multiplier` delegates to TerrainEffect
  - Given: `reset_for_tests`; `load_config()` (default)
  - When: `TerrainCost.cost_multiplier(2, 3)` called (Map/Grid's consumer-side method)
  - Then: returns identical value to `TerrainEffect.cost_multiplier(2, 3)` — both return `1`
  - Edge cases: this is the indirection sanity check; if the delegate is wrong (e.g., args swapped), this catches it

- **AC-5** (Map/Grid regression — the integration verification): full Map/Grid test suite passes unchanged after migration
  - Given: pre-migration baseline test counts captured (e.g., `N/N PASS, 0 errors, 0 failures, 0 orphans, GODOT EXIT 0` for the Map/Grid epic's tests)
  - When: full suite run after `terrain_cost.gd` migration
  - Then: identical counts; any Dijkstra-related test (story-005-dijkstra-movement-range tests in map-grid epic, once landed) produces identical path output
  - Edge cases: this is THE integration acceptance criterion — if Map/Grid behavior shifts, the migration is wrong; investigate before proceeding

- **AC-6** (Smoke integration test for the new TerrainEffect → Map/Grid path): a 5×5 fixture with mixed terrain produces the same Dijkstra path before/after migration
  - Given: a programmatic 5×5 MapGrid fixture with PLAINS / HILLS / FOREST mix; a known optimal path from (0,0) to (4,4)
  - When: `MapGrid.get_movement_range(unit_id, 10, 0)` (or `get_path` once that lands per map-grid epic story-005) called pre- and post-migration
  - Then: the returned PackedVector2Array is identical
  - Edge cases: this story may run BEFORE map-grid story-005 (Dijkstra) lands. If so, write the smoke test against whatever Dijkstra-related public API is available at this branch tip; if no Dijkstra API exists yet, the smoke test reduces to "TerrainCost.cost_multiplier returns 1 across the matrix" which AC-1 + AC-4 already cover. Document the dependency in §Dependencies below.

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/integration/core/terrain_cost_migration_test.gd` — must exist and pass (6 tests covering AC-1..6)
- Pre-migration baseline test count captured + post-migration confirmation: AC-5 verification result documented in `production/qa/evidence/` OR captured in the integration test file's header comment
- Full Map/Grid test suite runs green after migration (any failure blocks the story)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (`_cost_default_multiplier` populated from config), Story 002 (lazy-init guard)
- Soft-depends on: map-grid epic story-005 (Dijkstra) being landed for full AC-6 integration verification — if not yet landed at this branch tip, AC-6 reduces to AC-1+AC-4 coverage and is re-validated when story-005 lands (treated as a regression check at that future merge)
- Unlocks: ADR-0009 Unit Role epic (will populate `_cost_matrix` values; structure already in place); future deletion of `terrain_cost.gd` (tracked as TD when ADR-0009 lands)
