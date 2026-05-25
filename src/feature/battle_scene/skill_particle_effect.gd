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

## Inspire — 유비 격려. Adjacent player allies get a free action token. Visual
## reads as "warm supportive pulse spreading to neighbors". Caster center aura
## + 8 small ring pulses at the 8-neighbor positions (TILE_SIZE = 64 cardinal
## + diagonal). Sage-green palette for the buff/heal feel.
const INSPIRE_TILE_SIZE: float = 64.0
const INSPIRE_AURA_R_MIN: float = 10.0
const INSPIRE_AURA_R_MAX: float = 30.0
const INSPIRE_PULSE_R_MIN: float = 4.0
const INSPIRE_PULSE_R_MAX: float = 22.0
const INSPIRE_PULSE_WIDTH: float = 2.4
const INSPIRE_PULSE_DELAY: float = 0.12
const INSPIRE_PULSE_SPAN: float = 0.55
const INSPIRE_AURA_COLOR: Color = Color(0.66, 0.95, 0.62, 1.0)    # warm sage glow
const INSPIRE_PULSE_CORE_COLOR: Color = Color(0.85, 1.00, 0.78, 1.0)  # mint highlight
const INSPIRE_OUTLINE_COLOR: Color = Color(0.10, 0.30, 0.14, 1.0)  # forest ink

## Piercing-volley — 황충 (ARCHER) 28 dmg × 3 nearest within attack_range. Visual
## reads as "many arrows fanning outward". 8 radial arrow streaks at range-3
## distance — covers all directions since target picking is "3 nearest" rather
## than directional.
const PIERCING_VOLLEY_ARROW_COUNT: int = 8
const PIERCING_VOLLEY_INNER_R: float = 18.0
const PIERCING_VOLLEY_OUTER_R: float = 188.0  # ~range 3
const PIERCING_VOLLEY_WIDTH: float = 2.6
const PIERCING_VOLLEY_HEAD_LEN: float = 10.0
const PIERCING_VOLLEY_HEAD_HALF_W: float = 5.0
const PIERCING_VOLLEY_DELAY: float = 0.04
const PIERCING_VOLLEY_SPAN: float = 0.50
const PIERCING_VOLLEY_CORE_COLOR: Color = Color(1.00, 0.92, 0.50, 1.0)
const PIERCING_VOLLEY_GLOW_COLOR: Color = Color(0.98, 0.72, 0.22, 1.0)
const PIERCING_VOLLEY_OUTLINE_COLOR: Color = Color(0.32, 0.18, 0.05, 1.0)

## Charm — 초선 adjacent-enemy turn-waste. No damage; rose/pink palette + 4
## adjacent pulse rings + center pink heart-pulse glow.
const CHARM_CORE_R_MIN: float = 8.0
const CHARM_CORE_R_MAX: float = 28.0
const CHARM_PULSE_R_MIN: float = 5.0
const CHARM_PULSE_R_MAX: float = 24.0
const CHARM_TILE_SIZE: float = 64.0
const CHARM_PULSE_WIDTH: float = 2.4
const CHARM_DELAY: float = 0.10
const CHARM_SPAN: float = 0.60
const CHARM_CORE_COLOR: Color = Color(1.00, 0.74, 0.88, 1.0)
const CHARM_PULSE_COLOR: Color = Color(0.96, 0.50, 0.78, 1.0)
const CHARM_OUTLINE_COLOR: Color = Color(0.36, 0.10, 0.24, 1.0)

## Strategist — 조조 battlefield-wide 15 dmg. Massive indigo expanding ring +
## center flash so the wave reads as "the entire map ate it". Mirrors
## AttackLine.COLOR_STRATEGIST family.
const STRATEGIST_RING_R_MIN: float = 14.0
const STRATEGIST_RING_R_MAX: float = 420.0
const STRATEGIST_RING_WIDTH: float = 4.5
const STRATEGIST_CORE_R_MIN: float = 8.0
const STRATEGIST_CORE_R_MAX: float = 36.0
const STRATEGIST_CORE_COLOR: Color = Color(0.92, 0.86, 1.00, 1.0)
const STRATEGIST_GLOW_COLOR: Color = Color(0.78, 0.66, 0.95, 1.0)  # indigo violet
const STRATEGIST_OUTLINE_COLOR: Color = Color(0.20, 0.12, 0.36, 1.0)

