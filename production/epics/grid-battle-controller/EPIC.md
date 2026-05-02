# Epic: Grid Battle Controller

> **Layer**: Feature (battle orchestrator)
> **GDD**: `design/gdd/grid-battle.md` (1259 lines — **MVP subset only** consumed per ADR-0014 §0; full Alpha-tier scope deferred)
> **Architecture Module**: `GridBattleController` — battle-scoped Node at `BattleScene/GridBattleController` (4th invocation of pattern)
> **Status**: **Ready** (2026-05-02 — sprint-4 S4-04 scaffold; awaiting `/qa-plan grid-battle-controller` + sprint-5 implementation)
> **Stories**: 10/10 created (2026-05-02 via S4-04); 0/10 Complete
> **Created**: 2026-05-02 (Sprint 4 S4-04)

## Stories

| # | Story | Type | Status | TR-IDs | ACs | Estimate |
|---|-------|------|--------|--------|-----|----------|
| [001](story-001-class-skeleton-and-di.md) | GridBattleController class + 8-param `setup()` DI + `_ready()` 6-backend assertion + `_exit_tree()` cleanup with explicit CONNECT_DEFERRED-load-bearing comment | Logic (skeleton) | Ready | (ADR-0014 §1, §3, §10) | DI assertion + class_name verified | 2h |
| [002](story-002-battle-unit-resource-and-registry.md) | `BattleUnit` typed Resource (~10 fields) + `_units: Dictionary[int, BattleUnit]` registry + initialization from `setup()` + tag-based fate-counter unit detection | Logic | Ready | (ADR-0014 §3) | BattleUnit class + registry populated + 3 fate unit IDs detected | 2h |
| [003](story-003-fsm-and-input-dispatch.md) | 2-state FSM (OBSERVATION / UNIT_SELECTED) + `_on_input_action_fired` 10-grid-action filter + `_handle_grid_click` dispatch + selection state | Logic | Ready | (ADR-0014 §2, §4) | FSM transitions + action filter + click→handler routing | 3h |
| [004](story-004-move-action.md) | `is_tile_in_move_range(tile, unit_id)` callback + `_handle_move` + `_do_move` position update + `unit_moved(unit_id, from, to)` signal | Logic | Ready | (ADR-0014 §10 + grid-battle.md §123, §612) | move range query + action validation + signal emit | 3h |
| [005](story-005-attack-action-and-resolve.md) | `is_tile_in_attack_range(tile, unit_id)` + `_resolve_attack` (formation count + angle classification + aura check) + `DamageCalc.resolve(...)` static-call + `HPStatusController.apply_damage(unit_id, dmg, attack_type, source_flags)` 4-param call + `apply_death_consequences` (per grid-battle.md line 198) + `damage_applied` signal | Logic | Ready | (ADR-0014 §5 + grid-battle.md §198 + Implementation Notes) | resolve_attack chain + multipliers correct + damage_applied emit | 4h |
| [006](story-006-per-turn-action-consumption.md) | `_acted_this_turn` Dictionary[int, bool] + `_consume_unit_action` + `end_player_turn()` + auto-end-turn-when-all-acted + `TurnOrderRunner.spend_action_token` integration (single-token MVP simplification per ADR-0014 §6) | Logic | Ready | (ADR-0014 §6) | per-turn tracking + auto-handoff + token spend | 3h |
| [007](story-007-five-turn-limit.md) | `_on_round_started(round_num)` subscription + `MAX_TURNS_PER_BATTLE` BalanceConstants (=5 default) + `battle_outcome_resolved("TURN_LIMIT_REACHED", fate_data)` signal emission on round 6 entry | Logic | Ready | (ADR-0014 §7) | turn counter + outcome signal on overflow | 2h |
| [008](story-008-hidden-fate-condition-tracking.md) | 5 hidden counters (`_fate_rear_attacks` / `_fate_formation_turns` / `_fate_assassin_kills` / `_fate_boss_killed` + tank HP queried on-demand from HPStatusController) + `hidden_fate_condition_progressed(condition_id, value)` signal — Battle HUD does NOT subscribe (preserves "hidden" semantic for Destiny Branch ONLY) | Logic | Ready | (ADR-0014 §8 + game-concept.md Pillar 2) | 5 counters increment + signal channel correct | 3h |
| [009](story-009-cross-adr-exit-tree-audit.md) | Verify ADR-0010 HPStatusController `_exit_tree()` exists with autoload-disconnect (per ADR-0013 R-7 + TD-057 — partial false alarm: hp-status already has it; this story closes the audit and verifies TurnOrderRunner) | Config/Data (audit) | Ready | (ADR-0013 R-7 follow-up) | 2 cross-ADR Node systems audited; TD-057 final status logged | 1h |
| [010](story-010-epic-terminal-perf-lints-evidence.md) | Epic terminal — perf baseline (per-event < 0.5ms; 100 actions < 100ms p99) + 3 forbidden_pattern lints (signal_emission_outside_battle_domain + static_state + external_combat_math) + 6 BalanceConstants additions (MAX_TURNS_PER_BATTLE + 5 fate-condition thresholds) + epic-terminal commit | Config/Data | Ready | (ADR-0014 §11) | perf + lints PASS + epic close | 3h |

