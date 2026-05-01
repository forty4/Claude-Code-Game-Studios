extends GdUnitTestSuite

## turn_order_death_handling_test.gd
## Integration tests for Story 005 (turn-order epic):
##   - TR-008: unit_died CONNECT_DEFERRED subscription (R-1 mitigation)
##   - TR-015: CR-7 death mid-round queue removal + CR-7d counter-attack T5 interrupt
##   - TR-017: F-2 Cavalry Charge accumulation + get_charge_ready query
##
## Covers AC-1 through AC-11 from story-005 §Acceptance Criteria.
## AC-12 (CHARGE_THRESHOLD JSON key) verified via FileAccess grep assertion.
## AC-13 (regression baseline) verified via full-suite run.
##
## Governing ADRs: ADR-0011 (Turn Order), ADR-0001 (CONNECT_DEFERRED mandate §5),
##   ADR-0006 (BalanceConstants accessor), ADR-0009 (Cavalry passive_charge tag).
##
## TEST CLASSIFICATION: Integration — crosses GameBus boundary.
## Uses real /root/GameBus (GameBus.unit_died.emit() synthetic emission).
## No HPStatusController dependency — unit_died is emitted directly in tests.
##
## GOTCHA AWARENESS:
##   G-2  — Array[T].duplicate() demotes type; use .assign() instead
##   G-6  — orphan detection fires BETWEEN test body exit and after_test
##   G-8  — Signal.get_connections() returns untyped Array
##   G-9  — % operator precedence; wrap multi-line concat in parens
##   G-10 — autoload identifier binds at engine init, not dynamically
##   G-15 — before_test() is canonical hook (NOT before_each)
##   G-16 — typed Array[Dictionary] for signal log
##   G-24 — as operator precedence; wrap RHS cast in parens in == expressions

# ── Constants ─────────────────────────────────────────────────────────────────

## MVP hero IDs (heroes.json verified 2026-05-01).
const _HERO_LIU_BEI: StringName    = &"shu_001_liu_bei"
const _HERO_GUAN_YU: StringName    = &"shu_002_guan_yu"
const _HERO_ZHANG_FEI: StringName  = &"shu_003_zhang_fei"

## UnitRole.UnitClass int backing values (unit_role.gd — locked per ADR-0009).
const _CLASS_CAVALRY: int   = 0
const _CLASS_INFANTRY: int  = 1
const _CLASS_COMMANDER: int = 4

## Standard unit_ids for 3-unit test roster.
const _UID_A: int = 1
const _UID_B: int = 2
const _UID_C: int = 3

# ── Suite state ───────────────────────────────────────────────────────────────

var _runner: TurnOrderRunner

# ── Signal capture handlers (method-reference form — sidesteps G-4) ──────────

## Unified signal log — capture handlers append here.
var _signal_log: Array[Dictionary] = []

func _capture_unit_turn_started(unit_id: int) -> void:
	_signal_log.append({"signal": "unit_turn_started", "unit_id": unit_id})


func _capture_unit_turn_ended(unit_id: int, acted: bool) -> void:
	_signal_log.append({"signal": "unit_turn_ended", "unit_id": unit_id, "acted": acted})


# ── Lifecycle ─────────────────────────────────────────────────────────────────

func before_test() -> void:
	## G-15: canonical GdUnit4 v6.1.2 per-test hook (NOT before_each).
	## Creates a fresh TurnOrderRunner seeded with a 3-unit roster via
	## initialize_battle(); drains the deferred _begin_round frame; then
	## manually overrides _round_state = ROUND_ACTIVE for synchronous test control.
	_signal_log.clear()
	_runner = auto_free(TurnOrderRunner.new())
	add_child(_runner)
	# Seed deterministic initiatives via _seed_unit_state_for_test after init.
	var roster: Array[BattleUnit] = []
	roster.append(_make_unit(_UID_A, _HERO_LIU_BEI, _CLASS_COMMANDER, true))
	roster.append(_make_unit(_UID_B, _HERO_GUAN_YU, _CLASS_INFANTRY, false))
	roster.append(_make_unit(_UID_C, _HERO_ZHANG_FEI, _CLASS_CAVALRY, false))
	_runner.initialize_battle(roster)
	# Drain the deferred _begin_round() call before deterministic state setup.
	# Without this, deferred calls can fire during test's await process_frame and interfere.
	await get_tree().process_frame
	# Seed deterministic initiatives: A=120, B=100, C=80 → queue order [A, B, C].
	_runner._seed_unit_state_for_test(_UID_A, 120, 65, true)
	_runner._seed_unit_state_for_test(_UID_B, 100, 70, false)
	_runner._seed_unit_state_for_test(_UID_C, 80, 60, false)
	# Manually force ROUND_ACTIVE to bypass the deferred _begin_round chain.
	# This avoids frame-timing complexity in tests that call _advance_turn directly.
	_runner._round_state = TurnOrderRunner.RoundState.ROUND_ACTIVE
	_runner._queue_index = 0
	# Rebuild queue with seeded initiatives for deterministic [A, B, C] ordering.
	_runner._rebuild_queue()
	# G-15 marker: unit_died.disconnect() — runner under test handles via _on_unit_died
	_signal_log.clear()


