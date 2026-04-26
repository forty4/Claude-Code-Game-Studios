# Story 004: Stage 1 — base damage + F-DC-3 + BASE_CEILING (CR-3..CR-6)

> **Epic**: damage-calc
> **Status**: Complete (2026-04-26)
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 4-5 hours (effective-stat read via stub + terrain reduction + DEFEND_STANCE penalty + base damage formula + BASE_CEILING cap + Formation DEF consumer + 11 ACs)
> **Actual**: ~3.5 hours (vertical-slice cadence holding)

## Context

**GDD**: `design/gdd/damage-calc.md`
**Requirement**: `TR-damage-calc-007` (cap layer Stage-1), `TR-damage-calc-008` (HP/Status + Terrain Effect upstream interfaces)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012 Damage Calc
**ADR Decision Summary**: Stage 1 of the 12-stage pipeline reads effective stats from HP/Status (`get_modified_stat`), consumes already-clamped terrain_def from Terrain Effect (ADR-0008 contract), applies DEFEND_STANCE 0.60× ATK penalty, computes `base_damage = floori(eff_atk - eff_def × defense_mul)` with `MIN_DAMAGE = 1` floor and `BASE_CEILING = 83` ceiling. Adds Formation DEF consumer per F-DC-3 rev 2.9.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `clampi(value, 1, ATK_CAP)` and `clampi(eff_def, 1, DEF_CAP)` are 4.0-stable. `floori(float)` is round-toward-negative-infinity (per AC-DC-23 EC-DC-20 — distinct from `int(float)` truncate-toward-zero). `snappedf(value, 0.01)` precision-locked per AC-DC-30 EC-DC-21.

**Control Manifest Rules (Feature layer)**:
- Required: All tuning constants read via `DataRegistry.get_const(key)` or the provisional `BalanceConstants` wrapper — NEVER hardcoded `83`, `200`, `100`, `0.40`, etc. (per ADR-0012 §6 + AC-DC-48 + forbidden_pattern `hardcoded_damage_constants`)
- Required: `floori()` not `int()` for all int conversions in pipeline arithmetic (per AC-DC-23 EC-DC-20 + ADR-0012 §Decision 7)
- Required: `snappedf(value, 0.01)` precision-locked at 0.01 (NOT 0.001) per AC-DC-30 EC-DC-21
- Forbidden: Direct read of `Unit.atk` / `Unit.phys_def` raw stats — must go through `hp_status.get_modified_stat()` (per ADR-0012 §8 + Section F)

---

## Acceptance Criteria

*From `damage-calc.md` §F-DC-3 + AC-DC-01..07/11..15/23/53:*

- [x] **AC-DC-01 (D-1 baseline)**: `resolve(eff_atk=80, eff_def=50, FRONT, no passives)` → `HIT(resolved_damage=30)` (Cavalry FRONT base, no multipliers in Stage 1 — D_mult/P_mult applied in stories 005-006)
- [x] **AC-DC-02 (D-2 BASE_CEILING)**: ATK=190, DEF=10, FRONT → base=83 (clamps at BASE_CEILING)
- [x] **AC-DC-05 (D-5 MIN_DAMAGE floor)**: ATK=30, DEF=100, T_def=+30 → base=1 (MIN_DAMAGE floor)
- [x] **AC-DC-06 (D-6 negative T_def amplifies defense)**: ATK=60, DEF=50, T_def=−30 → defense_mul=1.30 → base=1 (since `60 − 50×1.30 = −5`, clamped to 1)
- [x] **AC-DC-07 (D-7 positive T_def penalty)**: ATK=80, DEF=50, T_def=+20 → defense_mul=0.80 → base=40 (`floori(80 − 50×0.80) = 40`)
- [x] **AC-DC-11 (EC-DC-1 ATK 0 clamp)**: mock `get_modified_stat` returning 0 or −5 → eff_atk clamped to 1; pipeline does not produce negative base
- [x] **AC-DC-12 (EC-DC-2 DEFEND_STANCE on eff_atk=1)**: `is_counter=true, defend_stance_active=true, raw_atk=1` → `floori(1×0.60)=0` → max(MIN_DAMAGE, 0) recovers to base=1
- [x] **AC-DC-13 (EC-DC-3 terrain_def boundary clamp)**: T_def values −31, −30, 0, +30, +31 → defense_mul values 1.30, 1.30, 1.00, 0.70, 0.70 (via `snappedf(1.0 − clampi(T_def, -30, 30) / 100.0, 0.01)`)
- [x] **AC-DC-15 (EC-DC-7 ATK over cap)**: mock returning 199, 200, 201 → eff_atk = 199, 200, 200 (Damage Calc clamp is last defense)
- [x] **AC-DC-23 (EC-DC-20 floori not int)**: synthetic intermediate float = −0.7 → result matches `floori(−0.7) = −1` path, not `int(−0.7) = 0` path; static grep for `int(` in `damage_calc.gd` returns 0 matches
- [x] **AC-DC-53 (D-8 Formation DEF consumer)**: `formation_def_bonus = 0.04`, `defender.def = 50` → `eff_def = clampi(50, 1, 100) + floori(50 × 0.04) = 50 + 2 = 52` → base=30; supplementary delta assertion vs `formation_def_bonus = 0.0` proves Formation DEF absorbs 2 points
- [x] Stage-1 returns `int base_damage` (passed to Stage 2 in story-005); private helpers `_stage_1_base_damage`, `_apply_defend_stance_penalty`, `_compute_defense_mul`, `_consume_formation_def_bonus` declared and tested

