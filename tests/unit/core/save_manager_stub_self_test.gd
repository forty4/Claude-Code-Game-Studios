extends GdUnitTestSuite

## save_manager_stub_self_test.gd
## Self-tests for Story 003: SaveManagerStub — /root/SaveManager swap utility
## with user://saves isolation via _save_root_override seam.
##
## Covers AC-1 through AC-7 per story QA Test Cases.
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
##   AC-1 and AC-7 need to verify the pre-swap state directly.
##
## LIFECYCLE:
##   before_test — paranoia swap_out() (no-op when _active_stub is null)
##   test body   — explicit swap_out() at end of any test that calls swap_in()
##   after_test  — unconditional swap_out() (idempotent belt-and-suspenders)
##
## G-10 NOTE (AC-1):
##   AC-1 verifies the node AT the path /root/SaveManager, NOT the global
##   identifier. The global identifier `SaveManager` binds at engine init and
##   always resolves to the production node regardless of what node is mounted
##   at /root/SaveManager. Accordingly, AC-1 asserts:
##     get_tree().root.get_node("SaveManager") == stub  ← CORRECT
##   And NOT:
##     SaveManager == stub  ← WRONG — global identifier never changes
##
## NODE CLEANUP NOTE:
##   SaveManagerStub.swap_out() calls free() on the stub for immediate synchronous
##   deletion — not queue_free(). This prevents GdUnit4's orphan detector from
##   flagging the stub as a leaked node. AC-2 asserts is_instance_valid(stub) == false
##   after swap_out to confirm immediate deletion.
##
## TEMP DIR NOTE:
##   AC-3 and AC-5 use explicit temp root paths under user://test_saves/ for
##   deterministic assertion. All temp dirs are removed by swap_out() or by the
##   test body directly. If a test crashes before swap_out, orphan dirs may
##   remain under user://test_saves/ — safe to delete manually.

const SAVE_MANAGER_PATH: String = "res://src/core/save_manager.gd"

## Deterministic temp root for AC-3: directory existence assertions.
const AC3_TEMP_ROOT: String = "user://test_saves/stub_self_test_ac3/"

## Deterministic temp root for AC-4: _path_for override assertion.
const AC4_TEMP_ROOT: String = "user://test_saves/stub_self_test_ac4/"

## Deterministic temp root for AC-5: cleanup assertion.
const AC5_TEMP_ROOT: String = "user://test_saves/stub_self_test_ac5/"

## Deterministic temp roots for AC-6: double swap_in invariant.
const AC6_TEMP_ROOT_1: String = "user://test_saves/stub_self_test_ac6_first/"
const AC6_TEMP_ROOT_2: String = "user://test_saves/stub_self_test_ac6_second/"


func before_test() -> void:
	# Paranoia guard: if a prior test left _active_stub dirty (hard-failed before
	# calling swap_out), force a restore. Safe to call even when swap_in was never
	# called because swap_out() short-circuits when _active_stub is null.
	SaveManagerStub.swap_out()


func after_test() -> void:
	# Unconditional cleanup. Idempotent — safe even if the test already called
	# swap_out, or never called swap_in.
	SaveManagerStub.swap_out()


# ── AC-1: swap_in mounts stub at /root/SaveManager ────────────────────────────


