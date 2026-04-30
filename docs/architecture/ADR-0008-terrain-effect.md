# ADR-0008: Terrain Effect System

## Status
Accepted (2026-04-25, via `/architecture-review` delta)

## Date
2026-04-25

## Last Verified
2026-04-25

## Decision Makers
- Technical Director (architecture owner)
- User (final approval, 2026-04-25)
- godot-specialist (engine validation, 2026-04-25 — APPROVED WITH SUGGESTIONS, all suggestions applied this pass)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core — gameplay rules calculator |
| **Knowledge Risk** | LOW — no post-cutoff APIs. `Dictionary[K, V]`, `JSON.parse_string`, `FileAccess.get_file_as_string`, `Vector2i`, GameBus signal pattern, typed `Resource` with `@export` are all pre-cutoff and stable. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/current-best-practices.md`, `design/gdd/terrain-effect.md`, `design/gdd/map-grid.md`, `design/gdd/damage-calc.md`, `design/gdd/formation-bonus.md`, `docs/architecture/ADR-0001-gamebus-autoload.md`, `docs/architecture/ADR-0004-map-grid-data-model.md`, `docs/architecture/architecture.md` §Core layer (line 252) |
| **Post-Cutoff APIs Used** | None. All APIs in this ADR's Decision section are pre-Godot-4.4 and stable across the project's pinned 4.6 baseline. |
| **Verification Required** | (1) Benchmark `get_combat_modifiers()` per-call latency on mid-range Android target: must be <0.1ms (AC-21 of `terrain-effect.md`). KEEP through implementation. (2) ~~JSON integer/float coercion~~ — **CLOSED 2026-04-25**: confirmed Godot 4.6 `JSON.parse_string` returns all numbers as `float`; `_validate_config()` rejects fractional values via `value != int(value)` guard (Notes §2). (3) ~~`class_name TerrainEffect` collision~~ — **CLOSED 2026-04-25**: no Godot 4.6 built-in by this name; `TerrainModifiers` and `CombatModifiers` also collision-free. (4) Confirm ADR-0004 §5b constants and 3-arg `get_attack_direction` signature match the eventual story-006 implementation; if drift occurs, treat as ADR-0004 follow-up amendment, not ADR-0008 revision. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (GameBus, Accepted 2026-04-18) — `terrain_changed(coord: Vector2i)` signal emission; subscription to `tile_destroyed(coord)` if caching is later added. ADR-0004 (Map/Grid, Accepted 2026-04-20) — calls `MapGrid.get_tile(coord)` for `terrain_type` + `elevation`. |
| **Enables** | terrain-effect epic creation (`/create-epics layer: core` re-run after this ADR is Accepted); replaces story-005's `cost_multiplier(_unit_type, _terrain_type) -> int` placeholder in `src/core/terrain_cost.gd:32` (currently returns `1` for all pairs); unblocks Damage Calc ADR (consumer of `get_combat_modifiers`); unblocks AI ADR (consumer of `get_terrain_score`); unblocks Formation Bonus shared-cap contract (`MAX_DEFENSE_REDUCTION = 30` is owned here). |
| **Blocks** | terrain-effect epic implementation; Damage Calc Feature-layer epic; AI Feature-layer epic; Battle HUD tile tooltip implementation. None of these can begin implementation until this ADR is Accepted. |
| **Ordering Note** | Soft-dependency on ADR-0006 (Balance/Data, **Accepted 2026-04-30 via /architecture-review delta #9**) **RATIFIED**. ADR-0006 §Decision 2 locked `BalanceConstants.get_const(key)` as the canonical accessor; ADR-0006 §Decision 4 ratified the flat-JSON pattern (no `{schema_version, category, data}` envelope for MVP). The TerrainConfig `_load_config()` direct-loading pattern shipped in this ADR is forward-compatible with the future Alpha-pipeline DataRegistry rename per ADR-0006 §Migration Path Forward — call-site `get_const(key) -> Variant` shape stable across migration. No ADR-0008 amendment required. |

## Context

### Problem Statement

`design/gdd/terrain-effect.md` (Designed 2026-04-16) defines the Terrain Effect System as MVP system #2 in the Core layer. The GDD specifies 5 Core Rules (CR-1..CR-5), 14 Edge Cases (EC-1..EC-14), 3 query methods, and 21 acceptance criteria. The architecture cannot proceed without locking 5 questions:

1. **Module type** — autoload Node? Battle-scoped Node? Stateless static utility class? GDD §States and Transitions explicitly states "stateless... pure query layer" — but says nothing about implementation form.
2. **Config schema and loading** — GDD line 583 specifies `assets/data/terrain/terrain_config.json` as the config file. The schema is implicit in CR-1..CR-5; the loading mechanism is undefined and overlaps with Balance/Data (#26, ADR-0006 — was NOT YET WRITTEN at ADR-0008 authoring 2026-04-25; **Accepted 2026-04-30 via delta #9** ratifying this Direct-loading pattern as forward-compatible).
3. **Bridge FLANK override location** — GDD CR-5 + line 263-266 defers to ADR: where does the FLANK→FRONT decoration of `MapGrid.get_attack_direction` happen — in Terrain Effect, in Damage Calc, or in Map/Grid itself?
4. **Caching strategy** — GDD §States and Transitions §Exception clause says "If performance requires caching..." — under what conditions, and how is invalidation wired?
5. **Terrain Cost Matrix scope** — `src/core/terrain_cost.gd:32` ships with a placeholder `cost_multiplier(_unit_type, _terrain_type) -> int: return 1` and an inline comment "REPLACED WHEN ADR-0008 Terrain Effect lands". The unit-type × terrain-type cost matrix used by Map/Grid Dijkstra is partly Terrain Effect's domain (terrain side), partly Unit Role's domain (unit-class side). This ADR must define the matrix structure even if it ships with placeholder values pending ADR-0009 Unit Role.

The ADR must also satisfy the cross-system contract ratified by `damage-calc.md` §F (2026-04-18): `terrain_def` is an opaque signed integer ∈ [−30, +30] already clamped per `MAX_DEFENSE_REDUCTION`; `terrain_evasion` is an opaque integer ∈ [0, 30] already clamped per `MAX_EVASION`. Damage Calc owns the evasion roll (F-DC-2, OQ-DC-1 resolution). The cap constants `MAX_DEFENSE_REDUCTION = 30` and `MAX_EVASION = 30` are explicitly owned by this system per GDD line 267-271 ("This system defines... Damage Calc enforces the clamp. The cap values live in `assets/data/terrain/terrain_config.json` (this system's config), not in Damage Calc's config.").

### Constraints

**From `design/gdd/terrain-effect.md` (locked by systems-designer + game-designer + ai-programmer):**

- **CR-1**: 8 terrain types × 2 modifier values (`defense_bonus`, `evasion_bonus`) + special rules. Values per CR-1 table: PLAINS 0/0, HILLS 15/0, MOUNTAIN 20/5, FOREST 5/15, RIVER 0/0, BRIDGE 5/0 (`bridge_no_flank` special), FORTRESS_WALL 25/0, ROAD 0/0.
- **CR-1d**: Modifiers uniform across unit types for MVP (no class-specific terrain bonuses). Class differentiation handled by Map/Grid movement costs.
- **CR-2**: Elevation modifiers asymmetric (attacker bonus + defender penalty) at delta = ±1 → ±8%, delta = ±2 → ±15%. Sub-linear.
- **CR-3a**: `MAX_DEFENSE_REDUCTION = 30` (additive cap). Symmetric clamp [−30, +30] per F-1.
- **CR-3b**: `MAX_EVASION = 30` (additive cap).
- **CR-3d**: Minimum damage = 1 (defense alone never zeroes attacks).
- **CR-3e + EC-1**: Negative defense allowed (PLAINS + attacker-above scenarios). Symmetric clamp authoritative.
- **CR-4**: 3 public query methods — `get_terrain_modifiers(coord) -> TerrainModifiers`, `get_combat_modifiers(atk, def) -> CombatModifiers`, `get_terrain_score(coord) -> float`.
- **CR-5**: BRIDGE tiles convert FLANK → FRONT for the **defender** (CR-5b). REAR remains REAR (CR-5c). `bridge_no_flank` is a `special_rule` flag returned by `get_terrain_modifiers()`.
- **AC-21**: `get_combat_modifiers()` <0.1ms per call (budget: 100 calls per frame at 60fps).
- **GDD line 583**: Config at `assets/data/terrain/terrain_config.json`, owned by this system.

**From `design/gdd/damage-calc.md` (cross-system contract ratified 2026-04-18):**

- `terrain_def` is opaque signed integer ∈ [−30, +30] **already clamped** by Terrain Effect.
- `terrain_evasion` is opaque integer ∈ [0, 30] **already clamped** by Terrain Effect.
- Damage Calc owns the evasion roll; Terrain Effect provides the rate only.

**From `design/gdd/formation-bonus.md` (cross-system contract):**

- Formation defense stacks with terrain defense **under the shared cap** `MAX_DEFENSE_REDUCTION = 30`.
- Per-unit cap `0.05` (formation_def_bonus per unit) and `P_MULT_COMBINED_CAP = 1.31` are owned by Formation Bonus / Damage Calc, NOT this system.

**From `design/gdd/map-grid.md` and ADR-0004:**

- `MapGrid.get_tile(coord: Vector2i) -> MapTileData` is the canonical query for `terrain_type` (int enum mirror) + `elevation` (int 0/1/2).
- `MapGrid.get_attack_direction(attacker, defender, defender_facing) -> int` returns `ATK_DIR_FRONT/FLANK/REAR`. ADR-0008 may decorate this output for BRIDGE tiles via the `bridge_no_flank` flag.
- ADR-0004 line 33 explicitly enables ADR-0008: "ADR-0008 Terrain Effect (consumes `MapTileData.terrain_type` + terrain-cost matrix contract)".
- Map/Grid emits `tile_destroyed(coord)` on GameBus; Terrain Effect MAY subscribe if caching is added (deferred for MVP).

**From `.claude/docs/technical-preferences.md`:**

- GDScript with static typing mandatory.
- Mobile performance budgets: 512 MB memory ceiling, 60fps / 16.6 ms frame budget.
- Test coverage floor: 100% for balance formulas (terrain modifier formulas included), 80% for gameplay systems.
- Naming conventions: PascalCase classes, snake_case variables, snake_case past-tense signals.

**From `docs/architecture/architecture.md` §Core layer (line 252):**

- Module Ownership pre-defined: "Stateless per-unit — pure rules calculator indexed by tile coord."
- Exposes: `get_terrain_modifiers(coord) -> TerrainModifiers`, `get_terrain_score(coord) -> float` (AI use, elevation-agnostic), emits `terrain_changed(coord)` via GameBus.
- Consumes: Map/Grid (`get_tile(coord)`), Balance/Data (`terrain/terrain_config.json` at init), GameBus subscription to `tile_destroyed(coord)`.
- Engine APIs used: `Resource` + `@export` for `TerrainModifiers`, `Vector2i`, `Dictionary` keyed by terrain enum. **LOW risk.**
- Layer-invariant verification (architecture.md line 262-268): "Terrain Effect → Map/Grid (Foundation ✅)" — clean downward dependency.

### Requirements

**Functional**:

- Provide `get_terrain_modifiers(coord: Vector2i) -> TerrainModifiers` returning raw (uncapped) values for HUD display (per EC-12).
- Provide `get_combat_modifiers(attacker_coord, defender_coord) -> CombatModifiers` returning clamped values for combat resolution (per CR-3a, CR-3b, F-1).
- Provide `get_terrain_score(coord: Vector2i) -> float` returning normalized 0.0-1.0 score for AI positioning (per F-3).
- Emit `GameBus.terrain_changed(coord: Vector2i)` when `tile_destroyed(coord)` is observed AND the destruction changes the tile's effective `terrain_type` (e.g., FOREST destroyed → PLAINS).
- Define the terrain-cost matrix structure (per-unit-type × per-terrain-type integer multiplier) used by Map/Grid Dijkstra, even if MVP values are uniform `1`.
- Load configuration from `assets/data/terrain/terrain_config.json` at game start; validate schema; fall back to safe defaults on error (per AC-20).

**Non-functional**:

- `get_combat_modifiers()` <0.1 ms per call (AC-21).
- Stateless: no per-battle initialization; no per-battle state; no per-battle teardown.
- Thread-safe for read access (current Godot main-thread model is single-threaded for game logic, but the ADR documents the constraint for future-proofing).
- Idempotent: identical inputs always produce identical outputs (no random sampling; evasion roll is Damage Calc's responsibility).

## Decision

### 1. Module Type — Stateless Static Utility Class

**Decision**: Implement Terrain Effect as `class_name TerrainEffect extends RefCounted` with all methods declared `static`. Configuration is stored in static class-scope variables loaded once at first access (lazy initialization with idempotent guard).

```gdscript
class_name TerrainEffect
extends RefCounted

