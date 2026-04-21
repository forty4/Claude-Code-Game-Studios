extends GdUnitTestSuite

## game_bus_stub_self_test.gd
## Self-tests for Story 006: GameBusStub — /root/GameBus swap utility.
##
## Covers AC-1 through AC-5 and AC-7 per story QA Test Cases.
## AC-6 (README code-block lint) is advisory; no automated coverage here.
##
## ISOLATION STRATEGY:
##   Each test that calls swap_in() also calls swap_out() explicitly at the end
##   of its body. This prevents GdUnit4's orphan detector from flagging the
##   detached production node between the test body finishing and after_test
##   running. after_test remains as a belt-and-suspenders safety net for any
##   test that crashes before reaching its explicit cleanup line.
##
##   before_test calls swap_out() as a paranoia guard — safe because swap_out()
##   short-circuits when _active_stub is null (no prior swap_in).
##
##   The self-test cannot call swap_in() globally in before_test() because
##   AC-1 and AC-5 need to verify the pre-swap state directly.
##
## LIFECYCLE:
##   before_test — paranoia swap_out() (no-op when _active_stub is null)
##   test body   — explicit swap_out() at end of any test that calls swap_in()
##   after_test  — unconditional swap_out() (idempotent belt-and-suspenders)
##
## SIGNAL OBSERVATION:
##   Array-append lambda capture pattern throughout (same idiom as Story 005).
##   GDScript lambdas cannot reassign outer primitive locals — Array.append()
##   on a captured Array reference works correctly.
##
## NODE CLEANUP NOTE:
##   GameBusStub.swap_out() calls free() on the stub for immediate synchronous
##   deletion — not queue_free(). This prevents GdUnit4's orphan detector from
##   flagging the stub as a leaked node (deferred deletion leaves the object alive
##   until end-of-frame, which the detector sees as an orphan). AC-2 asserts
##   is_instance_valid(stub) == false after swap_out to confirm immediate deletion.

const GAME_BUS_PATH: String = "res://src/core/game_bus.gd"


func before_test() -> void:
	# Paranoia guard: if a prior test left _active_stub dirty (hard-failed before
	# calling swap_out), force a restore. Safe to call even when swap_in was never
	# called because swap_out() short-circuits when _active_stub is null.
	GameBusStub.swap_out()


func after_test() -> void:
	# Unconditional cleanup. Idempotent — safe even if the test already called
	# swap_out, or never called swap_in.
	GameBusStub.swap_out()


# ── Helpers ───────────────────────────────────────────────────────────────────


## Thin delegation to the shared TestHelpers module.
## Kept as a local wrapper so call sites within this file are unchanged.
func _get_user_signals(node: Node) -> Array[Dictionary]:
	return TestHelpers.get_user_signals(node)


# ── AC-1: swap_in replaces production at /root/GameBus ────────────────────────


## AC-1: swap_in mounts a fresh stub at /root/GameBus; it is distinct from the
## production instance but carries the same script (same signal declarations).
func test_stub_swap_in_replaces_production_at_root() -> void:
	# Arrange — record the production reference before swapping
	var prod_before: Node = get_tree().root.get_node_or_null("GameBus")
	assert_bool(prod_before != null).override_failure_message(
		"Pre-condition failed: /root/GameBus not found before swap_in. "
		+ "GdUnit4 may not be mounting autoloads in the test tree."
	).is_true()

	# Act
	var stub: Node = GameBusStub.swap_in()

	# Assert — stub is now at /root/GameBus
	var at_root: Node = get_tree().root.get_node_or_null("GameBus")
	assert_bool(at_root != null).override_failure_message(
		"swap_in failed: /root/GameBus is null after swap_in"
	).is_true()

	assert_bool(at_root == stub).override_failure_message(
		"swap_in failed: /root/GameBus is not the returned stub instance"
	).is_true()

	# Assert — stub is a different instance from the original production node
	assert_bool(stub != prod_before).override_failure_message(
		"swap_in failed: stub is the same object as the production GameBus"
	).is_true()

	# Assert — stub runs the same script (same signal surface)
	var expected_script: GDScript = load(GAME_BUS_PATH) as GDScript
	assert_bool(stub.get_script() == expected_script).override_failure_message(
		"swap_in failed: stub does not use the GameBus script at '%s'" % GAME_BUS_PATH
	).is_true()

	# Assert (edge) — stub has zero connected subscribers on any user signal
	for sig: Dictionary in _get_user_signals(stub):
		var sig_name: String = sig["name"] as String
		var connection_count: int = stub.get_signal_connection_list(sig_name).size()
		assert_int(connection_count).override_failure_message(
			"AC-1 edge: fresh stub has %d subscriber(s) on signal '%s'; expected 0"
			% [connection_count, sig_name]
		).is_equal(0)

	# Cleanup — explicit swap_out prevents the detached production node from being
	# detected as an orphan by GdUnit4's between-test scan. after_test remains as
	# a belt-and-suspenders safety net for crash-before-cleanup scenarios.
	GameBusStub.swap_out()


