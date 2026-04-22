extends GdUnitTestSuite

## scene_manager_retry_test.gd — Story 006: Error recovery + retry loop.
##
## Integration tests for the full error-recovery and retry-loop paths:
##   AC-4: ERROR → retry → IN_BATTLE (single cycle via battle_launch_requested re-emit)
##   AC-5: LOSS → retry (Overworld ref preserved; MockScenarioRunner._retry_count increments)
##   AC-7: 5-cycle multi-retry determinism (same Overworld ref; no orphan BattleScenes)
##
## STUB STRATEGY (G-10):
##   SceneManagerStub.swap_in() ONLY. The stub SM subscribes to the real GameBus
##   autoload identifier in its _ready(). Emits go on GameBus directly.
##   GameBusStub is NOT used — combining it with SceneManagerStub breaks handler wiring
##   because the autoload identifier binds at engine init, not to /root/GameBus dynamically.
##
## FIXTURE:
##   res://scenes/battle/test_ac4_map.tscn — same fixture as scene_handoff_timing_test.gd.
##   All retry tests use this path for the valid battle load.
##
## TIMER CONTROL:
##   _poll_until_state_changes() drives _on_load_tick() directly (bypasses 100 ms cadence)
##   so tests do not wait real-time seconds for the loader thread.
##
## MESSAGEQUEUE ORDERING (confirmed by user — correct 2-await pattern):
##   Frame N flush: SM._on_battle_outcome_resolved + runner._on_battle_outcome both fire.
##     SM: state → RETURNING_FROM_BATTLE; call_deferred(_free_...) queued for Frame N+1.
##     Runner: sees LOSS; increments _retry_count; re-emits battle_launch_requested (synchronous).
##       battle_launch_requested CONNECT_DEFERRED handler queued for Frame N+1.
##   Frame N+1 flush: _free_battle_scene_and_restore_overworld fires (state → IDLE),
##     THEN _on_battle_launch_requested fires (sees IDLE, proceeds to LOADING_BATTLE).
##   2-await + state==LOADING_BATTLE check + poll is exactly right for this ordering.
##
## CLEANUP DISCIPLINE (G-6):
##   - SceneManagerStub.swap_out() called explicitly at end of each test body.
##   - Any _battle_scene_ref added to /root is removed + freed before swap_out.
##   - MockScenarioRunner and mock Overworld freed in-body.
##   - after_test() calls swap_out() as crash-safety net only.
##
## G-9 COMPLIANCE: all multi-line format strings wrapped in outer parens before %.

const FIXTURE_MAP_ID: String = "test_ac4_map"
const FIXTURE_SCENE_PATH: String = "res://scenes/battle/test_ac4_map.tscn"
const MAX_POLL_ITERATIONS: int = 80


# ── Lifecycle ─────────────────────────────────────────────────────────────────


## Safety-net cleanup. SceneManagerStub.swap_out() is idempotent.
func after_test() -> void:
	SceneManagerStub.swap_out()


# ── Helpers ───────────────────────────────────────────────────────────────────


## Polls sm._on_load_tick() until state leaves LOADING_BATTLE or MAX_POLL_ITERATIONS
## is exhausted. Returns the final state int.
## Awaiting process_frame between ticks gives the loader thread time to advance.
func _poll_until_state_changes(sm: Node) -> int:
	for _i: int in MAX_POLL_ITERATIONS:
		sm._on_load_tick()
		if sm.state != sm.State.LOADING_BATTLE:
			return sm.state as int
		await get_tree().process_frame
	return sm.state as int


## Drives a full launch → IN_BATTLE cycle using the given payload.
## Asserts LOADING_BATTLE after emit + IN_BATTLE after poll.
## Returns the _battle_scene_ref so the caller can track and clean it up.
func _run_battle_cycle(sm: Node, payload: BattlePayload) -> Node:
	GameBus.battle_launch_requested.emit(payload)
	await get_tree().process_frame

	assert_int(sm.state as int).override_failure_message(
		("_run_battle_cycle: state must be LOADING_BATTLE (1) after emit; got %d."
		+ " Check autoload binding (G-10) and fixture availability at '%s'.")
		% [sm.state as int, FIXTURE_SCENE_PATH]
	).is_equal(sm.State.LOADING_BATTLE as int)

	var final_state: int = await _poll_until_state_changes(sm)

	assert_int(final_state).override_failure_message(
		("_run_battle_cycle: state must be IN_BATTLE (2) after load; got %d")
		% [final_state]
	).is_equal(sm.State.IN_BATTLE as int)

	return sm.get("_battle_scene_ref") as Node


