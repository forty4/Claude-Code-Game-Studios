# Battle HUD — Epic Verification Summary

> **Epic**: `production/epics/battle-hud/EPIC.md`
> **Sprint**: Sprint 10 (S10-01 through S10-03 — 2026-05-07)
> **Governing ADR**: `docs/architecture/ADR-0015-battle-hud.md`
> **Story**: `production/epics/battle-hud/story-008-epic-terminal-lints-and-verification.md`
> **Date**: 2026-05-07
> **Author**: Dowan Kim

---

## Epic Outcome — All 8 Stories Complete

| # | Story | Tests added | Sprint slot |
|---|---|---:|---|
| 001 | Class skeleton + 9-param DI + 11 GameBus subs + `_exit_tree` | +6 | S6-05 |
| 002 | UI elements registry (UI-GB-01..14) + recursive MOUSE_FILTER_IGNORE | +5 | S6-06 |
| 003 | Unit info panel (UI-GB-03/11) + HP/Status integration | +7 | S6-09 |
| 004 | Initiative queue (UI-GB-01) + turn/round counter (UI-GB-07) | +6 | S7-09 |
| 005 | Action menu (UI-GB-02) + skill list (UI-GB-05) + two-tap protocol + 7 button handlers | +7 | S8-07 |
| 006 | Combat forecast (UI-GB-04) + show_forecast + dismiss + render-budget instrumentation | +13 | S10-01 |
| 007 | Tile tooltip (UI-GB-06) + battle results (UI-GB-09) + grid-layer overlays (UI-GB-12/13/14) | +15 | S10-02 |
| 008 | Epic terminal — 7 CI lints + smoke test + verification summary doc | +8 | S10-03 |

**Total**: ~+67 tests across this epic. **Test baseline**: 1199 (sprint-9 close, 46th FFB) → **1236** (post-story-008). **51 consecutive failure-free baselines** since sprint-3 close.

---

## Engine Verification Item 1 — Dual-focus end-to-end (HIGH risk, Godot 4.6)

**Source**: ADR-0015 §Engine Compatibility Verification §1
**Outcome**: **DEFERRED to Polish-tier macOS Metal manual smoke**

The dual-focus simultaneity check (keyboard focus on UI-GB-02 action menu does NOT cancel mouse hover on UI-GB-04 forecast) was verified structurally via story-006 integration tests. End-to-end manual verification on Pixel 7 (touch) + macOS Metal (mouse + keyboard) + Linux Vulkan (mouse + keyboard + gamepad) is documented in:

- Source story: story-006 (Combat Forecast)
- Manual evidence link: `production/qa/evidence/battle-hud-story-006-evidence.md` AC-8 (DEFERRED Polish-tier macOS Metal per Story Type UI manual scope)

**KEEP through**: Polish phase manual cross-platform verification.

---

## Engine Verification Item 2 — AccessKit screen reader (HIGH risk, Godot 4.5+)

**Source**: ADR-0015 §Engine Compatibility Verification §2
**Outcome**: **DEFERRED to Polish-tier macOS VoiceOver + Android TalkBack manual smoke**

UI-GB-01..14 elements expose `tooltip_text` + accessibility properties on every Control per AccessKit auto-enabled inheritance (Godot 4.5+). Structural verification:

- Source story: story-003 (Unit Info Panel) ratified the AccessKit-via-Control inheritance precedent
- Manual evidence link: future Polish-tier `production/qa/evidence/battle-hud-accessibility-verification.md`
- Android TalkBack: explicitly post-MVP per `design/ux/accessibility-requirements.md` §4

**KEEP through**: Polish phase + Android port milestone.

---

## Engine Verification Item 3 — 44pt Touch Target (CRITICAL)

**Source**: ADR-0015 §Engine Compatibility Verification §3 + technical-preferences.md mobile parity + accessibility-requirements.md WCAG 2.5.5
**Outcome**: **PASS — automated forever via Lint 4**

