# Story 007: F-GB-PROV retirement + entities.yaml damage_resolve registration + Grid Battle integration tests

> **Epic**: damage-calc
> **Status**: Ready
> **Layer**: Feature
> **Type**: Integration
> **Manifest Version**: 2026-04-20
> **Estimate**: 4-5 hours (cross-doc same-patch obligation: GDD edit + entities.yaml schema + 4 integration tests + CI grep gate)

## Context

**GDD**: `design/gdd/damage-calc.md`, `design/gdd/grid-battle.md` (sole caller GDD — receives an edit this story)
**Requirement**: `TR-damage-calc-003` (Grid Battle direct-call interface), `TR-damage-calc-009` (F-GB-PROV retirement)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0012 Damage Calc
**ADR Decision Summary**: Same-patch obligation — F-GB-PROV provisional formula REMOVED from `grid-battle.md` §CR-5 Step 7 in the same patch as `entities.yaml` `damage_resolve` registration. AC-DC-44 CI grep gate enforces both sides ship together. Grid Battle is the sole caller (CR-1, AC-DC-42 call-count discipline) and the orchestrator that invokes `hp_status.apply_damage()` on HIT — Damage Calc has zero outbound calls into HP/Status mutation API.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: This story is primarily cross-doc + integration tests (no Damage Calc source code changes — pipeline complete after story-006). Grid Battle integration tests use the same Damage Calc binary that stories 003-006 produce. The integration tests stub Grid Battle via mock test fixtures (Grid Battle GDD is in MAJOR REVISION per `damage-calc.md` line 132 + `architecture-traceability.md`; full Grid Battle implementation is a future Feature epic).

**Control Manifest Rules (Feature layer)**:
- Required: F-GB-PROV must NOT exist in `design/` after this patch (AC-DC-44 grep gate)
- Required: `entities.yaml` damage_resolve formula registration ships in the same patch
- Required: 11 constants in `entities.yaml` carry `referenced_by: [damage-calc.md]` audit trail (per ADR-0012 §Migration Plan + `damage-calc.md` Bidirectional Citation Audit)
- Forbidden: Grid Battle integration tests calling DamageCalc internals — must use the public `resolve()` entry point only

---

## Acceptance Criteria

*From ADR-0012 §9 + AC-DC-29/31/42/43/44:*

- [ ] **AC-DC-44 (F-GB-PROV grep gate)**: `grid-battle.md` §CR-5 Step 7 removed F-GB-PROV provisional formula; cites `damage-calc.md` §F-DC-1; `grep -r "F-GB-PROV" design/gdd/grid-battle.md src/` returns 0 matches; CI workflow integrates this grep as blocking lint
- [ ] **`entities.yaml` `damage_resolve` registration**: formula registered with full type-signature in YAML schema; 9 consumed constants (`BASE_CEILING, DAMAGE_CEILING, COUNTER_ATTACK_MODIFIER, MIN_DAMAGE, MAX_DEFENSE_REDUCTION, MAX_EVASION, ATK_CAP, DEF_CAP, DEFEND_STANCE_ATK_PENALTY`) + 2 owned new (`CHARGE_BONUS=1.20, AMBUSH_BONUS=1.15`) + 1 owned cap (`P_MULT_COMBINED_CAP=1.31`) all registered; each consumed constant has `referenced_by: [damage-calc.md]` field added
- [ ] **AC-DC-29 (EC-DC-17 dead defender gated upstream)**: integration test confirms Damage Calc accepts HP=0 defender and returns valid HIT (NOT MISS); the dead-defender pre-condition gate is Grid Battle's, not Damage Calc's. Test path: `tests/integration/damage_calc/damage_calc_integration_test.gd::test_dead_defender_gated_by_grid_battle`
- [ ] **AC-DC-31 (EC-DC-22 ambush dead defender gated upstream)**: integration test confirms Grid Battle blocks the ambush call before resolve() when defender is dead; Damage Calc has no dead-unit guard
- [ ] **AC-DC-42 (resolve call count exact)**: 3 scenarios — (1) primary HIT with counter-eligible defender → call count = 2 (primary + counter); (2) primary HIT with non-counter-eligible defender → call count = 1; (3) primary MISS → call count = 1 (no counter on MISS per CR-2). All counts EXACT (assert_eq, not assert_at_least)
- [ ] **AC-DC-43 (apply_damage valid on HIT, AoE coverage)**: 4 scenarios — (a) single HIT → 1 apply_damage call with `resolved_damage ≥ 1`; (b) single MISS → 0 apply_damage calls; (c) 6-target AoE all HIT → exactly 6 apply_damage calls each with `resolved_damage ≥ 1`; (d) 6-target AoE with 2 MISS → exactly 4 apply_damage calls
- [ ] CI workflow integrates AC-DC-44 grep as a blocking lint step (failure if F-GB-PROV reappears post-merge)

