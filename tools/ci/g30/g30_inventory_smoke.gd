extends Node
## G-30 WINDOWED SMOKE HARNESS — Inventory Panel (UI-GB-15) slot-click verification.
##
## Purpose (S93): close the S92 BLOCKER — the inventory slot-button click was left
## UNCONFIRMED ("click reaches the Button?"). Headless GdUnit tests mount the real
## panel but call `.pressed.emit()` / `_on_inventory_slot_pressed()` directly; they
## NEVER dispatch a real mouse event through the live viewport → CanvasLayer →
## Container mouse_filter → Button picking chain. That gap is exactly G-30.
##
## This is the project's FIRST windowed smoke harness, per G-30 §Correct step 6
## ("synthesize InputEventMouseButton via push_input + assert the downstream
## handler ran"). It must run WINDOWED (not --headless) — headless has no real
## render/GUI-pick path.
##
## Run:  godot --path . res://tools/ci/g30/g30_inventory_smoke.tscn
## (the harness quits itself; a 25s failsafe timer force-quits if it stalls).
##
## What it does:
##   1. Drive ScenarioRunner → ch01 (dev_jump_to_chapter), instantiate the real
##      battle_scene.tscn under /root (faithful to the MVP dev-jump path, which
##      uses change_scene — NOT the SceneManager pause-overworld path, so no
##      process_mode=DISABLED confound).
##   2. Wait for HUD + inventory panel + slot buttons to mount & lay out.
##   3. Force the panel open for a FRESH player unit (token unspent → buttons
##      enabled). We bypass _open_inventory_panel's active-turn logic on purpose:
##      the I-key→open path (G-30 behavior a) is already user-confirmed; the
##      UNCONFIRMED part is the slot CLICK.
##   4. Synthesize a real left-click at the slot-0 Button's center via
##      viewport.push_input(ev, in_local_coords=true) — canvas-space picking, the
##      space the leading hypothesis (Container mouse_filter swallow) lives in.
##   5. Report: did the Button's `pressed` fire? did `unit_item_used` fire? what
##      control does gui_get_hovered_control() return at that point? + rects,
##      z-order, mouse_filter chain. Screenshots at each step.
##
## Verdict lines are prefixed [G30] for easy grep.

const SHU_PATH: String = "res://assets/data/scenarios/shu_canon_main.json"
const SHOT_DIR: String = "/tmp/g30/"

