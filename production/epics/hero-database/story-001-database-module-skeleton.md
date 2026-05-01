# Story 001: HeroDatabase module skeleton + lazy-init + 6 query API

> **Epic**: Hero Database
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3-4h (new module ~200 LoC + lazy-init contract + 6 stub query methods + skeleton test suite)
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/hero-database.md`
**Requirement**: `TR-hero-database-001`, `TR-hero-database-003`, `TR-hero-database-004`, `TR-hero-database-014`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0007 — Hero Database — HeroData Resource + HeroDatabase Static Query Layer (MVP scope)
**ADR Decision Summary**: `class_name HeroDatabase extends RefCounted` + `@abstract` (G-22 typed-reference parse-time block) + all-static methods + lazy-init `static var _heroes_loaded: bool` + `static var _heroes: Dictionary[StringName, HeroData] = {}`. Single-file JSON storage at `assets/data/heroes/heroes.json` with `JSON.new().parse()` instance form for line/col diagnostics. 6 public static query methods per §4. 5th-precedent stateless-static pattern (ADR-0008→0006→0012→0009→0007).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `JSON.new().parse()` instance form pre-Godot-4.0 stable; `FileAccess.get_file_as_string()` pre-4.4 stable (READ path only — 4.4 `store_*` change does NOT apply); `Dictionary[StringName, HeroData]` typed Godot 4.4+ stable; `@abstract` decorator pre-cutoff stable; `Array[HeroData]` typed-array construction pattern (G-2 prevention) MANDATORY: use `var result: Array[HeroData] = []` + `result.append(hero)` + `return result` — NOT `_heroes.values().duplicate()` which silently demotes typing per G-2.

**Control Manifest Rules (Foundation layer)**:
- Required: Foundation-layer modules live under `src/foundation/` per architecture.md layer invariants
- Required: G-15 test isolation — `_heroes_loaded = false` reset in `before_test()` for every test that calls any HeroDatabase method
- Required: G-22 enforcement — `@abstract` decoration on `class_name HeroDatabase extends RefCounted` blocks typed-reference instantiation at parse time
- Forbidden: signal declarations + `connect()` + `emit_signal()` calls (non-emitter invariant per ADR-0001 line 372 — full lint enforcement in story 005)
- Forbidden: `_heroes.values().duplicate()` for typed-array returns (G-2 silent typing demotion)
- Guardrail: `get_hero` <0.001ms (Dictionary[StringName, HeroData] hash lookup)

---

## Acceptance Criteria

*From ADR-0007 §1, §3, §4 + GDD §Detailed Design §Module form, scoped to this story:*

- [ ] **AC-1** (TR-001 module form): `src/foundation/hero_database.gd` exists with `class_name HeroDatabase extends RefCounted` + `@abstract` decoration + zero `_init`, zero `_ready`, zero `_process`, zero instance fields, zero signals, zero subscriptions
- [ ] **AC-2** (TR-001 + TR-014 lazy-init state): two static vars present — `_heroes_loaded: bool = false` + `_heroes: Dictionary[StringName, HeroData] = {}` (Godot 4.4+ typed Dictionary syntax)
- [ ] **AC-3** (TR-003 storage path + lazy-init): private static helper `_load_heroes()` reads `assets/data/heroes/heroes.json` via `FileAccess.get_file_as_string()` + parses via `JSON.new().parse()` (instance form, NOT `JSON.parse_string()`); on success sets `_heroes_loaded = true`; on FileAccess failure emits `push_error` + leaves `_heroes_loaded = false`. **No per-record validation in this story** — story 002 owns that.
- [ ] **AC-4** (TR-004 6-method API skeleton): all 6 public static methods declared with correct signatures from ADR-0007 §4:
   1. `static func get_hero(hero_id: StringName) -> HeroData`
   2. `static func get_heroes_by_faction(faction: int) -> Array[HeroData]`
   3. `static func get_heroes_by_class(unit_class: int) -> Array[HeroData]`
   4. `static func get_all_hero_ids() -> Array[StringName]`
   5. `static func get_mvp_roster() -> Array[HeroData]`
   6. `static func get_relationships(hero_id: StringName) -> Array[Dictionary]`
   Each method calls `_load_heroes()` first if `_heroes_loaded == false`. Each method body returns the contract-correct value type (G-2 typed-array construction pattern for collection returns).
- [ ] **AC-5** (TR-005 read-only contract source comment): each query method has `# RETURNS SHARED REFERENCE — consumers MUST NOT mutate fields. Use base+modifier pattern.` source comment immediately above. (Convention-only enforcement; R-1 mitigation regression test ships in story 004.)
- [ ] **AC-6** (TR-014 test isolation): `tests/unit/foundation/hero_database_test.gd` skeleton suite includes `before_test()` that resets `HeroDatabase._heroes_loaded = false` AND `HeroDatabase._heroes = {}` (G-15 obligation; mirrors ADR-0006 `_cache_loaded` precedent)
- [ ] **AC-7** (skeleton test coverage): minimum 6 unit tests in the skeleton suite — one per query method exercising the lazy-init contract on an empty/synthetic-fixture _heroes dict (e.g. `test_get_hero_returns_null_on_miss_with_push_error`, `test_get_all_hero_ids_returns_typed_array_empty_when_no_load`)
- [ ] **AC-8** (regression PASS): full GdUnit4 regression maintains the **506/506 baseline** (or new baseline with the +6 skeleton tests = 512/512) post-story; 0 errors / 0 failures (the carried-forward 1 failure is orthogonal); 0 orphans (G-7 verified — Overall Summary count + zero `Parse Error` matches)

