## MainMenu — entry-point screen shown at game launch.
##
## Four options:
##   - 새 시나리오 (New scenario): reset ScenarioRunner, change_scene to
##     battle_scene which will fresh-load shu_canon_full.json via its bootstrap path.
##   - 이어하기 (Continue): load the latest SaveContext from slot 1 and call
##     ScenarioRunner.restore_from_save_context() before changing scenes.
##     Disabled when no save exists in the slot.
##   - DEV: 챕터 점프 (S62): debug-build only. Opens a popup listing every
##     chapter across all production scenarios; clicking jumps straight to
##     that chapter via ScenarioRunner.dev_jump_to_chapter(). Default roster
##     only — branch_overrides / hidden destiny chains require a full
##     playthrough to exercise. Button is `visible = false` until _ready()
##     enables it under `OS.has_feature("debug")`.
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
@onready var _dev_jump_button: Button = $Center/Box/Buttons/DevJumpButton
@onready var _quit_button: Button = $Center/Box/Buttons/QuitButton
@onready var _continue_caption: Label = $Center/Box/ContinueCaption
@onready var _signature_badge: Label = $Center/Box/SignatureBadge
@onready var _archive_button: Button = $Center/Box/ArchiveButton


const _DEFAULT_SLOT: int = 1
const _BATTLE_SCENE_PATH: String = "res://scenes/battle/battle_scene.tscn"

## Production scenarios surfaced in the DEV chapter-jump menu. Pairs of
## (display_name, res_path). Keep in sync with /assets/data/scenarios/.
const _DEV_JUMP_SCENARIOS: Array[Array] = [
	["촉 (蜀)", "res://assets/data/scenarios/shu_canon_full.json"],
	["위 (魏)", "res://assets/data/scenarios/mvp_wei.json"],
]

# Maps PopupMenu item_id (int) → {scenario_path: String, chapter_index: int}.
# Populated lazily on first menu_about_to_show so we don't reparse scenario JSON
# on _ready() for every launch (the dev menu is debug-only).
var _dev_jump_entries: Dictionary = {}
var _dev_jump_popup: PopupMenu = null


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
	if _dev_jump_button != null:
		# Debug-build gate. `OS.has_feature("debug")` is false in
		# exported release builds — the dev jump surface stays hidden there.
		var debug_build: bool = OS.has_feature("debug")
		_dev_jump_button.visible = debug_build
		if debug_build:
			_dev_jump_button.pressed.connect(_on_dev_jump_pressed)
	if _archive_button != null:
		_archive_button.pressed.connect(_on_archive_pressed)
	_refresh_continue_state()
	_refresh_signature_state()


# ─── Buttons ──────────────────────────────────────────────────────────────────

func _on_new_pressed() -> void:
	# Force the next BattleScene bootstrap to load shu_canon_full.json fresh from
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


# ─── DEV: 챕터 점프 (debug build only) ─────────────────────────────────────────

## Opens the dev chapter-jump popup. First press builds the popup lazily by
## parsing each scenario's chapter list — kept inside _on_dev_jump_pressed
## rather than _ready() so non-debug builds (where the button is hidden)
## never pay the JSON-parse cost.
func _on_dev_jump_pressed() -> void:
	if _dev_jump_popup == null:
		_dev_jump_popup = PopupMenu.new()
		_dev_jump_popup.name = "DevJumpPopup"
		_dev_jump_popup.id_pressed.connect(_on_dev_jump_item_selected)
		add_child(_dev_jump_popup)
	_rebuild_dev_jump_popup()
	# Position the popup beneath the button. mouse-position fallback if the
	# button is somehow not in the tree.
	var anchor_pos: Vector2 = get_viewport().get_mouse_position()
	if _dev_jump_button != null and _dev_jump_button.is_inside_tree():
		var rect: Rect2 = _dev_jump_button.get_global_rect()
		anchor_pos = rect.position + Vector2(rect.size.x + 8, 0)
	var window_pos: Vector2i = Vector2i(anchor_pos) + Vector2i(get_window().position)
	_dev_jump_popup.popup(Rect2i(window_pos, Vector2i.ZERO))


