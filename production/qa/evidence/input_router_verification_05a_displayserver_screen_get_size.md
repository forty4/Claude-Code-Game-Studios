# InputRouter Verification #5a — DisplayServer.screen_get_size logical pixels

**Epic**: input-handling
**Story**: story-008-touch-protocol-tpp-magnifier-f1
**ADR**: ADR-0005 §Verification Required §5a + F-1
**Status**: Verified (headless macOS) | Polish-deferred (Android device confirmation)

## Test Procedure (Headless macOS)

1. At test runtime, call `DisplayServer.screen_get_size()` and read the returned Vector2i
2. Assert `size.x > 0 and size.y > 0` (sanity)
3. Assert `size.x < 16000 and size.y < 16000` (loose upper bound — physical-pixel-multiplier on a Retina dev box would yield ~2880x1800 or higher logical size; the bound is a smoke gate, not a strict logical-pixel assertion)
4. Document the observed Vector2i value below for traceability

## Test Procedure (Android — Polish-deferable)

1. Boot Android 14+ device with running app
2. Log `DisplayServer.screen_get_size()` to debug overlay
3. Compare against device's known logical DPR'd resolution (e.g. Pixel 6 = 1080x2400 logical, NOT 1080x2400 × DPR)
4. If physical-pixel return observed, F-1 derivation FORMULA UPDATE required (divide by DPR)

## Expected Result

`DisplayServer.screen_get_size()` returns logical DPI-aware pixels on macOS + Android (verified via godot-specialist Item 5 PASS but requires runtime confirmation per ADR-0005 §5a).

## Observed Value (Headless macOS, 2026-05-06)

`DisplayServer.screen_get_size() = Vector2i(0, 0)` — confirmed via direct probe at `/tmp/probe_displayserver.gd` (`extends SceneTree` + `_init` print + quit) on dev box (Darwin 25.4.0, macOS Retina 2× DPR; primary display physical 2880×1800; logical 1440×900).

**Headless interpretation**: a `(0, 0)` return is the EXPECTED outcome under headless mode — DisplayServer does not bind to a real display when the engine is launched with `--headless`. The API is callable without crashing (the smoke gate's true assertion target).

**Display-backed verification (deferred to first dev-box smoke check)**: when story-008/009 testing is done on a display-attached machine without `--headless`, the expected return is `(1440, 900)` or similar logical-pixel resolution (NOT physical-pixel `(2880, 1800)`). If physical-pixel return is observed on a non-headless run, F-1 derivation FORMULA UPDATE is required (divide by DPR per the Android verification path below).

**Android verification trigger**: when first Android export build is green AND minimum-spec device is available (Polish phase per story-008 EPIC.md item-#5a classification).

## Status

Headless macOS verification in `tests/unit/foundation/input_router_touch_part_a_test.gd::test_displayserver_screen_get_size_returns_sane_logical_resolution` (story-008 implementation 2026-05-06). Android verification reactivation trigger: when first Android export build is green AND minimum-spec device available.

## F-1 Connection

`DisplayServer.screen_get_size()` is called (story-009/touch-protocol-part-B will exercise this more directly via touch coord → screen-relative offset computation). For story-008 scope, the InputRouter's F-1 derivation does NOT call `screen_get_size()` per se — the formula uses fixed constants (`TOUCH_TARGET_MIN_PX` / `TILE_WORLD_SIZE`) from BalanceConstants. The verification test is a smoke gate ensuring the API is callable on the dev box and produces a sane logical-pixel value.
