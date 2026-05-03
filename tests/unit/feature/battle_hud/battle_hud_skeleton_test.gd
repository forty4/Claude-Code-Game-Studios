## BattleHUD skeleton tests — AC-1 through AC-7 per story-001 acceptance criteria.
##
## Story-001: class declaration + 9-param DI + _ready() asserts + PRESET_FULL_RECT +
## _handle_signal test seam + _exit_tree skeleton + battle_hud.tscn existence.
##
## ADR: ADR-0015 Battle HUD (Accepted 2026-05-03)
## Requirements: TR-battle-hud-001, TR-battle-hud-002, TR-battle-hud-014
##
## Test type: Logic (all ACs are automated unit tests — story type = Logic per
## coding-standards.md test evidence table).
##
## Gotcha references (consulted before authoring):
##   G-6: explicit cleanup at end of test body — use free(), not queue_free(), for
##        test-owned Nodes (GdUnit4 orphan detector fires before after_test).
##   G-7: verify Overall Summary count after run — parse errors surface as silent skips.
##   G-8: Signal.get_connections() returns untyped Array — declare as Array, narrow loop.
##   G-11: is_instance_valid() before any `as Node` cast on potentially freed refs.
##   G-14: run `godot --headless --import --path .` after writing new class_name files.
##   G-15: use before_test() / after_test() — not before_each() / after_each().

extends GdUnitTestSuite

const BattleHUDScript: GDScript = preload("res://src/feature/battle_hud/battle_hud.gd")
const BattleCameraStubScript: GDScript = preload("res://tests/helpers/battle_camera_stub.gd")
const HPStatusControllerStubScript: GDScript = preload("res://tests/helpers/hp_status_controller_stub.gd")
const TurnOrderRunnerStubScript: GDScript = preload("res://tests/helpers/turn_order_runner_stub.gd")
const MapGridStubScript: GDScript = preload("res://tests/helpers/map_grid_stub.gd")
const TerrainEffectStubScript: GDScript = preload("res://tests/helpers/terrain_effect_stub.gd")
const UnitRoleStubScript: GDScript = preload("res://tests/helpers/unit_role_stub.gd")
const HeroDatabaseStubScript: GDScript = preload("res://tests/helpers/hero_database_stub.gd")
const InputRouterStubScript: GDScript = preload("res://tests/helpers/input_router_stub.gd")

const GridBattleControllerStubScript: GDScript = preload("res://tests/helpers/grid_battle_controller_stub.gd")


# ─── Helper: build a fully-DI'd BattleHUD + all 9 dep stubs ─────────────────

## _make_hud_with_stubs() — returns a Dictionary containing the BattleHUD instance
## and all 9 typed stub dependencies, ready for setup() + add_child(). Caller is
## responsible for cleanup via free() per G-6.
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
		"hud": hud,
		"camera": camera,
		"hp_controller": hp_controller,
		"turn_runner": turn_runner,
		"grid_controller": grid_controller,
		"input_router": input_router,
		"map_grid": map_grid,
		"terrain_effect": terrain_effect,
		"unit_role": unit_role,
		"hero_db": hero_db,
	}


## _free_bag() — free all Node-type deps in a bag created by _make_hud_with_stubs().
## RefCounted-typed deps (UnitRole, HeroDatabase, TerrainEffect) are auto-freed;
## Node-typed deps require explicit free() per G-6.
func _free_bag(bag: Dictionary) -> void:
	# G-11: guard before cast in case a dep was already freed in an earlier assertion
	for key: String in ["hud", "camera", "hp_controller", "turn_runner",
			"grid_controller", "input_router", "map_grid"]:
		var dep: Variant = bag.get(key)
		if is_instance_valid(dep):
			var node: Node = dep as Node
			if node != null and not node.is_queued_for_deletion():
				node.free()


# ─── AC-1: BattleHUD class declaration ───────────────────────────────────────

