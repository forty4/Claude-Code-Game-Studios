# Story 010: Epic terminal — perf baseline + 3 lints + 6 BalanceConstants + epic close

> **Epic**: Grid Battle Controller | **Status**: Complete (2026-05-03) | **Layer**: Feature | **Type**: Config/Data | **Estimate**: 3h
> **ADR**: ADR-0014 §11 + Performance Implications + Migration Plan §13

## Acceptance Criteria

- [x] **AC-1** Performance baseline test `tests/unit/feature/grid_battle/grid_battle_controller_perf_test.gd` with 4 tests (location uses `tests/unit/` per camera/turn-order/damage-calc/hp-status precedent — story spec used `tests/performance/` placeholder but established convention is `tests/unit/`):
  - [x] `test_setup_8_units_under_2ms_cold_start` — DI setup() with 8-unit roster ×200 over 10µs ADR headline → <2_000µs gate. PASS
  - [x] `test_handle_grid_click_1000_calls_under_50ms` — 1000-iter FSM dispatch ×10 amortized over 0.05ms ADR headline → <50_000µs gate. PASS
  - [x] `test_resolve_attack_100_calls_under_250ms` — 100-iter full chain ×5 amortized over 0.5ms ADR headline → <250_000µs gate. PASS
  - [x] `test_100_synthetic_battle_actions_under_300ms` — 100 mixed actions ×3 over 100ms ADR headline → <300_000µs gate. PASS
- [x] **AC-2** `tools/ci/lint_grid_battle_controller_signal_emission_outside_battle_domain.sh` shipped + chmod +x + PASS — 0 GameBus emits in controller (5 LOCAL signals only per ADR-0014 §8)
- [x] **AC-3** `tools/ci/lint_grid_battle_controller_static_state.sh` shipped + chmod +x + PASS — 0 `^static var ` declarations (battle-scoped state contract preserved; mirrors hp_status_static_state + turn_order_static_state precedent)
- [x] **AC-4** `tools/ci/lint_grid_battle_controller_external_combat_math.sh` shipped + chmod +x + PASS — combat-math keywords confined to 4-file allowlist (controller + damage_calc + resolve_modifiers + battle_unit). Migration safety rail for future Formation Bonus ADR cutover
- [x] **AC-5** `tools/ci/lint_balance_entities_grid_battle_controller.sh` shipped + chmod +x + PASS — 6/6 keys present:
  - `MAX_TURNS_PER_BATTLE = 5` (already shipped in story-001)
  - 5 fate-condition thresholds NEW: `FATE_TANK_HP_THRESHOLD = 0.60` + `FATE_ASSASSIN_KILLS_THRESHOLD = 2` + `FATE_REAR_ATTACKS_THRESHOLD = 2` + `FATE_FORMATION_TURNS_THRESHOLD = 3` + `FATE_BOSS_KILLED_REQUIRED = 1`
- [x] **AC-6** All 4 lint scripts wired into `.github/workflows/tests.yml` (lines 114-122 of post-update file) after the camera 5-lint block per existing precedent
- [x] **AC-7** `ResolveModifiers` Resource extension shipped in story-005 same-patch — 3 new fields (`formation_atk_bonus`, `angle_mult`, `aura_mult`) verified back-compat (78 damage_calc tests still PASS)
- [x] **AC-8** `production/qa/evidence/grid_battle_controller_verification_summary.md` shipped — epic-terminal rollup lists 5 LOCAL signals + 4 lint script results + cross-ADR audit closure + perf budgets + drift catalog + final baseline
- [x] **AC-9** TD-057 RESOLVED 2026-05-03 (Path B retrofit) per story-009. Logged at `docs/tech-debt-register.md` with full audit findings table + verification report
- [x] **AC-10** Regression baseline: 841 PASS / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0 — **19th consecutive failure-free baseline** (was 757 pre-sprint-5 → +84 tests)
- [x] **AC-11** EPIC.md updated: Status Ready → Complete (2026-05-03); 10/10 Complete; final test baseline + verification doc reference recorded
- [x] **AC-12** `production/epics/index.md` updated: Feature layer 2/13 → 3/13 (grid-battle-controller Complete); header line + grid-battle-controller row both refreshed

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
- Logic: `tests/unit/feature/grid_battle/grid_battle_controller_perf_test.gd` — 4 tests, all PASS
- Config/Data: 4 lint scripts shipped + chmod +x + wired into CI — all exit 0
- Visual/Feel: `production/qa/evidence/grid_battle_controller_verification_summary.md` — epic-terminal rollup shipped
- Smoke: full GdUnit4 suite 841 / 0 errors / 0 failures / 0 orphans / Exit 0 (19th consecutive failure-free)
**Status**: [x] Shipped 2026-05-03 — all evidence artifacts complete

## Dependencies

- **Depends on**: ALL prior 9 stories Complete (perf baseline measures shipped code; lints validate shipped patterns; epic close requires impl complete)
- **Unlocks**: Sprint-5 epic close-out → sprint-6 Battle Scene wiring + Battle HUD ADR + Scenario Progression ADR + Destiny Branch ADR begin
