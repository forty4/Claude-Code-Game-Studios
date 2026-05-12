## GridBattleControllerStub — minimal test stub for GridBattleController DI seam.
##
## Extends GridBattleController (Node) so it satisfies the typed
## `_grid_controller: GridBattleController` field on BattleHUD.
##
## `_ready()` override prevents the production GridBattleController._ready() from:
##   (a) asserting all 8 DI deps non-null (setup() not called in test context)
##   (b) subscribing to 5 GameBus signals (input_action_fired, unit_died,
##       unit_turn_started, unit_turn_ended, round_started) via CONNECT_DEFERRED —
##       avoids unintended signal wiring + orphan warnings from the GdUnit4 test runner.
##
## `_exit_tree()` override is a no-op because this stub never connects any signals
## in _ready(), so no disconnect is needed on tree exit.
##
## See: src/feature/grid_battle/grid_battle_controller.gd, ADR-0014, ADR-0016.
class_name GridBattleControllerStub
extends GridBattleController


# Story-003 test injection: BattleUnit lookup for show_unit_info() hero_id resolution.
# Production GridBattleController.get_battle_unit(unit_id) reads from _units (private).
# This stub overrides with a test-injectable Dictionary populated via set_test_unit().
var _test_units: Dictionary[int, BattleUnit] = {}


func _ready() -> void:
	# No-op: skips production DI asserts + 5 CONNECT_DEFERRED GameBus subscriptions.
	pass


func _exit_tree() -> void:
	# No-op: this stub never subscribed to GameBus in _ready(), so no disconnect needed.
	pass


## Story-003 test seam — populate test BattleUnit lookup table.
## Test fixtures call this in before_test() to inject deterministic unit data.
func set_test_unit(unit_id: int, unit: BattleUnit) -> void:
	_test_units[unit_id] = unit


## Story-003 override of GridBattleController.get_battle_unit().
## Reads from _test_units instead of production _units field.
func get_battle_unit(unit_id: int) -> BattleUnit:
	return _test_units.get(unit_id)
