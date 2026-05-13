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
var _chapter_visuals: Node = null
## Single TurnIndicator instance, reparented under the active unit's polygon
## on each grid_controller.active_unit_changed emit. Lazy-init on first emit
## so we don't allocate before ChapterVisuals' unit polygons are spawned.
var _turn_indicator: TurnIndicator = null

## Slide tween reference held to prevent local-scope GC from dropping the
## completion callback under certain windowed scheduler timings. Overwritten
## on every move; the previous Tween auto-cleans if already finished.
var _slide_tween_keepalive: Tween = null

## Set true when battle_outcome_resolved fires. Gates the post-battle restart
## keyboard handler (R = reload scene, ESC = quit).
var _battle_resolved: bool = false


## Movement-tween duration on unit_moved. Short enough to feel responsive
## (player still perceives the action as instant) but long enough that the
## slide reads as "moved to here" rather than a teleport jump.
const MOVE_ANIM_DURATION: float = 0.6

## Attack-lunge tuning. On damage_applied, the attacker polygon nudges
## LUNGE_DISTANCE px toward the defender over LUNGE_HALF_DURATION seconds,
## then returns to origin over another LUNGE_HALF_DURATION seconds. Total
## ~0.15s feels snappy without competing with the defender's red-flash +
## HP-bar refresh that run in parallel.
const LUNGE_DISTANCE: float = 12.0
const LUNGE_HALF_DURATION: float = 0.075

## Death-fade duration. Polygon's modulate:a tweens to 0 then visible is set
## false. Long enough to read as "this unit just died" rather than a cut,
## short enough to keep combat pacing tight.
const DEATH_FADE_DURATION: float = 0.3

## On battle_outcome_resolved, ChapterVisuals modulate tweens to this color
## over OUTCOME_DIM_DURATION seconds so the grid recedes and the outcome
## banner pops. Slight blue cast (B 0.50 > R/G 0.45) reads as "scene cooling
## down" rather than just gray.
const OUTCOME_DIM_COLOR: Color = Color(0.45, 0.45, 0.50, 1.0)
const OUTCOME_DIM_DURATION: float = 0.4

