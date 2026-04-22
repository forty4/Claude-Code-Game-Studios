# Story 001: SceneManager autoload + 5-state FSM skeleton

> **Epic**: scene-manager
> **Status**: Ready
> **Layer**: Platform
> **Type**: Logic
> **Manifest Version**: 2026-04-20

## Context

**GDD**: — (infrastructure; authoritative spec is ADR-0002)
**Requirement**: `TR-scene-manager-001`

**ADR Governing Implementation**: ADR-0002 — §Key Interfaces (autoload declaration) + §State Machine
**ADR Decision Summary**: "SceneManager is a single autoload at `/root/SceneManager` (load order 2, after GameBus) with a 5-state FSM: IDLE, LOADING_BATTLE, IN_BATTLE, RETURNING_FROM_BATTLE, ERROR. Signal-driven — no public imperative transition API."

**Engine**: Godot 4.6 | **Risk**: LOW (this story is skeleton only; handler logic deferred to stories 003-006)
**Engine Notes**: Autoload name-vs-class_name collision gotcha (see `.claude/rules/godot-4x-gotchas.md` G-3) — `extends Node` with NO `class_name` since `SceneManager` is the autoload identifier. `scene_transition_failed` signal is ALREADY declared on GameBus as of story-002 commit (no ADR-0001 amendment needed in this PR).

**Control Manifest Rules (Platform layer)**:
- Required: SceneManager autoload at `/root/SceneManager`, load order 2 (after GameBus)
- Required: 5-state FSM with typed state enum; read-only `state` accessor (writes push_error)
- Required: `_ready` connects GameBus handlers via CONNECT_DEFERRED; `_exit_tree` disconnects with `is_connected` guard
- Forbidden: gameplay state on SceneManager (pure transition lifecycle)
- Forbidden: per-frame emits (no emits from `_process` / `_physics_process`)

## Acceptance Criteria

*Derived from ADR-0002 §Key Interfaces + §Validation Criteria V-1, V-2:*

- [ ] `src/core/scene_manager.gd` exists: `extends Node` (NO `class_name`), matching autoload discipline
- [ ] Script declares `enum State { IDLE, LOADING_BATTLE, IN_BATTLE, RETURNING_FROM_BATTLE, ERROR }` exactly
- [ ] `var state: State` read-only accessor (getter returns `_state`, setter pushes error)
- [ ] `var loading_progress: float = 0.0` readable property (populated by later stories)
- [ ] `_ready()` connects to `GameBus.battle_launch_requested` and `GameBus.battle_outcome_resolved` via CONNECT_DEFERRED; creates private `_load_timer: Timer` child (wait_time 0.1, one_shot false, autostart false, connects timeout → `_on_load_tick`)
- [ ] `_exit_tree()` disconnects both signals guarded by `is_connected`
- [ ] Handler stubs exist: `_on_battle_launch_requested(payload: BattlePayload)`, `_on_battle_outcome_resolved(outcome: BattleOutcome)`, `_on_load_tick()` — all with `pass` body + TODO comment citing the story that implements it
- [ ] `project.godot` [autoload] section adds `SceneManager="*res://src/core/scene_manager.gd"` as SECOND entry after `GameBus`, preserves ORDER-SENSITIVE comment
- [ ] Initial `state == State.IDLE` after `_ready`
- [ ] Godot `--import` succeeds (no parse errors, no autoload collision)

## Implementation Notes

*From ADR-0002 §Key Interfaces:*

1. **Autoload identity**: autoload name `SceneManager` is THE global identifier. Script must NOT declare `class_name SceneManager` (would cause "Class hides autoload singleton" parse error — G-3). Same discipline as `game_bus.gd`.

2. **State accessor read-only contract** (ADR-0002 §Key Interfaces):
   ```gdscript
   var state: State = State.IDLE:
       get: return _state
       set(_v): push_error("SceneManager.state is read-only; state transitions via signal handlers")
   ```

