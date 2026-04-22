# Story 002: SceneManager stub for GdUnit4 test isolation

> **Epic**: scene-manager
> **Status**: Complete
> **Layer**: Platform
> **Type**: Integration
> **Estimate**: small (~2-3h) — pattern copy of gamebus story-006; G-6 orphan hardening + `free()`/`queue_free()` discipline already internalized from precedent
> **Manifest Version**: 2026-04-20

## Context

**GDD**: — (infrastructure; test-infra contract per ADR-0002)
**Requirement**: `TR-scene-manager-001` (via V-10 validation criterion)

**ADR Governing Implementation**: ADR-0002 — §Validation Criteria V-10
**ADR Decision Summary**: "SceneManager stub injectable via `before_test`/`after_test` matching GameBus stub pattern. Tests can isolate SceneManager state without affecting production `/root/SceneManager`."

**Engine**: Godot 4.6 | **Risk**: LOW (autoload tree manipulation — stable pre-cutoff APIs; pattern already established by GameBusStub in gamebus story-006)
**Engine Notes**: Parallel pattern to `tests/unit/core/game_bus_stub.gd`. Same hardening lessons apply: `Engine.get_main_loop().root` + SceneTree cast + null guard; `is_instance_valid()` guards before dereferencing cached Node; `free()` (not `queue_free()`) on test-owned Nodes; explicit `swap_out()` at end of test body (not relying on `after_test`) to prevent GdUnit4 orphan detection. See `.claude/rules/godot-4x-gotchas.md` G-6.

**Control Manifest Rules (Platform layer)**:
- Required: SceneManager stub injectable via `before_test`/`after_test` in GdUnit4 — documented pattern
- Required: Stub inherits same script as production (no duplicate enum/FSM declarations)
- Required: No test depends on execution order (isolation discipline)
- Forbidden: Tests modifying production autoload state without cleanup

## Acceptance Criteria

*Derived from ADR-0002 §Validation Criteria V-10 + gamebus story-006 pattern:*

- [ ] `tests/unit/core/scene_manager_stub.gd` — helper module with `class_name SceneManagerStub extends RefCounted`, static `swap_in()` / `swap_out()` methods
- [ ] `swap_in()`: detach production `/root/SceneManager` via `root.remove_child()`, cache in `_cached_production: Node` static var; instantiate fresh stub via `(load(SCENE_MANAGER_PATH) as GDScript).new()`; name `"SceneManager"`; `add_child` under root; cache in `_active_stub: Node` static var; return stub
- [ ] `swap_out()`: idempotent — safe to call from `after_test` even if `swap_in` was never called or a prior `swap_out` already ran; uses `is_instance_valid()` guards before dereferencing cached nodes
- [ ] Root access via `_get_root()` helper: `Engine.get_main_loop() as SceneTree` + null guard + `push_warning` on non-SceneTree MainLoop
- [ ] `free()` (not `queue_free()`) for immediate synchronous stub deletion (avoids orphan detection)
- [ ] `tests/unit/core/scene_manager_stub_self_test.gd` — 7 self-tests matching `game_bus_stub_self_test` structure:
  - AC-1 swap_in replaces production at /root/SceneManager
  - AC-2 swap_out restores production + `is_instance_valid(stub) == false`
  - AC-3 idempotent swap_out (double-call safe)
  - AC-3 edge: swap_out without prior swap_in is safe
  - AC-4 state isolation (fresh stub starts in IDLE, independent of production state)
  - AC-5 no orphaned nodes across 5 cycles
  - AC-7 coexists with GameBusDiagnostics (if running)
- [ ] Explicit `swap_out()` at end of every self-test body (not relying on `after_test`) — prevents GdUnit4 orphan-detector flagging the detached production node (G-6)
- [ ] Both `before_test` and `after_test` call `SceneManagerStub.swap_out()` as paranoia guard

## Implementation Notes

*From ADR-0002 §Validation Criteria V-10 + `tests/unit/core/game_bus_stub.gd` as reference:*

1. **Pattern copy** — `tests/unit/core/game_bus_stub.gd` is the template. Stub script structure:
   ```gdscript
   class_name SceneManagerStub
   extends RefCounted

   const SCENE_MANAGER_PATH: String = "res://src/core/scene_manager.gd"

   static var _cached_production: Node = null
   static var _active_stub: Node = null

   static func swap_in() -> Node: ...
   static func swap_out() -> void: ...
   static func _get_root() -> Node: ...
   ```

2. **Key differences from GameBusStub**:
   - Path: `res://src/core/scene_manager.gd` (not `game_bus.gd`)
   - Autoload name: `SceneManager` (not `GameBus`)
   - Stub inherits the full 5-state FSM from the production script — fresh instance means fresh `_state = State.IDLE`, fresh `_overworld_ref = null`, etc.
   - Timer child: stub's `_ready` will create its own private Timer (same as production) — tests that need to control Timer behavior should inject their own via the `_load_timer` property after `swap_in`

3. **State isolation guarantee** — AC-4: fresh stub MUST start in `State.IDLE` even if production was mid-transition. This is the primary test-isolation property SceneManager users rely on.

