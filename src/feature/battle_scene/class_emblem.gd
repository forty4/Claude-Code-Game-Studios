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

const _SIZE: float = 14.0  # class emblem outer half-extent in px; polygon ≈ 52×52
const _STROKE: float = 1.8

## Session-16 amendment: hero overlay scale-up. Original overlays at ~0.2*_SIZE
## (3-6px features) were invisible against the larger class emblem. Hero
## symbols now render at HERO_OVERLAY_SIZE (close to the polygon half-extent
## minus class emblem half-extent) so they read as a clear secondary identifier
## next to the class glyph.
const _HERO_OVERLAY_SIZE: float = 11.0
## Class emblem shrink factor when a hero overlay is present. Demotes the
## class glyph to a small corner badge so the hero overlay can take the
## primary visual focus. 1.0 = full size (no hero overlay), 0.55 = shrunk.
const _CLASS_SHRINK_WITH_OVERLAY: float = 0.55
## Class emblem corner offset when shrunk — bottom-right of the polygon so the
## hero overlay can occupy the upper area unobstructed.
const _CLASS_CORNER_OFFSET: Vector2 = Vector2(10.0, 10.0)
## Hero overlay center offset — slightly upper-left of polygon center so the
## class emblem badge can sit lower-right without overlap.
const _HERO_OVERLAY_CENTER: Vector2 = Vector2(-3.0, -4.0)

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
	# Use the saturated accent directly (no lerp) so the hero mark pops against
	# the class emblem badge underneath.
	if hero_accent.a > 0.0:
		emblem._color_overlay = hero_accent
		emblem._color_overlay.a = 0.98
	else:
		emblem._color_overlay = emblem._color_accent
	emblem.rotation = counter_rotation
	return emblem


func _draw() -> void:
	# When a hero overlay is authored, shrink + offset the class emblem so the
	# hero mark can take the primary visual focus. Without an overlay, the
	# class emblem renders at full size centered.
	var has_overlay: bool = _hero_id != &"" and _has_hero_overlay(_hero_id)
	if has_overlay:
		draw_set_transform(_CLASS_CORNER_OFFSET, 0.0,
			Vector2(_CLASS_SHRINK_WITH_OVERLAY, _CLASS_SHRINK_WITH_OVERLAY))
	match _unit_class:
		0: _draw_cavalry_spear()
		1: _draw_infantry_shield()
		2: _draw_archer_bow()
		3: _draw_strategist_scroll()
		4: _draw_commander_crown()
		5: _draw_scout_dagger()
		_: _draw_infantry_shield()
	if has_overlay:
		# Reset transform before drawing the overlay at full scale.
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		_draw_hero_overlay()


## Hero IDs with an authored overlay. Kept in sync with `_draw_hero_overlay`'s
## match arms below — if you add a new overlay case, append the hero_id here.
const _OVERLAY_HERO_IDS: Array[StringName] = [
	&"shu_001_liu_bei", &"shu_002_guan_yu", &"shu_003_zhang_fei",
	&"shu_004_huang_zhong", &"wei_001_cao_cao", &"wei_005_xiahou_dun",
	&"wei_006_zhang_liao", &"wei_007_yu_jin", &"wei_008_xu_chu",
	&"wu_001_sun_quan", &"wu_003_zhou_yu", &"qun_001_lu_bu",
	&"qun_004_diao_chan",
]


## Returns true if `hero_id` matches one of the authored overlay cases below.
func _has_hero_overlay(hero_id: StringName) -> bool:
	return hero_id in _OVERLAY_HERO_IDS


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


## Helper: hero overlay drawing anchor (slightly upper-left of polygon center
## to give the lower-right class emblem badge breathing room).
func _overlay_anchor() -> Vector2:
	return _HERO_OVERLAY_CENTER


## Stroke width for hero overlays — chunkier than the class emblem so the hero
## mark reads at first glance against the class glyph + faction fill.
func _overlay_stroke() -> float:
	return _STROKE + 0.6


## Renders a thin contrasting backing stroke beneath the overlay's main color
## so it stays legible regardless of the faction fill underneath. Side-aware:
## player units (light faction) get dark backing, enemy units (dark faction)
## get light backing.
func _overlay_backing() -> Color:
	# _color_main is already side-aware (dark for player, bone for enemy);
	# reuse it with a touch of alpha to keep the backing subtle.
	var c: Color = _color_main
	c.a = 0.85
	return c


## 유비 — 큰 귀 (large crescent ears framing the head). Two filled circles
## flanking the upper area, large enough to read past the class emblem badge.
func _overlay_long_ears() -> void:
	var s: float = _HERO_OVERLAY_SIZE
	var c: Vector2 = _overlay_anchor()
	draw_circle(c + Vector2(-s, -s * 0.30), s * 0.55, _overlay_backing())
	draw_circle(c + Vector2(s, -s * 0.30), s * 0.55, _overlay_backing())
	draw_circle(c + Vector2(-s, -s * 0.30), s * 0.40, _color_overlay)
	draw_circle(c + Vector2(s, -s * 0.30), s * 0.40, _color_overlay)


