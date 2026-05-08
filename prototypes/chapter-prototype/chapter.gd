# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does the existing GAME CONCEPT (formation tactics + hidden fate
#   branches + role differentiation + scenario story integration) work as a
#   coherent loop?
# Date: 2026-05-02
# Scope: 1 chapter ("장판파") with 4 phases (story → party → battle → fate result)
# S12-02 (2026-05-08): Pillar 4 atmospheric moment — REWRITTEN branch overlay + audio cue.

extends Control

const BattleV2 := preload("res://prototypes/chapter-prototype/battle_v2.gd")

# ─── Pillar 4 atmospheric moment tuning knobs (inline per prototype-code rules) ──

const RESERVED_COLOR_VERMILION: Color = Color8(0xC0, 0x39, 0x2B)  # 주홍 — Beat 7 panel tint
const RESERVED_COLOR_GOLD: Color = Color8(0xD4, 0xA0, 0x17)       # 금색 — Beat 7 title color
const DWELL_LOCKOUT_S: float = 1.5                                  # dwell window in seconds
const PANEL_TINT_ALPHA: float = 0.35                                # wash, not solid
const AUDIO_CUE_FUNDAMENTAL_HZ: float = 220.0                       # 묵 wash low-hum
const AUDIO_CUE_HARMONIC_HZ: float = 330.0                          # perfect-fifth-ish ceremonial
const AUDIO_CUE_DURATION_S: float = 1.2                             # aligns with dwell envelope
const AUDIO_CUE_VOLUME_DB: float = -12.0                            # ducks below result text
const AUDIO_CUE_MIX_RATE: float = 44100.0                           # standard CD-quality mix rate

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
var _last_branch: String = ""  # captured from _judge_fate() for atmospheric dispatch

# Panel references (built dynamically in _ready)
var _story_panel: Control
var _party_panel: Control
var _battle_panel: Node2D
var _result_panel: Control

# Atmospheric moment nodes (created in _ready after _result_panel exists)
var _atmospheric_overlay: ColorRect
var _atmospheric_audio: AudioStreamPlayer
var _atmospheric_buffer: PackedVector2Array  # pre-baked 묵 hum stereo samples

# ─── Lifecycle ──────────────────────────────────────────────────────────────

func _ready() -> void:
	# Resize window for prototype; 2x scale for HiDPI readability (logical 820x760, physical 1640x1520)
	if not Engine.is_editor_hint() and DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_size(Vector2i(1640, 1520))
		DisplayServer.window_set_title("천명역전 — 장판파 [PROTOTYPE]")
		# Center the window on screen so it doesn't go off-bottom on smaller displays
		var screen_size: Vector2i = DisplayServer.screen_get_size()
		var window_size: Vector2i = DisplayServer.window_get_size()
		DisplayServer.window_set_position((screen_size - window_size) / 2)
		# Scale content 2x — keeps internal coords at 820x760 but renders 2x larger
		get_window().content_scale_factor = 2.0
	_build_all_panels()
	_prebake_atmospheric_audio()
	_build_atmospheric_nodes()
	_show_story_phase()

# Pre-bake the 묵 hum audio buffer into a PackedVector2Array (stereo).
# Envelope: ease-in 0..0.2s → sustain 0.2..0.8s → ease-out decay 0.8..1.2s.
# Formula: value = (sin(2π × 220 × t) + 0.5 × sin(2π × 330 × t)) × envelope(t)
func _prebake_atmospheric_audio() -> void:
	var total_frames: int = int(AUDIO_CUE_MIX_RATE * AUDIO_CUE_DURATION_S)  # ~52920
	_atmospheric_buffer = PackedVector2Array()
	_atmospheric_buffer.resize(total_frames)
	var attack_end: float = 0.2
	var sustain_end: float = 0.8
	var decay_end: float = AUDIO_CUE_DURATION_S
	for i: int in total_frames:
		var t: float = float(i) / AUDIO_CUE_MIX_RATE
		# Envelope calculation
		var env: float
		if t < attack_end:
			# ease-in: quadratic ramp 0→1 over [0, 0.2s]
			var p: float = t / attack_end
			env = p * p
		elif t < sustain_end:
			# sustain: full amplitude
			env = 1.0
		else:
			# ease-out decay: quadratic ramp 1→0 over [0.8s, 1.2s]
			var p: float = (t - sustain_end) / (decay_end - sustain_end)
			env = (1.0 - p) * (1.0 - p)
		var sample: float = (sin(TAU * AUDIO_CUE_FUNDAMENTAL_HZ * t) +
				0.5 * sin(TAU * AUDIO_CUE_HARMONIC_HZ * t)) * env
		_atmospheric_buffer[i] = Vector2(sample, sample)  # L = R (mono-to-stereo)

