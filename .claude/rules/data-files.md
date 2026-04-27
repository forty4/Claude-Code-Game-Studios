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

Until then: **constants-registry files use UPPER_SNAKE_CASE keys**; **all other data files use camelCase**.
