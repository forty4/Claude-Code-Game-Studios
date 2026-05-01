class_name TurnOrderRunner
## TurnOrderRunner — battle-scoped temporal orchestration core for 천명역전.
##
## Ratified by ADR-0011. Consumes GameBus.unit_died per ADR-0001.
## Emits 4 GameBus signals (round_started, unit_turn_started, unit_turn_ended,
## victory_condition_detected) per ADR-0001 Turn Order Domain + §Migration Plan §0
## same-patch amendment.
##
## RULES:
##  - TurnOrderRunner is created at battle-init by Battle Preparation and freed
##    automatically with BattleScene via ADR-0002 SceneManager teardown.
##  - State must NOT persist across battles (battle-scoped Node, NOT autoload).
##  - Instance field count is locked at 5 (any 6th field requires ADR-0011 amendment).
##  - ALL tuning-constant reads MUST flow through BalanceConstants.get_const(key)
##    per ADR-0006 — never hardcoded.
##  - _queue MUST be mutated in-place (.clear() + .append_array()); NEVER reassigned
##    to avoid typed-array reference replacement hazards (forbidden_pattern:
##    turn_order_typed_array_reassignment; ADR-0011 §Decision Advisory B + G-2).
##  - Emits ONLY the 4 Turn Order Domain signals; MUST NOT emit any other GameBus
##    signal (forbidden_pattern: turn_order_signal_emission_outside_domain).
##
## See ADR-0011 §Decision for topology and §Key Interfaces for full API.
extends Node

# ── Enums ──────────────────────────────────────────────────────────────────────

## State of the current battle round lifecycle.
## Consumers reference as TurnOrderRunner.RoundState.ROUND_STARTING etc.
enum RoundState {
	BATTLE_NOT_STARTED,
	BATTLE_INITIALIZING,
	ROUND_STARTING,
	ROUND_ACTIVE,
	ROUND_ENDING,
	BATTLE_ENDED,
}

## Per-unit turn state within the current round.
## Consumers reference as TurnOrderRunner.TurnState.IDLE etc.
## Stored as UnitTurnState.turn_state typed field.
enum TurnState {
	IDLE,
	ACTING,
	DONE,
	DEAD,
}

## Action types per ADR-0011 §Key Interfaces line 151 + GDD §CR-4 (5 actions).
## Consumers reference as TurnOrderRunner.ActionType.MOVE etc.
## Ratified by TR-turn-order-013 (story-004 same-patch).
enum ActionType {
	MOVE,
	ATTACK,
	USE_SKILL,
	DEFEND,
	WAIT,
}

## Victory result codes for victory_condition_detected signal payload.
## int backing values 0/1/2 — passed as int via GameBus.victory_condition_detected(result: int)
## per ADR-0001 line 155 typed-signal contract.
## AC-18 precedence rule: PLAYER_WIN (0) is checked BEFORE PLAYER_LOSE (1) in
## _evaluate_victory() — ensures mutual-kill scenario emits PLAYER_WIN.
## Ratified by TR-turn-order-007/018/020 (story-006 same-patch).
enum VictoryResult {
	PLAYER_WIN = 0,
	PLAYER_LOSE = 1,
	DRAW = 2,
}

## Failure error codes for declare_action() validation rejection paths.
## NONE=0 sentinel for success; non-zero values are mutually exclusive failure modes.
## Ratified by TR-turn-order-013 (story-004 same-patch).
enum ActionError {
	NONE,
	INVALID_ACTION_TYPE,
	TOKEN_ALREADY_SPENT,
	MOVE_LOCKED_BY_DEFEND_STANCE,
	UNIT_NOT_FOUND,
	NOT_UNIT_TURN,
}

# ── Private variables ──────────────────────────────────────────────────────────

## Ordered list of ALIVE unit_ids for the current round. Rebuilt at R3 each round.
## unit_id type LOCKED to int per ADR-0001 line 153 + ADR-0010 + ADR-0011 contract.
## MUST be mutated in-place (.clear() + .append_array()); never reassigned
## (forbidden_pattern: turn_order_typed_array_reassignment — Advisory B).
var _queue: Array[int] = []

## Pointer to the currently ACTING unit in _queue. Advances at T7.
var _queue_index: int = 0

## Current round counter. Initialized to 0 at BI-4; incremented at R1.
var _round_number: int = 0

