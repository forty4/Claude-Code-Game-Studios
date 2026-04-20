## BattleStartEffect — nested payload inside BattlePayload.battle_start_effects.
## Emitter: ScenarioRunner (via BattlePayload on battle_prepare_requested / battle_launch_requested).
## Consumed by: BattleController (setup phase), Battle HUD.
##
## Shape PROVISIONAL — locked by Grid Battle ADR; currently placeholder for BattlePayload.
## Fields will expand once the Grid Battle ADR finalises effect categories.
class_name BattleStartEffect
extends Resource

@export var effect_id: String = ""
@export var target_faction: int = 0
@export var value: int = 0
