# Story 006: Stage 3-4 — raw damage + counter halve + DAMAGE_CEILING + ResolveResult construction + source_flags + AC-DC-51 bypass-seam

> **Epic**: damage-calc
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Estimate**: 5-6 hours (Stage 3-4 pipeline + final cap + counter halve + ResolveResult + source_flags semantics + AC-DC-51 bypass-seam test + static lints + 10 ACs — final-pipeline integration story)

## Context

**GDD**: `design/gdd/damage-calc.md`
**Requirement**: `TR-damage-calc-001` (sole entry point), `TR-damage-calc-003` (no apply_damage), `TR-damage-calc-004` (signal-free), `TR-damage-calc-006` (tuning constants), `TR-damage-calc-012` (source_flags semantics)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012 Damage Calc
**ADR Decision Summary**: Stage 3 is raw damage F-DC-6 (`raw = floori(base × D_mult × P_mult)` with `MIN_DAMAGE` floor + `DAMAGE_CEILING = 180` ceiling). Stage 4 is counter halve F-DC-7 (`resolved_damage = floori(raw × COUNTER_ATTACK_MODIFIER)` if `is_counter` else `raw`, with `MIN_DAMAGE` floor). `ResolveResult.hit/miss` constructed with always-NEW `Array[StringName]` for source_flags (per ADR-0012 §12); never mutate caller's array. Static-lint AC-DC-34/35 enforced on completed `damage_calc.gd`. AC-DC-51 bypass-seam test exercises the StringName-literal release-build defense.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `Array[StringName].duplicate()` returns typed result when assigned to a typed local (per godot-specialist AF-3 + ADR-0012 §12 pattern). `floori()` round-toward-negative-infinity. `&"foo"` StringName literal ≠ `"foo"` String — the `in` operator on `Array[StringName]` rejects String elements at element comparison level (the AC-DC-51 release-build defense).

**Control Manifest Rules (Feature layer)**:
- Required: `source_flags` is ALWAYS a fresh `Array[StringName]` constructed via `modifiers.source_flags.duplicate()` then appended (per ADR-0012 §12); never mutates caller
- Required: All flag literals use `&"foo"` StringName syntax (release-build defense per AC-DC-51)
- Required: All tuning constants read via `DataRegistry.get_const()` or `BalanceConstants` wrapper — `DAMAGE_CEILING=180`, `COUNTER_ATTACK_MODIFIER=0.5`, `MIN_DAMAGE=1`, plus `CHARGE_BONUS=1.20` and `AMBUSH_BONUS=1.15` (from story-005 references — registry read verified here via AC-DC-48)
- Forbidden: `signal` declarations or `connect()` calls in `damage_calc.gd` (AC-DC-34 static lint enforced this story)
- Forbidden: `apply_damage` or `hp_status` write-path calls in `damage_calc.gd` (AC-DC-35 static lint enforced this story)
- Forbidden: `Dictionary(` or standalone `{` constructor inside reachable `resolve()` body except `build_vfx_tags` helper (AC-DC-41 static lint — verified in story-008)

---

## Acceptance Criteria

*From `damage-calc.md` §F-DC-6 + §F-DC-7 + §CR-9..CR-12 + AC-DC-08/17/20/24/33-36/48/51:*

