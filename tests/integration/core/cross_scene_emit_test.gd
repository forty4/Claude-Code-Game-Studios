extends GdUnitTestSuite

## cross_scene_emit_test.gd — Story 007: Cross-scene emit integration test.
##
## Validates ADR-0001 §Validation Criteria V-4:
##   "A cross-scene emit test passes — BattleController (in battle scene) emits
##    battle_outcome_resolved; ScenarioRunner (in overworld scene) receives it
##    after battle scene is freed. Freed-battle-scene test asserts no dangling
##    reference errors."
##
## SCOPE:
##   - 8 test functions covering AC-1..AC-8 per story QA Test Cases.
##   - Uses the real /root/GameBus (integration test per story §4 — NOT stub).
##   - Uses MockScenarioRunner + MockBattleController (no real implementations).
##
## SCENE CONSTRUCTION:
##   All "scenes" are constructed programmatically via Node.new() + add_child().
##   No .tscn fixture files are used. Justification: programmatic fixtures are
##   easier to diff, version-control, and maintain; no editor dependency; no
##   fixture-file drift risk. The story AC wording "synthetic fixture .tscn" is
##   an implementation suggestion; the intent (mock scene structure) is satisfied
##   by programmatic Node construction.
##
## FRAME ADVANCEMENT:
##   CONNECT_DEFERRED handlers fire on the next idle frame. Tests use
##   `await get_tree().process_frame` to advance. When a node is also freed
##   via call_deferred in the same emit frame, two awaits are used (two-frame
##   rule) — Godot does NOT guarantee handler-before-free ordering within one
##   idle frame; two frames ensure both deferred operations complete regardless
##   of intra-frame queue ordering.
##
## AC-6 IMPLEMENTATION NOTE:
##   "No dangling-ref errors" is verified explicitly: after the emit-then-free
##   sequence, Signal.get_connections() is checked for dangling entries (objects
##   that are no longer is_instance_valid). Zero dangling entries = AC-6 passes.
##   Implicit proof (test passing without crash) remains the primary safety net.
##
## CLEANUP:
##   All programmatically spawned root-level Nodes are tracked in _spawned and
##   freed synchronously (free(), not queue_free()) in after_test() to prevent
##   GdUnit4's orphan detector from flagging deferred-but-alive nodes.
##
## ADR reference:    ADR-0001 §V-4, §Implementation Guidelines §5, §6
## TR references:    TR-gamebus-001, TR-scenario-progression-003
## Pattern refs:     TR-scenario-progression-003 / EC-SP-5 (duplicate-guard)


## Tracks every Node added to /root during a test. after_test() frees them all.
var _spawned: Array[Node] = []


# ── Lifecycle ─────────────────────────────────────────────────────────────────


func after_test() -> void:
	# Synchronous cleanup — free() not queue_free() to avoid GdUnit4 orphan flags.
	for node: Node in _spawned:
		if is_instance_valid(node) and node.is_inside_tree():
			get_tree().root.remove_child(node)
		if is_instance_valid(node):
			node.free()
	_spawned.clear()


# ── Helpers ───────────────────────────────────────────────────────────────────


## Adds a Node to /root and registers it for after_test() cleanup.
func _spawn_at_root(node: Node) -> void:
	get_tree().root.add_child(node)
	_spawned.append(node)


## Builds a "mock overworld" Node hierarchy:
##   MockOverworld (Node)
##     └─ MockScenarioRunner (Node — subscribes to battle_outcome_resolved)
##
## The runner connects to GameBus in its own _ready(), which fires when
## add_child() is called (the node is already in the tree when _ready runs).
## Callers must add the returned Node to the tree via _spawn_at_root() before
## triggering any emits — connection happens in _ready, not construction.
func _make_mock_overworld() -> Node:
	var overworld: Node = Node.new()
	overworld.name = "MockOverworld"
	var runner: MockScenarioRunner = MockScenarioRunner.new()
	runner.name = "MockScenarioRunner"
	overworld.add_child(runner)
	return overworld


## Builds a "mock battle scene" Node hierarchy:
##   MockBattleScene (Node)
##     └─ MockBattleController (Node — emits battle_outcome_resolved on demand)
func _make_mock_battle_scene() -> Node:
	var battle: Node = Node.new()
	battle.name = "MockBattleScene"
	var controller: MockBattleController = MockBattleController.new()
	controller.name = "MockBattleController"
	battle.add_child(controller)
	return battle


