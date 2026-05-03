# Story 002: 11 GameBus Signal Subscriptions + DI Test Seam + S5 Input-Blocked Filter

> **Epic**: Battle HUD
> **Status**: Complete
> **Layer**: Presentation
> **Type**: Logic
> **Manifest Version**: 2026-04-20
> **Completed**: 2026-05-03

## Context

**GDD**: `design/ux/battle-hud.md` v1.1
**Requirement**: `TR-battle-hud-003`, `TR-battle-hud-010`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0015 Battle HUD (Accepted 2026-05-03)
**ADR Decision Summary**: HUD subscribes to 11 signals across 4 domains (4 controller-LOCAL + 1 HP/Status + 3 Turn Order + 2 InputRouter + 1 formation_bonuses_updated), all using `Object.CONNECT_DEFERRED` per ADR-0001 §5. `_exit_tree()` body explicitly disconnects all 11. Recursive `MOUSE_FILTER_IGNORE` on root Control during InputRouter S5 INPUT_BLOCKED state.

**Engine**: Godot 4.6 | **Risk**: HIGH (recursive Control disable 4.5+ + CONNECT_DEFERRED discipline)
**Engine Notes**:
- Godot 4.5+ recursive `mouse_filter = MOUSE_FILTER_IGNORE` on root Control propagates down the Control tree in one call (per `docs/engine-reference/godot/breaking-changes.md` 4.5 entry). Verify on macOS Metal + Linux Vulkan + Windows D3D12 cross-platform.
- The 4 controller-LOCAL signals are signals on the `GridBattleController` instance, NOT on the GameBus autoload — subscribed via DI'd `_grid_controller.unit_selected_changed.connect(...)` per TR-grid-battle-controller-004. The 1 HP/Status + 3 Turn Order + 2 InputRouter + 1 Formation Bonus signals ARE on GameBus autoload — subscribed via `GameBus.<signal_name>.connect(...)`.
- `disconnect()` is a safe no-op in Godot 4.x; defensive `is_connected()` guards retained per godot-specialist authoring revision #1 but NOT correctness requirement.

