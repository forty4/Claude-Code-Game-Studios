# Story 002: 22-action StringName vocabulary + ACTIONS_BY_CATEGORY const + default_bindings.json schema + JSON load + InputMap population + R-5 parity validation

> **Epic**: Input Handling
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 3-4h
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/input-handling.md`
**Requirement**: `TR-input-handling-003`, `TR-input-handling-004`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0005 — Input Handling — InputRouter Autoload + 7-State FSM (MVP scope)
**ADR Decision Summary**: TR-003 = 22 StringName actions in 4 categories (10 grid + 4 camera + 5 menu + 3 meta) declared in `ACTIONS_BY_CATEGORY: Dictionary[StringName, Array[StringName]]` const Dictionary; ACTIONS_BY_CATEGORY const is the runtime source-of-truth for action existence; default_bindings.json is the source-of-truth for InputEvent → action mapping; both must be in parity at `_ready()` validation (R-5 mitigation: FATAL `push_error` + early-return on mismatch). TR-004 = bindings externalized to `assets/data/input/default_bindings.json` (forbidden_pattern `hardcoded_input_bindings` enforced via story-010 lint); load via `FileAccess.get_file_as_string()` + `JSON.new().parse()` (mirrors ADR-0006/0007/0008/0009 4-precedent); InputMap population via `InputMap.add_action(action: StringName)` + `InputMap.action_add_event(action: StringName, event: InputEvent)` per delta #6 Item 8 correction (NOT `Input.parse_input_event()` — that method is event INJECTION not InputMap population).

**Engine**: Godot 4.6 | **Risk**: HIGH (governed by ADR-0005)
**Engine Notes**: `InputMap.add_action()` + `InputMap.action_add_event()` (4.0+ stable); `FileAccess.get_file_as_string()` (Godot 4.4 return-type changed from `String?` → `String` per `breaking-changes.md`; verified usage pattern matches ADR-0006/0007 precedent). `JSON.new().parse()` returns `Error` enum, parsed dict in `JSON.data` (4.0+ stable). `InputEvent` matches by `keycode` / `button_index` fields, NOT by `pressed` state per delta #6 Item 3 verification (newly-constructed InputEvent instances have `pressed=false` default but does not break action matching) — verified against live 4.6 InputMap source on first story implementation. CR-1c PC-only `grid_hover` action: matches `InputEventMouseMotion` (no `pressed` field; always TOUCH-equivalent unreachable per CR-1c).

**Control Manifest Rules (Foundation layer + Global)**:
- Required: bindings live in `assets/data/input/default_bindings.json` only (forbidden_pattern `hardcoded_input_bindings` per CR-1b — story-010 lint enforces); JSON load via 4-precedent pattern (FileAccess + JSON.new().parse); InputMap population via `InputMap.add_action` + `InputMap.action_add_event`; ACTIONS_BY_CATEGORY const Dictionary[StringName, Array[StringName]] (typed)
- Forbidden: `Input.parse_input_event()` for InputMap population (that's for event injection per delta #6 Item 8); raw `String` keys in ACTIONS_BY_CATEGORY (StringName mandatory per ADR-0001 §7 line 168 + delta #6 Item 10a); per-frame InputMap mutation (mutation only via `set_binding(action, event)` post-`_ready()` per CR-1b)
- Guardrail: ACTIONS_BY_CATEGORY exactly 22 actions across 4 categories; default_bindings.json exactly 22 keys (excluding `grid_hover` which is PC-only); R-5 parity validation FATAL `push_error` on any mismatch (missing key, extra key, category miscount)

---

## Acceptance Criteria

*From GDD §Acceptance Criteria AC-1 + AC-2 + ADR-0005 §4 + CR-1, CR-1a, CR-1b, CR-1c:*

- [ ] **AC-1** ACTIONS_BY_CATEGORY const Dictionary declared on InputRouter (or extracted to a const-only `src/foundation/input_actions.gd` if GDScript const-on-Node is restricted) with exactly 22 StringName actions across 4 categories: **grid (10)** = `&"unit_select"`, `&"move_target_select"`, `&"move_confirm"`, `&"move_cancel"`, `&"attack_target_select"`, `&"attack_confirm"`, `&"attack_cancel"`, `&"undo_last_move"`, `&"end_unit_turn"`, `&"grid_hover"` (PC-only per CR-1c); **camera (4)** = `&"camera_pan"`, `&"camera_zoom_in"`, `&"camera_zoom_out"`, `&"camera_snap_to_unit"`; **menu (5)** = `&"open_unit_info"`, `&"open_game_menu"`, `&"close_menu"`, `&"end_player_turn"`, `&"end_phase_confirm"`; **meta (3)** = `&"action_confirm"`, `&"action_cancel"`, `&"toggle_input_hints"`
- [ ] **AC-2** `assets/data/input/default_bindings.json` exists with JSON schema: top-level Dictionary keyed by action StringName; values are `Array[Dictionary]` where each Dictionary describes an InputEvent (`{"type": "key", "keycode": KEY_ENTER}` for keyboard, `{"type": "mouse_button", "button_index": MOUSE_BUTTON_LEFT}` for mouse, `{"type": "screen_touch"}` for touch). All 21 non-PC-only actions present (excluding `grid_hover` which is `_unhandled_input(InputEventMouseMotion)` direct-handle, not InputMap-routed)
- [ ] **AC-3** InputRouter `_ready()` body loads `default_bindings.json` via `FileAccess.get_file_as_string("res://assets/data/input/default_bindings.json")` + `JSON.new().parse(content)` per ADR-0006/0007/0008/0009 4-precedent pattern; FATAL `push_error` + early-return if file missing or parse fails (R-3 + R-5 mitigation)
- [ ] **AC-4** InputRouter `_ready()` populates Godot's InputMap via `InputMap.add_action(action: StringName)` + `InputMap.action_add_event(action: StringName, event: InputEvent)` for each (action, event-list) pair from the parsed JSON. InputEvent constructed via `InputEventKey.new()` + `event.keycode = KEY_ENTER` etc. (NOT `Input.parse_input_event()` per delta #6 Item 8)
- [ ] **AC-5** R-5 parity validation in `_ready()` AFTER bindings load: assert `ACTIONS_BY_CATEGORY.values().reduce(func(acc, arr): return acc + arr.size(), 0) - 1 == default_bindings.json.size()` (the `-1` excludes `grid_hover` which is PC-only). On mismatch: FATAL `push_error("InputRouter R-5 parity FAIL: ACTIONS_BY_CATEGORY has N total - 1 PC-only = X; default_bindings.json has Y; mismatch indicates schema drift")` + early-return without populating InputMap
- [ ] **AC-6** AC-1 GDD test: GIVEN keyboard maps `KEY_ENTER` to `action_confirm` per default_bindings.json, WHEN player presses Enter, THEN `_handle_event` is invoked with `InputEventKey.keycode == KEY_ENTER`; verified via DI test seam direct call to `_handle_event(InputEventKey.new())` after setting keycode + bypassing real input pipeline. Each of the 22 actions has at least 1 binding entry in default_bindings.json (excluding `grid_hover`)
- [ ] **AC-7** AC-2 GDD test: GIVEN `default_bindings.json` maps `action_confirm` to `KEY_ENTER`, WHEN test edits the file in-place to map `action_confirm` to `KEY_SPACE` and re-instantiates InputRouter, THEN `InputMap.action_get_events("action_confirm")` returns the new SPACE event (NOT ENTER); verified via test that uses a temporary fixture file in `tests/fixtures/input/`
- [ ] **AC-8** `_unhandled_input(event: InputEvent) -> void` override added on InputRouter, body delegates to `_handle_event(event)`. Per ADR-0005 §1 + delta #6 Implementation Note Advisory C, `_unhandled_input` (NOT `_input`) is used so Controls have first-pass via `_gui_input` (dual-focus 4.6 architecture preserves Control focus layer above InputRouter)
- [ ] **AC-9** `_handle_event(event: InputEvent)` body: iterate ACTIONS_BY_CATEGORY values; for each action, call `InputMap.action_has_event(action, event)`; on first match, store action + construct InputContext + return (do NOT actually call `_handle_action(action, ctx)` yet — that's story-003). For now: store action match in a test-observable field `_last_matched_action: StringName` for AC-6 verification
- [ ] **AC-10** Regression baseline maintained: full GdUnit4 suite passes ≥749 cases (story-001 baseline) + new tests / 0 errors / 0 failures / 0 orphans / Exit 0; new test file `tests/unit/foundation/input_router_actions_bindings_test.gd` adds ≥10 tests covering AC-1..AC-9
- [ ] **AC-11** `tests/fixtures/input/test_bindings_minimal.json` authored — 3-action minimal fixture for AC-7 dynamic-rebinding test; production `default_bindings.json` is NOT modified during tests (G-15 isolation discipline)

---

## Implementation Notes

*Derived from ADR-0005 §4 + CR-1, CR-1a, CR-1b, CR-1c + delta #6 Items 3, 8, 10a:*

1. **ACTIONS_BY_CATEGORY const declaration** (verbatim per ADR-0005 §4 + GDD §Action System):
   ```gdscript
   const ACTIONS_BY_CATEGORY: Dictionary[StringName, Array[StringName]] = {
       &"grid": [&"unit_select", &"move_target_select", &"move_confirm", &"move_cancel",
                 &"attack_target_select", &"attack_confirm", &"attack_cancel",
                 &"undo_last_move", &"end_unit_turn", &"grid_hover"],
       &"camera": [&"camera_pan", &"camera_zoom_in", &"camera_zoom_out", &"camera_snap_to_unit"],
       &"menu": [&"open_unit_info", &"open_game_menu", &"close_menu",
                 &"end_player_turn", &"end_phase_confirm"],
       &"meta": [&"action_confirm", &"action_cancel", &"toggle_input_hints"],
   }
   ```
   If GDScript const-on-Node restriction surfaces (untested), extract to `src/foundation/input_actions.gd` with `class_name InputActions` + `static var ACTIONS_BY_CATEGORY: Dictionary[StringName, Array[StringName]] = {...}`.

2. **default_bindings.json schema** (target file `assets/data/input/default_bindings.json`):
   ```json
   {
       "_schema_version": "1.0.0",
       "_authority": "ADR-0005 §4 + GDD §Action System; story-002 same-patch obligation",
       "unit_select": [
           {"type": "mouse_button", "button_index": 1},
           {"type": "screen_touch"}
       ],
       "move_target_select": [
           {"type": "mouse_button", "button_index": 1},
           {"type": "screen_touch"}
       ],
       "move_confirm": [
           {"type": "key", "keycode": 4194309}
       ],
       "action_confirm": [
           {"type": "key", "keycode": 4194309}
       ],
       "action_cancel": [
           {"type": "key", "keycode": 4194305}
       ],
       "camera_pan": [
           {"type": "screen_drag"}
       ],
       "camera_zoom_in": [
           {"type": "key", "keycode": 61}
       ],
       "camera_zoom_out": [
           {"type": "key", "keycode": 45}
       ]
       /* ... remaining 13 actions excluding grid_hover */
   }
   ```
   Note: keycode integer values are Godot 4.6 `KeyboardKeyCode` enum ints (`KEY_ENTER=4194309`, `KEY_ESCAPE=4194305`, `KEY_EQUAL=61`, `KEY_MINUS=45`). Use `OS.find_keycode_from_string("Enter")` at file authoring time to verify; reference table in GDScript docs `@GlobalScope.html#enum-keycode`. Resolved values DO NOT change across Godot versions (stable API).