# Create overlay ColorRect and AudioStreamPlayer under _result_panel.
# Called after _build_all_panels() so _result_panel already exists.
func _build_atmospheric_nodes() -> void:
	# ColorRect overlay — sits over result panel content; MOUSE_FILTER_IGNORE so clicks pass through
	_atmospheric_overlay = ColorRect.new()
	_atmospheric_overlay.name = "AtmosphericOverlay"
	_atmospheric_overlay.size = _result_panel.size
	_atmospheric_overlay.color = RESERVED_COLOR_VERMILION
	_atmospheric_overlay.modulate.a = 0.0
	_atmospheric_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_panel.add_child(_atmospheric_overlay)

	# AudioStreamPlayer — uses AudioStreamGenerator for synthesized hum playback
	var stream: AudioStreamGenerator = AudioStreamGenerator.new()
	stream.mix_rate = AUDIO_CUE_MIX_RATE
	stream.buffer_length = 0.1
	_atmospheric_audio = AudioStreamPlayer.new()
	_atmospheric_audio.name = "AtmosphericAudio"
	_atmospheric_audio.stream = stream
	_atmospheric_audio.volume_db = AUDIO_CUE_VOLUME_DB
	_result_panel.add_child(_atmospheric_audio)

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
		card.text = "%s [%s]\n%s" % [hero["name"], hero["role"], hero["desc"]]
		card.alignment = HORIZONTAL_ALIGNMENT_LEFT
		card.add_theme_font_size_override("font_size", 14)
		if not is_selectable:
			card.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		# Connect FIRST, then set initial state with set_pressed_no_signal to avoid spurious toggle fires
		card.toggled.connect(_on_party_toggle.bind(String(hero["id"])))
		card.set_pressed_no_signal(is_forced or (String(hero["id"]) in _selected_party))
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

func _on_party_toggle(toggled_on: bool, hero_id: String) -> void:
	# Godot 4.x toggled signal emits (toggled_on: bool); bound args follow.
	if _phase != 1: return
	if toggled_on and not (hero_id in _selected_party):
		if _selected_party.size() >= 4:
			# Reject — cap at 4
			var card: Button = _party_panel.get_node("Card_" + hero_id)
			card.set_pressed_no_signal(false)
			return
		_selected_party.append(hero_id)
	elif not toggled_on and (hero_id in _selected_party):
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

	if _last_branch == "REWRITTEN":
		await _dispatch_atmospheric_moment()

# Dispatch the Pillar 4 atmospheric moment for the REWRITTEN branch.
# Sequence: overlay fade-in → audio cue → dwell lockout → overlay fade-out → re-enable buttons.
func _dispatch_atmospheric_moment() -> void:
	var retry_btn: Button = _result_panel.get_node("RetryButton")
	var quit_btn: Button = _result_panel.get_node("QuitButton")

	# Defensive reset — ensure clean state in case of re-entry
	_atmospheric_overlay.modulate.a = 0.0
	if _atmospheric_audio.playing:
		_atmospheric_audio.stop()

	# Disable buttons for dwell lockout (AC-S12-02-3)
	retry_btn.disabled = true
	quit_btn.disabled = true

	# Fade overlay in (AC-S12-02-1): 0 → PANEL_TINT_ALPHA over 0.4s easeOut
	var tween_in: Tween = create_tween()
	tween_in.tween_property(_atmospheric_overlay, "modulate:a", PANEL_TINT_ALPHA, 0.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Emit audio cue (AC-S12-02-2): play then push pre-baked buffer
	_atmospheric_audio.play()
	var playback: AudioStreamGeneratorPlayback = _atmospheric_audio.get_stream_playback() as AudioStreamGeneratorPlayback
	if playback != null:
		playback.push_buffer(_atmospheric_buffer)

	# Dwell lockout — 1.5s per AC-SP-9
	await get_tree().create_timer(DWELL_LOCKOUT_S).timeout

	# Fade overlay out: PANEL_TINT_ALPHA → 0 over 0.2s easeIn
	var tween_out: Tween = create_tween()
	tween_out.tween_property(_atmospheric_overlay, "modulate:a", 0.0, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	# Re-enable buttons after dwell
	retry_btn.disabled = false
	quit_btn.disabled = false

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
			title_color = RESERVED_COLOR_GOLD  # AC-S12-02-4: canonical 금색 #D4A017
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

	_last_branch = branch  # captured for atmospheric dispatch in _show_result_phase()

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
	# Defensive atmospheric reset — prevents stacked dispatches on re-entry
	_atmospheric_overlay.modulate.a = 0.0
	if _atmospheric_audio.playing:
		_atmospheric_audio.stop()
	# Re-enable buttons in case retry fires before dwell completes (edge case guard)
	var retry_btn: Button = _result_panel.get_node("RetryButton")
	var quit_btn: Button = _result_panel.get_node("QuitButton")
	retry_btn.disabled = false
	quit_btn.disabled = false

	# Reset selection + outcome, return to story phase
	_selected_party = ["zhang_fei", "zhao_yun"]
	_battle_outcome = {}
	_last_branch = ""
	# Reset party-panel UI checkboxes
	for hero: Dictionary in HERO_OPTIONS:
		var card: Button = _party_panel.get_node("Card_" + String(hero["id"]))
		card.button_pressed = bool(hero.get("forced", false))
	_show_story_phase()

func _on_quit() -> void:
	get_tree().quit()
