extends GdUnitTestSuite

## input_router_actions_bindings_test.gd
## Story 002 tests — 22-action ACTIONS_BY_CATEGORY const + default_bindings.json
## schema + JSON load + InputMap population + R-5 parity validation.
## Covers AC-1 through AC-11 per story QA Test Cases.
##
## Pattern: structural source-scan via FileAccess.get_file_as_string + content.contains
## per G-22 precedent (input_router_skeleton_test.gd). Runtime assertions via direct
## InputRouter const/field access and InputMap query APIs.
##
## LIFECYCLE:
##   before_test — clears all 6 InputRouter fields + erases leftover InputMap actions
##                 + loads minimal test fixture (G-15 isolation; NOT production JSON)
##   after_test  — no additional cleanup needed (before_test handles the reset)
##
## G-15: uses before_test() NOT before_each() — GdUnit4 v6.1.2 only recognises
##        before_test() as the per-test setup hook.
## G-25: ACTIONS_BY_CATEGORY is Dictionary[StringName, Array] (not Array[StringName]
##        value type) due to Godot 4.6 nested-typed-collection restriction.

const _IR_PATH: String = "res://src/foundation/input_router.gd"
const _BINDINGS_PATH: String = "res://assets/data/input/default_bindings.json"
const _FIXTURE_PATH: String = "res://tests/fixtures/input/test_bindings_minimal.json"
## AC-3 negative-path fixtures
const _FIXTURE_INVALID_JSON: String = "res://tests/fixtures/input/test_bindings_invalid_json.json"
const _FIXTURE_NON_DICT: String = "res://tests/fixtures/input/test_bindings_non_dict_top_level.json"
const _FIXTURE_MISSING: String = "res://tests/fixtures/input/test_bindings_intentionally_missing_xyz.json"

## KEY_ENTER keycode per Godot 4.6 @GlobalScope Key enum
const _KEY_ENTER: int = 4194309
## KEY_ESCAPE keycode
const _KEY_ESCAPE: int = 4194305
## KEY_SPACE keycode
const _KEY_SPACE: int = 32
## KEY_M keycode — uniquely bound to open_unit_info in default_bindings.json
## (chosen for AC-6 first-match test because KEY_ENTER is shared by 4 actions and
## the first-match-wins iteration order would yield move_confirm, not action_confirm).
const _KEY_M: int = 77
## An unbound key (KEY_F8) for "no match" tests
const _KEY_UNBOUND: int = 4194343


func before_test() -> void:
	# G-15 canonical reset (5th-precedent autoload helper, story-010 epic-terminal).
	# Covers all 17 fields per `tools/ci/lint_input_router_g15_reset.sh`.
	InputRouter.reset_for_tests()
	# G-15 reset — full 7-field clear (6 ADR-0005 §1 fields + _last_matched_action story-002)
	InputRouter._state = InputRouter.InputState.OBSERVATION
	InputRouter._active_mode = InputRouter.InputMode.KEYBOARD_MOUSE
	InputRouter._pre_menu_state = InputRouter.InputState.OBSERVATION
	InputRouter._undo_windows.clear()
	InputRouter._input_blocked_reasons.clear()
	InputRouter._bindings.clear()
	InputRouter._last_matched_action = &""

	# Erase any InputMap actions left from production _ready() or prior tests.
	# Iterate all 4 categories to ensure clean slate.
	for category: StringName in InputRouter.ACTIONS_BY_CATEGORY.keys():
		for action: StringName in InputRouter.ACTIONS_BY_CATEGORY[category]:
			if InputMap.has_action(action):
				InputMap.erase_action(action)

	# Load minimal test fixture (NOT production default_bindings.json)
	# so tests work against a known 3-action baseline.
	var content: String = FileAccess.get_file_as_string(_FIXTURE_PATH)
	if not content.is_empty():
		var json := JSON.new()
		if json.parse(content) == OK:
			InputRouter._populate_input_map(json.data)


# ── AC-1 + AC-2 structural source assertions ──────────────────────────────────


