extends Node
## Auto-battle telemetry harness (S98) — closes the S95/S96 "windowed 실플레이
## telemetry" gap. The ttk_matrix.gd model is a static attrition LOWER BOUND
## (excludes terrain / facing-direction / counter / defend-stance / command_aura
## / items / AI imperfection / reachability). This harness runs the REAL battle
## to completion through the natural loop — TurnOrderRunner + production AISystem
## (enemies) + a greedy player auto-pilot (players) + real _handle_player_attack
## → DamageCalc → HPStatusController — and captures what ACTUALLY happens:
## per-hit damage, kills, rounds-to-resolve, final outcome, survivors per side.
##
## Player tactics = greedy melee auto-pilot (attack the in-range enemy it can
## kill / lowest-HP, else move toward nearest enemy, else WAIT). NO items / NO
## skills / NO formation strategy — so the result is a LOWER bound on real
## human play (a human does better) but an UPPER bound on the static model's
## realism (real terrain/direction/counter/defend are all live). The truth for
## a given chapter sits between this number and the model's.
##
## Run (headless, fast — identical telemetry, no render/tweens):
##   godot --headless --path . res://tools/ci/balance/g30_autobattle_telemetry.tscn -- <chapter_idx>
## Run (windowed, slower — adds render + slide tweens):
##   godot --path . res://tools/ci/balance/g30_autobattle_telemetry.tscn -- <chapter_idx>
## chapter_idx is 0-based (0=ch01 … 10=ch11 … 15=ch16).

const SHU_PATH: String = "res://assets/data/scenarios/shu_canon_main.json"

var _chapter_idx: int = 0
var _battle: Node = null
var _controller: Node = null
var _turn_runner: Node = null
var _hp: Node = null

var _resolved: bool = false
var _outcome: StringName = &""
var _max_round: int = 1
var _frames: int = 0

# telemetry accumulators
var _dmg_by_side: Dictionary = {0: 0, 1: 0}   # damage DEALT by side
var _hits_by_side: Dictionary = {0: 0, 1: 0}
var _kills_by_side: Dictionary = {0: 0, 1: 0}  # kills CREDITED to side
var _acted_log: int = 0
# auto-pilot action breakdown (diagnostic)
var _ap_attack: int = 0
var _ap_move_attack: int = 0
var _ap_move_only: int = 0
var _ap_wait: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.is_valid_int():
			_chapter_idx = a.to_int()
	print("[TELE] ===== auto-battle telemetry — chapter_idx=", _chapter_idx, " =====")
	get_tree().create_timer(240.0).timeout.connect(func() -> void:
		push_error("[TELE] FAILSAFE TIMEOUT (240s) — battle did not resolve (frames=%d round=%d)" % [_frames, _max_round])
		_report()
		get_tree().quit(8))
	_run.call_deferred()


func _run() -> void:
	var runner: Node = get_node_or_null("/root/ScenarioRunner")
	runner.call("reset_for_tests")
	runner.call("set_active_scenario_path", SHU_PATH)
	runner.call("dev_jump_to_chapter", SHU_PATH, _chapter_idx)

	var bs: PackedScene = load("res://scenes/battle/battle_scene.tscn") as PackedScene
	_battle = bs.instantiate()
	get_tree().root.add_child(_battle)
	await _dismiss_story_beats(_battle)

	_controller = await _await_node(_battle, "GridBattleController", 240)
	if _controller == null:
		push_error("[TELE] controller never appeared"); _report(); get_tree().quit(4); return
	_turn_runner = _controller.get("_turn_runner")
	_hp = _controller.get("_hp_controller")
	# Zero the AI thinking pause so the loop runs at frame speed.
	if _controller.has_method("set_ai_thinking_pause_sec_for_test"):
		_controller.call("set_ai_thinking_pause_sec_for_test", 0.0)

	# Telemetry subscriptions.
	if _controller.has_signal("damage_applied"):
		_controller.connect("damage_applied", _on_damage)
	if _controller.has_signal("unit_killed"):
		_controller.connect("unit_killed", _on_killed)
	if _controller.has_signal("round_started_visual"):
		_controller.connect("round_started_visual", _on_round)
	if _controller.has_signal("battle_outcome_resolved"):
		_controller.connect("battle_outcome_resolved", _on_outcome)

	# Let the first turn become active before driving.
	for _i in 8:
		await get_tree().process_frame
	set_process(true)


func _process(_delta: float) -> void:
	if _resolved:
		return
	_frames += 1
	if _controller == null:
		return
	var active: int = int(_controller.call("get_active_turn_unit_id"))
	if active < 0:
		return
	var units: Dictionary = _controller.get("_units")
	if not units.has(active):
		return
	var u: Object = units[active]
	if int(u.get("side")) != 0:
		return  # enemy turn — AISystem drives it; we wait.
	if _controller.get("_acted_this_turn").get(active, false):
		return  # already acted this turn — waiting for the loop to advance.
	_autopilot(active, u, units)


