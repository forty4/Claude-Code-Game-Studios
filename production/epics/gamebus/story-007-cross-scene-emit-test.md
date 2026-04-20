# Story 007: Cross-scene emit integration test

> **Epic**: gamebus
> **Status**: Ready
> **Layer**: Platform
> **Type**: Integration
> **Manifest Version**: 2026-04-20

## Context

**GDD**: — (infrastructure; scene-boundary survival per ADR-0001)
**Requirement**: `TR-gamebus-001` + `TR-scenario-progression-003` (EC-SP-5 duplicate-guard pattern)

**ADR Governing Implementation**: ADR-0001 — §Validation Criteria V-4 + §Implementation Guidelines §6 (Lifecycle discipline)
**ADR Decision Summary**: "A cross-scene emit test passes — `BattleController` (in battle scene) emits `battle_outcome_resolved`; `ScenarioRunner` (in overworld scene) receives it after battle scene is freed. Freed-battle-scene test asserts no dangling reference errors."

**Engine**: Godot 4.6 | **Risk**: MEDIUM (deferred-handler ordering across scene boundaries; `is_instance_valid` guards; SceneTree frame semantics)
**Engine Notes**: `CONNECT_DEFERRED` fires handlers on the next idle frame. Combined with `call_deferred` for scene free (per ADR-0002 TR-scene-manager-004), this creates a two-frame ordering that must be verified on actual Godot 4.6 behavior, not assumed.

**Control Manifest Rules (Platform layer)**:
- Required: `CONNECT_DEFERRED` mandatory for cross-scene connects
- Required: Every signal handler guards Resource payloads with `is_instance_valid`
- Required: Every `connect` in `_ready` has matching `disconnect` in `_exit_tree` guarded by `is_connected`
- Forbidden: Direct node references across scene boundaries

## Acceptance Criteria

*Derived from ADR-0001 §Validation Criteria V-4 + §Risks mitigation (cross-scene freed-Resource scenario):*

