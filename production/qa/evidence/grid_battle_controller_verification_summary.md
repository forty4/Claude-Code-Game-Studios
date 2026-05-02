# Grid Battle Controller — Epic Verification Summary

> **Epic**: `production/epics/grid-battle-controller/EPIC.md`
> **Sprint**: Sprint 5 (2026-05-02 to 2026-05-03 actual ship)
> **Governing ADR**: `docs/architecture/ADR-0014-grid-battle-controller.md`
> **Story**: `production/epics/grid-battle-controller/story-010-epic-terminal-perf-lints-evidence.md`
> **Date**: 2026-05-03
> **Author**: Dowan Kim

---

## Epic Outcome — All 10 Stories Complete

| # | Story | Tests added | Sprint slot |
|---|---|---:|---|
| qa-plan | grid-battle-controller QA plan | n/a | S5-01 |
| 001 | Class skeleton + 8-param DI + 4 GameBus subs + `_exit_tree` | +4 | S5-02 |
| 002 | BattleUnit Resource + `_units` registry + tag-based fate detection | +5 | S5-03 |
| 003 | 2-state FSM + 10-grid-action filter + click dispatch + Camera fallback | +12 | S5-04 |
| 004 | MOVE action + `is_tile_in_move_range` + `unit_moved` signal | +11 | S5-05 |
| 005 | ATTACK chain + DamageCalc integration + `damage_applied` signal | +17 | S5-06 |
| 006 | Per-turn action consumption + auto-handoff (drift #9 + #10) | +9 | S5-07 |
| 007 | 5-turn limit + `battle_outcome_resolved` + `_check_battle_end` + terminal state | +10 | S5-08 |
| 008 | Hidden fate counters (formation_turns + boss/assassin attribution + tank_hp_pct) | +12 | S5-09 |
| 009 | Cross-ADR `_exit_tree` audit + TurnOrderRunner retrofit + TD-057 RESOLVED | 0 | S5-10 |
| 010 | Epic terminal — perf + 4 lints + 5 BalanceConstants + epic close | +4 | S5-11 |

**Total**: **+84 new tests** across 7 unit test files + 1 perf test file.
**Test baseline**: 757 (pre-sprint-5) → **841** (post-story-010). **19 consecutive failure-free baselines** since sprint-3 close (per active.md velocity ledger).

---

## AC-1 — Performance Baseline (4 perf tests)

**File**: `tests/unit/feature/grid_battle/grid_battle_controller_perf_test.gd`

| Test | ADR headline | CI permissive gate | Result (last run, headless macOS) |
|---|---|---:|---|
| `test_setup_8_units_under_2ms_cold_start` | < 0.01ms (10µs) | < 2_000µs (×200) | PASS — well under gate |
| `test_handle_grid_click_1000_calls_under_50ms` | < 0.05ms × 1000 | < 50_000µs (×10 amortized) | PASS |
| `test_resolve_attack_100_calls_under_250ms` | < 0.5ms × 100 | < 250_000µs (×5 amortized) | PASS |
| `test_100_synthetic_battle_actions_under_300ms` | < 100ms total | < 300_000µs (×3) | PASS |

**Asymmetric-signal rationale** (mirrors ADR-0012 R-2 precedent): headless CI PASS does not prove mobile PASS, but headless CI FAIL would guarantee mobile FAIL. CI gates are the negative-signal coverage; reference-hardware p99 validation moves to `perf-nightly.yml` (TBD post-MVP).

CI uses `SKIP_PERF_BUDGETS=1` env var marker (set in `.github/workflows/tests.yml` line 121); gates remain permissive enough that the env-var is a redundant safety net rather than the primary mechanism.

---

## AC-2 / AC-3 / AC-4 / AC-5 — Forbidden-Pattern Lints (4 scripts)

| Lint script | ADR pattern | Status |
|---|---|---|
| `tools/ci/lint_grid_battle_controller_signal_emission_outside_battle_domain.sh` | `grid_battle_controller_signal_emission_outside_battle_domain` (ADR-0014 §8) | **PASS** — 0 GameBus emits |
| `tools/ci/lint_grid_battle_controller_static_state.sh` | `grid_battle_controller_static_state` (ADR-0014) | **PASS** — 0 `static var` |
| `tools/ci/lint_grid_battle_controller_external_combat_math.sh` | `grid_battle_controller_external_combat_math` (ADR-0014 R-2) | **PASS** — 4-file allowlist enforced |
| `tools/ci/lint_balance_entities_grid_battle_controller.sh` | 6 BalanceConstants keys present | **PASS** — 6/6 keys |

All 4 lints chmod +x and wired into `.github/workflows/tests.yml` (block: lines 114-122 of the file post-update, after the camera 5-lint block).

**External combat math allowlist** (legitimate references):
- `src/feature/grid_battle/grid_battle_controller.gd` — sole math implementer
- `src/feature/damage_calc/damage_calc.gd` — consumer of `formation_atk_bonus`
- `src/feature/damage_calc/resolve_modifiers.gd` — data carrier (`@export` fields)
- `src/core/battle_unit.gd` — doc-comment references only

When Formation Bonus ADR ships post-MVP, the math will move to FormationBonusSystem; the lint is the migration safety rail (a 5th file showing up = forced design conversation).

---

## AC-7 — ResolveModifiers Extension Verification

3 new fields shipped in story-005 same-patch (`src/feature/damage_calc/resolve_modifiers.gd`):
- `formation_atk_bonus: float = 0.0` (consumed by DamageCalc P_mult)
- `angle_mult: float = 1.0` (controller-side post-multiply; future Formation Bonus ADR may migrate into DamageCalc)
- `aura_mult: float = 1.0` (controller-side post-multiply)

Back-compat verified: existing damage-calc tests (78 cases) PASS unchanged. Forward-compat: existing damage-calc factory `ResolveModifiers.make(...)` still produces valid instances with default field values.

---

## AC-8 — Verification Doc (this file)

5 controller-LOCAL signals shipped + grep-asserted on `grid_battle_controller.gd`:
- `unit_selected_changed(unit_id, was_selected)` (story-003 — fires)
- `unit_moved(unit_id, from, to)` (story-004 — fires)
- `damage_applied(attacker_id, defender_id, damage)` (story-005 — fires)
- `battle_outcome_resolved(outcome, fate_data)` (story-007 — fires)
- `hidden_fate_condition_progressed(condition_id, value)` (story-005 + 008 — fires)

**Hidden semantic preservation** (game-concept.md Pillar 2): `hidden_fate_condition_progressed` has 0 default subscribers per `test_hidden_fate_signal_has_zero_default_subscribers` structural assertion. Battle HUD MUST NOT subscribe — Destiny Branch ADR (sprint-6) is sole consumer.

---

## AC-9 — TD-057 Final Status

**RESOLVED 2026-05-03** via story-009 audit. See `docs/tech-debt-register.md` TD-057 for full audit findings table + verification report.

Summary: 4 battle-scoped Nodes audited. 3 of 4 systems already had `_exit_tree()` autoload-disconnect (HPStatusController + BattleCamera + GridBattleController). TurnOrderRunner was the missing case → retrofitted in same patch as story-009 (`src/core/turn_order_runner.gd` `_exit_tree` body added, mirrors HPStatusController pattern).

Cross-ADR markers updated:
- ADR-0013 R-6 → "RESOLVED 2026-05-03 via grid-battle-controller story-009 audit"
- ADR-0014 R-7 → "RESOLVED 2026-05-03"
- ADR-0014 §Implementation Notes → audit outcome appended

Pattern stable at **4 invocations**.

---

## AC-10 — Regression Baseline

**Final epic baseline**: **841 PASS / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0**.

Sprint-5 trajectory:
- Pre-session (sprint-4 close): 757
- Story-001 skeleton: 757 → 761 (+4) — 10th
- Story-002 registry: 761 → 766 (+5) — 11th
- Story-003 FSM: 766 → 778 (+12) — 12th
- Story-004 MOVE: 778 → 789 (+11) — 13th
- Story-005 ATTACK: 789 → 806 (+17) — 14th
- Story-006 turn consumption: 806 → 815 (+9) — 15th
- Story-007 turn limit: 815 → 825 (+10) — 16th
- Story-008 fate counters: 825 → 837 (+12) — 17th
- Story-009 audit retrofit: 837 (no new tests; smoke check) — 18th
- Story-010 perf baseline: 837 → **841** (+4) — **19th consecutive failure-free**

---

## Architectural Drift Catalog (this epic)

10 drift items surfaced + fixed during implementation; ADR-0014 Implementation Notes amended each time. Pattern stable at **10 invocations across 5 implementation stories** (001-005-006-007-009).

| # | Story | Drift |
|---|---|---|
| 1 | 001 | ADR §3 sketches `_hp_controller.unit_died.connect(...)` instance signal; production routes via GameBus autoload |
| 2 | 001 | ADR-0010 boundary said no BattleUnit field additions; story-002 amended via ADR-0014 §3 contract |
| 3 | 003 | ADR-0014 §10 sketches `action: StringName` but GameBus uses `String` |
| 4 | 005 | ADR §5 step 9 invokes `_hp_controller.apply_death_consequences` — method does NOT exist on shipped HPStatusController |
| 5 | 005 | `ResolveModifiers.formation_atk_bonus` already had documented range [0.0, 0.05]; ADR §5 wants [0.0, 0.20] |
| 6 | 005 | ADR §5 stores `angle_mult` + `aura_mult` on ResolveModifiers but DamageCalc doesn't consume them |
| 7 | 005 | `BattleUnit` lacked `raw_atk` + `raw_def` fields needed for AttackerContext + DefenderContext |
| 8 | 005 | HeroDatabase + UnitRole + TerrainEffect are all-static — DI cleanup candidate (deferred) |
| 9 | 006 | ADR §6 sketches `_turn_runner.spend_action_token(unit_id)` — shipped API is `declare_action(unit_id, action, target) -> ActionResult` |
| 10 | 006 | ADR §6 + AC-5 reference `_turn_runner.end_player_turn()` — no such method on shipped runner |

All 10 documented in ADR-0014 Implementation Notes section with rationale + retroactive design intent preserved. Pattern: read shipped API fresh → flag drift in Implementation Notes amendment → ship correct code + ADR amendment in same patch.

---

## Cross-ADR Closure

| ADR | Closure marker |
|---|---|
| ADR-0013 R-6 (Camera GameBus connection leak) | RESOLVED 2026-05-03 via story-009 audit |
| ADR-0013 R-7 (cross-ADR `_exit_tree` audit obligation) | RESOLVED 2026-05-03 — pattern stable at 4 invocations |
| ADR-0014 R-7 (cross-ADR `_exit_tree` audit follow-up) | RESOLVED 2026-05-03 |
| TD-057 (TurnOrderRunner missing `_exit_tree`) | RESOLVED 2026-05-03 (Path B retrofit shipped) |

---

## Sprint-5 Should-Have Status (forward look)

The 2 should-have stories (S5-12 ADR-0015 Battle HUD authoring + S5-13 Battle HUD epic scaffold) remain `backlog` at epic close. They depend on ADR-0014's `5 controller-LOCAL signals` contract (now SHIPPED) but are scope-independent of grid-battle-controller — addressing in a follow-up sprint-5 mini-batch is acceptable per the ratified plan.

---

## Co-Author

🤖 Generated with [Claude Code](https://claude.com/claude-code)
