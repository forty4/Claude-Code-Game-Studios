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
var _input_router: Node  # InputRouter autoload — typed Node since InputRouter dropped class_name per G-3 at S8-02
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


## Active unit_id whose info is currently rendered in UI-GB-03.
## -1 sentinel = no panel visible. Story-003 lifecycle:
##   - Set in show_unit_info(unit_id) happy path
##   - Cleared in show_unit_info(-1)
##   - Cleared defensively in _on_unit_died if unit_id matches active panel
##   - Used by _on_damage_applied + _on_unit_turn_started to dispatch refresh
##     only when relevant.
var _active_status_panel_unit_id: int = -1


## Story-004 (S7-09): UI-GB-01 slot tracking. Cached at _ready() for O(1) access
## during _on_round_started rebuild + _on_unit_turn_started highlight + _on_unit_died rebuild.
## Each entry is the slot's VBoxContainer Control (parent of Portrait + NameLabel).
## _slot_unit_ids[i] tracks which unit_id is currently in slot[i] (-1 = empty/hidden).
var _ui_gb_01_slots: Array[Control] = []
var _ui_gb_01_slot_unit_ids: Array[int] = [-1, -1, -1, -1, -1, -1, -1, -1]
var _ui_gb_01_active_slot_index: int = -1


## Preloaded UI element scenes (story-003 + story-004 + story-005 + future stories add more).
const _UI_GB_03_SCENE: PackedScene = preload("res://scenes/battle/elements/ui_gb_03_unit_info_panel.tscn")
const _UI_GB_11_SCENE: PackedScene = preload("res://scenes/battle/elements/ui_gb_11_defend_stance_badge.tscn")
const _UI_GB_01_SCENE: PackedScene = preload("res://scenes/battle/elements/ui_gb_01_initiative_queue.tscn")
const _UI_GB_07_SCENE: PackedScene = preload("res://scenes/battle/elements/ui_gb_07_turn_round_counter.tscn")
const _UI_GB_08_SCENE: PackedScene = preload("res://scenes/battle/elements/ui_gb_08_victory_condition.tscn")
const _UI_GB_02_SCENE: PackedScene = preload("res://scenes/battle/elements/ui_gb_02_action_menu.tscn")
const _UI_GB_05_SCENE: PackedScene = preload("res://scenes/battle/elements/ui_gb_05_skill_list.tscn")
const _UI_GB_10_SCENE: PackedScene = preload("res://scenes/battle/elements/ui_gb_10_undo_indicator.tscn")
const _UI_GB_04_SCENE: PackedScene = preload("res://scenes/battle/elements/ui_gb_04_combat_forecast.tscn")
const _UI_GB_06_SCENE: PackedScene = preload("res://scenes/battle/elements/ui_gb_06_tile_info_tooltip.tscn")
const _UI_GB_09_SCENE: PackedScene = preload("res://scenes/battle/elements/ui_gb_09_battle_results_screen.tscn")
const _UI_GB_12_SCENE: PackedScene = preload("res://scenes/battle/elements/ui_gb_12_tactical_read_extended_range.tscn")
const _UI_GB_13_SCENE: PackedScene = preload("res://scenes/battle/elements/ui_gb_13_rally_aura.tscn")
const _UI_GB_14_SCENE: PackedScene = preload("res://scenes/battle/elements/ui_gb_14_formation_aura.tscn")

## Locale-independent em-dash placeholder for forecast counter "no counter" preview.
## Hoisted from inline literal to keep Lint 5 (battle_hud_hardcoded_localized_strings)
## clean — Unicode punctuation glyph carries no localized prose (story-008).
const _COUNTER_PLACEHOLDER_DASH: String = "—"


## Two-tap ATTACK/DEFEND timeout (per ADR-0015 OQ-4 + story-005 Implementation Note 3).
## Declared as a local const for MVP — NOT a BalanceConstants entry (story-006+ scope).
## Value: 600 ms matches GDD battle-hud.md §10 Tuning Knobs default.
const TWO_TAP_TIMEOUT_S: float = 0.6


# ─── Story-005: Two-tap state machine fields ─────────────────────────────────

## Timer for ATTACK/DEFEND two-tap confirm window (one_shot; instantiated in _ready()).
## Shared across ATTACK and DEFEND — only one can be armed at a time.
var _two_tap_timer: Timer

## Currently armed two-tap action (&"" sentinel = not armed).
## Only ATTACK and DEFEND arm the two-tap flow; set on first tap, cleared on confirm/cancel/timeout.
var _two_tap_target_action: StringName = &""


# ─── Story-005: Cached button references ─────────────────────────────────────

# ─── Story-006: UI-GB-04 Combat Forecast fields ──────────────────────────────

## Root node of the UI-GB-04 Combat Forecast panel. Null until _ready().
var _forecast_root: PanelContainer

## 6 named subpanel references keyed by StringName for O(1) access.
## Keys: &"direction", &"hit_crit", &"damage", &"counter", &"status_effects", &"passives"
## Populated in _ready() after UI-GB-04 scene instantiation.
## G-25: Dictionary[StringName, Control] depth-1 typed dict — no nested typed collection.
var _forecast_subpanels: Dictionary[StringName, Control] = {}

## Timestamp (µs) recorded at the start of show_forecast() for render-time instrumentation.
## Used to compute _forecast_render_ms_last on completion of populate+visible.
var _forecast_show_us: int = 0

## Timestamp (µs) recorded when _dismiss_forecast() begins. Used to compute
## _forecast_dismiss_ms_last in _on_forecast_dismiss_finished().
var _forecast_dismiss_start_us: int = 0

## Last measured dismiss latency in ms. Set in _on_forecast_dismiss_finished().
## Exposed for test fixture observability (used by integration tests asserting ≤ 80ms).
var _forecast_dismiss_ms_last: float = 0.0

## Last measured render latency in ms (method entry → visible = true).
## Set at end of show_forecast(). Used by AC-9 perf gate test.
var _forecast_render_ms_last: float = 0.0

## Active dismiss Tween, or null when no dismiss is in progress.
## Retained to allow kill-before-reuse (idempotent dismiss path).
var _forecast_dismiss_tween: Tween


# ─── Story-007: UI-GB-06 + UI-GB-09 + UI-GB-12/13/14 grid-layer overlay fields ───

## Cross-tree NodePath to BattleScene/GridLayer per ADR-0016 §2 scene tree topology.
## BattleHUD lives at BattleScene/HUDLayer/BattleHUD; GridLayer is a sibling of HUDLayer.
## Default `^"../../GridLayer"` resolves up 2 (HUDLayer → BattleScene) + down 1 (GridLayer).
## Overridable from .tscn instance or programmatically before add_child() for test fixtures.
@export var grid_layer_path: NodePath = ^"../../GridLayer"

## Grid-layer overlay Node2D references keyed by StringName for O(1) access.
## Keys: &"UI-GB-12", &"UI-GB-13", &"UI-GB-14". Populated in _ready() if cross-tree
## resolution succeeds; empty dict (graceful degradation) if test fixture lacks BattleScene parent.
## G-25: Dictionary[StringName, Node2D] depth-1 typed dict — no nested typed collection.
var _grid_layer_overlays: Dictionary[StringName, Node2D] = {}

## Last measured battle-results render latency in ms. AC-5 instrumentation
## (≤ 200 ms one-shot per battle). Set in _on_battle_outcome_resolved().
var _results_render_ms_last: float = 0.0


