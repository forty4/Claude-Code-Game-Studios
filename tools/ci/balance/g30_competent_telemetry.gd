extends Node
## Competent auto-pilot telemetry harness (S100) — TIERED ABLATION.
##
## Closes the S95/S96/S98/S99 gold-standard residual: S98's naive-melee pilot is
## the PESSIMISTIC floor (draws/loses every DEFEAT_ALL), ttk_matrix is the
## OPTIMISTIC ceiling; neither tells us whether the S99 per-chapter turn budgets
## actually let a SKILLED player win in time. This harness runs the REAL battle
## (TurnOrderRunner + production AISystem + DamageCalc) with a tiered player
## auto-pilot so we can attribute WHICH strategy element flips DRAW → WIN:
##
##   tier 0  naive            — S98 exact: in-range attack (preview dmg + kill
##                              bonus) / move Manhattan-toward-nearest / WAIT.
##   tier 1  +flank           — movement picks the reachable tile that yields the
##                              best attack ANGLE (rear 1.50× / side 1.25× /
##                              front 1.0×), replicating _attack_angle geometry.
##   tier 2  +skill           — fire the one-shot skill when engaged (offensive
##                              skills self-declare; utility skills chain).
##   tier 3  +item            — action-items (fire_scroll AoE / heal / aid) before
##                              attacking when high-value; buff-items
##                              (strength 1.5× / rally 1.3× / intimidate 0.7× /
##                              march) invested on approach (move-only) turns.
##
## HONESTY: a heuristic bot is NOT a skilled human — it is still a LOWER bound on
## true human play, just a much tighter one than tier 0. The truth for a chapter
## sits between the highest tier here and the model's optimistic floor.
##
## ── S100 RESULT (budget-6 S99 chapters, 5 enemies each; enemies-left at limit) ──
##   chapter | t0 naive | t1 +flank | t2 +skill | t3 +item
##   ch09    |   E4     |   E2      |   E2      |   E1
##   ch11    |   E4     |   E3      |   E3      |   E1
##   ch14    |   E4     |   E3      |   E3      |   WIN
## Findings: (1) the strategy layer is mechanically load-bearing + MONOTONE —
##   flank (Pillar #1) is the first lever (E4→E2/E3), ITEMS (Pillar #5) the
##   decisive one (→E1 / ch14 WIN); skills added 0 kills here (bot fires one-shots
##   sub-optimally / utility-heavy kits). (2) S99 budgets are TIGHT BUT FAIR — the
##   sub-human bot lands 0-1 enemies short; a skilled human closes that last gap.
##   (3) bracket fully tightened: S98 naive floor (DRAW E4) → competent (DRAW E1 /
##   occasional WIN) → human ceiling (WIN). Validates S99 — no balance change.
##   Caveats: flank tier occasionally net-NEGATIVE (lone-unit over-extension w/o
##   focus-fire support — ch03 → LOSS); early budget-5 chapters draw E2 even at t3
##   (small rosters + low atk_mult + sub-human bot, not a budget-5 fault).
##
## Run (headless, fast):
##   godot --headless --path . res://tools/ci/balance/g30_competent_telemetry.tscn -- <chapter_idx> <tier>
## chapter_idx 0-based (0=ch01 … 10=ch11 … 15=ch16); tier 0-3 (default 3).

const SHU_PATH: String = "res://assets/data/scenarios/shu_canon_main.json"

# Angle multipliers — mirror grid_battle_controller._compute_angle_mult.
const ANGLE_REAR: float = 1.50
const ANGLE_REAR_SPECIALIST: float = 1.75
const ANGLE_SIDE: float = 1.25
const ANGLE_FRONT: float = 1.00

var _chapter_idx: int = 10
var _tier: int = 3
var _battle: Node = null
var _controller: Node = null
var _turn_runner: Node = null
var _hp: Node = null

var _resolved: bool = false
var _outcome: StringName = &""
var _max_round: int = 1
var _frames: int = 0