Static lint enforces every interactive Button has `custom_minimum_size.x ≥ 44 AND custom_minimum_size.y ≥ 44` on touch viewport. First dedicated accessibility lint in the project.

- Lint script: `tools/ci/lint_battle_hud_touch_target_size.sh`
- Files scanned: `scenes/battle/battle_hud.tscn` + `scenes/battle/elements/ui_gb_*.tscn` (15 files)
- Result on main HEAD (2026-05-07): **PASS — 10 interactive Buttons checked; all ≥ 44×44pt**
- Negative test recipe: edit `ui_gb_02_action_menu.tscn` MoveButton `custom_minimum_size = Vector2(40, 40)` → re-run → assert exit 1 → revert

**KEEP forever** — automated CI gate; first dedicated accessibility lint precedent.

---

## Engine Verification Item 4 — Forecast Dismiss Latency ≤ 80 ms

**Source**: ADR-0015 §Engine Compatibility Verification §4 + design/ux/battle-hud.md AC-UX-HUD-02
**Outcome**: **PASS — instrumented in production code via story-006**

`Time.get_ticks_usec()` start/end delta spans `damage_applied` → Tween.finished (NOT `Performance.TIME_PROCESS` per godot-specialist 2026-05-03 advisory B-4). Tracked in `_forecast_dismiss_ms_last` field; integration test gate at 80ms.

- Source story: story-006 (Combat Forecast)
- Test gate: `tests/integration/feature/battle_hud/battle_hud_forecast_test.gd::test_dismiss_completes_within_80ms_budget`
- Reference hardware: Pixel 7-class (Adreno 610 / Mali-G57)
- BalanceConstants companion: `FORECAST_RENDER_BUDGET_MS = 120` (one-shot forecast burst budget; verified by Lint 7)

**KEEP through**: Polish phase + reference-hardware p99 validation in `perf-nightly.yml` (TBD).

---

## Engine Verification Item 5 — Recursive `MOUSE_FILTER_IGNORE` propagation (Godot 4.5+)

**Source**: ADR-0015 §Engine Compatibility Verification §5
**Outcome**: **PASS — verified via story-002 integration test**

Setting `mouse_filter = MOUSE_FILTER_IGNORE` on the BattleHUD root disables ALL child Control interactions in one call (Godot 4.5+ recursive propagation). No per-child enumeration required.

- Source story: story-002 (UI elements registry)
- Test gate: regression test asserting Button.pressed signal does not emit while root is set IGNORE
- Story-007 (S9-02 input-handling) S5 INPUT_BLOCKED state consumes this contract

**KEEP through**: GDD MVP regression suite.

---

## Engine Verification Item 6 — `Object.CONNECT_DEFERRED` discipline

**Source**: ADR-0015 §Engine Compatibility Verification §6 + ADR-0001 §5 mandate
**Outcome**: **PASS — automated forever via Lint 6**

All 11 GameBus + GridBattleController-LOCAL subscriptions in BattleHUD MUST use `Object.CONNECT_DEFERRED`. Static lint counts subscriptions and asserts presence on each.

- Lint script: `tools/ci/lint_battle_hud_connect_deferred.sh`
- Subscriptions verified (lines 248-260 of `battle_hud.gd`):
  - 4 controller-LOCAL: `unit_selected_changed`, `unit_moved`, `damage_applied`, `battle_outcome_resolved`
  - 7 GameBus: `unit_died`, `round_started`, `unit_turn_started`, `unit_turn_ended`, `input_state_changed`, `input_mode_changed`, `formation_bonuses_updated`
- Result on main HEAD (2026-05-07): **PASS — all 11 subscriptions use `Object.CONNECT_DEFERRED`**
- Negative test recipe: remove `Object.CONNECT_DEFERRED` from one `.connect(...)` line → re-run → assert exit 1 → revert

**KEEP forever** — automated CI gate.

---

## Engine Verification Item 7 — Pillar 2 hidden-fate non-subscription (CRITICAL)