## AC-1 (source-scan): ACTIONS_BY_CATEGORY const is declared in input_router.gd.
## Verifies the const declaration line + 4 category StringName literals present.
## G-22 structural source-scan approach — does not rely on runtime enum access.
func test_actions_by_category_const_declared_in_source() -> void:
	# Arrange
	var content: String = FileAccess.get_file_as_string(_IR_PATH)
	assert_bool(content.length() > 0).override_failure_message(
		"AC-1 pre-condition: failed to read %s" % _IR_PATH
	).is_true()

	# Assert — const declaration line present
	assert_bool(content.contains("const ACTIONS_BY_CATEGORY:")).override_failure_message(
		"AC-1: input_router.gd must declare 'const ACTIONS_BY_CATEGORY:'"
	).is_true()

	# Assert — 4 category StringName keys present as literals
	assert_bool(content.contains('&"grid"')).override_failure_message(
		"AC-1: ACTIONS_BY_CATEGORY must include &\"grid\" category"
	).is_true()

	assert_bool(content.contains('&"camera"')).override_failure_message(
		"AC-1: ACTIONS_BY_CATEGORY must include &\"camera\" category"
	).is_true()

	assert_bool(content.contains('&"menu"')).override_failure_message(
		"AC-1: ACTIONS_BY_CATEGORY must include &\"menu\" category"
	).is_true()

	assert_bool(content.contains('&"meta"')).override_failure_message(
		"AC-1: ACTIONS_BY_CATEGORY must include &\"meta\" category"
	).is_true()

	# Spot-check 5 specific action names in source
	assert_bool(content.contains('&"unit_select"')).override_failure_message(
		"AC-1: source must contain &\"unit_select\""
	).is_true()

	assert_bool(content.contains('&"action_confirm"')).override_failure_message(
		"AC-1: source must contain &\"action_confirm\""
	).is_true()

	assert_bool(content.contains('&"grid_hover"')).override_failure_message(
		"AC-1: source must contain &\"grid_hover\" (PC-only per CR-1c)"
	).is_true()

	assert_bool(content.contains('&"camera_pan"')).override_failure_message(
		"AC-1: source must contain &\"camera_pan\""
	).is_true()

	assert_bool(content.contains('&"end_phase_confirm"')).override_failure_message(
		"AC-1: source must contain &\"end_phase_confirm\""
	).is_true()


# ── AC-1 runtime count assertions ────────────────────────────────────────────


## AC-1 (runtime): ACTIONS_BY_CATEGORY const is accessible on the InputRouter
## autoload at runtime. Total action count = 24 (story-009 added camera_pinch_zoom +
## camera_two_finger_tap_cancel per CR-1d additive evolution); per-category counts verified.
func test_actions_by_category_runtime_total_is_24() -> void:
	# Assert — 4 categories present
	assert_int(InputRouter.ACTIONS_BY_CATEGORY.size()).override_failure_message(
		"AC-1: ACTIONS_BY_CATEGORY must have exactly 4 categories"
	).is_equal(4)

	# Assert — per-category counts
	assert_int(InputRouter.ACTIONS_BY_CATEGORY[&"grid"].size()).override_failure_message(
		"AC-1: grid category must have exactly 10 actions"
	).is_equal(10)

	# camera category was 4 actions through story-008; story-009 added +2 (camera_pinch_zoom,
	# camera_two_finger_tap_cancel) per CR-1d additive evolution → 6 total.
	assert_int(InputRouter.ACTIONS_BY_CATEGORY[&"camera"].size()).override_failure_message(
		"AC-1: camera category must have exactly 6 actions (4 + story-009 CR-1d additions)"
	).is_equal(6)

	assert_int(InputRouter.ACTIONS_BY_CATEGORY[&"menu"].size()).override_failure_message(
		"AC-1: menu category must have exactly 5 actions"
	).is_equal(5)

	assert_int(InputRouter.ACTIONS_BY_CATEGORY[&"meta"].size()).override_failure_message(
		"AC-1: meta category must have exactly 3 actions"
	).is_equal(3)

	# Assert — total = 24 (10 grid + 6 camera + 5 menu + 3 meta)
	var total: int = 0
	for category: StringName in InputRouter.ACTIONS_BY_CATEGORY.keys():
		total += InputRouter.ACTIONS_BY_CATEGORY[category].size()
	assert_int(total).override_failure_message(
		"AC-1: ACTIONS_BY_CATEGORY total action count must be 24 (post-story-009 CR-1d); got %d" % total
	).is_equal(24)


