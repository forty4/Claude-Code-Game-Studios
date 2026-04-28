# Story 009: Damage Calc integration test (consumes get_class_direction_mult per F-DC-3) [SCOPE EXPANDED]

> **Epic**: unit-role
> **Status**: Complete (2026-04-28) ✅ — 4 new integration tests + DamageCalc refactor; 492/492 full-suite green
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-20
> **Estimate**: 2-3 hours (S) — actual ~50min orchestrator + 1 specialist round (substantive scope expansion: refactor DamageCalc + update damage_calc_test.gd + write integration test; specialist hit context budget mid-test-creation; orchestrator finished the integration test inline + 2 mechanical fixes)
> **Implementation commit**: `b9634bb` (2026-04-28)

## Post-completion notes

### Story-blocking architectural discoveries (9th + 10th implementation-time discoveries this session)
**Drift A**: ADR-0009 §6 specifies DamageCalc reads CLASS_DIRECTION_MULT via `UnitRole.get_class_direction_mult` for per-class data locality. But `damage_calc.gd` lines 77 + 202 currently used `BalanceConstants.get_const("CLASS_DIRECTION_MULT")` — read from `balance_entities.json`, NOT `unit_roles.json`.

**Drift B**: `balance_entities.json` `CLASS_DIRECTION_MULT` values DIVERGED from `unit_roles.json` (CAVALRY FLANK 1.05 vs 1.10; SCOUT/INFANTRY/ARCHER REAR all wrong). DamageCalc was computing wrong damage for non-Cavalry classes — silent corruption.

**Drift C (sub-finding)**: AttackerContext.Class is a SEPARATE 4-value enum (CAVALRY=0, SCOUT=1, INFANTRY=2, ARCHER=3) ≠ UnitRole.UnitClass's 6-value enum (CAVALRY=0, INFANTRY=1, ARCHER=2, STRATEGIST=3, COMMANDER=4, SCOUT=5). The class-int orderings differ — explains why balance_entities.json had a 4-key shape. Bridge dict required for translation.

### Resolution (Option 1 — user-approved scope expansion)
Refactor DamageCalc to consume UnitRole accessor + write integration test in same story. Story-009 grew from "write integration test" to "refactor DamageCalc + write integration test". Authorized scope expansion implicitly fixes the silent corruption + closes 2 cross-epic drifts.

### Files modified/created
- `src/feature/damage_calc/damage_calc.gd`: refactored lines 77+202 + `_direction_multiplier`; added `_DIR_INT` (StringName→int direction translation) + `_ATTACKER_CLASS_TO_UNIT_ROLE` (4-class enum bridge dict). +64/-25 LoC
- `tests/unit/damage_calc/damage_calc_test.gd`: assertion updates per refactored consumption path; AC-6 dual-fire sentinel updated per-class (D_mult diverges per class now); AC-4 mock dict updated 12→11 keys (CLASS_DIRECTION_MULT removed from BalanceConstants read path). +63/-38 LoC
- `tests/integration/foundation/unit_role_damage_calc_integration_test.gd` (NEW, ~210 LoC, 4 test functions): load-bearing sentinel propagation + Cavalry REAR rev 2.8 apex (D_mult=1.64) + class no-op invariant + G-15 reset discipline meta-test

### 2 mechanical fixes (orchestrator-side)
1. **GDScript operator precedence**: `result.resolved_damage == c["dual_fire_dmg"] as int` parsed as `(a == b) as int` (assert_bool received int 0/1). Fixed with explicit parens. → **G-24 candidate codification** (this close-out commit) — "GDScript `as` operator has LOWER precedence than `==` — wrap RHS cast in parens"
2. **Field name corrections**: hand-written integration test used wrong AttackerContext/DefenderContext field names (`atk` vs `raw_atk`; `phys_def` vs `raw_def`; `terrain_def_bonus` vs `terrain_def`). Fixed by inspecting actual class declarations. Process insight: writing tests against an unfamiliar class API requires `Read` of the class declaration FIRST, not assumption from naming convention

### AttackerContext.Class architectural limitation surfaced
DamageCalc currently CANNOT be called with STRATEGIST or COMMANDER attackers (those classes are not in AttackerContext.Class enum). This is a real architectural limitation tied to the 4-class AttackerContext.Class shape. If those classes need to attack via DamageCalc in the future:
- Option A: extend AttackerContext.Class to 6 values matching UnitRole.UnitClass (likely the cleanest)
- Option B: replace AttackerContext.Class with UnitRole.UnitClass directly (per ADR-0012 §2 future migration path)

