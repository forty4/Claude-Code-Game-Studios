# Input Handling System (입력 처리)

> **Status**: Designed
> **Author**: user + systems-designer, game-designer, ux-designer, gameplay-programmer
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 1 (형세의 전술) — input is how players express tactical intent

## Overview

The Input Handling System is the cross-platform input abstraction layer that
translates raw device signals — keyboard/mouse on PC, touch on mobile — into
semantic game actions consumed by every interactive system in the game. It owns
the mapping from physical input to logical intent: when a player taps a grid
cell, clicks a unit, or presses a hotkey, this system determines *what was
requested* and emits it as a device-agnostic action that Grid Battle, Camera,
UI, and all other consumers process without knowing or caring which device
produced it.

For the player, this system is invisible when working correctly and infuriating
when it isn't. Every tactical decision in 천명역전 — selecting a tile, commanding
a unit to move, confirming an attack, panning across the battlefield — begins as
input. The system must feel instantaneous and precise regardless of device: a tap
on a phone screen must feel as deliberate and responsive as a mouse click on PC.
Because this is a tactical game where a single misplaced unit can collapse a
formation (Pillar 1), input errors caused by ambiguity, lag, or imprecision are
not minor annoyances — they undermine the core promise of the game.

The system uses auto-detect mode switching: the last-used input device determines
the active input context. If a player on a tablet with a keyboard touches the
screen, the system switches to touch mode; if they press a key, it switches to
keyboard mode. No manual toggle is required. This GDD defines the foundational
action vocabulary (grid selection, unit commands, camera controls, menu navigation)
that downstream system GDDs will consume and extend.

## Player Fantasy

**The Strategist's Two Beats: Read the Field, Then Command**

The player is a 군사(軍師) surveying the battlefield from a hilltop. The
input system must honor the two-beat rhythm of strategic command: first you
read, then you speak.

**The first beat — reading (형세 파악)**. The strategist's gaze sweeps the
field. Panning across the map, inspecting tiles, checking unit stats and
terrain effects — all of this is exploratory and consequence-free. The player
should feel safe to browse the entire battlefield without fear of accidental
commitment. The device disappears; only the battlefield remains. This beat
should feel fluid, forgiving, and boundless — like scanning a war map spread
across a table.

**The second beat — commanding (명령)**. The strategist's will becomes action.
Selecting a unit, choosing a destination, confirming an attack — these are
deliberate and irreversible within the turn. This beat should feel crisp,
weighty, and final — like placing a stone on a Go board or sealing a war
order with a stamp. There is no ambiguity about what was commanded.

The wrong feeling is when these two beats blur together — when every touch
carries the anxiety of accidental commitment, or when commands feel as casual
as browsing. A misplaced tap that moves Guan Yu to the wrong tile doesn't
just cost a turn; it can collapse a formation that took three turns to build
(Pillar 1). The system must make reading feel safe and commanding feel
intentional, on every device, every time.

*Anchor moment*: The player pans the battlefield studying the enemy formation,
tapping tiles freely to check terrain and ranges. Everything feels exploratory.
Then they select Zhao Yun, see movement range light up, tap the flanking
position, and confirm. The tone shifts — the command locks in with weight and
finality. Two distinct feelings, one seamless flow.

## Detailed Design

### Core Rules

#### CR-1. Action Vocabulary

Every player intent is expressed as a device-agnostic `InputAction`. Consumer
systems (Grid Battle, Camera, HUD) subscribe to these actions only — they never
read raw input events.

| # | Action Name | Description | PC Default | Touch Gesture |
|---|-------------|-------------|-----------|---------------|
| **Grid Actions** | | | | |
| G-1 | `grid_select` | Select the highlighted tile or unit | Left-click | Single tap |
| G-2 | `grid_hover` | Move highlight cursor to a tile (PC only) | Mouse move over tile | N/A (see CR-4a) |
| G-3 | `grid_cursor_move` | Move highlight cursor by direction | Arrow keys / WASD | N/A (keyboard only) |
| G-4 | `unit_select` | Select a friendly unit | Left-click on unit / Enter | Tap on unit (second tap — see CR-4a) |
| G-5 | `move_target_select` | Choose a movement destination tile | Left-click on tile in range | Tap on tile in range |
| G-6 | `attack_target_select` | Choose an attack target | Left-click on enemy | Tap on enemy |
| G-7 | `action_confirm` | Confirm the pending command | Enter / Right-click confirm | Tap confirm button in action panel |
| G-8 | `action_cancel` | Cancel current selection / go up one level | Escape / Right-click | Back button / two-finger tap |
| G-9 | `end_unit_turn` | End selected unit's actions for this turn | Space | Tap "Wait" button in action panel |
| G-10 | `end_player_turn` | End entire player phase | E key | Tap "End Phase" button |
| **Camera Actions** | | | | |
| C-1 | `camera_pan` | Pan camera across battlefield | Middle-click drag / edge scroll | Single-finger drag on empty area |
| C-2 | `camera_zoom_in` | Zoom in | Scroll wheel up / + key | Pinch-out (two fingers apart) |
| C-3 | `camera_zoom_out` | Zoom out | Scroll wheel down / - key | Pinch-in (two fingers together) |
| C-4 | `camera_snap_to_unit` | Center camera on active unit | F key | Double-tap unit portrait in HUD |
| **Menu/UI Actions** | | | | |
| U-1 | `ui_confirm` | Confirm dialog/menu choice | Enter / Space | Tap confirm button |
| U-2 | `ui_cancel` | Close dialog / go back | Escape | Tap back button |
| U-3 | `ui_navigate` | Move focus in menus | Arrow keys / Tab | Swipe within menu |
| U-4 | `open_unit_info` | Open detail panel for highlighted unit | I key | Long-press on unit (500ms) |
| U-5 | `open_game_menu` | Open in-battle menu | P key / Menu key | Tap menu icon |
| **Meta Actions** | | | | |
| M-1 | `undo_last_move` | Undo last confirmed move (within undo window) | Z key / Ctrl+Z | Tap undo button in action panel |
| M-2 | `toggle_terrain_overlay` | Toggle terrain info overlay on all tiles | T key | Tap terrain icon in HUD |
| M-3 | `toggle_formation_overlay` | Toggle formation bonus overlay | Y key | Tap formation icon in HUD |

