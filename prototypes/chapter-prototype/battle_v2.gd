# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does the existing GAME CONCEPT (formation tactics + hidden fate
#   branches + role differentiation + scenario story integration) work as a
#   coherent loop? Direct test of MVP Core Hypothesis from game-concept.md L296:
#   "진형 기반 턴제 전투에서 숨겨진 운명 분기 조건을 발견하는 경험이
#    회차 플레이를 유발할 만큼 재미있는가?"
# Date: 2026-05-02
# Owner: chapter.gd (this is the battle phase only)

extends Node2D

signal battle_ended(outcome: Dictionary)
# outcome dict shape:
#   { units: Array[Dict], turn_count: int,
#     fate_data: { tank_alive_hp_pct: float, assassin_kills: int,
#                  rear_attacks: int, formation_turns: int, boss_killed: bool } }

# ─── Map constants ──────────────────────────────────────────────────────────

const TILE_SIZE: int = 56
const GRID_W: int = 7
const GRID_H: int = 7
const MAX_TURNS: int = 5  # Pillar 1 + Pillar 2: time pressure forces tactical decisions

const T_PLAINS: int = 0
const T_FOREST: int = 1
const T_HILLS:  int = 2
const T_RIVER:  int = 3   # impassable
const T_BRIDGE: int = 4   # passable river crossing

# 7×7 = 49 tiles. River bisects map east-west; bridge at (3,3).
# Player west, enemy east.
const TERRAIN_MAP: Array[int] = [
	0, 0, 0, 0, 0, 0, 0,
	0, 1, 1, 0, 2, 2, 0,
	0, 1, 0, 3, 0, 2, 0,
	0, 0, 3, 4, 3, 0, 0,
	0, 2, 0, 3, 0, 1, 0,
	0, 2, 2, 0, 1, 1, 0,
	0, 0, 0, 0, 0, 0, 0,
]

# ─── Facing (last move direction; 8-direction collapsed to 4 cardinal) ──────

const FACE_E: int = 0  # +x
const FACE_S: int = 1  # +y
const FACE_W: int = 2  # -x
const FACE_N: int = 3  # -y

# ─── Hero pool (data — chapter.gd selects which 4 to instantiate) ───────────

const HERO_POOL: Dictionary = {
	"liu_bei": {
		"name": "유비", "side": 0, "atk": 18, "def": 14, "hp_max": 80,
		"move": 3, "range": 1, "passive": "command_aura",
	},
	"guan_yu": {  # disabled by chapter scenario
		"name": "관우", "side": 0, "atk": 32, "def": 18, "hp_max": 100,
		"move": 3, "range": 1, "passive": "",
	},
	"zhang_fei": {
		"name": "장비", "side": 0, "atk": 30, "def": 25, "hp_max": 120,
		"move": 2, "range": 1, "passive": "bridge_blocker", "tag": "tank",
	},
	"zhao_yun": {
		"name": "조운", "side": 0, "atk": 35, "def": 14, "hp_max": 90,
		"move": 5, "range": 1, "passive": "hit_and_run", "tag": "assassin",
	},
	"huang_zhong": {
		"name": "황충", "side": 0, "atk": 28, "def": 10, "hp_max": 70,
		"move": 3, "range": 2, "passive": "rear_specialist",
	},
}

# Enemy roster (Cao Cao's vanguard at Changban)
const ENEMY_ROSTER: Array[Dictionary] = [
	{"id": "xiahou_dun", "name": "하후돈", "side": 1, "atk": 28, "def": 16, "hp_max": 95,  "move": 3, "range": 1, "x": 5, "y": 3},
	{"id": "zhang_liao", "name": "장요",   "side": 1, "atk": 30, "def": 14, "hp_max": 90,  "move": 4, "range": 1, "x": 5, "y": 1},
	{"id": "yu_jin",     "name": "우금",   "side": 1, "atk": 24, "def": 18, "hp_max": 85,  "move": 3, "range": 1, "x": 5, "y": 5},
	{"id": "xu_zhu",     "name": "허저",   "side": 1, "atk": 36, "def": 22, "hp_max": 110, "move": 3, "range": 1, "x": 6, "y": 3, "boss": true},
]

