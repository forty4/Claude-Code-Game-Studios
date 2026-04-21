## MockScenarioRunner — integration test helper for Story 007.
##
## Subscribes to GameBus.battle_outcome_resolved and records received payloads.
## Implements the full ADR-0001 §6 lifecycle discipline:
##   - CONNECT_DEFERRED in _ready
##   - is_connected guard + disconnect in _exit_tree
##   - is_instance_valid guard on payload in handler
##
## Also implements the TR-scenario-progression-003 / EC-SP-5 duplicate-emission
## guard (_consumed_once flag). This is the reference implementation that the
## real ScenarioRunner (Scenario Progression epic) will copy.
##
## INTEGRATION TEST USE ONLY — class_name is project-wide for test convenience.
## The real ScenarioRunner is NOT yet implemented; this name is free at time of
## Story 007 authoring. When real ScenarioRunner is implemented it will live in
## src/gameplay/ — this mock remains in tests/integration/core/.
class_name MockScenarioRunner
extends Node


## Payloads received via GameBus.battle_outcome_resolved. Each entry is one
## valid, non-duplicate BattleOutcome. Inspected by integration tests.
var received: Array[BattleOutcome] = []

## EC-SP-5 duplicate-emission guard (TR-scenario-progression-003).
## Set to true after the first valid payload is consumed. Subsequent emissions
## are logged and ignored — mimicking the real ScenarioRunner's state-guard
## that ignores battle_outcome_resolved outside the IN_BATTLE state.
##
## LIMITATION: this flag is never reset after construction. Multi-battle
## integration tests that need to simulate re-entry to IN_BATTLE state must
## either create a fresh MockScenarioRunner per battle OR extend this mock
## with a reset_for_new_battle() method. The real ScenarioRunner will reset
## its state-machine guard on transition back to IN_BATTLE — this mock does NOT
## model that behavior. See TD-015 (story-007 completion notes).
var _consumed_once: bool = false


func _ready() -> void:
	# CONNECT_DEFERRED mandatory for cross-scene connects per ADR-0001 §5.
	# Handler fires on the next idle frame, after the emitter's frame resolves.
	GameBus.battle_outcome_resolved.connect(_on_battle_outcome, CONNECT_DEFERRED)


func _exit_tree() -> void:
	# is_connected guard prevents double-disconnect errors (ADR-0001 §6).
	if GameBus.battle_outcome_resolved.is_connected(_on_battle_outcome):
		GameBus.battle_outcome_resolved.disconnect(_on_battle_outcome)


func _on_battle_outcome(outcome: BattleOutcome) -> void:
	# is_instance_valid guard: a Resource payload passed through a deferred queue
	# can in principle be freed before the handler fires (ADR-0001 §6, EC-SP-5).
	if not is_instance_valid(outcome):
		push_warning("battle_outcome_resolved: invalid payload; ignored")
		return

	# EC-SP-5 duplicate-emission guard (TR-scenario-progression-003).
	# Real ScenarioRunner ignores emissions outside the IN_BATTLE state.
	# Mock uses a boolean flag as the equivalent guard.
	if _consumed_once:
		push_warning("battle_outcome_resolved: duplicate emission; ignored (EC-SP-5)")
		return

	_consumed_once = true
	received.append(outcome)
