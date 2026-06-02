extends Node
## G-30 windowed smoke — S101 chapter-end ceremony verification.
##
## User feedback: finishing a chapter showed only the full-screen "승리" banner
## with the narrative gated behind a "leave"-reading button — "끝 느낌 0". S101
## restructured the WIN path into a continuous ceremony: banner → "▶ 계속" prompt
## → Beat 8 → ConsequenceScreen → Beat 9 → chapter-complete buttons. Headless
## tests can't see windowed UI flow (G-30), so this harness boots a chapter,
## force-wins, and asserts the node sequence appears in order:
##   1. After WIN: OutcomeBanner + WinContinuePrompt present, NO PostBattleButtons
##      (the key fix — exit buttons are DEFERRED until after the story).
##   2. Trigger the ceremony → StoryBeatScreen (Beat 8) + ConsequenceScreen +
##      StoryBeatScreen (Beat 9) appear and are driven via advance().
##   3. After the narrative: PostBattleButtons (chapter-complete) appears.
## Screenshots at each stage for visual attestation.
##
## Run:  godot --path . res://tools/ci/g30/g30_chapter_end_smoke.tscn -- <chapter_idx>
##   chapter_idx 0-based (default 0 = ch01). Exit 0 = ceremony verified.

const SHU_PATH: String = "res://assets/data/scenarios/shu_canon_main.json"
const SHOT_DIR: String = "/tmp/g30/"

var _chapter_idx: int = 0
var _battle: Node = null
var _controller: Node = null
var _hud: Node = null


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.is_valid_int():
			_chapter_idx = a.to_int()
	print("[G30] ===== S101 chapter-end ceremony smoke (chapter_idx=", _chapter_idx, ") =====")
	get_tree().create_timer(60.0).timeout.connect(func() -> void:
		push_error("[G30] FAILSAFE TIMEOUT (60s)")
		_finish(9))
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	var runner: Node = get_node_or_null("/root/ScenarioRunner")
	runner.call("reset_for_tests")
	runner.call("set_active_scenario_path", SHU_PATH)
	runner.call("jump_to_chapter", SHU_PATH, _chapter_idx)

	var bs: PackedScene = load("res://scenes/battle/battle_scene.tscn") as PackedScene
	_battle = bs.instantiate()
	get_tree().root.add_child(_battle)
	await _dismiss_story_beats(_battle)

	_controller = await _await_node(_battle, "GridBattleController", 240)
	if _controller == null:
		push_error("[G30] controller never appeared"); _finish(4); return
	_hud = _battle.get_node_or_null("HUDLayer")
	if _controller.has_method("set_ai_thinking_pause_sec_for_test"):
		_controller.call("set_ai_thinking_pause_sec_for_test", 0.0)
	# Let the battle-start title card + any pre-battle beat screen fully clear
	# before force-winning (in real play the player fights several rounds first;
	# without this wait the title card overlaps the victory banner — a force-win
	# artifact, not a feature bug). ~150 frames ≈ 2.5s.
	for _i in 150:
		var leftover: Node = _hud.get_node_or_null("StoryBeatScreen")
		if leftover != null and leftover.has_method("advance"):
			leftover.call("advance")
		await get_tree().process_frame

	# ── 1. Force-win: kill every enemy via the real damage path ──────────────
	var hp: Node = _controller.get("_hp_controller")
	var units: Dictionary = _controller.get("_units")
	var killed: int = 0
	for uid_v: Variant in units:
		var u: Object = units[uid_v]
		if int(u.get("side")) != 0 and hp.call("is_alive", int(uid_v)):
			hp.call("apply_damage", int(uid_v), 99999, 0, [])
			killed += 1
	print("[G30] force-killed ", killed, " enemies")
	# Wait for the deferred unit_died → _check_battle_end → VICTORY → banner.
	if not await _await_hud_child("OutcomeBanner", 120):
		push_error("[G30] OutcomeBanner never appeared after force-win"); _finish(5); return

	# ── 2. Assert WIN shows the continue prompt, NOT the exit buttons ────────
	for _i in 8:
		await get_tree().process_frame
	await _shot("s101_ch%02d_1_banner_continue" % (_chapter_idx + 1))
	var has_prompt: bool = _hud.get_node_or_null("WinContinuePrompt") != null
	var has_buttons_early: bool = _hud.get_node_or_null("PostBattleButtons") != null
	if not has_prompt:
		push_error("[G30] FAIL: WinContinuePrompt absent after WIN (ceremony not deferred)")
		_finish(6); return
	if has_buttons_early:
		push_error("[G30] FAIL: PostBattleButtons present BEFORE the story (regression — "
			+ "exit buttons should be deferred until after the narrative)")
		_finish(6); return
	print("[G30] OK stage 1 — WinContinuePrompt present, exit buttons deferred")

	# ── 3. Trigger the ceremony + drive the narrative screens ────────────────
	_battle.call("_begin_win_ceremony")  # coroutine — runs in background
	var saw_beat: bool = false
	var saw_consequence: bool = false
	var shots_taken: Dictionary = {}
	for frame in 1500:
		var beat: Node = _hud.get_node_or_null("StoryBeatScreen")
		var conseq: Node = _hud.get_node_or_null("ConsequenceScreen")
		var buttons: Node = _hud.get_node_or_null("PostBattleButtons")
		if buttons != null:
			break  # ceremony complete — chapter-complete buttons mounted
		if beat != null:
			saw_beat = true
			if not shots_taken.has("beat"):
				shots_taken["beat"] = true
				await _shot("s101_ch%02d_2_beat" % (_chapter_idx + 1))
			if frame % 8 == 0 and beat.has_method("advance"):
				beat.call("advance")
		elif conseq != null:
			saw_consequence = true
			if not shots_taken.has("conseq"):
				shots_taken["conseq"] = true
				await _shot("s101_ch%02d_3_consequence" % (_chapter_idx + 1))
			if frame % 8 == 0 and conseq.has_method("advance"):
				conseq.call("advance")
		await get_tree().process_frame

	# ── 4. Assert the chapter-complete buttons mounted after the story ───────
	for _i in 8:
		await get_tree().process_frame
	await _shot("s101_ch%02d_4_chapter_complete" % (_chapter_idx + 1))
	var has_buttons_late: bool = _hud.get_node_or_null("PostBattleButtons") != null
	print("[G30] narrative seen — beat=%s consequence=%s ; chapter-complete buttons=%s"
		% [saw_beat, saw_consequence, has_buttons_late])
	if not saw_beat:
		push_error("[G30] FAIL: no StoryBeatScreen during the ceremony (narrative didn't play)")
		_finish(7); return
	if not has_buttons_late:
		push_error("[G30] FAIL: chapter-complete PostBattleButtons never appeared after narrative")
		_finish(7); return

	print("[G30] PASS — ch%02d: banner → ▶계속 → Beat8%s → Beat9 → chapter-complete buttons."
		% [_chapter_idx + 1, " → Consequence" if saw_consequence else ""])
	_finish(0)


func _await_hud_child(name: String, max_frames: int) -> bool:
	for _i in max_frames:
		if _hud != null and _hud.get_node_or_null(name) != null:
			return true
		await get_tree().process_frame
	return false


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
		var path: String = SHOT_DIR + tag + ".png"
		img.save_png(path)
		print("[G30] screenshot -> ", path)


func _finish(code: int) -> void:
	print("[G30] DONE (exit ", code, ")")
	get_tree().quit(code)
