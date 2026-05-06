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

## Test-observable field for story-002: last action matched by _handle_event.
## Replaced by full dispatch signal in story-003. Field remains for backward-
## compat with story-002 source-scan structural asserts; now reflects "last action
## that successfully dispatched" (set before _handle_action call).
var _last_matched_action: StringName = &""

## Provisional Grid Battle reference (typed Variant — GridBattleController class
## doesn't exist yet; story-014 narrows when Grid Battle ADR ships). Production
## sets via set_grid_battle() at battle prep time. Tests inject via
## set_grid_battle_for_tests(). Used by S2 confirm arm + S1 range validation.
var _grid_battle: Variant = null

## Transient scratch state for AC-11 end-player-turn 2-beat confirmation flow.
## NOT counted in ADR-0005 §1's 6-field architectural-field list — implementation-
## internal scratch, scoped per action sequence (set by `&"end_player_turn"` first
## beat, reset by `&"end_phase_confirm"` second beat OR `&"action_cancel"`).
## G-15 obligation: `before_test()` resets to `false` (story-010 lint enforces).
var _pending_end_phase: bool = false

## Transient flag set by per-state arms when they execute observable behavior
## (state change OR re-targeting ctx-update OR end-phase gate toggle). Reset
## at start of each `_handle_action` dispatch. Drives the action_fired emit
## decoupling from state_changed emit per story-004 AC-8 re-targeting case.
##
## INVARIANT: written EXCLUSIVELY inside `_handle_action` and its callee per-
## state arms (`_handle_action_in_s0..s6`). Never written from `_handle_event`,
## public API, or any other dispatch path. Reset-on-entry at line 313 is the
## sole "init" point; the auto-set at line 331 + per-arm explicit `= true` are
## the sole "set" points. Story-010 lint will enforce this invariant.
##
## RE-ENTRANCY NOTE: synchronous re-entry of `_handle_action` from a signal
## subscriber (NOT CONNECT_DEFERRED — production violates ADR-0001 §5 if it
## happens) would mutate this field mid-dispatch and corrupt the outer call's
## emit decision. Production safety relies on the ADR-0001 §5 deferred-connect
## mandate. The story-003 AC-7 reentrancy test documents the synchronous
## re-entry contract; story-007 + downstream consumers must use CONNECT_DEFERRED.
var _did_visible_work: bool = false


# ── Action vocabulary (ADR-0005 §4 + TR-input-handling-003) ──────────────────