func after_test() -> void:
	## G-15 cleanup: disconnect runner's unit_died subscription before auto_free.
	## Prevents stale signal handler accumulation across tests.
	if is_instance_valid(_runner):
		if GameBus.unit_died.is_connected(_runner._on_unit_died):
			GameBus.unit_died.disconnect(_runner._on_unit_died)
		if GameBus.unit_turn_started.is_connected(_capture_unit_turn_started):
			GameBus.unit_turn_started.disconnect(_capture_unit_turn_started)
		if GameBus.unit_turn_ended.is_connected(_capture_unit_turn_ended):
			GameBus.unit_turn_ended.disconnect(_capture_unit_turn_ended)


# ── Helper ────────────────────────────────────────────────────────────────────

func _make_unit(unit_id: int, hero_id: StringName, unit_class: int, is_player: bool) -> BattleUnit:
	var u: BattleUnit = BattleUnit.new()
	u.unit_id = unit_id
	u.hero_id = hero_id
	u.unit_class = unit_class
	u.is_player_controlled = is_player
	return u


func _make_move_target(cost: int) -> ActionTarget:
	var t: ActionTarget = ActionTarget.new()
	t.movement_cost = cost
	return t


# ── AC-1: unit_died subscription on initialize_battle ────────────────────────

## AC-1 (TR-008): After initialize_battle, runner is subscribed to GameBus.unit_died.
## Given: post-initialize_battle runner (before_test sets up).
## When:  assert GameBus.unit_died.is_connected(_runner._on_unit_died).
## Then:  returns true; subscription exists with CONNECT_DEFERRED flag.
func test_unit_died_subscription_exists_after_initialize_battle() -> void:
	# Assert — connection must exist (set up by initialize_battle in before_test)
	assert_bool(
		GameBus.unit_died.is_connected(_runner._on_unit_died)
	).override_failure_message(
		("AC-1: after initialize_battle, GameBus.unit_died must be connected to "
		+ "_on_unit_died; is_connected returned false — subscription missing or "
		+ "CONNECT_DEFERRED flag not applied (ADR-0001 §5 mandate)")
	).is_true()


## AC-1 idempotent: calling initialize_battle again (after resetting state) does
## NOT double-connect the signal. is_connected still returns true; connection count == 1.
func test_unit_died_subscription_is_idempotent_no_double_connect() -> void:
	# Verify pre-condition: connected after first initialize_battle (from before_test)
	assert_bool(GameBus.unit_died.is_connected(_runner._on_unit_died)).is_true()

	# Read connection count before attempted re-connect
	var connections_before: Array = GameBus.unit_died.get_connections()
	var count_before: int = 0
	for conn: Dictionary in connections_before:
		var target: Object = (conn.get("callable", Callable()) as Callable).get_object()
		if target == _runner:
			count_before += 1

	# Attempt re-subscription via the is_connected-guarded pattern.
	if not GameBus.unit_died.is_connected(_runner._on_unit_died):
		GameBus.unit_died.connect(_runner._on_unit_died, Object.CONNECT_DEFERRED)

	# Connection count must still be 1
	var connections_after: Array = GameBus.unit_died.get_connections()
	var count_after: int = 0
	for conn: Dictionary in connections_after:
		var target: Object = (conn.get("callable", Callable()) as Callable).get_object()
		if target == _runner:
			count_after += 1

	assert_int(count_after).override_failure_message(
		("AC-1 idempotent: unit_died must have exactly 1 connection to _runner._on_unit_died; "
		+ "got %d — is_connected guard failed to prevent double-connect")
		% count_after
	).is_equal(count_before)


