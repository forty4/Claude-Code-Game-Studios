## PauseMenu — full-screen overlay mounted on demand by BattleScene when the
## player presses ESC mid-battle (or post-battle).
##
## While visible, get_tree().paused = true freezes the battle world (autoloads
## with PROCESS_MODE_ALWAYS, like SoundManager, keep ticking). The pause menu
## itself runs PROCESS_MODE_ALWAYS so input + buttons keep working.
##
## Three options:
##   - 이어 진행 (Resume): hide overlay, unpause
##   - 메인 메뉴로 (Main menu): unpause, change_scene to main_menu.tscn
##   - 종료 (Quit): get_tree().quit
##
## Self-builds its UI in code (no .tscn). `class_name PauseMenu` (no built-in
## collision per G-12); run `godot --headless --import --path .` after first
## creating this file (G-14). No GameBus subscriptions.
class_name PauseMenu
extends Control


signal resume_requested


const _MAIN_MENU_PATH: String = "res://scenes/main_menu/main_menu.tscn"
const _BACKDROP_COLOR: Color = Color(0.025, 0.035, 0.055, 0.88)


var _resume_button: Button = null
var _sfx_toggle_button: Button = null

## Edge-detect latch for the ESC close-poll. Starts true so the ESC press that
## opened this menu (still held when _ready fires) doesn't immediately close it
## — the player must release ESC and press again to close via keyboard.
var _esc_was_held: bool = true


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = _BACKDROP_COLOR
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP  # eat clicks behind us
	add_child(backdrop)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var box: VBoxContainer = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(box)

	var title: Label = _make_label("일시정지", 40, Color(0.96, 0.92, 0.80, 1.0), 8)
	box.add_child(title)
	box.add_child(_make_spacer(12))

	_resume_button = _make_button("이어 진행 (ESC)", _on_resume_pressed)
	box.add_child(_resume_button)
	_sfx_toggle_button = _make_button(_sfx_label(), _on_sfx_toggle_pressed)
	box.add_child(_sfx_toggle_button)
	box.add_child(_make_button("메인 메뉴로", _on_main_menu_pressed))
	box.add_child(_make_button("종료", _on_quit_pressed))


func show_paused() -> void:
	visible = true
	get_tree().paused = true
	_esc_was_held = true  # latch — wait for release before ESC closes us
	if _resume_button != null:
		_resume_button.grab_focus.call_deferred()


## ESC close-poll — PROCESS_MODE_ALWAYS keeps this running while the tree is
## paused. Pattern mirrors BattleScene's post-battle poll: edge-detected so
## holding ESC doesn't toggle every frame.
func _process(_delta: float) -> void:
	if not visible:
		return
	var esc_held: bool = (
		Input.is_physical_key_pressed(KEY_ESCAPE)
		or Input.is_key_pressed(KEY_ESCAPE)
	)
	if esc_held and not _esc_was_held:
		_on_resume_pressed()
	_esc_was_held = esc_held


func hide_paused() -> void:
	visible = false
	get_tree().paused = false


# ─── Button handlers ──────────────────────────────────────────────────────────

func _on_resume_pressed() -> void:
	hide_paused()
	resume_requested.emit()


func _on_main_menu_pressed() -> void:
	# Unpause BEFORE changing scenes — change_scene_to_file with the tree paused
	# leaves the new scene's _ready running paused too.
	hide_paused()
	get_tree().change_scene_to_file(_MAIN_MENU_PATH)


func _on_quit_pressed() -> void:
	hide_paused()  # tidy in case quit is intercepted (e.g. an OS confirm dialog)
	get_tree().quit()


## Flips SoundManager.enabled AND persists the choice across restarts via
## SoundManager.set_enabled (writes user://settings.cfg). Headless runs keep
## enabled false regardless — toggling is a no-op there (the player pool is
## empty so play() is short-circuited anyway).
func _on_sfx_toggle_pressed() -> void:
	var sm: Node = get_node_or_null("/root/SoundManager")
	if sm == null:
		return
	# set_enabled persists; falls back to direct assignment when the autoload
	# is a stub without the API (test harnesses that subclass Node directly).
	if sm.has_method("set_enabled"):
		sm.set_enabled(not (sm.enabled as bool))
	else:
		sm.enabled = not (sm.enabled as bool)
	if _sfx_toggle_button != null:
		_sfx_toggle_button.text = _sfx_label()


## Reads the current SoundManager.enabled at button-build / refresh time. Falls
## back to ON when the autoload is missing (test harness, etc.).
func _sfx_label() -> String:
	var sm: Node = get_node_or_null("/root/SoundManager")
	var on: bool = true
	if sm != null:
		on = sm.enabled as bool
	return "음향 끄기" if on else "음향 켜기"


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


func _make_spacer(h: int) -> Control:
	var s: Control = Control.new()
	s.custom_minimum_size = Vector2(0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return s


func _make_button(text: String, on_pressed: Callable) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(260, 50)
	btn.add_theme_font_size_override("font_size", 22)
	btn.mouse_filter = Control.MOUSE_FILTER_STOP
	btn.pressed.connect(on_pressed)
	return btn
