class_name ActionTarget
## ActionTarget — placeholder target descriptor for declare_action().
##
## Story-004 stub: 2 fields sufficient for token validation tests.
## Story-007 / Grid Battle integration epic will extend with terrain / range / LoS
## validation fields and query methods.
##
## Tests pass `null` for the `target` argument throughout story-004 because
## ActionTarget validation is out of scope here (ADR-0011 story-004 IN-2 deferral).
##
## RULES:
##  - This class is a VALUE OBJECT — create per-action, never mutate after passing.
##  - target_unit_id == 0 and target_position == Vector2i.ZERO are the null-state
##    sentinel values (no target specified).
##
## See ADR-0011 §Key Interfaces — declare_action target parameter.
extends RefCounted

# ── Public variables ───────────────────────────────────────────────────────────

## The unit_id of the targeted unit, or 0 if targeting a grid cell (not a unit).
## int per ADR-0001 + ADR-0011 unit_id type lock.
var target_unit_id: int = 0

## The grid position being targeted, or Vector2i.ZERO if targeting a unit.
## Story-007+ will validate range / LoS / terrain from this coordinate.
var target_position: Vector2i = Vector2i.ZERO

## Movement cost consumed by this MOVE action for F-2 Cavalry Charge accumulation.
## Story-005: read by declare_action(MOVE) path to accumulate accumulated_move_cost.
## Story-007+ Grid Battle integration will populate from terrain cost at the target cell.
## Default 0 = no movement cost (stub state; tests pass explicit values).
var movement_cost: int = 0