var _battle: Node = null
var _slot_pressed_fired: bool = false
var _item_used_fired: bool = false
var _feedback_flashed: bool = false
## "self" (default): click a heal/strength/march SELF item — verify it fires +
## flashes + closes (behaviors b/c). "fire": click fire_scroll — verify it ARMS
## a GROUND target overlay (panel stays open, range disc renders) — behavior d.
## "ally" (S94): click aid_potion / rally_scroll — verify it ARMS an ALLY target
## overlay (금록 palette, panel stays open, ally-occupied tiles published).
## Select via:  godot --path . res://…/g30_inventory_smoke.tscn -- ally
var _mode: String = "self"
## 0-based chapter index to boot (default 0 = ch01). Pass a number after `--`.
var _chapter_idx: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a == "fire" or a == "ally":
			_mode = a
		elif a.is_valid_int():
			_chapter_idx = a.to_int()
	print("[G30] ===== inventory slot-click windowed smoke (mode=", _mode, " chapter_idx=", _chapter_idx, ") =====")
	print("[G30] window=", DisplayServer.window_get_size(), " viewport=", get_viewport().get_visible_rect().size,
		" content_scale=", get_window().content_scale_factor, " screen_scale=", DisplayServer.screen_get_scale())
	# Failsafe: never hang CI / the agent.
	get_tree().create_timer(25.0).timeout.connect(func() -> void:
		push_error("[G30] FAILSAFE TIMEOUT (25s) — quitting")
		_finish(99))
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)

	# ── 1. Drive ScenarioRunner → ch01 ────────────────────────────────────────
	var runner: Node = get_node_or_null("/root/ScenarioRunner")
	if runner == null:
		push_error("[G30] ScenarioRunner autoload missing"); _finish(2); return
	runner.call("reset_for_tests")
	runner.call("set_active_scenario_path", SHU_PATH)
	var jumped: bool = runner.call("dev_jump_to_chapter", SHU_PATH, _chapter_idx)
	print("[G30] dev_jump_to_chapter(idx ", _chapter_idx, ") -> ", jumped)

	# ── 2. Instantiate the real battle scene under /root ─────────────────────
	var bs: PackedScene = load("res://scenes/battle/battle_scene.tscn") as PackedScene
	if bs == null:
		push_error("[G30] battle_scene.tscn failed to load"); _finish(3); return
	_battle = bs.instantiate()
	get_tree().root.add_child(_battle)
	print("[G30] battle scene mounted under /root")

	# ── 2b. Dismiss the windowed pre-battle StoryBeatScreen ───────────────────
	# Windowed runs mount a StoryBeatScreen (Beat 1 + Beat 3) that AWAITS player
	# input before _start_battle() builds the HUD. Walk past it via its public
	# advance(); when it self-frees (sequence_finished), the HUD build proceeds.
	await _dismiss_story_beats(_battle)

	# ── 3. Wait for the slot-0 Button to exist ───────────────────────────────
	var panel_path: String = "HUDLayer/BattleHUD/UI_GB_15_InventoryPanel"
	var slot0_path: String = panel_path + "/VBoxContainer/SlotsHBox/Slot0Button"
	var slot0: Button = await _await_node(_battle, slot0_path, 240) as Button
	if slot0 == null:
		push_error("[G30] slot-0 button never appeared (battle build failed?)")
		await _shot("00_no_slot")
		_finish(4); return
	var hud: Control = _battle.get_node_or_null("HUDLayer/BattleHUD") as Control
	var controller: Node = _battle.get_node_or_null("GridBattleController")
	var panel: Control = _battle.get_node_or_null(panel_path) as Control
	print("[G30] hud=", hud, " controller=", controller, " panel=", panel)
	# Let the battle settle a few frames (turn loop, layout).
	for _i in 5:
		await get_tree().process_frame
	await _shot("01_battle_booted")

	# ── 4. Target the ACTIVE turn unit (the real play scenario) ───────────────
	# use_item's turn gate requires unit_id == _active_turn_unit_id, so to test
	# the HAPPY PATH (item actually fires, not just routing) we must open the
	# panel for whoever's turn it is. Find their first SELF-target item slot.
	var units: Dictionary = controller.get("_units")
	var active_id: int = int(controller.call("get_active_turn_unit_id"))
	print("[G30] active_turn_unit_id=", active_id)
	# Full per-player-unit inventory dump — confirms the chapter's authored
	# starting_inventory_by_hero actually loaded for EVERY hero in this chapter.
	print("[G30] --- player inventories (chapter idx ", _chapter_idx, ") ---")
	for uid: int in units:
		var pu: Object = units[uid]
		if int(pu.get("side")) == 0:
			print("[G30]   uid=", uid, " ", pu.get("hero_id"), " inv=", pu.get("inventory"))
	var wanted: Array = [&"heal_potion", &"strength_scroll", &"march_scroll"]
	if _mode == "fire":
		wanted = [&"fire_scroll"]
	elif _mode == "ally":
		wanted = [&"aid_potion", &"rally_scroll"]
	var puid: int = -1
	var punit: Object = null
	var slot_idx: int = -1
	# Prefer the active unit if it's a player with a wanted item.
	if units.has(active_id) and int(units[active_id].get("side")) == 0:
		var au: Object = units[active_id]
		var inv: Array = au.get("inventory")
		for s in inv.size():
			if inv[s] in wanted:
				puid = active_id; punit = au; slot_idx = s; break
	# Fallback: any player with a wanted item (routing-only — use_item will turn-gate).
	if puid == -1:
		for uid: int in units:
			var u: Object = units[uid]
			if int(u.get("side")) == 0:
				var inv2: Array = u.get("inventory")
				for s2 in inv2.size():
					if inv2[s2] in wanted:
						puid = uid; punit = u; slot_idx = s2; break
			if puid != -1: break
	if puid == -1:
		push_error("[G30] no player unit with a wanted item (%s) in ch01 roster" % str(wanted)); _finish(5); return
	var happy_path: bool = (puid == active_id)
	print("[G30] target unit_id=", puid, " hero=", punit.get("hero_id"),
		" inventory=", punit.get("inventory"), " slot=", slot_idx,
		" item=", punit.get("inventory")[slot_idx], " happy_path(active)=", happy_path)

	# Slot button at the chosen index.
	var slot_btn: Button = panel.get_node_or_null(
		"VBoxContainer/SlotsHBox/Slot%dButton" % slot_idx) as Button
	if slot_btn == null:
		push_error("[G30] slot button %d missing" % slot_idx); _finish(6); return

	# HP before (for heal magnitude check).
	var hp_ctrl: Node = _battle.get_node_or_null("HPStatusController")
	var hp_before: int = int(hp_ctrl.call("get_current_hp", puid)) if hp_ctrl != null else -1

	# Open the panel for this unit.
	hud.set("_inventory_unit_id", puid)
	hud.set("_inventory_pending_slot", -1)
	hud.call("_refresh_inventory_panel", punit)
	panel.visible = true
	for _i in 4:
		await get_tree().process_frame
	print("[G30] slot.disabled(natural)=", slot_btn.disabled, " panel.visible=", panel.visible)
	if slot_btn.disabled:
		slot_btn.disabled = false
		print("[G30] force-enabled slot for routing test")
	await _shot("02_panel_open")

	# ── 5. Diagnostics: rects, z-order, mouse_filter chain ────────────────────
	_dump_geometry(panel, slot_btn)

	# ── 6. Synthesize the click in canvas-local space ─────────────────────────
	var center: Vector2 = slot_btn.get_global_rect().get_center()
	print("[G30] slot global_rect=", slot_btn.get_global_rect(), " click_center=", center)
	_push_mouse_motion(center)
	await get_tree().process_frame
	var vp: Viewport = get_viewport()
	var hovered: Control = null
	if vp.has_method("gui_get_hovered_control"):
		hovered = vp.gui_get_hovered_control()
	print("[G30] gui_get_hovered_control @center = ", hovered, "  (== slot? ", hovered == slot_btn, ")")

	# Wire observers BEFORE the click.
	slot_btn.pressed.connect(func() -> void: _slot_pressed_fired = true)
	if controller.has_signal("unit_item_used"):
		controller.connect("unit_item_used", func(_a: int, _b: StringName, _c: int, _d: int) -> void:
			_item_used_fired = true)
	var feedback: Label = panel.get_node_or_null("VBoxContainer/FeedbackLabel") as Label

	# Press + release.
	_push_mouse_button(center, true)
	await get_tree().process_frame
	_push_mouse_button(center, false)
	for _i in 6:
		await get_tree().process_frame
	if feedback != null and feedback.visible:
		_feedback_flashed = true
	var feedback_text: String = feedback.text if feedback != null else ""
	await _shot("03_after_click")

	# ── 7. Behavior checks — branch by mode ───────────────────────────────────
	var verdict_ok: bool = false
	if _mode == "fire":
		# Behavior (d): fire_scroll is non-SELF/GROUND → clicking ARMS a target
		# overlay. Panel STAYS open; controller arms tile-click gate; the range
		# disc tiles get published to ChapterVisuals.
		var pending_slot: int = int(hud.get("_inventory_pending_slot"))
		var armed: bool = bool(controller.get("_item_target_armed")) if controller.has_method("set_item_target_armed") else false
		var tiles: PackedVector2Array = controller.call("get_item_target_tiles", puid, &"fire_scroll")
		print("[G30] -------- RESULT (fire) --------")
		print("[G30] CLICK_REACHED_BUTTON (pressed)   = ", _slot_pressed_fired)
		print("[G30] panel STILL open (arm, not fire) = ", panel.visible)
		print("[G30] _inventory_pending_slot          = ", pending_slot, " (== ", slot_idx, "?)")
		print("[G30] controller _item_target_armed    = ", armed)
		print("[G30] fire_scroll target tiles (disc)  = ", tiles.size(), " tiles -> ", tiles)
		print("[G30] item_used (should be FALSE)      = ", _item_used_fired)
		# let the overlay draw for the screenshot
		for _i in 4:
			await get_tree().process_frame
		await _shot("05_fire_armed_overlay")
		verdict_ok = _slot_pressed_fired and panel.visible and pending_slot == slot_idx \
			and armed and tiles.size() > 0 and not _item_used_fired
		print("[G30] ===== VERDICT: ", ("PASS — fire_scroll arms GROUND overlay (range disc shown)" if verdict_ok else "FAIL"), " =====")
		_finish(0 if verdict_ok else 1)
		return

	if _mode == "ally":
		# S94 — aid_potion / rally_scroll are ALLY-target → clicking ARMS an ALLY
		# overlay (금록 palette). Panel STAYS open; controller arms the tile-click
		# gate; get_item_target_tiles publishes the reachable ally-occupied tiles.
		var item_id_ally: StringName = punit.get("inventory")[slot_idx]
		var pending_slot: int = int(hud.get("_inventory_pending_slot"))
		var armed: bool = bool(controller.get("_item_target_armed")) if controller.has_method("set_item_target_armed") else false
		var tiles: PackedVector2Array = controller.call("get_item_target_tiles", puid, item_id_ally)
		var tiles_in_reach: bool = tiles.size() > 0
		print("[G30] -------- RESULT (ally) --------")
		print("[G30] item                          = ", item_id_ally)
		print("[G30] CLICK_REACHED_BUTTON (pressed) = ", _slot_pressed_fired)
		print("[G30] panel STILL open (arm)         = ", panel.visible)
		print("[G30] _inventory_pending_slot        = ", pending_slot, " (== ", slot_idx, "?)")
		print("[G30] controller _item_target_armed  = ", armed)
		print("[G30] ALLY target tiles              = ", tiles.size(), " -> ", tiles)
		print("[G30] ally in reach at deploy        = ", tiles_in_reach)
		print("[G30] item_used (should be FALSE)    = ", _item_used_fired)
		for _i in 4:
			await get_tree().process_frame
		await _shot("05_ally_armed_overlay")
		# Core arm verdict does NOT depend on ally proximity (arming is geometry-
		# independent). tiles_in_reach is reported + WARN-flagged but the overlay
		# render correctness is what the screenshot attests.
		verdict_ok = _slot_pressed_fired and panel.visible and pending_slot == slot_idx \
			and armed and not _item_used_fired
		var verdict_msg: String = "FAIL"
		if verdict_ok:
			verdict_msg = "PASS — ALLY item arms 금록 overlay"
			if not tiles_in_reach:
				verdict_msg += " (WARN: no ally within ALLY_SUPPORT_RANGE at deploy)"
		print("[G30] ===== VERDICT: ", verdict_msg, " =====")
		_finish(0 if verdict_ok else 1)
		return

	# self mode — behaviors (b)+(c)
	var hp_after: int = int(hp_ctrl.call("get_current_hp", puid)) if hp_ctrl != null else -1
	var ui_elems: Dictionary = hud.get("_ui_elements")
	var buff_glyph: Control = ui_elems.get(&"UI-GB-16") as Control
	var glyph_visible: bool = buff_glyph != null and buff_glyph.visible
	var closed_after_fire: bool = false
	if happy_path:
		for _i in 50:  # ~0.8s @60fps
			await get_tree().process_frame
			if not panel.visible:
				closed_after_fire = true; break

	print("[G30] -------- RESULT (self) --------")
	print("[G30] CLICK_REACHED_BUTTON (pressed fired) = ", _slot_pressed_fired)
	print("[G30] unit_item_used fired (item FIRED)    = ", _item_used_fired)
	print("[G30] feedback flashed                     = ", _feedback_flashed, "  text='", feedback_text, "'")
	print("[G30] HP ", hp_before, " -> ", hp_after, " (heal delta=", hp_after - hp_before, ")")
	print("[G30] UI-GB-16 buff glyph visible (c)      = ", glyph_visible)
	print("[G30] panel auto-closed after fire (b)     = ", closed_after_fire)
	await _shot("05_after_dwell")

	verdict_ok = _slot_pressed_fired
	if happy_path:
		verdict_ok = _slot_pressed_fired and _item_used_fired and closed_after_fire
	print("[G30] ===== VERDICT: ",
		("PASS — slot click " + ("fires item + closes panel (happy path)" if happy_path else "routes to button")) \
		if verdict_ok else "FAIL", " =====")
	_finish(0 if verdict_ok else 1)


