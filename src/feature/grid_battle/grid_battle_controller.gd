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


# ─── Combat resolution (story-005) ───────────────────────────────────────────

## RNG instance for DamageCalc.resolve evasion roll consumption (1 randi_range
## per non-counter call per ADR-0012 AC-DC-26 replay determinism). Fresh
## RandomNumberGenerator per battle; deterministic seeding deferred to
## scenario-progression ADR (sprint-6).
var _rng: RandomNumberGenerator = null


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


# ─── Terminal state (story-007 AC-7) ─────────────────────────────────────────

## Set true the moment battle_outcome_resolved is emitted. All input + signal
## handlers early-return when set, preventing duplicate outcome emission on
## edge cases (e.g., turn-limit firing simultaneously with last-enemy-death).
var _battle_over: bool = false


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
	# Story-005: RNG instance for DamageCalc.resolve evasion roll consumption.
	# Deterministic seeding deferred to Scenario Progression ADR (sprint-6).
	_rng = RandomNumberGenerator.new()
	_rng.randomize()

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

## Checks whether a tile is in the given unit's movement range. Implements
## input-handling §9 Bidirectional Contract (R-5) + grid-battle.md §612 + §123.
##
## MVP simplification per ADR-0014 §0 + story-004 Implementation Note #1:
## Manhattan distance check (no BFS pathfinding). Future Pathfinding ADR will
## refine to "reachable path exists" via Dijkstra against terrain cost matrix
## per UnitRole.get_class_cost_table; this method's interface stays stable.
##
## Returns false if: unit_id not in registry, tile out of unit's move_range,
## tile occupied by another unit, OR tile not passable (RIVER / MOUNTAIN per
## MapTileData.is_passable_base — set at MapResource load by ADR-0008 contract).
func is_tile_in_move_range(tile: Vector2i, unit_id: int) -> bool:
	if not _units.has(unit_id):
		return false
	var unit: BattleUnit = _units[unit_id]
	# Manhattan distance check (MVP per AC-2)
	var dx: int = absi(tile.x - unit.position.x)
	var dy: int = absi(tile.y - unit.position.y)
	var manhattan: int = dx + dy
	if manhattan == 0 or manhattan > unit.move_range:
		return false  # zero-distance (current tile) or out-of-range
	# Passability + occupancy via MapGrid.get_tile (single source of truth)
	var tile_data: MapTileData = _map_grid.get_tile(tile)
	if tile_data == null:
		return false  # out of bounds (defensive — get_tile may return null at edges)
	if not tile_data.is_passable_base:
		return false  # RIVER / MOUNTAIN / impassable terrain
	if tile_data.occupant_id != 0:
		return false  # tile occupied by some unit
	return true


## Checks whether a tile is a valid attack target for the given unit. Implements
## input-handling §9 Bidirectional Contract (R-5) + grid-battle.md §612 + §198.
##
## Per ADR-0014 §10 + story-005 AC-1: tile must contain an ENEMY unit (different
## side) AND be within attacker's attack_range (Manhattan distance; 1 for melee,
## 2 for 황충 ranged_specialist). MVP simplification — no line-of-sight or
## terrain modifiers.
func is_tile_in_attack_range(tile: Vector2i, unit_id: int) -> bool:
	if not _units.has(unit_id):
		return false
	var attacker: BattleUnit = _units[unit_id]
	# Manhattan distance check
	var dx: int = absi(tile.x - attacker.position.x)
	var dy: int = absi(tile.y - attacker.position.y)
	var manhattan: int = dx + dy
	if manhattan == 0 or manhattan > attacker.attack_range:
		return false
	# Tile must contain an enemy unit (different side) per AC-1
	for defender: BattleUnit in _units.values():
		if defender.position == tile and defender.side != attacker.side:
			return true
	return false


## Returns the currently selected unit_id, or -1 if no unit is selected.
func get_selected_unit_id() -> int:
	return _selected_unit_id


