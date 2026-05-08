# Pre-Production → Production Gate Check — 2026-05-08

| Field | Value |
|---|---|
| **Date** | 2026-05-08 |
| **Target phase** | Production |
| **Review mode** | lean (`production/review-mode.txt`) |
| **Verdict** | **CONCERNS** (unchanged from 2026-05-06; sprint-9 + sprint-10 + sprint-11 closures advanced substrate by 3 cycles but did NOT close the experiential validation gap; sole gating blockers UNCHANGED at S7-11 + S8-15 USER-OWNED — now carried as S11-12 4th-time + S11-13 2nd-time) |
| **Director Panel** | 3× READY (TD + PR + AD) + 1× CONCERNS (CD) — same pattern as 2026-05-05 + 2026-05-06; pattern stable at 3 invocations |
| **Sole gating blockers** | **S7-11 user attestation** (4 VS Validation items; 4th-time carryover) + **S8-15 user attestation** (manual smoke check Batches 1+3; 2nd-time carryover) — both USER-OWNED + **CD-flagged ≥1 player-facing Pillar 3/4 demonstration target for sprint-12** |
| **Cross-references** | Prior gate-check `production/gate-checks/pre-prod-to-prod-2026-05-06.md` (CONCERNS); /team-qa sign-off `production/qa/qa-signoff-sprint-11-2026-05-08.md` (APPROVED); smoke check `production/qa/smoke-sprint-11-2026-05-08.md` (PASS); retrospective `production/retrospectives/retro-sprint-11-2026-05-08.md` |

---

## 1. Verdict Trajectory

| Date | Verdict | Director Panel | Note |
|---|---|---|---|
| 2026-04-20 | FAIL | n/a (prior format) | First gate-check; multiple structural gaps |
| 2026-05-04 | CONCERNS | 4× CONCERNS | 13/17 artifacts; 6-step path-to-PASS surfaced |
| 2026-05-05 | CONCERNS | 3× READY + 1× CONCERNS (CD) | 15/17 artifacts; sole gate = S7-11 user attestation |
| 2026-05-06 | CONCERNS | 3× READY + 1× CONCERNS (CD) | 17/17 artifacts; sole gates = S7-11 + S8-15 USER-OWNED |
| **2026-05-08** | **CONCERNS** | **3× READY + 1× CONCERNS (CD)** | **20/20 artifacts (3 net-new sprint-11 additions); sole gates = S7-11 (4th-time) + S8-15 (2nd-time) USER-OWNED + CD Pillar 3/4 demo target** |

**Trajectory**: Substrate continues to harden cycle-over-cycle (sprint-9 → sprint-10 → sprint-11 = 3 cycles; +120 tests at battle-hud + 4 consecutive FFBs 49th–52nd + 36-streak in-patch hygiene; 20 ADRs all Accepted + Core layer 5/5 Complete + ai-system Feature 1/1 Complete + main-menu UX spec stub + Liu Bei character profile stub + production/decisions/ + production/polish-backlog.md + production/process-audits/). USER-OWNED attestation pattern stable at 4-invocation deferral; refusal-to-fabricate posture preserved. Pillar 3+4 demonstration unchanged at HYPOTHESIS.

---

## 2. Required Artifacts: 20/20 Present (3 net-new since 2026-05-06)

