## ChapterResult — payload for GameBus.chapter_completed.
## Emitter: ScenarioRunner (BEAT_9_TRANSITION entry).
## Consumed by: Destiny State, Save/Load.
##
## outcome reuses BattleOutcome.Result enum directly (no re-definition).
## branch_triggered is DEPRECATED — use branch_path_id instead. Kept for
## back-compat during sprint-7+ schema migration: both fields are set to the
## same value at emit time by ScenarioRunner.
## flags_to_set is the list of world-state flag IDs to activate after this chapter resolves.
##
## Sprint-7 S7-02 EXTENSION: added branch_path_id + echo_count_at_completion per
## AC-SP-9 + ADR-0017 §Key Interfaces. Existing 4 fields preserved for test compat.
## ADR: ADR-0017 §Key Interfaces §ChapterResult.
class_name ChapterResult
extends Resource

@export var chapter_id: String = ""
@export var outcome: BattleOutcome.Result = BattleOutcome.Result.LOSS
## DEPRECATED ALIAS for branch_path_id; populated for back-compat during sprint-7+
## schema migration. Use branch_path_id for new code.
@export var branch_triggered: String = ""
@export var flags_to_set: Array[String] = []

## Canonical branch path identifier resolved by DestinyBranchJudge.
## Same value as branch_triggered (both set at emit time in ScenarioRunner).
@export var branch_path_id: String = ""

## Echo count snapshot BEFORE Beat 9 reset.
## For no-retry chapters this is 0; for retried chapters it is the retry count.
@export var echo_count_at_completion: int = 0