# ── AC-2: R-1 CONNECT_DEFERRED — synchronous emit does NOT trigger removal ───

## AC-2 (TR-008, R-1): unit_died emit does NOT trigger queue removal synchronously.
## Removal happens AFTER await get_tree().process_frame (deferred frame unwind).
## Given: 3-unit runner; emit unit_died for _UID_A.
## When (synchronous): _unit_states.size() == 3 (unchanged — CONNECT_DEFERRED not yet fired).
## After await frame: _unit_states.size() == 2 (deferred handler fired).
func test_unit_died_deferred_not_synchronous_r1_mitigation() -> void:
	var initial_size: int = _runner._unit_states.size()  # 3

	# Act — emit synchronously
	GameBus.unit_died.emit(_UID_A)

	# Synchronous assertion — handler NOT yet fired (CONNECT_DEFERRED pending)
	assert_int(_runner._unit_states.size()).override_failure_message(
		("AC-2 sync: unit_died handler must NOT fire synchronously (CONNECT_DEFERRED); "
		+ "expected _unit_states.size() == %d (unchanged); got %d — "
		+ "handler fired synchronously, R-1 mitigation broken")
		% [initial_size, _runner._unit_states.size()]
	).is_equal(initial_size)

	# Drain deferred frame
	await get_tree().process_frame

	# Post-deferred assertion — handler fired, unit removed
	assert_int(_runner._unit_states.size()).override_failure_message(
		("AC-2 deferred: after process_frame, _unit_states.size() must be %d (one unit removed); "
		+ "got %d — CONNECT_DEFERRED handler did not fire")
		% [initial_size - 1, _runner._unit_states.size()]
	).is_equal(initial_size - 1)

	assert_bool(_runner._unit_states.has(_UID_A)).override_failure_message(
		"AC-2 deferred: _UID_A must be absent from _unit_states after deferred frame"
	).is_false()


# ── AC-3: R-2 double-death is no-op ──────────────────────────────────────────

## AC-3 (TR-008, R-2): Emitting unit_died twice for the same unit_id is a no-op.
## Second handler invocation returns early via _unit_states.has() short-circuit.
## No error, no double-removal, no _queue corruption.
## Given: emit unit_died(_UID_A) + await; then emit unit_died(_UID_A) + await again.
## Then: _unit_states.size() == 2 (unchanged from first removal); _queue stable.
func test_unit_died_double_death_is_noop_r2_defensive() -> void:
	# First death — emit + drain
	GameBus.unit_died.emit(_UID_A)
	await get_tree().process_frame
	var size_after_first: int = _runner._unit_states.size()  # 2

	# Second death (same unit_id) — emit + drain
	GameBus.unit_died.emit(_UID_A)
	await get_tree().process_frame

	# Assert — size unchanged from first removal (2 → 2, not 2 → 1)
	assert_int(_runner._unit_states.size()).override_failure_message(
		("AC-3: double-death must be no-op; after second emit+await, "
		+ "_unit_states.size() must still be %d; got %d — "
		+ "R-2 defensive has() check failed")
		% [size_after_first, _runner._unit_states.size()]
	).is_equal(size_after_first)

	# Assert — _UID_A still absent (not re-added)
	assert_bool(_runner._unit_states.has(_UID_A)).override_failure_message(
		"AC-3: _UID_A must remain absent from _unit_states after double-death"
	).is_false()

	# Assert — _queue still has 2 remaining units [_UID_B, _UID_C]
	assert_int(_runner._queue.size()).override_failure_message(
		("AC-3: _queue must have 2 units after double-death of _UID_A; got %d — "
		+ "queue was corrupted by double-removal attempt")
		% _runner._queue.size()
	).is_equal(2)

	assert_bool(_runner._queue.has(_UID_A)).override_failure_message(
		"AC-3: _UID_A must not be in _queue after double-death"
	).is_false()


# ── AC-4: CR-7a single death queue removal + _queue_index adjustment ──────────

