## ChapterVisuals — production-tier world-space tile renderer for chapter `.tscn`
## assets per ADR-0021 §1.
##
## Mounted as a child of BattleScene/GridLayer at STEP 1.5 of the BattleScene
## mount sequence (per ADR-0021 §6 / ADR-0016 §3 amended). Reads a MapResource
## and renders one solid-color rectangle per tile via the canonical Godot
## CanvasItem `_draw()` API.
##
## NOT prototype-tier (per ADR-0021 §4): this script does NOT runtime-construct
## ColorRect / Label nodes; it uses `_draw()` which is the engine's standard
## CanvasItem rendering pathway. Editor-authored .tscn structure (units as
## Polygon2D children of the chapter scene) carries the unit silhouette layer.
##
## Color palette per art-bible §4.1 + §3-3:
##   - Reserved colors (주홍 #C0392B / 금색 #D4A017) MUST NEVER appear here per
##     art-bible §1.지지 원칙 2 + §4.1 "절대 금지" — they are the destiny-branch
##     reveal exclusive signal channels.
##
## Usage:
##   var cv: ChapterVisuals = preload("res://scenes/battle/mvp_chapter_06.tscn") \
##       .instantiate()
##   cv.map_resource = my_map_resource  # set BEFORE add_child for clean _draw()
##   parent.add_child(cv)
##
class_name ChapterVisuals
extends Node2D


## Pixel size of one grid tile. MUST match BalanceConstants.TILE_WORLD_SIZE
## so visuals align with InputRouter/BattleCamera/BattleHUD grid math.
## .tscn unit polygon positions use (col * TILE_SIZE + TILE_SIZE/2, row * TILE_SIZE + TILE_SIZE/2).
const TILE_SIZE: int = 64

## Q4 facing chevron — small arrow pointing east (+x) by default. Local
## rotation rotates it to point in unit.facing direction. Apex at (10, 0),
## base 4px wide on the west side. static var (not const) — Vector2() 가
## runtime constructor 라 const expression 으로 사용 불가; static var 는
## 클래스 로드 시 1회 초기화 (G-25 family — typed-collection 제약 회피).


static var _FRONT_CHEVRON_SHAPE: PackedVector2Array = PackedVector2Array([
	Vector2(10.0, 0.0),    # apex (forward tip)
	Vector2(2.0, -4.0),    # back-top
	Vector2(2.0, 4.0),     # back-bottom
])


## Q4 helper — maps facing enum (0=N, 1=E, 2=S, 3=W per BattleUnit.facing) to
## a unit-vector pointing in that direction in world-space.
static func facing_to_vector(facing: int) -> Vector2:
	match facing:
		0: return Vector2(0.0, -1.0)
		1: return Vector2(1.0, 0.0)
		2: return Vector2(0.0, 1.0)
		3: return Vector2(-1.0, 0.0)
		_: return Vector2(0.0, -1.0)  # defensive default — N

## Color palette (art-bible §4.1 — non-reserved subset only).
const COLOR_PLAINS:        Color = Color("6b8c5a")  # 소록 — natural plains
const COLOR_FOREST:        Color = Color("4a6b3a")  # 소록 어두움 — forest density
const COLOR_HILLS:         Color = Color("a06a30")  # 황토 어두움 — earthen hills
const COLOR_MOUNTAIN:      Color = Color("1c1a17")  # 묵 — mountain mass
const COLOR_RIVER:         Color = Color("4a6878")  # 청회 깊은 — water tactical barrier
const COLOR_BRIDGE:        Color = Color("a0744a")  # 황토 갈색 — wooden bridge tone
const COLOR_FORTRESS_WALL: Color = Color("1c1a17")  # 묵 — solid wall mass
const COLOR_ROAD:          Color = Color("c8b898")  # 지백 어두움 — paved path
const COLOR_FIRE:          Color = Color("c84418")  # 주적 — burning ship debris (session-21 ch5)

## Session-47 — terrain glyph layer (shape-based, S48 amendment). Pre-S47
## windowed users couldn't distinguish HILLS from PLAINS from BRIDGE at a
## glance — muted earth palette read uniformly. S47 first added Hanja glyphs
## (森丘山河橋城道火) but user feedback was "한자를 모르겠어"; S48 replaces
## with primitive shapes that read iconically without language dependency:
##   FOREST       — 3 small triangles (trees clustered)
##   HILLS        — 2 rolling arches (⌒⌒)
##   MOUNTAIN     — 1 large peak triangle
##   RIVER        — 2 horizontal wavy lines (water)
##   BRIDGE       — 2 horizontal rails + 4 vertical planks
##   FORTRESS WALL — crenellation pattern (⊓⊓⊓ battlement)
##   ROAD         — 3 horizontal dashes
##   FIRE         — flame outline (teardrop pointed up)
##
## Color-tiered (semi-transparent so they don't compete with hero polygons):
## dark ink for light-tone tiles, cream ink for dark-tone tiles. Shapes drawn
## via draw_line / draw_polyline / draw_colored_polygon primitives — no font
## dependency, immediate visual recognition regardless of locale.
const _TERRAIN_GLYPH_DARK:   Color = Color(0.08, 0.06, 0.04, 0.55)
const _TERRAIN_GLYPH_BRIGHT: Color = Color(0.96, 0.92, 0.82, 0.65)
## Half-extent of the glyph drawing area, in tile-local px. ~14 → glyph
## occupies ~28×28 in the 64×64 tile, leaving 18px margin on each side.
const _TERRAIN_GLYPH_HALF:   float = 14.0
const _TERRAIN_GLYPH_STROKE: float = 2.2
## Per-terrain glyph color tier — dark ink stays subtle on light tiles, cream
## ink reads against the near-black tiles (MOUNTAIN / FORTRESS_WALL / RIVER).
const _TERRAIN_GLYPH_COLOR_BY_TYPE: Dictionary[int, Color] = {
	1: _TERRAIN_GLYPH_DARK,    # FOREST (green-tone)
	2: _TERRAIN_GLYPH_DARK,    # HILLS (brown-tone)
	3: _TERRAIN_GLYPH_BRIGHT,  # MOUNTAIN (dark-tone)
	4: _TERRAIN_GLYPH_BRIGHT,  # RIVER (blue-gray)
	5: _TERRAIN_GLYPH_DARK,    # BRIDGE (light brown)
	6: _TERRAIN_GLYPH_BRIGHT,  # FORTRESS_WALL (dark)
	7: _TERRAIN_GLYPH_DARK,    # ROAD (beige)
	8: _TERRAIN_GLYPH_DARK,    # FIRE (red)
}
## Tile boundary stroke per art-bible §3-3 "기능 정보는 항상 직선; 타일 경계는
## 명료한 먹선" — load-bearing for tactical-info readability.
const COLOR_TILE_BORDER:   Color = Color("1c1a17")  # 묵 — clear ink line


## Map data driving the tile-grid render. Set externally via property assignment
## before the first `_draw()` call (battle_scene.gd does this at STEP 1.5 in the
## mount sequence). Null-tolerant: `_draw()` no-ops gracefully when unset.
@export var map_resource: MapResource = null

## Selected unit's grid coord — drives the selection highlight overlay. Updated
## via set_selected_coord() from BattleScene wiring to GridBattleController.
## Vector2i(-1, -1) sentinel = no selection (overlay not drawn).
var _selected_coord: Vector2i = Vector2i(-1, -1)

## Tiles the selected unit can move to. Updated via set_movable_tiles() at
## selection time; empty = no preview drawn. Stored as PackedVector2Array of
## grid coords (matching GridBattleController.get_movable_tiles return shape).
var _movable_tiles: PackedVector2Array = PackedVector2Array()

## Parallel favor array (index-aligned with _movable_tiles): -1 / 0 / +1 per
## (selected unit class, tile terrain). Populated via set_movable_favors() at
## selection time. Empty OR length-mismatched = fall back to neutral tint for
## all movable tiles (forward-compat with callers that haven't wired favors).
## Source: GridBattleController.get_movable_favors().
var _movable_favors: PackedInt32Array = PackedInt32Array()