| Required Artifact | Status | Evidence |
|---|---|---|
| At least 1 prototype with README | ✅ | `prototypes/chapter-prototype/` + `prototypes/vertical-slice/` |
| First sprint plan exists | ✅ | `production/sprints/sprint-1.md` through `production/sprints/sprint-11.md` (11 sprints) |
| Art bible complete (all 9 sections + sign-off) | ✅ | `design/art/art-bible.md` |
| Character visual profiles for key characters | ✅ **NEW (S11-09 sprint-11)** | `design/art/characters/liu-bei.md` (first-stub-shipped partial state per AD-C5; Guan Yu + Zhang Fei DESCOPED per sprint-10 retro AI #5) |
| All MVP-tier GDDs complete | ✅ | per `design/gdd/systems-index.md` |
| Master architecture document | ✅ | `docs/architecture/architecture.md` v0.8 |
| ≥3 ADRs covering Foundation-layer | ✅ | 20 ADRs (ADR-0001 .. ADR-0020) all Accepted; Foundation 5/5 |
| Control manifest exists | ✅ | `docs/architecture/control-manifest.md` |
| Epics defined (Foundation + Core) | ✅ | `production/epics/` — 20 epics inc. **save-load NEW (S11-07 sprint-11)** |
| Vertical Slice build playable | ✅ | `prototypes/vertical-slice/battle.tscn` + `prototypes/chapter-prototype/chapter.tscn` |
| VS playtested ≥3 sessions | ⚠ | S7-11 attestation gap (4th-time carryover; refusal-to-fabricate) |
| VS playtest report | ⚠ | S7-11 attestation gap (same) |
| UX specs for key screens | ✅ **PARTIAL — main-menu NEW (S11-08 sprint-11)** | `design/ux/battle-hud.md` + **`design/ux/main-menu.md` (sprint-11)**; pause-menu spec remains AD-C6 ADVISORY |
| HUD design document | ✅ | `design/ux/battle-hud.md` v1.1 |
| Key UX specs passed `/ux-review` | ⚠ ADVISORY | battle-hud APPROVED; main-menu stub-level (sprint-11 NEW; ux-review run pending sprint-12) |
| Smoke check PASS or PASS WITH WARNINGS | ✅ **NEW (sprint-11)** | `production/qa/smoke-sprint-11-2026-05-08.md` PASS (1236/1236; 52nd FFB) |
| QA plan + sign-off | ✅ **NEW (sprint-11)** | `production/qa/qa-plan-sprint-11-closure-2026-05-08.md` + `production/qa/qa-signoff-sprint-11-2026-05-08.md` APPROVED |
| Accessibility requirements | ✅ | `design/ux/accessibility-requirements.md` Intermediate tier |
| Interaction pattern library | ✅ | `design/ux/interaction-patterns.md` |
| Architecture traceability | ✅ | `docs/architecture/architecture-traceability.md` v0.14 |

**3 net-new artifacts since 2026-05-06**: liu-bei character profile stub (S11-09) + main-menu UX spec stub (S11-08) + sprint-11-close artifact set (smoke + qa-plan + qa-signoff + retro).

---

## 3. Quality Checks

### Test substrate (TD-domain)

- **1236 / 1236 PASS / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0** — **52nd consecutive failure-free baseline** (chain unbroken since hp-status story-001; +120 tests added across sprints 8–10 — sprint-11 was doc-only, kept count at 1236)
- 49th FFB (sprint-9 close) + 50th FFB (sprint-9-close-S9-04) + 51st FFB (sprint-10 close) + 52nd FFB (sprint-11 close) = 4 consecutive FFB increments since prior gate
- 36-streak in-patch sprint-status hygiene (was 25 at sprint-10 close; +11 in sprint-11)
- G-7 silent-skip detection: PASS (Overall Summary count match)
- 20 ADRs all Accepted (sprint-11 added 0 new ADRs; ADR-0020 InputRouter Accepted at 2026-05-06 prior-gate-eve)

### Architecture surface (TD-domain)

- 5 net new conventions codified in sprint-11 alone: production/decisions/ Route c (S11-05) + Polish-tier ledger (S11-06) + sprint-close filename naming (S11-10) + /story-done Phase 7 step 5+6+7 (S11-03) + lint_story_status_consistency (NEW lint script)
- 2 net new directories established: docs/process/ (S11-05) + production/process-audits/ extension (S11-03 + S11-11 = 2 artifacts)
- save-load Core epic skeleton ready (S11-07) — 3-story decomposition for sprint-12 /create-stories follow-on
- lint_story_status_consistency surfaces 33 pre-existing drift items — sprint-12 cleanup target (process-doc domain per TD; not TD-tier risk)

### Vertical Slice Validation (CD-domain — UNCHANGED from 2026-05-06)

- A human has played through the core loop without developer guidance — **pending S7-11 attestation**
- The game communicates what to do within the first 2 minutes of play — **pending S7-11 attestation**
- No critical "fun blocker" bugs exist in the Vertical Slice build — **pending S7-11 attestation**
- The core mechanic feels good to interact with — **pending S7-11 attestation** (subjective check)

### Pillar Demonstration Status (CD-domain)

- **Pillar 1 (형세의 전술)**: PROVEN (mechanical + e2e integration tests across grid-battle-controller + battle-hud)
- **Pillar 2 (운명은 바꿀 수 있다)**: PROVEN (4-invocation architectural lock; chapter-1 e2e; destiny-branch + ai-system epics graduated)
- **Pillar 3 (영웅의 무게)**: HYPOTHESIS (mechanical scaffolding present via hp-status + unit-role + hero-database; narrative weight beat NOT shipped)
- **Pillar 4 (전국 시대의 그림자 / 삼국지의 숨결)**: HYPOTHESIS (structural arc proven; atmospheric tone gated on art-bible execution + audio surfacing — Liu Bei stub is a *precursor*, not *evidence*)

---

## 4. Director Panel Assessment (Lean Mode — All 4 Spawned in Parallel)

### Creative Director — **CONCERNS**

**Verdict comparison vs. 2026-05-06**: HOLDS at CONCERNS. Substrate has advanced impressively (Core 5/5 + battle-hud Feature 1/1 + 52nd FFB + ai-system Feature 1/1), but **none of the 3-sprint deltas address the experiential validation gap**. Sprint-9 was input polish, sprint-10 was presentation scaffolding, sprint-11 was 100% doc-only. Pillar 3 + Pillar 4 remain HYPOTHESIS — mechanical scaffolding has thickened, but no playable narrative beat or atmospheric moment has shipped to a player-facing surface in 3 cycles.

Specific findings:
1. **Pillar 3+4 status: HYPOTHESIS unchanged.** A doc-only sprint cannot move pillars from hypothesis to proven by definition — pillars are validated by player-facing experience, not by graduated epic counts. The destiny-branch + ai-system Core/Feature backfill is artifact-side closure, not demonstration.
2. **AD-C5/C6 stub closure does NOT materially change Pillar 4 readiness.** A liu-bei profile stub + main-menu UX spec stub are *necessary precursors* to atmospheric tone delivery, not *evidence* of it. Stubs gate downstream work; they do not constitute a shipped atmospheric moment. Three Kingdoms tone proves itself when a player sees/hears/reads it in-game, not when its spec exists.
3. **USER-OWNED 4th-time carryover IS a structural signal worth flagging — but not a CD blocker.** Refusal-to-fabricate is the correct posture; CD endorses it. However, 4 sprints of carryover suggests the attestation workflow itself may need redesign (lower-friction path, async batching, or explicit "deferred-to-Production-readiness-review" status). **Recommend escalating to producer for workflow review next sprint** — process debt accumulating, not creative debt.

**CD-refined Path-to-PASS** (NEW from this gate):
- Sprint-12 must ship at least **ONE player-facing Pillar 3 or Pillar 4 demonstration** (narrative beat in-engine OR atmospheric audio/visual moment in battle-hud).
- The "Production gate eligibility precondition MET" framing in sprint-11 retro should be tightened to "**artifact-side eligibility MET; experiential validation pending sprint-12 demo target**."

### Technical Director — **READY**

**Verdict comparison vs. 2026-05-06**: HOLDS at READY (reinforced).

The 20th ADR + 3-sprint zero-regression substrate REINFORCES prior READY. ADR-0020 (InputRouter, Accepted 2026-05-06) closes the input-handling architecture surface that S9 implemented; sprint-10 battle-hud (8/8) + sprint-11 doc-only consolidation produced zero new ADR debt while tests grew 1116 → 1236 (+120) with 36-streak in-patch hygiene and 4 consecutive FFBs (49th–52nd). Architecture surface is not just stable — it is *hardening* under load. Mandatory ADR list = 0 holds; Core layer 5/5 Complete is now substrate-verified, not just doc-flipped (S11-02 backfill confirmed pre-existing implementation at S7-02 ba02e02 was already in the 1236 baseline).

**33-drift surfacing is process-doc domain, NOT TD-tier.** lint_story_status_consistency (S11-03) catches Status field drift in production/epics/**/*.md — these are production-management artifacts, not src/ or docs/architecture/ artifacts. Zero of the 33 items touch ADR consistency, performance budgets, or cross-system contracts. Route to qa-lead + producer for sprint-12 cleanup.

**No new technical risks surfaced.** S10-05 CI-lane postponement was a binding decision TD co-signed — Linux + Windows D3D12 lanes green is sufficient for Production entry on the MVP path. S11-07 save-load epic skeleton correctly references ADR-0003/0017/0001 ahead of /create-stories.

### Producer — **READY**

**Verdict comparison vs. 2026-05-06**: HOLDS at READY (reinforced).

The 3-sprint clean closure record (sprint-9/10/11 all closed with no slipped Must items, 7-of-7 prior retro AIs absorbed in sprint-11 — first project precedent of 100% prior-sprint AI closure) materially strengthens the prior READY verdict; this is no longer a single-data-point velocity model — it's a 3-cycle validated model with explicit closure-mode capacity calibration as a bonus precedent for production-phase planning.

**On process risk**: No new process risks introduced. The 36-streak in-patch hygiene + 52nd FFB + 5 net new conventions codified in sprint-11 indicate the process tightened, not loosened, across the cycle.

**On USER-OWNED 4th-time-carry**: This is a known holding pattern, NOT a structural project-management failure. Refusal-to-fabricate posture is the correct producer behavior — escalation would mean writing attestations the user has not provided, which would corrupt the audit trail. Sprint-12 retro AI #7 (5th-time threshold codification) is the right next step. Recommend keeping this OUT of gate scope; it's a USER-action item, not a producer-process item.

**On closure-mode capacity**: The -77% over-performance for 100%-closure-mix is informative for production planning — closure-only sprints can absorb more retro-AI throughput than mixed-mode sprints. Sprint-12 retro AI #6 (closure-mode sprint planning evaluation) is correctly seeded.

### Art Director — **READY**

**Verdict comparison vs. 2026-05-06**: HOLDS at READY.

Both partial closures (AD-C5 + AD-C6) are meaningful, not merely nominal. The Liu Bei stub is substantive — defines Pillar 4 minimum recognition triplet (prominent-ears + full-trim-beard + paired-swords), locks reserved-color discipline at the character layer, establishes Peach Garden triangle composition, and explicitly protects Cao Cao / Sun Quan silhouette-collision space for future COMMANDER stubs via the cross-class boundary table. The main-menu UX spec carries production-grade content: layout zones, accessibility compliance table, component inventory, and event contracts. Neither document is a placeholder.

**On Liu Bei stub as benchmark**: Sets the silhouette-distinguishability framework adequately for sprint-12+ COMMANDER hero stub authoring (three-zoom legibility + asymmetric equipment protrusion rule + collision-exclusion table).

**On the descope-to-1-stub risk** (NEW ADVISORY-CANDIDATE): The Guan Yu + Zhang Fei DESCOPE does not introduce a new AD-tier risk *today* because no character-art production sprint is scheduled. The risk will surface as a new ADVISORY when that sprint is planned — at which point Guan Yu and Zhang Fei stubs will need to be authored before art commission begins. **Flagging now**: if a character-art sprint enters sprint-12 planning, author the Guan Yu + Zhang Fei stubs before that sprint closes story-readiness. Tracking candidate: `production/polish-backlog.md` POLISH-006 (NEW; AD-flagged for sprint-12 producer review).

**Remaining open items**: AD-C2 (contrast pass), AD-C3 (緣 font glyph, BUNDLED into first-text-rendering story), pause-menu UX spec (AD-C6 open side), POLISH-001..005 — all remain ADVISORY and Polish-tier appropriate. Nothing has graduated to BLOCKING.

---

## 5. Director Panel Verdict Synthesis

| Director | Verdict | Blockers |
|---|---|---|
| Creative | **CONCERNS** | Pillar 3+4 demonstration unproven (CONCERN); S7-11 + S8-15 attestation gaps acknowledged as USER-OWNED (NOT CD blockers); CD-refined path adds sprint-12 ≥1 Pillar 3/4 player-facing demo target |
| Technical | **READY** | None; substrate hardening; 33-drift surfacing routed to process-doc domain |
| Producer | **READY** | None; 3-cycle clean closure record reinforces; USER-OWNED 4th-time correctly held outside gate scope |
| Art | **READY** | None; AD-C5+AD-C6 partial closures substantive; Liu Bei sets benchmark; **NEW ADVISORY-candidate**: Guan Yu+Zhang Fei DESCOPE flagged for sprint-12 polish-backlog POLISH-006 entry if character-art sprint schedules |

**Per Phase 4b rule**: Any director CONCERNS → verdict is minimum CONCERNS. CD CONCERNS → verdict is **CONCERNS**.

---

## 6. Path to PASS (UPDATED — 2 USER-OWNED items + 1 CD-refined sprint-12 target)

### Item 1 — S7-11 user attestation (4 VS Validation items) — 4th-time carryover

**Carry chain**: S7-11 → S8-15 → S9-? → S10-13 → S11-12 (4 sprints continuous deferral; first time the count reaches 4)

**Required attestation per ADR-0001 §VS Validation + sprint-7 R-3**:
1. Human plays core loop without developer guidance (PASS / FAIL with notes)
2. Game communicates objectives within first 2 minutes (PASS / FAIL with notes)
3. No critical fun-blocker bugs (PASS / FAIL with notes)
4. Core mechanic feels good (subjective; PASS / FAIL with notes)

**Resolution path**: User boots `prototypes/chapter-prototype/chapter.tscn` (or `prototypes/vertical-slice/battle.tscn`), executes the core loop, and records attestation in `prototypes/chapter-prototype/REPORT.md`. Estimated time: ~30 minutes user time.

### Item 2 — S8-15 user attestation (manual smoke check Batches 1+3) — 2nd-time carryover

**Carry chain**: S8-15 → S10-14 → S11-13 (2 sprints)

**Required attestation**: Manual execution of sprint-8 manual smoke check Batches 1 (core stability) + 3 (data integrity + perf), recorded in `production/qa/qa-signoff-sprint-8-2026-05-06.md` Batches 1+3 sections.

**Resolution path**: User executes the documented batches + records PASS / FAIL per item. Estimated time: ~15 minutes user time.

### Item 3 — CD-refined sprint-12 demonstration target (NEW from this gate)

**CD-refined path-to-PASS**: Sprint-12 must ship at least **ONE player-facing Pillar 3 OR Pillar 4 demonstration**. Concrete options:
- Pillar 3 (영웅의 무게): a narrative beat in-engine where the player feels the weight of a hero's choice / death / loyalty (e.g., a chapter-1 scenario beat that uses ScenarioRunner's 9-beat ceremony to surface Pillar 3 stakes via dialogue + visual treatment)
- Pillar 4 (삼국지의 숨결): an atmospheric audio/visual moment in battle-hud that conveys Three Kingdoms tone (e.g., 운명 분기 reserved-color treatment shipping with audio cue at a destiny-branch resolution moment)

