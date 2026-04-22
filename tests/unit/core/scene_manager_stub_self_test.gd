extends GdUnitTestSuite

## scene_manager_stub_self_test.gd
## Self-tests for Story 002: SceneManagerStub — /root/SceneManager swap utility.
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
## NODE CLEANUP NOTE:
##   SceneManagerStub.swap_out() calls free() on the stub for immediate synchronous
##   deletion — not queue_free(). This prevents GdUnit4's orphan detector from
##   flagging the stub as a leaked node (deferred deletion leaves the object alive
##   until end-of-frame, which the detector sees as an orphan). AC-2 asserts
##   is_instance_valid(stub) == false after swap_out to confirm immediate deletion.

const SCENE_MANAGER_PATH: String = "res://src/core/scene_manager.gd"


func before_test() -> void:
	# Paranoia guard: if a prior test left _active_stub dirty (hard-failed before
	# calling swap_out), force a restore. Safe to call even when swap_in was never
	# called because swap_out() short-circuits when _active_stub is null.
	SceneManagerStub.swap_out()


func after_test() -> void:
	# Unconditional cleanup. Idempotent — safe even if the test already called
	# swap_out, or never called swap_in.
	SceneManagerStub.swap_out()


# ── AC-1: swap_in replaces production at /root/SceneManager ──────────────────


## AC-1: swap_in mounts a fresh stub at /root/SceneManager; it is distinct from the
## production instance but carries the same script (same FSM, same state surface).
func test_stub_swap_in_replaces_production_at_root() -> void:
	# Arrange — record the production reference before swapping
	var prod_before: Node = get_tree().root.get_node_or_null("SceneManager")
	assert_bool(prod_before != null).override_failure_message(
		"Pre-condition failed: /root/SceneManager not found before swap_in. "
		+ "GdUnit4 may not be mounting autoloads in the test tree."
	).is_true()

	# Act
	var stub: Node = SceneManagerStub.swap_in()

	# Assert — production was cached internally (direct check on the static cache).
	# Indirect verification (AC-2 restoring production correctly) would also fail if
	# this cache were wrong, but covering the assertion here pins down which leg of
	# the swap broke when a future regression lands.
	assert_object(SceneManagerStub._cached_production).override_failure_message(
		"AC-1: SceneManagerStub._cached_production is not the original production instance"
	).is_equal(prod_before)

	# Assert — stub is now at /root/SceneManager
	var at_root: Node = get_tree().root.get_node_or_null("SceneManager")
	assert_bool(at_root != null).override_failure_message(
		"swap_in failed: /root/SceneManager is null after swap_in"
	).is_true()

	assert_bool(at_root == stub).override_failure_message(
		"swap_in failed: /root/SceneManager is not the returned stub instance"
	).is_true()

	# Assert — stub is a different instance from the original production node
	assert_bool(stub != prod_before).override_failure_message(
		"swap_in failed: stub is the same object as the production SceneManager"
	).is_true()

	# Assert — stub runs the same script (same FSM surface)
	var expected_script: GDScript = load(SCENE_MANAGER_PATH) as GDScript
	assert_bool(stub.get_script() == expected_script).override_failure_message(
		"swap_in failed: stub does not use the SceneManager script at '%s'" % SCENE_MANAGER_PATH
	).is_true()

	# Assert (edge) — fresh stub starts in State.IDLE regardless of production state.
	# stub.State.IDLE resolves via the instance's script enum — the production script
	# has no class_name (G-3: autoloads must not declare class_name), so the enum is
	# accessed through the instance rather than a class reference.
	assert_bool(stub.state == stub.State.IDLE).override_failure_message(
		"AC-1 edge: fresh stub state is %d, expected State.IDLE (%d)"
		% [stub.state as int, stub.State.IDLE as int]
	).is_true()

	# Cleanup — explicit swap_out prevents the detached production node from being
	# detected as an orphan by GdUnit4's between-test scan. after_test remains as
	# a belt-and-suspenders safety net for crash-before-cleanup scenarios.
	SceneManagerStub.swap_out()