## Per-unit token state + accumulated_move_cost + acted_this_turn + turn_state.
## Keyed by unit_id (int) per ADR-0001 + ADR-0010 + ADR-0011 lock.
## Typed Dictionary (Godot 4.4+, validated by ADR-0010 precedent; Advisory A applies).
var _unit_states: Dictionary[int, UnitTurnState] = {}

## Current battle round lifecycle state.
var _round_state: RoundState = RoundState.BATTLE_NOT_STARTED

# ── Public methods — mutators ──────────────────────────────────────────────────

## Called once by Battle Preparation at battle-init. Executes BI-1 through BI-5
## (collect units, compute initiative via UnitRole.get_initiative, initialize
## per-unit flags, initialize counters, apply battle-start effects). BI-6 transitions
## _round_state to ROUND_STARTING and triggers _begin_round() asynchronously via
## Callable method-reference deferred form:
##     _begin_round.call_deferred()
## (per godot-specialist 2026-04-30 Item 6; NOT string-based call_deferred)
## Subscribes to GameBus.unit_died on first call only (idempotent connect; G-15
## test isolation reset must disconnect).
##
## Double-init guard: returns immediately with push_error if _round_state is not
## BATTLE_NOT_STARTED — initialize_battle() is a one-shot operation per battle.
##
## Empty roster guard: returns immediately with push_error if unit_roster is empty.
##
## Usage:
##     var runner := TurnOrderRunner.new()
##     add_child(runner)
##     runner.initialize_battle(unit_roster)
func initialize_battle(unit_roster: Array[BattleUnit]) -> void:
	# Double-init guard: must be the very first check so a second call on an
	# already-initialized runner reports "already initialized", not "empty roster".
	if _round_state != RoundState.BATTLE_NOT_STARTED:
		push_error(
			"TurnOrderRunner.initialize_battle: called more than once — "
			+ "initialize_battle is a one-shot operation per battle instance. "
			+ "Current _round_state: %d" % (_round_state as int)
		)
		return

	# Empty roster guard: must come after double-init so a second call with an
	# empty roster correctly reports "already initialized", not "empty roster".
	if unit_roster.is_empty():
		push_error(
			"TurnOrderRunner.initialize_battle: unit_roster is empty — "
			+ "battle cannot be initialized without at least one unit."
		)
		return

	# BI-4: initialize counters (explicit assignment per ADR-0011 §CR-9 BI-4 spec).
	_round_number = 0
	_queue_index = 0

	# BI-1 → BI-3: iterate roster; create and seed one UnitTurnState per unit.
	for unit: BattleUnit in unit_roster:
		# BI-1: hero_id → unit_id mapping via HeroDatabase lookup.
		# Cache the HeroData reference once per unit to avoid a double-call
		# across BI-2 (get_initiative) and BI-3 (stat_agility read).
		var hero: HeroData = HeroDatabase.get_hero(unit.hero_id)

		var state: UnitTurnState = UnitTurnState.new()

		# BI-1: establish unit_id — primary key for _unit_states.
		state.unit_id = unit.unit_id

		# BI-2: compute and cache initiative once per unit (CR-6 static-initiative rule).
		# MUST NOT be recomputed at R3 — value is fixed for the entire battle.
		state.initiative = UnitRole.get_initiative(hero, unit.unit_class as UnitRole.UnitClass)

		# BI-3: cache hero metadata fields read by the F-1 cascade comparator.
		state.stat_agility = hero.stat_agility
		state.is_player_controlled = unit.is_player_controlled

		# BI-3 (continued): token flags and turn state default to RefCounted init
		# values; explicit assignments here document intent per AC-3/AC-7.
		state.move_token_spent = false
		state.action_token_spent = false
		state.accumulated_move_cost = 0
		state.acted_this_turn = false
		state.turn_state = TurnState.IDLE

		_unit_states[unit.unit_id] = state

	# BI-5: battle-start effects deferred — Grid Battle + Formation Bonus own
	# per-system effect application per orchestrator hand-off.

	# BI-6: transition to ROUND_STARTING, build initial queue, trigger round start.
	_round_state = RoundState.ROUND_STARTING
	_rebuild_queue()
	# BI-6 (story-005): subscribe to GameBus.unit_died with CONNECT_DEFERRED (R-1 mitigation).
	# is_connected guard makes this idempotent — safe for test isolation reset patterns.
	if not GameBus.unit_died.is_connected(_on_unit_died):
		GameBus.unit_died.connect(_on_unit_died, Object.CONNECT_DEFERRED)
	_begin_round.call_deferred()


