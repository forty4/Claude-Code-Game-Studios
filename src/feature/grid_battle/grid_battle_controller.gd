## GridBattleController — central battle orchestrator for 천명역전 MVP First Chapter.
##
## Per ADR-0014 §1: 4th invocation of battle-scoped Node pattern (after ADR-0010
## HPStatusController + ADR-0011 TurnOrderRunner + ADR-0013 BattleCamera). Lives at
## BattleScene/GridBattleController. Freed with BattleScene exit. Not autoloaded.
##
## Class name `GridBattleController` — verified no Godot 4.6 ClassDB collision per
## ADR-0014 §1 (Battle / Grid / Controller are not Godot built-in class names).
##
## DI seam: BattleScene MUST call `setup(units, map_grid, camera, ...)` BEFORE
## `add_child()`. The `_ready()` body asserts all 7 deps non-null + units non-empty;
## without setup, the scene fails fast at mount time per ADR-0014 §3 + R-2 mitigation.
##
## MVP scope (per ADR-0014 §0): MOVE + ATTACK only; player-vs-script-bot;
## 5-turn limit; single chapter (장판파). AI integration, FormationBonusSystem,
## Rally, and USE_SKILL are explicitly deferred to future ADRs.
##
## MANDATORY `_exit_tree()` body explicitly disconnects all 4 signal subscriptions
## per ADR-0014 R-10 + ADR-0013 R-6 (camera_missing_exit_tree_disconnect forbidden_pattern
## extended to this ADR). GameBus is autoload — it outlives GridBattleController; without
## disconnect, autoload retains callables pointing at freed Node = leak + crash on next emit.
## HPStatusController + TurnOrderRunner are battle-scoped Nodes; null-guarded before disconnect.
##
## NOTE: GameBus.input_action_fired signal signature uses `String` (per ADR-0001 line 168 +
## battle_camera.gd NOTE block — `signal input_action_fired(action: String, context: InputContext)`).
## InputContext fields are `target_coord` / `target_unit_id` / `source_device` per
## src/core/payloads/input_context.gd (NOT `coord` / `unit_id` per ADR sketches).
##
## NOTE (signal routing — ADR-0014 §3 drift, verified at story-001 implementation 2026-05-02):
## ADR-0014 §3 architectural sketch shows `_hp_controller.unit_died.connect(...)` and
## `_turn_runner.unit_turn_started.connect(...)` / `.round_started.connect(...)` as INSTANCE
## signals. Production-shipped HPStatusController + TurnOrderRunner emit these via the
## GameBus autoload (per ADR-0010 §6 + ADR-0011 §Emitted signals + GameBus.gd lines 30/31/36).
## Therefore this controller subscribes to GameBus.X for all 4 signals (input_action_fired +
## unit_died + unit_turn_started + round_started) — uniform autoload subscription pattern.
## ADR-0014 §3 amended same-patch with "Implementation Notes" delta.

class_name GridBattleController
extends Node


# ─── Enums ───────────────────────────────────────────────────────────────────

## FSM — 2-state battle state machine per ADR-0014 §2 MVP scope.
## Full grid-battle.md GDD substates (AI_WAITING, AI_DECISION etc.) are deferred to
## the Battle AI ADR (sprint-7+).
enum BattleState {
	OBSERVATION,   ## No unit selected; click selects own unit
	UNIT_SELECTED, ## A unit is selected; click moves / attacks / deselects
}


# ─── Constants ───────────────────────────────────────────────────────────────

## The 10 grid-domain actions emitted by InputRouter that this controller filters
## per ADR-0014 §4 + input-handling GDD §93. Actions outside this list
## (camera_pan / camera_zoom_in / etc.) are silently ignored.
##
## Action semantics (MVP):
##  - unit_select: toggle unit selection (OBSERVATION→SELECTED on own unit; SELECTED→OBSERVATION on same)
##  - move_target_select / move_confirm: commit move action if tile is in move range
##  - move_cancel: deselect (return to OBSERVATION)
##  - attack_target_select / attack_confirm: commit attack action if tile is in attack range
##  - attack_cancel: deselect
##  - undo_last_move: MVP silent (post-MVP undo system)
##  - end_unit_turn: explicit player-turn-end button
##  - grid_hover: PC-only hover preview; silently ignored per CR-1c (touch parity)
const _GRID_ACTIONS: Array[String] = [
	"unit_select",
	"move_target_select",
	"move_confirm",
	"move_cancel",
	"attack_target_select",
	"attack_confirm",
	"attack_cancel",
	"undo_last_move",
	"end_unit_turn",
	"grid_hover",
]


