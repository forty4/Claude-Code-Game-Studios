extends GdUnitTestSuite

## scene_handoff_timing_test.gd — Story 004: Async threaded BattleScene load + progress.
##
## Integration test for AC-1 (happy-path async load) and the end-to-end AC-3 path
## (load failure via _transition_to_error → ERROR state), using a real PackedScene
## fixture loaded via ResourceLoader.load_threaded_request on a res:// path.
##
## SCOPE:
##   - test_scene_manager_async_load_happy_path_idle_to_in_battle (AC-1)
##   - test_scene_manager_async_load_nonexistent_path_reaches_error (AC-3 end-to-end)
##
## FIXTURE:
##   res://scenes/battle/test_ac4_map.tscn — minimal Node2D scene checked in under
##   scenes/battle/. The path is where _resolve_battle_scene_path("test_ac4_map")
##   resolves to (ADR-0002 §Path Resolution), so the test exercises the real code path
##   without any path-resolver override.
##   See scenes/battle/README-test-fixtures.md for fixture exclusion guidance.
##
## AUTOLOAD BINDING — CRITICAL (discovered story-004 round 3):
##   GameBusStub is NOT used in these tests. The GDScript autoload identifier `GameBus`
##   is bound at engine registration time to the production GameBus instance, NOT
##   dynamically to whatever node sits at /root/GameBus. GameBusStub.swap_in() replaces
##   the node at /root/GameBus but cannot rebind the identifier. When the stub SM's
##   _ready() calls `GameBus.battle_launch_requested.connect(...)`, it connects to the
##   PRODUCTION (now detached) GameBus, not the stub. Any emit on the stub bus never
##   reaches the handler.
##
##   CORRECT PATTERN: use SceneManagerStub.swap_in() only. The stub SM subscribes to
##   the real GameBus autoload in its _ready(). Emit on GameBus directly. The handler
##   fires correctly via CONNECT_DEFERRED.
##
##   CONSEQUENCE for ui_input_block/unblock: these signals also emit on the production
##   GameBus. Production subscribers (if any running during test) receive them. This is
##   acceptable in integration tests — the SM's behavior is what is being verified, not
##   signal isolation. Unit tests that need signal-emit isolation must call helpers
##   directly (_on_battle_launch_requested, _transition_to_error) rather than via bus.
##
## STUB STRATEGY (revised):
##   SceneManagerStub only — fresh SM subscribes to real GameBus; production SM at
##   /root/SceneManager is detached and not disturbed. Emits on GameBus reach the
##   stub SM's handler.
##
## TIMER CONTROL:
##   _on_load_tick() is called directly (bypassing the 100 ms Timer cadence) so the
##   test does not wait real-time seconds for the loader thread. We poll up to
##   MAX_POLL_ITERATIONS frames, checking after each tick whether the state has
##   advanced beyond LOADING_BATTLE.
##
## CLEANUP DISCIPLINE (G-6):
##   - SceneManagerStub.swap_out() is called explicitly at end of each test body.
##   - _battle_scene_ref (Node added to /root by _instantiate_and_enter_battle) is
##     removed from the tree and freed synchronously before swap_out.
##   - after_test() calls swap_out() as a crash-safety net; idempotent.
##
## G-9 COMPLIANCE:
##   All multi-line format strings wrapped in outer parentheses before the % operator.
##
## ADR references:  ADR-0002 §Key Interfaces, §Path Resolution, §State Machine
## TR references:   TR-scene-manager-003
## Story:           Story 004 — Async threaded BattleScene loading + progress

## Maximum _on_load_tick() poll iterations before declaring the test inconclusive.
## 80 iterations × one process_frame each ≈ 80 frames at 60 fps ≈ 1.33 s wall-clock.
const MAX_POLL_ITERATIONS: int = 80

## Path that _resolve_battle_scene_path("test_ac4_map") produces.
const FIXTURE_SCENE_PATH: String = "res://scenes/battle/test_ac4_map.tscn"

## map_id for a path that does NOT exist — used for the error-path integration test.
const NONEXISTENT_PATH_MAP_ID: String = "nonexistent_integration_ac3_404"


# ── Lifecycle ─────────────────────────────────────────────────────────────────


## Safety-net cleanup. SceneManagerStub.swap_out() is idempotent — if the test
## body already called it, this is a no-op.
func after_test() -> void:
	SceneManagerStub.swap_out()


