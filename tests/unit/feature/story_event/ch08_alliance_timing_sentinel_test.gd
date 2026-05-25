## ch08_alliance_timing_sentinel_test.gd
##
## Sentinels for ch08 alliance timing per
## `design/quick-specs/ch08-alliance-timing.md` (S82 spec, S82+ impl arc).
## Asserts:
##   AC-2 — ch08 hidden_condition exact shape:
##           {type: fate_threshold, field: win_within_turns, op: <=, value: 6}
##           (substrate정합 lock; spec §3.1).
##   AC-3 — ch08 victory_conditions REACH_TILE [13,4] unchanged
##           (Plan §4.2 "도주→재집결" narrative regression sentinel).
##   AC-4 — ch08 branch_table + hidden_branch_key + canonical_branch_key +
##           echo_threshold all locked to current data (spec §4.2/§4.3 decisions).
##   AC-6 — GridBattleController fate_data emit shape — `win_within_turns`
##           field present in production source (grid_battle_controller.gd:3362
##           VICTORY-outcome auto-set guarantee).
extends GdUnitTestSuite


const SCENARIO_PATH: String = "res://assets/data/scenarios/shu_canon_main.json"
const GRID_CONTROLLER_PATH: String = "res://src/feature/grid_battle/grid_battle_controller.gd"


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


func test_ch08_hidden_condition_win_within_turns_le_6() -> void:
	# Arrange
	var ch08: Dictionary = _chapter_by_id("ch08_xiakou_outskirts")
	assert_bool(ch08.is_empty()).override_failure_message(
		"ch08_xiakou_outskirts chapter not found in shu_canon_main.json"
	).is_false()

	# Act
	var hc: Dictionary = ch08.get("hidden_condition", {}) as Dictionary

	# Assert — exact shape {type, field, op, value} per spec §3.1
	assert_str(hc.get("type", "") as String).override_failure_message(
		"ch08 hidden_condition.type != 'fate_threshold' (HiddenConditionEvaluator predicate regression)"
	).is_equal("fate_threshold")
	assert_str(hc.get("field", "") as String).override_failure_message(
		"ch08 hidden_condition.field != 'win_within_turns' — substrate alignment regression "
		+ "(grid_battle_controller.gd:3362 fate_data emit name)"
	).is_equal("win_within_turns")
	assert_str(hc.get("op", "") as String).override_failure_message(
		"ch08 hidden_condition.op != '<=' — turn-limit semantics regression"
	).is_equal("<=")
	assert_int(int(hc.get("value", -1))).override_failure_message(
		"ch08 hidden_condition.value != 6 (★ trigger threshold regression; spec OQ-1 default)"
	).is_equal(6)


func test_ch08_victory_conditions_reach_tile_13_4_unchanged() -> void:
	# Arrange
	var ch08: Dictionary = _chapter_by_id("ch08_xiakou_outskirts")
	var vc: Dictionary = ch08.get("victory_conditions", {}) as Dictionary

	# Act + Assert — primary_condition_type=3 (REACH_TILE) per spec §3.2 lock
	assert_int(int(vc.get("primary_condition_type", -1))).override_failure_message(
		"ch08 victory_conditions.primary_condition_type != 3 (REACH_TILE) — "
		+ "narrative 도주→재집결 regression (spec §3.2)"
	).is_equal(3)
	var target_unit_ids: Array = vc.get("target_unit_ids", []) as Array
	assert_int(target_unit_ids.size()).is_equal(1)
	assert_int(target_unit_ids[0] as int).override_failure_message(
		"ch08 target_unit_ids[0] != 0 (유비 unit_id) — REACH_TILE carrier regression"
	).is_equal(0)
	var target_tile: Array = vc.get("target_tile", []) as Array
	assert_int(target_tile.size()).is_equal(2)
	assert_int(target_tile[0] as int).override_failure_message(
		"ch08 target_tile[0] != 13 (재집결 지점 col regression)"
	).is_equal(13)
	assert_int(target_tile[1] as int).override_failure_message(
		"ch08 target_tile[1] != 4 (재집결 지점 row regression)"
	).is_equal(4)


func test_ch08_branch_table_and_routing_locks() -> void:
	# Arrange — spec §4.2/§4.3 의 design 결정 lock (echo_threshold 1 + branch
	# names + hidden_branch_key 모두 현재 데이터 유지)
	var ch08: Dictionary = _chapter_by_id("ch08_xiakou_outskirts")

	# Act
	var bt: Dictionary = ch08.get("branch_table", {}) as Dictionary
	var hidden_key: String = ch08.get("hidden_branch_key", "") as String
	var canonical_key: String = ch08.get("canonical_branch_key", "") as String
	var echo_threshold: int = int(ch08.get("echo_threshold", -1))

	# Assert — branch_table 3 entries (spec §4.3 lock)
	assert_str(bt.get("WIN_default", "") as String).override_failure_message(
		"ch08 branch_table['WIN_default'] != 'WIN_xiakou_breakthrough' (canonical name regression)"
	).is_equal("WIN_xiakou_breakthrough")
	assert_str(bt.get("WIN_hidden", "") as String).override_failure_message(
		"ch08 branch_table['WIN_hidden'] != 'WIN_xiakou_united_advance' (★ branch name regression)"
	).is_equal("WIN_xiakou_united_advance")
	assert_str(bt.get("LOSS_default", "") as String).override_failure_message(
		"ch08 branch_table['LOSS_default'] != 'LOSS_xiakou_pursuit_continues' (default LOSS name regression)"
	).is_equal("LOSS_xiakou_pursuit_continues")
	# Assert — routing keys
	assert_str(hidden_key).is_equal("WIN_hidden")
	assert_str(canonical_key).is_equal("WIN_xiakou_breakthrough")
	# Assert — echo_threshold 1 (spec §4.2 deviation note from Plan §4.2's
	# hypothetical 2 — codified, do not flip without spec amendment)
	assert_int(echo_threshold).override_failure_message(
		"ch08 echo_threshold != 1 (spec §4.2 lock — timing-feedback 즉시성 rationale)"
	).is_equal(1)


func test_ch08_win_within_turns_substrate_present_in_controller() -> void:
	# AC-6 — substrate 정합 검증 via FateSubstrateAssertions (S85 helper, 4-instance
	# pattern extraction). NOTE: ch08 uses `_fate_win_within_turns = ` (auto-set
	# at VICTORY, NOT `+= 1`) — so we cannot use the generic 3-layer helper as-is.
	# Direct grep for the 2 critical layers (declaration + emit; set-site is
	# `=` not `+=`).
	var src: String = FileAccess.get_file_as_string(GRID_CONTROLLER_PATH)
	assert_str(src).override_failure_message(
		"grid_battle_controller.gd not loadable: %s" % GRID_CONTROLLER_PATH
	).is_not_empty()
	assert_bool(src.contains('"win_within_turns": _fate_win_within_turns')).override_failure_message(
		"grid_battle_controller.gd missing fate_data 'win_within_turns' emit — "
		+ "ch08 ★ trigger substrate broken (spec §3.3 / AC-6)"
	).is_true()
	assert_bool(src.contains("_fate_win_within_turns = ")).override_failure_message(
		"grid_battle_controller.gd missing _fate_win_within_turns set site — "
		+ "VICTORY auto-set substrate broken"
	).is_true()
