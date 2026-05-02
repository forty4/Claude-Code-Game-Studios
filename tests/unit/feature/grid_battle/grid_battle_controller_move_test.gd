## Move action tests for GridBattleController per ADR-0014 §10 + story-004.
##
## Story-004 AC-1..AC-9: is_tile_in_move_range (Manhattan + occupancy + passable)
## + _handle_move (validation + apply + consume) + _do_move (position + facing +
## MapGrid bookkeeping) + unit_moved signal emit + re-entrancy guard.

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
	(load("res://src/foundation/balance/balance_constants.gd") as GDScript).set("_cache_loaded", false)


# ─── Helpers ────────────────────────────────────────────────────────────────

func _make_unit(unit_id: int, pos: Vector2i, move_range: int, side: int = 0) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.position = pos
	unit.move_range = move_range
	unit.side = side
	unit.facing = 0  # N
	return unit


func _setup(roster: Array[BattleUnit]) -> Dictionary:
	# Returns dict containing the controller + map_grid stub for tests that need
	# to drive the stub (set_occupant_for_test, set_passable_for_test).
	var map_grid: MapGridStub = MapGridStubScript.new()
	map_grid.set_dimensions_for_test(Vector2i(8, 8))
	auto_free(map_grid)
	var camera: BattleCameraStub = BattleCameraStubScript.new()
	auto_free(camera)
	var hero_db: HeroDatabaseStub = HeroDatabaseStubScript.new()
	var turn_runner: TurnOrderRunnerStub = TurnOrderRunnerStubScript.new()
	auto_free(turn_runner)
	var hp_controller: HPStatusControllerStub = HPStatusControllerStubScript.new()
	auto_free(hp_controller)
	var terrain_effect: TerrainEffectStub = TerrainEffectStubScript.new()
	var unit_role: UnitRoleStub = UnitRoleStubScript.new()
	var controller: GridBattleController = GridBattleControllerScript.new()
	auto_free(controller)
	controller.setup(roster, map_grid, camera, hero_db, turn_runner, hp_controller, terrain_effect, unit_role)
	return {"controller": controller, "map_grid": map_grid}


# ─── AC-1, AC-2: is_tile_in_move_range validation matrix ───────────────────

func test_is_tile_in_move_range_valid_destination_returns_true() -> void:
	# Unit at (1, 2) with move_range=3; destination (2, 3) → Manhattan=2 ≤ 3,
	# unoccupied, passable.
	var unit: BattleUnit = _make_unit(1, Vector2i(1, 2), 3)
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]

	assert_bool(controller.is_tile_in_move_range(Vector2i(2, 3), 1)).is_true()


func test_is_tile_in_move_range_out_of_range_returns_false() -> void:
	# Unit at (1, 2) with move_range=2; destination (5, 5) → Manhattan=7 > 2.
	var unit: BattleUnit = _make_unit(1, Vector2i(1, 2), 2)
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]

	assert_bool(controller.is_tile_in_move_range(Vector2i(5, 5), 1)).is_false()


func test_is_tile_in_move_range_zero_distance_returns_false() -> void:
	# Unit's current tile is not a valid move target (Manhattan == 0).
	var unit: BattleUnit = _make_unit(1, Vector2i(1, 2), 3)
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]

	assert_bool(controller.is_tile_in_move_range(Vector2i(1, 2), 1)).is_false()


func test_is_tile_in_move_range_occupied_tile_returns_false() -> void:
	# Tile (2, 3) is occupied by some other unit (id=99) — fails check.
	var unit: BattleUnit = _make_unit(1, Vector2i(1, 2), 3)
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]
	(bag["map_grid"] as MapGridStub).set_occupant_for_test(Vector2i(2, 3), 99)

	assert_bool(controller.is_tile_in_move_range(Vector2i(2, 3), 1)).is_false()


func test_is_tile_in_move_range_impassable_tile_returns_false() -> void:
	# Tile (2, 3) is RIVER (is_passable_base=false) — fails check.
	var unit: BattleUnit = _make_unit(1, Vector2i(1, 2), 3)
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]
	(bag["map_grid"] as MapGridStub).set_passable_for_test(Vector2i(2, 3), false)

	assert_bool(controller.is_tile_in_move_range(Vector2i(2, 3), 1)).is_false()


func test_is_tile_in_move_range_unknown_unit_id_returns_false() -> void:
	# Unit not in registry — defensive false return.
	var unit: BattleUnit = _make_unit(1, Vector2i(1, 2), 3)
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]

	assert_bool(controller.is_tile_in_move_range(Vector2i(2, 3), 999)).is_false()


# ─── AC-4, AC-5, AC-7: _do_move position + facing + MapGrid + signal ───────

