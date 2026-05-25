## SkillParticleEffect — per-skill caster-centered visual flourish.
##
## Self-animating Node2D parented to ChapterVisuals (NOT the caster polygon) so
## the effect survives if the caster moves or dies mid-animation. Sibling to
## AttackLine / SkillPopup / DamagePopup. Spawned by battle_scene after the
## SkillPopup banner mount.
##
## Session-87 — first skill candidate: dragon_blade (관우 청룡언월도).
## Visual concept locked in S86 handoff #1: "caster yellow glow + sword swing
## trail". Implemented as 3 staggered expanding golden rings + a yellow
## crescent sweep arc rotating around the caster. Procedural _draw() per the
## AttackLine reference pattern (no CPUParticles2D — keeps the visual layer
## leaf-free of engine particle config and matches the existing popup family).
##
## Future skills (~17 more) dispatch via _kind StringName; each gets its own
## _draw_<skill> method + matching static factory. See S86 handoff for the
## locked palette per skill.
class_name SkillParticleEffect
extends Node2D

const DURATION_DEFAULT: float = 0.70

## Dragon-blade — golden warm-cream palette; rings sweep wider than the
## caster polygon (radius ~12px) so the glow reads as power emanating outward.
const DRAGON_BLADE_RING_COUNT: int = 3
const DRAGON_BLADE_RING_STAGGER: float = 0.15
const DRAGON_BLADE_RING_R_MIN: float = 10.0
const DRAGON_BLADE_RING_R_MAX: float = 38.0
const DRAGON_BLADE_RING_WIDTH: float = 2.6
const DRAGON_BLADE_RING_ALPHA: float = 0.85

const DRAGON_BLADE_SWEEP_RADIUS: float = 30.0
const DRAGON_BLADE_SWEEP_ARC: float = 0.85  # rad; ~49° crescent
const DRAGON_BLADE_SWEEP_WIDTH: float = 4.5
const DRAGON_BLADE_SWEEP_DELAY: float = 0.06
const DRAGON_BLADE_SWEEP_SPAN: float = 0.60
const DRAGON_BLADE_SWEEP_FROM: float = -PI * 0.7   # start angle (above-left)
const DRAGON_BLADE_SWEEP_TO: float = PI * 0.3      # end angle (below-right)
const DRAGON_BLADE_SWEEP_COLOR: Color = Color(1.00, 0.92, 0.55, 1.0)

## Thunder-roar — central burst + 4 cardinal lightning bolts to adjacent
## tiles (TILE_SIZE = 64). White/blue palette reads as raw electric power.
## Tracks the production behaviour: 25 damage to all Manhattan-1 enemies, so
## the visual reaches every cardinal neighbor regardless of unit presence.
const THUNDER_ROAR_TILE_SIZE: float = 64.0
const THUNDER_ROAR_BURST_R_MIN: float = 6.0
const THUNDER_ROAR_BURST_R_MAX: float = 22.0
const THUNDER_ROAR_BURST_WIDTH: float = 3.0
const THUNDER_ROAR_BOLT_SEGMENTS: int = 8
const THUNDER_ROAR_BOLT_JITTER: float = 6.0
const THUNDER_ROAR_BOLT_WIDTH: float = 3.2
const THUNDER_ROAR_BOLT_OUTLINE_WIDTH: float = 5.4
const THUNDER_ROAR_BOLT_DELAY: float = 0.05
const THUNDER_ROAR_BOLT_SPAN: float = 0.30
const THUNDER_ROAR_CORE_COLOR: Color = Color(0.96, 0.98, 1.00, 1.0)
const THUNDER_ROAR_GLOW_COLOR: Color = Color(0.55, 0.78, 1.00, 1.0)
const THUNDER_ROAR_OUTLINE_COLOR: Color = Color(0.10, 0.18, 0.36, 1.0)

var _accent: Color = Color(1.00, 0.85, 0.32)
var _kind: StringName = &""
var _progress: float = 0.0
## Pre-rolled bolt jitter pattern — each bolt's mid-point perpendicular
## offsets, baked in _ready so they stay stable across redraws instead of
## flickering on every frame. 4 bolts × (SEGMENTS-1) inner samples.
var _bolt_jitter: Array[PackedFloat32Array] = []


## Dragon-blade factory — 관우 청룡언월도. accent is the caster's hero accent
## (yellow gold for 관우) so the effect reads as "this hero's signature flourish".
static func make_dragon_blade(accent: Color) -> SkillParticleEffect:
	var e: SkillParticleEffect = SkillParticleEffect.new()
	e._accent = accent
	e._kind = &"dragon_blade"
	return e


