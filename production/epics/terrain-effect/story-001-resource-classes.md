# Story 001: TerrainModifiers + CombatModifiers Resource classes

> **Epic**: terrain-effect
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 1.5-2 hours (2 Resource classes + 1 unit test; spec verbatim from ADR-0008 §Decision 6)

## Context

**GDD**: `design/gdd/terrain-effect.md`
**Requirement**: `TR-terrain-effect-001`, `TR-terrain-effect-009` (bridge_no_flank flag)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0008 Terrain Effect System
**ADR Decision Summary**: Two typed `Resource` subclasses for the public query API surface — `TerrainModifiers` (raw uncapped values for HUD display per EC-12) and `CombatModifiers` (clamped values for Damage Calc with the `bridge_no_flank` denormalised flag per CR-5).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `@export Array[StringName]` on a `Resource` subclass is 4.0-stable; ResourceSaver round-trip preserves `Array[StringName]` typing per godot-specialist 2026-04-25 validation Item 5. No post-cutoff APIs. The G-2 typed-array `.duplicate()` demotion does NOT apply at this story's scope (no array duplication; defensive copy via fresh-construction lands in story-004/005).

**Control Manifest Rules (Core layer)**:
- Required: All gameplay Resources use typed `@export` fields (ADR-0003 convention, mirrored in ADR-0004 and ADR-0008)
- Required: `class_name` matches PascalCase (`TerrainModifiers`, `CombatModifiers`); file matches snake_case (`terrain_modifiers.gd`, `combat_modifiers.gd`)
- Forbidden: Non-`@export` serialized fields (silently dropped by `ResourceSaver` — same gotcha story-001 of map-grid epic surfaced)
- Forbidden: `class_name` collision with Godot 4.6 built-ins per G-12 — both `TerrainModifiers` and `CombatModifiers` verified collision-free 2026-04-25 (ADR-0008 Verification Required §3, CLOSED)

---

## Acceptance Criteria

*From ADR-0008 §Decision 6 + §Key Interfaces, scoped to Resource schema only (no runtime query behaviour):*

- [ ] `src/core/terrain_modifiers.gd` declares `class_name TerrainModifiers extends Resource` with `@export` fields: `defense_bonus: int = 0`, `evasion_bonus: int = 0`, `special_rules: Array[StringName] = []`
- [ ] `src/core/combat_modifiers.gd` declares `class_name CombatModifiers extends Resource` with `@export` fields: `defender_terrain_def: int = 0`, `defender_terrain_eva: int = 0`, `elevation_atk_mod: int = 0`, `elevation_def_mod: int = 0`, `bridge_no_flank: bool = false`, `special_rules: Array[StringName] = []`
- [ ] Default construction of both classes yields all-zero / empty / false defaults exactly as documented
- [ ] `TerrainModifiers` instance round-trips via `ResourceSaver.save(path)` → `ResourceLoader.load(path, "", CACHE_MODE_IGNORE)` with identical field values, including the `Array[StringName]` content
- [ ] `CombatModifiers` instance round-trips identically (covers all 6 fields including `bridge_no_flank: bool` and `Array[StringName]`)
- [ ] Round-trip preserves `int`, `bool`, and `StringName` element types (no silent `Variant` coercion in `Array[StringName]`)

---

## Implementation Notes

*Derived from ADR-0008 §Decision 6 + §Key Interfaces (lines 470-491) + Notes for Implementation §5:*

- Both classes are `extends Resource`. No `RefCounted` subclassing (`Resource` already extends `RefCounted` transitively).
- Use `@export` on every serialized field. ADR-0003's EchoMark + map-grid story-001 precedents both confirm: non-`@export` fields are silently dropped by `ResourceSaver`.
- `special_rules: Array[StringName] = []` initial value MUST be inline default — `[]` literal binds correctly to `Array[StringName]` in 4.6 inspector.
- `bridge_no_flank` is denormalised — also present in `special_rules` array. Damage Calc consumers may check either; the bool field is faster (no array scan). Both must be set consistently when populated by `get_combat_modifiers()` in story-005.
- This story does NOT exercise the defensive-copy pattern (returning new instances each query call). That lands in story-004/005 when the queries are wired up. This story's tests construct instances directly with `.new()`.
- The `special_rules` array typing has implications for G-2 (typed-array `.duplicate()` demotion). When story-005 populates `_terrain_table` entries from JSON, the `special_rules` arrays must be assembled with explicit typed assignment, not via `.duplicate()`. Document this in the source-file header to forewarn implementers of later stories.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 002: `class_name TerrainEffect extends RefCounted`, static vars, terrain-type integer constants, lazy-init guard, `reset_for_tests()` discipline
- Story 003: `terrain_config.json` authoring + `load_config()` parsing + schema validation + safe-default fallback
- Story 004: `get_terrain_modifiers()` + `get_terrain_score()` queries that return populated instances of these Resource classes
- Story 005: `get_combat_modifiers()` that returns populated `CombatModifiers` with bridge_no_flank flag + elevation table lookup + clamps

