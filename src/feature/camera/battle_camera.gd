## BattleCamera — battle-scoped Camera2D providing zoom + pan + screen→grid hit-testing.
##
## Per ADR-0013 §1: 3rd invocation of battle-scoped Node pattern (after ADR-0010
## HPStatusController + ADR-0011 TurnOrderRunner). Class name `BattleCamera`
## (NOT `Camera`) avoids G-12 ClassDB collision with Godot 4.6 built-in Camera
## base class (parent of Camera2D + Camera3D).
##
## DI seam: BattleScene MUST call `setup(map_grid)` BEFORE `add_child()`. The
## `_ready()` body asserts `_map_grid != null`; without setup, the scene fails
## fast at mount time per ADR-0013 §5 + R-2 mitigation.
##
## Lifecycle: instantiated when BattleScene loads; freed when BattleScene exits.
## MANDATORY `_exit_tree()` body explicitly disconnects `GameBus.input_action_fired`
## per ADR-0013 §5 + R-6 (godot-specialist 2026-05-02 review concern #2 —
## without disconnect, autoload retains callable pointing at freed Node = leak +
## potential crash on next emit).
##
## NOTE: GameBus.input_action_fired signal signature uses `String` (per ADR-0001
## line 168 — `signal input_action_fired(action: String, context: InputContext)`)
## even though ADR-0005 + ADR-0013 sketches use `StringName`. The carried
## advisory for ADR-0001 §168 amendment (delta #6 Item 10a) is not yet applied;
## production code uses `String` consistently with the live signal signature.
##
## NOTE: InputContext fields are `target_coord` / `target_unit_id` / `source_device`
## per src/core/payloads/input_context.gd (NOT `coord` / `unit_id` per ADR
## sketches). Production code uses the SHIPPED field names.

class_name BattleCamera
extends Camera2D


# ─── Instance state (4 fields per ADR-0013 §7) ──────────────────────────────

var _map_grid: MapGrid = null
var _drag_active: bool = false
var _drag_start_screen_pos: Vector2 = Vector2.ZERO
var _drag_start_camera_pos: Vector2 = Vector2.ZERO


# ─── DI seam (BattleScene calls before add_child per ADR-0013 §5) ───────────

func setup(map_grid: MapGrid) -> void:
	_map_grid = map_grid


# ─── Lifecycle ──────────────────────────────────────────────────────────────

func _ready() -> void:
	# DI guard — fail fast if BattleScene forgot setup() per ADR-0013 R-2 mitigation
	assert(_map_grid != null, "BattleCamera.setup(map_grid) must be called before adding to scene tree")
	make_current()
	# Initialize zoom from BalanceConstants per forbidden_pattern hardcoded_zoom_literals
	var default_zoom: float = float(BalanceConstants.get_const("CAMERA_ZOOM_DEFAULT"))
	zoom = Vector2(default_zoom, default_zoom)
	# Subscribe to GameBus.input_action_fired with CONNECT_DEFERRED per ADR-0001 §5
	GameBus.input_action_fired.connect(_on_input_action_fired, Object.CONNECT_DEFERRED)
	_apply_pan_clamp()


func _exit_tree() -> void:
	# MANDATORY explicit disconnect per ADR-0013 R-6 + camera_missing_exit_tree_disconnect
	# forbidden_pattern (godot-specialist 2026-05-02 review concern #2). GameBus is
	# autoload — it outlives BattleCamera; without this disconnect, the autoload
	# retains a callable pointing at the freed Camera Node = leak + crash on next emit.
	if GameBus.input_action_fired.is_connected(_on_input_action_fired):
		GameBus.input_action_fired.disconnect(_on_input_action_fired)


# ─── Public API: cross-system contract surface (ADR-0013 §7) ────────────────

## Convert screen-space pixel coords to grid coords. Returns Vector2i(-1, -1) for
## off-grid (out of map bounds). SOLE implementation per forbidden_pattern
## external_screen_to_grid_implementation. Consumed by Grid Battle Controller
## (ADR-0014) for click hit-testing per input-handling §9 Bidirectional Contract.
func screen_to_grid(screen_pos: Vector2) -> Vector2i:
	# Convert screen → world via canvas transform's affine inverse (Godot 4.6 idiom)
	var world_pos: Vector2 = get_canvas_transform().affine_inverse() * screen_pos
	var tile_size: int = int(BalanceConstants.get_const("TILE_WORLD_SIZE"))
	var grid_x: int = int(world_pos.x / tile_size)
	var grid_y: int = int(world_pos.y / tile_size)
	var map_dims: Vector2i = _map_grid.get_map_dimensions()
	if grid_x < 0 or grid_x >= map_dims.x or grid_y < 0 or grid_y >= map_dims.y:
		return Vector2i(-1, -1)
	return Vector2i(grid_x, grid_y)