## Naval-strategy — 주유 adjacent STUN. Soft blue water-ripple palette so the
## visual differentiates from thunder_roar (sharp electric bolts to the same
## adjacency). Three concentric ripples per cardinal neighbor.
const NAVAL_TILE_SIZE: float = 64.0
const NAVAL_RIPPLE_COUNT: int = 3
const NAVAL_RIPPLE_STAGGER: float = 0.12
const NAVAL_RIPPLE_R_MIN: float = 6.0
const NAVAL_RIPPLE_R_MAX: float = 26.0
const NAVAL_RIPPLE_WIDTH: float = 2.0
const NAVAL_CORE_COLOR: Color = Color(0.78, 0.92, 1.00, 1.0)
const NAVAL_GLOW_COLOR: Color = Color(0.36, 0.62, 0.92, 1.0)
const NAVAL_OUTLINE_COLOR: Color = Color(0.06, 0.16, 0.36, 1.0)

## Rebel-charge — 위연 self +50% + DEF pierce (dragon_blade mechanic, darker
## palette). Single dark-red crescent slash + blood-red ring at caster. Same
## visual silhouette as dragon_blade but the palette communicates "blade
## waiting for the moment" rather than "righteous champion".
const REBEL_CHARGE_RING_COUNT: int = 2
const REBEL_CHARGE_RING_STAGGER: float = 0.18
const REBEL_CHARGE_RING_R_MIN: float = 12.0
const REBEL_CHARGE_RING_R_MAX: float = 34.0
const REBEL_CHARGE_RING_WIDTH: float = 2.8
const REBEL_CHARGE_SWEEP_RADIUS: float = 32.0
const REBEL_CHARGE_SWEEP_ARC: float = 1.10
const REBEL_CHARGE_SWEEP_WIDTH: float = 5.0
const REBEL_CHARGE_SWEEP_DELAY: float = 0.05
const REBEL_CHARGE_SWEEP_SPAN: float = 0.55
const REBEL_CHARGE_SWEEP_FROM: float = -PI * 0.5
const REBEL_CHARGE_SWEEP_TO: float = PI * 0.5
const REBEL_CHARGE_RING_COLOR: Color = Color(0.78, 0.16, 0.20, 1.0)
const REBEL_CHARGE_SWEEP_COLOR: Color = Color(0.92, 0.38, 0.30, 1.0)
const REBEL_CHARGE_OUTLINE_COLOR: Color = Color(0.24, 0.04, 0.06, 1.0)

## Blunt-strategy — 방통 range-2 AoE (12 dmg + slow). Indigo 2-tile reach ring
## + 4 cardinal dashed strokes communicating "deception sweeps outward".
const BLUNT_RING_RADII: Array[float] = [64.0, 128.0]
const BLUNT_RING_WIDTH: float = 2.4
const BLUNT_DASH_COUNT: int = 4   # cardinal directions
const BLUNT_DASH_INNER_R: float = 20.0
const BLUNT_DASH_OUTER_R: float = 120.0
const BLUNT_DASH_SEGMENT_LEN: float = 9.0
const BLUNT_DASH_GAP_LEN: float = 7.0
const BLUNT_DASH_WIDTH: float = 2.6
const BLUNT_DELAY: float = 0.08
const BLUNT_SPAN: float = 0.62
const BLUNT_CORE_COLOR: Color = Color(0.85, 0.78, 1.00, 1.0)
const BLUNT_GLOW_COLOR: Color = Color(0.62, 0.50, 0.88, 1.0)
const BLUNT_OUTLINE_COLOR: Color = Color(0.14, 0.08, 0.28, 1.0)

## Phoenix-chick — 방통 adjacent heal 25 HP. Warm orange phoenix palette to
## differentiate from inspire (sage green). Caster aura + 4 adjacent rising
## feather pulses.
const PHOENIX_TILE_SIZE: float = 64.0
const PHOENIX_AURA_R_MIN: float = 10.0
const PHOENIX_AURA_R_MAX: float = 28.0
const PHOENIX_FEATHER_HEIGHT: float = 22.0
const PHOENIX_FEATHER_WIDTH: float = 10.0
const PHOENIX_DELAY: float = 0.10
const PHOENIX_SPAN: float = 0.62
const PHOENIX_HOT_COLOR: Color = Color(1.00, 0.86, 0.42, 1.0)
const PHOENIX_MID_COLOR: Color = Color(1.00, 0.50, 0.18, 1.0)
const PHOENIX_DARK_COLOR: Color = Color(0.62, 0.18, 0.06, 1.0)

## Xiliang-charge — 마초 (CAVALRY) 20 dmg in 4 cardinal lines, Manhattan ≤ 3.
## 4 long amber charge lines extending 3 tiles out + dust trail echo flanking
## the main line (matches CAVALRY visual family from AttackLine).
const XILIANG_LINE_INNER_R: float = 14.0
const XILIANG_LINE_OUTER_R: float = 188.0  # ~3 tiles
const XILIANG_LINE_WIDTH: float = 3.6
const XILIANG_LINE_OUTLINE_WIDTH: float = 5.4
const XILIANG_TRAIL_OFFSET: float = 5.0
const XILIANG_DELAY: float = 0.04
const XILIANG_SPAN: float = 0.55
const XILIANG_CORE_COLOR: Color = Color(1.00, 0.92, 0.45, 1.0)
const XILIANG_GLOW_COLOR: Color = Color(0.98, 0.80, 0.42, 1.0)  # CAVALRY amber
const XILIANG_OUTLINE_COLOR: Color = Color(0.32, 0.16, 0.04, 1.0)