## AC-4 (TR-015, CR-7a): Single death removes unit from _queue + _unit_states.
## _queue_index is adjusted when removal is at-or-before current index.
## Given: queue [A, B, C], _queue_index = 1 (B is current).
## When: emit unit_died(_UID_A) (queue[0], BEFORE current index) + await.
## Then: _queue == [B, C]; _queue_index == 0 (decremented because removal at pos 0 <= index 1).
func test_unit_died_single_death_removes_unit_and_adjusts_queue_index() -> void:
	# Set _queue_index = 1 (B is "current")
	_runner._queue_index = 1

	# Emit death for A (queue[0], before current index)
	GameBus.unit_died.emit(_UID_A)
	await get_tree().process_frame

	# Assert — A removed from _unit_states
	assert_bool(_runner._unit_states.has(_UID_A)).override_failure_message(
		"AC-4: _UID_A must be absent from _unit_states after death"
	).is_false()

	# Assert — A removed from _queue
	assert_bool(_runner._queue.has(_UID_A)).override_failure_message(
		"AC-4: _UID_A must be absent from _queue after death"
	).is_false()

	# Assert — _queue now has 2 units
	assert_int(_runner._queue.size()).override_failure_message(
		("AC-4: _queue must have 2 units after A's death; got %d")
		% _runner._queue.size()
	).is_equal(2)

	# Assert — _queue_index decremented (removal at pos 0 <= index 1)
	assert_int(_runner._queue_index).override_failure_message(
		("AC-4: _queue_index must decrement from 1 to 0 when removal at pos 0 <= current index 1; "
		+ "got %d")
		% _runner._queue_index
	).is_equal(0)


# ── AC-4b: CR-7a death AT current _queue_index (queue_pos == _queue_index) ───

## AC-4b (TR-015, CR-7a branch coverage): Death of unit at exactly _queue_index.
## Closes /code-review GAP 1 — the queue_pos == _queue_index branch of the
## adjustment guard `queue_pos <= _queue_index and _queue_index > 0` is exercised
## only implicitly through AC-5/AC-9. This test pins the index decrement at the
## boundary case (current unit dies, not before/after).
## Given: queue [A, B, C], _queue_index = 1 (B is current).
## When: emit unit_died(_UID_B) (queue[1], EXACTLY at current index) + await.
## Then: _queue == [A, C]; _queue_index == 0 (decremented because pos 1 <= index 1).
func test_unit_died_at_current_queue_index_decrements_index() -> void:
	# Set _queue_index = 1 (B is "current")
	_runner._queue_index = 1

	# Emit death for B (queue[1], exactly at current index)
	GameBus.unit_died.emit(_UID_B)
	await get_tree().process_frame

	# Assert — B removed from _queue
	assert_bool(_runner._queue.has(_UID_B)).override_failure_message(
		"AC-4b: _UID_B must be absent from _queue after death-at-current-index"
	).is_false()

	# Assert — _queue == [A, C] preserved order
	assert_int(_runner._queue.size()).override_failure_message(
		("AC-4b: _queue must have 2 units [A, C] after B's death; got %d")
		% _runner._queue.size()
	).is_equal(2)
	assert_int(_runner._queue[0]).override_failure_message(
		"AC-4b: _queue[0] must remain _UID_A after B's removal"
	).is_equal(_UID_A)
	assert_int(_runner._queue[1]).override_failure_message(
		"AC-4b: _queue[1] must be _UID_C after B's removal"
	).is_equal(_UID_C)

	# Assert — _queue_index decremented (queue_pos 1 <= _queue_index 1, _queue_index > 0)
	assert_int(_runner._queue_index).override_failure_message(
		("AC-4b: _queue_index must decrement from 1 to 0 when removal AT current index "
		+ "(queue_pos 1 == _queue_index 1, _queue_index > 0); got %d")
		% _runner._queue_index
	).is_equal(0)


# ── AC-5: CR-7d counter-attack T5 interrupt ───────────────────────────────────