static var _config_loaded: bool = false
static var _terrain_table: Dictionary = {}     # int (terrain_type) -> TerrainEntry Resource
static var _elevation_table: Dictionary = {}   # int (delta_elevation, -2..+2) -> ElevationEntry Resource
static var _max_defense_reduction: int = 30    # MVP default; overridable by config
static var _max_evasion: int = 30              # MVP default; overridable by config
static var _evasion_weight: float = 1.2        # MVP default; AI scoring per F-3
static var _max_possible_score: float = 43.0   # MVP default; F-3 normalisation constant
static var _cost_matrix: Dictionary = {}       # Dictionary[int (unit_type), Dictionary[int (terrain_type), int]]
```

**Rationale**:
- GDD §States and Transitions explicitly states: "The Terrain Effect System is **stateless**. It is a pure query layer."
- No per-battle state means no per-battle init cost (architecture.md line 252 confirms).
- A `class_name X extends RefCounted` with static methods is the canonical Godot 4.6 idiom for a stateless utility module — no Node lifecycle, no scene tree dependency, callable from anywhere via `TerrainEffect.method(...)`.
- Lazy initialization (load on first access) keeps unit tests fast: tests that don't query terrain don't pay the load cost. Idempotent guard (`_config_loaded` flag) prevents re-load on subsequent test cases within the same gdunit4 session.
- Static methods avoid the autoload-vs-instance ambiguity: callers never have to ask "where do I get the TerrainEffect instance?" — the answer is always `TerrainEffect.method(...)`.

**Forbidden patterns**:
- ❌ NO autoload registration. `/root/TerrainEffect` would imply a Node lifecycle that doesn't exist; static state is sufficient and avoids G-3 (autoload + class_name collision).
- ❌ NO instance methods. Anything that needs per-instance state belongs in a different module.
- ❌ NO `_ready()` / `_init()` Node-lifecycle hooks. Static utility classes do not have these.

### 2. Configuration Format — JSON at `assets/data/terrain/terrain_config.json`

**Decision**: Load configuration from a single JSON file at `assets/data/terrain/terrain_config.json` using `FileAccess.get_file_as_string()` + `JSON.parse_string()`. The file is owned by Terrain Effect and follows the schema below. **No** typed Resource (`.tres`) for MVP — this is a deliberate divergence from ADR-0003 / ADR-0004 patterns, justified by GDD line 583 specifying JSON and the design-tuning workflow benefit (designers edit JSON without launching Godot editor).

**Schema** (`assets/data/terrain/terrain_config.json`):

```json
{
  "schema_version": 1,
  "terrain_modifiers": {
    "0":  { "name": "PLAINS",        "defense_bonus": 0,  "evasion_bonus": 0,  "special_rules": [] },
    "1":  { "name": "FOREST",        "defense_bonus": 5,  "evasion_bonus": 15, "special_rules": [] },
    "2":  { "name": "HILLS",         "defense_bonus": 15, "evasion_bonus": 0,  "special_rules": [] },
    "3":  { "name": "MOUNTAIN",      "defense_bonus": 20, "evasion_bonus": 5,  "special_rules": [] },
    "4":  { "name": "RIVER",         "defense_bonus": 0,  "evasion_bonus": 0,  "special_rules": [] },
    "5":  { "name": "BRIDGE",        "defense_bonus": 5,  "evasion_bonus": 0,  "special_rules": ["bridge_no_flank"] },
    "6":  { "name": "FORTRESS_WALL", "defense_bonus": 25, "evasion_bonus": 0,  "special_rules": [] },
    "7":  { "name": "ROAD",          "defense_bonus": 0,  "evasion_bonus": 0,  "special_rules": [] }
  },
  "elevation_modifiers": {
    "-2": { "attack_mod": -15, "defense_mod": 15 },
    "-1": { "attack_mod": -8,  "defense_mod": 8 },
    "0":  { "attack_mod": 0,   "defense_mod": 0 },
    "1":  { "attack_mod": 8,   "defense_mod": -8 },
    "2":  { "attack_mod": 15,  "defense_mod": -15 }
  },
  "caps": {
    "max_defense_reduction": 30,
    "max_evasion": 30
  },
  "ai_scoring": {
    "evasion_weight": 1.2,
    "max_possible_score": 43.0
  },
  "cost_matrix": {
    "_comment": "MVP placeholder — uniform 1× multiplier pending ADR-0009 Unit Role. Schema: unit_type (int) → terrain_type (int) → multiplier (int).",
    "default_multiplier": 1
  }
}
```

**Terrain-type integer ordering**: Matches `MapGrid.ELEVATION_RANGES` ordering (PLAINS=0, FOREST=1, HILLS=2, MOUNTAIN=3, RIVER=4, BRIDGE=5, FORTRESS_WALL=6, ROAD=7) per TD-032 A-16 reconciliation. **Errata note**: GDD `terrain-effect.md` CR-1 table column order is alphabetical (HILLS / MOUNTAIN / FOREST etc.) for readability; the integer ordering in JSON (and in `src/core/terrain_cost.gd`) follows the canonical `MapGrid` ordering. The two are consistent because the JSON keys are string-typed integer mirrors.

**Validation on load** (per AC-20):
- `schema_version` must be `1`.
- All 8 terrain types must be present.
- All 5 elevation deltas (−2 to +2) must be present.
- `defense_bonus`, `evasion_bonus` must be non-negative integers ≤ 50 (sanity bound, not the runtime cap).
- `attack_mod`, `defense_mod` must be integers in [−25, +25].
- `caps.max_defense_reduction`, `caps.max_evasion` must be positive integers ≤ 50.
- `ai_scoring.evasion_weight` must be a finite float in (0, 5].
- `cost_matrix.default_multiplier` must be a positive integer.
- On any validation failure: `push_error(...)` + fall back to **MVP defaults** (CR-1 table values + caps 30/30 + EVASION_WEIGHT 1.2). Do NOT crash — the game must remain playable even with a corrupt config (per AC-20 spirit + Pillar 1 "battlefield always readable").

**Why JSON, not typed Resource (`.tres`)**:
- ✅ GDD line 583 explicitly specifies JSON.
- ✅ Designer workflow: edit values in any text editor; no Godot editor restart needed; hot-reload-friendly via dev console (post-MVP).
- ✅ Smaller diff footprint in version control (no Godot serialization noise).
- ✅ Cross-tool readable (Python data validators, balance spreadsheets).
- ⚠️ Loses Godot's typed-Resource integration (no inspector editing, no autocomplete in code references). Acceptable because the schema is small (8 terrain types) and stable.
- ✅ ADR-0006 Balance/Data ratified JSON for MVP (Accepted 2026-04-30 via delta #9 — §Decision 2 locked `BalanceConstants.get_const(key)` accessor backed by flat JSON; Alternative C `.tres` was REJECTED). No ADR-0008 amendment required; the JSON pipeline strategy is now project-wide standard.

**Migration to ADR-0006 Balance/Data pipeline** — **RESOLVED 2026-04-30 via delta #9 Acceptance of ADR-0006**:
- ADR-0006 ratified flat-JSON + `BalanceConstants.get_const(key)` as the MVP pattern. The TerrainConfig direct-loading helper is forward-compatible.
- Future Alpha-pipeline migration trigger is a separate Alpha-tier "DataRegistry Pipeline" ADR (no calendar commitment per ADR-0006 §Migration Path Forward) — NOT ADR-0006 itself.
- The schema, the `class_name TerrainEffect` interface, and the public method signatures DO NOT change at the future migration; only the internal `_load_config_direct()` helper would switch.

### 3. Bridge FLANK Override — Damage Calc Orchestrator Pattern via Flag

**Decision**: Terrain Effect does NOT decorate `MapGrid.get_attack_direction()`. Instead, `get_combat_modifiers()` returns a `bridge_no_flank: bool` flag in the `CombatModifiers` Resource. **Damage Calc orchestrates** the FLANK→FRONT collapse by:
1. Calling `MapGrid.get_attack_direction(attacker, defender, defender_facing)` to get raw direction.
2. Calling `TerrainEffect.get_combat_modifiers(attacker, defender)` to get the modifier set.
3. If `combat_mods.bridge_no_flank == true` AND raw direction is `ATK_DIR_FLANK`, treat as `ATK_DIR_FRONT` for damage calculation.

```gdscript
# In Damage Calc (Feature layer; future ADR):
var raw_dir: int = grid.get_attack_direction(atk, def, def_facing)
var combat_mods: CombatModifiers = TerrainEffect.get_combat_modifiers(atk, def)