## 관우 — 긴 수염 (3 flowing strands below center). Drawn longer + bolder.
func _overlay_long_beard() -> void:
	var s: float = _HERO_OVERLAY_SIZE
	var c: Vector2 = _overlay_anchor()
	for x_off: float in [-s * 0.55, 0.0, s * 0.55]:
		var top: Vector2 = c + Vector2(x_off, s * 0.10)
		var bot: Vector2 = c + Vector2(x_off + s * 0.10, s * 1.10)
		draw_line(top, bot, _overlay_backing(), _overlay_stroke() + 1.2, true)
		draw_line(top, bot, _color_overlay, _overlay_stroke(), true)


## 장비 — 텁수룩 수염 (wide bushy zigzag beard, very prominent).
func _overlay_thick_beard() -> void:
	var s: float = _HERO_OVERLAY_SIZE
	var c: Vector2 = _overlay_anchor()
	var pts: PackedVector2Array = PackedVector2Array([
		c + Vector2(-s * 1.05, s * 0.30),
		c + Vector2(-s * 0.55, s * 1.00),
		c + Vector2(0.0, s * 0.30),
		c + Vector2(s * 0.55, s * 1.00),
		c + Vector2(s * 1.05, s * 0.30),
	])
	draw_polyline(pts, _overlay_backing(), _overlay_stroke() + 1.6, true)
	draw_polyline(pts, _color_overlay, _overlay_stroke() + 0.4, true)


## 황충 — 백발 (3 white hair tufts above the head; elderly archer signifier).
func _overlay_white_hair() -> void:
	var s: float = _HERO_OVERLAY_SIZE
	var c: Vector2 = _overlay_anchor()
	var white: Color = Color(0.96, 0.96, 0.96, 0.98)
	var dark: Color = Color(0.10, 0.08, 0.06, 0.85)
	for x_off: float in [-s * 0.70, 0.0, s * 0.70]:
		var pos: Vector2 = c + Vector2(x_off, -s * 0.95)
		draw_circle(pos, s * 0.42, dark)
		draw_circle(pos, s * 0.32, white)


## 조조 — 깃털 (big quill feather with barbs). 4 barbs along a longer spine.
func _overlay_feather() -> void:
	var s: float = _HERO_OVERLAY_SIZE
	var base: Vector2 = _overlay_anchor() + Vector2(-s * 0.5, s * 0.6)
	var tip: Vector2 = _overlay_anchor() + Vector2(s * 0.5, -s * 0.8)
	# Backing spine
	draw_line(base, tip, _overlay_backing(), _overlay_stroke() + 1.2, true)
	draw_line(base, tip, _color_overlay, _overlay_stroke(), true)
	# Barbs (perpendicular to the spine)
	var spine: Vector2 = tip - base
	var perp: Vector2 = spine.rotated(PI * 0.5).normalized()
	for t: float in [0.30, 0.50, 0.70, 0.88]:
		var p: Vector2 = base.lerp(tip, t)
		var barb: Vector2 = perp * (s * 0.55 * (1.0 - t * 0.4))
		draw_line(p, p + barb, _color_overlay, _overlay_stroke() - 0.4, true)
		draw_line(p, p - barb, _color_overlay, _overlay_stroke() - 0.4, true)


## 하후돈 — 안대 (bold eyepatch over a circular eye; the X-strap is clearly visible).
func _overlay_eyepatch() -> void:
	var s: float = _HERO_OVERLAY_SIZE
	var c: Vector2 = _overlay_anchor()
	# Eye circle (the un-patched eye, drawn as outline)
	draw_arc(c + Vector2(-s * 0.50, 0.0), s * 0.40, 0.0, TAU, 16, _color_overlay, _overlay_stroke(), true)
	# Patch (filled square rotated 45° = diamond, drawn as filled polygon)
	var px: float = s * 0.45
	var patch_center: Vector2 = c + Vector2(s * 0.45, 0.0)
	var patch: PackedVector2Array = PackedVector2Array([
		patch_center + Vector2(-px, 0.0),
		patch_center + Vector2(0.0, -px),
		patch_center + Vector2(px, 0.0),
		patch_center + Vector2(0.0, px),
	])
	draw_colored_polygon(patch, _color_overlay)
	# Strap line connecting the patch to the eye
	draw_line(c + Vector2(-s * 0.10, 0.0), patch_center + Vector2(-px, 0.0),
		_color_overlay, _overlay_stroke() - 0.2, true)


## 장요 — 번개 (large lightning bolt zigzag, centered).
func _overlay_lightning() -> void:
	var s: float = _HERO_OVERLAY_SIZE
	var c: Vector2 = _overlay_anchor()
	var pts: PackedVector2Array = PackedVector2Array([
		c + Vector2(-s * 0.30, -s * 0.95),
		c + Vector2(s * 0.25, -s * 0.10),
		c + Vector2(-s * 0.15, s * 0.05),
		c + Vector2(s * 0.35, s * 0.95),
	])
	draw_polyline(pts, _overlay_backing(), _overlay_stroke() + 1.4, true)
	draw_polyline(pts, _color_overlay, _overlay_stroke() + 0.3, true)


