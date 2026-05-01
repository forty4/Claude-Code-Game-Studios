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
	# TODO story-005: GameBus.unit_died.connect(_on_unit_died, Object.CONNECT_DEFERRED)
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
	_evaluate_victory_stub()

	# Advance queue or end round.
	_advance_to_next_queued_unit()


## Called by the player input layer (via Grid Battle BattleController) OR AI System
## (via request_action delegation at T4). Validates token availability + DEFEND_STANCE
## locks + range/cooldown gates per ADR-0011 §CR-3 + §CR-4. On success: spends the
## appropriate token(s), updates _unit_states[unit_id], may emit unit_turn_ended at
## T6 if the action is turn-completing.
##
## TODO (story-004): action parameter type will be ActionType enum once declared.
##   For now typed as int (int-compatible with enum values; no cast required).
## TODO (story-004): target parameter type will be ActionTarget once declared.
##   For now typed as Variant to avoid forward-reference.
## TODO (story-004): return type will be ActionResult once declared.
##   For now returns null (Variant stub).
##
## Usage:
##     var result = runner.declare_action(unit_id, ActionType.MOVE, target)
func declare_action(_unit_id: int, _action: int, _target: Variant) -> Variant:
	return null

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
func get_charge_ready(_unit_id: int) -> bool:
	return false


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
func _activate_unit_turn(unit_id: int) -> void:
	var state: UnitTurnState = _unit_states[unit_id]
	state.move_token_spent = false
	state.action_token_spent = false
	state.accumulated_move_cost = 0
	state.acted_this_turn = false
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


## Evaluates victory condition at T7.
## Story-003 STUB — body intentionally empty.
## Story-006 implements full T7 victory check + GameBus.victory_condition_detected emit
## per ADR-0011 §Decision §Emitted signals (signal #4 added 2026-04-30 via §Migration Plan §0).
## NOTE: GameBus.victory_condition_detected signal declaration also pending — same-patch
## amendment to game_bus.gd is owned by story-006.
func _evaluate_victory_stub() -> void:
	pass


## Advances to next queued unit OR transitions to ROUND_ENDING at queue exhaustion.
## At queue exhaustion: state transitions ROUND_ACTIVE → ROUND_ENDING. Does NOT auto-call
## _begin_round() — keeps round transitions explicit for test determinism.
## Story-006 will add RE1..RE3 round-end logic (alive count → victory check → emit OR next round).
func _advance_to_next_queued_unit() -> void:
	_queue_index += 1
	if _queue_index >= _queue.size():
		_round_state = RoundState.ROUND_ENDING
	else:
		_advance_turn.call_deferred(_queue[_queue_index])


## Handles unit_died signal from GameBus (subscribed with CONNECT_DEFERRED per
## ADR-0001 §5 deferred-connect mandate — R-1 re-entrancy mitigation).
## Removes unit from _queue immediately (CR-7a); removes from _unit_states.
## Short-circuits with no-op if unit_id not in _unit_states (R-2 double-death guard).
## Full implementation in story-005.
func _on_unit_died(_unit_id: int) -> void:
	pass
