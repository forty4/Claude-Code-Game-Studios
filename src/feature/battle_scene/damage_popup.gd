## DamagePopup — short-lived floating damage number above a hit unit.
##
## Self-animating Node2D: drifts up 30px and fades to transparent over 0.8s,
## then queue_frees itself. Parented to ChapterVisuals (NOT the defender's
## polygon) so the popup survives the polygon being hidden by death feedback.
##
## Construction: use the static `make(damage)` factory; do NOT call `.new()`
## directly because the damage value must be set before `_ready` builds the
## Label child.
class_name DamagePopup
extends Node2D

const DRIFT_DISTANCE: float = 30.0
const DURATION: float = 0.8
const FONT_SIZE: int = 18
const LABEL_HALF_WIDTH: float = 30.0
const LABEL_HALF_HEIGHT: float = 10.0
const OUTLINE_SIZE: int = 4

const COLOR_DAMAGE:  Color = Color(1.00, 0.30, 0.25)
const COLOR_OUTLINE: Color = Color(0.05, 0.04, 0.04, 1.0)

var _damage: int = 0


## Constructs a popup with the given damage value. Add to a parent Node2D after
## setting its `position`; `_ready` then builds the label and starts the tween.
static func make(damage: int) -> DamagePopup:
	var p: DamagePopup = DamagePopup.new()
	p._damage = damage
	return p


func _ready() -> void:
	var label: Label = Label.new()
	label.text = "-%d" % _damage
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", COLOR_DAMAGE)
	label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	label.position = Vector2(-LABEL_HALF_WIDTH, -LABEL_HALF_HEIGHT)
	label.size = Vector2(LABEL_HALF_WIDTH * 2.0, LABEL_HALF_HEIGHT * 2.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	_animate()


func _animate() -> void:
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - DRIFT_DISTANCE, DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(queue_free)
