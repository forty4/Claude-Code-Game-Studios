# Epic: Battle HUD

> **Layer**: Presentation (first Presentation-layer epic in the project — establishes the layer)
> **GDD**: `design/ux/battle-hud.md` v1.1 (744 lines — UX spec; UI specs live in `design/ux/` not `design/gdd/`)
> **Architecture Module**: `BattleHUD` — battle-scoped Control mounted under `CanvasLayer` at `BattleScene/HUDLayer/BattleHUD` (**5th invocation** of battle-scoped Node pattern)
> **Status**: **Ready** (Pending ADR-0015 Acceptance via `/architecture-review` delta in fresh session)
> **Stories**: Not yet created — run `/create-stories battle-hud`
> **Created**: 2026-05-03 (Sprint 5 S5-13)
> **Manifest Version**: 2026-04-20 (`docs/architecture/control-manifest.md`)

## Overview

The Battle HUD epic implements `BattleHUD` — the **player-facing surface** that consumes 11 GameBus signals (4 of 5 GridBattleController controller-LOCAL signals + 1 HP/Status `unit_died` + 3 Turn Order signals + 2 InputRouter signals + 1 Grid Battle `formation_bonuses_updated`), reads state from 9 DI'd backends, renders 14 UI-GB-* elements per `design/ux/battle-hud.md` v1.1 (initiative queue, action menu, unit info panel, combat forecast, skill list, tile info tooltip, turn/round counter, victory condition display, end-of-battle results screen, undo indicator, DEFEND stance badge, TacticalRead extended range, Rally aura, Formation aura), and **explicitly does NOT subscribe** to `hidden_fate_condition_progressed` — Pillar 2 hidden semantic preservation locked at 3 layers (test + source-grep lint + registry forbidden_pattern).

This is the **first Presentation-layer epic** in the project + **5th invocation** of the battle-scoped Node pattern (after ADR-0010 HPStatusController + ADR-0011 TurnOrderRunner + ADR-0013 BattleCamera + ADR-0014 GridBattleController). Future Presentation-layer Nodes (Battle Results screen, Tutorial overlay, Pause menu within battle, Battle Prep UI, Story Event UI, Main Menu) follow the same DI + `_exit_tree()` discipline + non-emitter pattern + AccessKit-via-Control inheritance precedent established here.

## MVP Scope (per ADR-0015 §"Why MVP-scoped" — explicit deferral structure)

The full `design/ux/battle-hud.md` UX spec is 744 lines with all 14 UI-GB-* element specs + 13 visual/audio specs + forecast contract (UI-GB-04) + two-tap ATTACK/DEFEND mobile flows + palette/accessibility + 6 acceptance criteria + 5 Open Questions. **This epic implements the MVP subset** for the 장판파 first-chapter playable surface:

- ✅ **14 UI-GB-* elements** (full set — UX spec is MVP-tier already)
- ✅ **11 GameBus signal subscriptions** — all CONNECT_DEFERRED per ADR-0001 §5
- ✅ **Pillar 2 hidden-fate non-subscription** (zero lint + zero connect calls + zero source token occurrences)
- ✅ **9-param DI seam** (`setup(camera, hp_controller, turn_runner, grid_controller, input_router, map_grid, terrain_effect, unit_role, hero_db)`)
- ✅ **InputRouter Tap Preview Protocol** (`show_unit_info` + `show_tile_info` public methods per ADR-0005 lines 235-236)
- ✅ **Two-tap ATTACK/DEFEND** mobile confirm flows per battle-hud.md §5
- ✅ **44pt touch target enforcement** per technical-preferences.md
- ✅ **i18n via `tr()`** for all visible strings
- ✅ **AccessKit screen reader** auto-exposure (Godot 4.5+ Control inheritance)
- ✅ **`_exit_tree()` 11-disconnect cleanup** per TD-057 retrofit pattern (story-009)

**Explicit deferrals** (each future ADR / story slot reserved):
- ❌ `hp_status_changed` signal subscription — post-MVP per ADR-0010 OQ-3 (MVP polls `_active_status_panel_unit_id` HP per frame; future signal is additive non-breaking)
- ❌ Save/restore HUD state mid-battle — post-MVP (battle restart re-initializes HUD)
- ❌ Animation curve / VFX values authoring — owned by `design/ux/battle-hud.md` §2 + §6 (implementation-time art-director sign-off per accessibility-requirements.md §4)
- ❌ Battle Results screen as separate ADR — UI-GB-09 lives within BattleHUD class for MVP; Future Battle Results ADR may extract per design/ux/battle-hud.md §3 UI-GB-09 spec evolution
- ❌ Specific Control subclass choices for each UI-GB-* element — implementation freedom within ADR-0015 contract surface (e.g., UI-GB-02 ActionMenu may be PanelContainer + VBoxContainer or HBoxContainer; first story authors the subclass)

