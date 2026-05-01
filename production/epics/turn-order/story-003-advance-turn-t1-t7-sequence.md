# Story 003: _advance_turn T1..T7 sequence + state machine + 3 emitted signals

> **Epic**: Turn Order
> **Status**: Complete
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 3-4h
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/turn-order.md`
**Requirement**: `TR-turn-order-005`, `TR-turn-order-007`, `TR-turn-order-011`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011 — Turn Order — _advance_turn TEST SEAM + T1-T7 strict ordering + 3 of 4 emitted signals; ADR-0001 (GameBus single-emitter rule); ADR-0010 (HP/Status consumes unit_turn_started for T1 DoT tick + T3 status decrement)
**ADR Decision Summary**: TR-005 = `_advance_turn(unit_id: int) -> void` TEST SEAM (4-precedent extension of DI seam pattern; production-called via internal queue advancement; tests-called directly to bypass GameBus signal infrastructure). TR-007 = sole emitter of 3 signals in this story scope (round_started + unit_turn_started + unit_turn_ended); 4th signal `victory_condition_detected` is story-006 scope. TR-011 = T1-T7 strict ordering (DoT tick → death check → status decrement → activate → action budget → mark acted → victory check); state machine `_round_state` enum + internal `_advance_turn` driver enforces sequence.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: GameBus signal emission via `GameBus.round_started.emit(int)` etc. (4.0+ stable typed signal API); state machine via match-statement on enum (4.0+ stable). T5 action budget delegation invokes `controller.call(unit_id, queue_snapshot)` per Contract 5 — this story leaves T5 as a stub (story-004 implements full `declare_action` + token validation; story-003 just wires the T5 → controller.call hand-off shape).

**Control Manifest Rules (Core layer)**:
- Required: GameBus emit via typed signal API (NOT `emit_signal("name", args)` legacy form); _advance_turn TEST SEAM accessible via direct call (no underscore-prefix-makes-it-private illusion — GDScript convention only; GdUnit4 v6.1.2 calls `_advance_turn` directly with no reflection workaround)
- Forbidden: emitting any GameBus signal NOT in the 4-signal set (round_started + unit_turn_started + unit_turn_ended + victory_condition_detected); `turn_order_signal_emission_outside_domain` forbidden_pattern enforces this (story-007 lint scaffold)
- Guardrail: T1..T7 sequence MUST execute in strict order — no step skipped, reordered, or merged; state machine guards every transition

---

## Acceptance Criteria

*From GDD `design/gdd/turn-order.md` §CR-2 + ADR-0011 §Decision §Public mutator API §Emitted signals + §T1-T7 sequence, scoped to this story:*

- [ ] **AC-1** (TR-005, TEST SEAM) `_advance_turn(unit_id: int) -> void` callable directly from tests; no leading-underscore privacy enforcement; godot-specialist Item 7 compliant
- [ ] **AC-2** (TR-007) emits `GameBus.round_started(round_number: int)` at R4 (after queue construction in `_begin_round`); single emit per round
- [ ] **AC-3** (TR-007) emits `GameBus.unit_turn_started(unit_id: int)` at T4 (after `_activate_unit_turn` resets tokens + transitions UnitTurnState.turn_state to ACTING); one emit per turn
- [ ] **AC-4** (TR-007) emits `GameBus.unit_turn_ended(unit_id: int, acted: bool)` at T6 (after `_mark_acted` sets acted_this_turn flag based on token spend); one emit per turn
- [ ] **AC-5** (TR-011, T1-T2) T1 emits `unit_turn_started` (HP/Status consumes for DoT tick); T2 checks death — if `_unit_states[unit_id].turn_state == DEAD` (set by `_on_unit_died` between T1 and T2), short-circuits remaining T3-T7 steps
- [ ] **AC-6** (TR-011, T3) T3 status effect duration decrement step is a no-op stub in this story (HP/Status consumes `unit_turn_started` and runs decrements; Turn Order does NOT directly call HP/Status — fire-and-forget signal-driven contract)
- [ ] **AC-7** (TR-011, T4) `_activate_unit_turn(unit_id)` resets `move_token_spent=false`, `action_token_spent=false`, `accumulated_move_cost=0`, `acted_this_turn=false`; transitions `turn_state` IDLE → ACTING; emits `unit_turn_started`
- [ ] **AC-8** (TR-011, T5) T5 action budget execution delegates to `controller.call(unit_id, queue_snapshot)` per Contract 5 (Callable injected at BI-1 — story-002 deferred actual injection to story-005; this story uses a stub Callable for tests that returns a no-op ActionDecision)
- [ ] **AC-9** (TR-011, T6) `_mark_acted(unit_id)` sets `acted_this_turn = (move_token_spent OR action_token_spent)`; transitions `turn_state` ACTING → DONE; emits `unit_turn_ended(unit_id, acted_this_turn)`
- [ ] **AC-10** (TR-011, T7) T7 victory check is a no-op stub in this story (story-006 owns `_evaluate_victory()` + `victory_condition_detected` emit); story-003 reaches T7 and exits without emitting
- [ ] **AC-11** **GDD AC-02 Round Lifecycle Sequence** — given 2 alive units, both complete turns without battle-end → system executes in strict order R1→R2→R3→R4→[T1-T7 per unit]→RE1→RE2→RE3; no step skipped or reordered (asserted via signal emit order capture)
- [ ] **AC-12** Regression baseline maintained: ≥8 new tests; full suite ≥582 cases / 0 errors / ≤1 carried failure / 0 orphans

---

## Implementation Notes

*Derived from ADR-0011 §Decision §Public mutator API §Emitted signals + §T1-T7 sequence + ADR-0001 single-emitter rule:*

1. **State machine driver pattern** — `_round_state` enum drives the round lifecycle; `_advance_turn(unit_id)` drives the per-unit T1..T7 sequence. Match-statement on `_round_state` handles R1..RE3 transitions.

   **ERRATUM 2026-05-01 (story-003 close-out)**: the original pseudocode below showed `unit_turn_started.emit` at T1 before the T2 death check, but ADR-0011 §Decision §Emitted signals (line 220) authoritatively LOCKS the emit at T4 (after `_activate_unit_turn`). AC-3 in this story file (line 35) is correctly aligned with the ADR. The implementation places T2 short-circuit BEFORE `_activate_unit_turn`, so DEAD-on-arrival units emit NEITHER `unit_turn_started` NOR `unit_turn_ended` — `_advance_to_next_queued_unit()` is the only side effect. Validation Criterion #9 ("DoT death at T1 skips T2-T7") in ADR-0011 is deferred to Vertical Slice via story-007 TD-047 (cross-system Integration AC); it is achievable via HP/Status's T4 DoT tick consumer + deferred `_on_unit_died` queue removal, NOT via a T1 emit in Turn Order. The pseudocode below is preserved for historical record but must NOT be used as the implementation reference — see runner.gd `_advance_turn` for the authoritative form.

   ```gdscript
   func _begin_round() -> void:
       # R1: increment _round_number
       _round_number += 1
       # R2: alive units count
       # R3: rebuild queue via F-1 cascade (story-002 implementation)
       _rebuild_queue()
       # R4: emit round_started
       _round_state = RoundState.ROUND_ACTIVE
       _queue_index = 0
       GameBus.round_started.emit(_round_number)
       # Drive T1 of first unit
       if not _queue.is_empty():
           _advance_turn.call_deferred(_queue[0])

   func _advance_turn(unit_id: int) -> void:
       # NOTE: HISTORICAL PSEUDOCODE — see ERRATUM above. Authoritative form is in runner.gd.
       # T1: emit unit_turn_started for DoT tick path
       GameBus.unit_turn_started.emit(unit_id)
       # T2: check death (turn_state set to DEAD by _on_unit_died if it fired between T1 and T2)
       if _unit_states.get(unit_id, null) == null or _unit_states[unit_id].turn_state == TurnState.DEAD:
           # Skip remaining steps; advance to next queue position
           _advance_to_next_queued_unit()
           return
       # T3: status decrement (no-op in Turn Order — fire-and-forget per signal contract)
       # T4: activate unit turn
       _activate_unit_turn(unit_id)
       # T5: action budget (delegate to controller — story-004 owns full impl; story-003 stub)
       _execute_action_budget(unit_id)
       # T6: mark acted + emit unit_turn_ended
       _mark_acted(unit_id)
       # T7: victory check (story-006 owns; story-003 stub)
       _evaluate_victory_stub()
       # Advance to next queued unit OR end round
       _advance_to_next_queued_unit()
   ```

2. **GameBus emission pattern** — typed signal API form (godot-specialist Item 6):
   ```gdscript
   # CORRECT
   GameBus.round_started.emit(_round_number)
   GameBus.unit_turn_started.emit(unit_id)
   GameBus.unit_turn_ended.emit(unit_id, acted_this_turn)

   # FORBIDDEN (legacy form)
   emit_signal("round_started", _round_number)
   ```

3. **T5 stub for this story** — full `declare_action` implementation lands in story-004. For story-003 testing, `_execute_action_budget(unit_id)` is a 1-line method that calls a stub Callable:
   ```gdscript
   func _execute_action_budget(unit_id: int) -> void:
       if _unit_controller_callable.is_valid():
           _unit_controller_callable.call(unit_id, get_turn_order_snapshot())
       # Else no-op (test-stub path — proceeds straight to T6)
   ```
   `_unit_controller_callable` is a 6th instance field — **WAIT** — would exceed the 5-field ADR lock. Resolution: defer the Callable injection to story-005 where it's wired alongside the GameBus.unit_died subscription. For story-003 tests, hand-roll a synthetic test path that bypasses T5 entirely (test asserts T6 fires after T4 with default token state).

4. **G-15 obligation** — `before_test` resets `_unit_states.clear() + _queue.clear() + _round_number = 0 + _queue_index = 0 + _round_state = BATTLE_NOT_STARTED`. Full 6-element reset list (TR-019) is story-007 lint scope.

5. **Test signal capture pattern** — GdUnit4 signal capture via `var signal_log: Array = []; GameBus.unit_turn_started.connect(func(uid: int) -> void: signal_log.append({"signal": "unit_turn_started", "unit_id": uid}))`. Per G-4 lambda primitive-capture limitation: use Array.append, not direct primitive reassignment. Per G-10 autoload identifier binding: subscribe to REAL `/root/GameBus`, not stub.

6. **AC-11 GDD AC-02 round lifecycle sequence test** — fixture: 2-unit roster; assert signal emit order `round_started → unit_turn_started(unit 0) → unit_turn_ended(unit 0) → unit_turn_started(unit 1) → unit_turn_ended(unit 1)`. Use Array signal_log capture pattern.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: Module skeleton (gates this story)
- **Story 002**: initialize_battle BI-1..BI-6 + F-1 cascade (this story USES the post-init state via test fixture; doesn't re-implement)
- **Story 004**: declare_action + token validation + DEFEND_STANCE locks + 5 ActionType enum (this story stubs T5)
- **Story 005**: GameBus.unit_died subscription + CONNECT_DEFERRED + R-1 mitigation + Charge F-2 + Callable injection (this story stubs all of these)
- **Story 006**: T7 _evaluate_victory + 4th emitted signal victory_condition_detected (this story stubs T7)
- **Story 007**: Perf + 5 forbidden_patterns lint + G-15 6-element reset list lint + Polish-tier scaffold + TD entries

---

## QA Test Cases

*Lean mode — orchestrator-authored:*

**AC-1 _advance_turn TEST SEAM accessibility**:
- Given: post-initialize_battle state with 1 unit
- When: `runner._advance_turn(unit_id)` called directly from test (no reflection)
- Then: succeeds without parse error / privacy violation; T1 emits unit_turn_started

**AC-2 round_started emit at R4**:
- Given: post-initialize_battle state with 2 units; signal_log capture on GameBus.round_started
- When: `runner._begin_round()` called directly
- Then: signal_log[0] == {signal: "round_started", round_number: 1}; emit count == 1
- Edge case: second `_begin_round()` increments to 2 with another emit

**AC-3 unit_turn_started emit at T4**:
- Given: post-initialize_battle + _begin_round state; signal_log capture
- When: `_advance_turn(unit_id)` called for first queued unit
- Then: signal_log contains {signal: "unit_turn_started", unit_id: <expected>}; emit happens AFTER T4 _activate_unit_turn (state transition assertable: turn_state == ACTING when assertion runs synchronously after emit)

**AC-4 unit_turn_ended emit at T6**:
- Given: post-_advance_turn execution
- When: assert signal_log
- Then: contains {signal: "unit_turn_ended", unit_id: <expected>, acted: <expected>}; emit happens AFTER T6 _mark_acted

**AC-5 T2 death short-circuit**:
- Given: post-initialize_battle + manual transition `_unit_states[unit_id].turn_state = DEAD` (simulating death between T1 and T2)
- When: `_advance_turn(unit_id)` called
- Then: T1 unit_turn_started fires; T3-T7 steps skipped (no T6 unit_turn_ended emitted); _queue_index advances to next position
- Edge case: unit_id NOT in _unit_states (already removed by _on_unit_died — story-005 path) → T1 still emits (signal payload is unit_id; HP/Status decides whether to handle), T2 check defensive _unit_states.has() short-circuits

**AC-7 T4 token reset**:
- Given: pre-call state with `_unit_states[unit_id].move_token_spent = true`
- When: `_advance_turn(unit_id)` reaches T4
- Then: `_unit_states[unit_id]` has all 4 tokens reset to false/0; turn_state == ACTING

**AC-9 T6 acted_this_turn computation**:
- Given: post-T4 state with `move_token_spent = true, action_token_spent = false`
- When: `_advance_turn` reaches T6
- Then: `_unit_states[unit_id].acted_this_turn == true`; signal_log contains {acted: true}; turn_state == DONE
- Edge case: both tokens false (WAIT path) → acted_this_turn = false; signal {acted: false}

**AC-11 GDD AC-02 Round Lifecycle Sequence**:
- Given: 2-unit roster post-initialize_battle; signal_log capture on all 3 signals
- When: `_begin_round()` triggers full round execution (T5 stubbed for both units)
- Then: signal_log order is [round_started(1), unit_turn_started(unit0), unit_turn_ended(unit0, false), unit_turn_started(unit1), unit_turn_ended(unit1, false)]; no signal out of order; no step skipped

**AC-12 Regression**:
- Given: full GdUnit4 suite
- Then: ≥582 cases / 0 errors / 1 carried failure / 0 orphans

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/turn_order_advance_turn_test.gd` — new file (~10 tests covering AC-1..AC-11)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (module + 5 fields + 3 RefCounted wrappers) + Story 002 (initialize_battle + queue construction + F-1 cascade)
- Unlocks: Story 004 (declare_action needs T5 hook), Story 005 (death handling needs T2 check + Callable wiring), Story 006 (T7 victory check)

