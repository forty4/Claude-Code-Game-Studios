## BattleHUD UI-GB-02 Action Menu + UI-GB-05 Skill List + UI-GB-10 Undo + Two-Tap test.
##
## Story-005 — covers AC-1..AC-7 + AC-9 (automated state-transition tests).
## AC-8 (44pt manual pre-flight) is documented in
## `production/qa/evidence/battle-hud-story-005-evidence.md`; story-008 lint will
## automate the 44pt size check at CI.
##
## Tests use:
##   - `before_test()` for HeroDatabase static-state reset (per file header obligation)
##   - InputRouterSpy inner class — overrides _handle_event to record dispatched events
##   - GridBattleControllerStub + TurnOrderRunnerStub for active-unit gating
##
## ADR: ADR-0015 §4 + §5 + §OQ-4 (HUD owns two-tap timer; InputRouter receives
##      synthetic event on confirm via _handle_event)
## TR: TR-battle-hud-005, TR-battle-hud-017
##
## Gotchas applied (per `.claude/rules/godot-4x-gotchas.md`):
##   G-15: before_test (NOT before_each)
##   G-6: explicit free at end of body for Node-typed deps
##   G-22: source-scan structural assertion via FileAccess (test_no_gamebus_emit_calls_in_battle_hud_source)
##   G-4: lambda Array.append capture pattern (InputRouterSpy uses Array<InputEvent> field
##        which is reference-mutable and works inside connected callbacks)

extends GdUnitTestSuite

const BattleHUDScript: GDScript = preload("res://src/feature/battle_hud/battle_hud.gd")
const BattleCameraStubScript: GDScript = preload("res://tests/helpers/battle_camera_stub.gd")
const HPStatusControllerStubScript: GDScript = preload("res://tests/helpers/hp_status_controller_stub.gd")
const TurnOrderRunnerStubScript: GDScript = preload("res://tests/helpers/turn_order_runner_stub.gd")
const GridBattleControllerStubScript: GDScript = preload("res://tests/helpers/grid_battle_controller_stub.gd")
const MapGridStubScript: GDScript = preload("res://tests/helpers/map_grid_stub.gd")
const TerrainEffectStubScript: GDScript = preload("res://tests/helpers/terrain_effect_stub.gd")
const UnitRoleStubScript: GDScript = preload("res://tests/helpers/unit_role_stub.gd")
const HeroDatabaseStubScript: GDScript = preload("res://tests/helpers/hero_database_stub.gd")

const TEST_ACTIVE_UNIT_ID: int = 42
const TEST_INACTIVE_UNIT_ID: int = 99


## Inner Spy class — extends InputRouter (autoload identifier resolves to production
## script per Godot autoload contract; same path that InputRouterStub uses). Overrides
## _handle_event() to record dispatched InputEvents in a captured Array, short-circuiting
## production Phase 1 (mode-determine) + Phase 2 (action-resolve) + Phase 3 (dispatch).
##
## Per ADR-0015 §OQ-4: BattleHUD must invoke `_input_router._handle_event(synthetic_event)`
## on second tap of the two-tap window. The Spy verifies (a) call count and (b) the
## InputEventAction.action StringName payload.
class InputRouterSpy extends InputRouter:
	var captured_events: Array[InputEvent] = []

	func _handle_event(event: InputEvent) -> void:
		captured_events.append(event)


func before_test() -> void:
	# G-15 + hero_database.gd line 4-7 obligation: every test that touches
	# HeroDatabase static state MUST reset _heroes_loaded + _heroes.
	HeroDatabase._heroes_loaded = false
	HeroDatabase._heroes = {}


func after_test() -> void:
	# Idempotent crash-safety net per G-6 — actual cleanup happens in test bodies.
	HeroDatabase._heroes_loaded = false
	HeroDatabase._heroes = {}


# ─── Fixture builders ────────────────────────────────────────────────────────


func _make_hud_with_spy() -> Dictionary:
	var camera: BattleCameraStub = BattleCameraStubScript.new()
	var hp_controller: HPStatusControllerStub = HPStatusControllerStubScript.new()
	var turn_runner: TurnOrderRunnerStub = TurnOrderRunnerStubScript.new()
	var grid_controller: GridBattleControllerStub = GridBattleControllerStubScript.new()
	var input_router: InputRouterSpy = InputRouterSpy.new()
	var map_grid: MapGridStub = MapGridStubScript.new()
	var terrain_effect: TerrainEffectStub = TerrainEffectStubScript.new()
	var unit_role: UnitRoleStub = UnitRoleStubScript.new()
	var hero_db: HeroDatabaseStub = HeroDatabaseStubScript.new()

	var hud: BattleHUD = BattleHUDScript.new()
	hud.setup(camera, hp_controller, turn_runner, grid_controller, input_router,
			map_grid, terrain_effect, unit_role, hero_db)

	return {
		"hud": hud, "camera": camera, "hp_controller": hp_controller,
		"turn_runner": turn_runner, "grid_controller": grid_controller,
		"input_router": input_router, "map_grid": map_grid,
		"terrain_effect": terrain_effect, "unit_role": unit_role, "hero_db": hero_db,
	}


