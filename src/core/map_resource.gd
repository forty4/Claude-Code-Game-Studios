## MapResource — serialisable map schema (ADR-0004 §Decision 1).
##
## Stores the flat tile array and map dimensions for one map asset.
## Ratified by ADR-0004. All persisted fields are annotated @export;
## non-exported fields are SILENTLY DROPPED by ResourceSaver.
##
## INLINE-ONLY INVARIANT (ADR-0004 R-3):
##   TileData entries MUST remain inline inside MapResource.tres.
##   Never reference a TileData instance by external UID / shared .tres preset.
##   duplicate_deep() on a MapResource containing UID-referenced TileData returns
##   the SHARED instance — destruction state leaks between maps. Inline-only
##   prevents this class of bug entirely.
##
## Flat-array indexing convention (TR-map-grid-001):
##   tiles[coord.y * map_cols + coord.x]
##
## See also: MapTileData (src/core/map_tile_data.gd), ADR-0004.
## NOTE: tiles array was Array[TileData] prior to this rename. Class renamed
## MapTileData to avoid Godot 4.6 built-in TileData collision (TileSet/TileMapLayer
## API). ADR-0004 §Decision 1 errata — logged at /story-done for batched ADR correction.
class_name MapResource
extends Resource

## Schema version. Bump on every additive or breaking change.
## Loader consults schema_version to decide whether migration is required.
## Mirrors ADR-0003 schema_version convention; stored on MapResource, not globally.
@export var terrain_version: int = 1

## Stable map identifier used as a dictionary key throughout the runtime (StringName
## for fast hashing). Set to a unique value for every map asset.
@export var map_id: StringName = &""

## Number of rows in the grid (height in tiles).
@export var map_rows: int = 0

## Number of columns in the grid (width in tiles).
@export var map_cols: int = 0

## Flat tile array. Access a tile at (col, row) via:
##   tiles[row * map_cols + col]   — equivalently tiles[coord.y * map_cols + coord.x]
## Size must equal map_rows * map_cols; enforced by MapValidator (story-003).
## Empty array is valid at construction time — validation lives in story-003.
@export var tiles: Array[MapTileData] = []
