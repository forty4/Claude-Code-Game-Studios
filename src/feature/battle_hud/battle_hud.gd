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
## Signal connections wired in story-002: 11 subscriptions across 4 domains.
##   - 4 controller-LOCAL on _grid_controller (unit_selected_changed, unit_moved,
##     damage_applied, battle_outcome_resolved)
##   - 7 GameBus (unit_died, round_started, unit_turn_started, unit_turn_ended,
##     input_state_changed, input_mode_changed, formation_bonuses_updated)
## All use Object.CONNECT_DEFERRED per ADR-0001 §5.

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

	# ── Story-002: 11 signal subscriptions ─────────────────────────────────────
	# 4 controller-LOCAL on _grid_controller (NOT GameBus) per ADR-0014 §8 +
	# ADR-0015 §3. NOTE: the GridBattleController 5th controller-LOCAL signal
	# (per ADR-0014 §8 line 335; ADR-0015 §1 Pillar 2 lock) is deliberately
	# omitted; story-008 CRITICAL CI lint enforces source-content absence.
	_grid_controller.unit_selected_changed.connect(_on_unit_selected_changed, Object.CONNECT_DEFERRED)
	_grid_controller.unit_moved.connect(_on_unit_moved, Object.CONNECT_DEFERRED)
	_grid_controller.damage_applied.connect(_on_damage_applied, Object.CONNECT_DEFERRED)
	_grid_controller.battle_outcome_resolved.connect(_on_battle_outcome_resolved, Object.CONNECT_DEFERRED)

	# 7 GameBus subscriptions — HP/Status + Turn Order + InputRouter + Formation
	GameBus.unit_died.connect(_on_unit_died, Object.CONNECT_DEFERRED)
	GameBus.round_started.connect(_on_round_started, Object.CONNECT_DEFERRED)
	GameBus.unit_turn_started.connect(_on_unit_turn_started, Object.CONNECT_DEFERRED)
	GameBus.unit_turn_ended.connect(_on_unit_turn_ended, Object.CONNECT_DEFERRED)
	GameBus.input_state_changed.connect(_on_input_state_changed, Object.CONNECT_DEFERRED)
	GameBus.input_mode_changed.connect(_on_input_mode_changed, Object.CONNECT_DEFERRED)
	GameBus.formation_bonuses_updated.connect(_on_formation_bonuses_updated, Object.CONNECT_DEFERRED)


func _exit_tree() -> void:
	# Disconnect all 11 subscriptions mirroring the connect block in _ready().
	# Godot 4.x signal.disconnect(callable) is a safe no-op when not connected.
	# Defensive is_connected() guards retained per ADR-0015 §3 Implementation
	# Note 4: avoids benign debug-build errors if _exit_tree fires before _ready()
	# subscribed (e.g., in unit tests that free before add_child).

	# 4 controller-LOCAL disconnects
	if is_instance_valid(_grid_controller):
		if _grid_controller.unit_selected_changed.is_connected(_on_unit_selected_changed):
			_grid_controller.unit_selected_changed.disconnect(_on_unit_selected_changed)
		if _grid_controller.unit_moved.is_connected(_on_unit_moved):
			_grid_controller.unit_moved.disconnect(_on_unit_moved)
		if _grid_controller.damage_applied.is_connected(_on_damage_applied):
			_grid_controller.damage_applied.disconnect(_on_damage_applied)
		if _grid_controller.battle_outcome_resolved.is_connected(_on_battle_outcome_resolved):
			_grid_controller.battle_outcome_resolved.disconnect(_on_battle_outcome_resolved)

	# 7 GameBus disconnects
	if GameBus.unit_died.is_connected(_on_unit_died):
		GameBus.unit_died.disconnect(_on_unit_died)
	if GameBus.round_started.is_connected(_on_round_started):
		GameBus.round_started.disconnect(_on_round_started)
	if GameBus.unit_turn_started.is_connected(_on_unit_turn_started):
		GameBus.unit_turn_started.disconnect(_on_unit_turn_started)
	if GameBus.unit_turn_ended.is_connected(_on_unit_turn_ended):
		GameBus.unit_turn_ended.disconnect(_on_unit_turn_ended)
	if GameBus.input_state_changed.is_connected(_on_input_state_changed):
		GameBus.input_state_changed.disconnect(_on_input_state_changed)
	if GameBus.input_mode_changed.is_connected(_on_input_mode_changed):
		GameBus.input_mode_changed.disconnect(_on_input_mode_changed)
	if GameBus.formation_bonuses_updated.is_connected(_on_formation_bonuses_updated):
		GameBus.formation_bonuses_updated.disconnect(_on_formation_bonuses_updated)


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


