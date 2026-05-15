## HPStatusControllerStub — minimal test stub for HPStatusController DI seam.
##
## Extends HPStatusController (Node) so it satisfies the typed
## `_hp_controller: HPStatusController` field on GridBattleController.
##
## `_ready()` override prevents the production HPStatusController._ready() from
## subscribing to GameBus.unit_turn_started during tests — avoids unintended
## signal wiring + orphan warnings from the GdUnit4 test runner.
##
## NOTE: The production HPStatusController emits `unit_died` via GameBus
## (`GameBus.unit_died.emit(unit_id)` per src/core/hp_status_controller.gd:113).
## There is NO instance signal `unit_died` on HPStatusController. Therefore this
## stub does NOT redeclare it locally — GridBattleController subscribes to
## `GameBus.unit_died`, not `_hp_controller.unit_died`. Verified at story-001
## implementation 2026-05-02 (ADR-0014 §3 sketch drift; ADR amended same-patch).
##
## apply_damage: 4-param signature per ADR-0014 Implementation Notes (line 504).
## is_alive: canonical query per ADR-0014 Implementation Notes (line 505).
class_name HPStatusControllerStub
extends HPStatusController


# Story-003 test injection — backend query overrides for BattleHUD.show_unit_info().
# Production HPStatusController reads from per-unit UnitHPState; this stub uses
# flat per-unit_id Dictionaries for deterministic test injection.
var _test_current_hp: Dictionary[int, int] = {}
var _test_max_hp: Dictionary[int, int] = {}
var _test_status_effects: Dictionary[int, Array] = {}


func _ready() -> void:
	# No-op: prevents production GameBus.unit_turn_started subscription during tests.
	pass


func apply_damage(_unit_id: int, _resolved_damage: int, _attack_type: int, _source_flags: Array) -> void:
	pass


func is_alive(unit_id: int) -> bool:
	# Session-15 commit 4: per-unit override for tests that need a dead unit
	# (e.g., result-screen star-rating tests). Default still true if not set.
	return _test_alive.get(unit_id, true)


## Session-15 commit 4: test seam — populate per-unit alive override.
## get_battle_stats() relies on is_alive() to compute surviving_player_count.
func set_alive_for_test(unit_id: int, alive: bool) -> void:
	_test_alive[unit_id] = alive


var _test_alive: Dictionary[int, bool] = {}


## Story-003 test seam — populate per-unit current HP for show_unit_info().
func set_test_current_hp(unit_id: int, hp: int) -> void:
	_test_current_hp[unit_id] = hp


## Story-003 test seam — populate per-unit max HP for show_unit_info() HP bar.
func set_test_max_hp(unit_id: int, max_hp: int) -> void:
	_test_max_hp[unit_id] = max_hp


## Story-003 test seam — populate per-unit Array[StatusEffect] for show_unit_info().
## Pass [] to clear (e.g., simulating DEFEND_STANCE expiry between turns).
func set_test_status_effects(unit_id: int, effects: Array) -> void:
	_test_status_effects[unit_id] = effects


## Story-003 override of HPStatusController.get_current_hp().
func get_current_hp(unit_id: int) -> int:
	return _test_current_hp.get(unit_id, 0)


## Story-003 override of HPStatusController.get_max_hp().
func get_max_hp(unit_id: int) -> int:
	return _test_max_hp.get(unit_id, 0)


## Story-003 override of HPStatusController.get_status_effects().
## Returns shallow copy to mirror production R-5 contract.
func get_status_effects(unit_id: int) -> Array:
	var effects: Array = _test_status_effects.get(unit_id, [])
	return effects.duplicate()
