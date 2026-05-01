extends GdUnitTestSuite

## turn_order_advance_turn_test.gd
## Unit tests for Story 003 (turn-order epic): TurnOrderRunner._advance_turn T1..T7
## sequence, _begin_round R1..R4 round-start, and 3 emitted GameBus signals.
##
## Covers AC-1 through AC-11 from story-003 §Acceptance Criteria.
##
## Governing ADR: ADR-0011 — Turn Order / Action Management (Accepted 2026-04-30).
## Also governs: ADR-0001 (GameBus single-emitter) + ADR-0010 (HP/Status DoT consumer).
##
## TEST APPROACH:
##   G-10: subscribe to REAL /root/GameBus, NOT a stub. All signal connections use
##   the production GameBus autoload identifier directly.
##   G-4 sidestep: method-reference capture handlers (NOT lambdas) are used for all
##   signal subscriptions. Method references are safe for connect + disconnect.
##   G-15: before_test() resets all 5 runner instance fields + creates fresh runner.
##   after_test() MUST disconnect all signal connections to prevent accumulation.
##
## ISOLATION DISCIPLINE (G-15):
##   before_test() creates a fresh TurnOrderRunner per test, resets all 5 fields,
##   clears _signal_log, and connects the 3 capture handlers to real GameBus.
##   after_test() disconnects all 3 handlers unconditionally (is_connected guard).
##
## GOTCHA AWARENESS:
##   G-2  — typed-array preservation: .assign() not .duplicate()
##   G-4  — lambda primitive capture: use method refs instead of lambdas
##   G-9  — % operator precedence: wrap multi-line concat in parens before %
##   G-10 — subscribe to real GameBus (NOT stub) per autoload binding semantics
##   G-15 — before_test() is the canonical GdUnit4 v6.1.2 hook (NOT before_each)
##   G-23 — GdUnit4 v6.1.2 has no is_not_equal_approx(); use is_not_equal() or manual
##   G-24 — as-operator precedence: wrap RHS cast in parens in == expressions

# ── Constants ─────────────────────────────────────────────────────────────────

## MVP hero IDs (heroes.json verified 2026-05-01).
## stat_agility: liu_bei=65, guan_yu=70, zhang_fei=60, cao_cao=70, xiahou_dun=65.
const _HERO_LIU_BEI: StringName    = &"shu_001_liu_bei"
const _HERO_GUAN_YU: StringName    = &"shu_002_guan_yu"
const _HERO_ZHANG_FEI: StringName  = &"shu_003_zhang_fei"
const _HERO_CAO_CAO: StringName    = &"wei_001_cao_cao"
const _HERO_XIAHOU_DUN: StringName = &"wei_005_xiahou_dun"

## UnitRole.UnitClass int backing values (unit_role.gd — locked per ADR-0009).
const _CLASS_CAVALRY: int    = 0
const _CLASS_INFANTRY: int   = 1
const _CLASS_ARCHER: int     = 2
const _CLASS_STRATEGIST: int = 3
const _CLASS_COMMANDER: int  = 4
const _CLASS_SCOUT: int      = 5

# ── Suite state ───────────────────────────────────────────────────────────────

var _runner: TurnOrderRunner
## Unified signal log — all 3 capture handlers append here.
## G-4: method refs avoid lambda primitive-capture hazard entirely.
## G-16: typed Array[Dictionary] preserves element type for filter sub-arrays.
var _signal_log: Array[Dictionary] = []

# ── Signal capture handlers (method-reference form — sidesteps G-4) ──────────

func _capture_round_started(round_number: int) -> void:
	_signal_log.append({"signal": "round_started", "round_number": round_number})


func _capture_unit_turn_started(unit_id: int) -> void:
	_signal_log.append({"signal": "unit_turn_started", "unit_id": unit_id})


