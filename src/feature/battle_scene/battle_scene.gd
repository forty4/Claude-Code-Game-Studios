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
## Bridges the controller's LOCAL battle_outcome_resolved → GameBus.battle_outcome_resolved
## (which ScenarioRunner + SceneManager consume) — see battle_outcome_bridge.gd for why
## this hop needs a dedicated child rather than being done on the scene root.
var _outcome_bridge: BattleOutcomeBridge = null
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


## Diagnostic-trace gate. Sessions 4-5 used inline raw `print(...)` calls (SLIDE
## / SLIDE-DONE / BATTLE-END / POST-BATTLE-WAIT categories) to debug windowed-env
## quirks (Tween scheduler, keyboard poll, scene reload paths). The user confirmed
## the windowed env now mostly works, so they're routed through `_trace()` and
## silenced by default. Flip this constant to `true` (then re-import) to surface
## the full event-stream again.
const _TRACE_ENABLED: bool = false


func _trace(msg: String) -> void:
	if _TRACE_ENABLED:
		print(msg)


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

## Camera top-padding (pixels). The HUD ribbon (initiative queue / round counter
## / victory condition) sits in screen-space along the top edge; the camera's
## `offset.y` is shifted negative by this much so the rendered world slides DOWN
## by the same amount, leaving an empty band at top for the ribbon to overlay
## without covering any map tiles. Using `offset` (not `position`) keeps the
## camera's clamp-to-map limits behaving normally regardless of viewport size —
## the prior `position.y -= 60` hack worked at 1920×1080 but degraded on smaller
## windows because the limits would clamp the shifted position back. ~80 px
## matches the BattleHUD top-ribbon footprint with a few px of breathing room.
const HUD_TOP_RIBBON_PAD_PX: float = 80.0

## Per-chapter title-card flavor. Keyed by ChapterDefinition.chapter_id. Shown
## briefly at battle start so the fight has narrative framing. Fallback (unknown
## id) uses the chapter number alone. Placeholder copy — the eventual string
## table (assets/locale/*.po, beat_*_text_key) supersedes this when authored.
const CHAPTER_FLAVOR: Dictionary = {
	"ch01_changbanpo": {
		"title": "제1장 · 장판파 (長坂坡)",
		"tagline": "유비, 피난민을 등지고 조조의 추격을 막아내라.",
	},
	"ch02_changban_bridge": {
		"title": "제2장 · 장판교 (長坂橋)",
		"tagline": "장비, 다리 하나로 적의 전군을 멈춰 세워라.",
	},
	"ch03_xiakou_outskirts": {
		"title": "제3장 · 강하 외곽 · 적벽의 서막",
		"tagline": "관우 합류 — 강을 건너기까지 마지막 후위를 막아내라.",
	},
}
## How long the title card stays on screen before auto-removing (seconds).
const TITLE_CARD_DURATION: float = 3.5

## Player unit_id → hero_id. Stable across chapters (see _build_battle_units_from_chapter).
## Hero IDs MUST exist in assets/data/heroes/heroes.json. Placeholder until a
## data-driven player_hero_ids ChapterDefinition field lands (post-MVP scope).
const PLAYER_HERO_BY_UNIT_ID: Dictionary = {
	0: &"shu_001_liu_bei",   # 유비 — ch1 commander / rear-guard
	1: &"shu_003_zhang_fei", # 장비 — ch1 vanguard, ch2 bridge-holder
}


# ─── Built-in virtual methods ─────────────────────────────────────────────────

## _ready() — scenario bootstrap, then either present the chapter's pre-battle
## story (windowed only) and start the battle when the player dismisses it, or
## start the battle immediately (headless, or a retry-reload where the pre-battle
## beats were already shown). The story-presentation branch is fire-and-forget;
## battle setup runs in _start_battle() either way.
##
## Idempotent under all 3 launch sources per R-8:
##   (a) SceneManager-driven (ADR-0002 deferred packed-scene instantiation)
##   (b) project.godot main_scene config
##   (c) godot --main-scene CLI override
func _ready() -> void:
	if not _bootstrap_scenario_if_needed():
		return
	# Present the pre-battle story (Beat 1 anchor + Beat 3 brief) only in windowed
	# runs, and only when the scenario is fresh at the chapter's first beat (a
	# retry-reload lands at BEAT_4_PREP with the beats already seen → skip).
	if _should_present_story() \
			and ScenarioRunner.get_state() == ScenarioRunner.State.BEAT_1_ANCHOR:
		_present_pre_battle_story_then_start()
	else:
		_start_battle()


## Mounts a StoryBeatScreen with the chapter's pre-battle beats, waits for the
## player to advance past them, then starts the battle. Fire-and-forget coroutine
## from _ready() — battle systems are not created until this returns.
func _present_pre_battle_story_then_start() -> void:
	var chapter: ChapterDefinition = ScenarioRunner.get_current_chapter()
	if chapter != null:
		var beats: Array = _collect_pre_battle_beats(chapter)
		if not beats.is_empty():
			await _present_story_beats(beats)
	_start_battle()


## _start_battle() — 6-step mount sequence per ADR-0016 §3.
##
## Walks ScenarioRunner forward to BEAT_5_BATTLE (a no-op when already there),
## then: instantiate system → call setup() / initialize() → add_child() for each
## of the 6 battle-scoped children. The setup-before-add_child ordering is
## MANDATORY for all 5 system ADRs (ADR-0010/0011/0013/0014/0015 R-N).
func _start_battle() -> void:
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

	# === SCENARIO ADVANCE ===
	# Drive ScenarioRunner to BEAT_5_BATTLE for whatever chapter it's currently
	# on (the scenario was already loaded in _bootstrap_scenario_if_needed; this
	# walks the pre-battle beats). A reload after a chapter transition
	# (_proceed_scenario / _retry_chapter / _restart_scenario) finds ScenarioRunner
	# already at that chapter's pre-battle beats and walks them. SceneManager-driven
	# mode (post-Main-Menu, post-MVP): ScenarioRunner is already in BEAT_5_BATTLE; no-op.
	_advance_scenario_to_battle()
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
	# and shift the rendered world DOWN via Camera2D.offset so the HUD ribbon at
	# the top edge overlays empty space above the map rather than the top row
	# of tiles. Using `offset` (NOT `position`) so the camera's clamp-to-map
	# limits keep working at every viewport size — see HUD_TOP_RIBBON_PAD_PX.
	_battle_camera.offset.y = -HUD_TOP_RIBBON_PAD_PX

	# === STEP 2.5: InputRouter DI for screen→grid coord + grid→unit_id resolution.
	# Without these, every mouse click resolves to ctx.target_unit_id = -1 and
	# unit_select silently drops in InputRouter._handle_action_in_s0
	# (POLISH-011 production-wiring residual #2).
	_input_router.set_camera(_battle_camera)
	_input_router.set_map_grid(_map_grid)

	# === STEP 3: HPStatusController (ADR-0010) — depends on roster + MapGrid ===
	# initialize_unit(unit_id, hero, unit_class) per shipped ADR-0010 API.
	# IN-8 drift: no UnitRole.get_class_for_hero(); use unit.unit_class directly.
	# set_map_grid plumbs the MapGrid reference used by the CR-8c commander-death
	# DEMORALIZED-radius propagation (asserts non-null at use site). Missing this
	# wire-up was a session-8 user-reported crash on 유비 death.
	_hp_controller = HPStatusController.new()
	_hp_controller.name = "HPStatusController"
	_hp_controller.set_map_grid(_map_grid)
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
	# Session-13: defend stance badge — toggle on when applied, off on round
	# rollover (next round = fresh turn = stance consumed).
	_grid_controller.unit_defend_stance_applied.connect(_on_unit_defend_stance_applied)
	# Session-16: hero skill SFX cue. One sound covers all 6 skills for v1;
	# per-skill variants are a future iteration.
	if _grid_controller.has_signal(&"unit_skill_used"):
		_grid_controller.unit_skill_used.connect(_on_unit_skill_used)
	# Session-16: critical-hit (REAR-direction) visual feedback. Spawns the
	# "치명타!" popup + triggers camera shake + plays SFX_CRITICAL so the player
	# feels the flank payoff immediately rather than just seeing a bigger
	# damage number on the standard popup.
	if _grid_controller.has_signal(&"critical_hit_landed"):
		_grid_controller.critical_hit_landed.connect(_on_critical_hit_landed)
	# Session-16: mid-battle kill notification. Spawns "X 처치!" popup at victim
	# position + plays SFX_KILL flourish — defers the "did I get the kill?"
	# confirmation moment so the player doesn't have to wait until the result
	# screen to feel it.
	if _grid_controller.has_signal(&"unit_killed"):
		_grid_controller.unit_killed.connect(_on_unit_killed_mid_battle)

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

	# === STEP 5.6: BattleOutcomeBridge — battle-scoped GameBus publisher ===
	# Without this, GridBattleController's LOCAL battle_outcome_resolved never
	# reaches GameBus, so ScenarioRunner stays in BEAT_5_BATTLE forever and the
	# scenario never advances past chapter 1 (R-7 forbids the scene root from
	# emitting; ADR-0014 §8 forbids the controller from emitting on GameBus).
	_outcome_bridge = BattleOutcomeBridge.new()
	_outcome_bridge.name = "BattleOutcomeBridge"
	_outcome_bridge.setup(chapter.chapter_id)
	add_child(_outcome_bridge)
	_grid_controller.battle_outcome_resolved.connect(_outcome_bridge.on_local_outcome)

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
	# Persistent controls hint at the bottom edge — a first-time player has no
	# way to discover the click flow otherwise. Static label; no _process needed
	# (which matters: _pause_overworld() disables _process on this scene, see
	# _on_battle_outcome_resolved). Lives in HUDLayer (CanvasLayer) so it stays
	# visible regardless of the Node2D-parent visibility cascade.
	_mount_controls_hint()
	# Brief title card so the battle has narrative framing. Auto-removes via a
	# SceneTreeTimer (fires regardless of process_mode — unlike _process).
	_mount_title_card(chapter, roster)

	# ChapterVisuals is mounted at /root by SceneManager AFTER BattleScene._ready
	# returns (async load + deferred instantiate per ADR-0002). Spawn runtime
	# unit polygons once the visuals node appears — this replaces .tscn-baked
	# polygons with roster-driven ones so deployment branch overrides (e.g.
	# WIN_changbanpo_default placing 유비 at [2,3]) actually render.
	_spawn_unit_polygons_async(roster)

	# Session-12: kick off the battle ambient music. Silent no-op when the
	# player has muted music (set_music_enabled false → cached slug only).
	# Stops via _exit_tree when the scene unmounts (chapter transition / main).
	SoundManager.play_music(SoundManager.MUSIC_BATTLE_AMBIENT)