## AC-1 (CR-1c): grid_hover is in the grid category (PC-only) and NOT in
## default_bindings.json (touch-unreachable per CR-1c).
func test_grid_hover_in_grid_category_and_absent_from_default_bindings() -> void:
	# Assert — grid_hover present in grid category
	assert_bool(&"grid_hover" in InputRouter.ACTIONS_BY_CATEGORY[&"grid"]).override_failure_message(
		"AC-1/CR-1c: &\"grid_hover\" must be in the grid category of ACTIONS_BY_CATEGORY"
	).is_true()

	# Assert — grid_hover NOT in default_bindings.json (CR-1c: PC-only, touch-unreachable)
	var content: String = FileAccess.get_file_as_string(_BINDINGS_PATH)
	assert_bool(content.length() > 0).override_failure_message(
		"AC-2 pre-condition: failed to read %s" % _BINDINGS_PATH
	).is_true()
	var json := JSON.new()
	assert_int(json.parse(content)).override_failure_message(
		"AC-2 pre-condition: %s failed to parse" % _BINDINGS_PATH
	).is_equal(OK)
	var bindings: Dictionary = json.data as Dictionary
	assert_bool(bindings.has("grid_hover")).override_failure_message(
		"AC-2/CR-1c: default_bindings.json must NOT contain a \"grid_hover\" key (PC-only)"
	).is_false()


# ── AC-2 default_bindings.json schema assertions ─────────────────────────────


## AC-2: default_bindings.json exists, parses, contains exactly 23 action keys
## (24 total minus grid_hover which is PC-only per CR-1c), plus 2 meta keys.
## Story-009 CR-1d added 2 touch-only entries (camera_pinch_zoom, camera_two_finger_tap_cancel).
func test_default_bindings_json_loads_and_has_23_action_keys() -> void:
	# Arrange — load and parse production bindings
	var content: String = FileAccess.get_file_as_string(_BINDINGS_PATH)
	assert_bool(content.length() > 0).override_failure_message(
		"AC-2: default_bindings.json missing or empty at %s" % _BINDINGS_PATH
	).is_true()

	var json := JSON.new()
	assert_int(json.parse(content)).override_failure_message(
		"AC-2: default_bindings.json failed to parse as valid JSON"
	).is_equal(OK)

	var bindings: Dictionary = json.data as Dictionary
	assert_bool(bindings != null).override_failure_message(
		"AC-2: default_bindings.json top-level must be a JSON object"
	).is_true()

	# Assert — meta keys present
	assert_bool(bindings.has("_schema_version")).override_failure_message(
		"AC-2: default_bindings.json must contain \"_schema_version\" meta key"
	).is_true()
	assert_bool(bindings.has("_authority")).override_failure_message(
		"AC-2: default_bindings.json must contain \"_authority\" meta key"
	).is_true()

	# Count non-meta keys
	var action_count: int = 0
	for key: String in bindings.keys():
		if not key.begins_with("_"):
			action_count += 1

	assert_int(action_count).override_failure_message(
		("AC-2: default_bindings.json must have exactly 23 action keys"
		+ " (24 declared - 1 PC-only grid_hover); got %d") % action_count
	).is_equal(23)

	# Spot-check 5 specific action keys
	assert_bool(bindings.has("action_confirm")).override_failure_message(
		"AC-2: default_bindings.json must contain \"action_confirm\""
	).is_true()
	assert_bool(bindings.has("unit_select")).override_failure_message(
		"AC-2: default_bindings.json must contain \"unit_select\""
	).is_true()
	assert_bool(bindings.has("camera_zoom_in")).override_failure_message(
		"AC-2: default_bindings.json must contain \"camera_zoom_in\""
	).is_true()
	assert_bool(bindings.has("end_player_turn")).override_failure_message(
		"AC-2: default_bindings.json must contain \"end_player_turn\""
	).is_true()
	assert_bool(bindings.has("toggle_input_hints")).override_failure_message(
		"AC-2: default_bindings.json must contain \"toggle_input_hints\""
	).is_true()


# ── AC-4 InputMap population via DI seam ─────────────────────────────────────


