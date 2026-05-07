# tests/unit/tools_ci/lint_battle_hud_smoke_test.gd
#
# Smoke test for the 7 battle-hud CI lint scripts (story-008 / S10-03;
# epic-terminal lints).
#
# Story coverage:
#   - AC-1 Lint 1 (Pillar 2 hidden_fate_non_subscription) — CRITICAL
#   - AC-2 Lint 2 (signal_emission_outside_ui_domain)
#   - AC-3 Lint 3 (missing_exit_tree_disconnect)
#   - AC-4 Lint 4 (touch_target_size 44pt)
#   - AC-5 Lint 5 (no_hardcoded_strings i18n)
#   - AC-6 Lint 6 (connect_deferred)
#   - AC-7 Lint 7 (balance_entities_battle_hud key-presence)
#
# Each test asserts the lint script exits 0 on current main HEAD source.
# Negative-test recipes (insert violation → expect exit 1 → revert) documented
# inline as comments above each test for manual reproduction.
#
# G-3: no class_name — test files extend GdUnitTestSuite directly.
extends GdUnitTestSuite


const _LINT_DIR: String = "res://tools/ci/"


# Helper: run the given lint shell script via OS.execute, return exit code.
# Captures stdout+stderr into `output` Array for diagnostic messages.
func _run_lint(script_name: String, output: Array) -> int:
	# Resolve absolute path (OS.execute needs absolute or PATH-resolvable command).
	var abs_path: String = ProjectSettings.globalize_path(_LINT_DIR + script_name)
	if not FileAccess.file_exists(abs_path):
		output.append("Lint script not found: %s" % abs_path)
		return -1
	# bash -c invocation: cd to project root then run the lint relative to it
	# (the lint scripts use relative paths like `src/feature/battle_hud/`).
	var project_root: String = ProjectSettings.globalize_path("res://")
	var cmd: String = "cd %s && %s 2>&1" % [_quote(project_root), _quote(abs_path)]
	return OS.execute("bash", ["-c", cmd], output, true)


# Quote a path safely for inclusion in a shell `cd`/exec command.
func _quote(s: String) -> String:
	return "'" + s.replace("'", "'\\''") + "'"


# AC-1: Lint 1 (Pillar 2 hidden_fate_non_subscription) — CRITICAL.
# Negative test recipe: insert `# hidden_fate_condition_progressed` comment into
# `src/feature/battle_hud/battle_hud.gd`; re-run lint; expect exit 1; revert.
func test_lint_1_hidden_fate_non_subscription_passes_on_main() -> void:
	var output: Array = []
	var exit_code: int = _run_lint("lint_battle_hud_hidden_fate_non_subscription.sh", output)
	assert_int(exit_code).override_failure_message(
		"Lint 1 (Pillar 2 hidden_fate) should PASS on main HEAD. Output:\n%s" % "\n".join(output)
	).is_equal(0)


# AC-2: Lint 2 (signal_emission_outside_ui_domain).
# Negative test recipe: insert `GameBus.test_signal.emit()` into battle_hud.gd;
# re-run; expect exit 1; revert.
func test_lint_2_signal_emission_outside_ui_domain_passes_on_main() -> void:
	var output: Array = []
	var exit_code: int = _run_lint("lint_battle_hud_signal_emission_outside_ui_domain.sh", output)
	assert_int(exit_code).override_failure_message(
		"Lint 2 (non-emitter discipline) should PASS on main HEAD. Output:\n%s" % "\n".join(output)
	).is_equal(0)


# AC-3: Lint 3 (missing_exit_tree_disconnect, ≥11).
# Negative test recipe: comment out one `disconnect()` line inside `_exit_tree()`;
# re-run; expect exit 1; revert.
func test_lint_3_missing_exit_tree_disconnect_passes_on_main() -> void:
	var output: Array = []
	var exit_code: int = _run_lint("lint_battle_hud_missing_exit_tree_disconnect.sh", output)
	assert_int(exit_code).override_failure_message(
		"Lint 3 (_exit_tree disconnect ≥ 11) should PASS on main HEAD. Output:\n%s" % "\n".join(output)
	).is_equal(0)


