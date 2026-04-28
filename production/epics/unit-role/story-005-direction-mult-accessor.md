# Story 005: get_class_direction_mult + 6×3 table read from unit_roles.json

> **Epic**: unit-role
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 2 hours (S)

## Context

**GDD**: `design/gdd/unit-role.md`
**Requirement**: `TR-unit-role-007`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 — Unit Role System (§6 Class Direction Multiplier Ratification + §GDD Requirements Addressed AC-16/AC-17)
**ADR Decision Summary**: `get_class_direction_mult(unit_class, direction) -> float` is a single bracket-index lookup into the 6×3 `CLASS_DIRECTION_MULT` table loaded from `unit_roles.json` (per-class `class_direction_mult` array) — **NOT** read via `BalanceConstants.get_const("CLASS_DIRECTION_MULT")`. The `entities.yaml` `CLASS_DIRECTION_MULT` registration is a **design-side** registry entry tracking cross-system referenced_by; the runtime read goes through `unit_roles.json` for consistency with per-class config locality. Damage Calc consumes via UnitRole's accessor, NOT via `BalanceConstants`.

**Engine**: Godot 4.6 | **Risk**: LOW (typed `int` parameter for `direction` matches ADR-0004 §5b ATK_DIR constants; bracket-index lookup on Array stable; float return stable)
**Engine Notes**: `direction: int` parameter accepts ADR-0004 §5b `ATK_DIR_FRONT=0 / FLANK=1 / REAR=2` constants returned by `MapGrid.get_attack_direction(...)`. The int-vs-StringName encoding asymmetry (ADR-0004 returns int; ADR-0012 internally uses StringName for `ResolveModifiers.direction_rel`) is bridged by Grid Battle (per `architecture-review-2026-04-26.md` ADV-1 — implicit Grid Battle responsibility, future Grid Battle ADR will lock). UnitRole stays int-side at the boundary.

**Control Manifest Rules (Foundation layer + direct ADR cites)**:
- Required (direct, ADR-0009 §6): `get_class_direction_mult(unit_class: UnitRole.UnitClass, direction: int) -> float` reads from `_coefficients[class_key]["class_direction_mult"][direction]` populated by Story 002 from `unit_roles.json`
- Required (direct, ADR-0009 §6 asymmetry documentation): runtime read goes through `unit_roles.json`, **NOT** `BalanceConstants.get_const("CLASS_DIRECTION_MULT")`. The entities.yaml registration is design-side cross-system tracking only
- Required (direct, ADR-0012 §F-DC-3): values consumed by Damage Calc via this accessor; ADR-0012 ratifies the 6×3 shape (corrected from stale `[4][3]` reference per `/architecture-review` 2026-04-28 same-patch amendment)
- Required (direct, ADR-0009 §6 ratification chain): the 6×3 values are LOCKED per `unit-role.md` §CR-6a + §EC-7 + `entities.yaml` registration. Any change requires `/propagate-design-change` against unit-role.md + damage-calc.md + entities.yaml + unit_roles.json + ADR-0009 §6 in a single patch
- Forbidden (direct, ADR-0009 §6): reading `CLASS_DIRECTION_MULT` via `BalanceConstants.get_const(...)` — would short-circuit the per-class data locality + introduce sync risk between unit_roles.json runtime and entities.yaml design-side registration
- Forbidden (direct, ADR-0009 §6 + GDD CR-6a rev 2.8): hardcoded direction multiplier values in `src/foundation/unit_role.gd` matching the table values (1.09, 1.375, etc.) — values come from `_coefficients` cache only
- Guardrail (direct, ADR-0009 §Performance): `get_class_direction_mult` <0.01ms per call (called once per Damage Calc `resolve()` invocation; <100 calls per battle)

---

## Acceptance Criteria

*From GDD `design/gdd/unit-role.md` AC-16, AC-17 + EC-7:*