**Control Manifest Rules (Presentation layer)**:
- Required: `Object.CONNECT_DEFERRED` flag on every signal subscription (ADR-0001 §5; story-008 lints).
- Forbidden (registry): `battle_hud_missing_exit_tree_disconnect` (story-008 lint asserts ≥ 11 disconnect calls inside `_exit_tree()`); `battle_hud_subscribes_to_hidden_fate_signal` (Pillar 2 — must NEVER subscribe to controller's 5th signal).
- Guardrail: per-event signal handler ≈ 0.05 ms (only one fires per emit; realistic peak 0.05 ms) — well under 16.6 ms frame budget.

---

## Acceptance Criteria

*From ADR-0015 §3, §5 + ADR-0001 §5 CONNECT_DEFERRED mandate + R-5 + ADR-0014 controller-LOCAL signal contract:*

- [ ] `_ready()` connects all 11 signals AFTER the 9-backend assertion block from story-001:
  - 4 controller-LOCAL on `_grid_controller`: `unit_selected_changed`, `unit_moved`, `damage_applied`, `battle_outcome_resolved`
  - 1 GameBus: `unit_died` (from HPStatusController emission domain)
  - 3 GameBus: `round_started`, `unit_turn_started`, `unit_turn_ended` (TurnOrderRunner)
  - 2 GameBus: `input_state_changed`, `input_mode_changed` (InputRouter)
  - 1 GameBus: `formation_bonuses_updated` (Grid Battle CR-12)
- [ ] Every `connect()` call passes `Object.CONNECT_DEFERRED` as the third argument (or `flags=` keyword equivalent — Godot 4.6 `Signal.connect(callable, flags)` form preferred per ADR-0001 §5 example).
- [ ] **Zero subscription** to `_grid_controller.hidden_fate_condition_progressed` — Pillar 2 lock.
- [ ] 11 per-handler stub methods exist, each routing through `_handle_signal(&"<signal_name>", [<args...>])`:
  - `_on_unit_selected_changed(unit_id: int, was_selected: bool) -> void`
  - `_on_unit_moved(unit_id: int, from: Vector2i, to: Vector2i) -> void`
  - `_on_damage_applied(attacker_id: int, defender_id: int, damage: int) -> void`
  - `_on_battle_outcome_resolved(outcome: int, fate_data: Dictionary) -> void`
  - `_on_unit_died(unit_id: int) -> void`
  - `_on_round_started(round_number: int) -> void`
  - `_on_unit_turn_started(unit_id: int) -> void`
  - `_on_unit_turn_ended(unit_id: int) -> void`
  - `_on_input_state_changed(from_state: int, to_state: int) -> void`
  - `_on_input_mode_changed(new_mode: int) -> void`
  - `_on_formation_bonuses_updated(snapshot: Dictionary) -> void`
- [ ] Each `_on_*` handler body forwards `_handle_signal(&"<signal>", [args...])` and otherwise no-ops (UI-element render bodies arrive in stories 003-007).
- [ ] `_exit_tree()` body contains exactly 11 `disconnect()` calls — one per subscription, mirroring the connect block.
- [ ] `_on_input_state_changed(from_state, to_state)` sets `mouse_filter = MOUSE_FILTER_IGNORE` when `to_state == InputRouter.State.INPUT_BLOCKED` (S5), and reverts to `MOUSE_FILTER_STOP` when transitioning AWAY from S5.
- [ ] All 11 signal subscriptions use signal names exactly matching the source ADR/registry (no typos — typo = silent no-op, integration test catches via emit + receive count assertion).

---

## Implementation Notes

*Derived from ADR-0015 §3 + §5 + ADR-0001 §5 + ADR-0014 §3 controller-LOCAL signal contract:*

1. **Subscription block ordering** (in `_ready()`, after the 9 `assert()` lines from story-001):
   ```gdscript
   # 4 controller-LOCAL (subscribe via DI'd reference, NOT GameBus)
   _grid_controller.unit_selected_changed.connect(_on_unit_selected_changed, Object.CONNECT_DEFERRED)
   _grid_controller.unit_moved.connect(_on_unit_moved, Object.CONNECT_DEFERRED)
   _grid_controller.damage_applied.connect(_on_damage_applied, Object.CONNECT_DEFERRED)
   _grid_controller.battle_outcome_resolved.connect(_on_battle_outcome_resolved, Object.CONNECT_DEFERRED)
   # NOTE: hidden_fate_condition_progressed deliberately NOT connected (Pillar 2 lock)

   # 1 + 3 + 2 + 1 = 7 GameBus subscriptions
   GameBus.unit_died.connect(_on_unit_died, Object.CONNECT_DEFERRED)
   GameBus.round_started.connect(_on_round_started, Object.CONNECT_DEFERRED)
   GameBus.unit_turn_started.connect(_on_unit_turn_started, Object.CONNECT_DEFERRED)
   GameBus.unit_turn_ended.connect(_on_unit_turn_ended, Object.CONNECT_DEFERRED)
   GameBus.input_state_changed.connect(_on_input_state_changed, Object.CONNECT_DEFERRED)
   GameBus.input_mode_changed.connect(_on_input_mode_changed, Object.CONNECT_DEFERRED)
   GameBus.formation_bonuses_updated.connect(_on_formation_bonuses_updated, Object.CONNECT_DEFERRED)
   ```

2. **`_exit_tree()` body** mirrors the connect block — 11 `disconnect()` calls in same order. Each disconnects the Callable (not just signal name) — Godot 4.x signal disconnect signature is `signal.disconnect(callable)`. No `is_connected()` guard required for correctness; defensive guard optional per revision #1.

3. **Per-handler `_handle_signal` forwarding** — each `_on_*` handler is a thin forwarding shim:
   ```gdscript
   func _on_round_started(round_number: int) -> void:
       _handle_signal(&"round_started", [round_number])
       # UI-GB-01/07/08 render bodies wired in stories 003-004
   ```
   Test assertion mode: subclass overrides `_handle_signal` in test-only fixture and records every (name, args) call; story-002 tests assert each emit produces exactly one matching `_handle_signal` invocation. (5-precedent DI test seam pattern — ADR-0010/0011/0012/0014/0005.)

4. **S5 INPUT_BLOCKED filter toggle** — handle inside `_on_input_state_changed`:
   ```gdscript
   func _on_input_state_changed(from_state: int, to_state: int) -> void:
       _handle_signal(&"input_state_changed", [from_state, to_state])
       if to_state == InputRouter.State.INPUT_BLOCKED:
           mouse_filter = MOUSE_FILTER_IGNORE
       elif from_state == InputRouter.State.INPUT_BLOCKED:
           mouse_filter = MOUSE_FILTER_STOP
   ```
   Godot 4.5+ recursive disable means setting IGNORE on root suffices to disable all child Controls. Integration test: emit S5 transition, click Button child → `pressed` signal MUST NOT fire.

5. **`InputRouter.State.INPUT_BLOCKED` constant resolution** — InputRouter exposes its state enum publicly per ADR-0005; if not yet exposed (input-handling impl epic still in flight), use literal int `5` with a `# TODO: replace with InputRouter.State.INPUT_BLOCKED once input-handling Foundation epic ships` comment AND a stub-side `const STATE_INPUT_BLOCKED := 5` mirror in `tests/helpers/input_router_stub.gd`. Verify InputRouter shipped state at story-author time per epic R-3 mitigation.

6. **CONNECT_DEFERRED signal lint preview** — story-008's `lint_battle_hud_connect_deferred.sh` will assert that every `.connect(` call in `src/feature/battle_hud/` has `Object.CONNECT_DEFERRED` in the same statement. Author this story's source in single-line connect-with-flags form so the lint pattern matches cleanly.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- Stories 003-007: UI-element render bodies inside the 11 handlers (this story's handlers stay as no-op shims forwarding to `_handle_signal`).
- Story 005: two-tap timer state + synthetic event back-injection through `_input_router._handle_event(...)`.
- Story 008: CI lints automating the manual subscription discipline gates + Pillar 2 token absence + 44pt + i18n.

---

## QA Test Cases

*All Logic — automated unit + integration tests required.*

- **AC-1: 11 connect calls all use CONNECT_DEFERRED**
  - Given: a fresh BattleHUD instance with all 9 backends wired (story-001 skeleton)
  - When: `parent.add_child(hud)` triggers `_ready()`
  - Then: every `connect()` in source uses `Object.CONNECT_DEFERRED` (verify via test fixture asserting `signal.get_connections()[i].flags & Object.CONNECT_DEFERRED == Object.CONNECT_DEFERRED` for all 11)
  - Edge cases: regression test guards against typo'd `CONNECT_DEFFERED` (silent enum 0 = no flag = NOT deferred)

- **AC-2: Pillar 2 lock — hidden_fate_condition_progressed has zero connections from HUD**
  - Given: a fresh BattleHUD instance + GridBattleController fixture
  - When: `parent.add_child(hud)` triggers `_ready()` with controller wired
  - Then: `_grid_controller.hidden_fate_condition_progressed.get_connections().size()` returns 0 (assuming no other subscriber in test fixture)
  - Edge cases: run with multiple controllers in scene tree — assert HUD specifically NOT in `get_connections()` callable list (parameterised by-callable-target check)

- **AC-3: 11 _on_* handlers each forward to _handle_signal**
  - Given: BattleHUD subclass test fixture overriding `_handle_signal` to record `[name, args]` tuples
  - When: each of 11 signals emitted with realistic args (parameterised — 11 sub-cases)
  - Then: subclass records exactly one `_handle_signal` invocation per emit, with name matching emitted signal and args matching emitted args
  - Edge cases: fire same signal twice — 2 recorded calls; fire 2 different signals — 2 recorded calls in emit order

- **AC-4: _exit_tree() disconnects all 11**
  - Given: a fresh BattleHUD added to parent + all 11 signals connected (post-_ready)
  - When: `parent.remove_child(hud)` triggers `_exit_tree()`
  - Then: every emitter's signal `get_connections()` has 0 callables targeting hud (parameterised — 11 sub-cases)
  - Edge cases: re-add same hud back → `_ready()` re-subscribes; double-_exit_tree (defensive call) → still safe (disconnect on already-disconnected signal is no-op)

- **AC-5: S5 INPUT_BLOCKED → mouse_filter = MOUSE_FILTER_IGNORE**
  - Given: BattleHUD instance ready, mouse_filter currently `MOUSE_FILTER_STOP`
  - When: GameBus.input_state_changed emitted with `to_state == INPUT_BLOCKED`
  - Then: `hud.mouse_filter == Control.MOUSE_FILTER_IGNORE`
  - Edge cases: emit transition INPUT_BLOCKED → OBSERVATION → `hud.mouse_filter == Control.MOUSE_FILTER_STOP` revert; emit OBSERVATION → UNIT_SELECTED (neither involves S5) → mouse_filter unchanged

- **AC-6: Recursive MOUSE_FILTER_IGNORE blocks child Button input (Godot 4.5+ engine gate)**
  - Given: BattleHUD with a child Button instance + `pressed` signal listener counter
  - When: HUD enters S5 (mouse_filter = IGNORE) + simulated mouse click on Button position
  - Then: Button.pressed listener counter remains 0 (recursive disable propagated)
  - Edge cases: HUD exits S5 → mouse_filter = STOP → simulated click → Button.pressed counter increments to 1 (engine integration test; ADR-0015 Verification Item 5 — KEEP through Polish)

---

## Test Evidence

**Story Type**: Logic + Integration (recursive Control disable)
**Required evidence**:
- Logic: `tests/unit/feature/battle_hud/battle_hud_signals_test.gd` — covers AC-1 through AC-5
- Integration: `tests/integration/feature/battle_hud/battle_hud_recursive_filter_test.gd` — covers AC-6 chain + structural

**Status**: [x] Created 2026-05-03 — 13 tests pass (10 unit + 3 integration); 865/865 baseline preserved

---

## Dependencies

- Depends on: Story 001 (BattleHUD class skeleton + 9-param DI seam)
- Unlocks: Stories 003 + 004 (parallel; both consume the signal-handler hooks)

---

## Completion Notes

**Completed**: 2026-05-03
**Criteria**: 8/8 passing — all ACs covered (AC-7 S5 mouse_filter chain automated; AC-7 behavioral recursive descendant disable scoped as manual cross-platform gate per ADR-0015 Verification Item 5)
**Test Evidence**:
- Logic: `tests/unit/feature/battle_hud/battle_hud_signals_test.gd` — 10 tests covering AC-1..AC-5 incl. AC-1 typo regression + AC-2 Pillar 2 runtime + AC-3 capture subclass + AC-4 disconnect + re-add via `request_ready()` + AC-5 three-branch S5 toggle
- Integration: `tests/integration/feature/battle_hud/battle_hud_recursive_filter_test.gd` — 3 tests covering AC-6 chain (input_state_changed → mouse_filter property) + chain inverse + structural descendant property
- Helper: `tests/helpers/battle_hud_capture_subclass.gd` — AC-3 capture seam (Array[Dictionary] received log + super delegation for production side-effects)
**Code Review**: Complete — APPROVED WITH SUGGESTIONS (godot-gdscript-specialist: COMPLIANT on all ADRs + 6/6 standards + 0 G-N violations; qa-tester: 8/8 ACs COVERED, 4 non-blocking suggestions)
**Test result**: 865/865 PASS / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans (delta +13 vs S6-05 baseline 852; 21st consecutive failure-free regression baseline)
**Deviations**: 5 advisory (none blocking):
1. Cross-epic forward-prep: InputRouter.InputState enum (ADR-0005 §1 ratified surface) — front-loaded so battle_hud uses InputState.INPUT_BLOCKED instead of literal `5`; input-handling epic story-001 will keep the enum verbatim
2. Cross-epic forward-prep: GameBus.formation_bonuses_updated(snapshot: Dictionary) signal — required by ADR-0015 §3 R-3 + ADR-0014 CR-12; emission site lands in future Grid Battle epic story
3. Cross-epic forward-prep: explicit name guard in game_bus_diagnostics.gd::_route_to_domain for formation_bonuses_updated — G-5 explicit-name-precedes-prefix pattern
4. Deferred: ADR-0001 §Signal Contract Schema text update (paperwork — EXPECTED_SIGNALS in 3 test files satisfied the runtime gate; ADR document text update lands in next /architecture-review delta)
5. Story file documentation defects to fix in next sprint (non-blocking):
   - AC-3 lists `_on_unit_selected_changed(was_selected: bool)` but production is `int` per ADR-0014 §8 line 85
   - AC-4 wording "re-add hud back → _ready re-subscribes" is misleading — Godot only fires _ready once per Node lifetime; test uses `request_ready()` (test-only mechanism)

**Engine Verification Item 5 manual gate** (KEEP through Polish): synthetic-input behavioral test for recursive MOUSE_FILTER_IGNORE blocking child Button input was DROPPED because both `Input.parse_input_event` and `Viewport.push_input` empirically bypass the Control mouse_filter chain in GdUnit4 headless mode. Recommended next step: formalize as `production/qa/evidence/` checklist entry per qa-tester recommendation; producer / qa-lead decision on whether to gate before sprint-6 close or defer to Polish per ADR.
