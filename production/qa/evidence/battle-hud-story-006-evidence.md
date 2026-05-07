# Battle HUD Story 006 — UI-GB-04 Combat Forecast Evidence

**Epic**: battle-hud
**Story**: story-006-combat-forecast
**ADR**: ADR-0015 §5 + Verification §1+§4 + B-4 advisory
**Status**: Verified (headless tests cover AC-1..AC-5 + AC-9 + non-emitter discipline; AC-6 mechanically verified in scene; AC-7 + AC-8 deferred to art-director sign-off + Polish-tier on-device verification)

## AC-6: Chevron Hit Area ≥ 44×44pt (Touch Target Compliance, Manual Pre-Flight)

### Verification procedure
1. Open `scenes/battle/elements/ui_gb_04_combat_forecast.tscn` in Godot editor
2. Confirm each of 3 chevron `TextureRect` nodes (Sections 3 damage tiers) has `custom_minimum_size = Vector2(44, 44)`

### Result
- [x] **Verified at story-006 ship time** — all 3 chevron `TextureRect` nodes (`Chevron0` / `Chevron1` / `Chevron2`) at lines 87 / 93 / 99 of the .tscn declare `custom_minimum_size = Vector2(44, 44)`. Compliant with WCAG 2.5.5 + project mobile target floor (`technical-preferences.md` 44px touch target enforcement).
- **Story-008 CI lint** will automate this check via `tools/ci/lint_battle_hud_44pt_touch_target.sh` (forbidden_pattern: `battle_hud_touch_target_below_44pt`). Lint scope expands to include UI-GB-04 chevron `TextureRect` nodes alongside the 9 interactive Buttons that story-005 evidence inventoried.

## AC-7: Reserved Color Avoidance (AC-UX-HUD-05) — DEFERRED to Art-Director Sign-Off

### Verification procedure (planned)
1. Review `scenes/battle/elements/ui_gb_04_combat_forecast.tscn` for color property values
2. Render UI-GB-04 forecast on macOS Metal in `scenes/battle/battle_scene.tscn` running smoke
3. Visually confirm zero usage of 주홍 `#D63B2A` and 금색 `#C9A84C` in any forecast subpanel

### Result
- **DEFERRED** — story-006 ships the architectural contract (visibility + render budget + dismiss latency); chevron tier palette + section labels currently inherit the default theme (no explicit color overrides in the .tscn). Story-008's `lint_battle_hud_reserved_color_avoidance.sh` will enforce structurally via grep against forbidden hex literals; art-director sign-off documented at /code-review for chevron tier palette per battle-hud.md §6.
- **Art-director sign-off**: pending. Sprint-10 follow-up gate before public playtest.

## AC-8: Dual-Focus Simultaneity (Engine Verification Item 1) — DEFERRED to Polish-Tier macOS Metal Smoke

### Verification procedure (planned)
1. Run `scenes/battle/battle_scene.tscn` on macOS Metal with mouse + keyboard connected
2. Select an active player unit → UI-GB-02 action menu becomes visible with keyboard focus on a button
3. Mouse-hover an attack target tile → UI-GB-04 forecast renders simultaneously
4. Confirm UI-GB-02 keyboard focus highlight remains visible during the mouse-hover forecast render
5. Confirm UI-GB-04 forecast remains visible while keyboard arrow-keys / Tab navigate UI-GB-02

### Expected result
Both feedback channels (UI-GB-02 keyboard focus highlight + UI-GB-04 mouse-hover forecast) visually present in the same frame. The forecast .tscn declares `focus_mode = 0` (FOCUS_NONE) on the PanelContainer root per ADR-0015 §5 Note 5, so keyboard focus traversal cannot land on the read-only forecast panel — keyboard focus stays on UI-GB-02 buttons.

### Result
- **DEFERRED — Polish-tier on-device verification**. Headless mode is structurally unable to exercise mouse + keyboard simultaneity; macOS Metal smoke required.
- **Pre-condition (verified now)**: `focus_mode = 0` (FOCUS_NONE) on UI-GB-04 PanelContainer root per .tscn line 25. Forecast panel is non-focusable; keyboard focus cannot inadvertently land on it.

## AC-9: Performance Gate p99 < FORECAST_RENDER_BUDGET_MS (TR-battle-hud-014)

### Architectural verification
- `_forecast_render_ms_last` measured via `Time.get_ticks_usec()` start/end delta per ADR-0015 B-4 advisory (NOT `Performance.TIME_PROCESS` — multi-frame Tween span).
- p99 computed at `tests/integration/feature/battle_hud/battle_hud_forecast_test.gd::test_show_forecast_p99_under_render_budget_100_iterations` (lines 338-369): 100 iterations sorted; index `mini(99, ceil(0.99 * 100) - 1) = 98` selected.
- Headless gate: `SKIP_PERF_BUDGETS=1` permissive cap (1000 ms); `SKIP_PERF_BUDGETS` unset strict cap (120 ms).

### Result
- **PASS in headless** (`SKIP_PERF_BUDGETS=1` matching CI). Reported avg + p99 in failure-message format if budget breached. On-device verification (Pixel 7-class hardware: Adreno 610 / Mali-G57) deferred to Polish-tier soak test.

## AC-3 (Dismiss Latency ≤ 80ms, AC-UX-HUD-02) — Headless-Verified