## [TEST SEAM] Direct invocation of T1–T7 sequence for the specified unit_id.
## Production: called via internal queue advancement after previous unit's turn ends.
## Tests: called directly to bypass GameBus signal infrastructure + per-unit timing.
##
## Prefixed with _ but PUBLIC for test-namespace per ADR-0005 + ADR-0010 + ADR-0012
## DI seam pattern (4-precedent extension). GDScript 4.x does NOT enforce leading-
## underscore as private at the language level — convention only; GdUnit4 v6.1.2
## can call this directly without any reflection workaround.
##
## Usage:
##     runner._advance_turn(unit_id)
func _advance_turn(unit_id: int) -> void:
	# T1: descriptive entry point — no emit (canonical emit is at T4).

	# T2: defensive death + has check; short-circuits before any emit.
	if not _unit_states.has(unit_id) or _unit_states[unit_id].turn_state == TurnState.DEAD:
		_advance_to_next_queued_unit()
		return

	# T3: status decrement — no-op in Turn Order (HP/Status owns; signal-driven).

	# T4: activate unit turn (token reset + IDLE→ACTING + unit_turn_started emit).
	_activate_unit_turn(unit_id)

	# T5: action budget — story-004 implements declare_action; story-005 wires Callable.
	_execute_action_budget(unit_id)

	# T6: mark acted + unit_turn_ended emit.
	_mark_acted(unit_id)

	# T7: victory check — story-006 implements full _evaluate_victory().
	# AC-7/AC-22: T7 emit fires BEFORE RE2 round-cap check (synchronous order).
	var victory_result: Variant = _evaluate_victory()
	if victory_result != null:
		_emit_victory(victory_result as int)
		return   # AC-3: suppress _advance_to_next_queued_unit after decisive condition

	# Advance queue or end round.
	_advance_to_next_queued_unit()


