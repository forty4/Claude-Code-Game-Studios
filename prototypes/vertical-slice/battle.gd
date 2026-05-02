# PROTOTYPE - NOT FOR PRODUCTION
# Question: Does the existing backend (damage formula + HP tracking + grid +
#   terrain + turn order) feel like an actual battle game when wired together
#   with placeholder visuals (ColorRect + Label, no sprites)?
# Date: 2026-05-02
#
# DO NOT IMPORT FROM src/. All logic inlined per /prototype skill rules.
# Run via: open in Godot 4.6 editor, open battle.tscn, press F6.

extends Node2D

# ─── Constants (inlined; would normally live in BalanceConstants) ─────────────

const TILE_SIZE: int = 64
const GRID_W: int = 8
const GRID_H: int = 6

const TERRAIN_PLAINS: int = 0
const TERRAIN_FOREST: int = 1
const TERRAIN_HILLS: int = 2
const TERRAIN_RIVER: int = 3

# 8 cols × 6 rows = 48 tiles. Mix of terrains for visible variety.
const TERRAIN_MAP: Array[int] = [
	0, 0, 0, 0, 1, 1, 2, 2,   # row 0
	0, 1, 1, 0, 0, 1, 2, 2,   # row 1
	0, 1, 0, 0, 3, 3, 1, 2,   # row 2
	0, 0, 0, 3, 3, 0, 0, 2,   # row 3
	1, 1, 0, 0, 0, 0, 2, 2,   # row 4
	1, 0, 0, 0, 0, 2, 2, 2,   # row 5
]

# ─── Hardcoded units (would normally come from HeroDatabase) ─────────────────
# Modeled loosely on the Three Kingdoms cast from heroes.json design.

const UNITS_INITIAL: Array[Dictionary] = [
	{
		"id": "liu_bei", "name": "유비 (Liu Bei)", "side": 0,
		"atk": 22, "def": 12, "hp_max": 80, "move": 3,
		"x": 1, "y": 2,
	},
	{
		"id": "guan_yu", "name": "관우 (Guan Yu)", "side": 0,
		"atk": 32, "def": 18, "hp_max": 100, "move": 3,
		"x": 0, "y": 4,
	},
	{
		"id": "lu_bu", "name": "여포 (Lu Bu)", "side": 1,
		"atk": 38, "def": 14, "hp_max": 110, "move": 3,
		"x": 7, "y": 2,
	},
	{
		"id": "dong_zhuo", "name": "동탁 (Dong Zhuo)", "side": 1,
		"atk": 24, "def": 22, "hp_max": 95, "move": 2,
		"x": 6, "y": 4,
	},
]

# ─── Runtime state ───────────────────────────────────────────────────────────

var _units: Array[Dictionary] = []
var _grid_nodes: Array[ColorRect] = []
var _unit_nodes: Dictionary = {}      # id (String) → Control
var _turn_side: int = 0                # 0 = player, 1 = enemy
var _selected_unit_id: String = ""
var _state: int = 0                    # 0=observation, 1=unit_selected
var _move_targets: Array[Vector2i] = []
var _attack_targets: Array[Vector2i] = []
var _battle_over: bool = false
var _turn_count: int = 1
var _log_lines: Array[String] = []

# ─── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	_init_units()
	_build_grid()
	_build_units()
	_build_hud()
	_log("Battle start — Player turn 1")
	_refresh_hud()

func _init_units() -> void:
	for u: Dictionary in UNITS_INITIAL:
		var copy: Dictionary = u.duplicate()
		copy["hp_current"] = copy["hp_max"]
		copy["dead"] = false
		_units.append(copy)

# ─── Build: grid ─────────────────────────────────────────────────────────────

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
			rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # we handle clicks at root
			root.add_child(rect)
			_grid_nodes.append(rect)

