extends GdUnitTestSuite

## grid_battle_controller_ai_action_ready_test.gd
## Integration tests for Story S15-B (POLISH-011 absorption #2 of 3):
##   AC-1: set_ai_system connects ai_action_ready with CONNECT_DEFERRED
##   AC-2: set_ai_system is idempotent (double-call does not double-connect)
##   AC-3: _exit_tree disconnects ai_action_ready
##   AC-4: WAIT handler calls declare_action(WAIT) and nothing else
##   AC-5: MOVE handler calls _do_move then declare_action(MOVE)
##   AC-6: ATTACK handler resolves attack then calls declare_action(ATTACK)
##   AC-7: MOVE_AND_ATTACK handler calls MOVE then ATTACK declare_action (2 calls)
##   AC-8: DEFEND handler calls declare_action(DEFEND)
##   AC-9: USE_SKILL handler substitutes WAIT
##   AC-10: unknown unit_id in registry is a no-op (no dispatch)
##
## Test type: Integration — crosses GridBattleController <-> AISystem signal boundary.
## Uses real GridBattleController with stub AISystem + TurnOrderRunner double.
## No GameBus signal dependency (local signals only for AI path).
##
## Governing ADRs:
##   ADR-0014 §8 Amendment 2026-05-10 (this story's implementation)
##   ADR-0019 §Decision §Payload Form — AIActionCommand 6-ActionType enum
##   ADR-0011 §Decision Contract 5 — declare_action as T5 release path
##
## GOTCHA AWARENESS (see .claude/rules/godot-4x-gotchas.md):
##   G-4  — lambda primitive capture trap; use Array[Dictionary] captures pattern
##   G-6  — orphan detection fires before after_test; explicit cleanup in body
##   G-8  — Signal.get_connections() returns untyped Array
##   G-11 — is_instance_valid guard before as Node cast
##   G-15 — before_test() canonical hook (NOT before_each)
##   G-16 — typed Array[Dictionary] for signal log
##   G-26 — inner class names prefixed GBC* to avoid global class_name collision
##   G-28 — never bulk-disconnect-all; only disconnect test-owned callables


# ── Inner test doubles (G-26: prefixed GBC* to avoid global class_name collision) ──

## Minimal AISystem stub — exposes ai_action_ready signal + emit helper.
## Extends AISystem (registered global class_name) to satisfy GridBattleController's
## typed `_ai_system: AISystem` field without duck-typing.
class GBCAISystemStub extends AISystem:
	## Overrides AISystem _ready() to skip the controller-DI assert (production
	## AISystem subscribes to controller.ai_action_requested in _ready; tests do
	## not exercise that path — they emit ai_action_ready directly via emit_ready).
	func _ready() -> void:
		pass

	## Overrides AISystem _exit_tree() to skip disconnect of unsubscribed signal.
	func _exit_tree() -> void:
		pass

	## Helper: emit ai_action_ready on behalf of a test.
	func emit_ready(uid: int, cmd: AIActionCommand) -> void:
		ai_action_ready.emit(uid, cmd)


## TurnOrderRunner double — records all declare_action calls.
## Extends TurnOrderRunner (registered global class_name) to satisfy typed field.
class GBCTurnRunnerDouble extends TurnOrderRunner:
	## All recorded declare_action calls.
	## Each entry: {"unit_id": int, "action": int, "target": ActionTarget}
	var calls: Array[Dictionary] = []

	## Overrides initialize_battle to no-op (test doesn't need round lifecycle).
	func initialize_battle(_roster: Array[BattleUnit]) -> void:
		pass

	## Records the call then returns a successful ActionResult.
	func declare_action(unit_id: int, action: int, target: ActionTarget) -> ActionResult:
		calls.append({"unit_id": unit_id, "action": action, "target": target})
		return ActionResult.make_success()