## End-of-turn polygon dim. A unit's polygon modulate fades to this alpha when
## the unit finishes its turn having spent at least one token (acted=true);
## reset back to WHITE when the next round starts. Reads as "this unit is
## done for the round" alongside the chevron on the active unit.
const END_OF_TURN_DIM_ALPHA: float = 0.55
const END_OF_TURN_DIM_DURATION: float = 0.15


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
	# InputRouter needs Camera + MapGrid refs to resolve mouse pixel → grid coord →
	# unit_id at click time. Without these, _make_context_from_event leaves
	# ctx.target_unit_id = -1 and _handle_action_in_s0 silently drops every
	# unit_select click (POLISH-011 production-wiring residual #2).
	# Wired here AFTER _battle_camera + _map_grid are created (see STEPs 1 + 2 below).

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

	# === STEP 1.1: Populate MapGrid occupants from roster deployment positions.
	# Without this, every InputRouter click resolves to unit_id = -1 because
	# MapGrid.get_unit_at(coord) returns -1 for tiles whose tile_state is still EMPTY
	# (POLISH-011 production-wiring residual #3).
	for unit: BattleUnit in roster:
		var faction: int = MapGrid.FACTION_ALLY if unit.side == 0 else MapGrid.FACTION_ENEMY
		_map_grid.set_occupant(unit.position, unit.unit_id, faction)

	# === STEP 1.5 REMOVED: SceneManager._instantiate_and_enter_battle already
	# mounts res://scenes/battle/<map_id>.tscn at /root via the
	# battle_launch_requested signal path (ADR-0002 §_instantiate_and_enter_battle).
	# Mounting it again here under GridLayer was producing a dual-mount: the
	# visible instance was SceneManager's at /root, but BattleScene wired its own
	# (invisible) GridLayer instance, so selection-highlight overlays never reached
	# the rendered scene. Selection now resolves the live instance via /root lookup
	# in _on_unit_selected_changed.

	# === STEP 2: BattleCamera (ADR-0013) — depends on MapGrid ===
	_battle_camera = BattleCamera.new()
	_battle_camera.name = "BattleCamera"
	_battle_camera.setup(_map_grid)
	add_child(_battle_camera)
	# Windowed-play camera: keep zoom at 1.0 (matches balance constant + tests)
	# and shift the camera UP by 60 world px so the HUD ribbon at the top of
	# the viewport overlays empty space above the map rather than the top
	# row of tiles (where 장료 sits in chapter 1). 60 is enough to clear the
	# typical HUD ribbon while not leaving an obvious empty band at top.
	_battle_camera.position.y -= 60.0

	# === STEP 2.5: InputRouter DI for screen→grid coord + grid→unit_id resolution.
	# Without these, every mouse click resolves to ctx.target_unit_id = -1 and
	# unit_select silently drops in InputRouter._handle_action_in_s0
	# (POLISH-011 production-wiring residual #2).
	_input_router.set_camera(_battle_camera)
	_input_router.set_map_grid(_map_grid)

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
	# S15-J: wire NATURAL-LOOP mode per ADR-0011 §Amendment 2026-05-09 + ADR-0014 §Amendment 2026-05-10 (#1+#2+#3).
	# Without this call, T5 _execute_action_budget falls through TEST-SEAM no-op pass; production
	# battle loop runs to ROUND_CAP_DRAW in ~2-3 seconds without natural input/AI dispatch.
	_turn_runner.set_action_controller(_grid_controller._on_turn_runner_action_request)
	add_child(_grid_controller)

	# Wire unit-selection signal to chapter visuals selection-highlight overlay.
	# Instance lookup is dynamic (in handler) because SceneManager mounts the
	# chapter visuals AFTER battle_launch_requested fires (post-_ready boundary).
	_grid_controller.unit_selected_changed.connect(_on_unit_selected_changed)
	_grid_controller.unit_moved.connect(_on_unit_moved)
	_grid_controller.damage_applied.connect(_on_damage_applied)
	_grid_controller.unit_visual_died.connect(_on_unit_died_visual)
	_grid_controller.active_unit_changed.connect(_on_active_unit_changed)
	_grid_controller.unit_turn_ended_visual.connect(_on_unit_turn_ended_visual)
	_grid_controller.round_started_visual.connect(_on_round_started_visual)
	_grid_controller.battle_outcome_resolved.connect(_on_battle_outcome_resolved)

	# === STEP 5.5: AISystem (ADR-0019) — battle-scoped Node 6th invocation ===
	# Inserted via /architecture-review delta #14 2026-05-05 per ADR-0016 §3 R-3
	# Path A (preserves existing 1-6 numbering; full 1-7 renumber deferred).
	# Subscribes to GridBattleController.ai_action_requested with CONNECT_DEFERRED.
	_ai_system = AISystem.new()
	_ai_system.name = "AISystem"
	_ai_system.setup(_grid_controller)
	add_child(_ai_system)
	# Wire reverse direction: GridBattleController subscribes to AISystem.ai_action_ready
	# so AI commands actually execute. Without this, ai_action_ready emits into the void
	# and AI turns hang forever (POLISH-013 production-wiring residual).
	_grid_controller.set_ai_system(_ai_system)

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
	# Victory condition surfaces at battle init — without this UI-GB-08 stays
	# visible=false and the top-right ribbon slot is empty.
	_battle_hud.set_victory_condition(&"적 부대 전멸")

	# ChapterVisuals is mounted at /root by SceneManager AFTER BattleScene._ready
	# returns (async load + deferred instantiate per ADR-0002). Spawn runtime
	# unit polygons once the visuals node appears — this replaces .tscn-baked
	# polygons with roster-driven ones so deployment branch overrides (e.g.
	# WIN_changbanpo_default placing 유비 at [2,3]) actually render.
	_spawn_unit_polygons_async(roster)


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
	# Stats from HeroData — stat_might drives raw_atk so commanders like 유비
	# vs heavies like 장비 (might 92) feel different in combat. Tuning for
	# MVP "kills resolve within 5 rounds":
	#   Max HP per UnitRole formula = hp_seed * class_hp_mult * 2.0 + 50
	#     → infantry hp_seed 95 → 297 max_hp (very tanky)
	#   raw_atk = stat_might × 1.5 (장비 92 → 138) so 2-3 hits land a kill
	#     after the DamageCalc multiplier chain trims to ~80-110 effective
	#   raw_def = stat_command × 0.05 (small reduction so damage swings high)
	# Falls back to 10/5 if HeroData lookup fails (defensive only).
	var hero_data: HeroData = HeroDatabase.get_hero(hero_id)
	if hero_data != null:
		unit.raw_atk = int(hero_data.stat_might * 1.5)
		unit.raw_def = int(hero_data.stat_command * 0.05)
	else:
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