**Rule CR-1a.** No action may be bound to a hover-only interaction. Every PC
hover action must have an explicit activation equivalent on touch (tap, long-press,
or HUD button).

**Rule CR-1b.** All default bindings live in `assets/data/input/default_bindings.json`.
They are never hardcoded in GDScript. The system reads this file at startup and
populates Godot's `InputMap` accordingly.

**Rule CR-1c.** `grid_hover` (G-2) is a PC-only event so Camera and Battle HUD
can respond to cursor position. On touch, it is never emitted. Systems that show
previews on hover (movement range, tile info) must also trigger from the Tap
Preview Protocol (CR-4a) on touch.

---

#### CR-2. Input Mode Auto-Detection

**Rule CR-2a.** The system maintains `active_input_mode: enum { KEYBOARD_MOUSE, TOUCH }`.
Default at startup: `KEYBOARD_MOUSE` on PC, `TOUCH` on mobile.

**Rule CR-2b. Last-device-wins.** On each raw input event:
- `InputEventMouseButton` or `InputEventKey` → `KEYBOARD_MOUSE`
- `InputEventScreenTouch` or `InputEventScreenDrag` → `TOUCH`

Switch fires once per event, no debounce. Transition is invisible to the player.

**Rule CR-2c.** Mode switching does NOT reset game state. If a unit is selected
via touch and the player presses a keyboard key, the unit stays selected. The
new device takes over from exactly where the old device left off.

**Rule CR-2d.** HUD input hints update dynamically on mode switch (next frame).
"Tap to move" becomes "Click to move."

**Rule CR-2e. Godot project setting:** `emulate_mouse_from_touch` must be
**disabled** in production builds. Touch and mouse events are handled as
separate code paths for unambiguous device detection.

---

#### CR-3. Confirmation Flow (The Two-Beat Rule)

**Beat 1 — Reading (형세 파악): No confirmation, no consequences.**

| Action | Confirmation | Reason |
|--------|-------------|--------|
| Camera pan, zoom, snap | None | Pure exploration |
| `grid_hover` (PC) | None | No state change |
| Tap Preview (touch — CR-4a) | None | Info reveal only |
| `open_unit_info`, overlays | None | Read-only |
| Selecting a friendly unit → S1 | None | Reversible via cancel |

**Beat 2 — Commanding (명령): Explicit confirmation required.**

| Action | Confirmation Mechanism | Why |
|--------|----------------------|-----|
| Unit move | Tap/click destination → ghost preview → `action_confirm` | Move is undoable only before confirm |
| Unit attack | Tap/click target → damage preview → `action_confirm` | Attack is irreversible |
| End unit turn | Single press — no second confirmation | Action panel makes intent clear |
| End player turn | Two-step dialog ("End Phase?") → confirm | High stakes — wastes remaining actions |
| Destructive menu actions | Two-step dialog | Standard safety gate |

**Rule CR-3a.** Before `action_confirm` is valid, the game must display the
outcome: destination position for moves, expected damage for attacks. The player
confirms something visible, not abstract.

**Rule CR-3b.** The confirm button appears near the action point (ghost unit
position or attack target), not in a fixed screen corner. Fitts's Law: shorter
distance = faster, more accurate confirmation.

**Rule CR-3c.** No double-tap shortcut. The two-beat rhythm is strict: first
interaction = preview, confirm button = commit. This prevents accidental commits
and preserves the Tap Preview Protocol on touch.

---

#### CR-4. Touch-Specific Design

Touch introduces three problems absent from PC: no hover, finger occlusion,
and accidental touch.

**Problem 1: No Hover → Tap Preview Protocol (TPP)**

**Rule CR-4a.** When `active_input_mode == TOUCH` and state is `Observation`:
1. Player taps tile T.
2. Hit-test resolves target. If unit → show stats panel + range overlay.
   If empty tile → show terrain info.
3. A **preview bubble** appears 80–120px above the touch point (not centered
   on finger) showing tile/unit summary. Compensates for finger occlusion.
