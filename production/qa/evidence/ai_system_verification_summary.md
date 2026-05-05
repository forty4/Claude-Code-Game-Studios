# AI System Epic — Verification Summary

> **Epic**: `production/epics/ai-system/EPIC.md`
> **Story**: `story-001-ai-system-impl-and-pillar-2-lock-4th-precedent.md` (epic-terminal)
> **Closed**: 2026-05-05 (Sprint 7 S7-04)
> **ADR**: `docs/architecture/ADR-0019-ai-system.md` (Accepted 2026-05-05 via /architecture-review delta #14)
> **Verifier**: Dowan Kim (orchestrator) — single coordinated patch atomicity per ADR-0019 §Migration Plan §2..§5
> **Test baseline**: 943 → **953 passing** (+10 net AI tests; 0 errors / 0 failures / 0 orphans)

---

## §A. Story shipped

| # | Story | Type | Status | TR-IDs Covered | Test Evidence |
|---|-------|------|--------|----------------|---------------|
| 001 | AISystem implementation + Pillar 2 architectural lock 4th precedent enforcement | Logic + Integration | Complete (2026-05-05) | TR-ai-system-001..015 (full epic terminal) | 2 unit test files + 1 helper (10 new test functions); 4 new lints all PASS |

---

## §B. TR coverage matrix (15/15)

| TR-ID | Requirement (summary) | Status |
|-------|----------------------|--------|
| TR-001 | AISystem class form: `extends Node` battle-scoped 6th invocation | ✅ |
| TR-002 | Single source file with `match` dispatch on archetype StringName | ✅ |
| TR-003 | BattleStateSnapshot Resource (flat data, 7 typed @export fields) | ✅ |
| TR-004 | AIActionCommand Resource (5 fields + 6 static factories + ActionType enum append-only) | ✅ |
| TR-005 | Mount order: BattleScene `_ready()` step 5.5 (Path A insert) | ✅ |
| TR-006 | LOCAL signal subscription to GridBattleController.ai_action_requested with CONNECT_DEFERRED | ✅ |
| TR-007 | LOCAL signal emission `ai_action_ready` declared on AISystem class (NOT GameBus) | ✅ |
| TR-008 | `_exit_tree()` disconnects subscription per battle-scoped Node 6-precedent | ✅ |
| TR-009 | Determinism contract (no static var + no randf + no Time.* + no instance-var caching) | ✅ |
| TR-010 | Main-thread synchronous execution for MVP (WorkerThreadPool deferred) | ✅ |
| TR-011 | Forbidden pattern: ai_system_signal_emission_outside_action_ready | ✅ |
| TR-012 | Forbidden pattern: ai_system_static_var | ✅ |
| TR-013 | Forbidden pattern: ai_system_reads_destiny_branch_state (Pillar 2 lock 4th precedent) | ✅ |
| TR-014 | Forbidden pattern: ai_system_direct_battle_state_read | ✅ |
| TR-015 | 10 BalanceConstants entries (F-AI-Constants table) | ✅ |

---

## §C. Test verification

**Pre-S7-04**: 943/943 (post-S7-03 close).
**Post-S7-04**: **953/953 passing** (+10 net; 0 errors / 0 failures / 0 orphans).

### New test files (S7-04)

| File | Tests | Primary AC Coverage |
|------|-------|---------------------|
| `tests/unit/ai/ai_system_test.gd` | 5 | AC-AI-2 (determinism 100-invocation) + AC-AI-3 (archetype differentiation) + AC-AI-9 (Pillar 2 lock 4th precedent structural assertion) + AC-AI-10 (no_direct_state_read structural assertion) + determinism source-scan |
| `tests/unit/ai/ai_archetype_behavior_test.gd` | 5 | AC-AI-4 (aggressor finishing) + AC-AI-7 (coordinator commander targeting) + AC-AI-8 (coordinator rally) + EC-AI-1 (zero candidates → WAIT) + EC-AI-4 (unknown archetype fallback) |
| **Subtotal** | **10** | |

### Test helpers (S7-04)

| File | Purpose |
|------|---------|
| `tests/helpers/battle_state_snapshot_factory.gd` | Synthetic BattleStateSnapshot construction with builder pattern + default-fill of all 7 fields |

---

## §D. Lint verification

All 4 new lints pass:

| Lint | Pattern | Status |
|------|---------|--------|
| `lint_ai_system_no_gamebus_emit.sh` | ai_system_signal_emission_outside_action_ready (9-precedent stateless-emit / non-emitter discipline mirror) | ✅ PASS |
| `lint_ai_system_no_static_var.sh` | ai_system_static_var (5-precedent battle-scoped + RefCounted lint pattern mirror) | ✅ PASS |
| `lint_ai_system_no_destiny_branch_reference.sh` | ai_system_reads_destiny_branch_state (**Pillar 2 architectural lock 4th project precedent**) | ✅ PASS |
| `lint_ai_system_no_direct_state_read.sh` | ai_system_direct_battle_state_read (CR-AI-6 — 2nd invocation of pure-function-takes-snapshot pattern) | ✅ PASS |

**3-layer enforcement triad** for Pillar 2 lock 4th precedent (per Decision F):
1. Source-grep lint (`lint_ai_system_no_destiny_branch_reference.sh`)
2. ADR-0019 §CR-AI-8 inline annotation + ai_system.gd source-comment annotation
3. Integration test `test_ai_system_source_contains_no_pillar_2_tokens_outside_doc_comments` via FileAccess source-scan per G-22 structural assertion pattern

---

## §E. Files shipped

**Source files** (3 new):
- `src/feature/ai/ai_system.gd` (~470 LoC) — battle-scoped Node 6th invocation + 4 archetype scoring functions + decision pipeline
- `src/core/payloads/battle_state_snapshot.gd` (53 LoC) — 7-field flat-data Resource + get_unit() accessor
- `src/core/payloads/ai_action_command.gd` (84 LoC) — 5-field Resource + 6 static factories + ActionType enum (append-only)

**Modified existing source** (3):
- `src/feature/grid_battle/grid_battle_controller.gd` — added 6th LOCAL signal `ai_action_requested` declaration + `_make_battle_state_snapshot()` helper + `_on_unit_turn_started` AI-turn detection + emit
- `src/feature/battle_scene/battle_scene.gd` — inserted step 5.5 AISystem mount per ADR-0016 §3 R-3 amended via delta #14
- `assets/data/balance/balance_entities.json` — appended 10 F-AI-Constants entries

**Lint scripts** (4 new): all in `tools/ci/lint_ai_system_*.sh`

**Test files** (3 new): 2 unit test files + 1 test helper

**Evidence doc** (1): this file

**Total**: 14 files in single coordinated patch.

---

## §F. Architectural patterns ratified

- **6th invocation of battle-scoped Node pattern** (after HPStatusController + TurnOrderRunner + BattleCamera + GridBattleController + BattleHUD) — pattern stable at 6 invocations
- **1st invocation of single-class match-dispatch over subclass hierarchy pattern** — pattern boundary established for closed enum-keyed dispatch with closed MVP scope (4 archetypes per CR-AI-3); subclass hierarchy with @abstract test seam is post-MVP refactor option per Alternative §4
- **2nd invocation of LOCAL-signal-not-GameBus pattern** (after GridBattleController 6 LOCAL signals; AISystem emits 1 LOCAL signal `ai_action_ready` declared on AISystem class itself)
- **Pillar 2 architectural lock 4th project precedent** (`ai_system_reads_destiny_branch_state` follows `battle_hud_subscribes_to_hidden_fate_signal` + `scenario_runner_deferred_seal_in_beat_7_entry` + `destiny_branch_judge_reads_scenario_runner_state`) — pattern firmly stable at 4 invocations
- **2nd invocation of pure-function-takes-snapshot pattern** (after `destiny_branch_judge_reads_scenario_runner_state`) — CR-AI-6 enforcement via `lint_ai_system_no_direct_state_read.sh`

---

## §G. Documented deviations from ADR-0019 Migration Plan

1. **AC-AI-12 chapter-1 ending distribution test**: deferred until ScenarioRunner full chapter-1 narrative content lands (S7-05 should-have). Test scaffold may be added as bonus coverage in same sprint window if S7-05 ships.

2. **AC-AI-14 save/load determinism replay**: deferred — Save/Load #17 VS GDD CUT from sprint-7 per Producer pressure-cut decision. Determinism contract (CR-AI-5 + AC-AI-2 verification) provides structural guarantee.

3. **AC-AI-11 P99 Android device perf verification**: deferred to release-prep sprint per Decision E / R-3 mitigation. CI lanes Linux Editor + macOS Apple Silicon dev-machine verified.

4. **AC-AI-13 soft-lock recovery test**: covered structurally (AISystem doesn't crash + emits ai_action_ready normally; GridBattleController-side timeout + WAIT-substitution + ai_soft_lock_counter increment is post-MVP integration work — sprint-7 ships the protocol; full timer-based fallback defers to post-MVP).

5. **AC-AI-1 signal protocol compliance integration test**: covered structurally via determinism test (verifies `ai.decide()` returns valid AIActionCommand with non-default unit_id). Full mocked GridBattleController + multi-unit signal capture deferred — current subscription path verified by AC-MOUNT-1 + lint coverage.

6. **AC-AI-5 + AC-AI-6 (skirmisher kiting + holder chokepoint)**: not unit-tested in this story; covered indirectly by archetype-differentiation test (AC-AI-3) which validates that 4 archetypes produce distinct outputs in synthetic scenarios.

7. **GridBattleController emit call site at AI-turn entry**: shipped at `_on_unit_turn_started` per ADR-0019 §Decision body. CR-3 timeout enforcement is post-MVP — sprint-7 ships emission protocol; CR-3b WAIT-substitution + ai_soft_lock_counter is deferred to post-MVP timer integration.

8. **Test count consolidation**: story spec lists 5 test files; implementation consolidates into 2 files (ai_system_test + ai_archetype_behavior_test) covering 10 critical-path test functions. Coverage scope satisfies AC-AI-2 + AC-AI-3 + AC-AI-9 + AC-AI-10 (BLOCKING) + AC-AI-4 + AC-AI-7 + AC-AI-8 (per-archetype behavior).

---

## §H. Cross-references

- ADR-0019 (Accepted 2026-05-05) — governing
- ADR-0014 §8 (amended via delta #14 — 5 → 6 LOCAL signals; ai_action_requested 6th)
- ADR-0016 §3 R-3 (amended via delta #14 — mount step 5.5 insertion)
- ADR-0017 (ScenarioRunner — ChapterDefinition.enemy_roster archetype consumer)
- ADR-0018 (DestinyBranchJudge — Pillar 2 lock 3rd precedent template)
- ADR-0011 (TurnOrderRunner — `_on_unit_turn_started` event source)
- design/gdd/ai-system.md rev 1.0 — CR-AI-1..8 + F-AI-1..4 + EC-AI-1..12 + AC-AI-1..14
- production/epics/ai-system/story-001 (this story)
- production/qa/evidence/destiny_branch_verification_summary.md — Pillar 2 lock 3rd precedent template
- art-bible.md §4.7 — chapter-1 (장판파) enemy archetype assignments
- tooling-gotchas.md G-22 — @abstract structural source-file assertion pattern (mirrored in AC-AI-9 + AC-AI-10 tests)