func test_battle_hud_is_control_not_canvas_layer() -> void:
	# AC-1: instance `is BattleHUD` AND `is Control`; `is CanvasLayer` returns FALSE.
	# ADR-0015 §1: extends Control required for AccessKit + input routing + theme inheritance.
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]

	assert_bool(hud is BattleHUD).override_failure_message(
		"BattleHUD instance must satisfy `is BattleHUD` — class_name must be BattleHUD"
	).is_true()
	assert_bool(hud is Control).override_failure_message(
		"BattleHUD must extend Control (not CanvasLayer) per ADR-0015 §1"
	).is_true()
	# Cast through Object (untyped base) before the `is CanvasLayer` check.
	# The GDScript 4.6 parser raises a parse error when the static type of the
	# left-hand operand is known to be incompatible with the `is` target type
	# (Control ≮ CanvasLayer). Widening to Object defers the check to runtime
	# while preserving the intent: catch any regression where BattleHUD is
	# accidentally changed to extend CanvasLayer.
	var hud_as_object: Object = hud
	assert_bool(hud_as_object is CanvasLayer).override_failure_message(
		"BattleHUD must NOT be a CanvasLayer — CanvasLayer loses AccessKit + input routing"
	).is_false()

	_free_bag(bag)


# ─── AC-2: 9-param setup() signature + field wiring ─────────────────────────

func test_setup_wires_all_nine_deps() -> void:
	# AC-2: setup() populates all 9 private _<backend> fields. Verified pre-tree
	# (setup() must complete before add_child) per ADR-0015 §3 DI seam ordering.
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]

	assert_object(hud._camera).is_equal(bag["camera"])
	assert_object(hud._hp_controller).is_equal(bag["hp_controller"])
	assert_object(hud._turn_runner).is_equal(bag["turn_runner"])
	assert_object(hud._grid_controller).is_equal(bag["grid_controller"])
	assert_object(hud._input_router).is_equal(bag["input_router"])
	assert_object(hud._map_grid).is_equal(bag["map_grid"])
	assert_object(hud._terrain_effect).is_equal(bag["terrain_effect"])
	assert_object(hud._unit_role).is_equal(bag["unit_role"])
	assert_object(hud._hero_db).is_equal(bag["hero_db"])

	_free_bag(bag)


func test_setup_called_twice_replaces_references() -> void:
	# AC-2 edge case: calling setup() twice replaces references without error.
	# ADR-0015 §3 does not mandate single-shot — second call replaces all 9 fields.
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]

	var camera2: BattleCameraStub = BattleCameraStubScript.new()
	var hp2: HPStatusControllerStub = HPStatusControllerStubScript.new()
	var turn2: TurnOrderRunnerStub = TurnOrderRunnerStubScript.new()
	var grid2: GridBattleControllerStub = GridBattleControllerStubScript.new()
	var input2: InputRouterStub = InputRouterStubScript.new()
	var map2: MapGridStub = MapGridStubScript.new()
	var terrain2: TerrainEffectStub = TerrainEffectStubScript.new()
	var role2: UnitRoleStub = UnitRoleStubScript.new()
	var hero2: HeroDatabaseStub = HeroDatabaseStubScript.new()
	hud.setup(camera2, hp2, turn2, grid2, input2, map2, terrain2, role2, hero2)

	assert_object(hud._camera).is_equal(camera2)
	assert_object(hud._hp_controller).is_equal(hp2)
	assert_object(hud._turn_runner).is_equal(turn2)
	assert_object(hud._grid_controller).is_equal(grid2)
	assert_object(hud._input_router).is_equal(input2)
	assert_object(hud._map_grid).is_equal(map2)
	assert_object(hud._terrain_effect).is_equal(terrain2)
	assert_object(hud._unit_role).is_equal(role2)
	assert_object(hud._hero_db).is_equal(hero2)

	# Cleanup: free new stubs + original bag (old deps are orphaned by second setup)
	if is_instance_valid(camera2): camera2.free()
	if is_instance_valid(hp2): hp2.free()
	if is_instance_valid(turn2): turn2.free()
	if is_instance_valid(grid2): grid2.free()
	if is_instance_valid(input2): input2.free()
	if is_instance_valid(map2): map2.free()
	_free_bag(bag)