## HPStatusController stub — minimal surface for apply_damage + is_alive queries.
## Extends HPStatusController to satisfy typed field.
class GBCHPControllerStub extends HPStatusController:
	## Recorded apply_damage calls. Each: {"unit_id": int, "amount": int}
	var damage_calls: Array[Dictionary] = []

	## All unit_ids tracked as alive unless explicitly added to _dead_ids.
	var _dead_ids: Array[int] = []

	## Override _ready() to prevent GameBus subscription from production code.
	func _ready() -> void:
		pass  # no subscription — test-scoped

	## Override _exit_tree() to prevent disconnect crash on freed GameBus.
	func _exit_tree() -> void:
		pass

	func apply_damage(unit_id: int, resolved_damage: int, _attack_type: int, _source_flags: Array) -> void:
		damage_calls.append({"unit_id": unit_id, "amount": resolved_damage})

	func is_alive(unit_id: int) -> bool:
		return not (unit_id in _dead_ids)

	func get_current_hp(_unit_id: int) -> int:
		return 100

	func get_max_hp(_unit_id: int) -> int:
		return 100


## Concrete UnitRole subclass — bypasses @abstract parse-time block (G-22).
## Empty body OK because controller only stores the ref + asserts non-null;
## all UnitRole API is static (called as `UnitRole.get_atk(...)` etc).
class GBCUnitRoleStub extends UnitRole:
	pass


## Concrete HeroDatabase subclass — bypasses @abstract parse-time block (G-22).
## Empty body OK because controller stores the ref + asserts non-null;
## all HeroDatabase API is static (called as `HeroDatabase.get_hero(...)` etc).
class GBCHeroDatabaseStub extends HeroDatabase:
	pass


# ── Constants ─────────────────────────────────────────────────────────────────

## AI-controlled unit at (0,0). side=1 (enemy).
const _UID_AI: int  = 10
## Player-controlled defender at (1,0). side=0 (player).
const _UID_DEF: int = 11

## Start position for the AI unit.
const _POS_AI:  Vector2i = Vector2i(0, 0)
## Start position for the defender (adjacent — Manhattan distance 1).
const _POS_DEF: Vector2i = Vector2i(1, 0)


# ── Suite state ───────────────────────────────────────────────────────────────

var _controller: GridBattleController
var _ai_stub: GBCAISystemStub
var _turn_double: GBCTurnRunnerDouble
var _hp_stub: GBCHPControllerStub
var _map_grid: MapGrid
var _unit_moved_log: Array[Dictionary] = []  ## G-4: Array captures for unit_moved signal


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func before_test() -> void:
	## G-15: canonical per-test setup hook (NOT before_each).
	## Builds a minimal 2-unit fixture: AI unit at (0,0), defender at (1,0).
	## Controller is wired with stub dependencies, then set_ai_system() is called.
	_unit_moved_log.clear()

	# Build a minimal 15×15 MapGrid (MAP_COLS_MIN=15, MAP_ROWS_MIN=15 per
	# MapGrid._validate_map). All tiles passable PLAINS with no occupants.
	_map_grid = auto_free(MapGrid.new())
	add_child(_map_grid)
	_build_minimal_map(_map_grid, 15, 15)

	# Build stub AI units.
	var ai_unit: BattleUnit   = _make_unit(_UID_AI,  false, 1, _POS_AI,  2, 1)
	var def_unit: BattleUnit  = _make_unit(_UID_DEF, true,  0, _POS_DEF, 2, 1)

	# Build stubs / doubles.
	_turn_double = auto_free(GBCTurnRunnerDouble.new())
	add_child(_turn_double)

	_hp_stub = auto_free(GBCHPControllerStub.new())
	add_child(_hp_stub)

	_ai_stub = auto_free(GBCAISystemStub.new())
	add_child(_ai_stub)

	# Build controller with real stubs.
	# TerrainEffect + UnitRole + HeroDatabase + BattleCamera are not exercised by
	# AI-action-ready tests — pass fresh stubs that satisfy non-null asserts.
	var terrain_stub: TerrainEffect  = auto_free(TerrainEffect.new())
	var unit_role_stub: UnitRole     = auto_free(GBCUnitRoleStub.new())
	var hero_db_stub: HeroDatabase   = auto_free(GBCHeroDatabaseStub.new())
	var camera_stub: BattleCamera    = auto_free(BattleCamera.new())

	_controller = auto_free(GridBattleController.new())
	_controller.setup(
		[ai_unit, def_unit],
		_map_grid,
		camera_stub,
		hero_db_stub,
		_turn_double,
		_hp_stub,
		terrain_stub,
		unit_role_stub,
	)
	add_child(_controller)

	# Capture unit_moved via G-4 Array-of-Dict pattern (method reference form).
	_controller.unit_moved.connect(_capture_unit_moved)

	# Inject AI stub AFTER add_child (per set_ai_system contract).
	_controller.set_ai_system(_ai_stub)


