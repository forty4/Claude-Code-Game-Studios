# Story 006: PASSIVE_TAG_BY_CLASS const Dictionary + Array[StringName] consumer pattern

> **Epic**: unit-role
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 1-2 hours (XS)

## Context

**GDD**: `design/gdd/unit-role.md`
**Requirement**: `TR-unit-role-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 — Unit Role System (§7 Passive Tag Canonicalization) + ADR-0012 — Damage Calc (`damage_calc_dictionary_payload` forbidden_pattern precedent for Array[StringName] discipline)
**ADR Decision Summary**: 6 StringName tags locked as canonical passive set: `&"passive_charge"` (CAVALRY), `&"passive_shield_wall"` (INFANTRY), `&"passive_high_ground_shot"` (ARCHER), `&"passive_tactical_read"` (STRATEGIST), `&"passive_rally"` (COMMANDER), `&"passive_ambush"` (SCOUT). Exposed via `const PASSIVE_TAG_BY_CLASS: Dictionary` keyed by UnitClass enum int. `Array[StringName]` is the mandatory typed-array form for any consumer assembling passive-tag sets.

**Engine**: Godot 4.6 | **Risk**: LOW (`const` Dictionary with enum-int keys + StringName literal `&"foo"` values stable in 4.x; StringName interning is process-global per godot-specialist `/architecture-review` 2026-04-28 Item 7)
**Engine Notes**: `const` in GDScript MUST be initialized at parse time with literal values — cannot read from JSON. The `passive_tag` field in `unit_roles.json` (per Story 002 schema) is for documentation + cross-system tracking + CI lint verification, NOT runtime read. The runtime accessor reads the const Dictionary, not the JSON. `&"passive_charge"` StringName literal is process-globally interned: `&"passive_charge" == &"passive_charge"` is reliable across all call sites in Godot 4.6.

**Control Manifest Rules (Foundation layer + direct ADR cites)**:
- Required (direct, ADR-0009 §3 + §7): `const PASSIVE_TAG_BY_CLASS: Dictionary` declared at class body level (parse-time literal); keyed by `UnitClass` enum int values; values are `&"passive_*"` StringName literals
- Required (direct, ADR-0012 forbidden_pattern `damage_calc_dictionary_payload` precedent): `Array[StringName]` mandatory for any consumer assembling passive-tag sets — `Array[String]` is a silent-wrong-answer hole per ADR-0012 EC-DC-25 / AC-DC-51
- Required (direct, ADR-0009 §7): The 6 StringName tags are LOCKED. Adding a 7th requires ADR-0009 amendment + `/propagate-design-change` against unit-role.md (CR-2) + damage-calc.md (P_mult factor addition if applicable) + AI ADR (decision-tree consumer)
- Required (direct, ADR-0009 §4 cross-doc consistency): CI lint MUST verify `unit_roles.json` `passive_tag` field per class matches the const PASSIVE_TAG_BY_CLASS value per class — drift between JSON documentation and const runtime is a defect
- Forbidden (direct, ADR-0009 §7 + ADR-0012 EC-DC-25): `Array[String]` consumer assemblies — silent runtime mismatch with `&"passive_charge"` StringName comparison
- Forbidden (direct, ADR-0009 §7): hardcoding the 6 tags inline at consumer sites; consumers MUST reference `UnitRole.PASSIVE_TAG_BY_CLASS[UnitRole.UnitClass.CAVALRY]` for the canonical mapping
- Guardrail (direct, ADR-0009 §Performance): `PASSIVE_TAG_BY_CLASS` is a `const` Dictionary — zero runtime cost (parse-time initialized; bracket-index read is O(1))

---

## Acceptance Criteria

*From GDD `design/gdd/unit-role.md` AC-6..AC-11 (tag layer only — passive activation gates owned by consumers per ADR-0009 §7) + GDD §CR-2:*

- [ ] `const PASSIVE_TAG_BY_CLASS: Dictionary` declared in `src/foundation/unit_role.gd` at class body level (parse-time literal — NOT a `static var`)
- [ ] All 6 StringName values exactly match GDD §CR-2 + ADR-0009 §7:
  - CAVALRY → `&"passive_charge"`
  - INFANTRY → `&"passive_shield_wall"`
  - ARCHER → `&"passive_high_ground_shot"`
  - STRATEGIST → `&"passive_tactical_read"`
  - COMMANDER → `&"passive_rally"`
  - SCOUT → `&"passive_ambush"`
- [ ] All 6 keys use the `UnitClass` enum int values (`UnitClass.CAVALRY` etc., resolving to 0..5)
- [ ] `UnitRole.PASSIVE_TAG_BY_CLASS[UnitRole.UnitClass.CAVALRY]` returns `&"passive_charge"` (cross-script consumer access)
- [ ] `unit_roles.json` `passive_tag` field per class matches the const Dictionary value per class (CI lint verification: parse JSON + assert per-class string == String(const PASSIVE_TAG_BY_CLASS value))
- [ ] StringName interning verified: `UnitRole.PASSIVE_TAG_BY_CLASS[UnitClass.CAVALRY] == &"passive_charge"` returns `true` (process-global interning per godot-specialist Item 7)
- [ ] Sample `Array[StringName]` consumer pattern documented + tested: `var passive_set: Array[StringName] = [UnitRole.PASSIVE_TAG_BY_CLASS[UnitClass.CAVALRY], UnitRole.PASSIVE_TAG_BY_CLASS[UnitClass.SCOUT]]` typed-array assignment succeeds; `&"passive_charge" in passive_set` returns true
- [ ] **AC-6..AC-11 (passive activation gates)**: Activation logic (e.g., Charge requires `accumulated_move_cost >= 40`; Ambush requires `target.acted_this_turn == false`) is **OUT OF SCOPE** — owned by consumers per ADR-0009 §7. UnitRole only owns the canonical tag set. This story only verifies the tags are accessible, NOT that activation conditions trigger correctly

---

## Implementation Notes

*From ADR-0009 §3, §7, ADR-0012 forbidden_pattern damage_calc_dictionary_payload precedent:*

1. Const declaration shape (inside class body, NOT inside any method):
   ```gdscript
   const PASSIVE_TAG_BY_CLASS: Dictionary = {
       UnitClass.CAVALRY:    &"passive_charge",
       UnitClass.INFANTRY:   &"passive_shield_wall",
       UnitClass.ARCHER:     &"passive_high_ground_shot",
       UnitClass.STRATEGIST: &"passive_tactical_read",
       UnitClass.COMMANDER:  &"passive_rally",
       UnitClass.SCOUT:      &"passive_ambush",
   }
   ```
2. Const Dictionary in GDScript 4.x is parse-time initialized with literal values. The keys are evaluated as enum int values (CAVALRY=0, etc.); the values are interned StringName literals. Both are stable parse-time references.
3. The `Dictionary` type annotation is unparameterized — Godot 4.x does NOT support parameterized `const Dictionary[K, V]` (per godot-specialist `/architecture-review` 2026-04-28 Item 3 confirmation). Adding `Dictionary[int, StringName]` would be a parse error in 4.6.
4. Sample consumer pattern (e.g., AI / Damage Calc would do this — illustrative, NOT in this story's scope):
   ```gdscript
   # Consumer-side, NOT this story:
   var attacker_passive: StringName = UnitRole.PASSIVE_TAG_BY_CLASS[attacker.unit_class]
   var attacker_passives: Array[StringName] = [attacker_passive]  # typed Array[StringName]
   if &"passive_charge" in attacker_passives:
       # Charge activation logic (consumer-side; NOT in UnitRole)
   ```
5. CI lint verification (cross-doc consistency between JSON and const):
   ```python
   # tools/ci/verify_passive_tag_consistency.py (illustrative)
   import json
   data = json.load(open("assets/data/config/unit_roles.json"))
   expected = {
       "cavalry": "passive_charge",
       "infantry": "passive_shield_wall",
       "archer": "passive_high_ground_shot",
       "strategist": "passive_tactical_read",
       "commander": "passive_rally",
       "scout": "passive_ambush",
   }
   for class_key, expected_tag in expected.items():
       assert data[class_key]["passive_tag"] == expected_tag, f"{class_key} drift: {data[class_key]['passive_tag']} != {expected_tag}"
   ```
   The CI lint can be a Python script, a Godot test, or a shell grep — choice deferred to story implementation.
6. **Do not** define passive activation logic (CR-2 effects like "+20% bonus damage" or "5 flat reduction") in UnitRole — those are owned by consumers (Damage Calc owns Charge/Shield Wall/Ambush effect application; HP/Status owns Shield Wall flat reduction; Turn Order owns Ambush turn gate; Formation Bonus owns Rally aura). UnitRole owns ONLY the tag set + the activation gate **definitions** in GDD prose, not the runtime logic.
7. **Do not** add a getter method (e.g., `static func get_passive_tag(unit_class) -> StringName`) — direct const Dictionary access is more idiomatic + faster + simpler. ADR-0009 §3 explicitly lists the const as the access form.

---

## Out of Scope

*Handled by neighbouring stories or downstream consumer epics:*

- Stories 001-005 + 007-010: other UnitRole concerns (skeleton, JSON loader, formulas, cost table, direction mult, balance append, integrations, perf)
- Damage Calc Charge/Shield Wall/Ambush effect application per CR-2 (owned by ADR-0012 — already locked)
- HP/Status Shield Wall flat reduction per EC-11 (owned by future ADR-0010)
- Turn Order Ambush turn gate per EC-8 + EC-9 (owned by future ADR-0011)
- Formation Bonus Rally aura per EC-12 + grid-battle.md CR-15 (owned by future Formation Bonus ADR)
- AI passive-tag decision-tree consumer (owned by future AI ADR)
- Battle HUD passive icon display (owned by Battle HUD epic)

---

## QA Test Cases

*Logic story — automated unit test specs.*

- **AC-1 (Const Dictionary correctness — 6 entries)**:
  - Given: `src/foundation/unit_role.gd` is loaded
  - When: a test reads `UnitRole.PASSIVE_TAG_BY_CLASS`
  - Then: returns a Dictionary with exactly 6 entries; keys are `[0, 1, 2, 3, 4, 5]` (UnitClass enum int values); values are 6 StringName literals matching ADR-0009 §7
  - Edge cases: `PASSIVE_TAG_BY_CLASS.size() == 6`; missing key access returns `null` (Dictionary default behavior)

- **AC-2 (Per-class StringName values exact match)**:
  - Given: `UnitRole.PASSIVE_TAG_BY_CLASS` is loaded
  - When: per-class lookups: `[UnitClass.CAVALRY]`, `[UnitClass.INFANTRY]`, `[UnitClass.ARCHER]`, `[UnitClass.STRATEGIST]`, `[UnitClass.COMMANDER]`, `[UnitClass.SCOUT]`
  - Then: returns `&"passive_charge"`, `&"passive_shield_wall"`, `&"passive_high_ground_shot"`, `&"passive_tactical_read"`, `&"passive_rally"`, `&"passive_ambush"` respectively
  - Edge cases: typo in any tag name → CI test fails immediately (locked tag set per ADR-0009 §7)

- **AC-3 (StringName interning — process-global identity)**:
  - Given: `UnitRole.PASSIVE_TAG_BY_CLASS[UnitClass.CAVALRY]` returns `&"passive_charge"`
  - When: test compares with a freshly-typed `&"passive_charge"` literal
  - Then: `UnitRole.PASSIVE_TAG_BY_CLASS[UnitClass.CAVALRY] == &"passive_charge"` returns `true`; identity comparison via `is_same(a, b)` (if applicable) also true
  - Edge cases: comparison with `String("passive_charge")` (non-StringName) — Godot 4.x `StringName == String` returns true (per G-20 in project gotchas); structural typed-array boundary (`Array[StringName]` typing) is the correct enforcement layer, NOT the `==` operator alone

- **AC-4 (Array[StringName] consumer pattern)**:
  - Given: typed-array consumer pattern per ADR-0012 forbidden_pattern `damage_calc_dictionary_payload` precedent
  - When: test constructs `var passives: Array[StringName] = [UnitRole.PASSIVE_TAG_BY_CLASS[UnitClass.CAVALRY], UnitRole.PASSIVE_TAG_BY_CLASS[UnitClass.SCOUT]]`
  - Then: typed-array assignment succeeds (no runtime type error); `&"passive_charge" in passives` returns `true`; `&"passive_shield_wall" in passives` returns `false`
  - Edge cases: assigning an `Array[String]` element triggers runtime type rejection at insert/parameter-bind time per ADR-0012 §2 nuance (runtime, not parse-time enforcement)

- **AC-5 (JSON-vs-const drift CI lint)**:
  - Given: `assets/data/config/unit_roles.json` is shipped with `passive_tag` field per class
  - When: CI lint script (Python, Godot test, or shell grep) compares per-class JSON `passive_tag` String value to const PASSIVE_TAG_BY_CLASS value
  - Then: zero mismatches; per-class strings match (cavalry=passive_charge, infantry=passive_shield_wall, etc.)
  - Edge cases: future JSON edit changes `passive_tag` value → CI lint fails immediately; future const edit changes the StringName value → same CI failure (forces simultaneous updates)

- **AC-6 (Activation logic OUT OF SCOPE — verify by absence)**:
  - Given: `src/foundation/unit_role.gd` is written
  - When: a CI lint step greps for activation predicates (e.g., "accumulated_move_cost", "acted_this_turn", "delta_elevation")
  - Then: zero matches in `unit_role.gd` (activation logic is consumer-side per ADR-0009 §7)
  - Edge cases: false-positive on doc-comments referencing GDD CR-2 prose — exclude `# ` prefixed lines from grep

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/foundation/unit_role_passive_tags_test.gd` — must exist and pass (6 ACs above; ~80-120 LoC test file with 6-entry coverage + interning verification + Array[StringName] typed-array consumer pattern); CI lint script for AC-5 cross-doc consistency
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (needs `UnitClass` enum)
- Unlocks: Damage Calc consumer integration (already exists per ADR-0012); future AI ADR consumer; Battle HUD passive icon display
