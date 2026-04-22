# Story 006: Error recovery + retry loop

> **Epic**: scene-manager
> **Status**: Complete
> **Layer**: Platform
> **Type**: Integration
> **Estimate**: medium (~3-5h) — `_transition_to_error` body (one method, ~6 lines) is straightforward (calls existing `_restore_overworld` per story-003 DRY pattern); bulk of work is MockScenarioRunner retry extension + AC-5/AC-7 5-cycle retry integration test + AC-3/AC-4/AC-6 ERROR-path coverage + 3 unit tests for AC-1/AC-2. Per-cycle memory profiling deferred to story-007.
> **Manifest Version**: 2026-04-20

## Context

**GDD**: — (infrastructure; authoritative spec is ADR-0002)
**Requirement**: `TR-scene-manager-005`

**ADR Governing Implementation**: ADR-0002 — §Key Interfaces `_transition_to_error` + §State Machine ERROR state + §GDD Requirements Addressed (Scenario Progression F-SP-3 Echo retry)
**ADR Decision Summary**: "On async-load failure, emit `scene_transition_failed(context, reason)` via GameBus + transition to ERROR state. Restore Overworld for error-dialog visibility. Recovery only via re-emit of `battle_launch_requested` (ScenarioRunner-initiated retry). Preserves Overworld state across retry loops for Echo-retry mechanic."

**Engine**: Godot 4.6 | **Risk**: LOW (signal emission + state transition; pre-cutoff stable APIs)
**Engine Notes**: `scene_transition_failed(context: String, reason: String)` signal is already declared on GameBus (landed with gamebus story-002). No signal-contract changes needed in this PR.

**Control Manifest Rules (Platform layer)**:
- Required: `scene_transition_failed.emit` on unrecoverable load failure
- Required: ERROR state is exit-only via `battle_launch_requested` re-emit (no automatic recovery)
- Required: Overworld restored on ERROR entry (for error-dialog visibility per ADR §Risks)
- Forbidden: silent failure (every failure path MUST emit `scene_transition_failed` with actionable reason)
- Forbidden: calling `_transition_to_error` from `_process` / `_physics_process` (all error paths are event-driven)

## Acceptance Criteria

*Derived from ADR-0002 §Key Interfaces + §Validation Criteria V-4 (full), V-11:*

- [ ] `_transition_to_error(reason: String)` implemented:
  - `_state = State.ERROR`
  - `loading_progress = 0.0` (reset — in case error fires during LOADING)
  - `GameBus.scene_transition_failed.emit("scene_manager", reason)` — per ADR-0001 amendment already live
  - `GameBus.ui_input_unblock_requested.emit("scene_transition")` — unblocks input so player can interact with error dialog that ScenarioRunner shows
  - Call `_restore_overworld()` (from story 003) — makes Overworld visible so error dialog is rendered on top of restored UI (per ADR §Key Interfaces — transition_to_error restores Overworld even though it was paused)
