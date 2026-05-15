## SkillPopup — short-lived banner for hero active skill activation.
##
## Self-animating Node2D: scales in from 0.5×, drifts up, holds, then fades.
## Sibling to CriticalPopup / KillPopup. Spawned at caster polygon position
## by battle_scene when grid_battle_controller emits unit_skill_used.
##
## Construction: `SkillPopup.make(display_name, accent_color)`.
## display_name: Korean skill name (e.g., "청룡언월도!", "호로후!", "격려!").
## accent_color: hero accent color so caster identity reads at a glance.
class_name SkillPopup
extends Node2D

const DRIFT_DISTANCE: float = 42.0
const DURATION: float = 1.10
const SCALE_IN_DURATION: float = 0.14
const FADE_DELAY: float = 0.65
const FONT_SIZE_BANNER: int = 24
const OUTLINE_SIZE: int = 5
const BANNER_OFFSET_Y: float = -28.0

const COLOR_OUTLINE: Color = Color(0.06, 0.04, 0.10, 1.0)  # dark plum ink

var _display_name: String = ""
var _accent: Color = Color(1.00, 0.85, 0.32)


static func make(display_name: String, accent: Color) -> SkillPopup:
	var p: SkillPopup = SkillPopup.new()
	p._display_name = display_name
	p._accent = accent
	return p


func _ready() -> void:
	var banner: Label = Label.new()
	banner.text = _display_name
	banner.add_theme_font_size_override("font_size", FONT_SIZE_BANNER)
	banner.add_theme_color_override("font_color", _accent)
	banner.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	banner.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	banner.position = Vector2(-60.0, BANNER_OFFSET_Y - 10.0)
	banner.size = Vector2(120.0, 28.0)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(banner)
	scale = Vector2(0.5, 0.5)
	_animate()


func _animate() -> void:
	# Tree-bound tween per G-31 — survives BattleScene PROCESS_MODE_DISABLED.
	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	# Scale-in punch: 0.5× → 1.18× then settles
	tween.tween_property(self, "scale", Vector2(1.18, 1.18), SCALE_IN_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", position.y - DRIFT_DISTANCE, DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	var settle: Tween = get_tree().create_tween()
	settle.tween_interval(SCALE_IN_DURATION)
	settle.tween_property(self, "scale", Vector2(1.0, 1.0), 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	var fade: Tween = get_tree().create_tween()
	fade.tween_interval(FADE_DELAY)
	fade.tween_property(self, "modulate:a", 0.0, DURATION - FADE_DELAY) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fade.tween_callback(queue_free)