---

## Completion Notes

**Completed**: 2026-05-01
**Criteria**: 11/12 ACs covered (AC-1..AC-5 + AC-7 + AC-9 + AC-11 explicit; AC-6 / AC-8 / AC-10 documented stubs deferred to stories 004/005/006 per §Out of Scope; AC-12 verified via full-suite regression). 1 AC partially-covered (AC-9 acted=true branch deferred to TD-046 — see Code Review Suggestions).
**Test Evidence**: `tests/unit/core/turn_order_advance_turn_test.gd` — 10 test functions (9 explicit + 1 bonus) / 10 PASS standalone (191ms); full regression 585→**595 / 0 errors / 1 carried failure / 0 orphans** (carried failure = pre-existing orthogonal `test_hero_data_doc_comment_contains_required_strings`; not introduced by this story); story-002 regression 12/12 PASS unaffected (snapshot 9-field expansion + T4 emit point remain stable).
**Code Review**: APPROVED WITH SUGGESTIONS (5 advisory items — 2 NITs applied in-place, 1 SUGGESTION applied in-place, 1 SUGGESTION deferred to TD-046, 1 POST-CLOSE story-doc erratum applied above).

### Files Modified (1)

- `src/core/turn_order_runner.gd` (344 → 437 LoC, +93) — `_advance_turn` T1-T7 driver (lines 167-190); `_begin_round` R1-R4 round-start with deferred-Callable form (lines 356-373); `_activate_unit_turn` T4 token-reset + IDLE→ACTING + `unit_turn_started` emit (lines 380-387); `_execute_action_budget` story-004 stub (lines 395-396); `_mark_acted` T6 OR-formula + DONE transition + `unit_turn_ended` emit (lines 403-407); `_evaluate_victory_stub` story-006 stub (lines 416-417); `_advance_to_next_queued_unit` queue-advance OR ROUND_ENDING transition (lines 424-429); `_on_unit_died` story-005 stub (lines 437-438). NIT-1 fix: removed duplicate BI-5 comment (line 147 of pre-fix → cleaned to lines 145-146 only). One blank line at EOF preserved.

