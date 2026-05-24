## ch05_civilian_evacuation_sentinel_test.gd
##
## Sentinels for ch05 civilian evacuation per
## `design/quick-specs/ch05-civilian-evacuation.md` + ADR-0022.
## Asserts:
##   AC-4 — ch05 civilian_config.positions has 5 entries with exact coords
##           [[3,2], [5,3], [4,5], [4,7], [6,6]] (token placement balance lock).
##   AC-4 — ch05 civilian_config.evacuate_zone_max_col == 0 (한진 west zone).
##   AC-12 — every other chapter (ch01-ch04, ch06-ch16) has empty civilian_config
##           OR omits the field (regression sentinel for "civilian system stays
##           ch05-only" per ADR-0022 scope lock).
##   ★ scaffold — hidden_condition still targets `civilians_escorted >= 3` and
##           `hidden_branch_key == "WIN_hidden"` resolves to `WIN_xinye_civilians_saved`
##           (verifies plan §4.1 ★ trigger architecture intact).
extends GdUnitTestSuite


const SCENARIO_PATH: String = "res://assets/data/scenarios/shu_canon_main.json"

const EXPECTED_CH05_POSITIONS: Array[Array] = [
	[3, 2],
	[5, 3],
	[4, 5],
	[4, 7],
	[6, 6],
]


func _load_scenario() -> Dictionary:
	var raw: String = FileAccess.get_file_as_string(SCENARIO_PATH)
	assert_str(raw).override_failure_message(
		"scenario file missing or empty: %s" % SCENARIO_PATH
	).is_not_empty()
	var parsed: Variant = JSON.parse_string(raw)
	assert_bool(parsed is Dictionary).override_failure_message(
		"%s did not parse to a JSON object" % SCENARIO_PATH
	).is_true()
	return parsed as Dictionary


func _chapter_by_id(chapter_id: String) -> Dictionary:
	var scenario: Dictionary = _load_scenario()
	var chapters: Array = scenario.get("chapters", []) as Array
	for ch_var: Variant in chapters:
		var ch: Dictionary = ch_var as Dictionary
		if (ch.get("chapter_id", "") as String) == chapter_id:
			return ch
	return {}


func test_ch05_civilian_config_5_tokens_present() -> void:
	# Arrange
	var ch05: Dictionary = _chapter_by_id("ch05_xinye_fire")
	assert_bool(ch05.is_empty()).override_failure_message(
		"ch05_xinye_fire chapter not found in shu_canon_main.json"
	).is_false()

	# Act
	var cc: Dictionary = ch05.get("civilian_config", {}) as Dictionary
	var positions: Array = cc.get("positions", []) as Array

	# Assert
	assert_int(positions.size()).override_failure_message(
		"ch05 civilian_config.positions size != 5 (token placement regression)"
	).is_equal(5)
	for i in range(5):
		var pos: Array = positions[i] as Array
		var expected: Array = EXPECTED_CH05_POSITIONS[i]
		assert_int(pos[0] as int).override_failure_message(
			"ch05 civilian token[%d] col != %d (placement balance lock)" % [i, expected[0] as int]
		).is_equal(expected[0] as int)
		assert_int(pos[1] as int).override_failure_message(
			"ch05 civilian token[%d] row != %d (placement balance lock)" % [i, expected[1] as int]
		).is_equal(expected[1] as int)


func test_ch05_civilian_config_evacuate_zone_max_col_0() -> void:
	# Arrange
	var ch05: Dictionary = _chapter_by_id("ch05_xinye_fire")
	var cc: Dictionary = ch05.get("civilian_config", {}) as Dictionary

	# Act
	var zone_max_col: int = int(cc.get("evacuate_zone_max_col", -999))

	# Assert
	assert_int(zone_max_col).override_failure_message(
		"ch05 evacuate_zone_max_col != 0 (한진 west zone regression — Beat 1 narrative anchor)"
	).is_equal(0)


# AC-12 — Other chapters MUST NOT acquire civilian_config (ADR-0022 scope lock).
# civilian_config 가 ch05 외에서 활성되면 1) chapter 별 wiring 가 spread → impl 복잡도 증가,
# 2) plan §10 의 "default-only declaration" 위반 (regression sentinel).
func test_other_chapters_have_empty_civilian_config() -> void:
	# Arrange
	var scenario: Dictionary = _load_scenario()
	var chapters: Array = scenario.get("chapters", []) as Array

	# Act + Assert
	for ch_var: Variant in chapters:
		var ch: Dictionary = ch_var as Dictionary
		var cid: String = ch.get("chapter_id", "") as String
		if cid == "ch05_xinye_fire":
			continue
		var cc: Dictionary = ch.get("civilian_config", {}) as Dictionary
		assert_bool(cc.is_empty()).override_failure_message(
			"chapter %s has non-empty civilian_config — violates ADR-0022 scope lock (ch05-only)" % cid
		).is_true()


# ★ scaffold sentinel — ensures hidden branch routing remains intact.
# civilians_escorted >= 3 → WIN_hidden → WIN_xinye_civilians_saved.
func test_ch05_hidden_branch_civilians_escorted_3_scaffold() -> void:
	# Arrange
	var ch05: Dictionary = _chapter_by_id("ch05_xinye_fire")

	# Act
	var hidden_key: String = ch05.get("hidden_branch_key", "") as String
	var bt: Dictionary = ch05.get("branch_table", {}) as Dictionary
	var hc: Dictionary = ch05.get("hidden_condition", {}) as Dictionary

	# Assert — branch routing
	assert_str(hidden_key).override_failure_message(
		"ch05 hidden_branch_key != 'WIN_hidden' (★ scaffold regression)"
	).is_equal("WIN_hidden")
	assert_str(bt.get("WIN_hidden", "") as String).override_failure_message(
		"ch05 branch_table['WIN_hidden'] != 'WIN_xinye_civilians_saved' (★ branch_path_id regression)"
	).is_equal("WIN_xinye_civilians_saved")
	# Assert — hidden_condition (HiddenConditionEvaluator fate_threshold predicate)
	assert_str(hc.get("type", "") as String).is_equal("fate_threshold")
	assert_str(hc.get("field", "") as String).override_failure_message(
		"ch05 hidden_condition.field != 'civilians_escorted' — counter wiring contract violated"
	).is_equal("civilians_escorted")
	assert_str(hc.get("op", "") as String).is_equal(">=")
	assert_int(int(hc.get("value", -1))).override_failure_message(
		"ch05 hidden_condition.value != 3 (★ trigger threshold regression)"
	).is_equal(3)
