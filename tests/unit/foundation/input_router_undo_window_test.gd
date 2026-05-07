extends GdUnitTestSuite

## input_router_undo_window_test.gd
## Story 006 tests — per-unit undo window (CR-5) + window OPEN/CLOSE on
## confirm/attack/end-turn + EC-5 occupied-tile rejection + GridBattleStub extension.
## Covers AC-1..AC-10 + clear_for_battle_transition() lifecycle method.
##
## Pattern mirrors input_router_fsm_attack_st2_test.gd (story-004):
##   - G-3:  no class_name — InputRouter is an autoload without class_name
##   - G-15: before_test() not before_each() — GdUnit4 v6.1.2 lifecycle
##   - G-22: structural source-scan assertions use FileAccess.get_file_as_string
##   - G-25: no nested typed collections at declaration site
##   - G-26: no class_name on this test file — avoids collision with global registry
##   - G-28: disconnect only test-side lambdas in after_test (never bulk-disconnect-all)

const _IR_PATH: String = "res://src/foundation/input_router.gd"
const _STUB_PATH: String = "res://tests/helpers/grid_battle_stub.gd"


func before_test() -> void:
	# G-15 canonical reset (5th-precedent autoload helper, story-010 epic-terminal).
	# Covers all 17 fields per `tools/ci/lint_input_router_g15_reset.sh`.
	InputRouter.reset_for_tests()
	# G-15 reset — full 10-field clear matching story-004 baseline
	InputRouter._state = InputRouter.InputState.OBSERVATION
	InputRouter._active_mode = InputRouter.InputMode.KEYBOARD_MOUSE
	InputRouter._pre_menu_state = InputRouter.InputState.OBSERVATION
	InputRouter._undo_windows.clear()
	InputRouter._input_blocked_reasons.clear()
	InputRouter._bindings.clear()
	InputRouter._last_matched_action = &""
	InputRouter._grid_battle = null
	InputRouter._pending_end_phase = false
	InputRouter._did_visible_work = false


func after_test() -> void:
	# Safety net: ensure no stub persists across tests.
	InputRouter._grid_battle = null
	InputRouter._undo_windows.clear()
	InputRouter._pending_end_phase = false


# ── AC-1 _open_undo_window ────────────────────────────────────────────────────


## AC-1: _open_undo_window stores UndoEntry with correct fields.
func test_open_undo_window_stores_entry() -> void:
	# Arrange
	assert_bool(InputRouter._undo_windows.is_empty()).override_failure_message(
		"Pre-condition: _undo_windows must be empty before test"
	).is_true()

	# Act
	InputRouter._open_undo_window(1, Vector2i(2, 3), 1)

	# Assert — one entry stored
	assert_int(InputRouter._undo_windows.size()).override_failure_message(
		"AC-1: _open_undo_window must store exactly 1 entry"
	).is_equal(1)
	assert_bool(InputRouter._undo_windows.has(1)).override_failure_message(
		"AC-1: _undo_windows must have key unit_id=1"
	).is_true()

	var entry: UndoEntry = InputRouter._undo_windows[1]
	assert_bool(entry.pre_move_coord == Vector2i(2, 3)).override_failure_message(
		"AC-1: entry.pre_move_coord must be (2, 3)"
	).is_true()
	assert_int(entry.pre_move_facing).override_failure_message(
		"AC-1: entry.pre_move_facing must be 1"
	).is_equal(1)


## AC-1 CR-5b depth 1: re-open for same unit_id overwrites the previous entry.
func test_open_undo_window_overwrites_on_same_unit() -> void:
	# Arrange — open first window at coord A
	InputRouter._open_undo_window(1, Vector2i(0, 0), 0)

	# Act — re-open same unit at coord B (newer move)
	InputRouter._open_undo_window(1, Vector2i(9, 9), 2)

	# Assert — still exactly 1 entry; entry reflects coord B
	assert_int(InputRouter._undo_windows.size()).override_failure_message(
		"AC-1/CR-5b: overwrite must keep size == 1 (not append)"
	).is_equal(1)

	var entry: UndoEntry = InputRouter._undo_windows[1]
	assert_bool(entry.pre_move_coord == Vector2i(9, 9)).override_failure_message(
		"AC-1/CR-5b: overwritten entry must hold newer coord (9, 9)"
	).is_true()
	assert_int(entry.pre_move_facing).override_failure_message(
		"AC-1/CR-5b: overwritten entry must hold newer facing 2"
	).is_equal(2)


