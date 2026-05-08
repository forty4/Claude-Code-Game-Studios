# Sprint 13 — 2026-05-10 to 2026-05-12 (3-day window)

> **Generated**: 2026-05-09 (post-sprint-12 close commit `fc9adfb`; immediately following retro `production/retrospectives/retro-sprint-12-2026-05-09.md` MET WITH CONDITIONS verdict)
> **Mode**: lean (`production/review-mode.txt` = `lean`); HYBRID closure-mode pattern adopted at S12-07 — sprint-13 self-applies the pattern (closure/admin-leaning per user decision at plan-authoring)
> **Velocity model** (validated sprint-9/10/11/12): closure ÷3 / greenfield ÷5 / admin ÷3; sprint-13 closure-leaning trends toward ÷~4 actual per sprint-11/12 precedent (~0.5d projected from ~2.4d nominal)

## Sprint Goal

Resolve §11 USER-OWNED 5th-carry HARD GATE binding (S12-10 user-attested per disposition (a)) + S12-11 normal-carry attestation + S12-03 close-gate rerun re-evaluation (potential `production/stage.txt` Pre-Production → Production flip) + execute 2 codification AIs (anchored-regex + byte-cap) + producer call on `production/decisions/` §7 promotion trigger evaluation + first live closure-mode HYBRID signal evaluation at sprint-13 plan time.

**Sprint-13 is structurally-bound by §11.3 Live application table** — first project precedent of "sprint-(N+1) plan authoring obligations" derived from prior-sprint codification.

## Capacity

- Total days: 3
- Buffer (20%): 0.6d reserved
- Available: 2.4d nominal (claude-side) + ~45 min user time (S13-02 ~30 min + S13-10 ~15 min)
- Projected actual via closure-leaning HYBRID multiplier (÷~4 per sprint-11/12 precedent): **~0.5-0.7 calendar day** (claude-side execution; user attestations parallel-track)

## Carryover Backlog (from Previous Sprint)