# ─── Signals (Battle-domain per ADR-0014 §8) ────────────────────────────────

## Emitted when unit selection changes. was_selected == -1 for deselect.
signal unit_selected_changed(unit_id: int, was_selected: int)

## Emitted after a unit completes a move action.
signal unit_moved(unit_id: int, from: Vector2i, to: Vector2i)

## Emitted after HPStatusController.apply_damage resolves and returns.
signal damage_applied(attacker_id: int, defender_id: int, damage: int)

## Emitted when the battle is over. outcome is a StringName (e.g. &"TURN_LIMIT_REACHED").
## fate_data carries hidden fate condition snapshot per ADR-0014 §8.
signal battle_outcome_resolved(outcome: StringName, fate_data: Dictionary)

## Emitted silently for each fate-condition update. Destiny Branch ADR (sprint-6)
## is the SOLE subscriber — Battle HUD MUST NOT subscribe (preserves "hidden" semantic).
signal hidden_fate_condition_progressed(condition_id: StringName, value: int)


# ─── DI dependencies (ADR-0014 §3) ──────────────────────────────────────────

## Unit registry: unit_id → BattleUnit Resource. Populated by setup() from the Array.
var _units: Dictionary[int, BattleUnit] = {}

var _map_grid: MapGrid = null
var _camera: BattleCamera = null
var _hero_db: HeroDatabase = null      ## DI'd but static-method consumer; kept for future roster queries
var _turn_runner: TurnOrderRunner = null
var _hp_controller: HPStatusController = null
# NOTE: DamageCalc is NOT a DI dependency — its methods are `static func` (per
# src/feature/damage_calc/damage_calc.gd). Call as `DamageCalc.resolve(...)` directly.
# Tests that need to mock DamageCalc behavior use the existing damage-calc test
# fixture pattern (see tests/unit/feature/damage_calc/) — not DI through this controller.
var _terrain_effect: TerrainEffect = null
var _unit_role: UnitRole = null


# ─── FSM + per-turn state (ADR-0014 §2) ─────────────────────────────────────

var _state: BattleState = BattleState.OBSERVATION
var _selected_unit_id: int = -1

## unit_id → already-acted flag for this round.
var _acted_this_turn: Dictionary[int, bool] = {}

## ID of the last attacker — used by fate-counter (assassin kill attribution).
var _last_attacker_id: int = -1


# ─── Turn limit (ADR-0014 §3 / AC-4) ────────────────────────────────────────

## Derived from BalanceConstants at _ready(); never hardcoded.
var _max_turns: int = 0


# ─── Hidden fate-condition counters (ADR-0014 §2 / R-8) ─────────────────────

## unit_id of the 장비-tagged unit (tank). -1 if none found in roster.
var _fate_tank_unit_id: int = -1
## unit_id of the 조운-tagged unit (assassin). -1 if none found in roster.
var _fate_assassin_unit_id: int = -1
## unit_id of the boss-tagged enemy. -1 if none found in roster.
var _fate_boss_unit_id: int = -1
var _fate_rear_attacks: int = 0
var _fate_formation_turns: int = 0
var _fate_assassin_kills: int = 0
var _fate_boss_killed: bool = false


# ─── DI seam (BattleScene calls before add_child per ADR-0014 §3) ───────────

## Injects all 8 DI dependencies. MUST be called before add_child().
## DamageCalc is NOT a parameter — static-call site uses DamageCalc.resolve(...)
## directly per godot-specialist 2026-05-02 ADR-0014 review revision #2.
func setup(
		units: Array[BattleUnit],
		map_grid: MapGrid,
		camera: BattleCamera,
		hero_db: HeroDatabase,
		turn_runner: TurnOrderRunner,
		hp_controller: HPStatusController,
		terrain_effect: TerrainEffect,
		unit_role: UnitRole,
) -> void:
	for u: BattleUnit in units:
		_units[u.unit_id] = u
	_map_grid = map_grid
	_camera = camera
	_hero_db = hero_db
	_turn_runner = turn_runner
	_hp_controller = hp_controller
	_terrain_effect = terrain_effect
	_unit_role = unit_role
	# Tag-based fate-counter unit detection (per chapter-prototype pattern)
	_fate_tank_unit_id = _find_unit_by_tag(&"tank")
	_fate_assassin_unit_id = _find_unit_by_tag(&"assassin")
	_fate_boss_unit_id = _find_unit_by_tag(&"boss")