## Successor-strategy — 강유 single-ally heal+refund within Manhattan ≤ 4.
## Visual reads as "search-then-bless": indigo radial ring expanding to 4-tile
## reach + center starburst at caster (the strategist scanning the field).
const SUCCESSOR_RING_R_MIN: float = 18.0
const SUCCESSOR_RING_R_MAX: float = 260.0  # ~4-tile reach
const SUCCESSOR_RING_WIDTH: float = 2.8
const SUCCESSOR_STAR_INNER_R: float = 6.0
const SUCCESSOR_STAR_OUTER_R: float = 22.0
const SUCCESSOR_STAR_POINTS: int = 6
const SUCCESSOR_DELAY: float = 0.06
const SUCCESSOR_SPAN: float = 0.70
const SUCCESSOR_CORE_COLOR: Color = Color(0.92, 0.86, 1.00, 1.0)
const SUCCESSOR_GLOW_COLOR: Color = Color(0.62, 0.50, 0.92, 1.0)
const SUCCESSOR_OUTLINE_COLOR: Color = Color(0.18, 0.10, 0.32, 1.0)

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


## Inspire factory — 유비 격려. Adjacent allies get a free action token. Soft
## sage-green pulse spreading from caster to all 8 neighbor cells.
static func make_inspire(accent: Color) -> SkillParticleEffect:
	var e: SkillParticleEffect = SkillParticleEffect.new()
	e._accent = accent
	e._kind = &"inspire"
	return e


## Piercing-volley factory — 황충 다중 화살. 8 radial arrow streaks fanning out.
static func make_piercing_volley(accent: Color) -> SkillParticleEffect:
	var e: SkillParticleEffect = SkillParticleEffect.new()
	e._accent = accent
	e._kind = &"piercing_volley"
	return e


## Charm factory — 초선 매혹. Adjacent enemies waste their turn. Rose-pink
## pulse rings on cardinal neighbors + center heart-pink glow.
static func make_charm(accent: Color) -> SkillParticleEffect:
	var e: SkillParticleEffect = SkillParticleEffect.new()
	e._accent = accent
	e._kind = &"charm"
	return e


## Strategist factory — 조조 책략. Battlefield-wide 15 dmg. Massive indigo
## shockwave expanding well past the visible tile grid.
static func make_strategist(accent: Color) -> SkillParticleEffect:
	var e: SkillParticleEffect = SkillParticleEffect.new()
	e._accent = accent
	e._kind = &"strategist"
	return e


## Naval-strategy factory — 주유 수전책. STUN every Manhattan-1 enemy. Soft
## blue water-ripple palette differentiates from thunder_roar.
static func make_naval_strategy(accent: Color) -> SkillParticleEffect:
	var e: SkillParticleEffect = SkillParticleEffect.new()
	e._accent = accent
	e._kind = &"naval_strategy"
	return e


## Rebel-charge factory — 위연 반골일도. dragon_blade-class self-buff (+50% +
## DEF pierce). Dark-red palette + single crescent slash.
static func make_rebel_charge(accent: Color) -> SkillParticleEffect:
	var e: SkillParticleEffect = SkillParticleEffect.new()
	e._accent = accent
	e._kind = &"rebel_charge"
	return e


## Blunt-strategy factory — 방통 기만전략. Range-2 AoE (12 dmg + slow). Indigo
## 2-tile reach ring + 4 cardinal dashed strokes.
static func make_blunt_strategy(accent: Color) -> SkillParticleEffect:
	var e: SkillParticleEffect = SkillParticleEffect.new()
	e._accent = accent
	e._kind = &"blunt_strategy"
	return e


## Phoenix-chick factory — 방통 봉추. Adjacent ally heal 25. Warm orange
## phoenix palette + 4 adjacent rising feather pulses.
static func make_phoenix_chick(accent: Color) -> SkillParticleEffect:
	var e: SkillParticleEffect = SkillParticleEffect.new()
	e._accent = accent
	e._kind = &"phoenix_chick"
	return e


## Xiliang-charge factory — 마초 서량돌격. 4 cardinal lines × 3 tiles (20 dmg
## each). Amber CAVALRY palette + dust trail echo flanking each charge line.
static func make_xiliang_charge(accent: Color) -> SkillParticleEffect:
	var e: SkillParticleEffect = SkillParticleEffect.new()
	e._accent = accent
	e._kind = &"xiliang_charge"
	return e


