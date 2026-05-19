## ScenarioRunner.dev_jump_to_chapter — S62 dev-only chapter teleport API.
##
## Covers:
##   - Valid jump to ch06..ch10 of shu_canon_full + mvp_wei
##   - Out-of-range index refused (state unchanged)
##   - Empty path refused
##   - Bad path refused (load_scenario fault path)
##   - chapter_started fires for chapter_index >= 1 (chapter_index = 0 omits
##     because load_scenario already emitted it during CHAPTER_START auto-advance)
##
## Design note: the method has an `OS.has_feature("debug")` gate. Godot's
## editor binary IS a debug build, so headless test runs satisfy the gate
## automatically (the negative gate test would require an export template).
##
## Uses an isolated ScenarioRunner instance per ScenarioRunnerTestSeam pattern.
extends GdUnitTestSuite


const SHU_PATH: String = "res://assets/data/scenarios/shu_canon_full.json"
const WEI_PATH: String = "res://assets/data/scenarios/mvp_wei.json"


# ─── Happy path: every production chapter is reachable ────────────────────────


func test_dev_jump_lands_at_each_shu_canon_full_chapter() -> void:
	# 25 chapters in shu_canon_full — 영걸전식 풀 캠페인 완성 (도원결의 → 오장원).
	# prequel (ch01~ch05 황건적~신야) + main (ch06~ch10 장판~적벽)
	# + Phase B (ch11~ch14 형주 4군 + 통합) + Phase C (ch15~ch17 익주 입성)
	# + Phase D (ch18~ch22 한중·이릉·시그니처 분기 3개)
	# + Phase E (ch23~ch25 남만·북벌·오장원·영걸전 finale).
	var expected_ids: Array[String] = [
		"ch01_taoyuan_yellow_turban",
		"ch02_hulao_gate",
		"ch03_xuzhou_rescue",
		"ch04_bowang_slope",
		"ch05_xinye_fire",
		"ch06_changbanpo",
		"ch07_changban_bridge",
		"ch08_xiakou_outskirts",
		"ch09_chibi_prelude",
		"ch10_chibi_main",
		"ch11_jingzhou_pacify",
		"ch12_wuling_marsh",
		"ch13_changsha_veteran",
		"ch14_jingzhou_consolidate",
		"ch15_fushui_pass",
		"ch16_luofeng_slope",
		"ch17_chengdu_gates",
		"ch18_hanzhong_advance",
		"ch19_dingjun_peak",
		"ch20_fancheng_pursuit",
		"ch21_zhangfei_avenge",
		"ch22_yiling_burn",
		"ch23_southern_pacify",
		"ch24_jieting_pass",
		"ch25_wuzhang_plains",
	]
	for idx: int in expected_ids.size():
		var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
		auto_free(runner)
		var ok: bool = runner.dev_jump_to_chapter(SHU_PATH, idx)
		assert_bool(ok).override_failure_message(
			"dev_jump_to_chapter(shu_canon_full, %d) must succeed (returned false)" % idx
		).is_true()
		assert_int(runner.get_current_chapter_index()).is_equal(idx)
		var ch: ChapterDefinition = runner.get_current_chapter()
		assert_object(ch).override_failure_message(
			"get_current_chapter() must not be null after dev jump to index %d" % idx
		).is_not_null()
		assert_str(ch.chapter_id).override_failure_message(
			"dev jump to shu_canon_full[%d] landed on '%s', expected '%s'"
				% [idx, ch.chapter_id, expected_ids[idx]]
		).is_equal(expected_ids[idx])


func test_dev_jump_lands_at_each_mvp_wei_chapter() -> void:
	# 5 chapters in mvp_wei: ch01_bowang_slope .. ch05_chibi_burn.
	var expected_ids: Array[String] = [
		"ch01_bowang_slope",
		"ch02_xinye_fire",
		"ch03_changban_pursuit",
		"ch04_jiangling_conquest",
		"ch05_chibi_burn",
	]
	for idx: int in expected_ids.size():
		var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
		auto_free(runner)
		var ok: bool = runner.dev_jump_to_chapter(WEI_PATH, idx)
		assert_bool(ok).override_failure_message(
			"dev_jump_to_chapter(mvp_wei, %d) must succeed (returned false)" % idx
		).is_true()
		assert_int(runner.get_current_chapter_index()).is_equal(idx)
		var ch: ChapterDefinition = runner.get_current_chapter()
		assert_object(ch).is_not_null()
		assert_str(ch.chapter_id).override_failure_message(
			"dev jump to mvp_wei[%d] landed on '%s', expected '%s'"
				% [idx, ch.chapter_id, expected_ids[idx]]
		).is_equal(expected_ids[idx])


