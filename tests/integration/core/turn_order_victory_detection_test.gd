extends GdUnitTestSuite

## turn_order_victory_detection_test.gd
## Integration tests for Story 006 (turn-order epic):
##   - TR-007: _evaluate_victory() return semantics + victory_condition_detected emission
##   - TR-018: F-3 RE2 round-cap DRAW + ROUND_CAP JSON key
##   - TR-020: AC-18 mutual-kill PLAYER_WIN precedence + AC-22 T7-beats-RE2 precedence
##
## Covers AC-1 through AC-11 from story-006 §Acceptance Criteria.
## Test type: Integration — crosses GameBus boundary (victory_condition_detected emit).
## Uses real /root/GameBus; no HPStatusController dependency — unit_died emitted directly.
##
## Governing ADRs: ADR-0011 (Turn Order), ADR-0001 (CONNECT_DEFERRED mandate §5),
##   ADR-0006 (BalanceConstants accessor), ADR-0001 line 155 (int payload).
##
## GOTCHA AWARENESS:
##   G-4  — lambda primitive capture; use Array captures pattern
##   G-6  — orphan detection fires BETWEEN test body exit and after_test
##   G-9  — % operator precedence; wrap multi-line concat in parens
##   G-10 — autoload identifier binds at engine init; emit on real GameBus
##   G-15 — before_test() is canonical hook (NOT before_each)
##   G-16 — typed Array[Dictionary] for signal log
##   G-24 — as operator precedence; wrap RHS cast in parens in == expressions

# ── Constants ─────────────────────────────────────────────────────────────────

## MVP hero IDs verified against heroes.json 2026-05-01.
const _HERO_LIU_BEI: StringName   = &"shu_001_liu_bei"
const _HERO_GUAN_YU: StringName   = &"shu_002_guan_yu"
const _HERO_ZHANG_FEI: StringName = &"shu_003_zhang_fei"

## UnitRole.UnitClass int backing values (unit_role.gd — locked per ADR-0009).
const _CLASS_CAVALRY: int   = 0
const _CLASS_INFANTRY: int  = 1
const _CLASS_COMMANDER: int = 4

## Standard unit_ids.
const _UID_P1: int = 1   ## Player-controlled unit (is_player_controlled = true)
const _UID_E1: int = 2   ## Enemy unit (is_player_controlled = false)
const _UID_E2: int = 3   ## Second enemy unit

## VictoryResult backing values (TurnOrderRunner.VictoryResult enum).
const _PLAYER_WIN: int = 0
const _PLAYER_LOSE: int = 1
const _DRAW: int = 2

# ── Suite state ───────────────────────────────────────────────────────────────

var _runner: TurnOrderRunner

## Unified signal log — capture handlers append here (G-16: typed Array[Dictionary]).
var _signal_log: Array[Dictionary] = []

# ── Signal capture handlers (method-reference form — sidesteps G-4) ──────────

func _capture_victory(result: int) -> void:
	_signal_log.append({"signal": "victory_condition_detected", "result": result})


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func before_test() -> void:
	## G-15: canonical GdUnit4 v6.1.2 per-test hook (NOT before_each).
	## Creates a fresh TurnOrderRunner with a 2-unit (1 player + 1 enemy) roster.
	## Drains the deferred _begin_round frame; forces ROUND_ACTIVE for sync test control.
	_signal_log.clear()
	_runner = auto_free(TurnOrderRunner.new())
	add_child(_runner)
	var roster: Array[BattleUnit] = []
	roster.append(_make_unit(_UID_P1, _HERO_LIU_BEI, _CLASS_COMMANDER, true))
	roster.append(_make_unit(_UID_E1, _HERO_GUAN_YU, _CLASS_INFANTRY, false))
	_runner.initialize_battle(roster)
	# Drain the deferred _begin_round() call — avoids interference during tests.
	await get_tree().process_frame
	# Seed deterministic initiatives: P1=120 (player), E1=100 (enemy).
	_runner._seed_unit_state_for_test(_UID_P1, 120, 65, true)
	_runner._seed_unit_state_for_test(_UID_E1, 100, 70, false)
	# Force ROUND_ACTIVE + rebuild queue for synchronous test control.
	_runner._round_state = TurnOrderRunner.RoundState.ROUND_ACTIVE
	_runner._queue_index = 0
	_runner._rebuild_queue()
	_signal_log.clear()
	# G-15 marker: unit_died.disconnect() — runner under test handles via _on_unit_died
	# Connect victory capture handler (method-reference form — G-4 safe).
	GameBus.victory_condition_detected.connect(_capture_victory)