4. State remains `Observation`. No selection committed.
5. A second tap on the same unit → `unit_select`, state advances to S1.
6. A tap on a different element → dismiss previous preview, start new preview.

**Rule CR-4b. Touch target minimum.** All interactive elements must meet 44×44px
minimum hit area. Camera zoom is clamped so tiles never render below 44px on
the shortest dimension (see Formulas F-1).

**Problem 2: Finger Imprecision → Disambiguation**

**Rule CR-4c. Magnifier Panel.** When a touch lands within `DISAMBIG_EDGE_PX`
(default 8px) of a tile boundary, OR all tiles are smaller than `DISAMBIG_TILE_PX`
(default 55px):
1. Tile selection pauses.
2. Magnifier panel appears: 3×3 grid zoomed to 3× current scale, each tile
   labeled with terrain/unit info.
3. Player taps intended tile in magnifier.
4. Magnifier dismisses, normal flow continues.

**Rule CR-4d. Selection highlight.** Last-tapped tile retains a visible selection
ring until a different tile is tapped or state is cancelled. Confirms which tile
the system registered before the player commits.

**Problem 3: Accidental Touch → Intent Detection**

**Rule CR-4e. Minimum touch duration.** Contact shorter than `MIN_TOUCH_DURATION_MS`
(default 80ms) is rejected as accidental.

**Rule CR-4f. Pan vs. tap disambiguation.** A single-finger touch that moves more
than `PAN_ACTIVATION_PX` (default 12px) from the origin before release
→ classified as `camera_pan`. A touch within threshold → classified as tap.
See Formulas F-3.

**Rule CR-4g. Two-finger gestures.** Two simultaneous contacts are always camera
actions (pinch zoom or two-finger tap for cancel). Never interpreted as separate
selections. Second finger cancels any pending first-finger selection.

**Rule CR-4h. Action Panel.** Touch has no right-click. All context actions appear
in a persistent action panel at screen bottom, updating based on current state and
selected unit. Items are 44px tall minimum. Panel position adapts: appears on the
opposite side of the screen from the player's tap point to avoid occlusion.

---

#### CR-5. Undo/Cancel Rules

**Rule CR-5a. Undo Window.** `undo_last_move` (M-1) is valid after a move is
confirmed (S2 confirm → S0), but closes permanently when ANY of these occur:
- Player takes an attack with that unit
- Player presses `end_unit_turn` for that unit
- Player confirms `end_player_turn`

**Rule CR-5b. Per-unit, not per-turn.** Each unit has its own undo window.
If the player moves Unit A then Unit B, they can undo B's move, then A's
move, in reverse order. Undo depth: 1 move per unit.

**Rule CR-5c. Undo button visibility.** Always visible, dims when unavailable.
Communicates undo window state without hiding the affordance.

**Rule CR-5d. What undo restores.** Unit `coord` and `facing` revert. Tile
`occupant_id` updates. Unit `has_moved` flag clears. State returns to S1 so
the player can choose a different destination.

**Rule CR-5e. What undo does NOT restore.** Damage dealt, status effects from
terrain, enemy reactions triggered by the move. Undo is scoped to the player's
movement commitment only.

**Rule CR-5f. Undo blocked if tile occupied.** If the pre-move tile is now
occupied by another unit, undo is rejected with a brief "Cannot undo — tile
occupied" message.

---

### States and Transitions

The input state machine has 7 states. Every input event is processed against
the current state. Valid events fire signals to consumers; invalid events are
silently consumed.

```
S0: Observation          (default — reading beat)
S1: UnitSelected         (unit highlighted, action menu shown)
S2: MovementPreview      (destination chosen, ghost unit shown, awaiting confirm)
S3: AttackTargetSelect   (attack range shown, awaiting target)
S4: AttackConfirm        (target chosen, damage preview shown, awaiting confirm)
S5: InputBlocked         (enemy phase or animation — grid input gated)
S6: MenuOpen             (overlay menu/dialog active)
```

#### Transition Table

| From | Trigger | To | Side Effect |
|------|---------|-----|-------------|
| S0 | `unit_select` on friendly unit | S1 | Show action panel, movement/attack range overlay |
| S0 | `grid_select` on empty/enemy tile | S0 | Show tile/unit info (TPP on touch) |
| S0 | Camera actions | S0 | Camera moves |
| S0 | `open_game_menu` | S6 | Save `_pre_menu_state = S0`, open menu |
| S1 | `action_cancel` | S0 | Deselect unit, clear overlays |
| S1 | `move_target_select` on valid tile | S2 | Ghost unit at destination, confirm button appears |
| S1 | `attack_target_select` on valid enemy | S3 | Attack range overlay shown |
| S1 | `unit_select` on different friendly | S1 | Switch selection to new unit |
| S1 | `end_unit_turn` | S0 | Mark unit exhausted, deselect |
| S1 | Camera actions | S1 | Camera moves, selection preserved |
| S1 | `open_game_menu` | S6 | Save `_pre_menu_state = S1` |
| S2 | `action_confirm` | S0 | Unit moves, undo window opens |
| S2 | `action_cancel` | S1 | Clear destination, return to unit actions |
| S2 | Camera actions | S2 | Camera moves, selection preserved |
| S3 | `attack_target_select` on valid enemy | S4 | Show damage preview + confirm button |
| S3 | `action_cancel` | S1 | Return to unit actions |
| S3 | Camera actions | S3 | Camera moves |
| S4 | `action_confirm` | S0 | Attack resolves, unit action spent, no undo |
| S4 | `action_cancel` | S3 | Clear target, return to target selection |
| S5 | Camera actions, `open_unit_info`, overlays | S5 | Allowed — reading during enemy phase |
| S5 | Grid actions (G-1 through G-10) | S5 | Silently dropped |
| S5 | Enemy phase ends / animation completes | S0 | Restore to Observation |
| S6 | `ui_cancel` | `_pre_menu_state` | Restore prior state |
| S6 | Quit from menu | — | Save includes `_pre_menu_state` |