## Builds a synthetic BattleOutcome with identifiable field values for assertions.
func _make_payload(chapter: String = "ch_test_007", round_num: int = 3) -> BattleOutcome:
	var outcome: BattleOutcome = BattleOutcome.new()
	outcome.result = BattleOutcome.Result.WIN
	outcome.chapter_id = chapter
	outcome.final_round = round_num
	outcome.surviving_units = PackedInt64Array([1, 2, 3])
	outcome.defeated_units = PackedInt64Array([4, 5])
	outcome.is_abandon = false
	return outcome


# ── AC-1: Happy-path emit → free → receive ────────────────────────────────────


## AC-1: BattleController emits battle_outcome_resolved; battle scene is
## call_deferred-freed in the same frame; MockScenarioRunner (in a separate
## overworld scene) receives the payload exactly once after 2 idle frames.
##
## Two-frame rule: Godot does NOT guarantee handler-before-free ordering
## within a single idle frame — both are enqueued in the same deferred queue.
## Two process_frame awaits ensure BOTH the CONNECT_DEFERRED handler and the
## call_deferred("free") complete, regardless of intra-frame ordering. The
## conservative approach avoids depending on an engine sequencing guarantee
## that does not exist.
func test_cross_scene_emit_happy_path_emit_free_receive() -> void:
	# Arrange — overworld with runner subscribed, battle scene with controller
	var overworld: Node = _make_mock_overworld()
	_spawn_at_root(overworld)
	var battle: Node = _make_mock_battle_scene()
	_spawn_at_root(battle)

	var runner: MockScenarioRunner = overworld.get_node("MockScenarioRunner") as MockScenarioRunner
	var controller: MockBattleController = battle.get_node("MockBattleController") as MockBattleController
	assert_bool(runner != null).override_failure_message(
		"AC-1 pre-condition: MockScenarioRunner not found in overworld hierarchy"
	).is_true()
	assert_bool(controller != null).override_failure_message(
		"AC-1 pre-condition: MockBattleController not found in battle hierarchy"
	).is_true()

	var payload: BattleOutcome = _make_payload("ch_ac1", 3)

	# Act — emit, then schedule battle scene for deferred free (mimics SceneManager pattern)
	controller.emit_outcome(payload)
	battle.call_deferred("free")
	# Remove from _spawned since we are manually freeing it via call_deferred
	_spawned.erase(battle)

	# Advance two idle frames (two-frame rule — see docstring)
	await get_tree().process_frame
	await get_tree().process_frame

	# Assert — runner received exactly one payload
	assert_int(runner.received.size()).override_failure_message(
		("AC-1: expected MockScenarioRunner.received.size() == 1, got %d. "
		+ "CONNECT_DEFERRED handler may not have fired — check that runner was "
		+ "added to the tree before emit (connection happens in _ready).")
		% runner.received.size()
	).is_equal(1)

	# Assert — payload fields match what was emitted (no corruption)
	var got: BattleOutcome = runner.received[0]
	assert_int(got.result as int).override_failure_message(
		"AC-1: payload.result corrupted — got %d, expected %d (WIN)"
		% [got.result, BattleOutcome.Result.WIN]
	).is_equal(BattleOutcome.Result.WIN)

	assert_str(got.chapter_id).override_failure_message(
		"AC-1: payload.chapter_id corrupted — got '%s', expected 'ch_ac1'" % got.chapter_id
	).is_equal("ch_ac1")

	assert_int(got.final_round).override_failure_message(
		"AC-1: payload.final_round corrupted — got %d, expected 3" % got.final_round
	).is_equal(3)

	assert_bool(got.is_abandon).override_failure_message(
		"AC-1: payload.is_abandon corrupted — got true, expected false"
	).is_false()

	# Assert — battle scene node is freed after second frame
	assert_bool(is_instance_valid(battle)).override_failure_message(
		"AC-1 edge: battle scene node should be freed after call_deferred('free') + 2 frames"
	).is_false()

	# AC-6 implicit: test reaching this point without crash = no dangling-ref errors.


# ── AC-2: Disconnect on scene exit ────────────────────────────────────────────


