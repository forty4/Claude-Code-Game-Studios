## ScenarioRunner cascade_join_announced emit tests (S65+, 영걸전식 narrative).
##
## CHAPTER_START 진입 시 직전 챕터 outcome 이 signature_branch_key 였고 현재
## 챕터가 그 키에 매핑된 cascade_join_prose entry 를 authored 했으면
## GameBus.cascade_join_announced(signature_key, text_key) emit. 5 영웅 cascade
## 합류 인사 1회 발화 보장.
##
## Covers:
##   - 시그니처 직후 챕터 진입 + cascade_join_prose 매칭 → emit
##   - 비-시그니처 키 직후 → emit 안 함
##   - cascade_join_prose 미선언 (빈 dict) → emit 안 함
##   - cascade_join_prose 선언했지만 직전 outcome key 매칭 entry 없음 → emit 안 함
##   - chapter 1 진입 (_chapter_outcomes 비어있음) → emit 안 함
extends GdUnitTestSuite


var _captures: Array = []
var _signal_capture: Callable


func before_test() -> void:
	_captures = []
	_signal_capture = func(sig_key: String, text_key: String) -> void:
		_captures.append({"signature_key": sig_key, "text_key": text_key})
	if not GameBus.cascade_join_announced.is_connected(_signal_capture):
		GameBus.cascade_join_announced.connect(_signal_capture)


func after_test() -> void:
	if GameBus.cascade_join_announced.is_connected(_signal_capture):
		GameBus.cascade_join_announced.disconnect(_signal_capture)
	_captures.clear()


# ─── Helpers ──────────────────────────────────────────────────────────────────


func _make_chapter(
	chapter_id: String,
	chapter_number: int,
	cascade_join_prose: Dictionary = {},
) -> ChapterDefinition:
	var c: ChapterDefinition = ChapterDefinition.new()
	c.chapter_id = chapter_id
	c.chapter_number = chapter_number
	c.map_id = "mvp_chapter_%02d" % chapter_number
	c.author_draw_branch = false
	c.echo_threshold = 1 if chapter_number > 1 else 0
	c.branch_table = {"WIN_default": "WIN_%s" % chapter_id}
	c.canonical_branch_key = "WIN_%s" % chapter_id
	c.cascade_join_prose = cascade_join_prose.duplicate(true)
	return c


# ─── Happy path: signature key 직후 cascade_join emit ─────────────────────────


## 직전 챕터가 시그니처 키 해소 + 현재 챕터에 cascade_join_prose 매칭 entry
## → emit. 위연 ch14 시나리오를 시뮬레이트.
func test_cascade_join_emits_when_prior_outcome_matches_signature_key() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	# ch_prior: signature 키 해소 챕터 (인메모리). ch_current: cascade entry.
	var ch_prior: ChapterDefinition = _make_chapter("ch_prior", 1)
	var ch_current: ChapterDefinition = _make_chapter(
		"ch_current",
		2,
		{"WIN_test_signature": "test.cascade_join.alpha"},
	)
	runner._set_chapters_for_test(
		[ch_prior, ch_current] as Array[ChapterDefinition], "test_cascade"
	)
	runner._set_signature_branches_for_test(PackedStringArray(["WIN_test_signature"]))
	runner._set_chapter_outcomes_for_test([{
		"chapter_id": "ch_prior",
		"branch_path_id": "WIN_test_signature",
		"echo_count_at_completion": 0,
		"outcome": 0,
	}])
	# Advance to current chapter.
	runner._chapter_index = 1
	runner._enter_chapter_start()
	# Verify emit.
	assert_int(_captures.size()).override_failure_message(
		"cascade_join_announced must emit exactly once for signature → cascade match"
	).is_equal(1)
	assert_str(_captures[0].signature_key as String).is_equal("WIN_test_signature")
	assert_str(_captures[0].text_key as String).is_equal("test.cascade_join.alpha")


# ─── Negative cases: no emit ──────────────────────────────────────────────────


