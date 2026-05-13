## help_overlay_test.gd
##
## Smoke + signal-contract test for HelpOverlay (H-key triggered reference
## card on the BattleScene HUD layer). Pure UI — no GameBus emissions, no
## tree.paused side effects (distinct from PauseMenu). The overlay's behavior
## under live input is exercised in windowed runs; here we verify:
##   - the script registers the `close_requested` signal
##   - new() + add_child() succeeds without crashing
##   - show_help() flips visible true and arms the H-latch
##   - _on_close_pressed() emits close_requested + hides the overlay
##
## Pattern mirrors story_beat_screen_test.gd (same UI-overlay smoke shape).
extends GdUnitTestSuite


var _overlay: HelpOverlay = null


func before_test() -> void:
	_overlay = HelpOverlay.new()
	get_tree().root.add_child(_overlay)
	await get_tree().process_frame  # let _ready() build the widget tree


func after_test() -> void:
	if is_instance_valid(_overlay):
		get_tree().root.remove_child(_overlay)
		# free() not queue_free() per G-6 — no external Callable references on
		# the overlay subtree, so immediate free avoids the orphan window.
		_overlay.free()
	_overlay = null


func test_overlay_instantiates_without_crashing() -> void:
	# The strongest assertion possible without simulating input — just that
	# new() + add_child() + _ready() ran to completion. Smoke gate against
	# parse-error regressions on the help_overlay.gd file.
	assert_object(_overlay).is_not_null()
	assert_bool(_overlay.is_inside_tree()).is_true()


func test_show_help_makes_overlay_visible() -> void:
	_overlay.visible = false
	_overlay.show_help()
	assert_bool(_overlay.visible).is_true()


func test_close_pressed_emits_signal_and_hides_overlay() -> void:
	_overlay.show_help()
	# Capture via Array per G-4 — lambdas can't reassign captured primitives.
	var captures: Array = []
	_overlay.close_requested.connect(func() -> void:
		captures.append(true))
	_overlay._on_close_pressed()
	await get_tree().process_frame
	assert_int(captures.size()).override_failure_message(
		"close_requested must emit exactly once when _on_close_pressed runs"
	).is_equal(1)
	assert_bool(_overlay.visible).is_false()


func test_close_requested_signal_is_declared() -> void:
	# Defensive: verify the signal name actually exists on the script so the
	# BattleScene.connect() call site won't silently fail at runtime.
	var found: bool = false
	for sig: Dictionary in _overlay.get_signal_list():
		if (sig["name"] as String) == "close_requested":
			found = true
			break
	assert_bool(found).override_failure_message(
		"HelpOverlay must declare `signal close_requested` for BattleScene.connect"
	).is_true()
