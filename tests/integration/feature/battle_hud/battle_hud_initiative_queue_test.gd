## BattleHUD UI-GB-01 Initiative Queue + UI-GB-07 Turn/Round Counter +
## UI-GB-08 Victory Condition integration test (sprint-7 S7-09 / story-004).
##
## Covers AC-1..AC-6 from production/epics/battle-hud/story-004-initiative-queue-counters.md:
##   AC-1: 3 elements mount at _ready()
##   AC-2: round_started rebuilds UI-GB-01 + updates UI-GB-07 round_label
##   AC-3: unit_turn_started highlights UI-GB-01 slot + updates UI-GB-07 turn_label
##   AC-4: unit_turn_ended clears highlight
##   AC-5: unit_died rebuilds UI-GB-01
##   AC-6: set_victory_condition() shows UI-GB-08 with translated text
##
## AC-7 (i18n discipline) + AC-8 (per-slot tooltip AccessKit) are MANUAL gates
## documented in production/qa/evidence/battle-hud-story-004-evidence.md.
##
## Gotchas applied:
##   G-15: before_test (NOT before_each)
##   G-22: HeroDatabase @abstract; reset _heroes_loaded + _heroes per file
##   G-6: explicit free in test bodies for Node-typed deps
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

const TurnState = TurnOrderRunner.TurnState


func before_test() -> void:
	HeroDatabase._heroes_loaded = false
	HeroDatabase._heroes = {}


func after_test() -> void:
	HeroDatabase._heroes_loaded = false
	HeroDatabase._heroes = {}


# ─── Fixture builders ────────────────────────────────────────────────────────


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
		"hud": hud, "turn_runner": turn_runner, "grid_controller": grid_controller,
		"camera": camera, "hp_controller": hp_controller, "input_router": input_router,
		"map_grid": map_grid, "terrain_effect": terrain_effect, "unit_role": unit_role,
		"hero_db": hero_db,
	}


func _free_node_deps(bag: Dictionary) -> void:
	for key: String in ["camera", "hp_controller", "turn_runner",
			"grid_controller", "input_router", "map_grid"]:
		var dep: Variant = bag.get(key)
		if is_instance_valid(dep):
			var node: Node = dep as Node
			if node != null and not node.is_queued_for_deletion():
				node.free()


func _seed_turn_state(runner: TurnOrderRunnerStub, unit_id: int, init_val: int) -> void:
	var s: UnitTurnState = UnitTurnState.new()
	s.unit_id = unit_id
	s.initiative = init_val
	s.acted_this_turn = false
	s.turn_state = TurnState.IDLE
	runner._unit_states[unit_id] = s


func _seed_battle_unit(grid: GridBattleControllerStub, unit_id: int, hero_id: StringName) -> void:
	var u: BattleUnit = BattleUnit.new()
	u.unit_id = unit_id
	u.hero_id = hero_id
	grid.set_test_unit(unit_id, u)


func _seed_hero(hero_id: StringName, name_ko: String) -> void:
	var hero: HeroData = HeroData.new()
	hero.hero_id = hero_id
	hero.name_ko = name_ko
	HeroDatabase._heroes[hero_id] = hero
	HeroDatabase._heroes_loaded = true


# ─── AC-1: 3 elements mount at _ready() ──────────────────────────────────────


func test_ui_gb_01_07_08_elements_mount_at_ready() -> void:
	var fixture: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = fixture["hud"]
	add_child(hud)
	await get_tree().process_frame

	assert_object(hud._ui_elements.get(&"UI-GB-01")).override_failure_message(
		"AC-1: UI-GB-01 must mount at _ready"
	).is_not_null()
	assert_object(hud._ui_elements.get(&"UI-GB-07")).override_failure_message(
		"AC-1: UI-GB-07 must mount at _ready"
	).is_not_null()
	assert_object(hud._ui_elements.get(&"UI-GB-08")).override_failure_message(
		"AC-1: UI-GB-08 must mount at _ready"
	).is_not_null()
	# UI-GB-08 starts hidden per spec
	var v_panel: Control = hud._ui_elements.get(&"UI-GB-08")
	assert_bool(v_panel.visible).override_failure_message(
		"AC-1: UI-GB-08 starts hidden by default"
	).is_false()
	# UI-GB-01 has 8 slots cached
	assert_int(hud._ui_gb_01_slots.size()).is_equal(8)

	hud.free()
	_free_node_deps(fixture)


# ─── AC-2: round_started rebuilds UI-GB-01 + updates UI-GB-07 round_label ──


