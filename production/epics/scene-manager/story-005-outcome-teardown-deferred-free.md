# Story 005: Outcome-driven teardown + co-subscriber-safe free

> **Epic**: scene-manager
> **Status**: Ready
> **Layer**: Platform
> **Type**: Integration
> **Manifest Version**: 2026-04-20

## Context

**GDD**: — (infrastructure; authoritative spec is ADR-0002)
**Requirement**: `TR-scene-manager-004`

**ADR Governing Implementation**: ADR-0002 — §Key Interfaces `_on_battle_outcome_resolved` + `_free_battle_scene_and_restore_overworld` + §Risks R-1 (co-subscriber deferred-free race)
**ADR Decision Summary**: "On `battle_outcome_resolved`, transition RETURNING_FROM_BATTLE and `call_deferred('_free_battle_scene_and_restore_overworld')`. The call_deferred pushes free one additional frame so co-subscriber (ScenarioRunner) deferred handlers completing in the same frame can still read BattleScene node references safely."

**Engine**: Godot 4.6 | **Risk**: MEDIUM (CONNECT_DEFERRED + call_deferred ordering — verified by godot-specialist B-3 but requires empirical integration test on target device per V-5)
**Engine Notes**: The critical invariant: `CONNECT_DEFERRED` handlers fire on next idle frame; `call_deferred(method)` also fires on next idle frame, AFTER all CONNECT_DEFERRED handlers for the triggering emit. This means co-subscribers (ScenarioRunner) processing `battle_outcome_resolved` in their own CONNECT_DEFERRED handler can safely read `BattleScene` node references during their handler — SceneManager's `call_deferred('_free_...')` is queued BEHIND their handler. See gamebus story-007 cross-scene emit test as precedent pattern.

**Control Manifest Rules (Platform layer)**:
- Required: `call_deferred('_free_battle_scene_and_restore_overworld')` — NOT `queue_free()` directly in the CONNECT_DEFERRED handler (preserves co-subscriber refs for one additional frame)
- Required: `is_instance_valid(_battle_scene_ref)` guard before `queue_free()` in the deferred method
- Required: Overworld restoration via `_restore_overworld()` (from story 003) during teardown
- Forbidden: referencing `_battle_scene_ref` after `_free_battle_scene_and_restore_overworld` completes (nullify the ref)

## Acceptance Criteria

*Derived from ADR-0002 §Key Interfaces + §Validation Criteria V-5:*

- [ ] `_on_battle_outcome_resolved(outcome: BattleOutcome)` implemented:
  - `is_instance_valid(outcome)` guard + `push_warning` on invalid (matches gamebus pattern from MockScenarioRunner in story-007)
  - State guard: ignore if `_state != State.IN_BATTLE` (push_warning with current state; prevents spurious outcome handling)
  - Transition `_state = State.RETURNING_FROM_BATTLE`
  - `call_deferred('_free_battle_scene_and_restore_overworld')` — defers the free one additional frame
