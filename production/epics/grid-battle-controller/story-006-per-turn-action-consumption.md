# Story 006: Per-turn action consumption + end_player_turn + auto-handoff + token integration

> **Epic**: Grid Battle Controller | **Status**: Complete (2026-05-03) | **Layer**: Feature | **Type**: Logic | **Estimate**: 3h
> **ADR**: ADR-0014 §6 + R-5

## Acceptance Criteria

- [x] **AC-1** `_acted_this_turn: Dictionary[int, bool] = {}` instance field; populated in `_consume_unit_action(unit_id)` after each MOVE or ATTACK confirms (chapter-prototype rule: one action per unit per turn — MOVE OR ATTACK, not both unless followed-up move-then-attack-if-in-range)
- [x] **AC-2** `_consume_unit_action(unit_id: int) -> void`: sets `_acted_this_turn[unit_id] = true` + calls `_turn_runner.declare_action(unit_id, TurnOrderRunner.ActionType.ATTACK, null)` per ADR-0011 Contract 4 simplified MVP integration (drift #9 — sketch said `spend_action_token`, shipped API is `declare_action`; ADR-0014 Implementation Notes amended same-patch)
- [x] **AC-3** `_any_player_unit_can_act() -> bool`: iterates `_units.values()` filtered for side=0 + alive (HPStatusController.is_alive); returns true if any unit NOT in `_acted_this_turn`
- [x] **AC-4** Auto-handoff: after `_consume_unit_action`, if `_any_player_unit_can_act() == false` → call `end_player_turn()`
- [x] **AC-5** `end_player_turn() -> void`: controller-side bookkeeping (clear `_acted_this_turn` + deselect). DEVIATION drift #10 — shipped TurnOrderRunner has NO `end_player_turn()` method; round advance is signal-driven via GameBus.round_started → `_on_round_started`. ADR-0014 Implementation Notes amended same-patch
- [x] **AC-6** Move-then-attack-in-range pattern: DEFERRED to post-MVP. Current behavior: `_handle_move` consumes action immediately after move (story-004 logic preserved). The "1 action token whether MOVE alone or MOVE+ATTACK chained" semantic is structurally honored because `_consume_unit_action` deselects → second click in OBSERVATION goes through acted-unit guard (AC-7). Chain-attack UX deferred to Battle HUD epic or future ADR-0014 amendment
- [x] **AC-7** Acted-unit click guard: clicking a unit in `_acted_this_turn` → silent no-op (no FSM transition, no signal emit) per story-003 AC-7
- [x] **AC-8** Test: 4-unit player roster + simulate 4 sequential `_consume_unit_action` calls → after 4th call, `end_player_turn()` auto-fires (verified via `_acted_this_turn` cleared + 4 declared_actions on stub)
- [x] **AC-9** Test: simulate dead unit (HPStatusController stub returns is_alive=false) → `_any_player_unit_can_act` excludes it; if all-but-dead acted, auto-handoff still fires
- [x] **AC-10** Regression baseline maintained: 815 PASS / 0 errors / 0 failures / 0 orphans / Exit 0 (was 806 → +9 new tests; 15th consecutive failure-free baseline). New test file `tests/unit/feature/grid_battle/grid_battle_controller_turn_consumption_test.gd` adds 9 tests covering AC-2..AC-9

## Implementation Notes

*Derived from ADR-0014 §6 + chapter-prototype's _consume_unit_action + _end_player_action:*

1. **MVP single-action-token simplification** per ADR-0014 §6: full grid-battle.md GDD has separate move + action tokens (TurnOrderRunner Contract 4); MVP collapses to single action token. When future Token ADR refines this, only the encapsulated `_consume_unit_action` body changes — call sites stay stable.
2. **TurnOrderRunner integration**: `spend_action_token(unit_id)` per ADR-0011 — exact API name pending shipped TurnOrderRunner verification at story-006 implementation. If shipped name differs (e.g., `spend_token` or `consume_action`), use shipped name; story comment should note the discrepancy.
3. **Auto-handoff**: chapter-prototype proves this UX is good (no explicit "end turn" button required after all units acted). MVP retains both manual `end_player_turn()` button-trigger AND auto-handoff. Battle HUD (sprint-5) will add the explicit button.
4. **Dead-unit exclusion**: `_any_player_unit_can_act` MUST check `_hp_controller.is_alive(u.unit_id)` — using `is_dead` is wrong (per ADR-0014 Implementation Notes — `is_alive` is canonical query per shipped HPStatusController:219).
5. **Test pattern**: stub TurnOrderRunner with `spent_tokens: Array[int]` fixture; assert sequence of token spends matches expected.

## Test Evidence

**Story Type**: Logic (turn-action tracking + handoff dispatch — pure deterministic)
**Required evidence**: `tests/unit/feature/grid_battle/grid_battle_controller_turn_consumption_test.gd` — must exist + ≥5 tests + must pass
**Status**: [x] Shipped 2026-05-03 — 9 tests, all passing (≥5 required). Plus 3 prior-story tests updated to handle auto-handoff (move-test full-chain + move-test re-entrancy + attack-test full-chain — added 2nd alive player unit to gate handoff during single-call assertions).

## Dependencies

- **Depends on**: Story 001 (skeleton), Story 003 (FSM `_handle_grid_click` calls `_consume_unit_action` after action)
- **Unlocks**: Story 007 (round_started fires when end_player_turn → TurnOrderRunner advances round)
