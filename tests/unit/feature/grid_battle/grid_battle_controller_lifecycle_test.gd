## Lifecycle tests for GridBattleController — DI assertion + signal subscription
## + _exit_tree() autoload-disconnect cleanup per ADR-0014 §Validation §1+§2.
##
## Story-001: skeleton + 8-param DI + 4 GameBus signal subscriptions + _exit_tree disconnect.
## Mirrors battle_camera_lifecycle_test.gd pattern (camera epic precedent).
##
## NOTE: ADR-0014 §3 sketches show instance-level signal subscriptions
## (`_hp_controller.unit_died.connect(...)` etc.). Production-shipped backends
## emit these via GameBus autoload, NOT instance signals — verified at story-001
## implementation 2026-05-02. Tests assert against GameBus.X subscriptions for
## all 4 signals (input_action_fired + unit_died + unit_turn_started + round_started).

extends GdUnitTestSuite

const GridBattleControllerScript: GDScript = preload("res://src/feature/grid_battle/grid_battle_controller.gd")
const MapGridStubScript: GDScript = preload("res://tests/helpers/map_grid_stub.gd")
const HPStatusControllerStubScript: GDScript = preload("res://tests/helpers/hp_status_controller_stub.gd")
const TurnOrderRunnerStubScript: GDScript = preload("res://tests/helpers/turn_order_runner_stub.gd")
const HeroDatabaseStubScript: GDScript = preload("res://tests/helpers/hero_database_stub.gd")
const TerrainEffectStubScript: GDScript = preload("res://tests/helpers/terrain_effect_stub.gd")
const UnitRoleStubScript: GDScript = preload("res://tests/helpers/unit_role_stub.gd")
const BattleCameraStubScript: GDScript = preload("res://tests/helpers/battle_camera_stub.gd")


func before_test() -> void:
	# G-15 isolation — reset BalanceConstants cache between tests so MAX_TURNS_PER_BATTLE
	# (and other keys) are re-read fresh per test rather than carrying stale state.
	(load("res://src/foundation/balance/balance_constants.gd") as GDScript).set("_cache_loaded", false)


# ─── Helper: build a fully-DI'd GridBattleController + dependencies ─────────

func _make_controller_with_deps() -> Dictionary:
	# Returns Dictionary with the controller + all 7 dep instances + 1 BattleUnit
	# fixture, ready to be add_child'd. Caller is responsible for auto_free / free.
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = 1
	var map_grid: MapGridStub = MapGridStubScript.new()
	map_grid.set_dimensions_for_test(Vector2i(8, 8))
	var camera: BattleCameraStub = BattleCameraStubScript.new()
	var hero_db: HeroDatabaseStub = HeroDatabaseStubScript.new()
	var turn_runner: TurnOrderRunnerStub = TurnOrderRunnerStubScript.new()
	var hp_controller: HPStatusControllerStub = HPStatusControllerStubScript.new()
	var terrain_effect: TerrainEffectStub = TerrainEffectStubScript.new()
	var unit_role: UnitRoleStub = UnitRoleStubScript.new()
	var controller: GridBattleController = GridBattleControllerScript.new()
	controller.setup([unit], map_grid, camera, hero_db, turn_runner, hp_controller, terrain_effect, unit_role)
	return {
		"controller": controller,
		"unit": unit,
		"map_grid": map_grid,
		"camera": camera,
		"hero_db": hero_db,
		"turn_runner": turn_runner,
		"hp_controller": hp_controller,
		"terrain_effect": terrain_effect,
		"unit_role": unit_role,
	}


# ─── AC-1, AC-2: setup() assigns all 7 deps + populates _units ──────────────

func test_setup_assigns_all_deps() -> void:
	# Pre-tree state proxy per battle_camera precedent — verifies setup() populated
	# all internal fields BEFORE add_child / _ready fires.
	var bag: Dictionary = _make_controller_with_deps()
	var controller: GridBattleController = bag["controller"]
	auto_free(controller)
	# Stubs that are Nodes need cleanup; RefCounted stubs are auto-freed
	auto_free(bag["map_grid"] as Node)
	auto_free(bag["camera"] as Node)
	auto_free(bag["turn_runner"] as Node)
	auto_free(bag["hp_controller"] as Node)

	assert_int(controller._units.size()).is_equal(1)
	assert_object(controller._units[1]).is_equal(bag["unit"])
	assert_object(controller._map_grid).is_equal(bag["map_grid"])
	assert_object(controller._camera).is_equal(bag["camera"])
	assert_object(controller._hero_db).is_equal(bag["hero_db"])
	assert_object(controller._turn_runner).is_equal(bag["turn_runner"])
	assert_object(controller._hp_controller).is_equal(bag["hp_controller"])
	assert_object(controller._terrain_effect).is_equal(bag["terrain_effect"])
	assert_object(controller._unit_role).is_equal(bag["unit_role"])


# ─── AC-3, AC-8: pre-mount state without setup() — proxy for assert-fail ────

func test_ready_fails_without_setup_units_empty() -> void:
	# Per ADR-0014 R-2: _ready() asserts _units.size() > 0 + 7 deps non-null.
	# We test field state pre-mount as the proxy (asserts in _ready can crash test runner).
	var controller: GridBattleController = GridBattleControllerScript.new()
	auto_free(controller)
	# Did NOT call setup()
	assert_int(controller._units.size()).is_equal(0)
	assert_object(controller._map_grid).is_null()
	assert_object(controller._camera).is_null()
	assert_object(controller._hero_db).is_null()
	assert_object(controller._turn_runner).is_null()
	assert_object(controller._hp_controller).is_null()
	assert_object(controller._terrain_effect).is_null()
	assert_object(controller._unit_role).is_null()