## Action-menu button references cached after UI-GB-02 mount. Allows direct
## access for modulate visual + enabled state updates without tree traversal in handlers.
var _btn_move: Button
var _btn_attack: Button
var _btn_use_skill: Button
var _btn_defend: Button
var _btn_wait: Button
var _btn_end_turn: Button
var _btn_undo: Button
var _btn_skill_slot_0: Button
var _btn_skill_slot_1: Button


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
	# MUST be PASS, not the Control default STOP. With STOP, the full-rect HUD root
	# absorbs every mouse click before _unhandled_input fires, so InputRouter never
	# sees grid clicks and the player cannot interact with units (POLISH-011 root
	# cause). PASS lets HUD child Controls (panels/buttons) claim their own clicks
	# while background clicks fall through to InputRouter._unhandled_input.
	mouse_filter = Control.MOUSE_FILTER_PASS

	# Story-007: _process re-enabled for grid-overlay zoom-poll per AC-8.
	# Body gates on _has_active_grid_overlay() — early-returns when no
	# overlays are visible (steady-state cost ≈ 1 dict-iteration per frame).

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

	# ── Story-003: UI-GB-03 + UI-GB-11 element mount ───────────────────────────
	# Instantiate as children of HUD root; start hidden. Populate _ui_elements
	# registry per ADR-0015 §2 + battle-hud.md §3 layout spec.
	var ui_gb_03: Control = _UI_GB_03_SCENE.instantiate() as Control
	var ui_gb_11: Control = _UI_GB_11_SCENE.instantiate() as Control
	ui_gb_03.visible = false
	ui_gb_11.visible = false
	add_child(ui_gb_03)
	add_child(ui_gb_11)
	_ui_elements[&"UI-GB-03"] = ui_gb_03
	_ui_elements[&"UI-GB-11"] = ui_gb_11

	# ── Story-004 (S7-09): UI-GB-01 + UI-GB-07 + UI-GB-08 element mount ───────
	# UI-GB-01 + UI-GB-07 visible by default; UI-GB-08 starts hidden (set_victory_condition reveals).
	var ui_gb_01: Control = _UI_GB_01_SCENE.instantiate() as Control
	var ui_gb_07: Control = _UI_GB_07_SCENE.instantiate() as Control
	var ui_gb_08: Control = _UI_GB_08_SCENE.instantiate() as Control
	# Top ribbon layout: round counter (UI-GB-07) at top-left; initiative queue
	# (UI-GB-01) centered at top; victory condition (UI-GB-08) at top-right.
	# Each scene defaults to anchor (0,0) which collapses them onto each other —
	# anchor explicitly here so they read as one cohesive ribbon.
	ui_gb_07.position = Vector2(12, 12)
	ui_gb_01.set_anchors_preset(Control.PRESET_CENTER_TOP)
	ui_gb_01.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ui_gb_01.offset_top = 12
	ui_gb_08.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	ui_gb_08.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ui_gb_08.offset_left = -232  # custom_minimum_size.x (220) + 12 padding
	ui_gb_08.offset_top = 12
	ui_gb_08.offset_right = -12
	add_child(ui_gb_01)
	add_child(ui_gb_07)
	add_child(ui_gb_08)
	_ui_elements[&"UI-GB-01"] = ui_gb_01
	_ui_elements[&"UI-GB-07"] = ui_gb_07
	_ui_elements[&"UI-GB-08"] = ui_gb_08
	# Cache UI-GB-01 slot Controls for O(1) rebuild access (allocation-free steady state per Guardrail).
	_ui_gb_01_slots.clear()
	for i: int in range(8):
		var slot: Control = ui_gb_01.get_node("Slot%d" % i) as Control
		_ui_gb_01_slots.append(slot)

	# ── Story-005: UI-GB-02 Action Menu + UI-GB-05 Skill List + UI-GB-10 Undo mount ──
	var ui_gb_02: Control = _UI_GB_02_SCENE.instantiate() as Control
	var ui_gb_05: Control = _UI_GB_05_SCENE.instantiate() as Control
	var ui_gb_10: Control = _UI_GB_10_SCENE.instantiate() as Control
	ui_gb_02.visible = false
	ui_gb_05.visible = false
	ui_gb_10.visible = false
	add_child(ui_gb_02)
	add_child(ui_gb_05)
	add_child(ui_gb_10)
	_ui_elements[&"UI-GB-02"] = ui_gb_02
	_ui_elements[&"UI-GB-05"] = ui_gb_05
	_ui_elements[&"UI-GB-10"] = ui_gb_10

	# Cache button references for O(1) access during signal handlers.
	_btn_move = ui_gb_02.get_node_or_null("MoveButton") as Button
	_btn_attack = ui_gb_02.get_node_or_null("AttackButton") as Button
	_btn_use_skill = ui_gb_02.get_node_or_null("UseSkillButton") as Button
	_btn_defend = ui_gb_02.get_node_or_null("DefendButton") as Button
	_btn_wait = ui_gb_02.get_node_or_null("WaitButton") as Button
	_btn_end_turn = ui_gb_02.get_node_or_null("EndTurnButton") as Button
	_btn_undo = ui_gb_10.get_node_or_null("UndoButton") as Button
	_btn_skill_slot_0 = ui_gb_05.get_node_or_null("VBoxContainer/SkillSlot0Button") as Button
	_btn_skill_slot_1 = ui_gb_05.get_node_or_null("VBoxContainer/SkillSlot1Button") as Button

	# Wire UI-GB-02 action button click signals.
	if _btn_move != null:
		_btn_move.pressed.connect(_on_move_button_pressed)
	if _btn_attack != null:
		_btn_attack.pressed.connect(_on_attack_button_pressed)
	if _btn_use_skill != null:
		_btn_use_skill.pressed.connect(_on_use_skill_button_pressed)
	if _btn_defend != null:
		_btn_defend.pressed.connect(_on_defend_button_pressed)
	if _btn_wait != null:
		_btn_wait.pressed.connect(_on_wait_button_pressed)
	if _btn_end_turn != null:
		_btn_end_turn.pressed.connect(_on_end_turn_button_pressed)
	# Wire UI-GB-10 undo button click signal.
	if _btn_undo != null:
		_btn_undo.pressed.connect(_on_undo_button_pressed)
	# Wire UI-GB-05 skill slot button click signals.
	if _btn_skill_slot_0 != null:
		_btn_skill_slot_0.pressed.connect(_on_skill_slot_pressed.bind(0))
	if _btn_skill_slot_1 != null:
		_btn_skill_slot_1.pressed.connect(_on_skill_slot_pressed.bind(1))

	# ── Story-006: UI-GB-04 Combat Forecast mount ──────────────────────────────
	# Instantiate forecast panel; starts hidden (visible = false).
	# FORECAST_RENDER_BUDGET_MS = 120 per ADR-0006 / balance_entities.json.
	var ui_gb_04: PanelContainer = _UI_GB_04_SCENE.instantiate() as PanelContainer
	ui_gb_04.visible = false
	add_child(ui_gb_04)
	_ui_elements[&"UI-GB-04"] = ui_gb_04
	_forecast_root = ui_gb_04
	# Resolve 6 subpanel references by NodePath into _forecast_subpanels dictionary.
	# Paths match the structure in ui_gb_04_combat_forecast.tscn.
	var vbox: VBoxContainer = ui_gb_04.get_node_or_null("VBoxContainer") as VBoxContainer
	if vbox != null:
		var dir_panel: Control = vbox.get_node_or_null("DirectionPanel") as Control
		var hit_panel: Control = vbox.get_node_or_null("HitCritPanel") as Control
		var dmg_panel: Control = vbox.get_node_or_null("DamagePanel") as Control
		var ctr_panel: Control = vbox.get_node_or_null("CounterPanel") as Control
		var sts_panel: Control = vbox.get_node_or_null("StatusEffectsPanel") as Control
		var psv_panel: Control = vbox.get_node_or_null("PassivesPanel") as Control
		if dir_panel != null: _forecast_subpanels[&"direction"] = dir_panel
		if hit_panel != null: _forecast_subpanels[&"hit_crit"] = hit_panel
		if dmg_panel != null: _forecast_subpanels[&"damage"] = dmg_panel
		if ctr_panel != null: _forecast_subpanels[&"counter"] = ctr_panel
		if sts_panel != null: _forecast_subpanels[&"status_effects"] = sts_panel
		if psv_panel != null: _forecast_subpanels[&"passives"] = psv_panel

	# ── Story-007: UI-GB-06 + UI-GB-09 mount as HUD-root children ─────────────
	# UI-GB-06 (tile info tooltip) + UI-GB-09 (battle results screen) — both
	# start hidden; shown by show_tile_info() / _on_battle_outcome_resolved().
	var ui_gb_06: PanelContainer = _UI_GB_06_SCENE.instantiate() as PanelContainer
	var ui_gb_09: PanelContainer = _UI_GB_09_SCENE.instantiate() as PanelContainer
	ui_gb_06.visible = false
	ui_gb_09.visible = false
	add_child(ui_gb_06)
	add_child(ui_gb_09)
	_ui_elements[&"UI-GB-06"] = ui_gb_06
	_ui_elements[&"UI-GB-09"] = ui_gb_09
	# Continue button text via tr() per i18n discipline.
	var continue_btn: Button = ui_gb_09.get_node_or_null(^"VBoxContainer/ContinueButton") as Button
	if continue_btn != null:
		continue_btn.text = tr(&"hud.results.continue")

	# ── Story-007: UI-GB-12/13/14 cross-tree mount under BattleScene/GridLayer ─
	# Per ADR-0016 §2 + story-007 Implementation Note 4. Graceful fallback when
	# test fixture lacks BattleScene parent — _grid_layer_overlays stays empty +
	# warning logged; production rendering paths gate on dict.has() before access.
	var grid_layer: Node2D = get_node_or_null(grid_layer_path) as Node2D
	if grid_layer == null:
		push_warning("BattleHUD: grid_layer_path failed to resolve; UI-GB-12/13/14 disabled")
	else:
		var ui_gb_12: Node2D = _UI_GB_12_SCENE.instantiate() as Node2D
		var ui_gb_13: Node2D = _UI_GB_13_SCENE.instantiate() as Node2D
		var ui_gb_14: Node2D = _UI_GB_14_SCENE.instantiate() as Node2D
		grid_layer.add_child(ui_gb_12)
		grid_layer.add_child(ui_gb_13)
		grid_layer.add_child(ui_gb_14)
		_grid_layer_overlays[&"UI-GB-12"] = ui_gb_12
		_grid_layer_overlays[&"UI-GB-13"] = ui_gb_13
		_grid_layer_overlays[&"UI-GB-14"] = ui_gb_14

	# Instantiate two-tap timer — shared for ATTACK + DEFEND flows.
	_two_tap_timer = Timer.new()
	_two_tap_timer.one_shot = true
	_two_tap_timer.wait_time = TWO_TAP_TIMEOUT_S
	add_child(_two_tap_timer)
	# CONNECT_DEFERRED per ADR-0001 §5 uniformity; Timer.timeout is traditionally
	# non-deferred safe but project discipline mandates consistent CONNECT_DEFERRED.
	_two_tap_timer.timeout.connect(_on_two_tap_timeout, Object.CONNECT_DEFERRED)

	# Set action button labels via tr() per i18n discipline.
	_refresh_action_button_labels()


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

	# Story-005: disconnect two-tap timer + button click signals.
	# queue_free of self auto-disconnects these, but explicit disconnect per
	# 4-precedent exit_tree_disconnect discipline (battle_hud_missing_exit_tree_disconnect
	# forbidden_pattern mandates ≥11 explicit disconnects; these add to that count).
	if is_instance_valid(_two_tap_timer):
		if _two_tap_timer.timeout.is_connected(_on_two_tap_timeout):
			_two_tap_timer.timeout.disconnect(_on_two_tap_timeout)
	if is_instance_valid(_btn_move) and _btn_move.pressed.is_connected(_on_move_button_pressed):
		_btn_move.pressed.disconnect(_on_move_button_pressed)
	if is_instance_valid(_btn_attack) and _btn_attack.pressed.is_connected(_on_attack_button_pressed):
		_btn_attack.pressed.disconnect(_on_attack_button_pressed)
	if is_instance_valid(_btn_use_skill) and _btn_use_skill.pressed.is_connected(_on_use_skill_button_pressed):
		_btn_use_skill.pressed.disconnect(_on_use_skill_button_pressed)
	if is_instance_valid(_btn_defend) and _btn_defend.pressed.is_connected(_on_defend_button_pressed):
		_btn_defend.pressed.disconnect(_on_defend_button_pressed)
	if is_instance_valid(_btn_wait) and _btn_wait.pressed.is_connected(_on_wait_button_pressed):
		_btn_wait.pressed.disconnect(_on_wait_button_pressed)
	if is_instance_valid(_btn_end_turn) and _btn_end_turn.pressed.is_connected(_on_end_turn_button_pressed):
		_btn_end_turn.pressed.disconnect(_on_end_turn_button_pressed)
	if is_instance_valid(_btn_undo) and _btn_undo.pressed.is_connected(_on_undo_button_pressed):
		_btn_undo.pressed.disconnect(_on_undo_button_pressed)
	if is_instance_valid(_btn_skill_slot_0):
		var callable_s0: Callable = _on_skill_slot_pressed.bind(0)
		if _btn_skill_slot_0.pressed.is_connected(callable_s0):
			_btn_skill_slot_0.pressed.disconnect(callable_s0)
	if is_instance_valid(_btn_skill_slot_1):
		var callable_s1: Callable = _on_skill_slot_pressed.bind(1)
		if _btn_skill_slot_1.pressed.is_connected(callable_s1):
			_btn_skill_slot_1.pressed.disconnect(callable_s1)

	# Story-006: kill active forecast dismiss Tween to prevent post-free callback.
	# Tween auto-frees in Godot 4.6 but kill() prevents any pending callbacks
	# from firing after _exit_tree() completes.
	if _forecast_dismiss_tween != null:
		_forecast_dismiss_tween.kill()
		_forecast_dismiss_tween = null

	# Story-007: free cross-tree grid-layer overlays. Cross-tree children (mounted
	# under BattleScene/GridLayer) are NOT auto-freed when BattleHUD frees, since
	# they live in a different branch of the scene tree. Defensive is_instance_valid
	# guards per G-11 cast-on-freed precedent; queue_free() defers to end-of-frame.
	for overlay_key: StringName in _grid_layer_overlays.keys():
		var overlay: Node2D = _grid_layer_overlays[overlay_key]
		if is_instance_valid(overlay) and not overlay.is_queued_for_deletion():
			overlay.queue_free()
	_grid_layer_overlays.clear()


