# Story 003: Overworld pause/restore discipline

> **Epic**: scene-manager
> **Status**: Complete
> **Layer**: Platform
> **Type**: Logic
> **Estimate**: small (~2-3h) — 2 symmetric methods (pause + restore) + 6 unit tests appended to existing `scene_manager_test.gd` (no new test file); recursive Control disable already de-risked via ADR-0002 fallback path
> **Manifest Version**: 2026-04-20

## Context

**GDD**: — (infrastructure; authoritative spec is ADR-0002)
**Requirement**: `TR-scene-manager-002`

**ADR Governing Implementation**: ADR-0002 — §Key Interfaces `_pause_overworld` + §Decision (pause discipline) + §Validation Criteria V-6
**ADR Decision Summary**: "Overworld retained (not freed) during battle. Pause = `process_mode = PROCESS_MODE_DISABLED` + `visible = false` + `set_process_input(false)` + `set_process_unhandled_input(false)` + root Control recursive `mouse_filter = MOUSE_FILTER_IGNORE`. Restore = inverse on exit."

**Engine**: Godot 4.6 | **Risk**: MEDIUM (recursive Control disable is a 4.5+ feature; exact propagation property ambiguous in engine-reference — verification required before coding)
**Engine Notes**: Per ADR-0002 §Engine Compatibility Verification Required #1: "Confirm exact recursive-disable property name in Godot 4.6 (`mouse_filter` inheritance behavior on Control trees)." Fallback path documented in §Neutral Consequences: per-Control `set_mouse_filter(MOUSE_FILTER_IGNORE)` walk if the 4.5+ recursive-disable API name differs. Target-device verification (V-7) belongs to story 007, but specialist should consult `docs/engine-reference/godot/modules/ui.md §Recursive Disable` before coding.

**Control Manifest Rules (Platform layer)**:
- Required: Overworld retained via all 4 suppression properties + root Control recursive mouse_filter ignore — NOT freed
- Required: Restoration flips all 4 properties back on exit from IN_BATTLE
- Forbidden: touching Overworld focus state (focus restoration belongs to Overworld UI, not SceneManager — see ADR-0002 §Risks R-3)
- Guardrail: SceneManager itself holds zero gameplay state (Overworld reference is a cached Node*, not state)

## Acceptance Criteria

*Derived from ADR-0002 §Key Interfaces + V-6:*

- [ ] `_pause_overworld()` private method implemented on SceneManager:
  - Sets `_overworld_ref.process_mode = Node.PROCESS_MODE_DISABLED`
  - Sets `_overworld_ref.visible = false`
  - Calls `_overworld_ref.set_process_input(false)`
  - Calls `_overworld_ref.set_process_unhandled_input(false)`
  - Looks up `_overworld_ref.get_node_or_null("UIRoot") as Control`; if present, sets `root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE`
  - Guards with `if not is_instance_valid(_overworld_ref): return` at top
- [ ] `_restore_overworld()` private method implemented (inverse of `_pause_overworld`):
  - `process_mode = Node.PROCESS_MODE_INHERIT`
  - `visible = true`
  - `set_process_input(true)`
  - `set_process_unhandled_input(true)`
  - Root Control `mouse_filter = Control.MOUSE_FILTER_STOP`
  - `is_instance_valid` guard