## Called by the player input layer (via Grid Battle BattleController) OR AI System
## (via request_action delegation at T4). Validates token availability + DEFEND_STANCE
## locks + range/cooldown gates per ADR-0011 §CR-3 + §CR-4. On success: spends the
## appropriate token(s), updates _unit_states[unit_id].
##
## VALIDATION ORDER (validate-then-mutate — no half-validated state per Control Manifest):
##   1. UNIT_NOT_FOUND — unit_id not in _unit_states
##   2. NOT_UNIT_TURN   — unit's turn_state is not ACTING (only valid during T4-T5)
##   3. INVALID_ACTION_TYPE — action int is out of ActionType enum range
##   4. Per-ActionType token + DEFEND_STANCE validation + mutation
##
## Parameter `action` is typed int (not ActionType enum) to allow tests to pass
## invalid out-of-range ints (AC-1 INVALID_ACTION_TYPE path). Production callers
## SHOULD pass TurnOrderRunner.ActionType.MOVE etc.; the int typing is for
## test-rejection paths only.
##
## Parameter `target` is ActionTarget (nullable — tests pass null throughout
## story-004 since ActionTarget validation is deferred to story-007+ per IN-2).
##
## Returns ActionResult typed RefCounted wrapper:
##   success=true  → action accepted + token spent; error_code == NONE.
##   success=false → action rejected; error_code == reason; state UNCHANGED.
##
## Usage:
##     var result: ActionResult = runner.declare_action(
##         unit_id, TurnOrderRunner.ActionType.MOVE, target)
##     if result.success:
##         # token was spent
##     else:
##         # result.error_code as TurnOrderRunner.ActionError
func declare_action(unit_id: int, action: int, target: ActionTarget) -> ActionResult:
	# Validation 1: UNIT_NOT_FOUND — guard before any state read.
	if not _unit_states.has(unit_id):
		return ActionResult.make_failure(ActionError.UNIT_NOT_FOUND as int)

	var state: UnitTurnState = _unit_states[unit_id]

	# Validation 2: NOT_UNIT_TURN — declare_action only valid during T4-T5 (ACTING phase).
	# CR-3: action budget is active only while turn_state == ACTING.
	if state.turn_state != TurnState.ACTING:
		return ActionResult.make_failure(ActionError.NOT_UNIT_TURN as int)

	# Validation 3: INVALID_ACTION_TYPE — reject out-of-range int values.
	# ActionType.size() returns the count of enum members (5 for story-004).
	if action < 0 or action >= ActionType.size():
		return ActionResult.make_failure(ActionError.INVALID_ACTION_TYPE as int)

	# Validation 4 + Mutation: per-ActionType token check + state mutation.
	# match operates on the int backing value — all ActionType ints are in [0, 4].
	match action:
		ActionType.MOVE:
			# CR-3: MOVE token re-spend check FIRST (AC-7 takes precedence over DEFEND lock).
			if state.move_token_spent:
				return ActionResult.make_failure(ActionError.TOKEN_ALREADY_SPENT as int)
			# CR-4c: DEFEND_STANCE locks subsequent MOVE declarations this turn.
			if state.defend_stance_active:
				return ActionResult.make_failure(ActionError.MOVE_LOCKED_BY_DEFEND_STANCE as int)
			state.move_token_spent = true
			# F-2 accumulation (story-005, TR-017): capture movement cost for charge threshold.
			# target.movement_cost is the aggregate cost of the entire move path.
			if target != null:
				state.accumulated_move_cost += target.movement_cost
			return ActionResult.make_success()

		ActionType.ATTACK, ActionType.USE_SKILL:
			# CR-3: ACTION token re-spend check.
			if state.action_token_spent:
				return ActionResult.make_failure(ActionError.TOKEN_ALREADY_SPENT as int)
			state.action_token_spent = true
			return ActionResult.make_success()

		ActionType.DEFEND:
			# CR-3e: DEFEND spends ACTION token.
			# CR-4c: DEFEND_STANCE applied — subsequent MOVE declarations rejected.
			if state.action_token_spent:
				return ActionResult.make_failure(ActionError.TOKEN_ALREADY_SPENT as int)
			state.action_token_spent = true
			state.defend_stance_active = true
			return ActionResult.make_success()

		ActionType.WAIT:
			# CR-8: WAIT spends NO token; sets turn_state = DONE (no queue repositioning).
			# acted_this_turn stays false — T6 _mark_acted computes: false OR false = false.
			# Both tokens remain FRESH (move_token_spent=false, action_token_spent=false).
			state.turn_state = TurnState.DONE
			return ActionResult.make_success()

		_:
			# Unreachable: ActionType.size() guard above catches all out-of-range ints.
			# Defensive fallthrough in case the enum is extended without updating this match.
			return ActionResult.make_failure(ActionError.INVALID_ACTION_TYPE as int)

# ── Public methods — read-only queries ────────────────────────────────────────

## Returns true iff the unit spent at least one token during T5 this turn.
## Damage Calc consumes per attack for Scout Ambush gate (ADR-0012 line 343 —
## unit_id type LOCKED to int per ADR-0011; advisory queued for ADR-0012 amendment).
## Returns false for unknown unit_id (dead unit removed from _unit_states);
## R-2 defensive _unit_states.has() check applied in full implementation (story-003+).
##
## Usage:
##     var acted: bool = runner.get_acted_this_turn(unit_id)
func get_acted_this_turn(_unit_id: int) -> bool:
	return false


## Returns the current round counter. 0 before BI-4 / R1 (battle not started).
## Damage Calc consumes per attack for Scout Ambush round-2+ gate (ADR-0012).
##
## Usage:
##     var round: int = runner.get_current_round_number()
func get_current_round_number() -> int:
	return 0


## Returns a pull-based deep snapshot of current queue state.
## Battle HUD + AI consume for queue display + target prioritization.
## TurnOrderSnapshot is RefCounted with pure value semantics — consumers cannot
## mutate _queue or _unit_states via the snapshot
## (forbidden_pattern: turn_order_consumer_mutation).
## Returns null before initialize_battle() (story-002 implements the full body).
##
## Usage:
##     var snap: TurnOrderSnapshot = runner.get_turn_order_snapshot()
func get_turn_order_snapshot() -> TurnOrderSnapshot:
	return null