## _exit_tree — stops battle music when the scene tears down. Without this
## the music would continue across the brief gap before the next BattleScene
## mounts (or the main menu shows). Safe no-op when nothing is playing.
func _exit_tree() -> void:
	if SoundManager.has_method("stop_music"):
		SoundManager.stop_music()


# ─── Scenario driving (standalone-launch only) ───────────────────────────────

## Walks ScenarioRunner forward to BEAT_5_BATTLE for the chapter it's currently on.
##
## - First launch ever (also after _restart_scenario): no scenario loaded
##   (index == -1) → load mvp_shu.json (→ CHAPTER_START → BEAT_1_ANCHOR), then walk.
##   (load_scenario in _restart_scenario re-loads, so index is briefly -1-equivalent —
##    actually load_scenario resets directly to CHAPTER_START; covered below.)
## - Reload after a chapter transition: _proceed_scenario already advanced
##   ScenarioRunner to the next chapter's BEAT_1_ANCHOR → just walk the beats.
## - Reload after _retry_chapter: ScenarioRunner is in BEAT_4_PREP → confirm.
## - Already in BEAT_5_BATTLE (SceneManager-driven mode / test fixture): no-op.
## - Any other (stale post-battle) state: leave it; get_current_chapter() handles null.
##
## This only DRIVES the beat state machine — the pre-battle beat *presentation*
## (Beat 1 anchor + Beat 3 brief) happens beforehand in
## _present_pre_battle_story_then_start() (windowed only); a retry-reload or a
## headless run walks the beats here without any UI dwell.
func _advance_scenario_to_battle() -> void:
	if ScenarioRunner.get_current_chapter_index() == -1:
		if not ScenarioRunner.load_scenario("res://assets/data/scenarios/mvp_shu.json"):
			push_error("BattleScene: failed to load mvp_shu.json scenario")
			return
	# Bounded walk — 8 iterations is far more than the longest pre-battle path
	# (CHAPTER_START is auto-advanced inside ScenarioRunner; we only ever see
	# BEAT_1 → BEAT_2 → BEAT_3 → BEAT_4 → confirm).
	for _i: int in 8:
		match ScenarioRunner.get_state():
			ScenarioRunner.State.BEAT_1_ANCHOR, \
			ScenarioRunner.State.BEAT_2_ECHO, \
			ScenarioRunner.State.BEAT_3_BRIEF:
				ScenarioRunner.advance_beat()
			ScenarioRunner.State.BEAT_4_PREP:
				ScenarioRunner.confirm_deployment()  # -> BATTLE_LOADING -> BEAT_5_BATTLE
				return
			_:
				return  # BEAT_5_BATTLE (already in battle) or a stale state (leave it)


# ─── Story beat presentation (windowed; headless skips it) ───────────────────

## Story beat narrative content, keyed by beat_*_text_key (mirrors the keys in
## assets/data/scenarios/mvp_shu.json). Loaded once and cached; {} if the file
## is missing or malformed (in which case no story screen is shown — the battle
## still plays). See assets/data/story/story_content.json.
var _story_content_cache: Dictionary = {}
var _story_content_loaded: bool = false


## Ensures a scenario is loaded so get_current_chapter() works. The very first
## launch (and a "처음부터" restart) finds no scenario (index == -1) and loads
## mvp_shu.json (→ CHAPTER_START → BEAT_1_ANCHOR). Returns false on load failure.
func _bootstrap_scenario_if_needed() -> bool:
	if ScenarioRunner.get_current_chapter_index() == -1:
		if not ScenarioRunner.load_scenario("res://assets/data/scenarios/mvp_shu.json"):
			push_error("BattleScene: failed to load mvp_shu.json scenario")
			return false
	return true


## True only in windowed runs. Headless runs (CI, GdUnit4, the natural-turn-loop
## smoke) must NOT mount the StoryBeatScreen — it waits forever for player input.
func _should_present_story() -> bool:
	return DisplayServer.get_name() != "headless"


func _load_story_content() -> Dictionary:
	if _story_content_loaded:
		return _story_content_cache
	_story_content_loaded = true
	var path: String = "res://assets/data/story/story_content.json"
	var raw: String = FileAccess.get_file_as_string(path)
	if raw.is_empty():
		push_warning("BattleScene: story content file missing or empty: %s" % path)
		return _story_content_cache
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		push_warning("BattleScene: story content failed to parse as JSON object: %s" % path)
		return _story_content_cache
	_story_content_cache = parsed as Dictionary
	return _story_content_cache


## Resolves a beat text key to its { title, body, speaker?, line? } content
## Dictionary, or {} if the key is empty / unknown / has no usable prose.
func _beat_content(text_key: String) -> Dictionary:
	if text_key.is_empty():
		return {}
	var entry: Variant = _load_story_content().get(text_key, null)
	if not (entry is Dictionary):
		return {}
	var d: Dictionary = entry as Dictionary
	var has_body: bool = not (d.get("body", "") as String).strip_edges().is_empty()
	var has_line: bool = not (d.get("line", "") as String).strip_edges().is_empty()
	if not (has_body or has_line):
		return {}
	return d