## Selection-highlight handler. Looks up the SceneManager-mounted ChapterVisuals
## instance at /root (by class) at call-time, since the mount happens after
## BattleScene._ready returns (via battle_launch_requested → SceneManager).
func _on_unit_selected_changed(unit_id: int, _was_selected: int) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	if unit_id == -1:
		visuals.set_selected_coord(Vector2i(-1, -1))
		visuals.set_movable_tiles(PackedVector2Array())
		visuals.set_attackable_tiles(PackedVector2Array())
		return
	var unit: BattleUnit = _grid_controller.get_battle_unit(unit_id)
	if unit == null:
		visuals.set_selected_coord(Vector2i(-1, -1))
		visuals.set_movable_tiles(PackedVector2Array())
		visuals.set_attackable_tiles(PackedVector2Array())
		return
	visuals.set_selected_coord(unit.position)
	visuals.set_movable_tiles(_grid_controller.get_movable_tiles(unit_id))
	visuals.set_attackable_tiles(_grid_controller.get_attackable_tiles(unit_id))


func _find_chapter_visuals() -> Node:
	for child: Node in get_tree().root.get_children():
		if child is ChapterVisuals:
			return child
	return null


## Polls /root for ChapterVisuals across up to ~0.5s (30 frames @ 60fps) and
## calls spawn_unit_polygons(roster) once it appears. Required because the
## chapter visuals scene is async-loaded by SceneManager and mounts after
## BattleScene._ready returns. Fire-and-forget coroutine from _ready.
func _spawn_unit_polygons_async(roster: Array[BattleUnit]) -> void:
	# Was 30 (~0.5s @ 60fps) — too tight for cold boots on Apple Silicon where
	# SceneManager's async .tscn load + instantiation can exceed 0.5s. 300 frames
	# (~5s) gives generous headroom without indefinite wait.
	for attempt: int in 300:
		var visuals: Node = _find_chapter_visuals()
		if visuals != null and visuals.has_method("spawn_unit_polygons"):
			visuals.spawn_unit_polygons(roster)
			_mount_hp_bars(visuals, roster)
			return
		await get_tree().process_frame
	var root_names: Array = []
	for c: Node in get_tree().root.get_children():
		root_names.append(c.name)
	push_warning("BattleScene: ChapterVisuals not mounted within 300 frames; "
		+ "root children: " + str(root_names))


## Attaches a UnitHpBar Node2D child to each spawned unit polygon, seeded from
## HPStatusController. Polygon transform inheritance gives free repositioning on
## move; CanvasItem visibility cascade gives free hide-on-death. Per-unit refresh
## happens in _on_damage_applied.
func _mount_hp_bars(visuals: Node, roster: Array[BattleUnit]) -> void:
	if _hp_controller == null:
		return
	for unit: BattleUnit in roster:
		var polygon: Node2D = _find_unit_polygon(visuals, unit.unit_id)
		if polygon == null:
			continue
		var bar: UnitHpBar = UnitHpBar.new()
		bar.name = "HpBar"
		polygon.add_child(bar)
		bar.set_hp(
			_hp_controller.get_current_hp(unit.unit_id),
			_hp_controller.get_max_hp(unit.unit_id),
		)


