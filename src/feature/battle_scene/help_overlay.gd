## HelpOverlay — full-screen reference card mounted on demand by BattleScene
## when the player presses H mid-battle (or after).
##
## Unlike PauseMenu this does NOT pause the tree — it's a read-only overlay
## the player can dismiss with H again or by clicking the close button. While
## visible, the backdrop captures mouse so the grid below doesn't accept
## clicks (the player can read without accidentally moving a unit).
##
## Self-builds its UI in code (no .tscn). `class_name HelpOverlay` — run
## `godot --headless --import --path .` after creating this file (G-14).
## No GameBus subscriptions, no autoload, no signals beyond `close_requested`.
class_name HelpOverlay
extends Control


signal close_requested


const _BACKDROP_COLOR: Color = Color(0.018, 0.025, 0.045, 0.86)
const _CARD_COLOR: Color = Color(0.060, 0.070, 0.110, 0.96)
const _CARD_BORDER: Color = Color(0.75, 0.62, 0.32, 0.85)  # warm parchment border
const _HEADING_COLOR: Color = Color(0.98, 0.92, 0.74, 1.0)
const _BODY_COLOR: Color = Color(0.92, 0.92, 0.90, 1.0)
const _DIM_COLOR: Color = Color(0.72, 0.72, 0.70, 1.0)


## Edge-detect latch — true while H is held (set by caller via show_help()).
## Mirrors PauseMenu's _esc_was_held: prevents the H press that opened us
## from immediately closing us. Player must release H, then press again.
var _h_was_held: bool = true


func _ready() -> void:
	# Run regardless of tree.paused — this overlay doesn't pause but the
	# convention from PauseMenu (ALWAYS process_mode + own input loop) makes
	# both overlays consistent even when one is opened on top of the other.
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	# ── Backdrop (semi-transparent, eats clicks behind the card) ────────────
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = _BACKDROP_COLOR
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	# ── Centered card ──────────────────────────────────────────────────────
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(640, 0)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = _CARD_COLOR
	style.border_color = _CARD_BORDER
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	card.add_theme_stylebox_override("panel", style)
	center.add_child(card)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	# ── Title ──────────────────────────────────────────────────────────────
	box.add_child(_make_label("조작 안내", 32, _HEADING_COLOR, 8))
	box.add_child(_make_spacer(6))

	# ── Mouse / click controls ─────────────────────────────────────────────
	box.add_child(_make_section_heading("마우스"))
	box.add_child(_make_row("좌클릭 — 아군 유닛 선택"))
	box.add_child(_make_row("좌클릭 (빈 칸) — 선택한 유닛 이동"))
	box.add_child(_make_row("좌클릭 (적 유닛) — 공격"))
	box.add_child(_make_row("선택한 유닛 재클릭 — 그 턴 종료 / 대기"))
	box.add_child(_make_row("우측 큐 슬롯 클릭 — 해당 유닛 정보 보기"))
	box.add_child(_make_spacer(6))

	# ── Keyboard ───────────────────────────────────────────────────────────
	box.add_child(_make_section_heading("키보드"))
	box.add_child(_make_row("H — 이 도움말 열기 / 닫기"))
	box.add_child(_make_row("ESC — 일시 정지 메뉴"))
	box.add_child(_make_row("D — 선택한 유닛 방어 (받는 피해 50% 감소; 한 턴 소모)"))
	box.add_child(_make_row("Enter / R / Space — 전투 종료 후 다음 행동"))
	box.add_child(_make_spacer(6))

	# ── Unit class shapes ──────────────────────────────────────────────────
	box.add_child(_make_section_heading("유닛 형상 (외곽 색: 적 빨강 / 아군 청색)"))
	box.add_child(_make_row("삼각형 — 기병 (이동 +1)"))
	box.add_child(_make_row("사각형 — 보병 (HP·방어 우세)"))
	box.add_child(_make_row("다이아몬드 — 궁병 (사거리 2)"))
	box.add_child(_make_row("마름모 — 책사 (이동 -1, 술책 특화)"))
	box.add_child(_make_row("원 — 지휘관 (인접 아군에 +15% 피해 버프)"))
	box.add_child(_make_row("가는 다이아 — 척후 (선제 우세)"))
	box.add_child(_make_spacer(6))

	# ── Tips ───────────────────────────────────────────────────────────────
	box.add_child(_make_section_heading("팁"))
	box.add_child(_make_row("지휘관 유닛(유비/조조 등) 옆에 붙으면 피해가 +15% 증가합니다."))
	box.add_child(_make_row("산자락(짙은 녹지)은 이동이 느리지만 방어 보너스가 있습니다."))
	box.add_child(_make_row("궁병은 1칸 멀리서 공격할 수 있으나 반격을 받지 않습니다."))
	box.add_child(_make_row("적이 둘러쌀 것 같으면 D로 방어 — 한 턴 버려도 받는 피해 절반이 됩니다."))
	box.add_child(_make_row("적의 측면(FLANK) +20%, 후방(REAR) +50% 추가 피해. 공격 미리보기에서 확인하세요."))
	box.add_child(_make_row("기병(관우 등)이 4칸 이상 이동 후 공격하면 돌격 +20% — 멀리서 달려들어 한 방 노리세요."))
	box.add_child(_make_row("척후(초선 등)는 2라운드부터 아직 행동하지 않은 적에게 기습 +15% — 반격도 받지 않습니다."))
	box.add_child(_make_spacer(12))

	# ── Close button ────────────────────────────────────────────────────────
	var close_row: CenterContainer = CenterContainer.new()
	close_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(close_row)
	var close_btn: Button = Button.new()
	close_btn.text = "닫기 (H)"
	close_btn.custom_minimum_size = Vector2(220, 44)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.pressed.connect(_on_close_pressed)
	close_row.add_child(close_btn)


## Called by BattleScene right after add_child() to make the overlay visible
## with the latch armed (so the H press that opened us doesn't immediately
## close us — same pattern as PauseMenu.show_paused).
func show_help() -> void:
	visible = true
	_h_was_held = true


## ESC-style close poll. process_mode = ALWAYS keeps this running even if a
## PauseMenu is stacked on top (won't happen with current wiring but cheap).
func _process(_delta: float) -> void:
	if not visible:
		return
	var h_held: bool = (
		Input.is_physical_key_pressed(KEY_H)
		or Input.is_key_pressed(KEY_H)
	)
	if h_held and not _h_was_held:
		_on_close_pressed()
	_h_was_held = h_held


func _on_close_pressed() -> void:
	visible = false
	close_requested.emit()


# ─── Builders ─────────────────────────────────────────────────────────────────

func _make_label(text: String, size: int, color: Color, outline: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.02, 0.02, 0.03, 1.0))
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_font_size_override("font_size", size)
	return label


func _make_section_heading(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", _HEADING_COLOR)
	label.add_theme_font_size_override("font_size", 19)
	return label


func _make_row(text: String) -> Label:
	var label: Label = Label.new()
	label.text = "  " + text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", _BODY_COLOR)
	label.add_theme_font_size_override("font_size", 16)
	return label


func _make_spacer(h: int) -> Control:
	var s: Control = Control.new()
	s.custom_minimum_size = Vector2(0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s