# ── AC-2: swap_out restores the production instance ───────────────────────────


## AC-2: swap_out removes the stub and restores the original /root/SceneManager.
## The stub is freed immediately (is_instance_valid(stub) == false after swap_out).
func test_stub_swap_out_restores_production() -> void:
	# Arrange
	var prod_before: Node = get_tree().root.get_node_or_null("SceneManager")
	assert_bool(prod_before != null).override_failure_message(
		"Pre-condition failed: /root/SceneManager not found before swap_in"
	).is_true()

	var stub: Node = SceneManagerStub.swap_in()

	# Sanity — stub is in place
	assert_bool(get_tree().root.get_node_or_null("SceneManager") == stub).override_failure_message(
		"Pre-condition failed: stub not mounted after swap_in"
	).is_true()

	# Act
	SceneManagerStub.swap_out()

	# Assert — production is back at /root/SceneManager
	var at_root: Node = get_tree().root.get_node_or_null("SceneManager")
	assert_bool(at_root != null).override_failure_message(
		"swap_out failed: /root/SceneManager is null after swap_out"
	).is_true()

	assert_bool(at_root == prod_before).override_failure_message(
		"swap_out failed: /root/SceneManager is not the original production instance after swap_out"
	).is_true()

	# Assert — stub is freed (free() was called synchronously in swap_out).
	# is_instance_valid returns false for objects freed with free() — the correct
	# check when using immediate (non-deferred) deletion.
	assert_bool(is_instance_valid(stub)).override_failure_message(
		"swap_out failed: stub is still a valid instance after swap_out — free() was not called"
	).is_false()

	# Assert — exactly one node named "SceneManager" at root
	var scene_manager_count: int = 0
	for child: Node in get_tree().root.get_children():
		if child.name == "SceneManager":
			scene_manager_count += 1
	assert_int(scene_manager_count).override_failure_message(
		"swap_out failed: expected exactly 1 'SceneManager' child at root, found %d" % scene_manager_count
	).is_equal(1)

	# after_test will call swap_out again (idempotent — covered by AC-3)


# ── AC-3: swap_out is idempotent ──────────────────────────────────────────────


## AC-3: Calling swap_out twice after one swap_in produces no error, no
## double-free, and production remains at /root/SceneManager.
func test_stub_swap_out_is_idempotent() -> void:
	# Arrange
	var prod_before: Node = get_tree().root.get_node_or_null("SceneManager")
	assert_bool(prod_before != null).override_failure_message(
		"Pre-condition failed: /root/SceneManager not found before swap_in"
	).is_true()

	SceneManagerStub.swap_in()
	SceneManagerStub.swap_out()

	# Act — call swap_out a second time (must be a no-op)
	SceneManagerStub.swap_out()

	# Assert — production is still at /root/SceneManager after the second swap_out
	var at_root: Node = get_tree().root.get_node_or_null("SceneManager")
	assert_bool(at_root != null).override_failure_message(
		"Idempotent swap_out failed: /root/SceneManager is null after second swap_out"
	).is_true()

	assert_bool(at_root == prod_before).override_failure_message(
		"Idempotent swap_out failed: /root/SceneManager is not the original production instance"
	).is_true()

	# Assert — no duplicate SceneManager nodes at root
	var scene_manager_count: int = 0
	for child: Node in get_tree().root.get_children():
		if child.name == "SceneManager":
			scene_manager_count += 1
	assert_int(scene_manager_count).override_failure_message(
		("Idempotent swap_out failed: %d node(s) named 'SceneManager' at root after second swap_out; expected 1"
		% scene_manager_count)
	).is_equal(1)