## Tiles the selected unit can attack (enemy-occupied, within attack_range).
## Updated via set_attackable_tiles() at selection time; empty = no preview.
var _attackable_tiles: PackedVector2Array = PackedVector2Array()

## Active-turn unit's grid coord — drawn as a bright pulsing border ring so the
## player can tell at a glance which unit is currently allowed to act. Set via
## set_active_turn_coord() from BattleScene._on_active_unit_changed.
var _active_turn_coord: Vector2i = Vector2i(-1, -1)

## Subset of _attackable_tiles where AMBUSH conditions hold (session-15) —
## SCOUT attacker, round >= 2, defender not yet acted. Drawn with a distinct
## indigo fill ON TOP of the standard attack-preview red so the player can
## see at a glance "this is the +15% / no-counter target". Empty = no ambush
## window active for the selected unit.
var _ambush_target_tiles: PackedVector2Array = PackedVector2Array()

## REACH_TILE objective target coord (S59 windowed UX fix). The chapter's
## win condition target tile that the protagonist (target_unit_ids[0])
## must move onto. Drawn as a persistent gold ring + diagonal flag glyph
## so the player can see WHERE to go without scanning the HUD label.
## Vector2i(-1, -1) sentinel = no REACH_TILE target (chapter uses a
## different victory condition). Set via set_reach_tile_target() once at
## battle init from BattleScene reading chapter.victory_conditions.
var _reach_tile_target: Vector2i = Vector2i(-1, -1)

## Selected unit's grid coord IF that unit currently meets the CHARGE bonus
## conditions (session-15) — CAVALRY, passive_charge, accumulated_move_cost
## past CHARGE_THRESHOLD. Drawn as a cyan halo ring around the tile so the
## player can see "your next attack will get +20% from this rush" without
## opening the forecast. Vector2i(-1, -1) sentinel = no charge ready.
var _charge_ready_coord: Vector2i = Vector2i(-1, -1)

## Selected unit's grid coord IF that unit currently meets the HIGH GROUND
## SHOT bonus conditions (session-15 ARCHER) — ARCHER class, passive_high_ground_shot,
## standing on HILLS terrain. Drawn as a forest-green halo ring around the tile
## so the player can see "your bow attack will get +15% from elevation".
## Vector2i(-1, -1) sentinel = no high-ground bonus ready.
var _high_ground_ready_coord: Vector2i = Vector2i(-1, -1)


## Selection highlight color (saturated saffron — art-bible reserved color for
## "destiny moment" usage; here repurposed for tactical selection feedback).
const COLOR_SELECTION: Color = Color("d4a017")

## Movement-range preview fill: translucent player-faction blue so reachable
## tiles read as "your strategic space" without competing with the saffron
## selection outline. Alpha = 0.30 keeps terrain readable underneath.
const COLOR_MOVE_PREVIEW: Color = Color(0.18, 0.55, 0.67, 0.30)

## Session-55 — terrain favor tint variants on the movement-range preview.
## Per-class affinity (UnitRole cost_table) + per-tile survivability (defense +
## evasion bonus) collapsed into a ternary {-1, 0, +1} signal via
## GridBattleController.get_terrain_favor_for_unit(). Color hue alone carries
## the tile-level signal so the base preview alpha (~0.30) stays unchanged and
## tiles still read as "reachable" first, "favored/disfavored" second.
##   FAVORED    — leaf-green (helps this unit: fast OR survivable terrain)
##   DISFAVORED — brick-red  (hurts this unit: cost >= 2 mobility penalty)
## Saturation kept moderate so the COLOR_ATTACK_PREVIEW red still wins when
## both overlays land on the same tile (movement vs attack semantic priority).
const COLOR_MOVE_PREVIEW_FAVORED:    Color = Color(0.28, 0.70, 0.38, 0.32)
const COLOR_MOVE_PREVIEW_DISFAVORED: Color = Color(0.78, 0.32, 0.22, 0.34)

## Session-55 — colorblind alternate channel for the favor signal per
## design/ux/accessibility-requirements.md R-2 ("tile state must not rely on
## color alone"). A small monochrome triangle in the tile's TOP-LEFT corner
## redundantly encodes the favor sign:
##   FAVORED    — ▲ apex-up      (matches "+", "up", "good")
##   DISFAVORED — ▼ apex-down    (matches "-", "down", "bad")
##   NEUTRAL    — no glyph (default state needs no special mark)
## Position is top-left so it never collides with the centered S48 terrain
## glyph nor the active-turn gold ring (drawn around the tile border).
const _FAVOR_GLYPH_COLOR:   Color   = Color(1.0, 1.0, 1.0, 0.85)
const _FAVOR_GLYPH_HALF:    float   = 5.5
const _FAVOR_GLYPH_INSET:   Vector2 = Vector2(9.0, 9.0)

## Attack-range preview fill: translucent red on enemy-occupied tiles within
## attack reach. Distinct hue from movement preview so both can be read at
## once. NOT 주홍 #c0392b (art-bible reserved); muted brick instead.
const COLOR_ATTACK_PREVIEW: Color = Color(0.80, 0.28, 0.22, 0.40)

## Ambush-window fill (session-15 verb-feedback): translucent indigo drawn ON
## TOP of the attack preview so an ambush-eligible target tile reads as a
## distinct chord (red base + indigo wash) rather than blending into the
## standard target set. Hue distance from COLOR_ATTACK_PREVIEW is large enough
## to survive desaturated displays / colorblind sims.
const COLOR_AMBUSH_PREVIEW: Color = Color(0.42, 0.20, 0.78, 0.45)

## Charge-ready halo (session-15 verb-feedback): bright cyan ring drawn around
## the selected attacker's tile when CAVALRY has accumulated enough movement
## for the +20% charge bonus on its next attack. Cyan does NOT compete with
## the saffron selection outline (different hue) or the gold active-turn ring
## (warm vs cool), so all three rings can coexist on one tile and remain
## individually readable.
const COLOR_CHARGE_HALO: Color = Color(0.30, 0.85, 0.95, 0.95)

## High-ground halo (session-15 verb-feedback): bright forest green ring drawn
## around the selected ARCHER's tile when they stand on HILLS terrain. Distinct
## from cyan (CAVALRY charge), saffron (selection), and gold (active turn) —
## green reads as "natural elevation / vegetation" and pairs intuitively with
## HILLS terrain hue underneath.
const COLOR_HIGH_GROUND_HALO: Color = Color(0.40, 0.92, 0.36, 0.95)


## Faction colors per art-bible §4.2. Used by spawn_unit_polygons() as the
## polygon FILL so faction reads at a glance (the big colored shape). side==0 =
## player (촉/Shu blue); side==1 = enemy (위/Wei charcoal). Reserved 주홍/금색
## must NOT appear here.
const COLOR_FACTION_PLAYER: Color = Color("2e5f7a")
const COLOR_FACTION_ENEMY:  Color = Color("4a4a4a")

## Per-hero accent color — drawn as a thick Line2D BORDER around the polygon so
## individual generals are visually distinct within their faction (without
## overriding the faction read carried by the fill). Keyed by hero_id; missing
## entries fall back to a faction-tuned highlight via _get_hero_accent.
##
## Reserved palette values (art-bible §4.1) MUST NEVER appear here:
##   - 주홍 #C0392B (destiny-branch reveal — rewritten history)
##   - 금색 #D4A017 (destiny-branch reveal — selection / canonical seal)
const HERO_ACCENT_BY_HERO_ID: Dictionary = {
	# Shu (player) — distinct hues that stay legible against the blue fill.
	&"shu_001_liu_bei":     Color("d9b27c"),  # warm tan — ruler of refugees
	&"shu_002_guan_yu":     Color("5da86a"),  # leaf green — green-cloaked warrior
	&"shu_003_zhang_fei":   Color("b388c9"),  # lavender — thunderous outlier
	&"shu_004_huang_zhong": Color("e7c46a"),  # warm gold-amber — veteran archer
	# Wei (enemy) — vivid borders that pop against the charcoal fill.
	&"wei_001_cao_cao":     Color("b559a8"),  # violet-magenta — emperor-villain
	&"wei_005_xiahou_dun":  Color("d86b3a"),  # orange-rust — fierce one-eyed (≠ #C0392B)
	&"wei_006_zhang_liao":  Color("6bb7e0"),  # sky cyan — clever and swift
	&"wei_007_yu_jin":      Color("bfb05f"),  # olive — disciplined holder
	&"wei_008_xu_chu":      Color("e2a088"),  # peach — bodyguard brawn
	# Wu — sea-tone borders (oceanfront kingdom).
	&"wu_001_sun_quan":     Color("4ea7c2"),  # deep teal — young emperor
	&"wu_003_zhou_yu":      Color("84d4c1"),  # mint — elegant strategist
	# Qun — drift-faction; saturated outliers.
	&"qun_001_lu_bu":       Color("e85a5a"),  # vermillion — peerless warrior
	&"qun_004_diao_chan":   Color("ff8fc0"),  # pink — flower-of-the-court
}

