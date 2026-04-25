# Epic: Terrain Effect System

> **Layer**: Core
> **GDD**: design/gdd/terrain-effect.md (Designed, 2026-04-16)
> **Architecture Module**: Terrain Effect (docs/architecture/architecture.md §Core layer line 252)
> **Status**: Ready
> **Manifest Version**: 2026-04-20 (docs/architecture/control-manifest.md)
> **Stories**: Not yet created — run `/create-stories terrain-effect`

## Overview

Terrain Effect is the Core-layer stateless rules calculator that converts `MapTileData.terrain_type` + `elevation` into combat-ready modifier values. It owns the 8-terrain × {`defense_bonus`, `evasion_bonus`, `special_rules`} table per CR-1 (PLAINS 0/0, HILLS 15/0, MOUNTAIN 20/5, FOREST 5/15, RIVER 0/0, BRIDGE 5/0+`bridge_no_flank`, FORTRESS_WALL 25/0, ROAD 0/0), the asymmetric elevation modifier table per CR-2 (delta ±1 → ±8%, ±2 → ±15%, sub-linear), the symmetric clamp `[-MAX_DEFENSE_REDUCTION, +MAX_DEFENSE_REDUCTION]` per F-1, and the shared cap constants `MAX_DEFENSE_REDUCTION = 30` / `MAX_EVASION = 30` consumed by Formation Bonus and Damage Calc as a single source of truth. Implementation is `class_name TerrainEffect extends RefCounted` with all-static methods, lazy-loaded config from `assets/data/terrain/terrain_config.json` (instance-form `JSON.new().parse()` for line/col diagnostics), and three public query methods: `get_terrain_modifiers(coord)` (raw uncapped, for HUD), `get_combat_modifiers(atk, def)` (clamped, for Damage Calc), `get_terrain_score(coord)` (0.0-1.0 elevation-agnostic, for AI). The Bridge FLANK→FRONT override (CR-5) is owned by Damage Calc as orchestrator using ADR-0004 §5b `ATK_DIR_*` constants — Map/Grid stays Foundation-pure. No caching for MVP; future `terrain_changed(coord)` signal addition requires formal ADR-0001 amendment.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0008: Terrain Effect System | `class_name TerrainEffect extends RefCounted` + all-static methods; JSON config at `assets/data/terrain/terrain_config.json` with schema validation + safe-default fallback; Bridge FLANK→FRONT via `bridge_no_flank` flag in `CombatModifiers` (Damage Calc orchestrates); cost_matrix structure shipped with MVP=1 placeholder pending ADR-0009 Unit Role; shared cap accessors `max_defense_reduction()` / `max_evasion()` for cross-system single-source-of-truth | **LOW** (no post-cutoff APIs; idiomatic Godot 4.6 — RefCounted+static, JSON.new().parse(), Dictionary, @export Resource, Vector2i, clampi) |
| ADR-0004: Map/Grid Data Model | Consumes `MapGrid.get_tile(coord) -> MapTileData` for `terrain_type` + `elevation`; ADR-0004 §5b Direction Constants (Erratum 2026-04-25) provides `ATK_DIR_FRONT/FLANK/REAR` + `FACING_NORTH/EAST/SOUTH/WEST` int constants used by Damage Calc when orchestrating CR-5 Bridge override | LOW (inherited; no new APIs) |
| ADR-0001: GameBus Autoload | Future `terrain_changed(coord: Vector2i)` signal emission deferred to caching impl per ADR-0008 §4; addition requires formal ADR-0001 amendment when caching lands (parallels ADR-0004 `tile_destroyed` Environment-domain precedent) | LOW (deferred) |