## AC-1: swap_in mounts a fresh stub at /root/SaveManager and caches production.
##
## G-10 NOTE: The node AT /root/SaveManager after swap_in IS the stub.
## The global identifier `SaveManager` still resolves to the production instance
## bound at engine init. We verify via get_node() path traversal, NOT via the
## global identifier.
func test_stub_swap_in_mounts_stub_at_root_save_manager() -> void:
	# Arrange — record the production reference before swapping
	var prod_before: Node = get_tree().root.get_node_or_null("SaveManager")
	assert_bool(prod_before != null).override_failure_message(
		"Pre-condition failed: /root/SaveManager not found before swap_in. "
		+ "GdUnit4 may not be mounting autoloads in the test tree."
	).is_true()

	# Act
	var stub: Node = SaveManagerStub.swap_in()

	# Assert — stub is now at /root/SaveManager (node-at-path check, NOT global identifier).
	# Per G-10: global identifier `SaveManager` always resolves to the production node
	# bound at engine init. Only the path-based get_node() reflects the current mount.
	var at_root: Node = get_tree().root.get_node_or_null("SaveManager")
	assert_bool(at_root != null).override_failure_message(
		"AC-1: /root/SaveManager is null after swap_in"
	).is_true()

	assert_bool(at_root == stub).override_failure_message(
		"AC-1: /root/SaveManager is not the returned stub instance"
	).is_true()

	# Assert — stub is a different instance from the original production node
	assert_bool(stub != prod_before).override_failure_message(
		"AC-1: stub is the same object as the production SaveManager"
	).is_true()

	# Assert — stub runs the same script as production
	var expected_script: GDScript = load(SAVE_MANAGER_PATH) as GDScript
	assert_bool(stub.get_script() == expected_script).override_failure_message(
		"AC-1: stub does not use the SaveManager script at '%s'" % SAVE_MANAGER_PATH
	).is_true()

	# Assert — _cached_production is non-null and is the original production node
	assert_bool(SaveManagerStub._cached_production != null).override_failure_message(
		"AC-1: SaveManagerStub._cached_production is null after swap_in"
	).is_true()

	assert_bool(is_instance_valid(SaveManagerStub._cached_production)).override_failure_message(
		"AC-1: SaveManagerStub._cached_production is not a valid instance after swap_in"
	).is_true()

	assert_object(SaveManagerStub._cached_production).override_failure_message(
		"AC-1: SaveManagerStub._cached_production is not the original production instance"
	).is_equal(prod_before)

	# Cleanup — explicit swap_out prevents the detached production node from being
	# detected as an orphan by GdUnit4's between-test scan.
	SaveManagerStub.swap_out()


# ── AC-2: swap_out restores production and frees stub ─────────────────────────


## AC-2: swap_out removes the stub, frees it immediately, and restores production.
## is_instance_valid(stub) == false after swap_out confirms free() was used (not queue_free).
func test_stub_swap_out_restores_production_and_frees_stub() -> void:
	# Arrange
	var prod_before: Node = get_tree().root.get_node_or_null("SaveManager")
	assert_bool(prod_before != null).override_failure_message(
		"Pre-condition failed: /root/SaveManager not found before swap_in"
	).is_true()

	var stub: Node = SaveManagerStub.swap_in()

	# Sanity — stub is in place
	assert_bool(get_tree().root.get_node_or_null("SaveManager") == stub).override_failure_message(
		"Pre-condition: stub not mounted after swap_in"
	).is_true()

	# Act
	SaveManagerStub.swap_out()

	# Assert — production is back at /root/SaveManager
	var at_root: Node = get_tree().root.get_node_or_null("SaveManager")
	assert_bool(at_root != null).override_failure_message(
		"AC-2: /root/SaveManager is null after swap_out"
	).is_true()

	assert_bool(at_root == prod_before).override_failure_message(
		"AC-2: /root/SaveManager is not the original production instance after swap_out"
	).is_true()

	# Assert — stub is freed synchronously (free() not queue_free).
	# is_instance_valid returns false for objects freed with free() immediately.
	assert_bool(is_instance_valid(stub)).override_failure_message(
		"AC-2: stub is still a valid instance after swap_out — free() was not called"
	).is_false()

	# Assert — exactly one node named "SaveManager" at root (no duplicates)
	var save_manager_count: int = 0
	for child: Node in get_tree().root.get_children():
		if child.name == "SaveManager":
			save_manager_count += 1
	assert_int(save_manager_count).override_failure_message(
		"AC-2: expected exactly 1 'SaveManager' child at root, found %d" % save_manager_count
	).is_equal(1)

	# after_test will call swap_out again (idempotent — no double-free risk)


# ── AC-3: temp dir created with override ──────────────────────────────────────


## AC-3: swap_in with explicit temp_root creates the save root + 3 slot dirs.
## Verifies DirAccess.dir_exists_absolute for root, slot_1, slot_2, slot_3.
## swap_out removes the entire directory tree.
func test_stub_swap_in_creates_temp_dir_structure() -> void:
	# Act — swap in with a deterministic temp root
	var stub: Node = SaveManagerStub.swap_in(AC3_TEMP_ROOT)

	# Assert — temp root exists
	assert_bool(DirAccess.dir_exists_absolute(AC3_TEMP_ROOT)).override_failure_message(
		"AC-3: temp root '%s' does not exist after swap_in" % AC3_TEMP_ROOT
	).is_true()

	# Assert — all 3 slot subdirectories exist
	assert_bool(DirAccess.dir_exists_absolute(AC3_TEMP_ROOT + "slot_1")).override_failure_message(
		"AC-3: slot_1 directory not found under temp root"
	).is_true()

	assert_bool(DirAccess.dir_exists_absolute(AC3_TEMP_ROOT + "slot_2")).override_failure_message(
		"AC-3: slot_2 directory not found under temp root"
	).is_true()

	assert_bool(DirAccess.dir_exists_absolute(AC3_TEMP_ROOT + "slot_3")).override_failure_message(
		"AC-3: slot_3 directory not found under temp root"
	).is_true()

	# Cleanup — swap_out removes the entire temp dir tree
	SaveManagerStub.swap_out()

	# Assert — temp root is gone after swap_out
	assert_bool(DirAccess.dir_exists_absolute(AC3_TEMP_ROOT)).override_failure_message(
		"AC-3: temp root '%s' still exists after swap_out — cleanup failed" % AC3_TEMP_ROOT
	).is_false()


