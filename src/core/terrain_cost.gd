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
## a separate enum. ADR-0008 (Accepted 2026-04-25) has formalised the canonical
## ordering; these consts mirror TerrainEffect's constants. ADR-0009 Unit Role
## (not yet written) will populate concrete per-class cost_matrix values.
class_name TerrainCost
extends RefCounted

# ─── Terrain-type integer mirrors ────────────────────────────────────────────
## Must stay in sync with GDD §CR-3 ordering and MapGrid.ELEVATION_RANGES indices.
## ADR-0008 (Accepted 2026-04-25) has formalised the canonical ordering; these consts
## mirror TerrainEffect's terrain-type constants. ADR-0009 will define the UnitType enum.
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
## See gotcha G-1 (codified in .claude/rules/godot-4x-gotchas.md) — do NOT convert
## this to Dictionary[int, int]; the engine rejects generic-typed const Dictionaries.
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
## Delegates to [method TerrainEffect.cost_multiplier] (ADR-0008 §Decision 5
## §Migration Plan). MVP returns 1 for all pairs per CR-1d uniformity (TR-002);
## ADR-0009 Unit Role will populate concrete per-class values via TerrainEffect's
## _cost_matrix lookup. This delegate's signature is stable across that population
## change — only the value returned by TerrainEffect.cost_multiplier evolves.
##
## [param unit_type] — integer unit-type id (will match ADR-0009 UnitType enum).
## [param terrain_type] — integer terrain-type id matching the consts above.
##
## Future deletion: per ADR-0008 §Migration Plan step 4, this file will be deleted
## entirely once all callers migrate to TerrainEffect.cost_multiplier() directly.
## Tracked as TD when ADR-0009 lands.
##
## Example:
##   var multiplier: int = TerrainCost.cost_multiplier(unit_type, terrain_type)
static func cost_multiplier(unit_type: int, terrain_type: int) -> int:
	return TerrainEffect.cost_multiplier(unit_type, terrain_type)
