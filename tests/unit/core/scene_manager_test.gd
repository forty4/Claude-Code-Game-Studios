extends GdUnitTestSuite

## scene_manager_test.gd
## Unit tests for Story 001: SceneManager autoload + 5-state FSM skeleton.
##
## Covers AC-1 through AC-8 per story QA Test Cases.
##
## TEST SEAMS USED:
##   load(PATH).new() — instantiates a fresh SceneManager script instance (not
##     the autoload singleton). Required because autoload scripts must NOT declare
##     class_name (G-3: autoload name collision rule), so SceneManager.new() is
##     unavailable.
##   sm._exit_tree() — called directly in AC-6 to exercise disconnect guards
##     without removing the node from the tree.
##   sm.get_node_or_null("Timer") — Timer node is accessed by type name; the
##     Timer is the only child added in _ready so the name is deterministic.
##
## ISOLATION STRATEGY:
##   Each test creates a fresh SceneManager instance via load(PATH).new(). Tests
##   that need the node in a SceneTree call add_child(sm) so _ready() fires
##   naturally. Tests that do not need the tree (AC-3, AC-8) avoid add_child
##   entirely. Explicit free() is used per G-6 (orphan detection fires before
##   after_test; queue_free() would leave an orphan in the scan window).
##
## GOTCHA AWARENESS:
##   G-3 — no class_name on autoload scripts → use load(PATH).new()
##   G-6 — GdUnit4 orphan scan fires before after_test → free() not queue_free()
##   G-8 — Signal.get_connections() returns untyped Array → loop with typed var

const SCENE_MANAGER_PATH: String = "res://src/core/scene_manager.gd"
const GAME_BUS_PATH: String = "res://src/core/game_bus.gd"


# ── Helpers ───────────────────────────────────────────────────────────────────


## Instantiates a fresh SceneManager and adds it to the test tree so _ready fires.
## Returns the mounted node. Caller is responsible for calling sm.free() at test end.
func _make_scene_manager() -> Node:
	var sm: Node = (load(SCENE_MANAGER_PATH) as GDScript).new()
	add_child(sm)
	return sm


# ── AC-2: Initial state ───────────────────────────────────────────────────────


## AC-2: state == IDLE immediately after _ready.
## Given: SceneManager mounted (add_child triggers _ready).
## When: read SceneManager.state.
## Then: equals State.IDLE (int 0).
func test_scene_manager_initial_state_is_idle() -> void:
	# Arrange + Act
	var sm: Node = _make_scene_manager()

	# Assert
	var got: int = sm.state as int
	assert_int(got).override_failure_message(
		"Expected initial state IDLE (0), got %d" % got
	).is_equal(0)

	# Cleanup (G-6: free before test body exits, not queue_free)
	sm.free()


# ── AC-3: State enum contract ─────────────────────────────────────────────────


## AC-3: Enum values match append-only index contract.
## IDLE=0, LOADING_BATTLE=1, IN_BATTLE=2, RETURNING_FROM_BATTLE=3, ERROR=4.
## Tested without add_child — enum is script-level, no tree required.
func test_scene_manager_state_enum_values_are_stable() -> void:
	# Arrange — load script without mounting (no tree dependency)
	var script: GDScript = load(SCENE_MANAGER_PATH) as GDScript
	var sm: Node = script.new()

	# Act + Assert — compare each enum ordinal against expected index
	assert_int(sm.State.IDLE as int).override_failure_message(
		"State.IDLE must be 0 (append-only contract)"
	).is_equal(0)

	assert_int(sm.State.LOADING_BATTLE as int).override_failure_message(
		"State.LOADING_BATTLE must be 1"
	).is_equal(1)

	assert_int(sm.State.IN_BATTLE as int).override_failure_message(
		"State.IN_BATTLE must be 2"
	).is_equal(2)

	assert_int(sm.State.RETURNING_FROM_BATTLE as int).override_failure_message(
		"State.RETURNING_FROM_BATTLE must be 3"
	).is_equal(3)

	assert_int(sm.State.ERROR as int).override_failure_message(
		"State.ERROR must be 4"
	).is_equal(4)

	# Cleanup
	sm.free()


# ── AC-4: Read-only state accessor ───────────────────────────────────────────


## AC-4: Attempting to write state leaves state unchanged and triggers push_error.
## GdUnit4 does not provide a built-in push_error interceptor in v6.1.2, so
## this test verifies the state is unchanged (the invariant) and trusts that
## push_error fired — an error printed to stdout is acceptable evidence.
func test_scene_manager_state_write_rejected_leaves_state_unchanged() -> void:
	# Arrange
	var sm: Node = _make_scene_manager()
	var before: int = sm.state as int

	# Act — attempt write; this should call push_error internally and leave state unchanged
	# The setter signature is set(_v) → push_error, so the assignment is a no-op externally.
	sm.set("state", 2)  # 2 == IN_BATTLE — must NOT take effect

	# Assert — state is unchanged
	var after: int = sm.state as int
	assert_int(after).override_failure_message(
		"state must remain IDLE (0) after illegal write attempt, got %d" % after
	).is_equal(before)

	# Cleanup
	sm.free()


# ── AC-5: GameBus subscriptions ───────────────────────────────────────────────


## AC-5: SceneManager connects to both GameBus signals in _ready.
## Verifies is_connected returns true for both handler callables.
func test_scene_manager_connects_to_gamebus_signals_on_ready() -> void:
	# Arrange + Act
	var sm: Node = _make_scene_manager()

	# Assert — battle_launch_requested
	var launch_connected: bool = GameBus.battle_launch_requested.is_connected(
		sm._on_battle_launch_requested
	)
	assert_bool(launch_connected).override_failure_message(
		"battle_launch_requested must be connected to _on_battle_launch_requested after _ready"
	).is_true()

	# Assert — battle_outcome_resolved
	var outcome_connected: bool = GameBus.battle_outcome_resolved.is_connected(
		sm._on_battle_outcome_resolved
	)
	assert_bool(outcome_connected).override_failure_message(
		"battle_outcome_resolved must be connected to _on_battle_outcome_resolved after _ready"
	).is_true()

	# Cleanup
	sm.free()


# ── AC-6: Disconnect on exit ──────────────────────────────────────────────────


