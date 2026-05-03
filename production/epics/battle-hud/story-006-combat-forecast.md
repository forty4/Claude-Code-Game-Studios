# Story 006: UI-GB-04 Combat Forecast (Full Contract — 80ms Dismiss + FORECAST_RENDER_BUDGET_MS)

> **Epic**: Battle HUD
> **Status**: Ready
> **Layer**: Presentation
> **Type**: UI + Performance
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/ux/battle-hud.md` v1.1 §3 UI-GB-04 + §4 Combat Forecast Full Spec + §10 Tuning Knobs
**Requirement**: `TR-battle-hud-005` (UI-GB-04 partial), `TR-battle-hud-008` (80ms dismiss instrumentation), `TR-battle-hud-009` (FORECAST_RENDER_BUDGET_MS BalanceConstants), `TR-battle-hud-014` (perf-budget context)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0015 Battle HUD §5 + Verification §1 + §4 (Accepted 2026-05-03)
**ADR Decision Summary**: UI-GB-04 Combat Forecast renders pre-attack preview with 6 sections (forecast contract per battle-hud.md §4): Direction badge, Hit/Crit chance, Damage range, Counter-attack preview, Status effects applied/received, Passives list (including TacticalRead [TR] chip + Rally + Formation lines). Subscribes `damage_applied` (force dismiss) + `round_started` (force dismiss). Loaded budget: `FORECAST_RENDER_BUDGET_MS = 120` BalanceConstants entry (one-shot burst on attack-target-hover); dismiss latency ≤ 80 ms instrumented per AC-UX-HUD-02 using `Time.get_ticks_usec()` start/end delta (NOT `Performance.TIME_PROCESS` per advisory B-4).

**Engine**: Godot 4.6 | **Risk**: HIGH (forecast 80ms dismiss latency on Pixel 7-class — Engine Verification Item 4 + dual-focus mouse/keyboard simultaneity — Engine Verification Item 1)
**Engine Notes**:
- `Time.get_ticks_usec()` returns microseconds; convert to ms via `delta_ms = float(Time.get_ticks_usec() - start_us) / 1000.0`. Single function call, no `Performance.TIME_PROCESS` (which returns last frame's `_process` duration only).
- Dual-focus verification: keyboard focus on UI-GB-02 action menu does NOT cancel mouse hover on UI-GB-04 forecast — the player using mouse + keyboard simultaneously must see both feedback channels. Test on macOS Metal + Linux Vulkan (mouse + keyboard). Pixel 7 touch-only flow is independent.
- Forecast burst budget = 120 ms one-shot per `BalanceConstants.get_const(&"FORECAST_RENDER_BUDGET_MS")`. Not per-frame — only on attack-target-hover transitions.

**Control Manifest Rules (Presentation layer)**:
- Required: AccessKit-via-Control inheritance — UI-GB-04 root + section subgroups expose accessibility_label.
- Forbidden (registry): `battle_hud_signal_emission` (forecast dismiss is a HUD-internal Tween, NOT a GameBus emit); `battle_hud_hardcoded_localized_strings` (forecast section labels via `tr()`).
- Guardrail: forecast burst ≤ 120 ms p99 on Pixel 7-class hardware (Adreno 610 / Mali-G57 reference); steady-state (no-forecast) per-frame budget unchanged at 0.1 ms.

---

## Acceptance Criteria

*From battle-hud.md §3 UI-GB-04 + §4 Combat Forecast Full Spec + ADR-0015 §5 + Verification §1+§4 + AC-UX-HUD-01 + AC-UX-HUD-02 + AC-UX-HUD-03 + AC-UX-HUD-04 + AC-UX-HUD-05:*

- [ ] `scenes/battle/elements/ui_gb_04_combat_forecast.tscn` exists with PanelContainer + VBoxContainer holding 6 section subpanels (Direction, Hit/Crit, Damage, Counter-attack, Status effects, Passives). Each subpanel has `tooltip_text` for AccessKit + non-empty `accessibility_label`.
- [ ] `_ui_elements[&"UI-GB-04"]` populated in `_ready()`, starts hidden.
- [ ] `assets/data/balance/balance_entities.json` contains new entry `FORECAST_RENDER_BUDGET_MS: 120` (per battle-hud.md §10 Tuning Knobs; same-patch obligation per ADR-0015 §"Same-Patch Obligations from ADR-0015 Acceptance" item 1).
- [ ] `BalanceConstants.get_const(&"FORECAST_RENDER_BUDGET_MS") -> int` returns 120 after this story ships (per ADR-0006 5-precedent JSON pattern).
- [ ] `show_forecast(attacker_id: int, defender_id: int) -> void` public method (or internal handler invoked by InputRouter `attack_target_hovered` event — verify integration path at story-author time):
  - Queries grid_controller / damage_calc / hp_controller / unit_role / hero_db for the 6 sections' data
  - Populates UI-GB-04 6 subpanels via `tr()`-routed labels
  - Sets `visible = true`
  - Records `_forecast_show_us = Time.get_ticks_usec()` for budget instrumentation
  - Total render time within FORECAST_RENDER_BUDGET_MS (120 ms) — measured via `Performance.get_monitor(Performance.TIME_PROCESS)` instrumentation gate per TR-battle-hud-014 OR via wall-clock spanning method entry → `visible = true` line per godot-specialist advisory B-4 — implementation-time choice
- [ ] `_dismiss_forecast(reason: StringName) -> void` private method:
  - Records `_forecast_dismiss_start_us = Time.get_ticks_usec()`
  - Starts Tween fading UI-GB-04 from `modulate.a = 1.0` to `0.0` over `0.08` seconds (80 ms target)
  - On Tween.finished: sets `visible = false`, computes `dismiss_ms = (Time.get_ticks_usec() - _forecast_dismiss_start_us) / 1000.0`, records to `Performance` monitor or test fixture for AC-UX-HUD-02 verification
- [ ] `_on_damage_applied(attacker_id, defender_id, damage)` body extension: invokes `_dismiss_forecast(&"damage_applied")`.
- [ ] `_on_round_started(round_number)` body extension: if forecast visible, invokes `_dismiss_forecast(&"round_started")`.
- [ ] **Section 1 — Direction badge**: derived from attacker/defender facing per damage-calc rules; renders compass arrow + `tr(&"hud.forecast.direction.<dir>")` label.
- [ ] **Section 2 — Hit/Crit chance**: queries damage_calc for `compute_hit_chance(...)` + `compute_crit_chance(...)`; renders as percentage (e.g., "85%").
- [ ] **Section 3 — Damage range**: queries damage_calc for `compute_damage_min_max(...)`; renders min-max range with chevron tier glyphs per battle-hud.md §4 contract (e.g., ▶ ▶ ▶ for high tier).
- [ ] **Section 4 — Counter-attack preview**: queries damage_calc for `compute_counterattack_preview(...)` if defender has counterattack stance; "—" if no counter.
- [ ] **Section 5 — Status effects applied/received**: queries damage_calc + hp_controller for status-effect deltas (e.g., DEFEND_STANCE remaining, BLEED applied).
- [ ] **Section 6 — Passives list (visible cap = 3 lines)**: includes Rally line if `rally_bonus_active > 0` (per battle-hud.md UI-GB-13 §3 i18n key `"forecast.passive.rally"`); includes Formation line if pattern role active (UI-GB-14); includes [TR] chip if attacker is Strategist + target is TR-extended tile (UI-GB-12). 3-line cap enforced; if more than 3 passives apply, render top-3 by precedence (Rally > Formation > TR > others).
- [ ] **AC-UX-HUD-04 — chevron hit area ≥ 44×44pt** on touch viewport (each chevron is a TextureRect with `custom_minimum_size = Vector2(44, 44)` — verify in .tscn).
- [ ] **AC-UX-HUD-05 — No 주홍 (#D63B2A) or 금색 (#C9A84C) reserved colors** render in any UI-GB-04 variant per palette discipline (golden 금색 #C9A84C IS used for UI-GB-13 Rally aura per battle-hud.md §3 — clarify: §6 reserves 주홍 + Rally's 황금 from forecast palette; verify with art-director sign-off; if 황금 chevron tier conflicts, use alternative palette per battle-hud.md §6).
- [ ] **AC-UX-HUD-02 — dismiss latency ≤ 80 ms** instrumented via `Time.get_ticks_usec()` start/end delta; recorded for soak-test review.
- [ ] No `GameBus.*.emit` calls; forecast dismiss is HUD-internal Tween, not a cross-system signal.
- [ ] All visible strings via `tr()` — locale keys (samples): `hud.forecast.direction.north`, `hud.forecast.hit_label`, `hud.forecast.damage_label`, `hud.forecast.counter_label`, `hud.forecast.status_label`, `hud.forecast.passives_label`, `forecast.passive.rally`, `forecast.passive.formation`, `forecast.passive.tactical_read`, `forecast.no_counter.defend_stance`.

---

## Implementation Notes

*Derived from ADR-0015 §5 + §4 + battle-hud.md §4 Combat Forecast Full Spec + §10 Tuning Knobs:*

1. **Forecast trigger path** — `attack_target_hovered` is the trigger per battle-hud.md §3 UI-GB-04. Verify InputRouter exposes this signal (per registry / ADR-0005); if not signal-driven, route via `show_forecast(attacker_id, defender_id)` invocation from elsewhere (e.g., grid_controller hover state). Story-author's discovery task at first session.

2. **Dismiss instrumentation precision** — Per godot-specialist 2026-05-03 advisory B-4: use `Time.get_ticks_usec()` snapshots (NOT `Performance.get_monitor(Performance.TIME_PROCESS) * 1000`). TIME_PROCESS returns last `_process` call duration, which underreports multi-frame Tweens and overreports if frame did other work. The dismiss span is event-receipt → Tween.finished — wall-clock is the right axis.

3. **Tween dismiss approach** — `Tween` instance created in `_dismiss_forecast()` body (not retained as field — Godot 4.6 SceneTreeTimer-style). `tween_property(_ui_elements[&"UI-GB-04"], "modulate:a", 0.0, 0.08)`. Connect `finished` signal to a finalizer Callable that sets `visible = false` + records dismiss latency. Avoid retaining Tween instance across calls — let it auto-cleanup.

4. **Section 6 passives precedence** — when more than 3 passives apply, ranking is:
   - 1st: Rally (UI-GB-13 from Commander adjacency) — `forecast.passive.rally`
   - 2nd: Formation (UI-GB-14 from active formation snapshot) — `forecast.passive.formation`
   - 3rd: TacticalRead [TR] (UI-GB-12 chip when attacker is Strategist on TR-extended tile) — `forecast.passive.tactical_read`
   - 4th+: other passive types per future ADRs (currently not a concern at MVP)
   3-line visible cap is a hard UI constraint per battle-hud.md §4.1 Section 6; overflow shown as "+N more" tooltip OR scrollable region — verify implementation choice with art-director.

5. **Dual-focus verification** — Engine Verification Item 1: ensure UI-GB-04 hover state and UI-GB-02 keyboard focus state are independent. UI-GB-04 should be `focus_mode = Control.FOCUS_NONE` (forecast is not interactive — it's read-only display) so keyboard focus stays on UI-GB-02 buttons. Mouse hover on grid produces forecast; keyboard focus stays on action menu — both feedback channels visible simultaneously.

6. **BalanceConstants entry pattern** — append to `assets/data/balance/balance_entities.json` per ADR-0006 5-precedent JSON pattern. Sample entry:
   ```json
   {
     "FORECAST_RENDER_BUDGET_MS": 120
   }
   ```
   Story-008's `lint_balance_entities_battle_hud.sh` will validate presence + safe range (e.g., 50-300 sanity bounds).

7. **Performance verification gate** — TR-battle-hud-014 specifies per-story `Performance.get_monitor(Performance.TIME_PROCESS)` instrumentation. Add a test in `battle_hud_forecast_test.gd` that:
   - Triggers `show_forecast` 100 times in a row in headless mode
   - Records average + p99 latency in ms
   - Asserts p99 < 120 ms (FORECAST_RENDER_BUDGET_MS)
   - Documents in `production/qa/evidence/battle-hud-story-006-evidence.md`

8. **Reserved-color avoidance (AC-UX-HUD-05)** — review chevron tier palette + section labels against battle-hud.md §6 reserved-color list (주홍 + 금색 are reserved for Beat 7 destiny reveal per Pillar 2). Forecast chevron tiers use neutral grayscale OR battle-hud.md §6 palette (e.g., 청 + 백). Art-director sign-off required per epic R-6.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Story 005: UI-GB-02 Action Menu two-tap arming (forecast renders during ATTACK pending state — UI-GB-04 + UI-GB-02 coordinate visually but each owns its own visibility logic).
- Story 007: UI-GB-09 End-of-Battle Results (different `battle_outcome_resolved` handler).
- Story 008: 6 CI lints (this story authors source compliantly from start).

---

## QA Test Cases

*UI + Performance story — automated tests for forecast render + dismiss latency; manual for visual verification.*

- **AC-1: UI-GB-04 element + balance constant ship together**
  - Setup: instantiate BattleHUD; query `BalanceConstants.get_const(&"FORECAST_RENDER_BUDGET_MS")`
  - Verify: `_ui_elements[&"UI-GB-04"]` non-null + visible == false; constant returns 120 (int)
  - Pass condition: assertions pass

- **AC-2: show_forecast populates 6 sections within budget (AC-UX-HUD-01)**
  - Given: damage_calc + hp_controller + hero_db + unit_role + grid_controller stubs returning realistic values
  - When: `hud.show_forecast(attacker_id=42, defender_id=99)`
  - Then: UI-GB-04 visible == true; all 6 subpanel children render labels (non-empty); record render time `t = (Time.get_ticks_usec() - _forecast_show_us) / 1000.0`; assert `t < 120.0`
  - Edge cases: parameterised over (attacker has counter / no counter), (Rally active / not active), (Formation active / not active), (TR chip / no TR), (3 passives / 4+ passives precedence cap)

- **AC-3: damage_applied dismisses forecast within 80ms (AC-UX-HUD-02)**
  - Given: forecast visible (post AC-2 happy state)
  - When: `_grid_controller.damage_applied.emit(42, 99, 30)` (deferred → flush)
  - Then: forecast Tween starts; awaits Tween.finished; assert `dismiss_ms < 80.0` (recorded via `Time.get_ticks_usec()` delta)
  - Edge cases: forecast invisible at signal time → dismiss is no-op (no error)

- **AC-4: round_started dismisses forecast (force-dismiss path)**
  - Given: forecast visible
  - When: `GameBus.round_started.emit(4)` (deferred → flush)
  - Then: forecast Tween starts + dismisses
  - Edge cases: round_started while forecast already invisible — no Tween

- **AC-5: Section 6 passives precedence — Rally > Formation > TR cap at 3 lines (AC-UX-HUD-03)**
  - Given: damage_calc returning all 3 passives active + 1 hypothetical 4th passive
  - When: `show_forecast(42, 99)`
  - Then: Section 6 renders exactly 3 lines: Rally, Formation, TR — in that order; 4th passive not rendered (or rendered as overflow indicator per §4.1 Section 6)
  - Edge cases: only Formation + TR active → 2 lines rendered; only 1 passive → 1 line

- **AC-6: Chevron hit area ≥ 44×44pt (AC-UX-HUD-04, manual pre-flight)**
  - Setup: open `ui_gb_04_combat_forecast.tscn` in editor
  - Verify: each chevron TextureRect (Sections 3 damage tiers) has `custom_minimum_size.x ≥ 44 AND custom_minimum_size.y ≥ 44`
  - Pass condition: all chevrons compliant; story-008 lint enforces

- **AC-7: AC-UX-HUD-05 — Reserved colors absent (manual + art-director sign-off)**
  - Setup: review .tscn + script color references; review rendered output on macOS Metal
  - Verify: zero usage of 주홍 (#D63B2A) anywhere in UI-GB-04; 금색 (#C9A84C) only if explicitly approved for chevron palette per art-director (otherwise prefer 청/백 neutral)
  - Pass condition: art-director sign-off recorded in `production/qa/evidence/battle-hud-story-006-evidence.md`

- **AC-8: Dual-focus simultaneity (Engine Verification Item 1, manual on macOS Metal)**
  - Setup: BattleScene running with UI-GB-02 visible (active unit selected) + mouse hover on attack target tile
  - Verify: UI-GB-02 keyboard focus highlight remains visible on the focused button; UI-GB-04 forecast simultaneously rendered with mouse-hover origin
  - Pass condition: both feedback channels visually present in same frame; document outcome in story-006 evidence doc

- **AC-9: Performance gate p99 < FORECAST_RENDER_BUDGET_MS (TR-battle-hud-014)**
  - Setup: headless mode; loop `show_forecast` 100 iterations with realistic stubs
  - Verify: avg + p50 + p99 latency in ms recorded; p99 < 120 ms
  - Pass condition: AC-UX-HUD-01 met; document numbers in evidence doc

---

## Test Evidence

**Story Type**: UI + Performance
**Required evidence**:
- Integration test: `tests/integration/feature/battle_hud/battle_hud_forecast_test.gd` covers AC-1 through AC-5 + AC-9 (perf gate)
- Unit test: `tests/unit/feature/battle_hud/balance_entities_battle_hud_test.gd` covers AC-1 BalanceConstants entry presence
- Manual: `production/qa/evidence/battle-hud-story-006-evidence.md` covers AC-6 (44pt chevrons), AC-7 (palette + art-director), AC-8 (dual-focus on macOS Metal)

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: Story 005 (forecast renders during ATTACK two-tap pending — UI-GB-02 coordination established there)
- Unlocks: Story 007 (final UI-element batch); story-008 (epic terminal lints)
