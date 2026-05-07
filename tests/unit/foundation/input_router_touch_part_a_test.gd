extends GdUnitTestSuite

## input_router_touch_part_a_test.gd
## Story 008 tests — touch protocol part A: F-1 camera_zoom_min derivation +
## TPP (CR-4a) + Magnifier Panel trigger (CR-4c F-2) + Camera/MapGrid injection
## seams + project.godot emulate_mouse_from_touch=false + BalanceConstants 5-key check.
## Covers AC-1..AC-12.
##
## Pattern mirrors input_router_block_menu_test.gd (story-007 canonical precedent):
##   - G-3:  no class_name — InputRouter is an autoload without class_name
##   - G-10: use REAL GameBus autoload for emits (not a stub)
##   - G-15: before_test() not before_each() — GdUnit4 v6.1.2 lifecycle
##   - G-22: structural source-scan assertions use FileAccess.get_file_as_string
##   - G-23: is_equal_approx for floats; no is_not_equal_approx
##   - G-25: no nested typed collections at declaration site
##   - G-26: BattleHUDStub + CameraStub + MapGridStub class_names verified unique
##   - G-28: disconnect only test-side lambdas in after_test (never bulk-disconnect-all)

const _IR_PATH: String = "res://src/foundation/input_router.gd"
const _BALANCE_CONSTANTS_PATH: String = "res://src/foundation/balance/balance_constants.gd"
const _DEFAULT_BINDINGS_PATH: String = "res://assets/data/input/default_bindings.json"

## Test-side capture arrays and lambdas (G-28 pattern — explicit Callable references).
var _emits: Array[Dictionary] = []
var _emit_capture: Callable


func before_test() -> void:
	# G-15 canonical reset (5th-precedent autoload helper, story-010 epic-terminal).
	# Covers all 17 fields per `tools/ci/lint_input_router_g15_reset.sh`.
	InputRouter.reset_for_tests()
	# G-15 reset — full clear of all InputRouter mutable state
	(load(_BALANCE_CONSTANTS_PATH) as GDScript).set("_cache_loaded", false)
	InputRouter._state = InputRouter.InputState.OBSERVATION
	InputRouter._active_mode = InputRouter.InputMode.KEYBOARD_MOUSE
	InputRouter._last_tap_unit_id = -1
	InputRouter._last_tap_time_ms = 0
	InputRouter._camera = null
	InputRouter._map_grid = null
	InputRouter._grid_battle = null
	InputRouter._did_visible_work = false
	InputRouter._pending_end_phase = false
	InputRouter._undo_windows.clear()
	InputRouter._input_blocked_reasons.clear()
	InputRouter._pre_block_state = InputRouter.InputState.OBSERVATION
	InputRouter._pre_menu_state = InputRouter.InputState.OBSERVATION
	# Reset emit capture array
	_emits = []
	# Wire test-side capture (G-28: cache Callable reference to disconnect only this one)
	_emit_capture = func(action: String, ctx: InputContext) -> void:
		_emits.append({"action": action, "target_unit_id": ctx.target_unit_id, "target_coord": ctx.target_coord})
	GameBus.input_action_fired.connect(_emit_capture)


func after_test() -> void:
	# G-28: disconnect ONLY our test capture (NOT bulk-disconnect-all)
	if GameBus.input_action_fired.is_connected(_emit_capture):
		GameBus.input_action_fired.disconnect(_emit_capture)


# ── AC-1: F-1 camera_zoom_min derivation ─────────────────────────────────────


## AC-1: _compute_camera_zoom_min() derives 0.70 from BalanceConstants formula.
## Formula: ceilf((44 / 64) * 20) / 20 = ceilf(13.75) / 20 = 14 / 20 = 0.70
func test_compute_camera_zoom_min_derives_zoom_floor_from_balance_constants() -> void:
	var result: float = InputRouter._compute_camera_zoom_min()
	assert_float(result).override_failure_message(
		"AC-1: _compute_camera_zoom_min() must return 0.70 (F-1: ceil(44/64 * 20)/20)"
	).is_equal_approx(0.70, 0.001)


