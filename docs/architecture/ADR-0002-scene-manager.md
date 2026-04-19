# ADR-0002: Scene Manager Autoload — Overworld ↔ Battle Scene Orchestration

## Status

Accepted (2026-04-18)

## Date

2026-04-18

## Last Verified

2026-04-18

## Decision Makers

- Technical Director (architecture owner)
- User (final approval, 2026-04-18)
- godot-specialist (engine validation, 2026-04-18)
- Referenced by Scenario Progression GDD v2.0 (UI-7 provisional contract) as the pattern to ratify

## Summary

천명역전 (Defying Destiny) runs two long-lived scene contexts — the Overworld
scene (holding ScenarioRunner and the 8-beat ceremony rhythm) and the
BattleScene (instanced per chapter for the grid tactical combat). ScenarioRunner
must survive across battles; BattleScene must be freed on CLEANUP. This ADR
ratifies a dedicated autoload at `/root/SceneManager` that owns the full
transition lifecycle: async loading, Overworld pause+hide, BattleScene
instantiation as a `/root` peer, outcome-driven teardown, and error recovery.
Transitions are entirely signal-driven via the GameBus relay ratified in
ADR-0001, with one minor amendment to ADR-0001 to declare a new
`scene_transition_failed` signal.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scene Management |
| **Knowledge Risk** | MEDIUM — `ResourceLoader.load_threaded_*` API stable since 4.2; `PROCESS_MODE_DISABLED` semantics stable since 4.0; recursive Control disable is a 4.5+ feature with API name to verify before implementation |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md` (lines 38, 43, 67 — SceneTree, Recursive Control, TileMapLayer), `docs/engine-reference/godot/deprecated-apis.md` (line 26 — `PackedScene.instance()` → `instantiate()`), `docs/engine-reference/godot/modules/ui.md` §Recursive Disable, `docs/engine-reference/godot/current-best-practices.md` §Accessibility |
| **Post-Cutoff APIs Used** | `PROCESS_MODE_DISABLED` semantics (stable since 4.0 — no post-cutoff risk); Recursive Control disable (4.5+ — **verification required**: exact property for propagation is not fully specified in engine-reference §Recursive Disable, must be confirmed against Godot 4.6 API before coding); `ResourceLoader.load_threaded_request` signature unchanged in 4.4/4.5/4.6 per godot-specialist verification |
| **Verification Required** | (1) Confirm exact recursive-disable property name in Godot 4.6 (`mouse_filter` inheritance behavior on Control trees). (2) Confirm `ResourceLoader.load_threaded_get_status(path, progress_array)` out-parameter semantics on Android export. (3) Confirm `CONNECT_DEFERRED` ordering between SceneManager and ScenarioRunner handlers in frame N+1 with `call_deferred("_free_battle_scene")` pushing free to frame N+2. (4) Memory profile on Snapdragon 7-gen: peak combined Overworld + BattleScene under 250 MB resident. |

> **Note**: Knowledge Risk is MEDIUM. Re-validate this ADR if upgrading past Godot 4.6.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (Accepted 2026-04-18) — this ADR consumes `battle_launch_requested`, `battle_outcome_resolved`, and emits `ui_input_block_requested` / `ui_input_unblock_requested` on the GameBus relay established there. |
| **Enables** | Scenario Progression implementation (#6 MVP — UI-7 contract now ratified); Save/Load implementation (#17 VS — scene-boundary checkpoint timing); Battle Preparation UI (#19 Alpha — scene integration point). |
| **Blocks** | Scenario Progression v2.1 revision UI-7 contract lock; Grid Battle implementation (requires SceneManager to know where BattleScene lives in the tree before coding `_ready`). |
| **Ordering Note** | Must be Accepted before any MVP gameplay scene-transition code is written. Scenario Progression implementation cannot begin without this ADR. Minor amendment to ADR-0001 (new `scene_transition_failed` signal) must land alongside this ADR. |

## Context

### Problem Statement

Scenario Progression GDD v2.0 commits to a 9-beat ceremony per chapter. Beats
1–4 and 6–9 run in the Overworld scene under ScenarioRunner's state machine.
Beat 5 — the grid tactical battle — runs in a separate BattleScene
instantiated from a PackedScene. On battle conclusion, control returns to
ScenarioRunner at Beat 6 (OUTCOME) with the `BattleOutcome` payload in hand.

The GDD's UI-7 section marks the ScenarioRunner ↔ BattleScene scope handoff
as a **provisional contract** pending this ADR. Without a ratified pattern,
three concrete failure modes are imminent:

1. **Scene-boundary authority confusion** — Overworld could instantiate
   BattleScene as its child (coupling lifecycles), or SceneTree could
   `change_scene_to_packed` (destructive, loses ScenarioRunner state), or
   each feature branch could invent its own approach (producing inconsistent
   scene trees across MVP features).

2. **Async-load timing hazards** — battle scenes include terrain tilemaps,
   unit sprite atlases, VFX materials; synchronous `instantiate()` on
   mid-range Android causes frame-time spikes >500 ms observed in similar
   Godot tactical projects. A stated load strategy is required.

3. **Deferred-handler race conditions** — both ScenarioRunner and
   SceneManager must react to the same `battle_outcome_resolved` signal via
   GameBus. If SceneManager frees the BattleScene in its deferred handler
   before ScenarioRunner's deferred handler completes, ScenarioRunner may
   dereference freed nodes. ADR-0001 primitive-only-payload rule protects
   the outcome data itself but does not protect against handler-ordering
   races on the scene root.

The cost of not deciding: Scenario Progression cannot complete its v2.1
revision (UI-7 is blocking), Grid Battle cannot finalize its scene topology
(§CLEANUP cannot specify where/how teardown happens), and Save/Load cannot
place the CP-2 checkpoint boundary (which requires scene-transition timing
to be defined).

### Current State

No SceneManager exists. ADR-0001 declares `ui_input_block_requested` /
`ui_input_unblock_requested` with "emitter: UIRoot, SceneManager" as a
future expectation — this ADR fulfills that expectation. No code in
`src/core/` references scene transitions yet (pre-implementation).

### Constraints

- **Engine**: Godot 4.6, GDScript only (no GDExtension for core).
- **Platform**: Mobile-primary (iOS/Android). 512 MB ceiling, 60 fps /
  16.6 ms frame budget. Load-time hitches above 100 ms visible to player.
- **Signal contract**: Must use GameBus per ADR-0001. No direct node
  references across scene boundaries. `CONNECT_DEFERRED` mandatory.
- **Testing**: GdUnit4. SceneManager stub must be injectable the same way
  GameBus stub is (swap in `before_test`, restore in `after_test`).
- **Coding standards**: All public APIs doc-commented; no hardcoded
  gameplay values; dependency injection over singletons.
- **Pillar alignment**: Scenario Progression pillar decisions (retained
  Overworld state during battle lets Beat 2 Prior-State Echo carry forward
  across retries; Echo retry loop is LOSS → BATTLE_PREP, implying Overworld
  stays alive through multiple retries in one run).

### Requirements

1. **ScenarioRunner survives battle** — Overworld scene and ScenarioRunner
   node tree must be retained across the full battle lifecycle so Beat 6
   (OUTCOME) continues from Beat 5's exact state.
2. **BattleScene fully isolated** — BattleScene is instanced per chapter,
   freed on CLEANUP. No shared state leaks into the next chapter.
3. **Async load** — BattleScene loads on a background thread so the player
   sees a responsive UI (spinner, progress bar) during load, not a frozen
   frame.
4. **Signal-driven** — transitions triggered only by GameBus signals
   (`battle_launch_requested`, `battle_outcome_resolved`). No public
   imperative methods on SceneManager for transitions — enforces testability.
5. **ADR-0001-compliant** — zero emits from `_process` / `_physics_process`.
   All lifecycle emits come from discrete handlers.
6. **Error recovery** — load failure must not soft-lock the game. Fallback
   to Overworld + surface error to ScenarioRunner for player-visible retry
   or abort.
7. **Memory ceiling** — peak combined Overworld + BattleScene resident
   under 250 MB on mid-range Android.
8. **Frame-budget compliance** — SceneManager itself <0.1 ms/frame when
   IDLE; poll overhead during LOADING amortized via Timer (not per-frame).

## Decision

We adopt a single Godot autoload singleton at `/root/SceneManager` as the
sole owner of Overworld ↔ BattleScene transitions. SceneManager is
signal-driven (no public imperative API for transitions), uses
`ResourceLoader.load_threaded_request` for async BattleScene loading, and
retains the Overworld in a paused+hidden state during IN_BATTLE to
preserve ScenarioRunner state. SceneManager also requires one minor
amendment to ADR-0001 to declare a new `scene_transition_failed` signal
for error propagation.

### Architecture

```
                    /root (SceneTree root)
                      │
    ┌─────────────────┼─────────────────┐──────────────────┐
    │                 │                 │                  │
