# Story 008: Hidden fate-condition tracking — 5 silent counters + signal channel

> **Epic**: Grid Battle Controller | **Status**: Complete (2026-05-03) | **Layer**: Feature | **Type**: Logic | **Estimate**: 3h
> **ADR**: ADR-0014 §8 + game-concept.md Pillar 2 ("운명은 바꿀 수 있다") + Player Experience MDA Discovery #4

## Acceptance Criteria

- [x] **AC-1** 5 hidden counter instance fields shipped:
  - `_fate_rear_attacks` (story-005) + `_fate_formation_turns` (this story AC-3) + `_fate_assassin_kills` (this story AC-4) + `_fate_boss_killed` (this story AC-5)
  - tank_alive_hp_pct queried on-demand from `_hp_controller.get_current_hp` / `get_max_hp` in `_emit_battle_outcome` (AC-7)
- [x] **AC-2** Rear-attack tracking: in `_resolve_attack` (story-005), already shipped — `angle == "rear"` → increment + emit
- [x] **AC-3** Formation-turns tracking: `_on_round_started` iterates `_units.values()` filtered for side=0 + alive; first unit with `_count_adjacent_allies(u) >= 1` triggers ONE increment per round + emit (`break` after first match — round-scoped, not unit-scoped)
- [x] **AC-4** Assassin-kills tracking: `_on_unit_died` checks `_last_attacker_id == _fate_assassin_unit_id` (with `_fate_assassin_unit_id != -1` guard) AND defender's `side == 1` (friendly-fire excluded) → increment + emit
- [x] **AC-5** Boss-killed tracking: `_on_unit_died` checks `unit_id == _fate_boss_unit_id` (with `not _fate_boss_killed` idempotent guard) → flip flag + emit `boss_killed=1`
- [x] **AC-6** `signal hidden_fate_condition_progressed(condition_id: StringName, value: int)` already declared as controller-LOCAL in story-001 — NOT routed through GameBus (preserves hidden semantic)
- [x] **AC-7** `_emit_battle_outcome` snapshots 8 fields into fate_data: tank_unit_id + tank_alive_hp_pct (computed on-demand with `max_hp <= 0 → 0.0` guard) + assassin_unit_id + boss_unit_id + 4 counters
- [x] **AC-8** Hidden semantic preservation test: structural assertion that fresh controller has 0 subscribers on `hidden_fate_condition_progressed` (`get_connections().size() == 0`). Future Battle HUD authors must explicitly subscribe (which would fail this test → forces design conversation)
- [x] **AC-9** Full sweep test: 5-unit roster fixture (tank/assassin/ally/boss/grunt) drives formation_turns + boss_killed + assassin_kills + tank_alive_hp_pct in one battle → 3 hidden fate emits + correct fate_data snapshot
- [x] **AC-10** Regression baseline maintained: 837 PASS / 0 errors / 0 failures / 0 orphans / Exit 0 (was 825 → +12 new tests; 17th consecutive failure-free baseline). New test file `tests/unit/feature/grid_battle/grid_battle_controller_fate_test.gd` adds 12 tests covering AC-2..AC-9

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
**Status**: [x] Shipped 2026-05-03 — 12 tests, all passing (≥6 required). Coverage: formation_turns (with/without/once-per-round) + boss kill flip + non-boss no-flip + assassin kill counter + non-assassin/friendly-fire exclusions + tank_alive_hp_pct (with/without tank) + full 4-condition sweep + AC-8 hidden semantic structural test.

## Dependencies

- **Depends on**: Story 002 (tag-based fate unit IDs), Story 003 (FSM dispatches actions), Story 005 (rear attack detection in _resolve_attack), Story 007 (_emit_battle_outcome snapshot)
- **Unlocks**: Destiny Branch ADR (sprint-6 — sole consumer of hidden_fate_condition_progressed signal channel + battle_outcome_resolved fate_data)