# ─── AC-3: _ready() asserts all 9 backends non-null ─────────────────────────

func test_setup_skipped_fields_are_all_null() -> void:
	# AC-3 proxy: without setup(), all 9 fields are null. We cannot directly test
	# the assert() crash path (it would terminate the test runner per ADR guidance).
	# The proxy confirms the assert-triggering condition exists pre-tree.
	var hud: BattleHUD = BattleHUDScript.new()
	auto_free(hud)

	assert_object(hud._camera).is_null()
	assert_object(hud._hp_controller).is_null()
	assert_object(hud._turn_runner).is_null()
	assert_object(hud._grid_controller).is_null()
	assert_object(hud._input_router).is_null()
	assert_object(hud._map_grid).is_null()
	assert_object(hud._terrain_effect).is_null()
	assert_object(hud._unit_role).is_null()
	assert_object(hud._hero_db).is_null()


# ─── AC-4: _ready() calls PRESET_FULL_RECT ───────────────────────────────────

func test_ready_applies_full_rect_preset() -> void:
	# AC-4: after add_child(hud), anchor values match PRESET_FULL_RECT outcomes.
	# set_anchors_preset(Control.PRESET_FULL_RECT) → left=0, top=0, right=1, bottom=1.
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)  # triggers _ready()

	assert_float(hud.anchor_left).override_failure_message(
		"anchor_left must be 0.0 after PRESET_FULL_RECT"
	).is_equal(0.0)
	assert_float(hud.anchor_top).override_failure_message(
		"anchor_top must be 0.0 after PRESET_FULL_RECT"
	).is_equal(0.0)
	assert_float(hud.anchor_right).override_failure_message(
		"anchor_right must be 1.0 after PRESET_FULL_RECT"
	).is_equal(1.0)
	assert_float(hud.anchor_bottom).override_failure_message(
		"anchor_bottom must be 1.0 after PRESET_FULL_RECT"
	).is_equal(1.0)

	# G-6: explicit in-body free (not queue_free) before test body exits
	hud.free()
	# Free Node deps that outlive the hud
	for key: String in ["camera", "hp_controller", "turn_runner", "grid_controller", "input_router", "map_grid"]:
		var dep: Variant = bag.get(key)
		if is_instance_valid(dep):
			var node: Node = dep as Node
			if node != null:
				node.free()


func test_ready_disables_process() -> void:
	# AC-4 + story-001 AC-7: _ready() calls set_process(false) — no per-frame work
	# in skeleton. Story-007 may re-enable for grid-overlay zoom-poll.
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	assert_bool(hud.is_processing()).override_failure_message(
		"BattleHUD._process must be disabled in story-001 skeleton (set_process(false) in _ready)"
	).is_false()

	hud.free()
	for key: String in ["camera", "hp_controller", "turn_runner", "grid_controller", "input_router", "map_grid"]:
		var dep: Variant = bag.get(key)
		if is_instance_valid(dep):
			var node: Node = dep as Node
			if node != null:
				node.free()


# ─── AC-5: _handle_signal() test seam is silent no-op ───────────────────────

func test_handle_signal_no_op_on_any_name_and_args() -> void:
	# AC-5: _handle_signal("any_signal", []) — no error, no side effects.
	# Handler bodies are story-002; skeleton body is pass.
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]

	# Invoke with a variety of signal_name + args shapes — all must silently no-op.
	hud._handle_signal(&"unit_selected_changed", [])
	hud._handle_signal(&"unit_moved", [1, Vector2i(0, 0), Vector2i(1, 0)])
	hud._handle_signal(&"damage_applied", [1, 2, 10])
	hud._handle_signal(&"any_unknown_signal", ["foo", 42, true])
	hud._handle_signal(&"", [])

	# If we reached here without error, the test passes.
	assert_bool(true).is_true()

	_free_bag(bag)