**Highest engine risk**: LOW

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-terrain-effect-001 | CR-1: 8 terrain types × {defense_bonus, evasion_bonus, special_rules} table per the values above | ADR-0008 ✅ |
| TR-terrain-effect-002 | CR-1d: Modifiers uniform across unit types for MVP; class differentiation handled by Map/Grid cost matrix | ADR-0008 ✅ |
| TR-terrain-effect-003 | CR-2: Asymmetric elevation modifiers (delta ±1 → ±8%, ±2 → ±15%, sub-linear) | ADR-0008 ✅ |
| TR-terrain-effect-004 | F-1: Symmetric clamp `[-MAX_DEFENSE_REDUCTION, +MAX_DEFENSE_REDUCTION]` for total_defense; negative defense allowed and amplifies damage | ADR-0008 ✅ |
| TR-terrain-effect-005 | CR-3a/b: `MAX_DEFENSE_REDUCTION = 30`, `MAX_EVASION = 30`; cap-display `[MAX]` (CR-3c) | ADR-0008 ✅ |
| TR-terrain-effect-006 | CR-3d: Min damage = 1 — Damage Calc enforces; Terrain Effect supplies modifier only | ADR-0008 ✅ (delegated) |
| TR-terrain-effect-007 | CR-3e + EC-1: Symmetric clamp authoritative for negative defense | ADR-0008 ✅ |
| TR-terrain-effect-008 | CR-4: 3 query methods — `get_terrain_modifiers`, `get_combat_modifiers`, `get_terrain_score` | ADR-0008 ✅ |
| TR-terrain-effect-009 | CR-5: Bridge FLANK→FRONT via `bridge_no_flank` flag; Damage Calc orchestrates with ADR-0004 §5b `ATK_DIR_*` constants | ADR-0008 + ADR-0004 §5b ✅ |
| TR-terrain-effect-010 | Stateless RefCounted+static; lazy-init; `reset_for_tests()` discipline for GdUnit4 isolation | ADR-0008 ✅ |
| TR-terrain-effect-011 | Cross-system contract (damage-calc.md §F): opaque clamped `terrain_def ∈ [-30, +30]` / `terrain_evasion ∈ [0, 30]` | ADR-0008 ✅ |
| TR-terrain-effect-012 | Config at `assets/data/terrain/terrain_config.json`; FileAccess + `JSON.new().parse()` instance form | ADR-0008 ✅ |
| TR-terrain-effect-013 | AC-21: `get_combat_modifiers()` <0.1ms per call (mid-range Android, 100 calls/frame budget) | ADR-0008 ✅ |
| TR-terrain-effect-014 | AC-19/20: Schema validation + safe-default fallback; fractional-value rejection via `value != int(value)` | ADR-0008 ✅ |
| TR-terrain-effect-015 | EC-14: Elevation delta clamped to `[-2, +2]` before table lookup | ADR-0008 ✅ |
| TR-terrain-effect-016 | AC-14: OOB coord → zero modifiers; no error path | ADR-0008 ✅ |
| TR-terrain-effect-017 | Shared cap accessor `max_defense_reduction()` / `max_evasion()` — single source of truth for Formation Bonus + Damage Calc | ADR-0008 ✅ |
| TR-terrain-effect-018 | `cost_multiplier(unit_type, terrain_type)` matrix structure; MVP=1 uniform; replaces `terrain_cost.gd:32` placeholder | ADR-0008 ✅ |

**Untraced Requirements**: None.

## Scope

**Implements**:
- `src/core/terrain_modifiers.gd` — typed `TerrainModifiers extends Resource` with `@export` fields (`defense_bonus: int`, `evasion_bonus: int`, `special_rules: Array[StringName]`)
- `src/core/combat_modifiers.gd` — typed `CombatModifiers extends Resource` with `@export` fields (`defender_terrain_def: int`, `defender_terrain_eva: int`, `elevation_atk_mod: int`, `elevation_def_mod: int`, `bridge_no_flank: bool`, `special_rules: Array[StringName]`)
- `src/core/terrain_effect.gd` — `class_name TerrainEffect extends RefCounted` with all-static query/lifecycle methods, lazy-init config guard, terrain-type integer constants (PLAINS=0..ROAD=7), `reset_for_tests()` seam
- `assets/data/terrain/terrain_config.json` — config with `schema_version`, `terrain_modifiers` (8 entries), `elevation_modifiers` (5 entries delta -2..+2), `caps`, `ai_scoring`, `cost_matrix.default_multiplier=1`
- `src/core/terrain_cost.gd:32` migration — placeholder `cost_multiplier()` becomes a delegate to `TerrainEffect.cost_multiplier(unit_type, terrain_type)`
- `tests/unit/core/terrain_effect_test.gd` — 18 ACs across CR-1..CR-5 + EC-1..EC-14 + cross-suite static-state isolation regression test
- `tests/integration/core/terrain_effect_perf_test.gd` — AC-21 <0.1ms benchmark on desktop substitute (mobile validation deferred to Polish per save-manager/story-007 + map-grid/story-007 precedent)

