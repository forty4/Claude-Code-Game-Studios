# ADR-0001: GameBus Autoload — Cross-System Signal Relay

## Status

Accepted (2026-04-18, via `/architecture-review`)

## Date

2026-04-18

## Last Verified

2026-04-30 (via ADR-0011 same-patch amendment — added Turn Order Domain signal `victory_condition_detected(result: int)` declaration + §3 table row)

## Decision Makers

- Technical Director (architecture owner)
- User (final approval, 2026-04-18)
- Referenced by Scenario Progression GDD v1.0 (OQ-SP-01) as the pattern to ratify

## Summary

Cross-system events in 천명역전 (Defying Destiny) must cross scene boundaries (title → main-menu → battle-scene → story-event) without creating direct node references that would break on scene reload. This ADR ratifies a single Godot autoload singleton at `/root/GameBus` that declares every cross-system signal in one grep-able location, serves as a pure relay (no game state), and is the authoritative contract that all 14 MVP-tier systems must cite when emitting or subscribing to cross-scene events.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core / Scripting |
| **Knowledge Risk** | MEDIUM — autoload semantics and typed-signal declarations are stable since 4.2, but `@warning_ignore` behavior around typed-signal strictness tightened in 4.5 |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/current-best-practices.md` |
| **Post-Cutoff APIs Used** | Typed signal parameters (stable since 4.2, strictness tightened in 4.5); `Resource.duplicate_deep()` available for payload cloning (added in 4.5 — see `breaking-changes.md` §4.4→4.5 and `current-best-practices.md` §Resources); no reliance on accessibility (AccessKit) or shader baker features |
| **Verification Required** | (1) Confirm typed signals with `Resource` payloads serialize correctly across `save_checkpoint_requested` → Save/Load round-trip on target export (Android + Windows). (2) Confirm `CONNECT_DEFERRED` fires on the next idle frame, not the next physics frame, when emitter is in `_physics_process`. (3) Verify autoload order: `GameBus` must load before any system that calls `GameBus.connect(...)` in `_ready`. |

> **Note**: Knowledge Risk is MEDIUM. Re-validate this ADR if upgrading past Godot 4.6.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | None — this is a foundational architectural ADR. |
| **Enables** | Future ADR on Save/Load serialization (#17 VS); Future ADR on Scene Manager (battle scene load/unload); Scenario Progression implementation (#6 MVP); Destiny State implementation (#16 VS); any cross-scene signal flow. |
| **Blocks** | Scenario Progression implementation (cannot start coding #6 until this ADR is Accepted — OQ-SP-01 explicitly blocks on this). Grid Battle ↔ Scenario Progression handoff (battle_complete relay). |
| **Ordering Note** | Must be Accepted before any MVP gameplay system begins implementation. First ADR of the project by design — all subsequent ADRs inherit its signal conventions. |

## Context

### Problem Statement

The 14 MVP systems of 천명역전 must communicate across scene boundaries. The core handoff — Scenario Progression lives in the overworld scene, Grid Battle lives in a battle scene instanced on demand — means the emitter (`Grid Battle`) and subscriber (`Scenario Progression`) cannot hold direct references to each other. The battle scene is destroyed on CLEANUP; any signal wiring on the battle-scene side becomes a dangling reference the moment the scene unloads.

Without a ratified pattern, each programmer will invent their own — some using `get_tree().get_root().get_node(...)`, some chaining signals through parent nodes, some falling back to singletons with game state baked in. This creates three concrete failure modes already visible in the GDDs:

1. **Scenario Progression GDD OQ-SP-01** explicitly flags "GameBus autoload" as a locked decision but defers the pattern ratification to this ADR.
2. **Scenario Progression EC-SP-5** documents `battle_complete` firing twice as a known failure mode that depends on GameBus guarantees (emission ordering, single-subscriber enforcement).
3. **Grid Battle §CLEANUP** commits to emitting `battle_complete(outcome_data)` "relayed through GameBus autoload" — a contract with no defined shape until now.

The cost of not deciding: every MVP feature branch will implement its own relay, producing 14 subtly different patterns that cannot be grep'd, tested, or reasoned about uniformly. Scenario Progression cannot begin implementation until this is ratified (blocking).

### Current State

No signal architecture exists. Scenario Progression GDD v1.0 documents five outbound signals (`chapter_started`, `battle_prepare_requested`, `battle_launch_requested`, `chapter_completed`, `scenario_complete`) and one inbound signal (`battle_complete`) without specifying the relay mechanism. Grid Battle GDD commits to the same `battle_complete` contract. Turn Order GDD declares `round_started`, `unit_turn_started`, `unit_turn_ended`, `battle_ended`. HP/Status emits `unit_died`. Input Handling emits `input_action_fired`, `input_state_changed`, `input_mode_changed`. None of these are colocated; each GDD assumes "the engine" will make them work.

### Constraints

- **Engine**: Godot 4.6, GDScript only (no GDExtension for core relays — see `technical-preferences.md`).
- **Platform**: Mobile-primary (iOS/Android). Every hot-path allocation matters against the 512 MB mobile ceiling and 16.6 ms / 60 fps budget.
- **Physics**: Jolt (4.6 default). Physics tick is fixed-rate 60 Hz; relays triggered from `_physics_process` must not stall the physics thread.
- **Input**: Mixed touch + keyboard/mouse. Input events already fan out at high frequency; bus must not amplify them.
- **Scene boundaries**: Title, main menu, scenario select, overworld (beats 1–4, 6–9), battle scene (beat 5, IN_BATTLE). Battle scene is instanced per chapter and destroyed on CLEANUP. Any relay that holds a reference to a battle-scene node must survive that destruction.
- **Testing**: GdUnit4 is the framework. Tests must be able to swap GameBus for a double (Scenario Progression unit tests must assert "emitted `chapter_completed` with shape X" without spinning up Grid Battle).
- **Coding standards**: All public APIs doc-commented; no hardcoded gameplay values; dependency injection over singletons where testable.

### Requirements

1. **Single declaration point** — every cross-system signal declared in one file (grep-ability, contract visibility).
2. **Scene-reload-safe** — emitting and subscribing does not create dangling references when a scene is freed.
3. **Typed payloads** — signals with ≥2 payload fields use a typed `Resource` class; ≤1 field uses typed primitives. No untyped `Dictionary` payloads (breaks static typing, breaks grep for field usage).
4. **Serializable payloads** — payload `Resource` classes must round-trip through Godot's `ResourceSaver` / `ResourceLoader` so Save/Load (#17) can persist them.
5. **Per-frame forbidden** — no signal emits from `_process` or `_physics_process` hot loops. Per-frame state reads use direct property queries, not bus traffic.
6. **Performance budget** — relay logic adds <0.05 ms per emit on mid-range Android (Snapdragon 7-gen target); zero allocations in the relay path itself (payloads are constructed by emitter, not cloned by bus).
7. **Testable** — a GdUnit4 test double must be injectable without modifying production code (swap in `before_test`, restore in `after_test`).

## Decision

We adopt a single Godot autoload singleton at `/root/GameBus` as the pure relay for all cross-system signals in 천명역전. GameBus declares every signal in one file, organized by domain banner comments. GameBus holds NO game state — it is exclusively a signal-relay surface. All signal emissions and subscriptions use `CONNECT_DEFERRED` with explicit `_exit_tree` disconnects and `is_instance_valid` guards.

### Architecture

```
                     ┌──────────────────────────────────────────────────┐
                     │            /root/GameBus (autoload)              │
                     │                                                  │
                     │  signal battle_outcome_resolved(BattleOutcome)   │
                     │  signal chapter_started(String, int)             │
                     │  signal chapter_completed(ChapterResult)         │
                     │  signal destiny_branch_chosen(...)               │
                     │  signal ... (26 signals total — see Schema)      │
                     │                                                  │
                     │           [pure relay — zero state]              │
                     └──────────────────────────────────────────────────┘
                                      ▲             │
                                      │ emit        │ subscribe (deferred)
                                      │             ▼
        ┌─────────────────┐        ┌────────────────┐        ┌──────────────┐
        │  Grid Battle    │        │   Scenario     │        │  Save/Load   │
        │  (battle scene) │        │   Progression  │        │  (persistent)│
        │                 │        │   (overworld)  │        │              │
        │  emits:         │───────▶│  subscribes to │        │  subscribes  │
        │  battle_outcome │        │  battle_outcome│        │  to chapter_ │
        │    _resolved    │        │    _resolved   │        │    completed │
        └─────────────────┘        └────────────────┘        └──────────────┘
                 ▲                         │                        ▲
                 │                         │                        │
                 │ emits chapter_started   │ emits chapter_completed│
                 └─────────────────────────┴────────────────────────┘