func after_test() -> void:
	## G-15 cleanup: disconnect signal handlers before auto_free.
	if is_instance_valid(_runner):
		if GameBus.unit_died.is_connected(_runner._on_unit_died):
			GameBus.unit_died.disconnect(_runner._on_unit_died)
	if GameBus.victory_condition_detected.is_connected(_capture_victory):
		GameBus.victory_condition_detected.disconnect(_capture_victory)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_unit(unit_id: int, hero_id: StringName, unit_class: int, is_player: bool) -> BattleUnit:
	var u: BattleUnit = BattleUnit.new()
	u.unit_id = unit_id
	u.hero_id = hero_id
	u.unit_class = unit_class
	u.is_player_controlled = is_player
	return u


func _add_enemy_unit(unit_id: int) -> void:
	## Adds a second enemy unit to _unit_states + _queue for multi-unit test scenarios.
	## Assumes _runner is initialized; appends unit directly to _unit_states.
	var state: UnitTurnState = UnitTurnState.new()
	state.unit_id = unit_id
	state.initiative = 80
	state.stat_agility = 60
	state.is_player_controlled = false
	state.turn_state = TurnOrderRunner.TurnState.IDLE
	_runner._unit_states[unit_id] = state
	_runner._rebuild_queue()


func _kill_unit(unit_id: int) -> void:
	## Simulates unit death by emitting GameBus.unit_died and draining deferred frame.
	## This exercises the real _on_unit_died (CONNECT_DEFERRED) path.
	## Callers MUST await get_tree().process_frame after calling this.
	GameBus.unit_died.emit(unit_id)


func _count_victory_signals() -> int:
	var count: int = 0
	for entry: Dictionary in _signal_log:
		if (entry.get("signal", "") as String) == "victory_condition_detected":
			count += 1
	return count


func _first_victory_result() -> int:
	for entry: Dictionary in _signal_log:
		if (entry.get("signal", "") as String) == "victory_condition_detected":
			return entry.get("result", -1) as int
	return -1


# ── AC-1: _evaluate_victory() return semantics ────────────────────────────────

## AC-1 (TR-007): _evaluate_victory() returns null when both factions have alive units.
## Given: P1 alive (player), E1 alive (enemy).
## When: _evaluate_victory() called.
## Then: returns null (battle continues).
func test_evaluate_victory_returns_null_when_both_factions_alive() -> void:
	# Both P1 and E1 are alive (default from before_test)
	var result: Variant = _runner._evaluate_victory()
	assert_bool(result == null).override_failure_message(
		("AC-1: _evaluate_victory() must return null when both factions have alive units; "
		+ "got: %s — battle should continue") % str(result)
	).is_true()


## AC-1: _evaluate_victory() returns PLAYER_WIN when all enemies are dead.
## Given: E1's turn_state set to DEAD manually (simulate death without signal).
## When: _evaluate_victory() called.
## Then: returns VictoryResult.PLAYER_WIN (int value 0).
func test_evaluate_victory_returns_player_win_when_all_enemies_dead() -> void:
	# Mark enemy as DEAD (simulate death state in _unit_states without removing entry)
	_runner._unit_states[_UID_E1].turn_state = TurnOrderRunner.TurnState.DEAD

	var result: Variant = _runner._evaluate_victory()
	assert_bool(result != null).override_failure_message(
		"AC-1: _evaluate_victory() must not return null when all enemies are dead"
	).is_true()
	assert_int(result as int).override_failure_message(
		("AC-1: _evaluate_victory() must return PLAYER_WIN (0) when all enemies dead; "
		+ "got: %d") % (result as int)
	).is_equal(_PLAYER_WIN)


