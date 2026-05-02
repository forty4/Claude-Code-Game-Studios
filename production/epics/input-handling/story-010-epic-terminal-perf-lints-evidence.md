# Story 010: Epic terminal — performance baseline + 6+ forbidden_patterns CI lints + lint_emulate_mouse_from_touch.sh + default_bindings.json content authoring + DI test seam G-15 validation lint + 3 TD entries

> **Epic**: Input Handling
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: 3-4h
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/input-handling.md`
**Requirement**: `TR-input-handling-013`, `TR-input-handling-015`, `TR-input-handling-016`, `TR-input-handling-017`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005 — Input Handling — InputRouter Autoload + 7-State FSM (MVP scope) + ADR-0001 GameBus
**ADR Decision Summary**: Closure of TR-013 (DI test seam G-15 obligations enforced via static lint), TR-015 (`emulate_mouse_from_touch=false` R-3 mitigation lint + 6 mandatory verification items completion summary), TR-016 (performance baseline `_handle_event < 0.05ms` + 10k synthetic events <500ms throughput; on-device deferred per Polish-deferral 5+ precedent), TR-017 (non-emitter invariant lint — InputRouter sole emitter of 3 input-domain signals; 0 emit calls for OTHER 21 signals; carried advisory for ADR-0001 line 168 amendment `action: String` → `StringName`). Mirrors hp-status story-008 + turn-order story-007 epic-terminal precedent.

**Engine**: Godot 4.6 | **Risk**: HIGH (governed by ADR-0005)
**Engine Notes**: Performance test pattern stable from damage-calc story-010 + hp-status story-008 + turn-order story-007 (3-precedent). Lint script pattern: bash + grep against source files; exit 0 on PASS, exit 1 on FAIL with diagnostic output. CI wiring: append step to `.github/workflows/tests.yml` per existing pattern. TD entries logged in `docs/tech-debt-register.md` per established TD-NNN sequence (most recent: TD-053 from hp-status epic; story-010 starts at TD-054).

**Control Manifest Rules (Foundation layer + Global)**:
- Required: 6+ forbidden_patterns lint scripts at `tools/ci/lint_input_router_*.sh` + 1 `lint_emulate_mouse_from_touch.sh` + 1 `lint_balance_entities_input_handling.sh` + 1 `lint_input_router_g15_reset.sh` (DI test seam validation per TR-013); CI wiring into `.github/workflows/tests.yml`; performance baseline test at `tests/performance/foundation/input_router_perf_test.gd`; 3 TD entries logged with reactivation triggers; non-emitter invariant lint per TR-017
- Forbidden: per-frame emit through GameBus from `_input(event)` (existing project-wide lint covers); GameBus emit from InputRouter outside the 3 input-domain signals (story-010 lint enforces `input_router_signal_emission_outside_input_domain`); `_input(event)` override on InputRouter (only `_unhandled_input` per Advisory C); CI lint failure triggering merge (BLOCKING per testing standards)
- Guardrail: 6 mandatory verification items SUMMARIZED in epic-terminal evidence doc (`production/qa/evidence/input_router_verification_summary.md`); performance test `_handle_event < 0.05ms` p99 over 1000 iterations on macOS dev (headless); 10k synthetic events throughput < 500ms total; epic close-out commit message lists all 9 stories + final regression count + lint count

---

## Acceptance Criteria

*From ADR-0005 §Performance Implications + §Validation Criteria + ADR-0001 §7 + Implementation Notes Advisory C + EPIC.md Same-Patch Obligations:*

- [ ] **AC-1** Performance baseline test `tests/performance/foundation/input_router_perf_test.gd` exists with 4 tests: (a) `test_handle_event_under_0_05ms` — 1000-iteration p99 < 0.05ms on dev; (b) `test_handle_action_under_0_02ms` — 1000-iteration p99 < 0.02ms; (c) `test_10k_synthetic_events_under_500ms` — full-throughput throughput test; (d) `test_ready_init_under_5ms` — single-shot autoload init time < 5ms (JSON parse + InputMap population + R-5 parity validation). All headless; on-device measurement Polish-deferred per damage-calc story-010 precedent
- [ ] **AC-2** `tools/ci/lint_input_router_no_input_override.sh` — greps `src/foundation/input_router.gd` for `func _input(event` (NOT `_unhandled_input`); exits 1 if found (Advisory C — only `_unhandled_input` per dual-focus 4.6 architecture)
- [ ] **AC-3** `tools/ci/lint_input_router_input_blocked_drop_without_set_input_as_handled.sh` — greps S5 dispatch arm for grid-action drop without paired `get_viewport().set_input_as_handled()` call within 5 lines; exits 1 if any drop missing the handled call (Advisory C forbidden_pattern)
- [ ] **AC-4** `tools/ci/lint_input_router_signal_emission_outside_input_domain.sh` — greps `src/foundation/input_router.gd` for `GameBus\.` emit calls; counts those NOT in the 3 input-domain signals (`input_action_fired` / `input_state_changed` / `input_mode_changed`); exits 1 if count > 0 (TR-017 non-emitter invariant). Note: subscriptions (`.connect()`) are allowed for `ui_input_block_requested` + `ui_input_unblock_requested` per ADR-0002 — the lint distinguishes emit vs subscribe via `\.emit(` suffix match
- [ ] **AC-5** `tools/ci/lint_input_router_hardcoded_bindings.sh` — greps `src/foundation/input_router.gd` for hardcoded `KEY_` / `MOUSE_BUTTON_` / `JOY_BUTTON_` enum literals (CR-1b enforcement); exits 1 if any found (all bindings must come from `default_bindings.json`); allowlist: `if event.keycode == KEY_*` runtime checks are FORBIDDEN; only `event.keycode` field reads (without comparison) are allowed
- [ ] **AC-6** `tools/ci/lint_emulate_mouse_from_touch.sh` — greps `project.godot` `[input_devices.pointing]` section for `emulate_mouse_from_touch=false`; exits 1 if missing OR `=true` (R-3 mitigation per CR-2e); CI step wired into `.github/workflows/tests.yml`
- [ ] **AC-7** `tools/ci/lint_balance_entities_input_handling.sh` — bash script: for each of 7 input-handling BalanceConstants keys (TOUCH_TARGET_MIN_PX, TILE_WORLD_SIZE, TPP_DOUBLE_TAP_WINDOW_MS, DISAMBIG_EDGE_PX, DISAMBIG_TILE_PX, PAN_ACTIVATION_PX, MIN_TOUCH_DURATION_MS), assert presence in `assets/data/balance/balance_entities.json` + value within ADR-0005 §Tuning Knobs safe range; exits 1 on missing key or out-of-range value
- [ ] **AC-8** `tools/ci/lint_input_router_g15_reset.sh` — DI test seam G-15 obligation enforcement (TR-013): for every `tests/unit/foundation/input_router_*_test.gd` file, asserts `before_test()` body resets all 6 architectural fields (`_state`, `_active_mode`, `_pre_menu_state`, `_undo_windows`, `_input_blocked_reasons`, `_bindings`) AND all 6 transient/scratch fields added across stories 004/007/008/009 (`_pending_end_phase`, `_pre_block_state`, `_last_tap_unit_id`, `_last_tap_time_ms`, `_touch_start_pos`, `_touch_start_time_ms`, `_touch_travel_px`, `_active_touch_indices`, `_grid_battle`, `_camera`, `_map_grid`); exits 1 if any test file missing reset for any field
- [ ] **AC-9** `production/qa/evidence/input_router_verification_summary.md` epic-terminal rollup doc lists all 6 mandatory verification items + their per-story evidence files + final status (Verified / Polish-deferred / Resolved). Mirrors damage-calc story-010 perf summary precedent
- [ ] **AC-10** `assets/data/input/default_bindings.json` content COMPLETE — all 23 actions (22 - grid_hover PC-only + 2 new gestures from story-009 = 23 bound actions) have at least 1 InputEvent binding; PC-default bindings cover all PC-reachable actions; touch-default bindings cover all touch-reachable actions per CR-1a hover-only ban. Reviewed against GDD §Action System table for completeness
- [ ] **AC-11** Tech debt entries logged in `docs/tech-debt-register.md` (continuing TD-053 from hp-status epic): **TD-054** Polish-tier on-device verification rollup (6 verification items — items #1, #2, #5b Android, #6 — Polish-defer; reactivation trigger: physical Android 14+ and iOS 17 devices available + first export build green; estimated Polish effort 4-6h); **TD-055** 5 cross-system provisional contracts pending downstream ADRs (Camera + Grid Battle + Battle HUD + Settings + Tutorial) — each ADR may only WIDEN never NARROW the locked interface per provisional-dependency strategy; reactivation trigger: each ADR's authoring; estimated effort per ADR 1-2h cross-doc verification; **TD-056** ADR-0001 line 168 amendment carried advisory: `signal input_action_fired(action: String, context: InputContext)` → `action: StringName` to match ADR-0005 + GDD + ACTIONS_BY_CATEGORY hot-path StringName literal convention (delta #6 Item 10a); reactivation trigger: next ADR-0001 amendment OR general housekeeping pass
- [ ] **AC-12** All 9 lint scripts (AC-2..AC-8 totals: 7 input-handling + 1 emulate-mouse + 1 balance-entities) wired into `.github/workflows/tests.yml` per existing pattern; CI run passes all 9 + existing project lints
- [ ] **AC-13** Regression baseline maintained: full GdUnit4 suite passes ≥833 cases (story-009 baseline) + 4 new perf tests / 0 errors / 0 failures / 0 orphans / Exit 0; **final epic baseline ≥837 cases**
- [ ] **AC-14** EPIC.md updated — Status `Ready` → `Complete (2026-MM-DD)`; Stories table populated with all 10 stories Complete; final test baseline + regression count + commit ref recorded

---

## Implementation Notes

*Derived from ADR-0005 §Performance Implications + §Validation Criteria + Migration Plan §Implementation-time verification follow-ups + EPIC.md scope:*

1. **Performance baseline test pattern** (mirrors damage-calc story-010 + hp-status story-008 + turn-order story-007):
   ```gdscript
   # tests/performance/foundation/input_router_perf_test.gd
   extends GdUnitTestSuite

   const _ITERATIONS: int = 1000
   const _THROUGHPUT_COUNT: int = 10000

   func before_test() -> void:
       # G-15 full reset of all 6 + 6 transient/scratch fields
       _reset_input_router()

   func test_handle_event_under_0_05ms() -> void:
       var event := InputEventKey.new()
       event.keycode = KEY_ENTER
       event.pressed = true
       var times: PackedFloat32Array = []
       for i in _ITERATIONS:
           var t0: int = Time.get_ticks_usec()
           InputRouter._handle_event(event)
           var t1: int = Time.get_ticks_usec()
           times.append(float(t1 - t0) / 1000.0)  # ms
       times.sort()
       var p99: float = times[int(_ITERATIONS * 0.99)]
       assert_float(p99).override_failure_message("p99 _handle_event = %.4f ms (target < 0.05 ms)" % p99).is_less(0.05)

   func test_10k_synthetic_events_under_500ms() -> void:
       var events: Array[InputEvent] = []
       for i in _THROUGHPUT_COUNT:
           var event := InputEventKey.new()
           event.keycode = KEY_ENTER
           events.append(event)
       var t0: int = Time.get_ticks_msec()
       for event: InputEvent in events:
           InputRouter._handle_event(event)
       var elapsed: int = Time.get_ticks_msec() - t0
       assert_int(elapsed).override_failure_message("10k events = %d ms (target < 500 ms)" % elapsed).is_less(500)
   ```

2. **Lint script template** (bash + grep, mirrors hp-status / turn-order precedent):
   ```bash
   #!/usr/bin/env bash
   # tools/ci/lint_input_router_no_input_override.sh
   # Verify InputRouter does NOT override _input(event) — only _unhandled_input per Advisory C
   set -e
   FILE="src/foundation/input_router.gd"
   if grep -nE "^func _input\(event" "$FILE" > /dev/null; then
       echo "::error::InputRouter declares func _input(event) override — Advisory C forbids; use _unhandled_input only"
       grep -nE "^func _input\(event" "$FILE"
       exit 1
   fi
   echo "lint_input_router_no_input_override PASS"
   ```

3. **`lint_input_router_signal_emission_outside_input_domain.sh`**:
   ```bash
   #!/usr/bin/env bash
   set -e
   FILE="src/foundation/input_router.gd"
   # Find all GameBus.X.emit( calls
   ALL_EMITS=$(grep -nE "GameBus\.\w+\.emit\(" "$FILE" || true)
   # Filter OUT the 3 allowed input-domain signals
   FORBIDDEN=$(echo "$ALL_EMITS" | grep -vE "GameBus\.(input_action_fired|input_state_changed|input_mode_changed)\.emit\(" || true)
   if [ -n "$FORBIDDEN" ]; then
       echo "::error::InputRouter emits non-input-domain GameBus signals (TR-017 violation):"
       echo "$FORBIDDEN"
       exit 1
   fi
   echo "lint_input_router_signal_emission_outside_input_domain PASS"
   ```

4. **`lint_input_router_g15_reset.sh`** (most complex — validates 12 fields × N test files):
   ```bash
   #!/usr/bin/env bash
   set -e
   REQUIRED_FIELDS=(
       "_state" "_active_mode" "_pre_menu_state" "_undo_windows" "_input_blocked_reasons" "_bindings"
       "_pending_end_phase" "_pre_block_state"
       "_last_tap_unit_id" "_last_tap_time_ms"
       "_touch_start_pos" "_touch_start_time_ms" "_touch_travel_px" "_active_touch_indices"
       "_grid_battle" "_camera" "_map_grid"
   )
   FAILED=0
   for test_file in tests/unit/foundation/input_router_*_test.gd; do
       if [ ! -f "$test_file" ]; then continue; fi
       # Extract before_test() body
       BEFORE_TEST_BODY=$(awk '/^func before_test/,/^func [^_]/' "$test_file")
       for field in "${REQUIRED_FIELDS[@]}"; do
           # Field must appear in before_test body (assignment OR clear() OR remove call)
           if ! echo "$BEFORE_TEST_BODY" | grep -qE "${field}"; then
               echo "::error::$test_file before_test() missing reset for field $field"
               FAILED=$((FAILED + 1))
           fi
       done
   done
   if [ "$FAILED" -gt 0 ]; then
       echo "lint_input_router_g15_reset FAIL — $FAILED missing field resets"
       exit 1
   fi
   echo "lint_input_router_g15_reset PASS"
   ```

5. **`lint_emulate_mouse_from_touch.sh`**:
   ```bash
   #!/usr/bin/env bash
   set -e
   FILE="project.godot"
   # Look for emulate_mouse_from_touch=false in [input_devices.pointing] section
   IN_SECTION=$(awk '/^\[input_devices.pointing\]/,/^\[/' "$FILE")
   if echo "$IN_SECTION" | grep -qE "emulate_mouse_from_touch[[:space:]]*=[[:space:]]*false"; then
       echo "lint_emulate_mouse_from_touch PASS"
       exit 0
   fi
   echo "::error::project.godot [input_devices.pointing] missing 'emulate_mouse_from_touch=false' (R-3 / CR-2e violation)"
   exit 1
   ```

6. **`lint_balance_entities_input_handling.sh`** (mirrors `lint_balance_entities_hp_status.sh`):
   ```bash
   #!/usr/bin/env bash
   set -e
   FILE="assets/data/balance/balance_entities.json"
   declare -A EXPECTED=(
       ["TOUCH_TARGET_MIN_PX"]="44"
       ["TILE_WORLD_SIZE"]="64"
       ["TPP_DOUBLE_TAP_WINDOW_MS"]="500"
       ["DISAMBIG_EDGE_PX"]="8"
       ["DISAMBIG_TILE_PX"]="32"
       ["PAN_ACTIVATION_PX"]="16"
       ["MIN_TOUCH_DURATION_MS"]="80"
   )
   FAILED=0
   for key in "${!EXPECTED[@]}"; do
       VALUE=$(jq -r ".${key} // empty" "$FILE")
       if [ -z "$VALUE" ]; then
           echo "::error::balance_entities.json missing key: $key"
           FAILED=$((FAILED + 1))
       fi
   done
   if [ "$FAILED" -gt 0 ]; then
       echo "lint_balance_entities_input_handling FAIL"
       exit 1
   fi
   echo "lint_balance_entities_input_handling PASS"
   ```

7. **CI wiring template** (append to `.github/workflows/tests.yml` after existing hp-status lints):
   ```yaml
   - name: 'Lint input_router no _input override (Advisory C)'
     run: bash tools/ci/lint_input_router_no_input_override.sh
   - name: 'Lint input_router INPUT_BLOCKED drop without set_input_as_handled (Advisory C)'
     run: bash tools/ci/lint_input_router_input_blocked_drop_without_set_input_as_handled.sh
   - name: 'Lint input_router signal emission outside input domain (TR-017)'
     run: bash tools/ci/lint_input_router_signal_emission_outside_input_domain.sh
   - name: 'Lint input_router hardcoded bindings (CR-1b)'
     run: bash tools/ci/lint_input_router_hardcoded_bindings.sh
   - name: 'Lint input_router G-15 reset obligations (TR-013)'
     run: bash tools/ci/lint_input_router_g15_reset.sh
   - name: 'Lint emulate_mouse_from_touch=false (R-3 / CR-2e)'
     run: bash tools/ci/lint_emulate_mouse_from_touch.sh
   - name: 'Lint balance_entities input-handling 7 keys'
     run: bash tools/ci/lint_balance_entities_input_handling.sh
   ```

8. **`production/qa/evidence/input_router_verification_summary.md` template**:
   ```markdown
   # InputRouter Epic Verification Summary (Story 010 epic-terminal rollup)

   **Epic**: input-handling
   **Story**: story-010-epic-terminal-perf-lints-evidence
   **ADR**: ADR-0005 §Verification Required (6 items) + EPIC.md Same-Patch Obligations §4

   ## 6 Mandatory Verification Items — Final Status

   | # | Item | Doc | Status | Polish-Deferred? |
   |---|------|-----|--------|------------------|
   | 1 | Dual-focus end-to-end Android+macOS | `_01_dual_focus.md` (story-005) | [Polish-deferred / Verified] | YES (Polish-deferable) |
   | 2 | SDL3 gamepad detection Android+iOS | `_02_sdl3_gamepad.md` (story-005) | [Polish-deferred / Verified] | YES (Polish-deferable) |
   | 3 | emulate_mouse_from_touch in-editor | `_03_emulate_mouse_from_touch.md` (story-008) | Verified (project.godot grep) | NO |
   | 4 | Recursive Control disable cross-check | `_04_recursive_control_disable.md` (story-007) | Verified (headless GdUnit4) | NO |
   | 5a | DisplayServer.screen_get_size logical pixels | `_05a_displayserver_screen_get_size.md` (story-008) | Verified macOS (Polish-deferred Android) | PARTIAL |
   | 5b | Safe-area API name | `_05b_safe_area_api.md` (story-009) | Resolved (observed: [API_NAME or fallback]) | NO |
   | 6 | Touch event index stability physical hardware | `_06_touch_event_index_stability.md` (story-009) | Polish-deferred | YES (Polish-deferable) |

   ## Polish-Deferred Item Summary
   - Items #1, #2, #5a-Android, #6 → 4 reactivation triggers documented in TD-054
   - Total Polish-phase verification effort: 4-6h
   - Reactivation conditions: physical Android 14+ AND iOS 17 devices available + first export build green per platform

   ## Headless-Verified Item Summary (4/6 in MVP)
   - Items #3, #4, #5b: fully verified in headless GdUnit4 + project.godot grep
   - Item #5a: macOS dev box verified; Android Polish-deferred

   ## Performance Baseline (story-010 AC-1)
   - `_handle_event` p99 < 0.05ms (1000-iter on macOS dev): [TO BE FILLED AT IMPLEMENTATION]
   - 10k synthetic events throughput: [TO BE FILLED] ms (target < 500 ms)
   - `_ready()` autoload init: [TO BE FILLED] ms (target < 5 ms)

   ## CI Lint Coverage (9 new lints)
   1. lint_input_router_no_input_override.sh (Advisory C)
   2. lint_input_router_input_blocked_drop_without_set_input_as_handled.sh (Advisory C)
   3. lint_input_router_signal_emission_outside_input_domain.sh (TR-017)
   4. lint_input_router_hardcoded_bindings.sh (CR-1b)
   5. lint_input_router_g15_reset.sh (TR-013 — 12 fields × N test files)
   6. lint_emulate_mouse_from_touch.sh (R-3 / CR-2e)
   7. lint_balance_entities_input_handling.sh (7 keys safe-range)
   ```

9. **TD entries** in `docs/tech-debt-register.md`:
   ```markdown
   ### TD-054 — Input Handling Polish-tier on-device verification rollup

   **Status**: Open
   **Priority**: Polish (Beta blocker)
   **Logged**: 2026-MM-DD (story-010 epic-terminal)
   **Estimated effort**: 4-6h Polish phase

   **Reactivation triggers**:
   - Physical Android 14+ device available + first Android export build green
   - Physical iOS 17 device available + first iOS export build green
   - At least 1 device with notch (e.g. Pixel 6+, iPhone 13+) for safe-area #5b Android verification

   **Items deferred**:
   - Verification #1 dual-focus on Android (macOS verified headless)
   - Verification #2 SDL3 gamepad on Android+iOS (synthetic event coverage in headless)
   - Verification #5a Android screen_get_size logical-pixel return (macOS verified)
   - Verification #6 touch event index physical hardware (synthetic event cancel logic verified headless)

   **Ready-to-ship fallback**: All headless-verifiable items #3, #4, #5b (dev), #5a (mac dev) are verified MVP. The 4 Polish-deferred items confirm engine doesn't subvert behavior on real devices; without confirmation, MVP ship-risk is accepted as LOW (engine reference docs + godot-specialist 2026-04-30 PASS items + headless coverage cumulatively).

   ### TD-055 — 5 cross-system provisional contracts pending downstream ADRs

   **Status**: Open
   **Priority**: Architecture (per-ADR resolution)
   **Logged**: 2026-MM-DD (story-010 epic-terminal)
   **Estimated effort**: 1-2h per downstream ADR (cross-doc verification)

   **5 unwritten ADRs to widen-not-narrow the InputRouter locked contracts**:
   1. Camera ADR — `screen_to_grid` + `camera_zoom_min` clamp + drag state ownership (OQ-2)
   2. Grid Battle ADR — `is_tile_in_move_range` + `is_tile_in_attack_range` + `confirm_move/attack` + `restore_unit_to_pre_move` + `is_tile_occupied` + `get_unit_coord/facing`
   3. Battle HUD ADR — `show_unit_info` + `show_tile_info` + `dismiss_preview` + `show_magnifier` + `panel_reposition_request` subscription + reads `get_active_input_mode`
   4. Settings/Options ADR — `set_binding(action, event)` runtime remap consumer
   5. Tutorial ADR — subscribes to `input_action_fired` for step detection

   **Reactivation triggers**: each downstream ADR's `/architecture-decision` invocation. Cross-doc verification sweep documents widen-not-narrow compliance per provisional-dependency strategy (4 prior precedents).

   ### TD-056 — ADR-0001 line 168 carried advisory amendment

   **Status**: Open
   **Priority**: Cross-doc consistency
   **Logged**: 2026-MM-DD (story-010 epic-terminal); originally surfaced delta #6 Item 10a 2026-04-30
   **Estimated effort**: 30 min — single-line ADR-0001 edit + downstream consumer audit

   **Description**: ADR-0001 line 168 declares `signal input_action_fired(action: String, context: InputContext)` but ADR-0005 + GDD + ACTIONS_BY_CATEGORY all use `StringName` for action names (hot-path StringName literal convention). Amendment: change `action: String` → `action: StringName`. Downstream consumers: any GameBus subscriber to `input_action_fired` must accept `StringName` parameter.

   **Reactivation trigger**: next ADR-0001 amendment OR general housekeeping pass (LOW priority — does not block any ship-blocking ACs since StringName auto-converts to String at call boundary).
   ```

10. **Default bindings JSON content authoring** (AC-10): final `default_bindings.json` content with all 23 actions × at least 1 binding. Reference table:
    ```jsonc
    {
        "_schema_version": "1.0.0",
        "_authority": "ADR-0005 §4 + GDD §Action System; story-002 created + story-009 added 2 gestures + story-010 final content",
        "unit_select": [{"type": "mouse_button", "button_index": 1}, {"type": "screen_touch"}],
        "move_target_select": [{"type": "mouse_button", "button_index": 1}, {"type": "screen_touch"}],
        "move_confirm": [{"type": "key", "keycode": 4194309}, {"type": "screen_touch"}],
        "move_cancel": [{"type": "key", "keycode": 4194305}, {"type": "mouse_button", "button_index": 2}],
        "attack_target_select": [{"type": "mouse_button", "button_index": 1}, {"type": "screen_touch"}],
        "attack_confirm": [{"type": "key", "keycode": 4194309}, {"type": "screen_touch"}],
        "attack_cancel": [{"type": "key", "keycode": 4194305}, {"type": "mouse_button", "button_index": 2}],
        "undo_last_move": [{"type": "key", "keycode": 90}, {"type": "screen_touch"}],
        "end_unit_turn": [{"type": "key", "keycode": 84}, {"type": "screen_touch"}],
        "camera_pan": [{"type": "mouse_button", "button_index": 3}, {"type": "screen_drag"}],
        "camera_zoom_in": [{"type": "key", "keycode": 61}, {"type": "screen_drag"}],
        "camera_zoom_out": [{"type": "key", "keycode": 45}, {"type": "screen_drag"}],
        "camera_snap_to_unit": [{"type": "key", "keycode": 70}, {"type": "screen_touch"}],
        "camera_pinch_zoom": [{"type": "screen_drag"}],
        "camera_two_finger_tap_cancel": [{"type": "screen_touch"}],
        "open_unit_info": [{"type": "key", "keycode": 73}, {"type": "screen_touch"}],
        "open_game_menu": [{"type": "key", "keycode": 4194305}, {"type": "screen_touch"}],
        "close_menu": [{"type": "key", "keycode": 4194305}, {"type": "screen_touch"}],
        "end_player_turn": [{"type": "key", "keycode": 32}, {"type": "screen_touch"}],
        "end_phase_confirm": [{"type": "key", "keycode": 4194309}, {"type": "screen_touch"}],
        "action_confirm": [{"type": "key", "keycode": 4194309}, {"type": "screen_touch"}],
        "action_cancel": [{"type": "key", "keycode": 4194305}, {"type": "screen_touch"}],
        "toggle_input_hints": [{"type": "key", "keycode": 4194332}, {"type": "screen_touch"}]
    }
    ```
    23 actions × multiple bindings per action. Reference Godot keycode table for stable values (`KEY_ENTER=4194309`, `KEY_ESCAPE=4194305`, `KEY_F1=4194332`, etc).

11. **EPIC.md update** (AC-14): Status `Ready` → `Complete (2026-MM-DD)`; Stories table fully populated; final regression count `≥837`; commit ref recorded once epic-terminal commit lands. Mirrors hp-status EPIC.md update precedent.

12. **Sprint-3 close-out**: this story closes S3-04 fully (all 10 stories Complete). Sprint-3 progress: must-have 3/3 + should-have 1/2 done (S3-04 complete; S3-05 yaml hygiene + S3-06 TD-042 still backlog OR nice-to-have).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Future epic**: Camera ADR (TD-055 reactivation), Grid Battle ADR (TD-055), Battle HUD ADR (TD-055), Settings/Options ADR (TD-055), Tutorial ADR (TD-055)
- **Polish phase**: Verification items #1, #2, #5a-Android, #6 on-device confirmation (TD-054)
- **Future housekeeping**: ADR-0001 line 168 amendment (TD-056)

---

## QA Test Cases

*Authored inline (lean mode QL-STORY-READY skip).*

- **AC-1**: Performance baseline 4 tests pass
  - Given: production InputRouter `_handle_event` + `_ready()` paths complete
  - When: `tests/performance/foundation/input_router_perf_test.gd` invoked
  - Then: 4 tests pass; p99 < 0.05ms; 10k events < 500ms; init < 5ms
- **AC-2 ... AC-8**: Lint scripts exit 0 on production source
  - Given: production InputRouter source complete + 7 BalanceConstants + project.godot setting + 12-field G-15 reset in all test files
  - When: each lint script invoked
  - Then: each exits 0 with PASS message
  - Edge cases: each lint also tested with intentionally-malformed fixture asserting exit 1 with diagnostic
- **AC-9**: Verification summary doc exists + structure
  - Given: `production/qa/evidence/input_router_verification_summary.md`
  - When: read content
  - Then: 6-item table present; Polish-deferred items clearly marked; CI lint count == 9
- **AC-10**: default_bindings.json complete
  - Given: file content
  - When: parse + count non-meta keys
  - Then: 23 keys present (22 - grid_hover + 2 new gestures); each has ≥1 binding entry; each value is Array[Dictionary] with valid `type` field
- **AC-11**: 3 TD entries logged
  - Given: `docs/tech-debt-register.md`
  - When: grep for TD-054 + TD-055 + TD-056 headers
  - Then: all 3 sections present with reactivation triggers
- **AC-12**: 9 lints in workflow
  - Given: `.github/workflows/tests.yml`
  - When: grep for each new lint script name
  - Then: each appears as a workflow step
- **AC-13**: Final regression baseline
  - Given: full suite + 4 perf tests
  - When: invoke
  - Then: ≥837 cases / 0 errors / 0 failures / 0 orphans / Exit 0; all 9 input-handling lints PASS
- **AC-14**: EPIC.md updated to Complete
  - Given: `production/epics/input-handling/EPIC.md`
  - When: read
  - Then: Status field == "Complete (2026-MM-DD)"; Stories table populated with all 10 stories at Complete

---

## Test Evidence

**Story Type**: Config/Data (lint scripts + perf tests + evidence docs + TD entries; minimal new production code)
**Required evidence**:
- Logic: `tests/performance/foundation/input_router_perf_test.gd` — must exist + 4 tests + must pass
- Config/Data: 7 lint scripts at `tools/ci/lint_input_router_*.sh` + `lint_emulate_mouse_from_touch.sh` + `lint_balance_entities_input_handling.sh` (9 total) — all exit 0
- Visual/Feel: `production/qa/evidence/input_router_verification_summary.md` — epic-terminal rollup
- Smoke: full GdUnit4 suite Exit 0 with all new lints in CI

**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 002-009 (all production code + verification evidence files must exist before story-010 wraps with lints + perf + summary). Story-010 is the EPIC TERMINAL — runs LAST per Implementation Order in EPIC.md.
- **Unlocks**: Sprint-3 S3-04 marked done; epic graduates to Complete; Camera ADR / Grid Battle ADR / Battle HUD ADR / Settings ADR / Tutorial ADR can begin authoring (provisional-contract widen-not-narrow obligations now locked); Foundation layer 4/5 + 1 Ready → 5/5 Complete on epic close-out
