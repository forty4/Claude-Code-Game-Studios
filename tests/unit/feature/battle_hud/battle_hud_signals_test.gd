## BattleHUD signal subscription tests — AC-1..AC-5 for battle-hud story-002.
##
## Story-002: 11 GameBus signal subscriptions (4 controller-LOCAL +
## 7 GameBus autoload) all using Object.CONNECT_DEFERRED + DI test seam +
## S5 INPUT_BLOCKED → MOUSE_FILTER_IGNORE toggle. AC-6 (recursive
## mouse_filter blocks child Button input) lives in the integration test.
##
## ADR: ADR-0015 Battle HUD (Accepted 2026-05-03)
## TR-IDs: TR-battle-hud-003, TR-battle-hud-010
##
## Test type: Logic (all ACs are automated unit tests; AC-6 is integration).
##
## Gotcha references (consulted before authoring):
##   G-4: lambda primitive capture — use Array, not bare primitives. We avoid
##        lambdas entirely here by using BattleHUDCaptureSubclass.received.
##   G-6: explicit cleanup at end of test body — use free(), not queue_free(),
##        for test-owned Nodes (orphan detector fires before after_test).
##   G-7: verify Overall Summary count after run.
##   G-8: Signal.get_connections() returns untyped Array — declare as Array,
##        narrow loop var to Dictionary.
##   G-11: is_instance_valid() before any `as Node` cast on potentially-freed refs.
##   G-15: use before_test() / after_test() — not before_each() / after_each().

extends GdUnitTestSuite

const BattleHUDScript: GDScript = preload("res://src/feature/battle_hud/battle_hud.gd")
const BattleHUDCaptureSubclassScript: GDScript = preload("res://tests/helpers/battle_hud_capture_subclass.gd")
const BattleCameraStubScript: GDScript = preload("res://tests/helpers/battle_camera_stub.gd")
const HPStatusControllerStubScript: GDScript = preload("res://tests/helpers/hp_status_controller_stub.gd")
const TurnOrderRunnerStubScript: GDScript = preload("res://tests/helpers/turn_order_runner_stub.gd")
const GridBattleControllerStubScript: GDScript = preload("res://tests/helpers/grid_battle_controller_stub.gd")
const InputRouterStubScript: GDScript = preload("res://tests/helpers/input_router_stub.gd")
const MapGridStubScript: GDScript = preload("res://tests/helpers/map_grid_stub.gd")
const TerrainEffectStubScript: GDScript = preload("res://tests/helpers/terrain_effect_stub.gd")
const UnitRoleStubScript: GDScript = preload("res://tests/helpers/unit_role_stub.gd")
const HeroDatabaseStubScript: GDScript = preload("res://tests/helpers/hero_database_stub.gd")


# ─── Helper: build BattleHUD (or capture subclass) + 9 dep stubs ────────────

## Returns Dictionary with `hud` (instance), 9 stub deps, ready for add_child.
## When `capture` is true, instantiates BattleHUDCaptureSubclass instead so AC-3
## can record _handle_signal invocations.
func _make_hud_with_stubs(capture: bool = false) -> Dictionary:
	var camera: BattleCameraStub = BattleCameraStubScript.new()
	var hp_controller: HPStatusControllerStub = HPStatusControllerStubScript.new()
	var turn_runner: TurnOrderRunnerStub = TurnOrderRunnerStubScript.new()
	var grid_controller: GridBattleControllerStub = GridBattleControllerStubScript.new()
	var input_router: InputRouterStub = InputRouterStubScript.new()
	var map_grid: MapGridStub = MapGridStubScript.new()
	var terrain_effect: TerrainEffectStub = TerrainEffectStubScript.new()
	var unit_role: UnitRoleStub = UnitRoleStubScript.new()
	var hero_db: HeroDatabaseStub = HeroDatabaseStubScript.new()

	var hud: BattleHUD = (
		BattleHUDCaptureSubclassScript.new() if capture
		else BattleHUDScript.new()
	)
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


## Free Node-type deps explicitly (G-6). RefCounted deps auto-free.
## Order: hud first (so its _exit_tree disconnect runs against still-live deps),
## then the Node deps that outlive it.
func _free_bag(bag: Dictionary) -> void:
	for key: String in ["hud", "camera", "hp_controller", "turn_runner",
			"grid_controller", "input_router", "map_grid"]:
		var dep: Variant = bag.get(key)
		if is_instance_valid(dep):
			var node: Node = dep as Node
			if node != null and not node.is_queued_for_deletion():
				node.free()