---

## Implementation Notes

*Derived from ADR-0012 §7 + damage-calc.md §F-DC-3 + §CR-3..CR-6:*

- **Effective ATK read** (CR-3): `var raw_atk: int = attacker.raw_atk` — pre-extracted at Grid Battle from `hp_status.get_modified_stat(attacker.unit_id, &"atk")` per **ADR-0012 §8 amendment 2026-04-26 (Call-site ownership)**. The wrapper field carries the un-clamped value; CR-3's `clampi(raw_atk, 1, ATK_CAP)` is applied below. Test fixtures construct `AttackerContext` with mocked `raw_atk` directly (e.g. `AttackerContext.make(&"unit_a", AttackerContext.Class.CAVALRY, 80, false, false, [])`) — no HP/Status stub or callable injection needed.
- **Effective DEF read** (CR-3): `var raw_def: int = defender.raw_def` — pre-extracted at Grid Battle from `hp_status.get_modified_stat(defender.unit_id, def_stat)` where `def_stat = &"phys_def" if modifiers.attack_type == PHYSICAL else &"mag_def"`. The attack-type-conditional stat-name selection happens at Grid Battle construction time, not inside DamageCalc. Test fixtures construct `DefenderContext` with mocked `raw_def` directly.
- **DEFEND_STANCE penalty** (CR-3 + CR-4 + AC-DC-12): if `attacker.defend_stance_active`: `eff_atk = floori(raw_atk × DEFEND_STANCE_ATK_PENALTY)` where `DEFEND_STANCE_ATK_PENALTY = 0.40` from `entities.yaml` (per ADR-0012 §6 — read via `DataRegistry.get_const("DEFEND_STANCE_ATK_PENALTY")`). NOTE: the value 0.40 means damage at 1.0 - 0.40 = 0.60 multiplier per damage-calc.md §CR-3 — the constant name uses "PENALTY" but is the penalty fraction itself, not the multiplier; verify this against the GDD's CR-3 wording before implementing.
- **ATK / DEF clamps** (CR-3 + AC-DC-11/15): `eff_atk = clampi(raw_atk, 1, ATK_CAP)` where `ATK_CAP = 200`; `eff_def = clampi(raw_def, 1, DEF_CAP)` where `DEF_CAP = 105` (rev 2.9.2 — was 100; range expanded per damage-calc.md rev 2.9.2 changelog).
- **Formation DEF bonus consumer** (F-DC-3 rev 2.9, AC-DC-53): after eff_def clamp, add `floori(eff_def × modifiers.formation_def_bonus)` to eff_def. Range guard: `formation_def_bonus ∈ [0.0, 0.05]` upstream-capped per Formation Bonus F-FB-3.
- **Defense multiplier** (CR-4 + AC-DC-13): `defense_mul = snappedf(1.0 − clampi(defender.terrain_def, -MAX_DEFENSE_REDUCTION, MAX_DEFENSE_REDUCTION) / 100.0, 0.01)` where `MAX_DEFENSE_REDUCTION = 30` (per ADR-0008 ownership; read via `TerrainEffect.max_defense_reduction()` accessor or constant).
- **Base damage formula** (CR-5 + CR-6 + F-DC-3): `var base := floori(eff_atk - eff_def * defense_mul); base = mini(BASE_CEILING, max(MIN_DAMAGE, base))` where `BASE_CEILING = 83` and `MIN_DAMAGE = 1`.
- **Returned to Stage 2**: integer `base_damage ∈ [1, 83]`.
- **`floori` vs `int()`** (AC-DC-23 EC-DC-20): all int conversions use `floori()` (round-toward-negative-infinity). Static grep on `damage_calc.gd` for `int(` returns 0 matches.
- **`snappedf` precision lock** (AC-DC-30 EC-DC-21 — verified in story-008): all `snappedf(value, 0.01)` calls use precision 0.01 (NOT 0.001). Hardcoding the precision in this story is OK (AC-DC-48 only requires constants from `entities.yaml` to be tunable; the snappedf precision is locked-not-tunable per damage-calc.md §Tuning Knobs Locked-not-tunable).
- **Provisional `BalanceConstants` wrapper**: per epic workaround pattern, until ADR-0006 is Accepted, `DataRegistry.get_const()` calls go through a thin `BalanceConstants` wrapper that reads `entities.yaml` directly via `FileAccess` + `JSON.parse_string`. Wrapper API: `BalanceConstants.get_const("KEY") -> Variant`. Concrete keys consumed by Stage 1: `BASE_CEILING`, `MIN_DAMAGE`, `ATK_CAP`, `DEF_CAP`, `DEFEND_STANCE_ATK_PENALTY`, `MAX_DEFENSE_REDUCTION`. (Hardcoding is OK for this story IF the wrapper file does not yet exist; in that case grep-lint AC-DC-48 in story-006 will catch hardcoded literals at static-lint time and require the migration. Recommend implementing the wrapper here to avoid story-006 rework.)

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: Stage 2 direction × passive multiplier (F-DC-4 + F-DC-5) — `D_mult` and `P_mult` composition; AC-DC-03/04/09 D-3/D-4/D-9 examples; AC-DC-21 unknown_class guard
- Story 006: Stage 3-4 raw damage (F-DC-6) + counter halve (F-DC-7) + DAMAGE_CEILING + ResolveResult construction + source_flags + AC-DC-08 D-8 DEFEND_STANCE counter (full path)
- Story 008: AC-DC-30 EC-DC-21 snappedf precision lock test + AC-DC-50 engine pin