**Resolution path**: Sprint-12 plan should include a Must-Have story explicitly targeting one of the above. Estimated effort: ~1-2d nominal (greenfield gameplay content).

**Combined effort to upgrade CONCERNS → PASS**:
- Items 1+2: ~45 minutes user time
- Item 3: 1-2d sprint-12 implementation (claude-side)
- Total: items 1+2 + at least one shipped Pillar 3/4 demo at sprint-12 close — eligible for next-gate-check PASS

---

## 7. Alternative Path: Accept Production at CONCERNS

The user MAY override this verdict and advance to Production stage despite CONCERNS, with explicit acknowledgement that:

- Pillar 3+4 demonstration remains HYPOTHESIS until sprint-12+ shipping
- S7-11 + S8-15 USER-OWNED gates carry into Production stage as gate-debt items (sprint-12 retro AI #7 5th-time-threshold codification candidate)
- Acknowledge in writing that **CONCERNS verdict is being accepted** and the project enters Production with these CONCERN items tracked as sprint-12 backlog (not retrospectively claimed READY)

**This path is NOT recommended** — the prior gate (2026-05-06) and this gate (2026-05-08) both flagged the same blockers; sprint-9/10/11 substrate progress did NOT close them. Advancing without addressing them perpetuates the deferral pattern indefinitely.

**Recommended alternative**: Stay at Pre-Production stage; sprint-12 plan tackles items 1+2+3 above; next gate-check at sprint-12 close re-evaluates with potential PASS verdict.

---

## 8. Carryover into Sprint-12 (Production Phase Eligibility-Pending)

| Item | Source | Sprint-12 disposition | Owner | Priority |
|---|---|---|---|---|
| S7-11 attestation (5th-time at sprint-12) | sprint-7 R-3 | S12-01 USER-OWNED carryover; recommend 5th-time-threshold codification per sprint-11 retro AI #7 | user | **High** |
| S8-15 attestation (3rd-time at sprint-12) | sprint-8 R-? | S12-02 USER-OWNED carryover | user | Medium |
| **NEW** Pillar 3 OR Pillar 4 player-facing demo | this gate CD path-to-PASS refinement | S12-03 Must-Have greenfield gameplay story (~1-2d nominal) | claude (or game-designer + writer) | **High** |
| save-load Core epic /create-stories | sprint-11 S11-07 follow-on (sprint-11 retro AI #2) | S12-?? /create-stories save-load | claude | High |
| lint_story_status_consistency 33-drift bulk cleanup | sprint-11 S11-03 surfacing (sprint-11 retro AI #3) | S12-?? single coordinated pass | claude | High |
| TODO triage Address actions (5 items) | sprint-11 S11-11 (sprint-11 retro AI #4) | S12-?? bundleable ~30-min commit | claude | Medium |
| **NEW** Guan Yu + Zhang Fei character profile stubs (POLISH-006-candidate) | this gate AD flag — fires ONLY IF character-art sprint enters sprint-12 planning | conditional sprint-12 backlog row OR polish-backlog.md POLISH-006 entry | art-director | conditional |
| Closure-mode sprint planning evaluation | sprint-11 retro AI #6 | S12-?? producer call at sprint-12 plan time | producer | Medium |

---

## 9. Chain-of-Verification

**Step 1 — Generate 5 challenge questions** for the CONCERNS draft:

1. **Could any listed CONCERN be elevated to a blocker given the project's current state?**
   → No. CD-flagged Pillar 3+4 demonstration is explicitly Production-phase activity (per all 4 directors). S7-11 + S8-15 are USER-OWNED gates; refusal-to-fabricate posture means MANUAL CHECK NEEDED is correctly classified, not soft-FAIL.

2. **Is the concern resolvable within the next phase, or does it compound over time?**
   → Resolvable in sprint-12. CD-refined path-to-PASS specifies ≥1 Pillar 3/4 player-facing demo target; that is a concrete achievable target for a single sprint with greenfield ÷5 multiplier (1-2d nominal). USER-OWNED items resolve in ~45 min total user time. Not compounding.

3. **Did I soften any FAIL condition into a CONCERN to avoid a harder verdict?**
   → No. The verdict CONCERNS is justified by:
   - 1× CD CONCERNS (per Phase 4b rule, fixes minimum verdict at CONCERNS)
   - 0 missing required artifacts (20/20 present including 3 net-new sprint-11 additions)
   - 0 BLOCKING quality checks (all automated tests PASS at 52nd FFB)
   - 0 architecture surface concerns (20 ADRs Accepted; mandatory ADR list = 0)
   - All path-to-PASS items from prior gate-check 2026-05-06 either closed (artifact-side) or unchanged (USER-OWNED)

4. **Are there artifacts I didn't check that could reveal additional blockers?**
   → Spot-check: production/playtests/ does NOT exist (gate calls for "≥3 distinct playtest sessions documented"). However, this maps to the S7-11 attestation gap (the playtest documentation IS the S7-11 attestation; it's the same artifact under different framings). Already counted in Item 1 of path-to-PASS.

5. **Do all the CONCERNS together create a blocking problem even if each is minor alone?**
   → No. The 3 path-to-PASS items are independent: (1) S7-11 user time + (2) S8-15 user time + (3) sprint-12 demo target. They don't compound; they parallelize. User can do items 1+2 today; claude can take item 3 in sprint-12 plan.

**Step 2 — Re-verify specific files independently**:

- `production/qa/smoke-sprint-11-2026-05-08.md` (just-shipped) confirms 1236/1236 PASS / 52nd FFB ✓
- `production/qa/qa-signoff-sprint-11-2026-05-08.md` (just-shipped) confirms verdict APPROVED with no conditions ✓
- `docs/architecture/architecture-traceability.md` v0.14 confirms 20 ADRs Accepted; mandatory ADR list = 0 ✓
- `production/sprint-status.yaml` confirms S11-12 + S11-13 status=backlog (USER-OWNED unchanged) ✓
- `design/art/characters/liu-bei.md` (sprint-11 NEW) confirms first-stub-shipped state ✓
- `design/ux/main-menu.md` (sprint-11 NEW) confirms 14-section UX spec stub ✓

**Step 3 — Revision check**: All answers consistent with CONCERNS draft. **Verdict unchanged at CONCERNS.**

**Chain-of-Verification: 5 questions checked — verdict unchanged from CONCERNS to CONCERNS**.

---

## 10. Files Produced

- This gate-check artifact: `production/gate-checks/pre-prod-to-prod-2026-05-08.md`
- `production/stage.txt` — **NOT WRITTEN** (verdict CONCERNS; only PASS triggers stage.txt write per Phase 6 protocol)

---

## 11. Cross-References

- Prior gate-check: `production/gate-checks/pre-prod-to-prod-2026-05-06.md` (CONCERNS — same pattern)
- Sprint-11 close artifacts: `production/qa/smoke-sprint-11-2026-05-08.md` + `production/qa/qa-plan-sprint-11-closure-2026-05-08.md` + `production/qa/qa-signoff-sprint-11-2026-05-08.md` + `production/retrospectives/retro-sprint-11-2026-05-08.md`
- Architecture: `docs/architecture/architecture.md` v0.8 + `docs/architecture/architecture-traceability.md` v0.14 + 20 ADRs (ADR-0001..ADR-0020)
- USER-OWNED gates: `prototypes/chapter-prototype/REPORT.md` (S7-11 attestation target) + `production/qa/qa-signoff-sprint-8-2026-05-06.md` (S8-15 attestation target)
- Sprint-11 retro AIs: `production/retrospectives/retro-sprint-11-2026-05-08.md` §Action Items for Sprint-12

---

## Verdict: **CONCERNS**

**Sole gating blockers** (3 items; 2 USER-OWNED + 1 CD-refined sprint-12 target):
1. S7-11 user attestation (4 VS Validation items; 4th-time carryover; ~30 min user time)
2. S8-15 user attestation (manual smoke check Batches 1+3; 2nd-time carryover; ~15 min user time)
3. **NEW** Sprint-12 ≥1 Pillar 3 OR Pillar 4 player-facing demonstration (CD-refined; ~1-2d sprint-12 implementation)

**Path to PASS**: Items 1+2 unblock USER-OWNED gates; item 3 closes the experiential validation gap. Combined effort upgrades verdict CONCERNS → PASS, eligible for `production/stage.txt` flip to `Production` at next gate-check.

**Recommended next step**: Sprint-12 plan absorbs item 3 as Must-Have demo target; user attests items 1+2 at convenience. Run `/gate-check pre-prod-to-prod` again at sprint-12 close to re-evaluate.
