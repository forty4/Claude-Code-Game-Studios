# ADR-0013: Camera — Battle-Scoped `BattleCamera` (Camera2D) + Zoom + Pan + screen_to_grid

## Status
Accepted (2026-05-02 — lean mode authoring + godot-specialist CONCERNS resolved per §Risks R-6/R-7 + §1 BattleCamera rename + §5 explicit `_exit_tree()` cleanup; TD-ADR PHASE-GATE skipped per `production/review-mode.txt`)

## Date
2026-05-02

## Last Verified
2026-05-02

## Decision Makers
- claude (lean mode authoring; no PHASE-GATE TD-ADR per `production/review-mode.txt`)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Rendering / Input (Camera2D + InputEventMouseButton + DisplayServer.window_get_size) |
| **Knowledge Risk** | **LOW** — `Camera2D` (`enabled`, `zoom`, `position`, `make_current`, `get_screen_center_position`, `get_canvas_transform`), `InputEventMouseButton.button_index`, `InputEventMouseMotion.relative`, `MOUSE_BUTTON_WHEEL_UP/DOWN/MIDDLE`, `Vector2` math, `Tween` for smooth zoom, signal subscription with `Object.CONNECT_DEFERRED`, `to_local()` / `to_global()`, basic 2D viewport are all pre-Godot-4.4 and stable across the 4.6 baseline. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` (4.6 pin), `docs/engine-reference/godot/breaking-changes.md` (no Camera2D entries — confirmed no post-cutoff Camera2D changes), `docs/engine-reference/godot/deprecated-apis.md` (no Camera2D entries), `docs/engine-reference/godot/modules/rendering.md` (4.6 mobile renderer pin verified), `design/gdd/input-handling.md` (F-1 zoom floor + Bidirectional Contract §9 + camera-action vocabulary CR-1 + EC-9), `design/gdd/map-grid.md` (`get_map_dimensions()` for pan clamp), `docs/architecture/ADR-0001-gamebus-autoload.md` (consumer pattern + Object.CONNECT_DEFERRED mandate), `docs/architecture/ADR-0004-map-grid-data-model.md` (Map/Grid contract), `docs/architecture/ADR-0005-input-handling.md` (5 cross-system provisional contracts incl. Camera), `docs/architecture/ADR-0010-hp-status.md` (battle-scoped Node precedent #1), `docs/architecture/ADR-0011-turn-order.md` (battle-scoped Node precedent #2), `prototypes/chapter-prototype/battle_v2.gd` (fixed-view + click pattern shape — design brief, not refactoring source). |
| **Post-Cutoff APIs Used** | None. Camera2D's `enabled`, `zoom`, `make_current`, `get_screen_center_position` are stable since 4.0. The mouse-cursor-stable zoom recipe (adjust position to keep cursor world-pos invariant across zoom delta) is engine-agnostic vector math. |
| **Verification Required** | (1) `Camera2D.zoom` setter behavior on 4.6 — assert that `set_zoom(Vector2(z, z))` updates the canvas transform within the same frame for the screen_to_grid call to remain correct (verified by chapter-prototype which used direct position math without Camera2D and worked; producing equivalent under Camera2D should be straightforward). (2) `to_local()` correctness across zoom levels — assert `screen_to_grid` returns the same coord whether zoomed in or out by writing 3 fixture tests at `[zoom=0.70, zoom=1.00, zoom=2.00]` × known click position. (3) Pan clamp boundaries on edge cases — assert that with `viewport_size > map_world_size`, the camera centers the map (no clamp at all) rather than pinning to one edge; the standard recipe handles this with `max(0, half_extent)` clamps. KEEP through implementation. |

> **Knowledge Risk Note**: Domain is **LOW** risk. No post-cutoff API surface. Future Godot 4.7+ that touches `Camera2D.zoom` semantics (e.g., changing `zoom` from "world units per screen unit" to "screen units per world unit" — historically a 3.x → 4.0 inversion that confused devs) would trigger Superseded-by review. None projected as of pin date.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0001 GameBus** (Accepted 2026-04-18) — Camera is a pure consumer of `input_action_fired(action: StringName, ctx: InputContext)` filtered for `ACTIONS_BY_CATEGORY[&"camera"]` 4 actions; subscription via `Object.CONNECT_DEFERRED` per ADR-0001 §5 mandate; Camera does NOT add new signals to ADR-0001 §7 schema for MVP. **ADR-0004 Map/Grid** (Accepted 2026-04-20) — Camera consumes `MapGrid.get_map_dimensions() -> Vector2i` for pan-clamp world-extent computation. **ADR-0005 Input Handling** (Accepted 2026-04-30) — Camera honors the 5 cross-system provisional contracts §9 commit verbatim: `Camera.screen_to_grid(screen_pos: Vector2) -> Vector2i` + Camera owns drag state (OQ-2 resolution — InputRouter does NOT gate grid input mid-drag) + `camera_zoom_min = 0.70` enforcement (F-1). |
| **Enables** | (1) **ADR-0014 Grid Battle Controller** (Accepted 2026-05-02 — RATIFIED parameter-stable per delta #10 backfill) — consumes `Camera.screen_to_grid` for unit-tap hit-testing; `world_to_screen` derivation uses `get_canvas_transform() * world_pos` directly (no separate `world_to_screen()` method on Godot 4.6 `Camera2D` per delta #10 godot-specialist advisory D). (2) **Battle Scene wiring** (sprint-6) — first scene that includes a real Camera2D + Grid Battle Controller + 11 backend epics integrated. (3) **ADR-0015 Battle HUD** (Accepted 2026-05-03 via /architecture-review delta #10) — consumes `BattleCamera.get_zoom_value() -> float` for HUD scale-with-camera (UI-GB-12/13/14 grid-layer overlays counter-scale per ADR-0015 §6 `_process` poll gated on `_has_active_grid_overlay()`). |
| **Blocks** | camera Foundation/Feature epic creation (cannot start any story until this ADR is Accepted); `assets/data/camera/camera_defaults.json` (NOT YET AUTHORED — single-file config for default zoom + clamp behavior, pending camera epic story-001). |
| **Ordering Note** | First Feature-layer Node-based system. Joins the **2-precedent battle-scoped Node lineage** (ADR-0010 HPStatusController + ADR-0011 TurnOrderRunner) as the **3rd invocation** of the pattern. Distinct from ADR-0005 InputRouter's autoload-Node form because Camera state is battle-bounded (overworld + main menu have no Camera consumer; battle-scene-end frees the Camera with the rest of the BattleScene). **ADR-0015 Battle HUD (Accepted 2026-05-03 via /architecture-review delta #10)** followed this same battle-scoped Node form (5th invocation) for the same lifecycle reason. |

## Context

### Problem Statement

Sprint-3 closed with **11 backend epics Complete and zero playable surface** (`src/ui/` empty, no Camera, no `main_scene` in project.godot). Two prototype iterations (`prototypes/vertical-slice/` + `prototypes/chapter-prototype/`) confirmed the backend math but used wireframe ColorRect + fixed-view click handling — neither evaluable by an SRPG-experienced user (per the post-prototype playtest). Sprint-4 begins the MVP First Chapter (3-sprint arc to ship the 장판파 chapter as a playable surface).

The first production decision is **how to render the battle grid at appropriate scale and provide click-to-grid hit-testing**. Specifically:

1. **Storage form** — Camera2D Node? Static utility class with manual transform math? Autoload? The 5-precedent stateless-static pattern (ADR-0006/0007/0008/0009/0012) is for *calculator* systems with no lifecycle; Camera has signal subscriptions and per-frame mutable state (zoom + position) so it must be a Node. The 2-precedent battle-scoped Node pattern (ADR-0010 HPStatusController + ADR-0011 TurnOrderRunner) is the obvious fit.

2. **Zoom range and floor** — input-handling F-1 mandates `camera_zoom_min = 0.70` (44px touch target floor / 64px tile_world_size = 0.6875 → rounded up). Maximum zoom for PC tactical readability is roughly 2.00 (tile = 128px on screen). The default zoom for "normal play" is 1.00 (tile = 64px native).

3. **Pan model** — input-handling CR-4f defines pan-vs-tap via F-3 (`PAN_ACTIVATION_PX = 16`). Camera owns the drag state per OQ-2 resolution; InputRouter forwards `&"camera_pan"` action with `ctx` containing the drag delta, and Camera applies it. No edge-clamp would let the player pan into infinite empty space; with clamp, the player cannot lose the map. Clamp via `MapGrid.get_map_dimensions()`.

4. **Zoom origin** — naive `set_zoom(new_zoom)` zooms toward the camera's world position (typically the screen center). The standard "zoom toward cursor" recipe (adjust camera position by the world-space delta of the cursor before/after zoom) keeps the cursor over the same world point — much better feel for tactical play. Engine-agnostic vector math; no API risk.

5. **screen_to_grid contract** — the cross-system contract from input-handling §9 fixes the signature. Camera consumes `MapGrid.tile_world_size` (the 64-pixel constant from F-1) and the camera's own canvas transform to convert. Returns `Vector2i(-1, -1)` for off-grid (out of map bounds) — the sentinel for "click missed".

### Constraints

- **Engine version pin**: Godot 4.6. No 4.7+ APIs.
- **F-1 floor**: `camera_zoom_min = 0.70` is locked by ADR-0005 + input-handling GDD; cannot be lowered without violating 44px touch target requirement.
- **Battle-scoped lifecycle**: Camera lives inside BattleScene; freed when battle ends. No autoload survival.
- **Single Camera2D per scene**: Godot 4.6 requires `make_current()` to be called for the scene's primary camera; only one is current per viewport at any time.
- **MVP scope**: no edge-clamp polish (no smooth deceleration on pan, no zoom-out-to-fit-map keystroke, no minimap). Defer to Polish phase.
- **Performance budget**: per-frame Camera update < 0.1ms (negligible for a single Node2D transform).

### Requirements

- **R-1**: Provide `screen_to_grid(screen_pos: Vector2) -> Vector2i` with deterministic conversion across the full zoom range `[0.70, 2.00]`.
- **R-2**: Subscribe to `GameBus.input_action_fired` via `Object.CONNECT_DEFERRED`, filter for the 4 camera-domain actions (`&"camera_pan"`, `&"camera_zoom_in"`, `&"camera_zoom_out"`, `&"camera_snap_to_unit"`), and apply the corresponding camera operation.
- **R-3**: Enforce zoom range `[0.70, 2.00]` via clamp on every zoom mutation. Hardcoded literals must derive from BalanceConstants (`TOUCH_TARGET_MIN_PX / TILE_WORLD_SIZE` for floor; `CAMERA_ZOOM_MAX` constant for ceiling).
- **R-4**: Enforce pan clamp via `MapGrid.get_map_dimensions()` — Camera position bounded so map edges remain visible (with viewport-half offset).
- **R-5**: Zoom-toward-cursor — preserve the cursor's world position across zoom mutations.
- **R-6**: DI test seam — `setup(map_grid: MapGrid) -> void` callable by BattleScene before `_ready()` finishes, allowing tests to inject a stub MapGrid.
- **R-7**: Non-emitter discipline — Camera does NOT emit any GameBus signal in MVP (forbidden_pattern `camera_signal_emission`). ADR-0015 Battle HUD (Accepted 2026-05-03 via delta #10) consumes Camera state via direct method calls (`get_zoom_value()` getter polled per-frame on grid-overlay-active gating per ADR-0015 §6), not via signals — pattern ratified.

## Decision

### 1. Module Form — Battle-scoped Node + Camera2D

```gdscript
class_name BattleCamera extends Camera2D
```

3rd invocation of the battle-scoped Node pattern (after ADR-0010 HPStatusController + ADR-0011 TurnOrderRunner). Lives at `BattleScene/BattleCamera`. Freed with BattleScene exit. Not autoloaded.

**Class name `BattleCamera` (not `Camera`)** — `Camera` is a Godot 4.6 built-in base class (parent of both `Camera2D` and `Camera3D`); declaring `class_name Camera` would trigger G-12 / G-17 ClassDB collision per `.claude/rules/godot-4x-gotchas.md`. The `Battle*` prefix mirrors the project-scope-disambiguation pattern (paralleling potential future `OverworldCamera` or `MenuCamera`).

**Rejected**: stateless-static (no signal subscription possible for an `extends RefCounted` form per ADR-0005 Alternative 4 precedent). Autoload (camera state is battle-scoped, not cross-scene survival).

### 2. Zoom — Range `[0.70, 2.00]`, Default `1.0`, Cursor-Stable

**Constants** (added to `assets/data/balance/balance_entities.json` per ADR-0006 same-patch obligation):
- `CAMERA_ZOOM_MIN = 0.70` — F-1 derived (44 / 64 = 0.6875 → 0.70 with comfort margin); locked by input-handling
- `CAMERA_ZOOM_MAX = 2.00` — PC tactical readability ceiling
- `CAMERA_ZOOM_DEFAULT = 1.00` — tile = 64px native
- `CAMERA_ZOOM_STEP = 0.10` — wheel-zoom delta per `&"camera_zoom_in/out"` event

**Zoom-toward-cursor recipe** (engine-agnostic):

```gdscript
func _apply_zoom_delta(delta: float, cursor_screen_pos: Vector2) -> void:
    var old_zoom: float = zoom.x
    var new_zoom: float = clampf(old_zoom + delta, CAMERA_ZOOM_MIN, CAMERA_ZOOM_MAX)
    if is_equal_approx(new_zoom, old_zoom): return
    var cursor_world_before: Vector2 = get_canvas_transform().affine_inverse() * cursor_screen_pos
    zoom = Vector2(new_zoom, new_zoom)
    var cursor_world_after: Vector2 = get_canvas_transform().affine_inverse() * cursor_screen_pos
    position += cursor_world_before - cursor_world_after
    _apply_pan_clamp()  # zoom may have invalidated clamp; re-enforce