```

### Key Interfaces

**Autoload declaration** (`src/core/game_bus.gd`):

```gdscript
## GameBus — the single cross-system signal relay for 천명역전.
##
## This file is the authoritative signal contract referenced by ADR-0001.
## Every cross-scene / cross-system event in the project is declared here.
##
## RULES:
##  - GameBus holds NO game state. It is a pure relay.
##  - Emission semantics: direct emission from emitters (`GameBus.battle_outcome_resolved.emit(payload)`).
##    Subscribers always use `CONNECT_DEFERRED`:
##      GameBus.battle_outcome_resolved.connect(_on_battle_outcome, CONNECT_DEFERRED)
##  - Subscribers MUST disconnect in `_exit_tree` and guard payloads with `is_instance_valid`.
##  - Per-frame events are FORBIDDEN here. See ADR-0001 §Implementation Guidelines.
##
## DO NOT add fields, methods, or logic to this file beyond signal declarations
## and doc comments. See ADR-0001 §Evolution Rule for how to change the contract.
extends Node

# ═══ DOMAIN: Scenario Progression (emitter: ScenarioRunner) ════════════════════
signal chapter_started(chapter_id: String, chapter_number: int)
signal battle_prepare_requested(payload: BattlePayload)
signal battle_launch_requested(payload: BattlePayload)
signal chapter_completed(result: ChapterResult)
signal scenario_complete(scenario_id: String)
signal scenario_beat_retried(mark: EchoMark)

# ═══ DOMAIN: Grid Battle (emitter: BattleController) ═══════════════════════════
signal battle_outcome_resolved(outcome: BattleOutcome)
signal round_started(round_number: int)
signal unit_turn_started(unit_id: int)
signal unit_turn_ended(unit_id: int, acted: bool)
signal victory_condition_detected(result: int)  # int enum {PLAYER_WIN=0, PLAYER_LOSE=1, DRAW=2} — Turn Order detects, Grid Battle consumes + emits authoritative battle_outcome_resolved per single-owner rule (added 2026-04-30 via ADR-0011 same-patch amendment)
signal unit_died(unit_id: int)

# ═══ DOMAIN: Destiny (emitter: DestinyBranchJudge / DestinyStateStore) ═════════
signal destiny_branch_chosen(choice: DestinyBranchChoice)
signal destiny_state_flag_set(flag_key: String, value: bool)
signal destiny_state_echo_added(mark: EchoMark)

# ═══ DOMAIN: Story Event / Beat presentation (emitter: BeatConductor) ══════════
signal beat_visual_cue_fired(cue: BeatCue)
signal beat_audio_cue_fired(cue: BeatCue)
signal beat_sequence_complete(beat_number: int)

# ═══ DOMAIN: Input (emitter: InputRouter) ══════════════════════════════════════
signal input_action_fired(action: String, context: InputContext)
signal input_state_changed(from: int, to: int)
signal input_mode_changed(mode: int)

# ═══ DOMAIN: UI / Flow (emitter: UIRoot, SceneManager) ═════════════════════════
signal ui_input_block_requested(reason: String)
signal ui_input_unblock_requested(reason: String)
signal scene_transition_failed(context: String, reason: String)  # ADR-0002 amendment

# ═══ DOMAIN: Persistence (emitter: SaveManager; ScenarioRunner requests) ═══════
# Added by ADR-0003 amendment (2026-04-18).
signal save_checkpoint_requested(ctx: SaveContext)
signal save_persisted(chapter_number: int, cp: int)
signal save_load_failed(op: String, reason: String)

# ═══ DOMAIN: Environment (emitter: MapGrid) ════════════════════════════════════
# Added by ADR-0004 amendment (2026-04-18). Single-primitive payload is the
# canonical form for single-value signals per TR-gamebus-001.
signal tile_destroyed(coord: Vector2i)
```

**Payload Resource example** (`src/core/payloads/battle_outcome.gd`):

```gdscript
## BattleOutcome — payload for GameBus.battle_outcome_resolved.
## Owned by Grid Battle §CLEANUP. Consumed by Scenario Progression IN_BATTLE → OUTCOME.
##
## Result enum is tri-state {WIN, DRAW, LOSS} per Pillar-alignment decision.
## Scenario Progression F-SP-2 maps DRAW to LOSS for branch routing; the original
## DRAW value is preserved on this payload for Destiny State / telemetry.
class_name BattleOutcome
extends Resource

