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


## Preloaded UI element scenes (story-003 + story-004 + future stories add more).
const _UI_GB_03_SCENE: PackedScene = preload("res://scenes/battle/elements/ui_gb_03_unit_info_panel.tscn")
const _UI_GB_11_SCENE: PackedScene = preload("res://scenes/battle/elements/ui_gb_11_defend_stance_badge.tscn")
const _UI_GB_01_SCENE: PackedScene = preload("res://scenes/battle/elements/ui_gb_01_initiative_queue.tscn")
const _UI_GB_07_SCENE: PackedScene = preload("res://scenes/battle/elements/ui_gb_07_turn_round_counter.tscn")
const _UI_GB_08_SCENE: PackedScene = preload("res://scenes/battle/elements/ui_gb_08_victory_condition.tscn")


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
func _on_unit_selected_changed(unit_id: int, was_selected: int) -> void:
	_handle_signal(&"unit_selected_changed", [unit_id, was_selected])
	if was_selected != 0:
		show_unit_info(unit_id)
	elif unit_id == _active_status_panel_unit_id:
		show_unit_info(-1)


## _on_unit_moved — controller-LOCAL subscriber (GridBattleController).
func _on_unit_moved(unit_id: int, from: Vector2i, to: Vector2i) -> void:
	_handle_signal(&"unit_moved", [unit_id, from, to])
	# UI-GB-05 move animation trigger wired in story-004.


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


## _on_unit_turn_ended — GameBus subscriber (emitter: TurnOrderRunner).
## acted: bool — 2-param signature per GameBus line 32: `signal unit_turn_ended(unit_id: int, acted: bool)`.
## Story-004 (S7-09): clears UI-GB-01 highlight from the slot matching unit_id.
func _on_unit_turn_ended(unit_id: int, acted: bool) -> void:
	_handle_signal(&"unit_turn_ended", [unit_id, acted])
	if _ui_gb_01_active_slot_index >= 0 and _ui_gb_01_active_slot_index < _ui_gb_01_slot_unit_ids.size():
		if _ui_gb_01_slot_unit_ids[_ui_gb_01_active_slot_index] == unit_id:
			_clear_initiative_queue_highlight()


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
