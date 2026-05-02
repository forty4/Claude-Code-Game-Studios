# Story 007: S5 INPUT_BLOCKED + S6 MENU_OPEN + GameBus subscriptions to ADR-0002 SceneManager + nested PackedStringArray stack + set_input_as_handled() + ST-2 menu restoration + verification evidence #4 (recursive Control disable)

> **Epic**: Input Handling
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3-4h
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/input-handling.md`
**Requirement**: `TR-input-handling-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005 — Input Handling — InputRouter Autoload + 7-State FSM (MVP scope) + ADR-0002 SceneManager
**ADR Decision Summary**: TR-010 = §1 + Implementation Notes Advisory C + ADR-0002 `scene_transition_lifecycle` — InputRouter consumes 2 SceneManager-emitted GameBus signals: `ui_input_block_requested(reason: String)` drives S5 INPUT_BLOCKED entry; `ui_input_unblock_requested(reason: String)` drives S5 exit. `_input_blocked_reasons` PackedStringArray supports nested S5 entries (max nesting depth ~3 observed). SceneManager additionally calls `InputRouter.set_process_input(false) + set_process_unhandled_input(false)` directly during overworld retain (per ADR-0002 `overworld_pause_during_battle` api_decision); both required for Godot 4.x autoload Nodes (godot-specialist 2026-04-30 PASS Item 4). INPUT_BLOCKED dispatch arm silently drops grid actions G-1..G-10 + permits camera + read actions per EC-2 + ST-4; MUST call `get_viewport().set_input_as_handled()` BEFORE returning (forbidden_pattern `input_router_input_blocked_drop_without_set_input_as_handled` per Advisory C).

