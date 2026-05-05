## AIActionCommand — typed Resource for AISystem -> GridBattleController action.
##
## Returned by AISystem to GridBattleController via the LOCAL signal
## `ai_action_ready(unit_id, command)` per ADR-0019 §Decision body.
## GridBattleController's CR-3a action validator consumes the command; on
## 500ms timeout substitutes WAIT (CR-3b).
##
## Append-only ActionType enum mirrors BattleOutcome.Result discipline per
## ADR-0003 SaveMigrationRegistry contract — reordering / removing values
## requires a migration registry entry + schema_version bump.
##
## ADR: ADR-0019 §Decision §Payload Form.
## TR: TR-ai-system-004.
class_name AIActionCommand
extends Resource


## Action kind. APPEND-ONLY — never reorder or remove existing values without
## a SaveMigrationRegistry migration entry.
enum ActionType {
	WAIT = 0,
	MOVE = 1,
	ATTACK = 2,
	MOVE_AND_ATTACK = 3,
	DEFEND = 4,
	USE_SKILL = 5,
}


## Acting unit identifier.
@export var unit_id: int = -1

## Action kind from ActionType enum.
@export var action_type: ActionType = ActionType.WAIT

## Target tile for MOVE / MOVE_AND_ATTACK actions. Vector2i.ZERO when unused.
@export var move_target: Vector2i = Vector2i.ZERO

## Target unit_id for ATTACK / MOVE_AND_ATTACK actions. -1 when unused.
@export var attack_target_unit_id: int = -1

## Skill identifier for USE_SKILL actions (e.g., &"rally"). Empty when unused.
@export var skill_id: StringName = &""


# ─── Static factories ─────────────────────────────────────────────────────────


static func wait(unit_id: int) -> AIActionCommand:
	var c: AIActionCommand = AIActionCommand.new()
	c.unit_id = unit_id
	c.action_type = ActionType.WAIT
	return c


static func move(unit_id: int, target: Vector2i) -> AIActionCommand:
	var c: AIActionCommand = AIActionCommand.new()
	c.unit_id = unit_id
	c.action_type = ActionType.MOVE
	c.move_target = target
	return c


static func attack(unit_id: int, target_unit_id: int) -> AIActionCommand:
	var c: AIActionCommand = AIActionCommand.new()
	c.unit_id = unit_id
	c.action_type = ActionType.ATTACK
	c.attack_target_unit_id = target_unit_id
	return c


static func move_and_attack(unit_id: int, move_to: Vector2i, target_unit_id: int) -> AIActionCommand:
	var c: AIActionCommand = AIActionCommand.new()
	c.unit_id = unit_id
	c.action_type = ActionType.MOVE_AND_ATTACK
	c.move_target = move_to
	c.attack_target_unit_id = target_unit_id
	return c


static func defend(unit_id: int) -> AIActionCommand:
	var c: AIActionCommand = AIActionCommand.new()
	c.unit_id = unit_id
	c.action_type = ActionType.DEFEND
	return c


static func use_skill(unit_id: int, skill: StringName) -> AIActionCommand:
	var c: AIActionCommand = AIActionCommand.new()
	c.unit_id = unit_id
	c.action_type = ActionType.USE_SKILL
	c.skill_id = skill
	return c