3. **JSON loader pattern** (`_ready()` body):
   ```gdscript
   func _ready() -> void:
       var content := FileAccess.get_file_as_string("res://assets/data/input/default_bindings.json")
       if content.is_empty():
           push_error("InputRouter: default_bindings.json missing or empty")
           return
       var json := JSON.new()
       var parse_result := json.parse(content)
       if parse_result != OK:
           push_error("InputRouter: default_bindings.json parse error: %s" % json.get_error_message())
           return
       var bindings_dict := json.data as Dictionary
       _populate_input_map(bindings_dict)
       _validate_r5_parity(bindings_dict)
   ```
   Mirrors `BalanceConstants.gd` ADR-0006 5-precedent pattern + `HeroDatabase.gd` ADR-0007 6-precedent pattern.

4. **InputMap population helper** (`_populate_input_map(bindings_dict: Dictionary) -> void`):
   ```gdscript
   func _populate_input_map(bindings: Dictionary) -> void:
       for action_str: String in bindings.keys():
           if action_str.begins_with("_"):  # skip _schema_version, _authority meta keys
               continue
           var action: StringName = StringName(action_str)
           if not InputMap.has_action(action):
               InputMap.add_action(action)
           for event_dict: Dictionary in bindings[action_str] as Array:
               var event: InputEvent = _construct_input_event(event_dict)
               if event != null:
                   InputMap.action_add_event(action, event)
                   _bindings.get_or_add(action, []).append(event)
   ```
   `_construct_input_event` switches on `event_dict["type"]` and constructs `InputEventKey.new()` / `InputEventMouseButton.new()` / `InputEventScreenTouch.new()` / `InputEventScreenDrag.new()` setting keycode/button_index per the dict.