# ─── Public methods ───────────────────────────────────────────────────────────

## set_victory_condition() — story-004 (S7-09). Called by BattleScene at battle init
## per ADR-0016 §step 6 mount sequence. Sets UI-GB-08 ConditionLabel.text + makes
## the panel visible. Repeated calls replace the text. No "hide" path within MVP —
## condition stays visible until BattleScene tears down.
##
## condition_text: StringName — i18n key (e.g., &"victory.scenario_01.defeat_commander").
## Resolved by tr() at render time; if no locale entry, the key itself is used.
func set_victory_condition(condition_text: StringName) -> void:
	var panel: Control = _ui_elements.get(&"UI-GB-08")
	if panel == null:
		return
	var label: Label = panel.get_node_or_null("ConditionLabel") as Label
	if label != null:
		label.text = tr(String(condition_text))
	panel.visible = true


## show_forecast() — story-006 (S10-01). Renders UI-GB-04 Combat Forecast for
## the attacker→defender pair. Populates 6 subpanels (Direction, Hit/Crit,
## Damage, Counter, Status, Passives) within FORECAST_RENDER_BUDGET_MS = 120
## per ADR-0015 §5 + battle-hud.md §4 Combat Forecast Full Spec.
##
## Idempotent: if already visible, replaces content for the new pair. If a
## dismiss Tween is in flight, kills it before showing (prevents fade conflict).
##
## Render-time instrumentation per TR-battle-hud-014: spans method entry →
## _forecast_root.visible = true via Time.get_ticks_usec() delta. Recorded into
## _forecast_render_ms_last for AC-9 perf gate test observability.
##
## Backend query path (story-006):
##   1. _grid_controller.get_battle_unit(attacker_id / defender_id) → BattleUnit
##   2. _hp_controller.get_status_effects(defender_id) → Array[StatusEffect]
##   3. DamageCalc.* helpers — DEFENSIVE: queries are Variant-typed and
##      typeof-checked; if API surface gaps surface, sections fall through to
##      placeholder i18n keys. Real DamageCalc API integration is incremental
##      across stories 006/007 — this story prioritizes the architectural
##      contract (visibility + render budget + dismiss latency) over forecast
##      content fidelity. Passive precedence Rally > Formation > TR per
##      battle-hud.md §4.1 Section 6 capped at 3 visible lines.
func show_forecast(attacker_id: int, defender_id: int) -> void:
	if _forecast_root == null:
		return
	var start_us: int = Time.get_ticks_usec()
	# Kill any in-flight dismiss tween + reset alpha for clean reuse.
	if _forecast_dismiss_tween != null:
		_forecast_dismiss_tween.kill()
		_forecast_dismiss_tween = null
	_forecast_root.modulate.a = 1.0
	# Populate 6 subpanels via tr()-routed labels. Each subpanel gets a single
	# Label child by convention (or HBoxContainer for damage chevrons +
	# status_effects icons). We set tooltip_text for AccessKit per ADR-0015
	# Verification §2.
	_populate_forecast_section(&"direction", attacker_id, defender_id)
	_populate_forecast_section(&"hit_crit", attacker_id, defender_id)
	_populate_forecast_section(&"damage", attacker_id, defender_id)
	_populate_forecast_section(&"counter", attacker_id, defender_id)
	_populate_forecast_section(&"status_effects", attacker_id, defender_id)
	_populate_forecast_section(&"passives", attacker_id, defender_id)
	# Mark visible AFTER population so render-time delta captures the full work.
	_forecast_root.visible = true
	_forecast_show_us = Time.get_ticks_usec()
	_forecast_render_ms_last = float(_forecast_show_us - start_us) / 1000.0


## _populate_forecast_section — populates a single named subpanel.
## Uses defensive Label/RichTextLabel discovery: any child with a `text`
## property is treated as the content sink. Unknown sections fall through
## to a generic tr() placeholder. i18n keys per Implementation Note 4.
func _populate_forecast_section(section: StringName, attacker_id: int, defender_id: int) -> void:
	var subpanel: Control = _forecast_subpanels.get(section)
	if subpanel == null:
		return
	var label: Label = subpanel.get_node_or_null("Label") as Label
	if label == null:
		# Fallback: first Label descendant (defensive against .tscn structure drift).
		for child: Node in subpanel.get_children():
			if child is Label:
				label = child as Label
				break
	if label == null:
		return
	# Section-specific content. Real DamageCalc/HPStatus integration deferred
	# to story-007 contract — story-006 ships the architectural contract.
	match section:
		&"direction":
			label.text = tr(&"hud.forecast.direction.north")
			subpanel.tooltip_text = tr(&"hud.forecast.direction.north")
		&"hit_crit":
			label.text = _safe_tr_format(&"hud.forecast.hit_label", 85)
			subpanel.tooltip_text = _safe_tr_format(&"hud.forecast.hit_label", 85)
		&"damage":
			label.text = _safe_tr_format(&"hud.forecast.damage_label", [12, 18])
			subpanel.tooltip_text = _safe_tr_format(&"hud.forecast.damage_label", [12, 18])
		&"counter":
			# Counter-attack preview: em-dash placeholder if defender lacks counter.
			# DamageCalc integration deferred per Implementation Note. Em-dash
			# hoisted to const to keep Lint 5 (no_hardcoded_strings) clean —
			# Unicode punctuation placeholder is locale-independent (story-008).
			label.text = _COUNTER_PLACEHOLDER_DASH
			subpanel.tooltip_text = _safe_tr_format(&"hud.forecast.counter_label", _COUNTER_PLACEHOLDER_DASH)
		&"status_effects":
			label.text = tr(&"hud.forecast.status_label")
			subpanel.tooltip_text = tr(&"hud.forecast.status_label")
		&"passives":
			# Section 6 passives list — Rally > Formation > TR precedence per
			# Implementation Note 4. Cap at 3 visible lines. Story-006 ships
			# placeholder rendering; real bonus query integration in story-007.
			var passives: Array[StringName] = _collect_forecast_passives(attacker_id, defender_id)
			var lines: PackedStringArray = []
			var visible_cap: int = mini(passives.size(), 3)
			for i in range(visible_cap):
				lines.append(tr(passives[i]))
			label.text = "\n".join(lines) if lines.size() > 0 else ""
			subpanel.tooltip_text = tr(&"hud.forecast.passives_label")


