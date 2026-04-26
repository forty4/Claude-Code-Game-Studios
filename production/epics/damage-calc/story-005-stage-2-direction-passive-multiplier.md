# Story 005: Stage 2 — direction × passive multiplier + F-DC-4 + F-DC-5 + P_MULT_COMBINED_CAP

> **Epic**: damage-calc
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 4-5 hours (D_mult lookup + Charge/Ambush/Rally/Formation passive composition + P_MULT_COMBINED_CAP clamp + class-mutex + unknown_class guard + 7 ACs)

## Context

**GDD**: `design/gdd/damage-calc.md`
**Requirement**: `TR-damage-calc-007` (cap layer Stage-2.5), `TR-damage-calc-008` (Unit Role + Turn Order + Balance/Data upstream interfaces)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012 Damage Calc
**ADR Decision Summary**: Stage 2 is direction multiplier F-DC-4 (`D_mult = snappedf(BASE_DIRECTION_MULT[dir] × CLASS_DIRECTION_MULT[class][dir], 0.01)`) + Stage 2.5 passive multiplier F-DC-5 (Charge×Ambush×Rally×Formation composition with class-mutex Charge/Ambush exclusion + P_MULT_COMBINED_CAP=1.31 post-composition clamp). Per provisional ADR-0009 workaround: const tables defined locally using `unit-role.md` §EC-7 locked values verbatim.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `snappedf(value, 0.01)` + `&"foo" in Array[StringName]` linear scan (O(n), adequate at MVP — 2-5 passives/unit per ADV-2). The class-mutex check (CAVALRY → Charge fires, SCOUT/ARCHER → Ambush fires, INFANTRY → neither) is a structural design constraint — passive flag presence in `attacker.passives` does NOT mean the passive fires; class+passive both required. AC-DC-21 unknown_class guard fires here at the F-DC-4 lookup site.

**Control Manifest Rules (Feature layer)**:
- Required: StringName literal comparisons for passives (`&"passive_charge"`, `&"passive_ambush"`) — NEVER plain `String` (per AC-DC-51 release-build defense)
- Required: `snappedf(value, 0.01)` precision for D_mult composition
- Required: P_MULT_COMBINED_CAP applied AFTER all multiplicative composition (Charge/Ambush × Rally × Formation), NOT per-component
- Forbidden: Reordering D_mult or P_mult composition steps (multiplicative ordering is non-negotiable per damage-calc.md §F-DC-4/F-DC-5 + ADR-0012 §7)
- Forbidden: Hardcoded `1.20` / `1.15` / `1.31` / direction-multiplier values in `damage_calc.gd` (per AC-DC-48 + forbidden_pattern `hardcoded_damage_constants`)

---

## Acceptance Criteria

*From `damage-calc.md` §F-DC-4 + §F-DC-5 + AC-DC-03/04/09/16/21/27/52:*

