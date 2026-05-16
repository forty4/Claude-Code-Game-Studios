## ConsequenceScreen — post-battle "역사의 두 갈래" comparison overlay.
##
## Mounted between Beat 8 (this chapter's resolved ending prose) and Beat 9
## (transition to next chapter). Shows the player BOTH possible endings of
## the just-finished chapter side-by-side: the path they took (vivid gold,
## right) and the path they didn't (muted sepia, left). 영걸전의 "역사를
## 바꿨다 / 그대로다" 모먼트 — without explicit canonical/rewritten labels
## (the prose itself carries that subtext).
##
## Construction: `ConsequenceScreen.make(other_title, your_title)`. Use the
## titles from story_content.json beat-8 entries (e.g., "장판의 먼지가
## 가라앉다" vs "후위가 무너지다") — they're short, dramatic, and the
## divergence reads in one glance.
##
## Mount under a CanvasLayer so it renders above the battle world.
## process_mode = ALWAYS so the Enter/Space poll keeps working even when
## an ancestor is paused (BattleScene goes PROCESS_MODE_DISABLED while
## SceneManager treats it as "the overworld"). Mirrors StoryBeatScreen.
##
## Headless callers should NOT mount this — it waits forever for input.
class_name ConsequenceScreen
extends Control


## Emitted once the player presses 계속 / Enter / Space / clicks. Caller
## frees this node and continues the post-battle flow.
signal sequence_finished


# ─── Tuning ───────────────────────────────────────────────────────────────────

const BACKDROP_COLOR:     Color = Color(0.035, 0.045, 0.065, 0.94)
const HEADER_COLOR:       Color = Color(0.96, 0.90, 0.74, 1.0)
const SUBHEAD_MUTED:      Color = Color(0.65, 0.62, 0.55, 0.85)
const SUBHEAD_VIVID:      Color = Color("e8d68a")
const TITLE_MUTED_COLOR:  Color = Color(0.62, 0.56, 0.48, 0.88)
const TITLE_VIVID_COLOR:  Color = Color("e8d68a")
const SEPARATOR_COLOR:    Color = Color(0.50, 0.50, 0.55, 0.40)
const OUTLINE_COLOR:      Color = Color(0.02, 0.02, 0.03, 1.0)
## Session-44 — footnote color: dim parchment. Reads as ancillary "도움말"
## that doesn't compete with the bold title tier above. Stay legible against
## the dark backdrop via the heavy outline.
const FOOTNOTE_COLOR:     Color = Color(0.68, 0.66, 0.60, 0.78)

const HEADER_TEXT:        String = "역사의 두 갈래"
const SUBHEAD_OTHER:      String = "또 다른 갈래"
const SUBHEAD_YOUR:       String = "당신이 이른 갈래"
const COLUMN_WIDTH:       float  = 380.0
const SEPARATOR_HEIGHT:   float  = 90.0
const FOOTNOTE_FONT_SIZE: int    = 16
const FOOTNOTE_OUTLINE:   int    = 3


# ─── State (set via make() before _ready) ────────────────────────────────────

var _other_title: String = ""
var _your_title: String = ""
## Session-44 — optional retry-nudge footnote rendered between the comparison
## row and the advance button. Reads as "이 챕터를 다시 시도하면, 또 다른
## 결말을 경험할 수 있습니다." or similar — surfacing 영걸전 vision의
## "계속 시도하면서 성취감" path. Empty string → no footnote mount.
var _footnote: String = ""
var _finished: bool = false
## Edge-detect latch for Enter/Space — mirrors StoryBeatScreen pattern so a
## held key advances once, not once per frame. Starts true so we don't
## insta-skip if mounted while Enter is still held from a prior screen.
var _advance_key_held: bool = true

var _backdrop: ColorRect = null


# ─── Construction ────────────────────────────────────────────────────────────


## Static factory — set content before _ready() builds the widget tree.
## `other_title` = beat-8 title of the branch the player did NOT take.
## `your_title`  = beat-8 title of the branch the player DID take.
## `footnote`    = optional retry-nudge text rendered between the comparison
##                 and the advance button. Empty → no footnote mounted.
static func make(other_title: String, your_title: String,
		footnote: String = "") -> ConsequenceScreen:
	var s: ConsequenceScreen = ConsequenceScreen.new()
	s._other_title = other_title
	s._your_title = your_title
	s._footnote = footnote
	return s