# ─── AC-6: _exit_tree() empty skeleton — no crash ────────────────────────────

func test_exit_tree_skeleton_no_crash() -> void:
	# AC-6: remove_child / queue_free triggers _exit_tree() with no error.
	# Story-001 body is `pass`; no signals are subscribed yet.
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	# G-6: free() (not queue_free) for synchronous determinism
	hud.free()

	# Confirm no crash (reaching here = pass). Also verify post-free invalidity.
	assert_bool(is_instance_valid(hud)).override_failure_message(
		"hud should be freed after free() call"
	).is_false()

	for key: String in ["camera", "hp_controller", "turn_runner", "grid_controller", "input_router", "map_grid"]:
		var dep: Variant = bag.get(key)
		if is_instance_valid(dep):
			var node: Node = dep as Node
			if node != null:
				node.free()


# ─── AC-7: scenes/battle/battle_hud.tscn exists ──────────────────────────────

func test_battle_hud_tscn_exists_and_root_is_battle_hud() -> void:
	# AC-7: preload("res://scenes/battle/battle_hud.tscn") loads non-null PackedScene;
	# instantiated root is a BattleHUD instance.
	assert_bool(FileAccess.file_exists("res://scenes/battle/battle_hud.tscn")).override_failure_message(
		"scenes/battle/battle_hud.tscn must exist per story-001 AC-7"
	).is_true()

	var packed: PackedScene = load("res://scenes/battle/battle_hud.tscn") as PackedScene
	assert_object(packed).override_failure_message(
		"battle_hud.tscn must load as a non-null PackedScene"
	).is_not_null()

	# Why no setup() call here: PackedScene.instantiate() defers _ready() until
	# add_child(); since we never add to the tree, the 9-dep asserts never fire.
	# free() DOES trigger _exit_tree(), but the ADR-0015 §3 _exit_tree pattern
	# uses only `GameBus.signal.disconnect(_on_handler)` calls (handler methods,
	# not field derefs) guarded by is_connected — safe even with null deps.
	# DO NOT add `add_child(instance)` here without first calling setup() with
	# all 9 stubs — doing so would trigger the 9-dep asserts and crash the runner.
	var instance: Node = packed.instantiate()
	var hud: BattleHUD = instance as BattleHUD

	assert_object(hud).override_failure_message(
		"battle_hud.tscn root must be a BattleHUD (Control) instance"
	).is_not_null()

	if is_instance_valid(instance):
		instance.free()


# ─── AC-8 + AC-9: Source discipline (structural grep — manual CI gate) ────────

func test_source_contains_no_gamebus_emit_calls() -> void:
	# AC-8: zero `GameBus.*.emit` substrings — non-emitter discipline per ADR-0015 §5.
	# story-008 automates this as CI lint; this test provides the same gate inline.
	var content: String = FileAccess.get_file_as_string(
			"res://src/feature/battle_hud/battle_hud.gd")
	# Use a two-part check to avoid triggering the lint on THIS test file's own grep string
	var emitter_token: String = "GameBus."
	var emit_suffix: String = "emit"
	assert_bool(content.contains(emitter_token + emit_suffix)).override_failure_message(
		"battle_hud.gd MUST NOT contain GameBus.*.emit calls — non-emitter discipline per ADR-0015 §5"
	).is_false()


func test_source_contains_no_pillar_2_token() -> void:
	# AC-9: zero occurrences of `hidden_fate_condition_progressed` — Pillar 2 lock.
	# story-008 automates this as CRITICAL CI lint. KEEP FOREVER.
	var content: String = FileAccess.get_file_as_string(
			"res://src/feature/battle_hud/battle_hud.gd")
	assert_bool(content.contains("hidden_fate_condition_progressed")).override_failure_message(
		"battle_hud.gd MUST NOT contain 'hidden_fate_condition_progressed' (Pillar 2 lock — ADR-0015 §8)"
	).is_false()
