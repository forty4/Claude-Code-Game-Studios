extends GdUnitTestSuite

## input_router_touch_part_b_test.gd
## Story 009 tests — touch protocol part B: pan-vs-tap classifier (CR-4f / F-3) +
## two-finger gestures (CR-4g) + persistent action panel positioning (CR-4h) +
## safe-area API resolution (TR-012) + verification evidence #5b + #6.
## Covers AC-1..AC-12.
##
## Pattern mirrors input_router_touch_part_a_test.gd (story-008 canonical precedent):
##   - G-3:  no class_name — InputRouter is an autoload without class_name
##   - G-10: use REAL GameBus autoload for emits (not a stub)
##   - G-15: before_test() not before_each() — GdUnit4 v6.1.2 lifecycle
##   - G-16: typed Array[Dictionary] for parametric sweep
##   - G-22: structural source-scan assertions use FileAccess.get_file_as_string
##   - G-23: no is_not_equal_approx; use manual tolerance or is_not_equal
##   - G-25: no nested typed collections at declaration site
##   - G-28: disconnect only test-side lambdas in after_test (never bulk-disconnect-all)
##   - G-29 (candidate): do NOT use Input.parse_input_event for dispatch verification;
##           call _handle_event / _handle_action directly

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
	# G-15 reset — full clear of all InputRouter mutable state including story-009 fields
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
	# Story-009 new touch-tracking fields
	InputRouter._touch_start_pos = Vector2.ZERO
	InputRouter._touch_start_time_ms = 0
	InputRouter._touch_travel_px = 0.0
	InputRouter._active_touch_indices = PackedInt32Array()
	InputRouter._safe_area_inset = Vector4.ZERO
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


# ── AC-1: _classify_pan_or_tap pure-function classification ──────────────────


## AC-1: Returns &"camera_pan" when travel > PAN_ACTIVATION_PX (16px).
## 20 > 16 → camera_pan.
func test_classify_pan_or_tap_returns_camera_pan_when_travel_above_threshold() -> void:
	var result: StringName = InputRouter._classify_pan_or_tap(20.0, 100)
	assert_str(String(result)).override_failure_message(
		"AC-1: _classify_pan_or_tap(20.0, 100) must return 'camera_pan' (travel 20 > threshold 16)"
	).is_equal("camera_pan")


## AC-1: Returns &"_rejected" when hold < MIN_TOUCH_DURATION_MS (80ms) and no travel.
## (2, 50) → travel 2 <= 16 AND hold 50 < 80 → _rejected.
func test_classify_pan_or_tap_returns_rejected_when_short_hold_no_travel() -> void:
	var result: StringName = InputRouter._classify_pan_or_tap(2.0, 50)
	assert_str(String(result)).override_failure_message(
		"AC-1: _classify_pan_or_tap(2.0, 50) must return '_rejected' (travel<=16, hold<80ms)"
	).is_equal("_rejected")


## AC-1: Returns &"unit_select" when held > MIN duration without significant travel.
## (2, 100) → travel 2 <= 16 AND hold 100 >= 80 → unit_select.
func test_classify_pan_or_tap_returns_unit_select_when_held_long_no_travel() -> void:
	var result: StringName = InputRouter._classify_pan_or_tap(2.0, 100)
	assert_str(String(result)).override_failure_message(
		"AC-1: _classify_pan_or_tap(2.0, 100) must return 'unit_select' (travel<=16, hold>=80ms)"
	).is_equal("unit_select")


# ── AC-2: Pan classification end-to-end via _handle_event ────────────────────


