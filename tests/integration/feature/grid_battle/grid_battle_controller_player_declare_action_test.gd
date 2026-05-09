extends GdUnitTestSuite

## grid_battle_controller_player_declare_action_test.gd
## Integration tests for Story S15-C (POLISH-011 absorption #3 of 3):
##   AC-7 (S15-C): Player grid-click action arms dispatch correctly-typed
##   declare_action calls via the new _handle_player_move / _handle_player_attack /
##   _handle_player_end_turn helpers.
##
## Tests (7):
##   1. test_move_target_select_dispatches_move_token
##   2. test_attack_target_select_dispatches_attack_token
##   3. test_move_confirm_aliases_move_target_select_dispatch
##   4. test_attack_confirm_aliases_attack_target_select_dispatch
##   5. test_end_unit_turn_declares_wait_for_unacted_units_then_calls_end_player_turn
##   6. test_re_entrancy_guard_prevents_double_dispatch_in_same_turn
##   7. test_backward_compat_handle_move_directly_still_declares_attack_token
##
## Test type: Integration — drives GridBattleController.handle_grid_click() directly
## to verify player-path dispatch arm rewiring (S15-C) without GameBus dependency.
##
## Governing ADRs:
##   ADR-0014 §Amendment 2026-05-10 (#2) — player-path mirror helpers
##   ADR-0014 §6 (story-006) — _consume_unit_action backward compat
##   ADR-0011 §Amendment 2026-05-09 — T5 await declare_action semantics
##
## GOTCHA AWARENESS (see .claude/rules/godot-4x-gotchas.md):
##   G-4  — lambda primitive capture trap; use Array[Dictionary] captures pattern
##   G-6  — orphan detection fires before after_test; explicit cleanup in body
##   G-8  — Signal.get_connections() returns untyped Array
##   G-11 — is_instance_valid guard before as Node cast
##   G-15 — before_test() canonical hook (NOT before_each)
##   G-16 — typed Array[Dictionary] for signal log
##   G-22 — @abstract requires concrete subclass for instantiation in tests
##   G-26 — inner class names prefixed GBCP* to avoid global class_name collision
##   G-28 — never bulk-disconnect-all; only disconnect test-owned callables


# ── Inner test doubles (G-26: prefixed GBCP* to avoid global class_name collision) ──

## TurnOrderRunner double — records all declare_action calls.
## Extends TurnOrderRunner (registered global class_name) to satisfy typed field.
class GBCPTurnRunnerDouble extends TurnOrderRunner:
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
class GBCPHPControllerStub extends HPStatusController:
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
class GBCPUnitRoleStub extends UnitRole:
	pass


## Concrete HeroDatabase subclass — bypasses @abstract parse-time block (G-22).
## Empty body OK because controller stores the ref + asserts non-null;
## all HeroDatabase API is static (called as `HeroDatabase.get_hero(...)` etc).
class GBCPHeroDatabaseStub extends HeroDatabase:
	pass


# ── Constants ─────────────────────────────────────────────────────────────────

## Player-controlled unit that will act. side=0, at (0,0).
const _UID_PLAYER: int = 20
## Second player-controlled unit (for multi-unit end-turn test). side=0, at (2,0).
const _UID_PLAYER_2: int = 21
## Enemy unit (attack target). side=1, at (1,0) — adjacent to _UID_PLAYER.
const _UID_ENEMY: int = 22

## Start positions.
const _POS_PLAYER:   Vector2i = Vector2i(0, 0)
const _POS_PLAYER_2: Vector2i = Vector2i(2, 0)
const _POS_ENEMY:    Vector2i = Vector2i(1, 0)

## A passable tile within move range (distance 2 from PLAYER, unoccupied).
const _POS_MOVE_DEST: Vector2i = Vector2i(0, 2)


# ── Suite state ───────────────────────────────────────────────────────────────

