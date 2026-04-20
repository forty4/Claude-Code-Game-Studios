extends GdUnitTestSuite

## game_bus_declaration_test.gd
## Unit tests for Story 002: GameBus autoload declaration + registration.
## Covers AC-1 through AC-6 (AC-7 collapses into AC-4 lint check).

const GAME_BUS_PATH: String = "res://src/core/game_bus.gd"
const PROJECT_GODOT_PATH: String = "res://project.godot"

## The 27 signal names declared in game_bus.gd — authoritative list per ADR-0001.
const EXPECTED_SIGNALS: Array[String] = [
	"chapter_started",
	"battle_prepare_requested",
	"battle_launch_requested",
	"chapter_completed",
	"scenario_complete",
	"scenario_beat_retried",
	"battle_outcome_resolved",
	"round_started",
	"unit_turn_started",
	"unit_turn_ended",
	"unit_died",
	"destiny_branch_chosen",
	"destiny_state_flag_set",
	"destiny_state_echo_added",
	"beat_visual_cue_fired",
	"beat_audio_cue_fired",
	"beat_sequence_complete",
	"input_action_fired",
	"input_state_changed",
	"input_mode_changed",
	"ui_input_block_requested",
	"ui_input_unblock_requested",
	"scene_transition_failed",
	"save_checkpoint_requested",
	"save_persisted",
	"save_load_failed",
	"tile_destroyed",
]

## Expected Resource class_name for signals that carry a Resource payload.
## Keys: signal name. Values: array of expected class_name strings per arg position.
## Empty string at a position means a primitive arg — no class_name check there.
## Story 003 (signal_contract_test) will expand and formalize this map.
const EXPECTED_RESOURCE_ARG_CLASSES: Dictionary = {
	"battle_prepare_requested":  ["BattlePayload"],
	"battle_launch_requested":   ["BattlePayload"],
	"chapter_completed":         ["ChapterResult"],
	"battle_outcome_resolved":   ["BattleOutcome"],
	"input_action_fired":        ["", "InputContext"],  # first arg is String, second is InputContext
	"scenario_beat_retried":     ["EchoMark"],
	"destiny_branch_chosen":     ["DestinyBranchChoice"],
	"destiny_state_echo_added":  ["EchoMark"],
	"beat_visual_cue_fired":     ["BeatCue"],
	"beat_audio_cue_fired":      ["BeatCue"],
	"save_checkpoint_requested": ["SaveContext"],
}


## Returns all signal names on a bare Node — used as the baseline to filter out inherited
## signals when counting user-declared signals. Dynamic so Godot version changes (editor
## signals, platform-specific additions) never require a manual constant update.
func _get_node_inherited_signal_names() -> Array[String]:
	var baseline: Node = auto_free(Node.new())
	var names: Array[String] = []
	for sig: Dictionary in baseline.get_signal_list():
		names.append(sig["name"])
	return names


## AC-1: game_bus.gd extends Node; does NOT declare a class_name.
func test_gamebus_extends_node_and_has_no_class_name() -> void:
	# Arrange
	var script: GDScript = load(GAME_BUS_PATH)
	assert_bool(script != null).is_true()

	# Act — instantiate via script; instance IS-A Node confirms extends Node
	var instance: Node = auto_free(script.new())

	# Assert — extends Node
	assert_bool(instance is Node).is_true()

	# Assert — no class_name: scan raw source for class_name declaration
	var file := FileAccess.open(GAME_BUS_PATH, FileAccess.READ)
	assert_bool(file != null).is_true()
	if file == null:
		return
	var content: String = file.get_as_text()
	file.close()

	var class_name_regex := RegEx.new()
	class_name_regex.compile("^class_name\\s")
	var lines := content.split("\n")
	for line: String in lines:
		assert_bool(class_name_regex.search(line) == null).is_true()


## AC-2 + AC-3: game_bus.gd declares exactly 27 user signals.
func test_gamebus_declares_exactly_27_signals() -> void:
	# Arrange
	var script: GDScript = load(GAME_BUS_PATH)
	var instance: Node = auto_free(script.new())
	var inherited: Array[String] = _get_node_inherited_signal_names()

	# Act — collect all signals, filter out Node-inherited ones
	var all_signals: Array[Dictionary] = instance.get_signal_list()
	var user_signals: Array[Dictionary] = []
	for sig: Dictionary in all_signals:
		if not (sig["name"] as String) in inherited:
			user_signals.append(sig)

	# Assert — exactly 27
	assert_int(user_signals.size()).is_equal(27)


## AC-3: All 27 declared signals match the authoritative name list from ADR-0001.
func test_gamebus_signal_names_match_spec() -> void:
	# Arrange
	var script: GDScript = load(GAME_BUS_PATH)
	var instance: Node = auto_free(script.new())
	var inherited: Array[String] = _get_node_inherited_signal_names()

	# Act
	var all_signals: Array[Dictionary] = instance.get_signal_list()
	var user_signal_names: Array[String] = []
	for sig: Dictionary in all_signals:
		var name: String = sig["name"]
		if not name in inherited:
			user_signal_names.append(name)

	# Assert — every expected signal is present
	for expected: String in EXPECTED_SIGNALS:
		assert_bool(expected in user_signal_names).is_true()


