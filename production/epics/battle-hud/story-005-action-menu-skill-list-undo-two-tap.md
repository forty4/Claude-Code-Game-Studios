# Story 005: UI-GB-02 Action Menu + UI-GB-05 Skill List + UI-GB-10 Undo + Two-Tap ATTACK/DEFEND

> **Epic**: Battle HUD
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI + Integration
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/ux/battle-hud.md` v1.1 §3 UI-GB-02 + UI-GB-05 + UI-GB-10 + §5 Two-Tap Confirm Flows
**Requirement**: `TR-battle-hud-005` (UI-GB-02/05/10 partial), `TR-battle-hud-017` (two-tap timer ownership)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0015 Battle HUD §4 + §5 + §OQ-4 (Accepted 2026-05-03)
**ADR Decision Summary**: UI-GB-02 Action Menu shows MOVE/ATTACK/USE_SKILL/DEFEND/WAIT/END_TURN buttons for the selected unit; greys out actions whose tokens are spent. Subscribes `unit_selected_changed` + `unit_turn_started`. UI-GB-05 Skill List is a sub-panel of UI-GB-02 surfaced when USE_SKILL is selected. UI-GB-10 Undo Indicator visible during S3 PLAYER_TURN_ACTIVE + ACTION_PENDING (per battle-hud.md §3 UI-GB-10). Two-tap ATTACK/DEFEND mobile confirm: HUD owns the `_two_tap_timer: Timer` + `_two_tap_target_action: StringName`; on second tap within `TWO_TAP_TIMEOUT_S` window, HUD invokes `_input_router._handle_event(synthetic_action_confirm_event)` per ADR-0015 §OQ-4.

**Engine**: Godot 4.6 | **Risk**: MEDIUM (Timer + synthetic event injection through DI'd InputRouter test seam)
**Engine Notes**:
- `_input_router._handle_event(InputEvent)` is the InputRouter test seam (per ADR-0005 lines 235-236 ratified by ADR-0015 §4). Must verify shipped state at story-author time per epic R-3.
- Synthetic event creation: `InputEventAction.new()` with `action = StringName("attack_confirm")` + `pressed = true`. Verify InputRouter accepts InputEventAction — if it requires a domain-specific event type, adjust per InputRouter API.
- `Timer` node added as child of HUD root or as a script-instantiated `Timer` instance with `one_shot = true`, `wait_time = TWO_TAP_TIMEOUT_S` from BalanceConstants OR battle-hud.md §5 if ADR-0006 doesn't yet hold the key (scope: BalanceConstants entry creation is story-006 with FORECAST_RENDER_BUDGET_MS — TWO_TAP_TIMEOUT_S can be a battle-hud-local const for MVP per battle-hud.md §10 Tuning Knobs ownership).

**Control Manifest Rules (Presentation layer)**:
- Required: 44pt minimum touch target on all 6 action buttons (MOVE/ATTACK/USE_SKILL/DEFEND/WAIT/END_TURN) + skill-slot buttons + undo button — story-008 lint enforces.
- Forbidden (registry): `battle_hud_signal_emission` (synthetic event injection is via DI'd backend method call, NOT a GameBus emit).
- Guardrail: Timer overhead ≈ 0 ms (Godot Timer is engine-native, no GD-script per-frame poll); two-tap latency budget ≈ 16 ms p99 (1 frame).

---

## Acceptance Criteria

*From battle-hud.md §3 UI-GB-02/05/10 + §5 + ADR-0015 §4 + §OQ-4 + R-5 + AC-UX-HUD-08 + AC-UX-HUD-09:*

- [ ] `scenes/battle/elements/ui_gb_02_action_menu.tscn` exists with VBoxContainer or HBoxContainer + 6 Buttons: MOVE, ATTACK, USE_SKILL, DEFEND, WAIT, END_TURN. Each Button has `custom_minimum_size = Vector2(44, 44)` minimum.
- [ ] `scenes/battle/elements/ui_gb_05_skill_list.tscn` exists with PanelContainer + VBoxContainer holding 2 skill slot Buttons (cooldown indicator + range indicator child Controls).
- [ ] `scenes/battle/elements/ui_gb_10_undo_indicator.tscn` exists with Button + Label "Undo".
- [ ] `_ui_elements[&"UI-GB-02"]`, `_ui_elements[&"UI-GB-05"]`, `_ui_elements[&"UI-GB-10"]` populated in `_ready()`. UI-GB-02 starts hidden; UI-GB-05 starts hidden (sub-panel of UI-GB-02); UI-GB-10 starts hidden.
- [ ] `_on_unit_selected_changed(unit_id, was_selected)` body extension:
  - if `was_selected == true` AND unit is the active player unit per turn order: shows UI-GB-02 anchored near the unit
  - else: hides UI-GB-02 + UI-GB-05
- [ ] `_on_unit_turn_started(unit_id)` body extension: greys out spent-token actions per turn-state (MOVE token + ACTION token tracking).
- [ ] `_on_unit_moved(unit_id, from, to)` body extension: shows UI-GB-10 Undo Indicator if `unit_id` is the active unit AND ACTION token unspent (per battle-hud.md §3 UI-GB-10 visibility contract).
- [ ] UI-GB-02 button click handlers wired to invoke synthetic events through `_input_router._handle_event(...)`:
  - MOVE button → emit synthetic InputEventAction("move_action")
  - ATTACK button → start two-tap window: stores `_two_tap_target_action = &"attack"`, starts `_two_tap_timer`, hint shown to user (button modulate boost or label "Tap again to confirm")
  - DEFEND button → same two-tap pattern with `_two_tap_target_action = &"defend"`
  - USE_SKILL → reveals UI-GB-05; click handlers for skill slots invoke synthetic `skill_use` event
  - WAIT → invokes synthetic `wait_action` event
  - END_TURN → invokes synthetic `end_turn_action` event
- [ ] Two-tap state machine:
  - First tap on ATTACK or DEFEND: `_two_tap_target_action` set, `_two_tap_timer.start(TWO_TAP_TIMEOUT_S)`, button visual shows pending state
  - Second tap on the SAME action within timer window: emits synthetic confirm event via `_input_router._handle_event(...)`, clears `_two_tap_target_action`, stops timer
  - Tap on different action OR timer.timeout: clears `_two_tap_target_action`, removes pending visual
  - `_two_tap_timer.timeout` signal connected to `_on_two_tap_timeout()` handler in `_ready()` (per CONNECT_DEFERRED if applicable; Timer.timeout traditionally non-deferred OK — but follow ADR-0001 §5 mandate uniformly)
- [ ] UI-GB-10 Undo Button click invokes synthetic `undo_action` event via `_input_router._handle_event(...)`.
- [ ] No `GameBus.*.emit` calls anywhere — cross-system events flow through `_input_router._handle_event()` per non-emitter discipline.
- [ ] All visible button labels via `tr()` (e.g., `tr(&"hud.action.move")`).
- [ ] All buttons have `custom_minimum_size.x ≥ 44 AND custom_minimum_size.y ≥ 44` (story-008 lint enforces; this story authors compliantly from start).

---

## Implementation Notes

*Derived from ADR-0015 §4 + §OQ-4 + battle-hud.md §5 Two-Tap Confirm Flows:*

1. **Two-tap timer ownership** (ADR-0015 §OQ-4 contract — codified): HUD OWNS the timer; InputRouter receives a synthetic event upon confirm. HUD never authors the cross-system payload directly. Pattern boundary: cross-system events HUD initiates flow back through InputRouter as synthetic events per non-emitter discipline (TR-battle-hud-007).

2. **Timer instantiation strategy** — single `_two_tap_timer: Timer` field instantiated in `_ready()` (or as a child node in `battle_hud.tscn`). `one_shot = true`, `wait_time = TWO_TAP_TIMEOUT_S`. Connect `timeout` signal to `_on_two_tap_timeout()`. Timer instance is shared across both ATTACK and DEFEND two-tap flows since they cannot overlap (one active action at a time).

3. **`TWO_TAP_TIMEOUT_S` constant** — owned by battle-hud.md §10 Tuning Knobs per ADR-0015 OQ-4 ("ADR commits to architectural pattern, NOT timer durations"). For MVP, declare as `const TWO_TAP_TIMEOUT_S: float = 0.6` in battle_hud.gd OR as a BalanceConstants entry (preferred) — verify with battle-hud.md §10. Default 600ms is the GDD value at time of writing; treat as Alpha-tier (range tunable post-soak).

4. **Synthetic event factory** — helper method:
   ```gdscript
   func _make_synthetic_action_event(action_name: StringName, pressed: bool = true) -> InputEventAction:
       var ev := InputEventAction.new()
       ev.action = action_name
       ev.pressed = pressed
       return ev
   ```
   Then `_input_router._handle_event(_make_synthetic_action_event(&"attack_confirm"))` on confirm tap. Verify InputRouter `_handle_event` accepts InputEventAction or requires domain-specific event type at story-author time.

5. **Token-spend grey-out logic** — UI-GB-02 Action Menu button enabled state derived from active-unit token state. Active unit's MOVE-token + ACTION-token state needs a query method on either GridBattleController or TurnOrderRunner. Verify exact method name at author time; if absent, this story raises a same-patch addendum to ADR-0014 OR uses `_grid_controller.is_action_available(unit_id, action_name) -> bool` query (assume present per registry).

6. **Anchor positioning** — UI-GB-02 anchors near the selected unit. Use `_camera.get_canvas_transform() * world_pos` (per godot-specialist advisory D — Camera2D 4.6 lacks `world_to_screen()`) to position UI-GB-02 in screen-space relative to unit's world position. Apply offset to keep menu off-screen-edge.

7. **UI-GB-10 Undo visibility lifecycle** — driven by `_on_unit_moved` (show, if active unit + action unspent) AND `_on_battle_outcome_resolved` / `_on_unit_turn_ended` (hide). Visible-while-MOVE-token-spent-but-ACTION-token-unspent semantics — verify with `_grid_controller.is_undo_available(unit_id) -> bool` query at author time.

8. **i18n locale keys** (declare in same patch):
   - `hud.action.move` → "Move"
   - `hud.action.attack` → "Attack"
   - `hud.action.use_skill` → "Use Skill"
   - `hud.action.defend` → "Defend"
   - `hud.action.wait` → "Wait"
   - `hud.action.end_turn` → "End Turn"
   - `hud.action.attack_pending` → "Attack — Tap again to confirm"
   - `hud.action.defend_pending` → "Defend — Tap again to confirm"
   - `hud.undo.label` → "Undo"

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 006: UI-GB-04 Combat Forecast (renders alongside UI-GB-02 ATTACK pending state but is a separate element).
- Story 007: UI-GB-06 Tile Info + UI-GB-09 Results + UI-GB-12/13/14 grid-overlays.
- Story 008: 44pt CI lint validates this story's button sizes; non-emitter lint validates zero `.emit` calls.

---

## QA Test Cases

*UI + Integration story — automated tests for state transitions; manual for visual anchoring.*

- **AC-1: Three elements mount at _ready()**
  - Setup: instantiate BattleHUD + setup() flow
  - Verify: `_ui_elements[&"UI-GB-02/05/10"]` all non-null + child of hud root + `visible == false` by default
  - Pass condition: assertions pass

- **AC-2: unit_selected_changed shows UI-GB-02 for active player unit**
  - Given: turn_runner stub with active unit_id = 42 + turn-state ACTIVE; grid_controller stub returning `is_action_available(42, _) → true` for all actions
  - When: `_grid_controller.unit_selected_changed.emit(42, true)` (deferred → flush)
  - Then: UI-GB-02 visible == true; all 6 action Buttons enabled (modulate.a == 1.0)
  - Edge cases: emit `(99, true)` where 99 is NOT active unit — UI-GB-02 stays hidden (selection of inactive units shows UI-GB-03 only, no action menu)

- **AC-3: Two-tap ATTACK flow — first tap arms, second tap within window confirms**
  - Given: AC-2 happy state, UI-GB-02 visible
  - When: ATTACK button pressed (first tap)
  - Then: `_two_tap_target_action == &"attack"`, `_two_tap_timer.is_stopped() == false`, ATTACK button shows pending visual (text changes or modulate boost)
  - When: ATTACK button pressed again before `TWO_TAP_TIMEOUT_S` elapses
  - Then: `_input_router._handle_event(...)` invoked exactly once with InputEventAction(action=&"attack_confirm", pressed=true) (assert via input_router stub recording calls); `_two_tap_target_action == &""`, timer stopped
  - Edge cases: assert `_two_tap_timer.timeout` signal NOT fired before second tap (test introspects via `is_stopped()` after second tap)

- **AC-4: Two-tap DEFEND flow — same pattern as ATTACK**
  - Given: AC-2 happy state
  - When: DEFEND button first tap → DEFEND button second tap within window
  - Then: `_input_router._handle_event(InputEventAction(&"defend_confirm"))` called once
  - Edge cases: tap ATTACK first then DEFEND second (different action) → first arm cancelled; DEFEND becomes new arm (single second tap on DEFEND → confirms DEFEND, not ATTACK)

- **AC-5: Two-tap timer.timeout cancels the pending action**
  - Given: ATTACK button pressed once (armed)
  - When: simulate `_two_tap_timer.timeout` signal emit (or wait `TWO_TAP_TIMEOUT_S` real time in headless mode — prefer manual timeout invoke for determinism)
  - Then: `_two_tap_target_action == &""`, ATTACK button visual reverts, NO `_input_router._handle_event` call has been made for attack_confirm
  - Edge cases: tap a non-ATTACK/DEFEND action while ATTACK armed (e.g., MOVE) — cancel arm; MOVE invokes its own synthetic event

- **AC-6: UI-GB-10 Undo shows on unit_moved when undo_available**
  - Given: grid_controller stub returning `is_undo_available(42) → true`
  - When: `_grid_controller.unit_moved.emit(42, Vector2i(2,3), Vector2i(3,3))` (deferred → flush)
  - Then: UI-GB-10 visible == true
  - When: Undo button clicked
  - Then: `_input_router._handle_event(InputEventAction(&"undo_action"))` called once
  - Edge cases: `is_undo_available(42) → false` after action committed → UI-GB-10 visible == false on next signal sweep

- **AC-7: UI-GB-05 Skill List reveals on USE_SKILL**
  - Given: AC-2 happy state
  - When: USE_SKILL button clicked
  - Then: UI-GB-05 visible == true; both skill slot Buttons rendered (assert child count of UI-GB-05 VBoxContainer)
  - When: skill slot Button clicked
  - Then: `_input_router._handle_event(InputEventAction(&"skill_use_<slot>"))` called
  - Edge cases: skill on cooldown — slot Button disabled (modulate dim); click does not emit synthetic event

- **AC-8: All 6+ buttons meet 44pt minimum (manual pre-flight; story-008 lint automates)**
  - Setup: open `scenes/battle/elements/ui_gb_02_action_menu.tscn` + `ui_gb_05_skill_list.tscn` + `ui_gb_10_undo_indicator.tscn` in editor
  - Verify: every Button (or interactive Control) has `custom_minimum_size.x ≥ 44 AND custom_minimum_size.y ≥ 44`
  - Pass condition: all buttons compliant; story-008 lint will enforce

- **AC-9: AC-UX-HUD-08 + AC-UX-HUD-09 — Mobile DEFEND/ATTACK two-tap contract verified**
  - Setup: same as AC-3 + AC-4
  - Verify: HUD owns timer (assertion: `_two_tap_timer != null AND _two_tap_timer.get_parent() == hud OR _two_tap_timer == hud._two_tap_timer field instance`); synthetic events have correct action StringName values; two-tap timing matches `TWO_TAP_TIMEOUT_S` config
  - Pass condition: contract surface from §OQ-4 met exactly; document outcome in `production/qa/evidence/battle-hud-story-005-evidence.md`

---

## Test Evidence

**Story Type**: UI + Integration
**Required evidence**:
- Integration test: `tests/integration/feature/battle_hud/battle_hud_two_tap_test.gd` covers AC-1 through AC-7
- Manual: `production/qa/evidence/battle-hud-story-005-evidence.md` covers AC-8 (44pt manual pre-flight) + AC-9 (two-tap contract verification)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Stories 003 + 004 (wait for parallel stories — though strict ordering not required since handler bodies are disjoint, sequencing avoids merge conflicts on `_on_unit_selected_changed` and `_on_unit_turn_started`)
- Unlocks: Story 006 (Combat Forecast renders during ATTACK two-tap window — UI-GB-02 + UI-GB-04 coordinate visually)
