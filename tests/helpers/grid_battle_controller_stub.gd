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

# Session-25 test injection: drive can_use_skill + get_active_turn_unit_id from
# stub-owned state instead of the production _units / _active_turn_unit_id fields.
# Default _test_active_turn_unit_id = -1 means "no active turn" → can_use_skill
# returns true only when the unit has a wired skill AND skill_used==false (the
# "any unit can fire pre-battle" permissive default per production semantics).
var _test_active_turn_unit_id: int = -1
var _test_battle_over: bool = false


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


## Session-25 test seam — drives the active turn unit for can_use_skill gating.
## Passing -1 returns to permissive "no active turn" default.
func set_test_active_turn_unit_id(unit_id: int) -> void:
	_test_active_turn_unit_id = unit_id


## Session-25 test seam — drives the _battle_over gate for can_use_skill.
func set_test_battle_over(over: bool) -> void:
	_test_battle_over = over


## Session-25 override — mirrors production can_use_skill semantics but reads
## from stub-owned _test_units / _test_active_turn_unit_id / _test_battle_over
## instead of the production _units / _active_turn_unit_id / _battle_over fields
## (those are never populated in the stub because _ready() is a no-op).
func can_use_skill(unit_id: int) -> bool:
	if _test_battle_over:
		return false
	if not _test_units.has(unit_id):
		return false
	var unit: BattleUnit = _test_units[unit_id]
	if unit.side != 0:
		return false
	if unit.skill_id == &"":
		return false
	if unit.skill_used:
		return false
	if _test_active_turn_unit_id != -1 and unit_id != _test_active_turn_unit_id:
		return false
	return true


## Session-25 override — mirrors production get_active_turn_unit_id but reads
## from stub-owned _test_active_turn_unit_id.
func get_active_turn_unit_id() -> int:
	return _test_active_turn_unit_id


# ─── S91 Phase B step 9 follow-up — UI-GB-15 inventory + UI-GB-17 target ─────


## use_item call recorder + return-value control for HUD integration tests.
## Each entry: {unit_id, slot_idx, target_pos}. `_test_use_item_return` drives
## the success/reject flag the panel sees.
var use_item_calls: Array[Dictionary] = []
var _test_use_item_return: bool = true


func set_test_use_item_return(success: bool) -> void:
	_test_use_item_return = success


## Override use_item — production calls _units which is never populated by the
## stub; recorder + test-controlled return lets HUD-level tests verify the
## click flow without needing a full BattleUnit table.
func use_item(unit_id: int, slot_idx: int, target_pos: Vector2i = Vector2i(-1, -1)) -> bool:
	use_item_calls.append({
		"unit_id": unit_id,
		"slot_idx": slot_idx,
		"target_pos": target_pos,
	})
	return _test_use_item_return


## set_item_target_armed recorder so HUD tests can assert the controller
## gate was armed/disarmed at the expected points.
var set_item_target_armed_calls: Array[bool] = []


func set_item_target_armed(armed: bool) -> void:
	set_item_target_armed_calls.append(armed)
	# Also actually flip the field so any production-side test that checks
	# the gate works against this stub identically.
	_item_target_armed = armed


## begin_item_target_selection / clear_item_target_selection recorders. Each
## entry on begin: {unit_id, item_id, palette}. Counters increment per call.
var begin_item_target_selection_calls: Array[Dictionary] = []
var clear_item_target_selection_count: int = 0


func begin_item_target_selection(unit_id: int, item_id: StringName, palette: StringName) -> void:
	begin_item_target_selection_calls.append({
		"unit_id": unit_id,
		"item_id": item_id,
		"palette": palette,
	})


func clear_item_target_selection() -> void:
	clear_item_target_selection_count += 1


## get_item_target_tiles — stub returns the test-injected set so HUD tests
## can validate the panel rejects out-of-range clicks deterministically.
var _test_item_target_tiles: PackedVector2Array = PackedVector2Array()


func set_test_item_target_tiles(tiles: PackedVector2Array) -> void:
	_test_item_target_tiles = tiles


func get_item_target_tiles(_unit_id: int, _item_id: StringName) -> PackedVector2Array:
	return _test_item_target_tiles