func test_do_move_updates_position_and_facing_and_emits_signal() -> void:
	var unit: BattleUnit = _make_unit(1, Vector2i(1, 2), 3)
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]
	var map_grid: MapGridStub = bag["map_grid"]
	var captures: Array = []
	controller.unit_moved.connect(func(unit_id: int, from: Vector2i, to: Vector2i) -> void:
		captures.append({"unit_id": unit_id, "from": from, "to": to})
	)

	controller._do_move(unit, Vector2i(2, 3))

	# Position update
	assert_vector(unit.position).is_equal(Vector2i(2, 3))
	# Facing: from (1,2) to (2,3) → dx=1, dy=1; tie → X-axis wins → E (1)
	assert_int(unit.facing).is_equal(1)
	# MapGrid bookkeeping: clear_occupant + set_occupant called in correct order
	assert_int(map_grid.clear_occupant_calls.size()).is_equal(1)
	assert_vector(map_grid.clear_occupant_calls[0]).is_equal(Vector2i(1, 2))
	assert_int(map_grid.set_occupant_calls.size()).is_equal(1)
	assert_vector(map_grid.set_occupant_calls[0]["coord"] as Vector2i).is_equal(Vector2i(2, 3))
	assert_int(map_grid.set_occupant_calls[0]["unit_id"] as int).is_equal(1)
	assert_int(map_grid.set_occupant_calls[0]["faction"] as int).is_equal(MapGrid.FACTION_ALLY)
	# Signal emission per AC-5 + AC-7 (exactly 1 emit with correct tuple)
	assert_int(captures.size()).is_equal(1)
	assert_int(captures[0].unit_id as int).is_equal(1)
	assert_vector(captures[0].from as Vector2i).is_equal(Vector2i(1, 2))
	assert_vector(captures[0].to as Vector2i).is_equal(Vector2i(2, 3))


# ─── _direction_from_to: 4-cardinal tie-break verification ──────────────────

func test_direction_from_to_resolves_4_cardinal_directions() -> void:
	var unit: BattleUnit = _make_unit(1, Vector2i(0, 0), 3)
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]

	# E (dx > 0, dx ≥ |dy|)
	assert_int(controller._direction_from_to(Vector2i(0, 0), Vector2i(2, 1))).is_equal(1)
	# W (dx < 0, |dx| ≥ |dy|)
	assert_int(controller._direction_from_to(Vector2i(0, 0), Vector2i(-2, 1))).is_equal(3)
	# S (dy > 0, |dy| > |dx|)
	assert_int(controller._direction_from_to(Vector2i(0, 0), Vector2i(0, 2))).is_equal(2)
	# N (dy < 0, |dy| > |dx|)
	assert_int(controller._direction_from_to(Vector2i(0, 0), Vector2i(0, -2))).is_equal(0)


# ─── AC-3: _handle_move validates + applies + consumes (full chain) ────────

func test_handle_move_full_chain_valid_target() -> void:
	var unit: BattleUnit = _make_unit(1, Vector2i(1, 2), 3)
	# Story-006: 2nd alive player unit gates auto-handoff so _acted_this_turn
	# persists for assertion. Without it, _any_player_unit_can_act returns false
	# after unit 1 acts → end_player_turn → _acted_this_turn cleared.
	var ally: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([unit, ally])
	var controller: GridBattleController = bag["controller"]

	controller._handle_move(unit, Vector2i(2, 3))

	# Position updated
	assert_vector(unit.position).is_equal(Vector2i(2, 3))
	# Acted-this-turn populated by _consume_unit_action
	assert_bool(controller._acted_this_turn.get(1, false)).is_true()


# ─── AC-3: _handle_move silent on invalid target ───────────────────────────

func test_handle_move_invalid_target_silent_no_op() -> void:
	# Out-of-range destination → _handle_move silently returns.
	var unit: BattleUnit = _make_unit(1, Vector2i(1, 2), 1)  # move_range=1
	var bag: Dictionary = _setup([unit])
	var controller: GridBattleController = bag["controller"]
	var captures: Array = []
	controller.unit_moved.connect(func(unit_id: int, from: Vector2i, to: Vector2i) -> void:
		captures.append({"unit_id": unit_id})
	)

	controller._handle_move(unit, Vector2i(5, 5))  # Manhattan=7 > 1

	# Position unchanged
	assert_vector(unit.position).is_equal(Vector2i(1, 2))
	# No signal
	assert_int(captures.size()).is_equal(0)
	# Not consumed (validation failed before _consume_unit_action)
	assert_bool(controller._acted_this_turn.get(1, false)).is_false()


# ─── AC-8: re-entrancy guard — second call same turn silent no-op ─────────

func test_handle_move_re_entrancy_guard_silent_after_act() -> void:
	# First call moves successfully; second call same turn → silent no-op.
	var unit: BattleUnit = _make_unit(1, Vector2i(1, 2), 3)
	# Story-006: 2nd alive player unit gates auto-handoff so _acted_this_turn
	# is preserved between the two _handle_move calls.
	var ally: BattleUnit = _make_unit(2, Vector2i(7, 7), 1)
	var bag: Dictionary = _setup([unit, ally])
	var controller: GridBattleController = bag["controller"]
	controller._handle_move(unit, Vector2i(2, 3))  # first move OK
	assert_vector(unit.position).is_equal(Vector2i(2, 3))
	var captures: Array = []
	controller.unit_moved.connect(func(unit_id: int, from: Vector2i, to: Vector2i) -> void:
		captures.append({"unit_id": unit_id})
	)

	controller._handle_move(unit, Vector2i(3, 3))  # second move same turn

	# Position unchanged from first move
	assert_vector(unit.position).is_equal(Vector2i(2, 3))
	# No second signal
	assert_int(captures.size()).is_equal(0)
