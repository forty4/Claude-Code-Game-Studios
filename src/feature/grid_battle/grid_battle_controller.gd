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
## MANDATORY `_exit_tree()` body explicitly disconnects all 5 signal subscriptions
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
## Therefore this controller subscribes to GameBus.X for all 5 signals (input_action_fired +
## unit_died + unit_turn_started + unit_turn_ended + round_started) — uniform autoload subscription
## pattern. unit_turn_ended was added later (end-of-turn polygon dim) as a view-layer re-emit;
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


## Diagnostic-trace gate. Sessions 4-5 used inline raw `print(...)` calls (CLICK
## / TURN / HINT / SELECT / BATTLE-END categories) to debug input + turn-loop
## behavior in the windowed env. Now routed through `_trace()` and silenced by
## default; flip to `true` (then re-import) to surface the full event-stream
## again.
const _TRACE_ENABLED: bool = false


func _trace(msg: String) -> void:
	if _TRACE_ENABLED:
		print(msg)


# ─── Signals (Battle-domain per ADR-0014 §8) ────────────────────────────────

## Emitted when unit selection changes. was_selected == -1 for deselect.
signal unit_selected_changed(unit_id: int, was_selected: int)

## Emitted after a unit completes a move action.
signal unit_moved(unit_id: int, from: Vector2i, to: Vector2i)

## Emitted after HPStatusController.apply_damage resolves and returns.
signal damage_applied(attacker_id: int, defender_id: int, damage: int)

## Controller-scoped re-emit of GameBus.unit_died so scene-tier subscribers
## (BattleScene visual feedback) can react without subscribing to GameBus
## directly (battle_scene_smoke_test AC-7: no GameBus subs in BattleScene).
signal unit_visual_died(unit_id: int)

## Controller-scoped re-emit of GameBus.unit_turn_started for the view layer
## (BattleScene turn-indicator overlay). Fires for both player and AI turns;
## the view layer reparents a single TurnIndicator child under the active
## unit's polygon. Re-emit pattern avoids R-7 (no GameBus subs on BattleScene).
signal active_unit_changed(unit_id: int)

## Controller-scoped re-emit of GameBus.unit_turn_ended for the view layer
## (BattleScene end-of-turn polygon dim). acted=false units (passed without
## spending a token) don't get dimmed. Re-emit pattern avoids R-7.
signal unit_turn_ended_visual(unit_id: int, acted: bool)

## Controller-scoped re-emit of GameBus.round_started for the view layer
## (BattleScene undim-all on round rollover). Distinct from the controller's
## own _on_round_started handler which owns the turn-limit + fate-counter
## logic — this signal exists purely as a view-layer rollover cue.
signal round_started_visual(round_number: int)

## Emitted when the battle is over. outcome is a StringName (e.g. &"TURN_LIMIT_REACHED").
## fate_data carries hidden fate condition snapshot per ADR-0014 §8.
signal battle_outcome_resolved(outcome: StringName, fate_data: Dictionary)

## Emitted silently for each fate-condition update. Destiny Branch ADR (sprint-6)
## is the SOLE subscriber — Battle HUD MUST NOT subscribe (preserves "hidden" semantic).
signal hidden_fate_condition_progressed(condition_id: StringName, value: int)

## 6th LOCAL signal — emitted at AI-turn entry per ADR-0019 + ADR-0014 §8 amended
## via /architecture-review delta #14 2026-05-05. AISystem (battle-scoped Node 6th
## invocation) subscribes with CONNECT_DEFERRED and responds via its own LOCAL
## signal `ai_action_ready(unit_id, command)` within 500ms timeout per CR-3.
signal ai_action_requested(unit_id: int, snapshot: BattleStateSnapshot)


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

## AISystem DI field — injected via set_ai_system() AFTER add_child() (not a setup() param).
## Null = no AI subscriber (player-only mode or battle not yet wired). Per ADR-0014 §8
## Amendment 2026-05-10 §Subscriber Contract.
var _ai_system: AISystem = null


# ─── FSM + per-turn state (ADR-0014 §2) ─────────────────────────────────────

var _state: BattleState = BattleState.OBSERVATION
var _selected_unit_id: int = -1

## ID of the unit whose turn is currently ACTING per TurnOrderRunner. Player
## clicks on any other own unit are ignored — only the active turn unit can
## be selected, moved, or attack. Updated in _on_unit_turn_started; -1 between
## turns. Mirrors TurnOrderRunner's internal active-unit tracking so the click
## layer doesn't have to query the runner on every input.
var _active_turn_unit_id: int = -1