## AC-1: _camera_zoom_min field is pre-populated at autoload _ready() time.
func test_camera_zoom_min_field_cached_at_ready() -> void:
	# before_test() reset clears _cache_loaded; _camera_zoom_min already set by autoload _ready().
	# Re-calling _compute_camera_zoom_min here confirms the field holds the correct derivation.
	# The autoload boots before tests run — field should already be 0.70.
	assert_float(InputRouter._camera_zoom_min).override_failure_message(
		"AC-1: _camera_zoom_min must be 0.70 (populated by _ready() via _compute_camera_zoom_min)"
	).is_equal_approx(0.70, 0.001)


# ── AC-2: F-1 touch target minimum ≥ 44px ────────────────────────────────────


## AC-2: zoom_min * TILE_WORLD_SIZE ≥ 44px (actual 44.8px at 0.70 × 64).
## Documents the F-1 guarantee that the zoom floor ensures tiles meet the 44px touch target.
func test_zoom_min_floor_yields_touch_target_minimum_above_44px() -> void:
	var zoom_min: float = InputRouter._compute_camera_zoom_min()
	var tile_world: float = 64.0  # TILE_WORLD_SIZE constant
	var effective_px: float = zoom_min * tile_world
	assert_float(effective_px).override_failure_message(
		(
			"AC-2: zoom_min(%.4f) * TILE_WORLD_SIZE(64) = %.4f must be > 44.0px "
			+ "(touch target minimum per ADR-0005 F-1)"
		)
		% [zoom_min, effective_px]
	).is_greater(44.0)


# ── AC-3: TPP first tap — stay in S0 + record state ──────────────────────────


## AC-3: First tap in TOUCH mode stays in S0, records _last_tap_unit_id + _last_tap_time_ms,
## and emits input_action_fired (for Battle HUD TPP preview bubble).
func test_tpp_first_tap_in_touch_mode_stays_in_s0_and_records_state() -> void:
	# Arrange
	InputRouter._active_mode = InputRouter.InputMode.TOUCH
	var ctx := InputContext.new()
	ctx.target_unit_id = 5

	# Act
	InputRouter._handle_action(&"unit_select", ctx)

	# Assert — state stays S0
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-3: First TPP tap must leave _state at OBSERVATION (S0)"
	).is_equal(int(InputRouter.InputState.OBSERVATION))

	# Assert — _last_tap_unit_id recorded
	assert_int(InputRouter._last_tap_unit_id).override_failure_message(
		"AC-3: _last_tap_unit_id must record the tapped unit_id (5)"
	).is_equal(5)

	# Assert — _last_tap_time_ms non-zero (recorded)
	assert_int(InputRouter._last_tap_time_ms).override_failure_message(
		"AC-3: _last_tap_time_ms must be non-zero after first tap"
	).is_not_equal(0)

	# Assert — input_action_fired emitted for Battle HUD preview
	assert_int(_emits.size()).override_failure_message(
		"AC-3: First TPP tap must emit 1 input_action_fired for Battle HUD TPP bubble"
	).is_equal(1)
	assert_str(_emits[0]["action"] as String).override_failure_message(
		"AC-3: Emitted action must be 'unit_select'"
	).is_equal("unit_select")
	# AC-3: ctx payload propagation — Battle HUD must receive the tapped unit_id
	# so the preview bubble renders for the correct unit. Closes /code-review
	# IMPORTANT-3 / IMP-1 (godot-gdscript-specialist + qa-tester convergent finding).
	assert_int(_emits[0]["target_unit_id"] as int).override_failure_message(
		"AC-3: Emitted ctx.target_unit_id must be 5 (the tapped unit)"
	).is_equal(5)


# ── AC-4: TPP second tap variants ────────────────────────────────────────────


## AC-4: Second tap on same unit within TPP window advances to S1.
func test_tpp_second_tap_same_unit_within_window_advances_to_s1() -> void:
	# Arrange — simulate first tap already recorded 100ms ago
	InputRouter._active_mode = InputRouter.InputMode.TOUCH
	InputRouter._last_tap_unit_id = 5
	InputRouter._last_tap_time_ms = Time.get_ticks_msec() - 100
	var ctx := InputContext.new()
	ctx.target_unit_id = 5

	# Act
	InputRouter._handle_action(&"unit_select", ctx)

	# Assert — state advances to S1
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-4: Second TPP tap on same unit within window must advance to UNIT_SELECTED (S1)"
	).is_equal(int(InputRouter.InputState.UNIT_SELECTED))

	# Assert — TPP scratch state reset
	assert_int(InputRouter._last_tap_unit_id).override_failure_message(
		"AC-4: _last_tap_unit_id must be reset to -1 after second-tap advancement"
	).is_equal(-1)


