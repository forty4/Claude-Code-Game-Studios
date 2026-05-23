## ChapterSelect — production "챕터 선택" surface (S17 macro-loop, DEV menu 졸업).
##
## Entry from MainMenu's "새 시나리오" button. Presents the 16 MVP-demo chapters
## (shu_canon_main) as a 4×4 grid of cards. All chapters always selectable
## ("Always-all" model — per mvp-demo-16ch.md, chapter unlock not in scope; the
## demo wants the witness path to ch16 ★ visible from the start).
##
## Click a card → ScenarioRunner.reset_for_tests() + set_active_scenario_path()
## + jump_to_chapter() + change_scene_to_file(battle_scene). Same effect as the
## DEV chapter-jump popup, minus the debug-build gate (jump_to_chapter is the
## production sibling without the OS.has_feature("debug") refusal).
##
## "← 뒤로" returns to MainMenu without touching ScenarioRunner state.
##
## ★ markers on ch13 (위연 합류) and ch16 (방통 생존 — 시그니처 #1) hint at the
## destiny-branch beats the player can witness. Full reveal happens at Beat 8
## inside battle_scene; the card text only says the chapter exists.
##
## No `class_name` — loaded via the .tscn's script reference. Not an autoload.
extends Control


const _MAIN_MENU_SCENE_PATH: String = "res://scenes/main_menu/main_menu.tscn"
const _BATTLE_SCENE_PATH: String = "res://scenes/battle/battle_scene.tscn"
const _SCENARIO_PATH: String = "res://assets/data/scenarios/shu_canon_main.json"

## Per-chapter card content for the 16-chapter MVP demo. Tied to shu_canon_main.json
## chapter order (index = chapter_number - 1). Korean title + 1-line flavor + optional
## ★ marker for the 2 destiny-branch chapters (ch13 위연 / ch16 방통). Authoring
## reference: design/scenarios/yeong_geol_jeon_shu_master.md + the 25-ch attestation
## file at production/qa/evidence/phase-f-windowed-boot-attestation-25-chapters.md.
##
## `signature` field: empty string for normal chapters; descriptive marker for
## destiny-branch chapters that surface a ★ badge on the card. Order matters —
## card index → chapter_index passed to jump_to_chapter().
const _CHAPTER_CARDS: Array[Dictionary] = [
	{
		"number": 1,
		"title": "도원결의",
		"flavor": "황건적의 도륙 — 세 형제의 첫 맹세",
		"signature": "",
	},
	{
		"number": 2,
		"title": "호뢰관",
		"flavor": "여포의 일기당천 — 천하의 무위에 맞서다",
		"signature": "",
	},
	{
		"number": 3,
		"title": "서주 구원",
		"flavor": "조운 합류 — 백마장군의 첫 등장",
		"signature": "",
	},
	{
		"number": 4,
		"title": "박망파",
		"flavor": "제갈량의 화공 — 군사로서의 첫 진형",
		"signature": "",
	},
	{
		"number": 5,
		"title": "신야의 불",
		"flavor": "백성을 안고 떠나다 — 화공으로 시간을 사다",
		"signature": "",
	},
	{
		"number": 6,
		"title": "장판파",
		"flavor": "유비의 후퇴 — 백성과 함께 남하",
		"signature": "",
	},
	{
		"number": 7,
		"title": "장판교",
		"flavor": "장비 일성 — 다리 위에서 만 명을 막다",
		"signature": "",
	},
	{
		"number": 8,
		"title": "하구 외곽",
		"flavor": "황충 합류 — 노장의 활이 합류하다",
		"signature": "",
	},
	{
		"number": 9,
		"title": "적벽 전야",
		"flavor": "오촉 동맹 — 손권·주유와 손잡다",
		"signature": "",
	},
	{
		"number": 10,
		"title": "적벽",
		"flavor": "동남풍 화공 — 백만 대군이 강을 태우다",
		"signature": "",
	},
	{
		"number": 11,
		"title": "형주 평정",
		"flavor": "영릉·계양 4군 — 형주의 기반을 다지다",
		"signature": "",
	},
	{
		"number": 12,
		"title": "무릉의 늪",
		"flavor": "다리 하나의 도하점 — 좁은 길에 적을 가두다",
		"signature": "",
	},
	{
		"number": 13,
		"title": "장사 · 위연의 선택",
		"flavor": "한현의 충신을 살릴 것인가 — 위연의 합류 분기",
		"signature": "★ 위연 합류",
	},
	{
		"number": 14,
		"title": "형주 통합",
		"flavor": "도로망의 교차로 — 형주 정착의 마지막 정비",
		"signature": "",
	},
	{
		"number": 15,
		"title": "부수관",
		"flavor": "방통 합류 — 봉추가 진영에 오르다",
		"signature": "",
	},
	{
		"number": 16,
		"title": "낙봉파",
		"flavor": "봉추의 길 — 정찰이 운명을 바꾼다",
		"signature": "★ 방통 생존 (시그니처 #1)",
	},
]


