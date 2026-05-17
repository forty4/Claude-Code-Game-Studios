## ScenarioRunner.dev_jump_to_chapter — S62 dev-only chapter teleport API.
##
## Covers:
##   - Valid jump to ch06..ch10 of mvp_shu + mvp_wei
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


const SHU_PATH: String = "res://assets/data/scenarios/mvp_shu.json"
const WEI_PATH: String = "res://assets/data/scenarios/mvp_wei.json"


# ─── Happy path: every production chapter is reachable ────────────────────────


func test_dev_jump_lands_at_each_mvp_shu_chapter() -> void:
	# 5 chapters in mvp_shu: ch06_changbanpo .. ch10_chibi_main.
	var expected_ids: Array[String] = [
		"ch06_changbanpo",
		"ch07_changban_bridge",
		"ch08_xiakou_outskirts",
		"ch09_chibi_prelude",
		"ch10_chibi_main",
	]
	for idx: int in expected_ids.size():
		var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
		auto_free(runner)
		var ok: bool = runner.dev_jump_to_chapter(SHU_PATH, idx)
		assert_bool(ok).override_failure_message(
			"dev_jump_to_chapter(mvp_shu, %d) must succeed (returned false)" % idx
		).is_true()
		assert_int(runner.get_current_chapter_index()).is_equal(idx)
		var ch: ChapterDefinition = runner.get_current_chapter()
		assert_object(ch).override_failure_message(
			"get_current_chapter() must not be null after dev jump to index %d" % idx
		).is_not_null()
		assert_str(ch.chapter_id).override_failure_message(
			"dev jump to mvp_shu[%d] landed on '%s', expected '%s'"
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
	# mvp_shu has exactly 5 chapters, so index 5 is out of range.
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)

	var ok: bool = runner.dev_jump_to_chapter(SHU_PATH, 5)

	assert_bool(ok).override_failure_message(
		"dev_jump_to_chapter with index 5 (out of [0, 5)) must return false"
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
	assert_str(emits[0]["id"] as String).is_equal("ch06_changbanpo")
	assert_int(emits[0]["num"] as int).is_equal(6)


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