# ── AC-2 _close_undo_window ───────────────────────────────────────────────────


## AC-2: _close_undo_window removes the entry; closing non-existent key is no-op.
func test_close_undo_window_removes_entry() -> void:
	# Arrange — open a window
	InputRouter._open_undo_window(1, Vector2i(0, 0), 0)
	assert_bool(InputRouter._undo_windows.has(1)).is_true()

	# Act — close it
	InputRouter._close_undo_window(1)

	# Assert — key gone
	assert_bool(InputRouter._undo_windows.has(1)).override_failure_message(
		"AC-2: _close_undo_window must remove unit_id=1 entry"
	).is_false()

	# Close again — must NOT error (erase is a no-op on absent key)
	InputRouter._close_undo_window(1)
	assert_bool(InputRouter._undo_windows.is_empty()).override_failure_message(
		"AC-2: second _close_undo_window on absent key must be a silent no-op"
	).is_true()


# ── AC-3 + AC-5 _apply_undo happy path ───────────────────────────────────────


## AC-3 + AC-5: _apply_undo happy path — returns true, records restore call,
## removes entry, sets state → S1.
func test_apply_undo_happy_path_returns_true_and_records_restore_call() -> void:
	# Arrange
	var stub := GridBattleStub.new()
	InputRouter.set_grid_battle_for_tests(stub)
	InputRouter._open_undo_window(1, Vector2i(0, 0), 0)
	InputRouter._state = InputRouter.InputState.OBSERVATION

	# Act
	var result: bool = InputRouter._apply_undo(1)

	# Assert — return value
	assert_bool(result).override_failure_message(
		"AC-3/AC-5: _apply_undo must return true for valid window + clear tile"
	).is_true()

	# Assert — restore_calls recorded
	assert_int(stub.restore_calls.size()).override_failure_message(
		"AC-5: restore_unit_to_pre_move must be called exactly once"
	).is_equal(1)
	assert_int(stub.restore_calls[0]["unit_id"] as int).override_failure_message(
		"AC-5: restore_calls[0].unit_id must be 1"
	).is_equal(1)
	assert_bool(stub.restore_calls[0]["coord"] == Vector2i(0, 0)).override_failure_message(
		"AC-5: restore_calls[0].coord must be (0, 0)"
	).is_true()
	assert_int(stub.restore_calls[0]["facing"] as int).override_failure_message(
		"AC-5: restore_calls[0].facing must be 0"
	).is_equal(0)

	# Assert — window popped
	assert_bool(InputRouter._undo_windows.has(1)).override_failure_message(
		"AC-3: _undo_windows[1] must be removed after successful undo"
	).is_false()

	# Assert — state → S1 (CR-5 restore-to-S1)
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-5: _apply_undo must set state to S1 (UNIT_SELECTED)"
	).is_equal(int(InputRouter.InputState.UNIT_SELECTED))


## AC-3 (1): _apply_undo returns false when no window is open for unit (AC-13 case).
func test_apply_undo_returns_false_when_no_window() -> void:
	# Arrange — windows empty; state set to a known value
	InputRouter._state = InputRouter.InputState.OBSERVATION

	# Act
	var result: bool = InputRouter._apply_undo(99)

	# Assert — rejected
	assert_bool(result).override_failure_message(
		"AC-3(1)/AC-13: _apply_undo must return false when no window open for unit 99"
	).is_false()

	# Assert — state unchanged
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-13: state must remain OBSERVATION when undo is rejected (no window)"
	).is_equal(int(InputRouter.InputState.OBSERVATION))


