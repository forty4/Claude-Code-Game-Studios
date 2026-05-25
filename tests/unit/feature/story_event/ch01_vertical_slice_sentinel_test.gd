## ch01_vertical_slice_sentinel_test.gd
##
## Sentinels for ch01 vertical-slice uplift per
## `design/quick-specs/ch01-vertical-slice-uplift.md`. Asserts:
## 1. 황건 4 hero records (yel_001-004) exist in heroes.json, faction = 3 (QUNXIONG),
##    innate_skill_ids empty.
## 2. ch01 enemy_roster references only `yel_*` hero_ids (no `wei_*`).
## 3. ch01 tuning: enemy_atk_mult == 0.95, chokepoints length == 4 [[5,4],[6,4],[7,4],[8,4]].
## 4. ch01 branch_table is priming-null: keys exactly {WIN_default, LOSS_default} per
##    destiny-branch.md CR-13. Regression sentinel against future ★ leak.
## 5. ch01 Beat 8 default-WIN body contains ch05 seed substrings (백성을 지킬 날 / 신야의 흙길).
extends GdUnitTestSuite


const SCENARIO_PATH: String = "res://assets/data/scenarios/shu_canon_main.json"
const STORY_PATH: String = "res://assets/data/story/story_content.json"
const HEROES_PATH: String = "res://assets/data/heroes/heroes.json"

const EXPECTED_YEL_IDS: Array[String] = [
	"yel_001_cheng_yuanzhi",
	"yel_002_deng_mao",
	"yel_003_sun_zhong",
	"yel_004_huang_shao",
]

const FACTION_QUNXIONG: int = 3


func _load_json_object(path: String) -> Dictionary:
	var raw: String = FileAccess.get_file_as_string(path)
	assert_str(raw).override_failure_message("file missing or empty: %s" % path).is_not_empty()
	var parsed: Variant = JSON.parse_string(raw)
	assert_bool(parsed is Dictionary).override_failure_message(
		"%s did not parse to a JSON object" % path
	).is_true()
	return parsed as Dictionary


func _ch01_record() -> Dictionary:
	var scenario: Dictionary = _load_json_object(SCENARIO_PATH)
	var chapters: Array = scenario.get("chapters", []) as Array
	assert_int(chapters.size()).override_failure_message(
		"shu_canon_main.json has no chapters"
	).is_greater(0)
	return chapters[0] as Dictionary


# AC-1 — 4 황건 hero records 존재 + faction QUNXIONG + innate_skill_ids 비어있음
func test_ch01_yellow_turban_hero_records_exist() -> void:
	var heroes: Dictionary = _load_json_object(HEROES_PATH)
	for hid: String in EXPECTED_YEL_IDS:
		assert_bool(heroes.has(hid)).override_failure_message(
			"missing 황건 hero record: %s" % hid
		).is_true()
		var record: Dictionary = heroes[hid] as Dictionary
		assert_int(record.get("faction", -1) as int).override_failure_message(
			"%s faction != QUNXIONG (3)" % hid
		).is_equal(FACTION_QUNXIONG)
		var skills: Array = record.get("innate_skill_ids", []) as Array
		assert_int(skills.size()).override_failure_message(
			"%s has innate_skill_ids (expected empty per ch01 simplification)" % hid
		).is_equal(0)


# AC-2 — ch01 enemy_roster 가 yel_ prefix 만, 위(wei_) 미포함
func test_ch01_roster_is_yellow_turban() -> void:
	var ch01: Dictionary = _ch01_record()
	var roster: Array = ch01.get("enemy_roster", []) as Array
	assert_int(roster.size()).override_failure_message(
		"ch01 enemy_roster size != 4"
	).is_equal(4)
	for entry_var: Variant in roster:
		var entry: Dictionary = entry_var as Dictionary
		var hero_id: String = entry.get("hero_id", "") as String
		assert_bool(hero_id.begins_with("yel_")).override_failure_message(
			"ch01 enemy_roster contains non-황건 hero: %s (lore mismatch with 중평 원년 황건적의 난)" % hero_id
		).is_true()