## Returns an opaque snapshot of battle state for AI consumer (Battle AI ADR).
## Shape is intentionally unspecified at MVP; callers must not rely on field names.
func get_battle_state_snapshot() -> Dictionary:
	# TODO(story-003+): populate FSM state, unit positions, acted flags
	return {}


## Ends the player turn early. Also auto-called from _consume_unit_action when
## all alive player units have acted (AC-4 auto-handoff). Per ADR-0014 §6 +
## story-006 AC-5: clears _acted_this_turn for the next round + deselects.
##
## DEVIATION from ADR-0014 §6 sketch + AC-5 wording "_turn_runner.end_player_turn()":
## the shipped TurnOrderRunner has NO `end_player_turn()` method (drift #10 — see
## Implementation Notes amendment). Round advance is signal-driven via
## GameBus.round_started → _on_round_started; this method is controller-side
## bookkeeping ONLY. Full Battle Scene wiring (sprint-6+) will replace this with
## a synchronous Callable injection per ADR-0011 §Decision Contract 5.
func end_player_turn() -> void:
	_acted_this_turn.clear()
	if _selected_unit_id != -1:
		_deselect()


## Direct-callable entry point for grid click dispatch (also called by signal handler).
## Exposed as public so integration tests can drive it without emitting GameBus signals.
## Per ADR-0014 §4 + story-003 AC-5: 2-state FSM dispatch via match _state.
##
## Story-007 AC-7: terminal-state guard — once `_battle_over == true`, all click
## input is silently ignored (prevents post-resolution interaction).
##
## NOTE: action parameter type is `String` (not StringName per ADR-0014 §10 sketch)
## to match shipped GameBus.input_action_fired signal signature (String per ADR-0001
## line 168 + ADR-0001 amendment advisory delta #6 Item 10a still pending).
func handle_grid_click(action: String, coord: Vector2i, unit_id: int) -> void:
	if _battle_over:
		return  # AC-7 terminal-state guard — no input handling after outcome resolved
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
	if _battle_over:
		return  # AC-7 terminal-state guard — no further outcome processing
	# Story-008 AC-5: boss-killed flag (idempotent — only first kill flips it).
	if unit_id == _fate_boss_unit_id and not _fate_boss_killed:
		_fate_boss_killed = true
		hidden_fate_condition_progressed.emit(&"boss_killed", 1)
	# Story-008 AC-4: assassin-kill attribution. Last attacker is set by
	# _resolve_attack pre-apply_damage; CONNECT_DEFERRED guarantees it's
	# already populated by the time this handler fires. Defender must be
	# enemy (side==1) — friendly-fire kills don't count.
	if _last_attacker_id == _fate_assassin_unit_id and _fate_assassin_unit_id != -1:
		if _units.has(unit_id) and _units[unit_id].side == 1:
			_fate_assassin_kills += 1
			hidden_fate_condition_progressed.emit(&"assassin_kills", _fate_assassin_kills)
	# Story-007 AC-5: victory check on every unit death.
	_check_battle_end()


func _on_unit_turn_started(unit_id: int) -> void:
	# TODO(story-006): reset per-turn acted flag for this unit
	pass