var effective_dir: int = raw_dir
if combat_mods.bridge_no_flank and raw_dir == MapGrid.ATK_DIR_FLANK:
    effective_dir = MapGrid.ATK_DIR_FRONT
```

**Rationale**:
- ✅ Map/Grid stays pure (Foundation layer; no terrain awareness — keeps the layer-invariant clean).
- ✅ Damage Calc is the natural orchestrator (already coordinates terrain + formation + class + equipment per F-DC-5).
- ✅ Single source of truth for direction logic: Damage Calc + the CR-5b override rule documented in Damage Calc's eventual ADR.
- ❌ Rejected alternative (a) — Terrain Effect wraps `MapGrid.get_attack_direction`: requires Terrain Effect to import Map/Grid concepts (`def_facing`, direction enum), inflating its surface area beyond "stateless modifier query".
- ❌ Rejected alternative (c) — Map/Grid takes a `terrain_modifiers` parameter: violates Foundation-layer purity; Map/Grid would need to know about terrain effect concepts to honor the override.

### 4. Caching Strategy — None for MVP

**Decision**: No caching for MVP. Every `get_terrain_modifiers(coord)` call executes a fresh `MapGrid.get_tile(coord)` lookup + Dictionary table lookup. This is O(1) at the dict-lookup level + O(1) at the Map/Grid packed-cache level (per ADR-0004 §Decision 2).

**Rationale**:
- AC-21 budget is <0.1 ms per call (100 calls per frame at 60 fps). On packed-cache reads, expect <0.01 ms per call — 10× headroom. Caching adds complexity for marginal benefit.
- If profiling later shows hot-path significance, add a per-battle cache invalidated on `GameBus.tile_destroyed(coord)`. Cache is a `Dictionary[Vector2i, TerrainModifiers]` keyed by coord; size bounded by 40×30 = 1200 entries max.

**Future caching design (deferred)**:
```gdscript
# Pseudocode — NOT in MVP scope.
static var _modifier_cache: Dictionary = {}  # Vector2i -> TerrainModifiers