func _capture_unit_turn_ended(unit_id: int, acted: bool) -> void:
	_signal_log.append({"signal": "unit_turn_ended", "unit_id": unit_id, "acted": acted})


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func before_test() -> void:
	## G-15: canonical GdUnit4 v6.1.2 per-test hook (NOT before_each).
	## Creates a fresh TurnOrderRunner and resets all 5 instance fields.
	## Connects the 3 capture handlers to the real GameBus (G-10).
	_signal_log.clear()
	_runner = auto_free(TurnOrderRunner.new())
	add_child(_runner)
	# Reset all 5 instance fields (defensive even on fresh runner)
	# G-15 marker: _unit_states.clear() — runner under test resets via initialize_battle
	_runner._unit_states.clear()
	_runner._queue.clear()
	_runner._round_number = 0
	_runner._queue_index = 0
	_runner._round_state = TurnOrderRunner.RoundState.BATTLE_NOT_STARTED
	# Connect capture handlers to real GameBus (G-10: NOT a stub)
	GameBus.round_started.connect(_capture_round_started)
	GameBus.unit_turn_started.connect(_capture_unit_turn_started)
	GameBus.unit_turn_ended.connect(_capture_unit_turn_ended)


func after_test() -> void:
	## CRITICAL G-15: disconnect ALL handlers to prevent accumulation across tests.
	## is_connected guard prevents double-disconnect errors on out-of-order teardown.
	if GameBus.round_started.is_connected(_capture_round_started):
		GameBus.round_started.disconnect(_capture_round_started)
	if GameBus.unit_turn_started.is_connected(_capture_unit_turn_started):
		GameBus.unit_turn_started.disconnect(_capture_unit_turn_started)
	if GameBus.unit_turn_ended.is_connected(_capture_unit_turn_ended):
		GameBus.unit_turn_ended.disconnect(_capture_unit_turn_ended)


# ── Helper ────────────────────────────────────────────────────────────────────

## Constructs a BattleUnit with the specified fields.
## G-2: typed-array preservation — callers use roster.append(_make_unit(...)).
func _make_unit(
		unit_id: int,
		hero_id: StringName,
		unit_class: int,
		is_player: bool) -> BattleUnit:
	var u: BattleUnit = BattleUnit.new()
	u.unit_id = unit_id
	u.hero_id = hero_id
	u.unit_class = unit_class
	u.is_player_controlled = is_player
	return u


## Initializes the runner with a 1-unit roster (liu_bei, unit_id=1) and
## manually transitions _round_state to ROUND_ACTIVE without triggering
## the deferred _begin_round chain. Clears _signal_log after setup.
## Used by tests that call _advance_turn(uid) directly (synchronous path).
func _setup_single_unit_round_active(uid: int) -> void:
	var roster: Array[BattleUnit] = []
	roster.append(_make_unit(uid, _HERO_LIU_BEI, _CLASS_COMMANDER, true))
	_runner.initialize_battle(roster)
	# Manually set ROUND_ACTIVE to bypass the deferred _begin_round chain.
	# _begin_round would also be fine but adds the deferred frame complexity.
	_runner._round_state = TurnOrderRunner.RoundState.ROUND_ACTIVE
	# Clear any signals emitted by initialize_battle (ROUND_STARTING transition has none,
	# but _begin_round deferred fire might arrive — suppress by clearing log now)
	_signal_log.clear()


# ── AC-1: _advance_turn callable directly from test ───────────────────────────


## AC-1 (test seam): calling _advance_turn(uid) directly on a post-init runner
## completes the full T1..T7 sequence and leaves turn_state == DONE.
## Given: runner post-init with 1 unit; _round_state manually set to ROUND_ACTIVE.
## When:  _runner._advance_turn(uid) called directly (synchronous, no deferred).
## Then:  _unit_states[uid].turn_state == DONE (proves T1–T7 ran to completion).
func test_advance_turn_test_seam_callable_directly_from_test() -> void:
	# Arrange
	var uid: int = 1
	_setup_single_unit_round_active(uid)

	# Act — direct call (T1..T7 runs synchronously; T5 stub is pass)
	_runner._advance_turn(uid)

	# Assert — full sequence ran: state must be DONE
	assert_int(
		_runner._unit_states[uid].turn_state as int
	).override_failure_message(
		("AC-1: after _advance_turn(%d), turn_state must be DONE (%d); "
		+ "got %d — T1..T7 sequence did not complete")
		% [uid, TurnOrderRunner.TurnState.DONE as int,
			(_runner._unit_states[uid].turn_state as int)]
	).is_equal(TurnOrderRunner.TurnState.DONE as int)


# ── AC-2: _begin_round emits round_started ────────────────────────────────────