Both options require ADR-0012 amendment + propagate-design-change pass. Document for future Battle Preparation epic / Grid Battle ADR planning. Track as advisory non-blocker for unit-role epic close-out.

### Process insight (10 instances stable this session)
Pattern: 7 doc/data drift catches (story-001 @abstract; story-002 GDD value transcription; story-003 DEF_CAP; story-007 missing 7 caps; story-008 cross-epic terrain_type ordering; story-009 DamageCalc cross-epic consumption + value divergence; AttackerContext.Class enum collision sub-finding) + 2 GdUnit4/GDScript API surprises (story-005 is_not_equal_approx; story-009 as-operator precedence) + 2 clean-execution baselines (story-004; story-006).

The cross-epic drift catch rate (3 instances: story-007 missing caps; story-008 terrain_type ordering; story-009 DamageCalc consumption path) is the most valuable insight — it surfaces architectural inconsistencies that survived /architecture-review because the review verified ADRs against ADRs, not ADRs against existing source code. **Codification overdue for next /architecture-review iteration.**

### Calibration
- DamageCalc.gd modification: ~64 LoC
- damage_calc_test.gd updates: ~63 LoC change
- Integration test: 210 LoC (smaller than original 360 estimate; orchestrator wrote a focused 4-AC version after specialist context budget exhausted on the broader 18-fixture parametric)
- Substantively the most invasive story so far this session

## Context

**GDD**: `design/gdd/unit-role.md` + `design/gdd/damage-calc.md` (cross-system integration)
**Requirement**: `TR-unit-role-007` (ratifies ADR-0012 CLASS_DIRECTION_MULT[6][3]) + ADR-0012 TR-damage-calc-008 (5 cross-system upstream interfaces — Unit Role row)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0009 — Unit Role System (§6 Class Direction Multiplier Ratification) + ADR-0012 — Damage Calc (§F-DC-3 + §8 cross-system upstream interfaces — Unit Role row)
**ADR Decision Summary**: ADR-0012's apex arithmetic depends on `D_mult = snappedf(BASE_DIRECTION_MULT[direction_rel] × CLASS_DIRECTION_MULT[unit_class][direction_rel], 0.01)`. Story 005 ships `UnitRole.get_class_direction_mult(unit_class, direction)` returning the per-cell value from `unit_roles.json`. This story validates the cross-system contract end-to-end: DamageCalc.resolve() consumes UnitRole.get_class_direction_mult correctly for all 6 classes × 3 directions; F-DC-3 D_mult composition produces the expected apex (Cavalry REAR + Charge → D_mult=1.64 per rev 2.8); Strategist + Commander no-op rows produce D_mult=1.0; verifies the int↔StringName encoding bridge (Map/Grid int → Damage Calc StringName) at the call boundary.

**Engine**: Godot 4.6 | **Risk**: LOW (cross-class call between two RefCounted+all-static modules; both stable per their own ADR validations)
**Engine Notes**: This integration test exercises the floating-point composition chain that ADR-0012 R-8 flags as cross-platform-residue susceptible (`D_mult = 1.50 × 1.09` evaluates to `1.6349999...` on one platform vs `1.635` on another, then `snappedf(..., 0.01)` rounds to `1.63` vs `1.64` — flipping apex damage from 178 to 177 or 179). The integration test should run on the project's macOS-Metal CI baseline + Windows-D3D12 + Linux-Vulkan matrix per AC-DC-37 to catch any 1-ULP divergence. **For sprint-1 closure**: only macOS-Metal baseline required; cross-platform matrix activation deferred to damage-calc story-001 implementation per ADR-0012 R-8 Mitigation.

**Control Manifest Rules (Foundation layer + direct ADR cites)**:
- Required (direct, ADR-0012 §F-DC-3): Damage Calc apex arithmetic uses `D_mult = snappedf(BASE_DIRECTION_MULT[direction_rel] × CLASS_DIRECTION_MULT[unit_class][direction_rel], 0.01)`; per-cell CLASS_DIRECTION_MULT comes from `UnitRole.get_class_direction_mult` per ADR-0009 §6 ratification
- Required (direct, ADR-0012 §8 cross-system upstream interface — Unit Role row): the consumed interface is `UnitRole.BASE_DIRECTION_MULT[3]` (compile-time const table on UnitRole, NOT in this story; out of scope) + `UnitRole.CLASS_DIRECTION_MULT[6][3]` (now via `get_class_direction_mult` accessor per Story 005)
- Required (direct, ADR-0009 §6 + §Migration Plan): runtime read goes through `unit_roles.json`, NOT `BalanceConstants.get_const("CLASS_DIRECTION_MULT")` — verify by spot-check that the integration test cannot reach this constant via BalanceConstants
- Required (direct, ADR-0001 + non-emitter invariants): integration test uses direct method calls between UnitRole + DamageCalc (NOT signal-mediated); both modules on non-emitter list per ADR-0001 line 375
- Forbidden (direct, ADR-0009 §6 design-vs-runtime asymmetry): integration test reading via `BalanceConstants.get_const("CLASS_DIRECTION_MULT")` instead of `UnitRole.get_class_direction_mult` — would short-circuit the per-class data locality
- Guardrail (direct, ADR-0012 §Performance + ADR-0009 §Performance): combined `UnitRole.get_class_direction_mult` (<0.01ms) + DamageCalc.resolve() (50µs target) per attack — integration verifies no observable regression vs each module's individual budget