4. **Coexistence with GameBusDiagnostics (AC-7)** — if GameBusDiagnostics is active (debug build), its counter will see stub's signal emissions (if any), but stub's signal subscriptions are fresh. Same disclaimer as gamebus story-006 README: diagnostic warning capture via stub is not guaranteed.

5. **GameBus stub compatibility** — tests MAY use both `GameBusStub.swap_in()` AND `SceneManagerStub.swap_in()` in the same test for full autoload isolation. Order doesn't matter (independent autoloads). Both stubs use their own `_active_stub` static var.

6. **README update** — append a `## SceneManagerStub` section to `tests/unit/core/README.md` documenting usage pattern, matching GameBusStub section structure. Cross-reference from both sections to `.claude/rules/godot-4x-gotchas.md`.

## Out of Scope

- Multi-signal test orchestration framework (out of scope per gamebus story-006)
- Production SceneManager replacement at runtime (TEST-ONLY utility)
- Stub that auto-fires state transitions (tests manually manipulate state for determinism)

## QA Test Cases

*Test file*: `tests/unit/core/scene_manager_stub_self_test.gd`

- **AC-1** (swap_in replaces production):
  - Given: production SceneManager autoload mounted at `/root/SceneManager`
  - When: `var stub = SceneManagerStub.swap_in()`
  - Then: `get_tree().root.get_node("SceneManager") == stub`; production cached internally; stub's `get_script() == preload(SCENE_MANAGER_PATH)`
  - Edge: stub's `state == State.IDLE` regardless of production's previous state

- **AC-2** (swap_out restores production):
  - Given: stub active (after swap_in)
  - When: `SceneManagerStub.swap_out()`
  - Then: `/root/SceneManager` is production again; `is_instance_valid(stub) == false`

- **AC-3a** (idempotent swap_out):
  - Given: swap_in + swap_out called
  - When: swap_out called again
  - Then: no error; production still mounted; no double-free warning

- **AC-3b** (swap_out with no prior swap_in):
  - Given: fresh test, before_test paranoia swap_out
  - When: swap_out called again
  - Then: no error; production unchanged

- **AC-4** (state isolation):
  - Given: stub swapped in
  - When: read `stub.state`
  - Then: `== State.IDLE` (fresh instance)
  - Edge: mutating stub via test does NOT affect production (verified by reading production after swap_out)

- **AC-5** (5-cycle no-orphans):
  - Given: repeat swap_in/swap_out 5 times
  - When: check `/root/*` after each cycle
  - Then: exactly one node named "SceneManager"; no "SceneManager_production", no duplicates

- **AC-7** (coexists with GameBusDiagnostics):
  - Given: GameBusDiagnostics active (debug build)
  - When: swap_in → emit some GameBus signals → swap_out
  - Then: no crash; production SceneManager restored; GameBusDiagnostics still functional

## Test Evidence

**Story Type**: Integration
**Required evidence**: `tests/unit/core/scene_manager_stub.gd` + `tests/unit/core/scene_manager_stub_self_test.gd` + README section — all must exist; self-tests pass
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: Story 001 (SceneManager autoload must exist to be swappable)
- **Unlocks**: Stories 003-006 unit tests (can use `SceneManagerStub.swap_in()` for isolation)

## Completion Notes

**Completed**: 2026-04-22
**Criteria**: 8/8 passing, all 7 pre-specified QA Test Cases mapped to test functions
**Test Evidence**: `tests/unit/core/scene_manager_stub.gd` + `tests/unit/core/scene_manager_stub_self_test.gd` (7 tests pass) + `tests/unit/core/README.md` (`## SceneManagerStub` section appended). Full unit suite 64/64, 0 orphans, 0 regressions.
**Deviations**: None blocking. Advisory (matches GameBusStub precedent): 3 defensive-branch paths untested — production-missing-at-swap_in (swap_in:108), cached-production-freed-externally (swap_out:160-161, 178-179), foreign-node-at-root (swap_out:169-170). Not required by story ACs.
**Code Review**: Complete (/code-review 2026-04-22 — APPROVED after F-1 `_cached_production` direct-assert + F-2 `GameBus.round_started.emit` during swap window added to AC-1 and AC-7 tests).
**Manifest Version compliance**: 2026-04-20 matches current control-manifest (no staleness).
**Pattern parity**: Faithful copy of `game_bus_stub.gd` (gamebus story-006) with domain-appropriate divergences — state-isolation replaces signal-isolation in AC-4; AC-7 drops `_emits_this_frame` assertion (SceneManager stub doesn't emit on GameBus); Timer child inherited from production script.
**Files changed**:
- `tests/unit/core/scene_manager_stub.gd` (new, 181 lines — static swap_in/swap_out RefCounted helper)
- `tests/unit/core/scene_manager_stub_self_test.gd` (new, 386 lines, 7 test functions after F-1/F-2 fixes)
- `tests/unit/core/README.md` (+135 lines — `## SceneManagerStub` section appended after `## GameBusStub`)
