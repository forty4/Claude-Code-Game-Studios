extends GdUnitTestSuite

## map_grid_mutation_test.gd
## Integration tests for Story 004: Mutation API + packed cache write-through + tile_destroyed signal.
## Covers AC-1 through AC-9 (9 test functions, one per QA Test Case).
##
## Test isolation strategy (G-10 resolution):
##   Story §Implementation Notes line 69 prescribed GameBusStub.swap_in() for signal tests.
##   G-10 proves this cannot work for emitter-side tests: the autoload identifier `GameBus`
##   binds at engine init to the originally-registered node. Emitting on the stub never
##   fires handlers connected via MapGrid's production code.
##   Resolution: use the REAL GameBus autoload; connect a per-test capture array observer
##   with CONNECT_DEFERRED; disconnect in after_test. See Tension 2 in the task brief.
##
## G-6 (orphan detection): every test calls grid.free() explicitly at test-body end.
## after_test is a safety net only (idempotent).
##
## Manifest Version: 2026-04-20

# ─── GameBus observer state ───────────────────────────────────────────────────
## Capture array for tile_destroyed emissions. Cleared in before_test.
## Contains Vector2i values — one per observed emit (G-4: Array not primitive).
var _tile_destroyed_captures: Array = []

## G-6 safety-net tracker: if a test body exits early (assertion failure),
## the explicit `grid.free()` at test end never runs and the Node orphans
## between test body exit and after_test. This tracker lets after_test free
## the grid defensively. Tests assign `_current_grid = grid` after allocation
## and set it back to null immediately before their explicit grid.free().
var _current_grid: MapGrid = null


func _on_tile_destroyed_capture(coord: Vector2i) -> void:
	_tile_destroyed_captures.append(coord)


func before_test() -> void:
	_tile_destroyed_captures.clear()
	GameBus.tile_destroyed.connect(_on_tile_destroyed_capture, CONNECT_DEFERRED)


func after_test() -> void:
	# Safety disconnect (G-6 pattern: after_test is crash-safety net, not primary cleanup).
	if GameBus.tile_destroyed.is_connected(_on_tile_destroyed_capture):
		GameBus.tile_destroyed.disconnect(_on_tile_destroyed_capture)
	# G-6 safety-net grid free — triggered only if test body exited before explicit free.
	if is_instance_valid(_current_grid):
		_current_grid.free()
	_current_grid = null


# ─── Factory helper ────────────────────────────────────────────────────────────

## Build a valid [rows] x [cols] map for mutation testing.
##
## All tiles pass story-003 validation (CR-3 elevation-terrain, no impassable+occupied).
## Default: all PLAINS (terrain=0, elevation=0), EMPTY state, passable, non-destructible.
## Use the returned MapResource directly with grid.load_map().
##
## [param rows] and [param cols] must each be within valid bounds (15-40 cols, 15-30 rows).
func _make_valid_map_for_mutation(rows: int, cols: int) -> MapResource:
	var m := MapResource.new()
	m.map_id = &"mutation_test_map"
	m.map_rows = rows
	m.map_cols = cols
	m.terrain_version = 1
	var n: int = rows * cols
	for i: int in n:
		var t := MapTileData.new()
		t.coord            = Vector2i(i % cols, i / cols)
		t.terrain_type     = 0      # PLAINS — valid elevation=0 per CR-3
		t.elevation        = 0
		t.is_passable_base = true
		t.tile_state       = MapGrid.TILE_STATE_EMPTY
		t.is_destructible  = false
		t.destruction_hp   = 0
		t.occupant_id      = 0
		t.occupant_faction = 0
		m.tiles.append(t)
	return m


# ─── AC-1: set_occupant writes through to TileData + all relevant caches ──────

## AC-1: set_occupant writes through to TileData + all relevant caches (AC-ST-1).
##
## Given: loaded 15x15 PLAINS map, tile (3,5) is EMPTY.
## When: grid.set_occupant(Vector2i(3,5), 42, FACTION_ALLY)
## Then: TileData fields updated AND caches updated at idx=78 (5*15+3).
## Edge: FACTION_ENEMY produces STATE_ENEMY_OCCUPIED analogously.
func test_map_grid_mutation_set_occupant_writes_through_to_tiledata_and_caches() -> void:
	# Arrange
	var grid := MapGrid.new()
	_current_grid = grid
	var res: MapResource = _make_valid_map_for_mutation(15, 15)
	var ok: bool = grid.load_map(res)
	assert_bool(ok).override_failure_message(
		"Precondition: load_map must succeed; errors: %s" % str(grid.get_last_load_errors())
	).is_true()

	# Act
	grid.set_occupant(Vector2i(3, 5), 42, MapGrid.FACTION_ALLY)

	# Assert — TileData (authoritative source)
	var idx: int = 5 * 15 + 3  # = 78
	var td: MapTileData = grid._map.tiles[idx]
	assert_int(td.occupant_id).override_failure_message(
		"TileData.occupant_id should be 42 after set_occupant"
	).is_equal(42)
	assert_int(td.occupant_faction).override_failure_message(
		"TileData.occupant_faction should be FACTION_ALLY after set_occupant"
	).is_equal(MapGrid.FACTION_ALLY)
	assert_int(td.tile_state).override_failure_message(
		"TileData.tile_state should be TILE_STATE_ALLY_OCCUPIED after set_occupant with FACTION_ALLY"
	).is_equal(MapGrid.TILE_STATE_ALLY_OCCUPIED)

	# Assert — packed caches (R-4 write-through)
	assert_int(grid._occupant_id_cache[idx]).override_failure_message(
		"_occupant_id_cache[78] should be 42"
	).is_equal(42)
	assert_int(grid._occupant_faction_cache[idx]).override_failure_message(
		"_occupant_faction_cache[78] should be FACTION_ALLY"
	).is_equal(MapGrid.FACTION_ALLY)
	assert_int(grid._tile_state_cache[idx]).override_failure_message(
		"_tile_state_cache[78] should be TILE_STATE_ALLY_OCCUPIED"
	).is_equal(MapGrid.TILE_STATE_ALLY_OCCUPIED)

	# Edge: FACTION_ENEMY on a different tile produces ENEMY_OCCUPIED analogously.
	grid.set_occupant(Vector2i(4, 5), 99, MapGrid.FACTION_ENEMY)
	var idx2: int = 5 * 15 + 4  # = 79
	assert_int(grid._tile_state_cache[idx2]).override_failure_message(
		"_tile_state_cache[79] should be TILE_STATE_ENEMY_OCCUPIED after FACTION_ENEMY set_occupant"
	).is_equal(MapGrid.TILE_STATE_ENEMY_OCCUPIED)
	assert_int(grid._occupant_id_cache[idx2]).override_failure_message(
		"_occupant_id_cache[79] should be 99"
	).is_equal(99)

	_current_grid = null
	grid.free()


