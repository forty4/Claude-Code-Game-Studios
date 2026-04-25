extends SceneTree

## generate_sample_small.gd — Story 008 sample fixture generator (one-shot).
##
## Procedurally builds a 15×15 [MapResource] for inspector authoring documentation.
## Demonstrates the AC-SAMPLE-15x15 contract (story-008): mixed terrain (PLAINS,
## HILLS, ROAD, FOREST) + at least one destructible FORTRESS_WALL.
##
## Used by:
##   - Inspector authoring workflow (story-008) — opened in Godot inspector to
##     show the editor experience for content authors.
##   - AC-EDIT-ROUND-TRIP smoke (story-008) — sentinel field flips edited via
##     inspector + ResourceLoader round-trip verifies persistence.
##   - AC-R3-INLINE-ASSERT plain-text inspection (story-008) — confirms TileData
##     entries are inline SubResource blocks, not ExtResource references.
##
## Run once via:
##   godot --headless --path . -s res://tests/fixtures/generate_sample_small.gd
##
## Output: res://data/maps/sample_small.tres committed as a content-authoring
## reference asset.

const OUTPUT_PATH: String = "res://data/maps/sample_small.tres"

const MAP_COLS: int = 15
const MAP_ROWS: int = 15

# Terrain integer constants — mirror MapGrid's ordering (TD-032 A-16):
# PLAINS=0, FOREST=1, HILLS=2, MOUNTAIN=3, RIVER=4, BRIDGE=5, FORTRESS_WALL=6, ROAD=7
const TT_PLAINS:        int = 0
const TT_FOREST:        int = 1
const TT_HILLS:         int = 2
const TT_ROAD:          int = 7
const TT_FORTRESS_WALL: int = 6

# Elevation per terrain (matches MapGrid.ELEVATION_RANGES — first valid value).
# FORTRESS_WALL must be elev 1 or 2 (CR-3); pick 1.
const ELEV_FOR_TERRAIN: Array[int] = [0, 0, 1, 2, 0, 0, 1, 0]

# Tile-state constants — mirror MapGrid (story-004 numbering).
const TILE_STATE_EMPTY:        int = 0
const TILE_STATE_DESTRUCTIBLE: int = 4

# Faction constants.
const FACTION_NONE: int = 0


func _init() -> void:
	print("Generating sample_small.tres (15×15) ...")

	var m: MapResource = MapResource.new()
	m.map_id = &"sample_small"
	m.map_rows = MAP_ROWS
	m.map_cols = MAP_COLS
	m.terrain_version = 1

	var n: int = MAP_ROWS * MAP_COLS  # 225 tiles

	# Hand-curated mixed-terrain pattern showcasing each non-water terrain type
	# the validator accepts. This is a "happy path" authoring example, NOT a
	# perf fixture — readability + variety beat statistical distribution.
	#
	# Layout (15×15 grid):
	#   - Outer border row 0 + row 14: ROAD (the perimeter highway)
	#   - Outer border col 0 + col 14: PLAINS (open flank)
	#   - Diagonal stripe (row=col, 1..13): FOREST
	#   - Anti-diagonal stripe (row+col=14, but inner only): HILLS
	#   - Center (7,7): destructible FORTRESS_WALL (the AC-required destructible)
	#   - Everything else: PLAINS
	for i: int in n:
		var col: int = i % MAP_COLS
		var row: int = i / MAP_COLS
		var coord: Vector2i = Vector2i(col, row)

		var terrain: int = TT_PLAINS  # default

		# Center destructible wall.
		if col == 7 and row == 7:
			terrain = TT_FORTRESS_WALL
		# Diagonal forest stripe (inner cells, 1..13).
		elif col == row and col >= 1 and col <= 13:
			terrain = TT_FOREST
		# Anti-diagonal hills stripe (inner cells).
		elif (col + row) == 14 and col >= 1 and col <= 13:
			terrain = TT_HILLS
		# Top/bottom road.
		elif row == 0 or row == 14:
			terrain = TT_ROAD

		var t: MapTileData = MapTileData.new()
		t.coord            = coord
		t.terrain_type     = terrain
		t.elevation        = ELEV_FOR_TERRAIN[terrain]
		t.is_passable_base = (terrain != TT_FORTRESS_WALL)
		t.tile_state       = TILE_STATE_DESTRUCTIBLE if terrain == TT_FORTRESS_WALL else TILE_STATE_EMPTY
		t.occupant_id      = 0
		t.occupant_faction = FACTION_NONE
		t.is_destructible  = (terrain == TT_FORTRESS_WALL)
		t.destruction_hp   = 10 if terrain == TT_FORTRESS_WALL else 0
		m.tiles.append(t)

	var err: int = ResourceSaver.save(m, OUTPUT_PATH)
	if err != OK:
		push_error("ResourceSaver.save FAILED with error %d for path %s" % [err, OUTPUT_PATH])
		quit(1)
		return

	# Diagnostic: count terrain types for the print summary.
	var counts: Dictionary = {0: 0, 1: 0, 2: 0, 6: 0, 7: 0}
	for tile: MapTileData in m.tiles:
		counts[tile.terrain_type] = counts.get(tile.terrain_type, 0) + 1

	print("Generated %s — %d tiles. Terrain mix: PLAINS=%d FOREST=%d HILLS=%d ROAD=%d FORTRESS_WALL=%d (destructible)" \
		% [OUTPUT_PATH, n,
		   counts[0] as int, counts[1] as int, counts[2] as int,
		   counts[7] as int, counts[6] as int])
	quit(0)
