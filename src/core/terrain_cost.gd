## TerrainCost — static cost constants and multiplier stub for Dijkstra pathfinding.
##
## This file is a GDScript namespace module: `extends RefCounted` so it can be
## instantiated via `.new()` without issue (RefCounted auto-frees), but the class
## is intended as a pure constant + static-function namespace — no state is held
## on instances. (ADR-0004 §Decision 7; approved: C-4.)
##
## Usage example:
##   var cost: int = TerrainCost.BASE_TERRAIN_COST[TerrainCost.PLAINS]
##   var step: int = cost * TerrainCost.cost_multiplier(unit_type, terrain_type)
##
## Terrain-type integer mirror (must match GDD §CR-3 and MapTileData.terrain_type):
##   PLAINS=0, FOREST=1, HILLS=2, MOUNTAIN=3, RIVER=4, BRIDGE=5, FORTRESS_WALL=6, ROAD=7
## These mirrors are declared here so pathfinding consumers do not need to import
## a separate enum. ADR-0008 will formalise the canonical enum; until then these
## are the single source of truth for Dijkstra inner-loop terrain index access.
class_name TerrainCost
extends RefCounted

# ─── Terrain-type integer mirrors ────────────────────────────────────────────
## Must stay in sync with GDD §CR-3 ordering and MapGrid.ELEVATION_RANGES indices.
## ADR-0008 will formalise these as an exported enum; these consts shadow that future enum.
const PLAINS        := 0
const FOREST        := 1
const HILLS         := 2
const MOUNTAIN      := 3
const RIVER         := 4
const BRIDGE        := 5
const FORTRESS_WALL := 6
const ROAD          := 7

# ─── Base terrain cost table ─────────────────────────────────────────────────
## Per-terrain base movement cost used in Dijkstra step_cost formula (GDD §F-2/F-3).
## `step_cost = BASE_TERRAIN_COST[terrain_type] * cost_multiplier(unit_type, terrain_type)`
##
## RIVER (4) and FORTRESS_WALL (6) have cost 0 because they are filtered upstream
## by `_passable_base_cache[idx] == 0`; their cost entries are present to keep
## the lookup O(1) but are unreachable in a correctly-loaded map (GDD §EC-7).
##
## Untyped `Dictionary` because Godot 4.6 GDScript does not support typed-Dictionary
## const literals (same constraint as ELEVATION_RANGES in map_grid.gd line 53).
## Track for ADR-0008 cleanup; candidate gotcha G-13 if typed const Dictionary
## parse error is confirmed in project's pinned Godot 4.6 build.
const BASE_TERRAIN_COST: Dictionary = {
	PLAINS:        10,
	FOREST:        15,
	HILLS:         15,
	MOUNTAIN:      20,
	RIVER:          0,
	BRIDGE:        10,
	FORTRESS_WALL:  0,
	ROAD:           7,
}

# ─── Cost multiplier ─────────────────────────────────────────────────────────
## Return the cost multiplier for [param unit_type] crossing [param terrain_type].
##
## PLACEHOLDER — returns 1 for all unit×terrain combinations.
## REPLACED WHEN ADR-0008 Terrain Effect lands; MVP ships with this placeholder.
## The function signature is stable so ADR-0008 replacement does not break consumers.
##
## [param unit_type] — integer unit-type id (will match ADR-0008 UnitType enum).
## [param terrain_type] — integer terrain-type id matching the consts above.
##
## Example:
##   var multiplier: int = TerrainCost.cost_multiplier(unit_type, terrain_type)
static func cost_multiplier(_unit_type: int, _terrain_type: int) -> int:
	return 1
