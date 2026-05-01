# Epic: Turn Order / Action Management

> **Layer**: Core
> **GDD**: `design/gdd/turn-order.md` (Accepted via ADR-0011 2026-04-30; Contract 5 layer-invariant resolution prose added 2026-05-01 via S2-06)
> **Architecture Module**: TurnOrderRunner — battle-scoped Node child of BattleScene (`class_name TurnOrderRunner extends Node`), created at battle-init via Battle Preparation, freed automatically with BattleScene per ADR-0002 SceneManager teardown
> **Status**: Ready
> **Stories**: 7/7 created (2026-05-01) — see Stories table below
> **Manifest Version**: 2026-04-20 (`docs/architecture/control-manifest.md`)
> **Created**: 2026-05-01 (Sprint 2 S2-08 — `/create-epics turn-order`)
> **Stories Created**: 2026-05-01 (Sprint 2 S2-08 — `/create-stories turn-order`)

## Stories

| # | Story | Type | Status | Governing ADR | Depends on |
|---|-------|------|--------|---------------|------------|
| 001 | [TurnOrderRunner module skeleton + 5 instance fields + 3 RefCounted wrappers](story-001-module-skeleton.md) | Logic | Ready | ADR-0011 | None (gates 002+003+004+005+006+007) |
| 002 | [initialize_battle BI-1..BI-6 + F-1 tie-break cascade + queue construction](story-002-initialize-battle-and-f1-cascade.md) | Logic | Ready | ADR-0011 + ADR-0007 + ADR-0009 | 001 |
| 003 | [_advance_turn T1..T7 sequence + state machine + 3 emitted signals](story-003-advance-turn-t1-t7-sequence.md) | Logic | Ready | ADR-0011 + ADR-0001 + ADR-0010 | 001, 002 |
| 004 | [declare_action + token validation + DEFEND_STANCE locks + 5 ActionType enum](story-004-declare-action-tokens-and-defend-stance.md) | Logic | Ready | ADR-0011 | 001, 002, 003 |
| 005 | [Death handling (CR-7/CR-7d) + R-1 CONNECT_DEFERRED + R-2 + Charge F-2 + CHARGE_THRESHOLD append](story-005-death-handling-and-charge-accumulation.md) | Integration | Ready | ADR-0011 + ADR-0001 + ADR-0010 + ADR-0006 + ADR-0009 | 001, 002, 003, 004 |
| 006 | [Victory detection (T7+RE2 DRAW + AC-18 mutual kill + AC-22 T7-beats-RE2) + ROUND_CAP append](story-006-victory-detection-and-precedence-rules.md) | Logic | Ready | ADR-0011 + ADR-0001 + ADR-0006 | 001, 002, 003, 005 |
| 007 | [Epic terminal — perf baseline + 5+1 forbidden_patterns lint + G-15 6-element reset list lint + Polish-tier scaffolds + 3 TD entries](story-007-perf-lints-g15-and-td-entries.md) | Config/Data | Ready | ADR-0011 + ADR-0001 + ADR-0006 | 001, 002, 003, 004, 005, 006 |

**Stories total**: 7 — 5 Logic, 1 Integration, 1 Config/Data.

**Implementation order**: **001 → 002 → 003 → 004 → 005 → 006 → 007** (linear chain; story-005 Integration is gating for AC-9 mutual kill scenario in story-006; story-007 is the epic terminal).

**TR coverage**: 22/22 traced to ADR-0011 + 6 supporting ADRs (ADR-0001/0002/0006/0007/0009/0010); 0 untraced.

**AC coverage**: 23/23 GDD ACs assigned — AC-01..AC-16 + AC-18 + AC-22 covered across stories 002-006; AC-23 (perf ADVISORY) covered by story-007; AC-17 + AC-19 + AC-20 + AC-21 (cross-system Integration — POISON DoT death + battle-end via DoT + Scout Ambush gates) deferred via story-007 TD-047 (require HP/Status epic + Damage Calc + Grid Battle).

## Overview

