# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does the existing GAME CONCEPT (formation tactics + hidden fate
#   branches + role differentiation + scenario story integration) work as a
#   coherent loop?
# Date: 2026-05-02
# Scope: 1 chapter ("장판파") with 4 phases (story → party → battle → fate result)

extends Control

const BattleV2 := preload("res://prototypes/chapter-prototype/battle_v2.gd")

# ─── Story dialog (Phase 1) ──────────────────────────────────────────────────

const STORY_DIALOG: Array[String] = [
	"건안 13년 (208년) — 조조의 50만 대군이 신야성을 위협한다.",
	"유비는 백성과 함께 강하로 후퇴하지만, 조조의 정예 기병이 장판파에서 따라잡았다.",
	"조운은 유선과 미부인을 찾아 적진을 헤집는다.\n장비는 다리 위에서 추격을 막아선다.",
	"역사대로라면 — 미부인은 우물에 몸을 던지고, 조운은 유선만 안고 빠져나온다.\n비극은 정해진 대로 흘러갈 것이다.",
	"하지만 만약, 충분히 치밀한 전략가라면…\n운명을 거스를 수 있을지도 모른다.",
]

# ─── Hero pool for party select (Phase 2) ────────────────────────────────────

const HERO_OPTIONS: Array[Dictionary] = [
	{"id": "liu_bei",     "name": "유비",   "role": "사령관",        "desc": "인접 아군 +15% ATK (명령 오라)",            "selectable": true},
	{"id": "guan_yu",     "name": "관우",   "role": "주력 무장",     "desc": "양양으로 출정 중 — 이번 전투 참전 불가",     "selectable": false},
	{"id": "zhang_fei",   "name": "장비",   "role": "탱커",          "desc": "다리 봉쇄: 인접한 적의 이동력 -1",           "selectable": true, "forced": true},
	{"id": "zhao_yun",    "name": "조운",   "role": "기병 어쌔신",   "desc": "이동력 5 — 빠르게 적진 침투 가능",           "selectable": true, "forced": true},
	{"id": "huang_zhong", "name": "황충",   "role": "궁병",          "desc": "사거리 2 + 후방 공격 시 추가 보너스",        "selectable": true},
]

# ─── Fate judgment thresholds (HIDDEN from player during battle) ─────────────

const FATE_THRESHOLD_TANK_HP: float = 0.60   # 장비 60% 이상 HP
const FATE_THRESHOLD_KILLS: int = 2          # 조운 적장 2명 이상
const FATE_THRESHOLD_REAR: int = 2           # 후방 공격 2회 이상
const FATE_THRESHOLD_FORMATION: int = 3      # 진형 active 턴 3 이상

# ─── Result text by fate branch ──────────────────────────────────────────────

const RESULT_HISTORICAL: String = """역사대로 흘러갔다.

미부인은 우물에 몸을 던졌고, 조운은 유선만 안고 적진을 빠져나왔다.
장비의 호령으로 조조군은 잠시 멈추었지만, 비극은 막을 수 없었다.

다음 장에서 — 유비는 강하에서 손권과 동맹을 맺어 적벽으로 향한다.

(역사가 정해진 대로 흘러갔습니다. 다시 도전하면 다른 결말을 볼 수 있을지도…)"""

const RESULT_REWRITTEN: String = """운명을 거슬렀다 ─ 역사가 바뀌었다!

장비의 호령이 조조군을 다리 너머로 밀어내고, 조운은 미부인과 유선을 모두
무사히 구출해냈다. 황충의 화살이 적장의 후방을 꿰뚫었고, 유비의 명령 아래
4명의 영웅은 완전한 진형을 이루었다.

미부인은 살아남았다. 유선의 어머니는 유비와 함께 강하로 향했다.
이 변화는 이후 적벽, 형주, 익주 — 삼국지 전체의 흐름에 연쇄적으로 영향을 미칠 것이다.

(숨겨진 운명 분기 조건을 모두 충족했습니다. 1/N 분기 발견.)"""