static func _on_tile_destroyed(coord: Vector2i) -> void:
    _modifier_cache.erase(coord)
    # Re-emit terrain_changed if the terrain_type actually changed (FOREST → PLAINS, etc.)
    # Per CR-1 table, currently only FORTRESS_WALL destruction changes terrain_type.
    GameBus.terrain_changed.emit(coord)
```

**ADR-0001 amendment requirement**: When the future-caching implementation lands, adding `terrain_changed(coord: Vector2i)` to GameBus's signal contract requires a formal ADR-0001 amendment (analogous to the Environment domain banner amendment landed concurrently with ADR-0004 for `tile_destroyed`). Do NOT add the signal informally; the amendment is the gate.

### 5. Public API Surface

```gdscript
class_name TerrainEffect
extends RefCounted

# ─── Public Query API ──────────────────────────────────────────

## Returns raw (uncapped) terrain modifiers for HUD display.
## Per EC-12: caller-side display logic shows raw values + [MAX] indicator
## when stacked-and-capped exceeds the runtime cap.
##
## Reads MapGrid.get_tile(coord).terrain_type; returns zeroes if Map/Grid is
## not loaded or coord is out-of-bounds.
static func get_terrain_modifiers(grid: MapGrid, coord: Vector2i) -> TerrainModifiers

## Returns clamped combat modifiers for damage calculation.
## Per CR-3a: total_defense clamped to [-MAX_DEFENSE_REDUCTION, +MAX_DEFENSE_REDUCTION].
## Per CR-3b: terrain_evasion clamped to [0, MAX_EVASION].
## Per CR-5: bridge_no_flank flag set if defender is on a BRIDGE tile.
static func get_combat_modifiers(grid: MapGrid, attacker_coord: Vector2i,
                                  defender_coord: Vector2i) -> CombatModifiers

## Returns AI tile-scoring value in [0.0, 1.0] per F-3.
## Elevation-agnostic (EC-5): returns the tile's intrinsic terrain quality
## without considering the unit currently standing on it or any specific threat.
## AI applies its own unit-type weighting on top of this score.
static func get_terrain_score(grid: MapGrid, coord: Vector2i) -> float

## Returns the unit-type × terrain-type cost multiplier for Map/Grid Dijkstra.
## MVP: returns 1 for all (unit_type, terrain_type) pairs; populated by ADR-0009.
## Map/Grid's `terrain_cost.gd:32` placeholder calls this method instead of
## inlining `return 1` once this ADR is Accepted.
static func cost_multiplier(unit_type: int, terrain_type: int) -> int

# ─── Lifecycle / Configuration ─────────────────────────────────

## Public for tests; otherwise lazy-loaded on first method call.
## Idempotent: subsequent calls are no-ops once _config_loaded is true.
## Test seam: tests can call this with a custom path to load fixture configs
## (ADVISORY: most tests should use the default config; per-test custom configs
## are an exceptional case for tuning-knob tests).
static func load_config(path: String = "res://assets/data/terrain/terrain_config.json") -> bool

## Test seam: reset to fresh state. Used by gdunit4 before_test() to ensure
## test isolation when a test mutates static state (e.g., loads a custom config).
static func reset_for_tests() -> void
```

### 6. Resource Types — `TerrainModifiers` and `CombatModifiers`

```gdscript
class_name TerrainModifiers
extends Resource

## Per-tile modifier set (uncapped) — for HUD display.
@export var defense_bonus: int = 0      # 0..50 (raw, before cap)
@export var evasion_bonus: int = 0      # 0..50 (raw, before cap)
@export var special_rules: Array[StringName] = []  # e.g. [&"bridge_no_flank"]
```

```gdscript
class_name CombatModifiers
extends Resource