## Faction-tuned fallback border tone (used when a hero_id has no explicit accent).
const COLOR_HERO_FALLBACK_PLAYER: Color = Color("a8c4d4")  # pale Shu sky
const COLOR_HERO_FALLBACK_ENEMY:  Color = Color("c8a89a")  # pale Wei dust

## Unit polygon half-extent — bumped from 20 (≈40×40) to 26 (≈52×52) so units
## occupy ~80% of the 64px tile and read clearly at default 1.0 camera zoom.
const _UNIT_HALF: int = 26

## Session-43 — HUD declutter: hero name label modulate when the unit is NOT
## the active-turn unit nor the selected unit. Pre-S43 every unit's NameLabel
## rendered at modulate.a=1.0 simultaneously — 8 units on grid = 8 names
## shouting in parallel, contributing to "화면이 조잡" perception. Post-S43
## only active + selected units show their name at full alpha; others recede.
## Session-46 — dim alpha tightened 0.45 → 0.0 after windowed verification
## (S45 user feedback "각 장수의 이름이 겹쳐져서 잘 안 보임"). 0.45 alpha was
## still readable enough that adjacent unit names overlapped visually; full
## hide on non-active makes the active unit's name the only label on screen.
## Hero identity is still recoverable via the polygon emblem (S40 hero
## overlay carries 큰 귀 / 수염 / 안대 / etc.) — the name was redundant when
## the player isn't actively considering that unit.
## S60 — names always visible. Pre-S60 DIM_ALPHA=0.0 (fully invisible) was
## designed to declutter and rely on hero emblem identification, but user
## feedback shows position-at-a-glance is essential for tactical planning
## ("어떤 장수가 어디에 있는지를 한눈에 봐야 작전을 짤 수 있다"). Active turn
## + selected stay at 1.0 for emphasis; everyone else at 0.85 — visible
## but slightly recessed so the active unit still reads as primary.
const _UNIT_LABEL_DIM_ALPHA: float = 0.85
const _UNIT_LABEL_FULL_ALPHA: float = 1.0

## Per-hero accent border stroke (width in world px). Wide enough to read as a
## clear ring around the polygon at the default 1.0 camera zoom; narrow enough
## not to obscure the class shape underneath.
const _HERO_BORDER_WIDTH: float = 4.0


func set_selected_coord(coord: Vector2i) -> void:
	if _selected_coord == coord:
		return
	_selected_coord = coord
	queue_redraw()
	# Session-43 — selected unit's name pops to full alpha; previous selection
	# recedes (back to dim if not active-turn). Decouples selection emphasis
	# from the saffron tile outline so the unit identity itself reads stronger.
	_refresh_unit_label_alphas()


## Active turn coord — drawn as a thick gold border on the tile so the player
## immediately knows which unit may act. Independent from selection (the player
## may still inspect non-active units by clicking the ribbon).
func set_active_turn_coord(coord: Vector2i) -> void:
	if _active_turn_coord == coord:
		return
	_active_turn_coord = coord
	queue_redraw()
	# Session-43 — name label fade reacts to active-turn changes (active unit's
	# name pops to full alpha; the previous active unit recedes to dim).
	_refresh_unit_label_alphas()


## Updates the movement-range preview overlay. Pass an empty array to clear.
## Called from BattleScene._on_unit_selected_changed after computing the
## movable set via GridBattleController.get_movable_tiles().
##
## Note: setting tiles clears any stale favor array (length would mismatch).
## Callers wanting the favor tint must call set_movable_favors() AFTER this.
func set_movable_tiles(tiles: PackedVector2Array) -> void:
	_movable_tiles = tiles
	_movable_favors = PackedInt32Array()
	queue_redraw()


## Updates the per-tile favor signal for the current movable preview overlay.
## Array MUST be index-aligned with the array previously passed to
## set_movable_tiles() — length mismatch falls back to neutral tint for all
## tiles (defensive — never crashes). Value semantics: -1 disadvantage,
## 0 neutral (default blue), +1 advantage. Pass empty to disable favor tint.
func set_movable_favors(favors: PackedInt32Array) -> void:
	_movable_favors = favors
	queue_redraw()


## Updates the attack-range preview overlay. Pass an empty array to clear.
## Tiles should be enemy-occupied within attack_range (filtered by
## GridBattleController.get_attackable_tiles).
func set_attackable_tiles(tiles: PackedVector2Array) -> void:
	_attackable_tiles = tiles
	queue_redraw()


## Updates the AMBUSH window overlay (session-15). Pass an empty array to
## clear. Tiles must be a subset of _attackable_tiles — caller pulls them
## from GridBattleController.get_ambush_eligible_target_tiles which mirrors
## the same gate (SCOUT + passive_ambush + round >= 2 + defender unacted)
## used by DamageCalc, so the visual cue cannot drift from the actual bonus.
func set_ambush_target_tiles(tiles: PackedVector2Array) -> void:
	_ambush_target_tiles = tiles
	queue_redraw()


## Sets the REACH_TILE objective target tile (S59 windowed UX fix). Called
## by BattleScene once at battle init when chapter.victory_conditions is
## REACH_TILE; pass Vector2i(-1, -1) to clear (chapters with other win
## conditions). The overlay is persistent for the duration of the battle —
## chapter target_tile is static, not selection-dependent.
func set_reach_tile_target(coord: Vector2i) -> void:
	_reach_tile_target = coord
	queue_redraw()


## Sets the charge-ready halo coord (session-15). Pass Vector2i(-1, -1) to
## clear. Coord is typically the selected attacker's tile when the controller
## reports is_charge_ready(unit_id) == true. Independent from selection: a
## non-CAVALRY selected unit clears this even though the selection outline
## stays on, and a CAVALRY that just attacked clears this because the
## accumulated move resets on action commit.
func set_charge_ready_coord(coord: Vector2i) -> void:
	if _charge_ready_coord == coord:
		return
	_charge_ready_coord = coord
	queue_redraw()


## Sets the high-ground-ready halo coord (session-15 ARCHER). Pass Vector2i(-1, -1)
## to clear. Coord is typically the selected ARCHER's tile when the controller
## reports is_high_ground_ready(unit_id) == true. Independent from the charge
## halo (different class mutex) — only one of cyan-CHARGE or green-HIGH-GROUND
## can be active for the same selected unit at a given time.
func set_high_ground_ready_coord(coord: Vector2i) -> void:
	if _high_ground_ready_coord == coord:
		return
	_high_ground_ready_coord = coord
	queue_redraw()


## ADR-0022 escort overlay — attaches a small "EscortMarker" Polygon2D child to
## the carrier unit polygon when the carrier is ESCORTED, removes it when not.
## Driven by CivilianTokensVisuals.refresh() diff of get_civilian_tokens().
## Idempotent on the active=true side (re-call no-op when marker already exists).
const _ESCORT_OVERLAY_NAME: StringName = &"EscortMarker"
const _COLOR_ESCORT_OVERLAY: Color = Color(0.85, 0.75, 0.50, 0.95)
const _ESCORT_OVERLAY_OFFSET: Vector2 = Vector2(18, -18)


