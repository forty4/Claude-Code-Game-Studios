# What-if roster modeling (S96) — telemetry over reasoning.
# Reuses the REAL DamageCalc.resolve + real stats/HP (same derivation as
# ttk_matrix.gd) to quantify how the late-game DEFEAT_ALL margin
# (ch11-14, 6v4) responds to the two levers the S95 ramp could NOT move:
#   (A) enemy COUNT — append 5th / 6th enemy
#   (B) enemy STRENGTH — flat enemy HP multiplier (hypothetical new field)
#
# margin = wipe_rounds - clear_rounds ; > 0 = player wins attrition (too easy).
# Early DEFEAT_ALL baseline (ch01 mult1.25 = -0.43) is the "strategy required" target.
#
# Run: godot --headless --path . -s res://tools/ci/balance/whatif_late_roster.gd
extends SceneTree

const SCENARIO_PATH: String = "res://assets/data/scenarios/shu_canon_main.json"
const COMMANDER_CLASS: int = 4
# Candidate reinforcements (real heroes not already in the ch11-14 base roster).
const ADD_5TH: StringName = &"wei_001_cao_cao"   # COMMANDER, tanky (might75 cmd92)
const ADD_6TH: StringName = &"qun_001_lu_bu"     # CAVALRY, lethal (might100 cmd70)

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _atk_coeff: float = 1.0
var _def_coeff: float = 0.20
var _cmd_def_bonus: int = 18


func _initialize() -> void:
	_atk_coeff = BalanceConstants.get_const("HERO_ATK_COEFF") as float
	_def_coeff = BalanceConstants.get_const("HERO_DEF_COEFF") as float
	_cmd_def_bonus = BalanceConstants.get_const("HERO_COMMANDER_DEF_BONUS") as int
	_run()
	quit()


func _stat_row(hero_id: StringName, is_enemy: bool, mult: float, hp_mult: float) -> Dictionary:
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
	if is_enemy:
		max_hp = int(max_hp * hp_mult)
	return {"id": hero_id, "cls": cls, "atk": raw_atk, "def": raw_def, "hp": max_hp}


func _damage(attacker: Dictionary, defender: Dictionary) -> int:
	var no_passives: Array[StringName] = []
	var atk_ctx: AttackerContext = AttackerContext.make(
		attacker["id"] as StringName, attacker["cls"] as int, attacker["atk"] as int,
		false, false, no_passives, false)
	var def_ctx: DefenderContext = DefenderContext.make(
		defender["id"] as StringName, defender["def"] as int, 0, 0)
	var mods: ResolveModifiers = ResolveModifiers.make(
		ResolveModifiers.AttackType.PHYSICAL, _rng, &"FRONT", 1, false)
	return DamageCalc.resolve(atk_ctx, def_ctx, mods).resolved_damage


func _team_dps(attackers: Array, defenders: Array) -> float:
	var total: float = 0.0
	for a: Dictionary in attackers:
		var sum_d: int = 0
		for d: Dictionary in defenders:
			sum_d += _damage(a, d)
		if defenders.size() > 0:
			total += float(sum_d) / float(defenders.size())
	return total


func _margin(players: Array, enemies: Array) -> float:
	var enemy_hp: int = 0
	for e: Dictionary in enemies:
		enemy_hp += e["hp"] as int
	var player_hp: int = 0
	for p: Dictionary in players:
		player_hp += p["hp"] as int
	var pdps: float = _team_dps(players, enemies)
	var edps: float = _team_dps(enemies, players)
	var clear_rounds: float = (float(enemy_hp) / pdps) if pdps > 0 else 999.0
	var wipe_rounds: float = (float(player_hp) / edps) if edps > 0 else 999.0
	return wipe_rounds - clear_rounds


func _players(ch: Dictionary) -> Array:
	var out: Array = []
	var phm: Dictionary = ch.get("player_hero_ids", {}) as Dictionary
	for key: String in phm:
		var row: Dictionary = _stat_row(phm[key] as StringName, false, 1.0, 1.0)
		if not row.is_empty():
			out.append(row)
	return out


func _enemies(ch: Dictionary, mult: float, hp_mult: float, extra: Array[StringName]) -> Array:
	var out: Array = []
	for entry: Dictionary in (ch.get("enemy_roster", []) as Array):
		var row: Dictionary = _stat_row(entry["hero_id"] as StringName, true, mult, hp_mult)
		if not row.is_empty():
			out.append(row)
	for hid: StringName in extra:
		var row: Dictionary = _stat_row(hid, true, mult, hp_mult)
		if not row.is_empty():
			out.append(row)
	return out