> **§11.4 Trigger 1 binding obligation**: this table evaluation is the FIRST plan-authoring step at sprint-13 entry per `docs/process/decisions-convention.md` §11. **S12-10 disposition (a) user-attested SELECTED** (commit `fc9adfb` retro AI #1; user decision at sprint-13 plan-authoring 2026-05-09 PM). Path (c) carry-to-sprint-14 is **forbidden** by §11.

| Carryover Task | Original Sprint | Times Carried | Disposition | New Estimate / Target Tier |
|----------------|-----------------|---------------|-------------|---------------------------|
| **S12-10** S7-11 user attestation pass on 4 VS Validation items | sprint-7 (S7-11) → sprint-8 → sprint-9 → sprint-10 (S10-13) → sprint-11 (S11-12) → sprint-12 (S12-10) | **6** (project-record; **§11 HARD GATE BOUND** at sprint-13 entry per §11.3 Live application table) | **(a) USER-ATTESTED** per §11 disposition (user decision at plan-authoring; path (c) forbidden) | **S13-02 USER-OWNED CRITICAL** Must-Have (0d claude-side; ~30 min user time) — §11 binding requires resolution this sprint |
| **S12-11** S8-15 user attestation pass on sprint-8 manual smoke check Batches 1+3 | sprint-8 (S8-15) → sprint-10 (S10-14) → sprint-11 (S11-13) → sprint-12 (S12-11) | **4** | KEEP USER-OWNED (below 5-time threshold; normal carry) | **S13-10 USER-OWNED** Should-Have (0d claude-side; ~15 min user time) |
| **S12-03** /gate-check pre-prod-to-prod close-gate rerun re-evaluation | sprint-12 (blocker-bound) | **1** | KEEP claude-Must (re-runs after S13-02 + S13-10 attestations land) | **S13-03 Must-Have** (0.1d closure ÷3 → ~0.03d actual) |

**Carryover concentration into sprint-13**: 3 items. AI #2 visibility threshold (≥4) **NOT breached**. §11 HARD GATE binding handles S12-10 6th-carry per disposition (a).

**Disposition rationale**:
- **S12-10 (a) user-attested** chosen over (b) formally-cancelled at user discretion at plan-authoring time (2026-05-09 PM). Rationale: prototypes/chapter-prototype/REPORT.md 4 VS Validation items remain relevant test gates; user-attestation closes them on substantive grounds rather than cancellation. Cancellation decision artifact not required.
- **S12-11 normal-carry** below 5-time threshold; refusal-to-fabricate posture preserved; will be 5th-time at sprint-14 entry IF still pending then (next §11 HARD GATE candidate).
- **S12-03 carryover** is structural — close-gate cannot rerun until attestations land; this is the natural gating pattern, not a process failure.

## Tasks

### Must Have (Critical Path) — §11 HARD GATE binding + retro AI #1 follow-through

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S13-01 | **§11 HARD GATE pre-flight verification (codification + binding)** — verify Carryover Backlog table above includes S12-10 with disposition (a) or (b) per §11.4 Trigger 1; documented as MET by virtue of this plan's existence (table above conforms). Sprint-12 retro AI #1 CRITICAL closure. | claude | 0.05 (closure ÷3 → ~0.015d actual; meta-task documented at plan time) | sprint-12 retro AI #1 | This row's existence in the plan + Carryover Backlog table conformance is the artifact; sprint-13 plan ship validates §11.4 Trigger 1 obligation met |
| S13-02 | **S12-10 S7-11 USER-OWNED CRITICAL attestation** — §11 HARD GATE disposition (a) user-attested. User boots `prototypes/chapter-prototype/chapter.tscn` (or `vertical-slice/battle.tscn`), executes core loop, records attestation per item: PASS / FAIL with notes. **§11 binding means this MUST resolve in sprint-13**; cannot carry to sprint-14. | user | 0 (user time ~30 min) | prototypes/chapter-prototype/ + prototypes/vertical-slice/ + §11 HARD GATE binding | 4 attestations recorded in `prototypes/chapter-prototype/REPORT.md`; S7-11 closes; sprint-13 retro re-evaluates §11 binding fulfillment |
| S13-03 | **S12-03 `/gate-check pre-prod-to-prod` close-gate re-evaluation** post-S13-02 + S13-10 attestations. Verdict eligibility: PASS (writes `production/stage.txt` = `Production`) OR CONCERNS (re-evaluate path-to-PASS). Sprint-11 retro AI #1 follow-through closure. | claude | 0.1 (closure ÷3 → ~0.03d actual) | S13-02 attestation lands + S13-10 attestation lands | New gate-check artifact at `production/gate-checks/pre-prod-to-prod-2026-05-1?-rerun-2.md`; verdict + path-to-PASS documented; `production/stage.txt` written if PASS |

**Must-have subtotal: 0.15d nominal → ~0.045d actual projected** (3 closure × ÷3) + ~30 min user time

### Should Have — sprint-12 retro AI codification debt closure (#5 + #6 + #4)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S13-04 | **Anchored-regex-extraction discipline codification** — sprint-12 retro AI #5. Add TG-4 entry to `.claude/rules/tooling-gotchas.md` covering the lint_sprint_carryover_count first-run misfire (S12-09). Pattern: regex extraction patterns from prose-rich text MUST be anchored on the literal phrase preceding the target token. Same family as G-1/G-9/G-24 + TG-3. | claude | 0.1 (closure ÷3 → ~0.03d actual) | sprint-12 retro AI #5 + existing tooling-gotchas.md TG-1/2/3 precedents | TG-4 entry added with Context → Broken → Correct → Discovered structure; cross-reference from `.claude/skills/architecture-decision/SKILL.md` if regex-extraction discipline is skill-adjacent |
| S13-05 | **Byte-cap-recurrence-prevention codification** — sprint-12 retro AI #6. Make 200-byte sprint-status changelog check a `/story-done` Phase 7 step rather than oral guideline. Fired 4th time at S12-08; mitigation already proposed at sprint-11 retro Process Improvement #2 (scratch-draft + byte-check before commit-into-story-row). | claude | 0.1 (closure ÷3 → ~0.03d actual) | sprint-12 retro AI #6 + sprint-11 retro Process Improvement #2 | `.claude/skills/story-done/SKILL.md` Phase 7 step (NEW byte-check sub-step); validation: future /story-done invocations should fail closed if changelog draft >200 bytes |
| S13-06 | **`production/decisions/` directory §7 promotion trigger evaluation** — sprint-12 retro AI #4. Threshold ≥3 artifacts AND ≥2 distinct sprints **HAS FIRED** (4 artifacts across sprint-10 + sprint-12). Producer call: keep as Route c standalone OR promote to Route a sibling skill `/process-decision`. Document outcome at `production/decisions/decisions-convention-promotion-evaluation-2026-05-1?.md` per Route c convention. | producer (consults user) | 0.2 (admin ÷3 → ~0.07d actual) | sprint-12 retro AI #4 + `docs/process/decisions-convention.md` §7 trigger | Decision recorded; if Route a chosen, `/process-decision` skill scaffolded; if Route c retained, decision rationale documented |

**Should-have subtotal: 0.4d nominal → ~0.13d actual projected** (3 closure × ÷3)

### Nice to Have — closure-mode signal evaluation + tracking-only retro AIs

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S13-07 | **Sprint-13 closure-mode signal evaluation per §11.4 Trigger 4** — sprint-12 retro AI #3. Recurring per-sprint gate. Count A/B/C/D/E signals per `production/decisions/closure-mode-sprint-pattern-2026-05-09.md`; designate sprint-13 mode (closure / mixed / borderline). **First live signal-evaluation since codification** — establishes precedent for sprint-14+ pattern usage. | producer | 0.05 (admin ÷3 → ~0.015d actual; signal-count exercise) | sprint-12 retro AI #3 + closure-mode HYBRID decision | Signal count table embedded in this sprint plan §Sprint Mode (companion edit at first invocation per S12-07 deferred edit) OR as standalone signal-evaluation note; sprint-13 mode designated |
| S13-08 | **Convention-extension-via-numbered-section pattern validation** — sprint-12 retro AI #7. Tracking-only (no action this sprint unless convention extension triggers). At next convention extension, evaluate whether §11-style top-level addition is the right shape vs §3-style embedding. | producer | 0d (tracking-only this sprint) | sprint-12 retro AI #7 | No new artifact; row exists to track for sprint-13+ convention extensions |
| S13-09 | **POLISH-006 forcing function monitoring** — sprint-12 retro AI #8. Tracking-only (no action this sprint unless commission-sprint forcing function fires). AD-C5 will fully close when both Guan Yu + Zhang Fei stubs ship + character-art commission sprint enters planning OR Polish gate fires. | art-director (or claude) | 0d (tracking-only this sprint) | sprint-12 retro AI #8 + POLISH-006 entry | No new artifact; row exists to track for sprint-13+ commission-sprint trigger |

**Nice-to-have subtotal (claude-owned + producer): 0.05d nominal → ~0.015d actual projected**

### USER-OWNED — refusal-to-fabricate carryover

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S13-10 | **S12-11 S8-15 user attestation pass** on sprint-8 manual smoke check Batches 1+3 — **4th-time carryover** (below 5-time threshold; normal carry). User executes documented batches in `production/qa/qa-signoff-sprint-8-2026-05-06.md` Batches 1+3 sections, records PASS / FAIL per item. | user | 0 (user time ~15 min) | production/qa/qa-signoff-sprint-8-2026-05-06.md | Batches 1+3 attestations recorded; verdict potentially upgrades from APPROVED WITH CONDITIONS → APPROVED |

## Cuts (per sprint-13 plan + sprint-12 retro AI evaluation)

| Story | Reason for Cut |
|---|---|
| ~~In-sprint scope expansion (e.g., another epic flesh-out)~~ | Sprint-13 is closure/admin-leaning by user decision at plan-authoring time. No greenfield scope identified. If forcing function fires mid-sprint (e.g., a new GDD requires impl), evaluate sprint-13 mid-sprint at producer call |
| ~~Pause-menu UX spec~~ (AD-C6 open side; sprint-11 carry-forward) | Not in sprint-13 scope; remains AD ADVISORY for menu-implementation sprint. No forcing function this sprint |
| ~~Polish-tier sprint-13 trigger~~ | Sprint-13 is not yet at Polish phase entry; POLISH-001..006 carry-forwards remain in `production/polish-backlog.md` |

## Sprint Mode (S13-07 first live application of S12-07 closure-mode HYBRID signal evaluation)

> **Companion edit deferred at S12-07** (`production/decisions/closure-mode-sprint-pattern-2026-05-09.md` §11.4 Trigger 4) — first sprint-13+ /sprint-plan invocation triggers the `## Sprint Mode` section addition to `.claude/skills/sprint-plan/SKILL.md` Phase 2 template. Sprint-13 plan applies the pattern inline as evidence + the deferred companion edit lands at S13-07 closure.

**Sprint-13 closure-mode signal count**:

| Signal | Description | Sprint-13 satisfies? | Evidence |
|---|---|---|---|
| **A** Primary mode = closure-absorption | Plan dominated by carryover absorption + retro AI execution | ✅ YES | 3 carryover (S13-02/03/10) + 6 retro AI rows (S13-04..S13-09); 0 greenfield rows |
| **B** Carryover concentration ≥4 | At sprint entry | ❌ NO (3 items < 4 threshold) | Carryover = 3 items; AI #2 threshold not breached |
| **C** Zero new architectural risk | No new ADR required this sprint | ✅ YES | 0 new ADRs in sprint-13 plan; all work consumes existing ADRs / conventions |
| **D** Test count delta dominated by closure follow-on | ≥80% of expected test additions from closure work | ✅ YES | Sprint-13 expects ~0 test additions (closure/admin-leaning); 100% of any test additions would be closure-tier |
| **E** Single-session execution feasibility | Claude-side projected ≤1 calendar day | ✅ YES | Projected ~0.5-0.7 calendar day per closure-leaning HYBRID multiplier |

**Signal count: 4 of 5 (A/C/D/E) — exceeds ≥3-of-5 threshold per §11.4 HYBRID trigger.**

**Sprint-13 mode designation: CLOSURE-LEANING HYBRID** (matches user decision at plan-authoring time).

This is the **first live signal-evaluation** since S12-07 codification — establishes precedent for sprint-14+ usage.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **R1 — S13-02 user attestation slip** (user time doesn't materialize within sprint-13 window) | **Medium** | **CRITICAL** | §11 binding means sprint-13 close-out CANNOT carry S13-02 to sprint-14 (path (c) forbidden). Mitigation: (1) ESCALATE to user immediately if attestation hasn't landed by Day 2 morning; (2) If slip continues, **fallback to disposition (b)** at sprint-13 close — claude authors `production/decisions/{topic-slug}-cancel-decision-2026-05-1?.md` per Route c convention as last-resort. User opted for pure (a) at plan-authoring; the (b) fallback is forced-by-§11, not preferred |
| **R2 — S13-03 close-gate STILL CONCERNS** even after attestations land | Low | Medium | If new path-to-PASS issues surface (beyond items 1+2), document at gate-check artifact; sprint-14 absorbs as new path-to-PASS. Acceptable outcome; CD verdict will not regress |
| **R3 — S13-04 codification scope creep** (anchored-regex pattern extends beyond expected scope) | Low | Low | Time-box S13-04 to 1 entry; if extended pattern emerges, defer to sprint-14 retro AI |
| **R4 — S13-06 producer §7 promotion outcome contentious** | Low-Medium | Low | Surface 3 candidate options to user before authoring (Route a / Route c-stay / hybrid); default to Route c-stay if user prefers minimal-change |
| **R5 — Sprint-13 closure-mode designation drift** if greenfield forcing function fires mid-sprint | Low | Low | Producer call mid-sprint at first greenfield-trigger event; redesignate mode if signals shift to mixed-mode |
| **R6 — Sprint-13 close gate-check (S13-03) returns CONCERNS** with attestations landing but new items surface | Low | Low | Acceptable; sprint-14 absorbs. Same risk pattern as sprint-12 R5 |

## Dependencies on External Factors

- **User attestation gates S13-02 + S13-10**: §11 binding makes S13-02 critical-path; refusal-to-fabricate posture preserved
- **S13-03 close-gate verdict**: depends on S13-02 + S13-10 attestation outcomes
- **S13-06 producer call**: requires user concurrence on §7 promotion path (Route a vs Route c)

## Sprint-13 Retro AI seed (carry from sprint-12 retro)

- **AI #1** (sustained sprint-7→8→9→10→11→12→13): Codification debt MUST be paid at retro time
- **AI #2** (sustained sprint-9→10→11→12→13): Carryover concentration threshold ≥4 — sprint-13 entry has 3 (well below); validate post-S13 absorption
- **AI #3** (sustained sprint-9→10→11→12; pattern stable at 4 invocations): BACKFILL CLOSE-OUT verdict — sprint-13 may not invoke if no drift surfaces
- **AI #4** (validated 4th time sprint-12 at heavy-closure boundary): Mixed-mode velocity multiplier — sprint-13 closure-leaning re-validates against ÷~4 expectation
- **AI #5** Sprint-13 close gate-check evaluation (verify §11 binding fulfillment + S13-03 verdict)
- **AI #6** §11 HARD GATE rule live-binding outcome — does (a) user-attested actually close S7-11, or does it just rename the holding pattern? Validate at sprint-13 retro
- **AI #7** Closure-mode HYBRID first live signal-evaluation outcome (S13-07) — does the signal count match user-perceived sprint mode?
- **AI #8** `production/decisions/` §7 promotion outcome (S13-06) — Route a vs Route c retention decision
- **AI #9** First sprint to enter with §11.3 Live application table binding — codify the pattern of "structural pre-flight obligations" for sprint-14+
- **AI #10 NEW** /story-readiness path-verification gap — sprint-12 fired 3 times; sprint-13 may fire if any /story-readiness invocations happen; threshold codification candidate at ≥4-invocation-stable

## Definition of Done for this Sprint

- [ ] All Must Have tasks (S13-01 + S13-02 + S13-03) completed
- [ ] All tasks pass acceptance criteria (per Tasks table)
- [ ] **§11 HARD GATE binding fulfilled** — S13-02 attestation landed OR (R1 fallback) S12-10 cancellation decision authored at sprint-13 close
- [ ] QA plan exists (`production/qa/qa-plan-sprint-13-[date].md`) — see Phase 5 gate of /sprint-plan
- [ ] All Logic/Integration stories have passing unit/integration tests (sprint-13 expects 0 such stories per closure-leaning mode)
- [ ] Smoke check passed (`/smoke-check sprint`) — file naming per S11-10 codified convention `production/qa/smoke-sprint-13-[date].md`
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint-13` attestation-mode for closure-leaning) — file naming per S11-10 codified convention `production/qa/qa-signoff-sprint-13-[date].md`
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
- [ ] **Gate-check S13-03 re-run**: verdict documented; `production/stage.txt` written if PASS
- [ ] Sprint-13 retrospective authored at `production/retrospectives/retro-sprint-13-[date].md` (must address §11 first-binding outcome + closure-mode first-signal-evaluation outcome + 2 codification AIs delivered)

---

> **Scope check**: Sprint-13 has no greenfield scope; no /scope-check invocation needed. If mid-sprint forcing function fires (greenfield trigger), run /scope-check at that point.

> **QA Plan**: Run `/qa-plan sprint-13` after this sprint plan ships and before any S13-01..S13-09 implementation begins. The Production → Polish gate (and the sprint-13 close gate-check S13-03) requires a QA sign-off report, which requires a QA plan.
>
> **Recommended order**: (1) commit + push this sprint plan; (2) run `/qa-plan sprint-13` next; (3) S13-01 + S13-04 + S13-05 are claude-side-doable immediately; S13-02 + S13-10 are user-attestation-only; S13-06 awaits producer call; S13-03 awaits S13-02 + S13-10 attestations.
