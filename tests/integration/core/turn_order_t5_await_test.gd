extends GdUnitTestSuite

## turn_order_t5_await_test.gd
## Integration tests for Story S15-A (turn-order epic):
##   - AC-1: T5 dispatches to controller with (unit_id, snapshot) when controller injected
##   - AC-2: T5 hold — declare_action(WAIT) path defers T6 unit_turn_ended to next frame
##   - AC-3: T5 hold — declare_action(ATTACK) path defers T6 unit_turn_ended to next frame
##   - AC-4: T5 hold — MOVE alone does NOT complete the turn
##   - AC-5: MOVE then ATTACK completes the turn (multi-action path)
##   - AC-7: TEST-SEAM backward-compat — no controller → _advance_turn runs T1→T7 sync
##
## Covers AC-1, AC-2, AC-4 (natural-loop), AC-5, AC-6 (implicit), AC-7 from S15-A §Acceptance Criteria.
## AC-3 is a doc-only ADR amendment (no dedicated test function required).
## AC-6 (set_action_controller setter) is exercised implicitly by every controller-injected test.
## Test type: Integration — crosses GameBus boundary (unit_turn_started / unit_turn_ended).
## Uses real /root/GameBus (no GameBusStub.swap_in per G-10 mandate).
## No AI / GridBattleController dependency — controller injected as test Callable.
##
## Governing ADRs: ADR-0011 §Decision Contract 5 (NATURAL-LOOP / TEST-SEAM duality),
##   ADR-0001 (GameBus signal contract), ADR-0006 (BalanceConstants accessor).
##
## GOTCHA AWARENESS:
##   G-4  — lambda primitive capture; use Array captures pattern (NOT bool/int locals)
##   G-6  — orphan detection fires BETWEEN test body exit and after_test; explicit cleanup
##   G-9  — % operator precedence; wrap multi-line concat in parens
##   G-10 — autoload identifier binds at engine init; emit on real GameBus only
##   G-15 — before_test() is canonical hook (NOT before_each)
##   G-16 — typed Array[Dictionary] for signal log
##   G-24 — as operator precedence; wrap RHS cast in parens in == expressions

# ── Constants ─────────────────────────────────────────────────────────────────

## MVP hero IDs (heroes.json verified 2026-05-01).
const _HERO_LIU_BEI: StringName   = &"shu_001_liu_bei"
const _HERO_GUAN_YU: StringName   = &"shu_002_guan_yu"
const _HERO_ZHANG_FEI: StringName = &"shu_003_zhang_fei"

## UnitRole.UnitClass int backing values (unit_role.gd — locked per ADR-0009).
const _CLASS_CAVALRY: int   = 0
const _CLASS_INFANTRY: int  = 1
const _CLASS_COMMANDER: int = 4

## Standard unit_ids for a 2-unit test roster (player + enemy).
const _UID_P: int = 1   ## Player-controlled unit
const _UID_E: int = 2   ## Enemy unit

# ── Suite state ───────────────────────────────────────────────────────────────

var _runner: TurnOrderRunner

## Unified signal log — typed per G-16.
var _signal_log: Array[Dictionary] = []

## Controller invocation log — G-4 Array captures pattern.
## Each entry: {"unit_id": int, "snapshot": TurnOrderSnapshot}
var _controller_calls: Array = []

# ── Signal capture handlers (method-reference form — sidesteps G-4) ──────────

func _capture_unit_turn_started(unit_id: int) -> void:
	_signal_log.append({"signal": "unit_turn_started", "unit_id": unit_id})


func _capture_unit_turn_ended(unit_id: int, acted: bool) -> void:
	_signal_log.append({"signal": "unit_turn_ended", "unit_id": unit_id, "acted": acted})


# ── Test controller helpers ───────────────────────────────────────────────────