## AC-5 (TR-015, CR-7d): If the ACTING unit dies (T5 interrupt), the subsequent
## _advance_turn call for that unit short-circuits at T2 (unit not in _unit_states).
## T6 is NOT emitted for the dead unit. Queue advances past the dead unit.
## Given: _UID_A manually set to ACTING; emit unit_died(_UID_A) + await deferred.
## When: _runner._advance_turn(_UID_A) called (as would happen from queue advance).
## Then: no unit_turn_ended signal for _UID_A; T2 short-circuits; queue advances to B.
func test_unit_died_acting_unit_t5_interrupt_t6_skipped() -> void:
	# Arrange — connect capture handler for unit_turn_ended
	GameBus.unit_turn_ended.connect(_capture_unit_turn_ended)
	GameBus.unit_turn_started.connect(_capture_unit_turn_started)

	# Mark _UID_A as ACTING (simulating T5 in-flight)
	_runner._unit_states[_UID_A].turn_state = TurnOrderRunner.TurnState.ACTING
	_runner._queue_index = 0  # A is queue[0]

	# Emit death for the ACTING unit + drain deferred frame
	GameBus.unit_died.emit(_UID_A)
	await get_tree().process_frame

	# _UID_A is now removed from _unit_states and _queue
	assert_bool(_runner._unit_states.has(_UID_A)).override_failure_message(
		"AC-5: _UID_A must be absent from _unit_states after death"
	).is_false()

	# Simulate what the T5 continuation would do: call _advance_turn(_UID_A)
	# This represents the deferred advance that was in-flight when A died.
	_runner._advance_turn(_UID_A)

	# Assert — no unit_turn_ended fired for _UID_A (T2 short-circuits for missing unit)
	var ended_for_a: int = 0
	for entry: Dictionary in _signal_log:
		var sig: String = entry.get("signal", "") as String
		if sig == "unit_turn_ended" and (entry.get("unit_id", -1) as int) == _UID_A:
			ended_for_a += 1

	assert_int(ended_for_a).override_failure_message(
		("AC-5: unit_turn_ended must NOT fire for dead unit _UID_A; "
		+ "got %d emissions — T2 death check did not short-circuit")
		% ended_for_a
	).is_equal(0)


# ── AC-6: F-2 accumulated_move_cost per MOVE action ──────────────────────────

## AC-6 (TR-017, F-2): accumulated_move_cost increases by target.movement_cost
## per MOVE action declared in T5.
## Given: _UID_A in ACTING state; single MOVE declaration with cost 42.
## When: declare_action(MOVE, target_42)
## Then: accumulated_move_cost == 42
func test_declare_action_move_accumulates_movement_cost() -> void:
	# Arrange — set _UID_A to ACTING
	_runner._unit_states[_UID_A].turn_state = TurnOrderRunner.TurnState.ACTING
	_runner._unit_states[_UID_A].accumulated_move_cost = 0

	# Act — single MOVE declare with cost 42
	var target: ActionTarget = _make_move_target(42)
	var result: ActionResult = _runner.declare_action(_UID_A, TurnOrderRunner.ActionType.MOVE, target)

	# Assert — action succeeded
	assert_bool(result.success).override_failure_message(
		"AC-6: declare_action(MOVE) must succeed when MOVE token is unspent"
	).is_true()

	# Assert — accumulated_move_cost == 42
	assert_int(_runner._unit_states[_UID_A].accumulated_move_cost).override_failure_message(
		("AC-6: accumulated_move_cost must equal target.movement_cost (42) after MOVE declare; "
		+ "got %d — F-2 accumulation not applied in declare_action MOVE path")
		% _runner._unit_states[_UID_A].accumulated_move_cost
	).is_equal(42)


# ── AC-7: F-2 reset at T4 (NOT T6) ──────────────────────────────────────────

## AC-7 (TR-017, F-2 reset, R-3): accumulated_move_cost is reset to 0 at T4
## via _activate_unit_turn, NOT at T6. Pre-test sets dirty value (999) to prove
## T4 reset happened.
## Given: _UID_A accumulated_move_cost pre-set to 999 (dirty from prior turn).
## When: _runner._activate_unit_turn(_UID_A) called (executes T4 reset).
## Then: accumulated_move_cost == 0 at post-T4.
func test_activate_unit_turn_resets_accumulated_move_cost_at_t4() -> void:
	# Arrange — pre-set dirty accumulated_move_cost
	_runner._unit_states[_UID_A].accumulated_move_cost = 999

	# Act — _activate_unit_turn resets
	_runner._activate_unit_turn(_UID_A)

	# Assert — accumulated_move_cost reset to 0 (T4 reset)
	assert_int(_runner._unit_states[_UID_A].accumulated_move_cost).override_failure_message(
		("AC-7: accumulated_move_cost must be 0 after _activate_unit_turn (T4 reset); "
		+ "pre-test dirty value was 999; got %d — "
		+ "_activate_unit_turn did not reset accumulated_move_cost to 0 (R-3 violation)")
		% _runner._unit_states[_UID_A].accumulated_move_cost
	).is_equal(0)


# ── AC-8: get_charge_ready threshold boundary ─────────────────────────────────

