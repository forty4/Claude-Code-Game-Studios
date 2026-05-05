## ScenarioRunnerTestSeam — test helper for ScenarioRunner state enum access.
##
## Per IN-1 (G-3 autoload rule): scenario_runner.gd has NO class_name, so tests
## that need to reference `State.LOADING` etc. without booting the full autoload
## stack must access the enum through the script's constant map.
##
## Usage:
##   const State = preload("res://tests/helpers/scenario_runner_test_seam.gd").State
##
## OR (preferred for isolated unit tests):
##   var sm = ScenarioRunnerTestSeam.get_state_enum()
##   var loading: int = sm.LOADING as int
class_name ScenarioRunnerTestSeam
extends RefCounted


const SCENARIO_RUNNER_PATH: String = "res://src/core/scenario_runner.gd"


## Returns the State enum constants Dictionary {name: int}. Use for state
## ordinal comparison in tests that load the script via load() instead of
## accessing the autoload at /root/ScenarioRunner.
static func get_state_enum() -> Dictionary:
	var script: GDScript = load(SCENARIO_RUNNER_PATH)
	var consts: Dictionary = script.get_script_constant_map()
	# Godot 4.6 returns enum constants as a nested Dictionary at the enum name key.
	if consts.has("State"):
		return consts["State"] as Dictionary
	return {}


## Returns the SaveCheckpoint enum constants Dictionary.
static func get_save_checkpoint_enum() -> Dictionary:
	var script: GDScript = load(SCENARIO_RUNNER_PATH)
	var consts: Dictionary = script.get_script_constant_map()
	if consts.has("SaveCheckpoint"):
		return consts["SaveCheckpoint"] as Dictionary
	return {}


## Convenience: load a fresh ScenarioRunner script instance for unit tests.
## Bypasses the /root/ScenarioRunner autoload to allow per-test isolation.
static func make_isolated_runner() -> Node:
	var script: GDScript = load(SCENARIO_RUNNER_PATH)
	return script.new() as Node