---

## QA Test Cases

*Authored from ADR-0008 §Decision 6 + §Key Interfaces directly (lean mode — QL-STORY-READY gate skipped). Developer implements against these — do not invent new test cases during implementation.*

- **AC-1**: TerrainModifiers class declaration with all `@export` fields and correct defaults
  - Given: freshly-loaded test script
  - When: `var m := TerrainModifiers.new()`
  - Then: `assert_int(m.defense_bonus).is_equal(0)`, `assert_int(m.evasion_bonus).is_equal(0)`, `assert_int(m.special_rules.size()).is_equal(0)`
  - Edge cases: `typeof(m.special_rules) == TYPE_ARRAY` and the array's typed-element class is `StringName` (verify via `m.special_rules.append(&"test"); m.special_rules[0] is StringName` — `StringName.is_subsequence_of` is a method available only on StringName)

- **AC-2**: CombatModifiers class declaration with all `@export` fields and correct defaults
  - Given: freshly-loaded test script
  - When: `var c := CombatModifiers.new()`
  - Then: each int field == 0, `bridge_no_flank == false`, `special_rules.size() == 0`
  - Edge cases: default construction is the canonical "no terrain effect" state — used as zero-fill for OOB coord queries in story-004 (AC-14)

- **AC-3**: TerrainModifiers ResourceSaver round-trip including Array[StringName]
  - Given: TerrainModifiers with `defense_bonus = 25`, `evasion_bonus = 5`, `special_rules = [&"bridge_no_flank", &"siege_terrain"]`
  - When: `ResourceSaver.save(m, "user://test_terrain_modifiers.tres")` then `ResourceLoader.load("user://test_terrain_modifiers.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as TerrainModifiers`
  - Then: loaded fields match saved field-by-field; `loaded.special_rules.size() == 2`; `loaded.special_rules[0] == &"bridge_no_flank"`; both elements are still `StringName` type after round-trip
  - Edge cases: temp file cleaned up in `after_test`; CACHE_MODE_IGNORE consistent with ADR-0003/0004 convention

- **AC-4**: CombatModifiers ResourceSaver round-trip including bool + Array[StringName]
  - Given: CombatModifiers with `defender_terrain_def = -15`, `defender_terrain_eva = 30`, `elevation_atk_mod = 8`, `elevation_def_mod = -8`, `bridge_no_flank = true`, `special_rules = [&"bridge_no_flank"]`
  - When: round-trip via `ResourceSaver.save` + `ResourceLoader.load`
  - Then: all 6 fields match; signed integer `-15` preserved (no abs / unsigned coercion); `bool` preserved
  - Edge cases: signed-int round-trip is the implicit guard for AC-7 negative-defense scenario (story-005 covers the F-1 clamp logic itself; this story covers the schema's ability to carry a negative value)

- **AC-5**: Type preservation across save/load (no silent Variant coercion)
  - Given: round-tripped instances from AC-3 and AC-4
  - When: `typeof(loaded.defense_bonus)`, `typeof(loaded.bridge_no_flank)`, `typeof(loaded.special_rules)` inspected
  - Then: `TYPE_INT`, `TYPE_BOOL`, `TYPE_ARRAY` respectively — no float / Variant fallback
  - Edge cases: this guards against the non-`@export` silent-drop gotcha + the typed-array demotion gotcha (G-2). Inspector-typed `@export Array[StringName]` should round-trip with element typing intact in 4.6 per godot-specialist 2026-04-25 validation Item 5.

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/terrain_resource_classes_test.gd` — must exist and pass (5 tests covering AC-1..5)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (greenfield Resource schema; ADR-0008 Accepted; map-grid epic provides the precedent pattern)
- Unlocks: Story 002 (TerrainEffect skeleton — static vars typed against these Resource classes), Story 004 (queries return TerrainModifiers), Story 005 (queries return CombatModifiers)
