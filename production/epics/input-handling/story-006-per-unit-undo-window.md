# Story 006: Per-unit undo window (CR-5) + window OPEN/CLOSE on confirm/attack/end-turn + EC-5 occupied-tile rejection + Grid Battle stub extension

> **Epic**: Input Handling
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3-4h
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/input-handling.md`
**Requirement**: `TR-input-handling-009`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005 — Input Handling — InputRouter Autoload + 7-State FSM (MVP scope)
**ADR Decision Summary**: TR-009 = §1 + §5 + CR-5 — `_undo_windows: Dictionary[int, UndoEntry]` keyed by `unit_id` (per-unit, NOT per-turn per CR-5b; depth 1 move per unit). UndoEntry RefCounted holds `{unit_id, pre_move_coord, pre_move_facing}`. Window opens on S2 confirm → S0; closes permanently on (a) attack with that unit (S4 confirm), (b) `end_unit_turn` for that unit (S1 → S0), (c) `end_player_turn` confirmation. Memory bounded ~16-24 units × ~80 bytes = ~2 KB. Undo restores: unit coord + facing + `has_moved=false` + state→S1; does NOT restore damage / status / enemy reactions (CR-5e). Undo blocked if pre-move tile occupied (EC-5 + CR-5f); queries Grid Battle (provisional §9 stub).

**Engine**: Godot 4.6 | **Risk**: HIGH (governed by ADR-0005)
**Engine Notes**: Typed `Dictionary[int, UndoEntry]` (4.4+ stable). UndoEntry RefCounted (4.0+ stable; declared in story-001 with 3 fields). No engine-API surface here — pure data-structure manipulation.

**Control Manifest Rules (Foundation layer + Global)**:
- Required: undo logic in InputRouter only (NOT in Grid Battle — Grid Battle owns the actual move/attack execution; undo restores via paired Grid Battle method `restore_unit_to_pre_move(unit_id, coord, facing)` per provisional §9); EC-5 occupied-tile query via Grid Battle stub `is_tile_occupied(coord) -> bool`; CR-5e exclusions documented in inline comments
- Forbidden: undo windows persisting across battles (battle-scoped — `_undo_windows` cleared at battle-end via `set_grid_battle(null)` test seam OR explicit `clear_for_battle_transition()` method per ADR-0005 §1 R-2 memory bound); restoring damage/status/reactions (CR-5e exclusions); per-turn undo (per-unit only per CR-5b)
- Guardrail: `_open_undo_window` <10 LoC; `_close_undo_window` <5 LoC; `_apply_undo` <20 LoC; total undo logic <50 LoC

---

## Acceptance Criteria

*From GDD §Acceptance Criteria AC-12 + AC-13 + AC-14 + ADR-0005 §1 + CR-5 + CR-5b + CR-5e + CR-5f + EC-5:*

- [ ] **AC-1** `_open_undo_window(unit_id: int, pre_move_coord: Vector2i, pre_move_facing: int) -> void` helper added; called from S2 `_handle_action_in_s2` `&"move_confirm"` arm AFTER state transition to S0 (per CR-5 — window opens on the COMPLETED move). Stores `UndoEntry` in `_undo_windows[unit_id]`. Per CR-5b depth 1: if entry already exists for this unit_id, OVERWRITE (not append) — only the most recent move is undoable
- [ ] **AC-2** `_close_undo_window(unit_id: int) -> void` helper added; called from 3 sites per CR-5: (a) `_handle_action_in_s4` after attack confirm (close after S4 → S0 transition), (b) `_handle_action_in_s1` on `&"end_unit_turn"` for that unit (close before S1 → S0 transition since the ctx contains the unit), (c) `_handle_action_in_s0` on `&"end_phase_confirm"` second beat (close ALL undo windows via `_undo_windows.clear()`)
- [ ] **AC-3** `_apply_undo(unit_id: int) -> bool` helper added — handles `&"undo_last_move"` action invocation. Steps: (1) check `_undo_windows.has(unit_id)` — if false, return false (AC-13 case); (2) lookup entry; (3) check Grid Battle stub `is_tile_occupied(entry.pre_move_coord)` — if true, return false (AC-14 EC-5 case); (4) call `_grid_battle.restore_unit_to_pre_move(unit_id, entry.pre_move_coord, entry.pre_move_facing)` (stub method); (5) remove entry from `_undo_windows`; (6) set `_state = InputState.UNIT_SELECTED` per CR-5 restore-to-S1; (7) emit `input_state_changed` if state changed + `input_action_fired(&"undo_last_move", ctx)` via shared epilogue; (8) return true
- [ ] **AC-4** `&"undo_last_move"` action handled in `_handle_action_in_s0` arm: calls `_apply_undo(ctx.unit_id)`; success/failure handled by `_apply_undo` itself (sets `_did_visible_work = true` only on success; failure is silent per AC-13). Also handled in `_handle_action_in_s1` arm (player can undo from S1 — current unit-selected — too); routes identically
- [ ] **AC-5** AC-12 GDD test (undo window valid): GIVEN unit 1 confirmed move S2 → S0 with pre_move_coord=(0,0); WHEN `_handle_action(&"undo_last_move", ctx with unit_id=1)` invoked before any attack/end-turn — THEN `_apply_undo` returns true; `GridBattleStub.restore_calls` contains `{"unit_id": 1, "coord": (0,0), "facing": 0}`; `_state == UNIT_SELECTED`; `_undo_windows.has(1) == false`
- [ ] **AC-6** AC-13 GDD test (undo rejected after attack): GIVEN unit 1 confirmed move (window open) THEN confirmed attack (window closed via AC-2 site (a)); WHEN `_handle_action(&"undo_last_move", ctx with unit_id=1)` invoked — THEN `_apply_undo` returns false; no `restore_calls` recorded; `_state` unchanged
- [ ] **AC-7** AC-14 GDD test (undo blocked by tile occupation): GIVEN unit 1 moved A→B with pre_move_coord=(0,0); GridBattleStub `occupied_coords = [Vector2i(0,0)]`; WHEN `_handle_action(&"undo_last_move", ctx with unit_id=1)` invoked — THEN `_apply_undo` returns false (EC-5 + CR-5f); `_undo_windows[1]` STILL present (rejection doesn't pop the entry — player can retry once tile clears); `_state` unchanged
- [ ] **AC-8** End-phase confirm clears all undo windows (CR-5 site (c)): GIVEN multiple units have open undo windows; WHEN `_handle_action(&"end_phase_confirm", ctx)` invoked from S0 with `_pending_end_phase = true` — THEN AFTER the action, `_undo_windows.is_empty() == true`; subsequent `&"undo_last_move"` for any unit returns false
- [ ] **AC-9** Memory bound test (informational): allocate 24 UndoEntries (max plausible units per battle); assert total `_undo_windows.size() == 24`; informally verify per-entry footprint via instance count (no precise byte measurement required — informational guard rail per ADR-0005 §1 R-2)
- [ ] **AC-10** GridBattleStub extended with: `restore_unit_to_pre_move(unit_id: int, coord: Vector2i, facing: int) -> void` (records call to `restore_calls: Array[Dictionary]`); `is_tile_occupied(coord: Vector2i) -> bool` (returns true for `coord in occupied_coords`); `occupied_coords: Array[Vector2i] = []` field exposed for test fixture injection
- [ ] **AC-11** Regression baseline maintained: full GdUnit4 suite passes ≥789 cases (story-005 baseline) + new tests / 0 errors / 0 failures / 0 orphans / Exit 0; new test file `tests/unit/foundation/input_router_undo_window_test.gd` adds ≥10 tests covering AC-1..AC-9

---

## Implementation Notes

*Derived from ADR-0005 §1 + CR-5 + CR-5b + CR-5e + CR-5f + EC-5 + Migration Plan §From `[no current implementation]`:*

1. **`_open_undo_window` helper**:
   ```gdscript
   func _open_undo_window(unit_id: int, pre_move_coord: Vector2i, pre_move_facing: int) -> void:
       var entry := UndoEntry.new()
       entry.unit_id = unit_id
       entry.pre_move_coord = pre_move_coord
       entry.pre_move_facing = pre_move_facing
       _undo_windows[unit_id] = entry  # CR-5b depth 1: overwrite if exists
   ```

2. **S2 `move_confirm` arm extension** (replaces story-003's placeholder comment):
   ```gdscript
   func _handle_action_in_s2(action: StringName, ctx: InputContext) -> void:
       match action:
           &"move_confirm", &"action_confirm":
               # Capture pre-move state BEFORE applying move (Grid Battle modifies unit state)
               var pre_coord: Vector2i = _grid_battle.get_unit_coord(ctx.unit_id) if _grid_battle and _grid_battle.has_method("get_unit_coord") else Vector2i.ZERO
               var pre_facing: int = _grid_battle.get_unit_facing(ctx.unit_id) if _grid_battle and _grid_battle.has_method("get_unit_facing") else 0
               # Apply move
               if _grid_battle != null and _grid_battle.has_method("confirm_move"):
                   _grid_battle.confirm_move(ctx.unit_id, ctx.coord)
               # Open undo window (story-006)
               _open_undo_window(ctx.unit_id, pre_coord, pre_facing)
               _state = InputState.OBSERVATION
               _did_visible_work = true
           &"move_cancel":
               _state = InputState.UNIT_SELECTED
               _did_visible_work = true
   ```
   Note: GridBattleStub extended with `get_unit_coord(unit_id)` + `get_unit_facing(unit_id)` returning fixture defaults (`Vector2i(0,0)` + `0`) per AC-10. Production Grid Battle ADR will own the real implementation.

3. **`_close_undo_window` helper** + 3 call sites:
   ```gdscript
   func _close_undo_window(unit_id: int) -> void:
       _undo_windows.erase(unit_id)

   # Site (a) — S4 attack confirm (story-004 extension):
   func _handle_action_in_s4(action: StringName, ctx: InputContext) -> void:
       match action:
           &"attack_confirm", &"action_confirm":
               if _grid_battle != null and _grid_battle.has_method("confirm_attack"):
                   _grid_battle.confirm_attack(ctx.unit_id, ctx.coord)
               _close_undo_window(ctx.unit_id)  # site (a)
               _state = InputState.OBSERVATION
               _did_visible_work = true

   # Site (b) — S1 end_unit_turn (story-003 extension):
   func _handle_action_in_s1(action: StringName, ctx: InputContext) -> void:
       match action:
           # ... existing arms ...
           &"end_unit_turn":
               _close_undo_window(ctx.unit_id)  # site (b)
               _state = InputState.OBSERVATION
               _did_visible_work = true

   # Site (c) — S0 end_phase_confirm (story-004 end-phase 2-beat):
   func _handle_action_in_s0(action: StringName, ctx: InputContext) -> void:
       match action:
           # ... existing arms ...
           &"end_phase_confirm":
               if _pending_end_phase:
                   _pending_end_phase = false
                   _undo_windows.clear()  # site (c) — close ALL windows
                   _did_visible_work = true
   ```

4. **`_apply_undo` helper**:
   ```gdscript
   func _apply_undo(unit_id: int) -> bool:
       if not _undo_windows.has(unit_id):
           return false  # AC-13: no window open
       var entry: UndoEntry = _undo_windows[unit_id]
       # EC-5 + CR-5f: tile-occupied check
       if _grid_battle != null and _grid_battle.has_method("is_tile_occupied"):
           if _grid_battle.is_tile_occupied(entry.pre_move_coord):
               return false  # AC-14: tile occupied; entry retained for retry
       # Restore via Grid Battle (provisional §9 stub method)
       if _grid_battle != null and _grid_battle.has_method("restore_unit_to_pre_move"):
           _grid_battle.restore_unit_to_pre_move(unit_id, entry.pre_move_coord, entry.pre_move_facing)
       # Pop entry (one-shot undo; CR-5e — undo doesn't restore damage/status/reactions)
       _undo_windows.erase(unit_id)
       # Restore state to S1 per CR-5
       _state = InputState.UNIT_SELECTED
       _did_visible_work = true
       return true
   ```

5. **`&"undo_last_move"` action handling** in S0 + S1 arms:
   ```gdscript
   # Add to _handle_action_in_s0:
   &"undo_last_move":
       _apply_undo(ctx.unit_id)  # success/failure handled internally; _did_visible_work set on success only

   # Add to _handle_action_in_s1:
   &"undo_last_move":
       _apply_undo(ctx.unit_id)
   ```

6. **GridBattleStub extension** (`tests/helpers/grid_battle_stub.gd`):
   ```gdscript
   # Add to existing stub from story-003:
   var occupied_coords: Array[Vector2i] = []
   var restore_calls: Array[Dictionary] = []

   func is_tile_occupied(coord: Vector2i) -> bool:
       return coord in occupied_coords

   func restore_unit_to_pre_move(unit_id: int, coord: Vector2i, facing: int) -> void:
       restore_calls.append({"unit_id": unit_id, "coord": coord, "facing": facing})

   # Story-006 also adds these for the pre-move state capture in AC-1:
   var unit_coords: Dictionary[int, Vector2i] = {}
   var unit_facings: Dictionary[int, int] = {}

   func get_unit_coord(unit_id: int) -> Vector2i:
       return unit_coords.get(unit_id, Vector2i.ZERO)

   func get_unit_facing(unit_id: int) -> int:
       return unit_facings.get(unit_id, 0)
   ```

7. **End-phase clear-all test** (AC-8):
   ```gdscript
   func test_end_phase_confirm_clears_all_undo_windows() -> void:
       # Setup: 3 units with open undo windows
       for u in [1, 2, 3]:
           InputRouter._open_undo_window(u, Vector2i(u, u), 0)
       assert_int(InputRouter._undo_windows.size()).is_equal(3)
       # Setup: armed end-phase
       InputRouter._state = InputRouter.InputState.OBSERVATION
       InputRouter._pending_end_phase = true
       # Confirm
       InputRouter._handle_action(&"end_phase_confirm", InputContext.new())
       # Assertion
       assert_bool(InputRouter._undo_windows.is_empty()).is_true()
       assert_bool(InputRouter._pending_end_phase).is_false()
   ```

8. **Memory bound test** (AC-9):
   ```gdscript
   func test_undo_windows_24_unit_capacity() -> void:
       for u in 24:
           InputRouter._open_undo_window(u, Vector2i(u, u), 0)
       assert_int(InputRouter._undo_windows.size()).is_equal(24)
       # Informational only — no precise byte measurement; ADR-0005 §1 R-2 guards via per-entry RefCounted ~80 bytes ≈ 2 KB heap
   ```

9. **Test file**: `tests/unit/foundation/input_router_undo_window_test.gd` — 10-12 tests covering AC-1..AC-9. Use GridBattleStub injection per story-003 pattern. `before_test()` G-15 reset includes `_undo_windows.clear()` (story-001's reset list already contains this; story-006 verifies discipline).

10. **Battle-scoped lifecycle**: `_undo_windows` MUST clear at battle-end per ADR-0005 §1 R-2. Add `func clear_for_battle_transition() -> void: _undo_windows.clear()` method called by SceneManager when transitioning out of BattleScene (test seam available; production wiring deferred to Battle Preparation ADR).

11. **CR-5e exclusions documentation**: undo restores ONLY: coord + facing + `has_moved=false` + state→S1. Does NOT restore: HP damage taken from terrain, status effects applied during/after move, enemy unit reactions, AP spent. Inline comment on `_apply_undo` body documents this prominently to prevent scope creep at /dev-story time.

12. **G-15 reset obligation**: `_undo_windows.clear()` already in story-001's before_test reset list (story-001 AC-2 enforces 6-field reset). Story-010 lint script `lint_input_router_g15_reset.sh` validates the full 6-field + `_pending_end_phase` reset across all input_router_*_test.gd files.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 007**: GameBus subscriptions; S5/S6 arms; `_undo_windows` is preserved across menu open/close per ADR-0005 §1 R-2 (unaffected by S6 entry/exit)
- **Story 008-009**: Touch protocol; undo button visual state (dims when unavailable per CR-5c — Battle HUD owns rendering)
- **Story 010**: G-15 reset enforcement lint covers all 6 fields + `_pending_end_phase`; epic-terminal verification rollup

---

## QA Test Cases

*Authored inline (lean mode QL-STORY-READY skip).*

- **AC-1**: `_open_undo_window` opens entry
  - Given: empty `_undo_windows`
  - When: `_open_undo_window(1, Vector2i(2, 3), 1)`
  - Then: `_undo_windows.size() == 1`; `_undo_windows[1].pre_move_coord == Vector2i(2, 3)`; facing == 1
  - Edge cases: re-call for same unit_id with different coord → entry overwritten (CR-5b depth 1)
- **AC-2**: `_close_undo_window` removes entry
  - Given: `_undo_windows[1]` present
  - When: `_close_undo_window(1)`
  - Then: `_undo_windows.has(1) == false`
  - Edge cases: close non-existent → no error
- **AC-3**: `_apply_undo` happy path
  - Given: window open for unit 1; tile NOT occupied
  - When: `_apply_undo(1)`
  - Then: returns true; `restore_calls` recorded; `_undo_windows.has(1) == false`; `_state == UNIT_SELECTED`
- **AC-4**: `&"undo_last_move"` action routes correctly in S0 and S1
  - Given: window open; `_state in [S0, S1]`
  - When: `_handle_action(&"undo_last_move", ctx with unit_id=1)`
  - Then: `_apply_undo` invoked (verified via stub `restore_calls`)
  - Edge cases: invoke in S2/S3/S4/S5/S6 → no-op (per AC-8 sweep from story-003)
- **AC-5**: AC-12 happy path
  - Given: full S0→S1→S2→S0 sequence with confirm; pre_move_coord=(0,0); facing=0
  - When: undo invoked
  - Then: success; restored to coord (0,0), facing 0; state S1
- **AC-6**: AC-13 reject after attack
  - Given: full move → attack sequence; window closed via AC-2 site (a)
  - When: undo invoked
  - Then: returns false; no `restore_calls`; state unchanged
- **AC-7**: AC-14 reject by occupied tile
  - Given: window open with pre_move_coord=(0,0); `occupied_coords = [Vector2i(0,0)]`
  - When: undo invoked
  - Then: returns false; window STILL present (retry-allowed)
- **AC-8**: end-phase clears all
  - Given: 3 unit windows + armed `_pending_end_phase`
  - When: `&"end_phase_confirm"` action
  - Then: all windows cleared; `_pending_end_phase` reset
- **AC-9**: Memory bound informational
  - Given: 24 undo entries
  - When: count `_undo_windows.size()`
  - Then: equals 24
- **AC-10**: GridBattleStub extension
  - Given: `tests/helpers/grid_battle_stub.gd`
  - When: instantiate + invoke new methods
  - Then: `restore_calls` Array exists; `is_tile_occupied(c)` true for c in `occupied_coords`; `get_unit_coord/facing` return defaults
- **AC-11**: Regression baseline
  - Given: full suite invoked
  - When: 789 + new tests run
  - Then: ≥799 tests / 0 errors / 0 failures / 0 orphans / Exit 0

---

## Test Evidence

**Story Type**: Logic (undo data structure manipulation + Grid Battle stub interaction; pure deterministic)
**Required evidence**: `tests/unit/foundation/input_router_undo_window_test.gd` — must exist + ≥10 tests + must pass; GridBattleStub extended with 5 new methods + 3 new fields
**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 003 (S2 `move_confirm` arm — extends with undo-window OPEN), Story 004 (S4 `attack_confirm` arm — extends with undo-window CLOSE site (a); end-phase 2-beat — extends with site (c))
- **Unlocks**: Battle HUD epic (consumes `input_action_fired(&"undo_last_move", ctx)` to update undo button visual state per CR-5c)