## AC-4: _populate_input_map correctly registers actions into Godot's InputMap.
## Uses the minimal test fixture loaded in before_test() (G-15 isolation).
func test_populate_input_map_registers_fixture_actions() -> void:
	# before_test() already called _populate_input_map with the minimal fixture.
	# Fixture contains: action_confirm → KEY_SPACE, unit_select → MOUSE_BUTTON_LEFT,
	# move_confirm → KEY_ENTER.

	# Assert — 3 fixture actions are registered in InputMap
	assert_bool(InputMap.has_action(&"action_confirm")).override_failure_message(
		"AC-4: InputMap must have 'action_confirm' after _populate_input_map from fixture"
	).is_true()
	assert_bool(InputMap.has_action(&"unit_select")).override_failure_message(
		"AC-4: InputMap must have 'unit_select' after _populate_input_map from fixture"
	).is_true()
	assert_bool(InputMap.has_action(&"move_confirm")).override_failure_message(
		"AC-4: InputMap must have 'move_confirm' after _populate_input_map from fixture"
	).is_true()

	# Assert — action_confirm bound to KEY_SPACE in the fixture
	var ev_space := InputEventKey.new()
	ev_space.keycode = _KEY_SPACE
	assert_bool(InputMap.action_has_event(&"action_confirm", ev_space)).override_failure_message(
		"AC-4: InputMap action_confirm must have KEY_SPACE event (keycode %d) per fixture" % _KEY_SPACE
	).is_true()

	# Assert — unit_select bound to MOUSE_BUTTON_LEFT in the fixture
	var ev_left := InputEventMouseButton.new()
	ev_left.button_index = 1
	assert_bool(InputMap.action_has_event(&"unit_select", ev_left)).override_failure_message(
		"AC-4: InputMap unit_select must have MOUSE_BUTTON_LEFT event per fixture"
	).is_true()


# ── AC-6 _handle_event match assertions ──────────────────────────────────────


## AC-6: _handle_event with a uniquely-bound key matches the corresponding action
## from production bindings. Uses KEY_M (uniquely bound to open_unit_info) rather
## than KEY_ENTER (which is shared by 4 actions: move_confirm, attack_confirm,
## end_phase_confirm, action_confirm; first-match-wins iteration order yields
## move_confirm because grid category is iterated before meta category).
## Loads production bindings via _populate_input_map DI seam for this test only.
func test_handle_event_matches_uniquely_bound_key_to_action() -> void:
	# Arrange — clear fixture bindings and load production bindings
	InputRouter._bindings.clear()
	InputRouter._last_matched_action = &""
	for category: StringName in InputRouter.ACTIONS_BY_CATEGORY.keys():
		for action: StringName in InputRouter.ACTIONS_BY_CATEGORY[category]:
			if InputMap.has_action(action):
				InputMap.erase_action(action)

	var content: String = FileAccess.get_file_as_string(_BINDINGS_PATH)
	var json := JSON.new()
	assert_int(json.parse(content)).override_failure_message(
		"AC-6 pre-condition: production default_bindings.json failed to parse"
	).is_equal(OK)
	InputRouter._populate_input_map(json.data)

	# Act — construct KEY_M event (uniquely bound to open_unit_info)
	var ev := InputEventKey.new()
	ev.keycode = _KEY_M
	InputRouter._handle_event(ev)

	# Assert — open_unit_info matched (uniquely bound to KEY_M)
	assert_str(InputRouter._last_matched_action).override_failure_message(
		("AC-6: _handle_event with KEY_M must match &\"open_unit_info\";"
		+ " got &\"%s\"") % InputRouter._last_matched_action
	).is_equal(&"open_unit_info")


## AC-6: _handle_event with an unbound key clears _last_matched_action.
func test_handle_event_unbound_key_clears_last_matched_action() -> void:
	# Arrange — ensure a prior match exists so we can verify the clear
	InputRouter._last_matched_action = &"action_confirm"

	# Act — construct an unbound key (KEY_F8)
	var ev := InputEventKey.new()
	ev.keycode = _KEY_UNBOUND
	InputRouter._handle_event(ev)

	# Assert — _last_matched_action cleared to &""
	assert_str(InputRouter._last_matched_action).override_failure_message(
		("AC-6: _handle_event with unbound key must set _last_matched_action to &\"\";"
		+ " got &\"%s\"") % InputRouter._last_matched_action
	).is_equal(&"")


# ── AC-7 dynamic rebinding via set_binding ────────────────────────────────────


