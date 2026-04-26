# Story 002: AttackerContext / DefenderContext / ResolveModifiers / ResolveResult RefCounted wrapper classes

> **Epic**: damage-calc
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 2-3 hours (4 wrapper classes with `class_name` + `make()` factories; no pipeline logic — purely structural)

## Context

**GDD**: `design/gdd/damage-calc.md`
**Requirement**: `TR-damage-calc-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012 Damage Calc (Accepted 2026-04-26)
**ADR Decision Summary**: 4 typed `RefCounted` wrapper classes replace Grid Battle's prior Dictionary payload — `AttackerContext` (5 fields), `DefenderContext` (3 fields), `ResolveModifiers` (10 fields), `ResolveResult` (5 fields). Each declared with `class_name` and a static `make()` factory. `Array[StringName]` discipline mandatory on `.passives` / `.source_flags` / `.vfx_tags`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `class_name X extends RefCounted` + typed `Array[StringName]` parameter binding is enforced at runtime (assignment / insertion / parameter-bind time), NOT parse-time per ADR-0012 §2 + godot-specialist `/architecture-review` Item 2 verdict 2026-04-26. The release-build defense layer is the StringName literal `&"foo"` comparison — even with a bypass-seam `Array[String]`, `&"foo" in arr` returns `false`. RefCounted free is deterministic at scope exit (no GC pause) per godot-specialist Item 12.

**Control Manifest Rules (Feature layer)**:
- Required: All wrappers `extends RefCounted` with `class_name` matching PascalCase; file matches snake_case
- Required: All serialized-shape fields use typed declarations (no `Variant`); arrays use `Array[StringName]` not `Array`
- Forbidden: Direct field-by-field construction in production code (use `make()` factories); `.new()` + field assignment is reserved for AC-DC-51(b) bypass-seam tests only (per ADR-0012 Implementation Guidelines #3)
- Forbidden: Adding `signal` declarations to wrapper classes (these are pure data containers, not emitters)

---

## Acceptance Criteria

*From ADR-0012 §2 Type Boundary + §Implementation Guidelines:*

- [ ] `src/feature/damage_calc/attacker_context.gd` declares `class_name AttackerContext extends RefCounted` with fields: `unit_id: StringName`, `unit_class: UnitRole.Class` (enum reference — see Implementation Notes), `charge_active: bool = false`, `defend_stance_active: bool = false`, `passives: Array[StringName] = []`. Static `make(unit_id, unit_class, charge_active, defend_stance_active, passives) -> AttackerContext` factory present.
- [ ] `src/feature/damage_calc/defender_context.gd` declares `class_name DefenderContext extends RefCounted` with fields: `unit_id: StringName`, `terrain_def: int` (range [-30, +30] per ADR-0008 contract), `terrain_evasion: int` (range [0, 30]). Static `make(unit_id, terrain_def, terrain_evasion) -> DefenderContext` factory present.
- [ ] `src/feature/damage_calc/resolve_modifiers.gd` declares `class_name ResolveModifiers extends RefCounted` with enum `AttackType { PHYSICAL, MAGICAL }` and 10 fields: `attack_type: AttackType = AttackType.PHYSICAL`, `source_flags: Array[StringName] = []`, `direction_rel: StringName = &"FRONT"`, `is_counter: bool = false`, `skill_id: String = ""`, `rng: RandomNumberGenerator`, `round_number: int = 1`, `rally_bonus: float = 0.0`, `formation_atk_bonus: float = 0.0`, `formation_def_bonus: float = 0.0`. Static `make(...)` factory with required + optional parameters as specified in ADR-0012 §2.
- [ ] `src/feature/damage_calc/resolve_result.gd` declares `class_name ResolveResult extends RefCounted` with enums `Kind { HIT, MISS }` and `AttackType { PHYSICAL, MAGICAL }`, 5 fields: `kind: Kind`, `resolved_damage: int = 0`, `attack_type: AttackType = AttackType.PHYSICAL`, `source_flags: Array[StringName] = []`, `vfx_tags: Array[StringName] = []`. Static `hit(damage, atk_type, flags, vfx) -> ResolveResult` and `miss(flags = []) -> ResolveResult` factories present.
- [ ] All 4 classes have `class_name` collision-free check vs. Godot 4.6 built-ins (per G-3 gotcha + G-12 collision rule)
- [ ] All 4 classes default-construct cleanly via `.new()` and produce expected default field values

---

## Implementation Notes

*Derived from ADR-0012 §2 + §Implementation Guidelines #1, #3, #7:*

- **`UnitRole.Class` enum reference**: `unit_class: UnitRole.Class` requires `UnitRole` to be a known type. Per ADR-0012 §8 provisional-dependency strategy on ADR-0009: `UnitRole` is NOT YET written. **Workaround for this story**: declare a local enum `Class { CAVALRY, SCOUT, INFANTRY, ARCHER }` in `attacker_context.gd` with the same values as `unit-role.md` §EC-7. Field declared as `unit_class: int = 0` (since enum cross-referencing without UnitRole.gd is awkward) with a doc comment `# Maps to AttackerContext.Class enum (CAVALRY=0, SCOUT=1, INFANTRY=2, ARCHER=3) — local until ADR-0009 lands`. When ADR-0009 lands, migrate to `unit_class: UnitRole.Class` (call-sites unchanged since enum values are identical).
- **`make()` factory pattern**: each factory signature mirrors the field order in the class declaration; default values for optional parameters match the field defaults. Per ADR-0012 §Decision 2 final paragraph, signature mismatches are parse errors (positional/typed argument binding catches drift at the Grid Battle call site).
- **Field ordering and default values**: copy verbatim from ADR-0012 §2. Do NOT invent new defaults or reorder fields.
- **`source_flags` and `vfx_tags` array typing**: `Array[StringName]` not `Array[String]`. The runtime enforcement is at parameter-bind time (per godot-specialist Item 2). The release-build defense for AC-DC-51 bypass-seam is the StringName literal comparison in F-DC-5 (validated via story-006).
- **No pipeline logic in this story**: these classes are pure data containers. No `resolve()` method, no field validation logic, no helper methods beyond the static factories. The 12-stage pipeline lives in `damage_calc.gd` (story-003 onward).
- **`@abstract` decorator (4.5+, optional)**: NOT applied to wrappers (they need to be instantiable). The `@abstract` discussion in ADR-0012 §Implementation Guidelines #8 applies to `DamageCalc` itself (story-006), not to these wrappers.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 003: `class_name DamageCalc extends RefCounted` itself + Stage-0 pipeline (invariant guards + evasion roll); the wrappers must exist FIRST so `damage_calc.gd` can reference them
- Story 004-006: pipeline stages (F-DC-2..F-DC-7)
- Story 008: AC-DC-51 bypass-seam test class `TestAttackerContextBypass` (separate test-only RefCounted subclass)