# ─── Lifecycle ────────────────────────────────────────────────────────────────


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = BACKDROP_COLOR
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.gui_input.connect(_on_backdrop_gui_input)
	add_child(_backdrop)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 32)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)

	# Header
	vbox.add_child(_make_label(HEADER_TEXT, 36, HEADER_COLOR, 8,
		HORIZONTAL_ALIGNMENT_CENTER))

	# 2-column comparison row
	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 60)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(hbox)

	# LEFT — other path (muted sepia)
	hbox.add_child(_make_column(SUBHEAD_OTHER, SUBHEAD_MUTED, _other_title,
		TITLE_MUTED_COLOR, "OtherColumn"))

	# Vertical separator
	var sep: ColorRect = ColorRect.new()
	sep.name = "Separator"
	sep.color = SEPARATOR_COLOR
	sep.custom_minimum_size = Vector2(2.0, SEPARATOR_HEIGHT)
	hbox.add_child(sep)

	# RIGHT — your path (vivid gold)
	hbox.add_child(_make_column(SUBHEAD_YOUR, SUBHEAD_VIVID, _your_title,
		TITLE_VIVID_COLOR, "YourColumn"))

	# Session-44 — optional retry-nudge footnote between the comparison and
	# the advance button. Reads as "재시도하면 또 다른 결말" hint, surfacing
	# 영걸전 vision's "계속 시도하면서 성취감" path. Skipped on empty.
	if not _footnote.strip_edges().is_empty():
		var footnote_label: Label = _make_label(_footnote, FOOTNOTE_FONT_SIZE,
			FOOTNOTE_COLOR, FOOTNOTE_OUTLINE, HORIZONTAL_ALIGNMENT_CENTER)
		footnote_label.name = "Footnote"
		vbox.add_child(footnote_label)

	# Footer button
	var btn: Button = Button.new()
	btn.name = "AdvanceButton"
	btn.text = "계속 ▶  (Enter)"
	btn.custom_minimum_size = Vector2(240, 46)
	btn.add_theme_font_size_override("font_size", 20)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	# No keyboard focus — Enter is handled by the _process poll instead, so a
	# focused button would double-advance (its own activation + the poll).
	btn.focus_mode = Control.FOCUS_NONE
	btn.pressed.connect(advance)
	vbox.add_child(btn)


# ─── Public API ──────────────────────────────────────────────────────────────


## Advances past the screen, firing sequence_finished. Public so tests can
## drive it without simulating input. Idempotent after finish.
func advance() -> void:
	if _finished:
		return
	_finished = true
	if is_instance_valid(_backdrop):
		_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	sequence_finished.emit()


# ─── Input ───────────────────────────────────────────────────────────────────


func _process(_delta: float) -> void:
	if _finished:
		return
	var held: bool = (
		Input.is_physical_key_pressed(KEY_ENTER)
		or Input.is_key_pressed(KEY_ENTER)
		or Input.is_physical_key_pressed(KEY_KP_ENTER)
		or Input.is_physical_key_pressed(KEY_SPACE)
		or Input.is_key_pressed(KEY_SPACE)
	)
	if held and not _advance_key_held:
		advance()
	_advance_key_held = held


func _on_backdrop_gui_input(event: InputEvent) -> void:
	if _finished:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		advance()
		get_viewport().set_input_as_handled()


# ─── Widget helpers ──────────────────────────────────────────────────────────


func _make_column(subhead_text: String, subhead_color: Color,
		title_text: String, title_color: Color, column_name: String) -> VBoxContainer:
	var col: VBoxContainer = VBoxContainer.new()
	col.name = column_name
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(COLUMN_WIDTH, 0.0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(_make_label(subhead_text, 18, subhead_color, 4,
		HORIZONTAL_ALIGNMENT_CENTER))
	var displayed_title: String = title_text if not title_text.strip_edges().is_empty() \
		else "기록되지 않은 결말"
	var title_label: Label = _make_label(displayed_title, 26, title_color, 6,
		HORIZONTAL_ALIGNMENT_CENTER)
	title_label.name = "TitleLabel"
	col.add_child(title_label)
	return col


func _make_label(text: String, font_size: int, color: Color,
		outline: int, halign: int) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = halign
	label.custom_minimum_size = Vector2(COLUMN_WIDTH, 0.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_font_size_override("font_size", font_size)
	return label
