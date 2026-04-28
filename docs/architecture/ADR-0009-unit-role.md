# ADR-0009: Unit Role System

## Status
Accepted

## Date
2026-04-28

## Last Verified
2026-04-28 (re-verified post-implementation 2026-04-28: §1 line 130 second-correction applied per G-22 empirical discovery during unit-role/story-001 round 3 — `@abstract` is parse-time-on-typed-reference, not runtime; supersedes the /architecture-review 2026-04-28 Item 1 design-time correction)

## Decision Makers
- User (final approval, granted 2026-04-28 via `/architecture-review` delta-mode)
- Technical Director (architecture owner)
- godot-specialist (engine validation, 2026-04-28 design-time — APPROVED, 4 notes incorporated)
- godot-specialist (engine validation, 2026-04-28 review-time `/architecture-review` independent second opinion — APPROVED WITH SUGGESTIONS; 8/8 PASS-or-CONCERN; 2 corrections applied pre-acceptance: §1 `parse-time error` → `runtime error` for `UnitRole.new()` under `@abstract`, ADR-0012 line 42 dependency `CLASS_DIRECTION_MULT[4][3]` → `[6][3]` same-patch amendment)
- godot-gdscript-specialist (implementation-time empirical validation, 2026-04-28 unit-role/story-001 round 3 — DISCOVERED `@abstract` enforcement reality differs from BOTH the original ADR text AND the /architecture-review 2026-04-28 Item 1 correction; correctly characterized as parse-time-on-typed-reference with reflective bypass + no `push_error` emission; second correction applied to §1 line 130; G-22 codified in `.claude/rules/godot-4x-gotchas.md`)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Foundation — stateless gameplay rules calculator (per `architecture.md` §Foundation layer) |
| **Knowledge Risk** | LOW — no post-cutoff APIs. `class_name`, `RefCounted`, `static func`, typed `enum`, `Array[StringName]`, `PackedFloat32Array`, `JSON.new().parse()`, `FileAccess.get_file_as_string()`, `clamp` / `clampi` / `floori`, `@export` on `Resource`, `Dictionary[K, V]` are all pre-Godot-4.4 and stable across the project's pinned 4.6 baseline. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/current-best-practices.md`, `design/gdd/unit-role.md` (rev 2026-04-16), `design/gdd/damage-calc.md` (rev 2.9.3, primary direction-multiplier consumer), `design/gdd/terrain-effect.md` (cost-matrix structure consumer), `design/gdd/hero-database.md` (upstream Hero DB contract — pre-ADR), `design/gdd/grid-battle.md` (effective_move_range + cost-table consumer), `design/gdd/turn-order.md` (initiative consumer), `design/gdd/formation-bonus.md` (Commander Rally consumer), `design/gdd/hp-status.md` (max_hp consumer), `design/registry/entities.yaml` (12 constants already registered with `source: unit-role.md`), `docs/architecture/ADR-0001-gamebus-autoload.md` (non-emitter list), `docs/architecture/ADR-0006-balance-data.md` (BalanceConstants pipeline, Accepted 2026-04-26), `docs/architecture/ADR-0008-terrain-effect.md` (architectural-form precedent, Accepted 2026-04-25), `docs/architecture/ADR-0012-damage-calc.md` (CLASS_DIRECTION_MULT lock, Accepted 2026-04-26), `docs/architecture/architecture.md` §Foundation layer, `docs/registry/architecture.yaml`, `.claude/rules/godot-4x-gotchas.md` (G-15 BalanceConstants test isolation). |
| **Post-Cutoff APIs Used** | None. All APIs are pre-Godot-4.4. The `unit_class` enum-typed parameter binding (`unit_class: UnitRole.UnitClass`) is improved over ADR-0008's raw `int terrain_type` per godot-specialist 2026-04-28 advice — typed-enum parameter binding has been stable since Godot 4.0 and produces stricter parse-time type errors at call sites than raw `int`. |
| **Verification Required** | (1) `BalanceConstants._cache_loaded` reset in `unit_role_test.gd before_test()` per G-15 + ADR-0006 §6 — mandatory test obligation, every UnitRole test suite that transitively reads global caps must include the reset. (2) `PackedFloat32Array` returned from `get_class_cost_table()` must be a per-call copy (Godot 4.x COW semantics handle this naturally); a unit test must verify caller-mutation does NOT corrupt subsequent calls (R-1 mitigation). (3) Per-method latency budget: each `get_atk` / `get_phys_def` / `get_mag_def` / `get_max_hp` / `get_initiative` / `get_effective_move_range` < 0.05ms on minimum-spec mobile (Adreno 610 / Mali-G57 class) — soft budget, headless CI throughput baseline only; on-device measurement deferred per damage-calc story-010 Polish-deferral pattern (now stable at 5+ invocations). (4) Static lint via grep: zero `signal` declarations + zero `connect(` / `emit_signal(` calls in `src/foundation/unit_role.gd` (non-emitter invariant, mirrors ADR-0012 forbidden_pattern `damage_calc_signal_emission`). |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (GameBus, Accepted 2026-04-18) — UnitRole is on the **non-emitter list**; UnitRole emits zero signals, subscribes to zero signals, holds zero signal connections. ADR-0006 (Balance/Data, Accepted 2026-04-26) — `BalanceConstants.get_const(key: String) -> Variant` is the canonical accessor for all 10 global caps consumed by F-1..F-5 (`ATK_CAP`, `DEF_CAP`, `HP_CAP`, `HP_SCALE`, `HP_FLOOR`, `INIT_CAP`, `INIT_SCALE`, `MOVE_RANGE_MIN`, `MOVE_RANGE_MAX`, `MOVE_BUDGET_PER_RANGE`); test isolation obligation per ADR-0006 §6 + G-15. ADR-0008 (Terrain Effect, Accepted 2026-04-25) — Terrain Effect owns the cost-matrix STRUCTURE (terrain_type dimension, 8-entry terrain enum); UnitRole owns the cost-matrix unit-class DIMENSION (6-entry UnitClass enum) and exposes `get_class_cost_table(unit_class)` returning a `PackedFloat32Array` indexed by terrain_type. ADR-0008's cost-matrix placeholder (line 47, "uniform `1` pending ADR-0009 Unit Role") is ratified here. |
| **Soft / Provisional** | **ADR-0007 Hero DB (NOT YET WRITTEN — soft / provisional upstream)**: F-1..F-5 stat-derivation static methods accept a typed `HeroData` Resource parameter whose field shape (`stat_might`, `stat_intellect`, `stat_command`, `stat_agility`, `base_hp_seed`, `base_initiative_seed`, `move_range`, `default_class`, `innate_skill_ids`, `equipment_slot_override`) is contracted by `design/gdd/hero-database.md` §Detailed Rules but not yet ratified by an ADR. Workaround until ADR-0007 lands: ship with a thin `HeroData` Resource wrapper at `src/foundation/hero_data.gd` whose @export-annotated fields mirror the GDD contract; migrate to ADR-0007's authoritative shape when Accepted. The migration is parameter-stable (call sites unchanged); only the `HeroData` field set may extend (never rename without an ADR-0007 amendment + propagate-design-change pass). Mirrors ADR-0012's pattern of locking against unwritten upstream ADRs (line 42). |
| **Enables** | (1) **Ratifies** ADR-0008 (Terrain Effect)'s cost-matrix unit-class dimension placeholder (line 47); ADR-0008's `cost_matrix` structure can now resolve `unit_class` int parameters against UnitRole's authoritative table. (2) **Ratifies** ADR-0012 (Damage Calc) §F-DC-3 `CLASS_DIRECTION_MULT[unit_class][direction_rel]` — the 6×3 table values were locked by `unit-role.md` rev 2026-04-16 §EC-7 and shipped as `entities.yaml` `CLASS_DIRECTION_MULT` constant (`source: unit-role.md`); ADR-0009 ratifies (does not negotiate) those values. (3) **Unblocks** unit-role Foundation epic creation (`/create-epics unit-role` after Acceptance). (4) **Unblocks** Turn Order ADR (consumer of `get_initiative`), AI ADR (consumer of `PASSIVE_TAG_BY_CLASS` + `get_class_cost_table`), Battle Preparation epic (consumer of `class_pools.json` schema referenced by CR-5c), HP/Status ADR (consumer of `get_max_hp`), Formation Bonus ADR (consumer of Commander `passive_rally` tag + Rally cap constants per EC-12). |
| **Blocks** | unit-role Foundation epic implementation (cannot start any story until this ADR is Accepted); `assets/data/skills/class_pools.json` schema authoring (CR-5c data file); Turn Order ADR ratification of initiative formula (F-4); AI ADR ratification of cost-table consumer pattern; Battle Preparation epic story scaffolding for Slot-2 selection rules (CR-5a..5d). |
| **Ordering Note** | Soft-dependency on ADR-0007 Hero DB documented above. The migration is parameter-stable: when ADR-0007 lands and ratifies `HeroData`, no UnitRole call site changes — only the `HeroData` Resource definition file moves under ADR-0007's authority. Pattern is now stable at 2 invocations (ADR-0008 → ADR-0006 in 2 days; ADR-0009 → ADR-0007 in N days where N depends on Hero DB ADR scheduling). |