func after_test() -> void:
	## G-15: explicit cleanup.
	## Disconnect only the test-side captures per G-28 (never bulk-disconnect-all).
	if is_instance_valid(_controller):
		if _controller.unit_moved.is_connected(_capture_unit_moved):
			_controller.unit_moved.disconnect(_capture_unit_moved)


# ── Signal capture (method-reference form — sidesteps G-4) ───────────────────

func _capture_unit_moved(unit_id: int, from: Vector2i, to: Vector2i) -> void:
	_unit_moved_log.append({"unit_id": unit_id, "from": from, "to": to})


# ── Helpers ───────────────────────────────────────────────────────────────────

## Builds a minimal map: all passable PLAINS tiles, occupants cleared.
## Mirrors fixture pattern from tests/integration/core/map_grid_mutation_test.gd.
func _build_minimal_map(grid: MapGrid, cols: int, rows: int) -> void:
	var resource: MapResource = MapResource.new()
	resource.map_cols = cols
	resource.map_rows = rows
	resource.terrain_version = 1
	var tiles: Array[MapTileData] = []
	for row in range(rows):
		for col in range(cols):
			var t: MapTileData = MapTileData.new()
			t.coord = Vector2i(col, row)
			t.terrain_type = 0   # PLAINS — passable
			t.elevation = 0
			t.is_passable_base = true
			t.is_destructible = false
			t.destruction_hp = 0
			t.occupant_id = 0
			t.occupant_faction = 0
			t.tile_state = MapGrid.TILE_STATE_EMPTY
			tiles.append(t)
	resource.tiles = tiles
	var ok: bool = grid.load_map(resource)
	assert(ok, "MapGrid.load_map failed in test fixture")
	# Set initial occupancy to match unit positions.
	grid.set_occupant(_POS_AI,  _UID_AI,  MapGrid.FACTION_ENEMY)
	grid.set_occupant(_POS_DEF, _UID_DEF, MapGrid.FACTION_ALLY)


func _make_unit(
	unit_id: int,
	is_player: bool,
	side: int,
	pos: Vector2i,
	move_range: int,
	attack_range: int,
) -> BattleUnit:
	var u: BattleUnit = BattleUnit.new()
	u.unit_id       = unit_id
	u.is_player_controlled = is_player
	u.side          = side
	u.position      = pos
	u.move_range    = move_range
	u.attack_range  = attack_range
	u.raw_atk       = 10
	u.raw_def       = 5
	u.facing        = 1  # East
	return u


# ── AC-1: CONNECT_DEFERRED flag ───────────────────────────────────────────────

## AC-1 (S15-B): set_ai_system connects ai_action_ready with CONNECT_DEFERRED flag.
## Given: controller wired with GBCAISystemStub via set_ai_system (done in before_test).
## When: inspect _ai_stub.ai_action_ready connection list.
## Then: exactly 1 connection exists targeting GridBattleController._on_ai_action_ready;
##       that connection carries Object.CONNECT_DEFERRED flag (flag bitmask bit 8).
func test_set_ai_system_connects_with_deferred_flag() -> void:
	# G-8: get_connections() returns untyped Array
	var connections: Array = _ai_stub.ai_action_ready.get_connections()

	assert_int(connections.size()).override_failure_message(
		("AC-1: ai_action_ready must have exactly 1 connection after set_ai_system; "
		+ "got %d")
		% connections.size()
	).is_equal(1)

	var conn: Dictionary = connections[0] as Dictionary
	var flags: int = conn.get("flags", 0) as int

	## Object.CONNECT_DEFERRED = 8 (Godot 4.6 constant)
	assert_bool((flags & Object.CONNECT_DEFERRED) != 0).override_failure_message(
		("AC-1: ai_action_ready connection must carry CONNECT_DEFERRED flag (0x%X); "
		+ "actual flags = 0x%X")
		% [Object.CONNECT_DEFERRED, flags]
	).is_true()