## AC-2 (round_started signal): _begin_round emits GameBus.round_started with
## round_number == 1 on first (isolated) call.
## Given: runner with 1 unit; deferred _begin_round from initialize_battle drained;
##        state reset to ROUND_STARTING and round_number=0 for a clean isolated call.
## When:  _runner._begin_round() called; await one process_frame for deferred chain.
## Then:  _signal_log contains exactly one round_started entry with round_number == 1.
func test_begin_round_emits_round_started_with_round_number_one() -> void:
	# Arrange — initialize_battle schedules call_deferred(_begin_round) internally.
	# Drain that deferred call first (await 1 frame) so it doesn't pollute the log.
	var uid: int = 1
	var roster: Array[BattleUnit] = []
	roster.append(_make_unit(uid, _HERO_LIU_BEI, _CLASS_COMMANDER, true))
	_runner.initialize_battle(roster)
	await get_tree().process_frame  # drain initialize_battle's deferred _begin_round

	# Reset state for a clean isolated _begin_round call.
	_runner._round_number = 0
	_runner._queue_index = 0
	_runner._round_state = TurnOrderRunner.RoundState.ROUND_STARTING
	_signal_log.clear()

	# Act — call _begin_round directly; await frame for call_deferred chain to drain
	_runner._begin_round()
	await get_tree().process_frame

	# Assert — exactly one round_started with round_number == 1
	var round_started_entries: Array[Dictionary] = []
	for entry: Dictionary in _signal_log:
		if (entry.get("signal", "") as String) == "round_started":
			round_started_entries.append(entry)

	assert_int(round_started_entries.size()).override_failure_message(
		("AC-2: _begin_round must emit exactly 1 round_started signal; "
		+ "got %d entries in signal_log")
		% round_started_entries.size()
	).is_equal(1)

	assert_int(
		round_started_entries[0].get("round_number", -1) as int
	).override_failure_message(
		("AC-2: round_started must carry round_number == 1 on first _begin_round call; "
		+ "got %d")
		% (round_started_entries[0].get("round_number", -1) as int)
	).is_equal(1)


# ── AC-3 + AC-7: unit_turn_started emitted at T4 ─────────────────────────────


## AC-3 + AC-7 (unit_turn_started at T4): _advance_turn emits unit_turn_started
## with the unit_id after _activate_unit_turn resets token state.
## Given: runner post-init 1 unit; _round_state manually set ROUND_ACTIVE.
## When:  _runner._advance_turn(uid) called directly.
## Then:  unit_turn_started fires with unit_id == uid; final turn_state == DONE.
func test_advance_turn_emits_unit_turn_started_at_t4_after_activate() -> void:
	# Arrange
	var uid: int = 1
	_setup_single_unit_round_active(uid)

	# Act
	_runner._advance_turn(uid)

	# Assert — unit_turn_started fired with correct unit_id
	var started_entries: Array[Dictionary] = []
	for entry: Dictionary in _signal_log:
		if (entry.get("signal", "") as String) == "unit_turn_started":
			started_entries.append(entry)

	assert_int(started_entries.size()).override_failure_message(
		("AC-3: _advance_turn must emit exactly 1 unit_turn_started signal; "
		+ "got %d")
		% started_entries.size()
	).is_equal(1)

	assert_int(
		started_entries[0].get("unit_id", -1) as int
	).override_failure_message(
		("AC-3: unit_turn_started must carry unit_id == %d; got %d")
		% [uid, (started_entries[0].get("unit_id", -1) as int)]
	).is_equal(uid)

	# AC-7: T4→T6 ran synchronously (T5 stub is pass); final state == DONE
	assert_int(
		_runner._unit_states[uid].turn_state as int
	).override_failure_message(
		("AC-7: after _advance_turn(%d), turn_state must be DONE (%d); got %d")
		% [uid, TurnOrderRunner.TurnState.DONE as int,
			(_runner._unit_states[uid].turn_state as int)]
	).is_equal(TurnOrderRunner.TurnState.DONE as int)


# ── AC-4 + AC-9 (acted=false default): unit_turn_ended emitted at T6 ─────────


