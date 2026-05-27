## FakeBattleSceneWithSnapshot — minimal Node helper for ScenarioRunner
## _make_save_context test. Exposes get_per_unit_strategy_snapshot() returning
## test-injectable fixture data so the SaveContext populate path can be
## exercised without a full BattleScene boot.
##
## NOT a BattleScene subclass — avoids the production BattleScene's heavy
## _ready setup. ScenarioRunner._collect_active_battle_strategy_snapshot uses
## has_method() to detect snapshot capability, so a duck-typed Node with the
## method suffices.
class_name FakeBattleSceneWithSnapshot
extends Node


## Test fixture — populate before reading. Mirrors the
## BattleScene.get_per_unit_strategy_snapshot return shape:
##   {"inventory": {int -> Array[StringName]}, "pending_buff": {int -> Dictionary}}
var fixture_inventory_snapshot: Dictionary = {}
var fixture_pending_buff_snapshot: Dictionary = {}


func get_per_unit_strategy_snapshot() -> Dictionary:
	return {
		"inventory": fixture_inventory_snapshot,
		"pending_buff": fixture_pending_buff_snapshot,
	}