### Files Created (1)

- `tests/unit/core/turn_order_advance_turn_test.gd` (660 LoC, 10 tests + 4 helpers) — covers AC-1..AC-11 with method-reference signal capture pattern (G-4 sidestep), G-15 5-field reset in `before_test`, G-10 real-GameBus subscription, G-16 typed-Array[Dictionary] for signal log + 4 filter sub-arrays, G-24 paren-wrapped enum casts. AC-11 `test_round_lifecycle_emit_order_two_units` uses 3-frame initial drain (NIT fix per /code-review SUGGESTION 4) + 3-frame post-`_begin_round()` drain to deterministically settle the deferred-Callable chain.

### Code Review Findings Resolved

| # | Severity | Action |
|---|----------|--------|
| 1 | NIT | **APPLIED IN-PLACE** — duplicate BI-5 comment at runner.gd line 147 deleted |
| 2 | NIT | **APPLIED IN-PLACE** — `_signal_log: Array` + 4 filter sub-arrays typed as `Array[Dictionary]` per G-16 (test:57, test:194, test:231, test:277, test:457) |
| 3 | SUGGESTION | **DEFERRED to TD-046** — AC-9 acted=true branch coverage; structurally untestable in story-003 scope (T4 unconditional reset + T5 stub); resolution path documented for story-004 declare_action close-out |
| 4 | SUGGESTION | **APPLIED IN-PLACE** — AC-11 test 3rd drain `await get_tree().process_frame` added before `_signal_log.clear()` to deterministically settle the queue[1]→ROUND_ENDING chain (test:526) |
| 5 | POST-CLOSE | **APPLIED IN-PLACE** — story §Implementation Notes #1 ERRATUM block prepended to historical pseudocode clarifying T4 emit per ADR-0011 §Decision §Emitted signals (line 220) authoritative form |