---

## QA Test Cases

*Authored from damage-calc.md §F-DC-3 + AC ranges directly. Developer implements against these.*

- **AC-1 (AC-DC-01 D-1 baseline)**: Cavalry FRONT, no passives, no terrain
  - Given: `atk=80, def=50, T_def=0, FRONT, no passives, no charge, no defend_stance`; mock `get_modified_stat` returns 80 (atk) and 50 (phys_def)
  - When: Stage-1 returns base_damage
  - Then: `base_damage == 30` (floori(80 - 50*1.00) = 30, no BASE_CEILING fire)
  - Edge cases: with full pipeline (stories 005-006), final `resolved_damage == 30` for D-1

- **AC-2 (AC-DC-02 D-2 BASE_CEILING fires)**: ATK=190, DEF=10, FRONT
  - Given: `atk=190, def=10, T_def=0, FRONT`
  - When: Stage-1 base
  - Then: `base_damage == 83` (clamps; floori(190 - 10*1.00) = 180 → mini(83, max(1, 180)) = 83)

- **AC-3 (AC-DC-05 D-5 MIN_DAMAGE)**: ATK=30, DEF=100, T_def=+30
  - Given: `atk=30, def=100, T_def=+30`
  - When: Stage-1
  - Then: `base_damage == 1` (defense_mul=0.70 → floori(30 - 100*0.70) = floori(-40) = -40 → max(1, -40) = 1)

- **AC-4 (AC-DC-06 D-6 negative T_def)**: ATK=60, DEF=50, T_def=−30
  - Given: `atk=60, def=50, T_def=-30`
  - When: Stage-1
  - Then: `base_damage == 1` (defense_mul=1.30 → floori(60 - 50*1.30) = floori(-5) = -5 → max(1, -5) = 1)

- **AC-5 (AC-DC-07 D-7 positive T_def)**: ATK=80, DEF=50, T_def=+20
  - Given: `atk=80, def=50, T_def=+20`
  - When: Stage-1
  - Then: `base_damage == 40` (defense_mul=0.80 → floori(80 - 50*0.80) = 40)