## AC-4 edge: second tap on a DIFFERENT unit stays in S0 and updates _last_tap_unit_id.
func test_tpp_second_tap_different_unit_stays_in_s0_and_updates_last_tap_unit_id() -> void:
	# Arrange — previous tap on unit 5, recent timestamp
	InputRouter._active_mode = InputRouter.InputMode.TOUCH
	InputRouter._last_tap_unit_id = 5
	InputRouter._last_tap_time_ms = Time.get_ticks_msec() - 100
	var ctx := InputContext.new()
	ctx.target_unit_id = 7  # different unit

	# Act
	InputRouter._handle_action(&"unit_select", ctx)

	# Assert — state stays S0 (no advancement for different unit)
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-4 edge: tap on different unit must NOT advance state; must stay OBSERVATION (S0)"
	).is_equal(int(InputRouter.InputState.OBSERVATION))

	# Assert — _last_tap_unit_id updated to new unit
	assert_int(InputRouter._last_tap_unit_id).override_failure_message(
		"AC-4 edge: _last_tap_unit_id must update to the newly-tapped unit_id (7)"
	).is_equal(7)


## AC-4 edge: second tap on same unit but AFTER window expiry stays in S0 (re-arms tap).
func test_tpp_second_tap_window_expired_stays_in_s0() -> void:
	# Arrange — previous tap on unit 5, but 600ms ago (beyond 500ms window)
	InputRouter._active_mode = InputRouter.InputMode.TOUCH
	InputRouter._last_tap_unit_id = 5
	InputRouter._last_tap_time_ms = Time.get_ticks_msec() - 600
	var ctx := InputContext.new()
	ctx.target_unit_id = 5

	# Act
	InputRouter._handle_action(&"unit_select", ctx)

	# Assert — state stays S0 (window expired)
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-4 edge: tap after window expiry must NOT advance to S1; must stay OBSERVATION (S0)"
	).is_equal(int(InputRouter.InputState.OBSERVATION))

	# Assert — _last_tap_unit_id re-armed to same unit
	assert_int(InputRouter._last_tap_unit_id).override_failure_message(
		"AC-4 edge: _last_tap_unit_id must be re-set to 5 (re-armed on expired window)"
	).is_equal(5)


# ── Mode fork: KEYBOARD_MOUSE single-click advances directly to S1 ────────────


## Mode fork: KEYBOARD_MOUSE unit_select advances directly to S1 (no TPP gating).
func test_keyboard_mouse_mode_unit_select_single_click_advances_to_s1() -> void:
	# Arrange — ensure KEYBOARD_MOUSE mode (default)
	InputRouter._active_mode = InputRouter.InputMode.KEYBOARD_MOUSE
	var ctx := InputContext.new()
	ctx.target_unit_id = 5

	# Act
	InputRouter._handle_action(&"unit_select", ctx)

	# Assert — state advances directly to S1 (no TPP double-tap requirement)
	assert_int(int(InputRouter._state)).override_failure_message(
		"Mode fork: KEYBOARD_MOUSE unit_select must advance directly to UNIT_SELECTED (S1)"
	).is_equal(int(InputRouter.InputState.UNIT_SELECTED))


# ── AC-5: _should_trigger_magnifier helper ────────────────────────────────────


## AC-5: Returns true when edge_offset < DISAMBIG_EDGE_PX threshold (8px).
## Test: touch_pos=(54, 100), tile=48px → fmod(54,48)=6 → edge_offset=min(6,42)=6 < 8 → true.
func test_should_trigger_magnifier_returns_true_when_edge_offset_below_threshold() -> void:
	# fmod(54.0, 48.0) = 6.0 → x_edge = min(6, 42) = 6 < 8 threshold
	var result: bool = InputRouter._should_trigger_magnifier(Vector2(54.0, 100.0), 48.0)
	assert_bool(result).override_failure_message(
		"AC-5: edge_offset=6 < DISAMBIG_EDGE_PX=8 must trigger magnifier"
	).is_true()


