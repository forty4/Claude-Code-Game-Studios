extends SceneTree

## generate_stress_40x30.gd — Story 007 stress fixture generator (one-shot).
##
## Procedurally builds a 40×30 MapResource with terrain distribution
## **60% PLAINS / 15% HILLS / 10% FOREST / 10% ROAD / 5% MOUNTAIN** (totals 100%).
## Implementation: deterministic modulo-100 cycling across 1200 tiles, producing
## exact counts 720 / 180 / 120 / 120 / 60. No random seeds — reproducible across
## machines and runs.
##
## Place 5 deterministic ENEMY_OCCUPIED tiles at fixed coords (story-007 line 56).
## NO FORTRESS_WALL — pathfinding-unfriendly tiles bias the perf measurement
## (story-007 line 40).
##
## Run once via:
##   godot --headless --path . -s res://tests/fixtures/generate_stress_40x30.gd
##
## Output: tests/fixtures/maps/stress_40x30.tres committed as a deterministic
## perf-baseline asset. DO NOT regenerate on every test run — perf comparison
## across builds requires a stable fixture.
##
## NOTE: the generator output is referenced by tests/integration/core/map_grid_perf_test.gd.
## Changes to the distribution invalidate the perf baseline — consult story-007
## §QA Test Cases before modifying.

const OUTPUT_PATH: String = "res://tests/fixtures/maps/stress_40x30.tres"

const MAP_COLS: int = 40
const MAP_ROWS: int = 30

# Terrain integer constants — must mirror MapGrid's ordering (TD-032 A-16).
# PLAINS=0, FOREST=1, HILLS=2, MOUNTAIN=3, RIVER=4, BRIDGE=5, FORTRESS_WALL=6, ROAD=7
const TT_PLAINS:   int = 0
const TT_FOREST:   int = 1
const TT_HILLS:    int = 2
const TT_MOUNTAIN: int = 3
const TT_ROAD:     int = 7

# Elevation per terrain (matches MapGrid.ELEVATION_RANGES — first valid value).
const ELEV_FOR_TERRAIN: Array[int] = [0, 0, 1, 2, 0, 0, 1, 0]

# Story-007 line 56 listed (20,15) as an enemy coord, but story-007 line 80
# also specifies (20,15) as the player query origin. The two collide. Resolution:
# replace (20,15) with (25,12) for the enemy, keeping 5 deterministic obstacles
# at non-conflicting mid-map positions. Player coord remains (20,15) per spec.
const ENEMY_COORDS: Array[Vector2i] = [
	Vector2i(5, 5),
	Vector2i(12, 8),
	Vector2i(25, 12),
	Vector2i(30, 20),
	Vector2i(8, 22),
]

# Tile-state constants — must mirror MapGrid (story-004 numbering).
const TILE_STATE_EMPTY:          int = 0
const TILE_STATE_ENEMY_OCCUPIED: int = 2

# Faction constants — must mirror MapGrid.
const FACTION_NONE:  int = 0
const FACTION_ENEMY: int = 2


func _init() -> void:
	print("Generating stress_40x30.tres ...")

	var m: MapResource = MapResource.new()
	m.map_id = &"stress_40x30"
	m.map_rows = MAP_ROWS
	m.map_cols = MAP_COLS
	m.terrain_version = 1

	var n: int = MAP_ROWS * MAP_COLS  # 1200 tiles
	var tile_distribution: Array[int] = _build_distribution(n)

	for i: int in n:
		var col: int = i % MAP_COLS
		var row: int = i / MAP_COLS
		var coord: Vector2i = Vector2i(col, row)

		var terrain: int = tile_distribution[i]
		var elev: int = ELEV_FOR_TERRAIN[terrain]

		var t: MapTileData = MapTileData.new()
		t.coord            = coord
		t.terrain_type     = terrain
		t.elevation        = elev
		t.is_passable_base = true
		t.tile_state       = TILE_STATE_EMPTY
		t.occupant_id      = 0
		t.occupant_faction = FACTION_NONE
		t.is_destructible  = false
		t.destruction_hp   = 0
		m.tiles.append(t)

	# Apply 5 ENEMY_OCCUPIED overrides at deterministic coords.
	for ec: Vector2i in ENEMY_COORDS:
		var idx: int = ec.y * MAP_COLS + ec.x
		var tile: MapTileData = m.tiles[idx]
		# Force PLAINS at enemy coords for clean ENEMY_OCCUPIED state setup.
		tile.terrain_type     = TT_PLAINS
		tile.elevation        = 0
		tile.tile_state       = TILE_STATE_ENEMY_OCCUPIED
		# Note: Each enemy occupant_id starts at 100 + index for deterministic IDs
		# distinct from the test's player unit_id=1.
		tile.occupant_id      = 100 + ENEMY_COORDS.find(ec)
		tile.occupant_faction = FACTION_ENEMY

	var err: int = ResourceSaver.save(m, OUTPUT_PATH)
	if err != OK:
		push_error("ResourceSaver.save FAILED with error %d for path %s" % [err, OUTPUT_PATH])
		quit(1)
		return

	print("Generated %s — %d tiles, terrain dist: PLAINS=%d FOREST=%d HILLS=%d ROAD=%d MOUNTAIN=%d, %d enemy occupants." \
		% [OUTPUT_PATH, n,
		   _count(tile_distribution, TT_PLAINS),
		   _count(tile_distribution, TT_FOREST),
		   _count(tile_distribution, TT_HILLS),
		   _count(tile_distribution, TT_ROAD),
		   _count(tile_distribution, TT_MOUNTAIN),
		   ENEMY_COORDS.size()])
	quit(0)


## Build a deterministic tile-distribution array of length [param n].
##
## Distribution: 60% PLAINS / 15% HILLS / 10% FOREST / 10% ROAD / 5% MOUNTAIN.
## Total = 100%. Implemented as a fixed pattern (modulo-based) for reproducibility
## across machines and runs — no random seeds.
func _build_distribution(n: int) -> Array[int]:
	var result: Array[int] = []
	result.resize(n)
	# Use modulo cycling on a length-100 pattern. This produces deterministic
	# tile placement that statistically matches the target distribution across
	# any multiple-of-100 tile count (1200 = 12 cycles).
	#
	# Pattern: 60 PLAINS, 15 HILLS, 10 FOREST, 10 ROAD, 5 MOUNTAIN.
	for i: int in n:
		var bucket: int = i % 100
		if bucket < 60:
			result[i] = TT_PLAINS
		elif bucket < 75:
			result[i] = TT_HILLS
		elif bucket < 85:
			result[i] = TT_FOREST
		elif bucket < 95:
			result[i] = TT_ROAD
		else:
			result[i] = TT_MOUNTAIN
	return result


func _count(arr: Array[int], target: int) -> int:
	var c: int = 0
	for v: int in arr:
		if v == target:
			c += 1
	return c