## Successor-strategy factory — 강유 후계자 책략. Single-ally heal 25 + action
## refund within Manhattan ≤ 4. Indigo radial scan-ring + center starburst.
static func make_successor_strategy(accent: Color) -> SkillParticleEffect:
	var e: SkillParticleEffect = SkillParticleEffect.new()
	e._accent = accent
	e._kind = &"successor_strategy"
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
		&"inspire":
			_draw_inspire()
		&"piercing_volley":
			_draw_piercing_volley()
		&"charm":
			_draw_charm()
		&"strategist":
			_draw_strategist()
		&"naval_strategy":
			_draw_naval_strategy()
		&"rebel_charge":
			_draw_rebel_charge()
		&"blunt_strategy":
			_draw_blunt_strategy()
		&"phoenix_chick":
			_draw_phoenix_chick()
		&"xiliang_charge":
			_draw_xiliang_charge()
		&"successor_strategy":
			_draw_successor_strategy()
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


func _draw_inspire() -> void:
	# Layer 1: caster center sage aura — soft green glow expanding then
	# fading. Two passes (outer translucent + inner brighter) so the glow
	# feels warm rather than harsh.
	var aura_progress: float = clampf(_progress / 0.70, 0.0, 1.0)
	if aura_progress > 0.0:
		var aura_radius: float = lerp(INSPIRE_AURA_R_MIN, INSPIRE_AURA_R_MAX, aura_progress)
		var aura_alpha: float = sin(aura_progress * PI) * 0.85
		var outer: Color = INSPIRE_AURA_COLOR
		outer.a = aura_alpha * 0.55
		var inner: Color = INSPIRE_PULSE_CORE_COLOR
		inner.a = aura_alpha
		draw_circle(Vector2.ZERO, aura_radius + 6.0, outer)
		draw_circle(Vector2.ZERO, aura_radius, inner)

	# Layer 2: 8 small pulse rings appearing at the 8-neighbor positions
	# (4 cardinal + 4 diagonal at TILE_SIZE). All 8 pulses share timing
	# (the buff applies to all adjacent allies simultaneously). Ring grows
	# R_MIN → R_MAX with sin alpha. Cardinal positions get full TILE_SIZE
	# distance; diagonals are at TILE_SIZE/sqrt(2)·sqrt(2) = TILE_SIZE
	# euclidean — close enough since the grid uses adjacency by tile, not
	# pixel distance (visual reads as "8 neighbors touched").
	var pulse_progress: float = clampf((_progress - INSPIRE_PULSE_DELAY) / INSPIRE_PULSE_SPAN, 0.0, 1.0)
	if pulse_progress > 0.0 and pulse_progress < 1.0:
		var pulse_alpha: float = sin(pulse_progress * PI) * 0.95
		var pulse_radius: float = lerp(INSPIRE_PULSE_R_MIN, INSPIRE_PULSE_R_MAX, pulse_progress)
		var t: float = INSPIRE_TILE_SIZE
		var d: float = INSPIRE_TILE_SIZE * 0.7071  # diagonal at ~1-tile euclidean
		var neighbors: Array[Vector2] = [
			Vector2(t, 0.0), Vector2(-t, 0.0), Vector2(0.0, t), Vector2(0.0, -t),
			Vector2(d, d), Vector2(-d, d), Vector2(d, -d), Vector2(-d, -d),
		]
		var pulse_outline: Color = INSPIRE_OUTLINE_COLOR
		pulse_outline.a = pulse_alpha * 0.7
		var pulse_core: Color = INSPIRE_PULSE_CORE_COLOR
		pulse_core.a = pulse_alpha
		for n: Vector2 in neighbors:
			draw_arc(n, pulse_radius + 1.0, 0.0, TAU, 20, pulse_outline, INSPIRE_PULSE_WIDTH + 1.2, true)
			draw_arc(n, pulse_radius, 0.0, TAU, 20, pulse_core, INSPIRE_PULSE_WIDTH, true)