## _collect_forecast_passives — returns ordered i18n keys per precedence
## Rally > Formation > TR > others. Story-006 ships empty default; story-007
## populates from real GridBattleController formation_bonuses + UnitRole
## passive tags per Implementation Note 4.
func _collect_forecast_passives(_attacker_id: int, _defender_id: int) -> Array[StringName]:
	var result: Array[StringName] = []
	# Defensive: if grid_controller exposes a future passive-collection API,
	# call it here and append in precedence order. For now return empty.
	return result


## _dismiss_forecast() — story-006 (S10-01). Idempotent fade-out of UI-GB-04.
## Tween from modulate.a 1.0 → 0.0 over 0.08 seconds (target 80ms wall-clock
## per AC-UX-HUD-02 + TR-battle-hud-008). On Tween.finished:
## sets visible = false + records dismiss latency for test fixture.
##
## Reason argument is informational (recorded for diagnostic logs at debug-
## build time; no production behaviour branches on reason).
##
## Per ADR-0015 advisory B-4: instrumentation uses Time.get_ticks_usec()
## start/end delta, NOT Performance.TIME_PROCESS — the dismiss span is
## event-receipt → Tween.finished, which spans multiple frames; TIME_PROCESS
## returns single-frame _process duration which would underreport.
func _dismiss_forecast(_reason: StringName) -> void:
	if _forecast_root == null or not _forecast_root.visible:
		return
	# Kill any prior dismiss tween before starting a new one.
	if _forecast_dismiss_tween != null:
		_forecast_dismiss_tween.kill()
		_forecast_dismiss_tween = null
	_forecast_dismiss_start_us = Time.get_ticks_usec()
	_forecast_dismiss_tween = create_tween()
	_forecast_dismiss_tween.tween_property(_forecast_root, "modulate:a", 0.0, 0.08)
	_forecast_dismiss_tween.finished.connect(_on_forecast_dismiss_finished, CONNECT_ONE_SHOT)


## _on_forecast_dismiss_finished — Tween.finished callback.
## Hides the forecast panel + resets modulate alpha for next show_forecast()
## call + records dismiss latency for AC-3 perf assertion observability.
func _on_forecast_dismiss_finished() -> void:
	if _forecast_root != null:
		_forecast_root.visible = false
		_forecast_root.modulate.a = 1.0
	_forecast_dismiss_ms_last = float(Time.get_ticks_usec() - _forecast_dismiss_start_us) / 1000.0
	_forecast_dismiss_tween = null


## show_unit_info() — InputRouter Touch Tap Preview Protocol (CR-4a).
##
## Renders UI-GB-03 unit info panel for unit_id. Called by InputRouter on touch
## tap-preview (CR-4a). PC mouse hover routes through the same path.
## If unit_id == -1, dismisses the panel.
##
## Backend query path (story-003):
##   1. _grid_controller.get_battle_unit(unit_id) → BattleUnit (cross-epic
##      forward-prep added in story-003 to support hero_id resolution).
##   2. HeroDatabase.get_hero(battle_unit.hero_id) → HeroData (static; takes
##      StringName). Falls back to localized "unknown" placeholder if null.
##   3. _hp_controller.get_current_hp / get_max_hp / get_status_effects(unit_id)
##      → int / int / Array[StatusEffect].
##   4. Iterate status_effects Array; populate StatusEffectsHBox with TextureRect
##      icons; trigger UI-GB-11 DEFEND seal visibility on `defend_stance` entry.
func show_unit_info(unit_id: int) -> void:
	var panel: Control = _ui_elements.get(&"UI-GB-03")
	if unit_id == -1:
		if panel != null:
			panel.visible = false
		_set_defend_seal_visible(false)
		_active_status_panel_unit_id = -1
		return

	var battle_unit: BattleUnit = _grid_controller.get_battle_unit(unit_id)
	if battle_unit == null:
		push_warning("BattleHUD.show_unit_info: no BattleUnit for unit_id=%d" % unit_id)
		return

	var hero_data: HeroData = HeroDatabase.get_hero(battle_unit.hero_id)
	var unit_name_text: String
	if hero_data == null:
		unit_name_text = tr(&"hud.unit_info.unknown_unit")
	else:
		unit_name_text = hero_data.name_ko

	var current_hp: int = _hp_controller.get_current_hp(unit_id)
	var max_hp: int = _hp_controller.get_max_hp(unit_id)
	var status_effects: Array = _hp_controller.get_status_effects(unit_id)

	if panel != null:
		var name_label: Label = panel.get_node_or_null(^"UnitNameLabel") as Label
		if name_label != null:
			name_label.text = unit_name_text
		var class_label: Label = panel.get_node_or_null(^"ClassLabel") as Label
		if class_label != null:
			class_label.text = "%s: %s" % [
				tr(&"hud.unit_info.class_label"),
				tr(_class_to_i18n_key(battle_unit.unit_class)),
			]
		var hp_bar: TextureProgressBar = panel.get_node_or_null(^"HPBar") as TextureProgressBar
		if hp_bar != null:
			hp_bar.max_value = float(max_hp)
			hp_bar.value = float(current_hp)
		var atk_label: Label = panel.get_node_or_null(^"ATKLabel") as Label
		if atk_label != null:
			atk_label.text = "%s %d" % [tr(&"hud.unit_info.atk_label"), battle_unit.raw_atk]
		var def_label: Label = panel.get_node_or_null(^"DEFLabel") as Label
		if def_label != null:
			def_label.text = "%s %d" % [tr(&"hud.unit_info.def_label"), battle_unit.raw_def]
		var effects_box: HBoxContainer = panel.get_node_or_null(^"StatusEffectsHBox") as HBoxContainer
		var has_defend_stance: bool = false
		if effects_box != null:
			has_defend_stance = _populate_status_effects_box(effects_box, status_effects)
		var facing_label: Label = panel.get_node_or_null(^"FacingDirectionLabel") as Label
		if facing_label != null:
			facing_label.text = "%s: %s" % [
				tr(&"hud.unit_info.facing_label"),
				tr(_facing_to_i18n_key(battle_unit.facing)),
			]
		_set_defend_seal_visible(has_defend_stance)
		panel.visible = true
	_active_status_panel_unit_id = unit_id


## _set_defend_seal_visible() — UI-GB-11 visibility toggle.
##
## World-space tile positioning deferred to story-007 (no GridBattleController
## .get_unit_world_position() or MapGrid.coord_to_world() exposed yet). MVP:
## seal renders at fixed HUD-level position; story-007 migrates to GridLayer
## cross-tree per ADR-0015 §2 + ADR-0016 §2.
func _set_defend_seal_visible(visible_state: bool) -> void:
	var seal: Control = _ui_elements.get(&"UI-GB-11")
	if seal != null:
		seal.visible = visible_state


## _rebuild_initiative_queue() — story-004 (S7-09).
##
## Pull-based UI-GB-01 rebuild from `_turn_runner.get_turn_order_snapshot()`.
## Populates first 8 slots from snapshot.queue; hides remainder. Allocation-free
## steady state per Guardrail (Texture refs swap, no Node instantiation).
##
## Called by _on_round_started + _on_unit_died. The signal is a "queue may have
## changed — re-read" tap, NOT a state delivery (per story-004 Implementation Note 1).
func _rebuild_initiative_queue() -> void:
	if _turn_runner == null or _ui_gb_01_slots.is_empty():
		return
	var snap: TurnOrderSnapshot = _turn_runner.get_turn_order_snapshot()
	if snap == null:
		return
	var n: int = mini(8, snap.queue.size())
	for i: int in range(8):
		var slot: Control = _ui_gb_01_slots[i]
		if i < n:
			var entry: TurnOrderEntry = snap.queue[i]
			_ui_gb_01_slot_unit_ids[i] = entry.unit_id
			var name_label: Label = slot.get_node_or_null("NameLabel") as Label
			if name_label != null:
				var hero_name: String = "U%d" % entry.unit_id
				if _hero_db != null and _grid_controller != null:
					var battle_unit: BattleUnit = _grid_controller.get_battle_unit(entry.unit_id)
					if battle_unit != null:
						var hero: HeroData = HeroDatabase.get_hero(battle_unit.hero_id)
						if hero != null and hero.name_ko != "":
							hero_name = hero.name_ko
				name_label.text = hero_name
			slot.tooltip_text = "Upcoming: %s" % (name_label.text if name_label != null else "U%d" % entry.unit_id)
			slot.visible = true
		else:
			_ui_gb_01_slot_unit_ids[i] = -1
			slot.visible = false
	# Clear stale highlight if active unit no longer in queue.
	if _ui_gb_01_active_slot_index >= 0 and _ui_gb_01_active_slot_index < n:
		_set_initiative_queue_slot_modulate(_ui_gb_01_active_slot_index, true)
	else:
		_ui_gb_01_active_slot_index = -1


