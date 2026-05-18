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


# ─── ch10 retrofit verification (smoke) ─────────────────────────────────────


## Session-33 — Production mvp_shu.json ch07 record carries the ESCORT retrofit.
## Verifies the chapter JSON parses + ch07 victory_conditions hydrates correctly.
func test_mvp_shu_ch02_carries_escort_target_0() -> void:
	var json_text: String = FileAccess.get_file_as_string("res://assets/data/scenarios/mvp_shu.json")
	assert_bool(json_text.is_empty()).is_false()
	var parsed: Variant = JSON.parse_string(json_text)
	assert_object(parsed).is_not_null()
	var data: Dictionary = parsed as Dictionary
	var chapters: Array = data["chapters"] as Array
	var ch07_record: Dictionary = {}
	for c: Variant in chapters:
		var d: Dictionary = c as Dictionary
		if (d.get("chapter_id", "") as String) == "ch07_changban_bridge":
			ch07_record = d
			break
	assert_bool(ch07_record.is_empty()).override_failure_message(
		"mvp_shu.json must contain ch07_changban_bridge record"
	).is_false()
	# ESCORT victory_conditions
	assert_bool(ch07_record.has("victory_conditions")).override_failure_message(
		"S33: ch07_changban_bridge must carry victory_conditions block"
	).is_true()
	var vc_data: Dictionary = ch07_record["victory_conditions"] as Dictionary
	assert_int(vc_data["primary_condition_type"] as int).override_failure_message(
		"S33: ch07 must use ESCORT (primary_condition_type=2)"
	).is_equal(int(VictoryConditions.ConditionType.ESCORT))
	var t_ids: Array = vc_data["target_unit_ids"] as Array
	assert_int(t_ids.size()).is_equal(1)
	assert_int(t_ids[0] as int).override_failure_message(
		"S33: ch07 ESCORT target must be 유비 (unit_id=0)"
	).is_equal(0)
	# Default deployment now includes 유비 AND 장비 (S33 unification).
	var player_ids: Array = ch07_record["player_unit_ids"] as Array
	assert_int(player_ids.size()).override_failure_message(
		"S33: ch07 default player_unit_ids must include both 유비 + 장비"
	).is_equal(2)
	var has_player_0: bool = false
	var has_player_1: bool = false
	for pid: Variant in player_ids:
		if (pid as int) == 0:
			has_player_0 = true
		elif (pid as int) == 1:
			has_player_1 = true
	assert_bool(has_player_0).override_failure_message(
		"S33: ch07 default must include 유비 (unit_id=0) — ESCORT target"
	).is_true()
	assert_bool(has_player_1).override_failure_message(
		"S33: ch07 default must include 장비 (unit_id=1)"
	).is_true()
	# branch_overrides for WIN_changbanpo_default removed (now redundant
	# with the unified default deployment — both paths get 유비 + 장비).
	var branch_overrides: Dictionary = ch07_record.get("branch_overrides", {}) as Dictionary
	assert_bool(branch_overrides.has("WIN_changbanpo_default")).override_failure_message(
		"S33: ch07 branch_overrides.WIN_changbanpo_default must be removed (redundant after default unification)"
	).is_false()


## Session-34 — Production mvp_shu.json ch08 record carries the REACH_TILE retrofit.
## Verifies ch08_xiakou_outskirts vc block declares REACH_TILE targeting 유비 (unit 0)
## with target_tile = (13, 4) — the bridge across to 강하 (Xiakou). Different from
## ch07 ESCORT in that REACH_TILE is an ACTIVE win condition (move to tile)
## rather than passive (protect + clear enemies). Mirrors SURVIVE no-shortcut
## semantics: enemy wipeout does NOT shortcut to VICTORY_REACH_TILE.
func test_mvp_shu_ch03_carries_reach_tile_target_13_4() -> void:
	var json_text: String = FileAccess.get_file_as_string("res://assets/data/scenarios/mvp_shu.json")
	assert_bool(json_text.is_empty()).is_false()
	var parsed: Variant = JSON.parse_string(json_text)
	assert_object(parsed).is_not_null()
	var data: Dictionary = parsed as Dictionary
	var chapters: Array = data["chapters"] as Array
	var ch08_record: Dictionary = {}
	for c: Variant in chapters:
		var d: Dictionary = c as Dictionary
		if (d.get("chapter_id", "") as String) == "ch08_xiakou_outskirts":
			ch08_record = d
			break
	assert_bool(ch08_record.is_empty()).override_failure_message(
		"mvp_shu.json must contain ch08_xiakou_outskirts record"
	).is_false()
	# REACH_TILE victory_conditions
	assert_bool(ch08_record.has("victory_conditions")).override_failure_message(
		"S34: ch08_xiakou_outskirts must carry victory_conditions block"
	).is_true()
	var vc_data: Dictionary = ch08_record["victory_conditions"] as Dictionary
	assert_int(vc_data["primary_condition_type"] as int).override_failure_message(
		"S34: ch08 must use REACH_TILE (primary_condition_type=3)"
	).is_equal(int(VictoryConditions.ConditionType.REACH_TILE))
	var t_ids: Array = vc_data["target_unit_ids"] as Array
	assert_int(t_ids.size()).is_equal(1)
	assert_int(t_ids[0] as int).override_failure_message(
		"S34: ch08 REACH_TILE target must be 유비 (unit_id=0)"
	).is_equal(0)
	# target_tile [13, 4] is the bridge crossing to 강하 (per mvp_chapter_08.tres
	# comment: "River on right (col 13) is the escape edge; one bridge tile at
	# [13,4] is the only way across.")
	var tile_arr: Array = vc_data["target_tile"] as Array
	assert_int(tile_arr.size()).override_failure_message(
		"S34: ch08 target_tile must be a 2-element array"
	).is_equal(2)
	assert_int(tile_arr[0] as int).override_failure_message(
		"S34: ch08 target_tile.x must be 13 (bridge column)"
	).is_equal(13)
	assert_int(tile_arr[1] as int).override_failure_message(
		"S34: ch08 target_tile.y must be 4 (bridge row)"
	).is_equal(4)