┌───▼────┐     ┌──────▼──────┐   ┌──────▼──────┐    ┌──────▼──────┐
│GameBus │     │SceneManager │   │  Overworld  │    │ BattleScene │
│(auto-  │     │  (auto-     │   │  (current   │    │  (present   │
│ load 1)│     │   load 2)   │   │   scene,    │    │   only during│
│        │     │             │   │   retained  │    │   IN_BATTLE)│
│ signals│◀───▶│  state      │   │   during    │    │             │
│  relay │     │  machine    │   │   battle)   │    │             │
└────────┘     └─────────────┘   └─────────────┘    └─────────────┘
                      │                 │                  │
                      │  connects       │  ScenarioRunner  │  BattleController
                      │  (DEFERRED) to  │  is a child node │  is a child node
                      │  GameBus        │                  │
                      │                 │                  │
                      │ spawn/free ─────┼──────────────────┘
                      │  lifecycle      │
                      ▼                 │
               ResourceLoader           │
               (threaded load)          │
                                        │
                          Overworld:    │
                            visible = false (when LOADING_BATTLE / IN_BATTLE)
                            process_mode = PROCESS_MODE_DISABLED
                            set_process_input(false)
                            root Control mouse_filter = MOUSE_FILTER_IGNORE
```

### State Machine

```
    ┌─────────────────────────────────────────────────────┐
    │                                                     │
    ▼                                                     │
  ┌──────┐  battle_launch_requested   ┌───────────────┐   │
  │ IDLE ├──────────────────────────▶│LOADING_BATTLE │   │
  └──────┘  (subscribe handler)       └──────┬────────┘   │
    ▲                                        │            │
    │                                        │ load       │
    │                                        │ complete   │
    │ battle_scene freed                     ▼            │
    │ + overworld restored                ┌───────────┐   │
  ┌──────────────────────┐                │ IN_BATTLE │   │
  │RETURNING_FROM_BATTLE │◀───────────────┤           │   │
  └──────────┬───────────┘ battle_outcome └───────────┘   │
             │             _resolved                      │
             │             (subscribe handler)            │
             │                                            │
             │ load failed: scene_transition_failed       │
             │              ┌───────┐                     │
             │              │ ERROR ├─────────────────────┘
             └─────────────▶│       │ retry: battle_launch_requested re-emit
                            └───────┘