## Context

### Problem Statement

`design/gdd/unit-role.md` (Designed, rev 2026-04-16) defines the Unit Role System as the Foundation-layer stateless rule definition layer that owns 6 class profiles, 4 stat-derivation formulas (F-1 ATK, F-2 DEF, F-3 HP, F-4 Initiative, F-5 Move Range), 6 class passives, the 6×3 class direction multiplier table, and the unit-class dimension of the terrain cost matrix. The architecture cannot proceed without locking 7 questions:

1. **Module type** — Stateless static utility class? Battle-scoped Node? Autoload? GDD §States and Transitions explicitly states "stateless rule definition layer" — but says nothing about implementation form. ADR-0008 (Terrain Effect) ratified the `class_name X extends RefCounted` + all-static-methods form for an analogous Foundation/Core stateless calculator; this ADR must decide whether to reuse that form or diverge.
2. **UnitClass type representation** — int enum vs StringName tag. ADR-0012 (Damage Calc) indexes `CLASS_DIRECTION_MULT[unit_class][direction_rel]` (bracket indexing) and registered the constant in `entities.yaml`. The `unit_class` parameter type on `AttackerContext` was renamed from `class` (GDScript reserved keyword) per ADR-0012 Engine Compatibility note, but the type itself was not locked.
3. **Public API surface granularity** — 5 separate stat-derivation static methods (one per formula) vs a single bundle method returning a `UnitStats` typed Resource. Each consumer (Damage Calc reads atk/phys_def/passive tags; HP/Status reads max_hp; Turn Order reads initiative; Grid Battle reads effective_move_range) calls only what it needs.
4. **Cost-matrix unit-class-dimension exposure shape** — ADR-0008 line 47 declares the cost-matrix structure but explicitly defers the unit-class dimension to ADR-0009. Map/Grid Dijkstra hot loop calls cost lookups ~300 times per `get_movement_range` invocation; the exposure shape must support hot-path performance per `map-grid.md` AC-PERF-2 (<16ms total budget).
5. **Class direction multiplier ratification** — `unit-role.md` §CR-6a + §EC-7 locks the 6×3 table values; `entities.yaml` registers `CLASS_DIRECTION_MULT` with `source: unit-role.md`; ADR-0012 §F-DC-3 commits to those values as the locked direction multiplier. ADR-0009 must *ratify* (not negotiate) those values as the authoritative source.
6. **Config split between unit_roles.json and BalanceConstants** — GDD line 242-245 references both `assets/data/config/unit_roles.json` (per-class coefficients) and `assets/data/config/balance_constants.json` (global caps). ADR-0006 ratified `BalanceConstants.get_const(key)` backed by `assets/data/balance/balance_entities.json` (NOT `balance_constants.json`); the GDD prose is now stale.
7. **Passive tag canonicalization** — ADR-0012 forbidden_pattern `damage_calc_dictionary_payload` mandates `Array[StringName]` for passives with literal `&"passive_charge"`-style tags. UnitRole owns the canonical 6-tag set; ADR-0009 must lock the StringName values.

### Constraints

**From `design/gdd/unit-role.md` (locked by user + game-designer + systems-designer):**

- **CR-1**: 6 classes (CAVALRY, INFANTRY, ARCHER, STRATEGIST, COMMANDER, SCOUT) with primary stat / attack type / attack range / move delta / equipment slots per the §CR-1 table.
- **CR-1a**: PHYSICAL targets `phys_def`; MAGICAL targets `mag_def`. STRATEGIST is the sole MAGICAL class.
- **CR-1b**: `effective_move_range = clamp(hero_move_range + class_move_delta, MOVE_RANGE_MIN, MOVE_RANGE_MAX)`.
- **CR-2**: 6 class passives — `passive_charge`, `passive_shield_wall`, `passive_high_ground_shot`, `passive_tactical_read`, `passive_rally`, `passive_ambush` — owned by this system as a canonical StringName set.
- **CR-4**: 6 classes × 6 terrains (ROAD, PLAINS, HILLS, FOREST, MOUNTAIN, BRIDGE) terrain cost multiplier table per §CR-4. Effective tile cost = `floor(base_terrain_cost × class_multiplier)`.
- **CR-6a**: 6×3 class direction multiplier table — locked at rev 2.8 values (Cavalry REAR=1.09 per damage-calc rev 2.8 Rally-ceiling fix).
- **F-1..F-5**: Five stat-derivation formulas with explicit clamp ranges (`[1, ATK_CAP]`, `[1, DEF_CAP]`, `[HP_FLOOR+1, HP_CAP]`, `[1, INIT_CAP]`, `[MOVE_RANGE_MIN, MOVE_RANGE_MAX]`).
- **AC-20**: All class coefficients, multipliers, passive effect values, and caps loaded from data files. No gameplay value hardcoded.

**From `design/registry/entities.yaml` (constants already registered, source: unit-role.md):**

