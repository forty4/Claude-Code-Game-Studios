## s96_late_roster_balance_sentinel_test.gd
##
## Sentinels for the S96 late-game difficulty fix (raw-feedback #1 "난이도 너무
## 낮음", limitation ② from S95). The S95 atk_mult ramp could NOT move the
## late DEFEAT_ALL attrition margin: ch11-14 were 6 player heroes vs 4 static
## enemies, so the player won by pure attrition (harness margin +1.27~+1.36 =
## "wins without using the strategy layer"). atk_mult raises per-hit damage but
## cannot overcome the 6v4 numeric asymmetry.
##
## Fix (telemetry-driven, tools/ci/balance/whatif_late_roster.gd): add a 5th
## enemy to each of ch11-14 (→ 6v5), pulling the margin to -0.24~-0.47 — back
## into the early-game "strategy-required" zone (ch01 -0.43, ch03 -0.32).
##
## This sentinel locks the roster decision against regression. Asserts per
## chapter: enemy_roster size == 5 ; the added unit_id=8 entry's hero_id +
## archetype ; enemy_unit_ids contains 8 ; deployment_positions_default["8"]
## is the authored plains tile. ch11/12/14 add 조조 (only unused wei COMMANDER);
## ch13 already fields 조조 → adds 서황 (wei_008_xu_chu).
extends GdUnitTestSuite


const SCENARIO_PATH: String = "res://assets/data/scenarios/shu_canon_main.json"
const NEW_ENEMY_UID: int = 8

# chapter_id -> [hero_id, archetype, [col, row]] for the S96 5th enemy.
const PLAN: Dictionary = {
	"ch11_jingzhou_pacify": ["wei_001_cao_cao", "coordinator", [12, 3]],
	"ch12_wuling_marsh": ["wei_001_cao_cao", "coordinator", [12, 3]],
	"ch13_changsha_veteran": ["wei_008_xu_chu", "aggressor", [11, 4]],
	"ch14_jingzhou_consolidate": ["wei_001_cao_cao", "coordinator", [13, 3]],
}


func _load_json_object(path: String) -> Dictionary:
	var raw: String = FileAccess.get_file_as_string(path)
	assert_str(raw).override_failure_message("file missing or empty: %s" % path).is_not_empty()
	var parsed: Variant = JSON.parse_string(raw)
	assert_bool(parsed is Dictionary).override_failure_message(
		"%s did not parse to a JSON object" % path
	).is_true()
	return parsed as Dictionary


func _chapter_by_id(chapter_id: String) -> Dictionary:
	var scenario: Dictionary = _load_json_object(SCENARIO_PATH)
	var chapters: Array = scenario.get("chapters", []) as Array
	for ch_var: Variant in chapters:
		var ch: Dictionary = ch_var as Dictionary
		if (ch.get("chapter_id", "") as String) == chapter_id:
			return ch
	assert_bool(false).override_failure_message(
		"chapter not found: %s" % chapter_id
	).is_true()
	return {}


# AC-1 — each late DEFEAT_ALL chapter fields exactly 5 enemies (was 4, S96 +1).
func test_ch11_to_14_each_have_five_enemies() -> void:
	for chapter_id: String in PLAN:
		var ch: Dictionary = _chapter_by_id(chapter_id)
		var roster: Array = ch.get("enemy_roster", []) as Array
		assert_int(roster.size()).override_failure_message(
			"%s enemy_roster size != 5 — S96 late-game 6v5 attrition fix regressed "
			% chapter_id
			+ "(reverting to 6v4 makes the chapter winnable by pure attrition, "
			+ "raw-feedback #1 '난이도 낮음')"
		).is_equal(5)


# AC-2 — the appended unit_id=8 entry is the authored hero + archetype.
func test_ch11_to_14_fifth_enemy_identity() -> void:
	for chapter_id: String in PLAN:
		var spec: Array = PLAN[chapter_id] as Array
		var expected_hero: String = spec[0] as String
		var expected_arch: String = spec[1] as String
		var ch: Dictionary = _chapter_by_id(chapter_id)
		var roster: Array = ch.get("enemy_roster", []) as Array
		var found: Dictionary = {}
		for entry_var: Variant in roster:
			var entry: Dictionary = entry_var as Dictionary
			if (entry.get("unit_id", -1) as int) == NEW_ENEMY_UID:
				found = entry
				break
		assert_bool(not found.is_empty()).override_failure_message(
			"%s enemy_roster missing unit_id=8 entry" % chapter_id
		).is_true()
		assert_str(found.get("hero_id", "") as String).override_failure_message(
			"%s 5th enemy hero_id != %s" % [chapter_id, expected_hero]
		).is_equal(expected_hero)
		assert_str(found.get("archetype", "") as String).override_failure_message(
			"%s 5th enemy archetype != %s (invalid archetype → EC-AI-4 warning)"
			% [chapter_id, expected_arch]
		).is_equal(expected_arch)


# AC-3 — enemy_unit_ids + deployment_positions_default stay consistent with the
# new roster entry (battle_scene spawns from roster but turn-order / victory use
# enemy_unit_ids; missing deployment → spawn falls back to a bad default tile).
func test_ch11_to_14_unit_ids_and_deployment_consistent() -> void:
	for chapter_id: String in PLAN:
		var spec: Array = PLAN[chapter_id] as Array
		var expected_pos: Array = spec[2] as Array
		var ch: Dictionary = _chapter_by_id(chapter_id)
		var unit_ids: Array = ch.get("enemy_unit_ids", []) as Array
		# JSON.parse_string yields float number literals → compare as int, not has().
		var has_new_uid: bool = false
		for uid_var: Variant in unit_ids:
			if int(uid_var) == NEW_ENEMY_UID:
				has_new_uid = true
				break
		assert_bool(has_new_uid).override_failure_message(
			"%s enemy_unit_ids missing %d" % [chapter_id, NEW_ENEMY_UID]
		).is_true()
		var dep: Dictionary = ch.get("deployment_positions_default", {}) as Dictionary
		assert_bool(dep.has(str(NEW_ENEMY_UID))).override_failure_message(
			"%s deployment_positions_default missing key '8'" % chapter_id
		).is_true()
		var pos: Array = dep.get(str(NEW_ENEMY_UID), []) as Array
		assert_int(pos.size()).override_failure_message(
			"%s deployment '8' is not a [col,row] pair" % chapter_id
		).is_equal(2)
		assert_int(pos[0] as int).override_failure_message(
			"%s deployment '8' col mismatch" % chapter_id
		).is_equal(expected_pos[0] as int)
		assert_int(pos[1] as int).override_failure_message(
			"%s deployment '8' row mismatch" % chapter_id
		).is_equal(expected_pos[1] as int)