## AC-1: _evaluate_victory() returns PLAYER_LOSE when all players are dead.
## Given: P1's turn_state set to DEAD manually.
## When: _evaluate_victory() called.
## Then: returns VictoryResult.PLAYER_LOSE (int value 1).
func test_evaluate_victory_returns_player_lose_when_all_players_dead() -> void:
	# Mark player as DEAD in _unit_states
	_runner._unit_states[_UID_P1].turn_state = TurnOrderRunner.TurnState.DEAD

	var result: Variant = _runner._evaluate_victory()
	assert_bool(result != null).override_failure_message(
		"AC-1: _evaluate_victory() must not return null when all players are dead"
	).is_true()
	assert_int(result as int).override_failure_message(
		("AC-1: _evaluate_victory() must return PLAYER_LOSE (1) when all players dead; "
		+ "got: %d") % (result as int)
	).is_equal(_PLAYER_LOSE)


# ── AC-2: victory_condition_detected emitted exactly once ─────────────────────

## AC-2 (TR-007): On decisive condition, GameBus.victory_condition_detected emits exactly once.
## Given: E1 dead (turn_state = DEAD); victory capture handler connected.
## When: _emit_victory(PLAYER_WIN) called.
## Then: signal_log has exactly 1 entry with result == 0.
func test_emit_victory_emits_exactly_once_on_decisive_condition() -> void:
	# Arrange — force ROUND_ACTIVE (not BATTLE_ENDED) so emit guard is not triggered
	_runner._round_state = TurnOrderRunner.RoundState.ROUND_ACTIVE

	# Act — emit PLAYER_WIN
	_runner._emit_victory(_PLAYER_WIN)

	# Assert — exactly 1 signal emitted
	var count: int = _count_victory_signals()
	assert_int(count).override_failure_message(
		("AC-2: victory_condition_detected must emit exactly once; "
		+ "got %d emissions") % count
	).is_equal(1)

	# Assert — result is PLAYER_WIN (0)
	var result: int = _first_victory_result()
	assert_int(result).override_failure_message(
		("AC-2: victory_condition_detected payload must be PLAYER_WIN (0); got %d") % result
	).is_equal(_PLAYER_WIN)


# ── AC-3: single-emit guard + BATTLE_ENDED state ──────────────────────────────

## AC-3 (TR-007): After _emit_victory, _round_state transitions to BATTLE_ENDED.
## Subsequent _emit_victory calls are no-ops (single-emit guard).
## Given: ROUND_ACTIVE state.
## When: _emit_victory(PLAYER_WIN) → _emit_victory(DRAW) → _emit_victory(PLAYER_LOSE).
## Then: _round_state == BATTLE_ENDED; signal_log.size() == 1 (only first emit went through).
func test_emit_victory_single_emit_guard_subsequent_calls_noop() -> void:
	# Arrange — ROUND_ACTIVE
	_runner._round_state = TurnOrderRunner.RoundState.ROUND_ACTIVE

	# Act — first emit
	_runner._emit_victory(_PLAYER_WIN)

	# Assert — state transitioned to BATTLE_ENDED
	assert_int(_runner._round_state as int).override_failure_message(
		("AC-3: _round_state must be BATTLE_ENDED after _emit_victory; "
		+ "got: %d") % (_runner._round_state as int)
	).is_equal(TurnOrderRunner.RoundState.BATTLE_ENDED as int)

	# Act — subsequent calls (DRAW and PLAYER_LOSE)
	_runner._emit_victory(_DRAW)
	_runner._emit_victory(_PLAYER_LOSE)

	# Assert — only 1 signal emitted total
	var count: int = _count_victory_signals()
	assert_int(count).override_failure_message(
		("AC-3: single-emit guard must suppress subsequent _emit_victory calls; "
		+ "expected 1 total emission; got %d — guard not working") % count
	).is_equal(1)

	# Assert — the one emitted signal was PLAYER_WIN (first call)
	var result: int = _first_victory_result()
	assert_int(result).override_failure_message(
		("AC-3: the single emitted result must be PLAYER_WIN (0); got %d — "
		+ "wrong signal captured") % result
	).is_equal(_PLAYER_WIN)