## AC-6: _exit_tree disconnects both GameBus signals.
## After _exit_tree(), neither signal should have a connection pointing to sm.
## Uses untyped Array + typed loop variable per G-8.
func test_scene_manager_disconnects_gamebus_signals_on_exit_tree() -> void:
	# Arrange
	var sm: Node = _make_scene_manager()

	# Verify subscriptions are present before calling _exit_tree
	assert_bool(GameBus.battle_launch_requested.is_connected(sm._on_battle_launch_requested)).override_failure_message(
		"Pre-condition: battle_launch_requested should be connected before _exit_tree"
	).is_true()

	# Act — call _exit_tree directly (does not remove from tree; exercises disconnect guards)
	sm._exit_tree()

	# Assert — battle_launch_requested has no connection to sm
	# G-8: get_connections() returns untyped Array; loop var narrows element type.
	var launch_conns: Array = GameBus.battle_launch_requested.get_connections()
	var launch_sm_found: bool = false
	for conn: Dictionary in launch_conns:
		var target: Object = conn.get("callable", Callable()).get_object()
		if target == sm:
			launch_sm_found = true
			break
	assert_bool(launch_sm_found).override_failure_message(
		"battle_launch_requested must have no connection to sm after _exit_tree"
	).is_false()

	# Assert — battle_outcome_resolved has no connection to sm
	var outcome_conns: Array = GameBus.battle_outcome_resolved.get_connections()
	var outcome_sm_found: bool = false
	for conn: Dictionary in outcome_conns:
		var target: Object = conn.get("callable", Callable()).get_object()
		if target == sm:
			outcome_sm_found = true
			break
	assert_bool(outcome_sm_found).override_failure_message(
		"battle_outcome_resolved must have no connection to sm after _exit_tree"
	).is_false()

	# Cleanup
	sm.free()


## AC-6 idempotency: calling _exit_tree twice must not error or crash.
## Tests the is_connected guard on a second call when signals are already disconnected.
func test_scene_manager_exit_tree_is_idempotent() -> void:
	# Arrange
	var sm: Node = _make_scene_manager()

	# Act — call twice; second call must not raise errors
	sm._exit_tree()
	sm._exit_tree()  # is_connected guard should prevent double-disconnect error

	# Assert — state after double-exit is still IDLE (no corruption)
	assert_int(sm.state as int).override_failure_message(
		"state must remain IDLE after double _exit_tree call"
	).is_equal(0)

	# Cleanup
	sm.free()


# ── AC-7: Timer child properties ──────────────────────────────────────────────


## AC-7: A Timer child exists after _ready with correct properties.
## wait_time == 0.1, one_shot == false, autostart == false, timeout → _on_load_tick.
## The story explicitly permits any name for the Timer node; we locate it by
## iterating children and matching the Timer type rather than relying on naming.
func test_scene_manager_load_timer_child_properties() -> void:
	# Arrange + Act
	var sm: Node = _make_scene_manager()

	# Find the Timer child by type (robust to name-auto-assignment differences)
	var timer: Timer = null
	for child: Node in sm.get_children():
		if child is Timer:
			timer = child
			break

	assert_object(timer).override_failure_message(
		"SceneManager must have a Timer child after _ready"
	).is_not_null()

	if timer == null:
		sm.free()
		return

	# Assert — wait_time
	assert_float(timer.wait_time).override_failure_message(
		"Timer.wait_time must be 0.1 (100 ms poll cadence per ADR-0002 §Decision)"
	).is_equal(0.1)

	# Assert — one_shot
	assert_bool(timer.one_shot).override_failure_message(
		"Timer.one_shot must be false (repeating poll)"
	).is_false()

	# Assert — autostart
	assert_bool(timer.autostart).override_failure_message(
		"Timer.autostart must be false (timer starts only when loading begins)"
	).is_false()

	# Assert — timeout connected to _on_load_tick (per story AC, Implementation Notes §3)
	assert_bool(timer.timeout.is_connected(sm._on_load_tick)).override_failure_message(
		"Timer.timeout must be connected to _on_load_tick after _ready"
	).is_true()

	# Cleanup
	sm.free()


# ── loading_progress initial value (AC property requirement) ────────────────


## loading_progress must be 0.0 after _ready. Property is in the story AC list
## (line 34) but otherwise has no coverage — populated by later stories.
func test_scene_manager_loading_progress_initial_value_is_zero() -> void:
	# Arrange + Act
	var sm: Node = _make_scene_manager()

	# Assert
	var got: float = sm.loading_progress as float
	assert_float(got).override_failure_message(
		"loading_progress must be 0.0 after _ready, got %f" % got
	).is_equal_approx(0.0, 0.0001)

	# Cleanup (G-6)
	sm.free()


# ── AC-8: project.godot autoload order ───────────────────────────────────────


## AC-8: project.godot [autoload] section has GameBus first, SceneManager second,
## ORDER-SENSITIVE comment present, and GameBusDiagnostics third.
## Reads the raw file rather than querying the engine so this test is independent
## of the running autoload state.
func test_project_godot_autoload_order_is_correct() -> void:
	# Arrange
	const PROJECT_GODOT_PATH: String = "res://project.godot"
	var file: FileAccess = FileAccess.open(PROJECT_GODOT_PATH, FileAccess.READ)
	assert_object(file).override_failure_message(
		"project.godot must be readable at res://project.godot"
	).is_not_null()

	if file == null:
		return

	var content: String = file.get_as_text()
	file.close()

	# Assert — ORDER-SENSITIVE comment is present
	assert_bool(content.contains("ORDER-SENSITIVE")).override_failure_message(
		"project.godot must contain ORDER-SENSITIVE comment in [autoload] section"
	).is_true()

	# Assert — GameBus line present
	assert_bool(content.contains('GameBus="*res://src/core/game_bus.gd"')).override_failure_message(
		'project.godot must contain GameBus="*res://src/core/game_bus.gd"'
	).is_true()

	# Assert — SceneManager line present
	assert_bool(content.contains('SceneManager="*res://src/core/scene_manager.gd"')).override_failure_message(
		'project.godot must contain SceneManager="*res://src/core/scene_manager.gd"'
	).is_true()

	# Assert — GameBus appears before SceneManager (position check)
	var gamebus_pos: int = content.find('GameBus="*res://src/core/game_bus.gd"')
	var scene_manager_pos: int = content.find('SceneManager="*res://src/core/scene_manager.gd"')
	assert_bool(gamebus_pos < scene_manager_pos).override_failure_message(
		("project.godot autoload order violation: GameBus must appear before SceneManager."
		+ " GameBus pos=%d, SceneManager pos=%d") % [gamebus_pos, scene_manager_pos]
	).is_true()

	# Assert — SceneManager appears before GameBusDiagnostics
	var diagnostics_pos: int = content.find('GameBusDiagnostics="*res://src/core/game_bus_diagnostics.gd"')
	assert_bool(scene_manager_pos < diagnostics_pos).override_failure_message(
		("project.godot autoload order violation: SceneManager must appear before GameBusDiagnostics."
		+ " SceneManager pos=%d, GameBusDiagnostics pos=%d") % [scene_manager_pos, diagnostics_pos]
	).is_true()


