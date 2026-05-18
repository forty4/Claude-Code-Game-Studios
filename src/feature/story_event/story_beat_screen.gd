## StoryBeatScreen — full-screen narrative overlay shown between scenario beats.
##
## Presents an ordered sequence of story beats (scenario Beat 1/3 before a
## battle; Beat 8 revelation + Beat 9 transition after one). Each beat is a
## Dictionary { title: String, body: String, speaker?: String, line?: String }.
## The player advances one beat at a time by clicking anywhere, pressing the
## "계속" button, or pressing Enter / Space. After the last beat, emits
## `sequence_finished` — the caller (BattleScene) then frees this node and
## proceeds (walk ScenarioRunner to battle / reload the scene / show ending).
##
## Self-builds its UI in code (no .tscn): a fixed widget set built in _ready(),
## with text/visibility updated per beat (no per-beat node churn → no orphans).
## Mount under a CanvasLayer so it renders above the battle world.
## `process_mode = ALWAYS` so the Enter/Space poll keeps working even when an
## ancestor is paused (BattleScene goes PROCESS_MODE_DISABLED while SceneManager
## treats it as "the overworld").
##
## Headless callers should NOT mount this — it waits forever for player input.
## BattleScene gates mounting on DisplayServer.get_name() != "headless".
##
## No GameBus subscriptions — keeps it independent of the R-7 scene-root signal
## rules. `class_name StoryBeatScreen` (no built-in collision per G-12); run
## `godot --headless --import --path .` after first creating the file (G-14).
class_name StoryBeatScreen
extends Control


## Emitted once the player advances past the final beat. The caller frees this
## node and continues the scenario flow.
signal sequence_finished


# ─── Tuning ───────────────────────────────────────────────────────────────────

## Max width of the text column so prose stays readable on wide (1920+) screens.
const TEXT_COLUMN_WIDTH: float = 720.0

## Session-41 — cinematic letterbox bars. Pure black slides in from top + bottom
## at mount time, framing the prose in a 영화 letterbox frame. Reads as "scene
## is about to begin, listen" before any text is parsed. Bars slide back out at
## sequence_finished (not implemented — the screen just hides, faster anyway).
const LETTERBOX_HEIGHT: float = 80.0
const LETTERBOX_COLOR: Color = Color(0.0, 0.0, 0.0, 1.0)
const LETTERBOX_TWEEN_DURATION: float = 0.45

## Title + body fade-in on screen mount. Fires once on _ready (the chapter
## entrance moment); subsequent beat transitions swap text without re-fading.
const TEXT_FADEIN_DURATION: float = 0.55
## Body fade-in is delayed slightly after title so the title lands first, then
## the prose arrives — gives the player a moment to register the scene anchor
## before reading the body.
const BODY_FADEIN_DELAY: float = 0.22

## Cosmetic theme colors — Palette tokens — see design/art/art-bible-v1-distilled.md §1
const BACKDROP_COLOR: Color = Palette.BACKDROP_DARK
const TITLE_COLOR: Color = Palette.JI_BAEK                           # 지백 warm for title
const BODY_COLOR: Color = Color(0.88, 0.87, 0.83, 1.0)               # near-지백, lighter prose
const SPEAKER_COLOR: Color = Color(0.74, 0.84, 0.66, 1.0)            # UI hierarchy — no palette token
const LINE_COLOR: Color = Palette.JI_BAEK                            # 지백 for quoted lines
const OUTLINE_COLOR: Color = Palette.MUK_OUTLINE
const FOOTER_COLOR: Color = Color(0.62, 0.62, 0.66, 0.85)            # dim footer — no palette token


# ─── State ────────────────────────────────────────────────────────────────────

var _beats: Array = []
var _index: int = 0
var _finished: bool = false

## Edge-detect latch for the Enter/Space poll so a held key advances once, not
## once per frame. Mirrors the post-battle keyboard poll pattern in battle_scene.gd.
## Starts true so that if this screen is mounted WHILE Enter is still held (e.g.
## the player pressed Enter to trigger "다음 장으로"), we don't instantly skip the
## first beat — they must release and re-press.
var _advance_key_held: bool = true

