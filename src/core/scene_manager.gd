## SceneManager — the single owner of Overworld ↔ BattleScene transitions.
##
## Ratified by ADR-0002. Consumes GameBus signals per ADR-0001.
##
## RULES:
##   - SceneManager owns scene-transition lifecycle ONLY. It does not hold
##     gameplay state.
##   - All transitions are signal-driven. There are no public imperative
##     transition methods; callers emit on GameBus and SceneManager reacts.
##   - Overworld is retained (paused + hidden) during battle, NOT freed.
##   - BattleScene is freed via call_deferred to ensure co-subscriber
##     deferred handlers complete before freeing.
##
## Load order: 2nd autoload, after GameBus (see TR-scene-manager-001).
##
## NOTE (G-3): This script is registered as autoload "SceneManager" in
## project.godot. It must NOT declare class_name SceneManager — that
## would cause "Class hides autoload singleton" parse error.
## The autoload name IS the global identifier.
##
## See ADR-0002 §Decision for state machine and topology.
extends Node

# ── Constants and enums ───────────────────────────────────────────────────────

## FSM state set. Per TR-scene-manager-001 and ADR-0002 §State Machine.
## Append-only — never renumber (same discipline as BattleOutcome.Result).
enum State {
	IDLE,                   ## 0 — no transition in progress; normal gameplay
	LOADING_BATTLE,         ## 1 — async battle scene load underway
	IN_BATTLE,              ## 2 — battle scene live; overworld paused+hidden
	RETURNING_FROM_BATTLE,  ## 3 — outcome received; teardown scheduled
	ERROR,                  ## 4 — load failed; waiting for retry
}

# ── Public variables ──────────────────────────────────────────────────────────

## Read-only FSM state. Changes via internal signal handlers only.
## Writes are rejected with push_error; external code must never write directly.
var state: State = State.IDLE:
	get:
		return _state
	set(_v):
		push_error("SceneManager.state is read-only; state transitions via signal handlers")

## Async-load progress in [0.0, 1.0]. Valid only while state == LOADING_BATTLE.
## UI reads this as a property query — NOT via bus traffic (per ADR-0001 §5).
var loading_progress: float = 0.0

# ── Private variables ─────────────────────────────────────────────────────────

var _state: State = State.IDLE
## Overworld scene root. Declared as CanvasItem because _pause_overworld/_restore_overworld
## mutate .visible (CanvasItem-only). Production Overworld scenes are always Node2D- or
## Control-rooted. Story 004 will populate via get_tree().current_scene as CanvasItem.
var _overworld_ref: CanvasItem = null
var _battle_scene_ref: Node = null
var _load_path: String = ""
var _load_timer: Timer = null

# ── Built-in virtual methods ──────────────────────────────────────────────────

func _ready() -> void:
	## Create and mount the load-poll Timer (100 ms cadence, non-autostarting).
	## Cadence keeps SceneManager off the per-frame _process path (ADR-0001 §7).
	_load_timer = Timer.new()
	_load_timer.wait_time = 0.1
	_load_timer.one_shot = false
	_load_timer.autostart = false
	_load_timer.timeout.connect(_on_load_tick)
	add_child(_load_timer)

	## Subscribe to GameBus signals with CONNECT_DEFERRED per ADR-0001.
	GameBus.battle_launch_requested.connect(_on_battle_launch_requested, CONNECT_DEFERRED)
	GameBus.battle_outcome_resolved.connect(_on_battle_outcome_resolved, CONNECT_DEFERRED)


func _exit_tree() -> void:
	## Disconnect GameBus subscriptions guarded by is_connected to avoid
	## double-disconnect errors (e.g. if called during test cleanup or scene reload).
	if GameBus.battle_launch_requested.is_connected(_on_battle_launch_requested):
		GameBus.battle_launch_requested.disconnect(_on_battle_launch_requested)
	if GameBus.battle_outcome_resolved.is_connected(_on_battle_outcome_resolved):
		GameBus.battle_outcome_resolved.disconnect(_on_battle_outcome_resolved)

# ── Signal callbacks ──────────────────────────────────────────────────────────