func set_carrier_escort_overlay(carrier_unit_id: int, active: bool) -> void:
	var polygon: Node2D = _find_carrier_polygon(carrier_unit_id)
	if polygon == null:
		return
	var existing: Node = polygon.get_node_or_null(String(_ESCORT_OVERLAY_NAME))
	if active:
		if existing != null:
			return
		var marker: Polygon2D = Polygon2D.new()
		marker.name = String(_ESCORT_OVERLAY_NAME)
		marker.polygon = _make_escort_marker_shape()
		marker.color = _COLOR_ESCORT_OVERLAY
		marker.position = _ESCORT_OVERLAY_OFFSET
		polygon.add_child(marker)
	else:
		if existing != null:
			existing.queue_free()


func _find_carrier_polygon(unit_id: int) -> Node2D:
	# Mirrors BattleScene._find_unit_polygon's "Unit{id}_*" prefix scan.
	var prefix: String = "Unit%d_" % unit_id
	for parent_name: String in ["PlayerUnits", "EnemyUnits"]:
		var parent: Node = get_node_or_null(parent_name)
		if parent == null:
			continue
		for child: Node in parent.get_children():
			if (child.name as String).begins_with(prefix) and child is Node2D:
				return child as Node2D
	return null


func _make_escort_marker_shape() -> PackedVector2Array:
	# Smaller humanoid silhouette (~14px tall) — trailing the carrier per
	# spec §4.3 OQ-5. Color = warm sand for visible contrast against player
	# blue + enemy charcoal unit fills.
	return PackedVector2Array([
		Vector2(-4, -6),
		Vector2(0, -8),
		Vector2(4, -6),
		Vector2(5, 6),
		Vector2(-5, 6),
	])


## Spawns one Polygon2D per roster unit under PlayerUnits/EnemyUnits, replacing
## any pre-authored or previously-spawned polygons.
##
## Three orthogonal visual channels:
##   - Shape   = unit_class (UnitRole.UnitClass enum)            → see _shape_for_class
##   - Fill    = faction (BattleUnit.side; player blue / enemy charcoal)
##   - Border  = hero_id (HERO_ACCENT_BY_HERO_ID + Line2D child) → distinguishes
##               individual generals within a faction
##
## Rotation is facing-coded for directional classes (CAVALRY/ARCHER/SCOUT apex
## points along the facing axis); rotationally-symmetric classes (INFANTRY,
## STRATEGIST, COMMANDER) get rotation=0.
##
## Names follow the `Unit{unit_id}_*` convention so the existing battle_scene.gd
## _find_unit_polygon() helper (move/damage/death handlers) keeps working
## unchanged. The border + name label live as children of that polygon, so the
## modulate cascade carries them through damage-flash / death-fade / end-of-turn
## dim / round-undim animations automatically.
## Diagnostic-trace gate. The single `[SPAWN]` print here was a session 4-5
## diagnostic ("did unit polygons mount?"); silenced now that windowed boots
## reliably. Flip to `true` (then re-import) when investigating spawn issues.
const _TRACE_ENABLED: bool = false