## Unit-moved handler. Re-positions the unit's Polygon2D inside the chapter
## visuals (.tscn-authored as `Unit{unit_id}_*` under PlayerUnits/EnemyUnits)
## and updates the selection highlight if the moved unit is the current
## selection. Without this, BattleUnit.position mutates but the on-screen
## silhouette stays at its authored deployment coord.
func _on_unit_moved(unit_id: int, _from: Vector2i, to: Vector2i) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		print("[SLIDE] unit=%d visuals=NULL — slide skipped" % unit_id)
		return
	var tile_size: int = ChapterVisuals.TILE_SIZE
	var world_pos: Vector2 = Vector2(
		to.x * tile_size + tile_size / 2.0,
		to.y * tile_size + tile_size / 2.0,
	)
	var unit_node: Node2D = _find_unit_polygon(visuals, unit_id)
	if unit_node == null:
		print("[SLIDE] unit=%d polygon=NULL (children: %s) — slide skipped" %
			[unit_id, _list_polygon_names(visuals)])
		return
	print("[SLIDE] unit=%d from=%s to=%s (polygon now at %s, target %s)" %
		[unit_id, str(_from), str(to), str(unit_node.position), str(world_pos)])
	# DIAGNOSTIC: Tween was firing in headless but callback/finished never fired
	# in user's windowed env (verified across 5+ retries). Bypassing tween
	# entirely — set polygon.position INSTANTLY. If the user now sees the
	# polygon teleport to the new tile, the rendering pipeline is fine and
	# Tween was the problem. If still no visual change, rendering is broken.
	unit_node.position = world_pos
	print("[SLIDE-DONE] unit=%d polygon.position now %s (expected %s)" %
		[unit_id, str(unit_node.position), str(world_pos)])
	# Rotation tween: catch directional polygons (CAVALRY/ARCHER/SCOUT) up to
	# the post-move facing. Non-directional classes return 0 from
	# rotation_for_facing, so the tween is a no-op for them.
	if _grid_controller == null:
		return  # test mode without controller — slide handles position; rotation/active skipped
	var unit: BattleUnit = _grid_controller.get_battle_unit(unit_id)
	if unit != null:
		var target_rotation: float = (visuals as ChapterVisuals) \
			.rotation_for_facing(unit.facing, unit.unit_class)
		var rot_tween: Tween = create_tween().set_parallel(true)
		rot_tween.tween_property(unit_node, "rotation", target_rotation, MOVE_ANIM_DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# Counter-rotate the name label so it stays upright through the slide.
		var label_node: Node = unit_node.get_node_or_null("NameLabel")
		if label_node is Label:
			rot_tween.tween_property(label_node, "rotation", -target_rotation, MOVE_ANIM_DURATION) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# Counter-rotate the chevron if it's parented to this unit.
		if is_instance_valid(_turn_indicator) and _turn_indicator.get_parent() == unit_node:
			rot_tween.tween_property(_turn_indicator, "rotation", -target_rotation, MOVE_ANIM_DURATION) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Active-turn highlight follows the moving unit so the gold border sits on
	# the new tile by the time the slide finishes.
	if _grid_controller.get_selected_unit_id() == unit_id:
		visuals.set_selected_coord(to)
	if visuals.has_method("set_active_turn_coord"):
		var active_id: int = _grid_controller.get_active_turn_unit_id() \
			if _grid_controller.has_method("get_active_turn_unit_id") else -1
		if active_id == unit_id:
			visuals.set_active_turn_coord(to)
	# Unit just consumed its move action; clear the move preview so stale
	# "can move here" tiles don't linger. If the unit is still selected,
	# recompute attack reach from its new position so the player sees what
	# they can now hit; otherwise clear attack preview too.
	visuals.set_movable_tiles(PackedVector2Array())
	if _grid_controller.get_selected_unit_id() == unit_id:
		visuals.set_attackable_tiles(_grid_controller.get_attackable_tiles(unit_id))
	else:
		visuals.set_attackable_tiles(PackedVector2Array())


## Damage feedback: brief red flash on the defender's polygon so the player
## perceives "the attack landed" even when the defender survives. Without this,
## damage_applied is HUD-only and the grid view shows no change after attack.
func _on_damage_applied(attacker_id: int, defender_id: int, damage: int) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	var unit_node: Node2D = _find_unit_polygon(visuals, defender_id)
	if unit_node == null:
		return
	# Camera shake on every confirmed hit. Gated by the visuals check above so
	# tests without ChapterVisuals don't perturb camera offset.
	if _battle_camera != null and damage > 0:
		_battle_camera.shake()
	var original_modulate: Color = unit_node.modulate
	unit_node.modulate = Color(2.0, 0.4, 0.4, 1.0)  # bright red flash
	# Failsafe: ensure the defender goes back to its non-flash color even if
	# the Tween writes don't advance. Use a timer rather than tween_callback
	# (which also can drop in the same windowed scenarios).
	get_tree().create_timer(0.25).timeout.connect(func() -> void:
		if is_instance_valid(unit_node):
			unit_node.modulate = original_modulate)
	# Refresh the defender's HP bar to reflect the new HP. HPStatusController
	# applied the damage synchronously before damage_applied was emitted (grid
	# controller line ~1233-1236), so get_current_hp returns the post-hit value.
	var bar: Node = unit_node.get_node_or_null("HpBar")
	if bar is UnitHpBar and _hp_controller != null:
		(bar as UnitHpBar).set_hp(
			_hp_controller.get_current_hp(defender_id),
			_hp_controller.get_max_hp(defender_id),
		)
	# Floating damage number. Parented to ChapterVisuals (NOT the polygon) so
	# the popup persists if the hit kills the defender — _on_unit_died_visual
	# hides the polygon and its children, but the popup needs to remain visible
	# for the player to read what just happened.
	if damage > 0:
		var popup: DamagePopup = DamagePopup.make(damage)
		popup.position = unit_node.position + Vector2(0.0, -36.0)
		visuals.add_child(popup)
	# Attack lunge: nudge attacker toward defender then return. Sells the
	# swing without requiring per-class attack animations. Adjacent attackers
	# get the full distance; ranged attackers (황충 attack_range=2) get the
	# same px distance projected along the line — reads as "leans into the shot".
	var attacker_node: Node2D = _find_unit_polygon(visuals, attacker_id)
	if attacker_node != null:
		var origin: Vector2 = attacker_node.position
		var to_defender: Vector2 = unit_node.position - origin
		if to_defender.length_squared() > 0.0:
			var lunge_target: Vector2 = origin + to_defender.normalized() * LUNGE_DISTANCE
			var lunge_tween: Tween = create_tween()
			lunge_tween.tween_property(attacker_node, "position", lunge_target, LUNGE_HALF_DURATION) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			lunge_tween.tween_property(attacker_node, "position", origin, LUNGE_HALF_DURATION) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# Attack line from attacker to defender. Parented to ChapterVisuals so
		# the line persists if the hit kills the defender or the attacker is
		# repositioned mid-animation.
		var line: AttackLine = AttackLine.make(origin, unit_node.position)
		visuals.add_child(line)


## Death feedback: fade the dead unit's polygon to transparent over
## DEATH_FADE_DURATION, then hide it. Without this, the killed unit either
## stays on screen (no handler) or vanishes instantly (snap-hide), both of
## which read worse than a brief fade.
##
## Tween ordering note: the flash tween from _on_damage_applied is created
## first (same-frame deferred chain damage_applied → unit_died → handler),
## so the fade tween's modulate:a writes overlay on top of the flash's full
## modulate writes per frame — the unit fades to transparent while the red
## flash recedes. Final visible=false guards via is_instance_valid in case
## the polygon is freed mid-tween (scene transition).
func _on_unit_died_visual(unit_id: int) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	var unit_node: Node2D = _find_unit_polygon(visuals, unit_id)
	if unit_node == null:
		return
	# Failsafe pattern (windowed Tween-writes can stall): set the final state
	# via a SceneTreeTimer that fires unconditionally regardless of tween
	# scheduler behaviour.
	get_tree().create_timer(DEATH_FADE_DURATION + 0.05).timeout.connect(func() -> void:
		if is_instance_valid(unit_node):
			unit_node.modulate.a = 0.0
			unit_node.visible = false)


## Battle-outcome handler. Dims the grid (so the banner pops) and spawns the
## screen-centered OutcomeBanner on HUDLayer. The HUD's UI-GB-09 results
## panel still renders in parallel via its own subscription — this banner is
## the grid-level moment cue, not a replacement for the stats sheet.
func _on_battle_outcome_resolved(outcome: StringName, _fate_data: Dictionary) -> void:
	print("[BATTLE-END] outcome=%s — showing banner + dimming grid (R=restart, ESC=quit)" % outcome)
	_battle_resolved = true
	var visuals: Node = _find_chapter_visuals()
	if visuals is CanvasItem:
		# Instant-set the final dim color so the visual change is guaranteed
		# even if Tween writes don't advance (observed in user windowed env).
		(visuals as CanvasItem).modulate = OUTCOME_DIM_COLOR
	if _hud_layer != null:
		var banner: OutcomeBanner = OutcomeBanner.make(outcome)
		banner.name = "OutcomeBanner"
		_hud_layer.add_child(banner)
		# Restart prompt — small Label under the main outcome glyph so the
		# player knows they can re-enter without relaunching Godot.
		var prompt: Label = Label.new()
		prompt.text = "R / SPACE: 재시작   ESC: 종료"
		prompt.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90, 1.0))
		prompt.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.05, 1.0))
		prompt.add_theme_constant_override("outline_size", 4)
		prompt.add_theme_font_size_override("font_size", 22)
		prompt.set_anchors_preset(Control.PRESET_CENTER)
		prompt.position = Vector2(-90, 60)  # below the outcome glyph
		prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hud_layer.add_child(prompt)