```

Note: the `affine_inverse()` of the canvas transform converts screen → world. Godot 4.6 `Camera2D` updates `get_canvas_transform()` synchronously when `zoom` is mutated.

### 3. Pan — Action-Driven via GameBus + Edge Clamp via Map Dimensions

```gdscript
func _on_input_action_fired(action: StringName, ctx: InputContext) -> void:
    match action:
        &"camera_pan":
            position -= ctx.drag_delta / zoom.x  # ctx.drag_delta in screen pixels; convert to world
            _apply_pan_clamp()
        &"camera_zoom_in":
            _apply_zoom_delta(CAMERA_ZOOM_STEP, ctx.cursor_screen_pos)
        &"camera_zoom_out":
            _apply_zoom_delta(-CAMERA_ZOOM_STEP, ctx.cursor_screen_pos)
        &"camera_snap_to_unit":
            if ctx.unit_world_pos != Vector2.ZERO:
                position = ctx.unit_world_pos
                _apply_pan_clamp()
        _:
            return  # not a camera action — silently ignore
```

`InputContext` payload extension: ADR-0005's typed Resource currently has `coord: Vector2i` + `unit_id: int`. Camera consumption requires either (a) extending InputContext with `drag_delta: Vector2 = Vector2.ZERO` + `cursor_screen_pos: Vector2 = Vector2.ZERO` + `unit_world_pos: Vector2 = Vector2.ZERO` fields (additive-only schema evolution per ADR-0005 CR-1d), OR (b) having Camera read mouse position directly via `get_viewport().get_mouse_position()` for cursor + via internal drag-state-tracking for delta. **Decision: option (b)** — Camera owns drag state per OQ-2 resolution from ADR-0005, so internal tracking is more cohesive than extending InputContext. The `&"camera_pan"` action becomes a **trigger** ("user wants to pan"), and Camera computes the delta from its own drag-start position.

**Pan clamp**:

```gdscript
func _apply_pan_clamp() -> void:
    var map_dims: Vector2i = _map_grid.get_map_dimensions()  # (cols, rows)
    var tile_size: float = float(BalanceConstants.get_const(&"TILE_WORLD_SIZE"))
    var map_world_size: Vector2 = Vector2(map_dims.x, map_dims.y) * tile_size
    var viewport_size: Vector2 = get_viewport_rect().size / zoom.x  # in world units
    var half_view: Vector2 = viewport_size * 0.5
    # If map smaller than viewport, center the map; else clamp position so view stays inside map
    if map_world_size.x <= viewport_size.x:
        position.x = map_world_size.x * 0.5
    else:
        position.x = clampf(position.x, half_view.x, map_world_size.x - half_view.x)
    if map_world_size.y <= viewport_size.y:
        position.y = map_world_size.y * 0.5
    else:
        position.y = clampf(position.y, half_view.y, map_world_size.y - half_view.y)