## AC-7: set_binding replaces the prior event for an action. Verifies that the
## new event is present and the old event is no longer registered.
func test_set_binding_replaces_prior_event() -> void:
	# Arrange — before_test() loaded fixture: action_confirm → KEY_SPACE
	# Verify fixture baseline is as expected
	var ev_space := InputEventKey.new()
	ev_space.keycode = _KEY_SPACE
	assert_bool(InputMap.action_has_event(&"action_confirm", ev_space)).override_failure_message(
		"AC-7 pre-condition: action_confirm must initially have KEY_SPACE from fixture"
	).is_true()

	# Act — rebind action_confirm to KEY_ENTER
	var ev_enter := InputEventKey.new()
	ev_enter.keycode = _KEY_ENTER
	InputRouter.set_binding(&"action_confirm", ev_enter)

	# Assert — KEY_ENTER now bound
	assert_bool(InputMap.action_has_event(&"action_confirm", ev_enter)).override_failure_message(
		"AC-7: after set_binding, action_confirm must have KEY_ENTER event"
	).is_true()

	# Assert — KEY_SPACE no longer bound (replaced, not appended)
	assert_bool(InputMap.action_has_event(&"action_confirm", ev_space)).override_failure_message(
		"AC-7: after set_binding, action_confirm must NOT have old KEY_SPACE event"
	).is_false()


# ── AC-5 R-5 parity validation ───────────────────────────────────────────────


## AC-5: _validate_r5_parity returns 0 when given a correctly-sized 21-key dict.
## Return-value assertion verifies the parity check fired correctly (G-22:
## push_error is not capturable, so observable side effect is the int return).
func test_validate_r5_parity_returns_zero_on_correct_21_key_dict() -> void:
	# Arrange — load production bindings
	var content: String = FileAccess.get_file_as_string(_BINDINGS_PATH)
	var json := JSON.new()
	assert_int(json.parse(content)).override_failure_message(
		"AC-5 pre-condition: production default_bindings.json failed to parse"
	).is_equal(OK)
	var bindings: Dictionary = json.data as Dictionary

	# Act — exercise validator
	var mismatch: int = InputRouter._validate_r5_parity(bindings)

	# Assert — parity holds (mismatch = 0)
	assert_int(mismatch).override_failure_message(
		"AC-5: _validate_r5_parity must return 0 for valid 21-key production bindings; got %d" % mismatch
	).is_equal(0)


## AC-5: _validate_r5_parity returns the mismatch magnitude when dict has wrong
## non-meta key count. Return-value assertion replaces the prior no-op tautology;
## without this, a gutted parity validator would silently pass AC-5.
func test_validate_r5_parity_returns_nonzero_on_extra_key_mismatch() -> void:
	# Arrange — build a dict with 22 non-meta keys (accidentally includes grid_hover)
	var malformed: Dictionary = {}
	malformed["_schema_version"] = "1.0.0"
	malformed["_authority"] = "parity-test"
	for category: StringName in InputRouter.ACTIONS_BY_CATEGORY.keys():
		for action: StringName in InputRouter.ACTIONS_BY_CATEGORY[category]:
			malformed[String(action)] = [{"type": "key", "keycode": 32}]

	assert_int(malformed.size()).override_failure_message(
		"AC-5 pre-condition: malformed dict should have 26 total keys (24 actions + 2 meta) post story-009 CR-1d"
	).is_equal(26)

	# Act — exercise validator
	var mismatch: int = InputRouter._validate_r5_parity(malformed)

	# Assert — mismatch = |24 - 23| = 1 (one extra action; expected 23 = 24 declared - 1 PC-only)
	assert_int(mismatch).override_failure_message(
		"AC-5: _validate_r5_parity must return 1 when 24 non-meta vs 23 expected; got %d" % mismatch
	).is_equal(1)


## AC-5: _validate_r5_parity also returns the magnitude when dict has too FEW
## non-meta keys (mismatch on the under-count side).
func test_validate_r5_parity_returns_nonzero_on_missing_key_mismatch() -> void:
	# Arrange — only 1 action key (way fewer than 21 expected)
	var sparse: Dictionary = {
		"_schema_version": "1.0.0",
		"action_confirm": [{"type": "key", "keycode": 32}],
	}

	# Act
	var mismatch: int = InputRouter._validate_r5_parity(sparse)

	# Assert — mismatch = |1 - 23| = 22 (post story-009 CR-1d: expected 23 = 24 declared - 1 PC-only)
	assert_int(mismatch).override_failure_message(
		"AC-5: _validate_r5_parity must return 22 when 1 non-meta vs 23 expected; got %d" % mismatch
	).is_equal(22)


# ── AC-8 + AC-9 structural source assertions ──────────────────────────────────