## AC-3: After BATTLE_ENDED, _advance_turn is a no-op (T2 short-circuits for dead units).
## This tests that _round_state == BATTLE_ENDED prevents further game-state mutations
## through the emit guard on _end_round.
func test_battle_ended_state_advance_turn_noop() -> void:
	# Arrange — emit victory to set BATTLE_ENDED
	_runner._round_state = TurnOrderRunner.RoundState.ROUND_ACTIVE
	_runner._emit_victory(_PLAYER_WIN)

	# Clear log to capture only subsequent emissions
	_signal_log.clear()

	# Act — simulate _end_round call (as if queue exhausted after BATTLE_ENDED)
	_runner._end_round()

	# Assert — no additional victory signal emitted (BATTLE_ENDED guard)
	var count: int = _count_victory_signals()
	assert_int(count).override_failure_message(
		("AC-3: _end_round must be a no-op after BATTLE_ENDED; "
		+ "expected 0 additional emissions; got %d") % count
	).is_equal(0)


# ── AC-4: RE2 round-cap DRAW ──────────────────────────────────────────────────

## AC-4 (TR-018): RE2 round-cap DRAW — _end_round emits DRAW when _round_number >= ROUND_CAP.
## Given: _round_number = 30; both P1 + E1 alive; ROUND_ENDING state.
## When: _end_round() called.
## Then: victory_condition_detected emitted with result == DRAW (2).
func test_end_round_emits_draw_when_round_number_equals_round_cap() -> void:
	# Arrange — round 30, both alive, ROUND_ACTIVE (not BATTLE_ENDED)
	_runner._round_number = 30
	_runner._round_state = TurnOrderRunner.RoundState.ROUND_ACTIVE

	# Act — _end_round() should detect _round_number >= ROUND_CAP and emit DRAW
	_runner._end_round()

	# Assert — DRAW emitted
	var count: int = _count_victory_signals()
	assert_int(count).override_failure_message(
		("AC-4: _end_round must emit victory_condition_detected(DRAW) when "
		+ "_round_number (30) >= ROUND_CAP (30); got %d emissions") % count
	).is_equal(1)

	var result: int = _first_victory_result()
	assert_int(result).override_failure_message(
		("AC-4: RE2 round-cap must emit DRAW (2); got %d") % result
	).is_equal(_DRAW)

	# Assert — state is BATTLE_ENDED
	assert_int(_runner._round_state as int).override_failure_message(
		("AC-4: _round_state must be BATTLE_ENDED after RE2 DRAW emit; got %d")
		% (_runner._round_state as int)
	).is_equal(TurnOrderRunner.RoundState.BATTLE_ENDED as int)


## AC-4 boundary: round 29 does NOT trigger DRAW (battle continues).
func test_end_round_no_draw_when_round_number_below_cap() -> void:
	# Arrange — round 29 (< ROUND_CAP 30)
	_runner._round_number = 29
	_runner._round_state = TurnOrderRunner.RoundState.ROUND_ACTIVE
	# Disconnect victory capture temporarily to prevent false signal capture
	# from _begin_round firing via call_deferred
	if GameBus.victory_condition_detected.is_connected(_capture_victory):
		GameBus.victory_condition_detected.disconnect(_capture_victory)

	# Act — _end_round should NOT emit DRAW; should call _begin_round.call_deferred()
	_runner._end_round()

	# Assert — no DRAW signal (signal log was cleared and capture disconnected)
	# Verify state is ROUND_ENDING (not BATTLE_ENDED — RE3 path taken)
	assert_int(_runner._round_state as int).override_failure_message(
		("AC-4 boundary: _round_state must be ROUND_ENDING (not BATTLE_ENDED) "
		+ "when round 29 < ROUND_CAP 30; got %d") % (_runner._round_state as int)
	).is_equal(TurnOrderRunner.RoundState.ROUND_ENDING as int)

	# Drain deferred _begin_round to avoid orphaned deferred calls interfering with after_test
	await get_tree().process_frame

	# Reconnect for after_test cleanup
	if not GameBus.victory_condition_detected.is_connected(_capture_victory):
		GameBus.victory_condition_detected.connect(_capture_victory)


