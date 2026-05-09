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
## IN-10 (sprint-7 S7-02 ScenarioRunner integration 2026-05-05): mock encoder
##   block + 4 helpers DELETED. BattlePayload + ChapterDefinition now sourced
##   from ScenarioRunner.get_active_battle_config() / get_current_chapter() per
##   ADR-0017 §BattleConfig + ADR-0016 Migration Plan §1. IN-6/7/8/9 drift
##   notes preserved for traceability to grid_battle_controller / unit-role /
##   map-grid contracts. In standalone-launch mode (no SceneManager), BattleScene
##   bootstraps mvp_shu.json scenario itself for sprint-7 +1 playable-surface delta.

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
## inspection and future test seam compatibility. _input_router post-S8-02
## (input-handling story-001) is typed `Node` because InputRouter graduated to
## autoload and dropped `class_name` per G-3 — see input_router.gd header.
var _hero_db: HeroDatabase
var _balance_constants: BalanceConstants
var _terrain_effect: TerrainEffect
var _unit_role: UnitRole
var _input_router: Node


# ─── Battle-scoped child Node references ─────────────────────────────────────

var _map_grid: MapGrid
var _battle_camera: BattleCamera
var _hp_controller: HPStatusController
var _turn_runner: TurnOrderRunner
var _grid_controller: GridBattleController
var _ai_system: AISystem
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
	# .new() works. InputRouter graduated to autoload at S8-02 (input-handling
	# story-001 2026-05-06) — reference via /root/InputRouter directly per
	# ADR-0005 §1 + ADR-0020 §Decision §6 (boot pos 9). Closes prior TD-058
	# placeholder + supersedes the "sprint-7+ autoload graduation" pointer.
	_hero_db = (load("res://src/foundation/hero_database.gd") as GDScript).new()
	_unit_role = (load("res://src/foundation/unit_role.gd") as GDScript).new()
	_balance_constants = BalanceConstants.new()
	_terrain_effect = TerrainEffect.new()
	_input_router = get_node("/root/InputRouter")

	# === SPRINT-7 SCENARIO BOOTSTRAP (mock encoder DELETED 2026-05-05 per IN-10) ===
	# Standalone-launch mode: bootstrap mvp_shu.json directly. SceneManager-driven
	# mode (post-Main-Menu): ScenarioRunner is already in BEAT_4_PREP/BATTLE_LOADING.
	if ScenarioRunner.get_current_chapter_index() == -1:
		var loaded: bool = ScenarioRunner.load_scenario("res://assets/data/scenarios/mvp_shu.json")
		if not loaded:
			push_error("BattleScene: failed to load mvp_shu.json scenario")
		# Drive scenario forward to BEAT_5_BATTLE for standalone demo (no UI dwell).
		if ScenarioRunner.get_state() == ScenarioRunner.State.BEAT_1_ANCHOR:
			ScenarioRunner.advance_beat()  # -> BEAT_2_ECHO
			ScenarioRunner.advance_beat()  # -> BEAT_3_BRIEF
			ScenarioRunner.advance_beat()  # -> BEAT_4_PREP
			ScenarioRunner.confirm_deployment()  # -> BATTLE_LOADING -> BEAT_5_BATTLE
	var chapter: ChapterDefinition = ScenarioRunner.get_current_chapter()
	if chapter == null:
		push_error("BattleScene: no active chapter from ScenarioRunner")
		return
	var roster: Array[BattleUnit] = _build_battle_units_from_chapter(chapter)
	var map_resource: MapResource = _build_map_resource_for_chapter(chapter)

	# === STEP 1: MapGrid (ADR-0004) ===
	# load_map() returns bool — warnings logged per IN-6 + IN-7.
	_map_grid = MapGrid.new()
	_map_grid.name = "MapGrid"
	var map_ok: bool = _map_grid.load_map(map_resource)
	if not map_ok:
		push_warning("BattleScene: MapGrid.load_map() returned false — check map_resource validation")
		for err: String in _map_grid.get_last_load_errors():
			push_warning("BattleScene: MapGrid error: %s" % err)
	add_child(_map_grid)

	# === STEP 1.5: ChapterVisualScene (ADR-0021 §1 + §6) ===
	# Mount the chapter-scope authored .tscn under GridLayer so world-space
	# visuals render. Missing .tscn is a HIGH-tier warning (POLISH-010-class)
	# but not an error — headless logic continuity preserved via the
	# _build_map_resource_for_chapter() fallback above.
	var chapter_scene_path: String = "res://scenes/battle/%s.tscn" % chapter.map_id
	if ResourceLoader.exists(chapter_scene_path):
		var chapter_scene: PackedScene = load(chapter_scene_path) as PackedScene
		if chapter_scene != null:
			var chapter_visuals: Node = chapter_scene.instantiate()
			_grid_layer.add_child(chapter_visuals)
		else:
			push_warning("ADR-0021: failed to load chapter visual scene at '%s'" % chapter_scene_path)
	else:
		push_warning(("ADR-0021: chapter visual scene missing at '%s'; "
			+ "running with blank world-space (headless logic intact, "
			+ "windowed mode will render void). POLISH-010-class issue.")
			% chapter_scene_path)

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
	for unit: BattleUnit in roster:
		var hero: HeroData = HeroDatabase.get_hero(unit.hero_id)
		_hp_controller.initialize_unit(unit.unit_id, hero, unit.unit_class)
	add_child(_hp_controller)

	# === STEP 4: TurnOrderRunner (ADR-0011) — depends on roster ===
	_turn_runner = TurnOrderRunner.new()
	_turn_runner.name = "TurnOrderRunner"
	_turn_runner.initialize_battle(roster)
	add_child(_turn_runner)

	# === STEP 5: GridBattleController (ADR-0014) — depends on all 4 prior ===
	_grid_controller = GridBattleController.new()
	_grid_controller.name = "GridBattleController"
	_grid_controller.setup(
		roster,
		_map_grid,
		_battle_camera,
		_hero_db,
		_turn_runner,
		_hp_controller,
		_terrain_effect,
		_unit_role,
	)
	# S7-05: plumb chapter-authored chokepoints to AISystem holder-archetype scoring.
	_grid_controller.set_chokepoints(chapter.chokepoints)
	add_child(_grid_controller)

	# === STEP 5.5: AISystem (ADR-0019) — battle-scoped Node 6th invocation ===
	# Inserted via /architecture-review delta #14 2026-05-05 per ADR-0016 §3 R-3
	# Path A (preserves existing 1-6 numbering; full 1-7 renumber deferred).
	# Subscribes to GridBattleController.ai_action_requested with CONNECT_DEFERRED.
	_ai_system = AISystem.new()
	_ai_system.name = "AISystem"
	_ai_system.setup(_grid_controller)
	add_child(_ai_system)

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