## Thunder-roar factory — 장비 천둥 포효. 4 cardinal jagged lightning bolts
## radiating from the caster to adjacent tile centers (Manhattan-1 cells).
static func make_thunder_roar(accent: Color) -> SkillParticleEffect:
	var e: SkillParticleEffect = SkillParticleEffect.new()
	e._accent = accent
	e._kind = &"thunder_roar"
	return e


func _ready() -> void:
	if _kind == &"thunder_roar":
		_roll_thunder_roar_jitter()
	_animate()


## Pre-roll jitter for thunder_roar bolts so the polyline mid-points stay
## stable across the redraw cycle (otherwise the bolts re-randomize every
## frame and read as "static noise" instead of "frozen lightning fork").
func _roll_thunder_roar_jitter() -> void:
	_bolt_jitter.clear()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = Time.get_ticks_usec()
	for bolt_idx: int in 4:
		var jitter_row: PackedFloat32Array = PackedFloat32Array()
		for seg_idx: int in (THUNDER_ROAR_BOLT_SEGMENTS - 1):
			jitter_row.append(rng.randf_range(-THUNDER_ROAR_BOLT_JITTER, THUNDER_ROAR_BOLT_JITTER))
		_bolt_jitter.append(jitter_row)


func _process(_dt: float) -> void:
	queue_redraw()


func _animate() -> void:
	# Tree-bound tween per G-31. ChapterVisuals lives at /root so its
	# process_mode is independent of BattleScene, but the tree-bound form
	# is the safe default across every popup/effect in this family.
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(self, "_progress", 1.0, DURATION_DEFAULT) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)


func _draw() -> void:
	match _kind:
		&"dragon_blade":
			_draw_dragon_blade()
		&"thunder_roar":
			_draw_thunder_roar()
		_:
			pass


func _draw_dragon_blade() -> void:
	# Layer 1: 3 expanding golden rings, staggered start. Each ring scales
	# from R_MIN → R_MAX while alpha fades to 0; reads as a power halo
	# pulsing outward from the caster.
	for i: int in DRAGON_BLADE_RING_COUNT:
		var stagger: float = float(i) * DRAGON_BLADE_RING_STAGGER
		var span: float = 1.0 - stagger
		if span <= 0.0:
			continue
		var ring_progress: float = clampf((_progress - stagger) / span, 0.0, 1.0)
		if ring_progress <= 0.0:
			continue
		var radius: float = lerp(DRAGON_BLADE_RING_R_MIN, DRAGON_BLADE_RING_R_MAX, ring_progress)
		var alpha: float = (1.0 - ring_progress) * DRAGON_BLADE_RING_ALPHA
		var ring_color: Color = _accent
		ring_color.a = alpha
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, ring_color, DRAGON_BLADE_RING_WIDTH, true)

	# Layer 2: sword crescent sweep — a short arc segment rotating from
	# above-left to below-right past the caster. Yellow warm-cream so it
	# reads as "the blade itself slicing through". Independent timing
	# window inside the overall DURATION so the rings + sweep overlap
	# without colliding visually.
	var sweep_progress: float = clampf((_progress - DRAGON_BLADE_SWEEP_DELAY) / DRAGON_BLADE_SWEEP_SPAN, 0.0, 1.0)
	if sweep_progress > 0.0 and sweep_progress < 1.0:
		var sweep_center: float = lerp(DRAGON_BLADE_SWEEP_FROM, DRAGON_BLADE_SWEEP_TO, sweep_progress)
		var sweep_start: float = sweep_center - DRAGON_BLADE_SWEEP_ARC * 0.5
		var sweep_end: float = sweep_center + DRAGON_BLADE_SWEEP_ARC * 0.5
		# Alpha peaks mid-sweep (0.5 progress) for the "swoosh" feel, then
		# fades out at the end. Sin curve over 0..PI maps 0→1→0 across
		# sweep_progress 0..1.
		var sweep_alpha: float = sin(sweep_progress * PI) * 0.95
		var sweep_color: Color = DRAGON_BLADE_SWEEP_COLOR
		sweep_color.a = sweep_alpha
		# Outline pass for readability against dark terrain
		var outline_color: Color = Color(0.18, 0.12, 0.04, sweep_alpha * 0.75)
		draw_arc(Vector2.ZERO, DRAGON_BLADE_SWEEP_RADIUS, sweep_start, sweep_end, 24, outline_color, DRAGON_BLADE_SWEEP_WIDTH + 1.4, true)
		draw_arc(Vector2.ZERO, DRAGON_BLADE_SWEEP_RADIUS, sweep_start, sweep_end, 24, sweep_color, DRAGON_BLADE_SWEEP_WIDTH, true)


