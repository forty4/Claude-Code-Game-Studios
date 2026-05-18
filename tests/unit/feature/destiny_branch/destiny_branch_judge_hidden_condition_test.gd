## destiny_branch_judge_hidden_condition_test.gd
##
## Covers DefaultDestinyBranchJudge Row 2a (hidden-condition WIN) — the
## Pillar 2 (운명은 바꿀 수 있다) surface. Verifies:
##   • Hidden branch fires when predicate passes (WIN + condition met).
##   • Falls through to WIN_default when predicate fails.
##   • Falls through to WIN_default when fate_data empty.
##   • Falls through to WIN_default when hidden_branch_key absent.
##   • Hidden branch row is WIN-scoped — DRAW / LOSS unaffected.
##   • reserved_color_treatment flips correctly (hidden branch != canonical).
extends GdUnitTestSuite


# ─── Row 2a: hidden branch fires on WIN + predicate pass ──────────────────────


func test_win_with_hidden_condition_met_routes_to_hidden_branch() -> void:
	# Arrange — ch1 fixture with hidden_condition: assassin_kills >= 2.
	var chapter: ChapterDefinition = _make_ch1_with_hidden_fixture()
	var fate: Dictionary = {"assassin_kills": 2}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	# Act
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true, fate
	)
	# Assert
	assert_str(choice.branch_key).is_equal("WIN_ch1_lord_unharmed")
	assert_bool(choice.is_invalid).is_false()
	assert_bool(choice.is_canonical_history).is_false()
	# Hidden branch differs from canonical → reserved_color_treatment ON.
	assert_bool(choice.reserved_color_treatment).is_true()


func test_win_with_hidden_condition_far_exceeded_still_routes_hidden() -> void:
	var chapter: ChapterDefinition = _make_ch1_with_hidden_fixture()
	var fate: Dictionary = {"assassin_kills": 99}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true, fate
	)
	assert_str(choice.branch_key).is_equal("WIN_ch1_lord_unharmed")


# ─── Row 2a fall-through to Row 2 (WIN_default) ───────────────────────────────


func test_win_with_hidden_condition_below_threshold_routes_to_win_default() -> void:
	var chapter: ChapterDefinition = _make_ch1_with_hidden_fixture()
	var fate: Dictionary = {"assassin_kills": 1}  # below threshold
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true, fate
	)
	assert_str(choice.branch_key).is_equal("WIN_ch1_default")
	assert_bool(choice.is_canonical_history).is_true()
	assert_bool(choice.reserved_color_treatment).is_false()


func test_win_with_empty_fate_data_routes_to_win_default() -> void:
	var chapter: ChapterDefinition = _make_ch1_with_hidden_fixture()
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	# fate_data omitted → defaults to {} per resolve() signature.
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true
	)
	assert_str(choice.branch_key).is_equal("WIN_ch1_default")


func test_win_with_hidden_branch_key_absent_uses_win_default() -> void:
	# Chapter with NO hidden_branch_key authored — even if fate_data has the
	# threshold value, no hidden row exists to route to.
	var chapter: ChapterDefinition = _make_ch1_no_hidden_fixture()
	var fate: Dictionary = {"assassin_kills": 99}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true, fate
	)
	assert_str(choice.branch_key).is_equal("WIN_ch1_default")


func test_win_with_hidden_key_declared_but_no_branch_table_entry_falls_through() -> void:
	# Authoring drift: hidden_branch_key declared but branch_table missing the
	# corresponding entry. Resolver falls through to WIN_default rather than
	# emitting an empty branch_key (which would trip post-call guard).
	var chapter: ChapterDefinition = _make_ch1_with_hidden_fixture()
	chapter.branch_table = {
		"WIN_default":  "WIN_ch1_default",
		"LOSS_default": "LOSS_ch1_default",
		# "WIN_hidden" entry deliberately removed
	}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true, {"assassin_kills": 99}
	)
	assert_str(choice.branch_key).is_equal("WIN_ch1_default")
	assert_bool(choice.is_invalid).is_false()


# ─── Row 2a is WIN-scoped — DRAW / LOSS bypass hidden row ─────────────────────


