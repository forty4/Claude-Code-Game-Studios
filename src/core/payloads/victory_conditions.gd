## VictoryConditions — nested payload inside BattlePayload.victory_conditions.
## Emitter: ScenarioRunner (via BattlePayload on battle_prepare_requested / battle_launch_requested).
## Consumed by: Battle HUD (UI-GB-08 victory condition display) +
## GridBattleController (_check_battle_end + _on_round_started SURVIVE check).
##
## Session-28 — closed the placeholder. Pre-S28 the resource carried just
## `primary_condition_type` + `target_unit_ids` but neither field was ever
## read; the controller hardcoded ANNIHILATION-only checks. Post-S28 the
## resource defines a proper ConditionType taxonomy + per-type params, and
## the controller's `_check_battle_end` dispatches on condition_type.
##
## Default-construction (ConditionType.ANNIHILATION + zero fields) preserves
## the pre-S28 behaviour for chapters that don't set victory_conditions at
## all — null vc passed to the controller falls through to the default
## ANNIHILATION dispatcher path.
class_name VictoryConditions
extends Resource


## Victory-condition taxonomy. Default = ANNIHILATION (legacy MVP behaviour).
##   ANNIHILATION    — Player wins when all enemy units are dead; loses when
##                     all player units are dead. The pre-S28 baseline.
##   SURVIVE_N_ROUNDS — Player wins when round_num exceeds `survive_rounds`
##                     (i.e., on the start of round survive_rounds+1, having
##                     survived survive_rounds full rounds). Player still
##                     loses on full wipeout before the threshold. Enemy
##                     wipeout does NOT shortcut to victory — the player
##                     must hold position long enough.
##   ESCORT          — Player wins when all enemies are dead AND every
##                     unit in `target_unit_ids` is still alive. Loses
##                     immediately when any target dies (DEFEAT_ESCORT_LOST)
##                     OR when all player units die (DEFEAT_ANNIHILATION).
##                     The target-death check PRECEDES the win check, so
##                     a mutual-kill round (enemy wipeout + target dies on
##                     the same unit_died tick) resolves to DEFEAT.
##                     `target_unit_ids` is REQUIRED for ESCORT — empty
##                     list degrades to ANNIHILATION behaviour with a
##                     diagnostic push_warning.
##   REACH_TILE      — Player wins when `target_unit_ids[0]` reaches the
##                     coordinate `target_tile`. Enemy wipeout does NOT
##                     shortcut to victory (REACH-only — mirrors SURVIVE
##                     no-shortcut semantics). Loses when the target unit
##                     dies (DEFEAT_REACH_FAILED) OR when all player units
##                     die (DEFEAT_ANNIHILATION). Empty target_unit_ids
##                     degrades to ANNIHILATION with diagnostic warning.
##                     "Escape / scout-through" scenarios — beating the
##                     enemy isn't the win path, slipping past is.
enum ConditionType {
	ANNIHILATION = 0,
	SURVIVE_N_ROUNDS = 1,
	ESCORT = 2,
	REACH_TILE = 3,
}


## Active condition type. Reads as one of the ConditionType enum values.
## Backed by int rather than ConditionType so existing chapter .tres files
## that set `primary_condition_type = 0` continue to parse correctly without
## migration. Use VictoryConditions.ConditionType for new authoring.
@export var primary_condition_type: int = ConditionType.ANNIHILATION

## SURVIVE_N_ROUNDS param — player wins after surviving this many full rounds.
## `survive_rounds = 3` means: round 1 plays, round 2 plays, round 3 plays;
## at the start of round 4 the controller emits VICTORY_SURVIVE. 0 = unused
## (irrelevant for non-SURVIVE_N_ROUNDS types).
@export var survive_rounds: int = 0

## ESCORT param (session-30) — unit_ids of the protectees. Player wins only
## if ALL of these are alive at the moment of enemy wipeout; player loses
## immediately when any one of them dies.
## REACH_TILE param (session-31) — `target_unit_ids[0]` is the unit that
## must reach `target_tile`. Additional ids beyond [0] are unused for
## REACH_TILE (multi-unit reach not in MVP scope).
## Empty list is degenerate for ESCORT/REACH_TILE (falls through to
## ANNIHILATION with a diagnostic warning).
@export var target_unit_ids: PackedInt64Array = PackedInt64Array()

## REACH_TILE param (session-31) — destination coordinate that the target
## unit must occupy. Compared against unit.position by `_check_reach_tile_
## victory()` on every unit_moved emit. Vector2i.ZERO (0,0) is a valid
## map coord, but ALSO the default-construct value — chapters using
## REACH_TILE must set this explicitly. The dispatcher does NOT validate
## "is this tile passable" — chapter authors are responsible for picking
## a reachable destination.
@export var target_tile: Vector2i = Vector2i.ZERO
