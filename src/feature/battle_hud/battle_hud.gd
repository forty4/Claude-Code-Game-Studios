## BattleHUD — Battle-scoped Control orchestrator for the player-facing battle surface.
##
## Per ADR-0015 §1: 5th invocation of battle-scoped Node pattern (after ADR-0010
## HPStatusController + ADR-0011 TurnOrderRunner + ADR-0013 BattleCamera +
## ADR-0014 GridBattleController). Mounted at BattleScene/HUDLayer/BattleHUD.
## Freed automatically with BattleScene per ADR-0002. Not autoloaded.
##
## `extends Control` (NOT CanvasLayer) — required to inherit AccessKit auto-exposure
## (Godot 4.5+), input routing, focus management, and theme inheritance per ADR-0015 §1.
## Mounted under a CanvasLayer parent to enforce HUD-on-top render order independent
## of camera transform.
##
## DI seam: BattleScene wiring MUST call `setup(...)` BEFORE `add_child()`. `_ready()`
## asserts all 9 backend deps non-null per ADR-0015 §3. Without setup(), the scene fails
## fast at mount time.
##
## NON-EMITTER DISCIPLINE (ADR-0015 §5 + forbidden_pattern battle_hud_signal_emission):
## This class emits ZERO GameBus signals. Cross-system communication FROM HUD goes
## through method calls on DI'd backends (e.g. InputRouter._handle_event for undo).
## Story-008 CI lint enforces this via `lint_battle_hud_hidden_fate_non_subscription.sh`.
##
## PILLAR 2 LOCK: The GridBattleController hidden-fate signal (per ADR-0014 §8
## line 335; ADR-0015 §1 Pillar 2 lock) MUST NEVER be subscribed to here.
## Story-008 CI lint (CRITICAL) enforces this at build time.
##
## Signal connections are wired in story-002. This story-001 skeleton declares only
## the private backend fields, `setup()`, `_ready()` asserts + PRESET_FULL_RECT,
## `_handle_signal()` test seam, and `_exit_tree()` skeleton.

class_name BattleHUD
extends Control


# ─── Private backend fields (DI'd via setup() before add_child) ─────────────

## All 9 backend deps stored as private typed fields. @onready is NOT used —
## DI happens pre-add_child; these are populated by setup(), not by the scene tree.
var _camera: BattleCamera
var _hp_controller: HPStatusController
var _turn_runner: TurnOrderRunner
var _grid_controller: GridBattleController
var _input_router: InputRouter
var _map_grid: MapGrid
var _terrain_effect: TerrainEffect
var _unit_role: UnitRole
var _hero_db: HeroDatabase


# ─── UI element registry ─────────────────────────────────────────────────────

## Registry of 14 UI-GB-* element references keyed by StringName.
## Populated by stories 003-007. Typed Dictionary syntax verified at this
## story-001 first compile per ADR-0015 advisory A-4; if parse errors arise,
## downgrade to `var _ui_elements: Dictionary = {}` with type-comment annotation.
var _ui_elements: Dictionary[StringName, Control] = {}


# ─── DI seam ─────────────────────────────────────────────────────────────────

## setup() — 9-param dependency injection seam per ADR-0015 §3.
##
## Called BY BattleScene wiring BEFORE add_child(). Mirrors ADR-0014 8-param
## + ADR-0013 1-param pattern (5th invocation of battle-scoped Node DI).
##
## Parameters:
##   camera         — BattleCamera; read for get_zoom_value() (UI-GB-12/13/14 overlays)
##   hp_controller  — HPStatusController; read for get_current_hp/get_max_hp/get_status_effects
##   turn_runner    — TurnOrderRunner; read for get_turn_order_snapshot()
##   grid_controller — GridBattleController; read for get_selected_unit_id()
##   input_router   — InputRouter; wired for 2 GameBus subscriptions (story-002) +
##                    synthetic event dispatch (story-005/007)
##   map_grid       — MapGrid; read for get_tile() (UI-GB-06 tile info tooltip)
##   terrain_effect — TerrainEffect; read for get_modifier() (UI-GB-06 tooltip)
##   unit_role      — UnitRole; read for class-based stat queries (UI-GB-03 unit info)
##   hero_db        — HeroDatabase; read for get_hero() (UI-GB-03 name + portrait)
func setup(
	camera: BattleCamera,
	hp_controller: HPStatusController,
	turn_runner: TurnOrderRunner,
	grid_controller: GridBattleController,
	input_router: InputRouter,
	map_grid: MapGrid,
	terrain_effect: TerrainEffect,
	unit_role: UnitRole,
	hero_db: HeroDatabase,
) -> void:
	_camera = camera
	_hp_controller = hp_controller
	_turn_runner = turn_runner
	_grid_controller = grid_controller
	_input_router = input_router
	_map_grid = map_grid
	_terrain_effect = terrain_effect
	_unit_role = unit_role
	_hero_db = hero_db