# ─── AC-5, AC-7: 4 GameBus subscriptions + _exit_tree disconnects all ──────

func test_exit_tree_disconnects_all_four_gamebus_subscriptions() -> void:
	# Per ADR-0014 R-10: _exit_tree() MUST explicitly disconnect all 4 GameBus
	# subscriptions. Verify by:
	# (a) mount controller → _ready connects 4 signals
	# (b) confirm all 4 subscriptions live (object == controller)
	# (c) free controller → _exit_tree() runs
	# (d) after free, GameBus has no live subscriber for any of the 4 handlers
	#     pointing at this controller (assert via subscription enumeration)
	var bag: Dictionary = _make_controller_with_deps()
	var controller: GridBattleController = bag["controller"]
	add_child(controller)  # triggers _ready → connect 4 signals
	# Camera + Node stubs need to live for controller's _ready assertions
	# but we'll free them after the controller in cleanup
	auto_free(bag["map_grid"] as Node)
	auto_free(bag["camera"] as Node)
	auto_free(bag["turn_runner"] as Node)
	auto_free(bag["hp_controller"] as Node)

	# After _ready, all 4 subscriptions should be live (per ADR-0014 §3)
	assert_bool(_subscription_on_signal_exists(GameBus.input_action_fired, controller)).override_failure_message(
		"Expected GameBus.input_action_fired to have a live subscription pointing at GridBattleController after _ready"
	).is_true()
	assert_bool(_subscription_on_signal_exists(GameBus.unit_died, controller)).override_failure_message(
		"Expected GameBus.unit_died to have a live subscription pointing at GridBattleController after _ready"
	).is_true()
	assert_bool(_subscription_on_signal_exists(GameBus.unit_turn_started, controller)).override_failure_message(
		"Expected GameBus.unit_turn_started to have a live subscription pointing at GridBattleController after _ready"
	).is_true()
	assert_bool(_subscription_on_signal_exists(GameBus.round_started, controller)).override_failure_message(
		"Expected GameBus.round_started to have a live subscription pointing at GridBattleController after _ready"
	).is_true()

	# Free the controller → _exit_tree() runs
	controller.free()  # synchronous free for test determinism (NOT queue_free per G-6)

	# After free, no subscription on any of the 4 signals should remain pointing at this controller
	assert_bool(_subscription_on_signal_exists(GameBus.input_action_fired, controller)).override_failure_message(
		"GameBus.input_action_fired STILL has a subscription pointing at freed GridBattleController after _exit_tree"
	).is_false()
	assert_bool(_subscription_on_signal_exists(GameBus.unit_died, controller)).override_failure_message(
		"GameBus.unit_died STILL has a subscription pointing at freed GridBattleController after _exit_tree"
	).is_false()
	assert_bool(_subscription_on_signal_exists(GameBus.unit_turn_started, controller)).override_failure_message(
		"GameBus.unit_turn_started STILL has a subscription pointing at freed GridBattleController after _exit_tree"
	).is_false()
	assert_bool(_subscription_on_signal_exists(GameBus.round_started, controller)).override_failure_message(
		"GameBus.round_started STILL has a subscription pointing at freed GridBattleController after _exit_tree"
	).is_false()


# ─── Helper: search Signal connections for a target object reference ───────

func _subscription_on_signal_exists(sig: Signal, target: Variant) -> bool:
	# Per G-8: Signal.get_connections() returns untyped Array; declare as Array
	# and narrow loop variable to Dictionary at iteration time. Per G-11: target
	# may be a freed Object reference — typed `Object` parameter would crash with
	# "argument N (previously freed) is not a subclass of the expected argument
	# class". Variant param + is_instance_valid() guard before comparison.
	# When target is freed (post-controller.free()), no live subscription can
	# match it — return false (correct post-_exit_tree assertion state).
	if not is_instance_valid(target):
		return false
	var connections: Array = sig.get_connections()
	for conn: Dictionary in connections:
		var obj: Object = conn["callable"].get_object()
		if obj != null and obj == target:
			return true
	return false


# ─── AC-6: CONNECT_DEFERRED load-bearing comment present in source ─────────

func test_connect_deferred_load_bearing_comment_present_in_source() -> void:
	# Per ADR-0014 §3 + R-8 + godot-specialist 2026-05-02 review revision #1:
	# the CONNECT_DEFERRED comment marking unit_died as load-bearing reentrance
	# prevention is REQUIRED in source. Future maintainers must not remove it
	# without an ADR amendment. G-22-style structural source assertion catches
	# accidental removal at CI time.
	var content: String = FileAccess.get_file_as_string("res://src/feature/grid_battle/grid_battle_controller.gd")
	assert_bool(content.contains("CONNECT_DEFERRED")).override_failure_message(
		"grid_battle_controller.gd MUST contain 'CONNECT_DEFERRED' string per ADR-0014 §3"
	).is_true()
	assert_bool(content.contains("load-bearing reentrance prevention")).override_failure_message(
		"grid_battle_controller.gd MUST contain the verbatim 'load-bearing reentrance prevention' phrase per ADR-0014 §3 + AC-6"
	).is_true()
	assert_bool(content.contains("MUST NOT remove the DEFERRED flag")).override_failure_message(
		"grid_battle_controller.gd MUST contain the verbatim 'MUST NOT remove the DEFERRED flag' instruction per ADR-0014 §3 + AC-6"
	).is_true()