# ── AC-2: Idempotent double-call ──────────────────────────────────────────────

## AC-2 (S15-B): Calling set_ai_system a second time with the same stub does not
## double-connect. Exactly 1 connection remains on ai_action_ready.
## Given: set_ai_system already called once in before_test.
## When: set_ai_system called again with the same stub.
## Then: exactly 1 connection on ai_action_ready (is_connected guard).
func test_set_ai_system_idempotent_on_double_call() -> void:
	_controller.set_ai_system(_ai_stub)  # second call with same stub

	var connections: Array = _ai_stub.ai_action_ready.get_connections()

	assert_int(connections.size()).override_failure_message(
		("AC-2: double call to set_ai_system must not double-connect; "
		+ "expected 1 connection, got %d")
		% connections.size()
	).is_equal(1)


# ── AC-3: _exit_tree disconnects ─────────────────────────────────────────────

## AC-3 (S15-B): When the controller exits the tree, ai_action_ready is disconnected.
## Given: controller is in tree with ai_action_ready connected.
## When: controller is removed from the scene tree.
## Then: ai_action_ready.is_connected(_on_ai_action_ready) == false.
func test_exit_tree_disconnects_ai_action_ready() -> void:
	# Verify it starts connected.
	var before_conn: Array = _ai_stub.ai_action_ready.get_connections()
	assert_int(before_conn.size()).override_failure_message(
		"AC-3 precondition: should have 1 connection before removal"
	).is_equal(1)

	# Remove controller from tree — triggers _exit_tree().
	remove_child(_controller)

	var after_conn: Array = _ai_stub.ai_action_ready.get_connections()

	assert_int(after_conn.size()).override_failure_message(
		("AC-3: ai_action_ready must have 0 connections after controller _exit_tree; "
		+ "got %d — _exit_tree disconnect not executed")
		% after_conn.size()
	).is_equal(0)

	# G-6: re-add to tree so auto_free cleanup doesn't error.
	add_child(_controller)


# ── AC-4: WAIT handler ────────────────────────────────────────────────────────

## AC-4 (S15-B): WAIT command results in declare_action(WAIT, null) only.
## Given: ai_stub emits WAIT command for _UID_AI.
## When: await process_frame to drain CONNECT_DEFERRED.
## Then: _turn_double.calls has exactly 1 entry with action == WAIT.
##       unit_moved is NOT emitted.
func test_handler_wait_declares_wait_only() -> void:
	var cmd: AIActionCommand = AIActionCommand.wait(_UID_AI)
	_ai_stub.emit_ready(_UID_AI, cmd)
	await get_tree().process_frame

	assert_int(_turn_double.calls.size()).override_failure_message(
		("AC-4/WAIT: exactly 1 declare_action call expected; got %d")
		% _turn_double.calls.size()
	).is_equal(1)

	var call_action: int = _turn_double.calls[0].get("action", -1) as int
	assert_int(call_action).override_failure_message(
		("AC-4/WAIT: declare_action action must be WAIT (%d); got %d")
		% [TurnOrderRunner.ActionType.WAIT as int, call_action]
	).is_equal(TurnOrderRunner.ActionType.WAIT as int)

	assert_int(_unit_moved_log.size()).override_failure_message(
		"AC-4/WAIT: unit_moved must NOT fire on WAIT command"
	).is_equal(0)


# ── AC-5: MOVE handler ────────────────────────────────────────────────────────

