## BattleHUD UI-GB-03 Unit Info Panel + UI-GB-11 DEFEND Seal integration test.
##
## Story-003 — covers AC-1..AC-7 (automated state-transition tests).
## AC-8 (AccessKit on macOS VoiceOver) and AC-9 (i18n grep gate) are MANUAL —
## documented at /story-done time in `production/qa/evidence/battle-hud-story-003-evidence.md`
## (AC-8) and automated by story-008 Lint 5 (AC-9).
##
## Tests use:
##   - `before_test()` for HeroDatabase static-state reset (per file header obligation)
##   - GridBattleControllerStub.set_test_unit() + HPStatusControllerStub setters
##     (test injection seams added in story-003)
##
## ADR: ADR-0015 §4 + §5 + Engine Verification Item 2 (AccessKit deferred manual)
## TR: TR-battle-hud-005, -006, -012, -016
##
## Gotchas referenced (per `.claude/rules/godot-4x-gotchas.md`):
##   G-15: before_test (NOT before_each)
##   G-6: explicit free at end of body for Node-typed deps
##   G-22: HeroDatabase is @abstract — direct .new() blocks at parse-time on
##         typed references; HeroDatabaseStub provides DI binding (instance has
##         no behavior — production methods are all-static)

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

const TEST_UNIT_ID: int = 42
const TEST_OTHER_UNIT_ID: int = 99
const TEST_HERO_ID: StringName = &"shu_001_wei_yan"
const TEST_HERO_NAME_KO: String = "Wei Yan"

# Deterministic field values for AC-3 happy-path assertions on Class/ATK/DEF/Facing
# labels. unit_class=0 → CAVALRY (UnitRole.UnitClass.CAVALRY); facing=1 → E.
const TEST_UNIT_CLASS_CAVALRY: int = 0
const TEST_UNIT_RAW_ATK: int = 17
const TEST_UNIT_RAW_DEF: int = 9
const TEST_UNIT_FACING_E: int = 1


func before_test() -> void:
	# G-15 + hero_database.gd line 4-7 obligation: every test that calls any
	# HeroDatabase static method MUST reset _heroes_loaded + _heroes.
	HeroDatabase._heroes_loaded = false
	HeroDatabase._heroes = {}


func after_test() -> void:
	# Idempotent crash-safety net per G-6 — actual cleanup happens in test bodies.
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


func _make_battle_unit(unit_id: int, hero_id: StringName) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.hero_id = hero_id
	unit.is_player_controlled = true
	unit.unit_class = TEST_UNIT_CLASS_CAVALRY
	unit.raw_atk = TEST_UNIT_RAW_ATK
	unit.raw_def = TEST_UNIT_RAW_DEF
	unit.facing = TEST_UNIT_FACING_E
	return unit


func _make_hero_data(hero_id: StringName, name_ko: String) -> HeroData:
	var hero: HeroData = HeroData.new()
	hero.hero_id = hero_id
	hero.name_ko = name_ko
	return hero


func _make_status_effect(effect_id: StringName, remaining_turns: int) -> StatusEffect:
	var effect: StatusEffect = StatusEffect.new()
	effect.effect_id = effect_id
	effect.remaining_turns = remaining_turns
	return effect


# ─── AC-1: UI-GB-03 mounts at _ready ──────────────────────────────────────────

func test_ui_gb_03_panel_mounts_hidden_at_ready() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	var panel: Control = hud._ui_elements.get(&"UI-GB-03")
	assert_object(panel).override_failure_message(
		"AC-1: _ui_elements[&\"UI-GB-03\"] must be non-null after _ready"
	).is_not_null()
	assert_object(panel.get_parent()).is_equal(hud)
	assert_bool(panel.visible).override_failure_message(
		"AC-1: UI-GB-03 must start hidden (visible == false)"
	).is_false()

	hud.free()
	_free_node_deps(bag)


# ─── AC-2: UI-GB-11 DEFEND seal mounts at _ready ──────────────────────────────

func test_ui_gb_11_defend_seal_mounts_hidden_at_ready() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	var seal: Control = hud._ui_elements.get(&"UI-GB-11")
	assert_object(seal).override_failure_message(
		"AC-2: _ui_elements[&\"UI-GB-11\"] must be non-null after _ready"
	).is_not_null()
	assert_object(seal.get_parent()).is_equal(hud)
	assert_bool(seal.visible).is_false()

	hud.free()
	_free_node_deps(bag)


# ─── AC-3: show_unit_info() populates from backends ───────────────────────────

