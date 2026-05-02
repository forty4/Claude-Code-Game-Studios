# Story 004: Move action — is_tile_in_move_range + _handle_move + unit_moved signal

> **Epic**: Grid Battle Controller | **Status**: Complete (2026-05-03) | **Layer**: Feature | **Type**: Logic | **Estimate**: 3h
> **ADR**: ADR-0014 §10 + grid-battle.md §123 + §612 (input-handling §9 partner contract)
>
> **Implementation note**: `_consume_unit_action` PARTIAL body added in story-004 (`_acted_this_turn[unit_id] = true`) to enable AC-8 re-entrancy guard test. Story-006 will EXTEND this stub with TurnOrderRunner.spend_action_token + auto-end-turn-when-all-acted; the partial body is a strict subset (additive). MapGridStub extended with `set_passable_for_test` + no-op overrides for `set_occupant` / `clear_occupant` (avoid push_error from production class on null _map field).

## Acceptance Criteria

- [ ] **AC-1** `is_tile_in_move_range(tile: Vector2i, unit_id: int) -> bool` public callback per input-handling §9 + grid-battle.md §612 contract — InputRouter calls this for FSM dispatch (S0 → S1 unit-select; S1 → S2 move-target validation)
- [ ] **AC-2** `is_tile_in_move_range` validates: (a) tile within unit's `move_range` (Manhattan distance for MVP — no terrain cost integration), (b) tile unoccupied (no other unit on that coord), (c) tile passable (not RIVER per terrain enum — query MapGrid + TerrainEffect)
- [ ] **AC-3** `_handle_move(unit: BattleUnit, dest: Vector2i)` validates via `is_tile_in_move_range` + applies via `_do_move`; consumes the unit's turn action (story-006 `_consume_unit_action`)
- [ ] **AC-4** `_do_move(unit: BattleUnit, dest: Vector2i) -> void`: updates `unit.position = dest` + `unit.facing = _direction_from_to(unit.position, dest)` (last move direction = facing per chapter-prototype pattern); calls `_map_grid.clear_occupant(old_pos)` + `_map_grid.set_occupant(dest, unit.unit_id, unit.side)` for occupancy bookkeeping
- [ ] **AC-5** Emits `unit_moved(unit_id: int, from: Vector2i, to: Vector2i)` controller-LOCAL signal AFTER position update (not via GameBus per ADR-0014 §8 — preserves controller-local signal pattern)
- [ ] **AC-6** Test: 4-unit fixture (1 player at (1,2), 3 distractor units occupying various tiles) + valid destination (2,3) → `is_tile_in_move_range` returns true; invalid (out-of-range) returns false; invalid (occupied) returns false; invalid (river per stub TerrainEffect) returns false
- [ ] **AC-7** Signal capture test: `monitor_signals(controller)` + valid move → assert exactly 1 `unit_moved` emit with correct (unit_id, from, to) tuple
- [ ] **AC-8** Re-entrancy guard: `_handle_move` called twice for same unit in same turn → second call silent no-op (per acted-this-turn guard from story-006)
- [ ] **AC-9** Regression baseline maintained: ≥757 + new tests / 0 errors / 0 orphans / Exit 0; new test file `tests/unit/feature/grid_battle/grid_battle_controller_move_test.gd` adds ≥5 tests

## Implementation Notes

*Derived from ADR-0014 §10 + grid-battle.md §123 + chapter-prototype's _do_move:*

1. **Manhattan distance for MVP**: chapter-prototype uses `absi(dx) + absi(dy) <= move_range`. Full grid-battle.md §123 requires "reachable path exists" (Dijkstra against terrain cost matrix from UnitRole.get_class_cost_table). MVP simplification: skip pathfinding; assume Manhattan-reachable = valid. Future Pathfinding ADR (post-MVP) refines.
2. **Facing update on move** (per chapter-prototype pattern): if `absi(dx) >= absi(dy)`, facing = E or W (sign of dx); else facing = S or N (sign of dy). Used by attack angle calc in story-005.
3. **MapGrid occupancy bookkeeping**: per `set_occupant` / `clear_occupant` API in `src/core/map_grid.gd:491,548`. Required so other systems (AI later, click hit-test today) can query "what's at this tile" without iterating `_units`.
4. **TerrainEffect query for impassable**: ADR-0008 TerrainEffect provides modifier query; MVP needs a simple `is_passable(terrain_enum)` or equivalent. If not in shipped API, story-004 may need a small TerrainEffect amendment OR fallback to MapTileData.terrain_type enum check inline.
5. **Future Pathfinding ADR amendment**: when pathfinding ships, this story's `is_tile_in_move_range` body refactors to call `Pathfinder.compute_path(unit, dest)` — interface stays stable.

## Test Evidence

**Story Type**: Logic (move validation + position update — pure deterministic)
**Required evidence**: `tests/unit/feature/grid_battle/grid_battle_controller_move_test.gd` — must exist + ≥5 tests + must pass
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: Story 002 (BattleUnit + _units), Story 003 (FSM dispatch routes here)
- **Unlocks**: Story 005 (attack uses similar position-+-occupancy pattern), Story 006 (per-turn consumption from move)
