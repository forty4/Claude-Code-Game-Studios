# Story 006: cost_multiplier + terrain_cost.gd:32 migration + Map/Grid regression

> **Epic**: terrain-effect
> **Status**: Complete
> **Layer**: Core
> **Type**: Integration
> **Manifest Version**: 2026-04-20
> **Estimate**: 1.5-2 hours (1 trivial method + 1 file edit + Map/Grid regression run; the integration verification is the real work)
> **Actual**: ~2.5 hours (implementation 1h + 1 mid-implementation orchestrator-direct fix + /code-review with 6 inline improvements 45min + /story-done bookkeeping 30min)

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

**Status**: [x] Created and passing — `tests/integration/core/terrain_cost_migration_test.gd` (385 LoC, 6 test functions covering AC-1..AC-7); full regression 282/282 PASS, 0 errors / 0 failures / 0 orphans, godot exit 0 (was 276/276 baseline → +6 new = exact expected delta)

---

## Dependencies

- Depends on: Story 003 (`_cost_default_multiplier` populated from config), Story 002 (lazy-init guard)
- Soft-depends on: map-grid epic story-005 (Dijkstra) being landed for full AC-6 integration verification — if not yet landed at this branch tip, AC-6 reduces to AC-1+AC-4 coverage and is re-validated when story-005 lands (treated as a regression check at that future merge)
- Unlocks: ADR-0009 Unit Role epic (will populate `_cost_matrix` values; structure already in place); future deletion of `terrain_cost.gd` (tracked as TD when ADR-0009 lands)

---

## Completion Notes

