## grid_battle_controller_civilian_system_test.gd
##
## ADR-0022 Civilian System integration tests #8/9/10 per
## design/quick-specs/ch05-civilian-evacuation.md §7.
##
## Drives the civilian state machine end-to-end through GridBattleController's
## public + private surface, then proves the ★ trigger reaches DestinyBranchJudge
## as `WIN_xinye_civilians_saved` when 3+ tokens are SAVED.
##
##   Test #8 — pickup-on-end-turn (IDLE → ESCORTED on 8-neighbor adjacency)
##   Test #9 — save-on-zone-reach (ESCORTED → SAVED + counter +1 at col <= 0)
##   Test #10 — ★ trigger e2e (3 SAVED → fate_data.civilians_escorted >= 3 →
##              DefaultDestinyBranchJudge resolves to WIN_xinye_civilians_saved)
extends GdUnitTestSuite

const _GridControllerScript: GDScript = preload("res://src/feature/grid_battle/grid_battle_controller.gd")


# ─── Test #8: pickup-on-end-turn ──────────────────────────────────────────────


func test_civilian_pickup_on_player_end_turn_adjacency() -> void:
	# Arrange — controller + 1 player unit at (3,3) + 1 IDLE token at (3,2)
	var controller: Node = _GridControllerScript.new()
	var unit: BattleUnit = _make_player_unit(0, Vector2i(3, 3))
	var units: Dictionary = controller._units
	units[0] = unit
	controller.set_civilian_config({
		"positions": [[3, 2]],
		"evacuate_zone_max_col": 0,
	})

	# Act — player ends turn (carrier-adjacent IDLE token triggers pickup)
	controller._on_unit_turn_ended(0, true)

	# Assert — token bound to player as ESCORTED
	var tokens: Array[CivilianToken] = controller.get_civilian_tokens()
	assert_int(tokens.size()).is_equal(1)
	var t: CivilianToken = tokens[0]
	assert_int(t.state as int).override_failure_message(
		"Expected token state == ESCORTED after end-turn adjacency; got %d (IDLE=0/ESCORTED=1/SAVED=2)"
		% (t.state as int)
	).is_equal(CivilianToken.State.ESCORTED as int)
	assert_int(t.carrier_unit_id).is_equal(0)

	controller.free()


# ─── Test #9: save-on-zone-reach ──────────────────────────────────────────────


func test_civilian_save_on_carrier_reaches_evacuate_zone() -> void:
	# Arrange — controller + carrier at (1,3) + IDLE token at (1,2)
	# evacuate_zone_max_col = 0 (carrier must reach col 0 to SAVE)
	var controller: Node = _GridControllerScript.new()
	var unit: BattleUnit = _make_player_unit(0, Vector2i(1, 3))
	var units: Dictionary = controller._units
	units[0] = unit
	controller.set_civilian_config({
		"positions": [[1, 2]],
		"evacuate_zone_max_col": 0,
	})

	# Act phase 1 — carrier picks up IDLE token (8-neighbor adjacency from (1,3))
	controller._on_unit_turn_ended(0, true)
	var picked: CivilianToken = controller.get_civilian_tokens()[0]
	assert_int(picked.state as int).override_failure_message(
		"Phase-1 pickup precondition failed; token state=%d" % (picked.state as int)
	).is_equal(CivilianToken.State.ESCORTED as int)

	# Act phase 2 — move carrier to col 0 + end turn (save check fires)
	unit.position = Vector2i(0, 3)
	controller._on_unit_turn_ended(0, true)

	# Assert — token SAVED + counter incremented exactly once
	var saved: CivilianToken = controller.get_civilian_tokens()[0]
	assert_int(saved.state as int).override_failure_message(
		"Expected token state == SAVED after carrier reaches col <= 0; got %d"
		% (saved.state as int)
	).is_equal(CivilianToken.State.SAVED as int)
	assert_int(saved.carrier_unit_id).is_equal(-1)
	assert_int(controller._fate_civilians_escorted as int).override_failure_message(
		"Expected _fate_civilians_escorted == 1 after single SAVE; got %d"
		% (controller._fate_civilians_escorted as int)
	).is_equal(1)

	controller.free()