## Production mvp_shu.json ch10 record carries the SURVIVE_N_ROUNDS=5 retrofit.
## Reads the JSON directly via FileAccess + hydrate the ch10 record to verify
## the wiring end-to-end (catches any JSON syntax breakage at lint time).
func test_mvp_shu_ch05_carries_survive_5_rounds() -> void:
	var json_text: String = FileAccess.get_file_as_string("res://assets/data/scenarios/mvp_shu.json")
	assert_bool(json_text.is_empty()).is_false()
	var parsed: Variant = JSON.parse_string(json_text)
	assert_object(parsed).is_not_null()
	var data: Dictionary = parsed as Dictionary
	var chapters: Array = data["chapters"] as Array
	# Find ch10.
	var ch10_record: Dictionary = {}
	for c: Variant in chapters:
		var d: Dictionary = c as Dictionary
		if (d.get("chapter_id", "") as String) == "ch10_chibi_main":
			ch10_record = d
			break
	assert_bool(ch10_record.is_empty()).override_failure_message(
		"mvp_shu.json must contain ch10_chibi_main record"
	).is_false()
	assert_bool(ch10_record.has("victory_conditions")).override_failure_message(
		"S29: ch10_chibi_main must carry victory_conditions block"
	).is_true()
	var vc_data: Dictionary = ch10_record["victory_conditions"] as Dictionary
	assert_int(vc_data["primary_condition_type"] as int).override_failure_message(
		"S29: ch10 must use SURVIVE_N_ROUNDS (primary_condition_type=1)"
	).is_equal(int(VictoryConditions.ConditionType.SURVIVE_N_ROUNDS))
	assert_int(vc_data["survive_rounds"] as int).is_equal(5)


## S59 — ch08 hidden destiny authoring sanity. ch08 declares
## hidden_branch_key + hidden_condition (formation_turns >= 3). ch09
## branch_overrides carries the corresponding WIN_xiakou_united_advance
## key with 초선 (unit 8 / qun_004_diao_chan) added to the alliance roster.
## Pillar 2 second realization — mirrors ch06 → ch07 chain authored at S57.
func test_mvp_shu_ch03_authors_hidden_destiny_with_ch04_override() -> void:
	var json_text: String = FileAccess.get_file_as_string("res://assets/data/scenarios/mvp_shu.json")
	assert_bool(json_text.is_empty()).is_false()
	var parsed: Variant = JSON.parse_string(json_text)
	assert_object(parsed).is_not_null()
	var data: Dictionary = parsed as Dictionary
	var chapters: Array = data["chapters"] as Array
	var ch08_record: Dictionary = {}
	var ch09_record: Dictionary = {}
	for c: Variant in chapters:
		var d: Dictionary = c as Dictionary
		var cid: String = d.get("chapter_id", "") as String
		if cid == "ch08_xiakou_outskirts":
			ch08_record = d
		elif cid == "ch09_chibi_prelude":
			ch09_record = d
	assert_bool(ch08_record.is_empty()).is_false()
	assert_bool(ch09_record.is_empty()).is_false()
	# ch08 hidden_branch_key + hidden_condition authored.
	assert_str(ch08_record.get("hidden_branch_key", "") as String).override_failure_message(
		"S59: ch08 must declare hidden_branch_key = 'WIN_hidden'"
	).is_equal("WIN_hidden")
	var hc: Dictionary = ch08_record.get("hidden_condition", {}) as Dictionary
	assert_str(hc.get("type", "") as String).is_equal("fate_threshold")
	assert_str(hc.get("field", "") as String).override_failure_message(
		"S59: ch08 hidden condition must key on formation_turns"
	).is_equal("formation_turns")
	assert_str(hc.get("op", "") as String).is_equal(">=")
	assert_int(hc.get("value", -1) as int).is_equal(3)
	# ch08 branch_table maps WIN_hidden to the new branch key.
	var bt: Dictionary = ch08_record.get("branch_table", {}) as Dictionary
	assert_str(bt.get("WIN_hidden", "") as String).is_equal("WIN_xiakou_united_advance")
	# ch09 branch_overrides routes WIN_xiakou_united_advance to 초선-augmented roster.
	var ovr: Dictionary = ch09_record.get("branch_overrides", {}) as Dictionary
	assert_bool(ovr.has("WIN_xiakou_united_advance")).override_failure_message(
		"S59: ch09 must author branch_overrides for WIN_xiakou_united_advance"
	).is_true()
	var entry: Dictionary = ovr["WIN_xiakou_united_advance"] as Dictionary
	var ovr_uids: Array = entry.get("player_unit_ids", []) as Array
	var has_8: bool = false
	for uid: Variant in ovr_uids:
		if (uid as int) == 8:
			has_8 = true
			break
	assert_bool(has_8).override_failure_message(
		"S59: ch09 WIN_xiakou_united_advance override must include unit 8 (초선)"
	).is_true()
	var ovr_heroes: Dictionary = entry.get("player_hero_ids", {}) as Dictionary
	assert_str(ovr_heroes.get("8", "") as String).is_equal("qun_004_diao_chan")
	var ovr_dep: Dictionary = entry.get("deployment_positions_default", {}) as Dictionary
	assert_bool(ovr_dep.has("8")).override_failure_message(
		"S59: ch09 override must place unit 8 (초선) on the deployment grid"
	).is_true()


# ─── mvp_wei.json — Wei scenario authoring sanity ─────────────────────────────


