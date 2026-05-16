## Session-29 — _hydrate_chapter victory_conditions hydration tests.
##
## Covers the new JSON → VictoryConditions mapping in ScenarioRunner. Pre-S29
## the hydrator silently dropped any `victory_conditions` key in chapter JSON;
## post-S29 the field is decoded into a VictoryConditions resource and attached
## to ChapterDefinition.victory_conditions. Null preservation: chapters that
## omit the field continue to get `.victory_conditions = null` (which the
## controller dispatcher reads as ANNIHILATION default).
##
## Coverage:
##   - Omitted field → null (regression-safe for chapters 1-4)
##   - SURVIVE_N_ROUNDS record → VictoryConditions with matching type + rounds
##   - ANNIHILATION record (explicit 0) → VictoryConditions w/ ANNIHILATION
##   - target_unit_ids array → PackedInt64Array round-trip

extends GdUnitTestSuite


# ─── Hydration: field absent ─────────────────────────────────────────────────


## Pre-S29 chapter JSON omitted victory_conditions entirely. The hydrator must
## leave c.victory_conditions = null so the controller defaults to ANNIHILATION.
func test_hydrate_chapter_omitted_victory_conditions_yields_null() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var record: Dictionary = _make_minimal_record()
	# record has NO `victory_conditions` key.

	var chapter: ChapterDefinition = runner._hydrate_chapter(record)

	assert_object(chapter.victory_conditions).override_failure_message(
		"Omitted victory_conditions must yield null (regression: chapters 1-4 unchanged)"
	).is_null()


# ─── Hydration: SURVIVE_N_ROUNDS ─────────────────────────────────────────────


## SURVIVE_N_ROUNDS record produces a VictoryConditions with matching type +
## survive_rounds value.
func test_hydrate_chapter_survive_rounds_record() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var record: Dictionary = _make_minimal_record()
	record["victory_conditions"] = {
		"primary_condition_type": int(VictoryConditions.ConditionType.SURVIVE_N_ROUNDS),
		"survive_rounds": 7,
	}

	var chapter: ChapterDefinition = runner._hydrate_chapter(record)

	assert_object(chapter.victory_conditions).is_not_null()
	assert_int(chapter.victory_conditions.primary_condition_type).override_failure_message(
		"SURVIVE record must hydrate condition_type=SURVIVE_N_ROUNDS"
	).is_equal(int(VictoryConditions.ConditionType.SURVIVE_N_ROUNDS))
	assert_int(chapter.victory_conditions.survive_rounds).is_equal(7)


# ─── Hydration: ANNIHILATION explicit ────────────────────────────────────────


## Explicit ANNIHILATION record (primary_condition_type=0) also hydrates.
## Differs from the omitted-field path: here the resource exists but with
## default-equivalent values. Dispatcher behaves identically either way.
func test_hydrate_chapter_explicit_annihilation_record() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var record: Dictionary = _make_minimal_record()
	record["victory_conditions"] = {
		"primary_condition_type": int(VictoryConditions.ConditionType.ANNIHILATION),
	}

	var chapter: ChapterDefinition = runner._hydrate_chapter(record)

	assert_object(chapter.victory_conditions).is_not_null()
	assert_int(chapter.victory_conditions.primary_condition_type).is_equal(
		int(VictoryConditions.ConditionType.ANNIHILATION)
	)


# ─── Hydration: target_unit_ids round-trip ───────────────────────────────────


## target_unit_ids array → PackedInt64Array. Reserved for ESCORT / REACH_TILE
## but the hydration path is exercised today so future types plug in without
## additional wiring.
func test_hydrate_chapter_target_unit_ids_round_trip() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var record: Dictionary = _make_minimal_record()
	record["victory_conditions"] = {
		"primary_condition_type": 0,
		"target_unit_ids": [3, 7, 12],
	}

	var chapter: ChapterDefinition = runner._hydrate_chapter(record)

	assert_object(chapter.victory_conditions).is_not_null()
	assert_int(chapter.victory_conditions.target_unit_ids.size()).is_equal(3)
	assert_int(chapter.victory_conditions.target_unit_ids[0]).is_equal(3)
	assert_int(chapter.victory_conditions.target_unit_ids[1]).is_equal(7)
	assert_int(chapter.victory_conditions.target_unit_ids[2]).is_equal(12)


