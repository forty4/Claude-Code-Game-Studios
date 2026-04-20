## InputContext — payload for GameBus.input_action_fired (alongside a String action name).
## Emitter: InputRouter.
## Consumed by: Grid Battle, Battle HUD, Tutorial.
##
## source_device: 0 = keyboard/mouse, 1 = touch, 2 = gamepad (values TBD by InputRouter ADR).
## target_unit_id: -1 means no unit targeted (ground/UI click — sentinel value).
class_name InputContext
extends Resource

@export var target_coord: Vector2i = Vector2i.ZERO
@export var target_unit_id: int = -1
@export var source_device: int = 0