## Controller Callable that only records the invocation — does NOT call declare_action.
## Used to test the T5 "holds" (T6 must NOT fire until declare_action called later).
func _recording_controller(unit_id: int, snapshot: TurnOrderSnapshot) -> void:
	_controller_calls.append({"unit_id": unit_id, "snapshot": snapshot})


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func before_test() -> void:
	## G-15: canonical GdUnit4 v6.1.2 per-test hook (NOT before_each).
	## Creates a fresh TurnOrderRunner with a 2-unit roster (player + enemy).
	## Drains the deferred _begin_round() call frame; forces ROUND_ACTIVE for
	## synchronous test control; connects signal capture handlers.
	_signal_log.clear()
	_controller_calls.clear()

	_runner = auto_free(TurnOrderRunner.new())
	add_child(_runner)

	var roster: Array[BattleUnit] = []
	roster.append(_make_unit(_UID_P, _HERO_LIU_BEI, _CLASS_COMMANDER, true))
	roster.append(_make_unit(_UID_E, _HERO_GUAN_YU, _CLASS_INFANTRY, false))
	_runner.initialize_battle(roster)

	# Drain the deferred _begin_round() call before deterministic state setup.
	await get_tree().process_frame

	# Seed deterministic initiatives: P=120 (higher, acts first), E=100.
	_runner._seed_unit_state_for_test(_UID_P, 120, 65, true)
	_runner._seed_unit_state_for_test(_UID_E, 100, 70, false)

	# Force ROUND_ACTIVE to bypass deferred _begin_round chain in tests.
	_runner._round_state = TurnOrderRunner.RoundState.ROUND_ACTIVE
	_runner._queue_index = 0
	_runner._rebuild_queue()

	# Connect capture handlers before tests run.
	GameBus.unit_turn_started.connect(_capture_unit_turn_started)
	GameBus.unit_turn_ended.connect(_capture_unit_turn_ended)

	# Flush signals fired by initialize_battle + _begin_round.call_deferred drain
	_signal_log.clear()
	_controller_calls.clear()


func after_test() -> void:
	## G-15 cleanup: disconnect all test-owned handlers before auto_free.
	## Disconnects only the handlers THIS test suite added (never bulk-disconnect-all
	## per G-28 — bulk disconnect severs production autoload subscriptions).
	if is_instance_valid(_runner):
		if GameBus.unit_died.is_connected(_runner._on_unit_died):
			GameBus.unit_died.disconnect(_runner._on_unit_died)
	if GameBus.unit_turn_started.is_connected(_capture_unit_turn_started):
		GameBus.unit_turn_started.disconnect(_capture_unit_turn_started)
	if GameBus.unit_turn_ended.is_connected(_capture_unit_turn_ended):
		GameBus.unit_turn_ended.disconnect(_capture_unit_turn_ended)


# ── Helpers ───────────────────────────────────────────────────────────────────

func _make_unit(unit_id: int, hero_id: StringName, unit_class: int, is_player: bool) -> BattleUnit:
	var u: BattleUnit = BattleUnit.new()
	u.unit_id = unit_id
	u.hero_id = hero_id
	u.unit_class = unit_class
	u.is_player_controlled = is_player
	return u


func _count_signal(sig_name: String) -> int:
	var count: int = 0
	for entry: Dictionary in _signal_log:
		if (entry.get("signal", "") as String) == sig_name:
			count += 1
	return count


func _count_signal_for_unit(sig_name: String, unit_id: int) -> int:
	var count: int = 0
	for entry: Dictionary in _signal_log:
		if (entry.get("signal", "") as String) == sig_name \
				and (entry.get("unit_id", -1) as int) == unit_id:
			count += 1
	return count


# ── AC-1: T5 dispatches to controller when injected ──────────────────────────

