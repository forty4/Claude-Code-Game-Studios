## SignatureArchivePopup — 영걸전 5 시그니처 cascade 진척 archive 화면.
##
## Mounted by MainMenu when player taps the "시그니처 아카이브" button. Reads
## the latest SaveContext's persistent_branch_flags + signature metadata
## (hardcoded 5 영웅) to render a 5-card archive: 각 시그니처 이름 + 활성/
## 미활성 + 영웅 한 줄 설명 + 첫 달성 챕터.
##
## 다중 캠페인 누적 archive (cross-campaign) 은 별도 ProgressArchive 시스템
## 필요 — 본 popup 은 LAST SaveContext 한정으로 단순 표시 (in-progress 또는
## 직전 캠페인 끝낸 상태). 캠페인 다시 시작하면 cascade 0/5 부터 다시.
##
## No class_name — instantiated via SignatureArchivePopup.new() from main_menu.gd.
extends Control


signal closed


# Hardcoded signature catalog — order = cascade event chronology in mvp_shu.
# (signature_key, hero_name_ko, chapter_label, blurb)
const SIGNATURE_CATALOG: Array[Array] = [
	["WIN_changsha_wei_yan_defects",  "위연 (魏延)",     "ch13 장사",   "황충 노장과의 결의 — 칼을 거두고 한실의 부장으로."],
	["WIN_luofeng_pang_tong_lives",   "방통 (龐統)",     "ch16 낙봉파", "낙봉의 화살을 비껴 간 봉추 — 와룡의 옆에."],
	["WIN_fancheng_guan_yu_survives", "관우 (關羽)",     "ch20 번성",   "퇴로가 열렸다 — 청룡언월도 다시 본진에."],
	["WIN_zhangfei_survives",         "장비 (張飛)",     "ch21 장비",   "부하의 칼을 규율로 거두고 호통이 다시."],
	["WIN_yiling_liu_bei_survives",   "유비 (劉備)",     "ch22 이릉",   "이릉의 화공을 대비로 막다 — 인의가 끝까지."],
]


var _backdrop: ColorRect = null
var _active_flags: PackedStringArray = PackedStringArray()


## Static factory. `active_flags` is the persistent_branch_flags set from
## the latest SaveContext (or empty if no save exists).
static func make(active_flags: PackedStringArray) -> Control:
	var p: Node = (load("res://src/feature/main_menu/signature_archive_popup.gd") as GDScript).new()
	(p as Object).set("_active_flags", active_flags.duplicate())
	return p as Control


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = Color(0.03, 0.04, 0.06, 0.92)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_backdrop)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	vbox.custom_minimum_size = Vector2(620.0, 0.0)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)

	# Header
	var active_count: int = _active_flags.size()
	var header: Label = Label.new()
	header.text = "영걸전 시그니처 (%d / 5)" % active_count
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", Color(0.96, 0.86, 0.42, 1.0))
	header.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.04, 1.0))
	header.add_theme_constant_override("outline_size", 6)
	header.add_theme_font_size_override("font_size", 28)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(header)

	var subhead: Label = Label.new()
	subhead.text = "마지막 저장 시점 기준 — 캠페인 다시 시작하면 0/5 부터."
	subhead.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subhead.add_theme_color_override("font_color", Color(0.74, 0.72, 0.66, 0.92))
	subhead.add_theme_font_size_override("font_size", 14)
	subhead.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(subhead)

	# 5 cards
	for entry_var: Variant in SIGNATURE_CATALOG:
		var entry: Array = entry_var as Array
		var key: String = entry[0] as String
		var hero_name: String = entry[1] as String
		var chapter_label: String = entry[2] as String
		var blurb: String = entry[3] as String
		var is_active: bool = key in _active_flags
		vbox.add_child(_make_signature_card(hero_name, chapter_label, blurb, is_active))

	# Close button
	var close_btn: Button = Button.new()
	close_btn.name = "CloseButton"
	close_btn.text = "닫기 (Esc)"
	close_btn.custom_minimum_size = Vector2(200, 44)
	close_btn.add_theme_font_size_override("font_size", 18)
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.pressed.connect(_on_close_pressed)
	vbox.add_child(close_btn)


func _make_signature_card(hero_name: String, chapter_label: String,
		blurb: String, is_active: bool) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(620, 0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.12, 0.16, 0.92) if is_active else Color(0.07, 0.08, 0.10, 0.84)
	sb.border_color = Color(0.96, 0.78, 0.32, 0.95) if is_active else Color(0.32, 0.32, 0.34, 0.55)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	sb.content_margin_left = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_right = 14.0
	sb.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", sb)

	var inner: VBoxContainer = VBoxContainer.new()
	inner.add_theme_constant_override("separation", 4)
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(inner)

	var title_row: HBoxContainer = HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 12)
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(title_row)

	var status_label: Label = Label.new()
	status_label.text = "✦ 달성" if is_active else "○ 미달성"
	var status_color: Color = (
		Color(0.96, 0.86, 0.42, 1.0) if is_active
		else Color(0.50, 0.50, 0.54, 0.85)
	)
	status_label.add_theme_color_override("font_color", status_color)
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(status_label)

	var hero_label: Label = Label.new()
	hero_label.text = hero_name
	var hero_color: Color = (
		Color(0.98, 0.94, 0.84, 1.0) if is_active
		else Color(0.62, 0.62, 0.62, 0.85)
	)
	hero_label.add_theme_color_override("font_color", hero_color)
	hero_label.add_theme_color_override("font_outline_color", Color(0.03, 0.03, 0.04, 1.0))
	hero_label.add_theme_constant_override("outline_size", 4)
	hero_label.add_theme_font_size_override("font_size", 20)
	hero_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(hero_label)

	var chapter_inline: Label = Label.new()
	chapter_inline.text = "[%s]" % chapter_label
	chapter_inline.add_theme_color_override("font_color", Color(0.62, 0.62, 0.62, 0.78))
	chapter_inline.add_theme_font_size_override("font_size", 13)
	chapter_inline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(chapter_inline)

	var blurb_label: Label = Label.new()
	blurb_label.text = blurb
	blurb_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var blurb_color: Color = (
		Color(0.85, 0.83, 0.76, 0.94) if is_active
		else Color(0.55, 0.55, 0.55, 0.80)
	)
	blurb_label.add_theme_color_override("font_color", blurb_color)
	blurb_label.add_theme_font_size_override("font_size", 14)
	blurb_label.custom_minimum_size = Vector2(560, 0)
	blurb_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(blurb_label)

	return card


func _on_close_pressed() -> void:
	closed.emit()
	queue_free()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		_on_close_pressed()