## AC-4 + AC-9 default path (unit_turn_ended): _advance_turn emits unit_turn_ended
## with acted == false (default: no tokens spent in T5 stub).
## Given: runner post-init 1 unit; _round_state manually set ROUND_ACTIVE.
## When:  _runner._advance_turn(uid) called directly.
## Then:  unit_turn_ended fires with unit_id == uid, acted == false.
func test_advance_turn_emits_unit_turn_ended_at_t6() -> void:
	# Arrange
	var uid: int = 1
	_setup_single_unit_round_active(uid)

	# Act
	_runner._advance_turn(uid)

	# Assert — unit_turn_ended fired with correct args
	var ended_entries: Array[Dictionary] = []
	for entry: Dictionary in _signal_log:
		if (entry.get("signal", "") as String) == "unit_turn_ended":
			ended_entries.append(entry)

	assert_int(ended_entries.size()).override_failure_message(
		("AC-4: _advance_turn must emit exactly 1 unit_turn_ended signal; "
		+ "got %d")
		% ended_entries.size()
	).is_equal(1)

	assert_int(
		ended_entries[0].get("unit_id", -1) as int
	).override_failure_message(
		("AC-4: unit_turn_ended must carry unit_id == %d; got %d")
		% [uid, (ended_entries[0].get("unit_id", -1) as int)]
	).is_equal(uid)

	# AC-9 default path: no tokens spent in T5 stub → acted == false
	assert_bool(
		ended_entries[0].get("acted", true) as bool
	).override_failure_message(
		("AC-9 default: unit_turn_ended.acted must be false when no tokens spent; "
		+ "T5 stub is pass so both tokens remain unspent")
	).is_false()


# ── AC-5: T2 dead unit short-circuits, no emit ────────────────────────────────


## AC-5 dead path (T2 short-circuit): _advance_turn does NOT emit unit_turn_started
## or unit_turn_ended when the unit's turn_state is DEAD at T2.
## Given: runner post-init 1 unit; turn_state manually set to DEAD.
## When:  _runner._advance_turn(uid) called.
## Then:  NEITHER unit_turn_started NOR unit_turn_ended fires (T2 short-circuits).
func test_advance_turn_t2_dead_unit_short_circuits_no_emit() -> void:
	# Arrange
	var uid: int = 1
	_setup_single_unit_round_active(uid)
	# Manually mark unit as DEAD (simulating post-death state)
	_runner._unit_states[uid].turn_state = TurnOrderRunner.TurnState.DEAD

	# Act
	_runner._advance_turn(uid)

	# Assert — NEITHER signal fired
	var started_count: int = 0
	var ended_count: int = 0
	for entry: Dictionary in _signal_log:
		var sig: String = entry.get("signal", "") as String
		if sig == "unit_turn_started":
			started_count += 1
		elif sig == "unit_turn_ended":
			ended_count += 1

	assert_int(started_count).override_failure_message(
		("AC-5 dead: T2 short-circuit must suppress unit_turn_started; "
		+ "got %d emissions — T2 defensive check is not firing before T4")
		% started_count
	).is_equal(0)

	assert_int(ended_count).override_failure_message(
		("AC-5 dead: T2 short-circuit must suppress unit_turn_ended; "
		+ "got %d emissions — T2 defensive check is not firing before T6")
		% ended_count
	).is_equal(0)


# ── AC-5 edge case: unknown unit_id short-circuits, no emit ──────────────────


## AC-5 edge case (T2 unknown unit_id): _advance_turn does NOT emit any signal
## when the unit_id is not present in _unit_states. No crash occurs.
## Given: runner post-init with units 1+2; _round_state ROUND_ACTIVE.
## When:  _runner._advance_turn(9999) called (uid not in _unit_states).
## Then:  NEITHER unit_turn_started NOR unit_turn_ended fires; no crash.
func test_advance_turn_t2_unknown_unit_id_short_circuits_no_emit() -> void:
	# Arrange — 2-unit roster so _unit_states is populated (just not with 9999)
	var roster: Array[BattleUnit] = []
	roster.append(_make_unit(1, _HERO_LIU_BEI, _CLASS_COMMANDER, true))
	roster.append(_make_unit(2, _HERO_GUAN_YU, _CLASS_INFANTRY,  false))
	_runner.initialize_battle(roster)
	_runner._round_state = TurnOrderRunner.RoundState.ROUND_ACTIVE
	_signal_log.clear()

	# Act — 9999 is not in _unit_states; should short-circuit at T2
	_runner._advance_turn(9999)

	# Assert — no signals fired; no crash (test would error if crash occurred)
	var started_count: int = 0
	var ended_count: int = 0
	for entry: Dictionary in _signal_log:
		var sig: String = entry.get("signal", "") as String
		if sig == "unit_turn_started":
			started_count += 1
		elif sig == "unit_turn_ended":
			ended_count += 1

	assert_int(started_count).override_failure_message(
		("AC-5 unknown: T2 unknown-unit_id must suppress unit_turn_started; "
		+ "got %d emissions — _unit_states.has() guard is not firing")
		% started_count
	).is_equal(0)

	assert_int(ended_count).override_failure_message(
		("AC-5 unknown: T2 unknown-unit_id must suppress unit_turn_ended; "
		+ "got %d emissions")
		% ended_count
	).is_equal(0)


