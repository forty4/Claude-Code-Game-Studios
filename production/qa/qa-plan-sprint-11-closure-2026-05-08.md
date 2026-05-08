# QA Plan — Sprint-11 Closure

**Date**: 2026-05-08
**Sprint**: sprint-11 (Must 4/4 ✓ + Should 4/4 ✓ + Nice-claude 3/3 ✓ = 11/11 claude-owned ✓; commits `b1e10a0` → `045ce98` + smoke `6cbc8c9` final close)
**Scope**: closure-mode QA plan covering all 11 claude-owned sprint-11 stories
**Mode**: lean (`production/review-mode.txt` = `lean`)
**Smoke**: PASS — `production/qa/smoke-sprint-11-2026-05-08.md` (1236/1236; 52nd FFB)
**Filename naming**: per `.claude/skills/team-qa/SKILL.md` Phase 3 (codified S11-10 2026-05-08) — sprint-close gates use `qa-plan-sprint-[N]-closure-[date].md`

---

This is a **doc-only sprint closure addendum**. Sprint-11 was deliberately structured as a 100% closure/admin sprint — every claude-owned story produced documentation, process codification, epic skeletons, or skill-doc edits. **Zero `.gd` code was modified across all 11 stories.** No new automated tests were added (count stayed 1236 → 1236). No manual gameplay QA is required.

The QA plan is therefore slim — the document classification table is the load-bearing element; everything else is degenerate (no automated test obligations to verify; no manual QA sessions to run; no per-story evidence docs to author).

---

## Story Classification Table

All 11 claude-owned stories classified Config/Data per the project's coverage matrix in `CLAUDE.md` Coding Standards §Test Evidence by Story Type. Smoke check confirmed all 11 EXPECTED, 0 MISSING.

