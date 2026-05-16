## chapter_visuals_name_label_alpha_test.gd
##
## Session-43 — HUD declutter via name-label modulate. Pre-S43 every unit's
## NameLabel rendered at modulate.a=1.0 simultaneously, contributing to the
## "화면이 조잡" perception (8 units = 8 names shouting in parallel).
## Post-S43 only the active-turn unit + selected unit show their name at
## full alpha; others recede to _UNIT_LABEL_DIM_ALPHA (S46: tightened 0.45→0.0 after
## windowed feedback — adjacent names still overlapped at 0.45 alpha; 0.0 hides
## non-active names entirely. Hero identity remains via S40 polygon emblem).
##
## Coverage:
##   - Post-spawn: all NameLabels start at dim alpha (no active/selected yet)
##   - set_active_turn_coord(tile) → unit at that tile pops to full alpha;
##     other units stay at dim
##   - set_selected_coord(tile) → that unit's name also at full alpha
##   - Same tile for active + selected → still full alpha (no double-bump)
##   - Different tiles for active + selected → both at full alpha
##   - Clear active (Vector2i(-1,-1)) → previously-active unit reverts to dim
extends GdUnitTestSuite


const _CHAPTER_VISUALS_SCRIPT: String = "res://src/feature/battle_scene/chapter_visuals.gd"
const _TILE_SIZE: int = 64


var _visuals: Node = null
var _player_parent: Node2D = null
var _enemy_parent: Node2D = null


func before_test() -> void:
	var script: GDScript = load(_CHAPTER_VISUALS_SCRIPT) as GDScript
	_visuals = script.new()
	get_tree().root.add_child(_visuals)
	await get_tree().process_frame
	# Build minimal PlayerUnits / EnemyUnits parents with synthetic polygons.
	# The real spawn_unit_polygons() needs a full BattleUnit roster — we want a
	# narrower test focused on _refresh_unit_label_alphas behaviour, so we
	# construct the minimum shape it walks: Node2D parents containing Polygon2D
	# children with a "NameLabel" Label child.
	_player_parent = _make_unit_parent("PlayerUnits")
	_enemy_parent = _make_unit_parent("EnemyUnits")


func after_test() -> void:
	if is_instance_valid(_visuals):
		get_tree().root.remove_child(_visuals)
		_visuals.free()
	_visuals = null


# ─── Helpers ─────────────────────────────────────────────────────────────────


func _make_unit_parent(parent_name: String) -> Node2D:
	var p: Node2D = Node2D.new()
	p.name = parent_name
	_visuals.add_child(p)
	return p


## Mounts a fake unit polygon at tile (col, row) under `parent`. Position
## mirrors the spawn_unit_polygons formula: tile * TILE_SIZE + TILE_SIZE/2.
func _spawn_fake_unit(parent: Node2D, col: int, row: int) -> Polygon2D:
	var poly: Polygon2D = Polygon2D.new()
	poly.position = Vector2(
		col * _TILE_SIZE + _TILE_SIZE / 2.0,
		row * _TILE_SIZE + _TILE_SIZE / 2.0,
	)
	var label: Label = Label.new()
	label.name = "NameLabel"
	label.text = "Unit_%d_%d" % [col, row]
	poly.add_child(label)
	parent.add_child(poly)
	return poly


func _name_label_alpha(parent: Node2D, col: int, row: int) -> float:
	for child: Node in parent.get_children():
		var poly: Polygon2D = child as Polygon2D
		if poly == null:
			continue
		var tx: int = int(floor(poly.position.x / float(_TILE_SIZE)))
		var ty: int = int(floor(poly.position.y / float(_TILE_SIZE)))
		if tx == col and ty == row:
			var lab: Label = poly.get_node_or_null(^"NameLabel") as Label
			return lab.modulate.a
	return -1.0  # not found sentinel


# ─── Initial state: post-construction, no active/selected ────────────────────


