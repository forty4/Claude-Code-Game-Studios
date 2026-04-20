## BattlePayload — payload for GameBus.battle_prepare_requested and GameBus.battle_launch_requested.
## Emitter: ScenarioRunner (Scenario Progression — IN_BATTLE transition).
## Consumed by: Battle HUD, SceneManager.
##
## deployment_positions: Dictionary — keys are int (unit_id), values are Vector2i (grid coord).
## Dynamic key set at runtime requires Dictionary; all other fields are statically typed.
## This is the sole permitted untyped container per story AC-6 exemption.
class_name BattlePayload
extends Resource

@export var map_id: String = ""
@export var unit_roster: PackedInt64Array = PackedInt64Array()
## deployment_positions keys: int (unit_id) -> values: Vector2i (grid coord)
@export var deployment_positions: Dictionary = {}
@export var victory_conditions: VictoryConditions = null
@export var battle_start_effects: Array[BattleStartEffect] = []
