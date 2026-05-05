# Retrospective: Sprint 7

| Field | Value |
|---|---|
| **Period** | 2026-05-04 → 2026-05-05 (actual; planned 2026-05-31 → 2026-06-06) |
| **Sprint Goal** | Ship chapter-1 (장판파) end-to-end as the first user-experienceable narrative arc |
| **Mode** | Lean (per `production/review-mode.txt`) |
| **Generated** | 2026-05-05 |

---

## Metrics

| Metric | Planned | Actual | Delta |
|---|---|---|---|
| Stories | 11 (Must 4 + Should 3 + Nice 4) | 9 closed + 1 BLOCKED + 1 USER-OWNED | -2 from full-close |
| Completion Rate | 100% target | **82% closed** (9/11); 100% Must+Should | -18% on Nice |
| Story-days nominal | ~4.5 working days claude-owned | ~1-1.5 calendar days | **3-5× under nominal** |
| Test baseline (start) | 907 (sprint-6 close) | 907 | — |
| Test baseline (end) | ≥960 | **978** | +18 over target |
| Net new tests | ~50 | **+71** | +21 over target |
| Failure-free streak | sustain | **26th+ consecutive baseline** | held |
| Commits | — | **24** | — |
| ADRs Accepted | 18 → 19 | 18 → **19** (ADR-0019 AI System) | met |
| Bugs found | — | 1 pre-existing (G-7 silent-skip from S7-02) | — |
| Bugs fixed | — | 1 (G-7 silent-skip 1-char fix in S7-07 ba8da69) | — |
| Unplanned work | — | 0 | — |

---

## Velocity Trend

| Sprint | Planned (days) | Actual (days) | Multiplier |
|---|---|---|---|
| Sprint-5 | ~5d | ~1d | ~5× |
| Sprint-6 | 4.4d | ~1d | ~5× |
| **Sprint-7 (current)** | **4.5d** | **~1-1.5d** | **~3-5×** |

**Trend**: STABLE at 5× nominal multiplier. Sprint-7 sustained the velocity ratio even as scope shifted from architecture/ADR work (sprint-6) to broad implementation across 4 epics (S7-02 ScenarioRunner + S7-03 DestinyBranchJudge + S7-04 AISystem + S7-09 battle-hud). **R8 mitigation succeeded** — implementation-heavy sprint did not degrade the velocity multiplier.

---

## What Went Well