```

### 4. screen_to_grid — The Cross-System Contract

```gdscript
func screen_to_grid(screen_pos: Vector2) -> Vector2i:
    var world_pos: Vector2 = get_canvas_transform().affine_inverse() * screen_pos
    var tile_size: int = int(BalanceConstants.get_const(&"TILE_WORLD_SIZE"))
    var grid_x: int = int(world_pos.x / tile_size)
    var grid_y: int = int(world_pos.y / tile_size)
    var map_dims: Vector2i = _map_grid.get_map_dimensions()
    if grid_x < 0 or grid_x >= map_dims.x or grid_y < 0 or grid_y >= map_dims.y:
        return Vector2i(-1, -1)
    return Vector2i(grid_x, grid_y)
```

Deterministic, integer-safe, returns the sentinel `Vector2i(-1, -1)` for off-grid clicks. Grid Battle Controller (ADR-0014) consumes this verbatim.

### 5. DI Setup — `setup(map_grid: MapGrid)`

```gdscript
var _map_grid: MapGrid = null

func setup(map_grid: MapGrid) -> void:
    _map_grid = map_grid

func _ready() -> void:
    assert(_map_grid != null, "BattleCamera.setup(map_grid) must be called before adding to scene tree")
    make_current()
    zoom = Vector2(BalanceConstants.get_const(&"CAMERA_ZOOM_DEFAULT"), BalanceConstants.get_const(&"CAMERA_ZOOM_DEFAULT"))
    GameBus.input_action_fired.connect(_on_input_action_fired, Object.CONNECT_DEFERRED)
    _apply_pan_clamp()