- [ ] **AC-DC-08 (D-8 DEFEND_STANCE counter)**: ATK=120, defend_stance_active=true, is_counter=true, DEF=40, FRONT, T_def=0 → eff_atk=72, base=32, D_mult=1.00, P_mult=1.00 (Charge/Ambush blocked on counter), raw=32, counter_final=floori(32×0.5)=16
- [ ] **AC-DC-17 (EC-DC-10 degenerate stack)**: counter+DEFEND_STANCE+min-ATK → final = 1 (MIN_DAMAGE holds end-to-end through every floor in the pipeline)
- [ ] **AC-DC-20 (EC-DC-14 RNG call counts stable)**: snapshot RNG before resolve(); restore; call again; outputs bit-identical. Call counts: non-counter=1, counter=0, skill_stub=0 (verifies story-003 + this story together)
- [ ] **AC-DC-24 (EC-DC-23 counter halve min raw)**: synthetic raw=1 → `floori(1×0.5)=0` → max(MIN_DAMAGE, 0) = 1 (F-DC-7 floor catches)
- [ ] **AC-DC-33 (sole entry point)**: `damage_calc.gd` exports exactly 1 public function `resolve(...) -> ResolveResult`; static grep returns 1 match for non-prefixed `func ` declarations
- [ ] **AC-DC-34 (zero signals)**: static grep on `damage_calc.gd` for `signal ` and `emit_signal` returns 0 matches; CI-lint integrated
- [ ] **AC-DC-35 (no apply_damage)**: static grep on `damage_calc.gd` for `apply_damage` and `hp_status` write-path returns 0 matches; CI-lint integrated
- [ ] **AC-DC-36 (vfx_tags populated)**: for each provenance flag {charge, ambush, counter, terrain_penalty}, assert tag present in `ResolveResult.HIT.vfx_tags` when condition fires, absent when does not. Test all 8 combinations of {charge, ambush, counter}.
- [ ] **AC-DC-48 (TUNING knobs from registry)**: grep `1.20` and `1.15` literal floats in `damage_calc.gd` returns 0 matches; unit test mocks `BalanceConstants.get_const("CHARGE_BONUS") -> 1.30`, runs D-3 fixture, asserts resolved_damage changes accordingly (proves live registry read)
- [ ] **AC-DC-51 (StringName boundary bypass-seam)**: per ADR-0012 R-9 mitigation — direct private-helper call with locally-constructed untyped `Array` containing `String` elements; assert `&"passive_charge" in arr` returns false; P_mult=1.00; positive case (`Array[StringName]` with `&"passive_charge"`) returns P_mult=1.20 through normal `resolve()` entry. Test file extends `GdUnitTestSuite` (Node base) for `@onready` decorator support.
- [ ] `source_flags` always-new-Array semantics verified: re-call resolve() with same modifiers → no flag accumulation across calls
- [ ] `damage_calc.gd` total LoC ≈ 250-400 (sanity check; not blocking) — F-DC-1 master pipeline + 6 private helpers ((`_evasion_check`, `_stage_1_base_damage`, `_direction_multiplier`, `_passive_multiplier`, `_stage_2_raw_damage`, `_counter_reduction`) + invariant guards + factory wrappers

---

## Implementation Notes

*Derived from ADR-0012 §1, §3, §4, §6, §12 + Implementation Guidelines + damage-calc.md §F-DC-1/F-DC-6/F-DC-7:*

- **Stage 3 raw damage** (CR-9 + F-DC-6): `var raw := floori(base * D_mult * P_mult); raw = mini(DAMAGE_CEILING, max(MIN_DAMAGE, raw))` where `DAMAGE_CEILING = 180`, `MIN_DAMAGE = 1`. Note: `raw` is the value BEFORE counter halve.
- **Stage 4 counter halve** (CR-10 + F-DC-7): `var resolved := raw if not modifiers.is_counter else max(MIN_DAMAGE, floori(raw * COUNTER_ATTACK_MODIFIER))` where `COUNTER_ATTACK_MODIFIER = 0.5`. AC-DC-24 verified by raw=1 → `floori(1×0.5)=0` → max(1, 0)=1.
- **`source_flags` always-new-Array** (CR-11 + ADR-0012 §12 + AC-DC-36):
  ```gdscript
  var out_flags: Array[StringName] = modifiers.source_flags.duplicate()
  if modifiers.is_counter:
      out_flags.append(&"counter")
  if charge_fired:
      out_flags.append(&"charge")
  if ambush_fired:
      out_flags.append(&"ambush")
  if defender.terrain_def > 0:
      out_flags.append(&"terrain_penalty")
  # ... etc.
  ```
  The `.duplicate()` on `Array[StringName]` returns typed result when assigned to typed local (per godot-specialist AF-3). Never mutates `modifiers.source_flags`.
- **`vfx_tags` derivation** (AC-DC-36): `vfx_tags` is a separate `Array[StringName]` derived from the same provenance flags. Per ADR-0012 §Implementation Guidelines #5, `build_vfx_tags(...)` is the SINGLE helper allowed to allocate Dictionary inside `resolve()`'s call graph (composes from active passives + counter flag + provenance). Static lint AC-DC-41 excludes this helper.
- **`ResolveResult.hit/miss` construction**:
  ```gdscript
  return ResolveResult.hit(resolved, modifiers.attack_type, out_flags, vfx_tags)
  ```
  or
  ```gdscript
  return ResolveResult.miss([&"evasion"])  # Stage 0 evasion path
  ```
- **`COUNTER_ATTACK_MODIFIER`, `DAMAGE_CEILING`, `MIN_DAMAGE`, `CHARGE_BONUS`, `AMBUSH_BONUS`** constants: read via `BalanceConstants.get_const(key)` (provisional wrapper) or `DataRegistry.get_const(key)` (post-ADR-0006). NEVER hardcoded — AC-DC-48 grep gate enforces.
- **AC-DC-51 bypass-seam test pattern** (per ADR-0012 §2 + §10 #4 + R-9 + damage-calc.md AC-DC-51 rev 2.6):
  - Test class: `extends GdUnitTestSuite` (Node base) for `@onready` decorator support per ADR-0012 §10 #4 — required ONLY for this AC-DC-51(b) test class; other tests may use the lighter RefCounted base.
  - Test exposes `@onready var _passive_mul := Callable(DamageCalc, "_passive_multiplier_for_test")` — a test-only entry point on `DamageCalc` that accepts an external passives Array parameter overriding the attacker's own.
  - Test constructs a Cavalry AttackerContext via `.make()` with empty `passives`.
  - Test constructs a local `var wrong_typed_passives: Array = ["passive_charge"]` (untyped Array, String elements).
  - Test calls `_passive_mul.call(attacker, defender, modifiers, wrong_typed_passives)`.
  - Inside `_passive_multiplier_for_test`, the body uses `if PASSIVE_CHARGE in passives_arg` where `PASSIVE_CHARGE: StringName = &"passive_charge"`.
  - Assert `P_mult == 1.00` — because `&"passive_charge" in ["passive_charge"]` returns `false` (StringName ≠ String comparison).
  - Positive case: same setup with `Array[StringName]` typed `[&"passive_charge"]` through normal `resolve()` entry — assert `P_mult == 1.20`.
- **AC-DC-33/34/35 static lints**: integrate as CI grep steps in this story's PR. Pattern matches PR #43 (terrain-effect story-008) static-lint additions to `.github/workflows/tests.yml`.
- **AC-DC-48 registry-read test**: mock `BalanceConstants.get_const("CHARGE_BONUS") -> 1.30` (instead of 1.20); run D-3 fixture; assert `resolved_damage` changes from 59 (with 1.20) to `floori(30×1.64×1.30) = 63` (with 1.30) — proves live registry read, not cached literal.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 007: F-GB-PROV retirement + entities.yaml damage_resolve registration + Grid Battle integration tests (AC-DC-29/31/42/43/44)
- Story 008: AC-DC-39 RNG replay determinism (full-pipeline level test) + AC-DC-41 Dictionary-alloc static lint + AC-DC-49/50 engine-pin
- Story 009: AC-DC-45/46/47 accessibility UI tests
- Story 010: AC-DC-40(a)/(b) performance baseline

---

## QA Test Cases

*Authored from damage-calc.md §F-DC-6/F-DC-7 + AC ranges directly. Developer implements against these.*

- **AC-1 (AC-DC-08 D-8 DEFEND_STANCE counter)**:
  - Given: `atk=120, def=40, FRONT, T_def=0, defend_stance_active=true, is_counter=true`
  - When: full pipeline
  - Then: eff_atk=72, base=32, D_mult=1.00 (Cavalry FRONT), P_mult=1.00 (counter blocks Charge/Ambush; no Rally/Formation), raw=32, counter_final=floori(32×0.5)=16; HIT(resolved_damage=16)

- **AC-2 (AC-DC-17 EC-DC-10 degenerate stack)**:
  - Given: `is_counter=true, defend_stance_active=true, raw_atk=1, eff_def=50, T_def=0`
  - When: full pipeline
  - Then: HIT(resolved_damage=1) — MIN_DAMAGE floor catches at every stage (Stage-1 base=1, Stage-3 raw=1, Stage-4 counter_final=max(1, floori(1×0.5))=1)

- **AC-3 (AC-DC-20 EC-DC-14 RNG call counts + replay)**:
  - Given: RNG instance, snapshot before resolve()
  - When: 4 paths × {non-counter, counter, skill_stub, MISS via evasion}
  - Then: call counts {non-counter=1, counter=0, skill_stub=0, MISS_evasion=1 (rolled)}; restore RNG snapshot, re-call → bit-identical output for all four paths
  - Edge cases: across 100 iterations of each path, RNG advance count is exactly path × call

- **AC-4 (AC-DC-24 EC-DC-23 counter halve min raw)**:
  - Given: synthetic raw=1 entering counter_reduction()
  - When: Stage 4 applies
  - Then: returns 1 (not 0); MIN_DAMAGE floor in F-DC-7 catches `floori(1×0.5)=0`
  - Edge cases: raw=2 → counter_final=1 (also catches at floor); raw=3 → counter_final=1 (floori(1.5)=1)

- **AC-5 (AC-DC-33 sole entry point)**:
  - Given: completed `damage_calc.gd`
  - When: `grep -c "^func [a-z]" src/feature/damage_calc/damage_calc.gd | grep -v "^_"` (or equivalent lint)
  - Then: returns exactly 1 (the `resolve` public function); all helpers are `_`-prefixed private

- **AC-6 (AC-DC-34 zero signals)**:
  - Given: completed `damage_calc.gd`
  - When: `grep -E "(signal |emit_signal)" src/feature/damage_calc/damage_calc.gd`
  - Then: returns 0 matches; CI workflow includes this grep as a blocking lint step

- **AC-7 (AC-DC-35 no apply_damage)**:
  - Given: completed `damage_calc.gd`
  - When: `grep -E "(apply_damage|hp_status\\.)" src/feature/damage_calc/damage_calc.gd`
  - Then: returns 0 matches; CI workflow includes this grep as a blocking lint step

- **AC-8 (AC-DC-36 vfx_tags populated)**:
  - Given: 8 test scenarios — all combinations of {charge_fires, ambush_fires, counter_fires}
  - When: each `resolve()`
  - Then: `result.vfx_tags` contains `&"charge"` iff charge fired; `&"ambush"` iff ambush fired; `&"counter"` iff is_counter; `&"terrain_penalty"` iff terrain_def > 0
  - Edge cases: all-flags-firing case has vfx_tags = [`&"charge"`, `&"counter"`, `&"terrain_penalty"`] (Charge+counter is structurally impossible — but if a test bypasses via subclass, only `&"counter"` and `&"terrain_penalty"` set since Charge guard blocks)

- **AC-9 (AC-DC-48 TUNING knobs from registry)**:
  - Given: 2 test runs with mocked `BalanceConstants.get_const("CHARGE_BONUS")` returning 1.20 vs 1.30
  - When: D-3 fixture runs
  - Then: resolved_damage values 59 vs 63 respectively; supplementary: grep `1\\.20\\|1\\.15` in `damage_calc.gd` returns 0 matches

- **AC-10 (AC-DC-51 StringName bypass-seam)**:
  - Given: `var wrong_typed: Array = ["passive_charge"]` (untyped Array, String element); empty `attacker.passives`; Cavalry charge_active=true
  - When: `_passive_mul.call(attacker, defender, modifiers, wrong_typed)` (test-only entry)
  - Then: P_mult == 1.00 (StringName literal `&"passive_charge"` does not match String `"passive_charge"` in array)
  - Edge cases: positive case — `attacker.passives = [&"passive_charge"]` (typed array, StringName element) through normal `resolve()` → P_mult == 1.20

- **AC-11 (source_flags always-new-Array)**:
  - Given: `modifiers.source_flags = [&"original"]` (caller's array)
  - When: 100 calls to `resolve(atk, def, modifiers)`
  - Then: `modifiers.source_flags.size() == 1` after every call (caller's array unchanged); each `result.source_flags` has unique array identity (not the same instance as `modifiers.source_flags`)

---

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/damage_calc/damage_calc_test.gd` — Stage 3-4 + AC-DC-51 bypass-seam test functions; CI-lint AC-DC-33/34/35 integrated into `.github/workflows/tests.yml`. Must pass on headless CI.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005 (Stage 2 D_mult + P_mult feed Stage 3) + Story 001 (CI infrastructure for static-lint integration)
- Unlocks: Story 007 (Grid Battle integration tests run against the completed pipeline) + Story 008 (determinism + engine-pin tests run on the completed pipeline) + Story 009 (UI accessibility tests against full resolve()) + Story 010 (perf baseline against full resolve())