# AC-4: Lint 4 (touch_target_size 44pt).
# Negative test recipe: edit `ui_gb_02_action_menu.tscn` setting MoveButton
# `custom_minimum_size = Vector2(40, 40)`; re-run; expect exit 1; revert.
func test_lint_4_touch_target_size_passes_on_main() -> void:
	var output: Array = []
	var exit_code: int = _run_lint("lint_battle_hud_touch_target_size.sh", output)
	assert_int(exit_code).override_failure_message(
		"Lint 4 (44pt touch targets) should PASS on main HEAD. Output:\n%s" % "\n".join(output)
	).is_equal(0)


# AC-5: Lint 5 (no_hardcoded_strings i18n).
# Negative test recipe: insert `_label.text = "Hardcoded English"` line into
# battle_hud.gd; re-run; expect exit 1; revert.
func test_lint_5_no_hardcoded_strings_passes_on_main() -> void:
	var output: Array = []
	var exit_code: int = _run_lint("lint_battle_hud_no_hardcoded_strings.sh", output)
	assert_int(exit_code).override_failure_message(
		"Lint 5 (i18n no-hardcoded-strings) should PASS on main HEAD. Output:\n%s" % "\n".join(output)
	).is_equal(0)


# AC-6: Lint 6 (connect_deferred — all 11 GameBus/controller subscriptions).
# Negative test recipe: edit one `.connect(...)` call in battle_hud.gd to
# remove `Object.CONNECT_DEFERRED` flag; re-run; expect exit 1; revert.
func test_lint_6_connect_deferred_passes_on_main() -> void:
	var output: Array = []
	var exit_code: int = _run_lint("lint_battle_hud_connect_deferred.sh", output)
	assert_int(exit_code).override_failure_message(
		"Lint 6 (CONNECT_DEFERRED discipline) should PASS on main HEAD. Output:\n%s" % "\n".join(output)
	).is_equal(0)


# AC-7: Lint 7 (BalanceConstants key-presence FORECAST_RENDER_BUDGET_MS).
# Negative test recipe: temporarily delete `FORECAST_RENDER_BUDGET_MS` key from
# `assets/data/balance/balance_entities.json`; re-run; expect exit 1; revert.
func test_lint_7_balance_entities_battle_hud_passes_on_main() -> void:
	var output: Array = []
	var exit_code: int = _run_lint("lint_balance_entities_battle_hud.sh", output)
	assert_int(exit_code).override_failure_message(
		"Lint 7 (balance_entities key-presence) should PASS on main HEAD. Output:\n%s" % "\n".join(output)
	).is_equal(0)


# Structural: assert all 7 lint scripts are present + executable on disk.
# Catches accidental script removal or chmod regression.
func test_all_7_lint_scripts_present_and_executable() -> void:
	var scripts: PackedStringArray = [
		"lint_battle_hud_hidden_fate_non_subscription.sh",
		"lint_battle_hud_signal_emission_outside_ui_domain.sh",
		"lint_battle_hud_missing_exit_tree_disconnect.sh",
		"lint_battle_hud_touch_target_size.sh",
		"lint_battle_hud_no_hardcoded_strings.sh",
		"lint_battle_hud_connect_deferred.sh",
		"lint_balance_entities_battle_hud.sh",
	]
	for script: String in scripts:
		var abs_path: String = ProjectSettings.globalize_path(_LINT_DIR + script)
		assert_bool(FileAccess.file_exists(abs_path)).override_failure_message(
			"Lint script missing on disk: %s" % abs_path
		).is_true()
		# Executability check via `test -x` shell builtin.
		var output: Array = []
		var exit_code: int = OS.execute("bash", ["-c", "test -x " + _quote(abs_path)], output, true)
		assert_int(exit_code).override_failure_message(
			"Lint script not executable (chmod +x missing): %s" % abs_path
		).is_equal(0)
