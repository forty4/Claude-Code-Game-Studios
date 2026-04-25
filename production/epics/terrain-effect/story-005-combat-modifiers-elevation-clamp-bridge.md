# Story 005: get_combat_modifiers (CR-2 elevation + CR-3a/b symmetric clamp + CR-5 bridge flag + EC-14 delta clamp)

> **Epic**: terrain-effect
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 4-5 hours (heaviest query method; covers 8 GDD ACs + 1 EC; 14+ unit tests including elevation × terrain × bridge matrix)

## Context

**GDD**: `design/gdd/terrain-effect.md` §CR-2 (asymmetric elevation modifiers) + §CR-3a (symmetric clamp) + §CR-3b (evasion cap) + §CR-3e + §CR-5 (bridge FLANK→FRONT) + §EC-1 (negative defense symmetric clamp authoritative) + §EC-14 (delta clamp ±2) + §F-1 + §AC-3, AC-4, AC-5, AC-6, AC-7, AC-9, AC-10, AC-12 + `damage-calc.md` §F (cross-system contract ratified 2026-04-18)
**Requirement**: `TR-terrain-effect-003` (CR-2), `TR-terrain-effect-004` (F-1 clamp), `TR-terrain-effect-005` (caps), `TR-terrain-effect-007` (CR-3e/EC-1), `TR-terrain-effect-008` (3 of 3 query methods), `TR-terrain-effect-009` (CR-5 bridge_no_flank flag), `TR-terrain-effect-011` (cross-system contract), `TR-terrain-effect-015` (EC-14)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008 Terrain Effect System
**ADR Decision Summary**: The third and most complex query method. `get_combat_modifiers(grid, atk, def) -> CombatModifiers` reads both tile coords, computes `delta_elevation = atk.elev - def.elev`, clamps to [-2, +2] per EC-14 with warning, looks up the elevation table, applies the F-1 symmetric clamp `[-MAX_DEFENSE_REDUCTION, +MAX_DEFENSE_REDUCTION]` to `terrain_def`, applies the [0, MAX_EVASION] clamp to `terrain_eva`, sets `bridge_no_flank = true` if defender on BRIDGE per CR-5b, returns the populated `CombatModifiers` Resource. Cross-system contract honored: returned values are opaque pre-clamped per `damage-calc.md` §F.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Two `MapGrid.get_tile` calls (O(1) packed-cache reads each), two Dictionary lookups (`_terrain_table[def.terrain_type]` + `_elevation_table[delta]`), `clampi` arithmetic, defensive copy. Total ~10-20µs estimate per godot-specialist 2026-04-25 Item 11 (PASS at AC-21 0.1ms budget — 5-10× headroom). No post-cutoff APIs.

**Control Manifest Rules (Core layer)**:
- Required: F-1 symmetric clamp `[-MAX_DEFENSE_REDUCTION, +MAX_DEFENSE_REDUCTION]` for total_defense — clamped value is what Damage Calc receives (cross-system contract `terrain_def ∈ [-30, +30]` per damage-calc.md §F)
- Required: [0, MAX_EVASION] clamp for terrain_evasion — opaque clamped value per cross-system contract `terrain_evasion ∈ [0, 30]`
- Required: EC-14 elevation delta clamp to [-2, +2] BEFORE elevation table lookup; out-of-range delta logs `push_warning` per ADR-0008 + GDD EC-14
- Required: CR-5b bridge rule is defender-centric — set `bridge_no_flank = true` ONLY if the defender's terrain_type == BRIDGE; attacker's tile irrelevant to this flag
- Required: defensive copy on Resource return (same discipline as story-004)
- Forbidden: applying the FLANK→FRONT direction collapse here — that orchestration is owned by Damage Calc per ADR-0008 §Decision 3 (Map/Grid stays Foundation-pure; Damage Calc reads `bridge_no_flank` flag)
- Forbidden: enforcing the min damage = 1 rule (CR-3d) here — that's Damage Calc's responsibility per cross-system contract

---

## Acceptance Criteria

*From GDD AC-3, AC-4, AC-5, AC-6, AC-7, AC-9, AC-10, AC-12, EC-14 + ADR-0008 §Decision 5 + §Decision 6:*