## AC-1 (S15-A): When a controller is injected via set_action_controller(),
## _advance_turn dispatches to the controller at T5 with (unit_id, snapshot).
## Given: controller injected; _advance_turn(_UID_P) called.
## When: _execute_action_budget fires (NATURAL-LOOP mode detected via non-null Callable).
## Then: _controller_calls has 1 entry with unit_id == _UID_P and a TurnOrderSnapshot.
func test_t5_dispatches_to_controller_when_injected() -> void:
	# Arrange — inject recording controller (G-10: Callable captures method reference)
	_runner.set_action_controller(_recording_controller)

	# Act — run a single turn; T5 dispatches then returns (NATURAL-LOOP mode)
	_runner._advance_turn(_UID_P)

	# Assert — controller was invoked exactly once
	assert_int(_controller_calls.size()).override_failure_message(
		("AC-1: controller must be invoked exactly once at T5; got %d invocations — "
		+ "_execute_action_budget did not dispatch or dispatched multiple times")
		% _controller_calls.size()
	).is_equal(1)

	# Assert — controller was invoked with the correct unit_id
	var captured_unit_id: int = _controller_calls[0].get("unit_id", -1) as int
	assert_int(captured_unit_id).override_failure_message(
		("AC-1: controller must receive unit_id == %d (_UID_P); got %d — "
		+ "_execute_action_budget passed wrong unit_id")
		% [_UID_P, captured_unit_id]
	).is_equal(_UID_P)

	# Assert — controller received a non-null TurnOrderSnapshot
	var captured_snapshot: Variant = _controller_calls[0].get("snapshot", null)
	assert_bool(captured_snapshot != null).override_failure_message(
		("AC-1: controller must receive a non-null TurnOrderSnapshot at T5; got null — "
		+ "_execute_action_budget did not build/pass the snapshot")
	).is_true()

	assert_bool(captured_snapshot is TurnOrderSnapshot).override_failure_message(
		("AC-1: controller snapshot argument must be a TurnOrderSnapshot instance; "
		+ "got type: %s") % str(typeof(captured_snapshot))
	).is_true()


# ── AC-2: T5 hold — declare_action(WAIT) path ────────────────────────────────

## AC-2 (S15-A): Controller injected but does NOT call declare_action immediately.
## T6 unit_turn_ended must NOT fire synchronously after _advance_turn.
## After await get_tree().process_frame + declare_action(WAIT), T6 fires.
## Given: recording controller (holds the turn); _advance_turn(_UID_P).
## When: assert T6 not fired → call declare_action(WAIT) → await frame.
## Then: T6 unit_turn_ended fires for _UID_P.
func test_t5_holds_until_declare_action_wait_path() -> void:
	# Arrange — inject recording controller (holds; does NOT call declare_action)
	_runner.set_action_controller(_recording_controller)

	# Act step 1 — _advance_turn dispatches to controller + returns
	_runner._advance_turn(_UID_P)

	# Assert — T6 has NOT fired synchronously after _advance_turn returns
	var ended_sync: int = _count_signal_for_unit("unit_turn_ended", _UID_P)
	assert_int(ended_sync).override_failure_message(
		("AC-2: unit_turn_ended must NOT fire synchronously while controller holds the turn; "
		+ "got %d emissions after _advance_turn — T5 gate (NATURAL-LOOP return) not working")
		% ended_sync
	).is_equal(0)

	# Act step 2 — controller now calls declare_action(WAIT) to complete the turn
	var result: ActionResult = _runner.declare_action(
		_UID_P, TurnOrderRunner.ActionType.WAIT, null)

	assert_bool(result.success).override_failure_message(
		"AC-2: declare_action(WAIT) must succeed for _UID_P in ACTING state"
	).is_true()

	# Act step 3 — drain the deferred _complete_turn_t6_to_t7 call
	await get_tree().process_frame

	# Assert — T6 unit_turn_ended fired for _UID_P after declare_action(WAIT) + frame drain
	var ended_deferred: int = _count_signal_for_unit("unit_turn_ended", _UID_P)
	assert_int(ended_deferred).override_failure_message(
		("AC-2: unit_turn_ended must fire exactly once for _UID_P after declare_action(WAIT) "
		+ "+ process_frame drain; got %d emissions — _maybe_defer_turn_completion did not "
		+ "trigger _complete_turn_t6_to_t7.call_deferred")
		% ended_deferred
	).is_equal(1)

	# G-6: explicit cleanup before test body exits (deferred _advance_turn for _UID_E may fire)
	await get_tree().process_frame


