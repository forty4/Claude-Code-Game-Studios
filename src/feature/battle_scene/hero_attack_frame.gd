## HeroAttackFrame — per-hero basic-attack visual signature layered on top of
## the class-level AttackLine. Sibling to AttackLine / SkillParticleEffect /
## DamagePopup. Mounted by battle_scene._on_damage_applied after the AttackLine
## mount; resolves attacker hero_id via grid_controller.get_battle_unit().
##
## Position semantic: the node is positioned at the DEFENDER tile. _from_local
## is the attacker offset in node-local space (i.e. `attacker_world - defender_world`).
## This lets at-defender flourishes draw at Vector2.ZERO while from→to strokes
## use _from_local as the origin point.
##
## Session-89 — Phase 4 hero attack frame, first 5 heroes (Shu trio + Zhao Yun
## + Zhuge Liang). Each gets its own _kind / static factory / _draw_<hero>.
## Procedural _draw() per the AttackLine + SkillParticleEffect reference family.
## DURATION ~0.30s — shorter than skill particles (0.70s) because basic attacks
## fire frequently and a longer visual would stack / read as clutter.
##
## Visual concept summary (per Pillar #3 + #4 — role differentiation + Spirit
## of Three Kingdoms; weapon-specific signature for each hero):
##   shu_001_liu_bei    twin_blade_cross  雙股劍 → 2 crossing sword strokes (X)
##   shu_002_guan_yu    crescent_arc      청룡언월도 → golden sweep arc
##   shu_003_zhang_fei  spear_thrust      장팔사모 → red thrust + impact star
##   shu_005_zhao_yun   lance_dash        龍膽槍 → 3 parallel cyan slashes
##   shu_006_zhuge_liang fan_glyph        羽扇 → indigo glyph circle + sparks
##
## Differentiation vs skill_particle_effect: skill particles are caster-centered
## (yellow rings at 관우, sage pulse at 유비, indigo wave at 제갈량). Attack
## frames are defender-centered (X cross at target, golden sweep at target,
## indigo glyph at target). No visual confusion because the kinds differ in
## both shape AND anchor.
class_name HeroAttackFrame
extends Node2D

const DURATION: float = 0.30

# ─── Twin-blade-cross — 유비 雙股劍 ──────────────────────────────────────────
# Two parallel sword strokes meeting in an X at defender position. Cream-gold
# palette matches COMMANDER family (AttackLine.COLOR_COMMANDER baseline) so
# the hero frame layers cleanly on the class line.
const TBC_SWORD_LEN: float = 36.0
const TBC_SWORD_SEPARATION: float = 14.0  # perpendicular offset between the 2 swords
const TBC_SWORD_WIDTH: float = 3.2
const TBC_SWORD_OUTLINE_WIDTH: float = 4.8
const TBC_DELAY: float = 0.04
const TBC_SPAN: float = 0.60
const TBC_CORE_COLOR: Color = Color(0.99, 0.94, 0.65, 1.0)    # warm cream
const TBC_GLOW_COLOR: Color = Color(0.98, 0.86, 0.42, 1.0)    # COMMANDER gold
const TBC_OUTLINE_COLOR: Color = Color(0.20, 0.12, 0.04, 1.0)  # ink stroke

# ─── Crescent-arc — 관우 청룡언월도 ──────────────────────────────────────────
# Large golden crescent sweeping at defender. Distinct from skill_dragon_blade
# (rings at caster) — this is a single bold arc at the impact point.
const CA_RADIUS: float = 38.0
const CA_ARC: float = 1.15            # rad; ~66° crescent (wider than skill sweep)
const CA_WIDTH: float = 5.0
const CA_OUTLINE_WIDTH: float = 7.0
const CA_DELAY: float = 0.03
const CA_SPAN: float = 0.70
const CA_FROM: float = -PI * 0.75     # start angle (above-left)
const CA_TO: float = PI * 0.25        # end angle (below-right)
const CA_CORE_COLOR: Color = Color(1.00, 0.95, 0.55, 1.0)
const CA_GLOW_COLOR: Color = Color(1.00, 0.82, 0.32, 1.0)
const CA_OUTLINE_COLOR: Color = Color(0.28, 0.16, 0.04, 1.0)