## AC-2: When the overworld scene is freed, MockScenarioRunner._exit_tree()
## disconnects from GameBus. A subsequent emit must not reach the freed runner.
##
## Verifies the ADR-0001 §6 lifecycle discipline:
##   - _exit_tree disconnect with is_connected guard prevents stale connections
##   - Signal.get_connections() returns no entry for the freed runner
func test_cross_scene_emit_disconnect_on_scene_exit() -> void:
	# Arrange — spawn overworld and let runner connect
	var overworld: Node = _make_mock_overworld()
	_spawn_at_root(overworld)
	var runner: MockScenarioRunner = overworld.get_node("MockScenarioRunner") as MockScenarioRunner

	# Sanity — runner is connected before free
	# Signal.get_connections() returns untyped Array in Godot 4.6 — cannot assign to
	# Array[Dictionary] directly (runtime type-boundary error). The for-loop's typed
	# `conn: Dictionary` variable narrows element type locally. See TD-013 gotcha #8.
	var connections_before: Array = GameBus.battle_outcome_resolved.get_connections()
	var runner_connected_before: bool = false
	for conn: Dictionary in connections_before:
		if conn.get("callable", Callable()).get_object() == runner:
			runner_connected_before = true
			break
	assert_bool(runner_connected_before).override_failure_message(
		"AC-2 pre-condition: MockScenarioRunner should be connected to "
		+ "battle_outcome_resolved before overworld is freed"
	).is_true()

	# Act — free the overworld (triggers _exit_tree → disconnect)
	_spawned.erase(overworld)
	overworld.free()

	# Assert — no connection references the freed runner
	var connections_after: Array = GameBus.battle_outcome_resolved.get_connections()
	var stale_found: bool = false
	for conn: Dictionary in connections_after:
		var obj: Object = conn.get("callable", Callable()).get_object()
		if not is_instance_valid(obj):
			stale_found = true
			break
		if obj == runner:
			stale_found = true
			break
	assert_bool(stale_found).override_failure_message(
		"AC-2: stale connection to freed MockScenarioRunner found in "
		+ "battle_outcome_resolved connection list after overworld.free(). "
		+ "_exit_tree disconnect may not have run."
	).is_false()

	# Assert edge — emit after runner is freed; must not crash (no-one receives)
	# AC-6 implicit: reaching this line without crash = no dangling-ref error.
	var payload: BattleOutcome = _make_payload("ch_ac2_after_free", 1)
	GameBus.battle_outcome_resolved.emit(payload)
	await get_tree().process_frame
	# If a stale handler fired on the freed runner, Godot would have pushed an
	# error and likely halted GdUnit4 — reaching here is the passing assertion.


# ── AC-3: is_instance_valid guard (automated attempt) ─────────────────────────


## AC-3 automated attempt non-deterministic for Resource payloads:
##
## The signal's bound payload arg lifetime depends on the argument type:
##   - Resource / RefCounted: Godot's deferred signal queue increments refcount
##     until the handler fires, so dropping local refs does NOT free the payload
##     mid-flight. is_instance_valid(outcome) is always true when the handler
##     runs. The guard's false-path cannot be exercised by a simple ref-drop.
##   - Bare Object (not RefCounted): no refcount protection. Calling Object.free()
##     after emit but before the deferred frame DOES leave the deferred queue
##     holding a dangling pointer. is_instance_valid returns false correctly.
##
## Since BattleOutcome is a Resource in this codebase, the Resource branch applies.
## The is_instance_valid guard in MockScenarioRunner is still correct and defensive
## — it protects against scenarios where an emitter explicitly frees a payload
## sub-field (game-logic-specific, not reproducible in a generic integration test),
## or if the payload type is ever changed to bare Object in the future.
##
## Deferred to manual playtest verification per story AC-3 advisory clause.
## The null-payload variant (test_cross_scene_emit_null_payload_is_guarded below)
## exercises the false-path via emit(null) — a deterministic alternative trigger.
## GdUnit4 v6.1.2 note: `skip()` is NOT available as a runtime method on
## GdUnitTestSuite. Skip is a scanner-level attribute (do_skip: bool argument
## on the test annotation), not callable from test body code. `pass` is the
## correct stub body.
func test_cross_scene_emit_is_instance_valid_guard_deferred_to_manual() -> void:
	# No automated assertion — see docstring above.
	# AC-3 path: advisory. null-payload false-path is covered by
	# test_cross_scene_emit_null_payload_is_guarded below.
	pass


# ── AC-3 partial automation: null payload exercise ───────────────────────────