# Player starting positions (must align with HERO_POOL keys; assigned by chapter.gd at start)
const PLAYER_START_POSITIONS: Dictionary = {
	"zhang_fei":   {"x": 3, "y": 3, "facing": FACE_E},  # on the bridge
	"zhao_yun":    {"x": 1, "y": 2, "facing": FACE_E},
	"huang_zhong": {"x": 1, "y": 4, "facing": FACE_E},
	"liu_bei":     {"x": 1, "y": 3, "facing": FACE_E},
}

# ─── Runtime state ──────────────────────────────────────────────────────────

var _selected_hero_ids: Array[String] = []  # set by chapter.gd before _ready
var _units: Array[Dictionary] = []
var _grid_nodes: Array[ColorRect] = []
var _unit_nodes: Dictionary = {}
var _turn_side: int = 0
var _turn_count: int = 1
var _selected_unit_id: String = ""
var _state: int = 0   # 0=observation, 1=unit_selected
var _move_targets: Array[Vector2i] = []
var _attack_targets: Array[Vector2i] = []
var _battle_over: bool = false
var _log_lines: Array[String] = []

# Hidden fate-condition tracking (NEVER displayed to player during battle)
var _fate_rear_attacks: int = 0
var _fate_formation_turns: int = 0
var _fate_assassin_kills: int = 0  # boss kills credited to zhao_yun specifically
var _fate_boss_killed: bool = false

# Selection-state UX flag — units that already acted this turn cannot re-act
var _acted_this_turn: Dictionary = {}  # id -> bool

# ─── Public entry (called by chapter.gd before adding to tree) ──────────────

func setup(selected_hero_ids: Array[String]) -> void:
	_selected_hero_ids = selected_hero_ids

# ─── Lifecycle ──────────────────────────────────────────────────────────────

func _ready() -> void:
	if _selected_hero_ids.is_empty():
		# Fallback for direct-load testing — pick first 3 + 장비
		_selected_hero_ids = ["zhang_fei", "zhao_yun", "huang_zhong", "liu_bei"]
	_init_units()
	_build_grid()
	_build_units()
	_build_hud()
	_log("[장판파] 전투 시작 — 5턴 안에 조조군을 막아라")
	_refresh_hud()

func _init_units() -> void:
	# Player units from selection
	for hid: String in _selected_hero_ids:
		if not HERO_POOL.has(hid): continue
		if not PLAYER_START_POSITIONS.has(hid): continue
		var data: Dictionary = HERO_POOL[hid].duplicate(true)
		var pos: Dictionary = PLAYER_START_POSITIONS[hid]
		data["id"] = hid
		data["x"] = int(pos["x"])
		data["y"] = int(pos["y"])
		data["facing"] = int(pos["facing"])
		data["hp_current"] = int(data["hp_max"])
		data["dead"] = false
		_units.append(data)
	# Enemy units fixed
	for e: Dictionary in ENEMY_ROSTER:
		var copy: Dictionary = e.duplicate(true)
		copy["facing"] = FACE_W
		copy["hp_current"] = int(copy["hp_max"])
		copy["dead"] = false
		copy["passive"] = ""
		_units.append(copy)

# ─── Build: grid ────────────────────────────────────────────────────────────

func _build_grid() -> void:
	var root: Node2D = $Grid
	for y in GRID_H:
		for x in GRID_W:
			var rect: ColorRect = ColorRect.new()
			rect.size = Vector2(TILE_SIZE - 2, TILE_SIZE - 2)
			rect.position = Vector2(x * TILE_SIZE + 1, y * TILE_SIZE + 1)
			var t: int = TERRAIN_MAP[y * GRID_W + x]
			rect.color = _terrain_color(t)
			rect.set_meta("coord", Vector2i(x, y))
			rect.set_meta("terrain", t)
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			root.add_child(rect)
			_grid_nodes.append(rect)