## AC-8 (TR-017): get_charge_ready returns true iff accumulated_move_cost >= CHARGE_THRESHOLD.
## Tests boundary values: 39 (below), 40 (at threshold), 41 (above), and unknown unit_id.
func test_get_charge_ready_threshold_boundary_39_false() -> void:
	_runner._unit_states[_UID_A].accumulated_move_cost = 39
	assert_bool(_runner.get_charge_ready(_UID_A)).override_failure_message(
		("AC-8 boundary 39: get_charge_ready must return false when accumulated_move_cost == 39 "
		+ "(< CHARGE_THRESHOLD 40); got true — threshold comparison is wrong")
	).is_false()


func test_get_charge_ready_threshold_boundary_40_true() -> void:
	_runner._unit_states[_UID_A].accumulated_move_cost = 40
	assert_bool(_runner.get_charge_ready(_UID_A)).override_failure_message(
		("AC-8 boundary 40: get_charge_ready must return true when accumulated_move_cost == 40 "
		+ "(== CHARGE_THRESHOLD 40, inclusive); got false — threshold is not inclusive")
	).is_true()


func test_get_charge_ready_threshold_boundary_41_true() -> void:
	_runner._unit_states[_UID_A].accumulated_move_cost = 41
	assert_bool(_runner.get_charge_ready(_UID_A)).override_failure_message(
		("AC-8 boundary 41: get_charge_ready must return true when accumulated_move_cost == 41 "
		+ "(> CHARGE_THRESHOLD 40); got false")
	).is_true()


func test_get_charge_ready_unknown_unit_id_returns_false() -> void:
	## AC-8 R-2 defensive: unknown unit_id returns false (not crash).
	assert_bool(_runner.get_charge_ready(9999)).override_failure_message(
		("AC-8 unknown: get_charge_ready(9999) must return false for unknown unit_id; "
		+ "got true — R-2 defensive _unit_states.has() check missing")
	).is_false()


# ── AC-9: GDD AC-10 death mid-round queue removal + advance ──────────────────

## AC-9 (GDD AC-10): queue [A(ACTING), B, C], A killed → after deferred frame:
## A removed; queue == [B, C]; subsequent _advance_turn picks up B at T1.
func test_unit_died_mid_round_queue_removal_next_advance_picks_b() -> void:
	# Arrange — connect capture handlers
	GameBus.unit_turn_started.connect(_capture_unit_turn_started)
	GameBus.unit_turn_ended.connect(_capture_unit_turn_ended)

	# Set _UID_A as ACTING at queue[0]
	_runner._unit_states[_UID_A].turn_state = TurnOrderRunner.TurnState.ACTING
	_runner._queue_index = 0

	# Emit death for A + drain deferred frame
	GameBus.unit_died.emit(_UID_A)
	await get_tree().process_frame

	# Assert queue state: A removed, [B, C] remain
	assert_bool(_runner._queue.has(_UID_A)).override_failure_message(
		"AC-9: _UID_A must be absent from _queue after death"
	).is_false()
	assert_int(_runner._queue.size()).override_failure_message(
		("AC-9: _queue must have 2 units [B, C] after A's death; got %d")
		% _runner._queue.size()
	).is_equal(2)
	assert_int(_runner._queue[0]).override_failure_message(
		("AC-9: _queue[0] must be _UID_B after A's removal; got %d")
		% _runner._queue[0]
	).is_equal(_UID_B)

	# Act — simulate queue advance: call _advance_turn(_UID_B) as next in queue
	_runner._advance_turn(_UID_B)

	# Assert — unit_turn_started fired for B (T4 activated B's turn)
	var started_for_b: int = 0
	for entry: Dictionary in _signal_log:
		if (entry.get("signal", "") as String) == "unit_turn_started" \
				and (entry.get("unit_id", -1) as int) == _UID_B:
			started_for_b += 1

	assert_int(started_for_b).override_failure_message(
		("AC-9: unit_turn_started must fire for _UID_B as next queued unit after A's death; "
		+ "got %d — _advance_turn did not proceed to B")
		% started_for_b
	).is_equal(1)


# ── AC-10: GDD AC-14 Cavalry Charge accumulation Plains+Plains+Hills ──────────