```

States: **IDLE**, **LOADING_BATTLE**, **IN_BATTLE**, **RETURNING_FROM_BATTLE**,
**ERROR** (5 states).

### Key Interfaces

**Autoload declaration** (`src/core/scene_manager.gd`):

```gdscript
## SceneManager — the single owner of Overworld ↔ BattleScene transitions.
##
## Ratified by ADR-0002. Consumes GameBus signals per ADR-0001.
##
## RULES:
##  - SceneManager owns scene-transition lifecycle ONLY. It does not hold
##    gameplay state.
##  - All transitions are signal-driven. There are no public imperative
##    transition methods; callers emit on GameBus and SceneManager reacts.
##  - Overworld is retained (paused + hidden) during battle, NOT freed.
##  - BattleScene is freed via call_deferred to ensure co-subscriber
##    deferred handlers complete before freeing.
##
## See ADR-0002 §Decision for state machine and topology.
class_name SceneManager
extends Node

enum State {
    IDLE,
    LOADING_BATTLE,
    IN_BATTLE,
    RETURNING_FROM_BATTLE,
    ERROR,
}

## Read-only state accessor. Changes via internal signal handlers only.
var state: State = State.IDLE:
    get: return _state
    set(_v): push_error("SceneManager.state is read-only; state transitions via signal handlers")

## Read-only async-load progress [0.0, 1.0]. Valid only while state == LOADING_BATTLE.
## Per ADR-0001 §5, UI reads this as a property query — NOT via bus traffic.
var loading_progress: float = 0.0

var _state: State = State.IDLE
var _overworld_ref: Node = null
var _battle_scene_ref: Node = null
var _load_path: String = ""
var _load_timer: Timer = null

func _ready() -> void:
    GameBus.battle_launch_requested.connect(_on_battle_launch_requested, CONNECT_DEFERRED)
    GameBus.battle_outcome_resolved.connect(_on_battle_outcome_resolved, CONNECT_DEFERRED)
    _load_timer = Timer.new()
    _load_timer.wait_time = 0.1   # 100 ms poll — compliant with ADR-0001 §7 (no per-frame)
    _load_timer.one_shot = false
    _load_timer.autostart = false
    _load_timer.timeout.connect(_on_load_tick)
    add_child(_load_timer)

func _exit_tree() -> void:
    if GameBus.battle_launch_requested.is_connected(_on_battle_launch_requested):
        GameBus.battle_launch_requested.disconnect(_on_battle_launch_requested)
    if GameBus.battle_outcome_resolved.is_connected(_on_battle_outcome_resolved):
        GameBus.battle_outcome_resolved.disconnect(_on_battle_outcome_resolved)
