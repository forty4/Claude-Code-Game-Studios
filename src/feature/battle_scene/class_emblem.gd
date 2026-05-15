## ClassEmblem — small procedurally-drawn icon mounted as a child of each unit
## polygon. Reads at a glance as "this is a sword unit / a bow unit / a scroll
## unit." Six glyphs, one per UnitRole.UnitClass enum.
##
## Construction: `ClassEmblem.make(unit_class, side)`. Sided so the glyph
## contrasts against the faction fill — player units use a warm ink, enemy
## units use a cooler bone color (both readable on their respective fills).
##
## Drawn via Node2D._draw() so the parent polygon's modulate cascade carries
## the emblem through damage_flash / death_fade / round-dim animations.
class_name ClassEmblem
extends Node2D

const _SIZE: float = 14.0  # emblem outer half-extent in px; polygon ≈ 40×40
const _STROKE: float = 1.8

## Counter-rotation against the parent polygon's facing rotation so the glyph
## always reads upright. Set at make() time from the same rotation_for_facing
## value chapter_visuals applies to the polygon. Re-apply if the polygon is
## re-rotated mid-game (currently it isn't).
var _counter_rotation: float = 0.0
var _unit_class: int = -1
var _color_main: Color = Color(0.08, 0.06, 0.05, 0.95)
var _color_accent: Color = Color(0.92, 0.86, 0.72, 0.95)


## `unit_class` matches UnitRole.UnitClass enum (CAVALRY=0 / INFANTRY=1 / ARCHER=2
## / STRATEGIST=3 / COMMANDER=4 / SCOUT=5). `side` 0 = player (dark ink on light
## faction blue), 1 = enemy (bone on dark charcoal).
static func make(unit_class: int, side: int, counter_rotation: float) -> ClassEmblem:
	var emblem: ClassEmblem = ClassEmblem.new()
	emblem._unit_class = unit_class
	emblem._counter_rotation = counter_rotation
	if side == 0:
		# Dark ink reads on the light periwinkle faction fill.
		emblem._color_main = Color(0.10, 0.08, 0.06, 0.95)
		emblem._color_accent = Color(0.98, 0.92, 0.74, 0.95)
	else:
		# Bone reads on the charcoal enemy fill.
		emblem._color_main = Color(0.94, 0.90, 0.78, 0.95)
		emblem._color_accent = Color(0.30, 0.22, 0.16, 0.95)
	emblem.rotation = counter_rotation
	return emblem


func _draw() -> void:
	match _unit_class:
		0: _draw_cavalry_spear()
		1: _draw_infantry_shield()
		2: _draw_archer_bow()
		3: _draw_strategist_scroll()
		4: _draw_commander_crown()
		5: _draw_scout_dagger()
		_: _draw_infantry_shield()


## CAVALRY — diagonal spear: shaft from bottom-left to top-right, arrow head at top.
func _draw_cavalry_spear() -> void:
	var s: float = _SIZE
	var tail: Vector2 = Vector2(-s * 0.7, s * 0.7)
	var head: Vector2 = Vector2(s * 0.7, -s * 0.7)
	draw_line(tail, head, _color_main, _STROKE + 0.6, true)
	# Arrow head (small triangle at the tip)
	var tip_a: Vector2 = head + Vector2(-s * 0.42, -s * 0.04)
	var tip_b: Vector2 = head + Vector2(-s * 0.04, -s * 0.42)
	draw_line(head, tip_a, _color_main, _STROKE, true)
	draw_line(head, tip_b, _color_main, _STROKE, true)
	# Spear tassel near the grip
	draw_circle(tail + Vector2(s * 0.18, -s * 0.18), s * 0.16, _color_accent)


## INFANTRY — broad shield with a cross. Reads as "front line / tank".
func _draw_infantry_shield() -> void:
	var s: float = _SIZE
	# Shield outline (rounded-top rect)
	var shield_pts: PackedVector2Array = PackedVector2Array([
		Vector2(-s * 0.8, -s * 0.7),
		Vector2(s * 0.8, -s * 0.7),
		Vector2(s * 0.8, s * 0.2),
		Vector2(0.0, s * 0.85),
		Vector2(-s * 0.8, s * 0.2),
	])
	draw_colored_polygon(shield_pts, _color_main)
	# Cross in accent
	draw_line(Vector2(0, -s * 0.5), Vector2(0, s * 0.55), _color_accent, _STROKE, true)
	draw_line(Vector2(-s * 0.5, -s * 0.1), Vector2(s * 0.5, -s * 0.1), _color_accent, _STROKE, true)


