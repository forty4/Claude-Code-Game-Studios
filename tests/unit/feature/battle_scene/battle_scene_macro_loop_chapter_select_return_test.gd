## battle_scene_macro_loop_chapter_select_return_test.gd
##
## S17 macro-loop sentinel — covers the 4-change patch that redirects the
## post-battle proceed flow back to chapter_select instead of auto-loading
## the next chapter. Pre-S17 the flow was OutcomeBanner → ceremonial Beat
## 8/9 prose → _reload_via_scenario() → next chapter; the milestone's
## "DEV menu 졸업" goal needs the player to explicitly choose the next
## chapter from the selection screen.
##
## Tests are source-grep level — verifying the production code wires the
## chapter_select scene path at the right boundaries — because the actual
## scene transition is integration-level and is gated by the windowed
## attestation pass (`production/qa/evidence/
## phase-f-windowed-boot-attestation-16-chapters.md`).
##
## Sentinel responsibilities:
##   1. _CHAPTER_SELECT_SCENE_PATH constant defined + correct path
##   2. _proceed_scenario tail calls change_scene_to_file with that path
##   3. Post-battle WIN button labelled "챕터 선택으로 ▶" (not "다음 장으로")
##   4. Ending screen surfaces a "챕터 선택으로" return button
##   5. No production code still references "다음 장으로" (the pre-S17 label)
extends GdUnitTestSuite


const _BATTLE_SCENE_SCRIPT_PATH: String = "res://src/feature/battle_scene/battle_scene.gd"
const _CHAPTER_SELECT_SCENE_PATH_EXPECTED: String = "res://scenes/chapter_select/chapter_select.tscn"


# ─── Constant sentinel ───────────────────────────────────────────────────────

func test_chapter_select_scene_path_constant_present() -> void:
	var script: GDScript = load(_BATTLE_SCENE_SCRIPT_PATH) as GDScript
	var consts: Dictionary = script.get_script_constant_map()
	assert_bool(consts.has("_CHAPTER_SELECT_SCENE_PATH")).override_failure_message(
		"battle_scene.gd must declare const _CHAPTER_SELECT_SCENE_PATH for the S17 "
		+ "macro-loop return path."
	).is_true()


func test_chapter_select_scene_path_constant_value() -> void:
	var script: GDScript = load(_BATTLE_SCENE_SCRIPT_PATH) as GDScript
	var consts: Dictionary = script.get_script_constant_map()
	var path: String = consts.get("_CHAPTER_SELECT_SCENE_PATH", "") as String
	assert_str(path).override_failure_message(
		"_CHAPTER_SELECT_SCENE_PATH must equal %s. Got: %s"
			% [_CHAPTER_SELECT_SCENE_PATH_EXPECTED, path]
	).is_equal(_CHAPTER_SELECT_SCENE_PATH_EXPECTED)


# ─── Source-grep sentinels (S17 macro-loop wiring) ───────────────────────────

func test_proceed_scenario_tail_routes_to_chapter_select() -> void:
	# _proceed_scenario must end by calling change_scene_to_file with the
	# chapter_select path (not _reload_via_scenario as it did pre-S17).
	var source: String = _read_source()
	# We grep for the literal combination: "change_scene_to_file(_CHAPTER_SELECT_SCENE_PATH)"
	# appearing inside the file. This is the canonical S17 macro-loop exit point.
	assert_bool(source.contains("change_scene_to_file(_CHAPTER_SELECT_SCENE_PATH)")).override_failure_message(
		"battle_scene.gd must contain `change_scene_to_file(_CHAPTER_SELECT_SCENE_PATH)` "
		+ "(the S17 macro-loop return path at _proceed_scenario tail + ending screen "
		+ "primary button). Pre-S17 used `_reload_via_scenario` which auto-loaded the "
		+ "next chapter — that bypasses the chapter-selection screen."
	).is_true()


func test_post_battle_win_button_label_is_chapter_select_return() -> void:
	# WIN → "챕터 선택으로 ▶  (Enter)" is the primary first button.
	# Pre-S17 was "다음 장으로 ▶  (Enter)".
	var source: String = _read_source()
	assert_bool(source.contains("챕터 선택으로 ▶  (Enter)")).override_failure_message(
		"post-battle WIN row must surface a '챕터 선택으로 ▶  (Enter)' button — the "
		+ "primary macro-loop return. Pre-S17 label '다음 장으로 ▶  (Enter)' must have "
		+ "been replaced."
	).is_true()


func test_ending_screen_has_chapter_select_return_button() -> void:
	# Scenario complete card (after last chapter) — primary button now returns to
	# chapter_select rather than restarting from ch01.
	var source: String = _read_source()
	assert_bool(source.contains("챕터 선택으로  (Enter)")).override_failure_message(
		"_show_ending_screen must mount a '챕터 선택으로  (Enter)' return button as "
		+ "the primary action (with focus). Pre-S17 only offered '처음부터' as primary."
	).is_true()


func test_pre_s17_dauem_jangeuro_label_removed() -> void:
	# Sentinel: no production button still says "다음 장으로" (Korean for "to the
	# next chapter"). Any reappearance means the macro-loop redirect regressed.
	# Note: this checks BUTTON labels not narrative prose; the literal substring
	# "다음 장으로" could legitimately appear in docstring discussion of the
	# pre-S17 history — and indeed does in story_beat_screen.gd:73 (different
	# file, contextual reference, OK). The check is scoped to battle_scene.gd's
	# button-mounting region.
	var source: String = _read_source()
	# Search the post-battle button cluster region (between markers) — the
	# button labels live in _mount_post_battle_buttons + _show_ending_screen.
	# A simple substring check is fine because battle_scene.gd's docstring at
	# line 2076 was also updated in the same patch to remove "다음 장으로".
	assert_bool(source.contains("다음 장으로")).override_failure_message(
		"battle_scene.gd must not retain the pre-S17 '다음 장으로' button label "
		+ "(either in code or docstring within this file). The macro-loop redirect "
		+ "renamed it to '챕터 선택으로'."
	).is_false()


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _read_source() -> String:
	var raw: String = FileAccess.get_file_as_string(_BATTLE_SCENE_SCRIPT_PATH)
	assert_bool(raw.is_empty()).override_failure_message(
		"Could not read battle_scene.gd at %s" % _BATTLE_SCENE_SCRIPT_PATH
	).is_false()
	return raw