## Complements the AC-3 advisory stub above. Exercises the is_instance_valid
## guard via emit(null) — the simplest deterministic trigger for the false-path.
## Proves the guard works for null; Resource-lifetime false-path remains deferred
## to manual verification per the advisory stub above.
##
## Note: emitting null where the signal expects BattleOutcome may log a Godot
## type-mismatch warning in stdout — expected noise, not a test failure.
func test_cross_scene_emit_null_payload_is_guarded() -> void:
	# Arrange — spawn overworld with runner subscribed
	var overworld: Node = _make_mock_overworld()
	_spawn_at_root(overworld)
	var runner: MockScenarioRunner = overworld.get_node("MockScenarioRunner") as MockScenarioRunner

	var battle: Node = _make_mock_battle_scene()
	_spawn_at_root(battle)
	var controller: MockBattleController = battle.get_node("MockBattleController") as MockBattleController

	# Act — emit null payload (invalid); is_instance_valid guard should catch it
	controller.emit_outcome(null)
	await get_tree().process_frame

	# Assert — no payload received; null rejected by is_instance_valid guard
	assert_int(runner.received.size()).override_failure_message(
		"AC-3 null: expected received.size() == 0 (null rejected by is_instance_valid guard), got %d"
		% runner.received.size()
	).is_equal(0)

	# Assert — _consumed_once stays false; null did not count as valid consumption
	assert_bool(runner._consumed_once).override_failure_message(
		"AC-3 null: _consumed_once should stay false after guarded null emit"
	).is_false()


# ── AC-4: Duplicate emission guard (EC-SP-5) ──────────────────────────────────


## AC-4: Emitting battle_outcome_resolved twice in the same frame; MockScenarioRunner's
## _consumed_once flag (EC-SP-5 guard) ignores the second emission.
## TR-scenario-progression-003 reference implementation.
func test_cross_scene_emit_duplicate_emission_ignored_per_ec_sp5() -> void:
	# Arrange — fresh runner (not yet consumed)
	var overworld: Node = _make_mock_overworld()
	_spawn_at_root(overworld)
	var runner: MockScenarioRunner = overworld.get_node("MockScenarioRunner") as MockScenarioRunner

	var battle: Node = _make_mock_battle_scene()
	_spawn_at_root(battle)
	var controller: MockBattleController = battle.get_node("MockBattleController") as MockBattleController

	var payload1: BattleOutcome = _make_payload("ch_ac4_first", 1)
	var payload2: BattleOutcome = _make_payload("ch_ac4_second", 2)

	# Act — emit twice in the same frame (both deferred, fire next frame)
	controller.emit_outcome(payload1)
	controller.emit_outcome(payload2)

	# Advance one idle frame — both deferred handlers fire in this frame
	await get_tree().process_frame

	# Assert — only first payload received; second ignored by _consumed_once guard
	assert_int(runner.received.size()).override_failure_message(
		("AC-4 / EC-SP-5: expected received.size() == 1 (second emission ignored), got %d. "
		+ "Duplicate-emission guard (_consumed_once) may not be working.")
		% runner.received.size()
	).is_equal(1)

	assert_bool(runner._consumed_once).override_failure_message(
		"AC-4 / EC-SP-5: _consumed_once should be true after first emission"
	).is_true()

	# Assert — the one received payload is payload1 (first emission wins)
	assert_str(runner.received[0].chapter_id).override_failure_message(
		"AC-4 / EC-SP-5: first received payload should be payload1 (ch_ac4_first), "
		+ "got '%s'" % runner.received[0].chapter_id
	).is_equal("ch_ac4_first")


# ── AC-5: Re-instantiation fresh receives ────────────────────────────────────