func _terrain_color(t: int) -> Color:
	match t:
		T_PLAINS: return Color(0.4, 0.65, 0.32)
		T_FOREST: return Color(0.13, 0.38, 0.16)
		T_HILLS:  return Color(0.55, 0.42, 0.22)
		T_RIVER:  return Color(0.18, 0.42, 0.72)
		T_BRIDGE: return Color(0.55, 0.35, 0.18)  # wood brown
	return Color(0.5, 0.5, 0.5)

func _terrain_name(t: int) -> String:
	match t:
		T_PLAINS: return "평지"
		T_FOREST: return "숲(+5DEF)"
		T_HILLS:  return "언덕(+8DEF)"
		T_RIVER:  return "강(통과불가)"
		T_BRIDGE: return "다리"
	return "?"

func _terrain_def_bonus(t: int) -> int:
	match t:
		T_FOREST: return 5
		T_HILLS:  return 8
	return 0

func _is_passable(t: int) -> bool:
	return t != T_RIVER

# ─── Build: units ───────────────────────────────────────────────────────────

func _build_units() -> void:
	for u: Dictionary in _units:
		var ctrl: ColorRect = ColorRect.new()
		ctrl.size = Vector2(TILE_SIZE - 8, TILE_SIZE - 8)
		var color: Color = Color(0.22, 0.45, 0.92) if int(u["side"]) == 0 else Color(0.9, 0.22, 0.22)
		if bool(u.get("boss", false)):
			color = Color(0.75, 0.05, 0.55)  # purple for boss
		ctrl.color = color
		ctrl.position = Vector2(int(u["x"]) * TILE_SIZE + 4, int(u["y"]) * TILE_SIZE + 4)
		ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var lbl: Label = Label.new()
		lbl.text = String(u["name"])
		lbl.add_theme_font_size_override("font_size", 13)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.position = Vector2(2, 2)
		ctrl.add_child(lbl)

		var facing_arrow: Label = Label.new()
		facing_arrow.name = "FacingArrow"
		facing_arrow.text = _facing_arrow(int(u["facing"]))
		facing_arrow.add_theme_font_size_override("font_size", 14)
		facing_arrow.add_theme_color_override("font_color", Color(1, 1, 0.5, 0.85))
		facing_arrow.add_theme_color_override("font_outline_color", Color.BLACK)
		facing_arrow.add_theme_constant_override("outline_size", 3)
		facing_arrow.position = Vector2(TILE_SIZE - 24, 2)
		ctrl.add_child(facing_arrow)

		var hp_bar_bg: ColorRect = ColorRect.new()
		hp_bar_bg.size = Vector2(TILE_SIZE - 16, 5)
		hp_bar_bg.position = Vector2(4, TILE_SIZE - 18)
		hp_bar_bg.color = Color(0.05, 0.05, 0.05, 0.85)
		ctrl.add_child(hp_bar_bg)

		var hp_bar: ColorRect = ColorRect.new()
		hp_bar.size = Vector2(TILE_SIZE - 16, 5)
		hp_bar.position = Vector2(4, TILE_SIZE - 18)
		hp_bar.color = Color(0.25, 0.85, 0.3)
		hp_bar.name = "HpBar"
		ctrl.add_child(hp_bar)

		$Units.add_child(ctrl)
		_unit_nodes[String(u["id"])] = ctrl

func _facing_arrow(f: int) -> String:
	match f:
		FACE_E: return "▶"
		FACE_S: return "▼"
		FACE_W: return "◀"
		FACE_N: return "▲"
	return "?"

# ─── Build: HUD ─────────────────────────────────────────────────────────────