- [ ] Called by: story 004's `_on_battle_launch_requested` on `load_threaded_request` err != OK; story 004's `_on_load_tick` on `THREAD_LOAD_INVALID_RESOURCE` / `THREAD_LOAD_FAILED`; story 004's `_instantiate_and_enter_battle` on packed == null after `load_threaded_get`. All three callers are already wired in story 004 — this story only implements the method body.
- [ ] ERROR state transitions: `battle_launch_requested` while in ERROR is ACCEPTED (transitions to LOADING_BATTLE) — enables retry. No other signal triggers ERROR exit. This is the sole allowed recovery path.
- [ ] `_state` remains ERROR until retry emit fires — no timeouts, no self-recovery
- [ ] `_battle_scene_ref` is null while in ERROR (load failed before instantiate OR instantiate itself failed)
- [ ] Integration test `tests/integration/core/scene_manager_retry_test.gd`:
  - Simulates LOSS outcome flow: IN_BATTLE → battle_outcome_resolved(Result=LOSS) → IDLE (teardown) → ScenarioRunner re-emits battle_launch_requested → LOADING_BATTLE → IN_BATTLE (same map re-loaded)
  - Asserts Overworld state (proxied via a test-stub ScenarioRunner's `_retry_count` variable) survives the retry — the Node instance is the same pre- and post-retry (ref equality)
  - Asserts Overworld's `_retry_count` increments correctly across retries (F-SP-3 Echo accumulation proxy)
  - NOTE: the test uses a MockScenarioRunner (or extends gamebus story-007's MockScenarioRunner) — no real ScenarioRunner exists yet in the project
- [ ] Integration test: LOADING_BATTLE failure → ERROR → retry path:
  - State sequence IDLE → LOADING_BATTLE (fails) → ERROR → LOADING_BATTLE (retry) → IN_BATTLE (success second attempt)
  - `scene_transition_failed` fires exactly once on the first failure
  - Overworld properties are restored on ERROR entry (not left paused — player needs to see error dialog)

## Implementation Notes

*From ADR-0002 §Key Interfaces `_transition_to_error` snippet verbatim:*

1. **Implementation matches ADR snippet**:
   ```gdscript
   func _transition_to_error(reason: String) -> void:
       _state = State.ERROR
       loading_progress = 0.0
       GameBus.scene_transition_failed.emit("scene_manager", reason)
       GameBus.ui_input_unblock_requested.emit("scene_transition")
       # Restore Overworld so the player can see the error dialog ScenarioRunner shows.
       if is_instance_valid(_overworld_ref):
           _overworld_ref.process_mode = Node.PROCESS_MODE_INHERIT
           _overworld_ref.visible = true
           _overworld_ref.set_process_input(true)
           _overworld_ref.set_process_unhandled_input(true)
           # Mouse_filter restoration handled by _restore_overworld per story 003
   ```
   Actually — since story 003 implemented `_restore_overworld()` with the full restoration logic including mouse_filter, `_transition_to_error` should call `_restore_overworld()` directly instead of duplicating the 4 property assignments. Use the helper.

   Refactored implementation:
   ```gdscript
   func _transition_to_error(reason: String) -> void:
       _state = State.ERROR
       loading_progress = 0.0
       GameBus.scene_transition_failed.emit("scene_manager", reason)
       GameBus.ui_input_unblock_requested.emit("scene_transition")
       _restore_overworld()   # from story 003
   ```

2. **Retry entry is via story 004's handler** — `_on_battle_launch_requested` ALREADY accepts entry from ERROR state (story 004 AC-2 state guard allows IDLE or ERROR). This story doesn't add retry code; it verifies the full loop works end-to-end.

3. **LOSS retry is distinct from ERROR retry**:
   - **LOSS retry**: battle finishes normally with outcome.result == LOSS; SceneManager enters IDLE via story-005 teardown; ScenarioRunner initiates retry (re-emits battle_launch_requested). This path doesn't touch ERROR state.
   - **ERROR retry**: load or instantiate fails; SceneManager enters ERROR; ScenarioRunner shows dialog; player chooses retry → ScenarioRunner re-emits battle_launch_requested. This path transitions ERROR → LOADING_BATTLE.

   Both paths work with the same handler logic because story 004 accepts IDLE or ERROR as valid entry states.

4. **MockScenarioRunner for integration test** — gamebus story-007 created `MockScenarioRunner` in `tests/integration/core/`. Extend it here (or create `MockScenarioRunnerWithRetry` subclass) with a `_retry_count: int` field that increments in `_on_battle_outcome_resolved` and emits `battle_launch_requested` again on LOSS. This simulates F-SP-3 Echo-retry without requiring the real ScenarioRunner implementation (not yet in the project).

5. **Test sequence for retry integration**:
   1. swap_in both stubs (GameBus + SceneManager)
   2. Add MockScenarioRunner + MockBattleController + mock Overworld Node to /root (tracked in _spawned for cleanup)
   3. Emit battle_launch_requested → LOADING → IN_BATTLE (await frames)
   4. MockBattleController emits battle_outcome_resolved(LOSS) → teardown → IDLE (await 2 frames)
   5. MockScenarioRunner's handler saw LOSS → re-emits battle_launch_requested
   6. Assert: state back to LOADING_BATTLE → IN_BATTLE
   7. Assert: Overworld Node is THE SAME reference (ref equality) pre- and post-retry — state preserved
   8. Assert: MockScenarioRunner._retry_count == 1

6. **ERROR path integration test** — separate test function in the same file:
   1. Emit battle_launch_requested with invalid map_id → load fails → ERROR
   2. Assert: scene_transition_failed fires once with context="scene_manager"
   3. Assert: state == ERROR; Overworld restored (visible=true, process_mode=INHERIT)
   4. Assert: retry via valid map_id transitions ERROR → LOADING_BATTLE → IN_BATTLE

## Out of Scope

- Real ScenarioRunner implementation — Scenario Progression epic (Feature layer)
- Error dialog UI — Scenario Progression epic + UI epic
- Android target-device error-path verification — story 007
- Memory stability across many retry loops — story 007 (V-8 memory profile)

## QA Test Cases

*Test files*: `tests/unit/core/scene_manager_test.gd` (unit: transition_to_error behavior) + `tests/integration/core/scene_manager_retry_test.gd` (NEW: full retry loop)

- **AC-1** (transition_to_error state + emissions):
  - Given: state == LOADING_BATTLE or IN_BATTLE
  - When: `_transition_to_error("load_failed: test")` called
  - Then: state == ERROR; `scene_transition_failed` emitted with ("scene_manager", "load_failed: test"); `ui_input_unblock_requested` emitted with "scene_transition"; loading_progress == 0.0

- **AC-2** (Overworld restored on error):
  - Given: Overworld paused (4 suppression properties active); state LOADING_BATTLE
  - When: `_transition_to_error(...)` fires
  - Then: Overworld fully restored (all 4 properties active); UIRoot mouse_filter == STOP

- **AC-3** (ERROR state rejects other signals):
  - Given: state == ERROR
  - When: emit `battle_outcome_resolved` (spurious)
  - Then: handler's state guard ignores (state stays ERROR); push_warning fires

- **AC-4** (retry from ERROR — single cycle):
  - Given: state == ERROR; valid BattlePayload(map_id="test_ok")
  - When: emit `battle_launch_requested` → await async load
  - Then: state sequence ERROR → LOADING_BATTLE → IN_BATTLE; no `scene_transition_failed` on retry success

- **AC-5** (F-SP-3 Echo retry loop — Overworld state preserved):
  - Given: MockScenarioRunner with `_retry_count = 0` + mock Overworld mounted; state == IDLE
  - When: full loop: launch → IN_BATTLE → outcome LOSS → teardown → IDLE → retry re-emit → LOADING_BATTLE → IN_BATTLE
  - Then: Overworld Node ref unchanged (is THE SAME instance); MockScenarioRunner._retry_count == 1; Overworld can be pause/restored multiple times without state loss

- **AC-6** (no `scene_transition_failed` on normal teardown):
  - Given: state == IN_BATTLE
  - When: battle_outcome_resolved fires with outcome.result = WIN; teardown completes
  - Then: `scene_transition_failed` NOT emitted (normal teardown is a WIN/DRAW/LOSS outcome, not an error)

- **AC-7** (multi-retry determinism):
  - Given: 5 consecutive retry cycles with MockScenarioRunner
  - When: each cycle: LOSS → retry
  - Then: Overworld Node is the SAME reference all 5 times; _retry_count == 5; state sequence consistent; no memory leak (no orphan BattleScene nodes after each teardown)

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/core/scene_manager_test.gd` (unit tests for _transition_to_error) + `tests/integration/core/scene_manager_retry_test.gd` (NEW — full retry loop + ERROR recovery) — both must exist and pass (BLOCKING gate)
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: Story 001 (skeleton), Story 002 (stub), Story 003 (`_restore_overworld`), Story 004 (error-path hooks already call `_transition_to_error`; ERROR retry entry via `_on_battle_launch_requested` state guard), Story 005 (teardown path + MockScenarioRunner pattern for retry test)
- **Unlocks**: Story 007 (target-device error-path + retry memory profile verification); completes the core epic scope — remaining V-7 + V-8 are target-device checks in story 007

## Completion Notes

**Completed**: 2026-04-22
**Criteria**: 7/7 passing
**Test Evidence**: `tests/unit/core/scene_manager_test.gd` (3 new tests: AC-1, AC-2, AC-3+AC-6 combined) + `tests/integration/core/scene_manager_retry_test.gd` (NEW, 3 tests: AC-4 single ERROR→retry, AC-5 LOSS→retry ref equality, AC-7 5-cycle determinism) + extended `tests/integration/core/mock_scenario_runner.gd`. Full suite 100/100, 0 orphans, exit 0 (after round-2 fix + F-1/F-2 polish).
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (/code-review 2026-04-22, lean). F-1 + F-2 applied in-cycle; F-3/F-4/T-1 + 2 edge-case advisories logged as TD-021.
**Deviations**: None blocking.
- **Minor deviation from ADR snippet (approved by story-005 precedent)**: `_transition_to_error` calls `_restore_overworld()` (DRY) instead of inlining 3-4 property resets. 3rd story to leverage this abstraction (story-005 teardown, story-006 error, story-003 origin).
- **Removed `push_error`** from `_transition_to_error` — replaced by canonical `GameBus.scene_transition_failed` emit per Control Manifest ("Forbidden: silent failure — every failure path MUST emit scene_transition_failed"). Also cleaned up stale comment in story-004's direct unit test.
- **OUT OF SCOPE (justified, tracked in TD-021)**: `.claude/rules/godot-4x-gotchas.md` G-11 added (as Node cast on freed Variant crashes even with is_instance_valid not yet called). Touched `docs/tech-debt-register.md` with TD-021.
- **MockScenarioRunner Option A extension**: added `_retry_count`, `auto_retry_on_loss: bool`, `_retry_payload: BattlePayload`, `reset_for_new_battle()`, `set_retry_payload()`, `_emit_retry()` via call_deferred. Preserves gamebus story-007 contract (LIMITATION note at lines 30-35 anticipated this exact need).
**Manifest Version compliance**: 2026-04-20 matches current control-manifest.

**Key observations this cycle**:
- **Two major discoveries** worth codifying:
  - **G-11**: `as Node` cast on freed Object crashes even when declared `Variant`. `is_instance_valid()` MUST precede ANY `as T` cast. Distinct from G-3/G-10. Real crash with misleading error location (cast line, not caller). Centralize cleanup in guarded helper; do not inline cast at each call site. Codified with full Context/Broken/Correct/Discovered format.
  - **`get_tree().current_scene = mock` test seam**: clean production-mirror pattern for overriding what `_on_battle_launch_requested` captures as the Overworld ref. No production behavior hidden. Codified as test-seam note (inline, not standalone gotcha).
- **3-frame deferred queue ordering** for cross-system retry flows: Frame N (CONNECT_DEFERRED handlers) → Frame N+1 (call_deferred from SM + from MockScenarioRunner) → Frame N+2 (retry's CONNECT_DEFERRED handler). Documented in MockScenarioRunner + test file headers to prevent re-derivation.
- **Fast-load silent-pass risk** (F-2): conditional `if sm.state == LOADING_BATTLE: _poll_until_state_changes` can silently skip IN_BATTLE assertion on very fast loads. Unconditional post-poll state check added as regression guard (AC-5 + AC-7).

**Files changed**:
- `src/core/scene_manager.gd` — `_transition_to_error` extended from minimal (story-004 stub) to full ADR-0002 implementation
- `tests/unit/core/scene_manager_test.gd` — 3 new tests in `# ── Story 006` section (27 → 30 tests in file); comment update on story-004's `_transition_to_error` direct unit test (push_error expectation removed)
- `tests/integration/core/mock_scenario_runner.gd` — Option A direct extension (added retry surface, preserved gamebus story-007 contract)
- `tests/integration/core/scene_manager_retry_test.gd` — NEW file, 3 integration tests
- `.claude/rules/godot-4x-gotchas.md` — G-11 appended
- `docs/tech-debt-register.md` — TD-021 appended

**Implementation notes for story-007 (final story)**:
- Story-007 scope: target-device (Android) verification of V-7 (recursive Control disable) + V-8 (memory stability across many retry loops). Per-cycle memory profiling is the final gap.
- TD-021 T-edge-1/T-edge-2 naturally fit story-007 scope: `_transition_to_error` with null `_overworld_ref` + double-invocation.
- G-11 is now codified; future Android test cleanup in story-007 should follow the `is_instance_valid`-before-cast pattern.