- [ ] **AC-DC-03 (D-3 Cavalry REAR Charge primary)**: Cavalry REAR, ATK=80, DEF=50, charge_active=true, passive_charge, is_counter=false → D_mult=1.64, P_mult=1.20 → Stage-2 raw composition `floori(30×1.64×1.20) = 59`
- [ ] **AC-DC-04 (D-4 hardest primary path)**: Cavalry REAR Charge ATK=200, DEF=10, Rally(+10%), Formation(+5%) → D_mult=1.64, pre-cap P_mult=1.39 → P_MULT_COMBINED_CAP clamps to 1.31 → `floori(83×1.64×1.31) = 178` (NOT 180 — DAMAGE_CEILING silent on primary path)
- [ ] **AC-DC-09 (D-9 Scout Ambush FLANK)**: Scout, ATK=70, DEF=40, FLANK, round=3, defender not acted → D_mult=1.20, P_mult=1.15, base=30 → `floori(30×1.20×1.15) = 41`
- [ ] **AC-DC-16 (EC-DC-8 Charge suppressed on counter)**: same inputs `is_counter ∈ {true, false}` → P_mult ∈ {1.00, 1.20} respectively
- [ ] **AC-DC-21 (EC-DC-15 unknown_class guard)**: `attacker.unit_class = 99` (via `TestAttackerContextBypass`) → push_error fires; returns MISS with `source_flags.has(&"invariant_violation:unknown_class") == true`
- [ ] **AC-DC-27 (EC-DC-9 dual-passive class mutex)**: For each class ∈ {CAVALRY, SCOUT, INFANTRY, ARCHER}, attempt to fire BOTH `passive_charge` AND `passive_ambush`; assert P_mult ∈ {1.00, 1.15, 1.20} only — NEVER 1.38 (1.20×1.15=1.38 is structurally impossible)
- [ ] **AC-DC-52 (D-7 Formation ATK sub-apex)**: Cavalry REAR Charge, ATK=200, DEF=10, formation_atk_bonus=0.05, no Rally → P_mult=snappedf(1.20×1.05, 0.01)=1.26 (P_MULT_COMBINED_CAP=1.31 does NOT fire) → `floori(83×1.64×1.26) = 171`; supplementary delta vs `formation_atk_bonus=0.0` (P_mult=1.20, raw=163) proves Formation ATK is live and visible at sub-apex (+8 damage)
- [ ] Stage-2 returns `(int base_damage, float D_mult, float P_mult)` tuple OR `int raw_pre_dc6` for Stage 3+ consumption (whichever pattern matches the F-DC-1 master pipeline composition)
- [ ] Private helpers declared and tested: `_direction_multiplier`, `_passive_multiplier`, `_apply_p_mult_combined_cap`, `_check_class_mutex`, `_invariant_guard_unknown_class`

---

## Implementation Notes

*Derived from ADR-0012 §7 + §8 + damage-calc.md §F-DC-4/F-DC-5:*

- **Direction multiplier table** (F-DC-4, per `unit-role.md` §EC-7 locked values rev 2.8): define LOCAL const tables in `damage_calc.gd` per ADR-0012 §8 provisional ADR-0009 workaround:
  ```gdscript
  const BASE_DIRECTION_MULT := {
      &"FRONT": 1.00,
      &"FLANK": 1.20,
      &"REAR": 1.50,
  }
  const CLASS_DIRECTION_MULT := {
      0: {  # CAVALRY
          &"FRONT": 1.00, &"FLANK": 1.05, &"REAR": 1.09,  # rev 2.8 — was 1.20 pre Rally-cap-fix
      },
      1: {  # SCOUT
          &"FRONT": 1.00, &"FLANK": 1.00, &"REAR": 1.00,
      },
      2: {  # INFANTRY
          &"FRONT": 0.90, &"FLANK": 1.00, &"REAR": 1.00,
      },
      3: {  # ARCHER
          &"FRONT": 1.00, &"FLANK": 1.375, &"REAR": 1.00,  # rev 2.6 — Pillar-3 parity per BLK-7-9/10
      },
  }
  ```
  When ADR-0009 lands, replace with `UnitRole.BASE_DIRECTION_MULT` + `UnitRole.CLASS_DIRECTION_MULT` imports and remove locals.
- **AC-DC-21 unknown_class guard**: at the F-DC-4 lookup site, if `attacker.unit_class not in CLASS_DIRECTION_MULT.keys()`, fire the guard:
  ```gdscript
  if not CLASS_DIRECTION_MULT.has(attacker.unit_class):
      push_error("damage_calc.resolve: unknown unit_class %d" % attacker.unit_class)
      return ResolveResult.miss([&"invariant_violation:unknown_class"])
  ```
  Test via `TestAttackerContextBypass` subclass per ADR-0012 §Implementation Guidelines + AC-DC-21 pattern.
