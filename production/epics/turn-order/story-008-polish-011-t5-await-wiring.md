# Story 008: POLISH-011 absorption — ADR-0011 §Decision Contract 5 Callable controller wiring + T5 await

> **Epic**: Turn Order
> **Status**: Complete (2026-05-10 sprint-15 S15-A — 7/7 ACs verified; 7 new tests; full-suite 1288→1295 PASS; pre-existing hp_status_perf flap unrelated)
> **Layer**: Core
> **Type**: Integration
> **Estimate**: 3-5h (~0.4d)
> **Manifest Version**: 2026-04-20
> **Sprint**: sprint-15 (S15-A) — entry blocker for S15-B/C/D
> **Backlog**: POLISH-011 (CRITICAL release-blocker; gates Production advancement)

## Context

**GDD**: `design/gdd/turn-order.md`
**Requirement**: `TR-turn-order-005` (initialize_battle + declare_action + _advance_turn) + ADR-0011 §Decision Contract 5 (Callable controller dispatch — `controller.call(unit_id, queue_snapshot)` synchronous form)

**ADR Governing Implementation**: ADR-0011 — Turn Order — §Decision Contract 5 implementation patch (Callable controller wiring at T5; await-until-declare_action behavior); ADR-0001 (single-emitter rule preserved); ADR-0010 (T5 holds before T6 unit_turn_ended emit)

**ADR Decision Summary**: ADR-0011 §Decision Contract 5 mandates that `_execute_action_budget` dispatches to an externally-injected Callable controller (`controller.call(unit_id, queue_snapshot)`). Story-005 (turn-order story-005, shipped 2026-05-01) was obligated to wire this dispatch but shipped a stub body (`pass`) at `turn_order_runner.gd:561-562` — comment notes "Story-005 wires the Callable controller injection" but the implementation never landed. The natural battle loop reaches T5 → returns immediately → T6 → next unit, executing all units across deferred slots in 2-3 seconds → DRAW at ROUND_CAP=30. POLISH-011 root cause #1 of 3.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (R1 from sprint-15 plan: T5 await mechanism design may surface additional ADR-0011 amendment scope)
**Engine Notes**: `Callable` (Godot 4.0+ stable); `Callable.call(...)` synchronous form per ADR-0011 §Decision Contract 5; T5 hold-and-release semantics require state-machine pause until external `declare_action()` mutates UnitTurnState; `_advance_turn` per-T-step deferred chain must NOT short-circuit T5 → T6 advancement

**Control Manifest Rules (Core layer)**:
- Required: T5 must AWAIT until `declare_action()` is called for the active unit (state-machine pause); ADR-0011 amendment ratifies the await mechanism
- Forbidden: Direct synchronous T6 emit immediately after T5 dispatch (would re-introduce the stub behavior); modifying any of the 5 forbidden_patterns in architecture.yaml (consumer_mutation + external_queue_write + signal_emission_outside_domain + static_var_state_addition + typed_array_reassignment)
- Guardrail: ADR-0011 §Decision Contract 5 amendment must include the await mechanism contract; integration test must drive T5 hold-and-release without direct test-seam advance_turn calls (G-30 mitigation per sprint-15 S15-D paired infrastructure)

---

## Acceptance Criteria

*From sprint-15.md S15-A acceptance criteria + ADR-0011 §Decision Contract 5:*

- [ ] **AC-1** `_execute_action_budget(unit_id)` body at `src/core/turn_order_runner.gd:561` implements Callable controller dispatch per ADR-0011 §Decision Contract 5 (`controller.call(unit_id, queue_snapshot)` synchronous form). Stub `pass` body removed.
- [ ] **AC-2** T5 holds (state-machine pause) until `declare_action()` is called for the active unit. T5 → T6 transition is GATED on declare_action mutation of UnitTurnState (token spend OR explicit WAIT/DEFEND).
- [ ] **AC-3** ADR-0011 amendment ratifies the await mechanism (state-machine pause contract; deferred-vs-synchronous tradeoffs documented per R1 mitigation in sprint-15 plan).
- [ ] **AC-4** Integration test `tests/integration/core/turn_order_t5_await_test.gd` drives single-turn flow: `initialize_battle(roster)` → `_begin_round.call_deferred()` → wait for T5 hold → call `declare_action(unit_id, ActionType.WAIT, target)` → assert T6 fires → assert `unit_turn_ended` emit. NO direct `_advance_turn` test-seam calls.
- [ ] **AC-5** 1288 baseline preserved + new tests added (count: ~1290-1292 after story close depending on integration test count).
- [ ] **AC-6** Controller injection mechanism: `TurnOrderRunner` accepts a Callable controller via constructor or setter (per ADR-0011 §Decision Contract 5 — exact injection shape TBD by amendment); GridBattleController injects a controller dispatch at battle init.
- [ ] **AC-7** Backward compat with story-001..007 unit/integration tests — existing tests that call `_advance_turn(unit_id)` directly (test-seam) continue to PASS without regression.

---

## Implementation Notes

*Derived from ADR-0011 §Decision Contract 5 + POLISH-011 TRIAGE FINDING block at `production/polish-backlog.md`:*

1. **T5 stub location**: `src/core/turn_order_runner.gd:561-562`
   ```gdscript
   ## Story-003 STUB — body intentionally empty.
   ## Story-004 implements declare_action() + token validation + DEFEND_STANCE locks.
   ## Story-005 wires the Callable controller injection per ADR-0011 §Decision Contract 5
   ## (`controller.call(unit_id, queue_snapshot)` synchronous form).
   func _execute_action_budget(_unit_id: int) -> void:
       pass
   ```
   Story-005 closure was incomplete; this story closes the gap.

