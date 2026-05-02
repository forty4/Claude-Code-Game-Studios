# ADR-0015: Battle HUD — `BattleHUD` (Battle-scoped Control orchestrator for the player-facing battle surface)

## Status
Proposed (2026-05-03 — lean mode authoring + godot-specialist PASS WITH 3 REVISIONS resolved: revision #1 §3 `_exit_tree()` guard rationale comment added [`disconnect()` is safe in 4.x but guards retained for defensive hygiene]; revision #2 §4 `_handle_signal` `args: Array` rationale comment added [11 handlers heterogeneous arg shapes; typed array offers no additional safety]; revision #3 §6 `_process` `set_process(false)` gating option documented; TD-ADR PHASE-GATE skipped per `production/review-mode.txt`)

## Date
2026-05-03

## Last Verified
2026-05-03

## Decision Makers
- claude (lean mode authoring; no PHASE-GATE TD-ADR per `production/review-mode.txt`)

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | UI / Presentation (Control + CanvasLayer + signal subscription + cross-system state queries) |
| **Knowledge Risk** | **HIGH** — UI domain post-cutoff: (a) **4.6 dual-focus** (mouse/touch focus separate from keyboard/gamepad focus); (b) **4.5 AccessKit screen reader support** (auto-enabled on `Control` nodes; HUD inherits); (c) **4.5 recursive Control disable** (`MOUSE_FILTER_IGNORE` propagates through hierarchy); (d) **4.5 FoldableContainer** available but not used in MVP. APIs used: `Control` lifecycle (`_ready`, `_exit_tree`, `_gui_input`), `CanvasLayer.layer` int property, `Object.CONNECT_DEFERRED` for all GameBus subscriptions, `tr()` for i18n strings, `Tween` for fade animations, `set_anchors_preset(Control.PRESET_FULL_RECT)`, `Control.MOUSE_FILTER_IGNORE` recursive (4.5+ semantics), typed `Dictionary[K, V]` (4.4+ stable in 4.6), signal connect / disconnect, `is_equal_approx`. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md` (4.6 pin), `docs/engine-reference/godot/breaking-changes.md` (4.4/4.5/4.6 UI domain entries), `docs/engine-reference/godot/deprecated-apis.md` (no relevant entries), `docs/engine-reference/godot/modules/ui.md` (dual-focus + AccessKit + FoldableContainer + tr() best practice), `docs/engine-reference/godot/modules/input.md` (touch event flow), `design/ux/battle-hud.md` (744 lines — UI-GB-01..14 elements, 13 visual/audio specs, forecast contract, two-tap DEFEND/ATTACK flows, palette/accessibility), `design/gdd/grid-battle.md` (rules source — CR-12 signal emission obligation, formation_bonuses_updated provisional name, two-tap touch protocol), `design/gdd/game-concept.md` (Pillar 2 hidden semantic), `design/gdd/destiny-branch.md` (Pillar 2 sole consumer of hidden_fate_condition_progressed), `design/gdd/hp-status.md` (DEFEND_STANCE 1-turn duration), `design/gdd/turn-order.md` (initiative queue snapshot), `design/gdd/input-handling.md` (Touch Tap Preview Protocol CR-4a + Magnifier Panel CR-4c), `design/gdd/formation-bonus.md` (Formation Aura visual derivation), `design/ux/accessibility-requirements.md` (R-2 announcements + WCAG 1.4.11 contrast), `design/ux/interaction-patterns.md` (IP-006 redundancy triad + Beat-7 carve-out), `docs/architecture/ADR-0001-gamebus-autoload.md` (signal contract + CONNECT_DEFERRED mandate), `docs/architecture/ADR-0005-input-handling.md` (BattleHUD provisional contract lines 235-236 + InputRouter consumer pattern), `docs/architecture/ADR-0010-hp-status.md` (`get_current_hp/get_max_hp/get_status_effects` query API), `docs/architecture/ADR-0011-turn-order.md` (`get_turn_order_snapshot()` pull-based API + 4 emitted signals), `docs/architecture/ADR-0013-camera.md` (`get_zoom_value()` HUD scale-with-camera), `docs/architecture/ADR-0014-grid-battle-controller.md` (4 of 5 controller-LOCAL signals + 11+ field state read-only via `get_selected_unit_id` + battle-scoped Node precedent), `.claude/docs/technical-preferences.md` (44pt touch target + 60fps + 512MB mobile + tr() i18n). |
| **Post-Cutoff APIs Used** | (1) **`MOUSE_FILTER_IGNORE` recursive propagation** (4.5+) — used to disable HUD interaction during S5 INPUT_BLOCKED state via `mouse_filter = Control.MOUSE_FILTER_IGNORE` on the root; saves per-child mouse_filter state restoration. (2) **AccessKit auto-enabled** (4.5+) — `Control.tooltip_text` + `Control.focus_mode` automatically expose to screen readers; HUD authoring is responsible for setting these on every UI-GB-* element. (3) **Dual-focus split** (4.6) — `Control.grab_focus()` controls keyboard/gamepad focus only; mouse hover state is independent. HUD must NOT assume `grab_focus()` redirects mouse hover. (4) **Typed Dictionary** (4.4+ stable in 4.6) — `Dictionary[StringName, Control]` for UI element registry. |
| **Verification Required** | (1) **Dual-focus end-to-end (HIGH risk — 4.6)** — verify keyboard focus on UI-GB-02 action menu does NOT cancel mouse hover on UI-GB-04 forecast; player using mouse + keyboard simultaneously sees both feedback channels. Test on Pixel 7 (touch only) + macOS Metal (mouse + keyboard) + Linux Vulkan (mouse + keyboard + gamepad). KEEP through Polish. (2) **AccessKit screen reader announcement (HIGH risk — 4.5)** — UI-GB-01..14 elements expose `tooltip_text` + `accessibility_*` properties such that screen reader announces unit name + HP + status effects on focus change. Verify on macOS VoiceOver + Android TalkBack (post-MVP). (3) **44pt touch target enforcement (CRITICAL)** — every interactive Control on touch viewport ≥ 44×44pt minimum (per technical-preferences.md + accessibility-requirements.md). Static lint `tools/ci/lint_battle_hud_touch_target_size.sh` validates `custom_minimum_size.x ≥ 44 AND custom_minimum_size.y ≥ 44` on every Button/TextureButton/touch-receiving Control in `scenes/battle/battle_hud.tscn`. (4) **Forecast dismiss latency ≤ 80ms (AC-UX-HUD-02 from `design/ux/battle-hud.md`)** — verify on Pixel 7-class hardware (Adreno 610 / Mali-G57 reference) using `Performance.get_monitor(Performance.TIME_PROCESS) * 1000 < 80` instrumentation. (5) **Recursive `MOUSE_FILTER_IGNORE` propagation (4.5)** — verify setting `mouse_filter = MOUSE_FILTER_IGNORE` on the BattleHUD root disables ALL child Control interactions in one call (not per-child); regression test via integration test asserting Button.pressed signal does not emit while root is set IGNORE. (6) **`Object.CONNECT_DEFERRED` discipline** — all 11 GameBus subscriptions (4 ADR-0014 LOCAL + 4 cross-domain Turn Order/HP-Status + 2 InputRouter + 1 Grid Battle formation_bonuses_updated) use CONNECT_DEFERRED per ADR-0001 §5 mandate; static lint `tools/ci/lint_battle_hud_connect_deferred.sh` validates. (7) **`hidden_fate_condition_progressed` non-subscription enforcement (CRITICAL — Pillar 2 lock)** — static lint `tools/ci/lint_battle_hud_hidden_fate_non_subscription.sh` validates that `src/feature/battle_hud/battle_hud.gd` source code does NOT contain the literal token `hidden_fate_condition_progressed` (zero connect calls, zero references). Failure = Pillar 2 violation = build fail. KEEP forever (not just MVP). |

> **Knowledge Risk Note**: Domain is **HIGH** risk — the FIRST UI-domain ADR in the project after ADR-0005 InputRouter (also HIGH). Three post-cutoff items: (a) Godot 4.6 dual-focus, (b) Godot 4.5 AccessKit, (c) Godot 4.5 recursive Control disable. The `design/ux/battle-hud.md` UX spec (744 lines, v1.1) is the **authoring source-of-truth** for all 14 UI-GB-* elements; this ADR ratifies the *architectural form* (battle-scoped Control + DI + signal subscriptions + non-emitter discipline + Pillar 2 lock) without re-authoring the UX content. Future Godot 4.7+ that touches dual-focus semantics or AccessKit API would trigger Superseded-by review of this ADR's verification items.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | **ADR-0001 GameBus** (Accepted 2026-04-18) — BattleHUD is a **pure consumer** of 11 GameBus signals across 4 domains (Battle / Turn Order / HP/Status / Input) + 0 emissions (non-emitter discipline; codified as forbidden_pattern `battle_hud_signal_emission` below). All subscriptions use `Object.CONNECT_DEFERRED` per ADR-0001 §5 mandate. **ADR-0005 InputRouter** (Accepted 2026-04-30) — ratifies the BattleHUD provisional contract from ADR-0005 lines 235-236: `BattleHUD.show_unit_info(unit_id: int) -> void` + `BattleHUD.show_tile_info(coord: Vector2i) -> void` for Touch Tap Preview Protocol (CR-4a). Also ratifies the consumer subscription to `input_state_changed(from: int, to: int)` + `input_mode_changed(new_mode: int)` for contextual UI updates + hint icon mode swap. **ADR-0010 HPStatusController** (Accepted 2026-05-02) — DI dependency; HUD reads `get_current_hp(unit_id) / get_max_hp(unit_id) / get_status_effects(unit_id)` for HP bar (UI-GB-03) + status icon rendering (UI-GB-11 守 seal). Subscribes to `unit_died(unit_id)` for UI-GB-09 results screen + UI-GB-01 queue update. **ADR-0011 TurnOrderRunner** (Accepted 2026-05-02) — DI dependency; HUD reads `get_turn_order_snapshot()` pull-based on receipt of `round_started` / `unit_turn_started` / `unit_turn_ended` / `unit_died` signals per registry line 635 + ADR-0011 emitted signal contract. **ADR-0013 BattleCamera** (Accepted 2026-05-02) — DI dependency; HUD reads `get_zoom_value() -> float` for UI scale-with-camera per ADR-0013 line 239 (HUD elements counter-scale to remain readable as zoom changes; verified via per-frame `_process` poll OR zoom-event signal subscription — implementation-time choice deferred to first story per OQ-1 below). **ADR-0014 GridBattleController** (Accepted 2026-05-02) — DI dependency; HUD subscribes to **4 of 5** controller-LOCAL signals: `unit_selected_changed(unit_id, was_selected)` (UI-GB-02 action menu show/hide), `unit_moved(unit_id, from, to)` (UI-GB-10 undo indicator + tile state refresh), `damage_applied(attacker_id, defender_id, damage)` (UI-GB-04 forecast dismiss + 2.5 hit/miss feedback trigger), `battle_outcome_resolved(outcome, fate_data)` (UI-GB-09 end-of-battle results screen). **EXPLICITLY NOT** the 5th signal `hidden_fate_condition_progressed(condition_id, value)` per ADR-0014 line 335 + Pillar 2 hidden semantic preservation; codified as forbidden_pattern + CI lint (Verification §7). HUD also reads `get_selected_unit_id() -> int` for UI-GB-02 action menu binding per registry line 729. **ADR-0006 BalanceConstants** (Accepted 2026-04-30) — 1 new BalanceConstants entry: `FORECAST_RENDER_BUDGET_MS = 120` (per `design/ux/battle-hud.md` §10 Tuning Knobs); HUD reads via `BalanceConstants.get_const(&"FORECAST_RENDER_BUDGET_MS") -> int`. **ADR-0004 MapGrid** (Accepted 2026-04-20) — DI dependency; HUD reads `get_tile(coord) -> TileData` for UI-GB-06 tile info tooltip (terrain type, elevation, defense bonus, evasion bonus per battle-hud.md §3 UI-GB-06). **ADR-0008 TerrainEffect** (Accepted 2026-04-25) — DI dependency; HUD reads `TerrainEffect.get_modifier(...)` for UI-GB-06 tooltip terrain modifier display. **ADR-0009 UnitRole** (Accepted 2026-04-30) — DI dependency; HUD reads `UnitRole.get_max_hp(...)` + class-based stat queries for UI-GB-03 unit info panel. **ADR-0007 HeroDatabase** (Accepted 2026-04-30) — DI dependency; HUD reads `HeroDatabase.get_hero(hero_id)` for UI-GB-03 unit name + portrait reference. |
| **Soft / Provisional** | (1) **Battle Scene wiring (sprint-6 — soft / provisional downstream)**: `BattleScene` `.tscn` mount point creates `BattleHUD` as `CanvasLayer/BattleHUD` (Control) child; calls `BattleHUD.setup(...)` BEFORE `add_child()`; manages `_exit_tree()` lifecycle. Battle Scene wiring ADR ratifies the mount point + DI sequence verbatim from this ADR §3 below. (2) **Future `hp_status_changed` signal (post-MVP — soft / provisional upstream)**: ADR-0010 line 207 deferred OQ-3 ("Battle HUD polls get_status_effects() per frame OR subscribes to a future hp_status_changed signal in Battle HUD ADR"). MVP decision: HUD POLLS via `_process` ONLY when `_active_status_panel_unit_id != -1` (i.e., a unit info panel is open); polling cost is O(1) Dictionary lookup. Future ADR-0010 amendment may add `hp_status_changed(unit_id)` signal — additive change, HUD subscription is non-breaking. (3) **Animation curve / VFX values authoring**: this ADR codifies the architectural form; specific values (fade durations, ink-wash colors, animation curves) are owned by `design/ux/battle-hud.md` §2 + §6. Implementation-time art-director sign-off required per `design/ux/accessibility-requirements.md` §4 contrast verification. (4) **Save/restore HUD state**: NOT supported in MVP. Battle restart re-initializes HUD state. Future post-MVP save format may include HUD persistence but is out of scope here. |
| **Enables** | (1) **battle-hud Feature epic** (sprint-5 S5-13 — `/create-stories battle-hud` after this ADR is Accepted; estimated 5-8 stories per sprint-5 plan); (2) **Battle Scene wiring** (sprint-6 — Battle Scene mounts `BattleHUD` as `CanvasLayer/BattleHUD` child of BattleScene root; first scene that USES the controller-LOCAL signals shipped sprint-5); (3) **Closes ADR-0005 BattleHUD provisional contract** (lines 235-236) — provisional → ratified; (4) **Closes ADR-0010 HUD HP/Status query provisional contract** (line 43 #4) — provisional → ratified; (5) **Closes ADR-0011 HUD turn-order pull-based query provisional contract** (registry line 635) — provisional → ratified; (6) **Closes ADR-0013 HUD `get_zoom_value()` consumer provisional contract** (line 33 #3) — provisional → ratified; (7) **Closes ADR-0014 HUD signal subscription provisional contract** (registry line 712 + line 729) — provisional → ratified with 4 of 5 signals subscribed (5th explicitly forbidden per Pillar 2 lock); (8) **Unblocks Scenario Progression ADR (NOT YET WRITTEN — sprint-6)** — Scenario Progression subscribes to `battle_outcome_resolved`; HUD ALSO subscribes (UI-GB-09 results screen) but does so independently — no cross-coupling between ADRs. |
| **Blocks** | battle-hud Feature epic implementation (cannot start any story until this ADR is Accepted); `scenes/battle/battle_hud.tscn` scene file authoring + the 14 UI-GB-* element layouts; sprint-6 Battle Scene wiring (Battle Scene cannot mount HUD without this ADR's `setup(...)` signature contract); first user-visible-surface battle ship date. |
| **Ordering Note** | **5th invocation** of battle-scoped Node pattern after ADR-0010 HPStatusController + ADR-0011 TurnOrderRunner + ADR-0013 BattleCamera + ADR-0014 GridBattleController. **First Presentation-layer ADR** in the project — bridges Foundation (InputRouter) + Core (HP/Status, Turn Order) + Feature (Camera, GridBattleController) layers into a single player-facing surface. Pattern stable at 5 invocations; **future presentation-layer Nodes** (Battle Results screen, Tutorial overlay, Pause menu within battle) should follow the same DI + `_exit_tree()` discipline + non-emitter pattern + AccessKit-via-Control inheritance. |

## Context

### Problem Statement

After ADR-0014 GridBattleController shipped sprint-5 (10/10 epic Complete 2026-05-03) emitting 5 controller-LOCAL signals, the MVP First Chapter (sprint-5..7 arc) needs the **player-facing surface** that:

1. **Renders the 14 UI-GB-* elements** authored in `design/ux/battle-hud.md` v1.1 (initiative queue, action menu, unit info panel, combat forecast, skill list, tile info tooltip, turn/round counter, victory condition display, end-of-battle results screen, undo indicator, DEFEND stance badge, TacticalRead extended range, Rally aura visual, Formation aura visual).
2. **Consumes 4 of 5 GridBattleController controller-LOCAL signals** (per ADR-0014 §8 line 335 + Pillar 2 hidden semantic preservation): `unit_selected_changed`, `unit_moved`, `damage_applied`, `battle_outcome_resolved`. **Explicitly does NOT subscribe** to `hidden_fate_condition_progressed` — Destiny Branch is the sole consumer per ADR-0014 line 335 + game-concept.md Pillar 2 + destiny-branch.md.
3. **Consumes cross-domain signals** for state-driven UI updates: `unit_died` (HP/Status emit), `unit_turn_started` / `unit_turn_ended` / `round_started` (Turn Order emits per ADR-0011 line 643), `input_state_changed` / `input_mode_changed` (InputRouter emits per ADR-0005), `formation_bonuses_updated` (Grid Battle emits per CR-12 / UI-GB-14).
4. **Reads state** from 8 DI'd backends via direct method calls: `BattleCamera.get_zoom_value`, `HPStatusController.get_current_hp/get_max_hp/get_status_effects`, `TurnOrderRunner.get_turn_order_snapshot`, `GridBattleController.get_selected_unit_id`, `InputRouter.get_active_input_mode`, `MapGrid.get_tile`, `TerrainEffect.get_modifier`, `UnitRole.get_max_hp`, `HeroDatabase.get_hero`.
5. **Honors the InputRouter Touch Tap Preview Protocol** (per ADR-0005 lines 235-236): exposes `show_unit_info(unit_id: int) -> void` + `show_tile_info(coord: Vector2i) -> void` for InputRouter to invoke on tap-preview.
6. **Emits zero GameBus signals** — pure consumer + state-reader (non-emitter discipline; codified as forbidden_pattern below).
7. **Locks Pillar 2 hidden semantic preservation** — via dedicated forbidden_pattern + CI lint asserting `hidden_fate_condition_progressed` is NEVER subscribed by HUD source code (build-fail enforcement, not just convention).
8. **Survives Godot 4.6 UI domain HIGH risk** — dual-focus, AccessKit, recursive Control disable, typed Dictionary all verified against engine reference docs.

### Why MVP-scoped (the explicit deferral)

`design/ux/battle-hud.md` is **744 lines** with full authoring scope: 14 UI-GB-* element specs + 13 visual/audio specs (movement range highlight, attack range highlight, path preview, attack direction indicator, hit/miss feedback, etc.) + forecast contract (UI-GB-04) + two-tap ATTACK/DEFEND mobile flows + palette/accessibility + 6 acceptance criteria + 5 Open Questions. A faithful ADR covering all 14 elements + 13 visual specs + forecast formula derivations + i18n key registry + animation timing curves would be 1000+ LoC and 4-6h of work — beyond sprint-5 S5-12 capacity (estimated 0.4d per sprint-5 plan).

**This ADR's scope**: ratify the **architectural form** (module type, lifecycle, signal subscription pattern, DI signature, public API surface, non-emitter discipline, Pillar 2 lock, performance budget, engine compatibility) without re-authoring the UX content. The UX spec `design/ux/battle-hud.md` v1.1 remains the **authoring source-of-truth** for all per-element visual/audio specs; this ADR commits the implementation will faithfully render those specs. Story-level deviations (e.g., a UI-GB-* element's specific Control subclass choice, anchor preset, theme override) are **implementation freedom** within the contract surface ratified here.

When the battle-hud Feature epic ships sprint-6+, this ADR is **amended** (additive — new signal subscriptions if a future ADR adds emitters, new helper methods) or **superseded by** a successor ADR (for fundamental architecture changes like splitting HUD into per-element controllers).

### Constraints

1. **Battle-scoped lifecycle** — HUD lives only during BattleScene; freed automatically with BattleScene per ADR-0002 SceneManager teardown. Mirrors HPStatusController + TurnOrderRunner + BattleCamera + GridBattleController battle-scoped Node precedent (4 prior invocations).
2. **GameBus signal contract** — all subscriptions must use `Object.CONNECT_DEFERRED` per ADR-0001 §5; HUD must explicitly disconnect in `_exit_tree()` to prevent SOURCE-outlives-TARGET leak (TD-057 retrofit pattern from story-009).
3. **Non-emitter discipline** — HUD does NOT add new GameBus signals (forbidden_pattern below). Cross-system communication FROM HUD goes through method calls on DI'd backends or back through InputRouter (e.g., the Undo button click invokes `InputRouter._handle_event(...)` synthetic event; HUD does not emit `undo_requested` itself).
4. **Pillar 2 hidden semantic preservation** — `hidden_fate_condition_progressed` MUST NEVER be subscribed by HUD source code. CI lint enforces (Verification §7). This is a CORE constraint, not a stylistic preference.
5. **Performance budget** — `< 1.0ms` per frame steady-state HUD update (HP bar + initiative queue + status badges via signal handlers, NOT per-frame poll). Forecast burst budget `≤ 120ms` per UI-GB-04 `FORECAST_RENDER_BUDGET_MS` knob (one-shot render on attack-target-hover; not per-frame).
6. **Touch parity** — every interactive element ≥ 44×44pt minimum on touch viewport (technical-preferences.md). No hover-only interactions. Two-tap ATTACK/DEFEND model (UX-spec §5).
7. **i18n via `tr()`** — all visible strings use `tr(key)` per `design/ux/battle-hud.md` + technical-preferences.md UI rule. No hardcoded localized strings in `.gd` files.
8. **Cross-platform determinism** — HUD signal handlers + state queries must produce identical UI state across macOS Metal + Linux Vulkan + Windows D3D12 + Android Vulkan + iOS Metal. No platform-specific code paths in HUD logic.
9. **Test infrastructure** — DI seam pattern (mirroring ADR-0014's 8-param `setup`); HUD tests use mock signal sources + stub backends (extend existing `tests/helpers/turn_order_runner_stub.gd` pattern).

### Requirements

- **R-1**: BattleHUD class is `class_name BattleHUD extends Control` with `class_name BattleHUD` PascalCase; mounted as `CanvasLayer/BattleHUD` child of BattleScene root in `scenes/battle/battle_hud.tscn` (CanvasLayer wraps the Control to enforce HUD-on-top render order independent of camera transform).
- **R-2**: DI seam: `setup(camera: BattleCamera, hp_controller: HPStatusController, turn_runner: TurnOrderRunner, grid_controller: GridBattleController, input_router: InputRouter, map_grid: MapGrid, terrain_effect: TerrainEffect, unit_role: UnitRole, hero_db: HeroDatabase) -> void` — 9-param call BEFORE `add_child()`; `_ready()` asserts non-null on all 9 backend deps + connects all 11 GameBus subscriptions.
- **R-3**: Subscribes to **exactly 11 GameBus signals** with `CONNECT_DEFERRED`:
  - 4 from ADR-0014 GridBattleController: `unit_selected_changed` / `unit_moved` / `damage_applied` / `battle_outcome_resolved`
  - 1 from ADR-0010 HPStatusController: `unit_died`
  - 3 from ADR-0011 TurnOrderRunner: `round_started` / `unit_turn_started` / `unit_turn_ended`
  - 2 from ADR-0005 InputRouter: `input_state_changed` / `input_mode_changed`
  - 1 from ADR-0014 GridBattleController (Formation Bonus path): `formation_bonuses_updated`
- **R-4**: Does NOT subscribe to `hidden_fate_condition_progressed` — Pillar 2 lock; CI lint enforces (Verification §7).
- **R-5**: Emits zero GameBus signals — non-emitter discipline; forbidden_pattern `battle_hud_signal_emission` codified.
- **R-6**: Public API: `show_unit_info(unit_id: int) -> void` + `show_tile_info(coord: Vector2i) -> void` (InputRouter Tap Preview Protocol per ADR-0005 lines 235-236); plus `_handle_signal(signal_name: StringName, args: Array)` test seam (mirrors ADR-0014 + ADR-0005 DI test seam pattern).
- **R-7**: `_exit_tree()` MANDATORY — disconnects all 11 GameBus subscriptions explicitly; matches ADR-0013 R-6 + ADR-0014 R-4 + TD-057 retrofit pattern.
- **R-8**: Touch target enforcement: every interactive Control `custom_minimum_size.x ≥ 44 AND custom_minimum_size.y ≥ 44` on touch viewport; CI lint enforces (Verification §3).
- **R-9**: Forecast dismiss latency ≤ 80ms (AC-UX-HUD-02); HP bar update ≤ 16ms (1 frame); initiative queue rebuild ≤ 16ms (1 frame).
- **R-10**: All visible strings via `tr()`; no hardcoded localized strings (i18n parity).

## Decision

**Lock BattleHUD as a battle-scoped `Control` Node mounted under a `CanvasLayer` in BattleScene** (created on battle-init via Battle Scene wiring, freed automatically with BattleScene per ADR-0002). It owns 14 UI-GB-* element references via `Dictionary[StringName, Control]`, exposes 2 public methods (`show_unit_info` + `show_tile_info`), emits **zero** GameBus signals, consumes **11** GameBus signals via `CONNECT_DEFERRED`, reads state from 9 DI'd backends, enforces Pillar 2 hidden-fate non-subscription via static lint, and routes the 1 new tuning knob (`FORECAST_RENDER_BUDGET_MS`) through `BalanceConstants.get_const`.

### §1. Module Form — Battle-scoped Control under CanvasLayer

```gdscript
class_name BattleHUD extends Control

# Battle-scoped Node — created at BattleScene mount, freed automatically
# with BattleScene per ADR-0002. Mirrors HPStatusController + TurnOrderRunner +
# BattleCamera + GridBattleController battle-scoped Node precedent (5th invocation).
#
# Mounted as CanvasLayer/BattleHUD child of BattleScene root via
# scenes/battle/battle_hud.tscn — CanvasLayer wraps the Control to enforce
# HUD-on-top render order independent of camera transform.
#
# Set anchors_preset = PRESET_FULL_RECT on root Control so HUD covers the
# full viewport; child Controls use individual anchors per battle-hud.md §3
# layout spec.
```

**Rejected**: stateless-static (HUD has lifecycle + signal subscriptions; same justification as ADR-0010 §1 + ADR-0013 §1 + ADR-0014 §1 — battle-scoped Node form is the only viable shape for systems that LISTEN to events). Autoload (HUD is battle-scoped, not cross-scene survival; main menu has no HUD; mirrors BattleCamera rejection of autoload form). Multiple-controllers-without-wrapper (rejected per Alternative 3 below — 14 UI-GB-* elements need a coordinator for show/hide/anchor logic + DI fan-out).

### §2. Layout Structure — `CanvasLayer` parent, `Control` self, 14 UI-GB-* children

```
scenes/battle/battle_scene.tscn
└── BattleScene (Node2D)
    ├── BattleCamera (Camera2D — ADR-0013)
    ├── GridBattleController (Node — ADR-0014)
    ├── ... (other backend Nodes)
    └── HUDLayer (CanvasLayer, layer = 1)
        └── BattleHUD (Control, anchors_preset = PRESET_FULL_RECT)
            ├── UI-GB-01: InitiativeQueue (HBoxContainer / VBoxContainer)
            ├── UI-GB-02: ActionMenu (PanelContainer)
            ├── UI-GB-03: UnitInfoPanel (PanelContainer)
            ├── UI-GB-04: CombatForecast (PanelContainer + Tween)
            ├── UI-GB-05: SkillList (sub-panel, parented under ActionMenu)
            ├── UI-GB-06: TileInfoTooltip (PanelContainer)
            ├── UI-GB-07: TurnRoundCounter (Label)
            ├── UI-GB-08: VictoryConditionDisplay (Label)
            ├── UI-GB-09: EndOfBattleResults (PanelContainer + ColorRect overlay)
            ├── UI-GB-10: UndoIndicator (Button)
            ├── UI-GB-11: DefendStanceBadge (TextureRect + AnimationPlayer)
            ├── UI-GB-12: TacticalReadExtendedRange (Node2D overlay child of grid layer — NOT direct HUD child but coordinated via formation_bonuses_updated handler)
            ├── UI-GB-13: RallyAuraVisual (Node2D overlay — same pattern as UI-GB-12)
            └── UI-GB-14: FormationAuraVisual (Node2D overlay — same pattern)
```

**Note on UI-GB-12/13/14**: these three are **grid-layer overlays** (rendered at the world-space tile layer) rather than HUD-screen-space children. They are coordinated by BattleHUD's signal handlers (which receive `formation_bonuses_updated` and dispatch render commands to the overlays) but the overlay Nodes themselves are mounted under `BattleScene/GridLayer`, not `BattleScene/HUDLayer/BattleHUD`. This is per `design/ux/battle-hud.md` §3 UI-GB-14 spec and §3 UI-GB-12/13 specs which place the visuals at the tile layer. The HUD class therefore holds REFERENCES to these overlay Nodes (via `@export NodePath`) but does not own their lifetime. **Implementation freedom**: the first story may consolidate UI-GB-12/13/14 into BattleHUD as Control overlays via Camera2D-aware position tracking — that would eliminate the cross-tree NodePath dance. Decision deferred to first story per OQ-2 below.

### §3. DI Setup — `setup(...)` 9-Param Call

```gdscript
# Called BY BattleScene wiring BEFORE add_child() — mirrors ADR-0014 8-param + ADR-0013 1-param pattern
func setup(
    camera: BattleCamera,
    hp_controller: HPStatusController,
    turn_runner: TurnOrderRunner,
    grid_controller: GridBattleController,
    input_router: InputRouter,
    map_grid: MapGrid,
    terrain_effect: TerrainEffect,
    unit_role: UnitRole,
    hero_db: HeroDatabase
) -> void:
    _camera = camera
    _hp_controller = hp_controller
    _turn_runner = turn_runner
    _grid_controller = grid_controller
    _input_router = input_router
    _map_grid = map_grid
    _terrain_effect = terrain_effect
    _unit_role = unit_role
    _hero_db = hero_db

func _ready() -> void:
    # Assert DI happened before add_child()
    assert(_camera != null, "BattleHUD: camera DI required before add_child")
    assert(_hp_controller != null, "BattleHUD: hp_controller DI required")
    assert(_turn_runner != null, "BattleHUD: turn_runner DI required")
    assert(_grid_controller != null, "BattleHUD: grid_controller DI required")
    assert(_input_router != null, "BattleHUD: input_router DI required")
    assert(_map_grid != null, "BattleHUD: map_grid DI required")
    assert(_terrain_effect != null, "BattleHUD: terrain_effect DI required")
    assert(_unit_role != null, "BattleHUD: unit_role DI required")
    assert(_hero_db != null, "BattleHUD: hero_db DI required")

    # 11 GameBus subscriptions — all CONNECT_DEFERRED per ADR-0001 §5
    GameBus.unit_selected_changed.connect(_on_unit_selected_changed, Object.CONNECT_DEFERRED)
    GameBus.unit_moved.connect(_on_unit_moved, Object.CONNECT_DEFERRED)
    GameBus.damage_applied.connect(_on_damage_applied, Object.CONNECT_DEFERRED)
    GameBus.battle_outcome_resolved.connect(_on_battle_outcome_resolved, Object.CONNECT_DEFERRED)
    GameBus.unit_died.connect(_on_unit_died, Object.CONNECT_DEFERRED)
    GameBus.round_started.connect(_on_round_started, Object.CONNECT_DEFERRED)
    GameBus.unit_turn_started.connect(_on_unit_turn_started, Object.CONNECT_DEFERRED)
    GameBus.unit_turn_ended.connect(_on_unit_turn_ended, Object.CONNECT_DEFERRED)
    GameBus.input_state_changed.connect(_on_input_state_changed, Object.CONNECT_DEFERRED)
    GameBus.input_mode_changed.connect(_on_input_mode_changed, Object.CONNECT_DEFERRED)
    GameBus.formation_bonuses_updated.connect(_on_formation_bonuses_updated, Object.CONNECT_DEFERRED)

    # Anchors + initial visibility setup (children hidden until first signal)
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _initialize_ui_element_visibility()

func _exit_tree() -> void:
    # MANDATORY — TD-057 retrofit pattern (story-009) + ADR-0013 R-6 + ADR-0014 R-4
    # Disconnect all 11 GameBus subscriptions to prevent SOURCE-outlives-TARGET leak.
    #
    # NOTE on guards: Godot 4.x `Signal.disconnect(callable)` is a safe no-op when
    # the callable is not connected — guards are NOT a correctness requirement.
    # We retain them for defensive hygiene (avoids benign one-time debug-build
    # error when called before _ready() subscribed) + reads cleanly. The TD-057
    # motivation was the disconnect call itself, not the guard pattern.
    if GameBus.unit_selected_changed.is_connected(_on_unit_selected_changed):
        GameBus.unit_selected_changed.disconnect(_on_unit_selected_changed)
    if GameBus.unit_moved.is_connected(_on_unit_moved):
        GameBus.unit_moved.disconnect(_on_unit_moved)
    if GameBus.damage_applied.is_connected(_on_damage_applied):
        GameBus.damage_applied.disconnect(_on_damage_applied)
    if GameBus.battle_outcome_resolved.is_connected(_on_battle_outcome_resolved):
        GameBus.battle_outcome_resolved.disconnect(_on_battle_outcome_resolved)
    if GameBus.unit_died.is_connected(_on_unit_died):
        GameBus.unit_died.disconnect(_on_unit_died)
    if GameBus.round_started.is_connected(_on_round_started):
        GameBus.round_started.disconnect(_on_round_started)
    if GameBus.unit_turn_started.is_connected(_on_unit_turn_started):
        GameBus.unit_turn_started.disconnect(_on_unit_turn_started)
    if GameBus.unit_turn_ended.is_connected(_on_unit_turn_ended):
        GameBus.unit_turn_ended.disconnect(_on_unit_turn_ended)
    if GameBus.input_state_changed.is_connected(_on_input_state_changed):
        GameBus.input_state_changed.disconnect(_on_input_state_changed)
    if GameBus.input_mode_changed.is_connected(_on_input_mode_changed):
        GameBus.input_mode_changed.disconnect(_on_input_mode_changed)
    if GameBus.formation_bonuses_updated.is_connected(_on_formation_bonuses_updated):
        GameBus.formation_bonuses_updated.disconnect(_on_formation_bonuses_updated)
```

### §4. Public API Surface — 2 Methods + Test Seam

```gdscript
# InputRouter Tap Preview Protocol (CR-4a) — invoked BY InputRouter, NOT player code
func show_unit_info(unit_id: int) -> void:
    """Renders UI-GB-03 unit info panel for unit_id. Called by InputRouter on touch tap-preview
    (CR-4a). PC mouse hover routes through the same path. If unit_id == -1, dismisses the panel."""

func show_tile_info(coord: Vector2i) -> void:
    """Renders UI-GB-06 tile info tooltip for coord. Called by InputRouter on touch tap-preview
    (CR-4a) OR PC mouse hover on empty tile. If coord == Vector2i(-1, -1), dismisses the tooltip."""

# Test seam — direct signal-handler invocation bypasses GameBus subscription infrastructure
# `args: Array` is intentionally untyped — 11 handlers have heterogeneous arg shapes
# (mix of int, Vector2i, StringName, Dictionary). `Array[Variant]` would offer no
# additional type safety over `Array` here, and would require Variant unwrap at every
# index access. Per-handler call sites cast/index args directly per their known shape.
func _handle_signal(signal_name: StringName, args: Array) -> void:
    """Dispatch test signal directly to handlers. Production callers MUST go through GameBus —
    this seam exists ONLY for unit tests (mirrors ADR-0014 + ADR-0005 + ADR-0010 DI test seam pattern)."""
    match signal_name:
        &"unit_selected_changed":
            _on_unit_selected_changed(args[0], args[1])
        &"unit_moved":
            _on_unit_moved(args[0], args[1], args[2])
        &"damage_applied":
            _on_damage_applied(args[0], args[1], args[2])
        # ... (8 more)
        _:
            push_error("BattleHUD._handle_signal: unknown signal %s" % signal_name)
```

### §5. Signal Handlers — 11 Subscriptions, Zero Emissions

```gdscript
# From ADR-0014 GridBattleController (4 of 5 controller-LOCAL signals — Pillar 2 excludes the 5th)
func _on_unit_selected_changed(unit_id: int, was_selected: int) -> void:
    """UI-GB-02 ActionMenu show/hide; UI-GB-03 UnitInfoPanel populate."""

func _on_unit_moved(unit_id: int, from: Vector2i, to: Vector2i) -> void:
    """UI-GB-10 UndoIndicator show; tile state refresh on grid overlays."""

func _on_damage_applied(attacker_id: int, defender_id: int, damage: int) -> void:
    """UI-GB-04 CombatForecast dismiss (≤ 80ms per AC-UX-HUD-02); §2.5 hit/miss feedback trigger;
    UI-GB-03 UnitInfoPanel HP bar refresh via _hp_controller.get_current_hp(defender_id)."""

func _on_battle_outcome_resolved(outcome: StringName, fate_data: Dictionary) -> void:
    """UI-GB-09 EndOfBattleResults render. fate_data Dictionary keys per ADR-0014 §8 (boss_killed
    / tank_hp_pct / formation_turns / assassin_kills / rear_attacks). HUD displays surviving
    units + turns elapsed + outcome label; does NOT display the fate counters individually
    (preserves Pillar 2 hidden semantic — fate counters are surfaced only via reserved-color
    branches at Beat 7 per destiny-branch.md, not at Beat 6 results screen)."""

# From ADR-0010 HPStatusController
func _on_unit_died(unit_id: int) -> void:
    """UI-GB-01 InitiativeQueue rebuild via _turn_runner.get_turn_order_snapshot();
    UI-GB-09 EndOfBattleResults check (in case last enemy unit died)."""

# From ADR-0011 TurnOrderRunner
func _on_round_started(round_number: int) -> void:
    """UI-GB-07 TurnRoundCounter update; UI-GB-04 forecast force-dismiss."""

func _on_unit_turn_started(unit_id: int) -> void:
    """UI-GB-02 ActionMenu refresh (only show for player units); UI-GB-11 DefendStanceBadge
    expiry check via _hp_controller.get_status_effects(unit_id)."""

func _on_unit_turn_ended(unit_id: int) -> void:
    """UI-GB-01 InitiativeQueue advance via _turn_runner.get_turn_order_snapshot()."""

# From ADR-0005 InputRouter
func _on_input_state_changed(from_state: int, to_state: int) -> void:
    """Recursive Control disable when entering S5 INPUT_BLOCKED — set
    self.mouse_filter = Control.MOUSE_FILTER_IGNORE (4.5+ recursive propagation per
    docs/engine-reference/godot/modules/ui.md). Restore to MOUSE_FILTER_STOP on exit."""

func _on_input_mode_changed(new_mode: int) -> void:
    """Hint icon swap — KEYBOARD_MOUSE → keyboard glyph; TOUCH → finger glyph
    (per ADR-0005 line 451 + battle-hud.md §3 hint icon spec)."""

# From ADR-0014 GridBattleController (Formation Bonus path — UI-GB-14)
func _on_formation_bonuses_updated(snapshot: Dictionary) -> void:
    """UI-GB-14 FormationAuraVisual render; UI-GB-13 RallyAuraVisual render
    (per battle-hud.md §3.1 UI-GB-14 detailed spec + UI-GB-13 spec)."""
```

### §6. UI Scale-with-Camera — Per-Frame Poll on Selected Element ONLY

```gdscript
func _process(delta: float) -> void:
    """Poll camera zoom ONLY when UI-GB-12/13/14 grid-layer overlays are active
    (those need world-space → screen-space conversion that depends on zoom).
    HUD screen-space elements (UI-GB-01..11) don't need per-frame zoom poll —
    they're independent of camera transform via CanvasLayer."""
    if _has_active_grid_overlay():
        var current_zoom: float = _camera.get_zoom_value()
        if not is_equal_approx(current_zoom, _last_zoom):
            _refresh_grid_overlay_positions(current_zoom)
            _last_zoom = current_zoom
```

**Performance**: zoom-poll cost is O(1) — single `get_zoom_value()` call + 1 float comparison + conditional refresh. Steady-state (no zoom change): negligible. Refresh path (zoom change frame): O(N) where N = number of active grid overlays (typically ≤ 8 — Rally aura on 2-3 commanders + Formation aura on 4-6 units).

**Implementation freedom — `set_process(false)` gating**: per Godot best practice, `_process` should be disabled when not needed. Implementation may use `set_process(false)` in `_ready()` and re-enable on overlay-active transitions (`set_process(true)` when first grid overlay appears; `set_process(false)` when last grid overlay disappears) for strict per-Godot-best-practice compliance. The early-return gate via `_has_active_grid_overlay()` is functionally equivalent and acceptable; the choice is implementation-time. Both approaches eliminate per-frame CPU when no grid overlays are active.

### §7. Tuning Knobs — 1 New BalanceConstants Entry

| Knob | Default | Range | Description |
|------|---------|-------|-------------|
| `FORECAST_RENDER_BUDGET_MS` | 120 | 80–200 | UI-GB-04 forecast frame-time budget burst limit (per `design/ux/battle-hud.md` §10). Below 80: device-specific failures. Above 200: forecast feels laggy; Pillar 1 reading flow degrades. |

Loaded via `BalanceConstants.get_const(&"FORECAST_RENDER_BUDGET_MS") -> int` per ADR-0006 pattern. Same-patch obligation: `assets/data/balance/balance_entities.json` adds the key + value at first story implementation.

### §8. Pillar 2 Hidden Semantic Preservation — Forbidden Pattern + CI Lint

**Architectural lock**: HUD source code MUST NEVER contain `hidden_fate_condition_progressed` — neither as connect call, nor as variable name, nor as comment-out. Codified as forbidden_pattern + CI lint:

```bash
# tools/ci/lint_battle_hud_hidden_fate_non_subscription.sh
if grep -q "hidden_fate_condition_progressed" src/feature/battle_hud/battle_hud.gd; then
    echo "FAIL: BattleHUD source contains hidden_fate_condition_progressed (Pillar 2 lock)"
    echo "Per ADR-0015 §8 + ADR-0014 line 335 + design/gdd/destiny-branch.md, Battle HUD"
    echo "MUST NOT subscribe to this signal — Destiny Branch is sole consumer."
    exit 1
fi
```

This complements the ADR-0014 story-008 test obligation that asserts `hidden_fate_condition_progressed.get_connections().size() == 0` on fresh controller. Together they form a 3-layer Pillar 2 enforcement:
1. **Test layer** (story-008): connection count assertion on controller signal channel
2. **Source layer** (this ADR §8 lint): grep-based zero-occurrence assertion on HUD source
3. **Architecture layer** (this ADR forbidden_pattern): registry entry blocks future ADRs from adding HUD subscription

If a future Battle HUD designer believes they need to surface fate progress to the player, they MUST first revise this ADR (Superseded-by) AND `design/gdd/destiny-branch.md` Section B (which explicitly mandates wordlessness) AND `design/gdd/game-concept.md` Pillar 2. Three coordinated revisions are intentionally hard to do — the lock is meant to outlast individual designer impulses.

### §9. Architecture Diagram

```
                    ┌─────────────────────────────────────┐
                    │  BattleScene (Node2D)               │
                    │  ├── BattleCamera (ADR-0013)        │
                    │  ├── GridBattleController (ADR-0014)│
                    │  ├── HPStatusController (ADR-0010)  │
                    │  ├── TurnOrderRunner (ADR-0011)     │
                    │  ├── ... (other backends)           │
                    │  └── HUDLayer (CanvasLayer, layer=1)│
                    │      └── BattleHUD ← THIS ADR       │
                    └─────────────────────────────────────┘
                                    │
                    DI'd backends (read-only state queries)
                                    │
            ┌────────────┬──────────┼──────────┬──────────┬──────────┐
            ▼            ▼          ▼          ▼          ▼          ▼
        BattleCamera HPStatus  TurnOrder   Grid     InputRouter MapGrid
        get_zoom_value get_current_hp get_turn_order_snapshot get_active_input_mode
                                    │
                       11 GameBus signal subscriptions (CONNECT_DEFERRED)
                                    │
            ┌─────────────────────┐ │ ┌──────────────────────────────┐
            │ unit_selected_changed │ │ │ unit_died                  │
            │ unit_moved            │ │ │ round_started              │
            │ damage_applied        │ │ │ unit_turn_started          │
            │ battle_outcome_resolved│ │ │ unit_turn_ended            │
            │ formation_bonuses_updated│ │ input_state_changed       │
            │ (5th NOT subscribed:  │ │ │ input_mode_changed         │
            │  hidden_fate_*  ←     │ │ └──────────────────────────────┘
            │  Pillar 2 lock)       │ │
            └─────────────────────┘ │
                                    │
                        Renders 14 UI-GB-* elements
                                    │
            ┌────────────┬──────────┼──────────┬──────────┐
            ▼            ▼          ▼          ▼          ▼
         InitQueue   ActionMenu  UnitInfo  Forecast  EndResults
        (UI-GB-01)  (UI-GB-02)  (UI-GB-03)(UI-GB-04)(UI-GB-09)
                                                + 9 more (UI-GB-05..14)

                                    │
                  No GameBus emit (non-emitter discipline) ◄── codified forbidden_pattern
                                    │
                       Player input flows BACK through InputRouter, not HUD:
                       ┌────────────┐
                       │ InputRouter│ ← receives Undo button click, routes to GameBus
                       └────────────┘
```

### §10. Key Interfaces

```gdscript
# Public API surface (BattleHUD class)
class_name BattleHUD extends Control

# DI Setup — BattleScene wiring calls before _ready()
func setup(
    camera: BattleCamera,
    hp_controller: HPStatusController,
    turn_runner: TurnOrderRunner,
    grid_controller: GridBattleController,
    input_router: InputRouter,
    map_grid: MapGrid,
    terrain_effect: TerrainEffect,
    unit_role: UnitRole,
    hero_db: HeroDatabase
) -> void

# Public API (InputRouter Tap Preview Protocol — CR-4a)
func show_unit_info(unit_id: int) -> void
func show_tile_info(coord: Vector2i) -> void

# Test seam (ONLY for unit tests — production callers go through GameBus)
func _handle_signal(signal_name: StringName, args: Array) -> void

# Signal handlers (private — invoked via GameBus subscription with CONNECT_DEFERRED)
func _on_unit_selected_changed(unit_id: int, was_selected: int) -> void
func _on_unit_moved(unit_id: int, from: Vector2i, to: Vector2i) -> void
func _on_damage_applied(attacker_id: int, defender_id: int, damage: int) -> void
func _on_battle_outcome_resolved(outcome: StringName, fate_data: Dictionary) -> void
func _on_unit_died(unit_id: int) -> void
func _on_round_started(round_number: int) -> void
func _on_unit_turn_started(unit_id: int) -> void
func _on_unit_turn_ended(unit_id: int) -> void
func _on_input_state_changed(from_state: int, to_state: int) -> void
func _on_input_mode_changed(new_mode: int) -> void
func _on_formation_bonuses_updated(snapshot: Dictionary) -> void

# Internal helpers — not for external call
func _initialize_ui_element_visibility() -> void
func _has_active_grid_overlay() -> bool
func _refresh_grid_overlay_positions(zoom: float) -> void
```

**~12 instance fields** (battle-scoped, all DI'd or signal-state-derived):
- `_camera: BattleCamera = null` — DI'd before _ready()
- `_hp_controller: HPStatusController = null` — DI'd
- `_turn_runner: TurnOrderRunner = null` — DI'd
- `_grid_controller: GridBattleController = null` — DI'd
- `_input_router: InputRouter = null` — DI'd
- `_map_grid: MapGrid = null` — DI'd
- `_terrain_effect: TerrainEffect = null` — DI'd
- `_unit_role: UnitRole = null` — DI'd
- `_hero_db: HeroDatabase = null` — DI'd
- `_ui_elements: Dictionary[StringName, Control] = {}` — UI-GB-01..14 references (filled at _ready via @onready or @export NodePath resolution)
- `_active_status_panel_unit_id: int = -1` — UI-GB-03 polling gate per OQ-3 deferred design
- `_last_zoom: float = 1.0` — per-frame zoom-poll baseline for grid-layer overlays

## Alternatives Considered

### Alternative 1: Stateless-Static Utility Class

- **Description**: `class_name BattleHUD extends RefCounted` with all-static methods; no Control Node; manual draw calls via `_draw()` on a single Container node.
- **Pros**: Mirrors 5-precedent stateless-static pattern (ADR-0006/0007/0008/0009/0012). No instance state. Stateless = trivially testable.
- **Cons**: (a) Can't subscribe to GameBus signals (RefCounted has no node lifecycle); (b) Can't use Godot's UI node subsystem (Control + theme + AccessKit + dual-focus all require Node-based hierarchy); (c) Manual `_draw()` would require re-implementing what `Label`/`Button`/`PanelContainer` provide for free; (d) Massively diverges from Godot UI idiom; (e) AccessKit screen reader support is auto-enabled on Control nodes — static class would lose this for free.
- **Rejection Reason**: HUD is a *state-holder + signal-listener + UI-tree-renderer*, not a calculator. The 5-precedent stateless-static pattern is for systems CALLED by other systems, not systems that LISTEN to events AND own visual hierarchy. Same justification as ADR-0010 §Alt 3 + ADR-0013 §Alt 1 + ADR-0014 §Alt 1 rejection.

### Alternative 2: Autoload BattleHUD

- **Description**: BattleHUD as `/root/BattleHUD` autoload Node, like InputRouter (ADR-0005). State survives scene transitions.
- **Pros**: Eliminates per-battle setup cost. Single HUD reference reusable across scenes (if there were multiple battle-like scenes).
- **Cons**: (a) HUD state is fundamentally battle-scoped — overworld, main menu, and pause screens have no Battle HUD consumer; (b) Autoloads cannot be parameterized per-scene without ugly `set_battle(...)` calls before each scene-load; (c) AccessKit + theme + tween state would need per-battle reset logic, easy to forget; (d) Memory: HUD holds ~14 element references + ~12 backend refs — autoload adds zero benefit and one risk (state leak across battles if reset is forgotten). (e) Does not match the 4-precedent battle-scoped Node pattern (HPStatus + Camera + GridBattleController + TurnOrderRunner all battle-scoped).
- **Rejection Reason**: Battle-scoped lifecycle is the natural fit. Mirrors 4-precedent pattern. Autoload form would be the right call only if a future overworld-HUD or main-menu-HUD shared rendering with the battle HUD, which the GDD does not anticipate. Future Tutorial overlay or Settings panel within battle would be SEPARATE classes (not the same BattleHUD instance).

### Alternative 3: Multiple Separate Control Children (No HUD Wrapper)

- **Description**: Each UI-GB-* element is a separate Control child of `BattleScene/HUDLayer` (CanvasLayer). No `BattleHUD` wrapper class — each element is its own scene + script. Signal subscriptions are per-element.
- **Pros**: Maximum modularity. Each element testable in isolation. No God-Object risk.
- **Cons**: (a) **Signal-subscription fan-out**: 14 elements × N signals each = potentially 50+ subscriptions across the HUD; coordinator role still emerges (e.g., when `unit_selected_changed` fires, UI-GB-02 + UI-GB-03 + UI-GB-04 all need to update — without a wrapper they each subscribe independently, leading to ordering hazards). (b) **DI fan-out**: each element needs its own `setup(...)` with relevant backend refs; BattleScene wiring becomes a 14-element setup gauntlet. (c) **Show/hide coordination**: UI-GB-04 forecast dismisses on `damage_applied`, UI-GB-09 results screen shows on `battle_outcome_resolved` — without a wrapper, the show/hide ordering is implicit through Godot's signal dispatch order, which is not strictly defined. (d) **Theme coordination**: theme overrides need to apply consistently across all 14 elements; without a wrapper, theme ownership is unclear. (e) **Test infrastructure**: 14 separate test files vs. 1 integration-style test file with stubbed signal emitter — first option scales worse for the 14×11=154 (signal × element) interaction matrix.
- **Rejection Reason**: The 14 UI-GB-* elements form a coordinated surface — they all consume the same 11 GameBus signals + the same 9 backend refs. A wrapper class consolidates DI + signal subscription + show/hide coordination + theme application without preventing per-element modularity (each element can still be its own `.tscn` scene file under the wrapper's node tree). The wrapper is NOT a God-Object — it owns ~14 element references + 9 backend refs + 11 signal handlers, all of which are short delegations to per-element render methods. This matches ADR-0014 GridBattleController's role as central orchestrator (controller delegates to per-action handlers without becoming a God-Object).

### Alternative 4: Two ADRs — HUD Layout + HUD Logic

- **Description**: Split the ADR into ADR-0015a (HUD Layout — the 14 UI-GB-* element placement + theme + AccessKit) and ADR-0015b (HUD Logic — the 11 signal handlers + DI + Pillar 2 lock).
- **Pros**: Each ADR shorter + more focused. Could be authored in parallel.
- **Cons**: (a) Layout and logic are tightly coupled — signal handlers reference specific element node paths, theme overrides depend on which Control subclass is chosen; (b) Two ADRs means two PR review cycles + two acceptance ceremonies; (c) Future HUD changes would need to amend both ADRs; (d) The ADR-0014 §Alternative 4 (split into Controller + Combat Resolver) was rejected for the same reason — central orchestrators benefit from single-document atomicity.
- **Rejection Reason**: ADR cohesion outweighs ADR concision. Layout decisions (e.g., "UI-GB-04 forecast is a PanelContainer with Tween animation") inform logic decisions (e.g., "the `_on_damage_applied` handler triggers the forecast dismiss tween"). Splitting forces cross-ADR references for tightly-coupled decisions. MVP scope keeps this ADR ~600 LoC — manageable as one document.

## Consequences

### Positive

- **First Presentation-layer ADR — bridges Foundation + Core + Feature** into a single user-facing surface. Closes 5 prior provisional contracts (ADR-0005 + ADR-0010 + ADR-0011 + ADR-0013 + ADR-0014) in one document.
- **Pattern stable at 5 invocations** of battle-scoped Node — establishes the Presentation-layer extension of the pattern (HPStatus + Camera + GridBattleController + TurnOrderRunner + this).
- **Pillar 2 hidden semantic preservation enforced at 3 layers** — test (story-008 connection-count assertion) + source-code lint (this ADR §8) + ADR-level forbidden_pattern. Future designers cannot accidentally subscribe HUD to fate signal.
- **Non-emitter discipline simplifies the GameBus signal cap** — HUD adds 0 new signals to ADR-0001 §445 50-emits/frame budget; HUD-side state changes are pull-based via DI'd backend method calls.
- **DI seam reuses ADR-0014 + ADR-0010 + ADR-0005 + ADR-0012 test pattern** — `_handle_signal(name, args)` mirrors `_handle_event(event)` (ADR-0005) + `_apply_turn_start_tick(unit_id)` (ADR-0010) + RNG injection (ADR-0012). 6th invocation of test-seam pattern.
- **Engine compatibility verified** — 4 post-cutoff items (4.6 dual-focus, 4.5 AccessKit, 4.5 recursive Control disable, 4.4+ typed Dictionary) all checked against `docs/engine-reference/godot/modules/ui.md`; no unverified APIs.
- **44pt touch target enforcement** — CI lint codifies the technical-preferences.md mandate; not just convention.
- **AccessKit screen reader support inherited for free** — every UI-GB-* element is a Control subclass, so AccessKit auto-exposes them; HUD authors only need to set `tooltip_text` + `accessibility_*` properties.
- **i18n via `tr()` enforced** — no hardcoded strings; all UI text routes through Godot's localization pipeline; future locale additions don't require HUD code changes.

### Negative

- **9-param DI signature** — large `setup(...)` call; mitigated by mirror to ADR-0014's 8-param pattern (proven workable). BattleScene wiring will need explicit param-by-param setup; documentation generates from gdscript signatures.
- **HIGH engine risk** — 4 post-cutoff items require verification on real devices; first-mover cost falls on this ADR's first story implementation. Mitigation: 7 verification items in §Engine Compatibility table = explicit test gates.
- **Forecast render budget burst** — `FORECAST_RENDER_BUDGET_MS = 120` is a worst-case burst (UI-GB-04 forecast on attack-target-hover); steady-state is < 16ms per frame. If the budget is breached on minimum-spec mobile (Pixel 7 / Adreno 610), forecast feels laggy and Pillar 1 reading flow degrades. Mitigation: instrumentation in first story + soak-test in Polish.
- **Per-frame zoom-poll for grid-layer overlays (UI-GB-12/13/14)** — adds O(1) `_process` cost when overlays active; on most frames overlays are inactive and `_process` is a no-op via `_has_active_grid_overlay()` early-return. Worst case (Rally + Formation overlays active, zoom changing): ~8 grid overlay position updates per frame ≈ 0.05ms; negligible. Alternative would be subscribing to a future `camera_zoom_changed` signal; deferred to future ADR-0013 amendment per OQ-1 below.
- **HUD layout authoring is OUT of scope** — this ADR ratifies the architectural form but `design/ux/battle-hud.md` v1.1 owns specific element placements, fonts, colors, animations. Implementation-time art-director sign-off is a per-story acceptance gate.

### Risks

- **R-1: GameBus signal namespace non-issue** — HUD adds 0 new signals (non-emitter); no impact on ADR-0001 §445 50-emits/frame cap. Risk class: NONE (this is a positive, not a risk).
- **R-2: AccessKit screen reader integration** — Godot 4.5 AccessKit support is new (3 minor versions old as of 2026-05); reliable on macOS VoiceOver per docs/engine-reference/godot/modules/ui.md but Android TalkBack support is unverified. **Mitigation**: post-MVP a11y audit (per `design/ux/accessibility-requirements.md` §4); MVP HUD ships without TalkBack guarantee, with documentation of which elements have AccessKit attributes set.
- **R-3: Dual-focus regression on player using mouse + keyboard simultaneously** — Godot 4.6 split focus is recent; reports of edge cases exist (per docs/engine-reference/godot/modules/ui.md "Common Mistakes"). **Mitigation**: Verification §1 explicitly tests mouse-hover + keyboard-focus simultaneously on macOS Metal + Linux Vulkan as a per-story acceptance gate.
- **R-4: `_exit_tree()` disconnect leak parity with ADR-0013/0014** — same Godot 4.x SOURCE-outlives-TARGET pattern; this ADR has 11 separate signal subscriptions to disconnect (vs. ADR-0013's 1 + ADR-0014's 4). Mitigated by `_exit_tree()` body explicitly handling all 11 (see §3 code) + TD-057 retrofit pattern from story-009.
- **R-5: Forbidden-pattern lint fragility** — `lint_battle_hud_hidden_fate_non_subscription.sh` uses `grep -q` on a single source file. If HUD source is split across multiple files in a future refactor (e.g., `battle_hud.gd` + `battle_hud_signal_handlers.gd`), the lint must update its file list. **Mitigation**: lint script reads from a project-wide `BATTLE_HUD_SOURCE_FILES` env var or `.config` file; first story authors the convention. Same risk class as ADR-0014's grid-battle-controller lints (4 of which depend on file-list consistency).
- **R-6: 9-param DI signature drift** — if a future ADR adds a new battle-scoped backend (e.g., AI controller, status effect VFX system), HUD's `setup(...)` may need to grow. Migration: each addition is parameter-stable (existing call sites need a new arg appended); no breaking change. Acceptable per ADR-0014 8-param + ADR-0010 §Migration precedent.
- **R-7: Polling vs. signal trade-off for `hp_status_changed`** — MVP polls `_active_status_panel_unit_id` HP per frame (only when panel open); 60fps × 1 unit × 1 Dictionary lookup = 60 reads/sec — negligible. If future ADR-0010 amendment adds `hp_status_changed(unit_id)` signal, HUD can subscribe additively without breaking existing poll logic. **Mitigation**: poll path is a 1-line addition in `_process`; trivially removable when signal lands.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| `design/ux/battle-hud.md` (UX spec) | UI-GB-01..14 element render contract | §2 Layout structure + §5 Signal handlers commit to rendering all 14 elements based on signal-driven state changes |
| `design/ux/battle-hud.md` AC-UX-HUD-02 | Forecast dismiss within 80ms | §Verification §4 codifies as per-story acceptance gate; §5 `_on_damage_applied` handler is the dismiss trigger |
| `design/ux/battle-hud.md` §10 Tuning Knobs | `FORECAST_RENDER_BUDGET_MS = 120` | §7 adds 1 BalanceConstants entry; same-patch obligation at first story |
| `design/ux/battle-hud.md` §3 UI-GB-14 Formation Aura | `formation_bonuses_updated` signal subscription | §5 `_on_formation_bonuses_updated` handler renders UI-GB-14 + UI-GB-13 overlays |
| `design/gdd/grid-battle.md` CR-12 UI signal emission | HUD subscribes to `formation_bonuses_updated` (and 4 controller-LOCAL signals) | §3 + §5 — 11 GameBus subscriptions covering all CR-12 obligations |
| `design/gdd/game-concept.md` Pillar 2 (운명은 바꿀 수 있다) | Hidden fate semantic — HUD does NOT surface fate progress | §8 codifies 3-layer enforcement (test + lint + forbidden_pattern) of `hidden_fate_condition_progressed` non-subscription |
| `design/gdd/destiny-branch.md` Section B | Wordless pre-linguistic realization at Beat 7 | §8 lock prevents HUD from spoiling Beat 7 reveal at Beat 6 results screen |
| `design/gdd/hp-status.md` UI-GB-11 (DEFEND_STANCE 1-turn) | DEFEND_STANCE badge rendered on defending unit's tile | §5 `_on_unit_turn_started` checks `_hp_controller.get_status_effects(unit_id)` for DEFEND_STANCE entry, renders UI-GB-11 |
| `design/gdd/turn-order.md` initiative queue snapshot | UI-GB-01 InitiativeQueue rendering | §5 `_on_round_started` + `_on_unit_turn_ended` + `_on_unit_died` all call `_turn_runner.get_turn_order_snapshot()` |
| `design/gdd/input-handling.md` Touch Tap Preview Protocol (CR-4a) | InputRouter invokes `BattleHUD.show_unit_info` + `show_tile_info` | §4 Public API ratifies the 2 method signatures from ADR-0005 lines 235-236 |
| `design/gdd/input-handling.md` §S5 INPUT_BLOCKED state | HUD interaction disabled during scene transitions | §5 `_on_input_state_changed` sets `mouse_filter = MOUSE_FILTER_IGNORE` (4.5 recursive propagation) |
| `design/gdd/formation-bonus.md` CR-FB-1..14 | Formation Aura visual surface | §5 `_on_formation_bonuses_updated` + battle-hud.md §3 UI-GB-14 spec |
| `design/ux/accessibility-requirements.md` R-2 announcements | Screen reader exposure of unit/tile info on focus | §Engine Compatibility Verification §2 (AccessKit auto-enabled on Control); first-story authoring sets `tooltip_text` + `accessibility_*` per element |
| `.claude/docs/technical-preferences.md` 44pt touch target | All interactive Controls ≥ 44×44pt | §Engine Compatibility Verification §3 (CI lint); R-8 codifies |
| `.claude/docs/technical-preferences.md` i18n via `tr()` | All visible strings localizable | R-10 + §10 Key Interfaces explicit `tr(key)` discipline |

## Performance Implications

- **CPU**: Per-frame steady-state HUD update = ~0.1ms (no `_process` body except optional grid-overlay zoom-poll which is gated). Per-event signal handler cost: 11 handlers × ~0.05ms each = 0.55ms peak (only one fires per signal emit, so realistic peak ≈ 0.05ms per event). Forecast render burst: ≤ 120ms one-shot per UI-GB-04 spec; not per-frame. UI-GB-09 end-of-battle results render: ≤ 200ms one-shot (single occurrence per battle). Total budget consumption ≈ 1.0ms peak per battle action; well under 16.6ms frame budget.
- **Memory**: HUD instance ≈ 12 fields × 8 bytes = ~100 bytes + 14 element refs × 8 bytes = ~112 bytes + 9 backend refs × 8 bytes = ~72 bytes ≈ ~300 bytes. Per-element Control allocations dominate (PanelContainer + Label + TextureRect each ~200-400 bytes); 14 elements × ~300 bytes = ~4.2KB. Theme + i18n strings cached centrally (not per-instance). Total HUD allocation: ~5KB — well under 512MB mobile budget.
- **Load Time**: HUD instantiation in BattleScene mount = ~5ms (14 element scenes × ~0.3ms each); negligible relative to BattleScene's ~50ms total mount cost.
- **Network**: N/A (single-player MVP).

## Migration Plan

This ADR is the FIRST Presentation-layer ADR — no prior implementation to migrate. First story implementation creates:
- `src/feature/battle_hud/battle_hud.gd` — class implementing this ADR's §3-§10 contract
- `scenes/battle/battle_hud.tscn` — root Control scene with CanvasLayer parent + 14 child element scenes
- `scenes/battle/elements/ui_gb_01_initiative_queue.tscn` (and similar for 02..14)
- `tests/unit/feature/battle_hud/battle_hud_test.gd` — DI test seam validation + 11 signal handler invocation tests + Pillar 2 lint test (asserts `hidden_fate_condition_progressed` not in source)
- `tools/ci/lint_battle_hud_hidden_fate_non_subscription.sh` (new)
- `tools/ci/lint_battle_hud_signal_emission_outside_ui_domain.sh` (new — non-emitter discipline)
- `tools/ci/lint_battle_hud_touch_target_size.sh` (new — 44pt enforcement)
- `tools/ci/lint_battle_hud_connect_deferred.sh` (new — CONNECT_DEFERRED discipline)
- `tools/ci/lint_balance_entities_battle_hud.sh` (new — `FORECAST_RENDER_BUDGET_MS` key validation)
- `assets/data/balance/balance_entities.json` — adds `FORECAST_RENDER_BUDGET_MS = 120` key
- `.github/workflows/tests.yml` — wires 5 new lints after grid-battle-controller 4-lint block (sprint-5 story-010 precedent)
- BattleScene wiring (sprint-6) — instantiates `BattleHUD.new()`, calls `setup(camera, hp_controller, ...)`, `add_child()`, mounted under `CanvasLayer/HUDLayer`

## Validation Criteria

This ADR is validated when:

1. **Story coverage**: A future battle-hud Feature epic produces stories implementing each of §3-§10 sections + each of the 14 UI-GB-* element scenes.
2. **Test coverage**: Unit tests for all 11 signal handlers + DI seam + Pillar 2 lint pass; integration test verifies BattleScene mount → HUD render → signal-driven state update flow on all 11 signals.
3. **Engine compatibility verification**:
   - All 7 Verification items resolved (dual-focus, AccessKit, 44pt touch, forecast 80ms dismiss, recursive Control disable, CONNECT_DEFERRED discipline, Pillar 2 lint).
   - No Godot 4.6 deprecated API used; no post-cutoff API used without engine-reference doc citation.
4. **Pattern boundary verification**:
   - 5th invocation of battle-scoped Node pattern works (HPStatus + Camera + GridBattleController + TurnOrderRunner + BattleHUD).
   - Non-emitter discipline lint passes (HUD source contains no `GameBus.*.emit` calls).
   - Pillar 2 lock lint passes (HUD source contains no `hidden_fate_condition_progressed` references).
5. **Integration test**:
   - BattleScene mount → BattleHUD `setup(...)` → `add_child()` → all 11 signal handlers respond → `_exit_tree()` disconnects all 11 → no leaked Callable warnings.
6. **Performance test**:
   - Steady-state per-frame HUD update < 1.0ms on Pixel 7-class hardware.
   - Forecast render burst ≤ 120ms on Pixel 7-class hardware.
   - End-of-battle results render ≤ 200ms.
7. **Cross-platform determinism**: Same signal sequence produces identical HUD render state on macOS Metal + Linux Vulkan + Windows D3D12 + Android Vulkan + iOS Metal (post-MVP).
8. **AccessKit screen reader**: Macos VoiceOver announces unit name + HP + status effects on UI-GB-03 focus change (post-MVP for Android TalkBack).

## Open Questions

| OQ | Description | Owner | Resolution Path |
|----|-------------|-------|-----------------|
| OQ-1 | Per-frame zoom-poll vs. `camera_zoom_changed` signal subscription | first-story implementer + godot-specialist | First story attempts per-frame poll (gated on `_has_active_grid_overlay()`); if performance budget breached, raises ADR-0013 amendment to add `camera_zoom_changed` signal. Decision deferred to first story. |
| OQ-2 | UI-GB-12/13/14 grid-layer overlays as cross-tree NodePath references vs. consolidated as Control overlays via Camera2D-aware position tracking | first-story implementer | First story attempts NodePath approach (matches battle-hud.md §3 spec); if cross-tree dance becomes painful, refactor to Control overlays via `_camera.world_to_screen()` per-frame. Decision deferred to first story. |
| OQ-3 | `hp_status_changed` signal — poll vs. subscribe | post-MVP ADR-0010 amendment | MVP polls `_active_status_panel_unit_id` HP per frame; future ADR-0010 amendment may add `hp_status_changed(unit_id)` signal — additive, non-breaking. Decision deferred to post-MVP. |
| OQ-4 | Two-tap timer ownership for ATTACK / DEFEND confirm flows (battle-hud.md §5) | first-story implementer | Two-tap timer state owned by HUD (`_two_tap_timer: Timer` + `_two_tap_target_action: StringName`); HUD invokes `_input_router._handle_event(synthetic_attack_confirm_event)` on second tap within `TWO_TAP_TIMEOUT_S`. Decision codified at first story; this ADR commits to the architectural pattern (HUD owns timer; InputRouter receives synthetic event), not the timer durations (those are owned by `design/ux/battle-hud.md` §5). |
| OQ-5 | Save/restore HUD state mid-battle | post-MVP | NOT supported in MVP. Battle restart re-initializes HUD state. Future post-MVP save format may include HUD persistence; out of scope here. |

## Implementation Notes (first-story reads fresh from shipped code)

This ADR is **Proposed** at authoring time (2026-05-03). Upon Acceptance via `/architecture-review` delta, this section will be amended with implementation-time discoveries (architectural drifts, API gaps, ADR sketch vs. shipped reality). Pattern: read shipped API fresh → flag drift in Implementation Notes → ship correct code + ADR amendment in same patch. Mirrors ADR-0014 Implementation Notes 10-entry pattern (10 drifts surfaced + fixed in-line during sprint-5 stories 001-010).

Anticipated drift surfaces:
- **`GameBus.formation_bonuses_updated` signal name** — provisional in `design/ux/battle-hud.md` + ADR-0014 §8 + grid-battle.md CR-12; first story verifies the shipped GameBus signal declaration in `src/core/game_bus.gd` matches.
- **`InputRouter._handle_event` synthetic event injection** — first story verifies the shipped InputRouter accepts synthetic event via `_handle_event` test seam (per ADR-0005 line 988 — pattern proven 11 stories) for Two-tap ATTACK/DEFEND confirm flow.
- **`_camera.world_to_screen()` API** — verify Godot 4.6 `Camera2D` exposes inverse of `screen_to_grid` for grid-overlay position computation; if not, derive via `get_canvas_transform() * world_pos`.
- **`Control.MOUSE_FILTER_IGNORE` recursive propagation** — verify Godot 4.5+ `Control` mouse_filter cascade works as advertised in engine-reference doc; fallback to per-child set if not.
- **Typed `Dictionary[StringName, Control]` parse** — verify GDScript 4.6 typed-Dictionary syntax with Control value type.

## Related Decisions

- **ADR-0001** (GameBus) — signal contract source-of-truth; CONNECT_DEFERRED mandate
- **ADR-0005** (InputRouter) — Tap Preview Protocol consumer + 2 GameBus signal source for HUD
- **ADR-0010** (HPStatusController) — DI dependency + 1 GameBus signal source + 3 query methods
- **ADR-0011** (TurnOrderRunner) — DI dependency + 3 GameBus signal sources + 1 query method
- **ADR-0013** (BattleCamera) — DI dependency + 1 query method (`get_zoom_value`)
- **ADR-0014** (GridBattleController) — DI dependency + 5 GameBus signal sources (4 subscribed, 1 explicitly NOT subscribed per Pillar 2 lock) + 1 query method
- **ADR-0006** (BalanceConstants) — 1 new key `FORECAST_RENDER_BUDGET_MS`
- **ADR-0004** (MapGrid) — DI dependency + 1 query method for tile info tooltip
- **ADR-0008** (TerrainEffect) — DI dependency for tile info tooltip terrain modifier
- **ADR-0009** (UnitRole) — DI dependency for unit info panel class-based stats
- **ADR-0007** (HeroDatabase) — DI dependency for unit info panel name + portrait
- **Future: Scenario Progression ADR** (NOT YET WRITTEN — sprint-6) — separate consumer of `battle_outcome_resolved` (independent of HUD; no cross-coupling)
- **Future: Destiny Branch ADR** (NOT YET WRITTEN — sprint-6) — sole consumer of `hidden_fate_condition_progressed`; this ADR's §8 lock preserves Destiny Branch's exclusive access
- **Future: Battle Scene wiring ADR** (NOT YET WRITTEN — sprint-6) — mounts BattleHUD as `CanvasLayer/BattleHUD` child; calls `setup(...)` BEFORE `add_child()`