func _free_node_deps(bag: Dictionary) -> void:
	for key: String in ["camera", "hp_controller", "turn_runner",
			"grid_controller", "input_router", "map_grid"]:
		var dep: Variant = bag.get(key)
		if is_instance_valid(dep):
			var node: Node = dep as Node
			if node != null and not node.is_queued_for_deletion():
				node.free()


# ─── AC-1: 3 elements mount at _ready() hidden ────────────────────────────────


## AC-1: UI-GB-02 + UI-GB-05 + UI-GB-10 instantiated as children of HUD root, all hidden.
func test_three_elements_mount_at_ready_hidden() -> void:
	var bag: Dictionary = _make_hud_with_spy()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	for key: StringName in [&"UI-GB-02", &"UI-GB-05", &"UI-GB-10"]:
		var element: Control = hud._ui_elements.get(key)
		assert_object(element).override_failure_message(
			"AC-1: _ui_elements[%s] must be non-null after _ready" % key
		).is_not_null()
		assert_object(element.get_parent()).is_equal(hud)
		assert_bool(element.visible).override_failure_message(
			"AC-1: %s must start hidden (visible == false)" % key
		).is_false()

	hud.free()
	_free_node_deps(bag)


# ─── AC-2: unit_selected_changed visibility logic ─────────────────────────────


## AC-2: when active player unit is selected, UI-GB-02 becomes visible.
## TurnOrderRunnerStub default get_turn_order_snapshot() permissive fallback in
## _is_active_turn_unit returns true → UI-GB-02 visible == true.
func test_unit_selected_changed_shows_action_menu_for_active_unit() -> void:
	var bag: Dictionary = _make_hud_with_spy()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	# Inject a battle unit so show_unit_info doesn't NPE on missing-unit fallback path
	var grid_controller: GridBattleControllerStub = bag["grid_controller"]
	grid_controller.set_test_unit(TEST_ACTIVE_UNIT_ID, _make_battle_unit(TEST_ACTIVE_UNIT_ID))
	HeroDatabase._heroes_loaded = true

	# Drive the handler directly (synchronous; no await needed). _handle_signal is
	# a no-op hook in production; tests invoke handlers directly per existing precedent.
	hud._on_unit_selected_changed(TEST_ACTIVE_UNIT_ID, 1)

	var action_menu: Control = hud._ui_elements.get(&"UI-GB-02")
	assert_bool(action_menu.visible).override_failure_message(
		"AC-2: UI-GB-02 must become visible after unit_selected_changed for active unit"
	).is_true()

	hud.free()
	_free_node_deps(bag)


## AC-2 deselect: dismissing the active unit hides UI-GB-02 + UI-GB-05.
func test_unit_selected_changed_hides_panels_on_deselect() -> void:
	var bag: Dictionary = _make_hud_with_spy()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	# Pre-condition: simulate visible state from a prior selection.
	hud._ui_elements[&"UI-GB-02"].visible = true
	hud._ui_elements[&"UI-GB-05"].visible = true
	hud._active_status_panel_unit_id = TEST_ACTIVE_UNIT_ID

	# Deselect the active panel unit (direct handler invocation).
	hud._on_unit_selected_changed(TEST_ACTIVE_UNIT_ID, 0)

	assert_bool(hud._ui_elements[&"UI-GB-02"].visible).override_failure_message(
		"AC-2: UI-GB-02 must hide on deselect of active panel unit"
	).is_false()
	assert_bool(hud._ui_elements[&"UI-GB-05"].visible).override_failure_message(
		"AC-2: UI-GB-05 must hide on deselect (sub-panel of UI-GB-02)"
	).is_false()

	hud.free()
	_free_node_deps(bag)


# ─── AC-3: Two-tap ATTACK arm + confirm ───────────────────────────────────────