func _draw_piercing_volley() -> void:
	# 8 radial arrow streaks growing inner_R → outer_R across the sweep
	# window. Each arrow gets a shaft (3-pass: outline+glow+core) + a small
	# arrowhead triangle at the tip.
	var sweep: float = clampf((_progress - PIERCING_VOLLEY_DELAY) / PIERCING_VOLLEY_SPAN, 0.0, 1.0)
	if sweep <= 0.0 or sweep >= 1.0:
		return
	var alpha: float = sin(sweep * PI) * 0.95
	var tip_r: float = lerp(PIERCING_VOLLEY_INNER_R + 12.0, PIERCING_VOLLEY_OUTER_R, sweep)
	var outline_c: Color = PIERCING_VOLLEY_OUTLINE_COLOR
	outline_c.a = alpha * 0.85
	var glow_c: Color = PIERCING_VOLLEY_GLOW_COLOR
	glow_c.a = alpha * 0.80
	var core_c: Color = PIERCING_VOLLEY_CORE_COLOR
	core_c.a = alpha
	for arrow_idx: int in PIERCING_VOLLEY_ARROW_COUNT:
		var theta: float = TAU * float(arrow_idx) / float(PIERCING_VOLLEY_ARROW_COUNT)
		var dir: Vector2 = Vector2(cos(theta), sin(theta))
		var perp: Vector2 = dir.rotated(PI * 0.5)
		var inner: Vector2 = dir * PIERCING_VOLLEY_INNER_R
		var tip: Vector2 = dir * tip_r
		draw_line(inner, tip, outline_c, PIERCING_VOLLEY_WIDTH + 2.0, true)
		draw_line(inner, tip, glow_c, PIERCING_VOLLEY_WIDTH + 1.0, true)
		draw_line(inner, tip, core_c, PIERCING_VOLLEY_WIDTH, true)
		# Arrowhead triangle at the tip
		var head_base: Vector2 = tip - dir * PIERCING_VOLLEY_HEAD_LEN
		var head_l: Vector2 = head_base + perp * PIERCING_VOLLEY_HEAD_HALF_W
		var head_r: Vector2 = head_base - perp * PIERCING_VOLLEY_HEAD_HALF_W
		draw_polygon(PackedVector2Array([tip, head_l, head_r]), PackedColorArray([core_c, glow_c, glow_c]))


func _draw_charm() -> void:
	# Caster center pink glow.
	var core_p: float = clampf(_progress / 0.50, 0.0, 1.0)
	if core_p > 0.0:
		var r: float = lerp(CHARM_CORE_R_MIN, CHARM_CORE_R_MAX, core_p)
		var a: float = sin(core_p * PI) * 0.95
		var outer: Color = CHARM_PULSE_COLOR
		outer.a = a * 0.55
		var inner: Color = CHARM_CORE_COLOR
		inner.a = a
		draw_circle(Vector2.ZERO, r + 6.0, outer)
		draw_circle(Vector2.ZERO, r, inner)
	# 4 cardinal adjacent pink pulse rings (Manhattan-1 victims).
	var pulse_p: float = clampf((_progress - CHARM_DELAY) / CHARM_SPAN, 0.0, 1.0)
	if pulse_p > 0.0 and pulse_p < 1.0:
		var alpha: float = sin(pulse_p * PI) * 0.95
		var radius: float = lerp(CHARM_PULSE_R_MIN, CHARM_PULSE_R_MAX, pulse_p)
		var t: float = CHARM_TILE_SIZE
		var positions: Array[Vector2] = [
			Vector2(t, 0.0), Vector2(-t, 0.0), Vector2(0.0, t), Vector2(0.0, -t)
		]
		var outline_c: Color = CHARM_OUTLINE_COLOR
		outline_c.a = alpha * 0.7
		var core_c: Color = CHARM_CORE_COLOR
		core_c.a = alpha
		for p: Vector2 in positions:
			draw_arc(p, radius + 1.0, 0.0, TAU, 20, outline_c, CHARM_PULSE_WIDTH + 1.2, true)
			draw_arc(p, radius, 0.0, TAU, 20, core_c, CHARM_PULSE_WIDTH, true)


func _draw_strategist() -> void:
	# Layer 1: center indigo flash (R_MIN → R_MAX in first ~25%).
	var core_p: float = clampf(_progress / 0.30, 0.0, 1.0)
	if core_p > 0.0:
		var r: float = lerp(STRATEGIST_CORE_R_MIN, STRATEGIST_CORE_R_MAX, core_p)
		var a: float = sin(core_p * PI) * 0.95
		var glow: Color = STRATEGIST_GLOW_COLOR
		glow.a = a * 0.7
		var core: Color = STRATEGIST_CORE_COLOR
		core.a = a
		draw_circle(Vector2.ZERO, r + 8.0, glow)
		draw_circle(Vector2.ZERO, r, core)
	# Layer 2: massive expanding indigo ring covering the whole battlefield.
	var ring_p: float = _progress  # full duration
	if ring_p > 0.0 and ring_p < 1.0:
		var radius: float = lerp(STRATEGIST_RING_R_MIN, STRATEGIST_RING_R_MAX, ring_p)
		var alpha: float = (1.0 - ring_p) * 0.85
		var ring_outline: Color = STRATEGIST_OUTLINE_COLOR
		ring_outline.a = alpha * 0.8
		var ring_glow: Color = STRATEGIST_GLOW_COLOR
		ring_glow.a = alpha
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, ring_outline, STRATEGIST_RING_WIDTH + 2.0, true)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, ring_glow, STRATEGIST_RING_WIDTH, true)