```

**Transition to battle** (entry from IDLE, LOADING_BATTLE, or ERROR-retry):

```gdscript
func _on_battle_launch_requested(payload: BattlePayload) -> void:
    if not is_instance_valid(payload):
        push_warning("battle_launch_requested: invalid payload; ignored")
        return
    if _state != State.IDLE and _state != State.ERROR:
        push_warning("battle_launch_requested: already transitioning (state=%s); ignored" % State.keys()[_state])
        return
    _state = State.LOADING_BATTLE
    _overworld_ref = get_tree().current_scene
    _pause_overworld()
    GameBus.ui_input_block_requested.emit("scene_transition")
    _load_path = _resolve_battle_scene_path(payload.map_id)
    var err: Error = ResourceLoader.load_threaded_request(_load_path, "PackedScene", true)
    if err != OK:
        _transition_to_error("load_request_failed: %s" % error_string(err))
        return
    _load_timer.start()

func _pause_overworld() -> void:
    if not is_instance_valid(_overworld_ref):
        return
    _overworld_ref.process_mode = Node.PROCESS_MODE_DISABLED
    _overworld_ref.visible = false
    _overworld_ref.set_process_input(false)
    _overworld_ref.set_process_unhandled_input(false)
    # 4.5+ recursive disable on root Control (API name pending verification):
    var root_control: Control = _overworld_ref.get_node_or_null("UIRoot") as Control
    if root_control != null:
        root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
```

**Load status polling** (Timer-driven, 100 ms cadence — NOT per-frame):

```gdscript
func _on_load_tick() -> void:
    if _state != State.LOADING_BATTLE:
        _load_timer.stop()
        return
    var progress: Array = []
    var status: int = ResourceLoader.load_threaded_get_status(_load_path, progress)
    if progress.size() > 0:
        loading_progress = progress[0]
    match status:
        ResourceLoader.THREAD_LOAD_LOADED:
            _load_timer.stop()
            _instantiate_and_enter_battle()
        ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, ResourceLoader.THREAD_LOAD_FAILED:
            _load_timer.stop()
            _transition_to_error("load_failed: status=%d" % status)
        ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            pass   # keep polling

func _instantiate_and_enter_battle() -> void:
    var packed: PackedScene = ResourceLoader.load_threaded_get(_load_path) as PackedScene
    if packed == null:
        _transition_to_error("load_threaded_get returned null")
        return
    _battle_scene_ref = packed.instantiate()
    get_tree().root.add_child(_battle_scene_ref)
    _state = State.IN_BATTLE
    loading_progress = 1.0
    GameBus.ui_input_unblock_requested.emit("scene_transition")
```

**Return from battle** (outcome-driven, uses `call_deferred` to avoid
co-subscriber race per godot-specialist B-3):

```gdscript
func _on_battle_outcome_resolved(outcome: BattleOutcome) -> void:
    if not is_instance_valid(outcome):
        push_warning("battle_outcome_resolved: invalid payload; ignored")
        return
    if _state != State.IN_BATTLE:
        push_warning("battle_outcome_resolved outside IN_BATTLE (state=%s); ignored" % State.keys()[_state])
        return
    _state = State.RETURNING_FROM_BATTLE
    # Push BattleScene free one additional frame so co-subscriber
    # (ScenarioRunner) deferred handlers completing in the same frame
    # can still read BattleScene node references safely. See ADR-0002
    # §Risks and godot-specialist validation B-3.
    call_deferred("_free_battle_scene_and_restore_overworld")

func _free_battle_scene_and_restore_overworld() -> void:
    if is_instance_valid(_battle_scene_ref):
        _battle_scene_ref.queue_free()
    _battle_scene_ref = null
    if is_instance_valid(_overworld_ref):
        _overworld_ref.process_mode = Node.PROCESS_MODE_INHERIT
        _overworld_ref.visible = true
        _overworld_ref.set_process_input(true)
        _overworld_ref.set_process_unhandled_input(true)
        var root_control: Control = _overworld_ref.get_node_or_null("UIRoot") as Control
        if root_control != null:
            root_control.mouse_filter = Control.MOUSE_FILTER_STOP
    _state = State.IDLE
    loading_progress = 0.0
    # Focus restoration: Overworld UI subscribes to its own visibility_changed
    # and restores the pre-battle focused Control. SceneManager does NOT
    # touch focus state. See ADR-0002 §Risks R-3.
```

**Error recovery**:

```gdscript
func _transition_to_error(reason: String) -> void:
    _state = State.ERROR
    loading_progress = 0.0
    # Amendment to ADR-0001: new signal in UI/Flow domain.
    GameBus.scene_transition_failed.emit("scene_manager", reason)
    GameBus.ui_input_unblock_requested.emit("scene_transition")
    # Restore Overworld so the player can see the error dialog ScenarioRunner shows.
    if is_instance_valid(_overworld_ref):
        _overworld_ref.process_mode = Node.PROCESS_MODE_INHERIT
        _overworld_ref.visible = true
        _overworld_ref.set_process_input(true)
    # ERROR → LOADING_BATTLE retry: ScenarioRunner re-emits battle_launch_requested.
    # This is the only allowed way out of ERROR.