## 우금 — 사각 진영 (formation: a bold square frame with corner dots).
func _overlay_square_formation() -> void:
	var s: float = _HERO_OVERLAY_SIZE
	var c: Vector2 = _overlay_anchor()
	var r: float = s * 0.85
	var rect: PackedVector2Array = PackedVector2Array([
		c + Vector2(-r, -r), c + Vector2(r, -r),
		c + Vector2(r, r), c + Vector2(-r, r),
		c + Vector2(-r, -r),
	])
	draw_polyline(rect, _overlay_backing(), _overlay_stroke() + 1.0, true)
	draw_polyline(rect, _color_overlay, _overlay_stroke(), true)
	# Four corner dots — soldiers in formation.
	for corner: Vector2 in [Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)]:
		draw_circle(c + corner, s * 0.18, _color_overlay)


## 허저 — 산봉우리 (three mountain peaks silhouette).
func _overlay_mountain() -> void:
	var s: float = _HERO_OVERLAY_SIZE
	var c: Vector2 = _overlay_anchor()
	var pts: PackedVector2Array = PackedVector2Array([
		c + Vector2(-s * 1.00, s * 0.70),
		c + Vector2(-s * 0.50, -s * 0.20),
		c + Vector2(-s * 0.05, s * 0.30),
		c + Vector2(s * 0.40, -s * 0.85),
		c + Vector2(s * 0.85, s * 0.30),
		c + Vector2(s * 1.10, s * 0.70),
	])
	draw_polyline(pts, _overlay_backing(), _overlay_stroke() + 1.4, true)
	draw_polyline(pts, _color_overlay, _overlay_stroke() + 0.3, true)


## 손권 — 푸른 보주 (a large saturated blue orb; the famed blue-eyed emperor).
func _overlay_blue_orb() -> void:
	var s: float = _HERO_OVERLAY_SIZE
	var c: Vector2 = _overlay_anchor()
	var blue: Color = Color(0.30, 0.62, 0.95, 0.98)
	var blue_dark: Color = Color(0.10, 0.30, 0.62, 0.95)
	draw_circle(c, s * 0.80, blue_dark)
	draw_circle(c, s * 0.65, blue)
	# Highlight glint upper-left
	draw_circle(c + Vector2(-s * 0.25, -s * 0.30), s * 0.18, Color(0.95, 0.95, 1.0, 0.85))


## 주유 — 부채 (folding fan: 4 spokes + arc base).
func _overlay_fan() -> void:
	var s: float = _HERO_OVERLAY_SIZE
	var base: Vector2 = _overlay_anchor() + Vector2(0.0, s * 0.50)
	var spokes: Array[float] = [-PI * 0.55, -PI * 0.36, -PI * 0.18, 0.0]
	var spoke_len: float = s * 1.10
	# Backing arc — the fan paper edge
	var arc_pts: PackedVector2Array = PackedVector2Array()
	for theta: float in spokes:
		arc_pts.append(base + Vector2(cos(theta), sin(theta)) * spoke_len)
	draw_polyline(arc_pts, _overlay_backing(), _overlay_stroke() + 1.0, true)
	draw_polyline(arc_pts, _color_overlay, _overlay_stroke(), true)
	# Spokes from base
	for theta: float in spokes:
		var p: Vector2 = base + Vector2(cos(theta), sin(theta)) * spoke_len
		draw_line(base, p, _color_overlay, _overlay_stroke() - 0.2, true)


## 여포 — 별 (4-pointed star with starburst — the peerless warrior).
func _overlay_star() -> void:
	var s: float = _HERO_OVERLAY_SIZE
	var c: Vector2 = _overlay_anchor()
	var r: float = s * 0.95
	# 4 main points (kite-shape star)
	var star: PackedVector2Array = PackedVector2Array([
		c + Vector2(0.0, -r),
		c + Vector2(r * 0.35, -r * 0.35),
		c + Vector2(r, 0.0),
		c + Vector2(r * 0.35, r * 0.35),
		c + Vector2(0.0, r),
		c + Vector2(-r * 0.35, r * 0.35),
		c + Vector2(-r, 0.0),
		c + Vector2(-r * 0.35, -r * 0.35),
	])
	draw_colored_polygon(star, _overlay_backing())
	# Inner brighter star (smaller, same shape)
	var inner: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in star:
		inner.append(c + (p - c) * 0.75)
	draw_colored_polygon(inner, _color_overlay)


## 초선 — 꽃 (a 5-petal flower with bright center).
func _overlay_flower() -> void:
	var s: float = _HERO_OVERLAY_SIZE
	var c: Vector2 = _overlay_anchor()
	# 5 petals around the center
	var petal_r: float = s * 0.45
	for i: int in range(5):
		var theta: float = -PI * 0.5 + TAU * float(i) / 5.0
		var petal_center: Vector2 = c + Vector2(cos(theta), sin(theta)) * s * 0.55
		draw_circle(petal_center, petal_r, _overlay_backing())
		draw_circle(petal_center, petal_r * 0.78, _color_overlay)
	# Bright center bud
	draw_circle(c, s * 0.35, Color(0.98, 0.86, 0.45, 0.98))