## AC-5 (S15-B): MOVE command calls _do_move then declare_action(MOVE, target).
## AI unit at (0,0) moves to (2,0) — within move_range=2, passable, unoccupied.
## Given: ai_stub emits MOVE command targeting (2,0).
## When: await process_frame.
## Then: unit_moved emitted with from=(0,0) to=(2,0),
##       declare_action called with MOVE + target.target_position == (2,0).
func test_handler_move_executes_do_move_then_declares_move() -> void:
	var dest: Vector2i = Vector2i(2, 0)
	var cmd: AIActionCommand = AIActionCommand.move(_UID_AI, dest)
	_ai_stub.emit_ready(_UID_AI, cmd)
	await get_tree().process_frame

	# Assert unit_moved fired.
	assert_int(_unit_moved_log.size()).override_failure_message(
		("AC-5/MOVE: unit_moved must fire once after MOVE command; got %d emissions")
		% _unit_moved_log.size()
	).is_equal(1)

	var moved_from: Vector2i = _unit_moved_log[0].get("from", Vector2i(-1, -1)) as Vector2i
	var moved_to: Vector2i   = _unit_moved_log[0].get("to",   Vector2i(-1, -1)) as Vector2i

	assert_bool(moved_from == _POS_AI).override_failure_message(
		("AC-5/MOVE: unit_moved from must be %s; got %s")
		% [_POS_AI, moved_from]
	).is_true()

	assert_bool(moved_to == dest).override_failure_message(
		("AC-5/MOVE: unit_moved to must be %s; got %s")
		% [dest, moved_to]
	).is_true()

	# Assert declare_action called with MOVE + correct target position.
	assert_int(_turn_double.calls.size()).override_failure_message(
		("AC-5/MOVE: exactly 1 declare_action call expected; got %d")
		% _turn_double.calls.size()
	).is_equal(1)

	var call_action: int = _turn_double.calls[0].get("action", -1) as int
	assert_int(call_action).override_failure_message(
		("AC-5/MOVE: declare_action action must be MOVE (%d); got %d")
		% [TurnOrderRunner.ActionType.MOVE as int, call_action]
	).is_equal(TurnOrderRunner.ActionType.MOVE as int)

	var call_target: ActionTarget = _turn_double.calls[0].get("target", null) as ActionTarget
	assert_bool(call_target != null).override_failure_message(
		"AC-5/MOVE: declare_action ActionTarget must not be null"
	).is_true()

	assert_bool(call_target.target_position == dest).override_failure_message(
		("AC-5/MOVE: ActionTarget.target_position must be %s; got %s")
		% [dest, call_target.target_position]
	).is_true()


# ── AC-6: ATTACK handler ──────────────────────────────────────────────────────

## AC-6 (S15-B): ATTACK command calls _resolve_attack (which calls hp_stub.apply_damage)
## then declare_action(ATTACK, target).
## Defender is at (1,0), within attack_range=1 of AI unit at (0,0).
## Given: ai_stub emits ATTACK command targeting _UID_DEF.
## When: await process_frame.
## Then: hp_stub.damage_calls has 1 entry (defender took damage),
##       declare_action called with ATTACK + target.target_unit_id == _UID_DEF.
func test_handler_attack_executes_resolve_attack_then_declares_attack() -> void:
	var cmd: AIActionCommand = AIActionCommand.attack(_UID_AI, _UID_DEF)
	_ai_stub.emit_ready(_UID_AI, cmd)
	await get_tree().process_frame

	# Assert _hp_stub.apply_damage was called (damage was resolved).
	assert_int(_hp_stub.damage_calls.size()).override_failure_message(
		("AC-6/ATTACK: apply_damage must be called once for the defender; got %d calls")
		% _hp_stub.damage_calls.size()
	).is_equal(1)

	var dmg_uid: int = _hp_stub.damage_calls[0].get("unit_id", -1) as int
	assert_int(dmg_uid).override_failure_message(
		("AC-6/ATTACK: apply_damage must target _UID_DEF (%d); got unit_id=%d")
		% [_UID_DEF, dmg_uid]
	).is_equal(_UID_DEF)

	# Assert declare_action called with ATTACK.
	assert_int(_turn_double.calls.size()).override_failure_message(
		("AC-6/ATTACK: exactly 1 declare_action call expected; got %d")
		% _turn_double.calls.size()
	).is_equal(1)

	var call_action: int = _turn_double.calls[0].get("action", -1) as int
	assert_int(call_action).override_failure_message(
		("AC-6/ATTACK: declare_action action must be ATTACK (%d); got %d")
		% [TurnOrderRunner.ActionType.ATTACK as int, call_action]
	).is_equal(TurnOrderRunner.ActionType.ATTACK as int)

	var call_target: ActionTarget = _turn_double.calls[0].get("target", null) as ActionTarget
	assert_bool(call_target != null).override_failure_message(
		"AC-6/ATTACK: declare_action ActionTarget must not be null"
	).is_true()

	assert_int(call_target.target_unit_id).override_failure_message(
		("AC-6/ATTACK: ActionTarget.target_unit_id must be _UID_DEF (%d); got %d")
		% [_UID_DEF, call_target.target_unit_id]
	).is_equal(_UID_DEF)