var _dmg_by_side: Dictionary = {0: 0, 1: 0}
var _hits_by_side: Dictionary = {0: 0, 1: 0}
var _kills_by_side: Dictionary = {0: 0, 1: 0}
var _acted_log: int = 0
var _ap_attack: int = 0
var _ap_move_attack: int = 0
var _ap_move_only: int = 0
var _ap_wait: int = 0
var _ap_skill: int = 0
var _ap_item: int = 0


func _ready() -> void:
	var ints: Array[int] = []
	for a: String in OS.get_cmdline_user_args():
		if a.is_valid_int():
			ints.append(a.to_int())
	if ints.size() >= 1:
		_chapter_idx = ints[0]
	if ints.size() >= 2:
		_tier = clampi(ints[1], 0, 3)
	print("[TELE] ===== competent telemetry — chapter_idx=", _chapter_idx, " tier=", _tier, " =====")
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
	if _controller.has_method("set_ai_thinking_pause_sec_for_test"):
		_controller.call("set_ai_thinking_pause_sec_for_test", 0.0)

	if _controller.has_signal("damage_applied"):
		_controller.connect("damage_applied", _on_damage)
	if _controller.has_signal("unit_killed"):
		_controller.connect("unit_killed", _on_killed)
	if _controller.has_signal("round_started_visual"):
		_controller.connect("round_started_visual", _on_round)
	if _controller.has_signal("battle_outcome_resolved"):
		_controller.connect("battle_outcome_resolved", _on_outcome)

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
		return  # enemy turn — AISystem drives it.
	if _controller.get("_acted_this_turn").get(active, false):
		return
	_autopilot(active, u, units)


# ── Tiered competent auto-pilot for one player unit on its active turn. ────────
func _autopilot(uid: int, unit: Object, units: Dictionary) -> void:
	_acted_log += 1

	# TIER 2+: one-shot skill when engaged (offensive self-declares → turn ends;
	# utility skills don't spend the token → fall through to attack/move).
	if _tier >= 2 and bool(_controller.call("can_use_skill", uid)) and _engaged(unit, units):
		var fired: bool = bool(_controller.call("use_skill", uid))
		if fired:
			_ap_skill += 1
			if _acted(uid):
				return  # offensive skill consumed the turn

	# TIER 3: high-value ACTION item (AoE / sustain) before attacking.
	if _tier >= 3 and not _acted(uid) and _try_action_item(uid, unit, units):
		_ap_item += 1
		return

	# Attack an in-range enemy (best previewed damage + kill bonus).
	var target: int = _best_attack_target(uid, units)
	if target != -1:
		_ap_attack += 1
		_controller.call("_handle_player_attack", uid, target)
		return

	# Move toward the best position (flank-aware at tier>=1), then re-check.
	var nearest: int = _nearest_enemy(unit, units)
	if nearest != -1:
		var dest: Vector2i = _best_move_tile(uid, unit, units)
		if dest != (unit.get("position") as Vector2i):
			_controller.call("_handle_player_move", unit, dest)
			var t2: int = _best_attack_target(uid, units)
			if t2 != -1:
				_ap_move_attack += 1
				_controller.call("_handle_player_attack", uid, t2)
				return
			# Moved but still not in range → TIER 3: invest the turn in a buff.
			if _tier >= 3 and not _acted(uid) and _try_buff_item(uid, unit, units):
				_ap_item += 1
				return
			_ap_move_only += 1
			_end_turn_wait(uid)
			return

	# Nothing productive — TIER 3 buff investment, else WAIT.
	if _tier >= 3 and not _acted(uid) and _try_buff_item(uid, unit, units):
		_ap_item += 1
		return
	_ap_wait += 1
	_end_turn_wait(uid)


func _acted(uid: int) -> bool:
	return bool(_controller.get("_acted_this_turn").get(uid, false))


func _end_turn_wait(uid: int) -> void:
	_controller.get("_acted_this_turn")[uid] = true
	_turn_runner.call("declare_action", uid, TurnOrderRunner.ActionType.WAIT, null)


