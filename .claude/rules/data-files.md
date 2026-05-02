---
paths:
  - "assets/data/**"
---

# Data File Rules

- All JSON files must be valid JSON — broken JSON blocks the entire build pipeline
- File naming: lowercase with underscores only, following `[system]_[name].json` pattern
- Every data file must have a documented schema (either JSON Schema or documented in the corresponding design doc)
- Numeric values must include comments or companion docs explaining what the numbers mean
- Use consistent key naming: camelCase for keys within JSON files
- No orphaned data entries — every entry must be referenced by code or another data file
- Version data files when making breaking schema changes
- Include sensible defaults for all optional fields

## Examples

**Correct** naming and structure (`combat_enemies.json`):

```json
{
  "goblin": {
    "baseHealth": 50,
    "baseDamage": 8,
    "moveSpeed": 3.5,
    "lootTable": "loot_goblin_common"
  },
  "goblin_chief": {
    "baseHealth": 150,
    "baseDamage": 20,
    "moveSpeed": 2.8,
    "lootTable": "loot_goblin_rare"
  }
}
```

**Incorrect** (`EnemyData.json`):

```json
{
  "Goblin": { "hp": 50 }
}
```

Violations: uppercase filename, uppercase key, no `[system]_[name]` pattern, missing required fields.

---

## Constants Registry Exception (named scope only)

**One named exception** to the camelCase-keys rule applies to **flat constants registry files** — JSON files whose top-level shape is a `{KEY: value}` map of cross-system tuning constants. The keys ARE the constant names (1:1 with GDScript `const X = ...` identifiers), not entity domain field names.

### Affected files (exhaustive list)

- `assets/data/balance/balance_entities.json` (per ADR-0006, Proposed 2026-04-27)

Future constant-registry files MUST be added here explicitly when they are introduced. **Do NOT extend this exception silently** — every new file that wants UPPER_SNAKE_CASE keys must be enumerated above with its governing ADR.

### Why the exception

1. **Cross-doc grep-ability**: a tuning constant has a 1:1 identifier across `.gd ↔ .json ↔ .md`. `BalanceConstants.get_const("BASE_CEILING")` matches the `"BASE_CEILING"` JSON key matches the GDD's `BASE_CEILING` doc reference. camelCase would force regex-aware lints.
2. **Lint precedent depends on literal name match**: `tools/ci/lint_damage_calc_no_hardcoded_constants.sh` greps for the literal constant names (e.g., `BASE_CEILING`, `P_MULT_COMBINED_CAP`). Renaming keys to camelCase would invalidate the lint pattern; the lint would either become path-aware (more complexity) or stop catching the violation it's designed for.
3. **Domain shape**: constants registries are not entity-shape data files. The original camelCase rule was designed for entity-shape data (e.g., `combat_enemies.json` with `goblin.baseHealth` — entity domain object); it doesn't fit the constant-registry use case.

### Limited scope of the exception

The exception applies ONLY to constant-registry files (flat or shallow `{KEY: value}` map of cross-system tuning constants). It does NOT apply to:

- Entity-shape data files (heroes, maps, scenarios, equipment) — these MUST follow camelCase per the default rule.
- Mixed-content files where keys are domain entity names with sub-properties — these MUST follow camelCase.
- Any future file added to `assets/data/` that wants to deviate — every new exception requires explicit ADR + addition to the affected-files list above.

### Flat file format (no envelope)

`balance_entities.json` is a **flat JSON file** (no `{schema_version, category, data}` envelope). This is also documented as ADR-0006 MVP-scope decision (Q1 design pick); the GDD's CR-3 envelope format is deferred to Alpha. When a 2nd constants-registry file is added (currently none planned for MVP), the loader can transparently detect envelope-vs-flat at parse time.

**Correct** flat constants-registry file (`balance_entities.json`):

```json
{
  "BASE_CEILING": 83,
  "MIN_DAMAGE": 1,
  "P_MULT_COMBINED_CAP": 1.31,
  "CLASS_DIRECTION_MULT": {
    "0": {"FRONT": 1.00, "FLANK": 1.05, "REAR": 1.09}
  }
}
```

**Note**: nested dicts (e.g., `CLASS_DIRECTION_MULT` rows) MAY use string keys that are not UPPER_SNAKE_CASE if they represent enum-int values or direction labels. The exception applies to the **outer constant-name keys** specifically.

### When this exception is reviewed

When the Alpha-pipeline DataRegistry ADR is authored (post-MVP), this exception subsection should be re-evaluated. The full pipeline may either (a) preserve the exception (likely, given grep-ability remains valuable), or (b) introduce typed accessors that move the cross-doc-identifier matching to a different mechanism (e.g., schema generation), at which point camelCase could become viable.

Until then: **constants-registry files use UPPER_SNAKE_CASE keys**; **all other data files use camelCase** unless covered by the **Entity Data File Exception** below.

---

## Entity Data File Exception (typed-Resource-mapped data files)

**Second named exception** to the camelCase-keys rule applies to **entity-shape JSON data files whose nested keys map 1:1 with a typed Resource's `@export` field set**. The keys ARE the GDScript `@export` field identifiers (which are `snake_case` per `technical-preferences.md` naming convention), not arbitrary domain field names with free spelling.

### Affected files (exhaustive list)

