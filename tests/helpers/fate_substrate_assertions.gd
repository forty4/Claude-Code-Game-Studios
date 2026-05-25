## FateSubstrateAssertions — reusable 3-layer grep sentinel for fate_data fields.
##
## Codified at S85 from 4 stable instances of the substrate-check pattern in
## chapter ★ sentinel tests (ch08 / ch10 / ch13 / ch16 sentinel files, all
## authored S82-S84). Each invocation greps grid_battle_controller.gd source
## for the 3 layers that make a fate_data field "live":
##
##   Layer 1 — declaration: `var _fate_<field>` (or any `var <var_name>` form)
##   Layer 2 — increment:   `<var_name> += 1`
##   Layer 3 — fate_data emit: `"<field>": <var_name>`
##
## If any layer is missing the source has drifted from the substrate contract
## and the chapter's ★ trigger is silently broken — the assertion fires with
## a specific layer-attribution message so the reader knows which layer drifted.
##
## Usage (replaces ~25 lines of inline grep test in each sentinel file):
##
##   func test_ch08_win_within_turns_substrate_present_in_controller() -> void:
##       FateSubstrateAssertions.assert_substrate_present(
##           self, "win_within_turns", "_fate_win_within_turns", "ch08"
##       )
##
## The `chapter_label` arg appears in failure messages for cross-chapter triage
## (a single grep miss could fail multiple chapters' sentinels at once).
class_name FateSubstrateAssertions
extends RefCounted


const GRID_CONTROLLER_PATH: String = "res://src/feature/grid_battle/grid_battle_controller.gd"


## Asserts the 3-layer substrate is present in grid_battle_controller.gd:
##   1. `var <var_name>` declaration anywhere in the file
##   2. `<var_name> += 1` increment site
##   3. `"<field_name>": <var_name>` fate_data dict literal entry
##
## `chapter_label` is folded into the failure message so cross-chapter triage
## is clear when one missing layer fails multiple sentinels.
static func assert_substrate_present(
		suite: GdUnitTestSuite,
		field_name: String,
		var_name: String,
		chapter_label: String,
) -> void:
	var src: String = FileAccess.get_file_as_string(GRID_CONTROLLER_PATH)
	suite.assert_str(src).override_failure_message(
		"grid_battle_controller.gd not loadable: %s" % GRID_CONTROLLER_PATH
	).is_not_empty()

	# Layer 1 — declaration. We accept any `var <name>` form (typed-or-untyped)
	# rather than requiring the `: int` annotation, since some fields may use
	# `int = 0` shorthand or float types in future refactors.
	suite.assert_bool(src.contains("var " + var_name)).override_failure_message(
		("grid_battle_controller.gd missing `var %s` declaration "
		+ "(ch%s ★ substrate layer 1 broken)") % [var_name, chapter_label]
	).is_true()

	# Layer 2 — increment site. Any `<var_name> += 1` (caller-side discipline
	# guarantees the operator pattern; if a chapter needs `-=` it should be a
	# separate dedicated sentinel since negative counters break Pillar 2 monotonic
	# fate progress).
	suite.assert_bool(src.contains(var_name + " += 1")).override_failure_message(
		("grid_battle_controller.gd missing `%s += 1` increment site — "
		+ "ch%s ★ trigger substrate layer 2 broken") % [var_name, chapter_label]
	).is_true()

	# Layer 3 — fate_data emit. Match the exact dict literal pair so a typo in
	# either the key string or the var reference fails.
	var emit_substring: String = '"' + field_name + '": ' + var_name
	suite.assert_bool(src.contains(emit_substring)).override_failure_message(
		("grid_battle_controller.gd missing fate_data emit `%s` — "
		+ "ch%s ★ trigger substrate layer 3 broken") % [emit_substring, chapter_label]
	).is_true()
