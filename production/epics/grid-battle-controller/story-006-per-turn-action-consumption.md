# Story 006: Per-turn action consumption + end_player_turn + auto-handoff + token integration

> **Epic**: Grid Battle Controller | **Status**: Ready | **Layer**: Feature | **Type**: Logic | **Estimate**: 3h
> **ADR**: ADR-0014 §6 + R-5

## Acceptance Criteria

- [ ] **AC-1** `_acted_this_turn: Dictionary[int, bool] = {}` instance field; populated in `_consume_unit_action(unit_id)` after each MOVE or ATTACK confirms (chapter-prototype rule: one action per unit per turn — MOVE OR ATTACK, not both unless followed-up move-then-attack-if-in-range)
- [ ] **AC-2** `_consume_unit_action(unit_id: int) -> void`: sets `_acted_this_turn[unit_id] = true` + calls `_turn_runner.spend_action_token(unit_id)` per ADR-0011 Contract 4 simplified MVP integration (single-token; full move/action split deferred per ADR-0014 §6 simplification)
- [ ] **AC-3** `_any_player_unit_can_act() -> bool`: iterates `_units.values()` filtered for side=0 + alive (HPStatusController.is_alive); returns true if any unit NOT in `_acted_this_turn`
- [ ] **AC-4** Auto-handoff: after `_consume_unit_action`, if `_any_player_unit_can_act() == false` → call `end_player_turn()`
- [ ] **AC-5** `end_player_turn() -> void`: hands off to TurnOrderRunner — internally invokes `_turn_runner.end_player_turn()` or equivalent; resets `_acted_this_turn.clear()` for next round; deselects current selection (state → OBSERVATION + emit unit_selected_changed)
- [ ] **AC-6** Move-then-attack-in-range pattern (chapter-prototype proven): if `_handle_move` succeeds AND attack target exists in range from new position → allow attack as same turn-action (chapter-prototype's `_recompute_attack_targets_only` after move). MVP: single action consumption either way (MOVE alone OR MOVE+ATTACK chained = 1 action token spent)
- [ ] **AC-7** Acted-unit click guard: clicking a unit in `_acted_this_turn` → silent no-op (no FSM transition, no signal emit) per story-003 AC-7
- [ ] **AC-8** Test: 4-unit player roster + simulate 4 sequential `_consume_unit_action` calls → after 4th call, `_acted_this_turn.size() == 4` AND `end_player_turn()` auto-fires (verified via signal capture or `_turn_runner` stub method-call assertion)
- [ ] **AC-9** Test: simulate dead unit (HPStatusController stub returns is_alive=false) → `_any_player_unit_can_act` excludes it; if all-but-dead acted, auto-handoff still fires
- [ ] **AC-10** Regression baseline maintained: ≥757 + new tests / 0 errors / 0 orphans / Exit 0; new test file `tests/unit/feature/grid_battle/grid_battle_controller_turn_consumption_test.gd` adds ≥5 tests covering AC-2..AC-9

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
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: Story 001 (skeleton), Story 003 (FSM `_handle_grid_click` calls `_consume_unit_action` after action)
- **Unlocks**: Story 007 (round_started fires when end_player_turn → TurnOrderRunner advances round)
