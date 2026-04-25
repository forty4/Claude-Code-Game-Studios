# Story 004: get_terrain_modifiers + get_terrain_score (CR-1, CR-1d, F-3, EC-13, AC-14)

> **Epic**: terrain-effect
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 2-3 hours (2 query methods + defensive copy + ~10 unit tests covering all 8 terrain types + OOB + AI scoring + RIVER edge case)

## Context

**GDD**: `design/gdd/terrain-effect.md` §CR-1 (terrain modifier table) + §CR-1d (uniform across unit types) + §F-3 (terrain_score formula) + AC-1, AC-11, AC-13, AC-14, EC-13
**Requirement**: `TR-terrain-effect-001` (CR-1 query side), `TR-terrain-effect-002` (CR-1d uniformity), `TR-terrain-effect-008` (2 of 3 query methods), `TR-terrain-effect-016` (AC-14 OOB)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008 Terrain Effect System
**ADR Decision Summary**: Two of the three public query methods. `get_terrain_modifiers(grid, coord) -> TerrainModifiers` returns raw uncapped values for HUD display per EC-12; reads `MapGrid.get_tile(coord).terrain_type`, looks up `_terrain_table[terrain_type]`, returns a defensive-copy `TerrainModifiers` instance (~5-10µs alloc per call). `get_terrain_score(grid, coord) -> float` returns normalized [0.0, 1.0] per F-3 formula; elevation-agnostic per EC-5.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Two O(1) operations — `MapGrid.get_tile` is O(1) packed-cache read per ADR-0004 §Decision 2; `_terrain_table[terrain_type]` is O(1) Dict lookup. Defensive `TerrainModifiers.new()` allocation is ~5-10µs per godot-specialist 2026-04-25 Item 13 (PASS at AC-21 budget). No post-cutoff APIs.

**Control Manifest Rules (Core layer)**:
- Required: `reset_for_tests()` in `before_each()` for any suite that calls TerrainEffect methods (ADR-0008 §Risks line 562)
- Required: defensive copy on Resource return — return a NEW `TerrainModifiers` instance each call, never the static `_terrain_table` value directly (ADR-0008 §Notes for Implementation §5; prevents caller mutation from poisoning the static state)
- Required: `get_terrain_score` is elevation-agnostic per EC-5 — does NOT take an attacker reference point; AI must combine with `get_combat_modifiers()` for elevation-aware decisions
- Forbidden: returning the static `_terrain_table` Resource directly (mutation leak)
- Forbidden: caching the returned Resource on the caller side and assuming it stays current — the `terrain_changed(coord)` signal is deferred to caching impl (ADR-0008 §4) but the no-caching-for-MVP rule means every call is a fresh lookup

---

## Acceptance Criteria

*From GDD AC-1, AC-11, AC-13, AC-14, EC-13 + ADR-0008 §Decision 5 + §Notes §5:*