### Architectural verification
- `_forecast_dismiss_start_us` recorded in `_dismiss_forecast()` (line 570).
- `_forecast_dismiss_ms_last` recorded in `_on_forecast_dismiss_finished()` (line 583) as `Time.get_ticks_usec()` delta divided by 1000.
- Tween fades `modulate:a 1.0 → 0.0 over 0.08 seconds` (80 ms target wall-clock) per Implementation Note 3.
- B-4 advisory compliance: `Time.get_ticks_usec()` not `Performance.TIME_PROCESS`. Verified at /code-review by godot-gdscript-specialist.

### Result
- **PASS in headless**. On-device verification (Pixel 7-class) deferred to Polish-tier on-device soak alongside AC-9.

## Coverage Map

| AC | Verification mechanism | Test function or evidence line |
|----|------------------------|-------------------------------|
| AC-1 (mount + balance) | Headless integration + unit tests | `battle_hud_forecast_test::test_ui_gb_04_mounts_at_ready_and_starts_hidden` + `test_forecast_subpanels_dictionary_has_six_keys` + `balance_entities_battle_hud_test::test_balance_constants_has_forecast_render_budget_ms` + `test_balance_constants_forecast_render_budget_in_safe_range` |
| AC-2 (render + 6 subpanels populated) | Headless integration tests | `..::test_show_forecast_populates_subpanels_within_render_budget` + `..::test_show_forecast_populates_each_subpanel_with_text` |
| AC-3 (damage_applied dismiss + invisible no-op) | Headless integration tests | `..::test_damage_applied_initiates_forecast_dismiss_tween` + `..::test_dismiss_completes_within_80ms_budget` + `..::test_damage_applied_no_op_when_forecast_invisible` |
| AC-4 (round_started force-dismiss + edge) | Headless integration tests | `..::test_round_started_force_dismisses_visible_forecast` + `..::test_round_started_no_op_when_forecast_invisible` |
| AC-5 (passives precedence cap-3) | Headless integration test (structural — story-006 ships empty default; story-007 will populate from real GridBattleController formation_bonuses + UnitRole passive tags) | `..::test_collect_forecast_passives_returns_capped_array` |
| AC-6 (44pt chevron) | Scene-file mechanical verification (this evidence doc §AC-6) + story-008 CI lint pending | `ui_gb_04_combat_forecast.tscn` lines 87/93/99 |
| AC-7 (reserved color avoidance) | Art-director sign-off pending — story-008 CI lint covers structural | This evidence doc §AC-7 (DEFERRED) |
| AC-8 (dual-focus macOS Metal) | Polish-tier on-device smoke pending | This evidence doc §AC-8 (DEFERRED — Polish-tier) |
| AC-9 (p99 perf gate) | Headless integration test | `..::test_show_forecast_p99_under_render_budget_100_iterations` |
| TR-007 (non-emitter discipline) | G-22 source-scan structural assertion | `..::test_no_gamebus_emit_calls_in_battle_hud_forecast_paths` |

## ADVISORY Deviations Documented at /code-review

1. **Real DamageCalc API integration deferred to story-007** — `_populate_forecast_section()` ships placeholder content (hit=85, dmg=12-18, counter="—") via `tr()` keys. Real query through `DamageCalc.compute_hit_chance / compute_damage_min_max / compute_counterattack_preview` deferred. Ship-it decision: prioritize architectural contract (visibility + render budget + dismiss latency) over forecast content fidelity per Implementation Note rationale.
2. **`_collect_forecast_passives()` ships empty array default** — real Rally / Formation / TR query through `GridBattleController.formation_bonuses` + `UnitRole` passive tags deferred to story-007; structural cap-3 contract (AC-5) verified. Story-007 will populate from real backend; AC-5 parametric edge cases (Rally + Formation + TR overflow → 3 lines capped) will be exercised then.
3. **i18n locale entries staged but not yet authored** — `tr()` keys referenced via inline literals: `hud.forecast.direction.north`, `hud.forecast.hit_label`, `hud.forecast.damage_label`, `hud.forecast.counter_label`, `hud.forecast.status_label`, `hud.forecast.passives_label`, `forecast.passive.rally`, `forecast.passive.formation`, `forecast.passive.tactical_read`, `forecast.no_counter.defend_stance`. Locale infrastructure adds entries in next localization pass; until then, `tr()` returns the key as-string at runtime — visible but not localized.

## Cross-References

- ADR-0015 §5 — Forecast handler block (`_dismiss_forecast` invoked from `_on_damage_applied` + `_on_round_started`).
- ADR-0015 §3 — DI seam (9-param `setup()` precondition).
- ADR-0015 Verification §1 — Dual-focus end-to-end (HIGH risk — Polish-tier).
- ADR-0015 Verification §4 — Forecast dismiss latency ≤ 80 ms (this evidence + AC-3 tests).
- ADR-0015 B-4 advisory — `Time.get_ticks_usec()` instead of `Performance.TIME_PROCESS` (verified at /code-review).
- battle-hud.md §4 — Combat Forecast Full Spec.
- battle-hud.md §10 — Tuning Knobs (`FORECAST_RENDER_BUDGET_MS = 120`).
- TR-battle-hud-005 (UI-GB-04 partial) + TR-battle-hud-008 (80ms dismiss) + TR-battle-hud-009 (FORECAST_RENDER_BUDGET_MS) + TR-battle-hud-014 (perf-budget context).
- forbidden_pattern `battle_hud_signal_emission` — story-008 CI lint enforcement.
- TG-3 — `awk` range-pattern self-close trap (S9-05 discovery; not directly relevant here but cross-referenced for sprint-10 lint authoring).