func _exit_tree() -> void:
    # MANDATORY explicit disconnect — GameBus is autoload (outlives BattleCamera);
    # without disconnect, the autoload holds a callable pointing at a freed Node
    # → memory leak + crash on next emit if the Camera ref is dispatched. Per
    # godot-specialist 2026-05-02 ADR-0013 review (CONCERNS — required revision #2).
    if GameBus.input_action_fired.is_connected(_on_input_action_fired):
        GameBus.input_action_fired.disconnect(_on_input_action_fired)
```

Mirrors ADR-0010 HPStatusController + ADR-0011 TurnOrderRunner DI pattern. Tests inject a `MapGridStub` (extends `tests/helpers/map_grid_stub.gd` from hp-status epic).

**Cross-ADR audit obligation** (carried as TD entry by camera epic story-001): verify ADR-0010 + ADR-0011's battle-scoped Nodes also include `_exit_tree()` autoload-disconnect cleanup. If they don't, this is a latent leak across all 3 battle-scoped Node systems and a TD-057 entry must be logged for retrofit (the leak is silent in tests because BattleScene tear-down is rare in test fixtures).

### 6. Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│ BattleScene (battle_scene.tscn)                          │
│                                                          │
│  ┌──────────┐    setup(map_grid)                         │
│  │ MapGrid  │───────────────►┌──────────────┐            │
│  │ (Node2D) │                │ BattleCamera │ extends    │
│  └──────────┘                │  (Camera2D)  │ Camera2D   │
│                              └──────┬───────┘            │
│                                    │                     │
│  ┌─────────────────────────┐       │                     │
│  │ Grid Battle Controller  │ uses  │                     │
│  │    (ADR-0014, NYW)      │◄──────┤ screen_to_grid()    │
│  └─────────────────────────┘       │ get_zoom()          │
│                                    │                     │
└────────────────────────────────────┼─────────────────────┘
                                     │ subscribes (CONNECT_DEFERRED)
                                     ▼
                              GameBus.input_action_fired
                                     ▲
                                     │ emits
                              ┌──────┴──────┐
                              │ InputRouter │ (ADR-0005)
                              └─────────────┘
```