# ── AC-5: ROUND_CAP in balance_entities.json ──────────────────────────────────

## AC-5 (TR-018, ADR-0006 §6 same-patch): balance_entities.json contains ROUND_CAP: 30.
func test_round_cap_key_exists_in_balance_entities_json() -> void:
	var content: String = FileAccess.get_file_as_string(
		"res://assets/data/balance/balance_entities.json")

	# Key exists
	assert_bool(content.contains("ROUND_CAP")).override_failure_message(
		("AC-5: balance_entities.json must contain 'ROUND_CAP' key "
		+ "(ADR-0006 §6 same-patch obligation); key not found")
	).is_true()

	# Key+value exact match — prevents drift from value change
	assert_bool(content.contains('"ROUND_CAP": 30')).override_failure_message(
		("AC-5: balance_entities.json must contain '\"ROUND_CAP\": 30' literal; "
		+ "value mismatch or format drift — required: \"ROUND_CAP\": 30")
	).is_true()


# ── AC-6: AC-18 player-side precedence (mutual kill) ─────────────────────────

## AC-6 (TR-020 / AC-18): PLAYER_WIN checked BEFORE PLAYER_LOSE in _evaluate_victory.
## Mutual kill scenario: both P1 and E1 have turn_state = DEAD simultaneously.
## Given: _unit_states contains P1 (DEAD) and E1 (DEAD) — both factions at 0 alive.
## When: _evaluate_victory() called.
## Then: returns PLAYER_WIN (0), NOT PLAYER_LOSE (1) — enemy_alive == 0 check fires first.
func test_evaluate_victory_mutual_kill_returns_player_win_not_player_lose() -> void:
	# Arrange — both units marked DEAD (mutual kill simultaneity)
	_runner._unit_states[_UID_P1].turn_state = TurnOrderRunner.TurnState.DEAD
	_runner._unit_states[_UID_E1].turn_state = TurnOrderRunner.TurnState.DEAD

	# Act
	var result: Variant = _runner._evaluate_victory()

	# Assert — not null
	assert_bool(result != null).override_failure_message(
		"AC-6: _evaluate_victory() must not return null when all units are dead (mutual kill)"
	).is_true()

	# Assert — PLAYER_WIN (0), not PLAYER_LOSE (1)
	assert_int(result as int).override_failure_message(
		("AC-6 AC-18 mutual kill: _evaluate_victory() must return PLAYER_WIN (0) when both "
		+ "factions are at 0 alive — enemy_alive == 0 check must fire BEFORE player_alive == 0; "
		+ "got %d (expected 0=PLAYER_WIN)") % (result as int)
	).is_equal(_PLAYER_WIN)


# ── AC-7: AC-22 T7 emit precedence over RE2 ──────────────────────────────────