func test_loss_with_hidden_condition_met_still_routes_to_loss_default() -> void:
	var chapter: ChapterDefinition = _make_ch1_with_hidden_fixture()
	var fate: Dictionary = {"assassin_kills": 99}  # would meet condition
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.LOSS, 0, true, fate
	)
	assert_str(choice.branch_key).is_equal("LOSS_ch1_default")


func test_draw_fallback_with_hidden_condition_met_still_routes_to_win_default() -> void:
	# DRAW outcome on a chapter that does NOT author_draw_branch → fallback to
	# WIN row per Row 1. Even with hidden condition met in fate_data, the
	# DRAW-fallback path takes precedence (Row 1 fires before Row 2a).
	var chapter: ChapterDefinition = _make_ch1_with_hidden_fixture()
	var fate: Dictionary = {"assassin_kills": 99}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.DRAW, 0, true, fate
	)
	assert_str(choice.branch_key).is_equal("WIN_ch1_default")
	assert_bool(choice.is_draw_fallback).is_true()


# ─── Back-compat: resolve() default fate_data arg ─────────────────────────────


func test_resolve_with_default_fate_data_arg_still_works_on_non_hidden_chapter() -> void:
	# Ensures the new 5th param (fate_data: Dictionary = {}) is fully back-
	# compatible with the prior 4-arg call pattern used by existing tests.
	var chapter: ChapterDefinition = _make_ch1_no_hidden_fixture()
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true
	)
	assert_str(choice.branch_key).is_equal("WIN_ch1_default")
	assert_bool(choice.is_invalid).is_false()


# ─── Fixtures ─────────────────────────────────────────────────────────────────


func _make_ch1_with_hidden_fixture() -> ChapterDefinition:
	var c: ChapterDefinition = ChapterDefinition.new()
	c.chapter_id = "ch1"
	c.chapter_number = 1
	c.author_draw_branch = false
	c.echo_threshold = 0
	c.branch_table = {
		"WIN_default":  "WIN_ch1_default",
		"WIN_hidden":   "WIN_ch1_lord_unharmed",
		"LOSS_default": "LOSS_ch1_default",
	}
	c.canonical_branch_key = "WIN_ch1_default"
	c.hidden_branch_key = "WIN_hidden"
	c.hidden_condition = {
		"type": "fate_threshold",
		"field": "assassin_kills",
		"op": ">=",
		"value": 2,
	}
	return c


func _make_ch1_no_hidden_fixture() -> ChapterDefinition:
	var c: ChapterDefinition = ChapterDefinition.new()
	c.chapter_id = "ch1"
	c.chapter_number = 1
	c.author_draw_branch = false
	c.echo_threshold = 0
	c.branch_table = {
		"WIN_default":  "WIN_ch1_default",
		"LOSS_default": "LOSS_ch1_default",
	}
	c.canonical_branch_key = "WIN_ch1_default"
	# hidden_branch_key + hidden_condition left at defaults (empty)
	return c


# ─── Row 2a-legendary (S65+) — 영걸전식 finale 전설 분기 ─────────────────────


func _make_ch25_legendary_fixture() -> ChapterDefinition:
	## ch25-shaped fixture: hidden tier + legendary tier both authored.
	## hidden fires when qixing_turns >= 3 (relief-eased), legendary fires
	## additionally when active_signature_count >= 5.
	var c: ChapterDefinition = ChapterDefinition.new()
	c.chapter_id = "ch25_legendary_test"
	c.chapter_number = 25
	c.author_draw_branch = false
	c.echo_threshold = 1
	c.branch_table = {
		"WIN_default":   "WIN_canonical_falls",
		"WIN_hidden":    "WIN_hidden_revives",
		"WIN_legendary": "WIN_legendary_dawn",
		"LOSS_default":  "LOSS_consumed",
	}
	c.canonical_branch_key = "WIN_canonical_falls"
	c.hidden_branch_key = "WIN_hidden"
	c.hidden_condition = {"type": "fate_threshold", "field": "qixing_turns", "op": ">=", "value": 3}
	c.legendary_branch_key = "WIN_legendary"
	c.legendary_condition = {
		"type": "fate_threshold", "field": "active_signature_count", "op": ">=", "value": 5,
	}
	return c