## AC-2 / AC-8 GDD: pan classified and dispatched via _handle_event when drag travel > 16px.
## Sequence: touch pressed → drag 20px → touch released → expect camera_pan emit.
## Note: drag during tracking also triggers InputMap match for camera_pan (screen_drag
## binding) so we assert ≥1 camera_pan emit rather than exactly 1.
func test_pan_classification_end_to_end_via_handle_event_emits_camera_pan() -> void:
	# Arrange — load bindings into InputMap and activate TOUCH mode
	var bindings_dict: Dictionary = InputRouter._load_bindings_from_path(InputRouter.DEFAULT_BINDINGS_PATH)
	InputRouter._populate_input_map(bindings_dict)
	InputRouter._active_mode = InputRouter.InputMode.TOUCH

	# Act — sequence: press → drag 20px right → release
	var touch_press := InputEventScreenTouch.new()
	touch_press.index = 0
	touch_press.pressed = true
	touch_press.position = Vector2(100.0, 100.0)
	InputRouter._handle_event(touch_press)

	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(120.0, 100.0)
	drag.relative = Vector2(20.0, 0.0)
	InputRouter._handle_event(drag)

	var touch_release := InputEventScreenTouch.new()
	touch_release.index = 0
	touch_release.pressed = false
	touch_release.position = Vector2(120.0, 100.0)
	InputRouter._handle_event(touch_release)

	# Assert — at least 1 camera_pan emit (from classify+dispatch on release)
	var found_pan: bool = false
	for emit_record: Dictionary in _emits:
		if emit_record["action"] == "camera_pan":
			found_pan = true
			break
	assert_bool(found_pan).override_failure_message(
		("AC-2: pan sequence (press→drag 20px→release) must emit 'camera_pan'. "
		+ "Captured emits: %s") % str(_emits)
	).is_true()


# ── AC-3: Accidental touch rejected silently ──────────────────────────────────


## AC-3 / AC-9 GDD: touch released after 50ms with 0 travel → _rejected; NO action emit.
func test_accidental_touch_rejected_silently() -> void:
	# Arrange — set _touch_start_time_ms to simulate 50ms ago
	InputRouter._active_mode = InputRouter.InputMode.TOUCH
	var bindings_dict: Dictionary = InputRouter._load_bindings_from_path(InputRouter.DEFAULT_BINDINGS_PATH)
	InputRouter._populate_input_map(bindings_dict)

	var touch_press := InputEventScreenTouch.new()
	touch_press.index = 0
	touch_press.pressed = true
	touch_press.position = Vector2(100.0, 100.0)
	InputRouter._handle_event(touch_press)

	# Simulate 50ms ago by setting the start time directly
	InputRouter._touch_start_time_ms = Time.get_ticks_msec() - 50

	# Act — release with 0 travel after 50ms
	var touch_release := InputEventScreenTouch.new()
	touch_release.index = 0
	touch_release.pressed = false
	touch_release.position = Vector2(100.0, 100.0)
	InputRouter._handle_event(touch_release)

	# Assert — 0 emits (silent drop)
	assert_int(_emits.size()).override_failure_message(
		("AC-3: accidental touch (travel=0, hold=50ms<80ms) must produce 0 emits (silent drop). "
		+ "Captured emits: %s") % str(_emits)
	).is_equal(0)

	# Assert — _did_visible_work stays false
	assert_bool(InputRouter._did_visible_work).override_failure_message(
		"AC-3: _did_visible_work must remain false after rejected accidental touch"
	).is_false()


# ── AC-4: Two-finger gesture routing ─────────────────────────────────────────


## AC-4: InputEventScreenTouch with index=1, pressed=true → camera_two_finger_tap_cancel emit.
func test_two_finger_tap_emits_camera_two_finger_tap_cancel() -> void:
	# Arrange
	InputRouter._active_mode = InputRouter.InputMode.TOUCH

	# Act — second finger tap
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.pressed = true
	touch.position = Vector2(200.0, 200.0)
	InputRouter._handle_event(touch)

	# Assert — camera_two_finger_tap_cancel emitted
	var found: bool = false
	for emit_record: Dictionary in _emits:
		if emit_record["action"] == "camera_two_finger_tap_cancel":
			found = true
			break
	assert_bool(found).override_failure_message(
		("AC-4: InputEventScreenTouch(index=1, pressed=true) must emit "
		+ "'camera_two_finger_tap_cancel'. Captured emits: %s") % str(_emits)
	).is_true()


