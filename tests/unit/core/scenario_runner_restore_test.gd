## scenario_runner_restore_test.gd
##
## Covers ScenarioRunner.restore_from_save_context() — the MVP-level "이어하기"
## entry point used by MainMenu. Each test uses an isolated runner instance via
## the test seam so it can mutate state without disturbing the production
## /root/ScenarioRunner autoload (which other tests in the same run rely on).
extends GdUnitTestSuite

const SCENARIO_JSON: String = "res://assets/data/scenarios/mvp_shu.json"


func _ctx_for(chapter_id: String, chapter_number: int) -> SaveContext:
	var ctx: SaveContext = SaveContext.new()
	ctx.schema_version = 1
	ctx.slot_id = 1
	ctx.chapter_id = StringName(chapter_id)
	ctx.chapter_number = chapter_number
	ctx.last_cp = 1
	return ctx


func test_null_ctx_returns_false() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	assert_bool(runner.restore_from_save_context(null)).is_false()


func test_empty_chapter_id_returns_false() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var ctx: SaveContext = _ctx_for("", 1)
	assert_bool(runner.restore_from_save_context(ctx)).is_false()


func test_unknown_chapter_id_returns_false() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var ctx: SaveContext = _ctx_for("ch99_phantom", 99)
	assert_bool(runner.restore_from_save_context(ctx)).is_false()


func test_chapter_1_ctx_lands_at_chapter_0_beat_1_anchor() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var ctx: SaveContext = _ctx_for("ch01_changbanpo", 1)
	assert_bool(runner.restore_from_save_context(ctx)).is_true()
	assert_int(runner.get_current_chapter_index()).is_equal(0)
	var state_enum: Dictionary = ScenarioRunnerTestSeam.get_state_enum()
	assert_int(runner.get_state()).is_equal(state_enum["BEAT_1_ANCHOR"] as int)
	assert_str(runner.get_current_chapter().chapter_id).is_equal("ch01_changbanpo")


func test_chapter_2_ctx_jumps_to_chapter_1_index() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var ctx: SaveContext = _ctx_for("ch02_changban_bridge", 2)
	assert_bool(runner.restore_from_save_context(ctx)).is_true()
	assert_int(runner.get_current_chapter_index()).is_equal(1)
	var state_enum: Dictionary = ScenarioRunnerTestSeam.get_state_enum()
	assert_int(runner.get_state()).is_equal(state_enum["BEAT_1_ANCHOR"] as int)
	assert_str(runner.get_current_chapter().chapter_id).is_equal("ch02_changban_bridge")


func test_chapter_3_ctx_jumps_to_chapter_2_index() -> void:
	# ch3 = ch03_xiakou_outskirts at index 2 (added with the ch3 content patch).
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var ctx: SaveContext = _ctx_for("ch03_xiakou_outskirts", 3)
	assert_bool(runner.restore_from_save_context(ctx)).is_true()
	assert_int(runner.get_current_chapter_index()).is_equal(2)
	assert_str(runner.get_current_chapter().chapter_id).is_equal("ch03_xiakou_outskirts")