# ── AC-3: T5 hold — declare_action(ATTACK) path ──────────────────────────────

## AC-3 (S15-A): Same hold verification as AC-2 but with ATTACK action type.
## Given: recording controller; _advance_turn(_UID_P).
## When: assert T6 not fired → declare_action(ATTACK) → await frame.
## Then: T6 fires; acted==true (ACTION token spent).
func test_t5_holds_until_declare_action_attack_path() -> void:
	# Arrange — inject recording controller
	_runner.set_action_controller(_recording_controller)

	# Act step 1 — _advance_turn dispatches + returns
	_runner._advance_turn(_UID_P)

	# Assert — T6 has NOT fired synchronously
	var ended_sync: int = _count_signal_for_unit("unit_turn_ended", _UID_P)
	assert_int(ended_sync).override_failure_message(
		("AC-3: unit_turn_ended must NOT fire synchronously while controller holds (ATTACK path); "
		+ "got %d emissions after _advance_turn")
		% ended_sync
	).is_equal(0)

	# Act step 2 — controller calls declare_action(ATTACK)
	var result: ActionResult = _runner.declare_action(
		_UID_P, TurnOrderRunner.ActionType.ATTACK, null)

	assert_bool(result.success).override_failure_message(
		"AC-3: declare_action(ATTACK) must succeed for _UID_P in ACTING state"
	).is_true()

	# Act step 3 — drain the deferred T6+T7 call
	await get_tree().process_frame

	# Assert — T6 fired exactly once for _UID_P
	var ended_deferred: int = _count_signal_for_unit("unit_turn_ended", _UID_P)
	assert_int(ended_deferred).override_failure_message(
		("AC-3: unit_turn_ended must fire exactly once for _UID_P after declare_action(ATTACK) "
		+ "+ process_frame drain; got %d emissions")
		% ended_deferred
	).is_equal(1)

	# Assert — acted == true (ACTION token was spent)
	var acted_value: bool = false
	for entry: Dictionary in _signal_log:
		if (entry.get("signal", "") as String) == "unit_turn_ended" \
				and (entry.get("unit_id", -1) as int) == _UID_P:
			acted_value = entry.get("acted", false) as bool
			break

	assert_bool(acted_value).override_failure_message(
		("AC-3: unit_turn_ended(acted) must be true when ATTACK token was spent; "
		+ "got false — _mark_acted did not detect action_token_spent == true")
	).is_true()

	# G-6: drain any follow-on deferred calls
	await get_tree().process_frame


# ── AC-4: MOVE alone does NOT complete the turn ───────────────────────────────