- [ ] `static func get_combat_modifiers(grid: MapGrid, attacker_coord: Vector2i, defender_coord: Vector2i) -> CombatModifiers` declared on `TerrainEffect`
- [ ] If `_config_loaded == false`, lazy-trigger `load_config()` before reading state
- [ ] Reads `MapGrid.get_tile(attacker_coord)` and `MapGrid.get_tile(defender_coord)`; if either is null, returns zero-fill `CombatModifiers.new()` (defensive — same OOB pattern as story-004 AC-3)
- [ ] Computes `delta_elevation = attacker_tile.elevation - defender_tile.elevation`
- [ ] EC-14 / TR-015: clamps `delta_elevation` to [-2, +2] before table lookup; if clamped (out-of-range input), emits `push_warning("delta_elevation %d clamped to ±2 — update CR-2 table for new elevation range" % raw_delta)`
- [ ] Looks up `_elevation_table[clamped_delta]`; populates `elevation_atk_mod` (attack_mod) + `elevation_def_mod` (defense_mod) on the returned `CombatModifiers`
- [ ] AC-3: delta=+2 (attacker elevation 2 vs defender 0) → `elevation_atk_mod == 15` (positive — attacker bonus)
- [ ] AC-4: delta=+2 → `elevation_def_mod == -15` (negative — defender penalty per CR-2 table line 112; the asymmetric "attacker above" case)
- [ ] Reads defender_tile's terrain_type; looks up `_terrain_table[terrain_type]`; computes `total_defense = entry.defense_bonus + elevation_def_mod` (NOT including formation_def — that's Damage Calc's job per cross-system contract)
- [ ] AC-5 / F-1 clamp: `defender_terrain_def = clampi(total_defense, -_max_defense_reduction, _max_defense_reduction)` — symmetric clamp [-30, +30]; FORTRESS_WALL (25) + delta=-2 (elev_def +15) = 40 → clamped to 30
- [ ] AC-7: PLAINS (0) + delta=+2 (elev_def -15) = -15 → returned as -15 (negative; not floored to 0; CR-3e + EC-1 symmetric clamp authoritative)
- [ ] AC-6 / TR-005: terrain_eva from defender's `_terrain_table[terrain_type].evasion_bonus`, clamped to [0, _max_evasion]; FOREST (15) is below the cap (returns 15); the [0, 30] upper bound enforcement is what gets stress-tested
- [ ] CR-5b / TR-009: if defender_tile.terrain_type == BRIDGE, set `bridge_no_flank = true` and append `&"bridge_no_flank"` to `special_rules`; else both are false / empty
- [ ] AC-10: bridge rule defender-centric — attacker on BRIDGE + defender on PLAINS yields `bridge_no_flank == false`
- [ ] AC-12: full 6-field `CombatModifiers` populated correctly: `defender_terrain_def`, `defender_terrain_eva`, `elevation_atk_mod`, `elevation_def_mod`, `bridge_no_flank`, `special_rules`
- [ ] TR-011 cross-system contract: returned values are opaque pre-clamped per damage-calc.md §F; no further clamping happens downstream

---

## Implementation Notes

*Derived from ADR-0008 §Decision 5 + §Decision 6 + §Decision 3 + GDD F-1 + GDD EC-14:*

