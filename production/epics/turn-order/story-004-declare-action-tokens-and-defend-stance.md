# Story 004: declare_action + token validation + DEFEND_STANCE locks + 5 ActionType enum

> **Epic**: Turn Order
> **Status**: Ready
> **Layer**: Core
> **Type**: Logic
> **Estimate**: 2-3h
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/turn-order.md`
**Requirement**: `TR-turn-order-005`, `TR-turn-order-012`, `TR-turn-order-013`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0011 — Turn Order — declare_action mutator + CR-3 action budget + CR-4 ActionType enum
**ADR Decision Summary**: TR-005 = `declare_action(unit_id: int, action: ActionType, target: ActionTarget) -> ActionResult` validates token availability + DEFEND_STANCE locks per CR-3 + CR-4. TR-012 = CR-3 action budget — 1 MOVE + 1 ACTION token per turn; reset to FRESH at T4; CR-3f acted_this_turn iff at least one token spent. TR-013 = CR-4 5 ActionType enum (MOVE / ATTACK / USE_SKILL / DEFEND / WAIT); validation + DEFEND_STANCE locks (CR-4c — DEFEND_STANCE applied via HP/Status SE-3 prevents subsequent ACTION-token-spending until expiry); WAIT does not reposition (CR-8) — sets acted_this_turn = false + turn_state = DONE; failed validation returns `ActionResult{success: false, error_code: ActionError, side_effects: []}`.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: ActionType + ActionError typed enums (4.0+ stable); ActionTarget RefCounted typed wrapper or polymorphic Variant (decision deferral — orchestrator at /dev-story chooses); ActionResult RefCounted typed wrapper. DEFEND_STANCE check requires HP/Status query — soft-dep on ADR-0010 §Public API; for tests, use a stub HP/Status emitter.

**Control Manifest Rules (Core layer)**:
- Required: declare_action validates BEFORE mutation (no half-validated state); `ActionResult` RefCounted typed return (NOT Dictionary — typed contract per ADR-0011 §Decision); CR-3f acted_this_turn computation honest about token-spend state (no false positives)
- Forbidden: mutating UnitTurnState fields outside the validated declare_action path (forbidden_pattern `turn_order_external_queue_write` covers _queue + _unit_states; story-007 lint enforces); WAIT triggering queue repositioning (CR-8 — WAIT must NOT move unit to queue back; CR-8 explicit; AC-11)
- Guardrail: declare_action validation O(1) — Dictionary lookup + 1-2 boolean checks + DEFEND_STANCE query; no scan of _queue or other units

---

## Acceptance Criteria

*From GDD `design/gdd/turn-order.md` §CR-3 + §CR-4 + §CR-8 + ADR-0011 §Decision §Public mutator API, scoped to this story:*

- [ ] **AC-1** (TR-005, TR-013) `declare_action(unit_id: int, action: ActionType, target: ActionTarget) -> ActionResult` accepts 5 ActionType values (MOVE / ATTACK / USE_SKILL / DEFEND / WAIT); rejects invalid enum values via `ActionResult{success: false, error_code: INVALID_ACTION_TYPE}`
- [ ] **AC-2** (TR-012) MOVE action spends MOVE token only: `move_token_spent = true`; ACTION token unchanged; valid only if MOVE token FRESH
- [ ] **AC-3** (TR-012) ATTACK / USE_SKILL spends ACTION token only: `action_token_spent = true`; MOVE token unchanged; valid only if ACTION token FRESH AND no DEFEND_STANCE active
- [ ] **AC-4** (TR-013, CR-3e) DEFEND spends ACTION token + applies DEFEND_STANCE (delegated to HP/Status — Turn Order side just spends the token + records the request via signal/return value): `action_token_spent = true`; MOVE LOCKED for remainder of turn (CR-4c — subsequent MOVE declarations rejected with error_code MOVE_LOCKED_BY_DEFEND_STANCE)
- [ ] **AC-5** (TR-012, CR-3f) `acted_this_turn` set true at T6 iff at least one token spent during T5 (verified via story-003 _mark_acted; this story ensures declare_action mutates the spend flags correctly)
- [ ] **AC-6** (TR-013, CR-8) WAIT spends NO token: `move_token_spent = false`, `action_token_spent = false` post-WAIT; sets `turn_state = DONE`; `acted_this_turn = false` at T6; NO queue repositioning (CR-8 explicit)
- [ ] **AC-7** Token re-spend rejected: declare_action(MOVE) twice → second call returns `ActionResult{success: false, error_code: TOKEN_ALREADY_SPENT}`; same for ACTION
- [ ] **AC-8** Failed validation does NOT mutate state: pre-call snapshot vs post-failed-call snapshot field-equal
- [ ] **AC-9** **GDD AC-03 Action Budget Order Flexibility** — given a unit with both tokens available, Attack→Move order succeeds: ATTACK spends ACTION + DEFEND_STANCE-not-yet-applied so MOVE next call succeeds + spends MOVE + acted_this_turn = true at T6
- [ ] **AC-10** **GDD AC-04 acted_this_turn MOVE-Only Sets True** — unit spends MOVE token only (no ACTION, no WAIT); T6 → acted_this_turn = true; ACTION forfeited (turn_state = DONE without re-prompt); unit_turn_ended(acted=true) emitted
- [ ] **AC-11** **GDD AC-05 acted_this_turn WAIT Leaves False** — unit selects WAIT without spending any token; T6 → acted_this_turn = false; both tokens forfeited; unit_turn_ended(acted=false) emitted; NO queue repositioning
- [ ] **AC-12** **GDD AC-06 DEFEND Spends ACTION and Locks MOVE** — unit with both tokens selects DEFEND → ACTION spent + DEFEND_STANCE applied + MOVE locked for remainder of turn; subsequent MOVE declaration returns error_code MOVE_LOCKED_BY_DEFEND_STANCE; acted_this_turn = true at T6
- [ ] **AC-13** **GDD AC-11 No Delay WAIT Does Not Reposition** — unit third in queue selects WAIT at T4 → T6 unit in DONE state at original queue position (queue index 2 unchanged); pointer advances to fourth unit (index 3); no queue-back movement
- [ ] **AC-14** Regression baseline maintained: ≥10 new tests; full suite ≥592 cases / 0 errors / ≤1 carried failure / 0 orphans

---

## Implementation Notes

*Derived from ADR-0011 §Decision §Public mutator API + GDD §CR-3 + §CR-4 + §CR-8:*

1. **ActionType enum** declared INSIDE TurnOrderRunner (nested per ADR-0011 §State Ownership):
   ```gdscript
   enum ActionType { MOVE, ATTACK, USE_SKILL, DEFEND, WAIT }
   enum ActionError { NONE, INVALID_ACTION_TYPE, TOKEN_ALREADY_SPENT, MOVE_LOCKED_BY_DEFEND_STANCE, UNIT_NOT_FOUND, NOT_UNIT_TURN }
   ```

2. **ActionResult RefCounted wrapper** (4th wrapper class — gates ADR-0011 §State Ownership wrapper count check):
   ```gdscript
   class_name ActionResult extends RefCounted
   var success: bool = false
   var error_code: TurnOrderRunner.ActionError = TurnOrderRunner.ActionError.NONE
   var side_effects: Array = []   # untyped Array per ADR-0011 — heterogeneous payload
   ```
   NOTE: this is technically a 4th RefCounted wrapper; ADR-0011 §State Ownership lists 3. Orchestrator at /dev-story decides: (a) update ADR-0011 §State Ownership to "3 + ActionResult = 4 wrappers" via in-flight ADR amendment; OR (b) collapse ActionResult into a Dictionary return type. Recommend (a) — typed return is the project standard per ADR-0012 / ADR-0010 precedent.

3. **DEFEND_STANCE check** — soft-dep on HP/Status (ADR-0010); for tests, use a stub:
   ```gdscript
   func _is_defend_stance_active(unit_id: int) -> bool:
       # TODO story-005+: query HP/Status for active SE-3 DEFEND_STANCE on unit_id
       # Stub: read from a test-only Dictionary[int, bool] _test_defend_stance_state
       return _test_defend_stance_state.get(unit_id, false)
   ```
   When ADR-0010 epic ships (S2-07), this stub is replaced with `HPStatusController.has_status_effect(unit_id, StatusEffect.DEFEND_STANCE)`.

4. **CR-8 WAIT non-repositioning** — WAIT path in declare_action:
   ```gdscript
   ActionType.WAIT:
       state.move_token_spent = false
       state.action_token_spent = false
       state.turn_state = TurnState.DONE
       # acted_this_turn stays false (set at T6 _mark_acted based on tokens spent)
       return ActionResult.success_result()
   ```
   No `_queue.append(_queue.pop_front())` or similar reposition logic. Test asserts `_queue` content unchanged + `_queue_index` unchanged after WAIT.

5. **G-15 obligation reminder** — story-007 lint scaffold validates `before_test` resets all 5 instance fields + disconnects `unit_died` signal. This story's tests still need explicit `before_test` reset to avoid cross-test state leak; pattern matches story-001..003 precedent.

6. **AC-9 Attack→Move order**: critical sequence — ATTACK first (ACTION spent, no DEFEND_STANCE applied since ATTACK ≠ DEFEND), then MOVE second (MOVE token still FRESH, no DEFEND_STANCE block). Both succeed. acted_this_turn = true at T6.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 003**: T1-T7 sequence wiring (this story implements T5 declare_action contents; story-003 already wired T5 hand-off in `_execute_action_budget`)
- **Story 005**: GameBus.unit_died subscription + R-1 CONNECT_DEFERRED + Charge F-2 (this story does NOT implement charge accumulation — F-2 is story-005)
- **Story 006**: T7 victory check + 4th emitted signal (this story's declare_action doesn't trigger victory checks directly; T7 in story-003 calls a stub _evaluate_victory)
- **Story 007**: 5 forbidden_patterns lint + perf baseline + G-15 6-element reset list lint + Polish-tier scaffolds + TD entries

---

## QA Test Cases

*Lean mode — orchestrator-authored:*

**AC-1 ActionType validation**:
- Given: post-initialize_battle state with 1 unit; unit's turn (T4 reached, ACTING state)
- When: `runner.declare_action(unit_id, 99, null)` (invalid enum int — out of range)
- Then: returns ActionResult{success: false, error_code: INVALID_ACTION_TYPE}; UnitTurnState unchanged

**AC-2 MOVE token spend**:
- Given: unit in ACTING state, both tokens FRESH
- When: `declare_action(unit_id, ActionType.MOVE, target)`
- Then: returns ActionResult{success: true}; `_unit_states[unit_id].move_token_spent == true`; action_token_spent unchanged

**AC-3 ATTACK / USE_SKILL token spend**:
- Given: unit in ACTING state, both tokens FRESH, no DEFEND_STANCE active
- When: `declare_action(unit_id, ActionType.ATTACK, target)`
- Then: ActionResult{success: true}; action_token_spent = true; move_token_spent unchanged
- Edge case: USE_SKILL identical behavior

**AC-4 DEFEND spends ACTION + locks MOVE**:
- Given: unit in ACTING state, both tokens FRESH
- When: `declare_action(unit_id, ActionType.DEFEND, target)`
- Then: ActionResult{success: true}; action_token_spent = true; subsequent `declare_action(unit_id, ActionType.MOVE, target)` returns error_code MOVE_LOCKED_BY_DEFEND_STANCE

**AC-7 Token re-spend rejected**:
- Given: unit with `move_token_spent = true`
- When: `declare_action(unit_id, ActionType.MOVE, target)` second call
- Then: ActionResult{success: false, error_code: TOKEN_ALREADY_SPENT}; UnitTurnState field-equal to pre-call snapshot

**AC-8 Failed validation no-mutation**:
- Given: pre-call UnitTurnState snapshot
- When: declare_action that fails validation (e.g., re-spend)
- Then: post-call UnitTurnState field-by-field equal to pre-call snapshot (use UnitTurnState.snapshot() comparison)

**AC-9 GDD AC-03 Attack→Move flexibility**:
- Given: unit ACTING with both tokens FRESH
- When: `declare_action(MOVE)` after `declare_action(ATTACK)` (Attack first)
- Then: both succeed; both tokens spent; trigger T6 (via _mark_acted) → acted_this_turn = true

**AC-10 GDD AC-04 MOVE-only sets acted=true**:
- Given: unit ACTING; declare_action(MOVE) only
- When: T6 fires (via _advance_turn full-pipeline OR direct _mark_acted call)
- Then: acted_this_turn = true; signal_log contains unit_turn_ended{acted: true}

**AC-11 GDD AC-05 WAIT leaves acted=false**:
- Given: unit ACTING; declare_action(WAIT)
- When: T6 fires
- Then: acted_this_turn = false; both tokens still FRESH; turn_state = DONE; signal_log unit_turn_ended{acted: false}; `_queue` content unchanged + `_queue_index` advanced to next

**AC-12 GDD AC-06 DEFEND locks MOVE**:
- Given: unit ACTING; both tokens FRESH
- When: `declare_action(DEFEND)` THEN `declare_action(MOVE)`
- Then: first succeeds + applies DEFEND_STANCE; second returns error MOVE_LOCKED_BY_DEFEND_STANCE; T6 acted_this_turn = true (action token spent)

**AC-13 GDD AC-11 WAIT non-repositioning**:
- Given: 4-unit queue [U1, U2, U3, U4]; current `_queue_index = 2` (U3's turn)
- When: U3 declare_action(WAIT) → _advance_turn completes
- Then: `_queue == [U1, U2, U3, U4]` unchanged; `_queue_index` advances 2 → 3 (U4 next); U3.turn_state = DONE; no `_queue.append(U3)` mutation

**AC-14 Regression**:
- Given: full GdUnit4 suite
- Then: ≥592 cases / 0 errors / 1 carried failure / 0 orphans

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/core/turn_order_declare_action_test.gd` — new file (~10-12 tests)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 001 (module + 5 fields + RefCounted wrappers) + Story 002 (initialize_battle for setup) + Story 003 (T5 hand-off shape — _execute_action_budget hook point)
- Unlocks: Story 005 (death handling + R-1 needs declare_action wired since counter-attack flows through it), Story 006 (victory detection consumes acted_this_turn flags)