- [ ] **AC-16 (Direction multiplier table — Cavalry REAR + Charge composition)**: `get_class_direction_mult(CAVALRY, REAR=2) == 1.09` (rev 2.8 Rally-ceiling-fix value, was 1.20). Combined with base REAR ×1.5 + CHARGE_BONUS=1.20 → multiplicative product ≈ 1.97 per EC-7 (Damage Calc owns the multiplicative composition; this story verifies the per-cell value)
- [ ] **AC-17 (Scout REAR + Ambush composition)**: `get_class_direction_mult(SCOUT, REAR=2) == 1.1`. Combined with base REAR ×1.5 + AMBUSH_BONUS=1.15 → 1.5 × 1.1 × 1.15 = 1.897 per CR-6b (Damage Calc owns composition)
- [ ] All 18 cells of the 6×3 table verified (per ADR-0009 §6 + GDD §CR-6a):
  - CAVALRY: `[1.0, 1.1, 1.09]` (FRONT, FLANK, REAR)
  - INFANTRY: `[0.9, 1.0, 1.1]`
  - ARCHER: `[1.0, 1.375, 0.9]` — ARCHER FLANK is the largest class-mod bonus per GDD §CR-6a + damage-calc rev 2.6 BLK-7-9/10 ratification
  - STRATEGIST: `[1.0, 1.0, 1.0]` (no-op row by design — class identity expressed via Tactical Read evasion bypass)
  - COMMANDER: `[1.0, 1.0, 1.0]` (no-op row by design — class identity expressed via Rally adjacency aura)
  - SCOUT: `[1.0, 1.0, 1.1]`
- [ ] Runtime read goes through `unit_roles.json` (verified by mutating test fixture `unit_roles.json` cavalry `class_direction_mult[2]` to a sentinel value, re-init `_coefficients_loaded = false`, re-fetch — assert sentinel returned, NOT 1.09 from entities.yaml)
- [ ] Reading via `BalanceConstants.get_const("CLASS_DIRECTION_MULT")` is NOT performed in `get_class_direction_mult` body (verified via grep on the method body source)

---

## Implementation Notes

*From ADR-0009 §6, §Migration Plan §From locked direction multipliers, GDD §CR-6a + §EC-7:*

1. Method body shape:
   ```gdscript
   static func get_class_direction_mult(
       unit_class: UnitRole.UnitClass,
       direction: int  # ATK_DIR_FRONT=0 / FLANK=1 / REAR=2 per ADR-0004 §5b
   ) -> float:
       _load_coefficients()
       var class_key := _class_to_key(unit_class)
       var direction_array: Array = _coefficients[class_key]["class_direction_mult"]
       return direction_array[direction]
   ```
2. The `direction` parameter is `int` (matches ADR-0004 §5b `ATK_DIR_FRONT/FLANK/REAR` int constants returned by `MapGrid.get_attack_direction`). The int↔StringName encoding asymmetry between Map/Grid (int) and Damage Calc internal (StringName per `ResolveModifiers.direction_rel`) is Grid Battle's bridging responsibility (ADV-1 from `architecture-review-2026-04-26.md`); UnitRole stays int-side.
3. Direction array indexing must match ADR-0009 §6 table: index 0=FRONT, 1=FLANK, 2=REAR. JSON shape per Story 002: `"class_direction_mult": [1.0, 1.1, 1.09]` for CAVALRY (FRONT, FLANK, REAR).
4. **Do not** apply `snappedf(value, 0.01)` here — that's Damage Calc's responsibility per ADR-0012 §F-DC-3. UnitRole returns the raw float from the JSON.
5. **Do not** read via `BalanceConstants.get_const("CLASS_DIRECTION_MULT")` — the design-vs-runtime asymmetry is intentional per ADR-0009 §6 (per-class data locality in `unit_roles.json`).
6. **Do not** add bounds-checking on `direction` (caller responsibility — Map/Grid `get_attack_direction` returns int in [0, 2]). Out-of-range direction triggers an array out-of-bounds runtime error which is caught by ADR-0012's invariant_violation flag pattern at the Damage Calc consumer, NOT here.
7. **Do not** add bounds-checking on `unit_class` (typed enum parameter binding catches invalid values at call site per godot-specialist Item 2).

---

## Out of Scope

*Handled by neighbouring stories:*

- Story 003: F-1..F-5 stat-derivation methods (DEF/HP/Init are NOT direction multipliers; separate concern)
- Story 004: `get_class_cost_table` (similar shape but cost matrix is separate concern)
- Story 009: Damage Calc integration test verifying the F-DC-3 cross-system contract — apex Cavalry REAR + Charge → D_mult=1.64 per rev 2.8
- `snappedf(value, 0.01)` D_mult composition (ADR-0012 §F-DC-3 — Damage Calc owns)
- `CHARGE_BONUS=1.20` and `AMBUSH_BONUS=1.15` constants (ADR-0012 §6 + entities.yaml — Damage Calc owns the multiplier values; UnitRole owns only the activation gates per CR-2)
- Multiplicative ordering enforcement (EC-7 ratified by ADR-0012 §F-DC-5 + F-DC-6 — Damage Calc owns)

---

## QA Test Cases

*Logic story — automated unit test specs.*