# ─── Spear-thrust — 장비 장팔사모 ────────────────────────────────────────────
# Bold red thrust line from attacker direction into defender + impact starburst
# (4 short radial spokes) at defender. Reads as "powerful piercing thrust".
const ST_LINE_WIDTH: float = 5.0
const ST_LINE_OUTLINE_WIDTH: float = 7.0
const ST_LINE_DELAY: float = 0.00
const ST_LINE_SPAN: float = 0.45
const ST_STAR_DELAY: float = 0.20
const ST_STAR_SPAN: float = 0.55
const ST_STAR_SPOKES: int = 4
const ST_STAR_INNER_R: float = 8.0
const ST_STAR_OUTER_R: float = 22.0
const ST_STAR_WIDTH: float = 3.0
const ST_STAR_OUTLINE_WIDTH: float = 4.4
const ST_CORE_COLOR: Color = Color(1.00, 0.78, 0.65, 1.0)     # blood-pink core
const ST_GLOW_COLOR: Color = Color(0.92, 0.22, 0.18, 1.0)     # deep red
const ST_OUTLINE_COLOR: Color = Color(0.32, 0.04, 0.02, 1.0)  # blood-ink

# ─── Lance-dash — 조운 龍膽槍 ────────────────────────────────────────────────
# Three parallel cyan slashes between attacker and defender — reads as
# "rapid spear flurry". Cyan palette matches SCOUT class family.
const LD_SLASH_COUNT: int = 3
const LD_SLASH_OFFSET: float = 7.0    # perpendicular offset of outer slashes
const LD_SLASH_WIDTH: float = 2.8
const LD_SLASH_OUTLINE_WIDTH: float = 4.2
const LD_SLASH_STAGGER: float = 0.07  # each slash starts this much later
const LD_SLASH_SPAN: float = 0.45
# Spark at defender — small cyan cross at impact
const LD_SPARK_DELAY: float = 0.18
const LD_SPARK_SPAN: float = 0.50
const LD_SPARK_LEN: float = 12.0
const LD_SPARK_WIDTH: float = 2.6
const LD_CORE_COLOR: Color = Color(0.88, 0.99, 1.00, 1.0)     # icy white
const LD_GLOW_COLOR: Color = Color(0.45, 0.92, 0.96, 1.0)     # SCOUT cyan
const LD_OUTLINE_COLOR: Color = Color(0.08, 0.22, 0.32, 1.0)

# ─── Fan-glyph — 제갈량 羽扇 ─────────────────────────────────────────────────
# Indigo glyph circle at defender + 4 short radial spark lines. Reads as
# "magic strike from afar" — no projectile trail (the STRATEGIST class line
# already provides the dashed zap connection). 4 spokes oriented diagonally
# (NE/NW/SE/SW) to differentiate from spear_thrust's cardinal star.
const FG_RING_RADIUS: float = 24.0
const FG_RING_WIDTH: float = 2.8
const FG_RING_OUTLINE_WIDTH: float = 4.2
const FG_RING_DELAY: float = 0.04
const FG_RING_SPAN: float = 0.65
# Glyph cross-bars inside the ring (vertical + horizontal short strokes)
const FG_GLYPH_BAR_LEN: float = 18.0
const FG_GLYPH_BAR_WIDTH: float = 2.2
const FG_GLYPH_DELAY: float = 0.12
const FG_GLYPH_SPAN: float = 0.55
# 4 diagonal sparks radiating outward
const FG_SPARK_COUNT: int = 4
const FG_SPARK_INNER_R: float = 28.0
const FG_SPARK_OUTER_R: float = 44.0
const FG_SPARK_WIDTH: float = 2.4
const FG_SPARK_DELAY: float = 0.18
const FG_SPARK_SPAN: float = 0.55
const FG_CORE_COLOR: Color = Color(0.92, 0.86, 1.00, 1.0)     # pale violet
const FG_GLOW_COLOR: Color = Color(0.62, 0.50, 0.94, 1.0)     # STRATEGIST indigo
const FG_OUTLINE_COLOR: Color = Color(0.16, 0.08, 0.30, 1.0)