## AC-5 edge: Returns false when BOTH x and y edge_offsets >= threshold AND tile >= tile threshold.
## Test: touch_pos=(20, 20), tile=48px → fmod(20,48)=20 → x_edge=min(20,28)=20 > 8 AND
## y_edge=min(20,28)=20 > 8 AND tile 48 > 32 → false.
func test_should_trigger_magnifier_returns_false_when_edge_offset_above_and_tile_above() -> void:
	# Both x and y are 20px into a 48px tile → edge_offset = min(20, 28) = 20 > 8 threshold
	# tile_display_px = 48 > 32 tile threshold → neither condition triggers magnifier
	var result: bool = InputRouter._should_trigger_magnifier(Vector2(20.0, 20.0), 48.0)
	assert_bool(result).override_failure_message(
		"AC-5 edge: edge_offset=20 > 8 AND tile_px=48 > 32 must NOT trigger magnifier"
	).is_false()


# ── AC-5 + AC-6: tile below size threshold ────────────────────────────────────


## AC-5 + AC-6: Returns true when tile_display_px < DISAMBIG_TILE_PX (32px) regardless
## of edge position. Zoomed too far out to tap precisely — always trigger magnifier.
func test_should_trigger_magnifier_returns_true_when_tile_size_below_threshold() -> void:
	# tile_display_px = 30 < 32 threshold → trigger regardless of edge offset
	var result: bool = InputRouter._should_trigger_magnifier(Vector2(60.0, 100.0), 30.0)
	assert_bool(result).override_failure_message(
		"AC-5+AC-6: tile_display_px=30 < DISAMBIG_TILE_PX=32 must always trigger magnifier"
	).is_true()


# ── AC-7: No hover-only actions in TOUCH mode ─────────────────────────────────


## AC-7: grid_hover must NOT be in default_bindings.json (PC-only per CR-1c).
func test_no_hover_only_action_grid_hover_absent_in_default_bindings() -> void:
	var content: String = FileAccess.get_file_as_string(_DEFAULT_BINDINGS_PATH)
	assert_bool(content.length() > 0).override_failure_message(
		"AC-7: default_bindings.json must exist and be non-empty"
	).is_true()

	# Assert grid_hover is NOT in the bindings (PC-only per CR-1c)
	assert_bool(content.contains("\"grid_hover\"")).override_failure_message(
		"AC-7: grid_hover must NOT be in default_bindings.json (PC-only hover; touch devices have no hover)"
	).is_false()


## Set of actions that reach touch users via Battle HUD button widgets (per CR-4h
## persistent action panel, story-009 scope) rather than via raw InputMap screen_touch
## entries. `screen_touch` is positionless — adding it to N actions would cause every
## screen tap to multi-fire all N actions simultaneously. The actual touch-reachability
## architecture per ADR-0005 §3 is:
##   Direct InputMap touch (4 actions): unit_select / move_target_select /
##     attack_target_select consume raw screen taps via TPP (story-008 CR-4a);
##     camera_pan consumes screen_drag.
##   Battle HUD button-reachable (17 actions): everything else routes via Control
##     _gui_input → button.pressed → action dispatch. Story-009 wires the buttons;
##     story-008 establishes the contract.
##   PC-only (1 action): grid_hover absent from default_bindings.json (CR-1c).
const _AC7_BATTLE_HUD_REACHABLE: PackedStringArray = [
	"move_confirm", "move_cancel",
	"attack_confirm", "attack_cancel",
	"undo_last_move", "end_unit_turn",
	"camera_zoom_in", "camera_zoom_out", "camera_snap_to_unit",
	"open_unit_info", "open_game_menu", "close_menu",
	"end_player_turn", "end_phase_confirm",
	"action_confirm", "action_cancel", "toggle_input_hints",
]