- **Reference implementation skeleton** (the implementer may refine):
  ```gdscript
  static func get_combat_modifiers(grid: MapGrid, atk_coord: Vector2i, def_coord: Vector2i) -> CombatModifiers:
      if not _config_loaded:
          load_config()
      var atk_tile: MapTileData = grid.get_tile(atk_coord) if grid != null else null
      var def_tile: MapTileData = grid.get_tile(def_coord) if grid != null else null
      if atk_tile == null or def_tile == null:
          return CombatModifiers.new()  # OOB → zero-fill
      var raw_delta: int = atk_tile.elevation - def_tile.elevation
      var clamped_delta: int = clampi(raw_delta, -2, 2)
      if clamped_delta != raw_delta:
          push_warning("delta_elevation %d clamped to ±2 — update CR-2 table for new elevation range" % raw_delta)
      var elev: ElevationEntry = _elevation_table[clamped_delta]  # struct or Dict, depending on storage
      var terrain: TerrainModifiers = _terrain_table[def_tile.terrain_type]
      var total_def: int = terrain.defense_bonus + elev.defense_mod
      var result := CombatModifiers.new()
      result.defender_terrain_def = clampi(total_def, -_max_defense_reduction, _max_defense_reduction)
      result.defender_terrain_eva = clampi(terrain.evasion_bonus, 0, _max_evasion)
      result.elevation_atk_mod = elev.attack_mod
      result.elevation_def_mod = elev.defense_mod
      result.bridge_no_flank = (def_tile.terrain_type == BRIDGE)
      var rules: Array[StringName] = []
      rules.assign(terrain.special_rules)
      result.special_rules = rules
      return result
  ```
- **Note on storage of `_elevation_table` values**: Story-003 chose how to store these (nested Dict or a typed Resource). This story consumes whatever shape story-003 provides. If `_elevation_table` stores nested Dicts (`{"attack_mod": 15, "defense_mod": -15}`), the lookup syntax differs from typed Resource access. Pick the consistent pattern that story-003 established and match it here.
- **AC-3 vs AC-4 directionality**: GDD CR-2 table is the canonical source. Re-read line 108-112: delta=+2 → attacker bonus +15%, defender penalty −15%. The two ACs are checking the same row from different perspectives — both must pass. This is the OQ-7 close-as-resolved item from the 2026-04-25 architecture-review (no actual inconsistency).
- **Negative defense (AC-7) is intentional**: CR-3e + EC-1 + F-1 all converge — symmetric clamp [−30, +30] is authoritative. PLAINS (0) + attacker-far-above-defender (delta=+2 → elev_def=−15) yields total_defense = −15 returned as-is (within clamp). Damage Calc multiplies by `(1 - total_defense/100)` → `(1 - (-15)/100) = 1.15` → 15% damage amplification. This is the "land fights against you" inversion that the Pillar 1 fantasy designs around.
- **Bridge flag denormalization**: `bridge_no_flank: bool` is denormalized — it's also represented in `special_rules` as `&"bridge_no_flank"`. Damage Calc may check either; the bool is faster (no array scan). Both must be set consistently.
- The cross-system contract `terrain_def ∈ [-30, +30]` (damage-calc.md §F ratified 2026-04-18) means this method's `defender_terrain_def` field IS the clamped opaque value. Damage Calc treats it as a black box; it does not see the underlying terrain + elevation breakdown. Tests must verify the clamp works at boundary inputs (e.g., FORTRESS_WALL + delta=-2 = 25 + 15 = 40 → clamped to 30; not 40).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: `_terrain_table` + `_elevation_table` populated from JSON
- Story 004: `get_terrain_modifiers` (raw uncapped) + `get_terrain_score` (AI scoring)
- Story 006: `cost_multiplier` for Map/Grid Dijkstra
- Story 007: `max_defense_reduction()` / `max_evasion()` shared accessors
- Damage Calc's FLANK→FRONT direction collapse using `bridge_no_flank` flag — owned by Damage Calc Feature epic per ADR-0008 §Decision 3
- Damage Calc's evasion roll execution — owned by Damage Calc per cross-system contract; this story provides the rate only
- Damage Calc's min damage = 1 enforcement (CR-3d) — owned by Damage Calc

---

## QA Test Cases

*Authored from GDD AC-3, AC-4, AC-5, AC-6, AC-7, AC-9, AC-10, AC-12, EC-14 + ADR-0008 §Decision 5 + §Decision 6 directly (lean mode — QL-STORY-READY gate skipped). Developer implements against these — do not invent new test cases during implementation.*

- **AC-1** (GDD AC-3): Elevation attack bonus at delta=+2
  - Given: `reset_for_tests`; 2-tile fixture (atk at elev=2, def at elev=0, both PLAINS)
  - When: `get_combat_modifiers(grid, atk_coord, def_coord)`
  - Then: `elevation_atk_mod == 15`
  - Edge cases: AC-3 in GDD says "deals 15% more damage" — that's a Damage Calc behavior; here we verify the modifier value flows through