## Pre-battle beats for `chapter`: Beat 1 anchor + Beat 3 brief (Beat 2 is a
## silent_visual fragment with no text — skipped). Filters out keys with no content.
func _collect_pre_battle_beats(chapter: ChapterDefinition) -> Array:
	var beats: Array = []
	var b1: Dictionary = _beat_content(chapter.beat_1_text_key)
	if not b1.is_empty():
		beats.append(b1)
	var b3: Dictionary = _beat_content(chapter.beat_3_text_key)
	if not b3.is_empty():
		beats.append(b3)
	return beats


## Post-battle beats for the just-finished `chapter`: the Beat 8 revelation for
## the resolved branch (or an outcome-based fallback if `branch_choice` is null /
## invalid), then the Beat 9 chapter transition. Filters out keys with no content.
func _collect_post_battle_beats(chapter: ChapterDefinition, branch_choice: DestinyBranchChoice) -> Array:
	var beats: Array = []
	var branch_key: String = ""
	if branch_choice != null and not branch_choice.is_invalid:
		branch_key = branch_choice.branch_key
	if branch_key.is_empty():
		branch_key = _guess_branch_key_for_outcome(chapter)
	var b8: Dictionary = _beat_content(_beat_8_text_key_for_branch(chapter, branch_key))
	if not b8.is_empty():
		beats.append(b8)
	var b9: Dictionary = _beat_content(chapter.beat_9_text_key)
	if not b9.is_empty():
		beats.append(b9)
	return beats


func _beat_8_text_key_for_branch(chapter: ChapterDefinition, branch_key: String) -> String:
	for entry: Dictionary in chapter.beat_8_revelations:
		if (entry.get("branch_key", "") as String) == branch_key:
			return entry.get("text_key", "") as String
	return ""


## Best-effort branch_key when the resolved DestinyBranchChoice is unavailable:
## WIN → the chapter's canonical branch; DRAW / LOSS → its LOSS_default branch.
func _guess_branch_key_for_outcome(chapter: ChapterDefinition) -> String:
	if _pending_outcome == BattleOutcome.Result.WIN:
		return chapter.canonical_branch_key
	return chapter.branch_table.get("LOSS_default", "") as String


## Mounts a StoryBeatScreen on the HUD layer, presents `beats`, and awaits the
## player advancing past the last one; frees the screen before returning. No-op
## (returns immediately) if there is nothing to show or the HUD layer is absent.
func _present_story_beats(beats: Array) -> void:
	if beats.is_empty() or _hud_layer == null:
		return
	var screen: StoryBeatScreen = StoryBeatScreen.new()
	screen.name = "StoryBeatScreen"
	_hud_layer.add_child(screen)
	screen.present(beats)
	await screen.sequence_finished
	if is_instance_valid(screen):
		screen.queue_free()


## Removes the post-battle banner / button / controls-hint nodes from the HUD
## layer (used before showing the post-battle story so it isn't layered over them).
func _clear_post_battle_ui() -> void:
	if _hud_layer == null:
		return
	for nm: String in ["OutcomeBanner", "PostBattleButtons", "ControlsHint"]:
		var n: Node = _hud_layer.get_node_or_null(nm)
		if n != null:
			n.queue_free()


# ─── Chapter-driven helpers (sprint-7 S7-02 — replaces deleted mock encoder) ──


## Builds Array[BattleUnit] from ChapterDefinition.player_unit_ids + enemy_roster.
## Player units use chapter.player_unit_ids + chapter.deployment_positions_default.
## Enemy units use chapter.enemy_roster (Dictionary entries with unit_id/hero_id/archetype).
## Hero IDs MUST exist in assets/data/heroes/heroes.json.
func _build_battle_units_from_chapter(chapter: ChapterDefinition) -> Array[BattleUnit]:
	var roster: Array[BattleUnit] = []
	# Player units — bind player unit_ids to narrative-fitting heroes via a 3-tier
	# fallback chain: (1) chapter.player_hero_ids (data-driven, scales to any uid
	# in any chapter — preferred); (2) PLAYER_HERO_BY_UNIT_ID const (covers uids
	# 0/1 = 유비/장비 from the legacy hardcoded mapping); (3) 장비 (a sensible
	# default front-liner for unknown uids — keeps the battle bootable even when
	# new chapters forget to author the mapping).
	for i in chapter.player_unit_ids.size():
		var uid: int = int(chapter.player_unit_ids[i])
		var hero: StringName = _resolve_player_hero_id(chapter, uid)
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


## Resolves the hero_id for a player unit_id via the 3-tier fallback chain
## documented in _build_battle_units_from_chapter. Public-shaped (no underscore-
## prefixed args) so tests can drive it directly without poking the full builder.
func _resolve_player_hero_id(chapter: ChapterDefinition, uid: int) -> StringName:
	if chapter != null and chapter.player_hero_ids.has(uid):
		var hid: String = chapter.player_hero_ids[uid] as String
		if not hid.is_empty():
			return StringName(hid)
	if PLAYER_HERO_BY_UNIT_ID.has(uid):
		return PLAYER_HERO_BY_UNIT_ID[uid] as StringName
	return &"shu_003_zhang_fei"


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
	# Stats from HeroData. RE-TUNED at session 8 after the "유비 dies in 1
	# round" playtest: the original coefficients (might×1.5, command×0.05)
	# pushed every attack through BASE_CEILING=83 because eff_atk ≫ eff_def,
	# so raw_def was dead-code and 유비 fell to any 2 adjacent enemies.
	#   New target: "kill in 4-5 hits" (was the documented "2-3 hits" but
	#   with 4 enemies converging on a player the practical reality was 1
	#   round to a commander wipe). Math (적 하후돈 → 유비, FRONT, plains):
	#     eff_atk = 88 (was 132)        raw_atk  = might × 1.0
	#     eff_def = 28 (was 4)          raw_def  = command × 0.20 + 10 if COMMANDER
	#     base    = 88 − 28 = 60 (under ceiling — raw_def now matters)
	#     final  ≈ 40–55 after multiplier chain
	#     유비 226 HP / 50 ≈ 4–5 hits to drop, with command_aura buffing his
	#     adjacent retaliation. Cleaner difficulty curve at all 3 chapters.
	#   COMMANDER +10 raw_def bonus is the survivability hook that justifies
	#   "the commander is the formation anchor" — losing 유비 is supposed to
	#   be hard, not a 1-round race the AI always wins.
	# Max HP per UnitRole formula (unchanged): hp_seed × class_hp_mult × 2.0 + 50.
	# Fallback values (10 atk / 5 def) are only hit when HeroData is missing —
	# defensive against unknown hero_ids; never used by the live scenario.
	var hero_data: HeroData = HeroDatabase.get_hero(hero_id)
	if hero_data != null:
		# Coefficients data-driven via BalanceConstants — single source of truth
		# for atk/def derivation. Tune in balance_entities.json (HERO_ATK_COEFF /
		# HERO_DEF_COEFF / HERO_COMMANDER_DEF_BONUS) rather than touching code.
		var atk_coeff: float = BalanceConstants.get_const("HERO_ATK_COEFF") as float
		var def_coeff: float = BalanceConstants.get_const("HERO_DEF_COEFF") as float
		unit.raw_atk = int(hero_data.stat_might * atk_coeff)
		unit.raw_def = int(hero_data.stat_command * def_coeff)
		# Class from the hero's default — without this every unit defaulted to 0
		# (CAVALRY) and rendered as a triangle, hiding both the per-class shape
		# and the per-class HP/multiplier behavior. Fallback to INFANTRY (1) when
		# the hero is unknown — closest to "grunt" semantics.
		unit.unit_class = hero_data.default_class
		# COMMANDER survivability bonus — formation anchor: losing 유비 should be
		# hard, not a 1-round race. Applied AFTER unit_class assignment so the
		# conditional reads the resolved class.
		if unit.unit_class == UnitRole.UnitClass.COMMANDER:
			var cmd_bonus: int = BalanceConstants.get_const("HERO_COMMANDER_DEF_BONUS") as int
			unit.raw_def += cmd_bonus
	else:
		unit.raw_atk = 10
		unit.raw_def = 5
		unit.unit_class = UnitRole.UnitClass.INFANTRY
	# Enemy-side ATK penalty — MVP has only 3 player heroes (유비/장비/관우)
	# vs 5 enemy heroes spread across 3 chapters, which makes the player a
	# permanent minority. Without an enemy ATK throttle, even after the
	# session-8 atk/def retune ch1 is unwinnable: 4 enemies converge on
	# 유비 in ~3 turns and out-DPS the player's 2-unit retaliation budget.
	#   Resolution chain: chapter.enemy_atk_mult (per-chapter override) →
	#   BalanceConstants.ENEMY_ATK_MULT (global default). Per-chapter wins
	#   when set to a value in [0.0, 2.0]; -1.0 sentinel or out-of-range
	#   falls back to global. This lets ch1 / ch2 / ch3 carry their own
	#   difficulty curves without forcing the team to retune all chapters
	#   when one needs adjustment.
	if not is_player:
		unit.raw_atk = int(unit.raw_atk * _resolve_enemy_atk_mult())
	# Class-derived combat traits — ORDER-SENSITIVE: must follow unit_class assignment.
	# attack_range gives ARCHER 우금 actual reach (1→2). passive activates the
	# command_aura adjacency damage buff (+15% to allies adjacent to a COMMANDER)
	# that GridBattleController._has_adjacent_command_aura already implements but
	# never fired before because no unit ever had passive set. The AI hunt for
	# command_aura targets stays inactive — snapshot's `passive_id` is still
	# hardcoded to &"" (intentional asymmetry: player gets formation buff,
	# enemy AI doesn't gain a "kill the king" priority on top of it).
	unit.attack_range = _attack_range_for_class(unit.unit_class)
	unit.passive = _passive_for_class(unit.unit_class)
	# move_range derived from hero base + class delta clamped to balance range —
	# replaces a 3-everyone hardcode. Heroes.json gives 우금 (archer) 3, 장료
	# (strategist) 5 (-1 delta → 4), 관우 (cavalry) 4 (+1 delta → 5), most others 4.
	# Player now feels real class differentiation in deployment + skirmish range.
	if hero_data != null:
		unit.move_range = UnitRole.get_effective_move_range(hero_data, unit.unit_class)
	else:
		unit.move_range = 3
	# Session-15 commit 5: active skill from heroes.json innate_skill_ids[0].
	# Player-side only — enemy AI doesn't have a skill-trigger path yet, so
	# wiring the skill_id on enemies would create silently dead-stored data.
	# The controller's use_skill() refuses non-player units regardless.
	if is_player and hero_data != null and not hero_data.innate_skill_ids.is_empty():
		unit.skill_id = hero_data.innate_skill_ids[0]
	return unit