When each future ADR ships, this epic is **amended** (additive — new signal subscriptions, new helper methods) or **superseded by** a successor ADR.

## Pattern Boundary Precedent

BattleHUD is the **5th invocation** of the battle-scoped Node pattern. **First Presentation-layer ADR** in the project — establishes the layer pattern for the remaining 5 Presentation modules per architecture.md line 299 (Battle Prep UI, Story Event UI, Main Menu, Battle VFX, Sound/Music). Pattern stable at 5 invocations across 4 layers:

| Invocation | System | Layer | ADR | Status |
|---|---|---|---|---|
| #1 | HPStatusController | Core | ADR-0010 | Accepted 2026-04-30 / Complete 2026-05-02 |
| #2 | TurnOrderRunner | Core | ADR-0011 | Accepted 2026-04-30 / Complete 2026-05-02 |
| #3 | BattleCamera | Feature | ADR-0013 | Accepted 2026-05-02 / Complete 2026-05-02 |
| #4 | GridBattleController | Feature | ADR-0014 | Accepted 2026-05-02 / Complete 2026-05-03 |
| **#5** | **BattleHUD** | **Presentation** | **ADR-0015** | **Proposed 2026-05-03 / this epic Ready** |

Future Presentation-layer Nodes follow same DI + `_exit_tree()` discipline + non-emitter pattern + AccessKit-via-Control inheritance + 44pt touch target lint + i18n via `tr()` lint.

## Pillar 2 Architectural Lock — `hidden_fate_condition_progressed` Non-Subscription

**CRITICAL — first project precedent of pillar-anchored lint pattern.** `design/gdd/game-concept.md` Pillar 2 (운명은 바꿀 수 있다 — Destiny Can Be Rewritten) ratifies that fate progress is HIDDEN from the player during battle and surfaces only at Beat 7 reserved-color reveal per `design/gdd/destiny-branch.md` Section B. ADR-0015 §8 + the registry forbidden_pattern `battle_hud_subscribes_to_hidden_fate_signal` enforce this at 3 layers:

1. **Test layer** — story-008 connection-count assertion: `hidden_fate_condition_progressed.get_connections().size() == 0` on fresh GridBattleController instance (already shipped sprint-5 2026-05-03)
2. **Source layer** — CI lint `tools/ci/lint_battle_hud_hidden_fate_non_subscription.sh` greps `src/feature/battle_hud/battle_hud.gd` for the literal token; zero occurrences = PASS, any match = build fail (story to be authored in this epic)
3. **Architecture layer** — `docs/registry/architecture.yaml` forbidden_pattern blocks future ADRs from adding HUD subscription

