# QA Sign-off — Sprint-14 (Close-Out Attestation)

> **Date**: 2026-05-09 PM late-late
> **Sprint**: 14 (MIXED HYBRID closure-leaning per §11 HARD GATE rebind at sprint-14 plan-time; profile HOLDS at close — no mid-amendment redesignation needed)
> **Mode**: attestation-mode (closure-mode posture; user-time gates + auto-verification SUBSUME fresh manual batches per sprint-12 + sprint-13 precedents)
> **Engine**: Godot 4.6.2 stable official
> **Effective story count**: 9 (no mid-amendment Logic-tier additions; entry-plan classification accurate at close)

---

## Test Coverage Summary

| Story | Type | Test File / Evidence | Status |
|---|---|---|---|
| S14-01 | Config/Data (rule add) | `docs/architecture/ADR-0021-production-world-space-rendering-responsibility.md` Status:Accepted (576 LoC) | done |
| S14-02 | Visual/UI (Option A) | `production/qa/evidence/sprint-14-polish-010-evidence.md` + `sprint-14-polish-010-screenshot.png` (44KB user-captured); `chapter_visuals.gd` NEW (66 LoC `_draw()` tile renderer) | done |
| S14-03 | UI (user-attestation) | `qa-signoff-sprint-8-2026-05-06.md` §S14-03 Re-Attestation (§1.2/§3.2 PASS / §1.3 FAIL → POLISH-011) | partial |
| S14-04 | Admin (gate-check rerun-3) | `production/gate-checks/pre-prod-to-prod-2026-05-09-rerun-3.md` (FAIL) | done |
| S14-05 | Admin/decision | PENDING user concurrence (Route a vs Route c; 2nd-time carry) | not-started (carry-to-sprint-15) |
| S14-06 | Config/Data (rule add) | `.claude/rules/godot-4x-gotchas.md` G-30 entry (+40 LoC; 4-invocation pattern stability) | done |
| S14-07 | Config/Data (skill edit) | `.claude/docs/director-gates.md` AD-PHASE-GATE + TD-PHASE-GATE production-gate amendments | done |
| S14-08 | Admin/classification | `docs/tech-debt-register.md` TD-071/072/073 NEW + S14-08 classification matrix (10 ADVISORY items split 3-reg/5-doc/2-noaction) | done |
| S14-09 | Tracking-only | No-op this sprint (mid-sprint mode redesignation pattern remains stable at 1 invocation) | done (no-op) |

**Effective close**: 7 of 9 functionally complete + 1 partial (S14-03) + 1 carry (S14-05).
**Test baseline**: 1288 → **1288** (0 net additions; sprint-14 was Visual/UI + doc-edit work, no Logic-tier additions); **68th consecutive FFB preserved** through 6 sprint-14 commits + 1 sprint-close commit.

---

## Bugs Found (this sprint)

### Surfaced + Fixed (mid-sprint absorption)

**None this sprint** — sprint-14 was closure-mode + doc-edit heavy; no Logic-tier mid-amendments unlike sprint-13's S13-11/12 absorption pattern.

### Surfaced + Filed (deferred; sprint-15 work)

| Bug / gap | POLISH-ID | Tier | Disposition |
|---|---|---|---|
| **Production main_scene battle loop cannot complete naturally; auto-fast-forwards to DRAW in 2-3 seconds** | **POLISH-011** | **DEFECT CRITICAL (release-blocker; ESCALATED HIGH→CRITICAL via triage finding)** | **Carry to sprint-15 — 3-story absorption arc S15-A/B/C spanning ADR-0011/0014/0019 amendments; ~10-15h** |

POLISH-011 originally filed as HIGH-tier "input non-responsive" at S14-03 §1.3 FAIL surfacing. **Post-/clear triage finding** (sprint-14 PM late-late session) re-attributed root cause from input pipeline to turn-loop architectural integration gap (3 unwired integration boundaries: T5 stub + AISystem.ai_action_ready subscriber + declare_action plumbing). Tier escalated HIGH → CRITICAL.

### Surfaced via S14-08 ADVISORY classification — sprint-13 carry-forward