# ── Story 003: Overworld pause / restore ─────────────────────────────────────


## AC-1: _pause_overworld sets all four suppression properties on _overworld_ref.
## Given: SM + fake Overworld Node at _overworld_ref.
## When: sm._pause_overworld() called.
## Then: process_mode == PROCESS_MODE_DISABLED, visible == false,
##       is_processing_input() == false, is_processing_unhandled_input() == false.
func test_scene_manager_pause_overworld_sets_all_four_properties() -> void:
	# Arrange
	var sm: Node = _make_scene_manager()
	var fake_overworld: Node2D = Node2D.new()
	fake_overworld.name = "OverworldMock"
	add_child(fake_overworld)
	sm.set("_overworld_ref", fake_overworld)

	# Act
	sm._pause_overworld()

	# Assert
	assert_int(fake_overworld.process_mode as int).override_failure_message(
		("process_mode must be PROCESS_MODE_DISABLED (%d) after _pause_overworld, got %d")
		% [Node.PROCESS_MODE_DISABLED, fake_overworld.process_mode as int]
	).is_equal(Node.PROCESS_MODE_DISABLED as int)

	assert_bool(fake_overworld.visible).override_failure_message(
		"visible must be false after _pause_overworld"
	).is_false()

	assert_bool(fake_overworld.is_processing_input()).override_failure_message(
		"is_processing_input() must be false after _pause_overworld"
	).is_false()

	assert_bool(fake_overworld.is_processing_unhandled_input()).override_failure_message(
		"is_processing_unhandled_input() must be false after _pause_overworld"
	).is_false()

	# Cleanup (G-6)
	fake_overworld.free()
	sm.free()


## AC-2: _restore_overworld inverts all four suppression properties on _overworld_ref.
## Given: SM + fake Overworld Node paused via _pause_overworld.
## When: sm._restore_overworld() called.
## Then: process_mode == PROCESS_MODE_INHERIT, visible == true,
##       is_processing_input() == true, is_processing_unhandled_input() == true.
func test_scene_manager_restore_overworld_inverts_all_four_properties() -> void:
	# Arrange
	var sm: Node = _make_scene_manager()
	var fake_overworld: Node2D = Node2D.new()
	fake_overworld.name = "OverworldMock"
	add_child(fake_overworld)
	sm.set("_overworld_ref", fake_overworld)
	sm._pause_overworld()

	# Act
	sm._restore_overworld()

	# Assert
	assert_int(fake_overworld.process_mode as int).override_failure_message(
		("process_mode must be PROCESS_MODE_INHERIT (%d) after _restore_overworld, got %d")
		% [Node.PROCESS_MODE_INHERIT, fake_overworld.process_mode as int]
	).is_equal(Node.PROCESS_MODE_INHERIT as int)

	assert_bool(fake_overworld.visible).override_failure_message(
		"visible must be true after _restore_overworld"
	).is_true()

	assert_bool(fake_overworld.is_processing_input()).override_failure_message(
		"is_processing_input() must be true after _restore_overworld"
	).is_true()

	assert_bool(fake_overworld.is_processing_unhandled_input()).override_failure_message(
		"is_processing_unhandled_input() must be true after _restore_overworld"
	).is_true()

	# Cleanup (G-6)
	fake_overworld.free()
	sm.free()


## AC-3: UIRoot Control mouse_filter toggles on pause and restore.
## Given: fake Overworld with Control child named "UIRoot" (mouse_filter = STOP).
## When: _pause_overworld() → IGNORE; _restore_overworld() → STOP.
func test_scene_manager_pause_restore_overworld_toggles_ui_root_mouse_filter() -> void:
	# Arrange
	var sm: Node = _make_scene_manager()
	var fake_overworld: Node2D = Node2D.new()
	fake_overworld.name = "OverworldMock"
	var ui_root: Control = Control.new()
	ui_root.name = "UIRoot"
	ui_root.mouse_filter = Control.MOUSE_FILTER_STOP
	fake_overworld.add_child(ui_root)
	add_child(fake_overworld)
	sm.set("_overworld_ref", fake_overworld)

	# Act — pause
	sm._pause_overworld()

	# Assert — mouse_filter is IGNORE after pause
	assert_int(ui_root.mouse_filter as int).override_failure_message(
		("UIRoot.mouse_filter must be MOUSE_FILTER_IGNORE (%d) after _pause_overworld, got %d")
		% [Control.MOUSE_FILTER_IGNORE, ui_root.mouse_filter as int]
	).is_equal(Control.MOUSE_FILTER_IGNORE as int)

	# Act — restore
	sm._restore_overworld()

	# Assert — mouse_filter is STOP after restore
	assert_int(ui_root.mouse_filter as int).override_failure_message(
		("UIRoot.mouse_filter must be MOUSE_FILTER_STOP (%d) after _restore_overworld, got %d")
		% [Control.MOUSE_FILTER_STOP, ui_root.mouse_filter as int]
	).is_equal(Control.MOUSE_FILTER_STOP as int)

	# Cleanup (G-6)
	fake_overworld.free()
	sm.free()


## AC-4: _pause_overworld does not crash when no UIRoot child exists.
## The four process properties must still toggle correctly.
func test_scene_manager_pause_overworld_no_ui_root_is_safe() -> void:
	# Arrange — fake Overworld with NO UIRoot child
	var sm: Node = _make_scene_manager()
	var fake_overworld: Node2D = Node2D.new()
	fake_overworld.name = "OverworldMock"
	add_child(fake_overworld)
	sm.set("_overworld_ref", fake_overworld)

	# Act — must not crash
	sm._pause_overworld()

	# Assert — four properties still toggled
	assert_int(fake_overworld.process_mode as int).override_failure_message(
		"process_mode must be PROCESS_MODE_DISABLED even without UIRoot"
	).is_equal(Node.PROCESS_MODE_DISABLED as int)

	assert_bool(fake_overworld.visible).override_failure_message(
		"visible must be false even without UIRoot"
	).is_false()

	assert_bool(fake_overworld.is_processing_input()).override_failure_message(
		"is_processing_input() must be false even without UIRoot"
	).is_false()

	assert_bool(fake_overworld.is_processing_unhandled_input()).override_failure_message(
		"is_processing_unhandled_input() must be false even without UIRoot"
	).is_false()

	# Cleanup (G-6)
	fake_overworld.free()
	sm.free()