```
    ┌────────────────────────────────────────────┐
    │                                            │
    ▼                                            │
[S0: Observation] ──unit_select──▶ [S1: UnitSelected]
    │    ▲                          │  │  ▲
    │    │                     move │  │  │ cancel
    │    │                   target │  │  │
    │    │                          ▼  │  │
    │    │              [S2: MovementPreview]
    │    │                          │
    │    │◀────────confirm──────────┘
    │    │
    │    │         attack   [S3: AttackTargetSelect]
    │    │         target           │
    │    │           │         target_select
    │    │           │              ▼
    │    │           │     [S4: AttackConfirm]
    │    │◀──────────┘──────confirm─┘
    │
    │   open_menu        [S5: InputBlocked]
    └──────────▶ [S6: MenuOpen]     ▲ (enemy phase)
```

**Rule ST-1.** Only one state is active. S6 is not a stack — `_pre_menu_state`
stores the single prior state. Nested menus are handled within S6.

**Rule ST-2.** On menu restore: if `_pre_menu_state` is S2 or S4 (pending
confirm), restore to S1 instead. Pending confirmations are dropped on menu
interrupt to prevent phantom confirms on resume.

**Rule ST-3.** Every transition emits `input_state_changed(from, to)`. Grid
Battle, Camera, and Battle HUD subscribe to update overlays and enabled elements.

**Rule ST-4.** Input during animations: when a unit move animation plays, buffer
the first tap. Process it against the post-animation state when animation
completes. Discard if invalid.

---

### Interactions with Other Systems

#### What Input provides to consumers

| Consumer | Signals/Methods Received | Purpose |
|----------|-------------------------|---------|
| Grid Battle System | `unit_select`, `move_target_select`, `attack_target_select`, `action_confirm`, `action_cancel`, `end_unit_turn`, `end_player_turn`, `undo_last_move` | All unit commands |
| Camera System | `camera_pan`, `camera_zoom_in`, `camera_zoom_out`, `camera_snap_to_unit` | Camera control |
| Battle HUD | `input_state_changed` signal, `active_input_mode` property | Contextual UI |
| Settings/Options | `set_binding(action, event)` method | Key remapping |
| Tutorial System | `input_action_fired` signal | Tutorial triggers |

#### What Input requires from other systems

| Provider | Method/Data Required | Purpose |
|----------|---------------------|---------|
| Camera System | `screen_to_grid(screen_pos: Vector2) -> Vector2i` | Touch/click hit-testing |
| Grid Battle System | `is_tile_in_move_range(coord) -> bool`, `is_tile_in_attack_range(coord) -> bool` | Validate transitions |
| Battle HUD | `show_unit_info(unit_id)`, `show_tile_info(coord)` | TPP preview display |
| Balance/Data System | `assets/data/input/default_bindings.json` | Startup binding load |

#### Integration contract

- **Class**: `InputRouter` — Autoload Node at `/root/InputRouter`, load order 4 (after GameBus → SceneManager → SaveManager). `class_name` is canonical per ADR-0005 §2; "InputHandlingSystem" name is preserved in this GDD as a documentation alias only.
- **Signal**: `input_action_fired(action: StringName, context: Dictionary)` —
  emitted for every consumed action with context (target coord, unit ID, etc.)
- **Signal**: `input_state_changed(from: InputState, to: InputState)`
- **Signal**: `input_mode_changed(new_mode: InputMode)` — HUD hint updates
- **Read-only**: `get_current_state() -> InputState`
- **Read-only**: `get_active_input_mode() -> InputMode`
- **World input**: processed in `_unhandled_input()` (grid, camera)
- **Global hotkeys**: processed in `_input()` (escape, game menu)
- **AI bypass**: AI System calls Grid Battle directly, never through Input

## Formulas

Input Handling is primarily a state machine, not a calculation system. The
formulas below support touch interaction rules defined in CR-4.

### F-1. Minimum Zoom Constraint (Touch Target Enforcement)

```
camera_zoom_min = TOUCH_TARGET_MIN_PX / tile_world_size
```

| Variable | Symbol | Type | Range | Source |
|----------|--------|------|-------|--------|
| Minimum touch target | TOUCH_TARGET_MIN_PX | int | 44 (fixed) | technical-preferences.md |
| Tile size in world pixels | tile_world_size | int | 64 (fixed) | Map/Grid GDD |
| Minimum camera zoom | camera_zoom_min | float | 0.6875 → rounded to 0.70 | Derived |

