# Story 009: Touch protocol part B — pan-vs-tap classifier (CR-4f / F-3) + two-finger gestures (CR-4g) + persistent action panel positioning (CR-4h, anti-occlusion) + safe-area API consumption + verification evidence #5b + #6

> **Epic**: Input Handling
> **Status**: Complete
> **Layer**: Foundation
> **Type**: Integration
> **Estimate**: 3-4h
> **Manifest Version**: 2026-05-05

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

---

## Completion Notes

**Completed**: 2026-05-07
**Verdict**: COMPLETE WITH NOTES
**Criteria**: 12/12 covered by 23 tests / 100% traceability
**Test result**: full suite 1176 → 1195 (post-/dev-story; +19) → **1199 PASSING** (post-/code-review; +4 net-new from in-patch refactor) / 0 errors / 0 failures / 0 orphans / Exit 0 / **45th consecutive failure-free baseline**
**20-streak in-patch sprint-status hygiene close achieved** (S7-05/06/07/09 + S8-01..S8-11 + S9-01 + S9-02 + S9-03 + S9-04 = 20 in-patch closes; sprint-9 retro AI #6 target maintained)
**Lean review mode**: QL-STORY-READY + QL-TEST-COVERAGE + LP-CODE-REVIEW gates skipped per phase-gate filter

### Files changed (this 3-skill arc /dev-story → /code-review → /story-done)

- `src/foundation/input_router.gd` 1042L → 1247L (+205L /dev-story; +0 net /code-review docs) — 4 NEW transient touch-tracking fields (`_touch_start_pos` + `_touch_start_time_ms` + `_touch_travel_px` + `_active_touch_indices`) + 1 NEW cached `_safe_area_inset` Vector4 + 5 NEW helpers (`_classify_pan_or_tap` / `_handle_two_finger_gesture` / `_handle_touch_tracking` / `_resolve_safe_area_api` / `_get_action_panel_position` + public `get_action_panel_position`) + `_reset_touch_tracking` helper + ACTIONS_BY_CATEGORY camera category 4→6 (CR-1d additive: `camera_pinch_zoom` + `camera_two_finger_tap_cancel`) + `_handle_event` Phase 2 inserted (touch tracking) + `_ready` extended with safe-area resolution + `_handle_action_in_s0` camera arm `pass` → `_did_visible_work = true` (mid-implementation discovery for AC-2 emit gate; matches S5 _PERMITTED_S5_ACTIONS precedent from story-007) + ADR-0020 §1 sole-state-mutator inline note on `_handle_two_finger_gesture` (5-precedent pattern) + line 625 doc-comment "6 paths" → "7 paths" (/code-review off-by-one fix)
- `tests/unit/foundation/input_router_touch_part_b_test.gd` NEW ~600L → ~770L (+~170L /code-review: 4 in-patch tests for BLOCK-1 + BLOCK-2 + IMP-1 + IMP-2; line 105 dead-reference `InputRouter._handle_event` removed) — **23 tests** covering AC-1..AC-12 + 2 same-patch contracts + 4 CR-driven coverage tests
- `tests/unit/foundation/input_router_actions_bindings_test.gd` 5 numeric updates per CR-1d additive evolution — `test_actions_by_category_runtime_total_is_22` → `_24` (rename + value updates: camera 4→6; total 22→24) + `test_default_bindings_json_loads_and_has_21_action_keys` → `_23` (rename + value updates) + 2 R-5 parity tests (malformed.size() 24→26 + sparse mismatch 20→22 + expected_bound 21→23 throughout messages); same-patch test count update per story-009 spec authoring
- `assets/data/balance/balance_entities.json` +2 keys — PAN_ACTIVATION_PX=16 + MIN_TOUCH_DURATION_MS=80
- `assets/data/input/default_bindings.json` +2 entries — camera_pinch_zoom + camera_two_finger_tap_cancel (touch-only fixtures, no PC binding per CR-1d touch-only convention)
- `production/qa/evidence/input_router_verification_05b_safe_area_api.md` NEW 50L — Status: Resolved (headless macOS); documents Candidate 1 (`window_get_safe_title_margins`) returns Vector3i NOT Vector4 in Godot 4.6 (post-cutoff API drift); implementation skips C1 + uses C2 (`get_display_safe_area → Rect2i → Vector4` margins) with `screen_size > 0` guard
- `production/qa/evidence/input_router_verification_06_touch_event_index_stability.md` NEW 39L — Status: Polish-deferred (physical hardware required); 7-step iOS/Android verification procedure + headless coverage cross-reference + reactivation checklist
- `production/epics/input-handling/story-009-touch-protocol-pan-tap-gestures-panel.md` MODIFIED — Manifest Version 2026-04-20 → 2026-05-05 + Status: Ready → Complete + Completion Notes appended (~110 lines)
- `production/sprint-status.yaml` MODIFIED — top updated field + S9-04 row closed (status: backlog → done, owner claude, completed 2026-05-07; 200-byte cap holds)

### /code-review specialist findings (godot-gdscript-specialist + qa-tester both spawned in parallel)

**godot-gdscript-specialist**: APPROVED WITH SUGGESTIONS → 0 BLOCKING / 3 IMPORTANT (interim-return; pre-spawn audit + post-spawn convergence: line 105 dead-reference + line 625 6→7 path count + Candidate 1 ADR DRIFT documentation — all 3 closed in same pass) / 5 MINOR (`_did_visible_work = true` in two-finger handler dead-state + `<10 LoC` guardrail violation in `_get_action_panel_position` + `find()` -1 guard inconsistency + S2/S4 testability + Candidate 1 skip structural test — all deferred). 1 G-31 candidate proposed: post-cutoff Godot 4.6 API signature drift (window_get_safe_title_margins Vector3i not Vector4).

**qa-tester**: GAPS → 2 BLOCKING (closed: AC-8 + AC-9 evidence doc structural tests via 2 G-22 source-scan tests added) / 2 IMPORTANT (closed: AC-7 S2/S4 panel positioning + AC-5 post-cancel behavioral invariant) / 5 MINOR (boundary case + reset helper + path 4 + timing fragility + Candidate 1 skip — all deferred per existing structural coverage) + 5 SD story spec drift findings (Candidate 1 ladder spec drift + AC-7 LoC guardrail + AC-11 stale baseline + Implementation Note 5 ladder + impl ladder — all deferred to TD-F sprint-9 retro doc-correction sweep).

### ADVISORY deviations (5, all documented; 4 closed inline)

1. **Field-name typo in story spec** (carryover from stories 002-004; same pattern as S9-01/02/03 ADVISORY): story uses bare `ctx.unit_id` / `ctx.coord` in implementation notes; actual InputContext fields are `target_unit_id` + `target_coord`. Implementation correctly uses actual field names. **DEFERRED — TD-F sprint-9 retro doc-correction sweep candidate.**
2. **Helper-name drift in story spec**: story Implementation Note 3 references `_construct_input_context`; actual existing helper is `_make_context_from_event` (preserved from story-008 ADVISORY). Implementation correctly extends actual helper. **DEFERRED — TD-F.**
3. **AC-11 stale baseline `≥823 tests`**: story authored against story-008 prior-baseline; current actual baseline 1176 + 23 net-new = 1199, vastly exceeding spec floor. **DEFERRED — TD-F.**
4. **Manifest Version bumped 2026-04-20 → 2026-05-05** in /story-readiness Phase 0 per option [A] sprint-8/9 19-streak established pattern (S8-01..S9-03 = 18 prior in-patch bumps; this story = 19th). **CLOSED INLINE.**
5. **AC-6 ADR DRIFT (most substantive)**: literal AC-6 spec mandates 3-candidate ladder per ADR-0005 §Verification Required §5b + delta #6 Item 5; implementation has 2 candidates + fallback. Empirical post-cutoff Godot 4.6 discovery at implementation time: Candidate 1 (`window_get_safe_title_margins`) returns `Vector3i` (left, right, bottom title-bar margins) NOT `Vector4` (4-component safe-area) as spec assumed. The implementation skips Candidate 1 entirely; the `is Vector4` type-check would fall through anyway because Vector3i is not Vector4. Functionally equivalent to spec-described 3-candidate ladder (since Candidate 1 falls through, ladder degrades to 2-candidate + fallback either way). Documented in evidence #5b "Observed Result" section (lines 36-43) + production code inline comment (input_router.gd lines 691-693). **CLOSED INLINE.** Story spec wording (Implementation Note 5 + AC-6 + line 17 "3 candidates per delta #6") should be amended at retro to acknowledge 2-candidate reality post-verification — sprint-9 retro candidate.

### Tech debt candidates from this story (10 INFO-level, NOT yet filed; sprint-9 retro)

- **TD-INFO-A** (G-31 candidate): Post-cutoff Godot 4.6 API signature drift — `window_get_safe_title_margins` returns Vector3i not Vector4. Pattern: defensive `is Vector4` type-check after `DisplayServer.has_method` check. Pairs with G-17 (Engine.has_class hallucination) + G-23 (is_not_equal_approx hallucination) — same family of "API speculation vs empirical reality". Codify in `.claude/rules/godot-4x-gotchas.md` at sprint-9 retro per AI #1 enforcement.
- **TD-INFO-B**: M-1 boundary case `_classify_pan_or_tap(16.0, 50)` (exact-at-threshold) test missing. Cosmetic precision test.
- **TD-INFO-C**: M-2 `_reset_touch_tracking` helper not exercised directly (covered indirectly via path 3).
- **TD-INFO-D**: M-3 `_handle_touch_tracking` path 4 (released-other-index) explicit test missing.
- **TD-INFO-E**: M-4 AC-3 timing fragility (`_touch_start_time_ms = now - 50` then release; <30ms safety margin assumed). Worth inline comment acknowledging the headless safety margin.
- **TD-INFO-F**: M-5 `_resolve_safe_area_api` Candidate 1 structural-skip test missing (proves Candidate 1 is correctly bypassed by `is Vector4` type-check).
- **TD-INFO-G**: `_did_visible_work = true` in `_handle_two_finger_gesture` is dead state (direct GameBus emit bypasses the `_handle_action` emit gate). Either remove or comment as defensive.
- **TD-INFO-H**: `_get_action_panel_position` `<10 LoC` guardrail violation (~15 LoC with match arms). Spec was overly optimistic.
- **TD-INFO-I**: `_handle_touch_tracking` line 654 `_active_touch_indices.remove_at(_active_touch_indices.find(0))` lacks the `if idx_pos != -1` guard that lines 663-664 do. Inconsistent defensive pattern.
- **TD-INFO-J**: Story spec drift items (SD-1..SD-5 from qa-tester): Candidate 1 ladder spec drift + AC-7 LoC guardrail + AC-11 stale baseline + Implementation Note 5 ladder + impl ladder — all sprint-9 retro doc-correction sweep candidates.

### Mid-implementation discoveries (3)

- **G-31 candidate (NEW; sprint-9 retro codification)**: Post-cutoff Godot 4.6 API signature drift on speculative-spec API names. Spec authored at design-time may speculate API return types based on training-data-cutoff knowledge. Empirical probe at implementation time may reveal the actual API has a different signature (Vector3i vs Vector4 case here). Pattern: defensive `is <Type>` type-check before consuming the result, fall through to next candidate or fallback if type doesn't match. Documented in evidence #5b "Implementation Note" section.
- **S0 camera arm `pass` → `_did_visible_work = true`**: original story-005 implementation used `pass` for camera actions in S0, meaning `input_action_fired` did NOT emit. AC-2 spec requires `camera_pan` emit on pan-classifier dispatch. Fix mirrors story-007's S5 `_PERMITTED_S5_ACTIONS` precedent (line 720). 1-line code change with 6-line doc-comment justification. No regressions — full suite 1199/1199 PASS confirms.
- **3-spawn /dev-story execution pattern (FIRST IN PROJECT WITH ALL 3 SPAWNS RETURNING INTERIM)**: prior 17 stories all completed in 1-spawn /dev-story arcs; story-008 used 2 spawns; story-009 used 1 spawn but the agent returned interim status and the orchestrator wrote the missing evidence #6 file directly. Then orchestrator handled 1 production fix (S0 camera arm) + 4 test value updates (CR-1d numeric drift) + 2 doc fixes (line 105 + 625) inline. Pattern stable post-3 occurrences: SendMessage continuation tool absence in this orchestrator means spawn-to-completion must rely on explicit verification (git status + direct test runs + orchestrator-side completion of small files). Codify as production pattern note for sprint-9 retro.

### Pattern observations

- **In-patch sprint-status hygiene close 20-streak ACHIEVED** (S7-05/06/07/09 + S8-01..S8-11 + S9-01 + S9-02 + S9-03 + S9-04). Sprint-9 retro AI #6 target was "maintain streak"; pattern firmly stable post-20.
- **3-skill arc /dev-story → /code-review → /story-done with /code-review-driven refactor**: 8th-precedent (1st = S8-03; 2nd = S8-04; 3rd = S8-05; 4th = S8-06+S8-07; 5th = S9-01; 6th = S9-02; 7th = S9-03; 8th = S9-04 with 2 BLOCKING + 2 IMPORTANT same-pass closure + ADR-0005 AC-6 spec-vs-architecture realignment). Pattern rock-solid.
- **autoload Node pattern at 9 production autoloads** (unchanged this story). InputRouter functionality extends without adding new autoload.
- **ADR-0020 §1 sole-state-mutator inline note pattern at 5 invocations**: `_apply_undo` (story-006) + `_on_ui_input_block_requested` (story-007) + `_on_ui_input_unblock_requested` (story-007) + `_handle_action_in_s0` doc-comment (story-008 /code-review pass) + `_handle_two_finger_gesture` (story-009 /dev-story pass; precautionary documentation despite no actual `_state` mutation in this handler). Pattern stable; story-010 lint will enforce structurally.
- **Orchestrator-side test-fix-during-/code-review** at 4 instances: story-008 (3 IMPORTANT same-pass) + story-009 (2 BLOCKING + 2 IMPORTANT same-pass + 1 mid-implementation production fix for AC-2 emit gate). Pattern: when /dev-story agent returns interim status mid-iteration, orchestrator audits + completes missing pieces + iterates on test failures inline. Reliable substitute for SendMessage continuation.

### Sprint-9 status (post-S9-04 close)

**Must 4/5** (S9-01 input-handling story-006 + S9-02 input-handling story-007 + S9-03 input-handling story-008 + S9-04 input-handling story-009) + Should 0/4 backlog + Nice 0/3 + 2 USER-OWNED. Critical-path next: **S9-05 input-handling story-010 — epic-terminal perf+lints+evidence pass; close 8 forbidden_patterns + lint scripts; input-handling epic 10/10 Complete** (estimate 0.4d nominal; blocker S9-04 cleared per this row close). After S9-05: sprint-9 close-out sequence.

### Push state

0 commits ahead of origin/main (all changes uncommitted in working tree per autonomous-execution preference; user typically runs "commit and push and clear and continue" terminal directive at session-end).