## Resolves the effective enemy_atk_mult for the current battle. Per-chapter
## override wins over BalanceConstants global; sentinel -1.0 or out-of-range
## values fall back to global. Out-of-range emits push_warning (defensive
## against JSON typos that would otherwise silently break difficulty tuning).
##   Called once per enemy unit at _make_battle_unit. Cheap (autoload getter
##   + single comparison), so no need to memoize across the build loop.
func _resolve_enemy_atk_mult() -> float:
	var global_mul: float = BalanceConstants.get_const("ENEMY_ATK_MULT") as float
	var chapter: ChapterDefinition = ScenarioRunner.get_current_chapter()
	if chapter == null:
		return global_mul
	var override: float = chapter.enemy_atk_mult
	if override < 0.0:
		return global_mul
	if override > 2.0:
		push_warning(
			"BattleScene._resolve_enemy_atk_mult: chapter '%s' enemy_atk_mult=%.3f"
			% [chapter.chapter_id, override]
			+ " is out of [0.0, 2.0] range; falling back to global %.3f" % global_mul
		)
		return global_mul
	return override


## Class → melee/ranged reach mapping. ARCHER stands off (range 2); everyone
## else is melee (range 1). 황충's `rear_specialist` ranged exception is a
## per-hero passive override authored elsewhere when that hero ships.
func _attack_range_for_class(unit_class: int) -> int:
	if unit_class == int(UnitRole.UnitClass.ARCHER):
		return 2
	return 1


## Class → default passive mapping. COMMANDER carries `command_aura` so the
## adjacent-ally damage buff (GridBattleController._has_adjacent_command_aura)
## actually fires. CAVALRY carries `passive_charge` (session-13) so the +20%
## CHARGE_BONUS in DamageCalc._charge_factor fires when the cavalry unit
## moved >= CHARGE_THRESHOLD (40 path-cost = 4 flat tiles) before attacking.
## SCOUT carries `passive_ambush` (session-14) so the +15% AMBUSH_BONUS in
## DamageCalc._ambush_factor fires when attacking a not-yet-acted target
## from round 2 onwards (target also loses counter — see GridBattleController
## _preview_counter_eligible). ARCHER carries `passive_high_ground_shot`
## (session-15) so the +15% HIGH_GROUND_BONUS in DamageCalc._high_ground_factor
## fires whenever the archer attacks while standing on HILLS terrain.
## INFANTRY's `passive_shield_wall` is consumed directly by HPStatusController
## via UnitRole.PASSIVE_TAG_BY_CLASS lookup, not through this runtime field.
## STRATEGIST `tactical_read` + COMMANDER `passive_rally` remain advisory
## tags not consumed by the damage pipeline yet.
func _passive_for_class(unit_class: int) -> StringName:
	if unit_class == int(UnitRole.UnitClass.COMMANDER):
		return &"command_aura"
	if unit_class == int(UnitRole.UnitClass.CAVALRY):
		return &"passive_charge"
	if unit_class == int(UnitRole.UnitClass.SCOUT):
		return &"passive_ambush"
	if unit_class == int(UnitRole.UnitClass.ARCHER):
		return &"passive_high_ground_shot"
	return &""


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
		_clear_verb_feedback_overlays(visuals)
		return
	var unit: BattleUnit = _grid_controller.get_battle_unit(unit_id)
	if unit == null:
		visuals.set_selected_coord(Vector2i(-1, -1))
		visuals.set_movable_tiles(PackedVector2Array())
		visuals.set_attackable_tiles(PackedVector2Array())
		_clear_verb_feedback_overlays(visuals)
		return
	visuals.set_selected_coord(unit.position)
	visuals.set_movable_tiles(_grid_controller.get_movable_tiles(unit_id))
	visuals.set_attackable_tiles(_grid_controller.get_attackable_tiles(unit_id))
	_apply_verb_feedback_overlays(visuals, unit_id, unit.position)


## Session-15: pushes AMBUSH / CHARGE / HIGH GROUND feedback overlays for the
## given unit. Ambush set = subset of attackable tiles where SCOUT + round >= 2
## + defender unacted; charge coord = the unit's own tile when CAVALRY +
## passive_charge + accumulated_move >= CHARGE_THRESHOLD; high-ground coord =
## the unit's own tile when ARCHER + passive_high_ground_shot + standing on
## HILLS terrain. Class mutex guarantees charge and high-ground never both
## fire for the same unit, so they appear as one halo color per selection.
func _apply_verb_feedback_overlays(visuals: Node, unit_id: int, position: Vector2i) -> void:
	if visuals.has_method("set_ambush_target_tiles"):
		visuals.set_ambush_target_tiles(
			_grid_controller.get_ambush_eligible_target_tiles(unit_id))
	if visuals.has_method("set_charge_ready_coord"):
		var charge_coord: Vector2i = position if _grid_controller.is_charge_ready(unit_id) \
			else Vector2i(-1, -1)
		visuals.set_charge_ready_coord(charge_coord)
	if visuals.has_method("set_high_ground_ready_coord"):
		var hg_coord: Vector2i = position if _grid_controller.is_high_ground_ready(unit_id) \
			else Vector2i(-1, -1)
		visuals.set_high_ground_ready_coord(hg_coord)


## Session-15: clears AMBUSH / CHARGE / HIGH GROUND feedback overlays.
## Called on deselect and stale-selection branches so the indigo wash, cyan
## halo, and green halo don't linger past the selection they belonged to.
func _clear_verb_feedback_overlays(visuals: Node) -> void:
	if visuals.has_method("set_ambush_target_tiles"):
		visuals.set_ambush_target_tiles(PackedVector2Array())
	if visuals.has_method("set_charge_ready_coord"):
		visuals.set_charge_ready_coord(Vector2i(-1, -1))
	if visuals.has_method("set_high_ground_ready_coord"):
		visuals.set_high_ground_ready_coord(Vector2i(-1, -1))