const RESULT_PARTIAL: String = """비극은 막았다 — 그러나 운명은 뒤집지 못했다.

장비와 조운은 살아남았고, 일부 조조군은 격퇴되었다. 하지만 미부인을
구하기에는 충분치 않았다. 그녀의 우물은 비어있지 않았다.

역사는 부분적으로 흔들렸지만, 큰 흐름은 그대로 흘러간다.

(일부 조건만 충족했습니다. 무엇을 다르게 해야 할까요?)"""

const RESULT_DEFEAT: String = """패배 — 다리는 무너지고, 영웅들은 흩어졌다.

장비는 쓰러졌고, 추격을 막아낼 자가 없었다. 유비의 일행은 적의 추격에
완전히 노출되었다.

(다음 회차에서 다른 전술을 시도해 보세요.)"""

# ─── Runtime state ───────────────────────────────────────────────────────────

var _phase: int = 0   # 0=story, 1=party, 2=battle, 3=result
var _story_index: int = 0
var _selected_party: Array[String] = ["zhang_fei", "zhao_yun"]  # forced members start selected
var _battle_outcome: Dictionary = {}

# Panel references (built dynamically in _ready)
var _story_panel: Control
var _party_panel: Control
var _battle_panel: Node2D
var _result_panel: Control

# ─── Lifecycle ──────────────────────────────────────────────────────────────

func _ready() -> void:
	# Resize window for prototype (820x720); restored by editor on quit
	if not Engine.is_editor_hint() and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(Vector2i(820, 760))
		DisplayServer.window_set_title("천명역전 — 장판파 [PROTOTYPE]")
	_build_all_panels()
	_show_story_phase()

# ─── Build: Phase 1 — Story panel ────────────────────────────────────────────

func _build_all_panels() -> void:
	# Background
	var bg: ColorRect = ColorRect.new()
	bg.size = Vector2(820, 720)
	bg.color = Color(0.06, 0.07, 0.10)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	_story_panel = _build_story_panel()
	_party_panel = _build_party_panel()
	_battle_panel = _build_battle_panel()
	_result_panel = _build_result_panel()

	add_child(_story_panel)
	add_child(_party_panel)
	add_child(_battle_panel)
	add_child(_result_panel)

	_story_panel.visible = false
	_party_panel.visible = false
	_battle_panel.visible = false
	_result_panel.visible = false

func _build_story_panel() -> Control:
	var panel: Control = Control.new()
	panel.name = "StoryPanel"
	panel.size = Vector2(820, 720)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var title: Label = Label.new()
	title.text = "장판파 (長坂坡)"
	title.position = Vector2(60, 80)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 0.8, 0.4))
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 4)
	panel.add_child(title)

	var subtitle: Label = Label.new()
	subtitle.text = "건안 13년 (208년) — 1장"
	subtitle.position = Vector2(60, 130)
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
	panel.add_child(subtitle)

	var body: Label = Label.new()
	body.name = "StoryBody"
	body.position = Vector2(60, 220)
	body.size = Vector2(700, 300)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 19)
	body.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	body.add_theme_constant_override("line_spacing", 12)
	panel.add_child(body)

	var continue_lbl: Label = Label.new()
	continue_lbl.text = "▶ 클릭하여 계속"
	continue_lbl.position = Vector2(620, 660)
	continue_lbl.add_theme_font_size_override("font_size", 14)
	continue_lbl.add_theme_color_override("font_color", Color(0.6, 0.8, 1.0))
	panel.add_child(continue_lbl)

	var progress: Label = Label.new()
	progress.name = "StoryProgress"
	progress.position = Vector2(60, 660)
	progress.add_theme_font_size_override("font_size", 12)
	progress.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	panel.add_child(progress)

	# Click handler — full-panel button overlay
	var click_button: Button = Button.new()
	click_button.size = Vector2(820, 720)
	click_button.flat = true
	click_button.pressed.connect(_on_story_advance)
	panel.add_child(click_button)

	return panel

