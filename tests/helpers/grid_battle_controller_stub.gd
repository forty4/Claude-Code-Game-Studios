## GridBattleControllerStub — minimal test stub for GridBattleController DI seam.
##
## Extends GridBattleController (Node) so it satisfies the typed
## `_grid_controller: GridBattleController` field on BattleHUD.
##
## `_ready()` override prevents the production GridBattleController._ready() from:
##   (a) asserting all 8 DI deps non-null (setup() not called in test context)
##   (b) subscribing to 4 GameBus signals (input_action_fired, unit_died,
##       unit_turn_started, round_started) via CONNECT_DEFERRED — avoids
##       unintended signal wiring + orphan warnings from the GdUnit4 test runner.
##
## `_exit_tree()` override is a no-op because this stub never connects any signals
## in _ready(), so no disconnect is needed on tree exit.
##
## See: src/feature/grid_battle/grid_battle_controller.gd, ADR-0014, ADR-0016.
class_name GridBattleControllerStub
extends GridBattleController


func _ready() -> void:
	# No-op: skips production DI asserts + 4 CONNECT_DEFERRED GameBus subscriptions.
	pass


func _exit_tree() -> void:
	# No-op: this stub never subscribed to GameBus in _ready(), so no disconnect needed.
	pass