- **AC-2** (GDD AC-4): Elevation defense modifier (defender penalty) at delta=+2
  - Given: same 2-tile fixture from AC-1
  - When: `get_combat_modifiers`
  - Then: `elevation_def_mod == -15` (negative — defender's terrain defense is reduced when attacker is above)
  - Edge cases: this is the asymmetric pair to AC-1; both verify the same CR-2 table row from different perspectives

- **AC-3** (GDD AC-5): Defense cap enforced at 30%
  - Given: 2-tile fixture (atk at elev=0, def at elev=2, def on FORTRESS_WALL); delta=-2 → elev_def=+15
  - When: `get_combat_modifiers`
  - Then: total_defense = 25 (FORTRESS_WALL) + 15 (elevation) = 40 → `defender_terrain_def == 30` (clamped to MAX_DEFENSE_REDUCTION)
  - Edge cases: verify it's actually 40 pre-clamp (not 33 like AC-5's GDD example which has elev_def=+8 from delta=-1) — the test setup must match the formula

- **AC-4** (GDD AC-6): Evasion cap enforced at 30%
  - Given: 2-tile fixture, def on FOREST; agility-stacking is a Damage Calc concern, but at the Terrain Effect boundary, the FOREST evasion is 15 (under cap)
  - When: `get_combat_modifiers`
  - Then: `defender_terrain_eva == 15` (not clamped because under cap); the cap behavior is verified in AC-7's separate config-mutation case
  - Edge cases: GDD AC-6 says "FOREST (15) + agility (20) = 35 → clamped to 30" but agility is added downstream by HP/Status or Hero DB. Terrain Effect supplies only the terrain side. This test verifies the [0, 30] clamp boundary at the terrain side; the upper-bound clamp is exercised only with tuning-knob overrides (TK-2 raised the cap above 30, then a stronger tuned-eva config triggers the clamp). Skip the upper-bound stress test here; AC-7 below covers boundary by setting `_max_evasion = 10` via test config.

- **AC-5** (GDD AC-7): Negative defense amplifies damage
  - Given: 2-tile fixture (atk at elev=2, def at elev=0, def on PLAINS); delta=+2 → elev_def=−15
  - When: `get_combat_modifiers`
  - Then: total_defense = 0 (PLAINS) + (−15) = −15 → `defender_terrain_def == -15` (within symmetric clamp; not floored to 0)
  - Edge cases: this is the CR-3e + EC-1 explicit verification — symmetric clamp is authoritative; "not capped" doesn't mean "floored to 0"

- **AC-6** (GDD AC-9): Bridge FLANK rule — defender on BRIDGE sets bridge_no_flank flag
  - Given: 2-tile fixture (atk on PLAINS at any elev, def on BRIDGE at any elev)
  - When: `get_combat_modifiers`
  - Then: `bridge_no_flank == true`; `&"bridge_no_flank" in result.special_rules`
  - Edge cases: AC-9 in GDD also asserts the FLANK→FRONT collapse at the Damage Calc level — that's out of scope here; only the flag set is verified

- **AC-7** (GDD AC-10): Bridge rule defender-centric — attacker on BRIDGE + defender elsewhere = no flag
  - Given: 2-tile fixture (atk on BRIDGE, def on PLAINS)
  - When: `get_combat_modifiers`
  - Then: `bridge_no_flank == false`; `&"bridge_no_flank" not in result.special_rules`
  - Edge cases: confirms CR-5b — the rule applies when DEFENDER is on bridge, not attacker

- **AC-8** (GDD AC-12): Full 6-field CombatModifiers populated
  - Given: a representative case (atk elev=1 PLAINS, def elev=0 HILLS, delta=+1 → atk_mod +8, def_mod -8)
  - When: `get_combat_modifiers`
  - Then: `defender_terrain_def == 15 + (-8) = 7` (clamped against [-30, +30] no-op since within); `defender_terrain_eva == 0` (HILLS); `elevation_atk_mod == 8`; `elevation_def_mod == -8`; `bridge_no_flank == false`; `special_rules.size() == 0`
  - Edge cases: this is the canonical "full context" test — touches all 6 fields with a non-trivial scenario