func _terrain_color(t: int) -> Color:
	match t:
		TERRAIN_PLAINS: return Color(0.4, 0.65, 0.32)
		TERRAIN_FOREST: return Color(0.13, 0.38, 0.16)
		TERRAIN_HILLS:  return Color(0.55, 0.42, 0.22)
		TERRAIN_RIVER:  return Color(0.18, 0.42, 0.72)
	return Color(0.5, 0.5, 0.5)

func _terrain_name(t: int) -> String:
	match t:
		TERRAIN_PLAINS: return "PLAINS"
		TERRAIN_FOREST: return "FOREST"
		TERRAIN_HILLS:  return "HILLS"
		TERRAIN_RIVER:  return "RIVER"
	return "?"

func _terrain_def_bonus(t: int) -> int:
	# Inlined from terrain-effect GDD intent (Forest=15 evasion equivalent / Hills=15 def / River=-3 malus)
	match t:
		TERRAIN_FOREST: return 5
		TERRAIN_HILLS:  return 8
		TERRAIN_RIVER:  return -3
	return 0

# ─── Build: units ────────────────────────────────────────────────────────────

func _build_units() -> void:
	for u: Dictionary in _units:
		var ctrl: ColorRect = ColorRect.new()
		ctrl.size = Vector2(TILE_SIZE - 8, TILE_SIZE - 8)
		ctrl.color = Color(0.22, 0.45, 0.92) if int(u["side"]) == 0 else Color(0.9, 0.22, 0.22)
		ctrl.position = Vector2(int(u["x"]) * TILE_SIZE + 4, int(u["y"]) * TILE_SIZE + 4)
		ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var lbl: Label = Label.new()
		lbl.text = String(u["name"]).split(" ")[0]  # Korean name only, e.g. "유비"
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 4)
		lbl.position = Vector2(2, 4)
		ctrl.add_child(lbl)

		var hp_bar_bg: ColorRect = ColorRect.new()
		hp_bar_bg.size = Vector2(TILE_SIZE - 16, 6)
		hp_bar_bg.position = Vector2(4, TILE_SIZE - 22)
		hp_bar_bg.color = Color(0.1, 0.1, 0.1, 0.85)
		ctrl.add_child(hp_bar_bg)

		var hp_bar: ColorRect = ColorRect.new()
		hp_bar.size = Vector2(TILE_SIZE - 16, 6)
		hp_bar.position = Vector2(4, TILE_SIZE - 22)
		hp_bar.color = Color(0.25, 0.85, 0.3)
		hp_bar.name = "HpBar"
		ctrl.add_child(hp_bar)

		$Units.add_child(ctrl)
		_unit_nodes[String(u["id"])] = ctrl

# ─── Build: HUD ──────────────────────────────────────────────────────────────

func _build_hud() -> void:
	var hud: Control = $HUD
	var hud_y: int = GRID_H * TILE_SIZE + 12

	var turn_lbl: Label = Label.new()
	turn_lbl.name = "TurnLabel"
	turn_lbl.position = Vector2(16, hud_y)
	turn_lbl.add_theme_font_size_override("font_size", 22)
	hud.add_child(turn_lbl)

	var sel_lbl: Label = Label.new()
	sel_lbl.name = "SelLabel"
	sel_lbl.position = Vector2(16, hud_y + 32)
	sel_lbl.add_theme_font_size_override("font_size", 14)
	hud.add_child(sel_lbl)

	var help: Label = Label.new()
	help.text = "[Player turn] click your blue unit → click highlighted tile to move OR red enemy to attack. Click selected unit to deselect."
	help.position = Vector2(16, hud_y + 58)
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	hud.add_child(help)

	var log_lbl: Label = Label.new()
	log_lbl.name = "LogLabel"
	log_lbl.position = Vector2(16, hud_y + 82)
	log_lbl.add_theme_font_size_override("font_size", 12)
	log_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.6))
	hud.add_child(log_lbl)

	var win_lbl: Label = Label.new()
	win_lbl.name = "WinLabel"
	win_lbl.position = Vector2(GRID_W * TILE_SIZE / 2 - 100, GRID_H * TILE_SIZE / 2 - 30)
	win_lbl.add_theme_font_size_override("font_size", 56)
	win_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	win_lbl.add_theme_constant_override("outline_size", 6)
	win_lbl.visible = false
	hud.add_child(win_lbl)