func test_show_unit_info_populates_panel_from_backends() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid_controller: GridBattleControllerStub = bag["grid_controller"]
	var hp_controller: HPStatusControllerStub = bag["hp_controller"]
	add_child(hud)

	# Inject test data into stubs + HeroDatabase static state
	grid_controller.set_test_unit(TEST_UNIT_ID, _make_battle_unit(TEST_UNIT_ID, TEST_HERO_ID))
	hp_controller.set_test_current_hp(TEST_UNIT_ID, 80)
	hp_controller.set_test_max_hp(TEST_UNIT_ID, 120)
	hp_controller.set_test_status_effects(TEST_UNIT_ID,
			[_make_status_effect(&"defend_stance", 1)])
	HeroDatabase._heroes[TEST_HERO_ID] = _make_hero_data(TEST_HERO_ID, TEST_HERO_NAME_KO)
	# Option B (IN-N): set _heroes_loaded = true after direct injection so
	# HeroDatabase.get_hero() short-circuits _load_heroes() file I/O in headless mode.
	HeroDatabase._heroes_loaded = true

	hud.show_unit_info(TEST_UNIT_ID)

	var panel: Control = hud._ui_elements.get(&"UI-GB-03")
	assert_bool(panel.visible).override_failure_message(
		"AC-3: UI-GB-03 must be visible after show_unit_info"
	).is_true()
	assert_int(hud._active_status_panel_unit_id).is_equal(TEST_UNIT_ID)

	var name_label: Label = panel.get_node_or_null(^"UnitNameLabel") as Label
	assert_str(name_label.text).is_equal(TEST_HERO_NAME_KO)

	var hp_bar: TextureProgressBar = panel.get_node_or_null(^"HPBar") as TextureProgressBar
	assert_float(hp_bar.value).is_equal_approx(80.0, 0.01)
	assert_float(hp_bar.max_value).is_equal_approx(120.0, 0.01)

	var effects_box: HBoxContainer = panel.get_node_or_null(^"StatusEffectsHBox") as HBoxContainer
	assert_int(effects_box.get_child_count()).override_failure_message(
		"AC-3: StatusEffectsHBox must have 1 child after defend_stance injected"
	).is_equal(1)

	# AC-3: ClassLabel populated via _class_to_i18n_key(unit_class=0 → CAVALRY).
	# tr() with no locale loaded returns the key verbatim — assertion locks the
	# exact format string + literal i18n keys produced by show_unit_info().
	var class_label: Label = panel.get_node_or_null(^"ClassLabel") as Label
	assert_str(class_label.text).override_failure_message(
		"AC-3: ClassLabel must format '<class_label>: <class.cavalry>' via tr() literal keys"
	).is_equal("hud.unit_info.class_label: hud.unit_info.class.cavalry")

	# AC-3: ATKLabel populated with battle_unit.raw_atk.
	var atk_label: Label = panel.get_node_or_null(^"ATKLabel") as Label
	assert_str(atk_label.text).override_failure_message(
		"AC-3: ATKLabel must format '<atk_label> <raw_atk>' (got '%s')" % atk_label.text
	).is_equal("hud.unit_info.atk_label %d" % TEST_UNIT_RAW_ATK)

	# AC-3: DEFLabel populated with battle_unit.raw_def.
	var def_label: Label = panel.get_node_or_null(^"DEFLabel") as Label
	assert_str(def_label.text).override_failure_message(
		"AC-3: DEFLabel must format '<def_label> <raw_def>' (got '%s')" % def_label.text
	).is_equal("hud.unit_info.def_label %d" % TEST_UNIT_RAW_DEF)

	# AC-3: FacingDirectionLabel populated via _facing_to_i18n_key(facing=1 → E).
	var facing_label: Label = panel.get_node_or_null(^"FacingDirectionLabel") as Label
	assert_str(facing_label.text).override_failure_message(
		"AC-3: FacingDirectionLabel must format '<facing_label>: <facing.e>'"
	).is_equal("hud.unit_info.facing_label: hud.unit_info.facing.e")

	# UI-GB-11 should be visible because defend_stance is in status effects
	var seal: Control = hud._ui_elements.get(&"UI-GB-11")
	assert_bool(seal.visible).override_failure_message(
		"AC-3: UI-GB-11 must be visible when defend_stance is active"
	).is_true()

	hud.free()
	_free_node_deps(bag)


