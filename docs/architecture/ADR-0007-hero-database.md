# ADR-0007: Hero Database — HeroData Resource + HeroDatabase Static Query Layer (MVP scope)

## Status

Accepted (2026-04-30, escalated via `/architecture-review` delta — 9th Accepted ADR; first ratifies provisional `src/foundation/hero_data.gd` shipped 2026-04-28 under ADR-0009 §Migration Plan §3 soft-dep; 2 pre-acceptance wording corrections applied per godot-specialist Item 3 + Item 8 — see `docs/architecture/architecture-review-2026-04-30.md`)

## Date

2026-04-29

## Last Verified

2026-04-29

## Decision Makers

- User (Sprint scheduling authorization, 2026-04-29 — `/architecture-decision hero-database` invocation)
- Technical Director (architecture owner — ratification of 5th-precedent stateless-static pattern)
- godot-specialist (engine validation — pending Step 4.5; this draft will be revised per validation feedback before Write approval)

---

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Foundation — content-data layer (parallel to ADR-0006 BalanceConstants for tuning constants; ADR-0007 owns hero records) |
| **Knowledge Risk** | **LOW** — `class_name`, `RefCounted`, `Resource`, `@export`, `FileAccess.get_file_as_string()`, `JSON.new().parse()` instance form, `Dictionary` keyed by `StringName`, `Array[Resource]`, `Array[StringName]`, `Array[int]`, typed enum `@export` storage are all pre-Godot-4.4 and stable. No post-cutoff APIs. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `design/gdd/hero-database.md` (Designed, rev 2026-04-16), `docs/architecture/ADR-0001-gamebus-autoload.md` (non-emitter list), `docs/architecture/ADR-0003-save-load.md` (TR-save-load-002 @export discipline), `docs/architecture/ADR-0006-balance-data.md` (BalanceConstants pattern + JSON loading precedent), `docs/architecture/ADR-0008-terrain-effect.md` (architectural-form precedent #1), `docs/architecture/ADR-0009-unit-role.md` (4-precedent pattern + provisional HeroData soft-dep), `docs/architecture/ADR-0012-damage-calc.md` (typed-RefCounted wrappers + Array[StringName] discipline), `src/foundation/hero_data.gd` (provisional Resource, 10 fields, shipped 2026-04-28), `docs/registry/architecture.yaml` (cross-stance review), `.claude/rules/godot-4x-gotchas.md` (G-12 class_name collision, G-15 cache-isolation, G-22 @abstract semantics, G-14 class-cache refresh). |
| **Post-Cutoff APIs Used** | None. |
| **Verification Required** | (1) `HeroData` `class_name` does NOT collide with any Godot 4.6 built-in (per G-12: `HeroData` is project-scoped; verified non-colliding). (2) `Array[HeroData]` typed-array auto-coercion works in Godot 4.6 for the query return values (per G-2 typed-array discipline). (3) `Dictionary` keyed by `StringName` lookup performance is O(1) for the 8-10-hero MVP (50-100 entry Alpha forecast still O(1)). (4) `HeroDatabase._heroes_loaded` reset in `before_test()` for every GdUnit4 suite that calls any HeroDatabase method (per G-15 + ADR-0006 §6 obligation). (5) `JSON.new().parse()` instance form for line/col diagnostics on parse error (per ADR-0009 §4 precedent + ADR-0008 `_load_config` pattern). |

> **Knowledge Risk Note**: Domain is **LOW** risk. No post-cutoff API surface. Future Godot 4.7+ that touches `Resource.duplicate_deep()` semantics or `JSON.parse_string` Variant return would trigger Superseded-by review. None projected as of pin date.

---

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (GameBus, Accepted 2026-04-18) — HeroDatabase is on the **non-emitter list**; zero signals emitted, zero subscriptions. ADR-0006 (Balance/Data, Accepted 2026-04-26) — `BalanceConstants.get_const(key)` is the canonical accessor for any Hero-DB-side validation thresholds (e.g., `STAT_TOTAL_MIN`, `STAT_TOTAL_MAX`); for MVP the validation thresholds are **not** consumed at runtime by HeroDatabase (validation is build-time tooling per §6); the dependency is forward-compat for the Polish-tier validator story. ADR-0009 (Unit Role, Accepted 2026-04-28) — `HeroData.default_class` field is an int storage of the `UnitRole.UnitClass` enum; field-value semantics align 1:1 with the 6-entry enum (CAVALRY=0..SCOUT=5). |
| **Soft / Provisional** | (1) **Formation Bonus ADR (NOT YET WRITTEN — soft / provisional downstream)**: `relationships: Array[Dictionary]` field shape is provisional; the four-field record (`hero_b_id`, `relation_type`, `effect_tag`, `is_symmetric`) is locked by GDD CR-2, but the `effect_tag` String → typed-effect-Resource migration is owned by Formation Bonus ADR. ADR-0007 ships with `Array[Dictionary]` provisional; migration is parameter-stable (call site `HeroDatabase.get_relationships(hero_id)` shape unchanged when typed Resource lands). Mirrors ADR-0009's soft-dep pattern for unwritten upstream ADRs. (2) **Scenario Progression ADR (NOT YET WRITTEN — soft / provisional downstream)**: `join_condition_tag: String` field is stored as opaque String for MVP; tag interpretation is owned by Scenario Progression ADR (or Story Event ADR). ADR-0007 only enforces the field's presence + non-null type; tag-vocabulary canonicalization is deferred. (3) **Equipment/Item ADR (NOT YET WRITTEN — soft / provisional downstream)**: `equipment_slot_override: Array[int]` field stores int values whose semantic mapping (WEAPON=0, ARMOR=1, MOUNT=2, ACCESSORY=3 per GDD CR-2) is canonicalized by Equipment ADR. ADR-0007 enforces shape only; semantic int → enum binding deferred. |
| **Enables** | (1) **Ratifies** ADR-0009 (Unit Role) §Dependencies "Soft / Provisional" upstream clause on `HeroData` Resource shape (line 35). When ADR-0007 is Accepted, ADR-0009's soft-dep clause closes; the soft-dep clause is replaced with hard `Depends On ADR-0007` reference in the same patch. (2) **Closes** the only outstanding soft-dep from the Foundation/Core/Feature layers as of 2026-04-29. (3) **Unblocks** AI ADR (consumer of `get_heroes_by_class` for threat evaluation), HP/Status ADR (consumer of `get_hero(...).base_hp_seed`), Turn Order ADR (consumer of `get_hero(...).base_initiative_seed`), Damage Calc cross-system contract closure (already consumed transitively via UnitRole; Hero DB ratifies the underlying Resource shape), Battle Preparation epic (consumer of `get_mvp_roster()` for MVP roster scaffolding), Character Growth ADR (consumer of `growth_might/intellect/command/agility` field set), Formation Bonus ADR (consumer of `relationships` field), Scenario Progression ADR (consumer of `join_chapter` + `is_available_mvp`). |
| **Blocks** | hero-database Foundation epic implementation (cannot start any story until this ADR is Accepted); `assets/data/heroes/heroes.json` schema authoring + 8-10 MVP hero record content; the validation lint script `tools/ci/lint_hero_database_validation.sh` (Polish-tier follow-up; F-1..F-4 + EC-1..EC-7 enforcement). |
| **Ordering Note** | Pattern is now stable at **5 invocations** for the stateless-static Foundation/Core calculator form (ADR-0008 → ADR-0006 → ADR-0012 → ADR-0009 → ADR-0007). Cross-ADR consistency is the load-bearing benefit: every Foundation/Core data-layer ADR uses `class_name X extends RefCounted + all-static + lazy-init JSON config + BalanceConstants.get_const(key) for thresholds`. Future Foundation/Core data-layer ADRs (Skill/Ability, Formation Bonus, Equipment/Item, Character Growth) should adopt this pattern unless a domain-specific reason justifies divergence. |

---

## Context

### Problem Statement

`design/gdd/hero-database.md` (Designed, rev 2026-04-16, 4 Core Rules CR-1..CR-4, 4 Formulas F-1..F-4, 10 Edge Cases EC-1..EC-10, 12 Tuning Knobs, 15 Acceptance Criteria) defines the Hero Database as the Foundation-layer content data store for all hero records. 8 systems consume Hero DB read-only (Unit Role, HP/Status, Turn Order, Damage Calc, Formation Bonus, Story Event, Character Growth, Equipment/Item), plus 2 soft consumers (AI, Battle Preparation), plus 1 cross-feature consumer (Scenario Progression).

The architecture cannot proceed cleanly without locking 6 questions:

1. **Module form** — Stateless static utility class (4-precedent ADR-0008/0006/0012/0009 pattern)? Battle-scoped Node? Autoload? GDD §Detailed Rules implicitly states "central registry" but not the implementation form.
2. **HeroData Resource shape ratification** — `src/foundation/hero_data.gd` shipped 2026-04-28 with 10 provisional fields under ADR-0009 §Migration Plan §3 soft-dep clause. Which fields ratify in MVP? Which defer to Alpha or downstream ADRs (Formation Bonus, Scenario Progression, Equipment/Item)?
3. **Storage shape** — Single `heroes.json` file (parallel to ADR-0006 `balance_entities.json` / ADR-0008 `terrain_config.json` / ADR-0009 `unit_roles.json`)? Per-hero `.tres` Resources? Hand-coded const class?
4. **Query API surface** — Which of the 6 GDD-listed query interfaces (`get_hero`, `get_heroes_by_faction`, `get_heroes_by_class`, `get_relationships`, `get_all_hero_ids`, `get_mvp_roster`) ship in MVP? All 6, or a subset?
5. **`default_class` cross-script enum reference** — `HeroData.default_class` stores a `UnitRole.UnitClass` enum value. Storage form: typed enum (`@export var default_class: UnitRole.UnitClass`) or int with semantic comment (`@export var default_class: int  # UnitRole.UnitClass`)? Cross-script `@export` typed-enum has historical Godot 4.x inspector edge cases.
6. **Validation pipeline scope** — F-1 stat total / F-2 SPI / F-3 growth ceiling / F-4 MVP roster validation: runtime in HeroDatabase or build-time tooling (CI lint script)?

### Constraints

**From `design/gdd/hero-database.md` (locked by Foundation-layer GDD review):**

- **CR-1**: hero_id format `^[a-z]+_\d{3}_[a-z_]+$` (e.g., `shu_001_liu_bei`); ID is immutable across the project lifetime.
- **CR-2**: 9 record blocks — Identity (7 fields), Core Stats (4), Derived Seeds (2), Movement (1), Role (2), Growth (4), Skills (2 parallel arrays), Relationships (variable array of 4-field records), Scenario (3).
- **CR-3**: Stat balance guidelines — STAT_TOTAL ∈ [180, 280], min stat gap ≥ 30, no "all-rounder" heroes (Pillar 3).
- **CR-4**: 6-class enum aligns 1:1 with `UnitRole.UnitClass` (CAVALRY, INFANTRY, ARCHER, STRATEGIST, COMMANDER, SCOUT — int 0..5).

**From `design/gdd/hero-database.md` §Interactions with Other Systems**:

- 6 query interfaces required (`get_hero`, `get_heroes_by_faction`, `get_heroes_by_class`, `get_relationships`, `get_all_hero_ids`, `get_mvp_roster`).
- All consumer systems read-only. No runtime mutation of HeroData records by any consumer (per CR §Interactions "읽기 전용 계약").
- Runtime stat changes (level-up, equipment, status effects) are owned by individual consumer systems via "base + modifier" pattern; Hero DB stores only the immutable base.

**From `docs/architecture/ADR-0009-unit-role.md`:**

- §Dependencies "Soft / Provisional" line 35: `HeroData` Resource shape is parameter-locked at the GDD §Detailed Rules level; UnitRole call sites read `hero.stat_might`, `hero.stat_intellect`, `hero.stat_command`, `hero.stat_agility`, `hero.base_hp_seed`, `hero.base_initiative_seed`, `hero.move_range`. Field-set EXTENSIONS by ADR-0007 must NOT rename or reshape these 7 read-fields.
- §Migration Plan §3: "Create `src/foundation/hero_data.gd`: `class_name HeroData extends Resource` with @export-annotated fields per `hero-database.md` §Detailed Rules. Provisional shape; ADR-0007 will ratify."
- §3 Public API line 162: `get_atk(hero: HeroData, unit_class: UnitRole.UnitClass) -> int`. The `HeroData` parameter type is bound at every UnitRole stat-derivation method; ADR-0007 ratification preserves this binding.

**From `docs/architecture/ADR-0006-balance-data.md`:**

- `BalanceConstants.get_const(key)` is the canonical thresholds accessor. F-1..F-4 validation thresholds (STAT_TOTAL_MIN, STAT_TOTAL_MAX, SPI_WARNING_THRESHOLD, MVP_FLOOR_OFFSET, MVP_CEILING_OFFSET) are candidates for `balance_entities.json` entries when the validation tooling is implemented (Polish-tier follow-up).

**From `docs/architecture/ADR-0001-gamebus-autoload.md`:**

- HeroDatabase is on the **non-emitter list** — zero signals emitted, zero subscriptions, zero connections. Mirrors ADR-0006 BalanceConstants + ADR-0009 UnitRole + ADR-0012 DamageCalc precedent.

**From `.claude/docs/technical-preferences.md`:**

- GDScript with static typing mandatory.
- Mobile budgets: 60 fps / 16.6 ms frame budget; 512 MB ceiling.
- Test coverage floor: 80% for gameplay systems; CR-1 ID-format validator + EC-1 duplicate detection + EC-2 skill-array-mismatch detection are blocker bugs (must have unit test coverage).
- AC-15 GDD requirement: `get_mvp_roster()` 100-hero load + Dictionary build under 100ms on PC minimum spec.

**From `.claude/rules/godot-4x-gotchas.md`:**

- G-12: `HeroData` `class_name` is project-scoped; verified non-colliding with Godot 4.6 built-ins (no `HeroData` in `ClassDB.class_exists()`).
- G-14: Class-cache refresh required after creating any new `class_name`-declaring file. ADR-0007 acceptance triggers `godot --headless --import --path .` before first test run.
- G-15: `before_test()` cache reset for any GdUnit4 suite touching HeroDatabase static state.
- G-22: `@abstract` enforces parse-time on typed references only; structural source-file assertion is the test pattern (mirrors UnitRole story-001 pattern).

### Requirements

**Functional**:

- Provide `HeroData` typed Resource ratifying all CR-2 record blocks (or explicitly deferring sub-blocks to downstream ADRs).
- Provide `HeroDatabase` static query layer with 6 read-only methods covering all GDD-listed consumer needs.
- Provide schema validation at load time: hero_id format check, range checks for stats / seeds / move_range / growth rates, parallel-array integrity (skill IDs vs unlock levels).
- Provide severity model: FATAL conditions (CR-1 ID format violation, EC-1 duplicate hero_id, EC-2 skill array mismatch) reject the entire load + `push_error`; WARNING conditions (EC-5 orphan hero_b_id, EC-6 asymmetric relationship conflict) log + continue.
- Provide lazy-init: first call to any `HeroDatabase` method triggers JSON file load + cache build; subsequent calls are O(1) Dictionary lookups.

**Non-functional**:

- `get_hero()` < 0.001ms (Dictionary[StringName, HeroData] lookup).
- `get_heroes_by_faction()` / `get_heroes_by_class()` < 0.05ms for 10-hero MVP (linear scan); pre-built per-faction / per-class indices deferred to Alpha when 30+ heroes ship.
- `get_mvp_roster()` < 0.01ms for 8-10-hero filter.
- 100-hero load + Dictionary build < 100ms (per GDD AC-15).
- Memory: < 50KB cache for 10-hero MVP (~5KB per HeroData × 10 + Dictionary overhead).
- Stateless across battle boundaries: data loaded once per session; survives BattleScene tear-down/instantiation.
- Idempotent: identical inputs always produce identical query results (no random sampling, no time-dependent reads).

---

## Decision

### 1. Module Form — Stateless Static Utility Class (5th-precedent pattern)

`HeroDatabase` is a stateless static utility class with `class_name HeroDatabase extends RefCounted` + `@abstract` decoration (per ADR-0009 §1 + G-22 — typed-reference parse-time block; reflective bypass exists but is non-issue for this class). The class body contains only `static func` declarations + private `static var _heroes_loaded: bool` + `static var _heroes: Dictionary` (keyed by StringName hero_id). No `_init`, no `_ready`, no `_process`, no instance fields, no signals.

**Source location**: `src/foundation/hero_database.gd`.

`HeroData` continues to live at `src/foundation/hero_data.gd` (already shipped; this ADR ratifies the file shape).

Rejected alternatives in §Alternatives Considered.

### 2. HeroData Resource — Ratified MVP Field Set

```gdscript
class_name HeroData
extends Resource

# Identity Block (7 fields)
@export var hero_id: StringName = &""              # CR-1: ^[a-z]+_\d{3}_[a-z_]+$
@export var name_ko: String = ""
@export var name_zh: String = ""
@export var name_courtesy: String = ""             # CR-2: empty string allowed
@export var faction: int = 0                       # HeroData.HeroFaction enum (see below)
@export var portrait_id: String = ""               # asset key — Art Bible owned
@export var battle_sprite_id: String = ""          # asset key — Art Bible owned

# Core Stats Block (4 fields, range [1, 100])
@export var stat_might: int = 1
@export var stat_intellect: int = 1
@export var stat_command: int = 1
@export var stat_agility: int = 1

# Derived Stat Seeds Block (2 fields, range [1, 100])
@export var base_hp_seed: int = 1
@export var base_initiative_seed: int = 1

# Movement Block (1 field, range [2, 6])
@export var move_range: int = 2

# Role Block (2 fields)
@export var default_class: int = 0                 # UnitRole.UnitClass enum value [0, 5]; semantic comment
@export var equipment_slot_override: Array[int] = []  # Equipment ADR canonicalizes int → slot enum

# Growth Block (4 fields, range [0.5, 2.0])
@export var growth_might: float = 1.0
@export var growth_intellect: float = 1.0
@export var growth_command: float = 1.0
@export var growth_agility: float = 1.0

# Skills Block (2 parallel arrays — must be equal length per CR-2 + EC-2)
@export var innate_skill_ids: Array[StringName] = []
@export var skill_unlock_levels: Array[int] = []

# Scenario Block (3 fields)
@export var join_chapter: int = 1                  # 1-indexed
@export var join_condition_tag: String = ""        # Scenario ADR canonicalizes; empty = unconditional
@export var is_available_mvp: bool = false         # MVP roster filter

# Relationships Block (variable; provisional shape)
# NOTE: Resource.duplicate() does NOT deep-copy the inner Dictionaries — callers
# wanting isolation must use Resource.duplicate_deep() (Godot 4.5+). The typed
# Array[HeroRelationship] migration (Formation Bonus ADR) closes this structurally.
@export var relationships: Array[Dictionary] = []  # Formation Bonus ADR canonicalizes → typed Resource


# HeroFaction enum — locally scoped to HeroData (no cross-script enum reference)
enum HeroFaction {
    SHU      = 0,
    WEI      = 1,
    WU       = 2,
    QUNXIONG = 3,
    NEUTRAL  = 4,
}
```

**Total**: 26 `@export` fields + 1 nested enum.

**All `@export` discipline**: per ADR-0003 TR-save-load-002 + `non_exported_save_field` forbidden_pattern. Hero DB is **content data** (not save data), but `@export` is mandatory for two reasons: (a) Inspector authoring round-trip, (b) `ResourceSaver`-based serialization compatibility for future content-pipeline tooling that may dump heroes to `.tres`.

**`default_class: int` (NOT typed `UnitRole.UnitClass`)**: cross-script `@export` typed-enum reference creates a hard load-order coupling between `hero_data.gd` and `unit_role.gd` that is brittle in Godot 4.x Inspector authoring — specifically, **inspector-authoring instability when the cross-script enum type fails to resolve during editor load: the editor may show a bare integer field instead of an enum dropdown** (the binary storage is always int regardless; the risk is editor-time UX, not data corruption — corrected pre-acceptance per architecture-review-2026-04-30 godot-specialist Item 3). Storage as `int` matches the `entities.yaml` `CLASS_DIRECTION_MULT` key form (0..5 ints). UnitRole call sites bind `unit_class: UnitRole.UnitClass` at the parameter level (per ADR-0009 §3) — so type safety is preserved at the boundary. The cross-doc convention (HeroData.default_class int values align 1:1 with UnitRole.UnitClass enum int values) is codified as forbidden_pattern `hero_data_class_enum_drift` in §6.

**`HeroFaction` enum locally scoped**: faction storage is HeroData's own concern; no cross-system consumer needs to import it. Locally scoped enum avoids unnecessary export pollution.

**`Resource` vs `RefCounted` base-class trade-off acknowledgement** (added pre-acceptance per architecture-review-2026-04-30 godot-specialist Item 8): Resource base-class overhead (`resource_path`, `resource_name`, ResourceLoader cache participation, larger base memory footprint than RefCounted) is accepted for the 10-100 MVP/Alpha cache size at ~5KB/record; negligible against the 512MB mobile ceiling. Asymmetry with ADR-0012's `RefCounted` choice for transient typed wrappers (`AttackerContext`, `DefenderContext`, `ResolveModifiers`, `ResolveResult`) is intentional: HeroData is content data with Inspector-authoring + ResourceSaver round-trip use cases; ADR-0012 wrappers are per-call computation contexts with neither.

**Field set deferrals** (downstream ADR ratification required for typed migration):
- `relationships: Array[Dictionary]` — Formation Bonus ADR migrates to `Array[HeroRelationship]` typed Resource sub-class (4 fields per record per CR-2 §Relationships Block).
- `equipment_slot_override: Array[int]` — Equipment/Item ADR canonicalizes int → slot enum mapping.
- `join_condition_tag: String` — Scenario Progression ADR canonicalizes tag vocabulary.

### 3. Storage — Single `heroes.json` File (parallel to ADR-0006 / 0008 / 0009)

**File path**: `assets/data/heroes/heroes.json`

**Schema** (top-level: Dictionary keyed by hero_id String, values are HeroData record literals):

```json
{
  "shu_001_liu_bei": {
    "name_ko": "유비",
    "name_zh": "劉備",
    "name_courtesy": "玄德",
    "faction": 0,
    "portrait_id": "hero_liu_bei_portrait",
    "battle_sprite_id": "hero_liu_bei_battle",
    "stat_might": 50, "stat_intellect": 60, "stat_command": 90, "stat_agility": 50,
    "base_hp_seed": 70, "base_initiative_seed": 60,
    "move_range": 4,
    "default_class": 4,
    "equipment_slot_override": [],
    "growth_might": 1.0, "growth_intellect": 1.2, "growth_command": 1.5, "growth_agility": 1.0,
    "innate_skill_ids": [],
    "skill_unlock_levels": [],
    "join_chapter": 1,
    "join_condition_tag": "",
    "is_available_mvp": true,
    "relationships": []
  },
  "shu_002_guan_yu": { ... },
  ...
}
```

**Loading mechanism**: Lazy-init via instance-form `JSON.new().parse()` on first call to any HeroDatabase static method (line/col diagnostics on parse error per ADR-0009 §4 precedent). Each top-level Dictionary entry is converted into a HeroData Resource instance via field-by-field assignment + per-field range validation. The cache (`Dictionary[StringName, HeroData]`) persists for the GDScript engine session.

**Reject** Alternative B (per-hero `.tres`) — 8-10 file management overhead vs single file; harder to bulk-edit / diff in PR; lower coherence with established 4-precedent `[system].json` storage pattern. Future Alpha (30+ heroes) MAY split into faction-scoped files (`heroes_shu.json`, `heroes_wei.json`, `heroes_wu.json`, `heroes_qunxiong.json`) for diff-locality and reviewer cognition; not a forward-compat constraint for MVP.

### 4. HeroDatabase Public API (6 static methods)

```gdscript
class_name HeroDatabase
extends RefCounted

const _HEROES_JSON_PATH: String = "res://assets/data/heroes/heroes.json"

static var _heroes_loaded: bool = false
static var _heroes: Dictionary[StringName, HeroData] = {}   # typed Dictionary (Godot 4.4+)

# Primary record accessor
static func get_hero(hero_id: StringName) -> HeroData
    # Returns null + push_error on miss (caller treats as blocker bug, NOT degrade-with-default)

# Query accessors — return per-call Array[HeroData] (Godot 4.x typed-array COW; per-call copy)
static func get_heroes_by_faction(faction: int) -> Array[HeroData]
static func get_heroes_by_class(unit_class: int) -> Array[HeroData]   # int = UnitRole.UnitClass value
static func get_all_hero_ids() -> Array[StringName]
static func get_mvp_roster() -> Array[HeroData]                       # filter is_available_mvp == true

# Relationship accessor — provisional Array[Dictionary] until Formation Bonus ADR
static func get_relationships(hero_id: StringName) -> Array[Dictionary]
```

**6 static methods**, mapping 1:1 to GDD §Interactions §"Hero DB가 외부에 노출하는 쿼리 인터페이스" table.

**Return-value discipline**:
- `get_hero` returns `HeroData` (single Resource reference); shared instance reuse is safe because consumers respect the **read-only contract** per CR §Interactions "읽기 전용 계약". A consumer mutating `hero.stat_might` directly is a blocker bug (codified as forbidden_pattern in §6).
- `get_heroes_by_*` / `get_mvp_roster` return `Array[HeroData]` per-call (typed-array COW); the Array is fresh but the HeroData elements are shared references — same read-only contract applies.
- `get_all_hero_ids` returns `Array[StringName]` per-call.
- `get_relationships` returns `Array[Dictionary]` provisional; Dictionary elements are copies (not shared backing) per Godot 4.x Dictionary value semantics.

**Typed-array construction pattern** (G-2 prevention): query implementations MUST construct results as `var result: Array[HeroData] = []` + `result.append(hero)` + `return result` — NOT via `_heroes.values().duplicate()` (which demotes typing per G-2). The `.assign()` discipline is unnecessary at the return site when the local is declared with the typed annotation upfront.

**Index strategy** (MVP linear scan; Alpha pre-built indices):
- For 8-10-hero MVP: `get_heroes_by_faction` and `get_heroes_by_class` perform full-collection linear scan filter. ~10 iterations × ~5 field reads = trivial cost (<0.05ms).
- For 30+-hero Alpha: pre-built `_faction_index: Dictionary[int, Array[StringName]]` and `_class_index: Dictionary[int, Array[StringName]]` populated alongside `_heroes` during `_load_heroes()`. Migration is API-stable (call shape unchanged; internal optimization only).

### 5. Validation Pipeline — Severity-Tiered, Runtime + Build-Time Split

**Runtime validation** (FATAL severity; rejects load):
- **CR-1** ID format check: regex `^[a-z]+_\d{3}_[a-z_]+$` — invalid ID rejects entire load (matches GDD AC-01 + EC-1).
- **EC-1** Duplicate hero_id detection — duplicate keys reject entire load + `push_error` listing the offending ID (matches GDD AC-12).
- **EC-2** Skill parallel-array length mismatch — if `innate_skill_ids.size() != skill_unlock_levels.size()`, reject the offending record only + `push_error` listing hero_id + both sizes (matches GDD AC-13).
- **CR-2 schema range checks** — stats / seeds / move_range / growth rates out of declared range reject the offending record (matches GDD AC-02..AC-05).

**Runtime validation** (WARNING severity; load continues):
- **EC-4** Self-referencing relationship (`hero_b_id == hero_id`) — drop the offending relationship entry, log warning.
- **EC-5** Orphan hero_b_id (FK target missing) — drop the offending relationship entry, log warning. MVP roster excluding Full-Vision heroes is an expected state per GDD EC-5; FK miss is non-fatal.
- **EC-6** Asymmetric relationship conflict (A→B is RIVAL, B→A is SWORN_BROTHER) — load both relationships, log design-warning. Formation Bonus ADR adjudicates conflict resolution.

**Build-time validation** (DEFERRED to Polish-tier follow-up tooling story):
- **F-1** Stat total in [STAT_TOTAL_MIN, STAT_TOTAL_MAX] — implemented as `tools/ci/lint_hero_database_validation.sh` (mirrors AC-DC-48 hardcoded-constants lint precedent).
- **F-2** SPI < SPI_WARNING_THRESHOLD detection — same lint script.
- **F-3** Growth ceiling overshoot detection — same lint script.
- **F-4** MVP roster role-coverage check (4 dominant_stat distinct count ≥ 4) — same lint script.

The build-time validation thresholds (`STAT_TOTAL_MIN`, `STAT_TOTAL_MAX`, `SPI_WARNING_THRESHOLD`, etc.) live in `balance_entities.json` per ADR-0006 + read via `BalanceConstants.get_const(key)`. **Same-patch obligation**: the lint script's threshold append to `balance_entities.json` ships with the lint story, NOT with ADR-0007 acceptance. ADR-0007's runtime pipeline does not consume validation thresholds; the BalanceConstants dependency is forward-compat only.

### 6. Architecture Diagram

```
                    ┌────────────────────────────────────┐
                    │   HeroDatabase (Foundation)        │
                    │   class_name + RefCounted          │
                    │   + @abstract + all-static methods │
                    │   zero state / zero signals        │
                    └────────────────┬───────────────────┘
                                     │ lazy-init on first call
                                     ▼
                          ┌────────────────────────────┐
                          │  assets/data/heroes/       │
                          │  heroes.json               │
                          │  (top-level Dict           │
                          │   keyed by hero_id;        │
                          │   ~10 records for MVP)     │
                          └─────────────┬──────────────┘
                                        │ JSON.new().parse()
                                        │ + per-field validation
                                        │ + HeroData instantiation
                                        ▼
                  ┌──────────────────────────────────────────┐
                  │  static var _heroes: Dictionary          │
                  │     keyed by StringName hero_id          │
                  │     values: HeroData Resource refs       │
                  │     (session-persistent cache)           │
                  └──────────────────────┬───────────────────┘
                                         │
            ┌────────────────────────────┴────────────────────────────┐
            │                          │                              │
            ▼                          ▼                              ▼
    ┌──────────────┐            ┌─────────────┐              ┌─────────────────┐
    │ Unit Role    │            │ HP / Status │              │ Damage Calc     │
    │ AI           │            │ Turn Order  │              │ Formation Bonus │
    │ Battle Prep  │            │ Char Growth │              │ Equipment       │
    │ Scenario Prog│            │ Story Event │              │                 │
    └──────────────┘            └─────────────┘              └─────────────────┘
        consume HeroData fields READ-ONLY via 6 static query methods
```

### 7. Forbidden Patterns (Registry Candidates)

Two new forbidden patterns are codified for the architecture registry:

**`hero_database_signal_emission`** — HeroDatabase MUST NOT declare any signal, MUST NOT emit any signal, MUST NOT subscribe to any signal. Mirrors ADR-0012 `damage_calc_signal_emission` + ADR-0009 `unit_role_signal_emission` for the same architectural reason. Static-lint via grep.

**`hero_data_consumer_mutation`** — Consumers of `HeroDatabase.get_hero(...)` MUST NOT mutate any field of the returned HeroData Resource. CR §Interactions "읽기 전용 계약" is the contract; runtime stat changes (level-up, equipment, status effects) belong to consumer-side "base + modifier" pattern. A consumer mutating `hero.stat_might = 99` corrupts the shared cache for subsequent consumers — silent correctness bug.

`hero_data_class_enum_drift` is documented in §2 as a cross-doc convention (`HeroData.default_class` int values must align with UnitRole.UnitClass enum int values 0..5); it is NOT registered as a forbidden_pattern because it is a **value-alignment convention** rather than an architectural anti-pattern. Codified in ADR-0007 §2 prose + future ADR-0009 amendment will mention this alignment as a same-patch invariant.

---

## Alternatives Considered

### Alternative 1: Battle-scoped Node holding heroes during battle

- **Description**: `class_name HeroDatabase extends Node`, instantiated once per BattleScene, owns the `_heroes` Dictionary during battle, freed on BattleScene teardown.
- **Pros**: Memory cleanup tied to battle lifecycle; tests instantiate fresh per-battle.
- **Cons**: Hero DB is consumed by Overworld (Battle Preparation) + cross-scene (Scenario Progression `get_all_hero_ids()` for save/load). Battle-scoped lifecycle would force Overworld to maintain a parallel cache or re-load on every battle. Stateful — violates 4-precedent stateless-static pattern (ADR-0008 → 0006 → 0012 → 0009). Cross-scene reload cost is non-trivial (~50ms per JSON parse for 10-hero file; acceptable once per session, not acceptable per battle).
- **Rejection Reason**: Cross-scene consumer pattern (Battle Preparation reads heroes pre-battle; Scenario Progression reads heroes pre-load) demands session-persistent cache. Stateless-static + lazy-init persists naturally across BattleScene lifecycle.

### Alternative 2: Per-hero `.tres` Resources (no JSON)

- **Description**: `assets/data/heroes/shu_001_liu_bei.tres`, `assets/data/heroes/wei_001_cao_cao.tres`, ... × 8-10 files. HeroDatabase scans the directory at startup via `DirAccess.get_files_at()` + `ResourceLoader.load(path, '', CACHE_MODE_IGNORE)`.
- **Pros**: Native Godot Inspector authoring; type-safe per-field at the Resource boundary; no JSON syntax errors; ResourceSaver round-trip naturally available.
- **Cons**: 8-10 file management overhead (vs single file); harder to PR-diff (binary-ish .tres text); harder to bulk-edit (rename a stat across all heroes); harder for designers using external tools (spreadsheet → JSON pipelines per balance-data.md OQ-5). ADR-0006 § Alternative C rejected the same shape for `BalanceConstants`; ADR-0008 + ADR-0009 also chose JSON over per-record .tres. Established 4-precedent JSON pattern; switching to .tres splits the data pipeline.
- **Rejection Reason**: Pipeline-split cost outweighs per-record type-safety benefit. JSON is the established format per ADR-0006/0008/0009 precedent. Inspector authoring is preserved at the HeroData Resource level (designer can author a hero in inspector, export to JSON via tooling); the Resource `.tres` form is not the SOURCE-OF-TRUTH but a transient authoring medium.

### Alternative 3: Hand-coded const class (no JSON)

- **Description**: `HeroDatabase.gd` contains `const HEROES: Dictionary = { &"shu_001_liu_bei": HeroData.new_with(...), ... }` — values inlined at GDScript module load time.
- **Pros**: Zero runtime I/O; compile-time constant inlining; no parse-error surface.
- **Cons**: Violates GDD "data-driven" requirement (matches AC-20 in unit-role.md / matches AC-DC-48 in damage-calc.md / matches CR-10 in balance-data.md — hardcoded gameplay values are a blocker bug). Designers must edit `.gd` files to retune hero stats; spreadsheet pipeline + content pipeline integration become impossible.
- **Rejection Reason**: Blocker GDD violation. Hero DB is by definition the canonical content data store; hardcoding it negates its purpose.

### Alternative 4: Full DataRegistry pipeline now (Alpha-tier from day 1)

- **Description**: Implement the GDD balance-data.md CR-1..CR-10 full pipeline (Discovery / Parse / Validate / Build, 4 severity tiers, 9 categories, hot reload, schema versioning) and put `heroes` as one of the 9 categories.
- **Pros**: GDD-compliant from day 1; no MVP-vs-Alpha scope split.
- **Cons**: ~3 days of pipeline-implementation work for an interface that today serves 1 file with 10 records. ADR-0006 § Alternative A explicitly rejected the same shape and deferred full pipeline to Alpha. Reinstating it for ADR-0007 contradicts ADR-0006 precedent without new evidence.
- **Rejection Reason**: Over-building. ADR-0006 already deferred the full pipeline to Alpha. ADR-0007 reuses ADR-0006's lazy-init JSON pattern + extends with HeroData typed Resource — minimal addition, maximum consistency.

---

## Consequences

### Positive

- **5th-precedent stateless-static pattern stable**: ADR-0007 reuses the architectural form ratified by ADR-0008/0006/0012/0009. Cross-Foundation/Core consistency is the load-bearing benefit; future Foundation/Core data-layer ADRs (Skill, Formation, Equipment, Character Growth) inherit the pattern.
- **Closes ADR-0009 §From provisional HeroData soft-dep**: ADR-0009's only outstanding upstream soft-dep is ratified. Same-patch obligation: ADR-0009 §Dependencies "Soft / Provisional" line 35 is updated to hard `Depends On ADR-0007 (Hero DB, Accepted YYYY-MM-DD)`.
- **Unblocks 7 downstream ADRs / epics**: AI, HP/Status, Turn Order, Formation Bonus, Scenario Progression, Character Growth, Equipment/Item all gain a ratified HeroData consumer contract. Battle Preparation epic gains `get_mvp_roster()` for MVP scaffolding.
- **Forward-compatible with Alpha pipeline**: when DataRegistry full pipeline lands, HeroDatabase becomes a thin facade: `static func get_hero(id) -> HeroData: return DataRegistry.get_record(&"heroes", id) as HeroData`. Call-site stability preserved across migration.
- **Test-isolated**: `before_test()` cache reset pattern documented (per ADR-0006 §6 + G-15); HeroDatabase test suite obligation matches established Foundation-layer pattern.
- **Designer-friendly authoring**: JSON file diffs cleanly in PR; spreadsheet → JSON pipeline (per balance-data.md OQ-5) supports bulk authoring without code changes.

### Negative (Documented Deviations from GDD)

- **GDD F-1..F-4 validation deferred**: stat total / SPI / growth ceiling / MVP roster validation not enforced at runtime in MVP. Build-time tooling deferred to Polish-tier follow-up story. Designer error path: out-of-range hero authored in heroes.json silently loads; only manual review catches violations until lint script ships.
- **GDD CR-2 Relationships block deferred to typed Resource**: `Array[Dictionary]` provisional; typed `Array[HeroRelationship]` migration owned by Formation Bonus ADR. Risk of designer error in relationship authoring (4-field record shape unenforced beyond schema validation in `_load_heroes()`).
- **GDD CR-2 Equipment slot enum deferred**: `equipment_slot_override: Array[int]` storage form; semantic mapping (WEAPON/ARMOR/MOUNT/ACCESSORY) owned by Equipment ADR. ADR-0007 enforces array shape only.
- **GDD AC-15 100-hero load benchmark not validated in MVP**: with 10-hero MVP, the 100-hero / 100ms target is forward-compat extrapolation only. Validation deferred to Alpha when full roster ships.
- **`default_class: int` (not typed enum)**: prose-level convention enforces alignment with UnitRole.UnitClass; cross-script @export typed enum reference rejected for inspector-authoring stability. Drift risk if UnitRole.UnitClass enum is ever extended without HeroData ratification (mitigated by §6 cross-doc convention).

### Risks

**R-1: HeroData consumer mutation silent corruption**
- **Description**: A consumer (e.g., HP/Status applying level-up) mutating `hero.stat_might += 5` on a returned HeroData reference corrupts the shared cache. Subsequent `HeroDatabase.get_hero(id)` returns the mutated record; downstream consumers see drifted values.
- **Probability**: MEDIUM (the read-only contract is prose convention, not GDScript-enforced; a developer unfamiliar with the contract may mutate naively).
- **Impact**: HIGH (silent correctness bug; level-up / equipment / status effects all touch hero stats; cross-system stat drift compounds).
- **Mitigation**: (1) Codify forbidden_pattern `hero_data_consumer_mutation` in architecture registry. (2) Source-comment in `hero_database.gd` above each query method: `# RETURNS SHARED REFERENCE — consumers MUST NOT mutate fields. Use base+modifier pattern.`. (3) Unit test in `tests/unit/foundation/hero_database_consumer_mutation_test.gd`: get_hero, mutate stat, get_hero again, assert original value (FAIL if cache is corrupted — proves mutation propagates). Test serves as a documented fail-state, not a passing test (it's expected to "fail" because GDScript has no const reference enforcement; the test asserts the mutation IS visible, proving the convention is the only defense). Alternative: deeper-defense `duplicate_deep()` on every get_hero — rejected for performance (10× cost on hot path; reverse the contract to be enforced at consumer code review).

**R-2: HeroDatabase._heroes_loaded leakage between tests**
- **Description**: GdUnit4 test suites that call any HeroDatabase method inherit ADR-0006 + G-15 test-isolation obligation. A suite forgetting `_heroes_loaded = false` reset in `before_test()` leaks cache state to subsequent tests.
- **Probability**: HIGH (every HeroDatabase test suite must implement the reset; pattern is established at 8+ suites across the project).
- **Impact**: MEDIUM (intermittent test failures; cache state from a prior test leaks into the current test).
- **Mitigation**: G-15 codified `before_test()` reset (already standard project pattern). Source-comment in `hero_database_test.gd` template: `# G-15: HeroDatabase._heroes_loaded reset is MANDATORY in before_test().`. Mirror ADR-0009 R-2 + ADR-0006 R-2 mitigation.

**R-3: ADR-0009 same-patch update risk**
- **Description**: ADR-0007 acceptance triggers a same-patch update to ADR-0009 §Dependencies "Soft / Provisional" clause + ADR-0009 §Migration Plan §From provisional HeroData clause + `src/foundation/hero_data.gd` doc-comment header. If any of the three updates is missed, the documentation has stale references to "provisional ADR-0007" after acceptance.
- **Probability**: MEDIUM (3 cross-doc updates required; pattern of cross-doc-update misses validated by damage-calc rev 2.9.3 cross-doc desync incident — codified as standing discipline).
- **Impact**: LOW (documentation inconsistency; no runtime impact).
- **Mitigation**: ADR-0007 §Migration Plan §"Same-patch obligations" enumerates all 3 updates explicitly. Sweep + narrow re-review per damage-calc precedent (pattern stable at 4 invocations).

**R-4: GDD `hero-database.md` Status drift**
- **Description**: hero-database.md GDD Status currently reads "Designed". After ADR-0007 acceptance, status should flip to "Accepted via ADR-0007 (YYYY-MM-DD)". Cross-doc obligation.
- **Probability**: HIGH (status flips are routinely missed if not explicitly listed in same-patch obligations).
- **Impact**: LOW (documentation hygiene; no runtime impact).
- **Mitigation**: §Migration Plan same-patch obligations includes the GDD Status update line.

---

## GDD Requirements Addressed

| GDD AC / Section | Requirement | How ADR-0007 Addresses It |
|---|---|---|
| AC-01 (Hero ID format) | `^[a-z]+_\d{3}_[a-z_]+$` rejects non-conforming IDs | §5 runtime FATAL severity check in `_load_heroes()` |
| AC-02 (Core stat range) | stats out of [1, 100] reject record | §5 runtime FATAL on per-field range validation |
| AC-03 (Seed range) | base_hp_seed/base_initiative_seed out of [1, 100] reject record | §5 runtime FATAL |
| AC-04 (move_range bounds) | move_range out of [2, 6] reject record | §5 runtime FATAL |
| AC-05 (Growth rate bounds) | growth_* out of [0.5, 2.0] reject record | §5 runtime FATAL |
| AC-06 (Relationship record structure) | get_relationships returns 4-field records | §4 `get_relationships(hero_id) -> Array[Dictionary]`; provisional Dict shape until Formation Bonus ADR |
| AC-07 (Skill parallel array integrity) | innate_skill_ids.size() == skill_unlock_levels.size() | §5 runtime FATAL EC-2 check; both length 0 accepted |
| AC-08 (F-1 stat_total boundary) | 180/280 valid; 179/281 fail/flag | §5 build-time validation (DEFERRED to Polish lint script) |
| AC-09 (F-2 SPI threshold) | SPI < 0.5 design warning | §5 build-time validation (DEFERRED) |
| AC-10 (F-3 stat_projected clamp) | stat_projected clamps to 100 | §5 build-time validation (DEFERRED — Character Growth ADR ratifies L_CAP) |
| AC-11 (F-4 MVP roster validation) | role_coverage ≥ 4 dominant_stat distinct | §5 build-time validation (DEFERRED to Polish lint script) |
| AC-12 (EC-1 duplicate ID — full reject) | duplicate hero_id rejects entire load | §5 runtime FATAL EC-1 check |
| AC-13 (EC-2 skill mismatch — record reject) | offending record rejected; others continue | §5 runtime FATAL per-record |
| AC-14 (EC-5 orphan FK — non-fatal) | orphan relationship dropped + warning logged | §5 runtime WARNING EC-5 check |
| AC-15 (Query interface + perf) | 100-hero load + Dictionary build < 100ms | §6 forward-compat extrapolation (10-hero MVP measured; 100-hero validation deferred to Alpha) |

15/15 GDD ACs mapped. AC-08..AC-11 are explicitly deferred to Polish-tier build-time tooling (documented in §5 as DEFERRED with explicit Polish-tier follow-up story commitment).

---

## Performance Implications

- **`get_hero(id)`**: Dictionary[StringName, HeroData] lookup — O(1) hash; <0.001ms.
- **`get_heroes_by_faction` / `get_heroes_by_class`**: linear scan over `_heroes` values; 10-hero MVP × 5 field reads ≈ <0.05ms. Pre-built indices optional Alpha-tier optimization.
- **`get_mvp_roster`**: linear scan filter on `is_available_mvp == true`; same cost as faction/class scan.
- **`get_relationships`**: per-hero relationships array is variable size; typical < 10 entries; lookup + array copy < 0.01ms.
- **`get_all_hero_ids`**: Dictionary.keys() copy — Godot 4.x typed-array COW; <0.01ms for 10-hero MVP.
- **`_load_heroes()` (one-time on first call)**: FileAccess + JSON.parse + per-record HeroData instantiation + range validation. Estimated 5-15ms for 10-hero MVP; under 100ms target for 100-hero Alpha per AC-15.
- **Memory**: ~5KB per HeroData Resource (26 fields, ~200 bytes typical) × 10 = ~50KB cache for 10-hero MVP; ~500KB at 100-hero Alpha. Well under 512MB mobile ceiling.
- **Network**: N/A — content data ships with the build.

---

## Migration Plan

### From current state (provisional shape; 10 fields) to ratified shape (26 fields)

1. **Update `src/foundation/hero_data.gd`** — append the 16 missing fields (7 identity + 4 growth + 1 skill_unlock_levels + 3 scenario + 1 relationships) per §2; keep existing 10 fields unchanged (parameter-stable per ADR-0009 §Migration Plan §From provisional HeroData). Update file header doc-comment from "provisional ... ADR-0007 will ratify" → "Ratified by ADR-0007 (Accepted YYYY-MM-DD)".
2. **Create `src/foundation/hero_database.gd`** — new file, ~300 LoC, 6 static query methods + lazy-init `_load_heroes()` + per-record validation helpers.
3. **Create `assets/data/heroes/heroes.json`** — 8-10 MVP hero records per `is_available_mvp = true`. Field values lifted from GDD §Acceptance Criteria examples + designer authoring. Hero record selection for MVP roster: 4 dominant_stat coverage required per F-4 (defer enforcement to Polish lint).
4. **Create `tests/unit/foundation/hero_database_test.gd`** — covers AC-01..AC-07 (CR-1 ID format, range checks, parallel array integrity, EC-1 duplicate, EC-2 mismatch, EC-5 orphan WARNING, all 6 query methods).
5. **Create `tests/unit/foundation/hero_data_test.gd`** — covers HeroData Resource instantiation, default values, @export round-trip via ResourceSaver/Loader (sanity check; not save-load critical because Hero DB is content data).

### Same-patch obligations (must ship together with this ADR's Acceptance)

1. **ADR-0009 §Dependencies "Soft / Provisional" line 35** — update soft-dep clause to hard `Depends On ADR-0007 (Hero DB, Accepted YYYY-MM-DD)`. Drop "(NOT YET WRITTEN — soft / provisional upstream)" qualifier.
2. **ADR-0009 §Migration Plan §"From provisional HeroData to ADR-0007-ratified shape"** — mark as COMPLETE; replace prose with brief retrospective ("Ratified by ADR-0007 on YYYY-MM-DD; 16 fields added to provisional shape per ADR-0007 §2; all UnitRole call sites parameter-stable; no UnitRole call-site edits required").
3. **`src/foundation/hero_data.gd` header doc-comment** — drop "provisional" qualifier; replace with `Ratified by ADR-0007 (Accepted YYYY-MM-DD)`. The 16 new fields ship in the same patch.
4. **`design/gdd/hero-database.md` Status field** — flip from "Designed" to "Accepted via ADR-0007 (YYYY-MM-DD)" + cross-link to ADR-0007 in header metadata.
5. **TR registry append** — `docs/architecture/tr-registry.yaml` v6 → v7 with TR-hero-database-001..NNN entries (target ~10 TRs covering AC-01..AC-07 + AC-12..AC-14 + 6 query methods). Authored by `/architecture-review` delta on next run, NOT this ADR.
6. **Architecture registry append** — 1 new `state_ownership` entry (`hero_record_table`), 1 new `interfaces` entry (`hero_database_queries`, direct_call), 1 new `api_decisions` entry (`hero_database_module_form`), 2 new `forbidden_patterns` (`hero_database_signal_emission`, `hero_data_consumer_mutation`). Authored at Step 6 of this skill flow per user approval.

### Forward-compat migration (Alpha-tier, no calendar commitment)

When future Alpha-tier "DataRegistry Pipeline" ADR is authored:

1. HeroDatabase becomes a thin facade: `static func get_hero(id) -> HeroData: return DataRegistry.get_record(&"heroes", id) as HeroData`.
2. Eventual deprecation: callers migrate to `DataRegistry.get_record(...)` directly; HeroDatabase removed when zero callers remain.
3. Migration is call-site stable.

---

## Validation Criteria

ADR-0007 is correctly implemented when:

1. **All 15 GDD ACs covered**: §GDD Requirements Addressed table maps every AC-01..AC-15 to an ADR-0007 section. AC-08..AC-11 have documented Polish-tier deferral.
2. **HeroData Resource shape ratified**: `src/foundation/hero_data.gd` has 26 @export fields per §2 + `HeroFaction` nested enum.
3. **HeroDatabase 6-method API shipped**: `src/foundation/hero_database.gd` exposes the 6 static query methods per §4.
4. **Runtime severity validation working**: AC-01 ID format rejection + AC-12 EC-1 duplicate rejection + AC-13 EC-2 mismatch rejection + AC-14 EC-5 orphan WARNING all unit-tested with FATAL → push_error + null return contract verified.
5. **Test isolation discipline**: every HeroDatabase test suite includes `HeroDatabase._heroes_loaded = false` reset in `before_test()`. Static-lint check post-implementation: `grep -L "_heroes_loaded = false" tests/unit/foundation/hero_database*.gd` returns empty.
6. **Static lint — non-emitter invariant**: `grep -E '(signal\s|connect\(|emit_signal\()' src/foundation/hero_database.gd src/foundation/hero_data.gd` returns zero matches. Mirrors ADR-0012 + ADR-0009 + ADR-0006 forbidden_pattern enforcement.
7. **Static lint — no hardcoded validation thresholds**: `grep -E '\b(180|280|0\.5|2\.0|10|20)\b' src/foundation/hero_database.gd | grep -v "BalanceConstants.get_const"` returns zero matches (validation thresholds, when implemented in Polish lint, must come via BalanceConstants).
8. **R-1 mitigation test**: `tests/unit/foundation/hero_database_consumer_mutation_test.gd` documents shared-reference contract (test asserts mutation IS visible across get_hero calls — proving the read-only contract is convention-only).
9. **Cross-doc updates committed**: ADR-0009 §Dependencies + ADR-0009 §Migration Plan + `hero_data.gd` header + GDD Status — all 4 updates ship same-patch with this ADR's Write approval.

---

## Related Decisions

- `docs/architecture/ADR-0001-gamebus-autoload.md` — HeroDatabase on non-emitter list; zero signals in / out.
- `docs/architecture/ADR-0003-save-load.md` — TR-save-load-002 @export discipline; HeroData fields all @export-annotated for Resource serialization compatibility (even though Hero DB is content data, not save data).
- `docs/architecture/ADR-0006-balance-data.md` — `BalanceConstants.get_const(key)` accessor for forward-compat validation thresholds; `_heroes_loaded` test-isolation pattern mirrors `_cache_loaded` per G-15.
- `docs/architecture/ADR-0008-terrain-effect.md` — architectural-form precedent #1 (`class_name X extends RefCounted` + all-static + JSON config + lazy-init).
- `docs/architecture/ADR-0009-unit-role.md` — provisional HeroData soft-dep ratified by this ADR; same-patch update to §Dependencies + §Migration Plan.
- `docs/architecture/ADR-0012-damage-calc.md` — `Array[StringName]` typed-array discipline ratified for `innate_skill_ids` field.
- `design/gdd/hero-database.md` (Designed, rev 2026-04-16) — authoritative GDD source for all 4 Core Rules, 4 Formulas, 10 Edge Cases, 12 Tuning Knobs, 15 Acceptance Criteria.
- `.claude/rules/godot-4x-gotchas.md` G-12 (class_name collision avoidance), G-14 (class-cache refresh post file creation), G-15 (`_heroes_loaded` reset in before_test), G-22 (@abstract enforcement semantics).
- `docs/architecture/control-manifest.md` (Manifest Version 2026-04-20) — Foundation-layer programmer rules (will be extended with ADR-0007 obligations on next manifest revision).

---

## Notes

### N1: Why ADR-0007 is the smallest-scope Foundation ADR yet

Compared to ADR-0009 (Unit Role, ~480 LoC ADR; 6×6 cost matrix + 6×3 direction multiplier + F-1..F-5 derivation + 6-passive-tag canonicalization), ADR-0007 carries less architectural decision weight. The bulk of the GDD content (25+ field record blocks, 4 validation formulas, 12 tuning knobs, 15 AC) is content-shaped: the architecture decision is "stateless static utility class + JSON storage" (5th-precedent pattern); the rest is field-set ratification + query-API enumeration.

This is intentional. ADR-0007's role is to **ratify** the GDD-locked content shape, not to redesign it. The 4-precedent stateless-static pattern handles the architectural form; ADR-0007's load-bearing decisions are just (a) which fields ship in MVP vs deferred, (b) JSON file schema, (c) which validation severity tier each EC lands in.

### N2: Why F-1..F-4 validation defers to Polish-tier tooling

Runtime validation of stat balance (F-1 stat_total range), specialization (F-2 SPI), growth ceiling (F-3), and MVP roster coverage (F-4) does not block any consumer at runtime. A hero with stat_total=200 (out of [180, 280] range — failing F-1) can still be queried, instantiated, and consumed by Damage Calc / HP Status / Turn Order without corrupting any system; the violation is a **designer authoring error**, not a runtime correctness issue. Designer error catches are appropriately tooled at build-time (CI lint script) where the developer/designer iteration loop closes faster than runtime push_error in the editor console.

This deferral matches the Polish-deferral pattern stable at 5+ invocations (ADR-0008 + ADR-0006 + ADR-0009 + ADR-0012 + ADR-0007 = pattern is now load-bearing project discipline).

### N3: Cross-doc convention vs forbidden_pattern — `hero_data_class_enum_drift`

The convention "HeroData.default_class int values must align 1:1 with UnitRole.UnitClass enum values 0..5" is **not** registered as a forbidden_pattern. Reasoning: a forbidden_pattern is an architectural anti-pattern (something a developer might WANT to do but MUST NOT). Drifting an enum value is not something a developer wants to do — it's a coordination failure between two ADRs. The convention is documented in §2 prose + §6 forbidden_patterns scope-note + ADR-0009 future amendment will cross-reference. If drift occurs anyway, it surfaces as test failures in UnitRole's `get_class_direction_mult` test suite (mismatched int → wrong direction multiplier).

### N4: Why HeroDatabase ships zero indices in MVP

`get_heroes_by_faction` and `get_heroes_by_class` perform full-collection linear scan in MVP. Pre-built `_faction_index` / `_class_index` Dictionaries are NOT included.

Rationale: 10-hero MVP × 5 field reads × ~10 query calls per battle = ~500 ops per battle = trivial. Pre-built indices add ~50 LoC + 1 cache invalidation hazard (any future mutation pathway must update both `_heroes` and the indices) for a non-measurable performance gain. Established 4-precedent project discipline (ADR-0006 single-file lazy-load; ADR-0008 inline cost-matrix; ADR-0009 6×3 direction array; ADR-0012 stateless calculator) uniformly avoids structural read-optimization until measurement justifies it. Indices are a forward-compat Alpha-tier addition; the MVP API shape is identical.