## Combat-context modifiers (clamped) — for Damage Calc.
@export var defender_terrain_def: int = 0    # Clamped to [-30, +30] per CR-3a
@export var defender_terrain_eva: int = 0    # Clamped to [0, 30] per CR-3b
@export var elevation_atk_mod: int = 0       # Per CR-2 table; [-15, +15]
@export var elevation_def_mod: int = 0       # Per CR-2 table; [-15, +15]
@export var bridge_no_flank: bool = false    # Per CR-5; true if defender on BRIDGE
@export var special_rules: Array[StringName] = []  # All defender-tile flags
```

`CombatModifiers.bridge_no_flank` is a denormalised convenience flag also present in `special_rules`. Damage Calc may check either; the bool field is faster (no array scan).

### 7. Cap Constants Ownership and Cross-System Sharing

`MAX_DEFENSE_REDUCTION = 30` and `MAX_EVASION = 30` are owned by Terrain Effect and exposed as static class constants AND in the loaded config:

```gdscript
class_name TerrainEffect
extends RefCounted

const MAX_DEFENSE_REDUCTION_DEFAULT: int = 30  # Compile-time MVP default
const MAX_EVASION_DEFAULT: int = 30            # Compile-time MVP default

# Runtime values from config (may differ from defaults if config overrides):
static var _max_defense_reduction: int = MAX_DEFENSE_REDUCTION_DEFAULT
static var _max_evasion: int = MAX_EVASION_DEFAULT

## Public read accessor for cross-system consumers (Formation Bonus, Damage Calc).
static func max_defense_reduction() -> int:
    if not _config_loaded:
        load_config()
    return _max_defense_reduction

static func max_evasion() -> int:
    if not _config_loaded:
        load_config()
    return _max_evasion
```

Formation Bonus and Damage Calc call `TerrainEffect.max_defense_reduction()` to get the shared cap. This guarantees a single source of truth — the cap value lives in `terrain_config.json` and propagates to all consumers.

## Architecture Diagram

```
┌──────────────────── Foundation Layer ─────────────────────┐
│                                                            │
│   ┌──────────────┐                                         │
│   │   MapGrid    │  ◀───────── reads `tile_destroyed`     │
│   │  (ADR-0004)  │            via GameBus subscription    │
│   └──────┬───────┘            (deferred — see §4 Caching) │
│          │                                                 │
│          │ get_tile(coord)                                 │
│          │ → MapTileData                                   │
│          │   (terrain_type, elevation)                     │
│          │                                                 │
└──────────┼─────────────────────────────────────────────────┘
           │
           ▼
┌──────────────────────── Core Layer ───────────────────────┐
│                                                            │
│   ┌─────────────────────────────────────────┐              │
│   │   TerrainEffect (this ADR — Stateless)  │              │
│   │   ─────────────────────────────────     │              │
│   │   • Loads config once at first call     │              │
│   │   • get_terrain_modifiers(coord)        │              │
│   │   • get_combat_modifiers(atk, def)      │              │
│   │   • get_terrain_score(coord)            │              │
│   │   • cost_multiplier(unit, terrain)      │              │
│   │   • emits terrain_changed (deferred)    │              │
│   └────────────────┬────────────────────────┘              │
│                    │                                       │
└────────────────────┼───────────────────────────────────────┘
                     │
        ┌────────────┼─────────────┬──────────────┐
        ▼            ▼             ▼              ▼
┌───────────────┐ ┌──────────┐ ┌─────────┐ ┌─────────────┐
│ Damage Calc   │ │   AI     │ │ Battle  │ │ Formation   │
│ (Feature)     │ │ (Feature)│ │  HUD    │ │   Bonus     │
│               │ │          │ │ (Pres.) │ │  (Feature)  │
│ get_combat_   │ │ get_     │ │ get_    │ │ max_defense │
│   modifiers() │ │ terrain_ │ │ terrain │ │  _reduction │
│ + bridge_no_  │ │  score() │ │  _modi- │ │  () shared  │
│   flank check │ │          │ │ fiers() │ │  cap        │
└───────────────┘ └──────────┘ └─────────┘ └─────────────┘

┌──────────────────── Platform Layer ───────────────────────┐
│                                                            │
│   ┌──────────────┐                                         │
│   │   GameBus    │  ◀─── TerrainEffect emits              │
│   │  (ADR-0001)  │       `terrain_changed(coord)`         │
│   │              │       (deferred to caching impl)       │
│   └──────────────┘                                         │
└────────────────────────────────────────────────────────────┘
```

## Key Interfaces

```gdscript
# src/core/terrain_effect.gd
class_name TerrainEffect
extends RefCounted

# ── Compile-time defaults (CR-1, CR-3) ──────────────────────────
const MAX_DEFENSE_REDUCTION_DEFAULT: int = 30
const MAX_EVASION_DEFAULT: int = 30
const EVASION_WEIGHT_DEFAULT: float = 1.2
const MAX_POSSIBLE_SCORE_DEFAULT: float = 43.0

# Terrain-type integer mirrors (matches MapGrid.ELEVATION_RANGES ordering;
# TD-032 A-16 — canonical ordering is PLAINS=0, FOREST=1, HILLS=2, MOUNTAIN=3,
# RIVER=4, BRIDGE=5, FORTRESS_WALL=6, ROAD=7).
const PLAINS:        int = 0
const FOREST:        int = 1
const HILLS:         int = 2
const MOUNTAIN:      int = 3
const RIVER:         int = 4
const BRIDGE:        int = 5
const FORTRESS_WALL: int = 6
const ROAD:          int = 7

# ── Static state (lazy-init) ────────────────────────────────────
static var _config_loaded: bool = false
static var _terrain_table: Dictionary = {}      # int → TerrainEntry
static var _elevation_table: Dictionary = {}    # int (delta -2..+2) → ElevationEntry
static var _max_defense_reduction: int = MAX_DEFENSE_REDUCTION_DEFAULT
static var _max_evasion: int = MAX_EVASION_DEFAULT
static var _evasion_weight: float = EVASION_WEIGHT_DEFAULT
static var _max_possible_score: float = MAX_POSSIBLE_SCORE_DEFAULT
static var _cost_default_multiplier: int = 1

# ── Public Query API ────────────────────────────────────────────
static func get_terrain_modifiers(grid: MapGrid, coord: Vector2i) -> TerrainModifiers
static func get_combat_modifiers(grid: MapGrid, atk: Vector2i, def: Vector2i) -> CombatModifiers
static func get_terrain_score(grid: MapGrid, coord: Vector2i) -> float
static func cost_multiplier(unit_type: int, terrain_type: int) -> int
static func max_defense_reduction() -> int
static func max_evasion() -> int

# ── Lifecycle / Test Seams ──────────────────────────────────────
static func load_config(path: String = "res://assets/data/terrain/terrain_config.json") -> bool
static func reset_for_tests() -> void

# ── Internal Helpers (private, for testability via reset_for_tests) ──
static func _validate_config(parsed: Variant) -> bool
static func _apply_config(parsed: Dictionary) -> void
static func _fall_back_to_defaults() -> void
```

```gdscript
# src/core/terrain_modifiers.gd
class_name TerrainModifiers
extends Resource

