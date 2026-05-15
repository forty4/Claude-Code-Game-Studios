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
##   var cv: ChapterVisuals = preload("res://scenes/battle/mvp_chapter_01.tscn") \
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

## Color palette (art-bible §4.1 — non-reserved subset only).
const COLOR_PLAINS:        Color = Color("6b8c5a")  # 소록 — natural plains
const COLOR_FOREST:        Color = Color("4a6b3a")  # 소록 어두움 — forest density
const COLOR_HILLS:         Color = Color("a06a30")  # 황토 어두움 — earthen hills
const COLOR_MOUNTAIN:      Color = Color("1c1a17")  # 묵 — mountain mass
const COLOR_RIVER:         Color = Color("4a6878")  # 청회 깊은 — water tactical barrier
const COLOR_BRIDGE:        Color = Color("a0744a")  # 황토 갈색 — wooden bridge tone
const COLOR_FORTRESS_WALL: Color = Color("1c1a17")  # 묵 — solid wall mass
const COLOR_ROAD:          Color = Color("c8b898")  # 지백 어두움 — paved path
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

## Per-hero accent border stroke (width in world px). Wide enough to read as a
## clear ring around the polygon at the default 1.0 camera zoom; narrow enough
## not to obscure the class shape underneath.
const _HERO_BORDER_WIDTH: float = 4.0


func set_selected_coord(coord: Vector2i) -> void:
	if _selected_coord == coord:
		return
	_selected_coord = coord
	queue_redraw()


## Active turn coord — drawn as a thick gold border on the tile so the player
## immediately knows which unit may act. Independent from selection (the player
## may still inspect non-active units by clicking the ribbon).
func set_active_turn_coord(coord: Vector2i) -> void:
	if _active_turn_coord == coord:
		return
	_active_turn_coord = coord
	queue_redraw()


## Updates the movement-range preview overlay. Pass an empty array to clear.
## Called from BattleScene._on_unit_selected_changed after computing the
## movable set via GridBattleController.get_movable_tiles().
func set_movable_tiles(tiles: PackedVector2Array) -> void:
	_movable_tiles = tiles
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
		# Per-hero accent BORDER as a closed Line2D over the polygon's edge.
		# Same shape, vivid hero-specific color → individual generals are
		# distinct within their faction without diluting the faction fill read.
		# modulate cascade from the parent polygon takes the border along for
		# damage-flash / death-fade / end-of-turn dim / round-undim animations.
		var border: Line2D = Line2D.new()
		border.name = "HeroBorder"
		border.points = shape
		border.closed = true
		border.width = _HERO_BORDER_WIDTH
		border.default_color = _get_hero_accent(unit.hero_id, unit.side)
		border.joint_mode = Line2D.LINE_JOINT_BEVEL
		border.antialiased = true
		poly.add_child(border)
		# Session-16: small class-glyph inside the polygon (spear / shield / bow
		# / scroll / crown / dagger). Counter-rotated against the polygon facing
		# so the glyph stays upright. Reads as "what this piece does" at a glance
		# without obscuring the shape silhouette — placed at origin (center).
		# Also paints a per-hero overlay symbol (수염 / 안대 / 꽃 / 별 / 산 / 부채
		# / 등) using the hero accent color so 관우와 장비를 한 눈에 구분.
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
		var hero: HeroData = HeroDatabase.get_hero(unit.hero_id)
		var accent: Color = _get_hero_accent(unit.hero_id, unit.side)
		# Brighten the accent slightly so it reads at small font sizes against
		# any terrain backdrop without dropping to dim.
		var label_color: Color = accent.lerp(Color(1.0, 1.0, 1.0, 1.0), 0.45)
		var label: Label = Label.new()
		label.name = "NameLabel"
		label.text = hero.name_ko if hero != null and hero.name_ko != "" else String(unit.hero_id)
		label.add_theme_color_override("font_color", label_color)
		label.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.05, 1.0))
		label.add_theme_constant_override("outline_size", 8)
		label.add_theme_font_size_override("font_size", 20)
		# Counter the polygon's facing rotation so the label always reads upright.
		label.rotation = -poly.rotation
		label.position = Vector2(-40, -52)
		label.size = Vector2(80, 22)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		poly.add_child(label)


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
			draw_rect(rect, COLOR_TILE_BORDER, false, 1.0)

	# Movement-range preview (drawn before selection outline so the outline
	# stays visually on top of all overlays).
	for v: Vector2 in _movable_tiles:
		var move_rect: Rect2 = Rect2(
			Vector2(int(v.x) * TILE_SIZE, int(v.y) * TILE_SIZE),
			Vector2(TILE_SIZE, TILE_SIZE),
		)
		draw_rect(move_rect, COLOR_MOVE_PREVIEW, true)

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
		_: return COLOR_PLAINS