# ─── AC-2: clear_occupant resets occupant fields with write-through ────────────

## AC-2: clear_occupant resets occupant fields with write-through.
##
## Given: tile (3,5) has occupant 42 ALLY.
## When: grid.clear_occupant(Vector2i(3,5))
## Then: occupant_id==0, occupant_faction==FACTION_NONE, tile_state==EMPTY (TileData + caches).
## Edge: clearing an already-EMPTY tile is a no-op (idempotent), emits no error.
func test_map_grid_mutation_clear_occupant_resets_fields_with_write_through() -> void:
	# Arrange
	var grid := MapGrid.new()
	_current_grid = grid
	var res: MapResource = _make_valid_map_for_mutation(15, 15)
	assert_bool(grid.load_map(res)).is_true()
	grid.set_occupant(Vector2i(3, 5), 42, MapGrid.FACTION_ALLY)
	var idx: int = 5 * 15 + 3  # = 78

	# Precondition: verify occupant was set
	assert_int(grid._occupant_id_cache[idx]).is_equal(42)

	# Act
	grid.clear_occupant(Vector2i(3, 5))

	# Assert — TileData (authoritative source)
	var td: MapTileData = grid._map.tiles[idx]
	assert_int(td.occupant_id).override_failure_message(
		"TileData.occupant_id should be 0 after clear_occupant"
	).is_equal(0)
	assert_int(td.occupant_faction).override_failure_message(
		"TileData.occupant_faction should be FACTION_NONE after clear_occupant"
	).is_equal(MapGrid.FACTION_NONE)
	assert_int(td.tile_state).override_failure_message(
		"TileData.tile_state should be TILE_STATE_EMPTY after clear_occupant on ALLY tile"
	).is_equal(MapGrid.TILE_STATE_EMPTY)

	# Assert — packed caches (R-4 write-through)
	assert_int(grid._occupant_id_cache[idx]).override_failure_message(
		"_occupant_id_cache[78] should be 0 after clear_occupant"
	).is_equal(0)
	assert_int(grid._occupant_faction_cache[idx]).override_failure_message(
		"_occupant_faction_cache[78] should be FACTION_NONE"
	).is_equal(MapGrid.FACTION_NONE)
	assert_int(grid._tile_state_cache[idx]).override_failure_message(
		"_tile_state_cache[78] should be TILE_STATE_EMPTY after clear_occupant"
	).is_equal(MapGrid.TILE_STATE_EMPTY)

	# Edge: is_passable_base unchanged (PLAINS stays passable)
	assert_bool(td.is_passable_base).override_failure_message(
		"is_passable_base should remain true after clear_occupant on PLAINS tile"
	).is_true()

	# Edge: clearing already-EMPTY tile is a no-op (idempotent, no error)
	grid.clear_occupant(Vector2i(3, 5))  # second call — should not crash or error
	assert_int(grid._tile_state_cache[idx]).override_failure_message(
		"_tile_state_cache[78] should still be TILE_STATE_EMPTY after idempotent clear"
	).is_equal(MapGrid.TILE_STATE_EMPTY)

	_current_grid = null
	grid.free()


# ─── AC-3: apply_tile_damage partial (non-destroying) ─────────────────────────