## ARCHER — bow with arrow nocked. Curve drawn as a 9-segment polyline.
func _draw_archer_bow() -> void:
	var s: float = _SIZE
	# Bow curve: half-ellipse opening to the right
	var pts: PackedVector2Array = PackedVector2Array()
	var seg: int = 10
	for i: int in range(seg + 1):
		var t: float = float(i) / float(seg)
		var theta: float = lerp(-PI * 0.55, PI * 0.55, t)
		pts.append(Vector2(cos(theta) * -s * 0.75, sin(theta) * s * 0.85))
	draw_polyline(pts, _color_main, _STROKE + 0.4, true)
	# Bowstring (straight chord between the bow tips)
	draw_line(pts[0], pts[seg], _color_main, _STROKE * 0.6, true)
	# Arrow shaft (horizontal, slight rightward)
	draw_line(Vector2(-s * 0.3, 0), Vector2(s * 0.9, 0), _color_accent, _STROKE, true)
	# Arrow head
	draw_line(Vector2(s * 0.9, 0), Vector2(s * 0.55, -s * 0.22), _color_accent, _STROKE, true)
	draw_line(Vector2(s * 0.9, 0), Vector2(s * 0.55, s * 0.22), _color_accent, _STROKE, true)


## STRATEGIST — partially-unrolled scroll. Two horizontal rolls + a body rect.
func _draw_strategist_scroll() -> void:
	var s: float = _SIZE
	# Scroll body
	var body: Rect2 = Rect2(Vector2(-s * 0.6, -s * 0.45), Vector2(s * 1.2, s * 0.9))
	draw_rect(body, _color_accent, true)
	# Top + bottom rolls (rounded ends, drawn as filled circles flattened by overlap)
	for y: float in [-s * 0.45, s * 0.45]:
		draw_line(Vector2(-s * 0.75, y), Vector2(s * 0.75, y), _color_main, _STROKE + 1.0, true)
	# Three "text lines" inside the scroll
	for y: float in [-s * 0.2, 0.0, s * 0.2]:
		draw_line(Vector2(-s * 0.4, y), Vector2(s * 0.4, y), _color_main, _STROKE * 0.6, true)


## COMMANDER — crown with 3 spikes + headband.
func _draw_commander_crown() -> void:
	var s: float = _SIZE
	# Crown body (three triangular spikes connected by a flat base)
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(-s * 0.8, s * 0.2),
		Vector2(-s * 0.55, -s * 0.55),
		Vector2(-s * 0.3, s * 0.05),
		Vector2(0.0, -s * 0.75),  # tallest middle spike
		Vector2(s * 0.3, s * 0.05),
		Vector2(s * 0.55, -s * 0.55),
		Vector2(s * 0.8, s * 0.2),
		Vector2(s * 0.8, s * 0.5),
		Vector2(-s * 0.8, s * 0.5),
	])
	draw_colored_polygon(pts, _color_main)
	# Headband line + center jewel
	draw_line(Vector2(-s * 0.8, s * 0.32), Vector2(s * 0.8, s * 0.32), _color_accent, _STROKE * 0.7, true)
	draw_circle(Vector2(0, s * 0.4), s * 0.13, _color_accent)


## SCOUT — diagonal dagger with crossguard.
func _draw_scout_dagger() -> void:
	var s: float = _SIZE
	# Blade: thin diagonal line from lower-left to upper-right
	var hilt: Vector2 = Vector2(-s * 0.5, s * 0.5)
	var tip: Vector2 = Vector2(s * 0.6, -s * 0.6)
	draw_line(hilt, tip, _color_main, _STROKE + 0.4, true)
	# Crossguard perpendicular to the blade near the hilt
	var perp: Vector2 = (tip - hilt).rotated(PI * 0.5).normalized() * s * 0.30
	draw_line(hilt + perp, hilt - perp, _color_accent, _STROKE + 0.2, true)
	# Pommel (small circle at the very butt of the hilt)
	draw_circle(hilt + (hilt - tip).normalized() * s * 0.18, s * 0.13, _color_accent)
