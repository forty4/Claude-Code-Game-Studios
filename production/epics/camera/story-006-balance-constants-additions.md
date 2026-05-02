# Story 006: 6 BalanceConstants entries + key-presence lint

> **Epic**: Camera | **Status**: Complete | **Layer**: Feature | **Type**: Config/Data | **Estimate**: 0.5h
> **ADR**: ADR-0013 §Decision §2

## Acceptance Criteria

- [x] 6 keys added to `assets/data/balance/balance_entities.json`:
  - `TILE_WORLD_SIZE = 64` (input-handling F-1 + map-grid prerequisite)
  - `TOUCH_TARGET_MIN_PX = 44` (input-handling F-1 floor)
  - `CAMERA_ZOOM_MIN = 0.70` (F-1 derived: 44/64=0.6875 → 0.70 with comfort margin)
  - `CAMERA_ZOOM_MAX = 2.00` (PC tactical readability ceiling)
  - `CAMERA_ZOOM_DEFAULT = 1.00` (tile = 64px native)
  - `CAMERA_ZOOM_STEP = 0.10` (wheel-zoom delta per camera_zoom_in/out event)
- [x] `tools/ci/lint_balance_entities_camera.sh` validates all 6 keys present (PASS)

**Note**: `TILE_WORLD_SIZE` + `TOUCH_TARGET_MIN_PX` are also input-handling F-1 prerequisites — shipped here as bundled obligation. When input-handling epic ships (sprint-5+), it does NOT need to re-add these (camera epic owns the addition via this story).

## Implementation

`assets/data/balance/balance_entities.json` (+6 entries) + `tools/ci/lint_balance_entities_camera.sh` (~30 LoC).

## Test Evidence

**Story Type**: Config/Data. Required: smoke check (lint PASS). Status: lint PASS verified.
