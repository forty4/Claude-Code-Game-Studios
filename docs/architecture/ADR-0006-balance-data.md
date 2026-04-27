# ADR-0006: Balance/Data — BalanceConstants Singleton (MVP scope)

## Status

Proposed (2026-04-27, ratifies shipped code from damage-calc story-006b PR #65 + terrain-effect story-003 PR #43)

## Date

2026-04-27

## Last Verified

2026-04-27

## Decision Makers

- Technical Director (architecture owner)
- User (Sprint 1 S1-09 authorization, 2026-04-27)
- godot-specialist (engine validation deferred — ratifying shipped, test-verified code; production cycle since 2026-04-27 covers 388/388 GdUnit4 regression including the BalanceConstants test suite)

---

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core — data infrastructure / file loading |
| **Knowledge Risk** | **LOW** — `FileAccess.get_file_as_string()` is pre-Godot-4.4 and stable; `JSON.parse_string()` is pre-Godot-4.0 and stable; static `class_name` + static vars + RefCounted are pre-cutoff stable. The only post-cutoff change in this domain is `FileAccess.store_*` returning `bool` (Godot 4.4) — this ADR does NOT use the write path. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/current-best-practices.md`, `design/gdd/balance-data.md` (Designed 2026-04-16), `design/gdd/damage-calc.md` (rev 2.9.3, primary consumer), `design/gdd/terrain-effect.md` (already migrated 2026-04-25 via ADR-0008's `_load_config()` helper), `docs/architecture/ADR-0008-terrain-effect.md` (provisional-pattern precedent, 2026-04-25), `docs/architecture/ADR-0012-damage-calc.md` (consumer + interface lock, 2026-04-26), `docs/registry/architecture.yaml` (line 262 + line 573-574 forbidden-pattern reference), `src/feature/balance/balance_constants.gd` (90 lines, shipped PR #65), `tests/unit/balance/balance_constants_test.gd` (6 functions, all PASS), `assets/data/balance/entities.json` (current data file, 12 keys). |
| **Post-Cutoff APIs Used** | None. |
| **Verification Required** | (1) Confirm `entities.json` rename to `balance_entities.json` (Q3 design decision — `data-files.md` `[system]_[name].json` rule compliance) lands in same patch as ADR-0006 Acceptance; verify single-const-path-string update + 1 lint-script reference update; full regression must remain 388/388 PASS. (2) Confirm `BalanceConstants._cache` static-var lifecycle survives test-suite isolation (story-006b shipped before_test cache reset; pattern verified across 53 damage-calc tests + 6 balance-constants tests + 3 lint scripts). (3) ~~Engine API verification of FileAccess + JSON~~ — **CLOSED 2026-04-27**: shipped code in PR #65 has been exercised by 388/388 GdUnit4 regression across 10+ stories. |

> **Knowledge Risk Note**: Domain is **LOW** risk. Future Godot 4.7+ that touches `FileAccess.get_file_as_string()` semantics or `JSON.parse_string()` Variant return semantics would trigger Superseded-by review. The static-var lifecycle pattern (`static var _cache: Dictionary`) is GDScript 4.x core behaviour and unlikely to change.

---

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None. Foundation-layer / Core data infrastructure. Reads the project filesystem only; no signal subscriptions; no upstream ADR contracts to honor. |
| **Enables** | (1) **Ratifies** ADR-0008 (Terrain Effect, Accepted 2026-04-25)'s provisional `_load_config()` pattern (TerrainConfig wrapper); ADR-0008's "Ordering Note" line 35 explicitly documents soft-dependency on ADR-0006 for the data-loading pipeline. (2) **Ratifies** ADR-0012 (Damage Calc, Accepted 2026-04-26) §6 (tuning constants in entities.json) + §8 provisional-dependency contract; ADR-0012 §Dependencies line 42 documents the `BalanceConstants` workaround for the un-written ADR-0006. (3) **Unblocks** future Hero Database ADR (heroes file consumer pattern), future ADR-0009 Unit Role (class-direction tables consumer; tables already live in entities.json), future Formation Bonus ADR. |
| **Blocks** | None currently. ADR-0008 + ADR-0012 are already Accepted with the provisional pattern; this ADR ratifies retroactively. ADR-0006 acceptance closes a soft-dependency loop but does not gate any new work. |
| **Ordering Note** | This ADR ratifies a 2-precedent provisional pattern (ADR-0008 → BalanceConstants in 2026-04-25 → 04-27). Pattern stable at 2 invocations; ADR-0006 acceptance promotes it from "provisional, soft-dep" to "ratified, hard-contract". The migration to a future full DataRegistry singleton (Alpha-pipeline scope per balance-data.md GDD CR-1..CR-10) remains forward-compatible: call sites use `BalanceConstants.get_const(key) -> Variant`; future Alpha rename to `DataRegistry.get_const(key) -> Variant` is mechanical (~5-8 call sites in src/feature/damage_calc/ + src/core/terrain_config.gd; no semantic change). |

---

## Context

### Problem Statement

`design/gdd/balance-data.md` (Designed 2026-04-16, 10 Core Rules CR-1..CR-10, 13 Edge Cases EC-1..EC-13, 16 Tuning Knobs, 12 Acceptance Criteria) specifies the canonical data infrastructure for the project: a 4-phase Discovery/Parse/Validate/Build pipeline with 4 severity tiers, hot reload, JSON envelope `{schema_version, category, data}`, 9 data categories, and a single `DataRegistry` singleton orchestrating reads.

**The full GDD pipeline is Alpha-tier scope** — overbuilt for MVP needs. The current MVP project state has:

- **1 data file** (`assets/data/balance/entities.json`, 12 keys, 19 lines)
- **1 active consumer category** (balance constants, exercised by damage-calc + terrain-effect)
- **0 multi-file orchestration needs**
- **0 hot-reload UI binding**
- **0 schema-version migration needs** (no save files reference data file versions yet)

Two ADRs (ADR-0008 Terrain Effect, ADR-0012 Damage Calc) Accepted in the past 2 days with **provisional** data-loading patterns explicitly soft-dependent on ADR-0006:

- **ADR-0008 Ordering Note** (line 35): *"Soft-depends on ADR-0006 (Balance/Data, NOT YET WRITTEN) for the data-loading pipeline pattern. Workaround: ship with direct `FileAccess.get_file_as_string()` + `JSON.parse_string()` loading from `assets/data/terrain/terrain_config.json`; migrate to Balance/Data's pipeline call when ADR-0006 lands."*
- **ADR-0012 §Dependencies** (line 42): *"ADR-0006 (Balance/Data, NOT YET WRITTEN — soft / provisional): `DataRegistry.get_const(key)` for 11 constants (9 consumed + 2 owned). Workaround until ADR-0006 lands: ship with direct constant reads from `assets/data/balance/entities.json` via a thin `BalanceConstants` wrapper; migrate to ADR-0006's pipeline call when Accepted."*

The provisional pattern shipped in **damage-calc story-006b PR #65** (2026-04-27) as `src/feature/balance/balance_constants.gd` (90 lines, single public static `get_const(key: String) -> Variant`, lazy-load via `FileAccess` + `JSON.parse_string`, untyped Dictionary cache). The pattern has been exercised by **10+ stories** across 2 epics (terrain-effect, damage-calc) and the **388/388 GdUnit4 regression** since shipping. It works. It does NOT need to be redesigned.

ADR-0006 must therefore answer:

1. **Ratify-or-redesign?** — Lock the BalanceConstants pattern as the MVP-scoped contract, OR redesign to match GDD's full DataRegistry pipeline now?
2. **MVP scope vs Alpha scope** — Which GDD Core Rules ship in MVP? Which defer to Alpha?
3. **Naming-rule conflicts** — Resolve `data-files.md` rule conflicts: UPPER_SNAKE_CASE keys (vs camelCase rule); `entities.json` filename (vs `[system]_[name].json` pattern).
4. **Forward-compat migration** — How do call sites migrate from `BalanceConstants` to a future full `DataRegistry`?

### Constraints

**From `design/gdd/balance-data.md` (locked by Foundation-layer GDD review):**

- **CR-1**: System owns 3 things — JSON file format, loading/validation pipeline, cross-system constants file.
- **CR-2 + CR-7**: 9 data categories registered; `balance_constants` is the only category Balance/Data itself owns.
- **CR-6**: Single `DataRegistry` singleton + 3 access patterns (direct lookup, filtered query, constant access).
- **CR-10**: Hardcoding ban — values in JSON must NOT exist as literal constants in `.gd` files. AC-DC-48 grep enforces this for damage-calc.

**From shipped code (PR #65 + ADR-0008 _load_config helper):**

- 1 public static method: `BalanceConstants.get_const(key: String) -> Variant`.
- Lazy-load on first call: `_load_cache()` reads `entities.json` once via `FileAccess.get_file_as_string()`, parses via `JSON.parse_string()`, populates `static var _cache: Dictionary`.
- Idempotent guard: `_cache_loaded: bool` short-circuits subsequent calls (even if first load failed).
- Error mode: missing key → `push_error()` + `null` return. Caller responsible for `as int` / `as float` / `as Dictionary` cast.
- Test isolation: every test suite calling `BalanceConstants` MUST reset `_cache_loaded = false` in `before_test()` (documented in source header comment).

**From `data-files.md` rule** (project-wide):

- File naming: `[system]_[name].json` lowercase with underscores. Current `entities.json` violates (no system prefix in filename, only in directory path).
- Key naming: camelCase. Current keys are UPPER_SNAKE_CASE (mirror of GDScript `const X = ...` naming for grep-ability).

**From `architecture.yaml` registry** (line 262 + line 573-574):

- The interface contract `DataRegistry.get_const(key) -> Variant` is **already locked** in the registry as the call-site contract. ADR-0006 ratifies a name-aliased version: `BalanceConstants.get_const(key) -> Variant` for MVP, future-rename to `DataRegistry.get_const(key) -> Variant` when full pipeline lands.

---

## Decision

### 1. Module Form — Static Singleton-by-Convention

`BalanceConstants` is a **stateless static utility class** with `class_name BalanceConstants extends RefCounted`. It is NOT registered as an autoload — the `class_name` global identifier provides direct access (`BalanceConstants.get_const(...)`). Static vars hold the cached parse; method calls are static.

Rationale (matches ADR-0012 §1 module-form pattern for DamageCalc):
- No instance state per-call.
- No Node lifecycle (no `_ready()`, no `_process()`, no signal subscriptions).
- No autoload registration required.
- Tests instantiate via `(load("res://src/feature/balance/balance_constants.gd") as GDScript).set("_cache_loaded", false)` for isolation.

### 2. Public API — Single Method (MVP)

```gdscript
class_name BalanceConstants
extends RefCounted

## Returns the balance constant for [param key] from balance_entities.json.
## Lazy-loads on first call. Returns null + push_error for unknown keys.
## Caller casts the Variant to expected type at the call site:
##     var cap: float = BalanceConstants.get_const("P_MULT_COMBINED_CAP") as float
##     var atk_table: Dictionary = BalanceConstants.get_const("CLASS_DIRECTION_MULT") as Dictionary
static func get_const(key: String) -> Variant
```

**No typed accessors** (`get_const_int` / `get_const_float` / `get_const_dict`) in MVP. Q6 design decision per /architecture-decision Phase 4 confirmation. Tracked as **TD-041** (typed-accessor refactor) for future story.

### 3. Data File — `balance_entities.json` (RENAMED from `entities.json`)

**Rename**: `assets/data/balance/entities.json` → `assets/data/balance/balance_entities.json`.

Rationale: complies with `data-files.md` `[system]_[name].json` pattern. Mirrors ADR-0008 precedent (`assets/data/terrain/terrain_config.json`). Migration cost: 1 const path string update in `balance_constants.gd:_ENTITIES_JSON_PATH` + 1 `git mv` + lint-script reference update if any. Single-patch; ships with this ADR's Acceptance.

### 4. Data File Format — FLAT JSON (No envelope for MVP)

Current `balance_entities.json` is flat — no `{schema_version, category, data}` envelope. **MVP ratifies flat format**.

Rationale: GDD CR-3 envelope is a multi-file orchestration concern. With 1 file and 1 category, the envelope adds friction without value. Forward-compat note: when 2nd category file lands (e.g., heroes), the loader can transparently detect envelope-vs-flat at parse time and migrate per-file.

**Documented deviation from GDD CR-3** captured in §Consequences → Negative.

### 5. Key Naming — UPPER_SNAKE_CASE (`data-files.md` exception)

JSON keys in `balance_entities.json` use UPPER_SNAKE_CASE: `BASE_CEILING`, `P_MULT_COMBINED_CAP`, `CLASS_DIRECTION_MULT`, etc.

This violates `data-files.md` "camelCase keys" rule. **ADR-0006 documents the exception** with this rationale:

1. **Cross-doc grep-ability**: a tuning constant has 1:1 identifier across `.gd ↔ .json ↔ .md`. `BalanceConstants.get_const("BASE_CEILING")` matches `"BASE_CEILING"` JSON key matches GDD doc reference. camelCase would force regex-aware lints.
2. **AC-DC-48 hardcoded-constants lint precedent**: `tools/ci/lint_damage_calc_no_hardcoded_constants.sh` greps for the literal constant names. Renaming keys to camelCase would invalidate the lint pattern.
3. **`balance_entities.json` is exclusively a constants registry** — keys ARE constant names, not domain entity field names. The `data-files.md` rule was designed for entity-shape data files (e.g., `combat_enemies.json` with `goblin.baseHealth` — entity domain object); it doesn't fit the constant-registry use case.

**Limited scope**: this exception applies ONLY to `balance_entities.json` and any future "constant registry" files (similar shape: flat or shallow `{KEY: value}` map). Entity-shape data files (heroes, maps, scenarios) MUST follow camelCase per `data-files.md`.

**Cross-doc obligation**: append a "Constants Registry Exception" subsection to `data-files.md` documenting this exception in the same patch as ADR-0006 acceptance.

### 6. Loading Strategy — Lazy On-First-Call

`_load_cache()` is invoked on the first `get_const()` call. The cache persists for the lifetime of the GDScript engine session. There is no eager-load at boot, no `_ready()` autoload trigger, and no explicit initialization phase.

Test isolation requirement (carried forward from PR #65): every GdUnit4 test suite that calls ANY `BalanceConstants` method MUST reset `_cache_loaded = false` in `before_test()`. Documented in source header comment + this ADR's §Migration Plan.

### 7. MVP Scope vs Alpha Scope

The following GDD Core Rules **ship in MVP** (this ADR):

- CR-1 (system scope, narrowed: balance constants only)
- CR-7 (balance constants file, the single owned content)
- CR-10 (hardcoding ban, enforced by AC-DC-48 lint script for damage-calc)

The following GDD Core Rules **DEFER to Alpha** (post-MVP):

- **CR-2** (9-category registry) — only `balance_constants` exists in MVP.
- **CR-3** (JSON envelope) — flat ratified for MVP.
- **CR-4** (4-phase pipeline Discovery/Parse/Validate/Build) — MVP uses single-file lazy-load.
- **CR-5** (4 severity tiers FATAL/ERROR/WARNING/INFO) — MVP uses `push_error` + `null` return = "FATAL on access" implicitly.
- **CR-6** (3 access patterns: direct lookup / filtered query / constant access) — MVP supports constant access only.
- **CR-8** (schema versioning) — n/a; flat file has no version.
- **CR-9** (hot reload) — defer; game restart suffices for MVP iteration cadence.

When the full pipeline lands (Alpha-tier ADR, e.g., "ADR-XXXX DataRegistry Pipeline"), call sites migrate from `BalanceConstants.get_const(key)` to `DataRegistry.get_const(key)` — same call-site shape, different orchestrator. The `BalanceConstants` class can either be retired or repurposed as a sub-registry under DataRegistry.

### 8. Migration Path Forward

**To Alpha pipeline**:
1. Author Alpha-tier ADR for full DataRegistry pipeline.
2. Add `DataRegistry` autoload (extends Node; orchestrates 4-phase pipeline; 9 categories).
3. Migration step: `BalanceConstants` becomes a thin facade: `static func get_const(key) -> Variant: return DataRegistry.get_const(key)` — preserves call-site stability during migration.
4. Eventual deprecation: callers migrate to `DataRegistry.get_const(...)` directly; `BalanceConstants` removed when zero callers remain.

This is documented as a non-blocking forward-compat plan; no calendar commitment for Alpha.

### Architecture Diagram

```
                ┌──────────────────────────────────────────────┐
                │   Consumers (damage_calc.gd, terrain_*.gd)   │
                │   Call: BalanceConstants.get_const("KEY")    │
                └─────────────────────┬────────────────────────┘
                                      │ static method call
                                      ▼
        ┌─────────────────────────────────────────────────────┐
        │   BalanceConstants (class_name; static singleton)   │
        │                                                      │
        │   get_const(key: String) -> Variant                 │
        │     ├─ check _cache_loaded                          │
        │     ├─ if not loaded: _load_cache()                 │
        │     ├─ return _cache[key] OR push_error + null     │
        │                                                      │
        │   _load_cache() (private, called once)              │
        │     ├─ FileAccess.get_file_as_string(_PATH)        │
        │     ├─ JSON.parse_string(raw)                       │
        │     ├─ if Dictionary: _cache = parsed              │
        │     ├─ else: push_error                             │
        │     └─ _cache_loaded = true (always)                │
        └─────────────────────┬───────────────────────────────┘
                              │ FileAccess.get_file_as_string
                              ▼
                ┌────────────────────────────────────┐
                │  assets/data/balance/              │
                │  balance_entities.json (renamed    │
                │  from entities.json this patch)    │
                │                                    │
                │  Flat JSON (no envelope)           │
                │  UPPER_SNAKE_CASE keys             │
                │  12 keys: scalars + 2 dict tables  │
                └────────────────────────────────────┘
```

### Key Interfaces

```gdscript
## src/feature/balance/balance_constants.gd
class_name BalanceConstants
extends RefCounted

const _ENTITIES_JSON_PATH: String = "res://assets/data/balance/balance_entities.json"

static var _cache: Dictionary = {}
static var _cache_loaded: bool = false

static func get_const(key: String) -> Variant
```

**Call-site contract** (locked by registry.yaml line 262 + 573-574):
- Return type is `Variant`; caller responsible for type cast.
- `null` return signifies "key absent + push_error logged"; caller should treat as a blocker bug, NOT degrade with default values.
- Static-var lifecycle: cache persists across all calls within a GDScript engine session; only test suites reset via `set("_cache_loaded", false)` in `before_test()`.

---

## Alternatives Considered

### Alternative A: Full GDD Pipeline Now (REJECTED)

**Description**: Implement CR-1..CR-10 in entirety — DataRegistry singleton (autoload), 4-phase pipeline (Discovery/Parse/Validate/Build), 4 severity tiers, hot reload toggle, JSON envelope, 9-category registry framework.

**Pros**:
- GDD-compliant from day one.
- No "MVP-now / Alpha-later" split scope.
- Validated framework available when 2nd consumer category arrives.

**Cons**:
- ~3 days of implementation for an interface that today serves 1 file with 12 keys.
- Forces Alpha-scope schema decisions (envelope migration, severity tier thresholds, hot-reload UI binding) before any Alpha consumer needs them.
- Speculative — no current consumer asks for severity tiers or hot reload.

**Rejection Reason**: over-building. The MVP signals (1 file, 1 category, 0 hot-reload demand, 0 multi-file orchestration) all point to a thinner interface. ADR-0006 ratifies the thin interface and explicitly defers the GDD's full pipeline to Alpha — when 2nd category lands and the framework needs justify the framework cost.

### Alternative B: Static Const Class (REJECTED)

**Description**: Replace JSON loading entirely with a hand-maintained `BalanceConstants.gd` containing `const BASE_CEILING := 83`, `const P_MULT_COMBINED_CAP := 1.31`, etc. No I/O, no parsing, no cache.

**Pros**:
- Zero runtime cost.
- No file format / envelope / parsing concerns.
- Compile-time constant inlining.

**Cons**:
- **Violates GDD CR-10** ("hardcoded values are a blocker bug") — designers must edit `.gd` files to retune values.
- Breaks the AC-DC-48 lint contract: the lint exists precisely to forbid hardcoded values in `.gd` source.
- Breaks the "designer iterates on JSON" workflow validated by terrain-effect's `terrain_config.json` precedent.
- Compile-time constants do not survive Godot's hot-reload (editor-side); designers would need to rebuild after every tweak.

**Rejection Reason**: blocker GDD violation. CR-10 is non-negotiable.

### Alternative C: TRES (Resource) instead of JSON (REJECTED)

**Description**: Author `BalanceConstantsResource` extends Resource with `@export` properties for each constant; ship as `balance_entities.tres`. Use ResourceLoader at runtime.

**Pros**:
- Type-safe at the boundary (each `@export` has a typed declaration).
- Native Godot Inspector authoring (no JSON syntax errors).
- Built-in `duplicate_deep()` semantics (Godot 4.5+).

**Cons**:
- TRES files are not human-readable (binary-ish text). Diff review on PR is harder.
- Designers using external tools (spreadsheet → JSON pipelines, planned per balance-data.md OQ-5) must produce TRES files instead of JSON — significantly higher tooling cost.
- ADR-0008 already established JSON as the data file format for terrain configuration; using TRES for balance constants would split the data pipeline strategy.

**Rejection Reason**: pipeline-split cost outweighs type-safety benefit. JSON is the established format per ADR-0008 precedent + balance-data.md OQ-5 spreadsheet-export plan.

---

## Consequences

### Positive

- **Zero migration cost** for existing consumers — `damage_calc.gd` (8 call sites), `terrain_config.gd` (3 call sites) already use the BalanceConstants pattern; this ADR ratifies what's shipped.
- **Forward-compatible** with future Alpha pipeline — call-site `get_const(key) -> Variant` shape is stable across BalanceConstants → DataRegistry rename.
- **Designer-friendly** — JSON edits update game values without code changes (CR-10 honored).
- **Test-isolated** — `before_test()` cache reset pattern is documented and battle-tested across 53 damage-calc tests + 6 balance-constants tests.
- **Single-file, lazy-loaded** — minimal runtime cost; cache persists for engine session; no per-call disk I/O after first call.
- **Closes 2 soft-dependency loops** in ADR-0008 + ADR-0012 — both can drop "Soft / provisional" qualifiers from their §Dependencies tables.

### Negative (Documented Deviations from GDD)

- **GDD CR-3 envelope deviation**: `balance_entities.json` is flat (no `{schema_version, category, data}` envelope). Documented; MVP-scope decision; defer to Alpha when 2nd category file lands.
- **GDD CR-4 pipeline deviation**: no Discovery/Parse/Validate/Build 4-phase orchestration. MVP uses single-file lazy-load. Defer to Alpha.
- **GDD CR-5 severity tier deviation**: no 4-tier FATAL/ERROR/WARNING/INFO classification. MVP uses `push_error` + `null` return. Defer to Alpha.
- **GDD CR-6 access pattern deviation**: only `constant access` pattern is implemented. `direct lookup` (e.g., `get_hero(id)`) and `filtered query` (e.g., `get_heroes_by_faction(...)`) defer to Hero DB ADR + Alpha pipeline.
- **GDD CR-9 hot reload deviation**: no hot-reload trigger. Defer to Alpha.
- **`data-files.md` key-naming deviation**: UPPER_SNAKE_CASE used for grep-ability (documented in §Decision #5 with limited-scope clause). Cross-doc obligation: amend `data-files.md` to add "Constants Registry Exception" subsection in same patch as ADR-0006 acceptance.
- **Naming divergence with GDD `DataRegistry` term**: GDD uses `DataRegistry.get_const(key)` throughout; this ADR uses `BalanceConstants.get_const(key)`. Forward-compat plan in §Migration Path Forward documents the rename trigger (Alpha pipeline).

### Risks

- **R-1: Future Alpha pipeline forces structural rewrite of BalanceConstants** — when DataRegistry lands, the static-class `BalanceConstants` may need to become a sub-registry or be retired. Mitigation: §Migration Path Forward documents the migration steps; call-site shape stability ensures consumer code is unchanged.

- **R-2: Test isolation discipline drift** — every test suite touching `BalanceConstants` must reset `_cache_loaded` in `before_test()`. If a future suite forgets, static-state bleed across suites in the same GdUnit4 session can cause non-deterministic failures. Mitigation: source-header comment documents the requirement; G-15 lifecycle-hook codification (`.claude/rules/godot-4x-gotchas.md`) reinforces the discipline; full-regression PASS at PR #65 + every subsequent damage-calc PR validates the pattern.

- **R-3: `data-files.md` exception dilution** — if future "constant registry" files appear without the explicit ADR-0006 exception clause, key-naming may drift to camelCase per default rule. Mitigation: cross-doc obligation to amend `data-files.md` with the named exception ships in same patch as ADR-0006.

- **R-4: Filename rename collision** — `entities.json` → `balance_entities.json` requires the rename to land in same patch as the const path string update. Out-of-sync patches break the file load (push_error + null returns + game-blocker). Mitigation: rename + const update in single commit; CI matrix catches any miss via 388/388 regression failure.

---

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|---|---|---|
| balance-data.md | CR-1 (System scope owns 3 things: file format, pipeline, constants file) | Narrowed MVP scope: BalanceConstants owns the constants file (`balance_entities.json`); file format ratified flat (CR-3 envelope deferred); pipeline narrowed to single-file lazy-load (CR-4 deferred). |
| balance-data.md | CR-7 (Balance Constants file is the single owned content) | `assets/data/balance/balance_entities.json` is the canonical constants file. |
| balance-data.md | CR-10 (Hardcoding ban) | BalanceConstants pattern + AC-DC-48 grep lint enforce ban for damage-calc; pattern extends to future consumers. |
| damage-calc.md | F-DC-3, F-DC-5, F-DC-6 (constants in formulas) | All 11 constants (BASE_CEILING, P_MULT_COMBINED_CAP, etc.) read via `BalanceConstants.get_const(key)`. ADR-0012 §Dependencies provisional clause is now ratified. |
| terrain-effect.md | CR-3a, CR-3b (cap constants `MAX_DEFENSE_REDUCTION = 30`, `MAX_EVASION = 30`) | Cap constants live in `terrain_config.json` (ADR-0008 owned); BalanceConstants pattern is the loading mechanism. ADR-0008 §Ordering Note provisional clause is now ratified. |
| (future) hero-database.md | (when authored) | Hero DB will use the same BalanceConstants pattern OR migrate to Alpha-pipeline DataRegistry, depending on which lands first. |

---

## Performance Implications

- **CPU**: One-time cost ~0.5-2ms for `_load_cache()` on first call (FileAccess + JSON.parse_string for 12-key file). Subsequent calls are O(1) hash lookups — measured in nanoseconds. Mobile p99: well under any frame budget.
- **Memory**: `_cache: Dictionary` with 12 entries — ~1KB heap. Bounded by JSON file size (currently 488 bytes raw + 2-3× parse overhead = <2KB). Forward-compat: when 2nd category file lands, each is independent (no shared cache pressure).
- **Load Time**: Lazy-load on first call (typically during DamageCalc.resolve() at first attack of first battle). No boot-time penalty. Game can start with file unread; only the first consumer pays the load cost.
- **Network**: N/A. Single-player MVP; data files ship with the game.

---

## Migration Plan

### Same-patch obligations (must ship together with this ADR's Acceptance)

1. **File rename**: `assets/data/balance/entities.json` → `assets/data/balance/balance_entities.json` (`git mv`).
2. **Const path update**: `src/feature/balance/balance_constants.gd:_ENTITIES_JSON_PATH` value changes from `"res://assets/data/balance/entities.json"` to `"res://assets/data/balance/balance_entities.json"`.
3. **Lint script audit**: any `tools/ci/lint_*.sh` referencing `entities.json` updates the path.
4. **`data-files.md` amendment**: add "Constants Registry Exception" subsection documenting the UPPER_SNAKE_CASE key + flat-format exceptions for constant-registry files (named scope: `balance_entities.json` and structurally identical future files).
5. **TD-041 logged**: typed-accessor refactor (`get_const_int` / `get_const_float` / `get_const_dict`) tracked in `docs/tech-debt-register.md` for future story.

### Cross-doc updates (must ship before or alongside Acceptance)

- **ADR-0008 §Ordering Note**: drop "soft / provisional" qualifier; ADR-0006 has ratified the pattern. Replace with cross-reference to ADR-0006 Decision §1.
- **ADR-0012 §Dependencies**: drop "soft / provisional" qualifier on the ADR-0006 row; add cross-reference to ADR-0006 Decision §2.
- **`docs/registry/architecture.yaml` line 262 + 573-574**: append ADR-0006 cross-reference; mark the interface contract as "Ratified by ADR-0006 (Accepted YYYY-MM-DD)".

### Forward-compat migration (Alpha-tier, no calendar commitment)

When future Alpha-tier "DataRegistry Pipeline" ADR is authored:

1. Add `DataRegistry` autoload (extends Node, 4-phase pipeline, 9 categories).
2. Migration step: `BalanceConstants` becomes a thin facade: `static func get_const(key) -> Variant: return DataRegistry.get_const(key)`.
3. Eventual deprecation: callers migrate to `DataRegistry.get_const(...)` directly.
4. Retire `BalanceConstants` when zero callers remain.

This migration preserves call-site stability (`get_const(key) -> Variant` shape unchanged); no consumer code edits required during the transition window.

---

## Validation Criteria

ADR-0006 is correctly implemented when:

1. **All ratified consumers PASS regression**: 388/388 GdUnit4 regression continues to PASS post-rename (file rename + const path update).
2. **Lint scripts updated**: every `tools/ci/lint_*.sh` referencing `entities.json` updated to `balance_entities.json`. Failure to update = lint script becomes inert (matches no files), not a hard CI fail.
3. **Documentation updates committed**: `data-files.md` "Constants Registry Exception" subsection in place; ADR-0008 §Ordering Note ratification reference added; ADR-0012 §Dependencies provisional qualifier dropped.
4. **TD-041 logged**: tech-debt-register.md has a TD-041 entry for typed-accessor refactor (forward TD).
5. **No orphan references**: `grep -r "entities.json" src/ tools/ docs/` returns 0 matches post-rename (excluding `balance_entities.json` matches and historical references in completed story-006b documentation).

---

## Related Decisions

- **ADR-0001 (GameBus, Accepted 2026-04-18)** — N/A. BalanceConstants is on the non-emitter list (zero signals, zero subscriptions).
- **ADR-0008 (Terrain Effect, Accepted 2026-04-25)** — provisional `_load_config()` pattern is now **ratified** by this ADR. ADR-0008 §Ordering Note line 35 needs same-patch update.
- **ADR-0012 (Damage Calc, Accepted 2026-04-26)** — provisional `BalanceConstants` workaround is now **ratified** by this ADR. ADR-0012 §Dependencies line 42 needs same-patch update.
- **Future ADR-0009 (Unit Role, NOT YET WRITTEN)** — class-direction tables currently live in `balance_entities.json` (`BASE_DIRECTION_MULT`, `CLASS_DIRECTION_MULT`). When ADR-0009 lands, ratify whether they remain in `balance_entities.json` or migrate to a `unit_role.json` file.
- **Future Hero DB ADR (NOT YET WRITTEN)** — first non-constants consumer; will trigger the Alpha-pipeline ADR if `direct lookup` access pattern is needed at MVP.

---

## Notes

### N1: Why ratify rather than redesign?

This ADR is unusual in ratifying shipped code. Standard ADR flow (Proposed → Accepted → implementation) was inverted here: implementation shipped in PR #65 under provisional clauses in ADR-0008 + ADR-0012, predating ADR-0006 authoring. The damage-calc epic close (story-009 PR #74, 2026-04-27) used BalanceConstants 388/388 successfully.

Authoring ADR-0006 to redesign would force a refactor of working, tested code with no functional improvement — a pure waste. ADR-0006 instead **lifts the as-shipped pattern into formal architectural commitment** and explicitly catalogs the deviations from the GDD's full pipeline as MVP-scope decisions.

This is the same "ratify provisional pattern" approach used by ADR-0008 (which ratified terrain-effect's pre-design data-loading conventions). Pattern stable at 2 ratifications.

### N2: 6 design-decision questions (Q1-Q6) per /architecture-decision Phase 4

User-confirmed picks (2026-04-27):
- Q1 envelope: 1a flat (defer envelope to Alpha)
- Q2 key naming: 2a UPPER_SNAKE_CASE (documented exception, grep-ability rationale)
- Q3 filename: 3a rename to `balance_entities.json` (consistency with ADR-0008 precedent)
- Q4 severity tiers: 4a defer to Alpha
- Q5 hot reload: 5a defer to Alpha
- Q6 typed accessors: 6a keep `Variant` return; log TD-041 for future refactor
