## ch08_alliance_timing_branch_routing_test.gd
##
## Integration tests for ch08 ★ trigger routing per
## `design/quick-specs/ch08-alliance-timing.md` AC-8 + §7 tests #5/6/7.
## Drives fate_data shape (matching grid_battle_controller.gd:3362 emit)
## through DefaultDestinyBranchJudge with ch08 fixture chapter, asserts
## branch_key resolution for the 3 critical paths:
##   #5  win_within_turns=6 + WIN → WIN_xiakou_united_advance (★ hidden)
##   #6  win_within_turns=7 + WIN → WIN_xiakou_breakthrough (default canonical)
##   #7  LOSS outcome → LOSS_xiakou_pursuit_continues (regression sentinel)
##
## Mirrors the ch05 e2e pattern in grid_battle_controller_civilian_system_test.gd
## #10 — programmatic ChapterDefinition fixture matching shu_canon_main.json,
## direct judge.resolve drive, no controller wiring needed (fate_data shape
## verified separately in the sentinel test via substring check).
extends GdUnitTestSuite


# ─── ★ at win_within_turns=6 → hidden branch ─────────────────────────────────


func test_ch08_alliance_timing_triggers_hidden_branch_at_turn_6() -> void:
	# Arrange — ch08 fixture chapter + fate_data with win_within_turns=6
	# (the threshold value per spec §4.1 / hidden_condition lock).
	var chapter: ChapterDefinition = _make_ch08_fixture()
	var fate_data: Dictionary = {"win_within_turns": 6}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()

	# Act
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true, fate_data
	)

	# Assert — hidden ★ branch resolved (NOT canonical WIN_default)
	assert_str(choice.branch_key).override_failure_message(
		("Expected branch_key == 'WIN_xiakou_united_advance' when win_within_turns <= 6; "
		+ "got '%s'. fate_data.win_within_turns=%d, hidden_condition.value=%d")
		% [choice.branch_key, fate_data["win_within_turns"] as int,
			int(chapter.hidden_condition.get("value", -1))]
	).is_equal("WIN_xiakou_united_advance")
	assert_bool(choice.is_invalid).is_false()
	# F-DB-2: choice.branch_key != canonical → reserved_color_treatment = true
	# (hidden ★ is reserved-color reveal per Pillar 2)
	assert_bool(choice.reserved_color_treatment).override_failure_message(
		"★ hidden branch must set reserved_color_treatment=true (F-DB-2)"
	).is_true()


# ─── default canonical at win_within_turns=7 ──────────────────────────────────


func test_ch08_alliance_timing_falls_back_to_canonical_at_turn_7() -> void:
	# Arrange — fate_data with win_within_turns=7 (1 turn over threshold).
	# Player wins but too slowly — canonical WIN routes.
	var chapter: ChapterDefinition = _make_ch08_fixture()
	var fate_data: Dictionary = {"win_within_turns": 7}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()

	# Act
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true, fate_data
	)

	# Assert — canonical WIN_default routes (hidden_condition not satisfied)
	assert_str(choice.branch_key).override_failure_message(
		("Expected branch_key == 'WIN_xiakou_breakthrough' when win_within_turns > 6; "
		+ "got '%s'. fate_data.win_within_turns=%d")
		% [choice.branch_key, fate_data["win_within_turns"] as int]
	).is_equal("WIN_xiakou_breakthrough")
	assert_bool(choice.is_invalid).is_false()
	# canonical branch — no reserved-color treatment
	assert_bool(choice.reserved_color_treatment).override_failure_message(
		"canonical branch must NOT set reserved_color_treatment (F-DB-2)"
	).is_false()
	assert_bool(choice.is_canonical_history).is_true()


# ─── LOSS regression sentinel ────────────────────────────────────────────────


func test_ch08_loss_routes_to_pursuit_continues() -> void:
	# Arrange — LOSS outcome regardless of fate_data
	var chapter: ChapterDefinition = _make_ch08_fixture()
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()

	# Act
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.LOSS, 0, true, {}
	)

	# Assert — LOSS_default routes (hidden_condition only checked on WIN)
	assert_str(choice.branch_key).override_failure_message(
		"Expected branch_key == 'LOSS_xiakou_pursuit_continues' on LOSS outcome; got '%s'"
		% choice.branch_key
	).is_equal("LOSS_xiakou_pursuit_continues")
	assert_bool(choice.is_invalid).is_false()


# ─── Helpers ──────────────────────────────────────────────────────────────────


func _make_ch08_fixture() -> ChapterDefinition:
	# Mirrors assets/data/scenarios/shu_canon_main.json ch08 fields relevant to
	# DestinyBranchJudge routing — branch_table + hidden_branch_key +
	# hidden_condition + canonical_branch_key + echo_threshold (all locked by
	# ch08_alliance_timing_sentinel_test.gd). chapter_number=8 satisfies CR-13
	# (Ch1 echo_threshold=0 invariant doesn't apply).
	var c: ChapterDefinition = ChapterDefinition.new()
	c.chapter_id = "ch08_xiakou_outskirts"
	c.chapter_number = 8
	c.author_draw_branch = false
	c.echo_threshold = 1
	c.branch_table = {
		"WIN_default":  "WIN_xiakou_breakthrough",
		"WIN_hidden":   "WIN_xiakou_united_advance",
		"LOSS_default": "LOSS_xiakou_pursuit_continues",
	}
	c.canonical_branch_key = "WIN_xiakou_breakthrough"
	c.hidden_branch_key = "WIN_hidden"
	c.hidden_condition = {
		"type": "fate_threshold",
		"field": "win_within_turns",
		"op": "<=",
		"value": 6,
	}
	return c
