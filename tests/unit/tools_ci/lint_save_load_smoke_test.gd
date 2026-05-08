# tests/unit/tools_ci/lint_save_load_smoke_test.gd
#
# Smoke tests for the 3 save-load CI lint scripts (story-003 / S12-03;
# epic-terminal lints for AC-LINT-* acceptance criteria).
#
# Story coverage:
#   - AC-LINT-CACHE_MODE_IGNORE: lint_save_resource_loader_cache_mode_ignore.sh Exit 0 on main HEAD
#   - AC-LINT-MIGRATION_PURITY: lint_save_migration_callable_purity.sh Exit 0 on main HEAD
#   - AC-LINT-EXPORT_DISCIPLINE: lint_save_context_export_discipline.sh Exit 0 on main HEAD
#
# Each test asserts the lint script exits 0 on current main HEAD source.
# Negative-test recipes (insert violation → expect exit 1 → revert) documented
# inline as comments above each test for manual reproduction.
#
# G-3: no class_name — test files extend GdUnitTestSuite directly.
extends GdUnitTestSuite


const LINT_DIR: String = "res://tools/ci/"


# Helper: run the given lint shell script via OS.execute, return exit code.
# Captures stdout+stderr into `output` Array for diagnostic messages on failure.
func _run_lint(script_name: String, output: Array) -> int:
	# Resolve absolute path (OS.execute needs absolute or PATH-resolvable command).
	var abs_path: String = ProjectSettings.globalize_path(LINT_DIR + script_name)
	if not FileAccess.file_exists(abs_path):
		output.append("Lint script not found: %s" % abs_path)
		return -1
	# bash -c invocation: cd to project root then run the lint relative to it
	# (the lint scripts use relative paths like `src/core/save_manager.gd`).
	var project_root: String = ProjectSettings.globalize_path("res://")
	var cmd: String = "cd %s && %s 2>&1" % [_quote(project_root), _quote(abs_path)]
	return OS.execute("bash", ["-c", cmd], output, true)


# Quote a path safely for inclusion in a shell `cd`/exec command.
func _quote(s: String) -> String:
	return "'" + s.replace("'", "'\\''") + "'"


# AC-LINT-CACHE_MODE_IGNORE: lint_save_resource_loader_cache_mode_ignore.sh exits 0 on main HEAD.
#
# Negative-test recipe (manual verification):
#   1. Edit src/core/save_manager.gd — change one ResourceLoader.load(...) call to
#      use ResourceLoader.CACHE_MODE_REUSE instead of CACHE_MODE_IGNORE.
#      Example: change `ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)`
#      to       `ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)`.
#   2. Run: bash tools/ci/lint_save_resource_loader_cache_mode_ignore.sh
#   3. Assert exit code is 1 and the violating line number is reported.
#   4. Revert the edit (git checkout src/core/save_manager.gd) and confirm exit 0.
func test_lint_save_resource_loader_cache_mode_ignore_passes_on_main() -> void:
	var output: Array = []
	var exit_code: int = _run_lint("lint_save_resource_loader_cache_mode_ignore.sh", output)
	assert_int(exit_code).override_failure_message(
		("AC-LINT-CACHE_MODE_IGNORE: lint should PASS (Exit 0) on main HEAD. "
		+ "Output:\n%s") % "\n".join(output)
	).is_equal(0)


# AC-LINT-MIGRATION_PURITY: lint_save_migration_callable_purity.sh exits 0 on main HEAD.
# NOTE: _migrations is currently empty `{}` (MVP state) — lint passes with "0 migrations".
#
# Negative-test recipe (manual verification):
#   1. Edit src/core/save_migration_registry.gd — add a non-pure lambda to _migrations:
#      static var _migrations: Dictionary = {
#        1: func(ctx: SaveContext) -> SaveContext:
#          var bad = SaveManager  # captured autoload reference — FORBIDDEN
#          return ctx,
#      }
#   2. Run: bash tools/ci/lint_save_migration_callable_purity.sh
#   3. Assert exit code is 1 and "SaveManager autoload reference" violation is reported.
#   4. Revert the edit (git checkout src/core/save_migration_registry.gd) and confirm exit 0.
func test_lint_save_migration_callable_purity_passes_on_main() -> void:
	var output: Array = []
	var exit_code: int = _run_lint("lint_save_migration_callable_purity.sh", output)
	assert_int(exit_code).override_failure_message(
		("AC-LINT-MIGRATION_PURITY: lint should PASS (Exit 0) on main HEAD. "
		+ "Output:\n%s") % "\n".join(output)
	).is_equal(0)


# AC-LINT-EXPORT_DISCIPLINE: lint_save_context_export_discipline.sh exits 0 on main HEAD.
# NOTE: all SaveContext + EchoMark fields are @export-annotated per ADR-0003 §Schema Stability.
#
# Negative-test recipe (manual verification):
#   1. Edit src/core/payloads/save_context.gd — remove @export from one var declaration:
#      Change:
#        @export var schema_version: int = 1
#      To:
#        var schema_version: int = 1
#   2. Run: bash tools/ci/lint_save_context_export_discipline.sh
#   3. Assert exit code is 1 and "field `schema_version` has no @export annotation" is reported.
#   4. Revert the edit (git checkout src/core/payloads/save_context.gd) and confirm exit 0.
func test_lint_save_context_export_discipline_passes_on_main() -> void:
	var output: Array = []
	var exit_code: int = _run_lint("lint_save_context_export_discipline.sh", output)
	assert_int(exit_code).override_failure_message(
		("AC-LINT-EXPORT_DISCIPLINE: lint should PASS (Exit 0) on main HEAD. "
		+ "Output:\n%s") % "\n".join(output)
	).is_equal(0)


# Structural: assert all 3 save-load lint scripts are present + executable on disk.
# Catches accidental script removal or chmod regression.
func test_all_3_save_load_lint_scripts_present_and_executable() -> void:
	var scripts: PackedStringArray = [
		"lint_save_resource_loader_cache_mode_ignore.sh",
		"lint_save_migration_callable_purity.sh",
		"lint_save_context_export_discipline.sh",
	]
	for script: String in scripts:
		var abs_path: String = ProjectSettings.globalize_path(LINT_DIR + script)
		assert_bool(FileAccess.file_exists(abs_path)).override_failure_message(
			"Save-load lint script missing on disk: %s" % abs_path
		).is_true()
		# Executability check via `test -x` shell builtin.
		var output: Array = []
		var exit_code: int = OS.execute("bash", ["-c", "test -x " + _quote(abs_path)], output, true)
		assert_int(exit_code).override_failure_message(
			"Save-load lint script not executable (chmod +x missing): %s" % abs_path
		).is_equal(0)
