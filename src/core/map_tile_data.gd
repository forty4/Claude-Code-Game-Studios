## MapTileData — per-tile schema stored inline inside MapResource (ADR-0004 §Decision 1).
##
## CLASS RENAME NOTE: Originally named `TileData` per ADR-0004 §Decision 1.
## Renamed to `MapTileData` to avoid collision with the Godot 4.6 built-in
## `TileData` class used by TileSet/TileMapLayer API. ADR-0004 §Decision 1 errata
## — logged at /story-done for batched ADR correction.
##
## All persisted fields are annotated @export; non-exported fields are SILENTLY
## DROPPED by ResourceSaver (same gotcha ADR-0003 EchoMark surfaced).
##
## Enum mirrors (int fields):
##   terrain_type — authoritative enum source: GDD map-grid.md §CR-3
##   tile_state   — authoritative enum source: GDD map-grid.md §ST-1
## Using int mirrors keeps MapTileData schema-stable. A future story may extract
## them to a dedicated enums module; do not do so opportunistically here.
##
## Memory budget: ~64 B per MapTileData × 1200 tiles = ~77 KB per map at rest.
##
## See also: MapResource (src/core/map_resource.gd), ADR-0004.
class_name MapTileData
extends Resource

## Grid coordinate (column, row) of this tile.
## Access components via coord.x (col) and coord.y (row).
@export var coord: Vector2i = Vector2i.ZERO

## Terrain type enum mirror (int). Authoritative values: GDD map-grid.md §CR-3.
@export var terrain_type: int = 0

## Elevation in abstract height units. Higher values indicate elevated terrain.
@export var elevation: int = 0

## Tile state enum mirror (int). Authoritative values: GDD map-grid.md §ST-1.
@export var tile_state: int = 0

## Whether this tile can be destroyed during combat.
@export var is_destructible: bool = false

## Hit points remaining on a destructible tile. Ignored when is_destructible == false.
@export var destruction_hp: int = 0

## Entity ID of the occupant currently on this tile. 0 = unoccupied.
@export var occupant_id: int = 0

## Faction ID of the occupant. 0 = no faction / unoccupied.
@export var occupant_faction: int = 0

## Base passability before runtime modifiers (weather, destruction, etc.).
## true = passable by default; runtime systems may override per movement type.
@export var is_passable_base: bool = true