# ─── Bad input: refused without state mutation ────────────────────────────────


func test_dev_jump_rejects_empty_scenario_path() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)

	var ok: bool = runner.dev_jump_to_chapter("", 0)

	assert_bool(ok).override_failure_message(
		"dev_jump_to_chapter with empty path must return false"
	).is_false()
	# No scenario loaded → chapter_index stays at sentinel -1.
	assert_int(runner.get_current_chapter_index()).is_equal(-1)


func test_dev_jump_rejects_nonexistent_scenario_path() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)

	var ok: bool = runner.dev_jump_to_chapter(
		"res://assets/data/scenarios/nonexistent_scenario.json", 0
	)

	assert_bool(ok).override_failure_message(
		"dev_jump_to_chapter on missing file must return false (load_scenario fault)"
	).is_false()


func test_dev_jump_rejects_negative_index() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)

	var ok: bool = runner.dev_jump_to_chapter(SHU_PATH, -1)

	assert_bool(ok).override_failure_message(
		"dev_jump_to_chapter with negative index must return false"
	).is_false()


func test_dev_jump_rejects_overflow_index() -> void:
	# Phase E: shu_canon_full has exactly 25 chapters (영걸전식 풀 캠페인 완성), index 25 is out of range.
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)

	var ok: bool = runner.dev_jump_to_chapter(SHU_PATH, 25)

	assert_bool(ok).override_failure_message(
		"dev_jump_to_chapter with index 25 (out of [0, 25)) must return false"
	).is_false()
	# Scenario was loaded (load_scenario succeeded before the range check), so
	# index stays at 0 — the load landed there before the range check rejected.
	assert_int(runner.get_current_chapter_index()).override_failure_message(
		"After rejected overflow jump, runner should still be at the load-default chapter 0"
	).is_equal(0)


# ─── Side effect: chapter_started emit on index >= 1 ──────────────────────────


## Index 0 jumps emit chapter_started exactly once (from load_scenario's
## CHAPTER_START auto-advance), not twice — guards the "no double emit" path.
func test_dev_jump_to_index_0_emits_chapter_started_once() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	# Isolated runner subscribes nothing on GameBus by default; signal will
	# fire on the production /root/GameBus autoload because load_scenario
	# inside the isolated instance routes through GameBus.chapter_started.
	var emits: Array = []
	var capture: Callable = func(chapter_id: String, chapter_number: int) -> void:
		emits.append({"id": chapter_id, "num": chapter_number})
	GameBus.chapter_started.connect(capture)

	var ok: bool = runner.dev_jump_to_chapter(SHU_PATH, 0)

	GameBus.chapter_started.disconnect(capture)
	assert_bool(ok).is_true()
	assert_int(emits.size()).override_failure_message(
		"dev_jump to index 0 emitted chapter_started %d times — expected exactly 1"
			% emits.size()
	).is_equal(1)
	assert_str(emits[0]["id"] as String).is_equal("ch01_taoyuan_yellow_turban")
	assert_int(emits[0]["num"] as int).is_equal(1)


## Index 3 jump emits chapter_started TWICE: once at load_scenario for ch0,
## then again after _chapter_index bump for ch3. This is consistent with the
## restore_from_save_context pattern and intentional — StoryEvent / DestinyState
## subscribers cache the LATEST chapter_started's chapter_id.
func test_dev_jump_to_index_3_emits_chapter_started_for_target_chapter() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var emits: Array = []
	var capture: Callable = func(chapter_id: String, _num: int) -> void:
		emits.append(chapter_id)
	GameBus.chapter_started.connect(capture)

	var ok: bool = runner.dev_jump_to_chapter(WEI_PATH, 3)

	GameBus.chapter_started.disconnect(capture)
	assert_bool(ok).is_true()
	# Last emit must be the target chapter — subscribers use the LATEST cache.
	assert_int(emits.size()).override_failure_message(
		"dev_jump to index 3 emitted chapter_started %d times — expected >= 1"
			% emits.size()
	).is_greater_equal(1)
	assert_str(emits[emits.size() - 1] as String).override_failure_message(
		"Final chapter_started emit must be the target chapter (ch09 of mvp_wei)"
	).is_equal("ch04_jiangling_conquest")