## Read-only zoom query for HUD scale-matching by Battle HUD (sprint-5 ADR pending).
func get_zoom_value() -> float:
	return zoom.x


# ─── Signal handler ─────────────────────────────────────────────────────────

func _on_input_action_fired(action: String, _ctx: InputContext) -> void:
	# Filter: only camera-domain actions; everything else silently ignored.
	# Camera owns drag state per ADR-0005 OQ-2 resolution: &"camera_pan" is a
	# TRIGGER (player wants to pan), not a delta source. Camera reads viewport
	# mouse position itself for delta computation.
	match action:
		"camera_pan":
			_handle_camera_pan()
		"camera_zoom_in":
			_apply_zoom_delta(float(BalanceConstants.get_const("CAMERA_ZOOM_STEP")), get_viewport().get_mouse_position())
		"camera_zoom_out":
			_apply_zoom_delta(-float(BalanceConstants.get_const("CAMERA_ZOOM_STEP")), get_viewport().get_mouse_position())
		_:
			# Not a camera action — silently ignore (forbidden_pattern compliance:
			# Camera does NOT respond to non-camera actions)
			return


# ─── Pan logic (Camera owns drag state per ADR-0005 OQ-2) ───────────────────

func _handle_camera_pan() -> void:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	if not _drag_active:
		# First pan event since drag-start — anchor capture (R-5 mitigation:
		# touch event ordering means first event includes existing travel)
		_drag_active = true
		_drag_start_screen_pos = mouse_pos
		_drag_start_camera_pos = position
		return
	# Subsequent pan events: compute delta from anchor
	var screen_delta: Vector2 = mouse_pos - _drag_start_screen_pos
	# Convert screen delta to world delta via zoom inverse (zoom 2.0 = world delta is 0.5x screen)
	var world_delta: Vector2 = screen_delta / zoom.x
	position = _drag_start_camera_pos - world_delta
	_apply_pan_clamp()


## Reset drag state — public for tests + BattleScene to call on drag-end.
func end_drag() -> void:
	_drag_active = false


# ─── Zoom logic (cursor-stable per ADR-0013 §2) ─────────────────────────────

func _apply_zoom_delta(delta: float, cursor_screen_pos: Vector2) -> void:
	var zoom_min: float = float(BalanceConstants.get_const("CAMERA_ZOOM_MIN"))
	var zoom_max: float = float(BalanceConstants.get_const("CAMERA_ZOOM_MAX"))
	var old_zoom: float = zoom.x
	var new_zoom: float = clampf(old_zoom + delta, zoom_min, zoom_max)
	if is_equal_approx(new_zoom, old_zoom):
		return  # No change (clamped at floor or ceiling) — early return per R-4
	# Cursor-stable zoom recipe: preserve cursor's world position across zoom delta
	var cursor_world_before: Vector2 = get_canvas_transform().affine_inverse() * cursor_screen_pos
	zoom = Vector2(new_zoom, new_zoom)
	var cursor_world_after: Vector2 = get_canvas_transform().affine_inverse() * cursor_screen_pos
	position += cursor_world_before - cursor_world_after
	_apply_pan_clamp()  # zoom may invalidate prior clamp; re-enforce


# ─── Pan clamp (keep map visible per R-4) ───────────────────────────────────

func _apply_pan_clamp() -> void:
	var map_dims: Vector2i = _map_grid.get_map_dimensions()
	var tile_size: float = float(BalanceConstants.get_const("TILE_WORLD_SIZE"))
	var map_world_size: Vector2 = Vector2(map_dims.x, map_dims.y) * tile_size
	var viewport_size: Vector2 = get_viewport_rect().size / zoom.x
	var half_view: Vector2 = viewport_size * 0.5
	# X axis
	if map_world_size.x <= viewport_size.x:
		position.x = map_world_size.x * 0.5  # center map on screen
	else:
		position.x = clampf(position.x, half_view.x, map_world_size.x - half_view.x)
	# Y axis
	if map_world_size.y <= viewport_size.y:
		position.y = map_world_size.y * 0.5
	else:
		position.y = clampf(position.y, half_view.y, map_world_size.y - half_view.y)
