# Story 007: Cross-scene emit integration test

> **Epic**: gamebus
> **Status**: Complete
> **Layer**: Platform
> **Type**: Integration
> **Manifest Version**: 2026-04-20
> **Estimate**: medium (~3-4h) — actual ~5h across 6 implementation rounds (most iterative story to date; 3 new engine gotchas discovered + 1 real bug's worth of hardening applied)

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

## Completion Notes

**Completed**: 2026-04-21
**Criteria**: 8/8 testable ACs PASS + 1 BONUS test; 57/57 full unit+integration suite green in ~550ms, 0 orphans, GODOT EXIT 0, stdout clean
**Verdict**: COMPLETE WITH NOTES

**Test Evidence**: 3 artifacts in `tests/integration/core/` (new directory for the project):
- `mock_scenario_runner.gd` (~67 LoC) — class_name MockScenarioRunner with CONNECT_DEFERRED connect in _ready + is_connected-guarded disconnect in _exit_tree + is_instance_valid guard + EC-SP-5 _consumed_once duplicate guard
- `mock_battle_controller.gd` (~18 LoC) — class_name MockBattleController.emit_outcome(payload) helper
- `cross_scene_emit_test.gd` (~580 LoC post-hardening) — 9 test functions (8 AC-driven + 1 bonus null-payload automation of AC-3 partial false-path)

**Code Review**: Complete — `/code-review` initial verdict **APPROVED WITH SUGGESTIONS** (0 BLOCKING, 0 WARNING, 6 SUGGESTIONS + 4 ADVISORY gaps). Option C accepted: full hardening (9 changes) + new null-payload test + AC-6 explicit state assertion. Post-hardening round: 5 format-string concat sites fixed (`%` binding gotcha). Final verdict: **APPROVED**.

**Files delivered** (all in `tests/integration/core/`, new directory):
- 3 files listed above
- Zero src/ or project.godot changes
- CI workflow (`.github/workflows/tests.yml`) already covered `tests/integration` path from earlier work — no workflow changes needed

**Actual effort**: ~5h across 6 implementation rounds — most iterative story to date. Reasons: first integration test (new directory + patterns), first async test usage (`await get_tree().process_frame`), 3 new GDScript 4.x gotchas discovered during implementation (session total: 9).

**Implementation rounds**:
1. Initial write → 3 compile errors (autoload API collision from prior sessions, GdUnit4 `assert_signal_emit_count()` doesn't exist, loop variable scoping)
2. Fix compile → 56 tests run, 1 runtime error: typed-Array demotion in `Signal.get_connections()`
3. Fix runtime → 56/56 PASS, exit 0
4. Post-/code-review Option C plan → 9 hardening changes + 1 new null-payload test
5. Option C applied → 57/57 PASS but 8 format-string warnings in stdout (5 broken `"a" + "b" % args` concat sites)
6. Format-string fixes → 57/57 PASS, 0 orphans, exit 0, stdout clean

**Mid-flight corrections applied** (documented in commit messages):
- **Signal API (round 2)**: `.get_signal_connection_list()` doesn't exist on Signal in Godot 4.6 — correct API is `Signal.get_connections()` (Signal method) or `Object.get_signal_connection_list("sig_name")` (Object method). Chose Signal method for type safety.
- **Typed-Array demotion (round 2)**: `Signal.get_connections()` returns untyped `Array`, not `Array[Dictionary]` — declared outer as untyped `Array`, typed `for conn: Dictionary in ...` loop variable narrows element type. Same gotcha class as story-003 W-1 (`Array[T].duplicate()` demotion).
- **GdUnit4 parse-failure silence (round 1→2)**: parse error in test file silently reported as "no tests" with exit 0 — Overall Summary showed 48/48 unit tests only, masking that integration file never loaded. Critical CI-verification lesson: must check Overall Summary count matches expected, not just exit code.
- **Option C hardening (round 4)**: 9 items covering AC-1 comment accuracy (two-frame reasoning), AC-6 tautology → explicit dangling-count assertion, AC-8 `_spawn_at_root` deviation rationale, AC-3 docstring Resource-vs-Object distinction, `_consumed_once` limitation note in mock, `round` → `round_num` param rename (GDScript builtin shadowing), null-payload test (partial AC-3 automation), GdUnit4 `skip()` investigation.
- **Format-string concat (round 6)**: 5 sites broken `"a" + "b" % args` pattern. `%` binds only to immediate left operand — multi-line concats need explicit parens `("a" + "b") % args`. Non-failing but pollutes CI stdout.

**3 new GDScript 4.x / GdUnit4 gotchas discovered** (to be codified in TD-013):
7. **GdUnit4 silently treats parse-failed scripts as "no tests"** — exit 0 misleading, must verify Overall Summary count
8. **`Signal.get_connections()` returns untyped `Array`** — cannot assign to `Array[Dictionary]`; declare untyped outer or use `.assign()`
9. **`%` operator binds to immediate left operand** — `"a" + "b" % args` parses as `"a" + ("b" % args)`; multi-line concats need explicit parens before `%`

Session gotcha total: 9 (6 from stories 002-006, 3 from this story).

**Design decisions codified** (for downstream integration tests):
- Programmatic scene construction (not `.tscn` fixture files) — easier to diff, no fixture drift
- `_spawned: Array[Node]` cleanup pattern with `free()` (synchronous) in `after_test`
- Real `/root/GameBus` (not stub) for integration-level V-4 verification
- `await get_tree().process_frame` × 2 for deferred-handler + call_deferred-free sequence; × 1 otherwise
- `Signal.get_connections()` API preferred over `Object.get_signal_connection_list(name)`
- Mock `class_name` is free when real implementation hasn't landed; will coexist with `Mock*` prefix when real lands

**Advisory items logged as tech debt**:
- **TD-015** — Mock-vs-real `_consumed_once` semantic drift risk. MockScenarioRunner uses flat boolean; real ScenarioRunner per TR-scenario-progression-003 will use IN_BATTLE state machine. Divergence on re-entry scenarios means Story 007 AC-4 proves a property the real implementation may not preserve after state resets. Mitigation deferred to Scenario Progression epic's ScenarioRunner implementation story.

**Advisory items resolved in-situ during Option C** (not logged):
- All 6 engine-specialist SUGGESTIONs (S-1 through S-6 applied)
- qa-tester ADVISORY Gap 1 (null-payload untested) → new `test_cross_scene_emit_null_payload_is_guarded` covers it
- qa-tester ADVISORY Gap 2 (AC-8 orphan leak on mid-iteration failure) → documented in AC-8 comment with trade-off rationale
- AC-3 Resource-refcount false-path deferred to manual verification (Godot engine semantic, not code gap — docstring explains the distinction)

**Gates skipped** (review-mode=lean): QL-TEST-COVERAGE, LP-CODE-REVIEW phase-gates. Standalone `/code-review` ran with 2 specialists.