# ─── Lifecycle ───────────────────────────────────────────────────────────────

func _ready() -> void:
	# DI guard — fail fast if BattleScene forgot setup() per ADR-0014 R-2 mitigation
	assert(_units.size() > 0,
		"GridBattleController.setup() must be called before adding to scene tree — _units is empty")
	assert(_map_grid != null,
		"GridBattleController.setup() must be called before adding to scene tree — _map_grid is null")
	assert(_camera != null,
		"GridBattleController.setup() must be called before adding to scene tree — _camera is null")
	assert(_hero_db != null,
		"GridBattleController.setup() must be called before adding to scene tree — _hero_db is null")
	assert(_turn_runner != null,
		"GridBattleController.setup() must be called before adding to scene tree — _turn_runner is null")
	assert(_hp_controller != null,
		"GridBattleController.setup() must be called before adding to scene tree — _hp_controller is null")
	assert(_terrain_effect != null,
		"GridBattleController.setup() must be called before adding to scene tree — _terrain_effect is null")
	assert(_unit_role != null,
		"GridBattleController.setup() must be called before adding to scene tree — _unit_role is null")

	_max_turns = int(BalanceConstants.get_const("MAX_TURNS_PER_BATTLE"))

	# CRITICAL: CONNECT_DEFERRED on unit_died is NOT merely advisory — it is
	# load-bearing reentrance prevention. Without it, _on_unit_died could fire
	# synchronously inside HPStatusController.apply_damage() called from
	# _resolve_attack(), producing reentrant _check_battle_end() invocation
	# mid-resolve. Future maintainers MUST NOT remove the DEFERRED flag here.
	# (Per godot-specialist 2026-05-02 ADR-0014 review revision #1.)
	GameBus.input_action_fired.connect(_on_input_action_fired, Object.CONNECT_DEFERRED)
	GameBus.unit_died.connect(_on_unit_died, Object.CONNECT_DEFERRED)
	GameBus.unit_turn_started.connect(_on_unit_turn_started, Object.CONNECT_DEFERRED)
	GameBus.round_started.connect(_on_round_started, Object.CONNECT_DEFERRED)


func _exit_tree() -> void:
	# MANDATORY explicit disconnect per ADR-0014 R-10 + ADR-0013 R-6 +
	# camera_missing_exit_tree_disconnect forbidden_pattern extended to this ADR.
	# All 4 sources are GameBus autoload — autoload outlives this Node, so without
	# explicit disconnect the autoload retains callables pointing at freed Node =
	# leak + crash on next emit. All 4 disconnects unconditional.
	if GameBus.input_action_fired.is_connected(_on_input_action_fired):
		GameBus.input_action_fired.disconnect(_on_input_action_fired)
	if GameBus.unit_died.is_connected(_on_unit_died):
		GameBus.unit_died.disconnect(_on_unit_died)
	if GameBus.unit_turn_started.is_connected(_on_unit_turn_started):
		GameBus.unit_turn_started.disconnect(_on_unit_turn_started)
	if GameBus.round_started.is_connected(_on_round_started):
		GameBus.round_started.disconnect(_on_round_started)


# ─── Public API: cross-system contract surface (ADR-0014 §10) ────────────────

## Checks whether a tile is in the selected unit's movement range.
## Implements input-handling §9 Bidirectional Contract (R-5).
## TODO(story-004): replace stub with real BFS range check.
func is_tile_in_move_range(tile: Vector2i, unit_id: int) -> bool:
	# TODO(story-004): implement BFS + UnitRole.get_effective_move_range
	return false


## Checks whether a tile is in a unit's attack range.
## Implements input-handling §9 Bidirectional Contract (R-5).
## TODO(story-004): replace stub with real adjacency / 황충 range-2 check.
func is_tile_in_attack_range(tile: Vector2i, unit_id: int) -> bool:
	# TODO(story-004): implement adjacency + 황충 range-2 exception
	return false