- [x] `static func get_terrain_modifiers(grid: MapGrid, coord: Vector2i) -> TerrainModifiers` declared on `TerrainEffect`
- [x] `static func get_terrain_score(grid: MapGrid, coord: Vector2i) -> float` declared on `TerrainEffect`
- [x] If `_config_loaded == false`, both methods lazy-trigger `load_config()` before reading state (idempotent)
- [x] `get_terrain_modifiers` reads `MapGrid.get_tile(coord).terrain_type`, looks up `_terrain_table[terrain_type]`, returns a NEW `TerrainModifiers` instance with copied field values (defensive copy)
- [x] AC-1: HILLS defender (terrain_type=2) returns `TerrainModifiers` with `defense_bonus == 15`, `evasion_bonus == 0`, `special_rules == []`
- [x] AC-11: All 8 terrain types return canonical CR-1 values (PLAINS 0/0/[], FOREST 5/15/[], HILLS 15/0/[], MOUNTAIN 20/5/[], RIVER 0/0/[], BRIDGE 5/0/[&"bridge_no_flank"], FORTRESS_WALL 25/0/[], ROAD 0/0/[])
- [x] CR-1d / TR-002 uniformity: the query signature has NO `unit_type` parameter — all unit classes get the same modifiers (class differentiation is Map/Grid's cost_matrix domain, not Terrain Effect's terrain table)
- [x] AC-14: out-of-bounds coord returns zero-fill `TerrainModifiers` (defense_bonus=0, evasion_bonus=0, special_rules=[]) — no error path; quiet zero-fill via the `MapGrid.get_tile` returning null guard
- [x] EC-13: querying RIVER tile returns valid (0/0/[]) — no special-case error path for impassable terrain; modifier query and movement rule are independent concerns
- [x] AC-13: `get_terrain_score(coord)` returns float in [0.0, 1.0] per F-3 formula `(defense_bonus + evasion_bonus * EVASION_WEIGHT) / MAX_POSSIBLE_SCORE`
- [x] AC-13 worked examples match: FOREST → `(5 + 15 * 1.2) / 43.0 ≈ 0.5349`; HILLS → `(15 + 0) / 43.0 ≈ 0.3488`; PLAINS → `0.0`; FORTRESS_WALL → `(25 + 0) / 43.0 ≈ 0.5814` (note: NOT the maximum since MOUNTAIN's evasion stacks higher)
- [x] EC-5: `get_terrain_score` is elevation-agnostic — same coord returns same score regardless of any "attacker reference"; signature has no `attacker_coord` parameter
- [x] Defensive copy verified: mutating a returned `TerrainModifiers.special_rules.append(&"x")` does NOT affect the static `_terrain_table[terrain_type].special_rules` on subsequent calls

---

## Implementation Notes

*Derived from ADR-0008 §Decision 5 + §Notes for Implementation §5 + GDD F-3:*

- **Defensive copy pattern** (the ADR §Notes §5 + godot-specialist Item 13 canonical form):
  ```gdscript
  static func get_terrain_modifiers(grid: MapGrid, coord: Vector2i) -> TerrainModifiers:
      if not _config_loaded:
          load_config()
      var tile: MapTileData = grid.get_tile(coord) if grid != null else null
      if tile == null:
          return TerrainModifiers.new()  # zero-fill OOB return per AC-14
      var entry: TerrainModifiers = _terrain_table.get(tile.terrain_type, null)
      if entry == null:
          return TerrainModifiers.new()  # safety net for unknown terrain_type
      var copy := TerrainModifiers.new()
      copy.defense_bonus = entry.defense_bonus
      copy.evasion_bonus = entry.evasion_bonus
      copy.special_rules = entry.special_rules.duplicate()
      return copy
  ```
- **Note on G-2**: `entry.special_rules.duplicate()` demotes `Array[StringName]` to untyped `Array`. The `copy.special_rules` field is `@export Array[StringName]`, so the assignment will fail in strict typing. Use explicit typed assignment instead:
  ```gdscript
  var rules: Array[StringName] = []
  rules.assign(entry.special_rules)  # .assign() preserves typing
  copy.special_rules = rules
  ```
  Or, simpler: iterate and append. Either pattern works; pick one consistently across stories 004 and 005.
- **`get_terrain_score` formula** straight from GDD F-3:
  ```gdscript
  static func get_terrain_score(grid: MapGrid, coord: Vector2i) -> float:
      if not _config_loaded:
          load_config()
      var mods: TerrainModifiers = get_terrain_modifiers(grid, coord)
      return (mods.defense_bonus + mods.evasion_bonus * _evasion_weight) / _max_possible_score
  ```
- The MAX_POSSIBLE_SCORE = 43.0 constant is the theoretical-max FORTRESS_WALL score `25 + 15 * 1.2`. Note that no actual terrain reaches 1.0 — FORTRESS_WALL has 0 evasion, FOREST has 15 evasion but only 5 defense. The constant is preserved as a stable normalization basis; any future terrain that combines high def + high eva would exceed 1.0 unless the constant is updated.
- The `null grid` guard exists for tests that pass `null` deliberately to verify the OOB path. In production, `grid` is always non-null because `MapGrid` is the canonical battle-scoped Node. The guard is cheap insurance.
- For AC-14 OOB, `MapGrid.get_tile(Vector2i(-1, -1))` returns null per ADR-0004 §Decision 5 (verified at story-002 of map-grid epic — out-of-bounds coords return null, do not crash). Do NOT add a separate bounds-check here; let `MapGrid.get_tile` be the single source of truth for what counts as OOB.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: `_terrain_table` population from JSON; this story consumes the already-populated table
- Story 005: `get_combat_modifiers()` — the heavyweight query with elevation + clamps + bridge flag
- Story 006: `cost_multiplier()` for Map/Grid Dijkstra integration
- Story 007: `max_defense_reduction()` / `max_evasion()` shared accessors
- Future caching (deferred per ADR-0008 §4): no caching layer here; every call is a fresh lookup

---

## QA Test Cases

*Authored from GDD AC-1, AC-11, AC-13, AC-14, EC-13 + ADR-0008 §Decision 5 directly (lean mode — QL-STORY-READY gate skipped). Developer implements against these — do not invent new test cases during implementation.*

- **AC-1** (GDD AC-1): HILLS terrain returns canonical defense modifier
  - Given: `reset_for_tests()`; a 1×1 fixture MapGrid with one tile at (0,0) terrain_type=HILLS, elevation=0
  - When: `var m := TerrainEffect.get_terrain_modifiers(grid, Vector2i(0, 0))`
  - Then: `m.defense_bonus == 15`, `m.evasion_bonus == 0`, `m.special_rules.size() == 0`
  - Edge cases: AC-1 in the GDD says "15% less damage than PLAINS from identical attack" — that's a Damage Calc behavior; here we only verify the modifier value flows through

- **AC-2** (GDD AC-11): All 8 terrain types return canonical CR-1 values
  - Given: 8 separate 1×1 fixtures, one per terrain_type
  - When: `get_terrain_modifiers` called for each
  - Then: PLAINS 0/0/[]; FOREST 5/15/[]; HILLS 15/0/[]; MOUNTAIN 20/5/[]; RIVER 0/0/[]; BRIDGE 5/0/[&"bridge_no_flank"]; FORTRESS_WALL 25/0/[]; ROAD 0/0/[]
  - Edge cases: BRIDGE is the only terrain with non-empty `special_rules` in MVP; verify the StringName element is exactly `&"bridge_no_flank"` (not `"bridge_no_flank"` String — type matters for downstream `is_subsequence_of` calls)

- **AC-3** (GDD AC-14): OOB coord returns zero-fill modifiers
  - Given: a 5×5 fixture MapGrid loaded
  - When: `get_terrain_modifiers(grid, Vector2i(-1, -1))` and `get_terrain_modifiers(grid, Vector2i(99, 99))`
  - Then: both return `TerrainModifiers` with all-zero / empty fields; no error logged
  - Edge cases: `get_terrain_modifiers(null, Vector2i.ZERO)` — null grid — should also return zero-fill (the `grid != null` guard makes this a non-crash); document this as a defensive-only path (production never calls with null grid)

- **AC-4** (GDD EC-13): RIVER tile query returns valid 0/0 modifiers
  - Given: 1×1 fixture with terrain_type=RIVER (4)
  - When: `get_terrain_modifiers(grid, Vector2i(0, 0))`
  - Then: `defense_bonus == 0`, `evasion_bonus == 0`, `special_rules == []`
  - Edge cases: RIVER is impassable per Map/Grid, but the modifier query must not error — flying / boat units may legally occupy in the future. The query layer and movement layer are independent.

- **AC-5** (CR-1d / TR-002): Method signature has no unit_type parameter — uniformity verified at the contract level
  - Given: source code of `terrain_effect.gd` opened
  - When: signature of `get_terrain_modifiers` and `get_terrain_score` inspected
  - Then: signatures are `(grid: MapGrid, coord: Vector2i) -> TerrainModifiers` / `-> float` — no `unit_type` parameter
  - Edge cases: this is the structural verification of CR-1d. Class-specific terrain bonuses would require a signature change + ADR amendment.

- **AC-6** (GDD AC-13): get_terrain_score normalized to [0.0, 1.0]
  - Given: fixtures for FOREST, HILLS, PLAINS, FORTRESS_WALL
  - When: `get_terrain_score` called for each
  - Then: FOREST `(5 + 15*1.2) / 43.0 ≈ 0.5349` (assert via `is_equal_approx` with tolerance 0.001); HILLS `(15+0)/43.0 ≈ 0.3488`; PLAINS `0.0`; FORTRESS_WALL `(25+0)/43.0 ≈ 0.5814`
  - Edge cases: none of these reach 1.0 — the theoretical max requires hypothetical "FORTRESS_WALL with full evasion"; this is a stable normalization constant per F-3 + ADR-0008 §Decision 2

- **AC-7** (EC-5): get_terrain_score is elevation-agnostic
  - Given: source code of `get_terrain_score` opened
  - When: signature inspected
  - Then: signature is `(grid: MapGrid, coord: Vector2i) -> float` — no `attacker_coord` or elevation parameter
  - Edge cases: AI consumers must call `get_combat_modifiers(atk, def)` for elevation-aware decisions per EC-5 — this is documented in the AI epic's consumer contract, not enforced here

- **AC-8**: Defensive copy — caller mutation does not poison static state
  - Given: `reset_for_tests` + `load_config()`; a fixture with BRIDGE
  - When: `var m := get_terrain_modifiers(grid, bridge_coord)`; `m.special_rules.append(&"caller_pollution")`; `var m2 := get_terrain_modifiers(grid, bridge_coord)` (second call)
  - Then: `m2.special_rules.size() == 1` (only `&"bridge_no_flank"`); `m.special_rules.size() == 2` (the caller's mutation is local to `m` only)
  - Edge cases: this is the ADR-0008 §Notes §5 contract verification — without the defensive copy, the static `_terrain_table[BRIDGE].special_rules` would have grown to size 2 after the first call's mutation

- **AC-9**: Lazy-init triggers load_config on first query if not yet loaded
  - Given: `reset_for_tests` (so `_config_loaded == false`); fresh state
  - When: `get_terrain_modifiers(grid, Vector2i(0, 0))` called without prior `load_config`
  - Then: `_config_loaded == true` after the call (verified via `(load(PATH) as GDScript).get("_config_loaded")`); modifiers returned correctly from canonical defaults
  - Edge cases: this is the laziness contract from ADR-0008 §Decision 1 — tests that don't query terrain pay zero load cost

- **AC-10**: get_terrain_score also lazy-triggers load_config (parallel of AC-9)
  - Given: `reset_for_tests`; fresh state
  - When: `get_terrain_score(grid, Vector2i(0, 0))` called without prior `load_config`
  - Then: `_config_loaded == true` after; score returned correctly
  - Edge cases: both query methods independently trigger lazy load — neither assumes the other was called first

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/terrain_effect_queries_test.gd` — must exist and pass (10 tests covering AC-1..10)
- Test fixture: a small programmatic MapGrid + MapResource construction helper for the 8-terrain matrix (in-memory, no `.tres` authoring)

**Status**: [x] Created and passing — 10 test functions covering AC-1..AC-10 (with 3 inline /code-review-driven assertion additions: BRIDGE `typeof == TYPE_STRING_NAME` rigor, AC-3 (99,99) `special_rules.size()` symmetry, `get_terrain_score` OOB path); regression 252 → 262 (+10 new), 0 errors / 0 failures / 0 flaky / 0 orphans, Godot exit 0

---

## Dependencies

- Depends on: Story 003 (`_terrain_table` populated from JSON config), Story 002 (lazy-init guard contract), Story 001 (`TerrainModifiers` Resource class)
- Unlocks: Story 005 (`get_combat_modifiers` reuses the `_terrain_table` lookup pattern + the defensive-copy discipline established here)

---

## Completion Notes

**Completed**: 2026-04-26
**Criteria**: 13/13 passing (10 ACs as test functions + 3 sub-ACs verified by inspection-style assertions; 0 deferred; 0 untested) — 100% covered
**Deviations**:
- ADVISORY (fixture size): story spec said "1×1 fixture MapGrid" but `MapGrid.load_map` validation requires minimum 15 columns. Tests use 15×15 grids with the tile-of-interest at (0,0) and all other tiles as PLAINS. Behavior under test is identical (only (0,0) is queried); documented in test file headers.
- ADVISORY (TD-034 §F added): 1 deferred /code-review advisory — qa-tester R-3 (unknown terrain_type safety-net test). Cost ~10 min; suggested trigger is the epic-end test infrastructure hardening pass (story-008).
- ADVISORY (story-003 carry-over RESOLVED): TD-034 GAP-4 (fallback exact-value correctness — the BLOCKING carry-over from story-003) is now permanently mitigated. AC-2's explicit 8-terrain value matrix on `defense_bonus`, `evasion_bonus`, and `special_rules.size()` per terrain catches any typo in `_fall_back_to_defaults()`. Confirmed by qa-tester convergent review.
- ADVISORY (out-of-scope cosmetic): `tests/unit/core/terrain_effect_isolation_test.gd` doc-comments updated (3 occurrences of `before_each()` → `before_test()`). Mop-up of G-15 cosmetic finish; necessary for documentation accuracy.

**Test Evidence**:
- `tests/unit/core/terrain_effect_queries_test.gd` (590 LoC after R-1+R-2+R-4 inline additions, 10 test functions covering AC-1..AC-10) — EXISTS, all PASS
- Fixture helpers: `_make_grid(row, col, terrain_type, elevation)` (parametric 15×15 grid factory with target terrain at (0,0))
- Static-var seam: `(load(TERRAIN_EFFECT_PATH) as GDScript).get/set("_var")` per save_migration_registry_test.gd precedent
- Sentinel-mutation-preservation pattern (AC-9/AC-10): proves idempotent guard short-circuits second `get_terrain_modifiers` / `get_terrain_score` call BEFORE `_apply_config` re-runs (sentinel `_max_defense_reduction = 99` chosen because that field is NOT in F-3 formula — mutation cannot poison score equality assertion)
- Full regression: **262/262 PASS, 0 errors / 0 failures / 0 flaky / 0 orphans, Godot exit 0** (delta 252 → 262, +10 new test functions)

**Code Review**: Complete (lean mode standalone — convergent specialist review covered the LP-CODE-REVIEW + QL-TEST-COVERAGE phase-gates skipped under lean mode):
- godot-gdscript-specialist: **APPROVED WITH SUGGESTIONS** — pattern fidelity vs save_migration_registry; static typing PASS; G-1/G-2/G-9/G-12/G-14/G-15 all PASS; ADR-0008 §Decision 1/§Decision 5/§Decision 6/§Notes §5/EC-5/Pillar 1 fully compliant; forbidden-pattern audit PASS. 3 suggestions (1 out-of-scope story-003, 1 cosmetic, 1 false positive — story-003's AC-9 already covers file-not-found).
- qa-tester: **TESTABLE WITH GAPS** — TD-034 GAP-4 confirmed SATISFIED; 4 advisory gaps (no blocking); 4 recommendations.

**4 inline improvements applied** (3 to test rigor, 1 to documentation):
1. **R-1** (AC-3 `(99,99)` sub-case): added `special_rules.size()` assertion for coverage symmetry with (-1,-1) and null sub-cases.
2. **R-2** (AC-2 BRIDGE): added `typeof(bridge_m.special_rules[0]) == TYPE_STRING_NAME` after the existing `has(&"bridge_no_flank")` check. Closes a real type-safety gap: GDScript's `==` and `has()` coerce StringName ↔ String, so without this check a regression returning String "bridge_no_flank" instead of StringName &"bridge_no_flank" would silently pass.
3. **R-4** (AC-3 score path): added `get_terrain_score(grid, Vector2i(-1, -1)) == 0.0` assertion — proves OOB consistency across both queries (zero-fill modifiers → F-3 == 0).
4. **Sug 2** (`isolation_test.gd`): scrubbed 3 cosmetic `before_each()` references in doc-comments (lines 8, 51, 69). G-15 mop-up complete.

**1 advisory deferred to TD-034 §F**: qa-tester R-3 — unknown terrain_type safety-net test. The `if entry == null: return TerrainModifiers.new()` branch at terrain_effect.gd:501 catches a future scenario where `_terrain_table` lacks the queried terrain_type. AC-2 covers types 0-7 only; the internal safety net is currently untested in isolation. Test bypasses natural production path via `script.set("_terrain_table", {})` after lazy-init probe. Cost ~10 min.

**2 false positives correctly skipped** during /code-review triage:
- gdscript Sug 1 (`var err: int` → `var err: Error` typing) — out-of-scope, addresses story-003 code at line 159, not story-004
- gdscript Sug 3 (file-not-found path coverage) — already covered by story-003 AC-9 (`test_terrain_effect_config_file_not_found_falls_back`); agent missed the inline addition in story-003

**Files delivered** (2 spec'd + 2 out-of-scope, all justifiable):
- `src/core/terrain_effect.gd` (MODIFY, 466 → ~516 LoC; +47 LoC of impl + ~50 LoC of doc-comments) — 2 new public static methods (`get_terrain_modifiers`, `get_terrain_score`) inserted between `reset_for_tests` and `load_config` in the public-API section. Doc-comments use `[code]` BBCode tags + `@example` blocks per project standards.
- `tests/unit/core/terrain_effect_queries_test.gd` (NEW, 590 LoC, 10 test functions covering AC-1..AC-10) — `_make_grid()` parametric fixture helper; static-var seam pattern; G-15 awareness in header; `grid.free()` discipline (G-6) verified by 0 orphans
- `tests/unit/core/terrain_effect_isolation_test.gd` (MODIFY) — 3 cosmetic `before_each()` → `before_test()` doc-comment updates (G-15 mop-up; out-of-scope but necessary for accuracy)
- `docs/tech-debt-register.md` (MODIFY, +TD-034 §F + carry-over RESOLVED marker) — standard bookkeeping

**Forward-looking design decisions documented in code**:
- **Lazy-init pattern**: both query methods independently lazy-trigger `load_config()` if `_config_loaded == false`. Neither assumes the other was called first. Idempotent guard from story-003 short-circuits the second call.
- **Defensive copy via `.assign()`**: `rules.assign(entry.special_rules)` preserves `Array[StringName]` typing per G-2. Story-005 will inherit this discipline for `CombatModifiers`.
- **Quiet zero-fill OOB**: no `push_error`, no `push_warning` on out-of-bounds queries. Per ADR-0008 §Pillar 1 ("battlefield always readable"), consumers (HUD, AI) must never crash on edge-coord queries. Documented in method doc-comments.
- **F-3 formula source-of-truth**: `get_terrain_score` uses `_evasion_weight` and `_max_possible_score` from config — no hardcoded `1.2` or `43.0` literals in the formula.
- **EC-5 elevation-agnostic by signature**: `get_terrain_score(grid, coord)` has only 2 parameters. Verified at the test level via `get_script_method_list()` inspection. Class-specific or elevation-aware terrain bonuses would require an ADR amendment.

**Process insights** (compounding wins):
- **Convergent /code-review pattern** (gdscript + qa-tester parallel) ran in <3min combined; identified 7 findings (3 gdscript + 4 qa); applied 4 inline within ~5min; deferred 1 to TD-034 §F; correctly skipped 2 false positives. Pattern continues to validate as lean-mode minimum-safe-unit.
- **Convergent review specialist drift handling**: gdscript-specialist's findings drifted to story-003 code (5 of 6 line refs were story-003 implementation). Orchestrator triaged each finding for scope before applying. This is a healthy pattern — specialist sees the whole file; orchestrator filters for story scope.
- **G-14 codification (PR #35)** still paying dividends — pre-emptive `--import` pass after writing terrain_effect_queries_test.gd produced clean parse on first try.
- **G-15 codification (story-003)** still paying dividends — `before_test()` discipline applied correctly in the new test file from the start; no rediscovery cost.
- **Sub-agent Bash blocking pattern documented**: gdscript-specialist drafted both files for approval, then was BLOCKED on running Bash for the regression. Orchestrator-direct Bash recovery + the inline `assert_not_null` → `assert_object().is_not_null()` fix produced clean 262/262 in 2 iterations.
- **Inline orchestrator fix discipline**: agent's draft used `assert_not_null(m)` (JUnit/NUnit pattern). Orchestrator caught it during regression and fixed inline to `assert_object(m).is_not_null()` (GdUnit4 v6.1.2 idiom). Lesson: agent drafts may use unfamiliar assertion forms; verify against actual API before approving writes — but if it slips through, regression catches it cleanly.
- **AC count growth as a coverage signal**: spec was 10 ACs (with 3 sub-ACs). Final has 10 test functions covering 13 ACs total. R-2 type-identity check, R-1 coverage symmetry, and R-4 OOB consistency strengthened existing tests rather than inflating count — this is the right pattern for /code-review polish.
- **Convergent review test infrastructure dividend**: the convergent pattern (started in story-003) is producing reliable per-story improvement deltas (~3-5 inline fixes + 1-2 carry-overs to TD per story). This compounds: story-005's review will inherit the same pattern + the 3 advisory tests in TD-034 §C.

**Tech debt**: TD-034 extended with §F (1 new sub-item, ~10 min cost) + §Story-004 carry-over marked RESOLVED.

**No new gotcha codified this story** — all gotchas applied correctly from prior work (G-1/G-2/G-9/G-12/G-14/G-15).

**Unlocks**: Story 005 (`get_combat_modifiers` reuses `_terrain_table` lookup pattern + defensive-copy discipline established here; will exercise CR-2 elevation, CR-3a/b symmetric clamp, CR-5 BRIDGE flag, EC-14 delta clamp), Story 006 (`cost_multiplier` for Map/Grid Dijkstra integration), Story 007 (cap accessors `max_defense_reduction()` / `max_evasion()` shared accessors).

**Terrain-effect epic status**: **4/8 Complete** 🎉 — half-way mark crossed. Stories 005-007 are now parallelizable per EPIC dependency chain.