### 7. Key Interfaces

```gdscript
# Public API surface (Camera class)
class_name BattleCamera extends Camera2D

# Setup (DI — BattleScene calls before _ready())
func setup(map_grid: MapGrid) -> void

# Hit-testing (Grid Battle Controller consumes)
func screen_to_grid(screen_pos: Vector2) -> Vector2i

# Read-only state queries (Battle HUD consumes)
func get_zoom_value() -> float                  # returns zoom.x (zoom is uniform Vector2(z,z))

# Internal — not for external call
func _apply_zoom_delta(delta: float, cursor_screen_pos: Vector2) -> void
func _apply_pan_clamp() -> void
func _on_input_action_fired(action: StringName, ctx: InputContext) -> void
```

**4 instance fields** (battle-scoped):
- `_map_grid: MapGrid = null` — DI'd before _ready()
- `_drag_active: bool = false` — pan-vs-tap state
- `_drag_start_screen_pos: Vector2 = Vector2.ZERO` — captured at drag-start
- `_drag_start_camera_pos: Vector2 = Vector2.ZERO` — for delta computation

## Alternatives Considered

### Alternative 1: Stateless-Static Utility Class

- **Description**: `class_name Camera extends RefCounted` with all-static methods; no Camera2D Node; manual canvas transform calculation in shaders / `draw_set_transform()`.
- **Pros**: Mirrors 5-precedent pattern (ADR-0006/0007/0008/0009/0012). No instance state. Stateless = trivially testable.
- **Cons**: (a) Can't subscribe to GameBus signals (RefCounted has no node lifecycle). (b) Manual transform math means re-implementing what Camera2D provides for free. (c) `make_current()` semantics don't apply — would need to manually push transforms into every draw call. (d) Massively diverges from Godot idiom.
- **Rejection Reason**: Camera is a *state-holder + signal-listener*, not a calculator. The 5-precedent pattern is for systems CALLED by other systems, not systems that LISTEN to events. Same justification as ADR-0005 §1 Alternative 4 rejection (InputRouter REJECTED stateless-static for the same reason).

### Alternative 2: Autoload Camera (cross-scene survival)

- **Description**: Camera as `/root/Camera` autoload Node, like InputRouter (ADR-0005). State survives scene transitions.
- **Pros**: Eliminates per-battle setup cost. Single Camera reference reusable across scenes.
- **Cons**: (a) Camera state is fundamentally battle-scoped (overworld scene has no battle map; main menu has no Camera consumer). (b) Autoloads cannot be parameterized per-scene without ugly `set_map(...)` calls before each scene-load. (c) `make_current()` across scene boundaries gets weird (would need to manage stack of "previous current" cameras for nested scenes). (d) Memory: Camera holds ~40 bytes of state — autoload adds zero benefit and one risk (state leak across battles if reset is forgotten).
- **Rejection Reason**: Battle-scoped lifecycle is the natural fit. Mirrors ADR-0010 HPStatusController + ADR-0011 TurnOrderRunner battle-scoped Node precedent. Autoload form would be the right call only if a future overworld-camera or main-menu-camera shared state with the battle camera, which the GDD does not anticipate.

