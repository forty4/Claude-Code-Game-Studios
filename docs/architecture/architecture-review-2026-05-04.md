# Architecture Review Report — Delta #12

**Date**: 2026-05-04
**Mode**: Lean (per `production/review-mode.txt`); fresh-session escalation per same-session-ban discipline
**Engine**: Godot 4.6 (project pinned 2026-04-16)
**Sprint**: S6-10
**Session**: combined ADR-0017 escalation Proposed → Accepted + structural append (12 net-new TR-scenario-progression entries) — second /architecture-review delta to combine escalation + structural backfill in single fresh session (pattern stable at 2 invocations after delta #11)

---

## Verdict

**PASS WITH 3 CORRECTIONS** — all 3 corrections resolved same-patch within this delta's commit:
- 1 BLOCKING cross-ADR signal-payload conflict (ADR-0001 vs ADR-0017) — resolved via **Path A user decision** (amend ADR-0001 same-patch)
- 1 BLOCKING stale-ref backfill (ADR-0001 line 284 `scenario_beat_retried` PROVISIONAL → RATIFIED with shipped 3-field EchoMark) — resolved
- 2 ADVISORY items (test fixture enum access + `Time.get_ticks_msec()`) — added as ADR-0017 Implementation Notes IN-1 + IN-2

ADR-0017 Status: **Accepted (2026-05-04)**. Total accepted ADR count: 16 → **17**. Core layer 3/3 → **4/4 Complete**.

**Mandatory ADR list**: 0 → 0 (unchanged). Pre-Production → Production gate remains technically eligible; ADR-0018 Destiny Branch is the strongly recommended next ADR before invoking `/gate-check pre-production` (closes Pillar 2 + Pillar 4 architectural narrative-pillar substrate).

---

## Phase 1: Inputs Loaded

- ADR-0017 Scenario Progression (550 lines after godot-specialist 4 fixes from /architecture-decision phase)
- ADR-0001 GameBus Autoload (signal contract source-of-truth)
- ADR-0002 SceneManager (Overworld↔BattleScene transition lifecycle)
- ADR-0003 Save/Load (SaveContext + 3-CP policy + EchoMark §Schema Stability)
- ADR-0014 GridBattleController (BattleOutcome emission)
- ADR-0016 BattleSceneWiring (Migration Plan §1 mock encoder deletion target)
- design/gdd/scenario-progression.md (1527 lines; 16 CR + 6 F-SP + 14 EC-SP + 19 AC-SP)
- docs/registry/architecture.yaml v10
- docs/architecture/tr-registry.yaml v12
- godot-4x-gotchas.md (G-3 autoload + G-2 typed-Dictionary-export)
- engine-reference/godot/{VERSION.md, breaking-changes.md, deprecated-apis.md}

---

## Phase 2-3: Traceability Matrix Update

Existing 3 TR-scenario-progression entries preserved (TR-001..003 from delta #1 baseline). Appended 12 new TR-scenario-progression-004..015 covering ADR-0017's specific architectural decisions:

| TR-ID | Coverage | ADR |
|-------|----------|-----|
| TR-scenario-progression-004 | ScenarioRunner autoload Node form (G-3 compliance) | ADR-0017 |
| TR-scenario-progression-005 | 13-state enum + match-statement state machine | ADR-0017 |
| TR-scenario-progression-006 | ChapterDefinition typed Resource (13 @export fields, untyped branch_table per G-2) | ADR-0017 |
| TR-scenario-progression-007 | 7-signal contract (5 confirmed + 2 ratified at delta #12; scenario_complete payload widening) | ADR-0017 |
| TR-scenario-progression-008 | F-SP-3 v2.2 SYNCHRONOUS seal at BEAT_7 entry | ADR-0017 |
| TR-scenario-progression-009 | F-SP-1/F-SP-2 delegation to DestinyBranchJudge.resolve(...) | ADR-0017 |
| TR-scenario-progression-010 | Retry-loop guard two-layer defense (state + outcome assertion) | ADR-0017 |
| TR-scenario-progression-011 | 3-CP save emission timing (BEAT_1 / BEAT_7 post-seal / BEAT_9) | ADR-0017 |
| TR-scenario-progression-012 | BattlePayload reuse (no new BattleConfig type) | ADR-0017 |
| TR-scenario-progression-013 | JSON validation pipeline at LOADING entry per EC-SP-8 | ADR-0017 |
| TR-scenario-progression-014 | 5 forbidden_patterns registered v10 → v11 | ADR-0017 |
| TR-scenario-progression-015 | Migration Plan §1 atomicity (11 mechanical changes single sprint-7+ patch) | ADR-0017 |

Total TR count: 212 → **224**. tr-registry.yaml v12 → v13.

---

## Phase 4: Cross-ADR Conflict Detection

### 🔴 CONFLICT #1 (BLOCKING; Type: Integration contract / Signal payload)

**ADR-0001 vs ADR-0017** — `scenario_complete` signal payload shape mismatch.

- **ADR-0001 line 147**: `signal scenario_complete(scenario_id: String)` — single String payload
- **ADR-0001 line 283 table**: payload type `String` / fields `scenario_id: String`
- **ADR-0017 line 267 §Architecture Diagram**: `scenario_complete(ScenarioResult)` — typed Resource payload
- **ADR-0017 lines 346-351 §Key Interfaces**: defines `ScenarioResult` Resource with 4 fields (chapter_outcomes / canonical_delta / scenario_path_key / total_echo)
- **ADR-0017 line 480 §GDD Requirements**: explicitly claims "scenario_complete(ScenarioResult) at last chapter Beat 9"

**Impact**: Either ADR-0001 or ADR-0017 must be amended; cannot accept ADR-0017 with internal claim contradicting ADR-0001 source-of-truth.

**Resolution paths offered**:
- **(A) Amend ADR-0001 same-patch** — widen `scenario_complete` payload String → ScenarioResult; mirrors GDD intent (CR-16 + F-SP-4); matches `save_checkpoint_requested` 2026-04-18 ratification precedent
- **(B) Amend ADR-0017 same-patch** — revert §Architecture Diagram + §Key Interfaces; ScenarioResult becomes query-time API on ScenarioRunner (`get_scenario_result(): ScenarioResult`); signal stays String form
- **(C) Defer ADR-0017 acceptance** — preserve Proposed status; reopen for fresh-session amendment

**User decision (AskUserQuestion 2026-05-04)**: **Path A** (amend ADR-0001 same-patch)

**Resolution applied**:
1. ADR-0001 line 147: `signal scenario_complete(scenario_id: String)` → `signal scenario_complete(result: ScenarioResult)` + delta #12 reference
2. ADR-0001 line 283: table row updated with full ScenarioResult field list + RATIFIED via delta #12 marker
3. ADR-0001 §PROVISIONAL → RATIFIED list: new "(2026-05-04 via /architecture-review delta #12)" subsection added with both `scenario_complete` (widening) and `scenario_beat_retried` (ratification) entries

### 🟡 STALE-REF BACKFILL #1 (BLOCKING; Type: Cross-ADR coordination)

**ADR-0001 line 284**: `scenario_beat_retried` table row prose lists provisional 4-field shape (chapter_id / beat_number / retry_count / timestamp_unix) with `[PROVISIONAL — locked by Destiny State GDD #16]` marker. The signal declaration (line 148) is correctly typed `EchoMark` Resource — but the table prose was never updated to reflect the SHIPPED 3-field schema (beat_index / outcome / tag) ratified by ADR-0003 §Schema Stability.

**Resolution applied**:
1. ADR-0001 line 284 table prose: full rewrite with 3-field schema + RATIFIED via delta #12 marker
2. ADR-0001 line 363-364: PROVISIONAL signal count 4 → 3; `scenario_beat_retried` removed from PROVISIONAL list
3. ADR-0001 line 148 (signal declaration): inline comment added documenting delta #12 ratification

### 🟢 No other cross-ADR conflicts

ADR-0017's 7-signal contract aligns with ADR-0001 §1 Scenario domain table (lines 142-148 + 178-180 + 275-284 + 351). ADR-0014's `battle_outcome_resolved(BattleOutcome)` consumer contract aligns with ADR-0017 §Decision §Architecture Diagram. ADR-0003's 3-CP timing (CP-1 BEAT_1 / CP-2 RETURNING_FROM_BATTLE→IDLE / CP-3 next-chapter) aligns with ADR-0017's BEAT_1 / BEAT_7 post-seal / BEAT_9 emission points (CP-2 timing description differs in framing — ADR-0003 says "post-Beat 7 resolution persisted via SceneManager boundary observation", ADR-0017 says "BEAT_7 entry post-seal" — same intent: CP-2 captures state after seal but before DestinyBranchJudge.resolve runs). ADR-0016's Migration Plan §1 deletion sites are mechanically reachable from ADR-0017's §Migration Plan steps 7-11.

### ADR Dependency Order (post-delta #12)

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
  10. ADR-0010 HPStatusController (depends on ADR-0001/0006/0007)
  11. ADR-0011 TurnOrderRunner (depends on ADR-0001/0010)
  12. ADR-0012 DamageCalc (depends on ADR-0001/0006/0007/0009/0010)
  13. ADR-0017 ScenarioProgression (depends on ADR-0001/0002/0003/0014; NEW via delta #12)

Feature (depends on Core):
  14. ADR-0013 BattleCamera (depends on ADR-0001/0004/0005)
  15. ADR-0014 GridBattleController (depends on ADR-0001/0004/0005/0007/0008/0009/0010/0011/0012/0013)
  16. ADR-0016 BattleSceneWiring (depends on ADR-0001/0002/0004/0005/0010/0011/0013/0014/0015)

Presentation (depends on Feature):
  17. ADR-0015 BattleHUD (depends on ADR-0001/0005/0010/0011/0014)

UNBLOCKED for next sprint:
  18. ADR-0018 DestinyBranch (depends on ADR-0017 — UNBLOCKED via this delta)
```

No cycles. No unresolved dependencies. Topological sort consistent.

---

## Phase 5: Engine Compatibility Cross-Check

### Audit
- All ADRs reference Godot 4.6 ✓
- ADR-0017 §Engine Compatibility table marks Knowledge Risk LOW; confirmed (no post-cutoff API surface introduced; uses only Node 4.0 APIs + JSON.parse_string + Resource @export)
- 0 deprecated API references in ADR-0017
- 0 stale version references (all Accepted ADRs reference 4.6 or are version-agnostic)

### Engine Specialist Findings (godot-specialist 14th invocation, /architecture-review delta #12 mode)

**Verdict: PASS WITH 3 CORRECTIONS**

| Item | Status | Detail |
|------|--------|--------|
| 1: G-3 fix landed correctly | PASS | ADR-0017 lines 79 + 282 + 500 all show `extends Node` without `class_name ScenarioRunner` |
| 2: Typed-Dict-export fix landed correctly | PASS | Line 136 shows untyped `Dictionary = {}` with G-2 cross-reference |
| 3: `Resource.duplicate_deep` | PASS | Line 18 cites 4.5+ form; no `duplicate(true)` remains |
| 4: EchoMark schema | **CORRECTION** | ADR-0017 correctly references shipped 3-field schema; ADR-0001 line 284 table prose is stale (provisional 4-field shape) — see STALE-REF BACKFILL #1 above |
| 5: Boot order | PASS | GameBus → SceneManager → SaveManager → GameBusDiagnostics → BuildModeSentinel → ScenarioRunner correctly listed at lines 88 + 505 |
| 6: Signal contract alignment | **BLOCKING CORRECTION** | scenario_complete payload mismatch — see CONFLICT #1 above |
| 7: PackedInt64Array @export | PASS | Lines 146 + 148 supported in 4.x |
| 8: Array[Dictionary] / Array[BattleStartEffect] @export | PASS | G-2 only restricts typed `Dictionary[K,V]`; typed Array of unparameterized Dictionary is supported |
| 9: State enum external access | **ADVISORY** | Autoload-syntax `ScenarioRunner.State.X` works at runtime; headless test fixtures must use `(load(PATH) as GDScript).get_script_constant_map()` per G-3 §Test consequence — added as ADR-0017 IN-1 |
| 10: `Time.get_ticks_msec()` | **ADVISORY** | `_state_entered_at_msec: int = 0` field needs Time API not deprecated OS API — added as ADR-0017 IN-2 |

All 3 corrections resolved same-patch. 0 corrections deferred.

---

## Phase 5b: GDD Revision Flags

**None** — all GDD assumptions are consistent with verified engine behaviour. Specifically:
- scenario-progression.md §F-SP-4 + §CR-16 already lock the ScenarioResult shape that ADR-0017 emits; ADR-0001 was the stale ref (not the GDD)
- scenario-progression.md §States and Transitions table aligns 1:1 with ADR-0017's 13-state enum
- F-SP-3 v2.2 systems-designer B-1 invariant (SYNCHRONOUS seal at BEAT_7 entry) is correctly codified in ADR-0017 §Decision §F-SP-1/F-SP-2 + §forbidden_patterns

Minor advisory observations (NOT blocking; not flagged as revisions):
- GDD has F-SP-1 through F-SP-6 (6 formulas); ADR-0017 §GDD Requirements table mentions "F-SP-1..F-SP-5" (range of 5). F-SP-6 (Timing constants) is implicitly covered via ADR-0017 §State Machine Form line 110 `_state_entered_at_msec` field. Future ADR-0017 amendment may explicit the F-SP-6 row in the §GDD Requirements table.
- GDD has EC-SP-1 through EC-SP-14 (14 edge cases — v2.1 added EC-SP-10..14); ADR-0017 §GDD Requirements table mentions "EC-SP-1..EC-SP-9". The v2.1 additions (EC-SP-10..14) are transparently handled by ADR-0017's codifications (3-CP policy + F-SP-1 fallback + state guards). Future ADR-0017 amendment may explicit the EC-SP-10..14 rows.

---

## Phase 6: Architecture Registry Updates (delta #12)

`docs/registry/architecture.yaml` v10 → **v11**

### state_ownership (1 added)
- `scenario_runner_runtime_state` — owns 13-state enum + `_scenario_state` struct + ChapterLoader logic + 7-signal emission

### interfaces (1 added)
- `scenario_progression_signal_contract` — pattern: signal; producer: scenario-progression; consumers: 7 systems; signal_signatures: 7 entries with full payload shapes (including ScenarioResult widening + EchoMark ratification)

### api_decisions (1 added)
- `scenario_runner_module_form` — autoload Node (extends Node, NO `class_name` per G-3) + enum-match state machine + ChapterDefinition typed Resource + BattlePayload reuse + DestinyBranchJudge delegation; 4 alternatives documented with rejection reasons

### forbidden_patterns (5 added)
1. `scenario_runner_arbitrary_state_jump` — `_state =` outside `_transition_to()` forbidden
2. `scenario_runner_branch_table_runtime_mutation` — `chapter.branch_table[k] = v` forbidden after LOADING exit
3. `scenario_runner_save_context_partial_emit` — SaveContext construction must go through single `_make_save_context()` helper
4. `scenario_runner_deferred_seal_in_beat_7_entry` — **Pillar 2 architectural lock** — second project precedent of pillar-anchored lint pattern after `battle_hud_subscribes_to_hidden_fate_signal`
5. `scenario_runner_outcome_synthesis` — ScenarioRunner MUST NOT assign or override BattleOutcome.result (CR-3 invariant)

### Same-patch wording flips applied (8 total)
1. ADR-0001 line 147: signal payload widening
2. ADR-0001 line 283: table row payload + ratification marker
3. ADR-0001 line 284: scenario_beat_retried PROVISIONAL → RATIFIED prose
4. ADR-0001 line 363-364: PROVISIONAL count 4 → 3
5. ADR-0001 line 369-370: new "PROVISIONAL → RATIFIED 2026-05-04 via delta #12" subsection
6. ADR-0014 line 33: "Scenario Progression ADR (NOT YET WRITTEN)" → "ADR-0017 Accepted via delta #12"
7. ADR-0014 line 590: same flip
8. ADR-0016 line 37: "ADR-0017 Scenario Progression (NOT YET WRITTEN)" → "ADR-0017 Accepted via delta #12"

Within delta-pattern range; delta #9 24-correction close-out anomaly was higher.

### ADR-0017 Implementation Notes (2 ADVISORY items added)
- IN-1: Test fixture State enum access pattern (G-3 consequence for headless tests)
- IN-2: `Time.get_ticks_msec()` requirement (vs deprecated `OS.get_ticks_msec()`)

---

## Phase 7: Output Summary

### Traceability Summary
- Total requirements: 224 (was 212)
- ✅ Covered: 224 (100%)
- ⚠️ Partial: 0
- ❌ Gaps: 0

### Coverage Gaps
None. All 17 Accepted ADRs have full TR coverage in tr-registry.yaml v13.

### Cross-ADR Conflicts
1 BLOCKING resolved same-patch (CONFLICT #1 above; Path A user decision — amend ADR-0001 widening scenario_complete payload).

### ADR Dependency Order
Topologically sorted (see Phase 4 above). No cycles. No unresolved dependencies. ADR-0018 Destiny Branch UNBLOCKED.

### GDD Revision Flags
None. All GDD assumptions consistent with verified engine behaviour.

### Engine Compatibility Issues
None blocking. 2 ADVISORY items (IN-1 + IN-2) added to ADR-0017 Implementation Notes.

### Architecture Document Coverage
`docs/architecture/architecture.md` v0.8 (refreshed delta #11) — Layer Map should be refreshed to reflect Core 4/4 (was 3/3) at next opportunity. NOT BLOCKING for delta #12 acceptance; structural backfill only.

---

## Verdict: PASS WITH 3 CORRECTIONS

All 3 corrections resolved same-patch within this delta's commit. ADR-0017 Status flipped Proposed → **Accepted (2026-05-04)**.

### Blocking Issues (FAIL only — none)
None. Path A user decision resolved the only BLOCKING cross-ADR conflict.

### Required ADRs (next priority)
1. **ADR-0018 Destiny Branch** (sprint-6 nice-to-have S6-11 / sprint-7 — UNBLOCKED by this delta) — owns DestinyBranchJudge executor + DestinyBranchChoice payload; F-SP-1/F-SP-2 callable signatures locked in this ADR enable authoring without further ADR-0017 amendments
2. AI System ADR (sprint-7+) — required for Battle Prep epic
3. Battle Preparation ADR (sprint-7+) — subscribes to `battle_prepare_requested` emission point ratified by ADR-0017

---

## Phase 8: Files Updated This Delta

1. `docs/architecture/ADR-0017-scenario-progression.md` — Status Proposed → Accepted; 2 ADVISORY Implementation Notes added (IN-1 + IN-2); §Constraints note updated re: scenario_complete widening
2. `docs/architecture/ADR-0001-gamebus-autoload.md` — 3 amendments (signal declaration line 147 + table row line 283 + table row line 284 + PROVISIONAL count line 363 + new RATIFIED subsection)
3. `docs/architecture/ADR-0014-grid-battle-controller.md` — 2 stale-ref backfill flips (lines 33 + 590)
4. `docs/architecture/ADR-0016-battle-scene-wiring.md` — 1 stale-ref backfill flip (line 37 §Soft / Provisional)
5. `docs/registry/architecture.yaml` — v10 → v11 (1 state_ownership + 1 interface + 1 api_decision + 5 forbidden_patterns + delta #12 comment block)
6. `docs/architecture/tr-registry.yaml` — v12 → v13 (12 net-new TR-scenario-progression-004..015 entries + delta #12 comment block)
7. `docs/architecture/architecture-traceability.md` — v0.11 → v0.12 (Document Status block + Coverage summary Core 3/3 → 4/4 + 12 new TR rows + scenario-progression GDD section update + delta #12 changelog row)
8. `docs/architecture/architecture-review-2026-05-04.md` — this report (NEW)
9. `production/session-state/active.md` — session extract for delta #12 (appended)

---

## Phase 9: Handoff

### Immediate actions
1. **ADR-0018 Destiny Branch authoring** — UNBLOCKED by this delta; F-SP-1/F-SP-2 callable signatures locked; DestinyBranchJudge executor + DestinyBranchChoice payload authoring path clear. Run in fresh session: `/architecture-decision destiny-branch`
2. **Sprint-7+ ScenarioRunner implementation** — ADR-0017 Migration Plan §1..§11 ship in single coordinated patch; coordinate with battle-scene mock encoder revert per ADR-0016 §Migration Plan §1
3. **Architecture.md Layer Map refresh** — update Core 3/3 → 4/4 at next architecture.md amendment opportunity (NOT BLOCKING)

### Gate guidance
Pre-Production → Production gate is technically eligible (mandatory ADR list = 0). Strongly recommended to land ADR-0018 Destiny Branch before invoking `/gate-check pre-production` (closes Pillar 2 + Pillar 4 architectural narrative-pillar substrate).

### Rerun trigger
Re-run `/architecture-review` after ADR-0018 Destiny Branch is authored (in a fresh session per same-session-ban discipline) to verify the F-SP-1/F-SP-2 executor contract aligns with the spec ADR-0017 locks.

---

## Pattern Observations

- **12-invocation pattern**: /architecture-review pattern stable; this delta = 3 corrections (above mean ~2.5 but well below delta #6 6-correction HIGH-risk anomaly + delta #9 24-correction close-out anomaly)
- **Same-session godot-specialist 14th invocation**: PASS WITH 3 CORRECTIONS resolved same-patch; same-session pattern stable at 14 invocations
- **Combined-session pattern (escalation + structural backfill)**: 2nd invocation (after delta #11 ADR-0016); pattern now stable at 2 invocations
- **PROVISIONAL signal ratification pattern**: 7th invocation (scenario_beat_retried follows save_checkpoint_requested 2026-04-18 + 5 other PROVISIONAL signals' eventual ratification path)
- **Autoload Node lineage**: 6th invocation (ScenarioRunner extends GameBus + SceneManager + SaveManager + GameBusDiagnostics + BuildModeSentinel 5-precedent autoload form)
- **Enum + match state machine pattern**: 2nd invocation (after SceneManager ADR-0002); pattern now stable at 2 invocations
- **Pillar-anchored lint pattern**: 2nd invocation (`scenario_runner_deferred_seal_in_beat_7_entry` follows `battle_hud_subscribes_to_hidden_fate_signal` ADR-0015 — both Pillar 2 architectural locks)
- **Cross-ADR signal-payload widening at ratification**: 2nd invocation (scenario_complete widening follows save_checkpoint_requested 2026-04-18 ratification widening; first widening was String → SaveContext, this one is String → ScenarioResult)
- **Codification candidate**: when an ADR ratifies a PROVISIONAL signal at /architecture-review delta time, the ratification commonly involves payload widening (typed Resource replacing primitive); future ADRs that introduce typed Resource payloads should include same-patch ADR-0001 amendment in their Migration Plan §0 (per delta #8 codification candidate for added signals)
