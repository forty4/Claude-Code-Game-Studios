## chapter_select_test.gd
##
## Coverage for the S17 macro-loop "챕터 선택" surface (DEV menu 졸업).
## Production chapter selection scene replaces the pre-S17 direct
## new-scenario→battle-scene jump in main_menu.gd.
##
## Tests are Logic-level (constant data integrity) + scene-mount smoke
## (grid populates 16 cards). The click → ScenarioRunner.jump_to_chapter
## → change_scene_to_file chain is integration-level and is exercised by
## the windowed attestation pass (`production/qa/evidence/
## phase-f-windowed-boot-attestation-16-chapters.md`), not headless tests.
##
## Source-of-truth: src/feature/chapter_select/chapter_select.gd +
## scenes/chapter_select/chapter_select.tscn (S17).
extends GdUnitTestSuite


const _CHAPTER_SELECT_SCRIPT_PATH: String = "res://src/feature/chapter_select/chapter_select.gd"
const _CHAPTER_SELECT_SCENE_PATH: String = "res://scenes/chapter_select/chapter_select.tscn"
const _SCENARIO_RUNNER_SCRIPT_PATH: String = "res://src/core/scenario_runner.gd"


# ─── Constant-data integrity (Logic) ─────────────────────────────────────────

func test_chapter_cards_has_exactly_16_entries() -> void:
	var cards: Array = _read_chapter_cards()
	assert_int(cards.size()).override_failure_message(
		"_CHAPTER_CARDS must hold exactly 16 entries (MVP demo ch01-16 scope per "
		+ "production/milestones/mvp-demo-16ch.md). Got %d." % cards.size()
	).is_equal(16)


func test_chapter_cards_numbers_are_sequential_1_to_16() -> void:
	var cards: Array = _read_chapter_cards()
	for i: int in cards.size():
		var card: Dictionary = cards[i] as Dictionary
		var number: int = card["number"] as int
		assert_int(number).override_failure_message(
			"_CHAPTER_CARDS[%d].number must equal %d (1-indexed). Got %d." % [i, i + 1, number]
		).is_equal(i + 1)


func test_chapter_cards_all_have_nonempty_title() -> void:
	var cards: Array = _read_chapter_cards()
	for i: int in cards.size():
		var card: Dictionary = cards[i] as Dictionary
		var title: String = card["title"] as String
		assert_bool(title.is_empty()).override_failure_message(
			"_CHAPTER_CARDS[%d].title must be non-empty (chapter card needs a player-visible title)." % i
		).is_false()


func test_chapter_cards_all_have_nonempty_flavor() -> void:
	var cards: Array = _read_chapter_cards()
	for i: int in cards.size():
		var card: Dictionary = cards[i] as Dictionary
		var flavor: String = card["flavor"] as String
		assert_bool(flavor.is_empty()).override_failure_message(
			"_CHAPTER_CARDS[%d].flavor must be non-empty (rich card content requires 1-line flavor)." % i
		).is_false()


func test_chapter_cards_signature_chapters_are_ch13_and_ch16() -> void:
	# Per mvp-demo-16ch.md: ch16 방통 생존 ★ #1 + ch13 위연 합류 시그니처.
	# These are the 2 destiny-branch chapters in the MVP-demo range.
	var cards: Array = _read_chapter_cards()
	var marked: Array[int] = []
	for i: int in cards.size():
		var card: Dictionary = cards[i] as Dictionary
		var sig: String = card["signature"] as String
		if not sig.is_empty():
			marked.append(i + 1)
	# Sort for deterministic comparison.
	marked.sort()
	assert_array(marked).override_failure_message(
		"Exactly ch13 + ch16 should carry a ★ signature marker. Marked chapters: %s."
		% str(marked)
	).is_equal([13, 16])


func test_chapter_cards_ch16_signature_mentions_pang_tong() -> void:
	# Sentinel: ch16 ★ is the demo's primary identity ("방통 생존"). The card
	# must surface that name so the player recognises the witness opportunity.
	var cards: Array = _read_chapter_cards()
	var ch16_signature: String = (cards[15] as Dictionary)["signature"] as String
	assert_bool(ch16_signature.contains("방통")).override_failure_message(
		"ch16 signature must mention '방통' (the demo's ★ #1 trigger). Got: %s" % ch16_signature
	).is_true()


func test_chapter_cards_ch13_signature_mentions_wei_yan() -> void:
	# Sentinel: ch13 ★ is the secondary destiny-branch chapter ("위연 합류").
	var cards: Array = _read_chapter_cards()
	var ch13_signature: String = (cards[12] as Dictionary)["signature"] as String
	assert_bool(ch13_signature.contains("위연")).override_failure_message(
		"ch13 signature must mention '위연' (위연 합류 branch). Got: %s" % ch13_signature
	).is_true()


