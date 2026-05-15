## KillPopup — short-lived "X 처치!" banner spawned when a unit is killed
## mid-battle. Sibling to DamagePopup / CriticalPopup. Self-animating Node2D:
## scales in from 0.6×, drifts up 28px, fades out, then queue_frees. Parented
## to ChapterVisuals so the popup survives the victim polygon being hidden.
##
## Construction: `KillPopup.make(victim_name, name_color)` — battle_scene
## resolves the Korean hero name + accent color from HeroDatabase +
## chapter_visuals HERO_ACCENT_BY_HERO_ID before invoking make().
class_name KillPopup
extends Node2D

const DRIFT_DISTANCE: float = 28.0
const DURATION: float = 1.05
const SCALE_IN_DURATION: float = 0.14
const FADE_DELAY: float = 0.65
const FONT_SIZE: int = 20
const OUTLINE_SIZE: int = 5

## Slate background panel + warm text + name in accent color. Outline near-black
## for contrast against any terrain tile.
const COLOR_KILL_TEXT: Color = Color(0.96, 0.94, 0.86, 1.0)  # bone white
const COLOR_OUTLINE:   Color = Color(0.04, 0.04, 0.05, 1.0)

var _victim_name: String = ""
var _name_color: Color = Color(0.96, 0.86, 0.42, 1.0)


static func make(victim_name: String, name_color: Color) -> KillPopup:
	var p: KillPopup = KillPopup.new()
	p._victim_name = victim_name
	if name_color.a > 0.0:
		p._name_color = name_color
	return p


func _ready() -> void:
	# Two labels stacked: NAME (accent color) + " 처치!" (white). Stacking via
	# horizontal alignment in two separate Labels avoids BBCode dependency.
	# Compose a single RichText-style line by inserting a Container? Simpler:
	# one Label with text "X 처치!" tinted in the accent color (single hue).
	# Trade-off: name doesn't separately stand out from the "처치!" suffix, but
	# the whole line is in the killer's accent color which is more cohesive.
	var label: Label = Label.new()
	label.text = "%s 처치!" % _victim_name
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", _name_color)
	label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	label.position = Vector2(-80.0, -12.0)
	label.size = Vector2(160.0, 24.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(label)
	scale = Vector2(0.6, 0.6)
	_animate()


func _animate() -> void:
	# Tree-bound tweens per G-31 (immune to BattleScene PROCESS_MODE_DISABLED).
	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.08, 1.08), SCALE_IN_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y - DRIFT_DISTANCE, DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Settle to 1.0× after the bounce
	var settle: Tween = get_tree().create_tween()
	settle.tween_interval(SCALE_IN_DURATION)
	settle.tween_property(self, "scale", Vector2(1.0, 1.0), 0.08) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	# Fade out after FADE_DELAY
	var fade: Tween = get_tree().create_tween()
	fade.tween_interval(FADE_DELAY)
	fade.tween_property(self, "modulate:a", 0.0, DURATION - FADE_DELAY) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade.tween_callback(queue_free)