## AC-5: Null _overworld_ref guard — pause and restore are no-ops, no crash.
## Given: _overworld_ref == null (never assigned).
## When: _pause_overworld() and _restore_overworld() called.
## Then: no crash; SM state unchanged.
func test_scene_manager_pause_restore_overworld_null_ref_is_noop() -> void:
	# Arrange — _overworld_ref defaults to null
	var sm: Node = _make_scene_manager()

	# Act + Assert — must not crash
	sm._pause_overworld()
	sm._restore_overworld()

	# Post-condition: state is still IDLE (no corruption)
	assert_int(sm.state as int).override_failure_message(
		"state must remain IDLE after pause/restore on null _overworld_ref"
	).is_equal(0)

	# Cleanup (G-6)
	sm.free()


## AC-6: Freed _overworld_ref guard — is_instance_valid catches freed Node, no crash.
## Given: a Node assigned to _overworld_ref, then freed before _pause_overworld.
## When: _pause_overworld() and _restore_overworld() called.
## Then: is_instance_valid returns false → early return → no crash.
func test_scene_manager_pause_restore_overworld_freed_ref_is_noop() -> void:
	# Arrange
	var sm: Node = _make_scene_manager()
	var fake_overworld: Node = Node.new()
	sm.set("_overworld_ref", fake_overworld)
	# Free the Node without going through the tree (it was never add_child'd)
	fake_overworld.free()

	# Act + Assert — must not crash even though _overworld_ref points at freed memory
	sm._pause_overworld()
	sm._restore_overworld()

	# Post-condition: state is still IDLE (no corruption)
	assert_int(sm.state as int).override_failure_message(
		"state must remain IDLE after pause/restore on freed _overworld_ref"
	).is_equal(0)

	# Cleanup (G-6) — fake_overworld already freed; only free sm
	sm.free()


# ── Story 004: Async-load state machine ──────────────────────────────────────


## AC-2: State guard rejects battle_launch_requested when already in IN_BATTLE.
##
## ISOLATION ROOT CAUSE (discovered story-004 round 3):
##   GameBusStub.swap_in() replaces /root/GameBus, but the GDScript autoload
##   identifier `GameBus` is bound at registration time, not dynamically. When
##   the stub SM's _ready() calls `GameBus.battle_launch_requested.connect(...)`,
##   `GameBus` resolves to the ORIGINAL registered autoload (the production instance,
##   now detached). Emitting on bus_stub never reaches the stub SM's handler.
##   Fix: emit on the real `GameBus` autoload; use only SceneManagerStub.swap_in().
##
## GUARD TEST DESIGN:
##   Force state to IN_BATTLE (2) — a state the guard MUST reject (not IDLE or ERROR).
##   Observe that `ui_input_block_requested` is NOT emitted, proving the guard exited
##   before the full entry path ran. Capture via G-4-compliant Array captures pattern.
##   State must remain IN_BATTLE (it is NOT reset to IDLE/ERROR by the guard).
##
## G-6: explicit SceneManagerStub.swap_out() at end of body.
func test_scene_manager_state_guard_rejects_launch_during_loading_battle() -> void:
	# Arrange — swap in SM stub only; emit on real GameBus (autoload identifier)
	var sm: Node = SceneManagerStub.swap_in()

	# Force state to IN_BATTLE — guard must reject this (not IDLE, not ERROR)
	sm.set("_state", sm.State.IN_BATTLE as int)

	# Capture ui_input_block_requested emits via G-4 pattern (Array mutation, not
	# primitive reassign). If the guard fires correctly, this signal is never emitted.
	# Store the Callable explicitly so we can disconnect it in cleanup if it never fired
	# (CONNECT_ONE_SHOT auto-disconnects on first fire; if guard works it never fires,
	# leaving the connection live — explicit disconnect prevents cross-test pollution).
	var block_captures: Array = []
	var block_listener: Callable = func(reason: String) -> void:
		block_captures.append(reason)
	GameBus.ui_input_block_requested.connect(block_listener, CONNECT_ONE_SHOT)

	var payload: BattlePayload = BattlePayload.new()
	payload.map_id = "test_guard_map"

	# Act — emit on the REAL GameBus autoload; stub SM is subscribed to it
	GameBus.battle_launch_requested.emit(payload)
	await get_tree().process_frame

	# Assert — state must remain IN_BATTLE (guard rejected; state not mutated)
	assert_int(sm.state as int).override_failure_message(
		("AC-2: state must remain IN_BATTLE (2) after guard-rejected launch;"
		+ " got %d. Guard may have allowed an in-progress state to re-enter.")
		% [sm.state as int]
	).is_equal(sm.State.IN_BATTLE as int)

	# Assert — ui_input_block_requested was NOT emitted (guard exited before entry path)
	assert_int(block_captures.size()).override_failure_message(
		("AC-2: ui_input_block_requested must NOT fire when guard rejects launch;"
		+ " fired %d time(s). Full entry path ran despite guard — guard may be broken.")
		% [block_captures.size()]
	).is_equal(0)

	# Cleanup (G-6) — disconnect listener if it didn't fire (guard passed = never fired)
	if GameBus.ui_input_block_requested.is_connected(block_listener):
		GameBus.ui_input_block_requested.disconnect(block_listener)
	SceneManagerStub.swap_out()