## Both conditions satisfied → legendary tier wins (highest priority).
func test_win_with_hidden_AND_legendary_conditions_routes_to_legendary() -> void:
	var chapter: ChapterDefinition = _make_ch25_legendary_fixture()
	var fate: Dictionary = {"qixing_turns": 6, "active_signature_count": 5}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true, fate
	)
	assert_str(choice.branch_key).override_failure_message(
		"5 시그니처 + qixing 6턴 → 전설의 새벽 ENDING"
	).is_equal("WIN_legendary_dawn")
	assert_bool(choice.is_canonical_history).is_false()


## hidden满足, legendary 조건 부족 → hidden fallback (기존 동작 보존).
func test_win_with_hidden_met_but_legendary_below_routes_to_hidden() -> void:
	var chapter: ChapterDefinition = _make_ch25_legendary_fixture()
	var fate: Dictionary = {"qixing_turns": 6, "active_signature_count": 3}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true, fate
	)
	assert_str(choice.branch_key).override_failure_message(
		"3 시그니처 < 5 → legendary 조건 미충족 → hidden tier 유지"
	).is_equal("WIN_hidden_revives")


## hidden 미충족 시 legendary 평가 자체 안 함 → WIN_default.
## Critical: legendary는 hidden을 require함. 시그니처만 모았다고 발동 안 됨.
func test_win_with_hidden_unmet_skips_legendary_and_routes_to_win_default() -> void:
	var chapter: ChapterDefinition = _make_ch25_legendary_fixture()
	# 5 signatures active but qixing 0 → hidden 미충족 → legendary 평가 안 됨.
	var fate: Dictionary = {"qixing_turns": 0, "active_signature_count": 5}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true, fate
	)
	assert_str(choice.branch_key).override_failure_message(
		"hidden 미충족이면 legendary는 평가도 안 함 → canonical WIN_default"
	).is_equal("WIN_canonical_falls")


## legendary_branch_key 비어있음 (정상 hidden 챕터) → 기존 hidden 동작 100% 동일.
## Regression guard for non-finale 챕터들 — ch02~ch24 모두 영향 없음.
func test_win_with_hidden_only_no_legendary_field_routes_to_hidden_as_before() -> void:
	var chapter: ChapterDefinition = _make_ch1_with_hidden_fixture()
	# 아무리 active_signature_count가 5여도 legendary_branch_key 비어있으면 변화 없음.
	var fate: Dictionary = {"assassin_kills": 2, "active_signature_count": 99}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true, fate
	)
	assert_str(choice.branch_key).override_failure_message(
		"legendary 미선언 챕터: 기존 hidden 동작 변경 없음"
	).is_equal("WIN_ch1_lord_unharmed")


## legendary_branch_key가 branch_table에 entry 없음 → graceful fallback to hidden.
## Authoring 실수 방어 (validate가 잡지만 런타임에서도 fall-through).
func test_legendary_key_missing_from_branch_table_falls_through_to_hidden() -> void:
	var chapter: ChapterDefinition = _make_ch25_legendary_fixture()
	# Simulate authoring 실수: legendary_branch_key는 있지만 branch_table 엔트리 삭제.
	chapter.branch_table = {
		"WIN_default":  "WIN_canonical_falls",
		"WIN_hidden":   "WIN_hidden_revives",
		"LOSS_default": "LOSS_consumed",
	}
	var fate: Dictionary = {"qixing_turns": 6, "active_signature_count": 5}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.WIN, 0, true, fate
	)
	assert_str(choice.branch_key).override_failure_message(
		"legendary_branch_key declared but missing from branch_table → hidden fallback"
	).is_equal("WIN_hidden_revives")


## LOSS outcome bypasses both hidden and legendary tiers.
func test_loss_skips_legendary_tier_and_routes_to_loss_default() -> void:
	var chapter: ChapterDefinition = _make_ch25_legendary_fixture()
	var fate: Dictionary = {"qixing_turns": 6, "active_signature_count": 5}
	var judge: DefaultDestinyBranchJudge = DefaultDestinyBranchJudge.new()
	var choice: DestinyBranchChoice = judge.resolve(
		chapter, BattleOutcome.Result.LOSS, 0, true, fate
	)
	assert_str(choice.branch_key).is_equal("LOSS_consumed")