# ─── Scene mount smoke (Logic — grid population) ─────────────────────────────

func test_scene_mount_populates_16_card_buttons() -> void:
	var scene: PackedScene = load(_CHAPTER_SELECT_SCENE_PATH) as PackedScene
	assert_object(scene).is_not_null()
	var root: Control = scene.instantiate() as Control
	auto_free(root)
	add_child(root)
	await get_tree().process_frame
	var grid: GridContainer = root.get_node("Center/Box/Grid") as GridContainer
	assert_object(grid).override_failure_message(
		"Grid node missing at Center/Box/Grid — scene layout drifted from script expectations."
	).is_not_null()
	assert_int(grid.get_child_count()).override_failure_message(
		"Grid must contain 16 ChapterCard buttons after _ready. Got %d." % grid.get_child_count()
	).is_equal(16)


func test_scene_mount_first_card_button_is_ch01() -> void:
	var scene: PackedScene = load(_CHAPTER_SELECT_SCENE_PATH) as PackedScene
	var root: Control = scene.instantiate() as Control
	auto_free(root)
	add_child(root)
	await get_tree().process_frame
	var grid: GridContainer = root.get_node("Center/Box/Grid") as GridContainer
	var first_card: Button = grid.get_child(0) as Button
	assert_object(first_card).is_not_null()
	assert_str(first_card.name).is_equal("ChapterCard_01")
	# ch01 should NOT carry a signature marker (no ★ in ch01 text).
	assert_bool(first_card.text.contains("★")).override_failure_message(
		"ch01 card should not carry a ★ signature marker. Got text: %s" % first_card.text
	).is_false()


func test_scene_mount_ch16_card_text_carries_signature_marker() -> void:
	# The card text composition is "제16장 · 낙봉파  ★ ... \n flavor".
	var scene: PackedScene = load(_CHAPTER_SELECT_SCENE_PATH) as PackedScene
	var root: Control = scene.instantiate() as Control
	auto_free(root)
	add_child(root)
	await get_tree().process_frame
	var grid: GridContainer = root.get_node("Center/Box/Grid") as GridContainer
	var ch16_card: Button = grid.get_child(15) as Button
	assert_str(ch16_card.name).is_equal("ChapterCard_16")
	assert_bool(ch16_card.text.contains("★")).override_failure_message(
		"ch16 card text must carry a visible ★ marker. Got: %s" % ch16_card.text
	).is_true()
	assert_bool(ch16_card.text.contains("방통")).override_failure_message(
		"ch16 card text must mention 방통. Got: %s" % ch16_card.text
	).is_true()


func test_scene_mount_back_button_exists() -> void:
	var scene: PackedScene = load(_CHAPTER_SELECT_SCENE_PATH) as PackedScene
	var root: Control = scene.instantiate() as Control
	auto_free(root)
	add_child(root)
	await get_tree().process_frame
	var back_button: Button = root.get_node("Center/Box/Footer/BackButton") as Button
	assert_object(back_button).override_failure_message(
		"BackButton missing at Center/Box/Footer/BackButton — scene layout drifted."
	).is_not_null()
	assert_str(back_button.text).is_equal("← 뒤로")


# ─── ScenarioRunner contract sentinel (Logic) ────────────────────────────────

func test_scenario_runner_exposes_production_jump_to_chapter_method() -> void:
	# ChapterSelect depends on the production sibling of dev_jump_to_chapter.
	# This sentinel guards against the method being removed/renamed without
	# updating chapter_select.gd.
	var script: GDScript = load(_SCENARIO_RUNNER_SCRIPT_PATH) as GDScript
	var method_list: Array = script.get_script_method_list()
	var found: bool = false
	for m: Dictionary in method_list:
		if (m["name"] as String) == "jump_to_chapter":
			found = true
			break
	assert_bool(found).override_failure_message(
		"ScenarioRunner.jump_to_chapter() method missing — chapter_select.gd depends on it. "
		+ "The DEV sibling dev_jump_to_chapter() exists but has an OS.has_feature('debug') gate "
		+ "that production chapter selection must NOT inherit."
	).is_true()


# ─── Helpers ─────────────────────────────────────────────────────────────────

func _read_chapter_cards() -> Array:
	# Access the script-level const via load + get_script_constant_map.
	var script: GDScript = load(_CHAPTER_SELECT_SCRIPT_PATH) as GDScript
	var consts: Dictionary = script.get_script_constant_map()
	return consts.get("_CHAPTER_CARDS", []) as Array