## 직전 outcome 이 비-signature 키 → emit 안 함. legacy single-step branches
## (e.g., WIN_changbanpo_lord_unharmed) 가 cascade emit 트리거하지 않음을 보장.
func test_cascade_join_no_emit_when_prior_outcome_not_in_signature_set() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var ch: ChapterDefinition = _make_chapter(
		"ch_current",
		2,
		{"WIN_test_signature": "test.cascade_join.alpha"},
	)
	runner._set_chapters_for_test([ch] as Array[ChapterDefinition], "test_cascade")
	runner._set_signature_branches_for_test(PackedStringArray(["WIN_test_signature"]))
	runner._set_chapter_outcomes_for_test([{
		"chapter_id": "ch_prior",
		"branch_path_id": "WIN_legacy_non_signature",
		"echo_count_at_completion": 0,
		"outcome": 0,
	}])
	runner._chapter_index = 0
	runner._enter_chapter_start()
	assert_int(_captures.size()).override_failure_message(
		"비-signature 직전 outcome 은 cascade emit 트리거 안 함"
	).is_equal(0)


## cascade_join_prose 빈 dict (대부분의 일반 챕터) → emit 안 함.
func test_cascade_join_no_emit_when_chapter_has_no_cascade_prose() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var ch: ChapterDefinition = _make_chapter("ch_current", 2)  # cascade_join_prose 빈 dict
	runner._set_chapters_for_test([ch] as Array[ChapterDefinition], "test_cascade")
	runner._set_signature_branches_for_test(PackedStringArray(["WIN_test_signature"]))
	runner._set_chapter_outcomes_for_test([{
		"chapter_id": "ch_prior",
		"branch_path_id": "WIN_test_signature",
		"echo_count_at_completion": 0,
		"outcome": 0,
	}])
	runner._chapter_index = 0
	runner._enter_chapter_start()
	assert_int(_captures.size()).is_equal(0)


## cascade_join_prose 선언했지만 직전 outcome key 와 매칭되는 entry 없음
## → emit 안 함. 한 챕터가 여러 cascade 키 entry 를 authored 할 수 있는
## 미래 확장에 대비한 부분 매칭 보호.
func test_cascade_join_no_emit_when_prose_dict_missing_matching_key() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var ch: ChapterDefinition = _make_chapter(
		"ch_current",
		2,
		{"WIN_other_signature": "test.cascade_join.other"},
	)
	runner._set_chapters_for_test([ch] as Array[ChapterDefinition], "test_cascade")
	runner._set_signature_branches_for_test(PackedStringArray([
		"WIN_test_signature", "WIN_other_signature",
	]))
	runner._set_chapter_outcomes_for_test([{
		"chapter_id": "ch_prior",
		"branch_path_id": "WIN_test_signature",  # cascade_join_prose 에 매칭 entry 없음
		"echo_count_at_completion": 0,
		"outcome": 0,
	}])
	runner._chapter_index = 0
	runner._enter_chapter_start()
	assert_int(_captures.size()).override_failure_message(
		"prose dict 에 매칭되는 시그니처 키 entry 없으면 emit 안 함"
	).is_equal(0)


## Chapter 1 진입 시 (_chapter_outcomes 비어있음) → emit 안 함. 첫 챕터부터
## 의미없는 cascade emit 차단.
func test_cascade_join_no_emit_at_chapter_one_with_empty_outcomes() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var ch: ChapterDefinition = _make_chapter(
		"ch_first",
		1,
		{"WIN_test_signature": "test.cascade_join.alpha"},
	)
	runner._set_chapters_for_test([ch] as Array[ChapterDefinition], "test_cascade")
	runner._set_signature_branches_for_test(PackedStringArray(["WIN_test_signature"]))
	# _chapter_outcomes 비어있음 (chapter 1 fresh start).
	runner._chapter_index = 0
	runner._enter_chapter_start()
	assert_int(_captures.size()).is_equal(0)


# ─── shu_canon_full integration sentinel ─────────────────────────────────────────────


# ─── pending_cascade_announcement cache + consume ────────────────────────────


