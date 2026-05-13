## battle_scene_enemy_atk_mult_test.gd
##
## Verifies the per-chapter ENEMY_ATK_MULT override pipeline.
##
##   - ChapterDefinition.enemy_atk_mult defaults to -1.0 (sentinel = unset).
##   - ScenarioRunner._hydrate_chapter pulls the value from JSON when present.
##   - BattleScene._resolve_enemy_atk_mult prefers the chapter override when
##     in [0.0, 2.0]; falls back to BalanceConstants.ENEMY_ATK_MULT otherwise.
##   - Out-of-range overrides fall back to the global without crashing
##     (defensive against JSON typos).
##
## Companion to battle_scene_unit_class_propagation_test.gd — same instantiation
## pattern (BattleSceneScript.new() without scene-tree mount).
extends GdUnitTestSuite

const BattleSceneScript: GDScript = preload("res://src/feature/battle_scene/battle_scene.gd")
const ScenarioRunnerScript: GDScript = preload("res://src/core/scenario_runner.gd")


func _instantiate_battle_scene() -> BattleScene:
	var scene: BattleScene = BattleSceneScript.new()
	auto_free(scene)
	return scene


# ─── ChapterDefinition default ────────────────────────────────────────────────


func test_chapter_definition_enemy_atk_mult_defaults_to_sentinel() -> void:
	var chapter: ChapterDefinition = ChapterDefinition.new()
	assert_float(chapter.enemy_atk_mult).override_failure_message(
		"Default must be -1.0 sentinel so BattleScene falls back to global; got %.3f" % chapter.enemy_atk_mult
	).is_equal(-1.0)


# ─── ScenarioRunner._hydrate_chapter ──────────────────────────────────────────


func test_hydrate_chapter_omits_field_yields_sentinel() -> void:
	var runner: Node = ScenarioRunnerScript.new()
	auto_free(runner)
	var record: Dictionary = {"chapter_id": "ch_test", "chapter_number": 1, "map_id": "m"}
	var hydrated: ChapterDefinition = runner._hydrate_chapter(record)
	assert_float(hydrated.enemy_atk_mult).is_equal(-1.0)


func test_hydrate_chapter_reads_explicit_float() -> void:
	var runner: Node = ScenarioRunnerScript.new()
	auto_free(runner)
	var record: Dictionary = {
		"chapter_id": "ch_test",
		"chapter_number": 1,
		"map_id": "m",
		"enemy_atk_mult": 0.85,
	}
	var hydrated: ChapterDefinition = runner._hydrate_chapter(record)
	assert_float(hydrated.enemy_atk_mult).is_equal_approx(0.85, 0.0001)


func test_hydrate_chapter_coerces_int_to_float() -> void:
	# JSON parsing may yield int when the value is written without a decimal.
	# Float cast in _hydrate_chapter handles both shapes.
	var runner: Node = ScenarioRunnerScript.new()
	auto_free(runner)
	var record: Dictionary = {
		"chapter_id": "ch_test",
		"chapter_number": 1,
		"map_id": "m",
		"enemy_atk_mult": 1,
	}
	var hydrated: ChapterDefinition = runner._hydrate_chapter(record)
	assert_float(hydrated.enemy_atk_mult).is_equal_approx(1.0, 0.0001)


# ─── BattleScene._resolve_enemy_atk_mult ──────────────────────────────────────
#
# _resolve_enemy_atk_mult queries ScenarioRunner.get_current_chapter() at call
# time. The headless test environment uses the real autoload, so we exercise
# the static fallback path (no scenario loaded → null chapter → global) here.
# The per-chapter happy path is exercised indirectly via the hydration tests
# above + the unit_class propagation tests' chapter-1 roster build.


func test_resolve_enemy_atk_mult_falls_back_to_global_when_no_chapter_loaded() -> void:
	# After /clear or fresh test boot, ScenarioRunner.get_current_chapter() returns
	# null. Resolver must return the global BalanceConstants value (currently 0.7).
	var scene: BattleScene = _instantiate_battle_scene()
	var global_mul: float = BalanceConstants.get_const("ENEMY_ATK_MULT") as float
	# Reset ScenarioRunner so get_current_chapter() returns null deterministically.
	var runner: Node = get_node_or_null("/root/ScenarioRunner")
	if runner != null and runner.has_method("reset_for_tests"):
		runner.reset_for_tests()
	var resolved: float = scene._resolve_enemy_atk_mult()
	assert_float(resolved).override_failure_message(
		"No chapter loaded → resolver must return BalanceConstants.ENEMY_ATK_MULT (%.3f); got %.3f"
		% [global_mul, resolved]
	).is_equal_approx(global_mul, 0.0001)
