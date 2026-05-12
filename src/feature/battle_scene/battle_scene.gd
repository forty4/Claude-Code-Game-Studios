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

## Movement-tween duration on unit_moved. Short enough to feel responsive
## (player still perceives the action as instant) but long enough that the
## slide reads as "moved to here" rather than a teleport jump.
const MOVE_ANIM_DURATION: float = 0.2

## Attack-lunge tuning. On damage_applied, the attacker polygon nudges
## LUNGE_DISTANCE px toward the defender over LUNGE_HALF_DURATION seconds,
## then returns to origin over another LUNGE_HALF_DURATION seconds. Total
## ~0.15s feels snappy without competing with the defender's red-flash +
## HP-bar refresh that run in parallel.
const LUNGE_DISTANCE: float = 12.0
const LUNGE_HALF_DURATION: float = 0.075


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
	for _attempt: int in 30:
		var visuals: Node = _find_chapter_visuals()
		if visuals != null and visuals.has_method("spawn_unit_polygons"):
			visuals.spawn_unit_polygons(roster)
			_mount_hp_bars(visuals, roster)
			return
		await get_tree().process_frame
	push_warning("BattleScene: ChapterVisuals not mounted within 30 frames; "
		+ "runtime unit polygons not spawned")


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
		return
	var tile_size: int = ChapterVisuals.TILE_SIZE
	var world_pos: Vector2 = Vector2(
		to.x * tile_size + tile_size / 2.0,
		to.y * tile_size + tile_size / 2.0,
	)
	var unit_node: Node2D = _find_unit_polygon(visuals, unit_id)
	if unit_node != null:
		var tween: Tween = create_tween().set_parallel(true)
		tween.tween_property(unit_node, "position", world_pos, MOVE_ANIM_DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# Rotation tween: catch directional polygons (CAVALRY/ARCHER/SCOUT) up to
		# the post-move facing. Non-directional classes return 0 from
		# rotation_for_facing, so the tween is a no-op for them.
		var unit: BattleUnit = _grid_controller.get_battle_unit(unit_id)
		if unit != null:
			var target_rotation: float = (visuals as ChapterVisuals) \
				.rotation_for_facing(unit.facing, unit.unit_class)
			tween.tween_property(unit_node, "rotation", target_rotation, MOVE_ANIM_DURATION) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _grid_controller.get_selected_unit_id() == unit_id:
		visuals.set_selected_coord(to)
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
	var original_modulate: Color = unit_node.modulate
	unit_node.modulate = Color(2.0, 0.4, 0.4, 1.0)  # bright red flash
	var tween: Tween = create_tween()
	tween.tween_property(unit_node, "modulate", original_modulate, 0.25)
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


## Death feedback: hide the dead unit's polygon. Without this, the killed unit
## stays on screen at its last position, making the kill invisible to the player.
func _on_unit_died_visual(unit_id: int) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	var unit_node: Node2D = _find_unit_polygon(visuals, unit_id)
	if unit_node == null:
		return
	unit_node.visible = false


## Turn-indicator handler. Lazy-creates the indicator on first call and
## reparents it under the active unit's polygon on every subsequent emit.
## ChapterVisuals may not be mounted yet on the first emit (async load) — in
## that case the call is a graceful no-op; the next emit will land it.
func _on_active_unit_changed(unit_id: int) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
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
