extends Node
## G-30 faithful windowed smoke — S101/S102 WIN chapter-end ceremony, driven
## through the REAL Enter-poll path on the REAL current_scene.
##
## Why this exists: g30_chapter_end_smoke add_child's the battle under a harness
## root and calls _begin_win_ceremony() DIRECTLY; g30_real_win_smoke uses
## change_scene_to_file but never presses Enter. Neither exercises the actual
## windowed chain: Enter key → BattleScene._process forward poll →
## _invoke_primary_post_battle_action → _begin_win_ceremony → (narrative) →
## chapter-complete buttons → Enter again → chapter select. This harness does.
##
## Root-cause probe (deterministic, env-independent): after the ceremony mounts
## the chapter-complete buttons, BattleScene._process MUST still be armed
## (is_processing() == true) so the 2nd-phase Enter poll can fire. The S101/S102
## bug is that _begin_win_ceremony re-arms _battle_resolved but NOT set_process,
## leaving the chapter-complete "챕터 선택으로 ▶ (Enter)" button reachable only via
## the flaky GUI-focus path (user report: "계속 Enter만 보이는데 챕터가 안 끝남").
## We assert on is_processing() rather than the visible transition because the
## GUI focus path's reliability varies by windowed env — is_processing() targets
## the mechanism directly.
##
## Run:  godot --path . res://tools/ci/g30/g30_win_continue_chain_smoke.tscn -- <chapter_idx>
##   chapter_idx 0-based (default 0 = ch01). Exit 0 = chain verified.

const SHU_PATH: String = "res://assets/data/scenarios/shu_canon_main.json"
const BATTLE_PATH: String = "res://scenes/battle/battle_scene.tscn"
const SHOT_DIR: String = "/tmp/g30/"

var _chapter_idx: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.is_valid_int():
			_chapter_idx = a.to_int()
	print("[G30-CHAIN] ===== WIN continue-chain smoke (chapter_idx=", _chapter_idx, ") =====")
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	get_tree().create_timer(75.0).timeout.connect(func() -> void:
		push_error("[G30-CHAIN] FAILSAFE TIMEOUT (75s)"); get_tree().quit(9))
	var runner: Node = get_node_or_null("/root/ScenarioRunner")
	runner.call("reset_for_tests")
	runner.call("set_active_scenario_path", SHU_PATH)
	runner.call("jump_to_chapter", SHU_PATH, _chapter_idx)
	# This Node is the harness scene; it gets replaced by change_scene_to_file.
	# Re-parent the driver onto /root so it survives the swap and keeps running.
	var driver: Driver = Driver.new()
	driver.name = "WinChainDriver"
	driver.chapter_idx = _chapter_idx
	get_tree().root.add_child.call_deferred(driver)
	get_tree().change_scene_to_file.call_deferred(BATTLE_PATH)