func _draw_naval_strategy() -> void:
	# 4 cardinal positions, each with 3 staggered concentric ripples that
	# expand outward + fade. Reads as "water ripples spreading from each
	# stunned target". Distinct from thunder_roar's sharp bolts.
	var t: float = NAVAL_TILE_SIZE
	var positions: Array[Vector2] = [
		Vector2(t, 0.0), Vector2(-t, 0.0), Vector2(0.0, t), Vector2(0.0, -t)
	]
	for ripple_idx: int in NAVAL_RIPPLE_COUNT:
		var stagger: float = float(ripple_idx) * NAVAL_RIPPLE_STAGGER
		var span: float = 1.0 - stagger
		if span <= 0.0:
			continue
		var ripple_p: float = clampf((_progress - stagger) / span, 0.0, 1.0)
		if ripple_p <= 0.0 or ripple_p >= 1.0:
			continue
		var radius: float = lerp(NAVAL_RIPPLE_R_MIN, NAVAL_RIPPLE_R_MAX, ripple_p)
		var alpha: float = (1.0 - ripple_p) * 0.85
		var glow: Color = NAVAL_GLOW_COLOR
		glow.a = alpha
		var core: Color = NAVAL_CORE_COLOR
		core.a = alpha * 0.9
		for p: Vector2 in positions:
			draw_arc(p, radius + 1.0, 0.0, TAU, 24, glow, NAVAL_RIPPLE_WIDTH + 1.0, true)
			draw_arc(p, radius, 0.0, TAU, 24, core, NAVAL_RIPPLE_WIDTH, true)


func _draw_rebel_charge() -> void:
	# Layer 1: 2 staggered dark-red rings (mirror of dragon_blade but darker
	# palette + only 2 rings — leaner silhouette communicates "a single
	# deliberate moment", not the multi-pulse champion glow).
	for i: int in REBEL_CHARGE_RING_COUNT:
		var stagger: float = float(i) * REBEL_CHARGE_RING_STAGGER
		var span: float = 1.0 - stagger
		if span <= 0.0:
			continue
		var p: float = clampf((_progress - stagger) / span, 0.0, 1.0)
		if p <= 0.0:
			continue
		var radius: float = lerp(REBEL_CHARGE_RING_R_MIN, REBEL_CHARGE_RING_R_MAX, p)
		var alpha: float = (1.0 - p) * 0.90
		var ring_c: Color = REBEL_CHARGE_RING_COLOR
		ring_c.a = alpha
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, ring_c, REBEL_CHARGE_RING_WIDTH, true)
	# Layer 2: single dark-red crescent slash — mirror of dragon_blade sweep
	# but tighter angular range (vertical sweep, top → bottom).
	var sweep_p: float = clampf((_progress - REBEL_CHARGE_SWEEP_DELAY) / REBEL_CHARGE_SWEEP_SPAN, 0.0, 1.0)
	if sweep_p > 0.0 and sweep_p < 1.0:
		var center: float = lerp(REBEL_CHARGE_SWEEP_FROM, REBEL_CHARGE_SWEEP_TO, sweep_p)
		var s_start: float = center - REBEL_CHARGE_SWEEP_ARC * 0.5
		var s_end: float = center + REBEL_CHARGE_SWEEP_ARC * 0.5
		var alpha: float = sin(sweep_p * PI) * 0.95
		var outline_c: Color = REBEL_CHARGE_OUTLINE_COLOR
		outline_c.a = alpha * 0.85
		var sweep_c: Color = REBEL_CHARGE_SWEEP_COLOR
		sweep_c.a = alpha
		draw_arc(Vector2.ZERO, REBEL_CHARGE_SWEEP_RADIUS, s_start, s_end, 24, outline_c, REBEL_CHARGE_SWEEP_WIDTH + 1.6, true)
		draw_arc(Vector2.ZERO, REBEL_CHARGE_SWEEP_RADIUS, s_start, s_end, 24, sweep_c, REBEL_CHARGE_SWEEP_WIDTH, true)