- `assets/data/heroes/heroes.json` (per ADR-0007 §3, Accepted 2026-04-30) — keys `hero_id`, `stat_might`, `name_ko`, etc., 1:1 with `HeroData` `@export` fields
- `assets/data/terrain/terrain_config.json` (per ADR-0008 §2, Accepted 2026-04-25) — keys 1:1 with `TerrainModifiers` `@export` fields
- `assets/data/units/unit_roles.json` (per ADR-0009 §4, Accepted) — keys 1:1 with per-class coefficient field names; file authored when unit-role epic implementation begins (currently stories pending — file does not yet exist on disk as of 2026-05-02)

Future entity-data files MUST be added here explicitly when they are introduced. **Do NOT extend this exception silently** — every new file that wants `snake_case` keys must be enumerated above with its governing ADR.

### Why the exception

1. **Cross-doc grep-ability**: a hero/terrain/unit field has a 1:1 identifier across `.gd ↔ .json ↔ .md ↔ ADR`. `HeroData.hero_id` matches the `"hero_id"` JSON key matches the GDD's `hero_id` doc reference matches the ADR's `hero_id` schema row. camelCase would force a translation layer (e.g., `data["heroId"] → @export var hero_id`) and break grep-based audit lints.
2. **`@export` discipline depends on field-name match**: GDScript `Resource.set("hero_id", value)` matches the `@export var hero_id` field by literal string. With camelCase JSON keys, every load site would need explicit `data["heroId"] → instance.hero_id = data["heroId"]` mapping — a maintenance burden and a class of bugs the `Resource.set` reflection pattern is designed to avoid.
3. **Domain shape**: entity data files are typed Resources with named fields, not opaque blobs or constants registries. The original camelCase rule was designed for the 3rd category (e.g., loose `combat_enemies.json` config with no Resource backing); entity-Resource files have a stronger type contract that is best preserved at the JSON layer.
4. **Project-wide naming-convention coherence**: `technical-preferences.md` mandates `snake_case` for variables. JSON keys that map directly to `@export` fields are effectively variable names. Mixing case styles between the GDScript field and its JSON serialization invites cognitive load and review friction at every diff.

### Limited scope of the exception

The exception applies ONLY to **entity-shape data files where every JSON top-level entry is a record (or a record-of-records) whose nested keys are 1:1 with a typed `Resource`'s `@export` field set**, AND whose load path uses `Resource.set(key, value)` reflection (or equivalent direct field assignment) rather than a translation layer. It does NOT apply to:

- Constants-registry files (heroes-style entity data is not the same shape as `balance_entities.json`'s `{KEY: value}` map) — those use the **Constants Registry Exception** above (UPPER_SNAKE_CASE).
- Heterogeneous data files where some keys are entity field names and others are arbitrary tags — these MUST follow camelCase per the default rule.
- Opaque blob data files with no typed-Resource backing (e.g., a future `localization_strings.json` whose values are translation strings) — these MUST follow camelCase per the default rule.
- Files where the JSON shape is a `{label_string: nested_object}` map and the labels are NOT GDScript `@export` field names — these MUST follow camelCase.
- Any future file added to `assets/data/` that wants to deviate — every new exception requires explicit ADR + addition to the affected-files list above.

### Entity file format

Entity files use a `{record_id: {field: value, ...}}` two-level shape. Top-level keys are record identifiers (typically `snake_case` IDs that match an in-game `StringName` or enum). Nested keys are `@export` field names of the corresponding typed Resource.

**Correct** entity data file (`heroes.json` excerpt):

```json
{
  "shu_001_liu_bei": {
    "hero_id": "shu_001_liu_bei",
    "name_ko": "유비",
    "stat_might": 78,
    "stat_intelligence": 80,
    "default_class": 0,
    "relationships": [
      {"hero_b_id": "shu_002_guan_yu", "relation_type": "sworn_brother", "effect_tag": "rally_bonus", "is_symmetric": true}
    ]
  }
}
```

The outer `"shu_001_liu_bei"` is the record ID (1:1 with the inner `hero_id` field). The inner keys (`hero_id`, `name_ko`, `stat_might`, etc.) are 1:1 with `HeroData` `@export` field names. Nested object fields inside arrays (e.g., `relationships[].hero_b_id`) follow the same convention since they map to a typed `Resource` (provisional `Array[Dictionary]` per ADR-0007; will become typed when Formation Bonus ADR ratifies).

### When this exception is reviewed

When the Alpha-pipeline DataRegistry ADR is authored (post-MVP), this exception subsection should be re-evaluated together with the Constants Registry Exception. The full pipeline may either (a) preserve the exception (likely, given the `Resource.set` reflection pattern remains the cleanest typed-data load path), or (b) introduce a schema-generation layer that decouples JSON key style from GDScript field naming, at which point camelCase JSON could become viable without breaking the `@export` contract.

Until then: **entity-shape data files (per the affected-files list) use `snake_case` keys**; **all other data files use camelCase** (with the constants-registry sub-exception above).

### Origin

This exception was codified as TD-042 close-out (2026-05-02 / sprint-3 S3-06). The 3-ADR precedent (0007 + 0008 + 0009) had been silently following `snake_case` JSON keys against the default camelCase rule for ~2 weeks before the rule was amended. Future entity-data ADRs MUST cite this section in their §Decision (or §Notes) and add their data file to the affected-files list before merging.