var _kind: StringName = &""
var _progress: float = 0.0
## Attacker world position relative to this node (which sits at defender).
## i.e. `_from_local = attacker_world - defender_world`. For at-defender
## flourishes the attacker direction is _from_local.normalized().
var _from_local: Vector2 = Vector2.ZERO


# ─── Static factories ────────────────────────────────────────────────────────


## 유비 (shu_001) — twin sword X cross at defender.
static func make_twin_blade_cross(from_local: Vector2) -> HeroAttackFrame:
	var e: HeroAttackFrame = HeroAttackFrame.new()
	e._kind = &"twin_blade_cross"
	e._from_local = from_local
	return e


## 관우 (shu_002) — golden crescent sweep arc at defender.
static func make_crescent_arc(from_local: Vector2) -> HeroAttackFrame:
	var e: HeroAttackFrame = HeroAttackFrame.new()
	e._kind = &"crescent_arc"
	e._from_local = from_local
	return e


## 장비 (shu_003) — red spear thrust line + impact starburst.
static func make_spear_thrust(from_local: Vector2) -> HeroAttackFrame:
	var e: HeroAttackFrame = HeroAttackFrame.new()
	e._kind = &"spear_thrust"
	e._from_local = from_local
	return e


## 조운 (shu_005) — 3 parallel cyan slashes from attacker to defender.
static func make_lance_dash(from_local: Vector2) -> HeroAttackFrame:
	var e: HeroAttackFrame = HeroAttackFrame.new()
	e._kind = &"lance_dash"
	e._from_local = from_local
	return e


## 제갈량 (shu_006) — indigo glyph ring + diagonal sparks at defender.
static func make_fan_glyph(from_local: Vector2) -> HeroAttackFrame:
	var e: HeroAttackFrame = HeroAttackFrame.new()
	e._kind = &"fan_glyph"
	e._from_local = from_local
	return e


## Dispatch factory — returns null for unsupported hero_ids so the caller can
## skip the mount gracefully without breaking the rest of the visual stack.
## The supported set is the 5 main player heroes (Shu trio + Zhao Yun + Zhuge
## Liang); future heroes get added one at a time per the active.md handoff.
static func make_for_hero(from_local: Vector2, hero_id: StringName) -> HeroAttackFrame:
	match hero_id:
		&"shu_001_liu_bei":      return make_twin_blade_cross(from_local)
		&"shu_002_guan_yu":      return make_crescent_arc(from_local)
		&"shu_003_zhang_fei":    return make_spear_thrust(from_local)
		&"shu_005_zhao_yun":     return make_lance_dash(from_local)
		&"shu_006_zhuge_liang":  return make_fan_glyph(from_local)
		_:                       return null


# ─── Lifecycle ───────────────────────────────────────────────────────────────


func _ready() -> void:
	_animate()


func _animate() -> void:
	# Tree-bound tween per G-31. ChapterVisuals lives at /root so its
	# process_mode is independent of BattleScene, but tree-binding is the safe
	# default across every popup/effect in this family.
	var tween: Tween = get_tree().create_tween()
	tween.tween_property(self, "_progress", 1.0, DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)


func _process(_dt: float) -> void:
	queue_redraw()


func _draw() -> void:
	match _kind:
		&"twin_blade_cross":
			_draw_twin_blade_cross()
		&"crescent_arc":
			_draw_crescent_arc()
		&"spear_thrust":
			_draw_spear_thrust()
		&"lance_dash":
			_draw_lance_dash()
		&"fan_glyph":
			_draw_fan_glyph()
		_:
			pass


# ─── Style implementations ───────────────────────────────────────────────────