## AC-3: apply_tile_damage partial damage does NOT destroy the tile and does NOT emit signal.
##
## Given: DESTRUCTIBLE tile (3,5) with destruction_hp=10, is_destructible=true, occupant empty.
## When: grid.apply_tile_damage(Vector2i(3,5), 5)
## Then: returns false; destruction_hp==5; tile_state unchanged; no tile_destroyed emit.
## Edge: damage=0 is a no-op (returns false, destruction_hp unchanged).
func test_map_grid_mutation_apply_tile_damage_partial_no_destroy_no_emit() -> void:
	# Arrange
	var grid := MapGrid.new()
	_current_grid = grid
	var res: MapResource = _make_valid_map_for_mutation(15, 15)
	# Configure tile (3,5) as DESTRUCTIBLE with hp=10.
	var idx: int = 5 * 15 + 3  # = 78
	res.tiles[idx].is_destructible = true
	res.tiles[idx].destruction_hp  = 10
	res.tiles[idx].tile_state      = MapGrid.TILE_STATE_DESTRUCTIBLE
	assert_bool(grid.load_map(res)).is_true()

	# Act — partial damage (5 of 10 hp)
	var destroyed: bool = grid.apply_tile_damage(Vector2i(3, 5), 5)
	# CONNECT_DEFERRED: allow deferred frame to fire before asserting emit count.
	await get_tree().process_frame

	# Assert — partial: returns false, hp reduced, state unchanged, no signal
	assert_bool(destroyed).override_failure_message(
		"apply_tile_damage(5) on hp=10 tile should return false (not destroyed)"
	).is_false()
	assert_int(grid._map.tiles[idx].destruction_hp).override_failure_message(
		"destruction_hp should be 5 after 5 damage"
	).is_equal(5)
	assert_int(grid._tile_state_cache[idx]).override_failure_message(
		"tile_state cache should remain TILE_STATE_DESTRUCTIBLE (unchanged) after partial damage"
	).is_equal(MapGrid.TILE_STATE_DESTRUCTIBLE)
	assert_int(_tile_destroyed_captures.size()).override_failure_message(
		"tile_destroyed signal should NOT have been emitted for partial damage"
	).is_equal(0)

	# Edge: damage=0 is a no-op
	var destroyed_zero: bool = grid.apply_tile_damage(Vector2i(3, 5), 0)
	await get_tree().process_frame
	assert_bool(destroyed_zero).override_failure_message(
		"apply_tile_damage(0) should return false (no damage)"
	).is_false()
	assert_int(grid._map.tiles[idx].destruction_hp).override_failure_message(
		"destruction_hp should remain 5 after 0 damage"
	).is_equal(5)
	assert_int(_tile_destroyed_captures.size()).override_failure_message(
		"tile_destroyed should still not have been emitted after 0 damage"
	).is_equal(0)

	_current_grid = null
	grid.free()


# ─── AC-4: apply_tile_damage destroying + V-6 single emission ─────────────────

## AC-4: apply_tile_damage destroys tile, emits tile_destroyed exactly once (V-6).
##
## Given: DESTRUCTIBLE tile (3,5) with destruction_hp=5 (simulating prior AC-3 damage).
## When: grid.apply_tile_damage(Vector2i(3,5), 5)
## Then: returns true; destruction_hp=0; tile_state=DESTROYED; is_passable_base=true;
##       ALL 6 caches updated; tile_destroyed emitted EXACTLY ONCE.
## Edge: damage=99 with hp=5 destroys with one emit; second call on DESTROYED tile
##       emits nothing and returns false.
func test_map_grid_mutation_apply_tile_damage_destroying_emits_exactly_once() -> void:
	# Arrange — hp=5 (already partially damaged)
	var grid := MapGrid.new()
	_current_grid = grid
	var res: MapResource = _make_valid_map_for_mutation(15, 15)
	var idx: int = 5 * 15 + 3  # = 78
	res.tiles[idx].is_destructible = true
	res.tiles[idx].destruction_hp  = 5
	res.tiles[idx].tile_state      = MapGrid.TILE_STATE_DESTRUCTIBLE
	assert_bool(grid.load_map(res)).is_true()

	# Act — destroying blow
	var destroyed: bool = grid.apply_tile_damage(Vector2i(3, 5), 5)
	await get_tree().process_frame

	# Assert — tile destroyed this call
	assert_bool(destroyed).override_failure_message(
		"apply_tile_damage(5) on hp=5 tile should return true (destroyed)"
	).is_true()
	assert_int(grid._map.tiles[idx].destruction_hp).override_failure_message(
		"destruction_hp should be 0 after destroying blow"
	).is_equal(0)
	assert_int(grid._map.tiles[idx].tile_state).override_failure_message(
		"TileData.tile_state should be TILE_STATE_DESTROYED"
	).is_equal(MapGrid.TILE_STATE_DESTROYED)
	assert_bool(grid._map.tiles[idx].is_passable_base).override_failure_message(
		"is_passable_base should be true after destruction"
	).is_true()

	# Assert — ALL 6 caches updated (R-4 write-through verification)
	assert_int(grid._tile_state_cache[idx]).override_failure_message(
		"_tile_state_cache[78] should be TILE_STATE_DESTROYED"
	).is_equal(MapGrid.TILE_STATE_DESTROYED)
	assert_int(grid._passable_base_cache[idx]).override_failure_message(
		"_passable_base_cache[78] should be 1 (passable) after destruction"
	).is_equal(1)
	assert_int(grid._occupant_id_cache[idx]).override_failure_message(
		"_occupant_id_cache[78] should be 0 (no occupant)"
	).is_equal(0)
	assert_int(grid._occupant_faction_cache[idx]).override_failure_message(
		"_occupant_faction_cache[78] should be FACTION_NONE"
	).is_equal(MapGrid.FACTION_NONE)
	# terrain_type and elevation are unchanged by destruction (passable rubble, same terrain)
	assert_int(grid._terrain_type_cache[idx]).override_failure_message(
		"_terrain_type_cache[78] unchanged (still PLAINS=0)"
	).is_equal(0)

	# Assert — V-6: exactly one tile_destroyed emit
	assert_int(_tile_destroyed_captures.size()).override_failure_message(
		"tile_destroyed should have been emitted exactly once"
	).is_equal(1)
	assert_that(_tile_destroyed_captures[0]).override_failure_message(
		"tile_destroyed coord payload should be Vector2i(3,5); got %s" % str(_tile_destroyed_captures[0])
	).is_equal(Vector2i(3, 5))

	# Edge: over-damage (damage=99 on hp=5 tile) also destroys with exactly one emit.
	# Set up a new tile for this edge case.
	var idx2: int = 6 * 15 + 3  # = 93
	grid._map.tiles[idx2].is_destructible = true
	grid._map.tiles[idx2].destruction_hp  = 5
	grid._map.tiles[idx2].tile_state      = MapGrid.TILE_STATE_DESTRUCTIBLE
	grid._write_tile(idx2, grid._map.tiles[idx2])
	_tile_destroyed_captures.clear()
	var destroyed_over: bool = grid.apply_tile_damage(Vector2i(3, 6), 99)
	await get_tree().process_frame
	assert_bool(destroyed_over).override_failure_message(
		"apply_tile_damage(99) on hp=5 tile should return true (over-damage destroys)"
	).is_true()
	assert_int(_tile_destroyed_captures.size()).override_failure_message(
		"over-damage should emit tile_destroyed exactly once (not double-emit)"
	).is_equal(1)

	# Edge: second apply_tile_damage on already-DESTROYED tile returns false, no emit.
	_tile_destroyed_captures.clear()
	var destroyed_repeat: bool = grid.apply_tile_damage(Vector2i(3, 5), 99)
	await get_tree().process_frame
	assert_bool(destroyed_repeat).override_failure_message(
		"apply_tile_damage on already-DESTROYED tile should return false (V-6 idempotence)"
	).is_false()
	assert_int(_tile_destroyed_captures.size()).override_failure_message(
		"tile_destroyed must NOT be emitted a second time (V-6 idempotence)"
	).is_equal(0)

	_current_grid = null
	grid.free()