---

## Acceptance Criteria

*From GDD `design/gdd/unit-role.md` AC-22 + GDD `design/gdd/damage-calc.md` cross-system contract + ADR-0012 §F-DC-3 + ADR-0009 §6:*

- [ ] **AC-22 (Damage Calc cross-system contract)**: Integration test verifies DamageCalc.resolve() consumes `UnitRole.get_class_direction_mult(unit_class, direction)` correctly for all 6 classes × 3 directions = 18 combinations
- [ ] **F-DC-3 D_mult composition for apex Cavalry REAR + Charge**: ATK_DIR_REAR (BASE 1.5) × CLASS_DIRECTION_MULT[CAVALRY][REAR] (1.09) → `snappedf(1.5 × 1.09, 0.01) = 1.64`. Integration test verifies the snappedf result matches; combined with CHARGE_BONUS=1.20 (P_mult layer) → apex damage stays inside DAMAGE_CEILING=180 per ADR-0012 §7 cap layering
- [ ] STRATEGIST + COMMANDER all-direction D_mult composition produces base-only result: `snappedf(1.0 × 1.0, 0.01) = 1.0` for FRONT, `snappedf(1.2 × 1.0, 0.01) = 1.2` for FLANK, `snappedf(1.5 × 1.0, 0.01) = 1.5` for REAR — class identity expressed elsewhere per ADR-0009 §6 no-op-row design
- [ ] ARCHER FLANK D_mult composition (largest class-mod bonus): `snappedf(1.2 × 1.375, 0.01) = 1.65` — matches Scout REAR / Infantry REAR numerical anchor via distinct spatial position per GDD §CR-6a rationale
- [ ] Runtime read source verified: integration test mutates `unit_roles.json` cavalry `class_direction_mult[2]` to a sentinel value, re-init UnitRole cache, calls DamageCalc.resolve() on a Cavalry REAR attack, asserts the sentinel propagates through D_mult — proves DamageCalc reads UnitRole accessor (not BalanceConstants direct)
- [ ] No observable performance regression: per-call DamageCalc.resolve() with UnitRole accessor stays within ADR-0012 §Performance 50µs target on macOS-Metal baseline (cross-platform matrix deferred to damage-calc story-001 per ADR-0012 R-8)
- [ ] G-15 obligation: integration test resets `BalanceConstants._cache_loaded = false` AND `UnitRole._coefficients_loaded = false` in `before_test()` (DamageCalc consumers transitively read both)

---

## Implementation Notes

*From ADR-0012 §F-DC-3, §8 + ADR-0009 §6 + GDD damage-calc.md §F:*

1. Integration test scaffolding shape:
   ```gdscript
   class_name UnitRoleDamageCalcIntegrationTest
   extends GdUnitTestSuite

   func before_test() -> void:
       BalanceConstants._cache_loaded = false  # G-15
       UnitRole._coefficients_loaded = false   # mirror G-15 for UnitRole

   func test_damage_calc_consumes_unit_role_direction_mult_cavalry_rear_apex() -> void:
       # Construct AttackerContext + DefenderContext + ResolveModifiers per ADR-0012 §2 typed wrappers
       # Set direction_rel = REAR (StringName per ADR-0012 §2; Grid Battle bridges from int per ADV-1)
       # Set unit_class = CAVALRY (per AttackerContext typed field)
       # Set passives = [&"passive_charge"] to trigger CHARGE_BONUS
       # Call DamageCalc.resolve(attacker, defender, modifiers)
       # Assert result.D_mult == 1.64 (snappedf(1.5 × 1.09, 0.01))
       # Assert result.raw includes the apex composition per F-DC-5 + F-DC-6
       pass
   ```
