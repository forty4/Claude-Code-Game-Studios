# Story 001: UnitRole module skeleton + UnitClass enum + provisional HeroData wrapper

> **Epic**: unit-role
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 2-3 hours (S)

## Context

**GDD**: `design/gdd/unit-role.md`
**Requirement**: `TR-unit-role-001`, `TR-unit-role-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 — Unit Role System
**ADR Decision Summary**: `class_name UnitRole extends RefCounted` + `@abstract` + all-static methods + `enum UnitClass` typed parameter binding. 4-precedent stateless-calculator pattern (ADR-0008 → ADR-0006 → ADR-0012 → ADR-0009). Provisional `HeroData` Resource wrapper per ADR-0009 §Migration Plan §3 ships ahead of ADR-0007 with parameter-stable migration when ADR-0007 ratifies.

**Engine**: Godot 4.6 | **Risk**: LOW (no post-cutoff APIs; `class_name` + `RefCounted` + `static func` + typed `enum` + `@abstract` decorator all stable; `@abstract` is 4.5+ confirmed)
**Engine Notes**: `@abstract` blocks `UnitRole.new()` at **runtime**, NOT parse time (per godot-specialist `/architecture-review` 2026-04-28 Item 1 correction). The test for the non-instantiability invariant must `expect_runtime_error()`, NOT assert parse rejection. `enum UnitClass` typed parameter binding (`unit_class: UnitRole.UnitClass`) produces stricter type-checker warnings at call sites than raw `int` (per godot-specialist 2026-04-28 design-time validation Item 1).

**Control Manifest Rules (Foundation layer + direct ADR cites)**:
- Required (manifest, ADR-0001): "GameBus holds ZERO game state; pure signal relay only" — UnitRole inherits the zero-state pattern (zero instance fields, zero signal emissions, zero signal subscriptions per ADR-0001 line 375 non-emitter list)
- Required (direct, ADR-0009 §1): `class_name UnitRole extends RefCounted` + `@abstract` decorator + all `static func` + zero instance fields + lazy-init `static var _coefficients_loaded: bool` flag only
- Required (direct, ADR-0009 §Migration Plan §3): provisional `class_name HeroData extends Resource` at `src/foundation/hero_data.gd` with @export-annotated fields per `hero-database.md` §Detailed Rules — placeholder for ADR-0007
- Forbidden (manifest extension, ADR-0009): `signal` declarations in `src/foundation/unit_role.gd` (forbidden_pattern `unit_role_signal_emission` per `docs/registry/architecture.yaml` line 519+)
- Forbidden (direct, ADR-0009 §1 — Alternative 2 rejected): autoload registration at `/root/UnitRole` — NOT registered in project.godot
- Guardrail (direct, ADR-0009): zero per-battle initialization, zero per-battle state, zero per-battle teardown beyond the lazy-init data cache (which persists for the GDScript engine session per ADR-0006 §6)

---

## Acceptance Criteria

*Architectural setup story — verifies §1 module form invariants + §2 enum declaration + §Migration Plan §3 provisional HeroData wrapper. No direct GDD AC; all 23 ACs depend on the contracts established here.*

- [ ] `src/foundation/unit_role.gd` exists with `class_name UnitRole extends RefCounted` + `@abstract` decorator + zero instance fields
- [ ] `enum UnitClass { CAVALRY = 0, INFANTRY = 1, ARCHER = 2, STRATEGIST = 3, COMMANDER = 4, SCOUT = 5 }` declared inside the class body
- [ ] `static var _coefficients_loaded: bool = false` is the ONLY mutable state; no other `var` declarations (instance or static) at this story's scope
- [ ] `UnitRole.new()` raises a runtime error (via `@abstract`); verified by test that uses `expect_runtime_error()` semantics (NOT parse-time rejection assertion)
- [ ] `UnitRole.UnitClass.CAVALRY` etc. are accessible from external scripts (qualified-form cross-script reference works in 4.6)
- [ ] `src/foundation/hero_data.gd` exists with `class_name HeroData extends Resource` + @export-annotated fields per `hero-database.md` §Detailed Rules: `stat_might`, `stat_intellect`, `stat_command`, `stat_agility`, `base_hp_seed`, `base_initiative_seed`, `move_range`, `default_class`, `innate_skill_ids: Array[StringName]`, `equipment_slot_override` (typed per GDD)
- [ ] HeroData fields all annotated `@export` (non-`@export` fields are silently dropped by ResourceSaver per ADR-0003 TR-save-load-002)
- [ ] HeroData class doc-comment cites: "Provisional shape per ADR-0009 §Migration Plan §3; ADR-0007 Hero DB will ratify the authoritative field set when written. Migration parameter-stable per `unit-role.md` §Dependencies upstream contract."
- [ ] `UnitRole` class doc-comment cites: "Foundation-layer stateless gameplay rules calculator per ADR-0009 §Engine Compatibility. 4-precedent class_name+RefCounted+all-static pattern (ADR-0008 → ADR-0006 → ADR-0012 → ADR-0009). Non-emitter per ADR-0001 line 375."

---

## Implementation Notes

*From ADR-0009 §1, §2, §Migration Plan §1 + §3:*

1. File path convention: `src/foundation/unit_role.gd` (matches ADR-0009 §1 source location). NOT `src/core/`.
2. The `@abstract` decoration goes at the class top with `class_name` + `extends`:
   ```gdscript
   @abstract
   class_name UnitRole
   extends RefCounted
   ```
3. The `enum UnitClass` declaration goes inside the class body, before any methods. Integer backing values 0..5 are explicit (non-default) for entities.yaml + Dictionary key compatibility.
4. The `static var _coefficients_loaded: bool = false` is the lazy-init guard flag; populated by `_load_coefficients()` in Story 002. This story ships the declaration only.
5. `HeroData` field types per `hero-database.md` §Detailed Rules: `stat_*` are `int` in [1, 100]; `base_hp_seed` and `base_initiative_seed` are `int` in [1, 100]; `move_range` is `int` in [2, 6]; `default_class` is `int` (will become `UnitRole.UnitClass` typed once cross-script enum reference is verified working in test); `innate_skill_ids: Array[StringName]` (NOT `Array[String]` — per ADR-0012 `damage_calc_dictionary_payload` precedent); `equipment_slot_override` is `Array[int]` or `null` (typed per GDD pending ADR-0007 ratification).
6. **Do not** add any methods beyond the @abstract class declaration in this story. Stories 002-006 add the data layer + 8 public static methods + 1 const Dictionary.
7. **Do not** read or import from `BalanceConstants` in this story — that comes in Story 002 + Story 003. The skeleton has no runtime dependencies.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `unit_roles.json` schema + lazy-init JSON loader + `_load_coefficients()` body + safe-default fallback table
- Story 003: F-1..F-5 derived-stat static methods (`get_atk`, `get_phys_def`, `get_mag_def`, `get_max_hp`, `get_initiative`) + `get_effective_move_range`
- Story 004: `get_class_cost_table` + R-1 caller-mutation isolation regression test
- Story 005: `get_class_direction_mult` + 6×3 table read pattern
- Story 006: `const PASSIVE_TAG_BY_CLASS: Dictionary` declaration + Array[StringName] consumer pattern
- Story 010: non-emitter static-lint test + perf baseline test

---

## QA Test Cases

*Logic story — automated unit test specs. Developer implements against these; do not invent new test cases during implementation.*

- **AC-1 (UnitRole skeleton)**:
  - Given: `src/foundation/unit_role.gd` is on the Godot resource path
  - When: a test script references `UnitRole` (the global class_name)
  - Then: parse + class lookup succeed without error; `is_class("RefCounted")` returns true; reflection shows zero instance fields
  - Edge cases: file rename / class_name typo → parse error surfaces immediately

- **AC-2 (UnitClass enum)**:
  - Given: `UnitRole` is loaded
  - When: a test references `UnitRole.UnitClass.CAVALRY`, `UnitRole.UnitClass.INFANTRY`, ..., `UnitRole.UnitClass.SCOUT`
  - Then: each resolves to its expected int value (0, 1, 2, 3, 4, 5 respectively); `UnitClass.size()` (or equivalent introspection) reports 6 entries
  - Edge cases: typo in enum member name → parse error; integer-cast outside 0..5 → caller responsibility (no validation in UnitRole — Story 003 onward methods will assert)

- **AC-3 (`@abstract` runtime block)**:
  - Given: `UnitRole` is `@abstract`
  - When: a test calls `UnitRole.new()`
  - Then: a **runtime** error is raised (NOT a parse error). The test uses `expect_runtime_error()` or equivalent GdUnit4 pattern; assert the error message references @abstract or instantiation
  - Edge cases: indirect instantiation via `ClassDB.instantiate("UnitRole")` should also fail with runtime error (verify in same test); calling a static method on `UnitRole` (e.g., from Story 003 onward) succeeds normally — `@abstract` only blocks `.new()`

- **AC-4 (HeroData provisional wrapper)**:
  - Given: `src/foundation/hero_data.gd` exists with `class_name HeroData extends Resource`
  - When: a test instantiates `HeroData.new()` and reflects on @export fields
  - Then: all 10 expected fields are present (`stat_might`, `stat_intellect`, `stat_command`, `stat_agility`, `base_hp_seed`, `base_initiative_seed`, `move_range`, `default_class`, `innate_skill_ids`, `equipment_slot_override`); `Array[StringName]` typing on `innate_skill_ids` confirmed via inspection (assigning `Array[String]` element triggers runtime type rejection)
  - Edge cases: missing @export annotation → ResourceSaver round-trip silently drops the field (caught in Story 002+ when JSON-derived HeroData hits a save/load cycle); ADR-0007 future amendment may add fields → migration parameter-stable per §Migration Plan §From provisional HeroData

- **AC-5 (Doc-comment compliance)**:
  - Given: source files are written
  - When: a test (or grep-based CI step) inspects file contents
  - Then: `unit_role.gd` head-of-file doc-comment contains "ADR-0009", "Foundation", "non-emitter"; `hero_data.gd` head-of-file doc-comment contains "ADR-0009 §Migration Plan §3", "ADR-0007", "provisional"
  - Edge cases: future doc-comment edits should not break these grep predicates — they're invariants

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/foundation/unit_role_skeleton_test.gd` — must exist and pass (5 ACs above; ~30-60 LoC test file)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (epic-leading story)
- Unlocks: Story 002 (JSON loader needs the `_coefficients_loaded` flag declaration), Story 006 (PASSIVE_TAG_BY_CLASS const needs `UnitClass` enum), Story 007 (cross-doc append independent of UnitRole code but conceptually depends on epic kickoff)