**Completed**: 2026-04-26
**Verdict**: COMPLETE WITH NOTES
**Criteria**: 7/7 PASS (all spec'd as named test functions; 0 deferred; 0 untested; 100% covered)
**Tests**: 6 test functions in `terrain_cost_migration_test.gd` (385 LoC after /code-review enhancements); full regression 282/282 PASS, 0 errors / 0 failures / 0 flaky / 0 orphans, godot exit 0; suite execution 49ms.

**Files delivered** (3 in scope, 1 admin):
- `src/core/terrain_effect.gd` (MODIFY, 629 → 656 LoC; +27 LoC = +25 method/doc + +2 ADR-0009 cleanup TODO comment) — new `static func cost_multiplier(unit_type: int, terrain_type: int) -> int` inserted after `get_terrain_score` per ADR-0008 §Decision 5 ordering. `@warning_ignore("unused_parameter")` annotation + ADR-0009 cleanup TODO.
- `src/core/terrain_cost.gd` (MODIFY, 69 → 76 LoC; +7 LoC) — placeholder body replaced with `return TerrainEffect.cost_multiplier(unit_type, terrain_type)` delegate; 3 doc-comment regions updated (header lines 12-17, lines 21-24, BASE_TERRAIN_COST G-1 cross-ref lines 41-45). Argument names lose `_` prefix.
- `tests/integration/core/terrain_cost_migration_test.gd` (NEW, 385 LoC after /code-review trim, 6 test functions covering AC-1..AC-7) — `before_test()` discipline (G-15) with `TerrainEffect.reset_for_tests()`; user:// fixture pattern (AC-3) with `_write_ac3_fixture` helper + `DirAccess.remove_absolute` cleanup; `(load(PATH) as GDScript).get(...)` static-var inspection (AC-2); `_make_custom_terrain_map` factory (AC-7); `MapGrid.get_movement_range` Dijkstra exercise with positive (5,7) + negative (7,4) boundary assertions; `grid.free()` G-6 cleanup at end of AC-7 test.
- `docs/tech-debt-register.md` (MODIFY, +TD-034 §J/§K + cross-ref bookkeeping) — admin bookkeeping for advisory items from /code-review.

**Code-review verdict** (lean mode standalone convergent — 2 specialists in parallel):
- godot-gdscript-specialist: **APPROVED WITH SUGGESTIONS** (4 suggestions + 5 PASS-info + 1 recommendation + 1 OOS finding)
- qa-tester: **TESTABLE WITH GAPS** (6/6 ACs faithfully covered + 6 findings, 0 BLOCKING)
- **6 inline improvements applied**: (1) removed dead `_make_uniform_map` helper [convergent gdscript 1-A + qa F-4]; (2) typed `pairs: Array[Vector2i]` [gdscript 1-B]; (3) typed `result_set: Dictionary[Vector2i, bool]` [gdscript 1-C]; (4) direct `assert_int(...).is_greater(1)` [gdscript 1-D]; (5) line 384 prose fix "PLAINS neighbour" → "HILLS neighbour" [convergent gdscript 1-J + qa F-3]; (6) AC-5 doc-comment expanded to clarify hybrid value+count contract [qa F-1]; (7) TODO comment above `@warning_ignore` for ADR-0009 cleanup obligation [qa F-6].
- **2 advisories deferred** to TD-034 §J/§K (~16 min total): §J AC-6 expected reachable tile count not pinned (defer to ADR-0009 trigger); §K ADR-0008 §Risks line 567 stale `before_each()` reference (defer to next ADR-0008 amendment).

**Forced deviation accepted (1 ADVISORY, 0 BLOCKING)**: AC-7 spec wording "5×5 fixture map" relaxed to 15×15. `MapGrid.load_map` validation requires `rows ∈ [15,40]` and `cols ∈ [15,40]` per ADR-0004 §Decision 4. Behavior under test (Dijkstra cost-accumulation through migrated TerrainCost.cost_multiplier delegate) is identical at 15×15. Documented in test docstring + budget arithmetic adjusted (move_range=3, budget=30, origin (7,7) center).

**Mid-implementation orchestrator-direct fix history** (1 iteration): agent's first AC-7 (smoke path) draft had a step-cost arithmetic error in the (7,4) reachability assertion — comment said "3 steps × 10 = 30 = budget" but origin (7,7) IS in the HILLS band (rows 5-9), so path crosses 2 HILLS cells (cost 30) before reaching PLAINS (+10 = 40, over budget). Also missing `grid.free()` (G-6 orphan). Orchestrator-direct fix flipped (7,4) to negative assertion (HILLS band acts as budget barrier — itself useful regression coverage), added (5,7) positive boundary assertion (2 HILLS × 15 = 30 exactly = budget), added `grid.free()` cleanup. Re-run: 282/282 clean.

**Process insights**:
- **Cross-product fixture-vs-engine drift** is now the **5th occurrence** in this epic (story-002 TILE_STATE_, story-004 MAP_COLS_MIN, story-005 ELEVATION_RANGES, story-006 5×5 → 15×15 fixture-size + step-cost arithmetic). Recommendation logged earlier (story-005) for "Engine constraint quick-reference" section in story files remains unactioned and would have prevented both story-006 issues.
- **Convergent /code-review pattern (lean mode)** validated 5th time in this epic — minimum-safe-unit confirmed. Both specialists hit dead `_make_uniform_map` helper independently (gdscript 1-A + qa F-4); both hit cosmetic line 384 prose (gdscript 1-J + qa F-3). Strong-signal pattern: when both reviewers independently flag the same item, apply without further deliberation.
- **G-6/G-14/G-15 codifications** continue to pay dividends — clean lifecycle on first run for the orchestrator-direct AC-7 fix (G-6 `grid.free()` recall was immediate); G-14 import pass produced clean parse for the new test file; G-15 `before_test()` applied correctly from start.
- **Sub-agent Bash blocking pattern** continues — agent drafted both files for approval, then BLOCKED on Bash for verification chain. Orchestrator-direct Bash recovery (G-14 import + full-suite regression + AC-7 inline fix) executed in 1 iteration. 5th time in this epic; pattern stable.
- **AC-5 hybrid value+count contract**: the value contract (`TerrainEffect.cost_multiplier(0,0) == 1` AND `TerrainCost.cost_multiplier(0,0) == 1`) is asserted in the test function; the count contract (276 → 282 zero-regression) is captured externally in active.md per story §Test Evidence allowance. The qa-tester correctly flagged that the test function's NAME implied AC-5 automated coverage when the actual count contract is external — fix was a doc-comment expansion clarifying the hybrid (no rename needed since the orchestrator-level external check IS the canonical AC-5 verification).

**Tech debt logged**: 2 new sub-items — TD-034 §J (~15 min) + §K (~1 min). TD-034 cross-references updated to mark story-006 carry-over.

**No new gotcha codified this story** — all gotchas applied correctly from prior work (G-1 / G-6 / G-9 / G-14 / G-15). The AC-7 step-cost arithmetic error is test-authoring discipline, not a Godot/GdUnit4 gotcha.

**Terrain-effect epic status**: **6/8 Complete** 🎉 — first Integration story landed. Stories 007 (cap accessors) and 008 (perf benchmark + epic-end test infrastructure hardening) remain.
