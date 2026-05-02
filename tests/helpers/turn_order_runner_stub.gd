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
class_name TurnOrderRunnerStub
extends TurnOrderRunner


func initialize_battle(_unit_roster: Array[BattleUnit]) -> void:
	# No-op: prevents production GameBus.unit_died subscription during tests.
	pass