If a future Battle HUD designer believes they need to surface fate progress to the player, they MUST first revise this ADR (Superseded-by) AND `design/gdd/destiny-branch.md` Section B (which explicitly mandates wordlessness) AND `design/gdd/game-concept.md` Pillar 2. Three coordinated revisions are intentionally hard.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| **ADR-0015 Battle HUD** (Proposed 2026-05-03 — pending /architecture-review delta) | `BattleHUD` battle-scoped Control under CanvasLayer; 9-param DI `setup()`; 11 GameBus subscriptions (4 controller-LOCAL + 1 HP/Status + 3 Turn Order + 2 InputRouter + 1 formation_bonuses_updated) all CONNECT_DEFERRED; 0 emissions (non-emitter discipline); 2 public methods (show_unit_info + show_tile_info per ADR-0005 lines 235-236 Tap Preview); Pillar 2 hidden-fate non-subscription lock. godot-specialist PASS WITH 3 REVISIONS resolved same-patch (§3 _exit_tree guard rationale + §4 args:Array rationale + §6 set_process(false) gating doc). | **HIGH** (UI domain Godot 4.6: dual-focus + AccessKit + recursive Control disable + typed Dictionary) |
| ADR-0001 GameBus (Accepted 2026-04-18) | Signal contract source-of-truth; CONNECT_DEFERRED mandate for all 11 subscriptions; HUD non-emitter (0 GameBus.*.emit calls; codified as `battle_hud_signal_emission` forbidden_pattern) | LOW |
| ADR-0005 InputRouter (Accepted 2026-04-30) | Ratifies BattleHUD provisional contract from lines 235-236; HUD subscribes to `input_state_changed` + `input_mode_changed` for contextual UI updates; `show_unit_info(int)` + `show_tile_info(Vector2i)` invoked BY InputRouter on Tap Preview Protocol per CR-4a | HIGH (Foundation; HUD inherits dual-focus + AccessKit + edge-to-edge consideration) |
| ADR-0010 HPStatusController (Accepted 2026-04-30) | DI dependency; HUD reads `get_current_hp(unit_id) / get_max_hp(unit_id) / get_status_effects(unit_id)` for UI-GB-03 + UI-GB-11; subscribes to `unit_died` for UI-GB-09 results screen + UI-GB-01 queue update | LOW |
| ADR-0011 TurnOrderRunner (Accepted 2026-04-30) | DI dependency; HUD reads `get_turn_order_snapshot()` pull-based on `round_started` / `unit_turn_started` / `unit_turn_ended` / `unit_died` receipts for UI-GB-01 InitiativeQueue + UI-GB-07 TurnRoundCounter | LOW |
| ADR-0013 BattleCamera (Accepted 2026-05-02) | DI dependency; HUD reads `get_zoom_value() -> float` for UI scale-with-camera (counter-scale logic for UI-GB-12/13/14 grid-layer overlays) | LOW |
| ADR-0014 GridBattleController (Accepted 2026-05-02) | DI dependency; HUD subscribes to **4 of 5** controller-LOCAL signals: `unit_selected_changed` (UI-GB-02 + UI-GB-03), `unit_moved` (UI-GB-10 + tile state), `damage_applied` (UI-GB-04 dismiss + §2.5 hit/miss), `battle_outcome_resolved` (UI-GB-09); **EXPLICITLY NOT** `hidden_fate_condition_progressed` (Pillar 2 lock); reads `get_selected_unit_id()` for UI-GB-02 binding | LOW |
| ADR-0006 BalanceConstants (Accepted 2026-04-30) | 1 new entry: `FORECAST_RENDER_BUDGET_MS = 120` per battle-hud.md §10 Tuning Knobs; loaded via `BalanceConstants.get_const(&"FORECAST_RENDER_BUDGET_MS")` at first story implementation | LOW |
| ADR-0004 MapGrid (Accepted 2026-04-20) | DI dependency; HUD reads `get_tile(coord) -> TileData` for UI-GB-06 tile info tooltip (terrain type / elevation / defense bonus / evasion bonus) | LOW |
| ADR-0008 TerrainEffect (Accepted 2026-04-25) | DI dependency; HUD reads `get_modifier(...)` for UI-GB-06 terrain modifier display | LOW |
| ADR-0009 UnitRole (Accepted 2026-04-30) | DI dependency; HUD reads `UnitRole.get_max_hp(...)` + class-based stat queries for UI-GB-03 unit info panel | LOW |
| ADR-0007 HeroDatabase (Accepted 2026-04-30) | DI dependency; HUD reads `HeroDatabase.get_hero(hero_id)` for UI-GB-03 unit name + portrait reference | LOW |

**Highest Engine Risk**: **HIGH** (ADR-0015 UI domain Godot 4.6 + ADR-0005 inherited risk). 7 mandatory verification items as per-story acceptance gates: (1) dual-focus end-to-end (4.6 mouse/touch ≠ keyboard/gamepad focus), (2) AccessKit screen reader (4.5 — macOS VoiceOver + Android TalkBack post-MVP), (3) 44pt touch target CI lint, (4) forecast 80ms dismiss latency on Pixel 7-class hardware, (5) recursive `MOUSE_FILTER_IGNORE` propagation (4.5+), (6) CONNECT_DEFERRED discipline static lint (11 subscriptions), (7) **Pillar 2 hidden-fate non-subscription lint (CRITICAL — KEEP forever, not just MVP)**.

## Same-Patch Obligations from ADR-0015 Acceptance

1. **1 BalanceConstants addition** to `assets/data/balance/balance_entities.json` (first impl story): `FORECAST_RENDER_BUDGET_MS = 120` (UI-GB-04 forecast burst budget per battle-hud.md §10).
2. **5 forbidden_patterns** registered (already in `docs/registry/architecture.yaml` v8 via ADR-0015 commit): `battle_hud_signal_emission` + `battle_hud_subscribes_to_hidden_fate_signal` (CRITICAL Pillar 2 lock) + `battle_hud_missing_exit_tree_disconnect` + `battle_hud_touch_target_below_44pt` + `battle_hud_hardcoded_localized_strings`.
3. **5 CI lint scripts** at `tools/ci/lint_battle_hud_*.sh` (story to be authored as epic-terminal):
   - `lint_battle_hud_hidden_fate_non_subscription.sh` — Pillar 2 lock (zero token occurrences)
   - `lint_battle_hud_signal_emission_outside_ui_domain.sh` — non-emitter discipline (zero `GameBus.*.emit` calls)
   - `lint_battle_hud_missing_exit_tree_disconnect.sh` — 11 disconnect calls within `_exit_tree()` body
   - `lint_battle_hud_touch_target_size.sh` — 44pt minimum on touch viewport
   - `lint_battle_hud_connect_deferred.sh` — all 11 GameBus subscriptions use CONNECT_DEFERRED
   - PLUS 1 BalanceConstants key-presence lint: `lint_balance_entities_battle_hud.sh` (FORECAST_RENDER_BUDGET_MS)