## Subscribed to GameBus.round_started via CONNECT_DEFERRED in _ready().
## Per ADR-0014 §7 + story-007 AC-3: when round_num exceeds _max_turns, emit
## battle_outcome_resolved with TURN_LIMIT_REACHED outcome. _max_turns is
## loaded from BalanceConstants(MAX_TURNS_PER_BATTLE)=5 in _ready().
func _on_round_started(round_num: int) -> void:
	if _battle_over:
		return  # AC-7 terminal-state guard
	# Story-008 AC-3: formation_turns counter. If any alive player unit had
	# ≥1 adjacent ally during this round, increment + emit. Per ADR-0014 §7
	# sketch + chapter-prototype's formation-active scan.
	for unit: BattleUnit in _units.values():
		if unit.side != 0:
			continue  # player-side only
		if not _hp_controller.is_alive(unit.unit_id):
			continue  # dead units don't form formations
		if _count_adjacent_allies(unit) >= 1:
			_fate_formation_turns += 1
			hidden_fate_condition_progressed.emit(&"formation_turns", _fate_formation_turns)
			break  # one increment per round, not per qualifying unit
	# Story-007 AC-3: round 6 (>5) triggers TURN_LIMIT_REACHED.
	if round_num > _max_turns:
		_emit_battle_outcome(&"TURN_LIMIT_REACHED")


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
			# is_tile_in_move_range + _handle_move are story-004 implementations.
			# _handle_move signature takes BattleUnit (not unit_id) per AC-3 —
			# caller resolves _selected_unit_id → BattleUnit via _units lookup.
			if is_tile_in_move_range(coord, _selected_unit_id):
				_handle_move(_units[_selected_unit_id], coord)
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

## Handles a move action per story-004 AC-3: validates via is_tile_in_move_range,
## applies via _do_move, consumes the unit's turn action via _consume_unit_action.
## Re-entrancy guard per AC-8: silent no-op if unit already acted this turn.
##
## Signature uses BattleUnit (not unit_id) per story-004 AC-3 — caller in
## handle_grid_click resolves unit_id → BattleUnit before dispatch.
func _handle_move(unit: BattleUnit, dest: Vector2i) -> void:
	if _acted_this_turn.get(unit.unit_id, false):
		return  # AC-8 re-entrancy guard
	if not is_tile_in_move_range(dest, unit.unit_id):
		return  # invalid target — silent (validation already happened at dispatch
		        # but this defense is per AC-3: _handle_move validates internally)
	_do_move(unit, dest)
	_consume_unit_action(unit.unit_id)  # story-006 stub


## Handles an attack action per story-005 AC-2: validates via is_tile_in_attack_range,
## runs _resolve_attack chain (multipliers + DamageCalc + HPStatusController),
## consumes the unit's turn action via _consume_unit_action.
##
## DEVIATION from ADR-0014 §5 step 9: apply_death_consequences NOT called —
## the method does not exist on shipped HPStatusController; DEMORALIZED
## propagation auto-fires inside HPStatusController.apply_damage via
## _propagate_demoralized_radius (private). ADR-0014 Implementation Notes
## amended same-patch documenting the drift.
func _handle_attack(attacker_id: int, defender_id: int) -> void:
	if _acted_this_turn.get(attacker_id, false):
		return  # re-entrancy guard (mirrors story-004 _handle_move pattern)
	if not _units.has(attacker_id) or not _units.has(defender_id):
		return  # defensive — shouldn't happen if dispatch is correct
	var attacker: BattleUnit = _units[attacker_id]
	var defender: BattleUnit = _units[defender_id]
	if not is_tile_in_attack_range(defender.position, attacker_id):
		return  # invalid target — silent
	_resolve_attack(attacker, defender)
	_consume_unit_action(attacker_id)


# ─── Action implementations (story-004) ──────────────────────────────────────

## Applies a move per story-004 AC-4: updates position + facing + MapGrid
## occupancy bookkeeping + emits unit_moved AFTER all mutations complete (AC-5).
##
## Sole-writer of unit.position + unit.facing per ADR-0014 §3 (story-002
## sole-writer contract on _units extends to BattleUnit field mutations during
## battle). MapGrid occupancy bookkeeping per shipped clear_occupant +
## set_occupant API contract (strict-sync per §EC-6 — clear before set).
func _do_move(unit: BattleUnit, dest: Vector2i) -> void:
	var old_pos: Vector2i = unit.position
	# 1. MapGrid occupancy clear (must precede set per strict-sync EC-6)
	_map_grid.clear_occupant(old_pos)
	# 2. Mutate unit fields
	unit.position = dest
	unit.facing = _direction_from_to(old_pos, dest)
	# 3. MapGrid occupancy set with faction derived from side (0→ALLY, 1→ENEMY)
	var faction: int = MapGrid.FACTION_ALLY if unit.side == 0 else MapGrid.FACTION_ENEMY
	_map_grid.set_occupant(dest, unit.unit_id, faction)
	# 4. Emit unit_moved signal AFTER position update per AC-5
	unit_moved.emit(unit.unit_id, old_pos, dest)