## unit_id → already-acted flag for this round.
var _acted_this_turn: Dictionary[int, bool] = {}

## unit_id → MOVE token spent this turn. Tracked separately from _acted_this_turn
## so a player unit can MOVE and then ATTACK in the same turn (mirrors the turn
## runner's move_token_spent / action_token_spent split per ADR-0011). MOVE sets
## this flag (blocks a second MOVE); ATTACK sets _acted_this_turn (terminal).
var _moved_this_turn: Dictionary[int, bool] = {}

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


# ─── Chokepoints (S7-05 chapter-1 substrate; sourced from ChapterDefinition) ─

## Tactical chokepoint coords surfaced into BattleStateSnapshot.chokepoints for
## AISystem F-AI-3 (holder archetype) anchor scoring. Set via set_chokepoints()
## by BattleScene at chapter-load. Empty = no chokepoints (default snapshot).
var _chokepoints: Array[Vector2i] = []


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


## Injects the AISystem subscriber for `ai_action_ready` signal. Called by
## BattleScene AFTER add_child(), once both GridBattleController and AISystem
## are in the scene tree. Safe to call before or after _ready() — connection is
## established here, not in _ready(), so ORDER of add_child() vs. set_ai_system()
## call does not matter.
##
## Idempotent: calling twice with the same AISystem does nothing (is_connected guard).
## CONNECT_DEFERRED mandatory: `_on_ai_action_ready` calls `_do_move` /
## `_resolve_attack` (NOT the `_handle_move` / `_handle_attack` wrappers — see
## handler doc comment for the bypass rationale) which mutate `_units` /
## `_map_grid` state; deferral prevents reentrance if AISystem emits synchronously
## inside `_on_ai_action_requested` (which itself fires deferred from
## GridBattleController, but AISystem may be called synchronously from tests).
## Per ADR-0014 §8 Amendment 2026-05-10.
##
## DI surface (injection point), not runtime state — mirrors set_action_controller
## precedent on TurnOrderRunner (ADR-0011 §Amendment 2026-05-09).
func set_ai_system(ai_system: AISystem) -> void:
	_ai_system = ai_system
	if _ai_system == null:
		return
	if not _ai_system.ai_action_ready.is_connected(_on_ai_action_ready):
		var err: int = _ai_system.ai_action_ready.connect(
			_on_ai_action_ready, Object.CONNECT_DEFERRED
		)
		assert(err == OK,
			"GridBattleController: ai_action_ready.connect failed (err=%d)" % err)


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
	GameBus.unit_turn_ended.connect(_on_unit_turn_ended, Object.CONNECT_DEFERRED)
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
	if GameBus.unit_turn_ended.is_connected(_on_unit_turn_ended):
		GameBus.unit_turn_ended.disconnect(_on_unit_turn_ended)
	if GameBus.round_started.is_connected(_on_round_started):
		GameBus.round_started.disconnect(_on_round_started)
	# AISystem disconnect — is_instance_valid guard per G-11 (battle-scoped Node,
	# may be freed before GridBattleController in edge teardown orders). Source
	# outlives subscriber rule does NOT apply here (both are battle-scoped), so
	# the guard is purely defensive against unusual teardown order.
	if is_instance_valid(_ai_system) \
			and _ai_system.ai_action_ready.is_connected(_on_ai_action_ready):
		_ai_system.ai_action_ready.disconnect(_on_ai_action_ready)