# ── Engagement test: any live enemy within (attack_range + 2) Manhattan. ──────
func _engaged(unit: Object, units: Dictionary) -> bool:
	var pos: Vector2i = unit.get("position") as Vector2i
	var reach: int = int(unit.get("attack_range")) + 2
	for eid_v: Variant in units:
		var e: Object = units[eid_v]
		if int(e.get("side")) == 0:
			continue
		if not _hp.call("is_alive", int(eid_v)):
			continue
		var ep: Vector2i = e.get("position") as Vector2i
		if absi(ep.x - pos.x) + absi(ep.y - pos.y) <= reach:
			return true
	return false


# ── Best in-range target: prefer kill, then highest previewed damage. ─────────
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


# ── Tier-aware move-tile selection. ───────────────────────────────────────────
# tier 0: Manhattan-min toward nearest enemy (S98).
# tier 1+: among reachable tiles, prefer the one giving the best attack ANGLE
#          against a now-in-range enemy (rear > side > front); fall back to
#          Manhattan-approach when no tile yields an in-range attack.
func _best_move_tile(uid: int, unit: Object, units: Dictionary) -> Vector2i:
	var cur: Vector2i = unit.get("position") as Vector2i
	var tiles: PackedVector2Array = _controller.call("get_movable_tiles", uid)
	var nearest: int = _nearest_enemy(unit, units)
	if nearest == -1:
		return cur
	var enemy: Object = units[nearest]
	var ep: Vector2i = enemy.get("position") as Vector2i
	var atk_range: int = int(unit.get("attack_range"))
	var rear_spec: bool = (unit.get("passive") as StringName) == &"rear_specialist"

	if _tier == 0:
		# Manhattan-min toward nearest enemy.
		var best0: Vector2i = cur
		var best_d0: int = absi(ep.x - cur.x) + absi(ep.y - cur.y)
		for t: Vector2 in tiles:
			var ti: Vector2i = Vector2i(int(t.x), int(t.y))
			var d: int = absi(ep.x - ti.x) + absi(ep.y - ti.y)
			if d < best_d0:
				best_d0 = d
				best0 = ti
		return best0

	# tier >= 1: flank-aware. Score each reachable tile that can attack SOME
	# enemy from there by the best attack angle_mult; prefer rear positions.
	var best: Vector2i = cur
	var best_angle: float = -1.0
	for t: Vector2 in tiles:
		var ti: Vector2i = Vector2i(int(t.x), int(t.y))
		var tile_best_angle: float = -1.0
		for eid_v: Variant in units:
			var e: Object = units[eid_v]
			if int(e.get("side")) == 0 or not _hp.call("is_alive", int(eid_v)):
				continue
			var epos: Vector2i = e.get("position") as Vector2i
			if absi(epos.x - ti.x) + absi(epos.y - ti.y) > atk_range:
				continue  # not in attack range from this tile
			var am: float = _angle_mult_at(ti, e, rear_spec)
			tile_best_angle = maxf(tile_best_angle, am)
		if tile_best_angle > best_angle:
			best_angle = tile_best_angle
			best = ti
	if best_angle > 0.0:
		return best  # found a tile that can attack — best flank among them
	# No reachable tile reaches an enemy → pure Manhattan-approach (tier 0 path).
	var bestm: Vector2i = cur
	var best_dm: int = absi(ep.x - cur.x) + absi(ep.y - cur.y)
	for t2: Vector2 in tiles:
		var ti2: Vector2i = Vector2i(int(t2.x), int(t2.y))
		var d2: int = absi(ep.x - ti2.x) + absi(ep.y - ti2.y)
		if d2 < best_dm:
			best_dm = d2
			bestm = ti2
	return bestm