## AC-7 (TR-020 / AC-22): T7 victory emit fires BEFORE RE2 evaluation.
## Round 30, last unit's T7 detects PLAYER_WIN → BATTLE_ENDED → _end_round no-op.
## Given: _round_number = 30; E1 removed from _unit_states (simulating death);
##        _queue = [P1], _queue_index = 0 (last unit in queue).
## When: _advance_turn(_UID_P1) runs T7 → detects PLAYER_WIN → emits → returns.
## Then: signal_log has 1 entry (PLAYER_WIN); _end_round would find BATTLE_ENDED and short-circuit.
func test_t7_victory_win_suppresses_re2_draw_on_round_30() -> void:
	# Arrange — round 30; kill E1 (remove from _unit_states, simulating death without signal)
	_runner._round_number = 30
	_runner._unit_states.erase(_UID_E1)
	_runner._rebuild_queue()
	# Queue should be [P1] only now
	_runner._queue_index = 0
	_runner._round_state = TurnOrderRunner.RoundState.ROUND_ACTIVE

	# Act — _advance_turn for P1 (only unit; T7 sees enemy_alive == 0 → PLAYER_WIN)
	_runner._advance_turn(_UID_P1)

	# Assert — exactly 1 victory signal; result is PLAYER_WIN (not DRAW)
	var count: int = _count_victory_signals()
	assert_int(count).override_failure_message(
		("AC-7 AC-22: T7 PLAYER_WIN must emit exactly 1 victory signal on round 30; "
		+ "got %d signals") % count
	).is_equal(1)

	var result: int = _first_victory_result()
	assert_int(result).override_failure_message(
		("AC-7 AC-22: T7 must emit PLAYER_WIN (0), not DRAW (2); got %d — "
		+ "T7 precedence over RE2 broken") % result
	).is_equal(_PLAYER_WIN)

	# Assert — BATTLE_ENDED state (from T7 emit)
	assert_int(_runner._round_state as int).override_failure_message(
		("AC-7: _round_state must be BATTLE_ENDED after T7 PLAYER_WIN emit; got %d")
		% (_runner._round_state as int)
	).is_equal(TurnOrderRunner.RoundState.BATTLE_ENDED as int)


# ── AC-8: GDD AC-16 Round Cap DRAW at Round 30 ────────────────────────────────

## AC-8 (GDD AC-16 F-3): Round 30 with units alive on both sides → last T7 no victory
## → RE2 evaluates _round_number >= ROUND_CAP → emits DRAW.
## This is a multi-step integration test simulating the full round-30 path.
## Given: _round_number = 30; P1 (alive) + E1 (alive) — both present.
## Scenario: P1 takes turn at T7, no victory (E1 still alive) → queue exhausted → _end_round.
## Then: RE2 emits DRAW; _round_state == BATTLE_ENDED.
func test_round_30_draw_when_both_factions_alive_at_end_of_round() -> void:
	# Arrange — round 30; both units alive; P1 is last in queue
	_runner._round_number = 30
	_runner._round_state = TurnOrderRunner.RoundState.ROUND_ACTIVE
	# Use only P1 in queue (E1 still in _unit_states but not in queue — simulating E1 already acted)
	# We force _queue = [P1], _queue_index = 0; E1 alive in _unit_states
	_runner._queue.clear()
	_runner._queue.append(_UID_P1)
	_runner._queue_index = 0

	# Act — _advance_turn for P1: T7 → _evaluate_victory returns null (E1 alive) →
	# _advance_to_next_queued_unit → queue exhausted → _end_round → RE2 DRAW
	_runner._advance_turn(_UID_P1)

	# Assert — exactly 1 victory signal; result is DRAW
	var count: int = _count_victory_signals()
	assert_int(count).override_failure_message(
		("AC-8 GDD AC-16: Round 30 last T7 with both factions alive must emit DRAW via RE2; "
		+ "got %d signals — expected exactly 1") % count
	).is_equal(1)

	var result: int = _first_victory_result()
	assert_int(result).override_failure_message(
		("AC-8 GDD AC-16: RE2 round-cap must emit DRAW (2) on round 30; got %d") % result
	).is_equal(_DRAW)

	# Assert — BATTLE_ENDED (RE3 suppressed)
	assert_int(_runner._round_state as int).override_failure_message(
		("AC-8: _round_state must be BATTLE_ENDED after DRAW emit; got %d")
		% (_runner._round_state as int)
	).is_equal(TurnOrderRunner.RoundState.BATTLE_ENDED as int)