# Widget set, built once in _ready():
var _backdrop: ColorRect = null
var _title_label: Label = null
var _body_label: Label = null
var _speaker_label: Label = null
var _line_label: Label = null
var _page_label: Label = null
var _advance_button: Button = null
var _letterbox_top: ColorRect = null
var _letterbox_bottom: ColorRect = null


# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # the backdrop ColorRect catches clicks

	_backdrop = ColorRect.new()
	_backdrop.name = "Backdrop"
	_backdrop.color = BACKDROP_COLOR
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP  # clicking the dim area advances
	_backdrop.gui_input.connect(_on_backdrop_gui_input)
	add_child(_backdrop)

	var center: CenterContainer = CenterContainer.new()
	center.name = "Center"
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Content"
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)

	_title_label = _make_label(34, TITLE_COLOR, 8, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_title_label)
	_body_label = _make_label(21, BODY_COLOR, 5, HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(_body_label)
	_speaker_label = _make_label(18, SPEAKER_COLOR, 4, HORIZONTAL_ALIGNMENT_LEFT)
	box.add_child(_speaker_label)
	_line_label = _make_label(24, LINE_COLOR, 6, HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_line_label)

	var footer: HBoxContainer = HBoxContainer.new()
	footer.name = "Footer"
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 20)
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(footer)
	_page_label = _make_label(16, FOOTER_COLOR, 3, HORIZONTAL_ALIGNMENT_CENTER)
	_page_label.custom_minimum_size = Vector2.ZERO  # footer item — not a prose column
	footer.add_child(_page_label)
	_advance_button = Button.new()
	_advance_button.name = "AdvanceButton"
	_advance_button.custom_minimum_size = Vector2(240, 46)
	_advance_button.add_theme_font_size_override("font_size", 20)
	_advance_button.mouse_filter = Control.MOUSE_FILTER_STOP
	# No keyboard focus: Enter/Space are handled by the _process poll instead, so
	# a focused button would double-advance (its own activation + the poll).
	_advance_button.focus_mode = Control.FOCUS_NONE
	_advance_button.pressed.connect(advance)
	footer.add_child(_advance_button)

	# Session-41 — cinematic letterbox bars + entrance fade.
	# Built AFTER the content so they sit on top (z-order = child order). Mouse
	# filter IGNORE so they don't block backdrop click-to-advance.
	_letterbox_top = ColorRect.new()
	_letterbox_top.name = "LetterboxTop"
	_letterbox_top.color = LETTERBOX_COLOR
	_letterbox_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_letterbox_top.offset_bottom = 0.0  # starts collapsed
	_letterbox_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_letterbox_top)
	_letterbox_bottom = ColorRect.new()
	_letterbox_bottom.name = "LetterboxBottom"
	_letterbox_bottom.color = LETTERBOX_COLOR
	_letterbox_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_letterbox_bottom.offset_top = 0.0  # starts collapsed
	_letterbox_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_letterbox_bottom)

	# Title + body start invisible — tween in. Speaker / line / page / button
	# stay at full opacity (they're secondary; their visibility is gated by
	# _render_current_beat per-beat content).
	_title_label.modulate.a = 0.0
	_body_label.modulate.a = 0.0
	# Tween bound to SceneTree per G-31 — the StoryBeatScreen runs under HUDLayer
	# inside BattleScene, which goes PROCESS_MODE_DISABLED while SceneManager
	# treats the battle as the overworld. The screen itself is PROCESS_MODE_ALWAYS
	# (line 77) so self.create_tween() would actually fire here, but binding to
	# the tree is the consistent project pattern post-G-31.
	var tween: Tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(_letterbox_top, "offset_bottom", LETTERBOX_HEIGHT,
		LETTERBOX_TWEEN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_letterbox_bottom, "offset_top", -LETTERBOX_HEIGHT,
		LETTERBOX_TWEEN_DURATION).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_title_label, "modulate:a", 1.0, TEXT_FADEIN_DURATION) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body_label, "modulate:a", 1.0, TEXT_FADEIN_DURATION) \
		.set_delay(BODY_FADEIN_DELAY).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Failsafe per G-31 pattern — if the tween drops mid-flight (windowed Godot
	# 4.6 occasional behaviour), the SceneTreeTimer hard-sets the final state
	# so the screen never ends up stuck with invisible text / collapsed bars.
	get_tree().create_timer(LETTERBOX_TWEEN_DURATION + 0.10).timeout.connect(
		func() -> void:
			if is_instance_valid(self):
				if is_instance_valid(_letterbox_top):
					_letterbox_top.offset_bottom = LETTERBOX_HEIGHT
				if is_instance_valid(_letterbox_bottom):
					_letterbox_bottom.offset_top = -LETTERBOX_HEIGHT
				if is_instance_valid(_title_label):
					_title_label.modulate.a = 1.0
				if is_instance_valid(_body_label):
					_body_label.modulate.a = 1.0)

	# If present() was already called (uncommon — callers add_child then present),
	# render now. Otherwise wait for present().
	if not _beats.is_empty():
		_render_current_beat()


# ─── Public API ───────────────────────────────────────────────────────────────

## Begins presenting `beats` (Array of Dictionaries; see file header). A null or
## empty array immediately emits `sequence_finished` (the caller treats that as
## "nothing to show, carry on"). Safe to call once, right after add_child().
func present(beats: Array) -> void:
	_beats = beats if beats != null else []
	_index = 0
	_finished = false
	visible = true
	if _beats.is_empty():
		_emit_finished()
		return
	if is_node_ready():
		_render_current_beat()
	# else: _ready() will render once the widget set exists.


## Returns the 0-based index of the beat currently on screen (for tests).
func get_current_index() -> int:
	return _index


## Returns the total beat count in the active sequence (for tests).
func get_beat_count() -> int:
	return _beats.size()


## Advances to the next beat, or finishes the sequence if on the last beat.
## Public so tests can drive it without simulating input. Idempotent after finish.
func advance() -> void:
	if _finished:
		return
	_index += 1
	if _index >= _beats.size():
		_emit_finished()
		return
	_render_current_beat()


# ─── Input ────────────────────────────────────────────────────────────────────

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


# ─── Rendering ────────────────────────────────────────────────────────────────

func _render_current_beat() -> void:
	if _index < 0 or _index >= _beats.size():
		return
	if _title_label == null:
		return  # widget set not built yet (present() before _ready) — _ready re-renders
	var beat: Dictionary = _beats[_index] as Dictionary

	var title_text: String = (beat.get("title", "") as String).strip_edges()
	_title_label.text = title_text
	_title_label.visible = not title_text.is_empty()

	var body_text: String = (beat.get("body", "") as String)
	_body_label.text = body_text
	_body_label.visible = not body_text.strip_edges().is_empty()

	var speaker_text: String = (beat.get("speaker", "") as String).strip_edges()
	_speaker_label.text = "— " + speaker_text
	_speaker_label.visible = not speaker_text.is_empty()

	var line_text: String = (beat.get("line", "") as String).strip_edges()
	_line_label.text = line_text
	_line_label.visible = not line_text.is_empty()

	_page_label.text = "%d / %d" % [_index + 1, _beats.size()]
	var is_last: bool = _index + 1 >= _beats.size()
	_advance_button.text = "전투 시작 ▶  (Enter)" if is_last else "계속 ▶  (Enter)"


## Builds a width-capped, autowrapping Label with an outline for legibility over
## the battle world. mouse_filter IGNORE so clicks fall through to the backdrop.
func _make_label(font_size: int, color: Color, outline: int, halign: int) -> Label:
	var label: Label = Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = halign
	label.custom_minimum_size = Vector2(TEXT_COLUMN_WIDTH, 0.0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", outline)
	label.add_theme_font_size_override("font_size", font_size)
	return label


# ─── Finish ───────────────────────────────────────────────────────────────────

func _emit_finished() -> void:
	if _finished:
		return
	_finished = true
	# Stop eating clicks the instant the sequence ends — the caller frees us next
	# frame, but until then we don't want to block the battle view.
	if is_instance_valid(_backdrop):
		_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	sequence_finished.emit()
