# Story 008: Touch protocol part A — Tap Preview Protocol (CR-4a) + Magnifier Panel (CR-4c F-2 trigger) + Selection highlight (CR-4d) + F-1 camera_zoom_min derivation + verification evidence #3 + #5a + Battle HUD/Camera stubs

> **Epic**: Input Handling
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 4-5h
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/input-handling.md`
**Requirement**: `TR-input-handling-007`, `TR-input-handling-008`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005 — Input Handling — InputRouter Autoload + 7-State FSM (MVP scope)
**ADR Decision Summary**: TR-007 (touch part A scope) = §5 + CR-4 — Tap Preview Protocol (CR-4a TPP) dispatched in OBSERVATION state when `active_input_mode == TOUCH` (preview bubble 80-120px above touch point; second tap on same unit advances S0 → S1; tap on different element dismisses prior preview). Magnifier Panel (CR-4c) triggered when `tap_edge_offset < DISAMBIG_EDGE_PX` OR `tile_display_px < DISAMBIG_TILE_PX` per F-2 (3×3 grid zoomed 3× current scale; tap-to-tile mapping repositioned if near screen edge per EC-9). TR-008 = §7 + F-1 `camera_zoom_min = TOUCH_TARGET_MIN_PX (44 fixed) / tile_world_size (64 fixed) = 0.6875 → rounded to 0.70 for comfort margin (44.8px effective at zoom=0.70 above 44px floor); InputRouter computes derivation using `DisplayServer.screen_get_size()` — flagged for §5a verification (returns logical DPI-aware pixels on Android — plausible per godot-specialist Item 5 but reference docs do not explicitly confirm).

**Engine**: Godot 4.6 | **Risk**: HIGH (governed by ADR-0005)
**Engine Notes**: `DisplayServer.screen_get_size() -> Vector2i` (4.0+ stable; godot-specialist Item 5 plausible-but-unconfirmed for logical DPI return on Android — verification §5a mandatory); `InputEventScreenTouch.position` (4.0+ stable) for tap coordinate; `InputEventScreenTouch.index` field (4.0+ stable; verification §6 advisory for cross-platform stability is story-009 scope). `emulate_mouse_from_touch=false` setting in `[input_devices.pointing]` of `project.godot` — verification §3 mandatory in this story (Project Settings → Input Devices → Pointing path plausible per godot-specialist Item 6 but unconfirmed in reference docs). **Verification items #3 + #5a** mandatory in this story (NOT Polish-deferable per EPIC.md classification — both headless-verifiable).