## emit 시 _pending_cascade_announcement 에 cache 됨 (BattleScene consume 대상).
func test_pending_cascade_announcement_set_on_emit() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var ch_prior: ChapterDefinition = _make_chapter("ch_prior", 1)
	var ch_current: ChapterDefinition = _make_chapter(
		"ch_current",
		2,
		{"WIN_test_signature": "test.cascade_join.alpha"},
	)
	runner._set_chapters_for_test(
		[ch_prior, ch_current] as Array[ChapterDefinition], "test_cascade"
	)
	runner._set_signature_branches_for_test(PackedStringArray(["WIN_test_signature"]))
	runner._set_chapter_outcomes_for_test([{
		"chapter_id": "ch_prior",
		"branch_path_id": "WIN_test_signature",
		"echo_count_at_completion": 0,
		"outcome": 0,
	}])
	runner._chapter_index = 1
	runner._enter_chapter_start()
	var pending: Dictionary = runner.get_pending_cascade_announcement()
	assert_bool(pending.is_empty()).override_failure_message(
		"Cascade emit 직후 pending announcement cache 비어있으면 안 됨"
	).is_false()
	assert_str(pending.get("signature_key", "") as String).is_equal("WIN_test_signature")
	assert_str(pending.get("text_key", "") as String).is_equal("test.cascade_join.alpha")


## consume 은 1회만 동작 (이후엔 빈 dict 반환). retry-reload 시 cascade 중복 차단.
func test_consume_pending_cascade_announcement_is_idempotent() -> void:
	var runner: Node = ScenarioRunnerTestSeam.make_isolated_runner()
	auto_free(runner)
	var ch_prior: ChapterDefinition = _make_chapter("ch_prior", 1)
	var ch_current: ChapterDefinition = _make_chapter(
		"ch_current",
		2,
		{"WIN_test_signature": "test.cascade_join.alpha"},
	)
	runner._set_chapters_for_test(
		[ch_prior, ch_current] as Array[ChapterDefinition], "test_cascade"
	)
	runner._set_signature_branches_for_test(PackedStringArray(["WIN_test_signature"]))
	runner._set_chapter_outcomes_for_test([{
		"chapter_id": "ch_prior",
		"branch_path_id": "WIN_test_signature",
		"echo_count_at_completion": 0,
		"outcome": 0,
	}])
	runner._chapter_index = 1
	runner._enter_chapter_start()
	var first: Dictionary = runner.consume_pending_cascade_announcement()
	assert_bool(first.is_empty()).is_false()
	var second: Dictionary = runner.consume_pending_cascade_announcement()
	assert_bool(second.is_empty()).override_failure_message(
		"consume 두 번째 호출 시 빈 dict (idempotent)"
	).is_true()


# ─── shu_canon_full integration sentinel ─────────────────────────────────────────────


## shu_canon_full.json 의 5 cascade entry 챕터 (ch14/17/21/22/23) 가 모두
## cascade_join_prose entry 를 authored 했는지 데이터 sentinel.
func test_shu_canon_full_authors_all_five_cascade_join_prose_entries() -> void:
	var json_text: String = FileAccess.get_file_as_string("res://assets/data/scenarios/shu_canon_full.json")
	var data: Dictionary = JSON.parse_string(json_text) as Dictionary
	var by_id: Dictionary = {}
	for c: Variant in (data["chapters"] as Array):
		var d: Dictionary = c as Dictionary
		by_id[d.get("chapter_id", "") as String] = d
	# Expected: (chapter_id, signature_key, text_key) for each cascade hero's
	# first-join chapter.
	var expected: Array = [
		["ch14_jingzhou_consolidate", "WIN_changsha_wei_yan_defects",  "ch14.cascade_join.wei_yan"],
		["ch17_chengdu_gates",        "WIN_luofeng_pang_tong_lives",   "ch17.cascade_join.pang_tong"],
		["ch21_zhangfei_avenge",      "WIN_fancheng_guan_yu_survives", "ch21.cascade_join.guan_yu"],
		["ch22_yiling_burn",          "WIN_zhangfei_survives",         "ch22.cascade_join.zhang_fei"],
		["ch23_southern_pacify",      "WIN_yiling_liu_bei_survives",   "ch23.cascade_join.liu_bei"],
	]
	for entry_var: Variant in expected:
		var entry: Array = entry_var as Array
		var cid: String = entry[0] as String
		var sig_key: String = entry[1] as String
		var text_key: String = entry[2] as String
		var ch: Dictionary = by_id.get(cid, {}) as Dictionary
		var prose: Dictionary = ch.get("cascade_join_prose", {}) as Dictionary
		assert_bool(prose.has(sig_key)).override_failure_message(
			"%s cascade_join_prose must authored entry for '%s'" % [cid, sig_key]
		).is_true()
		assert_str(prose.get(sig_key, "") as String).is_equal(text_key)
