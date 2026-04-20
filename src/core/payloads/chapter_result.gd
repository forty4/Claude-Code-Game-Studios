## ChapterResult — payload for GameBus.chapter_completed.
## Emitter: ScenarioRunner (BRANCH_JUDGMENT -> TRANSITION state).
## Consumed by: Destiny State, Save/Load.
##
## outcome reuses BattleOutcome.Result enum directly (no re-definition).
## branch_triggered is the ID string of the narrative branch chosen; empty if no branch fires.
## flags_to_set is the list of world-state flag IDs to activate after this chapter resolves.
class_name ChapterResult
extends Resource

@export var chapter_id: String = ""
@export var outcome: BattleOutcome.Result = BattleOutcome.Result.LOSS
@export var branch_triggered: String = ""
@export var flags_to_set: Array[String] = []