## Returns true iff _unit_states[unit_id].accumulated_move_cost >=
## BalanceConstants.get_const("CHARGE_THRESHOLD").
## Damage Calc consumes for Cavalry Charge passive (ADR-0009 passive_charge).
## CHARGE_THRESHOLD flows through BalanceConstants.get_const per ADR-0006.
## Returns false for unknown unit_id (R-2 defensive check; story-003+ implementation).
##
## Usage:
##     var ready: bool = runner.get_charge_ready(unit_id)
func get_charge_ready(unit_id: int) -> bool:
	if not _unit_states.has(unit_id):
		return false   # R-2 defensive — dead unit removed from _unit_states
	return _unit_states[unit_id].accumulated_move_cost >= (BalanceConstants.get_const("CHARGE_THRESHOLD") as int)


## Returns a defensive copy of the per-unit state via UnitTurnState.snapshot().
## AI System consumes for action selection context at T4.
## Returns snapshot() copy — consumer cannot mutate original
## (forbidden_pattern: turn_order_consumer_mutation).
## Returns null for unknown unit_id (story-003+ implementation).
##
## Usage:
##     var state: UnitTurnState = runner.get_unit_turn_state(unit_id)
func get_unit_turn_state(_unit_id: int) -> UnitTurnState:
	return null

# ── Public test seam ───────────────────────────────────────────────────────────

## [TEST SEAM] Mutates the 3 F-1 cascade metadata fields on an existing UnitTurnState
## entry without re-running the full BI-1..BI-3 loop.
##
## Enables AC-8..AC-12 synthetic-initiative tests without contrived 6-hero fixture
## data. Workflow: call initialize_battle(roster) with real heroes to populate
## _unit_states; then call this seam to OVERRIDE the cached initiative/agility/
## player values; then call _rebuild_queue() directly to apply the F-1 cascade
## with the overridden values; then assert _queue contents.
##
## TEST SEAM: production code MUST NOT call this — flagged via 'test' in name.
## 5-precedent extension of DI seam pattern:
##   ADR-0005 _handle_event + ADR-0010 _apply_turn_start_tick +
##   ADR-0012 _resolve_with_rng + ADR-0011 _advance_turn +
##   ADR-0011-story-002 _seed_unit_state_for_test.
##
## Prefixed with _ but PUBLIC for test-namespace per GDScript 4.x convention
## (leading-underscore is convention only; GdUnit4 v6.1.2 calls this directly).
##
## Usage (tests only):
##     runner._seed_unit_state_for_test(unit_id, 120, 85, true)
func _seed_unit_state_for_test(
		unit_id: int,
		initiative: int,
		stat_agility: int,
		is_player_controlled: bool) -> void:
	if not _unit_states.has(unit_id):
		push_error(
			("TurnOrderRunner._seed_unit_state_for_test: unit_id %d not found in "
			+ "_unit_states — call initialize_battle() first before seeding.") % unit_id
		)
		return
	_unit_states[unit_id].initiative = initiative
	_unit_states[unit_id].stat_agility = stat_agility
	_unit_states[unit_id].is_player_controlled = is_player_controlled

# ── Private methods ────────────────────────────────────────────────────────────

## Rebuilds _queue from _unit_states keys, sorted by the F-1 cascade comparator.
## Called at BI-6 (initial queue build) and future R3 (round-start queue rebuild
## in story-003).
##
## MUST use .clear() + .append_array() — NEVER reassign _queue directly
## (forbidden_pattern: turn_order_typed_array_reassignment; G-2 prevention).
##
## G-2 typed-array preservation: `ids.assign(_unit_states.keys())` instead of
## `var ids: Array[int] = _unit_states.keys()` — Dictionary.keys() returns
## untyped Array; .assign() preserves the Array[int] annotation.
func _rebuild_queue() -> void:
	_queue.clear()
	var ids: Array[int] = []
	ids.assign(_unit_states.keys())
	_queue.append_array(ids)
	_queue.sort_custom(_compare_units_for_queue)


