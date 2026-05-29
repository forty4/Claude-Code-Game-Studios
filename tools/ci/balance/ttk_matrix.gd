# Balance verification harness (S95) — telemetry over reasoning.
# Computes damage / TTK using the REAL production DamageCalc.resolve + real
# hero stats (HeroDatabase) + real HP formula (UnitRole.get_max_hp) +
# real raw_atk/raw_def derivation (mirrors battle_scene._make_battle_unit).
#
# Goal: verify raw-feedback #1 ("난이도 너무 낮음") — is enemy_atk_mult 1.50
# producing an appropriate difficulty curve, or has it overshot?
#
# Run: godot --headless --path . -s res://tools/ci/balance/ttk_matrix.gd
extends SceneTree

const SCENARIO_PATH: String = "res://assets/data/scenarios/shu_canon_main.json"
const CLASS_ABBR: Array[String] = ["CAV", "INF", "ARC", "STR", "CMD", "SCT"]
const COMMANDER_CLASS: int = 4
const DIRECTIONS: Array[StringName] = [&"FRONT", &"FLANK", &"REAR"]

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _atk_coeff: float = 1.0
var _def_coeff: float = 0.20
var _cmd_def_bonus: int = 18

# Proposed S95 difficulty ramp (replaces flat 1.50). 1-indexed by chapter.
# Rationale: early chapters teach (gentle); late chapters counter roster growth
# (player reaches 6-7 heroes vs static 4 enemies) by raising per-hit pressure;
# climax (ch16 낙봉파 signature branch) is hardest.
const PROPOSED_RAMP: Array[float] = [
	1.25, # ch01 DEFEAT_ALL  3v4  tutorial (도원결의) — approachable intro
	1.30, # ch02 SURVIVE_5   3v3  early survival
	1.35, # ch03 DEFEAT_ALL  4v4
	1.40, # ch04 DEFEAT_ALL  5v4
	1.45, # ch05 SURVIVE_5   5v5
	1.45, # ch06 SURVIVE_5   2v4  장판파 — designed desperate, 2 heroes
	1.45, # ch07 DEFEAT_BOSS 2v2
	1.50, # ch08 REACH_TILE  5v4  race, combat incidental
	1.50, # ch09             6v4
	1.55, # ch10 SURVIVE_5   6v5  적벽
	1.55, # ch11 DEFEAT_ALL  6v4
	1.60, # ch12 DEFEAT_ALL  6v4
	1.60, # ch13 DEFEAT_ALL  6v4
	1.65, # ch14 DEFEAT_ALL  6v4
	1.65, # ch15 REACH_TILE  7v4
	1.70, # ch16 SURVIVE_4   7v4  낙봉파 signature climax — hardest
]


func _initialize() -> void:
	_atk_coeff = BalanceConstants.get_const("HERO_ATK_COEFF") as float
	_def_coeff = BalanceConstants.get_const("HERO_DEF_COEFF") as float
	_cmd_def_bonus = BalanceConstants.get_const("HERO_COMMANDER_DEF_BONUS") as int
	_run()
	quit()


# Builds a stat row for one hero. is_enemy applies enemy_atk_mult to raw_atk
# exactly as battle_scene._make_battle_unit does (int() truncation).
func _stat_row(hero_id: StringName, is_enemy: bool, mult: float) -> Dictionary:
	var hero: HeroData = HeroDatabase.get_hero(hero_id)
	if hero == null:
		return {}
	var cls: int = hero.default_class
	var raw_atk: int = int(hero.stat_might * _atk_coeff)
	if is_enemy:
		raw_atk = int(raw_atk * mult)
	var raw_def: int = int(hero.stat_command * _def_coeff)
	if cls == COMMANDER_CLASS:
		raw_def += _cmd_def_bonus
	var max_hp: int = UnitRole.get_max_hp(hero, cls)
	return {
		"id": hero_id,
		"name": hero.name_ko,
		"cls": cls,
		"atk": raw_atk,
		"def": raw_def,
		"hp": max_hp,
	}


# Real DamageCalc.resolve, plains (terrain_def=0, evasion=0), no passives/buff.
func _damage(attacker: Dictionary, defender: Dictionary, dir: StringName, is_counter: bool) -> int:
	var no_passives: Array[StringName] = []
	var atk_ctx: AttackerContext = AttackerContext.make(
		attacker["id"] as StringName, attacker["cls"] as int, attacker["atk"] as int,
		false, false, no_passives, false)
	var def_ctx: DefenderContext = DefenderContext.make(
		defender["id"] as StringName, defender["def"] as int, 0, 0)
	var mods: ResolveModifiers = ResolveModifiers.make(
		ResolveModifiers.AttackType.PHYSICAL, _rng, dir, 1, is_counter)
	var res: ResolveResult = DamageCalc.resolve(atk_ctx, def_ctx, mods)
	return res.resolved_damage


