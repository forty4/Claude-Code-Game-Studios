## BattleHUD UI-GB-15/16/17 inventory + buff indicator + target overlay tests
## (S91+ Phase B step 9 / strategy-systems.md v0.3 §3.5 / battle-hud.md §3.2).
##
## Covers headless-feasible behaviors (visibility state machine + signal
## subscription contracts + slot data binding). Visual rendering of overlay
## tile tints + glyph anchoring is windowed-mode verification (G-30) — not
## reachable from this test file.
##
## ADR: ADR-0015 Battle HUD signal discipline
## Story: Strategy Systems Phase B step 9 (UI-GB-15/16/17)
##
## Gotcha references:
##   G-4: lambda primitive capture — use Array.append() pattern when needed
##   G-6: explicit free() in test body before after_test
##   G-7: verify Overall Summary count after run
##   G-15: before_test (NOT before_each) for HeroDatabase static reset
##   G-28: explicit per-test disconnect; never bulk-disconnect-all on signal
extends GdUnitTestSuite

const BattleHUDScript: GDScript = preload("res://src/feature/battle_hud/battle_hud.gd")
const BattleCameraStubScript: GDScript = preload("res://tests/helpers/battle_camera_stub.gd")
const HPStatusControllerStubScript: GDScript = preload("res://tests/helpers/hp_status_controller_stub.gd")
const TurnOrderRunnerStubScript: GDScript = preload("res://tests/helpers/turn_order_runner_stub.gd")
const GridBattleControllerStubScript: GDScript = preload("res://tests/helpers/grid_battle_controller_stub.gd")
const InputRouterStubScript: GDScript = preload("res://tests/helpers/input_router_stub.gd")
const MapGridStubScript: GDScript = preload("res://tests/helpers/map_grid_stub.gd")
const TerrainEffectStubScript: GDScript = preload("res://tests/helpers/terrain_effect_stub.gd")
const UnitRoleStubScript: GDScript = preload("res://tests/helpers/unit_role_stub.gd")
const HeroDatabaseStubScript: GDScript = preload("res://tests/helpers/hero_database_stub.gd")

const TEST_UNIT_ID: int = 7


func before_test() -> void:
	HeroDatabase._heroes_loaded = false
	HeroDatabase._heroes = {}


func after_test() -> void:
	HeroDatabase._heroes_loaded = false
	HeroDatabase._heroes = {}


func _make_hud_with_stubs() -> Dictionary:
	var camera: BattleCameraStub = BattleCameraStubScript.new()
	var hp_controller: HPStatusControllerStub = HPStatusControllerStubScript.new()
	var turn_runner: TurnOrderRunnerStub = TurnOrderRunnerStubScript.new()
	var grid_controller: GridBattleControllerStub = GridBattleControllerStubScript.new()
	var input_router: InputRouterStub = InputRouterStubScript.new()
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


func _free_bag(bag: Dictionary) -> void:
	# hud first (its _exit_tree runs against live deps), then Node deps.
	for key: String in ["hud", "camera", "hp_controller", "turn_runner",
			"grid_controller", "input_router", "map_grid"]:
		var dep: Variant = bag.get(key)
		if is_instance_valid(dep):
			var node: Node = dep as Node
			if node != null and not node.is_queued_for_deletion():
				node.free()


func _make_unit(side: int, inventory: Array[StringName] = []) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = TEST_UNIT_ID
	unit.hero_id = &"test_hero_001"
	unit.unit_class = UnitRole.UnitClass.INFANTRY
	unit.side = side
	unit.inventory = inventory
	return unit


# ─── Mount: UI-GB-15 + UI-GB-16 exist at _ready() as hidden HUD children ──────


func test_ui_gb_15_mounts_as_hud_child_starts_hidden() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	var panel: Control = hud._ui_elements.get(&"UI-GB-15")
	assert_object(panel).override_failure_message(
		"Phase B step 9: UI-GB-15 must be present in _ui_elements after _ready"
	).is_not_null()
	assert_object(panel.get_parent()).is_equal(hud)
	assert_bool(panel.visible).override_failure_message(
		"Phase B step 9: UI-GB-15 must start hidden (visible=false)"
	).is_false()

	hud.free()
	_free_bag(bag)


func test_ui_gb_16_mounts_as_hud_child_starts_hidden() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	var glyph: Control = hud._ui_elements.get(&"UI-GB-16")
	assert_object(glyph).override_failure_message(
		"Phase B step 9: UI-GB-16 must be present in _ui_elements after _ready"
	).is_not_null()
	assert_object(glyph.get_parent()).is_equal(hud)
	assert_bool(glyph.visible).override_failure_message(
		"Phase B step 9: UI-GB-16 must start hidden until pending_buff set"
	).is_false()

	hud.free()
	_free_bag(bag)


# ─── _on_input_action_fired toggles UI-GB-15 visibility on &"use_item" ────────


func test_use_item_action_opens_panel_when_active_player_unit() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid: GridBattleControllerStub = bag["grid_controller"]
	add_child(hud)

	var unit: BattleUnit = _make_unit(0, [&"heal_potion", &"strength_scroll", &""])
	grid.set_test_unit(TEST_UNIT_ID, unit)
	grid.set_test_active_turn_unit_id(TEST_UNIT_ID)

	# Act — fire use_item action directly through the HUD handler (bypasses
	# GameBus signal so the test runs synchronously; the connect itself is
	# verified by the connect-deferred lint).
	hud._on_input_action_fired(&"use_item", null)

	# Assert — panel now visible, inventory unit tracked
	var panel: Control = hud._ui_elements.get(&"UI-GB-15")
	assert_bool(panel.visible).override_failure_message(
		"Phase B step 9: use_item action with active player unit must open UI-GB-15"
	).is_true()
	assert_int(hud._inventory_unit_id).override_failure_message(
		"Phase B step 9: opening panel must record _inventory_unit_id = active unit"
	).is_equal(TEST_UNIT_ID)

	hud.free()
	_free_bag(bag)