## Wei scenario (조조의 남정) — 5 chapters with ch08 hidden destiny + ch10
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

	# ch08 hidden destiny — assassin_kills >= 3 → WIN_changban_pursuit_unshakeable.
	var ch08: Dictionary = by_id["ch03_changban_pursuit"] as Dictionary
	assert_str(ch08.get("hidden_branch_key", "") as String).override_failure_message(
		"Wei ch08 must declare hidden_branch_key = 'WIN_hidden'"
	).is_equal("WIN_hidden")
	var hc: Dictionary = ch08.get("hidden_condition", {}) as Dictionary
	assert_str(hc.get("type", "") as String).is_equal("fate_threshold")
	assert_str(hc.get("field", "") as String).is_equal("assassin_kills")
	assert_str(hc.get("op", "") as String).is_equal(">=")
	assert_int(hc.get("value", -1) as int).is_equal(3)
	var ch08_bt: Dictionary = ch08.get("branch_table", {}) as Dictionary
	assert_str(ch08_bt.get("WIN_hidden", "") as String).is_equal("WIN_changban_pursuit_unshakeable")

	# ch10 branch_overrides routes WIN_changban_pursuit_unshakeable to a reduced
	# (3-enemy) alliance roster — without Wu reinforcements the survive-5-rounds
	# fight is winnable, which yields WIN_chibi_wind_too_late at Beat 7.
	var ch10: Dictionary = by_id["ch05_chibi_burn"] as Dictionary
	assert_str(ch10.get("canonical_branch_key", "") as String).override_failure_message(
		"Wei ch10 canonical branch must be LOSS_chibi_burn_canonical (historical defeat)"
	).is_equal("LOSS_chibi_burn_canonical")
	var ovr: Dictionary = ch10.get("branch_overrides", {}) as Dictionary
	assert_bool(ovr.has("WIN_changban_pursuit_unshakeable")).override_failure_message(
		"Wei ch10 must author branch_overrides for WIN_changban_pursuit_unshakeable"
	).is_true()
	var entry: Dictionary = ovr["WIN_changban_pursuit_unshakeable"] as Dictionary
	var ovr_enemy_ids: Array = entry.get("enemy_unit_ids", []) as Array
	assert_int(ovr_enemy_ids.size()).override_failure_message(
		"Wei ch10 hidden override must reduce enemy count from 5 to 3 (Wu vanguard absent)"
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


# ─── Phase B (mvp_shu ch11~ch14) — 형주 4군 평정 + 통합 authoring sanity ────────


## Phase B regression sentinel — mvp_shu must declare exactly 14 chapters
## (Phase A prequel ch01~ch05 + main ch06~ch10 + Phase B 형주 ch11~ch14).
## ch13 hidden destiny (wei_yan_spared_turns ≥ 3) + ch14 branch_overrides chain
## mirror the영걸전 시그니처 위연 합류 분기.
func test_mvp_shu_phase_b_authors_ch11_to_ch14_with_wei_yan_defection_chain() -> void:
	var json_text: String = FileAccess.get_file_as_string("res://assets/data/scenarios/mvp_shu.json")
	assert_bool(json_text.is_empty()).override_failure_message(
		"mvp_shu.json must exist at assets/data/scenarios/mvp_shu.json"
	).is_false()
	var parsed: Variant = JSON.parse_string(json_text)
	var data: Dictionary = parsed as Dictionary
	var chapters: Array = data["chapters"] as Array
	assert_int(chapters.size()).override_failure_message(
		"Phase E: mvp_shu must declare exactly 25 chapters — 영걸전식 풀 캠페인 완성 (A 10 + B 4 + C 3 + D 5 + E 3)"
	).is_equal(25)

	var by_id: Dictionary = {}
	for c: Variant in chapters:
		var d: Dictionary = c as Dictionary
		by_id[d.get("chapter_id", "") as String] = d

	for expected_id: String in [
		"ch11_jingzhou_pacify",
		"ch12_wuling_marsh",
		"ch13_changsha_veteran",
		"ch14_jingzhou_consolidate",
	]:
		assert_bool(by_id.has(expected_id)).override_failure_message(
			"Phase B: mvp_shu missing chapter_id '%s'" % expected_id
		).is_true()

	# ch13 hidden destiny — wei_yan_spared_turns >= 3 → WIN_changsha_wei_yan_defects.
	var ch13: Dictionary = by_id["ch13_changsha_veteran"] as Dictionary
	assert_str(ch13.get("hidden_branch_key", "") as String).override_failure_message(
		"Phase B: ch13 must declare hidden_branch_key = 'WIN_hidden'"
	).is_equal("WIN_hidden")
	var hc: Dictionary = ch13.get("hidden_condition", {}) as Dictionary
	assert_str(hc.get("type", "") as String).is_equal("fate_threshold")
	assert_str(hc.get("field", "") as String).is_equal("wei_yan_spared_turns")
	assert_str(hc.get("op", "") as String).is_equal(">=")
	assert_int(hc.get("value", -1) as int).is_equal(3)
	var ch13_bt: Dictionary = ch13.get("branch_table", {}) as Dictionary
	assert_str(ch13_bt.get("WIN_hidden", "") as String).is_equal("WIN_changsha_wei_yan_defects")

	# ch14 branch_overrides — WIN_changsha_wei_yan_defects adds unit_id 15 (위연)
	# to the player roster, expanding from 6 to 7 deployed units.
	var ch14: Dictionary = by_id["ch14_jingzhou_consolidate"] as Dictionary
	var ovr: Dictionary = ch14.get("branch_overrides", {}) as Dictionary
	assert_bool(ovr.has("WIN_changsha_wei_yan_defects")).override_failure_message(
		"Phase B: ch14 must author branch_overrides for WIN_changsha_wei_yan_defects"
	).is_true()
	var entry: Dictionary = ovr["WIN_changsha_wei_yan_defects"] as Dictionary
	var ovr_unit_ids: Array = entry.get("player_unit_ids", []) as Array
	assert_int(ovr_unit_ids.size()).override_failure_message(
		"Phase B: ch14 hidden override must add 위연 (unit_id 15) → 7 player units (got %d)"
			% ovr_unit_ids.size()
	).is_equal(7)
	var found_wei_yan: bool = false
	for uid_var: Variant in ovr_unit_ids:
		if int(uid_var) == 15:
			found_wei_yan = true
			break
	assert_bool(found_wei_yan).override_failure_message(
		"Phase B: ch14 hidden override player_unit_ids must include unit_id 15 (위연); got %s"
			% str(ovr_unit_ids)
	).is_true()
	var ovr_hero_ids: Dictionary = entry.get("player_hero_ids", {}) as Dictionary
	assert_str(ovr_hero_ids.get("15", "") as String).is_equal("shu_009_wei_yan")

	# Map ids match the new .tres files generated for Phase B.
	for expected_id: String in [
		"ch11_jingzhou_pacify",
		"ch12_wuling_marsh",
		"ch13_changsha_veteran",
		"ch14_jingzhou_consolidate",
	]:
		var ch: Dictionary = by_id[expected_id] as Dictionary
		var map_id: String = ch.get("map_id", "") as String
		var map_path: String = "res://assets/data/maps/%s.tres" % map_id
		assert_bool(ResourceLoader.exists(map_path)).override_failure_message(
			"Phase B: %s declares map_id '%s' but %s does not exist on disk"
				% [expected_id, map_id, map_path]
		).is_true()


## Phase B end-to-end hydration smoke — full mvp_shu loads through
## ScenarioRunner.load_scenario without scenario_fault. Catches validator
## regressions on the new Phase B chapter records (echo_threshold, victory
## conditions, hidden_condition, branch_overrides shape).
func test_mvp_shu_phase_b_full_scenario_loads_via_runner_without_fault() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)

	var ok: bool = runner.load_scenario("res://assets/data/scenarios/mvp_shu.json")

	assert_bool(ok).override_failure_message(
		"Phase B/C: ScenarioRunner.load_scenario MUST succeed on full mvp_shu.json"
	).is_true()


