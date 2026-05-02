# Story 007: 5-turn limit + battle_outcome_resolved emission + victory check

> **Epic**: Grid Battle Controller | **Status**: Complete (2026-05-03) | **Layer**: Feature | **Type**: Logic | **Estimate**: 2h
> **ADR**: ADR-0014 §7

## Acceptance Criteria

- [x] **AC-1** `_max_turns: int = 0` instance field; populated in `_ready()` from `BalanceConstants.get_const("MAX_TURNS_PER_BATTLE")` (already shipped in story-001)
- [x] **AC-2** `_on_round_started(round_num: int) -> void` subscribed to `GameBus.round_started` via CONNECT_DEFERRED in story-001 (drift #1: GameBus autoload, not instance signal)
- [x] **AC-3** `_on_round_started` body: if `round_num > _max_turns` → call `_emit_battle_outcome(&"TURN_LIMIT_REACHED")`; story-008 will add formation_turns counter increment alongside this body
- [x] **AC-4** `_emit_battle_outcome(outcome: StringName) -> void`: gathers fate_data Dictionary snapshot from 7 fate fields (tank/assassin/boss unit_ids + 4 counters) + emits `battle_outcome_resolved(outcome, fate_data)` controller-LOCAL signal + sets `_battle_over = true` (idempotent — early-returns if already set)
- [x] **AC-5** Victory check on `_on_unit_died(unit_id)`: calls `_check_battle_end()` after every unit death. Story-008 will add fate counter updates alongside this body
- [x] **AC-6** `_check_battle_end() -> bool` helper: iterates `_units.values()` filtered by `_hp_controller.is_alive`; emits VICTORY_ANNIHILATION (enemy_alive==0) before DEFEAT_ANNIHILATION (player_alive==0) per grid-battle.md CR-7 / EC-GB-02 player-side precedence on mutual-kill
- [x] **AC-7** Once `battle_outcome_resolved` emitted, controller enters terminal state — `handle_grid_click` early-returns if `_battle_over`; `_on_round_started` + `_on_unit_died` early-return if `_battle_over`; `_emit_battle_outcome` itself is idempotent
- [x] **AC-8** Test: round 6 round_started fires → exactly 1 `battle_outcome_resolved(&"TURN_LIMIT_REACHED", fate_data)` emit (covered: `test_on_round_started_over_limit_emits_turn_limit_reached` + `test_emit_battle_outcome_includes_fate_data_snapshot`)
- [x] **AC-9** Test: simulate lethal damage to last enemy → `_on_unit_died` → exactly 1 `battle_outcome_resolved(&"VICTORY_ANNIHILATION", fate_data)` emit (covered: `test_check_battle_end_all_enemies_dead_emits_victory` + DEFEAT counterpart + mutual-kill precedence test)
- [x] **AC-10** Regression baseline maintained: 825 PASS / 0 errors / 0 failures / 0 orphans / Exit 0 (was 815 → +10 new tests; 16th consecutive failure-free baseline). New test file `tests/unit/feature/grid_battle/grid_battle_controller_turn_limit_test.gd` adds 10 tests covering AC-3..AC-9

## Implementation Notes

*Derived from ADR-0014 §7 + grid-battle.md CR-7 + chapter-prototype's _check_victory:*

1. **TurnOrderRunner round_started signal**: per ADR-0011 / shipped TurnOrderRunner. Round starts at 1; turn 5 limit means round_num 6 triggers TURN_LIMIT_REACHED.
2. **CR-7 evaluation order** (per grid-battle.md): VICTORY_ANNIHILATION → DEFEAT_ANNIHILATION → VICTORY_COMMANDER_KILL (scenario-driven). MVP only handles first 2; commander-kill deferred to Scenario Progression ADR (sprint-6).
3. **Terminal state**: once `_battle_over = true`, all click handlers + signal handlers early-return. Prevents double-emit of battle_outcome_resolved on edge cases (e.g., turn_limit firing simultaneously with last-enemy-death).
4. **Fate data snapshot**: see story-008 — all 5 hidden counters get bundled into the `fate_data` Dictionary at outcome-emission time. Destiny Branch ADR (sprint-6) consumes this snapshot for chapter-advancement judging.
5. **Test isolation**: `before_test()` resets `_battle_over = false` + `_acted_this_turn.clear()` per G-15 discipline.

## Test Evidence

**Story Type**: Logic (turn counter + outcome dispatch — pure deterministic)
**Required evidence**: `tests/unit/feature/grid_battle/grid_battle_controller_turn_limit_test.gd` — must exist + ≥4 tests + must pass
**Status**: [x] Shipped 2026-05-03 — 10 tests, all passing (≥4 required). Coverage: turn-limit threshold (under/at/over), fate_data snapshot shape, VICTORY/DEFEAT/mutual-kill annihilation, terminal-state idempotency on second emit, terminal guards on `handle_grid_click` + `_on_round_started`.

## Dependencies

- **Depends on**: Story 001 (skeleton + round_started subscription), Story 005 (apply_damage chain emits unit_died), Story 008 (fate counter snapshot for fate_data)
- **Unlocks**: Scenario Progression ADR (sprint-6 — primary consumer of battle_outcome_resolved)