# ── AC-4: SAVE_ROOT override takes effect via _path_for ───────────────────────


## AC-4: _path_for on the stub returns a path under the temp root, not user://saves/.
## This proves _effective_save_root() is used by _path_for rather than SAVE_ROOT directly.
func test_stub_path_for_uses_override_root() -> void:
	# Arrange — swap in with a known temp root (trailing slash is normalized by swap_in)
	var stub: Node = SaveManagerStub.swap_in(AC4_TEMP_ROOT)

	# Act — call _path_for directly (leading underscore is convention-only in GDScript;
	# access is not restricted — same pattern used in save_manager_test.gd AC-9)
	var got: String = stub._path_for(1, 5, 2)

	# Assert — returned path starts with the temp root, NOT the production user://saves
	assert_bool(got.begins_with(AC4_TEMP_ROOT)).override_failure_message(
		("AC-4: _path_for returned '%s'; expected path beginning with '%s'. "
		+ "_effective_save_root() may not be wired to _path_for correctly.")
		% [got, AC4_TEMP_ROOT]
	).is_true()

	assert_bool(not got.begins_with("user://saves")).override_failure_message(
		("AC-4: _path_for returned '%s' which begins with 'user://saves'; "
		+ "the production save root is leaking through the override seam.")
		% [got]
	).is_true()

	# Assert — path still has the correct format (slot, chapter, cp components present)
	assert_bool(got.contains("slot_1")).override_failure_message(
		"AC-4: _path_for result '%s' missing expected 'slot_1' component" % got
	).is_true()

	assert_bool(got.contains("ch_05")).override_failure_message(
		"AC-4: _path_for result '%s' missing expected 'ch_05' component (zero-padded)" % got
	).is_true()

	assert_bool(got.contains("cp_2")).override_failure_message(
		"AC-4: _path_for result '%s' missing expected 'cp_2' component" % got
	).is_true()

	assert_bool(got.ends_with(".res")).override_failure_message(
		"AC-4: _path_for result '%s' missing expected '.res' extension" % got
	).is_true()

	# Cleanup
	SaveManagerStub.swap_out()


# ── AC-5: temp dir cleanup after swap_out removes all files ───────────────────


## AC-5: swap_out recursively removes the temp directory even when it contains files.
## A dummy file is written to slot_1 to verify non-empty-dir cleanup works correctly.
func test_stub_swap_out_cleans_up_temp_dir_recursively() -> void:
	# Arrange — swap in, then write a dummy file into the temp hierarchy
	var _stub: Node = SaveManagerStub.swap_in(AC5_TEMP_ROOT)

	var dummy_path: String = AC5_TEMP_ROOT + "slot_1/dummy.res"
	var fa: FileAccess = FileAccess.open(dummy_path, FileAccess.WRITE)
	assert_object(fa).override_failure_message(
		"AC-5 setup: could not open dummy file for writing at '%s'" % dummy_path
	).is_not_null()
	if fa != null:
		fa.store_string("dummy")
		fa.close()

	# Pre-condition: file exists
	assert_bool(FileAccess.file_exists(dummy_path)).override_failure_message(
		"AC-5 setup: dummy file not found at '%s' before swap_out" % dummy_path
	).is_true()

	# Act — swap_out must recursively remove all contents including the dummy file
	SaveManagerStub.swap_out()

	# Assert — entire temp root is gone (recursive removal succeeded)
	assert_bool(DirAccess.dir_exists_absolute(AC5_TEMP_ROOT)).override_failure_message(
		("AC-5: temp root '%s' still exists after swap_out — recursive cleanup failed. "
		+ "The dummy file in slot_1/ may have blocked DirAccess.remove_absolute on the parent dir.")
		% AC5_TEMP_ROOT
	).is_false()


# ── AC-6: double swap_in warns gracefully, no orphan leak ─────────────────────