## F-1 cascade comparator for Array.sort_custom().
## Returns true if unit a should precede unit b in the turn queue.
##
## F-1 cascade order (ADR-0011 §Decision + TR-turn-order-010):
##   Step 0: initiative DESC (higher initiative acts earlier)
##   Step 1: stat_agility DESC (tie-break: higher agility acts earlier)
##   Step 2: is_player_controlled DESC (tie-break: player > AI)
##   Step 3: unit_id ASC (final deterministic tie-break; guarantees total order)
##
## All 4 comparison fields are cached on UnitTurnState at BI-2/BI-3; this
## comparator NEVER re-queries HeroDatabase (CR-6 static-initiative rule).
func _compare_units_for_queue(a: int, b: int) -> bool:
	var sa: UnitTurnState = _unit_states[a]
	var sb: UnitTurnState = _unit_states[b]
	if sa.initiative != sb.initiative:
		return sa.initiative > sb.initiative  # DESC: higher initiative first
	if sa.stat_agility != sb.stat_agility:
		return sa.stat_agility > sb.stat_agility  # DESC: higher agility first
	if sa.is_player_controlled != sb.is_player_controlled:
		return sa.is_player_controlled  # DESC: true > false (player before AI)
	return a < b  # ASC: lower unit_id first (final deterministic guarantee)


## Story-003 implements R1..R4 round-start sequence + first unit deferred advance.
## Story-006 will extend with RE1..RE3 round-end + victory-condition checks.
##
## Called via `_begin_round.call_deferred()` at BI-6 — the Callable method-reference
## deferred form per godot-specialist 2026-04-30 Item 6. NOT string-based
## `call_deferred("_begin_round")` which is a deprecated-apis pattern.
func _begin_round() -> void:
	# R1: increment round counter.
	_round_number += 1

	# R2: alive units count — _unit_states is the source of truth post-_on_unit_died
	# (story-005 owns death removal; story-003 trusts current _unit_states).

	# R3: rebuild queue from current alive units via F-1 cascade (story-002).
	_rebuild_queue()

	# R4: transition state, reset queue pointer, emit round_started.
	_round_state = RoundState.ROUND_ACTIVE
	_queue_index = 0
	GameBus.round_started.emit(_round_number)

	# Drive T1 of first queued unit asynchronously (Callable method-reference form).
	if not _queue.is_empty():
		_advance_turn.call_deferred(_queue[0])


## Resets per-turn token state and transitions the unit into ACTING phase.
## Emits GameBus.unit_turn_started — canonical T4 emit point per ADR-0011 §Emitted signals.
## HP/Status consumes for DoT tick + status decrement + DEFEND_STANCE/DEMORALIZED expiry
## per ADR-0010 §Soft/Provisional clause (1) ratified by ADR-0011 acceptance.
##
## Story-004 same-patch UnitTurnState 10-field reset:
##   defend_stance_active is CLEARED to false at T4 (within-turn semantics only).
##   Cross-turn HP/Status SE-3 persistence is DEFERRED to story-005+ HP/Status integration.
func _activate_unit_turn(unit_id: int) -> void:
	var state: UnitTurnState = _unit_states[unit_id]
	state.move_token_spent = false
	state.action_token_spent = false
	state.accumulated_move_cost = 0
	state.acted_this_turn = false
	state.defend_stance_active = false
	state.turn_state = TurnState.ACTING
	GameBus.unit_turn_started.emit(unit_id)


## Executes the action budget for the active unit.
## Story-003 STUB — body intentionally empty.
## Story-004 implements declare_action() + token validation + DEFEND_STANCE locks.
## Story-005 wires the Callable controller injection per ADR-0011 §Decision Contract 5
## (`controller.call(unit_id, queue_snapshot)` synchronous form).
func _execute_action_budget(_unit_id: int) -> void:
	pass


## Marks the unit as acted (or not) and transitions to DONE phase.
## Emits GameBus.unit_turn_ended(unit_id, acted) — canonical T6 emit point.
## acted_this_turn is true iff at least one token was spent during T5
## (CR-3f per ADR-0011 §Decision UnitTurnState semantics).
func _mark_acted(unit_id: int) -> void:
	var state: UnitTurnState = _unit_states[unit_id]
	state.acted_this_turn = state.move_token_spent or state.action_token_spent
	state.turn_state = TurnState.DONE
	GameBus.unit_turn_ended.emit(unit_id, state.acted_this_turn)