## AC-3: first ATTACK tap arms (_two_tap_target_action == &"attack" + timer running);
## second ATTACK tap within window dispatches synthetic attack_confirm event.
func test_two_tap_attack_first_arms_second_confirms() -> void:
	var bag: Dictionary = _make_hud_with_spy()
	var hud: BattleHUD = bag["hud"]
	var spy: InputRouterSpy = bag["input_router"]
	add_child(hud)

	# First tap — arm.
	hud._on_attack_button_pressed()
	assert_str(String(hud._two_tap_target_action)).override_failure_message(
		"AC-3: first tap must set _two_tap_target_action == 'attack', got '%s'" % String(hud._two_tap_target_action)
	).is_equal("attack")
	assert_bool(hud._two_tap_timer.is_stopped()).override_failure_message(
		"AC-3: first tap must START the two-tap timer (is_stopped() == false)"
	).is_false()
	assert_int(spy.captured_events.size()).override_failure_message(
		"AC-3: first tap must NOT dispatch attack_confirm yet, captured %d events" % spy.captured_events.size()
	).is_equal(0)

	# Second tap — confirm.
	hud._on_attack_button_pressed()

	assert_int(spy.captured_events.size()).override_failure_message(
		"AC-3: second tap must dispatch exactly 1 synthetic event, got %d" % spy.captured_events.size()
	).is_equal(1)
	var ev: InputEventAction = spy.captured_events[0] as InputEventAction
	assert_object(ev).is_not_null()
	assert_str(String(ev.action)).override_failure_message(
		"AC-3: dispatched event action must be 'attack_confirm', got '%s'" % String(ev.action)
	).is_equal("attack_confirm")
	assert_str(String(hud._two_tap_target_action)).override_failure_message(
		"AC-3: arm must clear after confirm (got '%s')" % String(hud._two_tap_target_action)
	).is_equal("")

	hud.free()
	_free_node_deps(bag)


# ─── AC-4: Two-tap DEFEND arm + confirm ───────────────────────────────────────


## AC-4: same pattern as AC-3 but for DEFEND.
func test_two_tap_defend_first_arms_second_confirms() -> void:
	var bag: Dictionary = _make_hud_with_spy()
	var hud: BattleHUD = bag["hud"]
	var spy: InputRouterSpy = bag["input_router"]
	add_child(hud)

	hud._on_defend_button_pressed()
	hud._on_defend_button_pressed()

	assert_int(spy.captured_events.size()).is_equal(1)
	var ev: InputEventAction = spy.captured_events[0] as InputEventAction
	assert_str(String(ev.action)).is_equal("defend_confirm")
	assert_str(String(hud._two_tap_target_action)).is_equal("")

	hud.free()
	_free_node_deps(bag)


## AC-4 edge case: ATTACK then DEFEND cancels ATTACK arm + arms DEFEND.
## Second DEFEND tap then confirms DEFEND, NOT ATTACK.
func test_two_tap_attack_then_defend_cancels_attack_arms_defend() -> void:
	var bag: Dictionary = _make_hud_with_spy()
	var hud: BattleHUD = bag["hud"]
	var spy: InputRouterSpy = bag["input_router"]
	add_child(hud)

	# Tap ATTACK (arms attack)
	hud._on_attack_button_pressed()
	assert_str(String(hud._two_tap_target_action)).is_equal("attack")

	# Tap DEFEND (cancels attack arm, arms defend) — different action triggers re-arm
	hud._on_defend_button_pressed()
	assert_str(String(hud._two_tap_target_action)).override_failure_message(
		"AC-4 edge: DEFEND tap while attack-armed must re-arm to defend, got '%s'" % String(hud._two_tap_target_action)
	).is_equal("defend")

	# At this point, no events should be captured yet (only first taps).
	assert_int(spy.captured_events.size()).override_failure_message(
		"AC-4 edge: first taps must NOT dispatch confirm events"
	).is_equal(0)

	# Tap DEFEND again — confirms defend (NOT attack).
	hud._on_defend_button_pressed()
	assert_int(spy.captured_events.size()).is_equal(1)
	var ev: InputEventAction = spy.captured_events[0] as InputEventAction
	assert_str(String(ev.action)).override_failure_message(
		"AC-4 edge: confirmed event must be defend_confirm, got '%s'" % String(ev.action)
	).is_equal("defend_confirm")

	hud.free()
	_free_node_deps(bag)


# ─── AC-5: Two-tap timeout cancels pending action ─────────────────────────────


## AC-5: Timer.timeout (or manual _on_two_tap_timeout invocation for determinism)
## clears the pending arm without firing a confirm event.
func test_two_tap_timer_timeout_cancels_pending_action() -> void:
	var bag: Dictionary = _make_hud_with_spy()
	var hud: BattleHUD = bag["hud"]
	var spy: InputRouterSpy = bag["input_router"]
	add_child(hud)

	# Arm ATTACK.
	hud._on_attack_button_pressed()
	assert_str(String(hud._two_tap_target_action)).is_equal("attack")

	# Manually invoke timeout for determinism (real-time wait is non-deterministic in headless).
	hud._on_two_tap_timeout()

	assert_str(String(hud._two_tap_target_action)).override_failure_message(
		"AC-5: timeout must clear the pending arm (got '%s')" % String(hud._two_tap_target_action)
	).is_equal("")
	assert_int(spy.captured_events.size()).override_failure_message(
		"AC-5: timeout must NOT dispatch any synthetic confirm event, captured %d events" % spy.captured_events.size()
	).is_equal(0)

	hud.free()
	_free_node_deps(bag)