## Returns the currently selected unit_id, or -1 if no unit is selected.
func get_selected_unit_id() -> int:
	return _selected_unit_id


## Returns an opaque snapshot of battle state for AI consumer (Battle AI ADR).
## Shape is intentionally unspecified at MVP; callers must not rely on field names.
func get_battle_state_snapshot() -> Dictionary:
	# TODO(story-003+): populate FSM state, unit positions, acted flags
	return {}


## Ends the player turn early. Also auto-called when all alive player units have acted.
## TODO(story-006): implement full token-based end-of-turn logic.
func end_player_turn() -> void:
	# TODO(story-006): call TurnOrderRunner to advance round
	pass


## Direct-callable entry point for grid click dispatch (also called by signal handler).
## Exposed as public so integration tests can drive it without emitting GameBus signals.
## Per ADR-0014 §4 + story-003 AC-5: 2-state FSM dispatch via match _state.
##
## NOTE: action parameter type is `String` (not StringName per ADR-0014 §10 sketch)
## to match shipped GameBus.input_action_fired signal signature (String per ADR-0001
## line 168 + ADR-0001 amendment advisory delta #6 Item 10a still pending).
func handle_grid_click(action: String, coord: Vector2i, unit_id: int) -> void:
	match _state:
		BattleState.OBSERVATION:
			_handle_grid_click_observation(action, coord, unit_id)
		BattleState.UNIT_SELECTED:
			_handle_grid_click_unit_selected(action, coord, unit_id)


# ─── Signal handlers (stubs — logic in stories 003-008) ─────────────────────

## Subscribed to GameBus.input_action_fired via CONNECT_DEFERRED in _ready().
## Per ADR-0014 §4 + story-003 AC-3, AC-4, AC-6:
##   1. Filter via _is_grid_action(action) — non-grid actions silently ignored
##   2. Resolve coord from ctx.target_coord; fallback to camera.screen_to_grid()
##      if ctx.target_coord == Vector2i.ZERO (sentinel from InputRouter when
##      raw event couldn't resolve)
##   3. Off-grid sentinel Vector2i(-1, -1) → silent return
##   4. Dispatch to handle_grid_click with the resolved coord + ctx.target_unit_id
func _on_input_action_fired(action: String, ctx: InputContext) -> void:
	if not _is_grid_action(action):
		return
	var coord: Vector2i = ctx.target_coord
	if coord == Vector2i.ZERO and _camera != null:
		# Camera fallback per ADR-0014 §4 — re-resolve via viewport mouse position.
		coord = _camera.screen_to_grid(get_viewport().get_mouse_position())
	if coord == Vector2i(-1, -1):
		return  # off-grid sentinel from BattleCamera.screen_to_grid
	handle_grid_click(action, coord, ctx.target_unit_id)


func _on_unit_died(unit_id: int) -> void:
	# TODO(story-008): update fate counters (boss kill, assassin kill attribution)
	# TODO(story-007): call _check_battle_end()
	pass


func _on_unit_turn_started(unit_id: int) -> void:
	# TODO(story-006): reset per-turn acted flag for this unit
	pass


func _on_round_started(round_num: int) -> void:
	# TODO(story-007): check turn limit (round_num > _max_turns → emit battle_outcome_resolved)
	# TODO(story-008): update _fate_formation_turns counter
	pass


# ─── Private helpers ─────────────────────────────────────────────────────────

## Scans _units for the first unit whose BattleUnit.tag matches the given tag.
## Returns -1 if no matching unit found per ADR-0014 §3 + story-002 AC-4.
## Tag is singular (StringName) on BattleUnit per ADR-0014 §3 (NOT Array of tags
## — MVP scope. Future Rally ADR may need multi-tag, e.g., "commander+tank";
## additive amendment to BattleUnit at that point per CR-1d schema-evolution rules).
func _find_unit_by_tag(tag: StringName) -> int:
	for unit: BattleUnit in _units.values():
		if unit.tag == tag:
			return unit.unit_id
	return -1


## Returns true if the given action is one of the 10 grid-domain actions per
## ADR-0014 §4 + input-handling GDD §93. Non-grid actions (camera_pan,
## camera_zoom_in, etc.) are silently ignored by _on_input_action_fired.
func _is_grid_action(action: String) -> bool:
	return action in _GRID_ACTIONS


# ─── FSM dispatch helpers (story-003 AC-5) ───────────────────────────────────