4. **5 lint steps wired** into `.github/workflows/tests.yml` (story-NN epic-terminal — same precedent as grid-battle-controller story-010 4-lint block).
5. **`scenes/battle/battle_hud.tscn`** — root Control scene with CanvasLayer parent; 14 child element scenes at `scenes/battle/elements/ui_gb_NN_<name>.tscn` (one per UI-GB-* element per battle-hud.md §3).
6. **Test stub strategy**: extend existing `tests/helpers/turn_order_runner_stub.gd` (sprint-5 story-006 precedent) + new stubs for `tests/helpers/{battle_camera,grid_battle_controller,input_router,hp_status_controller}_stub.gd` (some may already exist from prior epics — verify before authoring).
7. **`production/qa/evidence/battle_hud_verification_summary.md`** — epic-terminal rollup doc per grid-battle-controller story-010 precedent (mandatory before epic Complete).

## Cross-System Dependencies

The 9 DI'd backends are **all already shipped to production** — this epic is the *integration site*, not a build-from-scratch. Heavy reuse:

- **GridBattleController** (Feature, Complete 2026-05-03) — 4 of 5 controller-LOCAL signals subscribed; `get_selected_unit_id()` query
- **BattleCamera** (Feature, Complete 2026-05-02) — `get_zoom_value()` query for grid-layer overlay scale-with-camera
- **HPStatusController** (Core, Complete 2026-05-02) — `get_current_hp / get_max_hp / get_status_effects` queries; `unit_died` signal subscription
- **TurnOrderRunner** (Core, Complete 2026-05-02) — `get_turn_order_snapshot()` query; 3 signal subscriptions (`round_started`, `unit_turn_started`, `unit_turn_ended`)
- **InputRouter** (Foundation, Ready — implementation pending input-handling Foundation epic; sprint-5 input-handling Ready 2026-05-02) — `get_active_input_mode()` query; 2 signal subscriptions; invokes `BattleHUD.show_unit_info / show_tile_info` per Tap Preview Protocol. **NOTE**: input-handling Foundation epic is "Ready" not "Complete" — battle-hud impl stories will need stubs for InputRouter integration tests until input-handling ships.
- **MapGrid** (Foundation, Complete 2026-04-25) — `get_tile(coord)` for UI-GB-06 tile info tooltip
- **TerrainEffect** (Core, Complete 2026-04-26) — `get_modifier(...)` for UI-GB-06 terrain modifier display
- **UnitRole** (Foundation, Complete 2026-04-28) — class-based derived stats for UI-GB-03 unit info panel
- **HeroDatabase** (Foundation, Complete 2026-05-01) — `get_hero(hero_id)` for UI-GB-03 unit name + portrait reference
- **GameBus** (Platform, Complete 2026-04-21) — 11 signal subscription consumer; non-emitter

**Dependency note**: 8 of 9 backends are Complete (concrete shipped code); InputRouter is Ready (epic exists with 17/17 TRs traced; impl stories not yet shipped). Battle HUD impl stories that exercise InputRouter integration may need stubs OR may sequence after input-handling impl ships. First story authoring must verify InputRouter shipped state.

## GDD Requirements

`design/ux/battle-hud.md` v1.1 uses UI-GB-NN identifiers (NOT TR-XXX format). The TR registry (`docs/architecture/tr-registry.yaml`) does NOT yet contain battle-hud entries — TR backfill is a follow-up for `/architecture-review` delta. ADR-0015 §"GDD Requirements Addressed" maps each UI-GB-* identifier to ADR-0015 sections explicitly.

**14 UI-GB-* elements** (full coverage per ADR-0015):