## Handles AISystem.ai_action_ready signal (CONNECT_DEFERRED). Per ADR-0014 §8
## Amendment 2026-05-10 §Handler Dispatch Table — 6-way ActionType match:
##
##   WAIT      → declare_action(WAIT, null) only (no game-state mutation)
##   MOVE      → _do_move → declare_action(MOVE, target)
##   ATTACK    → _resolve_attack → declare_action(ATTACK, target)
##   MOVE_AND_ATTACK → decompose: _do_move → declare_action(MOVE) THEN
##                     _resolve_attack → declare_action(ATTACK)
##   DEFEND    → declare_action(WAIT, null) [DEFEND execution deferred to Skill ADR]
##   USE_SKILL → push_warning + declare_action(WAIT, null) per ADR-0014 §0 MVP scope
##
## DESIGN NOTE: This handler bypasses _handle_move/_handle_attack wrappers because
## both wrappers call _consume_unit_action() which always issues declare_action(ATTACK)
## internally (MVP single-token simplification). AI path needs the correct MOVE/ATTACK
## token split for _maybe_defer_turn_completion predicate in S15-A. Directly calling
## _do_move/_resolve_attack avoids the double declare_action problem. _acted_this_turn
## is set explicitly here to honour the re-entrancy guard that _handle_move/_handle_attack
## check. Per ADR-0014 §8 Amendment 2026-05-10 §Order of Operations.
##
## Guards: _battle_over early-return; unit_id must be in _units; command must be
## non-null. Invalid unit_id or null command → push_warning + return (no dispatch).
func _on_ai_action_ready(unit_id: int, command: AIActionCommand) -> void:
	if _battle_over:
		return
	if command == null:
		push_warning(
			"GridBattleController._on_ai_action_ready: null command for unit_id=%d — skipping dispatch"
			% unit_id
		)
		return
	if not _units.has(unit_id):
		push_warning(
			"GridBattleController._on_ai_action_ready: unit_id=%d not in registry — skipping dispatch"
			% unit_id
		)
		return
	match command.action_type:
		AIActionCommand.ActionType.WAIT:
			_acted_this_turn[unit_id] = true
			_turn_runner.declare_action(unit_id, TurnOrderRunner.ActionType.WAIT, null)
		AIActionCommand.ActionType.MOVE:
			var unit: BattleUnit = _units[unit_id]
			if is_tile_in_move_range(command.move_target, unit_id):
				_do_move(unit, command.move_target)
			_acted_this_turn[unit_id] = true
			_turn_runner.declare_action(
				unit_id, TurnOrderRunner.ActionType.MOVE,
				_make_move_target(command.move_target)
			)
			# AI MOVE-only finalizes the turn: WAIT sets turn_state=DONE so
			# _maybe_defer_turn_completion can advance to the next unit. Player
			# MOVE intentionally leaves the turn open for follow-up ATTACK/WAIT;
			# AI commits its full beat in one _on_ai_action_ready dispatch.
			_turn_runner.declare_action(unit_id, TurnOrderRunner.ActionType.WAIT, null)
		AIActionCommand.ActionType.ATTACK:
			if _units.has(command.attack_target_unit_id):
				var attacker: BattleUnit = _units[unit_id]
				var defender: BattleUnit = _units[command.attack_target_unit_id]
				if is_tile_in_attack_range(defender.position, unit_id):
					_resolve_attack(attacker, defender)
			_acted_this_turn[unit_id] = true
			_turn_runner.declare_action(
				unit_id, TurnOrderRunner.ActionType.ATTACK,
				_make_attack_target(command.attack_target_unit_id)
			)
		AIActionCommand.ActionType.MOVE_AND_ATTACK:
			# 2-call decomposition: MOVE action first, ATTACK action second.
			# _maybe_defer_turn_completion fires on the ATTACK declare_action call
			# (action_token_spent == true). Per ADR-0014 §8 Amendment §Order of Ops.
			var unit: BattleUnit = _units[unit_id]
			if is_tile_in_move_range(command.move_target, unit_id):
				_do_move(unit, command.move_target)
			_turn_runner.declare_action(
				unit_id, TurnOrderRunner.ActionType.MOVE,
				_make_move_target(command.move_target)
			)
			if _units.has(command.attack_target_unit_id):
				# Re-read unit after potential _do_move position update
				unit = _units[unit_id]
				var defender: BattleUnit = _units[command.attack_target_unit_id]
				if is_tile_in_attack_range(defender.position, unit_id):
					_resolve_attack(unit, defender)
			_acted_this_turn[unit_id] = true
			_turn_runner.declare_action(
				unit_id, TurnOrderRunner.ActionType.ATTACK,
				_make_attack_target(command.attack_target_unit_id)
			)
		AIActionCommand.ActionType.DEFEND:
			# DEFEND is a basic action with token-spending semantics per ADR-0011
			# story-004 amendment (sets defend_stance_active on UnitTurnState).
			# No game-state mutation here — TurnOrderRunner owns the state flag.
			_acted_this_turn[unit_id] = true
			_turn_runner.declare_action(unit_id, TurnOrderRunner.ActionType.DEFEND, null)
		AIActionCommand.ActionType.USE_SKILL:
			# USE_SKILL execution deferred per ADR-0014 §0 MVP scope.
			# Substitutes WAIT so the AI unit's turn completes cleanly.
			push_warning(
				("GridBattleController: AIActionCommand.USE_SKILL deferred per ADR-0014 "
				+ "§0 MVP scope — substituting WAIT for unit_id %d")
				% unit_id
			)
			_acted_this_turn[unit_id] = true
			_turn_runner.declare_action(unit_id, TurnOrderRunner.ActionType.WAIT, null)
		_:
			push_warning(
				"GridBattleController._on_ai_action_ready: unknown action_type=%d for unit_id=%d"
				% [command.action_type as int, unit_id]
			)
			_acted_this_turn[unit_id] = true
			_turn_runner.declare_action(unit_id, TurnOrderRunner.ActionType.WAIT, null)


