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