func spawn_unit_polygons(roster: Array[BattleUnit]) -> void:
	if _TRACE_ENABLED:
		print("[SPAWN] spawn_unit_polygons called for %d units" % roster.size())
	var player_parent: Node2D = _get_or_create_unit_parent("PlayerUnits")
	var enemy_parent: Node2D = _get_or_create_unit_parent("EnemyUnits")
	for child: Node in player_parent.get_children():
		child.queue_free()
	for child: Node in enemy_parent.get_children():
		child.queue_free()
	for unit: BattleUnit in roster:
		var poly: Polygon2D = Polygon2D.new()
		poly.name = "Unit%d_%s" % [unit.unit_id, String(unit.hero_id)]
		poly.position = Vector2(
			unit.position.x * TILE_SIZE + TILE_SIZE / 2.0,
			unit.position.y * TILE_SIZE + TILE_SIZE / 2.0,
		)
		# Fill = faction (the strong "friend / foe" read).
		poly.color = COLOR_FACTION_PLAYER if unit.side == 0 else COLOR_FACTION_ENEMY
		var shape: PackedVector2Array = _shape_for_class(unit.unit_class)
		poly.polygon = shape
		poly.rotation = rotation_for_facing(unit.facing, unit.unit_class)
		if unit.side == 0:
			player_parent.add_child(poly)
		else:
			enemy_parent.add_child(poly)
		# Q5 Phase 1+2 — Resolve chibi grid sprite first. When chibi is mounted,
		# the legacy identity cues (HeroBorder accent ring, ClassEmblem class
		# glyph + per-hero overlay, NameLabel Korean name) are SKIPPED — the
		# sprite already conveys hero identity (silhouette + face + weapon) and
		# the legacy cues clutter / occlude it. FrontChevron is retained always
		# since chibi is counter-rotated to upright and cannot encode unit
		# facing — REAR-attack 치명타 가독성 cue must remain.
		# Heroes without a chibi asset (un-shipped roster, pre-cascade enemies
		# at ch13, etc.) keep the legacy 4-cue composition unchanged.
		var idle_tex: Texture2D = HeroDatabase.get_grid_sprite_frame_texture(unit.hero_id, "idle")
		var has_chibi_sprite: bool = (idle_tex != null)
		# Per-hero accent BORDER as a closed Line2D over the polygon's edge.
		# Same shape, vivid hero-specific color → individual generals are
		# distinct within their faction without diluting the faction fill read.
		# modulate cascade from the parent polygon takes the border along for
		# damage-flash / death-fade / end-of-turn dim / round-undim animations.
		if not has_chibi_sprite:
			var border: Line2D = Line2D.new()
			border.name = "HeroBorder"
			border.points = shape
			border.closed = true
			border.width = _HERO_BORDER_WIDTH
			border.default_color = _get_hero_accent(unit.hero_id, unit.side)
			border.joint_mode = Line2D.LINE_JOINT_BEVEL
			border.antialiased = true
			poly.add_child(border)
		# Q5 Phase 1+2 — Chibi grid sprite mount (sumi-e + chibi fusion per
		# art-bible §5.7). AnimatedSprite2D — idle frame always (Phase 1), plus
		# optional breath frame (Phase 2) for 2-frame ping-pong loop visualizing
		# subtle inhale/exhale chest-shoulder breath. Per-hero phase offset
		# (hero_id hash) → multi-hero grids don't sync into a uniformed drill.
		# Polygon faction fill remains visible as halo around sprite's
		# transparent silhouette, preserving friend/foe read. Counter-rotated
		# against poly.rotation so chibi always renders upright regardless of
		# class facing. Scaled to fit TILE_SIZE * 0.9 → slight inset so faction
		# halo reads. Distinct from Q5 1차 (`4c17ac2`, reverted at `97b0c7a`)
		# which mounted static portraits.
		if has_chibi_sprite:
			var breath_tex: Texture2D = HeroDatabase.get_grid_sprite_frame_texture(unit.hero_id, "breath")
			var anim_sprite: AnimatedSprite2D = AnimatedSprite2D.new()
			anim_sprite.name = "ChibiSprite"
			var frames: SpriteFrames = SpriteFrames.new()
			# Godot 4.6: SpriteFrames.new() auto-creates the "default" animation.
			# Calling add_animation(&"default") here triggers the warning
			# "SpriteFrames already has animation 'default'" + no-op. Just
			# add frames directly. Fixed S73 (was firing once per chibi unit
			# per spawn cycle).
			frames.add_frame(&"default", idle_tex)
			if breath_tex != null:
				frames.add_frame(&"default", breath_tex)
			# 800 ms per frame → 1.25 fps. 2-frame ping-pong = 1.6 s cycle.
			frames.set_animation_speed(&"default", 1.25)
			frames.set_animation_loop(&"default", true)
			# Q5 Phase 3 — Walk motion is code-side only (vertical bounce tween
			# in battle_scene._on_unit_moved). No walk_0/walk_1 PNG assets —
			# S72 학습: chibi 짧은 다리 비례에서 lateral leg-swap frame 이 시각
			# 적으로 marginal + Gemini chibi 매체 한계 (anchor 전략도 실패).
			# Frame-swap 대신 코드 vertical hop 으로 결정적 motion. Bounce
			# gate = ChibiSprite is AnimatedSprite2D (모든 chibi 영웅 자동 적용).
			anim_sprite.sprite_frames = frames
			var native_size: Vector2 = idle_tex.get_size()
			var max_dim: float = maxf(native_size.x, native_size.y)
			var fit_factor: float = (TILE_SIZE * 0.9) / max_dim
			anim_sprite.scale = Vector2(fit_factor, fit_factor)
			anim_sprite.position = Vector2.ZERO
			anim_sprite.rotation = -poly.rotation
			# Per-hero phase offset — hash unit.hero_id to a 0..1 fraction,
			# then seed initial frame + frame_progress so 5 heroes on grid
			# breathe at staggered phases (no drill-team sync). Only meaningful
			# when breath frame exists (else 1-frame anim = no phase to shift).
			# CRITICAL: set frame + progress BEFORE play() — Godot 4.6
			# AnimatedSprite2D.frame setter stops playback if assigned after
			# play() (first windowed attestation: 위연 "전혀 움직임 없음").
			# set_frame_and_progress(int, float) is atomic and preferred.
			if breath_tex != null:
				var hash_val: int = hash(String(unit.hero_id))
				var phase: float = float(hash_val % 1000) / 1000.0
				if phase >= 0.5:
					anim_sprite.set_frame_and_progress(1, (phase - 0.5) * 2.0)
				else:
					anim_sprite.set_frame_and_progress(0, phase * 2.0)
			anim_sprite.play(&"default")
			poly.add_child(anim_sprite)
		# Session-16: small class-glyph inside the polygon (spear / shield / bow
		# / scroll / crown / dagger). Counter-rotated against the polygon facing
		# so the glyph stays upright. Reads as "what this piece does" at a glance
		# without obscuring the shape silhouette — placed at origin (center).
		# Also paints a per-hero overlay symbol (수염 / 안대 / 꽃 / 별 / 산 / 부채
		# / 등) using the hero accent color so 관우와 장비를 한 눈에 구분.
		if not has_chibi_sprite:
			var emblem: ClassEmblem = ClassEmblem.make(unit.unit_class, unit.side,
				-poly.rotation, unit.hero_id, _get_hero_accent(unit.hero_id, unit.side))
			emblem.name = "ClassEmblem"
			poly.add_child(emblem)
		# Name label above the polygon — bigger, heavier outline than the prior
		# pass so the hero is identifiable at a glance even before the player
		# memorizes the shape+border palette. Session-16: tint label color to the
		# hero accent (HERO_ACCENT_BY_HERO_ID) so 관우/장비/유비/황충/초선 etc. read
		# as distinct hand-named pieces at the same time the border color does.
		# Outline stays near-black for contrast against terrain.
		if not has_chibi_sprite:
			var hero: HeroData = HeroDatabase.get_hero(unit.hero_id)
			var accent: Color = _get_hero_accent(unit.hero_id, unit.side)
			# Brighten the accent slightly so it reads at small font sizes against
			# any terrain backdrop without dropping to dim. Session-40: lerp factor
			# tightened 0.45 → 0.30 so the hero accent reads more saturated — pre-
			# S40 the names trended toward neutral cream and the per-hero color
			# distinction in the labels was muddled. Outline still carries contrast.
			var label_color: Color = accent.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.30)
			var label: Label = Label.new()
			label.name = "NameLabel"
			label.text = hero.name_ko if hero != null and hero.name_ko != "" else String(unit.hero_id)
			label.add_theme_color_override("font_color", label_color)
			label.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.05, 1.0))
			# S60 — name labels are always visible (per_UNIT_LABEL_DIM_ALPHA=0.85).
			# Pre-S60 size 80×22 + font_size 20 overflowed TILE_SIZE=64 → adjacent
			# columns had 16px horizontal label overlap, garbled at standard zoom
			# when DIM_ALPHA was bumped from 0. Resized to 60×18 + font_size 13 so
			# every label fits within its tile column. 2-3 char Korean names
			# (유비/관우/장비/황충/초선/하후돈 etc.) all fit cleanly.
			label.add_theme_constant_override("outline_size", 4)
			label.add_theme_font_size_override("font_size", 13)
			# Counter the polygon's facing rotation so the label always reads upright.
			label.rotation = -poly.rotation
			# Centered horizontally over the polygon, just above the class emblem.
			# size.x=60 < TILE_SIZE=64 → no horizontal overlap with adjacent columns.
			label.position = Vector2(-30, -44)
			label.size = Vector2(60, 18)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			poly.add_child(label)
		# Q5 Phase 1+2 status (S72): chibi sprite + 2-frame breath mounted for
		# all 5 cascade 영웅 (위연 / 방통 / 관우 / 장비 / 유비). Legacy cues
		# (border / emblem / label) suppressed when chibi present per Heavy hide.
		# Phase 3-4 (walk 4-frame / attack 3-frame) 은 추후 작업.
		# Q4 facing chevron — universal "front" indicator on EVERY unit polygon
		# so player can tell which direction each unit is looking (esp. INFANTRY/
		# STRATEGIST/COMMANDER which are rotation-symmetric — pre-Q4 they had
		# zero facing cue, making REAR-attack 치명타 unusable). Chevron is a
		# child of poly so it inherits modulate / scale / death-fade animations.
		# Pose math accounts for class-specific poly.rotation: chevron's GLOBAL
		# pose always points at unit.facing regardless of class symmetry.
		var chevron: Polygon2D = Polygon2D.new()
		chevron.name = "FrontChevron"
		chevron.polygon = _FRONT_CHEVRON_SHAPE
		chevron.color = Color(0.05, 0.04, 0.04, 1.0)  # MUK ink — contrasts both faction fills
		var poly_rot: float = poly.rotation
		var facing_vec: Vector2 = facing_to_vector(unit.facing)
		var chevron_radius: float = TILE_SIZE * 0.42
		# Position in poly's local frame = (global facing offset) rotated by -poly_rot.
		chevron.position = facing_vec.rotated(-poly_rot) * chevron_radius
		# Local rotation = (global facing angle) - poly's rotation.
		chevron.rotation = atan2(facing_vec.y, facing_vec.x) - poly_rot
		poly.add_child(chevron)
		# S73 — Synergy badge slot (Synergy v2). Empty text until controller
		# calls set_synergy_badges() with per-unit char map. Chars: '義' Peach
		# Garden / '策' 방통 Counsel (recipient or self) / '獨' 위연 Lone Wolf.
		# Concat possible (e.g. '義策' when 유비 adjacent to both 장비 and 방통).
		# Counter-rotated position (world-frame upper-right of tile, regardless
		# of poly facing) + counter-rotated text (always upright). Gold tint per
		# art-bible JI_BAEK warm palette. mouse_filter IGNORE per Phase 3 위급!
		# learning (Label default STOP intercepts click — breaks grid click).
		var badge: Label = Label.new()
		badge.name = "SynergyBadge"
		badge.text = ""
		badge.visible = false
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.add_theme_color_override("font_color", Color(0.85, 0.71, 0.27, 1.0))  # gold
		badge.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.05, 1.0))
		badge.add_theme_constant_override("outline_size", 3)
		badge.add_theme_font_size_override("font_size", 14)
		badge.position = Vector2(14, -30).rotated(-poly_rot)
		badge.rotation = -poly_rot
		poly.set_meta(&"unit_id", unit.unit_id)
		poly.add_child(badge)
	# Session-43 — fresh roster spawned with default modulate.a=1.0 on every
	# NameLabel. Refresh so non-active, non-selected names start at dim alpha.
	# Active turn coord may not be set yet (round 1 first init unit fires
	# set_active_turn_coord shortly after spawn) — in that window all names
	# render dim, which reads as "nothing's acting yet, scene is settling."
	_refresh_unit_label_alphas()