## Frees any battle scene ref that _instantiate_and_enter_battle added to /root.
## Accepts Variant so callers can pass already-freed or null references safely —
## is_instance_valid() is the authoritative guard. The check MUST happen before
## any `as Node` cast: casting a freed-object reference throws "Trying to cast a
## freed object" even when the declared param is Variant.
func _cleanup_battle_ref(battle_ref: Variant) -> void:
	if not is_instance_valid(battle_ref):
		return
	var node: Node = battle_ref as Node
	if node.is_inside_tree():
		get_tree().root.remove_child(node)
	node.free()


# ── AC-4: Single ERROR → retry cycle ─────────────────────────────────────────


## AC-4: ERROR → LOADING_BATTLE → IN_BATTLE via battle_launch_requested re-emit.
## Given: SM forced to ERROR state (simulates a prior load failure).
## When: battle_launch_requested emitted with valid payload on real GameBus.
## Then: state sequence ERROR → LOADING_BATTLE → IN_BATTLE;
##       scene_transition_failed NOT fired during the successful retry.
func test_scene_manager_error_to_in_battle_via_retry() -> void:
	# Arrange — SM stub only; emit on real GameBus (G-10)
	var sm: Node = SceneManagerStub.swap_in()

	assert_bool(ResourceLoader.exists(FIXTURE_SCENE_PATH, "PackedScene")).override_failure_message(
		("AC-4 pre-condition: fixture not found at '%s'."
		+ " Ensure scenes/battle/test_ac4_map.tscn is committed.")
		% [FIXTURE_SCENE_PATH]
	).is_true()

	# Force state to ERROR (simulates a prior load failure)
	sm.set("_state", sm.State.ERROR as int)

	# Capture scene_transition_failed — must NOT fire on a successful retry
	var failed_captures: Array = []
	var failed_listener: Callable = func(_ctx: String, _rsn: String) -> void:
		failed_captures.append(true)
	GameBus.scene_transition_failed.connect(failed_listener)

	var payload: BattlePayload = BattlePayload.new()
	payload.map_id = FIXTURE_MAP_ID

	# Act — retry emit on real GameBus; CONNECT_DEFERRED fires next idle frame
	GameBus.battle_launch_requested.emit(payload)
	await get_tree().process_frame

	# Assert — moved to LOADING_BATTLE (ERROR accepted as entry state per story-004 guard)
	assert_int(sm.state as int).override_failure_message(
		("AC-4: state must be LOADING_BATTLE (1) after retry emit from ERROR;"
		+ " got %d. Guard must accept ERROR → LOADING_BATTLE.")
		% [sm.state as int]
	).is_equal(sm.State.LOADING_BATTLE as int)

	# Poll to IN_BATTLE
	var final_state: int = await _poll_until_state_changes(sm)
	assert_int(final_state).override_failure_message(
		("AC-4: state must be IN_BATTLE (2) after retry load completes; got %d")
		% [final_state]
	).is_equal(sm.State.IN_BATTLE as int)

	# Disconnect listener before assertions (G-6)
	if GameBus.scene_transition_failed.is_connected(failed_listener):
		GameBus.scene_transition_failed.disconnect(failed_listener)

	# Assert — scene_transition_failed did NOT fire during the successful retry
	assert_int(failed_captures.size()).override_failure_message(
		("AC-4: scene_transition_failed must NOT fire on a successful retry;"
		+ " fired %d times") % [failed_captures.size()]
	).is_equal(0)

	# Cleanup (G-6) — pass Variant directly; _cleanup_battle_ref guards is_instance_valid
	_cleanup_battle_ref(sm.get("_battle_scene_ref"))
	SceneManagerStub.swap_out()


# ── AC-5: LOSS → retry (Overworld ref preserved) ─────────────────────────────


