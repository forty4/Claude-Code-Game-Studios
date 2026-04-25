# Story 004: get_terrain_modifiers + get_terrain_score (CR-1, CR-1d, F-3, EC-13, AC-14)

> **Epic**: terrain-effect
> **Status**: Ready
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

- [ ] `static func get_terrain_modifiers(grid: MapGrid, coord: Vector2i) -> TerrainModifiers` declared on `TerrainEffect`
- [ ] `static func get_terrain_score(grid: MapGrid, coord: Vector2i) -> float` declared on `TerrainEffect`
- [ ] If `_config_loaded == false`, both methods lazy-trigger `load_config()` before reading state (idempotent)
- [ ] `get_terrain_modifiers` reads `MapGrid.get_tile(coord).terrain_type`, looks up `_terrain_table[terrain_type]`, returns a NEW `TerrainModifiers` instance with copied field values (defensive copy)
- [ ] AC-1: HILLS defender (terrain_type=2) returns `TerrainModifiers` with `defense_bonus == 15`, `evasion_bonus == 0`, `special_rules == []`
- [ ] AC-11: All 8 terrain types return canonical CR-1 values (PLAINS 0/0/[], FOREST 5/15/[], HILLS 15/0/[], MOUNTAIN 20/5/[], RIVER 0/0/[], BRIDGE 5/0/[&"bridge_no_flank"], FORTRESS_WALL 25/0/[], ROAD 0/0/[])
- [ ] CR-1d / TR-002 uniformity: the query signature has NO `unit_type` parameter — all unit classes get the same modifiers (class differentiation is Map/Grid's cost_matrix domain, not Terrain Effect's terrain table)
- [ ] AC-14: out-of-bounds coord returns zero-fill `TerrainModifiers` (defense_bonus=0, evasion_bonus=0, special_rules=[]) — no error path; quiet zero-fill via the `MapGrid.get_tile` returning null guard
- [ ] EC-13: querying RIVER tile returns valid (0/0/[]) — no special-case error path for impassable terrain; modifier query and movement rule are independent concerns
- [ ] AC-13: `get_terrain_score(coord)` returns float in [0.0, 1.0] per F-3 formula `(defense_bonus + evasion_bonus * EVASION_WEIGHT) / MAX_POSSIBLE_SCORE`
- [ ] AC-13 worked examples match: FOREST → `(5 + 15 * 1.2) / 43.0 ≈ 0.5349`; HILLS → `(15 + 0) / 43.0 ≈ 0.3488`; PLAINS → `0.0`; FORTRESS_WALL → `(25 + 0) / 43.0 ≈ 0.5814` (note: NOT the maximum since MOUNTAIN's evasion stacks higher)
- [ ] EC-5: `get_terrain_score` is elevation-agnostic — same coord returns same score regardless of any "attacker reference"; signature has no `attacker_coord` parameter
- [ ] Defensive copy verified: mutating a returned `TerrainModifiers.special_rules.append(&"x")` does NOT affect the static `_terrain_table[terrain_type].special_rules` on subsequent calls

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

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (`_terrain_table` populated from JSON config), Story 002 (lazy-init guard contract), Story 001 (`TerrainModifiers` Resource class)
- Unlocks: Story 005 (`get_combat_modifiers` reuses the `_terrain_table` lookup pattern + the defensive-copy discipline established here)
