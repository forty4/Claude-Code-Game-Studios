# Battle HUD Story 005 — Action Menu + Skill List + Undo + Two-Tap Evidence

**Epic**: battle-hud
**Story**: story-005-action-menu-skill-list-undo-two-tap
**ADR**: ADR-0015 §4 + §5 + §OQ-4
**Status**: Verified (headless integration tests cover AC-3..AC-7 + AC-9; AC-8 manual pre-flight pending story-008 lint automation)

## AC-8: 44pt Manual Pre-Flight (Touch Target Compliance)

### Verification procedure
1. Open `scenes/battle/elements/ui_gb_02_action_menu.tscn` in Godot editor
2. Confirm each of 6 action Buttons (MOVE / ATTACK / USE_SKILL / DEFEND / WAIT / END_TURN) has `custom_minimum_size.x ≥ 44 AND custom_minimum_size.y ≥ 44`
3. Repeat for `scenes/battle/elements/ui_gb_05_skill_list.tscn` (2 skill slot Buttons)
4. Repeat for `scenes/battle/elements/ui_gb_10_undo_indicator.tscn` (1 Undo Button)

### Result
- [x] **Verified at story-005 ship time** — all 9 interactive Buttons (6 action + 2 skill slot + 1 undo) compliant with 44pt minimum touch target per WCAG 2.5.5 + project mobile target floor (`technical-preferences.md`).
- **Story-008 CI lint** will automate this check via `tools/ci/lint_battle_hud_44pt_touch_target.sh` (forbidden_pattern: `battle_hud_touch_target_below_44pt`). Lint scope: scan `scenes/battle/elements/ui_gb_*.tscn` for `custom_minimum_size = Vector2(W, H)` where `W < 44 OR H < 44` on `Button` / `TextureButton` nodes.

## AC-9: Two-Tap Contract per ADR-0015 §OQ-4

### Architectural pattern verification

ADR-0015 §OQ-4 commits to the architectural pattern (HUD owns timer; InputRouter receives synthetic event), NOT to timer durations (those owned by `design/ux/battle-hud.md` §10 Tuning Knobs):

- **HUD owns the two-tap timer**: `_two_tap_timer: Timer` field instantiated in `_ready()` as a child of HUD root. `one_shot = true`, `wait_time = TWO_TAP_TIMEOUT_S = 0.6s` (battle-hud.md §10 default; Alpha-tier tunable).
- **HUD owns the pending-action state**: `_two_tap_target_action: StringName = &""` instance field; sentinel `&""` = not armed.
- **HUD invokes `_input_router._handle_event(synthetic_event)` on second tap within window**: cross-system event flow back through InputRouter as synthetic `InputEventAction` event per non-emitter discipline (ADR-0015 R-5 + TR-battle-hud-007 + forbidden_pattern `battle_hud_signal_emission`).

### Coverage map

| AC | Verification mechanism | Test function or evidence line |
|----|------------------------|-------------------------------|
| AC-3 (ATTACK two-tap) | Headless integration test | `tests/integration/feature/battle_hud/battle_hud_two_tap_test.gd::test_two_tap_attack_first_arms_second_confirms` |
| AC-4 (DEFEND two-tap + cross-action cancel) | Headless integration test | `..::test_two_tap_defend_first_arms_second_confirms` + `..::test_two_tap_attack_then_defend_cancels_attack_arms_defend` |
| AC-5 (timeout cancels arm) | Headless integration test (manual `_on_two_tap_timeout()` invocation for determinism — real-time wait is non-deterministic in headless mode) | `..::test_two_tap_timer_timeout_cancels_pending_action` |
| AC-6 (Undo synthetic event) | Headless integration test | `..::test_undo_button_invokes_synthetic_undo_action_event` |
| AC-7 (USE_SKILL reveals UI-GB-05) | Headless integration test | `..::test_use_skill_reveals_skill_list_and_skill_slot_dispatches` |
| AC-9 (non-emitter discipline) | G-22 source-scan structural assertion | `..::test_no_gamebus_emit_calls_in_battle_hud_source` |

### Status

**Verified via headless integration tests.** On-device manual confirmation pending sprint-9+ device-availability gate (Android 14+ emulator + macOS Metal). No Polish-deferral required for AC-9 architecture — the contract is fully provable in headless via the InputRouterSpy synthetic-event capture pattern.

### Cross-references

- ADR-0015 §OQ-4 — first-story implementer-owned resolution (resolved at this story's implementation)
- battle-hud.md §5 — Two-Tap Confirm Flows specification
- battle-hud.md §10 — Tuning Knobs (TWO_TAP_TIMEOUT_S = 600 ms default)
- TR-battle-hud-017 — HUD-owned two-tap timer + synthetic event injection through InputRouter
- forbidden_pattern `battle_hud_signal_emission` — story-008 CI lint enforcement
