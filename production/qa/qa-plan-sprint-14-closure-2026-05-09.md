# QA Plan — Sprint-14 Closure (Addendum to Entry-Time Plan)

> **Date**: 2026-05-09 PM late-late
> **Scope**: Sprint-14 close ceremony — delta from entry-time `production/qa/qa-plan-sprint-14-2026-05-09.md` (9-story 80% non-runtime closure-leaning HYBRID profile authored at sprint-14 entry per `13856b2`).
> **Reason for addendum**: Sprint-14 executed without mid-sprint Logic-tier amendments (entry profile preserved), but mid-session POLISH-011 surfacing + post-/clear triage finding produced a CRITICAL release-blocker carry-condition that materially shifts the rerun-3 path-to-PASS outlook. Entry-plan's "MIXED HYBRID closure-leaning" profile remains accurate at close — 0 net Logic-tier additions.
> **Mode**: sprint-close (parallel to sprint-12 + sprint-13 closure addendum precedents)

---

## Story Classification Table (close-actual)

| ID | Type (entry plan) | Type (close-actual) | Test Evidence | Status |
|---|---|---|---|---|
| S14-01 | Config/Data (rule add) | Config/Data | `docs/architecture/ADR-0021-production-world-space-rendering-responsibility.md` Status:Accepted (576 LoC at `715350c`) | done |
| S14-02 | Visual/UI primary (Option A) OR Config/Data (Option C) | **Visual/UI** (Option A chosen) | `production/qa/evidence/sprint-14-polish-010-evidence.md` (7-section AC mapping) + `sprint-14-polish-010-screenshot.png` (44KB user-captured at `715350c`); `chapter_visuals.gd` NEW (66 LoC `_draw()` tile renderer) — **regression-only via 1288 baseline, NO new automated test added per user direction** | done |
| S14-03 | UI (user-attestation) | UI (user-attestation) | `production/qa/qa-signoff-sprint-8-2026-05-06.md` §S14-03 Re-Attestation (§1.2/§3.2 PASS / §1.3 FAIL → POLISH-011 NEW at `715350c`); 2nd refusal-to-fabricate invocation in S8-15 lifecycle | partial |
| S14-04 | Admin/process | Admin/process | `production/gate-checks/pre-prod-to-prod-2026-05-09-rerun-3.md` verdict **FAIL** (3× NOT READY CD/TD/PR + 1× **READY AD** — 1st READY in rerun chain history; 1st verdict downgrade in chain at `78dc228`) | done |
| S14-05 | Admin/decision | Admin/decision | NOT executed — USER-OWNED carry to sprint-15 (Route a vs Route c retention decision; 2nd-time carry; user concurrence pending) | not-started (carry to sprint-15) |
| S14-06 | Config/Data (rule add) | Config/Data | `.claude/rules/godot-4x-gotchas.md` G-30 entry (+40 LoC at `164c5ad`); pattern stability ESCALATED 2→4 invocations within 48hr (POLISH-008 + POLISH-010 + POLISH-011-input-frame + POLISH-011-actual) | done |
| S14-07 | Config/Data (skill edit) | Config/Data | `.claude/docs/director-gates.md` AD-PHASE-GATE + TD-PHASE-GATE production-gate amendments (file pivoted SKILL.md→director-gates.md; both reference G-30; both return CONCERNS-min if no windowed-smoke harness; commit `b2ad3e9`) | done |
| S14-08 | Admin/classification | Admin/classification | `docs/tech-debt-register.md` TD-071/072/073 NEW entries + S14-08 classification matrix inline (10 ADVISORY items split 3-reg/5-doc/2-noaction at `b2ad3e9`); register 70→73 entries | done |
| S14-09 | Tracking-only | Tracking-only | No-op this sprint (trigger never fired; mid-sprint mode redesignation pattern remains stable at sprint-13 1-invocation baseline) | done (no-op) |

**Summary**: 6 done + 1 partial (S14-03) + 1 not-started (S14-05 USER-OWNED carry) + 1 no-op tracking. **Effective close: 7 of 9 functionally complete; S14-05 carries to sprint-15 close ceremony alongside POLISH-011 absorption arc.**

---

## Closure-Mode Profile Update