## Counts how many entries in `connections` (untyped Array per G-8) have a
## callable whose object identity matches `target`. Used by AC-2 + AC-4.
func _count_connections_to(connections: Array, target: Object) -> int:
	var count: int = 0
	for conn: Dictionary in connections:
		var cb: Callable = conn.get("callable", Callable())
		if cb.get_object() == target:
			count += 1
	return count


## Returns the connection Dictionary for a callable matching (target, method),
## or empty Dictionary if not found. Used by AC-1 to inspect flags.
func _find_connection(connections: Array, target: Object, method: StringName) -> Dictionary:
	for conn: Dictionary in connections:
		var cb: Callable = conn.get("callable", Callable())
		if cb.get_object() == target and cb.get_method() == method:
			return conn
	return {}


# ─── AC-1: 11 connect calls all use Object.CONNECT_DEFERRED ─────────────────
# Parameterised by (emitter_kind, signal_name, handler_method). emitter_kind
# is either "controller" (the DI'd _grid_controller) or "gamebus" (autoload).

const _SUBSCRIPTIONS: Array[Dictionary] = [
	# 4 controller-LOCAL (on _grid_controller, NOT GameBus)
	{"emitter": "controller", "signal": &"unit_selected_changed", "handler": &"_on_unit_selected_changed"},
	{"emitter": "controller", "signal": &"unit_moved", "handler": &"_on_unit_moved"},
	{"emitter": "controller", "signal": &"damage_applied", "handler": &"_on_damage_applied"},
	{"emitter": "controller", "signal": &"battle_outcome_resolved", "handler": &"_on_battle_outcome_resolved"},
	# 7 GameBus
	{"emitter": "gamebus", "signal": &"unit_died", "handler": &"_on_unit_died"},
	{"emitter": "gamebus", "signal": &"round_started", "handler": &"_on_round_started"},
	{"emitter": "gamebus", "signal": &"unit_turn_started", "handler": &"_on_unit_turn_started"},
	{"emitter": "gamebus", "signal": &"unit_turn_ended", "handler": &"_on_unit_turn_ended"},
	{"emitter": "gamebus", "signal": &"input_state_changed", "handler": &"_on_input_state_changed"},
	{"emitter": "gamebus", "signal": &"input_mode_changed", "handler": &"_on_input_mode_changed"},
	{"emitter": "gamebus", "signal": &"formation_bonuses_updated", "handler": &"_on_formation_bonuses_updated"},
]


func test_all_eleven_subscriptions_use_connect_deferred() -> void:
	# AC-1: every connect() in _ready() passes Object.CONNECT_DEFERRED. After
	# add_child(hud), inspect each emitter's signal connections; the connection
	# whose callable targets the hud's handler must have CONNECT_DEFERRED set.
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid_controller: GridBattleController = bag["grid_controller"]
	add_child(hud)  # triggers _ready() → 11 connects

	for sub: Dictionary in _SUBSCRIPTIONS:
		var emitter: Object = (
			grid_controller if (sub["emitter"] as String) == "controller"
			else GameBus
		)
		var signal_name: StringName = sub["signal"]
		var handler: StringName = sub["handler"]

		# G-8: get_connections() returns untyped Array; declare as Array, narrow loop.
		var sig: Signal = Signal(emitter, signal_name)
		var connections: Array = sig.get_connections()
		var conn: Dictionary = _find_connection(connections, hud, handler)

		assert_bool(conn.is_empty()).override_failure_message(
			"AC-1: no connection found from %s.%s to BattleHUD.%s — _ready() must connect all 11 signals" % [
				(sub["emitter"] as String), str(signal_name), str(handler)
			]
		).is_false()

		var flags: int = conn.get("flags", 0) as int
		assert_int(flags & Object.CONNECT_DEFERRED).override_failure_message(
			"AC-1: %s.%s.connect(BattleHUD.%s, ...) must set Object.CONNECT_DEFERRED — got flags=%d" % [
				(sub["emitter"] as String), str(signal_name), str(handler), flags
			]
		).is_equal(Object.CONNECT_DEFERRED)

	hud.free()
	_free_bag({
		"camera": bag["camera"], "hp_controller": bag["hp_controller"],
		"turn_runner": bag["turn_runner"], "grid_controller": bag["grid_controller"],
		"input_router": bag["input_router"], "map_grid": bag["map_grid"],
	})