# ─── Phase C (mvp_shu ch15~ch17) — 익주 입성 authoring sanity ──────────────────


## Phase C regression sentinel — ch15 부수관 (REACH_TILE 방통 합류) + ch16 낙봉파
## (시그니처 hidden destiny scout_first_turns ≥ 2 → 방통 생존) + ch17 성도
## (branch_overrides on WIN_luofeng_pang_tong_lives → 방통 잔류).
func test_mvp_shu_phase_c_authors_ch15_to_ch17_with_pang_tong_survival_chain() -> void:
	var json_text: String = FileAccess.get_file_as_string("res://assets/data/scenarios/mvp_shu.json")
	var parsed: Variant = JSON.parse_string(json_text)
	var data: Dictionary = parsed as Dictionary
	var chapters: Array = data["chapters"] as Array

	var by_id: Dictionary = {}
	for c: Variant in chapters:
		var d: Dictionary = c as Dictionary
		by_id[d.get("chapter_id", "") as String] = d

	for expected_id: String in [
		"ch15_fushui_pass",
		"ch16_luofeng_slope",
		"ch17_chengdu_gates",
	]:
		assert_bool(by_id.has(expected_id)).override_failure_message(
			"Phase C: mvp_shu missing chapter_id '%s'" % expected_id
		).is_true()

	# ch15 REACH_TILE victory — commander (unit 0) reaches [14, 4].
	var ch15: Dictionary = by_id["ch15_fushui_pass"] as Dictionary
	var ch15_vc: Dictionary = ch15.get("victory_conditions", {}) as Dictionary
	assert_int(int(ch15_vc.get("primary_condition_type", -1))).override_failure_message(
		"Phase C: ch15 victory_conditions.primary_condition_type must be 3 (REACH_TILE)"
	).is_equal(3)
	var ch15_target_tile: Array = ch15_vc.get("target_tile", []) as Array
	assert_int(ch15_target_tile.size()).is_equal(2)
	assert_int(int(ch15_target_tile[0])).is_equal(14)
	assert_int(int(ch15_target_tile[1])).is_equal(4)
	# ch15 roster includes 방통 (unit_id 16, hero shu_007_pang_tong).
	var ch15_hero_ids: Dictionary = ch15.get("player_hero_ids", {}) as Dictionary
	assert_str(ch15_hero_ids.get("16", "") as String).override_failure_message(
		"Phase C: ch15 player_hero_ids[16] must be 'shu_007_pang_tong' (방통 합류)"
	).is_equal("shu_007_pang_tong")

	# ch16 hidden destiny — scout_first_turns >= 2 → WIN_luofeng_pang_tong_lives.
	var ch16: Dictionary = by_id["ch16_luofeng_slope"] as Dictionary
	assert_str(ch16.get("hidden_branch_key", "") as String).is_equal("WIN_hidden")
	var hc: Dictionary = ch16.get("hidden_condition", {}) as Dictionary
	assert_str(hc.get("type", "") as String).is_equal("fate_threshold")
	assert_str(hc.get("field", "") as String).is_equal("scout_first_turns")
	assert_str(hc.get("op", "") as String).is_equal(">=")
	assert_int(int(hc.get("value", -1))).is_equal(2)
	var ch16_bt: Dictionary = ch16.get("branch_table", {}) as Dictionary
	assert_str(ch16_bt.get("WIN_hidden", "") as String).is_equal("WIN_luofeng_pang_tong_lives")
	# ch16 SURVIVE_N_ROUNDS=4.
	var ch16_vc: Dictionary = ch16.get("victory_conditions", {}) as Dictionary
	assert_int(int(ch16_vc.get("primary_condition_type", -1))).override_failure_message(
		"Phase C: ch16 victory_conditions.primary_condition_type must be 1 (SURVIVE_N_ROUNDS)"
	).is_equal(1)
	assert_int(int(ch16_vc.get("survive_rounds", -1))).is_equal(4)

	# ch17 default roster (no 방통) + branch_overrides on hidden destiny restores 방통.
	var ch17: Dictionary = by_id["ch17_chengdu_gates"] as Dictionary
	var ch17_default_units: Array = ch17.get("player_unit_ids", []) as Array
	assert_int(ch17_default_units.size()).override_failure_message(
		"Phase C: ch17 default player_unit_ids should be 6 (방통 사망 canonical)"
	).is_equal(6)
	var ovr: Dictionary = ch17.get("branch_overrides", {}) as Dictionary
	assert_bool(ovr.has("WIN_luofeng_pang_tong_lives")).override_failure_message(
		"Phase C: ch17 must author branch_overrides for WIN_luofeng_pang_tong_lives (영걸전 시그니처)"
	).is_true()
	var entry: Dictionary = ovr["WIN_luofeng_pang_tong_lives"] as Dictionary
	var ovr_unit_ids: Array = entry.get("player_unit_ids", []) as Array
	assert_int(ovr_unit_ids.size()).override_failure_message(
		"Phase C: ch17 hidden override must add 방통 (unit_id 16) → 7 player units (got %d)"
			% ovr_unit_ids.size()
	).is_equal(7)
	var found_pang_tong: bool = false
	for uid_var: Variant in ovr_unit_ids:
		if int(uid_var) == 16:
			found_pang_tong = true
			break
	assert_bool(found_pang_tong).override_failure_message(
		"Phase C: ch17 hidden override player_unit_ids must include unit_id 16 (방통); got %s"
			% str(ovr_unit_ids)
	).is_true()
	var ovr_hero_ids: Dictionary = entry.get("player_hero_ids", {}) as Dictionary
	assert_str(ovr_hero_ids.get("16", "") as String).is_equal("shu_007_pang_tong")

	# Map ids match the new .tres files generated for Phase C.
	for expected_id: String in [
		"ch15_fushui_pass",
		"ch16_luofeng_slope",
		"ch17_chengdu_gates",
	]:
		var ch: Dictionary = by_id[expected_id] as Dictionary
		var map_id: String = ch.get("map_id", "") as String
		var map_path: String = "res://assets/data/maps/%s.tres" % map_id
		assert_bool(ResourceLoader.exists(map_path)).override_failure_message(
			"Phase C: %s declares map_id '%s' but %s does not exist on disk"
				% [expected_id, map_id, map_path]
		).is_true()


