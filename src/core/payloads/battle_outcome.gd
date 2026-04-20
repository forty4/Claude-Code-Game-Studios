## BattleOutcome — payload for GameBus.battle_outcome_resolved.
## Emitter: BattleController (CLEANUP entry).
## Consumed by: ScenarioRunner (OUTCOME state), Save/Load (via chapter_completed chain),
## Character Growth (post-MVP).
##
## Result enum is tri-state {WIN, DRAW, LOSS} per Pillar-alignment decision.
## Scenario Progression F-SP-2 maps DRAW to LOSS for branch routing; the original
## DRAW value is preserved on this payload for Destiny State / telemetry.
## Enum ordering is frozen per TR-save-load-005 (append-only — never reorder or remove).
class_name BattleOutcome
extends Resource

enum Result { WIN, DRAW, LOSS }

@export var result: Result = Result.LOSS
@export var chapter_id: String = ""
@export var final_round: int = 0
@export var surviving_units: PackedInt64Array = PackedInt64Array()
@export var defeated_units: PackedInt64Array = PackedInt64Array()
@export var is_abandon: bool = false  # LOSS-only; true if player chose Abandon