- **AC-6 (AC-DC-11 ATK clamp)**: raw_atk values 0, -5, 1, 200 → eff_atk values 1, 1, 1, 200
  - Given: 4 separate test runs, mock returning each value
  - When: Stage-1
  - Then: eff_atk clamped to [1, ATK_CAP] before damage formula

- **AC-7 (AC-DC-12 DEFEND_STANCE on eff_atk=1)**: raw_atk=1, defend_stance_active=true
  - Given: `is_counter=true, defend_stance_active=true, raw_atk=1, eff_def=50`
  - When: Stage-1 applies penalty `floori(1 × 0.60) = 0`, then max(MIN_DAMAGE, 0) recovers to 1, then formula `floori(1 - 50*1.00) = -49` → max(1, -49) = 1
  - Then: `base_damage == 1`

- **AC-8 (AC-DC-13 terrain_def boundary clamp)**: 5 test runs covering T_def ∈ {-31, -30, 0, +30, +31}
  - Given: each T_def
  - When: defense_mul computed
  - Then: defense_mul values 1.30, 1.30, 1.00, 0.70, 0.70 respectively
  - Edge cases: confirm `clampi(T_def, -30, 30)` is applied BEFORE `snappedf` (out-of-range inputs clamped first)

- **AC-9 (AC-DC-15 ATK over cap)**: mock returning 199, 200, 201 → eff_atk = 199, 200, 200
  - Given: 3 separate runs
  - When: clamp applied
  - Then: 201 → 200 (Damage Calc is the last clamp defense)

- **AC-10 (AC-DC-23 floori not int)**: synthetic float intermediate −0.7
  - Given: a contrived test case where `eff_atk - eff_def * defense_mul` lands at -0.7
  - When: `floori(-0.7)` invoked
  - Then: result is -1 (not 0); supplementary: `grep "int(" src/feature/damage_calc/damage_calc.gd` returns 0 matches