func _draw_blunt_strategy() -> void:
	# Layer 1: 2 concentric indigo rings at radii 1 + 2 tiles. Both share
	# the same timing window — appear together, fade together. Reads as
	# "the deception envelopes the field within 2 tiles".
	var p: float = clampf((_progress - BLUNT_DELAY) / BLUNT_SPAN, 0.0, 1.0)
	if p <= 0.0 or p >= 1.0:
		return
	var alpha: float = sin(p * PI) * 0.92
	var outline_c: Color = BLUNT_OUTLINE_COLOR
	outline_c.a = alpha * 0.8
	var glow_c: Color = BLUNT_GLOW_COLOR
	glow_c.a = alpha
	for radius: float in BLUNT_RING_RADII:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, outline_c, BLUNT_RING_WIDTH + 1.4, true)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, glow_c, BLUNT_RING_WIDTH, true)
	# Layer 2: 4 cardinal dashed strokes from inner_R to outer_R. Each stroke
	# is a series of short segments + gaps along the radial direction.
	var step: float = BLUNT_DASH_SEGMENT_LEN + BLUNT_DASH_GAP_LEN
	var stroke_len: float = BLUNT_DASH_OUTER_R - BLUNT_DASH_INNER_R
	var dash_count: int = int(stroke_len / step)
	var core_c: Color = BLUNT_CORE_COLOR
	core_c.a = alpha
	for dash_idx: int in BLUNT_DASH_COUNT:
		var theta: float = TAU * float(dash_idx) / float(BLUNT_DASH_COUNT)
		var dir: Vector2 = Vector2(cos(theta), sin(theta))
		for seg_idx: int in (dash_count + 1):
			var seg_start_d: float = BLUNT_DASH_INNER_R + float(seg_idx) * step
			var seg_end_d: float = minf(seg_start_d + BLUNT_DASH_SEGMENT_LEN, BLUNT_DASH_OUTER_R)
			if seg_start_d >= BLUNT_DASH_OUTER_R:
				break
			var a: Vector2 = dir * seg_start_d
			var b: Vector2 = dir * seg_end_d
			draw_line(a, b, outline_c, BLUNT_DASH_WIDTH + 1.4, true)
			draw_line(a, b, core_c, BLUNT_DASH_WIDTH, true)


func _draw_phoenix_chick() -> void:
	# Layer 1: caster center warm-orange aura.
	var aura_p: float = clampf(_progress / 0.60, 0.0, 1.0)
	if aura_p > 0.0:
		var r: float = lerp(PHOENIX_AURA_R_MIN, PHOENIX_AURA_R_MAX, aura_p)
		var a: float = sin(aura_p * PI) * 0.90
		var dark: Color = PHOENIX_DARK_COLOR
		dark.a = a * 0.5
		var mid: Color = PHOENIX_MID_COLOR
		mid.a = a * 0.9
		var hot: Color = PHOENIX_HOT_COLOR
		hot.a = a
		draw_circle(Vector2.ZERO, r + 7.0, dark)
		draw_circle(Vector2.ZERO, r + 2.0, mid)
		draw_circle(Vector2.ZERO, r, hot)
	# Layer 2: 4 adjacent phoenix-feather pulses — tear-drop triangles
	# pointing UP (rising flame motif) at each cardinal Manhattan-1 tile.
	var pulse_p: float = clampf((_progress - PHOENIX_DELAY) / PHOENIX_SPAN, 0.0, 1.0)
	if pulse_p > 0.0 and pulse_p < 1.0:
		var alpha: float = sin(pulse_p * PI) * 0.95
		var scale: float = sin(pulse_p * PI) * 1.0
		if scale > 0.0:
			var t: float = PHOENIX_TILE_SIZE
			var positions: Array[Vector2] = [
				Vector2(t, 0.0), Vector2(-t, 0.0), Vector2(0.0, t), Vector2(0.0, -t)
			]
			for pos: Vector2 in positions:
				_draw_phoenix_feather(pos, scale, alpha)


func _draw_phoenix_feather(pos: Vector2, scale: float, alpha: float) -> void:
	# Tear-drop pointing UP. Up = negative Y in screen space.
	var tip: Vector2 = pos + Vector2(0.0, -PHOENIX_FEATHER_HEIGHT * scale)
	var base_l: Vector2 = pos + Vector2(-PHOENIX_FEATHER_WIDTH * 0.5 * scale, 0.0)
	var base_r: Vector2 = pos + Vector2(PHOENIX_FEATHER_WIDTH * 0.5 * scale, 0.0)
	var inner_tip: Vector2 = pos + Vector2(0.0, -PHOENIX_FEATHER_HEIGHT * scale * 0.70)
	var inner_l: Vector2 = pos + Vector2(-PHOENIX_FEATHER_WIDTH * 0.22 * scale, 0.0)
	var inner_r: Vector2 = pos + Vector2(PHOENIX_FEATHER_WIDTH * 0.22 * scale, 0.0)
	var dark: Color = PHOENIX_DARK_COLOR
	dark.a = alpha * 0.65
	var mid: Color = PHOENIX_MID_COLOR
	mid.a = alpha
	var hot: Color = PHOENIX_HOT_COLOR
	hot.a = alpha
	draw_polygon(PackedVector2Array([tip, base_r, base_l]), PackedColorArray([mid, dark, dark]))
	draw_polygon(PackedVector2Array([inner_tip, inner_r, inner_l]), PackedColorArray([hot, mid, mid]))