# ─── Phase D (mvp_shu ch18~ch22) — 한중·이릉·영걸전 시그니처 분기 3개 ────────────


## Phase D regression sentinel — ch18 한중 진군 (마초 합류) + ch19 정군산 (황충
## hidden) + ch20 번성 (관우 생환 시그니처 #3) + ch21 장비 (장비 생존 시그니처) +
## ch22 이릉 (유비 생환 시그니처 #4). ch21/ch22 cascading branch_overrides chain.
func test_mvp_shu_phase_d_authors_ch18_to_ch22_with_three_signature_branches() -> void:
	var json_text: String = FileAccess.get_file_as_string("res://assets/data/scenarios/mvp_shu.json")
	var parsed: Variant = JSON.parse_string(json_text)
	var data: Dictionary = parsed as Dictionary
	var chapters: Array = data["chapters"] as Array

	var by_id: Dictionary = {}
	for c: Variant in chapters:
		var d: Dictionary = c as Dictionary
		by_id[d.get("chapter_id", "") as String] = d

	for expected_id: String in [
		"ch18_hanzhong_advance",
		"ch19_dingjun_peak",
		"ch20_fancheng_pursuit",
		"ch21_zhangfei_avenge",
		"ch22_yiling_burn",
	]:
		assert_bool(by_id.has(expected_id)).override_failure_message(
			"Phase D: mvp_shu missing chapter_id '%s'" % expected_id
		).is_true()

	# ch18 — 마초 (unit_id 17, hero shu_008_ma_chao) joins the roster.
	var ch18: Dictionary = by_id["ch18_hanzhong_advance"] as Dictionary
	var ch18_hero_ids: Dictionary = ch18.get("player_hero_ids", {}) as Dictionary
	assert_str(ch18_hero_ids.get("17", "") as String).override_failure_message(
		"Phase D: ch18 player_hero_ids[17] must be 'shu_008_ma_chao' (마초 합류)"
	).is_equal("shu_008_ma_chao")

	# ch19 hidden destiny — huang_zhong_xiahou_yuan_kill >= 1 → WIN_dingjun_old_general_proven.
	var ch19: Dictionary = by_id["ch19_dingjun_peak"] as Dictionary
	var hc19: Dictionary = ch19.get("hidden_condition", {}) as Dictionary
	assert_str(hc19.get("field", "") as String).is_equal("huang_zhong_xiahou_yuan_kill")
	var ch19_bt: Dictionary = ch19.get("branch_table", {}) as Dictionary
	assert_str(ch19_bt.get("WIN_hidden", "") as String).is_equal("WIN_dingjun_old_general_proven")

	# ch20 hidden destiny — retreat_path_clear_turns >= 3 → 관우 생환 (시그니처 #3).
	var ch20: Dictionary = by_id["ch20_fancheng_pursuit"] as Dictionary
	var hc20: Dictionary = ch20.get("hidden_condition", {}) as Dictionary
	assert_str(hc20.get("field", "") as String).is_equal("retreat_path_clear_turns")
	assert_int(int(hc20.get("value", -1))).is_equal(3)
	var ch20_bt: Dictionary = ch20.get("branch_table", {}) as Dictionary
	assert_str(ch20_bt.get("WIN_hidden", "") as String).is_equal("WIN_fancheng_guan_yu_survives")
	# ch20 SURVIVE_N_ROUNDS = 6.
	var ch20_vc: Dictionary = ch20.get("victory_conditions", {}) as Dictionary
	assert_int(int(ch20_vc.get("primary_condition_type", -1))).is_equal(1)
	assert_int(int(ch20_vc.get("survive_rounds", -1))).is_equal(6)

	# ch21 default roster (no 관우 unit 6) + branch_overrides on WIN_fancheng_guan_yu_survives
	# restores 관우 to roster (cascading single-step survival chain).
	var ch21: Dictionary = by_id["ch21_zhangfei_avenge"] as Dictionary
	var ch21_default_units: Array = ch21.get("player_unit_ids", []) as Array
	var ch21_has_guan_yu_default: bool = false
	for uid_var: Variant in ch21_default_units:
		if int(uid_var) == 6:
			ch21_has_guan_yu_default = true
			break
	assert_bool(ch21_has_guan_yu_default).override_failure_message(
		"Phase D: ch21 default roster MUST NOT include 관우 (unit 6) — canonical 관우 전사"
	).is_false()
	var ovr21: Dictionary = ch21.get("branch_overrides", {}) as Dictionary
	assert_bool(ovr21.has("WIN_fancheng_guan_yu_survives")).override_failure_message(
		"Phase D: ch21 must author branch_overrides for WIN_fancheng_guan_yu_survives"
	).is_true()
	var ch21_ovr_units: Array = (ovr21["WIN_fancheng_guan_yu_survives"] as Dictionary).get("player_unit_ids", []) as Array
	var ch21_ovr_has_guan_yu: bool = false
	for uid_var: Variant in ch21_ovr_units:
		if int(uid_var) == 6:
			ch21_ovr_has_guan_yu = true
			break
	assert_bool(ch21_ovr_has_guan_yu).override_failure_message(
		"Phase D: ch21 hidden override player_unit_ids must include 관우 (unit 6) on 시그니처 #3"
	).is_true()
	# ch21 hidden destiny — discipline_turns >= 4 → WIN_zhangfei_survives.
	var hc21: Dictionary = ch21.get("hidden_condition", {}) as Dictionary
	assert_str(hc21.get("field", "") as String).is_equal("discipline_turns")
	var ch21_bt: Dictionary = ch21.get("branch_table", {}) as Dictionary
	assert_str(ch21_bt.get("WIN_hidden", "") as String).is_equal("WIN_zhangfei_survives")

	# ch22 default roster (no 장비 unit 1) + branch_overrides on WIN_zhangfei_survives
	# restores 장비 to roster (cascading single-step survival chain).
	var ch22: Dictionary = by_id["ch22_yiling_burn"] as Dictionary
	var ch22_default_units: Array = ch22.get("player_unit_ids", []) as Array
	var ch22_has_zhangfei_default: bool = false
	for uid_var: Variant in ch22_default_units:
		if int(uid_var) == 1:
			ch22_has_zhangfei_default = true
			break
	assert_bool(ch22_has_zhangfei_default).override_failure_message(
		"Phase D: ch22 default roster MUST NOT include 장비 (unit 1) — canonical 장비 시해"
	).is_false()
	var ovr22: Dictionary = ch22.get("branch_overrides", {}) as Dictionary
	assert_bool(ovr22.has("WIN_zhangfei_survives")).override_failure_message(
		"Phase D: ch22 must author branch_overrides for WIN_zhangfei_survives"
	).is_true()
	var ch22_ovr_units: Array = (ovr22["WIN_zhangfei_survives"] as Dictionary).get("player_unit_ids", []) as Array
	var ch22_ovr_has_zhangfei: bool = false
	for uid_var: Variant in ch22_ovr_units:
		if int(uid_var) == 1:
			ch22_ovr_has_zhangfei = true
			break
	assert_bool(ch22_ovr_has_zhangfei).override_failure_message(
		"Phase D: ch22 hidden override player_unit_ids must include 장비 (unit 1) on 시그니처"
	).is_true()
	# ch22 hidden destiny — counter_fire_turns >= 2 → 유비 생환 (시그니처 #4).
	var hc22: Dictionary = ch22.get("hidden_condition", {}) as Dictionary
	assert_str(hc22.get("field", "") as String).is_equal("counter_fire_turns")
	var ch22_bt: Dictionary = ch22.get("branch_table", {}) as Dictionary
	assert_str(ch22_bt.get("WIN_hidden", "") as String).is_equal("WIN_yiling_liu_bei_survives")

	# Map ids match the new .tres files generated for Phase D.
	for expected_id: String in [
		"ch18_hanzhong_advance",
		"ch19_dingjun_peak",
		"ch20_fancheng_pursuit",
		"ch21_zhangfei_avenge",
		"ch22_yiling_burn",
	]:
		var ch: Dictionary = by_id[expected_id] as Dictionary
		var map_id: String = ch.get("map_id", "") as String
		var map_path: String = "res://assets/data/maps/%s.tres" % map_id
		assert_bool(ResourceLoader.exists(map_path)).override_failure_message(
			"Phase D: %s declares map_id '%s' but %s does not exist on disk"
				% [expected_id, map_id, map_path]
		).is_true()