**Engine**: Godot 4.6 | **Risk**: HIGH (governed by ADR-0005)
**Engine Notes**: `Object.CONNECT_DEFERRED` for GameBus subscriptions per ADR-0001 §5 deferred-connect mandate (re-entrancy hazard mitigation per delta #6 Item 4 Advisory D). `get_viewport().set_input_as_handled()` is the canonical Godot API for marking events consumed (4.0+ stable). `set_process_input(false)` + `set_process_unhandled_input(false)` for autoload Nodes — both required per godot-specialist Item 4 (Godot 4.x core behavior; only one is insufficient because `_input` and `_unhandled_input` are dispatched through separate per-frame paths). PackedStringArray push/pop_at via `arr.append()` + `arr.remove_at(arr.find(reason))` (4.0+ stable). **Verification item #4** mandatory before story ships first test: confirm SceneManager `set_process_input(false) + set_process_unhandled_input(false)` against `/root/InputRouter` does silence both `_input` + `_unhandled_input` callbacks (godot-specialist PASS but headless-confirmation in test required).

**Control Manifest Rules (Foundation layer + Global)**:
- Required: GameBus subscription via `Object.CONNECT_DEFERRED` (NEVER raw connect — re-entrancy hazard); nested `_input_blocked_reasons` PackedStringArray stack (NOT a `bool` flag — supports multiple concurrent block sources); `get_viewport().set_input_as_handled()` BEFORE return in S5 dropped-action arms (forbidden_pattern enforced via story-010 lint); `_pre_menu_state` field updated on S6 entry per ADR-0005 §1; ST-2 demotion via `_apply_st2_demotion` helper (story-004) on S6 close
- Forbidden: bool flag for `_input_blocked_reasons` (must be PackedStringArray for nested support); raw `Object.connect` without CONNECT_DEFERRED (re-entrancy); rendering menu UI inside InputRouter (Battle HUD owns); rendering INPUT_BLOCKED visual feedback (Battle HUD owns); blocking camera + read actions in S5 (per EC-2 — those still function)
- Guardrail: `_handle_action_in_s5` <20 LoC; `_handle_action_in_s6` <15 LoC; `_on_ui_input_block_requested` <10 LoC; `_on_ui_input_unblock_requested` <10 LoC; max nesting depth ~3 enforced via informational test (push_warning if exceeded; not FATAL — ADR-0005 doesn't lock the cap)

---

## Acceptance Criteria

*From GDD §Acceptance Criteria AC-16 + AC-17 + ADR-0005 §1 + Implementation Notes Advisory C + EC-2 + EC-3 + ST-4:*

- [ ] **AC-1** InputRouter `_ready()` body subscribes to ADR-0002 SceneManager-emitted GameBus signals via `Object.CONNECT_DEFERRED`: `GameBus.ui_input_block_requested.connect(_on_ui_input_block_requested, Object.CONNECT_DEFERRED)` + `GameBus.ui_input_unblock_requested.connect(_on_ui_input_unblock_requested, Object.CONNECT_DEFERRED)`. Subscriptions wire AFTER bindings load (story-002's `_ready()` body)
- [ ] **AC-2** `_on_ui_input_block_requested(reason: String) -> void` handler appends `reason` to `_input_blocked_reasons` PackedStringArray; if this is the FIRST entry (i.e., `_input_blocked_reasons.size() == 1` after append), set `_state = InputState.INPUT_BLOCKED` (S5) + emit `input_state_changed(int(prev_state), int(InputState.INPUT_BLOCKED))`. If multiple reasons stack (size > 1 after append), state is ALREADY S5 — no additional emit (idempotent re-entry per AC-5)
- [ ] **AC-3** `_on_ui_input_unblock_requested(reason: String) -> void` handler removes `reason` from `_input_blocked_reasons` (find + remove_at; if not found, push_warning); if `_input_blocked_reasons.is_empty()` after removal, restore prior state via `_state = _pre_block_state` + emit pair (where `_pre_block_state` is captured on first block entry — see Implementation Note 3). If still nested (size > 0 after removal), state stays S5 — no emit
- [ ] **AC-4** `_handle_action_in_s5(action: StringName, ctx: InputContext) -> void`: silently drops grid actions (`unit_select`, `move_target_select`, `move_confirm`, `move_cancel`, `attack_target_select`, `attack_confirm`, `attack_cancel`, `undo_last_move`, `end_unit_turn`, `grid_hover`); permits camera actions (`camera_pan`, `camera_zoom_in/out`, `camera_snap_to_unit`) + read actions (`open_unit_info`); silent drops MUST call `get_viewport().set_input_as_handled()` BEFORE returning to prevent event continuing to downstream `_unhandled_input` handlers (Advisory C forbidden_pattern)
- [ ] **AC-5** Nested-block test: `ui_input_block_requested("transition")` → `ui_input_block_requested("dialog")` → `ui_input_unblock_requested("dialog")` → `ui_input_unblock_requested("transition")` — verify (a) only 1 `input_state_changed` emit on first entry, (b) no emits on 2nd entry/1st exit, (c) 1 `input_state_changed` emit on final exit restoring prior state
- [ ] **AC-6** `_handle_action_in_s6(action: StringName, ctx: InputContext) -> void`: handles `&"close_menu"` → `_state = _apply_st2_demotion(_pre_menu_state)` (uses story-004 helper); emit `input_state_changed(int(MENU_OPEN), int(_state))` + `input_action_fired(&"close_menu", ctx)`. Other actions in S6 silently dropped (player must close menu first to interact with grid)
- [ ] **AC-7** AC-16 GDD test (menu state preservation with ST-2 demotion): GIVEN `_state = MOVEMENT_PREVIEW (S2)`; WHEN `&"open_game_menu"` action fires (transitions to S6 setting `_pre_menu_state = S2`) THEN `&"close_menu"` action fires — THEN `_state == UNIT_SELECTED (S1)` (NOT S2 — pending move-confirm dropped per ST-2 demotion); verifies story-004's `_apply_st2_demotion` integration
- [ ] **AC-8** AC-17 GDD test (S5 input blocked enemy phase): GIVEN `_state == INPUT_BLOCKED (S5)`; WHEN `&"unit_select"` action attempted (via `_handle_event` synthetic) — THEN action silently dropped (no state change, no `input_action_fired` emit for the dropped action, no Grid Battle stub call); `get_viewport().set_input_as_handled()` invoked. AND camera pan + open_unit_info STILL function (verified via separate test — camera action passes through with normal emit-pair)
- [ ] **AC-9** Verification evidence #4: `production/qa/evidence/input_router_verification_04_recursive_control_disable.md` exists describing test that confirms SceneManager `InputRouter.set_process_input(false) + set_process_unhandled_input(false)` silences both `_input` + `_unhandled_input` callbacks. Headless-verifiable (NOT Polish-deferable): set up test scene, mount InputRouter, call both setters, inject synthetic event, assert no `_handle_event` invocation. **MANDATORY in this story** (not Polish-deferable per EPIC.md scope — items #3, #4, #5a, #5b are headless-verifiable)
- [ ] **AC-10** Regression baseline maintained: full GdUnit4 suite passes ≥799 cases (story-006 baseline) + new tests / 0 errors / 0 failures / 0 orphans / Exit 0; new test file `tests/unit/foundation/input_router_block_menu_test.gd` adds ≥12 tests covering AC-1..AC-9
- [ ] **AC-11** New field `_pre_block_state: InputState = InputState.OBSERVATION` added — captures state at the moment of FIRST block entry; restored on FINAL block exit. NOT in ADR-0005 §1's 6-field list per Implementation Note 3 — classified as transient implementation-internal field (mirrors story-004's `_pending_end_phase` precedent). G-15 reset obligation: `before_test()` resets to `OBSERVATION`

---

## Implementation Notes

*Derived from ADR-0005 §1 + Implementation Notes Advisory C + EC-2 + EC-3 + ST-4 + ADR-0002 §scene_transition_lifecycle:*

1. **`_ready()` body extension** (after story-002's bindings load):
   ```gdscript
   func _ready() -> void:
       _load_bindings()  # story-002
       _populate_input_map(_loaded_dict)  # story-002
       _validate_r5_parity(_loaded_dict)  # story-002
       # Story-007: GameBus subscriptions per ADR-0001 §5 deferred-connect mandate
       GameBus.ui_input_block_requested.connect(_on_ui_input_block_requested, Object.CONNECT_DEFERRED)
       GameBus.ui_input_unblock_requested.connect(_on_ui_input_unblock_requested, Object.CONNECT_DEFERRED)
   ```

2. **`_on_ui_input_block_requested` handler**:
   ```gdscript
   func _on_ui_input_block_requested(reason: String) -> void:
       _input_blocked_reasons.append(reason)
       if _input_blocked_reasons.size() == 1:
           # First block entry: capture prior state for restoration on final exit
           _pre_block_state = _state
           var prev_state: InputState = _state
           _state = InputState.INPUT_BLOCKED
           GameBus.input_state_changed.emit(int(prev_state), int(_state))
       # If size > 1, state already S5 — no re-emit (idempotent nested entry)
   ```

3. **`_pre_block_state` field rationale**: like `_pending_end_phase` (story-004), `_pre_block_state` is implementation-internal transient scratch state — captures the state at the moment of the first block entry so we can restore it on the final exit. NOT in ADR-0005 §1's 6-field list because (a) it's only meaningful while `_input_blocked_reasons.size() > 0`, (b) it doesn't appear in any cross-system contract or signal payload, (c) it's reset to default on every block-exit-empty event. Pattern stable at 2 invocations now (`_pending_end_phase` story-004 + `_pre_block_state` story-007). Documented in inline comment.

4. **`_on_ui_input_unblock_requested` handler**:
   ```gdscript
   func _on_ui_input_unblock_requested(reason: String) -> void:
       var idx: int = _input_blocked_reasons.find(reason)
       if idx == -1:
           push_warning("InputRouter: unblock requested for unknown reason '%s'; current stack: %s" % [reason, str(_input_blocked_reasons)])
           return
       _input_blocked_reasons.remove_at(idx)
       if _input_blocked_reasons.is_empty():
           # Final exit: restore prior state
           var prev_state: InputState = _state
           _state = _pre_block_state
           GameBus.input_state_changed.emit(int(prev_state), int(_state))
           _pre_block_state = InputState.OBSERVATION  # reset for next block sequence
       # If still nested (size > 0 after removal), state stays S5 — no emit
   ```

5. **`_handle_action_in_s5` arm** (silent-drop with set_input_as_handled):
   ```gdscript
   const _GRID_ACTIONS: Array[StringName] = [
       &"unit_select", &"move_target_select", &"move_confirm", &"move_cancel",
       &"attack_target_select", &"attack_confirm", &"attack_cancel",
       &"undo_last_move", &"end_unit_turn", &"grid_hover",
   ]
   const _PERMITTED_S5_ACTIONS: Array[StringName] = [
       &"camera_pan", &"camera_zoom_in", &"camera_zoom_out", &"camera_snap_to_unit",
       &"open_unit_info",
   ]

   func _handle_action_in_s5(action: StringName, ctx: InputContext) -> void:
       if action in _GRID_ACTIONS:
           # Silently drop + set_input_as_handled per Advisory C
           get_viewport().set_input_as_handled()
           return
       if action in _PERMITTED_S5_ACTIONS:
           # Camera + read actions pass through (no state change in S5; emit handled by _handle_action epilogue if _did_visible_work set)
           # Note: in S5, these don't change _state, but they DO produce visible work for downstream (camera moves, panel opens)
           _did_visible_work = true
           return
       # Other actions (menu actions, end_phase, etc.) — silent in S5 by default (no permitted side effect)
       get_viewport().set_input_as_handled()
   ```

6. **`_handle_action_in_s6` arm**:
   ```gdscript
   func _handle_action_in_s6(action: StringName, ctx: InputContext) -> void:
       match action:
           &"close_menu":
               var prev_state: InputState = _state
               _state = _apply_st2_demotion(_pre_menu_state)  # story-004 helper
               # Emit pair handled by _handle_action epilogue:
               # - input_state_changed if _state != prev_state (always true here unless _pre_menu_state was also S6 — impossible)
               # - input_action_fired
               _did_visible_work = true
           # Other actions: silent (player must close menu first)
   ```

7. **S0/S1/S2/S3 → S6 entry**: existing arms in stories 003+004 already set `_pre_menu_state = _state` before `_state = MENU_OPEN`. Verify the assignment lines are present + accurate after this story's S6 implementation; add if missing.

8. **`open_game_menu` action handling**: should work from S0/S1/S2/S3 per GDD §Transition Table. Uniform handler:
   ```gdscript
   # In each of S0, S1, S2, S3 arms:
   &"open_game_menu":
       _pre_menu_state = _state
       _state = InputState.MENU_OPEN
       _did_visible_work = true
   ```

9. **Verification evidence #4 template** (`production/qa/evidence/input_router_verification_04_recursive_control_disable.md`):
   ```markdown
   # InputRouter Verification #4 — Recursive Control Disable

   **Epic**: input-handling
   **Story**: story-007-input-blocked-and-menu-open
   **ADR**: ADR-0005 §Verification Required §4
   **Status**: Verified (headless GdUnit4)

   ## Test Procedure (Headless)
   1. Mount InputRouter autoload via test fixture
   2. Connect a test-observable lambda to InputRouter's `_handle_event` (or replace with test seam that increments a counter on each call)
   3. Call `InputRouter.set_process_input(false)` + `InputRouter.set_process_unhandled_input(false)` (mirrors SceneManager `overworld_pause_during_battle` api_decision)
   4. Inject synthetic InputEvent via `Input.parse_input_event(event)` (NOT InputRouter._handle_event direct call — bypasses the gate; AC-9 specifically tests the gate)
   5. await get_tree().process_frame
   6. Assert: counter == 0 (no `_handle_event` invocation; both gate paths effective)
   7. Re-enable both: `set_process_input(true)` + `set_process_unhandled_input(true)`
   8. Inject same event
   9. Assert: counter == 1 (now event dispatched)

   ## Expected Result
   Both `set_process_input(false)` AND `set_process_unhandled_input(false)` are required for autoload Nodes; setting only one leaves the other path active. Confirms godot-specialist 2026-04-30 PASS Item 4.

   ## Status
   Headless test in `tests/unit/foundation/input_router_block_menu_test.gd::test_recursive_control_disable_silences_both_paths` documents the verification. Mandatory in story-007 per EPIC.md scope (not Polish-deferable — fully headless-verifiable).
   ```

10. **Test file**: `tests/unit/foundation/input_router_block_menu_test.gd` — 12-15 tests covering AC-1..AC-9. Pattern: GdUnitTestSuite Node-based; `before_test()` G-15 reset of all 6 fields + `_pending_end_phase` (story-004) + `_pre_block_state` (story-007) — story-010 lint enforces full reset list. Use signal capture lambdas with G-4 Array.append pattern.

11. **G-10 hazard awareness**: this story subscribes InputRouter (an autoload) to GameBus signals. Per G-10, autoload identifier binds at engine init time to the originally-registered node. Tests that swap `/root/GameBus` with `GameBusStub.swap_in()` AND swap InputRouter would have G-10 risk. For story-007 tests, use the REAL GameBus autoload + emit on it directly (`GameBus.ui_input_block_requested.emit("test_reason")`) per G-10 "Correct" pattern.

12. **AC-9 test seam approach**: to test "set_process_input(false) silences callbacks" without needing real OS input pipeline, expose `var _handle_event_call_count: int = 0` test-observable counter incremented at the top of `_handle_event`. Test uses `Input.parse_input_event()` (Godot's official synthetic-event-injection API per delta #6 Item 8 distinction — this is event injection, NOT InputMap population) to simulate engine dispatch through `_unhandled_input`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 008-009**: Touch protocol (S5 doesn't change touch handling — same drop-grid + permit-camera rule)
- **Story 010**: G-15 reset enforcement lint covers `_pre_block_state` addition; epic-terminal `set_input_as_handled` lint script enforces Advisory C forbidden_pattern; verification evidence rollup

---

## QA Test Cases

*Authored inline (lean mode QL-STORY-READY skip).*

- **AC-1**: GameBus subscriptions wired in `_ready()`
  - Given: InputRouter autoload at `/root/InputRouter`
  - When: read source for connect calls
  - Then: 2 connect calls present with `Object.CONNECT_DEFERRED` flag for `ui_input_block_requested` + `ui_input_unblock_requested`
- **AC-2**: First block entry transitions to S5 + captures pre-state
  - Given: `_state = OBSERVATION`; `_input_blocked_reasons.is_empty()`
  - When: `_on_ui_input_block_requested("transition")`
  - Then: `_input_blocked_reasons == ["transition"]`; `_state == INPUT_BLOCKED`; `_pre_block_state == OBSERVATION`; 1 emit captured
  - Edge cases: second block (`"dialog"`) → stack size 2; state stays S5; 0 additional emits
- **AC-3**: Final block exit restores prior state
  - Given: nested block (`["transition", "dialog"]`); state S5
  - When: `_on_ui_input_unblock_requested("dialog")` → `_on_ui_input_unblock_requested("transition")`
  - Then: after first unblock, stack size 1, state still S5, 0 emits; after second unblock, stack empty, state restored to OBSERVATION (or whatever `_pre_block_state` captured), 1 emit
  - Edge cases: unblock for unknown reason → push_warning + no state change
- **AC-4**: S5 grid action drops + set_input_as_handled
  - Given: `_state = S5`
  - When: `_handle_action(&"unit_select", ctx)` (synthetic via _handle_action direct — bypasses _handle_event)
  - Then: state unchanged; `get_viewport().set_input_as_handled()` invoked (verify via Viewport mock if available, OR via grep of _handle_action_in_s5 source for the call); no Grid Battle stub call; no emit
  - Edge cases: `&"camera_pan"` in S5 → `_did_visible_work = true`; `&"open_unit_info"` in S5 → permitted
- **AC-5**: Nested-block sequence correctness
  - Given: 4-event sequence (block "T", block "D", unblock "D", unblock "T")
  - When: events processed in order
  - Then: 2 emits total (1 on first block, 1 on final unblock); state sequence S0 → S5 → S5 → S5 → S0
- **AC-6**: S6 close_menu transition with ST-2 demotion
  - Given: `_state = S6`; `_pre_menu_state = S2`
  - When: `_handle_action(&"close_menu", ctx)`
  - Then: `_state == S1` (per `_apply_st2_demotion(S2) → S1` from story-004); 2 emits (state_changed + action_fired)
  - Edge cases: `_pre_menu_state = S0` → close_menu restores S0 directly (no demotion); `_pre_menu_state = S4` → demoted to S1
- **AC-7**: AC-16 GDD test (menu state preservation w/ demotion)
  - Given: full sequence S0 → S1 → S2 → (open_game_menu → S6 with `_pre_menu_state=S2`) → (close_menu → S1 via demotion)
  - When: complete sequence
  - Then: final `_state == S1`; pending move-confirm dropped (S2 progress NOT preserved per ST-2)
- **AC-8**: AC-17 GDD test (S5 silently drops grid + permits camera)
  - Given: `_state = S5`
  - When: `_handle_action(&"unit_select", ctx)` then `_handle_action(&"camera_pan", ctx)` then `_handle_action(&"open_unit_info", ctx)`
  - Then: first dropped (no emit); second + third permitted (`_did_visible_work` set; `input_action_fired` emit captured for each)
- **AC-9**: Verification evidence #4 doc + headless test
  - Given: file `production/qa/evidence/input_router_verification_04_recursive_control_disable.md` exists
  - When: read content
  - Then: contains test procedure + expected result + status "Verified (headless GdUnit4)"
  - AND: test `test_recursive_control_disable_silences_both_paths` passes — counter == 0 after both setters disable, == 1 after re-enable
- **AC-10**: Regression baseline
  - Given: full suite invoked
  - When: 799 + new tests run
  - Then: ≥811 tests / 0 errors / 0 failures / 0 orphans / Exit 0
- **AC-11**: `_pre_block_state` field exists + G-15 reset
  - Given: InputRouter source file
  - When: grep for `var _pre_block_state: InputState = InputState.OBSERVATION`
  - Then: 1 match with inline comment classifying as transient-internal
  - Edge cases: assert `before_test()` in this story's test file resets it

---

## Test Evidence

**Story Type**: Integration (multi-system: InputRouter consumes ADR-0002 SceneManager GameBus signals; cross-system contract verification + nested state machine)
**Required evidence**:
- Integration: `tests/unit/foundation/input_router_block_menu_test.gd` — must exist + ≥12 tests + must pass
- Visual/Feel: `production/qa/evidence/input_router_verification_04_recursive_control_disable.md` — must exist + status "Verified" (NOT Polish-deferable per EPIC.md item-#4 classification)

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 003 (S0/S1/S2 arms — extend with `&"open_game_menu"` setting `_pre_menu_state`), Story 004 (`_apply_st2_demotion` helper used by S6 close), Story 002 (`_ready()` body extends with subscriptions)
- **Unlocks**: Story 008-009 (touch protocol — S5 INPUT_BLOCKED behavior is uniform across input modes); SceneManager's `overworld_pause_during_battle` api_decision is fully consumed (verifies the cross-system contract round-trip)