10 ADVISORY items from S13-11 + S13-12 /code-review reports classified at S14-08 (sprint-13 retro AI #10 closure):
- 3 → tech-debt-register: TD-071 (fallback exhaustiveness lint) + TD-072 (Korean hardcoded fallback strings) + TD-073 (AISystem unknown-archetype regression sentinel)
- 5 → documentation-polish (in-place fix at next file touch)
- 2 → test-polish (no-action minor refactors)

---

## ADVISORY Deferrals (carry forward to sprint-15)

| # | Item | Tier | Sprint-15 disposition |
|---|---|---|---|
| 10 | POLISH-011 turn-loop integration gap (3-story arc S15-A/B/C) | **CRITICAL (release-blocker)** | sprint-15 plan-time MUST-HAVE absorption |
| — | S14-05 S13-06 producer §7 promotion call | MEDIUM | sprint-15 close ceremony (2nd-time carry; user concurrence still pending) |
| — | S14-09 Mid-sprint mode redesignation tracking | MONITOR | sprint-15+ retro tracking (pattern remains stable at 1 invocation; codification trigger ≥2) |
| — | Optional visual-smoke harness for chapter_visuals.gd (S14-02 substrate) | ADVISORY | sprint-15+ when paired with TD-071/073 verification-gap test infrastructure |
| — | TD-071 + TD-072 + TD-073 NEW (S14-08 classification) | LOW-MEDIUM | sprint-15+ as forcing functions fire |
| — | POLISH-007 + POLISH-008 (sprint-13 carry; ADVISORY tier) | LOW-DEFECT | sprint-15+ as forcing functions fire |

---

## Verdict: **APPROVED WITH CONDITIONS** ⚠️

**Verdict rationale**:
- All claude-doable stories DONE (6 of 6 + 1 partial; S14-05 USER-OWNED carry; S14-09 no-op tracking)
- Substrate ratchet on prior gate-check items strongly positive: 4 of 4 prior path-to-PASS items CLOSED (rerun-2 → rerun-3) — strongest single-sprint closure ratio in rerun chain history
- AD's 1st READY verdict in rerun chain history (POLISH-010 closure via Option A shipped clean at S14-02)
- Automated tests 1288/1288 PASS / 68th FFB preserved through entire sprint window (67th → 68th ratchet at sprint-close re-verification)
- No new automated test additions (sprint-14 was Visual/UI + doc-edit work; advisory visual-smoke harness gap captured under G-30 + TD-073 sprint-15+ test infrastructure)
- POLISH-011 CRITICAL release-blocker is sprint-14-surfaced-but-sprint-14-cannot-absorb (closure-mode discipline correctly prohibited absorption); 3-story arc S15-A/B/C Must Have at sprint-15 plan-time
- S14-04 /gate-check rerun-3 verdict FAIL (1st downgrade in chain history) is honest pricing of POLISH-011 CRITICAL — the gate is doing its job
- Sprint-14 substantive PASS at logic-tier despite POLISH-011 release-blocker because POLISH-011 is MVP integration gap surfaced by the sprint, NOT introduced by the sprint

**Conditions** (carry-conditions to sprint-15; do NOT block sprint-14 close):
1. **POLISH-011 absorption arc S15-A/B/C** (turn-loop integration gap closure) — gates `/gate-check pre-prod-to-prod` rerun-4 PASS verdict + `production/stage.txt` Pre-Production → Production flip
2. **S14-05 S13-06 producer §7 promotion call** — 2nd-time carry; user concurrence pending
3. **Optional visual-smoke harness for S14-02 chapter_visuals.gd** — G-30 mitigation deferred to sprint-15+ test infrastructure work paired with TD-071/073
4. **Sprint-15 carryover concentration audit at plan-time** — POLISH-011 (3 stories) + S14-05 + S14-09 + likely 1-2 others = ≥5 expected → §11 HARD GATE rebind expected (2nd consecutive closure-leaning sprint)
5. **S14-09 mid-sprint mode redesignation tracking** — sprint-15+ retro pattern frequency check (codification trigger ≥2 invocations; sprint-14 did NOT redesignate; pattern stable at 1 invocation)

**Mirroring sprint-13 close pattern**: sprint-13 closed APPROVED WITH CONDITIONS with POLISH-010 + ADR-0021 + S8-15 re-attestation + S13-06 → sprint-14 carry. Sprint-14 closes APPROVED WITH CONDITIONS with POLISH-011 + S14-05 → sprint-15 carry. Pattern stable across 2 consecutive closure-leaning sprints.

---

## Sprint-14 Close Gate Notes

**Strongest positive trajectory signals**:

1. **4 of 4 prior gate-check items CLOSED** (rerun-2 → rerun-3 path-to-PASS items 5/6/8/9; Item 7 partial) — **strongest single-sprint closure ratio in rerun chain history**.
2. **AD's 1st READY verdict in rerun chain history** — POLISH-010 closure via Option A shipped clean at S14-02; AD-bound substrate (art bible compliance, palette discipline, silhouette specs, world-space rendering presence) verified production-state.
3. **G-30 verification gap pattern codification effective** — pattern stability ESCALATED 2→4 invocations within 48hr (POLISH-008 + POLISH-010 + POLISH-011-input-frame + POLISH-011-actual). S14-06 codification + S14-07 prompt amendments shipped same sprint as 4th invocation surfaced.
4. **ADR-0021 ratified at S14-01** — 576 LoC; first project ADR ratified at sprint entry as gate-check carry-condition; §6 amends ADR-0016 §3 STEP 1.5 via Path A precedent.
5. **S14-08 ADVISORY classification batch closed** — sprint-13 retro AI #10 closure; 10 items split 3-reg/5-doc/2-noaction; TD-071/072/073 NEW (register 70→73 entries).
6. **68th consecutive failure-free baseline** — preserved through 7 commits this sprint window (`715350c` → `9c249ca` → `164c5ad` → `b2ad3e9` → `78dc228` → `c4031b3` → close commit). 67th → 68th ratchet at sprint-close re-verification.
7. **PRE-FLIGHT byte-check codification dogfood ~17× clean** — codification stable across S14 work; 3 in-flight trim events (S14-02 / S14-06 / S14-07) caught pre-commit; pattern of "in-flight trim during draft" stable at 3 invocations (sprint-14 retro AI candidate if 4th invocation in sprint-15+).

**Negative signals**:
1. **1st verdict downgrade in rerun chain history** — S14-04 FAIL (vs prior 7 reruns all CONCERNS). Honest pricing of POLISH-011 CRITICAL.
2. **POLISH-011 CRITICAL is qualitatively worse than predecessor POLISH-010 was** — content-authoring gap → MVP integration gap; 1-2hr fix → 2-3 sprint-15 stories.
3. **POLISH-011 5-hypothesis miss at initial filing** — initial triage framed it via observed symptom (input); actual root cause was none of the 5 listed hypotheses. Sprint-14 retro AI #13 candidate.
4. **2nd refusal-to-fabricate invocation in S8-15 lifecycle** — sprint-13 S13-10 + sprint-14 S14-03; pattern stable at 2 → discipline embedded; sprint-14 retro AI #14 (pattern stability check at sprint-15).

**Hygiene streak**: 50+ in-patch sprint-status closes (project-record continuing); sprint-14 close commit will extend to ~57+ assuming all 9 sprint-14 stories close in-patch.

---

## Next Step

Run `/retrospective sprint-14` to author `production/retrospectives/retro-sprint-14-2026-05-09.md`. Required topics (per gate-check rerun-3 + qa-plan-closure recommendations):

1. **4-of-4 gate-check items CLOSED** — strongest single-sprint closure ratio; what enabled it (sprint-14 plan structure / closure-mode discipline / etc.)
2. **AD's 1st READY verdict** — what was the AD-bound substrate progression that finally crossed the threshold
3. **POLISH-011 5-hypothesis miss + triage outcome** (NEW retro AI #13) — initial framing was input-frame; actual root cause was turn-loop integration gap; what was the actual cause + how to prevent
4. **G-30 codification effective + 2→4 invocation escalation within 48hr** — measure effectiveness; pattern stability quadrupled in single sprint
5. **Refusal-to-fabricate posture 2nd invocation in S8-15** (NEW retro AI #14) — pattern stable at 2 → discipline embedded; sprint-15+ AI tracks 3rd invocation
6. **1st verdict downgrade in rerun chain history** — honest pricing of CRITICAL tier; gate doing its job
7. **PRE-FLIGHT byte-check 17× clean dogfood + 3 in-flight trim events** — codification effective at S13-05 root-cause closure
8. **S14-08 ADVISORY classification batch outcome** — sprint-13 retro AI #10 closure; 10 items disposed (TD-071/072/073)
9. **Mid-sprint mode redesignation pattern remains stable at 1 invocation** — sprint-14 did NOT redesignate; sprint-15+ retro frequency check
10. **S14-05 S13-06 producer §7 promotion call** — 2nd-time carry to sprint-15

After retro, sprint-14 close commit + push + sprint-status-history.md archive.

---

## Cross-references

- Smoke check: `production/qa/smoke-sprint-14-2026-05-09.md` (commit `c4031b3`)
- QA-plan closure addendum: `production/qa/qa-plan-sprint-14-closure-2026-05-09.md` (this commit)
- Gate-check rerun-3: `production/gate-checks/pre-prod-to-prod-2026-05-09-rerun-3.md` (commit `78dc228`)
- Sprint-13 close precedent: `production/qa/qa-signoff-sprint-13-2026-05-09.md` (commit `ef025a6`)
- POLISH-011 entry + TRIAGE FINDING: `production/polish-backlog.md` (commit `9c249ca`)
- §11 HARD GATE rule: `docs/process/decisions-convention.md` §11.3
- G-30 codification: `.claude/rules/godot-4x-gotchas.md` G-30 (commit `164c5ad`)
- TD-071/072/073 NEW + classification matrix: `docs/tech-debt-register.md` (commit `b2ad3e9`)
- AD+TD phase-gate prompts amended: `.claude/docs/director-gates.md` (commit `b2ad3e9`)
- Closure-mode pattern: `production/decisions/closure-mode-sprint-pattern-2026-05-09.md`