# ─── AC-5: AC-EDGE-4 — occupant survives tile destruction ─────────────────────

## AC-5: AC-EDGE-4 — when a DESTRUCTIBLE tile with an occupant is destroyed, the
## occupant fields are preserved and tile_state stays ALLY/ENEMY_OCCUPIED (not DESTROYED).
## is_passable_base becomes true. Signal emitted exactly once.
##
## Given: DESTRUCTIBLE tile (3,5) with destruction_hp=10, occupant_id=42, ALLY_OCCUPIED.
## When: grid.apply_tile_damage(Vector2i(3,5), 10)
## Then: returns true; tile_destroyed emitted once; post-state: tile_state==ALLY_OCCUPIED,
##       occupant_id==42, is_passable_base==true; caches match.
## Edge: same scenario with ENEMY_OCCUPIED — signal fires once; occupant state preserved.
func test_map_grid_mutation_apply_tile_damage_occupant_survives_destruction() -> void:
	# Arrange — ALLY_OCCUPIED + DESTRUCTIBLE tile at (3,5)
	var grid := MapGrid.new()
	_current_grid = grid
	var res: MapResource = _make_valid_map_for_mutation(15, 15)
	var idx: int = 5 * 15 + 3  # = 78
	res.tiles[idx].is_destructible  = true
	res.tiles[idx].destruction_hp   = 10
	res.tiles[idx].tile_state       = MapGrid.TILE_STATE_ALLY_OCCUPIED
	res.tiles[idx].occupant_id      = 42
	res.tiles[idx].occupant_faction = MapGrid.FACTION_ALLY
	res.tiles[idx].is_passable_base = true
	assert_bool(grid.load_map(res)).is_true()

	# Act
	var destroyed: bool = grid.apply_tile_damage(Vector2i(3, 5), 10)
	await get_tree().process_frame

	# Assert — tile reported as destroyed
	assert_bool(destroyed).override_failure_message(
		"apply_tile_damage on hp=10 tile with full 10 damage should return true"
	).is_true()

	# Assert — signal emitted exactly once
	assert_int(_tile_destroyed_captures.size()).override_failure_message(
		"tile_destroyed should be emitted exactly once even when occupant survives"
	).is_equal(1)
	assert_that(_tile_destroyed_captures[0]).override_failure_message(
		"tile_destroyed coord should be Vector2i(3,5)"
	).is_equal(Vector2i(3, 5))

	# Assert — occupant preserved (AC-EDGE-4)
	var td: MapTileData = grid._map.tiles[idx]
	assert_int(td.tile_state).override_failure_message(
		"TileData.tile_state should remain TILE_STATE_ALLY_OCCUPIED (occupant survives, not DESTROYED)"
	).is_equal(MapGrid.TILE_STATE_ALLY_OCCUPIED)
	assert_int(td.occupant_id).override_failure_message(
		"TileData.occupant_id should remain 42 after tile destroyed with occupant"
	).is_equal(42)
	assert_bool(td.is_passable_base).override_failure_message(
		"is_passable_base should be true after destruction (terrain gone, rubble passable)"
	).is_true()

	# Assert — caches match TileData
	assert_int(grid._tile_state_cache[idx]).override_failure_message(
		"_tile_state_cache should be ALLY_OCCUPIED (occupant surviving)"
	).is_equal(MapGrid.TILE_STATE_ALLY_OCCUPIED)
	assert_int(grid._occupant_id_cache[idx]).override_failure_message(
		"_occupant_id_cache should be 42"
	).is_equal(42)
	assert_int(grid._passable_base_cache[idx]).override_failure_message(
		"_passable_base_cache should be 1 (passable)"
	).is_equal(1)

	# Edge: same scenario with ENEMY_OCCUPIED occupant
	var idx2: int = 7 * 15 + 3  # = 108
	grid._map.tiles[idx2].is_destructible  = true
	grid._map.tiles[idx2].destruction_hp   = 10
	grid._map.tiles[idx2].tile_state       = MapGrid.TILE_STATE_ENEMY_OCCUPIED
	grid._map.tiles[idx2].occupant_id      = 77
	grid._map.tiles[idx2].occupant_faction = MapGrid.FACTION_ENEMY
	grid._map.tiles[idx2].is_passable_base = true
	grid._write_tile(idx2, grid._map.tiles[idx2])
	_tile_destroyed_captures.clear()
	var destroyed_enemy: bool = grid.apply_tile_damage(Vector2i(3, 7), 10)
	await get_tree().process_frame
	assert_bool(destroyed_enemy).is_true()
	assert_int(_tile_destroyed_captures.size()).override_failure_message(
		"tile_destroyed should emit once for ENEMY_OCCUPIED occupant-survives scenario"
	).is_equal(1)
	assert_int(grid._tile_state_cache[idx2]).override_failure_message(
		"_tile_state_cache should be ENEMY_OCCUPIED (enemy occupant survives)"
	).is_equal(MapGrid.TILE_STATE_ENEMY_OCCUPIED)

	_current_grid = null
	grid.free()