## AC-7 + AC-14 + EC-5 + CR-5f: _apply_undo returns false and RETAINS entry when
## pre-move tile is occupied (retry-allowed per CR-5f).
func test_apply_undo_returns_false_when_tile_occupied() -> void:
	# Arrange
	var stub := GridBattleStub.new()
	stub.occupied_coords.append(Vector2i(0, 0))  # pre-move tile is occupied
	InputRouter.set_grid_battle_for_tests(stub)
	InputRouter._open_undo_window(1, Vector2i(0, 0), 0)
	InputRouter._state = InputRouter.InputState.OBSERVATION

	# Act
	var result: bool = InputRouter._apply_undo(1)

	# Assert — rejected
	assert_bool(result).override_failure_message(
		"AC-7/EC-5/AC-14: _apply_undo must return false when pre-move tile is occupied"
	).is_false()

	# Assert — entry STILL present (CR-5f: rejection does NOT pop; retry allowed)
	assert_bool(InputRouter._undo_windows.has(1)).override_failure_message(
		"CR-5f: _undo_windows[1] must be RETAINED after occupied-tile rejection (retry)"
	).is_true()

	# Assert — no restore call made
	assert_int(stub.restore_calls.size()).override_failure_message(
		"EC-5: restore_unit_to_pre_move must NOT be called when tile is occupied"
	).is_equal(0)

	# Assert — state unchanged
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-14: state must remain OBSERVATION when undo is blocked by occupied tile"
	).is_equal(int(InputRouter.InputState.OBSERVATION))


## /code-review-driven (qa-tester IMPORTANT #1): _apply_undo with `_grid_battle == null`
## documents and locks the intentional no-stub behavior — entry pops, state → S1,
## returns true even though no Grid Battle restore call was made. Permissive on
## null mirrors `_is_tile_in_move_range` / `_is_tile_in_attack_range` Foundation
## pattern (story-003+004 baseline) — production wiring at Battle Preparation
## ADR enforces real Grid Battle injection.
func test_apply_undo_succeeds_silently_when_no_grid_battle() -> void:
	# Arrange — _grid_battle is null (not injected); window is open
	InputRouter.set_grid_battle_for_tests(null)
	InputRouter._open_undo_window(1, Vector2i(7, 7), 2)
	InputRouter._state = InputRouter.InputState.OBSERVATION

	# Act
	var result: bool = InputRouter._apply_undo(1)

	# Assert — succeeds despite null Grid Battle (permissive-on-null pattern)
	assert_bool(result).override_failure_message(
		"_apply_undo with null _grid_battle must return true (permissive-on-null)"
	).is_true()

	# Assert — entry popped (one-shot undo per CR-5)
	assert_bool(InputRouter._undo_windows.has(1)).override_failure_message(
		"CR-5: _undo_windows[1] must be popped after successful _apply_undo"
	).is_false()

	# Assert — state restored to S1
	assert_int(int(InputRouter._state)).override_failure_message(
		"CR-5: _state must be UNIT_SELECTED after _apply_undo success"
	).is_equal(int(InputRouter.InputState.UNIT_SELECTED))


