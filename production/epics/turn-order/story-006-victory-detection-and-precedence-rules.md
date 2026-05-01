# Story 006: Victory detection (T7 + RE2 round-cap DRAW + AC-18 mutual kill PLAYER_WIN precedence + AC-22 T7-beats-RE2) + ROUND_CAP append

> **Epic**: Turn Order
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3h
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/turn-order.md`
**Requirement**: `TR-turn-order-007`, `TR-turn-order-018`, `TR-turn-order-020`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011 — Turn Order — 4th emitted signal `victory_condition_detected` + F-3 round cap + AC-18/AC-22 precedence rules; ADR-0001 (Grid Battle is sole emitter of authoritative `battle_outcome_resolved` per single-owner rule); ADR-0006 (BalanceConstants.get_const("ROUND_CAP"))
**ADR Decision Summary**: TR-007 = sole emitter of 4th GameBus signal `victory_condition_detected(result: int)` (int enum {PLAYER_WIN=0, PLAYER_LOSE=1, DRAW=2}); emitted at T7 (decisive) OR RE2 (round cap DRAW); sole consumer Grid Battle. TR-018 = F-3 round cap — RE2 reads `BalanceConstants.get_const("ROUND_CAP")`; if `_round_number >= ROUND_CAP`, emits `victory_condition_detected(DRAW)`. ROUND_CAP=30 net-new key appended same-patch per ADR-0006 §6 obligation. TR-020 = AC-18 mutual kill PLAYER_WIN precedence (player-side checked BEFORE PLAYER_LOSE in T7); AC-22 T7 PLAYER_WIN beats RE2 DRAW in Round 30 (T7 emit happens synchronously before RE2 evaluation).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Match-statement on faction-count-derived enum (4.0+ stable); BalanceConstants.get_const string-keyed read (project-stable per ADR-0006 5+ invocations); int-enum for `victory_condition_detected` payload matches ADR-0001 line 155 typed-signal declaration.

**Control Manifest Rules (Core layer)**:
- Required: `victory_condition_detected` emitted by TurnOrderRunner ONLY (sole-emitter rule); ROUND_CAP read via `BalanceConstants.get_const("ROUND_CAP")` (no direct file reads); player-side precedence in T7 evaluation (PLAYER_WIN check before PLAYER_LOSE per AC-18)
- Forbidden: emitting `battle_outcome_resolved` from Turn Order (Grid Battle owns this per ADR-0001 single-owner rule); using `(int)` cast on enum without parens per G-24; forgetting to register `victory_condition_detected` in the 4-signal whitelist (story-007 lint enforces against off-domain emissions)
- Guardrail: `_evaluate_victory()` O(N) — single pass over `_unit_states` to count alive faction units; AC-23 budget < 1ms (story-007 perf verifies)

---

## Acceptance Criteria

*From GDD `design/gdd/turn-order.md` §F-3 + §AC-16/AC-18/AC-22 + ADR-0011 §Decision §Emitted signals + §AC-18/AC-22 precedence rules, scoped to this story:*

- [ ] **AC-1** (TR-007) `_evaluate_victory() -> Variant` (returns int enum value or null) called at T7 (story-003 stub site) AND RE2; returns null if no decisive condition met (battle continues)
- [ ] **AC-2** (TR-007) On decisive condition: emits `GameBus.victory_condition_detected(result: int)` exactly once per battle; `result` is int enum value {PLAYER_WIN=0, PLAYER_LOSE=1, DRAW=2}
- [ ] **AC-3** (TR-007) After emit, `_round_state` transitions to BATTLE_ENDED; subsequent `_advance_turn` / `_begin_round` calls are no-ops (no further signal emissions; no further state mutation)
- [ ] **AC-4** (TR-018) RE2 round-cap DRAW: at end of round, if `_round_number >= BalanceConstants.get_const("ROUND_CAP") as int`, emit `victory_condition_detected(DRAW)`; ROUND_CAP=30 per ADR-0011
- [ ] **AC-5** (TR-018) Same-patch obligation: `assets/data/balance/balance_entities.json` gains `ROUND_CAP: 30` key; verified by lint scaffold (story-007 enforces)
- [ ] **AC-6** (TR-020) AC-18 player-side precedence: in T7 `_evaluate_victory()`, PLAYER_WIN check executes BEFORE PLAYER_LOSE — mutual kill scenario (both faction counts hit 0 same T7) → emit PLAYER_WIN, NOT PLAYER_LOSE
- [ ] **AC-7** (TR-020) AC-22 T7 emit precedence: T7 `_evaluate_victory` emits BEFORE RE2 `_evaluate_round_cap` (synchronous order); Round 30 final unit's T7 PLAYER_WIN suppresses subsequent RE2 DRAW emit
- [ ] **AC-8** **GDD AC-16 F-3 Round Cap DRAW at Round 30** — Round 30 with units alive on both sides, last unit completes T7 without victory-condition detection → RE2 evaluates `_round_number >= ROUND_CAP` true → emits `victory_condition_detected(DRAW)`; RE3 never executes
- [ ] **AC-9** **GDD AC-18 EC-04 Mutual Kill PLAYER_WIN** — last player unit A attacks last enemy B; B dies from attack, A dies from counter-attack; T7 evaluates → emits `victory_condition_detected(PLAYER_WIN)`; PLAYER_WIN checked BEFORE PLAYER_LOSE
- [ ] **AC-10** **GDD AC-22 EC-19 T7 WIN Beats RE2 DRAW in Round 30** — Round 30, last enemy dies at T7 → emits `victory_condition_detected(PLAYER_WIN)` synchronously at T7 (BEFORE RE2 evaluation); RE1/RE2/RE3 never execute; WIN takes precedence over DRAW
- [ ] **AC-11** Regression baseline maintained: ≥6 new tests; full suite ≥604 cases / 0 errors / ≤1 carried failure / 0 orphans

---

## Implementation Notes

*Derived from ADR-0011 §Decision §Emitted signals + §AC-18/AC-22 precedence rules + §F-3 round cap + ADR-0001 §3 single-owner rule:*

1. **VictoryResult enum** declared INSIDE TurnOrderRunner (consumers reference as int per ADR-0001 line 155 typed-signal):
   ```gdscript
   enum VictoryResult { PLAYER_WIN = 0, PLAYER_LOSE = 1, DRAW = 2 }
   ```

2. **`_evaluate_victory()` implementation** — player-side precedence per AC-18:
   ```gdscript
   func _evaluate_victory() -> Variant:
       var player_alive: int = 0
       var enemy_alive: int = 0
       for state: UnitTurnState in _unit_states.values():
           if state.turn_state == TurnState.DEAD:
               continue
           # is_player_controlled cached in UnitTurnState (per story-002 §Implementation Notes Item 1 decision)
           if state.is_player_controlled:
               player_alive += 1
           else:
               enemy_alive += 1
       # AC-18 player-side precedence: check PLAYER_WIN BEFORE PLAYER_LOSE
       if enemy_alive == 0:
           return VictoryResult.PLAYER_WIN   # includes mutual-kill case (player_alive may also be 0)
       if player_alive == 0:
           return VictoryResult.PLAYER_LOSE
       return null   # battle continues
   ```

3. **T7 hook in `_advance_turn`** — replace story-003's `_evaluate_victory_stub()` with real call:
   ```gdscript
   # In _advance_turn after T6 _mark_acted:
   var result: Variant = _evaluate_victory()
   if result != null:
       _emit_victory(result as int)
       return   # AC-3: subsequent _advance_to_next_queued_unit suppressed
   _advance_to_next_queued_unit()
   ```

4. **RE2 round-cap check** — in `_end_round` (called after all queued units have completed turns):
   ```gdscript
   func _end_round() -> void:
       _round_state = RoundState.ROUND_ENDING
       # RE1: per-round cleanup hooks (deferred to consumers via signal — no direct call here)
       # RE2: round-cap check — AC-22 precedence already handled (T7 _evaluate_victory ran before this)
       if _round_number >= (BalanceConstants.get_const("ROUND_CAP") as int):
           _emit_victory(VictoryResult.DRAW)
           return
       # RE3: trigger next round
       _begin_round.call_deferred()
   ```

5. **`_emit_victory` helper** — single-emit guard + state transition:
   ```gdscript
   func _emit_victory(result: int) -> void:
       if _round_state == RoundState.BATTLE_ENDED:
           return   # AC-3 single-emit guard
       _round_state = RoundState.BATTLE_ENDED
       GameBus.victory_condition_detected.emit(result)
   ```

6. **AC-22 precedence verification** — story-006 test emits `unit_died` for last enemy at T5 (counter-attack scenario) on Round 30 → `_advance_turn` reaches T7 BEFORE `_end_round` runs → `_evaluate_victory` returns PLAYER_WIN → `_emit_victory(PLAYER_WIN)` fires → `_round_state` = BATTLE_ENDED → subsequent `_end_round` (if it ever runs) detects BATTLE_ENDED and short-circuits.

7. **ROUND_CAP same-patch append** — `assets/data/balance/balance_entities.json` add key `"ROUND_CAP": 30` under appropriate parent group (likely `turn_order` or `combat_meta`). Same JSON edit can include CHARGE_THRESHOLD from story-005 if both stories land in the same patch; otherwise each story owns its own append.

8. **G-24 enum cast in parens** — when comparing or assigning enum values, wrap `(int)` cast in parens:
   ```gdscript
   # CORRECT
   var result: int = _evaluate_victory() as int
   GameBus.victory_condition_detected.emit(result)

   # FORBIDDEN per G-24 — operator precedence trap
   GameBus.victory_condition_detected.emit(_evaluate_victory() as int)   # if this becomes part of a larger expression, as int binds wrong
   ```

9. **Cross-system note**: Grid Battle (Feature, unwritten ADR) consumes `victory_condition_detected` and emits authoritative `battle_outcome_resolved` per ADR-0001 single-owner rule. Turn Order does NOT directly emit `battle_outcome_resolved` (story-007 lint enforces). Tests in this story only assert `victory_condition_detected` emission; Grid Battle's downstream `battle_outcome_resolved` is out of scope.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 003**: T1-T7 sequence wiring (this story replaces the T7 stub with real `_evaluate_victory` call)
- **Story 004**: declare_action (this story's victory check evaluates AFTER declare_action effects via T6→T7 sequence)
- **Story 005**: GameBus.unit_died subscription + R-1 + R-2 + Charge F-2 (this story's tests USE the death-handled queue state from story-005)
- **Story 007**: 5 forbidden_patterns lint (including `turn_order_signal_emission_outside_domain` which validates the 4-signal whitelist) + perf baseline + Polish-tier scaffolds + TD entries
- **Grid Battle (unwritten ADR)**: authoritative `battle_outcome_resolved` emission downstream of `victory_condition_detected`

---

## QA Test Cases

*Lean mode — orchestrator-authored:*

**AC-1 _evaluate_victory return**:
- Given: 2-unit roster (1 player + 1 enemy), both alive
- When: `runner._evaluate_victory()`
- Then: returns null (battle continues)
- Edge case: kill enemy (turn_state = DEAD) → returns VictoryResult.PLAYER_WIN; kill player → returns VictoryResult.PLAYER_LOSE

**AC-2 victory_condition_detected emit**:
- Given: kill all enemies (set turn_state = DEAD); signal_log capture on `GameBus.victory_condition_detected`
- When: `_evaluate_victory()` returns PLAYER_WIN AND `_emit_victory(0)` invoked (or T7 path triggers it)
- Then: signal_log == [{result: 0}]; emit count == 1

**AC-3 single-emit guard + BATTLE_ENDED state**:
- Given: post-emit state (`_round_state == BATTLE_ENDED`)
- When: subsequent `_advance_turn(uid)` OR `_begin_round()` OR `_emit_victory(2)` invocations
- Then: no further signals emitted; state mutations suppressed

**AC-4 RE2 round-cap DRAW**:
- Given: `_round_number = 30`; both factions alive (`_evaluate_victory` returns null)
- When: `_end_round()` reaches RE2
- Then: signal_log contains {result: 2} (DRAW); state = BATTLE_ENDED

**AC-5 ROUND_CAP append**:
- Given: `assets/data/balance/balance_entities.json`
- When: grep ROUND_CAP
- Then: 1 match; value 30

**AC-6 AC-18 player-side precedence (mutual kill)**:
- Given: 1 player + 1 enemy; both alive at start of T7 evaluation (manually set both turn_state = DEAD to simulate mutual kill simultaneity)
- When: `_evaluate_victory()`
- Then: returns VictoryResult.PLAYER_WIN (NOT PLAYER_LOSE; player-side check executed first)

**AC-7 AC-22 T7 emit precedence over RE2**:
- Given: Round 30, queue [P1, E1], _queue_index = 1 (last unit E1's turn); E1 dies during T5 (counter-attack)
- When: T7 fires for E1; `_evaluate_victory` returns PLAYER_WIN; `_emit_victory(PLAYER_WIN)`; `_round_state = BATTLE_ENDED`
- Then: signal_log first entry is {result: 0}; subsequent `_end_round` short-circuits (does NOT emit DRAW); signal_log size == 1

**AC-8 GDD AC-16 DRAW at Round 30**:
- Given: Round 30 sets up; both factions still have alive units at end of round
- When: all units complete T7 (none decisive); `_end_round()` runs
- Then: emit DRAW; RE3 (story-003 _begin_round.call_deferred) does NOT fire

**AC-9 GDD AC-18 mutual kill PLAYER_WIN**:
- Given: 1 player A + 1 enemy B; A attacks B; B dies; B's counter-attack kills A; T7 for A's turn evaluates
- When: `_evaluate_victory` runs after both deaths processed (test-controlled: emit unit_died for B + await + emit unit_died for A + await)
- Then: returns PLAYER_WIN; signal_log {result: 0}

**AC-10 GDD AC-22 T7 WIN beats RE2 DRAW**:
- Given: Round 30; queue [P1, E1] both alive at start; player attack kills E1 at T5; T7 fires
- When: T7 evaluates → PLAYER_WIN emit
- Then: signal_log == [{result: 0}]; `_end_round` not called (or short-circuits); RE2 ROUND_CAP check never fires

**AC-11 Regression**:
- Given: full GdUnit4 suite
- Then: ≥604 cases / 0 errors / 1 carried failure / 0 orphans

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/turn_order_victory_detection_test.gd` — new file (~10 tests covering AC-1..AC-10)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (5 fields + RefCounted + RoundState/TurnState enums) + Story 002 (initialize_battle for setup) + Story 003 (T1-T7 sequence wiring + T7 stub site) + Story 005 (death-handled queue state for AC-9 mutual kill scenario)
- Unlocks: Story 007 (lint validates ROUND_CAP append + 4-signal whitelist + perf baseline includes _evaluate_victory)