func _ready() -> void:
	# Build the 4×4 grid of chapter cards. Done in code (not .tscn) so the
	# card layout stays single-sourced with the _CHAPTER_CARDS metadata. A
	# headless test mount sees the same structure as a windowed launch.
	var grid: GridContainer = $Center/Box/Grid as GridContainer
	if grid != null:
		_populate_grid(grid)
	var back_button: Button = $Center/Box/Footer/BackButton as Button
	if back_button != null:
		back_button.pressed.connect(_on_back_pressed)
		back_button.grab_focus.call_deferred()


# ─── Grid population ──────────────────────────────────────────────────────────

func _populate_grid(grid: GridContainer) -> void:
	# Defensive clear in case _ready is called twice (test re-mount pattern).
	for child in grid.get_children():
		child.queue_free()
	for i in _CHAPTER_CARDS.size():
		var card: Dictionary = _CHAPTER_CARDS[i]
		var btn: Button = _make_card_button(i, card)
		grid.add_child(btn)


func _make_card_button(chapter_index: int, card: Dictionary) -> Button:
	var btn: Button = Button.new()
	btn.name = "ChapterCard_%02d" % (chapter_index + 1)
	btn.custom_minimum_size = Vector2(280, 110)
	btn.add_theme_font_size_override("font_size", 14)
	# Multi-line button text — number / title (with optional ★) / flavor.
	# Button has clip_text=false by default in 4.6 so the 3 lines render.
	var sig: String = card["signature"] as String
	var title_line: String = "제%d장 · %s" % [card["number"], card["title"]]
	if not sig.is_empty():
		title_line += "  " + sig
	btn.text = "%s\n%s" % [title_line, card["flavor"]]
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Capture chapter_index in the binding — lambda primitive capture would
	# alias across iterations per G-4; using `bind()` is the safe form.
	btn.pressed.connect(_on_chapter_card_pressed.bind(chapter_index))
	return btn


# ─── Button handlers ──────────────────────────────────────────────────────────

func _on_chapter_card_pressed(chapter_index: int) -> void:
	var runner: Node = get_node_or_null("/root/ScenarioRunner")
	if runner == null:
		push_warning("ChapterSelect: ScenarioRunner autoload missing")
		return
	# Drop any prior per-run state so the chapter starts clean. Mirrors the
	# DEV-jump and "새 시나리오" sequence in MainMenu.
	runner.reset_for_tests()
	runner.set_active_scenario_path(_SCENARIO_PATH)
	if not runner.jump_to_chapter(_SCENARIO_PATH, chapter_index):
		push_warning(
			"ChapterSelect: jump_to_chapter(%s, %d) refused"
				% [_SCENARIO_PATH, chapter_index]
		)
		return
	get_tree().change_scene_to_file(_BATTLE_SCENE_PATH)


func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(_MAIN_MENU_SCENE_PATH)