func _build_hud() -> void:
	var hud: Control = $HUD
	var hud_y: int = GRID_H * TILE_SIZE + 8

	var turn_lbl: Label = Label.new()
	turn_lbl.name = "TurnLabel"
	turn_lbl.position = Vector2(10, hud_y)
	turn_lbl.add_theme_font_size_override("font_size", 18)
	hud.add_child(turn_lbl)

	var sel_lbl: Label = Label.new()
	sel_lbl.name = "SelLabel"
	sel_lbl.position = Vector2(10, hud_y + 26)
	sel_lbl.add_theme_font_size_override("font_size", 12)
	hud.add_child(sel_lbl)

	var help: Label = Label.new()
	help.text = "[Player] 파란 유닛 클릭 → 사거리 칸/적 클릭 (이동 OR 공격). 한 유닛은 한 턴에 한 번만 행동."
	help.position = Vector2(10, hud_y + 48)
	help.add_theme_font_size_override("font_size", 11)
	help.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	hud.add_child(help)

	var end_btn: Button = Button.new()
	end_btn.name = "EndTurnButton"
	end_btn.text = "턴 종료"
	end_btn.position = Vector2(GRID_W * TILE_SIZE - 80, hud_y + 70)
	end_btn.size = Vector2(80, 30)
	end_btn.pressed.connect(_on_end_turn_pressed)
	hud.add_child(end_btn)

	var log_lbl: Label = Label.new()
	log_lbl.name = "LogLabel"
	log_lbl.position = Vector2(10, hud_y + 70)
	log_lbl.add_theme_font_size_override("font_size", 10)
	log_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.6))
	hud.add_child(log_lbl)

func _refresh_hud() -> void:
	var turn_lbl: Label = $HUD/TurnLabel
	turn_lbl.text = "턴 %d/%d — %s" % [_turn_count, MAX_TURNS, ("플레이어" if _turn_side == 0 else "조조군")]
	turn_lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0) if _turn_side == 0 else Color(1.0, 0.45, 0.4))

	var sel_lbl: Label = $HUD/SelLabel
	if _selected_unit_id != "":
		var u: Dictionary = _get_unit(_selected_unit_id)
		var t: int = TERRAIN_MAP[int(u["y"]) * GRID_W + int(u["x"])]
		sel_lbl.text = "%s | HP %d/%d | ATK %d DEF %d MOV %d 사거리 %d | %s" % [
			u["name"], u["hp_current"], u["hp_max"], u["atk"], u["def"],
			u["move"], u["range"], _terrain_name(t),
		]
	else:
		sel_lbl.text = ""

	for u2: Dictionary in _units:
		var node: ColorRect = _unit_nodes[String(u2["id"])]
		var hp_bar: ColorRect = node.get_node("HpBar")
		var hp_pct: float = float(u2["hp_current"]) / float(u2["hp_max"])
		hp_bar.size.x = (TILE_SIZE - 16) * hp_pct
		if hp_pct < 0.33: hp_bar.color = Color(0.9, 0.2, 0.2)
		elif hp_pct < 0.66: hp_bar.color = Color(0.95, 0.75, 0.15)
		else: hp_bar.color = Color(0.25, 0.85, 0.3)
		var arrow: Label = node.get_node("FacingArrow")
		arrow.text = _facing_arrow(int(u2["facing"]))
		if bool(u2["dead"]):
			node.modulate = Color(0.4, 0.4, 0.4, 0.5)
		# Dim units that already acted this turn
		if int(u2["side"]) == 0 and _acted_this_turn.has(String(u2["id"])):
			node.modulate = Color(0.6, 0.6, 0.6, 1.0)
		elif not bool(u2["dead"]):
			node.modulate = Color(1, 1, 1, 1)

	var log_lbl: Label = $HUD/LogLabel
	var tail: Array = _log_lines.slice(maxi(0, _log_lines.size() - 4))
	log_lbl.text = "\n".join(tail)

# ─── Input ──────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if _battle_over: return
	if _turn_side != 0: return
	if not (event is InputEventMouseButton): return
	var mb: InputEventMouseButton = event
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed: return
	# Convert global → local (this Node2D is offset inside chapter.gd's BattlePanel)
	var local_pos: Vector2 = to_local(mb.position)
	var coord: Vector2i = _local_to_grid(local_pos)
	if coord.x < 0: return
	_handle_click(coord)

