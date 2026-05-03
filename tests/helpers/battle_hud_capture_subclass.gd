## BattleHUDCaptureSubclass — AC-3 test seam for battle-hud story-002.
##
## Subclasses BattleHUD and overrides `_handle_signal()` to record every
## (signal_name, args) pair in `received`. Tests instantiate this instead of
## BattleHUD directly, emit signals, then assert on `received`.
##
## Usage (per G-4 lambda primitive-capture gotcha — use Array, not bare primitives):
##   var runner: BattleHUDCaptureSubclass = CaptureScript.new()
##   runner.setup(camera, hp, turn, grid, input, map, terrain, role, hero_db)
##   add_child(runner)
##   _grid_controller.unit_died.emit(42)
##   await get_tree().process_frame   # CONNECT_DEFERRED fires after frame
##   assert_int(runner.received.size()).is_equal(1)
##   assert_str(runner.received[0]["name"] as String).is_equal("unit_died")
##
## Array[Dictionary] receives; each element: { "name": StringName, "args": Array }
##
## See: tests/unit/feature/battle_hud/battle_hud_signals_test.gd (AC-3)
##      .claude/rules/godot-4x-gotchas.md G-4 (lambda primitive capture)
class_name BattleHUDCaptureSubclass
extends BattleHUD


## received — ordered log of every _handle_signal() invocation.
## Each entry is {"name": StringName, "args": Array}.
var received: Array[Dictionary] = []


## _handle_signal — overrides BattleHUD test seam to capture instead of no-op.
## Records the (name, args) pair then calls super() so production
## side-effects (mouse_filter toggle etc.) also run.
func _handle_signal(signal_name: StringName, args: Array) -> void:
	received.append({"name": signal_name, "args": args})
	# Call super so _on_input_state_changed side-effects (mouse_filter toggle) run.
	super._handle_signal(signal_name, args)