## Session-43 — sets NameLabel.modulate.a per unit polygon based on whether
## the polygon sits on _active_turn_coord or _selected_coord. Walks both
## PlayerUnits + EnemyUnits parents; ignores non-Polygon2D children. Polygon
## position is `unit.position * TILE_SIZE + TILE_SIZE/2`, so floor(pos/TILE_SIZE)
## recovers the unit's tile coord even mid-tween (tween interpolates between
## two adjacent tiles; floor returns one of the two, neither of which is the
## active/selected tile unless the unit is moving INTO or AWAY from it).
##
## Called from: set_active_turn_coord, set_selected_coord, spawn_unit_polygons.
## Not called from set_movable_tiles / set_attackable_tiles etc. — those
## overlays don't change which unit is active/selected.
func _refresh_unit_label_alphas() -> void:
	for parent_name: String in ["PlayerUnits", "EnemyUnits"]:
		var parent: Node2D = get_node_or_null(parent_name) as Node2D
		if parent == null:
			continue
		for child: Node in parent.get_children():
			if not (child is Polygon2D):
				continue
			var poly: Polygon2D = child as Polygon2D
			var name_label: Label = poly.get_node_or_null("NameLabel") as Label
			if name_label == null:
				continue
			var tile: Vector2i = Vector2i(
				int(floor(poly.position.x / float(TILE_SIZE))),
				int(floor(poly.position.y / float(TILE_SIZE))),
			)
			var is_active: bool = (_active_turn_coord == tile)
			var is_selected: bool = (_selected_coord == tile)
			name_label.modulate.a = (
				_UNIT_LABEL_FULL_ALPHA if (is_active or is_selected)
				else _UNIT_LABEL_DIM_ALPHA
			)


## S73 Synergy v2 — paints per-unit synergy badge (義/策/獨, concat possible)
## above each polygon. Called by battle_scene after spawn / unit_moved /
## unit_killed / unit_visual_died — any event that can change adjacency. Empty
## string hides the badge. unit_id stored as poly meta (&"unit_id") during
## spawn_unit_polygons. Walks both PlayerUnits + EnemyUnits parents.
func set_synergy_badges(badges: Dictionary) -> void:
	for parent_name: String in ["PlayerUnits", "EnemyUnits"]:
		var parent: Node2D = get_node_or_null(parent_name) as Node2D
		if parent == null:
			continue
		for child: Node in parent.get_children():
			if not (child is Polygon2D):
				continue
			var poly: Polygon2D = child as Polygon2D
			if not poly.has_meta(&"unit_id"):
				continue
			var unit_id: int = int(poly.get_meta(&"unit_id"))
			var badge: Label = poly.get_node_or_null("SynergyBadge") as Label
			if badge == null:
				continue
			var text: String = badges.get(unit_id, "") as String
			badge.text = text
			badge.visible = text != ""


## Returns the per-hero accent border color for `hero_id`, falling back to a
## faction-tuned highlight when no entry is authored. Public-ish (used by tests
## that want to assert per-hero distinction without hardcoding the palette).
func _get_hero_accent(hero_id: StringName, side: int) -> Color:
	if HERO_ACCENT_BY_HERO_ID.has(hero_id):
		return HERO_ACCENT_BY_HERO_ID[hero_id] as Color
	return COLOR_HERO_FALLBACK_PLAYER if side == 0 else COLOR_HERO_FALLBACK_ENEMY


func _get_or_create_unit_parent(parent_name: String) -> Node2D:
	var existing: Node = get_node_or_null(parent_name)
	if existing is Node2D:
		return existing as Node2D
	var parent: Node2D = Node2D.new()
	parent.name = parent_name
	add_child(parent)
	return parent


## Class-coded silhouettes (UnitRole.UnitClass enum, see src/foundation/unit_role.gd).
## Shapes intentionally distinct at a glance: CAVALRY=triangle (apex=facing);
## INFANTRY=square; ARCHER=inverted triangle; STRATEGIST=diamond;
## COMMANDER=pentagon; SCOUT=small triangle. All sized ~40×40.
func _shape_for_class(unit_class: int) -> PackedVector2Array:
	var h: int = _UNIT_HALF
	match unit_class:
		0:  # CAVALRY — east-facing triangle (apex +x); rotation applied separately
			return PackedVector2Array([Vector2(h, 0), Vector2(-h, -h), Vector2(-h, h)])
		1:  # INFANTRY — square
			return PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])
		2:  # ARCHER — inverted triangle (apex -y, baseline +y rotated to facing)
			return PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(0, h)])
		3:  # STRATEGIST — diamond
			return PackedVector2Array([Vector2(0, -h), Vector2(h, 0), Vector2(0, h), Vector2(-h, 0)])
		4:  # COMMANDER — pentagon
			return PackedVector2Array([
				Vector2(0, -h), Vector2(h, -h / 3), Vector2(h * 2 / 3, h),
				Vector2(-h * 2 / 3, h), Vector2(-h, -h / 3),
			])
		5:  # SCOUT — small triangle (75% scale)
			var s: int = h * 3 / 4
			return PackedVector2Array([Vector2(0, -s), Vector2(s, s), Vector2(-s, s)])
		_:
			return PackedVector2Array([Vector2(-h, -h), Vector2(h, -h), Vector2(h, h), Vector2(-h, h)])


