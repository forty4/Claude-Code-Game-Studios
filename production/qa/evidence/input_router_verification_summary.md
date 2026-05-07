# InputRouter Epic Verification Summary (Story 010 epic-terminal rollup)

**Epic**: input-handling
**Story**: story-010-epic-terminal-perf-lints-evidence
**ADR**: ADR-0005 §Verification Required (6 items) + EPIC.md Same-Patch Obligations §4
**Date**: 2026-05-07

## 6 Mandatory Verification Items — Final Status

| # | Item | Doc | Status | Polish-Deferred? |
|---|------|-----|--------|------------------|
| 1 | Dual-focus end-to-end Android+macOS | `_01_dual_focus.md` (story-005) | Polish-deferred (Android device) | YES |
| 2 | SDL3 gamepad detection Android+iOS | `_02_sdl3_gamepad.md` (story-005) | Polish-deferred (physical hardware) | YES |
| 3 | emulate_mouse_from_touch in-editor | `_03_emulate_mouse_from_touch.md` (story-008) | Verified (project.godot grep + lint_emulate_mouse_from_touch.sh) | NO |
| 4 | Recursive Control disable cross-check | `_04_recursive_control_disable.md` (story-007) | Verified (headless GdUnit4 hybrid pattern) | NO |
| 5a | DisplayServer.screen_get_size logical pixels | `_05a_displayserver_screen_get_size.md` (story-008) | Verified macOS (Polish-deferred Android) | PARTIAL |
| 5b | Safe-area API name | `_05b_safe_area_api.md` (story-009) | Resolved (Candidate 2 `get_display_safe_area`; Candidate 1 returns Vector3i not Vector4 — empirical post-cutoff Godot 4.6 drift) | NO |
| 6 | Touch event index stability physical hardware | `_06_touch_event_index_stability.md` (story-009) | Polish-deferred (synthetic event coverage in headless via story-009 multi-touch cancel test) | YES |

## Polish-Deferred Item Summary

- **Items #1, #2, #5a-Android, #6** → 4 reactivation triggers documented in TD-068 (post-launch on-device verification rollup)
- **Total Polish-phase verification effort**: 4-6h
- **Reactivation conditions**: physical Android 14+ AND iOS 17 devices available + first export build green per platform

## Headless-Verified Item Summary (4/6 in MVP)

- **Items #3, #4, #5b**: fully verified in headless GdUnit4 + project.godot grep + 3-candidate fallback ladder
- **Item #5a**: macOS dev box verified via `(0, 0)` headless probe + sanity bounds; Android Polish-deferred
- **Items #1, #2, #6**: synthetic-event coverage in headless tests; on-device confirmation deferred to Polish per 5+ precedent

## Performance Baseline (story-010 AC-1)

Headless macOS (Godot 4.6.2.stable; M-series Apple Silicon dev box):
- `_handle_event` p99 over 1000 iterations: <0.25ms (gate; on-device target 0.05ms)
- `_handle_action` p99 over 1000 iterations: <0.10ms (gate)
- 10k synthetic events throughput: <500ms total
- `_ready()` init equivalent (JSON load + InputMap populate + R-5 parity) p50 over 5 runs: <5ms

On-device measurement Polish-deferred per damage-calc / hp-status / turn-order epic-terminal 3-precedent (CI runners lack vsynced display; SKIP_PERF_BUDGETS=1 in headless workflow).

## CI Lint Coverage (7 new lints)

Story-010 ships 7 input-handling-domain lints wired into `.github/workflows/tests.yml`:

1. `lint_input_router_no_input_override.sh` — Advisory C: no `_input(event)` override; only `_unhandled_input`
2. `lint_input_router_input_blocked_drop_without_set_input_as_handled.sh` — Advisory C: S5 dispatch must call `set_input_as_handled()`
3. `lint_input_router_signal_emission_outside_input_domain.sh` — TR-input-handling-017: sole emitter of 3 input-domain signals
4. `lint_input_router_hardcoded_bindings.sh` — CR-1b: no `==` comparison against `KEY_*` / `MOUSE_BUTTON_*` / `JOY_BUTTON_*` enum literals
5. `lint_input_router_g15_reset.sh` — TR-input-handling-013: every test file's `before_test()` resets all 17 fields
6. `lint_emulate_mouse_from_touch.sh` — R-3 / CR-2e: `project.godot` `[input_devices.pointing]` `emulate_mouse_from_touch=false`
7. `lint_balance_entities_input_handling.sh` — 7 BalanceConstants keys present + within ADR-0005 §Tuning Knobs safe ranges

(NOTE: spec line 252 in story-010 said "9 new lints" but Implementation Note 8 enumerated 7. The actual count is 7 — sprint-9 retro doc-correction sweep candidate.)

## 5 Cross-System Provisional Contracts (TD-069)

InputRouter holds 5 widen-not-narrow provisional contracts pending downstream ADRs:
1. **Camera ADR** — `screen_to_grid` + `camera_zoom_min` clamp + drag state ownership (OQ-2)
2. **Grid Battle ADR** — `is_tile_in_move_range` + `is_tile_in_attack_range` + `confirm_move/attack` + `restore_unit_to_pre_move` + `is_tile_occupied` + `get_unit_coord/facing`
3. **Battle HUD ADR** — `show_unit_info` + `show_tile_info` + `dismiss_preview` + `show_magnifier` + `panel_reposition_request` subscription + reads `get_active_input_mode`
4. **Settings/Options ADR** — `set_binding(action, event)` runtime remap consumer
5. **Tutorial ADR** — subscribes to `input_action_fired` for step detection

Each downstream ADR may only WIDEN never NARROW the locked interface per provisional-dependency strategy (4 prior precedents in damage-calc/hp-status/turn-order/grid-battle epics).

## Epic Closure

- **10/10 stories Complete** (story-001 through story-010)
- **Final test baseline**: ≥1199 PASS + 4 perf tests = **≥1203 cases** / 0 errors / 0 failures / 0 orphans / Exit 0
- **45+ consecutive failure-free baselines** maintained through epic close
- **20-streak in-patch sprint-status hygiene close** (S7-05/06/07/09 + S8-01..S8-11 + S9-01 + S9-02 + S9-03 + S9-04 + S9-05 = 21 in-patch closes)
- **8th-precedent 3-skill arc /dev-story → /code-review → /story-done** with /code-review-driven refactor pattern
