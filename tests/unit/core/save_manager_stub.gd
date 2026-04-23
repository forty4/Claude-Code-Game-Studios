## SaveManagerStub — test-infrastructure helper that swaps /root/SaveManager with a
## fresh instance for test isolation, redirects its save root to a temp directory,
## then restores the production instance and cleans up the temp directory.
##
## Usage pattern:
##   extends GdUnitTestSuite
##   var _stub: Node
##
##   func before_test() -> void:
##       _stub = SaveManagerStub.swap_in()
##
##   func after_test() -> void:
##       SaveManagerStub.swap_out()
##       _stub = null
##
##   func test_my_scenario() -> void:
##       # use the stub like the real SaveManager — same API, redirected save root
##       assert_int(_stub.active_slot).is_equal(1)
##       # drive the API, make assertions...
##
##       # Explicit in-body cleanup prevents GdUnit4's orphan detector from flagging
##       # the detached production node between test body end and after_test.
##       # after_test's swap_out() is a safety net for crashes, not the primary path.
##       SaveManagerStub.swap_out()
##
## ADR reference: ADR-0003 §Constraints (testing).
## Story:         Story 003 — SaveManager stub pattern for GdUnit4.
##
## PRODUCTION CODE MUST NOT CALL swap_in / swap_out.
## This is a TEST-ONLY utility. The class_name is visible project-wide only to
## make test imports cleaner — SaveManagerStub is never registered as an autoload.
##
## Save root isolation:
##   swap_in() redirects the stub's save root to a temp directory under
##   user://test_saves/[unique]/ by setting stub._save_root_override BEFORE
##   add_child() fires _ready(). This means _ensure_save_root() (called from
##   _ready()) creates directories at the temp path, not at user://saves/.
##   swap_out() recursively removes the temp directory after freeing the stub.
##
## G-10 note (autoload-identifier binding):
##   The autoload identifier `SaveManager` was bound at engine init to the
##   production node. After swap_in(), `/root/SaveManager` IS the stub, but
##   the global identifier `SaveManager` still resolves to the production instance.
##   Tests that need to verify SaveManager's GameBus handler fires must emit on
##   the REAL GameBus autoload and use the REAL /root/SaveManager, not this stub.
##   Use this stub for tests that exercise direct-method paths (set_active_slot,
##   _path_for, save_checkpoint, etc.) without a GameBus roundtrip.
##
## Known limitations:
##   - GdUnit4 runs test functions serially per suite. The static-var cache is
##     safe under serial execution. Parallel test execution within a suite would
##     break this pattern. Document as a project constraint.
##   - temp dirs live under user://test_saves/[unique]/. If a test crashes before
##     swap_out() runs, orphan temp dirs may remain. Manual cleanup:
##     rm -rf <project_data_dir>/user_test_saves/
##   - swap_in() + swap_out() trigger a full _ready() / _exit_tree() cycle on the
##     production node (remove + re-add). The production node re-subscribes to
##     GameBus on swap_out. This is the correct behavior — it mirrors engine-init
##     state exactly and leaves the production node ready for subsequent tests.
class_name SaveManagerStub
extends RefCounted

## Path to the production SaveManager script. The stub is instantiated from this
## same script so all method signatures are identical — no duplication.
const SAVE_MANAGER_PATH: String = "res://src/core/save_manager.gd"

## Cached reference to the production /root/SaveManager, stored on swap_in.
## Persists across test-function boundaries via GDScript static-var semantics.
## Reset to null on successful swap_out.
static var _cached_production: Node = null

## Cached reference to the active stub instance created by swap_in.
## Used by swap_out to distinguish the stub from the production node — prevents
## the paranoia-path swap_out (called before any swap_in) from misidentifying
## the production node as "the stub to remove".
## Reset to null on successful swap_out.
static var _active_stub: Node = null

## The temp root path used by the current active stub.
## Stored so swap_out() knows which directory to clean up.
## Reset to empty on successful swap_out.
static var _active_temp_root: String = ""