@export var defense_bonus: int = 0
@export var evasion_bonus: int = 0
@export var special_rules: Array[StringName] = []
```

```gdscript
# src/core/combat_modifiers.gd
class_name CombatModifiers
extends Resource

@export var defender_terrain_def: int = 0
@export var defender_terrain_eva: int = 0
@export var elevation_atk_mod: int = 0
@export var elevation_def_mod: int = 0
@export var bridge_no_flank: bool = false
@export var special_rules: Array[StringName] = []
```

## Alternatives Considered

### Alternative 1: Battle-scoped Node (mirroring ADR-0004 Map/Grid)

- **Description**: `class_name TerrainEffect extends Node`, instantiated as a BattleScene child, loaded via `add_child(TerrainEffect.new())` at battle enter. Loads config in `_ready()`. Subscribes to GameBus signals via `_ready()`.
- **Pros**: Mirrors Map/Grid's lifecycle exactly; signal subscription via Node's `connect` is idiomatic; per-battle config could enable per-chapter terrain overrides.
- **Cons**:
  - Adds a Node to the scene tree for zero per-battle state.
  - Per-battle init cost (config re-load) for no benefit — config is immutable.
  - Callers need a reference to the instance: either through scene-tree traversal (fragile) or dependency injection (verbose).
  - Per-chapter terrain overrides are NOT a planned feature for MVP (GDD has no such requirement).
- **Rejection reason**: Violates GDD's "stateless... pure query layer" requirement. Adds complexity (Node lifecycle, instance reference passing) for no requirement-driven benefit.

### Alternative 2: Game-scoped Autoload (`/root/TerrainEffect`)

- **Description**: Autoload at `/root/TerrainEffect` (load order 4 after GameBus / SceneManager / SaveManager). Loads config in `_ready()`. Globally accessible via `TerrainEffect` autoload identifier.
- **Pros**: Globally accessible without static-method ceremony; idiomatic for "always-on game services" (matches ADR-0001 GameBus, ADR-0002 SceneManager, ADR-0003 SaveManager).
- **Cons**:
  - Autoload lifecycle implies a Node that responds to scene-tree events. Terrain Effect responds to nothing — it's pure functions.
  - Adds a 4th autoload to the project. Each autoload increases boot time and project complexity.
  - Tests must navigate the autoload-stub pattern (G-3, G-10 gotchas) for isolation, even though the module has no per-test mutable state worth isolating.
  - `class_name TerrainEffect` would collide with the autoload name per G-3 — would force renaming the script class.
- **Rejection reason**: Autoload semantics are wrong fit for a stateless rules calculator. The correct idiom for "global static utility" is a `class_name X extends RefCounted` with static methods. Autoloads are for instances that need to persist across scenes (GameBus, SceneManager, SaveManager all hold state); Terrain Effect holds nothing per scene.

### Alternative 3: Stateless Static Utility Class (CHOSEN)

- **Description**: `class_name TerrainEffect extends RefCounted` with all static methods; lazy-loaded config in static class-scope variables.
- **Pros**: ALL the cons of alternatives 1+2 are absent. Stateless = no lifecycle. Static = globally callable without instance plumbing. Lazy-loaded = tests pay zero cost for queries that don't fire.
- **Cons**:
  - Static state is global state — tests must call `reset_for_tests()` between cases that load custom configs (acceptable; gdunit4 `before_test` handles this cleanly).
  - Mocking is harder (no instance to inject); test seams must be designed in (provided: `load_config(path)` accepts custom path; `reset_for_tests()` clears state).
- **Rejection reason of alternatives**: See above.

### Alternative 4: Pure Static — No Class Type, Functions in a Script File

- **Description**: A plain `.gd` script with `static func` declarations and no `class_name`. Imported via `preload("res://src/core/terrain_effect.gd")` at call sites.
- **Pros**: Zero boilerplate.
- **Cons**: Loses the `class_name` global identifier — every consumer needs a `preload` line. IDE autocomplete is degraded. The benefit of `class_name` (cleaner imports, autocomplete) outweighs the negligible cost of `extends RefCounted`.
- **Rejection reason**: Project naming conventions (`.claude/docs/technical-preferences.md` line "Naming Conventions") favor `class_name` for all reusable modules. `RefCounted` is the correct base for a non-instantiated utility (it's never `.new()`-ed).

## Consequences

### Positive

- **Zero per-battle init cost**: Config loads once at game start (lazy on first method call); subsequent battles pay zero re-init cost. Compare: ADR-0004 MapGrid pays `duplicate_deep` cost per battle enter — Terrain Effect doesn't because there's no per-battle mutable state.
- **Trivially testable**: Static methods + idempotent lazy init + `reset_for_tests()` seam = unit tests are cheap, isolated, and parallel-safe within gdunit4.
- **Clean cross-system contracts**: `max_defense_reduction()` / `max_evasion()` static accessors give Formation Bonus + Damage Calc a single source of truth. Cap value changes are JSON-config edits — no code change.
- **Foundation-layer-clean Map/Grid**: Bridge FLANK override lives in Damage Calc, not Map/Grid. Architecture invariant #4 holds (Foundation has no upward dependencies).
- **JSON config = designer-editable**: Terrain tuning happens without launching Godot editor. Faster iteration during balance work.
- **LOW engine risk**: All APIs pre-cutoff. No verification gauntlet beyond the project's standard test suite.

### Negative

- **Static state = global state**: Tests must `reset_for_tests()` between cases that load custom configs. Mitigation: `before_test()` boilerplate is one line.
- **No typed-Resource inspector editing**: Designers edit JSON in a text editor, not the Godot inspector. Trade-off: faster iteration vs. less discoverable schema. GDD line 583 explicitly chose JSON; this ADR honors that.
- **JSON parsing cost on first access**: ~1-5ms one-time cost at first `get_terrain_modifiers()` call. Acceptable: happens during scene load, not during gameplay.
- **Cost matrix placeholder**: `cost_multiplier()` returns the `default_multiplier` (1) for all unit-type/terrain-type pairs until ADR-0009 Unit Role lands. This means MVP gameplay has no class-specific terrain pathing penalties (e.g., Cavalry pays normal cost on MOUNTAIN). GDD CR-1d explicitly accepts this: "Modifiers uniform across all unit types for MVP."
- **No caching = repeated Map/Grid lookups**: Every call hits Map/Grid. Mitigation: Map/Grid lookups are O(1) packed-cache reads (ADR-0004). Aggregate per-frame cost stays well within AC-21 budget. If profiling proves otherwise, add caching per §4.

### Risks

| Risk | Severity | Mitigation |
|------|----------|-----------|
| **Config file missing or corrupt at game start** | MEDIUM — game still launches but with default values; player sees "wrong" terrain modifiers | `_fall_back_to_defaults()` ensures playability. `push_error` logs the issue. AC-20 test verifies fallback. |
| **JSON integer values parsed as float by Godot** | LOW — Godot 4.6 `JSON.parse_string` returns `float` for all numbers; integer fields could carry float drift | `_validate_config()` casts via `int(value)` and rejects non-integral floats. Verification Required §3. |
| ~~**ADR-0006 Balance/Data lands with `.tres`-only pipeline**~~ **RESOLVED 2026-04-30** | RESOLVED — ADR-0006 Accepted 2026-04-30 via delta #9 ratified flat-JSON + `BalanceConstants.get_const(key)`; Alternative C `.tres` REJECTED. No migration required. | n/a — risk closed. |
| **Cost matrix shape mismatch with ADR-0009 Unit Role** | MEDIUM — if Unit Role defines unit types differently, cost_matrix structure may need amendment | This ADR ships with the matrix shape (Dict[int, Dict[int, int]]) defined; ADR-0009 populates values. If ADR-0009 chooses a different shape (e.g., per-unit instead of per-class), this ADR receives a follow-up amendment. |
| **g-12 class_name collision** | LOW — `TerrainEffect` is not a Godot built-in | Verified via Godot 4.6 class list; no collision. Safe. |
| **Negative defense values produce surprising behavior** | LOW — game-design risk, not engine risk | GDD CR-3e + EC-1 explicitly address this; F-1 symmetric clamp [-30, +30] is authoritative. UI per EC-12 shows raw + cap indicator. |
| **Static state bleeds across gdunit4 test suites via lazy-init guard** | MEDIUM — `_config_loaded = true` set by Suite A carries into Suite B's VM; fixture configs from AC-19/AC-20 tests may corrupt default-config tests in other files. The `SaveMigrationRegistry` precedent avoids this because its static state is empty-by-default; this module is not. | All test suites that call any `TerrainEffect` method MUST call `reset_for_tests()` in `before_each()` — NOT just suites that call `load_config()` with a custom path. Document this requirement in `terrain_effect_test.gd` header and in the `reset_for_tests()` doc comment. Verify by adding a multi-suite isolation regression test that exercises Suite A custom-config + Suite B default-config in sequence. |
| **`JSON.get_error_message()` not available on `parse_string()` path** | LOW — `JSON.parse_string()` is a static method; `get_error_message()` is an instance method on `JSON`. The two cannot be combined. The Notes for Implementation reference is inaccurate as written. | Decide before implementation: (a) keep `JSON.parse_string()` and accept that `null` return is the only diagnostic signal (log a fixed error string with the file path), OR (b) switch `_load_config()` to `var json := JSON.new(); var err := json.parse(text); if err != OK: push_error(json.get_error_message())` for line-and-column diagnostics. Option (b) is recommended. |

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|---------------------------|
| `terrain-effect.md` CR-1 | 8 terrain types × {defense, evasion, special} | `_terrain_table` Dict keyed by `terrain_type` int; values from JSON config |
| `terrain-effect.md` CR-2 | Asymmetric elevation modifiers (delta ±1 → ±8%, ±2 → ±15%) | `_elevation_table` Dict keyed by delta; `get_combat_modifiers` computes `delta = atk.elev - def.elev` and looks up |
| `terrain-effect.md` CR-3a | Symmetric clamp [−30, +30] for total_defense | `get_combat_modifiers` applies `clampi(...)` per the formula |
| `terrain-effect.md` CR-3b | `MAX_EVASION = 30` cap | `_max_evasion` clamp in `get_combat_modifiers`; cross-system accessor `max_evasion()` |
| `terrain-effect.md` CR-3d | Min damage = 1 | NOT enforced here — Damage Calc's responsibility per cross-system contract; Terrain Effect provides the modifier only |
| `terrain-effect.md` CR-3e + EC-1 | Negative defense allowed; symmetric clamp | F-1 matches; clamp `[−30, +30]` is symmetric per Decision §6 |
| `terrain-effect.md` CR-4 | 3 query methods | `get_terrain_modifiers`, `get_combat_modifiers`, `get_terrain_score` per Key Interfaces |
| `terrain-effect.md` CR-5 | Bridge FLANK override | Decision §3 — flag-based; Damage Calc orchestrates |
| `terrain-effect.md` EC-1 | Symmetric clamp authoritative | Decision §6 + Key Interfaces |
| `terrain-effect.md` EC-2 | Garrison model for FORTRESS_WALL | Out of scope for this ADR (Grid Battle / Siege owns garrison logic); this ADR just provides the 25% defense modifier |
| `terrain-effect.md` EC-9 | Snapshot at attack initiation | Damage Calc owns snapshotting per cross-system contract; Terrain Effect always returns current-state |
| `terrain-effect.md` EC-12 | Raw values for HUD, clamped for combat | `get_terrain_modifiers` returns raw (uncapped); `get_combat_modifiers` returns clamped |
| `terrain-effect.md` EC-13 | RIVER queries valid (no error) | `_terrain_table` has RIVER entry (0/0/[]) — no special-case error path |
| `terrain-effect.md` EC-14 | Elevation delta clamped to ±2 | `get_combat_modifiers` clamps delta via `clampi(delta, -2, 2)` before table lookup; logs warning on clamp |
| `terrain-effect.md` AC-1..AC-21 | Acceptance criteria | All testable via `tests/unit/core/terrain_effect_test.gd` (story-level test scaffolding will reference these ACs) |
| `damage-calc.md` §F | Opaque clamped contract: `terrain_def ∈ [-30, +30]`, `terrain_evasion ∈ [0, 30]` | `CombatModifiers.defender_terrain_def`, `defender_terrain_eva` per Decision §6 |
| `formation-bonus.md` §F-FB-1 | Shared cap `MAX_DEFENSE_REDUCTION = 30` | `TerrainEffect.max_defense_reduction()` static accessor — single source of truth |
| `map-grid.md` §F-2 + ADR-0004 | `cost_multiplier(unit_type, terrain_type)` placeholder in `terrain_cost.gd:32` | `TerrainEffect.cost_multiplier()` replaces the placeholder; MVP returns `1` for all pairs; ADR-0009 will populate values |

## Performance Implications

- **CPU per call**: <0.01 ms expected (`MapGrid.get_tile` is O(1) packed-cache read; `_terrain_table[terrain_type]` is O(1) Dict lookup; total = 2 hash lookups + arithmetic). AC-21 budget is 0.1 ms — 10× headroom.
- **CPU at game start**: 1-5 ms one-time JSON parse + schema validation. Happens before gameplay starts; not on the frame budget.
- **Memory**: ~few KB for `_terrain_table` (8 entries × small Resource each = ~1-2 KB) + `_elevation_table` (5 entries × small = ~0.5 KB) + cost_matrix (placeholder dict, ~0.1 KB). Total <5 KB.
- **Load time**: Negligible. JSON file is small (<1 KB on disk).
- **Network**: N/A — no network operations.

## Migration Plan

### From the current placeholder (story-005's `terrain_cost.gd`)

**Current state**: `src/core/terrain_cost.gd:32` has a placeholder:
```gdscript
static func cost_multiplier(_unit_type: int, _terrain_type: int) -> int:
    # REPLACED WHEN ADR-0008 Terrain Effect lands; MVP ships with this placeholder.
    return 1