# ─── Chapter-driven helpers (sprint-7 S7-02 — replaces deleted mock encoder) ──


## Builds Array[BattleUnit] from ChapterDefinition.player_unit_ids + enemy_roster.
## Player units use chapter.player_unit_ids + chapter.deployment_positions_default.
## Enemy units use chapter.enemy_roster (Dictionary entries with unit_id/hero_id/archetype).
## Hero IDs MUST exist in assets/data/heroes/heroes.json.
func _build_battle_units_from_chapter(chapter: ChapterDefinition) -> Array[BattleUnit]:
	var roster: Array[BattleUnit] = []
	# Player units — bind chapter player_unit_ids to chapter-1 narrative-fitting heroes.
	# S7-05: chapter-1 (장판파) defenders are 유비 + 장비 (Liu Bei rear-guarding refugees;
	# Zhang Fei's bridge stand). Hero-binding remains hardcoded here pending a
	# data-driven player_hero_ids ChapterDefinition field (post-MVP scope).
	var player_default_heroes: Array[StringName] = [&"shu_001_liu_bei", &"shu_003_zhang_fei"]
	for i in chapter.player_unit_ids.size():
		var uid: int = int(chapter.player_unit_ids[i])
		var hero: StringName = player_default_heroes[i] if i < player_default_heroes.size() else &"shu_003_zhang_fei"
		var pos: Vector2i = chapter.deployment_positions_default.get(uid, Vector2i(1 + i, 2)) as Vector2i
		var tag: StringName = &"tank" if i == 0 else &"assassin"
		# Player units default to &"aggressor" archetype (S13-12); chapter fixtures
		# do not currently author player_unit archetypes — extend ChapterDefinition
		# if AI-driven player units are introduced post-MVP.
		roster.append(_make_battle_unit(uid, hero, true, pos, tag, &"aggressor"))
	# Enemy units from chapter.enemy_roster Dictionary entries.
	for entry in chapter.enemy_roster:
		var d: Dictionary = entry as Dictionary
		var uid: int = int(d.get("unit_id", 0))
		var hero: StringName = StringName(d.get("hero_id", "wei_001_cao_cao") as String)
		var archetype: StringName = StringName(d.get("archetype", "aggressor") as String)
		# Position fallback: spread enemies across columns 4+ at row 2.
		var pos: Vector2i = chapter.deployment_positions_default.get(uid, Vector2i(4 + roster.size(), 2)) as Vector2i
		# tag carries the fate-counter role (coordinator → "boss" for fate tracking
		# per ADR-0014 §2 fate counter pattern). archetype is preserved separately
		# on the BattleUnit for AISystem dispatch (S13-12 separation).
		var tag: StringName = &"boss" if archetype == &"coordinator" else archetype
		roster.append(_make_battle_unit(uid, hero, false, pos, tag, archetype))
	return roster


## Constructs a single BattleUnit. Replaces the deleted _make_mock_unit helper.
## archetype param (S13-12) carries the AI behaviour bucket — distinct from `tag`
## which carries the fate-counter role. See BattleUnit.archetype docstring for the
## separation rationale (BUG #2: prior conflation leaked tag="boss" into AISystem
## dispatch as unknown archetype, triggering EC-AI-4 fallback warning).
func _make_battle_unit(
		unit_id: int,
		hero_id: StringName,
		is_player: bool,
		pos: Vector2i,
		tag: StringName,
		archetype: StringName,
) -> BattleUnit:
	var unit: BattleUnit = BattleUnit.new()
	unit.unit_id = unit_id
	unit.hero_id = hero_id
	unit.is_player_controlled = is_player
	unit.side = 0 if is_player else 1
	unit.position = pos
	unit.tag = tag
	unit.archetype = archetype
	unit.move_range = 3
	unit.attack_range = 1
	unit.raw_atk = 10
	unit.raw_def = 5
	return unit


## Builds a 15×15 all-grass MapResource for the chapter. Sprint-7 S7-05 will
## load chapter-1 (장판파) authored .tres at assets/data/maps/{map_id}.tres;
## current stub fixture provides uniform grass per IN-9 + ADR-0016 IN-9.
func _build_map_resource_for_chapter(_chapter: ChapterDefinition) -> MapResource:
	var map: MapResource = MapResource.new()
	map.map_cols = 15
	map.map_rows = 15
	map.tiles = _make_uniform_grass_tiles(15, 15)
	return map


## Returns a flat row-major Array[MapTileData] with all tiles passable grass.
## Preserved from sprint-6 mock helpers; sprint-7+ chapter map loading will
## replace this with assets/data/maps/{map_id}.tres asset loading.
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