## AC-3 (direct unit): _transition_to_error sets ERROR state + resets progress.
## This is the pure unit test of the helper — exercises the state-machine contract
## regardless of which Godot-internal ResourceLoader path triggered the call.
## The end-to-end AC-3 path (load_request_failed via err != OK) is covered by the
## integration test at tests/integration/core/scene_handoff_timing_test.gd.
func test_scene_manager_transition_to_error_sets_error_state_and_resets_progress() -> void:
	# Arrange
	var sm: Node = _make_scene_manager()
	# Pre-condition: partially-loaded state with non-zero progress
	sm.set("_state", sm.State.LOADING_BATTLE as int)
	sm.set("loading_progress", 0.6)
	sm.set("_load_path", "res://scenes/battle/some_map.tscn")

	# Act — story-006: push_error removed; GameBus.scene_transition_failed is the canonical signal.
	# No bus listener attached here — this test only checks state + progress (not emissions).
	sm._transition_to_error("test_reason: unit test of _transition_to_error helper")

	# Assert — state is ERROR (4)
	assert_int(sm.state as int).override_failure_message(
		"AC-3: state must be ERROR (4) after _transition_to_error; got %d" % [sm.state as int]
	).is_equal(sm.State.ERROR as int)

	# Assert — loading_progress reset to 0.0
	assert_float(sm.loading_progress).override_failure_message(
		"AC-3: loading_progress must be 0.0 after _transition_to_error; got %f"
		% [sm.loading_progress]
	).is_equal_approx(0.0, 0.0001)

	# Cleanup (G-6)
	sm.free()


## AC-4: _on_load_tick with THREAD_LOAD_FAILED status → timer stops + state → ERROR.
## Strategy: set SM to LOADING_BATTLE with a non-existent resource path, queue the
## threaded request (returns OK — job queued), then drive _on_load_tick() in a poll
## loop until the loader thread reports FAILED and state reaches ERROR.
## This exercises the THREAD_LOAD_FAILED match branch and the timer-stop call.
##
## Note: load_threaded_request returns OK for non-existent res:// paths — it queues
## the job. FAILED status arrives asynchronously from the loader thread. We poll
## via direct _on_load_tick() calls (faster than 100 ms Timer cadence).
func test_scene_manager_on_load_tick_failed_status_transitions_to_error() -> void:
	# Arrange
	var sm: Node = _make_scene_manager()
	const BAD_PATH: String = "res://tests/fixtures/scenes/nonexistent_ac4_404.tscn"
	sm.set("_state", sm.State.LOADING_BATTLE as int)
	sm.set("_load_path", BAD_PATH)

	# Queue the load job (returns OK; FAILED status arrives asynchronously)
	ResourceLoader.load_threaded_request(BAD_PATH, "PackedScene", true)

	# Poll _on_load_tick() until state leaves LOADING_BATTLE or max iterations hit.
	# 60 iterations with one process_frame each gives the loader thread time to respond.
	var reached_error: bool = false
	for _i: int in 60:
		sm._on_load_tick()
		if sm.state != sm.State.LOADING_BATTLE:
			reached_error = true
			break
		await get_tree().process_frame

	# Assert — state reached ERROR
	assert_bool(reached_error).override_failure_message(
		("AC-4: state did not leave LOADING_BATTLE after 60 tick polls on bad path '%s'."
		+ " Loader thread may not have responded within the frame budget.") % [BAD_PATH]
	).is_true()

	assert_int(sm.state as int).override_failure_message(
		"AC-4: state must be ERROR (4) after THREAD_LOAD_FAILED; got %d" % [sm.state as int]
	).is_equal(sm.State.ERROR as int)

	# Assert — Timer was stopped by the FAILED branch
	var timer: Timer = null
	for child: Node in sm.get_children():
		if child is Timer:
			timer = child
			break
	if timer != null:
		assert_bool(timer.is_stopped()).override_failure_message(
			"AC-4: Timer must be stopped after _on_load_tick handles FAILED status"
		).is_true()

	# Cleanup (G-6)
	sm.free()


## AC-5: loading_progress readable as a plain property — no bus subscription needed.
## Given: SM with loading_progress set to 0.5 via set().
## When: external caller reads sm.loading_progress directly.
## Then: returns 0.5; no GameBus signal subscription required.
func test_scene_manager_loading_progress_readable_as_property_without_bus() -> void:
	# Arrange
	var sm: Node = _make_scene_manager()
	sm.set("loading_progress", 0.5)

	# Act — property read with no bus involvement
	var got: float = sm.loading_progress

	# Assert
	assert_float(got).override_failure_message(
		"AC-5: loading_progress must read 0.5 when set directly; got %f" % [got]
	).is_equal_approx(0.5, 0.0001)

	# Cleanup (G-6)
	sm.free()


## AC-7: Retry from ERROR — battle_launch_requested emitted while in ERROR state
## is accepted and transitions to LOADING_BATTLE.
## Given: SceneManagerStub swapped in; state forced to ERROR.
## When: battle_launch_requested emitted on the real GameBus autoload.
## Then: state → LOADING_BATTLE (retry accepted per ADR-0002 state-machine diagram).
##
## AUTOLOAD BINDING NOTE (G-new, story-004 round 3):
##   GameBusStub is NOT used here. `GameBus` the identifier resolves to the registered
##   autoload (production instance) regardless of what node is at /root/GameBus. The
##   stub SM connects to the real GameBus in _ready(); emitting on the real GameBus
##   is what reaches the handler. See integration test file header for full explanation.
##
## FIXTURE MAP_ID: must resolve to a real res:// path so load_threaded_request returns
## OK. A non-existent path returns non-OK immediately → _transition_to_error fires
## inside the handler → state flips back to ERROR before the test reads it.
##
## Timer hygiene: timer is stopped after the await to contain the async load.
func test_scene_manager_retry_from_error_state_transitions_to_loading_battle() -> void:
	# Arrange — SM stub only; emit on real GameBus
	var sm: Node = SceneManagerStub.swap_in()

	# Force state to ERROR (simulate a prior load failure)
	sm.set("_state", sm.State.ERROR as int)

	# Use the checked-in fixture map_id — resolves to res://scenes/battle/test_ac4_map.tscn
	var payload: BattlePayload = BattlePayload.new()
	payload.map_id = "test_ac4_map"

	# Act — emit on the real GameBus; CONNECT_DEFERRED fires next idle frame
	GameBus.battle_launch_requested.emit(payload)
	await get_tree().process_frame

	# Capture state before timer can advance it further
	var state_after: int = sm.state as int

	# Stop the timer to contain the async load within this test boundary
	for child: Node in sm.get_children():
		if child is Timer:
			(child as Timer).stop()
			break

	# Assert — state is LOADING_BATTLE (1): retry was accepted
	assert_int(state_after).override_failure_message(
		("AC-7: state must be LOADING_BATTLE (1) after retry from ERROR;"
		+ " got %d. Guard must accept ERROR → LOADING_BATTLE.") % [state_after]
	).is_equal(sm.State.LOADING_BATTLE as int)

	# Cleanup (G-6)
	SceneManagerStub.swap_out()