- **AC-11 (AC-DC-53 D-8 Formation DEF consumer)**: Infantry FRONT, formation_def_bonus=0.04
  - Given: `atk=82, def=50, T_def=0, FRONT, formation_def_bonus=0.04, no passives` (Infantry; D_mult=0.90 applied in story-005)
  - When: Stage-1 + `eff_def = 50 + floori(50 × 0.04) = 52`; defense_mul=1.00; base = mini(83, max(1, floori(82 - 52*1.00))) = mini(83, 30) = 30
  - Then: Stage-1 returns 30
  - Edge cases: same inputs with `formation_def_bonus=0.0` → eff_def=50, base=mini(83, max(1, 32)) = 32; delta of -2 proves Formation DEF absorbs 2 points (full pipeline assertion in story-005-006)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/damage_calc/damage_calc_test.gd` — Stage 1 + F-DC-3 test functions; must pass on headless CI

**Status**: [x] Test file exists at `tests/unit/damage_calc/damage_calc_test.gd` — 12 new test functions (AC-1..AC-11 + 1 E-1 compound) appended to the story-003 baseline; 37/37 PASS in damage_calc suite, 331/331 PASS in full regression (0 errors / 0 failures / 0 orphans / exit 0).

---

## Dependencies

- Depends on: Story 003 (Stage 0 + DamageCalc class skeleton)
- Unlocks: Story 005 (Stage 2 reads `base_damage` from this story's output)

---

## Completion Notes

**Completed**: 2026-04-26 (PR #59 merged; commit 6ae3047 on main)
**Pre-PR**: PR #58 — story-004 prep (wrapper `raw_atk`/`raw_def` fields + ADR-0012 §8 call-site ownership amendment) merged the same day before implementation began.

**Criteria**: 12/11 PASS (11 ACs + 1 E-1 compound edge case from /code-review qa-tester).
- All 11 ACs covered by 11 dedicated test functions (AC-6, AC-8, AC-9 use parametric `Array[Dictionary]` sub-case loops with `override_failure_message`).
- E-1 (qa-tester recommendation): `raw_atk=0 + defend_stance_active=true` → MIN_DAMAGE=1 — added as `test_stage_1_defend_stance_raw_atk_0_compound_recovers_to_min_damage` to pin the compound clamp-recovery path against future refactors.

**Pre-resolved decisions (orchestrator authorization, recorded for audit)**:
1. Hardcoded constants (`BASE_CEILING=83`, `MIN_DAMAGE=1`, `ATK_CAP=200`, `DEF_CAP=105`, `DEFEND_STANCE_ATK_PENALTY=0.40`) per §Implementation Notes line 63 — `BalanceConstants` wrapper does not exist yet; story-006 grep-lint AC-DC-48 will catch and force migration when ADR-0006 lands. TODO(story-006) inline.
2. `TerrainEffect.max_defense_reduction()` ADR-0008 shared accessor used for the defense_mul cap (no hardcoded `30`).
3. DEFEND_STANCE applied as `(1.0 - DEFEND_STANCE_ATK_PENALTY)` matching AC-DC-12 expected output — resolved the spec's flagged ambiguity at §Implementation Notes line 55. Doc-comments at `damage_calc.gd:25-28, 123-127` document the semantic so future readers don't re-litigate.

**Deviations**: None blocking. Three documented advisories:
- Hardcoded constants (covered by inline TODO + future story-006 migration grep-lint).
- F-1 (qa-tester MAJOR policy flag): AC-10 literal-grep test is future-hostile to Stages 2/3/4 additions in `damage_calc.gd`. **Surface to qa-lead at `/story-readiness story-005`** with three options on the table (accept brittleness as enforcement / narrow grep scope per-stage / move to `tools/ci/` lint script). Not a story-004 defect.
- G-16 codification candidate (gdscript-specialist): untyped `Array` of Dictionary literals in parametric tests should be `Array[Dictionary]`. Pattern-stable across this story's 3 occurrences (now corrected inline at `damage_calc_test.gd:417, 487, 520`). Worth batching with future tech-debt sweep into `.claude/rules/godot-4x-gotchas.md`.

**Deferred to future stories** (rationale documented):
- N-1 (gdscript-specialist NIT): `as ResolveResult.AttackType` enum-cast time-bomb at `damage_calc.gd:82` — affects Stage 2/3/4 ResolveResult construction sites too; story-006 ResolveResult-construction scope.
- E-2 (qa-tester advisory): `formation_def_bonus` out-of-range guard not tested — correctly out of scope per Formation Bonus contract (upstream-capped per F-FB-3).
- N-2 (gdscript-specialist NIT): FileAccess CI-only comment on AC-10 test — low-value; AC-DC-23 reference + test name already convey intent.
- E-3 (qa-tester advisory): `terrain_evasion=0 + defend_stance_active=true` non-counter compound — Stage 0/1 paths independent; AC-7 covers via counter shortcut.

**CI catch-and-fix during implementation**: 1 iteration. AC-10 literal-grep test caught `int(` substring inside 3 explanatory doc-comments on first headless run. Resolved by rephrasing ("the truncating int conversion"). No logic change. Process insight: future docs/comments in `damage_calc.gd` must avoid the literal `int(` substring — codification candidate alongside G-16.

**Test Evidence**: Logic story — `tests/unit/damage_calc/damage_calc_test.gd` (24 functions; 12 new for story-004 + 1 E-1 compound; 37/37 PASS; 0 orphans; exit 0). Full regression 331/331 PASS.

**Code Review**: Standalone `/code-review` (lean dual: gdscript-specialist + qa-tester) → APPROVED WITH SUGGESTIONS APPLIED. 3 inline edits applied (S-1 tighter helper signature, S-2 `Array[Dictionary]` typing × 3, E-1 compound test); 5 deferred with rationale (N-1, N-2, F-1, E-2, E-3). Per-story dev-time gate review skipped per lean mode (`production/review-mode.txt`).

**Files delivered**:
- M `src/feature/damage_calc/damage_calc.gd` (+99 LoC; 5 const declarations + 4 private static helpers; replaces story-003 `TODO(story-004)` placeholder)
- M `tests/unit/damage_calc/damage_calc_test.gd` (+355 LoC; 12 new test functions appended to story-003 baseline)

**Damage-calc epic progress**: 3/10 → 4/10. Vertical-slice 4/7 done (next: 005 → 006 → 007 = first-playable damage roll demo).
**Sprint 1**: 7 stories closed (S1-01..S1-05 Must-Haves + S1-08 + damage-calc 002/003); story-004 is 4th damage-calc story but remains tracked via EPIC.md per the vertical-slice replan note in `sprint-status.yaml` S1-06 (which references "damage-calc stories 002-007").

**Unlocks**: damage-calc story-005 (Stage 2 — direction × passive multiplier composition; reads `base_damage` from this story's output).