func _refresh_hud() -> void:
	var turn_lbl: Label = $HUD/TurnLabel
	turn_lbl.text = "TURN %d — %s" % [_turn_count, "PLAYER" if _turn_side == 0 else "ENEMY"]
	turn_lbl.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0) if _turn_side == 0 else Color(1.0, 0.45, 0.4))

	var sel_lbl: Label = $HUD/SelLabel
	if _selected_unit_id != "":
		var u: Dictionary = _get_unit(_selected_unit_id)
		var t: int = TERRAIN_MAP[int(u["y"]) * GRID_W + int(u["x"])]
		sel_lbl.text = "SELECTED: %s | HP %d/%d | ATK %d DEF %d MOV %d | on %s" % [
			u["name"], u["hp_current"], u["hp_max"], u["atk"], u["def"], u["move"], _terrain_name(t),
		]
	else:
		sel_lbl.text = ""

	# HP bars
	for u2: Dictionary in _units:
		var node: ColorRect = _unit_nodes[String(u2["id"])]
		var hp_bar: ColorRect = node.get_node("HpBar")
		var hp_pct: float = float(u2["hp_current"]) / float(u2["hp_max"])
		hp_bar.size.x = (TILE_SIZE - 16) * hp_pct
		if hp_pct < 0.33: hp_bar.color = Color(0.9, 0.2, 0.2)
		elif hp_pct < 0.66: hp_bar.color = Color(0.95, 0.75, 0.15)
		else: hp_bar.color = Color(0.25, 0.85, 0.3)
		if bool(u2["dead"]):
			node.color = Color(0.3, 0.3, 0.3)
			node.modulate = Color(1, 1, 1, 0.5)

	# Log (last 5 lines)
	var log_lbl: Label = $HUD/LogLabel
	var tail: Array = _log_lines.slice(max(0, _log_lines.size() - 5))
	log_lbl.text = "\n".join(tail)

# ─── Input ──────────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if _battle_over: return
	if _turn_side != 0: return  # player turn only
	if not (event is InputEventMouseButton): return
	var mb: InputEventMouseButton = event
	if mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed: return
	var coord: Vector2i = _screen_to_grid(mb.position)
	if coord.x < 0: return
	_handle_click(coord)

func _screen_to_grid(pos: Vector2) -> Vector2i:
	var gx: int = int(pos.x / TILE_SIZE)
	var gy: int = int(pos.y / TILE_SIZE)
	if gx < 0 or gx >= GRID_W or gy < 0 or gy >= GRID_H:
		return Vector2i(-1, -1)
	return Vector2i(gx, gy)

func _handle_click(coord: Vector2i) -> void:
	var unit_at: Variant = _unit_at(coord)
	match _state:
		0:  # OBSERVATION — clicking own unit selects it
			if unit_at != null and int(unit_at["side"]) == 0 and not bool(unit_at["dead"]):
				_select_unit(String(unit_at["id"]))
		1:  # UNIT_SELECTED — click selected unit again to deselect; click target to act
			if unit_at != null and String(unit_at["id"]) == _selected_unit_id:
				_deselect()
				return
			# Attack takes priority over move (red highlight)
			if unit_at != null and int(unit_at["side"]) == 1 and not bool(unit_at["dead"]) and coord in _attack_targets:
				_do_attack(_get_unit(_selected_unit_id), unit_at)
				_end_player_action()
				return
			# Move (yellow-highlighted empty tile)
			if unit_at == null and coord in _move_targets:
				_do_move(_get_unit(_selected_unit_id), coord)
				_end_player_action()
				return

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