func _find_chapter_visuals() -> Node:
	for child: Node in get_tree().root.get_children():
		# Skip a previous chapter's ChapterVisuals that SceneManager has queued
		# for deletion but the tree hasn't reaped yet (chapter-transition window).
		if child is ChapterVisuals and not child.is_queued_for_deletion():
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
			# A prior battle (before reload_current_scene) may have left the
			# /root ChapterVisuals dimmed via OUTCOME_DIM_COLOR — it survives
			# the scene reload because SceneManager mounted it at /root, not
			# under current_scene. Reset to full brightness on every battle start.
			if visuals is CanvasItem:
				(visuals as CanvasItem).modulate = Color.WHITE
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
		_trace("[SLIDE] unit=%d visuals=NULL — slide skipped" % unit_id)
		return
	var tile_size: int = ChapterVisuals.TILE_SIZE
	var world_pos: Vector2 = Vector2(
		to.x * tile_size + tile_size / 2.0,
		to.y * tile_size + tile_size / 2.0,
	)
	var unit_node: Node2D = _find_unit_polygon(visuals, unit_id)
	if unit_node == null:
		_trace("[SLIDE] unit=%d polygon=NULL (children: %s) — slide skipped" %
			[unit_id, _list_polygon_names(visuals)])
		return
	_trace("[SLIDE] unit=%d from=%s to=%s (polygon now at %s, target %s)" %
		[unit_id, str(_from), str(to), str(unit_node.position), str(world_pos)])
	# G-30b ROOT CAUSE HYPOTHESIS (session 7): SceneManager._pause_overworld
	# sets BattleScene.process_mode = PROCESS_MODE_DISABLED on
	# battle_launch_requested, and `get_tree().create_tween()` called from a BattleScene
	# method binds the Tween to `self` (BattleScene) — disabled-mode parents
	# pause their tweens, so tween_property writes never fire in windowed mode.
	# Fix: bind the slide tween to the SceneTree itself via
	# `get_tree().create_tween()` — SceneTree is the root scheduler, immune to
	# parent process_mode. Failsafe instant-set at duration+buffer survives
	# either way (covers headless tests that don't run the tween scheduler
	# loop AND any remaining windowed-env edge cases).
	var start_pos: Vector2 = unit_node.position
	var slide_tween: Tween = get_tree().create_tween()
	slide_tween.tween_property(unit_node, "position", world_pos, MOVE_ANIM_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	get_tree().create_timer(MOVE_ANIM_DURATION + 0.05).timeout.connect(func() -> void:
		# Re-resolve the polygon at fire time — ChapterVisuals may have been
		# freed mid-slide (battle end during animation).
		var v: Node = _find_chapter_visuals()
		if v == null:
			return
		var n: Node2D = _find_unit_polygon(v, unit_id)
		if is_instance_valid(n):
			n.position = world_pos)
	SoundManager.play(SoundManager.SFX_MOVE)
	_trace("[SLIDE-DONE] unit=%d polygon.position now %s (start %s → target %s)" %
		[unit_id, str(unit_node.position), str(start_pos), str(world_pos)])
	# Rotation tween: catch directional polygons (CAVALRY/ARCHER/SCOUT) up to
	# the post-move facing. Non-directional classes return 0 from
	# rotation_for_facing, so the tween is a no-op for them.
	if _grid_controller == null:
		return  # test mode without controller — slide handles position; rotation/active skipped
	var unit: BattleUnit = _grid_controller.get_battle_unit(unit_id)
	if unit != null:
		var target_rotation: float = (visuals as ChapterVisuals) \
			.rotation_for_facing(unit.facing, unit.unit_class)
		var rot_tween: Tween = get_tree().create_tween().set_parallel(true)
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
		# Session-15: a CAVALRY that just crossed CHARGE_THRESHOLD on this slide
		# now has the cyan halo eligible; a SCOUT whose new range overlaps an
		# unacted enemy now has indigo targets. Recompute both from the new
		# position so the verb-feedback cue appears the instant the slide ends.
		_apply_verb_feedback_overlays(visuals, unit_id, to)
	else:
		visuals.set_attackable_tiles(PackedVector2Array())
		_clear_verb_feedback_overlays(visuals)


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
	if damage > 0:
		SoundManager.play(SoundManager.SFX_HIT)
	var original_modulate: Color = unit_node.modulate
	unit_node.modulate = Color(2.0, 0.4, 0.4, 1.0)  # bright red flash
	# Failsafe: ensure the defender goes back to its non-flash color even if
	# the Tween writes don't advance. Use a timer rather than tween_callback
	# (which also can drop in the same windowed scenarios). Re-resolve the
	# polygon at fire time instead of capturing it — the ChapterVisuals (and its
	# polygons) gets freed by SceneManager the moment the battle ends, and a
	# captured-then-freed node makes Godot spam "Lambda capture freed" warnings.
	get_tree().create_timer(0.25).timeout.connect(func() -> void:
		var v: Node = _find_chapter_visuals()
		if v == null:
			return
		var n: Node2D = _find_unit_polygon(v, defender_id)
		if is_instance_valid(n):
			n.modulate = original_modulate)
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
			var lunge_tween: Tween = get_tree().create_tween()
			lunge_tween.tween_property(attacker_node, "position", lunge_target, LUNGE_HALF_DURATION) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			lunge_tween.tween_property(attacker_node, "position", origin, LUNGE_HALF_DURATION) \
				.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# Attack line from attacker to defender. Parented to ChapterVisuals so
		# the line persists if the hit kills the defender or the attacker is
		# repositioned mid-animation. Session-16: pass attacker_class so the
		# line picks a per-class style (spear / bow-arc / scroll-zap / etc.).
		var attacker_class: int = -1
		if _grid_controller != null and _grid_controller.has_method("get_unit_class"):
			attacker_class = _grid_controller.get_unit_class(attacker_id)
		var line: AttackLine = AttackLine.make_for_class(origin, unit_node.position,
			attacker_class)
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
	# scheduler behaviour. Re-resolve the polygon at fire time (don't capture it)
	# — see _on_damage_applied for the "Lambda capture freed" rationale.
	get_tree().create_timer(DEATH_FADE_DURATION + 0.05).timeout.connect(func() -> void:
		var v: Node = _find_chapter_visuals()
		if v == null:
			return
		var n: Node2D = _find_unit_polygon(v, unit_id)
		if is_instance_valid(n):
			n.modulate.a = 0.0
			n.visible = false)


## Mounts a brief centered title card (chapter title + tagline) at battle start.
## Auto-removes after TITLE_CARD_DURATION via SceneTreeTimer — chosen over a
## _process countdown because _pause_overworld() disables _process on this scene
## (see _on_battle_outcome_resolved) while SceneTreeTimer.timeout still fires.
## No fade-out tween: Tween property writes are unreliable in the windowed env
## (G-30b), so the card just snaps away when the timer fires.
func _mount_title_card(chapter: ChapterDefinition, roster: Array[BattleUnit]) -> void:
	if _hud_layer == null or chapter == null:
		return
	var flavor: Dictionary = CHAPTER_FLAVOR.get(chapter.chapter_id, {}) as Dictionary
	var title_text: String = flavor.get("title", "제%d장" % chapter.chapter_number) as String
	var tagline_text: String = flavor.get("tagline", "") as String
	var roster_text: String = _format_player_roster_line(roster)

	# CenterContainer (full-rect) centers its single child — clean, no offset math.
	var card: CenterContainer = CenterContainer.new()
	card.name = "TitleCard"
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 8)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)

	var title: Label = Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90, 1.0))
	title.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.04, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_font_size_override("font_size", 40)
	box.add_child(title)

	if not tagline_text.is_empty():
		var tagline: Label = Label.new()
		tagline.text = tagline_text
		tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tagline.add_theme_color_override("font_color", Color(0.86, 0.84, 0.78, 1.0))
		tagline.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.04, 1.0))
		tagline.add_theme_constant_override("outline_size", 6)
		tagline.add_theme_font_size_override("font_size", 22)
		box.add_child(tagline)

	if not roster_text.is_empty():
		var roster_label: Label = Label.new()
		roster_label.text = roster_text
		roster_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		roster_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Slight cool tint so the roster reads as "your forces" — distinct from the
		# warm tagline (situation prose) above it.
		roster_label.add_theme_color_override("font_color", Color(0.78, 0.86, 0.93, 1.0))
		roster_label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.04, 1.0))
		roster_label.add_theme_constant_override("outline_size", 5)
		roster_label.add_theme_font_size_override("font_size", 18)
		box.add_child(roster_label)

	_hud_layer.add_child(card)
	# Self-destruct via a child Timer (not a SceneTreeTimer): if the scene reloads
	# before TITLE_CARD_DURATION elapses, the Timer is freed along with `card`, so
	# there's no dangling callback referencing a freed node.
	var life: Timer = Timer.new()
	life.one_shot = true
	life.autostart = true
	life.wait_time = TITLE_CARD_DURATION
	life.timeout.connect(card.queue_free)
	card.add_child(life)


