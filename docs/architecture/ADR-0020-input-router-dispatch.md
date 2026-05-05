# ADR-0020: InputRouter `_handle_event` Dispatch Contract + Cross-System Integration Narrowing (post-ADR-0014/0015 Acceptance)

## Status

Proposed (2026-05-05 — sprint-8 S8-01; awaits combined-session escalation pattern 5th invocation via fresh-session `/architecture-review` delta #15 same-day per same-session-ban discipline. Pattern stable at 4 prior invocations: deltas #11 (ADR-0014/0017) + #12 (ADR-0017 widening) + #13 (ADR-0018) + #14 (ADR-0019). Authored fresh-session per `/architecture-decision input-router-dispatch` invocation post-sprint-7 retrospective + sprint-8 plan ratification.)

## Date

2026-05-05

## Last Verified

2026-05-05 against `docs/engine-reference/godot/VERSION.md` (Godot 4.6, pinned 2026-04-16).

## Decision Makers

Solo dev — autonomous authoring per gate-check 2026-05-05 + sprint-8 S8-01 directive. ADR narrows ADR-0005 §9 provisional integration contracts now that ADR-0014 (Grid Battle Controller) + ADR-0015 (Battle HUD) are Accepted (2026-05-03), and locks the `_handle_event(event: InputEvent) -> void` inner-loop dispatch sequence that ADR-0005 §8 referenced only as "DI test seam" without specifying the dispatch ordering.

## Summary

Define **`InputRouter._handle_event(event: InputEvent) -> void`** as the **canonical dispatch entry** with locked inner-loop sequence (4 sequential phases: mode-determine → action-resolve via `InputMap` → state-transition via inline `match` dispatch → signal-emit pair `input_state_changed` + `input_action_fired`). This ADR lifts `_handle_event` from "test-only seam" framing in ADR-0005 §8 to the **public contract surface that 3 caller classes depend on**: (1) Godot engine via `_unhandled_input(event)` indirection (production input pipeline); (2) `BattleHUD.gd:19` (undo dispatch per ADR-0015 §5 — explicit DI'd-backend method call exception); (3) GdUnit4 v6.1.2 tests via direct synthetic-event injection per `before_test()` 6-field reset discipline (G-15 mirror obligation). **Touch-mouse separation** is structural (per CR-1a hover-only ban + CR-2b last-device-wins) — `_determine_mode_from_event(event) -> InputMode` queries event class identity ONLY (no `_active_mode` consultation, no temporal smoothing). **8 forbidden_patterns** codified (4 carried from ADR-0005 + 4 net-new). **3 integration ratifications** narrow ADR-0005 §9 SOFT/PROVISIONAL contracts: (a) ADR-0014 GridBattleController as range-validation source per CR-EC-7; (b) ADR-0015 BattleHUD as `input_state_changed`/`input_mode_changed` consumer + TPP `show_unit_info`/`show_tile_info` callee + undo `_handle_event` caller (sole production exception to `_`-prefix discipline); (c) Camera + Settings/Options + Tutorial remain SOFT/PROVISIONAL pending their own ADRs. **NO new module form decisions** — ADR-0005 §1 Autoload Node form + 6 mutable fields + 7-state FSM + 22-action vocab + InputMode enum REMAIN authoritative (this ADR does NOT supersede ADR-0005). **NO source code shipped** — this ADR sets the architectural bound; sprint-8 stories S8-02..06 (input-handling story-001..005) implement.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Foundation — Input dispatch + cross-system integration narrowing |
| **Knowledge Risk** | LOW (this ADR introduces no new post-cutoff API usage; ADR-0005 already absorbed the HIGH risk for the InputRouter surface as a whole — dual-focus + SDL3 + Android edge-to-edge are governed there). The 4 net-new forbidden_patterns introduced here are pure source-grep static checks. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/modules/input.md`, `docs/engine-reference/godot/modules/ui.md`, `design/gdd/input-handling.md` (CR-1..CR-5 + ST-1..ST-4 + AC-1..AC-18 + F-1..F-3), `design/gdd/grid-battle.md` (CR-3/3a + provisional consumer of grid actions G-1..G-10), `design/ux/battle-hud.md` (UI-GB-N consumer surfaces), `docs/architecture/ADR-0001-gamebus-autoload.md` (3 Input-domain signals registered: `input_action_fired` / `input_state_changed` / `input_mode_changed`), `docs/architecture/ADR-0002-scene-manager.md` (`ui_input_block/unblock_requested` consumer + recursive disable), `docs/architecture/ADR-0005-input-handling.md` (form-level — Autoload Node + 6 fields + 7-state FSM + 22-action vocab + InputMode + 4 base forbidden_patterns + 17 TR-input-handling-001..017), `docs/architecture/ADR-0014-grid-battle-controller.md` (Accepted 2026-05-03 — battle-scoped Node + `is_tile_in_move_range` / `is_tile_in_attack_range` provisional → ratified here), `docs/architecture/ADR-0015-battle-hud.md` (Accepted 2026-05-03 — battle-scoped Node + DI'd `_input_router: InputRouter` + 2 GameBus subscriptions on `input_state_changed` / `input_mode_changed` + TPP `show_unit_info` / `show_tile_info` + undo dispatch via `_handle_event` exception), `docs/architecture/ADR-0019-ai-system.md` (Accepted 2026-05-05 — most recent ADR precedent for combined-session escalation pattern + `_`-prefix discipline). |
| **Post-Cutoff APIs Used** | NONE in this ADR's incremental decision surface. The dispatch-loop sequence uses pre-4.4 stable APIs only: `InputEvent` subclass `is`-narrowing (4.0+), `match` dispatch on `StringName` (1.0+), typed `signal` declarations (4.2+), `Object.CONNECT_DEFERRED` (4.0+). The 6 mandatory verification items in ADR-0005 (dual-focus + SDL3 + emulate_mouse_from_touch + recursive disable + screen_get_size + safe-area + touch event index) are inherited unchanged. |
| **Verification Required** | (1) `_handle_event` is the **sole state-mutating method** for `_state` / `_active_mode` / `_undo_windows` / `_pre_menu_state` / `_input_blocked_reasons` (4 of 6 instance fields per ADR-0005 §1 line 119; `_bindings` mutates via `set_binding` per CR-1b runtime remap). Lint: `tools/ci/lint_input_router_state_mutation_outside_handle_event.sh` greps for `_state\s*=`/`_active_mode\s*=`/`_undo_windows\[`/`_pre_menu_state\s*=`/`_input_blocked_reasons\.(append|remove)` outside the `_handle_event` function body in `src/foundation/input_router.gd`; returns 0. (2) `BattleHUD.gd` is the **sole production caller** of `InputRouter._handle_event` outside the engine `_unhandled_input` indirection — verified via `grep -rn 'input_router\._handle_event\|InputRouter\..*_handle_event' src/` returning matches ONLY in `src/feature/battle_hud/battle_hud.gd` + the InputRouter file itself. Lint: `tools/ci/lint_input_router_handle_event_caller_allowlist.sh`. (3) 22-action vocabulary parity test (R-5 from ADR-0005 §1 line 233) — `default_bindings.json` keys MUST exactly equal `ACTIONS_BY_CATEGORY` flat-set. Verified at story-002 (S8-03). (4) `input_state_changed` + `input_action_fired` emit pair fires in sequence (state-changed FIRST, action-fired SECOND) for every state transition — order matters because BattleHUD's S5 INPUT_BLOCKED `MOUSE_FILTER_IGNORE` recursive disable must apply BEFORE any subsequent action signal lands. Verified at story-003 (S8-04) integration test. (5) Touch + Mouse separation: `_determine_mode_from_event` queries event class identity only (no `_active_mode` read); same input event class always returns same `InputMode` regardless of prior history. Verified at story-005 (S8-06) parametric AC-9 sweep. |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0005 Input Handling** (Accepted 2026-04-30 via `/architecture-review` delta #6) — owns InputRouter form-level architecture (Autoload Node + 6 fields + 7-state FSM + 22-action vocab + InputMode + 17 TR-input-handling-001..017 + 4 base forbidden_patterns). This ADR NARROWS ADR-0005 §9 SOFT/PROVISIONAL integration contracts; does NOT supersede ADR-0005's form decisions. **ADR-0001 GameBus** (Accepted 2026-04-18) — InputRouter sole-emitter of 3 Input-domain signals (`input_action_fired` / `input_state_changed` / `input_mode_changed`); this ADR ratifies the emit ordering inside `_handle_event` (state-changed FIRST, action-fired SECOND, mode-changed once-per-mode-transition). **ADR-0002 SceneManager** (Accepted 2026-04-18) — InputRouter consumes `ui_input_block_requested` / `ui_input_unblock_requested` for S5 entry/exit; SceneManager additionally calls `set_process_input(false) + set_process_unhandled_input(false)` for overworld retain; this ADR's `_handle_event` MUST honor those silenced-callback paths (engine drops events before `_unhandled_input` fires; `_handle_event` is unreachable when both callbacks are disabled). **ADR-0014 Grid Battle Controller** (Accepted 2026-05-03 via `/architecture-review` delta #11) — battle-scoped Node owning `is_tile_in_move_range(coord) -> bool` + `is_tile_in_attack_range(coord) -> bool` validation methods. ADR-0005 §9 SOFT/PROVISIONAL → **ratified here** as DI'd query-methods consumed by `_handle_event` for state transition gates (G-5 move_target_select valid? + G-6 attack_target_select valid? before S1→S2 / S3→S4 transitions). **ADR-0015 Battle HUD** (Accepted 2026-05-03 via `/architecture-review` delta #10) — battle-scoped Node with DI'd `_input_router: InputRouter` reference. ADR-0005 §9 SOFT/PROVISIONAL → **ratified here** as: (a) sole production caller of `InputRouter._handle_event` for undo button dispatch (per `battle_hud.gd:19` doc-comment + ADR-0015 §5); (b) consumer of `input_state_changed` for S5 INPUT_BLOCKED `MOUSE_FILTER_IGNORE` recursive disable (ADR-0015 §5); (c) consumer of `input_mode_changed` for hint icon updates; (d) callee of `show_unit_info(unit_id)` + `show_tile_info(coord)` for TPP CR-4a preview rendering. |
| **Soft / Provisional** | (1) **Camera ADR (NOT YET WRITTEN)** — REMAINS SOFT/PROVISIONAL per ADR-0005 §9. `Camera.screen_to_grid(screen_pos: Vector2) -> Vector2i` for touch/click hit-testing; Camera owns drag state (OQ-2 — InputRouter does NOT gate grid input mid-drag); Camera enforces `camera_zoom_min = 0.70` per F-1. This ADR commits no further narrowing; downstream Camera ADR ratifies (does not negotiate). (2) **Settings/Options ADR (NOT YET WRITTEN)** — REMAINS SOFT/PROVISIONAL. `InputRouter.set_binding(action: StringName, event: InputEvent) -> void` runtime key remapping per CR-1b; Settings/Options sole external caller. (3) **Tutorial ADR (NOT YET WRITTEN)** — REMAINS SOFT/PROVISIONAL. Subscribes to `input_action_fired` for tutorial step detection. |
| **Enables** | (1) **Sprint-8 S8-02..S8-06 input-handling stories 1-5** — InputRouter graduates from 33-line PLACEHOLDER (per `src/foundation/input_router.gd:1` doc-comment "TYPE PLACEHOLDER") to functional FSM with locked dispatch contract. (2) **Sprint-8 S8-07 S7-10 unblock + ship** — battle-hud story-005 (UI-GB-02/05/10 + two-tap timer) cannot validate AC-UX-HUD-08/09 without `_handle_event` undo dispatch path being a public contract surface BattleHUD can call from production. (3) **Resolution of S7-10 BLOCKED root cause** — sprint-7 retrospective (`production/retrospectives/retro-sprint-7-2026-05-05.md`) noted PLACEHOLDER discovery as the proximate cause; this ADR's contract surface (sole-caller-allow-list + state-mutation-allow-list) makes the PLACEHOLDER → production transition lint-enforceable instead of trust-based. (4) **Resolution of OQ-1 partial (gamepad routing)** + **OQ-2 partial (camera pan ownership)** — both confirmed unchanged from ADR-0005 §6 + §9 (gamepad → KEYBOARD_MOUSE; camera owns drag state + InputRouter pass-through). |
| **Blocks** | input-handling story-001 (S8-02) module-skeleton implementation (cannot start until this ADR Accepted via /architecture-review delta #15 — module skeleton's `_handle_event` stub signature is locked here). All 4 net-new forbidden_pattern lint scripts authored at story-010 epic terminal (S9 carryover) MUST conform to the ADR-locked dispatch sequence. |
| **Ordering Note** | Authored AFTER ADR-0014 + ADR-0015 (both Accepted 2026-05-03) AND AFTER ADR-0019 (Accepted 2026-05-05, most-recent precedent). The 5-precedent integration-narrowing pattern (ADR-0014 ratifying ADR-0010/11/12 provisional → ADR-0015 ratifying ADR-0005/10/11 provisional → ADR-0017 ratifying ADR-0001 + ADR-0003 provisional → ADR-0018 ratifying ADR-0017 line 209 widening → ADR-0019 ratifying ADR-0014 widening) is now stable; this ADR is the **6th invocation** of the integration-narrowing pattern. Same-session ban discipline: this Proposed-status ADR was authored without `/architecture-review` invocation in the same session; fresh-session delta #15 escalates to Accepted (combined-session escalation pattern 5th invocation after deltas #11/#12/#13/#14). |

## Context

### Problem Statement

ADR-0005 §1 line 119 + §8 establishes `_handle_event(event: InputEvent) -> void` as the InputRouter's "DI test seam" — a `_`-prefixed method that GdUnit4 v6.1.2 tests call directly with synthetic event instances, bypassing the engine's `_unhandled_input` dispatch. This framing is **insufficient for sprint-8 implementation** for 5 reasons:

1. **BattleHUD undo dispatch path** — `src/feature/battle_hud/battle_hud.gd:19` doc-comment explicitly states "method calls on DI'd backends (e.g. InputRouter._handle_event for undo)". This is a production caller, NOT a test caller. The `_`-prefix convention forbids production callers, but BattleHUD is a justified exception per ADR-0015 §5 §undo-button-press-handling (which references `_input_router._handle_event(InputEventAction.new(...))` synthesis). Without locking this exception in an ADR, the `_`-prefix convention is either (a) violated or (b) ambiguous.

2. **Inner-loop dispatch sequence is unspecified** — ADR-0005 §3 says "mode switch fires once per event"; §5 says "transition emits `input_state_changed` + `input_action_fired`"; §6 says "Joypad → KEYBOARD_MOUSE for MVP". Each is true in isolation but the **ordering** (mode-determine vs action-resolve vs state-transition vs signal-emit) is not locked. This matters because BattleHUD's S5 INPUT_BLOCKED `MOUSE_FILTER_IGNORE` recursive disable (per ADR-0015 §5 `_on_input_state_changed` handler line 627) must apply BEFORE any subsequent action signal could fire on a now-disabled UI tree, OR the disable-dispatch race produces phantom action emits during scene transitions.

3. **Provisional contracts in ADR-0005 §9 now have Accepted upstream ADRs** — Grid Battle (ADR-0014 Accepted 2026-05-03) + Battle HUD (ADR-0015 Accepted 2026-05-03). The 5-precedent provisional-dependency strategy (ADR-0008→0006, ADR-0012→0009/10/11, ADR-0009→0007, ADR-0007→Formation Bonus, ADR-0019→0014 widening) requires **ratification at the downstream-ADR Acceptance time**, NOT at the upstream-ADR Acceptance time. This ADR is the ratification document for InputRouter↔GridBattleController + InputRouter↔BattleHUD; the SOFT/PROVISIONAL labels in ADR-0005 §9 lines 174-178 must flip to ratified here.

4. **Sprint-7 S7-10 PLACEHOLDER discovery** — sprint-7 S7-10 (battle-hud story-005, UI-GB-02/05/10 + two-tap timer) was BLOCKED at story-attempt time because `src/foundation/input_router.gd` was a 33-line type-placeholder without `_handle_event` body. Sprint-7 retrospective (`production/retrospectives/retro-sprint-7-2026-05-05.md`) attributed this to "no architectural contract that says BattleHUD can rely on `_handle_event` existing". A new ADR closes this gap by making the contract surface explicit + lint-enforceable.

5. **`_state` / `_active_mode` mutation discipline** — ADR-0005 §1 line 119 declares 6 instance fields but does not lock **which method is allowed to write them**. Without an ADR-locked allow-list, future stories (006/007/008/009 input-handling) might add helper methods that mutate `_state` directly, breaking the dispatch-sequence invariant from §2 above.

### Constraints

**From ADR-0005 (form-level constraints REMAIN authoritative — this ADR does not amend them):**

- **6 instance fields** — `_state` / `_active_mode` / `_pre_menu_state` / `_undo_windows` / `_input_blocked_reasons` / `_bindings`. Field count + types unchanged. (ADR-0005 §1 line 119)
- **7-state FSM** — S0..S6 enum int 0..6 wire-format. Transition semantics unchanged. (ADR-0005 §5)
- **22-action vocabulary** — 10 grid + 4 camera + 5 menu + 3 meta. ACTIONS_BY_CATEGORY const Dictionary. (ADR-0005 §4)
- **InputMode enum** — KEYBOARD_MOUSE=0 / TOUCH=1 / GAMEPAD=2 reserved. (ADR-0005 §6)
- **3 GameBus emits** — `input_action_fired(action, ctx)` + `input_state_changed(from, to)` + `input_mode_changed(new_mode)`. Sole-emitter for Input domain. (ADR-0005 §3 + ADR-0001 §7)
- **2 GameBus subscriptions** — `ui_input_block_requested` + `ui_input_unblock_requested` from SceneManager. (ADR-0005 §1 + ADR-0002)

**From ADR-0014 (now Accepted; this ADR ratifies the integration):**

- **`is_tile_in_move_range(coord: Vector2i) -> bool`** + **`is_tile_in_attack_range(coord: Vector2i) -> bool`** are public methods on GridBattleController battle-scoped Node. InputRouter `_handle_event` calls these (via DI'd reference per integration step in `BattleScene._ready()` mount sequence) for S1→S2 + S3→S4 transition gates per CR-EC-7 (out-of-range tap rejection).
- **`ai_action_requested(unit_id, snapshot)`** is GridBattleController's LOCAL signal (NOT GameBus); InputRouter does NOT subscribe (CR-AI-6 + ADR-0014 §8 LOCAL signal contract). AI dispatch is a parallel pipeline, not a downstream consumer of InputRouter.

**From ADR-0015 (now Accepted; this ADR ratifies the integration):**

- **`BattleHUD.show_unit_info(unit_id: int) -> void`** + **`show_tile_info(coord: Vector2i) -> void`** are public methods called by InputRouter for TPP CR-4a preview rendering on S0 + TOUCH mode tap.
- **`BattleHUD._on_input_state_changed(from, to)`** GameBus handler (per `battle_hud.gd:621`) — applies `MOUSE_FILTER_IGNORE` to grid-tap surfaces when `to == InputState.INPUT_BLOCKED`; reverts to `MOUSE_FILTER_PASS` when `from == INPUT_BLOCKED`.
- **`BattleHUD._on_input_mode_changed(new_mode)`** GameBus handler (per `battle_hud.gd:633`) — updates hint icons + action panel layout.
- **`BattleHUD._on_undo_button_pressed()`** internally calls `_input_router._handle_event(InputEventAction.new(...))` to inject an `undo_last_move` action — sole production exception to `_`-prefix discipline.

**From sprint-7 retrospective (`retro-sprint-7-2026-05-05.md`):**

- Sprint-7 retro AI #1 PARTIAL: "all shipped work must close its sprint-status row in the same patch" — this ADR's authoring must close S8-01 row in the same commit.
- Sprint-7 retro improvement #1 NEW: "pre-flight check policy — every carryover story must verify underlying infra has all referenced APIs at sprint-plan time". S7-10 PLACEHOLDER was the lesson; this ADR's contract surface enables future S8-07-style stories to grep for `_handle_event` body presence at sprint-plan time, not story-attempt time.

**From sprint-8 plan §S8-01 + §R1:**

- `_handle_event(event: InputEvent) -> void` dispatch contract per input-handling.md F-1/F-2.
- Touch-mouse separation per technical-preferences.md "no hover-only".
- 6+ forbidden_patterns (this ADR delivers 8 = 4 base from ADR-0005 + 4 net-new).
- DI test seam.
- Integration with ADR-0014 GridBattleController + ADR-0015 BattleHUD.
- Combined-session escalation pattern 5th invocation (same-session-ban with `/architecture-review`).

**Performance budget (inherited from ADR-0005 §Performance Implications):**

- `_handle_event < 0.05ms` on minimum-spec mobile (Adreno 610 / Mali-G57 class).
- `_handle_action_match < 0.02ms` (single match-arm dispatch).
- 10k synthetic events <500ms headless throughput baseline.

**Architecture-registry constraints (read from `docs/registry/architecture.yaml` v13 post-ADR-0019):**

- `input_router_signal_emission_outside_input_domain` forbidden_pattern (ADR-0005) — InputRouter does NOT emit GameBus signals outside the 3 Input-domain signals. This ADR's dispatch sequence respects this; no new emit surfaces.
- `grid_battle_controller_signal_emission_outside_battle_domain` forbidden_pattern (ADR-0014 widening at delta #14) — InputRouter does NOT emit GridBattleController's 6 LOCAL signals; it CALLS GridBattleController's range-validation methods.
- `hardcoded_input_bindings` forbidden_pattern (ADR-0005) — REMAINS authoritative; this ADR's dispatch loop reads `_bindings` populated from `default_bindings.json` at autoload `_ready()`.

## Decision

Lock the **`_handle_event(event: InputEvent) -> void` dispatch contract** with a 4-phase inner-loop sequence + 4 net-new forbidden_patterns + 3 ratified integration narrowings. ADR-0005 §1 form-level decisions REMAIN authoritative (Autoload Node + 6 fields + 7-state FSM + 22-action vocab + InputMode + 17 TRs); this ADR augments without superseding.

### Decision §1. `_handle_event` Dispatch Sequence (4-phase inner loop)

`_handle_event(event: InputEvent) -> void` body MUST follow this exact sequence:

```gdscript
func _handle_event(event: InputEvent) -> void:
    # Phase 1 — Mode determination (most-recent-event-class rule per ADR-0005 §3)
    var detected_mode: InputMode = _determine_mode_from_event(event)
    if detected_mode != _active_mode:
        _active_mode = detected_mode
        GameBus.input_mode_changed.emit(int(detected_mode))

    # Phase 2 — Action resolution via InputMap (per CR-1b externalized bindings)
    var action: StringName = _resolve_action_from_event(event)
    if action == &"":
        return  # event not bound to any action; silently drop

    # Phase 3 — State transition (inline match dispatch per ADR-0005 §5)
    var prev_state: InputState = _state
    var ctx: InputContext = _build_context_for_action(action, event)
    var new_state: InputState = _transition_state(prev_state, action, ctx)
    if new_state == prev_state:
        # action consumed without state change (e.g. camera_pan in S0 stays S0)
        # OR action invalid for current state (silently dropped per ADR-0005 §5 ST-1..ST-4)
        if _action_was_valid(prev_state, action):
            GameBus.input_action_fired.emit(action, ctx)
        return
    _state = new_state

    # Phase 4 — Signal emit pair (state-changed FIRST, action-fired SECOND)
    # Order matters: BattleHUD MOUSE_FILTER_IGNORE on S5 entry must apply before
    # any subsequent action could fire on now-disabled tree (ADR-0015 §5).
    GameBus.input_state_changed.emit(int(prev_state), int(new_state))
    GameBus.input_action_fired.emit(action, ctx)
```

Justification for the 4-phase sequence:

- **Phase 1 first** — mode determination is a pure structural read of event class identity (no state mutation beyond `_active_mode` write); must run before any action resolution because Phase 2's `InputMap` resolution may differ between modes (e.g. `grid_hover` is PC-only per CR-1c — touch mode never resolves it).
- **Phase 2 second** — action resolution via `InputMap.action_get_events(action)` lookups (or equivalent inverse); produces `action: StringName`. Empty StringName = unbound event (silently dropped per CR-1d). NO state mutation in this phase.
- **Phase 3 third** — state transition logic is the only phase that reads `_state` + writes new `_state`. Match dispatch is inline (NOT a separate StateMachine Resource per ADR-0005 §5 — single dispatch path through `_handle_action(action, ctx)`). Validation against GridBattleController range methods happens here (e.g. `move_target_select` from S1 → S2 only if `GridBattleController.is_tile_in_move_range(ctx.coord)` returns true).
- **Phase 4 last** — emit pair MUST fire `input_state_changed` BEFORE `input_action_fired`. BattleHUD's S5 INPUT_BLOCKED handler (per ADR-0015 §5) applies `MOUSE_FILTER_IGNORE` recursive disable at `_on_input_state_changed`; if the action signal fires first, action consumers (Grid Battle controller, Camera) might process the action against a now-disabled UI state (race condition).

The "action consumed without state change" branch (e.g. camera_pan in S0 stays S0; G-2 grid_hover in PC mode) emits `input_action_fired` ONLY if the action was valid for the current state — invalid actions (e.g. unit_select on enemy turn S5 INPUT_BLOCKED) are silently dropped per ADR-0005 §5 ST-1.

### Decision §2. `_handle_event` is the Sole State-Mutating Method

The 4 mutable instance fields written ONLY inside `_handle_event` body:
- `_state: InputState` (Phase 3 only)
- `_active_mode: InputMode` (Phase 1 only)
- `_pre_menu_state: InputState` (Phase 3 — set on S6 MENU_OPEN entry per ADR-0005 §5 ST-1)
- `_undo_windows: Dictionary[int, UndoEntry]` (Phase 3 — populate on S2 confirm → S0; clear on attack/end-unit-turn/end-player-turn per CR-5)

The 2 fields with allowed external write entry points:
- `_input_blocked_reasons: PackedStringArray` — written via `_on_ui_input_block_requested(reason)` + `_on_ui_input_unblock_requested(reason)` GameBus handlers (per ADR-0005 §1 + ADR-0002). These handlers are CONNECT_DEFERRED subscriptions; mutation is single-threaded by Godot's deferred dispatch.
- `_bindings: Dictionary[StringName, Array[InputEvent]]` — written via `set_binding(action, event)` runtime remap method (per CR-1b; Settings/Options sole external caller).

Lint enforcement: `tools/ci/lint_input_router_state_mutation_outside_handle_event.sh` (NEW per Migration Plan §3) greps for `_state\s*=`/`_active_mode\s*=`/`_pre_menu_state\s*=`/`_undo_windows\[` writes outside the `_handle_event` function body in `src/foundation/input_router.gd`; returns 0.

### Decision §3. `_handle_event` Caller Allow-List

`_handle_event(event)` is `_`-prefixed per GDScript convention — production callers are normally forbidden. This ADR locks **2 production caller exceptions**:

1. **Engine `_unhandled_input(event)` callback** — InputRouter's `_unhandled_input(event)` body is exactly `_handle_event(event)` (single-line forwarder per ADR-0005 §8). This is the standard Godot input pipeline entry; it does not violate `_`-prefix discipline because `_unhandled_input` is itself `_`-prefixed (engine-callback prefix; semantic is "engine entry point", not "private method").

2. **`src/feature/battle_hud/battle_hud.gd` undo dispatch** — BattleHUD's `_on_undo_button_pressed()` synthesizes an `InputEventAction.new()` with `action = &"undo_last_move"` + `pressed = true` and calls `_input_router._handle_event(synthetic_event)`. This is the sole production exception per ADR-0015 §5 + `battle_hud.gd:19` doc-comment. Justification: undo button is a HUD-owned UI control (tap target), not a grid-domain input event; it cannot route through `_unhandled_input` because the HUD-tap is consumed by the Control before reaching `_unhandled_input`. Synthesis-and-inject is the only path that preserves the `_handle_event` 4-phase dispatch sequence + signal emit invariants.

GdUnit4 v6.1.2 tests are NOT subject to the allow-list — the `_`-prefix convention exempts `tests/**/*.gd` files universally per project test-injection precedent (mirrors damage-calc story-006 RNG-injection pattern + 11-story precedent across damage-calc / unit-role / hp-status / turn-order epics).

Lint enforcement: `tools/ci/lint_input_router_handle_event_caller_allowlist.sh` (NEW per Migration Plan §3) greps for `_handle_event\s*\(` outside (a) `src/foundation/input_router.gd` itself, (b) `src/feature/battle_hud/battle_hud.gd`, (c) `tests/**/*.gd`. Returns 0 violations.

### Decision §4. Touch-Mouse Separation: `_determine_mode_from_event` Pure Function

Per CR-1a hover-only ban + CR-2b last-device-wins, mode determination is **structural, not temporal** — `_determine_mode_from_event(event: InputEvent) -> InputMode` consults event class identity ONLY, never reads `_active_mode` or any time-window history:

```gdscript
func _determine_mode_from_event(event: InputEvent) -> InputMode:
    if event is InputEventScreenTouch or event is InputEventScreenDrag:
        return InputMode.TOUCH
    if event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventKey:
        return InputMode.KEYBOARD_MOUSE
    if event is InputEventJoypadButton or event is InputEventJoypadMotion:
        return InputMode.KEYBOARD_MOUSE  # OQ-1 partial: gamepad → KEYBOARD_MOUSE for MVP
    return _active_mode  # unknown event class — preserve last-known mode (defensive)
```

Pure-function discipline: same input event class always returns same `InputMode` regardless of prior history. This makes Phase 1 idempotent (back-to-back same-class events emit `input_mode_changed` exactly once on first transition; zero emits on subsequent same-mode events per AC-5 idempotency test from story-005). NOT chosen:

- **Temporal smoothing** (REJECTED) — debouncing or rolling-window mode determination would mask deliberate device-switch input (e.g. user picks up tablet stylus while phone keyboard plugged in). Last-device-wins is the player-fantasy-correct behavior per `design/gdd/input-handling.md` §Player Fantasy "two-beat rhythm".
- **Active-mode hysteresis** (REJECTED) — biasing toward keeping current mode would create a "stickiness" pathology on legitimately ambiguous events. CR-2b fires once per event with no debounce.

### Decision §5. Forbidden Patterns Total: 8 (4 carried + 4 net-new)

**Carried from ADR-0005 (unchanged authoritative source):**

1. `hardcoded_input_bindings` — bindings live in `default_bindings.json`; never hardcoded. Lint: `grep -E '(KEY_|MOUSE_BUTTON_|JOY_BUTTON_)' src/foundation/input_router.gd` returns 0 outside import-block constants.
2. `input_router_input_blocked_drop_without_set_input_as_handled` — INPUT_BLOCKED dispatch arm MUST call `get_viewport().set_input_as_handled()` before returning (Advisory C from ADR-0005 delta #6).
3. `input_router_signal_emission_outside_input_domain` — InputRouter is sole-emitter of 3 Input-domain GameBus signals; non-emitter for OTHER 21 signals across 8 domains. Lint: `grep -c 'GameBus\.' src/foundation/input_router.gd` minus the 3 Input-domain emits + 2 ADR-0002 consumes = 0.
4. `emulate_mouse_from_touch_enabled` — `project.godot` `[input_devices.pointing]` must have `emulate_mouse_from_touch=false`. Lint: `grep -E 'emulate_mouse_from_touch=true' project.godot` returns 0; `grep -E 'emulate_mouse_from_touch=false' project.godot` returns ≥1.

**Net-new in this ADR (4 patterns; lint scripts authored at story-010 epic-terminal S9 carryover):**

5. **`input_router_state_mutation_outside_handle_event`** — `_state` / `_active_mode` / `_pre_menu_state` / `_undo_windows` mutation only inside `_handle_event` body. Lint: `tools/ci/lint_input_router_state_mutation_outside_handle_event.sh` (per Decision §2 V-Required item 1).

6. **`input_router_handle_event_external_caller_outside_battle_hud`** — `InputRouter._handle_event` callable only from (a) InputRouter itself via `_unhandled_input`, (b) `src/feature/battle_hud/battle_hud.gd`, (c) tests. Lint: `tools/ci/lint_input_router_handle_event_caller_allowlist.sh` (per Decision §3 V-Required item 2).

7. **`input_router_per_frame_state_polling_api`** — InputRouter does NOT export per-frame state read API beyond the 2 already-locked getters from ADR-0005 §1 (`get_active_input_mode()` + `get_state()`). Consumers MUST subscribe to `input_state_changed` / `input_mode_changed` for state observation; per-frame polling forbidden because it would race with the 4-phase dispatch sequence (Decision §1). Lint: `grep -E '^func get_' src/foundation/input_router.gd` returns exactly 2 matches (the 2 ADR-0005 getters; no NEW getters added).

8. **`input_router_hover_only_action_in_bindings`** — extends CR-1a hover-only ban: any action in `default_bindings.json` MUST have BOTH a PC binding (keyboard/mouse) AND a touch binding (gesture/HUD button), EXCEPT G-2 `grid_hover` which is PC-only by design per CR-1c (whitelisted). Lint: `tools/ci/lint_input_bindings_pc_touch_parity.sh` parses JSON, counts non-empty PC + touch arrays per action, fails any action with PC-only binding except `grid_hover`.

### Decision §6. Integration Narrowing — 3 Provisional Contracts → Ratified

**Ratification 1: ADR-0014 GridBattleController as range-validation source**

ADR-0005 §9 line 175 SOFT/PROVISIONAL → **ratified here**. InputRouter `_handle_event` Phase 3 state-transition match arms call:

- `GridBattleController.is_tile_in_move_range(coord: Vector2i) -> bool` for S1→S2 transition gate (CR-EC-7 out-of-range tap rejection).
- `GridBattleController.is_tile_in_attack_range(coord: Vector2i) -> bool` for S3→S4 transition gate.

Integration mechanism: `InputRouter._grid_battle_controller: GridBattleController = null` instance field set via `set_grid_battle_controller(controller)` setter called by `BattleScene._ready()` mount sequence (per ADR-0014 §6 + ADR-0019 §Mount Order line 254 inserted-step pattern). Setter is the only entry point for the reference; cleared on `BattleScene._exit_tree()` per battle-scoped lifecycle. InputRouter does NOT subscribe to GridBattleController's 6 LOCAL signals — calls are method-level only, not signal-level (CR-AI-6 + ADR-0014 §8 LOCAL signal channel reserved for AI dispatch).

Forbidden pattern from ADR-0005 not violated: InputRouter still does NOT compute ranges itself (CR-EC-7); it queries GridBattleController for every transition gate.

**Ratification 2: ADR-0015 BattleHUD as TPP callee + signal subscriber + undo `_handle_event` caller**

ADR-0005 §9 line 176 SOFT/PROVISIONAL → **ratified here**. 4 integration surfaces locked:

(a) InputRouter `_handle_event` Phase 3 (state stays S0 + mode TOUCH + action `grid_select` on tile/unit) calls `BattleHUD.show_unit_info(unit_id)` OR `BattleHUD.show_tile_info(coord)` for TPP CR-4a preview rendering. Reference: `BattleHUD._battle_hud: BattleHUD = null` instance field set via `set_battle_hud(hud)` setter (parallel to Ratification 1 mechanism).

(b) BattleHUD subscribes to `GameBus.input_state_changed` via CONNECT_DEFERRED at `BattleHUD._ready()` (per ADR-0015 §5 line 621); applies `MOUSE_FILTER_IGNORE` recursive disable on S5 entry; reverts on S5 exit. InputRouter is sole emitter; subscription is consumer-side concern.

(c) BattleHUD subscribes to `GameBus.input_mode_changed` via CONNECT_DEFERRED at `BattleHUD._ready()` (per ADR-0015 §5 line 633); updates hint icons + action panel layout. InputRouter is sole emitter.

(d) BattleHUD's `_on_undo_button_pressed()` synthesizes `InputEventAction.new()` with `action = &"undo_last_move"` + `pressed = true` and calls `_input_router._handle_event(synthetic_event)`. This is the **sole production exception to `_`-prefix discipline** per Decision §3 caller allow-list.

**Ratification 3: Camera + Settings/Options + Tutorial REMAIN SOFT/PROVISIONAL**

No narrowing in this ADR — those 3 systems do not yet have Accepted ADRs. ADR-0005 §9 lines 174 + 177 + 178 unchanged; downstream Camera/Settings/Tutorial ADRs ratify when authored.

### Decision §7. Signal Emit Ordering Invariant

`_handle_event` Phase 4 emit pair MUST fire in this exact order on every state transition:

1. `GameBus.input_state_changed.emit(int(prev_state), int(new_state))` — FIRST
2. `GameBus.input_action_fired.emit(action, ctx)` — SECOND

Justification: BattleHUD's `_on_input_state_changed` handler (per ADR-0015 §5 line 627) applies `MOUSE_FILTER_IGNORE` recursive disable on S5 entry. If `input_action_fired` fires first, downstream consumers (Grid Battle, Camera) might process the action against a now-disabled UI tree — a race condition that surfaces only on S0 → S5 transitions during enemy phase boundary or scene-transition handoff. Locking the order at the ADR level prevents future refactors from accidentally swapping the emits.

`input_mode_changed` emit (Phase 1) fires BEFORE the state-changed/action-fired pair when mode also changes — but is decoupled from the pair (mode change can happen independently of state change, e.g. on `grid_hover` PC event in S0).

## Alternatives Considered

### Alternative 1: Amend ADR-0005 Instead of New ADR

**Rejected.** ADR-0005 is form-level (Autoload, FSM, vocab, modes, undo). Amendment would conflate form/dispatch/integration concerns into one ADR exceeding ~600 LoC. Project precedent (ADR-0014 + ADR-0015 + ADR-0017 + ADR-0018 + ADR-0019) is to author a **new ADR for each major architectural surface** even when surfaces are tightly related; this ADR follows that precedent (6th invocation of integration-narrowing pattern). ADR-0005 changelog would also lose the "Status: Accepted (2026-04-30)" pin if reflowed for amendment.

### Alternative 2: Skip ADR — Let Stories Implement Organically

**Rejected.** Sprint-7 S7-10 BLOCKED on InputRouter PLACEHOLDER demonstrated that without an architectural contract that says BattleHUD can rely on `_handle_event` existing, the implementation can ship broken. The pre-flight check policy from sprint-7 retro improvement #1 ("every carryover story must verify underlying infra has all referenced APIs at sprint-plan time") requires a written contract surface to grep against. Skipping the ADR would also leave the 4 net-new forbidden_patterns un-codified; the patterns are non-trivial design decisions (especially Decision §3 caller allow-list with the BattleHUD exception) that need ADR-level review.

### Alternative 3: Public `dispatch(event)` Method Instead of `_handle_event`

**Rejected.** Renaming to `dispatch(event)` would remove the `_`-prefix discipline that protects the inner-loop state-mutation invariant from accidental external callers. The `_handle_event` allow-list approach (Decision §3) preserves the convention while explicitly authorizing the BattleHUD exception via lint allow-list. Public `dispatch(event)` would also break GdUnit4 test conventions where `_`-prefixed methods are the established DI test seam pattern (mirrors damage-calc story-006 RNG-injection 11-story precedent).

### Alternative 4: Per-Action Dispatcher Class Hierarchy

**Rejected.** ADR-0005 §5 already locked inline match dispatch. Refactoring to per-action dispatcher classes would add 22+ source files (one per action) for a closed action vocabulary that does not benefit from extensibility. Mirrors ADR-0019 §Decision §Archetype Dispatch reasoning (single-class match-dispatch vs subclass hierarchy — same trade-off, same conclusion).

### Alternative 5: Synchronous `await` Inside `_handle_event` for Range Validation

**Rejected.** `is_tile_in_move_range` + `is_tile_in_attack_range` are synchronous methods on GridBattleController (per ADR-0014 §6); no `await` needed. If future ADR-0014 amendment makes them async (unlikely — they read battle-scoped state), this ADR would need an amendment. Locking synchronous invocation here prevents future drift.

### Alternative 6: Separate `_handle_event_test_seam(event)` for Tests

**Rejected.** Duplicating the dispatch entry would create test-vs-production drift — tests would exercise a different code path than production. Single entry point with allow-list lint is the safer pattern.

## Consequences

### Positive

- **Sprint-8 S8-02..06 input-handling stories unblocked** with locked architectural contract — InputRouter graduates from PLACEHOLDER to functional FSM with lint-enforceable invariants.
- **Sprint-7 S7-10 unblock at S8-07** structurally guaranteed — once `_handle_event` body lands per S8-04 (story-003 FSM core), BattleHUD's two-tap timer test (UI-GB-02/05/10 + AC-UX-HUD-08/09) can validate against a real production dispatch path.
- **Pre-flight check policy enforced** — sprint-7 retro improvement #1 ("verify referenced APIs at sprint-plan time") becomes lint-greppable: `grep -n 'func _handle_event' src/foundation/input_router.gd` either returns the body or fails fast.
- **6th invocation of integration-narrowing pattern stable** — provisional-dependency strategy at 6 invocations across the project is a project-wide discipline marker.
- **8 forbidden_patterns codified** — exceeds sprint-8 plan target of 6+; codifies the BattleHUD `_handle_event` exception lint-explicitly.
- **Touch-mouse separation pattern locked** — pure-function `_determine_mode_from_event` is structurally idempotent + parametric-test-friendly; AC-5 + AC-9 from story-005 trivially derive from Decision §4.

### Negative

- **2 new lint scripts at story-010 epic terminal** (sprint-9 carryover S7→S8→S9): `lint_input_router_state_mutation_outside_handle_event.sh` + `lint_input_router_handle_event_caller_allowlist.sh`. Adds ~50 LoC of bash + CI workflow wiring. Already accounted for in input-handling EPIC.md story-010 9-CI-lint-scripts target.
- **BattleHUD `_handle_event` exception is a load-bearing ADR-locked exception** — future refactor to remove the exception (e.g. add public `inject_action(action, ctx)` method on InputRouter) requires ADR amendment. Trade-off accepted because BattleHUD's undo dispatch is the only known production caller; over-engineering for hypothetical second exception unwarranted.
- **2 net-new instance field references** (`_grid_battle_controller` + `_battle_hud` per Decision §6) extend ADR-0005's 6-field count to 8 fields. Field count drift requires ADR-0005 changelog entry at /architecture-review delta #15 + tr-registry TR-input-handling-002 amendment ("6 fields" → "8 fields with 2 DI'd Node references"). Net cost: 2 changelog lines + 1 TR amendment.
- **Decision §1 4-phase sequence is prescriptive** — locks implementation freedom for sprint-8 S8-04 (story-003 FSM core). Trade-off accepted because the ordering is load-bearing for ADR-0015 BattleHUD subscriber correctness.

### Neutral

- **No new GameBus signals** — 3 Input-domain signals from ADR-0001 §7 unchanged.
- **No new Resources** — InputContext + UndoEntry from ADR-0005 unchanged.
- **No supersession** — ADR-0005 status remains Accepted; this ADR is additive narrowing.

## Risks

- **R-1 (LOW)**: BattleHUD `_handle_event` exception leaks into other scenes (e.g. Overworld scene adds undo button calling InputRouter). **Mitigation**: Decision §3 lint allow-list rejects any new caller; new exception requires ADR amendment per design discipline.

- **R-2 (LOW)**: Decision §1 Phase 4 emit ordering accidentally swapped during refactor. **Mitigation**: integration test at story-003 (S8-04) asserts `input_state_changed` Callable's deferred-frame fires before `input_action_fired` Callable's deferred-frame on a synthesized S0→S5 transition.

- **R-3 (MEDIUM)**: GAMEPAD mode promotion (post-MVP) requires Phase 1 amendment in `_determine_mode_from_event`. **Mitigation**: ADR-0005 §6 reserves int 2 for GAMEPAD mode; future Settings/Options ADR adds 3rd `match` arm to `_determine_mode_from_event` without supersession of this ADR (additive amendment).

- **R-4 (LOW)**: `is_tile_in_move_range` / `is_tile_in_attack_range` made async in future ADR-0014 amendment. **Mitigation**: Alternative 5 explicitly rejects async — future async refactor would require this ADR's amendment, surfacing the breaking-change explicitly.

- **R-5 (LOW)**: `_grid_battle_controller` / `_battle_hud` reference held across BattleScene exit causes use-after-free. **Mitigation**: BattleScene's `_exit_tree` clears references via `InputRouter.clear_battle_references()` setter (NEW per Migration Plan §1); InputRouter is autoload (survives scene transitions) but battle-scoped Node references must be cleared at battle exit.

- **R-6 (LOW)**: Lint allow-list false positive on legitimate refactor (e.g. moving BattleHUD undo logic to a sub-Node `UndoButtonController`). **Mitigation**: lint allow-list editable per ADR amendment; cost of amendment is single-line file path addition + changelog entry.

## Performance Implications

- **`_handle_event` total body**: < 0.05 ms on minimum-spec mobile (Adreno 610 / Mali-G57 class) — Phase 1 (1 type check chain) + Phase 2 (1 InputMap lookup) + Phase 3 (1 match-arm + 1-2 method calls to GridBattleController) + Phase 4 (2 signal emits).
- **`_determine_mode_from_event`**: < 0.005 ms (3 `is`-narrowing checks).
- **`_resolve_action_from_event`**: < 0.01 ms (1 InputMap lookup).
- **`_transition_state` (match dispatch)**: < 0.02 ms (1 match-arm + 0-2 GridBattleController query method calls).
- **Signal emit pair (Phase 4)**: < 0.01 ms (2 GameBus emits via CONNECT_DEFERRED — actual handler runs next frame).
- **No new memory allocations per event** beyond the existing InputContext payload (~16 bytes per Vector2i + 8 bytes per int = ~24 bytes; transient, garbage-collected when the signal handler returns).
- **Frame impact**: synchronous; 10k synthetic events <500ms headless throughput baseline (per ADR-0005 §Performance Implications + AC-AI-11 mirror).

## Migration Plan

1. **No source code changes in this ADR's authoring** — sprint-8 stories S8-02..S8-06 implement.
2. **`InputRouter._grid_battle_controller` + `_battle_hud` instance fields added at story-001 (S8-02)** — accompanying setters `set_grid_battle_controller(controller)` + `set_battle_hud(hud)` + `clear_battle_references()`. ADR-0005 6-field count extends to 8 fields per Consequences §Negative.
3. **2 new lint scripts at story-010 epic terminal (S9 carryover)**:
   - `tools/ci/lint_input_router_state_mutation_outside_handle_event.sh` — Decision §2 enforcement.
   - `tools/ci/lint_input_router_handle_event_caller_allowlist.sh` — Decision §3 enforcement.
   (2 additional lint scripts — `lint_input_bindings_pc_touch_parity.sh` for forbidden_pattern #8 + perf-budget script — already in EPIC.md story-010 9-CI-lint-scripts target.)
4. **Architecture registry update** at `/architecture-review` delta #15: `docs/registry/architecture.yaml` v13 → v14 with 4 net-new forbidden_patterns + 2 amended (`input_router_signal_emission_outside_input_domain` description widening to ratify ADR-0014 + ADR-0015 integration; `hardcoded_input_bindings` description amendment to reference ratification 1+2).
5. **TR registry update**: `docs/architecture/tr-registry.yaml` v15 → v16. Append TR-input-handling-018..021 (4 net-new TRs):
   - TR-input-handling-018: `_handle_event` 4-phase dispatch sequence (Decision §1 + V-Required item 1).
   - TR-input-handling-019: `_handle_event` sole-state-mutating-method invariant (Decision §2 + forbidden_pattern #5).
   - TR-input-handling-020: `_handle_event` caller allow-list (Decision §3 + forbidden_pattern #6).
   - TR-input-handling-021: Signal emit ordering invariant (Decision §7 + V-Required item 4).
   Amend TR-input-handling-002 description: "6 fields" → "6 base fields per ADR-0005 + 2 DI'd Node references per ADR-0020 = 8 fields".
6. **ADR-0005 changelog entry** at delta #15: append "2026-05-05 — ADR-0020 narrows ADR-0005 §9 SOFT/PROVISIONAL contracts (Grid Battle + Battle HUD ratified; Camera/Settings/Tutorial unchanged); 4 net-new forbidden_patterns added (5..8); 2-field count extension (`_grid_battle_controller` + `_battle_hud` DI'd references)."
7. **ADR-0014 changelog entry** at delta #15: append "2026-05-05 — ADR-0020 ratifies `is_tile_in_move_range` + `is_tile_in_attack_range` as InputRouter consumer surfaces."
8. **ADR-0015 changelog entry** at delta #15: append "2026-05-05 — ADR-0020 ratifies BattleHUD's 4 InputRouter integration surfaces (TPP callee + 2 GameBus subscribers + undo `_handle_event` caller exception)."
9. **Architecture traceability update** at delta #15: 4 net-new TRs surface in traceability matrix; 2 amended TRs (ADR-0005 form-level TR-002 widening) cross-reference both ADRs.
10. **Sprint-status.yaml row close** (sprint-7 retro AI #1 enforcement): S8-01 row flips to `done` in same patch as this ADR's commit; S8-02..06 rows blocker field references "S8-01" until /architecture-review delta #15 lands.

All migration items above are sprint-8/9 scope. This ADR's authoring (Proposed) is the same-patch deliverable; Acceptance via fresh-session delta #15 is a downstream action.

## Validation Criteria

- **V-1**: `_handle_event` is the sole state-mutating method for `_state` / `_active_mode` / `_pre_menu_state` / `_undo_windows`. Lint exit 0 (Decision §2). Verified at story-003 (S8-04) implementation.
- **V-2**: BattleHUD is the sole production caller of `InputRouter._handle_event` outside engine `_unhandled_input`. Lint exit 0 (Decision §3). Verified at story-001 (S8-02) module-skeleton ship.
- **V-3**: 22-action vocabulary parity test (PC binding + touch binding for 21 of 22 actions; G-2 grid_hover whitelisted PC-only). Lint exit 0 (forbidden_pattern #8). Verified at story-002 (S8-03).
- **V-4**: Phase 4 emit ordering — `input_state_changed` fires before `input_action_fired` on every state-changing transition. Integration test at story-003 (S8-04) asserts via signal-capture order.
- **V-5**: `_determine_mode_from_event` parametric sweep — 7 (event_class, expected_mode) cases per AC-9 from story-005 (S8-06). Pure-function discipline holds.
- **V-6**: 8 forbidden_pattern lint scripts all green at story-010 (S9 carryover) epic-terminal.
- **V-7**: `_grid_battle_controller` + `_battle_hud` references cleared on BattleScene `_exit_tree` (R-5 mitigation). Verified at integration test in story-003 (S8-04).
- **V-8**: `_handle_event < 0.05ms` perf baseline (10k synthetic events <500ms headless). Verified at story-010 (S9 carryover) perf-baseline test.

## GDD Requirements Addressed

| TR | Requirement | Source |
|---|---|---|
| TR-input-handling-018 | `_handle_event` 4-phase dispatch sequence (mode-determine → action-resolve → state-transition → signal-emit) | this ADR §Decision §1 |
| TR-input-handling-019 | `_handle_event` sole-state-mutating-method invariant for 4 of 6 fields (`_state` / `_active_mode` / `_pre_menu_state` / `_undo_windows`) | this ADR §Decision §2 + forbidden_pattern #5 |
| TR-input-handling-020 | `_handle_event` caller allow-list (engine `_unhandled_input` + BattleHUD undo + tests) | this ADR §Decision §3 + forbidden_pattern #6 |
| TR-input-handling-021 | Phase 4 signal emit ordering invariant (`input_state_changed` FIRST, `input_action_fired` SECOND) | this ADR §Decision §7 + V-4 |
| TR-input-handling-002 (amended) | 6 fields per ADR-0005 + 2 DI'd Node references per ADR-0020 (`_grid_battle_controller` + `_battle_hud`) = 8 fields total | ADR-0005 §1 + this ADR §Decision §6 |

## Related

- `design/gdd/input-handling.md` — the GDD this ADR's dispatch sequence ratifies (CR-1..CR-5 + ST-1..ST-4 + AC-1..AC-18 + F-1..F-3)
- `design/gdd/grid-battle.md` — CR-EC-7 out-of-range tap rejection rule consumed by Phase 3 state-transition match arms
- `design/ux/battle-hud.md` — UI-GB-N consumer surfaces ratified by Decision §6 Ratification 2
- `docs/architecture/ADR-0001-gamebus-autoload.md` §7 — Input-domain signal contract source-of-truth (3 emits)
- `docs/architecture/ADR-0002-scene-manager.md` — `ui_input_block/unblock_requested` consumer pair + recursive disable
- `docs/architecture/ADR-0005-input-handling.md` — form-level authoritative source (Autoload Node + 6 fields + 7-state FSM + 22-action vocab + InputMode + 17 TRs); this ADR narrows §9 provisional contracts
- `docs/architecture/ADR-0014-grid-battle-controller.md` — `is_tile_in_move_range` + `is_tile_in_attack_range` ratified here as InputRouter consumer surfaces
- `docs/architecture/ADR-0015-battle-hud.md` — 4 InputRouter integration surfaces ratified here (TPP callee + 2 GameBus subscribers + undo `_handle_event` caller exception)
- `docs/architecture/ADR-0019-ai-system.md` — most-recent precedent for combined-session escalation pattern + `_`-prefix discipline
- `production/epics/input-handling/EPIC.md` — 10-story epic + 6 mandatory verification items + same-patch obligations from ADR-0005 Acceptance
- `production/epics/input-handling/story-001-module-skeleton-and-autoload-registration.md` — sprint-8 S8-02 implementation target (uses this ADR's locked `_handle_event` stub signature)
- `production/sprints/sprint-8.md` §S8-01 + §R1 — sprint-8 plan that scoped this ADR
- `production/retrospectives/retro-sprint-7-2026-05-05.md` — sprint-7 retro identifying S7-10 PLACEHOLDER root cause + improvement #1 (pre-flight check policy)
- `src/foundation/input_router.gd` — current 33-line PLACEHOLDER (per file doc-comment); graduates at story-001 (S8-02)
- `src/feature/battle_hud/battle_hud.gd:19` — production-caller exception doc-comment that this ADR codifies
- `src/feature/grid_battle/grid_battle_controller.gd` — host of `is_tile_in_move_range` + `is_tile_in_attack_range` consumed by Phase 3
- `docs/registry/architecture.yaml` v13 — to be updated to v14 at /architecture-review delta #15 with 4 net-new forbidden_patterns
- `docs/architecture/tr-registry.yaml` v15 — to be updated to v16 at /architecture-review delta #15 with 4 net-new TR-input-handling-018..021 + 1 amended TR-input-handling-002

## Changelog

| Date | Change |
|------|--------|
| 2026-05-05 | Initial draft. Status: Proposed. Sprint-8 S8-01 deliverable. ADR narrows ADR-0005 §9 SOFT/PROVISIONAL contracts now that ADR-0014 (Grid Battle Controller, Accepted 2026-05-03) + ADR-0015 (Battle HUD, Accepted 2026-05-03) are downstream Accepted; locks `_handle_event` 4-phase dispatch sequence + sole-state-mutating-method invariant + caller allow-list + signal emit ordering invariant + 4 net-new forbidden_patterns (#5..#8 — total 8 with 4 carried from ADR-0005) + 4 net-new TR-input-handling-018..021 + 1 amended TR-002 (8-field count). 6th invocation of integration-narrowing pattern after ADR-0014/0015/0017/0018/0019. Authored fresh-session per same-session-ban discipline; ready for fresh-session `/architecture-review` for Accepted escalation via combined-session escalation pattern 5th invocation (delta #15) after deltas #11/#12/#13/#14. |
