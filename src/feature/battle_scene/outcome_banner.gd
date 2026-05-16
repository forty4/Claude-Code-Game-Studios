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
const SUBTITLE_FONT_SIZE: int = 28
const SUBTITLE_OUTLINE_SIZE: int = 4
## Gap between main label baseline and subtitle top, in pixels.
const SUBTITLE_GAP: float = 12.0

## Outcome → label text. Korean per project locale; the HUD already handles
## i18n via tr(); this banner is a single moment-of-truth grid cue and uses
## the canonical Korean glyphs directly.
const TEXT_VICTORY: String = "승리"
const TEXT_DEFEAT:  String = "패배"
const TEXT_DRAW:    String = "무승부"
const TEXT_DEFAULT: String = "결과"

## Session-34 — per-outcome subtitle text. Names WHICH win/loss condition
## resolved so the four VICTORY_* and three DEFEAT_* outcome types are not
## visually collapsed into identical "승리" / "패배" reveals. Korean glyphs
## direct per banner locale convention (i18n handled by HUD panel, not here).
const SUBTITLE_VICTORY_ANNIHILATION: String = "적 부대 전멸"
const SUBTITLE_VICTORY_SURVIVE:      String = "전선 사수"
const SUBTITLE_VICTORY_ESCORT:       String = "호위 성공"
const SUBTITLE_VICTORY_REACH_TILE:   String = "탈출 성공"
const SUBTITLE_DEFEAT_ANNIHILATION:  String = "아군 전멸"
const SUBTITLE_DEFEAT_ESCORT_LOST:   String = "호위 대상 사망"
const SUBTITLE_DEFEAT_REACH_FAILED:  String = "탈출 실패"
const SUBTITLE_DRAW:                 String = "턴 한도 도달"
const SUBTITLE_DEFAULT:              String = ""

## Color tier — offset from art-bible reserved 주홍/금색 channels.
const COLOR_VICTORY: Color = Color("e8d68a")  # warm yellow, NOT #D4A017
const COLOR_DEFEAT:  Color = Color("8a3a3a")  # deep maroon, NOT #C0392B
const COLOR_DRAW:    Color = Color("c8c0a8")  # neutral parchment
const COLOR_DEFAULT: Color = Color("c8c0a8")
const COLOR_OUTLINE: Color = Color(0.05, 0.04, 0.04, 1.0)

var _outcome: StringName = &""


## Outcome StringNames match the values emitted by GridBattleController._emit_battle_outcome:
## VICTORY_ANNIHILATION / VICTORY_SURVIVE / VICTORY_ESCORT / VICTORY_REACH_TILE /
## DEFEAT_ANNIHILATION / DEFEAT_ESCORT_LOST / DEFEAT_REACH_FAILED /
## TURN_LIMIT_REACHED. Other values fall through to the generic "결과" default.
## Session-28: VICTORY_SURVIVE added for SURVIVE_N_ROUNDS condition type.
## Session-30: VICTORY_ESCORT + DEFEAT_ESCORT_LOST added for ESCORT type.
## Session-31: VICTORY_REACH_TILE + DEFEAT_REACH_FAILED added for REACH_TILE.
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

	# Session-34 — subtitle naming the resolved condition (e.g., "호위 성공",
	# "탈출 실패"). Anchored to the parent vertical center with offset; sits
	# just below the main label's text baseline.
	var subtitle_text: String = _subtitle_for_outcome(_outcome)
	if not subtitle_text.is_empty():
		var subtitle: Label = Label.new()
		subtitle.anchor_left = 0.0
		subtitle.anchor_top = 0.5
		subtitle.anchor_right = 1.0
		subtitle.anchor_bottom = 0.5
		subtitle.offset_top = float(FONT_SIZE) * 0.5 + SUBTITLE_GAP
		subtitle.offset_bottom = subtitle.offset_top + float(SUBTITLE_FONT_SIZE) + 8.0
		subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		subtitle.vertical_alignment = VERTICAL_ALIGNMENT_TOP
		subtitle.text = subtitle_text
		subtitle.add_theme_font_size_override("font_size", SUBTITLE_FONT_SIZE)
		subtitle.add_theme_color_override("font_color", _color_for_outcome(_outcome))
		subtitle.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
		subtitle.add_theme_constant_override("outline_size", SUBTITLE_OUTLINE_SIZE)
		subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
		subtitle.name = "Subtitle"
		add_child(subtitle)

	# Production fallback: Tween writes have been observed not firing in
	# certain windowed Godot 4.6 sessions (slide tween dropped its callback +
	# its property writes never advanced). Set the final state instantly so
	# the banner is at least visible, then animate ON TOP of it. If the tween
	# never advances, the banner is still readable.
	modulate.a = 1.0
	label.position = Vector2.ZERO
	# Optional entrance flourish (drops + fades in). If the tween doesn't
	# fire, the banner stays at its final state thanks to the instant set above.
	modulate.a = 0.0
	label.position = Vector2(0.0, Y_DROP)
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, ENTRANCE_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", 0.0, ENTRANCE_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Failsafe: after tween duration + buffer, hard-set the final state so we
	# never end up with an invisible banner from a dropped tween.
	get_tree().create_timer(ENTRANCE_DURATION + 0.05).timeout.connect(func() -> void:
		if is_instance_valid(self):
			modulate.a = 1.0
			if is_instance_valid(label):
				label.position = Vector2.ZERO)