## 유비 — two perpendicular cream-gold sword strokes forming an X at defender.
## Both strokes appear simultaneously in a single sin(progress·PI) bloom so the
## cross reads as one decisive double-cut.
func _draw_twin_blade_cross() -> void:
	var p: float = clampf((_progress - TBC_DELAY) / TBC_SPAN, 0.0, 1.0)
	if p <= 0.0 or p >= 1.0:
		return
	var alpha: float = sin(p * PI)
	# Orient the X 45° from cardinal (so it's a diagonal cross, not a + sign).
	var dir_a: Vector2 = Vector2(1.0, 1.0).normalized()
	var dir_b: Vector2 = Vector2(1.0, -1.0).normalized()
	# Slight inward growth: short at start, full at peak.
	var half_len: float = TBC_SWORD_LEN * 0.5 * (0.6 + 0.4 * p)
	# Sword A — top-left to bottom-right
	var a1: Vector2 = -dir_a * half_len
	var a2: Vector2 =  dir_a * half_len
	# Sword B — top-right to bottom-left
	var b1: Vector2 = -dir_b * half_len
	var b2: Vector2 =  dir_b * half_len
	# 3-pass: outline + glow + core for readability against any terrain.
	var oc: Color = TBC_OUTLINE_COLOR; oc.a = alpha * 0.85
	var gc: Color = TBC_GLOW_COLOR;    gc.a = alpha * 0.85
	var cc: Color = TBC_CORE_COLOR;    cc.a = alpha
	for stroke: Array in [[a1, a2], [b1, b2]]:
		var s: Vector2 = stroke[0]
		var e: Vector2 = stroke[1]
		draw_line(s, e, oc, TBC_SWORD_OUTLINE_WIDTH, true)
		draw_line(s, e, gc, TBC_SWORD_WIDTH + 1.2, true)
		draw_line(s, e, cc, TBC_SWORD_WIDTH, true)


## 관우 — single large golden crescent arc sweeping at defender. Mirrors
## skill_dragon_blade's sweep but anchored at defender + wider arc + bolder
## width so the basic attack reads as the polearm's reach landing on target.
func _draw_crescent_arc() -> void:
	var p: float = clampf((_progress - CA_DELAY) / CA_SPAN, 0.0, 1.0)
	if p <= 0.0 or p >= 1.0:
		return
	var sweep_center: float = lerp(CA_FROM, CA_TO, p)
	var sweep_start: float = sweep_center - CA_ARC * 0.5
	var sweep_end: float = sweep_center + CA_ARC * 0.5
	var alpha: float = sin(p * PI)
	var oc: Color = CA_OUTLINE_COLOR; oc.a = alpha * 0.80
	var gc: Color = CA_GLOW_COLOR;    gc.a = alpha * 0.90
	var cc: Color = CA_CORE_COLOR;    cc.a = alpha
	draw_arc(Vector2.ZERO, CA_RADIUS, sweep_start, sweep_end, 28, oc, CA_OUTLINE_WIDTH, true)
	draw_arc(Vector2.ZERO, CA_RADIUS, sweep_start, sweep_end, 28, gc, CA_WIDTH + 1.4, true)
	draw_arc(Vector2.ZERO, CA_RADIUS, sweep_start, sweep_end, 28, cc, CA_WIDTH, true)


