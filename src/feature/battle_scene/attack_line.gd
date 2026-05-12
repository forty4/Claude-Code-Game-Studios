## AttackLine — short-lived line drawn from attacker to defender on
## `damage_applied`. Self-animating: fades `modulate:a → 0` over DURATION then
## queue_frees. Parented to ChapterVisuals (NOT either polygon) so the line
## survives if the hit kills the defender or moves the attacker.
##
## Ranged attacks (chord length > ARC_DISTANCE_THRESHOLD) auto-render as an
## upward parabolic arc instead of a straight line — sells the projectile
## trajectory and visually separates archer hits from melee swings without
## requiring the call site to know the attacker's class.
##
## Construction: use the static `make(from, to)` factory; positions are in the
## same world-space frame as the unit polygons (ChapterVisuals local space).
class_name AttackLine
extends Node2D

const DURATION: float = 0.2
const WIDTH: float = 3.0
const OUTLINE_WIDTH_BONUS: float = 1.5

## Distance threshold above which the line becomes an arc. ChapterVisuals
## TILE_SIZE = 64; 96 = ~1.5 tiles, cleanly separating melee (exactly 1 tile
## under 4-directional adjacency = 64px) from any range-2+ shot (128px+).
const ARC_DISTANCE_THRESHOLD: float = 96.0

## Apex height proportional to chord length, capped so very long shots don't
## bow into the HUD ribbon at the top of the viewport.
const ARC_HEIGHT_RATIO: float = 0.30
const ARC_HEIGHT_MAX: float = 64.0

## Polyline sample count for the parabola. 16 segments reads as smooth at
## the standard tile zoom; each segment is ~8-12px in screen space.
const ARC_SEGMENTS: int = 16

const COLOR_LINE:    Color = Color(0.95, 0.88, 0.70, 0.85)  # warm cream
const COLOR_OUTLINE: Color = Color(0.05, 0.04, 0.04, 0.85)  # ink stroke

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
## 0.0 = straight line; > 0 = parabolic arc with this apex height above the
## chord midpoint. Inferred from chord length in make().
var _arc_height: float = 0.0


static func make(from: Vector2, to: Vector2) -> AttackLine:
	var l: AttackLine = AttackLine.new()
	l._from = from
	l._to = to
	var dist: float = (to - from).length()
	if dist > ARC_DISTANCE_THRESHOLD:
		l._arc_height = minf(dist * ARC_HEIGHT_RATIO, ARC_HEIGHT_MAX)
	return l


func _ready() -> void:
	_animate()


func _draw() -> void:
	if _arc_height <= 0.0:
		# Melee: straight line, black backing for terrain-agnostic readability.
		draw_line(_from, _to, COLOR_OUTLINE, WIDTH + OUTLINE_WIDTH_BONUS)
		draw_line(_from, _to, COLOR_LINE, WIDTH)
		return
	# Ranged: parabolic arc above the chord midpoint via quadratic Bezier
	# sampled at ARC_SEGMENTS + 1 points. Apex is straight up (-Y) so the
	# trajectory reads as an arrow shot regardless of fire direction.
	var points: PackedVector2Array = PackedVector2Array()
	var mid: Vector2 = (_from + _to) * 0.5
	var apex: Vector2 = mid + Vector2(0.0, -_arc_height)
	for i: int in range(ARC_SEGMENTS + 1):
		var t: float = float(i) / float(ARC_SEGMENTS)
		var inv: float = 1.0 - t
		var p: Vector2 = (inv * inv) * _from + (2.0 * inv * t) * apex + (t * t) * _to
		points.append(p)
	draw_polyline(points, COLOR_OUTLINE, WIDTH + OUTLINE_WIDTH_BONUS, true)
	draw_polyline(points, COLOR_LINE, WIDTH, true)


func _animate() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
