## AttackLine — short-lived effect drawn from attacker to defender on
## `damage_applied`. Self-animating: fades `modulate:a → 0` over DURATION then
## queue_frees. Parented to ChapterVisuals (NOT either polygon) so the line
## survives if the hit kills the defender or moves the attacker.
##
## Session-16: class-aware style switch. Pass attacker_class into `make()` and
## the line picks one of six visual treatments:
##   - CAVALRY    — thick warm-cream straight line with trailing dash echo (charge)
##   - INFANTRY   — thick warm-cream straight line (sword swing); default look
##   - ARCHER     — upward parabolic arc (existing behaviour, retained as a
##                  procedural arrow shot)
##   - STRATEGIST — dashed indigo line ending in a small "lightning crack" at
##                  the target (intellect strike)
##   - COMMANDER  — straight line + pulse ring at the target (command order)
##   - SCOUT      — cyan zigzag (quick strike) — only shows when ambush conditions
##                  are met; reads as the fast-paced ambush vibe regardless
##
## Backward-compatibility: when no class is supplied (legacy callers + the few
## tests that build via .new() directly), the auto-arc / straight-line decision
## from sessions 4-15 still drives the rendering. Class-aware callers should
## prefer `make_for_class(from, to, attacker_class)`.
class_name AttackLine
extends Node2D

const DURATION: float = 0.22
const WIDTH: float = 3.0
const OUTLINE_WIDTH_BONUS: float = 1.5

## Distance threshold above which the line becomes an arc when class is NOT
## supplied. ChapterVisuals TILE_SIZE = 64; 96 = ~1.5 tiles, cleanly separating
## melee (exactly 1 tile under 4-directional adjacency = 64px) from any range-2+
## shot (128px+).
const ARC_DISTANCE_THRESHOLD: float = 96.0

## Apex height proportional to chord length, capped so very long shots don't
## bow into the HUD ribbon at the top of the viewport.
const ARC_HEIGHT_RATIO: float = 0.30
const ARC_HEIGHT_MAX: float = 64.0

## Polyline sample count for the parabola. 16 segments reads as smooth at
## the standard tile zoom; each segment is ~8-12px in screen space.
const ARC_SEGMENTS: int = 16

## Zigzag (SCOUT) — number of cycles along the chord; each cycle = one full
## up/down sweep. 6 cycles at 1-tile distance reads as "rapid slash flurry".
const ZIGZAG_CYCLES: int = 6
const ZIGZAG_AMPLITUDE: float = 6.0

## Dashed (STRATEGIST) — dash and gap length in pixels.
const DASH_LEN: float = 7.0
const DASH_GAP: float = 5.0

const COLOR_LINE:        Color = Color(0.95, 0.88, 0.70, 0.90)  # warm cream (melee default)
const COLOR_OUTLINE:     Color = Color(0.05, 0.04, 0.04, 0.85)  # ink stroke
const COLOR_STRATEGIST:  Color = Color(0.78, 0.66, 0.95, 0.95)  # indigo violet
const COLOR_COMMANDER:   Color = Color(0.98, 0.86, 0.42, 0.95)  # warm gold
const COLOR_SCOUT:       Color = Color(0.45, 0.92, 0.96, 0.95)  # cyan flash
const COLOR_CAVALRY:     Color = Color(0.98, 0.80, 0.42, 0.95)  # saturated amber

const _CLASS_NONE: int = -1
## UnitRole.UnitClass values inlined to avoid loading the foundation module
## in a leaf visual — keep this list in sync if the enum is renumbered (rare).
const _CLASS_CAVALRY: int = 0
const _CLASS_INFANTRY: int = 1
const _CLASS_ARCHER: int = 2
const _CLASS_STRATEGIST: int = 3
const _CLASS_COMMANDER: int = 4
const _CLASS_SCOUT: int = 5

var _from: Vector2 = Vector2.ZERO
var _to: Vector2 = Vector2.ZERO
## 0.0 = straight line; > 0 = parabolic arc with this apex height above the
## chord midpoint. Inferred from chord length in make().
var _arc_height: float = 0.0
var _attacker_class: int = _CLASS_NONE


## Legacy factory — preserves the pre-session-16 auto-arc-on-distance behaviour.
## Prefer make_for_class when the attacker's class is known.
static func make(from: Vector2, to: Vector2) -> AttackLine:
	var l: AttackLine = AttackLine.new()
	l._from = from
	l._to = to
	var dist: float = (to - from).length()
	if dist > ARC_DISTANCE_THRESHOLD:
		l._arc_height = minf(dist * ARC_HEIGHT_RATIO, ARC_HEIGHT_MAX)
	return l


## Session-16 factory — selects a per-class draw style. attacker_class matches
## UnitRole.UnitClass (0=CAVALRY .. 5=SCOUT); any other value falls back to the
## legacy auto-arc / straight-line behaviour for safety.
static func make_for_class(from: Vector2, to: Vector2, attacker_class: int) -> AttackLine:
	var l: AttackLine = make(from, to)
	l._attacker_class = attacker_class
	# ARCHER always uses the arc regardless of distance; melee classes always
	# stay straight even on long shots (which shouldn't happen for melee but
	# this keeps the per-class read consistent).
	if attacker_class == _CLASS_ARCHER:
		var dist: float = (to - from).length()
		l._arc_height = minf(maxf(dist, ARC_DISTANCE_THRESHOLD) * ARC_HEIGHT_RATIO, ARC_HEIGHT_MAX)
	elif attacker_class >= 0 and attacker_class != _CLASS_NONE:
		# Non-ARCHER classes: suppress the auto-arc; their style speaks for
		# itself without needing the projectile metaphor.
		l._arc_height = 0.0
	return l