5. **R-5 parity validator** (`_validate_r5_parity(bindings_dict: Dictionary) -> void`):
   ```gdscript
   func _validate_r5_parity(bindings: Dictionary) -> void:
       var meta_keys: int = 0
       for key: String in bindings.keys():
           if key.begins_with("_"):
               meta_keys += 1
       var bound_count: int = bindings.size() - meta_keys
       var declared_count: int = 0
       for category: StringName in ACTIONS_BY_CATEGORY.keys():
           declared_count += ACTIONS_BY_CATEGORY[category].size()
       var pc_only: int = 1  # grid_hover (CR-1c)
       var expected_bound: int = declared_count - pc_only
       if bound_count != expected_bound:
           push_error("InputRouter R-5 parity FAIL: ACTIONS_BY_CATEGORY has %d - %d PC-only = %d; default_bindings.json has %d; schema drift detected" % [declared_count, pc_only, expected_bound, bound_count])
   ```
   Per CR-1c: `grid_hover` is PC-only and unreachable on touch; equivalent reachable via Tap Preview Protocol. NOT included in default_bindings.json count.

6. **`_unhandled_input` wiring**:
   ```gdscript
   func _unhandled_input(event: InputEvent) -> void:
       _handle_event(event)
   ```
   Use `_unhandled_input` NOT `_input` per ADR-0005 Implementation Note Advisory C — Controls get first dispatch via `_gui_input`; InputRouter handles only events that propagated past all Controls. This preserves the dual-focus 4.6 architecture (Control focus layer above InputRouter; per godot-specialist Item 1 PASS).