## Evaluates victory condition — O(N) single pass over _unit_states.
## Returns int VictoryResult enum value if a decisive condition is met, null otherwise.
## AC-18 player-side precedence: PLAYER_WIN checked BEFORE PLAYER_LOSE — mutual-kill
## scenario (both faction counts hit 0 in the same T7) → PLAYER_WIN, NOT PLAYER_LOSE.
## Called at T7 (decisive unit conditions) and is referenced from _end_round (RE2 cap).
## Implements TR-turn-order-007 / TR-turn-order-020.
func _evaluate_victory() -> Variant:
	var player_alive: int = 0
	var enemy_alive: int = 0
	for state: UnitTurnState in _unit_states.values():
		if state.turn_state == TurnState.DEAD:
			continue
		# is_player_controlled cached in UnitTurnState at BI-3 (story-002).
		if state.is_player_controlled:
			player_alive += 1
		else:
			enemy_alive += 1
	# AC-18 player-side precedence: PLAYER_WIN check BEFORE PLAYER_LOSE.
	# Covers mutual-kill: enemy_alive == 0 AND player_alive == 0 → PLAYER_WIN.
	if enemy_alive == 0:
		return VictoryResult.PLAYER_WIN
	if player_alive == 0:
		return VictoryResult.PLAYER_LOSE
	return null   # battle continues


## Emits GameBus.victory_condition_detected(result) once per battle.
## Single-emit guard: if _round_state == BATTLE_ENDED, returns immediately (AC-3).
## On first call: transitions _round_state to BATTLE_ENDED then emits.
## Implements TR-turn-order-007 §AC-2/AC-3.
func _emit_victory(result: int) -> void:
	if _round_state == RoundState.BATTLE_ENDED:
		return   # AC-3 single-emit guard
	_round_state = RoundState.BATTLE_ENDED
	GameBus.victory_condition_detected.emit(result)


## Executes RE1..RE3 round-end sequence after all queued units have completed turns.
## RE1: (deferred to consumers via signal — no direct call here; out-of-scope for story-006)
## RE2: round-cap DRAW check — AC-22 T7 precedence already enforced (T7 ran before this).
##      If _round_number >= ROUND_CAP, emit victory_condition_detected(DRAW) and halt.
## RE3: trigger next round via _begin_round.call_deferred() (Callable method-reference form
##      per godot-specialist 2026-04-30 Item 6; NOT string-based call_deferred).
## Implements TR-turn-order-018 / F-3 round cap.
func _end_round() -> void:
	# Single-emit guard: if BATTLE_ENDED (T7 already emitted), skip all RE phases.
	if _round_state == RoundState.BATTLE_ENDED:
		return
	_round_state = RoundState.ROUND_ENDING
	# RE2: round-cap DRAW — reads ROUND_CAP via BalanceConstants per ADR-0006 (no hardcoded 30).
	if _round_number >= (BalanceConstants.get_const("ROUND_CAP") as int):
		_emit_victory(VictoryResult.DRAW)
		return   # RE3 suppressed — battle ended
	# RE3: start the next round.
	_begin_round.call_deferred()


## Advances to next queued unit OR transitions to ROUND_ENDING at queue exhaustion.
## At queue exhaustion: transitions ROUND_ACTIVE → ROUND_ENDING then calls _end_round().
## _end_round() owns RE1..RE3 (round-cap victory check → DRAW OR next round).
func _advance_to_next_queued_unit() -> void:
	_queue_index += 1
	if _queue_index >= _queue.size():
		_end_round()
	else:
		_advance_turn.call_deferred(_queue[_queue_index])


## Handles unit_died signal from GameBus (subscribed with CONNECT_DEFERRED per
## ADR-0001 §5 deferred-connect mandate — R-1 re-entrancy mitigation).
## Removes unit from _queue immediately (CR-7a); removes from _unit_states.
## Short-circuits with no-op if unit_id not in _unit_states (R-2 double-death guard).
## Full implementation in story-005.
func _on_unit_died(unit_id: int) -> void:
	if not _unit_states.has(unit_id):
		return   # R-2 defensive — double-death no-op; second call is safe
	_unit_states.erase(unit_id)
	var queue_pos: int = _queue.find(unit_id)
	if queue_pos != -1:
		_queue.remove_at(queue_pos)
		# _queue_index adjustment: if removal was at-or-before current index, decrement
		# to keep _queue_index pointing at the same logical "next acting" unit.
		if queue_pos <= _queue_index and _queue_index > 0:
			_queue_index -= 1
	# CR-7d: if the dead unit was ACTING (T5 in flight), the deferred delivery of
	# _on_unit_died (CONNECT_DEFERRED) means this runs AFTER the T5 call stack unwinds.
	# The next _advance_turn call will find _unit_states.has(unit_id) == false at T2
	# and short-circuit — T6 is skipped, _advance_to_next_queued_unit runs naturally.