func _compute_move_targets(u: Dictionary) -> void:
	_move_targets.clear()
	var ux: int = int(u["x"])
	var uy: int = int(u["y"])
	var rng: int = int(u["move"])
	for y in GRID_H:
		for x in GRID_W:
			if x == ux and y == uy: continue
			if _unit_at(Vector2i(x, y)) != null: continue
			# Manhattan distance (no terrain cost in prototype)
			var d: int = absi(x - ux) + absi(y - uy)
			if d <= rng:
				# Skip rivers as impassable
				if TERRAIN_MAP[y * GRID_W + x] == TERRAIN_RIVER: continue
				_move_targets.append(Vector2i(x, y))

func _compute_attack_targets(u: Dictionary) -> void:
	_attack_targets.clear()
	for other: Dictionary in _units:
		if int(other["side"]) == int(u["side"]) or bool(other["dead"]): continue
		var d: int = absi(int(other["x"]) - int(u["x"])) + absi(int(other["y"]) - int(u["y"]))
		if d == 1:  # melee adjacency only in prototype
			_attack_targets.append(Vector2i(int(other["x"]), int(other["y"])))

func _apply_highlights() -> void:
	for rect: ColorRect in _grid_nodes:
		var c: Vector2i = rect.get_meta("coord")
		var t: int = rect.get_meta("terrain")
		if c in _attack_targets:
			rect.color = Color(0.95, 0.25, 0.25)  # red — attack target
		elif c in _move_targets:
			rect.color = _terrain_color(t).lightened(0.35)  # bright tint — movable
		else:
			rect.color = _terrain_color(t)

func _clear_highlights() -> void:
	for rect: ColorRect in _grid_nodes:
		rect.color = _terrain_color(rect.get_meta("terrain"))

# ─── Queries ────────────────────────────────────────────────────────────────

func _unit_at(coord: Vector2i) -> Variant:
	for u: Dictionary in _units:
		if bool(u["dead"]): continue
		if int(u["x"]) == coord.x and int(u["y"]) == coord.y:
			return u
	return null

func _get_unit(id: String) -> Dictionary:
	for u: Dictionary in _units:
		if String(u["id"]) == id:
			return u
	return {}

# ─── Actions ────────────────────────────────────────────────────────────────

func _do_move(u: Dictionary, dest: Vector2i) -> void:
	u["x"] = dest.x
	u["y"] = dest.y
	var node: ColorRect = _unit_nodes[String(u["id"])]
	# Tween for visible feedback
	var tw: Tween = create_tween()
	tw.tween_property(node, "position", Vector2(dest.x * TILE_SIZE + 4, dest.y * TILE_SIZE + 4), 0.18).set_trans(Tween.TRANS_QUAD)
	_log("%s moved to (%d,%d)" % [u["name"], dest.x, dest.y])

func _do_attack(attacker: Dictionary, defender: Dictionary) -> void:
	var t: int = TERRAIN_MAP[int(defender["y"]) * GRID_W + int(defender["x"])]
	var def_bonus: int = _terrain_def_bonus(t)
	# Damage formula (simplified from ADR-0012):
	#   dmg = max(1, ATK - DEF - terrain_def_bonus)
	var dmg: int = maxi(1, int(attacker["atk"]) - int(defender["def"]) - def_bonus)
	defender["hp_current"] = maxi(0, int(defender["hp_current"]) - dmg)

	_log("⚔ %s → %s : %d dmg (DEF %d + terrain %d)" % [
		String(attacker["name"]).split(" ")[0],
		String(defender["name"]).split(" ")[0],
		dmg, defender["def"], def_bonus,
	])

	# Flash defender
	var node: ColorRect = _unit_nodes[String(defender["id"])]
	var orig: Color = node.color
	var flash_tw: Tween = create_tween()
	flash_tw.tween_property(node, "color", Color.WHITE, 0.05)
	flash_tw.tween_property(node, "color", orig, 0.15)

	if int(defender["hp_current"]) <= 0:
		defender["dead"] = true
		_log("💀 %s defeated" % String(defender["name"]).split(" ")[0])

# ─── Turn flow ──────────────────────────────────────────────────────────────