# ─── AC-1 regression — source must not contain typo CONNECT_DEFFERED ────────

func test_source_does_not_contain_connect_deferred_typo() -> void:
	# Silent enum-typo trap: CONNECT_DEFFERED (double F) maps to int 0 = no flag
	# = NOT deferred. Story-008 will codify this as a CI lint; this test guards
	# the fix locally until then.
	var content: String = FileAccess.get_file_as_string(
			"res://src/feature/battle_hud/battle_hud.gd")
	# Use indirect token assembly so the test file itself is not flagged.
	var typo: String = "CONNECT_DEF" + "FERED"
	assert_bool(content.contains(typo)).override_failure_message(
		"battle_hud.gd contains the silent typo CONNECT_DEFFERED (double F) — must use CONNECT_DEFERRED"
	).is_false()


# ─── AC-2: Pillar 2 lock — zero connections to hidden_fate_condition_progressed ──

func test_pillar_2_lock_no_hidden_fate_subscription() -> void:
	# AC-2: After add_child(hud), the controller's hidden_fate_condition_progressed
	# signal must have zero connections whose callable targets the hud (other
	# subscribers in the test fixture are allowed; this assertion is HUD-specific).
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid_controller: GridBattleController = bag["grid_controller"]
	add_child(hud)

	var connections: Array = grid_controller.hidden_fate_condition_progressed.get_connections()
	var hud_connection_count: int = _count_connections_to(connections, hud)

	assert_int(hud_connection_count).override_failure_message(
		"AC-2 Pillar 2 lock: hidden_fate_condition_progressed must have ZERO callables targeting BattleHUD; found %d" % hud_connection_count
	).is_equal(0)

	hud.free()
	_free_bag({
		"camera": bag["camera"], "hp_controller": bag["hp_controller"],
		"turn_runner": bag["turn_runner"], "grid_controller": bag["grid_controller"],
		"input_router": bag["input_router"], "map_grid": bag["map_grid"],
	})


# ─── AC-3: 11 _on_* handlers each forward to _handle_signal(name, args) ─────
# Uses BattleHUDCaptureSubclass which overrides _handle_signal to record every
# invocation as {"name": StringName, "args": Array}. Each emit is followed by
# `await get_tree().process_frame` so CONNECT_DEFERRED handlers fire on idle.

func _emit_signal_for(bag: Dictionary, sub: Dictionary, args: Array) -> void:
	# Helper: emit the signal on the right emitter with the right args.
	var grid_controller: GridBattleController = bag["grid_controller"]
	var sig_name: StringName = sub["signal"]
	if (sub["emitter"] as String) == "controller":
		var sig: Signal = Signal(grid_controller, sig_name)
		sig.emit.callv(args)
	else:
		var sig: Signal = Signal(GameBus, sig_name)
		sig.emit.callv(args)


# Realistic args for each of the 11 signals — must match production signatures.
const _AC3_EMITS: Array[Dictionary] = [
	{"signal": &"unit_selected_changed", "args": [42, 1]},                     # int, int (NOT bool — production sig)
	{"signal": &"unit_moved", "args": [42, Vector2i(0, 0), Vector2i(1, 0)]},
	{"signal": &"damage_applied", "args": [1, 2, 10]},
	{"signal": &"battle_outcome_resolved", "args": [&"victory", {}]},          # StringName, Dictionary
	{"signal": &"unit_died", "args": [42]},
	{"signal": &"round_started", "args": [3]},
	{"signal": &"unit_turn_started", "args": [42]},
	{"signal": &"unit_turn_ended", "args": [42, true]},                        # 2 args — production sig
	{"signal": &"input_state_changed", "args": [0, 1]},                        # OBSERVATION → UNIT_SELECTED (not S5)
	{"signal": &"input_mode_changed", "args": [1]},
	{"signal": &"formation_bonuses_updated", "args": [{}]},
]