## Constructs an ActionTarget for a MOVE action to target_pos.
## movement_cost is set to 0 (stub per story-007+ refinement candidate).
## Per ADR-0011 §Key Interfaces + ADR-0014 §8 Amendment 2026-05-10.
func _make_move_target(target_pos: Vector2i) -> ActionTarget:
	var t: ActionTarget = ActionTarget.new()
	t.target_position = target_pos
	t.target_unit_id = 0
	t.movement_cost = 0  # story-007+ refinement: populate from terrain cost matrix
	return t


## Constructs an ActionTarget for an ATTACK action targeting target_unit_id.
## target_position is left at Vector2i.ZERO (unit-targeted attack, position derived
## by caller from _units registry as needed).
## Per ADR-0011 §Key Interfaces + ADR-0014 §8 Amendment 2026-05-10.
func _make_attack_target(target_unit_id: int) -> ActionTarget:
	var t: ActionTarget = ActionTarget.new()
	t.target_unit_id = target_unit_id
	t.target_position = Vector2i.ZERO
	t.movement_cost = 0
	return t


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
	# Use tile_state (not occupant_id) — occupant_id is the unit_id which is 0
	# for the commander (unit 0), making that tile spuriously read as empty.
	if tile_data.tile_state == MapGrid.TILE_STATE_ALLY_OCCUPIED \
			or tile_data.tile_state == MapGrid.TILE_STATE_ENEMY_OCCUPIED:
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


## Enumerates the set of tiles the unit can legally move to. Reuses
## is_tile_in_move_range as the single source of truth for movement validation,
## so the preview cannot drift from the click-time check. Scans the Manhattan
## diamond bounded by unit.move_range (≤ 5 typically, so worst-case 60 checks).
## Origin tile is excluded (manhattan == 0 returns false in is_tile_in_move_range).
func get_movable_tiles(unit_id: int) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	if not _units.has(unit_id):
		return result
	var unit: BattleUnit = _units[unit_id]
	for dx: int in range(-unit.move_range, unit.move_range + 1):
		for dy: int in range(-unit.move_range, unit.move_range + 1):
			if absi(dx) + absi(dy) > unit.move_range:
				continue
			var coord: Vector2i = unit.position + Vector2i(dx, dy)
			if is_tile_in_move_range(coord, unit_id):
				result.append(Vector2(coord))
	return result


## Enumerates the set of tiles the unit can legally attack. Reuses
## is_tile_in_attack_range as the single source of truth, so the preview
## cannot drift from the click-time check. Scans the Manhattan diamond
## bounded by unit.attack_range (≤ 2 for MVP, worst-case 12 checks).
func get_attackable_tiles(unit_id: int) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	if not _units.has(unit_id):
		return result
	var unit: BattleUnit = _units[unit_id]
	for dx: int in range(-unit.attack_range, unit.attack_range + 1):
		for dy: int in range(-unit.attack_range, unit.attack_range + 1):
			if absi(dx) + absi(dy) > unit.attack_range:
				continue
			var coord: Vector2i = unit.position + Vector2i(dx, dy)
			if is_tile_in_attack_range(coord, unit_id):
				result.append(Vector2(coord))
	return result


## Returns the currently selected unit_id, or -1 if no unit is selected.
func get_selected_unit_id() -> int:
	return _selected_unit_id


## get_battle_unit() — cross-epic forward-prep (battle-hud story-003).
## Returns the BattleUnit for the given unit_id, or null if not found.
## Added to support BattleHUD.show_unit_info() hero_id resolution path.
## Read-only query per ADR-0014 §3 contract.
func get_battle_unit(unit_id: int) -> BattleUnit:
	return _units.get(unit_id)


## Returns the unit_id of the unit whose turn is currently ACTING. -1 if no
## unit is active (between turns, before battle start, after resolution).
## Used by view-layer code (battle_scene) to track the active-turn highlight
## through slides without having to subscribe to active_unit_changed separately.
func get_active_turn_unit_id() -> int:
	return _active_turn_unit_id


