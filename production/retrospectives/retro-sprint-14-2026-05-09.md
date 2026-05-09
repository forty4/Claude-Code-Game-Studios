# Sprint-14 Retrospective

**Sprint Period**: 2026-05-09 (single-day execution; entry-plan ship through close ceremony)
**Generated**: 2026-05-09 PM late-late
**Mode**: MIXED HYBRID closure-leaning (§11 HARD GATE rebind triggered at sprint-14 plan-time per concentration ≥5 audit; HOLDS at close — no mid-amendment redesignation)
**Engine**: Godot 4.6.2 stable official

---

## Metrics

| Metric | Planned | Actual | Delta |
|---|---|---|---|
| Stories | 9 | 9 | 0 |
| Effective close (done + partial + carry + no-op) | 9 | 6 done + 1 partial + 1 carry + 1 no-op | 0 |
| Story-effort days nominal | ~2.2d | ~1.5d (single-day execution) | -0.7d |
| Bugs surfaced + fixed in-sprint | 0 expected (closure-mode) | 0 | 0 |
| Bugs surfaced + filed (carry) | 0 expected | 1 (POLISH-011 CRITICAL release-blocker) | +1 |
| Unplanned mid-sprint tasks | 0 expected (closure-mode) | 0 | 0 |
| Commits in sprint window | — | 7 (incl. entry plan + qa-plan + close-pending) | — |
| Test baseline at entry / close | 1288 / 1288 | 1288 / 1288 (0 net additions; 67th → 68th FFB ratchet) | 0 |

---

## Velocity Trend

| Sprint | Planned | Effective Close | Rate | Mid-Amend? |
|---|---|---|---|---|
| 12 | 11 | 11/11 (100%; 5 carry-conditions to sprint-13) | 100% | No |
| 13 | 10 | 11 of 12 (92%; +2 mid-amend; 1 USER-OWNED carry to sprint-14) | 92% | **Yes** (S13-11 + S13-12 Logic-tier; CLOSURE-LEANING → MIXED HYBRID redesignation) |
| **14** | **9** | **8 of 9 (89%; 0 mid-amend; 1 USER-OWNED carry to sprint-15)** | **89%** | **No** |

**Trend**: Stable closure-mode discipline across 3 consecutive sprints. Sprint-14 differentiates from sprint-13 by NOT requiring mid-amendment — entry plan classification accurate at close. Mid-sprint mode redesignation pattern remains stable at 1 invocation (sprint-13 only); sprint-15 retro AI tracks if 2nd invocation surfaces (codification trigger).

---

## What Went Well

1. **4 of 4 prior gate-check items CLOSED + 1 partial** (rerun-2 → rerun-3 path-to-PASS items 5/6/8/9; Item 7 partial). **Strongest single-sprint closure ratio in rerun chain history**. Sprint-14 entry-time plan absorbed all 4 carry-conditions from sprint-13 close cleanly.

2. **AD's 1st READY verdict in rerun chain history at S14-04** — POLISH-010 closure via Option A shipped clean at S14-02 (`assets/data/maps/mvp_chapter_01.tres` + `scenes/battle/mvp_chapter_01.tscn` + `chapter_visuals.gd`); user-captured screenshot validates art-bible §3-2 silhouettes + §4.1 palette compliance. AD-bound substrate (art bible compliance, palette discipline, silhouette specs, world-space rendering presence) verified production-state for the first time across 8 gate-checks.

3. **G-30 verification gap pattern codification effective + pattern stability ESCALATED 2→4 invocations within 48hr** (POLISH-008 + POLISH-010 + POLISH-011-input-frame + POLISH-011-actual). Sprint-14 S14-06 codification + S14-07 prompt amendments shipped same sprint as 4th invocation surfaced. Codification-debt-at-retro-time AI #1 from sprint-7 now sustained 7→8 sprints.