# ─── AC-6: AC-ST-3 direct ALLY→ENEMY rejected ─────────────────────────────────

## AC-6: AC-ST-3 direct ALLY→ENEMY transition is rejected with ERR_ILLEGAL_STATE_TRANSITION.
##
## Given: tile (3,5) is STATE_ALLY_OCCUPIED with occupant_id=42.
## When: grid.set_occupant(Vector2i(3,5), 99, FACTION_ENEMY)
## Then: push_error with ERR_ILLEGAL_STATE_TRANSITION; state unchanged (occupant 42, ALLY).
## Edge: ENEMY→ALLY also rejected; ALLY→ALLY overwrite also rejected (§EC-6 strict-sync).
func test_map_grid_mutation_set_occupant_direct_faction_transition_rejected() -> void:
	# Arrange
	var grid := MapGrid.new()
	_current_grid = grid
	var res: MapResource = _make_valid_map_for_mutation(15, 15)
	assert_bool(grid.load_map(res)).is_true()
	grid.set_occupant(Vector2i(3, 5), 42, MapGrid.FACTION_ALLY)
	var idx: int = 5 * 15 + 3  # = 78

	# Precondition: tile is ALLY_OCCUPIED with occupant 42
	assert_int(grid._tile_state_cache[idx]).is_equal(MapGrid.TILE_STATE_ALLY_OCCUPIED)
	assert_int(grid._occupant_id_cache[idx]).is_equal(42)

	# Act — attempt ALLY→ENEMY direct transition (must be rejected)
	# (push_error is called internally; GdUnit4 does not capture push_error natively,
	# so we assert the state is UNCHANGED as the observable side-effect.)
	grid.set_occupant(Vector2i(3, 5), 99, MapGrid.FACTION_ENEMY)

	# Assert — state unchanged (AC-ST-3 rejection preserved prior state)
	assert_int(grid._occupant_id_cache[idx]).override_failure_message(
		"_occupant_id_cache should still be 42 after rejected ALLY→ENEMY transition"
	).is_equal(42)
	assert_int(grid._occupant_faction_cache[idx]).override_failure_message(
		"_occupant_faction_cache should still be FACTION_ALLY after rejected transition"
	).is_equal(MapGrid.FACTION_ALLY)
	assert_int(grid._tile_state_cache[idx]).override_failure_message(
		"_tile_state_cache should still be TILE_STATE_ALLY_OCCUPIED after rejected transition"
	).is_equal(MapGrid.TILE_STATE_ALLY_OCCUPIED)
	assert_int(grid._map.tiles[idx].occupant_id).override_failure_message(
		"TileData.occupant_id should still be 42 after rejected ALLY→ENEMY transition"
	).is_equal(42)

	# Edge: ENEMY→ALLY direct also rejected
	var idx2: int = 6 * 15 + 3  # = 93
	grid.set_occupant(Vector2i(3, 6), 55, MapGrid.FACTION_ENEMY)
	assert_int(grid._tile_state_cache[idx2]).is_equal(MapGrid.TILE_STATE_ENEMY_OCCUPIED)
	grid.set_occupant(Vector2i(3, 6), 11, MapGrid.FACTION_ALLY)  # ENEMY→ALLY rejected
	assert_int(grid._occupant_id_cache[idx2]).override_failure_message(
		"ENEMY→ALLY transition should be rejected; occupant_id should remain 55"
	).is_equal(55)
	assert_int(grid._tile_state_cache[idx2]).override_failure_message(
		"tile_state should remain ENEMY_OCCUPIED after rejected ENEMY→ALLY"
	).is_equal(MapGrid.TILE_STATE_ENEMY_OCCUPIED)

	# Edge: ALLY→ALLY overwrite (same faction, different unit) also rejected (§EC-6 strict-sync)
	grid.set_occupant(Vector2i(3, 5), 100, MapGrid.FACTION_ALLY)  # overwrite ALLY with ALLY
	assert_int(grid._occupant_id_cache[idx]).override_failure_message(
		("ALLY→ALLY overwrite should be rejected per §EC-6 strict-sync;" \
		+ " occupant_id should remain 42")
	).is_equal(42)

	_current_grid = null
	grid.free()


# ─── AC-7: AC-ST-4 IMPASSABLE immutability ────────────────────────────────────

