# Epic: GameBus Signal Relay

> **Layer**: Platform
> **GDD**: — (infrastructure; authoritative spec is ADR-0001)
> **Architecture Module**: GameBus (docs/architecture/architecture.md §Platform layer)
> **Status**: Ready
> **Manifest Version**: 2026-04-20
> **Stories**: 9 created (2026-04-20; +Story 000 bootstrap added post-review) — see Stories table below

## Overview

GameBus is the single autoload signal-relay surface at `/root/GameBus` that owns every cross-system, cross-scene event in 천명역전. It declares 27 signals across 10 domains (scenario, battle, turn, unit, destiny, beat, input, ui, save, environment) as the sole grep-able contract every MVP system must use for cross-scene communication. GameBus holds zero game state — it is a pure signal relay with typed Resource payloads for ≥2-field signals and typed primitives for 1-field single-primitive signals. All subscribers use `CONNECT_DEFERRED` with explicit `_exit_tree` disconnects and `is_instance_valid` guards. Per-frame emissions are forbidden; a 50-emit/frame soft cap is enforced by debug-only diagnostics.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0001: GameBus Autoload — Cross-System Signal Relay | Single `/root/GameBus` autoload; 27 typed signals in 10 domains; zero game state; CONNECT_DEFERRED mandatory; @export-typed Resource payloads round-trippable via ResourceSaver/Loader | LOW (core signal API stable since 4.0; typed-signal strictness tightened 4.5 — no regression for this use) |

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-gamebus-001 | All cross-system signals on `/root/GameBus`; per-frame forbidden; payloads ≥2 fields = typed Resource | ADR-0001 ✅ |
| TR-scenario-progression-001 | GameBus signal relay pattern ratified before Scenario impl (OQ-SP-01) | ADR-0001 ✅ |
| TR-scenario-progression-002 | 5 outbound signals cross scene boundaries | ADR-0001 ✅ |
| TR-scenario-progression-003 | EC-SP-5 duplicate battle-complete guard | ADR-0001 ✅ |
| TR-grid-battle-001 | Tri-state `{WIN, DRAW, LOSS}` `BattleOutcome` signal | ADR-0001 ✅ |
| TR-turn-order-001 | round_started / unit_turn_started / unit_turn_ended owned by Turn Order; battle_ended ownership moved to Grid Battle | ADR-0001 ✅ |
| TR-hp-status-001 | `unit_died` signal ownership | ADR-0001 ✅ |
| TR-input-handling-001 | input_action_fired / input_state_changed / input_mode_changed exposed | ADR-0001 ✅ |

**Untraced Requirements**: None.

## Scope

**Implements**:
- `project.godot` — Godot 4.6 project bootstrap (rendering method, physics engine, empty autoload block) + `addons/gdUnit4/` test harness install + `src/` subdirectory scaffolding (Story 000, prerequisite for all subsequent `.gd` authoring across every epic)
- `src/core/game_bus.gd` — autoload declaring 27 signals in 10 banner-comment domains
- `src/core/payloads/` — typed Resource classes for multi-field payloads (`BattleOutcome`, `BattlePayload`, `ChapterResult`, `InputContext`, `SaveContext`, `EchoMark`, `DestinyBranchChoice`, `BeatCue`, `VictoryConditions`, `BattleStartEffect`)
- `project.godot` — autoload registration (`GameBus` as load order 1, before any system that subscribes in `_ready`)
- `tests/unit/core/signal_contract_test.gd` — parses ADR-0001's §Signal Contract Schema table and asserts GameBus declares every listed signal with matching typed signature
- `tests/unit/core/payload_serialization_test.gd` — ResourceSaver → ResourceLoader round-trip for every payload Resource
- `tests/unit/core/game_bus_stub.gd` — GdUnit4 swap pattern (`before_test` / `after_test`)
- `GameBusDiagnostics` debug-only emit counter with 50/frame soft cap + `push_warning` on exceed

