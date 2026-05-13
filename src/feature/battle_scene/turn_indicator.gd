## TurnIndicator — view-layer cue marking whose turn is currently active.
##
## Single instance, owned by BattleScene, reparented under the active unit's
## Polygon2D on each `_grid_controller.active_unit_changed` emit. Inherits
## transform + visibility from its parent polygon (so movement carries it,
## death hides it via CanvasItem visibility cascade).
##
## Visual: downward chevron in warm cream, sitting above the HP bar. Subtle
## vertical bob keeps the "attention here" read without competing with
## selection (gold outline) or HP bar (green/yellow/red).
class_name TurnIndicator
extends Node2D

## Y-offset above the polygon center. HP bar sits at -28 with ~5px height, so
## the indicator's tip rests just above the bar's top edge.
const Y_OFFSET: float = -44.0
const CHEVRON_HALF_WIDTH: float = 11.0
const CHEVRON_HEIGHT: float = 13.0

const COLOR_FILL:    Color = Color(1.00, 0.85, 0.20, 1.00)  # bright gold
const COLOR_OUTLINE: Color = Color(0.11, 0.10, 0.09, 1.00)  # ink stroke

const BOB_AMPLITUDE: float = 6.0
const BOB_DURATION: float = 0.45

var _bob_tween: Tween = null


func _ready() -> void:
	position = Vector2(0.0, Y_OFFSET)
	_start_bob()


func _exit_tree() -> void:
	if _bob_tween != null and _bob_tween.is_valid():
		_bob_tween.kill()
	_bob_tween = null


func _start_bob() -> void:
	if _bob_tween != null and _bob_tween.is_valid():
		_bob_tween.kill()
	_bob_tween = create_tween().set_loops()
	_bob_tween.tween_property(self, "position:y", Y_OFFSET - BOB_AMPLITUDE, BOB_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bob_tween.tween_property(self, "position:y", Y_OFFSET + BOB_AMPLITUDE, BOB_DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _draw() -> void:
	# Chevron points down toward the unit polygon below.
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(-CHEVRON_HALF_WIDTH, 0.0),
		Vector2(CHEVRON_HALF_WIDTH, 0.0),
		Vector2(0.0, CHEVRON_HEIGHT),
	])
	draw_colored_polygon(pts, COLOR_FILL)
	# Closed outline (last→first) — thicker stroke for visibility.
	var outline: PackedVector2Array = PackedVector2Array([pts[0], pts[1], pts[2], pts[0]])
	draw_polyline(outline, COLOR_OUTLINE, 2.0, true)