- 10 global caps registered with `source: unit-role.md`: `ATK_CAP=200`, `DEF_CAP=100`, `HP_CAP=300`, `HP_SCALE=2.0`, `HP_FLOOR=50`, `INIT_CAP=200`, `INIT_SCALE=2.0`, `MOVE_RANGE_MIN=2`, `MOVE_RANGE_MAX=6`, `tactical_read_extension_tiles=1`.
- `CLASS_DIRECTION_MULT` registered with `source: unit-role.md`, `referenced_by: [unit-role.md, damage-calc.md]`.
- `CHARGE_BONUS=1.20` registered with `source: damage-calc.md`, `referenced_by: [unit-role.md, turn-order.md]`. UnitRole's CR-2 Charge passive defines the activation gate; damage-calc owns the multiplier value.
- `AMBUSH_BONUS=1.15` registered with `source: damage-calc.md`, `referenced_by: [unit-role.md, turn-order.md]`. Same split: UnitRole's CR-2 Ambush passive defines the activation gate; damage-calc owns the multiplier value.

**From `docs/architecture/ADR-0001-gamebus-autoload.md`:**

- UnitRole is on the non-emitter list (line 375 region) — emits zero signals, subscribes to zero signals.

**From `docs/architecture/ADR-0006-balance-data.md`:**

- `BalanceConstants.get_const(key: String) -> Variant` is the canonical accessor for all global caps. UnitRole MUST use this accessor for every read of `ATK_CAP`, `DEF_CAP`, `HP_CAP`, `HP_SCALE`, `HP_FLOOR`, `INIT_CAP`, `INIT_SCALE`, `MOVE_RANGE_MIN`, `MOVE_RANGE_MAX`, `MOVE_BUDGET_PER_RANGE`.
- Test isolation obligation: every test suite calling `BalanceConstants` MUST reset `_cache_loaded = false` in `before_test()` per ADR-0006 §6 + G-15.
- Data file: `assets/data/balance/balance_entities.json` (NOT `balance_constants.json` as the GDD prose currently reads — GDD line 244 + 606 + Tuning Knobs sections are updated alongside this ADR).

**From `docs/architecture/ADR-0008-terrain-effect.md`:**

- Architectural-form precedent: `class_name TerrainEffect extends RefCounted` + all-static-methods + JSON config + lazy-init load. Verified by godot-specialist 2026-04-25.
- Cost matrix structure declaration: ADR-0008 §1d declares the per-unit-type × per-terrain-type cost matrix as the canonical shape; ADR-0008 line 47 explicitly defers the unit-type dimension to ADR-0009.

**From `docs/architecture/ADR-0012-damage-calc.md`:**

- `CLASS_DIRECTION_MULT[6][3]` table consumed via `entities.yaml` constant + `BalanceConstants.get_const("CLASS_DIRECTION_MULT")`. ADR-0012 commits to the rev 2.8 locked values.
- `Array[StringName]` is the typed-array contract for passives per `damage_calc_dictionary_payload` forbidden_pattern. UnitRole's exposed passive tags are `Array[StringName]` with literal `&"passive_*"` form.

**From `.claude/docs/technical-preferences.md`:**

- GDScript with static typing mandatory.
- Mobile budgets: 60 fps / 16.6 ms frame budget; 512 MB ceiling.
- Test coverage floor: 100% for balance formulas (F-1..F-5 included), 80% for gameplay systems.
- Naming: PascalCase classes, snake_case variables, snake_case past-tense signals, UPPER_SNAKE_CASE constants.

**From `.claude/rules/godot-4x-gotchas.md`:**

- G-15: `BalanceConstants._cache_loaded` reset in `before_test()` for every GdUnit4 suite that transitively reads global caps.

### Requirements

**Functional**:

- Provide 5 derived-stat static methods (`get_atk`, `get_phys_def`, `get_mag_def`, `get_max_hp`, `get_initiative`) implementing GDD F-1..F-4 formulas with full clamp discipline.
- Provide `get_effective_move_range(hero, unit_class) -> int` implementing F-5; `move_budget` is a one-line consumer compute (`effective_move_range × MOVE_BUDGET_PER_RANGE`) — not a separate method.
- Provide `get_class_cost_table(unit_class) -> PackedFloat32Array` returning a 6-entry packed array indexed by terrain_type enum (0..5: ROAD, PLAINS, HILLS, FOREST, MOUNTAIN, BRIDGE).
- Provide `get_class_direction_mult(unit_class, direction) -> float` for damage-calc consumption per F-DC-3.
- Provide `PASSIVE_TAG_BY_CLASS: Dictionary[int, StringName]` constant exposing the 6-class → 6-tag mapping for AI / Damage Calc / Battle HUD.
- Load per-class coefficients from `assets/data/config/unit_roles.json` (this system's config); load global caps via `BalanceConstants.get_const(key)` per ADR-0006.
- Lazy-init at first access; no eager-load at boot.

**Non-functional**:

- Each derived-stat method <0.05ms on minimum-spec mobile (one-time per unit per battle, called ~12 times at battle init).
- `get_class_cost_table()` <0.01ms per call (called once per Map/Grid `get_movement_range` invocation).
- `get_class_direction_mult()` <0.01ms per call (called once per damage-calc `resolve()` invocation).
- Stateless: zero per-battle initialization, zero per-battle state, zero per-battle teardown beyond the lazy-init data cache (which persists for the GDScript engine session per ADR-0006 §6).
- Idempotent: identical inputs always produce identical outputs (no random sampling; no time-dependent reads).
- Thread-safe for read access (Godot single-threaded game logic; documented for future-proofing).

## Decision

### 1. Module Type — Stateless Static Utility Class

`UnitRole` is a stateless static utility class with `class_name UnitRole extends RefCounted`. It is **NOT** registered as an autoload — the `class_name` global identifier provides direct access (`UnitRole.get_atk(...)`, `UnitRole.get_class_cost_table(...)`, etc.). The class body contains only `static func` declarations + `static const` data + a private `static var _coefficients_loaded: bool` lazy-init flag. No `_init` constructor, no `_ready`, no `_process`, no instance fields.

**Optional `@abstract` decoration** (Godot 4.5+ G-13 hardening): the class body is decorated `@abstract` so that `UnitRole.new()` is a **parse-time error on typed references** (`var x: UnitRole = UnitRole.new()` triggers "Cannot construct abstract class" at GDScript reload time; this is the only reliable enforcement point). Reflective paths (`var x: Variant = script.new()` where `script: GDScript = load(...)`) BYPASS `@abstract` entirely and return a live `RefCounted` instance. No `push_error` is emitted by either path. Distinction matters for test authoring: assert structurally via source-file inspection (`FileAccess.get_file_as_string` + `content.contains("@abstract")`), NOT runtime instantiation tests. See G-22 in `.claude/rules/godot-4x-gotchas.md`. Mirrors the `damage_calc_state_mutation` forbidden_pattern enforcement on DamageCalc. **Wording history**: original ADR text said "parse-time error"; /architecture-review 2026-04-28 Item 1 corrected to "runtime error" based on engine-reference doc reading; empirical testing during unit-role/story-001 round 3 (2026-04-28) re-corrected to "parse-time-on-typed-reference with reflective bypass" — the precise reality. Both prior wordings were close-but-wrong; this is the third and authoritative formulation.

**Source location**: `src/foundation/unit_role.gd`.

Rejected alternatives in §Alternatives Considered.

### 2. UnitClass Enum (typed parameter binding)

```gdscript
class_name UnitRole
extends RefCounted

enum UnitClass {
    CAVALRY = 0,
    INFANTRY = 1,
    ARCHER = 2,
    STRATEGIST = 3,
    COMMANDER = 4,
    SCOUT = 5,
}
```

Public method signatures bind the typed enum: `static func get_atk(hero: HeroData, unit_class: UnitRole.UnitClass) -> int`. Parse-time type errors at call sites are stricter than raw `int` (per godot-specialist 2026-04-28). This improves on ADR-0008's raw `int terrain_type` pattern; the divergence is intentional and forward-compatible — ADR-0008's terrain_type enum may be retrofitted in a future amendment without breaking ADR-0009 call sites.

Cross-script consumers reference the enum as `UnitRole.UnitClass.CAVALRY` (full qualified name) when constructing `AttackerContext` etc. The enum is also serializable to int for storage in `entities.yaml` (`CLASS_DIRECTION_MULT` keys: `0`, `1`, `2`, `3`, `4`, `5`).

### 3. Public API Surface (8 static methods + 1 const)

```gdscript
# Derived stats — one method per GDD F-1..F-4 formula (orthogonal; each consumer
# calls only what it needs):
static func get_atk(hero: HeroData, unit_class: UnitRole.UnitClass) -> int
static func get_phys_def(hero: HeroData, unit_class: UnitRole.UnitClass) -> int
static func get_mag_def(hero: HeroData, unit_class: UnitRole.UnitClass) -> int
static func get_max_hp(hero: HeroData, unit_class: UnitRole.UnitClass) -> int
static func get_initiative(hero: HeroData, unit_class: UnitRole.UnitClass) -> int

# Move range — F-5; move_budget is a consumer-side compute (range × MOVE_BUDGET_PER_RANGE):
static func get_effective_move_range(hero: HeroData, unit_class: UnitRole.UnitClass) -> int

# Cost matrix unit-class dimension (consumed by Map/Grid Dijkstra):
static func get_class_cost_table(unit_class: UnitRole.UnitClass) -> PackedFloat32Array

# Class direction multiplier (consumed by Damage Calc F-DC-3):
static func get_class_direction_mult(
    unit_class: UnitRole.UnitClass,
    direction: int  # ATK_DIR_FRONT=0 / FLANK=1 / REAR=2 per ADR-0004 §5b
) -> float

# Canonical passive-tag mapping (consumed by AI / Damage Calc / Battle HUD):
const PASSIVE_TAG_BY_CLASS: Dictionary = {
    UnitClass.CAVALRY:    &"passive_charge",
    UnitClass.INFANTRY:   &"passive_shield_wall",
    UnitClass.ARCHER:     &"passive_high_ground_shot",
    UnitClass.STRATEGIST: &"passive_tactical_read",
    UnitClass.COMMANDER:  &"passive_rally",
    UnitClass.SCOUT:      &"passive_ambush",
}
```

**8 static methods + 1 const Dictionary**. Bundled `derive_unit_stats(hero, class) -> UnitStats` Resource explicitly **rejected** in §Alternatives — orthogonal per-stat methods avoid coupling consumers to the full derivation cost.

### 4. Config Schema and Loading

**Per-class coefficients** are loaded from `assets/data/config/unit_roles.json` (this system's config, parallel to ADR-0008's `assets/data/terrain/terrain_config.json`). Schema (top-level: 6 class entries keyed by lowercase class name):

```json
{
  "cavalry": {
    "primary_stat": "stat_might",
    "secondary_stat": null,
    "w_primary": 1.0,
    "w_secondary": 0.0,
    "class_atk_mult": 1.1,
    "class_phys_def_mult": 0.8,
    "class_mag_def_mult": 0.7,
    "class_hp_mult": 0.9,
    "class_init_mult": 0.9,
    "class_move_delta": 1,
    "passive_tag": "passive_charge",
    "terrain_cost_table": [1.0, 1.0, 1.5, 2.0, 3.0, 1.0],
    "class_direction_mult": [1.0, 1.1, 1.09]
  },
  "infantry": { ... },
  ...
}
```

**Schema fields per class** (12): `primary_stat`, `secondary_stat`, `w_primary`, `w_secondary`, `class_atk_mult`, `class_phys_def_mult`, `class_mag_def_mult`, `class_hp_mult`, `class_init_mult`, `class_move_delta`, `passive_tag`, `terrain_cost_table` (6-entry array indexed by terrain_type enum), `class_direction_mult` (3-entry array indexed by ATK_DIR enum).

**Global caps** are read via `BalanceConstants.get_const(key)` per ADR-0006: `ATK_CAP`, `DEF_CAP`, `HP_CAP`, `HP_SCALE`, `HP_FLOOR`, `INIT_CAP`, `INIT_SCALE`, `MOVE_RANGE_MIN`, `MOVE_RANGE_MAX`, `MOVE_BUDGET_PER_RANGE`. **No** UnitRole code reads `assets/data/balance/balance_entities.json` directly — the access path is exclusively `BalanceConstants.get_const(...)`.

**Loading mechanism**: Lazy-init via instance-form `JSON.new().parse()` (line/col diagnostics on parse error) at first access of any UnitRole method. Safe-default fallback per ADR-0008 precedent — if `unit_roles.json` is missing or malformed, `_load_coefficients()` populates defaults from a hardcoded fallback table matching GDD CR-1 + CR-4 + CR-6a values, logs a `push_error()`, and continues. The cache persists for the GDScript engine session.

### 5. Cost Matrix Unit-Class Dimension Ratification

UnitRole owns the 6 × 6 cost matrix:

| Class \ Terrain | ROAD (0) | PLAINS (1) | HILLS (2) | FOREST (3) | MOUNTAIN (4) | BRIDGE (5) |
|---|---|---|---|---|---|---|
| CAVALRY (0)    | 1.0 | 1.0 | 1.5 | 2.0 | 3.0 | 1.0 |
| INFANTRY (1)   | 1.0 | 1.0 | 1.0 | 1.0 | 1.5 | 1.0 |
| ARCHER (2)     | 1.0 | 1.0 | 1.0 | 1.0 | 2.0 | 1.0 |
| STRATEGIST (3) | 1.0 | 1.0 | 1.5 | 1.5 | 2.0 | 1.0 |
| COMMANDER (4)  | 1.0 | 1.0 | 1.0 | 1.5 | 2.0 | 1.0 |
| SCOUT (5)      | 1.0 | 1.0 | 1.0 | 0.7 | 1.5 | 1.0 |

Values lifted verbatim from `unit-role.md` §CR-4. RIVER (impassable for all) and FORTRESS_WALL (impassable until destroyed) are NOT in this 6-entry table — they are handled at the Map/Grid layer per `unit-role.md` CR-4a as `is_passable_base = false` checks BEFORE cost-table lookup.

`get_class_cost_table(unit_class)` returns the 6-entry row for the requested class as a `PackedFloat32Array`. Map/Grid Dijkstra hot loop: one fetch per `get_movement_range` invocation, then index-reads in the inner loop (no Variant boxing, no per-cell static-method dispatch).

**R-1 (per-call copy semantics)**: `PackedFloat32Array` is COW (copy-on-write) in Godot 4.x; returning a `PackedFloat32Array` from a static method yields a per-call copy at the call site naturally. UnitRole MUST NOT cache and return a shared backing array — GDScript has no `const` reference enforcement, and a caller mutating a cached array would silently corrupt subsequent calls. Codified as forbidden_pattern candidate `unit_role_returned_array_mutation` (registered at Step 6 if approved).

### 6. Class Direction Multiplier Ratification

UnitRole ratifies (does not negotiate) the 6 × 3 `CLASS_DIRECTION_MULT` table locked by `unit-role.md` §CR-6a + §EC-7 + `entities.yaml`:

| Class \ Direction | FRONT (0) | FLANK (1) | REAR (2) |
|---|---|---|---|
| CAVALRY (0)    | 1.0 | 1.1   | 1.09 |
| INFANTRY (1)   | 0.9 | 1.0   | 1.1  |
| ARCHER (2)     | 1.0 | 1.375 | 0.9  |
| STRATEGIST (3) | 1.0 | 1.0   | 1.0  |
| COMMANDER (4)  | 1.0 | 1.0   | 1.0  |
| SCOUT (5)      | 1.0 | 1.0   | 1.1  |

**Cavalry REAR=1.09** is the rev 2.8 Rally-ceiling-fix value (was 1.20 pre rev 2.8) per damage-calc.md ninth-pass cross-doc desync audit BLK-G-2. ADR-0009 ratifies the post-fix value as the authoritative source; any future amendment to this table requires `/propagate-design-change` against unit-role.md + damage-calc.md + entities.yaml in a single patch.

`get_class_direction_mult(unit_class, direction)` is a single bracket-index lookup into `CLASS_DIRECTION_MULT` loaded from `unit_roles.json` (per-class `class_direction_mult` array) — **NOT** read via `BalanceConstants.get_const("CLASS_DIRECTION_MULT")`. The `entities.yaml` `CLASS_DIRECTION_MULT` registration is a **design-side** registry entry tracking cross-system referenced_by; the runtime read goes through `unit_roles.json` for consistency with the per-class config locality (every other per-class coefficient — `class_atk_mult`, `class_hp_mult`, etc. — also lives in `unit_roles.json`, not entities.json). Damage Calc reads via UnitRole's accessor, not via `BalanceConstants`.

### 7. Passive Tag Canonicalization

The 6 StringName tags are **locked** as the canonical passive set:

```gdscript
&"passive_charge"             # CAVALRY
&"passive_shield_wall"        # INFANTRY
&"passive_high_ground_shot"   # ARCHER
&"passive_tactical_read"      # STRATEGIST
&"passive_rally"              # COMMANDER
&"passive_ambush"             # SCOUT
```

Exposed via `const PASSIVE_TAG_BY_CLASS: Dictionary` keyed by `UnitClass` enum int. `Array[StringName]` is the mandatory typed-array form for any consumer assembling passive-tag sets per `damage_calc_dictionary_payload` forbidden_pattern (`Array[String]` is a silent-wrong-answer hole — see ADR-0012 EC-DC-25 / AC-DC-51).

Adding a 7th passive tag requires an ADR-0009 amendment + propagate-design-change pass against unit-role.md (CR-2 row addition) + damage-calc.md (P_mult factor addition if applicable) + AI ADR (decision-tree consumer).

### Architecture Diagram

```
                    ┌──────────────────────────────┐
                    │      UnitRole (Foundation)   │
                    │  class_name + RefCounted     │
                    │  all-static methods (@abstract)
                    │  zero state / zero signals   │
                    └──────────────┬───────────────┘
                                   │
            ┌──────────────────────┼─────────────────────┐
            │ (lazy-init, first    │ (every read         │
            │  access)             │  through accessor)  │
            ▼                      │                      ▼
   assets/data/config/             │              BalanceConstants
   unit_roles.json                 │              .get_const(key)
   (per-class coefficients,        │              (per ADR-0006;
    cost table rows,               │               backed by
    class direction array,         │               balance_entities.json)
    passive_tag per class)         │
                                   │
                                   ▼
            ┌─────────────────────────────────────────┐
            │     8 public static methods             │
            ├─────────────────────────────────────────┤
            │  get_atk / get_phys_def / get_mag_def   │
            │    → Damage Calc, AI                    │
            │  get_max_hp                             │
            │    → HP/Status                          │
            │  get_initiative                         │
            │    → Turn Order                         │
            │  get_effective_move_range               │
            │    → Grid Battle                        │
            │  get_class_cost_table                   │
            │    → Map/Grid (Dijkstra hot loop)       │
            │  get_class_direction_mult               │
            │    → Damage Calc (F-DC-3)               │
            │  PASSIVE_TAG_BY_CLASS (const)           │
            │    → AI, Damage Calc, Battle HUD        │
            └─────────────────────────────────────────┘
```

### Key Interfaces

| Method | Signature | Consumer(s) | Hot-path? |
|---|---|---|---|
| `get_atk` | `(HeroData, UnitClass) -> int [1, ATK_CAP]` | Damage Calc | One-time per unit per battle |
| `get_phys_def` | `(HeroData, UnitClass) -> int [1, DEF_CAP]` | Damage Calc | One-time per unit per battle |
| `get_mag_def` | `(HeroData, UnitClass) -> int [1, DEF_CAP]` | Damage Calc | One-time per unit per battle |
| `get_max_hp` | `(HeroData, UnitClass) -> int [HP_FLOOR+1, HP_CAP]` | HP/Status | One-time per unit per battle |
| `get_initiative` | `(HeroData, UnitClass) -> int [1, INIT_CAP]` | Turn Order | One-time per unit per battle |
| `get_effective_move_range` | `(HeroData, UnitClass) -> int [MOVE_RANGE_MIN, MOVE_RANGE_MAX]` | Grid Battle | Per-turn per unit |
| `get_class_cost_table` | `(UnitClass) -> PackedFloat32Array (6 entries)` | Map/Grid | **YES** — once per `get_movement_range`; ~5-10 calls per turn |
| `get_class_direction_mult` | `(UnitClass, int direction) -> float` | Damage Calc | **YES** — once per `resolve()`; <100 calls per battle |
| `PASSIVE_TAG_BY_CLASS` | `const Dictionary[int, StringName]` (6 entries) | AI, Damage Calc, Battle HUD | Cold (initialization-time read) |

## Alternatives Considered

### Alternative 1: Battle-scoped Node holding per-unit derived stats cache
- **Description**: `class_name UnitRole extends Node`, instantiated once per BattleScene, caches derived stats per unit in a `Dictionary[int, UnitStats]` keyed by unit_id. Methods are instance methods on the cache.
- **Pros**: Single derivation per unit per battle; cache hit on repeated reads (e.g., Damage Calc reading atk for the same unit across multiple turn attacks).
- **Cons**: Stateful — violates GDD §States and Transitions explicit "stateless rule definition layer" contract. Cache invalidation on stat-buff/debuff is a hazard (HP/Status owns runtime stat modifications; a cache layer here would race with HP/Status's `get_modified_stat` accessor per ADR-0012 §Dependencies). Per-battle init/teardown adds boilerplate. ADR-0008 precedent rejected the same form for an analogous Foundation calculator.
- **Rejection Reason**: Stateful caching contradicts GDD invariant + introduces cache-invalidation correctness bug surface that the orthogonal stateless form does not have. The "redundant derivation" cost is negligible (<0.05ms × 12 units × 1 derivation per battle = <0.6ms one-time at battle init).

### Alternative 2: Autoload singleton at `/root/UnitRole`
- **Description**: Register UnitRole as autoload load order 4 (after GameBus / SceneManager / SaveManager). Methods are instance methods on the autoload Node.
- **Pros**: Single global access point; no `class_name` global identifier lookup.
- **Cons**: No shared state to own (GDD §States and Transitions invariant). ADR-0008 + ADR-0006 + ADR-0012 all chose `class_name X extends RefCounted` over autoload for stateless calculators — pattern is established at 3+ invocations. Autoload introduces test-isolation friction (every test scene starts the autoload Node lifecycle); G-15 BalanceConstants pattern explicitly avoids autoload for this reason. Test isolation easier with `class_name` global per ADR-0006 §6.
- **Rejection Reason**: No state to motivate autoload; established 3-precedent class_name pattern; test-isolation friction.

### Alternative 3: StringName-tag UnitClass representation
- **Description**: `unit_class` is `StringName` (`&"cavalry"`, `&"infantry"`, etc.). Lookup via Dictionary keyed by StringName.
- **Pros**: More readable in logs and test fixtures; aligns with passive-tag StringName precedent.
- **Cons**: Slower than int enum bracket index (StringName Dictionary lookup ≈ hash + comparison; int array bracket index = direct offset). Re-opens the silent-fail surface ADR-0012 EC-DC-25 / AC-DC-51 closed for `Array[String]` vs `Array[StringName]` — `unit_class == "cavalry"` (String) vs `unit_class == &"cavalry"` (StringName) is a parse-passing runtime mismatch. The 6-entry enum is small and fixed; readability gain is marginal.
- **Rejection Reason**: Performance + silent-fail risk + no tangible readability win at 6-entry scale.

### Alternative 4: Single bundled `derive_unit_stats(hero, class) -> UnitStats` Resource
- **Description**: One method returns a `UnitStats` typed Resource with all 5 derived stats (`atk`, `phys_def`, `mag_def`, `max_hp`, `initiative`) populated. Consumers read fields off the Resource.
- **Pros**: One call site per unit per battle; symmetric with ADR-0012's `ResolveResult` Resource bundling.
- **Cons**: Couples consumers to the full derivation cost — Damage Calc that only needs `atk` pays for `phys_def` / `mag_def` / `max_hp` / `initiative` derivation it does not use. Partial-derivation optimization is not free (premature). Resource construction overhead per derivation. Adds one Resource file (`src/foundation/unit_stats.gd`) without clear consumer that needs the bundle.
- **Rejection Reason**: No consumer needs the bundle; orthogonal per-stat methods are simpler and avoid coupling.

## Consequences

### Positive

- 7 downstream consumers unblocked (Damage Calc, Grid Battle, Turn Order, AI, Battle Preparation, Equipment/Item, Formation Bonus, HP/Status) with a single grep-able rule layer.
- Ratifies ADR-0008's cost-matrix unit-class dimension placeholder (line 47) without re-negotiation — ADR-0008 ships uniform=1; ADR-0009 fills the matrix.
- Ratifies ADR-0012's `CLASS_DIRECTION_MULT[6][3]` locked values without re-negotiation — values pre-locked by GDD CR-6a + entities.yaml registration.
- Orthogonal API: each consumer (Damage Calc / HP-Status / Turn Order / Grid Battle / AI / Battle HUD) reads only what it needs; no coupling to bundled derivations.
- Reuses the 3-precedent `class_name X extends RefCounted` + all-static + JSON config pattern (ADR-0008 → ADR-0006 → ADR-0012 → ADR-0009); pattern is now stable at 4 invocations.
- Improves on ADR-0008's raw-int parameter pattern via typed `UnitClass` enum binding; godot-specialist validated this divergence.

### Negative

- 5-6 separate stat-derivation calls per unit per battle (vs 1 bundled call). Cumulative <0.6ms per battle init — measurable but well inside the 16.6ms frame budget (one-time, not per-frame).
- `HeroData` typed-Resource parameter shape is coupled to unwritten ADR-0007 Hero DB. Soft-dep documented; migration is parameter-stable (call sites unchanged when ADR-0007 ratifies HeroData shape).
- The `CLASS_DIRECTION_MULT` runtime read goes through `unit_roles.json` (not `entities.yaml` / `balance_entities.json`), creating a documentation-vs-runtime asymmetry: the design-side registry entry in `entities.yaml` is for cross-system referenced_by tracking; the runtime read is per-class data locality. This is a known divergence — explicit comment in `unit_roles.json` schema header + ADR-0009 §6 prose make the asymmetry traceable.

### Risks

**R-1: PackedFloat32Array caller-mutation silent corruption**
- **Description**: `get_class_cost_table()` returns a `PackedFloat32Array`; if a future implementation caches and returns a shared backing array, a caller mutating the array would corrupt subsequent calls — silent-fail.
- **Probability**: LOW (Godot 4.x COW handles per-call copy naturally for PackedFloat32Array; the risk is a future "optimization" PR that adds caching).
- **Impact**: HIGH (silent correctness bug; pathfinding produces wrong movement ranges; no test would catch it without explicit caller-mutation regression).
- **Mitigation**: (1) Codify as forbidden_pattern `unit_role_returned_array_mutation` in architecture registry. (2) Unit test in `unit_role_test.gd`: call `get_class_cost_table(CAVALRY)`, mutate the returned array, call `get_class_cost_table(CAVALRY)` again, assert original values returned. (3) Source-comment in `unit_role.gd` above the method declaration: `# RETURNS PER-CALL COPY — DO NOT cache and return shared array.`

**R-2: BalanceConstants._cache_loaded leakage between tests**
- **Description**: GdUnit4 test suites that call any UnitRole method that transitively reads global caps via `BalanceConstants.get_const(...)` inherit ADR-0006's test-isolation obligation.
- **Probability**: HIGH (every UnitRole test suite will read global caps).
- **Impact**: MEDIUM (intermittent test failures; cache state from a prior test leaks into the current test).
- **Mitigation**: G-15 codified before_test() reset (already standard project pattern at 6+ test suites). Source-comment in `unit_role_test.gd` template: `# G-15: BalanceConstants._cache_loaded reset is MANDATORY in before_test().`

**R-3: ADR-0007 HeroData shape drift**
- **Description**: When ADR-0007 Hero DB is written and ratifies the `HeroData` Resource shape, fields may rename or reshape (e.g., `stat_might` → `stat_strength`).
- **Probability**: LOW (`hero-database.md` GDD §Detailed Rules locks the field set as Designed).
- **Impact**: MEDIUM (every UnitRole stat-derivation method's field-access site breaks; mechanical refactor).
- **Mitigation**: ADR-0009 §Dependencies soft-dep clause + Migration Plan pre-documents the parameter-stable migration pattern. ADR-0007 ratification triggers `/propagate-design-change` against unit-role.md + ADR-0009 §Migration Plan.

**R-4: GDD prose stale on `balance_constants.json`**
- **Description**: `unit-role.md` rev 2026-04-16 references `assets/data/config/balance_constants.json` (8+ touch points). ADR-0006 ratified `BalanceConstants.get_const(key)` backed by `assets/data/balance/balance_entities.json`. The GDD prose is stale.
- **Probability**: HIGH (already stale at ADR-0009 authoring time).
- **Impact**: LOW-MEDIUM (developer reading the GDD before ADR-0006/ADR-0009 implements against the wrong file path; caught at first test run).
- **Mitigation**: GDD updated alongside ADR-0009 Acceptance — prose preface in §Formulas section pointing to ADR-0006 + line 244 + line 606 + Tuning Knobs Source-column edits. **Single-patch with this ADR's Write approval.**

## GDD Requirements Addressed

| GDD AC / Section | Requirement | How ADR-0009 Addresses It |
|---|---|---|
| AC-1 (F-1 ATK) | `atk` integer in `[1, ATK_CAP]` for all 6 classes | §3 `get_atk(hero, unit_class) -> int` reads class coefficients from `unit_roles.json` + `ATK_CAP` from BalanceConstants |
| AC-2 (F-2 DEF split) | `phys_def` / `mag_def` in `[1, DEF_CAP]`; PHYSICAL→phys_def, MAGICAL→mag_def | §3 separate `get_phys_def` / `get_mag_def` methods (orthogonal); attack_type routing owned by Damage Calc per CR-1a |
| AC-3 (F-3 HP) | `max_hp` in `[HP_FLOOR+1, HP_CAP]` (EC-14 minimum 51) | §3 `get_max_hp` implements `clamp(floor(seed × class_hp_mult × HP_SCALE) + HP_FLOOR, HP_FLOOR, HP_CAP)`; BalanceConstants caps |
| AC-4 (F-4 Init) | `initiative` in `[1, INIT_CAP]`; Scout highest at base_init=80 → 192 | §3 `get_initiative` reads `class_init_mult` from `unit_roles.json` + `INIT_CAP` / `INIT_SCALE` from BalanceConstants |
| AC-5 (F-5 Move Range) | clamp `[MOVE_RANGE_MIN, MOVE_RANGE_MAX]`; EC-1, EC-2 cases | §3 `get_effective_move_range` implements `clamp(hero.move_range + class_move_delta, MOVE_RANGE_MIN, MOVE_RANGE_MAX)`; BalanceConstants bounds |
| AC-6..AC-11 (Class Passives) | 6 passives with activation gates | §7 `PASSIVE_TAG_BY_CLASS` const + per-passive logic owned by consumers (Damage Calc / HP-Status / Turn Order); UnitRole owns the canonical tag set |
| AC-12 (Cost matrix accuracy) | `floor(base × class_multiplier)` per CR-4 table | §5 `get_class_cost_table` returns the 6-entry row; Map/Grid Dijkstra applies `floori()` |
| AC-13 (Cavalry MOUNTAIN budget) | EC-3, EC-4 path-order dependent | §5 cost table value `3.0` × MOUNTAIN base `20` × `floori` = 60 cost; Map/Grid `remaining_budget >= tile_cost` enforcement |
| AC-14 (Scout FOREST = PLAINS) | EC-5 floor load-bearing | §5 cost table value `0.7` × FOREST base `15` = 10.5; Map/Grid `floori` floors to 10 (matches PLAINS); `floor` is owned by Map/Grid Dijkstra, not UnitRole |
| AC-15 (RIVER / FORTRESS_WALL impassable) | CR-4a | §5 NOT in the 6-entry table — handled at Map/Grid layer via `is_passable_base = false` |
| AC-16 (Direction mult — Cavalry REAR + Charge = 1.97) | CR-6 + CR-6b + EC-7 | §6 `get_class_direction_mult(CAVALRY, REAR) = 1.09`; Damage Calc applies × Charge × base REAR per F-DC-3/F-DC-5 |
| AC-17 (Scout REAR + Ambush = 1.897) | CR-6b | §6 `get_class_direction_mult(SCOUT, REAR) = 1.1`; Damage Calc applies × Ambush per P_mult |
| AC-18..AC-19 (Skill Slot Rules) | CR-5a..5d | §3 NOT in UnitRole's API surface for MVP — `class_pools.json` schema (CR-5c) deferred to Battle Preparation epic; UnitRole's only contribution is `passive_tag` per class (CR-2) |
| AC-20 (Data-driven, no hardcoded gameplay values) | All coefficients/caps from data files | §4 per-class coefficients in `unit_roles.json`; global caps via BalanceConstants (no literal numeric constants in `unit_role.gd` matching the 10 cap names) |
| AC-21 (Hot-reload on data change) | Modifying `unit_roles.json` takes effect on next battle | §4 lazy-init at first-access ⇒ session-persistent cache. **Limitation**: hot-reload requires editor restart in MVP (matches ADR-0006 §6 BalanceConstants behavior); editor-time reload is deferred to a future Alpha-tier ADR |
| AC-22 (Damage Calc contract) | atk/phys_def/mag_def/passive tags/direction mult | §3 + §6 + §7 — all 4 contracts satisfied via 4 separate accessor methods |
| AC-23 (Grid Battle contract) | effective_move_range / move_budget / cost table / attack_range | §3 + §5 — `effective_move_range` + cost table covered; `move_budget = effective_move_range × MOVE_BUDGET_PER_RANGE` (consumer compute); `attack_range` from `unit_roles.json` per-class field (NOT exposed as a separate UnitRole method — Battle Preparation reads directly from `unit_roles.json` for now; future amendment if needed) |

## Performance Implications

- **CPU per derived-stat method**: <0.05ms (single arithmetic + clamp + `BalanceConstants.get_const` read).
- **CPU per `get_class_cost_table`**: <0.01ms (single `PackedFloat32Array` per-call copy from cached row).
- **CPU per `get_class_direction_mult`**: <0.01ms (single bracket index into cached 6×3 table).
- **CPU per battle-init derivation pass**: <0.6ms total (5 derived-stat methods × 12 units = 60 calls × 0.05ms = 3ms — actually well inside the 16.6ms one-time budget at battle init).
- **CPU per `get_movement_range` Dijkstra invocation**: <0.01ms cost-table fetch + ~300 indexed-reads in inner loop (Map/Grid budget, not UnitRole's).
- **Memory**: <2KB for cached `unit_roles.json` parse (6 classes × ~12 fields × 8 bytes ≈ 600 bytes typical; cap ≈ 2KB with Dictionary overhead). Plus 6 × `PackedFloat32Array` copies in transient call frames (~24 bytes each, GC-collected per call).
- **Load Time**: <5ms one-time JSON parse at first method call (deferred from boot).
- **Network**: N/A (local, deterministic).

## Migration Plan

### From current state (no UnitRole module exists)

1. **Create `src/foundation/unit_role.gd`**: `class_name UnitRole extends RefCounted` + `@abstract` + `enum UnitClass` + 8 static methods + `const PASSIVE_TAG_BY_CLASS`.
2. **Create `assets/data/config/unit_roles.json`**: 6 class entries with the 12-field schema per §4. Values lifted from GDD CR-1, CR-4, CR-6a, F-1..F-5 coefficient tables.
3. **Create `src/foundation/hero_data.gd`**: `class_name HeroData extends Resource` with @export-annotated fields per `hero-database.md` §Detailed Rules. Provisional shape; ADR-0007 will ratify.
4. **Add `MOVE_BUDGET_PER_RANGE = 10` constant to `assets/data/balance/balance_entities.json`**: cross-doc obligation per ADR-0006 §3 — UnitRole uses the constant in `move_budget` documentation; consumers (Grid Battle) read via `BalanceConstants.get_const("MOVE_BUDGET_PER_RANGE")`. Single-line append; lint-script reference unchanged.
5. **Update GDD `design/gdd/unit-role.md`** prose references from `balance_constants.json` → `BalanceConstants.get_const(...)` per ADR-0006 + this ADR. **Single-patch with ADR-0009 Write approval.**
6. **Register architecture registry candidates** at Step 6: state ownership (`class_profile_table` → unit-role); interface contract (`unit_role_queries`, direct_call, 1 producer + 7 consumers); api_decisions (`unit_role_module_form`); 2 forbidden_patterns (`unit_role_returned_array_mutation`, `unit_role_signal_emission`).

### From provisional `HeroData` to ADR-0007-ratified shape (when ADR-0007 lands)

1. ADR-0007 authoring and Acceptance ratifies the `HeroData` Resource definition.
2. If field renames occur (LOW probability): `/propagate-design-change` against `unit-role.md` + ADR-0009 + UnitRole call-sites + tests.
3. If field-set expansion only (HIGH probability): no UnitRole changes; new `HeroData` fields are inert to UnitRole's read set.
4. Migration is parameter-stable: `static func get_atk(hero: HeroData, unit_class: UnitRole.UnitClass) -> int` signature unchanged.

### From locked direction multipliers to future tuning revisions

1. Any change to the 6×3 `CLASS_DIRECTION_MULT` table requires `/propagate-design-change` against `unit-role.md` (§CR-6a + §EC-7) + `damage-calc.md` (F-DC-3 references) + `entities.yaml` (CLASS_DIRECTION_MULT registry value) + `unit_roles.json` runtime values + this ADR (§6 ratified table).
2. Sweep + narrow re-review pattern is mandatory for any cross-doc value update (validated 4× across damage-calc revs 2.8.1, 2.9.0, 2.9.2, 2.9.3 per damage-calc review log).

## Validation Criteria

This ADR is correct if all of the following hold after implementation:

1. **23 GDD ACs covered**: §GDD Requirements Addressed table maps every AC-1..AC-23 to an ADR-0009 section. AC-21 (hot-reload) has a documented MVP limitation (editor restart required) that matches ADR-0006 BalanceConstants behavior.
2. **Test coverage**: 100% on F-1..F-5 formulas (per technical-preferences.md "balance formulas 100%"). 80%+ on cost table, direction mult, passive tag set, error/fallback paths.
3. **G-15 test isolation**: every UnitRole test suite calling any method that transitively reads BalanceConstants resets `_cache_loaded = false` in `before_test()`. Static-lint check post-implementation: `grep -L "_cache_loaded = false" tests/unit/foundation/unit_role*.gd` returns empty.
4. **Static lint — non-emitter invariant**: `grep -E '(signal\s|connect\(|emit_signal\()' src/foundation/unit_role.gd` returns zero matches. Mirrors ADR-0012 forbidden_pattern `damage_calc_signal_emission`.
5. **Static lint — no hardcoded global caps**: `grep -E '\b(200|100|300|2\.0|50|6|2)\b' src/foundation/unit_role.gd | grep -v "BalanceConstants.get_const"` flags any literal that matches a global-cap value without going through the accessor. False-positive list maintained in `tools/ci/` (e.g., array indices).
6. **R-1 mitigation test**: `tests/unit/foundation/unit_role_test.gd::test_get_class_cost_table_caller_mutation_isolated` — fetches table, mutates returned array, fetches again, asserts original values. Test MUST pass.
7. **R-3 soft-dep clause executable**: when ADR-0007 lands, this ADR's Migration Plan §"From provisional HeroData to ADR-0007-ratified shape" is the runbook. No surprise refactor.
8. **Per-method latency budget**: headless CI throughput baseline test in `tests/unit/foundation/unit_role_perf_test.gd` (mirrors damage-calc story-010 pattern); on-device measurement deferred per Polish-deferral pattern (5+ invocations).
9. **GDD sync complete**: `unit-role.md` references to `balance_constants.json` updated to `BalanceConstants.get_const(...)` per ADR-0006 + this ADR (single-patch with Write approval).

## Related Decisions

- `docs/architecture/ADR-0001-gamebus-autoload.md` — UnitRole on non-emitter list; zero signals in / out.
- `docs/architecture/ADR-0006-balance-data.md` — `BalanceConstants.get_const(key)` accessor for global caps; G-15 test-isolation obligation; data file at `assets/data/balance/balance_entities.json`.
- `docs/architecture/ADR-0008-terrain-effect.md` — architectural-form precedent (`class_name X extends RefCounted` + all-static + JSON config + lazy-init); cost-matrix structure declaration with unit-class dimension explicitly deferred to ADR-0009.
- `docs/architecture/ADR-0012-damage-calc.md` — `CLASS_DIRECTION_MULT[6][3]` table consumer; `Array[StringName]` typed-array passive contract; `damage_calc_signal_emission` forbidden_pattern precedent for the non-emitter invariant.
- `design/gdd/unit-role.md` (Designed, rev 2026-04-16) — authoritative GDD source for all 6 classes, F-1..F-5 formulas, CR-1..CR-6 rules, EC-1..EC-17 edge cases, AC-1..AC-23 acceptance criteria.
- `design/registry/entities.yaml` — 12 constants registered with `source: unit-role.md`; `CLASS_DIRECTION_MULT` and `CHARGE_BONUS` / `AMBUSH_BONUS` cross-system referenced_by tracking.
- `.claude/rules/godot-4x-gotchas.md` G-15 — `BalanceConstants._cache_loaded` reset in before_test().
- `docs/architecture/control-manifest.md` (Manifest Version 2026-04-20) — Foundation-layer programmer rules.