## Handles battle_launch_requested from GameBus.
## Validates payload, guards against duplicate/in-progress transitions, initiates
## async BattleScene load, pauses the Overworld, and starts the poll Timer.
## State transition: IDLE/ERROR → LOADING_BATTLE.
## Per ADR-0002 §Key Interfaces + §Risks "Nested battles explicit rejection".
func _on_battle_launch_requested(payload: BattlePayload) -> void:
	if not is_instance_valid(payload):
		push_warning("battle_launch_requested: invalid payload; ignored")
		return
	if _state != State.IDLE and _state != State.ERROR:
		push_warning(
			("battle_launch_requested: already transitioning (state=%s); ignored")
			% State.keys()[_state]
		)
		return
	_state = State.LOADING_BATTLE
	# get_tree().current_scene returns Node; cast to CanvasItem because
	# _pause_overworld/_restore_overworld mutate .visible (CanvasItem-only).
	# If the current scene is not a CanvasItem (e.g., test fixtures), the cast
	# returns null and _pause_overworld no-ops via its is_instance_valid guard.
	_overworld_ref = get_tree().current_scene as CanvasItem
	_pause_overworld()
	GameBus.ui_input_block_requested.emit("scene_transition")
	_load_path = _resolve_battle_scene_path(payload.map_id)
	var err: Error = ResourceLoader.load_threaded_request(_load_path, "PackedScene", true)
	if err != OK:
		_transition_to_error("load_request_failed: %s" % error_string(err))
		return
	_load_timer.start()


## Handles battle_outcome_resolved from GameBus.
## Validates payload and state, transitions to RETURNING_FROM_BATTLE, and schedules
## BattleScene teardown + Overworld restore via call_deferred for co-subscriber safety.
## Per ADR-0002 §Key Interfaces + §Risks R-1 (co-subscriber deferred-free race).
## State transition: IN_BATTLE → RETURNING_FROM_BATTLE (synchronous), then → IDLE (deferred).
func _on_battle_outcome_resolved(outcome: BattleOutcome) -> void:
	if not is_instance_valid(outcome):
		push_warning("battle_outcome_resolved: invalid payload; ignored")
		return
	if _state != State.IN_BATTLE:
		push_warning(
			"battle_outcome_resolved outside IN_BATTLE (state=%s); ignored"
			% State.keys()[_state]
		)
		return
	_state = State.RETURNING_FROM_BATTLE
	# Push BattleScene free one additional frame so co-subscriber
	# (ScenarioRunner) deferred handlers completing in the same frame
	# can still read BattleScene node references safely. See ADR-0002
	# §Risks and godot-specialist validation B-3.
	call_deferred("_free_battle_scene_and_restore_overworld")


## Polls ResourceLoader load status at 100 ms intervals during LOADING_BATTLE.
## Reads progress out-param array, updates loading_progress, and dispatches on
## LOADED (instantiate) or FAILED/INVALID (error). Timer-driven, not per-frame.
## Per ADR-0002 §Key Interfaces.
func _on_load_tick() -> void:
	if _state != State.LOADING_BATTLE:
		_load_timer.stop()
		return
	var progress: Array = []
	var status: int = ResourceLoader.load_threaded_get_status(_load_path, progress)
	if progress.size() > 0:
		loading_progress = progress[0]
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			_load_timer.stop()
			_instantiate_and_enter_battle()
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE, ResourceLoader.THREAD_LOAD_FAILED:
			_load_timer.stop()
			_transition_to_error("load_failed: status=%d" % status)
		ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			pass  # keep polling

# ── Overworld pause / restore ─────────────────────────────────────────────────

## Suppresses the Overworld scene while a BattleScene is live.
## Applies four suppression properties and disables the root Control's mouse
## filter if a "UIRoot" Control child exists.
## Guard: no-op if _overworld_ref is null or freed.
## Called internally by the battle-entry path (story-004). NOT a public API.
func _pause_overworld() -> void:
	if not is_instance_valid(_overworld_ref):
		return
	_overworld_ref.process_mode = Node.PROCESS_MODE_DISABLED
	_overworld_ref.visible = false
	_overworld_ref.set_process_input(false)
	_overworld_ref.set_process_unhandled_input(false)
	var root_control := _overworld_ref.get_node_or_null("UIRoot") as Control
	if root_control != null:
		root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE


## Restores the Overworld scene after a BattleScene exits.
## Inverts all four suppression properties and restores the root Control's
## mouse filter if a "UIRoot" Control child exists.
## Guard: no-op if _overworld_ref is null or freed.
## Called internally by the battle-exit path (story-005). NOT a public API.
func _restore_overworld() -> void:
	if not is_instance_valid(_overworld_ref):
		return
	_overworld_ref.process_mode = Node.PROCESS_MODE_INHERIT
	_overworld_ref.visible = true
	_overworld_ref.set_process_input(true)
	_overworld_ref.set_process_unhandled_input(true)
	var root_control := _overworld_ref.get_node_or_null("UIRoot") as Control
	if root_control != null:
		root_control.mouse_filter = Control.MOUSE_FILTER_STOP

# ── Battle exit helpers ───────────────────────────────────────────────────────

## Frees the BattleScene and restores the Overworld after battle_outcome_resolved.
## Called via call_deferred from _on_battle_outcome_resolved — fires one frame after
## the outcome handler so co-subscriber CONNECT_DEFERRED handlers complete first.
## Per ADR-0002 §Key Interfaces _free_battle_scene_and_restore_overworld.
func _free_battle_scene_and_restore_overworld() -> void:
	if is_instance_valid(_battle_scene_ref):
		_battle_scene_ref.queue_free()
	_battle_scene_ref = null
	_restore_overworld()
	_state = State.IDLE
	loading_progress = 0.0
	# Focus restoration: Overworld UI subscribes to its own visibility_changed
	# and restores the pre-battle focused Control. SceneManager does NOT
	# touch focus state. See ADR-0002 §Risks R-3.

# ── Async-load helpers ────────────────────────────────────────────────────────

## Retrieves the loaded PackedScene, instantiates it as a /root peer,
## transitions to IN_BATTLE, and unblocks UI input.
## Called only from _on_load_tick when THREAD_LOAD_LOADED is received.
## Per ADR-0002 §Key Interfaces _instantiate_and_enter_battle.
func _instantiate_and_enter_battle() -> void:
	var packed: PackedScene = ResourceLoader.load_threaded_get(_load_path) as PackedScene
	if packed == null:
		_transition_to_error("load_threaded_get returned null")
		return
	_battle_scene_ref = packed.instantiate()
	get_tree().root.add_child(_battle_scene_ref)
	_state = State.IN_BATTLE
	loading_progress = 1.0
	GameBus.ui_input_unblock_requested.emit("scene_transition")


## Maps a map_id to its canonical BattleScene resource path.
## Convention: res://scenes/battle/<map_id>.tscn (ADR-0002 §Path Resolution).
## The template is a build-time convention; map_id IS the data input.
## No file-existence check needed — ResourceLoader surfaces missing files via
## THREAD_LOAD_FAILED status, which routes to _transition_to_error.
func _resolve_battle_scene_path(map_id: String) -> String:
	return "res://scenes/battle/%s.tscn" % map_id


## Transitions the FSM to ERROR state and signals the failure to listeners.
## Resets loading_progress, emits scene_transition_failed + ui_input_unblock_requested,
## and restores the Overworld so the error dialog ScenarioRunner shows is visible.
## Per ADR-0002 §Key Interfaces _transition_to_error + §Risks R-2 (error dialog visibility).
## Called by: _on_battle_launch_requested (err != OK), _on_load_tick (FAILED/INVALID),
## _instantiate_and_enter_battle (null packed).
## Exit from ERROR state: only via battle_launch_requested re-emit (retry — story-004 guard accepts ERROR).
func _transition_to_error(reason: String) -> void:
	_state = State.ERROR
	loading_progress = 0.0
	GameBus.scene_transition_failed.emit("scene_manager", reason)
	GameBus.ui_input_unblock_requested.emit("scene_transition")
	_restore_overworld()   # DRY — story-003; restores 4 properties + UIRoot mouse_filter
