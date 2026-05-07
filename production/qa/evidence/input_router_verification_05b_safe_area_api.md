# InputRouter Verification #5b — Safe-Area API Name Resolution

**Epic**: input-handling
**Story**: story-009-touch-protocol-pan-tap-gestures-panel
**ADR**: ADR-0005 §Verification Required §5b + delta #6 Item 5
**Status**: Resolved (headless macOS) — observed "neither candidate returns Vector4; get_display_safe_area returns Rect2i (Vector4.ZERO fallback on desktop); see implementation note below"

## Test Procedure (Headless macOS)

1. At `_ready()`, call `DisplayServer.has_method("window_get_safe_title_margins")`; log result
2. If true, call the method + log return value + check type
3. Call `DisplayServer.has_method("get_display_safe_area")`; log result
4. If true, call the method + log return value + check type
5. Document fallback `Vector4.ZERO` outcome

## Test Procedure (Android — Polish-deferable)

1. Boot Android 14+ device with notch (e.g. Pixel 6+)
2. Log safe-area inset values to debug overlay
3. Compare against device's known notch dimensions
4. Update this doc with confirmation

## Expected Result

`get_display_safe_area` (Candidate 2) returns `Rect2i` convertible to Vector4 margins on Android 14+ with notch. `window_get_safe_title_margins` (Candidate 1) returns `Vector3i` (title bar margins — NOT Vector4 as originally speculated); it is skipped in `_resolve_safe_area_api` in favour of Candidate 2. Fallback `Vector4.ZERO` acceptable for desktop builds.

## Observed Result (macOS dev box — Godot 4.6.2.stable, headless)

Probe command run at story-009 implementation time:
```
HAS_window_get_safe_title_margins=true
HAS_get_display_safe_area=true
RESULT_A=(0, 0, 0)   ← type is Vector3i (NOT Vector4 as spec assumed)
RESULT_B=[P: (0, 0), S: (0, 0)]   ← type is Rect2i; screen_get_size()=(0,0) in headless
```

**Candidate 1 deviation**: `window_get_safe_title_margins` exists in Godot 4.6 but returns `Vector3i` (left, right, bottom title bar margins), not `Vector4`. The story spec assumed `Vector4` return — this is a post-cutoff API detail. The implementation skips Candidate 1 and proceeds directly to Candidate 2.

**Candidate 2 result**: `get_display_safe_area` returns `Rect2i` as expected. On headless macOS with `screen_get_size()=(0,0)`, the computed insets are all 0.0 — valid fallback.

**Observed `_safe_area_inset` value on dev box**: `Vector4(0, 0, 0, 0)` (no notch on macOS desktop)

**Implementation choice**: `_resolve_safe_area_api()` implements Candidate 2 (`get_display_safe_area → Rect2i → Vector4` margins) with a `screen_size.x > 0 and screen_size.y > 0` guard to prevent divide-by-zero on headless. Falls back to `Vector4.ZERO` when screen is zero-size or API not present.

## Status

Headless test coverage: `tests/unit/foundation/input_router_touch_part_b_test.gd::test_resolve_safe_area_api_returns_vector4_or_fallback_zero` and `::test_safe_area_inset_cached_at_ready`.

Mandatory per EPIC.md item-#5b. Android reactivation trigger: first Android export green + notch device. When Android export is first green, re-run probe with `godot --headless --path . -s /tmp/probe_safe_area.gd` on device and update the Observed Result section.