## Helper coverage: _resolve_battle_scene_path returns the ADR §Path Resolution format.
## Pure function — no tree or stubs needed.
func test_scene_manager_resolve_battle_scene_path_returns_correct_format() -> void:
	# Arrange — load script without mounting (pure function, no tree dependency)
	var sm: Node = (load(SCENE_MANAGER_PATH) as GDScript).new()

	# Act
	var got: String = sm._resolve_battle_scene_path("my_map")

	# Assert
	assert_str(got).override_failure_message(
		("_resolve_battle_scene_path must return 'res://scenes/battle/my_map.tscn';"
		+ " got '%s'") % [got]
	).is_equal("res://scenes/battle/my_map.tscn")

	# Cleanup (G-6)
	sm.free()


# ── Story 005: Outcome-driven teardown + co-subscriber-safe free ─────────────


## AC-1 (synchronous): outcome handler transitions state to RETURNING_FROM_BATTLE immediately.
## Given: state == IN_BATTLE, _battle_scene_ref set to mock node.
## When: _on_battle_outcome_resolved called directly.
## Then: state == RETURNING_FROM_BATTLE synchronously (before deferred fires).
func test_scene_manager_outcome_handler_transitions_to_returning_synchronously() -> void:
	# Arrange
	var sm: Node = _make_scene_manager()
	var mock_battle: Node = Node.new()
	add_child(mock_battle)
	sm.set("_state", sm.State.IN_BATTLE as int)
	sm.set("_battle_scene_ref", mock_battle)

	# Act — direct call bypasses CONNECT_DEFERRED timing (unit test, not integration)
	sm._on_battle_outcome_resolved(BattleOutcome.new())

	# Assert — state is RETURNING_FROM_BATTLE (3) synchronously
	assert_int(sm.state as int).override_failure_message(
		("AC-1: state must be RETURNING_FROM_BATTLE (3) synchronously after handler;"
		+ " got %d") % [sm.state as int]
	).is_equal(sm.State.RETURNING_FROM_BATTLE as int)

	# Cleanup (G-6)
	mock_battle.free()
	sm.free()


## AC-2 (deferred): one process_frame after outcome handler → state IDLE, ref null, progress 0.
## Given: state == IN_BATTLE, _battle_scene_ref set to mock node in tree.
## When: _on_battle_outcome_resolved called; await 1 frame.
## Then: state == IDLE, _battle_scene_ref == null, loading_progress == 0.0.
func test_scene_manager_outcome_deferred_teardown_completes_to_idle() -> void:
	# Arrange
	var sm: Node = _make_scene_manager()
	var mock_battle: Node = Node.new()
	mock_battle.name = "MockBattleScene"
	add_child(mock_battle)
	sm.set("_state", sm.State.IN_BATTLE as int)
	sm.set("_battle_scene_ref", mock_battle)
	sm.set("loading_progress", 1.0)

	# Act
	sm._on_battle_outcome_resolved(BattleOutcome.new())
	await get_tree().process_frame

	# Assert — state is IDLE (0)
	assert_int(sm.state as int).override_failure_message(
		("AC-2: state must be IDLE (0) after deferred teardown fires;"
		+ " got %d") % [sm.state as int]
	).is_equal(sm.State.IDLE as int)

	# Assert — _battle_scene_ref nulled out
	assert_object(sm.get("_battle_scene_ref")).override_failure_message(
		"AC-2: _battle_scene_ref must be null after deferred teardown"
	).is_null()

	# Assert — loading_progress reset to 0.0
	assert_float(sm.loading_progress).override_failure_message(
		("AC-2: loading_progress must be 0.0 after deferred teardown; got %f")
		% [sm.loading_progress]
	).is_equal_approx(0.0, 0.0001)

	# mock_battle freed by queue_free in _free_battle_scene_and_restore_overworld;
	# no manual free needed for it here.
	# Cleanup (G-6)
	sm.free()


## AC-4: null/invalid payload rejected — state unchanged, no transition.
## Given: state == IN_BATTLE.
## When: _on_battle_outcome_resolved(null) called.
## Then: state remains IN_BATTLE; call_deferred NOT queued (early return before state change).
func test_scene_manager_outcome_handler_rejects_null_payload() -> void:
	# Arrange
	var sm: Node = _make_scene_manager()
	sm.set("_state", sm.State.IN_BATTLE as int)

	# Act — null payload triggers is_instance_valid guard + push_warning
	sm._on_battle_outcome_resolved(null)

	# Assert — state is unchanged (still IN_BATTLE)
	assert_int(sm.state as int).override_failure_message(
		("AC-4: state must remain IN_BATTLE (2) after null payload; got %d."
		+ " push_warning should have fired and early-returned.") % [sm.state as int]
	).is_equal(sm.State.IN_BATTLE as int)

	# Cleanup (G-6)
	sm.free()


## AC-5: state guard rejects outcome when not IN_BATTLE.
## Given: each non-IN_BATTLE state.
## When: _on_battle_outcome_resolved called with valid outcome.
## Then: state unchanged for each case; no transition to RETURNING_FROM_BATTLE.
func test_scene_manager_outcome_handler_rejects_when_not_in_battle() -> void:
	# Arrange
	var sm: Node = _make_scene_manager()

	for non_battle_state: int in [
		sm.State.IDLE as int,
		sm.State.LOADING_BATTLE as int,
		sm.State.RETURNING_FROM_BATTLE as int,
		sm.State.ERROR as int,
	]:
		sm.set("_state", non_battle_state)

		# Act
		sm._on_battle_outcome_resolved(BattleOutcome.new())

		# Assert — state unchanged
		assert_int(sm.state as int).override_failure_message(
			("AC-5: state must remain %d (non-IN_BATTLE) after guard-rejected outcome;"
			+ " got %d") % [non_battle_state, sm.state as int]
		).is_equal(non_battle_state)

	# Cleanup (G-6)
	sm.free()