- **AC-9** (GDD EC-14): Out-of-range elevation delta clamped + warning logged
  - Given: 2-tile fixture (atk elev=3, def elev=0 — delta=+3, beyond table); MapGrid normally enforces 0/1/2 elevation, but this test exercises the defensive clamp
  - When: `get_combat_modifiers`
  - Then: `clamped_delta == 2` is used (so atk_mod=+15, def_mod=-15); `push_warning` was called with a message matching "delta_elevation 3 clamped to ±2"
  - Edge cases: verify warning by checking warning count or capturing stderr; the clamp itself is the runtime contract — when MapGrid grows to support elevation 3, this clamp + warning is the breadcrumb forcing CR-2 table extension

- **AC-10**: Out-of-bounds atk OR def returns zero-fill
  - Given: 1×1 fixture; query with `atk_coord = Vector2i(0, 0)` (valid) but `def_coord = Vector2i(99, 99)` (OOB)
  - When: `get_combat_modifiers`
  - Then: returns zero-fill `CombatModifiers` (all int fields 0, bool false, special_rules empty)
  - Edge cases: same OOB pattern as story-004 AC-3; null grid also returns zero-fill (defensive)

- **AC-11**: Cap accessor uses runtime _max_defense_reduction (not the compile-time const)
  - Given: a tuned config with `caps.max_defense_reduction: 25` (lowered from 30); reset + load_config(test_path)
  - When: a high-defense scenario (FORTRESS_WALL + elev_def +15 = 40)
  - Then: `defender_terrain_def == 25` (clamped to the tuned runtime cap, not 30)
  - Edge cases: verifies AC-19 data-driven promise at the combat-modifier level + the runtime-vs-compile-time cap distinction in ADR-0008 §Decision 7

- **AC-12** (TR-011 cross-system contract verification): Returned values are opaque pre-clamped
  - Given: any combat scenario
  - When: `get_combat_modifiers`
  - Then: `defender_terrain_def` is in `[-_max_defense_reduction, +_max_defense_reduction]`; `defender_terrain_eva` is in `[0, _max_evasion]`; both invariants hold for ALL test cases above
  - Edge cases: this is the contract gate — Damage Calc treats these as opaque; if they ever fall outside the range, Damage Calc's downstream math breaks. Add this as a global invariant check that runs on every test fixture's output.

- **AC-13**: Defensive copy — caller mutation does not poison static state (parallel of story-004 AC-8)
  - Given: standard fixture; first `get_combat_modifiers` call returns `m1`; `m1.special_rules.append(&"caller_pollution")`
  - When: second `get_combat_modifiers` call to same coords
  - Then: second result's `special_rules` does NOT contain `&"caller_pollution"`; static `_terrain_table` not mutated
  - Edge cases: same discipline as story-004; verify here independently in case story-004 wasn't yet implemented (parallel-developable)

- **AC-14**: Lazy-init triggers load_config on first query
  - Given: `reset_for_tests` (so `_config_loaded == false`)
  - When: `get_combat_modifiers` called without prior `load_config`
  - Then: `_config_loaded == true` after; result returned correctly from canonical defaults
  - Edge cases: parallel of story-004 AC-9; all 3 query methods independently lazy-trigger

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/terrain_effect_combat_modifiers_test.gd` — must exist and pass (14 tests covering AC-1..14)
- Test fixture: programmatic 2-tile MapGrid construction helper for the terrain × elevation matrix; fixture MapResource patterns parallel to story-004's helper

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 003 (`_elevation_table` + `_terrain_table` + `_max_defense_reduction` + `_max_evasion` populated), Story 002 (lazy-init guard), Story 001 (`CombatModifiers` Resource class)
- Soft-depends on: Story 004 (defensive-copy pattern established; this story consumes the discipline)
- Unlocks: Damage Calc Feature epic (consumes `CombatModifiers` for damage formula F-DC-5; orchestrates Bridge FLANK→FRONT using ADR-0004 §5b ATK_DIR_* constants)