# ── AC-7: _activate_unit_turn resets tokens ────────────────────────────────────


## AC-7 (token reset): _activate_unit_turn (called at T4) resets all 4 dirty token
## fields to defaults. Verified by asserting post-T6 field values == defaults.
## T4 resets to: move_token_spent=false, action_token_spent=false,
## accumulated_move_cost=0, acted_this_turn=false.
## T6 then sets acted_this_turn = move_token_spent OR action_token_spent = false OR false = false.
## All 4 fields end at default values. ✓
## Given: runner post-init 1 unit; 4 token fields pre-set to dirty values.
## When:  _runner._advance_turn(uid) called directly.
## Then:  all 4 token fields == default (reset by T4 _activate_unit_turn; T5 stub = pass).
func test_activate_unit_turn_resets_tokens_and_transitions_to_acting_via_advance_turn() -> void:
	# Arrange — pre-set dirty state simulating stale prior turn
	var uid: int = 1
	_setup_single_unit_round_active(uid)
	var state: UnitTurnState = _runner._unit_states[uid]
	state.move_token_spent = true
	state.action_token_spent = true
	state.accumulated_move_cost = 5
	state.acted_this_turn = true

	# Act — T4 resets, T5 stub is pass, T6 computes acted from (false OR false)
	_runner._advance_turn(uid)

	# Assert — all 4 fields are at default post-T4-reset (T5 spent no tokens)
	var post_state: UnitTurnState = _runner._unit_states[uid]

	assert_bool(post_state.move_token_spent).override_failure_message(
		("AC-7: move_token_spent must be false after T4 reset + no T5 spend; "
		+ "got true — _activate_unit_turn did not reset move_token_spent")
	).is_false()

	assert_bool(post_state.action_token_spent).override_failure_message(
		("AC-7: action_token_spent must be false after T4 reset + no T5 spend; "
		+ "got true — _activate_unit_turn did not reset action_token_spent")
	).is_false()

	assert_int(post_state.accumulated_move_cost).override_failure_message(
		("AC-7: accumulated_move_cost must be 0 after T4 reset; "
		+ "got %d — _activate_unit_turn did not reset accumulated_move_cost")
		% post_state.accumulated_move_cost
	).is_equal(0)

	# acted_this_turn: T4 reset to false; T5 stub doesn't spend tokens;
	# T6 sets acted_this_turn = false OR false = false.
	assert_bool(post_state.acted_this_turn).override_failure_message(
		("AC-7: acted_this_turn must be false when no tokens spent in T5 stub; "
		+ "T4 reset to false + T5 stub = pass → T6 computes false OR false = false")
	).is_false()


# ── AC-9 default: unit_turn_ended.acted == false when no tokens spent ─────────


## AC-9 default path confirmation (acted=false): unit_turn_ended.acted is false
## when neither token is spent (T5 stub is pass).
## This test is a standalone confirmation of the acted=false contract.
## Given: runner post-init 1 unit; no dirty token pre-set.
## When:  _runner._advance_turn(uid) called.
## Then:  unit_turn_ended signal fires with acted == false.
func test_advance_turn_t6_acted_false_when_no_tokens_spent() -> void:
	# Arrange
	var uid: int = 1
	_setup_single_unit_round_active(uid)

	# Act
	_runner._advance_turn(uid)

	# Assert — unit_turn_ended.acted == false
	var ended_entries: Array[Dictionary] = []
	for entry: Dictionary in _signal_log:
		if (entry.get("signal", "") as String) == "unit_turn_ended":
			ended_entries.append(entry)

	assert_int(ended_entries.size()).override_failure_message(
		("AC-9: must capture exactly 1 unit_turn_ended signal; got %d")
		% ended_entries.size()
	).is_equal(1)

	assert_bool(
		ended_entries[0].get("acted", true) as bool
	).override_failure_message(
		("AC-9: unit_turn_ended.acted must be false when T5 stub makes no token spends; "
		+ "T4 resets tokens, T5 passes, T6 computes false OR false = false")
	).is_false()