func test_show_unit_info_unknown_hero_renders_localized_placeholder() -> void:
	# Edge case: HeroDatabase.get_hero returns null → fallback to tr() placeholder.
	# Godot's tr() returns the key string when no locale table loaded — that's
	# the fallback behavior under test.
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid_controller: GridBattleControllerStub = bag["grid_controller"]
	var hp_controller: HPStatusControllerStub = bag["hp_controller"]
	add_child(hud)

	# BattleUnit exists but no HeroData injected → get_hero returns null
	grid_controller.set_test_unit(TEST_UNIT_ID, _make_battle_unit(TEST_UNIT_ID, &"unknown_999_ghost"))
	hp_controller.set_test_current_hp(TEST_UNIT_ID, 50)
	hp_controller.set_test_max_hp(TEST_UNIT_ID, 100)

	hud.show_unit_info(TEST_UNIT_ID)

	var panel: Control = hud._ui_elements.get(&"UI-GB-03")
	assert_bool(panel.visible).is_true()
	var name_label: Label = panel.get_node_or_null(^"UnitNameLabel") as Label
	# Per Godot 4.x tr() semantics with no locale loaded: returns the key string
	# verbatim. Asserting against the exact key locks the fallback path —
	# previously a length()>0 check passed for any non-empty text and would have
	# missed accidental population from a different code path.
	assert_str(name_label.text).override_failure_message(
		"AC-3 edge: unknown hero must route through tr(&\"hud.unit_info.unknown_unit\") fallback; got '%s'" % name_label.text
	).is_equal("hud.unit_info.unknown_unit")

	hud.free()
	_free_node_deps(bag)


# ─── AC-4: show_unit_info(-1) dismisses panel ─────────────────────────────────

func test_show_unit_info_minus_one_dismisses_panel() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid_controller: GridBattleControllerStub = bag["grid_controller"]
	var hp_controller: HPStatusControllerStub = bag["hp_controller"]
	add_child(hud)

	# Setup: panel is visible for TEST_UNIT_ID
	grid_controller.set_test_unit(TEST_UNIT_ID, _make_battle_unit(TEST_UNIT_ID, TEST_HERO_ID))
	hp_controller.set_test_current_hp(TEST_UNIT_ID, 80)
	hp_controller.set_test_max_hp(TEST_UNIT_ID, 120)
	HeroDatabase._heroes[TEST_HERO_ID] = _make_hero_data(TEST_HERO_ID, TEST_HERO_NAME_KO)
	HeroDatabase._heroes_loaded = true
	hud.show_unit_info(TEST_UNIT_ID)
	assert_int(hud._active_status_panel_unit_id).is_equal(TEST_UNIT_ID)

	hud.show_unit_info(-1)

	var panel: Control = hud._ui_elements.get(&"UI-GB-03")
	assert_bool(panel.visible).override_failure_message(
		"AC-4: UI-GB-03 must be hidden after show_unit_info(-1)"
	).is_false()
	assert_int(hud._active_status_panel_unit_id).is_equal(-1)

	# Edge case: dismiss when already hidden → no-op no error
	hud.show_unit_info(-1)
	assert_int(hud._active_status_panel_unit_id).is_equal(-1)

	hud.free()
	_free_node_deps(bag)


# ─── AC-5: unit_selected_changed routes through show_unit_info ────────────────

func test_unit_selected_changed_true_routes_to_show_unit_info() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid_controller: GridBattleControllerStub = bag["grid_controller"]
	var hp_controller: HPStatusControllerStub = bag["hp_controller"]
	add_child(hud)

	grid_controller.set_test_unit(TEST_UNIT_ID, _make_battle_unit(TEST_UNIT_ID, TEST_HERO_ID))
	hp_controller.set_test_current_hp(TEST_UNIT_ID, 80)
	hp_controller.set_test_max_hp(TEST_UNIT_ID, 120)
	HeroDatabase._heroes[TEST_HERO_ID] = _make_hero_data(TEST_HERO_ID, TEST_HERO_NAME_KO)
	HeroDatabase._heroes_loaded = true

	# Emit controller-LOCAL signal (CONNECT_DEFERRED so flush via process_frame).
	grid_controller.unit_selected_changed.emit(TEST_UNIT_ID, 1)
	await get_tree().process_frame

	var panel: Control = hud._ui_elements.get(&"UI-GB-03")
	assert_bool(panel.visible).override_failure_message(
		"AC-5: UI-GB-03 must be visible after unit_selected_changed(unit, 1) flush"
	).is_true()
	assert_int(hud._active_status_panel_unit_id).is_equal(TEST_UNIT_ID)

	# Inverse: was_selected == 0 for the active panel unit → dismisses
	grid_controller.unit_selected_changed.emit(TEST_UNIT_ID, 0)
	await get_tree().process_frame

	assert_bool(panel.visible).override_failure_message(
		"AC-5: UI-GB-03 must be hidden after unit_selected_changed(unit, 0) for active unit"
	).is_false()
	assert_int(hud._active_status_panel_unit_id).is_equal(-1)

	hud.free()
	_free_node_deps(bag)