func _run() -> void:
	var f: FileAccess = FileAccess.open(SCENARIO_PATH, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	var chapters: Array = data["chapters"] as Array

	print("================================================================")
	print(" WHAT-IF LATE-GAME ROSTER (S96) — DEFEAT_ALL ch11-14 margin")
	print(" margin = wipeRnd - clearRnd ; >0 player wins attrition (too easy)")
	print(" TARGET: pull toward ~0 or slightly negative (ch01 baseline -0.43)")
	print(" 5th = %s ; 6th = %s" % [ADD_5TH, ADD_6TH])
	print("================================================================")
	print("ch | mult | base E4 | +5th E5 | +5th+6th E6 | E4 hp1.3 | E4 hp1.5 | E5 hp1.3")
	print("---+------+---------+---------+-------------+----------+----------+---------")

	var none: Array[StringName] = []
	var five: Array[StringName] = [ADD_5TH]
	var six: Array[StringName] = [ADD_5TH, ADD_6TH]

	for idx: int in [10, 11, 12, 13]: # ch11-14
		var ch: Dictionary = chapters[idx] as Dictionary
		var mult: float = float(ch.get("enemy_atk_mult", 1.0))
		var p: Array = _players(ch)
		var m_base: float = _margin(p, _enemies(ch, mult, 1.0, none))
		var m_e5: float = _margin(p, _enemies(ch, mult, 1.0, five))
		var m_e6: float = _margin(p, _enemies(ch, mult, 1.0, six))
		var m_hp13: float = _margin(p, _enemies(ch, mult, 1.3, none))
		var m_hp15: float = _margin(p, _enemies(ch, mult, 1.5, none))
		var m_e5hp13: float = _margin(p, _enemies(ch, mult, 1.3, five))
		print("%2d | %.2f | %+6.2f  | %+6.2f  | %+9.2f   | %+7.2f  | %+7.2f  | %+6.2f"
			% [idx + 1, mult, m_base, m_e5, m_e6, m_hp13, m_hp15, m_e5hp13])

	print("")
	print("REFERENCE early DEFEAT_ALL margins (strategy-required zone):")
	for idx: int in [0, 2, 3]: # ch01, ch03, ch04
		var ch: Dictionary = chapters[idx] as Dictionary
		var mult: float = float(ch.get("enemy_atk_mult", 1.0))
		var m: float = _margin(_players(ch), _enemies(ch, mult, 1.0, none))
		print("  ch%02d (mult %.2f, %dv%d): margin %+.2f"
			% [idx + 1, mult, (ch.get("player_hero_ids", {}) as Dictionary).size(),
				(ch.get("enemy_roster", []) as Array).size(), m])

	# ── FINAL S96 PLAN — per-chapter 5th enemy (cao_cao already in ch13) ──
	# ch11/12/14 add cao_cao (only unused wei COMMANDER). ch13 already has
	# cao_cao → test the two remaining wei: xu_chu (CMD) vs zhang_liao (STR).
	print("")
	print("=== FINAL S96 PLAN — actual 5th-enemy per chapter ===")
	var caocao: Array[StringName] = [&"wei_001_cao_cao"]
	var xuchu: Array[StringName] = [&"wei_008_xu_chu"]
	var zhangliao: Array[StringName] = [&"wei_006_zhang_liao"]
	for spec: Array in [[10, caocao, "+조조"], [11, caocao, "+조조"]]:
		_print_plan(chapters[spec[0] as int] as Dictionary, spec[0] as int, spec[1] as Array, spec[2] as String)
	# ch13: two candidates
	_print_plan(chapters[12] as Dictionary, 12, xuchu, "+서황(CMD)")
	_print_plan(chapters[12] as Dictionary, 12, zhangliao, "+장료(STR)")
	_print_plan(chapters[13] as Dictionary, 13, caocao, "+조조")


func _print_plan(ch: Dictionary, idx: int, extra: Array, label: String) -> void:
	var ex: Array[StringName] = []
	ex.assign(extra)
	var mult: float = float(ch.get("enemy_atk_mult", 1.0))
	var p: Array = _players(ch)
	var m_base: float = _margin(p, _enemies(ch, mult, 1.0, [] as Array[StringName]))
	var m_new: float = _margin(p, _enemies(ch, mult, 1.0, ex))
	print("  ch%02d %-11s mult%.2f : E4 %+.2f → E5 %s %+.2f"
		% [idx + 1, ch.get("chapter_id", "?"), mult, m_base, label, m_new])