# ─── Built-in virtual methods ─────────────────────────────────────────────────

func _ready() -> void:
	# Assert all 9 DI deps were wired before add_child() per ADR-0015 §3 R-2.
	# Fails fast at mount time if setup() was skipped.
	assert(_camera != null, "BattleHUD: camera DI required before add_child")
	assert(_hp_controller != null, "BattleHUD: hp_controller DI required before add_child")
	assert(_turn_runner != null, "BattleHUD: turn_runner DI required before add_child")
	assert(_grid_controller != null, "BattleHUD: grid_controller DI required before add_child")
	assert(_input_router != null, "BattleHUD: input_router DI required before add_child")
	assert(_map_grid != null, "BattleHUD: map_grid DI required before add_child")
	assert(_terrain_effect != null, "BattleHUD: terrain_effect DI required before add_child")
	assert(_unit_role != null, "BattleHUD: unit_role DI required before add_child")
	assert(_hero_db != null, "BattleHUD: hero_db DI required before add_child")

	# Cover the full viewport — child Controls use individual anchors per
	# battle-hud.md §3 layout spec.
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# No _process work in this skeleton per story-001 AC-7. Story-007 may
	# re-enable _process for grid-overlay zoom-poll when grid overlays are active.
	set_process(false)

	# 11 GameBus signal subscriptions are wired in story-002.
	# _ui_elements registry is populated in stories 003-007.


func _exit_tree() -> void:
	# Skeleton — story-002 fills in 11 CONNECT_DEFERRED disconnect calls.
	# Declared here per ADR-0015 §3 Implementation Note 4 so the pattern
	# is established before signal connections are added.
	#
	# NOTE on guards (story-002 rationale, pre-written for maintainer clarity):
	# Godot 4.x `Signal.disconnect(callable)` is a safe no-op when the callable
	# is not connected — guards are NOT a correctness requirement. They are retained
	# for defensive hygiene to avoid benign debug-build errors if _exit_tree fires
	# before _ready() subscribed (e.g., in unit tests that free before add_child).
	pass


# ─── Public methods ───────────────────────────────────────────────────────────

## show_unit_info() — InputRouter Touch Tap Preview Protocol (CR-4a).
##
## Renders UI-GB-03 unit info panel for unit_id. Called by InputRouter on touch
## tap-preview (CR-4a). PC mouse hover routes through the same path.
## If unit_id == -1, dismisses the panel.
## Body implemented in story-003.
func show_unit_info(unit_id: int) -> void:
	pass


## show_tile_info() — InputRouter Touch Tap Preview Protocol (CR-4a).
##
## Renders UI-GB-06 tile info tooltip for coord. Called by InputRouter on touch
## tap-preview (CR-4a) or PC mouse hover on empty tile.
## If coord == Vector2i(-1, -1), dismisses the tooltip.
## Body implemented in story-007.
func show_tile_info(coord: Vector2i) -> void:
	pass


# ─── Private methods ──────────────────────────────────────────────────────────

## _handle_signal() — test seam for direct signal-handler invocation.
##
## Dispatches a signal by name to the appropriate private handler without
## going through GameBus subscription infrastructure. Production callers MUST
## use GameBus — this seam exists ONLY for unit tests (mirrors ADR-0014 +
## ADR-0005 + ADR-0010 DI test seam pattern).
##
## `args: Array` is intentionally untyped — 11 handlers have heterogeneous arg
## shapes (mix of int, Vector2i, StringName, Dictionary). Typed Array[Variant]
## would offer no additional type safety and requires Variant unwrap at every
## index access per ADR-0015 §4 rationale comment.
##
## Handler bodies are stubbed in story-001; wired in story-002.
func _handle_signal(signal_name: StringName, args: Array) -> void:
	pass
