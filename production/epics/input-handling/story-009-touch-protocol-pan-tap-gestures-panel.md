# Story 009: Touch protocol part B — pan-vs-tap classifier (CR-4f / F-3) + two-finger gestures (CR-4g) + persistent action panel positioning (CR-4h, anti-occlusion) + safe-area API consumption + verification evidence #5b + #6

> **Epic**: Input Handling
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3-4h
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/input-handling.md`
**Requirement**: `TR-input-handling-007` (extension), `TR-input-handling-012`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005 — Input Handling — InputRouter Autoload + 7-State FSM (MVP scope)
**ADR Decision Summary**: TR-007 (touch part B scope) = §5 + CR-4 — pan-vs-tap classifier (CR-4f / F-3): `touch_travel_px > PAN_ACTIVATION_PX` → `camera_pan`; `(hold_duration_ms < MIN_TOUCH_DURATION_MS=80 AND NOT pan)` → rejected. Two-finger gestures (CR-4g) always camera (pinch-zoom or two-finger tap cancel; second finger cancels pending first-finger selection per EC-1 multi-touch cancel). Persistent action panel (CR-4h) updates per state with anti-occlusion repositioning. TR-012 = §7 Android edge-to-edge / safe-area — Action panel positioning consults Godot 4.5+ `DisplayServer` safe-area API (exact name **TBD §5b verification**); 3 candidates per delta #6: (1) `DisplayServer.window_get_safe_title_margins()` (plural per design-time validation Item 5); (2) `DisplayServer.get_display_safe_area()` (review-time candidate Item 5); (3) fallback `DisplayServer.window_get_position_with_decorations()` (desktop-only — likely insufficient for Android notches). Verification §5b mandatory before this story ships.

**Engine**: Godot 4.6 | **Risk**: HIGH (governed by ADR-0005)
**Engine Notes**: `InputEventScreenDrag.position` + `InputEventScreenDrag.relative` (4.0+ stable; `relative` accumulates drag delta since last drag event); `InputEventScreenTouch.index` + `InputEventScreenDrag.index` (4.0+ stable; verification §6 advisory for cross-platform stability — physical hardware on iOS 17 + Android 14+ confirms OS-assigned indices are stable through multi-touch sequence). `Time.get_ticks_msec()` (4.0+ stable) for hold-duration tracking. **Verification items #5b + #6** mandatory in this story — #5b headless-verifiable (try each of 3 candidate API names; document which one resolves); #6 Polish-deferable per pattern (physical-hardware test).

**Control Manifest Rules (Foundation layer + Global)**:
- Required: pan-vs-tap classification deterministic via F-3 thresholds (PAN_ACTIVATION_PX + MIN_TOUCH_DURATION_MS); two-finger gestures ALWAYS classified as camera (NEVER unit_select — CR-4g); second-finger arrival cancels pending first-finger selection (EC-1); safe-area API resolved at `_ready()` (cached as `_safe_area_inset: Vector4 = Vector4.ZERO` field); persistent action panel positioning emits `input_action_fired(&"panel_reposition_request", ctx)` for Battle HUD subscription (InputRouter does NOT render the panel)
- Forbidden: classifying single-finger drag as `unit_select` (always pan); rendering action panel inside InputRouter; hardcoded safe-area inset values (must derive at `_ready()`); `_safe_area_inset` mutation outside `_ready()` or screen-resize handler (test-isolation enforced via convention)
- Guardrail: `_classify_pan_or_tap` <15 LoC; `_handle_two_finger_gesture` <15 LoC; `_resolve_safe_area_api` <20 LoC (tries 3 candidates in order); persistent action panel logic <10 LoC

---

## Acceptance Criteria

*From GDD §Acceptance Criteria AC-8 + AC-9 + ADR-0005 §5 + §7 + CR-4f + CR-4g + CR-4h + EC-1 + EC-9 + F-3:*

- [ ] **AC-1** `_classify_pan_or_tap(touch_travel_px: float, hold_duration_ms: int) -> StringName` helper returns: `&"camera_pan"` if `touch_travel_px > PAN_ACTIVATION_PX (constant ~16px)`; `&"_rejected"` if `(hold_duration_ms < MIN_TOUCH_DURATION_MS (80ms) AND touch_travel_px <= PAN_ACTIVATION_PX)`; `&"unit_select"` if neither (i.e., held longer than 80ms without significant travel — a tap)
- [ ] **AC-2** AC-8 GDD test (pan classification): GIVEN touch begins + moves 20px within 100ms; WHEN `_classify_pan_or_tap(20.0, 100)` invoked — THEN returns `&"camera_pan"` (travel > 16); inject via `_handle_event(InputEventScreenDrag)` to verify the action emits `input_action_fired(&"camera_pan", ctx)` (no state change)
- [ ] **AC-3** AC-9 GDD test (accidental touch rejection): GIVEN touch begins + releases after 50ms without movement; WHEN `_classify_pan_or_tap(2.0, 50)` invoked — THEN returns `&"_rejected"`; inject via `_handle_event(InputEventScreenTouch.released)` to verify NO action emit (silent drop; `_did_visible_work` stays false)
- [ ] **AC-4** Two-finger gesture handling (CR-4g): `_handle_two_finger_gesture(event: InputEventScreenTouch | InputEventScreenDrag) -> void` invoked when `event.index >= 1` (second+ finger): always classified as camera operation (`&"camera_pinch_zoom"` for drag with size change, `&"camera_two_finger_tap_cancel"` for tap). NEVER routed to grid actions. AND second-finger ARRIVAL (index >= 1 with `pressed=true`) cancels any pending first-finger TPP state by resetting `_last_tap_unit_id = -1` + `_last_tap_time_ms = 0` (EC-1 multi-touch cancel)
- [ ] **AC-5** EC-1 GDD test (multi-touch cancel): GIVEN `_last_tap_unit_id = 5` (first-finger TPP active in S0); WHEN second finger arrives (`InputEventScreenTouch.new()` with `index=1`, `pressed=true`) — THEN `_last_tap_unit_id == -1` (preview dismissed); subsequent same-unit second tap on first finger does NOT advance to S1 (window has been canceled)
- [ ] **AC-6** Safe-area API resolution at `_ready()`: `_resolve_safe_area_api() -> Vector4` tries 3 DisplayServer candidate methods in order: (1) `DisplayServer.window_get_safe_title_margins()` (plural); (2) `DisplayServer.get_display_safe_area()`; (3) fallback `Vector4.ZERO` (desktop default — no insets). Returns Vector4(left, top, right, bottom) margins. Cached as `_safe_area_inset: Vector4`. Per EPIC.md §5b mandatory verification — if no candidate exists, document fallback in evidence doc + return Vector4.ZERO. Test verifies graceful fallback (no crash) when neither candidate resolves
- [ ] **AC-7** Persistent action panel anti-occlusion (CR-4h): `_get_action_panel_position(state: InputState) -> Vector2` helper computes panel position based on (a) viewport size from `DisplayServer.window_get_size()`, (b) safe-area inset `_safe_area_inset`, (c) state-specific anchor (S1/S3 prefer bottom-center; S2/S4 prefer below the confirm tile to avoid occlusion). Returns position in screen pixels. Subscribers (Battle HUD) consume via `input_action_fired(&"panel_reposition_request", ctx)` emitted on every state transition where panel must update
- [ ] **AC-8** Verification evidence #5b: `production/qa/evidence/input_router_verification_05b_safe_area_api.md` exists describing the 3-candidate test result. Test: at `_ready()`, attempt to call each candidate; log which (if any) resolves; document outcome. Headless-verifiable on dev machine (likely `Vector4.ZERO` fallback if neither candidate exists in 4.6 desktop build); Android verification reactivation trigger ("when first Android export build green AND device with notch available"). MANDATORY this story per EPIC.md item-#5b classification
- [ ] **AC-9** Verification evidence #6: `production/qa/evidence/input_router_verification_06_touch_event_index_stability.md` exists describing physical-hardware test plan for two-finger gesture index assignment stability on iOS 17 + Android 14+. Polish-deferable per EPIC.md item-#6 + ADR-0005 §Verification Required Item 6 + Implementation Notes Advisory B; reactivation trigger: when physical-hardware available AND first iOS/Android export green. Headless fallback: synthetic-event injection test (story-009 AC-5 covers EC-1 multi-touch cancel via synthetic events)
- [ ] **AC-10** AC-9 GDD test reused — accidental-touch sweep: 5-case parametric Array[Dictionary] cases — for each (travel_px, hold_ms, expected_action) pair: (2, 50, "_rejected"), (2, 100, "unit_select"), (20, 100, "camera_pan"), (20, 50, "camera_pan" — travel dominates timing), (16.1, 50, "camera_pan" — boundary just-above)
- [ ] **AC-11** Regression baseline maintained: full GdUnit4 suite passes ≥823 cases (story-008 baseline) + new tests / 0 errors / 0 failures / 0 orphans / Exit 0; new test file `tests/unit/foundation/input_router_touch_part_b_test.gd` adds ≥10 tests covering AC-1..AC-7
- [ ] **AC-12** New BalanceConstants entries added: `PAN_ACTIVATION_PX = 16`, `MIN_TOUCH_DURATION_MS = 80` — 2 new keys with provenance comments

---

## Implementation Notes

*Derived from ADR-0005 §5 + §7 + CR-4f + CR-4g + CR-4h + EC-1 + EC-9 + F-3 + Implementation Notes Advisory B:*

1. **`_classify_pan_or_tap` helper**:
   ```gdscript
   const _PAN_ACTIVATION_PX_KEY: StringName = &"PAN_ACTIVATION_PX"
   const _MIN_TOUCH_DURATION_MS_KEY: StringName = &"MIN_TOUCH_DURATION_MS"

   func _classify_pan_or_tap(touch_travel_px: float, hold_duration_ms: int) -> StringName:
       var pan_threshold: float = float(BalanceConstants.get_const(_PAN_ACTIVATION_PX_KEY))
       var min_duration: int = int(BalanceConstants.get_const(_MIN_TOUCH_DURATION_MS_KEY))
       if touch_travel_px > pan_threshold:
           return &"camera_pan"
       if hold_duration_ms < min_duration:
           return &"_rejected"
       return &"unit_select"
   ```

2. **Touch tracking state (NEW fields)**: 4 transient fields needed for travel + duration tracking. Per `_pending_end_phase` (story-004) + `_pre_block_state` (story-007) precedent, classify as implementation-internal scratch state (NOT in ADR-0005 §1 6-field list):
   ```gdscript
   var _touch_start_pos: Vector2 = Vector2.ZERO  # set on InputEventScreenTouch.pressed=true
   var _touch_start_time_ms: int = 0
   var _touch_travel_px: float = 0.0  # accumulates from InputEventScreenDrag.relative magnitudes
   var _active_touch_indices: PackedInt32Array = []  # tracks which finger indices are down (multi-touch)
   ```
   G-15 reset obligation: `before_test()` resets all 4 to defaults. Story-010 lint enforces.

3. **Touch event handling extension** (`_handle_event` extends story-005):
   ```gdscript
   func _handle_event(event: InputEvent) -> void:
       # Step 1: mode determination (story-005)
       # ...
       # Step 2: touch tracking + multi-touch handling (story-009)
       if event is InputEventScreenTouch:
           var touch: InputEventScreenTouch = event
           if touch.pressed:
               if touch.index >= 1:
                   # Second+ finger arrival: EC-1 cancel + classify as gesture
                   _last_tap_unit_id = -1
                   _last_tap_time_ms = 0
                   _active_touch_indices.append(touch.index)
                   _handle_two_finger_gesture(touch)
                   return
               # First finger pressed: start tracking
               _touch_start_pos = touch.position
               _touch_start_time_ms = Time.get_ticks_msec()
               _touch_travel_px = 0.0
               _active_touch_indices.append(0)
           else:
               # Touch released: classify
               if touch.index == 0 and _active_touch_indices.size() == 1:
                   var hold_ms: int = Time.get_ticks_msec() - _touch_start_time_ms
                   var classified: StringName = _classify_pan_or_tap(_touch_travel_px, hold_ms)
                   _active_touch_indices.remove_at(_active_touch_indices.find(0))
                   if classified == &"_rejected":
                       return  # silent drop
                   # Fire action via InputMap match-or-direct dispatch
                   var ctx := _construct_input_context(touch)
                   _handle_action(classified, ctx)
                   _reset_touch_tracking()
                   return
               # Other index released: just remove from tracking
               var idx_pos: int = _active_touch_indices.find(touch.index)
               if idx_pos != -1:
                   _active_touch_indices.remove_at(idx_pos)
       elif event is InputEventScreenDrag:
           var drag: InputEventScreenDrag = event
           if drag.index >= 1:
               _handle_two_finger_gesture(drag)
               return
           if drag.index == 0:
               _touch_travel_px += drag.relative.length()
               # Continuous drag may also fire camera_pan during the drag (Battle HUD streams the motion)
               # ... per CR-4f
       # Step 3: standard action match (story-002 + 005)
       # ...
   ```

4. **`_handle_two_finger_gesture` helper**:
   ```gdscript
   func _handle_two_finger_gesture(event: InputEvent) -> void:
       # CR-4g: ALWAYS classified as camera operation (NEVER grid)
       var ctx := InputContext.new()
       if event is InputEventScreenDrag:
           # Pinch-zoom or two-finger pan
           _did_visible_work = true
           GameBus.input_action_fired.emit(&"camera_pinch_zoom", ctx)
       elif event is InputEventScreenTouch and event.pressed:
           # Two-finger tap = cancel pending first-finger interaction
           _did_visible_work = true
           GameBus.input_action_fired.emit(&"camera_two_finger_tap_cancel", ctx)
   ```
   Note: `&"camera_pinch_zoom"` + `&"camera_two_finger_tap_cancel"` are NEW actions outside ACTIONS_BY_CATEGORY's 22-action vocabulary. Per ADR-0005 CR-1d schema-evolution discipline, additive actions are permitted; story-009 same-patch adds these 2 to `ACTIONS_BY_CATEGORY` `camera` category (10 → 12 actions; 22 → 24 total) AND to `default_bindings.json` (camera_pinch_zoom → 2-finger pinch fixture; camera_two_finger_tap_cancel → 2-finger tap fixture). R-5 parity validation in story-002 still passes (24 declared - 1 PC-only = 23 expected; default_bindings.json size = 23).

5. **`_resolve_safe_area_api` 3-candidate fallback**:
   ```gdscript
   var _safe_area_inset: Vector4 = Vector4.ZERO

   func _resolve_safe_area_api() -> Vector4:
       # Candidate 1: window_get_safe_title_margins (plural per design-time Item 5)
       if DisplayServer.has_method(&"window_get_safe_title_margins"):
           var result: Variant = DisplayServer.call(&"window_get_safe_title_margins", DisplayServer.MAIN_WINDOW_ID)
           if result is Vector4:
               return result as Vector4
       # Candidate 2: get_display_safe_area (review-time Item 5)
       if DisplayServer.has_method(&"get_display_safe_area"):
           var result: Variant = DisplayServer.call(&"get_display_safe_area")
           if result is Rect2i:
               # Convert Rect2i to Vector4(left, top, right, bottom) margins
               var screen_size: Vector2i = DisplayServer.screen_get_size()
               var rect: Rect2i = result as Rect2i
               return Vector4(
                   float(rect.position.x),
                   float(rect.position.y),
                   float(screen_size.x - rect.position.x - rect.size.x),
                   float(screen_size.y - rect.position.y - rect.size.y)
               )
       # Fallback: desktop / no notch — zero margins
       return Vector4.ZERO
   ```
   Test: assert `_resolve_safe_area_api()` does not crash; returns either non-zero Vector4 (mobile with notch) or `Vector4.ZERO` (desktop / no API). Document observed value in evidence #5b.

6. **Persistent action panel positioning** (`_get_action_panel_position`):
   ```gdscript
   func _get_action_panel_position(state: InputState) -> Vector2:
       var viewport_size: Vector2i = DisplayServer.window_get_size()
       var safe_left: float = _safe_area_inset.x
       var safe_top: float = _safe_area_inset.y
       var safe_right: float = _safe_area_inset.z
       var safe_bottom: float = _safe_area_inset.w
       var usable_w: float = float(viewport_size.x) - safe_left - safe_right
       var usable_h: float = float(viewport_size.y) - safe_top - safe_bottom
       match state:
           InputState.UNIT_SELECTED, InputState.ATTACK_TARGET_SELECT:
               # Bottom-center; safe-area aware
               return Vector2(safe_left + usable_w * 0.5, safe_top + usable_h - 80.0)
           InputState.MOVEMENT_PREVIEW, InputState.ATTACK_CONFIRM:
               # Below confirm tile (anti-occlusion); requires Camera tile-screen-position info
               # MVP: bottom-third for now; Camera ADR will refine
               return Vector2(safe_left + usable_w * 0.5, safe_top + usable_h * 0.66)
           _:
               return Vector2(-1, -1)  # no panel in S0/S5/S6
   ```
   Battle HUD subscribes to a per-state-transition `input_action_fired(&"panel_reposition_request", ctx)` to call `InputRouter.get_action_panel_position(state)` and update the UI.

7. **Verification evidence #5b template** (`production/qa/evidence/input_router_verification_05b_safe_area_api.md`):
   ```markdown
   # InputRouter Verification #5b — Safe-Area API Name Resolution

   **Epic**: input-handling
   **Story**: story-009-touch-protocol-pan-tap-gestures-panel
   **ADR**: ADR-0005 §Verification Required §5b + delta #6 Item 5
   **Status**: Resolved (headless macOS) — observed [API_NAME or "neither candidate"]

   ## Test Procedure (Headless macOS)
   1. At test runtime, call `DisplayServer.has_method("window_get_safe_title_margins")`; log result
   2. If true, call the method + log return value
   3. Else, call `DisplayServer.has_method("get_display_safe_area")`; log result
   4. If true, call the method + log return value
   5. Else, document fallback `Vector4.ZERO` is correct for this build/platform
   6. Update this doc with the OBSERVED result

   ## Test Procedure (Android — Polish-deferable)
   1. Boot Android 14+ device with notch (e.g. Pixel 6+)
   2. Log safe-area inset values to debug overlay
   3. Compare against device's known notch dimensions
   4. Update this doc with confirmation

   ## Expected Result
   At least one of the 2 candidates resolves on Android 14+; fallback `Vector4.ZERO` acceptable for desktop. If neither resolves on Android, escalate as ADR-0005 §5b update — alternative API path required.

   ## Observed Result (macOS dev box)
   [TO BE FILLED AT IMPLEMENTATION TIME]

   ## Status
   Headless test in `tests/unit/foundation/input_router_touch_part_b_test.gd::test_safe_area_api_resolves_or_falls_back`. Mandatory per EPIC.md item-#5b. Android reactivation trigger: first Android export green + notch device.
   ```

8. **Verification evidence #6 template** (`production/qa/evidence/input_router_verification_06_touch_event_index_stability.md`):
   ```markdown
   # InputRouter Verification #6 — Touch Event Index Stability (Physical Hardware)

   **Epic**: input-handling
   **Story**: story-009-touch-protocol-pan-tap-gestures-panel
   **ADR**: ADR-0005 §Verification Required §6 + Implementation Notes Advisory B
   **Status**: Polish-deferred (physical hardware required)

   ## Test Procedure (Physical Device — Polish-deferable)
   1. Boot iOS 17 device + Android 14+ device with running app
   2. Place 2 fingers on screen sequentially: finger 1 first, finger 2 second
   3. Verify `InputEventScreenTouch.index == 0` for finger 1 + `index == 1` for finger 2
   4. Lift finger 1 (still finger 2 down)
   5. Verify finger 2 STILL has `index == 1` (NOT reassigned to 0)
   6. Lift finger 2; place 2 fresh fingers
   7. Verify indices restart from 0 (post-clear)

   ## Expected Result
   OS-assigned indices stable through multi-touch sequence; not reassigned on any single-finger lift. Confirms CR-4g + EC-1 multi-touch cancel logic in story-009.

   ## Polish-Deferral Rationale
   Headless GdUnit4 test (`test_two_finger_gesture_cancels_first_finger_tpp`) injects synthetic events with manually-set `.index` field and verifies cancel logic; production rule depends on OS-assigned index stability which only physical hardware can confirm. Reactivation trigger: when iOS 17 + Android 14+ device available AND first iOS/Android export green.

   ## Status
   Headless coverage: `tests/unit/foundation/input_router_touch_part_b_test.gd::test_two_finger_gesture_cancels_first_finger_tpp`. Polish-deferral pattern (5+ precedent).
   ```

9. **Test file**: `tests/unit/foundation/input_router_touch_part_b_test.gd` — 10-12 tests covering AC-1..AC-7. Pattern: GdUnitTestSuite Node-based; full G-15 reset + 4 new touch-tracking fields reset (`_touch_start_pos`, `_touch_start_time_ms`, `_touch_travel_px`, `_active_touch_indices`); inject synthetic InputEventScreenTouch + InputEventScreenDrag instances directly; `Time.get_ticks_msec()` mocking via `_test_now_ms` test seam if needed.

10. **2 new BalanceConstants additions**:
    ```jsonc
    // PAN_ACTIVATION_PX owned by Input Handling; F-3 pan threshold (CR-4f)
    "PAN_ACTIVATION_PX": 16,
    // MIN_TOUCH_DURATION_MS owned by Input Handling; F-3 accidental-touch rejection (CR-4f)
    "MIN_TOUCH_DURATION_MS": 80,
    ```

11. **2 new actions added to ACTIONS_BY_CATEGORY** (CR-1d additive evolution):
    ```gdscript
    # Update story-002's ACTIONS_BY_CATEGORY:
    &"camera": [&"camera_pan", &"camera_zoom_in", &"camera_zoom_out", &"camera_snap_to_unit",
                &"camera_pinch_zoom", &"camera_two_finger_tap_cancel"],  # +2 from story-009
    ```
    Plus 2 default_bindings.json entries (touch fixtures only — no PC binding for these gestures).

12. **G-22 verification reminder**: AC-8 + AC-9 evidence docs follow the project-wide template — header / test procedure / expected result / status / observed result. Use the structural-source-file pattern for assertions about doc presence (FileAccess + content.contains).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 010**: Epic terminal — perf baseline + 6+ forbidden_patterns lints + `lint_emulate_mouse_from_touch.sh` wiring + `lint_balance_entities_input_handling.sh` + DI test seam G-15 validation lint covering all 4 new touch-tracking fields + 3 TD entries (Polish-tier on-device verification + provisional-contract advisory + ADR-0001 line 168 amendment)

---

## QA Test Cases

*Authored inline (lean mode QL-STORY-READY skip).*

- **AC-1**: `_classify_pan_or_tap` 3-way classification
  - Given: BalanceConstants `PAN_ACTIVATION_PX=16`, `MIN_TOUCH_DURATION_MS=80`
  - When: `_classify_pan_or_tap(20, 100)` → returns `&"camera_pan"`; `(2, 50)` → `&"_rejected"`; `(2, 100)` → `&"unit_select"`
  - Then: matches per F-3
- **AC-2**: AC-8 GDD test (pan classification end-to-end)
  - Given: synthetic InputEventScreenTouch (pressed) → InputEventScreenDrag with relative (20, 0) → InputEventScreenTouch (released) within 100ms
  - When: each event injected via `_handle_event`
  - Then: `input_action_fired(&"camera_pan", ctx)` captured; no state change
- **AC-3**: AC-9 GDD test (accidental rejection)
  - Given: synthetic touch press → release after 50ms with 0 travel
  - When: events injected
  - Then: 0 emits captured (silent drop); `_did_visible_work == false`
- **AC-4**: Two-finger gesture routing
  - Given: synthetic InputEventScreenTouch with `index=1, pressed=true` AND prior `_last_tap_unit_id = 5`
  - When: event injected
  - Then: `input_action_fired(&"camera_two_finger_tap_cancel", ctx)` captured; `_last_tap_unit_id == -1` (EC-1 cancel)
- **AC-5**: EC-1 multi-touch cancel
  - Given: TPP active (`_last_tap_unit_id = 5`) in S0
  - When: second-finger touch arrives
  - Then: `_last_tap_unit_id == -1`; first-finger second-tap NO LONGER advances to S1
- **AC-6**: Safe-area API resolution
  - Given: `_resolve_safe_area_api()` invoked at `_ready()`
  - When: 3 candidates checked
  - Then: returns Vector4 (either non-zero from a resolved candidate OR `Vector4.ZERO` fallback); no crash
  - Edge cases: assert `_safe_area_inset` cached value matches return
- **AC-7**: Action panel positioning safe-area-aware
  - Given: viewport 1280x720, safe-area inset (0, 80, 0, 60) (notch top + nav bar bottom)
  - When: `_get_action_panel_position(InputState.UNIT_SELECTED)` invoked
  - Then: returns Vector2 with x within usable width, y above bottom-safe-area
  - Edge cases: S0/S5/S6 → returns (-1, -1) (no panel)
- **AC-8**: Verification evidence #5b doc + headless test
  - Given: doc exists
  - When: read content
  - Then: Status field present; Observed Result field present (filled at implementation time)
- **AC-9**: Verification evidence #6 doc
  - Given: doc exists
  - When: read content
  - Then: Status: Polish-deferred; reactivation trigger documented
- **AC-10**: Sweep
  - Given: 5-case parametric Array[Dictionary]
  - When: each scenario fed to `_classify_pan_or_tap`
  - Then: result matches expected
- **AC-11**: Regression baseline
  - Given: full suite invoked
  - When: 823 + new tests run
  - Then: ≥833 tests / 0 errors / 0 failures / 0 orphans / Exit 0
- **AC-12**: 2 new BalanceConstants present
  - Given: balance_entities.json
  - When: parse + check for `PAN_ACTIVATION_PX` + `MIN_TOUCH_DURATION_MS`
  - Then: both present with values 16, 80; provenance comments present

---

## Test Evidence

**Story Type**: Integration (multi-system: pan-vs-tap classifier + safe-area + persistent panel positioning span InputRouter + DisplayServer + Camera/BattleHUD subscribers)
**Required evidence**:
- Integration: `tests/unit/foundation/input_router_touch_part_b_test.gd` — must exist + ≥10 tests + must pass
- Visual/Feel: `production/qa/evidence/input_router_verification_05b_*.md` (status: Resolved on dev) + `_06_*.md` (status: Polish-deferred)
- Same-patch: 2 new BalanceConstants + 2 new ACTIONS_BY_CATEGORY entries + 2 new default_bindings.json entries

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 008 (touch part A — TPP state tracking fields + `_construct_input_context`); Story 005 (mode determination — pan-vs-tap classifier extends touch event handling)
- **Unlocks**: Story 010 (epic terminal — perf baseline includes pan-vs-tap classifier throughput; lint covers all 4 new touch-tracking fields in G-15 reset enforcement); Battle HUD epic (consumes pinch_zoom + two_finger_tap_cancel + panel_reposition_request signals)