## AC-6: duplicate outcome in same frame — first accepted, second rejected by state guard.
## Given: state == IN_BATTLE.
## When: _on_battle_outcome_resolved called twice synchronously (same-frame simulation).
## Then: after first call state == RETURNING_FROM_BATTLE;
##       after second call state still == RETURNING_FROM_BATTLE (guard rejected second call);
##       after await 1 frame state == IDLE (deferred free ran once).
func test_scene_manager_outcome_handler_rejects_duplicate_in_same_frame() -> void:
	# Arrange
	var sm: Node = _make_scene_manager()
	var mock_battle: Node = Node.new()
	mock_battle.name = "MockBattleScene2"
	add_child(mock_battle)
	sm.set("_state", sm.State.IN_BATTLE as int)
	sm.set("_battle_scene_ref", mock_battle)

	# Act — two synchronous calls simulate duplicate emission in the same frame
	sm._on_battle_outcome_resolved(BattleOutcome.new())
	sm._on_battle_outcome_resolved(BattleOutcome.new())

	# Assert — state is RETURNING_FROM_BATTLE: first call accepted, second rejected
	# (deferred free has not yet run; still on same sync frame)
	assert_int(sm.state as int).override_failure_message(
		("AC-6: state must be RETURNING_FROM_BATTLE (3) after first outcome accepted and"
		+ " second rejected; got %d. If IDLE (0), deferred fired mid-sync — unexpected."
		+ " If IN_BATTLE (2), guard may have rejected both.")
		% [sm.state as int]
	).is_equal(sm.State.RETURNING_FROM_BATTLE as int)

	# Allow deferred to fire then verify clean transition to IDLE
	await get_tree().process_frame

	assert_int(sm.state as int).override_failure_message(
		"AC-6: state must be IDLE (0) after deferred teardown runs; got %d" % [sm.state as int]
	).is_equal(sm.State.IDLE as int)

	# mock_battle freed by queue_free in teardown; no manual free needed.
	# Cleanup (G-6)
	sm.free()


## AC-7: Overworld's 4 suppression properties restored after teardown.
## Given: paused Overworld with UIRoot Control child + mock BattleScene; state == IN_BATTLE.
## When: _on_battle_outcome_resolved called + await 1 frame.
## Then: all 4 suppression properties RESTORED; UIRoot mouse_filter == STOP.
func test_scene_manager_outcome_teardown_restores_overworld_properties() -> void:
	# Arrange
	var sm: Node = _make_scene_manager()

	# Build a mock overworld with UIRoot Control child
	var mock_overworld: Node2D = Node2D.new()
	mock_overworld.name = "OverworldMock"
	var ui_root: Control = Control.new()
	ui_root.name = "UIRoot"
	add_child(mock_overworld)
	mock_overworld.add_child(ui_root)

	var mock_battle: Node = Node.new()
	mock_battle.name = "MockBattleScene3"
	add_child(mock_battle)

	# Apply suppression (mirrors _pause_overworld from battle entry)
	sm.set("_overworld_ref", mock_overworld)
	sm._pause_overworld()

	sm.set("_state", sm.State.IN_BATTLE as int)
	sm.set("_battle_scene_ref", mock_battle)

	# Act
	sm._on_battle_outcome_resolved(BattleOutcome.new())
	await get_tree().process_frame

	# Assert — process_mode restored to INHERIT
	assert_int(mock_overworld.process_mode as int).override_failure_message(
		("AC-7: process_mode must be PROCESS_MODE_INHERIT (%d) after teardown; got %d")
		% [Node.PROCESS_MODE_INHERIT, mock_overworld.process_mode as int]
	).is_equal(Node.PROCESS_MODE_INHERIT as int)

	# Assert — visible restored to true
	assert_bool(mock_overworld.visible).override_failure_message(
		"AC-7: visible must be true after teardown"
	).is_true()

	# Assert — input processing restored
	assert_bool(mock_overworld.is_processing_input()).override_failure_message(
		"AC-7: is_processing_input() must be true after teardown"
	).is_true()

	assert_bool(mock_overworld.is_processing_unhandled_input()).override_failure_message(
		"AC-7: is_processing_unhandled_input() must be true after teardown"
	).is_true()

	# Assert — UIRoot mouse_filter restored to STOP
	assert_int(ui_root.mouse_filter as int).override_failure_message(
		("AC-7: UIRoot.mouse_filter must be MOUSE_FILTER_STOP (%d) after teardown; got %d")
		% [Control.MOUSE_FILTER_STOP, ui_root.mouse_filter as int]
	).is_equal(Control.MOUSE_FILTER_STOP as int)

	# mock_battle freed by queue_free in teardown; mock_overworld is our node.
	# free() on mock_overworld recursively frees ui_root child.
	# Cleanup (G-6)
	mock_overworld.free()
	sm.free()


# ── Story 006: Error recovery + _transition_to_error full implementation ────