7. **`_handle_event` body — story-002 scope** (story-003 extends to dispatch):
   ```gdscript
   var _last_matched_action: StringName = &""  # test-observable; will be replaced by full dispatch in story-003

   func _handle_event(event: InputEvent) -> void:
       for category: StringName in ACTIONS_BY_CATEGORY.keys():
           for action: StringName in ACTIONS_BY_CATEGORY[category]:
               if InputMap.action_has_event(action, event):
                   _last_matched_action = action
                   return  # match-and-store; story-003 replaces with _handle_action(action, ctx)
       _last_matched_action = &""  # no match
   ```

8. **Test fixture authoring**: create `tests/fixtures/input/test_bindings_minimal.json` with 3 actions (`action_confirm` mapped to KEY_SPACE; `unit_select` mapped to MOUSE_BUTTON_LEFT; `move_confirm` mapped to KEY_ENTER) for AC-7 dynamic-rebinding test isolation per G-15 obligation. Production `default_bindings.json` MUST NOT be modified during tests; use `_load_bindings_from_path(path)` test seam instead of relying on `_ready()` reading the production path.

9. **DI test seam for bindings load**: extract `_populate_input_map(bindings_dict: Dictionary)` + `_validate_r5_parity(bindings_dict: Dictionary)` as separate helpers callable from tests. `_ready()` body becomes a thin orchestrator: `_load_bindings()` → `_populate_input_map()` → `_validate_r5_parity()`. Tests call `_populate_input_map(custom_dict)` directly bypassing the file-load step. Mirrors damage-calc story-006 RNG-injection pattern.