# ── Helpers ───────────────────────────────────────────────────────────────────


## Polls sm._on_load_tick() until state leaves LOADING_BATTLE or MAX_POLL_ITERATIONS
## is exhausted. Returns the final state int.
## Awaiting process_frame between ticks gives the loader thread time to advance status.
func _poll_until_state_changes(sm: Node) -> int:
	for _i: int in MAX_POLL_ITERATIONS:
		sm._on_load_tick()
		if sm.state != sm.State.LOADING_BATTLE:
			return sm.state as int
		await get_tree().process_frame
	return sm.state as int


# ── AC-1: Happy-path async load ───────────────────────────────────────────────


## AC-1: Full IDLE → LOADING_BATTLE → IN_BATTLE state sequence using the real
## ResourceLoader.load_threaded_request API and a res:// PackedScene fixture.
##
## Verified:
##   - State sequence: IDLE → LOADING_BATTLE (after emit + one deferred frame)
##                     LOADING_BATTLE → IN_BATTLE (after load completes via tick poll)
##   - loading_progress == 1.0 in IN_BATTLE
##   - _battle_scene_ref is a valid Node after IN_BATTLE entry
##   - ui_input_block_requested fires before IN_BATTLE; ui_input_unblock fires after
##     (verified implicitly — reaching IN_BATTLE proves both emits ran in sequence)
func test_scene_manager_async_load_happy_path_idle_to_in_battle() -> void:
	# Arrange — SM stub only; emit on real GameBus (see AUTOLOAD BINDING note above)
	var sm: Node = SceneManagerStub.swap_in()

	# Pre-condition: state is IDLE
	assert_int(sm.state as int).override_failure_message(
		"AC-1 pre-condition: state must be IDLE (0) before emit"
	).is_equal(sm.State.IDLE as int)

	# Verify fixture is loadable via engine VFS before queuing the async load.
	# ResourceLoader.exists() is reliable in headless mode for res:// paths.
	assert_bool(ResourceLoader.exists(FIXTURE_SCENE_PATH, "PackedScene")).override_failure_message(
		("AC-1 pre-condition: fixture not loadable at '%s'."
		+ " Ensure scenes/battle/test_ac4_map.tscn is committed and visible to the"
		+ " resource system (run `godot --headless --import` if needed).")
		% [FIXTURE_SCENE_PATH]
	).is_true()

	# Build payload with the fixture map_id
	var payload: BattlePayload = BattlePayload.new()
	payload.map_id = "test_ac4_map"

	# Act — emit on the REAL GameBus autoload; stub SM is subscribed to it.
	# CONNECT_DEFERRED means the handler fires on the next idle frame.
	GameBus.battle_launch_requested.emit(payload)
	await get_tree().process_frame

	# Assert — state is LOADING_BATTLE (handler ran and entry path completed)
	assert_int(sm.state as int).override_failure_message(
		("AC-1: state must be LOADING_BATTLE (1) after battle_launch_requested fires;"
		+ " got %d. CONNECT_DEFERRED handler may not have run, or fixture path was"
		+ " rejected and _transition_to_error flipped state to ERROR.")
		% [sm.state as int]
	).is_equal(sm.State.LOADING_BATTLE as int)

	# Act — poll ticks until load completes (IN_BATTLE) or timeout
	var final_state: int = await _poll_until_state_changes(sm)

	# Assert — state reached IN_BATTLE (2)
	assert_int(final_state).override_failure_message(
		("AC-1: state must be IN_BATTLE (2) after load completes;"
		+ " got %d after up to %d poll iterations. Fixture may not be loadable"
		+ " or _instantiate_and_enter_battle may have failed its null-packed guard.")
		% [final_state, MAX_POLL_ITERATIONS]
	).is_equal(sm.State.IN_BATTLE as int)

	# Assert — loading_progress is 1.0 in IN_BATTLE
	assert_float(sm.loading_progress).override_failure_message(
		("AC-1: loading_progress must be 1.0 after IN_BATTLE entry; got %f")
		% [sm.loading_progress]
	).is_equal_approx(1.0, 0.0001)

	# Assert — _battle_scene_ref was set (instantiated PackedScene)
	var battle_ref: Node = sm.get("_battle_scene_ref") as Node
	assert_bool(is_instance_valid(battle_ref)).override_failure_message(
		("AC-1: _battle_scene_ref must be a valid Node after IN_BATTLE entry."
		+ " _instantiate_and_enter_battle may have called _transition_to_error.")
	).is_true()

	# Cleanup — remove and free the battle scene before swap_out (G-6).
	# _battle_scene_ref was added to get_tree().root by _instantiate_and_enter_battle.
	# It must be detached and freed before swap_out() or orphan detection fires.
	if is_instance_valid(battle_ref) and battle_ref.is_inside_tree():
		get_tree().root.remove_child(battle_ref)
	if is_instance_valid(battle_ref):
		battle_ref.free()

	# Cleanup — swap out SM stub (synchronous; production SM restored)
	SceneManagerStub.swap_out()