# ── AC-2: swap_out restores the production instance ───────────────────────────


## AC-2: swap_out removes the stub and restores the original /root/GameBus.
## The stub is freed immediately (is_instance_valid(stub) == false after swap_out).
func test_stub_swap_out_restores_production() -> void:
	# Arrange
	var prod_before: Node = get_tree().root.get_node_or_null("GameBus")
	assert_bool(prod_before != null).override_failure_message(
		"Pre-condition failed: /root/GameBus not found before swap_in"
	).is_true()

	var stub: Node = GameBusStub.swap_in()

	# Sanity — stub is in place
	assert_bool(get_tree().root.get_node_or_null("GameBus") == stub).override_failure_message(
		"Pre-condition failed: stub not mounted after swap_in"
	).is_true()

	# Act
	GameBusStub.swap_out()

	# Assert — production is back at /root/GameBus
	var at_root: Node = get_tree().root.get_node_or_null("GameBus")
	assert_bool(at_root != null).override_failure_message(
		"swap_out failed: /root/GameBus is null after swap_out"
	).is_true()

	assert_bool(at_root == prod_before).override_failure_message(
		"swap_out failed: /root/GameBus is not the original production instance after swap_out"
	).is_true()

	# Assert — stub is freed (free() was called synchronously in swap_out).
	# is_instance_valid returns false for objects freed with free() — the correct
	# check when using immediate (non-deferred) deletion.
	assert_bool(is_instance_valid(stub)).override_failure_message(
		"swap_out failed: stub is still a valid instance after swap_out — free() was not called"
	).is_false()

	# Assert — exactly one node named "GameBus" at root
	var gamebus_count: int = 0
	for child: Node in get_tree().root.get_children():
		if child.name == "GameBus":
			gamebus_count += 1
	assert_int(gamebus_count).override_failure_message(
		"swap_out failed: expected exactly 1 'GameBus' child at root, found %d" % gamebus_count
	).is_equal(1)

	# after_test will call swap_out again (idempotent — covered by AC-3)


# ── AC-3: swap_out is idempotent ──────────────────────────────────────────────


## AC-3: Calling swap_out twice after one swap_in produces no error, no
## double-free, and production remains at /root/GameBus.
func test_stub_swap_out_is_idempotent() -> void:
	# Arrange
	var prod_before: Node = get_tree().root.get_node_or_null("GameBus")
	assert_bool(prod_before != null).override_failure_message(
		"Pre-condition failed: /root/GameBus not found before swap_in"
	).is_true()

	GameBusStub.swap_in()
	GameBusStub.swap_out()

	# Act — call swap_out a second time (must be a no-op)
	GameBusStub.swap_out()

	# Assert — production is still at /root/GameBus after the second swap_out
	var at_root: Node = get_tree().root.get_node_or_null("GameBus")
	assert_bool(at_root != null).override_failure_message(
		"Idempotent swap_out failed: /root/GameBus is null after second swap_out"
	).is_true()

	assert_bool(at_root == prod_before).override_failure_message(
		"Idempotent swap_out failed: /root/GameBus is not the original production instance"
	).is_true()

	# Assert — no duplicate GameBus nodes at root
	var gamebus_count: int = 0
	for child: Node in get_tree().root.get_children():
		if child.name == "GameBus":
			gamebus_count += 1
	assert_int(gamebus_count).override_failure_message(
		"Idempotent swap_out failed: %d node(s) named 'GameBus' at root after second swap_out; expected 1"
		% gamebus_count
	).is_equal(1)


