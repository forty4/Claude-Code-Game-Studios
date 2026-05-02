## tick_effect.gd
## DoT (Damage over Time) tick parameters for status effects with per-turn HP damage.
## Authored as a sub-Resource of StatusEffect — shared as read-only reference between
## the .tres template and per-unit duplicated instances (shallow .duplicate() is correct
## per ADR-0010 §4: tick_effect is read-only post-load; no per-instance mutation needed).
##
## Consumed by: HPStatusController._apply_turn_start_tick (story-006 implements F-3)
## Emitter:     n/a (data-only Resource; no signal emission)
## Consumer:    HPStatusController (sole consumer; F-3 DoT formula per ADR-0010 §8)
##
## Field count: exactly 5 @export fields per ADR-0010 §4 guardrail.
## damage_type=0 means TRUE_DAMAGE — bypasses the F-1 intake pipeline; direct HP reduction.
class_name TickEffect
extends Resource

## Damage type applied by the DoT tick. 0 = TRUE_DAMAGE (bypasses F-1 intake pipeline;
## direct current_hp -= dot_damage per F-3 per ADR-0010 §8 lines 366-368).
@export var damage_type: int = 0

## F-3 max_hp coefficient — fraction of max_hp applied as base DoT per tick.
## POISON default: 0.04 (4% of max_hp per turn per ADR-0010 §12).
@export var dot_hp_ratio: float = 0.0

## F-3 fixed addend — flat HP damage added to the ratio component each tick.
## POISON default: 3 per ADR-0010 §12.
@export var dot_flat: int = 0

## F-3 floor — minimum HP damage per tick (after floor(ratio + flat) computation).
## POISON default: 1 per ADR-0010 §12.
@export var dot_min: int = 0

## F-3 ceiling — maximum HP damage allowed per tick (prevents excessive DoT on high-HP units).
## POISON default: 20 per ADR-0010 §12.
@export var dot_max_per_turn: int = 0
