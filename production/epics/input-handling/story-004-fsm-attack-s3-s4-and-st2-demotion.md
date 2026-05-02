# Story 004: 7-state FSM extended S3↔S4 (ATTACK_TARGET_SELECT ↔ ATTACK_CONFIRM) + ST-2 demotion + end-player-turn safety gate

> **Epic**: Input Handling
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3-4h
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/input-handling.md`
**Requirement**: `TR-input-handling-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005 — Input Handling — InputRouter Autoload + 7-State FSM (MVP scope)
**ADR Decision Summary**: Continuation of TR-006 — story-003 covered S0/S1/S2 move flow; story-004 extends to S3 ATTACK_TARGET_SELECT + S4 ATTACK_CONFIRM (attack flow) + ST-2 demotion (S2/S4 → S1 on menu restoration, dropping pending confirms). Same inline-match dispatch pattern. AC-11 GDD covers the end-player-turn safety gate (`end_phase_confirm` confirmation dialog flow — InputRouter does NOT render the dialog; it gates the `end_player_turn` action behind a 2-beat confirmation routed through `&"end_phase_confirm"` separate action).

**Engine**: Godot 4.6 | **Risk**: HIGH (governed by ADR-0005)
**Engine Notes**: Same as story-003 (inline `match` statement + signal emit + Object.CONNECT_DEFERRED downstream-consumer obligation). ST-2 demotion is pure-state-machine logic — no engine API surface. End-player-turn safety: InputRouter holds a transient `_pending_end_phase: bool = false` field (NOT in ADR-0005 §1's 6-field list — this is implementation-internal scratch state, scoped per-action sequence and reset on cancel/confirm; documented as transient-non-architectural per Implementation Note 3 below).

**Control Manifest Rules (Foundation layer + Global)**:
- Required: same as story-003 — inline match dispatch; emit-pair ordering (state change BEFORE downstream emit); typed InputContext payload; ST-2 demotion uses `_pre_menu_state` field per ADR-0005 §1
- Forbidden: same as story-003; ALSO forbidden: rendering the end-phase confirmation dialog inside InputRouter (Battle HUD owns dialog UI; InputRouter owns the action-gate state machine only); rendering ghost-unit/confirm-button visuals inside InputRouter (Battle HUD per provisional contract)
- Guardrail: `_handle_action_in_s3` + `_handle_action_in_s4` each <15 LoC; ST-2 demotion logic is single function `_apply_st2_demotion()` <10 LoC called from `_handle_action_in_s6` (story-007 implements full S6); end-phase safety gate adds `_pending_end_phase` field + 2 transitions (request → confirm) — NOT a new state

---

## Acceptance Criteria

*From GDD §Acceptance Criteria AC-10 (attack portion) + AC-11 + ADR-0005 §5 + GDD §Transition Table ST-2:*

- [ ] **AC-1** S1 (UNIT_SELECTED) `_handle_action_in_s1` extended to handle `&"attack_target_select"`: validates `ctx.coord != Vector2i.ZERO` AND queries provisional Grid Battle stub `is_tile_in_attack_range(ctx.coord)` → set `_state = InputState.ATTACK_TARGET_SELECT` (S1 → S3); emit pair via shared `_handle_action` epilogue from story-003
- [ ] **AC-2** S3 (ATTACK_TARGET_SELECT) `_handle_action_in_s3` arm handles `&"attack_confirm"` and `&"action_confirm"` (alias per CR-3a): set `_state = InputState.ATTACK_CONFIRM` (S3 → S4); emit pair. Also handles `&"attack_cancel"` → S1; `&"attack_target_select"` (re-targeting) → stay in S3 with new ctx (coord change, no state transition — emit `input_action_fired` only without `input_state_changed`); `&"open_game_menu"` → S6 (story-007 implements demotion via `_pre_menu_state = S3`)
- [ ] **AC-3** S4 (ATTACK_CONFIRM) `_handle_action_in_s4` arm handles `&"attack_confirm"` and `&"action_confirm"` (second confirmation completes attack): calls Grid Battle stub `confirm_attack(ctx.unit_id, ctx.coord)` → closes any open undo window for the unit (CR-5: attack closes undo per story-006 implementation; story-004 adds placeholder comment) → set `_state = InputState.OBSERVATION` (S4 → S0); emit pair. Also handles `&"attack_cancel"` → S3
- [ ] **AC-4** ST-2 demotion helper: `func _apply_st2_demotion(restored_state: InputState) -> InputState:` returns demoted state per ADR-0005 §5 ST-2 rule — if `restored_state in [InputState.MOVEMENT_PREVIEW, InputState.ATTACK_CONFIRM]` (S2 or S4 — pending-confirm states), demote to `InputState.UNIT_SELECTED` (S1); otherwise return restored_state unchanged. Used by S6 menu-close transition (story-007 invokes; story-004 implements the helper for unit-test coverage)
- [ ] **AC-5** AC-10 GDD test (attack portion): GIVEN S1 with attack-range target visible, WHEN player taps target — THEN S3 entered; WHEN player taps confirm (`action_confirm` alias) — THEN S4 entered; WHEN player taps confirm again — THEN attack stub fires + state returns to S0; emits 6 signals total (3 transitions × 2-emit-pair)
- [ ] **AC-6** AC-11 GDD end-player-turn safety gate: 2-beat confirmation flow via `&"end_player_turn"` (request) + `&"end_phase_confirm"` (confirm). Implementation: in S0 (or S1 with no unit having pending move), `&"end_player_turn"` action sets `_pending_end_phase = true` + emits `input_action_fired(&"end_player_turn", ctx)` (NO state change — Battle HUD subscriber renders the confirmation dialog); subsequent `&"end_phase_confirm"` action checks `_pending_end_phase == true`, fires `&"end_phase_confirm"` action through GameBus, resets `_pending_end_phase = false`. `&"action_cancel"` resets `_pending_end_phase = false` without firing confirm
- [ ] **AC-7** ST-2 demotion test sweep: for each (input_state, expected_demoted_state) pair: (S0, S0), (S1, S1), (S2 → S1), (S3, S3), (S4 → S1), (S5, S5), (S6, S6) — 7 cases; assert `_apply_st2_demotion(state) == expected`
- [ ] **AC-8** Re-targeting case AC-2: GIVEN S3 with first attack target selected, WHEN player taps a DIFFERENT attack-range target (`&"attack_target_select"` again) — THEN state remains S3 (no `input_state_changed` emit) but `input_action_fired` IS emitted with the NEW ctx (Battle HUD subscriber updates target preview)
- [ ] **AC-9** GridBattleStub extended with `confirm_attack(unit_id: int, coord: Vector2i) -> void` (records call to `confirm_attack_calls` Array per story-003 stub-extension pattern); `is_tile_in_attack_range` already added in story-003 — verify still present + working
- [ ] **AC-10** Regression baseline maintained: full GdUnit4 suite passes ≥771 cases (story-003 baseline) + new tests / 0 errors / 0 failures / 0 orphans / Exit 0; new test file `tests/unit/foundation/input_router_fsm_attack_st2_test.gd` adds ≥10 tests covering AC-1..AC-9
- [ ] **AC-11** `_pending_end_phase: bool` field present on InputRouter (transient scratch state; NOT counted in ADR-0005 §1's 6-field list per Implementation Note 3); G-15 reset obligation: `before_test()` resets to `false` (story-010 lint enforces this addition to G-15 reset list)

---

## Implementation Notes

*Derived from ADR-0005 §5 + GDD §Transition Table + AC-11 + delta #6 Item 4:*

1. **S3 ATTACK_TARGET_SELECT arm** (`_handle_action_in_s3`):
   ```gdscript
   func _handle_action_in_s3(action: StringName, ctx: InputContext) -> void:
       match action:
           &"attack_confirm", &"action_confirm":
               _state = InputState.ATTACK_CONFIRM
           &"attack_cancel":
               _state = InputState.UNIT_SELECTED
           &"attack_target_select":
               # Re-targeting: emit action_fired only (no state change)
               # AC-8: handled via _handle_action's emit-pair epilogue suppressing
               # input_state_changed when _state unchanged, but still emitting
               # input_action_fired. NOTE: this requires _handle_action to be
               # restructured — emit input_action_fired ALWAYS (every call), and
               # input_state_changed ONLY when _state changed. See Implementation
               # Note 4 below for restructured emit logic.
               pass  # state unchanged; ctx-update behavior delivered via input_action_fired emit
           &"open_game_menu":
               _pre_menu_state = _state  # S3
               _state = InputState.MENU_OPEN  # → S6 (story-007 implements full S6 entry)
   ```

2. **S4 ATTACK_CONFIRM arm** (`_handle_action_in_s4`):
   ```gdscript
   func _handle_action_in_s4(action: StringName, ctx: InputContext) -> void:
       match action:
           &"attack_confirm", &"action_confirm":
               # Second confirmation — execute attack
               if _grid_battle != null and _grid_battle.has_method("confirm_attack"):
                   _grid_battle.confirm_attack(ctx.unit_id, ctx.coord)
               # Close any open undo window for this unit (CR-5; story-006 implements)
               # _close_undo_window(ctx.unit_id)  # story-006
               _state = InputState.OBSERVATION
           &"attack_cancel":
               _state = InputState.ATTACK_TARGET_SELECT
   ```

3. **`_pending_end_phase` transient field rationale**: ADR-0005 §1 line 119 specifies exactly 6 instance fields. `_pending_end_phase: bool` is a transient scratch state for the 2-beat end-phase confirmation flow that does NOT need cross-frame persistence (resets on `&"action_cancel"` or `&"end_phase_confirm"` immediately). Pattern stable: classified as implementation-internal scratch (NOT new architectural field — does not require ADR amendment). Story-010 lint adds `_pending_end_phase` to the G-15 `before_test()` reset list. Documented in inline comment on the field declaration.

4. **`_handle_action` emit-logic restructure** (per AC-8 re-targeting case):
   ```gdscript
   func _handle_action(action: StringName, ctx: InputContext) -> void:
       var prev_state: InputState = _state
       match _state:
           InputState.OBSERVATION: _handle_action_in_s0(action, ctx)
           InputState.UNIT_SELECTED: _handle_action_in_s1(action, ctx)
           InputState.MOVEMENT_PREVIEW: _handle_action_in_s2(action, ctx)
           InputState.ATTACK_TARGET_SELECT: _handle_action_in_s3(action, ctx)
           InputState.ATTACK_CONFIRM: _handle_action_in_s4(action, ctx)
           InputState.INPUT_BLOCKED: _handle_action_in_s5(action, ctx)
           InputState.MENU_OPEN: _handle_action_in_s6(action, ctx)
       # Story-004 emit-pair restructure:
       if _state != prev_state:
           GameBus.input_state_changed.emit(int(prev_state), int(_state))
       # Always emit action_fired for valid (state, action) pairs that produced any visible work
       # (state change OR re-targeting OR end-phase request). Per-arm emit-control via _did_visible_work flag.
       if _did_visible_work:
           GameBus.input_action_fired.emit(action, ctx)
           _did_visible_work = false  # reset for next call
   ```
   Per-arm sets `_did_visible_work = true` when it executed observable behavior (state change OR re-targeting ctx-update OR `_pending_end_phase` toggle). Replaces story-003's "emit only on state change" rule with the more precise "emit on visible work" rule. AC-8 re-targeting specifically: S3 arm sets `_did_visible_work = true` when `&"attack_target_select"` matches.

5. **AC-11 end-player-turn flow**:
   ```gdscript
   var _pending_end_phase: bool = false  # transient scratch; reset by AC-11 cancel/confirm

   func _handle_action_in_s0(action: StringName, ctx: InputContext) -> void:
       match action:
           # ... existing arms from story-003 ...
           &"end_player_turn":
               # First beat: arm the gate. Battle HUD subscriber renders confirmation dialog
               # via input_action_fired subscription. NO state change.
               _pending_end_phase = true
               _did_visible_work = true
           &"end_phase_confirm":
               # Second beat: confirm only if armed
               if _pending_end_phase:
                   _pending_end_phase = false
                   _did_visible_work = true
                   # Battle HUD subscriber executes actual phase-end (calls Turn Order, etc.)
           &"action_cancel":
               # Cancel armed end-phase request without firing confirm
               if _pending_end_phase:
                   _pending_end_phase = false
                   # NOTE: no _did_visible_work — silently cancel; subscribers shouldn't see fake "cancel" event for an unarmed gate
   ```

6. **`_apply_st2_demotion` helper**:
   ```gdscript
   func _apply_st2_demotion(restored_state: InputState) -> InputState:
       # Per ADR-0005 §5 + GDD ST-2: S2 (MOVEMENT_PREVIEW) and S4 (ATTACK_CONFIRM)
       # are pending-confirm states; menu-close drops the pending confirm and demotes to S1.
       if restored_state == InputState.MOVEMENT_PREVIEW or restored_state == InputState.ATTACK_CONFIRM:
           return InputState.UNIT_SELECTED
       return restored_state
   ```
   Helper is pure (no side effects); story-007 invokes from S6 close-menu transition. Story-004 unit-tests it standalone.

7. **`is_tile_in_attack_range` GridBattleStub extension**: per story-003 AC-9 placeholder, this story's AC-9 confirms it's wired with fixture `Vector2i(4,4)` + `(5,5)` in attack range. Plus add `confirm_attack(unit_id: int, coord: Vector2i) -> void` recording to `confirm_attack_calls: Array[Dictionary]` (mirrors `confirm_move_calls` pattern).

8. **S1 → S3 transition addition**: story-003's `_handle_action_in_s1` extended:
   ```gdscript
   # Add to existing S1 arm (story-003)
   match action:
       # ... existing arms ...
       &"attack_target_select":
           if ctx.coord == Vector2i.ZERO:
               return
           if not _is_tile_in_attack_range(ctx.coord):
               return  # silent rejection per EC-7
           _state = InputState.ATTACK_TARGET_SELECT
   ```
   And a sibling `_is_tile_in_attack_range` helper mirroring `_is_tile_in_move_range`.

9. **Test file**: `tests/unit/foundation/input_router_fsm_attack_st2_test.gd` — 10-12 tests covering AC-1..AC-9. Tests follow story-003 pattern: `before_test()` G-15 reset (now includes `_pending_end_phase = false`); GridBattleStub injection; signal capture lambdas. ST-2 demotion sweep test (AC-7) is a 7-case parametric test using `Array[Dictionary]` cases pattern per G-16 typed-array obligation.

10. **Re-targeting test (AC-8)**:
    ```gdscript
    func test_s3_retargeting_emits_action_fired_without_state_changed() -> void:
        var captures_state: Array = []
        var captures_action: Array = []
        GameBus.input_state_changed.connect(func(p, n): captures_state.append([p, n]))
        GameBus.input_action_fired.connect(func(a, c): captures_action.append([a, c]))
        # Setup: enter S3
        _setup_state_in_s3()  # helper that does S0 → S1 → S3 with proper stub injection
        captures_state.clear()
        captures_action.clear()
        # Re-target
        var ctx_new := InputContext.new()
        ctx_new.coord = Vector2i(5, 5)  # different valid attack-range coord
        InputRouter._handle_action(&"attack_target_select", ctx_new)
        await get_tree().process_frame
        # Assertions
        assert_int(captures_state.size()).is_equal(0)  # no state change emit
        assert_int(captures_action.size()).is_equal(1)  # but action_fired DID emit
        assert_object(captures_action[0][1]).is_same(ctx_new)  # with NEW ctx
    ```

11. **End-phase test (AC-6)**:
    ```gdscript
    func test_end_player_turn_two_beat_confirmation() -> void:
        InputRouter._state = InputRouter.InputState.OBSERVATION
        InputRouter._pending_end_phase = false
        var captures_action: Array = []
        GameBus.input_action_fired.connect(func(a, c): captures_action.append(a))
        # First beat: arm
        InputRouter._handle_action(&"end_player_turn", InputContext.new())
        await get_tree().process_frame
        assert_bool(InputRouter._pending_end_phase).is_true()
        assert_int(captures_action.size()).is_equal(1)
        assert_str(str(captures_action[0])).is_equal("end_player_turn")
        # Second beat: confirm
        InputRouter._handle_action(&"end_phase_confirm", InputContext.new())
        await get_tree().process_frame
        assert_bool(InputRouter._pending_end_phase).is_false()
        assert_int(captures_action.size()).is_equal(2)
        assert_str(str(captures_action[1])).is_equal("end_phase_confirm")
    ```

12. **G-23 reminder**: `_pending_end_phase` boolean assertions use `assert_bool(...).is_true()` / `.is_false()`; do NOT use `is_equal_approx` (G-23 — that method doesn't exist on Bool assert; not applicable here but cross-cited as discipline).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 005**: Mode determination logic (`_handle_event` extension to set `_active_mode`)
- **Story 006**: Per-unit undo window logic; story-004's `_close_undo_window` placeholder is just a comment
- **Story 007**: S5 INPUT_BLOCKED + S6 MENU_OPEN full implementation; ADR-0002 GameBus signal subscriptions; nested `_input_blocked_reasons` PackedStringArray stack; full menu-close transition that invokes `_apply_st2_demotion`
- **Story 008-009**: Touch protocol — TPP fires from S0 in TOUCH mode; pan-vs-tap classifier; persistent action panel
- **Story 010**: Epic terminal — `_pending_end_phase` G-15 reset enforcement lint; perf baseline

---

## QA Test Cases

*Authored inline (lean mode QL-STORY-READY skip).*

- **AC-1**: S1 → S3 transition on `attack_target_select`
  - Given: `_state = UNIT_SELECTED`; GridBattleStub injected with `Vector2i(4,4)` in attack range
  - When: `_handle_action(&"attack_target_select", ctx with coord=(4,4))`
  - Then: `_state == ATTACK_TARGET_SELECT`; emit pair captured
  - Edge cases: coord NOT in attack range → no transition (silent rejection); coord = Vector2i.ZERO → no transition
- **AC-2**: S3 transitions
  - Given: `_state = ATTACK_TARGET_SELECT`
  - When: `_handle_action(&"attack_confirm", ctx)` OR `&"action_confirm"`
  - Then: `_state == ATTACK_CONFIRM`; emit pair
  - Edge cases: `&"attack_cancel"` → S1; `&"open_game_menu"` → S6 with `_pre_menu_state = S3`; re-targeting via `&"attack_target_select"` → S3 retained
- **AC-3**: S4 confirm + cancel
  - Given: `_state = ATTACK_CONFIRM`; GridBattleStub
  - When: `_handle_action(&"attack_confirm", ctx with unit_id=1, coord=(4,4))`
  - Then: `_state == OBSERVATION`; `GridBattleStub.confirm_attack_calls` contains `{"unit_id": 1, "coord": (4,4)}`; emit pair
  - Edge cases: `&"attack_cancel"` → S3
- **AC-4**: ST-2 demotion helper purity
  - Given: `_apply_st2_demotion(state)` called directly
  - When: each of 7 InputState values passed
  - Then: returns S1 for S2 or S4; returns input unchanged otherwise
  - Edge cases: assert helper is pure (no side effects on `_state`)
- **AC-5**: AC-10 attack flow end-to-end
  - Given: S1 with attack target visible
  - When: tap attack target → tap confirm → tap confirm
  - Then: state sequence S1 → S3 → S4 → S0; 6 emits total
- **AC-6**: AC-11 end-phase 2-beat
  - Given: `_state = S0`; `_pending_end_phase = false`
  - When: `&"end_player_turn"` → check `_pending_end_phase=true`; then `&"end_phase_confirm"` → check `_pending_end_phase=false`
  - Then: 2 `input_action_fired` emits captured (one per beat); 0 `input_state_changed` emits (no state transition)
  - Edge cases: `&"end_phase_confirm"` without prior arm → no emit, no toggle; `&"action_cancel"` after arm → silent reset
- **AC-7**: ST-2 sweep
  - Given: 7-case parametric Array[Dictionary]
  - When: each `_apply_st2_demotion(case.state)` called
  - Then: result matches `case.expected`
- **AC-8**: S3 re-targeting
  - Given: `_state = S3`; first target tapped
  - When: `&"attack_target_select"` with different valid coord
  - Then: `_state` still S3; 0 `input_state_changed` emits since enter; 1 `input_action_fired` emit with NEW ctx
- **AC-9**: GridBattleStub `confirm_attack` recording
  - Given: GridBattleStub instantiated
  - When: `stub.confirm_attack(2, Vector2i(5,5))` called
  - Then: `stub.confirm_attack_calls.size() == 1`; entry matches input
  - Edge cases: `is_tile_in_attack_range(Vector2i(99,99))` returns false; `is_tile_in_attack_range(Vector2i(4,4))` returns true
- **AC-10**: Regression baseline
  - Given: full suite invoked
  - When: 771 + new tests run
  - Then: ≥781 tests / 0 errors / 0 failures / 0 orphans / Exit 0
- **AC-11**: `_pending_end_phase` field exists + G-15 reset note
  - Given: InputRouter source file
  - When: grep for `var _pending_end_phase: bool = false`
  - Then: 1 match present; inline comment documents transient-scratch classification
  - Edge cases: assert before_test() in this story's test file resets it to `false`

---

## Test Evidence

**Story Type**: Logic (FSM extensions are pure deterministic logic; ST-2 demotion helper is pure function)
**Required evidence**: `tests/unit/foundation/input_router_fsm_attack_st2_test.gd` — must exist + ≥10 tests + must pass; GridBattleStub extended with `confirm_attack` method
**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 003 (S0/S1/S2 FSM core + `_handle_action` dispatch + GridBattleStub baseline)
- **Unlocks**: Story 007 (S6 menu-close transition invokes `_apply_st2_demotion`); Battle HUD epic (consumes `&"end_player_turn"` + `&"end_phase_confirm"` signals to render confirmation dialog)