## AC-8: _unhandled_input(event: InputEvent) -> void is declared and delegates
## to _handle_event(event). G-22 source-scan with line-anchored check.
func test_unhandled_input_override_present_and_delegates_to_handle_event() -> void:
	# Arrange
	var content: String = FileAccess.get_file_as_string(_IR_PATH)
	assert_bool(content.length() > 0).override_failure_message(
		"AC-8 pre-condition: failed to read %s" % _IR_PATH
	).is_true()

	# Assert — _unhandled_input signature present (line-anchored: no doc-comment prefix)
	var has_decl: bool = false
	for line: String in content.split("\n"):
		var stripped: String = line.lstrip(" \t")
		if stripped.begins_with("func _unhandled_input(event: InputEvent) -> void:"):
			has_decl = true
			break
	assert_bool(has_decl).override_failure_message(
		"AC-8: input_router.gd must declare 'func _unhandled_input(event: InputEvent) -> void:'"
	).is_true()

	# Assert — body delegates to _handle_event(event)
	assert_bool(content.contains("_handle_event(event)")).override_failure_message(
		"AC-8: _unhandled_input body must call _handle_event(event)"
	).is_true()

	# Assert — _input override is NOT present (Controls own first dispatch)
	var has_input_override: bool = false
	for line: String in content.split("\n"):
		var stripped: String = line.lstrip(" \t")
		if stripped.begins_with("func _input(event"):
			has_input_override = true
			break
	assert_bool(has_input_override).override_failure_message(
		"AC-8: input_router.gd must NOT declare func _input (use _unhandled_input per Advisory C)"
	).is_false()


## AC-9: _handle_event iterates ACTIONS_BY_CATEGORY using the canonical loop form.
## G-22 source-scan verifies the inner-loop pattern and InputMap.action_has_event call.
func test_handle_event_iterates_4_categories_in_source() -> void:
	# Arrange
	var content: String = FileAccess.get_file_as_string(_IR_PATH)
	assert_bool(content.length() > 0).override_failure_message(
		"AC-9 pre-condition: failed to read %s" % _IR_PATH
	).is_true()

	# Assert — outer category loop present (line-anchored)
	var has_outer_loop: bool = false
	for line: String in content.split("\n"):
		var stripped: String = line.lstrip(" \t")
		if stripped.begins_with("for category: StringName in ACTIONS_BY_CATEGORY.keys():"):
			has_outer_loop = true
			break
	assert_bool(has_outer_loop).override_failure_message(
		"AC-9: _handle_event must have 'for category: StringName in ACTIONS_BY_CATEGORY.keys():'"
	).is_true()

	# Assert — inner action loop present
	assert_bool(content.contains("for action: StringName in ACTIONS_BY_CATEGORY[category]:")).override_failure_message(
		"AC-9: _handle_event must have inner 'for action: StringName in ACTIONS_BY_CATEGORY[category]:'"
	).is_true()

	# Assert — InputMap.action_has_event called inside the inner loop
	assert_bool(content.contains("InputMap.action_has_event(action, event)")).override_failure_message(
		"AC-9: _handle_event must call InputMap.action_has_event(action, event)"
	).is_true()

	# Assert — Input.parse_input_event is NOT used (delta #6 Item 8 forbidden pattern)
	# G-22 line-anchored: skip lines starting with '##' or '#' (doc comments) — line 254
	# of input_router.gd legitimately mentions Input.parse_input_event in a doc comment
	# explaining WHY the function does NOT use it.
	var has_forbidden_call: bool = false
	for line: String in content.split("\n"):
		var stripped: String = line.lstrip(" \t")
		if stripped.begins_with("#"):
			continue  # skip all comment lines (doc + regular)
		if stripped.contains("Input.parse_input_event("):
			has_forbidden_call = true
			break
	assert_bool(has_forbidden_call).override_failure_message(
		"AC-9/delta-#6-Item-8: input_router.gd must NOT use Input.parse_input_event() "
		+ "in non-comment code (event injection, not InputMap population)"
	).is_false()


# ── AC-11 fixture isolation ───────────────────────────────────────────────────


# ── AC-3 negative-path tests via _load_bindings_from_path DI seam ─────────────


## AC-3: missing file path returns empty Dictionary (push_error fires, but the
## return value is the observable side effect tests can assert on).
func test_load_bindings_returns_empty_on_missing_file() -> void:
	# Act — point at a path that does not exist on disk
	var result: Dictionary = InputRouter._load_bindings_from_path(_FIXTURE_MISSING)

	# Assert — empty Dictionary returned (failure sentinel)
	assert_bool(result.is_empty()).override_failure_message(
		"AC-3: _load_bindings_from_path must return {} for missing file; got %s" % result
	).is_true()