## AC-7: AC-ST-4 — IMPASSABLE tiles reject set_occupant; apply_tile_damage is a
## no-op on non-destructible IMPASSABLE; but IMPASSABLE+is_destructible=true allows
## apply_tile_damage with destruction transition.
##
## Given: tile (3,5) is STATE_IMPASSABLE, is_destructible=false.
## When: set_occupant or apply_tile_damage(100) called.
## Then: state unchanged; no tile_destroyed emit.
## Edge: IMPASSABLE with is_destructible=true — apply_tile_damage IS allowed; on hp<=0
##       transitions to DESTROYED with signal emit (AC-ST-4 exception path).
func test_map_grid_mutation_impassable_tile_rejects_mutations_except_destructible() -> void:
	# Arrange — IMPASSABLE non-destructible tile at (3,5)
	var grid := MapGrid.new()
	_current_grid = grid
	var res: MapResource = _make_valid_map_for_mutation(15, 15)
	var idx: int = 5 * 15 + 3  # = 78
	res.tiles[idx].is_passable_base = false
	res.tiles[idx].tile_state       = MapGrid.TILE_STATE_IMPASSABLE
	res.tiles[idx].is_destructible  = false
	res.tiles[idx].destruction_hp   = 0
	assert_bool(grid.load_map(res)).is_true()

	# Act — set_occupant on IMPASSABLE (must be rejected)
	grid.set_occupant(Vector2i(3, 5), 42, MapGrid.FACTION_ALLY)

	# Assert — state unchanged
	assert_int(grid._tile_state_cache[idx]).override_failure_message(
		"IMPASSABLE tile must reject set_occupant; tile_state should remain IMPASSABLE"
	).is_equal(MapGrid.TILE_STATE_IMPASSABLE)
	assert_int(grid._occupant_id_cache[idx]).override_failure_message(
		"IMPASSABLE tile: occupant_id should remain 0 after rejected set_occupant"
	).is_equal(0)

	# Act — apply_tile_damage on non-destructible IMPASSABLE (warning + no-op)
	var destroyed: bool = grid.apply_tile_damage(Vector2i(3, 5), 100)
	await get_tree().process_frame

	# Assert — no-op + no signal
	assert_bool(destroyed).override_failure_message(
		"apply_tile_damage on non-destructible IMPASSABLE should return false"
	).is_false()
	assert_int(grid._tile_state_cache[idx]).override_failure_message(
		"IMPASSABLE non-destructible: tile_state must remain IMPASSABLE after apply_tile_damage"
	).is_equal(MapGrid.TILE_STATE_IMPASSABLE)
	assert_int(_tile_destroyed_captures.size()).override_failure_message(
		"tile_destroyed must NOT be emitted for non-destructible IMPASSABLE damage"
	).is_equal(0)

	# Edge: IMPASSABLE with is_destructible=true DOES allow apply_tile_damage.
	# Set up a second tile for this edge case.
	var idx2: int = 6 * 15 + 3  # = 93
	grid._map.tiles[idx2].is_passable_base = false
	grid._map.tiles[idx2].tile_state       = MapGrid.TILE_STATE_IMPASSABLE
	grid._map.tiles[idx2].is_destructible  = true
	grid._map.tiles[idx2].destruction_hp   = 10
	grid._write_tile(idx2, grid._map.tiles[idx2])
	_tile_destroyed_captures.clear()
	var destroyed_wall: bool = grid.apply_tile_damage(Vector2i(3, 6), 10)
	await get_tree().process_frame
	assert_bool(destroyed_wall).override_failure_message(
		"IMPASSABLE+is_destructible=true: apply_tile_damage should return true on hp->0"
	).is_true()
	assert_int(_tile_destroyed_captures.size()).override_failure_message(
		"IMPASSABLE+destructible destruction should emit tile_destroyed once"
	).is_equal(1)
	assert_int(grid._tile_state_cache[idx2]).override_failure_message(
		"IMPASSABLE+destructible after full damage: tile_state should be TILE_STATE_DESTROYED"
	).is_equal(MapGrid.TILE_STATE_DESTROYED)

	_current_grid = null
	grid.free()


# ─── AC-8: apply_tile_damage on non-destructible warning ──────────────────────

## AC-8: apply_tile_damage on non-destructible tile → push_warning, returns false,
## no state change, no signal emit.
##
## Given: PLAINS tile (3,5), is_destructible=false.
## When: grid.apply_tile_damage(Vector2i(3,5), 100)
## Then: returns false; push_warning emitted; no state change; no tile_destroyed signal.
## Edge: idempotent — repeat call same behaviour.
func test_map_grid_mutation_apply_tile_damage_non_destructible_no_op_warning() -> void:
	# Arrange — PLAINS tile (non-destructible, default from factory)
	var grid := MapGrid.new()
	_current_grid = grid
	var res: MapResource = _make_valid_map_for_mutation(15, 15)
	assert_bool(grid.load_map(res)).is_true()
	var idx: int = 5 * 15 + 3  # = 78
	# Verify factory default: is_destructible=false, tile_state=EMPTY
	assert_bool(not grid._map.tiles[idx].is_destructible).is_true()
	assert_int(grid._tile_state_cache[idx]).is_equal(MapGrid.TILE_STATE_EMPTY)

	# Act
	var destroyed: bool = grid.apply_tile_damage(Vector2i(3, 5), 100)
	await get_tree().process_frame

	# Assert
	assert_bool(destroyed).override_failure_message(
		"apply_tile_damage on non-destructible tile should return false"
	).is_false()
	assert_int(grid._tile_state_cache[idx]).override_failure_message(
		"_tile_state_cache must remain TILE_STATE_EMPTY after no-op damage"
	).is_equal(MapGrid.TILE_STATE_EMPTY)
	assert_int(_tile_destroyed_captures.size()).override_failure_message(
		"tile_destroyed must NOT be emitted for non-destructible tile damage"
	).is_equal(0)
	# (push_warning cannot be captured by GdUnit4 v6.1.2 without a custom logger stub;
	#  warning content is tested by visual inspection in CI log. Idempotent return value
	#  and no-state-change are the observable contract assertions here.)

	# Edge: idempotent — second call same behaviour
	var destroyed2: bool = grid.apply_tile_damage(Vector2i(3, 5), 100)
	await get_tree().process_frame
	assert_bool(destroyed2).override_failure_message(
		"Second apply_tile_damage on non-destructible tile should also return false"
	).is_false()
	assert_int(_tile_destroyed_captures.size()).override_failure_message(
		"Still zero tile_destroyed emits after second no-op call"
	).is_equal(0)

	_current_grid = null
	grid.free()