# ─── Phase E (mvp_shu ch23~ch25) — 남만·북벌·오장원·영걸전 finale ──────────────


## Phase E regression sentinel — ch23 남만 정벌 (칠종칠금 hidden) + ch24 가정
## (강유 합류 + 마속 생존 시그니처) + ch25 오장원 (영걸전 최종 시그니처 #5 제갈량 회생).
## 25챕터 풀 캠페인 완성 sentinel — master plan §1 100%.
func test_mvp_shu_phase_e_authors_ch23_to_ch25_with_qixing_revival_finale() -> void:
	var json_text: String = FileAccess.get_file_as_string("res://assets/data/scenarios/mvp_shu.json")
	var parsed: Variant = JSON.parse_string(json_text)
	var data: Dictionary = parsed as Dictionary
	var chapters: Array = data["chapters"] as Array

	var by_id: Dictionary = {}
	for c: Variant in chapters:
		var d: Dictionary = c as Dictionary
		by_id[d.get("chapter_id", "") as String] = d

	for expected_id: String in [
		"ch23_southern_pacify",
		"ch24_jieting_pass",
		"ch25_wuzhang_plains",
	]:
		assert_bool(by_id.has(expected_id)).override_failure_message(
			"Phase E: mvp_shu missing chapter_id '%s'" % expected_id
		).is_true()

	# ch23 hidden destiny — menghuo_captures >= 7 → WIN_southern_seven_releases (칠종칠금).
	var ch23: Dictionary = by_id["ch23_southern_pacify"] as Dictionary
	var hc23: Dictionary = ch23.get("hidden_condition", {}) as Dictionary
	assert_str(hc23.get("field", "") as String).is_equal("menghuo_captures")
	assert_int(int(hc23.get("value", -1))).is_equal(7)
	var ch23_bt: Dictionary = ch23.get("branch_table", {}) as Dictionary
	assert_str(ch23_bt.get("WIN_hidden", "") as String).is_equal("WIN_southern_seven_releases")

	# ch24 — 강유 (unit 18, hero shu_010_jiang_wei) joins, REACH_TILE 제갈량 to [12,5].
	var ch24: Dictionary = by_id["ch24_jieting_pass"] as Dictionary
	var ch24_hero_ids: Dictionary = ch24.get("player_hero_ids", {}) as Dictionary
	assert_str(ch24_hero_ids.get("18", "") as String).override_failure_message(
		"Phase E: ch24 player_hero_ids[18] must be 'shu_010_jiang_wei' (강유 합류)"
	).is_equal("shu_010_jiang_wei")
	var ch24_vc: Dictionary = ch24.get("victory_conditions", {}) as Dictionary
	assert_int(int(ch24_vc.get("primary_condition_type", -1))).override_failure_message(
		"Phase E: ch24 victory_conditions.primary_condition_type must be 3 (REACH_TILE)"
	).is_equal(3)
	var ch24_target_units: Array = ch24_vc.get("target_unit_ids", []) as Array
	assert_int(int(ch24_target_units[0])).override_failure_message(
		"Phase E: ch24 target_unit_ids[0] must be 13 (제갈량)"
	).is_equal(13)
	# ch24 hidden destiny — masu_supervised_turns >= 3 → WIN_jieting_masu_survives (시그니처).
	var hc24: Dictionary = ch24.get("hidden_condition", {}) as Dictionary
	assert_str(hc24.get("field", "") as String).is_equal("masu_supervised_turns")
	var ch24_bt: Dictionary = ch24.get("branch_table", {}) as Dictionary
	assert_str(ch24_bt.get("WIN_hidden", "") as String).is_equal("WIN_jieting_masu_survives")

	# ch25 — 영걸전 finale — qixing_turns >= 6 → WIN_wuzhang_kongming_revives (시그니처 #5).
	var ch25: Dictionary = by_id["ch25_wuzhang_plains"] as Dictionary
	var hc25: Dictionary = ch25.get("hidden_condition", {}) as Dictionary
	assert_str(hc25.get("field", "") as String).is_equal("qixing_turns")
	assert_int(int(hc25.get("value", -1))).is_equal(6)
	var ch25_bt: Dictionary = ch25.get("branch_table", {}) as Dictionary
	assert_str(ch25_bt.get("WIN_hidden", "") as String).override_failure_message(
		"Phase E: ch25 WIN_hidden must be 'WIN_wuzhang_kongming_revives' (영걸전 최종 시그니처 #5)"
	).is_equal("WIN_wuzhang_kongming_revives")
	# ch25 SURVIVE_N_ROUNDS = 8.
	var ch25_vc: Dictionary = ch25.get("victory_conditions", {}) as Dictionary
	assert_int(int(ch25_vc.get("primary_condition_type", -1))).is_equal(1)
	assert_int(int(ch25_vc.get("survive_rounds", -1))).is_equal(8)

	# Map ids match the new .tres files generated for Phase E.
	for expected_id: String in [
		"ch23_southern_pacify",
		"ch24_jieting_pass",
		"ch25_wuzhang_plains",
	]:
		var ch: Dictionary = by_id[expected_id] as Dictionary
		var map_id: String = ch.get("map_id", "") as String
		var map_path: String = "res://assets/data/maps/%s.tres" % map_id
		assert_bool(ResourceLoader.exists(map_path)).override_failure_message(
			"Phase E: %s declares map_id '%s' but %s does not exist on disk"
				% [expected_id, map_id, map_path]
		).is_true()