# ─── ch05 retrofit verification (smoke) ─────────────────────────────────────


## Session-33 — Production mvp_shu.json ch02 record carries the ESCORT retrofit.
## Verifies the chapter JSON parses + ch02 victory_conditions hydrates correctly.
func test_mvp_shu_ch02_carries_escort_target_0() -> void:
	var json_text: String = FileAccess.get_file_as_string("res://assets/data/scenarios/mvp_shu.json")
	assert_bool(json_text.is_empty()).is_false()
	var parsed: Variant = JSON.parse_string(json_text)
	assert_object(parsed).is_not_null()
	var data: Dictionary = parsed as Dictionary
	var chapters: Array = data["chapters"] as Array
	var ch02_record: Dictionary = {}
	for c: Variant in chapters:
		var d: Dictionary = c as Dictionary
		if (d.get("chapter_id", "") as String) == "ch02_changban_bridge":
			ch02_record = d
			break
	assert_bool(ch02_record.is_empty()).override_failure_message(
		"mvp_shu.json must contain ch02_changban_bridge record"
	).is_false()
	# ESCORT victory_conditions
	assert_bool(ch02_record.has("victory_conditions")).override_failure_message(
		"S33: ch02_changban_bridge must carry victory_conditions block"
	).is_true()
	var vc_data: Dictionary = ch02_record["victory_conditions"] as Dictionary
	assert_int(vc_data["primary_condition_type"] as int).override_failure_message(
		"S33: ch02 must use ESCORT (primary_condition_type=2)"
	).is_equal(int(VictoryConditions.ConditionType.ESCORT))
	var t_ids: Array = vc_data["target_unit_ids"] as Array
	assert_int(t_ids.size()).is_equal(1)
	assert_int(t_ids[0] as int).override_failure_message(
		"S33: ch02 ESCORT target must be 유비 (unit_id=0)"
	).is_equal(0)
	# Default deployment now includes 유비 AND 장비 (S33 unification).
	var player_ids: Array = ch02_record["player_unit_ids"] as Array
	assert_int(player_ids.size()).override_failure_message(
		"S33: ch02 default player_unit_ids must include both 유비 + 장비"
	).is_equal(2)
	var has_player_0: bool = false
	var has_player_1: bool = false
	for pid: Variant in player_ids:
		if (pid as int) == 0:
			has_player_0 = true
		elif (pid as int) == 1:
			has_player_1 = true
	assert_bool(has_player_0).override_failure_message(
		"S33: ch02 default must include 유비 (unit_id=0) — ESCORT target"
	).is_true()
	assert_bool(has_player_1).override_failure_message(
		"S33: ch02 default must include 장비 (unit_id=1)"
	).is_true()
	# branch_overrides for WIN_changbanpo_default removed (now redundant
	# with the unified default deployment — both paths get 유비 + 장비).
	var branch_overrides: Dictionary = ch02_record.get("branch_overrides", {}) as Dictionary
	assert_bool(branch_overrides.has("WIN_changbanpo_default")).override_failure_message(
		"S33: ch02 branch_overrides.WIN_changbanpo_default must be removed (redundant after default unification)"
	).is_false()


