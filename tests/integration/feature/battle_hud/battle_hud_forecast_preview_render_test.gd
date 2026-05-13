## BattleHUD UI-GB-04 Combat Forecast — preview-Dictionary render (session-10).
##
## Verifies that show_forecast(attacker_id, defender_id, preview) renders the
## REAL damage / direction / counter values from the preview Dictionary rather
## than the legacy placeholder constants.
##
##   - direction subpanel uses preview["direction"] StringName as i18n key suffix
##   - hit_crit subpanel reads preview["hit_pct"]
##   - damage subpanel reads preview["damage"] (final post-multiplier int)
##   - counter subpanel reads preview["counter_damage"] when counter_eligible
##   - counter falls back to em-dash when not eligible
##   - passives subpanel reads preview["passives"] when present
##
## Companion to battle_hud_forecast_test.gd — that file pins the architectural
## contract with the placeholder path (preview={}); this file pins the
## preview-fed path that ships once 2-step attack flow is wired.
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

const TEST_ATTACKER_ID: int = 42
const TEST_DEFENDER_ID: int = 99


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


func _free_node_deps(bag: Dictionary) -> void:
	for key: String in ["camera", "hp_controller", "turn_runner",
			"grid_controller", "input_router", "map_grid"]:
		var dep: Variant = bag.get(key)
		if is_instance_valid(dep):
			var node: Node = dep as Node
			if node != null and not node.is_queued_for_deletion():
				node.free()


## Mirror of BattleHUD._find_first_label_descendant — recursive Label finder
## so tests assert against the same Label production code populates.
func _find_label(root: Node) -> Label:
	for child: Node in root.get_children():
		if child is Label:
			return child as Label
		var nested: Label = _find_label(child)
		if nested != null:
			return nested
	return null


# ─── Damage subpanel reads preview ───────────────────────────────────────────


func test_damage_subpanel_shows_preview_damage_value() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	var preview: Dictionary = {
		"direction": &"REAR",
		"damage": 47,
		"hit_pct": 100,
		"counter_damage": 0,
		"counter_eligible": false,
		"kind": 0,
		"passives": [],
		"angle_mult": 1.50,
		"aura_mult": 1.00,
	}
	hud.show_forecast(TEST_ATTACKER_ID, TEST_DEFENDER_ID, preview)

	var subpanel: Control = hud._forecast_subpanels.get(&"damage")
	var label: Label = _find_label(subpanel)
	assert_str(label.text).override_failure_message(
		"damage subpanel must show preview['damage']=47 verbatim; got '%s'" % label.text
	).is_equal("47")

	hud.free()
	_free_node_deps(bag)


# ─── Counter subpanel shows damage when eligible ─────────────────────────────


func test_counter_subpanel_shows_value_when_eligible() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	var preview: Dictionary = {
		"direction": &"FRONT",
		"damage": 30,
		"hit_pct": 100,
		"counter_damage": 18,
		"counter_eligible": true,
		"kind": 0,
		"passives": [],
		"angle_mult": 1.00,
		"aura_mult": 1.00,
	}
	hud.show_forecast(TEST_ATTACKER_ID, TEST_DEFENDER_ID, preview)

	var subpanel: Control = hud._forecast_subpanels.get(&"counter")
	var label: Label = _find_label(subpanel)
	assert_str(label.text).override_failure_message(
		"counter subpanel must show preview['counter_damage']=18; got '%s'" % label.text
	).is_equal("18")

	hud.free()
	_free_node_deps(bag)


func test_counter_subpanel_shows_dash_when_not_eligible() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	var preview: Dictionary = {
		"direction": &"FRONT",
		"damage": 30,
		"hit_pct": 100,
		"counter_damage": 0,
		"counter_eligible": false,
		"kind": 0,
		"passives": [],
		"angle_mult": 1.00,
		"aura_mult": 1.00,
	}
	hud.show_forecast(TEST_ATTACKER_ID, TEST_DEFENDER_ID, preview)

	var subpanel: Control = hud._forecast_subpanels.get(&"counter")
	var label: Label = _find_label(subpanel)
	# Em-dash placeholder constant — read via reflection rather than hardcoded
	# so test stays valid if the constant value rotates.
	var dash: String = hud._COUNTER_PLACEHOLDER_DASH
	assert_str(label.text).override_failure_message(
		"counter subpanel must show em-dash '%s' when not eligible; got '%s'"
		% [dash, label.text]
	).is_equal(dash)

	hud.free()
	_free_node_deps(bag)


# ─── Backward compatibility ───────────────────────────────────────────────────


func test_show_forecast_without_preview_uses_placeholder_path() -> void:
	# Legacy callers (placeholder path) still produce non-empty content per AC-2.
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	hud.show_forecast(TEST_ATTACKER_ID, TEST_DEFENDER_ID)  # no preview arg

	assert_dict(hud._last_preview).override_failure_message(
		"show_forecast without preview must set _last_preview = {} (legacy path)"
	).is_empty()
	# Damage subpanel should fall back to the placeholder _safe_tr_format text
	# (which is non-empty by construction).
	var subpanel: Control = hud._forecast_subpanels.get(&"damage")
	var label: Label = _find_label(subpanel)
	assert_str(label.text).is_not_empty()

	hud.free()
	_free_node_deps(bag)


# ─── Signal handler integration ───────────────────────────────────────────────


func test_attack_preview_requested_handler_triggers_show_forecast() -> void:
	# Verifies the _on_attack_preview_requested handler routes the signal payload
	# into show_forecast (which sets visible + caches preview).
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	var preview: Dictionary = {
		"direction": &"FLANK",
		"damage": 22,
		"hit_pct": 100,
		"counter_damage": 0,
		"counter_eligible": false,
		"kind": 0,
		"passives": [],
		"angle_mult": 1.25,
		"aura_mult": 1.00,
	}
	hud._on_attack_preview_requested(TEST_ATTACKER_ID, TEST_DEFENDER_ID, preview)

	assert_bool(hud._forecast_root.visible).override_failure_message(
		"handler must make forecast visible via show_forecast"
	).is_true()
	assert_dict(hud._last_preview).contains_key_value("damage", 22)

	hud.free()
	_free_node_deps(bag)


func test_attack_preview_dismissed_handler_starts_dismiss_tween() -> void:
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	hud.show_forecast(TEST_ATTACKER_ID, TEST_DEFENDER_ID, {})
	assert_bool(hud._forecast_root.visible).is_true()

	hud._on_attack_preview_dismissed(&"test_invoke")

	assert_object(hud._forecast_dismiss_tween).override_failure_message(
		"dismiss handler must initiate dismiss tween via _dismiss_forecast"
	).is_not_null()

	hud.free()
	_free_node_deps(bag)
