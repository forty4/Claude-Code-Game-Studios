## CivilianTokensVisuals — battle-scoped Node2D rendering the ADR-0022
## civilian token collection at chapter-grid space. Mounted as a child of
## ChapterVisuals so transform inheritance gives free grid-space placement.
##
## ADR-0022 §5 + R-4 — polling renderer that reads GridBattleController via
## `get_civilian_tokens()` snapshot. Does NOT mutate civilian state. Refresh
## is driven by BattleScene lifecycle hooks (`_on_unit_turn_ended_visual`,
## `_on_unit_died_visual`) — the only events where civilian state can change.
##
## State visuals (spec §4.3):
##   IDLE     — gray humanoid polygon at grid_cell (default visible after spawn)
##   ESCORTED — token polygon hidden; carrier shows EscortMarker overlay
##              (delegated to ChapterVisuals.set_carrier_escort_overlay)
##   SAVED    — fade despawn over FADE_DURATION (G-31 tree-bound tween +
##              SceneTreeTimer failsafe per BattleScene's death-fade pattern)
class_name CivilianTokensVisuals
extends Node2D

const TILE_SIZE: int = 64  # mirrors ChapterVisuals.TILE_SIZE
const COLOR_IDLE: Color = Color(0.65, 0.65, 0.60, 0.95)  # neutral civilian gray
const COLOR_OUTLINE: Color = Color(0.20, 0.20, 0.20, 1.0)
const FADE_DURATION: float = 0.3

var _controller: Node = null
var _chapter_visuals: Node = null
## token_id -> Polygon2D child node
var _polygons_by_id: Dictionary = {}
## token_id -> last-observed state (int from CivilianToken.State enum)
var _cached_state: Dictionary = {}
## Set of carrier_unit_ids currently showing the EscortMarker overlay.
## Used to diff against the next snapshot so we can clear stale overlays
## (token transitioned ESCORTED -> SAVED or ESCORTED -> IDLE).
var _prev_escort_carriers: Dictionary = {}


## DI surface — BattleScene provides the controller for snapshot polling and
## the ChapterVisuals reference for carrier-overlay delegation.
func set_controller(controller: Node, chapter_visuals: Node) -> void:
	_controller = controller
	_chapter_visuals = chapter_visuals
	refresh()


## Polls controller snapshot + reconciles polygon children + carrier overlays.
## Idempotent — calling without state change is a cheap no-op (cached diff).
func refresh() -> void:
	if _controller == null:
		return
	if not _controller.has_method("get_civilian_tokens"):
		return
	var snapshot: Array[CivilianToken] = _controller.get_civilian_tokens()

	# Spawn polygons for any tokens we haven't seen yet (first-refresh path).
	for t: CivilianToken in snapshot:
		if not _polygons_by_id.has(t.token_id):
			_spawn_token_polygon(t)

	# Reconcile per-token state transitions + collect current escort carriers.
	var current_carriers: Dictionary = {}
	for t: CivilianToken in snapshot:
		var prev: int = _cached_state.get(t.token_id, -1) as int
		var curr: int = t.state as int
		if prev != curr:
			_cached_state[t.token_id] = curr
			_on_token_state_changed(t, curr)
		# After recovery the token is IDLE at a new cell — keep its polygon
		# position synced even when state didn't change.
		if curr == CivilianToken.State.IDLE as int:
			var poly: Polygon2D = _polygons_by_id.get(t.token_id, null)
			if poly != null:
				poly.position = _cell_to_world(t.grid_cell)
		elif curr == CivilianToken.State.ESCORTED as int:
			current_carriers[t.carrier_unit_id] = true

	# Diff escort carriers — enable overlay for new escorts, clear stale ones.
	for carrier_id: int in current_carriers:
		if not _prev_escort_carriers.has(carrier_id):
			_set_carrier_overlay(carrier_id, true)
	for carrier_id: int in _prev_escort_carriers:
		if not current_carriers.has(carrier_id):
			_set_carrier_overlay(carrier_id, false)
	_prev_escort_carriers = current_carriers


func _spawn_token_polygon(t: CivilianToken) -> void:
	var poly: Polygon2D = Polygon2D.new()
	poly.name = "Civilian_" + str(t.token_id)
	poly.polygon = _make_civilian_shape()
	poly.color = COLOR_IDLE
	poly.position = _cell_to_world(t.grid_cell)
	add_child(poly)
	_polygons_by_id[t.token_id] = poly
	_cached_state[t.token_id] = t.state as int


func _on_token_state_changed(t: CivilianToken, curr: int) -> void:
	var poly: Polygon2D = _polygons_by_id.get(t.token_id, null)
	if poly == null:
		return
	if curr == CivilianToken.State.ESCORTED as int:
		# Carrier's EscortMarker takes over — hide standalone token polygon.
		poly.visible = false
	elif curr == CivilianToken.State.IDLE as int:
		# Recovered from carrier death — reposition at recovery cell + show.
		poly.position = _cell_to_world(t.grid_cell)
		poly.visible = true
		poly.modulate.a = 1.0
	elif curr == CivilianToken.State.SAVED as int:
		# Fade despawn — tree-bound tween (G-31: BattleScene runs under
		# PROCESS_MODE_DISABLED, so self.create_tween would stall).
		poly.visible = true
		var tween: Tween = get_tree().create_tween()
		tween.tween_property(poly, "modulate:a", 0.0, FADE_DURATION) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# Failsafe — ensure final alpha + invisible even if tween stalls.
		get_tree().create_timer(FADE_DURATION + 0.05).timeout.connect(func() -> void:
			if is_instance_valid(poly):
				poly.modulate.a = 0.0
				poly.visible = false)


func _set_carrier_overlay(carrier_unit_id: int, active: bool) -> void:
	if _chapter_visuals == null:
		return
	if not _chapter_visuals.has_method("set_carrier_escort_overlay"):
		return
	_chapter_visuals.set_carrier_escort_overlay(carrier_unit_id, active)


func _cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(
		cell.x * TILE_SIZE + TILE_SIZE / 2.0,
		cell.y * TILE_SIZE + TILE_SIZE / 2.0,
	)


## Simple humanoid silhouette (~24px tall) — gray figure per spec OQ-4.
## Asset replacement (chibi sprite) is deferred per branch-distribution-plan.md
## §9 Asset Pipeline notes.
func _make_civilian_shape() -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-6, -12),
		Vector2(0, -16),
		Vector2(6, -12),
		Vector2(8, 12),
		Vector2(-8, 12),
	])
