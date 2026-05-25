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
##   story-008: touch protocol part A — F-1 camera_zoom_min derivation + TPP (CR-4a) +
##             Magnifier Panel trigger (CR-4c F-2) + Camera/MapGrid injection seams
##   story-009: touch protocol part B — pan-vs-tap classifier (CR-4f) + 2-finger
##             gestures (CR-4g) + persistent action panel positioning (CR-4h) +
##             safe-area API resolution (TR-012)
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

## Transient scratch state for AC-11 — captures _state at the moment of FIRST
## block entry; restored on FINAL block exit (when _input_blocked_reasons becomes
## empty). NOT counted in ADR-0005 §1's 6-field architectural-field list —
## implementation-internal scratch, scoped per block-stack lifetime (set on first
## append to _input_blocked_reasons, reset to OBSERVATION on final pop). Mirrors
## _pending_end_phase precedent (story-004) for transient-internal field design.
## G-15 obligation: `before_test()` resets to `OBSERVATION` (story-010 lint enforces).
var _pre_block_state: InputState = InputState.OBSERVATION

## Transient touch-tracking state for AC-1 pan-vs-tap classifier (story-009 CR-4f).
## NOT counted in ADR-0005 §1's 6-field architectural-field list — implementation-
## internal scratch, scoped per single-finger touch gesture.
## G-15 obligation: `before_test()` resets all 4 fields. Story-010 lint enforces.
var _touch_start_pos: Vector2 = Vector2.ZERO
var _touch_start_time_ms: int = 0
var _touch_travel_px: float = 0.0

## Active touch-finger indices for AC-4 two-finger gesture handling (CR-4g).
## index 0 = first finger; index >= 1 = second/third+ fingers (multi-touch).
## G-25 safe — depth-1 PackedInt32Array.
var _active_touch_indices: PackedInt32Array = []

## Cached safe-area inset resolved at `_ready()` per AC-6 (CR-4h Android edge-to-edge
## TR-input-handling-012 + verification §5b). Vector4(left, top, right, bottom) margins.
## Defaults to ZERO (desktop fallback); resolved-at-ready via 3-candidate ladder.
## Mutated only at `_ready()` and screen-resize handler — convention-enforced.
var _safe_area_inset: Vector4 = Vector4.ZERO

## F-1 camera zoom minimum derived from BalanceConstants at _ready() time (story-008).
## Formula: TOUCH_TARGET_MIN_PX (44) / TILE_WORLD_SIZE (64) = 0.6875 → ceil to next
## 0.05 increment = 0.70. Cached for runtime use; recomputed only on screen-size-change
## events. Shadow of the CAMERA_ZOOM_MIN JSON constant — this derived version is the
## canonical runtime value (proves provenance rather than trusting a raw constant).
## G-15 obligation: `before_test()` resets to `0.70` (story-010 lint enforces).
var _camera_zoom_min: float = 0.70

## Transient scratch — last unit_id tapped in TOUCH mode (TPP, story-008 CR-4a).
## NOT counted in ADR-0005 §1's 6-field architectural-field list — implementation-
## internal scratch. Initialised to -1 (no tap recorded). Reset to -1 on second-tap
## advancement or window expiry with different unit.
## G-15 obligation: `before_test()` resets to `-1` (story-010 lint enforces).
var _last_tap_unit_id: int = -1

## Transient scratch — Time.get_ticks_msec() at the moment of the last unit tap
## in TOUCH mode (TPP, story-008 CR-4a). 0 = no tap recorded.
## G-15 obligation: `before_test()` resets to `0` (story-010 lint enforces).
var _last_tap_time_ms: int = 0

## Provisional Camera reference (typed Variant — CameraController class doesn't
## exist yet; story-014 narrows when Camera ADR ships). Tests inject via
## set_camera_for_tests(). Used by _make_context_from_event for screen→grid coord
## resolution (story-008).
var _camera: Variant = null

## Provisional MapGrid reference (typed Variant — MapGrid class exists but is not
## the InputRouter-relevant contract surface yet; story-014 narrows). Tests inject
## via set_map_grid_for_tests(). Used by _make_context_from_event for coord→unit_id
## lookup (story-008).
var _map_grid: Variant = null

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
## Grid actions that are silently dropped in S5 INPUT_BLOCKED (story-007 + AC-4).
## Named with _S5 suffix to distinguish from the ACTIONS_BY_CATEGORY["grid"] slice,
## which has the same contents but serves a different semantic purpose.
const _GRID_ACTIONS_S5: Array[StringName] = [
	&"unit_select", &"move_target_select", &"move_confirm", &"move_cancel",
	&"attack_target_select", &"attack_confirm", &"attack_cancel",
	&"undo_last_move", &"end_unit_turn", &"grid_hover",
]

## Camera + read actions permitted to pass through in S5 INPUT_BLOCKED (story-007 + AC-4).
## These actions do NOT change _state in S5, but they DO set _did_visible_work so that
## the input_action_fired emit fires for downstream subscribers (camera, info panel).
const _PERMITTED_S5_ACTIONS: Array[StringName] = [
	&"camera_pan", &"camera_zoom_in", &"camera_zoom_out", &"camera_snap_to_unit",
	&"open_unit_info",
]