## Builds the "출진: 유비 (지휘) · 장비 (보병)" line shown under the chapter
## tagline so the player sees who they're commanding before the fight starts.
## Player-side units only — enemies are revealed via the units themselves.
## Returns "" when the roster has no player units (no line rendered).
func _format_player_roster_line(roster: Array[BattleUnit]) -> String:
	var parts: Array[String] = []
	for unit: BattleUnit in roster:
		if unit.side != 0:
			continue
		var hero: HeroData = HeroDatabase.get_hero(unit.hero_id)
		var name_ko: String = hero.name_ko if hero != null and hero.name_ko != "" else String(unit.hero_id)
		var class_name_ko: String = _class_label_ko(unit.unit_class)
		parts.append("%s (%s)" % [name_ko, class_name_ko])
	if parts.is_empty():
		return ""
	return "출진: " + "  ·  ".join(parts)


## Korean short label for the 6 UnitRole classes. Kept inline so the title card
## doesn't pull on the BattleHUD's i18n stack (which is en.po only).
func _class_label_ko(unit_class: int) -> String:
	match unit_class:
		int(UnitRole.UnitClass.CAVALRY):    return "기병"
		int(UnitRole.UnitClass.INFANTRY):   return "보병"
		int(UnitRole.UnitClass.ARCHER):     return "궁병"
		int(UnitRole.UnitClass.STRATEGIST): return "책사"
		int(UnitRole.UnitClass.COMMANDER):  return "지휘"
		int(UnitRole.UnitClass.SCOUT):      return "척후"
		_:                                  return "?"


## Mounts a small always-on controls hint at the bottom of the viewport.
## A first-time player otherwise has no cue for the click flow (select → move/
## attack tile → re-click to end turn). Bottom-anchored Label inside HUDLayer.
func _mount_controls_hint() -> void:
	if _hud_layer == null:
		return
	var hint: Label = Label.new()
	hint.name = "ControlsHint"
	hint.text = "유닛 클릭 → 빈 칸 = 이동 · 적 클릭 1회 = 미리보기 · 2회 = 공격 · [D] 방어 · 재클릭 = 턴 종료    [H] 도움말  [Esc] 일시정지"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(0.95, 0.93, 0.86, 0.92))
	hint.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.05, 1.0))
	hint.add_theme_constant_override("outline_size", 5)
	hint.add_theme_font_size_override("font_size", 18)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -34.0
	hint.offset_bottom = -8.0
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud_layer.add_child(hint)


## Battle-outcome handler (connected to GridBattleController's LOCAL signal).
## Dims the grid, shows the OutcomeBanner, and mounts outcome-aware post-battle
## buttons. The ScenarioRunner-side advance (BEAT_6→9, chapter transition) is
## driven by _proceed_scenario() when the player chooses to move on — the
## GameBus emit that wakes ScenarioRunner here is done by BattleOutcomeBridge,
## which is also connected to the controller's signal (R-7: scene root never
## emits GameBus). The HUD's UI-GB-09 results panel renders in parallel.
func _on_battle_outcome_resolved(outcome: StringName, _fate_data: Dictionary) -> void:
	_trace("[BATTLE-END] outcome=%s — showing banner + post-battle options" % outcome)
	_battle_resolved = true
	_pending_outcome = _outcome_result(outcome)
	# Root cause of "restart hotkey doesn't fire" (session 4): in standalone
	# launch, SceneManager treats this BattleScene as the "overworld" and calls
	# _pause_overworld() on it (process_mode = DISABLED + set_process_input(false)
	# + set_process_unhandled_input(false)). That stops _process() — so the
	# restart-key polling loop below never runs. This signal handler fires
	# regardless of process_mode (direct signal callback), so we re-arm our own
	# processing here, the moment the battle ends. PROCESS_MODE_ALWAYS also
	# survives any future pause. Re-enable _input/_unhandled_input too for parity.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(true)
	set_process_input(true)
	set_process_unhandled_input(true)
	var visuals: Node = _find_chapter_visuals()
	if is_instance_valid(visuals) and visuals is CanvasItem:
		# Instant-set the final dim color so the visual change is guaranteed
		# even if Tween writes don't advance (observed in user windowed env).
		# (SceneManager may free this node a frame or two later on its own
		# battle_outcome_resolved subscription — guard with is_instance_valid.)
		(visuals as CanvasItem).modulate = OUTCOME_DIM_COLOR
	if _hud_layer != null:
		# Drop the controls hint — the screen now belongs to the outcome banner.
		var hint: Node = _hud_layer.get_node_or_null("ControlsHint")
		if hint != null:
			hint.queue_free()
		var banner: OutcomeBanner = OutcomeBanner.make(outcome)
		banner.name = "OutcomeBanner"
		_hud_layer.add_child(banner)
		_mount_post_battle_buttons(_pending_outcome)


## Maps a controller outcome StringName to a BattleOutcome.Result int.
func _outcome_result(outcome: StringName) -> int:
	match outcome:
		&"VICTORY_ANNIHILATION": return BattleOutcome.Result.WIN
		&"DEFEAT_ANNIHILATION": return BattleOutcome.Result.LOSS
		&"TURN_LIMIT_REACHED": return BattleOutcome.Result.DRAW
		_: return BattleOutcome.Result.DRAW


## Outcome-aware post-battle button cluster below the OutcomeBanner.
## WIN → 다음 장으로 / 처음부터 / 종료.   DRAW or LOSS → 재시도 / 이대로 진행 / 종료.
## Buttons go through the Viewport GUI path, so they work even if the keyboard
## poll in _process doesn't register in the windowed env (session 4). The first
## button grabs focus so Enter activates it.
func _mount_post_battle_buttons(result: int) -> void:
	if _hud_layer == null:
		return
	var bar: CenterContainer = CenterContainer.new()
	bar.name = "PostBattleButtons"
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar.offset_top = 150.0  # push the cluster below the outcome glyph
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE  # only the buttons capture clicks
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(row)

	var first_btn: Button = null
	if result == BattleOutcome.Result.WIN:
		first_btn = _add_post_battle_button(row, "다음 장으로 ▶  (Enter)", _proceed_scenario)
		_add_post_battle_button(row, "처음부터", _restart_scenario)
	else:
		first_btn = _add_post_battle_button(row, "재시도  (Enter)", _retry_chapter)
		_add_post_battle_button(row, "이대로 진행 ▶", _proceed_scenario)
	_add_post_battle_button(row, "종료 (Esc)", func() -> void: get_tree().quit())

	_hud_layer.add_child(bar)
	if first_btn != null:
		first_btn.grab_focus()


func _add_post_battle_button(row: HBoxContainer, label: String, on_press: Callable) -> Button:
	var btn: Button = Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(200, 50)
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(func() -> void:
		_trace("[BATTLE-END] button pressed: %s" % label)
		on_press.call())
	row.add_child(btn)
	return btn