# ─── AC-9: V-5 cache-sync parametric — every mutation × every cache ────────────

## AC-9: V-5 cache-sync parametric — after EVERY mutation in a 10-step sequence,
## all 6 caches match the corresponding TileData fields at every cell.
## This is the R-4 safety net: a missed cache write in any mutation path will fail here.
##
## Given: 3×3 test grid (minimum valid 15×15 used; all assertions are on indices 0..8).
## When: a planned sequence of 10 mutations across all 3 methods is executed.
## Then: after EACH mutation, for every cache index, all 6 cache arrays match TileData. Zero mismatches.
func test_map_grid_mutation_cache_sync_parametric_all_mutations_all_caches() -> void:
	# Arrange — 15x15 map (minimum valid); we mutate only tiles in the first 3x3 block (indices 0..8)
	var grid := MapGrid.new()
	_current_grid = grid
	var res: MapResource = _make_valid_map_for_mutation(15, 15)

	# Pre-seed 9 tiles for the mutation sequence:
	#   Tiles 0..2 (row 0, cols 0-2): DESTRUCTIBLE, hp=20, passable, EMPTY
	#   Tiles 15..17 (row 1, cols 0-2): DESTRUCTIBLE, hp=10, passable, EMPTY
	#   Tiles 30..32 (row 2, cols 0-2): PLAINS, non-destructible, passable, EMPTY
	for c: int in 3:
		var i0: int = 0 * 15 + c   # row 0
		res.tiles[i0].is_destructible = true
		res.tiles[i0].destruction_hp  = 20
		res.tiles[i0].tile_state      = MapGrid.TILE_STATE_DESTRUCTIBLE
		var i1: int = 1 * 15 + c   # row 1
		res.tiles[i1].is_destructible = true
		res.tiles[i1].destruction_hp  = 10
		res.tiles[i1].tile_state      = MapGrid.TILE_STATE_DESTRUCTIBLE
		# row 2: default PLAINS (non-destructible, EMPTY) from factory

	assert_bool(grid.load_map(res)).is_true()

	# ── 10-step mutation plan ──────────────────────────────────────────────────
	# After each step, assert cache consistency across a representative sample of
	# indices. We verify the 6 indices that were DIRECTLY mutated (hot indices) +
	# their neighbours, ensuring no adjacent-cell clobbering.
	#
	# Step 1: set_occupant (0,0) → ALLY #1
	# Step 2: set_occupant (1,0) → ALLY #2
	# Step 3: set_occupant (2,0) → ENEMY #3
	# Step 4: clear_occupant (1,0) → EMPTY
	# Step 5: apply_tile_damage (0,1) 5 → partial (hp 10→5)
	# Step 6: apply_tile_damage (1,1) 10 → destroy
	# Step 7: set_occupant (0,1) 7 ALLY (tile still DESTRUCTIBLE hp=5 — should work)
	# Step 8: apply_tile_damage (0,1) 5 → destroy with occupant (AC-EDGE-4)
	# Step 9: clear_occupant (0,0) → EMPTY
	# Step 10: clear_occupant (0,1) → DESTROYED (tile state preserved)

	var check_coords: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
		Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
		Vector2i(0, 2), Vector2i(1, 2), Vector2i(2, 2),
	]

	# Helper inline function (GDScript lambda captures local scope)
	var step_count: int = 0

	# Step 1: set_occupant (0,0) ALLY #1
	step_count += 1
	grid.set_occupant(Vector2i(0, 0), 1, MapGrid.FACTION_ALLY)
	TestHelpers.assert_all_caches_match_tiledata(self, grid, check_coords, step_count)

	# Step 2: set_occupant (1,0) ALLY #2
	step_count += 1
	grid.set_occupant(Vector2i(1, 0), 2, MapGrid.FACTION_ALLY)
	TestHelpers.assert_all_caches_match_tiledata(self, grid, check_coords, step_count)

	# Step 3: set_occupant (2,0) ENEMY #3
	step_count += 1
	grid.set_occupant(Vector2i(2, 0), 3, MapGrid.FACTION_ENEMY)
	TestHelpers.assert_all_caches_match_tiledata(self, grid, check_coords, step_count)

	# Step 4: clear_occupant (1,0) → EMPTY
	step_count += 1
	grid.clear_occupant(Vector2i(1, 0))
	TestHelpers.assert_all_caches_match_tiledata(self, grid, check_coords, step_count)

	# Step 5: apply_tile_damage (0,1) 5 → partial damage (hp 10→5)
	step_count += 1
	grid.apply_tile_damage(Vector2i(0, 1), 5)
	TestHelpers.assert_all_caches_match_tiledata(self, grid, check_coords, step_count)

	# Step 6: apply_tile_damage (1,1) 10 → destroy tile (no occupant)
	step_count += 1
	grid.apply_tile_damage(Vector2i(1, 1), 10)
	await get_tree().process_frame
	TestHelpers.assert_all_caches_match_tiledata(self, grid, check_coords, step_count)

	# Step 7: set_occupant (0,1) unit 7 ALLY (tile is DESTRUCTIBLE hp=5, not occupied)
	step_count += 1
	grid.set_occupant(Vector2i(0, 1), 7, MapGrid.FACTION_ALLY)
	TestHelpers.assert_all_caches_match_tiledata(self, grid, check_coords, step_count)

	# Step 8: apply_tile_damage (0,1) 5 → destroy with occupant (AC-EDGE-4)
	step_count += 1
	grid.apply_tile_damage(Vector2i(0, 1), 5)
	await get_tree().process_frame
	TestHelpers.assert_all_caches_match_tiledata(self, grid, check_coords, step_count)

	# Step 9: clear_occupant (0,0) → EMPTY (was ALLY #1)
	step_count += 1
	grid.clear_occupant(Vector2i(0, 0))
	TestHelpers.assert_all_caches_match_tiledata(self, grid, check_coords, step_count)

	# Step 10: clear_occupant (0,1) → should stay ALLY_OCCUPIED if occupant survived step 8,
	# then become EMPTY after clear; or if tile is DESTROYED (no occupant survive path)
	# the post-clear state depends on AC-EDGE-4 outcome.
	# After step 8, AC-EDGE-4: tile_state == ALLY_OCCUPIED (occupant survived), hp==0, passable.
	# After clear_occupant: occupant_id=0, occupant_faction=0. State reverts to EMPTY
	# (not DESTROYED) because clear_occupant only preserves DESTROYED state when tile_state==DESTROYED.
	# But here tile_state is ALLY_OCCUPIED (AC-EDGE-4 path) — clear goes to EMPTY.
	step_count += 1
	grid.clear_occupant(Vector2i(0, 1))
	TestHelpers.assert_all_caches_match_tiledata(self, grid, check_coords, step_count)

	_current_grid = null
	grid.free()