**Result:** `44 / 64 = 0.6875`, rounded up to **0.70** for comfort margin.
At `camera_zoom = 0.70`, tiles render at 44.8px — above the 44px minimum.

**Constraint:** Camera System must clamp zoom to `[camera_zoom_min, camera_zoom_max]`.
This formula's output feeds directly into the Camera System GDD as a hard floor.

---

### F-2. Tap Disambiguation Trigger

```
needs_disambig = (tap_edge_offset < DISAMBIG_EDGE_PX)
                 OR (tile_display_px < DISAMBIG_TILE_PX)
```

| Variable | Symbol | Type | Range | Source |
|----------|--------|------|-------|--------|
| Tap distance from nearest tile edge | tap_edge_offset | float | 0 – tile_display_px/2 | Runtime measurement |
| Edge disambiguation threshold | DISAMBIG_EDGE_PX | int | 8 (default) | Tuning knob |
| Tile display size on screen | tile_display_px | float | 44.8 – 128 | `tile_world_size × camera_zoom` |
| Tile size disambiguation threshold | DISAMBIG_TILE_PX | int | 55 (default) | Tuning knob |
| Needs magnifier | needs_disambig | bool | — | Output |

**Example:** Player taps 6px from tile boundary, tiles are 48px on screen.
`6 < 8` → true. Magnifier panel appears.

---

### F-3. Pan vs. Tap Classification

```
is_pan = (touch_travel_px > PAN_ACTIVATION_PX)
is_tap = NOT is_pan AND (hold_duration_ms >= MIN_TOUCH_DURATION_MS)
is_rejected = (hold_duration_ms < MIN_TOUCH_DURATION_MS) AND NOT is_pan
```

| Variable | Symbol | Type | Range | Source |
|----------|--------|------|-------|--------|
| Touch travel distance | touch_travel_px | float | 0+ | Runtime measurement |
| Pan activation threshold | PAN_ACTIVATION_PX | int | 12 (default) | Tuning knob |
| Hold duration | hold_duration_ms | int | 0+ | Runtime measurement |
| Minimum touch duration | MIN_TOUCH_DURATION_MS | int | 80 (default) | Tuning knob |
| Is camera pan | is_pan | bool | — | Output |
| Is valid tap | is_tap | bool | — | Output |
| Is accidental (rejected) | is_rejected | bool | — | Output |

**Example:** Finger down, moves 5px, releases at 120ms.
`5 < 12` → not pan. `120 >= 80` → valid tap. Result: tap registered.

**Example:** Finger down, moves 20px in 90ms.
`20 > 12` → pan. Result: camera pan, no tile selection.

**Example:** Finger down, stays still, releases at 50ms.
`0 < 12` → not pan. `50 < 80` → rejected. Result: accidental, no action.

## Edge Cases

### EC-1. Multi-Touch During Single-Finger Operation

If a second finger touches while a tile is highlighted or a unit is being
acted on: the pending single-finger interaction is cancelled immediately.
Two-finger gesture takes priority. State reverts to S0 via implicit
`action_cancel`.

### EC-2. Input During Enemy Phase / Animations

All grid actions (G-1 through G-10) are silently dropped in S5 (InputBlocked).
Camera actions (C-1 through C-4), `open_unit_info` (U-4), and overlay toggles
(M-2, M-3) remain active — the player can continue reading the field while
the enemy phase executes. When a unit move animation plays during the player's
turn, the first tap is buffered and processed against the post-animation state
when the animation completes. Buffered input is discarded if invalid in the
post-animation state.

### EC-3. Menu State Restore

When S6 (MenuOpen) is entered and the player closes the menu normally,
`_pre_menu_state` is restored. **Exception:** if `_pre_menu_state` is S2
(MovementPreview) or S4 (AttackConfirm), restore to S1 (UnitSelected)
instead — pending confirmations are dropped to prevent phantom commits.
If the player quits the game from the menu, `_pre_menu_state` is saved.
On resume, the same S2/S4 → S1 demotion applies.

### EC-4. Keyboard and Touch in Same Frame

If a keyboard key and a touch event arrive in the same `_input` frame,
both are processed. The last one in Godot's event queue sets
`active_input_mode`. This is acceptable — the next input event from
either device will correct the mode.

### EC-5. Undo When Pre-Move Tile Is Occupied

If `undo_last_move` is triggered but the unit's pre-move tile is now occupied
by another unit that moved there during the same turn: undo is rejected. The
undo button dims and "Cannot undo — tile occupied" appears briefly. The move
stands. The player is not in an error state.

### EC-6. Long-Press Interrupted by Pan

If a long-press (500ms hold for `open_unit_info`) is initiated and the finger
moves more than `PAN_ACTIVATION_PX` before the 500ms threshold: the long-press
is cancelled and the interaction becomes `camera_pan`. The unit info panel
does not open.

### EC-7. Tile Out of Range Selected