func _build_party_panel() -> Control:
	var panel: Control = Control.new()
	panel.name = "PartyPanel"
	panel.size = Vector2(820, 720)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var title: Label = Label.new()
	title.text = "편성"
	title.position = Vector2(60, 60)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	panel.add_child(title)

	var instruction: Label = Label.new()
	instruction.text = "전투에 참전할 무장 4명을 선택하십시오. (장비, 조운은 자동 편성)"
	instruction.position = Vector2(60, 110)
	instruction.add_theme_font_size_override("font_size", 14)
	instruction.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	panel.add_child(instruction)

	# Hero cards
	var card_y_start: int = 160
	var card_h: int = 90
	for i in HERO_OPTIONS.size():
		var hero: Dictionary = HERO_OPTIONS[i]
		var card: Button = Button.new()
		card.name = "Card_" + String(hero["id"])
		card.position = Vector2(60, card_y_start + i * (card_h + 10))
		card.size = Vector2(700, card_h)
		card.toggle_mode = true
		var is_forced: bool = bool(hero.get("forced", false))
		var is_selectable: bool = bool(hero.get("selectable", true))
		card.disabled = not is_selectable or is_forced
		card.button_pressed = is_forced or (String(hero["id"]) in _selected_party)
		card.text = "%s [%s]\n%s" % [hero["name"], hero["role"], hero["desc"]]
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.add_theme_font_size_override("font_size", 14)
		if not is_selectable:
			card.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		card.toggled.connect(_on_party_toggle.bind(String(hero["id"])))
		panel.add_child(card)

	# Status + start button
	var status: Label = Label.new()
	status.name = "PartyStatus"
	status.position = Vector2(60, 660)
	status.add_theme_font_size_override("font_size", 14)
	panel.add_child(status)

	var start_btn: Button = Button.new()
	start_btn.name = "StartBattleButton"
	start_btn.text = "전투 시작 →"
	start_btn.position = Vector2(640, 655)
	start_btn.size = Vector2(120, 40)
	start_btn.add_theme_font_size_override("font_size", 16)
	start_btn.pressed.connect(_on_start_battle)
	panel.add_child(start_btn)

	return panel

func _build_battle_panel() -> Node2D:
	# Battle is a Node2D (not Control) because it builds its own grid via build_grid()
	var panel: Node2D = Node2D.new()
	panel.name = "BattlePanel"
	panel.position = Vector2(20, 20)
	return panel

func _build_result_panel() -> Control:
	var panel: Control = Control.new()
	panel.name = "ResultPanel"
	panel.size = Vector2(820, 720)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var title: Label = Label.new()
	title.name = "ResultTitle"
	title.position = Vector2(60, 80)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_outline_color", Color.BLACK)
	title.add_theme_constant_override("outline_size", 5)
	panel.add_child(title)

	var body: Label = Label.new()
	body.name = "ResultBody"
	body.position = Vector2(60, 170)
	body.size = Vector2(700, 380)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_theme_font_size_override("font_size", 17)
	body.add_theme_color_override("font_color", Color(0.92, 0.92, 0.92))
	body.add_theme_constant_override("line_spacing", 10)
	panel.add_child(body)

	var stats: Label = Label.new()
	stats.name = "ResultStats"
	stats.position = Vector2(60, 560)
	stats.size = Vector2(700, 80)
	stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stats.add_theme_font_size_override("font_size", 12)
	stats.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	panel.add_child(stats)

	var retry_btn: Button = Button.new()
	retry_btn.name = "RetryButton"
	retry_btn.text = "다시 도전"
	retry_btn.position = Vector2(60, 660)
	retry_btn.size = Vector2(140, 40)
	retry_btn.add_theme_font_size_override("font_size", 16)
	retry_btn.pressed.connect(_on_retry)
	panel.add_child(retry_btn)

	var quit_btn: Button = Button.new()
	quit_btn.name = "QuitButton"
	quit_btn.text = "종료"
	quit_btn.position = Vector2(660, 660)
	quit_btn.size = Vector2(100, 40)
	quit_btn.add_theme_font_size_override("font_size", 16)
	quit_btn.pressed.connect(_on_quit)
	panel.add_child(quit_btn)

	return panel

