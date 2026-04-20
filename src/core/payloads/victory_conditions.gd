## VictoryConditions — nested payload inside BattlePayload.victory_conditions.
## Emitter: ScenarioRunner (via BattlePayload on battle_prepare_requested / battle_launch_requested).
## Consumed by: Battle HUD, BattleController (win evaluation logic).
##
## Shape PROVISIONAL — locked by Grid Battle ADR; currently placeholder for BattlePayload.
## Fields will expand once the Grid Battle ADR finalises victory condition types.
class_name VictoryConditions
extends Resource

@export var primary_condition_type: int = 0
@export var target_unit_ids: PackedInt64Array = PackedInt64Array()
