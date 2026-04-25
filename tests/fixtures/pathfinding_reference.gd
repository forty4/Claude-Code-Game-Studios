## PathfindingReference — intentionally simple reference Dijkstra for V-4 equivalence tests.
##
## This implementation uses Dictionary + Array freely — it is NOT performance-tuned.
## Its purpose is correctness: it provides a second-order Dijkstra for cross-checking
## against the production packed-cache Dijkstra in MapGrid (story-005 AC-8 / V-4).
##
## Lives in tests/fixtures/ — test tree only, never imported from src/.
##
## Usage example (in a GdUnit4 test):
##   var ref := PathfindingReference.new()
##   var ref_cost: int = ref.path_cost(grid, from, to, unit_type)
##   var prod_path: PackedVector2Array = grid.get_movement_path(from, to, unit_type)
##   assert_int(prod_cost).is_equal(ref_cost)
##
## `extends RefCounted` — standard GDScript namespace idiom (approved C-4).
## A `.new()` call is harmless; instance auto-frees.
class_name PathfindingReference
extends RefCounted

## Compute the minimum-cost path from [param from] to [param to] on [param grid].
##
## Returns an [Array] (untyped) of [Vector2i] tile coordinates from [param from]
## to [param to] inclusive, or an empty Array if [param to] is unreachable.
## [code]from == to[/code] returns [code][from][/code] (single element).
##
## Uses plain Dictionary + Array — intentionally readable, not performance-tuned.
## [param unit_type] forwarded to [method TerrainCost.cost_multiplier] (same lookup
## as production Dijkstra so cost values are comparable).
##
## Example:
##   var path: Array = ref.compute_path(grid, Vector2i(0,0), Vector2i(4,4), 0)
func compute_path(grid: MapGrid, from: Vector2i, to: Vector2i, unit_type: int) -> Array:
	if from == to:
		return [from]

	var cols: int = grid._map.map_cols
	var rows: int = grid._map.map_rows

	if from.x < 0 or from.x >= cols or from.y < 0 or from.y >= rows:
		return []
	if to.x < 0 or to.x >= cols or to.y < 0 or to.y >= rows:
		return []

	# dist[coord] = minimum cost found so far.
	var dist: Dictionary = {}
	# predecessor[coord] = Vector2i coord of the tile before this one on best path.
	var predecessor: Dictionary = {}
	# Simple unordered frontier; we scan for minimum each iteration (correct, slow).
	var frontier: Array[Vector2i] = []

	dist[from] = 0
	frontier.append(from)

	var offsets: Array[Vector2i] = [
		Vector2i(0, -1),
		Vector2i(1,  0),
		Vector2i(0,  1),
		Vector2i(-1, 0),
	]

	while frontier.size() > 0:
		# Find minimum-cost coord in frontier (linear scan — reference impl, O(n²) OK).
		var best_idx: int = 0
		var best_cost: int = dist[frontier[0]] as int
		for fi: int in range(1, frontier.size()):
			var fc: int = dist[frontier[fi]] as int
			if fc < best_cost:
				best_cost = fc
				best_idx = fi

		var cur: Vector2i = frontier[best_idx]
		frontier.remove_at(best_idx)

		if cur == to:
			break

		var cur_cost: int = dist[cur] as int
		var cur_idx: int = cur.y * cols + cur.x

		for off: Vector2i in offsets:
			var ncol: int = cur.x + off.x
			var nrow: int = cur.y + off.y

			if ncol < 0 or ncol >= cols or nrow < 0 or nrow >= rows:
				continue

			var nidx: int = nrow * cols + ncol
			var ncoord: Vector2i = Vector2i(ncol, nrow)

			# Passability — read packed caches (same source as production Dijkstra).
			if grid._passable_base_cache[nidx] == 0:
				continue

			var nstate: int = grid._tile_state_cache[nidx]
			if nstate == MapGrid.TILE_STATE_ENEMY_OCCUPIED \
					or nstate == MapGrid.TILE_STATE_IMPASSABLE:
				continue

			var terrain: int = grid._terrain_type_cache[nidx]
			var step: int = TerrainCost.BASE_TERRAIN_COST[terrain] \
					* TerrainCost.cost_multiplier(unit_type, terrain)
			var new_cost: int = cur_cost + step

			# Relax edge.
			if not dist.has(ncoord) or new_cost < (dist[ncoord] as int):
				dist[ncoord] = new_cost
				predecessor[ncoord] = cur
				if not ncoord in frontier:
					frontier.append(ncoord)

	if not dist.has(to):
		return []

	# Reconstruct path by walking predecessors.
	var path: Array = []
	var c: Vector2i = to
	while c != from:
		path.append(c)
		if not predecessor.has(c):
			return []  # Broken chain — should not happen on a valid result.
		c = predecessor[c] as Vector2i
	path.append(from)
	path.reverse()
	return path


## Return the total movement cost of a path as computed by [method compute_path].
##
## [param path] — Array of [Vector2i] coordinates (from compute_path or production get_movement_path).
## [param grid] — the MapGrid instance (provides packed caches).
## [param unit_type] — unit-type id for cost_multiplier.
##
## Returns 0 for a path of length 0 or 1. Skips the first tile (origin has no entry cost).
##
## Example:
##   var cost: int = ref.path_cost_from_array(path_array, grid, unit_type)
func path_cost_from_array(path: Array, grid: MapGrid, unit_type: int) -> int:
	if path.size() <= 1:
		return 0
	var cols: int = grid._map.map_cols
	var total: int = 0
	# Skip index 0 (origin — no entry cost); sum from index 1 onward.
	for i: int in range(1, path.size()):
		var coord: Vector2i = path[i] as Vector2i
		var idx: int = coord.y * cols + coord.x
		var terrain: int = grid._terrain_type_cache[idx]
		total += TerrainCost.BASE_TERRAIN_COST[terrain] \
				* TerrainCost.cost_multiplier(unit_type, terrain)
	return total


## Same as [method path_cost_from_array] but accepts a [PackedVector2Array] directly
## (for comparing against production [method MapGrid.get_movement_path] output without
## manual conversion).
##
## Example:
##   var ref_cost: int = ref.path_cost_from_packed(grid.get_movement_path(f, t, u), grid, unit_type)
func path_cost_from_packed(path: PackedVector2Array, grid: MapGrid, unit_type: int) -> int:
	if path.size() <= 1:
		return 0
	var cols: int = grid._map.map_cols
	var total: int = 0
	for i: int in range(1, path.size()):
		var coord: Vector2i = Vector2i(path[i])
		var idx: int = coord.y * cols + coord.x
		var terrain: int = grid._terrain_type_cache[idx]
		total += TerrainCost.BASE_TERRAIN_COST[terrain] \
				* TerrainCost.cost_multiplier(unit_type, terrain)
	return total
