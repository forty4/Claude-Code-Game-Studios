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


func _ready() -> void:
	# No-op: prevents production GameBus.unit_turn_started subscription during tests.
	pass


func apply_damage(_unit_id: int, _resolved_damage: int, _attack_type: int, _source_flags: Array) -> void:
	pass


func is_alive(_unit_id: int) -> bool:
	return true