- **D_mult composition** (CR-7 + F-DC-4): `D_mult = snappedf(BASE_DIRECTION_MULT[direction_rel] * CLASS_DIRECTION_MULT[unit_class][direction_rel], 0.01)`. Note: precision 0.01 (locked-not-tunable). Apex example: Cavalry REAR = `snappedf(1.50 × 1.09, 0.01) = snappedf(1.6350, 0.01) = 1.64`.
- **Passive multiplier composition** (CR-8 + F-DC-5):
  ```
  P_mult_pre_cap = (
      _charge_factor(attacker, modifiers) ×
      _ambush_factor(attacker, modifiers, turn_order) ×
      (1.0 + modifiers.rally_bonus) ×
      (1.0 + modifiers.formation_atk_bonus)
  )
  P_mult = mini_float(P_MULT_COMBINED_CAP, P_mult_pre_cap)
  ```
- **Class mutex** (AC-DC-27 EC-DC-9):
  - Charge fires iff `attacker.unit_class == CAVALRY` AND `attacker.charge_active` AND `&"passive_charge" in attacker.passives` AND NOT `modifiers.is_counter`. Returns 1.20 (CHARGE_BONUS) or 1.00.
  - Ambush fires iff `attacker.unit_class ∈ {SCOUT, ARCHER}` AND `&"passive_ambush" in attacker.passives` AND NOT `modifiers.is_counter` AND `modifiers.round_number >= 2` AND `not turn_order.get_acted_this_turn(defender.unit_id)`. Returns 1.15 (AMBUSH_BONUS) or 1.00.
  - Class mutex: CAVALRY can never fire Ambush (Ambush guard blocks); SCOUT/ARCHER can never fire Charge (Charge requires CAVALRY); INFANTRY fires neither. Result: P_mult ∈ {1.00, 1.15, 1.20} only at the Charge/Ambush axes (Rally and Formation can compound).
- **Counter suppression** (AC-DC-16 EC-DC-8): on `is_counter == true`, both Charge and Ambush guards block (per CR-8 — counters are reactive, not pre-charged). P_mult contribution from Charge/Ambush = 1.00 on counter path. Rally + Formation still apply on counter (per F-DC-5 line ordering).
- **Turn Order interface**: `turn_order.get_acted_this_turn(defender.unit_id)` is provisional per ADR-0012 §8 workaround (ADR-0011 not yet written). Test fixture stub: inject a callable that returns false unless test sets it true.
- **AC-DC-52 D-7 Formation ATK sub-apex**: tests the case where P_MULT_COMBINED_CAP does NOT fire (sub-apex stack). Cavalry+Charge+Formation(+5%) no Rally: pre-cap `1.20 × 1.05 = 1.26` < 1.31, so cap is NOT applied. Delta vs no-Formation case (P_mult=1.20) proves Formation contributes +8 damage at this stack.
- **`P_MULT_COMBINED_CAP` constant**: 1.31, registered as `entities.yaml` constant (locked-not-tunable per damage-calc.md §Tuning Knobs Locked-not-tunable). Read via `BalanceConstants.get_const("P_MULT_COMBINED_CAP")`.
- **Stage-2 output to Stage-3**: this story can either return a tuple `(base, D_mult, P_mult)` or compute `raw = floori(base × D_mult × P_mult)` and pass that as int. Recommend the latter (simpler interface; Stage-3 in story-006 just applies DAMAGE_CEILING + counter halve to the int).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: Stage 3 raw damage (F-DC-6) DAMAGE_CEILING=180 final cap + counter halve (F-DC-7) + ResolveResult.hit/miss construction + source_flags semantics + AC-DC-08 D-8 DEFEND_STANCE counter (full path)
- Story 008: AC-DC-25 EC-DC-24 snappedf cross-platform residue + AC-DC-50 engine pin

---

## QA Test Cases

*Authored from damage-calc.md §F-DC-4/F-DC-5 + AC ranges directly. Developer implements against these.*

