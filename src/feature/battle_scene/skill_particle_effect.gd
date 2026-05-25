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

var _accent: Color = Color(1.00, 0.85, 0.32)
var _kind: StringName = &""
var _progress: float = 0.0


## Dragon-blade factory — 관우 청룡언월도. accent is the caster's hero accent
## (yellow gold for 관우) so the effect reads as "this hero's signature flourish".
static func make_dragon_blade(accent: Color) -> SkillParticleEffect:
	var e: SkillParticleEffect = SkillParticleEffect.new()
	e._accent = accent
	e._kind = &"dragon_blade"
	return e


func _ready() -> void:
	_animate()


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