| UI-GB-ID | Element | ADR Coverage |
|---|---|---|
| UI-GB-01 | Initiative Queue | ADR-0015 §5 (subscribes `round_started` + `unit_turn_started` + `unit_turn_ended` + `unit_died`; queries `_turn_runner.get_turn_order_snapshot()`) ✅ |
| UI-GB-02 | Action Menu | ADR-0015 §5 (subscribes `unit_selected_changed` + `unit_turn_started`) ✅ |
| UI-GB-03 | Unit Info Panel | ADR-0015 §5 (subscribes `unit_selected_changed` + `damage_applied` + `unit_turn_started`; queries `_hp_controller.get_current_hp/get_max_hp/get_status_effects` + `_hero_db.get_hero` + `_unit_role.get_max_hp`) ✅ |
| UI-GB-04 | Combat Forecast | ADR-0015 §5 (subscribes `damage_applied` + `round_started` for force-dismiss; FORECAST_RENDER_BUDGET_MS = 120 BalanceConstants key) ✅ |
| UI-GB-05 | Skill List | ADR-0015 §2 (sub-panel parented under UI-GB-02 ActionMenu — implementation-time element) ✅ |
| UI-GB-06 | Tile Info Tooltip | ADR-0015 §4 (`show_tile_info(coord)` public method invoked BY InputRouter on Tap Preview; queries `_map_grid.get_tile` + `_terrain_effect.get_modifier`) ✅ |
| UI-GB-07 | Turn/Round Counter | ADR-0015 §5 (subscribes `round_started` + `unit_turn_started`) ✅ |
| UI-GB-08 | Victory Condition Display | ADR-0015 §2 (BattleScene-passed config; rendered at battle init) ✅ |
| UI-GB-09 | End-of-Battle Results Screen | ADR-0015 §5 (subscribes `battle_outcome_resolved`; renders fate_data outcome WITHOUT surfacing fate counters individually — Pillar 2 preservation) ✅ |
| UI-GB-10 | Undo Indicator | ADR-0015 §5 (subscribes `unit_moved`; visible during S3 PLAYER_TURN_ACTIVE + ACTION_PENDING) ✅ |
| UI-GB-11 | DEFEND Stance Badge | ADR-0015 §5 (subscribes `unit_turn_started` for badge expiry; queries `_hp_controller.get_status_effects` for DEFEND_STANCE entry) ✅ |
| UI-GB-12 | TacticalRead Extended Range | ADR-0015 §2 (grid-layer overlay; coordinated via `formation_bonuses_updated` handler; first-story decides direct child vs. cross-tree NodePath per OQ-2) ✅ |
| UI-GB-13 | Rally Aura Visual | ADR-0015 §5 (subscribes `formation_bonuses_updated`; renders 황금 overlay per battle-hud.md §3 UI-GB-13 spec) ✅ |
| UI-GB-14 | Formation Aura Visual | ADR-0015 §5 (subscribes `formation_bonuses_updated`; renders 청록 octagonal outline + 緣 bond glyph per battle-hud.md §3 UI-GB-14 spec) ✅ |

**6 AC-UX-HUD-* acceptance criteria** (per battle-hud.md §8 — coverage verified at story-level):

| AC-ID | Acceptance Criterion | ADR Coverage |
|---|---|---|
| AC-UX-HUD-01 | Forecast renders all applicable sections within FORECAST_RENDER_BUDGET_MS | ADR-0015 §7 + Verification §4 (per-story performance gate) ✅ |
| AC-UX-HUD-02 | Forecast dismiss within 80ms on hover-off / target change | ADR-0015 R-9 + Verification §4 (per-story performance gate) ✅ |
| AC-UX-HUD-03 | Chevron tier glyphs render correctly | ADR-0015 §2 (UI-GB-04 child element — implementation-time) ✅ |
| AC-UX-HUD-04 | Touch viewport chevron hit area ≥ 44×44pt | ADR-0015 R-8 + Verification §3 (CI lint enforces) ✅ |
| AC-UX-HUD-05 | No 주홍/금색 reserved colors render in any UI-GB-04 variant | ADR-0015 §2 (palette discipline; implementation-time art-director sign-off) ✅ |
| AC-UX-HUD-06 | DEFEND_STANCE 守 seal renders on defending unit's tile | ADR-0015 §5 `_on_unit_turn_started` ✅ |
| AC-UX-HUD-07 | DEFEND_STANCE seal expires on next `unit_turn_started` for that unit | ADR-0015 §5 `_on_unit_turn_started` ✅ |
| AC-UX-HUD-08 | Mobile DEFEND two-tap confirm contract | ADR-0015 §OQ-4 + battle-hud.md §5.2 (HUD owns timer; InputRouter receives synthetic event) ✅ |
| AC-UX-HUD-09 | Mobile ATTACK two-tap confirm contract | ADR-0015 §OQ-4 + battle-hud.md §5.1 (same pattern as DEFEND) ✅ |

**Untraced Requirements**: **None at the architectural level** — all 14 UI-GB-* + 9 AC-UX-HUD-* are covered by ADR-0015 sections explicitly. **TR backfill needed**: TR-IDs for battle-hud are NOT yet in `docs/architecture/tr-registry.yaml` — to be backfilled via `/architecture-review` delta in fresh session.