func _local_to_grid(pos: Vector2) -> Vector2i:
	var gx: int = int(pos.x / TILE_SIZE)
	var gy: int = int(pos.y / TILE_SIZE)
	if gx < 0 or gx >= GRID_W or gy < 0 or gy >= GRID_H:
		return Vector2i(-1, -1)
	return Vector2i(gx, gy)

func _handle_click(coord: Vector2i) -> void:
	var unit_at: Variant = _unit_at(coord)
	match _state:
		0:
			if unit_at != null and int(unit_at["side"]) == 0 and not bool(unit_at["dead"]):
				if _acted_this_turn.has(String(unit_at["id"])):
					_log("이미 행동한 유닛입니다")
					return
				_select_unit(String(unit_at["id"]))
		1:
			if unit_at != null and String(unit_at["id"]) == _selected_unit_id:
				_deselect()
				return
			# Attack target?
			if unit_at != null and int(unit_at["side"]) == 1 and not bool(unit_at["dead"]) and coord in _attack_targets:
				_do_attack(_get_unit(_selected_unit_id), unit_at)
				_consume_unit_action(_selected_unit_id)
				return
			# Move target?
			if unit_at == null and coord in _move_targets:
				_do_move(_get_unit(_selected_unit_id), coord)
				# After move, can the unit attack? If so, allow follow-up. Otherwise consume.
				_recompute_attack_targets_only(_get_unit(_selected_unit_id))
				if _attack_targets.is_empty():
					_consume_unit_action(_selected_unit_id)
				else:
					_apply_highlights()
					_refresh_hud()

# ─── Selection / highlights ─────────────────────────────────────────────────

func _select_unit(id: String) -> void:
	_selected_unit_id = id
	_state = 1
	var u: Dictionary = _get_unit(id)
	_compute_move_targets(u)
	_compute_attack_targets(u)
	_apply_highlights()
	_refresh_hud()

func _deselect() -> void:
	_selected_unit_id = ""
	_state = 0
	_move_targets.clear()
	_attack_targets.clear()
	_clear_highlights()
	_refresh_hud()

func _consume_unit_action(id: String) -> void:
	_acted_this_turn[id] = true
	_deselect()
	# Auto-end turn if all alive player units have acted
	var any_can_act: bool = false
	for u: Dictionary in _units:
		if int(u["side"]) == 0 and not bool(u["dead"]) and not _acted_this_turn.has(String(u["id"])):
			any_can_act = true; break
	if not any_can_act:
		_on_end_turn_pressed()

func _on_end_turn_pressed() -> void:
	if _turn_side != 0 or _battle_over: return
	_deselect()
	if _check_battle_end(): return
	_turn_side = 1
	_refresh_hud()
	await get_tree().create_timer(0.4).timeout
	await _ai_turn()

func _compute_move_targets(u: Dictionary) -> void:
	_move_targets.clear()
	var ux: int = int(u["x"]); var uy: int = int(u["y"])
	var rng: int = int(u["move"])
	for y in GRID_H:
		for x in GRID_W:
			if x == ux and y == uy: continue
			if _unit_at(Vector2i(x, y)) != null: continue
			var d: int = absi(x - ux) + absi(y - uy)
			if d > rng: continue
			if not _is_passable(TERRAIN_MAP[y * GRID_W + x]): continue
			_move_targets.append(Vector2i(x, y))

func _compute_attack_targets(u: Dictionary) -> void:
	_attack_targets.clear()
	var rng: int = int(u["range"])
	for other: Dictionary in _units:
		if int(other["side"]) == int(u["side"]) or bool(other["dead"]): continue
		var d: int = absi(int(other["x"]) - int(u["x"])) + absi(int(other["y"]) - int(u["y"]))
		if d <= rng:
			_attack_targets.append(Vector2i(int(other["x"]), int(other["y"])))