## Returns an opaque snapshot of battle state for AI consumer (Battle AI ADR).
## Shape is intentionally unspecified at MVP; callers must not rely on field names.
func get_battle_state_snapshot() -> Dictionary:
	# TODO (Battle AI ADR — not yet written; sprint-7+): populate FSM state, unit
	# positions, acted flags. Shape locked at ADR authoring time per ADR-0014 §10
	# Key Interfaces (opaque shape) + ADR-0014 line 598.
	return {}


## Per ADR-0014 §Amendment 2026-05-10 (#2 — player-path mirror).
## Player explicitly ends turn (`end_unit_turn` action). For each player-side
## alive unit that has NOT acted, declare WAIT to release the T5 await per
## S15-A `_maybe_defer_turn_completion` (action_token_spent == true).
## Preserves existing end_player_turn() side effects (deselect + auto-handoff).
func _handle_player_end_turn() -> void:
	for unit: BattleUnit in _units.values():
		if unit.side != 0:
			continue  # player-side only
		if not _hp_controller.is_alive(unit.unit_id):
			continue  # dead units don't WAIT
		if _acted_this_turn.get(unit.unit_id, false):
			continue  # already declared an action this turn
		_acted_this_turn[unit.unit_id] = true
		_turn_runner.declare_action(unit.unit_id,
			TurnOrderRunner.ActionType.WAIT, null)
	end_player_turn()


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
	_moved_this_turn.clear()
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
	# Eyeball trace — kept lean enough to leave on; helps the user diagnose
	# why a click did or didn't do what they expected.
	_trace("[CLICK] action=%s coord=%s unit_id=%d state=%d active=%d selected=%d" %
		[action, str(coord), ctx.target_unit_id, int(_state),
		_active_turn_unit_id, _selected_unit_id])
	handle_grid_click(action, coord, ctx.target_unit_id)


func _on_unit_died(unit_id: int) -> void:
	if _battle_over:
		return  # AC-7 terminal-state guard — no further outcome processing
	# Re-emit as a controller-scoped signal for scene-tier visual handlers
	# (BattleScene polygon hide). Fires before _check_battle_end so the visual
	# update lands even if this death resolves the battle.
	unit_visual_died.emit(unit_id)
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
	# Per ADR-0019 + grid-battle.md CR-3: AI-turn detection + ai_action_requested emission.
	# When the active turn unit is non-player-controlled, emit ai_action_requested
	# so that AISystem (battle-scoped Node 6th invocation) can produce an action.
	if _battle_over:
		return
	if not _units.has(unit_id):
		return
	var unit: BattleUnit = _units[unit_id]
	if unit == null:
		return
	# Track the active turn unit so click handlers can reject input on other own
	# units (only the active unit may move/attack on a given turn).
	_active_turn_unit_id = unit_id
	_trace("[TURN] active unit changed to %d (side=%d, player=%s)" %
		[unit_id, unit.side, unit.is_player_controlled])
	# Auto-deselect a stale selection if the new active unit differs — keeps
	# the gold-outline + range overlays on the unit the player can actually move.
	if _selected_unit_id != -1 and _selected_unit_id != unit_id:
		_deselect()
	# View-layer hook for the turn indicator. Fires for BOTH player and AI turns
	# so the on-grid cue tracks every active unit, not just AI dispatch entries.
	active_unit_changed.emit(unit_id)
	# AI dispatch happens via TurnOrderRunner T5 _action_controller →
	# _on_turn_runner_action_request (NATURAL-LOOP path per S15-J amendment).
	# Pre-S15-J emit removed here to prevent ai_action_requested dup-fire.


