# Story 007: Epic terminal — 4 forbidden_pattern lints + CI wiring + epic close

> **Epic**: Camera | **Status**: Complete | **Layer**: Feature | **Type**: Config/Data | **Estimate**: 0.5h
> **ADR**: ADR-0013 §11 + Migration Plan story-007 spec

## Acceptance Criteria

- [x] 4 forbidden_pattern lint scripts at `tools/ci/lint_camera_*.sh` (chmod +x):
  1. `lint_camera_signal_emission.sh` — BattleCamera MUST NOT emit GameBus signals (`.emit` anchor)
  2. `lint_camera_exit_tree_disconnect.sh` — `_exit_tree` exists AND contains `GameBus.input_action_fired.disconnect` (godot-specialist concern #2 enforcement)
  3. `lint_camera_no_hardcoded_zoom.sh` — no literal `0.70/2.00/1.00/0.10` floats outside comments
  4. `lint_camera_external_screen_to_grid.sh` — exactly 1 `func screen_to_grid` in src/ (BattleCamera as sole impl)
- [x] All 4 lints PASS against shipped code (verified)
- [x] 5 CI lint steps wired into `.github/workflows/tests.yml` (4 above + `lint_balance_entities_camera.sh` from story-006)
- [x] Full GdUnit4 regression: 757/757 cases / 0 errors / 0 failures / 0 orphans / Exit 0 (was 743 → +14 from camera tests = 9th consecutive failure-free baseline)
- [x] EPIC.md Status `Ready` → `Complete (2026-05-02)`; Stories table populated 7/7
- [x] `production/epics/index.md` updated: Feature layer 1/13 → 2/13 (camera Complete)

## Implementation

5 lint scripts at `tools/ci/lint_camera_*.sh` + `tools/ci/lint_balance_entities_camera.sh`. CI wiring in `.github/workflows/tests.yml` (5 new steps after `lint_damage_calc_no_stub_copy.sh`).

## Test Evidence

**Story Type**: Config/Data. Required: smoke check (all lints PASS) + full regression PASS. Status: all 5 lints PASS + 757/757 regression PASS.

## Cross-ADR Follow-Up Resolution

Per ADR-0013 R-7 + TD-057 candidate (HPStatusController + TurnOrderRunner `_exit_tree` audit):
- **HPStatusController**: ALREADY HAS `_exit_tree()` at `src/core/hp_status_controller.gd:45` with `GameBus.unit_turn_started.disconnect` — **partial false alarm** (no retrofit needed).
- **TurnOrderRunner**: audit DEFERRED to grid-battle-controller epic story-009 (sprint-5 S5 work).

TD-057 status: partial-resolved (1 of 2 systems verified clean); remaining audit carries to sprint-5.