## Re-fight the current chapter. On LOSS/DRAW the scenario is in BEAT_6_RESULT;
## retry_outcome() bounces it back to BEAT_4_PREP (bumping echo_count), then the
## scene reload re-runs _ready() → _start_battle() → confirm.
func _retry_chapter() -> void:
	_battle_resolved = false  # neutralize the post-battle key poll during the awaits
	if await _wait_for_scenario_state(ScenarioRunner.State.BEAT_6_RESULT):
		ScenarioRunner.retry_outcome()  # -> BEAT_4_PREP
	else:
		push_warning("BattleScene: retry — ScenarioRunner not in BEAT_6_RESULT; reloading anyway")
	await _reload_via_scenario()


## Re-start the whole scenario from chapter 1. load_scenario resets ScenarioRunner
## to CHAPTER_START → BEAT_1_ANCHOR; the scene reload then drives it to battle.
func _restart_scenario() -> void:
	_battle_resolved = false
	ScenarioRunner.load_scenario("res://assets/data/scenarios/mvp_shu.json")
	await _reload_via_scenario()


## Accept the outcome and move the scenario forward: BEAT_6 → 7 → 8 → 9 → either
## the next chapter (reload this scene — _ready picks it up via ScenarioRunner)
## or SCENARIO_END (show the ending screen, no reload). In windowed runs, the
## Beat 8 revelation + Beat 9 transition are presented via StoryBeatScreen before
## the chapter is walked off (BEAT_8 → BEAT_9 advances the chapter index).
func _proceed_scenario() -> void:
	_battle_resolved = false  # neutralize the post-battle key poll during the awaits
	if not await _wait_for_scenario_state(ScenarioRunner.State.BEAT_6_RESULT):
		push_warning("BattleScene: proceed — ScenarioRunner never reached BEAT_6_RESULT")
		return
	ScenarioRunner.accept_outcome()  # -> BEAT_7_JUDGMENT -> BEAT_8_REVEAL (auto)
	# Post-battle story (windowed only). Capture the just-finished chapter + its
	# branch choice NOW — advance_beat() below pushes BEAT_8 -> BEAT_9, which
	# advances the chapter index and clears _last_branch_choice.
	if _should_present_story() \
			and ScenarioRunner.get_state() == ScenarioRunner.State.BEAT_8_REVEAL:
		var finished_chapter: ChapterDefinition = ScenarioRunner.get_current_chapter()
		var branch_choice: DestinyBranchChoice = ScenarioRunner.get_last_branch_choice()
		if finished_chapter != null:
			var post_beats: Array = _collect_post_battle_beats(finished_chapter, branch_choice)
			if not post_beats.is_empty():
				_clear_post_battle_ui()
				await _present_story_beats(post_beats)
	if ScenarioRunner.get_state() == ScenarioRunner.State.BEAT_8_REVEAL:
		ScenarioRunner.advance_beat()  # -> BEAT_9_TRANSITION -> next chapter BEAT_1_ANCHOR | SCENARIO_END
	await get_tree().process_frame
	if ScenarioRunner.get_state() == ScenarioRunner.State.SCENARIO_END:
		_show_ending_screen()
		return
	# A next chapter is queued in BEAT_1_ANCHOR — reload (the fresh _ready walks
	# its pre-battle beats and re-triggers SceneManager to mount ch2's tiles).
	await _reload_via_scenario()


## Reloads this scene once SceneManager has settled to IDLE (it's tearing down
## the just-finished chapter's ChapterVisuals after battle_outcome_resolved). The
## extra trailing frame lets SceneManager's queue_free() actually land before the
## reloaded _ready() re-runs _spawn_unit_polygons_async. No-op (warns) if this
## scene isn't the current scene (non-standalone mode — post-MVP).
func _reload_via_scenario() -> void:
	for _i: int in 30:
		if SceneManager.state == SceneManager.State.IDLE:
			break
		await get_tree().process_frame
	await get_tree().process_frame
	_battle_resolved = false
	if get_tree().current_scene == self:
		get_tree().reload_current_scene()
	else:
		push_warning("BattleScene: scenario-driven reload outside standalone mode not implemented")


## Awaits (up to ~1s) until ScenarioRunner reaches `target`. Returns true on
## success, false on timeout. ScenarioRunner advances via a CONNECT_DEFERRED
## GameBus subscription, so we may need to wait a frame or two after the battle
## ends before BEAT_6_RESULT is reached.
func _wait_for_scenario_state(target: int) -> bool:
	for _i: int in 60:
		if ScenarioRunner.get_state() == target:
			return true
		await get_tree().process_frame
	return ScenarioRunner.get_state() == target


## Scenario-complete screen. Replaces the post-battle buttons with an ending
## card + 처음부터 / 종료. Shown when _proceed_scenario walks the last chapter
## off the end (ScenarioRunner state == SCENARIO_END).
func _show_ending_screen() -> void:
	_trace("[BATTLE-END] scenario complete — showing ending screen")
	if _hud_layer == null:
		return
	var old_buttons: Node = _hud_layer.get_node_or_null("PostBattleButtons")
	if old_buttons != null:
		old_buttons.queue_free()
	var old_banner: Node = _hud_layer.get_node_or_null("OutcomeBanner")
	if old_banner != null:
		old_banner.queue_free()
	var card: CenterContainer = CenterContainer.new()
	card.name = "EndingCard"
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(box)
	var title: Label = Label.new()
	title.text = "시나리오 클리어"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_color_override("font_color", Color(0.95, 0.84, 0.46, 1.0))  # warm gold-ish (not the reserved #D4A017)
	title.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.04, 1.0))
	title.add_theme_constant_override("outline_size", 8)
	title.add_theme_font_size_override("font_size", 48)
	box.add_child(title)
	var sub: Label = Label.new()
	sub.text = "장판파에서 강하 외곽까지 — 촉한은 살아남았고, 적벽이 기다린다."
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sub.add_theme_color_override("font_color", Color(0.86, 0.84, 0.78, 1.0))
	sub.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.04, 1.0))
	sub.add_theme_constant_override("outline_size", 6)
	sub.add_theme_font_size_override("font_size", 22)
	box.add_child(sub)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 24)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	var again: Button = _add_post_battle_button(row, "처음부터  (Enter)", _restart_scenario)
	_add_post_battle_button(row, "종료 (Esc)", func() -> void: get_tree().quit())
	_hud_layer.add_child(card)
	again.grab_focus()


## Mid-/post-battle keyboard polling. Polling sidesteps InputRouter (autoload),
## which binds Esc to move_cancel and consumes events before BattleScene's
## _unhandled_input would see them. ESC opens the pause menu in both phases;
## Enter/R/Space drive the primary post-battle action when _battle_resolved.
var _process_tick: int = 0
## BattleOutcome.Result of the just-finished battle (-1 until battle_outcome_resolved).
var _pending_outcome: int = -1
## Edge-detect latch for the ESC pause-toggle.
var _esc_was_held: bool = false
## Edge-detect latch for the H help-toggle.
var _h_was_held: bool = false

func _process(_delta: float) -> void:
	# ESC opens the pause menu mid- AND post-battle. Edge-detected so a held key
	# doesn't spawn-and-close the menu every frame.
	var esc_held: bool = (
		Input.is_physical_key_pressed(KEY_ESCAPE)
		or Input.is_key_pressed(KEY_ESCAPE)
	)
	if esc_held and not _esc_was_held:
		_open_pause_menu()
	_esc_was_held = esc_held

	# H opens the help overlay. Distinct from pause — does NOT freeze the tree;
	# the player can read while AI-turn animations keep playing in the background.
	var h_held: bool = (
		Input.is_physical_key_pressed(KEY_H)
		or Input.is_key_pressed(KEY_H)
	)
	if h_held and not _h_was_held:
		_toggle_help_overlay()
	_h_was_held = h_held

	if not _battle_resolved:
		return
	_process_tick += 1
	if _process_tick % 60 == 1:
		# Once per second while waiting for input — confirms _process is firing.
		_trace("[POST-BATTLE-WAIT] _process firing; ENTER=%s R=%s SPACE=%s ESC=%s" %
			[Input.is_physical_key_pressed(KEY_ENTER) or Input.is_physical_key_pressed(KEY_KP_ENTER),
			Input.is_physical_key_pressed(KEY_R),
			Input.is_physical_key_pressed(KEY_SPACE),
			Input.is_physical_key_pressed(KEY_ESCAPE)])
	if (Input.is_physical_key_pressed(KEY_ENTER) or Input.is_key_pressed(KEY_ENTER)
			or Input.is_physical_key_pressed(KEY_KP_ENTER)
			or Input.is_physical_key_pressed(KEY_R) or Input.is_key_pressed(KEY_R)
			or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SPACE)):
		_trace("[BATTLE-END] forward key pressed — invoking primary post-battle action")
		_battle_resolved = false  # gate further key handling until the next battle
		set_process(false)
		_invoke_primary_post_battle_action()