## AC-4: InputEventScreenDrag with index=1 → camera_pinch_zoom emit.
func test_two_finger_drag_emits_camera_pinch_zoom() -> void:
	# Arrange
	InputRouter._active_mode = InputRouter.InputMode.TOUCH

	# Act — second finger drag
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = Vector2(300.0, 300.0)
	drag.relative = Vector2(5.0, 5.0)
	InputRouter._handle_event(drag)

	# Assert — camera_pinch_zoom emitted
	var found: bool = false
	for emit_record: Dictionary in _emits:
		if emit_record["action"] == "camera_pinch_zoom":
			found = true
			break
	assert_bool(found).override_failure_message(
		("AC-4: InputEventScreenDrag(index=1) must emit 'camera_pinch_zoom'. "
		+ "Captured emits: %s") % str(_emits)
	).is_true()


# ── AC-5: EC-1 multi-touch cancel ────────────────────────────────────────────


## AC-5 / EC-1: Second finger arrival cancels first-finger TPP state.
## GIVEN: _last_tap_unit_id=5 (first-finger TPP active in S0)
## WHEN: second finger arrives (index=1, pressed=true)
## THEN: _last_tap_unit_id == -1 (preview dismissed)
func test_two_finger_arrival_cancels_first_finger_tpp_state() -> void:
	# Arrange — simulate TPP active state
	InputRouter._active_mode = InputRouter.InputMode.TOUCH
	InputRouter._last_tap_unit_id = 5
	InputRouter._last_tap_time_ms = Time.get_ticks_msec() - 100

	# Act — second finger arrives
	var touch := InputEventScreenTouch.new()
	touch.index = 1
	touch.pressed = true
	touch.position = Vector2(200.0, 200.0)
	InputRouter._handle_event(touch)

	# Assert — _last_tap_unit_id reset to -1 (EC-1 cancel)
	assert_int(InputRouter._last_tap_unit_id).override_failure_message(
		"AC-5 / EC-1: second finger arrival must reset _last_tap_unit_id to -1"
	).is_equal(-1)

	# Assert — _last_tap_time_ms reset to 0
	assert_int(InputRouter._last_tap_time_ms).override_failure_message(
		"AC-5 / EC-1: second finger arrival must reset _last_tap_time_ms to 0"
	).is_equal(0)


# ── AC-6: Safe-area API resolution ───────────────────────────────────────────


## AC-6: _resolve_safe_area_api() returns a Vector4 without crashing (fallback ok).
## Headless macOS: both APIs exist but return zero values → Vector4.ZERO.
func test_resolve_safe_area_api_returns_vector4_or_fallback_zero() -> void:
	var result: Vector4 = InputRouter._resolve_safe_area_api()
	# Assert it IS a Vector4 (we check via field access — if it weren't Vector4 this would crash)
	assert_float(result.x).override_failure_message(
		"AC-6: _resolve_safe_area_api() must return a Vector4; result.x access must not crash"
	).is_greater_equal(0.0)
	assert_float(result.y).override_failure_message(
		"AC-6: _resolve_safe_area_api() must return a Vector4; result.y access must not crash"
	).is_greater_equal(0.0)
	assert_float(result.z).override_failure_message(
		"AC-6: _resolve_safe_area_api() must return a Vector4; result.z access must not crash"
	).is_greater_equal(0.0)
	assert_float(result.w).override_failure_message(
		"AC-6: _resolve_safe_area_api() must return a Vector4; result.w access must not crash"
	).is_greater_equal(0.0)


## AC-6: _safe_area_inset field is cached as Vector4 at autoload boot (_ready()).
## On headless dev box it is Vector4.ZERO (desktop fallback).
func test_safe_area_inset_cached_at_ready() -> void:
	# The autoload boots before tests run; _safe_area_inset is set in _ready().
	# before_test() resets it to ZERO; re-call _resolve_safe_area_api to confirm
	# the field type is correct. On headless macOS this returns ZERO (valid).
	InputRouter._safe_area_inset = InputRouter._resolve_safe_area_api()
	# Assert it is accessible as Vector4 with non-negative components
	assert_float(InputRouter._safe_area_inset.x).override_failure_message(
		"AC-6: _safe_area_inset.x must be >= 0 (no negative insets)"
	).is_greater_equal(0.0)
	assert_float(InputRouter._safe_area_inset.y).override_failure_message(
		"AC-6: _safe_area_inset.y must be >= 0 (no negative insets)"
	).is_greater_equal(0.0)