If the player taps a tile that appears highlighted but is not actually in valid
range (e.g., rendering bug): the action is rejected. State remains unchanged.
No error dialog — the highlight simply does not change, giving implicit feedback.
Input always queries Grid Battle System for range validation.

### EC-8. Device Disconnection

If a gamepad is disconnected mid-action (future gamepad support): the system
switches to `KEYBOARD_MOUSE` mode. Any pending state is preserved per CR-2c.
If touch is the only remaining input method (mobile), `TOUCH` mode activates.

### EC-9. Magnifier Panel Edge-of-Screen

If the magnifier panel (CR-4c) would render partially off-screen because the
tap occurred near a screen edge: the magnifier is repositioned to stay fully
within the viewport, offset from the tap point as needed. The tap-to-tile
mapping within the magnifier adjusts accordingly.

### EC-10. Rapid State Transitions

If the player executes `unit_select` → `move_target_select` → `action_confirm`
faster than the visual system can update overlays (e.g., very fast keyboard
input): state transitions are processed immediately in sequence. Visual updates
catch up on the next frame. The state machine never waits for visuals — it is
the source of truth, and visuals are derived.

## Dependencies

### Upstream (this system depends on)

| System | Status | Dependency Type | What is needed |
|--------|--------|----------------|----------------|
| (none) | — | — | Foundation layer — no upstream dependencies |

Input Handling is a Foundation system with zero upstream dependencies.
It reads `default_bindings.json` from the data directory at startup, which
is managed by the Balance/Data System's loading pipeline, but this is a
file-read dependency, not a system dependency — Input can function without
the Balance/Data runtime.

### Downstream (these systems depend on this)

| System | Status | Dependency Type | What Input provides |
|--------|--------|----------------|---------------------|
| Grid Battle System | Not Started | Hard | All unit command actions (G-1 through G-10), `input_state_changed` signal |
| Camera System | Not Started | Hard | All camera actions (C-1 through C-4), `input_mode_changed` signal |
| Battle HUD | Not Started | Hard | `input_state_changed`, `active_input_mode` for contextual UI |
| Settings/Options | Not Started | Soft | `set_binding()` API for key remapping |
| Tutorial System | Not Started | Soft | `input_action_fired` signal for tutorial step detection |

### Bidirectional Contracts

**Input ↔ Camera System:** Input calls `screen_to_grid()` for touch hit-testing;
Camera subscribes to camera actions. Both must initialize before input processing
begins. Camera must enforce `camera_zoom_min = 0.70` from F-1.

**Input ↔ Grid Battle System:** Grid Battle publishes validity info
(`is_tile_in_move_range`, `is_tile_in_attack_range`); Input uses this to
validate state transitions. Input never performs its own range calculations.

**Input ↔ Battle HUD:** HUD exposes `show_unit_info()` and `show_tile_info()`
for TPP preview display. HUD reads `active_input_mode` to render appropriate
hints.

### Provisional Contracts

Grid Battle, Camera, and Battle HUD do not have GDDs yet. The interfaces
defined above are provisional and will be confirmed when those systems are
designed. Specifically:
- `screen_to_grid()` method signature and return type
- Range validation method signatures
- HUD info display method signatures

## Tuning Knobs

All knobs live in external JSON files under `assets/data/`. No input
constant is hardcoded in GDScript.

| # | Knob | Config File | Default | Safe Range | Too High | Too Low | Affects |
|---|------|------------|---------|-----------|----------|---------|---------|
| TK-1 | `long_press_duration_ms` | `input/touch_config.json` | 500 | 350–800 | Unit info never opens accidentally | Feels laggy, users give up waiting | Feel — info access speed |
| TK-2 | `min_touch_duration_ms` | `input/touch_config.json` | 80 | 50–150 | Accidental touches accepted | Deliberate taps rejected | Feel — touch sensitivity |
| TK-3 | `pan_activation_px` | `input/touch_config.json` | 12 | 8–20 | Pan never triggers, always tap | Pan triggers when tapping | Feel — tap vs. pan |
| TK-4 | `disambig_edge_px` | `input/touch_config.json` | 8 | 4–16 | Magnifier appears too often | Ambiguous border taps unresolved | Touch — disambiguation |
| TK-5 | `disambig_tile_px` | `input/touch_config.json` | 55 | 44–72 | Magnifier always on at normal zoom | Never shows when tiles are small | Touch — disambiguation |
| TK-6 | `camera_zoom_min` | `camera/camera_config.json` | 0.70 | 0.6875–0.85 | Cannot zoom out to see battlefield | Tiles below 44px touch target | Gate — touch target minimum |
| TK-7 | `camera_zoom_max` | `camera/camera_config.json` | 2.0 | 1.5–3.0 | Very large tiles, disorienting | Cannot inspect detail | Gate — zoom ceiling |
| TK-8 | `preview_bubble_offset_px` | `input/touch_config.json` | 100 | 60–150 | Bubble too far from context | Bubble hidden behind finger | Touch — occlusion compensation |

**Tuning guidance:**
- TK-1 through TK-3 are "feel" knobs — iterate during playtesting on actual
  mobile devices. Desktop testing with mouse clicks will not surface the right
  values.
