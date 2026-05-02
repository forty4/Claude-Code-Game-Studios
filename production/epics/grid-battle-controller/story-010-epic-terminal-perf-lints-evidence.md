# Story 010: Epic terminal — perf baseline + 3 lints + 6 BalanceConstants + epic close

> **Epic**: Grid Battle Controller | **Status**: Ready | **Layer**: Feature | **Type**: Config/Data | **Estimate**: 3h
> **ADR**: ADR-0014 §11 + Performance Implications + Migration Plan §13

## Acceptance Criteria

- [ ] **AC-1** Performance baseline test `tests/performance/feature/grid_battle/grid_battle_controller_perf_test.gd` with 4 tests:
  - `test_handle_input_action_under_0_05ms` — 1000-iteration p99 < 0.05ms (per-event signal handler cost)
  - `test_resolve_attack_under_0_5ms` — full chain (controller multipliers → DamageCalc.resolve → HPStatusController.apply_damage) p99 < 0.5ms
  - `test_100_synthetic_battle_actions_under_100ms` — full-throughput (avg < 1ms per action including all 7 backend invocations)
  - `test_setup_under_0_01ms_for_8_units` — DI setup() with 8-unit roster < 0.01ms
- [ ] **AC-2** `tools/ci/lint_grid_battle_controller_signal_emission_outside_battle_domain.sh`: greps `src/feature/grid_battle/grid_battle_controller.gd` for `GameBus\..*\.emit\(` calls; exits 1 if any found (per ADR-0014 forbidden_pattern — controller emits 5 LOCAL signals only, NOT GameBus signals)
- [ ] **AC-3** `tools/ci/lint_grid_battle_controller_static_state.sh`: greps for `^static var ` declarations in controller source; exits 1 if any found (battle-scoped Node MUST NOT have static state per battle_runtime_state ownership; mirrors hp_status_static_state + turn_order_static_state precedent)
- [ ] **AC-4** `tools/ci/lint_grid_battle_controller_external_combat_math.sh`: greps `src/` (excluding `grid_battle_controller.gd` + `damage_calc.gd` + `tests/helpers/`) for `formation_atk_bonus|attack_angle|adjacent_command_aura|_count_adjacent_allies|_attack_angle|_has_adjacent_command_aura` keywords; exits 1 if any found in unauthorized files (migration safety rail for future Formation Bonus ADR cutover per ADR-0014 R-2)
- [ ] **AC-5** `tools/ci/lint_balance_entities_grid_battle_controller.sh`: validates 6 BalanceConstants keys present in `assets/data/balance/balance_entities.json`:
  - `MAX_TURNS_PER_BATTLE = 5` (chapter-prototype proven default; 5-turn limit per ADR-0014 §7)
  - 5 fate-condition thresholds (placeholder; final ownership may shift to Destiny Branch ADR sprint-6): `FATE_TANK_HP_THRESHOLD = 0.60` + `FATE_ASSASSIN_KILLS_THRESHOLD = 2` + `FATE_REAR_ATTACKS_THRESHOLD = 2` + `FATE_FORMATION_TURNS_THRESHOLD = 3` + `FATE_BOSS_KILLED_REQUIRED = 1` (chapter-prototype values)
- [ ] **AC-6** All 4 lint scripts (AC-2..AC-5) chmod +x + wired into `.github/workflows/tests.yml` per existing pattern (after camera epic 5 lints from S4-02)
- [ ] **AC-7** `ResolveModifiers` Resource extension verified shipped in story-005 same-patch — 3 new fields (`formation_atk_bonus: float = 0.0`, `angle_mult: float = 1.0`, `aura_mult: float = 1.0`) present + back-compat to existing damage-calc tests
- [ ] **AC-8** `production/qa/evidence/grid_battle_controller_verification_summary.md` epic-terminal rollup doc lists: 5 controller-LOCAL signals declared correctly; 4 lint scripts PASS; cross-ADR audit (story-009) outcome; per-event perf budget compliance verified
- [ ] **AC-9** TD-057 status final per story-009 outcome: either RESOLVED (false alarm) or RESOLVED (TurnOrderRunner retrofit). Logged in `docs/tech-debt-register.md`
- [ ] **AC-10** Regression baseline maintained: full GdUnit4 suite passes ≥782 cases (757 + ~25 from grid-battle-controller test files) / 0 errors / 0 failures / 0 orphans / Exit 0; **final epic baseline ≥785 cases**
- [ ] **AC-11** EPIC.md updated: Status `Ready` → `Complete (2026-MM-DD)`; Stories table populated 10/10; final test baseline + commit ref recorded
- [ ] **AC-12** `production/epics/index.md` updated: Feature layer 2/13 → 3/13 (grid-battle-controller Complete)

## Implementation Notes

*Derived from ADR-0014 §11 + Performance Implications + camera epic story-007 epic-terminal precedent:*

1. **Perf test pattern** (mirrors damage-calc story-010 + hp-status story-008 + turn-order story-007 + camera epic perf-test):
   ```gdscript
   # tests/performance/feature/grid_battle/grid_battle_controller_perf_test.gd
   extends GdUnitTestSuite
   func test_handle_input_action_under_0_05ms() -> void:
       # Setup: stubbed deps + simple battle fixture
       # Run 1000 iterations of synthetic action dispatch + measure p99
       # Assert p99 < 0.05ms
   ```
   Note: `SKIP_PERF_BUDGETS=1` env var (per `.github/workflows/tests.yml` line 110 precedent) skips assertions on headless Linux runners — perf tests run but don't gate CI on flaky timings. Reference-hardware validation moves to `perf-nightly.yml` (TBD).

2. **5 fate-condition thresholds ownership**: chapter-prototype has these inline in `chapter.gd` const block. ADR-0014 §0 placeholder text says "may shift to Destiny Branch ADR (sprint-6)". Story-010 SHIPS the placeholders in BalanceConstants for MVP; if Destiny Branch ADR claims ownership at sprint-6, the 5 keys can move to a `destiny/` namespace within balance_entities.json (additive — doesn't break existing key references).

3. **External combat math lint** (AC-4): the regex pattern is intentionally broad (multiple keyword alternates) to catch any future class accidentally re-implementing formation/angle/aura math. Allowlist: `src/feature/grid_battle/grid_battle_controller.gd` + `src/feature/damage_calc/damage_calc.gd` + `tests/helpers/` stubs.

4. **Epic-terminal commit pattern**: per turn-order story-007 + hp-status story-008 + camera epic precedent — single `feat(grid-battle): epic 10/10 Complete + ...` commit with detailed body listing all 10 stories' deliverables. Test baseline target ≥785 PASS / 0 errors.

## Test Evidence

**Story Type**: Config/Data (lint scripts + perf tests + evidence doc; minimal new production code)
**Required evidence**:
- Logic: `tests/performance/feature/grid_battle/grid_battle_controller_perf_test.gd` — must exist + 4 tests
- Config/Data: 4 lint scripts at `tools/ci/lint_grid_battle_controller_*.sh` + `lint_balance_entities_grid_battle_controller.sh` (5 total) — all exit 0
- Visual/Feel: `production/qa/evidence/grid_battle_controller_verification_summary.md` — epic-terminal rollup
- Smoke: full GdUnit4 suite Exit 0 with all new lints in CI
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: ALL prior 9 stories Complete (perf baseline measures shipped code; lints validate shipped patterns; epic close requires impl complete)
- **Unlocks**: Sprint-5 epic close-out → sprint-6 Battle Scene wiring + Battle HUD ADR + Scenario Progression ADR + Destiny Branch ADR begin
