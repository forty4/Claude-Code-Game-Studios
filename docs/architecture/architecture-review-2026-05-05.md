# Architecture Review Report — Delta #14

**Date**: 2026-05-05
**Mode**: Lean (per `production/review-mode.txt`); fresh-session escalation per same-session-ban discipline
**Engine**: Godot 4.6 (project pinned 2026-04-16)
**Sprint**: S7-01 (sprint-7 plan path-to-PASS item #6 ADR escalation)
**Session**: combined ADR-0019 escalation Proposed → Accepted + structural append (15 net-new TR-ai-system entries) — **4th consecutive /architecture-review delta to combine escalation + structural append in single fresh session** (pattern stable at 4 invocations after delta #11/#12/#13)

---

## Verdict

**PASS WITH 1 BLOCKING + 1 ADVISORY CORRECTIONS** — both resolved same-patch within this delta's commit:
- 1 BLOCKING cross-ADR integration conflict (ADR-0014 §8 5-LOCAL-signal set vs ADR-0019 assumed 6th `ai_action_requested` LOCAL signal on GridBattleController) — resolved via same-patch ADR-0014 additive amendment to §8 + R-1 + Enables block
- 1 ADVISORY GDD wording reconciliation (`ai-system.md` CR-AI-1 step "6.5" vs ADR-0019 §Mount Order step "5.5") — resolved via same-patch GDD wording flip

ADR-0019 Status: **Accepted (2026-05-05)**. Total accepted ADR count: 18 → **19**. Feature layer 3/4 → **4/4 Complete** (AI System closes the MVP Feature-layer chain; Battle Preparation deferred to post-MVP per ADR-0019 §0 scope statement). Pillar 2 architectural lock pattern stable at **4 invocations** (`ai_system_reads_destiny_branch_state` follows `battle_hud_subscribes_to_hidden_fate_signal` + `scenario_runner_deferred_seal_in_beat_7_entry` + `destiny_branch_judge_reads_scenario_runner_state`).

**Mandatory ADR list**: 0 → 0 (unchanged since delta #8). **Pre-Production → Production gate is now eligible** (mandatory ADR list = 0; AI System closes the cross-director convergent blocker per gate-check 2026-05-04 path-to-PASS item #4).

---

## Phase 1: Inputs Loaded

- ADR-0019 AI System (435 lines — Proposed authoring 2026-05-04 commit `6dfd962` per gate-check pre-prod-to-prod-2026-05-04 path-to-PASS item #4)
- ADR-0014 GridBattleController (LOCAL signal contract — same-patch amendment target)
- ADR-0015 BattleHUD (battle-scoped Node 5th-precedent)
- ADR-0016 BattleSceneWiring (6-step mount sequence — same-patch documentation amendment target)
- ADR-0017 ScenarioProgression (ChapterDefinition.enemy_roster archetype field consumer)
- ADR-0018 DestinyBranch (Pillar 2 architectural lock 3rd-precedent — pattern this ADR's 4th-precedent extends)
- ADR-0010/0011/0013 (battle-scoped Node precedent triad)
- ADR-0001 GameBus (signal contract source-of-truth — verified NO new GameBus signals from this ADR; AISystem uses LOCAL signal only)
- design/gdd/ai-system.md 327 lines (rev 1.0 — same-patch CR-AI-1 wording reconciliation target)
- design/gdd/grid-battle.md (CR-3 + CR-3a `ai_action_requested` / `ai_action_ready` signal protocol + 500ms timeout + WAIT-substitution + soft_lock_counter — already locked at GDD level; ADR-0019 ratifies AISystem internal architecture only)
- docs/registry/architecture.yaml v12
- docs/architecture/tr-registry.yaml v14
- docs/architecture/architecture-traceability.md v0.13
- godot-4x-gotchas.md (G-3 autoload + G-22 @abstract on typed references + G-15 test-isolation reset)
- engine-reference/godot/{VERSION.md, breaking-changes.md, deprecated-apis.md}
- src/feature/grid_battle/grid_battle_controller.gd (verified shipped 5-LOCAL-signal declaration at lines 85-99)

---

## Phase 2-3: Traceability Matrix Update

15 net-new TR-ai-system-001..015 entries appended to tr-registry.yaml v14 → v15:

| TR-ID | Coverage | ADR |
|-------|----------|-----|
| TR-ai-system-001 | AISystem class form: `extends Node` (battle-scoped, 6th invocation of pattern) | ADR-0019 |
| TR-ai-system-002 | Single-source-file with `match` dispatch on archetype StringName (NOT subclass hierarchy) | ADR-0019 |
| TR-ai-system-003 | `BattleStateSnapshot extends Resource` typed payload (flat data — no nested Resources) | ADR-0019 |
| TR-ai-system-004 | `AIActionCommand extends Resource` typed payload + 6 static factories + ActionType enum append-only | ADR-0019 |
| TR-ai-system-005 | Mount order: BattleScene `_ready()` step 5.5 (post-GridBattleController, pre-BattleHUD; insert-not-renumber per delta #14 Path A) | ADR-0019 |
| TR-ai-system-006 | LOCAL signal subscription to GridBattleController.ai_action_requested with CONNECT_DEFERRED | ADR-0019 |
| TR-ai-system-007 | LOCAL signal emission `ai_action_ready` declared on AISystem class itself (NOT GameBus) | ADR-0019 |
| TR-ai-system-008 | `_exit_tree()` disconnects subscription (battle-scoped 6th invocation discipline) | ADR-0019 |
| TR-ai-system-009 | Determinism contract: no static var + no randf + no Time.get_ticks_msec + no instance-var caching across calls | ADR-0019 |
| TR-ai-system-010 | Main-thread synchronous execution for MVP; WorkerThreadPool deferred to post-MVP amendment | ADR-0019 |
| TR-ai-system-011 | Forbidden pattern: ai_system_signal_emission_outside_action_ready (5-precedent stateless-emit lint mirror) | ADR-0019 |
| TR-ai-system-012 | Forbidden pattern: ai_system_static_var (4-precedent battle-scoped state-isolation lint mirror) | ADR-0019 |
| TR-ai-system-013 | Forbidden pattern: ai_system_reads_destiny_branch_state (Pillar 2 lock 4th precedent) | ADR-0019 |
| TR-ai-system-014 | Forbidden pattern: ai_system_direct_battle_state_read (CR-AI-6 enforcement; 1-precedent pure-function-takes-snapshot mirror) | ADR-0019 |
| TR-ai-system-015 | DI null-check assert in `_ready()` (GridBattleController reference required pre-add_child) | ADR-0019 |

Total TR count: 239 → **254**. tr-registry.yaml v14 → v15.

---

## Phase 4: Cross-ADR Conflict Detection

### 🔴 CONFLICT #1 (BLOCKING; Type: Integration contract / Signal set ratification)

**ADR-0014 vs ADR-0019** — GridBattleController LOCAL signal set count mismatch.

- **ADR-0014 §8 (lines 323-333)**: declares **5 LOCAL signals** ratified by ADR-0015 BattleHUD Accepted 2026-05-03 via /architecture-review delta #10: `unit_selected_changed` + `unit_moved` + `damage_applied` + `battle_outcome_resolved` + `hidden_fate_condition_progressed`. R-1 documents "MVP set ratified by ADR-0015" + budget consumption "<10/frame even at peak — well under cap". Shipped source `src/feature/grid_battle/grid_battle_controller.gd:85-99` confirms exactly 5 declarations.
- **ADR-0019 §Decision §Decision body (lines 137-144)**: AISystem `_ready()` connects to `_grid_battle_controller.ai_action_requested.connect(_on_ai_action_requested, CONNECT_DEFERRED)` — assumes a **6th LOCAL signal** `ai_action_requested(unit_id: int, snapshot: BattleStateSnapshot)` declared on GridBattleController. Same signal is documented in `design/gdd/grid-battle.md` CR-3 + CR-3a + AC-GB-16 (full Alpha-tier scope) but NOT in ADR-0014's MVP signal set (ADR-0014 §0 explicitly defers AI substate machine: "AI substate machine (CR-3 AI_WAITING + ai_action_ready CONNECT_ONE_SHOT + AI_DECISION_TIMEOUT_MS timer + soft-lock counter) ... beyond sprint-4 S4-03 capacity").
- **architecture.yaml forbidden_pattern `grid_battle_controller_signal_emission_outside_battle_domain`** (line 1856) lists exactly the 5-signal set verbatim, codifying the "5 LOCAL signals" budget at registry level.

**Impact**: Cannot accept ADR-0019 with internal claim contradicting ADR-0014's ratified 5-signal set + the architecture-registry forbidden_pattern's 5-signal whitelist. AISystem implementation at sprint-7+ (S7-04) would fail at integration time — `_grid_battle_controller.ai_action_requested.connect(...)` would raise an "Invalid signal name" error because GridBattleController has no `ai_action_requested` declared.

**Resolution applied (same-patch)**: Path forward — **additive amendment to ADR-0014** (mirrors delta #13's Path A pattern of upstream-ADR same-patch flip at downstream-ADR acceptance time):
1. ADR-0014 §8: add 6th LOCAL signal declaration `signal ai_action_requested(unit_id: int, snapshot: BattleStateSnapshot)` with note "MVP+ extension per ADR-0019 acceptance (delta #14)"
2. ADR-0014 §8 prose: "MVP set ratified by ADR-0015 Battle HUD" → "MVP set (5) ratified by ADR-0015 Battle HUD; 6th signal `ai_action_requested` ratified by ADR-0019 AI System Accepted 2026-05-05 via /architecture-review delta #14"
3. ADR-0014 §R-1 budget revision: "5 signals" → "6 signals" with note "ai_action_requested fires 1× per AI unit per turn = ~4 events per round; total per-frame budget consumption still well under ADR-0001 §445 cap"
4. ADR-0014 §Enables block: add ADR-0019 reference
5. ADR-0014 §9 architecture diagram (line ~384): add `ai_action_requested → AI System (sprint-7+)` row
6. **architecture.yaml forbidden_pattern `grid_battle_controller_signal_emission_outside_battle_domain`** description: amend "all 5 emitted signals" → "all 6 emitted signals" + add `ai_action_requested` to the listed signal set
7. **architecture.yaml state_ownership `battle_runtime_state`** interface field: add `ai_action_requested(unit_id: int, snapshot: BattleStateSnapshot)` to the documented 5-signal set inline

**5th project precedent of "ratification widening at upstream-ADR acceptance"** after save_checkpoint_requested 2026-04-18 (String → SaveContext) + scenario_complete delta #12 (String → ScenarioResult) + scenario_beat_retried delta #12 (provisional 4-field → shipped 3-field) + ADR-0017 line 209 instance-form widening delta #13. Pattern stable at 5 invocations; the upstream ADR's signal/call surface typically lags behind a downstream ADR that ratifies the consumer.

**Note on shipped source**: ADR-0014's shipped source (`src/feature/grid_battle/grid_battle_controller.gd:85-99`) does NOT yet declare `ai_action_requested`. Sprint-7+ S7-04 implementation patch (per ADR-0019 §Migration Plan §6 — "GridBattleController extension `_make_battle_state_snapshot()` private method") will add the signal declaration + the snapshot factory same-patch. Delta #14 amendment is the documentation+architecture ratification; the source code-side change ships with S7-04.

### 🟡 ADVISORY #1 (GDD wording reconciliation)

**design/gdd/ai-system.md CR-AI-1 vs ADR-0019 §Mount Order** — step number inconsistency.

- **ai-system.md line 28 CR-AI-1**: "AISystem is instantiated per battle by `BattleScene` root mount sequence (post-MVP step 6.5, between GridBattleController and BattleHUD per ADR-0019 §Mount Order — to be ratified)"
- **ADR-0019 §Mount Order (lines 240-249)**: "5.5. AISystem ← NEW per ADR-0019" (between GridBattleController step 5 and BattleHUD step 6)

ADR-0016's actual 6-step sequence has GridBattleController at step 5 and BattleHUD at step 6 — so AISystem inserted between is "step 5.5", not "6.5". The GDD authoring used a different mental model.

**Resolution applied (same-patch)**: Flip GDD CR-AI-1 line 28 wording "post-MVP step 6.5" → "step 5.5" + remove "to be ratified" qualifier (ADR-0019 ratification is this delta).

### 🟡 ADVISORY #2 (Mount sequence renumber decision — DEFERRED to S7-04)

**ADR-0019 §Mount Order line 254 + Migration Plan §1**: "Numbering as '5.5' preserves the 1-6 historical contract for ADRs 0016 documentation; alternative is to renumber 1-7 (cleaner) — DEFERRED to /architecture-review delta."

**Decision applied (delta #14)**: **Path A — insert "step 5.5"** (preserve existing 1-6 numbering). Rationale:
- Minimum-touch keeps existing ADR-0016 cross-references stable (architecture-traceability.md, registry/architecture.yaml `battle_scene_root_lifecycle` interface field, multiple ADR-0014/0015 references to "step 5" / "step 6" remain valid)
- ADR-0016 file is being touched at sprint-7+ S7-02 anyway for sprint-6 mock encoder deletion + lint phase-flip + project.godot main_scene revert per ADR-0017 Migration Plan §1 — full 1-7 renumber can happen organically as part of that touch with zero additional context cost
- "5.5" notation is unambiguous in code comments + diagrams + tests; no behavioral consequence

ADR-0016 §3 R-3 receives a same-patch documentation amendment inserting "(5.5) AISystem.setup(grid_controller) → add_child" between current step 5 and step 6.

### 🟢 No other cross-ADR conflicts

- **Pillar 2 architectural lock pattern** — `ai_system_reads_destiny_branch_state` is the **4th invocation** of the pillar-anchored lint pattern after `battle_hud_subscribes_to_hidden_fate_signal` (ADR-0015 1st) + `scenario_runner_deferred_seal_in_beat_7_entry` (ADR-0017 2nd) + `destiny_branch_judge_reads_scenario_runner_state` (ADR-0018 3rd). Pattern stable at 4 invocations; 3-layer enforcement triad (source-grep lint + ADR inline annotation + integration test) preserved per control-manifest.md §Pillar 2 Architectural Locks (codified 2026-05-04 path-to-PASS item #3).
- **Battle-scoped Node 6th invocation** — pattern confirmed stable; HPStatusController + TurnOrderRunner + BattleCamera + GridBattleController + BattleHUD = 5 prior; AISystem = 6th. Same `_exit_tree()` disconnect discipline + battle-scoped lifecycle + setup-before-add_child mandate inherited cleanly.
- **`ai_system_static_var` forbidden_pattern** — mirrors `grid_battle_controller_static_state` + `hp_status_static_var_state_addition` + `turn_order_static_var_state_addition` + `destiny_branch_judge_static_var` 4-precedent battle-scoped + RefCounted lint pattern. Pattern stable at 5 invocations.
- **`ai_system_signal_emission_outside_action_ready` forbidden_pattern** — mirrors `damage_calc_signal_emission` + `unit_role_signal_emission` + `hero_database_signal_emission` + `balance_constants_signal_emission` + `camera_signal_emission` + `battle_hud_signal_emission` + `grid_battle_controller_signal_emission_outside_battle_domain` + `destiny_branch_judge_emits_gamebus_signal` 8-precedent stateless-emit / non-emitter discipline. Pattern stable at 9 invocations.
- **`ai_system_direct_battle_state_read` forbidden_pattern** — mirrors `destiny_branch_judge_reads_scenario_runner_state` 1-precedent pure-function-takes-snapshot pattern. Pattern stable at 2 invocations.
- **AISystem `ai_action_signal_contract` interface** — uses LOCAL signal pattern (NOT direct_call like `destiny_branch_judge_signal_contract` from delta #13). Both are valid project patterns; LOCAL signal pattern mirrors GridBattleController's 5-LOCAL-signal pattern (now 6 with ai_action_requested) and is the canonical channel for battle-scoped Node-to-Node communication that doesn't cross scene boundaries. No conflict with prior interface contracts.
- **No new GameBus signals** — AISystem adds 0 entries to ADR-0001 §7 Signal Contract Schema. Defense-in-depth via `ai_system_signal_emission_outside_action_ready` lint. ADR-0001 untouched this delta.
- **ADR-0017 ChapterDefinition extension** — ADR-0019 §Migration Plan §8 documents `enemy_roster: Array[Dictionary]` entries gain `archetype: StringName` field. This is an additive Dictionary-field extension, NOT a typed-Resource schema change — does NOT trigger an ADR-0017 amendment per project convention (ChapterDefinition's enemy_roster is already typed `Array[Dictionary]` with open-ended Dictionary contents). Sprint-7+ S7-05 chapter-1 ChapterDefinition `.tres` authoring will populate the field.

### ADR Dependency Order (post-delta #14)

```
Foundation (no dependencies):
  1. ADR-0001 GameBus
  2. ADR-0002 SceneManager
  3. ADR-0003 Save/Load
  4. ADR-0004 MapGrid
  5. ADR-0005 InputHandling
  6. ADR-0006 BalanceConstants
  7. ADR-0007 HeroDatabase
  8. ADR-0008 TerrainEffect
  9. ADR-0009 UnitRole

Core (depends on Foundation):
  10. ADR-0010 HPStatusController
  11. ADR-0011 TurnOrderRunner
  12. ADR-0012 DamageCalc
  13. ADR-0017 ScenarioProgression (delta #12)
  14. ADR-0018 DestinyBranch (delta #13)

Feature (depends on Core):
  15. ADR-0013 BattleCamera
  16. ADR-0014 GridBattleController (amended delta #14: +1 LOCAL signal ai_action_requested for ADR-0019 consumer)
  17. ADR-0016 BattleSceneWiring (amended delta #14: +1 mount step 5.5 for ADR-0019)
  18. ADR-0019 AISystem (depends on ADR-0014/0017/0011/0010/0004/0012/0006/0016; NEW via delta #14)

Presentation (depends on Feature):
  19. ADR-0015 BattleHUD
```

No cycles. No unresolved dependencies. All 19 ADRs Accepted. Topological sort consistent.

---

## Phase 5: Engine Compatibility Cross-Check

### Audit
- All ADRs reference Godot 4.6 ✓
- ADR-0019 §Engine Compatibility table marks Knowledge Risk LOW (Godot 4.6 pinned; no post-cutoff APIs required)
- ADR-0019 §Engine Compatibility §Post-Cutoff APIs Used: "NONE. AISystem uses pre-4.4 stable APIs only: `Node` lifecycle (`_ready` / `_exit_tree`), typed `signal` declarations (4.2+ stable), `match` statements (1.0+), `@export` typed properties on `Resource` (4.0+ stable). The GDD's optional post-MVP `WorkerThreadPool` offload (EC-AI-12) is NOT in scope of this ADR — same-patch deferral."
- 0 deprecated API references in ADR-0019
- Verification Required items 1-5 (BattleStateSnapshot ResourceSaver/Loader round-trip + AIActionCommand serialization + `_exit_tree()` disconnect + 2 lint scripts) — all sprint-7+ implementation scope per Migration Plan §3 + §4 + §5; not BLOCKING for delta #14 acceptance (mirrors delta #13's deferral of OQ-DB-6 5-platform serialization to sprint-7+ S7-03 implementation)

### Engine Specialist Findings

**Skipped this delta** — per delta #11 + #13 lean-mode pattern when ADR introduces zero new post-cutoff API surface. ADR-0019 uses only pre-4.4 stable APIs (Node lifecycle + signals + match + Resource @export). The HIGH-risk surface owned by ADR-0015 (4.6 dual-focus, 4.5 AccessKit, 4.5 recursive Control disable) is NOT re-asserted at AISystem level — AISystem has no UI surface. The MEDIUM-risk surface owned by ADR-0018 (@abstract test seam, parameterless duplicate_deep, StringName field-type preservation through ResourceSaver) is NOT exercised by AISystem either — AISystem uses `match` dispatch (NOT @abstract subclass hierarchy per Alternative 4 rejection) and BattleStateSnapshot is flat-data-only (no nested Resources, no StringName fields requiring round-trip preservation beyond AIActionCommand.skill_id which mirrors the well-tested ADR-0014 BattleOutcome enum @export pattern).

If sprint-7+ S7-04 implementation surfaces an unexpected engine quirk (e.g., `Array[Dictionary]` @export on BattleStateSnapshot.units fails ResourceSaver round-trip on a specific export target), an Implementation Note IN-N can be added to ADR-0019 same-patch with the implementation story per project precedent. No pre-implementation specialist consultation required.

---

## Phase 5b: GDD Revision Flags

**1 ADVISORY — `ai-system.md` CR-AI-1 step "6.5" → "5.5" wording flip** (resolved same-patch this delta per Phase 4 ADVISORY #1).

**No other GDD revision flags** — all other GDD assumptions are consistent with verified engine behaviour and accepted ADRs:
- ai-system.md CR-AI-1..8 + F-AI-1..4 + EC-AI-1..12 + AC-AI-1..14 + OQ-AI-1..5 — ratified at GDD authoring (2026-05-04 commit `b9acb98`); ADR-0019 ratifies the module form interpretation only (no GDD content disagreement)
- grid-battle.md CR-3 + CR-3a + AC-GB-16 — already locks ai_action_requested / ai_action_ready signal protocol at GDD level; ADR-0019 §Decision body matches verbatim
- BattleHUD AI-thinking-indicator subscription (UI-GB-N) — ADR-0019 §Migration Plan §7 documents same-patch with sprint-7+ battle-hud GDD revision; NOT BLOCKING for delta #14 (mirrors delta #11's "battle-hud first-story implementation handles UI-GB-N spec" precedent — battle-hud GDD revisions are tracked separately)
- chapter-prototype/battle_v2.gd:596-678 naive AI design reference — ADR-0019 §Related explicitly preserves this as design reference for Aggressor archetype but does NOT migrate the prototype code per project prototype-code rules

---

## Phase 6: Architecture Registry Updates (delta #14)

`docs/registry/architecture.yaml` v12 → **v13**

### state_ownership (1 added)
- `ai_system_runtime_state` — AISystem battle-scoped Node 6th invocation + 2 typed Resource payloads (BattleStateSnapshot + AIActionCommand) + 4 archetype scoring functions + DI'd GridBattleController reference + battle-scoped instance state only (no static var); owned by ADR-0019

### state_ownership (1 amended)
- `battle_runtime_state` (GridBattleController) — interface field updated to acknowledge 6th LOCAL signal `ai_action_requested(unit_id: int, snapshot: BattleStateSnapshot)` ratified by ADR-0019 acceptance via delta #14 (was 5 LOCAL signals per delta #10 ADR-0015 BattleHUD ratification)

### interfaces (1 added)
- `ai_action_signal_contract` — pattern: **signal** (LOCAL signal NOT GameBus — defense-in-depth via ai_system_signal_emission_outside_action_ready forbidden_pattern); producers: grid-battle-controller (ai_action_requested emission) + ai-system (ai_action_ready emission); consumers: ai-system (subscribes to ai_action_requested) + grid-battle-controller (subscribes to ai_action_ready); signal_signatures: 2 entries; explicit determinism + thread-safety contract codification per CR-AI-5 + EC-AI-12

### api_decisions (1 added)
- `ai_system_module_form` — battle-scoped Node 6th invocation + single-class match-dispatch on archetype StringName (NOT subclass hierarchy) + 2 typed Resources (BattleStateSnapshot + AIActionCommand) + main-thread synchronous MVP execution; 6 alternatives documented (Autoload + RefCounted + static utility + strategy-class hierarchy + behavior trees + GOAP/Min-Max/MCTS — all rejected per ADR-0019 §Alternatives Considered)

### forbidden_patterns (4 added)
1. `ai_system_signal_emission_outside_action_ready` — AISystem MUST NOT emit any GameBus signal; defense-in-depth lint (9-precedent stateless-emit / non-emitter discipline mirror)
2. `ai_system_static_var` — AISystem MUST NOT declare any `static var`; battle-scoped lifecycle requires instance state only (5-precedent battle-scoped + RefCounted lint pattern mirror)
3. `ai_system_reads_destiny_branch_state` — AISystem MUST NOT reference `hidden_fate_condition_progressed` / `DestinyBranchChoice` / `destiny_branch_chosen` token; **Pillar 2 architectural lock — 4th project precedent** of pillar-anchored lint pattern after `battle_hud_subscribes_to_hidden_fate_signal` + `scenario_runner_deferred_seal_in_beat_7_entry` + `destiny_branch_judge_reads_scenario_runner_state`
4. `ai_system_direct_battle_state_read` — AISystem MUST NOT reference `MapGrid.` / `HPStatusController.` / `TurnOrderRunner.` outside the BattleStateSnapshot parameter binding; CR-AI-6 enforcement (1-precedent pure-function-takes-snapshot mirror from `destiny_branch_judge_reads_scenario_runner_state`)

### forbidden_patterns (1 amended)
- `grid_battle_controller_signal_emission_outside_battle_domain` — description amended: "all 5 emitted signals" → "all 6 emitted signals"; signal list extended to include `ai_action_requested(unit_id: int, snapshot: BattleStateSnapshot)`

### Same-patch wording flips applied (8 total)
1. ADR-0014 §8 add 6th LOCAL signal `ai_action_requested(unit_id: int, snapshot: BattleStateSnapshot)` declaration + ratification footnote referencing ADR-0019 / delta #14
2. ADR-0014 §8 prose: "MVP set ratified by ADR-0015 Battle HUD" → "MVP set (5) ratified by ADR-0015 Battle HUD; 6th signal ai_action_requested ratified by ADR-0019"
3. ADR-0014 §R-1 budget revision: "5 signals" → "6 signals" with ai_action_requested per-frame budget note
4. ADR-0014 §Enables block: add ADR-0019 reference (AI System Accepted via delta #14)
5. ADR-0014 §9 architecture diagram: add `ai_action_requested → AI System (sprint-7+)` row
6. ADR-0016 §3 R-3 mount sequence: insert "(5.5) AISystem.setup(grid_controller) → add_child" between current step 5 and step 6 + add ADR-0019 cross-ref
7. ADR-0016 Soft/Provisional dependencies block: add ADR-0019 entry (AI System Accepted via delta #14 — same-patch documentation amendment for step 5.5 insertion)
8. ai-system.md CR-AI-1 line 28 wording: "post-MVP step 6.5, between GridBattleController and BattleHUD per ADR-0019 §Mount Order — to be ratified" → "step 5.5 (between GridBattleController and BattleHUD per ADR-0019 §Mount Order — Accepted via /architecture-review delta #14)"

Plus 2 same-patch corrections from Phase 4:
- architecture.yaml `battle_runtime_state` interface field: 5-signal set → 6-signal set
- architecture.yaml `grid_battle_controller_signal_emission_outside_battle_domain` description: 5 → 6 signals

Total 10 wording flips across 4 docs (within delta-pattern range; delta #9 24-correction close-out anomaly was higher; delta #13 had 13 same-patch flips; this delta has 10).

---

## Phase 7: Output Summary

### Traceability Summary
- Total requirements: 254 (was 239)
- ✅ Covered: 254 (100%)
- ⚠️ Partial: 0
- ❌ Gaps: 0

### Coverage Gaps
None. All 19 Accepted ADRs have full TR coverage in tr-registry.yaml v15.

### Cross-ADR Conflicts
1 BLOCKING resolved same-patch (CONFLICT #1 — ADR-0014 §8 5-signal set vs ADR-0019 6th `ai_action_requested` signal; resolved via same-patch ADR-0014 additive amendment to §8 + R-1 + Enables + §9 diagram + 2 architecture.yaml entry updates).

### ADR Dependency Order
Topologically sorted (see Phase 4 above). No cycles. No unresolved dependencies. All 19 ADRs Accepted.

### GDD Revision Flags
1 ADVISORY resolved same-patch (ai-system.md CR-AI-1 step "6.5" → "5.5" wording flip).

### Engine Compatibility Issues
None. ADR-0019 introduces zero post-cutoff API surface.

### Architecture Document Coverage
`docs/architecture/architecture.md` v0.8 (refreshed delta #11) — Layer Map should be refreshed to reflect Feature 4/4 (was 3/4) at next opportunity. **NOT BLOCKING for delta #14 acceptance**; structural backfill only.

---

## Verdict: PASS WITH 1 BLOCKING + 1 ADVISORY CORRECTIONS

Both corrections resolved same-patch within this delta's commit. ADR-0019 Status flipped Proposed → **Accepted (2026-05-05)**.

### Blocking Issues (FAIL only — none)
None. ADR-0014 §8 6th-signal additive amendment resolved the BLOCKING cross-ADR integration conflict.

### Required ADRs (next priority — all OPTIONAL post-delta #14)
1. **Battle Preparation ADR** (post-MVP) — pre-battle hero loadout + formation pick + battle_prepare_requested subscriber per ADR-0017 §Migration Plan §1; UNBLOCKED by ADR-0017+0018+0019 chain but not required for chapter-1 vertical-slice scope
2. **Story Event #10 + Destiny State #16 GDDs** (sprint-7+ S7-06 + S7-07 design authoring; UNBLOCKED by delta #13 ADR-0018 ratification — each load-bearing for chapter-1 narrative beats per Producer cut-point logic)
3. **Save/Load #17 VS GDD** (CUT from sprint-7 per Producer pressure-cut decision; in-memory CP-1/2/3 satisfies sprint-7 demo)

---

## Phase 8: Files Updated This Delta

1. `docs/architecture/ADR-0019-ai-system.md` — Status Proposed → Accepted (2026-05-05); Changelog row added
2. `docs/architecture/ADR-0014-grid-battle-controller.md` — §8 6th LOCAL signal `ai_action_requested` declaration + prose update + R-1 budget revision (5 → 6) + Enables block ADR-0019 entry + §9 architecture diagram row addition (5 wording flips)
3. `docs/architecture/ADR-0016-battle-scene-wiring.md` — §3 R-3 mount sequence step 5.5 insertion + Soft/Provisional dependencies block ADR-0019 entry (2 wording flips)
4. `design/gdd/ai-system.md` — CR-AI-1 line 28 step "6.5" → "5.5" wording flip + remove "to be ratified" qualifier (1 wording flip)
5. `docs/registry/architecture.yaml` — v12 → v13 (1 state_ownership added + 1 state_ownership amended + 1 interface added + 1 api_decision added + 4 forbidden_patterns added + 1 forbidden_pattern amended + delta #14 comment block)
6. `docs/architecture/tr-registry.yaml` — v14 → v15 (15 net-new TR-ai-system-001..015 entries + delta #14 comment block)
7. `docs/architecture/architecture-traceability.md` — v0.13 → v0.14 (Document Status block + Coverage summary Feature 3/4 → 4/4 + 15 new TR rows + ai-system GDD section + delta #14 changelog row)
8. `docs/architecture/architecture-review-2026-05-05.md` — this report (NEW)
9. `production/session-state/active.md` — session extract for delta #14 (appended)

---

## Phase 9: Handoff

### Immediate actions
1. **Sprint-7+ AISystem implementation (S7-04)** — ADR-0019 Migration Plan §2..§5 ships in single coordinated patch (3 new source files + 2 test helpers + 5 unit/integration test files + 4 CI lint scripts + GridBattleController extension `_make_battle_state_snapshot()` + BattleScene mount sequence step 5.5 insertion + chapter-1 ChapterDefinition.enemy_roster archetype assignments). Single-patch atomicity per delta-#13 ADR-0018 Migration Plan precedent.
2. **Sprint-7+ ScenarioRunner implementation (S7-02)** — ADR-0017 Migration Plan §1..§11 same coordinated patch (independent of S7-04 but coordinated at sprint-7 plan level)
3. **Sprint-7+ DestinyBranchJudge implementation (S7-03)** — ADR-0018 Migration Plan §5 already authored at delta #13 handoff; same coordinated patch
4. **Architecture.md Layer Map refresh** — update Feature 3/4 → 4/4 + ADR coverage 18 → 19 at next architecture.md amendment opportunity (NOT BLOCKING)
5. **GridBattleController source-code amendment (sprint-7+ S7-04 same-patch)** — add `signal ai_action_requested(unit_id: int, snapshot: BattleStateSnapshot)` declaration to `src/feature/grid_battle/grid_battle_controller.gd` (currently 5 signals at lines 85-99 → 6 signals); add `_make_battle_state_snapshot() -> BattleStateSnapshot` private helper per ADR-0019 §Migration Plan §6; add `ai_action_requested.emit(unit_id, snapshot)` call site at AI-turn entry point. Source-code change ships with S7-04 implementation patch; this delta documents the architecture-side ratification only.

### Gate guidance
**Pre-Production → Production gate is now eligible** (mandatory ADR list = 0; AI System closes the cross-director convergent blocker per gate-check 2026-05-04 path-to-PASS item #4). Run `/gate-check pre-production` AFTER S7-01..S7-07 close + S7-11 user attestation captured → expect upgrade CONCERNS → PASS + `production/stage.txt` written = "Production".

### Rerun trigger
Re-run `/architecture-review` after Battle Preparation ADR is authored (post-MVP scope; not sprint-7 critical path) OR if a future AI System amendment is needed (e.g., WorkerThreadPool deferral per EC-AI-12 promotion to mainline if P99 > 200ms profiling surfaces). Both are post-sprint-7 scope; not blocking for current sprint.

---

## Pattern Observations

- **14-invocation pattern**: /architecture-review pattern stable; this delta = 1 BLOCKING + 1 ADVISORY corrections (well below delta #6 6-correction HIGH-risk anomaly + delta #9 24-correction close-out anomaly; matches typical delta correction count)
- **Same-session godot-specialist 16th invocation skipped this delta** — no new engine API surface; ADR-0019 introduces zero post-cutoff APIs; HIGH-risk surface owned by ADR-0015 not re-asserted at AISystem level. Specialist invocation count remains at 16 (last invocation delta #13)
- **Combined-session pattern (escalation + structural append)**: **4th invocation** (after delta #11 ADR-0016 + delta #12 ADR-0017 + delta #13 ADR-0018); pattern firmly stable at 4 invocations — codification candidate carried forward (delta #11): future deltas should default to combining escalation + structural append in single fresh session unless TR backfill volume exceeds typical single-session capacity
- **Cross-ADR integration conflict at downstream-ADR acceptance time**: **5th project precedent** of "ratification widening at upstream-ADR acceptance" (after save_checkpoint_requested 2026-04-18 + scenario_complete delta #12 + scenario_beat_retried delta #12 + ADR-0017 line 209 instance-form widening delta #13 + this delta's ADR-0014 §8 6th-signal additive amendment). Pattern firmly stable at 5 invocations; the upstream ADR's signal/call surface typically lags behind a downstream ADR that ratifies the consumer
- **Pillar-anchored lint pattern (Pillar 2 architectural lock)**: **4th invocation** (`ai_system_reads_destiny_branch_state` follows `destiny_branch_judge_reads_scenario_runner_state` ADR-0018 + `scenario_runner_deferred_seal_in_beat_7_entry` ADR-0017 + `battle_hud_subscribes_to_hidden_fate_signal` ADR-0015 — all 4 are Pillar 2 architectural locks). Pattern firmly stable at 4 invocations; control-manifest.md §Pillar 2 Architectural Locks codification (2026-05-04 path-to-PASS item #3) holds — 3-layer enforcement triad (source-grep lint + ADR inline annotation + integration test) consistently applied
- **Battle-scoped Node pattern**: **6th invocation** (AISystem follows HPStatusController + TurnOrderRunner + BattleCamera + GridBattleController + BattleHUD). Pattern firmly stable at 6 invocations; setup-before-add_child mandate + `_exit_tree()` disconnect discipline + battle-scoped lifecycle non-persistence + instance-state-only enforcement all carried forward
- **LOCAL signal pattern (NOT GameBus) for battle-internal events**: **2nd invocation** of LOCAL signal channel for cross-Node battle-internal communication (after GridBattleController's 5+1 LOCAL signals; AISystem's 1 LOCAL signal `ai_action_ready`). Pattern stable at 2 invocations — battle-internal events with single-consumer pairs use LOCAL signals to avoid GameBus 50-emits/frame budget consumption per ADR-0001 §445
- **Single-class match-dispatch over subclass hierarchy** (AISystem) — 1st invocation of this pattern (vs ADR-0018 DestinyBranchJudge's @abstract subclass hierarchy). Establishes pattern boundary: single-class match-dispatch for closed enum-keyed dispatch with closed MVP scope (4 archetypes); subclass hierarchy with @abstract test seam for open extensibility + complex test stubbing requirements. Codification candidate: future ADRs ratifying enum-keyed dispatch logic should default to single-class match-dispatch unless test stubbing or extensibility justifies subclass hierarchy
- **Codification candidate (carried forward)**: when a downstream ADR ratifies a consumer-side signal subscription, pre-validate that the upstream ADR's signal set covers the assumed signal in the /architecture-decision phase + flag any missing signals as Phase 4 same-patch additive-amendment targets at the /architecture-review delta time. Future formula-evaluator / consumer ADRs should pre-validate upstream signal sets + interface contracts before Proposed-status authoring closes