---

## Implementation Notes

*Derived from ADR-0007 §1 (Module Form), §3 (Storage), §4 (Public API), §Migration Plan §2:*

1. **File layout** (~200-250 LoC):
   ```gdscript
   ## hero_database.gd
   ## Ratified by ADR-0007 (Accepted 2026-04-30).
   ##
   ## TEST ISOLATION: every test that calls any HeroDatabase method MUST reset
   ##   HeroDatabase._heroes_loaded = false
   ##   HeroDatabase._heroes = {}
   ## in before_test() per G-15 + ADR-0006 §6 obligation.
   @abstract
   class_name HeroDatabase extends RefCounted

   const _HEROES_JSON_PATH := "res://assets/data/heroes/heroes.json"

   static var _heroes_loaded: bool = false
   static var _heroes: Dictionary[StringName, HeroData] = {}

   # ─── Lazy-init ────────────────────────────────────────────────────────────
   static func _load_heroes() -> void:
       if _heroes_loaded:
           return
       # Story 002 fills in the validation pipeline. This story leaves a stub
       # that reads + parses + dispatches to a placeholder validator that
       # accepts everything (yields _heroes_loaded = true on FileAccess success).
       ...

   # ─── Public API (6 methods) ───────────────────────────────────────────────
   # RETURNS SHARED REFERENCE — consumers MUST NOT mutate fields. Use base+modifier pattern.
   static func get_hero(hero_id: StringName) -> HeroData:
       _load_heroes()
       if not _heroes.has(hero_id):
           push_error("HeroDatabase.get_hero: unknown hero_id '%s'" % hero_id)
           return null
       return _heroes[hero_id]
   # ... 5 more methods ...
   ```

2. **G-2 typed-array construction discipline** (from ADR-0007 §4 + control-manifest Foundation rules) — for `get_heroes_by_faction` / `get_heroes_by_class` / `get_all_hero_ids` / `get_mvp_roster`:
   ```gdscript
   # CORRECT
   var result: Array[HeroData] = []
   for hero in _heroes.values():
       if hero.faction == faction:
           result.append(hero)
   return result

   # FORBIDDEN — silent typing demotion to Array (untyped)
   return _heroes.values().filter(func(h): return h.faction == faction)
   ```

3. **`_load_heroes()` placeholder body for this story** (story 002 fills in CR-1/CR-2/EC-1/EC-2 validation): minimal happy-path read + parse + per-record `HeroData` instantiation via field-by-field assignment. No validation severity tiers in this story — wraps every record in `_heroes` directly. **Story 002 will add the validation pipeline as a pre-cache check before insertion.**

4. **`get_relationships(hero_id)` MVP shape**: returns `hero.relationships` directly (`Array[Dictionary]` typed; provisional shape per ADR-0007 §2 deferral note — Formation Bonus ADR will migrate to typed Resource). Self-reference / orphan FK / asymmetric conflict WARNING-tier dropping ships in **story 004**.

5. **Error contract for `get_hero` miss**: per ADR-0007 §4 — null + `push_error` (NOT degrade-with-default). The skeleton test `test_get_hero_returns_null_on_miss_with_push_error` validates this contract.

6. **Test fixture pattern**: skeleton tests bypass file load by directly populating `_heroes` in `before_test()`:
   ```gdscript
   func before_test() -> void:
       HeroDatabase._heroes_loaded = false
       HeroDatabase._heroes = {}
       # Synthetic fixture for skeleton tests:
       var hero := HeroData.new()
       hero.hero_id = &"shu_001_liu_bei"
       hero.faction = 0  # SHU
       HeroDatabase._heroes = {&"shu_001_liu_bei": hero}
       HeroDatabase._heroes_loaded = true
   ```