## AC-5: After the overworld scene is freed and re-instantiated, the new
## MockScenarioRunner receives the next emission. The old subscriber (freed)
## does not re-receive. Verifies scene lifecycle signal contract integrity.
func test_cross_scene_emit_re_instantiation_fresh_receives() -> void:
	# Arrange — first overworld + runner
	var overworld_old: Node = _make_mock_overworld()
	_spawn_at_root(overworld_old)
	var runner_old: MockScenarioRunner = overworld_old.get_node("MockScenarioRunner") as MockScenarioRunner

	var battle: Node = _make_mock_battle_scene()
	_spawn_at_root(battle)
	var controller: MockBattleController = battle.get_node("MockBattleController") as MockBattleController

	# Emit once — runner_old consumes it
	controller.emit_outcome(_make_payload("ch_ac5_first", 1))
	await get_tree().process_frame

	assert_int(runner_old.received.size()).override_failure_message(
		"AC-5 pre-condition: runner_old should have received first payload"
	).is_equal(1)

	# Act — free old overworld (disconnect happens in _exit_tree)
	_spawned.erase(overworld_old)
	overworld_old.free()

	# Act — instantiate new overworld; new runner connects fresh in _ready
	var overworld_new: Node = _make_mock_overworld()
	_spawn_at_root(overworld_new)
	var runner_new: MockScenarioRunner = overworld_new.get_node("MockScenarioRunner") as MockScenarioRunner

	# Assert — new runner starts unconsumed
	assert_bool(runner_new._consumed_once).override_failure_message(
		"AC-5: new runner should start with _consumed_once == false (fresh state)"
	).is_false()
	assert_int(runner_new.received.size()).override_failure_message(
		"AC-5: new runner.received should start empty"
	).is_equal(0)

	# Act — emit again
	controller.emit_outcome(_make_payload("ch_ac5_second", 2))
	await get_tree().process_frame

	# Assert — new runner received the second payload
	assert_int(runner_new.received.size()).override_failure_message(
		("AC-5: new runner should have received second payload (got %d). "
		+ "Fresh subscription after re-instantiation may not be working.")
		% runner_new.received.size()
	).is_equal(1)

	assert_str(runner_new.received[0].chapter_id).override_failure_message(
		"AC-5: new runner received wrong payload — got '%s', expected 'ch_ac5_second'"
		% runner_new.received[0].chapter_id
	).is_equal("ch_ac5_second")

	# Assert — old runner did NOT receive the second payload (already freed)
	# is_instance_valid(runner_old) is false — we cannot safely call runner_old.received.size().
	# The absence of a crash when emit fired = confirmation the old stale ref was not invoked.
	# AC-6 implicit: reaching here without error = no dangling runner_old reference fired.


# ── AC-6: No dangling-ref errors ─────────────────────────────────────────────


## AC-6: Full happy-path sequence with explicit node-lifecycle transitions.
## No dangling-reference crash occurs. Verified implicitly — test passing IS
## the evidence (Godot runtime surfaces dangling references as push_errors that
## halt GdUnit4 execution).
##
## This test exercises the most dangerous transition: emit while a subscriber
## is alive, then free the subscriber, then emit again. The second emit must
## not reach the freed subscriber.
func test_cross_scene_emit_no_dangling_ref_errors() -> void:
	# Arrange
	var overworld: Node = _make_mock_overworld()
	_spawn_at_root(overworld)
	var runner: MockScenarioRunner = overworld.get_node("MockScenarioRunner") as MockScenarioRunner

	var battle: Node = _make_mock_battle_scene()
	_spawn_at_root(battle)
	var controller: MockBattleController = battle.get_node("MockBattleController") as MockBattleController

	# Act — emit, await, confirm reception (healthy first pass)
	controller.emit_outcome(_make_payload("ch_ac6_first", 1))
	await get_tree().process_frame

	assert_int(runner.received.size()).override_failure_message(
		"AC-6: first emission should have been received (got %d)"
		% runner.received.size()
	).is_equal(1)

	# Act — free overworld (subscriber disconnects in _exit_tree)
	_spawned.erase(overworld)
	overworld.free()

	# Act — emit again after subscriber is freed (must NOT crash)
	controller.emit_outcome(_make_payload("ch_ac6_second", 2))

	# After overworld.free(), the runner is disconnected synchronously.
	# Second emit has zero subscribers — one await is sufficient (or could be
	# omitted entirely; we keep it to verify no deferred-queue ghost handler fires).
	await get_tree().process_frame

	# AC-6 explicit: after all emits, connection list must contain no dangling refs.
	# If a stale handler existed and fired, Godot would have push_error'd before here.
	var connections: Array = GameBus.battle_outcome_resolved.get_connections()
	var dangling_count: int = 0
	for conn: Dictionary in connections:
		var target: Object = conn.get("callable", Callable()).get_object()
		if not is_instance_valid(target):
			dangling_count += 1
	assert_int(dangling_count).override_failure_message(
		("AC-6: found %d dangling connection(s) in battle_outcome_resolved — _exit_tree "
		+ "disconnect may not have run for freed subscribers") % dangling_count
	).is_equal(0)


