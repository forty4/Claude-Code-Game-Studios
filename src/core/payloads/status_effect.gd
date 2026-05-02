## status_effect.gd
## Per-unit status effect instance — typed Resource with 7 @export fields.
## Authored as 5 .tres templates in assets/data/status_effects/{poison, demoralized,
## defend_stance, inspired, exhausted}.tres; HPStatusController.apply_status duplicates
## the template via .duplicate() into per-unit instances so remaining_turns mutation
## per instance does not affect the shared template (ADR-0010 §4 read-only sub-Resource).
##
## Signal: n/a (data-only Resource; no signal emission)
## Emitter: n/a
## Consumed by: HPStatusController (apply_status, get_modified_stat, _apply_turn_start_tick)
##
## Field count: exactly 7 @export fields per ADR-0010 §4 guardrail.
## effect_type values: 0=BUFF, 1=DEBUFF
## duration_type values: 0=TURN_BASED, 1=CONDITION_BASED, 2=ACTION_LOCKED
class_name StatusEffect
extends Resource

## Unique identifier for this effect type (matches .tres filename stem).
## e.g., &"poison", &"demoralized", &"defend_stance", &"inspired", &"exhausted"
@export var effect_id: StringName = &""

## Effect polarity: 0=BUFF (beneficial), 1=DEBUFF (detrimental).
@export var effect_type: int = 0

## Duration tracking mode:
##   0=TURN_BASED: remaining_turns decremented each unit turn start
##   1=CONDITION_BASED: expires when external condition met (e.g., DEMORALIZED recovery radius)
##   2=ACTION_LOCKED: persists until unit takes a specific action (e.g., DEFEND_STANCE expires on next action)
@export var duration_type: int = 0

## Remaining turn count. For CONDITION_BASED this acts as the turn-cap fallback
## (DEMORALIZED 4-turn cap per CR-6 SE-2). Decremented by _apply_turn_start_tick.
@export var remaining_turns: int = 0

## Stat modifier map: Dictionary[StringName, int] where key is stat name and value
## is signed integer percent modifier (e.g., {&"atk": -25} for DEMORALIZED).
## Empty dictionary means no stat modification (e.g., POISON — damage handled via tick_effect).
@export var modifier_targets: Dictionary = {}

## DoT tick parameters. null if this effect has no per-turn HP damage (BUFFs + non-DoT DEBUFFs).
## Non-null only for POISON (and future DoT variants per OQ-6 extension path).
## Read-only shared reference — do NOT mutate fields on this sub-Resource per ADR-0010 §4.
@export var tick_effect: TickEffect = null

## Unit ID of the attacker/source who applied this effect.
## -1 means unsourced (scenario event, Commander auto-trigger, etc.).
## Used for DEMORALIZED recovery proximity check (source unit proximity per CR-6 SE-2).
@export var source_unit_id: int = -1