## AC-1: _transition_to_error emits scene_transition_failed + ui_input_unblock_requested
## on the real GameBus with correct arguments.
## Given: SM with LOADING_BATTLE state + non-zero progress.
## When: _transition_to_error("test_reason: AC-1 unit test") called directly.
## Then: state == ERROR, progress == 0.0, scene_transition_failed emitted with
##       ("scene_manager", reason), ui_input_unblock_requested emitted with "scene_transition".
## G-4 compliance: Array.append captures (not primitive reassign).
## G-10 compliance: direct handler call — no bus emit needed; listeners on real GameBus.
func test_scene_manager_transition_to_error_emits_correct_bus_signals() -> void:
	# Arrange
	var sm: Node = _make_scene_manager()
	sm.set("_state", sm.State.LOADING_BATTLE as int)
	sm.set("loading_progress", 0.6)

	# Capture scene_transition_failed args via G-4 pattern
	var failed_captures: Array = []
	var failed_listener: Callable = func(context: String, reason: String) -> void:
		failed_captures.append({"context": context, "reason": reason})
	GameBus.scene_transition_failed.connect(failed_listener)

	# Capture ui_input_unblock_requested args
	var unblock_captures: Array = []
	var unblock_listener: Callable = func(context: String) -> void:
		unblock_captures.append({"context": context})
	GameBus.ui_input_unblock_requested.connect(unblock_listener)

	# Act
	sm._transition_to_error("test_reason: AC-1 unit test")

	# Disconnect listeners before assertions (G-6: disconnect before test body exits)
	if GameBus.scene_transition_failed.is_connected(failed_listener):
		GameBus.scene_transition_failed.disconnect(failed_listener)
	if GameBus.ui_input_unblock_requested.is_connected(unblock_listener):
		GameBus.ui_input_unblock_requested.disconnect(unblock_listener)

	# Assert — state is ERROR (4)
	assert_int(sm.state as int).override_failure_message(
		"AC-1: state must be ERROR (4) after _transition_to_error; got %d" % [sm.state as int]
	).is_equal(sm.State.ERROR as int)

	# Assert — loading_progress reset to 0.0
	assert_float(sm.loading_progress).override_failure_message(
		"AC-1: loading_progress must be 0.0 after _transition_to_error; got %f" % [sm.loading_progress]
	).is_equal_approx(0.0, 0.0001)

	# Assert — scene_transition_failed fired once with correct args
	assert_int(failed_captures.size()).override_failure_message(
		("AC-1: scene_transition_failed must fire exactly once; fired %d times")
		% [failed_captures.size()]
	).is_equal(1)

	if failed_captures.size() > 0:
		assert_str(failed_captures[0].context as String).override_failure_message(
			("AC-1: scene_transition_failed context must be 'scene_manager'; got '%s'")
			% [failed_captures[0].context as String]
		).is_equal("scene_manager")

		assert_str(failed_captures[0].reason as String).override_failure_message(
			("AC-1: scene_transition_failed reason must match; got '%s'")
			% [failed_captures[0].reason as String]
		).is_equal("test_reason: AC-1 unit test")

	# Assert — ui_input_unblock_requested fired once with "scene_transition"
	assert_int(unblock_captures.size()).override_failure_message(
		("AC-1: ui_input_unblock_requested must fire exactly once; fired %d times")
		% [unblock_captures.size()]
	).is_equal(1)

	if unblock_captures.size() > 0:
		assert_str(unblock_captures[0].context as String).override_failure_message(
			("AC-1: ui_input_unblock_requested context must be 'scene_transition'; got '%s'")
			% [unblock_captures[0].context as String]
		).is_equal("scene_transition")

	# Cleanup (G-6)
	sm.free()


## AC-2: _transition_to_error restores the Overworld (all 4 suppression props + UIRoot mouse_filter).
## Given: Overworld paused via _pause_overworld (all 4 properties suppressed); SM in LOADING_BATTLE.
## When: _transition_to_error called.
## Then: process_mode INHERIT, visible true, both input flags true, UIRoot mouse_filter STOP.
func test_scene_manager_transition_to_error_restores_overworld() -> void:
	# Arrange
	var sm: Node = _make_scene_manager()
	var fake_overworld: Node2D = Node2D.new()
	fake_overworld.name = "OverworldMock006"
	var ui_root: Control = Control.new()
	ui_root.name = "UIRoot"
	ui_root.mouse_filter = Control.MOUSE_FILTER_STOP
	fake_overworld.add_child(ui_root)
	add_child(fake_overworld)

	sm.set("_overworld_ref", fake_overworld)
	sm._pause_overworld()  # apply all 4 suppression properties
	sm.set("_state", sm.State.LOADING_BATTLE as int)

	# Act
	sm._transition_to_error("overworld_restore_test")

	# Assert — process_mode restored to INHERIT
	assert_int(fake_overworld.process_mode as int).override_failure_message(
		("AC-2: process_mode must be PROCESS_MODE_INHERIT (%d) after _transition_to_error; got %d")
		% [Node.PROCESS_MODE_INHERIT, fake_overworld.process_mode as int]
	).is_equal(Node.PROCESS_MODE_INHERIT as int)

	# Assert — visible restored
	assert_bool(fake_overworld.visible).override_failure_message(
		"AC-2: visible must be true after _transition_to_error"
	).is_true()

	# Assert — input processing restored
	assert_bool(fake_overworld.is_processing_input()).override_failure_message(
		"AC-2: is_processing_input() must be true after _transition_to_error"
	).is_true()

	assert_bool(fake_overworld.is_processing_unhandled_input()).override_failure_message(
		"AC-2: is_processing_unhandled_input() must be true after _transition_to_error"
	).is_true()

	# Assert — UIRoot mouse_filter restored to STOP
	assert_int(ui_root.mouse_filter as int).override_failure_message(
		("AC-2: UIRoot.mouse_filter must be MOUSE_FILTER_STOP (%d) after _transition_to_error; got %d")
		% [Control.MOUSE_FILTER_STOP, ui_root.mouse_filter as int]
	).is_equal(Control.MOUSE_FILTER_STOP as int)

	# Cleanup (G-6) — fake_overworld.free() recursively frees ui_root
	fake_overworld.free()
	sm.free()


## AC-3 + AC-6: ERROR state guard rejects battle_outcome_resolved (spurious signal);
## scene_transition_failed NOT emitted when the state guard fires (not an error condition).
## Given: state == ERROR.
## When: _on_battle_outcome_resolved called with a valid BattleOutcome.
## Then: state remains ERROR; scene_transition_failed does NOT fire.
## AC-6 coverage: the state-guard rejection path is not an error event — no failed signal.
func test_scene_manager_error_state_rejects_battle_outcome_resolved() -> void:
	# Arrange
	var sm: Node = _make_scene_manager()
	sm.set("_state", sm.State.ERROR as int)

	# Capture any scene_transition_failed emits — must stay empty
	var failed_captures: Array = []
	var failed_listener: Callable = func(_ctx: String, _rsn: String) -> void:
		failed_captures.append(true)
	GameBus.scene_transition_failed.connect(failed_listener)

	# Act — spurious outcome in ERROR state
	sm._on_battle_outcome_resolved(BattleOutcome.new())

	# Disconnect listener before assertions (G-6)
	if GameBus.scene_transition_failed.is_connected(failed_listener):
		GameBus.scene_transition_failed.disconnect(failed_listener)

	# Assert — state remains ERROR (not RETURNING_FROM_BATTLE or IDLE)
	assert_int(sm.state as int).override_failure_message(
		("AC-3: state must remain ERROR (4) after spurious battle_outcome_resolved;"
		+ " got %d. Guard must reject outcomes outside IN_BATTLE.") % [sm.state as int]
	).is_equal(sm.State.ERROR as int)

	# Assert — scene_transition_failed NOT emitted (guard rejection is not an error event)
	assert_int(failed_captures.size()).override_failure_message(
		("AC-6: scene_transition_failed must NOT fire when outcome rejected by state guard;"
		+ " fired %d times. Normal teardown guard rejection is not an error condition.")
		% [failed_captures.size()]
	).is_equal(0)

	# Cleanup (G-6)
	sm.free()
