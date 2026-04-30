# ADR-0005: Input Handling — InputRouter Autoload + 7-State FSM (MVP scope)

## Status

Proposed (2026-04-30, drafted via `/architecture-decision input-handling` — first HIGH engine-risk ADR; godot-specialist validation 2026-04-30 returned APPROVED WITH SUGGESTIONS, 2 corrections applied pre-Write per Item 5 + Item 8; review-mode lean per `production/review-mode.txt`)

## Date

2026-04-30

## Last Verified

2026-04-30

## Decision Makers

- User (Sprint scheduling authorization, 2026-04-30 — `/architecture-decision input-handling` invocation)
- Technical Director (architecture owner — first HIGH-risk Foundation ADR)
- godot-specialist (engine validation, 2026-04-30 — APPROVED WITH SUGGESTIONS, 8/8 PASS-or-CONCERN; 5 PASS + 2 CONCERN→corrected pre-Write + 1 CONCERN→verify-in-editor; 3 advisories incorporated as Implementation Notes)

---

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Foundation — Input (cross-platform) — **HIGH engine risk** (first such ADR for this project) |
| **Knowledge Risk** | **HIGH** — three post-cutoff changes touch this ADR's contract: (a) Godot 4.6 **dual-focus system** (mouse/touch focus separated from keyboard/gamepad focus); (b) Godot 4.5 **SDL3 gamepad driver** (delegates gamepad handling to SDL library); (c) Godot 4.5 **recursive Control disable** (`mouse_filter = MOUSE_FILTER_IGNORE` propagates to descendant Controls). Plus Godot 4.5 **Android edge-to-edge / 16KB pages** affecting safe-area inset computation. The LLM training data (~Godot 4.3) does NOT cover any of these. **Every API call in this ADR has been verified against `docs/engine-reference/godot/modules/input.md` + `modules/ui.md` + `breaking-changes.md`** (Last verified 2026-02-12 per the engine reference VERSION pin) **AND independently re-validated by godot-specialist on 2026-04-30** (8 focused validation items: 5 PASS, 2 CONCERN→corrected pre-Write, 1 CONCERN→verify-in-editor). |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` (4.6 pinned 2026-04-16); `docs/engine-reference/godot/modules/input.md`; `docs/engine-reference/godot/modules/ui.md`; `docs/engine-reference/godot/breaking-changes.md` (4.4 → 4.5 → 4.6 sections); `docs/engine-reference/godot/deprecated-apis.md`; `docs/engine-reference/godot/current-best-practices.md`; `design/gdd/input-handling.md` (Designed 2026-04-16, 5 Core Rules CR-1..CR-5, 22-action vocabulary, 7-state machine, 3 formulas F-1..F-3, 10 Edge Cases EC-1..EC-10, 8 Tuning Knobs, 18 Acceptance Criteria, 5 Open Questions); `docs/architecture/ADR-0001-gamebus-autoload.md` (3 Input-domain signals already registered: `input_action_fired` / `input_state_changed` / `input_mode_changed`); `docs/architecture/ADR-0002-scene-manager.md` (`ui_input_block_requested` / `ui_input_unblock_requested` consumer contract per registry `scene_transition_lifecycle`); `docs/architecture/ADR-0004-map-grid-data-model.md` (`get_tile(coord) -> TileData` for tap-to-select); `docs/registry/architecture.yaml` v1 (3 input-related stances cross-checked); `.claude/docs/technical-preferences.md` (44px touch target + 60fps + 512MB mobile budget + naming PascalCase). |
| **Post-Cutoff APIs Used** | (a) **Godot 4.6 dual-focus**: `Control.focus_mode = FOCUS_ALL` continues to work; **NEW**: when a Control receives `_gui_input(event)` from mouse/touch the focus is mouse-focus (separate from keyboard focus). InputRouter operates BELOW Control focus layer (handles `_unhandled_input` after all Controls had a chance) so dual-focus split does not bifurcate `active_input_mode` — the mode is determined by the most-recent **event class** (Mouse/Touch/Key), not by which focus channel owns the focus. (b) **Godot 4.5 SDL3 gamepad backend**: API surface (`InputEventJoypadButton` / `InputEventJoypadMotion` / `Input.is_joy_button_pressed`) **unchanged**; SDL3 provides the runtime device handling but the GDScript surface is identical. ADR-0005 routes joypad events to `KEYBOARD_MOUSE` mode for MVP (no new mode). (c) **Godot 4.5 recursive Control disable**: `Control.mouse_filter = MOUSE_FILTER_IGNORE` propagates to children (per ADR-0002 `overworld_pause_during_battle` registered api_decision); InputRouter is NOT a Control — it is a Node-based autoload — so recursive disable does not affect InputRouter directly. SceneManager silences InputRouter via `InputRouter.set_process_input(false) + set_process_unhandled_input(false)` as an explicit per-frame gate. (d) **Godot 4.5 Android edge-to-edge / safe-area**: `DisplayServer.screen_get_size()` for camera_zoom_min derivation (returns logical DPI-aware pixels — verify on first story); safe-area API name **deferred to implementation-time verification** per godot-specialist 2026-04-30 Item 5 — see §7 below. Export-preset 16KB-page config is build-side, not InputRouter-side. |
| **Verification Required** | (1) **Dual-focus end-to-end test on Android 14+ emulator + macOS Metal**: tap a Control with `focus_mode = FOCUS_ALL`, then press an arrow key → confirm `active_input_mode` switches per most-recent-event-class rule, NOT per focus-channel ownership. **KEEP through Polish**. (2) **SDL3 gamepad detection on Android 15 / iOS 17**: connect a Bluetooth controller mid-scene → confirm `InputEventJoypadButton` events arrive AND that the existing keyboard/mouse mode is preserved (no MVP gamepad mode promotion). (3) **`emulate_mouse_from_touch` project setting**: confirm `project.godot` has `[input_devices.pointing] emulate_mouse_from_touch=false` set; CI lint must catch reintroduction. Path is plausible per Godot 4.x format but not explicitly confirmed in reference docs (godot-specialist 2026-04-30 Item 6) — verify in-editor via Project Settings → Input Devices → Pointing on first story. (4) **Recursive Control disable cross-check**: confirm SceneManager's `set_process_input(false) + set_process_unhandled_input(false)` against `/root/InputRouter` does silence `_input` + `_unhandled_input` callbacks (Godot 4.x core behavior, godot-specialist 2026-04-30 PASS Item 4 — both required, both work for autoload Nodes). (5a) **`DisplayServer.screen_get_size()` returns logical (DPI-aware) pixels on Android, NOT physical pixels** — F-1 derivation depends on this; godot-specialist 2026-04-30 Item 5 confirms behavior is plausible but reference docs do not explicitly confirm; verify on first story implementation. (5b) **Safe-area API name verification** — confirm exact 4.6 method name + signature for window safe-area inset query (per §7 candidate list); if neither candidate exists, fall back to platform-specific workaround via `DisplayServer.window_get_position_with_decorations()`. (6) **Touch event `index` field stability** for two-finger gesture tracking (CR-4g): event indices are assigned by the OS; document the bookkeeping pattern; per godot-specialist Advisory B run integration test on iOS 17 + Android 14+ on **physical hardware** (NOT just emulator). |