# ── helpers ──────────────────────────────────────────────────────────────────

func _dismiss_story_beats(battle: Node) -> void:
	for _i in 30:
		var screen: Node = battle.get_node_or_null("HUDLayer/StoryBeatScreen")
		if screen == null:
			# Give it a couple frames to mount, then accept absence as "done".
			await get_tree().process_frame
			await get_tree().process_frame
			if battle.get_node_or_null("HUDLayer/StoryBeatScreen") == null:
				print("[G30] story beats dismissed (screen gone after ", _i, " advances)")
				return
			continue
		if screen.has_method("advance"):
			screen.call("advance")
		for _j in 3:
			await get_tree().process_frame
	print("[G30] WARNING: StoryBeatScreen still present after 30 advances")


func _await_node(root: Node, path: String, max_frames: int) -> Node:
	for _i in max_frames:
		var n: Node = root.get_node_or_null(path)
		if n != null:
			return n
		await get_tree().process_frame
	return null


func _push_mouse_motion(pos: Vector2) -> void:
	var m: InputEventMouseMotion = InputEventMouseMotion.new()
	m.position = pos
	m.global_position = pos
	get_viewport().push_input(m, true)


func _push_mouse_button(pos: Vector2, pressed: bool) -> void:
	var e: InputEventMouseButton = InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	get_viewport().push_input(e, true)


