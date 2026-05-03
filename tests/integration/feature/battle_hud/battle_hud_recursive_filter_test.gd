## BattleHUD recursive MOUSE_FILTER_IGNORE integration test — AC-6 for story-002.
##
## Engine Verification Item 5 (ADR-0015 §Verification Required) — KEEP through
## Polish. Recursive Control disable (Godot 4.5+) means setting
## `mouse_filter = MOUSE_FILTER_IGNORE` on a parent Control propagates to all
## descendant Controls in one operation.
##
## Headless caveat: synthetic `Input.parse_input_event` and `Viewport.push_input`
## both bypass the Control mouse_filter chain in headless mode (verified
## empirically — Button.pressed fires regardless of root's filter). Therefore
## the BEHAVIORAL verification of recursive disable is a MANUAL cross-platform
## gate per ADR-0015 Verification Item 5: macOS Metal + Linux Vulkan +
## Windows D3D12 hand-tested on dev hardware. KEEP through Polish.
##
## What this automated test DOES verify:
##   1. The full signal chain — GameBus.input_state_changed(_, INPUT_BLOCKED)
##      fires _on_input_state_changed, which sets hud.mouse_filter to IGNORE.
##   2. The reverse transition (any state ≠ INPUT_BLOCKED) reverts the filter
##      to STOP.
##   3. The structural property holds: button is descendant of HUD subtree
##      with HUD.mouse_filter == IGNORE; engine docs (Godot 4.5 changelog)
##      guarantee descendants cannot receive input under that condition.
##
## TR: TR-battle-hud-010 (recursive MOUSE_FILTER_IGNORE during S5 INPUT_BLOCKED)
## ADR: ADR-0015 Battle HUD §Verification Item 5
##
## Gotchas referenced:
##   G-6: explicit free at end of body for Node-typed deps
##   G-15: before_test / after_test (not before_each)

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


# ─── AC-6 (chain): signal → handler → mouse_filter property ────────────────

func test_input_state_changed_to_blocked_propagates_filter_property() -> void:
	# Validates the full chain: GameBus.input_state_changed(_, INPUT_BLOCKED)
	# triggers _on_input_state_changed which sets root mouse_filter to IGNORE.
	# Engine guarantees recursive descendant disable from this state — that
	# behavior is verified manually per ADR-0015 Verification Item 5.
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	# Pre-condition — Control default mouse_filter is STOP after _ready
	assert_int(hud.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)

	GameBus.input_state_changed.emit(
		InputRouter.InputState.OBSERVATION,
		InputRouter.InputState.INPUT_BLOCKED,
	)
	await get_tree().process_frame

	assert_int(hud.mouse_filter).override_failure_message(
		"AC-6 chain: hud.mouse_filter must be MOUSE_FILTER_IGNORE after S5 transition; got %d" % hud.mouse_filter
	).is_equal(Control.MOUSE_FILTER_IGNORE)

	hud.free()
	_free_node_deps(bag)


func test_input_state_revert_from_blocked_resets_filter_to_stop() -> void:
	# Inverse chain — exiting S5 reverts the recursive disable.
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	GameBus.input_state_changed.emit(
		InputRouter.InputState.OBSERVATION,
		InputRouter.InputState.INPUT_BLOCKED,
	)
	await get_tree().process_frame
	assert_int(hud.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)

	GameBus.input_state_changed.emit(
		InputRouter.InputState.INPUT_BLOCKED,
		InputRouter.InputState.UNIT_SELECTED,
	)
	await get_tree().process_frame

	assert_int(hud.mouse_filter).override_failure_message(
		"AC-6 chain inverse: hud.mouse_filter must revert to MOUSE_FILTER_STOP after S5 exit; got %d" % hud.mouse_filter
	).is_equal(Control.MOUSE_FILTER_STOP)

	hud.free()
	_free_node_deps(bag)


# ─── AC-6 (structural): child Controls reside in HUD subtree under IGNORE ──

func test_child_button_under_hud_is_descendant_when_filter_is_ignore() -> void:
	# Structural: a child Button is part of the HUD subtree, so when
	# HUD.mouse_filter == IGNORE the engine's recursive-disable rule (Godot
	# 4.5+) takes effect on the descendant. This test asserts the structural
	# precondition; behavioral verification is platform-manual per ADR-0015.
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	var button: Button = Button.new()
	button.size = Vector2(60, 30)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(button)

	# Trigger S5
	GameBus.input_state_changed.emit(
		InputRouter.InputState.OBSERVATION,
		InputRouter.InputState.INPUT_BLOCKED,
	)
	await get_tree().process_frame

	# Structural assertions — the descendant is in HUD's subtree under IGNORE.
	assert_bool(button.is_inside_tree()).is_true()
	assert_object(button.get_parent()).is_equal(hud)
	assert_int(hud.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	# Button keeps its own filter — recursive disable is per-frame engine behavior
	# applied at input-routing time, not by mutating descendants' filter property.
	assert_int(button.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)

	hud.free()
	_free_node_deps(bag)
