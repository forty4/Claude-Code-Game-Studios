## ClassEmblem — small procedurally-drawn icon mounted as a child of each unit
## polygon. Reads at a glance as "this is a sword unit / a bow unit / a scroll
## unit." Six glyphs, one per UnitRole.UnitClass enum.
##
## Session-16: also draws a small per-hero overlay symbol on top of the class
## base when `hero_id` is supplied — 큰 귀 (유비), 수염 (관우/장비), 활 위 백발
## (황충), 꽃 (초선), 깃 (조조), 안대 (하후돈), 번개 (장요), 사각 진영 (우금),
## 산봉우리 (허저), 푸른 보주 (손권), 부채 (주유), 별 (여포). Heroes without
## an authored overlay just show the class base.
##
## Construction: `ClassEmblem.make(unit_class, side, counter_rotation, hero_id)`.
## Sided so the glyph contrasts against the faction fill — player units use a
## warm ink, enemy units use a cooler bone color (both readable on their
## respective fills).
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
## Hero-specific overlay color (HERO_ACCENT_BY_HERO_ID-derived). Defaults to
## _color_accent if not supplied via make(). The overlay layer sits on top of
## the class base so the hero mark reads as a "personal seal" stamped on the
## class glyph.
var _color_overlay: Color = Color(0.98, 0.92, 0.74, 0.95)
var _hero_id: StringName = &""


## `unit_class` matches UnitRole.UnitClass enum (CAVALRY=0 / INFANTRY=1 / ARCHER=2
## / STRATEGIST=3 / COMMANDER=4 / SCOUT=5). `side` 0 = player (dark ink on light
## faction blue), 1 = enemy (bone on dark charcoal). `hero_id` is optional —
## when supplied, a per-hero overlay symbol is drawn on top of the class base.
static func make(unit_class: int, side: int, counter_rotation: float,
		hero_id: StringName = &"", hero_accent: Color = Color(0, 0, 0, 0)) -> ClassEmblem:
	var emblem: ClassEmblem = ClassEmblem.new()
	emblem._unit_class = unit_class
	emblem._counter_rotation = counter_rotation
	emblem._hero_id = hero_id
	if side == 0:
		# Dark ink reads on the light periwinkle faction fill.
		emblem._color_main = Color(0.10, 0.08, 0.06, 0.95)
		emblem._color_accent = Color(0.98, 0.92, 0.74, 0.95)
	else:
		# Bone reads on the charcoal enemy fill.
		emblem._color_main = Color(0.94, 0.90, 0.78, 0.95)
		emblem._color_accent = Color(0.30, 0.22, 0.16, 0.95)
	# Hero overlay tint — supplied accent or fall back to the side-default accent.
	if hero_accent.a > 0.0:
		# Boost saturation slightly so the overlay reads against any background.
		emblem._color_overlay = hero_accent.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.15)
		emblem._color_overlay.a = 0.98
	else:
		emblem._color_overlay = emblem._color_accent
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
	# Per-hero overlay symbol drawn on top of the class base. No-op for heroes
	# without an authored entry — those just show the class emblem.
	if _hero_id != &"":
		_draw_hero_overlay()


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


# ─── Per-hero overlay symbols ────────────────────────────────────────────────
#
# Each overlay is 1-3 simple draw ops sized ~6-8px, drawn in the upper-right
# corner of the emblem so the class base stays readable. Heroes that don't
# match any case fall through with no overlay (just the class glyph).
func _draw_hero_overlay() -> void:
	match _hero_id:
		&"shu_001_liu_bei":      _overlay_long_ears()       # 유비 — 큰 귀
		&"shu_002_guan_yu":      _overlay_long_beard()      # 관우 — 긴 수염
		&"shu_003_zhang_fei":    _overlay_thick_beard()     # 장비 — 텁수룩 수염
		&"shu_004_huang_zhong":  _overlay_white_hair()      # 황충 — 백발 (3 흰 점)
		&"wei_001_cao_cao":      _overlay_feather()         # 조조 — 깃털
		&"wei_005_xiahou_dun":   _overlay_eyepatch()        # 하후돈 — 안대 (X)
		&"wei_006_zhang_liao":   _overlay_lightning()       # 장요 — 번개
		&"wei_007_yu_jin":       _overlay_square_formation() # 우금 — 사각 진영
		&"wei_008_xu_chu":       _overlay_mountain()        # 허저 — 산봉우리
		&"wu_001_sun_quan":      _overlay_blue_orb()        # 손권 — 푸른 보주
		&"wu_003_zhou_yu":       _overlay_fan()             # 주유 — 부채
		&"qun_001_lu_bu":        _overlay_star()            # 여포 — 별
		&"qun_004_diao_chan":    _overlay_flower()          # 초선 — 꽃
		_:
			pass


