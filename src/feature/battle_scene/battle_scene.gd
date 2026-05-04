## BattleScene — scene-root orchestrator for the battle screen.
##
## Per ADR-0016 §1: NEW pattern — scene-root-as-orchestrator. Distinct from the
## 5-precedent battle-scoped Node setup() pattern (Camera + HP/Status + Turn Order
## + Grid Battle + Battle HUD) because BattleScene IS the scene root, not a child.
##
## Mounts 6 battle-scoped child Nodes (MapGrid → BattleCamera → HPStatusController
## → TurnOrderRunner → GridBattleController → BattleHUD) in DI dependency order.
## Setup-before-add_child is enforced for all 5 systems that mandate it.
##
## Lifecycle: created and freed by ADR-0002 SceneManager (Overworld↔BattleScene
## transition flow) OR by Godot's main_scene config (sprint-6 standalone launch
## only — see ADR-0016 §5 + §Migration Plan revert path).
##
## R-7: NO GameBus subscriptions on BattleScene root.
## R-6: NO _exit_tree() body — auto-tree-free + each child's own _exit_tree().
## R-10: No static state. Not an autoload. No parameter-on-instantiate.
##
## IN-6 (implementation drift): ADR-0016 §3 shows _map_grid.load_map_resource();
##   shipped MapGrid API is load_map(res: MapResource) -> bool. Using load_map().
## IN-7 (implementation drift): ADR-0016 §4 shows MapResource.width/height/tile_data;
##   shipped MapResource fields are map_cols/map_rows/tiles: Array[MapTileData].
##   Mock builder updated to match.
## IN-8 (implementation drift): ADR-0016 §3 shows _unit_role.get_class_for_hero();
##   UnitRole has no such method (static-only class, no per-hero-class lookup at this
##   API level). Mock uses unit.unit_class (already set on BattleUnit) to call
##   HPStatusController.initialize_unit(). Sprint-7+ when real BattleConfig lands,
##   class is provided per hero definition — no code change to signature needed.
## IN-9 (implementation drift): ADR-0016 §4 shows mock tiles as Array[StringName];
##   MapResource.tiles is Array[MapTileData]. _make_uniform_grass_tiles() builds
##   properly typed Array[MapTileData] with is_passable_base=true + coord set.

class_name BattleScene
extends Node2D


# ─── Scene tree references ────────────────────────────────────────────────────

## Populated by @onready after the 3-node skeleton's _ready() fires.
## Grid-space overlays (UI-GB-12/13/14) mount under _grid_layer at runtime
## per ADR-0015 §2. HUDLayer layer=1 ensures screen-space HUD renders above all
## world-space siblings regardless of sibling order.
@onready var _grid_layer: Node2D = $GridLayer
@onready var _hud_layer: CanvasLayer = $HUDLayer


# ─── DI'd backend references (autoloads — already booted before _ready) ──────

## All 5 accessed as their class_name identifiers. Stored as fields for
## inspection and future test seam compatibility.
var _hero_db: HeroDatabase
var _balance_constants: BalanceConstants
var _terrain_effect: TerrainEffect
var _unit_role: UnitRole
var _input_router: InputRouter


# ─── Battle-scoped child Node references ─────────────────────────────────────

var _map_grid: MapGrid
var _battle_camera: BattleCamera
var _hp_controller: HPStatusController
var _turn_runner: TurnOrderRunner
var _grid_controller: GridBattleController
var _battle_hud: BattleHUD


# ─── Built-in virtual methods ─────────────────────────────────────────────────