# AC-3 — tuning values: enemy_atk_mult 1.50 + chokepoint 4 칸 정확값
# S86 bumped 0.95 → 1.15 after "여전히 너무 쉬움". S88 bumped 1.15 → 1.50
# after user last battle TURN_LIMIT_REACHED DRAW + "전반적으로 난이도가 너무 낮음"
# raw report. 1.50 is the global baseline for ch01-ch25.
func test_ch01_tuning_values_aligned() -> void:
	var ch01: Dictionary = _ch01_record()
	var atk_mult: float = ch01.get("enemy_atk_mult", 0.0) as float
	assert_float(atk_mult).override_failure_message(
		"ch01 enemy_atk_mult != 1.50 (긴장감 tuning regression — S88 baseline)"
	).is_equal_approx(1.50, 0.0001)
	var chokepoints: Array = ch01.get("chokepoints", []) as Array
	assert_int(chokepoints.size()).override_failure_message(
		"ch01 chokepoints size != 4 (도로 4칸 일렬 regression)"
	).is_equal(4)
	var expected_cols: Array[int] = [5, 6, 7, 8]
	for i: int in range(4):
		var cp: Array = chokepoints[i] as Array
		assert_int(cp[0] as int).override_failure_message(
			"chokepoint[%d] col != %d" % [i, expected_cols[i]]
		).is_equal(expected_cols[i])
		assert_int(cp[1] as int).override_failure_message(
			"chokepoint[%d] row != 4" % i
		).is_equal(4)


# AC-4 — branch_table priming-null regression sentinel
# destiny-branch.md CR-13: Ch1 cannot declare echo_threshold or hidden branches.
# 본 spec 은 ch01 의 ★ 추가를 거부 — 이 test 는 그 거부의 mechanical 보증.
func test_ch01_priming_null_branch_table() -> void:
	var ch01: Dictionary = _ch01_record()
	var bt: Dictionary = ch01.get("branch_table", {}) as Dictionary
	var keys: Array = bt.keys()
	keys.sort()
	assert_int(keys.size()).override_failure_message(
		"ch01 branch_table keys size != 2 (priming-null regression — keys: %s)" % str(keys)
	).is_equal(2)
	assert_bool(bt.has("WIN_default")).override_failure_message(
		"ch01 branch_table missing WIN_default"
	).is_true()
	assert_bool(bt.has("LOSS_default")).override_failure_message(
		"ch01 branch_table missing LOSS_default"
	).is_true()
	assert_bool(bt.has("WIN_hidden")).override_failure_message(
		"ch01 acquired WIN_hidden — violates CR-13 priming-null architecture"
	).is_false()
	# echo_threshold MUST be 0 (CR-13 forbids non-zero for Ch1)
	assert_int(ch01.get("echo_threshold", -1) as int).override_failure_message(
		"ch01 echo_threshold != 0 (CR-13 violation)"
	).is_equal(0)


# AC-5 — Beat 8 default-WIN body 가 ch05 seed sentence 의 핵심 어구 포함
func test_ch01_beat8_win_contains_ch05_seed() -> void:
	var story: Dictionary = _load_json_object(STORY_PATH)
	var key: String = "ch01.beat8.win_taoyuan_oath_held"
	assert_bool(story.has(key)).override_failure_message(
		"story_content.json missing key: %s" % key
	).is_true()
	var entry: Dictionary = story[key] as Dictionary
	var body: String = entry.get("body", "") as String
	assert_bool(body.contains("신야의 흙길")).override_failure_message(
		"Beat 8 default-WIN body missing ch05 seed sentence: '신야의 흙길'"
	).is_true()
	assert_bool(body.contains("백성을 지킬 날")).override_failure_message(
		"Beat 8 default-WIN body missing ch05 seed sentence: '백성을 지킬 날'"
	).is_true()
