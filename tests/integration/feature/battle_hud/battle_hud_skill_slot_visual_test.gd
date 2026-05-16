## BattleHUD UI-GB-05 SkillSlot0Button visual state test — session 25.
##
## Covers `_refresh_skill_slot_visual(unit_id)` 3-state taxonomy:
##   - READY (Color(1.0, 0.55, 0.55)) when can_use_skill(unit_id) == true
##   - USED  (Color(0.55, 0.55, 0.55)) when unit.skill_used == true
##   - DEFAULT (Color.WHITE) for all other cases (no skill / null unit / wrong
##     side / battle_over / non-active-turn / missing controller methods)
##
## Plus the 3 hook-point integrations:
##   - _on_use_skill_button_pressed refreshes right before showing the panel
##   - _on_unit_turn_started refreshes at turn-start
##   - _on_unit_skill_used_refresh refreshes after a skill fires
##
## ADR / source: ADR-0015 (HUD architecture), grid_battle_controller.can_use_skill
## (session 20), session-24 _refresh_action_buttons pattern (mirrored here).
##
## Gotchas applied (per `.claude/rules/godot-4x-gotchas.md`):
##   G-15: before_test (NOT before_each)
##   G-6:  explicit free at end of body for Node-typed deps

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

# Mirrored from battle_hud.gd session-25 constants — keep in sync.
const COLOR_READY: Color = Color(1.0, 0.55, 0.55)
const COLOR_USED: Color = Color(0.55, 0.55, 0.55)


func before_test() -> void:
	HeroDatabase._heroes_loaded = false
	HeroDatabase._heroes = {}


func after_test() -> void:
	HeroDatabase._heroes_loaded = false
	HeroDatabase._heroes = {}


# ─── Fixture builders ────────────────────────────────────────────────────────


func _make_hud() -> Dictionary:
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


func _make_unit(skill_id: StringName, skill_used: bool, side: int = 0) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = TEST_UNIT_ID
	unit.side = side
	unit.is_player_controlled = (side == 0)
	unit.skill_id = skill_id
	unit.skill_used = skill_used
	return unit


# ─── State matrix: READY ───────────────────────────────────────────────────────


## READY — skill wired, not used, active turn → red modulate.
func test_skill_slot_visual_ready_when_can_use_skill_true() -> void:
	var bag: Dictionary = _make_hud()
	var hud: BattleHUD = bag["hud"]
	var grid: GridBattleControllerStub = bag["grid_controller"]
	add_child(hud)
	grid.set_test_unit(TEST_UNIT_ID, _make_unit(&"dragon_blade", false))
	grid.set_test_active_turn_unit_id(TEST_UNIT_ID)

	hud._refresh_skill_slot_visual(TEST_UNIT_ID)

	assert_object(hud._btn_skill_slot_0.modulate).override_failure_message(
		"READY: modulate must be Color(1.0, 0.55, 0.55) red tint when can_use_skill=true, got %s"
				% str(hud._btn_skill_slot_0.modulate)
	).is_equal(COLOR_READY)

	hud.free()
	_free_node_deps(bag)


# ─── State matrix: USED ────────────────────────────────────────────────────────


## USED — skill_used==true → grey modulate (precedes READY check).
func test_skill_slot_visual_used_when_skill_used_flag_true() -> void:
	var bag: Dictionary = _make_hud()
	var hud: BattleHUD = bag["hud"]
	var grid: GridBattleControllerStub = bag["grid_controller"]
	add_child(hud)
	grid.set_test_unit(TEST_UNIT_ID, _make_unit(&"dragon_blade", true))
	grid.set_test_active_turn_unit_id(TEST_UNIT_ID)

	hud._refresh_skill_slot_visual(TEST_UNIT_ID)

	assert_object(hud._btn_skill_slot_0.modulate).override_failure_message(
		"USED: modulate must be Color(0.55, 0.55, 0.55) grey when skill_used=true, got %s"
				% str(hud._btn_skill_slot_0.modulate)
	).is_equal(COLOR_USED)

	hud.free()
	_free_node_deps(bag)


# ─── State matrix: DEFAULT fallbacks ───────────────────────────────────────────


## DEFAULT — unit has no skill_id wired → white modulate.
func test_skill_slot_visual_default_when_no_skill_wired() -> void:
	var bag: Dictionary = _make_hud()
	var hud: BattleHUD = bag["hud"]
	var grid: GridBattleControllerStub = bag["grid_controller"]
	add_child(hud)
	grid.set_test_unit(TEST_UNIT_ID, _make_unit(&"", false))
	grid.set_test_active_turn_unit_id(TEST_UNIT_ID)

	hud._refresh_skill_slot_visual(TEST_UNIT_ID)

	assert_object(hud._btn_skill_slot_0.modulate).override_failure_message(
		"DEFAULT: modulate must be Color.WHITE when skill_id is empty, got %s"
				% str(hud._btn_skill_slot_0.modulate)
	).is_equal(Color.WHITE)

	hud.free()
	_free_node_deps(bag)


