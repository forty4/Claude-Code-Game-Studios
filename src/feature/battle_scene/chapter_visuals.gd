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


## Pixel size of one grid tile. Coordinates the tile-space rendering with
## unit-silhouette Polygon2D children authored in the .tscn at fixed positions
## (col * TILE_SIZE + TILE_SIZE/2, row * TILE_SIZE + TILE_SIZE/2). If this
## constant changes, .tscn unit positions must be re-authored to match.
const TILE_SIZE: int = 48

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