### Alternative 3: Composite — Camera2D Node + Adjacent Static Helper

- **Description**: Camera2D Node owns mutable state (zoom, position); a separate stateless `class_name CameraMath extends RefCounted` static class owns `screen_to_grid` math.
- **Pros**: Separates lifecycle (Node) from pure math (RefCounted) — testable in isolation.
- **Cons**: (a) `screen_to_grid` requires `get_canvas_transform()` — that's a Camera2D-instance method, not a free function. The static helper would need to receive a `Camera2D` reference, which is just a roundabout way of calling an instance method. (b) Two classes for one concept — adds API surface without clarity benefit.
- **Rejection Reason**: Over-engineering for MVP. The Node form already supports DI test stubbing; splitting math into a static helper offers marginal testability gain at the cost of a 2-class API. If a future use case emerges (e.g., a Battle HUD needing screen-to-grid without a Camera reference), the helper can be extracted then.

## Consequences

### Positive
- Establishes Camera as the **3rd battle-scoped Node** in the project, reinforcing the pattern boundary precedent (ADR-0010 + ADR-0011 + this ADR).
- `screen_to_grid` is the single source-of-truth for click-to-grid conversion — no other system implements its own (forbidden_pattern `external_screen_to_grid_implementation`).
- Cursor-stable zoom is the Godot-idiomatic UX expectation; matches feel of all major SRPG tools (영걸전 / Triangle Strategy / etc.).
- Pan clamp prevents player from "losing the map" — common SRPG papercut avoided.
- Subscription via `Object.CONNECT_DEFERRED` matches ADR-0001 §5 mandate; avoids re-entrancy hazards from InputRouter dispatch.
- LOW engine risk — every API used is stable since Godot 4.0.

### Negative
- Camera owns its own drag state (per OQ-2 resolution from ADR-0005). This means InputRouter's `&"camera_pan"` action is a **trigger** rather than a complete description; Camera must read `get_viewport().get_mouse_position()` directly for cursor and track its own drag-start state. Slight coupling to viewport mouse query that pure-action systems would avoid.
- 4 new BalanceConstants entries (`CAMERA_ZOOM_MIN/MAX/DEFAULT/STEP`) — extends the constants registry; minor maintenance cost.
- Pan clamp computation runs on every pan event — ~0.005ms per call; well under budget but worth noting.
- DI pattern requires every BattleScene to remember `camera.setup(map_grid)` before adding to tree — easy to forget; mitigated by `_ready()` assert.