3. **Timer setup in _ready** — 100 ms cadence (ADR-0001 §7 no-per-frame compliance; ADR-0002 §Decision "Timer-based polling at 100 ms"). Timer is a `Node` child of SceneManager; `add_child(_load_timer)` in `_ready`.

4. **Handler stubs deliberate** — this story ships the skeleton. Body implementations land in:
   - `_on_battle_launch_requested` → story 004
   - `_on_battle_outcome_resolved` → story 005
   - `_on_load_tick` → story 004
   - `_pause_overworld` / `_restore_overworld` → story 003
   - `_instantiate_and_enter_battle` → story 004
   - `_free_battle_scene_and_restore_overworld` → story 005
   - `_transition_to_error` → story 006

   Each stub has a `# TODO story-NNN:` comment linking to its target story.

5. **project.godot order-sensitive comment** — preserve the existing gamebus comment block; add SceneManager as the second entry:
   ```ini
   [autoload]

   ; ORDER-SENSITIVE: GameBus must be first — all other autoloads may reference it in _ready
   GameBus="*res://src/core/game_bus.gd"
   SceneManager="*res://src/core/scene_manager.gd"
   ```

6. **Signal declaration confirmation** — `scene_transition_failed(context: String, reason: String)` already exists on GameBus as of story-002. Verify via `grep "scene_transition_failed" src/core/game_bus.gd` — no amendment needed in this PR.

## Out of Scope

- Stub for tests — story 002
- Overworld pause/restore implementation — story 003
- Async load handlers + Timer polling logic — story 004
- Teardown + call_deferred — story 005
- Error recovery logic — story 006
- Android target-device verification — story 007

## QA Test Cases

*Test file*: `tests/unit/core/scene_manager_test.gd`

- **AC-1** (script loads cleanly):
  - Given: SceneManager registered as autoload
  - When: `godot --headless --import`
  - Then: exit 0, no parse errors, no "Class hides autoload singleton" error

- **AC-2** (initial state):
  - Given: autoload mounted
  - When: read `SceneManager.state` immediately after `_ready`
  - Then: returns `SceneManager.State.IDLE`

- **AC-3** (State enum contract):
  - Given: script loaded
  - When: compare enum values
  - Then: `IDLE == 0`, `LOADING_BATTLE == 1`, `IN_BATTLE == 2`, `RETURNING_FROM_BATTLE == 3`, `ERROR == 4` (append-only ordering — same discipline as BattleOutcome.Result per TR-save-load-005)

- **AC-4** (read-only state):
  - Given: autoload mounted in IDLE
  - When: attempt `SceneManager.state = SceneManager.State.IN_BATTLE`
  - Then: state unchanged + `push_error` fires with "read-only; state transitions via signal handlers" message

- **AC-5** (GameBus subscriptions):
  - Given: autoload mounted
  - When: call `GameBus.battle_launch_requested.is_connected(sm._on_battle_launch_requested)` and `GameBus.battle_outcome_resolved.is_connected(sm._on_battle_outcome_resolved)`
  - Then: both return true

- **AC-6** (disconnect on exit):
  - Given: autoload mounted + subscribed
  - When: manually call `_exit_tree()`
  - Then: both signals have no connection to SceneManager (verified via `get_connections()` per G-8)

- **AC-7** (Timer child exists):
  - Given: autoload mounted
  - When: `SceneManager.get_node_or_null("Timer")` (or whatever name specialist picks)
  - Then: returns a Timer with `wait_time == 0.1`, `one_shot == false`, `autostart == false`

- **AC-8** (project.godot autoload order):
  - Given: `project.godot` parsed
  - When: inspect `[autoload]` section
  - Then: `GameBus` first, `SceneManager` second, ORDER-SENSITIVE comment present

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/core/scene_manager_test.gd` — must exist and pass (BLOCKING gate)
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: None (gamebus epic Complete on main; `scene_transition_failed` signal already declared)
- **Unlocks**: Stories 002-006 (all depend on the skeleton) + Story 007 (target-device verification)
