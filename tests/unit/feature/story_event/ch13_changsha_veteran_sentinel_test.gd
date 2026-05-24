## ch13_changsha_veteran_sentinel_test.gd
##
## Sentinels for ch13 위연 합류 (per design/narrative/branch-distribution-plan.md
## §4.4 — reference ★, existing impl as of S82). Asserts:
##   - hidden_condition exact shape (wei_yan_spared_turns >= 3)
##   - branch_table 3 entries + hidden_branch_key + canonical_branch_key locks
##   - echo_threshold = 2 (plan §4.4 default)
##   - wei_yan_spared_turns substrate present in grid_battle_controller.gd
##     (declaration + increment + fate_data emit grep sentinel)
##
## ★ trigger ship-ready verification (MVP 5 중 3번째 — ch05 4-layer + ch08
## 2-layer 이후). chapter data is existing impl, no JSON edit required.
extends GdUnitTestSuite


const SCENARIO_PATH: String = "res://assets/data/scenarios/shu_canon_main.json"
const GRID_CONTROLLER_PATH: String = "res://src/feature/grid_battle/grid_battle_controller.gd"


func _load_chapter() -> Dictionary:
	var raw: String = FileAccess.get_file_as_string(SCENARIO_PATH)
	var parsed: Variant = JSON.parse_string(raw)
	var chapters: Array = (parsed as Dictionary).get("chapters", []) as Array
	for ch_var: Variant in chapters:
		var ch: Dictionary = ch_var as Dictionary
		if (ch.get("chapter_id", "") as String) == "ch13_changsha_veteran":
			return ch
	return {}


func test_ch13_hidden_condition_wei_yan_spared_turns_gte_3() -> void:
	var ch13: Dictionary = _load_chapter()
	assert_bool(ch13.is_empty()).override_failure_message(
		"ch13_changsha_veteran chapter not found in shu_canon_main.json"
	).is_false()
	var hc: Dictionary = ch13.get("hidden_condition", {}) as Dictionary
	assert_str(hc.get("type", "") as String).is_equal("fate_threshold")
	assert_str(hc.get("field", "") as String).override_failure_message(
		"ch13 hidden_condition.field != 'wei_yan_spared_turns' — Plan §4.4 ★ trigger contract"
	).is_equal("wei_yan_spared_turns")
	assert_str(hc.get("op", "") as String).is_equal(">=")
	assert_int(int(hc.get("value", -1))).override_failure_message(
		"ch13 hidden_condition.value != 3 (★ trigger threshold regression)"
	).is_equal(3)


func test_ch13_branch_table_and_routing_locks() -> void:
	var ch13: Dictionary = _load_chapter()
	var bt: Dictionary = ch13.get("branch_table", {}) as Dictionary
	assert_str(bt.get("WIN_default", "") as String).is_equal("WIN_changsha_taken")
	assert_str(bt.get("WIN_hidden", "") as String).override_failure_message(
		"ch13 branch_table['WIN_hidden'] != 'WIN_changsha_wei_yan_defects' (★ branch name regression)"
	).is_equal("WIN_changsha_wei_yan_defects")
	assert_str(bt.get("LOSS_default", "") as String).is_equal("LOSS_changsha_repelled")
	assert_str(ch13.get("hidden_branch_key", "") as String).is_equal("WIN_hidden")
	assert_str(ch13.get("canonical_branch_key", "") as String).is_equal("WIN_changsha_taken")
	assert_int(int(ch13.get("echo_threshold", -1))).override_failure_message(
		"ch13 echo_threshold != 2 (Plan §4.4 default; signature ★ scarcity)"
	).is_equal(2)


func test_ch13_wei_yan_spared_turns_substrate_present_in_controller() -> void:
	# AC — substrate guarantee for ★ trigger. ch13's ★ requires
	# `_fate_wei_yan_spared_turns` declaration + increment site + fate_data emit.
	# Future refactor 가 어떤 layer 라도 drop 시 본 test 즉시 fail.
	var src: String = FileAccess.get_file_as_string(GRID_CONTROLLER_PATH)
	assert_str(src).is_not_empty()
	# 1. Declaration
	assert_bool(src.contains("var _fate_wei_yan_spared_turns")).override_failure_message(
		"grid_battle_controller.gd missing _fate_wei_yan_spared_turns declaration"
	).is_true()
	# 2. Increment site
	assert_bool(src.contains("_fate_wei_yan_spared_turns += 1")).override_failure_message(
		"grid_battle_controller.gd missing _fate_wei_yan_spared_turns increment site — "
		+ "ch13 ★ trigger substrate broken (Plan §4.4)"
	).is_true()
	# 3. fate_data emit
	assert_bool(src.contains('"wei_yan_spared_turns": _fate_wei_yan_spared_turns')).override_failure_message(
		"grid_battle_controller.gd missing fate_data 'wei_yan_spared_turns' emit"
	).is_true()
