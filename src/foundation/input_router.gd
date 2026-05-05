## InputRouter — Foundation-layer Autoload Node for cross-platform input handling.
##
## Implemented: story-001 (2026-05-06) — module skeleton + enums + payload types +
## autoload registration. Replaces the PLACEHOLDER created during battle-hud story-001.
##
## Governance:
##   ADR-0005 (form-level): Autoload Node + 6 fields + 7-state FSM + 22-action vocab +
##              InputMode enum + 17 TRs + 4 base forbidden_patterns
##   ADR-0020  (dispatch-level): 4-phase _handle_event dispatch sequence + sole-state-
##              mutating-method invariant + caller allow-list + 4 net-new forbidden_patterns
##
## Autoload boot position 9 — after GameBus → SceneManager → SaveManager →
## GameBusDiagnostics → BuildModeSentinel → ScenarioRunner → DestinyState → StoryEvent.
## Consumes ui_input_block_requested + ui_input_unblock_requested (story-007 wires
## subscriptions). Emits input_action_fired + input_state_changed + input_mode_changed
## via GameBus (story-002+ wires emission).
##
## Responsibility by story:
##   story-001 (this): type system + 6 fields + 2 enums + 4 method stubs + registration
##   story-002: 22-action StringName vocabulary + bindings JSON load + InputMap population
##   story-003-004: 7-state FSM transition logic + state-transition signal emit
##   story-005: last-device-wins mode determination + input_mode_changed emit
##   story-006: per-unit undo window open/close + EC-5 occupied-tile rejection
##   story-007: S5 INPUT_BLOCKED + S6 MENU_OPEN + GameBus signal subscriptions
##   story-008-009: touch protocol (TPP + pan-vs-tap + two-finger + safe-area)
##   story-010: epic terminal — perf baseline + forbidden_pattern lints
##
## NOTE: class_name InputRouter was verified at story-001 implementation time. Godot 4.6
## fires "Parse Error: Could not parse global class InputRouter" when both class_name and
## autoload registration are present — G-3 CONFIRMED applies to this project. class_name
## is OMITTED. Reference via load("res://src/foundation/input_router.gd") in tests.
## ADR-0020 §Decision §6 footnote ("G-3 verification SETTLED") is corrected: G-3 FIRES.
extends Node


## InputState — 7-state FSM enum per ADR-0005 §1.
##
## S0..S6 ordinals are wire-format (save/load forward-compat per ADR-0005 §5).
## Names + ordinals are ratified contract surface — do NOT renumber or rename.
enum InputState {
	OBSERVATION = 0,           ## S0 — reading beat (default)
	UNIT_SELECTED = 1,         ## S1 — unit highlighted, action menu shown
	MOVEMENT_PREVIEW = 2,      ## S2 — destination chosen, ghost shown, awaiting confirm
	ATTACK_TARGET_SELECT = 3,  ## S3 — attack range shown, awaiting target
	ATTACK_CONFIRM = 4,        ## S4 — target chosen, damage preview shown, awaiting confirm
	INPUT_BLOCKED = 5,         ## S5 — enemy phase or animation; grid input silenced
	MENU_OPEN = 6,             ## S6 — overlay menu/dialog active
}

## InputMode — 2-value enum per ADR-0005 §1 + CR-2.
##
## KEYBOARD_MOUSE = 0, TOUCH = 1. Gamepad routes to KEYBOARD_MOUSE for MVP per OQ-1.
## Future GAMEPAD mode reserved at int 2 per ADR-0005 §6 — NOT declared in MVP scope.
## Mode switch does NOT reset game state (CR-2c). HUD hints update next frame (CR-2d).
enum InputMode {
	KEYBOARD_MOUSE = 0,        ## PC input: keyboard, mouse, or gamepad (MVP: routed here)
	TOUCH = 1,                 ## Mobile/tablet: touch events
}


# ── Instance fields (ADR-0005 §1 line 119) ───────────────────────────────────
# Exactly 6 fields. Types and defaults are ratified contract surface — do NOT
# modify without updating ADR-0005 §1 and TR-input-handling-002.

## Current FSM state. Transitions via _handle_event (story-003+).
var _state: InputState = InputState.OBSERVATION

## Most-recently-detected input device mode (last-device-wins per CR-2).
var _active_mode: InputMode = InputMode.KEYBOARD_MOUSE

## FSM state before S6 MENU_OPEN was entered; restored on menu close (story-007).
var _pre_menu_state: InputState = InputState.OBSERVATION

## Per-unit undo windows; key = unit_id int, value = UndoEntry (story-006 populates).
var _undo_windows: Dictionary[int, UndoEntry] = {}

## Stack of block reasons from SceneManager ui_input_block_requested (story-007).
var _input_blocked_reasons: PackedStringArray = []

## Runtime key-binding overrides per action (story-002 loads from JSON; story-002
## also implements set_binding). Key = action StringName, value = Array of
## InputEvent. NOTE: declared as `Dictionary[StringName, Array]` (not
## `Dictionary[StringName, Array[InputEvent]]`) because Godot 4.6 does not yet
## support nested typed collections — `Array` element type is enforced by
## set_binding(action, event) signature + ADR-0005 §1 contract.
var _bindings: Dictionary[StringName, Array] = {}


# ── Public API ────────────────────────────────────────────────────────────────

## Returns the currently active input mode (KEYBOARD_MOUSE or TOUCH).
##
## Callers: BattleHUD._on_input_mode_changed (per ADR-0015 §5); story-002+ emits
## input_mode_changed via GameBus on mode transitions.
func get_active_input_mode() -> InputMode:
	return _active_mode


## Returns the current FSM state (S0..S6).
##
## Callers: BattleHUD._on_input_state_changed (per ADR-0015 §5); test assertions.
func get_state() -> InputState:
	return _state


## Overrides the default binding for an action at runtime (CR-1b runtime remap).
##
## Sole external caller: Settings/Options scene per ADR-0005 §Soft/Provisional (4).
## Story-002 implements the body (loads default_bindings.json; this stub is a
## type-system placeholder only).
func set_binding(action: StringName, event: InputEvent) -> void:
	pass  # story-002 implements: updates _bindings[action] + InputMap


## Internal dispatch entry point — DI seam for synthetic event injection from tests.
##
## ADR-0020 §Decision §1 locks the 4-phase dispatch sequence:
##   Phase 1: mode-determine via pure-function _determine_mode_from_event
##   Phase 2: action-resolve via InputMap lookup
##   Phase 3: state-transition via inline match dispatch
##   Phase 4: signal-emit pair (input_state_changed FIRST, input_action_fired SECOND)
##
## Sole PRODUCTION caller: _unhandled_input (story-002 wires). The only non-test
## external caller allowed per ADR-0020 §Decision §1 is BattleHUD undo dispatch
## (sole production exception per ADR-0015 §5 line 627). Story-003+ implements body.
func _handle_event(event: InputEvent) -> void:
	pass  # story-003+ implements: 4-phase dispatch per ADR-0020 §Decision §1