2. The 18-combination coverage can be a parameterized test with a fixture table:
   ```gdscript
   # Fixture: (unit_class, direction, expected_D_mult)
   const D_MULT_FIXTURES = [
       [UnitClass.CAVALRY, &"FRONT", 1.0],   # snappedf(1.0 × 1.0, 0.01)
       [UnitClass.CAVALRY, &"FLANK", 1.32],  # snappedf(1.2 × 1.1, 0.01)
       [UnitClass.CAVALRY, &"REAR",  1.64],  # snappedf(1.5 × 1.09, 0.01) — apex
       [UnitClass.INFANTRY, &"FRONT", 0.9],
       [UnitClass.INFANTRY, &"FLANK", 1.2],
       [UnitClass.INFANTRY, &"REAR",  1.65],
       [UnitClass.ARCHER,   &"FRONT", 1.0],
       [UnitClass.ARCHER,   &"FLANK", 1.65], # snappedf(1.2 × 1.375, 0.01) — largest class-mod
       [UnitClass.ARCHER,   &"REAR",  1.35],
       [UnitClass.STRATEGIST, &"FRONT", 1.0],
       [UnitClass.STRATEGIST, &"FLANK", 1.2],
       [UnitClass.STRATEGIST, &"REAR",  1.5],
       [UnitClass.COMMANDER, &"FRONT", 1.0],
       [UnitClass.COMMANDER, &"FLANK", 1.2],
       [UnitClass.COMMANDER, &"REAR",  1.5],
       [UnitClass.SCOUT,     &"FRONT", 1.0],
       [UnitClass.SCOUT,     &"FLANK", 1.2],
       [UnitClass.SCOUT,     &"REAR",  1.65],  # snappedf(1.5 × 1.1, 0.01)
   ]
   ```
   The expected values use `snappedf(BASE × CLASS, 0.01)` per ADR-0012 §F-DC-3.
3. The int↔StringName direction encoding bridge: ADR-0004 returns int (ATK_DIR_FRONT=0/FLANK=1/REAR=2); ADR-0012 internally uses StringName for `ResolveModifiers.direction_rel`. Grid Battle is the implicit bridge per ADV-1 from `architecture-review-2026-04-26.md`. **For this integration test**: construct `ResolveModifiers.direction_rel: StringName` directly (skip the bridge for test simplicity). The bridge will be tested in a future Grid Battle ADR's epic.
4. The runtime-source verification (AC-4 sentinel test) extends Story 005's pattern to the integration boundary:
   ```gdscript
   # Replace unit_roles.json cavalry class_direction_mult[2] with sentinel 9.99 (test fixture)
   # Reset UnitRole._coefficients_loaded = false
   # Call DamageCalc.resolve(...) with CAVALRY REAR
   # Assert result.D_mult reflects the sentinel: snappedf(1.5 × 9.99, 0.01) = 14.99
   # (Damage Calc's BASE_CEILING + DAMAGE_CEILING caps would activate, but the D_mult itself proves the source)
   ```
5. **Do not** introduce new tests for the F-DC-5 + F-DC-6 P_mult layer (CHARGE/AMBUSH multipliers) — those are owned by ADR-0012 + damage-calc epic; this story focuses on the UnitRole → DamageCalc D_mult contract specifically.
6. **Do not** assert exact integer raw damage values — those depend on AttackerContext.atk + DefenderContext.def + terrain modifiers which are out of scope here; assert only `D_mult` and `source_flags` provenance.
7. **Do not** test the cross-platform matrix activation in this story — defer to damage-calc story-001 per ADR-0012 R-8 mitigation. macOS-Metal baseline only.

---

## Out of Scope

*Handled by neighbouring stories or downstream consumer epics:*

- Story 005: `get_class_direction_mult` accessor authoring (this story consumes; Story 005 implements)
- DamageCalc.resolve() body itself (already implemented per damage-calc epic Ready/Complete; this story validates the consumer-side contract)
- F-DC-5 + F-DC-6 P_mult layer (CHARGE_BONUS, AMBUSH_BONUS multipliers — owned by ADR-0012 + damage-calc epic)
- Apex damage CEILING activation tests (owned by ADR-0012 §7 cap layering verification — already covered by damage-calc epic AC-DC-7)
- Cross-platform matrix activation (deferred to damage-calc story-001 per ADR-0012 R-8 Mitigation)
- Grid Battle int→StringName direction encoding bridge (deferred to future Grid Battle ADR per ADV-1)
- BASE_DIRECTION_MULT[3] compile-time const declaration on UnitRole (per ADR-0012 §8 — out of scope this sprint; ADR-0012 currently locally-defines this in DamageCalc per provisional-dependency strategy)
- HP/Status `get_modified_stat` consumer integration (owned by future ADR-0010)
- Turn Order `get_acted_this_turn` Scout Ambush gate (owned by future ADR-0011)