# ─── Test #10: ★ trigger e2e ──────────────────────────────────────────────────


func test_ch05_three_civilians_saved_triggers_hidden_branch() -> void:
	# Arrange — controller with 3 IDLE civilian tokens; force all 3 to SAVED
	# via the SOLE mutator path (_civilian_commit_save). Then prove fate_data
	# shape feeds DestinyBranchJudge to the hidden ch05 ★ branch.
	var controller: Node = _GridControllerScript.new()
	controller.set_civilian_config({
		"positions": [[3, 2], [5, 3], [4, 5]],
		"evacuate_zone_max_col": 0,
	})

	# Act phase 1 — force-SAVE all 3 tokens (simulates 3 successful escort runs).
	# Direct state-machine drive: ESCORTED via bind_to_carrier (carrier id 0
	# satisfies assert), then commit_save + _civilian_commit_save mirrors the
	# real flow in _civilian_check_save_for_unit.
	var tokens: Array[CivilianToken] = controller._civilian_tokens
	for t: CivilianToken in tokens:
		t.bind_to_carrier(0)
		t.commit_save()
		controller._civilian_commit_save(t.token_id)

	# Assert phase 1 — counter exactly matches token count
	assert_int(controller._fate_civilians_escorted as int).override_failure_message(
		"Counter must equal 3 SAVED tokens; got %d" % (controller._fate_civilians_escorted as int)
	).is_equal(3)

	# Act phase 2 — feed counter into DestinyBranchJudge via fate_data shape
	# matching grid_battle_controller.gd's actual emit (`"civilians_escorted": _fate_civilians_escorted`).
	var fate_data: Dictionary = {
		"civilians_escorted": controller._fate_civilians_escorted,
	}
	var chapter: ChapterDefinition = _make_ch05_fixture()
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true, fate_data
	)

	# Assert phase 2 — hidden ★ branch routed (not the default WIN_xinye_burning_retreat)
	# Parens around the concat per G-9 (`%` operator binds to immediate left
	# operand only, not the full string concat).
	assert_str(choice.branch_key).override_failure_message(
		("Expected branch_key == WIN_xinye_civilians_saved when civilians_escorted >= 3; got '%s'. "
		+ "Routing chain: hidden_branch_key=%s, hidden_condition.value=%s, fate_data.civilians_escorted=%d")
		% [choice.branch_key, chapter.hidden_branch_key,
			str(chapter.hidden_condition.get("value", -1)),
			fate_data["civilians_escorted"] as int]
	).is_equal("WIN_xinye_civilians_saved")
	assert_bool(choice.is_invalid).is_false()

	controller.free()


# ─── Helpers ──────────────────────────────────────────────────────────────────


func _make_player_unit(unit_id: int, position: Vector2i) -> BattleUnit:
	var u: BattleUnit = BattleUnit.new()
	u.unit_id = unit_id
	u.is_player_controlled = true
	u.side = 0
	u.position = position
	return u


func _make_ch05_fixture() -> ChapterDefinition:
	# Mirrors assets/data/scenarios/shu_canon_main.json ch05 fields relevant to
	# DestinyBranchJudge routing — branch_table + hidden_branch_key +
	# hidden_condition. Other ch05 fields (banter, beats, civilian_config) are
	# routing-irrelevant.
	var c: ChapterDefinition = ChapterDefinition.new()
	c.chapter_id = "ch05_xinye_fire"
	c.chapter_number = 5
	c.author_draw_branch = false
	c.echo_threshold = 0
	c.branch_table = {
		"WIN_default":  "WIN_xinye_burning_retreat",
		"WIN_hidden":   "WIN_xinye_civilians_saved",
		"LOSS_default": "LOSS_xinye_consumed_with_city",
	}
	c.canonical_branch_key = "WIN_xinye_burning_retreat"
	c.hidden_branch_key = "WIN_hidden"
	c.hidden_condition = {
		"type": "fate_threshold",
		"field": "civilians_escorted",
		"op": ">=",
		"value": 3,
	}
	return c