# ── AC-9: GDD AC-18 Mutual Kill PLAYER_WIN ───────────────────────────────────

## AC-9 (GDD AC-18 EC-04): Last player A attacks last enemy B; B dies (unit_died emit);
## B's counter-attack kills A (unit_died emit). T7 evaluates after both deaths.
## Expected: PLAYER_WIN emitted (player-side precedence — enemy_alive == 0 checked first).
##
## Implementation note: this test simulates the mutual-kill by:
##   1. Emitting unit_died for E1 (B dies from attack) + await deferred frame
##   2. Emitting unit_died for P1 (A dies from counter) + await deferred frame
##   3. Both are now removed from _unit_states
##   4. Calling _evaluate_victory() to verify it returns PLAYER_WIN
##   5. Calling _emit_victory (via _advance_turn path) to verify signal emission
##
## The CONNECT_DEFERRED subscription means both removals happen asynchronously.
## After both drain, _unit_states is empty — mutual kill state reached.
func test_mutual_kill_emits_player_win_not_player_lose() -> void:
	# Arrange — reset to round 1 (not 30) to ensure DRAW is not triggered
	_runner._round_number = 1
	_runner._round_state = TurnOrderRunner.RoundState.ROUND_ACTIVE

	# Step 1: E1 dies (B killed by A's attack)
	_kill_unit(_UID_E1)
	await get_tree().process_frame
	# E1 removed from _unit_states
	assert_bool(_runner._unit_states.has(_UID_E1)).override_failure_message(
		"AC-9 setup: E1 must be removed from _unit_states after unit_died"
	).is_false()

	# Step 2: P1 dies (A killed by B's counter-attack)
	_kill_unit(_UID_P1)
	await get_tree().process_frame
	# P1 removed from _unit_states
	assert_bool(_runner._unit_states.has(_UID_P1)).override_failure_message(
		"AC-9 setup: P1 must be removed from _unit_states after unit_died"
	).is_false()

	# Step 3: _unit_states is now empty (mutual kill)
	assert_int(_runner._unit_states.size()).override_failure_message(
		"AC-9 setup: _unit_states must be empty after mutual kill"
	).is_equal(0)

	# Step 4: Evaluate victory directly
	var eval_result: Variant = _runner._evaluate_victory()
	assert_bool(eval_result != null).override_failure_message(
		"AC-9: _evaluate_victory() must not return null for mutual kill (both factions at 0)"
	).is_true()
	assert_int(eval_result as int).override_failure_message(
		("AC-9 AC-18 EC-04: _evaluate_victory() must return PLAYER_WIN (0) for mutual kill; "
		+ "got %d — enemy_alive == 0 check must fire BEFORE player_alive == 0") % (eval_result as int)
	).is_equal(_PLAYER_WIN)

	# Step 5: Emit via _emit_victory and verify signal
	_runner._emit_victory(eval_result as int)

	var count: int = _count_victory_signals()
	assert_int(count).override_failure_message(
		("AC-9: victory_condition_detected must emit exactly 1 time for mutual kill; got %d") % count
	).is_equal(1)

	var signal_result: int = _first_victory_result()
	assert_int(signal_result).override_failure_message(
		("AC-9: victory_condition_detected payload must be PLAYER_WIN (0); got %d") % signal_result
	).is_equal(_PLAYER_WIN)


# ── AC-10: GDD AC-22 T7 WIN beats RE2 DRAW on Round 30 ──────────────────────