# ── AC-3 end-to-end: non-existent path reaches ERROR ─────────────────────────


## AC-3 end-to-end: launching with a map_id that resolves to a non-existent path
## causes the SM to reach ERROR state. Two code paths may produce this result:
##   (a) load_threaded_request returns non-OK immediately → _transition_to_error called
##       synchronously inside the handler; state is ERROR after one deferred frame.
##   (b) load_threaded_request returns OK (job queued) → THREAD_LOAD_FAILED status
##       arrives asynchronously; _on_load_tick tick-polling drives state to ERROR.
##
## The test handles both branches. The contract verified: "bad path → ERROR".
func test_scene_manager_async_load_nonexistent_path_reaches_error() -> void:
	# Arrange — SM stub only; emit on real GameBus
	var sm: Node = SceneManagerStub.swap_in()

	var payload: BattlePayload = BattlePayload.new()
	payload.map_id = NONEXISTENT_PATH_MAP_ID

	# Act — emit on the REAL GameBus; CONNECT_DEFERRED fires next idle frame
	GameBus.battle_launch_requested.emit(payload)
	await get_tree().process_frame

	# After one deferred frame, state is either:
	#   ERROR (4)          — load_threaded_request returned non-OK immediately (path (a))
	#   LOADING_BATTLE (1) — request was queued; tick polling needed (path (b))
	#   IDLE (0)           — handler never fired (test infrastructure problem)
	var state_after_emit: int = sm.state as int

	if state_after_emit == sm.State.LOADING_BATTLE:
		# Path (b): drive tick poll until FAILED status arrives
		var final_state: int = await _poll_until_state_changes(sm)
		assert_int(final_state).override_failure_message(
			("AC-3 e2e: state must be ERROR (4) after load fails on nonexistent path;"
			+ " got %d after up to %d poll iterations.")
			% [final_state, MAX_POLL_ITERATIONS]
		).is_equal(sm.State.ERROR as int)
	else:
		# Path (a) or unexpected: assert ERROR.
		# If state is IDLE (0), the handler never fired — "got 0" in the failure
		# message is a clear signal to check the autoload binding / stub setup.
		assert_int(state_after_emit).override_failure_message(
			("AC-3 e2e: state must be ERROR (4) after bad-path launch;"
			+ " got %d (0=IDLE: handler never fired; 4=ERROR: expected immediate failure)")
			% [state_after_emit]
		).is_equal(sm.State.ERROR as int)

	# Assert — loading_progress reset to 0.0 in either error path
	assert_float(sm.loading_progress).override_failure_message(
		("AC-3 e2e: loading_progress must be 0.0 in ERROR state; got %f")
		% [sm.loading_progress]
	).is_equal_approx(0.0, 0.0001)

	# No battle_scene_ref cleanup needed — error path never calls _instantiate_and_enter_battle

	# Cleanup (G-6)
	SceneManagerStub.swap_out()


# ── Story 005: AC-3 — Co-subscriber ref-safety (V-5 invariant) ───────────────


