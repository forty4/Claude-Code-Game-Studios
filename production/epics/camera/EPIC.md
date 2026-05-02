# Epic: Camera (BattleCamera)

> **Layer**: Feature
> **GDD**: cross-system contract from `design/gdd/input-handling.md` §9 + `design/gdd/map-grid.md` (no dedicated Camera GDD — system is small enough that ADR-0013 is the source-of-truth)
> **Architecture Module**: `BattleCamera` — battle-scoped Node at `BattleScene/BattleCamera`
> **Status**: **Complete** (2026-05-02 — sprint-4 S4-02 epic-terminal commit)
> **Stories**: 7/7 Complete
> **Created**: 2026-05-02

## Stories

| # | Story | Type | Status | TR-IDs | ACs | Estimate |
|---|-------|------|--------|--------|-----|----------|
| [001](story-001-class-skeleton-and-di.md) | BattleCamera class + DI setup() + _ready() + _exit_tree() | Logic | Complete | (ADR-0013 §1, §5) | DI assertion + class_name verified | 1h |
| [002](story-002-screen-to-grid.md) | screen_to_grid implementation + 3-zoom invariance test | Logic | Complete | (ADR-0013 §4) | sentinel + valid coord + 3-zoom inv | 1h |
| [003](story-003-zoom-with-cursor-stable.md) | _apply_zoom_delta cursor-stable recipe + range clamp [0.70, 2.00] | Logic | Complete | (ADR-0013 §2) | floor + ceiling + step + cursor-stable | 1h |
| [004](story-004-pan-with-camera-owns-drag.md) | _handle_camera_pan + _drag_active anchor pattern + edge clamp | Logic | Complete | (ADR-0013 §3 + ADR-0005 OQ-2) | drag-start anchor + clamp at edges | 1h |
| [005](story-005-gamebus-subscription-and-disconnect.md) | GameBus.input_action_fired CONNECT_DEFERRED + _exit_tree disconnect | Integration | Complete | (ADR-0013 §5 + R-6) | live subscription + _exit_tree disconnect verified | 1h |
| [006](story-006-balance-constants-additions.md) | 6 BalanceConstants entries + key-presence lint | Config/Data | Complete | (ADR-0013 §2) | TILE_WORLD_SIZE + TOUCH_TARGET_MIN_PX + 4 CAMERA_* | 0.5h |
| [007](story-007-epic-terminal-lints-and-ci.md) | 4 forbidden_pattern lint scripts + CI wiring + epic terminal | Config/Data | Complete | (ADR-0013 §11) | 5 lint scripts + CI 5 new steps + epic close | 0.5h |

**Total estimate**: 6h actual (within sprint-4 S4-02 budget of 1.5d = 12h).
**Implementation order**: 001 → 002/003/004/005 (parallel) → 006 → 007 epic-terminal.

## Overview

The Camera epic implements `BattleCamera` — the Feature-layer battle-scoped Node providing zoom (range 0.70-2.00), drag-to-pan, mouse-wheel zoom, and `screen_to_grid()` coordinate conversion. **3rd invocation of the battle-scoped Node pattern** (after ADR-0010 HPStatusController + ADR-0011 TurnOrderRunner).

This is the **first Feature-layer Node-based system**. Sole consumer of the `BattleCamera.screen_to_grid` cross-system contract is `GridBattleController` (ADR-0014 — sprint-5 epic implementation). Battle HUD (sprint-5 ADR pending) consumes `get_zoom_value()` for HUD scale-matching.

## Pattern Boundary Precedent

BattleCamera extends the established **2-precedent battle-scoped Node lineage** (ADR-0010 + ADR-0011) to **3 invocations**. Distinct from ADR-0005 InputRouter's autoload-Node form — Camera state is battle-bounded (overworld + main menu have no Camera consumer; battle-scene-end frees the Camera with the rest of BattleScene).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| **ADR-0013 Camera** (Accepted 2026-05-02) | `BattleCamera` (NOT `Camera` per G-12 ClassDB collision) extends Camera2D; 4 instance fields (`_map_grid`, `_drag_active`, `_drag_start_screen_pos`, `_drag_start_camera_pos`); zoom range [0.70, 2.00] + cursor-stable recipe + edge-clamp via MapGrid.get_map_dimensions; `screen_to_grid` sentinel `Vector2i(-1,-1)` for off-grid; MANDATORY `_exit_tree()` autoload-disconnect cleanup (godot-specialist concern #2). | **LOW** — Camera2D pre-cutoff stable; no post-cutoff APIs; engine risk LOW |
| ADR-0001 GameBus | BattleCamera subscribes to `input_action_fired(action: String, ctx: InputContext)` filtered for camera-domain actions via `Object.CONNECT_DEFERRED`; non-emitter | LOW |
| ADR-0004 MapGrid | DI dependency; BattleCamera consumes `get_map_dimensions() -> Vector2i` for pan-clamp world-extent | LOW |
| ADR-0005 Input Handling | OQ-2 resolution: Camera owns drag state; `&"camera_pan"` action is a TRIGGER, not delta source; `screen_to_grid` Bidirectional Contract from §9 | HIGH (governing ADR-0005); inherited LOW for camera consumer surface |
| ADR-0006 BalanceConstants | 6 new entries: `TILE_WORLD_SIZE` + `TOUCH_TARGET_MIN_PX` + `CAMERA_ZOOM_MIN/MAX/DEFAULT/STEP` | LOW |