## Stories

> Not yet created — run `/create-stories battle-hud` to break this epic into implementable stories.

**Estimated story count**: 5-8 stories (~12-20h total). Larger than typical Core/Foundation epics due to (a) 14 UI-GB-* elements requiring per-element scenes + scripts, (b) HIGH engine risk requiring 7 verification items as per-story acceptance gates, (c) Pillar 2 lock requiring dedicated lint story + dedicated test story, (d) cross-platform render verification (macOS Metal + Linux Vulkan + Windows D3D12 + Android Vulkan + iOS Metal — post-MVP).

**Anticipated story shape** (final decomposition during `/create-stories`):

| # | Story (anticipated) | Type | TR-IDs | Estimate |
|---|---|---|---|---|
| 001 | BattleHUD class skeleton + 9-param `setup()` DI + `_ready()` 9-backend assertion + `_exit_tree()` 11-disconnect cleanup + scene mount under CanvasLayer | Logic (skeleton) | (ADR-0015 §1, §3, §10) | 2-3h |
| 002 | 11 GameBus signal subscriptions with CONNECT_DEFERRED + per-handler stub bodies + DI test seam `_handle_signal(name, args)` | Logic | (ADR-0015 §3, §5) | 2-3h |
| 003 | UI-GB-03 Unit Info Panel (full populate via `_on_unit_selected_changed` + `_hp_controller.get_*` queries + `_hero_db.get_hero`) + UI-GB-11 DEFEND Stance Badge | UI | (ADR-0015 §5 + battle-hud.md §3 UI-GB-03/11) | 3h |
| 004 | UI-GB-01 Initiative Queue + UI-GB-07 Turn/Round Counter + UI-GB-08 Victory Condition Display | UI | (ADR-0015 §5 + battle-hud.md §3 UI-GB-01/07/08) | 3h |
| 005 | UI-GB-02 Action Menu + UI-GB-05 Skill List + UI-GB-10 Undo Indicator + Two-tap ATTACK/DEFEND confirm flows (HUD owns timer) | UI + Integration | (ADR-0015 §4, §OQ-4 + battle-hud.md §3 UI-GB-02/05/10 + §5) | 4h |
| 006 | UI-GB-04 Combat Forecast (full forecast contract per battle-hud.md §4 — all 6 sections + chevron tiers + 80ms dismiss + FORECAST_RENDER_BUDGET_MS budget gate) | UI + Performance | (ADR-0015 §5 + battle-hud.md §4) | 4h |
| 007 | UI-GB-06 Tile Info Tooltip (`show_tile_info` public method) + UI-GB-09 End-of-Battle Results Screen (battle_outcome_resolved handler — Pillar 2 preservation: outcome only, no fate counter detail) + UI-GB-12/13/14 grid-layer overlays | UI + Integration | (ADR-0015 §4, §5 + battle-hud.md §3) | 4h |
| 008 | Epic terminal — 5 lints (hidden_fate_non_subscription + signal_emission + exit_tree_disconnect + touch_target_size + connect_deferred) + 1 BalanceConstants key-presence lint + FORECAST_RENDER_BUDGET_MS BalanceConstants entry + verification summary doc + 7 Verification items closure + epic Complete | Config/Data + Audit | (ADR-0015 §Engine Compatibility + §10 Migration Plan) | 3h |

**Implementation order**: 001 → 002 → {003, 004 in parallel after 002} → 005 → 006 → 007 → 008 (epic terminal).

**Sprint allocation**: All 5-8 stories deferred to **sprint-6** (per sprint-5 plan; S5-13 ships scaffold only). Sprint-6 also wires the BattleScene that mounts BattleHUD as `CanvasLayer/BattleHUD` child — Battle Scene wiring ADR (NOT YET WRITTEN) is the natural sprint-6 partner ADR.

## Definition of Done