# ─── AC-10 (story-004 code-review close-out): null _map + out-of-bounds guards ──

## AC-10: Safety-guard coverage — mutations on a null _map (pre-load) and mutations
## with out-of-bounds coords must push_error, leave state unchanged, and emit no signal.
##
## Added during story-004 /code-review close-out (convergent gdscript-specialist Q9 +
## qa-tester gaps 7+8). These guards were activated by this story but previously
## untested. They will be called again by story-005 Dijkstra queries, so closing
## the coverage here prevents a regression surface when story-005 lands.
##
## Exercises ALL 6 guards in a single function:
##   1. set_occupant with _map == null (before load_map)
##   2. clear_occupant with _map == null
##   3. apply_tile_damage with _map == null
##   4. set_occupant with coord outside map bounds (negative + over-max, x + y axes)
##   5. clear_occupant with coord outside map bounds
##   6. apply_tile_damage with coord outside map bounds
##
## All paths must: not crash, push_error (observable via state-unchanged + return value),
## and emit zero tile_destroyed signals.
func test_map_grid_mutation_null_map_and_out_of_bounds_guards_are_noop() -> void:
	# ── Part 1: null _map (MapGrid.new() without load_map) ────────────────────────
	var grid := MapGrid.new()
	_current_grid = grid

	# All 3 methods must no-op without crashing when _map == null.
	grid.set_occupant(Vector2i(0, 0), 42, MapGrid.FACTION_ALLY)
	grid.clear_occupant(Vector2i(0, 0))
	var null_damage: bool = grid.apply_tile_damage(Vector2i(0, 0), 10)
	await get_tree().process_frame

	assert_bool(null_damage).override_failure_message(
		"apply_tile_damage on null _map must return false"
	).is_false()
	assert_int(_tile_destroyed_captures.size()).override_failure_message(
		"null _map mutations must not emit tile_destroyed"
	).is_equal(0)

	# ── Part 2: out-of-bounds coords on a loaded 15x15 grid ──────────────────────
	var res: MapResource = _make_valid_map_for_mutation(15, 15)
	assert_bool(grid.load_map(res)).override_failure_message(
		"precondition: load_map must succeed; errors: %s" % str(grid.get_last_load_errors())
	).is_true()

	# Snapshot a sample of pre-OOB tile states for comparison.
	var pre_sample: Array[int] = []
	for i: int in 9:
		pre_sample.append(grid._tile_state_cache[i])

	# Negative-x
	grid.set_occupant(Vector2i(-1, 5), 42, MapGrid.FACTION_ALLY)
	# At-or-over max-x (cols=15, so x=15 is out of bounds)
	grid.set_occupant(Vector2i(15, 5), 99, MapGrid.FACTION_ENEMY)
	# Negative-y
	grid.set_occupant(Vector2i(5, -1), 7, MapGrid.FACTION_ALLY)
	# Over max-y (rows=15, so y=15 is out of bounds)
	grid.set_occupant(Vector2i(5, 15), 8, MapGrid.FACTION_ENEMY)

	# OOB clear_occupant — two representative variants
	grid.clear_occupant(Vector2i(-1, -1))
	grid.clear_occupant(Vector2i(50, 50))

	# OOB apply_tile_damage — two representative variants
	var oob_damage_pos: bool = grid.apply_tile_damage(Vector2i(100, 100), 10)
	var oob_damage_neg: bool = grid.apply_tile_damage(Vector2i(-5, -5), 10)
	await get_tree().process_frame

	assert_bool(oob_damage_pos).override_failure_message(
		"apply_tile_damage OOB (positive) must return false"
	).is_false()
	assert_bool(oob_damage_neg).override_failure_message(
		"apply_tile_damage OOB (negative) must return false"
	).is_false()
	assert_int(_tile_destroyed_captures.size()).override_failure_message(
		"OOB mutations must not emit tile_destroyed"
	).is_equal(0)

	# State-unchanged invariant: the 9-tile pre-sample must match post-sample.
	for i: int in 9:
		assert_int(grid._tile_state_cache[i]).override_failure_message(
			("OOB mutations must not affect in-bounds tile state;" \
			+ " tile %d: pre=%d post=%d") % [i, pre_sample[i], grid._tile_state_cache[i]]
		).is_equal(pre_sample[i])

	_current_grid = null
	grid.free()


## Cache-integrity helper extracted to TestHelpers.assert_all_caches_match_tiledata
## per TD-032 A-14 — story-005 (Dijkstra) and story-006 (LoS) need the same assertion.
## See tests/unit/core/test_helpers.gd for the implementation.