**Does not implement**: any consumer-side signal wiring (belongs to each consuming system's epic); the 4 PROVISIONAL payload shapes (ratified by their owning ADRs when written — Destiny State #16, Destiny Branch #4, Story Event #10).

## Provisional Payload Signals (carried)

These signals have locked names + emitters but payload shapes owned by downstream GDDs/ADRs not yet written:

| Signal | Owner | Resolution Trigger |
|--------|-------|-------------------|
| `scenario_beat_retried(EchoMark)` | Destiny State GDD #16 | Destiny State ADR |
| `destiny_branch_chosen(DestinyBranchChoice)` | Destiny Branch GDD #4 | Destiny Branch ADR |
| `destiny_state_echo_added(EchoMark)` | Destiny State GDD #16 | Destiny State ADR |
| `beat_visual_cue_fired(BeatCue)` / `beat_audio_cue_fired(BeatCue)` | Story Event GDD #10 | Story Event ADR |

When each downstream ADR locks the payload shape, ADR-0001 is amended per its §Evolution Rule #4 (no supersession needed).

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria embedded in stories (derived from ADR-0001 V-1..V-10) are verified
- `tests/unit/core/signal_contract_test.gd` passes on CI
- `tests/unit/core/payload_serialization_test.gd` passes on CI (all non-provisional payloads)
- CI lint confirms zero `GameBus\..*\.emit` inside `_process` or `_physics_process` (V-7)
- CI lint confirms `game_bus.gd` contains only `signal` declarations + doc comments + banner comments (V-9)
- Cross-scene emit integration test passes (V-4): BattleController emits, ScenarioRunner receives after battle scene freed
- Frame-time profile on target Android shows <0.5 ms bus dispatch attribution (V-8)

## Stories

| # | Story | Type | Status | ADR | Validation |
|---|-------|------|--------|-----|------------|
| 000 | Godot 4.6 project + GdUnit4 test harness bootstrap | Config/Data | Ready | ADR-0001..0004 | Prerequisite: `.gd` parse + test runner |
| 001 | Non-provisional payload Resource classes | Logic | Ready | ADR-0001 | TR-gamebus-001 §3 |
| 002 | GameBus autoload declaration + registration | Logic | Ready | ADR-0001 | V-1, V-9 |
| 003 | signal_contract_test — ADR table → code drift gate | Integration | Ready | ADR-0001 | V-2 |
| 004 | payload_serialization_test — ResourceSaver round-trip | Integration | Ready | ADR-0001 | V-3 |
| 005 | GameBusDiagnostics — debug-only 50-emit/frame soft cap | Logic | Ready | ADR-0001 | V-5 |
| 006 | GameBus stub pattern for GdUnit4 | Integration | Ready | ADR-0001 | V-6 |
| 007 | Cross-scene emit integration test | Integration | Ready | ADR-0001 | V-4 |
| 008 | CI lint — per-frame emit ban | Config/Data | Ready | ADR-0001 | V-7 |

**Deferred to Polish phase (consumer-system-dependent)**:
- V-8: Frame-time profile on target Android showing <0.5 ms bus dispatch — requires running battle with real consumers
- V-10: Scenario Progression integration milestone — belongs to Scenario Progression epic's Vertical Slice exit criterion

## Implementation Order

1. **Story 000** — project bootstrap (prerequisite for all `.gd` parse + GdUnit4 test runs)
2. **Story 001** — payload classes (foundation for signal signatures)
3. **Story 002** — GameBus autoload (depends on Story 001's class_names)
4. **Stories 003 / 004 / 005 / 006 in parallel** — all test/tooling layered on the autoload
5. **Story 007** — cross-scene integration test (depends on Story 001 + 002; recommended to use Story 006 stub)
6. **Story 008** — CI lint (depends on Story 002 for real GameBus reference)

## Next Step

Run `/story-readiness production/epics/gamebus/story-000-project-bootstrap.md` to validate the bootstrap story, then `/dev-story` to begin implementation.