enum Result { WIN, DRAW, LOSS }

@export var result: Result = Result.LOSS
@export var chapter_id: String = ""
@export var final_round: int = 0
@export var surviving_units: PackedInt64Array = PackedInt64Array()
@export var defeated_units: PackedInt64Array = PackedInt64Array()
@export var is_abandon: bool = false  # LOSS-only; true if player chose Abandon
```

**Subscriber pattern** (example in `ScenarioRunner`):

```gdscript
func _ready() -> void:
    GameBus.battle_outcome_resolved.connect(_on_battle_outcome_resolved, CONNECT_DEFERRED)

func _exit_tree() -> void:
    if GameBus.battle_outcome_resolved.is_connected(_on_battle_outcome_resolved):
        GameBus.battle_outcome_resolved.disconnect(_on_battle_outcome_resolved)

func _on_battle_outcome_resolved(outcome: BattleOutcome) -> void:
    if not is_instance_valid(outcome):
        push_warning("battle_outcome_resolved received invalid payload; ignored")
        return
    if _state != State.IN_BATTLE:
        push_warning("battle_outcome_resolved received outside IN_BATTLE; ignored (EC-SP-5)")
        return
    _transition_to_outcome(outcome)
```

### Implementation Guidelines

1. **Autoload registration** — Add to `project.godot` under `[autoload]`: `GameBus="*res://src/core/game_bus.gd"`. The `*` prefix makes it a singleton node at `/root/GameBus`. Must be the first autoload entry so every other autoload can reference it.

2. **Signal naming** — `{domain}_{event}_{past_tense}`. Domain prefix is one of: `scenario_`, `battle_`, `round_`, `unit_`, `destiny_`, `beat_`, `input_`, `ui_`, `save_`. Past-tense tail (`_started`, `_completed`, `_resolved`, `_chosen`, `_requested`) disambiguates event-fact from command-verb.

3. **Payload typing rule**:
   - **≥2 fields** → define a payload `Resource` class with `class_name`, `@export` fields, static types. File in `src/core/payloads/`.
   - **1 field of primitive type** → typed primitive directly in signal signature (e.g., `scenario_complete(scenario_id: String)`).
   - **0 fields** → bare signal (e.g., `ui_input_block_requested(reason: String)` — `reason` is mandatory even with zero-payload events, for log traceability).
   - **Never**: untyped `Dictionary`, `Array`, or `Variant` payloads. These break static typing, break IDE autocomplete, and break Save/Load round-tripping.

4. **Serialization contract** — every payload `Resource` class must be serializable via `ResourceSaver.save(payload, tmp_path)` → `ResourceLoader.load(tmp_path)` with identical data. Test this in `tests/unit/core/payload_serialization_test.gd` for every payload class. Save/Load (#17) will depend on this.

5. **Connection mode** — `CONNECT_DEFERRED` is mandatory for cross-scene connects. Emitters run in the battle scene's frame; subscribers run in the overworld scene's frame. Deferred connection guarantees the subscriber executes on the next idle frame, after physics and input are resolved, avoiding re-entrancy. `CONNECT_ONE_SHOT` is allowed for save_checkpoint_requested and similar discrete commits.

6. **Lifecycle discipline** — every `connect(...)` in `_ready` MUST have a matching `disconnect(...)` in `_exit_tree` guarded by `is_connected`. Every signal handler MUST guard `Resource` payloads with `is_instance_valid` (a freed Resource arriving through a deferred call is a known Godot edge case — see Scenario Progression EC-SP-5).

7. **Forbidden emission contexts**:
   - NOT from `_process(delta)` — violates per-frame ban.
   - NOT from `_physics_process(delta)` — violates per-frame ban AND creates physics-to-idle ordering hazards.
   - NOT from `_input(event)` for high-frequency input (mouse motion, touch drag) — use dedicated input batching in InputRouter.
   - ALLOWED from: state-machine transitions, explicit command handlers, scene-lifecycle hooks, authored gameplay moments (e.g., "chapter concluded").

8. **Soft cap** — 50 emissions per frame, project-wide. Enforced by debug-only `GameBusDiagnostics` (stripped in release builds) that counts emits per frame and logs `push_warning` on exceed. This is a smell detector, not a hard limit.

9. **GameBus test double** — in GdUnit4, `before_test` removes the production `/root/GameBus` node and registers a `GameBusStub` with the same signals. `after_test` restores. Stub inherits the same interface by loading the same script — no duplication. Pattern documented in `tests/unit/core/README.md` (to be created with implementation).

### Signal Contract Schema

This is the authoritative contract. Scenario Progression GDD v2.0 cites this table directly. Changes require superseding ADR.

**Frequency class legend**:
- `discrete` — narrative/flow events, ≤1 per minute typical (chapter transitions, scenario boundaries)
- `burst` — combat resolution events, ≤5 per second in combat peak (round ticks, unit death)
- `input` — player-driven events, event-rate bounded by player (action fires, state changes)
- Per-frame is FORBIDDEN across all domains.

**Payload type legend**:
- `Resource` — typed Resource class in `src/core/payloads/`
- `[primitive]` — directly typed GDScript primitive
- `PROVISIONAL` — shape will be locked by downstream GDD; this ADR locks only the name and emitter

#### 1. Scenario Progression domain (Emitter: ScenarioRunner)

| Signal | Payload Type | Payload Fields | Emitter | Subscribers (MVP) | Frequency |
|---|---|---|---|---|---|
| `chapter_started` | `String, int` | `chapter_id: String`, `chapter_number: int` | ScenarioRunner (OPENING_EVENT entry) | Story Event, Battle HUD, Main Menu | discrete |
| `battle_prepare_requested` | `BattlePayload` (Resource) | `map_id: String`, `unit_roster: PackedInt64Array`, `deployment_positions: Dictionary`, `victory_conditions: VictoryConditions`, `battle_start_effects: Array[BattleStartEffect]` | ScenarioRunner (BATTLE_PREP entry) | Battle Preparation UI (not MVP — deferred), Battle HUD | discrete |
| `battle_launch_requested` | `BattlePayload` (Resource) | (same as above) | ScenarioRunner (BATTLE_PREP → IN_BATTLE) | SceneManager (Grid Battle scene instantiation) | discrete |
| `chapter_completed` | `ChapterResult` (Resource) | `chapter_id: String`, `outcome: BattleOutcome.Result`, `branch_triggered: String`, `flags_to_set: Array[String]` | ScenarioRunner (BRANCH_JUDGMENT → TRANSITION) | Destiny State, Save/Load | discrete |
| `scenario_complete` | `String` | `scenario_id: String` | ScenarioRunner (COMPLETE entry) | Main Menu, Save/Load | discrete |
| `scenario_beat_retried` | `EchoMark` (Resource) `[PROVISIONAL — locked by Destiny State GDD #16]` | Provisional shape: `chapter_id: String`, `beat_number: int`, `retry_count: int`, `timestamp_unix: int`. Final shape owned by Destiny State. | ScenarioRunner (on retry, LOSS → BATTLE_PREP loop) | Destiny State, Story Event (Beat 2 echo content) | discrete |

#### 2. Grid Battle domain (Emitter: BattleController)

| Signal | Payload Type | Payload Fields | Emitter | Subscribers (MVP) | Frequency |
|---|---|---|---|---|---|
| `battle_outcome_resolved` | `BattleOutcome` (Resource) | `result: Result {WIN, DRAW, LOSS}`, `chapter_id: String`, `final_round: int`, `surviving_units: PackedInt64Array`, `defeated_units: PackedInt64Array`, `is_abandon: bool` | BattleController (CLEANUP entry) | ScenarioRunner, Save/Load (via `chapter_completed` chain), Character Growth (#9 VS — post-MVP) | discrete |

> **Note**: This is the single signal that replaces `battle_complete(outcome_data)` referenced in Scenario Progression GDD v1.0 and Grid Battle GDD. Name change from `battle_complete` to `battle_outcome_resolved` enforces the tri-state convention and past-tense naming rule. Scenario Progression GDD v2.0 must update its §C.3 references.

#### 3. Turn Order domain (Emitter: TurnOrderRunner)

| Signal | Payload Type | Payload Fields | Emitter | Subscribers (MVP) | Frequency |
|---|---|---|---|---|---|
| `round_started` | `int` | `round_number: int` | TurnOrderRunner (R1) | Grid Battle, Formation Bonus (#3 MVP), Battle HUD | burst |
| `unit_turn_started` | `int` | `unit_id: int` | TurnOrderRunner (T0) | Grid Battle, AI (#8 MVP), Battle HUD | burst |
| `unit_turn_ended` | `int, bool` | `unit_id: int`, `acted: bool` | TurnOrderRunner (T7) | Grid Battle, AI | burst |
| `victory_condition_detected` | `int` | `result: int` (enum {PLAYER_WIN=0, PLAYER_LOSE=1, DRAW=2}) | TurnOrderRunner (T7 decisive outcome OR RE2 round cap DRAW) | Grid Battle (sole consumer; transitions to RESOLUTION + emits authoritative `battle_outcome_resolved`) | discrete |

> **Note**: Turn Order GDD declares `battle_ended(result)` but that responsibility moves to Grid Battle's `battle_outcome_resolved` per this ADR — a single system owns battle termination to prevent the dual-emitter edge case (Turn Order GDD EC-03 and Grid Battle EC-GB-23 agree Grid Battle is authoritative). Turn Order's role is to DETECT the terminal condition and emit `victory_condition_detected(result)` (added 2026-04-30 via ADR-0011 same-patch amendment); Grid Battle consumes the bridge signal and emits the authoritative `battle_outcome_resolved` with the typed `BattleOutcome` Resource payload (chapter_id / final_round / surviving_units that Turn Order does not have).

#### 4. HP/Status domain (Emitter: HPStatusController per unit, relayed via GameBus)

| Signal | Payload Type | Payload Fields | Emitter | Subscribers (MVP) | Frequency |
|---|---|---|---|---|---|
| `unit_died` | `int` | `unit_id: int` | HPStatusController (on HP reaching 0) | Turn Order (removes from queue), Grid Battle (victory check), AI | burst |

#### 5. Destiny domain (Emitter: DestinyBranchJudge, DestinyStateStore)

| Signal | Payload Type | Payload Fields | Emitter | Subscribers (MVP) | Frequency |
|---|---|---|---|---|---|
| `destiny_branch_chosen` | `DestinyBranchChoice` (Resource) `[PROVISIONAL — locked by Destiny Branch GDD #4]` | Provisional: `chapter_id: String`, `branch_key: String`, `revelation_cue_id: String`, `required_flags: Array[String]`, `authored: bool` (true = pre-authored, false = dynamic — but dynamic is OUT OF SCOPE per Pillar 2 decision) | DestinyBranchJudge (beat 7 evaluation) | ScenarioRunner (consumes in BRANCH_JUDGMENT), Story Event (beat 8 revelation content) | discrete |
| `destiny_state_flag_set` | `String, bool` | `flag_key: String`, `value: bool` | DestinyStateStore (flag write) | Save/Load, Scenario Progression (beat 2 echo content reads via `destiny_state.has_flag`, but on-change events go through bus for telemetry/UI) | discrete |
| `destiny_state_echo_added` | `EchoMark` (Resource) `[PROVISIONAL — shares shape with scenario_beat_retried; locked by Destiny State GDD #16]` | Same as `scenario_beat_retried` payload. | DestinyStateStore (retry consequence accumulation) | Story Event (Beat 2 Prior-State Echo content references echo marks), Save/Load | discrete |

> **Pillar 2 note**: The pre-authored-divergence decision means `destiny_branch_chosen.authored` is always `true` at MVP. Dynamic branches are not a bus concern at this stage.

#### 6. Story Event / Beat presentation domain (Emitter: BeatConductor)

| Signal | Payload Type | Payload Fields | Emitter | Subscribers (MVP) | Frequency |
|---|---|---|---|---|---|
| `beat_visual_cue_fired` | `BeatCue` (Resource) `[PROVISIONAL — locked by Story Event GDD #10 VS]` | Provisional: `beat_number: int`, `cue_id: String`, `chapter_id: String`, `duration_ms: int` | BeatConductor (triggered by ScenarioRunner beat sequence) | Story Event UI (visual channel), VFX | discrete |
| `beat_audio_cue_fired` | `BeatCue` (Resource) `[PROVISIONAL — locked by Story Event GDD #10 VS]` | Same as visual cue. | BeatConductor (triggered by ScenarioRunner beat sequence) | Sound/Music, Story Event UI (captions) | discrete |
| `beat_sequence_complete` | `int` | `beat_number: int` | BeatConductor (beat finished, e.g., beat 1 → beat 2 transition) | ScenarioRunner (next-beat gate), Story Event | discrete |

> **Beat 2 multi-modal note**: Dual-channel emission (`beat_visual_cue_fired` + `beat_audio_cue_fired` as two separate signals rather than one combined payload) is explicit per Pillar Beat 2 multi-modal decision. Visual and audio subscribers are on different systems; splitting the signals lets Sound/Music subscribe to audio-only without coupling to visual.

#### 7. Input domain (Emitter: InputRouter)

| Signal | Payload Type | Payload Fields | Emitter | Subscribers (MVP) | Frequency |
|---|---|---|---|---|---|
| `input_action_fired` | `String, InputContext` (Resource) | `action: String`, `context: InputContext {target_coord: Vector2i, target_unit_id: int, source_device: int}` | InputRouter (after state-machine consume) | Grid Battle, Battle HUD, Tutorial (#27 FV) | input |
| `input_state_changed` | `int, int` | `from: int`, `to: int` | InputRouter (state transition) | Battle HUD, Settings/Options | input |
| `input_mode_changed` | `int` | `mode: int` | InputRouter (KEYBOARD_MOUSE ↔ TOUCH switch) | Battle HUD, Camera | input |

#### 8. UI / Flow domain (Emitter: UIRoot, SceneManager)

| Signal | Payload Type | Payload Fields | Emitter | Subscribers (MVP) | Frequency |
|---|---|---|---|---|---|
| `ui_input_block_requested` | `String` | `reason: String` | Grid Battle (AI turn), BeatConductor (cinematic), SceneManager (loading) | InputRouter | discrete |
| `ui_input_unblock_requested` | `String` | `reason: String` | Same as above (symmetric) | InputRouter | discrete |
| `scene_transition_failed` | `String, String` | `context: String`, `reason: String` | SceneManager (ERROR state entry) | ScenarioRunner (displays retry/abort dialog), Main Menu (logs for telemetry) | discrete |

#### 9. Persistence domain (Emitter: SaveManager)

| Signal | Payload Type | Payload Fields | Emitter | Subscribers (MVP) | Frequency |
|---|---|---|---|---|---|
| `save_checkpoint_requested` | `SaveContext` (Resource) | `source: SaveContext` — ratified by ADR-0003; payload is the live context to snapshot. SaveManager duplicate_deep's it before serialization. Typed-Resource shape per TR-gamebus-001. | ScenarioRunner (Beat 1 entry CP-1, post-battle CP-2 on observing SceneManager's RETURNING_FROM_BATTLE→IDLE boundary via `battle_outcome_resolved`, next-chapter entry CP-3) | SaveManager | discrete |
| `save_persisted` | `int, int` | `chapter_number: int`, `cp: int` | SaveManager (after atomic rename succeeds) | Save Slot UI, HUD toast | discrete |
| `save_load_failed` | `String, String` | `op: String` (one of `"save"`, `"load"`), `reason: String` (machine-readable cause) | SaveManager (on ResourceSaver failure, rename failure, invalid resource, or missing migration step) | Error toast UI, ScenarioRunner (player-facing retry/abort dialog) | discrete |

#### 10. Environment domain (Emitter: MapGrid)

| Signal | Payload Type | Payload Fields | Emitter | Subscribers (MVP) | Frequency |
|---|---|---|---|---|---|
| `tile_destroyed` | `Vector2i` | `coord: Vector2i` — position of the tile that was destroyed. Consumers look up post-destruction state via `MapGrid.get_tile(coord)`. Single-primitive canonical form per TR-gamebus-001 (no wrapping Resource needed since coord is the sole semantically-necessary field). | MapGrid (inside `apply_tile_damage()` when destruction_hp reaches 0) | AI (invalidates cached path), Formation Bonus (re-checks adjacency for formations touching coord), VFX system (plays destruction effect) | discrete (rare — ≤ a few per battle) |

**Total signal count: 27 signals across 10 domains.**

**PROVISIONAL signals: 4** (all payload-shape-provisional; all emitter+name locked):
- `scenario_beat_retried` — shape TBD by Destiny State GDD #16
- `destiny_branch_chosen` — shape TBD by Destiny Branch GDD #4
- `destiny_state_echo_added` — shape TBD by Destiny State GDD #16
- `beat_visual_cue_fired` / `beat_audio_cue_fired` — shape TBD by Story Event GDD #10 (counted as 2 but share one provisional payload class)

**PROVISIONAL → RATIFIED (2026-04-18)**:
- `save_checkpoint_requested` — shape ratified by ADR-0003 as `(source: SaveContext)`.

**MVP systems that are non-emitters by design** (and WHY — so nobody adds bus traffic later without a superseding ADR):
- **Map/Grid (#14)** — query-first spatial service; 9 public queries (`get_tile`, `get_movement_range`, `get_path`, `get_attack_range`, `get_attack_direction`, `get_adjacent_units`, `get_occupied_tiles`, `has_line_of_sight`, `get_map_dimensions`) are direct calls, not events. **Exception (ADR-0004 amendment 2026-04-18):** Map/Grid emits exactly one signal, `tile_destroyed(coord: Vector2i)`, because destruction affects AI path caches and Formation adjacency in systems that are not in the call chain. No other Map/Grid state change should ever become a signal without a superseding ADR.
- **Hero Database (#25)** — read-only data registry. `hero_database.get(unit_id)` is a direct call.
- **Balance/Data (#26)** — read-only config registry. `balance_data.get(...)` is a direct call.
- **Unit Role (#5)**, **Terrain Effect (#2)** — pure data/calculation layers over Hero DB and Map/Grid; no state events.
- **Formation Bonus (#3)**, **Damage Calculation (#11)** — subscribers only; consume `round_started` and per-attack context; do not emit.
- **AI (#8)** — consumes `unit_turn_started`; emits action commands through Grid Battle's command interface (direct method calls on BattleController), not the bus. AI-to-Grid-Battle is in-scene.
- **Destiny Branch Judge itself (#4)** is short-lived (one call per beat 7); emits `destiny_branch_chosen` then returns.

### Evolution Rule

Changes to the Signal Contract Schema are contract changes. They require:

1. **Add a new signal** — minor amendment. Edit this ADR (keep Status: Accepted), add the signal to the Schema with full row, add a dated changelog line at the bottom. Add the declaration to `src/core/game_bus.gd`. Update `signal_contract_test.gd`. No supersession needed.
2. **Rename an existing signal** — breaking change. Author ADR-000N superseding this one for the rename. Keep the old signal as a forwarder in `game_bus.gd` for ONE release cycle, emitting `push_warning("signal X renamed to Y; update subscribers")` on every use. Remove the shim in the release after.
3. **Change a payload shape** — breaking change for non-PROVISIONAL signals. Same as rename: supersede with new ADR, one-release deprecation shim.
4. **Lock a PROVISIONAL signal** — minor amendment. When the downstream GDD (Destiny State, Save/Load, Destiny Branch, Story Event) ratifies the payload shape, edit this ADR, remove the `PROVISIONAL` marker, fill in the final shape. No supersession — PROVISIONAL is explicitly a "to be filled in" marker, not a contract change.
5. **Remove a signal** — breaking change. Supersede with new ADR; deprecation shim cycle.

## Alternatives Considered

### Alternative 1: Per-domain signal buses (multiple autoloads)

- **Description**: Separate autoloads per domain — `BattleBus`, `ScenarioBus`, `InputBus`, `DestinyBus` — each owning its own signals.
- **Pros**: Domain isolation — changes to `BattleBus` cannot cascade to `InputBus` subscribers. Smaller files. Easier to mock one domain in tests.
- **Cons**: Grepping for "which system emits X?" requires knowing the domain first. Cross-domain signals (e.g., `battle_outcome_resolved` is consumed by Scenario Progression, which is a different domain) create ambiguous ownership. More autoload entries = more boot-order sensitivity. Scenario Progression's downstream-interfaces section would have to reference 4 different buses.
- **Estimated Effort**: Similar to chosen approach, slightly more boilerplate.
- **Rejection Reason**: Scenario Progression GDD v1.0 already expects "GameBus" (singular) as the pattern. Splitting now would contradict the ratified name. The indie project scale (14 MVP systems, ~23 signals) does not justify four autoloads. Domain isolation is better served by banner comments within one file — grep `signal battle_` is as effective as a separate bus and preserves the "one file to check" property.

### Alternative 2: Signal relaying via parent-node signal chains (no autoload)

- **Description**: Each scene's root node declares and re-emits signals from children. Battle-scene root emits `battle_outcome_resolved`; SceneManager listens, passes to overworld-scene root, which passes to ScenarioRunner.
- **Pros**: No global state. Pure tree-local wiring, Godot-idiomatic at small scale.
- **Cons**: Every hop is a manual re-emit. Cross-scene signal requires SceneManager to exist as an intermediary — creates the exact coupling problem we are trying to solve. Scene destruction during transition creates dangling connections mid-chain. Impossible to grep the full signal contract — it is scattered across every scene root.
- **Estimated Effort**: 3-4x more boilerplate per signal (emit, re-emit, re-emit, handle).
- **Rejection Reason**: Breaks the grep-ability requirement. Breaks the scene-boundary-survival requirement. Godot's autoload pattern exists precisely for this case.

### Alternative 3: EventBus library (third-party addon, e.g., `godot-events`)

- **Description**: Adopt an existing Godot addon providing a typed event bus with subscribe/unsubscribe helpers, `once()` / `off()` semantics.
- **Pros**: Battle-tested. Some addons offer priority-queue semantics, namespacing, event replay.
- **Cons**: Adds a third-party dependency not on the approved list (see `technical-preferences.md` §Allowed Libraries — currently empty). Addon versioning risk. Feature set exceeds MVP needs (priorities, replay, namespacing are YAGNI for 23 signals). Obscures the contract behind library API.
- **Estimated Effort**: Lower upfront (import addon), higher long-term (dependency maintenance).
- **Rejection Reason**: MVP scale does not justify adding an approved-library line item. A 60-line GDScript autoload is trivially maintainable. Reversibility is higher with first-party code.

### Alternative 4: Direct node references via get_tree().get_root().get_node(...)

- **Description**: Each system holds a cached reference to the other, acquired via path lookup. No bus.
- **Pros**: Zero indirection. Fastest possible dispatch.
- **Cons**: Scene destruction invalidates cached references silently. Cross-scene calls require both scenes to be loaded simultaneously (they are not). Creates a hard-coded scene-tree topology — moving a node breaks every reference. Untestable (cannot stub the node path in GdUnit4 without mutating the tree).
- **Estimated Effort**: Lowest upfront, catastrophic long-term debt.
- **Rejection Reason**: Violates scene-reload-safety requirement outright. This is the anti-pattern this ADR is designed to prevent.

## Consequences

### Positive

- **Single source of truth for cross-system events** — one `src/core/game_bus.gd` file, grep-able, diff-visible in PRs.
- **Scene-reload-safe** — autoload persists across scene changes; `is_instance_valid` + `_exit_tree` discipline prevents the "freed payload" edge case (Scenario Progression EC-SP-5 handles the duplicate-emission corner).
- **Testable** — GameBus stub injectable via autoload tree manipulation in `before_test`; Scenario Progression unit tests can assert signal contracts without spinning up Grid Battle.
- **Save/Load-ready** — all typed payloads are `Resource` classes, serializable by construction. Save/Load #17 inherits this contract at zero design cost.
- **Performance-predictable** — no per-frame traffic allowed; signal dispatch is Godot's native path (C++ implementation, zero allocation for the relay itself).
- **Contract locked early** — Scenario Progression GDD v2.0 can cite this ADR's Signal Contract Schema verbatim, unblocking implementation.

### Negative

- **Global surface area** — GameBus is visible from every script. Discipline required to prevent it from accreting state or becoming a grab-bag. Mitigation: this ADR forbids state; code review enforces it.
- **Boot-order sensitivity** — GameBus must load first among autoloads. A programmer who reorders autoloads without understanding will get null-reference crashes in other autoloads' `_ready`. Mitigation: comment in `project.godot` explaining the constraint; `/start` skill will document it.
- **Signal churn friction** — adding a new cross-system signal requires (1) update this ADR, (2) update GameBus declaration, (3) define payload Resource if needed, (4) update subscribers. For genuinely cross-system events this is the right friction. For in-scene events it is wasteful — programmers must correctly identify which is which. Mitigation: Implementation Guidelines §Forbidden emission contexts list; code review rejects in-scene events routed through the bus.
- **Payload Resource proliferation** — `src/core/payloads/` will contain ~15 small Resource classes by vertical-slice. Each is a file. Mitigation: acceptable cost; the alternative (untyped Dictionaries) is strictly worse for typing, Save/Load, and IDE support.

### Neutral

- **26 signals is the current MVP-scoped total** — 23 at original ADR (2026-04-18), +1 from ADR-0002 (scene_transition_failed), +2 from ADR-0003 (save_persisted, save_load_failed). Vertical Slice and Alpha will add more (Character Growth, Equipment, Camera); re-validate total against 50-emits/frame cap quarterly.
- **Name change**: `battle_complete` → `battle_outcome_resolved`. Scenario Progression GDD v2.0 and Grid Battle GDD must update their signal references (bidirectional update, producer-coordinated).
- **One-release deprecation shim policy** — any future signal rename keeps the old name as a forwarder for one release cycle, emitting `push_warning` on use. Removal requires a superseding ADR.

## Risks

| Risk | Probability | Impact | Mitigation |
|---|---|---|---|
| Programmers add game state to GameBus ("just a counter") | MEDIUM | HIGH — defeats the pure-relay contract | Linter rule (GDScript static analysis) disallowing non-signal declarations in `game_bus.gd`; code review. |
| Programmers emit per-frame events through bus | MEDIUM | HIGH — violates 16.6 ms budget | `GameBusDiagnostics` debug-only emit counter with 50/frame soft cap; `push_warning` on exceed; performance-analyst agent reviews pre-milestone. |
| Cross-scene payload holds a freed Node reference | MEDIUM | MEDIUM — crash on access | Payload Resources hold primitive fields only (IDs, not Node refs). `is_instance_valid` guards in handlers. Documented anti-pattern in implementation guide. |
| Autoload boot order changes break GameBus initialization | LOW | HIGH — crashes entire game | `project.godot` comment + pre-commit hook validates GameBus is first. |
| Signal-contract drift between ADR and GameBus code | MEDIUM | MEDIUM — stale ADR | Automated test `signal_contract_test.gd` that reads this ADR's table and asserts every listed signal exists on GameBus with matching signature. Run in CI. |
| Provisional payload shape changes late, breaking subscribers | HIGH | MEDIUM — downstream GDDs lock shapes | This ADR marks 5 signals PROVISIONAL with named dependency. Downstream GDD authoring triggers supersession of this ADR, not silent edit. |
| Godot 4.6 typed-signal strictness regresses | LOW | MEDIUM — payload type mismatches | Engine Compatibility §Verification Required includes explicit test; re-validate on any Godot patch. |

## Performance Implications

GameBus adds negligible direct overhead; the performance contract is about what it FORBIDS (per-frame traffic).

| Metric | Before | Expected After | Budget |
|---|---|---|---|
| CPU (frame time, bus dispatch only) | 0 ms (no bus) | <0.05 ms / emit on mid-range Android | <0.5 ms total per frame (1/30th of 16.6 ms budget) |
| Memory (bus + payloads resident) | 0 MB | ~0.05 MB (GameBus node + signal tables) | Mobile ceiling 512 MB; bus-attributable < 1 MB always |
| Load Time (autoload init) | N/A | <1 ms at boot (signal declaration only) | <50 ms autoload total |
| Network | N/A | N/A (local relay only) | N/A |

**Per-emission cost breakdown** (on Snapdragon 7-gen target):
- `signal.emit(payload)` with deferred connection: ~0.02 ms (Godot native path)
- Subscriber handler execution: owned by subscriber, not bus
- Payload construction: owned by emitter, measured separately

**Soft cap enforcement**: 50 emits/frame × 0.05 ms = 2.5 ms worst-case bus overhead. At target load (~10-15 emits/frame during combat peak), bus overhead is < 1 ms.

## Migration Plan

This is a foundational ADR with no legacy code to migrate. The rollout is:

1. **Create `src/core/game_bus.gd`** with signal declarations per this ADR's Schema. Register in `project.godot`. Verify autoload instantiates at boot. Verify: `get_tree().get_root().get_node("/root/GameBus")` returns a valid Node in an empty scene.
2. **Create `src/core/payloads/` directory** with `Resource` classes for all non-provisional payloads (`BattleOutcome`, `BattlePayload`, `ChapterResult`, `InputContext`). Ship unit tests confirming each serializes via ResourceSaver → ResourceLoader with identical data.
3. **Update Scenario Progression GDD** (v2.0 pass — coordinated by producer, authored by narrative-director; not this ADR's scope) to cite this ADR and rename `battle_complete` → `battle_outcome_resolved`.
4. **Update Grid Battle GDD** (v5.0 pass — coordinated by producer; not this ADR's scope) to rename `battle_complete` → `battle_outcome_resolved` and confirm payload shape matches `BattleOutcome` Resource.
5. **Implement `signal_contract_test.gd`** in CI — parses this ADR's schema table and asserts GameBus declares every listed signal with matching typed signature. Blocks merges on drift.
6. **Create `tests/unit/core/README.md`** documenting the GameBus stub pattern for GdUnit4.
7. **First consumer: Scenario Progression implementation** — begins only after GameBus is Accepted. Scenario Progression stories cite this ADR + listed TR-IDs.

**Rollback plan**: If this ADR proves wrong within the first vertical-slice implementation, supersede with ADR-0002 (e.g., adopting multi-bus or third-party library). Rollback cost is LOW at this stage — only `src/core/game_bus.gd` and payload Resources exist. MEDIUM if Scenario Progression has shipped production code using the bus; HIGH after more than 3 MVP systems integrate. This is why we ratify now, before any gameplay implementation.

## Validation Criteria

- [ ] **V-1**: `/root/GameBus` is loadable as an autoload in a minimal Godot 4.6 project without errors.
- [ ] **V-2**: `signal_contract_test.gd` passes — every signal in the Schema is declared with matching typed signature on GameBus.
- [ ] **V-3**: Every payload Resource class round-trips via `ResourceSaver.save` → `ResourceLoader.load` with byte-identical data (`payload_serialization_test.gd`).
- [ ] **V-4**: A cross-scene emit test passes — `BattleController` (in battle scene) emits `battle_outcome_resolved`; `ScenarioRunner` (in overworld scene) receives it after battle scene is freed. Freed-battle-scene test asserts no dangling reference errors.
- [ ] **V-5**: `GameBusDiagnostics` emit counter logs `push_warning` when >50 emits occur in one frame (tested with synthetic burst).
- [ ] **V-6**: GdUnit4 double pattern works — test file swaps GameBus in `before_test`, restores in `after_test`, both pre and post state confirmed.
- [ ] **V-7**: Per-frame forbidden check — code search for `GameBus\..*\.emit` inside `_process` or `_physics_process` returns zero matches (CI lint).
- [ ] **V-8**: Frame-time profile on target Android device (Snapdragon 7-gen) during combat peak shows <0.5 ms attributable to GameBus dispatch.
- [ ] **V-9**: No production script declares `var` or `func` in `game_bus.gd` beyond signal declarations and doc comments (CI lint asserting pure-relay).
- [ ] **V-10**: Scenario Progression implementation milestone successfully integrates GameBus for `battle_outcome_resolved` round-trip with Grid Battle (vertical-slice exit criterion).

## GDD Requirements Addressed

| GDD Document | System | Requirement | How This ADR Satisfies It |
|---|---|---|---|
| `design/gdd/scenario-progression.md` | Scenario Progression (#6 MVP) | OQ-SP-01: "Author ADR for GameBus before Scenario Progression implementation begins, to ratify the pattern for all future cross-scene signal flows." | This ADR ratifies the pattern with a full signal-contract schema, unblocking Scenario Progression implementation. |
| `design/gdd/scenario-progression.md` | Scenario Progression (#6 MVP) | §Dependencies: five downstream signals documented (`chapter_started`, `battle_prepare_requested`, `battle_launch_requested`, `chapter_completed`, `scenario_complete`) without relay mechanism. | All five signals are declared on GameBus with payload types; Scenario Progression is the emitter. |
| `design/gdd/scenario-progression.md` | Scenario Progression (#6 MVP) | EC-SP-5: "`battle_complete` signal fires twice — ScenarioRunner maintains a guard, ignoring duplicate." | ADR names the signal `battle_outcome_resolved` with single-emission contract from Grid Battle CLEANUP. Subscriber-side guard pattern is codified in Implementation Guidelines §Lifecycle discipline. |
| `design/gdd/grid-battle.md` | Grid Battle (#1 MVP) | §CLEANUP: "Emit `battle_complete(outcome)` to caller." §Dependencies: "Scenario Progression — Grid Battle reports back via `battle_complete(outcome_data)` relayed through GameBus autoload." | Signal renamed to `battle_outcome_resolved` with typed `BattleOutcome` Resource payload. Relay mechanism ratified. |
| `design/gdd/turn-order.md` | Turn Order (#13 MVP) | §Dependencies Contract 4: signals `round_started`, `unit_turn_started`, `unit_turn_ended`, `battle_ended`. | First three declared on GameBus in Turn Order domain. `battle_ended` supplanted by Grid Battle's `battle_outcome_resolved` (single-owner rule) — Turn Order GDD v-next should reference this ADR to reflect change. |
| `design/gdd/hp-status.md` | HP/Status (#12 MVP) | `unit_died` signal consumed by Turn Order and Grid Battle. | Declared on GameBus, typed `int unit_id`. |
| `design/gdd/input-handling.md` | Input Handling (#29 MVP) | §Integration contract: `input_action_fired`, `input_state_changed`, `input_mode_changed`. | All three declared on GameBus in Input domain with typed payloads. |
| `design/gdd/terrain-effect.md` | Terrain Effect (#2 MVP) | OQ-5: "Bridge FLANK override — wrapper vs signal vs internal — architecture decision." | This ADR does not decide OQ-5 (belongs in terrain's own ADR). However, if OQ-5 resolves to "signal", it must be declared on GameBus per this contract — no ad-hoc signals outside the bus. |

> Pillar-alignment decisions (pre-authored divergence, Echo retry consequence, DRAW tri-state, Beat 2 multi-modal, Save/Load serializability) are addressed throughout §Signal Contract Schema — see inline notes in Domains 1, 2, 5, 6.

## TR Registry

Registered in `docs/architecture/tr-registry.yaml` on 2026-04-18 by `/architecture-review`:

- `TR-gamebus-001` — All cross-system signals must be declared on the GameBus autoload at `/root/GameBus`. Per-frame events are forbidden. Payloads with ≥2 fields must be typed Resource classes.

Additional TRs registered from GDDs this ADR addresses: `TR-scenario-progression-001/002/003`, `TR-grid-battle-001`, `TR-turn-order-001`, `TR-hp-status-001`, `TR-input-handling-001`.

## Related

- **Scenario Progression GDD** (`design/gdd/scenario-progression.md`) — primary consumer; must be updated to v2.0 with ADR citation (not this ADR's scope — producer-coordinated cascade).
- **Grid Battle GDD** (`design/gdd/grid-battle.md`) — signal rename `battle_complete` → `battle_outcome_resolved` propagates to v5.0 revision (not this ADR's scope — producer-coordinated cascade).
- **Turn Order GDD** (`design/gdd/turn-order.md`) — `battle_ended` ownership change, ADR citation on v-next revision.
- **ADR-0002 (Scene Manager)** — `docs/architecture/ADR-0002-scene-manager.md` (Accepted 2026-04-18). Depends on this ADR for `battle_launch_requested`, `battle_outcome_resolved`, `ui_input_block_requested`, `ui_input_unblock_requested`, and the amended `scene_transition_failed` signal.
- **ADR-0003 (Save/Load)** — `docs/architecture/ADR-0003-save-load.md` (Accepted 2026-04-18). Depends on this ADR for the Persistence domain (`save_checkpoint_requested`, `save_persisted`, `save_load_failed`). Also ratifies the previously-provisional `save_checkpoint_requested` payload shape as `(source: SaveContext)`.
- **Code (once implemented)**: `src/core/game_bus.gd`, `src/core/payloads/*.gd`, `tests/unit/core/signal_contract_test.gd`, `tests/unit/core/payload_serialization_test.gd`.

---

## Changelog

| Date | Change | Author |
|---|---|---|
| 2026-04-18 | Initial ADR drafted (Proposed). 23 signals across 8 domains; 5 provisional. | technical-director |
| 2026-04-18 | Status flipped Proposed → Accepted via `/architecture-review`. Fixed `duplicate_deep()` version attribution (4.6 → 4.5). Registered TR-gamebus-001 + 7 derived TRs in tr-registry.yaml. | /architecture-review |
| 2026-04-18 | Minor amendment (§Evolution Rule #1): added `scene_transition_failed(context: String, reason: String)` to UI/Flow domain. Signal count 23 → 24. Required by ADR-0002 SceneManager ERROR-state contract. No supersession. | /architecture-decision (ADR-0002) |
| 2026-04-18 | Minor amendment (§Evolution Rule #1 + #4): added Persistence domain (#9). Ratified provisional `save_checkpoint_requested` as `(source: SaveContext)`. Added `save_persisted(int, int)` and `save_load_failed(String, String)`. Signal count 24 → 26. Provisional count 5 → 4. Required by ADR-0003 SaveManager contract. No supersession. | /architecture-decision (ADR-0003) |
| 2026-04-18 | Minor amendment (§Evolution Rule #1): added Environment domain (#10) with `tile_destroyed(coord: Vector2i)`. Map/Grid moves from pure non-emitter to sole emitter of this signal (documented exception in non-emitters list). Signal count 26 → 27. Domain count 9 → 10. Code-block banner count 7 → 8. Single-primitive payload per TR-gamebus-001 canonical form (1-field primitive; no wrapping Resource). Required by ADR-0004 Map/Grid data model. No supersession. | /architecture-decision (ADR-0004) |