## Maps facing (0=N, 1=E, 2=S, 3=W) to polygon rotation. CAVALRY's base shape
## points east (+x) so facing=1 is identity; INFANTRY/STRATEGIST/COMMANDER are
## rotationally symmetric enough that rotation is a no-op (return 0).
## Public so BattleScene can compute the target rotation when tweening a
## moved unit's polygon toward its new facing.
func rotation_for_facing(facing: int, unit_class: int) -> float:
	if unit_class != 0 and unit_class != 2 and unit_class != 5:
		return 0.0
	match facing:
		0: return -PI / 2.0  # N
		1: return 0.0        # E (base orientation)
		2: return PI / 2.0   # S
		3: return PI         # W
		_: return 0.0


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	if map_resource == null:
		return
	if map_resource.map_cols <= 0 or map_resource.map_rows <= 0:
		return
	var expected_size: int = map_resource.map_cols * map_resource.map_rows
	if map_resource.tiles.size() != expected_size:
		push_warning(("ChapterVisuals: tiles.size()=%d != map_cols*map_rows=%d; "
			+ "render aborted (data shape mismatch).")
			% [map_resource.tiles.size(), expected_size])
		return

	for row: int in map_resource.map_rows:
		for col: int in map_resource.map_cols:
			var idx: int = row * map_resource.map_cols + col
			var tile: MapTileData = map_resource.tiles[idx]
			if tile == null:
				continue
			var rect: Rect2 = Rect2(
				Vector2(col * TILE_SIZE, row * TILE_SIZE),
				Vector2(TILE_SIZE, TILE_SIZE),
			)
			var fill: Color = _get_terrain_color(tile.terrain_type)
			draw_rect(rect, fill, true)
			# Session-47 — terrain glyph (Hanja) drawn over the fill so each
			# non-PLAINS terrain reads distinctively at a glance. PLAINS gets
			# no glyph (the default state needs no special mark).
			_draw_terrain_glyph(rect, tile.terrain_type)
			draw_rect(rect, COLOR_TILE_BORDER, false, 1.0)

	# Movement-range preview (drawn before selection outline so the outline
	# stays visually on top of all overlays). Per-tile color picked from the
	# favor array when length matches the tile array; otherwise neutral blue
	# (forward-compat for callers that don't push favors yet). A redundant
	# corner glyph (▲ / ▼) per-tile encodes the favor sign for colorblind
	# alt-channel parity (design/ux/accessibility-requirements.md R-2).
	var _favor_len: int = _movable_favors.size()
	var _use_favors: bool = _favor_len == _movable_tiles.size()
	for i: int in _movable_tiles.size():
		var v: Vector2 = _movable_tiles[i]
		var move_rect: Rect2 = Rect2(
			Vector2(int(v.x) * TILE_SIZE, int(v.y) * TILE_SIZE),
			Vector2(TILE_SIZE, TILE_SIZE),
		)
		var fill: Color = COLOR_MOVE_PREVIEW
		var favor: int = 0
		if _use_favors:
			favor = _movable_favors[i]
			if favor > 0:
				fill = COLOR_MOVE_PREVIEW_FAVORED
			elif favor < 0:
				fill = COLOR_MOVE_PREVIEW_DISFAVORED
		draw_rect(move_rect, fill, true)
		_draw_favor_glyph(move_rect, favor)

	# Attack-range preview (drawn over movement preview so enemy targets
	# read as the dominant action when both overlay sets are visible).
	for v: Vector2 in _attackable_tiles:
		var atk_rect: Rect2 = Rect2(
			Vector2(int(v.x) * TILE_SIZE, int(v.y) * TILE_SIZE),
			Vector2(TILE_SIZE, TILE_SIZE),
		)
		draw_rect(atk_rect, COLOR_ATTACK_PREVIEW, true)

	# Ambush-window overlay (session-15) — drawn on TOP of the attack preview
	# so ambush-eligible targets read as a red+indigo chord that pops against
	# plain red targets. Subset of _attackable_tiles per the controller helper.
	for v: Vector2 in _ambush_target_tiles:
		var ambush_rect: Rect2 = Rect2(
			Vector2(int(v.x) * TILE_SIZE, int(v.y) * TILE_SIZE),
			Vector2(TILE_SIZE, TILE_SIZE),
		)
		draw_rect(ambush_rect, COLOR_AMBUSH_PREVIEW, true)
		# Thin indigo border so the ambush tile is also recognizable when only
		# the corner is visible at the edge of the camera viewport.
		draw_rect(ambush_rect, Color(0.55, 0.30, 0.95, 0.95), false, 2.0)

	# REACH_TILE objective marker (S59 windowed UX) — drawn before selection
	# rings so an actively-selected unit standing on the target shows both
	# overlays cleanly. Persistent gold-amber ring with a diagonal slash
	# flag inside, distinct from active-turn gold (saturated vs amber tone)
	# so it doesn't read as "active turn unit" when the player scans the map.
	# Player intuition: "the goal flag is over there."
	if _reach_tile_target.x >= 0 and _reach_tile_target.y >= 0:
		var rt_origin: Vector2 = Vector2(_reach_tile_target.x * TILE_SIZE, _reach_tile_target.y * TILE_SIZE)
		var rt_rect: Rect2 = Rect2(rt_origin, Vector2(TILE_SIZE, TILE_SIZE))
		# Soft amber fill so the tile reads as "marked" from a distance.
		draw_rect(rt_rect, Color(0.95, 0.72, 0.18, 0.28), true)
		# Thick amber border ring — outer + inner for a "halo" read distinct
		# from the active-turn gold ring.
		draw_rect(rt_rect, Color(0.98, 0.78, 0.22, 1.0), false, 4.0)
		# Flag pole + pennant in the tile center (vector-drawn, no font).
		var cx: float = rt_origin.x + TILE_SIZE * 0.5
		var cy: float = rt_origin.y + TILE_SIZE * 0.5
		var pole_top: Vector2 = Vector2(cx - 10, cy - 16)
		var pole_bot: Vector2 = Vector2(cx - 10, cy + 16)
		draw_line(pole_top, pole_bot, Color(0.10, 0.08, 0.06, 1.0), 2.5)
		# Triangular pennant pointing right from the top of the pole.
		var pennant: PackedVector2Array = PackedVector2Array([
			Vector2(cx - 10, cy - 16),
			Vector2(cx + 12, cy - 10),
			Vector2(cx - 10, cy - 4),
		])
		draw_colored_polygon(pennant, Color(0.98, 0.78, 0.22, 1.0))

	# Active turn highlight — drawn before selection so a selected active unit
	# shows both rings (active=gold thick, selection=lighter thin on top).
	if _active_turn_coord.x >= 0 and _active_turn_coord.y >= 0:
		var atc: Rect2 = Rect2(
			Vector2(_active_turn_coord.x * TILE_SIZE, _active_turn_coord.y * TILE_SIZE),
			Vector2(TILE_SIZE, TILE_SIZE),
		)
		# Outer thick gold border + inner ring for a "halo" read.
		draw_rect(atc, Color(1.0, 0.85, 0.20, 1.0), false, 4.0)
		var inner: Rect2 = Rect2(atc.position + Vector2(3, 3), atc.size - Vector2(6, 6))
		draw_rect(inner, Color(1.0, 0.95, 0.55, 0.85), false, 2.0)

	# Selection highlight overlay (drawn last so it sits on top of tiles + preview).
	if _selected_coord.x >= 0 and _selected_coord.y >= 0:
		var sel_rect: Rect2 = Rect2(
			Vector2(_selected_coord.x * TILE_SIZE, _selected_coord.y * TILE_SIZE),
			Vector2(TILE_SIZE, TILE_SIZE),
		)
		draw_rect(sel_rect, COLOR_SELECTION, false, 3.0)

	# Charge-ready halo (session-15) — drawn LAST so it sits on top of every
	# other overlay including selection. Inset slightly so the saffron selection
	# outline remains visible underneath; cyan ring reads as a distinct second
	# channel "your rush is loaded — attack now to cash it in".
	if _charge_ready_coord.x >= 0 and _charge_ready_coord.y >= 0:
		var ch_rect: Rect2 = Rect2(
			Vector2(_charge_ready_coord.x * TILE_SIZE + 4,
				_charge_ready_coord.y * TILE_SIZE + 4),
			Vector2(TILE_SIZE - 8, TILE_SIZE - 8),
		)
		draw_rect(ch_rect, COLOR_CHARGE_HALO, false, 3.0)

	# High-ground-ready halo (session-15 ARCHER) — same inset as charge halo
	# so the saffron selection outline remains visible underneath. Class mutex
	# (CAVALRY vs ARCHER) guarantees this and the charge halo cannot co-exist
	# on a single selected unit, so no z-ordering conflict between the two.
	if _high_ground_ready_coord.x >= 0 and _high_ground_ready_coord.y >= 0:
		var hg_rect: Rect2 = Rect2(
			Vector2(_high_ground_ready_coord.x * TILE_SIZE + 4,
				_high_ground_ready_coord.y * TILE_SIZE + 4),
			Vector2(TILE_SIZE - 8, TILE_SIZE - 8),
		)
		draw_rect(hg_rect, COLOR_HIGH_GROUND_HALO, false, 3.0)


## Session-47 / S48 — draws the per-terrain shape glyph centered on `rect`.
## Pure primitive ops (draw_line / draw_polyline / draw_colored_polygon),
## no font dependency, instant visual recognition regardless of locale.
## No-op for PLAINS (0) and unknown terrain types.
func _draw_terrain_glyph(rect: Rect2, terrain_type: int) -> void:
	if not _TERRAIN_GLYPH_COLOR_BY_TYPE.has(terrain_type):
		return
	var color: Color = _TERRAIN_GLYPH_COLOR_BY_TYPE[terrain_type] as Color
	var c: Vector2 = rect.position + rect.size * 0.5
	var s: float = _TERRAIN_GLYPH_HALF
	match terrain_type:
		1:  # FOREST — 3 small trees clustered
			_glyph_forest(c, s, color)
		2:  # HILLS — 2 rolling arches
			_glyph_hills(c, s, color)
		3:  # MOUNTAIN — single tall peak
			_glyph_mountain(c, s, color)
		4:  # RIVER — 2 horizontal wavy lines
			_glyph_river(c, s, color)
		5:  # BRIDGE — 2 rails + 4 cross-planks
			_glyph_bridge(c, s, color)
		6:  # FORTRESS WALL — crenellation ⊓⊓⊓
			_glyph_fortress(c, s, color)
		7:  # ROAD — dashed line
			_glyph_road(c, s, color)
		8:  # FIRE — flame teardrop
			_glyph_fire(c, s, color)
		_:
			pass


## FOREST — three small triangular tree silhouettes clustered.
## Layout: one center-top tree + two flanking trees slightly below.
func _glyph_forest(c: Vector2, s: float, color: Color) -> void:
	_draw_filled_triangle(c + Vector2(0.0, -s * 0.20), s * 0.55, color)
	_draw_filled_triangle(c + Vector2(-s * 0.75, s * 0.30), s * 0.45, color)
	_draw_filled_triangle(c + Vector2(s * 0.75, s * 0.30), s * 0.45, color)