func _text_for_outcome(outcome: StringName) -> String:
	match outcome:
		&"VICTORY_ANNIHILATION": return TEXT_VICTORY
		&"VICTORY_SURVIVE":      return TEXT_VICTORY  # Session-28
		&"VICTORY_ESCORT":       return TEXT_VICTORY  # Session-30
		&"VICTORY_REACH_TILE":   return TEXT_VICTORY  # Session-31
		&"DEFEAT_ANNIHILATION":  return TEXT_DEFEAT
		&"DEFEAT_ESCORT_LOST":   return TEXT_DEFEAT   # Session-30
		&"DEFEAT_REACH_FAILED":  return TEXT_DEFEAT   # Session-31
		&"TURN_LIMIT_REACHED":   return TEXT_DRAW
		_:                       return TEXT_DEFAULT


func _color_for_outcome(outcome: StringName) -> Color:
	match outcome:
		&"VICTORY_ANNIHILATION": return COLOR_VICTORY
		&"VICTORY_SURVIVE":      return COLOR_VICTORY  # Session-28
		&"VICTORY_ESCORT":       return COLOR_VICTORY  # Session-30
		&"VICTORY_REACH_TILE":   return COLOR_VICTORY  # Session-31
		&"DEFEAT_ANNIHILATION":  return COLOR_DEFEAT
		&"DEFEAT_ESCORT_LOST":   return COLOR_DEFEAT   # Session-30
		&"DEFEAT_REACH_FAILED":  return COLOR_DEFEAT   # Session-31
		&"TURN_LIMIT_REACHED":   return COLOR_DRAW
		_:                       return COLOR_DEFAULT


## Session-34 — outcome-specific subtitle text. Returns "" for outcomes
## without a meaningful sub-label (e.g., the generic fallback case); the
## _ready() caller skips subtitle mount when empty so the legacy
## "결과" generic banner remains a single-line label.
func _subtitle_for_outcome(outcome: StringName) -> String:
	match outcome:
		&"VICTORY_ANNIHILATION": return SUBTITLE_VICTORY_ANNIHILATION
		&"VICTORY_SURVIVE":      return SUBTITLE_VICTORY_SURVIVE
		&"VICTORY_ESCORT":       return SUBTITLE_VICTORY_ESCORT
		&"VICTORY_REACH_TILE":   return SUBTITLE_VICTORY_REACH_TILE
		&"DEFEAT_ANNIHILATION":  return SUBTITLE_DEFEAT_ANNIHILATION
		&"DEFEAT_ESCORT_LOST":   return SUBTITLE_DEFEAT_ESCORT_LOST
		&"DEFEAT_REACH_FAILED":  return SUBTITLE_DEFEAT_REACH_FAILED
		&"TURN_LIMIT_REACHED":   return SUBTITLE_DRAW
		_:                       return SUBTITLE_DEFAULT