## Mounts a PauseMenu on the HUD layer (idempotent — does nothing if already
## mounted) and pauses the tree. Used by the ESC poll above. The pause menu
## owns its own resume / main-menu / quit handlers.
func _open_pause_menu() -> void:
	if _hud_layer == null:
		return
	if _hud_layer.get_node_or_null("PauseMenu") != null:
		return  # already paused — let the menu handle its own close
	var menu: PauseMenu = PauseMenu.new()
	menu.name = "PauseMenu"
	menu.resume_requested.connect(_on_pause_menu_resumed)
	_hud_layer.add_child(menu)
	menu.show_paused()


func _on_pause_menu_resumed() -> void:
	var menu: Node = _hud_layer.get_node_or_null("PauseMenu") if _hud_layer != null else null
	if menu != null:
		menu.queue_free()


## Toggles the HelpOverlay on the HUD layer. Mid- AND post-battle. Unlike
## the pause menu this does NOT freeze the tree — the player can read the
## reference card while the AI keeps acting. Same edge-detection pattern as
## PauseMenu so a single H tap toggles cleanly without flicker.
func _toggle_help_overlay() -> void:
	if _hud_layer == null:
		return
	var existing: Node = _hud_layer.get_node_or_null("HelpOverlay")
	if existing != null:
		# Already shown — let the overlay's own close handler tear it down so
		# its close_requested signal still fires (keeps the flow symmetric).
		if existing.has_method("_on_close_pressed"):
			existing._on_close_pressed()
		return
	var overlay: HelpOverlay = HelpOverlay.new()
	overlay.name = "HelpOverlay"
	overlay.close_requested.connect(_on_help_overlay_closed)
	_hud_layer.add_child(overlay)
	overlay.show_help()


func _on_help_overlay_closed() -> void:
	var overlay: Node = _hud_layer.get_node_or_null("HelpOverlay") if _hud_layer != null else null
	if overlay != null:
		overlay.queue_free()


## Runs the same action as the focused post-battle button: on WIN that's
## _proceed_scenario; on DRAW/LOSS that's _retry_chapter.
func _invoke_primary_post_battle_action() -> void:
	if _pending_outcome == BattleOutcome.Result.WIN:
		_proceed_scenario()
	else:
		_retry_chapter()


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
	# Player-side units only — AI turns can chain rapid-fire and a chirp on every
	# enemy turn would feel like spam. Player chirp signals "your turn now" cleanly.
	if unit != null and unit.is_player_controlled:
		SoundManager.play(SoundManager.SFX_TURN)
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
			# Session-13: clear any defend stance badge — the new round means
			# every unit's stance was consumed (or not used) and starts fresh.
			var badge: Node = poly.get_node_or_null("DefendBadge")
			if badge != null:
				badge.queue_free()


## Session-13 — defend stance applied. Adds a small "방" Label to the unit's
## polygon so the player can see at a glance that the unit will take 50% less
## damage on the next incoming attack. Removed at round_started_visual.
func _on_unit_defend_stance_applied(unit_id: int) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	var poly: Node2D = _find_unit_polygon(visuals, unit_id)
	if poly == null:
		return
	# Idempotent — if the badge is already there (e.g., AI defends twice in a
	# round somehow), don't stack duplicates.
	if poly.get_node_or_null("DefendBadge") != null:
		return
	var badge: Label = Label.new()
	badge.name = "DefendBadge"
	badge.text = "방"
	# High-contrast on the faction fill — gold border with white inner.
	badge.add_theme_color_override("font_color", Color(1.0, 0.95, 0.78, 1.0))
	badge.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.05, 1.0))
	badge.add_theme_constant_override("outline_size", 6)
	badge.add_theme_font_size_override("font_size", 18)
	# Counter polygon facing rotation so the glyph stays upright.
	badge.rotation = -poly.rotation
	# Top-right corner of the polygon (positive X, negative Y in local coords).
	badge.position = Vector2(18, -34)
	badge.size = Vector2(20, 20)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	poly.add_child(badge)


## Session-16: hero active skill fired. Plays the SFX_SKILL cue so the player
## gets immediate audio feedback that the one-shot was consumed. View-only —
## damage application is handled separately via _on_damage_applied for the
## damage-dealing skills (thunder_roar / piercing_volley / strategist).
func _on_unit_skill_used(_unit_id: int, _skill_id: StringName) -> void:
	if SoundManager != null and SoundManager.has_method("play"):
		SoundManager.play(SoundManager.SFX_SKILL)


## Session-16: mid-battle kill notification. Spawns "X 처치!" popup at the
## victim's polygon position (captured BEFORE the death-fade tween hides the
## node) + plays SFX_KILL flourish. Killer/victim ids both arrive on the
## signal; only the victim's display name + accent are needed.
func _on_unit_killed_mid_battle(_killer_id: int, victim_id: int,
		victim_hero_id: StringName) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	var victim_node: Node2D = _find_unit_polygon(visuals, victim_id)
	if victim_node == null:
		return
	# Resolve display name + accent color (uses chapter_visuals' authoritative
	# accent dict so it stays in sync with the unit polygon's border color).
	var display_name: String = String(victim_hero_id)
	var hero: HeroData = HeroDatabase.get_hero(victim_hero_id)
	if hero != null and hero.name_ko != "":
		display_name = hero.name_ko
	var accent: Color = Color(0.96, 0.86, 0.42, 1.0)  # default warm gold
	if visuals.has_method("_get_hero_accent"):
		# Visualss internal helper — public-ish per chapter_visuals docstring.
		accent = visuals._get_hero_accent(victim_hero_id, 1)  # side=1 fallback
	# SFX cue.
	if SoundManager != null and SoundManager.has_method("play"):
		SoundManager.play(SoundManager.SFX_KILL)
	# Popup at victim position.
	var popup: KillPopup = KillPopup.make(display_name, accent)
	popup.position = victim_node.position + Vector2(0.0, -16.0)
	visuals.add_child(popup)


## Session-16: critical-hit (REAR-direction) feedback. Spawns the "치명타!"
## popup at the defender's position + triggers camera shake + plays SFX.
## Receives the same defender_id the damage_applied handler does; uses the
## defender's polygon position so the popup tracks late-game repositioning.
func _on_critical_hit_landed(_attacker_id: int, defender_id: int, damage: int,
		_angle: StringName) -> void:
	var visuals: Node = _find_chapter_visuals()
	if visuals == null:
		return
	var defender_node: Node2D = _find_unit_polygon(visuals, defender_id)
	if defender_node == null:
		return
	# Stronger camera shake than a normal hit — REAR is the big payoff.
	if _battle_camera != null and _battle_camera.has_method("shake"):
		_battle_camera.shake(8.0, 0.25)
	# SFX cue.
	if SoundManager != null and SoundManager.has_method("play"):
		SoundManager.play(SoundManager.SFX_CRITICAL)
	# "치명타!" popup above the defender. Offset slightly above the standard
	# DamagePopup (which also fires this frame via _on_damage_applied) so the
	# two labels don't stack.
	var popup: CriticalPopup = CriticalPopup.make(damage)
	popup.position = defender_node.position
	visuals.add_child(popup)


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