---

## Implementation Notes

*Derived from ADR-0012 §9 + Migration Plan + damage-calc.md §Cross-system Invariants Locked Here:*

- **Same-patch obligation pattern** (per ADR-0012 R-5 mitigation): all 3 cross-doc edits ship in this PR — `grid-battle.md` § CR-5 Step 7 rewrite + `entities.yaml` damage_resolve registration + 9 constants `referenced_by` audit + `tests/integration/damage_calc/damage_calc_integration_test.gd` test file.
- **`grid-battle.md` §CR-5 Step 7 rewrite**: replace F-GB-PROV pseudocode block with citation: `"Damage resolution: per damage-calc.md §F-DC-1 master pipeline. Call: `var result := DamageCalc.resolve(attacker_ctx, defender_ctx, modifiers)`. On HIT, call `hp_status.apply_damage(defender.unit_id, result.resolved_damage, result.attack_type, result.source_flags)`. On MISS, no apply_damage call (per AC-DC-43)."`. The exact wording can mirror the existing grid-battle.md citation style for ADR-0001.
- **`entities.yaml` damage_resolve registration**: schema follows `entities.yaml` existing patterns (mirrors terrain_config.json registration in story-007 of terrain-effect epic). Required fields: formula name, parameters (4 typed RefCounted wrappers per ADR-0012 §2), return type (ResolveResult), referenced_by audit. Each of the 9 consumed constants gets `referenced_by: [damage-calc.md]` appended (or moved to multi-element list if already referenced).
- **`CHARGE_BONUS=1.20, AMBUSH_BONUS=1.15, P_MULT_COMBINED_CAP=1.31` new constants**: registered with full schema (current value, safe range per damage-calc.md §Tuning Knobs, owner = damage-calc.md, referenced_by = damage-calc.md). Locked-not-tunable for P_MULT_COMBINED_CAP.
- **Grid Battle mock pattern** (integration tests): per architecture.md + `damage-calc.md` line 132 (Grid Battle GDD in MAJOR REVISION), full Grid Battle is not yet implemented. Tests use a minimal `GridBattleStub` test helper that orchestrates resolve() calls + apply_damage() invocations + counter-eligibility gate, matching the existing integration-test fixture pattern from gamebus epic story-007 (`tests/integration/core/scene_handoff_timing_test.gd` precedent).
- **AC-DC-42 call-count test**: mock DamageCalc with a wrapper that increments a counter on each `resolve()` call; run 3 scenarios via the GridBattleStub; assert exact call counts.
- **AC-DC-43 AoE coverage test**: simulate Grid Battle dispatching to N targets via the GridBattleStub; assert apply_damage call count exactly equals N for all-HIT, N-misses for partial-MISS scenarios.
- **AC-DC-29 dead-defender test**: construct a defender with HP=0 (mock hp_status returning 0 for HP); call DamageCalc.resolve() with non-zero ATK; assert valid HIT returned (NOT MISS — Damage Calc has no HP check). Then verify GridBattleStub's pre-condition gate fires before resolve() in production code path (test the gate, not Damage Calc's behavior post-gate).
- **AC-DC-31 ambush dead-defender**: variation of AC-DC-29 with passive_ambush + Scout class; same pattern — Grid Battle gates, Damage Calc does not.
- **CI workflow update**: add AC-DC-44 grep step. Pattern: mirror PR #43 (terrain-effect story-008 perf baseline) static-lint additions. Step name: `verify_fgb_prov_removed`. Command: `! grep -r "F-GB-PROV" design/gdd/grid-battle.md src/`. Failure modes: presence of F-GB-PROV → CI fails; absence → step passes.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: completed `damage_calc.gd` pipeline (this story consumes the completed pipeline; no source code changes in `damage_calc.gd`)
- Story 008: determinism + engine-pin tests + cross-platform matrix (different test category)
- Future Grid Battle Feature epic: full Grid Battle implementation including production-grade pre-condition gates (this story's GridBattleStub is a test-only stand-in)

---

## QA Test Cases

*Authored from ADR-0012 §9 + AC-DC-29/31/42/43/44 directly. Developer implements against these.*

- **AC-1 (AC-DC-44 F-GB-PROV grep gate)**:
  - Given: post-patch state (story-007 PR merged)
  - When: `grep -r "F-GB-PROV" design/gdd/grid-battle.md src/`
  - Then: returns 0 matches; supplementary: `grep "damage_resolve" assets/data/balance/entities.yaml` returns ≥ 1 match (formula registered)
  - Edge cases: CI workflow has the grep as a step that fails the build if F-GB-PROV reappears in any future PR

- **AC-2 (entities.yaml damage_resolve registration)**:
  - Given: post-patch `entities.yaml`
  - When: parse YAML; locate `damage_resolve` formula entry
  - Then: formula has fields: name, parameters (4 typed wrappers), return_type, owner, referenced_by; supplementary: 9 consumed constants each have `referenced_by: [damage-calc.md, ...]` audit trail; CHARGE_BONUS/AMBUSH_BONUS/P_MULT_COMBINED_CAP registered with current values

- **AC-3 (AC-DC-29 dead defender gated upstream)**:
  - Given: defender mock with HP=0; non-zero ATK; standard FRONT no-passives setup
  - When: `DamageCalc.resolve(...)`
  - Then: result is HIT with valid resolved_damage; NOT MISS (Damage Calc does not check HP)
  - Setup: `GridBattleStub`-based integration test verifies Grid Battle's pre-condition gate fires BEFORE resolve() in production path (separate assertion against the stub's call ordering)