## Helper: returns a Vector2 in the upper-right quadrant where overlay marks
## sit so they don't collide with the class base center.
func _overlay_anchor() -> Vector2:
	return Vector2(_SIZE * 0.55, -_SIZE * 0.7)


## 유비 — 2 small crescents flanking the head pos (자비롭고 큰 귀).
func _overlay_long_ears() -> void:
	var s: float = _SIZE
	# Two small filled circles at top, framing the class emblem's apex.
	draw_circle(Vector2(-s * 0.65, -s * 0.55), s * 0.18, _color_overlay)
	draw_circle(Vector2(s * 0.65, -s * 0.55), s * 0.18, _color_overlay)


## 관우 — 긴 수염 (long beard): 3 vertical strands below center.
func _overlay_long_beard() -> void:
	var s: float = _SIZE
	for x: float in [-s * 0.18, 0.0, s * 0.18]:
		draw_line(Vector2(x, s * 0.25), Vector2(x + s * 0.03, s * 0.95),
			_color_overlay, _STROKE * 0.7, true)


## 장비 — 텁수룩 수염 (wide bushy beard): thick zigzag along bottom.
func _overlay_thick_beard() -> void:
	var s: float = _SIZE
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(-s * 0.55, s * 0.55),
		Vector2(-s * 0.25, s * 0.85),
		Vector2(0.0, s * 0.55),
		Vector2(s * 0.25, s * 0.85),
		Vector2(s * 0.55, s * 0.55),
	])
	draw_polyline(pts, _color_overlay, _STROKE * 1.1, true)


## 황충 — 백발 (3 white dots above the class emblem head; reads as elderly).
func _overlay_white_hair() -> void:
	var s: float = _SIZE
	var white: Color = Color(0.95, 0.95, 0.95, 0.98)
	for x: float in [-s * 0.35, 0.0, s * 0.35]:
		draw_circle(Vector2(x, -s * 0.95), s * 0.12, white)


## 조조 — 깃털 (small feather angle near the upper-right of the emblem).
func _overlay_feather() -> void:
	var a: Vector2 = _overlay_anchor()
	var tip: Vector2 = a + Vector2(_SIZE * 0.42, -_SIZE * 0.42)
	draw_line(a, tip, _color_overlay, _STROKE, true)
	# Little barbs along the spine
	for t: float in [0.3, 0.55, 0.8]:
		var p: Vector2 = a.lerp(tip, t)
		var perp: Vector2 = (tip - a).rotated(PI * 0.5).normalized() * _SIZE * 0.18
		draw_line(p, p + perp, _color_overlay, _STROKE * 0.6, true)


## 하후돈 — 안대 (eyepatch as an X mark over the upper-right area).
func _overlay_eyepatch() -> void:
	var c: Vector2 = _overlay_anchor() + Vector2(-_SIZE * 0.15, _SIZE * 0.15)
	var r: float = _SIZE * 0.28
	# X mark: two crossed strokes
	draw_line(c + Vector2(-r, -r), c + Vector2(r, r), _color_overlay, _STROKE, true)
	draw_line(c + Vector2(-r, r), c + Vector2(r, -r), _color_overlay, _STROKE, true)