## _set_initiative_queue_highlight() — story-004 (S7-09).
##
## Find the slot whose unit_id matches + apply visual highlight (modulate.a boost).
## If unit_id NOT in queue, clear active slot index (visual no-op).
func _set_initiative_queue_highlight(unit_id: int) -> void:
	# Clear any prior highlight first.
	if _ui_gb_01_active_slot_index >= 0:
		_set_initiative_queue_slot_modulate(_ui_gb_01_active_slot_index, false)
	_ui_gb_01_active_slot_index = -1
	for i: int in range(_ui_gb_01_slot_unit_ids.size()):
		if _ui_gb_01_slot_unit_ids[i] == unit_id:
			_ui_gb_01_active_slot_index = i
			_set_initiative_queue_slot_modulate(i, true)
			return


## _clear_initiative_queue_highlight() — story-004 (S7-09).
func _clear_initiative_queue_highlight() -> void:
	if _ui_gb_01_active_slot_index >= 0:
		_set_initiative_queue_slot_modulate(_ui_gb_01_active_slot_index, false)
	_ui_gb_01_active_slot_index = -1


## _set_initiative_queue_slot_modulate() — story-004 (S7-09) visual highlight impl.
## Implementation choice per Implementation Note 3: modulate.a boost
## (1.0 default → 1.2 when highlighted). Art-director sign-off per epic R-6.
func _set_initiative_queue_slot_modulate(slot_index: int, highlighted: bool) -> void:
	if slot_index < 0 or slot_index >= _ui_gb_01_slots.size():
		return
	var slot: Control = _ui_gb_01_slots[slot_index]
	if slot == null:
		return
	slot.modulate.a = 1.2 if highlighted else 1.0


## _populate_status_effects_box() — clears + repopulates UI-GB-03 status icons.
##
## Returns true if any effect in `status_effects` is `defend_stance` (used by
## show_unit_info caller to drive UI-GB-11 seal visibility). Each icon's
## tooltip_text routes through `tr()` with a literal-key dispatch via
## `_status_effect_to_i18n_key` so Godot POT extraction can statically detect
## every locale key.
func _populate_status_effects_box(effects_box: HBoxContainer, status_effects: Array) -> bool:
	for child: Node in effects_box.get_children():
		child.queue_free()
	var has_defend_stance: bool = false
	for effect: StatusEffect in status_effects:
		var icon: TextureRect = TextureRect.new()
		icon.tooltip_text = tr(_status_effect_to_i18n_key(effect.effect_id))
		icon.custom_minimum_size = Vector2(44.0, 44.0)
		effects_box.add_child(icon)
		if effect.effect_id == &"defend_stance":
			has_defend_stance = true
	return has_defend_stance


## _class_to_i18n_key() — UnitRole.UnitClass enum int → literal locale key StringName.
##
## Literal-StringName dispatch (NOT runtime concatenation) so Godot's POT
## extractor + future i18n tooling can statically detect every locale key. Mirrors
## UnitRole._class_to_key (private static) lowercase JSON keys; en.po declares all 6.
func _class_to_i18n_key(unit_class: int) -> StringName:
	match unit_class:
		0: return &"hud.unit_info.class.cavalry"
		1: return &"hud.unit_info.class.infantry"
		2: return &"hud.unit_info.class.archer"
		3: return &"hud.unit_info.class.strategist"
		4: return &"hud.unit_info.class.commander"
		5: return &"hud.unit_info.class.scout"
		_: return &"hud.unit_info.unknown_unit"


## _facing_to_i18n_key() — BattleUnit.facing int → literal locale key StringName.
##
## Same literal-dispatch pattern as _class_to_i18n_key. BattleUnit.facing per
## ADR-0014 §3 + grid_battle_controller._direction_from_to: 0=N / 1=E / 2=S / 3=W.
func _facing_to_i18n_key(facing: int) -> StringName:
	match facing:
		0: return &"hud.unit_info.facing.n"
		1: return &"hud.unit_info.facing.e"
		2: return &"hud.unit_info.facing.s"
		3: return &"hud.unit_info.facing.w"
		_: return &"hud.unit_info.unknown_unit"


## _status_effect_to_i18n_key() — StatusEffect.effect_id → literal locale key StringName.
##
## Replaces the prior `tr("hud.status." + String(effect.effect_id))` runtime-
## concatenated key (i18n extraction blind spot). MVP scope: only defend_stance
## ships in story-003; future status effects (e.g., demoralized, charge_active)
## land here as match arms + en.po entries when their owning stories implement.
func _status_effect_to_i18n_key(effect_id: StringName) -> StringName:
	match effect_id:
		&"defend_stance": return &"hud.status.defend_stance"
		_: return &"hud.status.unknown"


## show_tile_info() — InputRouter Touch Tap Preview Protocol (CR-4a).
##
## Renders UI-GB-06 tile info tooltip for coord. Called by InputRouter on touch
## tap-preview (CR-4a) or PC mouse hover on empty tile.
## If coord == Vector2i(-1, -1), dismisses the tooltip.
##
## Backend query path (story-007):
##   1. _map_grid.get_tile(coord) → MapTileData (terrain_type + elevation)
##   2. TerrainEffect.get_terrain_modifiers(_map_grid, coord) → TerrainModifiers
##      (defense_bonus + evasion_bonus)
##   3. Position derived in screen-space: tile_size from BalanceConstants
##      TILE_WORLD_SIZE; world_pos = Vector2(coord) * tile_size; screen_pos =
##      _camera.get_canvas_transform() * world_pos per godot-specialist 2026-05-03
##      advisory D (Camera2D in 4.6 has no world_to_screen() method).
##
## Defensive: if get_tile returns null, log warning + dismiss panel.
func show_tile_info(coord: Vector2i) -> void:
	var panel: PanelContainer = _ui_elements.get(&"UI-GB-06") as PanelContainer
	if panel == null:
		return
	if coord == Vector2i(-1, -1):
		panel.visible = false
		return
	if _map_grid == null:
		push_warning("BattleHUD.show_tile_info: _map_grid null; cannot resolve tile data")
		panel.visible = false
		return
	var tile: MapTileData = _map_grid.get_tile(coord)
	if tile == null:
		push_warning("BattleHUD.show_tile_info: no MapTileData for coord %s" % str(coord))
		panel.visible = false
		return
	# Populate 4 Labels via tr()-routed format strings per i18n discipline.
	var vbox: VBoxContainer = panel.get_node_or_null(^"VBoxContainer") as VBoxContainer
	if vbox != null:
		var terrain_lbl: Label = vbox.get_node_or_null(^"TerrainLabel") as Label
		if terrain_lbl != null:
			terrain_lbl.text = "%s: %d" % [tr(&"hud.tile.terrain_label"), tile.terrain_type]
		var elev_lbl: Label = vbox.get_node_or_null(^"ElevationLabel") as Label
		if elev_lbl != null:
			elev_lbl.text = "%s: %d" % [tr(&"hud.tile.elevation_label"), tile.elevation]
		# defense/evasion query through TerrainEffect static helper.
		var modifiers: TerrainModifiers = TerrainEffect.get_terrain_modifiers(_map_grid, coord)
		var def_bonus: int = modifiers.defense_bonus if modifiers != null else 0
		var eva_bonus: int = modifiers.evasion_bonus if modifiers != null else 0
		var def_lbl: Label = vbox.get_node_or_null(^"DefenseLabel") as Label
		if def_lbl != null:
			def_lbl.text = tr(&"hud.tile.defense_label") % def_bonus
		var eva_lbl: Label = vbox.get_node_or_null(^"EvasionLabel") as Label
		if eva_lbl != null:
			eva_lbl.text = tr(&"hud.tile.evasion_label") % eva_bonus
	# Position the panel in screen-space using BattleCamera canvas transform.
	# tile_size derived from BalanceConstants.TILE_WORLD_SIZE per established
	# BattleCamera precedent (battle_camera.gd:78). Per godot-specialist advisory D:
	# use get_canvas_transform() directly — no Camera2D.world_to_screen() in 4.6.
	if _camera != null:
		var tile_size: float = float(BalanceConstants.get_const(&"TILE_WORLD_SIZE"))
		var world_pos: Vector2 = Vector2(float(coord.x) * tile_size, float(coord.y) * tile_size)
		var screen_pos: Vector2 = _camera.get_canvas_transform() * world_pos
		# Small offset so the tooltip doesn't overlap the cursor's tile.
		panel.position = screen_pos + Vector2(8.0, 8.0)
	panel.visible = true


# ─── Private methods ──────────────────────────────────────────────────────────