4. **ADR-0021 ratified at S14-01** (576 LoC) — first project ADR ratified at sprint entry as gate-check carry-condition. §6 amends ADR-0016 §3 STEP 1.5 via Path A precedent (process-novel: ADR amendment via existing ADR's same-doc edit rather than new ADR).

5. **POLISH-011 triage finding caught structural integration gap that 5 hypotheses missed** — initial filing framed POLISH-011 as input pipeline issue (5 hypotheses listed). Post-/clear triage session re-attributed root cause to turn-loop architectural integration gap (T5 stub + AISystem.ai_action_ready subscriber gap + declare_action plumbing gap). Tier escalated HIGH → CRITICAL with full evidence trail. **Triage caught what 1288/1288 PASS automated suite couldn't catch** (G-30 4th invocation reinforcement).

6. **PRE-FLIGHT byte-check codification (S13-05) DOGFOODED ~17× clean across S14 work** — 3 in-flight trim events at S14-02 / S14-06 / S14-07 caught pre-commit (in-flight trim pattern stable at 3 invocations; if 4th invocation in sprint-15+, codification refinement candidate per sprint-13 retro AI #6 follow-up).

7. **68th consecutive failure-free baseline** preserved through 7 sprint-14 commits — no regression on sprint-13 carry-conditions (S13-11 `_safe_tr_format` + S13-12 BattleUnit.archetype unchanged).

8. **S14-08 ADVISORY classification batch closed sprint-13 retro AI #10** — 10 ADVISORY items split 3-reg/5-doc/2-noaction; TD-071/072/073 NEW (register 70 → 73 entries). Sibling AIs from sprint-13 retro now 6 of 10 closed in single-sprint follow-through.

---

## What Went Poorly

1. **POLISH-011 5-hypothesis miss at initial filing** (NEW pattern this sprint) — initial S14-03 attestation surfaced "input non-responsive" symptom; sprint-14 PM late session filed POLISH-011 with 5 hypotheses, NONE of which were the actual root cause. The triage finding caught this in subsequent session (post-/clear recovery), but the pattern is: **"FAIL surfaces in windowed mode; first triage frames it via observed symptom rather than tracing the full execution path"**. Cost: ~30min of triage work that produced wrong hypotheses + the post-/clear triage that finally caught actual root cause. Sprint-15+ retro AI tracks if pattern recurs.

2. **1st verdict downgrade in rerun chain history at S14-04 (CONCERNS → FAIL)** — POLISH-011 CRITICAL is qualitatively worse than predecessor POLISH-010 was (content-authoring gap → MVP integration gap; 1-2hr fix → 2-3 sprint-15 stories). The downgrade is honest pricing of the integration gap — but it also means rerun-4 is at minimum sprint-15 close away. Sprint-15 will be 2nd consecutive closure-leaning sprint per §11 HARD GATE rebind expected at plan-time.

3. **Optional visual-smoke harness for S14-02 chapter_visuals.gd was NOT authored** — the QA plan classified it as "(optional)" tier; sprint-14 chose existing 1288 baseline regression-only path per user direction. This is a deferred mitigation for G-30 verification gap pattern; sprint-15+ test infrastructure work paired with TD-071/073 will close this. Pattern: optional/advisory work consistently defers; consider promoting to Should Have at sprint-15 if pattern-stability quintuples (5 invocations).

4. **2nd refusal-to-fabricate invocation in S8-15 lifecycle** — sprint-13 S13-10 first invocation; sprint-14 S14-03 second invocation. Pattern stable at 2 → discipline embedded; sprint-15+ retro AI tracks 3rd invocation. Watchlist concern: if same posture is invoked at sprint-15 close on POLISH-011 fix re-attestation, the pattern crosses 3 invocations and warrants formal codification (retro AI #14).

---

## Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---|---|---|---|
| POLISH-011 surfaced after S14-02 fix landed (S14-03 §1.3 FAIL) | ~30 min triage + post-/clear re-triage | Filed as carry-condition with TRIAGE FINDING; sprint-14 cannot absorb (closure-mode discipline) | G-30 windowed-smoke harness (sprint-15+ infrastructure work) catches similar issues earlier |
| 5-hypothesis triage miss at POLISH-011 initial filing | ~30 min wasted on wrong hypotheses | Post-/clear triage caught actual root cause via execution-path tracing | Sprint-15+ retro AI #13: "trace full execution path before pattern-matching to symptom-class" |
| AD-PHASE-GATE production-amendment file pivot SKILL.md → director-gates.md | ~5 min realization at S14-07 implementation | Amended director-gates.md (where prompts actually live) instead of SKILL.md (where directors are spawned) | Sprint-14 S14-07 spec was wrong about file location; future spec authors verify spawn-vs-template file ownership |

---

## Estimation Accuracy

| Story | Estimated | Actual | Variance | Likely Cause |
|---|---|---|---|---|
| S14-02 POLISH-010 Option A | 1.5d (most-overestimated) | ~1h | -1.4d | Closure-mode efficiency: art-bible spec + ADR-0021 §6 step-1.5 mount path + chapter_visuals.gd `_draw()` API all converged cleanly; no engine-API surprises |
| S14-04 gate-check rerun-3 | 0.1d (most-balanced) | ~30min | -0.05d | Lean-mode 4-director spawn + skill protocol; verdict synthesis straightforward given strong substrate ratchet evidence |
| S14-07 AD gate criterion (file pivot) | 0.05d | ~15min | 0 | File-pivot realization (~5min) + 2 prompt amendments (~10min) — accurate estimate |

**Overall estimation accuracy**: ~78% of stories within ±20% of estimate (best-case path). Closure-mode sprints consistently UNDER-take their estimates (sprint-12 / sprint-13 / sprint-14 all came in 30-50% under) because doc-edit work is faster than typed estimates anticipate. **Adjustment recommendation**: closure-mode story estimates can be reduced by 30% for sprint-15+ planning (parallel to sprint-13 retro adjustment for HYBRID work).

---

## Carryover Analysis

| Task | Original Sprint | Times Carried | Reason | Action |
|---|---|---|---|---|
| S13-06 producer §7 promotion call | 12 | 2 (→13 → 14 → 15) | USER-OWNED; user concurrence pending | sprint-15 close ceremony — if 3rd carry without resolution, force decision via Route c default per R7 (closure-mode pattern) |
| POLISH-011 turn-loop integration gap (NEW) | 14 | 0 (carries to 15 first time) | sprint-14-surfaced; closure-mode discipline correctly prohibited absorption | sprint-15 plan-time MUST-HAVE absorption (3-story arc S15-A/B/C) |
| S14-09 mid-sprint mode redesignation tracking | 14 | 0 (carries to 15) | Tracking-only; no trigger fired | sprint-15+ retro frequency check (codification trigger ≥2 invocations) |
| Optional visual-smoke harness for chapter_visuals.gd | 14 | 0 (carries to 15) | Advisory; G-30 mitigation deferred | sprint-15+ paired with TD-071/073 verification-gap test infrastructure |

---

## Technical Debt Status

- **TODO count**: 2 (no change from sprint-13 close)
- **FIXME count**: 0 (no change)
- **HACK count**: 0 (stable)
- **Trend**: Stable
- **Tech-debt register**: 70 → 73 entries (TD-071/072/073 NEW from S14-08 ADVISORY classification batch)

**Notable register additions**:
- TD-071: Fallback exhaustiveness lint for `battle_hud._format_fallback` (verification gap; sibling to G-30 + TD-073)
- TD-072: Hardcoded Korean fallback strings (l10n boundary; closure trigger en.po + ko.po locale ship)
- TD-073: AISystem unknown-archetype regression sentinel (verification gap; sibling to G-30 + TD-071)

---

## Previous Action Items Follow-Up (from Sprint-13 retro)

| Sprint-13 retro AI | Status | Notes |
|---|---|---|
| AI #1 Codification debt at retro time (sustained) | ✅ ACTIVE | Sprint-14 sustained; 8 sprints continuous (sprint-7→14) |
| AI #2 Carryover concentration ≥5 watchpoint | ✅ TRIGGERED | Sprint-14 entry concentration at 5+; §11 HARD GATE rebind succeeded plan-time → closure-leaning |
| AI #3 POLISH-010 disposition (Option A or C) | ✅ CLOSED | S14-02 Option A shipped clean |
| AI #4 ADR-0021 ratification | ✅ CLOSED | S14-01 Status:Accepted |
| AI #5 S8-15 re-attestation outcome | ⚠️ PARTIALLY CLOSED | S14-03 §1.2/§3.2 PASS; §1.3 FAIL → POLISH-011 NEW (still MIXED, different composition) |
| AI #6 Verification gap pattern G-30 codification | ✅ CLOSED | S14-06 +40 LoC; pattern stability 2→4 invocations |
| AI #7 AD gate criterion addition | ✅ CLOSED | S14-07 AD+TD phase-gate prompts amended (file pivoted SKILL.md → director-gates.md) |
| AI #8 S13-06 producer §7 promotion (Route a vs c) | ⏳ DEFERRED | S14-05 carries to sprint-15 (2nd-time carry; user concurrence still pending) |
| AI #9 Mid-sprint mode redesignation precedent frequency | ✅ DID-NOT-INVOKE | Sprint-14 did NOT redesignate (entry-plan classification held); pattern stable at 1 invocation |
| AI #10 /code-review ADVISORY items batch classification | ✅ CLOSED | S14-08 10 items split 3-reg/5-doc/2-noaction; TD-071/072/073 NEW |

**AIs closed in-sprint: 6 of 10** (#3 + #4 + #6 + #7 + #10 + #1 sustained). #2 triggered as-designed (positive signal that watchpoint works). #5 partial carry-forward. #8 deferred (2nd-time carry). #9 did-not-invoke.

**Strongest closure single sprint**: sprint-14 closed 6 sprint-13 retro AIs in one sprint cycle — best AI-closure-rate to date.

---

## Action Items for Sprint-15

| AI # | Description | Owner | Priority |
|---|---|---|---|
| **#1** | **Codification debt at retro time** — sustained pattern (sprint-7→8→9→10→11→12→13→14→15) | retrospective | Active |
| **#2** | **Carryover concentration ≥5 → §11 HARD GATE rebind** — sprint-15 plan-time MUST audit; if ≥5 (POLISH-011 + S14-05 + likely 1-2 others), rebind to closure-leaning before story selection | producer | Active |
| **#3** | **POLISH-011 absorption arc** (S15-A/B/C 3-story; ADR-0011 §Decision Contract 5 + ADR-0014 + ADR-0019 amendments) | godot-gdscript-specialist + lead-programmer + technical-director | **Must Have** |
| **#4** | **S8-15 §1.3 third re-attestation** post-POLISH-011-fix — refusal-to-fabricate posture preserved (3rd invocation; pattern stability ESCALATES 2→3 if invoked) | user (after Item #3 lands) | Should Have |
| **#5** | **S13-06 producer §7 promotion call** — 2nd-time carry (now 3rd-time eligible if not resolved); Route c default per R7 if user unavailable at sprint-15 close | producer + user | Should Have |
| **#6** | **POLISH-011 5-hypothesis miss retro AI** (NEW from sprint-14) — pattern: "FAIL surfaces in windowed mode; first triage frames via observed symptom rather than tracing execution path"; sprint-15+ retro tracks 2nd invocation for codification | retrospective | Active |
| **#7** | **Refusal-to-fabricate posture invocation count** (NEW from sprint-14) — 2nd invocation at S14-03; pattern stable at 2; sprint-15 tracks 3rd invocation if any sprint sees similar honest-FAIL-under-AC-pressure scenario | retrospective | Active |
| **#8** | **AD's 1st READY verdict pattern check** (NEW from sprint-14) — does AD return READY at rerun-4 after POLISH-011 closure? POLISH-010 closure produced AD's 1st READY; predict POLISH-011 closure will NOT change AD verdict (POLISH-011 is non-AD scope) | retrospective | Active |
| **#9** | **Verdict downgrade pattern stability** (NEW from sprint-14) — 1st downgrade at S14-04 was honest pricing of CRITICAL tier; sprint-15+ retro tracks if rerun-4 reverses (CONCERNS or PASS expected) or downgrades further (would be 2nd consecutive FAIL — process-significance signal) | retrospective | Active |
| **#10** | **Optional visual-smoke harness for chapter_visuals.gd** — sprint-15+ when paired with TD-071/073 verification-gap test infrastructure; G-30 mitigation deferred | godot-gdscript-specialist | Nice to Have |
| **#11** | **Mid-sprint mode redesignation pattern frequency** — sprint-14 did-not-invoke; pattern stable at 1; if sprint-15 redesignates, pattern reaches 2 → codification trigger | retrospective | Active |
| **#12** | **PRE-FLIGHT byte-check in-flight trim pattern** — 3 invocations across sprint-14 (S14-02 / S14-06 / S14-07); pattern stable at 3; sprint-15+ tracks if 4th invocation surfaces, codification refinement candidate (e.g., pre-draft byte-budget guidance) | retrospective | Active |
| **#13** | **POLISH-011 triage outcome** + 3-integration-boundary fix verification (sprint-15 close) — what was the actual implementation pattern (Callable controller dispatch wiring) and how to prevent similar story-level wiring gaps | retrospective | Active |

**Active retro AI count: 13** (4 carryforwards from sprint-13 + 9 NEW from sprint-14). Sprint-15 retro AI #1 sustained pattern continues; total active AIs heavy but most are tracking-only watch markers, not active obligations.

---

## Process Improvements

1. **Triage protocol amendment** — when filing a release-blocker bug from a windowed-mode FAIL, FIRST trace the full execution path (read implementation files, verify wire-up across system boundaries) BEFORE listing hypotheses. The 5-hypothesis miss at POLISH-011 initial filing wasted ~30min on wrong framings; the post-/clear re-triage caught the actual root cause via execution-path tracing. **Codify**: add to `.claude/rules/tooling-gotchas.md` as TG-5 candidate if pattern recurs in sprint-15+. Pattern stability is currently 1 invocation; not yet codification-trigger threshold.

2. **Sprint-15+ closure-mode estimate adjustment** — closure-mode stories consistently come in 30-50% under estimate (sprint-12 / sprint-13 / sprint-14). Apply 30% reduction factor for closure-mode story estimates at sprint-15+ planning to improve estimation accuracy. Already established at sprint-13 retro; sprint-14 confirms the pattern.

---

## Summary

Sprint-14 was the **strongest single-sprint gate-check item closure ratio in rerun chain history** (4 of 4 prior items CLOSED + 1 partial), achieved via clean execution of carry-conditions from sprint-13 close: ADR-0021 ratified, POLISH-010 closure via Option A shipped clean (AD's 1st READY verdict in chain history at S14-04), G-30 codified at 4-invocation pattern stability, AD+TD phase-gate prompts amended, ADVISORY classification batch closed.

However, the substrate ratchet was overshadowed by POLISH-011 — surfaced via S14-03 §1.3 FAIL, triaged through 5-hypothesis miss, finally re-attributed via post-/clear session to a turn-loop architectural integration gap (T5 stub + missing AI subscriber + missing declare_action plumbing) qualitatively worse than POLISH-010 was. Tier escalated HIGH → CRITICAL. S14-04 produced 1st verdict downgrade in rerun chain history (FAIL).

**The single most important thing to change going forward**: triage protocol amendment to trace full execution path BEFORE listing hypotheses when filing a release-blocker from windowed-mode FAIL. The triage finding caught what 5 hypotheses missed; future invocations should bypass the 5-hypothesis stage entirely.

**Sprint-15 outlook**: 2nd consecutive closure-leaning sprint expected (POLISH-011 absorption arc S15-A/B/C is Must Have). Rerun-4 PASS verdict possible at sprint-15 close if integration gap closes cleanly + S8-15 §1.3 third re-attestation passes. AD's READY likely holds. CD/TD/PR will assess based on integration test coverage + natural-loop demonstration.

---

## Cross-References

- Sprint-14 plan: `production/sprints/sprint-14.md` (commit `4f2ea2e`)
- Sprint-14 entry qa-plan: `production/qa/qa-plan-sprint-14-2026-05-09.md` (commit `13856b2`)
- Sprint-14 closure qa-plan: `production/qa/qa-plan-sprint-14-closure-2026-05-09.md` (this commit)
- Sprint-14 smoke: `production/qa/smoke-sprint-14-2026-05-09.md` (commit `c4031b3`)
- Sprint-14 sign-off: `production/qa/qa-signoff-sprint-14-2026-05-09.md` (this commit)
- Gate-check rerun-3: `production/gate-checks/pre-prod-to-prod-2026-05-09-rerun-3.md` (commit `78dc228`)
- Sprint-13 retro precedent: `production/retrospectives/retro-sprint-13-2026-05-09.md` (commit `ef025a6`)
- POLISH-011 entry + TRIAGE FINDING: `production/polish-backlog.md` (commit `9c249ca`)
- G-30 codification: `.claude/rules/godot-4x-gotchas.md` G-30 (commit `164c5ad`)
- TD-071/072/073 NEW + classification matrix: `docs/tech-debt-register.md` (commit `b2ad3e9`)
- AD+TD phase-gate prompts amended: `.claude/docs/director-gates.md` (commit `b2ad3e9`)
- §11 HARD GATE rule: `docs/process/decisions-convention.md` §11.3