10. **G-15 reset obligation in `before_test()`**: per ADR-0005 §8 + delta #6 Item 7, every input_router_*_test.gd `before_test()` MUST include `_bindings.clear()` + clear all 6 fields:
    ```gdscript
    func before_test() -> void:
        # G-15 reset — full 6-field clear including _bindings (delta #6 Item 7)
        InputRouter._state = InputRouter.InputState.OBSERVATION
        InputRouter._active_mode = InputRouter.InputMode.KEYBOARD_MOUSE
        InputRouter._pre_menu_state = InputRouter.InputState.OBSERVATION
        InputRouter._undo_windows.clear()
        InputRouter._input_blocked_reasons.clear()
        InputRouter._bindings.clear()
        # Repopulate from test fixture (NOT production default_bindings.json)
        var content := FileAccess.get_file_as_string("res://tests/fixtures/input/test_bindings_minimal.json")
        var json := JSON.new()
        json.parse(content)
        InputRouter._populate_input_map(json.data)
    ```
    Story-010 lint script enforces presence of `_bindings.clear()` in every input_router_*_test.gd before_test().

11. **Test file**: `tests/unit/foundation/input_router_actions_bindings_test.gd` — 10-12 tests covering AC-1..AC-9. Pattern: structural source-file assertions for ACTIONS_BY_CATEGORY (AC-1); JSON parse + key-count assertions (AC-2); programmatic `_populate_input_map` invocation + `InputMap.action_has_event` assertions (AC-4); R-5 parity FAIL injection (extra key in fixture → FATAL push_error captured via `assert_error` matcher per G-22 Path 3 — though G-22 notes Path 3 may not work for this specific case; if so, fall back to negative assertion via `_last_matched_action == &""` after parity-failed init).

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 003-004**: 7-state FSM transition logic + `_handle_action(action, ctx)` dispatch (story-002 only stores `_last_matched_action` for test verification)
- **Story 005**: Mode determination (KEYBOARD_MOUSE vs TOUCH detection in `_handle_event`)
- **Story 006**: Per-unit undo window
- **Story 007**: GameBus signal subscriptions
- **Story 008-009**: Touch protocol (TPP / Magnifier / pan-vs-tap / gestures / persistent panel)
- **Story 010**: Epic terminal — `lint_emulate_mouse_from_touch.sh` + `hardcoded_input_bindings` lint + `_bindings.clear()` lint

---

## QA Test Cases

*Authored inline (lean mode QL-STORY-READY skip).*

- **AC-1**: ACTIONS_BY_CATEGORY 22-action structure
  - Given: InputRouter source file
  - When: read content + assert ACTIONS_BY_CATEGORY const exists with `Dictionary[StringName, Array[StringName]]` type
  - Then: 4 categories present (`grid` / `camera` / `menu` / `meta`); category counts 10 / 4 / 5 / 3; total 22 actions; spot-check 5 specific StringName values present
  - Edge cases: assert no duplicate action across categories (`unit_select` appears in `grid` only); assert `grid_hover` present in `grid` (CR-1c PC-only)
- **AC-2**: default_bindings.json schema validation
  - Given: `assets/data/input/default_bindings.json` exists
  - When: JSON parse succeeds + dict has 21 non-meta keys
  - Then: each non-meta key matches one of the 21 actions (22 - grid_hover); each value is `Array[Dictionary]`; each Dictionary has valid `type` field (key/mouse_button/screen_touch/screen_drag)
  - Edge cases: assert `_schema_version` + `_authority` meta keys present; reject if any `grid_hover` binding accidentally added
- **AC-3**: JSON load + FATAL push_error on missing file
  - Given: temporarily-renamed `default_bindings.json` (or DI-injected nonexistent path)
  - When: InputRouter `_ready()` runs
  - Then: FATAL `push_error` fires; InputMap not populated
  - Edge cases: also test invalid JSON (truncated) → push_error fires; valid JSON with wrong shape (top-level Array instead of Dictionary) → push_error fires