## Builds a flat-data BattleStateSnapshot from the current battle state.
## Called by `_on_unit_turn_started` for AI-turn entries. Read-only — does not
## mutate _units, _map_grid, _hp_controller, or _turn_runner. Per ADR-0019
## §Decision §Payload Form.
func _make_battle_state_snapshot() -> BattleStateSnapshot:
	var snap: BattleStateSnapshot = BattleStateSnapshot.new()
	# Per-unit data.
	for u: BattleUnit in _units.values():
		var hp_curr: int = _hp_controller.get_current_hp(u.unit_id) if _hp_controller != null else 0
		var hp_mx: int = _hp_controller.get_max_hp(u.unit_id) if _hp_controller != null else 1
		var alive: bool = _hp_controller.is_alive(u.unit_id) if _hp_controller != null else true
		snap.units.append({
			"unit_id": u.unit_id,
			# S13-12: read from BattleUnit.archetype field directly. Prior code
			# read u.tag as the archetype source, which conflated the fate-counter
			# role (`tank`/`assassin`/`boss`) with the AI archetype dispatch bucket
			# (`aggressor`/`skirmisher`/`holder`/`coordinator`). When a chapter has a
			# coordinator-archetyped unit mapped to tag=`boss` for fate tracking,
			# the conflated read leaked `boss` into AISystem and fell through to
			# the EC-AI-4 unknown-archetype warning path (×4+ per battle).
			"archetype": u.archetype,
			"position": u.position,
			"hp_current": hp_curr,
			"hp_max": hp_mx,
			"atk": u.raw_atk,
			"def": u.raw_def,
			"move_range": u.move_range,
			"attack_range": u.attack_range,
			"side": u.side,
			"is_player_controlled": u.is_player_controlled,
			"passive_id": &"",
			"tag": u.tag,
			"is_alive": alive,
		})
	# Map dimensions + terrain grid.
	if _map_grid != null:
		var dims: Vector2i = _map_grid.get_map_dimensions()
		snap.map_dimensions = dims
		# Build flat row-major terrain grid for snapshot consumers.
		var grid: PackedInt32Array = PackedInt32Array()
		for row in range(dims.y):
			for col in range(dims.x):
				var tile: MapTileData = _map_grid.get_tile(Vector2i(col, row))
				grid.append(tile.terrain_type if tile != null else 0)
		snap.terrain_grid = grid
	# Round number.
	snap.round_number = _turn_runner.get_current_round_number() if _turn_runner != null else 0
	# Turn queue (best effort; empty if API not available).
	snap.queue_unit_ids = []
	# Chokepoints sourced from ChapterDefinition via set_chokepoints() at chapter-load
	# (S7-05); formation_center = centroid of allied (enemy-side) units' positions.
	snap.chokepoints = _chokepoints.duplicate()
	var enemy_positions: Array[Vector2i] = []
	for u: BattleUnit in _units.values():
		if u.side == 1:
			enemy_positions.append(u.position)
	if not enemy_positions.is_empty():
		var sum: Vector2i = Vector2i.ZERO
		for p: Vector2i in enemy_positions:
			sum += p
		snap.formation_center = Vector2i(sum.x / enemy_positions.size(), sum.y / enemy_positions.size())
	return snap


## Sets chokepoint coords for AISystem holder-archetype scoring. Called by
## BattleScene after ScenarioRunner hydrates the active ChapterDefinition.
## Pure setter — does not emit signals or trigger snapshot rebuilds.
func set_chokepoints(chokepoints: Array[Vector2i]) -> void:
	_chokepoints = chokepoints.duplicate()


## Subscribed to GameBus.unit_turn_ended via CONNECT_DEFERRED in _ready().
## Pure view-layer re-emit so BattleScene can dim the polygon of any unit that
## actually spent a token this turn. _battle_over gate suppresses post-resolve
## dim flicker; subscribers should treat acted=false as a no-op cue.
func _on_unit_turn_ended(unit_id: int, acted: bool) -> void:
	if _battle_over:
		return
	unit_turn_ended_visual.emit(unit_id, acted)