func test_capture_subclass_records_every_handler_invocation() -> void:
	# AC-3: emit each of 11 signals; capture subclass records 11 entries in
	# `received` with matching (name, args).
	var bag: Dictionary = _make_hud_with_stubs(true)
	var hud: BattleHUDCaptureSubclass = bag["hud"]
	add_child(hud)

	for emit: Dictionary in _AC3_EMITS:
		var sub: Dictionary = {}
		for s: Dictionary in _SUBSCRIPTIONS:
			if (s["signal"] as StringName) == (emit["signal"] as StringName):
				sub = s
				break
		_emit_signal_for(bag, sub, emit["args"] as Array)

	# Wait one idle frame so all CONNECT_DEFERRED handlers fire.
	await get_tree().process_frame

	assert_int(hud.received.size()).override_failure_message(
		"AC-3: capture subclass must record exactly 11 _handle_signal calls — got %d" % hud.received.size()
	).is_equal(11)

	# Verify each (name, args) pair was recorded in emit order.
	for i: int in range(_AC3_EMITS.size()):
		var entry: Dictionary = hud.received[i]
		var expected: Dictionary = _AC3_EMITS[i]
		var got_name: StringName = entry["name"]
		var got_args: Array = entry["args"]
		assert_str(str(got_name)).override_failure_message(
			"AC-3 entry %d: name mismatch — expected %s got %s" % [i, str(expected["signal"]), str(got_name)]
		).is_equal(str(expected["signal"]))
		assert_int(got_args.size()).override_failure_message(
			"AC-3 entry %d (%s): args.size mismatch — expected %d got %d" % [
				i, str(got_name), (expected["args"] as Array).size(), got_args.size()
			]
		).is_equal((expected["args"] as Array).size())

	hud.free()
	_free_bag({
		"camera": bag["camera"], "hp_controller": bag["hp_controller"],
		"turn_runner": bag["turn_runner"], "grid_controller": bag["grid_controller"],
		"input_router": bag["input_router"], "map_grid": bag["map_grid"],
	})


func test_same_signal_emitted_twice_records_two_entries() -> void:
	# AC-3 edge case: emit same signal twice → 2 captured entries in emit order.
	var bag: Dictionary = _make_hud_with_stubs(true)
	var hud: BattleHUDCaptureSubclass = bag["hud"]
	add_child(hud)

	GameBus.round_started.emit(7)
	GameBus.round_started.emit(8)
	await get_tree().process_frame

	assert_int(hud.received.size()).is_equal(2)
	assert_int((hud.received[0]["args"] as Array)[0] as int).is_equal(7)
	assert_int((hud.received[1]["args"] as Array)[0] as int).is_equal(8)

	hud.free()
	_free_bag({
		"camera": bag["camera"], "hp_controller": bag["hp_controller"],
		"turn_runner": bag["turn_runner"], "grid_controller": bag["grid_controller"],
		"input_router": bag["input_router"], "map_grid": bag["map_grid"],
	})


# ─── AC-4: _exit_tree() disconnects all 11 ──────────────────────────────────

func test_exit_tree_disconnects_all_eleven_subscriptions() -> void:
	# AC-4: After remove_child(hud), every emitter's signal must report 0
	# callables targeting the hud. Walks all 11 subscriptions per _SUBSCRIPTIONS.
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid_controller: GridBattleController = bag["grid_controller"]
	add_child(hud)
	# Sanity: pre-remove, all 11 connections exist.
	remove_child(hud)  # triggers _exit_tree → 11 disconnects

	for sub: Dictionary in _SUBSCRIPTIONS:
		var emitter: Object = (
			grid_controller if (sub["emitter"] as String) == "controller"
			else GameBus
		)
		var signal_name: StringName = sub["signal"]
		var sig: Signal = Signal(emitter, signal_name)
		var connections: Array = sig.get_connections()
		var hud_count: int = _count_connections_to(connections, hud)

		assert_int(hud_count).override_failure_message(
			"AC-4: %s.%s must have 0 callables targeting hud after _exit_tree; found %d" % [
				(sub["emitter"] as String), str(signal_name), hud_count
			]
		).is_equal(0)

	hud.free()
	_free_bag({
		"camera": bag["camera"], "hp_controller": bag["hp_controller"],
		"turn_runner": bag["turn_runner"], "grid_controller": bag["grid_controller"],
		"input_router": bag["input_router"], "map_grid": bag["map_grid"],
	})