func _draw_xiliang_charge() -> void:
	# 4 cardinal CAVALRY charge lines extending 3 tiles. Each line: outline
	# + glow + core + 2 dust trail echoes flanking the main line (mirrors
	# AttackLine CAVALRY style — speed-trail metaphor).
	var sweep: float = clampf((_progress - XILIANG_DELAY) / XILIANG_SPAN, 0.0, 1.0)
	if sweep <= 0.0 or sweep >= 1.0:
		return
	var alpha: float = sin(sweep * PI) * 0.95
	var tip_r: float = lerp(XILIANG_LINE_INNER_R + 16.0, XILIANG_LINE_OUTER_R, sweep)
	var outline_c: Color = XILIANG_OUTLINE_COLOR
	outline_c.a = alpha * 0.85
	var glow_c: Color = XILIANG_GLOW_COLOR
	glow_c.a = alpha * 0.80
	var core_c: Color = XILIANG_CORE_COLOR
	core_c.a = alpha
	var echo_c: Color = XILIANG_GLOW_COLOR
	echo_c.a = alpha * 0.55
	var cardinals: Array[Vector2] = [
		Vector2(1.0, 0.0), Vector2(-1.0, 0.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0)
	]
	for dir: Vector2 in cardinals:
		var perp: Vector2 = dir.rotated(PI * 0.5) * XILIANG_TRAIL_OFFSET
		var inner: Vector2 = dir * XILIANG_LINE_INNER_R
		var tip: Vector2 = dir * tip_r
		# Dust trail echoes flanking the main strike
		draw_line(inner + perp, tip + perp, echo_c, XILIANG_LINE_WIDTH * 0.55, true)
		draw_line(inner - perp, tip - perp, echo_c, XILIANG_LINE_WIDTH * 0.55, true)
		# Main charge line
		draw_line(inner, tip, outline_c, XILIANG_LINE_OUTLINE_WIDTH, true)
		draw_line(inner, tip, glow_c, XILIANG_LINE_WIDTH + 1.2, true)
		draw_line(inner, tip, core_c, XILIANG_LINE_WIDTH, true)


func _draw_successor_strategy() -> void:
	# Layer 1: expanding indigo ring up to 4-tile reach. Reads as "search
	# wave looking for the most-wounded ally". Lighter indigo than 조조
	# strategist to differentiate.
	var ring_p: float = _progress  # full duration
	if ring_p > 0.0 and ring_p < 1.0:
		var radius: float = lerp(SUCCESSOR_RING_R_MIN, SUCCESSOR_RING_R_MAX, ring_p)
		var alpha: float = (1.0 - ring_p) * 0.85
		var outline_c: Color = SUCCESSOR_OUTLINE_COLOR
		outline_c.a = alpha * 0.8
		var glow_c: Color = SUCCESSOR_GLOW_COLOR
		glow_c.a = alpha
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, outline_c, SUCCESSOR_RING_WIDTH + 1.6, true)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 48, glow_c, SUCCESSOR_RING_WIDTH, true)
	# Layer 2: 6-pointed starburst at caster (the strategist's signature
	# inflection point) — alternating inner + outer radii forms star shape.
	var star_p: float = clampf((_progress - SUCCESSOR_DELAY) / SUCCESSOR_SPAN, 0.0, 1.0)
	if star_p > 0.0 and star_p < 1.0:
		var alpha: float = sin(star_p * PI) * 0.95
		var scale: float = sin(star_p * PI)
		if scale > 0.0:
			var inner_r: float = SUCCESSOR_STAR_INNER_R * scale
			var outer_r: float = SUCCESSOR_STAR_OUTER_R * scale
			var points: PackedVector2Array = PackedVector2Array()
			var samples: int = SUCCESSOR_STAR_POINTS * 2
			for i: int in samples:
				var theta: float = TAU * float(i) / float(samples) - PI * 0.5
				var r: float = outer_r if (i % 2 == 0) else inner_r
				points.append(Vector2(cos(theta), sin(theta)) * r)
			points.append(points[0])  # close shape
			var outline_c: Color = SUCCESSOR_OUTLINE_COLOR
			outline_c.a = alpha * 0.85
			var glow_c: Color = SUCCESSOR_GLOW_COLOR
			glow_c.a = alpha
			var core_c: Color = SUCCESSOR_CORE_COLOR
			core_c.a = alpha
			draw_polyline(points, outline_c, 3.6, true)
			draw_polyline(points, glow_c, 2.4, true)
			draw_polyline(points, core_c, 1.4, true)