const ACTIONS_BY_CATEGORY: Dictionary[StringName, Array] = {
	&"grid": [
		&"unit_select", &"move_target_select", &"move_confirm", &"move_cancel",
		&"attack_target_select", &"attack_confirm", &"attack_cancel",
		&"undo_last_move", &"end_unit_turn", &"defend_stance", &"use_skill", &"grid_hover",
		# defend_stance = session-13 D key for player defend verb
		# use_skill = session-15 S key for hero active skill (1×/battle)
		# grid_hover = PC-only per CR-1c
	],
	&"camera": [
		&"camera_pan", &"camera_zoom_in", &"camera_zoom_out", &"camera_snap_to_unit",
		&"camera_pinch_zoom", &"camera_two_finger_tap_cancel",  # +2 from story-009 CR-4g (touch-only)
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


## Resets all 17 mutable fields to clean defaults — G-15 test-isolation hook.
##
## 5th autoload `reset_for_tests` precedent (after BalanceConstants + DestinyState +
## StoryEvent + ScenarioRunner per .claude/rules/godot-4x-gotchas.md G-28). Tests
## call this from `before_test()` to prevent state-leak across the suite.
##
## Field count breakdown (must match `tools/ci/lint_input_router_g15_reset.sh`
## REQUIRED_FIELDS list — 17 total):
##   - 6 architectural (story-001): _state / _active_mode / _pre_menu_state /
##     _undo_windows / _input_blocked_reasons / _bindings
##   - 1 transient (story-004): _pending_end_phase
##   - 1 transient (story-007): _pre_block_state
##   - 4 transient (story-008): _last_tap_unit_id / _last_tap_time_ms / _camera /
##     _map_grid
##   - 4 transient (story-009): _touch_start_pos / _touch_start_time_ms /
##     _touch_travel_px / _active_touch_indices
##   - 1 test seam (story-003+): _grid_battle
##
## Production code MUST NOT call this — caller-allowlist enforced socially. The
## `_for_tests` suffix marks the seam.
func reset_for_tests() -> void:
	# Architectural (6, ADR-0005 §1)
	_state = InputState.OBSERVATION
	_active_mode = InputMode.KEYBOARD_MOUSE
	_pre_menu_state = InputState.OBSERVATION
	_undo_windows.clear()
	_input_blocked_reasons.clear()
	_bindings.clear()
	# Transient scratch (story-004 + story-007)
	_pending_end_phase = false
	_pre_block_state = InputState.OBSERVATION
	# Transient touch (story-008)
	_last_tap_unit_id = -1
	_last_tap_time_ms = 0
	_camera = null
	_map_grid = null
	# Transient touch (story-009)
	_touch_start_pos = Vector2.ZERO
	_touch_start_time_ms = 0
	_touch_travel_px = 0.0
	_active_touch_indices = PackedInt32Array()
	# Test seam (story-003+)
	_grid_battle = null


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
	# Phase 2: touch tracking (story-009 CR-4f + CR-4g + EC-1).
	# Returns true when the event was fully handled; false to continue to action-match.
	if _handle_touch_tracking(event):
		return  # event consumed by touch tracking; action-match skipped
	# Drop button/key release + key-echo events: a single physical click fires both
	# pressed=true (button-down) and pressed=false (button-up) and InputMap.action_has_event
	# matches both. Without this filter, every click dispatches its action twice — the
	# release re-firing `unit_select` in S1 deselects the unit we just selected.
	if event is InputEventMouseButton and not (event as InputEventMouseButton).pressed:
		return
	if event is InputEventKey:
		var key_event: InputEventKey = event
		if not key_event.pressed or key_event.echo:
			return
	if event is InputEventJoypadButton and not (event as InputEventJoypadButton).pressed:
		return
	# Phase 3: action-resolve via InputMap lookup
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


## Camera DI for screen→grid coord resolution. Called by BattleScene at battle-prep
## time after BattleCamera is instantiated. Same setter is used by tests with a stub.
func set_camera(camera: Variant) -> void:
	_camera = camera


## MapGrid DI for grid coord→unit_id resolution. Called by BattleScene at battle-prep
## time after MapGrid is instantiated. Same setter is used by tests with a stub.
func set_map_grid(map_grid: Variant) -> void:
	_map_grid = map_grid


## Public read-only query — Battle HUD subscribes to `input_action_fired(&"panel_reposition_request")`
## then calls this method to get the current panel position for the active state.
## Returns Vector2(-1, -1) for states that do not show a panel (S0/S5/S6).
## Safe-area-aware: consults `_safe_area_inset` resolved at `_ready()`.
##
## Example:
##   func _on_input_action_fired(action: String, _ctx: InputContext) -> void:
##       if action == "panel_reposition_request":
##           var pos: Vector2 = InputRouter.get_action_panel_position(InputRouter.get_state())
##           action_panel.global_position = pos
func get_action_panel_position(state: InputState) -> Vector2:
	return _get_action_panel_position(state)


## Clears all per-unit undo windows at battle-end boundary (ADR-0005 §1 R-2 memory bound).
##
## Called by SceneManager when transitioning out of BattleScene (production wiring
## deferred to Battle Preparation ADR; test seam available now). Ensures undo windows
## are battle-scoped and do NOT leak across battles.
func clear_for_battle_transition() -> void:
	_undo_windows.clear()


## GameBus subscription handler — story-007. Appends reason to nested block stack.
##
## First entry transitions S0..S6 → S5 (INPUT_BLOCKED) and emits 1 input_state_changed.
## Subsequent stacked entries are idempotent — no additional emit (AC-2 + AC-5).
## Stack supports nested S5 entries from multiple block sources (max depth ~3 observed).
##
## CONNECT_DEFERRED at subscription site mitigates re-entrancy hazard per ADR-0001 §5.
##
## ADR-0020 §1 sole-state-mutator note: this handler writes `_state` directly.
## Permitted because it is invoked via GameBus signal dispatch (not from
## `_handle_event`, public API, or per-state arms) — same delegation pattern as
## `_apply_undo` (story-006). Phase 4 emit: only `input_state_changed` fires here;
## no `input_action_fired` (the GameBus emit IS the triggering event). Story-010
## lint will enforce that this handler is the only state-mutating subscriber path.
func _on_ui_input_block_requested(reason: String) -> void:
	_input_blocked_reasons.append(reason)
	if _input_blocked_reasons.size() == 1:
		_pre_block_state = _state
		var prev_state: InputState = _state
		_state = InputState.INPUT_BLOCKED
		GameBus.input_state_changed.emit(int(prev_state), int(_state))


## GameBus subscription handler — story-007. Removes reason from nested block stack.
##
## Final exit (stack becomes empty) restores `_pre_block_state` and emits 1
## input_state_changed; nested exits leave the stack non-empty and emit nothing
## (AC-3 + AC-5). Unknown reason fires push_warning (AC-3 edge case).
##
## CONNECT_DEFERRED at subscription site mitigates re-entrancy hazard per ADR-0001 §5.
##
## ADR-0020 §1 sole-state-mutator note: this handler writes `_state` directly.
## Permitted because it is invoked via GameBus signal dispatch (not from
## `_handle_event`, public API, or per-state arms) — same delegation pattern as
## `_apply_undo` (story-006) + `_on_ui_input_block_requested` (this story). Phase 4
## emit: only `input_state_changed` fires here; no `input_action_fired` (the
## GameBus emit IS the triggering event). `_pre_block_state` reset on final pop
## (mid-stack pops leave it intact for the eventual final unblock).
func _on_ui_input_unblock_requested(reason: String) -> void:
	var idx: int = _input_blocked_reasons.find(reason)
	if idx == -1:
		push_warning(
			"InputRouter: unblock requested for unknown reason '%s'; current stack: %s"
			% [reason, str(_input_blocked_reasons)]
		)
		return
	_input_blocked_reasons.remove_at(idx)
	if _input_blocked_reasons.is_empty():
		var prev_state: InputState = _state
		_state = _pre_block_state
		GameBus.input_state_changed.emit(int(prev_state), int(_state))
		_pre_block_state = InputState.OBSERVATION


# ── Per-unit undo window helpers (story-006 + CR-5) ──────────────────────────


## Opens an undo window for a unit after a confirmed move (CR-5 — opens on COMPLETED move).
##
## CR-5b depth 1: if an entry already exists for this unit_id, OVERWRITE it.
## Only the most recent move per unit is undoable. Called from S2 move_confirm arm.
func _open_undo_window(unit_id: int, pre_move_coord: Vector2i, pre_move_facing: int) -> void:
	var entry := UndoEntry.new()
	entry.unit_id = unit_id
	entry.pre_move_coord = pre_move_coord
	entry.pre_move_facing = pre_move_facing
	_undo_windows[unit_id] = entry  # CR-5b depth 1: overwrite if entry already exists


## Closes the undo window for a unit permanently.
##
## Called from 3 CR-5 sites: (a) S4 attack_confirm for that unit,
## (b) S1 end_unit_turn for that unit, (c) S0 end_phase_confirm (all windows via clear).
## erase() is a no-op when key is absent — safe to call unconditionally.
func _close_undo_window(unit_id: int) -> void:
	_undo_windows.erase(unit_id)


## Applies the undo for a unit — restores pre-move coord + facing + state → S1.
##
## Returns true on success, false on any rejection:
##   (1) No window open for this unit (AC-13 case) — silent no-op.
##   (2) Pre-move tile is occupied (EC-5 + CR-5f) — entry retained for retry;
##       player can attempt again once the tile clears.
##
## CR-5e exclusions — undo restores ONLY: unit coord + facing + state → S1.
## Does NOT restore: HP damage from terrain, status effects applied during/after move,
## enemy unit reactions triggered by the move, AP spent. These are intentionally
## excluded to prevent runaway state rollback exploits and scope creep.
##
## ADR-0020 §1 sole-state-mutator note: this helper writes `_state` and
## `_did_visible_work` directly. Permitted because `_apply_undo` is invoked
## EXCLUSIVELY from per-state arms (`_handle_action_in_s0` / `_handle_action_in_s1`
## via the `&"undo_last_move"` match arm) — same delegation pattern as
## `_apply_st2_demotion`. Not callable from `_handle_event`, public API, or any
## other dispatch path. Story-010 lint will enforce that `_apply_undo` is only
## referenced from the two undo-dispatch arms.
func _apply_undo(unit_id: int) -> bool:
	if not _undo_windows.has(unit_id):
		return false  # AC-13: no window open for this unit; silent no-op
	var entry: UndoEntry = _undo_windows[unit_id]
	# EC-5 + CR-5f: check if pre-move tile is now occupied by another unit.
	# Rejection does NOT pop the entry — player may retry when the tile clears.
	if _grid_battle != null and _grid_battle.has_method("is_tile_occupied"):
		if _grid_battle.is_tile_occupied(entry.pre_move_coord):
			return false  # AC-14: tile occupied; entry retained for retry (CR-5f)
	# Restore unit position via Grid Battle stub (provisional §9 method).
	if _grid_battle != null and _grid_battle.has_method("restore_unit_to_pre_move"):
		_grid_battle.restore_unit_to_pre_move(unit_id, entry.pre_move_coord, entry.pre_move_facing)
	_undo_windows.erase(unit_id)  # pop entry — one-shot undo per CR-5
	_state = InputState.UNIT_SELECTED  # CR-5: restore to S1 (UNIT_SELECTED) after undo
	_did_visible_work = true
	return true


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
	# Story-007: GameBus subscriptions per ADR-0001 §5 deferred-connect mandate.
	# CONNECT_DEFERRED mitigates re-entrancy hazard (ADR-0001 §5 + delta #6 Item 4 Advisory D).
	GameBus.ui_input_block_requested.connect(_on_ui_input_block_requested, Object.CONNECT_DEFERRED)
	GameBus.ui_input_unblock_requested.connect(_on_ui_input_unblock_requested, Object.CONNECT_DEFERRED)
	# Story-008: derive F-1 camera_zoom_min from BalanceConstants at boot time.
	# Called AFTER bindings load (BalanceConstants._cache_loaded must be primed first;
	# _load_bindings_from_path reads FileAccess which triggers BalanceConstants init on
	# first call via autoload chain). If BalanceConstants fails to load, falls back
	# gracefully to the 0.70 default already set on the field.
	_camera_zoom_min = _compute_camera_zoom_min()
	# Story-009 AC-6: resolve safe-area API at boot (Android edge-to-edge / notch).
	# Result cached in `_safe_area_inset`; falls back to Vector4.ZERO on desktop.
	_safe_area_inset = _resolve_safe_area_api()


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

## F-1 derivation (story-008 AC-1, ADR-0005 §7):
##   raw = TOUCH_TARGET_MIN_PX (44) / TILE_WORLD_SIZE (64) = 0.6875
##   comfort margin: round up to next 0.05 increment → ceilf(raw * 20) / 20 = 0.70
##   Guarantees tile_world_size * _camera_zoom_min ≥ 44px (actual: 44.8px at 0.70).
##
## Reads from BalanceConstants so the formula re-derives whenever the JSON constants
## change — test AC-1 asserts the result equals 0.70 and also tests the derivation
## path itself rather than a hardcoded constant. <10 LoC guardrail per story-008 §CM.
func _compute_camera_zoom_min() -> float:
	var touch_min: float = float(BalanceConstants.get_const(&"TOUCH_TARGET_MIN_PX"))
	var tile_world: float = float(BalanceConstants.get_const(&"TILE_WORLD_SIZE"))
	var raw: float = touch_min / tile_world
	return ceilf(raw * 20.0) / 20.0


## F-2 Magnifier Panel trigger (story-008 AC-5, ADR-0005 §7 + CR-4c):
## Returns true when tap is near a tile boundary (< DISAMBIG_EDGE_PX) OR when the
## tile is smaller than DISAMBIG_TILE_PX (camera zoomed too far out to tap precisely).
## Both conditions are independently sufficient — OR logic per the spec.
## <15 LoC guardrail per story-008 §CM (this helper + _compute_tap_edge_offset combined).
func _should_trigger_magnifier(touch_pos: Vector2, tile_display_px: float) -> bool:
	var edge_threshold: float = float(BalanceConstants.get_const(&"DISAMBIG_EDGE_PX"))
	var tile_threshold: float = float(BalanceConstants.get_const(&"DISAMBIG_TILE_PX"))
	var edge_offset: float = _compute_tap_edge_offset(touch_pos, tile_display_px)
	return edge_offset < edge_threshold or tile_display_px < tile_threshold


## Computes the shortest distance (px) from a touch position to the nearest tile
## boundary in screen space. Uses fmod to find position within the current tile, then
## returns the minimum of the distance to the left/top boundary vs right/bottom boundary.
func _compute_tap_edge_offset(touch_pos: Vector2, tile_display_px: float) -> float:
	var x_in_tile: float = fmod(touch_pos.x, tile_display_px)
	var y_in_tile: float = fmod(touch_pos.y, tile_display_px)
	var x_edge: float = min(x_in_tile, tile_display_px - x_in_tile)
	var y_edge: float = min(y_in_tile, tile_display_px - y_in_tile)
	return min(x_edge, y_edge)


## Pan-vs-tap classifier per ADR-0005 §F-3 + CR-4f. Returns one of:
##   &"camera_pan"   — touch_travel_px > PAN_ACTIVATION_PX (gesture detected as pan)
##   &"_rejected"    — hold_duration_ms < MIN_TOUCH_DURATION_MS AND no pan (accidental tap)
##   &"unit_select"  — held > MIN duration without significant travel (deliberate tap)
##
## Pure function: no side effects. <15 LoC guardrail per story-009 §CM.
func _classify_pan_or_tap(touch_travel_px: float, hold_duration_ms: int) -> StringName:
	var pan_threshold: float = float(BalanceConstants.get_const(&"PAN_ACTIVATION_PX"))
	var min_duration: int = int(BalanceConstants.get_const(&"MIN_TOUCH_DURATION_MS"))
	if touch_travel_px > pan_threshold:
		return &"camera_pan"
	if hold_duration_ms < min_duration:
		return &"_rejected"
	return &"unit_select"


## Two-finger gesture handler per ADR-0005 §CR-4g. ALWAYS classified as camera
## operation (NEVER routed to grid actions). Emits via direct GameBus.input_action_fired
## bypassing the action-match path because two-finger gestures don't have InputMap
## bindings (multi-touch index discrimination is not InputMap-representable).
##
## ADR-0020 §1 sole-state-mutator note: this handler does NOT mutate `_state` —
## camera operations don't change FSM state. Sets `_did_visible_work = true` for
## consistency but the dispatch path here is direct-emit, not via `_handle_action`.
##
## <15 LoC guardrail per story-009 §CM.
func _handle_two_finger_gesture(event: InputEvent) -> void:
	var ctx := InputContext.new()
	if event is InputEventScreenDrag:
		_did_visible_work = true
		GameBus.input_action_fired.emit(&"camera_pinch_zoom", ctx)
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		_did_visible_work = true
		GameBus.input_action_fired.emit(&"camera_two_finger_tap_cancel", ctx)


## Touch tracking + multi-touch handler (story-009 CR-4f + CR-4g + EC-1).
## Called at start of Phase 2 in _handle_event BEFORE the InputMap action-match loop.
##
## Returns true if the event was fully consumed (caller should return early).
## Returns false to let the action-match phase continue.
##
## 7 paths handled:
##   1. Touch pressed index >= 1: EC-1 cancel + 2-finger gesture; consumed (true)
##   2. Touch pressed index == 0: start tracking; let action-match continue (false)
##   3. Touch released index == 0 sole finger: classify + dispatch; consumed (true)
##   4. Touch released other index: remove from tracking; consumed (true)
##   5. Drag index >= 1: 2-finger gesture; consumed (true)
##   6. Drag index == 0: accumulate travel; let action-match continue (false)
##   7. Other events (key/mouse): not touch-related; let action-match continue (false)
func _handle_touch_tracking(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		if touch.pressed:
			if touch.index >= 1:
				# EC-1: second+ finger cancels pending first-finger TPP state
				_last_tap_unit_id = -1
				_last_tap_time_ms = 0
				_active_touch_indices.append(touch.index)
				_handle_two_finger_gesture(touch)
				return true  # consumed
			# First finger pressed: start tracking
			_touch_start_pos = touch.position
			_touch_start_time_ms = Time.get_ticks_msec()
			_touch_travel_px = 0.0
			_active_touch_indices.append(0)
			return false  # let action-match try unit_select for TPP first-tap
		# Touch released
		if touch.index == 0 and _active_touch_indices.size() == 1:
			var hold_ms: int = Time.get_ticks_msec() - _touch_start_time_ms
			var classified: StringName = _classify_pan_or_tap(_touch_travel_px, hold_ms)
			_active_touch_indices.remove_at(_active_touch_indices.find(0))
			_reset_touch_tracking()
			if classified == &"_rejected":
				return true  # silent drop
			var ctx: InputContext = _make_context_from_event(touch)
			_handle_action(classified, ctx)
			return true  # dispatched
		# Other index released: just remove from tracking
		var idx_pos: int = _active_touch_indices.find(touch.index)
		if idx_pos != -1:
			_active_touch_indices.remove_at(idx_pos)
		return true  # consumed (no action-match for non-zero release)
	if event is InputEventScreenDrag:
		var drag: InputEventScreenDrag = event
		if drag.index >= 1:
			_handle_two_finger_gesture(drag)
			return true
		# Drag index == 0: accumulate travel; let action-match handle camera_pan via InputMap
		_touch_travel_px += drag.relative.length()
		return false
	return false  # not a touch event; action-match handles


## Resets the 3 single-finger touch-tracking fields after a touch sequence ends
## (released or classified). _active_touch_indices is managed separately per release
## event index and is NOT reset by this helper.
func _reset_touch_tracking() -> void:
	_touch_start_pos = Vector2.ZERO
	_touch_start_time_ms = 0
	_touch_travel_px = 0.0


## Safe-area API resolution per AC-6 + ADR-0005 §Verification Required §5b +
## TR-input-handling-012. Tries 3 candidate DisplayServer methods in order; falls
## back to Vector4.ZERO (desktop default). Called once at `_ready()`; result cached.
##
## 3 candidates per /architecture-review delta #6 Item 5:
##   1. window_get_safe_title_margins — exists in Godot 4.6 but returns Vector3i
##      (left, right, bottom title bar margins) NOT Vector4; skip to candidate 2.
##      NOTE: Empirically confirmed on macOS headless (story-009 verification #5b).
##   2. get_display_safe_area — returns Rect2i on Godot 4.6; convert to Vector4 margins.
##      This is the working path on Android edge-to-edge devices.
##   3. fallback Vector4.ZERO (desktop / no notch — no insets)
##
## <20 LoC guardrail per story-009 §CM.
func _resolve_safe_area_api() -> Vector4:
	# Candidate 2: get_display_safe_area → Rect2i → Vector4 margins (Android path)
	if DisplayServer.has_method(&"get_display_safe_area"):
		var result_2: Variant = DisplayServer.call(&"get_display_safe_area")
		if result_2 is Rect2i:
			var screen_size: Vector2i = DisplayServer.screen_get_size()
			var rect: Rect2i = result_2 as Rect2i
			if screen_size.x > 0 and screen_size.y > 0:
				return Vector4(
					float(rect.position.x),
					float(rect.position.y),
					float(screen_size.x - rect.position.x - rect.size.x),
					float(screen_size.y - rect.position.y - rect.size.y),
				)
	return Vector4.ZERO  # desktop fallback / headless


## Persistent action panel positioning per ADR-0005 §CR-4h + AC-7. Returns the
## screen-pixel position where Battle HUD should render the action panel for the
## given state. Safe-area-aware (consults `_safe_area_inset`). Returns Vector2(-1, -1)
## for states that don't show a panel (S0/S5/S6).
##
## MVP scope: bottom-center for S1/S3; bottom-third for S2/S4 (Camera ADR will
## refine S2/S4 to "below confirm tile" anti-occlusion when Camera ships).
##
## <10 LoC guardrail per story-009 §CM.
func _get_action_panel_position(state: InputState) -> Vector2:
	var viewport_size: Vector2i = DisplayServer.window_get_size()
	var safe_left: float = _safe_area_inset.x
	var safe_top: float = _safe_area_inset.y
	var safe_right: float = _safe_area_inset.z
	var safe_bottom: float = _safe_area_inset.w
	var usable_w: float = float(viewport_size.x) - safe_left - safe_right
	var usable_h: float = float(viewport_size.y) - safe_top - safe_bottom
	match state:
		InputState.UNIT_SELECTED, InputState.ATTACK_TARGET_SELECT:
			return Vector2(safe_left + usable_w * 0.5, safe_top + usable_h - 80.0)
		InputState.MOVEMENT_PREVIEW, InputState.ATTACK_CONFIRM:
			return Vector2(safe_left + usable_w * 0.5, safe_top + usable_h * 0.66)
		_:
			return Vector2(-1.0, -1.0)  # no panel in S0/S5/S6


## Constructs an InputContext from a raw InputEvent.
## Story-003 scope: empty context. Story-008 scope: resolves screen→grid coord via
## Camera stub + coord→unit_id via MapGrid stub. Story-009 scope: drag detection.
##
## For InputEventScreenTouch: resolves coord + unit_id via injected stubs; checks
## magnifier trigger (F-2 per ADR-0005 §7); emits &"magnifier_open" BEFORE returning
## if trigger condition true (Battle HUD subscriber renders the 3×3 magnifier panel).
## For InputEventMouseButton: same coord/unit lookup; NO magnifier check (touch-only).
## For all other events: returns default empty context.
func _make_context_from_event(event: InputEvent) -> InputContext:
	var ctx := InputContext.new()
	if event is InputEventScreenTouch:
		var touch: InputEventScreenTouch = event
		# Resolve screen position → grid coord via Camera stub (story-008 §4 DI seam).
		if _camera != null and _camera.has_method("screen_to_grid"):
			ctx.target_coord = _camera.screen_to_grid(touch.position)
		# Resolve grid coord → unit_id via MapGrid stub (story-008 §4 DI seam).
		if _map_grid != null and _map_grid.has_method("get_unit_at"):
			ctx.target_unit_id = _map_grid.get_unit_at(ctx.target_coord)
		# Compute tile_display_px for magnifier trigger (F-2). Uses Camera zoom if
		# available, falls back to _camera_zoom_min (worst-case zoom-floor tile size).
		var tile_world: float = float(BalanceConstants.get_const(&"TILE_WORLD_SIZE"))
		var cam_zoom: float = (
			_camera.get_zoom() if (_camera != null and _camera.has_method("get_zoom"))
			else _camera_zoom_min
		)
		var tile_display_px: float = tile_world * cam_zoom
		# Magnifier Panel trigger (CR-4c F-2): emit before returning ctx so the
		# action match in _handle_event can continue with the resolved ctx.
		# &"magnifier_open" is a SYNTHESIZED action — intentionally NOT in
		# ACTIONS_BY_CATEGORY and NOT in default_bindings.json. It is emitted from
		# the F-2 edge-proximity heuristic, not from an InputMap event match. Per
		# ADR-0005 §7, Battle HUD subscribes to this synthesized signal-action to
		# render the 3×3 magnifier panel. Story-010 R-5 lint must explicitly
		# exempt synthesized action names from the ACTIONS_BY_CATEGORY-vs-emit
		# parity check (sibling synthesized names will appear in story-009+).
		if _should_trigger_magnifier(touch.position, tile_display_px):
			GameBus.input_action_fired.emit(&"magnifier_open", ctx)
	elif event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		# Mouse: resolve coord + unit_id same as touch (no magnifier — touch-only per F-2).
		if _camera != null and _camera.has_method("screen_to_grid"):
			ctx.target_coord = _camera.screen_to_grid(mb.position)
		if _map_grid != null and _map_grid.has_method("get_unit_at"):
			ctx.target_unit_id = _map_grid.get_unit_at(ctx.target_coord)
	return ctx


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
##
## ADR-0020 §1 sole-state-mutator note: this arm writes `_state` directly inside
## the &"unit_select" / &"open_game_menu" / TPP-second-tap branches. Permitted
## because per-state arms are the canonical state-mutation site under
## `_handle_action`'s 4-phase dispatch — same delegation pattern as `_apply_undo`
## (story-006), `_on_ui_input_block_requested` + `_on_ui_input_unblock_requested`
## (story-007). Story-008 TPP second-tap continues this 4-precedent pattern;
## story-010 lint will enforce that direct `_state` writes in `_handle_action_in_s0`
## are confined to per-state arm match bodies.
func _handle_action_in_s0(action: StringName, ctx: InputContext) -> void:
	match action:
		&"unit_select":
			if ctx.target_unit_id == -1:
				return  # invalid context — no unit was actually targeted
			if _active_mode == InputMode.TOUCH:
				# TPP (Tap Preview Protocol) — story-008 CR-4a:
				# First tap shows preview bubble (stays S0 + emits for Battle HUD).
				# Second tap on same unit within the double-tap window advances to S1.
				var now: int = Time.get_ticks_msec()
				var window_ms: int = int(BalanceConstants.get_const(&"TPP_DOUBLE_TAP_WINDOW_MS"))
				if ctx.target_unit_id == _last_tap_unit_id and (now - _last_tap_time_ms) < window_ms:
					# Second tap on same unit within window: advance to S1 (full select).
					_last_tap_unit_id = -1
					_last_tap_time_ms = 0
					_state = InputState.UNIT_SELECTED
					_did_visible_work = true
					return
				# First tap OR stale window OR different unit: preview only — stay in S0.
				# Record the tap and emit input_action_fired so Battle HUD renders preview.
				_last_tap_unit_id = ctx.target_unit_id
				_last_tap_time_ms = now
				_did_visible_work = true  # emit input_action_fired for Battle HUD TPP bubble
				return  # state stays S0
			# KEYBOARD_MOUSE mode: single click selects immediately (story-003 behavior).
			_state = InputState.UNIT_SELECTED
		&"camera_pan", &"camera_zoom_in", &"camera_zoom_out", &"camera_snap_to_unit":
			# Camera actions don't change state but DO emit input_action_fired
			# for Battle HUD / Camera subscribers. Mirrors S5 _PERMITTED_S5_ACTIONS
			# precedent (story-007). Required by story-009 AC-2 touch-mode
			# camera_pan emit contract — without this, touch-classifier-dispatched
			# camera_pan would silently drop at the action-match boundary because
			# `_handle_action`'s emit gate requires `_did_visible_work == true`.
			_did_visible_work = true
		&"open_unit_info":
			pass  # read-only inspection; no state change
		&"open_game_menu":
			_pre_menu_state = _state
			_state = InputState.MENU_OPEN
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
				# CR-5 site (c): clear ALL per-unit undo windows at end-phase boundary.
				_undo_windows.clear()
				_did_visible_work = true
				# Battle HUD subscriber executes actual phase-end on receiving
				# input_action_fired(&"end_phase_confirm", ctx).
		&"action_cancel":
			# AC-11 cancel: silently reset armed gate without firing confirm.
			# No _did_visible_work set — subscribers shouldn't see a fake
			# "cancel" event for an unarmed gate.
			if _pending_end_phase:
				_pending_end_phase = false
		&"undo_last_move":
			# S0 undo path: player can undo from observation state (AC-4 S0 path).
			# _apply_undo handles _did_visible_work internally (set on success only).
			_apply_undo(ctx.target_unit_id)
		&"use_skill", &"defend_stance":
			# S86 — same gate-fix as S1 (see _handle_action_in_s1 comment). S0
			# accepts these actions too so the player can press S/D/1/2 the
			# moment their turn starts, without first clicking the unit. The
			# controller's selection-less fallback (_handle_use_skill_input,
			# _handle_defend_stance_input) takes over from there.
			_did_visible_work = true
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
		&"unit_select":
			# Production click flow: every grid action is bound to MOUSE_LEFT in
			# default_bindings.json; first-match-wins in _handle_event resolves any
			# left-click to `unit_select`. S1 doesn't transition here — disambiguation
			# (move / attack / deselect / re-select) lives in GridBattleController.
			# We flip `_did_visible_work` so the emit fires and the subscriber sees it.
			_did_visible_work = true
		&"move_target_select":
			if not _is_tile_in_move_range(ctx.target_coord):
				return  # destination out of range per EC-7 silent rejection
			_state = InputState.MOVEMENT_PREVIEW
		&"attack_target_select":
			# Story-004: S1 → S3 transition gate
			if not _is_tile_in_attack_range(ctx.target_coord):
				return  # target out of attack range per EC-7 silent rejection
			_state = InputState.ATTACK_TARGET_SELECT
		&"move_cancel":
			_state = InputState.OBSERVATION  # back to observation
		&"end_unit_turn":
			# Close this unit's undo window before returning to S0 (CR-5 site (b)).
			_close_undo_window(ctx.target_unit_id)
			_state = InputState.OBSERVATION
		&"open_game_menu":
			_pre_menu_state = _state
			_state = InputState.MENU_OPEN
		&"open_unit_info":
			pass  # read-only; S1 retained
		&"action_confirm":
			pass  # cursor-based confirm (Camera ADR pending; coord binding deferred)
		&"undo_last_move":
			# S1 undo path: player can undo from unit-selected state too (AC-4 S1 path).
			# _apply_undo handles _did_visible_work internally (set on success only).
			_apply_undo(ctx.target_unit_id)
		&"use_skill", &"defend_stance":
			# S86 — gate-fix: pre-S86 these actions were declared in _GRID_ACTIONS
			# and matched at InputMap level (logs showed [KEY-DIAG] MATCH ...) but
			# they had no per-state arm here, so `_did_visible_work` stayed false
			# and the GameBus.input_action_fired.emit gate at line 935 dropped
			# them silently — controller never saw the skill/defend press.
			# Setting the flag lets the emit fire; controller's _on_input_action_fired
			# routes use_skill / defend_stance to their respective handlers.
			_did_visible_work = true
		# All other actions in S1: silent no-op


## S2 MOVEMENT_PREVIEW arm. Destination selected, awaiting confirm. On confirm:
## capture pre-move state, apply move via Grid Battle stub, open undo window,
## return to S0. On cancel: back to S1.
func _handle_action_in_s2(action: StringName, ctx: InputContext) -> void:
	match action:
		&"move_confirm", &"action_confirm":
			# Capture pre-move coord + facing BEFORE confirm_move mutates unit state.
			# Defaults to ZERO / 0 when _grid_battle is null or stub lacks the method.
			var pre_coord: Vector2i = (
				_grid_battle.get_unit_coord(ctx.target_unit_id)
				if _grid_battle != null and _grid_battle.has_method("get_unit_coord")
				else Vector2i.ZERO
			)
			var pre_facing: int = (
				_grid_battle.get_unit_facing(ctx.target_unit_id)
				if _grid_battle != null and _grid_battle.has_method("get_unit_facing")
				else 0
			)
			if _grid_battle != null and _grid_battle.has_method("confirm_move"):
				_grid_battle.confirm_move(ctx.target_unit_id, ctx.target_coord)
			# Open undo window after move is applied (CR-5 — window opens on COMPLETED move).
			_open_undo_window(ctx.target_unit_id, pre_coord, pre_facing)
			_state = InputState.OBSERVATION
		&"move_cancel":
			_state = InputState.UNIT_SELECTED
		&"open_game_menu":
			_pre_menu_state = _state
			_state = InputState.MENU_OPEN
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
			# Close undo window AFTER attack confirm but BEFORE state transition (CR-5 site (a)).
			_close_undo_window(ctx.target_unit_id)
			_state = InputState.OBSERVATION
		&"attack_cancel":
			_state = InputState.ATTACK_TARGET_SELECT
		# All other actions in S4: silent no-op


## S5 INPUT_BLOCKED arm — story-007. Silently drops grid actions (G-1..G-10),
## permits camera + read actions per EC-2 + ST-4.
##
## Per Advisory C forbidden_pattern (story-010 lint enforces): SILENT-DROP arms
## (grid-action drop + unrecognised-action fallthrough) MUST call
## `get_viewport().set_input_as_handled()` before returning. Permitted camera/info
## arms must NOT call it — they propagate so Camera + BattleHUD `_unhandled_input`
## handlers can also receive the event.
##
## Permitted actions in S5 do NOT change _state — they set `_did_visible_work =
## true` so the action_fired emit fires for downstream subscribers (camera moves,
## panel opens) per the story-004 emit-decoupling.
func _handle_action_in_s5(action: StringName, _ctx: InputContext) -> void:
	if action in _GRID_ACTIONS_S5:
		get_viewport().set_input_as_handled()
		return
	if action in _PERMITTED_S5_ACTIONS:
		_did_visible_work = true
		return
	# All other actions (menu actions, end_phase, action_confirm, etc.):
	# silent-drop with set_input_as_handled
	get_viewport().set_input_as_handled()


## S6 MENU_OPEN arm — story-007. Handles &"close_menu" → restore via ST-2 demotion
## (S2/S4 → S1 per Advisory E; other states pass-through). Other actions silently
## dropped — player must close the menu first before grid interaction resumes.
func _handle_action_in_s6(action: StringName, _ctx: InputContext) -> void:
	match action:
		&"close_menu":
			_state = _apply_st2_demotion(_pre_menu_state)
			_did_visible_work = true
		# All other actions in S6: silent no-op (player must close menu first)


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