## AC-4 (S15-A): declare_action(MOVE) spends move_token only; action_token_spent
## stays false; turn_state stays ACTING → _maybe_defer_turn_completion is a no-op.
## T6 unit_turn_ended must NOT fire after MOVE alone.
## Given: recording controller; _advance_turn(_UID_P).
## When: declare_action(MOVE) called.
## Then: T6 has NOT fired; state.move_token_spent == true; state.turn_state == ACTING.
func test_t5_holds_for_move_does_not_complete_turn() -> void:
	# Arrange — inject recording controller
	_runner.set_action_controller(_recording_controller)

	# Act step 1 — _advance_turn dispatches + returns
	_runner._advance_turn(_UID_P)

	# Act step 2 — declare MOVE (move_token only)
	var result: ActionResult = _runner.declare_action(
		_UID_P, TurnOrderRunner.ActionType.MOVE, null)

	assert_bool(result.success).override_failure_message(
		"AC-4: declare_action(MOVE) must succeed for _UID_P in ACTING state"
	).is_true()

	# Act step 3 — drain a frame to let any (incorrect) deferred call fire
	await get_tree().process_frame

	# Assert — T6 unit_turn_ended has NOT fired
	var ended_count: int = _count_signal_for_unit("unit_turn_ended", _UID_P)
	assert_int(ended_count).override_failure_message(
		("AC-4: unit_turn_ended must NOT fire after MOVE alone; got %d emissions — "
		+ "_maybe_defer_turn_completion incorrectly deferred completion on MOVE-only path")
		% ended_count
	).is_equal(0)

	# Assert — state reflects: move_token_spent, action_token_spent == false, ACTING
	assert_bool(_runner._unit_states[_UID_P].move_token_spent).override_failure_message(
		"AC-4: move_token_spent must be true after declare_action(MOVE)"
	).is_true()

	assert_bool(_runner._unit_states[_UID_P].action_token_spent).override_failure_message(
		"AC-4: action_token_spent must still be false after MOVE alone (only MOVE token spent)"
	).is_false()

	assert_int(_runner._unit_states[_UID_P].turn_state as int).override_failure_message(
		("AC-4: turn_state must still be ACTING after MOVE alone; got %d — "
		+ "MOVE alone must not advance turn_state to DONE")
		% (_runner._unit_states[_UID_P].turn_state as int)
	).is_equal(TurnOrderRunner.TurnState.ACTING as int)

	# G-6: explicit cleanup — discard the unit turn now (prevent deferred calls leaking)
	# Declare WAIT to complete the turn cleanly so no orphaned deferred calls remain.
	_runner.declare_action(_UID_P, TurnOrderRunner.ActionType.WAIT, null)
	await get_tree().process_frame
	await get_tree().process_frame


# ── AC-5: MOVE then ATTACK completes the turn ─────────────────────────────────

## AC-5 (S15-A): Multi-action MOVE+ATTACK path. After MOVE, T6 has not fired.
## After ATTACK (ACTION token spent), T6 fires on next frame.
## Given: recording controller; _advance_turn(_UID_P).
## When: declare_action(MOVE) → assert T6 not fired → declare_action(ATTACK) → await frame.
## Then: T6 fires exactly once for _UID_P; acted == true.
func test_t5_move_then_attack_completes_turn() -> void:
	# Arrange — inject recording controller
	_runner.set_action_controller(_recording_controller)

	# Act step 1 — _advance_turn dispatches + returns
	_runner._advance_turn(_UID_P)

	# Act step 2 — declare MOVE
	var move_result: ActionResult = _runner.declare_action(
		_UID_P, TurnOrderRunner.ActionType.MOVE, null)

	assert_bool(move_result.success).override_failure_message(
		"AC-5 setup: declare_action(MOVE) must succeed"
	).is_true()

	# Assert — T6 has NOT fired after MOVE alone (intermediate check)
	var ended_after_move: int = _count_signal_for_unit("unit_turn_ended", _UID_P)
	assert_int(ended_after_move).override_failure_message(
		("AC-5: unit_turn_ended must NOT fire after MOVE alone (intermediate check); "
		+ "got %d emissions — MOVE should not complete the turn")
		% ended_after_move
	).is_equal(0)

	# Act step 3 — declare ATTACK (ACTION token — turn completes)
	var attack_result: ActionResult = _runner.declare_action(
		_UID_P, TurnOrderRunner.ActionType.ATTACK, null)

	assert_bool(attack_result.success).override_failure_message(
		"AC-5 setup: declare_action(ATTACK) must succeed after MOVE on same turn"
	).is_true()

	# Act step 4 — drain the deferred _complete_turn_t6_to_t7 call
	await get_tree().process_frame

	# Assert — T6 fired exactly once for _UID_P
	var ended_after_attack: int = _count_signal_for_unit("unit_turn_ended", _UID_P)
	assert_int(ended_after_attack).override_failure_message(
		("AC-5: unit_turn_ended must fire exactly once for _UID_P after MOVE+ATTACK "
		+ "+ process_frame drain; got %d emissions")
		% ended_after_attack
	).is_equal(1)

	# Assert — acted == true (both tokens spent; acted_this_turn = move OR action = true)
	var acted_value: bool = false
	for entry: Dictionary in _signal_log:
		if (entry.get("signal", "") as String) == "unit_turn_ended" \
				and (entry.get("unit_id", -1) as int) == _UID_P:
			acted_value = entry.get("acted", false) as bool
			break

	assert_bool(acted_value).override_failure_message(
		("AC-5: unit_turn_ended(acted) must be true after MOVE+ATTACK; "
		+ "got false — _mark_acted did not detect token spend")
	).is_true()

	# G-6: drain any follow-on deferred calls
	await get_tree().process_frame


