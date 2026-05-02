# Sprint 5 — 2026-05-17 to 2026-05-23

> **Review mode**: lean (per `production/review-mode.txt`) — PR-SPRINT director gate skipped
> **Manifest Version**: 2026-04-20 (`docs/architecture/control-manifest.md`)
> **Generated**: 2026-05-02
> **Carries**: sprint-4 retrospective AI #4 (Critical) — grid-battle-controller implementation focus + Battle HUD ADR/scaffold

## Sprint Goal

**Ship grid-battle-controller epic end-to-end + author Battle HUD ADR**. Grid-battle-controller is the central battle orchestrator (4th invocation of battle-scoped Node pattern); landing it makes the BattleScene mount-able. Battle HUD ADR locks the player-facing surface contract for sprint-6 chapter wiring. **Playable-surface delta target: +1** (sprint-4 was the first +1; sprint-5 makes it +2 cumulative).

## Pivot context (carried from sprint-4)

Sprint-4 was the inflection point: 11 backend epics → 2 prototypes → first user-visible-surface ship (BattleCamera). Sprint-5 doubles down on production code: grid-battle-controller is the integration site for 7 shipped backends (TurnOrderRunner + HPStatusController + DamageCalc + HeroDatabase + MapGrid + TerrainEffect + UnitRole + BattleCamera + GameBus) + 5 controller-LOCAL signals consumed by Battle HUD/Scenario Progression/Destiny Branch.

Sprint-6 = Battle Scene wiring + first chapter (장판파) playable. Sprint-5 must make sprint-6 viable.

## Capacity (per retro AI #1 — continued tightening)

- Total days: **7 calendar → 5 working**
- Buffer (15%): **0.75 day** for unplanned work
- Available: **4.25 working days**

Note: sprint-4 actual ship pattern = 5 planned days collapsed to 1 calendar day. Estimate listed below is *nominal* (epic file estimate); actual may converge much faster. Per AI #1, Should-Have items are the slack — drop them if Must-Have runs long.

## Context

Project state as of 2026-05-02 (post-sprint-4 close):

- **Sprint-4 closed 5/7** (Must-have 4/4 + Should-have 1/2 + Nice-to-have 0/1; 2 asset items DEFERRED to user-owner)
- **All 14 ADRs Accepted** (12 prior + ADR-0013 Camera + ADR-0014 Grid Battle Controller)
- **12 epics Complete + 1 Ready** (Platform 3/3 + Foundation 4/5 + Core 3/4 + Feature 2/13 + grid-battle-controller Ready)
- **Full regression**: 757 testcases / 0 errors / 0 failures / 0 orphans (9th consecutive failure-free baseline)
- **First user-visible-surface code shipped** (`src/feature/camera/battle_camera.gd` ~140 LoC + 14 tests)
- **`src/ui/` still empty** — Battle HUD ADR sprint-5 cracks it; impl in sprint-6

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S5-01 | `/qa-plan grid-battle-controller` — per-epic QA discipline (locked sprint-2 Phase 5) before first `/dev-story` | claude | 0.15 | — | `production/qa/qa-plan-grid-battle-controller-2026-05-XX.md` exists; 10 stories classified Logic/Integration; test count target locked |
| S5-02 | grid-battle-controller story-001: GridBattleController class skeleton + 8-param `setup()` DI + `_ready()` 6-backend assertion + `_exit_tree()` cleanup with CONNECT_DEFERRED-load-bearing comment | claude | 0.25 | S5-01 | story file Complete + DI assertion test + class_name verified; full regression PASS |
| S5-03 | story-002: BattleUnit typed Resource (~10 fields) + `_units: Dictionary[int, BattleUnit]` registry init from `setup()` + tag-based fate-counter unit detection | claude | 0.25 | S5-02 | story Complete + Resource + registry populated + 3 fate unit IDs detected |
| S5-04 | story-003: 2-state FSM (OBSERVATION / UNIT_SELECTED) + `_on_input_action_fired` 10-grid-action filter + `_handle_grid_click` dispatch + selection state | claude | 0.4 | S5-03 | story Complete + FSM transitions + action filter + click→handler routing tests |
| S5-05 | story-004: MOVE action — `is_tile_in_move_range` callback + `_handle_move` + `_do_move` position update + `unit_moved(unit_id, from, to)` signal | claude | 0.4 | S5-04 | story Complete + range query + action validation + signal emit |
| S5-06 | story-005: ATTACK action — `is_tile_in_attack_range` + `_resolve_attack` (formation/angle/aura) + `DamageCalc.resolve(...)` static-call + `HPStatusController.apply_damage(4-param)` + `apply_death_consequences` + `damage_applied` signal + ResolveModifiers schema extension (3 new fields, additive) | claude | 0.5 | S5-05 | story Complete + resolve chain + multipliers correct + signal emit + ResolveModifiers extension back-compat |
| S5-07 | story-006: per-turn action consumption — `_acted_this_turn` Dictionary + `_consume_unit_action` + `end_player_turn()` + auto-end-turn-when-all-acted + `TurnOrderRunner.spend_action_token` integration (single-token MVP) | claude | 0.4 | S5-06 | story Complete + per-turn tracking + auto-handoff + token spend |
| S5-08 | story-007: 5-turn limit — `_on_round_started(round_num)` subscription + `MAX_TURNS_PER_BATTLE` BalanceConstants (=5) + `battle_outcome_resolved("TURN_LIMIT_REACHED", fate_data)` signal on round 6 | claude | 0.25 | S5-07 | story Complete + turn counter + outcome signal on overflow |
| S5-09 | story-008: hidden fate-condition tracking — 5 hidden counters (rear_attacks/formation_turns/assassin_kills/boss_killed/tank_hp queried on-demand) + `hidden_fate_condition_progressed(condition_id, value)` signal — Battle HUD does NOT subscribe (preserves "hidden" semantic for Destiny Branch ONLY) | claude | 0.4 | S5-07 | story Complete + 5 counters increment + signal channel correct |
| S5-10 | story-009: cross-ADR `_exit_tree` audit — verify HPStatusController already has it (TD-057 partial false alarm) + verify TurnOrderRunner status; close TD-057 final | claude | 0.15 | — | story Complete + 2 systems audited + TD-057 final status logged |
| S5-11 | story-010: epic-terminal — perf baseline (per-event < 0.5ms; 100 actions < 100ms p99) + 3 forbidden_pattern lints + 6 BalanceConstants additions + 1 key-presence lint + CI wiring; epic Complete commit | claude | 0.4 | S5-02..S5-10 | epic Complete; 4 lints + perf PASS; ≥780 PASS / 0 errors regression |