---

## QA Test Cases

*Authored from ADR-0012 §2 directly (lean mode — QL-STORY-READY gate skipped). Developer implements against these.*

- **AC-1**: AttackerContext default construction
  - Given: freshly-loaded test
  - When: `var ctx := AttackerContext.new()`
  - Then: `ctx.unit_id == &""` (or empty StringName), `ctx.unit_class == 0` (CAVALRY default per local-enum workaround), `ctx.charge_active == false`, `ctx.defend_stance_active == false`, `ctx.passives.size() == 0` AND typed-array element type is `StringName`
  - Edge cases: appending a `String` to `passives` should runtime-fail at insertion time (Godot 4.6 typed-array enforcement) — note this in story-006 AC-DC-51 test design

- **AC-2**: AttackerContext.make() factory
  - Given: valid argument set
  - When: `var ctx := AttackerContext.make(&"a", 0, true, false, [&"passive_charge"])`
  - Then: every field set per arguments; `ctx.passives` is `Array[StringName]` with one element `&"passive_charge"`
  - Edge cases: passing wrong-typed args should runtime-fail at parameter-bind time (e.g., `passives = ["passive_charge"]` String-array)

- **AC-3**: DefenderContext default + make()
  - Given: test
  - When: `var def := DefenderContext.new()` then `var def2 := DefenderContext.make(&"b", 15, 5)`
  - Then: defaults zero/empty for `def`; `def2.terrain_def == 15`, `def2.terrain_evasion == 5`
  - Edge cases: ADR-0008 contract is that `terrain_def ∈ [-30,+30]` already-clamped at the Terrain Effect boundary; this wrapper does NOT re-validate (per ADR-0012 §8 — opaque clamped contract)

- **AC-4**: ResolveModifiers default + make()
  - Given: a `RandomNumberGenerator.new()` instance + valid required args
  - When: `var mod := ResolveModifiers.make(ResolveModifiers.AttackType.PHYSICAL, rng, &"FRONT", 1)`
  - Then: required fields set; optional fields use defaults (`is_counter == false`, `skill_id == ""`, `source_flags.size() == 0`, `rally_bonus == 0.0`, `formation_atk_bonus == 0.0`, `formation_def_bonus == 0.0`)
  - Edge cases: optional `make()` with all 10 args populated also succeeds; assert each field reflects its argument

- **AC-5**: ResolveResult.hit() and .miss() factories
  - Given: test
  - When: `var hit := ResolveResult.hit(50, ResolveResult.AttackType.PHYSICAL, [&"counter"], [&"vfx_counter"])` AND `var miss := ResolveResult.miss([&"invariant_violation:rng_null"])`
  - Then: `hit.kind == ResolveResult.Kind.HIT`, `hit.resolved_damage == 50`, `hit.source_flags == [&"counter"]`, `hit.vfx_tags == [&"vfx_counter"]`; `miss.kind == ResolveResult.Kind.MISS`, `miss.resolved_damage == 0`, `miss.source_flags == [&"invariant_violation:rng_null"]`
  - Edge cases: `ResolveResult.miss()` (zero-args overload) returns MISS with empty source_flags; `ResolveResult.hit()` with empty `vfx_tags` is valid (no VFX dispatch)

- **AC-6**: class_name collision-free with Godot 4.6 built-ins
  - Given: project search
  - When: grep `AttackerContext`, `DefenderContext`, `ResolveModifiers`, `ResolveResult` against `docs/engine-reference/godot/` and against `Engine.has_class()` runtime check
  - Then: no Godot 4.6 built-in by these names; G-3 / G-12 collision-free (per ADR-0008 + ADR-0012 precedent)
  - Edge cases: confirm `ResolveResult` does not collide with future engine `Result` builtin (Godot 4.6 has no such class as of pinned version)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/damage_calc/wrapper_classes_test.gd` — must exist and pass

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (CI infrastructure prerequisite — required for `tests/unit/damage_calc/` discovery + headless CI run)
- Unlocks: Story 003 (Stage 0 pipeline references these wrappers)