## After battle ends, listen for restart / quit keys. _battle_resolved gates
## these so they don't trigger mid-battle. The reload_current_scene path
## rebuilds the whole battle from scratch — fastest way to "play again"
## without a Main Menu / Overworld surface (those are post-MVP).
## Post-battle restart hotkeys. We poll Input directly in _process because
## `_input` and `_unhandled_input` both compete with InputRouter (autoload)
## which has ESC bound to move_cancel and consumes events before we see them.
## Polling sidesteps the dispatcher entirely. Trade-off: we check every frame
## while battle is resolved — cheap (one Input.is_key_pressed per frame).
var _process_tick: int = 0

func _process(_delta: float) -> void:
	if not _battle_resolved:
		return
	_process_tick += 1
	if _process_tick % 60 == 1:
		# Once per second while waiting for restart input — confirms _process
		# is firing and shows what key state we're observing.
		print("[POST-BATTLE-WAIT] _process firing; R=%s ESC=%s SPACE=%s ENTER=%s" %
			[Input.is_physical_key_pressed(KEY_R),
			Input.is_physical_key_pressed(KEY_ESCAPE),
			Input.is_physical_key_pressed(KEY_SPACE),
			Input.is_physical_key_pressed(KEY_ENTER)])
	# Try both physical and logical key checks (macOS sometimes maps one but
	# not the other depending on keyboard layout / IME state).
	if Input.is_physical_key_pressed(KEY_R) or Input.is_key_pressed(KEY_R):
		print("[BATTLE-END] R pressed — reloading scene")
		_battle_resolved = false  # prevent re-trigger before scene reload completes
		get_tree().reload_current_scene()
	elif Input.is_physical_key_pressed(KEY_ESCAPE) or Input.is_key_pressed(KEY_ESCAPE):
		print("[BATTLE-END] ESC pressed — quitting")
		_battle_resolved = false
		get_tree().quit()
	elif Input.is_physical_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SPACE):
		# Bonus: SPACE also restarts (in case R doesn't register on macOS Korean IME).
		print("[BATTLE-END] SPACE pressed — reloading scene")
		_battle_resolved = false
		get_tree().reload_current_scene()