## Subscribed to GameBus.round_started via CONNECT_DEFERRED in _ready().
## Per ADR-0014 §7 + story-007 AC-3: when round_num exceeds _max_turns, emit
## battle_outcome_resolved with TURN_LIMIT_REACHED outcome. _max_turns is
## loaded from BalanceConstants(MAX_TURNS_PER_BATTLE)=5 in _ready().
func _on_round_started(round_num: int) -> void:
	if _battle_over:
		return  # AC-7 terminal-state guard
	# Clear per-round per-unit action flags so units can act in the new round.
	# Without this, _handle_grid_click_observation silently rejects re-selection
	# of any unit that acted in the prior round (user-reported "after 2 moves
	# the unit can't be selected again" symptom).
	_acted_this_turn.clear()
	_moved_this_turn.clear()
	round_started_visual.emit(round_num)
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
	# Active-turn enforcement: only the unit whose turn is ACTING may be selected.
	# Prior behavior allowed any own unit to be selected, then declare_action would
	# silently fail with NOT_UNIT_TURN — confusing the player into thinking input
	# was broken. Now the click is rejected upfront with a console hint.
	if _active_turn_unit_id != -1 and unit_id != _active_turn_unit_id:
		_trace("[TURN] Not unit %d's turn — active unit is %d" % [unit_id, _active_turn_unit_id])
		return
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
			# Toggle: clicking the selected unit again ends its turn if it has
			# already moved (declare WAIT — finalises the turn so the next unit
			# can act). If it hasn't moved yet, just deselect (existing flow).
			if unit_id == _selected_unit_id:
				if _moved_this_turn.get(_selected_unit_id, false):
					_trace("[HINT] unit %d re-clicked after move — declaring WAIT to end turn" % _selected_unit_id)
					_acted_this_turn[_selected_unit_id] = true
					_turn_runner.declare_action(_selected_unit_id, TurnOrderRunner.ActionType.WAIT, null)
					_deselect()
				else:
					_deselect()
				return
			# Production click disambiguation: every grid action (unit_select /
			# move_target_select / attack_target_select / …) is bound to MOUSE_LEFT
			# in default_bindings.json. InputRouter's first-match-wins resolves any
			# left-click to `unit_select`. In S1 we re-classify by ctx:
			#   empty tile in move range  → MOVE
			#   enemy tile in attack range → ATTACK
			#   different own unit        → silent (MVP — deselect first)
			if not _units.has(_selected_unit_id):
				return  # defensive — selection orphaned
			var selector: BattleUnit = _units[_selected_unit_id]
			if unit_id == -1:
				if is_tile_in_move_range(coord, _selected_unit_id):
					_handle_player_move(selector, coord)
			elif _units.has(unit_id) and _units[unit_id].side != selector.side:
				if is_tile_in_attack_range(coord, _selected_unit_id):
					_handle_player_attack(_selected_unit_id, unit_id)
		"move_cancel", "attack_cancel":
			_deselect()
		"move_target_select", "move_confirm":
			# Per ADR-0014 §Amendment 2026-05-10 (#2): dispatch to _handle_player_move
			# (not _handle_move) so declare_action emits correctly-typed MOVE token.
			# is_tile_in_move_range guard is redundant with _handle_player_move's
			# internal check but harmless — leaves story-004/005/006 guarantees intact.
			if is_tile_in_move_range(coord, _selected_unit_id):
				_handle_player_move(_units[_selected_unit_id], coord)
		"attack_target_select", "attack_confirm":
			# Per ADR-0014 §Amendment 2026-05-10 (#2): dispatch to _handle_player_attack.
			if is_tile_in_attack_range(coord, _selected_unit_id):
				_handle_player_attack(_selected_unit_id, unit_id)
		"end_unit_turn":
			# Per ADR-0014 §Amendment 2026-05-10 (#2): dispatch to _handle_player_end_turn
			# which declares WAIT for unacted units before calling end_player_turn().
			_handle_player_end_turn()
		_:
			# undo_last_move / grid_hover / unrecognized → silent (MVP scope)
			return


## Selects a unit. Transitions state to UNIT_SELECTED + emits unit_selected_changed
## with (new_unit_id, prev_selected_unit_id). Per ADR-0014 §8 + story-003 AC-5.
func _select_unit(unit_id: int) -> void:
	var prev: int = _selected_unit_id
	_selected_unit_id = unit_id
	_state = BattleState.UNIT_SELECTED
	_trace("[SELECT] unit=%d (active=%d)" % [unit_id, _active_turn_unit_id])
	unit_selected_changed.emit(unit_id, prev)


## Deselects the current unit. Transitions state to OBSERVATION + emits
## unit_selected_changed(-1, prev_selected_unit_id) per ADR-0014 §8.
func _deselect() -> void:
	var prev: int = _selected_unit_id
	_selected_unit_id = -1
	_state = BattleState.OBSERVATION
	unit_selected_changed.emit(-1, prev)


# ─── Action handler stubs (filled by stories 004-005) ───────────────────────

## Per ADR-0014 §Amendment 2026-05-10 (#2 — player-path mirror).
## Mirrors AI-path bypass (_on_ai_action_ready MOVE arm): calls _do_move directly
## (not _handle_move wrapper) to avoid _consume_unit_action's hardcoded
## declare_action(ATTACK). Player MOVE must declare correctly-typed MOVE so
## _maybe_defer_turn_completion (S15-A) keeps the turn open for follow-up ATTACK.
func _handle_player_move(unit: BattleUnit, dest: Vector2i) -> void:
	if _active_turn_unit_id != -1 and unit.unit_id != _active_turn_unit_id:
		return  # not this unit's turn — declare would silent-fail anyway; reject early
	if _acted_this_turn.get(unit.unit_id, false):
		return  # turn already terminal (attacked/waited) — no more moves
	if _moved_this_turn.get(unit.unit_id, false):
		_trace("[HINT] unit %d already moved this turn — click an enemy to attack OR click the unit itself to skip" % unit.unit_id)
		return  # MOVE token already spent — one move per turn
	if not is_tile_in_move_range(dest, unit.unit_id):
		return  # invalid target — silent
	_do_move(unit, dest)
	_moved_this_turn[unit.unit_id] = true
	_turn_runner.declare_action(unit.unit_id, TurnOrderRunner.ActionType.MOVE,
		_make_move_target(dest))