func test_round_started_rebuilds_ui_gb_01_and_updates_round_label() -> void:
	var fixture: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = fixture["hud"]
	var runner: TurnOrderRunnerStub = fixture["turn_runner"]
	var grid: GridBattleControllerStub = fixture["grid_controller"]

	# Seed 3 units with hero data
	_seed_hero(&"shu_001", "Liu Bei")
	_seed_hero(&"shu_003", "Zhang Fei")
	_seed_hero(&"wei_005", "Xiahou Dun")
	_seed_battle_unit(grid, 0, &"shu_001")
	_seed_battle_unit(grid, 1, &"shu_003")
	_seed_battle_unit(grid, 2, &"wei_005")
	_seed_turn_state(runner, 0, 90)
	_seed_turn_state(runner, 1, 80)
	_seed_turn_state(runner, 2, 70)
	runner._queue = [0, 1, 2]
	runner._round_number = 3

	add_child(hud)
	await get_tree().process_frame

	# Trigger round_started
	GameBus.round_started.emit(3)
	await get_tree().process_frame

	# UI-GB-07 round_label
	var counter: Control = hud._ui_elements.get(&"UI-GB-07")
	var round_label: Label = counter.get_node("RoundLabel") as Label
	assert_str(round_label.text).is_equal("Round 3")

	# UI-GB-01 slots[0..2] visible, slots[3..7] hidden
	for i: int in range(3):
		assert_bool(hud._ui_gb_01_slots[i].visible).override_failure_message(
			"AC-2: slot[%d] must be visible after rebuild with 3 units" % i
		).is_true()
	for i: int in range(3, 8):
		assert_bool(hud._ui_gb_01_slots[i].visible).override_failure_message(
			"AC-2: slot[%d] must be hidden (only 3 units in queue)" % i
		).is_false()
	# Slot unit_ids tracked
	assert_int(hud._ui_gb_01_slot_unit_ids[0]).is_equal(0)
	assert_int(hud._ui_gb_01_slot_unit_ids[1]).is_equal(1)
	assert_int(hud._ui_gb_01_slot_unit_ids[2]).is_equal(2)

	# Disconnect from GameBus to prevent test pollution
	hud.free()
	_free_node_deps(fixture)


# ─── AC-3: unit_turn_started highlights UI-GB-01 + updates UI-GB-07 ──────


func test_unit_turn_started_highlights_slot_and_updates_turn_label() -> void:
	var fixture: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = fixture["hud"]
	var runner: TurnOrderRunnerStub = fixture["turn_runner"]
	var grid: GridBattleControllerStub = fixture["grid_controller"]

	_seed_hero(&"shu_003", "Zhang Fei")
	_seed_battle_unit(grid, 7, &"shu_003")
	_seed_turn_state(runner, 7, 80)
	runner._queue = [7]
	runner._round_number = 1

	add_child(hud)
	await get_tree().process_frame

	# Pre-rebuild UI-GB-01 via round_started
	GameBus.round_started.emit(1)
	await get_tree().process_frame

	# Now trigger unit_turn_started for unit 7
	GameBus.unit_turn_started.emit(7)
	await get_tree().process_frame

	# UI-GB-07 turn_label updated
	var counter: Control = hud._ui_elements.get(&"UI-GB-07")
	var turn_label: Label = counter.get_node("TurnLabel") as Label
	assert_str(turn_label.text).contains("Zhang Fei")

	# UI-GB-01 slot[0] highlighted (modulate.a == 1.2)
	assert_int(hud._ui_gb_01_active_slot_index).is_equal(0)
	assert_float(hud._ui_gb_01_slots[0].modulate.a).is_equal_approx(1.2, 0.01)

	hud.free()
	_free_node_deps(fixture)


# ─── AC-4: unit_turn_ended clears highlight ──────────────────────────────────


func test_unit_turn_ended_clears_highlight() -> void:
	var fixture: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = fixture["hud"]
	var runner: TurnOrderRunnerStub = fixture["turn_runner"]
	var grid: GridBattleControllerStub = fixture["grid_controller"]

	_seed_hero(&"shu_003", "Zhang Fei")
	_seed_battle_unit(grid, 7, &"shu_003")
	_seed_turn_state(runner, 7, 80)
	runner._queue = [7]
	runner._round_number = 1

	add_child(hud)
	await get_tree().process_frame
	GameBus.round_started.emit(1)
	await get_tree().process_frame
	GameBus.unit_turn_started.emit(7)
	await get_tree().process_frame
	# Confirm highlight set
	assert_int(hud._ui_gb_01_active_slot_index).is_equal(0)

	# Now end the turn (acted=true → slot drops from highlight to acted-dim)
	GameBus.unit_turn_ended.emit(7, true)
	await get_tree().process_frame

	# Highlight cleared; slot now shows the acted-dim tier (mirrors the
	# polygon end-of-turn dim so the ribbon agrees with the grid).
	assert_int(hud._ui_gb_01_active_slot_index).is_equal(-1)
	assert_bool(hud._ui_gb_01_slot_acted[0]).is_true()
	assert_float(hud._ui_gb_01_slots[0].modulate.a).is_equal_approx(0.5, 0.01)

	hud.free()
	_free_node_deps(fixture)


# ─── AC-5: unit_died rebuilds UI-GB-01 ───────────────────────────────────────


