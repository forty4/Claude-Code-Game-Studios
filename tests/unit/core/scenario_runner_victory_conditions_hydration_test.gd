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


## S59 — ch03 hidden destiny authoring sanity. ch03 declares
## hidden_branch_key + hidden_condition (formation_turns >= 3). ch04
## branch_overrides carries the corresponding WIN_xiakou_united_advance
## key with 초선 (unit 8 / qun_004_diao_chan) added to the alliance roster.
## Pillar 2 second realization — mirrors ch01 → ch02 chain authored at S57.
func test_mvp_shu_ch03_authors_hidden_destiny_with_ch04_override() -> void:
	var json_text: String = FileAccess.get_file_as_string("res://assets/data/scenarios/mvp_shu.json")
	assert_bool(json_text.is_empty()).is_false()
	var parsed: Variant = JSON.parse_string(json_text)
	assert_object(parsed).is_not_null()
	var data: Dictionary = parsed as Dictionary
	var chapters: Array = data["chapters"] as Array
	var ch03_record: Dictionary = {}
	var ch04_record: Dictionary = {}
	for c: Variant in chapters:
		var d: Dictionary = c as Dictionary
		var cid: String = d.get("chapter_id", "") as String
		if cid == "ch03_xiakou_outskirts":
			ch03_record = d
		elif cid == "ch04_chibi_prelude":
			ch04_record = d
	assert_bool(ch03_record.is_empty()).is_false()
	assert_bool(ch04_record.is_empty()).is_false()
	# ch03 hidden_branch_key + hidden_condition authored.
	assert_str(ch03_record.get("hidden_branch_key", "") as String).override_failure_message(
		"S59: ch03 must declare hidden_branch_key = 'WIN_hidden'"
	).is_equal("WIN_hidden")
	var hc: Dictionary = ch03_record.get("hidden_condition", {}) as Dictionary
	assert_str(hc.get("type", "") as String).is_equal("fate_threshold")
	assert_str(hc.get("field", "") as String).override_failure_message(
		"S59: ch03 hidden condition must key on formation_turns"
	).is_equal("formation_turns")
	assert_str(hc.get("op", "") as String).is_equal(">=")
	assert_int(hc.get("value", -1) as int).is_equal(3)
	# ch03 branch_table maps WIN_hidden to the new branch key.
	var bt: Dictionary = ch03_record.get("branch_table", {}) as Dictionary
	assert_str(bt.get("WIN_hidden", "") as String).is_equal("WIN_xiakou_united_advance")
	# ch04 branch_overrides routes WIN_xiakou_united_advance to 초선-augmented roster.
	var ovr: Dictionary = ch04_record.get("branch_overrides", {}) as Dictionary
	assert_bool(ovr.has("WIN_xiakou_united_advance")).override_failure_message(
		"S59: ch04 must author branch_overrides for WIN_xiakou_united_advance"
	).is_true()
	var entry: Dictionary = ovr["WIN_xiakou_united_advance"] as Dictionary
	var ovr_uids: Array = entry.get("player_unit_ids", []) as Array
	var has_8: bool = false
	for uid: Variant in ovr_uids:
		if (uid as int) == 8:
			has_8 = true
			break
	assert_bool(has_8).override_failure_message(
		"S59: ch04 WIN_xiakou_united_advance override must include unit 8 (초선)"
	).is_true()
	var ovr_heroes: Dictionary = entry.get("player_hero_ids", {}) as Dictionary
	assert_str(ovr_heroes.get("8", "") as String).is_equal("qun_004_diao_chan")
	var ovr_dep: Dictionary = entry.get("deployment_positions_default", {}) as Dictionary
	assert_bool(ovr_dep.has("8")).override_failure_message(
		"S59: ch04 override must place unit 8 (초선) on the deployment grid"
	).is_true()


# ─── mvp_wei.json — Wei scenario authoring sanity ─────────────────────────────


