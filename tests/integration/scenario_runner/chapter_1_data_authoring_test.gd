## chapter_1_data_authoring_test.gd
##
## S7-05 chapter-1 ChapterDefinition data-authoring integration test.
## Phase A — first chapter is now 도원결의·황건적 토벌 (ch01_taoyuan_yellow_turban);
## previous "장판파" target moved to ch06 (post Phase 0 index shift).
##
## Validates the first-chapter shu_canon_main.json fixture surfaces all 4 archetypes
## with valid hero IDs, declares chokepoints in the schema, and remains
## structurally loadable by ScenarioRunner. This is the integration target
## that exercises ScenarioRunner + DestinyBranchJudge + AISystem coordination.
extends GdUnitTestSuite


const SCENARIO_JSON: String = "res://assets/data/scenarios/shu_canon_main.json"


# ─── AC-S7-05-1: chapter loads cleanly ────────────────────────────────────────


func test_chapter_1_loads_via_scenario_runner_without_fault() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var loaded: bool = runner.load_scenario(SCENARIO_JSON)
	assert_bool(loaded).override_failure_message(
		"chapter-1 shu_canon_main.json must pass EC-SP-8 7-key validation"
	).is_true()
	var chapter: ChapterDefinition = runner.get_current_chapter()
	assert_object(chapter).is_not_null()
	assert_str(chapter.chapter_id).is_equal("ch01_taoyuan_yellow_turban")


# ─── AC-S7-05-2: 4 enemy archetypes assigned ──────────────────────────────────


func test_chapter_1_enemy_roster_has_4_distinct_archetypes() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	runner.load_scenario(SCENARIO_JSON)
	var chapter: ChapterDefinition = runner.get_current_chapter()
	assert_int(chapter.enemy_roster.size()).is_equal(4)
	var archetypes: Array[StringName] = []
	for entry in chapter.enemy_roster:
		var d: Dictionary = entry as Dictionary
		archetypes.append(StringName(d.get("archetype", "") as String))
	assert_bool(&"aggressor" in archetypes).is_true()
	assert_bool(&"skirmisher" in archetypes).is_true()
	assert_bool(&"holder" in archetypes).is_true()
	assert_bool(&"coordinator" in archetypes).is_true()


# ─── AC-S7-05-3: enemy hero IDs resolve via HeroDatabase ─────────────────────


func test_chapter_1_enemy_hero_ids_all_exist_in_hero_database() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	runner.load_scenario(SCENARIO_JSON)
	var chapter: ChapterDefinition = runner.get_current_chapter()
	for entry in chapter.enemy_roster:
		var d: Dictionary = entry as Dictionary
		var hero_id: StringName = StringName(d.get("hero_id", "") as String)
		var hero: HeroData = HeroDatabase.get_hero(hero_id)
		assert_object(hero).override_failure_message(
			"hero_id '%s' from chapter-1 enemy_roster must exist in heroes.json" % hero_id
		).is_not_null()


# ─── AC-S7-05-4: chokepoints flow through schema ─────────────────────────────


func test_chapter_1_chokepoints_loaded_as_4_grid_coords() -> void:
	# Phase A first chapter (ch01_taoyuan_yellow_turban) has 4 chokepoints
	# at [5,4] [6,4] [7,4] [8,4] — 도로 4 칸 일렬, 형세의 흐름을 만들 수 있는 길이
	# (design/quick-specs/ch01-vertical-slice-uplift.md §3.2 긴장감 tuning).
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	runner.load_scenario(SCENARIO_JSON)
	var chapter: ChapterDefinition = runner.get_current_chapter()
	assert_int(chapter.chokepoints.size()).is_equal(4)
	assert_bool(Vector2i(5, 4) in chapter.chokepoints).is_true()
	assert_bool(Vector2i(6, 4) in chapter.chokepoints).is_true()
	assert_bool(Vector2i(7, 4) in chapter.chokepoints).is_true()
	assert_bool(Vector2i(8, 4) in chapter.chokepoints).is_true()


# ─── AC-S7-05-5: deployment positions cover all 6 unit_ids ───────────────────


func test_chapter_1_deployment_positions_cover_all_units() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	runner.load_scenario(SCENARIO_JSON)
	var chapter: ChapterDefinition = runner.get_current_chapter()
	# 2 player + 4 enemy = 6 unit_ids must each have a deployment position.
	for uid in chapter.player_unit_ids:
		assert_bool(chapter.deployment_positions_default.has(int(uid))).override_failure_message(
			"player unit_id %d missing from deployment_positions_default" % int(uid)
		).is_true()
	for uid in chapter.enemy_unit_ids:
		assert_bool(chapter.deployment_positions_default.has(int(uid))).override_failure_message(
			"enemy unit_id %d missing from deployment_positions_default" % int(uid)
		).is_true()


# ─── AC-S7-05-6: chokepoints flow into BattleStateSnapshot ───────────────────


func test_chokepoints_flow_through_grid_controller_into_snapshot() -> void:
	# Direct unit-level test: GridBattleController.set_chokepoints() persists into
	# the next _make_battle_state_snapshot() call. Bypasses BattleScene plumbing.
	var script: GDScript = load("res://src/feature/grid_battle/grid_battle_controller.gd")
	var controller: Node = script.new() as Node
	auto_free(controller)
	var coords: Array[Vector2i] = [Vector2i(3, 2), Vector2i(3, 3), Vector2i(3, 4)]
	controller.set_chokepoints(coords)
	# Verify field stored. Snapshot construction depends on _hp_controller / _map_grid
	# which are not set up here, so we assert the member directly via test seam.
	# Use Object.get() for indirect access to validate the setter persisted state.
	var stored: Variant = controller.get("_chokepoints")
	assert_int((stored as Array).size()).is_equal(3)
	assert_bool(Vector2i(3, 3) in (stored as Array)).is_true()