# ─── Signal callbacks ─────────────────────────────────────────────────────────

## _on_unit_selected_changed — controller-LOCAL subscriber (GridBattleController).
## was_selected: int (not bool) per ADR-0014 §8 line 85: `signal unit_selected_changed(unit_id: int, was_selected: int)`.
func _on_unit_selected_changed(unit_id: int, was_selected: int) -> void:
	_handle_signal(&"unit_selected_changed", [unit_id, was_selected])
	# UI-GB-04 selection indicator render wired in story-004.


## _on_unit_moved — controller-LOCAL subscriber (GridBattleController).
func _on_unit_moved(unit_id: int, from: Vector2i, to: Vector2i) -> void:
	_handle_signal(&"unit_moved", [unit_id, from, to])
	# UI-GB-05 move animation trigger wired in story-004.


## _on_damage_applied — controller-LOCAL subscriber (GridBattleController).
func _on_damage_applied(attacker_id: int, defender_id: int, damage: int) -> void:
	_handle_signal(&"damage_applied", [attacker_id, defender_id, damage])
	# UI-GB-02 HP bar update wired in story-003.


## _on_battle_outcome_resolved — controller-LOCAL subscriber (GridBattleController).
## outcome: StringName per ADR-0014 §8 line 95: `signal battle_outcome_resolved(outcome: StringName, fate_data: Dictionary)`.
## NOTE: GameBus.battle_outcome_resolved uses outcome: BattleOutcome (consumed by Scenario
## Progression per ADR-0015). This handler subscribes to the CONTROLLER-LOCAL signal.
func _on_battle_outcome_resolved(outcome: StringName, fate_data: Dictionary) -> void:
	_handle_signal(&"battle_outcome_resolved", [outcome, fate_data])
	# UI-GB-09 battle result overlay wired in story-006.


## _on_unit_died — GameBus subscriber (emitter: HPStatusController).
func _on_unit_died(unit_id: int) -> void:
	_handle_signal(&"unit_died", [unit_id])
	# UI-GB-02 death state render wired in story-003.


## _on_round_started — GameBus subscriber (emitter: TurnOrderRunner).
func _on_round_started(round_number: int) -> void:
	_handle_signal(&"round_started", [round_number])
	# UI-GB-01/07/08 round counter + turn order panel wired in stories 003-004.


## _on_unit_turn_started — GameBus subscriber (emitter: TurnOrderRunner).
func _on_unit_turn_started(unit_id: int) -> void:
	_handle_signal(&"unit_turn_started", [unit_id])
	# UI-GB-07 turn indicator wired in story-004.


## _on_unit_turn_ended — GameBus subscriber (emitter: TurnOrderRunner).
## acted: bool — 2-param signature per GameBus line 32: `signal unit_turn_ended(unit_id: int, acted: bool)`.
func _on_unit_turn_ended(unit_id: int, acted: bool) -> void:
	_handle_signal(&"unit_turn_ended", [unit_id, acted])
	# UI-GB-07 turn indicator reset wired in story-004.


## _on_input_state_changed — GameBus subscriber (emitter: InputRouter).
## AC-5: sets MOUSE_FILTER_IGNORE on root when transitioning TO S5 (INPUT_BLOCKED),
## reverts to MOUSE_FILTER_STOP when transitioning AWAY from S5.
## Godot 4.5+ recursive disable: setting IGNORE on root Control propagates to all children.
func _on_input_state_changed(from_state: int, to_state: int) -> void:
	_handle_signal(&"input_state_changed", [from_state, to_state])
	if to_state == InputRouter.InputState.INPUT_BLOCKED:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif from_state == InputRouter.InputState.INPUT_BLOCKED:
		mouse_filter = Control.MOUSE_FILTER_STOP


## _on_input_mode_changed — GameBus subscriber (emitter: InputRouter).
func _on_input_mode_changed(new_mode: int) -> void:
	_handle_signal(&"input_mode_changed", [new_mode])
	# Input mode display (touch/PC) wired in story-005.


## _on_formation_bonuses_updated — GameBus subscriber.
## Cross-epic forward-prep signal declared on GameBus in story-002 (battle-hud)
## per ADR-0015 §3 R-3. Emission site (GridBattleController) ships in Grid Battle epic.
## snapshot: Dictionary — formation bonus state snapshot per ADR-0014 CR-12 + ADR-0015 §5.
func _on_formation_bonuses_updated(snapshot: Dictionary) -> void:
	_handle_signal(&"formation_bonuses_updated", [snapshot])
	# UI-GB-10 formation bonus display wired in story-005.
