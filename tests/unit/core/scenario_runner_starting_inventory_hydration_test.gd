## scenario_runner_starting_inventory_hydration_test.gd
##
## S91 Phase B step 8 — _hydrate_chapter starting_inventory_by_hero hydration.
## Covers JSON → ChapterDefinition.starting_inventory_by_hero mapping per
## strategy-systems.md v0.3 §3.4 + AC-SS-2.
##
## Coverage:
##   - Omitted field → empty Dictionary (regression-safe for chapters 1-16)
##   - Single hero with full inventory → StringName key + Array[StringName] values
##   - Multiple heroes → all hydrated
##   - Empty slot sentinel ("") preserved through StringName coercion
##   - Surplus items beyond INVENTORY_SLOT_COUNT (3) dropped with push_warning
extends GdUnitTestSuite


# ─── Hydration: field absent ─────────────────────────────────────────────────


## Chapters that omit starting_inventory_by_hero keep the field as the
## ChapterDefinition default (empty Dictionary). Regression-safe for every
## chapter authored before Phase B (ch01-ch16 all pre-existing).
func test_hydrate_chapter_omitted_starting_inventory_yields_empty_dict() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var record: Dictionary = _make_minimal_record()
	# record has NO `starting_inventory_by_hero` key.

	var chapter: ChapterDefinition = runner._hydrate_chapter(record)

	assert_bool(chapter.starting_inventory_by_hero.is_empty()).override_failure_message(
		"Omitted starting_inventory_by_hero must yield empty Dictionary (regression "
		+ "safe for chapters 1-16 authored pre-Phase B)"
	).is_true()


# ─── Hydration: single hero entry ────────────────────────────────────────────


## A single-hero record hydrates with the hero_id_string key coerced to
## StringName and the inner Array[String] coerced to Array[StringName].
func test_hydrate_chapter_single_hero_inventory_round_trip() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var record: Dictionary = _make_minimal_record()
	record["starting_inventory_by_hero"] = {
		"shu_001_liu_bei": ["heal_potion", "", ""],
	}

	var chapter: ChapterDefinition = runner._hydrate_chapter(record)

	assert_bool(chapter.starting_inventory_by_hero.has(StringName("shu_001_liu_bei"))).override_failure_message(
		"hydrated dict must hold StringName key (not String) for direct BattleUnit.hero_id lookup"
	).is_true()
	var entry: Array = chapter.starting_inventory_by_hero[&"shu_001_liu_bei"] as Array
	assert_int(entry.size()).is_equal(3)
	assert_str(String(entry[0] as StringName)).is_equal("heal_potion")
	assert_str(String(entry[1] as StringName)).override_failure_message(
		"empty slot sentinel must preserve as StringName(\"\") through coercion"
	).is_equal("")
	assert_str(String(entry[2] as StringName)).is_equal("")


# ─── Hydration: multi-hero entries ───────────────────────────────────────────


## Multi-hero record hydrates every entry. Per-hero inventory contents stay
## independent (no cross-hero leak).
func test_hydrate_chapter_multi_hero_inventory_round_trip() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var record: Dictionary = _make_minimal_record()
	record["starting_inventory_by_hero"] = {
		"shu_001_liu_bei":  ["heal_potion", "", ""],
		"shu_003_zhang_fei": ["heal_potion", "strength_scroll", ""],
		"shu_002_guan_yu":  ["strength_scroll", "march_scroll", "heal_potion"],
	}

	var chapter: ChapterDefinition = runner._hydrate_chapter(record)

	assert_int(chapter.starting_inventory_by_hero.size()).is_equal(3)

	var liu_bei: Array = chapter.starting_inventory_by_hero[&"shu_001_liu_bei"] as Array
	assert_str(String(liu_bei[0] as StringName)).is_equal("heal_potion")
	assert_str(String(liu_bei[1] as StringName)).is_equal("")

	var zhang_fei: Array = chapter.starting_inventory_by_hero[&"shu_003_zhang_fei"] as Array
	assert_str(String(zhang_fei[0] as StringName)).is_equal("heal_potion")
	assert_str(String(zhang_fei[1] as StringName)).is_equal("strength_scroll")

	var guan_yu: Array = chapter.starting_inventory_by_hero[&"shu_002_guan_yu"] as Array
	assert_int(guan_yu.size()).is_equal(3)
	assert_str(String(guan_yu[2] as StringName)).is_equal("heal_potion")


# ─── Hydration: surplus items dropped per EC-SS-1 ────────────────────────────


## A hero authored with > INVENTORY_SLOT_COUNT (3) items gets the surplus
## dropped. push_warning is emitted but is non-fatal (per EC-SS-1: "inventory
## full" — surplus simply discarded).
func test_hydrate_chapter_surplus_items_dropped_to_3_slots() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var record: Dictionary = _make_minimal_record()
	record["starting_inventory_by_hero"] = {
		"shu_003_zhang_fei": [
			"heal_potion", "strength_scroll", "march_scroll", "fire_scroll", "heal_potion",
		],
	}

	var chapter: ChapterDefinition = runner._hydrate_chapter(record)

	var entry: Array = chapter.starting_inventory_by_hero[&"shu_003_zhang_fei"] as Array
	assert_int(entry.size()).override_failure_message(
		"EC-SS-1: surplus items beyond INVENTORY_SLOT_COUNT (3) must be dropped at hydration"
	).is_equal(3)
	# First three preserved; fire_scroll + heal_potion (slots 4 + 5) dropped.
	assert_str(String(entry[0] as StringName)).is_equal("heal_potion")
	assert_str(String(entry[1] as StringName)).is_equal("strength_scroll")
	assert_str(String(entry[2] as StringName)).is_equal("march_scroll")


# ─── Helpers ──────────────────────────────────────────────────────────────────


## Minimal record passing _validate_chapter_record. Mirrors the helper in
## scenario_runner_victory_conditions_hydration_test.gd.
func _make_minimal_record() -> Dictionary:
	return {
		"chapter_id": "test_ch",
		"chapter_number": 1,
		"map_id": "test_map",
		"author_draw_branch": false,
		"echo_threshold": 0,
		"branch_table": {
			"WIN_default":  "WIN_test_default",
			"LOSS_default": "LOSS_test_default",
		},
		"canonical_branch_key": "WIN_test_default",
	}
