# Story 004: declare_action + token validation + DEFEND_STANCE locks + 5 ActionType enum

> **Epic**: Turn Order
> **Status**: Complete
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

---

## Completion Notes

**Completed**: 2026-05-01
**Criteria**: 14/14 ACs covered (AC-1..AC-13 explicit + AC-14 verified via full-suite regression) + 2 defensive coverage tests (negative-int INVALID_ACTION_TYPE branch + post-WAIT MOVE NOT_UNIT_TURN re-entry guard) added in /code-review close-out per qa-tester GAPS findings.
**Test Evidence**: `tests/unit/core/turn_order_declare_action_test.gd` — 16 test functions / 16 PASS standalone (229ms); full regression 595→**611 / 0 errors / 1 carried failure / 0 orphans** (carried failure = pre-existing orthogonal `test_hero_data_doc_comment_contains_required_strings`; not introduced).
**Code Review**: APPROVED WITH SUGGESTIONS — godot-gdscript-specialist 0 BLOCKING / 1 SUGGESTION (deferred — story-007 helper hardening) / 2 NITs (doc-only, no action); qa-tester GAPS verdict (non-blocking) — 2 concrete branch gaps APPLIED IN-PLACE (negative-int INVALID_ACTION_TYPE + WAIT-then-MOVE NOT_UNIT_TURN), 3 gaps DEFERRED with rationale (DEFEND-then-DEFEND + ATTACK-then-DEFEND structurally same-guard as AC-7; result.side_effects vacuous in story-004 scope).

### Files Created (3)

- `src/core/action_target.gd` (~30 LoC) — `class_name ActionTarget extends RefCounted` 2-field stub per IN-2 (target_unit_id + target_position; placeholder for Battle Preparation ADR / Grid Battle epic ratification with full terrain/range/LoS validation). Tests pass `null` for `target` arg throughout — typed `ActionTarget` parameter accepts null via GDScript 4.x nullable Object refs.
- `src/core/action_result.gd` (~80 LoC) — `class_name ActionResult extends RefCounted` 3-field typed return (success: bool + error_code: int + side_effects: Array) + 2 static factory methods (`make_success(side_effects_payload)` + `make_failure(error_code_value)`). `error_code` typed as `int` (NOT `TurnOrderRunner.ActionError`) to avoid forward-reference circular import — tests cast as `result.error_code as TurnOrderRunner.ActionError` per IN-2 option (a) typed-return path.
- `tests/unit/core/turn_order_declare_action_test.gd` (~860 LoC, 16 tests) — 14 ACs (AC-1..AC-13 + AC-14 via regression) + 2 defensive coverage gates (UNIT_NOT_FOUND + NOT_UNIT_TURN-when-IDLE) + 2 /code-review-driven branch coverage tests (negative-int INVALID_ACTION_TYPE per qa-tester Gap 1 + post-WAIT MOVE NOT_UNIT_TURN per qa-tester Gap 4). Pattern mirrors `turn_order_advance_turn_test.gd`: G-15 5-field reset in `before_test()`, method-reference signal capture (G-4 sidestep), G-16 typed-Array[Dictionary] for signal_log, G-10 real-GameBus subscription, G-24 paren-wrapped enum-int casts, G-9 paren-wrapped multi-line %-format strings. Helper `_setup_single_unit_at_t4(uid)` simulates post-T4 ACTING state for declare_action validation paths.

### Files Modified (2)

- `src/core/unit_turn_state.gd` (94 → 111 LoC, +17) — 9 → 10 fields (added `defend_stance_active: bool = false` after `is_player_controlled`); `snapshot()` extended to copy the new field; header doc-comment notes 10-field count + 2026-05-01 story-004 amendment date + cross-link to ADR-0011 §Decision §Typed Resource amendment paragraph.
- `src/core/turn_order_runner.gd` (~437 → ~580 LoC, ~+143) — 2 nested enums added after TurnState enum (ActionType + ActionError); `declare_action()` public mutator implementation REPLACES the prior 1-line stub; T4 reset path in `_activate_unit_turn` extended with `state.defend_stance_active = false` (now 6-field reset list — earmarked for story-007 G-15 lint scaffold).

### Same-Patch Amendments Landed