## AC-3 edge: swap_out called without any prior swap_in must not error and must
## leave /root/GameBus unchanged.
func test_stub_swap_out_with_no_prior_swap_in_is_safe() -> void:
	# Arrange — before_test already called swap_out (paranoia); we are in clean state
	var prod_before: Node = get_tree().root.get_node_or_null("GameBus")

	# Act — swap_out with no prior swap_in
	GameBusStub.swap_out()

	# Assert — nothing changed
	var at_root: Node = get_tree().root.get_node_or_null("GameBus")
	assert_bool(at_root == prod_before).override_failure_message(
		"swap_out with no swap_in altered /root/GameBus unexpectedly"
	).is_true()


# ── AC-4: Signal isolation across swap ────────────────────────────────────────


## AC-4: A handler connected to the stub fires exactly once on stub emit.
## After swap_out the stub is freed, taking all its connections with it.
## New connections to the restored production GameBus work correctly.
func test_stub_signal_isolation_emits_reach_handler() -> void:
	# Arrange
	var stub: Node = GameBusStub.swap_in()

	var stub_captures: Array = []
	stub.chapter_started.connect(
		func(chapter_id: String, chapter_number: int) -> void:
			stub_captures.append({"id": chapter_id, "num": chapter_number})
	)

	# Act — emit once on the stub
	stub.chapter_started.emit("ch_isolation_test", 42)

	# Assert — handler fired exactly once with correct args
	assert_int(stub_captures.size()).override_failure_message(
		"AC-4: expected exactly 1 stub capture, got %d" % stub_captures.size()
	).is_equal(1)

	assert_str(stub_captures[0].id as String).override_failure_message(
		"AC-4: chapter_id mismatch — got '%s', expected 'ch_isolation_test'"
		% str(stub_captures[0].id)
	).is_equal("ch_isolation_test")

	assert_int(stub_captures[0].num as int).override_failure_message(
		"AC-4: chapter_number mismatch — got %d, expected 42"
		% (stub_captures[0].num as int)
	).is_equal(42)

	# Act — restore production
	GameBusStub.swap_out()

	# Assert (edge) — after swap_out, a fresh connection to production works;
	# the stub's subscriber is gone (stub is freed synchronously via free()).
	var prod: Node = get_tree().root.get_node_or_null("GameBus")
	assert_bool(prod != null).override_failure_message(
		"AC-4 edge: /root/GameBus null after swap_out"
	).is_true()

	var prod_captures: Array = []
	var prod_handler: Callable = func(chapter_id: String, _num: int) -> void:
		prod_captures.append(chapter_id)
	prod.chapter_started.connect(prod_handler)
	prod.chapter_started.emit("ch_prod_post_swap", 1)

	assert_int(prod_captures.size()).override_failure_message(
		"AC-4 edge: production emit after swap_out fired %d times, expected 1"
		% prod_captures.size()
	).is_equal(1)

	assert_str(prod_captures[0] as String).override_failure_message(
		"AC-4 edge: production capture is '%s', expected 'ch_prod_post_swap'"
		% str(prod_captures[0])
	).is_equal("ch_prod_post_swap")

	# Disconnect the observer we added — keep the production GameBus clean
	if prod.chapter_started.is_connected(prod_handler):
		prod.chapter_started.disconnect(prod_handler)


# ── AC-5: No orphaned nodes across repeated cycles ─────────────────────────────


## AC-5: Repeating swap_in / swap_out 5 times leaves exactly one node named
## "GameBus" at root each time — no orphan buildup.
func test_stub_no_orphaned_nodes_after_repeated_cycles() -> void:
	# Arrange
	var prod_before: Node = get_tree().root.get_node_or_null("GameBus")
	assert_bool(prod_before != null).override_failure_message(
		"Pre-condition failed: /root/GameBus not found before cycle test"
	).is_true()

	# Act + Assert — 5 full swap cycles
	for cycle: int in 5:
		var stub: Node = GameBusStub.swap_in()

		# After swap_in: exactly one GameBus at root (the stub)
		var count_after_in: int = 0
		for child: Node in get_tree().root.get_children():
			if child.name == "GameBus":
				count_after_in += 1

		assert_int(count_after_in).override_failure_message(
			"Cycle %d swap_in: expected 1 'GameBus' node at root, found %d"
			% [cycle, count_after_in]
		).is_equal(1)

		assert_bool(get_tree().root.get_node_or_null("GameBus") == stub).override_failure_message(
			"Cycle %d swap_in: /root/GameBus is not the stub" % cycle
		).is_true()

		GameBusStub.swap_out()

		# After swap_out: exactly one GameBus at root (the production one)
		var count_after_out: int = 0
		for child: Node in get_tree().root.get_children():
			if child.name == "GameBus":
				count_after_out += 1

		assert_int(count_after_out).override_failure_message(
			"Cycle %d swap_out: expected 1 'GameBus' node at root, found %d"
			% [cycle, count_after_out]
		).is_equal(1)

		assert_bool(get_tree().root.get_node_or_null("GameBus") == prod_before).override_failure_message(
			"Cycle %d swap_out: production not restored at /root/GameBus" % cycle
		).is_true()


