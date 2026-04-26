# Story 005: Stage 2 — direction × passive multiplier + F-DC-4 + F-DC-5 + P_MULT_COMBINED_CAP

> **Epic**: damage-calc
> **Status**: Complete (2026-04-26)
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 4-5 hours (D_mult lookup + Charge/Ambush/Rally/Formation passive composition + P_MULT_COMBINED_CAP clamp + class-mutex + unknown_class guard + 7 ACs)
> **Actual**: ~4 hours (vertical-slice cadence holding)

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

- [x] **AC-DC-03 (D-3 Cavalry REAR Charge primary)**: Cavalry REAR, ATK=80, DEF=50, charge_active=true, passive_charge, is_counter=false → D_mult=1.64, P_mult=1.20 → Stage-2 raw composition `floori(30×1.64×1.20) = 59`
- [x] **AC-DC-04 (D-4 hardest primary path)**: Cavalry REAR Charge ATK=200, DEF=10, Rally(+10%), Formation(+5%) → D_mult=1.64, pre-cap P_mult=1.39 → P_MULT_COMBINED_CAP clamps to 1.31 → `floori(83×1.64×1.31) = 178` (NOT 180 — DAMAGE_CEILING silent on primary path)
- [x] **AC-DC-09 (D-9 Scout Ambush FLANK)**: Scout, ATK=70, DEF=40, FLANK, round=3, defender not acted → D_mult=1.20, P_mult=1.15, base=30 → `floori(30×1.20×1.15) = 41`
- [x] **AC-DC-16 (EC-DC-8 Charge suppressed on counter)**: same inputs `is_counter ∈ {true, false}` → P_mult ∈ {1.00, 1.20} respectively
- [x] **AC-DC-21 (EC-DC-15 unknown_class guard)**: `attacker.unit_class = 99` (via `TestAttackerContextBypass`) → push_error fires; returns MISS with `source_flags.has(&"invariant_violation:unknown_class") == true`
- [x] **AC-DC-27 (EC-DC-9 dual-passive class mutex)**: For each class ∈ {CAVALRY, SCOUT, INFANTRY, ARCHER}, attempt to fire BOTH `passive_charge` AND `passive_ambush`; assert P_mult ∈ {1.00, 1.15, 1.20} only — NEVER 1.38 (1.20×1.15=1.38 is structurally impossible)
- [x] **AC-DC-52 (D-7 Formation ATK sub-apex)**: Cavalry REAR Charge, ATK=200, DEF=10, formation_atk_bonus=0.05, no Rally → P_mult=snappedf(1.20×1.05, 0.01)=1.26 (P_MULT_COMBINED_CAP=1.31 does NOT fire) → `floori(83×1.64×1.26) = 171`; supplementary delta vs `formation_atk_bonus=0.0` (P_mult=1.20, raw=163) proves Formation ATK is live and visible at sub-apex (+8 damage)
- [x] Stage-2 returns `(int base_damage, float D_mult, float P_mult)` tuple OR `int raw_pre_dc6` for Stage 3+ consumption (chose `raw_pre_dc6` int per Implementation Notes line 100 recommendation; simpler interface for Stage-3 in story-006)
- [x] Private helpers declared and tested: `_direction_multiplier`, `_passive_multiplier`, `_charge_factor`, `_ambush_factor` (4 helpers shipped; `_invariant_guard_unknown_class` was deleted post-/code-review S-1 because the inline guard at `resolve()` line 119 is the sole enforcement site — having an extracted helper alongside it caused divergent push_error message prefixes; `_apply_p_mult_combined_cap` and `_check_class_mutex` from the original spec were folded into `_passive_multiplier` and `_charge_factor`/`_ambush_factor` respectively, simplifying the call graph without losing semantic clarity)

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

**Status**: [x] Test file at `tests/unit/damage_calc/damage_calc_test.gd` — 9 new test functions appended (7 covering AC-DC-03/04/09/16/21/27/52 + 2 from /code-review qa-tester E-1/E-2). 46/46 PASS in damage_calc unit suite, 341/341 PASS in full regression (0 errors / 0 failures / 0 orphans / exit 0).