func _dump_geometry(panel: Control, slot0: Button) -> void:
	print("[G30] --- geometry ---")
	print("[G30] panel rect=", panel.get_global_rect(), " visible=", panel.visible,
		" mouse_filter=", panel.mouse_filter, " z_index=", panel.z_index)
	var node: Node = slot0
	while node is Control:
		var c: Control = node as Control
		print("[G30]   chain: ", c.name, " filter=", c.mouse_filter, " z=", c.z_index,
			" rect=", c.get_global_rect(), " visible=", c.visible)
		node = c.get_parent()
	# What else sits over the slot-0 center across ALL canvas layers?
	var center: Vector2 = slot0.get_global_rect().get_center()
	print("[G30] --- controls overlapping slot0 center ", center, " (filter!=IGNORE, visible) ---")
	_scan_overlaps(get_tree().root, center)


func _scan_overlaps(n: Node, p: Vector2) -> void:
	if n is Control:
		var c: Control = n as Control
		if c.visible and c.mouse_filter != Control.MOUSE_FILTER_IGNORE and c.get_global_rect().has_point(p):
			print("[G30]   over: ", c.get_path(), " filter=", c.mouse_filter, " z=", c.z_index)
	for child: Node in n.get_children():
		_scan_overlaps(child, p)


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img != null:
		var path: String = SHOT_DIR + tag + ".png"
		img.save_png(path)
		print("[G30] screenshot -> ", path)


func _finish(code: int) -> void:
	print("[G30] DONE (exit ", code, ")")
	get_tree().quit(code)