## _ready() — 6-step mount sequence per ADR-0016 §3.
##
## Each step: instantiate system → call setup() / initialize() → add_child().
## The setup-before-add_child ordering is MANDATORY for all 5 system ADRs
## (ADR-0010/0011/0013/0014/0015 R-N). The sprint-6 mock encounter is marked
## with explicit deletion markers per ADR-0016 R-4.
##
## Idempotent under all 3 launch sources per R-8:
##   (a) SceneManager-driven (ADR-0002 deferred packed-scene instantiation)
##   (b) project.godot main_scene config
##   (c) godot --main-scene CLI override
func _ready() -> void:
	# === DI: 5 backends per ADR-0016 IN-10 + G-22 reflective bypass for @abstract ===
	# HeroDatabase + UnitRole are @abstract — direct .new() blocks at parse time
	# on typed reference (per G-22). Reflective load(path).new() path bypasses
	# @abstract enforcement and returns a live RefCounted instance assignable
	# to typed fields. BalanceConstants + TerrainEffect are not @abstract — direct
	# .new() works. InputRouter (extends Node) needs add_child after .new().
	# Sprint-7+ when autoload graduation lands (e.g. InputRouter at input-handling
	# epic close), revert to autoload-identifier reads.
	_hero_db = (load("res://src/foundation/hero_database.gd") as GDScript).new()
	_unit_role = (load("res://src/foundation/unit_role.gd") as GDScript).new()
	_balance_constants = BalanceConstants.new()
	_terrain_effect = TerrainEffect.new()
	_input_router = InputRouter.new()
	_input_router.name = "InputRouter"
	add_child(_input_router)  # Node child of BattleScene root (TD-058 placeholder)

	# === SPRINT-6 MOCK ENCOUNTER ===
	# TODO: REMOVE WHEN ADR-0017 SCENARIO PROGRESSION LANDS
	# Sprint-7+ replacement: roster + map_resource come from BattleConfig
	# passed by ScenarioRunner via SceneManager.battle_launch_requested payload.
	var mock_roster: Array[BattleUnit] = _build_mock_roster_sprint6()
	# 15×15 minimum per ADR-0016 IN-9 (MapGrid validation enforces MAP_COLS_MIN=15 + MAP_ROWS_MIN=15)
	var mock_map_resource: MapResource = _build_mock_map_resource_sprint6(15, 15)
	# === END MOCK ===

	# === STEP 1: MapGrid (ADR-0004) ===
	# load_map() returns bool — warnings logged per IN-6 + IN-7.
	_map_grid = MapGrid.new()
	_map_grid.name = "MapGrid"
	var map_ok: bool = _map_grid.load_map(mock_map_resource)
	if not map_ok:
		push_warning("BattleScene: MapGrid.load_map() returned false — check map_resource validation")
		for err: String in _map_grid.get_last_load_errors():
			push_warning("BattleScene: MapGrid error: %s" % err)
	add_child(_map_grid)

	# === STEP 2: BattleCamera (ADR-0013) — depends on MapGrid ===
	_battle_camera = BattleCamera.new()
	_battle_camera.name = "BattleCamera"
	_battle_camera.setup(_map_grid)
	add_child(_battle_camera)

	# === STEP 3: HPStatusController (ADR-0010) — depends on roster ===
	# initialize_unit(unit_id, hero, unit_class) per shipped ADR-0010 API.
	# IN-8 drift: no UnitRole.get_class_for_hero(); use unit.unit_class directly.
	_hp_controller = HPStatusController.new()
	_hp_controller.name = "HPStatusController"
	for unit: BattleUnit in mock_roster:
		var hero: HeroData = HeroDatabase.get_hero(unit.hero_id)
		_hp_controller.initialize_unit(unit.unit_id, hero, unit.unit_class)
	add_child(_hp_controller)

	# === STEP 4: TurnOrderRunner (ADR-0011) — depends on roster ===
	_turn_runner = TurnOrderRunner.new()
	_turn_runner.name = "TurnOrderRunner"
	_turn_runner.initialize_battle(mock_roster)
	add_child(_turn_runner)

	# === STEP 5: GridBattleController (ADR-0014) — depends on all 4 prior ===
	_grid_controller = GridBattleController.new()
	_grid_controller.name = "GridBattleController"
	_grid_controller.setup(
		mock_roster,
		_map_grid,
		_battle_camera,
		_hero_db,
		_turn_runner,
		_hp_controller,
		_terrain_effect,
		_unit_role,
	)
	add_child(_grid_controller)

	# === STEP 6: BattleHUD (ADR-0015) — depends on all 5 prior ===
	_battle_hud = BattleHUD.new()
	_battle_hud.name = "BattleHUD"
	_battle_hud.setup(
		_battle_camera,
		_hp_controller,
		_turn_runner,
		_grid_controller,
		_input_router,
		_map_grid,
		_terrain_effect,
		_unit_role,
		_hero_db,
	)
	_hud_layer.add_child(_battle_hud)


# ─── Sprint-6 mock encounter helpers ─────────────────────────────────────────
# === SPRINT-6 MOCK ENCOUNTER HELPERS ===
# TODO: REMOVE WHEN ADR-0017 SCENARIO PROGRESSION LANDS
# These methods exist solely to ship the +1 playable-surface delta in sprint-6
# without blocking on Scenario Progression ADR. Delete the entire region
# between SPRINT-6 MOCK ENCOUNTER markers in _ready() + this entire region.


## Builds the 4-unit sprint-6 mock roster: 2 player (장비 tank + 조운 assassin)
## + 2 enemy. Per ADR-0016 §4. BattleUnit field names verified against
## src/core/battle_unit.gd 2026-05-04 (is_player_controlled, position per B-1).
func _build_mock_roster_sprint6() -> Array[BattleUnit]:
	var roster: Array[BattleUnit] = []
	roster.append(_make_mock_unit(0, &"jangbi",  true,  Vector2i(1, 2), &"tank"))
	roster.append(_make_mock_unit(1, &"joun",    true,  Vector2i(2, 2), &"assassin"))
	roster.append(_make_mock_unit(2, &"enemy_a", false, Vector2i(4, 2), &"boss"))
	roster.append(_make_mock_unit(3, &"enemy_b", false, Vector2i(5, 2), &""))
	return roster


## Constructs a single BattleUnit for the sprint-6 mock encounter.
func _make_mock_unit(
		unit_id: int,
		hero_id: StringName,
		is_player: bool,
		pos: Vector2i,
		tag: StringName,
) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.hero_id = hero_id
	unit.is_player_controlled = is_player
	unit.side = 0 if is_player else 1
	unit.position = pos
	unit.tag = tag
	unit.move_range = 3
	unit.attack_range = 1
	unit.raw_atk = 10
	unit.raw_def = 5
	return unit


## Builds a WxH all-grass MapResource for the sprint-6 mock encounter.
## Per IN-9: MapResource.tiles is Array[MapTileData]; each tile needs coord +
## is_passable_base=true. Uses terrain_type=0 (grass/plains) as the default.
func _build_mock_map_resource_sprint6(width: int, height: int) -> MapResource:
	var map: MapResource = MapResource.new()
	map.map_cols = width
	map.map_rows = height
	map.tiles = _make_uniform_grass_tiles(width, height)
	return map


## Returns a flat row-major Array[MapTileData] with all tiles passable grass.
## coord.x = col index, coord.y = row index per MapGrid row-major convention.
func _make_uniform_grass_tiles(w: int, h: int) -> Array[MapTileData]:
	var tiles: Array[MapTileData] = []
	for row: int in range(h):
		for col: int in range(w):
			var tile: MapTileData = MapTileData.new()
			tile.coord = Vector2i(col, row)
			tile.terrain_type = 0
			tile.is_passable_base = true
			tile.occupant_id = 0
			tile.occupant_faction = 0
			tiles.append(tile)
	return tiles

# === END SPRINT-6 MOCK ENCOUNTER HELPERS ===