Turn Order/Action Management is the Core-layer system that determines per-unit
action sequence within a battle and manages each unit's per-turn lifecycle
(move, attack, skill, defend, wait). It builds the round queue from initiative
values supplied by Unit Role (F-4), tracks per-unit token consumption (1 MOVE +
1 ACTION) and accumulated_move_cost (Cavalry Charge passive), and emits
4 GameBus signals consumed by Grid Battle, HP/Status, AI System, Battle HUD,
and Formation Bonus. Six-plus systems read its `acted_this_turn` and
`current_round_number` queries — most critically Damage Calc's Scout Ambush
gate (F-DC-5).

Architecturally, TurnOrderRunner is the **third battle-scoped Node** in the
project after InputRouter (ADR-0005) and HPStatusController (ADR-0010). The
state-holder + signal-listener combination disqualifies the 5-precedent
stateless-static utility class form (ADR-0008→0006→0012→0009→0007); the
battle-scoped form is now formally codified at 3 ADRs as Foundation/Core
discipline for systems with this concern shape.

The epic resolves three architecturally-significant points settled in
ADR-0011: (1) TurnOrderRunner is sole emitter of `victory_condition_detected`
(added 2026-04-30 via §Migration Plan §0 same-patch ADR-0001 amendment), with
Grid Battle as sole emitter of authoritative `battle_outcome_resolved` per
single-owner rule; (2) AI System invocation at T4 is direct Callable
delegation (NOT signal inversion — explicitly rejected per
§Alternatives Considered); (3) `unit_id: int` matches ADR-0001/0010 lock
(distinct from `hero_id: StringName` per ADR-0007; Battle Preparation maps
at BI-1).

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|------------------|-------------|
| **ADR-0011** Turn Order (Accepted 2026-04-30) | Battle-scoped Node form + 5 instance fields + 8 public methods + 4 emitted signals + 1 consumed signal + 5 forbidden_patterns; signal inversion rejected; Callable-delegation Contract 5 | LOW |
| **ADR-0001** GameBus (Accepted 2026-04-19; amended 2026-04-30 §Migration Plan §0) | Single-owner rule for 4 emitted signals (Turn Order Domain lines 152-155); CONNECT_DEFERRED mandate per §5; sole emitter of `unit_died` consumer subscription pattern | LOW |
| **ADR-0002** SceneManager (Accepted 2026-04-22) | Battle-scoped lifecycle — TurnOrderRunner instantiated at battle-init, freed automatically at BattleScene teardown; CR-1b non-persistence enforced by lifecycle alignment | LOW |
| **ADR-0006** Balance/Data (Accepted 2026-04-30) | `BalanceConstants.get_const(key)` accessor for ROUND_CAP=30 + CHARGE_THRESHOLD=40 (2 net-new keys appended to balance_entities.json same-patch with story-005 lint validation per §6 obligation) | LOW |
| **ADR-0007** Hero DB (Accepted 2026-04-30) | `HeroDatabase.get_hero(hero_id).stat_agility` for tie-break (F-1 cascade secondary key); hero_id ↔ unit_id mapping established at BI-1 | LOW |
| **ADR-0009** Unit Role (Accepted 2026-04-28) | `UnitRole.get_initiative(hero, unit_class) -> int` called once per unit at BI-2; static initiative MVP rule (CR-6 cached, NOT recomputed at R3) | LOW |
| **ADR-0010** HP/Status (Accepted 2026-04-30) | TurnOrderRunner subscribes to `GameBus.unit_died(unit_id: int)` (HPStatusController is sole emitter); CONNECT_DEFERRED for R-1 mitigation; T1 DoT tick + T3 status decrement consumer of `unit_turn_started` | LOW |

**Engine Risk**: **LOW overall** — `Callable` (Godot 4.0+ stable), `CONNECT_DEFERRED` (4.0+ stable, godot-specialist 2026-04-30 Item 4 verified through 4.6), `Dictionary[int, UnitTurnState]` typed Dictionary (Godot 4.4+; ratified by ADR-0010 precedent), `_begin_round.call_deferred()` Callable method-reference form (godot-specialist Item 6; NOT string-based). No post-cutoff Godot 4.5/4.6 API touched.

## GDD Requirements

22 of 22 requirements traced to Accepted ADRs. **0 untraced.**