## _is_active_turn_unit() — story-005. Returns true if unit_id is the unit whose
## turn is currently active per TurnOrderRunner snapshot (first entry in queue).
##
## Used by _on_unit_selected_changed to gate UI-GB-02 visibility — action menu shows
## only for the active player unit.
##
## Defensive fallback: returns true if _turn_runner is null OR snapshot has no queue
## entries (permissive — better to over-show the action menu than block legitimate input).
## Queue entries are TurnOrderEntry RefCounted objects with .unit_id property
## per TurnOrderSnapshot / TurnOrderEntry shape (ADR-0011).
func _is_active_turn_unit(unit_id: int) -> bool:
	if _turn_runner == null:
		return true  # permissive fallback
	var snap: TurnOrderSnapshot = _turn_runner.get_turn_order_snapshot()
	if snap == null or snap.queue.is_empty():
		return true  # permissive fallback
	var first: TurnOrderEntry = snap.queue[0]
	return first.unit_id == unit_id


## _refresh_action_button_labels() — story-005. Sets visible text on the 6 action
## menu buttons + skill slot buttons + undo button via tr() per ADR-0015
## forbidden_pattern battle_hud_hardcoded_localized_strings.
## Called once in _ready() after button caching completes.
func _refresh_action_button_labels() -> void:
	if _btn_move != null: _btn_move.text = tr(&"hud.action.move")
	if _btn_attack != null: _btn_attack.text = tr(&"hud.action.attack")
	if _btn_use_skill != null: _btn_use_skill.text = tr(&"hud.action.use_skill")
	if _btn_defend != null: _btn_defend.text = tr(&"hud.action.defend")
	if _btn_wait != null: _btn_wait.text = tr(&"hud.action.wait")
	if _btn_end_turn != null: _btn_end_turn.text = tr(&"hud.action.end_turn")
	if _btn_undo != null: _btn_undo.text = tr(&"hud.undo.label")


## _make_synthetic_action_event() — story-005. Factory: synthesizes an
## InputEventAction for cross-system event injection through
## _input_router._handle_event() per ADR-0015 §OQ-4 + non-emitter discipline.
## Per ADR-0015 R-5: HUD never emits GameBus signals; cross-system events flow
## back through InputRouter as synthetic events.
func _make_synthetic_action_event(action_name: StringName, pressed: bool = true) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action_name
	ev.pressed = pressed
	return ev


## _arm_two_tap() — story-005. Arms the two-tap window for ATTACK or DEFEND.
## Cancels any prior arm (idempotent: clears stale visual on different prior action),
## sets target, restarts timer, applies pending visual via Button.modulate.
func _arm_two_tap(action: StringName) -> void:
	_cancel_two_tap_arm()  # idempotent: clears stale visual on prior different action
	_two_tap_target_action = action
	if _two_tap_timer != null:
		_two_tap_timer.start()
	_apply_two_tap_pending_visual(action, true)


## _cancel_two_tap_arm() — story-005. Clears the pending two-tap arm + reverts
## visual. Idempotent — safe to call when nothing is armed.
func _cancel_two_tap_arm() -> void:
	if _two_tap_target_action == &"":
		return
	_apply_two_tap_pending_visual(_two_tap_target_action, false)
	_two_tap_target_action = &""
	if _two_tap_timer != null and not _two_tap_timer.is_stopped():
		_two_tap_timer.stop()


## _apply_two_tap_pending_visual() — story-005. Modulates the relevant Button to
## indicate pending two-tap state.
## pending=true: dim modulate (alpha 0.7) signals "tap again to confirm".
## pending=false: revert to default (Color.WHITE).
func _apply_two_tap_pending_visual(action: StringName, pending: bool) -> void:
	var target: Button = null
	match action:
		&"attack":
			target = _btn_attack
		&"defend":
			target = _btn_defend
	if target == null:
		return
	target.modulate = Color(1.0, 1.0, 1.0, 0.7) if pending else Color.WHITE

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
##
## Story-003 routing: was_selected != 0 → show_unit_info(unit_id) populates UI-GB-03;
## was_selected == 0 AND unit_id matches active panel → show_unit_info(-1) dismisses.
## All other was_selected == 0 cases ignored (only the active-panel unit triggers dismiss).
##
## Story-005 routing: if was_selected != 0, show UI-GB-02 ONLY when the selected unit
## is the currently active (turn-owner) unit from TurnOrderRunner snapshot. Defensive
## fallback: if snapshot unavailable, show UI-GB-02 for any selection.
## Hide UI-GB-02 + UI-GB-05 on deselect or inactive-unit selection.
func _on_unit_selected_changed(unit_id: int, was_selected: int) -> void:
	_handle_signal(&"unit_selected_changed", [unit_id, was_selected])
	if was_selected != 0:
		show_unit_info(unit_id)
		# Story-005: show action menu only for the active turn unit.
		var is_active_turn_unit: bool = _is_active_turn_unit(unit_id)
		if is_active_turn_unit:
			var action_menu: Control = _ui_elements.get(&"UI-GB-02")
			if action_menu != null:
				action_menu.visible = true
		else:
			# Inactive unit selected — show info panel only, not action menu.
			var action_menu: Control = _ui_elements.get(&"UI-GB-02")
			if action_menu != null:
				action_menu.visible = false
			var skill_panel: Control = _ui_elements.get(&"UI-GB-05")
			if skill_panel != null:
				skill_panel.visible = false
		# Story-007 AC-7: UI-GB-12 TR-extended range visibility for Strategist class.
		_update_tactical_read_overlay(unit_id)
	elif unit_id == _active_status_panel_unit_id:
		show_unit_info(-1)
		# Deselect — hide action menu + skill panel.
		var action_menu: Control = _ui_elements.get(&"UI-GB-02")
		if action_menu != null:
			action_menu.visible = false
		var skill_panel: Control = _ui_elements.get(&"UI-GB-05")
		if skill_panel != null:
			skill_panel.visible = false
		# Story-007 AC-7: hide UI-GB-12 on deselect.
		var tr_overlay: Node2D = _grid_layer_overlays.get(&"UI-GB-12")
		if tr_overlay != null:
			tr_overlay.visible = false


## _update_tactical_read_overlay — story-007 (S10-02). AC-7 visibility update.
## Renders UI-GB-12 only for Strategist class (Commander explicitly excluded per
## CR-2 v5.0 — Commander passive is passive_rally, not tactical_read).
##
## Story-007 ADVISORY: UnitRole.get_tactical_read_tiles() not yet exposed —
## defensive has_method() gate. When method lands, this handler will populate
## TR-extended tile children at 황토 70% opacity with 讀 micro-glyph per spec.
func _update_tactical_read_overlay(unit_id: int) -> void:
	var tr_overlay: Node2D = _grid_layer_overlays.get(&"UI-GB-12")
	if tr_overlay == null:
		return
	if _grid_controller == null:
		tr_overlay.visible = false
		return
	var battle_unit: BattleUnit = _grid_controller.get_battle_unit(unit_id)
	if battle_unit == null:
		tr_overlay.visible = false
		return
	var is_strategist: bool = battle_unit.unit_class == UnitRole.UnitClass.STRATEGIST
	if not is_strategist:
		tr_overlay.visible = false
		return
	# Strategist confirmed. Defensive: query TR-extended tiles only if API exposed.
	if _unit_role != null and _unit_role.has_method(&"get_tactical_read_tiles"):
		# Future render: position child Sprite2Ds at each TR-extended tile.
		# Story-007 ADVISORY: real rendering deferred; visibility flip ships now.
		tr_overlay.visible = true
	else:
		# API not yet exposed — hide overlay (matches MVP placeholder semantics).
		tr_overlay.visible = false


## _has_active_grid_overlay — story-007 (S10-02). Helper for _process gating.
## Returns true if any of UI-GB-12/13/14 is currently visible. Enables
## set_process(false) shortcut when no overlays active per godot-specialist
## revision #3 (avoid _process body when no rendering work needed).
func _has_active_grid_overlay() -> bool:
	for key: StringName in _grid_layer_overlays.keys():
		var overlay: Node2D = _grid_layer_overlays[key]
		if is_instance_valid(overlay) and overlay.visible:
			return true
	return false


## _process — story-007 (S10-02). Per-frame zoom-poll for grid overlay
## counter-scaling per AC-8 + Implementation Note 8. Gated on
## _has_active_grid_overlay() to avoid no-op work when no overlays active.
##
## Per-frame budget: ≤ 0.05 ms when active per TR-battle-hud-014; if breached,
## raise ADR-0013 amendment for camera_zoom_changed signal subscription.
##
## Story-007 ADVISORY: counter-scale rendering deferred — this body ships
## the gating contract; future story populates real per-overlay scale work.
func _process(_delta: float) -> void:
	if not _has_active_grid_overlay():
		return
	if _camera == null:
		return
	# Real counter-scale rendering deferred to post-MVP per AC-8 ADVISORY.
	var _zoom: float = _camera.get_zoom_value()


## _on_unit_moved — controller-LOCAL subscriber (GridBattleController).
## Story-005: shows UI-GB-10 Undo Indicator if this is the active player unit.
## GridBattleController.is_undo_available() API not yet shipped — permissive fallback
## (show undo for any move by the active unit; story-006 narrows logic).
func _on_unit_moved(unit_id: int, from: Vector2i, to: Vector2i) -> void:
	_handle_signal(&"unit_moved", [unit_id, from, to])
	# Story-005: show UI-GB-10 Undo Indicator if this is the active player unit.
	if _is_active_turn_unit(unit_id):
		var undo_indicator: Control = _ui_elements.get(&"UI-GB-10")
		if undo_indicator != null:
			# If grid_controller exposes is_undo_available, gate on it; else permissive.
			var should_show: bool = true
			if _grid_controller != null and _grid_controller.has_method("is_undo_available"):
				should_show = _grid_controller.is_undo_available(unit_id)
			undo_indicator.visible = should_show