func test_re_add_child_re_subscribes_all_eleven() -> void:
	# AC-4 edge case: re-adding hud back to tree triggers _ready again,
	# re-establishing all 11 connections. Godot only fires _ready once per
	# Node lifetime by default — request_ready() opts back in.
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	var grid_controller: GridBattleController = bag["grid_controller"]
	add_child(hud)
	remove_child(hud)
	hud.request_ready()
	add_child(hud)  # second _ready (because request_ready was called)

	for sub: Dictionary in _SUBSCRIPTIONS:
		var emitter: Object = (
			grid_controller if (sub["emitter"] as String) == "controller"
			else GameBus
		)
		var sig: Signal = Signal(emitter, sub["signal"] as StringName)
		var connections: Array = sig.get_connections()
		var hud_count: int = _count_connections_to(connections, hud)
		assert_int(hud_count).override_failure_message(
			"AC-4 re-add: %s.%s must have 1 hud connection after second _ready; got %d" % [
				(sub["emitter"] as String), str(sub["signal"]), hud_count
			]
		).is_equal(1)

	hud.free()
	_free_bag({
		"camera": bag["camera"], "hp_controller": bag["hp_controller"],
		"turn_runner": bag["turn_runner"], "grid_controller": bag["grid_controller"],
		"input_router": bag["input_router"], "map_grid": bag["map_grid"],
	})


# ─── AC-5: S5 INPUT_BLOCKED → mouse_filter = MOUSE_FILTER_IGNORE ────────────

func test_input_state_changed_to_input_blocked_sets_filter_ignore() -> void:
	# AC-5: emit GameBus.input_state_changed(any_from, INPUT_BLOCKED=5).
	# Wait one idle frame for CONNECT_DEFERRED. Assert mouse_filter is now IGNORE.
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	# Default is STOP after _ready (Control default = STOP, story-001 sets PRESET_FULL_RECT).
	assert_int(hud.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)

	GameBus.input_state_changed.emit(
		InputRouter.InputState.OBSERVATION,    # 0
		InputRouter.InputState.INPUT_BLOCKED,  # 5
	)
	await get_tree().process_frame

	assert_int(hud.mouse_filter).override_failure_message(
		"AC-5: after S5 INPUT_BLOCKED transition, mouse_filter must be MOUSE_FILTER_IGNORE; got %d" % hud.mouse_filter
	).is_equal(Control.MOUSE_FILTER_IGNORE)

	hud.free()
	_free_bag({
		"camera": bag["camera"], "hp_controller": bag["hp_controller"],
		"turn_runner": bag["turn_runner"], "grid_controller": bag["grid_controller"],
		"input_router": bag["input_router"], "map_grid": bag["map_grid"],
	})


func test_input_state_changed_away_from_blocked_reverts_to_stop() -> void:
	# AC-5: enter S5 → mouse_filter == IGNORE. Then transition AWAY from S5 →
	# mouse_filter reverts to STOP.
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	GameBus.input_state_changed.emit(0, 5)  # IDLE → INPUT_BLOCKED
	await get_tree().process_frame
	assert_int(hud.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)

	GameBus.input_state_changed.emit(5, 1)  # INPUT_BLOCKED → UNIT_SELECTED
	await get_tree().process_frame
	assert_int(hud.mouse_filter).override_failure_message(
		"AC-5: after transitioning AWAY from S5, mouse_filter must revert to MOUSE_FILTER_STOP; got %d" % hud.mouse_filter
	).is_equal(Control.MOUSE_FILTER_STOP)

	hud.free()
	_free_bag({
		"camera": bag["camera"], "hp_controller": bag["hp_controller"],
		"turn_runner": bag["turn_runner"], "grid_controller": bag["grid_controller"],
		"input_router": bag["input_router"], "map_grid": bag["map_grid"],
	})


func test_input_state_changed_neither_involves_s5_leaves_filter_unchanged() -> void:
	# AC-5: a transition that doesn't enter or exit S5 must leave mouse_filter
	# unchanged from its previous value.
	var bag: Dictionary = _make_hud_with_stubs()
	var hud: BattleHUD = bag["hud"]
	add_child(hud)

	# Initial state: STOP (Control default).
	assert_int(hud.mouse_filter).is_equal(Control.MOUSE_FILTER_STOP)

	GameBus.input_state_changed.emit(0, 1)  # OBSERVATION → UNIT_SELECTED (no S5)
	await get_tree().process_frame
	assert_int(hud.mouse_filter).override_failure_message(
		"AC-5: non-S5 transition must NOT change mouse_filter; got %d (expected STOP=%d)" % [
			hud.mouse_filter, Control.MOUSE_FILTER_STOP
		]
	).is_equal(Control.MOUSE_FILTER_STOP)

	hud.free()
	_free_bag({
		"camera": bag["camera"], "hp_controller": bag["hp_controller"],
		"turn_runner": bag["turn_runner"], "grid_controller": bag["grid_controller"],
		"input_router": bag["input_router"], "map_grid": bag["map_grid"],
	})