- [ ] `tests/integration/core/cross_scene_emit_test.gd` — GdUnit4 integration test class
- [ ] Synthetic battle-scene fixture: `tests/fixtures/scenes/mock_battle_scene.tscn` — minimal PackedScene with a `MockBattleController` node that can emit `GameBus.battle_outcome_resolved(payload)`
- [ ] Synthetic overworld-scene fixture: `tests/fixtures/scenes/mock_overworld.tscn` — minimal PackedScene with a `MockScenarioRunner` node that subscribes to `GameBus.battle_outcome_resolved` via `CONNECT_DEFERRED` in `_ready`, disconnects in `_exit_tree`, and records received payloads
- [ ] Test happy-path scenario:
  1. Load mock_overworld as current scene; MockScenarioRunner subscribes
  2. Instantiate mock_battle_scene as a `/root` peer (simulating ADR-0002 topology)
  3. MockBattleController emits `battle_outcome_resolved(synthetic_payload)`
  4. `call_deferred` free the battle scene (mimicking SceneManager's `_free_battle_scene_and_restore_overworld` pattern)
  5. Advance one idle frame (GdUnit4 `await get_tree().process_frame` or equivalent)
  6. Assert MockScenarioRunner received the payload exactly once
  7. Assert payload fields match synthetic values (no corruption)
  8. Assert no `push_error` or null-reference logs generated during sequence
- [ ] Test freed-payload edge case: verify that even if the battle scene's node hierarchy is torn down, the `BattleOutcome` payload (a Resource, not a Node) remains valid — Godot's Resource refcount keeps it alive while the signal handler holds a reference
- [ ] Test dangling-subscriber edge case: MockScenarioRunner calls `disconnect` in `_exit_tree`; after overworld scene is freed and re-instantiated, fresh subscriber connects — no stale-subscriber handler fires on a subsequent emit
- [ ] Test payload guard: emit `battle_outcome_resolved` with a payload that is subsequently freed BEFORE the deferred handler fires; assert handler's `is_instance_valid` guard catches and logs `push_warning("invalid payload; ignored")` without crashing
- [ ] Test duplicate-emission guard (TR-scenario-progression-003 / EC-SP-5): emit `battle_outcome_resolved` twice in quick succession; MockScenarioRunner's state-guard (a boolean "consumed" flag) ignores the second emission and logs `push_warning`
- [ ] Cleanup: `after_test` frees all synthetic scenes and disconnects all signal handlers

## Implementation Notes

*From ADR-0001 §Implementation Guidelines §6 + ADR-0002 §Key Interfaces `_free_battle_scene_and_restore_overworld` pattern:*

1. **MockScenarioRunner skeleton**:
   ```gdscript
   class_name MockScenarioRunner extends Node
   var received: Array[BattleOutcome] = []
   var _consumed_once: bool = false

   func _ready() -> void:
       GameBus.battle_outcome_resolved.connect(_on_battle_outcome, CONNECT_DEFERRED)

   func _exit_tree() -> void:
       if GameBus.battle_outcome_resolved.is_connected(_on_battle_outcome):
           GameBus.battle_outcome_resolved.disconnect(_on_battle_outcome)

   func _on_battle_outcome(outcome: BattleOutcome) -> void:
       if not is_instance_valid(outcome):
           push_warning("battle_outcome_resolved: invalid payload; ignored")
           return
       if _consumed_once:
           push_warning("battle_outcome_resolved: duplicate emission; ignored (EC-SP-5)")
           return
       _consumed_once = true
       received.append(outcome)
   ```

2. **MockBattleController skeleton**:
   ```gdscript
   class_name MockBattleController extends Node
   func emit_outcome(payload: BattleOutcome) -> void:
       GameBus.battle_outcome_resolved.emit(payload)
   ```

3. **Frame advancement in tests** — use `await get_tree().process_frame` after `CONNECT_DEFERRED` emits + `call_deferred` frees to let Godot's idle-frame pipeline run. May need 2 frames for a deferred-then-freed sequence (depends on GdUnit4 harness behavior — verify empirically in first iteration).

4. **GameBus stub integration** — these tests use the real `/root/GameBus` autoload (integration test, not unit). If stub isolation is needed (to avoid interference from GameBusDiagnostics counter increments from other test-in-progress activity), use `GameBusStub.swap_in()` from Story 006 — but this changes the test's classification from "integration" toward "unit-with-real-signals". Recommend: use real GameBus, keep as integration.

5. **is_instance_valid coverage for Resource payloads** — Godot's Resource lifecycle is refcounted; a Resource is freed when refcount drops to zero. If the emitter's only strong ref is released and the deferred-queued handler hasn't fired yet, the Resource can be invalidated mid-flight. Test simulates this by explicitly `payload.free()` (for Object) or dropping the last ref (for Resource) before `await process_frame`.

6. **TR-scenario-progression-003 pattern preservation** — EC-SP-5 in Scenario Progression GDD documents the duplicate-emission guard ("ScenarioRunner maintains a guard, ignoring duplicate"). This test is the reference implementation proving the pattern works.

7. **Why integration not unit** — this test exercises Godot's scene tree, autoload, and deferred-signal pipeline simultaneously. Mocking any of these would reduce to a unit test of a smaller slice; V-4 specifically requires the real pipeline.

## Out of Scope

- **Real BattleController / ScenarioRunner** — those are owned by Scenario Progression + Grid Battle epics. This story uses mocks.
- **SceneManager integration** — SceneManager's actual `_free_battle_scene_and_restore_overworld` is NOT invoked here. This story tests only the GameBus cross-scene emit primitive. The full SceneManager ↔ GameBus handshake is tested in `scene-manager` epic's Story (to be created) `scene_handoff_timing_test.gd`.
- **Scenario Progression state machine** — full 8-beat ceremony not in scope. Mock just subscribes once.
- **Performance timing** — frame-time measurement is V-8, belongs to Vertical Slice polish, not this epic.

## QA Test Cases

*Inline QA specification.*

**Test file**: `tests/integration/core/cross_scene_emit_test.gd`

- **AC-1** (happy path emit → free → receive):
  - Given: overworld scene + MockScenarioRunner instantiated at `/root`; battle scene + MockBattleController instantiated as `/root` peer
  - When: `MockBattleController.emit_outcome(BattleOutcome.new())`; battle scene `call_deferred("queue_free")`; await 2 process frames
  - Then: MockScenarioRunner.received.size() == 1; received payload fields match emitted; no push_error logs; no dangling-ref crashes
  - Edge: assert battle scene node is freed after the second frame

- **AC-2** (disconnect on exit):
  - Given: overworld scene currently loaded with MockScenarioRunner subscribed
  - When: overworld scene `queue_free()` (simulates main-menu return); check `GameBus.battle_outcome_resolved.get_connections()`
  - Then: no connections reference the freed MockScenarioRunner (clean disconnect via `_exit_tree`)
  - Edge: emit a signal afterward; no-one receives (no stale handler)

- **AC-3** (is_instance_valid guard):
  - Given: payload emitted with deferred connection; payload's only strong ref released
  - When: handler fires next frame
  - Then: `is_instance_valid(payload)` returns false; handler's early-return path taken; `push_warning` recorded with message "invalid payload; ignored"
  - Note: harder to test deterministically — may require explicit payload lifecycle control. If too fragile, mark as advisory with manual verification note

- **AC-4** (duplicate emission guard — EC-SP-5):
  - Given: MockScenarioRunner in fresh state (not yet consumed)
  - When: `MockBattleController.emit_outcome(payload1)`; `MockBattleController.emit_outcome(payload2)` (both in same frame); await one process frame
  - Then: `MockScenarioRunner.received.size() == 1` (only first received); `_consumed_once == true`; second handler invocation logged `push_warning` with EC-SP-5 message
  - Edge: payload1 was received; payload2 ignored

- **AC-5** (re-instantiation fresh):
  - Given: overworld scene freed and re-instantiated; new MockScenarioRunner subscribes
  - When: `MockBattleController.emit_outcome(payload)`; await one process frame
  - Then: NEW MockScenarioRunner receives payload; old subscriber (freed) does not re-receive
  - Edge: verifies scene lifecycle signal contract integrity across reload

- **AC-6** (no dangling-ref errors):
  - Given: full happy-path sequence
  - When: monitor Godot error log during test
  - Then: zero entries matching pattern "Attempt to use invalid instance" or "Object was freed" or "Nil instance"

- **AC-7** (cleanup):
  - Given: `after_test` runs
  - When: inspect `/root` children
  - Then: no leftover synthetic scenes; no orphan MockScenarioRunner / MockBattleController instances; any test-added connections to `GameBus` are released

- **AC-8** (deterministic):
  - Given: 10 consecutive runs
  - Then: identical pass result each run; CONNECT_DEFERRED ordering behavior is stable

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/integration/core/cross_scene_emit_test.gd` + fixture scenes — must exist and pass
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: Story 001 (BattleOutcome payload class); Story 002 (GameBus autoload); Story 006 (stub pattern optional but recommended for test isolation)
- **Unlocks**: SceneManager epic's `scene_handoff_timing_test.gd` (can reuse fixture patterns); proves the core ADR-0001 scene-boundary-survival contract works in practice