This epic is complete when:
- All 5-8 stories implemented + Complete
- `src/feature/battle_hud/battle_hud.gd` exists with `class_name BattleHUD extends Control`
- `_exit_tree()` body explicitly disconnects all 11 GameBus subscriptions (per ADR-0015 R-7 + battle_hud_missing_exit_tree_disconnect forbidden_pattern)
- Zero `GameBus.*.emit` calls in HUD source (non-emitter discipline; per battle_hud_signal_emission forbidden_pattern lint)
- **Zero `hidden_fate_condition_progressed` token occurrences in HUD source** (Pillar 2 lock; per battle_hud_subscribes_to_hidden_fate_signal forbidden_pattern lint — CRITICAL)
- All 14 UI-GB-* elements rendered per `design/ux/battle-hud.md` v1.1 specs
- All 6+ AC-UX-HUD-* acceptance criteria PASS
- 5 forbidden_pattern lints + 1 BalanceConstants key-presence lint = **6 lints all PASS**
- 6 lint steps wired into `.github/workflows/tests.yml`
- `FORECAST_RENDER_BUDGET_MS = 120` shipped in `assets/data/balance/balance_entities.json`
- `scenes/battle/battle_hud.tscn` + 14 child element scenes shipped
- Full GdUnit4 regression: ≥870-880 cases / 0 errors / 0 failures / 0 orphans / Exit 0 (current 841 + ~30-40 from battle-hud test files = ~870-880 estimated)
- All 7 Engine Compatibility verification items closed: dual-focus + AccessKit + 44pt + forecast 80ms + recursive Control disable + CONNECT_DEFERRED discipline + Pillar 2 lint
- **ADR-0015 escalated from Proposed → Accepted** via `/architecture-review` delta (separate session prerequisite; epic stories cannot ship until ADR Accepted)
- `production/qa/evidence/battle_hud_verification_summary.md` shipped (epic-terminal rollup doc per grid-battle-controller story-010 precedent)
- TR registry backfilled with battle-hud TR-IDs via `/architecture-review` delta (separate prerequisite)

## Test Baseline (target)

