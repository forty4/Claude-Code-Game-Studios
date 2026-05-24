## ch10_chibi_perfect_wind_sentinel_test.gd
##
## Sentinels for ch10 적벽 동남풍 perfect timing (per
## design/quick-specs/ch10-chibi-perfect-wind.md, S84 spec + impl arc).
## Asserts:
##   AC-2 — ch10 hidden_condition exact shape:
##           {fate_threshold, player_casualties, <=, 0} + branch_table.WIN_hidden
##           = "WIN_chibi_perfect_southeast_wind" + hidden_branch_key = "WIN_hidden".
##   AC-3 — victory_conditions SURVIVE_N_ROUNDS+survive_rounds=5 unchanged.
##   AC-4 — canonical_branch_key + echo_threshold=2 unchanged.
##   AC-5 — _fate_player_casualties substrate 3-layer present in controller
##           (declaration + increment in _on_unit_died + fate_data emit).
##
## ★ trigger ship-ready verification (MVP 5/5 — ch05/ch08/ch13/ch16 이후
## 마지막 ★). entity-less, substrate add only (3-layer in 1 commit).
extends GdUnitTestSuite


const SCENARIO_PATH: String = "res://assets/data/scenarios/shu_canon_main.json"
const GRID_CONTROLLER_PATH: String = "res://src/feature/grid_battle/grid_battle_controller.gd"


func _load_chapter() -> Dictionary:
	var raw: String = FileAccess.get_file_as_string(SCENARIO_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	var chapters: Array = (parsed as Dictionary).get("chapters", []) as Array
	for ch_var: Variant in chapters:
		var ch: Dictionary = ch_var as Dictionary
		if (ch.get("chapter_id", "") as String) == "ch10_chibi_main":
			return ch
	return {}


func test_ch10_hidden_condition_player_casualties_le_0() -> void:
	var ch10: Dictionary = _load_chapter()
	assert_bool(ch10.is_empty()).override_failure_message(
		"ch10_chibi_main chapter not found in shu_canon_main.json"
	).is_false()
	var hc: Dictionary = ch10.get("hidden_condition", {}) as Dictionary
	assert_str(hc.get("type", "") as String).is_equal("fate_threshold")
	assert_str(hc.get("field", "") as String).override_failure_message(
		"ch10 hidden_condition.field != 'player_casualties' — Plan §4.3 ★ trigger contract"
	).is_equal("player_casualties")
	assert_str(hc.get("op", "") as String).override_failure_message(
		"ch10 hidden_condition.op != '<=' — '전원 생존' semantics regression"
	).is_equal("<=")
	assert_int(int(hc.get("value", -1))).override_failure_message(
		"ch10 hidden_condition.value != 0 (★ trigger 'zero casualties' lock regression)"
	).is_equal(0)


func test_ch10_branch_table_includes_win_hidden_after_authoring() -> void:
	var ch10: Dictionary = _load_chapter()
	var bt: Dictionary = ch10.get("branch_table", {}) as Dictionary
	assert_int(bt.size()).override_failure_message(
		"ch10 branch_table must have 3 entries (default+hidden+loss) after S84 ★ authoring"
	).is_equal(3)
	assert_str(bt.get("WIN_default", "") as String).is_equal("WIN_chibi_main_burn")
	assert_str(bt.get("WIN_hidden", "") as String).override_failure_message(
		"ch10 branch_table['WIN_hidden'] != 'WIN_chibi_perfect_southeast_wind' (★ branch name regression)"
	).is_equal("WIN_chibi_perfect_southeast_wind")
	assert_str(bt.get("LOSS_default", "") as String).is_equal("LOSS_chibi_main_wind_fails")
	assert_str(ch10.get("hidden_branch_key", "") as String).override_failure_message(
		"ch10 hidden_branch_key != 'WIN_hidden' (★ routing regression)"
	).is_equal("WIN_hidden")
	assert_str(ch10.get("canonical_branch_key", "") as String).is_equal("WIN_chibi_main_burn")
	assert_int(int(ch10.get("echo_threshold", -1))).override_failure_message(
		"ch10 echo_threshold != 2 (Plan §4.3 signature ★ scarcity)"
	).is_equal(2)


func test_ch10_victory_conditions_survive_5_unchanged() -> void:
	var ch10: Dictionary = _load_chapter()
	var vc: Dictionary = ch10.get("victory_conditions", {}) as Dictionary
	# SURVIVE_N_ROUNDS primary_condition_type = 1
	assert_int(int(vc.get("primary_condition_type", -1))).override_failure_message(
		"ch10 victory_conditions.primary_condition_type != 1 (SURVIVE_N_ROUNDS regression — "
		+ "동남풍 5턴 metaphor lock)"
	).is_equal(1)
	assert_int(int(vc.get("survive_rounds", -1))).override_failure_message(
		"ch10 survive_rounds != 5 (Plan §4.3 timing lock — 동남풍 지속 시간 metaphor)"
	).is_equal(5)


func test_ch10_player_casualties_substrate_present_in_controller() -> void:
	# AC-5 — substrate guarantee for ★ trigger. ch10's ★ requires
	# `_fate_player_casualties` declaration + increment site (in _on_unit_died,
	# player-side filter) + fate_data emit. Future refactor 가 어떤 layer 라도
	# drop 시 본 test 즉시 fail.
	var src: String = FileAccess.get_file_as_string(GRID_CONTROLLER_PATH)
	assert_str(src).is_not_empty()
	# 1. Declaration
	assert_bool(src.contains("var _fate_player_casualties")).override_failure_message(
		"grid_battle_controller.gd missing _fate_player_casualties declaration "
		+ "(S84 substrate add regression)"
	).is_true()
	# 2. Increment site
	assert_bool(src.contains("_fate_player_casualties += 1")).override_failure_message(
		"grid_battle_controller.gd missing _fate_player_casualties increment site — "
		+ "ch10 ★ trigger substrate broken (Plan §4.3)"
	).is_true()
	# 3. fate_data emit
	assert_bool(src.contains('"player_casualties": _fate_player_casualties')).override_failure_message(
		"grid_battle_controller.gd missing fate_data 'player_casualties' emit"
	).is_true()