## 장비 — bold red thrust line from attacker direction into defender, followed
## by a 4-spoke impact starburst at defender. Two-stage timing: line first,
## star bursts as the line completes ("strike-then-impact" read).
func _draw_spear_thrust() -> void:
	var dist: float = _from_local.length()
	if dist <= 0.0:
		# Self-attack edge case (shouldn't happen for basic attacks but defensive).
		return
	var dir: Vector2 = _from_local / dist  # points TOWARDS attacker
	# Stage 1 — thrust line from attacker side into defender. Line grows from
	# attacker tip toward defender center; alpha peaks mid-stroke.
	var line_p: float = clampf((_progress - ST_LINE_DELAY) / ST_LINE_SPAN, 0.0, 1.0)
	if line_p > 0.0 and line_p < 1.0:
		var line_alpha: float = sin(line_p * PI)
		# Line extent: starts at attacker side (full distance away), retracts
		# toward defender (Vector2.ZERO) as the thrust lands.
		var line_start: Vector2 = dir * dist * (1.0 - line_p * 0.25)
		var line_end: Vector2 = dir * dist * (1.0 - line_p * 0.90)
		var oc: Color = ST_OUTLINE_COLOR; oc.a = line_alpha * 0.85
		var gc: Color = ST_GLOW_COLOR;    gc.a = line_alpha * 0.90
		var cc: Color = ST_CORE_COLOR;    cc.a = line_alpha
		draw_line(line_start, line_end, oc, ST_LINE_OUTLINE_WIDTH, true)
		draw_line(line_start, line_end, gc, ST_LINE_WIDTH + 1.4, true)
		draw_line(line_start, line_end, cc, ST_LINE_WIDTH, true)
	# Stage 2 — 4-spoke impact starburst at defender. Spokes radiate outward
	# along cardinal directions (N/S/E/W) so the impact reads as "shock force
	# bursting at the hit point", distinct from fan_glyph's diagonal sparks.
	var star_p: float = clampf((_progress - ST_STAR_DELAY) / ST_STAR_SPAN, 0.0, 1.0)
	if star_p > 0.0 and star_p < 1.0:
		var star_alpha: float = sin(star_p * PI)
		var inner_r: float = ST_STAR_INNER_R
		var outer_r: float = lerp(ST_STAR_INNER_R, ST_STAR_OUTER_R, star_p)
		var soc: Color = ST_OUTLINE_COLOR; soc.a = star_alpha * 0.85
		var sgc: Color = ST_GLOW_COLOR;    sgc.a = star_alpha * 0.90
		var scc: Color = ST_CORE_COLOR;    scc.a = star_alpha
		for i: int in ST_STAR_SPOKES:
			var theta: float = TAU * float(i) / float(ST_STAR_SPOKES)
			var sd: Vector2 = Vector2(cos(theta), sin(theta))
			var a: Vector2 = sd * inner_r
			var b: Vector2 = sd * outer_r
			draw_line(a, b, soc, ST_STAR_OUTLINE_WIDTH, true)
			draw_line(a, b, sgc, ST_STAR_WIDTH + 1.0, true)
			draw_line(a, b, scc, ST_STAR_WIDTH, true)


## 조운 — 3 parallel cyan slashes from attacker side to defender, staggered
## in time so the eye reads them as a rapid sequential flurry. Topped with a
## small cyan cross-spark at defender for the impact moment.
func _draw_lance_dash() -> void:
	var dist: float = _from_local.length()
	if dist <= 0.0:
		return
	var dir: Vector2 = _from_local / dist  # TOWARDS attacker
	var perp: Vector2 = dir.rotated(PI * 0.5)
	# 3 slashes: center, +offset, -offset (perpendicular). Each staggered.
	var perp_offsets: Array[float] = [0.0, LD_SLASH_OFFSET, -LD_SLASH_OFFSET]
	for slash_idx: int in LD_SLASH_COUNT:
		var stagger: float = float(slash_idx) * LD_SLASH_STAGGER
		var span: float = LD_SLASH_SPAN
		var p: float = clampf((_progress - stagger) / span, 0.0, 1.0)
		if p <= 0.0 or p >= 1.0:
			continue
		var alpha: float = sin(p * PI)
		var off: float = perp_offsets[slash_idx]
		# Slash retracts from attacker side toward defender as the flurry lands.
		var s: Vector2 = dir * dist * (1.0 - p * 0.20) + perp * off
		var e: Vector2 = dir * dist * (1.0 - p * 0.95) + perp * off
		var oc: Color = LD_OUTLINE_COLOR; oc.a = alpha * 0.85
		var gc: Color = LD_GLOW_COLOR;    gc.a = alpha * 0.90
		var cc: Color = LD_CORE_COLOR;    cc.a = alpha
		draw_line(s, e, oc, LD_SLASH_OUTLINE_WIDTH, true)
		draw_line(s, e, gc, LD_SLASH_WIDTH + 1.2, true)
		draw_line(s, e, cc, LD_SLASH_WIDTH, true)
	# Cross-spark at defender — small "+" shape, peaks late in the window.
	var spark_p: float = clampf((_progress - LD_SPARK_DELAY) / LD_SPARK_SPAN, 0.0, 1.0)
	if spark_p > 0.0 and spark_p < 1.0:
		var sa: float = sin(spark_p * PI)
		var oc: Color = LD_OUTLINE_COLOR; oc.a = sa * 0.85
		var gc: Color = LD_GLOW_COLOR;    gc.a = sa * 0.90
		var cc: Color = LD_CORE_COLOR;    cc.a = sa
		var hl: float = LD_SPARK_LEN * 0.5
		# Vertical + horizontal cross
		for axis: Vector2 in [Vector2(0.0, 1.0), Vector2(1.0, 0.0)]:
			var a: Vector2 = -axis * hl
			var b: Vector2 =  axis * hl
			draw_line(a, b, oc, LD_SPARK_WIDTH + 1.6, true)
			draw_line(a, b, gc, LD_SPARK_WIDTH + 0.8, true)
			draw_line(a, b, cc, LD_SPARK_WIDTH, true)


