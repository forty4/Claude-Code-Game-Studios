## test_helpers.gd — shared static helpers for tests/unit/core/*.
##
## Extracted to avoid duplication across signal_contract_test.gd,
## game_bus_diagnostics_test.gd, and game_bus_stub_self_test.gd. When
## Godot adds new inherited Node signals in a future version, only
## get_user_signals needs updating — and this file is the only place.
##
## Usage:
##   for sig: Dictionary in TestHelpers.get_user_signals(node):
##       ...
##
## NOTE: game_bus_declaration_test.gd uses a different helper shape
## (_get_node_inherited_signal_names, returning inherited names rather
## than user signals) and is intentionally NOT updated to use this module.
class_name TestHelpers
extends RefCounted


## Returns only user-declared signals on a Node, filtering inherited Node signals.
## Uses a dynamic baseline (bare Node.new()) so Godot version upgrades that add
## new built-in Node signals never require a manual update here.
## Matches the pattern from game_bus_declaration_test.gd for consistency.
static func get_user_signals(node: Node) -> Array[Dictionary]:
	var baseline: Node = Node.new()
	var inherited: Array[String] = []
	for sig: Dictionary in baseline.get_signal_list():
		inherited.append(sig["name"] as String)
	baseline.free()
	var result: Array[Dictionary] = []
	for sig: Dictionary in node.get_signal_list():
		if not (sig["name"] as String) in inherited:
			result.append(sig)
	return result
