## OutcomeBanner — large screen-centered "승리 / 패배 / 무승부" reveal on
## `battle_outcome_resolved`. Mounted on HUDLayer alongside BattleHUD's
## results panel; the banner is the grid-level cue, the HUD panel is the
## stats sheet.
##
## Construction: use static `make(outcome: StringName)`; do NOT call .new()
## directly because outcome text + color must resolve before _ready builds
## the label and starts the entrance tween.
##
## Color palette respects art-bible §1: the reserved 주홍 #C0392B and 금색
## #D4A017 are destiny-branch reveal channels and MUST NOT appear here.
## Banner colors are deliberately offset from those exact values.
class_name OutcomeBanner
extends Control

const ENTRANCE_DURATION: float = 0.3
const Y_DROP: float = 30.0
const FONT_SIZE: int = 64
const OUTLINE_SIZE: int = 6

## Outcome → label text. Korean per project locale; the HUD already handles
## i18n via tr(); this banner is a single moment-of-truth grid cue and uses
## the canonical Korean glyphs directly.
const TEXT_VICTORY: String = "승리"
const TEXT_DEFEAT:  String = "패배"
const TEXT_DRAW:    String = "무승부"
const TEXT_DEFAULT: String = "결과"

## Color tier — offset from art-bible reserved 주홍/금색 channels.
const COLOR_VICTORY: Color = Color("e8d68a")  # warm yellow, NOT #D4A017
const COLOR_DEFEAT:  Color = Color("8a3a3a")  # deep maroon, NOT #C0392B
const COLOR_DRAW:    Color = Color("c8c0a8")  # neutral parchment
const COLOR_DEFAULT: Color = Color("c8c0a8")
const COLOR_OUTLINE: Color = Color(0.05, 0.04, 0.04, 1.0)

var _outcome: StringName = &""


## Outcome StringNames match the values emitted by GridBattleController._emit_battle_outcome:
## VICTORY_ANNIHILATION / DEFEAT_ANNIHILATION / TURN_LIMIT_REACHED. Other values
## fall through to the generic "결과" default.
static func make(outcome: StringName) -> OutcomeBanner:
	var b: OutcomeBanner = OutcomeBanner.new()
	b._outcome = outcome
	return b


func _ready() -> void:
	# Fill the parent (HUDLayer) so the centered Label centers on the viewport.
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var label: Label = Label.new()
	label.anchor_left = 0.0
	label.anchor_top = 0.0
	label.anchor_right = 1.0
	label.anchor_bottom = 1.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = _text_for_outcome(_outcome)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", _color_for_outcome(_outcome))
	label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	label.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)

	# Entrance: drop in from +30y, fade alpha 0 → 1.
	modulate.a = 0.0
	label.position = Vector2(0.0, Y_DROP)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, ENTRANCE_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", 0.0, ENTRANCE_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _text_for_outcome(outcome: StringName) -> String:
	match outcome:
		&"VICTORY_ANNIHILATION": return TEXT_VICTORY
		&"DEFEAT_ANNIHILATION":  return TEXT_DEFEAT
		&"TURN_LIMIT_REACHED":   return TEXT_DRAW
		_:                       return TEXT_DEFAULT


func _color_for_outcome(outcome: StringName) -> Color:
	match outcome:
		&"VICTORY_ANNIHILATION": return COLOR_VICTORY
		&"DEFEAT_ANNIHILATION":  return COLOR_DEFEAT
		&"TURN_LIMIT_REACHED":   return COLOR_DRAW
		_:                       return COLOR_DEFAULT