## HILLS — two rolling arches side-by-side (⌒⌒). Drawn as a single polyline
## of two half-circles for a continuous wave-of-hills read.
func _glyph_hills(c: Vector2, s: float, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	var seg: int = 10
	# Left arch: x from -s to 0, y dips up (negative)
	for i: int in range(seg + 1):
		var t: float = float(i) / float(seg)
		var theta: float = PI * (1.0 - t)  # PI → 0
		pts.append(c + Vector2(
			-s * 0.55 + cos(theta) * s * 0.55,
			-sin(theta) * s * 0.45))
	# Right arch: continues from x=0 to x=s
	for i: int in range(seg + 1):
		var t: float = float(i) / float(seg)
		var theta: float = PI * (1.0 - t)
		pts.append(c + Vector2(
			s * 0.55 + cos(theta) * s * 0.55,
			-sin(theta) * s * 0.45))
	draw_polyline(pts, color, _TERRAIN_GLYPH_STROKE, true)


## MOUNTAIN — single sharp peak triangle (taller than wide for "산" reading).
func _glyph_mountain(c: Vector2, s: float, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array([
		c + Vector2(0.0, -s * 0.85),
		c + Vector2(s * 0.80, s * 0.55),
		c + Vector2(-s * 0.80, s * 0.55),
	])
	draw_colored_polygon(pts, color)


## RIVER — two horizontal wavy lines stacked vertically (water flow).
func _glyph_river(c: Vector2, s: float, color: Color) -> void:
	for y_off: float in [-s * 0.40, s * 0.40]:
		var pts: PackedVector2Array = PackedVector2Array()
		var seg: int = 16
		for i: int in range(seg + 1):
			var t: float = float(i) / float(seg)
			var x: float = lerp(-s * 1.05, s * 1.05, t)
			var y: float = y_off + sin(t * PI * 3.0) * s * 0.18
			pts.append(c + Vector2(x, y))
		draw_polyline(pts, color, _TERRAIN_GLYPH_STROKE, true)


## BRIDGE — two horizontal rails + four short vertical planks crossing.
func _glyph_bridge(c: Vector2, s: float, color: Color) -> void:
	# Two horizontal rails
	for y_off: float in [-s * 0.45, s * 0.45]:
		draw_line(
			c + Vector2(-s * 1.05, y_off),
			c + Vector2(s * 1.05, y_off),
			color, _TERRAIN_GLYPH_STROKE)
	# Four cross-planks
	for x_off: float in [-s * 0.80, -s * 0.27, s * 0.27, s * 0.80]:
		draw_line(
			c + Vector2(x_off, -s * 0.45),
			c + Vector2(x_off, s * 0.45),
			color, _TERRAIN_GLYPH_STROKE * 0.85)


## FORTRESS WALL — crenellation profile ⊓⊓⊓ as a single polyline
## (base → up → over → down → ...) describing 3 merlons on a base wall.
func _glyph_fortress(c: Vector2, s: float, color: Color) -> void:
	var base_y: float = s * 0.55
	var top_y:  float = -s * 0.55
	var mid_y:  float = -s * 0.10
	# 3 merlons, evenly spaced. Each merlon top ~0.30s wide.
	var pts: PackedVector2Array = PackedVector2Array([
		c + Vector2(-s * 1.05, base_y),  # base-left
		c + Vector2(-s * 1.05, mid_y),   # up to merlon base
		c + Vector2(-s * 0.75, mid_y),
		c + Vector2(-s * 0.75, top_y),   # merlon-1 top-left
		c + Vector2(-s * 0.30, top_y),   # merlon-1 top-right
		c + Vector2(-s * 0.30, mid_y),
		c + Vector2(s * 0.30, mid_y),
		c + Vector2(s * 0.30, top_y),    # merlon-2 top-left
		c + Vector2(s * 0.75, top_y),    # merlon-2 top-right (wait — gives 2 merlons)
		c + Vector2(s * 0.75, mid_y),
		c + Vector2(s * 1.05, mid_y),
		c + Vector2(s * 1.05, base_y),   # base-right
	])
	draw_polyline(pts, color, _TERRAIN_GLYPH_STROKE, true)


## ROAD — three short horizontal dashes (centered, evenly spaced).
func _glyph_road(c: Vector2, s: float, color: Color) -> void:
	var dash_len: float = s * 0.45
	var gap: float = s * 0.25
	var total_w: float = 3.0 * dash_len + 2.0 * gap
	var start_x: float = -total_w * 0.5
	for i: int in range(3):
		var x0: float = start_x + i * (dash_len + gap)
		draw_line(
			c + Vector2(x0, 0.0),
			c + Vector2(x0 + dash_len, 0.0),
			color, _TERRAIN_GLYPH_STROKE + 0.6)


## FIRE — flame teardrop silhouette (pointed up, rounded base).
func _glyph_fire(c: Vector2, s: float, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array([
		c + Vector2(0.0, -s * 0.85),         # tip
		c + Vector2(s * 0.45, -s * 0.20),    # right curve point
		c + Vector2(s * 0.60, s * 0.30),     # right flank
		c + Vector2(s * 0.30, s * 0.60),     # base right
		c + Vector2(-s * 0.30, s * 0.60),    # base left
		c + Vector2(-s * 0.60, s * 0.30),    # left flank
		c + Vector2(-s * 0.45, -s * 0.20),   # left curve point
	])
	draw_colored_polygon(pts, color)


## Helper — filled equilateral-ish triangle, apex pointing up, centered on
## `center` with `half_size` controlling the silhouette size.
func _draw_filled_triangle(center: Vector2, half_size: float, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array([
		center + Vector2(0.0, -half_size),
		center + Vector2(half_size * 0.85, half_size * 0.75),
		center + Vector2(-half_size * 0.85, half_size * 0.75),
	])
	draw_colored_polygon(pts, color)


## Session-55 — colorblind alternate channel for the movement-range favor
## signal. Draws ▲ (apex-up) for FAVORED tiles, ▼ (apex-down) for DISFAVORED
## tiles, nothing for NEUTRAL, in the tile's TOP-LEFT corner. Pure primitive
## ops (draw_colored_polygon) — no font dependency. Matches the redundant-
## channel pattern of damage-calc P_MULT cap ▲ glyph (design/gdd/damage-calc.md).
func _draw_favor_glyph(rect: Rect2, favor: int) -> void:
	if favor == 0:
		return
	var center: Vector2 = rect.position + _FAVOR_GLYPH_INSET
	var s: float = _FAVOR_GLYPH_HALF
	if favor > 0:
		# ▲ apex-up — advantage / "good" channel
		var up_pts: PackedVector2Array = PackedVector2Array([
			center + Vector2(0.0, -s),
			center + Vector2(s * 0.92, s * 0.75),
			center + Vector2(-s * 0.92, s * 0.75),
		])
		draw_colored_polygon(up_pts, _FAVOR_GLYPH_COLOR)
	else:
		# ▼ apex-down — disadvantage / "bad" channel
		var down_pts: PackedVector2Array = PackedVector2Array([
			center + Vector2(0.0, s),
			center + Vector2(s * 0.92, -s * 0.75),
			center + Vector2(-s * 0.92, -s * 0.75),
		])
		draw_colored_polygon(down_pts, _FAVOR_GLYPH_COLOR)


## Maps terrain_type enum (per src/core/terrain_cost.gd) to art-bible color.
## Unknown values fall back to PLAINS (graceful degradation, never crash).
func _get_terrain_color(terrain_type: int) -> Color:
	match terrain_type:
		0: return COLOR_PLAINS
		1: return COLOR_FOREST
		2: return COLOR_HILLS
		3: return COLOR_MOUNTAIN
		4: return COLOR_RIVER
		5: return COLOR_BRIDGE
		6: return COLOR_FORTRESS_WALL
		7: return COLOR_ROAD
		8: return COLOR_FIRE  # session-21 ch5 적벽 본전 — burning ship debris
		_: return COLOR_PLAINS