---

## Dependencies

- Depends on: Story 004 (Stage 1 base damage feeds Stage 2)
- Unlocks: Story 006 (Stage 3 raw + counter halve consumes Stage-2 output)

---

## Completion Notes

**Completed**: 2026-04-26 (PR #61 merged; commit 54c1ad5 on main)

**Criteria**: 9/7 PASS (7 ACs + 2 bonus from /code-review qa-tester E-1/E-2).
- All 7 ACs covered by 7 dedicated test functions; AC-6 uses 4-class parametric mutex with `override_failure_message` per the established S-2 pattern + structural-invariant sentinel (P_mult NEVER 1.38).
- E-1 (qa-tester recommendation): default-Callable Ambush fallback through `resolve()` — pins the production contract that an unset `acted_this_turn_callable` evaluates as `is_valid()=false` in `_ambush_factor` → `has_acted=false` → Ambush fires. Distinct from AC-3 which injects an explicit lambda.
- E-2 (qa-tester recommendation): Counter+Rally+Formation simultaneous test — pins spec line 96 positive claim ("Rally + Formation still apply on counter"). Counter suppresses Charge but Rally(+10%)+Formation(+5%) still apply → P_mult>1.00. Includes dual-resolve delta (+8) per the AC-7 pattern.

**Pre-resolved decisions (orchestrator authorization, recorded for audit)**:
1. Hardcoded constants (`P_MULT_COMBINED_CAP=1.31`, `CHARGE_BONUS=1.20`, `AMBUSH_BONUS=1.15`, `BASE_DIRECTION_MULT`, `CLASS_DIRECTION_MULT`) per §Implementation Notes line 99 — `BalanceConstants` wrapper does not exist yet; story-006 grep-lint AC-DC-48 will catch and force migration when ADR-0006 lands. TODO(story-006) inline at `damage_calc.gd:9-13` (consolidated with story-004's hardcoded-constants TODO block).
2. **`mini_float` story-spec typo** at story line 90 → corrected to `minf` at brief-time. The actual GDScript API is `minf(a, b)` for floats; `mini_float` does not exist. Documented in dev-story brief; agent never wrote the wrong API.
3. **Turn Order injection seam** = `acted_this_turn_callable: Callable` field on `ResolveModifiers` (defaults to no-op `Callable()`). Matches the story-004-prep wrapper-field precedent. Production wiring (story-007 Grid Battle) will inject `TurnOrder.get_acted_this_turn`; tests inject inline lambdas per AC-3.
4. **F-1 policy = Option 1** (accept AC-10 literal-grep brittleness) — parity with story-004. Avoided the literal `int(` substring in all new code and doc-comments. AC-10 grep test from story-004 still passes clean (0 occurrences in `damage_calc.gd`).

**Implementation refinements during /code-review** (6 inline + 6 deferred):
- Inline-applied:
  - **S-1** (gdscript): deleted dead `_invariant_guard_unknown_class` helper — divergent push_error prefixes vs the inline guard at `resolve()` was a maintenance hazard. Inline guard is now sole enforcement.
  - **S-2** (gdscript): rewrote `_ambush_factor` class check from verbose multi-line OR to `in` idiom (style consistency with passives check).
  - **N-1** (gdscript): added explanatory comment on `CLASS_DIRECTION_MULT` int keys (Godot 4.6 const Dictionary doesn't permit enum literals).
  - **N-3** (gdscript): updated `damage_calc_test.gd` file-level doc comment to cumulative story-003 + 004 + 005 coverage.
  - **E-1** (qa): added default-Callable Ambush fallback test.
  - **E-2** (qa): added Counter+Rally+Formation simultaneous test.
- Deferred with rationale:
  - **S-3** (gdscript): AC-2 doc-comment arithmetic polish (1.386 vs 1.39 post-snap) — comment-only; code correct.
  - **N-2** (gdscript): `wrapper_classes_test.gd` "all-10-args" comment now stale (11 args after `acted_this_turn_callable`) — AC-7 covers the 11th field; comment-only.
  - **G-1** (qa): AC-2 sub-case description nuance — test functionally correct.
  - **G-2** (qa MAJOR): AC-5 production-exclusion grep scope (only checks `damage_calc.gd`, not full `src/`) — defer to story-008 AC-DC-51(b) full-src/ bypass-seam grep (subsumes).
  - **E-3** (qa): `P_MULT_COMBINED_CAP` boundary (== 1.31 exactly) — `minf` semantics well-defined; low priority.
  - **F-2** (qa): AC-6 structural-invariant assertion direction — no code change needed.

**Retroactive fix (orchestrator-direct, ~3 min, 9 surgical edits)**:
- Stage 2 wiring multiplied story-004 Stage-1 tests' results by `D_mult ≠ 1.0` (because INFANTRY+FRONT → 0.90 per story-005 spec line 66). Surgical fix: 9 `INFANTRY → SCOUT` swaps in story-004 test fixtures (SCOUT has `D_mult=1.00` across all directions per spec line 64 — fully decouples Stage-1 verification from Stage-2 multiplication). Each swap got an inline rationale comment. 0 logic changes; expected values unchanged. CAVALRY-specific tests at lines 309/330 untouched (CAVALRY+FRONT also produces D_mult=1.00).
- **G-19 codification candidate** (NEW): Stage-N tests in multi-stage pipelines must use class+direction with downstream-mult identity (D_mult=1.00) for stage-isolated verification. SCOUT class is the "identity element" for D_mult. Worth batching with G-16/G-17/G-18 for tech-debt sweep into `.claude/rules/godot-4x-gotchas.md`.

**Out-of-scope deferrals tracked**:
- **N-1 (story-004 deferral)** enum-cast `as ResolveResult.AttackType` time-bomb — still deferred; will be addressed in story-006 ResolveResult.HIT/MISS construction scope.
- **F-1 policy decision** still open for qa-lead; surface again at `/story-readiness story-006`.

**Test Evidence**: Logic story — `tests/unit/damage_calc/damage_calc_test.gd` (46 functions; 9 new for story-005 + 9 INFANTRY→SCOUT swaps in story-004 fixtures; 46/46 PASS; 0 orphans; exit 0). Full regression 341/341 PASS. CI green on PR #61 (macOS Metal + GdUnit4 + gdunit4-report all pass).

**Code Review**: Standalone `/code-review` (lean dual: gdscript-specialist + qa-tester) → APPROVED WITH SUGGESTIONS APPLIED. 6 inline edits applied; 6 deferred with rationale. Per-story dev-time gate review skipped per lean mode (`production/review-mode.txt`).

**Files delivered**:
- M `src/feature/damage_calc/damage_calc.gd` (+139 LoC; 5 const declarations + AC-DC-21 unknown_class guard + 4 private static helpers; replaces story-004 `TODO(story-005)` placeholder for Stage 2)
- M `src/feature/damage_calc/resolve_modifiers.gd` (+10 LoC; new `acted_this_turn_callable: Callable` field + factory param)
- M `tests/unit/damage_calc/damage_calc_test.gd` (+447 LoC + 9 surgical edits; 9 new test functions appended to story-004 baseline + 1 nested TestAttackerContextBypass class for AC-5 + 9 retroactive INFANTRY→SCOUT swaps in story-004 fixtures)
- M `tests/unit/damage_calc/wrapper_classes_test.gd` (+30 LoC; 1 new test for `acted_this_turn_callable` defaults + invocation)

**Damage-calc epic progress**: 4/10 → 5/10. Vertical-slice 5/7 done (next: 006 → 007 = first-playable damage roll demo).
**Sprint 1**: 7 stories closed → unchanged (vertical-slice 002-007 tracked via EPIC.md per `sprint-status.yaml` S1-06 inline note; story-005 not separately tracked).

**Unlocks**: damage-calc story-006 (Stage 3-4 — DAMAGE_CEILING=180 final cap + counter halve via COUNTER_ATTACK_MODIFIER=0.5 + ResolveResult.HIT/MISS construction with full source_flags semantics; consumes `raw_pre_dc6` from this story's output; final story before story-007 Grid Battle integration = first-playable damage roll demo).