> **Knowledge Risk Note**: Domain is **HIGH** risk for the first time in this project's ADR pipeline. All 6 verification items (counting 5a + 5b separately) are **mandatory** before the InputRouter epic ships its first story. Future Godot 4.7+ that touches dual-focus semantics or SDL3 backend behavior would trigger Superseded-by review. The engine-reference docs were last verified 2026-02-12 — re-verify on the next /architecture-review pass if more than 60 days have elapsed.

---

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0001 GameBus** (Accepted 2026-04-18) — InputRouter is the **sole emitter** of 3 Input-domain signals already registered in ADR-0001 contract: `input_action_fired(action: StringName, ctx: InputContext)` (≥2-field typed Resource payload per TR-gamebus-001) + `input_state_changed(from: int, to: int)` (2-primitive payload) + `input_mode_changed(new_mode: int)` (single-primitive payload). InputRouter is on the **non-emitter list** for all OTHER signal domains (Combat / Scenario / Persistence / Environment / Grid Battle / Turn Order / HP/Status / UI-Flow). **ADR-0002 SceneManager** (Accepted 2026-04-18) — InputRouter consumes `ui_input_block_requested(reason: String)` + `ui_input_unblock_requested(reason: String)` per registered `scene_transition_lifecycle` interface (line 216 of `docs/registry/architecture.yaml`); these signals drive the S5 `INPUT_BLOCKED` state entry/exit. SceneManager also calls `InputRouter.set_process_input(false) + set_process_unhandled_input(false)` directly during overworld retain (per `overworld_pause_during_battle` api_decision line 458). **ADR-0004 Map/Grid** (Accepted 2026-04-20) — InputRouter calls `MapGrid.get_tile(coord: Vector2i) -> TileData` for tap-to-select hit-test routing (per registered `tile_grid_runtime_state` consumer entry line 260); the call goes through the Camera's `screen_to_grid` first (provisional). |
| **Soft / Provisional** | (1) **Camera ADR (NOT YET WRITTEN — soft / provisional downstream)**: `Camera.screen_to_grid(screen_pos: Vector2) -> Vector2i` for touch/click hit-testing; Camera owns `camera_zoom_min = 0.70` enforcement per F-1; Camera subscribes to `camera_pan` / `camera_zoom_in/out` / `camera_snap_to_unit` signals. ADR-0005 commits to these signatures verbatim from `design/gdd/input-handling.md` §Bidirectional Contracts; downstream Camera ADR ratifies (does not negotiate). Mirrors 4-precedent provisional-dep pattern (ADR-0008→0006 / ADR-0012→0009/0010/0011 / ADR-0009→0007 / ADR-0007→Formation Bonus). (2) **Grid Battle ADR (NOT YET WRITTEN — soft / provisional downstream)**: `GridBattleController.is_tile_in_move_range(coord: Vector2i) -> bool` + `is_tile_in_attack_range(coord: Vector2i) -> bool` for state-transition validation. InputRouter NEVER computes ranges itself — it queries Grid Battle for every transition gate. Migration parameter-stable when Grid Battle ADR lands. (3) **Battle HUD ADR (NOT YET WRITTEN — soft / provisional downstream)**: `BattleHUD.show_unit_info(unit_id: int) -> void` + `show_tile_info(coord: Vector2i) -> void` for Touch Tap Preview Protocol (CR-4a); `BattleHUD` reads `InputRouter.get_active_input_mode() -> InputMode` for hint icon updates. (4) **Settings/Options ADR (NOT YET WRITTEN — soft / provisional downstream)**: `InputRouter.set_binding(action: StringName, event: InputEvent) -> void` for runtime key remapping per CR-1b. (5) **Tutorial ADR (NOT YET WRITTEN — soft / provisional downstream)**: subscribes to `input_action_fired` for tutorial step detection per GDD §Interactions. |
| **Enables** | (1) **Unblocks input-handling Foundation epic** — `/create-epics input-handling` after this ADR is Accepted; brings Foundation layer **4/5 → 5/5 Complete**. (2) **Unblocks Camera ADR / Camera Foundation epic** — Camera depends on InputRouter for input event routing + zoom-clamp enforcement contract. (3) **Unblocks Battle HUD ADR / Presentation-layer epic** — HUD depends on `input_state_changed` + `input_mode_changed` for contextual UI. (4) **Unblocks Grid Battle Vertical Slice readiness** — Grid Battle's S2 confirm flow depends on `action_confirm` from InputRouter; no VS without this. (5) **Resolves Open Question** from architecture.md v0.4 — "Dual-focus system (4.6) × Input Handling auto-detect (CR-2) coherence" — closed by Decision §3 below. (6) **Resolves Scenario Progression v2.0 OQ bucket 3** partially — dual-focus + recursive Control disable + Android 15 edge-to-edge + AccessKit reduced-motion engine-reference verifications collapse into this ADR's Verification Required §1, §3, §4, §5a/b items. |
| **Blocks** | input-handling Foundation epic implementation (cannot start any story until this ADR is Accepted); `assets/data/input/default_bindings.json` schema authoring + the 22-action default binding table content; Camera ADR ratification (Camera depends on this ADR for the contract surface); Battle HUD ADR ratification (HUD depends on `input_state_changed` + `input_mode_changed`); Grid Battle Vertical Slice (no VS without InputRouter shipped). |
| **Ordering Note** | First **HIGH engine-risk ADR** in this project. Pattern divergence from prior 5 stateless-static ADRs (0008→0007): InputRouter is **STATEFUL** (owns 7-state FSM + active_input_mode + per-unit undo windows + 3 cached InputEvent buffers for state transitions). The 5-precedent stateless-static pattern is **NOT applicable** here — explicitly rejected as Alternative 4 below. The Autoload Node form is justified by (a) Foundation-layer cross-scene survival requirement (state machine survives BattleScene swap; menu state S6 is inherently non-battle-scoped) + (b) precedent compatibility with ADR-0001 (GameBus autoload) + ADR-0002 (SceneManager autoload) + ADR-0003 (SaveManager autoload) — InputRouter joins the same Platform-adjacent autoload lineage at load order 4. |

---

## Context

### Problem Statement

`design/gdd/input-handling.md` (Designed 2026-04-16, 5 Core Rules CR-1..CR-5, 22-action vocabulary, 7-state machine S0..S6, 3 formulas F-1..F-3, 10 Edge Cases EC-1..EC-10, 8 Tuning Knobs, 18 Acceptance Criteria, 5 Open Questions) defines the Foundation-layer Input Handling System. The architecture cannot proceed without locking 9 questions:

1. **Module form** — Autoload Node? Battle-scoped Node? Stateless static utility class? RefCounted singleton? GDD §Integration contract line 378 says "Singleton: InputHandlingSystem — Autoload or scene singleton" without locking the form. The 5-precedent stateless-static pattern (ADR-0008→0007) does NOT apply because InputRouter owns mutable state (7-state FSM + active_input_mode + per-unit undo windows).
2. **Class naming reconciliation** — registry uses `InputRouter` (referenced 4 places in ADR-0001 + ADR-0002 cross-refs); GDD prose uses "InputHandlingSystem". Cross-doc canonical name must lock.
3. **Godot 4.6 dual-focus reconciliation** — engine splits mouse/touch focus from keyboard/gamepad focus; GDD CR-2 ("auto-detect, last-device-wins, single mode") assumes single focus owner. Without ratification, the 7-state machine could need a per-channel split.
4. **Action vocabulary representation** — 22 actions: `StringName` per Godot idiom, or typed enum, or both?
5. **State machine implementation** — match/transition_table inline vs. dedicated `StateMachine` Resource vs. Godot AnimationTree-as-FSM repurposing?
6. **SDL3 gamepad backend (4.5)** — runtime path is automatic per Godot 4.5 default; how does ADR-0005 handle gamepad without committing to a 3rd `active_input_mode` value (OQ-1 partial resolution)?
7. **Android edge-to-edge / 16KB pages (4.5)** — safe-area-aware action panel positioning + DisplayServer.screen_get_size for camera_zoom_min derivation; what's in scope vs. export-preset config?
8. **Cross-system contracts** — Camera + Grid Battle + Battle HUD GDDs are NOT YET WRITTEN; how does ADR-0005 commit to interfaces those will own (provisional-dependency strategy)?
9. **Test infrastructure** — how do we test InputRouter without real input devices (DI seam pattern)?

### Constraints

