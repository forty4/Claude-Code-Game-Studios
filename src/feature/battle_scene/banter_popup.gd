## BanterPopup — short-lived speech bubble for hero personality lines.
##
## Self-animating Node2D: scales in from 0.5×, drifts up, holds, then fades.
## Sibling to CriticalPopup / KillPopup / SkillPopup pattern. Spawned at
## hero polygon position by battle_scene on banter events (battle_start /
## player_kill / low_hp / outcome_win / outcome_loss).
##
## Construction: `BanterPopup.make(line, accent_color)`.
## line: Korean banter text (single short sentence).
## accent_color: hero accent color so speaker identity reads at a glance.
class_name BanterPopup
extends Node2D

const DRIFT_DISTANCE: float = 28.0
const DURATION: float = 2.00
const SCALE_IN_DURATION: float = 0.14
const FADE_DELAY: float = 1.50
const FONT_SIZE_LINE: int = 16
const OUTLINE_SIZE: int = 4
const BANNER_OFFSET_Y: float = -36.0
const BANNER_WIDTH: float = 220.0
const BANNER_HEIGHT: float = 24.0

const COLOR_OUTLINE: Color = Color(0.06, 0.04, 0.10, 1.0)  # dark plum ink

var _line: String = ""
var _accent: Color = Color(1.00, 0.85, 0.32)


static func make(line: String, accent: Color) -> BanterPopup:
	var p: BanterPopup = BanterPopup.new()
	p._line = line
	p._accent = accent
	return p


func _ready() -> void:
	var banner: Label = Label.new()
	banner.text = _line
	banner.add_theme_font_size_override("font_size", FONT_SIZE_LINE)
	banner.add_theme_color_override("font_color", _accent)
	banner.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	banner.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	banner.position = Vector2(-BANNER_WIDTH / 2.0, BANNER_OFFSET_Y - BANNER_HEIGHT / 2.0)
	banner.size = Vector2(BANNER_WIDTH, BANNER_HEIGHT)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(banner)
	scale = Vector2(0.5, 0.5)
	_animate()


func _animate() -> void:
	# Tree-bound tween per G-31 — survives BattleScene PROCESS_MODE_DISABLED.
	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(1.10, 1.10), SCALE_IN_DURATION) \
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