## /code-review-driven (godot-gdscript-specialist IMPORTANT #1): AC-6 end-to-end
## sequence — the GDD scenario is "open window → attack closes it → undo attempt
## rejected". Constituent behaviors are tested in isolation elsewhere; this test
## drives the full three-beat flow contiguously to guard against any sequencing
## bug between attack-confirm-closes-window and the subsequent undo rejection.
func test_ac6_undo_rejected_after_full_move_then_attack_sequence() -> void:
	# Arrange — open undo window via S2 confirm path, then advance to S4
	var stub := GridBattleStub.new()
	stub.unit_coords[1] = Vector2i(0, 0)
	stub.fixture_in_attack_coords.append(Vector2i(4, 4))
	InputRouter.set_grid_battle_for_tests(stub)
	# Open undo window (simulates post-S2-confirm state)
	InputRouter._open_undo_window(1, Vector2i(0, 0), 0)
	assert_bool(InputRouter._undo_windows.has(1)).is_true()

	# Act — beat 1: dispatch attack_confirm from S4 (closes window via site (a))
	InputRouter._state = InputRouter.InputState.ATTACK_CONFIRM
	var attack_ctx := InputContext.new()
	attack_ctx.target_unit_id = 1
	attack_ctx.target_coord = Vector2i(4, 4)
	InputRouter._handle_action(&"attack_confirm", attack_ctx)

	# Beat 2 verification — window must be closed by attack confirm
	assert_bool(InputRouter._undo_windows.has(1)).override_failure_message(
		"CR-5 site (a): attack_confirm must close the undo window"
	).is_false()

	# Act — beat 3: dispatch undo_last_move from S0 (state is S0 post-attack)
	var undo_ctx := InputContext.new()
	undo_ctx.target_unit_id = 1
	var prior_restore_count: int = stub.restore_calls.size()
	InputRouter._handle_action(&"undo_last_move", undo_ctx)

	# Assert — undo rejected silently per AC-13 (no window present)
	assert_int(stub.restore_calls.size()).override_failure_message(
		"AC-6: undo after attack must NOT invoke restore_unit_to_pre_move"
	).is_equal(prior_restore_count)
	# State should remain OBSERVATION (post-attack S0; undo's silent failure leaves it)
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-6: state must remain OBSERVATION when undo silently fails"
	).is_equal(int(InputRouter.InputState.OBSERVATION))


# ── AC-4 &"undo_last_move" action dispatch ───────────────────────────────────


## AC-4 S0 path: undo_last_move dispatches _apply_undo from S0 OBSERVATION.
func test_undo_last_move_action_dispatches_via_handle_action_in_s0() -> void:
	# Arrange
	var stub := GridBattleStub.new()
	stub.unit_coords[1] = Vector2i(5, 5)
	InputRouter.set_grid_battle_for_tests(stub)
	InputRouter._open_undo_window(1, Vector2i(5, 5), 0)
	InputRouter._state = InputRouter.InputState.OBSERVATION

	var ctx := InputContext.new()
	ctx.target_unit_id = 1

	# Act
	InputRouter._handle_action(&"undo_last_move", ctx)

	# Assert — restore_calls populated (proves _apply_undo was invoked and succeeded)
	assert_int(stub.restore_calls.size()).override_failure_message(
		"AC-4 S0: undo_last_move from S0 must invoke _apply_undo and record restore call"
	).is_equal(1)


## AC-4 S1 path: undo_last_move dispatches _apply_undo from S1 UNIT_SELECTED.
func test_undo_last_move_action_dispatches_via_handle_action_in_s1() -> void:
	# Arrange
	var stub := GridBattleStub.new()
	InputRouter.set_grid_battle_for_tests(stub)
	InputRouter._open_undo_window(1, Vector2i(3, 3), 1)
	InputRouter._state = InputRouter.InputState.UNIT_SELECTED

	var ctx := InputContext.new()
	ctx.target_unit_id = 1

	# Act
	InputRouter._handle_action(&"undo_last_move", ctx)

	# Assert — restore_calls populated
	assert_int(stub.restore_calls.size()).override_failure_message(
		"AC-4 S1: undo_last_move from S1 must invoke _apply_undo and record restore call"
	).is_equal(1)

	# Assert — state is S1 (UNIT_SELECTED) after undo — _apply_undo sets it explicitly
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-4 S1: after undo from S1, state must be UNIT_SELECTED (S1)"
	).is_equal(int(InputRouter.InputState.UNIT_SELECTED))


# ── AC-2 site (a): attack_confirm closes undo window ─────────────────────────