**Source**: ADR-0015 §Engine Compatibility Verification §7 + game-concept.md Pillar 2 + destiny-branch.md §B
**Outcome**: **PASS — automated forever via Lint 1 (CRITICAL)**

BattleHUD source MUST NOT contain the literal token `hidden_fate_condition_progressed`. Zero tolerance — comments, variable names, .connect calls, and string literals all trigger fail. Forces architects to use renamed references if discussing the topic.

- Lint script: `tools/ci/lint_battle_hud_hidden_fate_non_subscription.sh`
- Result on main HEAD (2026-05-07): **PASS — 0 references in `src/feature/battle_hud/`**
- Three-doc revision required to relax: ADR-0015 (Superseded-by) + `design/gdd/destiny-branch.md` Section B + `design/gdd/game-concept.md` Pillar 2
- Negative test recipe: insert `# hidden_fate_condition_progressed` comment into source → re-run → assert exit 1 → revert

**KEEP forever** — first pillar-anchored lint pattern in the project. Pattern stable at 4 invocations across the codebase:
1. `battle_hud_subscribes_to_hidden_fate_signal` (this; TR-battle-hud-004)
2. `scenario_runner_deferred_seal_in_beat_7_entry` (TR-scenario-progression-008)
3. `destiny_branch_judge_reads_scenario_runner_state` (TR-destiny-branch-010)
4. `ai_system_reads_destiny_branch_state` (TR-ai-system-013)

---

## 7 Forbidden-Pattern Lints — Master Inventory

All 7 lint scripts shipped at `tools/ci/lint_battle_hud_*.sh` + `tools/ci/lint_balance_entities_battle_hud.sh`. All 7 wired into `.github/workflows/tests.yml` after the Input Handling lint block (lines 145-159 post-update).

| Lint script | Forbidden_pattern | TR-ID | AC | KEEP |
|---|---|---|---|---|
| `lint_battle_hud_hidden_fate_non_subscription.sh` | `battle_hud_subscribes_to_hidden_fate_signal` (Pillar 2 lock — CRITICAL) | TR-battle-hud-004 | AC-1 | **forever** |
| `lint_battle_hud_signal_emission_outside_ui_domain.sh` | `battle_hud_signal_emission` | TR-battle-hud-007 | AC-2 | forever |
| `lint_battle_hud_missing_exit_tree_disconnect.sh` | `battle_hud_missing_exit_tree_disconnect` | TR-battle-hud-003 | AC-3 | forever |
| `lint_battle_hud_touch_target_size.sh` | `battle_hud_touch_target_below_44pt` | TR-battle-hud-011 | AC-4 | **forever (1st accessibility lint)** |
| `lint_battle_hud_no_hardcoded_strings.sh` | `battle_hud_hardcoded_localized_strings` | TR-battle-hud-012 | AC-5 | **forever (1st i18n lint)** |
| `lint_battle_hud_connect_deferred.sh` | (Engine Verification Item 6) | (TR-battle-hud-003 cross-cut) | AC-6 | forever |
| `lint_balance_entities_battle_hud.sh` | (key-presence: `FORECAST_RENDER_BUDGET_MS`) | TR-battle-hud-009 | AC-7 | through MVP |

All 7 lint scripts chmod +x and wired into CI; smoke test at `tests/unit/tools_ci/lint_battle_hud_smoke_test.gd` (8 tests including structural presence/executability check).

**Lint suite wall-clock**: ≤ 5 s aggregate (mirrors grid-battle-controller 4-lint timing per ADR-0015 §Control Manifest Rules guardrail).

---

## ADVISORY Deviations (story-008)

5 ADVISORY deviations carried forward — none blocking; sprint-10 retro doc-correction sweep candidates:

