# Story 004: Async threaded BattleScene loading + progress

> **Epic**: scene-manager
> **Status**: Complete
> **Layer**: Platform
> **Type**: Integration
> **Estimate**: medium (~4-6h) — threaded ResourceLoader API + Timer polling + PackedScene fixture scaffolding + state machine unit tests + real async integration test (happy-path + error). ADR Path Resolution contract straightforward; retry from ERROR state explicitly supported.
> **Manifest Version**: 2026-04-20

## Context

**GDD**: — (infrastructure; authoritative spec is ADR-0002)
**Requirement**: `TR-scene-manager-003`

**ADR Governing Implementation**: ADR-0002 — §Key Interfaces `_on_battle_launch_requested` + §Key Interfaces `_on_load_tick` + §Key Interfaces `_instantiate_and_enter_battle` + §Path Resolution
**ADR Decision Summary**: "BattleScene async via `ResourceLoader.load_threaded_request`. Timer-polled status at 100 ms (NOT per-frame). On LOADED → instantiate as `/root` peer and transition IN_BATTLE. On failure → transition_to_error."

**Engine**: Godot 4.6 | **Risk**: MEDIUM (`ResourceLoader.load_threaded_*` API stable since 4.2; verification required: `load_threaded_get_status(path, progress_array)` out-parameter semantics on Android export — ADR-0002 §Engine Compatibility Verification Required #2)
**Engine Notes**: Android target-device async-load verification is story 007's responsibility; this story covers the code + unit tests (mock ResourceLoader) + local integration test (real PackedScene async load on desktop).

**Control Manifest Rules (Platform layer)**:
- Required: Async load via `ResourceLoader.load_threaded_request`; polling via private Timer node at 100 ms cadence
- Required: `loading_progress: float` property readable by UI WITHOUT bus subscription (per ADR-0001 §5 — UI reads this as property query, not via bus traffic)
- Forbidden: polling in `_process` / `_physics_process` (no per-frame; CI lint enforces via per-frame-emit ban but progress polling also subject to this discipline)
- Guardrail: <0.05 ms/tick × 10 ticks/sec = 0.5 ms/sec overhead during LOADING_BATTLE (negligible)

## Acceptance Criteria

*Derived from ADR-0002 §Key Interfaces + §Validation Criteria V-3, V-4 (partial), V-12:*

- [ ] `_on_battle_launch_requested(payload: BattlePayload)` implemented:
  - `is_instance_valid(payload)` guard + `push_warning` on invalid
  - State guard: ignore if not in `State.IDLE` or `State.ERROR` (push_warning with current state in message; single-battle-at-a-time invariant per ADR-0002 §Risks "Nested battles explicit rejection")
  - Transition `_state = State.LOADING_BATTLE`
  - Capture `_overworld_ref = get_tree().current_scene`
  - Call `_pause_overworld()` (from story 003)
  - Emit `GameBus.ui_input_block_requested.emit("scene_transition")` (ADR-0001-compliant)
  - Resolve `_load_path = _resolve_battle_scene_path(payload.map_id)`
  - Call `ResourceLoader.load_threaded_request(_load_path, "PackedScene", true)` — if err != OK, immediately transition_to_error with `"load_request_failed: %s" % error_string(err)`
  - Start `_load_timer`
- [ ] `_on_load_tick()` implemented (Timer-driven):
  - Early-exit if `_state != State.LOADING_BATTLE` (stop timer + return — defensive against timer races)
  - Call `ResourceLoader.load_threaded_get_status(_load_path, progress)` with `progress: Array = []` out-param
  - If `progress.size() > 0`, update `loading_progress = progress[0]`
  - Match on status: `THREAD_LOAD_LOADED` → stop timer + call `_instantiate_and_enter_battle`; `THREAD_LOAD_INVALID_RESOURCE` or `THREAD_LOAD_FAILED` → stop timer + `_transition_to_error("load_failed: status=%d" % status)`; `THREAD_LOAD_IN_PROGRESS` → pass (continue polling)
- [ ] `_instantiate_and_enter_battle()` implemented:
  - `var packed: PackedScene = ResourceLoader.load_threaded_get(_load_path) as PackedScene`
  - Null guard: if packed == null, transition_to_error
  - `_battle_scene_ref = packed.instantiate()`
  - `get_tree().root.add_child(_battle_scene_ref)` (BattleScene as /root peer — NOT under Overworld)
  - `_state = State.IN_BATTLE`
  - `loading_progress = 1.0`
  - Emit `GameBus.ui_input_unblock_requested.emit("scene_transition")`
- [ ] `_resolve_battle_scene_path(map_id: String) -> String` implemented (ADR §Path Resolution): returns `"res://scenes/battle/%s.tscn" % map_id`
- [ ] `loading_progress: float` property readable externally (test: `SceneManager.loading_progress` is 0.0 in IDLE, populates to [0.0, 1.0] during LOADING_BATTLE, == 1.0 after IN_BATTLE entry, resets via story 005's teardown)
- [ ] Unit tests: mock ResourceLoader-like interface (specialist's choice how to stub — may need a test double since ResourceLoader is a static engine singleton); verify state transitions + emit sequences + error paths
- [ ] Integration test (partial): `tests/integration/core/scene_handoff_timing_test.gd` — create this file; test_ac4_async_load_happy_path loads a MINIMAL test PackedScene fixture (programmatically built .tscn or `PackedScene.pack(Node)` at test time) and verifies the full IDLE → LOADING_BATTLE → IN_BATTLE flow completes within N await frames
- [ ] Transition from `State.ERROR` back to `LOADING_BATTLE` works (retry path — re-emit `battle_launch_requested` while in ERROR is accepted, per ADR-0002 state-machine diagram)

## Implementation Notes

*From ADR-0002 §Key Interfaces verbatim + engine-reference verification:*

1. **Mock ResourceLoader challenge** — `ResourceLoader` is a Godot static singleton, can't be directly mocked. Two test strategies:
   - **Unit test approach**: use a real minimal PackedScene (`PackedScene.new(); packed.pack(Node.new())`) saved to `user://tmp/` during `before_test`, then `load_threaded_request` the real path. Tests real engine behavior + doesn't require mocking.
   - **Integration test approach**: same but assertions focus on the happy-path flow + state sequence rather than specific load timing.
   Mixed is fine — unit test for state machine; integration test for real async load.

2. **`load_threaded_get_status` out-param** — ADR §Engine Compatibility Verification Required #2 flags this. In Godot 4.6, `progress: Array` passed by reference, status code returned. Verify via `docs/engine-reference/godot/` before coding. If the out-param signature differs, the unit test will catch it at author-time.

3. **Timer lifecycle** — `_load_timer` was created in `_ready` (story 001). Here we `.start()` it on load request; `.stop()` on completion (happy or error). Do NOT `free()` the Timer — it's a persistent child node.

4. **State guard on launch** — per ADR-0002 §Risks "Nested battles", `battle_launch_requested` outside `IDLE` or `ERROR` is ignored with push_warning. DO NOT silently queue, DO NOT crash. State machine rejects.

5. **BattleScene as /root peer** — `get_tree().root.add_child(_battle_scene_ref)` — NOT added under Overworld. Per ADR-0002 §Decision "BattleScene fully isolated".

6. **Path convention is hardcoded in `_resolve_battle_scene_path`** — intentional per ADR §Path Resolution. No data-driven override needed (map_id IS the data input); the `res://scenes/battle/%s.tscn` template is a build-time convention.

7. **Empty/missing scene path handling** — if the PackedScene file doesn't exist, `ResourceLoader.load_threaded_request` returns `FAILED` → handled by error path. No explicit file-existence check needed before the call.

8. **GameBusStub for unit tests** — emit `battle_launch_requested` via stub; SceneManager subscribes via its `_ready` which happens at `swap_in` time. Use both `GameBusStub.swap_in()` + `SceneManagerStub.swap_in()` in tests that need full isolation.

9. **Test fixture payload** — create `BattlePayload` with `map_id = "test_ac4_map"` and expect the lint to resolve to `res://scenes/battle/test_ac4_map.tscn`. Create that fixture file in `tests/fixtures/scenes/` (or generate programmatically per gamebus story-007 pattern).

## Out of Scope

- Outcome-driven teardown + `call_deferred` co-subscriber safety — story 005
- Error recovery + retry loop integration test — story 006 (basic error path transition is covered here, but full retry flow is story 006)
- Android target-device `load_threaded_get_status` verification — story 007
- Memory profile during IN_BATTLE — story 007 (V-8)

## QA Test Cases

*Test files*: `tests/unit/core/scene_manager_test.gd` (unit — state machine + mock/fixture load); `tests/integration/core/scene_handoff_timing_test.gd` (integration — real async load)

- **AC-1** (happy-path async load):
  - Given: SceneManagerStub.swap_in(), GameBusStub.swap_in(); test PackedScene fixture at `res://scenes/battle/test_ac4_map.tscn` (or user:// path)
  - When: emit `GameBus.battle_launch_requested` with `BattlePayload(map_id="test_ac4_map")`; await process_frame; run Timer ticks until status == LOADED
  - Then: state sequence = IDLE → LOADING_BATTLE → IN_BATTLE; `loading_progress` populated to [0.0, 1.0] during LOADING; `loading_progress == 1.0` in IN_BATTLE; `_battle_scene_ref != null`
  - Edge: `ui_input_block_requested.emit("scene_transition")` fires before IN_BATTLE; `ui_input_unblock_requested.emit("scene_transition")` fires after IN_BATTLE

- **AC-2** (state guard rejects duplicate launches):
  - Given: already in LOADING_BATTLE
  - When: emit `battle_launch_requested` again
  - Then: state unchanged; `push_warning` fires with "already transitioning (state=LOADING_BATTLE)"; `loading_progress` unchanged

- **AC-3** (load_threaded_request err != OK → ERROR):
  - Given: map_id that resolves to a path with invalid resource type (test fixture or force-invalid)
  - When: launch request processed
  - Then: state → ERROR; `_transition_to_error("load_request_failed: %s" %...)` fires (story 006 implements the emit; this story just calls it)

- **AC-4** (load_threaded_get_status FAILED → ERROR):
  - Given: load in progress, then simulate FAILED status
  - When: `_on_load_tick()` fires
  - Then: timer stopped; state → ERROR; `_transition_to_error("load_failed: status=...")` called

- **AC-5** (loading_progress property readable without bus):
  - Given: state == LOADING_BATTLE with progress 0.5
  - When: external caller reads `SceneManager.loading_progress`
  - Then: returns 0.5 (no bus subscription required)

- **AC-6** (Timer polling, not per-frame):
  - Given: CI lint-per-frame-emit ban (gamebus story-008) already installed
  - When: lint runs on `scene_manager.gd`
  - Then: zero violations (no GameBus emits inside `_process` or `_physics_process`)

- **AC-7** (retry from ERROR):
  - Given: state == ERROR
  - When: emit `battle_launch_requested` with valid payload
  - Then: state → LOADING_BATTLE (retry accepted)

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/core/scene_manager_test.gd` (unit tests added) + `tests/integration/core/scene_handoff_timing_test.gd` (happy-path integration) — both must exist and pass (BLOCKING gate)
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: Story 001 (skeleton), Story 002 (stub for isolation), Story 003 (`_pause_overworld` called during LOADING_BATTLE entry)
- **Unlocks**: Story 005 (teardown needs IN_BATTLE to be reachable); Story 006 (error path uses `_transition_to_error` which this story calls but doesn't implement)

## Completion Notes

**Completed**: 2026-04-22
**Criteria**: 7/7 passing
**Test Evidence**: `tests/unit/core/scene_manager_test.gd` (6 new tests: AC-2, AC-3 unit, AC-4, AC-5, AC-7, path helper) + `tests/integration/core/scene_handoff_timing_test.gd` (2 new tests: AC-1 happy path, AC-3 e2e). AC-6 enforced by CI lint (story-008). Full suite 87/87, 0 orphans, exit 0.
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (/code-review 2026-04-22, lean). All 6 advisory findings (F-1..F-4 + T-1..T-3) batched into TD-018 for future cleanup sweep.
**Deviations**: None blocking.
- **OUT OF SCOPE (justified)**: `.claude/rules/godot-4x-gotchas.md` — new G-10 entry codifying the autoload-identifier-binding discovery (prevents regression across all future stories using GameBus subscriptions). Also touched `docs/tech-debt-register.md` with TD-018 + TD-019.
- **Test isolation fix (documented in G-10)**: GameBusStub removed from 4 handler-firing tests because GDScript autoload identifiers bind at engine registration, NOT dynamically to /root/Name. Tests now emit on real GameBus autoload. AC-2 guard test hardened to observe `ui_input_block_requested` NOT firing (secondary side effect) — the previous "state unchanged" assertion was a false positive.
**Manifest Version compliance**: 2026-04-20 matches current control-manifest.

**Key findings this cycle**:
- **G-10 autoload identifier binding** — discovered empirically via 3 failing tests. Codified in gotchas file + TD-019. Pre-emptive audit of gamebus story-005/006/007 tests recommended during story-005 to flag false-positive patterns.
- **Dual AC-3 coverage** (unit + integration) — good pattern for future async-behavior stories.
- **ResourceLoader fixture strategy** — static `.tscn` checked in at `scenes/battle/test_ac4_map.tscn` (with README-test-fixtures.md export-exclusion note) chosen over programmatic `user://` generation. Simpler, works with `load_threaded_request` which requires `res://` paths.

**Files changed**:
- `src/core/scene_manager.gd` — 2 TODO stubs replaced (`_on_battle_launch_requested`, `_on_load_tick`) + 3 new helpers appended (`_instantiate_and_enter_battle`, `_resolve_battle_scene_path`, `_transition_to_error`). `_on_battle_outcome_resolved` stub preserved for story-005.
- `tests/unit/core/scene_manager_test.gd` — 6 new test functions in `# ── Story 004` section (line 545+)
- `tests/integration/core/scene_handoff_timing_test.gd` — NEW file, 2 integration tests with `AUTOLOAD BINDING — CRITICAL` header documenting G-10
- `scenes/battle/test_ac4_map.tscn` — NEW minimal Node2D test fixture (with `;` prefix comment marking test-only status)
- `scenes/battle/README-test-fixtures.md` — NEW export-exclusion guidance
- `.claude/rules/godot-4x-gotchas.md` — G-10 appended
- `docs/tech-debt-register.md` — TD-018 (6 batched polish items) + TD-019 (G-10 discovery)

**Implementation notes for future stories**:
- Story-005 (outcome teardown): `_on_battle_outcome_resolved` stub is preserved; consumes `_battle_scene_ref` (set by `_instantiate_and_enter_battle`), calls `_restore_overworld` (story-003), uses `call_deferred` per ADR §Risks "co-subscriber-safe free"
- Story-006 (error recovery): extends `_transition_to_error` to emit `GameBus.scene_transition_failed` + restore Overworld. F-3 nit (defensive `_load_timer.stop()`) should be addressed there.
- **G-10 audit required** in story-005: scan any tests in gamebus epic that use `GameBusStub.swap_in()` together with subscriber-receives-emit patterns. Flag false positives.
