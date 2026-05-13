## MainMenu — entry-point screen shown at game launch.
##
## Three options:
##   - 새 시나리오 (New scenario): reset ScenarioRunner, change_scene to
##     battle_scene which will fresh-load mvp_shu.json via its bootstrap path.
##   - 이어하기 (Continue): load the latest SaveContext from slot 1 and call
##     ScenarioRunner.restore_from_save_context() before changing scenes.
##     Disabled when no save exists in the slot.
##   - 종료 (Quit): get_tree().quit().
##
## Save slot is hardcoded to 1 for MVP (matches the implicit slot used by
## auto-checkpoints today). A future "save slot selector" screen replaces this
## hardcode with an explicit chosen slot from list_slots().
##
## No `class_name` — loaded via the .tscn's script reference. Not an autoload.
extends Control


@onready var _new_button: Button = $Center/Box/Buttons/NewButton
@onready var _continue_button: Button = $Center/Box/Buttons/ContinueButton
@onready var _quit_button: Button = $Center/Box/Buttons/QuitButton
@onready var _continue_caption: Label = $Center/Box/ContinueCaption


const _DEFAULT_SLOT: int = 1
const _BATTLE_SCENE_PATH: String = "res://scenes/battle/battle_scene.tscn"


func _ready() -> void:
	# Tests / headless runs can mount this scene without exercising buttons —
	# guard the connect calls so the Control is still usable in those contexts.
	if _new_button != null:
		_new_button.pressed.connect(_on_new_pressed)
		_new_button.grab_focus.call_deferred()
	if _continue_button != null:
		_continue_button.pressed.connect(_on_continue_pressed)
	if _quit_button != null:
		_quit_button.pressed.connect(_on_quit_pressed)
	_refresh_continue_state()


# ─── Buttons ──────────────────────────────────────────────────────────────────

func _on_new_pressed() -> void:
	# Force the next BattleScene bootstrap to load mvp_shu.json fresh from
	# disk: reset_for_tests() drops the chapter list back to LOADING/empty
	# so BattleScene._bootstrap_scenario_if_needed re-loads on first call.
	# (reset_for_tests is the canonical "drop runtime state" seam established
	# across the 4 autoloads; not test-exclusive — its name is a misnomer.)
	var runner: Node = get_node_or_null("/root/ScenarioRunner")
	if runner != null:
		runner.reset_for_tests()
	get_tree().change_scene_to_file(_BATTLE_SCENE_PATH)


func _on_continue_pressed() -> void:
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm == null:
		push_warning("MainMenu: SaveManager autoload missing")
		return
	sm.set_active_slot(_DEFAULT_SLOT)
	var ctx: SaveContext = sm.load_latest_checkpoint()
	if ctx == null:
		# No save in this slot — fall through silently; refresh button state.
		_refresh_continue_state()
		return
	var runner: Node = get_node_or_null("/root/ScenarioRunner")
	if runner == null:
		push_warning("MainMenu: ScenarioRunner autoload missing")
		return
	var ok: bool = runner.restore_from_save_context(ctx)
	if not ok:
		push_warning("MainMenu: restore_from_save_context refused — falling back to new game")
		runner.reset_for_tests()
	get_tree().change_scene_to_file(_BATTLE_SCENE_PATH)


func _on_quit_pressed() -> void:
	get_tree().quit()


# ─── Continue-button state ────────────────────────────────────────────────────

## Enables the Continue button when a save exists in the default slot, with a
## caption showing the saved chapter. Otherwise greys it out with a hint.
func _refresh_continue_state() -> void:
	if _continue_button == null:
		return
	var sm: Node = get_node_or_null("/root/SaveManager")
	if sm == null:
		_continue_button.disabled = true
		if _continue_caption != null:
			_continue_caption.text = ""
		return
	sm.set_active_slot(_DEFAULT_SLOT)
	var ctx: SaveContext = sm.load_latest_checkpoint()
	if ctx == null:
		_continue_button.disabled = true
		if _continue_caption != null:
			_continue_caption.text = "저장된 진행이 없습니다."
		return
	_continue_button.disabled = false
	if _continue_caption != null:
		_continue_caption.text = "마지막 저장: 제%d장 · %s" % [ctx.chapter_number, String(ctx.chapter_id)]