## Canonical 22-action vocabulary partitioned into 4 semantic categories.
##
## Callers: _handle_event (iterates categories → actions for InputMap lookup);
##          _validate_r5_parity (counts declared vs bound actions for R-5 check);
##          tests (structural + runtime count assertions).
## Governance: ADR-0005 §4 — action names + categories are ratified contract
##             surface. Do NOT rename or move actions without updating ADR-0005,
##             default_bindings.json, and TR-input-handling-003.
## G-25 NOTE: `Dictionary[StringName, Array[StringName]]` is NOT valid GDScript
##            4.6 syntax (nested typed collections forbidden). Declared as
##            `Dictionary[StringName, Array]` with StringName element type
##            enforced by the literal initialiser values (&"..." syntax).
const ACTIONS_BY_CATEGORY: Dictionary[StringName, Array] = {
	&"grid": [
		&"unit_select", &"move_target_select", &"move_confirm", &"move_cancel",
		&"attack_target_select", &"attack_confirm", &"attack_cancel",
		&"undo_last_move", &"end_unit_turn", &"grid_hover",  # grid_hover = PC-only per CR-1c
	],
	&"camera": [
		&"camera_pan", &"camera_zoom_in", &"camera_zoom_out", &"camera_snap_to_unit",
	],
	&"menu": [
		&"open_unit_info", &"open_game_menu", &"close_menu",
		&"end_player_turn", &"end_phase_confirm",
	],
	&"meta": [
		&"action_confirm", &"action_cancel", &"toggle_input_hints",
	],
}


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
## Replaces ALL prior bindings for the action (single-event-per-action override
## per CR-1b). Clears old InputMap events and registers the new one.
func set_binding(action: StringName, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	# Clear all prior InputMap events for this action
	for old_event: InputEvent in _bindings.get(action, []):
		InputMap.action_erase_event(action, old_event)
	InputMap.action_add_event(action, event)
	_bindings[action] = [event]


## Internal dispatch entry point — DI seam for synthetic event injection from tests.
##
## ADR-0020 §Decision §1 locks the 4-phase dispatch sequence:
##   Phase 1: mode-determine via _determine_mode_from_event — IMPLEMENTED (story-005)
##            Prepends mode detection + input_mode_changed emit before action match.
##   Phase 2: action-resolve via InputMap lookup (story-002: stores _last_matched_action)
##   Phase 3: state-transition via inline match dispatch (story-003+)
##   Phase 4: signal-emit pair (story-003+)
##
## Sole PRODUCTION caller: _unhandled_input (wired at story-002). The only non-test
## external caller allowed per ADR-0020 §Decision §1 is BattleHUD undo dispatch
## (sole production exception per ADR-0015 §5 line 627).
## Story-003+ replaces _last_matched_action store with full _handle_action dispatch.
func _handle_event(event: InputEvent) -> void:
	# Phase 1: mode determination (BEFORE action match per ADR-0005 §3 + ADR-0020 §1)
	var detected_mode: InputMode = _determine_mode_from_event(event)
	if detected_mode != _active_mode:
		_active_mode = detected_mode
		GameBus.input_mode_changed.emit(int(_active_mode))
	# Phase 2: action-resolve via InputMap lookup
	for category: StringName in ACTIONS_BY_CATEGORY.keys():
		for action: StringName in ACTIONS_BY_CATEGORY[category]:
			if not InputMap.has_action(action):
				continue  # defensive: skip actions not registered (e.g. grid_hover PC-only)
			if InputMap.action_has_event(action, event):
				_last_matched_action = action
				_handle_action(action, _make_context_from_event(event))
				return  # first match wins
	_last_matched_action = &""  # no match


## Routes unhandled input events through _handle_event after Controls have had
## first-pass dispatch via _gui_input (dual-focus 4.6 architecture per ADR-0005
## §1 + delta #6 Advisory C). Uses _unhandled_input NOT _input so Control focus
## layer is preserved above InputRouter.
##
## Sole PRODUCTION entry point from the engine input pipeline (story-002+).
func _unhandled_input(event: InputEvent) -> void:
	_handle_event(event)


## Test-only seam for injecting a Grid Battle stub. Production injection happens
## via a separate `set_grid_battle()` callable at Battle Preparation scene-load
## time (battle-prep ADR pending). Naming distinguishes test vs production seams.
##
## Per ADR-0005 §Soft/Provisional (2): `_grid_battle` is typed Variant because
## GridBattleController class doesn't exist yet; story-014 narrows when Grid
## Battle ADR ships.
func set_grid_battle_for_tests(stub: Variant) -> void:
	_grid_battle = stub


# ── Boot / lifecycle ──────────────────────────────────────────────────────────

## Path to the default bindings JSON. Override-able via _load_bindings_from_path
## for tests that exercise the negative paths (missing file / bad JSON / non-Dict
## top-level). Production calls go through _ready → _load_bindings_from_path with
## this constant.
const DEFAULT_BINDINGS_PATH: String = "res://assets/data/input/default_bindings.json"

## Loads default_bindings.json, populates InputMap, and validates R-5 parity.
## Thin orchestrator over _load_bindings_from_path → _populate_input_map →
## _validate_r5_parity. The seam at _load_bindings_from_path lets tests verify
## the missing-file / bad-JSON / non-Dictionary-top-level guard paths (AC-3).
func _ready() -> void:
	var bindings_dict: Dictionary = _load_bindings_from_path(DEFAULT_BINDINGS_PATH)
	if bindings_dict.is_empty():
		return  # _load_bindings_from_path already emitted push_error on failure
	_populate_input_map(bindings_dict)
	_validate_r5_parity(bindings_dict)


## Loads a bindings JSON file from the given res:// path and returns the parsed
## top-level Dictionary, or an empty Dictionary {} on any failure.
##
## Pattern: FileAccess.get_file_as_string + JSON.new().parse per ADR-0006/0007/
## 0008/0009 4-precedent. push_error fires (non-aborting — degraded operation)
## on any of: file missing or empty, JSON parse error, top-level value is not a
## Dictionary. Returns {} as the failure sentinel; callers check is_empty().
##
## DI seam: tests pass a fixture path (e.g. tests/fixtures/input/...) or a
## deliberately invalid path to exercise the AC-3 negative paths.
func _load_bindings_from_path(path: String) -> Dictionary:
	var content: String = FileAccess.get_file_as_string(path)
	if content.is_empty():
		push_error("InputRouter: bindings file missing or empty at %s" % path)
		return {}
	var json := JSON.new()
	var parse_result: int = json.parse(content)
	if parse_result != OK:
		push_error(
			"InputRouter: bindings parse error at %s: %s" % [path, json.get_error_message()]
		)
		return {}
	if not (json.data is Dictionary):
		push_error("InputRouter: bindings top-level at %s must be a Dictionary" % path)
		return {}
	return json.data as Dictionary


# ── Private helpers ───────────────────────────────────────────────────────────

## Constructs a minimal InputContext from a raw InputEvent. Story-003 scope:
## empty context (target_coord=ZERO, target_unit_id=-1). Story-008-009 narrows with
## screen→grid coord conversion.
## Production callers wire ctx fields via downstream Battle HUD interactions
## (ADR-0015 §5); for now, dispatch happens with empty ctx — _handle_action
## arms validate ctx fields before allowing transitions.
func _make_context_from_event(_event: InputEvent) -> InputContext:
	return InputContext.new()


## Determines the input mode from a single raw event — pure function, no side effects.
##
## Implements CR-2 most-recent-event-class rule per ADR-0005 §6:
##   - InputEventScreenTouch / InputEventScreenDrag → TOUCH
##   - InputEventMouseButton / InputEventMouseMotion / InputEventKey → KEYBOARD_MOUSE
##   - InputEventJoypadButton / InputEventJoypadMotion → KEYBOARD_MOUSE (OQ-1 MVP
##     partial: full GAMEPAD mode deferred; future ADR may add int 2 at Settings/Options)
##   - Unknown event class → preserve current _active_mode (defensive; no flip)
##
## Godot 4.6 event-class identity is NOT altered by dual-focus split at the Control
## layer — InputRouter operates BELOW the focus layer via _unhandled_input per
## godot-specialist 2026-04-30 Item 1 PASS. SDL3 backend (4.5+) does not change
## Joypad event class names (godot-specialist Item 3 advisory).
func _determine_mode_from_event(event: InputEvent) -> InputMode:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return InputMode.TOUCH
	if event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventKey:
		return InputMode.KEYBOARD_MOUSE
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		# OQ-1 partial: MVP routes joypad to KEYBOARD_MOUSE; future GAMEPAD ADR may
		# add 3rd mode at int 2 (Settings/Options ADR, post-MVP) without superseding
		# this ADR (additive enum value). TR-input-handling-011.
		return InputMode.KEYBOARD_MOUSE
	# Defensive: unknown event class — preserve current mode (no flip)
	return _active_mode


## Single dispatch path for all FSM transitions. Routes by current `_state` to
## per-state handler methods, then emits the GameBus signal pair on visible work.
##
## Per ADR-0020 §1 Phase 4: state-change happens FIRST inside the per-state arm,
## emit-pair happens SECOND in this method's tail. Per delta #6 Item 4: signal
## emit ordering is `input_state_changed` BEFORE `input_action_fired`.
##
## Story-004 emit-logic restructure (AC-8 re-targeting): `input_action_fired` is
## now emitted on ANY visible work (state change OR re-targeting ctx-update OR
## end-phase gate toggle), NOT only on state change. `_did_visible_work` is reset
## at dispatch entry; per-state arms flip it when they execute observable behavior;
## state-change auto-sets it in the epilogue. Backward-compatible with story-003
## tests — every state transition still emits both signals (auto-set path).
##
## NOTE: input_action_fired emits the action StringName as String at the GameBus
## boundary (signal declared as `signal input_action_fired(action: String, ...)`);
## GDScript 4.6 auto-coerces StringName → String at the emit call. Subscribers
## receive String. Tests using `assert_str(...)` expect String type accordingly.
##
## NOTE: emit fires even when the per-state arm's side-effect (e.g. confirm_move
## stub call in S2) was a no-op due to null `_grid_battle`. Subscribers that need
## to react to "move actually applied" vs. "transition reached confirm state" must
## query Grid Battle directly — emit is a transition signal, not a side-effect
## confirmation. Story-006 undo-window-open hooks here and must guard for null.
##
## Test seam: callable directly via InputRouter._handle_action(action, ctx) for
## fixture injection without going through the full _handle_event → InputMap path.
func _handle_action(action: StringName, ctx: InputContext) -> void:
	var prev_state: InputState = _state
	_did_visible_work = false  # reset per dispatch
	match _state:
		InputState.OBSERVATION:
			_handle_action_in_s0(action, ctx)
		InputState.UNIT_SELECTED:
			_handle_action_in_s1(action, ctx)
		InputState.MOVEMENT_PREVIEW:
			_handle_action_in_s2(action, ctx)
		InputState.ATTACK_TARGET_SELECT:
			_handle_action_in_s3(action, ctx)  # story-004
		InputState.ATTACK_CONFIRM:
			_handle_action_in_s4(action, ctx)  # story-004
		InputState.INPUT_BLOCKED:
			_handle_action_in_s5(action, ctx)  # story-007
		InputState.MENU_OPEN:
			_handle_action_in_s6(action, ctx)  # story-007
	# State change implies visible work — auto-set the flag.
	if _state != prev_state:
		_did_visible_work = true
		GameBus.input_state_changed.emit(int(prev_state), int(_state))
	if _did_visible_work:
		GameBus.input_action_fired.emit(action, ctx)


## S0 OBSERVATION arm. Default state — reading the battle. Player can select a
## unit (→ S1), pan/zoom camera (no state change), open menus (→ S6 in story-007),
## or initiate the end-player-turn 2-beat confirmation flow (AC-11). All other
## actions silently dropped per AC-8 invalid-action discipline.
func _handle_action_in_s0(action: StringName, ctx: InputContext) -> void:
	match action:
		&"unit_select":
			if ctx.target_unit_id == -1:
				return  # invalid context — no unit was actually targeted
			_state = InputState.UNIT_SELECTED
		&"camera_pan", &"camera_zoom_in", &"camera_zoom_out", &"camera_snap_to_unit":
			pass  # camera actions pass through without state change
		&"open_unit_info":
			pass  # read-only inspection; no state change
		&"open_game_menu":
			pass  # → S6 (story-007 wires)
		&"end_player_turn":
			# AC-11 first beat: arm the end-phase gate. Battle HUD subscriber
			# renders confirmation dialog via input_action_fired subscription.
			# NO state change — gate is a transient scratch flag.
			_pending_end_phase = true
			_did_visible_work = true
		&"end_phase_confirm":
			# AC-11 second beat: confirm only if armed.
			if _pending_end_phase:
				_pending_end_phase = false
				_did_visible_work = true
				# Battle HUD subscriber executes actual phase-end on receiving
				# input_action_fired(&"end_phase_confirm", ctx).
		&"action_cancel":
			# AC-11 cancel: silently reset armed gate without firing confirm.
			# No _did_visible_work set — subscribers shouldn't see a fake
			# "cancel" event for an unarmed gate.
			if _pending_end_phase:
				_pending_end_phase = false
		# All other actions in S0: silent no-op


## S1 UNIT_SELECTED arm. Player has selected a unit; can preview movement,
## initiate an attack, cancel back to S0, or open contextual menus. Movement and
## attack require the target tile to be in range per Grid Battle stub queries.
##
## NOTE: story spec AC-3 mandated a `ctx.target_coord == Vector2i.ZERO` sentinel
## guard. That guard would silently reject tile (0,0) as a valid destination,
## which is a production correctness bug since grid origins ARE valid playfield
## cells. Implementation deviates from spec: validity is delegated entirely to
## _is_tile_in_move_range / _is_tile_in_attack_range which return false for any
## coord not in the respective frontier (including out-of-bounds). Story-008/009
## (touch coord binding) owns the upstream "did the player actually target a coord"
## detection — empty-context dispatch from default-constructed InputContext is
## NOT story-003/004's concern.
func _handle_action_in_s1(action: StringName, ctx: InputContext) -> void:
	match action:
		&"move_target_select":
			if not _is_tile_in_move_range(ctx.target_coord):
				return  # destination out of range per EC-7 silent rejection
			_state = InputState.MOVEMENT_PREVIEW
		&"attack_target_select":
			# Story-004: S1 → S3 transition gate
			if not _is_tile_in_attack_range(ctx.target_coord):
				return  # target out of attack range per EC-7 silent rejection
			_state = InputState.ATTACK_TARGET_SELECT
		&"move_cancel", &"end_unit_turn":
			_state = InputState.OBSERVATION  # back to observation; undo closes (story-006)
		&"open_game_menu":
			pass  # → S6 (story-007)
		&"open_unit_info":
			pass  # read-only; S1 retained
		&"action_confirm":
			pass  # cursor-based confirm (Camera ADR pending; coord binding deferred)
		# All other actions in S1: silent no-op


## S2 MOVEMENT_PREVIEW arm. Destination selected, awaiting confirm. On confirm:
## apply move via Grid Battle stub + return to S0. On cancel: back to S1.
## Story-006 will add undo-window-open call after confirm.
func _handle_action_in_s2(action: StringName, ctx: InputContext) -> void:
	match action:
		&"move_confirm", &"action_confirm":
			if _grid_battle != null and _grid_battle.has_method("confirm_move"):
				_grid_battle.confirm_move(ctx.target_unit_id, ctx.target_coord)
			# Story-006: _open_undo_window(ctx.target_unit_id, ctx.target_coord)
			_state = InputState.OBSERVATION
		&"move_cancel":
			_state = InputState.UNIT_SELECTED
		# All other actions in S2: silent no-op


## S3 ATTACK_TARGET_SELECT arm. Player selected attack target; awaiting confirm.
## Action_confirm aliased to attack_confirm per CR-3a. Re-targeting (a fresh
## attack_target_select call) emits input_action_fired only without state change
## per AC-8 — Battle HUD subscriber updates target preview on the new ctx.
func _handle_action_in_s3(action: StringName, ctx: InputContext) -> void:
	match action:
		&"attack_confirm", &"action_confirm":
			_state = InputState.ATTACK_CONFIRM
		&"attack_cancel":
			_state = InputState.UNIT_SELECTED
		&"attack_target_select":
			# AC-8 re-targeting: state retained, ctx-update conveyed via
			# input_action_fired emit. Validate the new coord is in attack range.
			if _is_tile_in_attack_range(ctx.target_coord):
				_did_visible_work = true  # emit action_fired with new ctx
			# else silent rejection — no emit, no state change
		&"open_game_menu":
			_pre_menu_state = _state  # S3
			_state = InputState.MENU_OPEN  # → S6 (story-007 implements close)
		# All other actions in S3: silent no-op


## S4 ATTACK_CONFIRM arm. Second confirmation completes the attack — calls
## Grid Battle stub confirm_attack + closes any open undo window for the unit
## (story-006 implements undo close logic), then returns to S0 OBSERVATION.
##
## NOTE: target_unit_id == -1 guard mirrors S0 `&"unit_select"` (line 344). When
## production GridBattleController ships at story-014, -1 will be a semantically
## invalid call (no unit at index -1). Better to silently reject here than to
## propagate the invalid ID downstream. Defensive coding consistent with S0.
func _handle_action_in_s4(action: StringName, ctx: InputContext) -> void:
	match action:
		&"attack_confirm", &"action_confirm":
			if ctx.target_unit_id == -1:
				return  # invalid context — no attacker unit identified
			if _grid_battle != null and _grid_battle.has_method("confirm_attack"):
				_grid_battle.confirm_attack(ctx.target_unit_id, ctx.target_coord)
			# Story-006: _close_undo_window(ctx.target_unit_id)
			_state = InputState.OBSERVATION
		&"attack_cancel":
			_state = InputState.ATTACK_TARGET_SELECT
		# All other actions in S4: silent no-op


## S5 INPUT_BLOCKED arm — story-007 implements. Stub no-op (input is blocked,
## so dropping all actions is the correct degenerate behavior even today).
func _handle_action_in_s5(_action: StringName, _ctx: InputContext) -> void:
	pass


## S6 MENU_OPEN arm — story-007 implements. Stub no-op.
func _handle_action_in_s6(_action: StringName, _ctx: InputContext) -> void:
	pass


## Range-check helper for S1 → S2 transition gate. Defers to _grid_battle stub
## injection. When stub is null (production not yet wired pre-Grid-Battle-ADR),
## returns true (permissive — Grid Battle epic enforces real range query).
func _is_tile_in_move_range(coord: Vector2i) -> bool:
	if _grid_battle == null:
		return true  # permissive when no stub injected
	if not _grid_battle.has_method("is_tile_in_move_range"):
		return true  # stub doesn't implement check; permissive
	return _grid_battle.is_tile_in_move_range(coord)


## Range-check helper for S1 → S3 + S3 re-target gates. Defers to _grid_battle
## stub injection. Mirrors _is_tile_in_move_range permissive-on-null +
## permissive-on-missing-method pattern.
func _is_tile_in_attack_range(coord: Vector2i) -> bool:
	if _grid_battle == null:
		return true  # permissive when no stub injected
	if not _grid_battle.has_method("is_tile_in_attack_range"):
		return true  # stub doesn't implement check; permissive
	return _grid_battle.is_tile_in_attack_range(coord)


## ST-2 demotion helper per ADR-0005 §5 + GDD §Transition Table. S2 (MOVEMENT_PREVIEW)
## and S4 (ATTACK_CONFIRM) are pending-confirm states; on menu-close transition
## (story-007 implements full S6 → restored_state flow), the pending confirm is
## dropped and the state is demoted to S1 (UNIT_SELECTED). Story-004 implements
## the helper for unit-test coverage; story-007 invokes it from the close-menu arm.
##
## Pure function: no side effects on _state or any other field.
func _apply_st2_demotion(restored_state: InputState) -> InputState:
	if (
		restored_state == InputState.MOVEMENT_PREVIEW
		or restored_state == InputState.ATTACK_CONFIRM
	):
		return InputState.UNIT_SELECTED
	return restored_state


## Populates Godot's InputMap from a parsed bindings dictionary.
##
## Skips meta keys (those beginning with "_": _schema_version, _authority).
## Constructs InputEvent instances via _construct_input_event and registers each
## via InputMap.add_action + InputMap.action_add_event per AC-4. Tracks events
## in _bindings for runtime-remap clearing by set_binding.
## DI seam: tests call this directly with a custom dict instead of relying on
## _ready() reading the production JSON file path (G-15 isolation).
##
## Defensive: skips non-Array binding values + non-Dictionary event entries with
## push_warning (data-corruption-resistant; a JSON typo like `"typ": "key"`
## degrades to "action exists but no events bound" rather than a crash).
func _populate_input_map(bindings: Dictionary) -> void:
	for action_str: String in bindings.keys():
		if action_str.begins_with("_"):
			continue  # skip _schema_version, _authority meta keys
		var action: StringName = StringName(action_str)
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		var event_list_variant: Variant = bindings[action_str]
		if not (event_list_variant is Array):
			push_warning(
				"InputRouter: binding value for '%s' is not an Array; skipping" % action_str
			)
			continue
		for event_dict_variant: Variant in event_list_variant as Array:
			if not (event_dict_variant is Dictionary):
				push_warning(
					"InputRouter: event entry for '%s' is not a Dictionary; skipping" % action_str
				)
				continue
			var event: InputEvent = _construct_input_event(event_dict_variant as Dictionary)
			if event != null:
				InputMap.action_add_event(action, event)
				_bindings.get_or_add(action, []).append(event)


## Constructs an InputEvent from a JSON event descriptor dictionary.
##
## Supported types: "key" (InputEventKey + keycode), "mouse_button"
## (InputEventMouseButton + button_index), "screen_touch" (InputEventScreenTouch),
## "screen_drag" (InputEventScreenDrag). Unknown types emit push_warning + return null.
## Per delta #6 Item 8: InputMap population uses InputEventXxx.new() NOT
## Input.parse_input_event() (the latter is event injection, not InputMap registration).
func _construct_input_event(event_dict: Dictionary) -> InputEvent:
	# Dictionary.get returns Variant; `as String` on a non-String Variant
	# coerces to "" which falls through to the wildcard `_:` arm + push_warning.
	var type: String = event_dict.get("type", "") as String
	match type:
		"key":
			var ev := InputEventKey.new()
			ev.keycode = event_dict.get("keycode", 0) as int
			return ev
		"mouse_button":
			var ev := InputEventMouseButton.new()
			ev.button_index = event_dict.get("button_index", 0) as int
			return ev
		"screen_touch":
			return InputEventScreenTouch.new()
		"screen_drag":
			return InputEventScreenDrag.new()
		_:
			push_warning(
				"InputRouter: unknown event type '%s'; skipping" % event_dict.get("type", "")
			)
			return null


## Validates R-5 parity: ACTIONS_BY_CATEGORY declared count minus PC-only count
## must equal the number of non-meta keys in default_bindings.json.
##
## Emits push_error (non-aborting) on mismatch — schema drift between
## ACTIONS_BY_CATEGORY and default_bindings.json is a hard contract violation per
## ADR-0005 §4 R-5, but the autoload continues operating in a degraded state
## (some actions unbound or doubly-bound). PC-only count = 1 (grid_hover excluded
## from JSON per CR-1c).
##
## Returns the absolute mismatch magnitude: 0 when parity holds, |bound - expected|
## when drift detected. Tests assert the return value rather than relying on
## push_error capture (G-22: push_error is not capturable via assert_error matcher).
##
## DI seam: tests call this directly with a malformed dict to verify the error path.
func _validate_r5_parity(bindings: Dictionary) -> int:
	var meta_keys: int = 0
	for key: String in bindings.keys():
		if key.begins_with("_"):
			meta_keys += 1
	var bound_count: int = bindings.size() - meta_keys
	var declared_count: int = 0
	for category: StringName in ACTIONS_BY_CATEGORY.keys():
		declared_count += ACTIONS_BY_CATEGORY[category].size()
	var pc_only: int = 1  # grid_hover is PC-only (CR-1c); excluded from default_bindings.json
	var expected_bound: int = declared_count - pc_only
	var mismatch: int = absi(bound_count - expected_bound)
	if mismatch != 0:
		push_error(
			(
				"InputRouter R-5 parity FAIL: ACTIONS_BY_CATEGORY has %d - %d PC-only = %d;"
				+ " default_bindings.json has %d; schema drift detected (mismatch=%d)"
			)
			% [declared_count, pc_only, expected_bound, bound_count, mismatch]
		)
	return mismatch
