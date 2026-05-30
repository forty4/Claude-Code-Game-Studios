extends Node
## G-30 windowed smoke — S97 intimidate_scroll (ENEMY debuff) lifecycle.
##
## Headless unit tests prove the controller logic (set enemy pending_buff,
## magnitude 0.70, debuff signal). Per G-30 they do NOT exercise the windowed
## lifecycle: distribution load → use_item → unit_pending_debuff_changed →
## battle_scene._on_unit_pending_debuff_changed → red ▼ DebuffBadge render.
## This harness boots ch11 windowed (where 제갈량 carries intimidate_scroll),
## repositions 제갈량 adjacent to an enemy (smoke, not a legal move), fires the
## item, and asserts: ENEMY target tiles publish + the enemy's pending_buff is
## set + a "DebuffBadge" node renders on the enemy polygon. Screenshot attests.
##
## Run:  godot --path . res://tools/ci/g30/g30_intimidate_smoke.tscn
## Exit 0 = verified ; non-zero = failure.

const SHU_PATH: String = "res://assets/data/scenarios/shu_canon_main.json"
const SHOT_DIR: String = "/tmp/g30/"
const ZHUGE: StringName = &"shu_006_zhuge_liang"
const CH11_IDX: int = 10

var _battle: Node = null


func _ready() -> void:
	print("[G30] ===== S97 intimidate_scroll windowed smoke (ch11) =====")
	get_tree().create_timer(30.0).timeout.connect(func() -> void:
		push_error("[G30] FAILSAFE TIMEOUT (30s) — quitting")
		_finish(9))
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	var runner: Node = get_node_or_null("/root/ScenarioRunner")
	if runner == null:
		push_error("[G30] ScenarioRunner missing"); _finish(2); return
	runner.call("reset_for_tests")
	runner.call("set_active_scenario_path", SHU_PATH)
	runner.call("dev_jump_to_chapter", SHU_PATH, CH11_IDX)

	var bs: PackedScene = load("res://scenes/battle/battle_scene.tscn") as PackedScene
	_battle = bs.instantiate()
	get_tree().root.add_child(_battle)
	await _dismiss_story_beats(_battle)

	var controller: Node = await _await_node(_battle, "GridBattleController", 240)
	if controller == null:
		push_error("[G30] GridBattleController never appeared"); await _shot("00_no_controller"); _finish(4); return
	for _i in 12:
		await get_tree().process_frame

	var units: Dictionary = controller.get("_units")
	# Locate 제갈량 (carries intimidate_scroll per S97 distribution) + an enemy.
	var zhuge_id: int = -1
	var slot: int = -1
	var enemy_id: int = -1
	for uid_v: Variant in units:
		var u: Object = units[uid_v]
		if int(u.get("side")) != 0 and enemy_id == -1:
			enemy_id = int(uid_v)
		if StringName(u.get("hero_id")) == ZHUGE:
			zhuge_id = int(uid_v)
			var inv: Array = u.get("inventory")
			for s: int in range(inv.size()):
				if StringName(inv[s]) == &"intimidate_scroll":
					slot = s
	print("[G30] zhuge_id=", zhuge_id, " intimidate_slot=", slot, " enemy_id=", enemy_id)
	if zhuge_id == -1 or slot == -1:
		push_error("[G30] FAIL: 제갈량 has no intimidate_scroll in ch11 (distribution not loaded)")
		_finish(5); return
	if enemy_id == -1:
		push_error("[G30] FAIL: no enemy unit found"); _finish(6); return

	# Reposition 제갈량 adjacent to the enemy (smoke seam — bypasses movement) so
	# the enemy is within ENEMY_DISRUPT_RANGE, then make 제갈량 the active unit.
	var enemy: Object = units[enemy_id]
	var enemy_pos: Vector2i = enemy.get("position") as Vector2i
	var zhuge: Object = units[zhuge_id]
	zhuge.set("position", enemy_pos + Vector2i(1, 0))
	controller.set("_active_turn_unit_id", zhuge_id)

	# 1. ENEMY target tiles publish (get_item_target_tiles ENEMY arm).
	var tiles: PackedVector2Array = controller.call("get_item_target_tiles", zhuge_id, &"intimidate_scroll")
	print("[G30] ENEMY target tiles for intimidate_scroll: ", tiles)
	var tiles_ok: bool = Vector2(enemy_pos.x, enemy_pos.y) in tiles

	# 2. Fire the item at the enemy tile.
	var fired: bool = controller.call("use_item", zhuge_id, slot, enemy_pos)
	for _i in 6:
		await get_tree().process_frame
	var enemy_pb: Dictionary = enemy.get("pending_buff")
	var kind: String = String(enemy_pb.get(&"kind", &""))
	var mag: float = float(enemy_pb.get(&"magnitude", 0.0))
	print("[G30] use_item fired=", fired, " enemy.pending_buff kind=", kind, " magnitude=", mag)

	# 3. The ▼ DebuffBadge renders on the enemy polygon. ChapterVisuals (and the
	# unit polygons + badges) mount under /root, NOT under _battle (G-31), so
	# search the whole tree from root.
	await get_tree().process_frame
	var badge: Node = _find_descendant_named(get_tree().root, "DebuffBadge")
	print("[G30] DebuffBadge node present: ", badge != null, " -> ", badge)
	await _shot("s97_intimidate_ch11")

	var ok: bool = true
	if not tiles_ok:
		push_error("[G30] FAIL: enemy tile %s not in published ENEMY target tiles" % enemy_pos); ok = false
	if not fired:
		push_error("[G30] FAIL: use_item(intimidate) did not fire"); ok = false
	if kind != "intimidate":
		push_error("[G30] FAIL: enemy pending_buff kind '%s' != 'intimidate'" % kind); ok = false
	if absf(mag - 0.70) > 0.001:
		push_error("[G30] FAIL: magnitude %f != 0.70" % mag); ok = false
	if badge == null:
		push_error("[G30] FAIL: DebuffBadge ▼ did not render on the enemy polygon"); ok = false

	if ok:
		print("[G30] PASS — intimidate_scroll: ENEMY tiles + debuff applied (×0.70) + ▼ badge rendered.")
		_finish(0)
	else:
		_finish(7)


func _find_descendant_named(n: Node, target: String) -> Node:
	if n.name == target:
		return n
	for c: Node in n.get_children():
		var found: Node = _find_descendant_named(c, target)
		if found != null:
			return found
	return null


func _dismiss_story_beats(battle: Node) -> void:
	for _i in 30:
		var screen: Node = battle.get_node_or_null("HUDLayer/StoryBeatScreen")
		if screen == null:
			await get_tree().process_frame
			await get_tree().process_frame
			if battle.get_node_or_null("HUDLayer/StoryBeatScreen") == null:
				return
			continue
		if screen.has_method("advance"):
			screen.call("advance")
		for _j in 3:
			await get_tree().process_frame


func _await_node(root: Node, path: String, max_frames: int) -> Node:
	for _i in max_frames:
		var n: Node = root.get_node_or_null(path)
		if n != null:
			return n
		await get_tree().process_frame
	return null


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(SHOT_DIR + tag + ".png")
		print("[G30] screenshot -> ", SHOT_DIR + tag + ".png")


func _finish(code: int) -> void:
	print("[G30] DONE (exit ", code, ")")
	get_tree().quit(code)