- [ ] `_free_battle_scene_and_restore_overworld()` implemented:
  - `if is_instance_valid(_battle_scene_ref): _battle_scene_ref.queue_free()` (queue_free OK here — we're past the co-subscriber race; the battle_scene is truly gone next frame)
  - `_battle_scene_ref = null`
  - Call `_restore_overworld()` (from story 003)
  - Transition `_state = State.IDLE`
  - `loading_progress = 0.0` (reset)
- [ ] Does NOT touch focus state (ADR-0002 §R-3: Overworld UI owns focus via visibility_changed hook; SceneManager never calls grab_focus)
- [ ] Does NOT emit `ui_input_unblock_requested` from this path — input was already unblocked at IN_BATTLE entry (story 004). State sequence: IN_BATTLE (input unblocked) → battle_outcome_resolved → RETURNING (input stays unblocked per ADR — player can interact with Overworld immediately when it reappears)
- [ ] Integration test `tests/integration/core/scene_handoff_timing_test.gd` — `test_co_subscriber_reads_battle_scene_ref_in_deferred_handler`:
  - Subscribes a test stub to `battle_outcome_resolved` via CONNECT_DEFERRED
  - Stub's handler reads `SceneManager._battle_scene_ref` (or calls a test-visible accessor)
  - Asserts `is_instance_valid(battle_scene_ref) == true` INSIDE the stub's deferred handler
  - After 2 await process_frames, asserts `is_instance_valid(battle_scene_ref) == false` (freed) AND `SceneManager.state == State.IDLE`
- [ ] Unit test: state transitions IN_BATTLE → RETURNING_FROM_BATTLE (synchronous in the handler) → IDLE (deferred)
- [ ] Unit test: duplicate `battle_outcome_resolved` in the same frame — second emission is ignored (state already RETURNING_FROM_BATTLE on second CONNECT_DEFERRED handler fire, OR state is IDLE if deferred free already ran). Handler's state guard covers this case.

## Implementation Notes

*From ADR-0002 §Key Interfaces + gamebus story-007 cross-scene emit test as reference:*

1. **The critical invariant** — ADR-0002 §Risks R-1 says the call_deferred MUST be on `_free_battle_scene_and_restore_overworld`, not on `queue_free()` directly. Reason: in the CONNECT_DEFERRED handler frame, we want other co-subscribers to finish THEIR handlers before we free. call_deferred pushes our free to the NEXT deferred queue, which runs AFTER all current-frame CONNECT_DEFERRED handlers.

2. **Implementation matches ADR §Key Interfaces snippet verbatim** — do not paraphrase. Exact code block:
   ```gdscript
   func _on_battle_outcome_resolved(outcome: BattleOutcome) -> void:
       if not is_instance_valid(outcome):
           push_warning("battle_outcome_resolved: invalid payload; ignored")
           return
       if _state != State.IN_BATTLE:
           push_warning("battle_outcome_resolved outside IN_BATTLE (state=%s); ignored" % State.keys()[_state])
           return
       _state = State.RETURNING_FROM_BATTLE
       call_deferred("_free_battle_scene_and_restore_overworld")
   ```

3. **Test co-subscriber stub** — integration test creates a test Node that subscribes to `GameBus.battle_outcome_resolved` via CONNECT_DEFERRED BEFORE the emit. Its handler reads (via a test-only accessor on SceneManager, or via direct introspection) the `_battle_scene_ref`. The assertion is that the ref is VALID when this stub's handler fires (proving the 1-frame defer works).

4. **Test emit sequence** — the integration test must:
   1. swap_in SceneManagerStub + GameBusStub
   2. Manually set `_state = State.IN_BATTLE` and `_battle_scene_ref = Node.new()` (mock BattleScene); add the mock to /root
   3. Connect the test stub's handler via CONNECT_DEFERRED
   4. Emit `battle_outcome_resolved(BattleOutcome.new())`
   5. `await get_tree().process_frame` — frame N: all CONNECT_DEFERRED handlers fire (SceneManager + test stub); SceneManager's handler sets state to RETURNING and calls call_deferred; test stub reads `_battle_scene_ref`, asserts valid
   6. `await get_tree().process_frame` — frame N+1: call_deferred fires; _free_battle_scene_and_restore_overworld runs; state → IDLE; battle_scene freed
   7. Assert final state == IDLE; battle_scene_ref == null (or invalid instance)

5. **Focus restoration NOT this story** — per R-3. DO NOT call `grab_focus()` anywhere in the teardown path.

6. **Input unblock NOT this story** — player can interact with restored Overworld immediately (no unblock signal needed; input was already unblocked at IN_BATTLE entry in story 004). This is intentional per ADR §Key Interfaces snippet (the `_free_battle_scene_and_restore_overworld` method has no `ui_input_unblock_requested.emit` line; only `_transition_to_error` does in story 006).

7. **`queue_free()` vs `free()` in teardown** — ADR snippet uses `queue_free()` (deferred deletion). Here that's correct because we're already past the co-subscriber race (we're in the call_deferred method, which fires the frame AFTER handlers). The BattleScene will be freed at end of this frame — no other code is expected to reference it post-teardown.

## Out of Scope

- Error recovery path (`_transition_to_error`) — story 006
- LOSS → retry loop integration test — story 006 (retry uses error path + re-emit; teardown path doesn't loop back to LOADING on its own)
- Android target-device co-subscriber race verification — story 007
- Memory-reclamation profiling after teardown — story 007

## QA Test Cases

*Test file*: `tests/integration/core/scene_handoff_timing_test.gd` (NEW) + `tests/unit/core/scene_manager_test.gd` (add cases)

- **AC-1** (outcome handler transitions state correctly):
  - Given: state == IN_BATTLE, `_battle_scene_ref` set to mock Node
  - When: `_on_battle_outcome_resolved(BattleOutcome.new())` called directly
  - Then: immediately after handler exits, state == RETURNING_FROM_BATTLE; call_deferred is queued

- **AC-2** (deferred free completes teardown):
  - Given: as AC-1
  - When: await 1 process_frame (deferred call fires)
  - Then: `_battle_scene_ref == null`; mock Node is_queued_for_deletion() == true; state == IDLE; loading_progress == 0.0

- **AC-3** (co-subscriber ref-safety — V-5):
  - Given: state == IN_BATTLE, `_battle_scene_ref` set; test-stub subscribed to `battle_outcome_resolved` via CONNECT_DEFERRED
  - When: emit battle_outcome_resolved; await 1 frame
  - Then: DURING test-stub's deferred handler (before await resolves), `is_instance_valid(SceneManager._battle_scene_ref) == true` — the co-subscriber can safely read the ref
  - After 2 awaits: battle_scene freed; state IDLE

- **AC-4** (invalid payload rejected):
  - Given: state == IN_BATTLE
  - When: `_on_battle_outcome_resolved(null)` (simulate freed/null payload)
  - Then: state unchanged (still IN_BATTLE); push_warning fires; call_deferred NOT queued

- **AC-5** (state guard rejects outside IN_BATTLE):
  - Given: state == IDLE (or LOADING_BATTLE or ERROR)
  - When: outcome handler called
  - Then: state unchanged; push_warning with current state in message; call_deferred NOT queued

- **AC-6** (duplicate outcome in same frame):
  - Given: state == IN_BATTLE
  - When: handler fires twice in same frame (race simulation: call _on_battle_outcome_resolved twice synchronously)
  - Then: first call transitions to RETURNING; second call is rejected by state guard (state != IN_BATTLE)

- **AC-7** (Overworld restored correctly):
  - Given: paused Overworld + mock BattleScene; state == IN_BATTLE
  - When: outcome handler + await frame
  - Then: Overworld's 4 suppression properties restored to active values (process_mode INHERIT, visible true, process_input true, process_unhandled_input true); UIRoot mouse_filter == STOP

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/core/scene_handoff_timing_test.gd` (NEW — at least AC-3 co-subscriber test) + additions to `tests/unit/core/scene_manager_test.gd` — must exist and pass (BLOCKING gate)
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: Story 001 (skeleton + signal subscription), Story 002 (stub for isolation), Story 003 (`_restore_overworld` available), Story 004 (IN_BATTLE state reachable + `_battle_scene_ref` populated)
- **Unlocks**: Story 006 (error-recovery path reuses restoration logic from this story); Story 007 (target-device co-subscriber race test)
