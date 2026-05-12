## AttackLine — short-lived line drawn from attacker to defender on
## `damage_applied`. Self-animating: fades `modulate:a → 0` over DURATION then
## queue_frees. Parented to ChapterVisuals (NOT either polygon) so the line
## survives if the hit kills the defender or moves the attacker.
##
## Construction: use the static `make(from, to)` factory; positions are in the
## same world-space frame as the unit polygons (ChapterVisuals local space).
class_name AttackLine
extends Node2D

const DURATION: float = 0.2
const WIDTH: float = 3.0
const OUTLINE_WIDTH_BONUS: float = 1.5

const COLOR_LINE:    Color = Color(0.95, 0.88, 0.70, 0.85)  # warm cream
const COLOR_OUTLINE: Color = Color(0.05, 0.04, 0.04, 0.85)  # ink stroke

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO


static func make(from: Vector2, to: Vector2) -> AttackLine:
	var l: AttackLine = AttackLine.new()
	l._from = from
	l._to = to
	return l


func _ready() -> void:
	_animate()


func _draw() -> void:
	# Black backing for readability against any terrain tile color.
	draw_line(_from, _to, COLOR_OUTLINE, WIDTH + OUTLINE_WIDTH_BONUS)
	draw_line(_from, _to, COLOR_LINE, WIDTH)


func _animate() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
