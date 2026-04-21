## GameBusStub — test-infrastructure helper that swaps /root/GameBus with a
## fresh instance for test isolation, then restores the production instance.
##
## Usage pattern:
##   extends GdUnitTestSuite
##   var _stub: Node
##
##   func before_test() -> void:
##       _stub = GameBusStub.swap_in()
##
##   func after_test() -> void:
##       GameBusStub.swap_out()
##       _stub = null
##
##   func test_my_scenario() -> void:
##       # use the stub like the real GameBus — same signals, same signatures
##       _stub.battle_outcome_resolved.emit(BattleOutcome.new())
##       # assertions...
##
## ADR reference: ADR-0001 §Implementation Guidelines §9, §Validation Criteria V-6.
## Story:         Story 006 — GameBus stub pattern for GdUnit4.
##
## PRODUCTION CODE MUST NOT CALL swap_in / swap_out.
## This is a TEST-ONLY utility. The class_name is visible project-wide only to
## make test imports cleaner — GameBusStub is never registered as an autoload.
##
## GameBusDiagnostics interaction (Story 005):
##   When the stub is active, GameBusDiagnostics (if running in a debug build)
##   remains connected to the detached production GameBus. Stub emits do NOT
##   reach the diagnostic. On swap_out, the production GameBus is re-added to
##   the tree and the diagnostic automatically re-engages — Godot signal
##   connections persist through remove_child / add_child cycles because the
##   connection is between Callable target objects, not tree paths.
##   Tests that verify diagnostic soft-cap behavior must use the production
##   GameBus directly, not the stub.
##
## Known limitations:
##   - GdUnit4 runs test functions serially per suite. The static-var cache is
##     safe under serial execution. Parallel test execution within a suite would
##     break this pattern. Document as a project constraint.
##   - A fresh stub has zero connected subscribers. Production subscribers
##     (SceneManager, SaveManager) connected at boot do not re-bind to the stub.
##     For tests that need to verify SceneManager/SaveManager interaction with
##     GameBus, use full integration tests rather than this stub.
class_name GameBusStub
extends RefCounted

## Path to the production GameBus script. The stub is instantiated from this
## same script so signal declarations are identical — no duplication.
const GAME_BUS_PATH: String = "res://src/core/game_bus.gd"

## Cached reference to the production /root/GameBus, stored on swap_in.
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
## MainLoop → SceneTree cast and null-guards it so callers do not crash when
## running outside a SceneTree context (e.g., tool scripts, bare unit harnesses).
static func _get_root() -> Node:
	var main_loop: MainLoop = Engine.get_main_loop()
	var tree: SceneTree = main_loop as SceneTree
	if tree == null:
		push_warning(
			"GameBusStub: Engine.get_main_loop() is not a SceneTree (got %s) — stub pattern requires a SceneTree main loop."
			% [main_loop]
		)
		return null
	return tree.root


## Replaces /root/GameBus with a fresh instance of the same script.
## Returns the stub Node for optional direct manipulation
## (e.g., connecting a test-only observer to one of its signals).
##
## If no node currently sits at /root/GameBus, the stub is still added;
## _cached_production is left null in that case and swap_out will not attempt
## to restore anything.
##
## Example:
##   var stub: Node = GameBusStub.swap_in()
##   stub.chapter_started.connect(my_handler)
static func swap_in() -> Node:
	var root: Node = _get_root()
	if root == null:
		return null
	var prod: Node = root.get_node_or_null("GameBus")
	if prod != null:
		root.remove_child(prod)
		_cached_production = prod
	var stub: Node = (load(GAME_BUS_PATH) as GDScript).new()
	stub.name = "GameBus"
	root.add_child(stub)
	_active_stub = stub
	return stub


## Restores the production /root/GameBus and frees the stub.
## Idempotent — safe to call from after_test even if swap_in was never called
## or if a prior swap_out already ran.
##
## Ordering guarantee:
##   1. remove_child on the stub (synchronous — removes from tree immediately)
##   2. free() on the stub (synchronous — object destroyed immediately)
##   3. add_child on production (synchronous — production back in tree)
##   All three steps are synchronous. get_node("GameBus") returns the production
##   instance immediately after swap_out returns, and the stub is fully gone.
##
## Example:
##   func after_test() -> void:
##       GameBusStub.swap_out()
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
	var current: Node = root.get_node_or_null("GameBus")

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
			_cached_production.name = "GameBus"  # belt-and-suspenders
			root.add_child(_cached_production)
		elif _cached_production != null:
			push_warning("GameBusStub.swap_out: cached production node was freed externally — cannot restore. /root/GameBus is now missing.")
		_cached_production = null
		_active_stub = null
		return

	# Case D — a foreign node is at /root/GameBus (not our stub, not null).
	# Someone else mounted a node with that name after our swap_in. Don't touch
	# the foreign node; surface the anomaly and let caches clear.
	if current != null:
		push_warning("GameBusStub.swap_out: found a foreign node named 'GameBus' at root (not our stub). Cache cleared without restoration — manual cleanup may be required.")

	# Case C — stub already removed externally but production not yet restored.
	if current == null and _cached_production != null:
		if is_instance_valid(_cached_production):
			# Stub was already removed but production wasn't restored — restore it.
			_cached_production.name = "GameBus"
			root.add_child(_cached_production)
		else:
			push_warning("GameBusStub.swap_out: cached production node was freed externally — cannot restore. /root/GameBus is now missing.")
	_cached_production = null
	_active_stub = null