```

**Migration step (post-ADR-0008 Acceptance)**:
1. Implement `TerrainEffect` per this ADR.
2. Update `terrain_cost.gd:32` to delegate:
   ```gdscript
   static func cost_multiplier(unit_type: int, terrain_type: int) -> int:
       return TerrainEffect.cost_multiplier(unit_type, terrain_type)
   ```
3. Run full regression suite — all map-grid tests must pass unchanged (cost values are still 1; only the indirection changes).
4. Eventually (post-ADR-0009): delete `terrain_cost.gd` and migrate all callers to `TerrainEffect.cost_multiplier()` directly. Tracked as TD when ADR-0009 lands.

### When the future Alpha-pipeline DataRegistry ADR lands

ADR-0006 (Accepted 2026-04-30 via delta #9) ratified the MVP `BalanceConstants.get_const(key)` flat-JSON pattern. The TerrainEffect `_load_config_direct()` helper is forward-compatible per ADR-0006 §Migration Path Forward — no immediate migration required. When the future Alpha-tier DataRegistry pipeline ADR is authored:

1. Add `_load_config_via_data_registry(path: String)` helper.
2. Switch `load_config()` default implementation from direct JSON parse to DataRegistry pipeline call.
3. Public API unchanged. Consumer code unchanged.
4. Regression: AC-19 + AC-20 tests verify config loading still works.

### When ADR-0009 Unit Role lands

1. ADR-0009 specifies the unit-class enum (INFANTRY / CAVALRY / ARCHER / STRATEGIST / HEALER per architecture.md line 253).
2. Update `terrain_config.json` `cost_matrix` section with full population (5 unit classes × 8 terrain types = 40 entries).
3. Update `_apply_config()` to read the populated matrix instead of using `default_multiplier`.
4. Run map-grid regression: V-4 50-query equivalence must still pass (or its expectations updated if cost values change).

## Validation Criteria

This ADR is correct if:

1. **All terrain-effect.md ACs pass** when implemented per this ADR (AC-1 through AC-21). Test file: `tests/unit/core/terrain_effect_test.gd` (to be authored when terrain-effect epic stories are created).
2. **Cross-system contract holds**: Damage Calc, Formation Bonus, AI, Battle HUD can consume the API without touching Map/Grid directly for terrain data.
3. **Performance budget met**: AC-21 micro-benchmark passes (<0.1 ms per `get_combat_modifiers()` call).
4. **Story-005 placeholder unblocked**: `terrain_cost.gd:32` migrates to `TerrainEffect.cost_multiplier(...)` without test regression.
5. **Layer invariant clean**: Architecture review confirms Map/Grid (Foundation) has no upward dependency on Terrain Effect (Core); the Bridge FLANK orchestration lives in Damage Calc (Feature).
6. **Engine specialist sign-off**: `godot-specialist` validates the static-method-on-RefCounted pattern, JSON loading approach, and `class_name TerrainEffect` non-collision per Step 4.5 of `/architecture-decision`.

## Related Decisions

- **ADR-0001 GameBus** (Accepted) — `terrain_changed(coord: Vector2i)` signal addition (deferred to caching impl); `tile_destroyed(coord)` subscription (deferred to caching impl).
- **ADR-0004 Map/Grid Data Model** (Accepted) — upstream data source via `MapGrid.get_tile(coord)`. ADR-0004 line 33 explicitly enables ADR-0008.
- **ADR-0006 Balance/Data** (Accepted 2026-04-30 via /architecture-review delta #9) — RATIFIES the TerrainConfig direct-loading pattern as forward-compatible with the future Alpha-pipeline DataRegistry rename per ADR-0006 §Migration Path Forward.
- **ADR-0009 Unit Role** (NOT YET WRITTEN) — populates the cost_matrix unit-class dimension; soft-dependency, populates placeholder values post-Acceptance.
- **Future Damage Calc ADR** — consumes `get_combat_modifiers()`; orchestrates Bridge FLANK override per Decision §3.
- **Future AI ADR** — consumes `get_terrain_score()` for tile ranking.
- **Future Formation Bonus ADR** — consumes `max_defense_reduction()` for shared cap.

## Notes for Implementation

- **Test seam discipline**: `reset_for_tests()` MUST be called in `before_test()` for any test that calls `load_config()` with a custom path. Tests that use the default config can omit this call. Document in `terrain_effect_test.gd` header.
- **JSON parse error handling**: `JSON.parse_string()` is a STATIC method that returns `null` on parse failure with no diagnostic info available. For line-and-column error messages, use the instance form: `var json := JSON.new(); var err := json.parse(text); if err != OK: push_error("...: " + json.get_error_message())`. Recommended for implementation. The two forms cannot be combined — `JSON.get_error_message()` on the class itself is not a static method.
- **Validate integer fields explicitly**: When parsing JSON integer fields (`defense_bonus`, `evasion_bonus`, `attack_mod`, `defense_mod`, cap values), reject non-integral floats: `if typeof(value) != TYPE_FLOAT or value != int(value): push_error("non-integral value at " + key); return false`. Silent truncation (`int(15.9) == 15`) would accept malformed config without warning. Godot's `JSON.parse_string` returns all numbers as `float` by default — this validation step is the canonical place to reject decimal values for integer-typed fields.
- **Typed Dictionary const limitation note (G-1)**: The static state vars (`_terrain_table`, `_elevation_table`, `_cost_matrix`) are declared as untyped `Dictionary = {}` rather than `Dictionary[int, TerrainEntry]` because GDScript 4.6 does not support generic-Dictionary syntax in `static var` declarations. Document this rationale inline in the source file header to prevent future maintainers from "fixing" the untyped declarations. Same precedent: `src/core/save_migration_registry.gd`.
- **Avoid global JSON cache**: Godot's `JSON` class is reusable; create one instance per `load_config()` call rather than a static class-scope `JSON` instance. Smaller memory footprint.
- **Defensive copy on Resource return**: `get_terrain_modifiers()` and `get_combat_modifiers()` return new Resource instances each call to prevent caller mutation from affecting the static `_terrain_table`. Resources are `RefCounted` so allocation is cheap (~5-10 µs per call).
- **`reset_for_tests()` discipline**: This method MUST clear all static state and set `_config_loaded = false`. Test helpers should NEVER directly mutate `_terrain_table` etc. — always go through `reset_for_tests()` + `load_config(custom_path)`.
- **Documentation in `src/core/terrain_effect.gd` header**: Reference this ADR by ID. When future amendments land (e.g., future Alpha-pipeline DataRegistry migration per ADR-0006 §Migration Path Forward, ADR-0009 cost matrix population), the source-code header should be updated to reference the amendments.