func _recompute_attack_targets_only(u: Dictionary) -> void:
	# Used after a move-without-action — clear move targets, recompute attacks at new pos
	_move_targets.clear()
	_compute_attack_targets(u)

func _apply_highlights() -> void:
	for rect: ColorRect in _grid_nodes:
		var c: Vector2i = rect.get_meta("coord")
		var t: int = rect.get_meta("terrain")
		if c in _attack_targets:
			rect.color = Color(0.95, 0.25, 0.25)
		elif c in _move_targets:
			rect.color = _terrain_color(t).lightened(0.35)
		else:
			rect.color = _terrain_color(t)

func _clear_highlights() -> void:
	for rect: ColorRect in _grid_nodes:
		rect.color = _terrain_color(rect.get_meta("terrain"))

# ─── Queries ────────────────────────────────────────────────────────────────

func _unit_at(coord: Vector2i) -> Variant:
	for u: Dictionary in _units:
		if bool(u["dead"]): continue
		if int(u["x"]) == coord.x and int(u["y"]) == coord.y: return u
	return null

func _get_unit(id: String) -> Dictionary:
	for u: Dictionary in _units:
		if String(u["id"]) == id: return u
	return {}

func _adjacent_allies_count(u: Dictionary) -> int:
	var count: int = 0
	for o: Dictionary in _units:
		if String(o["id"]) == String(u["id"]): continue
		if bool(o["dead"]): continue
		if int(o["side"]) != int(u["side"]): continue
		var d: int = absi(int(o["x"]) - int(u["x"])) + absi(int(o["y"]) - int(u["y"]))
		if d == 1: count += 1
	return count

func _attack_angle(attacker: Dictionary, defender: Dictionary) -> String:
	# Returns "front", "side", or "rear" based on attacker position vs defender facing
	var dx: int = int(attacker["x"]) - int(defender["x"])
	var dy: int = int(attacker["y"]) - int(defender["y"])
	# Normalize attack direction (where attacker is, relative to defender)
	var attack_dir: int = -1
	if absi(dx) >= absi(dy):
		attack_dir = (FACE_E if dx > 0 else FACE_W)
	else:
		attack_dir = (FACE_S if dy > 0 else FACE_N)
	var def_facing: int = int(defender["facing"])
	if attack_dir == def_facing:
		return "front"
	elif (attack_dir + 2) % 4 == def_facing:
		return "rear"
	else:
		return "side"

# ─── Actions ────────────────────────────────────────────────────────────────

func _do_move(u: Dictionary, dest: Vector2i) -> void:
	var dx: int = dest.x - int(u["x"])
	var dy: int = dest.y - int(u["y"])
	# Update facing to last move direction
	if absi(dx) >= absi(dy) and dx != 0:
		u["facing"] = (FACE_E if dx > 0 else FACE_W)
	elif dy != 0:
		u["facing"] = (FACE_S if dy > 0 else FACE_N)
	u["x"] = dest.x
	u["y"] = dest.y
	var node: ColorRect = _unit_nodes[String(u["id"])]
	var tw: Tween = create_tween()
	tw.tween_property(node, "position",
		Vector2(dest.x * TILE_SIZE + 4, dest.y * TILE_SIZE + 4), 0.18).set_trans(Tween.TRANS_QUAD)
	_log("%s 이동 → (%d,%d)" % [u["name"], dest.x, dest.y])