# ── AC-7 (backward compat): TEST-SEAM mode runs T1→T7 synchronously ──────────

## AC-7 (S15-A backward compat): When NO controller is injected (_action_controller
## is Callable()), _advance_turn runs T1→T7 synchronously without any await.
## T6 unit_turn_ended fires SYNCHRONOUSLY after _advance_turn returns.
## This preserves the existing test contract for ALL story-001..S14 tests that call
## _advance_turn directly without injecting a controller.
## Given: NO set_action_controller call (default Callable() state).
## When: _advance_turn(_UID_P) called.
## Then: unit_turn_ended fires synchronously — no await needed.
func test_seam_mode_no_controller_runs_synchronous_t1_to_t7() -> void:
	# Arrange — NO controller injection (default Callable() — TEST-SEAM mode)
	# _runner._action_controller is Callable() from before_test runner construction.

	# Confirm controller is null (TEST-SEAM mode guard)
	assert_bool(_runner._action_controller.is_null()).override_failure_message(
		"AC-7 setup: _action_controller must be Callable() (null) before set_action_controller is called"
	).is_true()

	# Act — _advance_turn runs synchronously T1→T7 in TEST-SEAM mode
	_runner._advance_turn(_UID_P)

	# Assert — T6 unit_turn_ended fired SYNCHRONOUSLY (no await needed)
	var ended_sync: int = _count_signal_for_unit("unit_turn_ended", _UID_P)
	assert_int(ended_sync).override_failure_message(
		("AC-7 backward-compat: unit_turn_ended must fire synchronously in TEST-SEAM mode "
		+ "(no controller injected); got %d emissions — "
		+ "_advance_turn did not complete T6 inline when Callable() is null")
		% ended_sync
	).is_equal(1)

	# Assert — T4 unit_turn_started also fired synchronously
	var started_sync: int = _count_signal_for_unit("unit_turn_started", _UID_P)
	assert_int(started_sync).override_failure_message(
		("AC-7 backward-compat: unit_turn_started must fire synchronously in TEST-SEAM mode; "
		+ "got %d emissions — _activate_unit_turn not reached")
		% started_sync
	).is_equal(1)

	# Assert — turn_state is DONE (T6 _mark_acted completed)
	assert_int(_runner._unit_states[_UID_P].turn_state as int).override_failure_message(
		("AC-7 backward-compat: turn_state must be DONE after synchronous _advance_turn; "
		+ "got %d — T6 _mark_acted did not run")
		% (_runner._unit_states[_UID_P].turn_state as int)
	).is_equal(TurnOrderRunner.TurnState.DONE as int)

	# G-6: drain any deferred _advance_to_next_queued_unit calls
	await get_tree().process_frame


# ── AC-4 (natural-loop): end-to-end deferred chain — no test-seam calls ─────