## AC-7 positive reachability sweep: every action in ACTIONS_BY_CATEGORY (excluding
## `grid_hover` PC-only per CR-1c) MUST be reachable in TOUCH mode through SOME path.
## Closes /code-review IMPORTANT-2 / IMP-2 (godot-gdscript-specialist + qa-tester
## convergent finding) — the original AC-7 test only checked grid_hover absence;
## the spec mandated positive coverage of all 21 non-hover actions.
##
## SPEC INTERPRETATION NOTE: The literal AC-7 spec wording requests "every action
## must have a screen_touch entry in default_bindings.json". That literal reading
## conflicts with ADR-0005 §3 architecture: `screen_touch` is positionless; adding
## it to 17 button-reachable actions would multi-fire on every tap. The realistic
## AC-7 contract per ADR-0005 §3 + CR-4h is that every action is REACHABLE on touch,
## either directly (4 grid actions) or via Battle HUD button widgets (17 actions).
## This test enforces that reachability split, locking the architecture so a future
## edit that drops `screen_touch` from one of the 4 direct-dispatch actions or adds
## an unexpected action to the JSON without classification fails loud.
func test_all_non_hover_actions_have_touch_reachability() -> void:
	var content: String = FileAccess.get_file_as_string(_DEFAULT_BINDINGS_PATH)
	var json := JSON.new()
	var parse_result: int = json.parse(content)
	assert_int(parse_result).override_failure_message(
		"AC-7 sweep: default_bindings.json must parse cleanly"
	).is_equal(OK)
	var bindings: Dictionary = json.data as Dictionary

	var missing_reachability: Array[String] = []
	for category: StringName in InputRouter.ACTIONS_BY_CATEGORY.keys():
		for action: StringName in InputRouter.ACTIONS_BY_CATEGORY[category]:
			if action == &"grid_hover":
				continue  # PC-only per CR-1c — correctly absent from JSON
			var action_str: String = String(action)
			if not bindings.has(action_str):
				missing_reachability.append("%s [no key in JSON]" % action_str)
				continue
			# Battle HUD button-reachable actions don't need screen_touch — they
			# dispatch via Control widget tap. Verify the action is correctly
			# classified (in the exempt list) and skip the touch-event check.
			if action_str in _AC7_BATTLE_HUD_REACHABLE:
				continue  # CR-4h Battle HUD path — touch reaches via button widget
			# Direct-dispatch grid action — must have at least one screen_touch
			# or screen_drag entry per ADR-0005 §3 + CR-4a.
			var events: Array = bindings[action_str] as Array
			var has_touch: bool = false
			for event_variant: Variant in events:
				if not (event_variant is Dictionary):
					continue
				var event_dict: Dictionary = event_variant as Dictionary
				var ev_type: String = event_dict.get("type", "") as String
				if ev_type == "screen_touch" or ev_type == "screen_drag":
					has_touch = true
					break
			if not has_touch:
				missing_reachability.append(
					"%s [direct-dispatch action lacks screen_touch/screen_drag]" % action_str
				)

	assert_int(missing_reachability.size()).override_failure_message(
		(
			"AC-7 sweep: every non-grid_hover action must be touch-reachable. Direct-"
			+ "dispatch actions need screen_touch/screen_drag in default_bindings.json; "
			+ "Battle HUD-reachable actions must be in _AC7_BATTLE_HUD_REACHABLE per "
			+ "ADR-0005 §3 + CR-4h. Missing or unclassified: %s"
		)
		% str(missing_reachability)
	).is_equal(0)


# ── AC-8: emulate_mouse_from_touch=false in project.godot ────────────────────


## AC-8: project.godot must contain [input_devices.pointing] section with
## emulate_mouse_from_touch=false to prevent double-fire of touch events.
func test_emulate_mouse_from_touch_disabled_in_project_godot() -> void:
	var content: String = FileAccess.get_file_as_string("res://project.godot")
	assert_bool(content.contains("[input_devices.pointing]")).override_failure_message(
		"AC-8: project.godot must contain [input_devices.pointing] section"
	).is_true()
	assert_bool(content.contains("emulate_mouse_from_touch=false")).override_failure_message(
		"AC-8: project.godot must set emulate_mouse_from_touch=false to prevent double-fire"
	).is_true()