# ── AC-7: MOVE_AND_ATTACK handler ────────────────────────────────────────────

## AC-7 (S15-B): MOVE_AND_ATTACK results in exactly 2 declare_action calls:
## first MOVE, then ATTACK.
## AI unit at (0,0) moves to (0,1) (range-check: Manhattan=1, passable), then
## attacks defender at (1,0) (within attack_range=1 from (0,1): Manhattan=1, enemy side).
## Given: ai_stub emits MOVE_AND_ATTACK with move_target=(0,1), attack_target=_UID_DEF.
## When: await process_frame.
## Then: _turn_double.calls.size() == 2,
##       calls[0].action == MOVE, calls[1].action == ATTACK.
func test_handler_move_and_attack_declares_move_then_attack_in_order() -> void:
	var move_dest: Vector2i = Vector2i(0, 1)
	var cmd: AIActionCommand = AIActionCommand.move_and_attack(_UID_AI, move_dest, _UID_DEF)
	_ai_stub.emit_ready(_UID_AI, cmd)
	await get_tree().process_frame

	assert_int(_turn_double.calls.size()).override_failure_message(
		("AC-7/MOVE_AND_ATTACK: exactly 2 declare_action calls expected (MOVE then ATTACK); "
		+ "got %d")
		% _turn_double.calls.size()
	).is_equal(2)

	var first_action: int  = _turn_double.calls[0].get("action", -1) as int
	var second_action: int = _turn_double.calls[1].get("action", -1) as int

	assert_int(first_action).override_failure_message(
		("AC-7/MOVE_AND_ATTACK: calls[0].action must be MOVE (%d); got %d")
		% [TurnOrderRunner.ActionType.MOVE as int, first_action]
	).is_equal(TurnOrderRunner.ActionType.MOVE as int)

	assert_int(second_action).override_failure_message(
		("AC-7/MOVE_AND_ATTACK: calls[1].action must be ATTACK (%d); got %d")
		% [TurnOrderRunner.ActionType.ATTACK as int, second_action]
	).is_equal(TurnOrderRunner.ActionType.ATTACK as int)


# ── AC-8: DEFEND handler ──────────────────────────────────────────────────────

## AC-8 (S15-B): DEFEND command calls declare_action(DEFEND, null) — not WAIT.
## This is the Task A fix validation test (DEFEND used to substitute WAIT).
## Given: ai_stub emits DEFEND command for _UID_AI.
## When: await process_frame.
## Then: _turn_double.calls[0].action == TurnOrderRunner.ActionType.DEFEND.
func test_handler_defend_declares_defend() -> void:
	var cmd: AIActionCommand = AIActionCommand.defend(_UID_AI)
	_ai_stub.emit_ready(_UID_AI, cmd)
	await get_tree().process_frame

	assert_int(_turn_double.calls.size()).override_failure_message(
		("AC-8/DEFEND: exactly 1 declare_action call expected; got %d")
		% _turn_double.calls.size()
	).is_equal(1)

	var call_action: int = _turn_double.calls[0].get("action", -1) as int
	assert_int(call_action).override_failure_message(
		("AC-8/DEFEND: declare_action action must be DEFEND (%d), NOT WAIT; got %d "
		+ "— Task A DEFEND fix regression check")
		% [TurnOrderRunner.ActionType.DEFEND as int, call_action]
	).is_equal(TurnOrderRunner.ActionType.DEFEND as int)


# ── AC-9: USE_SKILL handler substitutes WAIT ──────────────────────────────────

