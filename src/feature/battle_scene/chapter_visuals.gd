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


## Faction colors per art-bible §4.2. Used by spawn_unit_polygons() to color
## player vs enemy unit silhouettes. side==0 = player (촉/Shu blue);
## side==1 = enemy (위/Wei charcoal). Reserved 주홍/금색 must NOT appear here.
const COLOR_FACTION_PLAYER: Color = Color("2e5f7a")
const COLOR_FACTION_ENEMY:  Color = Color("4a4a4a")

## Unit polygon half-extent — bumped from 20 (≈40×40) to 26 (≈52×52) so units
## occupy ~80% of the 64px tile and read clearly at default 1.0 camera zoom.
const _UNIT_HALF: int = 26


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


## Spawns one Polygon2D per roster unit under PlayerUnits/EnemyUnits, replacing
## any pre-authored or previously-spawned polygons. Shape is class-coded
## (UnitRole.UnitClass enum); color is faction-coded (BattleUnit.side); rotation
## is facing-coded for directional classes (CAVALRY/ARCHER apex points along the
## facing axis). Names follow the `Unit{unit_id}_*` convention so the existing
## battle_scene.gd _find_unit_polygon() helper (move/damage/death handlers) keeps
## working unchanged.
func spawn_unit_polygons(roster: Array[BattleUnit]) -> void:
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
		poly.color = COLOR_FACTION_PLAYER if unit.side == 0 else COLOR_FACTION_ENEMY
		poly.polygon = _shape_for_class(unit.unit_class)
		poly.rotation = rotation_for_facing(unit.facing, unit.unit_class)
		if unit.side == 0:
			player_parent.add_child(poly)
		else:
			enemy_parent.add_child(poly)
		# Name label above the polygon so the player can identify who's who at
		# a glance instead of staring at indistinguishable shape+color tokens.
		# Parented to the polygon so it follows transforms (slide/death-fade).
		var hero: HeroData = HeroDatabase.get_hero(unit.hero_id)
		var label: Label = Label.new()
		label.name = "NameLabel"
		label.text = hero.name_ko if hero != null and hero.name_ko != "" else String(unit.hero_id)
		label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 1.0))
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05, 1.0))
		label.add_theme_constant_override("outline_size", 6)
		label.add_theme_font_size_override("font_size", 16)
		# Counter the polygon's facing rotation so the label always reads upright.
		label.rotation = -poly.rotation
		label.position = Vector2(-28, -44)
		label.size = Vector2(56, 18)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		poly.add_child(label)


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