**Does not implement**:
- `terrain_changed(coord)` GameBus signal — deferred to caching implementation per ADR-0008 §4; addition requires formal ADR-0001 amendment
- Caching layer — none for MVP; AC-21 budget achieved via O(1) Dictionary lookups on packed-cache-backed `MapGrid.get_tile`
- Per-unit-class cost_matrix values — ADR-0009 Unit Role populates; MVP ships with uniform `default_multiplier = 1` per CR-1d
- Bridge FLANK→FRONT direction collapse — owned by Damage Calc orchestrator; this epic only sets the `bridge_no_flank` flag in `CombatModifiers`
- Min damage = 1 enforcement — owned by Damage Calc per cross-system contract (CR-3d)
- Evasion roll execution — owned by Damage Calc per F-DC-2 / OQ-DC-1 resolution (damage-calc.md §F ratified 2026-04-18)
- HUD tile tooltip rendering — Battle HUD epic consumes `get_terrain_modifiers()` for display
- AI tile-ranking weights — AI epic consumes `get_terrain_score()` and applies its own unit-type weighting

## Dependencies

**Depends on (must be Accepted before stories can start)**:
- ADR-0001 (GameBus) ✅ Accepted 2026-04-18 — terrain_changed signal deferred
- ADR-0004 (Map/Grid) ✅ Accepted 2026-04-20 (+ §5b erratum 2026-04-25) — `MapGrid.get_tile(coord)`, `ATK_DIR_*` constants
- ADR-0008 (this epic's governing ADR) ✅ Accepted 2026-04-25

**Soft-dependency (can ship without; documented in ADR-0008 §Migration Plan as API-stable)**:
- ADR-0006 Balance/Data (NOT YET WRITTEN) — config-loading pipeline. MVP uses direct `FileAccess.get_file_as_string()` + `JSON.new().parse()`; migration to Balance/Data pipeline is internals-only (`_load_config_via_balance_data()` swap), public API unchanged.
- ADR-0009 Unit Role (NOT YET WRITTEN) — populates cost_matrix unit-class dimension. MVP ships with `default_multiplier = 1` per CR-1d "modifiers uniform across unit types for MVP"; ADR-0009 populates the 5×8 matrix later without changing the public API.

**Enables** (unblocks implementation of):
- Damage Calc Feature epic (consumes `get_combat_modifiers()` for terrain_def/terrain_evasion + orchestrates Bridge FLANK override using ADR-0004 §5b constants)
- AI Feature epic (consumes `get_terrain_score()` for tile ranking)
- Formation Bonus Feature epic (consumes `max_defense_reduction()` shared cap accessor)
- Battle HUD Presentation epic (consumes `get_terrain_modifiers()` for tile tooltip display)
- Map/Grid Dijkstra cost values (replaces `terrain_cost.gd:32` placeholder via story-7 of this epic)

## Implementation Decisions Deferred (from ADR-0008 + control-manifest)

- **JSON parse error diagnostics**: ADR-0008 Notes §2 firm-recommends `JSON.new().parse(text)` + `get_error_message()` instance form over `JSON.parse_string()` static form for line/col diagnostics. Resolution: locked at `/dev-story` for the load-config story; no runtime decision.
- **Defensive copy on Resource return**: `get_terrain_modifiers()` and `get_combat_modifiers()` return new Resource instances each call (~5-10µs alloc). Resolution: ADR-0008 Notes §5 documents this as canonical; no decision needed at implementation.
- **`reset_for_tests()` discipline scope**: ADR-0008 mandates `reset_for_tests()` in `before_each()` for ALL test suites that call any `TerrainEffect` method (not just suites loading custom configs). Resolution: enforced via `terrain_effect_test.gd` header doc + multi-suite isolation regression test (will be a story-level AC).
- **AC-PERF Android target**: AC-21 budget is mid-range Android. Following save-manager/story-007 + map-grid/story-007 precedent, this epic's perf story validates desktop substitute (<0.1ms achievable in a fraction of the budget); on-device Android validation deferred to Polish phase.

## Cross-System Consumer Contracts (from ADR-0008 + GDDs)

These are consumer-side rules other epics must honor. This epic implements only the producer side.

- **Damage Calc**: subscribe-style contract — call `TerrainEffect.get_combat_modifiers(atk, def)`, then read `bridge_no_flank` flag. If flag is true AND raw `MapGrid.get_attack_direction()` returned `ATK_DIR_FLANK`, treat as `ATK_DIR_FRONT` for damage calculation (Bridge FLANK override per ADR-0008 §Decision 3).
- **Formation Bonus**: call `TerrainEffect.max_defense_reduction()` / `max_evasion()` for shared cap value; never hardcode `30`.
- **AI**: call `TerrainEffect.get_terrain_score(coord)` for elevation-agnostic tile quality; combine with `get_combat_modifiers(atk, def)` for elevation-aware positional evaluation per EC-5.
- **Battle HUD**: call `TerrainEffect.get_terrain_modifiers(coord)` for raw uncapped values + `[MAX]` indicator rendering when stacked-and-capped exceeds runtime cap (CR-3c, EC-12).
- **Map/Grid (consumer)**: `terrain_cost.gd:32` delegates to `TerrainEffect.cost_multiplier(unit_type, terrain_type)` post-this-epic; ships with `1` for all pairs until ADR-0009 lands.

These contracts are enforced at the consumer epic — this epic implements only the producer side.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All 21 acceptance criteria from `design/gdd/terrain-effect.md` (AC-1..AC-21) are verified via tests or evidence docs
- AC-21 perf: `get_combat_modifiers()` <0.1ms per call on desktop substitute (mobile on-device deferred to Polish)
- AC-19 + AC-20: Config schema validation passes (8 terrain types, 5 elevation deltas, fractional-value rejection, modifier ranges sane); corrupt config triggers `push_error` + safe-default fallback without crash
- Multi-suite static-state isolation regression test passes (Suite A custom-config + Suite B default-config sequence)
- `terrain_cost.gd:32` placeholder migrated to `TerrainEffect.cost_multiplier()` delegation; full Map/Grid regression suite (231/231) still passes unchanged
- `tests/unit/core/terrain_effect_test.gd` exercises all 18 TR-IDs; regression suite remains 0 errors / 0 failures / 0 orphans / GODOT EXIT 0
- ADR-0008's 1 KEEP-through-implementation Verification Required item validated (AC-21 benchmark); §2/§3 already CLOSED in ADR; §4 (ADR-0004 §5b alignment) auto-satisfied since story-006 of map-grid epic must implement the §5b signature/constants
- terrain-effect.md OQ-7 close-as-resolved is applied to the GDD (one-line edit; flagged in 2026-04-25 architecture-review)

## Stories

Not yet created — run `/create-stories terrain-effect` to generate the story breakdown.

**Anticipated decomposition** (preview only — final breakdown locked at `/create-stories`):

| # (anticipated) | Story | Type | Covers |
|---|-------|------|--------|
| 001 | TerrainModifiers + CombatModifiers Resource classes | Logic | TR-001 (TerrainModifiers schema), CR-5 flag on CombatModifiers |
| 002 | TerrainEffect skeleton — class_name + static state + lazy-init guard + reset_for_tests | Logic | TR-010 |
| 003 | Config JSON authoring + load_config (FileAccess + JSON.new().parse instance form) + schema validation + safe-default fallback | Config/Data + Logic | TR-012, TR-014 (AC-19/20) |
| 004 | get_terrain_modifiers + get_terrain_score (CR-1, F-3) | Logic | TR-001, TR-008 (1/3), TR-016 (AC-14 OOB), CR-1d |
| 005 | get_combat_modifiers (CR-2 elevation table + CR-3a/b symmetric clamp + CR-5 bridge flag + EC-14 delta clamp) | Logic | TR-003, TR-004, TR-005, TR-007, TR-008 (2/3), TR-009, TR-011, TR-015 |
| 006 | cost_multiplier + terrain_cost.gd:32 migration + Map/Grid regression | Integration | TR-018, TR-002 (cost_matrix MVP=1 uniform) |
| 007 | max_defense_reduction + max_evasion shared accessors + multi-suite static-state isolation regression test | Logic | TR-017, TR-010 (isolation discipline) |
| 008 | Performance baseline (desktop substitute) — AC-21 <0.1ms benchmark | Integration | TR-013 (AC-21) |

Probably 7-9 stories; `/create-stories terrain-effect` will lock the final count.

## Next Step

Run `/create-stories terrain-effect` to break this epic into implementable stories.