# ─── S69: DEV cascade-state seeding for signature badge + pulse attestation ──


## DEV jump to ch14 (cascade 1번째 합류 — 위연 from ch13 hidden) seeds
## _persistent_branch_flags with the prior signature key + sets pending cascade
## announcement so the badge renders "1/5" + pulse fires on first mount.
func test_dev_jump_to_ch14_seeds_wei_yan_cascade_state() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var ok: bool = runner.dev_jump_to_chapter(SHU_PATH, 13)  # ch14 = index 13
	assert_bool(ok).is_true()
	var flags: PackedStringArray = runner.get_persistent_branch_flags_for_test()
	assert_int(flags.size()).override_failure_message(
		"DEV jump to ch14 expects exactly 1 prior signature flag (위연 ch13 hidden)"
	).is_equal(1)
	assert_bool("WIN_changsha_wei_yan_defects" in flags).is_true()
	var pending: Dictionary = runner.get_pending_cascade_announcement()
	assert_str(pending.get("signature_key", "") as String).is_equal("WIN_changsha_wei_yan_defects")
	assert_str(pending.get("text_key", "") as String).is_equal("ch14.cascade_join.wei_yan")


## DEV jump to ch22 (장비 합류 — accumulates 4 prior cascade signatures:
## 위연 ch13 / 방통 ch16 / 관우 ch20 / 장비 ch21) seeds all 4 flags + sets
## pending announcement to the immediate prior's signature (zhang_fei).
func test_dev_jump_to_ch22_accumulates_four_prior_signature_flags() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var ok: bool = runner.dev_jump_to_chapter(SHU_PATH, 21)  # ch22 = index 21
	assert_bool(ok).is_true()
	var flags: PackedStringArray = runner.get_persistent_branch_flags_for_test()
	assert_int(flags.size()).override_failure_message(
		"DEV jump to ch22 expects 4 prior signature flags (위연/방통/관우/장비)"
	).is_equal(4)
	for expected: String in [
		"WIN_changsha_wei_yan_defects",
		"WIN_luofeng_pang_tong_lives",
		"WIN_fancheng_guan_yu_survives",
		"WIN_zhangfei_survives",
	]:
		assert_bool(expected in flags).override_failure_message(
			"flags must include %s after dev_jump to ch22" % expected
		).is_true()
	var pending: Dictionary = runner.get_pending_cascade_announcement()
	assert_str(pending.get("signature_key", "") as String).is_equal("WIN_zhangfei_survives")


## DEV jump to ch15 (post-cascade chapter with no own cascade_join_prose entry)
## still seeds prior signature flag but does NOT set pending announcement —
## badge shows "1/5 시그니처" without pulse.
func test_dev_jump_to_ch15_seeds_flag_but_no_cascade_announcement() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var ok: bool = runner.dev_jump_to_chapter(SHU_PATH, 14)  # ch15 = index 14
	assert_bool(ok).is_true()
	var flags: PackedStringArray = runner.get_persistent_branch_flags_for_test()
	assert_int(flags.size()).override_failure_message(
		"DEV jump to ch15 inherits 1 prior signature flag from ch13"
	).is_equal(1)
	var pending: Dictionary = runner.get_pending_cascade_announcement()
	assert_bool(pending.is_empty()).override_failure_message(
		"ch15 authored no cascade_join_prose → no pending announcement"
	).is_true()


## DEV jump to ch01 (index 0) returns early without seeding — chapter 0 has no
## prior chapters, no cascade state to seed.
func test_dev_jump_to_ch01_seeds_no_cascade_state() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var ok: bool = runner.dev_jump_to_chapter(SHU_PATH, 0)
	assert_bool(ok).is_true()
	var flags: PackedStringArray = runner.get_persistent_branch_flags_for_test()
	assert_int(flags.size()).is_equal(0)
	var pending: Dictionary = runner.get_pending_cascade_announcement()
	assert_bool(pending.is_empty()).is_true()