## Computes cardinal facing (0=N, 1=E, 2=S, 3=W) from movement vector per
## chapter-prototype pattern. Larger axis wins; on tie, X-axis wins.
## Used by _do_move (story-004) and consumed by _attack_angle (story-005).
func _direction_from_to(from: Vector2i, to: Vector2i) -> int:
	var dx: int = to.x - from.x
	var dy: int = to.y - from.y
	if absi(dx) >= absi(dy):
		return 1 if dx > 0 else 3  # E or W
	return 2 if dy > 0 else 0  # S or N


## Marks the unit as having acted this turn + spends action token via
## TurnOrderRunner + deselects + auto-handoff if all player units acted.
## Per ADR-0014 §6 + story-006 AC-1..AC-4.
##
## DEVIATION from ADR-0014 §6 sketch (drift #9 — see Implementation Notes
## amendment): sketch shows `_turn_runner.spend_action_token(unit_id)` but the
## shipped TurnOrderRunner public API is `declare_action(unit_id, action,
## target) -> ActionResult` per ADR-0011 §Key Interfaces. Map to
## ActionType.ATTACK for the MVP single-token simplification — when full
## Contract 4 (move + action token split) lands post-MVP, only this single
## call site changes. ActionTarget is null for MVP per ADR-0011 story-004
## "ActionTarget validation deferred to story-007+".
func _consume_unit_action(unit_id: int) -> void:
	_acted_this_turn[unit_id] = true
	# Single-token MVP: ATTACK token represents "this unit acted this turn"
	# regardless of whether the underlying action was a MOVE or ATTACK.
	_turn_runner.declare_action(unit_id, TurnOrderRunner.ActionType.ATTACK, null)
	if _selected_unit_id != -1:
		_deselect()
	if not _any_player_unit_can_act():
		end_player_turn()


## Returns true if any player-side (side==0) alive unit has NOT acted this turn.
## Per ADR-0014 §6 + story-006 AC-3. Used by _consume_unit_action for the
## auto-handoff gate (AC-4): all-player-units-acted → end_player_turn.
##
## Dead-unit exclusion via _hp_controller.is_alive(unit_id) per Implementation
## Notes #4 (`is_alive` is canonical query per shipped HPStatusController:219;
## `is_dead` is NOT a shipped API — drift catalogued at ADR-0014 review).
func _any_player_unit_can_act() -> bool:
	for unit: BattleUnit in _units.values():
		if unit.side != 0:
			continue  # only player-side units count for the handoff gate
		if not _hp_controller.is_alive(unit.unit_id):
			continue  # dead units excluded per Implementation Notes #4
		if not _acted_this_turn.get(unit.unit_id, false):
			return true
	return false


# ─── Combat resolution helpers (story-005) ──────────────────────────────────

## Counts same-side non-dead units within Manhattan distance 1 of the given unit.
## Per ADR-0014 §5 + story-005 AC-4. Used by _compute_formation_mult and by
## _on_round_started (story-008 _fate_formation_turns counter).
func _count_adjacent_allies(unit: BattleUnit) -> int:
	var count: int = 0
	for other: BattleUnit in _units.values():
		if other.unit_id == unit.unit_id:
			continue  # skip self
		if other.side != unit.side:
			continue  # skip enemies
		if not _hp_controller.is_alive(other.unit_id):
			continue  # skip dead units
		var dx: int = absi(other.position.x - unit.position.x)
		var dy: int = absi(other.position.y - unit.position.y)
		if dx + dy == 1:  # Manhattan adjacency
			count += 1
	return count