# ─── AC-6: damage_applied refreshes HP bar for active panel unit ──────────────

func test_damage_applied_refreshes_hp_bar_when_defender_is_active_panel_unit() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid_controller: GridBattleControllerStub = bag["grid_controller"]
	var hp_controller: HPStatusControllerStub = bag["hp_controller"]
	add_child(hud)

	# Setup: panel visible for TEST_UNIT_ID with HP=80/120
	grid_controller.set_test_unit(TEST_UNIT_ID, _make_battle_unit(TEST_UNIT_ID, TEST_HERO_ID))
	hp_controller.set_test_current_hp(TEST_UNIT_ID, 80)
	hp_controller.set_test_max_hp(TEST_UNIT_ID, 120)
	HeroDatabase._heroes[TEST_HERO_ID] = _make_hero_data(TEST_HERO_ID, TEST_HERO_NAME_KO)
	HeroDatabase._heroes_loaded = true
	hud.show_unit_info(TEST_UNIT_ID)

	# Mutate HP via stub setter; emit damage_applied with TEST_UNIT_ID as defender
	hp_controller.set_test_current_hp(TEST_UNIT_ID, 50)
	grid_controller.damage_applied.emit(7, TEST_UNIT_ID, 30)
	await get_tree().process_frame

	var panel: Control = hud._ui_elements.get(&"UI-GB-03")
	var hp_bar: TextureProgressBar = panel.get_node_or_null(^"HPBar") as TextureProgressBar
	assert_float(hp_bar.value).override_failure_message(
		"AC-6: HP bar must reflect current_hp=50 after damage_applied to active panel unit"
	).is_equal_approx(50.0, 0.01)

	hud.free()
	_free_node_deps(bag)


func test_damage_applied_to_other_unit_does_not_refresh_hp_bar() -> void:
	# Edge case: damage to a non-active-panel unit must NOT mutate HP bar.
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid_controller: GridBattleControllerStub = bag["grid_controller"]
	var hp_controller: HPStatusControllerStub = bag["hp_controller"]
	add_child(hud)

	grid_controller.set_test_unit(TEST_UNIT_ID, _make_battle_unit(TEST_UNIT_ID, TEST_HERO_ID))
	hp_controller.set_test_current_hp(TEST_UNIT_ID, 80)
	hp_controller.set_test_max_hp(TEST_UNIT_ID, 120)
	HeroDatabase._heroes[TEST_HERO_ID] = _make_hero_data(TEST_HERO_ID, TEST_HERO_NAME_KO)
	HeroDatabase._heroes_loaded = true
	hud.show_unit_info(TEST_UNIT_ID)

	# Pretend OTHER_UNIT_ID also took damage; HP for active unit unchanged.
	hp_controller.set_test_current_hp(TEST_UNIT_ID, 80)  # unchanged
	hp_controller.set_test_current_hp(TEST_OTHER_UNIT_ID, 10)
	grid_controller.damage_applied.emit(7, TEST_OTHER_UNIT_ID, 30)
	await get_tree().process_frame

	var panel: Control = hud._ui_elements.get(&"UI-GB-03")
	var hp_bar: TextureProgressBar = panel.get_node_or_null(^"HPBar") as TextureProgressBar
	assert_float(hp_bar.value).override_failure_message(
		"AC-6 edge: HP bar must remain at 80 when damage_applied targets non-active unit"
	).is_equal_approx(80.0, 0.01)

	hud.free()
	_free_node_deps(bag)


# ─── AC-7: unit_turn_started refreshes UI-GB-03 + expires UI-GB-11 ────────────