**Entry-time profile** (`qa-plan-sprint-14-2026-05-09.md`): "**80% non-runtime closure-mode** — 7 of 9 stories Config/Data + Admin tier (same posture as sprint-13 entry); 1 content-authoring exception (S14-02 Option A path) + 1 user-attestation gate (S14-03)."

**Close-actual profile** (no mid-sprint amendments): **5 Config/Data + 3 Admin + 1 Visual/UI + 1 UI(user-attestation) + 1 Tracking-only = 9 effective stories** (56% Config/Data + 33% Admin + 11% Visual/UI + 11% UI + 11% Tracking — note overlap from multi-classified stories). Profile **HOLDS** at MIXED HYBRID closure-leaning per entry plan; entry classification accurate at close (no mid-amendment redesignation needed unlike sprint-13's CLOSURE-LEANING → MIXED HYBRID precedent).

**Mode redesignation history**:
- 2026-05-09 AM (sprint-14 entry plan): MIXED HYBRID closure-leaning (§11 HARD GATE rebind triggered post-sprint-13-close concentration audit ≥5)
- 2026-05-09 PM late-late (close): MIXED HYBRID closure-leaning **HOLDS** — no redesignation needed
- Pattern stability: sprint-13 mid-sprint mode redesignation precedent remains stable at **1 invocation** (sprint-14 did NOT redesignate); sprint-14 retro AI #14 (mid-sprint mode redesignation precedent frequency tracking) records "did-not-invoke" disposition for sprint-15 retro carryover decision.

---

## Automated Test Requirements

### Test delta breakdown

| Source | Tests added | Tests removed | Net |
|---|---:|---:|---:|
| Sprint-13 close baseline (commit `fa35c8b`) | — | — | 1288 |
| Sprint-14 Logic additions | 0 | 0 | 0 → 1288 |
| Sprint-14 close baseline (commit `c4031b3`) | **0** | **0** | **1288** |

### Test surface status

- **All Logic story tests**: N/A — sprint-14 added zero Logic-tier stories.
- **S14-02 Visual/UI substrate**: regression-only verification via existing 1288 baseline preserved across all sprint-14 commits. No new automated test added (advisory gap captured under G-30 + TD-073 sprint-15+ test infrastructure work).
- **All non-Logic stories**: EXPECTED (Admin / Config-Data / Tracking-only / User-attestation tiers — no automated test required).
- **68th consecutive failure-free baseline (FFB)** preserved through 6 commits this sprint window: `715350c` → `9c249ca` → `164c5ad` → `b2ad3e9` → `78dc228` → `c4031b3` (current). 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans across all runs.

---

## Manual QA Checklist (close-actual outcomes)

### S14-02 — POLISH-010 Option A (visual rendering)

**Verification method**: windowed boot + visual evidence screenshot (entry plan)
**Sign-off**: art-director (visual identity alignment per art bible) + user (S14-03 §1.2 re-attestation)
**Outcome**: ✅ **PASS** — user-captured screenshot validates art-bible §3-2 silhouettes + §4.1 palette compliance (zero reserved-color violations); AD's 1st READY verdict in rerun chain history at S14-04 confirms substrate.

### S14-03 — S8-15 §1.2/1.3/3.2 re-attestation

**Verification method**: user re-runs Batches 1+3 against post-S14-02 build (entry plan)
**Sign-off**: user (refusal-to-fabricate posture preserved)
**Outcome**: ⚠️ **PARTIAL** — §1.2 (visual rendering) + §3.2 (no frame drops) MIXED → PASS; §1.3 (input responsive) FAIL → POLISH-011 NEW filed. MIXED status retained (different composition than original S13-10 MIXED). 2nd refusal-to-fabricate invocation in S8-15 lifecycle.

### S14-04 — /gate-check pre-prod-to-prod rerun-3

**Verification method**: 4-director panel parallel review (lean mode) (entry plan)
**Sign-off**: claude (skill protocol) + user (verdict acknowledgement)
**Outcome**: ❌ **FAIL** verdict (1st downgrade in chain history). Director panel: CD/TD/PR NOT READY + AD READY (1st in chain). Sole blocker: POLISH-011 CRITICAL turn-loop integration gap — 2-3 sprint-15 stories spanning ADR-0011/0014/0019 amendments.

### S14-05 — S13-06 producer §7 promotion call

**Verification method**: producer paper + user concurrence (entry plan)
**Sign-off**: user (Route a vs Route c retention decision)
**Outcome**: 🟡 **NOT-STARTED** — USER-OWNED; 2nd-time carry to sprint-15 close ceremony (1st-time carry was sprint-13 → sprint-14).

---

## Smoke Test Scope (close-actual)

Already executed at `c4031b3` (commit 2026-05-09 PM late-late) — verdict **PASS WITH WARNINGS**.

3 documented warnings carried forward:
1. POLISH-011 CRITICAL release-blocker (sprint-15 absorption mandatory)
2. Optional visual-smoke harness not authored (G-30 mitigation deferred)
3. S14-04 gate-check rerun-3 verdict FAIL (1st downgrade in chain)

Smoke artifact: `production/qa/smoke-sprint-14-2026-05-09.md`

---

## Playtest Requirements

**No playtest sessions required for sprint-14** — closure-mode + doc-edit heavy sprint. Sprint-15 POLISH-011 absorption arc will require a natural-loop integration test (non-seam) driving full battle to non-DRAW resolution as specified in rerun-3 path-to-PASS Item 10 §3 — that's automated regression coverage, not playtest tier.

POLISH-011 user re-attestation (S8-15 §1.3 third invocation post-fix) will be required at sprint-15 close — refusal-to-fabricate posture preserved; would be 3rd invocation; pattern stability ESCALATES 2→3.

---

## Definition of Done — Sprint-14

A story is DONE when ALL of the following are true:

- [x] All acceptance criteria verified — via automated test result OR documented manual evidence
- [x] Test file exists at the specified path for all Logic and Integration stories — N/A (zero Logic/Integration stories this sprint)
- [x] Manual evidence document exists for all Visual/Feel and UI stories — S14-02 evidence + S14-03 attestation captured
- [x] Smoke check passes — `c4031b3` PASS WITH WARNINGS at sprint-close
- [x] No regressions introduced — 1288/1288 / 68th FFB preserved
- [x] Code reviewed (via `/code-review` or documented peer review) — sprint-14 work was 80% doc edits; S14-02 chapter_visuals.gd reviewed inline at write time
- [ ] Story file updated to `Status: Complete` (via `/story-done`) — sprint-14 stories tracked via sprint-status.yaml flips rather than per-story `/story-done` invocations (closure-mode pattern; same as sprint-13)

**Sprint-14 carry-conditions to sprint-15** (formal):
1. **POLISH-011 CRITICAL release-blocker** (T5 stub + AISystem.ai_action_ready subscriber + declare_action plumbing) — 3-story absorption arc S15-A/B/C
2. **S14-05 producer §7 promotion call** — 2nd-time carry; user concurrence still pending
3. **S14-09 mid-sprint mode redesignation tracking** — backlog (no-op carry; pattern stability monitor)
4. **Optional visual-smoke harness for S14-02 chapter_visuals.gd** — advisory; G-30 mitigation deferred to sprint-15+ test infrastructure work paired with TD-071/073

---

## Cross-References

- Entry-time qa-plan: `production/qa/qa-plan-sprint-14-2026-05-09.md` (commit `13856b2`)
- Smoke artifact: `production/qa/smoke-sprint-14-2026-05-09.md` (commit `c4031b3`)
- Sprint-14 plan: `production/sprints/sprint-14.md` (commit `4f2ea2e`)
- Gate-check rerun-3: `production/gate-checks/pre-prod-to-prod-2026-05-09-rerun-3.md` (commit `78dc228`)
- POLISH-011 entry + TRIAGE FINDING: `production/polish-backlog.md` (commit `9c249ca`)
- G-30 codification: `.claude/rules/godot-4x-gotchas.md` G-30 (commit `164c5ad`)
- TD-071/072/073 NEW + classification matrix: `docs/tech-debt-register.md` (commit `b2ad3e9`)
- Sibling closure addendum precedents: `production/qa/qa-plan-sprint-13-closure-2026-05-09.md` + `production/qa/qa-plan-sprint-12-closure-2026-05-09.md`
