## UnitHpBar — thin HP indicator drawn above a unit polygon.
##
## Mounted as a Node2D child of the unit's Polygon2D in ChapterVisuals/PlayerUnits
## or /EnemyUnits. Inherits transform + visibility from its parent polygon, so
## movement repositions the bar automatically and hiding the polygon (death)
## hides the bar via the standard CanvasItem visibility cascade.
##
## Color tiers per art-bible §3-3 "기능 정보는 항상 직선" — solid blocks, no
## gradients; threshold-coded green ≥50% / yellow ≥25% / red below.
class_name UnitHpBar
extends Node2D

const BAR_WIDTH: float = 40.0
const BAR_HEIGHT: float = 5.0
## Y-offset above the polygon center. _UNIT_HALF in ChapterVisuals is 20, so
## -28 sits 8px above the silhouette's top edge.
const BAR_OFFSET_Y: float = -28.0

const COLOR_BG: Color = Color(0.10, 0.10, 0.12, 0.85)
const COLOR_BORDER: Color = Color(0.11, 0.10, 0.09)
const COLOR_HIGH: Color = Color(0.30, 0.75, 0.35)  # ≥50% — green
const COLOR_MID:  Color = Color(0.85, 0.70, 0.25)  # ≥25% — yellow
const COLOR_LOW:  Color = Color(0.80, 0.25, 0.20)  # <25% — red

var _current: int = 1
var _max: int = 1


func _ready() -> void:
	position = Vector2(0.0, BAR_OFFSET_Y)


## Updates the bar's displayed HP. max_hp is clamped to >= 1 to avoid div-by-zero;
## current is clamped to [0, max_hp]. Triggers a redraw.
func set_hp(current: int, max_hp: int) -> void:
	_max = maxi(1, max_hp)
	_current = clampi(current, 0, _max)
	queue_redraw()


func _draw() -> void:
	var bg_rect: Rect2 = Rect2(
		Vector2(-BAR_WIDTH / 2.0, -BAR_HEIGHT / 2.0),
		Vector2(BAR_WIDTH, BAR_HEIGHT),
	)
	draw_rect(bg_rect, COLOR_BG, true)

	var pct: float = clampf(float(_current) / float(_max), 0.0, 1.0)
	if pct > 0.0:
		var fg_color: Color = COLOR_LOW
		if pct >= 0.5:
			fg_color = COLOR_HIGH
		elif pct >= 0.25:
			fg_color = COLOR_MID
		var fg_rect: Rect2 = Rect2(
			Vector2(-BAR_WIDTH / 2.0, -BAR_HEIGHT / 2.0),
			Vector2(BAR_WIDTH * pct, BAR_HEIGHT),
		)
		draw_rect(fg_rect, fg_color, true)

	draw_rect(bg_rect, COLOR_BORDER, false, 1.0)