2. **Await mechanism design** — two candidate patterns per R1:
   - (a) **Deferred await via state flag**: T5 sets `_round_state = AWAITING_ACTION`; declare_action transitions to `_round_state = ACTION_DECLARED`; T6 deferred check pulls based on flag. Simpler; no Godot await primitives.
   - (b) **Async coroutine `await`**: T5 awaits a custom signal `_action_declared(unit_id)` emitted from declare_action; resumes T6. Cleaner state machine but introduces coroutine complexity in core runner.
   Recommend (a) for MVP per state-machine simplicity; ADR amendment locks the choice.

3. **Controller injection point** — ADR-0011 §Decision Contract 5 originally specified Callable injection but did not lock injection shape. Two options:
   - (a) Constructor: `TurnOrderRunner.new(controller: Callable)` — fails for `extends Node` (no constructor args allowed for autoload-form Nodes; battle-scoped here is OK but constraints apply)
   - (b) Setter: `set_action_controller(controller: Callable)` called by GridBattleController at battle init before `initialize_battle()`. Recommended.

4. **Integration test pattern** — mirrors S15-D natural-loop infrastructure (paired story); uses `_begin_round.call_deferred()` natural progression + waits for T5 state via `await get_tree().process_frame` loop polling on `_round_state == AWAITING_ACTION`. Test seam usage limited to inspection (read `_round_state`); no direct mutator calls.

5. **G-30 mitigation** — this story's integration test is a foundational mitigation for G-30 verification gap pattern (windowed-mode lifecycle behavior not exercised by headless seams). Pairs with S15-D natural-loop test infrastructure.

6. **Backward compat** — existing tests that call `_advance_turn(unit_id)` directly bypass T5 (story-001..007 pattern). The new T5 dispatch must check whether a controller is injected; if NOT, fall back to existing stub behavior (preserves test-seam discipline). Only the natural-loop path requires controller injection.

7. **Performance budget** — no performance impact expected. The state-flag await mechanism is O(1) per T-step deferred-chain poll; Callable dispatch is a single synchronous call per T5 entry (one per unit-turn, not per-frame). No hot-path allocations introduced (no new typed arrays, dictionaries, or per-turn object construction). AC-5 (1288 baseline preserved) guards against regression in turn_order_perf_test.gd budgets (initialize_battle < 50ms / get_acted_this_turn × 1000 < 5ms / get_charge_ready × 1000 < 10ms / get_turn_order_snapshot × 100 < 25ms per story-007 AC-1).

---

## Dependencies

- **Depends On**: None (entry blocker for sprint-15 POLISH-011 absorption arc)
- **Blocks**: S15-B (AISystem subscriber needs T5 await before declare_action plumbing), S15-C (player declare_action plumbing), S15-D (natural-loop integration test), S15-E (gate-check rerun-4 PASS verdict)

## Test Evidence

- **Type**: Integration (cross-system: turn-order ↔ controller ↔ test harness)
- **Location**: `tests/integration/core/turn_order_t5_await_test.gd` (NEW)
- **Gate Level**: BLOCKING per `.claude/docs/coding-standards.md` Test Evidence Matrix

## Out of Scope

- AISystem.ai_action_ready subscriber wiring (S15-B scope)
- Player grid-click declare_action plumbing (S15-C scope)
- Full natural-loop battle-end-to-end integration test (S15-D scope; this story's test is single-turn only)
- WorkerThreadPool deferral or async-await coroutine refactor of the entire turn loop (post-MVP; out of POLISH-011 closure scope)
- ADR-0014/0019 amendments (S15-B/C scope)

## Risks

- **R1** (from sprint-15 plan): T5 await mechanism design may surface additional ADR-0011 amendment scope. Mitigation: 0.6d sprint-15 buffer; amendment can be split into 2 (initial wire-up here; refinement at sprint-16 if needed).
- **R2**: Existing test-seam pattern (story-001..007 direct `_advance_turn` calls) breaks if T5 await blocks regardless of injection. Mitigation: AC-7 backward-compat requirement; null-controller fallback to stub behavior preserves the seam.

## Completion Notes

**Completed**: 2026-05-10
**Criteria**: 7/7 passing (AC-1..AC-7 all verified via `tests/integration/core/turn_order_t5_await_test.gd` + ADR amendment doc)
**Test count delta**: 1288 → 1295 (7 new tests; full-suite verified 2026-05-10 — 1 pre-existing `hp_status_perf_test::test_apply_status_perf_under_gate` timing flap unrelated to S15-A)
**Deviations**: 1 ADVISORY — Manifest Version 2026-04-20 in story header is older than current 2026-05-05; risk LOW (intervening manifest changes were Feature/Presentation layer rules; story is Core layer)
**Test Evidence**: Integration — `tests/integration/core/turn_order_t5_await_test.gd` (7 tests; 0 errors / 0 failures)
**Code Review**: Complete (godot-gdscript-specialist + qa-tester via /code-review 2026-05-10; verdict APPROVED WITH SUGGESTIONS after AC-4 natural-loop test added)
**ADR Amendment Applied**: `docs/architecture/ADR-0011-turn-order.md` §Amendment 2026-05-09 — S15-A: T5 Await Mechanism (Sprint-15 POLISH-011 Closure)
**Follow-up unblocked**: S15-B (AISystem subscriber + declare_action plumbing) + S15-C (player declare_action plumbing in grid-click handlers) + S15-D (full-battle natural-loop test) + S15-E (gate-check rerun-4)
**Suggestions deferred**: DEFEND path explicit test, controller error handling, null controller mid-battle, victory in natural-loop (qa-tester NICE-TO-ADD list — defer to S15-D or polish ticket)
