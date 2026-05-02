# Story 007: 5-turn limit + battle_outcome_resolved emission + victory check

> **Epic**: Grid Battle Controller | **Status**: Ready | **Layer**: Feature | **Type**: Logic | **Estimate**: 2h
> **ADR**: ADR-0014 §7

## Acceptance Criteria

- [ ] **AC-1** `_max_turns: int = 0` instance field; populated in `_ready()` from `BalanceConstants.get_const("MAX_TURNS_PER_BATTLE")` (added by story-010 = 5 default)
- [ ] **AC-2** `_on_round_started(round_num: int) -> void` subscribed to `_turn_runner.round_started` via CONNECT_DEFERRED in story-001
- [ ] **AC-3** `_on_round_started` body: if `round_num > _max_turns` → call `_emit_battle_outcome("TURN_LIMIT_REACHED")` (per ADR-0014 §7); also handles formation_turns counter increment (story-008)
- [ ] **AC-4** `_emit_battle_outcome(outcome: StringName) -> void`: gathers fate_data Dictionary snapshot from current 5 fate counters (story-008) + emits `battle_outcome_resolved(outcome, fate_data)` controller-LOCAL signal
- [ ] **AC-5** Victory check on `_on_unit_died(unit_id)` (story-008 wires this handler): if all enemies dead → `_emit_battle_outcome("VICTORY_ANNIHILATION")`; if all players dead → `_emit_battle_outcome("DEFEAT_ANNIHILATION")`. Per grid-battle.md CR-7 evaluation order: VICTORY_ANNIHILATION → DEFEAT_ANNIHILATION (first to resolve wins per EC-GB-02)
- [ ] **AC-6** `_check_battle_end() -> bool` helper: iterates `_units.values()` filtered by alive (HPStatusController.is_alive); returns true if either side has 0 alive units; used by victory check above
- [ ] **AC-7** Once `battle_outcome_resolved` emitted, controller enters terminal state — no further input handling (per `_battle_over: bool` flag set in `_emit_battle_outcome`)
- [ ] **AC-8** Test: simulate 5 rounds → 6th round_started fires → assert exactly 1 `battle_outcome_resolved("TURN_LIMIT_REACHED", fate_data)` emitted with correct fate_data snapshot
- [ ] **AC-9** Test: simulate lethal damage to last enemy → `_on_unit_died` → assert exactly 1 `battle_outcome_resolved("VICTORY_ANNIHILATION", fate_data)` emitted; defender HP 0 → cascade properly via CONNECT_DEFERRED (no reentrance)
- [ ] **AC-10** Regression baseline maintained: ≥757 + new tests / 0 errors / 0 orphans / Exit 0; new test file `tests/unit/feature/grid_battle/grid_battle_controller_turn_limit_test.gd` adds ≥4 tests covering AC-3..AC-9

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
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: Story 001 (skeleton + round_started subscription), Story 005 (apply_damage chain emits unit_died), Story 008 (fate counter snapshot for fate_data)
- **Unlocks**: Scenario Progression ADR (sprint-6 — primary consumer of battle_outcome_resolved)