## ch25 ending_screen_text_keys sentinel (S65+ — 3-tier ending UX). 4 분기
## (canonical/hidden/legendary/loss) 각각 ending prose key 매핑 + story_content
## prose 존재 검증.
func test_mvp_shu_ch25_authors_ending_screen_text_keys_for_all_four_branches() -> void:
	var json_text: String = FileAccess.get_file_as_string("res://assets/data/scenarios/mvp_shu.json")
	var data: Dictionary = JSON.parse_string(json_text) as Dictionary
	var ch25: Dictionary = {}
	for c: Variant in (data["chapters"] as Array):
		var d: Dictionary = c as Dictionary
		if d.get("chapter_id", "") as String == "ch25_wuzhang_plains":
			ch25 = d
			break
	var endings: Dictionary = ch25.get("ending_screen_text_keys", {}) as Dictionary
	assert_int(endings.size()).override_failure_message(
		"ch25 ending_screen_text_keys must declare exactly 4 entries (canonical/hidden/legendary/loss)"
	).is_equal(4)
	var expected: Dictionary = {
		"WIN_wuzhang_kongming_falls":   "ch25.ending.canonical_loyal",
		"WIN_wuzhang_kongming_revives": "ch25.ending.perfect_destiny",
		"WIN_wuzhang_legendary_dawn":   "ch25.ending.legendary_destiny",
		"LOSS_wuzhang_consumed":        "ch25.ending.loss_total",
	}
	for branch in expected.keys():
		assert_str(endings.get(branch, "") as String).override_failure_message(
			"ch25 ending_screen_text_keys['%s'] must map to '%s'" % [branch, expected[branch]]
		).is_equal(expected[branch] as String)
	# Verify story_content prose exists for all 4 ending keys.
	var story: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://assets/data/story/story_content.json")
	) as Dictionary
	for text_key in expected.values():
		assert_bool(story.has(text_key as String)).override_failure_message(
			"story_content.json must author '%s' prose" % text_key
		).is_true()


## ch25 legendary tier sentinel (S65+ 매력 보강): branch_table에 WIN_legendary
## 등재 + legendary_branch_key + legendary_condition (active_signature_count >= 5)
## + beat_8_revelations entry + story_content 한국어 prose. 5 시그니처 누적 +
## ch25 hidden 둘 다 달성 시 전설의 새벽 ENDING.
func test_mvp_shu_ch25_authors_legendary_destiny_tier() -> void:
	var json_text: String = FileAccess.get_file_as_string("res://assets/data/scenarios/mvp_shu.json")
	var data: Dictionary = JSON.parse_string(json_text) as Dictionary
	var ch25: Dictionary = {}
	for c: Variant in (data["chapters"] as Array):
		var d: Dictionary = c as Dictionary
		if d.get("chapter_id", "") as String == "ch25_wuzhang_plains":
			ch25 = d
			break
	# branch_table contains WIN_legendary → WIN_wuzhang_legendary_dawn.
	var bt: Dictionary = ch25.get("branch_table", {}) as Dictionary
	assert_str(bt.get("WIN_legendary", "") as String).override_failure_message(
		"ch25 branch_table must declare WIN_legendary → WIN_wuzhang_legendary_dawn"
	).is_equal("WIN_wuzhang_legendary_dawn")
	# legendary_branch_key declared.
	assert_str(ch25.get("legendary_branch_key", "") as String).is_equal("WIN_legendary")
	# legendary_condition: fate_threshold active_signature_count >= 5.
	var lc: Dictionary = ch25.get("legendary_condition", {}) as Dictionary
	assert_str(lc.get("type", "") as String).is_equal("fate_threshold")
	assert_str(lc.get("field", "") as String).is_equal("active_signature_count")
	assert_str(lc.get("op", "") as String).is_equal(">=")
	assert_int(int(lc.get("value", -1))).is_equal(5)
	# beat_8_revelations contains the legendary entry.
	var revs: Array = ch25.get("beat_8_revelations", []) as Array
	var has_legendary_rev: bool = false
	for r_var: Variant in revs:
		var r: Dictionary = r_var as Dictionary
		if (r.get("branch_key", "") as String) == "WIN_wuzhang_legendary_dawn":
			has_legendary_rev = true
			assert_str(r.get("text_key", "") as String).is_equal(
				"ch25.beat8.win_wuzhang_legendary_dawn"
			)
			break
	assert_bool(has_legendary_rev).override_failure_message(
		"ch25.beat_8_revelations must include WIN_wuzhang_legendary_dawn entry"
	).is_true()
	# story_content text key authored (한국어 prose 존재).
	var story_text: String = FileAccess.get_file_as_string(
		"res://assets/data/story/story_content.json"
	)
	var story: Dictionary = JSON.parse_string(story_text) as Dictionary
	assert_bool(story.has("ch25.beat8.win_wuzhang_legendary_dawn")).override_failure_message(
		"story_content.json must author 'ch25.beat8.win_wuzhang_legendary_dawn' prose"
	).is_true()


