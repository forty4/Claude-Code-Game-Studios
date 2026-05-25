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

## Fire-strategy — 제갈량 박망파/적벽 화공. AoE fire over Manhattan ≤ 3 cells.
## Caster glow + ring of flame motes at radii 1, 2, 3 tiles. Wave staggered
## outward so the fire reads as spreading from the caster.
const FIRE_STRATEGY_TILE_SIZE: float = 64.0
const FIRE_STRATEGY_RING_RADII: Array[float] = [64.0, 128.0, 192.0]
const FIRE_STRATEGY_MOTES_PER_RING: Array[int] = [8, 14, 20]
const FIRE_STRATEGY_RING_STAGGER: float = 0.12
const FIRE_STRATEGY_FLAME_HEIGHT: float = 14.0
const FIRE_STRATEGY_FLAME_WIDTH: float = 6.0
const FIRE_STRATEGY_CORE_R_MIN: float = 8.0
const FIRE_STRATEGY_CORE_R_MAX: float = 26.0
const FIRE_STRATEGY_CORE_COLOR: Color = Color(1.00, 0.82, 0.30, 1.0)
const FIRE_STRATEGY_FLAME_HOT: Color = Color(1.00, 0.92, 0.45, 1.0)   # bright tip
const FIRE_STRATEGY_FLAME_MID: Color = Color(0.98, 0.55, 0.18, 1.0)   # body
const FIRE_STRATEGY_FLAME_DARK: Color = Color(0.62, 0.20, 0.08, 1.0)  # base shadow

## Lone-lance — 조운 단신 돌격. Conditional buff (+75% IF no adjacent allies);
## visual reads as "isolated charge". Cyan/silver palette mirrors SCOUT class
## color (matches AttackLine.COLOR_SCOUT family). Solo-position indicator:
## wide cyan ring at the 8-neighbor boundary + 8 radial lance segments
## pointing outward to communicate "alone, ready to charge in any direction".
const LONE_LANCE_RING_RADIUS: float = 44.0    # just outside caster polygon
const LONE_LANCE_RING_WIDTH: float = 2.4
const LONE_LANCE_LANCE_COUNT: int = 8
const LONE_LANCE_LANCE_INNER_R: float = 16.0  # lance inner end
const LONE_LANCE_LANCE_OUTER_R: float = 40.0  # lance tip
const LONE_LANCE_LANCE_WIDTH: float = 3.2
const LONE_LANCE_LANCE_OUTLINE_WIDTH: float = 4.8
const LONE_LANCE_SWEEP_DELAY: float = 0.10
const LONE_LANCE_SWEEP_SPAN: float = 0.65
const LONE_LANCE_CORE_COLOR: Color = Color(0.85, 0.98, 1.00, 1.0)   # icy white
const LONE_LANCE_GLOW_COLOR: Color = Color(0.45, 0.92, 0.96, 1.0)   # cyan flash
const LONE_LANCE_OUTLINE_COLOR: Color = Color(0.08, 0.20, 0.30, 1.0)  # ink stroke

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


## Fire-strategy factory — 제갈량 박망파/적벽 화공. AoE flame motes in 3
## concentric tile rings (Manhattan ≤ 3) staggered outward from the caster.
static func make_fire_strategy(accent: Color) -> SkillParticleEffect:
	var e: SkillParticleEffect = SkillParticleEffect.new()
	e._accent = accent
	e._kind = &"fire_strategy"
	return e


## Lone-lance factory — 조운 단신 돌격. Solo-position indicator (cyan ring) +
## 8 radial lance segments. Buff fires only IF caster has no adjacent allies
## at attack-resolution time, so the visual communicates "isolated, ready".
static func make_lone_lance(accent: Color) -> SkillParticleEffect:
	var e: SkillParticleEffect = SkillParticleEffect.new()
	e._accent = accent
	e._kind = &"lone_lance"
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
		&"fire_strategy":
			_draw_fire_strategy()
		&"lone_lance":
			_draw_lone_lance()
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


func _draw_fire_strategy() -> void:
	# Layer 1: caster core flame — orange glow expanding from R_MIN → R_MAX
	# in the first ~30% of DURATION. Holds bright then fades with the rings.
	var core_progress: float = clampf(_progress / 0.35, 0.0, 1.0)
	if core_progress > 0.0:
		var radius: float = lerp(FIRE_STRATEGY_CORE_R_MIN, FIRE_STRATEGY_CORE_R_MAX, core_progress)
		var core_alpha: float = sin(core_progress * PI) * 0.95
		var glow_c: Color = FIRE_STRATEGY_FLAME_MID
		glow_c.a = core_alpha * 0.7
		var hot_c: Color = FIRE_STRATEGY_CORE_COLOR
		hot_c.a = core_alpha
		draw_circle(Vector2.ZERO, radius + 4.0, glow_c)
		draw_circle(Vector2.ZERO, radius, hot_c)

	# Layer 2: 3 concentric rings of flame motes at radii 1, 2, 3 tiles.
	# Each ring's motes appear staggered outward so the fire reads as
	# spreading from caster. Inside each ring all motes share the same
	# timing window.
	for ring_idx: int in FIRE_STRATEGY_RING_RADII.size():
		var stagger: float = float(ring_idx) * FIRE_STRATEGY_RING_STAGGER
		var span: float = 1.0 - stagger
		if span <= 0.0:
			continue
		var ring_progress: float = clampf((_progress - stagger) / span, 0.0, 1.0)
		if ring_progress <= 0.0 or ring_progress >= 1.0:
			continue
		var ring_alpha: float = sin(ring_progress * PI) * 0.95
		var radius: float = FIRE_STRATEGY_RING_RADII[ring_idx]
		var mote_count: int = FIRE_STRATEGY_MOTES_PER_RING[ring_idx]
		# Slight per-ring rotation offset so the motes don't align radially
		# across rings (reads as natural fire, not a clock face).
		var phase_offset: float = float(ring_idx) * 0.5
		for mote_idx: int in mote_count:
			var theta: float = TAU * float(mote_idx) / float(mote_count) + phase_offset
			var pos: Vector2 = Vector2(cos(theta), sin(theta)) * radius
			_draw_flame_mote(pos, theta + PI * 0.5, ring_alpha, ring_progress)


