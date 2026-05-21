## CriticalPopup — short-lived "치명타!" banner for REAR-direction hits.
##
## Self-animating Node2D: scales in from 0.5×, drifts up 36px, holds briefly,
## then fades to transparent over DURATION and queue_frees. Parented to
## ChapterVisuals (NOT the defender's polygon) so the popup survives the
## polygon being hidden by death feedback. Sibling to DamagePopup.
##
## Construction: `CriticalPopup.make(damage)`; spawned at the defender's
## position by battle_scene when grid_battle_controller emits
## critical_hit_landed.
class_name CriticalPopup
extends Node2D

const DRIFT_DISTANCE: float = 36.0
const DURATION: float = 0.95
const SCALE_IN_DURATION: float = 0.12
const FADE_DELAY: float = 0.55
const FONT_SIZE_BANNER: int = 22
const FONT_SIZE_DAMAGE: int = 26
const OUTLINE_SIZE: int = 5
const BANNER_OFFSET_Y: float = -18.0
const DAMAGE_OFFSET_Y: float = -42.0

## Saturated gold-amber + crimson outline reads as "big deal" without
## clashing with the standard red DamagePopup that fires at the same time.
const COLOR_BANNER:  Color = Color(1.00, 0.85, 0.32)  # warm gold
const COLOR_DAMAGE:  Color = Color(1.00, 0.42, 0.20)  # vivid red-orange
const COLOR_OUTLINE: Color = Color(0.32, 0.04, 0.04, 1.0)  # dark crimson ink

var _damage: int = 0
var _chain_level: int = 1  # 1 = first CRIT this round (no badge); 2+ = chain badge


static func make(damage: int, chain_level: int = 1) -> CriticalPopup:
	var p: CriticalPopup = CriticalPopup.new()
	p._damage = damage
	p._chain_level = chain_level
	return p


func _ready() -> void:
	# Banner label — "치명타!" or "치명타 ×N!" when chain ≥ 2 (S72 chain bonus).
	var banner: Label = Label.new()
	banner.text = "치명타!" if _chain_level <= 1 else "치명타 ×%d!" % _chain_level
	banner.add_theme_font_size_override("font_size", FONT_SIZE_BANNER)
	banner.add_theme_color_override("font_color", COLOR_BANNER)
	banner.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	banner.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	banner.position = Vector2(-40.0, BANNER_OFFSET_Y - 10.0)
	banner.size = Vector2(80.0, 24.0)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(banner)
	# Damage label — bigger than the normal DamagePopup since this IS the big hit.
	var dmg: Label = Label.new()
	dmg.text = "-%d" % _damage
	dmg.add_theme_font_size_override("font_size", FONT_SIZE_DAMAGE)
	dmg.add_theme_color_override("font_color", COLOR_DAMAGE)
	dmg.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	dmg.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	dmg.position = Vector2(-40.0, DAMAGE_OFFSET_Y - 14.0)
	dmg.size = Vector2(80.0, 28.0)
	dmg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dmg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(dmg)
	scale = Vector2(0.5, 0.5)
	_animate()


func _animate() -> void:
	# Tree-bound tween per G-31 — survives BattleScene PROCESS_MODE_DISABLED.
	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	# Scale-in punch: 0.5× → 1.15× → 1.0×
	tween.tween_property(self, "scale", Vector2(1.15, 1.15), SCALE_IN_DURATION) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Drift up over full duration
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
