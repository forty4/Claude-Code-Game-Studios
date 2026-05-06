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
## Body implemented in story-007.
func show_tile_info(coord: Vector2i) -> void:
	pass


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
	elif unit_id == _active_status_panel_unit_id:
		show_unit_info(-1)
		# Deselect — hide action menu + skill panel.
		var action_menu: Control = _ui_elements.get(&"UI-GB-02")
		if action_menu != null:
			action_menu.visible = false
		var skill_panel: Control = _ui_elements.get(&"UI-GB-05")
		if skill_panel != null:
			skill_panel.visible = false


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
	# UI-GB-09 battle result overlay wired in story-006.


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
