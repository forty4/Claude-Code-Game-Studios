class_name TurnOrderEntry
## TurnOrderEntry — one unit's display-facing turn-queue entry in a TurnOrderSnapshot.
##
## Ratified by ADR-0011 §Decision §Typed Resource / wrapper definitions.
## RefCounted (NOT Resource) — battle-scoped non-persistent per CR-1b.
## Pure value semantics: consumers cannot mutate the source TurnOrderRunner state
## via TurnOrderEntry fields (forbidden_pattern: turn_order_consumer_mutation).
##
## turn_state is declared as int (not TurnOrderRunner.TurnState) to allow
## lightweight consumer access without a full TurnOrderRunner reference
## per ADR-0011 §Key Interfaces spec.
##
## See ADR-0011 §Decision §Typed Resource / wrapper definitions for full spec.
extends RefCounted

# ── Public variables ───────────────────────────────────────────────────────────

## Unique identifier for the unit. int per ADR-0001 + ADR-0011 contract lock.
var unit_id: int = 0

## True if this unit is player-controlled; false if AI-controlled.
## Invisible to queue-sort logic (CR-1 interleaved queue); exposed here for HUD display.
var is_player_controlled: bool = false

## Computed initiative value for this unit this battle. Cached at BI-2;
## NOT recomputed each round (CR-6 static initiative rule).
var initiative: int = 0

## True iff this unit has already acted in the current round.
var acted_this_turn: bool = false

## TurnOrderRunner.TurnState enum value for this unit (stored as int for
## lightweight consumer access without requiring a TurnOrderRunner reference).
var turn_state: int = 0
