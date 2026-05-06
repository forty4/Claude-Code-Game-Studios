## BattleHUDStub — RefCounted test stub for the Battle HUD subscriber contract that
## consumes InputRouter signals. Story-008 AC-10 introduces this stub for TPP +
## Magnifier verification. Records all method invocations so tests can assert
## the call sequence + payload shapes.
##
## Class form: class_name + RefCounted (G-26 verified — no collision with existing
## class_name BattleHUD or BattleHUDController; this is a new identifier).
class_name BattleHUDStub
extends RefCounted

var show_unit_info_calls: Array[Dictionary] = []
var show_tile_info_calls: Array[Dictionary] = []
var dismiss_preview_calls: int = 0
var show_magnifier_calls: Array[Dictionary] = []


func show_unit_info(unit_id: int) -> void:
	show_unit_info_calls.append({"unit_id": unit_id})


func show_tile_info(coord: Vector2i) -> void:
	show_tile_info_calls.append({"coord": coord})


func dismiss_preview() -> void:
	dismiss_preview_calls += 1


func show_magnifier(touch_pos: Vector2, cluster_coords: Array[Vector2i]) -> void:
	show_magnifier_calls.append({"touch_pos": touch_pos, "cluster_coords": cluster_coords})
