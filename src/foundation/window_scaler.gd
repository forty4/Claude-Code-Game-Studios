## window_scaler.gd
## Resizes the game window to a sensible fraction of the screen at startup,
## centered within the screen's usable area.
##
## Without this, Godot opens at the project base viewport (1920×1080)
## regardless of display resolution — on Retina / 4K Mac displays this is
## ≤50% of physical screen width and feels small. canvas_items stretch
## (already enabled in project.godot) scales UI proportionally with window
## size, so resizing the window naturally scales text and HUD as well.
##
## Strategy: window = 85% of usable area (Mac menubar / Dock excluded),
## 16:9 preserved via smaller-axis scale, clamped so we never SHRINK below
## the base 1920×1080. Single-shot at _ready(); no signals, no state.
##
## Headless safety: DisplayServer.screen_get_usable_rect() returns (0,0)
## size in headless mode → guard short-circuits and the entire scaler
## no-ops, so test suite + CI never resize anything.
##
## NO `class_name` per G-3 autoload rule.
extends Node


const _BASE_W: int = 1920
const _BASE_H: int = 1080
const _TARGET_FRACTION: float = 0.85


func _ready() -> void:
	var screen_idx: int = DisplayServer.window_get_current_screen()
	var usable: Rect2i = DisplayServer.screen_get_usable_rect(screen_idx)
	if usable.size.x <= 0 or usable.size.y <= 0:
		return  # headless or invalid display info — leave window alone

	# Target = 85% of usable area; preserve 16:9 by picking the smaller axis scale.
	var scale_w: float = (float(usable.size.x) * _TARGET_FRACTION) / float(_BASE_W)
	var scale_h: float = (float(usable.size.y) * _TARGET_FRACTION) / float(_BASE_H)
	var scale: float = min(scale_w, scale_h)
	if scale <= 1.0:
		return  # display is at-or-below base viewport; default sizing is fine

	var final_w: int = int(float(_BASE_W) * scale)
	var final_h: int = int(float(_BASE_H) * scale)
	DisplayServer.window_set_size(Vector2i(final_w, final_h))

	# Center within usable area (handles macOS menubar offset + multi-monitor).
	var pos: Vector2i = usable.position + Vector2i(
		(usable.size.x - final_w) / 2,
		(usable.size.y - final_h) / 2
	)
	DisplayServer.window_set_position(pos)
