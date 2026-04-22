## SceneManagerStub — test-infrastructure helper that swaps /root/SceneManager with a
## fresh instance for test isolation, then restores the production instance.
##
## Usage pattern:
##   extends GdUnitTestSuite
##   var _stub: Node
##
##   func before_test() -> void:
##       _stub = SceneManagerStub.swap_in()
##
##   func after_test() -> void:
##       SceneManagerStub.swap_out()
##       _stub = null
##
##   func test_my_scenario() -> void:
##       # use the stub like the real SceneManager — same FSM, same state surface
##       assert_int(_stub.state).is_equal(_stub.State.IDLE)
##       # assertions...
##
##       # Explicit in-body cleanup prevents GdUnit4's orphan detector from flagging
##       # the detached production node between test body end and after_test.
##       # after_test's swap_out() is a safety net for crashes, not the primary path.
##       SceneManagerStub.swap_out()
##
## ADR reference: ADR-0002 §Validation Criteria V-10.
## Story:         Story 002 — SceneManager stub pattern for GdUnit4.
##
## PRODUCTION CODE MUST NOT CALL swap_in / swap_out.
## This is a TEST-ONLY utility. The class_name is visible project-wide only to
## make test imports cleaner — SceneManagerStub is never registered as an autoload.
##
## GameBusDiagnostics interaction (Story 005):
##   When the stub is active, GameBusDiagnostics (if running in a debug build)
##   remains connected to the detached production GameBus — not to the stub's
##   new GameBus subscriptions. On swap_out, the production SceneManager is
##   re-added to the tree — Godot signal connections persist through
##   remove_child / add_child cycles because the connection is between Callable
##   target objects, not tree paths.
##
## Known limitations:
##   - GdUnit4 runs test functions serially per suite. The static-var cache is
##     safe under serial execution. Parallel test execution within a suite would
##     break this pattern. Document as a project constraint.
##   - A fresh stub subscribes to GameBus signals in its own _ready(). Production
##     GameBus subscribers (other than the stub) that connected at boot do NOT
##     see the stub's internal subscriptions. Tests that need to verify
##     ScenarioRunner <-> SceneManager interaction should use full integration tests.
##   - The stub creates its own Timer child in _ready() (same as production).
##     Tests that need to control Timer behavior should replace _load_timer after
##     swap_in() returns.
class_name SceneManagerStub
extends RefCounted

## Path to the production SceneManager script. The stub is instantiated from this
## same script so FSM state and signal declarations are identical — no duplication.
const SCENE_MANAGER_PATH: String = "res://src/core/scene_manager.gd"

## Cached reference to the production /root/SceneManager, stored on swap_in.
## Persists across test-function boundaries via GDScript static-var semantics.
## Reset to null on successful swap_out.
static var _cached_production: Node = null

## Cached reference to the active stub instance created by swap_in.
## Used by swap_out to distinguish the stub from the production node — prevents
## the paranoia-path swap_out (called before any swap_in) from misidentifying
## the production node as "the stub to remove".
## Reset to null on successful swap_out.
static var _active_stub: Node = null


## Returns the SceneTree root Node, or null if no SceneTree is active.
## Static functions cannot call get_tree() — this helper performs the
## MainLoop -> SceneTree cast and null-guards it so callers do not crash when
## running outside a SceneTree context (e.g., tool scripts, bare unit harnesses).
static func _get_root() -> Node:
	var main_loop: MainLoop = Engine.get_main_loop()
	var tree: SceneTree = main_loop as SceneTree
	if tree == null:
		push_warning(
			"SceneManagerStub: Engine.get_main_loop() is not a SceneTree (got %s) — stub pattern requires a SceneTree main loop."
			% [main_loop]
		)
		return null
	return tree.root


## Replaces /root/SceneManager with a fresh instance of the same script.
## Returns the stub Node for optional direct manipulation
## (e.g., reading stub.state or replacing stub._load_timer for Timer control).
##
## If no node currently sits at /root/SceneManager, the stub is still added;
## _cached_production is left null in that case and swap_out will not attempt
## to restore anything.
##
## The fresh stub runs _ready() on add_child — it creates its own Timer child
## and subscribes to GameBus signals exactly as the production node does.
## This is the isolation property: each test gets a fresh subscriber set and
## a fresh FSM starting in State.IDLE.
##
## Example:
##   var stub: Node = SceneManagerStub.swap_in()
##   assert_bool(stub.state == stub.State.IDLE).is_true()
static func swap_in() -> Node:
	var root: Node = _get_root()
	if root == null:
		return null
	var prod: Node = root.get_node_or_null("SceneManager")
	if prod != null:
		root.remove_child(prod)
		_cached_production = prod
	var stub: Node = (load(SCENE_MANAGER_PATH) as GDScript).new()
	stub.name = "SceneManager"
	root.add_child(stub)
	_active_stub = stub
	return stub


## Restores the production /root/SceneManager and frees the stub.
## Idempotent — safe to call from after_test even if swap_in was never called
## or if a prior swap_out already ran.
##
## Ordering guarantee:
##   1. remove_child on the stub (synchronous — removes from tree immediately)
##   2. free() on the stub (synchronous — object destroyed immediately)
##   3. add_child on production (synchronous — production back in tree)
##   All three steps are synchronous. get_node("SceneManager") returns the
##   production instance immediately after swap_out returns, and the stub is
##   fully gone.
##
## Example:
##   func after_test() -> void:
##       SceneManagerStub.swap_out()
##       _stub = null
static func swap_out() -> void:
	# Guard: if no swap_in was ever called (_active_stub is null), there is
	# nothing to restore. Returning immediately prevents the production node from
	# being misidentified as "the stub to remove" in a paranoia-path call from
	# after_test() when the test never called swap_in().
	if _active_stub == null:
		_cached_production = null
		return

	var root: Node = _get_root()
	if root == null:
		return
	var current: Node = root.get_node_or_null("SceneManager")

	if current == _active_stub:
		# The stub is still in place. Remove it from the tree (synchronous) then
		# free it immediately with free() rather than queue_free(). Deferred
		# deletion leaves the Node alive until end-of-frame, which GdUnit4's
		# orphan detector flags as a leaked node. remove_child() already detaches
		# it from the tree, and no Callable references from other live objects
		# survive swap_out() in normal test usage, so free() is safe here.
		root.remove_child(current)
		current.free()
		if _cached_production != null and is_instance_valid(_cached_production):
			_cached_production.name = "SceneManager"  # belt-and-suspenders
			root.add_child(_cached_production)
		elif _cached_production != null:
			push_warning("SceneManagerStub.swap_out: cached production node was freed externally — cannot restore. /root/SceneManager is now missing.")
		_cached_production = null
		_active_stub = null
		return

	# Case D — a foreign node is at /root/SceneManager (not our stub, not null).
	# Someone else mounted a node with that name after our swap_in. Don't touch
	# the foreign node; surface the anomaly and let caches clear.
	if current != null:
		push_warning("SceneManagerStub.swap_out: found a foreign node named 'SceneManager' at root (not our stub). Cache cleared without restoration — manual cleanup may be required.")

	# Case C — stub already removed externally but production not yet restored.
	if current == null and _cached_production != null:
		if is_instance_valid(_cached_production):
			# Stub was already removed but production wasn't restored — restore it.
			_cached_production.name = "SceneManager"
			root.add_child(_cached_production)
		else:
			push_warning("SceneManagerStub.swap_out: cached production node was freed externally — cannot restore. /root/SceneManager is now missing.")
	_cached_production = null
	_active_stub = null