func _end_player_action() -> void:
	_state = 0
	_selected_unit_id = ""
	_move_targets.clear()
	_attack_targets.clear()
	_clear_highlights()
	_refresh_hud()
	if _check_victory(): return
	# Hand to AI
	_turn_side = 1
	_refresh_hud()
	await get_tree().create_timer(0.5).timeout
	await _ai_turn()

func _ai_turn() -> void:
	# Each living enemy unit takes one action (move-toward-nearest-player + attack-if-adjacent)
	for ai: Dictionary in _units:
		if int(ai["side"]) != 1 or bool(ai["dead"]): continue
		await _ai_act(ai)
		if _check_victory(): return
		await get_tree().create_timer(0.3).timeout
	# Back to player
	_turn_side = 0
	_turn_count += 1
	_log("— Turn %d — Player" % _turn_count)
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

	# If already adjacent → attack
	if min_d == 1:
		_do_attack(ai, target)
		_refresh_hud()
		return

	# Otherwise: greedy step toward target up to ai.move tiles
	var moves_left: int = int(ai["move"])
	while moves_left > 0:
		var tx: int = int(target["x"])
		var ty: int = int(target["y"])
		if absi(tx - int(ai["x"])) <= 1 and absi(ty - int(ai["y"])) <= 1 and (absi(tx - int(ai["x"])) + absi(ty - int(ai["y"])) == 1):
			break  # adjacent now — stop and attack
		var step: Vector2i = Vector2i(int(ai["x"]), int(ai["y"]))
		# Move along the longer axis first
		if absi(tx - int(ai["x"])) >= absi(ty - int(ai["y"])) and tx != int(ai["x"]):
			step.x += signi(tx - int(ai["x"]))
		elif ty != int(ai["y"]):
			step.y += signi(ty - int(ai["y"]))
		else:
			break
		# Validate
		if step.x < 0 or step.x >= GRID_W or step.y < 0 or step.y >= GRID_H: break
		if _unit_at(step) != null: break
		if TERRAIN_MAP[step.y * GRID_W + step.x] == TERRAIN_RIVER: break
		ai["x"] = step.x
		ai["y"] = step.y
		var node: ColorRect = _unit_nodes[String(ai["id"])]
		var tw: Tween = create_tween()
		tw.tween_property(node, "position", Vector2(step.x * TILE_SIZE + 4, step.y * TILE_SIZE + 4), 0.18)
		_log("%s moved to (%d,%d)" % [String(ai["name"]).split(" ")[0], step.x, step.y])
		moves_left -= 1
		await get_tree().create_timer(0.20).timeout

	# Attack if now adjacent
	var final_d: int = absi(int(target["x"]) - int(ai["x"])) + absi(int(target["y"]) - int(ai["y"]))
	if final_d == 1:
		await get_tree().create_timer(0.15).timeout
		_do_attack(ai, target)
	_refresh_hud()

# ─── Victory check ───────────────────────────────────────────────────────────

func _check_victory() -> bool:
	var player_alive: bool = false
	var enemy_alive: bool = false
	for u: Dictionary in _units:
		if bool(u["dead"]): continue
		if int(u["side"]) == 0: player_alive = true
		else: enemy_alive = true
	if not player_alive:
		_finish_battle("DEFEAT", Color(1.0, 0.3, 0.3))
		return true
	if not enemy_alive:
		_finish_battle("VICTORY", Color(1.0, 0.85, 0.2))
		return true
	return false

func _finish_battle(text: String, color: Color) -> void:
	_battle_over = true
	var win_lbl: Label = $HUD/WinLabel
	win_lbl.text = text
	win_lbl.add_theme_color_override("font_color", color)
	win_lbl.visible = true
	_log("=== %s ===" % text)
	_refresh_hud()

# ─── Logging helper ─────────────────────────────────────────────────────────

func _log(msg: String) -> void:
	_log_lines.append(msg)
	print("[BATTLE] " + msg)