## AC-3 (V-5): co-subscriber connected via CONNECT_DEFERRED reads _battle_scene_ref
## as valid during its own handler — before call_deferred fires the free.
##
## INVARIANT: battle_outcome_resolved fires its CONNECT_DEFERRED subscribers on the
## next idle frame (Frame N). SM's handler runs and calls call_deferred, which queues
## _free_battle_scene_and_restore_overworld for Frame N+1. A co-subscriber whose
## CONNECT_DEFERRED handler also fires on Frame N can safely read _battle_scene_ref
## because the free has not yet been scheduled for execution.
##
## G-10 COMPLIANCE: SceneManagerStub.swap_in() ONLY. Emit on the real GameBus
## autoload identifier. Co-subscriber connects to GameBus.battle_outcome_resolved
## directly — NOT to a stub bus.
##
## G-4 COMPLIANCE: co-subscriber lambda captures into Array, not outer primitive.
##
## G-6 COMPLIANCE: explicit disconnect + swap_out at end of test body.
func test_co_subscriber_reads_battle_scene_ref_in_deferred_handler() -> void:
	# Arrange
	var sm: Node = SceneManagerStub.swap_in()
	var mock_battle: Node = Node.new()
	mock_battle.name = "MockBattleSceneAC3"
	get_tree().root.add_child(mock_battle)  # must be in tree for queue_free to take effect
	sm.set("_state", sm.State.IN_BATTLE as int)
	sm.set("_battle_scene_ref", mock_battle)

	# Co-subscriber: connects to real GameBus.battle_outcome_resolved via CONNECT_DEFERRED.
	# In its handler (fires same Frame N as SM's handler), it reads _battle_scene_ref and
	# records whether it was still valid. Per G-4: use Array.append — lambda cannot
	# reassign outer primitives.
	var captures: Array = []
	var co_subscriber: Callable = func(_outcome: BattleOutcome) -> void:
		captures.append({
			"state_during_handler": sm.state as int,
			"ref_valid": is_instance_valid(sm.get("_battle_scene_ref") as Node),
		})
	GameBus.battle_outcome_resolved.connect(co_subscriber, CONNECT_DEFERRED)

	# Act — emit on real GameBus (G-10: stub SM subscribes to the real autoload)
	var outcome: BattleOutcome = BattleOutcome.new()
	GameBus.battle_outcome_resolved.emit(outcome)

	# Frame N: CONNECT_DEFERRED handlers fire (SM handler + co-subscriber).
	# SM handler: state → RETURNING_FROM_BATTLE, call_deferred queued.
	# Co-subscriber handler: reads _battle_scene_ref — should still be VALID.
	await get_tree().process_frame

	# Assert — co-subscriber fired exactly once
	assert_int(captures.size()).override_failure_message(
		("AC-3: co-subscriber handler must have fired exactly once. Got %d captures."
		+ " Ensure CONNECT_DEFERRED connection to real GameBus is working (G-10).")
		% [captures.size()]
	).is_equal(1)

	# Assert — _battle_scene_ref was valid during co-subscriber's Frame N handler
	assert_bool(captures[0].ref_valid as bool).override_failure_message(
		("AC-3: during CONNECT_DEFERRED handler, _battle_scene_ref must still be valid."
		+ " The 1-frame defer invariant: call_deferred fires AFTER all current-frame"
		+ " CONNECT_DEFERRED handlers. If false, the free ran too early (ADR-0002 R-1).")
	).is_true()

	# Assert — SM state was RETURNING_FROM_BATTLE during co-subscriber's Frame N handler
	assert_int(captures[0].state_during_handler as int).override_failure_message(
		("AC-3: SM state must be RETURNING_FROM_BATTLE (3) during co-subscriber handler;"
		+ " got %d") % [captures[0].state_during_handler as int]
	).is_equal(sm.State.RETURNING_FROM_BATTLE as int)

	# Frame N+1: call_deferred fires → _free_battle_scene_and_restore_overworld runs.
	await get_tree().process_frame

	# Assert — teardown complete after Frame N+1
	assert_int(sm.state as int).override_failure_message(
		("AC-3: state must be IDLE (0) after deferred free fires on Frame N+1;"
		+ " got %d") % [sm.state as int]
	).is_equal(sm.State.IDLE as int)

	assert_object(sm.get("_battle_scene_ref")).override_failure_message(
		"AC-3: _battle_scene_ref must be null after deferred free"
	).is_null()

	assert_bool(is_instance_valid(mock_battle)).override_failure_message(
		"AC-3: mock_battle must be freed (is_instance_valid == false) after queue_free runs"
	).is_false()

	# Cleanup (G-6): disconnect co-subscriber explicitly (was not CONNECT_ONE_SHOT)
	GameBus.battle_outcome_resolved.disconnect(co_subscriber)
	SceneManagerStub.swap_out()