```

### Project Configuration

`project.godot` autoload block:

```ini
[autoload]

; ORDER-SENSITIVE: GameBus must precede SceneManager because SceneManager
; connects to GameBus signals in _ready. Per ADR-0001 and ADR-0002.
GameBus="*res://src/core/game_bus.gd"
SceneManager="*res://src/core/scene_manager.gd"
```

### Path Resolution

```gdscript
func _resolve_battle_scene_path(map_id: String) -> String:
    return "res://scenes/battle/%s.tscn" % map_id
```

Map IDs are validated by Scenario Progression's branch-table validator
(EC-SP-8); SceneManager assumes the path resolves. If the file is missing,
`ResourceLoader.load_threaded_request` returns `FAILED` and
`_transition_to_error` handles the fallback.

## Alternatives Considered

### Alternative 1: Overworld owns BattleScene as child node

- **Description**: Overworld scene instantiates BattleScene as its own
  child. No SceneManager autoload. Overworld emits
  `battle_launch_requested` AND directly calls `add_child(battle_scene)`.
- **Pros**: Simpler — no new autoload, no new global state. Tree-local
  wiring. Easier to grep (battle instantiation is in Overworld, not
  scattered).
- **Cons**: Couples Overworld lifecycle to BattleScene. If Overworld is
  ever freed mid-battle (e.g., main-menu return), BattleScene dangles.
  Input routing propagates from Overworld to BattleScene in ways that
  may cause unintended interactions (touch events on overlapping UI).
  Tests become harder — Scenario Progression unit tests spawn a full
  Overworld to test battle transitions.
- **Estimated Effort**: Lower upfront (~30% less code). Higher long-term
  (coupling debt).
- **Rejection Reason**: Scenario Progression GDD v2.0 UI-7 explicitly
  wants scene-scope handoff, not scene-nesting. Retry loops (LOSS →
  BATTLE_PREP) repeatedly create and destroy BattleScene under Overworld
  — nesting creates repeated re-parenting overhead. A dedicated
  SceneManager isolates the churn.

### Alternative 2: SceneTree.change_scene_to_packed (destructive swap)

- **Description**: Use Godot's built-in
  `SceneTree.change_scene_to_packed(battle_scene_packed)` to fully
  replace the current scene with BattleScene. After battle,
  `change_scene_to_packed(overworld_scene_packed)` returns.
- **Pros**: Native Godot idiom. Zero custom orchestration code. Memory
  efficient (only one scene loaded).
- **Cons**: **Destructive** — Overworld is freed on entry to battle.
  ScenarioRunner state is lost. On return, ScenarioRunner must be
  restored from save — adds a dependency on Save/Load for every battle
  boundary, which is architecturally heavy for a 9-beat-per-chapter
  flow. Beat 2 Prior-State Echo (which reads prior-retry state) becomes
  impossible to carry across a single retry loop without a mandatory
  checkpoint save.
- **Estimated Effort**: Low upfront; high coupling debt to Save/Load.
- **Rejection Reason**: Pillar-alignment decision #2 (Echo-state retry
  consequence) requires retry state to carry across LOSS → BATTLE_PREP
  without forcing a save. Destructive scene swap would mandate saves
  on every retry, violating the Echo mechanic design.

### Alternative 3: Preload all BattleScenes at scenario-select

- **Description**: When the player selects a scenario, preload ALL
  chapter BattleScenes into memory. Zero load delay at battle entry.
- **Pros**: Instant battle entry (<16 ms). No async load code. No
  LOADING_BATTLE state needed.
- **Cons**: Holds 5 × ~80 MB = 400 MB resident for a 5-chapter scenario.
  Blows past the 512 MB mobile ceiling with zero headroom for framework
  + Overworld. Scales linearly with chapter count — unshippable past
  MVP's 5-chapter spec. Scenario-select screen load time jumps to
  ~3 seconds.
- **Estimated Effort**: Low upfront, catastrophic memory debt.
- **Rejection Reason**: Violates 512 MB mobile ceiling with > 5 chapters.
  Incompatible with the planned 14-MVP-system memory budget.

### Alternative 4: Synchronous load with cross-fade

- **Description**: Blocking `PackedScene.instantiate()` behind a
  cross-fade transition shader. No async load code.
- **Pros**: Simplest implementation. No Timer. No state polling.
- **Cons**: Frame-time spike during load — observed ~500 ms on
  mid-range Android for a moderate battle scene. Within the fade
  window visually, but the audio thread may stutter. Non-deterministic
  across devices — the fade duration would need to be tuned to the
  slowest device, making fast devices feel sluggish.
- **Estimated Effort**: Lowest upfront.
- **Rejection Reason**: Mobile-primary platform with 60 fps target
  cannot absorb a 500 ms frame spike. Async load with a progress bar is
  the professional norm for this scene-size class.

## Consequences

### Positive

- **Scene-scope handoff ratified** — Scenario Progression v2.1 can lock
  UI-7 and proceed to implementation.
- **Overworld state survives battle** — ScenarioRunner beat-machine
  continues across retries without mandatory save/load round-trips.
- **Mobile-compliant load** — async threaded load plus progress bar
  gives smooth UX on mid-range Android.
- **ADR-0001-compliant** — zero emits from `_process`. All transitions
  go through GameBus with `CONNECT_DEFERRED`.
- **Testable** — SceneManager stub injectable the same way GameBus stub
  is; Scenario Progression unit tests can assert transition behavior
  without loading a real BattleScene.
- **Single owner for scene lifecycle** — every future system that needs
  to cross the scene boundary uses this ADR's contract. No feature
  branches inventing their own patterns.

### Negative

- **Another global surface** — `/root/SceneManager` is visible from every
  script. Mitigation: ADR forbids gameplay state on SceneManager (same
  discipline as GameBus); code review enforces.
- **Memory retention** — Overworld held resident during battle consumes
  ~50 MB that could be reclaimed. Peak resident ~230 MB on 512 MB
  ceiling is well within budget but higher than destructive-swap
  alternative. Mitigation: verified on target device; ample headroom.
- **Handler-order discipline required** — every co-subscriber to
  `battle_outcome_resolved` (currently: ScenarioRunner) must tolerate
  the one-frame delay on BattleScene free. Documented contract.
- **ADR-0001 amendment required** — `scene_transition_failed` signal
  must be added to GameBus's UI/Flow domain. Minor amendment per
  ADR-0001 §Evolution Rule #1 (no supersession).

### Neutral

- **Recursive Control disable API name is a 4.5+ verification item** —
  engine-reference specifies the feature exists but leaves the exact
  propagation property ambiguous. Implementation must verify against
  Godot 4.6 docs before coding. Fallback: per-Control
  `set_mouse_filter(MOUSE_FILTER_IGNORE)` walk.
- **Timer-based polling at 100 ms** adds up to ~100 ms to the perceived
  load time in the worst case. For a load expected to take 300–1500 ms
  on mid-range Android, this is noise.
- **Retry loop preserves Overworld** — Beat 2 Prior-State Echo operates
  on in-memory ScenarioRunner state across `LOSS → BATTLE_PREP` retry
  without mandatory save. Deliberate pillar-alignment consequence.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Recursive Control disable API name differs from engine-reference | MEDIUM | LOW — falls back to per-Control walk | Verification required pre-implementation; implementation ADR-aware of fallback path. |
| Co-subscriber deferred handler order still races despite `call_deferred` extra frame | LOW | HIGH — crash on freed node ref | godot-specialist B-3 validated the 1-frame defer; unit test `scene_handoff_timing_test.gd` asserts ordering on target device. |
| BattleScene instantiate fails on Android due to out-of-memory | MEDIUM | HIGH — soft-lock | ERROR state + `scene_transition_failed` signal; ScenarioRunner shows retry/abort dialog; Overworld restored for visibility. |
| Overworld held resident leaks memory over many retries | LOW | MEDIUM — OOM after prolonged session | Overworld textures stay resident (Godot does not auto-unload on hide); verified 230 MB peak against 512 MB ceiling leaves 280 MB headroom; acceptable for MVP. |
| `ResourceLoader.load_threaded_*` behavior changes on Android export | LOW | HIGH — async load falls back to sync | Verification item in Engine Compatibility §Verification Required. If regressed, fallback to Alternative 4 synchronous load + fade. |
| ScenarioRunner retains reference to Overworld after re-show, expects input focus state preserved | MEDIUM | LOW — input to wrong Control | Focus restoration contract: Overworld UI owns focus state via `visibility_changed` hook (R-3 from godot-specialist). SceneManager does not touch focus. |
| Autoload order regressed by a programmer reordering `project.godot` | LOW | HIGH — crash at boot | Comment in `project.godot` (see §Project Configuration); pre-commit lint if added later. |
| Nested battles / battle-within-battle triggered by design evolution | LOW | HIGH — state machine cannot model | Explicit rejection in state machine (`battle_launch_requested` outside IDLE/ERROR is ignored with push_warning). Superseding ADR required if ever needed. |

## Performance Implications

| Metric | Before | Expected After | Budget |
|---|---|---|---|
| CPU (SceneManager, IDLE) | 0 ms | 0 ms | <0.1 ms/frame |
| CPU (SceneManager, LOADING_BATTLE) | 0 ms | <0.05 ms/tick × 10 ticks/sec = 0.5 ms/sec | Negligible (<0.1% of frame budget amortized) |
| CPU (SceneManager, IN_BATTLE) | 0 ms | 0 ms (idle) | <0.1 ms/frame |
| Memory (SceneManager node) | 0 MB | <0.1 MB | N/A |
| Memory (Overworld retained) | 0 MB | ~50 MB | within 512 MB mobile ceiling |
| Memory (BattleScene peak) | 0 MB | ~80 MB | within 512 MB mobile ceiling |
| Memory (total peak resident) | 0 MB | ~230 MB (100 MB engine + 50 MB Overworld + 80 MB BattleScene) | 512 MB mobile ceiling (45% utilization, 280 MB headroom) |
| Load time (BattleScene, Snapdragon 7-gen) | N/A | 300–1500 ms (async, non-blocking) | <2000 ms with visible progress |
| Frame-time spike during load | N/A | <1 ms (async load is off-thread) | <16.6 ms budget always |

## Migration Plan

No legacy code to migrate. Rollout:

1. **Amend ADR-0001** — add `scene_transition_failed(context: String,
   reason: String)` to the UI/Flow domain signal table. Add changelog
   entry. Update `src/core/game_bus.gd` when it is first implemented.
2. **Create `src/core/scene_manager.gd`** — autoload script per §Key
   Interfaces.
3. **Register autoload in `project.godot`** — second after GameBus, with
   order-sensitive comment.
4. **Write `tests/unit/core/scene_manager_test.gd`** — unit tests for:
   state-machine transitions (IDLE → LOADING → IN_BATTLE → IDLE; IDLE →
   LOADING → ERROR → LOADING retry); `CONNECT_DEFERRED` ordering with
   a co-subscriber stub; `load_threaded_*` happy path and failure path
   via mock ResourceLoader; Overworld pause/restore state discipline.
5. **Write `tests/integration/core/scene_handoff_timing_test.gd`** —
   integration test loading an actual BattleScene PackedScene on the
   target export; asserts 1-frame defer keeps co-subscriber refs valid.
6. **Update Scenario Progression GDD v2.1** — UI-7 provisional marker
   removed; cite this ADR as the authoritative contract.
7. **First consumer: Scenario Progression implementation** — begins
   only after ADR-0002 is Accepted.

**Rollback plan**: If SceneManager proves wrong within vertical-slice,
supersede with ADR-000N. Rollback cost is LOW before Scenario
Progression implementation; MEDIUM after one MVP system integrates;
HIGH after 3+ MVP systems. This is why we ratify now, before any
gameplay implementation.

## Validation Criteria

- [ ] **V-1**: SceneManager autoload loads without error in a minimal
  Godot 4.6 project with GameBus as the only other autoload.
- [ ] **V-2**: State machine transitions correctly on synthetic signal
  emissions (unit test).
- [ ] **V-3**: `ResourceLoader.load_threaded_request` happy path works
  on target Android export (integration test).
- [ ] **V-4**: `ResourceLoader.load_threaded_request` failure path
  transitions to ERROR and emits `scene_transition_failed` (integration
  test).
- [ ] **V-5**: `CONNECT_DEFERRED` + `call_deferred("_free_battle_
  scene_and_restore_overworld")` produces co-subscriber-safe ordering:
  a test stub subscribing to `battle_outcome_resolved` can read
  `BattleScene` node references during its deferred handler without
  crash (integration test).
- [ ] **V-6**: Overworld pause discipline works — `_process`,
  `_physics_process`, `_input`, `_unhandled_input` all suppressed on
  Overworld subtree when SceneManager is in LOADING_BATTLE or IN_BATTLE
  (unit test with instrumented Overworld stub).
- [ ] **V-7**: Recursive Control disable (4.5+) propagates correctly on
  target Android export — touch events do not reach Overworld UI
  during IN_BATTLE (integration test). Fallback path tested if API
  name differs.
- [ ] **V-8**: Memory profile on Snapdragon 7-gen: peak resident ≤250
  MB during IN_BATTLE with Overworld retained (performance test).
- [ ] **V-9**: `scene_transition_failed` signal is declared on GameBus
  (validated by updated `signal_contract_test.gd` — lives in ADR-0001's
  amendment).
- [ ] **V-10**: SceneManager stub injectable in `before_test` and
  restored in `after_test` (GdUnit4 pattern matches GameBus stub).
- [ ] **V-11**: Retry loop: LOSS outcome → ScenarioRunner re-emits
  `battle_launch_requested` → SceneManager transitions ERROR (if
  applicable) or IDLE → LOADING_BATTLE successfully without Overworld
  state loss (integration test replicates Scenario Progression F-SP-3
  Echo retry flow).
- [ ] **V-12**: `loading_progress` property exposes `[0.0, 1.0]` float
  during LOADING_BATTLE, readable by UI without bus subscription (UI
  integration test).

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Addresses It |
|---|---|---|---|
| `design/gdd/scenario-progression.md` | Scenario Progression (#6 MVP) | UI-7 (provisional): ScenarioRunner ↔ BattleScene scope handoff contract | This ADR ratifies the contract. Overworld retained, BattleScene as `/root` peer, signal-driven transitions, error recovery path. Scenario Progression v2.1 removes UI-7 provisional marker and cites ADR-0002. |
| `design/gdd/scenario-progression.md` | Scenario Progression (#6 MVP) | Beat 5 → Beat 6 transition timing: battle outcome must reach ScenarioRunner without ScenarioRunner being destroyed | SceneManager retains Overworld. ScenarioRunner's deferred handler for `battle_outcome_resolved` fires in the same frame as SceneManager's; `call_deferred` defers free one extra frame to guarantee handler completion. |
| `design/gdd/scenario-progression.md` | Scenario Progression (#6 MVP) | F-SP-3 Echo retry (LOSS → BATTLE_PREP loop): echo_count accumulates across retries in-memory | Overworld retention means ScenarioRunner's state (including echo_count) survives the retry loop without requiring a save checkpoint. Pillar-alignment decision #2 preserved. |
| `design/gdd/grid-battle.md` | Grid Battle (#1 MVP) | §CLEANUP: scene teardown must emit `battle_outcome_resolved` and free scene | Grid Battle emits via GameBus per ADR-0001. SceneManager handles the teardown (calls `queue_free` via deferred). Grid Battle code does not need to know it is being freed. |
| `design/gdd/balance-data.md` | Balance/Data (#26 MVP) | Battle scene paths must be data-driven | `_resolve_battle_scene_path(map_id)` resolves against a convention (`res://scenes/battle/{map_id}.tscn`). Scenario authoring supplies map_id via BattlePayload. |
| `design/gdd/input-handling.md` | Input Handling (#29 MVP) | `ui_input_block_requested` / `ui_input_unblock_requested` emit on transitions | SceneManager emits both on LOADING_BATTLE entry and IN_BATTLE entry respectively; on ERROR entry, unblock is emitted for visibility of error dialog. |

## TR Registry

Registered TR entries (tr-registry v2, 2026-04-18):

- `TR-scene-manager-001` — SceneManager must be an autoload at
  `/root/SceneManager`, second after GameBus. State machine: IDLE,
  LOADING_BATTLE, IN_BATTLE, RETURNING_FROM_BATTLE, ERROR.
- `TR-scene-manager-002` — Overworld scene retained during battle via
  `process_mode = PROCESS_MODE_DISABLED` + `visible = false` +
  `set_process_input(false)` + root Control recursive mouse-filter
  ignore. NOT freed.
- `TR-scene-manager-003` — BattleScene instantiated as `/root` peer to
  Overworld using `ResourceLoader.load_threaded_request` (async).
  Status polled via Timer node at 100 ms cadence. NOT polled in
  `_process`.
- `TR-scene-manager-004` — On `battle_outcome_resolved`, BattleScene
  freed via `call_deferred("_free_battle_scene_and_restore_overworld")`
  — defers free one additional frame to preserve co-subscriber
  deferred-handler node references.
- `TR-scene-manager-005` — On async-load failure, SceneManager emits
  `scene_transition_failed(context, reason)` via GameBus and transitions
  to ERROR state. Recovery only via re-emit of `battle_launch_requested`.

## Related

- **ADR-0001** (`docs/architecture/ADR-0001-gamebus-autoload.md`) —
  prerequisite; this ADR requires a minor amendment to ADR-0001 to add
  `scene_transition_failed` signal.
- **Scenario Progression GDD v2.0** (`design/gdd/scenario-progression.md`)
  — UI-7 ratification consumer.
- **Grid Battle GDD** (`design/gdd/grid-battle.md`) — §CLEANUP consumer.
- **Future**: Save/Load ADR (if authored) will cite this ADR for scene-
  transition-boundary checkpoint timing.
- **Future**: Scene Pooling ADR (post-Alpha, if profiling shows load
  times exceeding budget at scale) — may introduce PackedScene LRU
  cache as a supersedable addition.
- **Code (once implemented)**: `src/core/scene_manager.gd`,
  `tests/unit/core/scene_manager_test.gd`,
  `tests/integration/core/scene_handoff_timing_test.gd`.

---

## Changelog

| Date | Change | Author |
|---|---|---|
| 2026-04-18 | Initial ADR drafted (Proposed). State machine, async load via Timer, Overworld retention, co-subscriber deferred-free pattern, ERROR recovery. godot-specialist validation incorporated (3 blockers resolved, 5 recommendations adopted). | technical-director |
| 2026-04-18 | Transitioned Proposed → Accepted after `/architecture-review` (re-run) resolved ADR-0001 mechanical amendments (F-1, F-2). No changes to ADR content — SceneManager design is now binding. TR-scene-manager-001..005 registered in tr-registry v2. | technical-director |