- **Current pre-impl**: 841/841 PASS (post-grid-battle-controller epic close 2026-05-03; **19th consecutive failure-free baseline**)
- **Target post-impl**: ≥870-880 PASS (estimated +30-40 from 5-8 stories' tests; per-element rendering tests + signal-handler tests + DI seam test + Pillar 2 source-lint test)
- **Performance baseline**:
  - Per-frame steady-state HUD update < 1.0ms p99 on Pixel 7-class hardware (Adreno 610 / Mali-G57 reference)
  - Forecast burst budget ≤ 120ms p99 on Pixel 7-class hardware (FORECAST_RENDER_BUDGET_MS)
  - End-of-battle results render ≤ 200ms p99
  - Headless throughput: 100 synthetic battle action signals fully rendered < 100ms (avg < 1ms per signal)

## Engine Compatibility Verification Items

7 mandatory verification items as per-story acceptance gates (per ADR-0015 §Engine Compatibility table). Each item is a DEFINITION-OF-DONE gate, not advisory:

| # | Item | Risk | KEEP through | Story owner |
|---|---|---|---|---|
| 1 | Dual-focus end-to-end (mouse hover + keyboard focus simultaneous on macOS Metal + Linux Vulkan; touch-only on Pixel 7) | HIGH | Polish | story-006 (Combat Forecast) |
| 2 | AccessKit screen reader announcement (macOS VoiceOver — UI-GB-03 announces unit name + HP + status on focus change) | HIGH | Post-MVP a11y audit | story-003 (Unit Info Panel) |
| 3 | 44pt touch target enforcement (CI lint asserts every interactive Control ≥ 44×44pt) | CRITICAL | Forever | story-008 (Epic Terminal) |
| 4 | Forecast 80ms dismiss latency on Pixel 7-class hardware (Performance.get_monitor instrumentation) | HIGH | Polish | story-006 (Combat Forecast) |
| 5 | Recursive `MOUSE_FILTER_IGNORE` propagation (4.5 — integration test asserts Button.pressed not emitted while root IGNORE) | MEDIUM | Polish | story-002 (signal subscriptions + S5 INPUT_BLOCKED handler) |
| 6 | CONNECT_DEFERRED discipline (CI lint asserts all 11 subscriptions use CONNECT_DEFERRED flag) | LOW | Forever | story-008 (Epic Terminal) |
| 7 | **Pillar 2 hidden-fate non-subscription** (CI lint asserts zero `hidden_fate_condition_progressed` token in HUD source) | **CRITICAL** | **Forever** | story-008 (Epic Terminal) |

## Risks

- **R-1: ADR-0015 Proposed → Accepted blocker** — epic stories cannot ship implementation until ADR is Accepted via `/architecture-review` delta in fresh session. **Mitigation**: schedule `/architecture-review` immediately after sprint-5 close ceremony; sprint-6 plan includes the delta as first item.
- **R-2: HIGH engine risk requires real-device verification** — 7 Verification items include cross-platform tests on Pixel 7 + macOS Metal + Linux Vulkan + Windows D3D12 + Android Vulkan + iOS Metal. **Mitigation**: per-story acceptance gates; soak-test in Polish phase; Android TalkBack deferred post-MVP per design/ux/accessibility-requirements.md §4.
- **R-3: InputRouter not yet shipped (Foundation epic Ready, not Complete)** — battle-hud impl stories that exercise InputRouter integration may need stubs OR may sequence after input-handling impl ships. **Mitigation**: first story authoring (story-001) verifies InputRouter shipped state; story-002 + story-005 + story-007 are the InputRouter-integration-heavy stories — sequence after input-handling Complete OR use stubs.
- **R-4: Pillar 2 lint fragility on multi-file split** — if HUD source is split across multiple files in a future refactor (e.g., `battle_hud.gd` + `battle_hud_signal_handlers.gd` + `battle_hud_overlay_manager.gd`), the lint must update its file list. **Mitigation**: lint script reads from a project-wide `BATTLE_HUD_SOURCE_FILES` env var or `.config` file; first story authors the convention. Same risk class as ADR-0014's grid-battle-controller lints.
- **R-5: Two-tap timer ownership ambiguity** (battle-hud.md §5 vs. ADR-0005 InputRouter S2 confirm flow) — ADR-0015 §OQ-4 resolves: HUD owns timer, InputRouter receives synthetic event. First story (story-005) verifies the synthetic-event injection path against shipped InputRouter `_handle_event` test seam.
- **R-6: 14 UI-GB-* elements + 13 visual/audio specs scope creep** — implementation-time art-director sign-off required per `design/ux/accessibility-requirements.md` §4 contrast verification. **Mitigation**: per-story acceptance gate includes art-director sign-off where palette/contrast values are touched; explicit deferrals codified in MVP Scope above.
- **R-7: Performance budget burst on minimum-spec mobile** — `FORECAST_RENDER_BUDGET_MS = 120` is a worst-case burst; if breached on Pixel 7-class hardware, forecast feels laggy and Pillar 1 reading flow degrades. **Mitigation**: instrumentation in story-006 + soak-test in Polish phase; tuning knob is Alpha-tier (range 80-200) so registry-side adjustment is the first remediation lever.

## Next Step

**Run `/create-stories battle-hud`** to break this epic into 5-8 implementable stories. Then `/qa-plan battle-hud` (per per-epic QA plan strategy locked sprint-2 Phase 5; mandatory before first `/dev-story battle-hud/story-001`).

**Prerequisite for sprint-6 implementation**: `/architecture-review` delta in fresh session to escalate ADR-0015 from Proposed → Accepted (cannot run in same session as `/architecture-decision` per skill rule).

**Sprint-6 forward look**: Battle HUD impl + Battle Scene wiring + Scenario Progression ADR + Destiny Branch ADR. Battle HUD is the **first user-visible-surface system** that USES the 5 controller-LOCAL signals shipped sprint-5 — completes the +1 playable-surface delta started in sprint-4 with BattleCamera. Sprint-6 = Battle Scene + first chapter playable = next +1.

## Cross-References

- **Governing ADR**: `docs/architecture/ADR-0015-battle-hud.md` (~620 LoC; godot-specialist PASS WITH 3 REVISIONS resolved; **Proposed** status pending /architecture-review delta)
- **Design source-of-truth**: `design/ux/battle-hud.md` v1.1 (744 lines — UI-GB-01..14 elements + 13 visual/audio specs + forecast contract + two-tap mobile flows + palette/accessibility + 6 AC-UX-HUD-* + 5 OQs)
- **Pillar 2 source-of-truth**: `design/gdd/game-concept.md` Pillar 2 (운명은 바꿀 수 있다) + `design/gdd/destiny-branch.md` Section B (wordless pre-linguistic realization at Beat 7)
- **Coordinated GDDs**: `design/gdd/grid-battle.md` (CR-12 signal emission; UI-GB-* mirror references); `design/gdd/hp-status.md` (DEFEND_STANCE 1-turn duration); `design/gdd/turn-order.md` (initiative queue snapshot); `design/gdd/input-handling.md` (Touch Tap Preview Protocol CR-4a + Magnifier Panel CR-4c); `design/gdd/formation-bonus.md` (Formation Aura visual derivation)
- **Coordinated UX specs**: `design/ux/accessibility-requirements.md` (R-2 announcements + WCAG 1.4.11 contrast + 44pt touch target); `design/ux/interaction-patterns.md` (IP-006 redundancy triad + Beat-7 carve-out)
- **Sprint**: `production/sprints/sprint-5.md` S5-13 (scaffold only); implementation in sprint-6
- **Architecture registry**: `docs/registry/architecture.yaml` v8 (1 state_ownership + 1 interface + 1 performance_budget + 1 api_decision + 5 forbidden_patterns ratifying ADR-0015 ratifications)