## AC-5: F-SP-3 Echo retry — LOSS outcome triggers retry; Overworld Node ref is
## the same instance before and after retry.
## Given: MockScenarioRunner with auto_retry_on_loss=true; mock Overworld as current_scene.
## When: full loop — launch → IN_BATTLE → outcome LOSS → teardown → IDLE →
##       runner re-emits → LOADING_BATTLE → IN_BATTLE.
## Then: Overworld Node ref is THE SAME instance (ref equality); _retry_count == 1.
##
## CURRENT_SCENE SETUP: set get_tree().current_scene = mock_overworld so that
## _on_battle_launch_requested's natural `get_tree().current_scene as CanvasItem` capture
## picks up our mock on every entry — including the retry — without clobbering it.
## This simulates production conditions (Overworld IS current_scene) without touching
## production code. current_scene is restored to null in cleanup.
##
## AWAIT SEQUENCE (3 frames after LOSS emit, per call_deferred runner):
##   Frame N:   battle_outcome_resolved CONNECT_DEFERRED handlers fire.
##              SM: state→RETURNING_FROM_BATTLE; call_deferred(_free_...) queued.
##              Runner: LOSS received; _retry_count++; call_deferred("_emit_retry") queued.
##   Frame N+1: _free_battle_scene_and_restore_overworld fires (state→IDLE).
##              _emit_retry() fires → GameBus.battle_launch_requested.emit() →
##              SM's CONNECT_DEFERRED handler queued for Frame N+2.
##   Frame N+2: _on_battle_launch_requested fires (IDLE → LOADING_BATTLE).
func test_scene_manager_loss_retry_preserves_overworld_ref() -> void:
	# Arrange — SM stub only; emit on real GameBus (G-10)
	var sm: Node = SceneManagerStub.swap_in()

	assert_bool(ResourceLoader.exists(FIXTURE_SCENE_PATH, "PackedScene")).override_failure_message(
		("AC-5 pre-condition: fixture not found at '%s'") % [FIXTURE_SCENE_PATH]
	).is_true()

	# Mount mock Overworld and make it the SceneTree current_scene.
	# _on_battle_launch_requested captures `get_tree().current_scene as CanvasItem` on every
	# entry — setting current_scene to our Node2D mock makes both the initial capture and any
	# retry capture resolve to the same instance (production idempotency preserved in tests).
	var mock_overworld: Node2D = Node2D.new()
	mock_overworld.name = "MockOverworldAC5"
	get_tree().root.add_child(mock_overworld)
	get_tree().current_scene = mock_overworld
	var overworld_ref_before: Node = mock_overworld as Node

	# Set up MockScenarioRunner for auto-retry on LOSS
	var runner: MockScenarioRunner = MockScenarioRunner.new()
	runner.auto_retry_on_loss = true
	var payload: BattlePayload = BattlePayload.new()
	payload.map_id = FIXTURE_MAP_ID
	runner.set_retry_payload(payload)
	get_tree().root.add_child(runner)

	# First launch cycle — gets to IN_BATTLE
	var battle_ref_first: Node = await _run_battle_cycle(sm, payload)

	# Verify _overworld_ref captured our mock after battle entry
	assert_bool((sm.get("_overworld_ref") as Node) == mock_overworld).override_failure_message(
		"AC-5: _overworld_ref must be mock_overworld after battle entry"
	).is_true()

	# Act — emit LOSS outcome; MockScenarioRunner will call_deferred("_emit_retry")
	var outcome: BattleOutcome = BattleOutcome.new()
	outcome.result = BattleOutcome.Result.LOSS
	GameBus.battle_outcome_resolved.emit(outcome)

	# Frame N: CONNECT_DEFERRED handlers fire (SM teardown + runner receives LOSS)
	await get_tree().process_frame
	# Frame N+1: _free_... completes (state→IDLE); _emit_retry fires (emits launch_requested)
	await get_tree().process_frame
	# Frame N+2: _on_battle_launch_requested fires (IDLE → LOADING_BATTLE)
	await get_tree().process_frame

	# Poll to IN_BATTLE for the retry cycle
	if sm.state == sm.State.LOADING_BATTLE:
		var retry_state: int = await _poll_until_state_changes(sm)
		assert_int(retry_state).override_failure_message(
			("AC-5: state must be IN_BATTLE (2) after retry load completes; got %d")
			% [retry_state]
		).is_equal(sm.State.IN_BATTLE as int)

	# Unconditional post-retry state check — guards against silent-pass on fast fixture load
	# where state has already advanced past LOADING_BATTLE before the poll guard runs.
	assert_int(sm.state as int).override_failure_message(
		("AC-5: state must be IN_BATTLE (2) after retry (unconditional);"
		+ " got %d. Fast-load silent-pass regression guard.") % [sm.state as int]
	).is_equal(sm.State.IN_BATTLE as int)

	# Assert — MockScenarioRunner._retry_count == 1
	assert_int(runner._retry_count).override_failure_message(
		("AC-5: _retry_count must be 1 after one LOSS retry; got %d")
		% [runner._retry_count]
	).is_equal(1)

	# Assert — Overworld ref is THE SAME instance (ref equality — not just same values)
	var overworld_ref_after: Node = sm.get("_overworld_ref") as Node
	assert_bool(overworld_ref_after == overworld_ref_before).override_failure_message(
		("AC-5: _overworld_ref must be the SAME Node instance before and after retry."
		+ " F-SP-3 Echo-retry preserves Overworld state. Got different instance or null.")
	).is_true()

	# Cleanup (G-6) — restore current_scene before freeing mock (avoids dangling reference)
	get_tree().current_scene = null
	var battle_ref_second: Node = sm.get("_battle_scene_ref") as Node
	_cleanup_battle_ref(battle_ref_first)
	_cleanup_battle_ref(battle_ref_second)
	runner.free()
	mock_overworld.free()
	SceneManagerStub.swap_out()