**Must-have subtotal: ~3.55 working days nominal** (~28h).

### Should Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S5-12 | **ADR-0015 Battle HUD** — `/architecture-decision` Battle HUD as battle-scoped Control (CanvasLayer child) consuming GridBattleController's 5 LOCAL signals (`unit_selected_changed` + `unit_moved` + `damage_applied` + `battle_outcome_resolved`; explicitly NOT `hidden_fate_condition_progressed`) + BattleCamera state queries; godot-specialist 3-pass review per sprint-4 retro AI #3 | claude | 0.4 | S5-11 (or parallel with S5-09/S5-10) | ADR file Accepted; cross-references all 5 LOCAL signals + Camera state queries; engine compatibility verified against Godot 4.6 Control/CanvasLayer API |
| S5-13 | Battle HUD epic + stories scaffold (~5-8 stories estimated; impl deferred to sprint-6) — same scaffold pattern as grid-battle-controller S4-04 | claude | 0.25 | S5-12 | Epic file at `production/epics/battle-hud/EPIC.md`; 5-8 stories Ready with TRs/ACs; epics-index.md updated |

**Should-have subtotal: ~0.65 working days nominal** (~5h).

### Nice to Have

(none — sprint-4 retro AI #1 calls for tighter scoping; Should-Have already buffers Battle HUD ADR work)

## Out of Scope

- **Battle HUD implementation** — deferred to sprint-6 (after sprint-5 ships ADR + scaffold; impl needs the surface to wire into)
- **Battle Scene wiring** — sprint-6 (depends on Battle HUD ADR + grid-battle-controller Complete)
- **Scenario Progression epic** — sprint-6 (chapter data structure depends on Grid Battle Controller signal shape, now known post-sprint-5)
- **Destiny Branch epic** — sprint-6 (consumes `hidden_fate_condition_progressed` signal from grid-battle-controller story-008)
- **AI substate machine** — sprint-7+ (per ADR-0014 §0 deferral slot; player-only turns this MVP)
- **FormationBonus / Rally / Skill orchestration ADRs** — post-MVP (per ADR-0014 §0 deferral slots)
- **Hero portrait + BGM gathering** — user-owner per sprint-4 retro AI #2; not blocking sprint-5

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|-------------|
| S4-05 hero portraits | DEFERRED to user-owner per retro AI #2; carries to sprint-6 prep | n/a (user) |
| S4-06 BGM candidates | DEFERRED to user-owner per retro AI #2; carries to sprint-6 prep | n/a (user) |

## Risks

- **R1**: 26h grid-battle-controller scope is the largest single epic implementation in the project to date (camera was ~6h actual). 10 stories × 4 backend integrations each = high coordination surface. **Mitigation**: epic file pre-scaffolded all 10 stories with TRs/ACs (sprint-4 S4-04); ADR-0014 has Implementation Notes flagging shipped-API shapes; chapter-prototype validated the integration shape end-to-end. Story-001 → 002 → 003 sequential; 004/005/006/008 parallel after 003.
- **R2**: ResolveModifiers Resource extension (story-005) is a back-compat schema change to a frozen ADR-0012 contract. **Mitigation**: per ADR-0012 schema-evolution rules (additive fields only), no existing damage-calc tests break. Lint `lint_resolve_modifiers_back_compat.sh` if needed.
- **R3**: CONNECT_DEFERRED on `unit_died` is load-bearing (sprint-4 godot-specialist revision #1). Future maintainers might "clean it up" without realizing reentrancy implications. **Mitigation**: api_decisions registry entry `unit_died_connect_deferred_load_bearing` documented; ADR-0014 §3 + R-4 + story-001 acceptance criterion explicitly require the comment.
- **R4**: Battle HUD ADR (S5-12) sequenced AFTER grid-battle-controller Complete to ensure signal contract is real (not aspirational). If S5-11 slips, S5-12 also slips. **Mitigation**: S5-12 can fall back to Should-Have skip; sprint-6 plans for "Battle HUD ADR + Battle Scene wiring + impl" if S5-12 slips.
- **R5**: 3.55d Must-Have + 0.65d Should-Have = 4.2d total — within 4.25d available capacity. Zero slack. **Mitigation**: per sprint-3+sprint-4 actual velocity (5d planned → 1 calendar day actual), real risk of over-shipping not under-shipping. Watch for "5×-faster-than-planned" pattern continuing; if Must-Have lands fast, S5-12+S5-13 are immediately addressable.

## Dependencies on External Factors

- None. All 7 backend dependencies (TurnOrderRunner + HPStatusController + DamageCalc + HeroDatabase + MapGrid + TerrainEffect + UnitRole + BattleCamera) are Complete and shipped.

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed (S5-01..S5-11 = qa-plan + 10 grid-battle-controller stories Complete)
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-grid-battle-controller-2026-05-XX.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] grid-battle-controller epic Complete (`production/epics/grid-battle-controller/EPIC.md` updated; 10/10 stories Complete)
- [ ] `src/feature/grid_battle/grid_battle_controller.gd` exists with `class_name GridBattleController extends Node`
- [ ] All 5 controller-LOCAL signals declared + emitted at correct sites
- [ ] 3 forbidden_pattern lints + 1 BalanceConstants key-presence lint = 4 lints all PASS in CI
- [ ] ResolveModifiers Resource extended with 3 new fields (back-compat additive)
- [ ] TD-057 cross-ADR `_exit_tree` audit closed
- [ ] Full GdUnit4 regression: ≥780 cases / 0 errors / 0 failures / 0 orphans / Exit 0 (target 785-790)
- [ ] `production/epics/index.md` updated: Feature layer 2/13 → 3/13 (grid-battle-controller Complete)
- [ ] `production/sprint-status.yaml` updated per the 200-byte cap discipline (S3-05 active)
- [ ] Sprint-5 retrospective written before sprint-6 kickoff

## Cross-References

- **Sprint-4 retro**: `production/retrospectives/retro-sprint-4-2026-05-02.md` (AI #4 = sprint-5 plan source)
- **Governing ADR**: `docs/architecture/ADR-0014-grid-battle-controller.md`
- **Governing ADR (Should-Have)**: ADR-0015 Battle HUD (to be authored S5-12)
- **Epic file**: `production/epics/grid-battle-controller/EPIC.md` (10 stories Ready)
- **Design briefs (throwaway)**: `prototypes/chapter-prototype/battle_v2.gd` (MVP shape proven)
- **GDD**: `design/gdd/grid-battle.md` (1259 LoC — MVP subset only per ADR-0014 §0)
- **Game concept**: `design/gdd/game-concept.md` (MVP Core Hypothesis line 296)
- **Prior sprints**: `production/sprints/sprint-{1,2,3,4}.md`

> **Scope check**: Sprint-5 stories all derive from grid-battle-controller EPIC.md (sprint-4 S4-04 scaffold). Run `/scope-check grid-battle-controller` before story-001 implementation to verify no scope creep beyond the 10-story scaffold.