func _ttk(hp: int, dmg: int) -> int:
	if dmg <= 0:
		return 999
	return int(ceil(float(hp) / float(dmg)))


func _run() -> void:
	var f: FileAccess = FileAccess.open(SCENARIO_PATH, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var chapters: Array = data["chapters"] as Array

	print("================================================================")
	print(" BALANCE VERIFICATION — enemy_atk_mult difficulty curve (S95)")
	print(" raw_atk(player)=might ; raw_atk(enemy)=int(might*mult)")
	print(" raw_def=int(command*0.20)+CMD18 ; via real DamageCalc.resolve")
	print("================================================================")

	# ---- ch01 detailed matrix + sensitivity ----
	_print_chapter_detail(chapters[0] as Dictionary)

	# ---- 16-chapter ramp comparison: CURRENT(1.50 flat) vs PROPOSED ramp ----
	print("")
	print("=== RAMP COMPARISON — CURRENT (flat 1.50) vs PROPOSED ===")
	print(" metric by victory type: DEFEAT_ALL=margin(+player) ; else=alpha/cmdHP(<1 better)")
	print("ch | type        | P/E | cur→new |  CUR metric  |  NEW metric  | direction")
	print("---+-------------+-----+---------+--------------+--------------+----------")
	for i: int in range(min(16, chapters.size())):
		_print_ramp_compare(i + 1, chapters[i] as Dictionary)


# ch01 deep dive: full FRONT/REAR matrix + TTK + mult sensitivity.
func _print_chapter_detail(ch: Dictionary) -> void:
	var mult: float = float(ch.get("enemy_atk_mult", 1.0))
	var players: Array = _rosters(ch, false, mult)
	var enemies: Array = _rosters(ch, true, mult)

	print("")
	print("=== ch01 DETAIL  (enemy_atk_mult=%.2f) ===" % mult)
	print("PLAYERS:")
	for p: Dictionary in players:
		print("  %-4s %-6s cls=%s atk=%3d def=%3d hp=%3d"
			% [p["id"], p["name"], CLASS_ABBR[p["cls"]], p["atk"], p["def"], p["hp"]])
	print("ENEMIES (atk already ×%.2f):" % mult)
	for e: Dictionary in enemies:
		print("  %-4s %-6s cls=%s atk=%3d def=%3d hp=%3d"
			% [e["id"], e["name"], CLASS_ABBR[e["cls"]], e["atk"], e["def"], e["hp"]])

	print("")
	print("PLAYER → ENEMY  (FRONT dmg / TTK hits):")
	for p: Dictionary in players:
		var parts: Array[String] = []
		for e: Dictionary in enemies:
			var d: int = _damage(p, e, &"FRONT", false)
			parts.append("%s %d/%dh" % [e["name"], d, _ttk(e["hp"], d)])
		print("  %-6s → %s" % [p["name"], ", ".join(parts)])

	print("")
	print("ENEMY → PLAYER  (FRONT dmg / TTK hits):")
	for e: Dictionary in enemies:
		var parts: Array[String] = []
		for p: Dictionary in players:
			var d: int = _damage(e, p, &"FRONT", false)
			parts.append("%s %d/%dh" % [p["name"], d, _ttk(p["hp"], d)])
		print("  %-6s → %s" % [e["name"], ", ".join(parts)])

	print("")
	print("DIRECTION SWING on 유비 (cmd) — enemy 정원지(INF) dmg by facing:")
	var libei: Dictionary = players[0]
	var cyz: Dictionary = enemies[0]
	for dir: StringName in DIRECTIONS:
		var d: int = _damage(cyz, libei, dir, false)
		print("  %-5s: %3d dmg  (%d hits to drop 유비 %dHP)" % [dir, d, _ttk(libei["hp"], d), libei["hp"]])

	print("")
	print("MULT SENSITIVITY on ch01 (enemy_alpha on 유비 / clear / wipe rounds):")
	print("  mult | alpha→cmd | a/cmdHP | clrRnd | wipeRnd")
	for m: float in [1.00, 1.25, 1.50, 1.75, 2.00]:
		var ep: Array = _rosters(ch, false, m)
		var ee: Array = _rosters(ch, true, m)
		var metrics: Dictionary = _difficulty_metrics(ep, ee)
		print("  %.2f |   %4d    |  %.2f   |  %.2f  |  %.2f"
			% [m, metrics["alpha"], metrics["alpha_ratio"], metrics["clear_rounds"], metrics["wipe_rounds"]])


const VTYPE_NAMES: Dictionary = {
	0: "DEFEAT_ALL", 1: "SURVIVE_N", 2: "DEFEAT_BOSS", 3: "REACH_TILE", -1: "(default)"
}


func _print_ramp_compare(num: int, ch: Dictionary) -> void:
	var cur_mult: float = float(ch.get("enemy_atk_mult", 1.0))
	var new_mult: float = PROPOSED_RAMP[num - 1]
	var vc: Dictionary = ch.get("victory_conditions", {}) as Dictionary
	var vtype: int = int(vc.get("primary_condition_type", -1))

	var p: Array = _rosters(ch, false, cur_mult) # players are mult-independent
	var e_cur: Array = _rosters(ch, true, cur_mult)
	var e_new: Array = _rosters(ch, true, new_mult)
	if p.is_empty() or e_cur.is_empty():
		print("%2d | %-11s | SKIP" % [num, VTYPE_NAMES.get(vtype, "?")])
		return

	var m_cur: Dictionary = _difficulty_metrics(p, e_cur)
	var m_new: Dictionary = _difficulty_metrics(p, e_new)

	var cur_v: float
	var new_v: float
	var label: String
	if vtype == 0: # DEFEAT_ALL → margin (higher = easier for player)
		cur_v = (m_cur["wipe_rounds"] as float) - (m_cur["clear_rounds"] as float)
		new_v = (m_new["wipe_rounds"] as float) - (m_new["clear_rounds"] as float)
		label = "margin"
	else: # survival / boss / reach → alpha_ratio (lower = commander safer)
		cur_v = m_cur["alpha_ratio"] as float
		new_v = m_new["alpha_ratio"] as float
		label = "a/HP"

	var arrow: String = "harder" if new_v < cur_v else ("easier" if new_v > cur_v else "same")
	if vtype != 0:
		# for alpha_ratio, lower=harder for player; flip the wording
		arrow = "harder" if new_v > cur_v else ("easier" if new_v < cur_v else "same")
	print("%2d | %-11s | %d/%d |%.2f→%.2f| %s %+6.2f | %s %+6.2f | %s"
		% [num, VTYPE_NAMES.get(vtype, "?"), p.size(), e_cur.size(),
			cur_mult, new_mult, label, cur_v, label, new_v, arrow])


# Difficulty proxies. clear_rounds = enemy total HP / player team FRONT DPS
# (DPS = sum over players of avg FRONT dmg across all enemy defenders).
# wipe_rounds = player total HP / enemy team FRONT DPS. margin>0 => player wins.
# alpha = full enemy focus-fire FRONT damage on the commander in one round.
func _difficulty_metrics(players: Array, enemies: Array) -> Dictionary:
	var cmd: Dictionary = _find_commander(players)
	var cmd_hp: int = cmd["hp"] as int if not cmd.is_empty() else (players[0]["hp"] as int)
	var alpha: int = 0
	for e: Dictionary in enemies:
		alpha += _damage(e, cmd if not cmd.is_empty() else players[0], &"FRONT", false)

	var enemy_total_hp: int = 0
	for e: Dictionary in enemies:
		enemy_total_hp += e["hp"] as int
	var player_total_hp: int = 0
	for p: Dictionary in players:
		player_total_hp += p["hp"] as int

	var player_dps: float = _team_front_dps(players, enemies)
	var enemy_dps: float = _team_front_dps(enemies, players)

	return {
		"cmd_hp": cmd_hp,
		"alpha": float(alpha),
		"alpha_ratio": float(alpha) / float(cmd_hp),
		"clear_rounds": (float(enemy_total_hp) / player_dps) if player_dps > 0 else 999.0,
		"wipe_rounds": (float(player_total_hp) / enemy_dps) if enemy_dps > 0 else 999.0,
	}


# Sum over attackers of their average FRONT damage across all defenders.
func _team_front_dps(attackers: Array, defenders: Array) -> float:
	var total: float = 0.0
	for a: Dictionary in attackers:
		var sum_d: int = 0
		for d: Dictionary in defenders:
			sum_d += _damage(a, d, &"FRONT", false)
		if defenders.size() > 0:
			total += float(sum_d) / float(defenders.size())
	return total


func _find_commander(roster: Array) -> Dictionary:
	for u: Dictionary in roster:
		if (u["cls"] as int) == COMMANDER_CLASS:
			return u
	return {}


# Builds the player or enemy roster for a chapter from the scenario JSON.
func _rosters(ch: Dictionary, want_enemy: bool, mult: float) -> Array:
	var out: Array = []
	if want_enemy:
		var roster: Array = ch.get("enemy_roster", []) as Array
		for entry: Dictionary in roster:
			var row: Dictionary = _stat_row(entry["hero_id"] as StringName, true, mult)
			if not row.is_empty():
				out.append(row)
	else:
		var phm: Dictionary = ch.get("player_hero_ids", {}) as Dictionary
		for key: String in phm:
			var row: Dictionary = _stat_row(phm[key] as StringName, false, mult)
			if not row.is_empty():
				out.append(row)
	return out