func _ready() -> void:
	_animate()


func _draw() -> void:
	match _attacker_class:
		_CLASS_STRATEGIST:
			_draw_dashed(COLOR_STRATEGIST)
			return
		_CLASS_SCOUT:
			_draw_zigzag(COLOR_SCOUT)
			return
		_CLASS_COMMANDER:
			_draw_straight(COLOR_COMMANDER, WIDTH)
			_draw_target_pulse(COLOR_COMMANDER)
			return
		_CLASS_CAVALRY:
			_draw_straight(COLOR_CAVALRY, WIDTH + 0.8)
			_draw_trail_echo(COLOR_CAVALRY)
			return
		_CLASS_INFANTRY:
			_draw_straight(COLOR_LINE, WIDTH + 0.6)
			return
		_:
			pass  # ARCHER + legacy fall through to the arc/straight decision
	if _arc_height <= 0.0:
		_draw_straight(COLOR_LINE, WIDTH)
		return
	_draw_arc(COLOR_LINE)


# ─── Style implementations ───────────────────────────────────────────────────


func _draw_straight(line_color: Color, width: float) -> void:
	draw_line(_from, _to, COLOR_OUTLINE, width + OUTLINE_WIDTH_BONUS)
	draw_line(_from, _to, line_color, width)


func _draw_arc(line_color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	var mid: Vector2 = (_from + _to) * 0.5
	var apex: Vector2 = mid + Vector2(0.0, -_arc_height)
	for i: int in range(ARC_SEGMENTS + 1):
		var t: float = float(i) / float(ARC_SEGMENTS)
		var inv: float = 1.0 - t
		var p: Vector2 = (inv * inv) * _from + (2.0 * inv * t) * apex + (t * t) * _to
		points.append(p)
	draw_polyline(points, COLOR_OUTLINE, WIDTH + OUTLINE_WIDTH_BONUS, true)
	draw_polyline(points, line_color, WIDTH, true)


## STRATEGIST — fixed-length dashes along the chord; ends at the target with a
## small Y-shape "crack" so the strike reads as a magical zap, not a thrown
## projectile.
func _draw_dashed(line_color: Color) -> void:
	var delta: Vector2 = _to - _from
	var length: float = delta.length()
	if length <= 0.0:
		return
	var dir: Vector2 = delta / length
	var step: float = DASH_LEN + DASH_GAP
	var dashes: int = int(length / step)
	for i: int in range(dashes + 1):
		var a: Vector2 = _from + dir * float(i) * step
		var b_end: float = minf(float(i) * step + DASH_LEN, length)
		var b: Vector2 = _from + dir * b_end
		draw_line(a, b, COLOR_OUTLINE, WIDTH + OUTLINE_WIDTH_BONUS - 0.4)
		draw_line(a, b, line_color, WIDTH - 0.2)
	# Y-crack at target: 2 short branches splitting off the chord direction.
	var crack_origin: Vector2 = _to - dir * 6.0
	var perp: Vector2 = dir.rotated(PI * 0.5) * 7.0
	draw_line(crack_origin, _to + perp, line_color, WIDTH - 0.2)
	draw_line(crack_origin, _to - perp, line_color, WIDTH - 0.2)


## SCOUT — sinusoidal zigzag along the chord. Amplitude in the perpendicular
## direction. Hits as a "rapid strike flurry" visual.
func _draw_zigzag(line_color: Color) -> void:
	var delta: Vector2 = _to - _from
	var length: float = delta.length()
	if length <= 0.0:
		return
	var dir: Vector2 = delta / length
	var perp: Vector2 = dir.rotated(PI * 0.5)
	var segs: int = ZIGZAG_CYCLES * 4
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in range(segs + 1):
		var t: float = float(i) / float(segs)
		# Triangle wave 0..1..0..-1..0 across the chord
		var phase: float = (t * float(ZIGZAG_CYCLES)) * TAU
		var amp: float = sin(phase) * ZIGZAG_AMPLITUDE
		points.append(_from + dir * (length * t) + perp * amp)
	draw_polyline(points, COLOR_OUTLINE, WIDTH + OUTLINE_WIDTH_BONUS - 0.6, true)
	draw_polyline(points, line_color, WIDTH - 0.4, true)


## COMMANDER — extra concentric ring at the target tile so the order reads as
## "directed strike" rather than personal combat.
func _draw_target_pulse(line_color: Color) -> void:
	draw_arc(_to, 12.0, 0.0, TAU, 32, COLOR_OUTLINE, WIDTH + 0.4, true)
	draw_arc(_to, 12.0, 0.0, TAU, 32, line_color, WIDTH - 0.6, true)
	draw_arc(_to, 18.0, 0.0, TAU, 32, line_color, WIDTH - 1.0, true)


## CAVALRY — short fading echo line offset perpendicular to the chord so the
## strike reads as "I came charging through here, then hit."
func _draw_trail_echo(line_color: Color) -> void:
	var delta: Vector2 = _to - _from
	var length: float = delta.length()
	if length <= 0.0:
		return
	var dir: Vector2 = delta / length
	var perp: Vector2 = dir.rotated(PI * 0.5) * 4.0
	var echo_color: Color = line_color
	echo_color.a *= 0.55
	# Two parallel "speed trail" lines flanking the main strike.
	draw_line(_from + perp, _to + perp, echo_color, WIDTH * 0.55)
	draw_line(_from - perp, _to - perp, echo_color, WIDTH * 0.55)


func _animate() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)