**Total estimate**: ~26h = ~3.25 working days. Larger than camera epic (6h actual) due to 10 stories vs 7 + per-story scope is meaningfully larger (BattleUnit Resource design + FSM + 4 backend integrations per story).

**Implementation order**: 001 → 002 → 003 → {004, 005, 006, 008 in parallel after 003} → 007 → 009 → 010 (epic terminal).

**Sprint allocation**: All 10 stories deferred to **sprint-5** (per sprint-4 plan; S4-04 ships scaffold only).

## Overview

The Grid Battle Controller epic implements `GridBattleController` — the **central battle orchestrator** that owns unit state + FSM + per-turn action tracking, integrates 6 shipped backend systems (TurnOrderRunner + HPStatusController + HeroDatabase + MapGrid + TerrainEffect + UnitRole) + DamageCalc (static-call) + BattleCamera (DI'd), and emits 5 controller-LOCAL signals consumed by Battle HUD + Scenario Progression + Destiny Branch.

This is the **largest Feature-layer Node-based system** + **4th invocation** of the battle-scoped Node pattern (after ADR-0010 HPStatusController + ADR-0011 TurnOrderRunner + ADR-0013 BattleCamera).

## MVP Scope (per ADR-0014 §0 — explicit deferral structure)

The full `grid-battle.md` GDD is 1259 lines with full Alpha-tier scope. **This epic implements only the MVP subset** for the 장판파 first-chapter playable surface:

- ✅ MOVE + ATTACK actions (no skills)
- ✅ Player-only turns (no AI integration)
- ✅ 5-turn limit
- ✅ Single chapter (장판파)
- ✅ Melee adjacency (sole exception: 황충 range-2 ranged attack)
- ✅ Inline formation/angle math (chapter-prototype proven shape)
- ✅ 5 hidden fate-condition counters

**Explicit deferrals** (each future ADR slot reserved):
- ❌ AI substate machine (Battle AI ADR — sprint-7+)
- ❌ FormationBonusSystem orchestration (Formation Bonus ADR — post-MVP)
- ❌ Rally orchestration (Rally ADR — post-MVP)
- ❌ USE_SKILL counter eligibility + AOE_ALL (Skill ADR — post-MVP)

When each future ADR ships, this epic is **amended** (additive — new signal subscriptions, new helper methods) or **superseded by** a successor ADR.

## Pattern Boundary Precedent

GridBattleController is the **4th invocation** of the battle-scoped Node pattern. Pattern stable. Future battle-scoped Node systems (Battle HUD ADR — sprint-5) follow same DI + `_exit_tree()` discipline + `_resolve` reentrance prevention via CONNECT_DEFERRED on lethal-damage chain.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| **ADR-0014 Grid Battle Controller** (Accepted 2026-05-02) | `GridBattleController` battle-scoped Node; 8-param DI `setup()` (DamageCalc NOT in DI per godot-specialist revision #2 — static func); 2-state FSM; 5 controller-LOCAL signals (NOT GameBus); 5 hidden fate counters; CONNECT_DEFERRED on `unit_died` is LOAD-BEARING reentrance prevention (per godot-specialist revision #1). MVP-scoped per §0 with 4 deferral slots. | LOW |
| ADR-0013 BattleCamera (Accepted 2026-05-02) | DI dependency; `BattleCamera.screen_to_grid` consumed for click hit-testing per input-handling §9 Bidirectional Contract | LOW |
| ADR-0001 GameBus | Subscribes to `input_action_fired` via `Object.CONNECT_DEFERRED` filtered for 10 grid-domain actions; non-emitter to GameBus (5 controller-local signals instead) | LOW |
| ADR-0010 HPStatusController | DI dependency; sole writer of unit HP per ownership contract; `apply_damage(unit_id, resolved_damage, attack_type, source_flags)` 4-param signature; `is_alive(unit_id)` canonical query; `apply_death_consequences(unit_id)` invoked EXPLICITLY per grid-battle.md line 198 before victory check | LOW |
| ADR-0011 TurnOrderRunner | DI dependency; consumes initiative queue + token API per Contract 4 (MVP simplifies to single action token per ADR-0014 §6) | LOW |
| ADR-0012 DamageCalc | **NOT DI'd** — static-method call site `DamageCalc.resolve(attacker, defender, modifiers)` per godot-specialist revision #2; sole-caller contract per damage-calc.md line 260 honored | LOW |
| ADR-0007 HeroDatabase | DI dependency; roster lookup at battle init; BattleUnit Resource carries hero_id reference | LOW |
| ADR-0004 MapGrid | DI dependency; consumed for terrain queries + dimensions for clamp + tile data | LOW |
| ADR-0008 TerrainEffect | DI dependency; per-tile modifier query (defense bonus, evasion bonus) for combat resolution | LOW |
| ADR-0009 UnitRole | DI dependency; class-based derived stats (effective_atk / effective_def / effective_hp / effective_initiative / move_range / class_cost_table) | LOW |
| ADR-0006 BalanceConstants | 6 new entries: `MAX_TURNS_PER_BATTLE` + 5 fate-condition thresholds (though Destiny Branch ADR may claim ownership of the 5 thresholds — final placement decided at story-010 epic-terminal authoring) | LOW |

**Highest Engine Risk**: LOW across all governing ADRs. No post-cutoff API surface. The architectural complexity is in the *integration shape*, not in any individual API.

## Same-Patch Obligations from ADR-0014 Acceptance

1. **6 BalanceConstants additions** to `assets/data/balance/balance_entities.json` (story-010 epic-terminal): `MAX_TURNS_PER_BATTLE` + 5 fate-condition thresholds. (Final placement of fate thresholds may shift to Destiny Branch ADR; placeholder lives here for MVP.)
2. **3 forbidden_patterns** registered (already in `docs/registry/architecture.yaml` via ADR-0014 commit): `grid_battle_controller_signal_emission_outside_battle_domain` + `grid_battle_controller_static_state` + `grid_battle_controller_external_combat_math`.
3. **3 CI lint scripts** at `tools/ci/lint_grid_battle_controller_*.sh` + 1 BalanceConstants key-presence lint, wired into `.github/workflows/tests.yml` (story-010 epic-terminal).
4. **`ResolveModifiers` Resource extension**: 3 new fields (`formation_atk_bonus: float`, `angle_mult: float`, `aura_mult: float`) — additive per ADR-0012 schema-evolution rules; ships in story-005 same-patch obligation.
5. **5 controller-LOCAL signals** declared on GridBattleController class: `unit_selected_changed` + `unit_moved` + `damage_applied` + `battle_outcome_resolved` + `hidden_fate_condition_progressed` (NOT added to ADR-0001 §7 GameBus schema; signals are LOCAL per ADR-0014 §8 + R-1 50-emits/frame budget).

## Cross-System Dependencies

The 6 DI'd backends (+ DamageCalc static-call + BattleCamera DI'd) are **all already shipped to production** — this epic is the *integration site*, not a build-from-scratch. Heavy reuse:

- **TurnOrderRunner** (Core, Complete 2026-05-02) — `spend_action_token`, `unit_turn_started` signal, `round_started` signal
- **HPStatusController** (Core, Complete 2026-05-02) — `apply_damage(4-param)`, `apply_death_consequences(unit_id)`, `is_alive(unit_id)`, `unit_died` signal
- **DamageCalc** (Feature, Complete 2026-04-27) — `static func resolve(attacker, defender, modifiers) -> int`
- **HeroDatabase** (Foundation, Complete 2026-05-01) — `get_hero(hero_id)` query
- **MapGrid** (Foundation, Complete 2026-04-25) — `get_map_dimensions()`, `get_tile(coord)`, `set_occupant(coord, unit_id, faction)`, `clear_occupant(coord)`
- **TerrainEffect** (Core, Complete 2026-04-26) — modifier query API
- **UnitRole** (Foundation, Complete 2026-04-28) — class-based derived stats
- **BattleCamera** (Feature, Complete 2026-05-02) — `screen_to_grid(screen_pos: Vector2) -> Vector2i`
- **GameBus** (Platform, Complete 2026-04-21) — `input_action_fired(action: String, ctx: InputContext)` consumer

**Test stub strategy**: extend existing `tests/helpers/map_grid_stub.gd` (from hp-status epic) + new stubs for each backend `tests/helpers/{turn_order_runner,hp_status_controller,hero_database,terrain_effect,unit_role,damage_calc,battle_camera}_stub.gd`. Tests use stubs for unit-level isolation; integration tests use real backends.

## Definition of Done

This epic is complete when:
- All 10 stories implemented + Complete
- `src/feature/grid_battle/grid_battle_controller.gd` exists with `class_name GridBattleController extends Node`
- `_exit_tree()` body explicitly disconnects all 4 signal subscriptions (per ADR-0014 §3 + R-4)
- All 5 controller-LOCAL signals declared + emitted at correct sites
- 3 forbidden_pattern lints + 1 BalanceConstants key-presence lint = 4 lints all PASS
- 4 lint steps wired into `.github/workflows/tests.yml`
- Full GdUnit4 regression: ≥780 cases / 0 errors / 0 failures / 0 orphans / Exit 0 (current 757 + ~25 from grid-battle-controller test files = ~782 estimated)
- ResolveModifiers Resource extended with 3 new fields (back-compat additive)
- TD-057 cross-ADR `_exit_tree` audit closed (HPStatusController already has it; story-009 verifies TurnOrderRunner)
- 5 hidden fate-condition counters tracked silently — Destiny Branch ADR (sprint-6) consumes via `hidden_fate_condition_progressed` signal channel

## Test Baseline (target)

- **Current pre-impl**: 757/757 PASS (post-camera epic)
- **Target post-impl**: ≥780-790 PASS (estimated +25-35 from 10 stories' tests)
- **Performance baseline**: per-event handler < 0.05ms p99; per-attack chain < 0.5ms p99; 100 synthetic battle actions < 100ms

## Next Step

Sprint-5 kickoff: `/qa-plan grid-battle-controller` (per per-epic QA plan strategy locked sprint-2 Phase 5; mandatory before first /dev-story); then begin implementation with story-001.

The grid-battle-controller epic is **prerequisite for sprint-6 Battle Scene wiring** + Battle HUD ADR (sprint-5) + Scenario Progression ADR (sprint-6) + Destiny Branch ADR (sprint-6). Sprint-5 will likely focus exclusively on this epic plus Battle HUD authoring/scaffold.

## Cross-References

- **Governing ADR**: `docs/architecture/ADR-0014-grid-battle-controller.md` (~510 LoC, godot-specialist PASS WITH 2 REVISIONS resolved)
- **Design brief (throwaway)**: `prototypes/chapter-prototype/battle_v2.gd` (~720 LoC — MVP shape proven; production rewritten from scratch per /prototype skill rules)
- **GDD**: `design/gdd/grid-battle.md` (1259 lines — MVP subset only consumed)
- **Coordinated GDDs**: damage-calc.md (sole-caller contract) + hp-status.md (DEFEND_STANCE delegation per AC-GB-10b) + turn-order.md (Contract 4) + input-handling.md (§9 Bidirectional Contract partner; provides callbacks)
- **Sprint**: `production/sprints/sprint-4.md` S4-04 (scaffold only); implementation in sprint-5
