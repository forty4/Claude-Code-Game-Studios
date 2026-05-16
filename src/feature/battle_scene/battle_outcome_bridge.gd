## BattleOutcomeBridge — turns the battle's end into a Battle-domain BattleOutcome
## and publishes it on GameBus so ScenarioRunner (post-battle beats + chapter
## advance) and SceneManager (BattleScene/Overworld teardown) can react.
##
## Why a separate node: ADR-0016 R-7 forbids the BattleScene root from emitting
## GameBus signals, and ADR-0014 §8 forbids GridBattleController from emitting
## GameBus signals (its `battle_outcome_resolved` is controller-LOCAL). So the
## scene-root → GameBus hop goes through a dedicated mounted child — same shape
## as AISystem (battle-scoped, set up + add_child'd by BattleScene).
##
## Input: GridBattleController.battle_outcome_resolved(outcome: StringName,
## fate_data: Dictionary) — wired by BattleScene at mount time.
## Output: GameBus.battle_outcome_resolved(BattleOutcome).
##
## Exactly-once: a battle resolves exactly one outcome (mirrors
## GridBattleController._battle_over / TurnOrderRunner once-per-battle).
class_name BattleOutcomeBridge
extends Node

## Set by BattleScene.setup() before add_child. Stamped onto the BattleOutcome so
## ScenarioRunner's EC-SP-2 chapter_id-match guard passes.
var _chapter_id: String = ""
var _published: bool = false


## Outcome StringName → BattleOutcome.Result. Keys match
## GridBattleController._emit_battle_outcome's emitted values.
## Session-28 — VICTORY_SURVIVE added for SURVIVE_N_ROUNDS condition type.
## Session-30 — VICTORY_ESCORT + DEFEAT_ESCORT_LOST added for ESCORT type.
const _OUTCOME_TO_RESULT: Dictionary = {
	&"VICTORY_ANNIHILATION": BattleOutcome.Result.WIN,
	&"VICTORY_SURVIVE": BattleOutcome.Result.WIN,
	&"VICTORY_ESCORT": BattleOutcome.Result.WIN,
	&"DEFEAT_ANNIHILATION": BattleOutcome.Result.LOSS,
	&"DEFEAT_ESCORT_LOST": BattleOutcome.Result.LOSS,
	&"TURN_LIMIT_REACHED": BattleOutcome.Result.DRAW,
}


func setup(chapter_id: String) -> void:
	_chapter_id = chapter_id


## Handler for GridBattleController's LOCAL battle_outcome_resolved signal.
## Connected by BattleScene (the controller does not know this node exists).
func on_local_outcome(outcome: StringName, _fate_data: Dictionary) -> void:
	if _published:
		return
	_published = true
	var bo: BattleOutcome = BattleOutcome.new()
	bo.result = _OUTCOME_TO_RESULT.get(outcome, BattleOutcome.Result.DRAW) as BattleOutcome.Result
	bo.chapter_id = _chapter_id
	# CONNECT_DEFERRED on the subscriber side (ScenarioRunner, SceneManager) per
	# ADR-0001 §5 — this emit is fine to call synchronously from the controller's
	# signal chain; the subscribers' handlers run next idle frame.
	GameBus.battle_outcome_resolved.emit(bo)