## AC-6: A second swap_in while a stub is already active emits push_warning and
## swaps out the first stub cleanly before mounting the second.
##
## push_warning cannot be intercepted in GdUnit4 v6.1.2 (same limitation as
## push_error — see story-002 AC-6 precedent). We verify invariants instead:
##   - stub1 is freed (no orphan leak)
##   - stub2 is the node at /root/SaveManager
##   - _cached_production still points at the original production (not stub1)
func test_stub_double_swap_in_cleans_up_first_stub() -> void:
	# Arrange — record original production before any swap
	var prod_original: Node = get_tree().root.get_node_or_null("SaveManager")
	assert_bool(prod_original != null).override_failure_message(
		"Pre-condition: /root/SaveManager not found before double-swap test"
	).is_true()

	# Act — first swap_in
	var stub1: Node = SaveManagerStub.swap_in(AC6_TEMP_ROOT_1)

	# Sanity — stub1 is mounted
	assert_bool(get_tree().root.get_node_or_null("SaveManager") == stub1).override_failure_message(
		"Pre-condition: stub1 not mounted after first swap_in"
	).is_true()

	# Act — second swap_in (triggers push_warning + auto-swap_out of stub1)
	var stub2: Node = SaveManagerStub.swap_in(AC6_TEMP_ROOT_2)

	# Assert invariant 1: stub1 is freed (no orphan leak from the double-swap)
	assert_bool(is_instance_valid(stub1)).override_failure_message(
		("AC-6: stub1 is still a valid instance after second swap_in. "
		+ "The first stub was not freed — orphan leak risk.")
	).is_false()

	# Assert invariant 2: stub2 is now the node at /root/SaveManager
	var at_root: Node = get_tree().root.get_node_or_null("SaveManager")
	assert_bool(at_root == stub2).override_failure_message(
		"AC-6: /root/SaveManager is not stub2 after double swap_in"
	).is_true()

	# Assert invariant 3: _cached_production is the original engine-boot production,
	# not stub1 (the double-swap must NOT have overwritten the cache with stub1).
	assert_bool(is_instance_valid(SaveManagerStub._cached_production)).override_failure_message(
		"AC-6: _cached_production is no longer a valid instance after double swap_in"
	).is_true()

	assert_object(SaveManagerStub._cached_production).override_failure_message(
		("AC-6: _cached_production is not the original production instance. "
		+ "The double-swap may have overwritten the cache with stub1.")
	).is_equal(prod_original)

	# Assert invariant 4: only one SaveManager node at root (no duplicate)
	var save_manager_count: int = 0
	for child: Node in get_tree().root.get_children():
		if child.name == "SaveManager":
			save_manager_count += 1
	assert_int(save_manager_count).override_failure_message(
		"AC-6: expected exactly 1 'SaveManager' node at root after double swap_in, found %d"
		% save_manager_count
	).is_equal(1)

	# Cleanup — swap_out removes stub2 and restores production
	SaveManagerStub.swap_out()

	# Confirm production is back
	assert_bool(get_tree().root.get_node_or_null("SaveManager") == prod_original).override_failure_message(
		"AC-6 cleanup: production not restored after swap_out following double swap_in"
	).is_true()

	# AC-6 Gap 3 fix: confirm BOTH temp dirs were cleaned up. If _active_temp_root
	# handoff between swap cycles is broken, the first temp dir could silently leak.
	# Current implementation: second swap_in's internal swap_out cleans AC6_TEMP_ROOT_1;
	# final explicit swap_out cleans AC6_TEMP_ROOT_2. Both must be gone.
	assert_bool(DirAccess.dir_exists_absolute(AC6_TEMP_ROOT_1)).override_failure_message(
		("AC-6: first temp dir '%s' not cleaned up after double-swap + swap_out. "
		+ "_active_temp_root handoff between swap cycles is broken.") % AC6_TEMP_ROOT_1
	).is_false()
	assert_bool(DirAccess.dir_exists_absolute(AC6_TEMP_ROOT_2)).override_failure_message(
		("AC-6: second temp dir '%s' not cleaned up after final swap_out.") % AC6_TEMP_ROOT_2
	).is_false()


# ── AC-7: swap_out on unswapped state is no-op ────────────────────────────────