# Greedy melee auto-pilot for one player unit on its active turn.
func _autopilot(uid: int, unit: Object, units: Dictionary) -> void:
	_acted_log += 1
	# 1. Any enemy already in attack range? Attack the best target.
	var target: int = _best_attack_target(uid, units)
	if target != -1:
		_ap_attack += 1
		_controller.call("_handle_player_attack", uid, target)
		return
	# 2. Move toward the nearest enemy, then re-check attack range.
	var nearest: int = _nearest_enemy(unit, units)
	if nearest != -1:
		var dest: Vector2i = _best_move_tile(uid, unit, units[nearest])
		if dest != (unit.get("position") as Vector2i):
			_controller.call("_handle_player_move", unit, dest)
			var t2: int = _best_attack_target(uid, units)
			if t2 != -1:
				_ap_move_attack += 1
				_controller.call("_handle_player_attack", uid, t2)
				return
			_ap_move_only += 1
			_controller.get("_acted_this_turn")[uid] = true
			_turn_runner.call("declare_action", uid, TurnOrderRunner.ActionType.WAIT, null)
			return
	# 3. Nothing productive — end the turn (declare WAIT so the loop advances).
	_ap_wait += 1
	_controller.get("_acted_this_turn")[uid] = true
	_turn_runner.call("declare_action", uid, TurnOrderRunner.ActionType.WAIT, null)


# Best in-range enemy: prefer a kill (preview damage >= current HP), else lowest HP.
func _best_attack_target(uid: int, units: Dictionary) -> int:
	var best: int = -1
	var best_score: float = -1.0
	for eid_v: Variant in units:
		var e: Object = units[eid_v]
		if int(e.get("side")) == 0:
			continue
		var eid: int = int(eid_v)
		if not _hp.call("is_alive", eid):
			continue
		if not bool(_controller.call("is_tile_in_attack_range", e.get("position"), uid)):
			continue
		var prev: Dictionary = _controller.call("preview_attack", uid, eid)
		var dmg: float = float(prev.get("final_damage", 0))
		var hp: int = int(_hp.call("get_current_hp", eid))
		# kill bonus (1000) + damage; ties broken toward lower HP target.
		var score: float = dmg + (1000.0 if dmg >= float(hp) else 0.0) + (100.0 - float(hp)) * 0.01
		if score > best_score:
			best_score = score
			best = eid
	return best


func _nearest_enemy(unit: Object, units: Dictionary) -> int:
	var pos: Vector2i = unit.get("position") as Vector2i
	var best: int = -1
	var best_d: int = 1 << 30
	for eid_v: Variant in units:
		var e: Object = units[eid_v]
		if int(e.get("side")) == 0:
			continue
		if not _hp.call("is_alive", int(eid_v)):
			continue
		var ep: Vector2i = e.get("position") as Vector2i
		var d: int = absi(ep.x - pos.x) + absi(ep.y - pos.y)
		if d < best_d:
			best_d = d
			best = int(eid_v)
	return best


# Pick the reachable tile that minimises Manhattan distance to the target enemy.
func _best_move_tile(uid: int, unit: Object, enemy: Object) -> Vector2i:
	var ep: Vector2i = enemy.get("position") as Vector2i
	var cur: Vector2i = unit.get("position") as Vector2i
	var tiles: PackedVector2Array = _controller.call("get_movable_tiles", uid)
	var best: Vector2i = cur
	var best_d: int = absi(ep.x - cur.x) + absi(ep.y - cur.y)
	for t: Vector2 in tiles:
		var ti: Vector2i = Vector2i(int(t.x), int(t.y))
		var d: int = absi(ep.x - ti.x) + absi(ep.y - ti.y)
		if d < best_d:
			best_d = d
			best = ti
	return best


func _on_damage(attacker_id: int, _defender_id: int, damage: int) -> void:
	var units: Dictionary = _controller.get("_units")
	if units.has(attacker_id):
		var side: int = int(units[attacker_id].get("side"))
		_dmg_by_side[side] = (_dmg_by_side[side] as int) + damage
		_hits_by_side[side] = (_hits_by_side[side] as int) + 1


func _on_killed(killer_id: int, _victim_id: int, _victim_hero: StringName) -> void:
	var units: Dictionary = _controller.get("_units")
	if units.has(killer_id):
		var side: int = int(units[killer_id].get("side"))
		_kills_by_side[side] = (_kills_by_side[side] as int) + 1


func _on_round(round_number: int) -> void:
	_max_round = maxi(_max_round, round_number)


func _on_outcome(outcome: StringName, _fate_data: Dictionary) -> void:
	if _resolved:
		return
	_resolved = true
	_outcome = outcome
	set_process(false)
	_report()
	get_tree().quit(0)


func _alive_counts() -> Array:
	var p: int = 0
	var e: int = 0
	var units: Dictionary = _controller.get("_units")
	for uid_v: Variant in units:
		if _hp != null and _hp.call("is_alive", int(uid_v)):
			if int(units[uid_v].get("side")) == 0:
				p += 1
			else:
				e += 1
	return [p, e]


func _report() -> void:
	var ac: Array = _alive_counts()
	print("[TELE] ------------------------------------------------------------")
	print("[TELE] chapter_idx=%d  OUTCOME=%s  rounds=%d  frames=%d  player_turns_driven=%d"
		% [_chapter_idx, _outcome, _max_round, _frames, _acted_log])
	print("[TELE] survivors: players=%d  enemies=%d" % [ac[0], ac[1]])
	print("[TELE] damage dealt: player=%d (%d hits)  enemy=%d (%d hits)"
		% [_dmg_by_side[0], _hits_by_side[0], _dmg_by_side[1], _hits_by_side[1]])
	print("[TELE] kills: player=%d  enemy=%d" % [_kills_by_side[0], _kills_by_side[1]])
	print("[TELE] autopilot actions: attack=%d move+attack=%d move-only=%d wait=%d"
		% [_ap_attack, _ap_move_attack, _ap_move_only, _ap_wait])
	print("[TELE] ------------------------------------------------------------")


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
