## TurnOrderRunnerStub — minimal test stub for TurnOrderRunner DI seam.
##
## Extends TurnOrderRunner (Node) so it satisfies the typed
## `_turn_runner: TurnOrderRunner` field on GridBattleController.
##
## `initialize_battle()` override prevents the production GameBus.unit_died
## subscription from firing during tests that never call initialize_battle().
##
## NOTE: The production TurnOrderRunner emits `round_started` + `unit_turn_started`
## via GameBus (`GameBus.round_started.emit(...)` + `GameBus.unit_turn_started.emit(...)`
## per src/core/turn_order_runner.gd:486+509). There are NO instance signals
## `round_started` / `unit_turn_started` on TurnOrderRunner. Therefore this stub
## does NOT redeclare them locally — GridBattleController subscribes to
## `GameBus.round_started` + `GameBus.unit_turn_started`, not `_turn_runner.X`.
## Verified at story-001 implementation 2026-05-02 (ADR-0014 §3 sketch drift;
## ADR amended same-patch).
##
## Story-006: declare_action override captures (unit_id, action) tuples for
## token-spend assertions without enforcing the production state-machine
## (UNIT_NOT_FOUND / NOT_UNIT_TURN) — controller-side single-token MVP per
## ADR-0014 §6 simplification + Implementation Notes drift #9 (sketch said
## `spend_action_token`; shipped API is `declare_action`).
class_name TurnOrderRunnerStub
extends TurnOrderRunner


## Captured declare_action call args. Each entry: {"unit_id": int, "action": int}.
var declared_actions: Array[Dictionary] = []


func initialize_battle(_unit_roster: Array[BattleUnit]) -> void:
	# No-op: prevents production GameBus.unit_died subscription during tests.
	pass


func declare_action(unit_id: int, action: int, _target: ActionTarget) -> ActionResult:
	declared_actions.append({"unit_id": unit_id, "action": action})
	return ActionResult.make_success()


# ─── Session-13: charge eligibility test seam ─────────────────────────────────


## Per-unit_id charge eligibility override. Tests set via
## set_charge_eligible_for_test(unit_id, bool); the production caller
## (GridBattleController._resolve_attack + preview_attack) reads via
## is_unit_charge_eligible(unit_id). Default false (no charge eligible)
## so existing tests' damage assertions remain stable.
var _test_charge_eligible: Dictionary[int, bool] = {}


## Test seam — populate the per-unit charge eligibility lookup.
func set_charge_eligible_for_test(unit_id: int, eligible: bool) -> void:
	_test_charge_eligible[unit_id] = eligible


## Override of TurnOrderRunner.is_unit_charge_eligible. Production reads
## accumulated_move_cost against CHARGE_THRESHOLD; the stub reads from the
## test-seam dictionary so test fixtures can force the boolean directly.
func is_unit_charge_eligible(unit_id: int) -> bool:
	return _test_charge_eligible.get(unit_id, false)


# ─── Session-14: round number test seam (AMBUSH_BONUS gating) ────────────────


## Test seam — forces the inherited _round_number used by
## get_current_round_number(). GridBattleController.{_resolve_attack,preview_attack}
## query the round number to gate AMBUSH_BONUS (DamageCalc._ambush_factor
## requires round_number >= 2). Default 0 matches production cold-start; tests
## that want ambush eligibility call set_round_number_for_test(2) or higher.
func set_round_number_for_test(round_number: int) -> void:
	_round_number = round_number


# ─── Session-24: unit turn state test seam (is_action_available coverage) ────


## Test seam — sets a per-unit UnitTurnState that get_unit_turn_state() returns.
## GridBattleController.is_action_available reads turn_runner.get_unit_turn_state
## for token + DEFEND lock + turn_state queries. Tests pass an authored fixture
## state via this seam to exercise availability rules without running the full
## initialize_battle → declare_action pipeline.
var _test_unit_states: Dictionary[int, UnitTurnState] = {}


func set_unit_turn_state_for_test(unit_id: int, state: UnitTurnState) -> void:
	_test_unit_states[unit_id] = state


## Override of TurnOrderRunner.get_unit_turn_state. Production reads
## _unit_states[unit_id].snapshot(); stub returns the fixture state set via
## set_unit_turn_state_for_test, or null if not set (matches production
## "unknown unit_id" return).
func get_unit_turn_state(unit_id: int) -> UnitTurnState:
	return _test_unit_states.get(unit_id, null)