# ── AC-9: DisplayServer.screen_get_size smoke gate ────────────────────────────


## AC-9: DisplayServer.screen_get_size() returns a sane logical pixel value.
## Smoke gate — not a strict assertion. Polish-deferred Android device confirmation.
## In headless CI mode, screen_get_size() returns (0, 0) — the API must be callable
## without crashing; the positive-dimension check is only meaningful on a display-backed run.
##
## Closes /code-review IMPORTANT-2 / IMP-3 (godot-gdscript-specialist + qa-tester
## convergent finding) — the original implementation included a tautology
## `assert_bool(true).is_true()` line at end-of-body that was a structural
## false-pass (same class as S9-02 IMPORTANT-3). Removed in-patch — reaching the
## conditional bound assertion proves the API was callable without exception;
## no separate "callable" assertion needed.
func test_displayserver_screen_get_size_returns_sane_logical_resolution() -> void:
	var size: Vector2i = DisplayServer.screen_get_size()
	# Two valid outcomes: headless CI returns (0, 0) — the API was callable without
	# exception (which itself is the AC-9 smoke gate). Display-backed dev box returns
	# a non-zero Vector2i — assert it is below the runaway upper bound.
	if size.x > 0 or size.y > 0:
		# Display-backed run: sanity upper bound (Retina dev box ~2880x1800 logical).
		assert_bool(size.x < 16000 and size.y < 16000).override_failure_message(
			("AC-9: DisplayServer.screen_get_size() returned unexpectedly large dimensions: %s" % str(size))
		).is_true()
	# Headless: size = (0, 0) is the expected AC-9 outcome (API callable without crashing).
	# No additional assertion needed — the test reaching this comment proves callability.


# ── AC-10: Stub verification ──────────────────────────────────────────────────


## AC-10: BattleHUDStub records all method invocations with correct payload shapes.
func test_battle_hud_stub_records_method_calls() -> void:
	var stub := BattleHUDStub.new()

	# Act
	stub.show_unit_info(5)
	stub.show_tile_info(Vector2i(3, 4))
	stub.dismiss_preview()
	var cluster: Array[Vector2i] = [Vector2i(1, 1), Vector2i(1, 2)]
	stub.show_magnifier(Vector2(100.0, 200.0), cluster)

	# Assert show_unit_info
	assert_int(stub.show_unit_info_calls.size()).override_failure_message(
		"AC-10: show_unit_info_calls must have 1 entry"
	).is_equal(1)
	assert_int(stub.show_unit_info_calls[0]["unit_id"] as int).override_failure_message(
		"AC-10: show_unit_info_calls[0].unit_id must be 5"
	).is_equal(5)

	# Assert show_tile_info
	assert_int(stub.show_tile_info_calls.size()).override_failure_message(
		"AC-10: show_tile_info_calls must have 1 entry"
	).is_equal(1)
	var recorded_coord: Vector2i = stub.show_tile_info_calls[0]["coord"] as Vector2i
	assert_int(recorded_coord.x).override_failure_message(
		"AC-10: show_tile_info_calls[0].coord.x must be 3"
	).is_equal(3)
	assert_int(recorded_coord.y).override_failure_message(
		"AC-10: show_tile_info_calls[0].coord.y must be 4"
	).is_equal(4)

	# Assert dismiss_preview
	assert_int(stub.dismiss_preview_calls).override_failure_message(
		"AC-10: dismiss_preview_calls must be 1"
	).is_equal(1)

	# Assert show_magnifier
	assert_int(stub.show_magnifier_calls.size()).override_failure_message(
		"AC-10: show_magnifier_calls must have 1 entry"
	).is_equal(1)


## AC-10: CameraStub.clamp_zoom enforces F-1 floor at 0.70.
func test_camera_stub_clamp_zoom_enforces_f1_floor() -> void:
	var stub := CameraStub.new()

	# Below floor — should clamp to 0.70
	assert_float(stub.clamp_zoom(0.5)).override_failure_message(
		"AC-10: CameraStub.clamp_zoom(0.5) must return 0.70 (F-1 floor)"
	).is_equal_approx(0.70, 0.001)

	# Above floor — should pass through unchanged
	assert_float(stub.clamp_zoom(1.0)).override_failure_message(
		"AC-10: CameraStub.clamp_zoom(1.0) must return 1.0 (above floor; no clamping)"
	).is_equal_approx(1.0, 0.001)