### ADR Compliance

- **ADR-0011** §Decision §Emitted signals (line 220) — `unit_turn_started` emit at T4 after `_activate_unit_turn`: COMPLIANT (runner.gd:387 inside `_activate_unit_turn`)
- **ADR-0011** §Decision §Single emitter scope — Turn Order Domain only (round_started + unit_turn_started + unit_turn_ended): COMPLIANT (no other GameBus signals emitted)
- **ADR-0011** §Decision §Forbidden patterns: `turn_order_typed_array_reassignment` respected (`_queue.clear() + .append_array()` — never reassigned); `turn_order_signal_emission_outside_domain` respected: COMPLIANT
- **ADR-0001** Single-emitter rule (Turn Order Domain): COMPLIANT
- **ADR-0010** `unit_turn_started(unit_id: int)` provisional consumer ratification: emit point at T4 matches the ratified contract verbatim: COMPLIANT

### Engineering Discipline

- **G-2** typed-array preservation throughout (no `.duplicate()` calls; `_queue.clear() + .append_array()` discipline)
- **G-4** lambda primitive-capture sidestepped via 3 method-reference capture handlers (`_capture_round_started` / `_capture_unit_turn_started` / `_capture_unit_turn_ended`)
- **G-7** verified Overall Summary count grew 585 → 595 (+10 new tests; 0 silent skips per G-7 verification pattern)
- **G-9** paren-wrap `%` format strings throughout test file (all multi-line `override_failure_message` constructions)
- **G-10** real `/root/GameBus` subscription in test (NOT a stub) — autoload identifier binding stability per G-10 prescription
- **G-14** import refresh executed post-write (`godot --headless --import --path .`); no parse errors
- **G-15** `before_test()` (canonical hook) used + 5-field reset list (`_unit_states.clear() + _queue.clear() + _round_number=0 + _queue_index=0 + _round_state=BATTLE_NOT_STARTED`); `after_test()` is_connected-guarded disconnect symmetry
- **G-16** typed-Array[Dictionary] applied post-/code-review for signal log + 4 filter sub-arrays
- **G-22** reflective static-state reset N/A (no static state)
- **G-23** safe assertions only (no `is_not_equal_approx`)
- **G-24** paren-wrapped `as int` enum casts throughout test file

### Forward Look (next stories unblocked)

- **Story 004** (`declare_action` + token validation + DEFEND_STANCE locks + 5 ActionType enum) — T5 hook now wired via `_execute_action_budget` stub; story-004 fills the body. TD-046 AC-9 acted=true coverage gap closes here.
- **Story 005** (GameBus.unit_died subscription + CONNECT_DEFERRED + R-1 mitigation + Charge F-2 + Callable injection) — `_on_unit_died` stub at line 437 awaits implementation; deferred-connect TODO comment at line 152 of `initialize_battle` flags the wire-up site.
- **Story 006** (T7 `_evaluate_victory` + 4th emitted signal `victory_condition_detected` + same-patch `game_bus.gd` amendment) — `_evaluate_victory_stub` placeholder at line 416 awaits implementation; signal declaration in game_bus.gd is the same-patch obligation.