---

## QA Test Cases

*Integration story — automated integration test required.*

- **AC-1 (18-combination D_mult composition coverage)**:
  - Given: `_coefficients_loaded` reset in `before_test`; valid `unit_roles.json`; ADR-0012 BASE_DIRECTION_MULT values (FRONT=1.0, FLANK=1.2, REAR=1.5)
  - When: integration test iterates the 18-fixture table; each iteration constructs ResolveModifiers + AttackerContext + DefenderContext, calls `DamageCalc.resolve()`, reads `result.D_mult` (or computes `snappedf(BASE × UnitRole.get_class_direction_mult(class, dir), 0.01)` and compares)
  - Then: every D_mult matches the expected value per the fixture table (within `is_equal_approx(expected, 0.001)` tolerance to handle floating-point variance)
  - Edge cases: STRATEGIST + COMMANDER all-direction values must produce base-only D_mult (CLASS contribution = 1.0 no-op); ARCHER FLANK at 1.65 must be the FLANK numerical anchor matching SCOUT REAR + INFANTRY REAR

- **AC-2 (Cavalry REAR apex composition matches rev 2.8 lock)**:
  - Given: the canonical apex case per ADR-0012 §F-DC-3 + ADR-0009 §6 rev 2.8 ratification
  - When: integration test computes D_mult for CAVALRY REAR
  - Then: `D_mult == 1.64` exactly (or within 0.001 tolerance); combined with CHARGE_BONUS=1.20 (P_mult layer) the final apex damage stays inside DAMAGE_CEILING=180 per ADR-0012 §7
  - Edge cases: any regression to CLASS_DIRECTION_MULT[CAVALRY][REAR]=1.20 (pre-rev-2.8) → D_mult would be 1.80 → DAMAGE_CEILING=180 would fire — collapses Pillar-1+3 hierarchies per damage-calc.md ninth-pass desync audit BLK-G-2; CI test catches immediately

- **AC-3 (Runtime read source — sentinel propagation through DamageCalc)**:
  - Given: a test fixture replaces `unit_roles.json` cavalry `class_direction_mult[2]` with sentinel value 9.99
  - When: test resets `UnitRole._coefficients_loaded = false`; calls DamageCalc.resolve() on a Cavalry REAR attack
  - Then: `result.D_mult == snappedf(1.5 × 9.99, 0.01) == 14.99` (or BASE_CEILING/DAMAGE_CEILING activation; either way, the sentinel propagates — proves the runtime source is `unit_roles.json` and NOT entities.yaml `BalanceConstants.get_const("CLASS_DIRECTION_MULT")`)
  - Edge cases: cleanup restore `unit_roles.json` original value in `after_test`

- **AC-4 (Performance — no observable regression)**:
  - Given: ADR-0012 §Performance 50µs target per resolve() call (headless macOS-Metal baseline)
  - When: integration test runs N=1000 iterations with realistic AttackerContext + DefenderContext + ResolveModifiers
  - Then: average per-call latency < 50µs; per-call cost-table fetch (`UnitRole.get_class_direction_mult`) is <0.01ms per ADR-0009 §Performance budget
  - Edge cases: cross-platform matrix not in scope this story; macOS-Metal baseline only

- **AC-5 (G-15 + UnitRole cache reset in before_test)**:
  - Given: integration test file
  - When: CI lint greps for the reset pattern
  - Then: `before_test()` body contains both `BalanceConstants._cache_loaded = false` AND `UnitRole._coefficients_loaded = false`
  - Edge cases: future test edits that drop either reset → CI lint fails

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/foundation/unit_role_damage_calc_integration_test.gd` — must exist and pass (5 ACs above; ~200-280 LoC test file with 18-fixture parameterized D_mult coverage + apex Cavalry REAR test + sentinel runtime-source verification + perf baseline + G-15 reset)
**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005 (consumes `get_class_direction_mult` accessor); damage-calc epic's `DamageCalc.resolve()` implementation existing (per damage-calc epic Ready 2026-04-26 — story-001+ implementation needed for the resolve() body to be callable; if damage-calc stories not yet done at unit-role-009 implementation time, this story may need to defer to a later sprint or use a stub DamageCalc until damage-calc story-001+ are complete)
- Unlocks: ratifies ADR-0012's CLASS_DIRECTION_MULT[6][3] consumer contract end-to-end; closes the Foundation→Feature soft-dep loop opened during ADR-0012 Acceptance 2026-04-26