## Session-34 — Production mvp_shu.json ch03 record carries the REACH_TILE retrofit.
## Verifies ch03_xiakou_outskirts vc block declares REACH_TILE targeting 유비 (unit 0)
## with target_tile = (13, 4) — the bridge across to 강하 (Xiakou). Different from
## ch02 ESCORT in that REACH_TILE is an ACTIVE win condition (move to tile)
## rather than passive (protect + clear enemies). Mirrors SURVIVE no-shortcut
## semantics: enemy wipeout does NOT shortcut to VICTORY_REACH_TILE.
func test_mvp_shu_ch03_carries_reach_tile_target_13_4() -> void:
	var json_text: String = FileAccess.get_file_as_string("res://assets/data/scenarios/mvp_shu.json")
	assert_bool(json_text.is_empty()).is_false()
	var parsed: Variant = JSON.parse_string(json_text)
	assert_object(parsed).is_not_null()
	var data: Dictionary = parsed as Dictionary
	var chapters: Array = data["chapters"] as Array
	var ch03_record: Dictionary = {}
	for c: Variant in chapters:
		var d: Dictionary = c as Dictionary
		if (d.get("chapter_id", "") as String) == "ch03_xiakou_outskirts":
			ch03_record = d
			break
	assert_bool(ch03_record.is_empty()).override_failure_message(
		"mvp_shu.json must contain ch03_xiakou_outskirts record"
	).is_false()
	# REACH_TILE victory_conditions
	assert_bool(ch03_record.has("victory_conditions")).override_failure_message(
		"S34: ch03_xiakou_outskirts must carry victory_conditions block"
	).is_true()
	var vc_data: Dictionary = ch03_record["victory_conditions"] as Dictionary
	assert_int(vc_data["primary_condition_type"] as int).override_failure_message(
		"S34: ch03 must use REACH_TILE (primary_condition_type=3)"
	).is_equal(int(VictoryConditions.ConditionType.REACH_TILE))
	var t_ids: Array = vc_data["target_unit_ids"] as Array
	assert_int(t_ids.size()).is_equal(1)
	assert_int(t_ids[0] as int).override_failure_message(
		"S34: ch03 REACH_TILE target must be 유비 (unit_id=0)"
	).is_equal(0)
	# target_tile [13, 4] is the bridge crossing to 강하 (per mvp_chapter_03.tres
	# comment: "River on right (col 13) is the escape edge; one bridge tile at
	# [13,4] is the only way across.")
	var tile_arr: Array = vc_data["target_tile"] as Array
	assert_int(tile_arr.size()).override_failure_message(
		"S34: ch03 target_tile must be a 2-element array"
	).is_equal(2)
	assert_int(tile_arr[0] as int).override_failure_message(
		"S34: ch03 target_tile.x must be 13 (bridge column)"
	).is_equal(13)
	assert_int(tile_arr[1] as int).override_failure_message(
		"S34: ch03 target_tile.y must be 4 (bridge row)"
	).is_equal(4)


## Production mvp_shu.json ch05 record carries the SURVIVE_N_ROUNDS=5 retrofit.
## Reads the JSON directly via FileAccess + hydrate the ch05 record to verify
## the wiring end-to-end (catches any JSON syntax breakage at lint time).
func test_mvp_shu_ch05_carries_survive_5_rounds() -> void:
	var json_text: String = FileAccess.get_file_as_string("res://assets/data/scenarios/mvp_shu.json")
	assert_bool(json_text.is_empty()).is_false()
	var parsed: Variant = JSON.parse_string(json_text)
	assert_object(parsed).is_not_null()
	var data: Dictionary = parsed as Dictionary
	var chapters: Array = data["chapters"] as Array
	# Find ch05.
	var ch05_record: Dictionary = {}
	for c: Variant in chapters:
		var d: Dictionary = c as Dictionary
		if (d.get("chapter_id", "") as String) == "ch05_chibi_main":
			ch05_record = d
			break
	assert_bool(ch05_record.is_empty()).override_failure_message(
		"mvp_shu.json must contain ch05_chibi_main record"
	).is_false()
	assert_bool(ch05_record.has("victory_conditions")).override_failure_message(
		"S29: ch05_chibi_main must carry victory_conditions block"
	).is_true()
	var vc_data: Dictionary = ch05_record["victory_conditions"] as Dictionary
	assert_int(vc_data["primary_condition_type"] as int).override_failure_message(
		"S29: ch05 must use SURVIVE_N_ROUNDS (primary_condition_type=1)"
	).is_equal(int(VictoryConditions.ConditionType.SURVIVE_N_ROUNDS))
	assert_int(vc_data["survive_rounds"] as int).is_equal(5)


# ─── Helpers ──────────────────────────────────────────────────────────────────


## Minimal record passing _validate_chapter_record. Doesn't include
## victory_conditions; each test adds it as needed.
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
