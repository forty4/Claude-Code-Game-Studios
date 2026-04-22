# Epic: Scene Manager

> **Layer**: Platform
> **GDD**: — (infrastructure; authoritative spec is ADR-0002; consumer contracts in scenario-progression.md §UI-7 and grid-battle.md §CLEANUP)
> **Architecture Module**: SceneManager (docs/architecture/architecture.md §Platform layer)
> **Status**: Ready
> **Manifest Version**: 2026-04-20
> **Stories**: 7 — see table below

## Overview

SceneManager is the single autoload at `/root/SceneManager` (load order 2, after GameBus) that owns the full Overworld ↔ BattleScene transition lifecycle: async threaded loading via `ResourceLoader.load_threaded_request`, Overworld pause + hide via `PROCESS_MODE_DISABLED` + root Control recursive mouse-filter ignore, BattleScene instantiation as a `/root` peer, outcome-driven teardown via `call_deferred` free one additional frame to preserve co-subscriber refs, and error recovery via `scene_transition_failed` signal. SceneManager is signal-driven — no public imperative transition API — and holds zero gameplay state. Overworld is retained (not freed) during IN_BATTLE to preserve ScenarioRunner state across Echo retry loops (LOSS → BATTLE_PREP), satisfying Pillar 2's pre-authored retry consequence design.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0002: Scene Manager Autoload | 5-state FSM (IDLE / LOADING_BATTLE / IN_BATTLE / RETURNING_FROM_BATTLE / ERROR); async load + Timer-polled status at 100 ms; Overworld retention discipline; call_deferred free; signal-only transitions | MEDIUM (recursive Control disable 4.5+ property name verification; load_threaded Android export verification) |
| ADR-0001: GameBus Autoload | Consumed: `battle_launch_requested`, `battle_outcome_resolved`; Emitted: `ui_input_block_requested`, `ui_input_unblock_requested`, `scene_transition_failed` (minor amendment to ADR-0001) | LOW |

**Highest engine risk**: MEDIUM

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-scene-manager-001 | `/root/SceneManager` autoload, load order 2; 5-state FSM (IDLE, LOADING_BATTLE, IN_BATTLE, RETURNING_FROM_BATTLE, ERROR) | ADR-0002 ✅ |
| TR-scene-manager-002 | Overworld retained via `PROCESS_MODE_DISABLED` + `visible=false` + `set_process_input(false)` + root Control recursive mouse_filter IGNORE | ADR-0002 ✅ |
| TR-scene-manager-003 | BattleScene async via `ResourceLoader.load_threaded_request`; Timer-polled 100 ms; not per-frame | ADR-0002 ✅ |
| TR-scene-manager-004 | On `battle_outcome_resolved`, `call_deferred("_free_battle_scene_and_restore_overworld")` — defers free one frame to preserve co-subscriber refs | ADR-0002 ✅ |
| TR-scene-manager-005 | On async-load failure, emit `scene_transition_failed(context, reason)` via GameBus + ERROR state; recovery only via re-emit of `battle_launch_requested` | ADR-0002 ✅ |

**Untraced Requirements**: None.

## Scope

**Implements**:
- `src/core/scene_manager.gd` — autoload with 5-state FSM, signal handlers, private Timer for load polling
- `project.godot` — autoload registration at load order 2 with order-sensitive comment
- `tests/unit/core/scene_manager_test.gd` — state-machine transitions, CONNECT_DEFERRED ordering with co-subscriber stub, `load_threaded_*` happy/failure paths via mock ResourceLoader, Overworld pause/restore discipline
- `tests/integration/core/scene_handoff_timing_test.gd` — loads actual BattleScene PackedScene on target export; asserts 1-frame defer keeps co-subscriber refs valid
- `tests/integration/core/scene_manager_retry_test.gd` — LOSS → BATTLE_PREP → LOADING_BATTLE retry loop preserves Overworld state (replicates Scenario Progression F-SP-3 Echo retry flow)

**Does not implement**:
- Actual BattleScene content — belongs to Grid Battle + downstream system epics
- ScenarioRunner — belongs to Scenario Progression epic (Feature layer, not this epic)
- Recursive Control disable exact property verification — deferred-decision item (carried in control-manifest.md "Implementation Decisions Deferred")

## Dependencies

**Depends on (must be Accepted before stories can start)**:
- ADR-0001 (GameBus) ✅ Accepted 2026-04-18 — SceneManager subscribes to `battle_launch_requested` + `battle_outcome_resolved`; emits `scene_transition_failed` + block/unblock signals

**Enables**:
- Scenario Progression implementation (#6 MVP — UI-7 contract ratified)
- Grid Battle implementation (#1 MVP — CLEANUP teardown contract ratified)
- Save/Load implementation (#17 Core — CP-2 timing boundary = RETURNING_FROM_BATTLE → IDLE)

## Implementation Decisions Deferred (from control-manifest)

- **Recursive Control disable exact property name on Godot 4.6** — 4.5+ feature; exact property for mouse_filter propagation not fully specified in engine-reference. Resolution: godot-specialist pre-implementation. Fallback: per-Control `set_mouse_filter(MOUSE_FILTER_IGNORE)` walk.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria embedded in stories (derived from ADR-0002 V-1..V-12) are verified
- State-machine unit tests pass (V-2)
- Async load happy path + failure path integration tests pass on target Android export (V-3, V-4)
- CONNECT_DEFERRED co-subscriber-safe ordering verified on target device (V-5)
- Overworld pause discipline verified — `_process` / `_physics_process` / `_input` suppressed on Overworld subtree when LOADING_BATTLE or IN_BATTLE (V-6)
- Recursive Control disable verified on target Android export OR fallback walk activated (V-7)
- Memory profile ≤250 MB resident during IN_BATTLE with Overworld retained (V-8)
- `scene_transition_failed` declared on GameBus per amendment (V-9)
- SceneManager stub injectable via `before_test`/`after_test` matching GameBus stub pattern (V-10)
- Retry loop integration test passes (V-11)
- `loading_progress: float` property readable by UI without bus subscription (V-12)

## Stories

| # | Story | Type | Status | ADR | Covers |
|---|-------|------|--------|-----|--------|
| 001 | SceneManager autoload + 5-state FSM skeleton | Logic | Complete | ADR-0002 | TR-001, V-1, V-2 |
| 002 | SceneManager stub for GdUnit4 test isolation | Integration | Complete | ADR-0002 | V-10 |
| 003 | Overworld pause/restore discipline | Logic | Complete | ADR-0002 | TR-002, V-6 |
| 004 | Async threaded BattleScene loading + progress | Integration | Complete | ADR-0002 | TR-003, V-3, V-4 partial, V-12 |
| 005 | Outcome-driven teardown + co-subscriber-safe free | Integration | Complete | ADR-0002 | TR-004, V-5 |
| 006 | Error recovery + retry loop | Integration | Complete | ADR-0002 | TR-005, V-4 full, V-11 |
| 007 | Target-device verification (Android recursive Control disable + memory profile) | Integration | Ready | ADR-0002 | V-7, V-8 |

**Dependency chain**: 001 → 002 (stub) → 003 (pause) → 004 (load) → 005 (teardown) → 006 (error/retry) → 007 (target-device)

## Next Step

Run `/story-readiness production/epics/scene-manager/story-001-autoload-fsm-skeleton.md` to validate the first story, then `/dev-story` to implement.