## 제갈량 — indigo glyph circle at defender + interior cross-bars + 4 diagonal
## sparks radiating outward. Reads as "incantation lands". Three timing layers
## so the glyph appears to draw itself: ring first, bars second, sparks last.
func _draw_fan_glyph() -> void:
	# Layer 1 — outer ring expanding to FG_RING_RADIUS.
	var ring_p: float = clampf((_progress - FG_RING_DELAY) / FG_RING_SPAN, 0.0, 1.0)
	if ring_p > 0.0 and ring_p < 1.0:
		var alpha: float = sin(ring_p * PI)
		var radius: float = FG_RING_RADIUS * (0.4 + 0.6 * ring_p)
		var oc: Color = FG_OUTLINE_COLOR; oc.a = alpha * 0.85
		var gc: Color = FG_GLOW_COLOR;    gc.a = alpha * 0.90
		var cc: Color = FG_CORE_COLOR;    cc.a = alpha
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, oc, FG_RING_OUTLINE_WIDTH, true)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, gc, FG_RING_WIDTH + 1.2, true)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, cc, FG_RING_WIDTH, true)
	# Layer 2 — interior cross-bars (vertical + horizontal short strokes).
	var bar_p: float = clampf((_progress - FG_GLYPH_DELAY) / FG_GLYPH_SPAN, 0.0, 1.0)
	if bar_p > 0.0 and bar_p < 1.0:
		var ba: float = sin(bar_p * PI)
		var hl: float = FG_GLYPH_BAR_LEN * 0.5
		var oc: Color = FG_OUTLINE_COLOR; oc.a = ba * 0.85
		var gc: Color = FG_GLOW_COLOR;    gc.a = ba * 0.90
		var cc: Color = FG_CORE_COLOR;    cc.a = ba
		for axis: Vector2 in [Vector2(0.0, 1.0), Vector2(1.0, 0.0)]:
			var a: Vector2 = -axis * hl
			var b: Vector2 =  axis * hl
			draw_line(a, b, oc, FG_GLYPH_BAR_WIDTH + 1.6, true)
			draw_line(a, b, gc, FG_GLYPH_BAR_WIDTH + 0.8, true)
			draw_line(a, b, cc, FG_GLYPH_BAR_WIDTH, true)
	# Layer 3 — 4 diagonal sparks radiating outward (NE/NW/SE/SW). Distinct
	# from spear_thrust's cardinal star.
	var spark_p: float = clampf((_progress - FG_SPARK_DELAY) / FG_SPARK_SPAN, 0.0, 1.0)
	if spark_p > 0.0 and spark_p < 1.0:
		var sa: float = sin(spark_p * PI)
		var inner_r: float = FG_SPARK_INNER_R
		var outer_r: float = lerp(FG_SPARK_INNER_R, FG_SPARK_OUTER_R, spark_p)
		var oc: Color = FG_OUTLINE_COLOR; oc.a = sa * 0.85
		var gc: Color = FG_GLOW_COLOR;    gc.a = sa * 0.90
		var cc: Color = FG_CORE_COLOR;    cc.a = sa
		for i: int in FG_SPARK_COUNT:
			# Diagonal offsets: rotate cardinal by 45° (PI/4) + iterate by PI/2.
			var theta: float = PI * 0.25 + TAU * float(i) / float(FG_SPARK_COUNT)
			var sd: Vector2 = Vector2(cos(theta), sin(theta))
			var a: Vector2 = sd * inner_r
			var b: Vector2 = sd * outer_r
			draw_line(a, b, oc, FG_SPARK_WIDTH + 1.6, true)
			draw_line(a, b, gc, FG_SPARK_WIDTH + 0.8, true)
			draw_line(a, b, cc, FG_SPARK_WIDTH, true)