## AC-3 (typing): No declared signal has a Variant / untyped arg.
## TYPE_NIL == 0 in Godot's TYPE_* enum — means Variant / untyped.
func test_gamebus_signal_signatures_have_no_untyped_args() -> void:
	# Arrange
	var script: GDScript = load(GAME_BUS_PATH)
	var instance: Node = auto_free(script.new())
	var inherited: Array[String] = _get_node_inherited_signal_names()

	# Act + Assert
	var all_signals: Array[Dictionary] = instance.get_signal_list()
	for sig: Dictionary in all_signals:
		var sig_name: String = sig["name"]
		if sig_name in inherited:
			continue
		var args: Array[Dictionary] = []
		for a: Dictionary in (sig["args"] as Array):
			args.append(a)
		for arg: Dictionary in args:
			# TYPE_NIL (0) == Variant / untyped — forbidden per ADR-0001 §3
			var arg_type: int = arg["type"]
			assert_bool(arg_type != TYPE_NIL).is_true()


## AC-3 Edge: Resource-typed signal args carry the exact expected class_name.
## Spot-checks all 11 signals with Resource payloads. Story 003 will expand.
func test_gamebus_resource_signal_args_have_exact_class_name() -> void:
	# Arrange
	var script: GDScript = load(GAME_BUS_PATH)
	var instance: Node = auto_free(script.new())
	var all_signals: Array[Dictionary] = instance.get_signal_list()

	# Act + Assert — iterate only signals present in the lookup table
	for sig: Dictionary in all_signals:
		var sig_name: String = sig["name"]
		if not sig_name in EXPECTED_RESOURCE_ARG_CLASSES:
			continue
		var expected_classes: Array = EXPECTED_RESOURCE_ARG_CLASSES[sig_name]
		var args: Array[Dictionary] = []
		for a: Dictionary in (sig["args"] as Array):
			args.append(a)
		assert_int(args.size()).is_equal(expected_classes.size())
		for i: int in args.size():
			var expected: String = expected_classes[i]
			if expected == "":
				continue  # primitive arg — no class_name check
			assert_str(args[i]["class_name"] as String).is_equal(expected)


## AC-4 / AC-7: game_bus.gd contains ONLY extends, docstring, banners, signals, blanks.
## No var, func, const, class, @onready, or @export lines permitted.
func test_gamebus_script_has_no_var_func_const_class_declarations() -> void:
	# Arrange
	var file := FileAccess.open(GAME_BUS_PATH, FileAccess.READ)
	assert_bool(file != null).is_true()
	if file == null:
		return
	var content: String = file.get_as_text()
	file.close()

	# Strip comment lines (both # and ##) — prose in comments must not trigger
	var lines := content.split("\n")
	var forbidden_regex := RegEx.new()
	forbidden_regex.compile("^(var|func|const|class|@onready|@export)\\s")

	for line: String in lines:
		var stripped: String = line.strip_edges()
		if stripped.begins_with("#"):
			continue
		assert_bool(forbidden_regex.search(line) == null).is_true()


## AC-5: project.godot [autoload] section has the order-sensitive comment and
##        GameBus as the first non-comment entry.
func test_project_godot_has_gamebus_as_first_autoload() -> void:
	# Arrange
	var file := FileAccess.open(PROJECT_GODOT_PATH, FileAccess.READ)
	assert_bool(file != null).is_true()
	if file == null:
		return
	var content: String = file.get_as_text()
	file.close()

	# Locate [autoload] section
	var autoload_start: int = content.find("[autoload]")
	assert_bool(autoload_start != -1).is_true()

	# Extract lines from [autoload] to next section or end
	var after_autoload: String = content.substr(autoload_start)
	var next_section: int = after_autoload.find("\n[", 1)
	var autoload_block: String = after_autoload if next_section == -1 else after_autoload.substr(0, next_section)

	var lines := autoload_block.split("\n")

	# Assert — order-sensitive comment is present and GameBus is first entry
	var has_order_comment: bool = false
	var first_entry_line: String = ""
	for line: String in lines:
		var stripped: String = line.strip_edges()
		if stripped.begins_with("; ORDER-SENSITIVE:"):
			has_order_comment = true
		if stripped.length() > 0 and not stripped.begins_with(";") and not stripped.begins_with("["):
			if first_entry_line == "":
				first_entry_line = stripped

	assert_bool(has_order_comment).is_true()
	assert_str(first_entry_line).is_equal('GameBus="*res://src/core/game_bus.gd"')


## AC-6: game_bus.gd contains exactly 10 domain banner comments.
func test_gamebus_file_has_exactly_10_domain_banners() -> void:
	# Arrange
	var file := FileAccess.open(GAME_BUS_PATH, FileAccess.READ)
	assert_bool(file != null).is_true()
	if file == null:
		return
	var content: String = file.get_as_text()
	file.close()

	# Act — count lines matching the banner pattern
	var banner_regex := RegEx.new()
	banner_regex.compile("^# ═══ DOMAIN:")
	var lines := content.split("\n")
	var banner_count: int = 0
	for line: String in lines:
		if banner_regex.search(line) != null:
			banner_count += 1

	# Assert
	assert_int(banner_count).is_equal(10)
