extends SceneTree

# Headless test runner entry point.
# Invoked from CI and local via:
#   godot --headless --script tests/gdunit4_runner.gd
#
# Delegates to GdUnit4's CLI runner over `tests/unit/` and `tests/integration/`.
# Prerequisite: GdUnit4 installed at `addons/gdUnit4/` (Asset Library or submodule).

const GDUNIT4_CLI_PATH := "res://addons/gdUnit4/bin/GdUnit4CliRunner.gd"
const TEST_PATHS := [
	"res://tests/unit",
	"res://tests/integration",
]


func _init() -> void:
	if not ResourceLoader.exists(GDUNIT4_CLI_PATH):
		push_error(
			"GdUnit4 not installed at %s. Install via Godot Asset Library "
			"(Editor → AssetLib → search 'gdUnit4') or add as a git submodule. "
			"See tests/README.md first-run checklist."
			% GDUNIT4_CLI_PATH
		)
		quit(2)
		return

	var args := PackedStringArray()
	for path in TEST_PATHS:
		args.append("--add")
		args.append(path)
	args.append("--continue")

	var cli_script: Script = load(GDUNIT4_CLI_PATH)
	if cli_script == null:
		push_error("Failed to load GdUnit4 CLI runner at %s" % GDUNIT4_CLI_PATH)
		quit(2)
		return

	var cli_instance: Node = cli_script.new()
	root.add_child(cli_instance)
	if cli_instance.has_method("run_from_args"):
		var exit_code: int = cli_instance.run_from_args(args)
		quit(exit_code)
		return

	push_error(
		"GdUnit4 CLI runner does not expose expected entry point. "
		"Verify addons/gdUnit4 version is compatible with Godot 4.6."
	)
	quit(2)