## Re-populates the popup. Each item id is the index into _dev_jump_entries.
## Re-built every press so adding a new scenario .json picks up automatically.
func _rebuild_dev_jump_popup() -> void:
	_dev_jump_popup.clear()
	_dev_jump_entries.clear()
	var item_id: int = 0
	for entry: Array in _DEV_JUMP_SCENARIOS:
		var label: String = entry[0] as String
		var path: String = entry[1] as String
		var chapters: Array[String] = _read_chapter_ids(path)
		if chapters.is_empty():
			_dev_jump_popup.add_item("%s — (load failed: %s)" % [label, path])
			_dev_jump_popup.set_item_disabled(_dev_jump_popup.item_count - 1, true)
			continue
		# Section header (disabled, label-only).
		_dev_jump_popup.add_item("─── %s ───" % label)
		_dev_jump_popup.set_item_disabled(_dev_jump_popup.item_count - 1, true)
		# One row per chapter.
		for i: int in chapters.size():
			var ch_id: String = chapters[i]
			_dev_jump_popup.add_item("  ch%02d  %s" % [i + 1, ch_id], item_id)
			_dev_jump_entries[item_id] = {"scenario_path": path, "chapter_index": i}
			item_id += 1


## Returns the ordered chapter_id list for the scenario at `path`. Empty array
## on parse failure (the popup row shows the error inline).
func _read_chapter_ids(path: String) -> Array[String]:
	var raw: String = FileAccess.get_file_as_string(path)
	if raw.is_empty():
		return []
	var parsed: Variant = JSON.parse_string(raw)
	if not (parsed is Dictionary):
		return []
	var data: Dictionary = parsed as Dictionary
	var chapters: Array = data.get("chapters", []) as Array
	var out: Array[String] = []
	for ch_var: Variant in chapters:
		if not (ch_var is Dictionary):
			continue
		var ch: Dictionary = ch_var as Dictionary
		out.append(ch.get("chapter_id", "") as String)
	return out


## Performs the dev jump for the popup item the user picked. Drives
## ScenarioRunner.dev_jump_to_chapter() then transitions to BattleScene exactly
## like the natural "새 시나리오" path — BattleScene._ready picks up the loaded
## scenario + current chapter without re-loading.
func _on_dev_jump_item_selected(id: int) -> void:
	if not _dev_jump_entries.has(id):
		push_warning("MainMenu dev-jump: unknown item id %d" % id)
		return
	var entry: Dictionary = _dev_jump_entries[id] as Dictionary
	var path: String = entry["scenario_path"] as String
	var idx: int = entry["chapter_index"] as int
	var runner: Node = get_node_or_null("/root/ScenarioRunner")
	if runner == null:
		push_warning("MainMenu dev-jump: ScenarioRunner autoload missing")
		return
	# Reset cleans out any previous scenario state; set the active path so a
	# subsequent _restart_scenario inside BattleScene reloads THIS scenario,
	# not the default shu_canon_full.
	runner.reset_for_tests()
	runner.set_active_scenario_path(path)
	if not runner.dev_jump_to_chapter(path, idx):
		push_warning("MainMenu dev-jump: dev_jump_to_chapter(%s, %d) refused" % [path, idx])
		return
	get_tree().change_scene_to_file(_BATTLE_SCENE_PATH)


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


# ─── Signature archive (S65+ — meta progression) ─────────────────────────────


## Refreshes the SignatureBadge label from ProgressArchive's cross-campaign
## cumulative unlock count. Falls back to 0 when the ProgressArchive autoload
## is missing (defensive). Reads ProgressArchive — NOT SaveContext — so the
## badge reflects all-time unlocks (survives save-slot deletion + new campaign).
func _refresh_signature_state() -> void:
	if _signature_badge == null:
		return
	_signature_badge.text = "✦ %d/5 시그니처 (누적)" % _read_archive_unlocked_keys().size()


## Returns the cross-campaign cumulative unlocked signature keys from
## ProgressArchive. Empty PackedStringArray when the autoload is missing.
func _read_archive_unlocked_keys() -> PackedStringArray:
	var archive: Node = get_node_or_null("/root/ProgressArchive")
	if archive == null:
		return PackedStringArray()
	return archive.call("get_unlocked_keys") as PackedStringArray


## Mounts SignatureArchivePopup as a full-screen overlay. Closes on user
## tap of close button or ui_cancel (Esc). Always mountable — empty
## archive shows a 0/5 archive with all 5 미달성 cards.
func _on_archive_pressed() -> void:
	var keys: PackedStringArray = _read_archive_unlocked_keys()
	var popup_script: GDScript = load("res://src/feature/main_menu/signature_archive_popup.gd") as GDScript
	var popup: Control = popup_script.call("make", keys) as Control
	add_child(popup)