# ── AC-7: 5-cycle multi-retry determinism ────────────────────────────────────


## AC-7: 5 consecutive LOSS→retry cycles; Overworld same ref every cycle; no orphan BattleScenes.
## Given: MockScenarioRunner with auto_retry_on_loss=true; mock Overworld as current_scene.
## When: 5 full LOSS→retry cycles.
## Then: Overworld Node ref unchanged across all 5 cycles; _retry_count == 5;
##       each previous BattleScene ref is freed after teardown (no orphans).
##
## AWAIT SEQUENCE per cycle (3 frames, matching AC-5 — see AC-5 doc comment for rationale).
func test_scene_manager_five_cycle_retry_determinism() -> void:
	const CYCLES: int = 5

	# Arrange — SM stub only; emit on real GameBus (G-10)
	var sm: Node = SceneManagerStub.swap_in()

	assert_bool(ResourceLoader.exists(FIXTURE_SCENE_PATH, "PackedScene")).override_failure_message(
		("AC-7 pre-condition: fixture not found at '%s'") % [FIXTURE_SCENE_PATH]
	).is_true()

	var mock_overworld: Node2D = Node2D.new()
	mock_overworld.name = "MockOverworldAC7"
	get_tree().root.add_child(mock_overworld)
	get_tree().current_scene = mock_overworld
	var overworld_ref_before: Node = mock_overworld as Node

	var payload: BattlePayload = BattlePayload.new()
	payload.map_id = FIXTURE_MAP_ID

	var runner: MockScenarioRunner = MockScenarioRunner.new()
	runner.auto_retry_on_loss = true
	runner.set_retry_payload(payload)
	get_tree().root.add_child(runner)

	# Initial launch to reach IN_BATTLE before the retry loop begins
	var prev_battle_ref: Node = await _run_battle_cycle(sm, payload)

	# Run CYCLES iterations of LOSS → retry
	for cycle: int in CYCLES:
		var outcome: BattleOutcome = BattleOutcome.new()
		outcome.result = BattleOutcome.Result.LOSS
		GameBus.battle_outcome_resolved.emit(outcome)

		# Frame N: CONNECT_DEFERRED handlers fire; runner call_deferred("_emit_retry") queued
		await get_tree().process_frame
		# Frame N+1: _free_... (state→IDLE) + _emit_retry fires (emits battle_launch_requested)
		await get_tree().process_frame
		# Frame N+2: _on_battle_launch_requested fires (IDLE → LOADING_BATTLE)
		await get_tree().process_frame

		# Poll to IN_BATTLE for this retry
		if sm.state == sm.State.LOADING_BATTLE:
			var retry_state: int = await _poll_until_state_changes(sm)
			assert_int(retry_state).override_failure_message(
				("AC-7 cycle %d/%d: state must be IN_BATTLE (2) after retry; got %d")
				% [cycle + 1, CYCLES, retry_state]
			).is_equal(sm.State.IN_BATTLE as int)

		# Unconditional post-retry state check — guards against silent-pass on fast loads
		assert_int(sm.state as int).override_failure_message(
			("AC-7 cycle %d/%d: state must be IN_BATTLE (2) after retry (unconditional);"
			+ " got %d. Fast-load silent-pass regression guard.")
			% [cycle + 1, CYCLES, sm.state as int]
		).is_equal(sm.State.IN_BATTLE as int)

		# Assert — previous cycle's BattleScene was freed (no orphan nodes)
		assert_bool(is_instance_valid(prev_battle_ref)).override_failure_message(
			("AC-7 cycle %d/%d: previous BattleScene ref must be freed after teardown."
			+ " Orphan node detected — queue_free may not have run.")
			% [cycle + 1, CYCLES]
		).is_false()

		# Assert — Overworld ref is still the same instance every cycle
		var overworld_now: Node = sm.get("_overworld_ref") as Node
		assert_bool(overworld_now == overworld_ref_before).override_failure_message(
			("AC-7 cycle %d/%d: _overworld_ref must be the SAME Node instance;"
			+ " got a different instance — Overworld state was not preserved.")
			% [cycle + 1, CYCLES]
		).is_true()

		prev_battle_ref = sm.get("_battle_scene_ref") as Node

	# Assert — total retry count matches CYCLES
	assert_int(runner._retry_count).override_failure_message(
		("AC-7: _retry_count must be %d after %d cycles; got %d")
		% [CYCLES, CYCLES, runner._retry_count]
	).is_equal(CYCLES)

	# Cleanup (G-6) — restore current_scene before freeing mock
	get_tree().current_scene = null
	_cleanup_battle_ref(prev_battle_ref)
	runner.free()
	mock_overworld.free()
	SceneManagerStub.swap_out()