# ── AC-7: Coexists with GameBusDiagnostics active ────────────────────────────


## AC-7: swap_in → 60 emits on stub → swap_out works without crashing even
## when GameBusDiagnostics is active (as it is in debug builds under GdUnit4).
##
## Diagnostic behavior on stub emits is explicitly deferred per Implementation
## Notes §3 (option a — ignore). This test asserts:
##   (a) No crash during 60 stub emits while diagnostics is running
##   (b) After swap_out, production is correctly restored at /root/GameBus
##   (c) If diagnostics is present, it re-engages with production post-swap_out
##       (confirms signal connections persist through detach/reattach cycles)
##
## NOTE: GameBusDiagnostics connects to the production GameBus at boot. When
## production is detached for the stub, the diagnostic stays connected to the
## detached object — it does NOT see the 60 stub emits. After swap_out the
## production is re-added and the diagnostic re-engages automatically.
func test_stub_coexists_with_gamebus_diagnostics() -> void:
	# Arrange
	var diagnostics: Node = get_tree().root.get_node_or_null("GameBusDiagnostics")
	# Diagnostics may be absent in release builds or if it already self-destructed.
	if diagnostics == null or diagnostics.is_queued_for_deletion():
		print("[AC-7] GameBusDiagnostics not active — "
			+ "running without diagnostic coexistence check (expected in release builds)")
		diagnostics = null

	var prod_before: Node = get_tree().root.get_node_or_null("GameBus")
	assert_bool(prod_before != null).override_failure_message(
		"Pre-condition: /root/GameBus not found before swap_in"
	).is_true()

	# Act — swap in stub
	var stub: Node = GameBusStub.swap_in()

	# Act — emit 60 signals on stub (must not crash with diagnostics active)
	# Use round_started (single int arg — simplest non-Resource signal) for bulk.
	for idx: int in 60:
		stub.round_started.emit(idx)

	# Act — swap out
	GameBusStub.swap_out()

	# Assert (b) — production restored at /root/GameBus
	var at_root: Node = get_tree().root.get_node_or_null("GameBus")
	assert_bool(at_root != null).override_failure_message(
		"AC-7: /root/GameBus is null after swap_out"
	).is_true()

	assert_bool(at_root == prod_before).override_failure_message(
		"AC-7: /root/GameBus after swap_out is not the original production instance"
	).is_true()

	# Assert — no orphan GameBus nodes
	var gamebus_count: int = 0
	for child: Node in get_tree().root.get_children():
		if child.name == "GameBus":
			gamebus_count += 1
	assert_int(gamebus_count).override_failure_message(
		"AC-7: expected exactly 1 'GameBus' node after swap_out, found %d" % gamebus_count
	).is_equal(1)

	# Assert (c) — diagnostic re-engages with production after swap_out.
	# Confirms Godot signal connections persist through remove_child/add_child.
	if diagnostics != null:
		var emits_before: int = diagnostics._emits_this_frame as int
		prod_before.chapter_started.emit("ac7_diagnostic_check", 1)
		var emits_after: int = diagnostics._emits_this_frame as int
		assert_int(emits_after).override_failure_message(
			("AC-7: diagnostic _emits_this_frame did not increment after production emit "
			+ "post-swap_out (was %d, got %d). Signal connection may not persist through "
			+ "detach/reattach cycle.") % [emits_before, emits_after]
		).is_equal(emits_before + 1)
