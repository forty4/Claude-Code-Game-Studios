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
## Story-006 extension (Option A — direct extension, per TD-015 LIMITATION note):
##   Added _retry_count, auto_retry_on_loss flag, _retry_payload, reset_for_new_battle(),
##   and set_retry_payload() to support multi-cycle retry integration tests (AC-5, AC-7).
##   The LIMITATION note (lines 30-35 in the original) explicitly anticipated this need and
##   named the method reset_for_new_battle() — resolved here without subclassing.
##   Story-007 tests that do not set auto_retry_on_loss are unaffected (default is false).
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
## Set to true after the first valid payload is consumed. Reset via reset_for_new_battle()
## for multi-cycle retry tests. Real ScenarioRunner resets its state-machine guard on
## transition back to IN_BATTLE — this mock mirrors that via the explicit reset method.
var _consumed_once: bool = false

## Number of battle_launch_requested re-emits issued by this mock.
## Increments each time auto_retry_on_loss triggers a re-emit (story-006 AC-5, AC-7).
var _retry_count: int = 0

## When true, _on_battle_outcome automatically re-emits battle_launch_requested on LOSS,
## simulating F-SP-3 Echo-retry. Requires set_retry_payload() to be called before use.
## Default false so story-007 tests (which do not configure retry) remain unaffected.
var auto_retry_on_loss: bool = false

## The BattlePayload to re-emit on retry. Set via set_retry_payload().
## Kept as a Resource reference — BattlePayload extends Resource and is ref-counted,
## so reusing the same instance across cycles is safe. If spurious is_instance_valid
## warnings appear on deferred-queued payloads during the 5-cycle test, switch to
## caching map_id and building a fresh BattlePayload.new() per cycle inside this handler.
var _retry_payload: BattlePayload = null


func _ready() -> void:
	# CONNECT_DEFERRED mandatory for cross-scene connects per ADR-0001 §5.
	# Handler fires on the next idle frame, after the emitter's frame resolves.
	GameBus.battle_outcome_resolved.connect(_on_battle_outcome, CONNECT_DEFERRED)


func _exit_tree() -> void:
	# is_connected guard prevents double-disconnect errors (ADR-0001 §6).
	if GameBus.battle_outcome_resolved.is_connected(_on_battle_outcome):
		GameBus.battle_outcome_resolved.disconnect(_on_battle_outcome)


## Resets the duplicate-emission guard so this mock can receive the next battle's outcome.
## Call between retry cycles, or rely on auto_retry_on_loss to call this automatically on LOSS.
## Mirrors the real ScenarioRunner's state-machine transition back to IN_BATTLE.
func reset_for_new_battle() -> void:
	_consumed_once = false


## Sets the BattlePayload to re-emit when auto_retry_on_loss fires.
## Must be called before the first battle_launch_requested emit in retry tests.
func set_retry_payload(payload: BattlePayload) -> void:
	_retry_payload = payload


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

	# F-SP-3 Echo-retry: re-emit battle_launch_requested on LOSS if flag is set.
	# reset_for_new_battle() clears _consumed_once so the next cycle's outcome is accepted.
	#
	# EMIT VIA call_deferred — NOT synchronous:
	# This handler fires via CONNECT_DEFERRED (Frame N flush). SM's _on_battle_outcome_resolved
	# also fired in Frame N and called call_deferred("_free_battle_scene_and_restore_overworld"),
	# queuing teardown for Frame N+1. If we emitted synchronously here, Godot would queue SM's
	# CONNECT_DEFERRED _on_battle_launch_requested into Frame N's remaining flush — before
	# _free_... runs — causing state=RETURNING_FROM_BATTLE rejection.
	# Deferring the emit places it in Frame N+1's queue AFTER _free_ completes (state → IDLE),
	# so SM's retry handler sees IDLE and proceeds correctly.
	if auto_retry_on_loss and outcome.result == BattleOutcome.Result.LOSS:
		_retry_count += 1
		reset_for_new_battle()
		if is_instance_valid(_retry_payload):
			call_deferred("_emit_retry")
		else:
			push_warning(
				("MockScenarioRunner: auto_retry_on_loss=true but _retry_payload is null"
				+ " — retry emit skipped; call set_retry_payload() before use")
			)


func _emit_retry() -> void:
	if is_instance_valid(_retry_payload):
		GameBus.battle_launch_requested.emit(_retry_payload)