## Returns the SceneTree root Node, or null if no SceneTree is active.
## Static functions cannot call get_tree() — this helper performs the
## MainLoop -> SceneTree cast and null-guards it so callers do not crash when
## running outside a SceneTree context (e.g., tool scripts, bare unit harnesses).
static func _get_root() -> Node:
	var main_loop: MainLoop = Engine.get_main_loop()
	var tree: SceneTree = main_loop as SceneTree
	if tree == null:
		push_warning(
			"SaveManagerStub: Engine.get_main_loop() is not a SceneTree (got %s) — stub pattern requires a SceneTree main loop."
			% [main_loop]
		)
		return null
	return tree.root


## Replaces /root/SaveManager with a fresh instance of the same script.
## Redirects the stub's save root to temp_root (or an auto-generated unique path
## when temp_root is empty). Creates the temp root + 3 slot subdirs before
## add_child so _ready()'s _ensure_save_root() writes to the temp path.
##
## If a stub is already active (double swap_in), emits a push_warning, swaps out
## the first stub cleanly, then mounts the second. No orphan leak.
##
## Returns the stub Node. Returns null if no SceneTree is available.
##
## Example:
##   var stub: Node = SaveManagerStub.swap_in()
##   assert_int(stub.active_slot).is_equal(1)
##
##   # With explicit temp root:
##   var stub: Node = SaveManagerStub.swap_in("user://test_saves/my_test/")
static func swap_in(temp_root: String = "") -> Node:
	var root: Node = _get_root()
	if root == null:
		return null

	# Double swap_in guard: if a stub is already active, warn and swap it out
	# before proceeding. This keeps the invariant that _cached_production always
	# points at the original engine-boot production node, never at a prior stub.
	if _active_stub != null:
		push_warning(
			"SaveManagerStub.swap_in: a stub is already active — swapping it out before mounting a new one. "
			+ "Call swap_out() explicitly in test body to avoid this warning."
		)
		swap_out()

	# Auto-generate a unique temp root when none is provided.
	# Format: user://test_saves/<machine_id>_<ticks_msec>/
	# OS.get_unique_id() + Time.get_ticks_msec() avoids collisions across serial runs.
	var effective_temp_root: String = temp_root
	if effective_temp_root.is_empty():
		effective_temp_root = "user://test_saves/%s_%d/" % [
			OS.get_unique_id(), Time.get_ticks_msec()
		]

	# Ensure trailing slash is present so path concatenation is consistent.
	if not effective_temp_root.ends_with("/"):
		effective_temp_root += "/"

	# Create the temp directory hierarchy BEFORE add_child.
	# _ready() calls _ensure_save_root() which reads _save_root_override — if that
	# var is set before add_child, _ensure_save_root() will create dirs at the
	# override path. If we created them here first, _ensure_save_root() is idempotent.
	# We create them here anyway so AC-3 can assert their existence independently
	# of _ready() behavior, and as a belt-and-suspenders guard.
	var save_manager_script: GDScript = load(SAVE_MANAGER_PATH) as GDScript
	# SLOT_COUNT fallback `3` matches the current SaveManager.SLOT_COUNT. If that
	# constant is ever renamed, this fallback masks the drift silently. Paired with
	# AC-3 which asserts all 3 slot dirs exist — AC-3 would fail on drift.
	var slot_count: int = save_manager_script.get_script_constant_map().get("SLOT_COUNT", 3) as int
	DirAccess.make_dir_recursive_absolute(effective_temp_root)
	for i: int in range(1, slot_count + 1):
		DirAccess.make_dir_recursive_absolute("%sslot_%d" % [effective_temp_root, i])

	# Detach production. remove_child triggers _exit_tree on production, which
	# disconnects it from GameBus (no leaked subscription during the test window).
	var prod: Node = root.get_node_or_null("SaveManager")
	if prod != null:
		root.remove_child(prod)
		_cached_production = prod

	# Instantiate a fresh stub from the same script as production.
	# Set _save_root_override BEFORE add_child so _ready()'s _ensure_save_root()
	# uses the temp path, not the production user://saves/ path.
	var stub: Node = save_manager_script.new()
	stub.name = "SaveManager"
	stub.set("_save_root_override", effective_temp_root)
	root.add_child(stub)

	_active_stub = stub
	_active_temp_root = effective_temp_root
	return stub