# Replicates grid_battle_controller._attack_angle + _compute_angle_mult for a
# hypothetical attacker tile (pure geometry, no mutation).
func _angle_mult_at(attacker_tile: Vector2i, defender: Object, rear_specialist: bool) -> float:
	var dpos: Vector2i = defender.get("position") as Vector2i
	var facing: int = int(defender.get("facing"))
	var attacker_dir: int = _dir(dpos, attacker_tile)
	if attacker_dir == facing:
		return ANGLE_FRONT
	if attacker_dir == (facing + 2) % 4:
		return ANGLE_REAR_SPECIALIST if rear_specialist else ANGLE_REAR
	return ANGLE_SIDE


# Mirrors grid_battle_controller._direction_from_to. 0=N 1=E 2=S 3=W.
func _dir(from: Vector2i, to: Vector2i) -> int:
	var dx: int = to.x - from.x
	var dy: int = to.y - from.y
	if absi(dx) >= absi(dy):
		return 1 if dx > 0 else 3
	return 2 if dy > 0 else 0


# ── Skill heuristic — whether to fire the one-shot now. ───────────────────────
func _should_use_skill(_uid: int, _unit: Object, _units: Dictionary) -> bool:
	return true  # gated by _engaged() at the call site


# ── TIER 3 action items (used as the turn's primary action). ──────────────────
func _try_action_item(uid: int, unit: Object, units: Dictionary) -> bool:
	# 1. Self-sustain: heal when below half HP.
	if _hp_ratio(uid) < 0.5 and _has_item(unit, &"heal_potion"):
		if _use_self_item(uid, unit, &"heal_potion"):
			return true
	# 2. Ally sustain: aid a low ally in item range.
	if _has_item(unit, &"aid_potion"):
		var ally: int = _best_target_unit(uid, &"aid_potion", true, func(t: Object) -> float:
			return (1.0 - _hp_ratio(int(t.get("unit_id")))) if _hp_ratio(int(t.get("unit_id"))) < 0.6 else -1.0)
		if ally != -1 and _use_targeted_item(uid, unit, &"aid_potion", units[ally].get("position")):
			return true
	# 3. Offensive AoE: fire_scroll on the densest enemy cluster (>=2).
	if _has_item(unit, &"fire_scroll"):
		var center: Variant = _best_fire_target(uid)
		if center != null and _use_targeted_item(uid, unit, &"fire_scroll", center):
			return true
	return false


# ── TIER 3 buff items (invested on approach / move-only turns). ───────────────
func _try_buff_item(uid: int, unit: Object, units: Dictionary) -> bool:
	# strength_scroll (self, ×1.50 next attacks) — highest priority offense buff.
	if _has_item(unit, &"strength_scroll") and _use_self_item(uid, unit, &"strength_scroll"):
		return true
	# march_scroll (self, +move) — closes the approach-distance gap.
	if _has_item(unit, &"march_scroll") and _use_self_item(uid, unit, &"march_scroll"):
		return true
	# rally_scroll (ally, ×1.30) — buff an engaged ally.
	if _has_item(unit, &"rally_scroll"):
		var ally: int = _best_target_unit(uid, &"rally_scroll", true, func(t: Object) -> float:
			return 1.0 if _engaged(t, units) else 0.5)
		if ally != -1 and _use_targeted_item(uid, unit, &"rally_scroll", units[ally].get("position")):
			return true
	# intimidate_scroll (enemy, ×0.70) — debuff the nearest threat in range.
	if _has_item(unit, &"intimidate_scroll"):
		var enemy: int = _best_target_unit(uid, &"intimidate_scroll", false, func(t: Object) -> float:
			var ep: Vector2i = t.get("position") as Vector2i
			var p: Vector2i = unit.get("position") as Vector2i
			return 100.0 - float(absi(ep.x - p.x) + absi(ep.y - p.y)))
		if enemy != -1 and _use_targeted_item(uid, unit, &"intimidate_scroll", units[enemy].get("position")):
			return true
	return false