## Returns true if any same-side non-dead unit with passive == &"command_aura"
## (유비) is within Manhattan distance 1 of the attacker. Per ADR-0014 §5 +
## story-005 AC-5.
func _has_adjacent_command_aura(attacker: BattleUnit) -> bool:
	for other: BattleUnit in _units.values():
		if other.unit_id == attacker.unit_id:
			continue
		if other.side != attacker.side:
			continue
		if not _hp_controller.is_alive(other.unit_id):
			continue
		if other.passive != &"command_aura":
			continue
		var dx: int = absi(other.position.x - attacker.position.x)
		var dy: int = absi(other.position.y - attacker.position.y)
		if dx + dy == 1:
			return true
	return false


## Classifies the attack angle relative to defender's facing per ADR-0014 §5
## step 3 + story-005 AC-3. Returns "front" / "side" / "rear".
##
## attacker_dir is the cardinal direction FROM defender TO attacker (i.e., where
## the attacker is sitting from the defender's perspective). If attacker is in
## the direction the defender is FACING → "front". If attacker is BEHIND the
## defender (opposite direction of facing) → "rear". Otherwise → "side".
func _attack_angle(attacker: BattleUnit, defender: BattleUnit) -> String:
	var attacker_dir: int = _direction_from_to(defender.position, attacker.position)
	if attacker_dir == defender.facing:
		return "front"
	if attacker_dir == (defender.facing + 2) % 4:
		return "rear"
	return "side"


## Computes formation multiplier per chapter-prototype shape + ADR-0014 §5 step 2:
## 1.0 + 0.05 * adjacent_ally_count, capped at 1.20 (max 4 adjacent contributing).
func _compute_formation_mult(attacker: BattleUnit) -> float:
	var formation_count: int = _count_adjacent_allies(attacker)
	return minf(1.0 + 0.05 * float(formation_count), 1.20)


## Computes angle multiplier per chapter-prototype shape + ADR-0014 §5 step 4:
## front=1.00, side=1.25, rear=1.50, rear+rear_specialist passive (황충)=1.75.
func _compute_angle_mult(attacker: BattleUnit, defender: BattleUnit) -> float:
	var angle: String = _attack_angle(attacker, defender)
	match angle:
		"side":
			return 1.25
		"rear":
			if attacker.passive == &"rear_specialist":
				return 1.75
			return 1.50
		_:
			return 1.0  # front (default)


## Computes aura multiplier per chapter-prototype shape + ADR-0014 §5 step 5:
## 1.15 if any 유비 (command_aura passive) ally is adjacent to attacker, else 1.0.
func _compute_aura_mult(attacker: BattleUnit) -> float:
	if _has_adjacent_command_aura(attacker):
		return 1.15
	return 1.0


## Maps controller-local angle string to ResolveModifiers.direction_rel StringName
## per ADR-0012 ResolveModifiers contract: {FRONT, FLANK, REAR}.
##
## NOTE: ADR-0014 §5 uses "side" terminology; ADR-0012 ResolveModifiers uses
## "FLANK" StringName. They map 1:1 — translation lives at controller-DamageCalc
## boundary per Migration Plan §13.
func _angle_to_direction_rel(angle: String) -> StringName:
	match angle:
		"front":
			return &"FRONT"
		"side":
			return &"FLANK"
		"rear":
			return &"REAR"
		_:
			return &"FRONT"  # defensive default


