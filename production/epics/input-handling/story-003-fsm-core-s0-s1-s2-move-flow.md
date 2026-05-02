# Story 003: 7-state FSM core S0↔S1↔S2 (OBSERVATION ↔ UNIT_SELECTED ↔ MOVEMENT_PREVIEW ↔ MOVE_CONFIRM) + transition signal emit + 2-beat move confirmation

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
**ADR Decision Summary**: TR-006 = §5 7-state FSM with inline match dispatch — synchronous deterministic transitions per GDD §Transition Table; no external `StateMachine` Resource (Alternative 3 rejected); no AnimationTree-as-FSM repurposing. Single dispatch path through `_handle_action(action: StringName, ctx: InputContext)`. Each transition emits `GameBus.input_state_changed(prev: int, new: int)` + `GameBus.input_action_fired(action: StringName, ctx: InputContext)` per ADR-0001 §7 Signal Contract Schema.

**Engine**: Godot 4.6 | **Risk**: HIGH (governed by ADR-0005)
**Engine Notes**: `match` statement with multiple `_state` arms (Godot 4.0+ stable; per delta #6 godot-specialist Item 2 — match-arm fall-through is NOT a Godot 4.x feature; each arm is exclusive). `signal.emit(args)` for typed-arg signals (4.0+ stable; 4.5 introduced @abstract but not relevant here). Re-entrancy hazard: subscribers without `Object.CONNECT_DEFERRED` could synchronously re-enter `_handle_event` mid-dispatch (delta #6 Item 4 Advisory D); production InputRouter does NOT subscribe to its OWN signals, so this is downstream-consumer obligation per ADR-0001 §5 deferred-connect mandate (already enforced via existing CI lint per damage-calc/turn-order pattern).

**Control Manifest Rules (Foundation layer + Global)**:
- Required: inline `match _state` dispatch in `_handle_action`; 2 GameBus emit calls per transition (`input_state_changed` + `input_action_fired` in that order per ADR-0001 §7); typed-Resource InputContext payload (NEVER raw Dictionary or untyped Variant); state transitions BEFORE side-effects (set `_state = new` BEFORE emit per delta #6 Item 4)
- Forbidden: external `StateMachine` Resource (Alternative 3 rejected); AnimationTree-as-FSM (rejected); `Object.connect()` self-subscription on InputRouter own signals (re-entrancy hazard per Advisory D); raw `int` for state transitions in emits (use `int(InputState.NEW)` cast per delta #6 wire-format obligation); transition logic spread across multiple files (single `_handle_action` is the only entry point)
- Guardrail: `_handle_action` total length <100 LoC (inline match dispatch is intentionally compact); each match arm <15 LoC (transitions are simple state writes + emits + maybe field updates); ≥2 GameBus emits per visible transition (paired ordering enforced via test)

---

## Acceptance Criteria

*From GDD §Acceptance Criteria AC-10 (move portion) + AC-15 + ADR-0005 §5 + GDD §States and Transitions:*

- [ ] **AC-1** `_handle_action(action: StringName, ctx: InputContext) -> void` implemented on InputRouter; `_handle_event` updated to call `_handle_action` after action match (replaces story-002's `_last_matched_action` test-observable storage)
- [ ] **AC-2** `match _state` arm for `InputState.OBSERVATION (S0)` handles `&"unit_select"`: validates `ctx.unit_id != -1` (a unit was tapped/clicked) → set `_state = InputState.UNIT_SELECTED`; emit `input_state_changed(int(OBSERVATION), int(UNIT_SELECTED))` + `input_action_fired(&"unit_select", ctx)`. Other actions in S0 either silently ignored or dispatched to camera category (S0 also accepts `camera_pan` / `camera_zoom_in/out` / `camera_snap_to_unit` / `open_unit_info` / `open_game_menu` per GDD §Transition Table)
- [ ] **AC-3** S1 (UNIT_SELECTED) `match` arm handles `&"move_target_select"`: validates `ctx.coord != Vector2i.ZERO` AND queries provisional Grid Battle stub `is_tile_in_move_range(ctx.coord)` (stub returns true for hardcoded fixture coords) → set `_state = InputState.MOVEMENT_PREVIEW`; emit pair. S1 also handles `&"move_cancel"` → back to S0; `&"end_unit_turn"` → back to S0 (closes undo per CR-5 — actual close logic in story-006); `&"open_game_menu"` → S6 (story-007); `&"open_unit_info"` → no state change (S1 retained)
- [ ] **AC-4** S2 (MOVEMENT_PREVIEW) `match` arm handles `&"move_confirm"`: applies move (calls Grid Battle stub `confirm_move(ctx.unit_id, ctx.coord)` — stub no-ops for now) → opens undo window for the unit (story-006 implements; story-003 just sets a placeholder boolean) → set `_state = InputState.OBSERVATION` (S2 → S0); emit pair. S2 also handles `&"move_cancel"` → S1; `&"action_confirm"` (alias for `move_confirm` per CR-3a) handled identically
- [ ] **AC-5** AC-15 GDD test: every state transition emits `input_state_changed(prev, new)` exactly once BEFORE any downstream processing (prev = current `_state` int value, new = target `_state` int value); paired with `input_action_fired(action, ctx)`. Verified via signal-capture pattern (G-4 Array-append captures from `before_test()`-connected lambdas)
- [ ] **AC-6** AC-10 GDD test (move portion): GIVEN S1 with valid destination visible, WHEN player taps destination — THEN S2 entered (ghost unit / confirm button rendering deferred to Battle HUD epic, not part of FSM scope); WHEN player taps confirm — THEN unit moves (stub no-op acceptable), state returns to S0; both transitions emit signal pairs
- [ ] **AC-7** Re-entrancy hazard test: GIVEN test subscriber connects to `input_state_changed` WITHOUT `Object.CONNECT_DEFERRED`, WHEN subscriber's handler synchronously calls `InputRouter._handle_event(another_event)` mid-dispatch — THEN test asserts assertion-detectable behavior is well-defined (either: (a) both events process successfully sequentially, OR (b) a documented push_warning fires, OR (c) test fixture documents the actual observed behavior). The test EXISTS to lock the contract; production safety relies on ADR-0001 §5 deferred-connect mandate (downstream-consumer obligation, NOT enforced inside InputRouter itself)
- [ ] **AC-8** `_handle_action` invalid-state-action combinations silently ignored — e.g. `&"move_confirm"` in S0 → no state change, no emit, no error. Per ADR-0005 §5 inline match dispatch: missing action arms in a state are no-ops. Verified via test sweep across all (state, action) combinations (7 states × 22 actions ≥ 154 cases; sweep asserts no crashes; emits only on validated transitions)
- [ ] **AC-9** `tests/helpers/grid_battle_stub.gd` created — `class_name GridBattleStub extends RefCounted` with stub methods: `is_tile_in_move_range(coord: Vector2i) -> bool` (returns true for hardcoded coords {(1,1), (2,2), (3,3)}; false otherwise), `is_tile_in_attack_range(coord: Vector2i) -> bool` (story-004), `confirm_move(unit_id: int, coord: Vector2i) -> void` (no-op + records call to test-observable Array). Mirrors `tests/helpers/map_grid_stub.gd` precedent from hp-status epic
- [ ] **AC-10** Regression baseline maintained: full GdUnit4 suite passes ≥759 cases (story-002 baseline) + new tests / 0 errors / 0 failures / 0 orphans / Exit 0; new test file `tests/unit/foundation/input_router_fsm_core_test.gd` adds ≥12 tests covering AC-1..AC-9
- [ ] **AC-11** Stub injection seam: InputRouter exposes `var _grid_battle: Variant = null` field (typed `Variant` because GridBattleController class doesn't exist yet; story-014 narrows when Grid Battle ADR ships); test seam `func set_grid_battle_for_tests(stub: Variant) -> void` for stub injection (production sets via `set_grid_battle()` callable by Battle Preparation when scene loads — battle-prep ADR pending)

---

## Implementation Notes

*Derived from ADR-0005 §5 + GDD §States and Transitions + delta #6 Items 2, 4:*

1. **`_handle_action` skeleton** (verbatim per ADR-0005 §5 inline-match-dispatch decision):
   ```gdscript
   func _handle_action(action: StringName, ctx: InputContext) -> void:
       var prev_state: InputState = _state
       match _state:
           InputState.OBSERVATION:
               _handle_action_in_s0(action, ctx)
           InputState.UNIT_SELECTED:
               _handle_action_in_s1(action, ctx)
           InputState.MOVEMENT_PREVIEW:
               _handle_action_in_s2(action, ctx)
           InputState.ATTACK_TARGET_SELECT:
               _handle_action_in_s3(action, ctx)  # story-004
           InputState.ATTACK_CONFIRM:
               _handle_action_in_s4(action, ctx)  # story-004
           InputState.INPUT_BLOCKED:
               _handle_action_in_s5(action, ctx)  # story-007
           InputState.MENU_OPEN:
               _handle_action_in_s6(action, ctx)  # story-007
       # If _state changed during arm execution, emit pair
       if _state != prev_state:
           GameBus.input_state_changed.emit(int(prev_state), int(_state))
           GameBus.input_action_fired.emit(action, ctx)
   ```
   Note: emits at the END after each arm (single emit point — matches delta #6 Item 4 ordering: state change FIRST, emit SECOND, downstream handler runs AFTER).

2. **Per-state handler split rationale**: separate methods (`_handle_action_in_s0` etc.) keep each match arm <15 LoC and make per-state behavior trivially diff-able. Alternative inline `match action:` inside each state arm works but produces a single 100+ LoC method that's harder to read. ADR-0005 §5 doesn't mandate the split — orchestrator's call.

3. **S0 OBSERVATION arm** (`_handle_action_in_s0`):
   ```gdscript
   func _handle_action_in_s0(action: StringName, ctx: InputContext) -> void:
       match action:
           &"unit_select":
               if ctx.unit_id == -1:
                   return  # invalid context — silently ignore
               _state = InputState.UNIT_SELECTED
           &"camera_pan", &"camera_zoom_in", &"camera_zoom_out", &"camera_snap_to_unit":
               # Camera actions pass through without state change (ADR-0005 §5 + OQ-2 deferred resolution)
               pass
           &"open_unit_info":
               # Read-only; no state change
               pass
           &"open_game_menu":
               # → S6 (story-007); leave for now
               pass
           # All other actions: no-op in S0 (silently dropped per AC-8 invalid-action discipline)
   ```

4. **S1 UNIT_SELECTED arm**:
   ```gdscript
   func _handle_action_in_s1(action: StringName, ctx: InputContext) -> void:
       match action:
           &"move_target_select":
               if ctx.coord == Vector2i.ZERO:
                   return  # invalid context
               if not _is_tile_in_move_range(ctx.coord):
                   return  # invalid destination per EC-7
               _state = InputState.MOVEMENT_PREVIEW
           &"move_cancel", &"end_unit_turn":
               _state = InputState.OBSERVATION
           &"action_confirm":
               # Alias for move_target_select per CR-3a (PC keyboard shortcut)
               # Same behavior — validated via test
               pass  # currently no-op until coord is bound from cursor (Camera ADR pending)
           # ... other arms
   ```

5. **S2 MOVEMENT_PREVIEW arm**:
   ```gdscript
   func _handle_action_in_s2(action: StringName, ctx: InputContext) -> void:
       match action:
           &"move_confirm", &"action_confirm":
               # Apply move via stub (Grid Battle ADR pending)
               if _grid_battle != null and _grid_battle.has_method("confirm_move"):
                   _grid_battle.confirm_move(ctx.unit_id, ctx.coord)
               # Open undo window (story-006 implements full logic)
               # _open_undo_window(ctx.unit_id, ctx.coord)  # story-006
               _state = InputState.OBSERVATION
           &"move_cancel":
               _state = InputState.UNIT_SELECTED
   ```

6. **`_is_tile_in_move_range` helper**: defers to `_grid_battle` stub injection. If stub is null (production not yet wired), returns true (permissive — Grid Battle epic enforces real range query). Test injects stub explicitly:
   ```gdscript
   func _is_tile_in_move_range(coord: Vector2i) -> bool:
       if _grid_battle == null:
           return true  # permissive when no stub injected
       return _grid_battle.is_tile_in_move_range(coord)
   ```

7. **GridBattleStub** (`tests/helpers/grid_battle_stub.gd`):
   ```gdscript
   class_name GridBattleStub
   extends RefCounted

   var fixture_in_range_coords: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3)]
   var fixture_in_attack_coords: Array[Vector2i] = [Vector2i(4, 4), Vector2i(5, 5)]
   var confirm_move_calls: Array[Dictionary] = []
   var confirm_attack_calls: Array[Dictionary] = []  # story-004
   var occupied_coords: Array[Vector2i] = []  # story-006

   func is_tile_in_move_range(coord: Vector2i) -> bool:
       return coord in fixture_in_range_coords

   func is_tile_in_attack_range(coord: Vector2i) -> bool:
       return coord in fixture_in_attack_coords

   func confirm_move(unit_id: int, coord: Vector2i) -> void:
       confirm_move_calls.append({"unit_id": unit_id, "coord": coord})

   func is_tile_occupied(coord: Vector2i) -> bool:
       return coord in occupied_coords
   ```
   Same file extends through stories 004 + 006 (more methods added). Reusable across all input-handling integration tests.

8. **Re-entrancy hazard test (AC-7)**: complex test — set up subscriber that calls back into `_handle_event` synchronously without `CONNECT_DEFERRED`:
   ```gdscript
   func test_reentrancy_synchronous_subscriber_well_defined() -> void:
       var captures: Array = []
       GameBus.input_state_changed.connect(func(prev, new):
           captures.append({"prev": prev, "new": new})
           if captures.size() == 1:
               # Synchronously re-enter (NOT CONNECT_DEFERRED)
               var event2 := InputEventKey.new()
               event2.keycode = KEY_ESCAPE
               event2.pressed = true
               InputRouter._handle_event(event2)
       )
       # Trigger first event
       var event1 := InputEventKey.new()
       event1.keycode = KEY_ENTER
       event1.pressed = true
       InputRouter._handle_event(event1)
       await get_tree().process_frame
       # Assert observable behavior — document either both events processed or warning fired
       assert_int(captures.size()).is_greater_equal(1)  # at least the first transition emitted
       # Document outcome in test comment for ADR-0001 §5 + §6 Implementation Note Advisory D evidence
   ```

9. **Test file**: `tests/unit/foundation/input_router_fsm_core_test.gd` — 12-15 tests covering AC-1..AC-9. Pattern: GdUnitTestSuite Node-based extension; use `before_test()` G-15 reset of all 6 fields; explicit GridBattleStub injection via `InputRouter.set_grid_battle_for_tests(stub)`; signal-capture lambdas (G-4 pattern for handler-fired-then-state-asserted assertions).

10. **Sweep test for AC-8 invalid-action discipline**:
    ```gdscript
    func test_all_state_action_combinations_no_crash() -> void:
        for state_int in range(7):
            for category: StringName in InputRouter.ACTIONS_BY_CATEGORY.keys():
                for action: StringName in InputRouter.ACTIONS_BY_CATEGORY[category]:
                    InputRouter._state = state_int as InputRouter.InputState
                    var ctx := InputContext.new()
                    ctx.unit_id = 1
                    ctx.coord = Vector2i(1, 1)
                    InputRouter._handle_action(action, ctx)  # MUST NOT crash
    ```

11. **G-3 + G-22 test base**: extend GdUnitTestSuite per technical-preferences `Framework configuration` section. Use `FileAccess.get_file_as_string()` source-file structural assertions for state-arm presence verification (G-22 Path "Correct" pattern).

12. **`int()` cast for emit** per delta #6 Item 4: `GameBus.input_state_changed.emit(int(prev_state), int(_state))` — explicit cast prevents enum-to-int implicit-coercion warnings (Godot 4.6 `int_as_enum_without_cast` warning); also ensures wire-format consistency for save/load forward-compat.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 004**: S3 ATTACK_TARGET_SELECT + S4 ATTACK_CONFIRM arms; ST-2 demotion logic; end-player-turn safety gate (`end_phase_confirm` confirmation dialog flow)
- **Story 005**: Mode determination logic (`_handle_event` extension to set `_active_mode` based on event class BEFORE action match)
- **Story 006**: Undo window OPEN logic in S2 confirm arm (this story leaves placeholder comment); EC-5 occupied-tile rejection
- **Story 007**: S5 + S6 arms; GameBus subscriptions; `set_input_as_handled()` mandatory enforcement; `_input_blocked_reasons` PackedStringArray stack
- **Story 008-009**: Touch protocol — TPP fires from S0 in TOUCH mode; pan-vs-tap classifier overrides `move_target_select` action match in this story

---

## QA Test Cases

*Authored inline (lean mode QL-STORY-READY skip).*

- **AC-1**: `_handle_action` exists with correct signature
  - Given: InputRouter source file
  - When: grep for `func _handle_action(action: StringName, ctx: InputContext) -> void:`
  - Then: 1 match; `_handle_event` updated to call `_handle_action(action, ctx)` after match-store
  - Edge cases: assert `_last_matched_action` field removed (story-002 was test-observable; story-003 replaces with full dispatch)
- **AC-2**: S0 `unit_select` → S1 transition
  - Given: `_state = InputState.OBSERVATION`; ctx with `unit_id=1`, `coord=Vector2i(1,1)`
  - When: `_handle_action(&"unit_select", ctx)`
  - Then: `_state == InputState.UNIT_SELECTED`; `input_state_changed.emit(0, 1)` + `input_action_fired.emit(&"unit_select", ctx)` captured by signal subscribers
  - Edge cases: ctx with `unit_id=-1` → no transition, no emit; `&"unit_select"` in S1 (already in unit-selected) → no change
- **AC-3**: S1 transitions
  - Given: `_state = InputState.UNIT_SELECTED`; GridBattleStub injected with `Vector2i(1,1)` in range
  - When: `_handle_action(&"move_target_select", ctx with coord=(1,1))`
  - Then: `_state == InputState.MOVEMENT_PREVIEW`; signal pair emitted
  - Edge cases: `&"move_target_select"` with coord NOT in range → no transition (EC-7 silent rejection); `&"move_cancel"` → S0; `&"end_unit_turn"` → S0; `&"open_unit_info"` → no change (S1 retained)
- **AC-4**: S2 confirm + cancel
  - Given: `_state = InputState.MOVEMENT_PREVIEW`; GridBattleStub injected
  - When: `_handle_action(&"move_confirm", ctx with unit_id=1, coord=(1,1))`
  - Then: `_state == InputState.OBSERVATION`; GridBattleStub.confirm_move_calls contains `{"unit_id": 1, "coord": (1,1)}`; signal pair emitted (prev=2, new=0)
  - Edge cases: `&"move_cancel"` → S1; `&"action_confirm"` aliased identically; ctx with `coord=Vector2i.ZERO` → no transition (invalid context)
- **AC-5**: Signal-pair emit ordering
  - Given: any valid state transition
  - When: subscriber captures both signals via separate lambdas
  - Then: `input_state_changed` captured BEFORE `input_action_fired` (assert via timestamp/order in capture Array)
  - Edge cases: invalid action (no transition) → 0 emits; assert exactly 1 emit per signal per transition (no double-emit)
- **AC-6**: AC-10 GDD test (move flow end-to-end)
  - Given: S1 with valid destination
  - When: tap destination (inject `move_target_select` event); then tap confirm (inject `move_confirm` event)
  - Then: state sequence S1 → S2 → S0; 4 emits captured (2 signal-pair × 2 transitions); GridBattleStub.confirm_move_calls.size() == 1
- **AC-7**: Re-entrancy hazard well-defined (contract-locking test)
  - Given: subscriber connected WITHOUT CONNECT_DEFERRED that re-enters `_handle_event`
  - When: trigger initial event
  - Then: at minimum the first transition's emits captured; document observed second-event behavior in test comment (either: both transitions complete sequentially / push_warning fires / state observably-corrupted but recovered next frame)
  - Edge cases: re-run test 5x to confirm deterministic outcome (rule out race condition appearance)
- **AC-8**: All-(state, action) sweep no-crash
  - Given: 7 states × 22 actions = 154 combinations
  - When: each `_handle_action(action, ctx)` invoked with default ctx
  - Then: no crash, no SCRIPT ERROR; valid transitions produce emit pairs; invalid combinations are silent no-ops
  - Edge cases: assert orphan count in suite still 0 (no Object.new() leaks during sweep)
- **AC-9**: GridBattleStub structural correctness
  - Given: `tests/helpers/grid_battle_stub.gd` exists
  - When: instantiate via `var stub := GridBattleStub.new()`
  - Then: instance non-null; `is_tile_in_move_range(Vector2i(1,1))` returns true; `is_tile_in_move_range(Vector2i(99,99))` returns false; `confirm_move(1, Vector2i(1,1))` records call to `confirm_move_calls` Array
- **AC-10**: Regression baseline
  - Given: full suite invoked
  - When: 759 + new tests run
  - Then: ≥771 tests / 0 errors / 0 failures / 0 orphans / Exit 0
- **AC-11**: Stub injection seam
  - Given: InputRouter source file
  - When: grep for `func set_grid_battle_for_tests(stub: Variant) -> void:`
  - Then: 1 match; body sets `_grid_battle = stub`
  - Edge cases: assert NO production caller of this method (test-only seam — production injection is via separate `set_grid_battle()` method called by Battle Preparation)

---

## Test Evidence

**Story Type**: Logic (FSM transitions + signal emit are pure deterministic logic; stub injection is test-time only)
**Required evidence**: `tests/unit/foundation/input_router_fsm_core_test.gd` — must exist + ≥12 tests + must pass; `tests/helpers/grid_battle_stub.gd` exists with stub interface
**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 002 (action vocabulary + bindings + `_handle_event` matching loop must exist; this story replaces story-002's `_last_matched_action` with full `_handle_action` dispatch)
- **Unlocks**: Story 004 (S3/S4 attack flow extends `_handle_action` + GridBattleStub adds `is_tile_in_attack_range`), Story 006 (undo window — story-003 leaves placeholder in S2 arm), Story 007 (S5/S6 arms)