- **AC-1 (6×3 = 18 cells correctness)**:
  - Given: `_coefficients_loaded` reset in `before_test`; valid `unit_roles.json` per Story 002
  - When: `UnitRole.get_class_direction_mult(unit_class, direction)` is called for each of 6 classes × 3 directions
  - Then: every cell matches GDD §CR-6a rev 2.8 values exactly:
    - CAVALRY: FRONT=1.0, FLANK=1.1, REAR=1.09
    - INFANTRY: FRONT=0.9, FLANK=1.0, REAR=1.1
    - ARCHER: FRONT=1.0, FLANK=1.375, REAR=0.9
    - STRATEGIST: all 1.0 (no-op row)
    - COMMANDER: all 1.0 (no-op row)
    - SCOUT: FRONT=1.0, FLANK=1.0, REAR=1.1
  - Edge cases: floating-point precision — use `assert_float(...).is_equal_approx(expected, 0.001)` for comparison; verify ARCHER FLANK precisely 1.375 (not 1.38 or 1.37 — locked rev 2.6 value)

- **AC-2 (AC-16 Cavalry REAR rev 2.8 value)**:
  - Given: ADR-0009 §6 ratifies Cavalry REAR=1.09 (rev 2.8 Rally-ceiling-fix value, was 1.20 pre-fix)
  - When: `UnitRole.get_class_direction_mult(CAVALRY, 2)` is called
  - Then: returns exactly 1.09 (not 1.20)
  - Edge cases: any future regression to 1.20 → CI test fails immediately; this is the load-bearing rev 2.8 value preventing DAMAGE_CEILING activation per damage-calc.md ninth-pass desync audit BLK-G-2

- **AC-3 (AC-17 Scout REAR + Ambush composition baseline)**:
  - Given: `UnitRole.get_class_direction_mult(SCOUT, 2)` returns 1.1
  - When: combined with base REAR ×1.5 + AMBUSH_BONUS=1.15 (Damage Calc applies)
  - Then: per CR-6b, the multiplicative product is 1.5 × 1.1 × 1.15 = 1.897 (Damage Calc owns the composition; this story verifies UnitRole returns 1.1 as the per-cell value)
  - Edge cases: integration test for the full composition is in Story 009, NOT here

- **AC-4 (Runtime read source — unit_roles.json, NOT entities.yaml)**:
  - Given: a test fixture replaces `unit_roles.json` cavalry `class_direction_mult[2]` with sentinel value 9.99
  - When: test calls `UnitRole._coefficients_loaded = false` (reset cache); `UnitRole.get_class_direction_mult(CAVALRY, 2)`
  - Then: returns 9.99 (the sentinel from JSON), proving the runtime read source is `unit_roles.json` and NOT `entities.yaml` `BalanceConstants.get_const("CLASS_DIRECTION_MULT")`
  - Edge cases: cleanup — restore `unit_roles.json` original value in `after_test`

- **AC-5 (No BalanceConstants read in method body)**:
  - Given: `src/foundation/unit_role.gd` is written
  - When: a CI lint step greps for the BalanceConstants accessor in the `get_class_direction_mult` method body
  - Then: `grep -A 10 "func get_class_direction_mult" src/foundation/unit_role.gd | grep "BalanceConstants"` returns zero matches
  - Edge cases: future refactor that adds a BalanceConstants read here → CI lint fails (per ADR-0009 §6 design-vs-runtime asymmetry contract)

- **AC-6 (STRATEGIST + COMMANDER no-op rows)**:
  - Given: ADR-0009 §6 enumerates STRATEGIST + COMMANDER as all-1.0 no-op rows by design
  - When: `UnitRole.get_class_direction_mult(STRATEGIST, dir)` and `UnitRole.get_class_direction_mult(COMMANDER, dir)` for dir ∈ {0, 1, 2}
  - Then: all 6 calls return 1.0 (Strategist class identity = Tactical Read evasion bypass; Commander class identity = Rally adjacency aura — neither uses direction-based damage scaling)
  - Edge cases: future amendment to give STRATEGIST or COMMANDER non-trivial direction values → requires `/propagate-design-change` per ADR-0009 §6 amendment process

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/foundation/unit_role_direction_mult_test.gd` — must exist and pass (6 ACs above; ~120-180 LoC test file with 18-cell coverage + AC-16/AC-17 baselines + JSON-source verification + G-15 reset in `before_test`)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 002 (needs `_coefficients` cache populated by `_load_coefficients`)
- Unlocks: Story 009 (Damage Calc integration test consumes this accessor); Damage Calc resolve() consumer (in damage-calc epic; this story makes the cross-system contract real)