- TK-4 and TK-5 interact: if `disambig_tile_px` is set high (e.g., 72), the
  edge threshold (TK-4) becomes less relevant because the magnifier triggers
  on tile size alone.
- TK-6 is a hard constraint derived from F-1. Lowering it below 0.6875 violates
  the 44px touch target requirement from technical-preferences.md.

## Visual/Audio Requirements

### Visual Feedback by State

| State | Visual Cue | Purpose |
|-------|-----------|---------|
| S0 → tile hovered (PC) | Soft highlight on tile border | "You're looking here" |
| S0 → tile tapped (touch) | Preview bubble + soft highlight | TPP — info without commitment |
| S0 → S1 (unit selected) | Unit pulses/glows, range overlay appears, non-actionable tiles dim | Mode shift — "you are now commanding" |
| S1 → S2 (move destination chosen) | Ghost unit at destination, path line shown, confirm button appears | "This is what will happen" |
| S2 confirm → S0 (move executed) | Unit slides to destination, brief snap animation | Commitment feedback |
| S3 → S4 (attack target chosen) | Damage preview numbers, target highlighted in attack color | "This is the expected result" |
| S4 confirm → S0 (attack executed) | Attack animation + damage numbers | Consequence made visible |
| Any → S0 (cancel) | Overlays dissolve, neutral colors restore | "Safe again" |

### Mode Transition Micro-Animations

- **Entering Command Mode (S0 → S1):** Brief "snap" animation (~100ms) —
  camera subtly tightens on selected unit, range overlay expands outward
  from unit position. Creates physical weight for the transition.
- **Returning to Observation (any → S0):** Soft dissolve (~150ms) — overlays
  fade, camera eases back. Asymmetric timing (sharp entry, soft exit)
  reinforces "commanding is deliberate, canceling is safe."

### Audio Feedback

| Event | Sound Type | Notes |
|-------|-----------|-------|
| Unit selected | Soft click / paper unfurl | Tactile, not aggressive |
| Move confirmed | Seal stamp / decisive tap | Weight and finality |
| Attack confirmed | Brush stroke / impact hint | Anticipation, not the attack itself |
| Cancel / undo | Soft swoosh / paper fold | Effortless reversal |
| Invalid action (silent drop) | No sound | Silence = "nothing happened" |
| Magnifier panel open | Subtle lens focus sound | Contextual without alarm |

Every audio event must have a visual equivalent (flash, bounce, color change)
for players without sound.

## UI Requirements

### Action Panel (Touch)

A persistent contextual panel at the screen bottom (or side on landscape
mobile). Updates based on current input state and selected unit.

| State | Panel Contents |
|-------|---------------|
| S0 | Empty or showing "Select a unit" hint |
| S1 | Move / Attack / Wait / Info / Cancel buttons |
| S2 | Confirm Move / Cancel buttons |
| S3 | "Select target" hint / Cancel button |
| S4 | Confirm Attack / Cancel buttons + damage preview |
| S5 | "Enemy phase..." indicator |

- All buttons minimum 44px tall
- Panel repositions to opposite side of screen from last tap point (anti-occlusion)
- On PC with keyboard/mouse: panel is optional (right-click and hotkeys suffice),
  but visible by default for discoverability

### Input Hints

- Dynamic text/icon overlay showing context-appropriate control hints
- Updates immediately on `input_mode_changed` signal
- Examples: "Click to select" / "Tap to select", "Enter to confirm" / "Tap ✓"
- Positioned near the action point, not in a fixed HUD corner

### Undo Button

- Always visible in action panel area
- Bright when undo is available, dimmed (not hidden) when unavailable
- Shows tooltip "Undo last move (Z)" on PC hover

### Magnifier Panel (Touch)

- Appears centered on tap point, 3×3 zoomed grid
- Semi-transparent background behind magnifier
- Each tile in magnifier shows: terrain icon, unit icon (if occupied), tile coord
- Tapping outside the magnifier dismisses it without selecting

### Accessibility UI

- Adjustable touch target size option in Settings (scales all interactive elements)
- Keyboard cursor repeat rate and initial delay adjustable (default 300ms / 80ms)
- Movement range and attack range must be distinguishable by pattern, not color
  alone (hatching, dashed borders, or shape markers)
- Hold-to-confirm option for End Turn (default off, accessibility setting)
- All input feedback has both audio and visual channels

## Acceptance Criteria

### Action System

**AC-1. Action vocabulary completeness.**
GIVEN a battle scene is loaded, WHEN the player uses keyboard/mouse to:
select a unit, preview movement, confirm move, select attack target, confirm
attack, end turn, pan camera, zoom, open unit info — THEN each fires exactly
one `input_action_fired` signal with the correct action name. No raw
InputEvent is consumed by any system other than InputRouter (per ADR-0005 §2 canonical name; "InputHandlingSystem" GDD prose alias).

**AC-2. Binding externalization.**
GIVEN `assets/data/input/default_bindings.json` maps `action_confirm` to
`KEY_ENTER`, WHEN the file is edited to map it to `KEY_SPACE` and the game
is restarted — THEN Space triggers `action_confirm` without code changes.

### Auto-Detection