# ─── Phase transitions ───────────────────────────────────────────────────────

func _show_story_phase() -> void:
	_phase = 0
	_story_index = 0
	_story_panel.visible = true
	_party_panel.visible = false
	_battle_panel.visible = false
	_result_panel.visible = false
	_refresh_story()

func _refresh_story() -> void:
	var body: Label = _story_panel.get_node("StoryBody")
	body.text = STORY_DIALOG[_story_index]
	var prog: Label = _story_panel.get_node("StoryProgress")
	prog.text = "%d / %d" % [_story_index + 1, STORY_DIALOG.size()]

func _on_story_advance() -> void:
	if _phase != 0: return
	_story_index += 1
	if _story_index >= STORY_DIALOG.size():
		_show_party_phase()
	else:
		_refresh_story()

func _show_party_phase() -> void:
	_phase = 1
	_story_panel.visible = false
	_party_panel.visible = true
	_refresh_party_status()

func _on_party_toggle(hero_id: String, pressed: bool) -> void:
	if _phase != 1: return
	if pressed and not (hero_id in _selected_party):
		if _selected_party.size() >= 4:
			# Reject — cap at 4
			var card: Button = _party_panel.get_node("Card_" + hero_id)
			card.button_pressed = false
			return
		_selected_party.append(hero_id)
	elif not pressed and (hero_id in _selected_party):
		_selected_party.erase(hero_id)
	_refresh_party_status()

func _refresh_party_status() -> void:
	var status: Label = _party_panel.get_node("PartyStatus")
	var count: int = _selected_party.size()
	status.text = "선택됨: %d / 4" % count
	if count == 4:
		status.add_theme_color_override("font_color", Color(0.4, 0.9, 0.4))
	else:
		status.add_theme_color_override("font_color", Color(0.95, 0.7, 0.3))
	var btn: Button = _party_panel.get_node("StartBattleButton")
	btn.disabled = count != 4

func _on_start_battle() -> void:
	if _phase != 1: return
	if _selected_party.size() != 4: return
	_show_battle_phase()

func _show_battle_phase() -> void:
	_phase = 2
	_party_panel.visible = false
	_battle_panel.visible = true

	# Clear any prior battle instance
	for child in _battle_panel.get_children():
		_battle_panel.remove_child(child)
		child.queue_free()

	# Instantiate fresh BattleV2
	var battle: Node2D = BattleV2.new()
	battle.name = "BattleV2"

	# Battle needs a Grid + Units + HUD child node3 → create them so $Grid etc. resolve
	var grid: Node2D = Node2D.new(); grid.name = "Grid"; battle.add_child(grid)
	var units: Node2D = Node2D.new(); units.name = "Units"; battle.add_child(units)
	var hud: Control = Control.new(); hud.name = "HUD"; hud.size = Vector2(800, 120); hud.mouse_filter = Control.MOUSE_FILTER_IGNORE; battle.add_child(hud)

	battle.setup(_selected_party.duplicate())
	battle.battle_ended.connect(_on_battle_ended)
	_battle_panel.add_child(battle)

func _on_battle_ended(outcome: Dictionary) -> void:
	_battle_outcome = outcome
	_show_result_phase()

func _show_result_phase() -> void:
	_phase = 3
	_battle_panel.visible = false
	_result_panel.visible = true
	_judge_fate()

