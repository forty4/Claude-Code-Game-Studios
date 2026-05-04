# Architecture Review Report — Delta #13

**Date**: 2026-05-04
**Mode**: Lean (per `production/review-mode.txt`); fresh-session escalation per same-session-ban discipline
**Engine**: Godot 4.6 (project pinned 2026-04-16)
**Sprint**: S6-11
**Session**: combined ADR-0018 escalation Proposed → Accepted + structural append (15 net-new TR-destiny-branch entries) — **3rd consecutive /architecture-review delta to combine escalation + structural append in single fresh session** (pattern stable at 3 invocations after delta #11 + #12)

---

## Verdict

**PASS WITH 1 BLOCKING + 1 ADVISORY CORRECTIONS** — both resolved same-patch within this delta's commit:
- 1 BLOCKING cross-ADR integration conflict (ADR-0017 line 209 static-method call vs ADR-0018 RefCounted instance-method ratification) — resolved via same-patch ADR-0017 instance-form widening
- 1 ADVISORY C-2 residual (ADR-0018 line 56 `DEEP_DUPLICATE_ALL` constant inconsistent with line 17 advisement) — resolved via same-patch line 56 flip to parameterless `duplicate_deep()` form

ADR-0018 Status: **Accepted (2026-05-04)**. Total accepted ADR count: 17 → **18**. Core layer 4/4 → **5/5 Complete** (DestinyBranchJudge closes Core layer; Pillar 2 + Pillar 4 architectural narrative-pillar substrate complete).

**Mandatory ADR list**: 0 → 0 (unchanged since delta #8). **Pre-Production → Production gate is now strongly eligible** — ADR-0018 was the strongly-recommended pre-gate ADR per delta #12 handoff (closes Pillar 2 + Pillar 4 architectural substrate).

---

## Phase 1: Inputs Loaded

- ADR-0018 Destiny Branch (834 lines after godot-specialist 15th-invocation 3 advisory corrections from /architecture-decision phase + Status flip + line 56 C-2 residual fix this delta)
- ADR-0001 GameBus Autoload (signal contract source-of-truth — amendment target)
- ADR-0017 Scenario Progression (Accepted via delta #12 — line 209 same-patch flip target)
- ADR-0014 Grid Battle Controller (BattleOutcome.Result enum dependency)
- ADR-0003 Save/Load (CP-2/CP-3 timing anchors + SaveContext schema)
- design/gdd/destiny-branch.md (981 lines; rev 1.3.1 → 1.3.2 sync target)
- design/gdd/scenario-progression.md (CR-7 4th-argument invariant + F-SP-3 v2.2 sealing)
- docs/registry/architecture.yaml v11
- docs/architecture/tr-registry.yaml v13
- godot-4x-gotchas.md (G-3 autoload + G-22 @abstract parse-time-on-typed-references)
- engine-reference/godot/{VERSION.md, breaking-changes.md, deprecated-apis.md}

---

## Phase 2-3: Traceability Matrix Update

15 net-new TR-destiny-branch-001..015 entries appended to tr-registry.yaml v13 → v14:

| TR-ID | Coverage | ADR |
|-------|----------|-----|
| TR-destiny-branch-001 | RefCounted pure-function class form (1st @abstract test-seam pattern in project) | ADR-0018 |
| TR-destiny-branch-002 | 4-arg resolve() signature inherited from ADR-0017 line 200 (3rd ratification widening at upstream-ADR acceptance) | ADR-0018 |
| TR-destiny-branch-003 | 9-field DestinyBranchChoice typed Resource (ratifies ADR-0001 5-field PROVISIONAL via Evolution Rule #4) | ADR-0018 |
| TR-destiny-branch-004 | 12-entry F-DB-3 invariant_violation:* StringName vocabulary + invalid() factory | ADR-0018 |
| TR-destiny-branch-005 | @abstract _apply_f_sp_1 test seam (G-22 structural source-file assertion verification) | ADR-0018 |
| TR-destiny-branch-006 | DefaultDestinyBranchJudge production subclass + ScenarioFormulas.resolve_branch delegation | ADR-0018 |
| TR-destiny-branch-007 | invalid() factory + invariant-violation contract (CR-DB-10) | ADR-0018 |
| TR-destiny-branch-008 | F-DB-2 reserved_color_treatment derivation (CR-DB-9 + canonical_branch_key field-name reconciliation) | ADR-0018 |
| TR-destiny-branch-009 | Pillar 4 is_canonical_history payload-level enforcement | ADR-0018 |
| TR-destiny-branch-010 | Determinism invariant (lint-enforced via 3 forbidden_patterns) | ADR-0018 |
| TR-destiny-branch-011 | EC-DB-17 thread safety BY CONSTRUCTION (lint scan-set covers production + test stub + future subclass) | ADR-0018 |
| TR-destiny-branch-012 | ADR-0001 minor amendment 5-field → 9-field via Evolution Rule #4 | ADR-0018 |
| TR-destiny-branch-013 | BattleOutcome top-level class_name cross-doc constraint (SATISFIED in shipped src/core/payloads/battle_outcome.gd:10) | ADR-0018 |
| TR-destiny-branch-014 | Emission ownership in ScenarioRunner (CR-DB-4 lint-enforced) | ADR-0018 |
| TR-destiny-branch-015 | ResourceSaver/ResourceLoader round-trip on 5 export targets (closes destiny-branch GDD OQ-DB-6) | ADR-0018 |

Total TR count: 224 → **239**. tr-registry.yaml v13 → v14.

---

## Phase 4: Cross-ADR Conflict Detection

### 🔴 CONFLICT #1 (BLOCKING; Type: Integration contract / Class form)

**ADR-0017 vs ADR-0018** — `DestinyBranchJudge.resolve(...)` call-site form mismatch.

- **ADR-0017 line 209 (pre-flip)**: `var choice: DestinyBranchChoice = DestinyBranchJudge.resolve(...)` — STATIC-METHOD call form on class identifier
- **ADR-0018 §Decision §Class Form (lines 96-108 + 351-369)**: `DestinyBranchJudge` is `RefCounted` with INSTANCE method `resolve()`; production usage `var judge: DestinyBranchJudge = DefaultDestinyBranchJudge.new()` then `judge.resolve(...)`
- **ADR-0018 Alternative §2 (line 530)**: Static utility module form is REJECTED per EC-DB-17 thread-safety guarantee — `static var` would be required for test injection state, breaking determinism-by-construction

**Impact**: Either ADR-0017 or ADR-0018 must be amended; cannot accept ADR-0018 with internal claim contradicting ADR-0017's call-site code (ADR-0017 was Accepted via delta #12 with the static-call form, which pre-dated ADR-0018's executor ratification).

**Resolution applied (same-patch)**: Path forward — amend ADR-0017 §F-SP-1/F-SP-2 Execution code block to instance form. Mirrors delta #12's Path A pattern (upstream-ADR same-patch flip at downstream-ADR acceptance time):
1. ADR-0017 line 204-218: replace static-call form with `var judge: DestinyBranchJudge = DefaultDestinyBranchJudge.new()` + `var choice: DestinyBranchChoice = judge.resolve(...)` + RefCounted scope-drop comment
2. Inline source-comment annotation: cite ADR-0018 §Class Form binding + Alternative §2 rejection rationale + delta #13 acceptance reference

**4th project precedent of "ratification widening at upstream-ADR acceptance"** after save_checkpoint_requested 2026-04-18 (String → SaveContext) + scenario_complete delta #12 (String → ScenarioResult) + scenario_beat_retried delta #12 (provisional 4-field → shipped 3-field). Pattern stable at 4 invocations.

### 🟡 ADVISORY #1 (godot-specialist 16th invocation C-2 residual)

**ADR-0018 line 56 vs line 17** — internal contradiction within same ADR.

- **Line 17 (§Engine Compatibility)**: "the parameterless form `duplicate_deep()` is the verified-name signature in `breaking-changes.md`; subscribers may use it via ADR-0001 §6 deep-duplication latitude … the `DEEP_DUPLICATE_ALL` deep-mode flag constant referenced in earlier ADR drafts is **NOT verified in the pinned engine-reference docs** — consumers SHOULD prefer the parameterless `duplicate_deep()` form"
- **Line 56 (§Constraints, pre-flip)**: "consumers may duplicate for archiving via `duplicate_deep(Resource.DEEP_DUPLICATE_ALL)`"

Per godot-specialist 16th invocation: "These two lines now contradict each other within the same ADR." C-2 advisory was applied at the §Engine Compatibility header level at /architecture-decision time, but line 56 in §Constraints retained the pre-fix wording.

**Resolution applied (same-patch)**: Line 56 flipped to: "consumers may duplicate for archiving via the parameterless `duplicate_deep()` form per `breaking-changes.md` 4.4→4.5 row — the `Resource.DEEP_DUPLICATE_ALL` deep-mode flag constant is NOT verified in pinned engine-reference docs, so consumers SHOULD prefer the parameterless form per §Engine Compatibility row reconciliation."

### 🟢 No other cross-ADR conflicts

- ADR-0018 BattleOutcome top-level class_name constraint — **already SATISFIED in shipped code** (`src/core/payloads/battle_outcome.gd:10` declares `class_name BattleOutcome extends Resource` at top level; verified via grep). The cross-doc constraint flagged for grid-battle v5.0 GDD revision is for GDD-level documentation, not for codebase. V-11 can be marked SATISFIED at this delta.
- ADR-0018 5-field PROVISIONAL → 9-field RATIFIED amendment — this is the planned same-patch ADR-0001 minor amendment per Evolution Rule #4 (NOT a conflict; it IS the deliverable). Lands as part of this delta.
- ADR-0018 vs `scenario_runner_outcome_synthesis` forbidden_pattern — ADR-0018 mirrors discipline at judge level (judge MUST NOT mutate outcome). Reaffirmed; no conflict.
- ADR-0018 vs `battle_hud_subscribes_to_hidden_fate_signal` forbidden_pattern — ADR-0018 confirms judge is sole consumer per ADR-0014 line 335 + destiny-branch GDD §B. Cross-ref preserved; no conflict.
- ADR-0018 vs `scenario_runner_deferred_seal_in_beat_7_entry` forbidden_pattern (Pillar 2 architectural lock) — ADR-0018 defers to upstream sealing discipline; receives `first_attempt_resolved` as the already-sealed 4th argument. Reinforced via new `destiny_branch_judge_reads_scenario_runner_state` forbidden_pattern. No conflict.

### ADR Dependency Order (post-delta #13)

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
  14. ADR-0018 DestinyBranch (depends on ADR-0017/0001/0014/0003; NEW via delta #13)

Feature (depends on Core):
  15. ADR-0013 BattleCamera
  16. ADR-0014 GridBattleController
  17. ADR-0016 BattleSceneWiring

Presentation (depends on Feature):
  18. ADR-0015 BattleHUD
```

No cycles. No unresolved dependencies. All 18 ADRs Accepted. Topological sort consistent.

---

## Phase 5: Engine Compatibility Cross-Check

### Audit
- All ADRs reference Godot 4.6 ✓
- ADR-0018 §Engine Compatibility table marks Knowledge Risk HIGH (Godot 4.6 is post-LLM-cutoff; 4 post-cutoff API surface items verified: `@abstract` annotation per breaking-changes.md 4.4→4.5 + `Resource.duplicate_deep()` per breaking-changes.md 4.4→4.5 + typed-Resource `@export` of typed enum values + StringName field-type preservation through ResourceSaver/ResourceLoader on 5 export targets — last item flagged as BLOCKING for VS close per OQ-DB-6 + IN-1)
- 0 deprecated API references in ADR-0018 (the 4 prior fixes from /architecture-decision phase landed correctly per godot-specialist 16th-invocation verification: G-22 V-5 + DEEP_DUPLICATE_ALL note + V-8 lint scope expansion + 4-arg signature)

### Engine Specialist Findings (godot-specialist 16th invocation, /architecture-review delta #13 mode)

**Verdict: PASS WITH 1 ADVISORY CORRECTION**

| Item | Status | Detail |
|------|--------|--------|
| C-1: V-5 @abstract structural assertion | PASS | Lines 722-731 use FileAccess.get_file_as_string() + assert_bool contains pattern; runtime load() failure expectation absent; G-22 language explicit |
| C-2: DEEP_DUPLICATE_ALL note | **ADVISORY** | Line 17 advisory landed correctly; line 56 retained pre-fix wording → contradiction within same ADR. **Resolved same-patch**: line 56 flipped to parameterless form |
| C-3: V-8 lint scope expansion | PASS | Line 740 scan-set includes production source + test stub + future `extends DestinyBranchJudge` discovery; correctly scoped per godot-specialist Phase 4.5 advisory |
| N-1: breaking-changes.md cross-validation | PASS | @abstract at 4.4→4.5 row line 30 + duplicate_deep() at 4.4→4.5 row line 40 — both correctly cited at line 17 + line 52 |
| N-2: deprecated-apis.md cross-validation | PASS | OS.get_ticks_msec() + Resource.duplicate(true) deprecation correctly cited at lines 55-56 |
| N-3: G-3 autoload / class_name collision | PASS | Lines 111-119 explicitly document DestinyBranchJudge is NOT an autoload; G-3 does not apply |
| N-4: BattleOutcome.Result top-level class_name | PASS | Lines 42 + 53 state requirement; line 244 @export shape correct; cross-doc constraint tracked V-11 + Migration Plan §4 + §6; **codebase already SATISFIED** at src/core/payloads/battle_outcome.gd:10 |
| N-5: 4-arg resolve() signature consistency | PASS | Lines 132-137 + 354-360 + ADR-0017 line 200 all consistent on 4-arg form (chapter, outcome, echo_count, first_attempt_resolved) |
| N-6: 9-field Resource round-trip test protocol | PASS | Lines 768-805 well-formed GdUnit4 test including `typeof(loaded.invalid_reason) == TYPE_STRING_NAME` OQ-DB-6 critical assertion |
| N-7: 3 forbidden_patterns enforceability | PASS | All 3 grep regexes correct; scan-sets at lines 375-377 cover both production source files |
| N-8: domain-expert scan for missed anti-patterns | OBSERVATION | One pattern observation: `@export var outcome: BattleOutcome.Result` typed-enum @export serializes as int — enum reordering breaks save compat silently. ADR correctly documents at line 76 + designates enum order as locked at grid-battle v5.0. Specialist recommends adding literal comment in enum declaration source: `# DO NOT reorder — save-compatibility lock per ADR-0018`. Carried as advisory pattern observation for sprint-7+ grid-battle v5.0 implementation. |

All corrections resolved same-patch (1 ADVISORY at line 56 flipped). 0 corrections deferred.

---

## Phase 5b: GDD Revision Flags

**None blocking** — all GDD assumptions are consistent with verified engine behaviour. Specifically:
- destiny-branch.md §F-DB-1 IS the planned same-patch sync target (rev 1.3.1 → 1.3.2 with 7 wording flips covering 3-arg → 4-arg signature + canonical_branch_key field-name + ChapterDefinition typed-Resource + worked-examples 4th column + test-seam contract) — landed this delta per Migration Plan §1
- destiny-branch.md §F-DB-4 9-field shape ratified at ADR-0018 §Payload Form
- BattleOutcome top-level class_name constraint already satisfied in shipped code

**Minor advisory observation** (NOT blocking; not flagged as revision):
- destiny-branch.md sections OUTSIDE §F-DB-1 (CR-DB-9 in §Detailed Rules; F-DB-4 invariants in §Formulas; EC-DB-2 prose in §Edge Cases; AC-DB tests in §Acceptance Criteria) retain `default_branch_key` and `ChapterResource` references. ADR-0018 Migration Plan §1 explicitly scoped to §F-DB-1 (per ADR-0018 §Negative line 565: "1 GDD field-name flip" — singular). Cross-section field-name updates are deferred to future GDD hygiene pass — NOT BLOCKING for ADR-0018 acceptance per project precedent (ADR-0014 + ADR-0015 + ADR-0017 each landed with downstream GDD sync flagged but deferred). Suitable for incorporation into future tech-debt entry OR sprint-7+ pre-implementation hygiene pass.

---

## Phase 6: Architecture Registry Updates (delta #13)

`docs/registry/architecture.yaml` v11 → **v12**

### state_ownership (1 added)
- `destiny_branch_judge_runtime_payload` — DestinyBranchJudge RefCounted pure-function class + DestinyBranchChoice 9-field typed Resource payload; owns 13-state machine call-site + @abstract test seam + DefaultDestinyBranchJudge production subclass + 12-entry F-DB-3 invariant_violation:* StringName vocabulary

### interfaces (1 added)
- `destiny_branch_judge_signal_contract` — pattern: **direct_call** (NOT signal — first project precedent of direct_call interface contract; the judge IS called by ScenarioRunner not via GameBus); producer: destiny-branch; consumers: scenario-progression (sole caller); signal_signatures: 4 entries covering resolve() + _apply_f_sp_1() + invalid() factory + downstream destiny_branch_chosen GameBus emission; explicit test_seam + determinism contract codification

### api_decisions (1 added)
- `destiny_branch_judge_module_form` — RefCounted pure-function transient class with @abstract test seam (Godot 4.5+) + DefaultDestinyBranchJudge concrete subclass delegating to ScenarioFormulas.resolve_branch (ADR-0017 owned F-SP-1 authoritative impl) + DestinyBranchChoice typed Resource payload; 4 alternatives documented (inline F-SP-1 + static utility + autoload + untyped Dictionary all rejected)

### forbidden_patterns (3 added)
1. `destiny_branch_judge_emits_gamebus_signal` — judge MUST NOT emit GameBus signals (CR-DB-4 emission ownership in ScenarioRunner)
2. `destiny_branch_judge_static_var` — `static var` FORBIDDEN in entire DestinyBranchJudge class hierarchy (production + test stub + future subclass discovery per godot-specialist 15th-invocation advisory C-3 scan-set expansion)
3. `destiny_branch_judge_reads_scenario_runner_state` — judge MUST receive `first_attempt_resolved` as 4th argument (ALREADY-SEALED value) NOT read from autoload state (CR-DB-2 purity + scenario-progression CR-7 sealed-value pass-through invariant)

### Same-patch wording flips applied (13 total)
1. ADR-0001 line 315: 5-field PROVISIONAL → 9-field RATIFIED + ratification footnote
2. ADR-0001 line 319: Pillar 2 mechanical-expression note rewrite (reserved_color_treatment + is_canonical_history + invalid-path emission contract + 12-entry F-DB-3 vocabulary cross-ref)
3. ADR-0001 line 319: cross-doc BattleOutcome top-level class_name constraint paragraph (SATISFIED in shipped src/core/payloads/battle_outcome.gd:10)
4. ADR-0001 line 364: remove "shape TBD" entry; PROVISIONAL signal count 3 → 2
5. ADR-0001: new "PROVISIONAL → RATIFIED 2026-05-04 via /architecture-review delta #13" subsection mirroring delta #12 format
6. ADR-0001 changelog: new 2026-05-04 row for delta #13 amendment
7-13. destiny-branch GDD §F-DB-1 7 wording flips (per Migration Plan §1):
   - 7. Algorithm signature 3-arg → 4-arg
   - 8. Variables table 4th row added (first_attempt_resolved)
   - 9. Variables table chapter row: ChapterResource → ChapterDefinition
   - 10. Algorithm step 3 _apply_f_sp_1 4-arg call
   - 11. Algorithm step 4 + F-DB-2 derivation: default_branch_key → canonical_branch_key
   - 12. Worked examples E1-E6 4th column (first_attempt_resolved) + 4th-column-semantics paragraph
   - 13. Test-seam contract @abstract update + TestDestinyBranchJudgeWithSp1Stub 4-arg form + rev tag bump 1.3.1 → 1.3.2

Plus 2 same-patch corrections from Phase 4 + Phase 5:
- ADR-0017 line 209: static-method call → instance-form widening (Phase 4 BLOCKING resolution)
- ADR-0018 line 56: DEEP_DUPLICATE_ALL constant → parameterless duplicate_deep() form (Phase 5 ADVISORY C-2 residual)

Within delta-pattern range (delta #9 24-correction close-out anomaly was higher; delta #12 had 8 same-patch flips; this delta has 15 total when counting Phase 4 + Phase 5 corrections).

---

## Phase 7: Output Summary

### Traceability Summary
- Total requirements: 239 (was 224)
- ✅ Covered: 239 (100%)
- ⚠️ Partial: 0
- ❌ Gaps: 0

### Coverage Gaps
None. All 18 Accepted ADRs have full TR coverage in tr-registry.yaml v14.

### Cross-ADR Conflicts
1 BLOCKING resolved same-patch (CONFLICT #1 — ADR-0017 line 209 static-method-call vs ADR-0018 RefCounted instance-method ratification; resolved via same-patch ADR-0017 instance-form widening).

### ADR Dependency Order
Topologically sorted (see Phase 4 above). No cycles. No unresolved dependencies. All 18 ADRs Accepted.

### GDD Revision Flags
None blocking. destiny-branch §F-DB-1 sync IS the planned same-patch deliverable (rev 1.3.1 → 1.3.2 landed). Minor advisory observation: sections OUTSIDE §F-DB-1 retain `default_branch_key`/`ChapterResource` refs (deferred to future GDD hygiene pass).

### Engine Compatibility Issues
None blocking. 1 ADVISORY (C-2 residual at line 56) resolved same-patch.

### Architecture Document Coverage
`docs/architecture/architecture.md` v0.8 (refreshed delta #11) — Layer Map should be refreshed to reflect Core 5/5 (was 4/4) at next opportunity. **NOT BLOCKING for delta #13 acceptance**; structural backfill only.

---

## Verdict: PASS WITH 1 BLOCKING + 1 ADVISORY CORRECTIONS

Both corrections resolved same-patch within this delta's commit. ADR-0018 Status flipped Proposed → **Accepted (2026-05-04)**.

### Blocking Issues (FAIL only — none)
None. ADR-0017 line 209 instance-form widening resolved the BLOCKING cross-ADR integration conflict.

### Required ADRs (next priority — all OPTIONAL post-delta #13)
1. **AI System ADR** (sprint-7+) — required for Battle Prep epic; AI invocation point already documented in ADR-0014 + ADR-0011
2. **Battle Preparation ADR** (sprint-7+) — subscribes to `battle_prepare_requested` emission point ratified by ADR-0017
3. **Story Event #10 / Destiny State #16 / Save/Load #17 VS GDDs** (sprint-7+ design authoring; UNBLOCKED by this delta — each had BLOCKING gate on DestinyBranchChoice 9-field shape ratification + invalid-path emission contract per destiny-branch §Bidirectional rev 1.2 D1)

---

## Phase 8: Files Updated This Delta

1. `docs/architecture/ADR-0018-destiny-branch.md` — Status Proposed → Accepted; line 56 C-2 residual fix (DEEP_DUPLICATE_ALL → parameterless duplicate_deep())
2. `docs/architecture/ADR-0017-scenario-progression.md` — line 209 static-method-call → instance-form widening (BLOCKING resolution)
3. `docs/architecture/ADR-0001-gamebus-autoload.md` — 6 amendments (signal table row line 315 + Pillar 2/4 mechanical-expression note line 319 + cross-doc BattleOutcome paragraph line 319 + PROVISIONAL count line 363 + new "PROVISIONAL → RATIFIED 2026-05-04 via delta #13" subsection + changelog row)
4. `design/gdd/destiny-branch.md` — 7 wording flips per Migration Plan §1 (3-arg → 4-arg signature + Variables table 4th row + worked examples E1-E6 4th column + 4th-column-semantics paragraph + test-seam contract @abstract update + canonical_branch_key field-name + rev tag bump 1.3.1 → 1.3.2)
5. `docs/registry/architecture.yaml` — v11 → v12 (1 state_ownership + 1 interface + 1 api_decision + 3 forbidden_patterns + delta #13 comment block)
6. `docs/architecture/tr-registry.yaml` — v13 → v14 (15 net-new TR-destiny-branch-001..015 entries + delta #13 comment block)
7. `docs/architecture/architecture-traceability.md` — v0.12 → v0.13 (Document Status block + Coverage summary Core 4/4 → 5/5 + 15 new TR rows + destiny-branch GDD section + delta #13 changelog row)
8. `docs/architecture/architecture-review-2026-05-04b.md` — this report (NEW)
9. `production/session-state/active.md` — session extract for delta #13 (appended)

---

## Phase 9: Handoff

### Immediate actions
1. **Sprint-7+ DestinyBranchJudge implementation** — ADR-0018 Migration Plan §5 ships in single coordinated patch (3 new source files + 1 test helper + 2 unit test files + 3 future CI lints + 1 integration test); coordinate with ScenarioRunner per ADR-0017 §Migration Plan §1..§11 single coordinated patch
2. **Story Event #10 / Destiny State #16 / Save/Load #17 VS GDD authoring** — UNBLOCKED by this delta; each consumes DestinyBranchChoice 9-field payload contract; sprint-7+ design authoring scope
3. **Architecture.md Layer Map refresh** — update Core 4/4 → 5/5 at next architecture.md amendment opportunity (NOT BLOCKING)
4. **destiny-branch GDD hygiene pass** — sections OUTSIDE §F-DB-1 retain `default_branch_key`/`ChapterResource` refs; deferred to sprint-7+ pre-implementation hygiene per ADR-0014/0015/0017 precedent; suitable for incorporation into /create-stories `destiny-branch` epic prerequisite scope

### Gate guidance
**Pre-Production → Production gate is now strongly eligible** (mandatory ADR list = 0; ADR-0018 closes Pillar 2 + Pillar 4 architectural narrative-pillar substrate). Run `/gate-check pre-production` to formally evaluate gate readiness across all departments.

### Rerun trigger
Re-run `/architecture-review` after AI System ADR or Battle Preparation ADR is authored (in fresh session per same-session-ban discipline). Both are sprint-7+ scope; not blocking for current sprint.

---

## Pattern Observations

- **13-invocation pattern**: /architecture-review pattern stable; this delta = 1 BLOCKING + 1 ADVISORY corrections (well below delta #6 6-correction HIGH-risk anomaly + delta #9 24-correction close-out anomaly; matches typical delta correction count)
- **Same-session godot-specialist 16th invocation**: PASS WITH 1 ADVISORY CORRECTION resolved same-patch; same-session pattern stable at 16 invocations
- **Combined-session pattern (escalation + structural append)**: 3rd invocation (after delta #11 ADR-0016 + delta #12 ADR-0017); pattern now stable at 3 invocations — codification candidate carried forward (delta #11): future deltas should default to combining escalation + structural append in single fresh session unless TR backfill volume exceeds typical single-session capacity
- **PROVISIONAL signal ratification pattern**: 8th invocation (destiny_branch_chosen follows scenario_complete + scenario_beat_retried + 5 prior PROVISIONAL signals' ratification path)
- **Cross-ADR integration conflict at downstream-ADR acceptance time**: 4th project precedent of "ratification widening at upstream-ADR acceptance" (after save_checkpoint_requested 2026-04-18 + scenario_complete delta #12 + scenario_beat_retried delta #12 + this delta's ADR-0017 line 209 instance-form widening). Pattern stable at 4 invocations; the upstream ADR's call-site code typically lags behind the downstream ADR's executor ratification
- **RefCounted pure-function class with @abstract test seam pattern**: **1st invocation in the project** (no precedent — establishes pattern boundary for future formula-evaluator ADRs in destiny-branch / scenario-progression / save-load chain)
- **Pillar-anchored lint pattern**: 3rd invocation (`destiny_branch_judge_reads_scenario_runner_state` follows `scenario_runner_deferred_seal_in_beat_7_entry` ADR-0017 + `battle_hud_subscribes_to_hidden_fate_signal` ADR-0015 — all 3 are Pillar 2 architectural locks)
- **Direct_call interface contract**: 1st invocation (destiny_branch_judge_signal_contract is a direct_call pattern, distinguishing from prior interface contracts which were all signal-pattern); establishes pattern boundary for future executor-class interface contracts
- **Codification candidate (carried forward from delta #12)**: when an ADR ratifies a PROVISIONAL signal at /architecture-review delta time, the ratification commonly involves payload widening (typed Resource replacing primitive). This delta extends the pattern: when an ADR ratifies a PROVISIONAL signal AND introduces a new executor class, the upstream-ADR call-site code typically requires same-patch flip from static-method-call to instance-method-call form. Future ADRs introducing executor classes should pre-validate upstream-ADR call-site forms in the /architecture-decision phase + flag any static-method-call forms as Phase 4 same-patch correction targets at the /architecture-review delta time.