- **AC-4 (AC-DC-31 ambush dead defender gated upstream)**:
  - Given: Scout attacker with passive_ambush + round=3 + dead defender (HP=0)
  - When: GridBattleStub orchestrates the ambush attempt
  - Then: stub's pre-condition gate blocks the call; DamageCalc.resolve() never invoked; assertion: `resolve_call_count == 0`
  - Edge cases: live defender with same setup → ambush proceeds normally; resolve_call_count == 1

- **AC-5 (AC-DC-42 resolve call count — primary + counter)**:
  - Given: GridBattleStub with counter-eligible defender + primary HIT scenario
  - When: stub orchestrates the attack + counter
  - Then: `resolve_call_count == 2` (primary + counter); both calls successful
  - Edge cases: same setup with non-counter-eligible defender → call count = 1; primary MISS scenario → call count = 1 (no counter on MISS per CR-2)

- **AC-6 (AC-DC-43 apply_damage valid on HIT, AoE)**:
  - Given: 4 sub-scenarios — single HIT, single MISS, 6-AoE all-HIT, 6-AoE 4-HIT-2-MISS
  - When: GridBattleStub dispatches each scenario
  - Then: apply_damage call counts {1, 0, 6, 4} respectively; each call's `resolved_damage ≥ 1`; MISS path never invokes apply_damage
  - Edge cases: AoE with 0 valid targets (all dead/out-of-range) → 0 resolve() calls + 0 apply_damage calls; AoE with all MISS → 6 resolve() calls + 0 apply_damage calls

---

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/damage_calc/damage_calc_integration_test.gd` — must exist and pass on headless CI; CI workflow includes AC-DC-44 grep gate; `grid-battle.md` + `entities.yaml` edits ship in this story's PR.

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 006 (completed `damage_calc.gd` pipeline) + Story 001 (CI infrastructure for grep-gate integration)
- Unlocks: Future Grid Battle Feature epic (this story's GridBattleStub becomes a reference for the production Grid Battle implementation's call-count + AoE dispatch contracts)