## Per ADR-0014 §Amendment 2026-05-10 (#2 — player-path mirror).
## Mirrors AI-path bypass for the attack action.
func _handle_player_attack(attacker_id: int, defender_id: int) -> void:
	if _active_turn_unit_id != -1 and attacker_id != _active_turn_unit_id:
		return  # not this unit's turn — declare would silent-fail anyway; reject early
	if _acted_this_turn.get(attacker_id, false):
		return  # re-entrancy guard
	if not _units.has(attacker_id) or not _units.has(defender_id):
		return  # defensive — shouldn't happen if dispatch is correct
	var attacker: BattleUnit = _units[attacker_id]
	var defender: BattleUnit = _units[defender_id]
	if not is_tile_in_attack_range(defender.position, attacker_id):
		return  # invalid target — silent
	_resolve_attack(attacker, defender)
	_acted_this_turn[attacker_id] = true
	_turn_runner.declare_action(attacker_id, TurnOrderRunner.ActionType.ATTACK,
		_make_attack_target(defender_id))


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
	if dest == old_pos:
		return  # no-op move — don't churn occupancy bookkeeping
	# Pre-flight: destination must be vacant (the AI snapshot can stale-vote a
	# tile that another unit moved into in the same frame). Without this guard
	# _map_grid.set_occupant raises ERR_ILLEGAL_STATE_TRANSITION and the unit
	# ends up at dest in unit data but with clear_occupant'd old_pos in map_grid.
	# Use tile_state (not occupant_id) — occupant_id == 0 ambiguously means both
	# "empty" AND "occupied by unit 0" (the commander has id 0).
	var dest_tile: MapTileData = _map_grid.get_tile(dest)
	if dest_tile != null and (dest_tile.tile_state == MapGrid.TILE_STATE_ALLY_OCCUPIED \
			or dest_tile.tile_state == MapGrid.TILE_STATE_ENEMY_OCCUPIED):
		return  # tile occupied; silent reject (caller's range check was stale)
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
	_trace("[BATTLE-END] outcome=%s" % outcome)
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


## Per ADR-0014 §Amendment 2026-05-10 (#3 — production-wiring residual closure).
## Bridges T5 await per ADR-0011 §Amendment 2026-05-09 to the appropriate
## consumer subscriber: enemy-side via ai_action_requested emit → AISystem.decide
## → ai_action_ready chain (S15-B); player-side defers to natural grid-click input
## → _handle_player_* helpers (S15-C). Returns immediately for player units (T5
## stays paused until player declare_action fires); triggers AI dispatch for enemies.
##
## Registered as the _action_controller Callable on TurnOrderRunner by BattleScene
## STEP 5 (see battle_scene.gd S15-J insertion) so T5 calls this instead of the
## TEST-SEAM no-op pass.
##
## IMPORTANT: `snapshot` is a TurnOrderSnapshot (the type T5 passes), NOT UnitTurnState
## or BattleStateSnapshot. The parameter is typed TurnOrderSnapshot here to satisfy
## the Callable contract; this handler does not read it. For AI dispatch, a
## BattleStateSnapshot is built fresh via _make_battle_state_snapshot().
func _on_turn_runner_action_request(unit_id: int, snapshot: TurnOrderSnapshot) -> void:
	var unit: BattleUnit = _units.get(unit_id, null)
	if unit == null:
		push_warning("S15-J: _on_turn_runner_action_request received unknown unit_id=%d" % unit_id)
		return
	match unit.side:
		0:  # player — natural input path (S15-C); T5 stays paused until grid-click fires declare_action
			return
		1:  # enemy — synchronous AI dispatch via existing ai_action_requested → AISystem chain (S15-B)
			var battle_snapshot: BattleStateSnapshot = _make_battle_state_snapshot()
			ai_action_requested.emit(unit_id, battle_snapshot)
		_:
			push_warning("S15-J: unknown unit.side=%d for unit_id=%d" % [unit.side, unit_id])