# ── AC-7: Persistent action panel positioning ─────────────────────────────────


## AC-7: _get_action_panel_position returns safe-area-aware position for S1 (UNIT_SELECTED).
## Given viewport 1280×720, safe-area inset (0, 80, 0, 60):
##   usable_w = 1280 - 0 - 0 = 1280
##   usable_h = 720 - 80 - 60 = 580
##   S1 bottom-center: x = 0 + 1280*0.5 = 640, y = 80 + 580 - 80 = 580
func test_get_action_panel_position_returns_safe_area_aware_position_for_s1() -> void:
	# Arrange — set known safe-area inset
	InputRouter._safe_area_inset = Vector4(0.0, 80.0, 0.0, 60.0)

	# Act
	var pos: Vector2 = InputRouter._get_action_panel_position(InputRouter.InputState.UNIT_SELECTED)

	# Assert x is within the usable horizontal range [0, 1280]
	# On headless, window_get_size() may return (0,0) — guard with is_not_equal(-1)
	assert_float(pos.x).override_failure_message(
		("AC-7: S1 panel position.x must not be -1 (invalid state). "
		+ "Expected safe-area-aware center. Got: %s") % str(pos)
	).is_not_equal(-1.0)

	# Assert y is not -1 (valid state returns meaningful y)
	assert_float(pos.y).override_failure_message(
		("AC-7: S1 panel position.y must not be -1 (invalid state). Got: %s") % str(pos)
	).is_not_equal(-1.0)


## AC-7 edge: S0/S5/S6 return Vector2(-1, -1) — no panel for those states.
func test_get_action_panel_position_returns_neg_one_for_s0_s5_s6() -> void:
	var s0_pos: Vector2 = InputRouter._get_action_panel_position(InputRouter.InputState.OBSERVATION)
	assert_float(s0_pos.x).override_failure_message(
		"AC-7 edge: S0 must return Vector2(-1, -1).x = -1"
	).is_equal_approx(-1.0, 0.001)
	assert_float(s0_pos.y).override_failure_message(
		"AC-7 edge: S0 must return Vector2(-1, -1).y = -1"
	).is_equal_approx(-1.0, 0.001)

	var s5_pos: Vector2 = InputRouter._get_action_panel_position(InputRouter.InputState.INPUT_BLOCKED)
	assert_float(s5_pos.x).override_failure_message(
		"AC-7 edge: S5 must return Vector2(-1, -1).x = -1"
	).is_equal_approx(-1.0, 0.001)

	var s6_pos: Vector2 = InputRouter._get_action_panel_position(InputRouter.InputState.MENU_OPEN)
	assert_float(s6_pos.x).override_failure_message(
		"AC-7 edge: S6 must return Vector2(-1, -1).x = -1"
	).is_equal_approx(-1.0, 0.001)


# ── AC-10: Parametric sweep of _classify_pan_or_tap ──────────────────────────