## AC-10: MapGridStub.get_unit_at returns -1 for unfixtured coords + correct value for fixtured.
## G-6: MapGridStub extends MapGrid (a Node subclass); must call free() at end of test body.
func test_map_grid_stub_get_unit_at_returns_minus_one_for_unfixtured_coord() -> void:
	var stub := MapGridStub.new()

	# Unfixtured coord returns -1 sentinel
	assert_int(stub.get_unit_at(Vector2i(99, 99))).override_failure_message(
		"AC-10: MapGridStub.get_unit_at on unfixtured coord must return -1"
	).is_equal(-1)

	# Populated coord returns the fixtured unit_id
	stub.unit_at_coord[Vector2i(3, 3)] = 7
	assert_int(stub.get_unit_at(Vector2i(3, 3))).override_failure_message(
		"AC-10: MapGridStub.get_unit_at on fixtured coord must return 7"
	).is_equal(7)

	# G-6: free Node to prevent orphan detection between test body exit and after_test
	stub.free()


# ── AC-12: BalanceConstants 5-key check ──────────────────────────────────────


## AC-12: All 5 input-handling BalanceConstants keys present with expected values.
func test_balance_constants_input_handling_5_keys_present_with_expected_values() -> void:
	assert_int(int(BalanceConstants.get_const(&"TOUCH_TARGET_MIN_PX"))).override_failure_message(
		"AC-12: TOUCH_TARGET_MIN_PX must be 44"
	).is_equal(44)

	assert_int(int(BalanceConstants.get_const(&"TILE_WORLD_SIZE"))).override_failure_message(
		"AC-12: TILE_WORLD_SIZE must be 64"
	).is_equal(64)

	assert_int(int(BalanceConstants.get_const(&"TPP_DOUBLE_TAP_WINDOW_MS"))).override_failure_message(
		"AC-12: TPP_DOUBLE_TAP_WINDOW_MS must be 500"
	).is_equal(500)

	assert_int(int(BalanceConstants.get_const(&"DISAMBIG_EDGE_PX"))).override_failure_message(
		"AC-12: DISAMBIG_EDGE_PX must be 8"
	).is_equal(8)

	assert_int(int(BalanceConstants.get_const(&"DISAMBIG_TILE_PX"))).override_failure_message(
		"AC-12: DISAMBIG_TILE_PX must be 32"
	).is_equal(32)


# ── AC-10 integration: Camera/MapGrid stubs through `_make_context_from_event` ──
# Closes /code-review BLOCK-1 (qa-tester) — the 3 stub-isolation tests above
# verified each stub in isolation, but no test drove an InputEventScreenTouch
# through the production pipeline with stubs INJECTED on the InputRouter autoload
# via set_camera_for_tests / set_map_grid_for_tests. This story is classified
# Integration type per spec Test Evidence section (line 341); these 3 tests
# fulfill the integration evidence requirement.


## AC-10 integration: `_make_context_from_event(InputEventScreenTouch)` resolves
## both `target_coord` (via Camera stub) and `target_unit_id` (via MapGrid stub)
## when both stubs are injected via the public test seams.
func test_make_context_from_event_touch_resolves_coord_and_unit_via_stubs() -> void:
	# Arrange — inject both stubs via public test seams
	var camera := CameraStub.new()
	camera.screen_to_grid_map[Vector2i(200, 200)] = Vector2i(3, 3)
	var map_grid := MapGridStub.new()
	map_grid.unit_at_coord[Vector2i(3, 3)] = 7
	InputRouter.set_camera_for_tests(camera)
	InputRouter.set_map_grid_for_tests(map_grid)

	var touch := InputEventScreenTouch.new()
	touch.position = Vector2(200.0, 200.0)
	touch.pressed = true

	# Act
	var ctx: InputContext = InputRouter._make_context_from_event(touch)

	# Assert — coord resolved via Camera stub
	assert_int(ctx.target_coord.x).override_failure_message(
		"AC-10 integration: ctx.target_coord.x must be 3 (CameraStub fixture lookup)"
	).is_equal(3)
	assert_int(ctx.target_coord.y).override_failure_message(
		"AC-10 integration: ctx.target_coord.y must be 3 (CameraStub fixture lookup)"
	).is_equal(3)

	# Assert — unit_id resolved via MapGrid stub at the resolved coord
	assert_int(ctx.target_unit_id).override_failure_message(
		"AC-10 integration: ctx.target_unit_id must be 7 (MapGridStub fixture at (3,3))"
	).is_equal(7)

	# Cleanup — MapGridStub extends Node (G-6 obligation)
	map_grid.free()


