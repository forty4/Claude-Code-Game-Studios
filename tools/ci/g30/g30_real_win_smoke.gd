extends Node
## Faithful real-flow win repro (S102 debug). Unlike g30_chapter_end_smoke (which
## add_child's the battle scene under a harness root), this reproduces the ACTUAL
## main_menu path: seed the scenario, then change_scene_to_file(battle_scene) so
## the battle is the real current_scene (BattleCamera becomes current, full
## render). A persistent /root watcher (survives the scene swap) force-wins and
## screenshots the real win moment — to see exactly what the player sees.
##
## Run:  godot --path . res://tools/ci/g30/g30_real_win_smoke.tscn

const SHU_PATH: String = "res://assets/data/scenarios/shu_canon_main.json"
const BATTLE_PATH: String = "res://scenes/battle/battle_scene.tscn"


func _ready() -> void:
	var runner: Node = get_node_or_null("/root/ScenarioRunner")
	runner.call("reset_for_tests")
	runner.call("set_active_scenario_path", SHU_PATH)
	runner.call("jump_to_chapter", SHU_PATH, 0)  # ch01, exactly like chapter_select
	# Persistent watcher mounted on /root survives the change_scene swap below.
	var w: Watcher = Watcher.new()
	w.name = "RealWinWatcher"
	get_tree().root.add_child.call_deferred(w)
	get_tree().change_scene_to_file.call_deferred(BATTLE_PATH)


class Watcher extends Node:
	const SHOT_DIR: String = "/tmp/g30/"
	var _phase: int = 0
	var _frames: int = 0
	var _won: bool = false

	func _ready() -> void:
		DirAccess.make_dir_recursive_absolute(SHOT_DIR)
		get_tree().create_timer(45.0).timeout.connect(func() -> void:
			push_error("[REAL] FAILSAFE TIMEOUT"); get_tree().quit(9))
		set_process(true)

	func _process(_dt: float) -> void:
		_frames += 1
		var scene: Node = get_tree().current_scene
		if scene == null:
			return
		var controller: Node = scene.get_node_or_null("GridBattleController")
		# Dismiss the pre-battle StoryBeatScreen so the battle actually starts.
		var hud: Node = scene.get_node_or_null("HUDLayer")
		if hud != null:
			var beat: Node = hud.get_node_or_null("StoryBeatScreen")
			if beat != null and beat.has_method("advance"):
				beat.call("advance")
		if controller == null:
			return
		# Let the battle settle, then force-win once.
		if not _won:
			if _frames < 90:
				return
			var hp: Node = controller.get("_hp_controller")
			var units: Dictionary = controller.get("_units")
			var n: int = 0
			for uid_v: Variant in units:
				var u: Object = units[uid_v]
				if int(u.get("side")) != 0 and hp.call("is_alive", int(uid_v)):
					hp.call("apply_damage", int(uid_v), 99999, 0, [])
					n += 1
			print("[REAL] force-killed %d enemies (frame %d)" % [n, _frames])
			_won = true
			_phase = _frames
			return
		# Post-win: screenshot at +20 and +70 frames to capture the moment.
		var since: int = _frames - _phase
		if since == 20:
			await _report_and_shot(scene, "s102_real_win_early")
		elif since == 70:
			await _report_and_shot(scene, "s102_real_win_late")
			get_tree().quit(0)

	func _report_and_shot(scene: Node, tag: String) -> void:
		var hud: Node = scene.get_node_or_null("HUDLayer")
		var nodes: Array[String] = []
		if hud != null:
			for c: Node in hud.get_children():
				nodes.append(c.name)
		# /root ChapterVisuals (field + unit polygons) presence.
		var has_cv: bool = false
		for c: Node in get_tree().root.get_children():
			if (c.get_class() == "Node2D" or c is Node2D) and ("ChapterVisuals" in c.name or c.get("_is_chapter_visuals") != null):
				has_cv = true
		print("[REAL] %s — current_scene=%s HUD children=%s chapterVisualsAtRoot=%s"
			% [tag, scene.name, nodes, has_cv])
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		if img != null:
			img.save_png(SHOT_DIR + tag + ".png")
			print("[REAL] screenshot -> ", SHOT_DIR + tag + ".png")