# Pick the fire_scroll target tile maximising enemies within AoE radius 1; null
# if no tile catches >= 2 enemies (not worth the action).
func _best_fire_target(uid: int) -> Variant:
	var tiles: PackedVector2Array = _controller.call("get_item_target_tiles", uid, &"fire_scroll")
	var units: Dictionary = _controller.get("_units")
	var best_tile: Variant = null
	var best_count: int = 1  # require >= 2 to fire
	for t: Vector2 in tiles:
		var ti: Vector2i = Vector2i(int(t.x), int(t.y))
		var count: int = 0
		for eid_v: Variant in units:
			var e: Object = units[eid_v]
			if int(e.get("side")) == 0 or not _hp.call("is_alive", int(eid_v)):
				continue
			var ep: Vector2i = e.get("position") as Vector2i
			if absi(ep.x - ti.x) + absi(ep.y - ti.y) <= 1:
				count += 1
		if count > best_count:
			best_count = count
			best_tile = ti
	return best_tile


# Among the item's valid target tiles, return the unit_id (ally/enemy per
# want_ally) maximising the scorer; -1 if none scores positive.
func _best_target_unit(uid: int, item_id: StringName, want_ally: bool, scorer: Callable) -> int:
	var tiles: PackedVector2Array = _controller.call("get_item_target_tiles", uid, item_id)
	var units: Dictionary = _controller.get("_units")
	var tileset: Dictionary = {}
	for t: Vector2 in tiles:
		tileset[Vector2i(int(t.x), int(t.y))] = true
	var best: int = -1
	var best_score: float = 0.0
	for u_v: Variant in units:
		var u: Object = units[u_v]
		var is_ally: bool = int(u.get("side")) == 0
		if is_ally != want_ally:
			continue
		if int(u_v) == uid and want_ally:
			pass  # rally/aid may target self too in some kits — allow
		if not _hp.call("is_alive", int(u_v)):
			continue
		if not tileset.has(u.get("position") as Vector2i):
			continue
		var s: float = scorer.call(u)
		if s > best_score:
			best_score = s
			best = int(u_v)
	return best


func _hp_ratio(uid: int) -> float:
	var cur: float = float(_hp.call("get_current_hp", uid))
	var mx: float = float(_hp.call("get_max_hp", uid)) if _hp.has_method("get_max_hp") else cur
	return cur / mx if mx > 0.0 else 1.0


func _has_item(unit: Object, item_id: StringName) -> bool:
	return _find_slot(unit, item_id) != -1


func _find_slot(unit: Object, item_id: StringName) -> int:
	var inv: Array = unit.get("inventory")
	for i: int in inv.size():
		if StringName(inv[i]) == item_id:
			return i
	return -1


func _use_self_item(uid: int, unit: Object, item_id: StringName) -> bool:
	var slot: int = _find_slot(unit, item_id)
	if slot == -1:
		return false
	return bool(_controller.call("use_item", uid, slot, Vector2i(-1, -1)))


func _use_targeted_item(uid: int, unit: Object, item_id: StringName, target_pos: Vector2i) -> bool:
	var slot: int = _find_slot(unit, item_id)
	if slot == -1:
		return false
	return bool(_controller.call("use_item", uid, slot, target_pos))


# ── Telemetry ─────────────────────────────────────────────────────────────────
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
	print("[TELE] chapter_idx=%d  tier=%d  OUTCOME=%s  rounds=%d  player_turns=%d"
		% [_chapter_idx, _tier, _outcome, _max_round, _acted_log])
	print("[TELE] survivors: players=%d  enemies=%d" % [ac[0], ac[1]])
	print("[TELE] damage dealt: player=%d (%d hits)  enemy=%d (%d hits)"
		% [_dmg_by_side[0], _hits_by_side[0], _dmg_by_side[1], _hits_by_side[1]])
	print("[TELE] kills: player=%d  enemy=%d" % [_kills_by_side[0], _kills_by_side[1]])
	print("[TELE] autopilot: attack=%d move+attack=%d skill=%d item=%d move-only=%d wait=%d"
		% [_ap_attack, _ap_move_attack, _ap_skill, _ap_item, _ap_move_only, _ap_wait])
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