func test_unit_turn_started_expires_defend_stance_seal() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid_controller: GridBattleControllerStub = bag["grid_controller"]
	var hp_controller: HPStatusControllerStub = bag["hp_controller"]
	add_child(hud)

	# Setup: panel + DEFEND_STANCE seal visible
	grid_controller.set_test_unit(TEST_UNIT_ID, _make_battle_unit(TEST_UNIT_ID, TEST_HERO_ID))
	hp_controller.set_test_current_hp(TEST_UNIT_ID, 80)
	hp_controller.set_test_max_hp(TEST_UNIT_ID, 120)
	hp_controller.set_test_status_effects(TEST_UNIT_ID,
			[_make_status_effect(&"defend_stance", 1)])
	HeroDatabase._heroes[TEST_HERO_ID] = _make_hero_data(TEST_HERO_ID, TEST_HERO_NAME_KO)
	HeroDatabase._heroes_loaded = true
	hud.show_unit_info(TEST_UNIT_ID)

	var seal: Control = hud._ui_elements.get(&"UI-GB-11")
	assert_bool(seal.visible).is_true()  # pre-condition

	# Simulate DEFEND_STANCE expiring (TurnOrderRunner ticks it before unit_turn_started)
	hp_controller.set_test_status_effects(TEST_UNIT_ID, [])
	GameBus.unit_turn_started.emit(TEST_UNIT_ID)
	await get_tree().process_frame

	assert_bool(seal.visible).override_failure_message(
		"AC-7: UI-GB-11 DEFEND seal must hide after unit_turn_started + status effects empty"
	).is_false()

	# UI-GB-03 status effects HBox should also be empty now
	var panel: Control = hud._ui_elements.get(&"UI-GB-03")
	var effects_box: HBoxContainer = panel.get_node_or_null(^"StatusEffectsHBox") as HBoxContainer
	# queue_free is deferred; await one more frame to let removal complete
	await get_tree().process_frame
	assert_int(effects_box.get_child_count()).override_failure_message(
		"AC-7: StatusEffectsHBox must be empty after defend_stance expiry"
	).is_equal(0)

	hud.free()
	_free_node_deps(bag)


func test_unit_turn_started_for_other_unit_does_not_refresh() -> void:
	# Edge case: turn_started for non-active-panel unit leaves panel state unchanged.
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid_controller: GridBattleControllerStub = bag["grid_controller"]
	var hp_controller: HPStatusControllerStub = bag["hp_controller"]
	add_child(hud)

	grid_controller.set_test_unit(TEST_UNIT_ID, _make_battle_unit(TEST_UNIT_ID, TEST_HERO_ID))
	hp_controller.set_test_current_hp(TEST_UNIT_ID, 80)
	hp_controller.set_test_max_hp(TEST_UNIT_ID, 120)
	hp_controller.set_test_status_effects(TEST_UNIT_ID,
			[_make_status_effect(&"defend_stance", 1)])
	HeroDatabase._heroes[TEST_HERO_ID] = _make_hero_data(TEST_HERO_ID, TEST_HERO_NAME_KO)
	HeroDatabase._heroes_loaded = true
	hud.show_unit_info(TEST_UNIT_ID)

	# Different unit's turn starts; panel unchanged
	GameBus.unit_turn_started.emit(TEST_OTHER_UNIT_ID)
	await get_tree().process_frame

	var seal: Control = hud._ui_elements.get(&"UI-GB-11")
	assert_bool(seal.visible).override_failure_message(
		"AC-7 edge: UI-GB-11 must remain visible when other unit's turn starts"
	).is_true()
	assert_int(hud._active_status_panel_unit_id).is_equal(TEST_UNIT_ID)

	hud.free()
	_free_node_deps(bag)


# ─── Bonus: unit_died defensively clears _active_status_panel_unit_id ─────────

func test_unit_died_for_active_panel_unit_clears_state() -> void:
	# Defensive cleanup: if active panel unit dies, sentinel resets.
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid_controller: GridBattleControllerStub = bag["grid_controller"]
	var hp_controller: HPStatusControllerStub = bag["hp_controller"]
	add_child(hud)

	grid_controller.set_test_unit(TEST_UNIT_ID, _make_battle_unit(TEST_UNIT_ID, TEST_HERO_ID))
	hp_controller.set_test_current_hp(TEST_UNIT_ID, 80)
	hp_controller.set_test_max_hp(TEST_UNIT_ID, 120)
	HeroDatabase._heroes[TEST_HERO_ID] = _make_hero_data(TEST_HERO_ID, TEST_HERO_NAME_KO)
	HeroDatabase._heroes_loaded = true
	hud.show_unit_info(TEST_UNIT_ID)
	assert_int(hud._active_status_panel_unit_id).is_equal(TEST_UNIT_ID)

	GameBus.unit_died.emit(TEST_UNIT_ID)
	await get_tree().process_frame

	assert_int(hud._active_status_panel_unit_id).override_failure_message(
		"unit_died for active panel unit must reset _active_status_panel_unit_id to -1"
	).is_equal(-1)

	hud.free()
	_free_node_deps(bag)