func test_use_item_action_closes_panel_on_second_press() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid: GridBattleControllerStub = bag["grid_controller"]
	add_child(hud)

	var unit: BattleUnit = _make_unit(0, [&"heal_potion", &"", &""])
	grid.set_test_unit(TEST_UNIT_ID, unit)
	grid.set_test_active_turn_unit_id(TEST_UNIT_ID)

	# First press opens, second press closes.
	hud._on_input_action_fired(&"use_item", null)
	hud._on_input_action_fired(&"use_item", null)

	var panel: Control = hud._ui_elements.get(&"UI-GB-15")
	assert_bool(panel.visible).override_failure_message(
		"Phase B step 9: second use_item action press must close UI-GB-15 (toggle)"
	).is_false()
	assert_int(hud._inventory_unit_id).override_failure_message(
		"Phase B step 9: closing panel must reset _inventory_unit_id to -1"
	).is_equal(-1)

	hud.free()
	_free_bag(bag)


func test_use_item_action_no_op_when_no_active_player_unit() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid: GridBattleControllerStub = bag["grid_controller"]
	add_child(hud)

	# No active unit registered — set_test_active_turn_unit_id default is -1.
	grid.set_test_active_turn_unit_id(-1)

	hud._on_input_action_fired(&"use_item", null)

	var panel: Control = hud._ui_elements.get(&"UI-GB-15")
	assert_bool(panel.visible).override_failure_message(
		"Phase B step 9: R-3 guard — use_item action with no active unit must NOT open panel"
	).is_false()

	hud.free()
	_free_bag(bag)


func test_use_item_action_no_op_when_active_enemy_unit() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid: GridBattleControllerStub = bag["grid_controller"]
	add_child(hud)

	var enemy_unit: BattleUnit = _make_unit(1, [&"heal_potion", &"", &""])
	grid.set_test_unit(TEST_UNIT_ID, enemy_unit)
	grid.set_test_active_turn_unit_id(TEST_UNIT_ID)

	hud._on_input_action_fired(&"use_item", null)

	var panel: Control = hud._ui_elements.get(&"UI-GB-15")
	assert_bool(panel.visible).override_failure_message(
		"Phase B step 9: R-3 guard — enemy-side active turn must NOT open panel"
	).is_false()

	hud.free()
	_free_bag(bag)


func test_non_use_item_action_does_not_toggle_panel() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid: GridBattleControllerStub = bag["grid_controller"]
	add_child(hud)

	var unit: BattleUnit = _make_unit(0, [&"heal_potion", &"", &""])
	grid.set_test_unit(TEST_UNIT_ID, unit)
	grid.set_test_active_turn_unit_id(TEST_UNIT_ID)

	# Other actions arriving via the same signal must NOT toggle the panel.
	hud._on_input_action_fired(&"move", null)
	hud._on_input_action_fired(&"use_skill", null)
	hud._on_input_action_fired(&"defend_stance", null)

	var panel: Control = hud._ui_elements.get(&"UI-GB-15")
	assert_bool(panel.visible).override_failure_message(
		"Phase B step 9: non-use_item actions must NOT open the inventory panel"
	).is_false()

	hud.free()
	_free_bag(bag)


# ─── UI-GB-16 buff indicator visibility ──────────────────────────────────────


func test_pending_buff_changed_true_for_active_unit_shows_glyph() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid: GridBattleControllerStub = bag["grid_controller"]
	add_child(hud)

	grid.set_test_active_turn_unit_id(TEST_UNIT_ID)

	# Fire the handler directly (signal connection itself is verified by the
	# connect-deferred lint; the test exercises the handler's visibility logic).
	hud._on_unit_pending_buff_changed(TEST_UNIT_ID, true)

	var glyph: Control = hud._ui_elements.get(&"UI-GB-16")
	assert_bool(glyph.visible).override_failure_message(
		"Phase B step 9: pending_buff_changed(active, true) must show UI-GB-16 glyph"
	).is_true()

	hud.free()
	_free_bag(bag)


func test_pending_buff_changed_false_hides_glyph() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid: GridBattleControllerStub = bag["grid_controller"]
	add_child(hud)

	grid.set_test_active_turn_unit_id(TEST_UNIT_ID)

	hud._on_unit_pending_buff_changed(TEST_UNIT_ID, true)
	hud._on_unit_pending_buff_changed(TEST_UNIT_ID, false)

	var glyph: Control = hud._ui_elements.get(&"UI-GB-16")
	assert_bool(glyph.visible).override_failure_message(
		"Phase B step 9: pending_buff_changed(active, false) must hide UI-GB-16 glyph"
	).is_false()

	hud.free()
	_free_bag(bag)


func test_pending_buff_changed_non_active_unit_ignored() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid: GridBattleControllerStub = bag["grid_controller"]
	add_child(hud)

	grid.set_test_active_turn_unit_id(TEST_UNIT_ID)
	# Signal for a DIFFERENT unit (not the active one) — handler must ignore
	# so the glyph doesn't flip on non-active units' buff transitions.
	hud._on_unit_pending_buff_changed(TEST_UNIT_ID + 1, true)

	var glyph: Control = hud._ui_elements.get(&"UI-GB-16")
	assert_bool(glyph.visible).override_failure_message(
		"Phase B step 9: pending_buff_changed for non-active unit must NOT toggle glyph"
	).is_false()

	hud.free()
	_free_bag(bag)