## Turn-indicator handler. Lazy-creates the indicator on first call and
## reparents it under the active unit's polygon on every subsequent emit.
## ChapterVisuals may not be mounted yet on the first emit (async load) — in
## that case the call is a graceful no-op; the next emit will land it.
func _on_active_unit_changed(unit_id: int) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	# Tile-level active-turn highlight — bright gold border so the active unit
	# is visible even at zoomed-out scales where the chevron is too small to spot.
	var unit: BattleUnit = _grid_controller.get_battle_unit(unit_id)
	if unit != null and visuals.has_method("set_active_turn_coord"):
		visuals.set_active_turn_coord(unit.position)
	var polygon: Node2D = _find_unit_polygon(visuals, unit_id)
	if polygon == null:
		return
	if not is_instance_valid(_turn_indicator):
		_turn_indicator = TurnIndicator.new()
		_turn_indicator.name = "TurnIndicator"
	if _turn_indicator.get_parent() == polygon:
		return
	if _turn_indicator.get_parent() != null:
		_turn_indicator.get_parent().remove_child(_turn_indicator)
	polygon.add_child(_turn_indicator)
	# Counter the polygon's facing rotation so the chevron always points down
	# regardless of which direction the unit is facing.
	_turn_indicator.rotation = -polygon.rotation