## _on_damage_applied — controller-LOCAL subscriber (GridBattleController).
##
## Story-003 routing: if defender is the active panel unit, refresh HP bar value
## from _hp_controller.get_current_hp(). Partial refresh (HP bar only) — does
## NOT re-run full show_unit_info() to avoid status-effects HBox rebuild churn
## on every damage_applied frame.
func _on_damage_applied(attacker_id: int, defender_id: int, damage: int) -> void:
	_handle_signal(&"damage_applied", [attacker_id, defender_id, damage])
	# Story-006: force-dismiss UI-GB-04 forecast on damage apply per ADR-0015 §5.
	# Idempotent — _dismiss_forecast() early-returns if forecast not visible.
	_dismiss_forecast(&"damage_applied")
	if defender_id != _active_status_panel_unit_id:
		return
	var panel: Control = _ui_elements.get(&"UI-GB-03")
	if panel == null:
		return
	var hp_bar: TextureProgressBar = panel.get_node_or_null(^"HPBar") as TextureProgressBar
	if hp_bar != null:
		hp_bar.value = float(_hp_controller.get_current_hp(defender_id))


## _on_battle_outcome_resolved — controller-LOCAL subscriber (GridBattleController).
## outcome: StringName per ADR-0014 §8 line 95: `signal battle_outcome_resolved(outcome: StringName, fate_data: Dictionary)`.
## NOTE: GameBus.battle_outcome_resolved uses outcome: BattleOutcome (consumed by Scenario
## Progression per ADR-0015). This handler subscribes to the CONTROLLER-LOCAL signal.
func _on_battle_outcome_resolved(outcome: StringName, fate_data: Dictionary) -> void:
	_handle_signal(&"battle_outcome_resolved", [outcome, fate_data])
	# Story-007: render UI-GB-09 battle results screen with OUTCOME ONLY per
	# Pillar 2 lock (ADR-0015 §8). The fate_data dict carries per-condition
	# progress counters that MUST NOT be surfaced visually — Beat 7 reveal
	# happens in the post-battle scenario layer (design/gdd/destiny-branch.md
	# Section B). This handler reads ONLY the categorical `outcome` field.
	# Render-time instrumentation per AC-5 (≤ 200 ms one-shot per battle).
	# The `fate_data` parameter is intentionally unread by render code — passed
	# only to _handle_signal test seam above. Pillar 2 audit walks UI-GB-09
	# Label tree to verify no fate counter value bleeds into UI text. See
	# tests/integration/feature/battle_hud/battle_hud_overlays_test.gd.
	var start_us: int = Time.get_ticks_usec()
	var panel: PanelContainer = _ui_elements.get(&"UI-GB-09") as PanelContainer
	if panel == null:
		return
	var vbox: VBoxContainer = panel.get_node_or_null(^"VBoxContainer") as VBoxContainer
	if vbox == null:
		return
	# Outcome label — categorical mapping. Match StringName per ADR-0014 §8 line 95.
	var outcome_label: Label = vbox.get_node_or_null(^"OutcomeLabel") as Label
	if outcome_label != null:
		# StringNames match the values emitted by GridBattleController._emit_battle_outcome
		# (VICTORY_ANNIHILATION / DEFEAT_ANNIHILATION / TURN_LIMIT_REACHED). Earlier
		# lowercase &"victory"/&"defeat"/&"draw" arms never matched the actual emit
		# values, so every outcome silently fell through to the default — the label
		# always rendered "hud.outcome.draw" regardless of who won.
		var outcome_key: StringName = &"hud.outcome.draw"
		match outcome:
			&"VICTORY_ANNIHILATION": outcome_key = &"hud.outcome.victory"
			&"DEFEAT_ANNIHILATION":  outcome_key = &"hud.outcome.defeat"
			&"TURN_LIMIT_REACHED":   outcome_key = &"hud.outcome.draw"
		outcome_label.text = tr(outcome_key)
	# Surviving units count (categorical aggregate — NOT a fate counter).
	var surviving_count: int = 0
	if _hp_controller != null and _hp_controller.has_method("get_surviving_unit_count"):
		surviving_count = _hp_controller.get_surviving_unit_count()
	var surviving_label: Label = vbox.get_node_or_null(^"SurvivingUnitsLabel") as Label
	if surviving_label != null:
		surviving_label.text = _safe_tr_format(&"hud.results.surviving_units", surviving_count)
	# Turns elapsed (categorical aggregate — NOT a fate counter).
	var turns_elapsed: int = 0
	if _turn_runner != null and _turn_runner.has_method("get_round_count"):
		turns_elapsed = _turn_runner.get_round_count()
	var turns_label: Label = vbox.get_node_or_null(^"TurnsElapsedLabel") as Label
	if turns_label != null:
		turns_label.text = _safe_tr_format(&"hud.results.turns_elapsed", turns_elapsed)
	panel.visible = true
	_results_render_ms_last = float(Time.get_ticks_usec() - start_us) / 1000.0


## _on_unit_died — GameBus subscriber (emitter: HPStatusController).
##
## Story-003 routing: defensive clear of _active_status_panel_unit_id when the
## active panel unit dies (panel may already be hidden by other paths but this
## ensures the sentinel is reset even if dismissal didn't happen).
## Story-004 (S7-09): rebuild UI-GB-01 from fresh turn-order snapshot since the
## dead unit is removed from initiative queue.
func _on_unit_died(unit_id: int) -> void:
	_handle_signal(&"unit_died", [unit_id])
	if unit_id == _active_status_panel_unit_id:
		show_unit_info(-1)
	_rebuild_initiative_queue()


## _on_round_started — GameBus subscriber (emitter: TurnOrderRunner).
## Story-004 (S7-09): updates UI-GB-07 round_label + rebuilds UI-GB-01 from fresh snapshot.
func _on_round_started(round_number: int) -> void:
	_handle_signal(&"round_started", [round_number])
	# Story-006: force-dismiss UI-GB-04 forecast on new round per ADR-0015 §5.
	# Idempotent — _dismiss_forecast() early-returns if not visible.
	_dismiss_forecast(&"round_started")
	var counter: Control = _ui_elements.get(&"UI-GB-07")
	if counter != null:
		var round_label: Label = counter.get_node_or_null("RoundLabel") as Label
		if round_label != null:
			round_label.text = "Round %d" % round_number
	_rebuild_initiative_queue()


## _on_unit_turn_started — GameBus subscriber (emitter: TurnOrderRunner).
##
## Story-003 routing: if the panel is currently rendering this unit, re-invoke
## show_unit_info() to refresh status-effects HBox + DEFEND_STANCE seal expiry.
## Story-004 (S7-09): updates UI-GB-07 turn_label with active unit name + highlights
## the matching slot in UI-GB-01.
func _on_unit_turn_started(unit_id: int) -> void:
	_handle_signal(&"unit_turn_started", [unit_id])
	if unit_id == _active_status_panel_unit_id:
		show_unit_info(unit_id)
	# UI-GB-07 turn label
	var counter: Control = _ui_elements.get(&"UI-GB-07")
	if counter != null:
		var turn_label: Label = counter.get_node_or_null("TurnLabel") as Label
		if turn_label != null:
			var hero_name: String = "Unit %d" % unit_id
			if _hero_db != null:
				var battle_unit: BattleUnit = _grid_controller.get_battle_unit(unit_id) if _grid_controller != null else null
				if battle_unit != null:
					var hero: HeroData = HeroDatabase.get_hero(battle_unit.hero_id)
					if hero != null and hero.name_ko != "":
						hero_name = hero.name_ko
			turn_label.text = "Turn: %s" % hero_name
	# UI-GB-01 highlight
	_set_initiative_queue_highlight(unit_id)
	# Story-005: grey out spent-token actions on UI-GB-02 buttons.
	# If grid_controller doesn't expose is_action_available, fallback permissive (disabled=false).
	if _grid_controller != null and _grid_controller.has_method("is_action_available"):
		if _btn_move != null: _btn_move.disabled = not _grid_controller.is_action_available(unit_id, &"move")
		if _btn_attack != null: _btn_attack.disabled = not _grid_controller.is_action_available(unit_id, &"attack")
		if _btn_use_skill != null: _btn_use_skill.disabled = not _grid_controller.is_action_available(unit_id, &"use_skill")
		if _btn_defend != null: _btn_defend.disabled = not _grid_controller.is_action_available(unit_id, &"defend")
		if _btn_wait != null: _btn_wait.disabled = not _grid_controller.is_action_available(unit_id, &"wait")
		if _btn_end_turn != null: _btn_end_turn.disabled = not _grid_controller.is_action_available(unit_id, &"end_turn")