## AC-3 edge: swap_out called without any prior swap_in must not error and must
## leave /root/SceneManager unchanged.
func test_stub_swap_out_with_no_prior_swap_in_is_safe() -> void:
	# Arrange — before_test already called swap_out (paranoia); we are in clean state
	var prod_before: Node = get_tree().root.get_node_or_null("SceneManager")

	# Act — swap_out with no prior swap_in
	SceneManagerStub.swap_out()

	# Assert — nothing changed
	var at_root: Node = get_tree().root.get_node_or_null("SceneManager")
	assert_bool(at_root == prod_before).override_failure_message(
		"swap_out with no swap_in altered /root/SceneManager unexpectedly"
	).is_true()


# ── AC-4: State isolation — fresh stub always starts in State.IDLE ────────────


## AC-4: A fresh stub starts in State.IDLE regardless of what state production
## was in. Mutating the stub's internal _state does NOT affect the production
## instance (verified by reading production.state after swap_out).
func test_stub_state_isolation_fresh_stub_starts_in_idle() -> void:
	# Arrange
	var stub: Node = SceneManagerStub.swap_in()

	# Assert — stub starts in IDLE.
	# stub.State.IDLE resolves via the instance's script enum (no class_name on autoload).
	assert_bool(stub.state == stub.State.IDLE).override_failure_message(
		("AC-4: fresh stub state is %d, expected State.IDLE (%d). "
		+ "Stub did not start with a fresh FSM.")
		% [stub.state as int, stub.State.IDLE as int]
	).is_true()

	# Act — mutate stub's internal state directly (bypass the read-only property guard).
	# This simulates what would happen if a test drives the stub through a transition.
	stub._state = stub.State.IN_BATTLE

	# Assert — mutation is visible on the stub
	assert_bool(stub._state == stub.State.IN_BATTLE).override_failure_message(
		"AC-4: _state mutation on stub did not take effect — test setup error"
	).is_true()

	# Act — restore production
	SceneManagerStub.swap_out()

	# Assert (edge) — production state is unaffected by stub mutation.
	# This is the primary isolation guarantee: the stub and production are
	# separate instances; writing to stub._state never touches production._state.
	var prod: Node = get_tree().root.get_node_or_null("SceneManager")
	assert_bool(prod != null).override_failure_message(
		"AC-4 edge: /root/SceneManager null after swap_out"
	).is_true()

	assert_bool(prod.state == prod.State.IDLE).override_failure_message(
		("AC-4 edge: production state is %d after stub mutation + swap_out; "
		+ "expected State.IDLE (%d). Stub mutation leaked into production.")
		% [prod.state as int, prod.State.IDLE as int]
	).is_true()


# ── AC-5: No orphaned nodes across repeated cycles ─────────────────────────────


## AC-5: Repeating swap_in / swap_out 5 times leaves exactly one node named
## "SceneManager" at root each time — no orphan buildup.
func test_stub_no_orphaned_nodes_after_repeated_cycles() -> void:
	# Arrange
	var prod_before: Node = get_tree().root.get_node_or_null("SceneManager")
	assert_bool(prod_before != null).override_failure_message(
		"Pre-condition failed: /root/SceneManager not found before cycle test"
	).is_true()

	# Act + Assert — 5 full swap cycles
	for cycle: int in 5:
		var stub: Node = SceneManagerStub.swap_in()

		# After swap_in: exactly one SceneManager at root (the stub)
		var count_after_in: int = 0
		for child: Node in get_tree().root.get_children():
			if child.name == "SceneManager":
				count_after_in += 1

		assert_int(count_after_in).override_failure_message(
			"Cycle %d swap_in: expected 1 'SceneManager' node at root, found %d"
			% [cycle, count_after_in]
		).is_equal(1)

		assert_bool(get_tree().root.get_node_or_null("SceneManager") == stub).override_failure_message(
			"Cycle %d swap_in: /root/SceneManager is not the stub" % cycle
		).is_true()

		SceneManagerStub.swap_out()

		# After swap_out: exactly one SceneManager at root (the production one)
		var count_after_out: int = 0
		for child: Node in get_tree().root.get_children():
			if child.name == "SceneManager":
				count_after_out += 1

		assert_int(count_after_out).override_failure_message(
			"Cycle %d swap_out: expected 1 'SceneManager' node at root, found %d"
			% [cycle, count_after_out]
		).is_equal(1)

		assert_bool(get_tree().root.get_node_or_null("SceneManager") == prod_before).override_failure_message(
			"Cycle %d swap_out: production not restored at /root/SceneManager" % cycle
		).is_true()


