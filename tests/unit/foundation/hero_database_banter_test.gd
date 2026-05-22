extends GdUnitTestSuite

## hero_database_banter_test.gd
## S73 backfill — S72 Hero banter system (commit `4edabb2`).
## Covers HeroDatabase.get_banter() — lazy load, hero × event lookup, graceful
## empty-string fallback for unmapped cases, and 5 cascade 영웅 × 5 event
## regression sentinel (25-line authoring contract).
##
## TEST ISOLATION (G-15 + ADR-0006 §6):
##   before_test()/after_test() reset _banter_loaded + _banter static vars
##   so each test sees a clean cache. Synthetic injection helper used for
##   lookup tests; real JSON load exercised by lazy-load + sentinel tests.

const _HD_PATH: String = "res://src/foundation/hero_database.gd"
var _hd_script: GDScript = load(_HD_PATH) as GDScript


func before_test() -> void:
	_hd_script.set("_banter_loaded", false)
	var empty: Dictionary[StringName, Dictionary] = {}
	_hd_script.set("_banter", empty)


func after_test() -> void:
	_hd_script.set("_banter_loaded", false)
	var empty: Dictionary[StringName, Dictionary] = {}
	_hd_script.set("_banter", empty)


## Injects a synthetic banter fixture, bypassing file I/O. Use in Arrange when
## the test asserts lookup behavior rather than load behavior.
func _inject_synthetic_banter() -> void:
	var banter: Dictionary[StringName, Dictionary] = {
		&"shu_002_guan_yu": {
			"battle_start": "운명이 다하기 전엔 물러나지 않는다.",
			"player_kill": "한 명 줄었군.",
		},
		&"shu_003_zhang_fei": {
			"battle_start": "와하하! 다 덤벼라!",
		},
	}
	_hd_script.set("_banter", banter)
	_hd_script.set("_banter_loaded", true)


# ── get_banter() — happy path ──

func test_get_banter_returns_mapped_line_for_known_hero_event() -> void:
	# Arrange
	_inject_synthetic_banter()

	# Act
	var line: String = HeroDatabase.get_banter(&"shu_002_guan_yu", "battle_start")

	# Assert
	assert_str(line).is_equal("운명이 다하기 전엔 물러나지 않는다.")


func test_get_banter_returns_distinct_lines_per_event_for_same_hero() -> void:
	_inject_synthetic_banter()
	var battle: String = HeroDatabase.get_banter(&"shu_002_guan_yu", "battle_start")
	var kill: String = HeroDatabase.get_banter(&"shu_002_guan_yu", "player_kill")
	assert_str(battle).is_not_equal(kill)
	assert_str(battle).is_equal("운명이 다하기 전엔 물러나지 않는다.")
	assert_str(kill).is_equal("한 명 줄었군.")


# ── get_banter() — graceful empty paths ──

func test_get_banter_returns_empty_for_unmapped_hero() -> void:
	_inject_synthetic_banter()
	var line: String = HeroDatabase.get_banter(&"qun_001_lu_bu", "battle_start")
	assert_str(line).is_equal("")


func test_get_banter_returns_empty_for_mapped_hero_unmapped_event() -> void:
	_inject_synthetic_banter()
	# shu_003_zhang_fei in synthetic fixture only has "battle_start" mapped.
	var line: String = HeroDatabase.get_banter(&"shu_003_zhang_fei", "outcome_win")
	assert_str(line).is_equal("")


func test_get_banter_returns_empty_for_unknown_event_key() -> void:
	_inject_synthetic_banter()
	var line: String = HeroDatabase.get_banter(&"shu_002_guan_yu", "nonexistent_event")
	assert_str(line).is_equal("")


# ── Lazy load behavior ──

func test_get_banter_triggers_lazy_load_on_first_call() -> void:
	# No injection — let real JSON load fire.
	assert_bool(_hd_script.get("_banter_loaded") as bool).is_false()
	HeroDatabase.get_banter(&"shu_001_liu_bei", "battle_start")
	assert_bool(_hd_script.get("_banter_loaded") as bool).is_true()


func test_get_banter_idempotent_load_does_not_repopulate() -> void:
	# First call triggers load; capture cache snapshot.
	HeroDatabase.get_banter(&"shu_001_liu_bei", "battle_start")
	var snapshot: Dictionary = _hd_script.get("_banter") as Dictionary
	var snapshot_size: int = snapshot.size()
	# Second call must not re-load (no duplicate keys, same size).
	HeroDatabase.get_banter(&"shu_002_guan_yu", "battle_start")
	var post: Dictionary = _hd_script.get("_banter") as Dictionary
	assert_int(post.size()).is_equal(snapshot_size)


# ── Schema key filtering ──

func test_load_skips_underscore_prefixed_meta_keys() -> void:
	# Real JSON load. _schema / _events / _authoring_notes must NOT become
	# hero entries — _load_banter filters keys starting with "_".
	HeroDatabase.get_banter(&"shu_001_liu_bei", "battle_start")
	var banter: Dictionary = _hd_script.get("_banter") as Dictionary
	assert_bool(banter.has(&"_schema")).override_failure_message(
		"_load_banter must skip underscore-prefixed meta keys (got _schema in cache)"
	).is_false()
	assert_bool(banter.has(&"_events")).is_false()
	assert_bool(banter.has(&"_authoring_notes")).is_false()


# ── 5 cascade 영웅 × 5 event regression sentinel ──

func test_get_banter_5_cascade_heroes_all_5_events_authored() -> void:
	# Real JSON load. Sentinel: 5 영웅 × 5 events = 25 lines, all non-empty,
	# enforces the S72 authoring contract (commit `4edabb2`). Catches
	# regressions where a line is accidentally deleted from JSON.
	var heroes: Array[StringName] = [
		&"shu_001_liu_bei",
		&"shu_002_guan_yu",
		&"shu_003_zhang_fei",
		&"shu_007_pang_tong",
		&"shu_009_wei_yan",
	]
	var events: Array[String] = [
		"battle_start",
		"player_kill",
		"low_hp",
		"outcome_win",
		"outcome_loss",
	]
	var missing: Array[String] = []
	for hero: StringName in heroes:
		for event: String in events:
			var line: String = HeroDatabase.get_banter(hero, event)
			if line.is_empty():
				missing.append("%s × %s" % [hero, event])
	assert_int(missing.size()).override_failure_message(
		("S72 banter contract violated — 5 cascade 영웅 × 5 events = 25 lines"
		+ " required, missing: %s") % str(missing)
	).is_equal(0)


func test_get_banter_voice_distinction_no_dupe_battle_start() -> void:
	# Cross-hero voice distinction sentinel: 5 영웅 의 battle_start 가 모두 달라야
	# (S72 design — voice contrast required per JSON _authoring_notes). 같은 텍스트
	# 발견 시 voice merge 가 일어났다는 신호.
	var heroes: Array[StringName] = [
		&"shu_001_liu_bei",
		&"shu_002_guan_yu",
		&"shu_003_zhang_fei",
		&"shu_007_pang_tong",
		&"shu_009_wei_yan",
	]
	var lines: Dictionary[String, StringName] = {}
	for hero: StringName in heroes:
		var line: String = HeroDatabase.get_banter(hero, "battle_start")
		if lines.has(line):
			assert_bool(false).override_failure_message(
				"battle_start voice collision: %s and %s both say '%s'"
				% [lines[line], hero, line]
			).is_true()
		lines[line] = hero
