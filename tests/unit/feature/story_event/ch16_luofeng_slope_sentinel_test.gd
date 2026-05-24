## ch16_luofeng_slope_sentinel_test.gd
##
## Sentinels for ch16 방통 생존 (per design/narrative/branch-distribution-plan.md
## §4.5 — reference ★, existing impl as of S82). Asserts:
##   - hidden_condition exact shape (scout_first_turns >= 2)
##   - branch_table 3 entries + hidden_branch_key + canonical_branch_key locks
##   - echo_threshold = 3 (plan §4.5 default — highest scarcity)
##   - victory_conditions SURVIVE_N_ROUNDS survive_rounds=4 unchanged
##   - scout_first_turns substrate present in grid_battle_controller.gd
##
## ★ trigger ship-ready verification (MVP 5 중 4번째 — ch05/ch08/ch13 이후).
extends GdUnitTestSuite


const SCENARIO_PATH: String = "res://assets/data/scenarios/shu_canon_main.json"
const GRID_CONTROLLER_PATH: String = "res://src/feature/grid_battle/grid_battle_controller.gd"


func _load_chapter() -> Dictionary:
	var raw: String = FileAccess.get_file_as_string(SCENARIO_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	var chapters: Array = (parsed as Dictionary).get("chapters", []) as Array
	for ch_var: Variant in chapters:
		var ch: Dictionary = ch_var as Dictionary
		if (ch.get("chapter_id", "") as String) == "ch16_luofeng_slope":
			return ch
	return {}


func test_ch16_hidden_condition_scout_first_turns_gte_2() -> void:
	var ch16: Dictionary = _load_chapter()
	assert_bool(ch16.is_empty()).override_failure_message(
		"ch16_luofeng_slope chapter not found in shu_canon_main.json"
	).is_false()
	var hc: Dictionary = ch16.get("hidden_condition", {}) as Dictionary
	assert_str(hc.get("type", "") as String).is_equal("fate_threshold")
	assert_str(hc.get("field", "") as String).override_failure_message(
		"ch16 hidden_condition.field != 'scout_first_turns' — Plan §4.5 ★ trigger contract"
	).is_equal("scout_first_turns")
	assert_str(hc.get("op", "") as String).is_equal(">=")
	assert_int(int(hc.get("value", -1))).override_failure_message(
		"ch16 hidden_condition.value != 2 (★ trigger threshold regression)"
	).is_equal(2)


func test_ch16_branch_table_and_routing_locks() -> void:
	var ch16: Dictionary = _load_chapter()
	var bt: Dictionary = ch16.get("branch_table", {}) as Dictionary
	assert_str(bt.get("WIN_default", "") as String).is_equal("WIN_luofeng_kongming_arrives")
	assert_str(bt.get("WIN_hidden", "") as String).override_failure_message(
		"ch16 branch_table['WIN_hidden'] != 'WIN_luofeng_pang_tong_lives' (★ branch name regression)"
	).is_equal("WIN_luofeng_pang_tong_lives")
	assert_str(bt.get("LOSS_default", "") as String).is_equal("LOSS_luofeng_ambush_complete")
	assert_str(ch16.get("hidden_branch_key", "") as String).is_equal("WIN_hidden")
	assert_str(ch16.get("canonical_branch_key", "") as String).is_equal("WIN_luofeng_kongming_arrives")
	assert_int(int(ch16.get("echo_threshold", -1))).override_failure_message(
		"ch16 echo_threshold != 3 (Plan §4.5 default; highest scarcity ★ in MVP 5)"
	).is_equal(3)


func test_ch16_victory_conditions_survive_rounds_4_unchanged() -> void:
	var ch16: Dictionary = _load_chapter()
	var vc: Dictionary = ch16.get("victory_conditions", {}) as Dictionary
	# SURVIVE_N_ROUNDS primary_condition_type = 1 (VictoryConditions enum)
	assert_int(int(vc.get("primary_condition_type", -1))).override_failure_message(
		"ch16 victory_conditions.primary_condition_type != 1 (SURVIVE_N_ROUNDS regression)"
	).is_equal(1)
	assert_int(int(vc.get("survive_rounds", -1))).override_failure_message(
		"ch16 survive_rounds != 4 (Plan §4.5 timing lock — pang tong 합류 위치)"
	).is_equal(4)


func test_ch16_scout_first_turns_substrate_present_in_controller() -> void:
	var src: String = FileAccess.get_file_as_string(GRID_CONTROLLER_PATH)
	assert_str(src).is_not_empty()
	assert_bool(src.contains("var _fate_scout_first_turns")).override_failure_message(
		"grid_battle_controller.gd missing _fate_scout_first_turns declaration"
	).is_true()
	assert_bool(src.contains("_fate_scout_first_turns += 1")).override_failure_message(
		"grid_battle_controller.gd missing _fate_scout_first_turns increment site — "
		+ "ch16 ★ trigger substrate broken (Plan §4.5)"
	).is_true()
	assert_bool(src.contains('"scout_first_turns": _fate_scout_first_turns')).override_failure_message(
		"grid_battle_controller.gd missing fate_data 'scout_first_turns' emit"
	).is_true()