1. **Must + Should 7/7 closed (100% on critical path)**. S7-01..S7-07 all shipped: ADR-0019 Accepted via /architecture-review delta #14, ScenarioRunner autoload, DestinyBranchJudge with 12-vocab, AISystem 4 archetypes + Pillar 2 lock 4th precedent, chapter-1 (장판파) data, Story Event #10 GDD, Destiny State #16 GDD.
2. **26th+ consecutive failure-free baseline maintained** through 71 new tests across 4 implementation tracks. 978/978 PASSING / 0 errors / 0 failures / 0 orphans / 108 suites.
3. **Pillar 2 architectural lock pattern firmly stable at 4 invocations + 2 candidates**. Pattern triad (source-grep lint + ADR inline annotation + integration test source-scan) ratified across battle_hud_subscribes_to_hidden_fate_signal + scenario_runner_deferred_seal_in_beat_7_entry + destiny_branch_judge_reads_scenario_runner_state + ai_system_reads_destiny_branch_state. Pillar 2 (운명은 바꿀 수 있다) is the strongest pillar entering Production.
4. **Combined-session escalation pattern stable at 4 invocations** (deltas #11/#12/#13/#14). ADR Proposed → Accepted in single fresh session is now the default for /architecture-review deltas.
5. **Direct-author velocity for GDDs**: S7-05 chapter-1 data + S7-06 Story Event GDD + S7-07 Destiny State GDD all shipped via direct-author pattern (no /design-system orchestration). 5-6× faster than orchestration. Same precedent as ADR-0017/0018/0019 sessions.
6. **G-7 silent-skip surface-and-fix pattern (codification candidate)**: pre-existing trap from S7-02 commit ba02e02 surfaced at S7-05 baseline check (959/959 NOT reflecting 4 silently-skipped traversal tests); explicitly documented in S7-05 commit body as "deferred follow-up"; resolved in next commit (S7-07 ba8da69) with 1-char fix `assert_str(...).contains([...])` → `.contains(...)`. 4 traversal tests recovered. Pattern: same-session-fix preferred to deferred follow-up.
7. **6-variant scoping correction in S7-06**: sprint-7 plan called for "5 branch-state variants" in Story Event #10; mechanical analysis surfaced 6 distinct variants (draw_fallback as 6th distinct from draw_partial). GDD authoring may mechanically refine sprint-plan scope estimates.
8. **R-6 over-budgeted (positive surprise)**: 0 user-adjudication points surfaced during S7-06+S7-07 GDD authoring vs estimate of 2-4 per GDD. Pattern: GDDs define LOOKUP layers + signal contracts + invariant enforcement, not actual narrative copy; "narrative-heavy" descriptor was misleading.
9. **All 6 gate-check 2026-05-04 path-to-PASS items closed on claude-owned side**. Gate-check verdict trajectory CONCERNS-4× → CONCERNS-1× (3× READY + 1× CONCERNS at CD only).
10. **Pre-Production phase gate sole remaining blocker is USER-OWNED (S7-11 attestation)** — claude path-to-PASS work fully discharged.

---

## What Went Poorly

1. **S7-10 BLOCKED — pre-flight check missed**. Sprint-7 plan listed S7-10 (battle-hud story-005 with two-tap timer) as nice-to-have, but did NOT verify that InputRouter actually has a `_handle_event` method to route from. Discovery at story-attempt time: InputRouter is a 33-line PLACEHOLDER from the input-handling epic (which has 10 stories of unimplemented scope). Lost ~0.5h on story-attempt before recognizing the architecture gap. **Systemic cause**: carryover stories assumed underlying infra; no plan-time verification.
2. **Retro AI #1 ("close sprint-status row in same patch") violated S7-01..S7-04**. Manual reconcile required at S7-05 (commit e55dafc) to retroactively close 4 backlog rows. Pattern enforcement only began S7-05+. 4-story streak; not yet stable at 6+ commits to call this a hardened practice.
3. **S7-11 user attestation gate is the SOLE remaining /gate-check upgrade blocker** — completely outside claude control. Not a sprint-7 failure (it was budgeted as user-owned), but the verdict trajectory hits CONCERNS-pending-user-attestation regardless of how thoroughly claude-owned work was discharged. This is a refusal-to-fabricate posture commitment cost.

---

## Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---|---|---|---|
| **S7-10 InputRouter PLACEHOLDER** discovered at story-attempt time | ~0.5h investigation; story-day deferred | Marked S7-10 BLOCKED; deferred to sprint-8+ post input-handling epic landing (commit 208606d) | Sprint-plan pre-flight: every carryover story must verify underlying infra has all referenced APIs (not just the file exists) |
| **G-7 silent-skip in chapter_1_traversal_test.gd:99** (pre-existing from S7-02) | Surfaced at S7-05 baseline check; fixed in next commit S7-07 | 1-char fix: `assert_str(...).contains([...])` Array literal → `.contains(...)` String literal — unblocks 4 traversal tests | G-7 detection at every test baseline run (codification candidate); same-session-fix preferred to deferred follow-up |
| Save/Load #17 GDD CUT from sprint-7 (Producer pressure-cut at gate-check 2026-05-04) | n/a (cut at plan time) | Deferred to sprint-8 | Continue Producer pressure-cut discipline at gate-check time |

---

## Estimation Accuracy

| Story | Estimated | Actual | Variance | Likely Cause |
|---|---|---|---|---|
| S7-01 ADR-0019 escalation | 0.4d | ~0.1d | +75% under | 4th-precedent same-day-fresh-session escalation pattern is highly automated |
| S7-02 ScenarioRunner | 0.6d | ~0.2-0.3d | +50% under | ADR-0017 Migration Plan §1..§11 pre-sequenced; mock encoder deletion well-scoped |
| S7-03 DestinyBranchJudge | 0.5d | ~0.2d | +60% under | ADR-0018 Migration Plan §5 well-scoped; @abstract test seam codification clean |
| S7-04 AISystem | 0.5d | ~0.2-0.3d | +50% under | ADR-0019 Migration Plan §2..§5 pre-sequenced; 4-archetype dispatch matches single-class match pattern |
| S7-05 chapter-1 data | 0.3d | ~0.1d | +66% under | Data authoring + sprint-status reconcile combined |
| S7-06 Story Event GDD | 0.4d | ~0.1d | +75% under | Direct-author 5-6× velocity multiplier; 0 user-adjudication points (vs estimate 2-4) |
| S7-07 Destiny State GDD | 0.4d | ~0.1d | +75% under | Direct-author + 0 user-adjudication |
| S7-08 control-manifest backfill | 0.5d | ~0.1d | +80% under | Mechanical-doc-authoring; ADR consolidation matched expected pattern |
| S7-09 battle-hud story-004 | 0.4d | ~0.2d | +50% under | Carryover from sprint-6; battle-hud spec already authored |
| S7-10 (BLOCKED) | 0.5d | n/a | — | Architecture gap (InputRouter PLACEHOLDER) |

**Overall estimation accuracy**: 9/9 shipped stories within +50% to +80% UNDER estimate. **Consistent 3-5× under-nominal** across all task types — architecture/ADR + implementation + GDD authoring + manifest-backfill all converge to similar multiplier.

**Adjustment recommendation**: Sprint-8 plan should target **~1.5-2.0d nominal Must-Have** (down from sprint-7's 2.0d) per 4th-consecutive-AI-#1-ratchet discipline. If the multiplier holds, sprint-8 actual completes in ~0.4-0.5 calendar day.

---

## Carryover Analysis

| Task | Original Sprint | Times Carried | Reason | Action |
|---|---|---|---|---|
| S7-10 battle-hud story-005 (UI-GB-02/05/10 + two-tap timer) | Sprint-6 (S6-12-adjacent) → Sprint-7 → Sprint-8+ | 2× | Sprint-6: scope cut for ADR-0017/0018 architecture; Sprint-7: BLOCKED on input-handling epic | Defer to sprint-8 post input-handling stories 1-5 land |
| S7-11 user attestation (4 VS items) | Sprint-7 | 1× | User-owned by design; refusal-to-fabricate posture | User-track; non-sprint-bound |
| Save/Load #17 GDD authoring | Sprint-7 (cut at plan time) → Sprint-8 | 1× | Producer pressure-cut at gate-check 2026-05-04 | Sprint-8 should-have (design-only filler) |
| Hero portraits (8) | Sprint-4 → Sprint-7 → Sprint-8+ | 3× | User-owner | User-track; non-blocking |
| BGM candidates (2-3) | Sprint-4 → Sprint-7 → Sprint-8+ | 3× | User-owner | User-track; non-blocking |

---

## Technical Debt Status

| Metric | Sprint-5 close | Sprint-7 close | Trend |
|---|---|---|---|
| TODO count in src/ | 6 | **5** | ↓ shrinking |
| FIXME count in src/ | 0 | 0 | flat |
| HACK count in src/ | — | 0 | flat |

**Trend**: SHRINKING (-1 TODO net across 2 sprints).

---

## Previous Action Items Follow-Up (Sprint-7 Retro AI seed from gate-check 2026-05-04)

| Action | Status | Notes |
|---|---|---|
| **AI #1**: All shipped work must close its sprint-status row in the same patch | **PARTIAL** | Violated S7-01..S7-04 (4 backlog rows requiring retroactive close at S7-05 e55dafc); enforced S7-05..S7-10 (5-story streak). Not yet stable at 6+ commits — carry to sprint-8 retro AI |
| **AI #2**: 5× velocity multiplier durability under broader impl scope | **HELD** | Sustained 3-5× even with 4-track implementation (ScenarioRunner + DestinyBranchJudge + AISystem + battle-hud). R8 mitigation worked |
| **AI #3**: Pillar 2 lock pattern triad (source-grep + ADR-annotation + integration-test) | **STABLE** | 4th invocation in S7-04 (`ai_system_reads_destiny_branch_state`); pattern firmly locked |
| **AI #4**: Combined-session escalation pattern | **STABLE** | 4th invocation in S7-01 (delta #14); now the default |
| **AI #5**: CI lane gap for macOS / iOS / Android | **DEFERRED** | Per R-3 mitigation; sprint-8 evaluation pending. No new evidence to act on |

---

## Action Items for Sprint-8

| # | Action | Owner | Priority | Rationale / Source |
|---|---|---|---|---|
| 1 | Author InputRouter ADR (gate before implementation per TD recommendation) | claude | High | TD-PHASE-GATE feedback; unblocks S7-10 + UI-GB-09 + future player-agency stories |
| 2 | Implement input-handling epic stories 1-5 (split per Producer recommendation) | claude | High | Producer-PHASE-GATE: do NOT absorb full 10-story epic — split across sprint-8/9 |
| 3 | Ship S7-10 battle-hud story-005 (two-tap ATTACK/DEFEND timer) post input-handling 1-5 | claude | High | Carryover unblock |
| 4 | Sprint-status hygiene retro AI #1: enforce close-in-same-patch for ≥6 stories to declare pattern stable | claude | High | Sprint-7 streak at 5; need 6+ for stability |
| 5 | Pre-flight check policy: every carryover story must verify underlying infra has all referenced APIs at sprint-plan time, not story-attempt time | claude | High | S7-10 InputRouter PLACEHOLDER lesson — codify as new sprint-plan discipline |
| 6 | Author Save/Load #17 GDD (carryover; design-only filler) | claude | Med | Producer cut → sprint-8 should-have |
| 7 | Implement Story Event #10 (newly Designed S7-06) + ADR-0001 minor amendment (3 new GameBus signals) | claude | Med | Sprint-7 GDD landed; sprint-8 implementation per Pillar 4 substrate |
| 8 | Implement Destiny State #16 (newly Designed S7-07) + ADR-0001 minor amendment | claude | Med | Sprint-7 GDD landed; sprint-8 implementation per Pillar 2 substrate; converts 5th candidate Pillar 2 lock to shipped |
| 9 | Chapter-1 (장판파) end-to-end integration vertical-slice run | claude | Med | S7-05 data shipped; integration target for vertical-slice validation |
| 10 | First 2-3 character profile stubs (AD-C5 carryover) | art | Med | AD-PHASE-GATE recommendation; gates portrait spec |
| 11 | AD-C3 font glyph check (緣 bond glyph) before story-event text rendering tasks | art | Med | AD-PHASE-GATE; gates story-event implementation |
| 12 | S7-11 user attestation pass on 4 VS Validation items | user | High | SOLE remaining /gate-check upgrade blocker; refusal-to-fabricate posture |
| 13 | G-7 silent-skip detection at every test baseline run (codification candidate) | claude | Low | New tooling-gotcha pattern from S7-05→S7-07 surface-and-fix lesson |
| 14 | Pillar 4 chapter-2 scoping with chapter-1-callback ACs (CD recommendation) | design | Low (sprint-9+) | Pillar 4 demonstration unprovable until chapter-2 exists |

---

## Process Improvements

1. **Sprint-plan pre-flight discipline (NEW)**: Before adding a carryover story to a sprint, verify underlying infrastructure has all referenced APIs (not just file exists). For S7-10, a 5-min `grep '_handle_event' src/core/input/input_router.gd` would have surfaced the architecture gap at sprint-plan time, not story-attempt time. Codify in sprint-plan skill checklist.
2. **Same-session G-7 fix preferred to deferred follow-up**: When shipping a commit with comprehensive test growth, also verify no silent-skip from prior commits has surfaced; if surfaced, fix in same patch. Pattern from S7-05→S7-07 (deferred follow-up worked but added a commit cycle).
3. **Sprint-status close-in-same-patch enforcement at 6+ stories**: 4-story streak (S7-05..S7-09) is suggestive but not stable. Require 6+ consecutive in-patch closes before declaring pattern hardened. Carry to sprint-8 retro AI.

---

## Summary

Sprint-7 was a **strong sprint** by every claude-owned metric: Must+Should 7/7 closed (100% critical path), 26th+ consecutive failure-free baseline, all 6 gate-check 2026-05-04 path-to-PASS items closed on the claude-owned side. The Pre-Production → Production verdict trajectory upgraded from 4× CONCERNS to 3× READY + 1× CONCERNS in a single sprint cycle, and Pillar 2 architectural substrate is now firmly locked at 4 invocations + 2 candidates.

The two failure modes were **systemic, not individual**: (1) S7-10 BLOCKED revealed a sprint-plan pre-flight gap — carryover stories assumed infrastructure that didn't exist yet; (2) the SOLE remaining gate-check upgrade blocker (S7-11 user attestation) is fundamentally outside claude control by refusal-to-fabricate posture, which is a deliberate commitment cost that maps to "wait for real evidence" rather than "fabricate confidence."

**Single most important thing to change**: Codify sprint-plan pre-flight discipline so carryover stories verify underlying infra at plan time. The S7-10 lesson costs ~0.5h discovery time per occurrence and is preventable with a 5-min grep.

---

## Cross-References

- Sprint-7 plan: `production/sprints/sprint-7.md`
- Sprint-status: `production/sprint-status.yaml` (sprint 7; updated 2026-05-05)
- Gate-check 2026-05-05: `production/gate-checks/pre-prod-to-prod-2026-05-05.md`
- Prior gate-check (CONCERNS baseline): `production/gate-checks/pre-prod-to-prod-2026-05-04.md`
- Architecture-review delta #14: `docs/architecture/architecture-review-2026-05-05.md`
- Pillar 2 architectural locks: `docs/architecture/control-manifest.md` §Pillar 2 Architectural Locks
- Refusal-to-fabricate posture: `.claude/rules/tooling-gotchas.md` TG-2 + damage-calc 2026-04-27 precedent
- Prior retros: `production/retrospectives/retro-sprint-{2,3,4,5}-*.md` (sprint-6 retro implicit per `sprint-7.md` Pivot context)
