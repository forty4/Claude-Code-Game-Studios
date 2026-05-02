# Story 008: Hidden fate-condition tracking — 5 silent counters + signal channel

> **Epic**: Grid Battle Controller | **Status**: Ready | **Layer**: Feature | **Type**: Logic | **Estimate**: 3h
> **ADR**: ADR-0014 §8 + game-concept.md Pillar 2 ("운명은 바꿀 수 있다") + Player Experience MDA Discovery #4

## Acceptance Criteria

- [ ] **AC-1** 5 hidden counter instance fields:
  - `_fate_rear_attacks: int = 0` — incremented on each rear-angle attack landed (any unit)
  - `_fate_formation_turns: int = 0` — incremented at end of each round if any player unit had ≥1 adjacent ally during that round
  - `_fate_assassin_kills: int = 0` — incremented when `_fate_assassin_unit_id` (조운-tagged) kills an enemy unit
  - `_fate_boss_killed: bool = false` — set to true when `_fate_boss_unit_id` (boss-tagged enemy) dies
  - tank_alive_hp_pct — NOT a counter (queried on-demand from `HPStatusController.get_current_hp(_fate_tank_unit_id) / get_max_hp(...)`)
- [ ] **AC-2** Rear-attack tracking: in `_resolve_attack` (story-005), after computing `angle == "rear"` → increment `_fate_rear_attacks` + emit `hidden_fate_condition_progressed("rear_attacks", _fate_rear_attacks)` signal
- [ ] **AC-3** Formation-turns tracking: in `_on_round_started` (story-007), iterate `_units.values()` filtered for side=0 + alive; if any has `_count_adjacent_allies(u) >= 1` → increment `_fate_formation_turns` + emit `hidden_fate_condition_progressed("formation_turns", _fate_formation_turns)` signal
- [ ] **AC-4** Assassin-kills tracking: in `_on_unit_died(unit_id)` handler (subscribed via CONNECT_DEFERRED in story-001), check if last attacker was `_fate_assassin_unit_id` AND defender is enemy (side=1) → increment `_fate_assassin_kills` + emit signal. Requires tracking `_last_attacker_id` field set in `_resolve_attack`
- [ ] **AC-5** Boss-killed tracking: in `_on_unit_died(unit_id)`, if `unit_id == _fate_boss_unit_id` → set `_fate_boss_killed = true` + emit `hidden_fate_condition_progressed("boss_killed", 1)` signal
- [ ] **AC-6** `signal hidden_fate_condition_progressed(condition_id: StringName, value: int)` declared as controller-LOCAL (NOT GameBus per ADR-0014 §8 — Battle HUD does NOT subscribe to preserve "hidden" semantic; sole consumer is Destiny Branch ADR sprint-6)
- [ ] **AC-7** `_emit_battle_outcome` (story-007) snapshots all 5 counters into `fate_data: Dictionary` as `{"tank_alive_hp_pct": float, "rear_attacks": int, "formation_turns": int, "assassin_kills": int, "boss_killed": bool}`; tank HP queried on-demand from HPStatusController (not stored)
- [ ] **AC-8** **Hidden semantic preservation test**: assert that no Battle HUD subscriber exists for `hidden_fate_condition_progressed` (test enumerates connections; counts subscribers; expects = 0 from any HUD class). Future-proofs against accidental HUD subscription that would leak the hidden conditions to player.
- [ ] **AC-9** Test sweep: simulate fixture battle with all 4 condition types triggered → assert all 4 counters increment correctly + each emits its signal at the right moment + final fate_data snapshot is correct
- [ ] **AC-10** Regression baseline maintained: ≥757 + new tests / 0 errors / 0 orphans / Exit 0; new test file `tests/unit/feature/grid_battle/grid_battle_controller_fate_test.gd` adds ≥6 tests covering AC-2..AC-9

## Implementation Notes

*Derived from ADR-0014 §8 + game-concept.md Core Loop ("3-국면 전투 구조") + chapter-prototype's _fate_* counters:*

1. **Pillar 2 enforcement** ("어렵지만 가능하게"): per game-concept.md §Pillar 2 Design test, fate conditions should be HARD to discover. Hidden semantic is the load-bearing UX — Battle HUD subscribing would defeat the design intent ("플레이어가 자연스럽게 '이 전투에서 다르게 하면 역사가 바뀔까?' 추측하기 시작" per Key Dynamics).
2. **Sole consumer = Destiny Branch ADR** (sprint-6): only Destiny Branch system subscribes to `hidden_fate_condition_progressed`. Battle HUD subscribes to the OTHER 4 controller-local signals (unit_selected_changed + unit_moved + damage_applied + battle_outcome_resolved) but NOT this one.
3. **Tag-based unit detection** (story-002): `_fate_tank_unit_id` / `_fate_assassin_unit_id` / `_fate_boss_unit_id` populated in `setup()` via `_find_unit_by_tag(tag)`. If a tag is missing from the fixture (e.g., scenario lacks a "boss"-tagged enemy), the corresponding counter is dormant — no errors.
4. **`_last_attacker_id` tracking**: small instance field set in `_resolve_attack` immediately before calling `apply_damage` — used by `_on_unit_died` (which fires DEFERRED, so by handler time we need to know who attacked). Cleared at end of each turn for safety.
5. **fate_data snapshot timing**: only at battle-end (`_emit_battle_outcome`) — does NOT fire on every counter increment. The per-increment signal fires for Destiny Branch real-time consumers; the snapshot is for terminal-state judgment.

## Test Evidence

**Story Type**: Logic (counter increment + signal emission — pure deterministic)
**Required evidence**: `tests/unit/feature/grid_battle/grid_battle_controller_fate_test.gd` — must exist + ≥6 tests + must pass
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: Story 002 (tag-based fate unit IDs), Story 003 (FSM dispatches actions), Story 005 (rear attack detection in _resolve_attack), Story 007 (_emit_battle_outcome snapshot)
- **Unlocks**: Destiny Branch ADR (sprint-6 — sole consumer of hidden_fate_condition_progressed signal channel + battle_outcome_resolved fate_data)