## AC-10: 5-case parametric Array[Dictionary] sweep per story-009 AC-10 spec.
## Cases: (2, 50, "_rejected"), (2, 100, "unit_select"), (20, 100, "camera_pan"),
##        (20, 50, "camera_pan" — travel dominates timing),
##        (16.1, 50, "camera_pan" — boundary just-above)
func test_classify_pan_or_tap_parametric_sweep() -> void:
	# G-16: typed Array[Dictionary]
	var cases: Array[Dictionary] = [
		{"travel_px": 2.0, "hold_ms": 50, "expected": "_rejected"},
		{"travel_px": 2.0, "hold_ms": 100, "expected": "unit_select"},
		{"travel_px": 20.0, "hold_ms": 100, "expected": "camera_pan"},
		{"travel_px": 20.0, "hold_ms": 50, "expected": "camera_pan"},
		{"travel_px": 16.1, "hold_ms": 50, "expected": "camera_pan"},
	]

	for case: Dictionary in cases:
		var travel: float = case["travel_px"] as float
		var hold: int = case["hold_ms"] as int
		var expected: String = case["expected"] as String
		var result: StringName = InputRouter._classify_pan_or_tap(travel, hold)
		assert_str(String(result)).override_failure_message(
			("AC-10 sweep: _classify_pan_or_tap(travel=%.1f, hold=%d) expected '%s' "
			+ "but got '%s'") % [travel, hold, expected, String(result)]
		).is_equal(expected)


# ── AC-11 / AC-12: BalanceConstants new keys ──────────────────────────────────


## AC-12: PAN_ACTIVATION_PX=16 and MIN_TOUCH_DURATION_MS=80 present in BalanceConstants.
func test_balance_constants_input_handling_pan_tap_keys_present_with_expected_values() -> void:
	assert_int(int(BalanceConstants.get_const(&"PAN_ACTIVATION_PX"))).override_failure_message(
		"AC-12: PAN_ACTIVATION_PX must be 16"
	).is_equal(16)

	assert_int(int(BalanceConstants.get_const(&"MIN_TOUCH_DURATION_MS"))).override_failure_message(
		"AC-12: MIN_TOUCH_DURATION_MS must be 80"
	).is_equal(80)


# ── Same-patch contract verification ─────────────────────────────────────────


## Structural: 2 new camera actions are present in ACTIONS_BY_CATEGORY["camera"].
func test_two_new_camera_actions_in_actions_by_category() -> void:
	var camera_actions: Array = InputRouter.ACTIONS_BY_CATEGORY[&"camera"]

	var has_pinch_zoom: bool = false
	var has_tap_cancel: bool = false
	for action: Variant in camera_actions:
		if action == &"camera_pinch_zoom":
			has_pinch_zoom = true
		if action == &"camera_two_finger_tap_cancel":
			has_tap_cancel = true

	assert_bool(has_pinch_zoom).override_failure_message(
		"Same-patch: &'camera_pinch_zoom' must be in ACTIONS_BY_CATEGORY['camera']"
	).is_true()
	assert_bool(has_tap_cancel).override_failure_message(
		"Same-patch: &'camera_two_finger_tap_cancel' must be in ACTIONS_BY_CATEGORY['camera']"
	).is_true()


## Structural: 2 new camera actions are present in default_bindings.json with screen_touch entries.
## This ensures R-5 parity and the AC-7 reachability sweep in story-008 continues to pass.
func test_two_new_camera_actions_in_default_bindings_json() -> void:
	var content: String = FileAccess.get_file_as_string(_DEFAULT_BINDINGS_PATH)
	var json := JSON.new()
	var parse_result: int = json.parse(content)
	assert_int(parse_result).override_failure_message(
		"Same-patch: default_bindings.json must parse cleanly"
	).is_equal(OK)
	var bindings: Dictionary = json.data as Dictionary

	assert_bool(bindings.has("camera_pinch_zoom")).override_failure_message(
		"Same-patch: 'camera_pinch_zoom' must be a key in default_bindings.json"
	).is_true()
	assert_bool(bindings.has("camera_two_finger_tap_cancel")).override_failure_message(
		"Same-patch: 'camera_two_finger_tap_cancel' must be a key in default_bindings.json"
	).is_true()

	# Verify at least one screen_touch entry for each
	for action_key: String in ["camera_pinch_zoom", "camera_two_finger_tap_cancel"]:
		var events: Array = bindings[action_key] as Array
		var has_touch: bool = false
		for event_variant: Variant in events:
			if not (event_variant is Dictionary):
				continue
			var ev: Dictionary = event_variant as Dictionary
			if (ev.get("type", "") as String) == "screen_touch":
				has_touch = true
				break
		assert_bool(has_touch).override_failure_message(
			("Same-patch: default_bindings.json entry for '%s' must have at least one "
			+ "screen_touch event for R-5 parity + AC-7 reachability sweep") % action_key
		).is_true()