func _do_attack(attacker: Dictionary, defender: Dictionary) -> void:
	# Face the defender first (free reorient as part of attack)
	var dx: int = int(defender["x"]) - int(attacker["x"])
	var dy: int = int(defender["y"]) - int(attacker["y"])
	if absi(dx) >= absi(dy) and dx != 0:
		attacker["facing"] = (FACE_E if dx > 0 else FACE_W)
	elif dy != 0:
		attacker["facing"] = (FACE_S if dy > 0 else FACE_N)

	var t: int = TERRAIN_MAP[int(defender["y"]) * GRID_W + int(defender["x"])]
	var def_terrain_bonus: int = _terrain_def_bonus(t)
	var base: int = maxi(1, int(attacker["atk"]) - int(defender["def"]) - def_terrain_bonus)

	# Formation bonus: +5% per adjacent ally (max +20%)
	var formation_count: int = _adjacent_allies_count(attacker)
	var formation_mult: float = 1.0 + 0.05 * float(formation_count)

	# Angle bonus
	var angle: String = _attack_angle(attacker, defender)
	var angle_mult: float = 1.0
	match angle:
		"side": angle_mult = 1.25
		"rear":
			angle_mult = 1.50
			# Huang Zhong's specialist passive: +25% extra on rear (= 1.75)
			if String(attacker.get("passive", "")) == "rear_specialist":
				angle_mult = 1.75

	# Liu Bei command_aura: +15% if adjacent to attacker
	var aura_mult: float = 1.0
	for o: Dictionary in _units:
		if String(o["id"]) == String(attacker["id"]): continue
		if int(o["side"]) != int(attacker["side"]): continue
		if bool(o["dead"]): continue
		if String(o.get("passive", "")) != "command_aura": continue
		var dist: int = absi(int(o["x"]) - int(attacker["x"])) + absi(int(o["y"]) - int(attacker["y"]))
		if dist == 1: aura_mult = 1.15; break

	var dmg: int = int(floor(float(base) * formation_mult * angle_mult * aura_mult))
	dmg = maxi(1, dmg)
	defender["hp_current"] = maxi(0, int(defender["hp_current"]) - dmg)

	# Track fate conditions (silently)
	if angle == "rear":
		_fate_rear_attacks += 1

	var log_extras: Array[String] = []
	if formation_count > 0: log_extras.append("진형x%.2f(인접%d)" % [formation_mult, formation_count])
	if angle != "front": log_extras.append("%sx%.2f" % [angle, angle_mult])
	if aura_mult > 1.0: log_extras.append("유비명령x%.2f" % aura_mult)
	var extras_str: String = (" [" + ", ".join(log_extras) + "]") if not log_extras.is_empty() else ""

	_log("⚔ %s → %s : %d 피해%s" % [attacker["name"], defender["name"], dmg, extras_str])

	var node: ColorRect = _unit_nodes[String(defender["id"])]
	var orig: Color = node.color
	var ftw: Tween = create_tween()
	ftw.tween_property(node, "color", Color.WHITE, 0.05)
	ftw.tween_property(node, "color", orig, 0.15)

	if int(defender["hp_current"]) <= 0:
		defender["dead"] = true
		_log("💀 %s 처치" % defender["name"])
		# Track fate: was it the assassin (zhao_yun) who killed?
		if String(attacker["id"]) == "zhao_yun" and int(defender["side"]) == 1:
			_fate_assassin_kills += 1
		# Track fate: was it the boss?
		if bool(defender.get("boss", false)):
			_fate_boss_killed = true

# ─── Turn flow ──────────────────────────────────────────────────────────────

func _ai_turn() -> void:
	# Each living enemy unit takes one action
	for ai: Dictionary in _units:
		if int(ai["side"]) != 1 or bool(ai["dead"]): continue
		await _ai_act(ai)
		if _check_battle_end(): return
		await get_tree().create_timer(0.2).timeout
	# End-of-turn: check formation_turns fate condition
	# Count "formation moments" — at end of player+enemy round, are >=2 player units adjacent?
	var formation_active: bool = false
	for u: Dictionary in _units:
		if int(u["side"]) != 0 or bool(u["dead"]): continue
		if _adjacent_allies_count(u) >= 1:  # at least 1 adjacent ally = formation
			formation_active = true; break
	if formation_active:
		_fate_formation_turns += 1

	# Advance turn or end battle
	_acted_this_turn.clear()
	_turn_side = 0
	_turn_count += 1
	if _turn_count > MAX_TURNS:
		_log("⏰ 시간 종료 — 5턴 만료")
		_finish_battle()
		return
	_log("─── 턴 %d ───" % _turn_count)
	_refresh_hud()