## End-of-turn dim cue. Fired by GridBattleController as a re-emit of
## GameBus.unit_turn_ended. Skips passes (acted=false) so units that just
## advance without action keep full brightness, and skips dead units whose
## death-fade tween owns modulate.a — running this on a corpse would lift
## alpha back up mid-fade.
func _on_unit_turn_ended_visual(unit_id: int, acted: bool) -> void:
	if not acted:
		return
	if _hp_controller != null and not _hp_controller.is_alive(unit_id):
		return
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	var polygon: Node2D = _find_unit_polygon(visuals, unit_id)
	if polygon == null:
		return
	var target: Color = Color(1.0, 1.0, 1.0, END_OF_TURN_DIM_ALPHA)
	# Instant-set so the dim shows even when Tween writes don't advance.
	polygon.modulate = target


## Round-rollover undim. Iterates every spawned unit polygon under PlayerUnits
## and EnemyUnits and tweens modulate back to WHITE. Skips invisible polygons
## (dead units snap-hidden by _on_unit_died_visual) so a corpse doesn't get
## its alpha briefly lifted before staying invisible.
func _on_round_started_visual(_round_num: int) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	for parent_name: String in ["PlayerUnits", "EnemyUnits"]:
		var parent: Node = visuals.get_node_or_null(parent_name)
		if parent == null:
			continue
		for child: Node in parent.get_children():
			if not (child is Node2D):
				continue
			var poly: Node2D = child as Node2D
			if not poly.visible:
				continue
			# Instant-set so units brighten back to full alpha at round start
			# even if Tween writes don't advance.
			poly.modulate = Color.WHITE


func _list_polygon_names(visuals: Node) -> String:
	var names: Array = []
	for parent_name: String in ["PlayerUnits", "EnemyUnits"]:
		var parent: Node = visuals.get_node_or_null(parent_name)
		if parent == null:
			continue
		for child: Node in parent.get_children():
			names.append("%s/%s" % [parent_name, child.name])
	return str(names)


func _find_unit_polygon(visuals: Node, unit_id: int) -> Node2D:
	var prefix: String = "Unit%d_" % unit_id
	for parent_name: String in ["PlayerUnits", "EnemyUnits"]:
		var parent: Node = visuals.get_node_or_null(parent_name)
		if parent == null:
			continue
		for child: Node in parent.get_children():
			if (child.name as String).begins_with(prefix) and child is Node2D:
				return child as Node2D
	return null


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