## DEFAULT — unit is AI side (side != 0) → can_use_skill=false but skill_used=false
## → falls through to white (not red, not grey).
func test_skill_slot_visual_default_for_ai_unit() -> void:
	var bag: Dictionary = _make_hud()
	var hud: BattleHUD = bag["hud"]
	var grid: GridBattleControllerStub = bag["grid_controller"]
	add_child(hud)
	grid.set_test_unit(TEST_UNIT_ID, _make_unit(&"dragon_blade", false, 1))
	grid.set_test_active_turn_unit_id(TEST_UNIT_ID)

	hud._refresh_skill_slot_visual(TEST_UNIT_ID)

	assert_object(hud._btn_skill_slot_0.modulate).override_failure_message(
		"DEFAULT: modulate must be Color.WHITE for AI-side unit, got %s"
				% str(hud._btn_skill_slot_0.modulate)
	).is_equal(Color.WHITE)

	hud.free()
	_free_node_deps(bag)


## DEFAULT — battle_over==true → can_use_skill returns false, skill_used still
## false → white (battle ended, no point lighting up).
func test_skill_slot_visual_default_when_battle_over() -> void:
	var bag: Dictionary = _make_hud()
	var hud: BattleHUD = bag["hud"]
	var grid: GridBattleControllerStub = bag["grid_controller"]
	add_child(hud)
	grid.set_test_unit(TEST_UNIT_ID, _make_unit(&"dragon_blade", false))
	grid.set_test_active_turn_unit_id(TEST_UNIT_ID)
	grid.set_test_battle_over(true)

	hud._refresh_skill_slot_visual(TEST_UNIT_ID)

	assert_object(hud._btn_skill_slot_0.modulate).override_failure_message(
		"DEFAULT: modulate must be Color.WHITE when battle_over=true, got %s"
				% str(hud._btn_skill_slot_0.modulate)
	).is_equal(Color.WHITE)

	hud.free()
	_free_node_deps(bag)


## DEFAULT — different unit's turn (not active) → can_use_skill=false, skill_used
## still false → white.
func test_skill_slot_visual_default_when_not_active_turn() -> void:
	var bag: Dictionary = _make_hud()
	var hud: BattleHUD = bag["hud"]
	var grid: GridBattleControllerStub = bag["grid_controller"]
	add_child(hud)
	grid.set_test_unit(TEST_UNIT_ID, _make_unit(&"dragon_blade", false))
	grid.set_test_active_turn_unit_id(999)  # a different unit's turn

	hud._refresh_skill_slot_visual(TEST_UNIT_ID)

	assert_object(hud._btn_skill_slot_0.modulate).override_failure_message(
		"DEFAULT: modulate must be Color.WHITE when different unit is active, got %s"
				% str(hud._btn_skill_slot_0.modulate)
	).is_equal(Color.WHITE)

	hud.free()
	_free_node_deps(bag)


## DEFAULT — unknown unit_id (no BattleUnit for the id) → white.
func test_skill_slot_visual_default_when_unit_unknown() -> void:
	var bag: Dictionary = _make_hud()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)
	# Do NOT set_test_unit — leave _test_units empty.

	hud._refresh_skill_slot_visual(TEST_UNIT_ID)

	assert_object(hud._btn_skill_slot_0.modulate).override_failure_message(
		"DEFAULT: modulate must be Color.WHITE when unit_id is unknown, got %s"
				% str(hud._btn_skill_slot_0.modulate)
	).is_equal(Color.WHITE)

	hud.free()
	_free_node_deps(bag)


# ─── Hook integrations ─────────────────────────────────────────────────────────