## Runs the full attack resolve chain per ADR-0014 §5 + story-005 AC-2:
## 1. Compute formation_mult (±0..0.20)
## 2. Compute angle ("front"/"side"/"rear")
## 3. Compute angle_mult (1.0/1.25/1.50/1.75)
## 4. Compute aura_mult (1.0/1.15)
## 5. Construct AttackerContext + DefenderContext + ResolveModifiers
## 6. Call DamageCalc.resolve → ResolveResult (consumes RNG once for evasion roll)
## 7. Post-multiply controller-side multipliers (angle_mult × aura_mult — NOT
##    consumed by DamageCalc; formation_atk_bonus IS consumed via P_mult formula)
## 8. Track _last_attacker_id for story-008 fate-counter attribution
## 9. Track rear-attack fate counter (story-008 partial — ADR-0014 §5 step 6 +
##    grid-battle.md §198 hook for Destiny Branch)
## 10. _hp_controller.apply_damage (4-param signature per ADR-0010 + ADR-0014 §10)
## 11. Emit damage_applied(attacker_id, defender_id, damage)
##
## Returns the final damage dealt (post-multipliers); 0 on MISS.
##
## DEVIATION from ADR-0014 §5 step 9: apply_death_consequences NOT called —
## method not on shipped HPStatusController; DEMORALIZED propagation is internal
## to apply_damage via _propagate_demoralized_radius. Documented in commit +
## ADR-0014 Implementation Notes amendment.
func _resolve_attack(attacker: BattleUnit, defender: BattleUnit) -> int:
	# Stage 1: compute multipliers
	var formation_mult: float = _compute_formation_mult(attacker)
	var angle: String = _attack_angle(attacker, defender)
	var angle_mult: float = _compute_angle_mult(attacker, defender)
	var aura_mult: float = _compute_aura_mult(attacker)

	# Stage 2: build DamageCalc inputs
	var passives: Array[StringName] = []
	if attacker.passive != &"":
		passives.append(attacker.passive)
	var attacker_ctx: AttackerContext = AttackerContext.make(
		attacker.hero_id,
		attacker.unit_class,
		attacker.raw_atk,
		false,  # charge_active — MVP no charge
		false,  # defend_stance_active — MVP no defend
		passives,
	)
	var defender_ctx: DefenderContext = DefenderContext.make(
		defender.hero_id,
		defender.raw_def,
		0,  # terrain_def — MVP no terrain bonus
		0,  # terrain_evasion — MVP no evasion
	)
	var modifiers: ResolveModifiers = ResolveModifiers.make(
		ResolveModifiers.AttackType.PHYSICAL,
		_rng,
		_angle_to_direction_rel(angle),
		1,  # round_number — MVP placeholder; story-007 wires real round
		false,  # is_counter — MVP no counter
		"",  # skill_id — MVP no skills
		[],  # source_flags — populated by DamageCalc
		0.0,  # rally_bonus — MVP no rally
		formation_mult - 1.0,  # formation_atk_bonus (consumed by DamageCalc P_mult)
		0.0,  # formation_def_bonus — MVP no def bonus
		Callable(),  # acted_this_turn_callable — MVP no counter eligibility
	)
	# Set NEW story-005 fields (not in make() factory yet — additive same-patch).
	# These are CONTROLLER-side post-multipliers (NOT consumed by DamageCalc).
	modifiers.angle_mult = angle_mult
	modifiers.aura_mult = aura_mult

	# Stage 3: track attacker for story-008 fate-counter attribution
	_last_attacker_id = attacker.unit_id

	# Stage 4: call DamageCalc.resolve
	var result: ResolveResult = DamageCalc.resolve(attacker_ctx, defender_ctx, modifiers)
	var base_damage: int = result.resolved_damage  # 0 on MISS; 1+ on HIT

	# Stage 5: apply controller-side post-multipliers (angle_mult × aura_mult).
	# NOTE: formation_atk_bonus already consumed by DamageCalc in P_mult formula.
	var final_damage: int = roundi(float(base_damage) * angle_mult * aura_mult)
	if result.kind == ResolveResult.Kind.HIT and final_damage < 1:
		final_damage = 1  # ensure HIT delivers minimum 1 damage post-rounding

	# Stage 6: rear-attack fate counter (story-008 partial — full impl in story-008)
	if angle == "rear":
		_fate_rear_attacks += 1
		hidden_fate_condition_progressed.emit(&"rear_attacks", _fate_rear_attacks)

	# Stage 7: apply via HPStatusController (sole writer of HP per ADR-0010)
	_hp_controller.apply_damage(defender.unit_id, final_damage, modifiers.attack_type, modifiers.source_flags)

	# Stage 8: emit damage_applied per ADR-0014 §8
	damage_applied.emit(attacker.unit_id, defender.unit_id, final_damage)

	return final_damage