## AC-2 site (a): S4 attack_confirm closes undo window for the attacking unit.
func test_attack_confirm_closes_undo_window_for_attacker() -> void:
	# Arrange — open window for unit 1, then go to S4
	InputRouter._open_undo_window(1, Vector2i(0, 0), 0)
	assert_bool(InputRouter._undo_windows.has(1)).is_true()

	InputRouter._state = InputRouter.InputState.ATTACK_CONFIRM
	var stub := GridBattleStub.new()
	InputRouter.set_grid_battle_for_tests(stub)

	var ctx := InputContext.new()
	ctx.target_unit_id = 1
	ctx.target_coord = Vector2i(4, 4)

	# Act
	InputRouter._handle_action(&"attack_confirm", ctx)

	# Assert — undo window closed
	assert_bool(InputRouter._undo_windows.has(1)).override_failure_message(
		"AC-2 site (a): attack_confirm in S4 must close undo window for unit 1"
	).is_false()

	# Assert — state returned to S0
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-2 site (a): attack_confirm must transition to S0 (OBSERVATION)"
	).is_equal(int(InputRouter.InputState.OBSERVATION))


# ── AC-2 site (b): end_unit_turn closes undo window ──────────────────────────


## AC-2 site (b): S1 end_unit_turn closes undo window for that unit.
func test_end_unit_turn_closes_undo_window_for_unit() -> void:
	# Arrange
	InputRouter._open_undo_window(1, Vector2i(0, 0), 0)
	assert_bool(InputRouter._undo_windows.has(1)).is_true()

	InputRouter._state = InputRouter.InputState.UNIT_SELECTED

	var ctx := InputContext.new()
	ctx.target_unit_id = 1

	# Act
	InputRouter._handle_action(&"end_unit_turn", ctx)

	# Assert — undo window closed
	assert_bool(InputRouter._undo_windows.has(1)).override_failure_message(
		"AC-2 site (b): end_unit_turn must close undo window for unit 1"
	).is_false()

	# Assert — state back to S0 OBSERVATION
	assert_int(int(InputRouter._state)).override_failure_message(
		"AC-2 site (b): end_unit_turn must transition S1 → S0 (OBSERVATION)"
	).is_equal(int(InputRouter.InputState.OBSERVATION))


# ── AC-8 + AC-2 site (c): end_phase_confirm clears ALL windows ───────────────


## AC-8 + AC-2 site (c): end_phase_confirm when armed clears ALL undo windows.
func test_end_phase_confirm_clears_all_undo_windows() -> void:
	# Arrange — open 3 windows for 3 different units
	InputRouter._open_undo_window(1, Vector2i(1, 1), 0)
	InputRouter._open_undo_window(2, Vector2i(2, 2), 0)
	InputRouter._open_undo_window(3, Vector2i(3, 3), 0)
	assert_int(InputRouter._undo_windows.size()).is_equal(3)

	# Arm the end-phase gate
	InputRouter._state = InputRouter.InputState.OBSERVATION
	InputRouter._pending_end_phase = true

	var ctx := InputContext.new()

	# Act
	InputRouter._handle_action(&"end_phase_confirm", ctx)

	# Assert — all windows cleared
	assert_bool(InputRouter._undo_windows.is_empty()).override_failure_message(
		"AC-8/AC-2 site (c): end_phase_confirm must clear ALL undo windows"
	).is_true()

	# Assert — pending flag reset
	assert_bool(InputRouter._pending_end_phase).override_failure_message(
		"AC-8: end_phase_confirm must reset _pending_end_phase to false"
	).is_false()


# ── AC-9 Memory bound informational ──────────────────────────────────────────


## AC-9: 24 undo entries (max plausible units per battle) fit in _undo_windows.
## Informational guard per ADR-0005 §1 R-2 — no precise byte measurement needed.
func test_undo_windows_24_unit_capacity_holds() -> void:
	# Act — open 24 windows (unit IDs 0..23)
	for u: int in 24:
		InputRouter._open_undo_window(u, Vector2i(u, u), 0)

	# Assert — all 24 stored
	assert_int(InputRouter._undo_windows.size()).override_failure_message(
		("AC-9: _undo_windows must hold 24 entries (max plausible units);"
		+ " per-entry RefCounted ~80 bytes ≈ 2 KB — within ADR-0005 §1 R-2 bound")
	).is_equal(24)