## 25-chapter master plan completion sentinel — mvp_shu must declare exactly 25 chapters
## with the 영걸전식 풀 캠페인 도원결의 → 오장원 progression. Pure structural assertion
## independent of phase boundaries — protects against accidental chapter additions/removals.
func test_mvp_shu_full_campaign_25_chapter_progression_complete() -> void:
	var json_text: String = FileAccess.get_file_as_string("res://assets/data/scenarios/mvp_shu.json")
	var data: Dictionary = JSON.parse_string(json_text) as Dictionary
	var chapters: Array = data["chapters"] as Array

	assert_int(chapters.size()).override_failure_message(
		"25-chapter master plan: mvp_shu MUST declare exactly 25 chapters"
	).is_equal(25)

	# Chapter numbers must be 1..25 sequential.
	for i: int in 25:
		var ch: Dictionary = chapters[i] as Dictionary
		assert_int(int(ch.get("chapter_number", -1))).override_failure_message(
			"25-chapter master plan: chapter at index %d must have chapter_number %d, got %d"
				% [i, i + 1, int(ch.get("chapter_number", -1))]
		).is_equal(i + 1)

	# First chapter = 도원결의 (Peach Garden Oath); last chapter = 오장원 (Wuzhang Plains finale).
	assert_str((chapters[0] as Dictionary).get("chapter_id", "") as String).override_failure_message(
		"25-chapter master plan: first chapter must be ch01_taoyuan_yellow_turban (도원결의)"
	).is_equal("ch01_taoyuan_yellow_turban")
	assert_str((chapters[24] as Dictionary).get("chapter_id", "") as String).override_failure_message(
		"25-chapter master plan: final chapter must be ch25_wuzhang_plains (오장원·영걸전 finale)"
	).is_equal("ch25_wuzhang_plains")


# ─── Multi-step survival cascade — mvp_shu.json data sentinel (S65) ───────────


## After S65 cascade rollout, mvp_shu.json must declare:
##   1. signature_branches root array (5 영걸전 시그니처 키)
##   2. branch_overrides cascade entries on every chapter the signature applies to:
##      - 위연 (WIN_changsha_wei_yan_defects) : ch14~ch25 (12 chapters)
##      - 방통 (WIN_luofeng_pang_tong_lives)  : ch17~ch25 (9 chapters)
##      - 관우 (WIN_fancheng_guan_yu_survives): ch21~ch25 (5 chapters)
##      - 장비 (WIN_zhangfei_survives)        : ch22~ch25 (4 chapters)
##      - 유비 (WIN_yiling_liu_bei_survives)  : ch23~ch25 (3 chapters)
##
## Each cascade entry MUST patch the cascade hero into the chapter's roster
## (player_unit_ids + player_hero_ids + deployment_positions_default).
func test_mvp_shu_signature_branches_root_and_cascade_overrides_complete() -> void:
	var json_text: String = FileAccess.get_file_as_string("res://assets/data/scenarios/mvp_shu.json")
	var data: Dictionary = JSON.parse_string(json_text) as Dictionary

	# 1. signature_branches root.
	var sig_keys: Array = data.get("signature_branches", []) as Array
	assert_int(sig_keys.size()).override_failure_message(
		"mvp_shu root signature_branches must declare 5 영걸전 시그니처 키"
	).is_equal(5)
	for expected: String in [
		"WIN_changsha_wei_yan_defects",
		"WIN_luofeng_pang_tong_lives",
		"WIN_fancheng_guan_yu_survives",
		"WIN_zhangfei_survives",
		"WIN_yiling_liu_bei_survives",
	]:
		assert_bool(expected in sig_keys).override_failure_message(
			"signature_branches missing '%s'" % expected
		).is_true()

	# 2. Build a chapter-number -> dict map for cascade range checks.
	var by_num: Dictionary = {}
	for c: Variant in (data["chapters"] as Array):
		var d: Dictionary = c as Dictionary
		by_num[int(d.get("chapter_number", -1))] = d

	# Cascade ranges: signature key, expected unit_id added by cascade,
	# expected hero_id added by cascade, first chapter cascade applies to.
	var cascade_specs: Array = [
		{"key": "WIN_changsha_wei_yan_defects",  "uid": 15, "hero": "shu_009_wei_yan",   "start": 14},
		{"key": "WIN_luofeng_pang_tong_lives",   "uid": 16, "hero": "shu_007_pang_tong", "start": 17},
		{"key": "WIN_fancheng_guan_yu_survives", "uid":  6, "hero": "shu_002_guan_yu",   "start": 21},
		{"key": "WIN_zhangfei_survives",         "uid":  1, "hero": "shu_003_zhang_fei", "start": 22},
		{"key": "WIN_yiling_liu_bei_survives",   "uid":  0, "hero": "shu_001_liu_bei",   "start": 23},
	]
	for spec_var: Variant in cascade_specs:
		var spec: Dictionary = spec_var as Dictionary
		var sig_key: String = spec["key"] as String
		var uid: int = spec["uid"] as int
		var hero: String = spec["hero"] as String
		var start_n: int = spec["start"] as int
		for n: int in range(start_n, 26):
			var ch: Dictionary = by_num[n] as Dictionary
			var ovr: Dictionary = ch.get("branch_overrides", {}) as Dictionary
			assert_bool(ovr.has(sig_key)).override_failure_message(
				"ch%02d cascade missing branch_overrides['%s']" % [n, sig_key]
			).is_true()
			var entry: Dictionary = ovr[sig_key] as Dictionary
			var units: Array = entry.get("player_unit_ids", []) as Array
			# JSON int parses to Variant — explicit int cast per element.
			var has_uid: bool = false
			for uid_var: Variant in units:
				if int(uid_var) == uid:
					has_uid = true
					break
			assert_bool(has_uid).override_failure_message(
				"ch%02d cascade '%s' must add unit_id %d to roster"
					% [n, sig_key, uid]
			).is_true()
			var heroes: Dictionary = entry.get("player_hero_ids", {}) as Dictionary
			assert_str(heroes.get(str(uid), "") as String).override_failure_message(
				"ch%02d cascade '%s' must map unit %d → hero '%s'"
					% [n, sig_key, uid, hero]
			).is_equal(hero)


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