**Control Manifest Rules (Foundation layer + Global)**:
- Required: TPP only fires in S0 with TOUCH mode; Magnifier Panel only fires when F-2 trigger condition true; F-1 derivation uses `DisplayServer.screen_get_size()` ONCE at `_ready()` (cached as `_camera_zoom_min: float = 0.70` — recomputed only on screen-size change events, not per-frame); `_construct_input_context` performs Camera stub `screen_to_grid(touch_pos) -> coord` + MapGrid stub `get_unit_at(coord) -> unit_id`; `emulate_mouse_from_touch=false` set in project.godot (verification #3)
- Forbidden: hardcoded `camera_zoom_min` value (must derive from F-1 formula at `_ready()`); rendering TPP bubble inside InputRouter (Battle HUD owns rendering — InputRouter only emits `input_action_fired(&"unit_select", ctx_with_unit_id)` for first tap and `&"unit_select"` again for second tap with same unit_id; Battle HUD distinguishes); `emulate_mouse_from_touch=true` (R-3 violation — story-010 lint enforces)
- Guardrail: F-1 computation <10 LoC; TPP state tracking <20 LoC additional fields (`_last_tap_unit_id: int = -1` + `_last_tap_time_ms: int = 0` for second-tap-detection); Magnifier trigger `_should_trigger_magnifier` <15 LoC

---

## Acceptance Criteria

*From GDD §Acceptance Criteria AC-5 + AC-6 + AC-7 + AC-18 + ADR-0005 §7 + CR-4a + CR-4c + CR-4d + F-1 + F-2 + EC-9:*

- [ ] **AC-1** F-1 derivation: `_compute_camera_zoom_min() -> float` helper computes `TOUCH_TARGET_MIN_PX (44) / tile_world_size (64) = 0.6875`; rounds to 0.70 for comfort margin; cached as `_camera_zoom_min: float` field at `_ready()`. Constants extracted from BalanceConstants per ADR-0006 (`BalanceConstants.get_const(&"TOUCH_TARGET_MIN_PX")` + `&"TILE_WORLD_SIZE"`); if BalanceConstants doesn't have them yet, story-008 same-patch adds the 2 keys to `assets/data/balance/balance_entities.json`
- [ ] **AC-2** AC-6 GDD test (touch target minimum): GIVEN `_camera_zoom_min == 0.70`; WHEN `tile_world_size * _camera_zoom_min` measured — THEN result == 44.8px (above 44px floor with comfort margin); informational: `0.6875 * 64 == 44.0px` exact (the floor)
- [ ] **AC-3** TPP state tracking: 2 new fields `_last_tap_unit_id: int = -1` + `_last_tap_time_ms: int = 0`. On `&"unit_select"` action match in S0 with `_active_mode == TOUCH`: if `ctx.unit_id == _last_tap_unit_id` AND `(Time.get_ticks_msec() - _last_tap_time_ms) < TPP_DOUBLE_TAP_WINDOW_MS` (constant ~500ms per CR-4a — extracted to BalanceConstants), advance to S1 (full unit-selected behavior); otherwise (first tap on a new unit OR same-unit-but-window-expired): stay in S0, update `_last_tap_unit_id` + `_last_tap_time_ms`, emit `input_action_fired(&"unit_select", ctx)` for Battle HUD to render preview bubble
- [ ] **AC-4** AC-5 GDD test (TPP): GIVEN S0 + TOUCH mode + ctx with unit_id=5; WHEN first tap (`_handle_action(&"unit_select", ctx)`) — THEN state stays S0; `_last_tap_unit_id == 5`; `input_action_fired(&"unit_select", ctx)` emit captured. WHEN second tap on SAME unit within 500ms — THEN state transitions S0 → S1; second emit captured. WHEN second tap on DIFFERENT unit — THEN state stays S0; `_last_tap_unit_id` updated to new unit_id (preview dismissed and re-shown for new unit)
- [ ] **AC-5** Magnifier Panel F-2 trigger: `_should_trigger_magnifier(touch_pos: Vector2, tile_display_px: float) -> bool` returns true when `_compute_tap_edge_offset(touch_pos) < DISAMBIG_EDGE_PX (constant ~8px)` OR `tile_display_px < DISAMBIG_TILE_PX (constant ~32px)`. `_compute_tap_edge_offset` uses `DisplayServer.screen_get_size()` to determine tap distance to nearest tile boundary in screen space. Helper called from `_construct_input_context` for touch events; if true, emits `input_action_fired(&"magnifier_open", ctx)` BEFORE the action match (Battle HUD subscriber renders the 3×3 magnifier panel; player taps within the magnifier to disambiguate)
- [ ] **AC-6** AC-7 GDD test (magnifier trigger): GIVEN `tile_display_px == 48` (above 32 threshold); GIVEN touch lands 6px from tile boundary (below 8 threshold); WHEN `_should_trigger_magnifier(touch_pos, 48.0)` invoked — THEN returns true. Edge cases: touch 10px from boundary AND tile_display 48px → returns false; touch 10px from boundary AND tile_display 30px → returns true (tile size dominates)
- [ ] **AC-7** AC-18 GDD test (no hover-only): GIVEN `_active_mode == TOUCH`; sweep all 22 actions; WHEN each action's reachability checked — THEN every action except `grid_hover` (PC-only per CR-1c) has at least 1 binding in `default_bindings.json` mapping to a touch-equivalent (`screen_touch` event). `grid_hover` reachable equivalent is the TPP preview (CR-4a — first tap shows the same info that hover would on PC). Verified via test that asserts every entry in `ACTIONS_BY_CATEGORY[grid/menu/meta]` (excluding `grid_hover`) has a touch binding
- [ ] **AC-8** Verification evidence #3: `production/qa/evidence/input_router_verification_03_emulate_mouse_from_touch.md` exists describing in-editor verification of `emulate_mouse_from_touch=false` in `project.godot` `[input_devices.pointing]` section. Test: read `project.godot` content; assert `emulate_mouse_from_touch=false` appears in the `[input_devices.pointing]` section. Add the setting if missing. Headless-verifiable + mandatory in this story per EPIC.md item-#3 classification
- [ ] **AC-9** Verification evidence #5a: `production/qa/evidence/input_router_verification_05a_displayserver_screen_get_size.md` exists describing test that confirms `DisplayServer.screen_get_size()` returns logical (DPI-aware) pixels on macOS (headless-verifiable on dev machine) + documents Android verification path for Polish (mobile-only confirmation via export build). Test: at `_ready()`, log `DisplayServer.screen_get_size()` value; assert value is sane (1280x720 or similar logical resolution, NOT physical-pixel multiplier). Mandatory in this story per EPIC.md item-#5a classification (headless-verifiable on dev)
- [ ] **AC-10** Battle HUD + Camera stubs created: `tests/helpers/battle_hud_stub.gd` (`class_name BattleHUDStub extends RefCounted` with `show_unit_info(unit_id) -> void` + `show_tile_info(coord) -> void` + `dismiss_preview() -> void` + `show_magnifier(touch_pos, cluster_coords) -> void`; recording calls to per-method `Array[Dictionary]` fields per stub-extension precedent). `tests/helpers/camera_stub.gd` (`class_name CameraStub extends RefCounted` with `screen_to_grid(screen_pos: Vector2) -> Vector2i` returning fixture mappings + `clamp_zoom(zoom: float) -> float` returning `max(zoom, _camera_zoom_min)`). MapGrid stub from hp-status epic (`tests/helpers/map_grid_stub.gd`) extended with `get_unit_at(coord: Vector2i) -> int` (returns -1 if no unit; fixture-injected unit_id otherwise)
- [ ] **AC-11** Regression baseline maintained: full GdUnit4 suite passes ≥811 cases (story-007 baseline) + new tests / 0 errors / 0 failures / 0 orphans / Exit 0; new test file `tests/unit/foundation/input_router_touch_part_a_test.gd` adds ≥12 tests covering AC-1..AC-9
- [ ] **AC-12** New BalanceConstants entries added to `assets/data/balance/balance_entities.json`: `TOUCH_TARGET_MIN_PX = 44`, `TILE_WORLD_SIZE = 64`, `TPP_DOUBLE_TAP_WINDOW_MS = 500`, `DISAMBIG_EDGE_PX = 8`, `DISAMBIG_TILE_PX = 32` — 5 new keys with provenance comments per ADR-0006 + ADR-0005 §Tuning Knobs ownership

---

## Implementation Notes

*Derived from ADR-0005 §5 + §7 + CR-4a + CR-4c + CR-4d + F-1 + F-2 + EC-9 + Implementation Notes Item 5 (DisplayServer):*

1. **F-1 derivation in `_ready()`**:
   ```gdscript
   var _camera_zoom_min: float = 0.70  # default; recomputed at _ready()

   func _ready() -> void:
       # ... story-002 + story-007 _ready() body ...
       _camera_zoom_min = _compute_camera_zoom_min()

   func _compute_camera_zoom_min() -> float:
       var touch_min: float = float(BalanceConstants.get_const(&"TOUCH_TARGET_MIN_PX"))  # 44
       var tile_world: float = float(BalanceConstants.get_const(&"TILE_WORLD_SIZE"))  # 64
       var raw: float = touch_min / tile_world  # 0.6875
       # Comfort margin: round up to next 0.05 increment; 0.6875 → 0.70 per F-1 + ADR-0005 §7
       return ceilf(raw * 20.0) / 20.0
   ```

2. **TPP state tracking on `_handle_action_in_s0` `unit_select` arm**:
   ```gdscript
   const _TPP_DOUBLE_TAP_WINDOW_MS_KEY: StringName = &"TPP_DOUBLE_TAP_WINDOW_MS"
   var _last_tap_unit_id: int = -1
   var _last_tap_time_ms: int = 0

   func _handle_action_in_s0(action: StringName, ctx: InputContext) -> void:
       match action:
           &"unit_select":
               if ctx.unit_id == -1:
                   return
               if _active_mode == InputMode.TOUCH:
                   var now: int = Time.get_ticks_msec()
                   var window_ms: int = int(BalanceConstants.get_const(_TPP_DOUBLE_TAP_WINDOW_MS_KEY))
                   if ctx.unit_id == _last_tap_unit_id and (now - _last_tap_time_ms) < window_ms:
                       # Second tap on same unit within window: advance to S1
                       _last_tap_unit_id = -1
                       _last_tap_time_ms = 0
                       _state = InputState.UNIT_SELECTED
                       _did_visible_work = true
                       return
                   # First tap (or stale window OR different unit): preview only
                   _last_tap_unit_id = ctx.unit_id
                   _last_tap_time_ms = now
                   _did_visible_work = true  # emit input_action_fired so Battle HUD renders TPP bubble
                   # State stays S0
                   return
               # KEYBOARD_MOUSE mode: single click selects (story-003 behavior preserved)
               _state = InputState.UNIT_SELECTED
               _did_visible_work = true
           # ... existing arms from stories 003-007 ...
   ```

3. **`_should_trigger_magnifier` helper**:
   ```gdscript
   const _DISAMBIG_EDGE_PX_KEY: StringName = &"DISAMBIG_EDGE_PX"
   const _DISAMBIG_TILE_PX_KEY: StringName = &"DISAMBIG_TILE_PX"

   func _should_trigger_magnifier(touch_pos: Vector2, tile_display_px: float) -> bool:
       var edge_threshold: float = float(BalanceConstants.get_const(_DISAMBIG_EDGE_PX_KEY))
       var tile_threshold: float = float(BalanceConstants.get_const(_DISAMBIG_TILE_PX_KEY))
       var edge_offset: float = _compute_tap_edge_offset(touch_pos, tile_display_px)
       return edge_offset < edge_threshold or tile_display_px < tile_threshold

   func _compute_tap_edge_offset(touch_pos: Vector2, tile_display_px: float) -> float:
       # Distance from touch_pos to nearest tile boundary in screen space
       var x_in_tile: float = fmod(touch_pos.x, tile_display_px)
       var y_in_tile: float = fmod(touch_pos.y, tile_display_px)
       var x_edge: float = min(x_in_tile, tile_display_px - x_in_tile)
       var y_edge: float = min(y_in_tile, tile_display_px - y_in_tile)
       return min(x_edge, y_edge)
   ```

4. **`_construct_input_context` extension** (replaces story-005's placeholder):
   ```gdscript
   func _construct_input_context(event: InputEvent) -> InputContext:
       var ctx := InputContext.new()
       if event is InputEventScreenTouch:
           var touch: InputEventScreenTouch = event
           if _camera != null and _camera.has_method("screen_to_grid"):
               ctx.coord = _camera.screen_to_grid(touch.position)
           if _map_grid != null and _map_grid.has_method("get_unit_at"):
               ctx.unit_id = _map_grid.get_unit_at(ctx.coord)
           # Magnifier trigger check
           var tile_display: float = float(BalanceConstants.get_const(&"TILE_WORLD_SIZE")) * (_camera.get_zoom() if _camera and _camera.has_method("get_zoom") else _camera_zoom_min)
           if _should_trigger_magnifier(touch.position, tile_display):
               GameBus.input_action_fired.emit(&"magnifier_open", ctx)
       elif event is InputEventMouseButton:
           # Mouse click: similar coord lookup via Camera stub
           var mb: InputEventMouseButton = event
           if _camera != null and _camera.has_method("screen_to_grid"):
               ctx.coord = _camera.screen_to_grid(mb.position)
           if _map_grid != null and _map_grid.has_method("get_unit_at"):
               ctx.unit_id = _map_grid.get_unit_at(ctx.coord)
       return ctx
   ```

5. **Camera + MapGrid stub injection**: add `var _camera: Variant = null` field on InputRouter (typed Variant since CameraController class doesn't exist yet — story-014 narrows when Camera ADR ships); test seam `func set_camera_for_tests(stub: Variant) -> void`. MapGrid stub already exists at `tests/helpers/map_grid_stub.gd` (hp-status epic precedent); story-008 extends it with `get_unit_at(coord) -> int` method.

6. **CameraStub** (`tests/helpers/camera_stub.gd`):
   ```gdscript
   class_name CameraStub
   extends RefCounted

   var screen_to_grid_map: Dictionary[Vector2i, Vector2i] = {}  # screen_pos quantized → coord
   var current_zoom: float = 1.0

   func screen_to_grid(screen_pos: Vector2) -> Vector2i:
       var key := Vector2i(int(screen_pos.x), int(screen_pos.y))
       return screen_to_grid_map.get(key, Vector2i(int(screen_pos.x / 64), int(screen_pos.y / 64)))

   func clamp_zoom(zoom: float) -> float:
       return max(zoom, 0.70)  # F-1 floor

   func get_zoom() -> float:
       return current_zoom

   func set_zoom(z: float) -> void:
       current_zoom = clamp_zoom(z)
   ```

7. **BattleHUDStub** (`tests/helpers/battle_hud_stub.gd`):
   ```gdscript
   class_name BattleHUDStub
   extends RefCounted

   var show_unit_info_calls: Array[Dictionary] = []
   var show_tile_info_calls: Array[Dictionary] = []
   var dismiss_preview_calls: int = 0
   var show_magnifier_calls: Array[Dictionary] = []

   func show_unit_info(unit_id: int) -> void:
       show_unit_info_calls.append({"unit_id": unit_id})

   func show_tile_info(coord: Vector2i) -> void:
       show_tile_info_calls.append({"coord": coord})

   func dismiss_preview() -> void:
       dismiss_preview_calls += 1

   func show_magnifier(touch_pos: Vector2, cluster_coords: Array[Vector2i]) -> void:
       show_magnifier_calls.append({"touch_pos": touch_pos, "cluster_coords": cluster_coords})
   ```

8. **MapGridStub extension** (extend `tests/helpers/map_grid_stub.gd` from hp-status epic):
   ```gdscript
   # Add to existing MapGridStub:
   var unit_at_coord: Dictionary[Vector2i, int] = {}  # fixture-injected unit IDs at coords

   func get_unit_at(coord: Vector2i) -> int:
       return unit_at_coord.get(coord, -1)
   ```

9. **Verification evidence #3 template** (`production/qa/evidence/input_router_verification_03_emulate_mouse_from_touch.md`):
   ```markdown
   # InputRouter Verification #3 — emulate_mouse_from_touch=false

   **Epic**: input-handling
   **Story**: story-008-touch-protocol-tpp-magnifier-f1
   **ADR**: ADR-0005 §Verification Required §3 + CR-2e + R-3
   **Status**: Verified (headless via project.godot grep)

   ## Test Procedure (Headless)
   1. Read `project.godot` content via `FileAccess.get_file_as_string("res://project.godot")`
   2. Locate `[input_devices.pointing]` section
   3. Assert `emulate_mouse_from_touch=false` line present in the section
   4. If missing, add it (story-008 same-patch obligation)
   5. CI lint `tools/ci/lint_emulate_mouse_from_touch.sh` (story-010 wires) enforces this on every push

   ## Expected Result
   `emulate_mouse_from_touch=false` set in `[input_devices.pointing]` of `project.godot` for all builds. Touch events do NOT synthesize fake mouse events that would cause double-fire of the same action via two dispatch paths.

   ## Status
   Verified via headless test in `tests/unit/foundation/input_router_touch_part_a_test.gd::test_emulate_mouse_from_touch_disabled`. Mandatory per EPIC.md item-#3 (headless-verifiable; not Polish-deferable).
   ```

10. **Verification evidence #5a template** (`production/qa/evidence/input_router_verification_05a_displayserver_screen_get_size.md`):
    ```markdown
    # InputRouter Verification #5a — DisplayServer.screen_get_size logical pixels

    **Epic**: input-handling
    **Story**: story-008-touch-protocol-tpp-magnifier-f1
    **ADR**: ADR-0005 §Verification Required §5a + F-1
    **Status**: Verified (headless macOS) | Polish-deferred (Android device confirmation)

    ## Test Procedure (Headless macOS)
    1. At test runtime, call `DisplayServer.screen_get_size()` and log Vector2i value
    2. Assert value is sane logical resolution (NOT physical-pixel multiplier on Retina)
    3. On macOS Retina (dev box typical): expect ~1440x900 logical (NOT 2880x1800 physical)
    4. Document observed value in evidence file

    ## Test Procedure (Android — Polish-deferable)
    1. Boot Android 14+ device with running app
    2. Log `DisplayServer.screen_get_size()` to debug overlay
    3. Compare against device's known logical DPR'd resolution (e.g. Pixel 6 = 1080x2400 logical, NOT 1080x2400 × DPR)
    4. If physical-pixel return observed, F-1 derivation FORMULA UPDATE required (divide by DPR)

    ## Expected Result
    `DisplayServer.screen_get_size()` returns logical DPI-aware pixels on macOS + Android (verified via godot-specialist Item 5 PASS but requires runtime confirmation per ADR-0005 §5a).

    ## Status
    Headless macOS verification in `tests/unit/foundation/input_router_touch_part_a_test.gd::test_displayserver_screen_get_size_logical`. Android verification reactivation trigger: when first Android export build is green AND minimum-spec device available.
    ```

11. **Test file**: `tests/unit/foundation/input_router_touch_part_a_test.gd` — 12-15 tests covering AC-1..AC-9. Pattern: GdUnitTestSuite Node-based; full G-15 reset + Camera/MapGrid/BattleHUD stub injection; `Time.get_ticks_msec()` mocking for AC-4 second-tap window test (use `_test_now_ms` test seam if Time mocking unavailable in GdUnit4 v6.1.2 — fall back to setting `_last_tap_time_ms` directly).

12. **5 new BalanceConstants additions** (AC-12 same-patch):
    ```jsonc
    // === INPUT HANDLING BalanceConstants (ADR-0005 §Tuning Knobs, story-008 same-patch) ===
    // TOUCH_TARGET_MIN_PX owned by Input Handling; F-1 numerator
    "TOUCH_TARGET_MIN_PX": 44,
    // TILE_WORLD_SIZE owned by Input Handling; F-1 denominator (also consumed by Camera/Grid Battle ADRs when they ship)
    "TILE_WORLD_SIZE": 64,
    // TPP_DOUBLE_TAP_WINDOW_MS owned by Input Handling; CR-4a second-tap window
    "TPP_DOUBLE_TAP_WINDOW_MS": 500,
    // DISAMBIG_EDGE_PX owned by Input Handling; F-2 magnifier trigger threshold (edge proximity)
    "DISAMBIG_EDGE_PX": 8,
    // DISAMBIG_TILE_PX owned by Input Handling; F-2 magnifier trigger threshold (tile size)
    "DISAMBIG_TILE_PX": 32,
    ```
    Also extend `tools/ci/lint_balance_entities_hp_status.sh` pattern to a sibling `tools/ci/lint_balance_entities_input_handling.sh` (story-010 authors fully; this story creates the 5 keys).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 009**: Touch protocol part B — pan-vs-tap classifier (CR-4f / F-3); two-finger gestures (CR-4g); persistent action panel (CR-4h); verification evidence #5b + #6
- **Story 010**: `lint_emulate_mouse_from_touch.sh` (this story documents the verification but story-010 wires the CI lint); `lint_balance_entities_input_handling.sh`; epic-terminal verification rollup

---

## QA Test Cases

*Authored inline (lean mode QL-STORY-READY skip).*

- **AC-1**: F-1 derivation correctness
  - Given: BalanceConstants `TOUCH_TARGET_MIN_PX=44`, `TILE_WORLD_SIZE=64`
  - When: `_compute_camera_zoom_min()` invoked
  - Then: returns 0.70 (rounded up from 0.6875)
  - Edge cases: change `TOUCH_TARGET_MIN_PX` to 48 → returns 0.75; informational
- **AC-2**: Touch target minimum at zoom
  - Given: `_camera_zoom_min == 0.70`
  - When: `0.70 * 64` computed
  - Then: 44.8 (above 44 floor)
- **AC-3**: TPP first-tap stays in S0
  - Given: S0 + TOUCH mode + `_last_tap_unit_id = -1`
  - When: `_handle_action(&"unit_select", ctx with unit_id=5)`
  - Then: `_state == OBSERVATION`; `_last_tap_unit_id == 5`; `_last_tap_time_ms != 0`; 1 emit captured
- **AC-4**: AC-5 GDD test (TPP second-tap)
  - Given: `_last_tap_unit_id = 5`, `_last_tap_time_ms = Time.get_ticks_msec() - 100` (within window)
  - When: second `&"unit_select"` with unit_id=5
  - Then: `_state == UNIT_SELECTED`; `_last_tap_unit_id` reset to -1
  - Edge cases: second tap on different unit (unit_id=7) → state stays S0; `_last_tap_unit_id = 7`; window expired (>500ms) → state stays S0; `_last_tap_unit_id` updated
- **AC-5**: Magnifier trigger conditions
  - Given: edge threshold 8, tile threshold 32
  - When: `_should_trigger_magnifier(Vector2(54, 100), 48.0)` (54 % 48 = 6, edge_offset 6 < 8) — returns true
  - Edge cases: `_should_trigger_magnifier(Vector2(60, 100), 48.0)` (edge 12 > 8) AND tile 48 > 32 → false; `_should_trigger_magnifier(Vector2(60, 100), 30.0)` (tile < 32) → true
- **AC-6**: AC-7 GDD test (magnifier trigger 6px from boundary, 48px tile)
  - Given: precise scenario from AC-7
  - When: `_should_trigger_magnifier` invoked
  - Then: returns true
- **AC-7**: AC-18 GDD test (no hover-only)
  - Given: ACTIONS_BY_CATEGORY + default_bindings.json loaded
  - When: sweep all 22 actions; for each (excluding `grid_hover`), check default_bindings.json has at least 1 entry with `screen_touch` event type
  - Then: 21/22 actions have touch binding; `grid_hover` correctly absent (CR-1c PC-only)
- **AC-8**: Verification evidence #3 doc + project.godot setting
  - Given: `production/qa/evidence/input_router_verification_03_emulate_mouse_from_touch.md` exists
  - When: read `project.godot` `[input_devices.pointing]` section
  - Then: `emulate_mouse_from_touch=false` line present
  - Edge cases: if missing, add it as part of story-008 same-patch
- **AC-9**: Verification evidence #5a doc + DisplayServer test
  - Given: doc exists
  - When: at test runtime, log `DisplayServer.screen_get_size()`
  - Then: returns sane Vector2i (NOT physical-pixel multiplier on Retina dev box); doc updated with observed value
- **AC-10**: Stub structural correctness
  - Given: BattleHUDStub + CameraStub + MapGridStub-extended created
  - When: instantiate each + invoke key methods
  - Then: methods exist + return expected fixture values; `show_*` methods record calls to Array fields
- **AC-11**: Regression baseline
  - Given: full suite invoked
  - When: 811 + new tests run
  - Then: ≥823 tests / 0 errors / 0 failures / 0 orphans / Exit 0
- **AC-12**: 5 new BalanceConstants present
  - Given: `assets/data/balance/balance_entities.json`
  - When: parse + check for 5 keys (TOUCH_TARGET_MIN_PX, TILE_WORLD_SIZE, TPP_DOUBLE_TAP_WINDOW_MS, DISAMBIG_EDGE_PX, DISAMBIG_TILE_PX)
  - Then: all present with values 44, 64, 500, 8, 32 respectively; provenance comments present per ADR-0006 convention

---

## Test Evidence

**Story Type**: Integration (TPP + Magnifier require Camera + MapGrid + BattleHUD stub interaction; multi-system contract verification)
**Required evidence**:
- Integration: `tests/unit/foundation/input_router_touch_part_a_test.gd` — must exist + ≥12 tests + must pass
- Visual/Feel: `production/qa/evidence/input_router_verification_03_*.md` + `_05a_*.md` — must exist; #3 status "Verified"; #5a status "Verified macOS" + "Polish-deferred Android"
- Same-patch: `assets/data/balance/balance_entities.json` extended with 5 input-handling keys

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 005 (`_construct_input_context` placeholder — this story implements full version), Story 002 (default_bindings.json must have touch entries for AC-7), Story 001 (InputContext payload — coord + unit_id fields used)
- **Unlocks**: Story 009 (touch part B — pan-vs-tap classifier extends `_construct_input_context` with InputEventScreenDrag handling); Battle HUD epic (consumes `&"magnifier_open"` + TPP `&"unit_select"` first-tap signals)