- **AC-4**: InputMap population correctness
  - Given: minimal fixture loaded via `_populate_input_map(test_dict)`
  - When: `InputMap.action_has_event("action_confirm", InputEventKey.new() with keycode=KEY_SPACE)` queried
  - Then: returns `true` (KEY_SPACE registered as bound to action_confirm in fixture)
  - Edge cases: assert NOT `Input.parse_input_event` used (grep test source — must not match `Input.parse_input_event`); assert `InputMap.add_action` called for each unique action
- **AC-5**: R-5 parity validation FATAL on mismatch
  - Given: malformed fixture with 22 keys instead of 21 (extra `grid_hover` binding accidentally added)
  - When: `_validate_r5_parity(malformed_dict)` invoked
  - Then: FATAL `push_error` with format string mentioning "schema drift detected"
  - Edge cases: also test 20 keys (one missing) → FATAL fires; valid 21 keys → no error
- **AC-6**: `_handle_event` matches enter to action_confirm
  - Given: production bindings loaded (action_confirm → KEY_ENTER per AC-2 fixture)
  - When: construct `InputEventKey.new()` with keycode = KEY_ENTER + invoke `_handle_event(event)`
  - Then: `_last_matched_action == &"action_confirm"`
  - Edge cases: invoke with KEY_F12 (unbound) → `_last_matched_action == &""`; invoke with `InputEventScreenTouch` → `_last_matched_action == &"unit_select"` (touch fallback)
- **AC-7**: Dynamic rebinding via fixture file
  - Given: load fixture mapping `action_confirm` to KEY_SPACE
  - When: `_populate_input_map(fixture_dict)` invoked
  - Then: `InputMap.action_get_events("action_confirm")` returns Array containing event with keycode == KEY_SPACE; old KEY_ENTER binding NOT present (assumes test cleared InputMap first via `_bindings.clear()` + `InputMap.erase_action`)
  - Edge cases: ensure prior production binding does not leak — explicitly call `InputMap.erase_action("action_confirm")` in before_test() per G-15
- **AC-8**: `_unhandled_input` override delegates to `_handle_event`
  - Given: InputRouter source file
  - When: grep for `func _unhandled_input(event: InputEvent) -> void:`
  - Then: 1 match; body calls `_handle_event(event)` (single-line delegation per Implementation Note 6)
  - Edge cases: assert NO `_input(event)` override (per Advisory C — Controls own first dispatch via _gui_input; only _unhandled_input on InputRouter)
- **AC-9**: `_handle_event` matching loop iterates 4 categories
  - Given: InputRouter source file
  - When: grep for `for category: StringName in ACTIONS_BY_CATEGORY.keys()` in `_handle_event` body
  - Then: 1 match present; nested `for action: StringName in ACTIONS_BY_CATEGORY[category]` also present
  - Edge cases: assert `InputMap.action_has_event` is called inside the inner loop; assert early-return (`return`) on first match
- **AC-10**: Regression baseline
  - Given: full GdUnit4 suite invoked
  - When: 749 + new tests run
  - Then: ≥759 tests / 0 errors / 0 failures / 0 orphans / Exit 0
- **AC-11**: Test fixture isolation
  - Given: `tests/fixtures/input/test_bindings_minimal.json` exists with 3 actions
  - When: AC-7 test runs against this fixture
  - Then: production `default_bindings.json` content unchanged (assert pre-test md5 == post-test md5)
  - Edge cases: assert no other test file references the production path during write operations

---

## Test Evidence

**Story Type**: Logic (R-5 parity validator + InputMap population are pure logic)
**Required evidence**: `tests/unit/foundation/input_router_actions_bindings_test.gd` — must exist + ≥10 tests + must pass; `tests/fixtures/input/test_bindings_minimal.json` exists with valid 3-action schema
**Status**: [ ] Not yet created

---

## Dependencies

- **Depends on**: Story 001 (module skeleton must exist; ACTIONS_BY_CATEGORY + 6 fields + InputContext + UndoEntry; autoload registration)
- **Unlocks**: Story 003 (FSM core — needs `_handle_event` matching loop + `_handle_action` dispatch wiring), Story 005 (mode determination — extends `_handle_event` for event-class detection), Story 008 (touch protocol — depends on InputMap binding for `screen_touch` events)