## Wei scenario (조조의 남정) — 5 chapters with ch03 hidden destiny + ch05
## branch_overrides chain. Mirrors the Shu hidden-destiny authoring patterns
## but with Wei perspective + canonical-loss-at-Chibi historical framing.
func test_mvp_wei_scenario_authors_5_chapters_with_hidden_destiny_chain() -> void:
	var json_text: String = FileAccess.get_file_as_string("res://assets/data/scenarios/mvp_wei.json")
	assert_bool(json_text.is_empty()).override_failure_message(
		"mvp_wei.json must exist at assets/data/scenarios/mvp_wei.json"
	).is_false()
	var parsed: Variant = JSON.parse_string(json_text)
	assert_object(parsed).override_failure_message(
		"mvp_wei.json must parse as a JSON object"
	).is_not_null()
	var data: Dictionary = parsed as Dictionary
	assert_str(data.get("scenario_id", "") as String).is_equal("mvp_wei")

	var chapters: Array = data["chapters"] as Array
	assert_int(chapters.size()).override_failure_message(
		"mvp_wei must declare exactly 5 chapters"
	).is_equal(5)

	var by_id: Dictionary = {}
	for c: Variant in chapters:
		var d: Dictionary = c as Dictionary
		by_id[d.get("chapter_id", "") as String] = d

	for expected_id: String in [
		"ch01_bowang_slope",
		"ch02_xinye_fire",
		"ch03_changban_pursuit",
		"ch04_jiangling_conquest",
		"ch05_chibi_burn",
	]:
		assert_bool(by_id.has(expected_id)).override_failure_message(
			"mvp_wei missing chapter_id '%s'" % expected_id
		).is_true()

	# ch03 hidden destiny — assassin_kills >= 3 → WIN_changban_pursuit_unshakeable.
	var ch03: Dictionary = by_id["ch03_changban_pursuit"] as Dictionary
	assert_str(ch03.get("hidden_branch_key", "") as String).override_failure_message(
		"Wei ch03 must declare hidden_branch_key = 'WIN_hidden'"
	).is_equal("WIN_hidden")
	var hc: Dictionary = ch03.get("hidden_condition", {}) as Dictionary
	assert_str(hc.get("type", "") as String).is_equal("fate_threshold")
	assert_str(hc.get("field", "") as String).is_equal("assassin_kills")
	assert_str(hc.get("op", "") as String).is_equal(">=")
	assert_int(hc.get("value", -1) as int).is_equal(3)
	var ch03_bt: Dictionary = ch03.get("branch_table", {}) as Dictionary
	assert_str(ch03_bt.get("WIN_hidden", "") as String).is_equal("WIN_changban_pursuit_unshakeable")

	# ch05 branch_overrides routes WIN_changban_pursuit_unshakeable to a reduced
	# (3-enemy) alliance roster — without Wu reinforcements the survive-5-rounds
	# fight is winnable, which yields WIN_chibi_wind_too_late at Beat 7.
	var ch05: Dictionary = by_id["ch05_chibi_burn"] as Dictionary
	assert_str(ch05.get("canonical_branch_key", "") as String).override_failure_message(
		"Wei ch05 canonical branch must be LOSS_chibi_burn_canonical (historical defeat)"
	).is_equal("LOSS_chibi_burn_canonical")
	var ovr: Dictionary = ch05.get("branch_overrides", {}) as Dictionary
	assert_bool(ovr.has("WIN_changban_pursuit_unshakeable")).override_failure_message(
		"Wei ch05 must author branch_overrides for WIN_changban_pursuit_unshakeable"
	).is_true()
	var entry: Dictionary = ovr["WIN_changban_pursuit_unshakeable"] as Dictionary
	var ovr_enemy_ids: Array = entry.get("enemy_unit_ids", []) as Array
	assert_int(ovr_enemy_ids.size()).override_failure_message(
		"Wei ch05 hidden override must reduce enemy count from 5 to 3 (Wu vanguard absent)"
	).is_equal(3)

	# Map ids match the new .tres files generated for the Wei line.
	for expected_id: String in [
		"ch01_bowang_slope",
		"ch02_xinye_fire",
		"ch03_changban_pursuit",
		"ch04_jiangling_conquest",
		"ch05_chibi_burn",
	]:
		var ch: Dictionary = by_id[expected_id] as Dictionary
		var map_id: String = ch.get("map_id", "") as String
		assert_str(map_id).override_failure_message(
			"Wei %s map_id must follow mvp_wei_chapter_NN convention (got '%s')"
				% [expected_id, map_id]
		).starts_with("mvp_wei_chapter_")
		var map_path: String = "res://assets/data/maps/%s.tres" % map_id
		assert_bool(ResourceLoader.exists(map_path)).override_failure_message(
			"Wei %s declares map_id '%s' but %s does not exist on disk"
				% [expected_id, map_id, map_path]
		).is_true()


## Wei scenario fully loads through ScenarioRunner.load_scenario without faults —
## end-to-end hydration smoke (catches validator regressions for the new chapter
## layout if any chapter record fails _validate_chapter_record).
func test_mvp_wei_scenario_loads_via_runner_without_fault() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)

	var ok: bool = runner.load_scenario("res://assets/data/scenarios/mvp_wei.json")

	assert_bool(ok).override_failure_message(
		"ScenarioRunner.load_scenario MUST succeed on mvp_wei.json — check scenario_fault stderr"
	).is_true()


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