**Highest Engine Risk among governing ADRs**: LOW for the BattleCamera-direct surface; ADR-0005 HIGH for upstream InputRouter (deferred — does not block Camera epic).

## Same-Patch Obligations from ADR-0013 Acceptance

1. **6 BalanceConstants additions** to `assets/data/balance/balance_entities.json`: `TILE_WORLD_SIZE=64`, `TOUCH_TARGET_MIN_PX=44`, `CAMERA_ZOOM_MIN=0.70`, `CAMERA_ZOOM_MAX=2.00`, `CAMERA_ZOOM_DEFAULT=1.00`, `CAMERA_ZOOM_STEP=0.10`. (`TILE_WORLD_SIZE` + `TOUCH_TARGET_MIN_PX` are also input-handling F-1 prerequisites — shipped here as bundled obligation.)
2. **4 forbidden_patterns registered** in `docs/registry/architecture.yaml`: `camera_signal_emission`, `camera_missing_exit_tree_disconnect`, `hardcoded_zoom_literals`, `external_screen_to_grid_implementation` (all 4 registered via ADR-0013 commit).
3. **5 CI lint scripts** at `tools/ci/lint_camera_*.sh` + `lint_balance_entities_camera.sh` wired into `.github/workflows/tests.yml`.
4. **Story-009 cross-ADR audit** (per ADR-0013 R-7 + TD-057 candidate): partial-resolved by checking shipped HPStatusController code at ADR-0014 authoring — `_exit_tree()` ALREADY EXISTS at line 45 with `GameBus.unit_turn_started.disconnect`. TurnOrderRunner audit deferred to grid-battle-controller epic story-009.

## Test Baseline

**Final epic baseline: 757/757 PASS** (was 743 → +14 from camera unit tests). 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0. **9th consecutive failure-free baseline.**

Test files:
- `tests/unit/feature/camera/battle_camera_screen_to_grid_test.gd` (4 tests — ACs ADR-0013 §Validation §1)
- `tests/unit/feature/camera/battle_camera_zoom_test.gd` (6 tests — ACs ADR-0013 §Validation §1 zoom items)
- `tests/unit/feature/camera/battle_camera_lifecycle_test.gd` (4 tests — DI assertion + _exit_tree disconnect verification + zoom-from-BalanceConstants)

Reuses existing `tests/helpers/map_grid_stub.gd` (from hp-status epic) — no new test helper authored.

## Definition of Done

This epic is complete when:
- All 7 stories Complete
- `src/feature/camera/battle_camera.gd` exists with `class_name BattleCamera extends Camera2D` (NOT `Camera` per G-12)
- `_exit_tree()` body explicitly disconnects `GameBus.input_action_fired` callback
- 6 BalanceConstants keys present in `balance_entities.json`
- 4 forbidden_pattern lint scripts + 1 BalanceConstants key-presence lint = 5 lints all PASS
- 5 lint steps wired into `.github/workflows/tests.yml`
- Full GdUnit4 regression: ≥757 cases / 0 errors / 0 failures / 0 orphans / Exit 0
- godot-specialist 2 BLOCKING revisions resolved (BattleCamera rename + _exit_tree disconnect — verified at ADR-0013 commit)

## Next Step

Sprint-4 S4-04: `/create-epics grid-battle-controller` (next sprint-4 task).

Camera epic is **prerequisite for sprint-5 grid-battle-controller epic implementation** (which will DI BattleCamera + call `screen_to_grid` for click hit-testing).

## Cross-References

- **Governing ADR**: `docs/architecture/ADR-0013-camera.md` (~280 LoC, godot-specialist PASS)
- **Implementation**: `src/feature/camera/battle_camera.gd` (~140 LoC)
- **Tests**: `tests/unit/feature/camera/battle_camera_*_test.gd` (3 files, 14 tests)
- **Lints**: `tools/ci/lint_camera_*.sh` + `lint_balance_entities_camera.sh` (5 scripts)
- **CI**: `.github/workflows/tests.yml` 5 new lint steps + GdUnit4 suite includes feature/camera/
- **Registry**: `docs/registry/architecture.yaml` 11 entries referencing ADR-0013 (state + interface + perf budget + 3 api_decisions + 4 forbidden_patterns)
- **Sprint**: `production/sprints/sprint-4.md` S4-02
- **Design brief (throwaway)**: `prototypes/chapter-prototype/battle_v2.gd` fixed-view + click pattern shape