- **ADR-0011 §Decision §Typed Resource UnitTurnState code-block**: 9 → 10 fields update + 2026-05-01 prose amendment paragraph citing story-004 trigger + within-turn-vs-cross-turn DEFEND_STANCE persistence boundary + 6-field T4 reset list earmarked for story-007 G-15 lint scaffold
- **ADR-0011 §Decision §Wrapper count**: prose amendment paragraph documenting wrapper inventory growth from baseline-3 (UnitTurnState + TurnOrderSnapshot + TurnOrderEntry) through story-002 (+BattleUnit stub) to story-004 (+ActionResult + ActionTarget stub) — current count 6 (4 active + 2 stubs); §State Ownership "3 wrappers" prose superseded by `src/core/` authoritative inventory
- **TR-turn-order-004**: requirement text revised to enumerate 6 wrappers (4 active + 2 stubs) with field counts; `revised: "2026-05-01"` annotation already in place (carried from story-002 same-patch); added story-004 amendment trace at end of requirement string

### Code Review Findings Resolved (2026-05-01 close-out)

| # | Source | Severity | Action |
|---|--------|----------|--------|
| 1 | qa-tester Gap 1 | SUGGESTION | **APPLIED IN-PLACE** — `test_declare_action_invalid_action_type_negative_int_rejected` covers the `action < 0` branch of the line-259 guard (was untested; only `>= ActionType.size()` branch tested via 99-input) |
| 2 | qa-tester Gap 4 | SUGGESTION | **APPLIED IN-PLACE** — `test_declare_action_post_wait_move_rejected_with_not_unit_turn` covers cross-action-type re-entry guard (post-WAIT turn_state=DONE → MOVE returns NOT_UNIT_TURN) |
| 3 | qa-tester Gap 2 (DEFEND-then-DEFEND) | DEFERRED | Same `if state.action_token_spent` guard already covered by AC-7's ATTACK + USE_SKILL re-spend assertions. Branch coverage structurally sufficient. |
| 4 | qa-tester Gap 3 (ATTACK-then-DEFEND) | DEFERRED | Same as #3 — same-guard implied-test coverage. |
| 5 | qa-tester Gap 5 (result.side_effects) | DEFERRED | Vacuous in story-004 (no side_effects payloads defined). Story-005+ HP/Status integration will populate; assertions land then. |
| 6 | gdscript SUGGESTION (`_setup_single_unit_at_t4` deferred-noise) | DEFERRED | Latent for future tests asserting `_round_number` after the helper. Flag for story-007 helper-hardening scope. |
| 7 | gdscript NIT (AC-11 comment imprecision + AC-3 story-doc paraphrase) | NO ACTION | Documentation-only nits; no code change. |

### Code Review Design Choices (orchestrator pre-decided)