## Restores the production /root/SaveManager, frees the stub, and removes the
## temp directory tree created by swap_in.
## Idempotent — safe to call from after_test even if swap_in was never called
## or if a prior swap_out already ran.
##
## Ordering guarantee:
##   1. remove_child on the stub (synchronous — removes from tree immediately)
##   2. free() on the stub (synchronous — object destroyed immediately, NOT queue_free)
##   3. add_child on production (synchronous — production back in tree, _ready fires)
##   4. _remove_dir_recursive on the temp root (synchronous file-system cleanup)
##   All four steps are synchronous. get_node("SaveManager") returns the production
##   instance immediately after swap_out returns and the stub is fully gone.
##
## free() vs queue_free():
##   free() is mandatory. queue_free() defers deletion to end-of-frame; GdUnit4's
##   orphan detector scans between test body exit and after_test — it would flag the
##   still-alive deferred node as a leaked orphan (exit code 101).
##
## Example:
##   func after_test() -> void:
##       SaveManagerStub.swap_out()
##       _stub = null
static func swap_out() -> void:
	# Guard: if no swap_in was ever called (_active_stub is null), there is
	# nothing to restore. Returning immediately prevents the production node from
	# being misidentified as "the stub to remove" in a paranoia-path call from
	# after_test() when the test never called swap_in().
	if _active_stub == null:
		_cached_production = null
		_active_temp_root = ""
		return

	var root: Node = _get_root()
	if root == null:
		return

	var current: Node = root.get_node_or_null("SaveManager")

	if current == _active_stub:
		# Normal case: stub is still in place. Remove + free + restore production.
		var temp_root_to_clean: String = _active_temp_root
		root.remove_child(current)
		current.free()
		if _cached_production != null and is_instance_valid(_cached_production):
			_cached_production.name = "SaveManager"  # belt-and-suspenders
			root.add_child(_cached_production)
		elif _cached_production != null:
			push_warning(
				"SaveManagerStub.swap_out: cached production node was freed externally — "
				+ "cannot restore. /root/SaveManager is now missing."
			)
		_cached_production = null
		_active_stub = null
		_active_temp_root = ""
		# Clean up temp directory after all node operations are complete.
		if not temp_root_to_clean.is_empty():
			_remove_dir_recursive(temp_root_to_clean)
		return

	# Case D — a foreign node is at /root/SaveManager (not our stub, not null).
	# Someone else mounted a node with that name after our swap_in. Don't touch
	# the foreign node; surface the anomaly and let caches clear.
	if current != null:
		push_warning(
			"SaveManagerStub.swap_out: found a foreign node named 'SaveManager' at root "
			+ "(not our stub). Cache cleared without restoration — manual cleanup may be required."
		)

	# Case C — stub already removed externally but production not yet restored.
	if current == null and _cached_production != null:
		if is_instance_valid(_cached_production):
			# Stub was already removed but production wasn't restored — restore it.
			_cached_production.name = "SaveManager"
			root.add_child(_cached_production)
		else:
			push_warning(
				"SaveManagerStub.swap_out: cached production node was freed externally — "
				+ "cannot restore. /root/SaveManager is now missing."
			)

	var temp_root_to_clean: String = _active_temp_root
	_cached_production = null
	_active_stub = null
	_active_temp_root = ""
	if not temp_root_to_clean.is_empty():
		_remove_dir_recursive(temp_root_to_clean)


## Recursively removes a directory and all its contents.
## Uses DirAccess.remove_absolute (absolute paths) throughout — DirAccess.remove()
## expects relative paths and silently fails on absolute paths (AC-8 lesson from
## save_manager_test.gd: always use the _absolute variant on user:// paths).
## Safe to call when path does not exist — returns immediately if DirAccess.open fails.
static func _remove_dir_recursive(path: String) -> void:
	# Normalize: strip trailing slash so open() works correctly on all platforms.
	var clean_path: String = path.rstrip("/")
	var da: DirAccess = DirAccess.open(clean_path)
	if da == null:
		return
	# Remove all files in this directory.
	for f: String in da.get_files():
		DirAccess.remove_absolute("%s/%s" % [clean_path, f])
	# Recurse into subdirectories before removing them (must be empty to remove).
	for d: String in da.get_directories():
		_remove_dir_recursive("%s/%s" % [clean_path, d])
	# Now remove the (now-empty) directory itself.
	DirAccess.remove_absolute(clean_path)