func _judge_fate() -> void:
	var fate: Dictionary = _battle_outcome.get("fate_data", {})
	var any_player_alive: bool = false
	var any_enemy_alive: bool = false
	for u: Dictionary in _battle_outcome.get("units", []) as Array:
		if bool(u["dead"]): continue
		if int(u["side"]) == 0: any_player_alive = true
		else: any_enemy_alive = true

	# Branch logic
	var branch: String = ""
	var title_text: String = ""
	var title_color: Color = Color.WHITE
	var body_text: String = ""

	if not any_player_alive:
		branch = "DEFEAT"
		title_text = "패배 (DEFEAT)"
		title_color = Color(0.95, 0.3, 0.3)
		body_text = RESULT_DEFEAT
	else:
		# Check the 5 hidden conditions
		var c1: bool = float(fate.get("tank_alive_hp_pct", 0.0)) >= FATE_THRESHOLD_TANK_HP
		var c2: bool = int(fate.get("assassin_kills", 0)) >= FATE_THRESHOLD_KILLS
		var c3: bool = int(fate.get("rear_attacks", 0)) >= FATE_THRESHOLD_REAR
		var c4: bool = int(fate.get("formation_turns", 0)) >= FATE_THRESHOLD_FORMATION
		var c5: bool = bool(fate.get("boss_killed", false))
		var conditions_met: int = (1 if c1 else 0) + (1 if c2 else 0) + (1 if c3 else 0) + (1 if c4 else 0) + (1 if c5 else 0)

		if c1 and c2 and c3 and c4 and c5:
			branch = "REWRITTEN"
			title_text = "운명 역전 (HISTORY REWRITTEN!)"
			title_color = Color(1, 0.85, 0.2)
			body_text = RESULT_REWRITTEN
		elif any_enemy_alive and conditions_met < 3:
			branch = "HISTORICAL"
			title_text = "역사대로 (HISTORICAL OUTCOME)"
			title_color = Color(0.65, 0.65, 0.7)
			body_text = RESULT_HISTORICAL
		else:
			branch = "PARTIAL"
			title_text = "부분 성공 (PARTIAL)"
			title_color = Color(0.6, 0.85, 0.95)
			body_text = RESULT_PARTIAL

	var title: Label = _result_panel.get_node("ResultTitle")
	title.text = title_text
	title.add_theme_color_override("font_color", title_color)

	var body: Label = _result_panel.get_node("ResultBody")
	body.text = body_text

	# Stats (post-battle data — visible to player; hidden conditions still NOT named explicitly)
	var stats: Label = _result_panel.get_node("ResultStats")
	stats.text = "[전투 데이터] 턴 %d 종료 | 장비 HP %.0f%% | 조운 처치수 %d | 후방공격 %d회 | 진형 활성 턴 %d | 적장 처치 %s" % [
		int(_battle_outcome.get("turn_count", 0)),
		float(fate.get("tank_alive_hp_pct", 0.0)) * 100.0,
		int(fate.get("assassin_kills", 0)),
		int(fate.get("rear_attacks", 0)),
		int(fate.get("formation_turns", 0)),
		"O" if bool(fate.get("boss_killed", false)) else "X",
	]

	print("[CHAPTER] 결과 분기: %s (조건 %d/5 충족)" % [branch, _count_fate_conditions(fate)])

func _count_fate_conditions(fate: Dictionary) -> int:
	var n: int = 0
	if float(fate.get("tank_alive_hp_pct", 0.0)) >= FATE_THRESHOLD_TANK_HP: n += 1
	if int(fate.get("assassin_kills", 0)) >= FATE_THRESHOLD_KILLS: n += 1
	if int(fate.get("rear_attacks", 0)) >= FATE_THRESHOLD_REAR: n += 1
	if int(fate.get("formation_turns", 0)) >= FATE_THRESHOLD_FORMATION: n += 1
	if bool(fate.get("boss_killed", false)): n += 1
	return n

func _on_retry() -> void:
	# Reset selection + outcome, return to story phase
	_selected_party = ["zhang_fei", "zhao_yun"]
	_battle_outcome = {}
	# Reset party-panel UI checkboxes
	for hero: Dictionary in HERO_OPTIONS:
		var card: Button = _party_panel.get_node("Card_" + String(hero["id"]))
		card.button_pressed = bool(hero.get("forced", false))
	_show_story_phase()

func _on_quit() -> void:
	get_tree().quit()