**From `design/gdd/input-handling.md` (locked by Foundation-layer GDD review):**
- **CR-1**: 22-action vocabulary (10 grid + 4 camera + 5 menu + 3 meta); every action has both PC and touch activation paths (CR-1a hover-only ban).
- **CR-1b**: All bindings live in `assets/data/input/default_bindings.json`; never hardcoded.
- **CR-2**: `active_input_mode: enum { KEYBOARD_MOUSE, TOUCH }`; last-device-wins; mode switch does NOT reset game state (CR-2c); HUD hints update next frame (CR-2d); `emulate_mouse_from_touch` MUST be disabled in production builds (CR-2e).
- **CR-3**: Two-beat confirmation flow; `action_confirm` only valid AFTER outcome is displayed (CR-3a); confirm button near action point (CR-3b, Fitts's Law); no double-tap shortcut (CR-3c).
- **CR-4**: Touch protocol — Tap Preview Protocol (CR-4a); 44×44px minimum touch target (CR-4b → enforced via F-1 `camera_zoom_min = 0.70`); Magnifier Panel (CR-4c); Selection highlight (CR-4d); MIN_TOUCH_DURATION_MS = 80 (CR-4e); Pan vs tap (CR-4f / F-3); two-finger gestures = camera (CR-4g); persistent action panel (CR-4h).
- **CR-5**: Per-unit undo window (1 move per unit); closes on attack / end-unit-turn / end-player-turn; pre-move tile occupied → undo rejected.
- **F-1**: `camera_zoom_min = TOUCH_TARGET_MIN_PX / tile_world_size = 44/64 = 0.6875 → 0.70`.
- **18 ACs** (AC-1..AC-18) collectively define the testable contract.

**From `docs/engine-reference/godot/modules/input.md` (Last verified 2026-02-12) + godot-specialist re-validation 2026-04-30:**
- **Godot 4.6 dual-focus** — mouse/touch focus separate from keyboard/gamepad focus; visual feedback differs by input method. **Specialist Item 1 PASS**: dual-focus does NOT alter event-class identity; the most-recent-event-class rule is engine-correct.
- **Godot 4.5 SDL3 gamepad** — API unchanged; SDL3 provides better device detection + improved rumble + consistent button mapping. **Specialist Item 3 PASS** (with advisory): SDL3 may alter button index assignments on some gamepads relative to SDL2 (internal remapping table changed) — does not affect ADR-0005 routing-to-KEYBOARD_MOUSE choice; reconsider when post-MVP GAMEPAD ADR is written.
- **Common mistake** (line 70 of input.md) — "Not testing both mouse and keyboard focus paths (dual-focus in 4.6)".

**From `docs/registry/architecture.yaml` (v1, 3 input-related stances):**
- `scene_transition_lifecycle` (signal interface, line 216): InputRouter consumes `ui_input_block_requested` / `ui_input_unblock_requested`.
- `overworld_pause_during_battle` (api_decision, line 458): SceneManager silences InputRouter via `set_process_input(false) + set_process_unhandled_input(false)` + recursive Control disable.
- `tile_grid_runtime_state` (state, line 260): InputRouter reads `MapGrid.get_tile(coord)` for tap-to-select routing.

**From `.claude/docs/technical-preferences.md`:**
- 44×44px minimum touch target.
- 60 fps target / 16.6 ms frame budget / 512 MB mobile / <500 draw calls (2D).
- Naming: `class_name` PascalCase; signals snake_case past tense; constants UPPER_SNAKE_CASE.
- All UI must support both touch and mouse input; hover-only forbidden.

---

## Decision

**Lock the InputRouter as a Platform-adjacent Autoload Node at `/root/InputRouter` (load order 4, after GameBus → SceneManager → SaveManager).** It owns a typed-enum 7-state FSM + a 2-value `InputMode` enum, exposes 3 read-only query methods, emits the 3 already-registered Input-domain GameBus signals, and consumes the 2 SceneManager-emitted block/unblock signals. All state transitions go through a single internal dispatch path with a DI seam for synthetic event injection from GdUnit4 tests.

### §1. Module Form — Autoload Node, NOT stateless-static

```gdscript
# src/foundation/input_router.gd  (autoload registered at /root/InputRouter, load order 4)
extends Node
class_name InputRouter

# 7-state FSM with semantic enum names; int 0..6 wire-format for save/load forward-compat
enum InputState {
    OBSERVATION = 0,           # GDD S0 — reading beat (default)
    UNIT_SELECTED = 1,         # GDD S1 — unit highlighted, action menu shown
    MOVEMENT_PREVIEW = 2,      # GDD S2 — destination chosen, ghost shown, awaiting confirm
    ATTACK_TARGET_SELECT = 3,  # GDD S3 — attack range shown, awaiting target
    ATTACK_CONFIRM = 4,        # GDD S4 — target chosen, damage preview shown, awaiting confirm
    INPUT_BLOCKED = 5,         # GDD S5 — enemy phase or animation; grid input silenced
    MENU_OPEN = 6,             # GDD S6 — overlay menu/dialog active
}

enum InputMode {
    KEYBOARD_MOUSE = 0,        # PC default
    TOUCH = 1,                 # Mobile default; gamepad routes here for MVP
}

# Mutable owned state (justifies non-stateless-static module form)
var _state: InputState = InputState.OBSERVATION
var _active_mode: InputMode = InputMode.KEYBOARD_MOUSE  # platform default set in _ready
var _pre_menu_state: InputState = InputState.OBSERVATION  # restored on S6 → prior
var _undo_windows: Dictionary = {}  # unit_id (int) → UndoEntry (RefCounted) — per-unit undo per CR-5b
var _input_blocked_reasons: PackedStringArray = []  # stack of block reasons for nested S5 entries
var _bindings: Dictionary = {}  # action StringName → Array[InputEvent] — runtime mutable for remap
```

**Justification**: InputRouter holds 4 distinct mutable state fields (FSM state + active mode + pre-menu state + undo windows + block reason stack + runtime bindings) that survive scene transitions but reset between battles (per ADR-0002 SceneManager retain-vs-free pattern). Stateless-static utility (5-precedent ADR-0008→0007) is **architecturally incompatible** — see Alternative 4 (godot-specialist 2026-04-30 Item 7 PASS confirms both engine claims). Battle-scoped Node fails because S6 MENU_OPEN state must work outside battle scope. Autoload Node is the only form that satisfies both cross-scene survival + mutable-state-with-test-isolation requirements (godot-specialist 2026-04-30 Item 2 PASS confirms autoload Node receives both `_input` and `_unhandled_input` callbacks).

### §2. Class Naming Reconciliation

Registry-canonical name `InputRouter` is adopted as `class_name`. The GDD's "InputHandlingSystem" prose name is preserved as a documentation alias. `/architecture-decision` Phase 4.7 GDD sync edits applied 2026-04-30 (3 occurrences in `design/gdd/input-handling.md` lines 378 / 708 / 811).

| Surface | Name | Rationale |
|---|---|---|
| GDScript class | `class_name InputRouter` | Matches registry referenced_by entries (ADR-0001 + ADR-0002) |
| Autoload path | `/root/InputRouter` | Mirrors `/root/GameBus` / `/root/SceneManager` / `/root/SaveManager` lineage |
| File path | `src/foundation/input_router.gd` | Foundation layer per architecture.md |
| System slug | `input-handling` | Matches GDD filename + epic directory |
| GDD prose alias | "InputHandlingSystem" | Preserved with cross-doc note added 2026-04-30 (line 378) |

### §3. Dual-Focus Reconciliation (Godot 4.6)

**The single-`active_input_mode` design from GDD CR-2 is preserved unchanged.** Mode determination is by **most-recent-event-class**, NOT by which focus channel owns focus:

| Event class | Mode set |
|---|---|
| `InputEventMouseButton` | `KEYBOARD_MOUSE` |
| `InputEventMouseMotion` | `KEYBOARD_MOUSE` |
| `InputEventKey` | `KEYBOARD_MOUSE` |
| `InputEventScreenTouch` | `TOUCH` |
| `InputEventScreenDrag` | `TOUCH` |
| `InputEventJoypadButton` | `KEYBOARD_MOUSE` (MVP — see §6) |
| `InputEventJoypadMotion` | `KEYBOARD_MOUSE` (MVP — see §6) |

**Rationale**: Godot 4.6's dual-focus split affects Control-level visual focus (where mouse hover lights up vs. where Tab/Arrow keys land) — that is a Control-layer rendering concern, NOT an InputRouter action-vocabulary concern. InputRouter operates BELOW the Control focus layer (`_unhandled_input` is fired AFTER all Controls have had a chance via `_gui_input`). The most-recent-event-class rule is well-defined regardless of which focus channel was active. **Engine-validated** 2026-04-30 by godot-specialist Item 1 PASS — dual-focus does NOT alter event-class identity. **Closes Open Question** from architecture.md v0.4 (Dual-focus × CR-2 coherence).

### §4. Action Vocabulary — 22 StringName Actions

```gdscript
# Coverage-checked via const dictionary; static-lint friendly
const ACTIONS_BY_CATEGORY: Dictionary = {
    &"grid": [
        &"grid_select", &"grid_hover", &"grid_cursor_move",
        &"unit_select", &"move_target_select", &"attack_target_select",
        &"action_confirm", &"action_cancel",
        &"end_unit_turn", &"end_player_turn",
    ],
    &"camera": [
        &"camera_pan", &"camera_zoom_in", &"camera_zoom_out", &"camera_snap_to_unit",
    ],
    &"menu": [
        &"ui_confirm", &"ui_cancel", &"ui_navigate",
        &"open_unit_info", &"open_game_menu",
    ],
    &"meta": [
        &"undo_last_move", &"toggle_terrain_overlay", &"toggle_formation_overlay",
    ],
}
# Lint: total = 22; categories partition (no overlap); every action also exists in default_bindings.json
```

Bindings load from `assets/data/input/default_bindings.json` at `_ready()` via `FileAccess.get_file_as_string()` + `JSON.new().parse()` (mirrors ADR-0006/0007/0008/0009 4-precedent JSON loading pattern). InputMap population uses `InputMap.add_action(action: StringName)` + `InputMap.action_add_event(action: StringName, event: InputEvent)`; typed `InputEvent` subclasses (`InputEventKey`, `InputEventMouseButton`, `InputEventJoypadButton`) are constructed from JSON event descriptors via direct property assignment (e.g., `var ev := InputEventKey.new(); ev.physical_keycode = KEY_ENTER`). `Input.parse_input_event()` is reserved for the §8 DI test seam (synthetic event injection through the engine's input pipeline) — **NOT for InputMap population** (which it does not perform; corrected pre-Write per godot-specialist 2026-04-30 Item 8).

### §5. State Machine — Inline Match Dispatch

Synchronous deterministic transitions per GDD §Transition Table. No external `StateMachine` Resource, no AnimationTree-as-FSM repurposing.

```gdscript
func _handle_action(action: StringName, ctx: InputContext) -> void:
    # Single dispatch path — also the DI seam for tests (see §8)
    var prev_state: InputState = _state
    match _state:
        InputState.OBSERVATION:
            _transition_from_observation(action, ctx)
        InputState.UNIT_SELECTED:
            _transition_from_unit_selected(action, ctx)
        # ... 5 more state arms
    if _state != prev_state:
        GameBus.input_state_changed.emit(prev_state, _state)
    GameBus.input_action_fired.emit(action, ctx)
```

### §6. SDL3 Gamepad (Godot 4.5) — Pass-through to KEYBOARD_MOUSE Mode

Joypad events route to `KEYBOARD_MOUSE` mode for MVP. **No 3rd `GAMEPAD` mode is introduced.** OQ-1 (Gamepad Full Support Scope) is **partially resolved**: full gamepad support — including a dedicated `GAMEPAD` mode + grid cursor navigation — is deferred to a post-MVP ADR. Settings/Options ADR may add a 3rd mode without superseding ADR-0005 (additive enum value at int 2). Godot 4.5 SDL3 backend may have altered button index remapping relative to SDL2 (godot-specialist 2026-04-30 Item 3 advisory) — does not affect this ADR but the post-MVP GAMEPAD ADR must verify per-controller button mapping.

### §7. Android Edge-to-Edge / Safe-Area (Godot 4.5)

InputRouter computes `camera_zoom_min` from F-1 using `DisplayServer.screen_get_size()` (returns logical DPI-aware pixels per Verification Required §5a — godot-specialist 2026-04-30 Item 5 confirms behavior is plausible but reference docs do not explicitly confirm; verify on first story implementation). Action panel positioning consults a Godot 4.5+ DisplayServer safe-area API (**exact method name to be verified at implementation-time against live 4.6 docs** — candidate names per godot-specialist 2026-04-30 Item 5: `DisplayServer.window_get_safe_title_margins()` (plural) OR a platform-specific workaround via `DisplayServer.window_get_position_with_decorations()`) to avoid clipping behind notches / nav bars. Export-preset 16KB-page Android config is **out of scope** for this ADR (build-side concern; tracked in tech-debt register if needed).

### §8. Test Infrastructure — DI Seam

```gdscript
# Public test seam (NOT for production callers — convention enforced via _-prefixed name)
func _handle_event(event: InputEvent) -> void:
    """Direct event injection for GdUnit4 tests. Production: called by Godot via _input/_unhandled_input."""
    # ... event classification + action dispatch
```

GdUnit4 tests synthesize `InputEvent` subclasses and call `_handle_event()` directly. Mirrors damage-calc story-006 RNG-injection seam pattern (proven 11 stories). Test isolation via `before_test()` reset of `_state` + `_active_mode` + `_undo_windows` (G-15-style obligation, codified as forbidden_pattern in §Phase 6 registry update). Optional: `Input.parse_input_event(synthetic_event)` may also be used to inject events through the full engine pipeline (`_input` → `_unhandled_input` → InputRouter); use case is end-to-end integration tests when isolated state-machine tests via `_handle_event` are insufficient.

### §9. Cross-System Provisional Contracts

| Downstream system | Interface InputRouter commits to (verbatim from GDD) | Migration path |
|---|---|---|
| Camera (NOT YET WRITTEN) | `Camera.screen_to_grid(screen_pos: Vector2) -> Vector2i` | Camera ADR ratifies; signature unchanged |
| Camera (NOT YET WRITTEN) | Camera enforces `camera_zoom_min = 0.70` per F-1 | Camera ADR ratifies; constant value locked here |
| Grid Battle (NOT YET WRITTEN) | `GridBattleController.is_tile_in_move_range(coord: Vector2i) -> bool` | Grid Battle ADR ratifies |
| Grid Battle (NOT YET WRITTEN) | `GridBattleController.is_tile_in_attack_range(coord: Vector2i) -> bool` | Grid Battle ADR ratifies |
| Battle HUD (NOT YET WRITTEN) | `BattleHUD.show_unit_info(unit_id: int) -> void` | HUD ADR ratifies |
| Battle HUD (NOT YET WRITTEN) | `BattleHUD.show_tile_info(coord: Vector2i) -> void` | HUD ADR ratifies |

4-precedent provisional-dependency strategy applies (ADR-0008→0006 / ADR-0012→0009/0010/0011 / ADR-0009→0007 / ADR-0007→Formation Bonus). Each downstream ADR can only WIDEN, never NARROW, the locked interface.

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    GODOT 4.6 ENGINE EVENT QUEUE                         │
│  InputEventKey / InputEventMouseButton / InputEventMouseMotion /        │
│  InputEventScreenTouch / InputEventScreenDrag /                         │
│  InputEventJoypadButton / InputEventJoypadMotion                        │
└────────────────┬────────────────────────────────────────────────────────┘
                 │
                 │ _input(event)            ← global hotkeys (Esc, P, etc.)
                 │ _unhandled_input(event)  ← world (after all Controls + _gui_input)
                 ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  /root/InputRouter (Autoload Node, load order 4)                        │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  _handle_event(event)  ← single dispatch path + DI test seam     │   │
│  │       │                                                           │   │
│  │       ├─ classify event → update _active_mode (last-device-wins) │   │
│  │       ├─ resolve InputMap action ← bindings (default_bindings.json│   │
│  │       │                              + runtime remap via set_binding)│ │
│  │       ├─ touch protocol (TPP, magnifier, pan-vs-tap classifier)  │   │
│  │       └─ _handle_action(action, ctx) → state machine dispatch    │   │
│  │                                                                   │   │
│  │  7-state FSM: OBSERVATION ⇄ UNIT_SELECTED ⇄ MOVEMENT_PREVIEW ⇄   │   │
│  │  ATTACK_TARGET_SELECT ⇄ ATTACK_CONFIRM ; INPUT_BLOCKED ; MENU_OPEN│   │
│  └──────────────────────────────────────────────────────────────────┘   │
└────┬────────────────────────────────────────────────────────────────────┘
     │
     │ READS                              EMITS (3 signals on /root/GameBus)
     │  • Camera.screen_to_grid           │
     │  • MapGrid.get_tile(coord)         │
     │  • GridBattleController.is_tile_in_*  │
     │                                    │
     ▼                                    ▼
┌────────────┐   ┌─────────────────────────────────────────────────────┐
│ Camera ADR │   │ /root/GameBus (ADR-0001)                            │
│ Grid Battle│   │  • input_action_fired(action: StringName, ctx)      │
│ Battle HUD │   │  • input_state_changed(from: int, to: int)          │
│ (provisional)│ │  • input_mode_changed(new_mode: int)                │
└────────────┘   └─────────────────┬───────────────────────────────────┘
                                   │
                                   │ subscribers
                                   ▼
                          Grid Battle / Camera / Battle HUD /
                          Settings / Tutorial


       SceneManager (ADR-0002) silences InputRouter:
            ──→ InputRouter.set_process_input(false)
            ──→ InputRouter.set_process_unhandled_input(false)
       SceneManager (ADR-0002) drives S5 entry/exit:
            ──→ ui_input_block_requested(reason)   → S5 entry
            ──→ ui_input_unblock_requested(reason) → S5 exit
```

### Key Interfaces

```gdscript
# Public emitted signals (declared on GameBus per ADR-0001 — InputRouter is sole emitter)
GameBus.input_action_fired(action: StringName, ctx: InputContext)
GameBus.input_state_changed(from_state: int, to_state: int)
GameBus.input_mode_changed(new_mode: int)

# Public read-only queries
InputRouter.get_current_state() -> InputState
InputRouter.get_active_input_mode() -> InputMode
InputRouter.get_undo_window(unit_id: int) -> UndoEntry  # null if no window open

# Public mutation API (Settings/Options sole caller)
InputRouter.set_binding(action: StringName, event: InputEvent) -> void

# Test seam (convention: _-prefixed; production callers forbidden)
InputRouter._handle_event(event: InputEvent) -> void

# Typed Resource payloads (in src/core/payloads/)
class_name InputContext extends Resource
@export var target_coord: Vector2i = Vector2i.ZERO  # Vector2i.MAX_VALUE if N/A
@export var unit_id: int = -1                        # -1 if N/A
@export var screen_pos: Vector2 = Vector2.ZERO       # for touch protocol disambiguation

class_name UndoEntry extends RefCounted
var unit_id: int
var pre_move_coord: Vector2i
var pre_move_facing: int  # int enum from grid-battle ADR (provisional)
```

### Implementation Notes (per godot-specialist 2026-04-30 advisories)

- **Consumed-event inheritance (Advisory A)**: when a Control consumes an event via `accept_event()` in its `_gui_input`, the event does NOT propagate to InputRouter's `_unhandled_input` — engine-correct behavior and design-intentional (UI button taps should not also trigger unit selection). InputRouter using `_unhandled_input` (NOT `_input`) for world-space input is precisely the right pattern to inherit this consumption automatically.
- **INPUT_BLOCKED silent-drop (Advisory C)**: when InputRouter receives an event in `INPUT_BLOCKED` state and decides to silently drop it (per GDD EC-2 + ST-4), the implementation MUST call `get_viewport().set_input_as_handled()` BEFORE returning to prevent the event from continuing to any downstream `_unhandled_input` handlers (relevant for test fixtures with additional listeners + future Tutorial / debug overlays).
- **Touch index stability per-platform (Advisory B)**: R-6 verification must run on both iOS 17 and Android 14+ on **physical hardware** (NOT just emulator) to catch OS-specific index reuse behavior on rapid lift+touch sequences.

---

## Alternatives Considered

### Alternative 1: Battle-scoped Node (child of BattleScene)

- **Description**: InputRouter as a Node child of BattleScene; created on battle entry, freed on battle exit per ADR-0002 SceneManager lifecycle.
- **Pros**: Battle-scoped isolation matches MapGrid pattern (ADR-0004); no cross-battle state leakage; simpler test fixture.
- **Cons**: S6 MENU_OPEN state must work OUTSIDE battle scope (main menu, scenario select, options screen). Battle-scoped form fails this fundamental requirement. Would force a duplicate "MenuInputRouter" autoload for non-battle scenes.
- **Rejection reason**: GDD §Transition Table includes S6 MENU_OPEN as a state reachable from any other state including non-battle contexts (main menu → settings → back). Battle-scoped form structurally cannot support this.

### Alternative 2: Hybrid (Autoload for global hotkeys + BattleScene-child for grid)

- **Description**: A small autoload InputRouter for global hotkeys (Esc, P, settings) + a battle-scoped GridInputRouter as BattleScene child for grid actions.
- **Pros**: Battle-scoped isolation for grid-specific state (FSM transitions S0→S4); global hotkeys survive scene swaps via autoload portion.
- **Cons**: Splits the 7-state FSM across two Nodes — S0..S4 in GridInputRouter, S5..S6 in autoload. Cross-Node state coordination requires signal indirection or shared Resource. Test fixtures double in count. Last-device-wins mode tracking must live in autoload (mode is global) but mode affects grid behavior (TPP touch-only). Results in awkward shared-state passing.
- **Rejection reason**: 7-state FSM is a single conceptual machine per GDD §States and Transitions; physically splitting it across two Nodes invites coordination bugs without commensurate benefit. Test infrastructure cost outweighs the isolation benefit.

### Alternative 3: Dedicated `StateMachine` Resource pattern

- **Description**: Implement the 7-state FSM as a Godot `StateMachine` Resource (similar to `AnimationTree` / `StateChart` addons) with discrete `State` Resources and explicit Transition objects. InputRouter delegates dispatch to the resource.
- **Pros**: Visual editor authoring; declarative transition table; pluggable for new states without GDScript edits.
- **Cons**: 7 states with 100% synchronous deterministic transitions do not benefit from a generalized state-machine framework. Adds 1-2 layers of indirection (state lookup → transition match → callback). Performance unmeasurable but cognitive overhead real (developers must learn the framework before reading FSM logic). No third-party StateMachine addon is on this project's approved-libraries list (currently empty per technical-preferences.md).
- **Rejection reason**: YAGNI for 7 deterministic synchronous states. Inline match/dispatch (§5) is simpler, more grep-able, and consistent with the project's preference for concrete idioms over framework abstractions. Third-party addon adoption requires a separate ADR per technical-preferences governance.

### Alternative 4: Stateless-Static Utility Class (5-precedent ADR-0008→0007 pattern)

- **Description**: `class_name InputRouter extends RefCounted` + `@abstract` + all-static methods. State held in `static var` fields (FSM state, active_input_mode, undo windows).
- **Pros**: Consistency with the 5-precedent stateless-static pattern (ADR-0008 → ADR-0006 → ADR-0012 → ADR-0009 → ADR-0007); test isolation via G-15 reset pattern proven.
- **Cons**: **The pattern is architecturally incompatible.** `static var` fields ARE state, but the pattern's value (hot-path call sites, no instance lifecycle, no signal subscriptions) does not apply: InputRouter MUST receive engine event callbacks via `_input(event)` / `_unhandled_input(event)` which are Node lifecycle methods, NOT static methods. A `RefCounted` cannot be in the scene tree and cannot receive engine event callbacks directly. The only workaround is a wrapper Node that forwards to static methods — adding indirection without benefit. Additionally, InputRouter MUST consume 2 GameBus signals (per ADR-0002 `scene_transition_lifecycle` interface) — signal subscribers must be Object instances; static-method Callables (e.g., `Callable(SomeClass, "static_method")`) have undefined disconnect identity in GDScript 4.x because the class object is not a typical Object instance.
- **Rejection reason**: **Engine-level structural incompatibility**, not preference — both engine claims independently confirmed by godot-specialist 2026-04-30 Item 7 PASS. `_input` / `_unhandled_input` callback delivery + signal subscription identity both require an Object instance in the scene tree. The 5-precedent pattern applies to systems that are CALLED (Damage Calc / Unit Role / Hero DB / Balance/Data / Terrain Effect) — not systems that LISTEN (InputRouter). This rejection codifies the pattern's scope boundary: stateless-static is for stateless calculator/lookup systems; Node-based form is for event-listening systems.

---

## Consequences

### Positive
- **Foundation 4/5 → 5/5 Complete** — last Foundation-layer ADR; unblocks Camera + Battle HUD + Grid Battle ADRs simultaneously.
- **Single canonical name** — `InputRouter` registry-aligned; cross-doc drift eliminated (3 GDD edits applied 2026-04-30).
- **Dual-focus risk closed** — most-recent-event-class rule is engine-version-stable (works on 4.5, 4.6, projected 4.7+) per godot-specialist Item 1 PASS.
- **Test isolation pattern proven** — DI seam mirrors damage-calc story-006 RNG injection (11-story track record); first event-listening system test infrastructure can become reusable for Camera + Battle HUD.
- **5 OQs from architecture.md v0.4 partially resolved** in this ADR (Dual-focus CR-2 coherence; Scenario Progression OQ bucket 3 dual-focus + recursive Control disable + edge-to-edge subset; OQ-1 gamepad MVP scope; OQ-2 camera pan ownership clarified — Camera owns drag state, InputRouter does not gate; OQ-3 single-input-buffer ratified per ST-4).

### Negative
- **First HIGH-risk ADR** — sets precedent for engine-version verification rigor; future HIGH-risk ADRs (UI dual-focus pattern, ink-wash shader pipeline) must meet the same Verification Required bar.
- **Pattern divergence from 5-precedent stateless-static** — explicitly rejected pattern; risk that future Node-based ADRs (Camera, Battle HUD) drift toward stateless-static for "consistency" when their nature is event-listening. Mitigation: §Alternative 4 codifies the scope boundary.
- **Provisional contracts to 5 unwritten downstream ADRs** — interface drift risk if any downstream ADR negotiates rather than ratifies. Mitigation: 4-precedent track record (ADR-0008→0006 / ADR-0012→0009/0010/0011 / ADR-0009→0007 / ADR-0007→Formation Bonus) shows downstream ADRs consistently ratify; risk bounded.
- **Per-unit undo storage** — `_undo_windows: Dictionary` grows by entry per unit acted; pruned at battle-end. Memory footprint bounded by max units per battle (~16-24 per GDD); negligible.
- **2 implementation-time API verifications** — safe-area API name (§7) + DPI-pixel return (§5a) not confirmed in static reference docs; first-story implementer must verify against live 4.6 docs/source.

### Risks
- **R-1 — Dual-focus regression on engine patch** (Godot 4.6.x → 4.6.y or 4.7+): if Godot changes `_unhandled_input` ordering relative to `_gui_input`, InputRouter could intercept events meant for Controls. **Mitigation**: integration test fixture that creates a dummy Control with `mouse_filter = MOUSE_FILTER_STOP` and asserts InputRouter does NOT receive the consumed event; runs in CI per push.
- **R-2 — SDL3 gamepad detection latency on Bluetooth controller hot-plug**: Godot 4.5 SDL3 backend may take 1-2 frames to register a freshly-connected gamepad. Action emitted from a button press in those frames could be silently dropped. **Mitigation**: gamepad explicitly out of scope for MVP per §6; document in known-issues if observed during Polish. (godot-specialist 2026-04-30 Item 3 confirms hardware-layer concern that SDL3 does NOT solve.)
- **R-3 — `emulate_mouse_from_touch` regression**: a future contributor flips the project setting back ON (Godot's IDE default is `false` but a project preset import could re-enable). Touch events would synthesize fake mouse events, double-firing actions. **Mitigation**: CI lint script `tools/ci/lint_emulate_mouse_from_touch.sh` greps `project.godot` for the setting; fails if not explicitly `=false`.
- **R-4 — Static-var leakage in tests** (if Alternative 4 partially adopted): NOT applicable since Alternative 4 rejected. If a future contributor introduces `static var` for caching, the G-15 mirror pattern obligation must be enforced. **Mitigation**: forbidden_pattern `input_router_static_var_state_addition` codified in §Phase 6.
- **R-5 — Action vocabulary drift between code and `default_bindings.json`**: an action added in `ACTIONS_BY_CATEGORY` const but NOT in JSON (or vice versa) silently breaks the mapping. **Mitigation**: `_ready()` validation: every action in `ACTIONS_BY_CATEGORY` must exist in JSON, and every JSON action must exist in const. FATAL on mismatch; CI lint enforces by validating fresh-cloned project state.
- **R-6 — Touch index reuse on rapid lift+touch sequences**: OS-assigned touch indices may be recycled within a frame; CR-4g (two-finger gesture cancels first-finger selection) depends on stable index tracking. **Mitigation**: track touch state by `(index, contact_start_frame)` tuple; document the bookkeeping pattern. Per godot-specialist Advisory B, run integration test on iOS 17 + Android 14+ on **physical hardware** (NOT just emulator).

---

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|---|---|---|
| input-handling.md | CR-1 22-action vocabulary | §4 — `ACTIONS_BY_CATEGORY` const + `default_bindings.json` parity validation (R-5 mitigation) |
| input-handling.md | CR-1a no hover-only | §5 inline state machine — every PC hover path has a touch-equivalent action |
| input-handling.md | CR-1b external bindings | §4 — `assets/data/input/default_bindings.json` lazy-loaded via `JSON.new().parse()`; runtime mutable via `set_binding()` |
| input-handling.md | CR-2 last-device-wins mode | §3 — most-recent-event-class rule; `KEYBOARD_MOUSE` ↔ `TOUCH` enum; gamepad pass-through (§6) |
| input-handling.md | CR-2c state preserved on switch | §1 — `_active_mode` change does NOT reset `_state` or `_undo_windows` |
| input-handling.md | CR-2e `emulate_mouse_from_touch` disabled | §Verification Required §3 + R-3 mitigation (CI lint) |
| input-handling.md | CR-3 two-beat confirmation | §5 inline FSM — S2/S4 are explicit pre-confirm states; `action_confirm` only valid in S2/S4 |
| input-handling.md | CR-4a Tap Preview Protocol | §5 — TPP dispatch in OBSERVATION state when mode is TOUCH; dispatches `BattleHUD.show_unit_info` / `show_tile_info` (provisional contract §9) |
| input-handling.md | CR-4b 44px touch target | §7 — `DisplayServer.screen_get_size()` for `camera_zoom_min` derivation per F-1 |
| input-handling.md | CR-4c Magnifier Panel | §5 inline state — pan-vs-tap classifier triggers magnifier when tap_edge_offset < DISAMBIG_EDGE_PX OR tile_display_px < DISAMBIG_TILE_PX |
| input-handling.md | CR-4e MIN_TOUCH_DURATION_MS | §5 — F-3 classifier in dispatch path; tunable via `assets/data/input/touch_config.json` |
| input-handling.md | CR-4g two-finger = camera | §5 — touch index bookkeeping per R-6 mitigation |
| input-handling.md | CR-5 per-unit undo | §1 — `_undo_windows: Dictionary` keyed by unit_id; closes on attack/end-turn/end-phase |
| input-handling.md | F-1 camera_zoom_min derivation | §7 — `DisplayServer.screen_get_size()` provides logical pixels for the formula |
| input-handling.md | F-2 disambiguation trigger | §5 — inline classifier in TPP dispatch |
| input-handling.md | F-3 pan-vs-tap classification | §5 — inline classifier in `_handle_event` before state dispatch |
| input-handling.md | EC-1 multi-touch cancel | §5 — touch index bookkeeping cancels pending single-finger interaction |
| input-handling.md | EC-2 input during S5 | §5 — INPUT_BLOCKED dispatch arm silently drops grid actions; permits camera + read actions; calls `get_viewport().set_input_as_handled()` per Implementation Notes Advisory C |
| input-handling.md | EC-3 menu state restore | §1 — `_pre_menu_state` field; ST-2 demotion S2/S4 → S1 on restore |
| input-handling.md | EC-4 keyboard + touch same frame | §3 — last-event-class wins; correctness on next event |
| input-handling.md | EC-5 undo blocked by occupation | §5 — undo handler queries pre-move tile occupancy via Grid Battle (provisional §9) |
| input-handling.md | EC-7 out-of-range tile rejection | §5 — every transition queries `is_tile_in_*_range` (provisional §9) before commit |
| input-handling.md | EC-10 rapid state transitions | §5 — synchronous deterministic transitions; visual catch-up next frame per ST-4 |
| input-handling.md | AC-1..AC-18 | All 18 ACs map to one or more §1-§9 sections (full coverage table in `tr-registry.yaml` upon /architecture-review acceptance) |
| input-handling.md | OQ-1 gamepad scope | §6 — partially resolved: MVP gamepad → KEYBOARD_MOUSE; full GAMEPAD mode deferred to post-MVP ADR |
| input-handling.md | OQ-2 camera pan ownership | §9 — Camera owns drag state per provisional contract; InputRouter does NOT gate grid input mid-drag |
| input-handling.md | OQ-3 input buffer depth | §5 — single-tap buffer per ST-4 ratified; queue depth deferred (revisit at Polish if OQ-3 surfaces in playtest) |

---

## Performance Implications

- **CPU**: per-event dispatch < 0.05 ms on minimum-spec mobile (Adreno 610 / Mali-G57 class). Single dictionary lookup (`ACTIONS_BY_CATEGORY` membership) + match-arm dispatch + 1-3 signal emissions. Headless CI throughput baseline; on-device measurement deferred per damage-calc story-010 Polish-deferral pattern.
- **Memory**: `_undo_windows` Dictionary bounded by max units per battle (~16-24 entries × ~80 bytes each = ~2 KB). `_bindings` Dictionary bounded by 22 actions × ~120 bytes per InputEvent = ~3 KB. `_input_blocked_reasons` PackedStringArray bounded by max nesting depth (~3, observed). **Total InputRouter heap footprint: < 10 KB** << 512 MB mobile ceiling.
- **Load Time**: `_ready()` JSON parse of `default_bindings.json` (~22 actions × ~150 bytes = ~3.3 KB) is single-shot at autoload init; < 5 ms estimated. Lazy parse pattern same as ADR-0006/0007/0008/0009.
- **Network**: N/A — InputRouter is single-player.

---

## Migration Plan

### From `[no current implementation]`
No `src/foundation/input_router.gd` exists; clean greenfield. First story creates the file + autoload registration + minimal `_handle_event` skeleton.

### From GDD prose name "InputHandlingSystem"
Phase 4.7 GDD sync edits applied 2026-04-30 (3 occurrences in `design/gdd/input-handling.md` lines 378 / 708 / 811). One-line edits per occurrence; no semantic change. Applied in same patch as ADR-0005 Write per godot-specialist write-approval gate.

### Cross-system contract migration paths
- When Camera ADR lands: `Camera.screen_to_grid` and `camera_zoom_min` enforcement signatures are already locked here; Camera ADR ratifies with no negotiation. If Camera ADR proposes a different signature, this ADR-0005 must be amended (caught by `/architecture-review` cross-conflict scan).
- When Grid Battle ADR lands: same — `is_tile_in_*_range` signatures locked here.
- When Battle HUD ADR lands: same — `show_unit_info` / `show_tile_info` signatures locked here.
- When Settings/Options ADR lands: `set_binding(action, event)` signature locked here.
- When Tutorial ADR lands: subscribes to `input_action_fired` (no new contract required).
- When post-MVP gamepad ADR lands: adds `InputMode.GAMEPAD = 2` (additive enum value, not a renumber); existing call sites remain compatible.

### Implementation-time verification follow-ups (per godot-specialist 2026-04-30)
- First InputRouter story MUST verify `DisplayServer.screen_get_size()` returns logical (DPI-aware) pixels on Android against live 4.6 source/docs (Verification §5a).
- First InputRouter story MUST verify the exact 4.6 safe-area API method name + signature (Verification §5b); confirm against `DisplayServer.window_get_safe_title_margins()` (plural form candidate) OR fall back to `DisplayServer.window_get_position_with_decorations()` workaround.
- First InputRouter story MUST verify `[input_devices.pointing] emulate_mouse_from_touch=false` path in `project.godot` via Project Settings → Input Devices → Pointing in-editor (Verification §3 + godot-specialist Item 6).

---

## Validation Criteria

1. **Autoload registration**: `project.godot` contains `InputRouter="*res://src/foundation/input_router.gd"` at load order 4 (after GameBus + SceneManager + SaveManager). Boot test verifies `/root/InputRouter` is reachable from `_ready()` of a downstream node.
2. **22-action coverage parity**: `_ready()` validation pass — every action in `ACTIONS_BY_CATEGORY` exists in `default_bindings.json` AND vice versa; FATAL push_error + early-return on mismatch (R-5 mitigation). CI test fixture validates fresh-cloned project state.
3. **3 GameBus signal emission contracts**: per ADR-0001 TR-gamebus-001 — InputRouter emits exactly `input_action_fired(StringName, InputContext)` + `input_state_changed(int, int)` + `input_mode_changed(int)`; static lint `grep -c 'GameBus\.input_' src/foundation/input_router.gd` returns 3 emit call sites for the 3 signal names.
4. **Non-emitter invariant for all non-Input GameBus signals**: per ADR-0001 line 372-region — `grep -c 'GameBus\.' src/foundation/input_router.gd | grep -v '^GameBus\.input_'` returns 0 emit call sites (allows consumption of `ui_input_block_requested` / `ui_input_unblock_requested` per ADR-0002).
5. **DI seam test isolation**: every `tests/unit/foundation/input_router_test.gd` test suite calls `InputRouter._handle_event(synthetic_event)` directly (not via Godot's `Input.parse_input_event` path); `before_test()` resets `_state = OBSERVATION` + `_active_mode = KEYBOARD_MOUSE` + `_undo_windows.clear()` + `_input_blocked_reasons.clear()` (G-15 mirror pattern obligation).
6. **Dual-focus end-to-end test on Android 14+ + macOS Metal** (per Verification Required §1) — KEEP through Polish.
7. **`emulate_mouse_from_touch` lint gate** — `tools/ci/lint_emulate_mouse_from_touch.sh` greps `project.godot`; fails if `emulate_mouse_from_touch=true` or unset (R-3 mitigation).
8. **Per-method latency baseline** (headless CI): `_handle_event` < 0.05 ms; `_handle_action` dispatch < 0.02 ms. On-device measurement deferred to Polish per Polish-deferral pattern (stable at 6+ invocations as of ADR-0007).
9. **Cross-platform determinism**: same synthetic event sequence produces same FSM state transitions on macOS Metal + Linux Vulkan + Windows D3D12 (no float-point math in InputRouter; deterministic by construction).
10. **INPUT_BLOCKED set_input_as_handled call** (per Implementation Notes Advisory C): every silent-drop arm in INPUT_BLOCKED state calls `get_viewport().set_input_as_handled()` BEFORE returning; static lint asserts presence in the INPUT_BLOCKED arm of `_handle_event`.

---

## Related Decisions

- ADR-0001 GameBus (Accepted 2026-04-18) — non-emitter list line 375 region MUST update to remove `input-handling` (InputRouter IS an emitter for the 3 Input-domain signals, but stays on the non-emitter list for all OTHER 21 signals across 8 domains).
- ADR-0002 SceneManager (Accepted 2026-04-18) — `scene_transition_lifecycle` interface registry entry (line 216) lists `input-handling` as consumer of `ui_input_block_requested` / `ui_input_unblock_requested`; this ADR ratifies the consumer contract.
- ADR-0004 Map/Grid (Accepted 2026-04-20) — `tile_grid_runtime_state` registry entry (line 260) lists `input-handling` as consumer of `get_tile`; this ADR ratifies the consumer pattern (via Camera `screen_to_grid` indirection).
- Future: Camera ADR — will ratify `screen_to_grid` + `camera_zoom_min` enforcement.
- Future: Grid Battle ADR — will ratify `is_tile_in_move_range` + `is_tile_in_attack_range`.
- Future: Battle HUD ADR — will ratify `show_unit_info` + `show_tile_info`.
- Future: Settings/Options ADR — will ratify `set_binding` runtime remap contract.
- Future: post-MVP Gamepad ADR — will add `InputMode.GAMEPAD = 2` additive enum value.