**AC-3. Mode switching.**
GIVEN the game is in `KEYBOARD_MOUSE` mode, WHEN a touch event arrives —
THEN `active_input_mode` switches to `TOUCH` within the same frame, and
HUD hint icons update on the next frame.

**AC-4. State preservation on switch.**
GIVEN a unit is selected via touch (state S1), WHEN the player presses a
keyboard key — THEN `active_input_mode` switches to `KEYBOARD_MOUSE` and
the unit remains selected (state stays S1).

### Touch Protocol

**AC-5. Tap Preview Protocol.**
GIVEN state is S0 and `active_input_mode` is TOUCH, WHEN the player taps a
tile containing a friendly unit — THEN: unit info panel appears, range
overlay appears, preview bubble appears above the touch point, and state
remains S0. WHEN the player taps the same unit again — THEN state transitions
to S1.

**AC-6. Touch target minimum.**
GIVEN camera is at minimum zoom (0.70), WHEN tile size is measured — THEN
no tile measures less than 44 logical pixels on its shortest axis.

**AC-7. Magnifier trigger.**
GIVEN tiles are 48px and a touch lands 6px from a tile boundary — WHEN the
tap is processed — THEN the magnifier panel appears showing the 3×3 cluster.

**AC-8. Pan vs. tap classification.**
GIVEN a touch begins and moves 20px within 100ms — WHEN classified — THEN
it is classified as `camera_pan` and no tile selection occurs.

**AC-9. Accidental touch rejection.**
GIVEN a touch begins and releases after 50ms without movement — WHEN
classified — THEN it is rejected (50 < 80ms) and no action fires.

### Confirmation Flow

**AC-10. Two-beat move confirmation.**
GIVEN a unit is in S1 and a valid destination is visible, WHEN the player
taps the destination — THEN the game enters S2, ghost unit appears, confirm
button appears. WHEN the player taps confirm — THEN the unit moves, state
returns to S0.

**AC-11. End-player-turn safety gate.**
GIVEN the player taps "End Phase" — THEN a confirmation dialog appears.
The phase does not end until the player explicitly confirms the dialog.

### Undo

**AC-12. Undo window valid.**
GIVEN a unit has confirmed a move (S2 → S0), WHEN `undo_last_move` is
triggered before attack or end-turn — THEN the unit returns to pre-move
tile, `has_moved` clears, state enters S1.

**AC-13. Undo rejected after attack.**
GIVEN a unit has confirmed an attack (S4 → S0), WHEN `undo_last_move` is
triggered — THEN action is rejected, undo button is disabled.

**AC-14. Undo blocked by tile occupation.**
GIVEN a unit moved from tile A to tile B, and another unit then moved to
tile A — WHEN undo is triggered for the first unit — THEN undo is rejected
with "Cannot undo — tile occupied" message.

### State Machine

**AC-15. State transition signal.**
GIVEN any state transition occurs — THEN `input_state_changed(from, to)` is
emitted exactly once before any downstream processing.

**AC-16. Menu state preservation.**
GIVEN state is S2 and the player opens the game menu — WHEN the menu is
closed — THEN state restores to S1 (not S2), because pending confirmations
are dropped.

**AC-17. Input blocked during enemy phase.**
GIVEN S5 is active, WHEN the player attempts `unit_select` — THEN the action
is silently dropped. Camera pan and `open_unit_info` still function.

**AC-18. No hover-only interactions.**
GIVEN `active_input_mode` is TOUCH, WHEN every interactive element is tested
— THEN every action reachable via PC hover has an equivalent touch activation
(tap, long-press, or HUD button).

## Open Questions

### OQ-1. Gamepad Full Support Scope

Partial gamepad support is noted in technical-preferences.md. When full gamepad
is added, does it get its own input mode (`GAMEPAD`) or share `KEYBOARD_MOUSE`?
Gamepad cursor navigation on a grid works differently from mouse (continuous vs.
discrete). Defer to Camera System GDD and Settings/Options GDD.

### OQ-2. Camera Pan Ownership

Does the Camera System own its own drag state, or does InputRouter need
a dedicated `CameraPanning` state that gates grid input during a drag? Current
design keeps camera actions pass-through (no state change), but if camera pan
needs to block grid selections mid-drag, the state machine needs adjustment.
Resolve when Camera System GDD is authored.

### OQ-3. Input Buffering Depth During Animations

ST-4 defines buffering one tap during animation. Should we buffer a queue of
inputs (e.g., player queues `unit_select` + `move_target_select` during a
lengthy animation)? Risk: unexpected rapid execution when animation ends.
Recommend single-input buffer (current design) and test during prototyping.

### OQ-4. Magnifier Panel Effectiveness

The magnifier panel (CR-4c) is a novel touch UX element. Its usability is
unproven. Needs dedicated playtesting on actual mobile devices during prototype
phase. May be replaced by a simpler "zoom-to-area" approach if it proves clunky.

### OQ-5. Action Panel Position on Landscape Tablets

Bottom panel works well on phones. On landscape tablets (larger screen, wider
aspect ratio), should the action panel move to the side? Or should it remain
bottom-aligned for consistency? Resolve during Battle HUD design or UX spec.
