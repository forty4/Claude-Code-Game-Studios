## MockBattleController — integration test helper for Story 007.
##
## Minimal stand-in for the real BattleController (owned by Grid Battle epic).
## Exposes a single method to emit GameBus.battle_outcome_resolved on demand,
## simulating the real BattleController's CLEANUP entry point.
##
## INTEGRATION TEST USE ONLY — not a substitute for the real BattleController.
class_name MockBattleController
extends Node


## Emits GameBus.battle_outcome_resolved with the given payload.
## Mirrors the real BattleController's CLEANUP contract per ADR-0001 §Signal Schema.
## Emission is synchronous from the caller's frame; connected subscribers using
## CONNECT_DEFERRED receive the payload on the next idle frame.
func emit_outcome(payload: BattleOutcome) -> void:
	GameBus.battle_outcome_resolved.emit(payload)