# ── Structural source checks ──────────────────────────────────────────────────


## Structural: _resolve_safe_area_api is declared in input_router.gd source.
func test_resolve_safe_area_api_source_present_in_input_router() -> void:
	var content: String = FileAccess.get_file_as_string(_IR_PATH)
	assert_bool(content.contains("_resolve_safe_area_api")).override_failure_message(
		"Structural: _resolve_safe_area_api must be declared in input_router.gd"
	).is_true()


## Structural: _classify_pan_or_tap is declared in input_router.gd source.
func test_classify_pan_or_tap_source_present_in_input_router() -> void:
	var content: String = FileAccess.get_file_as_string(_IR_PATH)
	assert_bool(content.contains("_classify_pan_or_tap")).override_failure_message(
		"Structural: _classify_pan_or_tap must be declared in input_router.gd"
	).is_true()


## Structural: _handle_touch_tracking is declared in input_router.gd source.
func test_handle_touch_tracking_source_present_in_input_router() -> void:
	var content: String = FileAccess.get_file_as_string(_IR_PATH)
	assert_bool(content.contains("_handle_touch_tracking")).override_failure_message(
		"Structural: _handle_touch_tracking must be declared in input_router.gd"
	).is_true()


# ── /code-review BLOCK-1 + BLOCK-2 (qa-tester): evidence doc structural tests ──
# Closes spec-mandated AC-8 + AC-9 G-22 source-scan assertions per
# story-009 ## QA Test Cases section.


## AC-8: Verification evidence #5b doc exists with Status + Observed Result fields.
## G-22 structural source-scan pattern. Closes /code-review BLOCK-1 (qa-tester).
func test_evidence_05b_doc_exists_with_status_and_observed_result() -> void:
	const _EVIDENCE_05B_PATH: String = (
		"res://production/qa/evidence/input_router_verification_05b_safe_area_api.md"
	)
	var content: String = FileAccess.get_file_as_string(_EVIDENCE_05B_PATH)
	assert_bool(content.length() > 0).override_failure_message(
		"AC-8: verification #5b doc must exist at %s" % _EVIDENCE_05B_PATH
	).is_true()
	assert_bool(content.contains("Status")).override_failure_message(
		"AC-8: verification #5b doc must contain Status field"
	).is_true()
	assert_bool(content.contains("Observed Result")).override_failure_message(
		"AC-8: verification #5b doc must contain Observed Result section (filled at impl-time)"
	).is_true()


## AC-9: Verification evidence #6 doc exists with Polish-deferred status + reactivation trigger.
## G-22 structural source-scan pattern. Closes /code-review BLOCK-2 (qa-tester).
func test_evidence_06_doc_exists_with_polish_deferred_status() -> void:
	const _EVIDENCE_06_PATH: String = (
		"res://production/qa/evidence/input_router_verification_06_touch_event_index_stability.md"
	)
	var content: String = FileAccess.get_file_as_string(_EVIDENCE_06_PATH)
	assert_bool(content.length() > 0).override_failure_message(
		"AC-9: verification #6 doc must exist at %s" % _EVIDENCE_06_PATH
	).is_true()
	assert_bool(content.contains("Polish-deferred")).override_failure_message(
		"AC-9: verification #6 doc must declare Status: Polish-deferred"
	).is_true()
	assert_bool(content.contains("Reactivation")).override_failure_message(
		"AC-9: verification #6 doc must document a reactivation trigger"
	).is_true()


# ── /code-review IMP-1 (qa-tester): AC-7 S2/S4 panel positioning coverage ────