class Driver extends Node:
	const SHOT_DIR: String = "/tmp/g30/"
	var chapter_idx: int = 0

	func _ready() -> void:
		_run()

	func _run() -> void:
		var battle: Node = await _await_current_scene_with("GridBattleController", 600)
		if battle == null:
			push_error("[G30-CHAIN] battle scene / controller never appeared"); _done(4); return
		var hud: Node = battle.get_node_or_null("HUDLayer")
		var controller: Node = battle.get_node_or_null("GridBattleController")
		if controller.has_method("set_ai_thinking_pause_sec_for_test"):
			controller.call("set_ai_thinking_pause_sec_for_test", 0.0)

		# Dismiss the pre-battle title card + story beat screens so the real battle
		# runs (mirrors g30_chapter_end_smoke's settle window).
		for _i in 150:
			var leftover: Node = hud.get_node_or_null("StoryBeatScreen")
			if leftover != null and leftover.has_method("advance"):
				leftover.call("advance")
			await get_tree().process_frame

		# ── Force-win via the real damage path ──────────────────────────────────
		var hp: Node = controller.get("_hp_controller")
		var units: Dictionary = controller.get("_units")
		var killed: int = 0
		for uid_v: Variant in units:
			var u: Object = units[uid_v]
			if int(u.get("side")) != 0 and hp.call("is_alive", int(uid_v)):
				hp.call("apply_damage", int(uid_v), 99999, 0, [])
				killed += 1
		print("[G30-CHAIN] force-killed ", killed, " enemies")
		if not await _await_hud_child(hud, "OutcomeBanner", 180):
			push_error("[G30-CHAIN] OutcomeBanner never appeared after force-win"); _done(5); return
		if not await _await_hud_child(hud, "WinContinuePrompt", 120):
			push_error("[G30-CHAIN] WinContinuePrompt absent — not a WIN ceremony path"); _done(5); return
		for _i in 10:
			await get_tree().process_frame
		await _shot("s101_chain_ch%02d_1_continue_prompt" % (chapter_idx + 1))
		print("[G30-CHAIN] stage 1 — banner + WinContinuePrompt up; battle.is_processing()=",
			battle.is_processing())

		# ── PHASE 1: real Enter → BattleScene._process poll → _begin_win_ceremony ─
		await _tap_enter()
		# Confirm the synthesized Enter actually drove the poll (ceremony started).
		var ceremony_started: bool = false
		for _i in 90:
			if hud.get_node_or_null("WinContinuePrompt") == null:
				ceremony_started = true
				break
			await get_tree().process_frame
		if not ceremony_started:
			push_error("[G30-CHAIN] synthesized Enter did NOT trigger the ceremony — "
				+ "phase-1 _process forward poll not driven (synth mechanism or arm gap). "
				+ "is_physical_key_pressed(ENTER)=%s" % Input.is_physical_key_pressed(KEY_ENTER))
			_done(6); return
		print("[G30-CHAIN] stage 2 — phase-1 Enter triggered ceremony (continue prompt gone)")

		# ── Drive the narrative screens with Enter taps until the chapter-complete
		#    buttons appear. Break the instant buttons mount so we probe the arm
		#    state BEFORE any further tap could transition away. ──────────────────
		var saw_narrative: bool = false
		var buttons_appeared: bool = false
		for _i in 80:
			var btns: Node = hud.get_node_or_null("PostBattleButtons")
			if btns != null:
				buttons_appeared = true
				break
			var beat: Node = hud.get_node_or_null("StoryBeatScreen")
			var conseq: Node = hud.get_node_or_null("ConsequenceScreen")
			if beat != null or conseq != null:
				saw_narrative = true
				await _tap_enter()
			else:
				await get_tree().process_frame
		if not buttons_appeared:
			push_error("[G30-CHAIN] chapter-complete PostBattleButtons never appeared "
				+ "(narrative seen=%s)" % saw_narrative)
			_done(7); return
		await _shot("s101_chain_ch%02d_2_chapter_complete" % (chapter_idx + 1))

		# ── ROOT-CAUSE PROBE — is the 2nd-phase Enter poll re-armed? ─────────────
		var processing: bool = battle.is_processing()
		var resolved: bool = bool(battle.get("_battle_resolved"))
		var ceremony_shown: bool = bool(battle.get("_win_ceremony_shown"))
		print("[G30-CHAIN] stage 3 — chapter-complete buttons up. PROBE: ",
			"is_processing()=%s _battle_resolved=%s _win_ceremony_shown=%s saw_narrative=%s"
			% [processing, resolved, ceremony_shown, saw_narrative])

		# Soft check: a fresh Enter tap should leave the battle scene (→ chapter
		# select). GUI-focus-path-dependent, so reported but NOT a hard gate.
		await _tap_enter()
		var transitioned: bool = false
		for _i in 40:
			if get_tree().current_scene != battle or not is_instance_valid(battle):
				transitioned = true
				break
			await get_tree().process_frame
		print("[G30-CHAIN] soft check — 2nd Enter transitioned away from battle: ", transitioned)

		# ── Verdict ─────────────────────────────────────────────────────────────
		if not processing:
			push_error("[G30-CHAIN] FAIL — BattleScene._process is OFF at the "
				+ "chapter-complete buttons. The 2nd-phase Enter poll cannot fire; "
				+ "keyboard Enter is dead on '챕터 선택으로 ▶ (Enter)'. "
				+ "_begin_win_ceremony re-arms _battle_resolved but not set_process(true).")
			_done(6); return
		if not resolved:
			push_error("[G30-CHAIN] FAIL — _battle_resolved is false at chapter-complete "
				+ "buttons (forward poll gated off).")
			_done(6); return
		print("[G30-CHAIN] PASS — ch%02d WIN chain: continue → narrative → chapter-complete "
			% (chapter_idx + 1)
			+ "buttons with the Enter poll re-armed (is_processing()=true). "
			+ "soft transition=%s" % transitioned)
		_done(0)

	# ── Input synthesis ─────────────────────────────────────────────────────────
	## Press-hold-release Enter through the real input pipeline so both the
	## BattleScene forward poll (Input.is_*_pressed, no edge) and the narrative
	## screens' edge-detected polls (need a release between presses) observe it.
	func _tap_enter() -> void:
		var down: InputEventKey = InputEventKey.new()
		down.keycode = KEY_ENTER
		down.physical_keycode = KEY_ENTER
		down.pressed = true
		Input.parse_input_event(down)
		Input.flush_buffered_events()
		for _i in 6:
			await get_tree().process_frame
		var up: InputEventKey = InputEventKey.new()
		up.keycode = KEY_ENTER
		up.physical_keycode = KEY_ENTER
		up.pressed = false
		Input.parse_input_event(up)
		Input.flush_buffered_events()
		for _i in 6:
			await get_tree().process_frame

	# ── Awaiters ────────────────────────────────────────────────────────────────
	## Waits for current_scene to expose `child`. CRUCIAL: dismisses any pre-battle
	## StoryBeatScreen each frame — in windowed runs _ready() gates _start_battle()
	## (and thus the GridBattleController build) behind the player advancing past
	## the Beat 1/3 pre-battle narrative. Without dismissing, the controller is
	## never built and this loop times out (the bug the first draft hit).
	func _await_current_scene_with(child: String, max_frames: int) -> Node:
		for _i in max_frames:
			var scene: Node = get_tree().current_scene
			if scene != null:
				var hud: Node = scene.get_node_or_null("HUDLayer")
				if hud != null:
					var beat: Node = hud.get_node_or_null("StoryBeatScreen")
					if beat != null and beat.has_method("advance"):
						beat.call("advance")
				if scene.get_node_or_null(child) != null:
					return scene
			await get_tree().process_frame
		return null

	func _await_hud_child(hud: Node, child: String, max_frames: int) -> bool:
		for _i in max_frames:
			if hud != null and is_instance_valid(hud) and hud.get_node_or_null(child) != null:
				return true
			await get_tree().process_frame
		return false

	func _shot(tag: String) -> void:
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		if img != null:
			img.save_png(SHOT_DIR + tag + ".png")
			print("[G30-CHAIN] screenshot -> ", SHOT_DIR + tag + ".png")

	func _done(code: int) -> void:
		print("[G30-CHAIN] DONE (exit ", code, ")")
		get_tree().quit(code)
