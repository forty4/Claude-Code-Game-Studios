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


var _saved_locale: String


func before_test() -> void:
	HeroDatabase._heroes_loaded = false
	HeroDatabase._heroes = {}
	# Force "en" locale so tooltip translation assertions stay stable across
	# CI runs regardless of system locale (mirrors battle_hud_forecast_test
	# + battle_hud_unit_info_test pattern).
	_saved_locale = TranslationServer.get_locale()
	TranslationServer.set_locale("en")


func after_test() -> void:
	HeroDatabase._heroes_loaded = false
	HeroDatabase._heroes = {}
	if _saved_locale != "":
		TranslationServer.set_locale(_saved_locale)


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


# ─── S91 step 9 follow-up: UI-GB-17 tile-click target confirmation ───────────


## Helper — make a ctx with target_coord (mirrors what InputRouter produces).
func _make_ctx_with_coord(coord: Vector2i) -> InputContext:
	var ctx: InputContext = InputContext.new()
	ctx.target_coord = coord
	return ctx


## Slot click for a non-SELF item (fire_scroll → GROUND target_type) arms the
## controller via set_item_target_armed(true) + records the pending slot index +
## triggers begin_item_target_selection so the UI-GB-17 overlay can render.
func test_non_self_slot_click_arms_controller_and_overlay() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid: GridBattleControllerStub = bag["grid_controller"]
	add_child(hud)

	# Arrange — active player unit with fire_scroll in slot 1.
	var unit: BattleUnit = _make_unit(0, [&"heal_potion", &"fire_scroll", &""])
	grid.set_test_unit(TEST_UNIT_ID, unit)
	grid.set_test_active_turn_unit_id(TEST_UNIT_ID)
	# Open panel
	hud._on_input_action_fired(&"use_item", null)

	# Act — slot 1 click (fire_scroll)
	hud._on_inventory_slot_pressed(1)

	# Assert — controller armed, panel records pending slot, begin emit fired
	assert_int(hud._inventory_pending_slot).override_failure_message(
		"step 9 follow-up: non-SELF slot click must record pending slot index"
	).is_equal(1)
	assert_int(grid.set_item_target_armed_calls.size()).is_equal(1)
	assert_bool(grid.set_item_target_armed_calls[0]).override_failure_message(
		"step 9 follow-up: non-SELF slot click must call set_item_target_armed(true)"
	).is_true()
	assert_int(grid.begin_item_target_selection_calls.size()).is_equal(1)
	assert_str(String(grid.begin_item_target_selection_calls[0]["palette"] as StringName)).is_equal("GROUND")
	# Panel stays open during target-selection phase
	var panel: Control = hud._ui_elements.get(&"UI-GB-15")
	assert_bool(panel.visible).is_true()

	hud.free()
	_free_bag(bag)


## S94 — slot click for an ALLY item (aid_potion) arms target selection with the
## ALLY palette (UI-GB-17 금록), mirroring the GROUND path. Proves the cross-hero
## items route through the existing target-overlay flow with the correct palette.
func test_ally_item_slot_click_arms_controller_with_ally_palette() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid: GridBattleControllerStub = bag["grid_controller"]
	add_child(hud)

	# Arrange — active player unit with aid_potion in slot 1.
	var unit: BattleUnit = _make_unit(0, [&"heal_potion", &"aid_potion", &""])
	grid.set_test_unit(TEST_UNIT_ID, unit)
	grid.set_test_active_turn_unit_id(TEST_UNIT_ID)
	hud._on_input_action_fired(&"use_item", null)

	# Act — slot 1 click (aid_potion → ALLY target_type)
	hud._on_inventory_slot_pressed(1)

	# Assert — armed with ALLY palette, pending slot recorded
	assert_int(hud._inventory_pending_slot).is_equal(1)
	assert_int(grid.set_item_target_armed_calls.size()).is_equal(1)
	assert_bool(grid.set_item_target_armed_calls[0]).is_true()
	assert_int(grid.begin_item_target_selection_calls.size()).is_equal(1)
	assert_str(String(grid.begin_item_target_selection_calls[0]["palette"] as StringName)).override_failure_message(
		"S94: aid_potion slot click must arm target selection with the ALLY palette"
	).is_equal("ALLY")
	var panel: Control = hud._ui_elements.get(&"UI-GB-15")
	assert_bool(panel.visible).is_true()

	hud.free()
	_free_bag(bag)


## Tile click while armed at a valid target tile → use_item(uid, slot, coord).
## Panel + overlay clear via use_item completion (mocked here via stub return
## true → _on_unit_item_used is normally signal-driven, not in this synchronous
## test path — we verify the use_item invocation alone).
func test_armed_tile_click_at_valid_coord_calls_use_item_with_target_pos() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid: GridBattleControllerStub = bag["grid_controller"]
	add_child(hud)

	# Arrange — armed state set up via slot click path
	var unit: BattleUnit = _make_unit(0, [&"heal_potion", &"fire_scroll", &""])
	grid.set_test_unit(TEST_UNIT_ID, unit)
	grid.set_test_active_turn_unit_id(TEST_UNIT_ID)
	grid.set_test_item_target_tiles(PackedVector2Array([Vector2(3, 2), Vector2(4, 4)]))
	hud._on_input_action_fired(&"use_item", null)
	hud._on_inventory_slot_pressed(1)
	# Sanity — armed
	assert_int(hud._inventory_pending_slot).is_equal(1)

	# Act — tile click at a valid coord (move_target_select arrives with coord)
	var ctx: InputContext = _make_ctx_with_coord(Vector2i(3, 2))
	hud._on_input_action_fired(&"move_target_select", ctx)

	# Assert — use_item called with (uid=7, slot=1, target_pos=(3,2))
	assert_int(grid.use_item_calls.size()).override_failure_message(
		"step 9 follow-up: armed tile click at valid coord must call use_item exactly once"
	).is_equal(1)
	assert_int(grid.use_item_calls[0]["unit_id"] as int).is_equal(TEST_UNIT_ID)
	assert_int(grid.use_item_calls[0]["slot_idx"] as int).is_equal(1)
	assert_vector(grid.use_item_calls[0]["target_pos"] as Vector2i).override_failure_message(
		"step 9 follow-up: use_item must receive the clicked target_pos verbatim"
	).is_equal(Vector2i(3, 2))

	hud.free()
	_free_bag(bag)