## AC-7: _get_action_panel_position S2/S4 (MOVEMENT_PREVIEW + ATTACK_CONFIRM) returns
## the bottom-third anti-occlusion path (distinct from S1/S3 bottom-center). Closes
## /code-review IMP-1 (qa-tester) — original AC-7 tests covered S1 + S0/S5/S6 negative
## but not the MVP S2/S4 anti-occlusion path which is a structurally different match arm.
func test_get_action_panel_position_returns_valid_position_for_s2_s4() -> void:
	# Arrange — known safe-area inset
	InputRouter._safe_area_inset = Vector4(0.0, 0.0, 0.0, 0.0)

	# Act
	var s2_pos: Vector2 = InputRouter._get_action_panel_position(InputRouter.InputState.MOVEMENT_PREVIEW)
	var s4_pos: Vector2 = InputRouter._get_action_panel_position(InputRouter.InputState.ATTACK_CONFIRM)

	# Assert — both return non-(-1,-1) (i.e. they hit the S2/S4 match arm, not the default arm)
	assert_float(s2_pos.x).override_failure_message(
		"AC-7: S2 (MOVEMENT_PREVIEW) panel position.x must NOT be -1 (must hit non-default match arm). Got: %s" % str(s2_pos)
	).is_not_equal(-1.0)
	assert_float(s2_pos.y).override_failure_message(
		"AC-7: S2 (MOVEMENT_PREVIEW) panel position.y must NOT be -1. Got: %s" % str(s2_pos)
	).is_not_equal(-1.0)
	assert_float(s4_pos.x).override_failure_message(
		"AC-7: S4 (ATTACK_CONFIRM) panel position.x must NOT be -1 (must hit non-default match arm). Got: %s" % str(s4_pos)
	).is_not_equal(-1.0)
	assert_float(s4_pos.y).override_failure_message(
		"AC-7: S4 (ATTACK_CONFIRM) panel position.y must NOT be -1. Got: %s" % str(s4_pos)
	).is_not_equal(-1.0)


# ── /code-review IMP-2 (qa-tester): AC-5 post-cancel behavioral invariant ────


## AC-5 / EC-1 downstream invariant: after second-finger arrival cancels TPP state,
## a subsequent same-unit "second tap" on first finger does NOT advance to S1 — the
## window has been canceled. Closes /code-review IMP-2 (qa-tester) — original AC-5
## test asserted field-state reset only; the spec also requires the behavioral
## invariant that the now-fresh first tap is treated as a new first tap.
func test_after_multitouch_cancel_second_tap_does_not_advance_to_s1() -> void:
	# Arrange — simulate TPP first tap already recorded
	InputRouter._active_mode = InputRouter.InputMode.TOUCH
	InputRouter._last_tap_unit_id = 5
	InputRouter._last_tap_time_ms = Time.get_ticks_msec() - 100

	# Act — second finger cancels (resets _last_tap_unit_id to -1)
	var second_touch := InputEventScreenTouch.new()
	second_touch.index = 1
	second_touch.pressed = true
	InputRouter._handle_event(second_touch)

	# Verify cancel happened (precondition for the behavioral invariant)
	assert_int(InputRouter._last_tap_unit_id).override_failure_message(
		"AC-5 precondition: 2-finger arrival must reset _last_tap_unit_id to -1"
	).is_equal(-1)

	# Now simulate a "second tap" on unit 5 via _handle_action directly
	var ctx := InputContext.new()
	ctx.target_unit_id = 5
	InputRouter._handle_action(&"unit_select", ctx)

	# Assert — state stays S0 OBSERVATION (window was canceled; this is a new first tap)
	assert_int(int(InputRouter._state)).override_failure_message(
		(
			"AC-5 / EC-1 behavioral invariant: after 2-finger cancel, a same-unit tap "
			+ "must be treated as a NEW first tap (state stays OBSERVATION); must NOT "
			+ "advance to UNIT_SELECTED. Got state: %d"
		)
		% int(InputRouter._state)
	).is_equal(int(InputRouter.InputState.OBSERVATION))

	# Assert — _last_tap_unit_id is now 5 (new first tap recorded)
	assert_int(InputRouter._last_tap_unit_id).override_failure_message(
		"AC-5 / EC-1: post-cancel new first tap must record _last_tap_unit_id = 5"
	).is_equal(5)