## Hook 1: _on_unit_turn_started fires _refresh_skill_slot_visual for the
## freshly-active unit. Validate end-to-end: turn starts → modulate transitions
## from white (initial) to red (READY).
func test_unit_turn_started_refreshes_skill_slot_to_ready() -> void:
	var bag: Dictionary = _make_hud()
	var hud: BattleHUD = bag["hud"]
	var grid: GridBattleControllerStub = bag["grid_controller"]
	add_child(hud)
	grid.set_test_unit(TEST_UNIT_ID, _make_unit(&"dragon_blade", false))

	# Initial state — slot 0 should be white before any signal.
	assert_object(hud._btn_skill_slot_0.modulate).is_equal(Color.WHITE)

	# Simulate turn-start by setting active turn unit + invoking the handler.
	# (Direct handler call mirrors session-24's mid-turn refresh test pattern;
	# the production signal path is covered by integration boot-flow tests.)
	grid.set_test_active_turn_unit_id(TEST_UNIT_ID)
	hud._on_unit_turn_started(TEST_UNIT_ID)

	assert_object(hud._btn_skill_slot_0.modulate).override_failure_message(
		"Hook 1: _on_unit_turn_started must refresh slot 0 to READY tint, got %s"
				% str(hud._btn_skill_slot_0.modulate)
	).is_equal(COLOR_READY)

	hud.free()
	_free_node_deps(bag)


## Hook 2: _on_unit_skill_used_refresh fires _refresh_skill_slot_visual and
## flips the modulate from READY to USED after a skill fires.
func test_unit_skill_used_refresh_flips_slot_to_used() -> void:
	var bag: Dictionary = _make_hud()
	var hud: BattleHUD = bag["hud"]
	var grid: GridBattleControllerStub = bag["grid_controller"]
	add_child(hud)
	var unit: BattleUnit = _make_unit(&"dragon_blade", false)
	grid.set_test_unit(TEST_UNIT_ID, unit)
	grid.set_test_active_turn_unit_id(TEST_UNIT_ID)

	# Drive READY state via turn-started, then flip to USED.
	hud._on_unit_turn_started(TEST_UNIT_ID)
	assert_object(hud._btn_skill_slot_0.modulate).is_equal(COLOR_READY)

	# Simulate skill consumption: flip the unit's skill_used flag + invoke
	# the post-fire handler. Production code: use_skill() sets skill_used=true
	# then emits unit_skill_used, which routes through _on_unit_skill_used_refresh.
	unit.skill_used = true
	hud._on_unit_skill_used_refresh(TEST_UNIT_ID, &"dragon_blade")

	assert_object(hud._btn_skill_slot_0.modulate).override_failure_message(
		"Hook 2: _on_unit_skill_used_refresh must flip slot 0 to USED tint, got %s"
				% str(hud._btn_skill_slot_0.modulate)
	).is_equal(COLOR_USED)

	hud.free()
	_free_node_deps(bag)


## Hook 3: _on_use_skill_button_pressed refreshes slot 0 visual right before
## the panel becomes visible (so the player sees the correct state on first
## reveal of the panel, not a stale modulate from a prior turn).
func test_use_skill_button_pressed_refreshes_slot_before_show() -> void:
	var bag: Dictionary = _make_hud()
	var hud: BattleHUD = bag["hud"]
	var grid: GridBattleControllerStub = bag["grid_controller"]
	add_child(hud)
	grid.set_test_unit(TEST_UNIT_ID, _make_unit(&"dragon_blade", false))
	grid.set_test_active_turn_unit_id(TEST_UNIT_ID)

	# Pre-state: white (default modulate at HUD init).
	assert_object(hud._btn_skill_slot_0.modulate).is_equal(Color.WHITE)

	# Click USE_SKILL → panel reveal path → slot 0 visual refresh.
	hud._on_use_skill_button_pressed()

	assert_object(hud._btn_skill_slot_0.modulate).override_failure_message(
		"Hook 3: _on_use_skill_button_pressed must refresh slot 0 to READY tint, got %s"
				% str(hud._btn_skill_slot_0.modulate)
	).is_equal(COLOR_READY)

	# And the panel itself must end up visible.
	var skill_panel: Control = hud._ui_elements.get(&"UI-GB-05")
	assert_bool(skill_panel.visible).is_true()

	hud.free()
	_free_node_deps(bag)


## State-transition: USED → re-open panel still shows grey (defensive — panel
## auto-hides on fire so this path is rare in practice, but documents that a
## subsequent re-open won't show a stale READY tint).
func test_use_skill_button_pressed_shows_used_after_skill_consumed() -> void:
	var bag: Dictionary = _make_hud()
	var hud: BattleHUD = bag["hud"]
	var grid: GridBattleControllerStub = bag["grid_controller"]
	add_child(hud)
	# Unit already used its skill earlier this battle.
	grid.set_test_unit(TEST_UNIT_ID, _make_unit(&"dragon_blade", true))
	grid.set_test_active_turn_unit_id(TEST_UNIT_ID)

	hud._on_use_skill_button_pressed()

	assert_object(hud._btn_skill_slot_0.modulate).override_failure_message(
		"USED state must persist across panel re-open, got %s"
				% str(hud._btn_skill_slot_0.modulate)
	).is_equal(COLOR_USED)

	hud.free()
	_free_node_deps(bag)