## AC-10 integration: `_make_context_from_event` emits `&"magnifier_open"` via
## GameBus.input_action_fired when the F-2 trigger condition is met (touch near
## tile boundary OR tile_display_px below threshold). The Battle HUD subscriber
## consumes this synthesized signal-action to render the magnifier panel.
func test_make_context_from_event_touch_emits_magnifier_open_when_trigger_condition_true() -> void:
	# Arrange — inject Camera with low zoom (forces tile_display_px below threshold).
	# tile_world * 0.4 = 64 * 0.4 = 25.6 px display tile, below DISAMBIG_TILE_PX=32 → trigger.
	var camera := CameraStub.new()
	camera.set_zoom(1.0)  # set_zoom clamps to 0.70 floor; we'll override directly below
	camera.current_zoom = 0.4  # bypass clamp for test purposes (force F-2 trigger)
	var map_grid := MapGridStub.new()
	InputRouter.set_camera_for_tests(camera)
	InputRouter.set_map_grid_for_tests(map_grid)

	var touch := InputEventScreenTouch.new()
	touch.position = Vector2(100.0, 100.0)
	touch.pressed = true

	# Act
	var _ctx: InputContext = InputRouter._make_context_from_event(touch)

	# Assert — magnifier_open emitted (synthesized action, not in ACTIONS_BY_CATEGORY)
	var found_magnifier: bool = false
	for emit_record: Dictionary in _emits:
		if emit_record["action"] == "magnifier_open":
			found_magnifier = true
			break
	assert_bool(found_magnifier).override_failure_message(
		(
			"AC-10 integration: _make_context_from_event must emit &\"magnifier_open\" "
			+ "when F-2 trigger condition is true (tile_display_px=25.6 < 32). Captured emits: %s"
		)
		% str(_emits)
	).is_true()

	# Cleanup
	map_grid.free()


## AC-10 integration: `_make_context_from_event` does NOT emit `&"magnifier_open"`
## when both F-2 trigger conditions are false (tap far from edge AND tile size
## above threshold). Negative-coverage sentinel.
func test_make_context_from_event_touch_no_magnifier_emit_when_trigger_condition_false() -> void:
	# Arrange — inject Camera with full zoom (large tile_display_px, no F-2 trigger).
	# tile_world * 1.0 = 64 px display tile, above DISAMBIG_TILE_PX=32. Touch at
	# (20, 20) gives fmod(20, 64)=20, edge_offset=min(20, 44)=20 > DISAMBIG_EDGE_PX=8.
	var camera := CameraStub.new()
	camera.current_zoom = 1.0
	var map_grid := MapGridStub.new()
	InputRouter.set_camera_for_tests(camera)
	InputRouter.set_map_grid_for_tests(map_grid)

	var touch := InputEventScreenTouch.new()
	touch.position = Vector2(20.0, 20.0)
	touch.pressed = true

	# Act
	var _ctx: InputContext = InputRouter._make_context_from_event(touch)

	# Assert — NO magnifier_open emit
	for emit_record: Dictionary in _emits:
		assert_str(emit_record["action"] as String).override_failure_message(
			(
				"AC-10 integration: _make_context_from_event must NOT emit &\"magnifier_open\" "
				+ "when F-2 trigger condition is false (edge_offset=20 > 8 AND tile_display=64 > 32). "
				+ "Spurious emit: %s"
			)
			% str(emit_record)
		).is_not_equal("magnifier_open")

	# Cleanup
	map_grid.free()
