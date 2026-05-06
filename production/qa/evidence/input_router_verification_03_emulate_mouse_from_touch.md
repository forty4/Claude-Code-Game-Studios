# InputRouter Verification #3 — emulate_mouse_from_touch=false

**Epic**: input-handling
**Story**: story-008-touch-protocol-tpp-magnifier-f1
**ADR**: ADR-0005 §Verification Required §3 + CR-2e + R-3
**Status**: Verified (headless via project.godot grep)

## Test Procedure (Headless)

1. Read `project.godot` content via `FileAccess.get_file_as_string("res://project.godot")`
2. Locate `[input_devices.pointing]` section header
3. Assert `emulate_mouse_from_touch=false` line present in the section
4. CI lint `tools/ci/lint_emulate_mouse_from_touch.sh` (story-010 wires) will enforce this on every push

## Expected Result

`emulate_mouse_from_touch=false` set in `[input_devices.pointing]` of `project.godot` for all builds. Touch events do NOT synthesize fake mouse events that would cause double-fire of the same action via two dispatch paths (InputRouter._unhandled_input would otherwise fire once for the touch + once for the synthesized mouse event).

## Status

Verified via headless test in `tests/unit/foundation/input_router_touch_part_a_test.gd::test_emulate_mouse_from_touch_disabled_in_project_godot` (story-008 implementation 2026-05-06). Mandatory per EPIC.md item-#3 classification (headless-verifiable; not Polish-deferable).

## Story-008 Implementation Notes

- The setting was previously absent from `project.godot` (no `[input_devices.pointing]` section existed). Story-008 same-patch added the section + setting + a clarifying comment block citing ADR-0005 §Verification Required §3 + CR-2e + R-3.
- Story-010 will wire the `tools/ci/lint_emulate_mouse_from_touch.sh` lint script to enforce this setting on every push.