## Single flame-shape mote: tear-drop triangle pointing along `tip_angle`.
## `progress` 0..1 used to scale the flame size — small at start, peaks
## mid-window, shrinks at end (same sin curve as alpha so the flame
## "breathes" once before fading).
func _draw_flame_mote(pos: Vector2, tip_angle: float, alpha: float, progress: float) -> void:
	var scale: float = sin(progress * PI) * 1.0
	if scale <= 0.0:
		return
	# Build a 3-point flame: tip + 2 base corners, oriented along tip_angle.
	# tip_angle = angle TOWARDS the flame tip (radial outward).
	var tip_dir: Vector2 = Vector2(cos(tip_angle - PI * 0.5), sin(tip_angle - PI * 0.5))
	var tip: Vector2 = pos + tip_dir * (FIRE_STRATEGY_FLAME_HEIGHT * scale)
	var perp: Vector2 = tip_dir.rotated(PI * 0.5)
	var base_l: Vector2 = pos - perp * (FIRE_STRATEGY_FLAME_WIDTH * 0.5 * scale)
	var base_r: Vector2 = pos + perp * (FIRE_STRATEGY_FLAME_WIDTH * 0.5 * scale)
	# Inner hot tip — a smaller triangle inside for the bright core.
	var inner_tip: Vector2 = pos + tip_dir * (FIRE_STRATEGY_FLAME_HEIGHT * scale * 0.7)
	var inner_l: Vector2 = pos - perp * (FIRE_STRATEGY_FLAME_WIDTH * 0.25 * scale)
	var inner_r: Vector2 = pos + perp * (FIRE_STRATEGY_FLAME_WIDTH * 0.25 * scale)
	var dark: Color = FIRE_STRATEGY_FLAME_DARK
	dark.a = alpha * 0.65
	var mid: Color = FIRE_STRATEGY_FLAME_MID
	mid.a = alpha
	var hot: Color = FIRE_STRATEGY_FLAME_HOT
	hot.a = alpha
	draw_polygon(PackedVector2Array([tip, base_r, base_l]), PackedColorArray([mid, dark, dark]))
	draw_polygon(PackedVector2Array([inner_tip, inner_r, inner_l]), PackedColorArray([hot, mid, mid]))


func _draw_lone_lance() -> void:
	# Layer 1: cyan "solo position" ring at the 8-neighbor boundary. Quick
	# punch in (first ~25%), holds visible, then fades with the lances. Two
	# passes (outline + glow) so the ring reads against grass + stone tiles.
	var ring_progress: float = clampf(_progress / 0.85, 0.0, 1.0)
	if ring_progress > 0.0 and ring_progress < 1.0:
		var ring_alpha: float = sin(ring_progress * PI) * 0.95
		var ring_outline: Color = LONE_LANCE_OUTLINE_COLOR
		ring_outline.a = ring_alpha * 0.8
		var ring_glow: Color = LONE_LANCE_GLOW_COLOR
		ring_glow.a = ring_alpha
		draw_arc(Vector2.ZERO, LONE_LANCE_RING_RADIUS, 0.0, TAU, 48, ring_outline, LONE_LANCE_RING_WIDTH + 1.6, true)
		draw_arc(Vector2.ZERO, LONE_LANCE_RING_RADIUS, 0.0, TAU, 48, ring_glow, LONE_LANCE_RING_WIDTH, true)

	# Layer 2: 8 radial lance segments. Each lance grows outward from inner_R
	# to outer_R across the sweep window — reads as "charging outward in
	# every direction simultaneously" (solo strike potential). Sin alpha for
	# flash + fade. Three passes (outline + glow + core) per lance for
	# readability over any terrain palette.
	var sweep_progress: float = clampf((_progress - LONE_LANCE_SWEEP_DELAY) / LONE_LANCE_SWEEP_SPAN, 0.0, 1.0)
	if sweep_progress > 0.0 and sweep_progress < 1.0:
		var lance_alpha: float = sin(sweep_progress * PI) * 0.95
		var outer_r: float = lerp(LONE_LANCE_LANCE_INNER_R + 6.0, LONE_LANCE_LANCE_OUTER_R, sweep_progress)
		for lance_idx: int in LONE_LANCE_LANCE_COUNT:
			var theta: float = TAU * float(lance_idx) / float(LONE_LANCE_LANCE_COUNT)
			var dir: Vector2 = Vector2(cos(theta), sin(theta))
			var inner: Vector2 = dir * LONE_LANCE_LANCE_INNER_R
			var outer: Vector2 = dir * outer_r
			var outline_c: Color = LONE_LANCE_OUTLINE_COLOR
			outline_c.a = lance_alpha * 0.85
			var glow_c: Color = LONE_LANCE_GLOW_COLOR
			glow_c.a = lance_alpha * 0.80
			var core_c: Color = LONE_LANCE_CORE_COLOR
			core_c.a = lance_alpha
			draw_line(inner, outer, outline_c, LONE_LANCE_LANCE_OUTLINE_WIDTH, true)
			draw_line(inner, outer, glow_c, LONE_LANCE_LANCE_WIDTH + 1.2, true)
			draw_line(inner, outer, core_c, LONE_LANCE_LANCE_WIDTH, true)