## 장요 — 번개 (lightning zigzag in upper-right corner).
func _overlay_lightning() -> void:
	var a: Vector2 = _overlay_anchor()
	var pts: PackedVector2Array = PackedVector2Array([
		a + Vector2(-_SIZE * 0.05, -_SIZE * 0.30),
		a + Vector2(_SIZE * 0.20, -_SIZE * 0.05),
		a + Vector2(_SIZE * 0.00, _SIZE * 0.05),
		a + Vector2(_SIZE * 0.30, _SIZE * 0.35),
	])
	draw_polyline(pts, _color_overlay, _STROKE * 0.95, true)


## 우금 — 사각 진영 (small square frame; discipline / formation).
func _overlay_square_formation() -> void:
	var a: Vector2 = _overlay_anchor()
	var r: float = _SIZE * 0.26
	var rect: PackedVector2Array = PackedVector2Array([
		a + Vector2(-r, -r), a + Vector2(r, -r),
		a + Vector2(r, r), a + Vector2(-r, r),
	])
	draw_polyline(rect, _color_overlay, _STROKE * 0.8, true)
	# Closing edge for the polyline (not closed by default).
	draw_line(rect[3], rect[0], _color_overlay, _STROKE * 0.8, true)


## 허저 — 산봉우리 (mountain silhouette: 3 peaks).
func _overlay_mountain() -> void:
	var a: Vector2 = _overlay_anchor()
	var pts: PackedVector2Array = PackedVector2Array([
		a + Vector2(-_SIZE * 0.40, _SIZE * 0.25),
		a + Vector2(-_SIZE * 0.20, -_SIZE * 0.10),
		a + Vector2(-_SIZE * 0.05, _SIZE * 0.05),
		a + Vector2(_SIZE * 0.15, -_SIZE * 0.30),
		a + Vector2(_SIZE * 0.30, _SIZE * 0.05),
		a + Vector2(_SIZE * 0.45, _SIZE * 0.25),
	])
	draw_polyline(pts, _color_overlay, _STROKE * 0.95, true)


## 손권 — 푸른 보주 (small blue filled circle — said to have blue eyes in lore).
func _overlay_blue_orb() -> void:
	var c: Vector2 = _overlay_anchor()
	var blue: Color = Color(0.36, 0.66, 0.95, 0.98)
	draw_circle(c, _SIZE * 0.22, blue)


## 주유 — 부채 (small folding fan: a fan of 3 spokes from a base).
func _overlay_fan() -> void:
	var base: Vector2 = _overlay_anchor() + Vector2(0.0, _SIZE * 0.15)
	for theta: float in [-PI * 0.45, -PI * 0.25, -PI * 0.05]:
		var v: Vector2 = Vector2(cos(theta), sin(theta)) * _SIZE * 0.42
		draw_line(base, base + v, _color_overlay, _STROKE * 0.85, true)


## 여포 — 별 (4-pointed star, peerless warrior accent).
func _overlay_star() -> void:
	var c: Vector2 = _overlay_anchor()
	var r: float = _SIZE * 0.32
	# Horizontal + vertical strokes form a 4-point star.
	draw_line(c + Vector2(-r, 0.0), c + Vector2(r, 0.0), _color_overlay, _STROKE * 0.9, true)
	draw_line(c + Vector2(0.0, -r), c + Vector2(0.0, r), _color_overlay, _STROKE * 0.9, true)
	# Diagonal cross at half radius for a starburst feel
	var d: float = r * 0.55
	draw_line(c + Vector2(-d, -d), c + Vector2(d, d), _color_overlay, _STROKE * 0.55, true)
	draw_line(c + Vector2(-d, d), c + Vector2(d, -d), _color_overlay, _STROKE * 0.55, true)


## 초선 — 꽃 (5-petal flower; 4 cardinal + center).
func _overlay_flower() -> void:
	var c: Vector2 = _overlay_anchor()
	var r: float = _SIZE * 0.22
	# Center bud
	draw_circle(c, _SIZE * 0.10, _color_overlay)
	# 4 petals at cardinals
	for v: Vector2 in [Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)]:
		draw_circle(c + v, _SIZE * 0.10, _color_overlay)