### Risks
- **R-1: Camera2D zoom direction confusion** — Godot 3.x had inverted zoom semantics (higher zoom = smaller view); Godot 4.0+ inverted to "higher zoom = larger view". This ADR commits to the 4.6 semantic. **Mitigation**: explicit comment on `zoom` setter; perf test asserts `zoom = Vector2(2,2)` yields 2× the apparent tile size.
- **R-2: BalanceConstants load-order race** — Camera's `_ready()` consumes `BalanceConstants.get_const(&"CAMERA_ZOOM_DEFAULT")`; if BalanceConstants hasn't loaded, returns 0.0 → Camera zoom collapses. **Mitigation**: BalanceConstants is autoloaded at order 0 (first); Camera is battle-scoped (loaded much later). Race is impossible by load order.
- **R-3: MapGrid stub vs. real divergence** — tests inject MapGridStub (existing helper); production injects real MapGrid. If stub's `get_map_dimensions()` returns different shape than real (e.g., Vector2 vs Vector2i), pan clamp breaks silently. **Mitigation**: stub matches real signature exactly per existing convention; lint script `tools/ci/lint_camera_map_grid_contract.sh` greps both sources for the signature.
- **R-4: Cursor-stable zoom inverts at extreme zoom levels** — at zoom = 0.70 (close to floor) zooming in past floor produces no zoom change, but the cursor-stable position adjustment still fires. **Mitigation**: early-return when `is_equal_approx(new_zoom, old_zoom)` per the recipe.
- **R-5: Touch-screen pan event ordering** — InputRouter's pan-vs-tap classifier (CR-4f F-3) fires `&"camera_pan"` only AFTER a touch travels > PAN_ACTIVATION_PX; the first `camera_pan` event lacks an established drag-start because it includes the existing travel. **Mitigation**: Camera's `_drag_active` flag starts false; first `camera_pan` event captures `_drag_start_screen_pos` from current mouse position; subsequent events compute delta from that anchor.
- **R-6: GameBus connection leak on BattleScene exit** (per godot-specialist 2026-05-02 review, blocking concern #2) — `GameBus` is an autoload (load order 1) and outlives every BattleScene instance. When BattleScene is `queue_free()`d, `BattleCamera` is freed with it, but Godot 4.x does NOT auto-disconnect signals where the SOURCE outlives the TARGET — only the reverse. Without explicit cleanup, the autoload retains a callable pointing at a freed Node, causing (a) memory leak (callable ref + closure capture) and (b) crash on next emit if the dispatcher attempts to invoke the freed callable. **Mitigation**: explicit `_exit_tree()` body that calls `GameBus.input_action_fired.disconnect(_on_input_action_fired)` (see §5 code block). **Cross-ADR follow-up: RESOLVED 2026-05-03 via grid-battle-controller story-009 audit** — HPStatusController + BattleCamera + GridBattleController already had `_exit_tree()` autoload-disconnect; TurnOrderRunner was missing and got retrofitted in same patch. TD-057 closed; pattern stable at 4 invocations.
- **R-7: `process_mode` ambiguity for pause-menu scenarios** (per godot-specialist advisory #3) — Camera's default `process_mode = PROCESS_MODE_INHERIT` means that if BattleScene ever uses `get_tree().paused = true` for a pause menu, Camera's `_on_input_action_fired` handler stops firing — pan/zoom dies during pause. EC-9 specifies camera actions remain active during enemy phase (`INPUT_BLOCKED` state in InputRouter), but a pause-menu pause is structurally different from S5. **Decision deferral**: this ADR does NOT lock `process_mode` — defer to camera epic story-001 once the pause-menu pattern is decided (state-machine-only pause vs. `get_tree().paused = true`). If `get_tree().paused`, set `BattleCamera.process_mode = PROCESS_MODE_ALWAYS`. If state-machine pause, default `INHERIT` is fine. **Default for story-001**: leave `process_mode` unset (engine default INHERIT); revisit when first pause menu ships.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `input-handling.md` | F-1: `camera_zoom_min = 44 / 64 = 0.70` (rounded for comfort) | `CAMERA_ZOOM_MIN = 0.70` BalanceConstants entry; clamp enforced on every zoom mutation |
| `input-handling.md` | §9 Bidirectional Contract: `Camera.screen_to_grid(screen_pos: Vector2) -> Vector2i` | Verbatim signature implemented per §4 of this ADR |
| `input-handling.md` | OQ-2 resolution: Camera owns drag state (InputRouter does NOT gate grid input mid-drag) | `_drag_active` + `_drag_start_*` instance fields; `&"camera_pan"` action treated as trigger, not delta source |
| `input-handling.md` | CR-1 + Action vocabulary: 4 camera-domain actions (`camera_pan` / `camera_zoom_in` / `camera_zoom_out` / `camera_snap_to_unit`) | `_on_input_action_fired` match arm handles all 4; non-camera actions silently ignored |
| `input-handling.md` | EC-9: camera actions remain active in S5 (INPUT_BLOCKED) per EC-2 — player can pan/zoom during enemy phase to read the field | InputRouter's S5 dispatch arm passes camera actions through (per ADR-0005 Implementation Notes Advisory C); Camera receives them normally — no S5-aware logic in Camera itself |
| `map-grid.md` | `get_map_dimensions() -> Vector2i` consumed by Camera | DI'd via `setup(map_grid)`; called in `_apply_pan_clamp` and `screen_to_grid` |

## Performance Implications

- **CPU per-frame**: Camera2D update is engine-internal — negligible (~0.001ms). Custom code runs only on input events: `_on_input_action_fired` < 0.005ms per call (single match arm + ~3 vector ops). Headless throughput baseline target: 1000 synthetic camera events < 10ms.
- **Memory**: 4 instance fields + Camera2D engine state ≈ ~120 bytes total per Camera instance. Single instance per battle. Well under 512 MB mobile ceiling.
- **Load Time**: `_ready()` runs `make_current()` + initial zoom set + GameBus connect + initial pan_clamp — all O(1), single-shot at battle scene entry, < 1ms.
- **Network**: N/A (singleplayer).
- **Cross-platform**: Pure 2D vector math. Deterministic by construction. No platform-specific APIs.

## Migration Plan

From `[no current implementation — chapter-prototype's fixed-view + click pattern is the throwaway brief, not the migration source]`:

1. Author camera epic via `/create-epics camera` (sprint-4 S4-02 first sub-task)
2. `/create-stories camera` produces ~5-7 stories:
   - story-001: `BattleCamera` class skeleton (`extends Camera2D`, NOT `class_name Camera` per G-12) + DI `setup(map_grid)` + `_ready()` + **`_exit_tree()` autoload-disconnect cleanup** (per godot-specialist concern #2) + Battle Scene mount
   - story-002: GameBus subscription + 4 action handlers + InputContext consumption pattern
   - story-003: Zoom logic (range clamp + cursor-stable recipe + tween polish)
   - story-004: Pan logic (drag-state tracking + edge clamp via MapGrid)
   - story-005: `screen_to_grid` implementation + 3-zoom fixture test
   - story-006: Cross-ADR audit — verify ADR-0010 HPStatusController + ADR-0011 TurnOrderRunner battle-scoped Nodes also have `_exit_tree()` autoload-disconnect; if missing, log TD-057 retrofit task (separate from this ADR's scope; may carry to Polish phase)
   - story-007 (epic-terminal): perf baseline + 4 forbidden_patterns lints (`camera_signal_emission` + `camera_missing_exit_tree_disconnect` + `hardcoded_zoom_literals` + `external_screen_to_grid_implementation`) + 4 BalanceConstants entries + epic-terminal commit
3. Same-patch obligations:
   - 4 new BalanceConstants in `assets/data/balance/balance_entities.json` (`CAMERA_ZOOM_MIN/MAX/DEFAULT/STEP`)
   - 1 lint addition for the BalanceConstants key-presence gate (extend `lint_balance_entities_*.sh` family)
   - `tests/helpers/camera_stub.gd` from chapter-prototype is NOT used (production code; new stub written from scratch in story-001)
4. Camera epic complete sets up sprint-5 Grid Battle Controller epic (S5+) and sprint-6 Battle Scene wiring.

## Validation Criteria

This ADR is correct when (validation in camera epic story-006 epic-terminal):

1. **Functional**:
   - `screen_to_grid(Vector2(0,0))` at default zoom + position returns `Vector2i(0,0)` for a 1280×720 viewport with map-origin centered
   - `screen_to_grid` returns `Vector2i(-1,-1)` for any click outside `[0, map_width × tile_size)` × `[0, map_height × tile_size)`
   - Same click position returns same grid coord at zoom = 0.70, 1.00, 2.00 (3 fixture tests)
   - `_apply_zoom_delta` with delta = +0.10 from zoom = 1.00 yields zoom = 1.10 AND cursor world position invariant ± 0.001px
   - `_apply_zoom_delta` at zoom = 0.70 with delta = -0.10 yields zoom unchanged (clamped to floor)
   - `_apply_pan_clamp` with map smaller than viewport centers the camera on map center
   - `_apply_pan_clamp` with map larger than viewport bounds position to keep view inside map
2. **Signal contract**:
   - Subscription to `GameBus.input_action_fired` uses `Object.CONNECT_DEFERRED` (assert via grep test)
   - Explicit `_exit_tree()` cleanup disconnects `_on_input_action_fired` (assert via grep test for `GameBus.input_action_fired.disconnect` literal in source)
   - `BattleCamera` does NOT emit any GameBus signal (assert via lint `grep -c 'GameBus\..*\.emit' src/feature/camera/battle_camera.gd` returns `0`; the `\.emit` suffix anchor distinguishes emit calls from subscription / disconnect / `is_connected` lines per godot-specialist advisory)
3. **Performance**:
   - Headless: 1000 synthetic camera events < 10ms (avg < 0.01ms per event)
   - Single camera frame update < 0.05ms (negligible)
4. **Engine compatibility**:
   - Verify Camera2D semantic on Godot 4.6: `zoom = Vector2(2,2)` yields 2× larger apparent tile (NOT smaller per 3.x semantics)
   - Verify `get_canvas_transform()` updates synchronously when `zoom` is mutated (test: set zoom, immediately call screen_to_grid, expect updated result)

## Related Decisions

- **ADR-0001** (GameBus) — signal contract source-of-truth; consumer pattern + Object.CONNECT_DEFERRED mandate
- **ADR-0004** (Map/Grid) — `get_map_dimensions()` consumed for pan clamp
- **ADR-0005** (Input Handling) — F-1 zoom floor + screen_to_grid contract + 4 camera actions + OQ-2 drag-state ownership resolution
- **ADR-0006** (Balance/Data) — 4 new BalanceConstants entries follow this ADR's authoring pattern
- **ADR-0010** (HPStatusController) — battle-scoped Node precedent #1
- **ADR-0011** (TurnOrderRunner) — battle-scoped Node precedent #2
- **ADR-0014** (Grid Battle Controller, Accepted 2026-05-02) — primary consumer of `screen_to_grid`; was authored in parallel with this ADR; delta #10 backfill ratified
- **ADR-0015** (Battle HUD, Accepted 2026-05-03 via /architecture-review delta #10) — consumer of `get_zoom_value()` for HUD scale matching per ADR-0015 §6 grid-overlay polling
- **Future Camera ADR amendment** — may add `&"camera_recenter_on_selection"` action when first multi-unit selection feature ships (post-MVP)
