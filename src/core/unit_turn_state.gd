class_name UnitTurnState
## UnitTurnState — per-unit token state + turn tracking + cached battle metadata
## for TurnOrderRunner.
##
## Ratified by ADR-0011 §Decision §Typed Resource / wrapper definitions.
## Same-patch amendment 2026-05-01 (story-002): extended from 6 → 9 fields with
## `initiative: int`, `stat_agility: int`, `is_player_controlled: bool` cached at
## BI-2/BI-3 to support the F-1 sort-time comparator without re-querying HeroDatabase
## per O(N log N) comparison. CR-6 static-initiative rule structurally enforced by
## storage location — values cached once at BI-2/BI-3, never recomputed.
##
## RefCounted (NOT Resource) — battle-scoped non-persistent runtime state per
## ADR-0011 CR-1b lifecycle alignment (mirrors ADR-0010 UnitHPState rationale).
##
## RULES:
##  - All 9 fields are public (no getters/setters) — owned exclusively by
##    TurnOrderRunner; consumers MUST NOT mutate via snapshot()
##    (forbidden_pattern: turn_order_consumer_mutation; ADR-0011 §Decision).
##  - snapshot() uses field-by-field copy; MUST NOT call .duplicate() or
##    .duplicate_deep() — those are Resource methods; UnitTurnState is RefCounted.
##  - unit_id type is int per ADR-0001 line 153 + ADR-0011 lock.
##  - initiative, stat_agility, is_player_controlled are cached at BI-2/BI-3
##    and MUST NOT be written after initialization (CR-6 static-initiative rule).
##
## See ADR-0011 §Decision §Typed Resource / wrapper definitions for full spec.
extends RefCounted

# ── Public variables ───────────────────────────────────────────────────────────

## Unique identifier for the unit. int per ADR-0001 + ADR-0011 contract lock.
var unit_id: int = 0

## True once the unit has spent its MOVE token this turn. Reset to false at T4.
var move_token_spent: bool = false

## True once the unit has spent its ACTION token this turn. Reset to false at T4.
var action_token_spent: bool = false

## Cumulative grid-cell movement cost this turn for F-2 Cavalry Charge budget.
## Reset to 0 at T4 (turn START, not T6) per ADR-0011 R-3 mitigation.
var accumulated_move_cost: int = 0

## True iff at least one token was spent during T5 this turn (CR-3f).
## Read by Damage Calc for Scout Ambush gate via get_acted_this_turn() query.
var acted_this_turn: bool = false

## Current turn phase for this unit within the round.
## Typed as TurnOrderRunner.TurnState enum (nested enum; consumers reference as
## TurnOrderRunner.TurnState.IDLE etc.).
var turn_state: TurnOrderRunner.TurnState = TurnOrderRunner.TurnState.IDLE

## Cached initiative value computed once at BI-2 via UnitRole.get_initiative().
## CR-6 static-initiative rule: MUST NOT be recomputed at R3 — value is fixed
## for the entire battle duration. Used by F-1 cascade comparator Step 0 (DESC).
var initiative: int = 0

## Cached stat_agility from HeroDatabase.get_hero(hero_id).stat_agility at BI-3.
## Read by F-1 cascade comparator Step 1 (DESC) when initiative values are tied.
## Per ADR-0007 read-only contract — source HeroData MUST NOT be mutated.
var stat_agility: int = 0

## True if this unit is controlled by the player; false if AI-controlled.
## Cached at BI-3 from BattleUnit.is_player_controlled.
## Read by F-1 cascade comparator Step 2 (DESC: player-controlled > AI) when
## both initiative and stat_agility are tied.
var is_player_controlled: bool = false

# ── Public methods ─────────────────────────────────────────────────────────────

## Returns a defensive deep copy via explicit field-by-field assignment.
## Consumer cannot mutate the original UnitTurnState via the returned copy
## (forbidden_pattern: turn_order_consumer_mutation — ADR-0011 §Decision).
##
## Per godot-specialist 2026-04-30 Item 3 + G-2 prevention:
## NOT .duplicate() / .duplicate_deep() — those are Resource methods;
## UnitTurnState is RefCounted, NOT Resource. Field-by-field is idiomatic.
##
## Copies all 9 fields (6 original + 3 metadata added 2026-05-01 story-002).
##
## Usage:
##     var copy: UnitTurnState = original.snapshot()
##     copy.acted_this_turn = true  # does NOT affect original.acted_this_turn
func snapshot() -> UnitTurnState:
	var copy: UnitTurnState = UnitTurnState.new()
	copy.unit_id = unit_id
	copy.move_token_spent = move_token_spent
	copy.action_token_spent = action_token_spent
	copy.accumulated_move_cost = accumulated_move_cost
	copy.acted_this_turn = acted_this_turn
	copy.turn_state = turn_state
	copy.initiative = initiative
	copy.stat_agility = stat_agility
	copy.is_player_controlled = is_player_controlled
	return copy