func test_unit_died_rebuilds_initiative_queue() -> void:
	var fixture: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = fixture["hud"]
	var runner: TurnOrderRunnerStub = fixture["turn_runner"]
	var grid: GridBattleControllerStub = fixture["grid_controller"]

	_seed_hero(&"shu_001", "Liu Bei")
	_seed_hero(&"shu_003", "Zhang Fei")
	_seed_battle_unit(grid, 0, &"shu_001")
	_seed_battle_unit(grid, 1, &"shu_003")
	_seed_turn_state(runner, 0, 90)
	_seed_turn_state(runner, 1, 80)
	runner._queue = [0, 1]
	runner._round_number = 1

	add_child(hud)
	await get_tree().process_frame
	GameBus.round_started.emit(1)
	await get_tree().process_frame
	# Confirm 2 visible slots
	assert_int(hud._ui_gb_01_slot_unit_ids[0]).is_equal(0)
	assert_int(hud._ui_gb_01_slot_unit_ids[1]).is_equal(1)

	# Simulate unit 0 dying — remove from runner state + queue
	runner._unit_states.erase(0)
	runner._queue = [1]

	GameBus.unit_died.emit(0)
	await get_tree().process_frame

	# UI-GB-01 rebuilt — slot[0] now shows unit 1
	assert_int(hud._ui_gb_01_slot_unit_ids[0]).is_equal(1)
	assert_int(hud._ui_gb_01_slot_unit_ids[1]).is_equal(-1)
	assert_bool(hud._ui_gb_01_slots[0].visible).is_true()
	assert_bool(hud._ui_gb_01_slots[1].visible).is_false()

	hud.free()
	_free_node_deps(fixture)


# ─── AC-6: set_victory_condition() shows UI-GB-08 ─────────────────────────


func test_set_victory_condition_shows_panel_with_translated_text() -> void:
	var fixture: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = fixture["hud"]
	add_child(hud)
	await get_tree().process_frame

	var panel: Control = hud._ui_elements.get(&"UI-GB-08")
	assert_bool(panel.visible).is_false()  # starts hidden

	hud.set_victory_condition(&"victory.scenario_01.defeat_commander")
	await get_tree().process_frame

	assert_bool(panel.visible).is_true()
	var label: Label = panel.get_node("ConditionLabel") as Label
	# tr() returns the key itself if no locale entry — that's the expected behavior here
	assert_str(label.text).is_equal("victory.scenario_01.defeat_commander")

	# Repeated call replaces text + stays visible
	hud.set_victory_condition(&"victory.scenario_02.survive_5_rounds")
	await get_tree().process_frame
	assert_str(label.text).is_equal("victory.scenario_02.survive_5_rounds")
	assert_bool(panel.visible).is_true()

	hud.free()
	_free_node_deps(fixture)


# ─── Ribbon click → show_unit_info dispatch ────────────────────────────────


func test_initiative_slot_click_dispatches_show_unit_info() -> void:
	var fixture: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = fixture["hud"]
	var runner: TurnOrderRunnerStub = fixture["turn_runner"]
	var grid: GridBattleControllerStub = fixture["grid_controller"]

	_seed_hero(&"shu_003", "Zhang Fei")
	_seed_battle_unit(grid, 7, &"shu_003")
	_seed_turn_state(runner, 7, 80)
	runner._queue = [7]
	runner._round_number = 1

	add_child(hud)
	await get_tree().process_frame
	GameBus.round_started.emit(1)
	await get_tree().process_frame
	assert_int(hud._ui_gb_01_slot_unit_ids[0]).is_equal(7)

	# Synthesize LMB-press on slot[0] via gui_input emit (CR-4a-equivalent path
	# but driven by the slot's own input rather than InputRouter Tap Preview).
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	hud._ui_gb_01_slots[0].gui_input.emit(ev)
	await get_tree().process_frame

	assert_int(hud._active_status_panel_unit_id).override_failure_message(
		"Ribbon click on slot[0] (unit_id=7) must dispatch show_unit_info(7)"
	).is_equal(7)

	# Click again → toggles dismissal (matches _on_unit_selected_changed pattern).
	hud._ui_gb_01_slots[0].gui_input.emit(ev)
	await get_tree().process_frame
	assert_int(hud._active_status_panel_unit_id).override_failure_message(
		"Second click on the same slot must toggle dismissal via show_unit_info(-1)"
	).is_equal(-1)

	hud.free()
	_free_node_deps(fixture)


func test_initiative_slot_click_on_empty_slot_is_noop() -> void:
	var fixture: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = fixture["hud"]

	add_child(hud)
	await get_tree().process_frame
	# No round_started → slot_unit_ids stay at -1 sentinel

	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	hud._ui_gb_01_slots[3].gui_input.emit(ev)
	await get_tree().process_frame

	# Empty slot click must not crash + must not change panel state.
	assert_int(hud._active_status_panel_unit_id).override_failure_message(
		"Click on empty (unit_id=-1) slot must be a no-op"
	).is_equal(-1)

	hud.free()
	_free_node_deps(fixture)