## AC-9 (S15-B): USE_SKILL command substitutes WAIT per ADR-0014 §0 MVP scope.
## Given: ai_stub emits USE_SKILL command for _UID_AI.
## When: await process_frame.
## Then: _turn_double.calls[0].action == WAIT (not USE_SKILL — not a TurnOrderRunner type).
func test_handler_use_skill_substitutes_wait() -> void:
	var cmd: AIActionCommand = AIActionCommand.use_skill(_UID_AI, &"rally")
	_ai_stub.emit_ready(_UID_AI, cmd)
	await get_tree().process_frame

	assert_int(_turn_double.calls.size()).override_failure_message(
		("AC-9/USE_SKILL: exactly 1 declare_action call expected (substituted WAIT); got %d")
		% _turn_double.calls.size()
	).is_equal(1)

	var call_action: int = _turn_double.calls[0].get("action", -1) as int
	assert_int(call_action).override_failure_message(
		("AC-9/USE_SKILL: action must be WAIT (%d) per MVP substitution; got %d")
		% [TurnOrderRunner.ActionType.WAIT as int, call_action]
	).is_equal(TurnOrderRunner.ActionType.WAIT as int)


# ── AC-10: Unknown unit_id is a no-op ────────────────────────────────────────

## AC-10 (S15-B): Command for a unit_id not in the controller registry is silently ignored.
## Given: ai_stub emits WAIT command for unit_id=999 (not in registry).
## When: await process_frame.
## Then: _turn_double.calls is empty (no declare_action call).
func test_handler_unknown_unit_id_no_dispatch() -> void:
	var cmd: AIActionCommand = AIActionCommand.wait(999)
	_ai_stub.emit_ready(999, cmd)
	await get_tree().process_frame

	assert_int(_turn_double.calls.size()).override_failure_message(
		("AC-10/UNKNOWN_UID: no declare_action call expected for unregistered unit_id=999; "
		+ "got %d calls — unknown_unit_id guard not executing")
		% _turn_double.calls.size()
	).is_equal(0)


# ── AC-11: _battle_over early-return guard ───────────────────────────────────

## AC-11 (S15-B /code-review qa-tester MUST-ADD #2): _battle_over early-return.
## Given: controller has _battle_over flipped to true (terminal-state guard).
## When: ai_stub emits a WAIT command for a registered unit_id.
## Then: _turn_double.calls remains empty (no declare_action dispatch).
##
## Mirrors _on_round_started and other terminal-state-guarded handlers per
## ADR-0014 §7. Without this guard, post-victory AI emissions would still
## consume turn tokens — silently corrupting the resolved-battle state.
func test_handler_battle_over_early_return_no_dispatch() -> void:
	# Force terminal-state via direct field write (test-seam access).
	_controller._battle_over = true
	var cmd: AIActionCommand = AIActionCommand.wait(_UID_AI)
	_ai_stub.emit_ready(_UID_AI, cmd)
	await get_tree().process_frame

	assert_int(_turn_double.calls.size()).override_failure_message(
		("AC-11/BATTLE_OVER: no declare_action call expected when _battle_over=true; "
		+ "got %d calls — early-return guard not executing")
		% _turn_double.calls.size()
	).is_equal(0)


# ── AC-12: null command guard ────────────────────────────────────────────────

## AC-12 (S15-B /code-review qa-tester MUST-ADD #3): null command guard.
## Given: controller is in live-battle state with registered AI unit.
## When: ai_stub emits ai_action_ready with a NULL command payload.
## Then: _turn_double.calls remains empty + push_warning fires (not asserted
##       directly — see G-22 family: stderr scan would couple test to engine
##       internals; behavioural assertion (no dispatch) is sufficient).
##
## A null command would crash the match-on-action_type access if not guarded.
## This test pins the guard so removal of `if command == null:` is a
## detectable regression.
func test_handler_null_command_no_dispatch() -> void:
	_ai_stub.ai_action_ready.emit(_UID_AI, null)
	await get_tree().process_frame

	assert_int(_turn_double.calls.size()).override_failure_message(
		("AC-12/NULL_CMD: no declare_action call expected for null command; "
		+ "got %d calls — null-command guard not executing")
		% _turn_double.calls.size()
	).is_equal(0)
