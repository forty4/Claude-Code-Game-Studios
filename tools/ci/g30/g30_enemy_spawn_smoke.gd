extends Node
## G-30 windowed smoke — S96 late-game 5th-enemy spawn verification.
##
## Headless tests assert the scenario JSON has 5 enemy roster entries for
## ch11-14 (s96_late_roster_balance_sentinel_test.gd), but per G-30 a headless
## PASS does NOT gate the windowed lifecycle — the actual battle_scene
## `_build_battle_units_from_chapter` → roster spawn → MapGrid placement path is
## only exercised when the scene boots for real. This harness boots windowed,
## dev-jumps to the target chapter, lets the real battle build its units, then
## asserts the 5th enemy (unit_id=8) actually spawned with the authored hero_id,
## side=enemy, and grid position — plus a screenshot for visual attestation.
##
## Run:  godot --path . res://tools/ci/g30/g30_enemy_spawn_smoke.tscn -- <chapter_idx>
##   chapter_idx is 0-based: 10=ch11, 11=ch12, 12=ch13, 13=ch14.
## Exit 0 = spawn verified ; non-zero = failure (see _finish codes).

const SHU_PATH: String = "res://assets/data/scenarios/shu_canon_main.json"
const SHOT_DIR: String = "/tmp/g30/"
const NEW_ENEMY_UID: int = 8

# Expected S96 5th enemy per 0-based chapter index: [hero_id, archetype, Vector2i].
const PLAN: Dictionary = {
	10: ["wei_001_cao_cao", "coordinator", Vector2i(12, 3)],
	11: ["wei_001_cao_cao", "coordinator", Vector2i(12, 3)],
	12: ["wei_008_xu_chu", "aggressor", Vector2i(11, 4)],
	13: ["wei_001_cao_cao", "coordinator", Vector2i(13, 3)],
}

var _battle: Node = null
var _chapter_idx: int = 10


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.is_valid_int():
			_chapter_idx = a.to_int()
	print("[G30] ===== S96 enemy-spawn windowed smoke (chapter_idx=", _chapter_idx, ") =====")
	var failsafe: SceneTreeTimer = get_tree().create_timer(30.0)
	failsafe.timeout.connect(func() -> void:
		push_error("[G30] FAILSAFE TIMEOUT (30s) — quitting")
		_finish(9))
	# Defer so the SceneTree finishes setting up before we add_child under /root
	# (a direct call from _ready hits "Parent node is busy setting up children").
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	if not PLAN.has(_chapter_idx):
		push_error("[G30] chapter_idx %d not in S96 PLAN (use 10-13)" % _chapter_idx)
		_finish(1); return
	var spec: Array = PLAN[_chapter_idx] as Array
	var want_hero: String = spec[0] as String
	var want_arch: String = spec[1] as String
	var want_pos: Vector2i = spec[2] as Vector2i

	# ── 1. Drive ScenarioRunner → target chapter ─────────────────────────────
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

	# ── 2b. Dismiss the pre-battle StoryBeatScreen so _start_battle() builds ──
	await _dismiss_story_beats(_battle)

	# ── 3. Wait for GridBattleController + its unit registry ─────────────────
	var controller: Node = await _await_node(_battle, "GridBattleController", 240)
	if controller == null:
		push_error("[G30] GridBattleController never appeared (battle build failed?)")
		await _shot("00_no_controller"); _finish(4); return
	# Let the battle settle (turn loop, layout, unit polygons).
	for _i in 12:
		await get_tree().process_frame

	var units: Dictionary = controller.get("_units")
	if units == null:
		push_error("[G30] controller._units null"); _finish(5); return

	# ── 4. Enumerate spawned units; count enemies, find uid 8 ────────────────
	var enemy_ids: Array[int] = []
	var player_ids: Array[int] = []
	for uid_v: Variant in units:
		var u: Object = units[uid_v]
		if int(u.get("side")) != 0:
			enemy_ids.append(int(uid_v))
		else:
			player_ids.append(int(uid_v))
	enemy_ids.sort()
	player_ids.sort()
	print("[G30] spawned players=", player_ids.size(), " ", player_ids)
	print("[G30] spawned enemies=", enemy_ids.size(), " ", enemy_ids)
	for eid: int in enemy_ids:
		var eu: Object = units[eid]
		print("[G30]   enemy uid=", eid, " hero=", eu.get("hero_id"),
			" side=", eu.get("side"), " arch=", eu.get("archetype"), " pos=", eu.get("position"))

	await _shot("s96_ch%02d_enemies" % (_chapter_idx + 1))

	# ── 5. Assertions ────────────────────────────────────────────────────────
	var ok: bool = true
	if enemy_ids.size() != 5:
		push_error("[G30] FAIL: enemy count %d != 5 (S96 6v5 spawn not realized)" % enemy_ids.size())
		ok = false
	var fifth: Object = controller.call("get_battle_unit", NEW_ENEMY_UID)
	if fifth == null:
		push_error("[G30] FAIL: no spawned unit with unit_id=8")
		ok = false
	else:
		var got_hero: String = String(fifth.get("hero_id"))
		var got_arch: String = String(fifth.get("archetype"))
		var got_side: int = int(fifth.get("side"))
		var got_pos: Vector2i = fifth.get("position") as Vector2i
		if got_hero != want_hero:
			push_error("[G30] FAIL: uid8 hero_id '%s' != '%s'" % [got_hero, want_hero]); ok = false
		if got_side == 0:
			push_error("[G30] FAIL: uid8 side=%d (expected enemy, non-zero)" % got_side); ok = false
		if got_arch != want_arch:
			push_error("[G30] FAIL: uid8 archetype '%s' != '%s'" % [got_arch, want_arch]); ok = false
		if got_pos != want_pos:
			push_error("[G30] FAIL: uid8 pos %s != authored %s" % [got_pos, want_pos]); ok = false
		if ok:
			print("[G30] uid8 OK — hero=", got_hero, " side=", got_side,
				" arch=", got_arch, " pos=", got_pos, " (authored ", want_pos, ")")

	if ok:
		print("[G30] PASS — ch%02d windowed spawned 5 enemies; 5th = %s @ %s, side=enemy."
			% [_chapter_idx + 1, want_hero, want_pos])
		_finish(0)
	else:
		_finish(6)


func _dismiss_story_beats(battle: Node) -> void:
	for _i in 30:
		var screen: Node = battle.get_node_or_null("HUDLayer/StoryBeatScreen")
		if screen == null:
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