## Tile click while armed at an OUT-OF-RANGE coord → use_item NOT called +
## feedback label flashed. Player can re-click at a valid tile (arming stays).
func test_armed_tile_click_at_invalid_coord_no_use_item_shows_feedback() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid: GridBattleControllerStub = bag["grid_controller"]
	add_child(hud)

	var unit: BattleUnit = _make_unit(0, [&"heal_potion", &"fire_scroll", &""])
	grid.set_test_unit(TEST_UNIT_ID, unit)
	grid.set_test_active_turn_unit_id(TEST_UNIT_ID)
	# Only (3, 2) is valid; (9, 9) is out of range
	grid.set_test_item_target_tiles(PackedVector2Array([Vector2(3, 2)]))
	hud._on_input_action_fired(&"use_item", null)
	hud._on_inventory_slot_pressed(1)

	# Act — click at out-of-range coord
	var ctx: InputContext = _make_ctx_with_coord(Vector2i(9, 9))
	hud._on_input_action_fired(&"move_target_select", ctx)

	# Assert — no use_item, feedback visible
	assert_int(grid.use_item_calls.size()).override_failure_message(
		"step 9 follow-up: out-of-range tile click must NOT call use_item"
	).is_equal(0)
	var panel: Control = hud._ui_elements.get(&"UI-GB-15")
	var feedback: Label = panel.get_node_or_null("VBoxContainer/FeedbackLabel") as Label
	assert_bool(feedback.visible).override_failure_message(
		"step 9 follow-up: out-of-range click must show FeedbackLabel (target_invalid)"
	).is_true()
	# Arm state preserved — player can re-click
	assert_int(hud._inventory_pending_slot).is_equal(1)

	hud.free()
	_free_bag(bag)


# ─── Tooltip / i18n integration ──────────────────────────────────────────────


## Slot button tooltip_text is set per-item with the formatted name + effect.
## Tooltip is the R-6-D secondary-info path; primary remains slot click.
func test_inventory_slot_tooltip_renders_translated_name_and_effect() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid: GridBattleControllerStub = bag["grid_controller"]
	add_child(hud)

	var unit: BattleUnit = _make_unit(0, [&"heal_potion", &"fire_scroll", &""])
	grid.set_test_unit(TEST_UNIT_ID, unit)
	grid.set_test_active_turn_unit_id(TEST_UNIT_ID)
	hud._on_input_action_fired(&"use_item", null)

	# heal_potion slot tooltip (no restriction)
	var tip_0: String = hud._btn_inventory_slot_0.tooltip_text
	assert_str(tip_0).override_failure_message(
		"R-6-D: heal_potion slot tooltip must include translated item name"
	).contains("Healing Potion")
	assert_str(tip_0).contains("Restore 25 HP")
	# fire_scroll slot tooltip (HAS a restriction label)
	var tip_1: String = hud._btn_inventory_slot_1.tooltip_text
	assert_str(tip_1).override_failure_message(
		"R-6-D: fire_scroll slot tooltip must include translated item name"
	).contains("Fire Scroll")
	assert_str(tip_1).contains("Range-3 fire AoE")
	assert_str(tip_1).override_failure_message(
		"R-6-D: fire_scroll tooltip must include restriction text when non-empty"
	).contains("INT >= 60")
	# Empty slot tooltip — just the empty-slot label
	var tip_2: String = hud._btn_inventory_slot_2.tooltip_text
	assert_str(tip_2).is_equal("(Empty)")

	hud.free()
	_free_bag(bag)


## Closing the panel (e.g. second I-press) while armed disarms the controller.
func test_closing_panel_while_armed_disarms_controller() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid: GridBattleControllerStub = bag["grid_controller"]
	add_child(hud)

	var unit: BattleUnit = _make_unit(0, [&"heal_potion", &"fire_scroll", &""])
	grid.set_test_unit(TEST_UNIT_ID, unit)
	grid.set_test_active_turn_unit_id(TEST_UNIT_ID)
	hud._on_input_action_fired(&"use_item", null)
	hud._on_inventory_slot_pressed(1)
	# Sanity — armed
	assert_int(grid.set_item_target_armed_calls.size()).is_equal(1)
	assert_bool(grid.set_item_target_armed_calls[0]).is_true()

	# Act — second I-press closes the panel
	hud._on_input_action_fired(&"use_item", null)

	# Assert — disarm call recorded
	assert_int(grid.set_item_target_armed_calls.size()).override_failure_message(
		"step 9 follow-up: closing armed panel must emit a 2nd set_item_target_armed call"
	).is_equal(2)
	assert_bool(grid.set_item_target_armed_calls[1]).override_failure_message(
		"step 9 follow-up: second call on close must be set_item_target_armed(false)"
	).is_false()
	# Clear emit also fires
	assert_int(grid.clear_item_target_selection_count).is_equal(1)

	hud.free()
	_free_bag(bag)