# ─── Battle outcome resolution (story-007) ──────────────────────────────────

## Builds the fate_data Dictionary snapshot from current 5 fate counters and
## emits battle_outcome_resolved + sets _battle_over terminal-state flag.
## Per ADR-0014 §7 + story-007 AC-4 + AC-7.
##
## fate_data shape (consumed by Destiny Branch ADR — sprint-6):
##   - tank_unit_id / assassin_unit_id / boss_unit_id (int): roster identity
##   - rear_attacks (int): cumulative rear-strike count (story-005 + story-008)
##   - formation_turns (int): rounds with active formation (story-008)
##   - assassin_kills (int): kills attributed to assassin (story-008)
##   - boss_killed (bool): boss-tagged enemy killed flag (story-008)
##
## Idempotency: this method early-returns if _battle_over is already true,
## guaranteeing exactly-once outcome emission per battle (CR-7 / AC-7).
func _emit_battle_outcome(outcome: StringName) -> void:
	if _battle_over:
		return  # AC-7: idempotent — outcome already resolved
	_battle_over = true
	# Story-008 AC-7: tank_alive_hp_pct queried on-demand (NOT a stored counter).
	# 0.0 if no tank unit in roster, dead, or HP/Status returns 0 max_hp.
	var tank_pct: float = 0.0
	if _fate_tank_unit_id != -1:
		var max_hp: int = _hp_controller.get_max_hp(_fate_tank_unit_id)
		if max_hp > 0:
			tank_pct = float(_hp_controller.get_current_hp(_fate_tank_unit_id)) / float(max_hp)
	var fate_data: Dictionary = {
		"tank_unit_id": _fate_tank_unit_id,
		"tank_alive_hp_pct": tank_pct,
		"assassin_unit_id": _fate_assassin_unit_id,
		"boss_unit_id": _fate_boss_unit_id,
		"rear_attacks": _fate_rear_attacks,
		"formation_turns": _fate_formation_turns,
		"assassin_kills": _fate_assassin_kills,
		"boss_killed": _fate_boss_killed,
	}
	battle_outcome_resolved.emit(outcome, fate_data)


## Checks alive-unit counts on each side. If either side has 0 alive units,
## emits the corresponding annihilation outcome and returns true. Returns false
## if both sides still have at least one alive unit. Per ADR-0014 §7 +
## story-007 AC-5 + AC-6 + grid-battle.md CR-7 evaluation order.
##
## CR-7 evaluation order: VICTORY_ANNIHILATION checked BEFORE DEFEAT_ANNIHILATION
## per grid-battle.md EC-GB-02 mutual-kill precedence (player-side wins ties).
## Called from _on_unit_died (CONNECT_DEFERRED — no reentrance per ADR-0014 R-8).
func _check_battle_end() -> bool:
	var player_alive: int = 0
	var enemy_alive: int = 0
	for unit: BattleUnit in _units.values():
		if not _hp_controller.is_alive(unit.unit_id):
			continue
		if unit.side == 0:
			player_alive += 1
		else:
			enemy_alive += 1
	# CR-7 + EC-GB-02: VICTORY_ANNIHILATION precedence over DEFEAT.
	if enemy_alive == 0:
		_emit_battle_outcome(&"VICTORY_ANNIHILATION")
		return true
	if player_alive == 0:
		_emit_battle_outcome(&"DEFEAT_ANNIHILATION")
		return true
	return false