## Dispatches a grid click in OBSERVATION state. Only `unit_select` on an own
## unit (side == 0) that has not acted-this-turn produces a state transition.
## Per ADR-0014 §4 + story-003 AC-5 + AC-7.
func _handle_grid_click_observation(action: String, _coord: Vector2i, unit_id: int) -> void:
	if action != "unit_select":
		return  # only unit_select transitions out of OBSERVATION (MVP scope)
	if unit_id == -1:
		return  # off-grid or non-unit click (e.g., empty tile)
	if not _units.has(unit_id):
		return  # invalid unit_id (defensive — shouldn't happen if InputRouter is correct)
	var unit: BattleUnit = _units[unit_id]
	if unit.side != 0:
		return  # only own units (player side) can be selected (MVP — no enemy inspection)
	if _acted_this_turn.get(unit_id, false):
		return  # acted-this-turn click guard per AC-7 (silent no-op)
	_select_unit(unit_id)


## Dispatches a grid click in UNIT_SELECTED state. Per ADR-0014 §4 + story-003 AC-5:
##  - unit_select on selected unit again → deselect
##  - move_cancel / attack_cancel → deselect
##  - move_target_select / move_confirm + valid move target → handoff to _handle_move (story-004)
##  - attack_target_select / attack_confirm + valid attack target → handoff to _handle_attack (story-005)
##  - end_unit_turn → end_player_turn (story-006 stub)
##  - other actions in this state → silent
func _handle_grid_click_unit_selected(action: String, coord: Vector2i, unit_id: int) -> void:
	match action:
		"unit_select":
			# Clicking the selected unit again deselects (toggle semantic).
			# Clicking a DIFFERENT own unit is silent in MVP — must deselect first.
			if unit_id == _selected_unit_id:
				_deselect()
		"move_cancel", "attack_cancel":
			_deselect()
		"move_target_select", "move_confirm":
			# is_tile_in_move_range stubs to false until story-004; dispatch is wired
			# but downstream _handle_move is a no-op until story-004 fills it.
			if is_tile_in_move_range(coord, _selected_unit_id):
				_handle_move(_selected_unit_id, coord)
		"attack_target_select", "attack_confirm":
			# Same pattern as move — wire dispatch; defer handler body to story-005.
			if is_tile_in_attack_range(coord, _selected_unit_id):
				_handle_attack(_selected_unit_id, unit_id)
		"end_unit_turn":
			end_player_turn()
		_:
			# undo_last_move / grid_hover / unrecognized → silent (MVP scope)
			return


## Selects a unit. Transitions state to UNIT_SELECTED + emits unit_selected_changed
## with (new_unit_id, prev_selected_unit_id). Per ADR-0014 §8 + story-003 AC-5.
func _select_unit(unit_id: int) -> void:
	var prev: int = _selected_unit_id
	_selected_unit_id = unit_id
	_state = BattleState.UNIT_SELECTED
	unit_selected_changed.emit(unit_id, prev)


## Deselects the current unit. Transitions state to OBSERVATION + emits
## unit_selected_changed(-1, prev_selected_unit_id) per ADR-0014 §8.
func _deselect() -> void:
	var prev: int = _selected_unit_id
	_selected_unit_id = -1
	_state = BattleState.OBSERVATION
	unit_selected_changed.emit(-1, prev)


# ─── Action handler stubs (filled by stories 004-005) ───────────────────────

## Handles a move action — validates + applies + emits unit_moved.
## TODO(story-004): full body — _do_move + _consume_unit_action + signal emit.
func _handle_move(_unit_id: int, _dest: Vector2i) -> void:
	# TODO(story-004): position update + facing update + occupancy bookkeeping +
	# unit_moved signal + _consume_unit_action(_unit_id) handoff to story-006.
	pass


## Handles an attack action — runs the resolve chain + applies damage + emits.
## TODO(story-005): full body — _resolve_attack + DamageCalc.resolve +
## HPStatusController.apply_damage + apply_death_consequences + damage_applied.
func _handle_attack(_attacker_id: int, _defender_id: int) -> void:
	# TODO(story-005): formation/angle/aura math + DamageCalc static-call +
	# HPStatusController.apply_damage(4-param) + apply_death_consequences +
	# damage_applied signal + fate-counter increments (story-008 hooks).
	pass