| Story | Type | Output artifact (NEW or EDIT) | Automated Required | Manual Required | Blocker? |
|---|---|---|---|---|---|
| **S11-01** — /story-readiness BACKFILL CLOSE-OUT verdict + S10-11 sprint-plan template bundle | Config/Data (skill-doc edit) | EDIT `.claude/skills/story-readiness/SKILL.md` Phase 2.5/4/5/6 + `.claude/skills/sprint-plan/` Carryover Backlog template | N/A — skill-doc change; verified by 2nd-invocation usage at S11-02 (live use 2026-05-07) | N/A — pattern-stability validation: pattern stable at 4 invocations as of S11-02 close | NONE |
| **S11-02** — destiny-branch + ai-system epic graduation backfill | Config/Data (epic Status flip) | EDIT `production/epics/destiny-branch/EPIC.md` + `production/epics/ai-system/EPIC.md` + `production/epics/index.md` rows | N/A — doc-only Status flip; original work shipped sprint-7 S7-03 + S7-04 (already PASSING in 1236 baseline) | N/A — pattern stability: 3rd + 4th activation of sprint-10 retro AI #3 confirmed | NONE |
| **S11-03** — /story-done Phase 7 audit + lint_story_status_consistency.sh | Config/Data (skill-doc + new lint) | EDIT `.claude/skills/story-done/SKILL.md` Phase 7 step 5+6+7 + NEW `tools/ci/lint_story_status_consistency.sh` + NEW `production/process-audits/story-done-phase-7-audit-2026-05-08.md` (NEW directory's first artifact) | PASS — new lint at `tools/ci/lint_story_status_consistency.sh` runs Exit 1 on existing 33 drift items (sprint-12 bulk cleanup target); Exit 0 expected after cleanup | N/A — process audit + CI gate; no manual session required | NONE |
| **S11-04** — Carryover absorption sweep | Config/Data (sprint-status verification) | EDIT `production/sprint-status.yaml` (verification reflects sprint-10 retro AI #5 dispositions: 2 CUT + 1 BUNDLE + 1 DESCOPE + 3 KEEP + 2 USER carry) | N/A — verification-only, no impl | N/A | NONE |
| **S11-05** — production/decisions/ convention codification (Route c) | Config/Data (process doc + skill-scope-guard) | NEW `docs/process/decisions-convention.md` (10-section + filename pattern + trigger discipline + Route-a ≥3-artifact promotion) + EDIT `.claude/skills/architecture-decision/SKILL.md` (ADR-vs-process scope guard) | N/A — process doc | N/A — pattern-stability check: only 1 artifact precedent (ci-lane-gap); promotion trigger = ≥3 artifacts | NONE |
| **S11-06** — production/polish-backlog.md | Config/Data (Polish-tier ledger) | NEW `production/polish-backlog.md` (POLISH-001..005 from battle-hud verification summary §ADVISORY Deviations) | N/A — ledger-only | N/A — entry format documented; future intake routes via this file | NONE |
| **S11-07** — save-load Core epic creation | Config/Data (epic skeleton + index) | NEW `production/epics/save-load/EPIC.md` (3-story decomposition; TR-save-load-008..020) + EDIT `production/epics/index.md` row | N/A — epic skeleton; no impl shipped this sprint; sprint-12 `/create-stories save-load` pending | N/A — epic skeleton; AC verification pending sprint-12 implementation | NONE |
| **S11-08** — main-menu UX spec stub (closes AD-C6 main-menu side) | Config/Data (UX spec) | NEW `design/ux/main-menu.md` (14-section UX spec stub Intermediate a11y) | N/A — UX spec only | N/A — UX spec stub; AD-C6 main-menu side will close at next gate-check; pause-menu remains open | NONE |
| **S11-09** — 유비 character profile stub (S10-07 descoped 3→1) | Config/Data (art spec) | NEW `design/art/characters/liu-bei.md` (Sections 1-3 silhouette+costume+role-anchor; canonical anchors from heroes.json shu_001_liu_bei) | N/A — art spec only | N/A — art spec stub; AD-C5 will re-rate to "first-stub-shipped partial state" at next gate-check | NONE |
| **S11-10** — sprint-close filename naming convention | Config/Data (skill-doc edit) | EDIT `.claude/skills/smoke-check/SKILL.md` §Output + Phase 6 + EDIT `.claude/skills/team-qa/SKILL.md` Phase 3 + Phase 6 | PASS — convention validated by THIS qa-plan + smoke artifact filename usage (sprint-N-closure- + sprint-N- prefixes) | N/A — convention codification | NONE |
| **S11-11** — TODO triage pass | Config/Data (process audit) | NEW `production/process-audits/todo-triage-2026-05-08.md` (5 TODOs classified: 2 Address + 2 Defer-with-context + 1 Remove) | N/A — triage doc only | N/A — sprint-12 cleanup actions queued (4 actions bundleable in ~30-min commit; post-cleanup TODO count 5→2 below AI #6 threshold) | NONE |

---

## Automated Test Requirements

**Sprint-11 added zero new test files.** Test count stayed 1236 → 1236 (52nd consecutive failure-free baseline; was 51st at sprint-10 close). All pre-existing tests continue to PASS.

The single new lint added in S11-03 (`tools/ci/lint_story_status_consistency.sh`) operates on doc consistency rather than runtime behavior — it is wired as a sprint-12 cleanup forcing function, not gated as BLOCKING for sprint-11 close (the 33 pre-existing drift items it surfaced are themselves the sprint-12 target).

| Existing test surface | Status |
|---|---|
| Full headless suite via `addons/gdUnit4/bin/GdUnitCmdTool.gd` | PASS — 1236/1236 / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0 |
| All Pillar-2-anchored lints (battle-hud + scenario-progression + destiny-branch + ai-system) | PASS — pattern stable at 4 invocations across all 4 lint scripts |
| `lint_story_status_consistency.sh` (NEW S11-03) | Exit 1 on 33 pre-existing drift items (sprint-12 cleanup target); does NOT gate sprint-11 close per S11-03 commit message scope discipline |

---

## Manual QA Scope

**0 manual QA sessions required at sprint-11 close.**

Rationale per qa-lead Phase 2 strategy:
- All 11 stories are Config/Data type — no gameplay surface to manually verify
- No `.gd` code was touched in any sprint-11 story → no behavioral change to validate
- Process / doc artifacts are validated structurally (file existence + section presence + cross-reference integrity) at `/story-done` time; smoke check confirmed 11/11 EXPECTED with 0 MISSING
- The 4 condensed-batch smoke items (test baseline + working tree clean + lint drift count + 200-byte hygiene) are tooling-verifiable and were all PASS

---

## ADVISORY Deferrals (carry forward)

Sprint-11 introduced **3 net-new ADVISORY items** beyond the 5 inherited from battle-hud closure (now tracked in `production/polish-backlog.md`):

1. **AD-C6 pause-menu UX spec** — sprint-11 S11-08 closed only the main-menu side. Pause-menu UX spec remains a separate doc + separate sprint task. NOT regressing AD-C6 fully; main-menu side closes at next gate-check.
2. **AD-C5 Guan Yu + Zhang Fei character profile stubs** — sprint-11 S11-09 descoped from 3 stubs to 1 (Liu Bei only) per sprint-10 retro AI #5. Guan Yu + Zhang Fei stubs are **DESCOPED** (not deferred) — they will not appear in any sprint-11/12 backlog row unless explicitly re-added by user or art-director.
3. **lint_story_status_consistency 33 pre-existing drift items** — surfaced by S11-03 NEW lint; sprint-12 bulk cleanup target. Does NOT gate sprint-11 close (the lint exists to enforce going-forward; pre-existing drift is grandfathered until the cleanup sprint).

The 5 inherited ADVISORY items from battle-hud closure (POLISH-001..005 in `production/polish-backlog.md`) carry forward unchanged.

---

## Out of Scope (sprint-11 closure)

Explicitly NOT covered by this QA plan + not blocking sprint close:

- **Sprint-11 USER-OWNED items (S11-12 + S11-13)** — 4th-time S7-11 carryover + 2nd-time S8-15 carryover. Awaiting user attestation; refusal-to-fabricate posture unchanged. Carryover to sprint-12 is automatic.
- **Save/Load #17 implementation (sprint-11 S11-07)** — epic skeleton only this sprint; sprint-12 `/create-stories save-load` then `/dev-story` flesh-out. Implementation is OUT OF SCOPE for sprint-11 close gate.
- **POLISH-001..005 (battle-hud ADVISORY items)** — Polish-tier carry-forwards in `production/polish-backlog.md`; closure trigger is Polish-phase entry per ledger §Pickup Discipline.
- **POLISH-006-candidate (map_grid Dijkstra heuristic)** — TODO triage classified TODO-01 as Defer-with-context with Polish-phase forcing function. Producer call at sprint-12 plan time whether to migrate inline TODO to POLISH-006 ledger entry.
- **Performance profiling** — no perf budget changed in sprint-11 (no .gd code touched). `/perf-profile` runs deferred to Polish-tier.
- **5-platform CI lane verification** (macOS Metal / iOS Metal / Android Vulkan) — POSTPONED per sprint-10 S10-05 binding decision (`production/decisions/ci-lane-gap-decision-2026-05-07.md`); reactivation triggers continue to monitor at every gate-check.
- **Pre-Production → Production gate evaluation** — sprint-11 retro will assess whether Core layer 5/5 Complete (achieved via S11-02 backfill cascade per sprint-status.yaml line 36 AI #5 NEW) triggers gate-check pass. Out of scope for THIS qa-plan; in scope for `/retrospective sprint-11`.

---

## Entry Criteria (already met)

- [x] All 4 Must-Have stories status=done in `production/sprint-status.yaml` (S11-01 / S11-02 / S11-03 / S11-04)
- [x] All 4 Should-Have stories status=done (S11-05 / S11-06 / S11-07 / S11-08)
- [x] All 3 claude-owned Nice-to-Have stories status=done (S11-09 / S11-10 / S11-11)
- [x] Smoke check PASS — `production/qa/smoke-sprint-11-2026-05-08.md` (1236/1236; 52nd FFB)
- [x] All BLOCKING-tier automated tests PASS in headless run (validated 2026-05-08)
- [x] All required artifacts exist on disk (smoke check Phase 3 confirmed 11/11 EXPECTED, 0 MISSING)
- [x] All 11 claude-owned sprint-11 stories COVERED or EXPECTED in coverage scan
- [x] No open S1/S2 bugs in `production/qa/bugs/` against sprint-11 work products (no bugs filed this sprint)
- [x] sprint-11 critical path Must-Have 4/4 closed; carryover absorption sweep S11-04 closes sprint-10 retro AI #5
- [x] Working tree clean post-push (5 commits `b1e10a0` → `045ce98` + smoke `6cbc8c9` on origin/main)

---

## Exit Criteria (this QA cycle)

This QA cycle EXITS when:

- [x] qa-lead Phase 2 strategy confirms CLEAR TO CLOSE (delivered 2026-05-08 via this qa-plan + smoke PASS verdict)
- [ ] qa-lead Phase 7 sign-off report authored at `production/qa/qa-signoff-sprint-11-2026-05-08.md` with verdict APPROVED / APPROVED WITH CONDITIONS / NOT APPROVED
- [ ] Sign-off report committed to repo
- [ ] Sprint retrospective (`/retrospective sprint-11`) authored at `production/retrospectives/retro-sprint-11-2026-05-08.md`
- [ ] Sprint-status history archive landed in `production/sprint-status-history.md` Sprint 11 section

After exit: build advances to sprint-12 plan authoring (carries USER-OWNED S11-12 + S11-13 + Save/Load #17 epic flesh-out + TODO triage cleanup actions).

---

## Verdict (preliminary, pending Phase 7 sign-off)

Based on the strategy + smoke check + automated tests + artifact inventory:

**Recommendation**: APPROVED. All 11 claude-owned sprint-11 stories are Done with complete artifacts; no S1/S2 bugs open; no MISSING test evidence; smoke PASS at 52nd FFB; 36-streak in-patch hygiene preserved; lint_story_status_consistency 33 baseline preserved (no new drift introduced by sprint-11 commits).

The 3 ADVISORY items (AD-C6 pause-menu side / AD-C5 descoped Guan Yu+Zhang Fei / lint_story_status_consistency 33 drift) are NOT gating; they are tracked carryover items with explicit dispositions (sprint-12 sprint-plan absorption candidates).

USER-OWNED Nice items (S11-12 + S11-13) carry forward to sprint-12 unchanged. Refusal-to-fabricate posture preserved across the 4th-time S7-11 carryover (would be 5th at sprint-12 if not addressed).

**Final verdict** will be issued in the Phase 7 sign-off report.

---

## References

- Smoke check: `production/qa/smoke-sprint-11-2026-05-08.md`
- Prior closure-mode qa-plan precedent: `production/qa/qa-plan-sprint-10-closure-2026-05-07.md`
- Sprint plan: `production/sprints/sprint-11.md`
- Sprint status (canonical): `production/sprint-status.yaml`
- Sprint history archive (pending Sprint 11 section): `production/sprint-status-history.md`
- Active session state: `production/session-state/active.md` (will be cleared at sprint-11 close per project pattern)
- Naming convention codification source: `.claude/skills/team-qa/SKILL.md` Phase 3 (sprint-N-closure- prefix; codified S11-10 commit `045ce98`)
- Polish backlog (sprint-11 inception): `production/polish-backlog.md`
- Decisions convention (sprint-11 inception): `docs/process/decisions-convention.md`
- TODO triage doc: `production/process-audits/todo-triage-2026-05-08.md`
- /story-done Phase 7 audit: `production/process-audits/story-done-phase-7-audit-2026-05-08.md`
- save-load Core epic skeleton: `production/epics/save-load/EPIC.md`
- main-menu UX spec stub: `design/ux/main-menu.md`
- 유비 character profile stub: `design/art/characters/liu-bei.md`