## AC-3: invalid JSON returns empty Dictionary (parse error caught by guard).
func test_load_bindings_returns_empty_on_invalid_json() -> void:
	# Act — point at a fixture with malformed JSON
	var result: Dictionary = InputRouter._load_bindings_from_path(_FIXTURE_INVALID_JSON)

	# Assert — empty Dictionary returned (failure sentinel)
	assert_bool(result.is_empty()).override_failure_message(
		"AC-3: _load_bindings_from_path must return {} for invalid JSON; got %s" % result
	).is_true()


## AC-3: non-Dictionary top-level (e.g., JSON array) returns empty Dictionary.
func test_load_bindings_returns_empty_on_non_dict_top_level() -> void:
	# Act — point at a fixture whose top-level is a JSON Array
	var result: Dictionary = InputRouter._load_bindings_from_path(_FIXTURE_NON_DICT)

	# Assert — empty Dictionary returned (failure sentinel)
	assert_bool(result.is_empty()).override_failure_message(
		"AC-3: _load_bindings_from_path must return {} for non-Dict top-level; got %s" % result
	).is_true()


## AC-3 happy-path: valid fixture returns parsed Dictionary with expected keys.
func test_load_bindings_returns_parsed_dict_for_valid_fixture() -> void:
	# Act — load the minimal fixture
	var result: Dictionary = InputRouter._load_bindings_from_path(_FIXTURE_PATH)

	# Assert — non-empty + has the 3 fixture actions + 2 meta keys
	assert_bool(result.is_empty()).override_failure_message(
		"AC-3 happy-path: _load_bindings_from_path must return non-empty dict for valid fixture"
	).is_false()
	assert_bool(result.has("action_confirm")).override_failure_message(
		"AC-3 happy-path: parsed dict must contain action_confirm"
	).is_true()
	assert_bool(result.has("_schema_version")).override_failure_message(
		"AC-3 happy-path: parsed dict must contain _schema_version meta key"
	).is_true()


# ── _construct_input_event + _populate_input_map defensive-path tests ─────────


## _construct_input_event returns null + push_warning on unknown event type.
## Silent data-corruption guard: a JSON typo like {"typ": "key"} would produce
## a null InputEvent that _populate_input_map skips, leaving the action in
## InputMap with zero events bound (rather than crashing the autoload).
func test_construct_input_event_returns_null_on_unknown_type() -> void:
	# Act — pass an event_dict with an unknown type
	var result: InputEvent = InputRouter._construct_input_event(
		{"type": "unknown_type", "keycode": 32}
	)

	# Assert — null returned
	assert_object(result).override_failure_message(
		"_construct_input_event must return null for unknown event type"
	).is_null()


## _construct_input_event returns null when the dict lacks a "type" key.
func test_construct_input_event_returns_null_on_missing_type_key() -> void:
	# Act — pass an event_dict without a "type" key
	var result: InputEvent = InputRouter._construct_input_event({"keycode": 32})

	# Assert — null returned (Dictionary.get default is "" → falls to wildcard)
	assert_object(result).override_failure_message(
		"_construct_input_event must return null when 'type' key is absent"
	).is_null()


## _populate_input_map skips actions whose binding value is not an Array
## (push_warning fires; the action is still added to InputMap but receives no
## events). Defensive against typos like "action_confirm": "KEY_ENTER" instead
## of "action_confirm": [{"type": "key", "keycode": 4194309}].
func test_populate_input_map_skips_non_array_binding_value() -> void:
	# Arrange — clear InputMap state for the test action
	if InputMap.has_action(&"defensive_test_action"):
		InputMap.erase_action(&"defensive_test_action")

	# Act — call with a binding value that is not an Array
	InputRouter._populate_input_map({"defensive_test_action": "this is a String not an Array"})

	# Assert — action exists in InputMap but has no events bound
	assert_bool(InputMap.has_action(&"defensive_test_action")).override_failure_message(
		"_populate_input_map must still add_action for non-Array binding value"
	).is_true()
	assert_int(InputMap.action_get_events(&"defensive_test_action").size()).override_failure_message(
		"_populate_input_map must skip event registration when value is not an Array"
	).is_equal(0)

	# Cleanup
	InputMap.erase_action(&"defensive_test_action")