# ── AC-7: Coexists with GameBusDiagnostics active ────────────────────────────


## AC-7: swap_in -> swap_out works without crashing even when GameBusDiagnostics
## is active (as it is in debug builds under GdUnit4).
##
## Unlike the GameBusStub AC-7, the SceneManager stub does not emit on GameBus
## itself — its _ready() subscribes to GameBus but does not emit. This test
## asserts:
##   (a) No crash during swap_in / swap_out while diagnostics is running
##   (b) After swap_out, production is correctly restored at /root/SceneManager
##   (c) If diagnostics is present, it is still valid after swap_out
##       (swap cycle did not accidentally free or corrupt the diagnostic node)
##
## NOTE: The stub's _ready() connects to GameBus with CONNECT_DEFERRED, creating
## new subscriptions on the fresh stub. When swap_out frees the stub, those
## subscriptions are automatically removed. The production SceneManager's
## subscriptions (connected at boot) are unaffected by the swap cycle.
func test_stub_coexists_with_gamebus_diagnostics() -> void:
	# Arrange
	var diagnostics: Node = get_tree().root.get_node_or_null("GameBusDiagnostics")
	# Diagnostics may be absent in release builds or if it already self-destructed.
	if diagnostics == null or diagnostics.is_queued_for_deletion():
		print("[AC-7] GameBusDiagnostics not active — "
			+ "running without diagnostic coexistence check (expected in release builds)")
		diagnostics = null

	var prod_before: Node = get_tree().root.get_node_or_null("SceneManager")
	assert_bool(prod_before != null).override_failure_message(
		"Pre-condition: /root/SceneManager not found before swap_in"
	).is_true()

	# Act — swap in stub (stub._ready subscribes to GameBus; must not crash diagnostics)
	var stub: Node = SceneManagerStub.swap_in()

	# Assert (a) — stub is in place with no crash from diagnostics observing the swap
	assert_bool(is_instance_valid(stub)).override_failure_message(
		"AC-7: stub is not valid immediately after swap_in — _ready() may have crashed"
	).is_true()

	# Act — emit 60 GameBus signals during the swap window. This exercises the
	# full traffic path (GameBus → diagnostics, with the SceneManager stub in place
	# as a co-subscriber) and proves no crash occurs under emission. round_started
	# is a single-int signal — simplest non-Resource emission matching the
	# GameBusStub AC-7 precedent.
	for idx: int in 60:
		GameBus.round_started.emit(idx)

	# Act — swap out
	SceneManagerStub.swap_out()

	# Assert (b) — production restored at /root/SceneManager
	var at_root: Node = get_tree().root.get_node_or_null("SceneManager")
	assert_bool(at_root != null).override_failure_message(
		"AC-7: /root/SceneManager is null after swap_out"
	).is_true()

	assert_bool(at_root == prod_before).override_failure_message(
		"AC-7: /root/SceneManager after swap_out is not the original production instance"
	).is_true()

	# Assert — no orphan SceneManager nodes
	var scene_manager_count: int = 0
	for child: Node in get_tree().root.get_children():
		if child.name == "SceneManager":
			scene_manager_count += 1
	assert_int(scene_manager_count).override_failure_message(
		"AC-7: expected exactly 1 'SceneManager' node after swap_out, found %d" % scene_manager_count
	).is_equal(1)

	# Assert (c) — diagnostic is still valid after swap cycle.
	# Confirms the swap did not accidentally free or corrupt the diagnostic node.
	if diagnostics != null:
		assert_bool(is_instance_valid(diagnostics)).override_failure_message(
			"AC-7: GameBusDiagnostics node is no longer valid after SceneManager swap cycle — "
			+ "swap_out may have freed or corrupted it unexpectedly"
		).is_true()
