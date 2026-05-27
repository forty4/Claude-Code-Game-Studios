## scenario_runner_strategy_snapshot_test.gd
##
## S91 Phase B step 8b follow-up — exercises ScenarioRunner._make_save_context
## populating SaveContext.per_hero_inventory_snapshot +
## per_hero_pending_buff_snapshot via the new
## _collect_active_battle_strategy_snapshot helper that pulls from
## SceneManager._battle_scene_ref.
##
## Test seam discipline:
##   - SceneManager._battle_scene_ref is restored to its prior value in
##     after_test to keep test isolation per G-28.
##   - A minimal fake BattleScene-like Node injected for the populated-path
##     test, supplying get_per_unit_strategy_snapshot() with deterministic
##     fixture data.
extends GdUnitTestSuite

const FakeBattleSceneScript: GDScript = preload("res://tests/helpers/fake_battle_scene_with_snapshot.gd")


var _prior_battle_scene_ref: Node


func before_test() -> void:
	# Capture prior _battle_scene_ref so we restore on after_test.
	_prior_battle_scene_ref = SceneManager._battle_scene_ref


func after_test() -> void:
	# Restore so other tests in the same suite session don't see our injection.
	SceneManager._battle_scene_ref = _prior_battle_scene_ref


# ─── Populate path: BattleScene present, snapshot pulled into SaveContext ─────


## When SceneManager has an active battle_scene_ref exposing
## get_per_unit_strategy_snapshot(), _make_save_context pulls that data into
## ctx.per_hero_inventory_snapshot + per_hero_pending_buff_snapshot.
func test_make_save_context_populates_snapshots_from_active_battle_scene() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	# Fake battle scene with known snapshot data
	var fake: Node = FakeBattleSceneScript.new()
	auto_free(fake)
	fake.fixture_inventory_snapshot = {
		1: [&"heal_potion", &"strength_scroll", &""] as Array[StringName],
		2: [&"fire_scroll", &"", &""] as Array[StringName],
	}
	fake.fixture_pending_buff_snapshot = {
		1: {&"kind": &"strength", &"magnitude": 1.5, &"expires_at_turn": 3},
	}
	SceneManager._battle_scene_ref = fake

	var ctx: SaveContext = runner._make_save_context(runner.SaveCheckpoint.CP_2)

	# Inventory snapshot pulled from fake
	assert_int(ctx.per_hero_inventory_snapshot.size()).override_failure_message(
		"step 8b follow-up: _make_save_context must populate inventory_snapshot from active battle"
	).is_equal(2)
	var inv_1: Array = ctx.per_hero_inventory_snapshot[1] as Array
	assert_str(String(inv_1[0] as StringName)).is_equal("heal_potion")
	# Pending buff snapshot pulled
	assert_int(ctx.per_hero_pending_buff_snapshot.size()).is_equal(1)
	var buff_1: Dictionary = ctx.per_hero_pending_buff_snapshot[1] as Dictionary
	assert_str(String(buff_1.get(&"kind", &"") as StringName)).is_equal("strength")


# ─── No-battle path: SceneManager._battle_scene_ref null, snapshots stay empty ─


## When SceneManager has no active battle scene (CP_1 chapter start, CP_3
## scenario transition, fresh game start), snapshots remain at the SaveContext
## default empty Dictionary.
func test_make_save_context_leaves_snapshots_empty_when_no_battle_scene() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	SceneManager._battle_scene_ref = null

	var ctx: SaveContext = runner._make_save_context(runner.SaveCheckpoint.CP_1)

	assert_bool(ctx.per_hero_inventory_snapshot.is_empty()).override_failure_message(
		"step 8b follow-up: no active battle scene → inventory_snapshot stays empty"
	).is_true()
	assert_bool(ctx.per_hero_pending_buff_snapshot.is_empty()).override_failure_message(
		"step 8b follow-up: no active battle scene → pending_buff_snapshot stays empty"
	).is_true()


# ─── Defensive: battle scene present but missing helper method ───────────────


## When SceneManager._battle_scene_ref points at a node that doesn't expose
## get_per_unit_strategy_snapshot (e.g. test stubs that bypass BattleScene),
## _make_save_context silently leaves snapshots empty — no crash, no error.
func test_make_save_context_handles_battle_scene_without_snapshot_method() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	# Bare Node has no get_per_unit_strategy_snapshot method.
	var bare: Node = Node.new()
	auto_free(bare)
	SceneManager._battle_scene_ref = bare

	var ctx: SaveContext = runner._make_save_context(runner.SaveCheckpoint.CP_2)

	# Defensive empty
	assert_bool(ctx.per_hero_inventory_snapshot.is_empty()).is_true()
	assert_bool(ctx.per_hero_pending_buff_snapshot.is_empty()).is_true()