# ─── AC-6: UI-GB-10 Undo button dispatch ──────────────────────────────────────


## AC-6: clicking the Undo button dispatches a synthetic undo_action event
## via InputRouter._handle_event. No two-tap required for undo (single-tap commit).
func test_undo_button_invokes_synthetic_undo_action_event() -> void:
	var bag: Dictionary = _make_hud_with_spy()
	var hud: BattleHUD = bag["hud"]
	var spy: InputRouterSpy = bag["input_router"]
	add_child(hud)

	hud._on_undo_button_pressed()

	assert_int(spy.captured_events.size()).is_equal(1)
	var ev: InputEventAction = spy.captured_events[0] as InputEventAction
	assert_str(String(ev.action)).is_equal("undo_action")

	hud.free()
	_free_node_deps(bag)


# ─── AC-7: USE_SKILL reveals UI-GB-05 + skill slot dispatches ─────────────────


## AC-7: clicking USE_SKILL reveals UI-GB-05; clicking a skill slot dispatches
## synthetic skill_use_<slot> event.
func test_use_skill_reveals_skill_list_and_skill_slot_dispatches() -> void:
	var bag: Dictionary = _make_hud_with_spy()
	var hud: BattleHUD = bag["hud"]
	var spy: InputRouterSpy = bag["input_router"]
	add_child(hud)

	hud._on_use_skill_button_pressed()

	var skill_panel: Control = hud._ui_elements.get(&"UI-GB-05")
	assert_bool(skill_panel.visible).override_failure_message(
		"AC-7: UI-GB-05 must become visible after USE_SKILL click"
	).is_true()

	hud._on_skill_slot_pressed(0)
	assert_int(spy.captured_events.size()).is_equal(1)
	var ev: InputEventAction = spy.captured_events[0] as InputEventAction
	assert_str(String(ev.action)).override_failure_message(
		"AC-7: skill slot 0 click must dispatch skill_use_0, got '%s'" % String(ev.action)
	).is_equal("skill_use_0")

	hud.free()
	_free_node_deps(bag)


# ─── AC-9: ADR-0015 §OQ-4 contract — non-emitter discipline ──────────────────


## AC-9 + R-5: structural source-scan asserts that battle_hud.gd contains ZERO
## `GameBus.<signal>.emit(` patterns (forbidden_pattern: battle_hud_signal_emission).
## G-22 source-scan substitute (story-008 lint will automate this at CI).
func test_no_gamebus_emit_calls_in_battle_hud_source() -> void:
	var content: String = FileAccess.get_file_as_string("res://src/feature/battle_hud/battle_hud.gd")
	assert_bool(content.is_empty()).override_failure_message(
		"AC-9 setup: battle_hud.gd source must be readable"
	).is_false()

	var regex: RegEx = RegEx.create_from_string("GameBus\\.[a-zA-Z_]+\\.emit\\s*\\(")
	var matches: Array[RegExMatch] = regex.search_all(content)
	# Filter out doc-comment matches (lines starting with `##` or `#`)
	var production_matches: int = 0
	var lines: PackedStringArray = content.split("\n")
	for m: RegExMatch in matches:
		# Find which line the match is on
		var pos: int = m.get_start()
		var prefix: String = content.substr(0, pos)
		var line_num: int = prefix.count("\n")
		if line_num >= lines.size():
			continue
		var line_content: String = lines[line_num].strip_edges()
		if line_content.begins_with("#"):
			continue  # doc-comment; ignore
		production_matches += 1
	assert_int(production_matches).override_failure_message(
		"AC-9 + R-5: battle_hud.gd MUST have ZERO GameBus.*.emit production calls "
		+ "(non-emitter discipline per forbidden_pattern battle_hud_signal_emission); "
		+ "found %d production matches" % production_matches
	).is_equal(0)


# ─── Helpers ──────────────────────────────────────────────────────────────────


func _make_battle_unit(unit_id: int) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.hero_id = &"shu_001_wei_yan"
	unit.is_player_controlled = true
	unit.unit_class = 0  # CAVALRY (per ADR-0009 EC-7 + unit-role.md)
	unit.raw_atk = 17
	unit.raw_def = 9
	unit.facing = 1  # E
	return unit