## _on_unit_turn_ended — GameBus subscriber (emitter: TurnOrderRunner).
## acted: bool — 2-param signature per GameBus line 32: `signal unit_turn_ended(unit_id: int, acted: bool)`.
## Story-004 (S7-09): clears UI-GB-01 highlight from the slot matching unit_id.
## Story-005: hides UI-GB-10 Undo Indicator (turn over → no undo possible).
##            Cancels any lingering two-tap arm at turn-end (defensive).
func _on_unit_turn_ended(unit_id: int, acted: bool) -> void:
	_handle_signal(&"unit_turn_ended", [unit_id, acted])
	if _ui_gb_01_active_slot_index >= 0 and _ui_gb_01_active_slot_index < _ui_gb_01_slot_unit_ids.size():
		if _ui_gb_01_slot_unit_ids[_ui_gb_01_active_slot_index] == unit_id:
			_clear_initiative_queue_highlight()
	# Story-005: hide UI-GB-10 Undo Indicator on turn end.
	var undo_indicator: Control = _ui_elements.get(&"UI-GB-10")
	if undo_indicator != null:
		undo_indicator.visible = false
	# Cancel any lingering two-tap arm at turn-end (defensive).
	_cancel_two_tap_arm()


## _on_input_state_changed — GameBus subscriber (emitter: InputRouter).
## AC-5: sets MOUSE_FILTER_IGNORE on root when transitioning TO S5 (INPUT_BLOCKED),
## reverts to MOUSE_FILTER_PASS when transitioning AWAY from S5.
## Godot 4.5+ recursive disable: setting IGNORE on root Control propagates to all children.
## Default is PASS (not STOP) so background clicks fall through to InputRouter
## via _unhandled_input — STOP would block all gameplay clicks (POLISH-011).
func _on_input_state_changed(from_state: int, to_state: int) -> void:
	_handle_signal(&"input_state_changed", [from_state, to_state])
	if to_state == InputRouter.InputState.INPUT_BLOCKED:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	elif from_state == InputRouter.InputState.INPUT_BLOCKED:
		mouse_filter = Control.MOUSE_FILTER_PASS


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
	# Story-007: update UI-GB-13 Rally aura + UI-GB-14 Formation aura per AC-6.
	# Visible-while-active semantics: overlay visible if at least one applicable
	# Commander/formation entry present in snapshot; hidden otherwise.
	# Story-007 ADVISORY: real opacity-tier rendering (20%/30%/40% per Commander
	# stack count for Rally; 청록 15% tint for Formation MVP-fallback) deferred —
	# this handler ships visibility toggle structural contract; rendering
	# children deferred per evidence-doc ADVISORY.
	var rally: Node2D = _grid_layer_overlays.get(&"UI-GB-13")
	var formation: Node2D = _grid_layer_overlays.get(&"UI-GB-14")
	if rally == null and formation == null:
		# Cross-tree GridLayer absent (graceful fallback per AC-1) — nothing to update.
		return
	# Rally visibility: derived from snapshot's Commander adjacency entries.
	# Snapshot schema TBD by GridBattleController amendment; defensive read.
	var has_rally: bool = false
	if snapshot.has(&"rally_active"):
		has_rally = bool(snapshot.get(&"rally_active", false))
	elif snapshot.has(&"commanders") and snapshot.get(&"commanders") is Array:
		var commanders: Array = snapshot.get(&"commanders", [])
		has_rally = commanders.size() > 0
	if rally != null:
		rally.visible = has_rally
	# Formation visibility: derived from snapshot's pattern-role entries.
	var has_formation: bool = false
	if snapshot.has(&"formation_active"):
		has_formation = bool(snapshot.get(&"formation_active", false))
	elif snapshot.has(&"pattern_roles") and snapshot.get(&"pattern_roles") is Array:
		var roles: Array = snapshot.get(&"pattern_roles", [])
		has_formation = roles.size() > 0
	if formation != null:
		formation.visible = has_formation


# ─── Story-005: Action button click handlers ──────────────────────────────────

## _on_move_button_pressed — story-005. MOVE: synthesize move_action event;
## dispatch through InputRouter. Cancels any pending two-tap arm.
func _on_move_button_pressed() -> void:
	_cancel_two_tap_arm()
	if _input_router != null:
		_input_router._handle_event(_make_synthetic_action_event(&"move_action"))


## _on_attack_button_pressed — story-005. ATTACK first/second tap per ADR-0015 §OQ-4.
## First tap arms the two-tap window; second tap within TWO_TAP_TIMEOUT_S confirms.
func _on_attack_button_pressed() -> void:
	if _two_tap_target_action == &"attack":
		# Second tap on the SAME armed action → confirm
		if _input_router != null:
			_input_router._handle_event(_make_synthetic_action_event(&"attack_confirm"))
		_cancel_two_tap_arm()
	else:
		# First tap (or different prior arm) → arm ATTACK
		_arm_two_tap(&"attack")


## _on_use_skill_button_pressed — story-005. USE_SKILL: reveals UI-GB-05 skill list.
## Cancels any pending two-tap arm.
func _on_use_skill_button_pressed() -> void:
	_cancel_two_tap_arm()
	var skill_panel: Control = _ui_elements.get(&"UI-GB-05")
	if skill_panel != null:
		skill_panel.visible = true


## _on_defend_button_pressed — story-005. DEFEND first/second tap per ADR-0015 §OQ-4.
## First tap arms the two-tap window; second tap within TWO_TAP_TIMEOUT_S confirms.
func _on_defend_button_pressed() -> void:
	if _two_tap_target_action == &"defend":
		# Second tap on the SAME armed action → confirm
		if _input_router != null:
			_input_router._handle_event(_make_synthetic_action_event(&"defend_confirm"))
		_cancel_two_tap_arm()
	else:
		# First tap (or different prior arm) → arm DEFEND
		_arm_two_tap(&"defend")


## _on_wait_button_pressed — story-005. WAIT: synthesize wait_action event.
## Cancels any pending two-tap arm.
func _on_wait_button_pressed() -> void:
	_cancel_two_tap_arm()
	if _input_router != null:
		_input_router._handle_event(_make_synthetic_action_event(&"wait_action"))


## _on_end_turn_button_pressed — story-005. END_TURN: synthesize end_turn_action event.
## Cancels any pending two-tap arm.
func _on_end_turn_button_pressed() -> void:
	_cancel_two_tap_arm()
	if _input_router != null:
		_input_router._handle_event(_make_synthetic_action_event(&"end_turn_action"))


## _on_undo_button_pressed — story-005. UNDO: synthesize undo_action event.
## No two-tap required for undo (single-tap confirmation per spec).
func _on_undo_button_pressed() -> void:
	if _input_router != null:
		_input_router._handle_event(_make_synthetic_action_event(&"undo_action"))


## _on_skill_slot_pressed — story-005. Skill slot clicked: synthesize skill_use_N event
## where N is the slot_index. Bound via .bind(slot_index) at _ready() time.
func _on_skill_slot_pressed(slot_index: int) -> void:
	var action: StringName = StringName("skill_use_%d" % slot_index)
	if _input_router != null:
		_input_router._handle_event(_make_synthetic_action_event(action))


## _on_two_tap_timeout — story-005. Timer.timeout handler — clears pending arm
## without firing confirm event. Per ADR-0015 §OQ-4 two-tap cancel path.
func _on_two_tap_timeout() -> void:
	_cancel_two_tap_arm()


## Safely formats a translatable string with positional args.
##
## Returns tr(key) % args when the translated string contains a format
## specifier (i.e., `%` character is present after translation — meaning
## the locale lookup actually happened). Otherwise returns a Korean-default
## fallback string for the key — defensive against the no-locale-loaded case
## where tr() returns the key itself, which has no `%d`/`%s` specifier and
## would runtime-error on % args.
##
## Discovered: S13-11 sprint-13 mid-amendment 2026-05-09 PM (Production VS bug
## #1 surfaced at headless boot of scenes/battle/battle_scene.tscn).
func _safe_tr_format(key: StringName, args: Variant) -> String:
	var translated: String = tr(key)
	# tr() returns the key itself when not in the loaded translation table.
	# Detect this via the absence of a `%` specifier in the translated string —
	# all of our format keys must contain `%d` / `%s` / `%v` in the locale file.
	if "%" in translated:
		# @warning_ignore("unsafe_cast") is not needed here: GDScript String.% operator
		# accepts Variant on the right-hand side at runtime. The static analyser does
		# not flag Variant % on String — the op is dynamically dispatched.
		return translated % args
	# Fallback: no locale loaded, or key missing from locale file.
	return _format_fallback(key, args)


## Hardcoded Korean fallback strings for the 5 known tr() % sites in this file.
## Match these strings to the locale file when keys are added to assets/locale/en.po.
##
## NOTE: this fallback ladder is intentionally exhaustive over the 5 known sites.
## Adding a new tr() %-using key MUST add a match arm here. When the project
## gains a registered locale + all 5 keys land in en.po + ko.po, this fallback
## can be removed (the `if "%" in translated` branch always succeeds).
func _format_fallback(key: StringName, args: Variant) -> String:
	match key:
		&"hud.results.surviving_units":
			return "%d 유닛 생존" % args
		&"hud.results.turns_elapsed":
			return "%d 턴 경과" % args
		&"hud.forecast.hit_label":
			return "명중 %d%%" % args
		&"hud.forecast.damage_label":
			return "%d–%d 피해" % args
		&"hud.forecast.counter_label":
			return "반격 %s" % args
		_:
			push_warning("BattleHUD._format_fallback: unknown key '%s' — returning translated key" % key)
			return tr(key)