## AC-10 (GDD AC-22 EC-19): Round 30, last enemy dies at T5 (counter-attack scenario).
## T7 fires → _evaluate_victory → PLAYER_WIN → _emit_victory → BATTLE_ENDED → return.
## _end_round (RE2) is NOT called because T7 returned early after emit.
## Given: _round_number = 30; E1 killed (unit_died + await) before T7 evaluation;
##        P1 is the active unit; T7 runs and detects enemy_alive == 0 → PLAYER_WIN.
## Then: signal_log == [{result: 0}]; _round_state == BATTLE_ENDED;
##       _end_round never fires RE2 DRAW.
func test_round_30_t7_win_beats_re2_draw_t7_precedence() -> void:
	# Arrange — round 30; E1 dies first (simulates T5 counter-attack death)
	_runner._round_number = 30
	_runner._round_state = TurnOrderRunner.RoundState.ROUND_ACTIVE
	_runner._queue.clear()
	_runner._queue.append(_UID_P1)  # P1 is the last acting unit
	_runner._queue_index = 0

	# Kill E1 before T7 (deferred — must drain)
	_kill_unit(_UID_E1)
	await get_tree().process_frame

	# Verify E1 is gone from _unit_states
	assert_bool(_runner._unit_states.has(_UID_E1)).override_failure_message(
		"AC-10 setup: E1 must be removed before T7 evaluation"
	).is_false()

	# Act — _advance_turn for P1 on round 30:
	# T7: enemy_alive == 0 → PLAYER_WIN → _emit_victory → BATTLE_ENDED → return (no _end_round)
	_runner._advance_turn(_UID_P1)

	# Assert — exactly 1 signal; PLAYER_WIN (not DRAW)
	var count: int = _count_victory_signals()
	assert_int(count).override_failure_message(
		("AC-10 GDD AC-22: Round 30 T7 WIN must emit exactly 1 victory_condition_detected; "
		+ "got %d — possible double-emit (T7 + RE2)") % count
	).is_equal(1)

	var result: int = _first_victory_result()
	assert_int(result).override_failure_message(
		("AC-10 GDD AC-22: T7 must emit PLAYER_WIN (0), not DRAW (2), on round 30; "
		+ "got %d — RE2 DRAW must be suppressed because T7 set BATTLE_ENDED first") % result
	).is_equal(_PLAYER_WIN)

	# Assert — BATTLE_ENDED (from T7 emit, not RE2)
	assert_int(_runner._round_state as int).override_failure_message(
		("AC-10: _round_state must be BATTLE_ENDED after T7 PLAYER_WIN; got %d")
		% (_runner._round_state as int)
	).is_equal(TurnOrderRunner.RoundState.BATTLE_ENDED as int)


# ── AC-11: Regression (ROUND_CAP key + basic baseline) ───────────────────────

## AC-11 combined: ROUND_CAP key present + VictoryResult enum values are correct.
## This test provides a structural verification that the story-006 same-patch additions
## are complete: enum values match spec (0/1/2) and JSON key exists.
func test_victory_result_enum_values_match_spec() -> void:
	# VictoryResult enum backing values must be exactly 0, 1, 2 per ADR-0011 line 152.
	assert_int(TurnOrderRunner.VictoryResult.PLAYER_WIN as int).override_failure_message(
		"AC-11: VictoryResult.PLAYER_WIN must == 0 per ADR-0011 spec"
	).is_equal(0)

	assert_int(TurnOrderRunner.VictoryResult.PLAYER_LOSE as int).override_failure_message(
		"AC-11: VictoryResult.PLAYER_LOSE must == 1 per ADR-0011 spec"
	).is_equal(1)

	assert_int(TurnOrderRunner.VictoryResult.DRAW as int).override_failure_message(
		"AC-11: VictoryResult.DRAW must == 2 per ADR-0011 spec"
	).is_equal(2)


## AC-11: GameBus.victory_condition_detected signal is declared (same-patch amendment).
func test_victory_condition_detected_signal_declared_on_gamebus() -> void:
	var signal_found: bool = false
	for sig: Dictionary in GameBus.get_signal_list():
		if (sig.get("name", "") as String) == "victory_condition_detected":
			signal_found = true
			break
	assert_bool(signal_found).override_failure_message(
		("AC-11: GameBus.victory_condition_detected must be declared "
		+ "(ADR-0001 same-patch amendment per ADR-0011 §Migration Plan §0); "
		+ "signal not found on GameBus")
	).is_true()