| TR-ID | Requirement (excerpt) | ADR Coverage |
|-------|------------------------|--------------|
| TR-turn-order-001 | Emits round_started + unit_turn_started + unit_turn_ended; battle termination owned by Grid Battle per ADR-0001 single-owner rule | ADR-0011 + ADR-0001 ✅ |
| TR-turn-order-002 | Battle-scoped Node form (NOT stateless-static — listens + holds state); 3-precedent codified | ADR-0011 ✅ |
| TR-turn-order-003 | 5 instance fields: _queue + _queue_index + _round_number + _unit_states + _round_state | ADR-0011 ✅ |
| TR-turn-order-004 | 3 RefCounted typed wrappers (UnitTurnState + TurnOrderSnapshot + TurnOrderEntry); NOT Resource | ADR-0011 ✅ |
| TR-turn-order-005 | Public mutator API — initialize_battle + declare_action + _advance_turn (TEST SEAM) | ADR-0011 ✅ |
| TR-turn-order-006 | Public read-only query API — 5 methods (get_acted_this_turn + get_current_round_number + get_turn_order_snapshot + get_charge_ready + get_unit_turn_state) | ADR-0011 + ADR-0012 ✅ |
| TR-turn-order-007 | Sole emitter of 4 GameBus signals (round_started + unit_turn_started + unit_turn_ended + victory_condition_detected) per ADR-0001 single-emitter rule | ADR-0011 + ADR-0001 ✅ |
| TR-turn-order-008 | Subscribes to GameBus.unit_died with CONNECT_DEFERRED (R-1 mitigation); R-2 defensive _unit_states.has() check | ADR-0011 + ADR-0001 + ADR-0010 ✅ |
| TR-turn-order-009 | 5 forbidden_patterns registered in architecture.yaml (consumer_mutation + external_queue_write + signal_emission_outside_domain + static_var_state_addition + typed_array_reassignment) | ADR-0011 ✅ |
| TR-turn-order-010 | F-1 tie-break cascade (initiative DESC + stat_agility DESC + is_player_controlled DESC + unit_id ASC); deterministic AC-13 | ADR-0011 + ADR-0007 ✅ |
| TR-turn-order-011 | T1-T7 sequence strict ordering (DoT tick → death check → duration decrement → activate → action budget → mark acted → victory check) | ADR-0011 + ADR-0010 ✅ |
| TR-turn-order-012 | CR-3 action budget — 1 MOVE + 1 ACTION token; reset at T4; acted_this_turn iff at least one spent | ADR-0011 ✅ |
| TR-turn-order-013 | CR-4 action types — 5 ActionType enum (MOVE / ATTACK / USE_SKILL / DEFEND / WAIT); validation + DEFEND_STANCE locks | ADR-0011 ✅ |
| TR-turn-order-014 | CR-6 static initiative MVP rule (cached at BI-2, NOT recomputed; AC-09 mid-battle status doesn't reorder) | ADR-0011 + ADR-0009 ✅ |
| TR-turn-order-015 | CR-7 death mid-round + CR-7d counter-attack T5 interrupt | ADR-0011 + ADR-0010 ✅ |
| TR-turn-order-016 | CR-9 BI-1..BI-6 battle initialization sequence; _begin_round.call_deferred() Callable method-ref form | ADR-0011 + ADR-0009 ✅ |
| TR-turn-order-017 | F-2 charge accumulation (Cavalry Charge passive); reset at T4 (R-3 mitigation) | ADR-0011 + ADR-0009 ✅ |
| TR-turn-order-018 | F-3 round cap + 2 BalanceConstants append (ROUND_CAP=30 + CHARGE_THRESHOLD=40) per ADR-0006 §6 same-patch | ADR-0011 + ADR-0006 ✅ |
| TR-turn-order-019 | G-15 6-element reset list — _unit_states.clear() + _queue.clear() + counters + state + unit_died.disconnect() | ADR-0011 ✅ |
| TR-turn-order-020 | AC-18 mutual kill PLAYER_WIN precedence + AC-22 T7 PLAYER_WIN beats RE2 DRAW in Round 30 | ADR-0011 ✅ |
| TR-turn-order-021 | Performance — O(N log N) sort + O(1) queries; ~500 bytes per battle; AC-23 < 1ms on minimum mobile | ADR-0011 ✅ |
| TR-turn-order-022 | Cross-doc unit_id type — int matches ADR-0001/0010 lock; ADR-0012 narrowed via delta #8; hero_id distinct (ADR-0007) | ADR-0011 + ADR-0001 + ADR-0010 ✅ |

## Layer-invariant resolution (Contract 5 — direct Callable delegation)

Per `design/gdd/turn-order.md` §Interface Contracts Contract 5 (revised 2026-05-01
via S2-06): Turn Order satisfies architecture.md §1 invariant #4 by depending on
a generic `Callable` abstraction injected by Battle Preparation at BI-1, NOT by
signal-inverting AI. TurnOrderRunner source MUST contain zero AI System symbol
references; the `controller: Callable` reference is engine-primitive and
type-blind to AI vs player input layer. Interleaved queue (CR-1) makes
`is_player_controlled` invisible to queue logic — it is HUD/CR-7d-counter-attack
metadata only. Forbidden_pattern `turn_order_ai_system_direct_symbol_reference`
registration is a same-patch obligation of the lint-script story (Polish-tier
or terminal-step story per epic implementation order).

## Architecture risks carried forward

- **R-1** (signal-receipt timing): mitigated via `Object.CONNECT_DEFERRED` on `unit_died` subscription (godot-specialist 2026-04-30 Item 4 verified stable through Godot 4.6). Test verification: integration test asserts queue removal happens after apply_damage call stack unwinds, not synchronously during damage application.
- **R-2** (double-death): mitigated via defensive `_unit_states.has(unit_id)` short-circuit in `_on_unit_died`. Test verification: regression test fires `unit_died` twice for same unit_id; second call no-ops cleanly.
- **R-3** (charge budget reset on death-interrupted turn): mitigated via T4 reset (turn START), not T6. Test verification: turn-interrupted-by-death scenario asserts next turn's T4 cleanly resets accumulated_move_cost to 0.
- **R-5** (cross-test state leak via static-var sneak-in): mitigated via 5 forbidden_patterns + G-15 6-element reset list. Static-lint check: `grep -L 'unit_died.disconnect' tests/unit/core/turn_order*.gd` returns empty.
- **R-9** (Callable-delegation invariant erosion): mitigated via `turn_order_ai_system_direct_symbol_reference` forbidden_pattern (registered same-patch with lint-script story). Lint enforces zero `class_name AI` / `preload(".../ai_*.gd")` / `import AISystem` matches in TurnOrderRunner source.

## Story decomposition preview

Story count estimate: **~6-7 stories**, mirroring the unit-role / damage-calc / hero-database multi-story Foundation/Core epic decomposition discipline. Implementation order will be authored via `/create-stories turn-order`; preview structure (subject to /create-stories-time refinement):

1. **TurnOrderRunner module skeleton + battle-scoped Node + 5 instance fields + 3 RefCounted wrappers** (Logic, ~3-4h) — gates 002+003+004+005+006+007
2. **initialize_battle BI-1..BI-6 + queue construction + F-1 tie-break cascade + AC-13 determinism** (Logic, ~3-4h) — depends on 001
3. **_advance_turn T1..T7 sequence + state machine + activate/mark-acted lifecycle** (Logic, ~3-4h) — depends on 001+002
4. **declare_action + token validation + DEFEND_STANCE locks + CR-3/CR-4 ActionType enum** (Logic, ~2-3h) — depends on 001+003
5. **Death handling (CR-7 / CR-7d counter-attack T5 interrupt) + R-1 CONNECT_DEFERRED + R-2 defensive guard** (Integration, ~3-4h) — depends on 001+003
6. **Victory detection (T7 decisive + RE2 round-cap DRAW + AC-18 mutual kill PLAYER_WIN precedence + AC-22 T7-beats-RE2)** (Logic, ~2-3h) — depends on 001+002+003+005
7. **Epic terminal — perf baseline + 5 forbidden_patterns lint + G-15 6-element reset list lint + 2 BalanceConstants append + Polish-tier scaffolds + TD entries** (Config/Data, ~2-3h) — depends on all prior; closes the epic

Estimated total: **~18-24h** (~3-4 days) — comparable to hero-database (5 stories, ~14h actual) and damage-calc (10 stories, ~25h actual). Story-005's R-1 CONNECT_DEFERRED Integration test will likely be the critical-path determining the longest implementation window.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All 22 TR-turn-order requirements are verified by passing automated tests (`tests/unit/core/turn_order_*.gd` + `tests/integration/core/turn_order_*.gd`)
- All 8 public API methods (3 mutator + 5 read-only query) have unit tests covering happy path + error path + R-1/R-2/R-3/R-5/R-9 mitigations
- All 5 forbidden_patterns are registered in `docs/registry/architecture.yaml` AND enforced by `tools/ci/lint_turn_order_*.sh` script(s) wired into `.github/workflows/tests.yml`
- 2 BalanceConstants appended to `assets/data/balance/balance_entities.json` (ROUND_CAP=30 + CHARGE_THRESHOLD=40) with same-patch lint validation per ADR-0006 §6
- G-15 6-element reset list enforced by lint scaffold
- Layer-invariant resolution prose §Contract 5 is preserved across the implementation (no `class_name AI` / `import AI*` symbol references in `src/core/turn_order_runner.gd`)
- Full GdUnit4 regression maintains baseline post-epic (~564 + ~50-60 new tests = ~620 cases / 0 errors / ≤1 carried failure / 0 orphans)

## Cross-system integration notes

- **Damage Calc (ADR-0012)**: 4 query interface ratifications — `get_acted_this_turn(unit_id: int) -> bool` (Scout Ambush gate F-DC-5) + `get_current_round_number() -> int` (Round-2+ Ambush gate); ADR-0011 acceptance closed ADR-0012's last upstream Core soft-dep. Type advisory: ADR-0012 lines 91/109/340/343 originally StringName, narrowed → int via /architecture-review delta #8 same-patch (TR-turn-order-022).
- **HP/Status (ADR-0010)**: 2-way contract — Turn Order subscribes to `unit_died` (CONNECT_DEFERRED); HP/Status subscribes to `unit_turn_started` (T1 DoT tick + T3 status decrement + DEFEND_STANCE/DEMORALIZED expiry per ADR-0010 §Soft/Provisional clause (1) ratified by this ADR).
- **Battle Preparation (Feature, unwritten ADR)**: Owns hero_id ↔ unit_id mapping at BI-1; injects per-unit `controller: Callable` references for Contract 5 delegation. Soft-dep on the future Battle Preparation ADR which formalizes the BattleUnit contract; provisional implementation can use a stub Callable provider for tests until Battle Preparation ships.
- **AI System (Feature, unwritten ADR)**: Implements `controller: Callable(unit_id: int, queue_snapshot: TurnOrderSnapshot) -> ActionDecision` interface; consumes `unit_turn_started` (action delegation) + `TurnOrderSnapshot` (target prioritization) + `acted_this_turn` query. Soft-dep on the future AI System ADR; provisional implementation can use a deterministic test-AI for integration tests.
- **Grid Battle (Feature, unwritten ADR)**: Sole emitter of authoritative `battle_outcome_resolved` per ADR-0001 single-owner rule. Consumes Turn Order's `victory_condition_detected` and transitions to RESOLUTION state. Soft-dep on the Grid Battle ADR (Vertical Slice critical path).
- **Battle HUD (Presentation, unwritten ADR)**: Pull-based consumer — calls `get_turn_order_snapshot()` on `round_started` / `unit_turn_ended` / `unit_died` receipts. Soft-dep on Battle HUD ADR.
- **Formation Bonus (Feature, unwritten ADR)**: Consumes `round_started` for per-round bonus recomputation. Soft-dep on Formation Bonus ADR.

## Next Step

Run `/create-stories turn-order` to break this epic into ~6-7 implementable stories with embedded TR-IDs, ADR references, AC tables, test evidence paths, and dependency graphs. Story decomposition preview above is a starting point; /create-stories will refine boundaries based on reviewability + test-evidence-path discipline.