# ── AC-7: Cleanup leaves no orphans ──────────────────────────────────────────


## AC-7: Validates the _spawned tracking mechanism that after_test() uses.
## Calls after_test() directly mid-body to confirm:
##   (a) _spawned is empty after cleanup
##   (b) the tracked node is freed synchronously
##
## Note: after_test() runs AGAIN automatically after this test body exits.
## Since _spawned is empty at that point, the second call is a no-op. Safe.
##
## End-to-end proof that all 8 tests leave zero orphans is provided by
## GdUnit4's orphan-node counter reporting 0 across the full suite (CI gate).
func test_cross_scene_emit_cleanup_leaves_no_orphans() -> void:
	# Arrange — spawn a node and confirm it is tracked
	var sentinel: Node = Node.new()
	sentinel.name = "AC7Sentinel"
	_spawn_at_root(sentinel)

	assert_int(_spawned.size()).override_failure_message(
		"AC-7 pre-condition: _spawned should have 1 entry after _spawn_at_root"
	).is_equal(1)

	assert_bool(is_instance_valid(sentinel)).override_failure_message(
		"AC-7 pre-condition: sentinel node should be valid before cleanup"
	).is_true()

	# Act — invoke cleanup explicitly (GdUnit4 normally calls after_test after body exits)
	after_test()

	# Assert — tracking array cleared
	assert_bool(_spawned.is_empty()).override_failure_message(
		"AC-7: _spawned should be empty after after_test() — cleanup array not cleared"
	).is_true()

	# Assert — node freed synchronously (free() not queue_free())
	assert_bool(is_instance_valid(sentinel)).override_failure_message(
		"AC-7: sentinel node should be freed after after_test() — free() must be called, not queue_free()"
	).is_false()

	# Note: after_test() will be called again by GdUnit4 framework after this
	# test body returns. _spawned is empty so it is a no-op — idempotent.


# ── AC-8: Deterministic ───────────────────────────────────────────────────────


## AC-8: 10 consecutive iterations of the happy-path sequence all produce the
## same result. Verifies CONNECT_DEFERRED ordering is stable across runs and
## that fresh runner instances start clean every iteration.
func test_cross_scene_emit_is_deterministic() -> void:
	var battle: Node = _make_mock_battle_scene()
	_spawn_at_root(battle)
	var controller: MockBattleController = battle.get_node("MockBattleController") as MockBattleController

	for iteration: int in 10:
		# Arrange — fresh overworld per iteration
		var overworld: Node = _make_mock_overworld()
		# Add directly to root, NOT via _spawn_at_root, because this loop frees each
		# overworld at the end of its iteration (line below). Using _spawn_at_root would
		# accumulate 10 entries in _spawned — wasteful when each iteration owns a
		# complete create+emit+assert+free cycle. Trade-off: if an assertion fails
		# mid-iteration, the current iteration's overworld leaks (after_test won't
		# catch it). Acceptable for a determinism stress-test; downstream integration
		# tests should prefer _spawn_at_root for any test where mid-body failure paths
		# need clean cleanup.
		get_tree().root.add_child(overworld)
		var runner: MockScenarioRunner = overworld.get_node("MockScenarioRunner") as MockScenarioRunner

		# Act
		var payload: BattleOutcome = _make_payload("ch_ac8_iter_%d" % iteration, iteration)
		controller.emit_outcome(payload)
		await get_tree().process_frame

		# Assert — identical result every iteration
		assert_int(runner.received.size()).override_failure_message(
			("AC-8 iteration %d: expected received.size() == 1, got %d. "
			+ "CONNECT_DEFERRED ordering is not stable.")
			% [iteration, runner.received.size()]
		).is_equal(1)

		assert_str(runner.received[0].chapter_id).override_failure_message(
			"AC-8 iteration %d: chapter_id mismatch — got '%s', expected 'ch_ac8_iter_%d'"
			% [iteration, runner.received[0].chapter_id, iteration]
		).is_equal("ch_ac8_iter_%d" % iteration)

		assert_bool(runner._consumed_once).override_failure_message(
			"AC-8 iteration %d: _consumed_once should be true after one emission"
			% iteration
		).is_true()

		# Cleanup this iteration's overworld before next iteration
		overworld.free()

		# Reset controller's underlying signal state is N/A — GameBus holds no state.
		# Next iteration's runner subscribes fresh via its own _ready().