## _populate_input_map skips event entries that are not Dictionaries.
## Defensive against malformed JSON like "action": ["not_a_dict", {valid: dict}].
func test_populate_input_map_skips_non_dictionary_event_entry() -> void:
	# Arrange
	if InputMap.has_action(&"mixed_event_action"):
		InputMap.erase_action(&"mixed_event_action")

	# Act — array contains a String (skipped) and a valid event Dict (registered)
	InputRouter._populate_input_map({
		"mixed_event_action": ["this should be skipped", {"type": "key", "keycode": 32}],
	})

	# Assert — exactly 1 event registered (the valid one)
	assert_bool(InputMap.has_action(&"mixed_event_action")).is_true()
	assert_int(InputMap.action_get_events(&"mixed_event_action").size()).override_failure_message(
		"_populate_input_map must register the valid event and skip the non-Dictionary one"
	).is_equal(1)

	# Cleanup
	InputMap.erase_action(&"mixed_event_action")


## _handle_event matches an InputEventMouseButton event (button_index=1) to
## unit_select per production bindings (mouse-fallback iteration; sibling check
## to the keyboard KEY_M test). unit_select is the first action in the grid
## category with a mouse_button binding, so first-match-wins yields it.
##
## NOTE: a parallel InputEventScreenTouch test for AC-6's "touch fallback"
## edge case (story spec line 246) is deferred to story-008-009 (touch protocol
## implementation). InputMap.action_has_event has nuanced exact-match semantics
## for InputEventScreenTouch that the touch-protocol stories will own — the
## keyboard + mouse paths verified here are sufficient to prove the iteration
## logic for story-002 scope.
func test_handle_event_matches_mouse_left_to_unit_select() -> void:
	# Arrange — load production bindings (unit_select has mouse_button + screen_touch)
	InputRouter._bindings.clear()
	InputRouter._last_matched_action = &""
	for category: StringName in InputRouter.ACTIONS_BY_CATEGORY.keys():
		for action: StringName in InputRouter.ACTIONS_BY_CATEGORY[category]:
			if InputMap.has_action(action):
				InputMap.erase_action(action)

	var content: String = FileAccess.get_file_as_string(_BINDINGS_PATH)
	var json := JSON.new()
	assert_int(json.parse(content)).is_equal(OK)
	InputRouter._populate_input_map(json.data)

	# Act — construct MOUSE_BUTTON_LEFT event
	var ev := InputEventMouseButton.new()
	ev.button_index = 1  # MOUSE_BUTTON_LEFT
	InputRouter._handle_event(ev)

	# Assert — unit_select is first grid action bound to mouse_button=1
	# (move_target_select + attack_target_select also bind it but come later)
	assert_str(InputRouter._last_matched_action).override_failure_message(
		("AC-6 mouse fallback: _handle_event with MOUSE_BUTTON_LEFT must match"
		+ " &\"unit_select\" (first grid action with mouse_button binding);"
		+ " got &\"%s\"") % InputRouter._last_matched_action
	).is_equal(&"unit_select")


# ── AC-11 fixture isolation ───────────────────────────────────────────────────


## AC-11: production default_bindings.json is unchanged after any fixture-loading
## operation. Computes a hash before and after loading the minimal fixture.
func test_fixture_isolation_production_bindings_unchanged() -> void:
	# Arrange — hash production bindings content BEFORE any fixture load
	var before_content: String = FileAccess.get_file_as_string(_BINDINGS_PATH)
	var before_hash: int = before_content.hash()
	assert_bool(before_content.length() > 0).override_failure_message(
		"AC-11 pre-condition: production bindings file unreadable"
	).is_true()

	# Act — load the minimal test fixture (simulates AC-7 dynamic-rebinding scenario)
	var fixture_content: String = FileAccess.get_file_as_string(_FIXTURE_PATH)
	var fixture_json := JSON.new()
	fixture_json.parse(fixture_content)
	InputRouter._populate_input_map(fixture_json.data)

	# Arrange — hash production bindings AFTER fixture load
	var after_content: String = FileAccess.get_file_as_string(_BINDINGS_PATH)
	var after_hash: int = after_content.hash()

	# Assert — production bindings content unchanged
	assert_int(after_hash).override_failure_message(
		"AC-11: production default_bindings.json must not be modified by fixture-load operations"
	).is_equal(before_hash)