## AC-4 natural-loop (S15-A + G-30 partial mitigation):
## Drives the full natural-loop deferred chain end-to-end:
##   set_action_controller(...) → initialize_battle(roster)
##   → wait for _begin_round.call_deferred()
##   → wait for _advance_turn.call_deferred(_queue[0])
##   → assert controller invoked with first-queued unit (T5 holding)
##   → call declare_action(WAIT)
##   → wait for _complete_turn_t6_to_t7.call_deferred()
##   → assert unit_turn_ended emitted for first_unit
##
## CRITICAL: NO direct _advance_turn test-seam calls. NO manual _round_state forcing.
## The test relies entirely on the deferred chain, which is what AC-4 of story-008
## explicitly requires. This is the foundational G-30 mitigation — prior tests use
## the test-seam (direct _advance_turn calls) which bypasses the production deferred
## chain. This test exercises the production chain directly.
func test_natural_loop_begin_round_to_t5_hold() -> void:
	# ARRANGE: before_test set up a runner with ROUND_ACTIVE + test-seam state.
	# Reset to pre-battle state so initialize_battle drives the natural-loop.
	_runner._round_state = TurnOrderRunner.RoundState.BATTLE_NOT_STARTED
	_runner._queue.clear()
	_runner._unit_states.clear()
	_signal_log.clear()
	_controller_calls.clear()

	# Inject controller BEFORE initialize_battle so NATURAL-LOOP mode is active
	# from the moment _begin_round runs (T5 will dispatch, not run synchronously).
	_runner.set_action_controller(_recording_controller)

	var roster: Array[BattleUnit] = [
		_make_unit(_UID_P, _HERO_LIU_BEI, _CLASS_COMMANDER, true),
		_make_unit(_UID_E, _HERO_GUAN_YU, _CLASS_INFANTRY, false),
	]

	# ACT phase 1: initialize_battle triggers _begin_round.call_deferred().
	_runner.initialize_battle(roster)
	await get_tree().process_frame  # let _begin_round fire (queue rebuild + first _advance_turn dispatch)
	await get_tree().process_frame  # let _advance_turn.call_deferred fire (T1-T5 + controller dispatch)

	# ASSERT phase 1: controller was invoked once; T5 is holding before declare_action.
	assert_int(_controller_calls.size()).override_failure_message(
		("AC-4 natural-loop: controller must be invoked exactly once after initialize_battle "
		+ "deferred chain; got %d calls — _begin_round or _advance_turn deferred chain did not "
		+ "dispatch to controller")
		% _controller_calls.size()
	).is_equal(1)

	var first_unit: int = (_controller_calls[0]["unit_id"] as int)
	# Verify first_unit matches what _queue[0] holds — ADR-0011 F-1 cascade ordering.
	assert_int(first_unit).override_failure_message(
		("AC-4 natural-loop: controller unit_id %d must match _queue[0] %d — "
		+ "queue rebuild or advance_turn dispatched wrong unit")
		% [first_unit, _runner._queue[0]]
	).is_equal(_runner._queue[0])

	# T6 must NOT have fired yet — controller is still holding at T5.
	assert_int(_count_signal_for_unit("unit_turn_ended", first_unit)).override_failure_message(
		("AC-4 natural-loop: unit_turn_ended must NOT fire before declare_action — "
		+ "T5 gate is not holding; got %d premature emissions for unit %d")
		% [_count_signal_for_unit("unit_turn_ended", first_unit), first_unit]
	).is_equal(0)

	# ACT phase 2: complete the turn via WAIT (natural controller action).
	var result: ActionResult = _runner.declare_action(
		first_unit, TurnOrderRunner.ActionType.WAIT, null)

	assert_bool(result.success).override_failure_message(
		("AC-4 natural-loop: declare_action(WAIT) must succeed for unit %d in ACTING state")
		% first_unit
	).is_true()

	await get_tree().process_frame  # let _complete_turn_t6_to_t7.call_deferred fire (T6 + T7)
	await get_tree().process_frame  # let any chained _advance_to_next_queued_unit deferreds fire

	# ASSERT phase 2: T6 fired for first_unit after declare_action(WAIT) + frame drain.
	assert_int(_count_signal_for_unit("unit_turn_ended", first_unit)).override_failure_message(
		("AC-4 natural-loop: unit_turn_ended must fire for unit %d after declare_action(WAIT) "
		+ "+ 2 frame awaits; got %d emissions — _complete_turn_t6_to_t7.call_deferred did not run "
		+ "or _maybe_defer_turn_completion did not trigger it")
		% [first_unit, _count_signal_for_unit("unit_turn_ended", first_unit)]
	).is_greater_equal(1)

	# G-6: drain any remaining deferred calls before test body exits.
	await get_tree().process_frame
	await get_tree().process_frame