# ── clear_for_battle_transition lifecycle ─────────────────────────────────────


## Implementation Notes §10: clear_for_battle_transition clears all windows.
func test_clear_for_battle_transition_clears_all_windows() -> void:
	# Arrange — open 3 windows
	InputRouter._open_undo_window(1, Vector2i(1, 1), 0)
	InputRouter._open_undo_window(2, Vector2i(2, 2), 0)
	InputRouter._open_undo_window(3, Vector2i(3, 3), 0)
	assert_int(InputRouter._undo_windows.size()).is_equal(3)

	# Act
	InputRouter.clear_for_battle_transition()

	# Assert — all cleared
	assert_bool(InputRouter._undo_windows.is_empty()).override_failure_message(
		"clear_for_battle_transition must clear all undo windows (battle-scoped memory per ADR-0005 §1 R-2)"
	).is_true()


# ── AC-10 GridBattleStub extension structural checks ─────────────────────────


## AC-10: GridBattleStub has all story-006 required methods and fields.
func test_grid_battle_stub_extension_methods_present() -> void:
	# Arrange
	var stub := GridBattleStub.new()

	# Assert — new methods present
	assert_bool(stub.has_method("restore_unit_to_pre_move")).override_failure_message(
		"AC-10: GridBattleStub must have restore_unit_to_pre_move method"
	).is_true()
	assert_bool(stub.has_method("get_unit_coord")).override_failure_message(
		"AC-10: GridBattleStub must have get_unit_coord method"
	).is_true()
	assert_bool(stub.has_method("get_unit_facing")).override_failure_message(
		"AC-10: GridBattleStub must have get_unit_facing method"
	).is_true()

	# Assert — new fields accessible
	assert_bool(stub.restore_calls is Array).override_failure_message(
		"AC-10: GridBattleStub.restore_calls must be an Array"
	).is_true()
	assert_bool(stub.unit_coords is Dictionary).override_failure_message(
		"AC-10: GridBattleStub.unit_coords must be a Dictionary"
	).is_true()
	assert_bool(stub.unit_facings is Dictionary).override_failure_message(
		"AC-10: GridBattleStub.unit_facings must be a Dictionary"
	).is_true()

	# Assert — fixture behavior: get_unit_coord defaults to ZERO for unknown unit
	assert_bool(stub.get_unit_coord(99) == Vector2i.ZERO).override_failure_message(
		"AC-10: get_unit_coord for unknown unit_id must return Vector2i.ZERO"
	).is_true()

	# Assert — fixture behavior: get_unit_facing defaults to 0 for unknown unit
	assert_int(stub.get_unit_facing(99)).override_failure_message(
		"AC-10: get_unit_facing for unknown unit_id must return 0"
	).is_equal(0)

	# Assert — is_tile_occupied uses occupied_coords
	assert_bool(stub.is_tile_occupied(Vector2i(0, 0))).override_failure_message(
		"AC-10: is_tile_occupied must return false when occupied_coords is empty"
	).is_false()
	stub.occupied_coords.append(Vector2i(0, 0))
	assert_bool(stub.is_tile_occupied(Vector2i(0, 0))).override_failure_message(
		"AC-10: is_tile_occupied must return true after appending coord to occupied_coords"
	).is_true()

	# Assert — restore_unit_to_pre_move records call to restore_calls
	stub.restore_unit_to_pre_move(7, Vector2i(2, 2), 1)
	assert_int(stub.restore_calls.size()).override_failure_message(
		"AC-10: restore_unit_to_pre_move must record exactly 1 call"
	).is_equal(1)
	assert_int(stub.restore_calls[0]["unit_id"] as int).is_equal(7)
	assert_bool(stub.restore_calls[0]["coord"] == Vector2i(2, 2)).is_true()
	assert_int(stub.restore_calls[0]["facing"] as int).is_equal(1)