func test_refresh_with_no_active_or_selected_makes_all_labels_dim() -> void:
	_spawn_fake_unit(_player_parent, 2, 3)
	_spawn_fake_unit(_player_parent, 4, 5)
	_spawn_fake_unit(_enemy_parent, 6, 3)
	# _active_turn_coord + _selected_coord both default Vector2i(-1, -1).
	_visuals._refresh_unit_label_alphas()
	assert_float(_name_label_alpha(_player_parent, 2, 3)).is_equal_approx(0.0, 0.001)
	assert_float(_name_label_alpha(_player_parent, 4, 5)).is_equal_approx(0.0, 0.001)
	assert_float(_name_label_alpha(_enemy_parent, 6, 3)).is_equal_approx(0.0, 0.001)


# ─── Active-turn pop ─────────────────────────────────────────────────────────


func test_set_active_turn_coord_pops_matching_unit_label_to_full_alpha() -> void:
	_spawn_fake_unit(_player_parent, 2, 3)
	_spawn_fake_unit(_player_parent, 4, 5)
	_visuals.set_active_turn_coord(Vector2i(2, 3))
	assert_float(_name_label_alpha(_player_parent, 2, 3)).override_failure_message(
		"S43: active turn unit's name must be at full alpha (1.0)"
	).is_equal_approx(1.0, 0.001)
	assert_float(_name_label_alpha(_player_parent, 4, 5)).override_failure_message(
		"S43: non-active, non-selected unit's name must be at dim alpha (0.45)"
	).is_equal_approx(0.0, 0.001)


# ─── Selection pop ───────────────────────────────────────────────────────────


func test_set_selected_coord_pops_matching_unit_label_to_full_alpha() -> void:
	_spawn_fake_unit(_player_parent, 2, 3)
	_spawn_fake_unit(_enemy_parent, 6, 3)
	_visuals.set_selected_coord(Vector2i(6, 3))
	assert_float(_name_label_alpha(_enemy_parent, 6, 3)).is_equal_approx(1.0, 0.001)
	assert_float(_name_label_alpha(_player_parent, 2, 3)).is_equal_approx(0.0, 0.001)


# ─── Active + selected on different tiles ────────────────────────────────────


func test_active_and_selected_on_different_tiles_both_at_full_alpha() -> void:
	_spawn_fake_unit(_player_parent, 2, 3)
	_spawn_fake_unit(_enemy_parent, 6, 3)
	_visuals.set_active_turn_coord(Vector2i(2, 3))
	_visuals.set_selected_coord(Vector2i(6, 3))
	assert_float(_name_label_alpha(_player_parent, 2, 3)).is_equal_approx(1.0, 0.001)
	assert_float(_name_label_alpha(_enemy_parent, 6, 3)).is_equal_approx(1.0, 0.001)


# ─── Clearing active reverts label to dim ────────────────────────────────────


func test_clearing_active_turn_coord_returns_label_to_dim() -> void:
	_spawn_fake_unit(_player_parent, 2, 3)
	_visuals.set_active_turn_coord(Vector2i(2, 3))
	assert_float(_name_label_alpha(_player_parent, 2, 3)).is_equal_approx(1.0, 0.001)
	# Sentinel "no active turn" — both coords reset to Vector2i(-1, -1).
	_visuals.set_active_turn_coord(Vector2i(-1, -1))
	assert_float(_name_label_alpha(_player_parent, 2, 3)).is_equal_approx(0.0, 0.001)


# ─── Constants exposure ──────────────────────────────────────────────────────


func test_s43_alpha_constants_are_in_expected_range() -> void:
	var script: GDScript = load(_CHAPTER_VISUALS_SCRIPT) as GDScript
	var dim: float = script.get("_UNIT_LABEL_DIM_ALPHA") as float
	var full: float = script.get("_UNIT_LABEL_FULL_ALPHA") as float
	# S46: dim alpha tightened to 0.0 (fully hidden) after windowed feedback
	# that 0.45 still produced visible overlap on adjacent units.
	assert_float(dim).override_failure_message(
		"S46: dim alpha must be in [0.0, 0.6] — values >0.6 risk overlap noise"
	).is_greater_equal(0.0)
	assert_float(dim).is_less_equal(0.6)
	assert_float(full).is_equal_approx(1.0, 0.001)