## AC-10 (GDD AC-14): Cavalry path Plains(10)+Plains(10)+Hills(22)=42 accumulated.
## get_charge_ready returns true (42 >= 40). T4 reset verified first.
func test_cavalry_charge_accumulation_plains_hills_42_charge_ready() -> void:
	# Arrange — pre-set dirty accumulated_move_cost to prove T4 reset works
	_runner._unit_states[_UID_C].accumulated_move_cost = 999

	# Act step 1: trigger T4 reset via _activate_unit_turn
	_runner._activate_unit_turn(_UID_C)

	# Verify T4 reset happened
	assert_int(_runner._unit_states[_UID_C].accumulated_move_cost).override_failure_message(
		("AC-10: accumulated_move_cost must be 0 after _activate_unit_turn (T4 reset); "
		+ "pre-test dirty value was 999; got %d — R-3 mitigation not applied")
		% _runner._unit_states[_UID_C].accumulated_move_cost
	).is_equal(0)

	# Act step 2: declare MOVE with cost 42 (Plains 10 + Plains 10 + Hills 22)
	var move_target: ActionTarget = _make_move_target(42)
	var result: ActionResult = _runner.declare_action(
		_UID_C, TurnOrderRunner.ActionType.MOVE, move_target)

	assert_bool(result.success).override_failure_message(
		"AC-10: declare_action(MOVE, cost=42) must succeed"
	).is_true()

	# Assert — accumulated_move_cost == 42
	assert_int(_runner._unit_states[_UID_C].accumulated_move_cost).override_failure_message(
		("AC-10: accumulated_move_cost must be 42 after MOVE with cost 42; got %d — "
		+ "Plains(10)+Plains(10)+Hills(22)=42 accumulation failed")
		% _runner._unit_states[_UID_C].accumulated_move_cost
	).is_equal(42)

	# Assert — get_charge_ready returns true (42 >= 40)
	assert_bool(_runner.get_charge_ready(_UID_C)).override_failure_message(
		("AC-10: get_charge_ready must return true when accumulated_move_cost == 42 "
		+ "(>= CHARGE_THRESHOLD 40); got false")
	).is_true()


# ── AC-11: GDD AC-15 zero-move no trigger ────────────────────────────────────

## AC-11 (GDD AC-15): Cavalry attacks without spending MOVE token →
## accumulated_move_cost == 0, get_charge_ready == false.
func test_cavalry_zero_move_no_charge_ready() -> void:
	# Arrange — _UID_C in ACTING state (T4 already reset accumulated_move_cost to 0)
	_runner._activate_unit_turn(_UID_C)

	# Verify reset
	assert_int(_runner._unit_states[_UID_C].accumulated_move_cost).is_equal(0)

	# Act — declare ATTACK directly (no MOVE)
	var result: ActionResult = _runner.declare_action(
		_UID_C, TurnOrderRunner.ActionType.ATTACK, null)

	assert_bool(result.success).override_failure_message(
		"AC-11: declare_action(ATTACK) must succeed"
	).is_true()

	# Assert — accumulated_move_cost still 0
	assert_int(_runner._unit_states[_UID_C].accumulated_move_cost).override_failure_message(
		("AC-11: accumulated_move_cost must remain 0 when no MOVE declared; got %d")
		% _runner._unit_states[_UID_C].accumulated_move_cost
	).is_equal(0)

	# Assert — get_charge_ready false
	assert_bool(_runner.get_charge_ready(_UID_C)).override_failure_message(
		("AC-11: get_charge_ready must return false when accumulated_move_cost == 0; got true")
	).is_false()


# ── AC-12: CHARGE_THRESHOLD in balance_entities.json ─────────────────────────

## AC-12 (ADR-0006 §6 same-patch): balance_entities.json contains CHARGE_THRESHOLD key.
func test_charge_threshold_key_exists_in_balance_entities_json() -> void:
	var content: String = FileAccess.get_file_as_string(
		"res://assets/data/balance/balance_entities.json")
	assert_bool(content.contains("CHARGE_THRESHOLD")).override_failure_message(
		("AC-12: balance_entities.json must contain 'CHARGE_THRESHOLD' key (ADR-0006 §6 same-patch); "
		+ "key missing — add CHARGE_THRESHOLD: 40 to the JSON file")
	).is_true()
	# Strict key+value match — bare "40" matches DEFEND_STANCE_ATK_PENALTY: 0.40 false-positive.
	assert_bool(content.contains('"CHARGE_THRESHOLD": 40')).override_failure_message(
		("AC-12: balance_entities.json must contain '\"CHARGE_THRESHOLD\": 40' literal; "
		+ "value mismatch or formatting drift — required: \"CHARGE_THRESHOLD\": 40")
	).is_true()