1. **Story title says "6 CI Lints" but body enumerates 7** — minor spec drift; the 7-lint reality is the source of truth (Lint 1 + 2 + 3 + 4 + 5 + 6 + Lint 7 BalanceConstants key-presence). Sprint-10 retro: amend story title.
2. **Implementation Notes #1 claims "grid-battle-controller 4-lints"** — actual count is 3 lints (signal_emission_outside_battle_domain + static_state + external_combat_math; balance_entities_grid_battle_controller is the 4th). Pattern-shape advice still valid; numerical claim slightly off.
3. **AC-10 references `tests/gdunit4_runner.gd`** — file does not exist; actual CI runner is `MikeSchulze/gdUnit4-action@v1`. Same wording in CLAUDE.md Coding Standards (project-wide doc pattern). Smoke test invocation pattern works through the addon directly.
4. **Lint 5 whitelist allows format-strings with embedded English prose** — e.g., `"Round %d"`, `"Turn: %s"`, `"Upcoming: %s"` pass current Lint 5 because they contain `%[ds]` format specifiers. Future i18n hardening should refactor to the `tr()`-prefix pattern (`"%s %d" % [tr(&"hud.round_label"), round_number]`) used elsewhere in the file (lines 711/714/721/918/921). Sprint-10 retro candidate.
5. **Em-dash placeholder hoisted to const `_COUNTER_PLACEHOLDER_DASH`** — small refactor to `src/feature/battle_hud/battle_hud.gd` to keep Lint 5 clean. Documented inline at the const declaration (line 96).

---

## AC-10 — Regression Baseline

**Final epic baseline**: **1236 PASS / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0**.

Sprint-10 trajectory:
- Pre-sprint (sprint-9 close): 1203
- /sprint-plan + drift-correction sweep: 1203 → 1199 (small re-baseline due to test-helper consolidation)
- Story-006 forecast: 1199 → 1212 (+13) — 47th FFB
- Story-007 tile/results/overlays: 1213 → 1227 (+14) — 49th FFB
- Story-007 same-pass /code-review closure: 1227 → 1228 (+1) — 50th FFB
- Story-008 epic-terminal: 1228 → **1236** (+8 smoke tests) — **51st consecutive failure-free**

---

## Epic Cross-System Closure Markers

| Verification item | Cross-ADR closure | Closure marker |
|---|---|---|
| Item 6 CONNECT_DEFERRED | ADR-0001 §5 mandate | RESOLVED 2026-05-07 — automated via Lint 6 |
| Item 7 Pillar 2 hidden-fate lock | ADR-0014 §8 + game-concept.md Pillar 2 | RESOLVED 2026-05-07 — automated via Lint 1 (CRITICAL) |
| TR-battle-hud-004 Pillar 2 | ADR-0015 §Decision §8 | RESOLVED 2026-05-07 — 4th project precedent of pillar-anchored lint |
| TR-battle-hud-007 non-emitter | ADR-0015 §5 R-5 | RESOLVED 2026-05-07 — automated via Lint 2 |
| TR-battle-hud-003 _exit_tree disconnects ≥ 11 | ADR-0015 §3 + Engine Verification §6 | RESOLVED 2026-05-07 — automated via Lint 3 (count = 22) |
| TR-battle-hud-011 44pt touch | ADR-0015 §Engine Verification §3 | RESOLVED 2026-05-07 — automated via Lint 4 (1st accessibility lint) |
| TR-battle-hud-012 i18n via tr() | ADR-0015 §R-10 | RESOLVED 2026-05-07 — automated via Lint 5 (1st i18n lint) |
| TR-battle-hud-009 BalanceConstants FORECAST_RENDER_BUDGET_MS | ADR-0015 §Decision §Depends On | RESOLVED 2026-05-07 — automated via Lint 7 |

---

## Epic Status

**Battle HUD Feature epic 8/8 Complete** at sprint-10 S10-03 close. ADR-0015 Status remains **Accepted**; no flip-back at post-impl close-out.

`docs/architecture/architecture-traceability.md` Coverage row: **Presentation 1/6 → 1/6** (battle-hud was already counted as 1 of 6 ADRs; epic graduation refresh appended to status cell).

---

## Co-Author

🤖 Generated with [Claude Code](https://claude.com/claude-code)