## AC-7: swap_out called with no prior swap_in is a no-op.
## /root/SaveManager remains unchanged; no error or crash.
## before_test already called swap_out() (paranoia guard), so we are in clean state.
func test_stub_swap_out_with_no_prior_swap_in_is_no_op() -> void:
	# Arrange — record production before the no-op call
	var prod_before: Node = get_tree().root.get_node_or_null("SaveManager")

	# Act — swap_out with no prior swap_in (should short-circuit silently)
	SaveManagerStub.swap_out()

	# Assert — /root/SaveManager is unchanged
	var at_root: Node = get_tree().root.get_node_or_null("SaveManager")
	assert_bool(at_root == prod_before).override_failure_message(
		"AC-7: swap_out with no prior swap_in altered /root/SaveManager unexpectedly"
	).is_true()

	# Assert — production node is still valid (nothing was freed)
	assert_bool(is_instance_valid(prod_before)).override_failure_message(
		"AC-7: production node is no longer valid after no-op swap_out"
	).is_true()

	# Assert — no duplicate SaveManager nodes appeared
	var save_manager_count: int = 0
	for child: Node in get_tree().root.get_children():
		if child.name == "SaveManager":
			save_manager_count += 1
	assert_int(save_manager_count).override_failure_message(
		"AC-7: expected exactly 1 'SaveManager' node at root after no-op swap_out, found %d"
		% save_manager_count
	).is_equal(1)


# ── Multi-cycle + idempotency regression (Gap 1 + Gap 2 from qa-tester) ──────


## Regression test: 3 full swap_in/swap_out cycles do not accumulate orphan temp
## dirs or duplicate nodes. Also covers Gap 1 (idempotent swap_out) by asserting
## a second swap_out after one cycle is a safe no-op.
##
## Context: story-007 (perf) will run 100 iterations of the full save cycle under
## SaveManagerStub. If any cycle leaks a temp dir or leaves a duplicate node, the
## failure mode may only manifest at iteration 50+ with expensive debugging.
## This 3-cycle test catches the regression class at the story-003 level rather
## than deferring discovery to story-007.
##
## Precedent: scene_manager_stub_self_test.gd has an analogous multi-cycle test.
func test_stub_three_cycles_leave_no_orphans_and_swap_out_is_idempotent() -> void:
	# Arrange — record original production; compute deterministic temp roots per cycle
	var prod_original: Node = get_tree().root.get_node_or_null("SaveManager")
	assert_bool(prod_original != null).override_failure_message(
		"Pre-condition: /root/SaveManager not found before multi-cycle test"
	).is_true()

	var cycle_roots: Array[String] = [
		"user://test_saves/stub_self_test_cycle_0/",
		"user://test_saves/stub_self_test_cycle_1/",
		"user://test_saves/stub_self_test_cycle_2/",
	]

	# Act — run 3 full swap_in/swap_out cycles
	for i: int in range(3):
		var stub: Node = SaveManagerStub.swap_in(cycle_roots[i])

		# Cycle invariant: exactly one SaveManager at root; stub is that node
		var cycle_count: int = 0
		for child: Node in get_tree().root.get_children():
			if child.name == "SaveManager":
				cycle_count += 1
		assert_int(cycle_count).override_failure_message(
			"Cycle %d: expected 1 'SaveManager' node after swap_in, found %d" % [i, cycle_count]
		).is_equal(1)

		# Temp dir exists during the swap window
		assert_bool(DirAccess.dir_exists_absolute(cycle_roots[i])).override_failure_message(
			"Cycle %d: temp dir '%s' not created after swap_in" % [i, cycle_roots[i]]
		).is_true()

		SaveManagerStub.swap_out()

		# Production restored + cycle temp dir cleaned
		assert_bool(get_tree().root.get_node_or_null("SaveManager") == prod_original).override_failure_message(
			"Cycle %d: production not restored after swap_out" % i
		).is_true()
		assert_bool(DirAccess.dir_exists_absolute(cycle_roots[i])).override_failure_message(
			"Cycle %d: temp dir '%s' not cleaned up after swap_out (orphan leak)" % [i, cycle_roots[i]]
		).is_false()

	# Gap 1 assertion: a second swap_out after the loop is a safe no-op.
	# _active_stub is null at this point; swap_out must short-circuit without error.
	SaveManagerStub.swap_out()  # Idempotent: must not crash, must not duplicate production
	assert_bool(get_tree().root.get_node_or_null("SaveManager") == prod_original).override_failure_message(
		"Idempotent swap_out: second swap_out (no active stub) altered /root/SaveManager"
	).is_true()

	# Final: exactly one SaveManager at root after all cycles + idempotent tail call
	var final_count: int = 0
	for child: Node in get_tree().root.get_children():
		if child.name == "SaveManager":
			final_count += 1
	assert_int(final_count).override_failure_message(
		"Multi-cycle: expected 1 'SaveManager' node at root after 3 cycles + idempotent swap_out, found %d"
		% final_count
	).is_equal(1)