func _draw_thunder_roar() -> void:
	# Layer 1: central electric burst at the caster. Two concentric expanding
	# rings (core white + outer blue glow) so the caster looks struck by their
	# own thunder. Quick punch in the first ~40% of DURATION, then settles.
	var burst_progress: float = clampf(_progress / 0.45, 0.0, 1.0)
	if burst_progress > 0.0:
		var burst_radius: float = lerp(THUNDER_ROAR_BURST_R_MIN, THUNDER_ROAR_BURST_R_MAX, burst_progress)
		var burst_alpha: float = (1.0 - burst_progress)
		var core: Color = THUNDER_ROAR_CORE_COLOR
		core.a = burst_alpha
		var glow: Color = THUNDER_ROAR_GLOW_COLOR
		glow.a = burst_alpha * 0.85
		draw_arc(Vector2.ZERO, burst_radius + 3.0, 0.0, TAU, 24, glow, THUNDER_ROAR_BURST_WIDTH + 1.8, true)
		draw_arc(Vector2.ZERO, burst_radius, 0.0, TAU, 24, core, THUNDER_ROAR_BURST_WIDTH, true)

	# Layer 2: 4 cardinal lightning bolts to adjacent tile centers (Manhattan-1).
	# Bolts appear shortly after the burst, hold visible for a short window,
	# then fade. Jagged polyline with pre-rolled jitter (see _roll_thunder_roar_jitter).
	var bolt_progress: float = clampf((_progress - THUNDER_ROAR_BOLT_DELAY) / THUNDER_ROAR_BOLT_SPAN, 0.0, 1.0)
	if bolt_progress > 0.0 and bolt_progress < 1.0:
		# Sin curve 0→1→0 across bolt_progress 0..1 — bolt flashes then fades.
		var bolt_alpha: float = sin(bolt_progress * PI)
		var cardinals: Array[Vector2] = [
			Vector2(THUNDER_ROAR_TILE_SIZE, 0.0),
			Vector2(-THUNDER_ROAR_TILE_SIZE, 0.0),
			Vector2(0.0, THUNDER_ROAR_TILE_SIZE),
			Vector2(0.0, -THUNDER_ROAR_TILE_SIZE),
		]
		for bolt_idx: int in cardinals.size():
			_draw_bolt(Vector2.ZERO, cardinals[bolt_idx], bolt_idx, bolt_alpha)


## Draws a single jagged lightning bolt from `start` to `end` using the
## pre-rolled jitter pattern at row `bolt_idx`. Three passes (outline + glow +
## core) give the bolt readability against any terrain palette.
func _draw_bolt(start: Vector2, end: Vector2, bolt_idx: int, alpha: float) -> void:
	var delta: Vector2 = end - start
	var length: float = delta.length()
	if length <= 0.0:
		return
	var dir: Vector2 = delta / length
	var perp: Vector2 = dir.rotated(PI * 0.5)
	var jitter_row: PackedFloat32Array = _bolt_jitter[bolt_idx] if bolt_idx < _bolt_jitter.size() else PackedFloat32Array()
	var points: PackedVector2Array = PackedVector2Array()
	points.append(start)
	for seg_idx: int in (THUNDER_ROAR_BOLT_SEGMENTS - 1):
		var t: float = float(seg_idx + 1) / float(THUNDER_ROAR_BOLT_SEGMENTS)
		var offset: float = jitter_row[seg_idx] if seg_idx < jitter_row.size() else 0.0
		points.append(start + dir * (length * t) + perp * offset)
	points.append(end)
	var outline_c: Color = THUNDER_ROAR_OUTLINE_COLOR
	outline_c.a = alpha * 0.85
	var glow_c: Color = THUNDER_ROAR_GLOW_COLOR
	glow_c.a = alpha * 0.80
	var core_c: Color = THUNDER_ROAR_CORE_COLOR
	core_c.a = alpha
	draw_polyline(points, outline_c, THUNDER_ROAR_BOLT_OUTLINE_WIDTH, true)
	draw_polyline(points, glow_c, THUNDER_ROAR_BOLT_WIDTH + 1.2, true)
	draw_polyline(points, core_c, THUNDER_ROAR_BOLT_WIDTH, true)