- [ ] `_overworld_ref: Node = null` private var initialized at SceneManager level (populated by story 004's `_on_battle_launch_requested` via `_overworld_ref = get_tree().current_scene`)
- [ ] NO public API for pause/restore — these are private, called internally by future stories 004 (on LOADING_BATTLE entry) and 005/006 (on restoration paths)
- [ ] Unit tests verify all 4 properties toggle correctly via instrumented Overworld mock (no real scene loading required)
- [ ] Unit test verifies `UIRoot` Control mouse_filter toggles correctly when present; gracefully skips when absent (overworld hierarchy without UIRoot)
- [ ] Unit test verifies `is_instance_valid` guard: calling pause/restore with `_overworld_ref == null` is a no-op (no crash)

## Implementation Notes

*From ADR-0002 §Key Interfaces + `.claude/rules/godot-4x-gotchas.md`:*

1. **Implementation** — matches ADR-0002 §Key Interfaces `_pause_overworld` snippet verbatim. Add the symmetric `_restore_overworld` with property values inverted.

2. **Recursive Control disable property name** — ADR-0002 flags this as 4.5+ verification required. Before writing the mouse_filter line, check `docs/engine-reference/godot/modules/ui.md §Recursive Disable` for the exact property. If the reference doesn't specify the propagation property, use the explicit `MOUSE_FILTER_IGNORE` on the root Control as a conservative fallback (the ADR documents this is acceptable). Target-device verification of actual touch-event blocking is story 007's responsibility.

3. **UIRoot lookup** — `_overworld_ref.get_node_or_null("UIRoot")` is the contract. If Overworld scene doesn't have a child named exactly "UIRoot", the Control-level mouse_filter isn't set (safe no-op). This is Scenario Progression epic's responsibility to provide — don't enforce presence here.

4. **Null-safety** — `is_instance_valid(_overworld_ref)` guard at top of both pause/restore methods. Without it, a pause after `_overworld_ref` went null (e.g., user quit mid-battle) would crash. Story 001's skeleton leaves `_overworld_ref = null` initial; this story assumes the caller has populated it (story 004 will).

5. **Unit test mock strategy** — create a minimal `Node` instance in the test, set it as `_overworld_ref` on a SceneManager stub (via story 002's stub pattern), call `_pause_overworld`, assert the 4 properties. Add a `UIRoot` Control child and verify mouse_filter toggles. Use `SceneManagerStub.swap_in()` for isolation.

6. **Focus restoration NOT this story's job** — per ADR-0002 §Risks R-3, Overworld UI owns focus state via `visibility_changed` hook. SceneManager does NOT touch focus. If someone asks for focus-restoration code here, reject.

## Out of Scope

- Target-device verification of recursive Control disable (V-7) — story 007
- Calling `_pause_overworld` from `_on_battle_launch_requested` — story 004
- Calling `_restore_overworld` from teardown/error handlers — stories 005, 006
- Focus state management — Overworld UI responsibility (ADR-0002 §R-3)

## QA Test Cases

*Test file*: `tests/unit/core/scene_manager_test.gd` (add test cases; don't fork)

- **AC-1** (pause sets all 4 properties):
  - Given: SceneManagerStub.swap_in() + fake Overworld Node assigned to `_overworld_ref`
  - When: `sm._pause_overworld()`
  - Then: `process_mode == PROCESS_MODE_DISABLED`, `visible == false`, `is_processing_input() == false`, `is_processing_unhandled_input() == false`

- **AC-2** (restore inverts all 4 properties):
  - Given: paused Overworld (as AC-1)
  - When: `sm._restore_overworld()`
  - Then: `process_mode == PROCESS_MODE_INHERIT`, `visible == true`, `is_processing_input() == true`, `is_processing_unhandled_input() == true`

- **AC-3** (UIRoot mouse_filter toggles):
  - Given: Overworld with UIRoot Control child, mouse_filter initially STOP
  - When: pause → restore cycle
  - Then: after pause, UIRoot.mouse_filter == IGNORE; after restore, UIRoot.mouse_filter == STOP

- **AC-4** (no UIRoot is safe):
  - Given: Overworld without UIRoot child
  - When: pause() called
  - Then: no crash; other 4 properties still toggle correctly

- **AC-5** (null _overworld_ref guard):
  - Given: `_overworld_ref = null`
  - When: pause() and restore() called
  - Then: no crash; no property access errors

- **AC-6** (freed _overworld_ref guard):
  - Given: Overworld Node assigned then freed before pause() call
  - When: pause() / restore() called
  - Then: no crash (is_instance_valid returns false → early return)

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/core/scene_manager_test.gd` — must exist and pass (BLOCKING gate). Test cases added to the existing file from story 001.
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: Story 001 (SceneManager skeleton — `_overworld_ref` var exists); Story 002 (SceneManagerStub for test isolation)
- **Unlocks**: Story 004 (async load calls `_pause_overworld` on LOADING_BATTLE entry); stories 005/006 (call `_restore_overworld` on exit paths)

## Completion Notes

**Completed**: 2026-04-22
**Criteria**: 7/7 passing, all 6 QA test cases mapped to test functions
**Test Evidence**: `tests/unit/core/scene_manager_test.gd` — 6 new test functions appended (AC-1..AC-6), 15 total tests in file. Full suite 79/79, 0 orphans, exit 0.
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (/code-review 2026-04-22, lean). F-1 fix applied in-cycle; F-2/T-1 logged as tech debt.
**Deviations**: None blocking.
- **OUT OF SCOPE (justified)**: Widened `_overworld_ref: Node` → `_overworld_ref: CanvasItem` at `scene_manager.gd:56` (originally declared in story-001). Latent type-safety bug caught empirically this cycle: `_pause_overworld` mutates `.visible` which is CanvasItem-only; bare `Node.new()` test mock crashed at runtime. Widening the declared type makes the implicit contract explicit and lets the compiler verify it. Story-001 tests still 9/9 pass (AC-6 via `.set()` bypass remains valid).
- **ADVISORY (deferred)**: F-2 nit — 5 tests use `sm.set("_overworld_ref", x)` where direct assignment would be more idiomatic; T-1 edge — no test for "UIRoot exists but isn't a Control" silent-skip case.
**Manifest Version compliance**: 2026-04-20 matches current control-manifest.
**Files changed**:
- `src/core/scene_manager.gd` — 2 new private methods (lines 104-137) + 1 declaration widened (line 56) with explanatory doc comment
- `tests/unit/core/scene_manager_test.gd` — 6 new test functions appended (lines 344-end, ~200 lines)

**Implementation notes for future stories**:
- Story-004 will populate `_overworld_ref` via `get_tree().current_scene as CanvasItem` (cast needed because `current_scene` returns Node) — see scene_manager.gd:56 doc comment
- `_pause_overworld` / `_restore_overworld` are idempotent no-ops on null or freed refs (by design, tested AC-5/AC-6)
- Recursive Control disable used the ADR-0002 conservative fallback path (explicit MOUSE_FILTER_IGNORE on root only; no recursive walk). Target-device verification of actual touch-event blocking is story-007's responsibility (V-7).