7. **Same-patch §4 verification (carryover from ADR-0007 §Migration Plan)**: confirm `design/gdd/hero-database.md` Status field reads "Accepted via ADR-0007 (2026-04-30)" — if still "Designed", flip in this same patch (1-line edit).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: Per-record validation pipeline (CR-1 hero_id regex + CR-2 range checks + EC-1 duplicate + EC-2 skill array integrity FATAL severity)
- **Story 003**: `assets/data/heroes/heroes.json` MVP roster authoring + happy-path integration test
- **Story 004**: Relationship WARNING tier (EC-4/5/6) + R-1 consumer-mutation regression test
- **Story 005**: Perf baseline + non-emitter lint script + Polish-tier validation lint scaffold + TD entry

---

## QA Test Cases

*Lean mode — orchestrator-authored. Convergent /code-review at story close-out validates these.*

**AC-1** (module form):
- Given: `src/foundation/hero_database.gd` does not exist pre-story
- When: file created with `@abstract class_name HeroDatabase extends RefCounted` + zero instance state
- Then: `grep -E '^@abstract$' src/foundation/hero_database.gd` returns 1 match; `grep -E '^(signal |func _init|func _ready|func _process)' src/foundation/hero_database.gd` returns 0 matches
- Edge case: any `var ` at module scope without `static` qualifier is a violation (instance fields forbidden)

**AC-2** (static vars + typed Dictionary):
- Given: module file post-creation
- When: grep for `^static var _heroes_loaded: bool` and `^static var _heroes: Dictionary\[StringName, HeroData\]`
- Then: both return 1 match each
- Edge case: untyped `Dictionary` (without `[StringName, HeroData]`) is a violation per Godot 4.4+ typed-Dictionary syntax discipline

**AC-3** (lazy-init contract):
- Given: `_heroes_loaded == false` + valid `heroes.json` at expected path
- When: any query method called for the first time
- Then: `_load_heroes()` invoked + `_heroes_loaded` flips to true + subsequent calls skip re-loading
- Edge case: FileAccess returns empty string (file missing) → `push_error` + `_heroes_loaded` stays false; next call retries (acceptable for MVP — story 002 may strengthen this)

**AC-4** (6-method API signatures):
- Given: module post-implementation
- When: grep `^static func (get_hero|get_heroes_by_faction|get_heroes_by_class|get_all_hero_ids|get_mvp_roster|get_relationships)` runs
- Then: 6 matches with exact signatures from §4 (parameter types + return types verified per match)
- Edge case: any method returning `Array` (untyped) instead of `Array[HeroData]` / `Array[StringName]` / `Array[Dictionary]` is a G-2 violation

**AC-5** (read-only source comments):
- Given: 6 query methods declared
- When: grep `# RETURNS SHARED REFERENCE` runs against the file
- Then: 6 matches (one per query method)
- Edge case: comment present on `_load_heroes` (private helper) is harmless but not required

**AC-6** (test isolation):
- Given: `tests/unit/foundation/hero_database_test.gd` skeleton suite
- When: `before_test()` body inspected
- Then: contains both `HeroDatabase._heroes_loaded = false` AND `HeroDatabase._heroes = {}` lines
- Edge case: `before_each()` (GdUnit3 idiom) is a violation — must be `before_test()` per GdUnit4 v6.1.2 lifecycle hook

**AC-7** (skeleton test coverage):
- Given: skeleton suite post-implementation
- When: `tests/unit/foundation/hero_database_test.gd` is run via `godot --headless ... -a tests/unit/foundation/`
- Then: ≥6 tests, all pass; one test asserts `get_hero(&"unknown")` returns null + push_error trail; one test asserts `get_all_hero_ids()` returns typed `Array[StringName]` (NOT `Array`)
- Edge case: any test that does not reset `_heroes_loaded` in `before_test()` will have order-dependent state — expect orphan or sporadic failures if isolation is wrong

**AC-8** (regression PASS):
- Given: post-story full regression run (`godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests/unit -a res://tests/integration -c`)
- Then: `Overall Summary` reports ≥506+ tests, 0 errors, ≤1 failure (the orthogonal carried-forward failure), 0 orphans, exit ≤1 (1 acceptable iff only the carried failure)
- Edge case: any new failure beyond the carried baseline must be triaged before close-out

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/foundation/hero_database_test.gd` — skeleton suite covering AC-1..AC-7; must exist + pass
- Smoke check (optional for Logic stories): `production/qa/smoke-hero-database-story-001-YYYY-MM-DD.md` only if regression baseline shifts unexpectedly

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (`hero_data.gd` already shipped 2026-04-30 with 26 @export fields per ADR-0007 §Migration Plan §1)
- Unlocks: Story 002 (validation pipeline needs the `_load_heroes()` skeleton to inject validation into); Story 003 (MVP roster authoring needs the module to load); Story 004 (WARNING tier extends `_load_heroes()`); Story 005 (perf + lint scripts target this file)
