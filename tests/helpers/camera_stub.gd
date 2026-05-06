## CameraStub — RefCounted test stub for the InputRouter `_camera: Variant`
## injection seam. Production CameraController class doesn't exist yet (story-014
## narrows when Camera ADR ships); this stub provides screen→grid mapping for
## touch coord resolution + clamp_zoom for F-1 zoom-floor verification.
##
## Class form: class_name + RefCounted (G-26 verified — no collision with built-ins
## or existing user class_name; new identifier).
class_name CameraStub
extends RefCounted

## Per-screen-pos fixture mapping. Tests populate to fixture exact screen→grid pairs.
## G-25 safe — depth-1 typed Dictionary.
var screen_to_grid_map: Dictionary[Vector2i, Vector2i] = {}

## Current zoom level. Tests mutate via set_zoom; clamped to F-1 floor.
var current_zoom: float = 1.0


## Returns grid coord for a screen position. Falls back to integer-divide-by-64
## (default tile_world_size) when no fixture entry. Tests using non-fixture coords
## get deterministic results without per-test setup.
func screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var key := Vector2i(int(screen_pos.x), int(screen_pos.y))
	return screen_to_grid_map.get(
		key,
		Vector2i(int(screen_pos.x / 64), int(screen_pos.y / 64))
	)


## F-1 floor enforcement: zoom cannot go below 0.70 (44.8px effective at tile_world=64).
func clamp_zoom(zoom: float) -> float:
	return max(zoom, 0.70)


func get_zoom() -> float:
	return current_zoom


func set_zoom(z: float) -> void:
	current_zoom = clamp_zoom(z)