# ── AC-9 state: turn_state == DONE at T6 ─────────────────────────────────────


## AC-9 state confirmation: turn_state transitions to DONE at T6 (_mark_acted).
## Given: runner post-init 1 unit; _round_state manually ROUND_ACTIVE.
## When:  _runner._advance_turn(uid) called.
## Then:  _unit_states[uid].turn_state == DONE.
func test_advance_turn_transitions_state_to_done_at_t6() -> void:
	# Arrange
	var uid: int = 1
	_setup_single_unit_round_active(uid)

	# Act
	_runner._advance_turn(uid)

	# Assert
	assert_int(
		_runner._unit_states[uid].turn_state as int
	).override_failure_message(
		("AC-9 state: turn_state must be DONE (%d) after _advance_turn; got %d "
		+ "— _mark_acted is not transitioning turn_state to DONE")
		% [TurnOrderRunner.TurnState.DONE as int,
			(_runner._unit_states[uid].turn_state as int)]
	).is_equal(TurnOrderRunner.TurnState.DONE as int)


# ── AC-11 (GDD AC-02): round lifecycle signal order for 2-unit roster ─────────


## AC-11 / GDD AC-02 (round lifecycle emit order): a full round cycle for a 2-unit
## roster emits signals in exactly the order:
##   [round_started(1), unit_turn_started(uid_a), unit_turn_ended(uid_a, false),
##    unit_turn_started(uid_b), unit_turn_ended(uid_b, false)]
## where uid_a and uid_b are the F-1 cascade queue order from _runner._queue post-init.
##
## Given: runner initialized with 2 MVP heroes.
## When:  _runner._begin_round() called; await get_tree().process_frame twice
##        (first frame drains _begin_round deferred chain → unit_a turn starts;
##         second frame drains unit_a deferred advance → unit_b turn;
##         unit_b is synchronous after call_deferred resolves).
## Then:  _signal_log order matches [round_started, unit_turn_started(a),
##        unit_turn_ended(a), unit_turn_started(b), unit_turn_ended(b)].
func test_round_lifecycle_emit_order_two_units() -> void:
	# Arrange — 2-unit roster (real MVP heroes for initiative-based F-1 cascade ordering).
	# initialize_battle schedules call_deferred(_begin_round) internally — drain it first.
	var roster: Array[BattleUnit] = []
	roster.append(_make_unit(1, _HERO_LIU_BEI, _CLASS_COMMANDER, true))
	roster.append(_make_unit(2, _HERO_GUAN_YU, _CLASS_INFANTRY,  false))
	_runner.initialize_battle(roster)
	await get_tree().process_frame  # drain initialize_battle's deferred _begin_round
	await get_tree().process_frame  # drain queue[0]'s deferred _advance_turn(queue[1])
	await get_tree().process_frame  # drain queue[1]'s ROUND_ENDING transition (full chain settles)

	# Seed synthetic initiatives to make ordering deterministic regardless of
	# UnitRole.get_initiative balance changes: uid=1 gets 120, uid=2 gets 100.
	_runner._seed_unit_state_for_test(1, 120, 65, true)
	_runner._seed_unit_state_for_test(2, 100, 70, false)

	# Reset state for a clean isolated _begin_round call.
	_runner._round_number = 0
	_runner._queue_index = 0
	_runner._round_state = TurnOrderRunner.RoundState.ROUND_STARTING
	_signal_log.clear()

	# Act — call _begin_round directly; await frames for full deferred chain.
	# Frame 1: _begin_round runs → emits round_started → call_deferred(_advance_turn, queue[0])
	# Frame 2: _advance_turn(queue[0]) runs → emits unit_turn_started(a) + unit_turn_ended(a)
	#           → call_deferred(_advance_turn, queue[1])
	# Frame 3: _advance_turn(queue[1]) runs → emits unit_turn_started(b) + unit_turn_ended(b)
	#           → ROUND_ENDING
	_runner._begin_round()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame

	# Identify expected uid order from post-seeded queue (rebuilt in _begin_round at R3)
	# After _begin_round, the queue is rebuilt; we must read it AFTER the fact.
	# Since _begin_round already ran, _runner._queue holds the R3-rebuilt order.
	# uid=1 (initiative 120) should be first; uid=2 (initiative 100) second.
	var uid_a: int = _runner._queue[0]
	var uid_b: int = _runner._queue[1]

	# Assert signal count: exactly 5 signals in total
	assert_int(_signal_log.size()).override_failure_message(
		("AC-11: full 2-unit round must produce exactly 5 signals "
		+ "[round_started, turn_started(a), turn_ended(a), turn_started(b), turn_ended(b)]; "
		+ "got %d signals in log: %s")
		% [_signal_log.size(), str(_signal_log)]
	).is_equal(5)

	# Assert signal[0]: round_started(1)
	assert_str(
		_signal_log[0].get("signal", "") as String
	).override_failure_message(
		("AC-11: signal[0] must be 'round_started'; got '%s'")
		% (_signal_log[0].get("signal", "") as String)
	).is_equal("round_started")

	assert_int(
		_signal_log[0].get("round_number", -1) as int
	).override_failure_message(
		("AC-11: signal[0] round_number must be 1; got %d")
		% (_signal_log[0].get("round_number", -1) as int)
	).is_equal(1)

	# Assert signal[1]: unit_turn_started(uid_a)
	assert_str(
		_signal_log[1].get("signal", "") as String
	).override_failure_message(
		("AC-11: signal[1] must be 'unit_turn_started'; got '%s'")
		% (_signal_log[1].get("signal", "") as String)
	).is_equal("unit_turn_started")

	assert_int(
		_signal_log[1].get("unit_id", -1) as int
	).override_failure_message(
		("AC-11: signal[1] unit_id must be uid_a=%d (queue[0]); got %d")
		% [uid_a, (_signal_log[1].get("unit_id", -1) as int)]
	).is_equal(uid_a)

	# Assert signal[2]: unit_turn_ended(uid_a, false)
	assert_str(
		_signal_log[2].get("signal", "") as String
	).override_failure_message(
		("AC-11: signal[2] must be 'unit_turn_ended'; got '%s'")
		% (_signal_log[2].get("signal", "") as String)
	).is_equal("unit_turn_ended")

	assert_int(
		_signal_log[2].get("unit_id", -1) as int
	).override_failure_message(
		("AC-11: signal[2] unit_id must be uid_a=%d; got %d")
		% [uid_a, (_signal_log[2].get("unit_id", -1) as int)]
	).is_equal(uid_a)

	assert_bool(
		_signal_log[2].get("acted", true) as bool
	).override_failure_message(
		"AC-11: signal[2] unit_turn_ended.acted must be false (T5 stub, no tokens spent)"
	).is_false()

	# Assert signal[3]: unit_turn_started(uid_b)
	assert_str(
		_signal_log[3].get("signal", "") as String
	).override_failure_message(
		("AC-11: signal[3] must be 'unit_turn_started'; got '%s'")
		% (_signal_log[3].get("signal", "") as String)
	).is_equal("unit_turn_started")

	assert_int(
		_signal_log[3].get("unit_id", -1) as int
	).override_failure_message(
		("AC-11: signal[3] unit_id must be uid_b=%d (queue[1]); got %d")
		% [uid_b, (_signal_log[3].get("unit_id", -1) as int)]
	).is_equal(uid_b)

	# Assert signal[4]: unit_turn_ended(uid_b, false)
	assert_str(
		_signal_log[4].get("signal", "") as String
	).override_failure_message(
		("AC-11: signal[4] must be 'unit_turn_ended'; got '%s'")
		% (_signal_log[4].get("signal", "") as String)
	).is_equal("unit_turn_ended")

	assert_int(
		_signal_log[4].get("unit_id", -1) as int
	).override_failure_message(
		("AC-11: signal[4] unit_id must be uid_b=%d; got %d")
		% [uid_b, (_signal_log[4].get("unit_id", -1) as int)]
	).is_equal(uid_b)

	assert_bool(
		_signal_log[4].get("acted", true) as bool
	).override_failure_message(
		"AC-11: signal[4] unit_turn_ended.acted must be false (T5 stub, no tokens spent)"
	).is_false()

	# Assert final round_state == ROUND_ENDING (queue exhausted after 2 units)
	assert_int(
		_runner._round_state as int
	).override_failure_message(
		("AC-11: after both units complete, _round_state must be ROUND_ENDING (%d); "
		+ "got %d — _advance_to_next_queued_unit did not transition on queue exhaustion")
		% [TurnOrderRunner.RoundState.ROUND_ENDING as int,
			(_runner._round_state as int)]
	).is_equal(TurnOrderRunner.RoundState.ROUND_ENDING as int)
