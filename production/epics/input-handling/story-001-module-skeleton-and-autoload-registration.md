# Story 001: InputRouter Autoload module skeleton + InputState/InputMode enums + InputContext payload + project.godot autoload registration

> **Epic**: Input Handling
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic (borderline-skeleton)
> **Estimate**: 2h
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/input-handling.md`
**Requirement**: `TR-input-handling-002`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005 — Input Handling — InputRouter Autoload + 7-State FSM (MVP scope)
**ADR Decision Summary**: TR-002 = InputRouter is `class_name InputRouter extends Node` autoloaded at `/root/InputRouter` (load order 4: GameBus → SceneManager → SaveManager → **InputRouter**); 6 mutable instance fields (`_state`, `_active_mode`, `_pre_menu_state`, `_undo_windows`, `_input_blocked_reasons`, `_bindings`); 5-precedent stateless-static REJECTED (Alternative 4 — engine-level structural incompatibility: Node lifecycle callbacks `_input`/`_unhandled_input` cannot fire on RefCounted; signal subscription identity for static-method Callables undefined in GDScript 4.x); battle-scoped Node form REJECTED (Alternative 1 — S6 MENU_OPEN must work outside battle scope).

**Engine**: Godot 4.6 | **Risk**: HIGH (governed by ADR-0005)
**Engine Notes**: Autoload registration in `[autoload]` section of `project.godot` per Godot 4.x format (`InputRouter="*res://src/foundation/input_router.gd"`; the leading `*` makes it an Autoload Node rather than just a script load). Per G-3 — autoload script must NOT declare matching `class_name` (would collide with the autoload identifier). Verified 2026-05-02 against ADR-0001 GameBus + ADR-0002 SceneManager + ADR-0003 SaveManager precedent: those 3 autoloads have `class_name` matching their autoload name and they work — meaning Godot 4.6 either tolerates the collision OR the G-3 gotcha was specific to a different pattern. **Verification at story-001 implementation time**: try `class_name InputRouter` first; if parse error fires per G-3 ("Class 'InputRouter' hides an autoload singleton"), drop the `class_name` declaration and reference via `(load("res://src/foundation/input_router.gd") as GDScript)` in tests per G-3 test consequence note. Typed `Dictionary[int, UndoEntry]` (Godot 4.4+ stable in 4.6); typed `Dictionary[StringName, Array[InputEvent]]` (4.4+ stable); `PackedStringArray` (4.0+ stable).

**Control Manifest Rules (Foundation layer + Global)**:
- Required: Autoload Node form for InputRouter (3-precedent autoload variant: ADR-0001 GameBus + ADR-0002 SceneManager + ADR-0003 SaveManager — InputRouter joins as load order 4); typed `Dictionary[K, V]` where keys/values are typed; `class_name` PascalCase + `snake_case` filenames; UPPER_SNAKE_CASE constants; StringName `&"action_name"` literals for action identifiers
- Forbidden: stateless-static utility class form for InputRouter (engine-level structural incompatibility per Alternative 4); battle-scoped Node form (Alternative 1; S6 MENU_OPEN must survive battle scope); String-based `connect()` (use typed signal connections); untyped Array/Dictionary; hardcoded gameplay values (route input bindings through `default_bindings.json` per CR-1b — story-002 enforces); per-frame emit through GameBus from `_input(event)` per ADR-0001 §7 (already enforced project-wide via `tools/ci/lint_per_frame_emit.sh`)
- Guardrail: InputRouter instance field count exactly 6 per ADR-0005 §1 line 119; field types match ADR-0005 §1 verbatim; `_bindings.clear()` MUST appear in `before_test()` reset per delta #6 godot-specialist Item 7 (omitting leaks `set_binding` remap state — story-010 lint enforces)

---

## Acceptance Criteria

*From ADR-0005 §1 + §2 + §4 + §5 + §6, scoped to this story:*

- [ ] **AC-1** InputRouter declared as `extends Node` at `src/foundation/input_router.gd` (NOT extends RefCounted; NOT battle-scoped; NOT stateless-static). `class_name InputRouter` declared OR omitted per G-3 verification — see Implementation Note #1
- [ ] **AC-2** InputRouter declares exactly 6 instance fields with exact types per ADR-0005 §1 line 119: `var _state: InputState = InputState.OBSERVATION`, `var _active_mode: InputMode = InputMode.KEYBOARD_MOUSE`, `var _pre_menu_state: InputState = InputState.OBSERVATION`, `var _undo_windows: Dictionary[int, UndoEntry] = {}`, `var _input_blocked_reasons: PackedStringArray = []`, `var _bindings: Dictionary[StringName, Array[InputEvent]] = {}`
- [ ] **AC-3** `enum InputState { OBSERVATION, UNIT_SELECTED, MOVEMENT_PREVIEW, ATTACK_TARGET_SELECT, ATTACK_CONFIRM, INPUT_BLOCKED, MENU_OPEN }` declared on InputRouter (int 0..6 wire-format for save/load forward-compat per ADR-0005 §5). Numeric value of each member must match the canonical ordering in GDD §States and Transitions (S0=OBSERVATION through S6=MENU_OPEN)
- [ ] **AC-4** `enum InputMode { KEYBOARD_MOUSE, TOUCH }` declared on InputRouter (int 0..1 wire-format; `KEYBOARD_MOUSE = 0`, `TOUCH = 1` — gamepad routes to `KEYBOARD_MOUSE` for MVP per OQ-1 + TR-011; future GAMEPAD mode reserved at int 2 per ADR-0005 §6)
- [ ] **AC-5** InputContext typed Resource declared at `src/foundation/payloads/input_context.gd` — `class_name InputContext extends Resource` with @export fields per ADR-0001 §7 line 168 carried-advisory direction (≥2-field typed payload). MVP fields: `@export var coord: Vector2i = Vector2i.ZERO` (tile coord for grid actions; Vector2i.ZERO for non-grid actions) + `@export var unit_id: int = -1` (target unit for tap-to-select; -1 for non-unit-targeted actions). Future fields can be added without breaking ADR-0005 contract (additive-only schema evolution per CR-1d)
- [ ] **AC-6** UndoEntry RefCounted declared at `src/foundation/payloads/undo_entry.gd` — `class_name UndoEntry extends RefCounted` with 3 fields per ADR-0005 §1 + CR-5: `var unit_id: int = -1`, `var pre_move_coord: Vector2i = Vector2i.ZERO`, `var pre_move_facing: int = 0` (facing as int 0..3 wire-format; aligns with future Camera/movement enum)
- [ ] **AC-7** `project.godot` `[autoload]` section contains `InputRouter="*res://src/foundation/input_router.gd"` at load order 4 (after GameBus + SceneManager + SaveManager; before any future foundation-layer autoload). Verify by reading `project.godot` and asserting line presence + ordering
- [ ] **AC-8** All public-method placeholders stubbed on InputRouter with exact signatures per ADR-0005 §Key Interfaces (read fresh at implementation time): `get_active_input_mode() -> InputMode` (returns `_active_mode`), `get_state() -> InputState` (returns `_state`), `set_binding(action: StringName, event: InputEvent) -> void` (body = `pass`), `_handle_event(event: InputEvent) -> void` (DI test seam — body = `pass`). All method bodies are `pass` for void / return current field value for getters
- [ ] **AC-9** InputRouter has NO `_ready()` body in this story (story-002 adds JSON load + InputMap population). `_input(event)` and `_unhandled_input(event)` likewise NOT implemented yet (story-002 wires `_unhandled_input` to call `_handle_event`)
- [ ] **AC-10** All 3 new `class_name` declarations (InputRouter — pending G-3 verification, InputContext, UndoEntry) resolve cleanly in `godot --headless --import --path .` (G-14 obligation; no class-cache parse errors; no G-12 built-in collision — verified Story-001 implementation time: `InputRouter` + `InputContext` + `UndoEntry` are NOT Godot built-in class names per `ClassDB.class_exists()` check per G-17)
- [ ] **AC-11** Regression baseline maintained: full GdUnit4 suite passes ≥743 cases (current baseline post hp-status epic) / 0 errors / 0 failures / 0 orphans / Exit 0; new test file `tests/unit/foundation/input_router_skeleton_test.gd` adds ≥6 tests covering AC-1..AC-10

---

## Implementation Notes

*Derived from ADR-0005 §1, §2, §4, §5, §6 + Migration Plan §From `[no current implementation]`:*

1. **G-3 verification at implementation time**: First attempt — declare `class_name InputRouter extends Node` in `src/foundation/input_router.gd`. Run `godot --headless --import --path .`. If parse error fires ("Class 'InputRouter' hides an autoload singleton"), drop the `class_name` line. Cross-check existing autoloads: `src/core/game_bus.gd` (declares `class_name GameBus`?), `src/foundation/scene_manager.gd`, `src/foundation/save_manager.gd`. If those existing autoloads have `class_name` declared AND the project parses cleanly, the gotcha was specific to an earlier Godot version OR a different declaration order — InputRouter can declare `class_name` too. Otherwise omit. Document outcome in `.claude/rules/godot-4x-gotchas.md` G-3 entry as a 4.6 verification update.

2. **File layout** (4 new src files + 1 modified project.godot):
   - `src/foundation/input_router.gd` — main InputRouter Node class with 6 fields + 2 enums + 4 stub methods
   - `src/foundation/payloads/input_router_enums.gd` — OPTIONAL: if GDScript 4.6 disallows enum declarations directly on autoload-pattern Node classes (untested), extract enums to a separate utility script. Default path: declare enums inline on InputRouter; only extract if first import pass fails
   - `src/foundation/payloads/input_context.gd` — InputContext typed Resource (2 @export fields)
   - `src/foundation/payloads/undo_entry.gd` — UndoEntry RefCounted (3 fields)
   - `project.godot` modify `[autoload]` section to append `InputRouter="*res://src/foundation/input_router.gd"` line; verify load order 4

3. **Field defaults** (verbatim from ADR-0005 §1 line 119):
   ```gdscript
   var _state: InputState = InputState.OBSERVATION
   var _active_mode: InputMode = InputMode.KEYBOARD_MOUSE
   var _pre_menu_state: InputState = InputState.OBSERVATION
   var _undo_windows: Dictionary[int, UndoEntry] = {}
   var _input_blocked_reasons: PackedStringArray = []
   var _bindings: Dictionary[StringName, Array[InputEvent]] = {}
   ```
   These exact defaults must appear; deviations break ADR §1 line 119 conformance + downstream story-002 R-5 parity test.

4. **Subscribe-to-GameBus DEFERRED to story-007**: Per ADR-0002 §5 + ADR-0005 §1 + Implementation Notes Advisory C, `_ready()` body subscribes to `GameBus.ui_input_block_requested.connect(_on_ui_input_block_requested, Object.CONNECT_DEFERRED)` + `GameBus.ui_input_unblock_requested.connect(_on_ui_input_unblock_requested, Object.CONNECT_DEFERRED)`. Story-001 leaves `_ready()` unimplemented (no `_ready()` override at all yet). Story-007 adds the body.

5. **`_input` / `_unhandled_input` DEFERRED to story-002**: Story-001 ships only the type system. Story-002 wires `_unhandled_input(event)` to dispatch into `_handle_event(event)` once the action vocabulary + InputMap population is in place.

6. **Project.godot autoload load order**: existing `[autoload]` section likely has:
   ```
   GameBus="*res://src/core/game_bus.gd"
   SceneManager="*res://src/foundation/scene_manager.gd"
   SaveManager="*res://src/foundation/save_manager.gd"
   ```
   Append `InputRouter` as the 4th line. Godot loads autoloads top-to-bottom; the order matters because InputRouter consumes `GameBus.ui_input_block_requested` (added in story-007), so InputRouter MUST load AFTER GameBus per ADR-0005 §1 line 117. Reading `project.godot` to verify exact existing format before editing.

7. **InputContext payload split rationale**: ADR-0001 §7 line 168 carried advisory says `signal input_action_fired(action: StringName, ctx: InputContext)` with `InputContext` as a typed Resource ≥2-field payload (per TR-gamebus-001). The 2 MVP fields (`coord` + `unit_id`) cover all 22 actions per GDD AC-1. Future fields (e.g., `gesture_type` for two-finger gesture differentiation, `screen_pos: Vector2` for raw touch coords) are additive; downstream consumers must use `ctx.coord` etc. with default-friendly access (`Vector2i.ZERO` / `-1` are sentinel "not applicable" values). Schema evolution discipline per CR-1d (additive-only).

8. **UndoEntry RefCounted choice**: per ADR-0005 §1 R-2, UndoEntry is RefCounted (NOT Resource). Reason: undo entries are battle-scoped, not save-persistent; RefCounted is lighter; no need for `.tres` file authoring or ResourceSaver round-trip. The Dictionary[int, UndoEntry] holds at most ~16-24 entries (per-unit; max units per battle) × ~80 bytes ≈ ~2 KB heap (per ADR-0005 §1 R-2 memory bound).

9. **Test file**: `tests/unit/foundation/input_router_skeleton_test.gd` — 6-8 structural tests covering AC-1..AC-10. Pattern: use `FileAccess.get_file_as_string("res://src/foundation/input_router.gd")` + `content.contains("var _state: InputState = InputState.OBSERVATION")` for AC-2 / AC-3 / AC-4 source-file structural assertions per turn-order story-001 G-22 precedent. Use `load("res://src/foundation/payloads/input_context.gd").new() as InputContext` for AC-5 instantiation. Use `FileAccess.get_file_as_string("res://project.godot")` + `content.contains("InputRouter=\"*res://src/foundation/input_router.gd\"")` for AC-7 autoload registration assertion. **Test base class**: extend `GdUnitTestSuite` (Node-based) per technical-preferences `Framework configuration` section.

10. **G-14 obligation**: after writing all 4 new `.gd` files with class_name declarations, run `godot --headless --import --path .` BEFORE first test run to refresh `.godot/global_script_class_cache.cfg`. Skipping costs ~2 min on first failed test run. Verified pattern via terrain-effect/story-001 + hp-status/story-001 precedents.

11. **G-17 collision pre-check**: `InputRouter` / `InputContext` / `UndoEntry` / `InputState` (enum) / `InputMode` (enum) — verify none collide with Godot 4.6 built-ins via `ClassDB.class_exists("InputRouter")` etc. Built-in `Input` (singleton) is distinct from `InputRouter`; built-in `InputEvent` etc. distinct from `InputContext`; `UndoEntry` not a built-in. Verified safe pre-implementation.

12. **No production-method bodies in this story**: `set_binding`, `_handle_event` are stubbed with `pass`. Stories 002-009 implement the rest sequentially per Implementation Order in EPIC.md. This story ships the type system + structural compliance + autoload registration only.

13. **Sprint-3 baseline note**: regression baseline currently 743 (post hp-status epic close-out 2026-05-02 commit `6731cc6`). Story-001 adds ~6-8 tests targeting structural compliance; expected new baseline ~749-751.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: 22-action StringName vocabulary + ACTIONS_BY_CATEGORY const + `default_bindings.json` schema + JSON load + InputMap population + R-5 parity validation + `_unhandled_input` → `_handle_event` wiring
- **Story 003-004**: 7-state FSM transition logic (S0↔S1↔S2↔S3↔S4) + transition signal emit + 2-beat confirmation + ST-2 demotion + end-player-turn safety gate
- **Story 005**: Last-device-wins mode determination logic + state preservation + `input_mode_changed` emit + verification evidence #1 + #2
- **Story 006**: Per-unit undo window OPEN/CLOSE logic + EC-5 occupied-tile rejection + Grid Battle stub
- **Story 007**: S5 INPUT_BLOCKED + S6 MENU_OPEN + GameBus signal subscriptions to ADR-0002 SceneManager + nested PackedStringArray stack + `set_input_as_handled()` + ST-2 menu restoration + verification evidence #4
- **Story 008**: Touch protocol part A (TPP + Magnifier + F-1 zoom derivation + Battle HUD/Camera stubs) + verification evidence #3 + #5a
- **Story 009**: Touch protocol part B (pan-vs-tap + two-finger + persistent action panel + safe-area API) + verification evidence #5b + #6
- **Story 010**: Epic terminal — perf baseline + 6+ forbidden_patterns lints + emulate_mouse_from_touch lint + DI test seam validation + 3 TD entries

---

## QA Test Cases

*Authored inline (lean mode QL-STORY-READY skip per `production/review-mode.txt`).*

- **AC-1**: InputRouter declared as `extends Node` at correct path
  - Given: `src/foundation/input_router.gd` exists
  - When: read file content via `FileAccess.get_file_as_string()`
  - Then: content contains `extends Node` (NOT `extends RefCounted`, NOT `extends Resource`)
  - Edge cases: `class_name` line presence depends on G-3 verification (see Implementation Note #1) — assert outcome documented in test comment
- **AC-2**: 6 instance fields with exact types
  - Given: InputRouter source file
  - When: grep for each field declaration
  - Then: all 6 fields present with exact types: `_state: InputState`, `_active_mode: InputMode`, `_pre_menu_state: InputState`, `_undo_windows: Dictionary[int, UndoEntry]`, `_input_blocked_reasons: PackedStringArray`, `_bindings: Dictionary[StringName, Array[InputEvent]]`
  - Edge cases: defaults must match (e.g. `_undo_windows: Dictionary[int, UndoEntry] = {}` not just `Dictionary = {}`)
- **AC-3**: InputState enum with 7 members in canonical S0..S6 order
  - Given: InputRouter source file
  - When: parse enum declaration (regex / content match)
  - Then: enum has exactly 7 members in order OBSERVATION (0), UNIT_SELECTED (1), MOVEMENT_PREVIEW (2), ATTACK_TARGET_SELECT (3), ATTACK_CONFIRM (4), INPUT_BLOCKED (5), MENU_OPEN (6)
  - Edge cases: assert int values via instantiation: `InputRouter.InputState.OBSERVATION == 0` etc.
- **AC-4**: InputMode enum with 2 MVP members
  - Given: InputRouter source file
  - When: parse enum declaration
  - Then: enum has exactly 2 members: KEYBOARD_MOUSE (0), TOUCH (1); int values verified via instantiation
  - Edge cases: future GAMEPAD member at int 2 reserved per ADR-0005 §6 — should NOT be present in MVP scope
- **AC-5**: InputContext Resource with 2 @export fields
  - Given: `src/foundation/payloads/input_context.gd` exists
  - When: instantiate via `var ctx = (load("res://src/foundation/payloads/input_context.gd") as GDScript).new()`
  - Then: instance is non-null; `ctx.coord` returns `Vector2i.ZERO`; `ctx.unit_id` returns `-1` (defaults)
  - Edge cases: cast to `InputContext` succeeds without error
- **AC-6**: UndoEntry RefCounted with 3 fields
  - Given: `src/foundation/payloads/undo_entry.gd` exists
  - When: instantiate
  - Then: instance is non-null; 3 fields default to `unit_id=-1`, `pre_move_coord=Vector2i.ZERO`, `pre_move_facing=0`
  - Edge cases: assert cast to `UndoEntry` succeeds; assert NOT `extends Resource` (must be `extends RefCounted`)
- **AC-7**: project.godot autoload registration
  - Given: `project.godot` exists
  - When: read content
  - Then: content contains `InputRouter="*res://src/foundation/input_router.gd"`; line position is AFTER `GameBus`, `SceneManager`, `SaveManager` lines (load order 4)
  - Edge cases: assert no duplicate `InputRouter` autoload entry; assert leading `*` (Autoload Node) not missing
- **AC-8**: Public method stubs with exact signatures
  - Given: InputRouter source file
  - When: grep for each method signature
  - Then: 4 methods present with exact signatures: `get_active_input_mode() -> InputMode`, `get_state() -> InputState`, `set_binding(action: StringName, event: InputEvent) -> void`, `_handle_event(event: InputEvent) -> void`
  - Edge cases: getter bodies return current field; setter/handler bodies are `pass`
- **AC-9**: No `_ready()` body in this story
  - Given: InputRouter source file
  - When: grep for `func _ready`
  - Then: 0 matches (no `_ready()` override declared yet — story-007 adds it)
  - Edge cases: also assert no `_input` or `_unhandled_input` override declared yet (story-002 adds the latter)
- **AC-10**: G-14 import refresh resolves all class_name declarations
  - Given: 4 new `.gd` files just authored
  - When: run `godot --headless --import --path .`
  - Then: import exits cleanly (no parse errors visible in stderr); Identifier `InputContext` / `UndoEntry` / `InputState` / `InputMode` resolvable in test files (verified by AC-5 + AC-6 instantiation tests passing)
  - Edge cases: if G-3 collision fires for `InputRouter` class_name, document and drop per Implementation Note #1
- **AC-11**: Regression baseline maintained
  - Given: full GdUnit4 suite invoked
  - When: 743 + new tests run
  - Then: ≥749 tests / 0 errors / 0 failures / 0 orphans / Exit 0
  - Edge cases: G-7 silent-skip check — verify `Overall Summary` count actually advanced beyond 743 (not just exit 0 with the new test file silently skipped due to parse error)

---

## Test Evidence

**Story Type**: Logic (borderline-skeleton; scaffolding-heavy with structural assertions)
**Required evidence**: `tests/unit/foundation/input_router_skeleton_test.gd` — must exist + ≥6 tests + must pass
**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: None (story-001 is the epic's first story)
- **Unlocks**: Story 002 (action vocabulary + bindings + InputMap), Story 003 (FSM transitions), Story 005 (mode determination), Story 006 (undo window), Story 007 (S5/S6 + GameBus subscribes), Story 008 (touch part A), Story 009 (touch part B), Story 010 (epic terminal)
