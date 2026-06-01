extends Node
## G-30 windowed smoke — S99 per-chapter turn_budget wiring verification.
##
## Headless tests assert (a) the scenario JSON carries turn_budget for the
## big-map ANNIHILATION chapters + the post-MVP SURVIVE fixes, and (b) the
## controller's set_victory_conditions() overrides _max_turns. But per G-30 a
## headless PASS does NOT gate the windowed lifecycle: the actual
## ScenarioRunner hydrate → battle_scene.set_victory_conditions(chapter.
## victory_conditions) → controller._max_turns path is only exercised when the
## scene boots for real. This harness boots windowed, dev-jumps to a chapter,
## lets the real battle build, then asserts controller._max_turns equals the
## authored per-chapter budget (and the global default 5 for a control chapter).
##
## Run:  godot --path . res://tools/ci/g30/g30_turn_budget_smoke.tscn -- <chapter_idx>
##   chapter_idx is 0-based: 0=ch01 (control, expect 5), 8=ch09, 10=ch11,
##   11=ch12, 13=ch14 (all expect 6).
## Exit 0 = budget verified ; non-zero = failure (see _finish codes).

const SHU_PATH: String = "res://assets/data/scenarios/shu_canon_main.json"
const SHOT_DIR: String = "/tmp/g30/"

# Expected windowed _max_turns per 0-based chapter index (S99 equalization).
const EXPECTED_BUDGET: Dictionary = {
	0: 5,    # ch01 — small map, apprRnd 1 → keeps the global default (control)
	8: 6,    # ch09 — 16-wide, apprRnd 2 → window 4
	10: 6,   # ch11 — gap 9, apprRnd 2
	11: 6,   # ch12 — gap 9, apprRnd 2
	13: 6,   # ch14 — gap 10, apprRnd 2
}

var _battle: Node = null
var _chapter_idx: int = 10


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.is_valid_int():
			_chapter_idx = a.to_int()
	print("[G30] ===== S99 turn_budget windowed smoke (chapter_idx=", _chapter_idx, ") =====")
	var failsafe: SceneTreeTimer = get_tree().create_timer(30.0)
	failsafe.timeout.connect(func() -> void:
		push_error("[G30] FAILSAFE TIMEOUT (30s) — quitting")
		_finish(9))
	# Defer so the SceneTree finishes setting up before we add_child under /root.
	_run.call_deferred()


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(SHOT_DIR)
	if not EXPECTED_BUDGET.has(_chapter_idx):
		push_error("[G30] chapter_idx %d not in S99 EXPECTED_BUDGET (use 0/8/10/11/13)" % _chapter_idx)
		_finish(1); return
	var want_budget: int = EXPECTED_BUDGET[_chapter_idx] as int

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

	# ── 3. Wait for GridBattleController ─────────────────────────────────────
	var controller: Node = await _await_node(_battle, "GridBattleController", 240)
	if controller == null:
		push_error("[G30] GridBattleController never appeared (battle build failed?)")
		await _shot("00_no_controller"); _finish(4); return
	# Let the battle settle (set_victory_conditions is called during build).
	for _i in 12:
		await get_tree().process_frame

	await _shot("s99_ch%02d_turn_budget" % (_chapter_idx + 1))

	# ── 4. Assertion — windowed _max_turns equals the authored budget ────────
	var got_budget: int = int(controller.get("_max_turns"))
	print("[G30] ch%02d windowed controller._max_turns = %d (expected %d)"
		% [_chapter_idx + 1, got_budget, want_budget])
	if got_budget != want_budget:
		push_error("[G30] FAIL: ch%02d _max_turns %d != expected %d — per-chapter turn_budget "
			% [_chapter_idx + 1, got_budget, want_budget]
			+ "did NOT flow scenario → battle_scene → controller in windowed mode")
		_finish(6); return

	print("[G30] PASS — ch%02d windowed _max_turns = %d (S99 per-chapter budget wired)."
		% [_chapter_idx + 1, got_budget])
	_finish(0)


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