func _ai_act(ai: Dictionary) -> void:
	# Find nearest living player target
	var target: Variant = null
	var min_d: int = 99999
	for u: Dictionary in _units:
		if int(u["side"]) == 0 and not bool(u["dead"]):
			var d: int = absi(int(u["x"]) - int(ai["x"])) + absi(int(u["y"]) - int(ai["y"]))
			if d < min_d:
				min_d = d
				target = u
	if target == null: return

	var rng: int = int(ai["range"])
	if min_d <= rng:
		_do_attack(ai, target)
		_refresh_hud()
		return

	# Greedy step toward target (Zhang Fei's bridge_blocker passive halves nearby AI move)
	var move_budget: int = int(ai["move"])
	# Check bridge_blocker proximity reduction
	for o: Dictionary in _units:
		if String(o.get("passive", "")) != "bridge_blocker": continue
		if bool(o["dead"]): continue
		var dist: int = absi(int(o["x"]) - int(ai["x"])) + absi(int(o["y"]) - int(ai["y"]))
		if dist == 1:
			move_budget = maxi(1, move_budget - 1)
			break

	while move_budget > 0:
		var tx: int = int(target["x"]); var ty: int = int(target["y"])
		var ax: int = int(ai["x"]); var ay: int = int(ai["y"])
		var d_now: int = absi(tx - ax) + absi(ty - ay)
		if d_now <= rng: break
		var step: Vector2i = Vector2i(ax, ay)
		if absi(tx - ax) >= absi(ty - ay) and tx != ax:
			step.x += signi(tx - ax)
		elif ty != ay:
			step.y += signi(ty - ay)
		else:
			break
		if step.x < 0 or step.x >= GRID_W or step.y < 0 or step.y >= GRID_H: break
		if _unit_at(step) != null: break
		if not _is_passable(TERRAIN_MAP[step.y * GRID_W + step.x]): break
		_do_move(ai, step)
		move_budget -= 1
		await get_tree().create_timer(0.18).timeout

	# Attack if in range now
	var final_d: int = absi(int(target["x"]) - int(ai["x"])) + absi(int(target["y"]) - int(ai["y"]))
	if final_d <= rng:
		await get_tree().create_timer(0.12).timeout
		_do_attack(ai, target)
	_refresh_hud()

# ─── Battle end check ──────────────────────────────────────────────────────

func _check_battle_end() -> bool:
	var player_alive: bool = false
	var enemy_alive: bool = false
	for u: Dictionary in _units:
		if bool(u["dead"]): continue
		if int(u["side"]) == 0: player_alive = true
		else: enemy_alive = true
	if not player_alive or not enemy_alive:
		_finish_battle()
		return true
	return false

func _finish_battle() -> void:
	_battle_over = true
	# Compute fate snapshot
	var tank_pct: float = 0.0
	for u: Dictionary in _units:
		if String(u["id"]) == "zhang_fei":
			tank_pct = float(u["hp_current"]) / float(u["hp_max"]) if not bool(u["dead"]) else 0.0
			break
	var outcome: Dictionary = {
		"units": _units,
		"turn_count": _turn_count,
		"fate_data": {
			"tank_alive_hp_pct": tank_pct,
			"assassin_kills": _fate_assassin_kills,
			"rear_attacks": _fate_rear_attacks,
			"formation_turns": _fate_formation_turns,
			"boss_killed": _fate_boss_killed,
		},
	}
	_log("=== 전투 종료 ===")
	_refresh_hud()
	# Wait briefly so player sees the final state, then signal
	await get_tree().create_timer(1.5).timeout
	battle_ended.emit(outcome)

# ─── Logging ────────────────────────────────────────────────────────────────

func _log(msg: String) -> void:
	_log_lines.append(msg)
	print("[BATTLE_V2] " + msg)