- **AC-1 (AC-DC-03 D-3 Cavalry REAR Charge primary)**:
  - Given: Cavalry, ATK=80, DEF=50, REAR, charge_active=true, passive_charge, is_counter=false
  - When: full pipeline through Stage 2.5 cap
  - Then: D_mult=1.64, P_mult=1.20, raw=floori(30×1.64×1.20)=59 (verified at story-006 final result)

- **AC-2 (AC-DC-04 D-4 hardest primary path)**:
  - Given: Cavalry REAR Charge ATK=200, DEF=10, Rally(+10%), Formation(+5%)
  - When: full pipeline
  - Then: base=83, D_mult=1.64, pre-cap P_mult=1.20×1.10×1.05=1.386 → P_MULT_COMBINED_CAP clamps to 1.31 → raw=floori(83×1.64×1.31)=178; supplementary: same with charge_active=false but Rally cap+no Formation → P_mult=1.10, raw=floori(83×1.64×1.10)=149 (proves 29pt differentiation at max-everything)

- **AC-3 (AC-DC-09 D-9 Scout Ambush FLANK)**:
  - Given: Scout, ATK=70, DEF=40, FLANK, round=3, defender not acted (turn_order.get_acted_this_turn returns false), passive_ambush
  - When: Stage 2
  - Then: D_mult=snappedf(1.20×1.00, 0.01)=1.20, P_mult=1.15, base=30, raw=floori(30×1.20×1.15)=41

- **AC-4 (AC-DC-16 EC-DC-8 Charge suppressed on counter)**:
  - Given: identical Cavalry REAR Charge inputs, two runs `is_counter ∈ {true, false}`
  - When: Stage 2.5
  - Then: P_mult ∈ {1.00, 1.20} respectively; resolved_damage differs by exactly 1.20× factor

- **AC-5 (AC-DC-21 EC-DC-15 unknown_class guard)**:
  - Given: `var ctx := TestAttackerContextBypass.new()` with `ctx.unit_class = 99`
  - When: `DamageCalc.resolve(ctx, ...)`
  - Then: `result.kind == MISS`, `result.source_flags.has(&"invariant_violation:unknown_class") == true`; push_error fires (visual log check)
  - Edge cases: production-exclusion grep lint — `TestAttackerContextBypass` must NOT appear in `src/`

- **AC-6 (AC-DC-27 EC-DC-9 class mutex)**:
  - Given: 4 test runs, one per class (CAVALRY/SCOUT/INFANTRY/ARCHER), each with `passives=[&"passive_charge", &"passive_ambush"]` AND charge_active=true
  - When: Stage 2.5
  - Then:
    - Cavalry: P_mult=1.20 (Charge fires, Ambush class-blocked)
    - Scout: P_mult=1.15 (Ambush fires, Charge class-blocked)
    - Infantry: P_mult=1.00 (both class-blocked)
    - Archer: P_mult=1.15 (Ambush fires, Charge class-blocked)
  - Edge cases: P_mult is NEVER 1.38 across all 4 classes — class mutex structurally enforces

- **AC-7 (AC-DC-52 D-7 Formation ATK sub-apex)**:
  - Given: Cavalry REAR Charge ATK=200, DEF=10, formation_atk_bonus=0.05, no Rally
  - When: Stage 2.5
  - Then: pre-cap P_mult = 1.20 × 1.05 = 1.26 (P_MULT_COMBINED_CAP=1.31 does NOT fire); D_mult=1.64; raw=floori(83×1.64×1.26)=171
  - Edge cases: same inputs with formation_atk_bonus=0.0 → P_mult=1.20, raw=floori(83×1.64×1.20)=163; delta=171-163=+8 proves Formation ATK contribution

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/damage_calc/damage_calc_test.gd` — Stage 2 + F-DC-4/5 test functions; must pass on headless CI

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 004 (Stage 1 base damage feeds Stage 2)
- Unlocks: Story 006 (Stage 3 raw + counter halve consumes Stage-2 output)