- **IN-2 ActionResult typed-return decision**: option (a) — RefCounted typed wrapper class (NOT Dictionary). Matches ADR-0010 / ADR-0012 typed-return precedent. Trade-off: 4th wrapper class + ADR amendment for wrapper count growth. Rejected option (b) Dictionary-return — would have regressed the typed-API discipline.
- **IN-2 ActionTarget defer**: 2-field RefCounted stub (target_unit_id + target_position). Battle Preparation ADR / Grid Battle epic will ratify the full descriptor. Tests pass `null` for `target` arg throughout story-004 since validation is out of scope.
- **IN-3 DEFEND_STANCE storage**: 10th UnitTurnState field `defend_stance_active: bool` rather than 6th instance field on TurnOrderRunner (would have conflicted with the 5-field lock per ADR-0011 §Architecture Diagram). T4 reset clears the flag — within-turn-only semantics; cross-turn HP/Status SE-3 persistence (CR-4b release on subsequent MOVE/ATTACK) deferred to story-005+ HP/Status integration.
- **AC-3 ATTACK after DEFEND validation**: story AC-3 prose says "valid only if ACTION token FRESH AND no DEFEND_STANCE active" — interpreted as redundant since DEFEND already spends ACTION (so ACTION_token_spent=true → TOKEN_ALREADY_SPENT rejection precedes the DEFEND_STANCE check). No separate MOVE_LOCKED-style branch needed for ATTACK in story-004 scope.
- **AC-7 vs AC-4 error code precedence (MOVE)**: TOKEN_ALREADY_SPENT check FIRST, MOVE_LOCKED_BY_DEFEND_STANCE check SECOND. A unit that already spent MOVE this turn AND has defend_stance_active gets TOKEN_ALREADY_SPENT (the spent token shouldn't pretend to be locked).

### ADR Compliance

- **ADR-0011** §Key Interfaces line 165 — `declare_action(unit_id: int, action: ActionType, target: ActionTarget) -> ActionResult` signature: COMPLIANT. (Note: parameter typed as `int` not `ActionType` to allow tests to pass invalid out-of-range ints for AC-1 rejection coverage. Production callers should pass `ActionType.MOVE` etc.; the int typing is for test-rejection paths.)
- **ADR-0011** §Decision §Forbidden patterns: `turn_order_external_queue_write` respected (declare_action writes ONLY to `_unit_states[unit_id]` via the existing entry; never to `_queue` directly); `turn_order_consumer_mutation` respected (no consumer-mutation seam introduced); `turn_order_signal_emission_outside_domain` respected (declare_action does NOT emit any signal directly — emit happens at T6 via _mark_acted per story-003): COMPLIANT
- **ADR-0011** §Decision §Public mutator API — declare_action validation O(1) (Dictionary lookup + 1-2 boolean checks; no _queue scan): COMPLIANT
- **ADR-0011** §Forbidden patterns 5-pattern set — all 5 respected; declare_action does NOT introduce typed-array reassignment, static-state, or out-of-domain emission: COMPLIANT
- **GDD §CR-3 + §CR-4 + §CR-8**: action budget binary-token rules (CR-3a/b/e), 5 ActionType enum (CR-4), DEFEND_STANCE MOVE-lock within-turn (CR-4c), WAIT non-repositioning (CR-8): COMPLIANT
- **GDD §CR-4c clarification**: GDD source-of-truth says "DEFEND_STANCE movement lock: A unit in DEFEND_STANCE cannot MOVE." ADR-0011 §GDD Requirements line 390 quotes CR-4c as "prevents subsequent ACTION-token-spending until expiry" which contradicts GDD wording. Story-004 followed GDD source-of-truth (MOVE-lock semantics). ADR-0011 §GDD Requirements line 390 prose drift flagged for next ADR-0011 amendment cycle (low priority — semantics are correctly implemented; only the ADR's quote of CR-4c is mis-paraphrased).

### Engineering Discipline

- **G-2** typed-array preservation throughout (no `.duplicate()` calls; ActionResult.side_effects intentionally untyped per ADR-0011)
- **G-4** lambda primitive-capture sidestepped via method-reference signal capture handler in test
- **G-7** verified Overall Summary count grew 595 → 609 (+14 new tests; 0 silent skips per G-7 verification pattern)
- **G-9** paren-wrap %-format strings in `override_failure_message` constructions throughout test
- **G-10** real `/root/GameBus` subscription (NOT a stub) per autoload-identifier-binding stability
- **G-12** `ActionResult` + `ActionTarget` NOT colliding with Godot 4.6 built-in classes (verified via grep)
- **G-14** import refresh executed post-write (`godot --headless --import --path .`); no parse errors
- **G-15** `before_test()` (canonical hook) used + 5-field reset list; `after_test()` is_connected-guarded disconnect symmetry
- **G-16** typed-Array[Dictionary] for signal log filter
- **G-22** N/A (no static state)
- **G-23** safe assertions only (no `is_not_equal_approx`)
- **G-24** paren-wrapped enum-int casts (`X as int` on RHS of `==`) throughout test

### Forward Look (next stories unblocked)

- **Story 005** (Death handling + R-1 CONNECT_DEFERRED + Charge F-2): `_on_unit_died` stub at runner.gd line ~437 awaits implementation; declare_action is now wired so counter-attack scenarios can flow through it. Cross-turn DEFEND_STANCE release (CR-4b) lands when HP/Status integration replaces the `state.defend_stance_active` field with `HPStatusController.has_status_effect(unit_id, StatusEffect.DEFEND_STANCE)` query.
- **Story 006** (Victory detection): `_evaluate_victory_stub` at runner.gd line ~416 awaits implementation; consumes `acted_this_turn` flags from declare_action mutations.
- **Story 007** (Epic terminal — perf + lints): G-15 6-field reset list lint will scan `_activate_unit_turn` for the 6 fields {move_token_spent, action_token_spent, accumulated_move_cost, acted_this_turn, turn_state, defend_stance_active}; 5-pattern forbidden_patterns lint will scan src/core/turn_order_runner.gd for declare_action compliance.

**TD-046 closure**: AC-9 acted=true synthetic-state coverage — story-004's `test_declare_action_attack_then_move_both_succeed_acted_true_at_t6` covers the path through declare_action → _mark_acted production seam, closing the TD-046 gap that story-003 was unable to reach. TD-046 can be marked Resolved post-/story-done.