var _controller: GridBattleController
var _turn_double: GBCPTurnRunnerDouble
var _hp_stub: GBCPHPControllerStub
var _map_grid: MapGrid
var _unit_moved_log: Array[Dictionary] = []  ## G-4: Array captures for unit_moved signal


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func before_test() -> void:
	## G-15: canonical per-test setup hook (NOT before_each).
	## Builds a 3-unit fixture: 2 player units + 1 enemy unit.
	## Controller is wired with stub dependencies and put into UNIT_SELECTED state.
	_unit_moved_log.clear()

	# Build a minimal 15×15 MapGrid.
	_map_grid = auto_free(MapGrid.new())
	add_child(_map_grid)
	_build_minimal_map(_map_grid, 15, 15)

	# Build units.
	var player_unit: BattleUnit   = _make_unit(_UID_PLAYER,   true,  0, _POS_PLAYER,   2, 1)
	var player_unit_2: BattleUnit = _make_unit(_UID_PLAYER_2, true,  0, _POS_PLAYER_2, 2, 1)
	var enemy_unit: BattleUnit    = _make_unit(_UID_ENEMY,    false, 1, _POS_ENEMY,    2, 1)

	# Build doubles.
	_turn_double = auto_free(GBCPTurnRunnerDouble.new())
	add_child(_turn_double)

	_hp_stub = auto_free(GBCPHPControllerStub.new())
	add_child(_hp_stub)

	# Minimal stubs for non-exercised DI deps.
	var terrain_stub: TerrainEffect = auto_free(TerrainEffect.new())
	var unit_role_stub: UnitRole    = auto_free(GBCPUnitRoleStub.new())
	var hero_db_stub: HeroDatabase  = auto_free(GBCPHeroDatabaseStub.new())
	var camera_stub: BattleCamera   = auto_free(BattleCamera.new())

	_controller = auto_free(GridBattleController.new())
	_controller.setup(
		[player_unit, player_unit_2, enemy_unit],
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

	# Drive controller into UNIT_SELECTED state with _UID_PLAYER selected.
	# handle_grid_click is public per ADR-0014 §4 + story-003 AC-5.
	_controller.handle_grid_click("unit_select", _POS_PLAYER, _UID_PLAYER)


func after_test() -> void:
	## G-15: explicit cleanup.
	## Disconnect only test-side captures per G-28 (never bulk-disconnect-all).
	if is_instance_valid(_controller):
		if _controller.unit_moved.is_connected(_capture_unit_moved):
			_controller.unit_moved.disconnect(_capture_unit_moved)


# ── Signal capture (method-reference form — sidesteps G-4) ───────────────────

func _capture_unit_moved(unit_id: int, from: Vector2i, to: Vector2i) -> void:
	_unit_moved_log.append({"unit_id": unit_id, "from": from, "to": to})


# ── Helpers ───────────────────────────────────────────────────────────────────

## Builds a minimal map: all passable PLAINS tiles, occupants cleared.
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
	grid.set_occupant(_POS_PLAYER,   _UID_PLAYER,   MapGrid.FACTION_ALLY)
	grid.set_occupant(_POS_PLAYER_2, _UID_PLAYER_2, MapGrid.FACTION_ALLY)
	grid.set_occupant(_POS_ENEMY,    _UID_ENEMY,    MapGrid.FACTION_ENEMY)


func _make_unit(
	unit_id: int,
	is_player: bool,
	side: int,
	pos: Vector2i,
	move_range: int,
	attack_range: int,
) -> BattleUnit:
	var u: BattleUnit = BattleUnit.new()
	u.unit_id              = unit_id
	u.is_player_controlled = is_player
	u.side                 = side
	u.position             = pos
	u.move_range           = move_range
	u.attack_range         = attack_range
	u.raw_atk              = 10
	u.raw_def              = 5
	u.facing               = 1  # East
	return u


# ── Test 1: move_target_select dispatches MOVE token ─────────────────────────

## AC-7 (S15-C) Test 1: move_target_select arm dispatches _handle_player_move,
## which calls declare_action with correctly-typed MOVE token (not ATTACK).
## Given: player unit selected (UNIT_SELECTED state, done in before_test).
## When: handle_grid_click("move_target_select", valid_dest, 0) is driven.
## Then: exactly 1 declare_action call with action == MOVE and matching position.
##       unit_moved fires (via _do_move inside _handle_player_move).
##       _handle_move wrapper is NOT in the path — sole-call discipline; no ATTACK token.
func test_move_target_select_dispatches_move_token() -> void:
	_controller.handle_grid_click("move_target_select", _POS_MOVE_DEST, 0)

	# Assert exactly 1 declare_action call with MOVE type.
	assert_int(_turn_double.calls.size()).override_failure_message(
		("Test1/move_target_select: exactly 1 declare_action call expected; got %d")
		% _turn_double.calls.size()
	).is_equal(1)

	var call_action: int = _turn_double.calls[0].get("action", -1) as int
	assert_int(call_action).override_failure_message(
		("Test1/move_target_select: declare_action must be MOVE (%d), not ATTACK (%d); got %d "
		+ "— player-path arm must call _handle_player_move not _handle_move")
		% [TurnOrderRunner.ActionType.MOVE as int, TurnOrderRunner.ActionType.ATTACK as int, call_action]
	).is_equal(TurnOrderRunner.ActionType.MOVE as int)

	# Assert target position is correct.
	var call_target: ActionTarget = _turn_double.calls[0].get("target", null) as ActionTarget
	assert_bool(call_target != null).override_failure_message(
		"Test1/move_target_select: ActionTarget must not be null"
	).is_true()

	assert_bool((call_target.target_position) == _POS_MOVE_DEST).override_failure_message(
		("Test1/move_target_select: ActionTarget.target_position must be %s; got %s")
		% [_POS_MOVE_DEST, call_target.target_position]
	).is_true()

	# Assert unit_moved fired (confirms _do_move executed, not just the wrapper).
	assert_int(_unit_moved_log.size()).override_failure_message(
		"Test1/move_target_select: unit_moved must fire once (confirms _do_move ran)"
	).is_equal(1)


# ── Test 2: attack_target_select dispatches ATTACK token ─────────────────────

## AC-7 (S15-C) Test 2: attack_target_select arm dispatches _handle_player_attack,
## which calls declare_action with correctly-typed ATTACK token.
## Enemy is at (1,0), within attack_range=1 of player at (0,0).
## Given: player unit selected (done in before_test).
## When: handle_grid_click("attack_target_select", _POS_ENEMY, _UID_ENEMY).
## Then: exactly 1 declare_action call with action == ATTACK and target_unit_id == _UID_ENEMY.
##       hp_stub.apply_damage called once for the enemy (damage resolved).
func test_attack_target_select_dispatches_attack_token() -> void:
	_controller.handle_grid_click("attack_target_select", _POS_ENEMY, _UID_ENEMY)

	# Assert exactly 1 declare_action call with ATTACK type.
	assert_int(_turn_double.calls.size()).override_failure_message(
		("Test2/attack_target_select: exactly 1 declare_action call expected; got %d")
		% _turn_double.calls.size()
	).is_equal(1)

	var call_action: int = _turn_double.calls[0].get("action", -1) as int
	assert_int(call_action).override_failure_message(
		("Test2/attack_target_select: declare_action must be ATTACK (%d); got %d")
		% [TurnOrderRunner.ActionType.ATTACK as int, call_action]
	).is_equal(TurnOrderRunner.ActionType.ATTACK as int)

	# Assert target_unit_id is the enemy.
	var call_target: ActionTarget = _turn_double.calls[0].get("target", null) as ActionTarget
	assert_bool(call_target != null).override_failure_message(
		"Test2/attack_target_select: ActionTarget must not be null"
	).is_true()

	assert_int(call_target.target_unit_id).override_failure_message(
		("Test2/attack_target_select: ActionTarget.target_unit_id must be _UID_ENEMY (%d); got %d")
		% [_UID_ENEMY, call_target.target_unit_id]
	).is_equal(_UID_ENEMY)

	# Assert damage was applied (confirms _resolve_attack ran).
	assert_int(_hp_stub.damage_calls.size()).override_failure_message(
		"Test2/attack_target_select: apply_damage must be called once for the enemy"
	).is_equal(1)


# ── Test 3: move_confirm aliases move_target_select dispatch ──────────────────

## AC-7 (S15-C) Test 3: "move_confirm" action invokes the same handler as
## "move_target_select" — both are in the same match arm → same dispatch path.
## Given: player unit selected (done in before_test).
## When: handle_grid_click("move_confirm", _POS_MOVE_DEST, 0).
## Then: exactly 1 declare_action call with action == MOVE.
func test_move_confirm_aliases_move_target_select_dispatch() -> void:
	_controller.handle_grid_click("move_confirm", _POS_MOVE_DEST, 0)

	assert_int(_turn_double.calls.size()).override_failure_message(
		("Test3/move_confirm: exactly 1 declare_action call expected; got %d")
		% _turn_double.calls.size()
	).is_equal(1)

	var call_action: int = _turn_double.calls[0].get("action", -1) as int
	assert_int(call_action).override_failure_message(
		("Test3/move_confirm: declare_action must be MOVE (%d); got %d")
		% [TurnOrderRunner.ActionType.MOVE as int, call_action]
	).is_equal(TurnOrderRunner.ActionType.MOVE as int)


# ── Test 4: attack_confirm aliases attack_target_select dispatch ──────────────

## AC-7 (S15-C) Test 4: "attack_confirm" action invokes the same handler as
## "attack_target_select" — both are in the same match arm → same dispatch path.
## Given: player unit selected (done in before_test).
## When: handle_grid_click("attack_confirm", _POS_ENEMY, _UID_ENEMY).
## Then: exactly 1 declare_action call with action == ATTACK.
func test_attack_confirm_aliases_attack_target_select_dispatch() -> void:
	_controller.handle_grid_click("attack_confirm", _POS_ENEMY, _UID_ENEMY)

	assert_int(_turn_double.calls.size()).override_failure_message(
		("Test4/attack_confirm: exactly 1 declare_action call expected; got %d")
		% _turn_double.calls.size()
	).is_equal(1)

	var call_action: int = _turn_double.calls[0].get("action", -1) as int
	assert_int(call_action).override_failure_message(
		("Test4/attack_confirm: declare_action must be ATTACK (%d); got %d")
		% [TurnOrderRunner.ActionType.ATTACK as int, call_action]
	).is_equal(TurnOrderRunner.ActionType.ATTACK as int)


# ── Test 5: end_unit_turn declares WAIT for unacted units ─────────────────────

## AC-7 (S15-C) Test 5: end_unit_turn arm dispatches _handle_player_end_turn.
## Fixture has 2 player units; _UID_PLAYER is selected (before_test puts it in
## UNIT_SELECTED). Neither has acted yet.
##
## Given: both player units have NOT acted (_acted_this_turn empty).
## When: handle_grid_click("end_unit_turn", ...) from UNIT_SELECTED state.
## Then: WAIT declared for BOTH player units (2 declare_action calls with WAIT).
##       end_player_turn() side-effect: selection cleared (_selected_unit_id == -1).
##       No WAIT declared for the enemy unit (side==1 excluded).
func test_end_unit_turn_declares_wait_for_unacted_units_then_calls_end_player_turn() -> void:
	# Before: both player units unacted. Confirm selection state.
	assert_int(_controller.get_selected_unit_id()).override_failure_message(
		"Test5/precondition: _UID_PLAYER must be selected before end_unit_turn"
	).is_equal(_UID_PLAYER)

	_controller.handle_grid_click("end_unit_turn", Vector2i.ZERO, 0)

	# Assert 2 WAIT declare_action calls — one per player unit.
	assert_int(_turn_double.calls.size()).override_failure_message(
		("Test5/end_unit_turn: 2 WAIT declare_action calls expected (one per unacted player unit); "
		+ "got %d — _handle_player_end_turn may not be wired")
		% _turn_double.calls.size()
	).is_equal(2)

	for i in range(2):
		var call_action: int = _turn_double.calls[i].get("action", -1) as int
		var call_uid: int = _turn_double.calls[i].get("unit_id", -1) as int
		assert_int(call_action).override_failure_message(
			("Test5/end_unit_turn: declare_action[%d] must be WAIT (%d); got %d for unit_id=%d")
			% [i, TurnOrderRunner.ActionType.WAIT as int, call_action, call_uid]
		).is_equal(TurnOrderRunner.ActionType.WAIT as int)

	# Assert enemy unit was NOT given WAIT.
	var enemy_wait_calls: int = 0
	for call: Dictionary in _turn_double.calls:
		if (call.get("unit_id", -1) as int) == _UID_ENEMY:
			enemy_wait_calls += 1
	assert_int(enemy_wait_calls).override_failure_message(
		"Test5/end_unit_turn: enemy unit must NOT receive a WAIT declare_action call"
	).is_equal(0)

	# Assert end_player_turn() side-effect: selection cleared.
	assert_int(_controller.get_selected_unit_id()).override_failure_message(
		("Test5/end_unit_turn: end_player_turn() must clear selection (get_selected_unit_id "
		+ "must be -1 after end_unit_turn); got %d")
		% _controller.get_selected_unit_id()
	).is_equal(-1)


# ── Test 6: re-entrancy guard prevents double dispatch ────────────────────────

## AC-7 (S15-C) Test 6: calling move_target_select twice for the same unit in
## the same turn must result in only 1 declare_action call (re-entrancy guard).
## Given: player unit selected; first move_target_select succeeds.
## When: move_target_select called a second time (same or different dest).
## Then: still exactly 1 declare_action call total (guard fires on second call).
func test_re_entrancy_guard_prevents_double_dispatch_in_same_turn() -> void:
	# First dispatch — should succeed.
	_controller.handle_grid_click("move_target_select", _POS_MOVE_DEST, 0)

	# The unit has now acted; re-enter UNIT_SELECTED state by re-selecting
	# (note: after _handle_player_move the controller may remain in UNIT_SELECTED
	# since _handle_player_move does NOT call _deselect — it only sets _acted_this_turn).
	# Drive a second move_target_select; _handle_player_move's re-entrancy guard fires.
	_controller.handle_grid_click("move_target_select", Vector2i(0, 1), 0)

	# Must still be exactly 1 declare_action call.
	assert_int(_turn_double.calls.size()).override_failure_message(
		("Test6/re-entrancy: re-entrancy guard must prevent second dispatch; "
		+ "expected 1 declare_action call, got %d")
		% _turn_double.calls.size()
	).is_equal(1)


# ── Test 7: backward compat — _handle_move still declares ATTACK token ────────

## AC-7 (S15-C) Test 7: backward-compatibility regression sentinel.
## Direct call to _handle_move(unit, dest) (bypassing the dispatch arm)
## must still trigger _consume_unit_action → declare_action(ATTACK, null)
## per story-006 contract. This test pins that _handle_move and
## _consume_unit_action are UNCHANGED so existing story-004/005/006 tests
## continue to pass (AC-5 backward compat).
##
## Per ADR-0014 §Amendment 2026-05-10 (#2) Out-of-Scope: "Token ADR convergence
## (post-MVP; will eventually retire _consume_unit_action)". Until then,
## _handle_move's path via _consume_unit_action must remain ATTACK.
func test_backward_compat_handle_move_directly_still_declares_attack_token() -> void:
	# Access units directly from controller's registry via public get_battle_unit().
	var player_unit: BattleUnit = _controller.get_battle_unit(_UID_PLAYER)
	assert_bool(player_unit != null).override_failure_message(
		"Test7/backward_compat: get_battle_unit must return non-null for _UID_PLAYER"
	).is_true()

	# Call _handle_move directly — bypasses dispatch arm, uses old wrapper path.
	_controller._handle_move(player_unit, _POS_MOVE_DEST)

	# Assert exactly 1 declare_action call with ATTACK type (story-006 token).
	assert_int(_turn_double.calls.size()).override_failure_message(
		("Test7/backward_compat: _handle_move must produce exactly 1 declare_action call "
		+ "via _consume_unit_action; got %d — backward-compat regression")
		% _turn_double.calls.size()
	).is_equal(1)

	var call_action: int = _turn_double.calls[0].get("action", -1) as int
	assert_int(call_action).override_failure_message(
		("Test7/backward_compat: _handle_move path must declare ATTACK (%d) via "
		+ "_consume_unit_action (story-006 single-token simplification); got %d "
		+ "— if this changed, ADR-0014 §6 + story-006 backward compat is broken")
		% [TurnOrderRunner.ActionType.ATTACK as int, call_action]
	).is_equal(TurnOrderRunner.ActionType.ATTACK as int)

	# unit_moved must also have fired (the actual move still executes).
	assert_int(_unit_moved_log.size()).override_failure_message(
		"Test7/backward_compat: unit_moved must fire once (move was executed by _handle_move)"
	).is_equal(1)
