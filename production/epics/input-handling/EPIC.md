# Epic: Input Handling System

> **Layer**: Foundation (per ADR-0005 § Engine Compatibility — corrects systems-index.md #29 row "Core" classification)
> **GDD**: `design/gdd/input-handling.md` (Designed 2026-04-16; 5 Core Rules CR-1..CR-5 with sub-rules; 22-action vocabulary in 4 categories; 7-state FSM S0..S6; 3 formulas F-1..F-3; 10 Edge Cases EC-1..EC-10; 8 Tuning Knobs; 18 Acceptance Criteria AC-1..AC-18; 5 Open Questions OQ-1..OQ-5)
> **Architecture Module**: `InputRouter` — **Autoload Node** at `/root/InputRouter` (load order 4: GameBus → SceneManager → SaveManager → **InputRouter**)
> **Manifest Version**: 2026-04-20 (`docs/architecture/control-manifest.md`)
> **Status**: **Ready** (2026-05-02 — Sprint 3 S3-04 epic + 10 stories scaffolded; awaiting `/qa-plan input-handling` + `/dev-story`)
> **Stories**: 10/10 created (2026-05-02 via `/create-stories input-handling`); 0/10 Complete
> **Created**: 2026-05-02 (Sprint 3 S3-04)

## Stories

| # | Story | Type | Status | TR-IDs | GDD ACs | Estimate |
|---|-------|------|--------|--------|---------|----------|
| [001](story-001-module-skeleton-and-autoload-registration.md) | InputRouter Autoload module skeleton + InputState/InputMode enums + InputContext payload + project.godot autoload registration | Logic (borderline-skeleton) | Ready | TR-002 | (structural) | 2h |
| [002](story-002-action-vocabulary-and-bindings-json.md) | 22-action StringName vocabulary + ACTIONS_BY_CATEGORY const + default_bindings.json schema + JSON load + InputMap population + R-5 parity validation | Logic | Ready | TR-003, TR-004 | AC-1, AC-2 | 3-4h |
| [003](story-003-fsm-core-s0-s1-s2-move-flow.md) | 7-state FSM core S0↔S1↔S2 move flow + transition signal emit + 2-beat move confirmation | Logic | Ready | TR-006 | AC-10 (move), AC-15 | 3-4h |
| [004](story-004-fsm-attack-s3-s4-and-st2-demotion.md) | 7-state FSM extended S3↔S4 attack flow + ST-2 demotion + end-player-turn safety gate | Logic | Ready | TR-006 | AC-10 (attack), AC-11 | 3-4h |
| [005](story-005-mode-determination-cr2.md) | Last-device-wins mode determination + state preservation + verification evidence #1 + #2 | Logic | Ready | TR-005, TR-011 | AC-3, AC-4 | 3h (+2h evidence) |
| [006](story-006-per-unit-undo-window.md) | Per-unit undo window (CR-5) + EC-5 occupied-tile rejection + Grid Battle stub extension | Logic | Ready | TR-009 | AC-12, AC-13, AC-14 | 3-4h |
| [007](story-007-input-blocked-and-menu-open.md) | S5 INPUT_BLOCKED + S6 MENU_OPEN + ADR-0002 GameBus subscriptions + nested PackedStringArray stack + verification evidence #4 | Integration | Ready | TR-010 | AC-16, AC-17 | 3-4h |
| [008](story-008-touch-protocol-tpp-magnifier-f1.md) | Touch protocol part A — TPP + Magnifier + F-1 zoom + verification evidence #3 + #5a + Battle HUD/Camera stubs | Integration | Ready | TR-007, TR-008 | AC-5, AC-6, AC-7, AC-18 | 4-5h |
| [009](story-009-touch-protocol-pan-tap-gestures-panel.md) | Touch protocol part B — pan-vs-tap + two-finger gestures + persistent action panel + verification evidence #5b + #6 | Integration | Ready | TR-007, TR-012 | AC-8, AC-9 | 3-4h |
| [010](story-010-epic-terminal-perf-lints-evidence.md) | Epic terminal — perf baseline + 9 CI lint scripts + 6-item verification summary + 3 TD entries (TD-054/055/056) | Config/Data | Ready | TR-013, TR-015, TR-016, TR-017 | (Validation §3..§10) | 3-4h |

**Implementation order**: 001 → 002 → {003, 005, 006 in parallel after 002} → 004 (after 003) → 007 (after 003) → 008 (after 002) → 009 (after 008) → 010 (epic terminal, after all).

**Total estimate**: ~32-40h across 6 Logic + 3 Integration + 1 Config/Data — larger than turn-order/hp-status precedent due to HIGH engine risk + 6 mandatory verification items + touch protocol breadth + 5 provisional cross-system contracts requiring stub authoring (Camera + Grid Battle + Battle HUD via tests/helpers/ stubs; Settings + Tutorial as future-ADR placeholders).

**5 cross-system stubs** authored across stories 003/006/008: `tests/helpers/grid_battle_stub.gd` (story-003 baseline + story-004/006 extensions), `tests/helpers/battle_hud_stub.gd` (story-008), `tests/helpers/camera_stub.gd` (story-008); `tests/helpers/map_grid_stub.gd` extended in story-008 (existing from hp-status epic).

**6 mandatory verification items** distributed:
- #1 dual-focus → story-005 (Polish-deferable)
- #2 SDL3 gamepad → story-005 (Polish-deferable)
- #3 emulate_mouse_from_touch in-editor → story-008 (mandatory headless)
- #4 recursive Control disable → story-007 (mandatory headless)
- #5a DisplayServer.screen_get_size → story-008 (mandatory headless on macOS; Polish-defer Android)
- #5b safe-area API name → story-009 (mandatory headless via 3-candidate fallback)
- #6 touch event index → story-009 (Polish-deferable physical hardware)

Story-010 epic terminal produces a 6-item rollup summary doc at `production/qa/evidence/input_router_verification_summary.md`.

## Overview

The Input Handling epic implements the Foundation-layer system that translates
raw `InputEvent` instances from Godot's input pipeline into 22 canonical game
actions, manages a 7-state Finite State Machine governing player intent flow
(observation → unit-selected → movement-preview → attack-target-select →
attack-confirm → input-blocked → menu-open), and emits 3 typed GameBus signals
that downstream systems consume for HUD updates, undo windows, and turn-flow
reactions. `InputRouter` is the **first STATEFUL Foundation autoload** in the
project — the 5-precedent stateless-static pattern (ADR-0008→0007) is
**explicitly rejected** as Alternative 4 in ADR-0005 because (a) Node lifecycle
callbacks `_input` / `_unhandled_input` cannot fire on `RefCounted` instances
and (b) signal subscription identity for static-method `Callable` is undefined
in GDScript 4.x. Battle-scoped Node form is also rejected because S6 MENU_OPEN
must work outside battle scope (overworld + main menu).

The epic delivers: 7-state FSM with inline match dispatch (no external
StateMachine Resource); auto-detect input-mode switching with last-device-wins
rule (KEYBOARD_MOUSE ↔ TOUCH; gamepad routes to KEYBOARD_MOUSE for MVP per
OQ-1); per-unit undo window (depth 1, keyed by `unit_id`, closes on attack /
end-unit-turn / end-player-turn); externalized bindings via
`assets/data/input/default_bindings.json` (CR-1b — never hardcoded; runtime
remap via `InputRouter.set_binding(action, event)` consumed by future
Settings/Options ADR); touch protocol — Tap Preview Protocol (CR-4a),
Magnifier Panel (CR-4c F-2 trigger), pan-vs-tap classifier (CR-4f F-3),
two-finger gesture handling (CR-4g), persistent action panel (CR-4h);
F-1 `camera_zoom_min = 0.70` derivation enforcing 44px minimum touch target
(CR-4b). The pattern boundary precedent established by ADR-0005 §Alternative 4
(stateless-static for systems CALLED; Node-based form for systems that LISTEN
AND/OR hold mutable state) is the project-wide discipline applied 3 times so
far (InputRouter autoload + HPStatusController battle-scoped + TurnOrderRunner
battle-scoped).

## Pattern Boundary Precedent

InputRouter is the **establishing precedent + autoload variant** of the
Node-based form. Two sub-patterns now in use:

- **Autoload Node** (cross-scene survival; battle-independent lifecycle):
  **InputRouter** (ADR-0005, this epic). Joins same Platform-adjacent autoload
  lineage as ADR-0001 GameBus + ADR-0002 SceneManager + ADR-0003 SaveManager
  at load order 4.
- **Battle-scoped Node** (battle-bounded lifecycle; freed with BattleScene):
  **HPStatusController** (ADR-0010, Complete 2026-05-02) + **TurnOrderRunner**
  (ADR-0011, Complete 2026-05-02).

Future Feature-layer state-holders + signal-listeners (Grid Battle, AI System,
Battle HUD likely candidates) should adopt the battle-scoped Node variant when
lifecycle is battle-bounded; only systems that must survive scene transitions
or operate outside battle scope (e.g. main-menu input) qualify for the
autoload variant.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| **ADR-0005 Input Handling** (primary, Accepted 2026-04-30 delta #6) | InputRouter Autoload Node at `/root/InputRouter` load order 4 + 6 mutable fields (`_state` InputState, `_active_mode` InputMode, `_pre_menu_state` InputState, `_undo_windows` Dictionary[int, UndoEntry], `_input_blocked_reasons` PackedStringArray, `_bindings` Dictionary[StringName, Array[InputEvent]]) + 7-state FSM with inline match dispatch + 22-action StringName vocabulary (4 categories) + externalized JSON bindings + Tap Preview Protocol + Magnifier Panel + pan-vs-tap + per-unit undo + DI test seam via `_handle_event`. **6 mandatory verification items** (dual-focus / SDL3 gamepad / `emulate_mouse_from_touch` / recursive Control disable / `DisplayServer.screen_get_size` logical-pixel return / safe-area API name) before first story ships. | **HIGH** — three post-cutoff items (Godot 4.6 dual-focus + Godot 4.5 SDL3 gamepad + Godot 4.5 Android edge-to-edge / 16KB pages); first such ADR in this project's pipeline |
| ADR-0001 GameBus (Accepted 2026-04-18) | InputRouter is **sole emitter** of 3 Input-domain signals already registered in ADR-0001 §7 Signal Contract Schema (lines 329-335): `input_action_fired(action: StringName, ctx: InputContext)` ≥2-field typed Resource payload + `input_state_changed(from: int, to: int)` 2-primitive payload + `input_mode_changed(new_mode: int)` single-primitive payload. InputRouter is **non-emitter** by behavior for all OTHER 21 GameBus signals across 8 domains (forbidden_pattern `input_router_signal_emission_outside_input_domain`). Carried advisory for next ADR-0001 amendment: line 168 `action: String` → `StringName` (delta #6 Item 10a). | LOW |
| ADR-0002 SceneManager (Accepted 2026-04-18) | InputRouter consumes 2 SceneManager-emitted signals: `ui_input_block_requested(reason: String)` drives S5 INPUT_BLOCKED entry; `ui_input_unblock_requested(reason: String)` drives S5 exit. `_input_blocked_reasons` PackedStringArray supports nested S5 entries (max depth ~3). SceneManager additionally calls `InputRouter.set_process_input(false) + set_process_unhandled_input(false)` directly per `overworld_pause_during_battle` api_decision (godot-specialist 2026-04-30 PASS Item 4 — both required for autoload Nodes). INPUT_BLOCKED dispatch arm MUST call `get_viewport().set_input_as_handled()` before returning (forbidden_pattern `input_router_input_blocked_drop_without_set_input_as_handled`). | LOW |
| ADR-0004 Map/Grid (Accepted 2026-04-20) | `MapGrid.get_tile(coord: Vector2i) -> TileData` consumed for tap-to-select hit-test routing (via Camera's provisional `screen_to_grid` first); registered `tile_grid_runtime_state` consumer entry in `docs/registry/architecture.yaml` line 260. | LOW |

**Highest Engine Risk among governing ADRs**: **HIGH** (ADR-0005 — first such ADR in this project's pipeline; Foundation 4/5 → 5/5 Complete on this epic graduation).

## GDD Requirements

| TR-ID | Requirement (abridged) | ADR Coverage |
|-------|------------------------|--------------|
| TR-input-handling-001 | Input Handling exposes 3 cross-system signals: `input_action_fired` (with typed `InputContext`), `input_state_changed`, `input_mode_changed` (KEYBOARD_MOUSE ↔ TOUCH) | ADR-0001 ✅ (signal contract source-of-truth; registry omits explicit `adr:` field per §7 emit-table convention) |
| TR-input-handling-002 | §1 Module form — `InputRouter` Autoload Node at `/root/InputRouter` (load order 4); `class_name InputRouter extends Node` + 6 mutable fields; state survives scene transitions via Autoload lifecycle. 5-precedent stateless-static REJECTED (Alternative 4 — engine-level structural incompatibility); battle-scoped REJECTED (S6 MENU_OPEN must work outside battle scope) | ADR-0005 ✅ |
| TR-input-handling-003 | §4 + CR-1 Action vocabulary — 22 StringName actions in 4 categories (10 grid + 4 camera + 5 menu + 3 meta) declared in `ACTIONS_BY_CATEGORY` const Dictionary; PC + touch parity per CR-1a hover-only ban (G-2 grid_hover PC-only by design CR-1c); R-5 mitigation: FATAL push_error + early-return on parity mismatch with `default_bindings.json` | ADR-0005 ✅ |
| TR-input-handling-004 | §4 + CR-1b Bindings externalization — all defaults in `assets/data/input/default_bindings.json` (forbidden_pattern `hardcoded_input_bindings`); load via `FileAccess.get_file_as_string()` + `JSON.new().parse()` (mirrors ADR-0006/0007/0008/0009 4-precedent JSON loading); `InputMap` population via `InputMap.add_action()` + `InputMap.action_add_event()` (NOT `Input.parse_input_event()` — per delta #6 Item 8 correction); runtime mutation `InputRouter.set_binding(action, event)` — Settings/Options sole caller per CR-1b | ADR-0005 ✅ |
| TR-input-handling-005 | §3 + CR-2 Last-device-wins mode determination — most-recent-event-class rule: Mouse/Motion/Key → KEYBOARD_MOUSE; ScreenTouch/Drag → TOUCH; Joypad → KEYBOARD_MOUSE (MVP per §6). godot-specialist 2026-04-30 Item 1 PASS — Godot 4.6 dual-focus does NOT alter event-class identity. Mode switch fires once per event (no debounce); CR-2c preserves `_state` + `_undo_windows` across mode switch; HUD hint icons update next frame via `input_mode_changed` | ADR-0005 ✅ |
| TR-input-handling-006 | §5 7-state FSM with inline match dispatch — synchronous deterministic transitions per GDD §Transition Table; states OBSERVATION/UNIT_SELECTED/MOVEMENT_PREVIEW/ATTACK_TARGET_SELECT/ATTACK_CONFIRM/INPUT_BLOCKED/MENU_OPEN (int 0..6 wire-format); single dispatch path through `_handle_action(action, ctx)`; transition emits `input_state_changed(prev, new)` + `input_action_fired(action, ctx)`; `_pre_menu_state` stores prior state on S6 entry; ST-2 demotion on restoration (S2/S4 → S1, drops pending confirms); re-entrancy hazard mitigated via ADR-0001 §5 deferred-connect mandate; ST-4 single-tap buffer (OQ-3 queue depth deferred to Polish) | ADR-0005 ✅ |
| TR-input-handling-007 | §5 + CR-4 Touch protocol — Tap Preview Protocol (CR-4a TPP, OBSERVATION state, 80-120px above touch point, second-tap-on-same advances S0→S1, tap-on-different dismisses); Magnifier Panel (CR-4c, triggered when `tap_edge_offset < DISAMBIG_EDGE_PX` OR `tile_display_px < DISAMBIG_TILE_PX` per F-2; 3×3 grid zoomed 3×); pan-vs-tap classifier (CR-4f / F-3): `touch_travel_px > PAN_ACTIVATION_PX` → camera_pan; `(hold_duration_ms < MIN_TOUCH_DURATION_MS=80 AND NOT pan)` → rejected; two-finger always camera (CR-4g pinch-zoom or two-finger tap cancel; second finger cancels pending first-finger selection per EC-1); persistent action panel (CR-4h, anti-occlusion repositioning) | ADR-0005 ✅ |
| TR-input-handling-008 | §7 + F-1 `camera_zoom_min` derivation — F-1: `camera_zoom_min = TOUCH_TARGET_MIN_PX (44 fixed) / tile_world_size (64 fixed) = 0.6875 → 0.70` (comfort margin: 44.8px effective at zoom=0.70). InputRouter computes via `DisplayServer.screen_get_size()` — **flagged for §5a verification** (returns logical DPI-aware pixels on Android — plausible per godot-specialist 2026-04-30 Item 5 but reference docs do not explicitly confirm; physical-pixel return on 3× DPR Android device would invalidate the formula). Camera (NOT YET WRITTEN — provisional §9) enforces clamp `[camera_zoom_min, camera_zoom_max]` per Bidirectional Contract; hard floor cannot be lowered below 0.6875 without violating 44px touch target requirement | ADR-0005 ✅ |
| TR-input-handling-009 | §1 + §5 + CR-5 Per-unit undo window — `_undo_windows: Dictionary[int, UndoEntry]` keyed by `unit_id` (per-unit, NOT per-turn per CR-5b; depth 1 move per unit). UndoEntry RefCounted holds {`unit_id`, `pre_move_coord`, `pre_move_facing`}. Window opens on S2 confirm → S0; closes permanently on (a) attack with that unit, (b) end_unit_turn for that unit, (c) end_player_turn confirmation. Memory bounded (~16-24 units × ~80 bytes = ~2 KB). Undo restores coord + facing + `has_moved=false` + state→S1; does NOT restore damage / status / enemy reactions (CR-5e). Undo blocked if pre-move tile occupied (EC-5 + CR-5f); queries Grid Battle (provisional §9) | ADR-0005 ✅ |
| TR-input-handling-010 | §1 + Implementation Notes Advisory C + ADR-0002 — InputRouter consumes `ui_input_block_requested(reason: String)` (drives S5 entry) + `ui_input_unblock_requested(reason: String)` (drives S5 exit); `_input_blocked_reasons` PackedStringArray stack supports nested S5 entries (max depth ~3). SceneManager additionally calls `InputRouter.set_process_input(false) + set_process_unhandled_input(false)` per `overworld_pause_during_battle` api_decision (both required for Godot 4.x autoload Nodes per godot-specialist Item 4). INPUT_BLOCKED dispatch arm MUST call `get_viewport().set_input_as_handled()` BEFORE returning (forbidden_pattern `input_router_input_blocked_drop_without_set_input_as_handled` per Advisory C) | ADR-0005 ✅ |
| TR-input-handling-011 | §6 SDL3 gamepad pass-through — Joypad events route to KEYBOARD_MOUSE mode for MVP; no 3rd GAMEPAD mode. OQ-1 partially resolved: full gamepad support (dedicated mode + grid cursor navigation) DEFERRED post-MVP. Settings/Options ADR may add 3rd mode (additive enum value at int 2) without superseding ADR-0005. SDL3 button-index remapping advisory (godot-specialist Item 3) does not affect MVP routing; post-MVP GAMEPAD ADR must verify per-controller mapping. Bluetooth gamepad hot-plug 1-2 frame detection latency (R-2) is hardware-layer concern out of MVP scope | ADR-0005 ✅ |
| TR-input-handling-012 | §7 Android edge-to-edge / safe-area — Action panel positioning consults Godot 4.5+ `DisplayServer` safe-area API (exact name **TBD §5b verification**). 3 candidates per delta #6: (1) `DisplayServer.window_get_safe_title_margins()`; (2) `DisplayServer.get_display_safe_area()`; (3) fallback `DisplayServer.window_get_position_with_decorations()` (desktop-only — likely insufficient for Android notches). Verification §5b mandatory before first story ships. Export-preset 16KB-page Android config out of scope (build-side; tracked in tech-debt register if needed) | ADR-0005 ✅ |
| TR-input-handling-013 | §8 DI test seam — `InputRouter._handle_event(event: InputEvent)` is sole synthetic event injection seam for GdUnit4 v6.1.2 unit tests (production callers forbidden by `_`-prefix convention). Tests construct `InputEvent` subclasses directly + call `_handle_event()` bypassing `_input/_unhandled_input` dispatch. Test isolation via `before_test()` reset of all 6 fields including `_bindings.clear()` then repopulate from JSON fixture (G-15 mirror obligation; `_bindings.clear()` addition per delta #6 godot-specialist Item 7 — omitting leaks `set_binding()` remap state across tests). Mirrors damage-calc story-006 RNG-injection pattern (proven 11 stories) | ADR-0005 ✅ |
| TR-input-handling-014 | §9 Cross-system provisional contracts (4-precedent provisional-dependency strategy) — InputRouter commits verbatim from GDD §Bidirectional Contracts: (1) **Camera** (NOT YET WRITTEN): `Camera.screen_to_grid(screen_pos: Vector2) -> Vector2i` + camera owns drag state (OQ-2 — InputRouter does NOT gate grid input mid-drag) + `camera_zoom_min = 0.70` enforcement; (2) **Grid Battle** (NOT YET WRITTEN): `GridBattleController.is_tile_in_move_range(coord) -> bool` + `is_tile_in_attack_range(coord) -> bool` (InputRouter NEVER computes ranges); (3) **Battle HUD** (NOT YET WRITTEN): `BattleHUD.show_unit_info(unit_id: int)` + `show_tile_info(coord: Vector2i)` for TPP + reads `InputRouter.get_active_input_mode()`; (4) **Settings/Options** (NOT YET WRITTEN): `InputRouter.set_binding(action, event)` runtime remap; (5) **Tutorial** (NOT YET WRITTEN): subscribes to `input_action_fired` for step detection. Each downstream ADR may only WIDEN, never NARROW, the locked interface | ADR-0005 ✅ |
| TR-input-handling-015 | §Verification Required + CR-2e + R-3 — `emulate_mouse_from_touch=false` MUST be set in `[input_devices.pointing]` of `project.godot` for ALL builds per CR-2e (touch events MUST NOT synthesize fake mouse events — would create duplicate dispatch paths breaking TPP semantics). CI lint `tools/ci/lint_emulate_mouse_from_touch.sh` greps `project.godot` per push; FAIL if `true` OR unset (R-3 mitigation; forbidden_pattern `emulate_mouse_from_touch_enabled`). **6 mandatory verification items** before first story ships: (1) Dual-focus end-to-end Android 14+ + macOS Metal; (2) SDL3 gamepad detection Android 15 / iOS 17; (3) `emulate_mouse_from_touch` in-editor; (4) Recursive Control disable cross-check; (5a) `DisplayServer.screen_get_size` logical-pixel return; (5b) Safe-area API name; (6) Touch event index stability iOS 17 + Android 14+ physical hardware (Advisory B) | ADR-0005 ✅ |
| TR-input-handling-016 | §Performance Implications + Validation §8/§10 — CPU per-event dispatch < 0.05ms on minimum-spec mobile (Adreno 610 / Mali-G57 class); single dictionary lookup + match-arm dispatch + 1-3 signal emissions. `_handle_event < 0.05ms`; `_handle_action < 0.02ms`. Memory: total InputRouter heap < 10 KB (`_undo_windows` ~2 KB / `_bindings` ~3 KB / `_input_blocked_reasons` bounded depth ~3) << 512 MB mobile ceiling. Load Time: `_ready()` JSON parse of `default_bindings.json` (~22 actions × ~150 bytes = ~3.3 KB) single-shot at autoload init < 5ms. Headless CI throughput baseline; on-device deferred per Polish-deferral pattern (stable at 6+ invocations as of ADR-0007). Cross-platform determinism by construction (no float-point math in InputRouter) | ADR-0005 ✅ |
| TR-input-handling-017 | §4 + Validation §3/§4 — Non-emitter invariant: InputRouter sole emitter of 3 Input-domain signals per ADR-0001 §7 (lines 329-335); does NOT appear on ADR-0001 lines 370-377 non-emitter list (factual correction per delta #6 Item 9); non-emitter by behavior for OTHER 21 signals across 8 domains (Combat / Scenario / Persistence / Environment / Grid Battle / Turn Order / HP/Status / UI-Flow). Static lints: `grep -c 'GameBus\.input_' src/foundation/input_router.gd` returns 3; `grep -c 'GameBus\.' src/foundation/input_router.gd` minus input domain returns 0 (allows consumption of `ui_input_block/unblock_requested` per ADR-0002). Carried advisory for next ADR-0001 amendment: line 168 `action: String` → `StringName` (delta #6 Item 10a) | ADR-0005 ✅ |

**Total**: 17/17 covered (TR-001 → ADR-0001 GameBus signal-contract source-of-truth; TR-002..017 → ADR-0005 explicit); **0 untraced**.

## Same-Patch Obligations from ADR-0005 Acceptance

The ADR was Accepted 2026-04-30 with the following story-level obligations
that this epic MUST satisfy before the epic can graduate to Complete:

1. **`assets/data/input/default_bindings.json` schema authoring + 22-action default
   binding table content** — mirrors ADR-0006/0007/0008/0009 4-precedent JSON
   loading. PC defaults (keyboard/mouse) + touch defaults; runtime InputMap
   population via `InputMap.add_action(action: StringName)` + `InputMap.action_add_event(action: StringName, event: InputEvent)` (NOT `Input.parse_input_event` — that method is event INJECTION not InputMap population per delta #6 Item 8).
2. **`emulate_mouse_from_touch=false` `project.godot` setting** + CI lint
   `tools/ci/lint_emulate_mouse_from_touch.sh` (forbidden_pattern
   `emulate_mouse_from_touch_enabled`; R-3 mitigation).
3. **Forbidden-patterns registration** in `docs/registry/architecture.yaml` +
   matching CI lint scripts in `tools/ci/` + wiring into `.github/workflows/tests.yml`:
   `hardcoded_input_bindings` (CR-1b enforcement), `input_router_input_blocked_drop_without_set_input_as_handled` (Advisory C), `input_router_signal_emission_outside_input_domain` (Validation §3/§4), `emulate_mouse_from_touch_enabled` (R-3), and 2-3 additional patterns by analogy with turn-order/hp-status 5-6-pattern sets (final pattern count locked at epic-terminal story).
4. **6 mandatory verification items** completed as per-story acceptance gates
   with evidence docs at `production/qa/evidence/input_router_verification_*.md`:
   (1) **Dual-focus end-to-end** on Android 14+ emulator + macOS Metal — KEEP through Polish;
   (2) **SDL3 gamepad detection** on Android 15 / iOS 17 — Bluetooth controller
   mid-scene + KEYBOARD_MOUSE preservation;
   (3) **`emulate_mouse_from_touch`** in-editor verification of Project Settings →
   Input Devices → Pointing path (godot-specialist Item 6 — plausible but
   unconfirmed in reference docs);
   (4) **Recursive Control disable cross-check** — confirm SceneManager
   `set_process_input(false) + set_process_unhandled_input(false)` against
   `/root/InputRouter` silences both `_input` + `_unhandled_input` callbacks
   (godot-specialist Item 4 PASS);
   (5a) **`DisplayServer.screen_get_size()` logical-pixel return on Android** —
   F-1 derivation depends on this; godot-specialist Item 5 plausible-but-unconfirmed;
   (5b) **Safe-area API name verification** — confirm exact 4.6 method name +
   signature for window safe-area inset query (3 candidates per §7); fallback
   to `DisplayServer.window_get_position_with_decorations()` if neither exists;
   (6) **Touch event `index` field stability** for two-finger gestures (CR-4g)
   — integration test on iOS 17 + Android 14+ on **physical hardware** (NOT
   just emulator) per godot-specialist Advisory B.

## Soft / Provisional Dependencies

5 downstream ADRs are NOT YET WRITTEN; InputRouter commits verbatim to the
contract surface from GDD §Bidirectional Contracts. Each downstream ADR can
only WIDEN, never NARROW, the locked interface (provisional-dependency
strategy proven 4 invocations: ADR-0008→0006 / ADR-0012→0009/0010/0011 /
ADR-0009→0007 / ADR-0007→Formation Bonus).

- **Camera ADR** (NOT YET WRITTEN) — `Camera.screen_to_grid(screen_pos: Vector2) -> Vector2i` for touch/click hit-testing; Camera enforces `camera_zoom_min = 0.70` per F-1; Camera owns drag state (OQ-2 resolution — InputRouter does NOT gate grid input mid-drag); Camera subscribes to `camera_pan` / `camera_zoom_in/out` / `camera_snap_to_unit` signals.
- **Grid Battle ADR** (NOT YET WRITTEN) — `GridBattleController.is_tile_in_move_range(coord: Vector2i) -> bool` + `is_tile_in_attack_range(coord: Vector2i) -> bool` for state-transition validation; InputRouter NEVER computes ranges (queries Grid Battle for every transition gate per EC-7).
- **Battle HUD ADR** (NOT YET WRITTEN) — `BattleHUD.show_unit_info(unit_id: int) -> void` + `show_tile_info(coord: Vector2i) -> void` for TPP preview (CR-4a); HUD reads `InputRouter.get_active_input_mode() -> InputMode` for hint icon updates.
- **Settings/Options ADR** (NOT YET WRITTEN) — `InputRouter.set_binding(action: StringName, event: InputEvent) -> void` for runtime key remapping per CR-1b; sole external caller of `set_binding` per CR-1b.
- **Tutorial ADR** (NOT YET WRITTEN) — subscribes to `input_action_fired` for tutorial step detection per GDD §Interactions.

## Stub Strategy for Provisional Dependencies

For each unwritten downstream ADR, the corresponding integration-test stub
goes at `tests/helpers/{camera,grid_battle,battle_hud}_stub.gd` (mirrors
`tests/helpers/map_grid_stub.gd` precedent from hp-status epic). Stub
responses use deterministic fixtures (e.g. `is_tile_in_move_range` returns
true for a hard-coded set of `Vector2i` coords). Replace stubs with real
collaborators when each downstream ADR ships.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All 18 input-handling GDD ACs (AC-1..AC-18) verified — Logic + Integration
  story types per `tests/unit/foundation/` + `tests/integration/foundation/`
  test-evidence rules
- All 17 TRs (TR-input-handling-001..017) status remains `active`; any
  Polish-deferred items logged as TD entries with reactivation triggers
- `assets/data/input/default_bindings.json` authored with 22-action default
  binding table + JSON schema doc-comment
- `emulate_mouse_from_touch=false` set in `project.godot` + CI lint exit 0
- 6+ forbidden_patterns registered in `docs/registry/architecture.yaml` + CI
  lint scripts wired into `.github/workflows/tests.yml`
- DI test seam (`_handle_event` direct call + 6-field `before_test()` reset
  including `_bindings.clear()` per G-15) verified per Validation §5
- **6 mandatory verification items** completed with evidence docs at
  `production/qa/evidence/input_router_verification_*.md` (items #1, #2, #6
  may be Polish-deferred via the standing pattern if minimum-spec
  device/emulator unavailable; items #3, #4, #5a, #5b MUST complete in this
  epic — they are headless-verifiable)
- Headless CI throughput baseline test PASS (`_handle_event < 0.05ms`,
  `_handle_action < 0.02ms`, 10k synthetic events <500ms); on-device
  measurement Polish-deferred per damage-calc story-010 precedent

## Next Step

Run `/create-stories input-handling` to break this epic into implementable
stories (~9-11 stories estimated, ~28-36h total — larger than turn-order /
hp-status precedent due to HIGH engine risk + 6 verification gates + touch
protocol breadth + 5 provisional cross-system contracts requiring stub
authoring).
