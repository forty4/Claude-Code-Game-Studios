# QA Plan — Sprint-12 Closure

**Date**: 2026-05-09
**Sprint**: sprint-12 (Must 2/3 ✓ + Should 3/3 ✓ + Nice-claude 3/3 ✓ = 8/8 claude-owned closed; S12-03 blocker-bound; commits `779f614` → `1ca72a1` on origin/main; 14 sprint-12-tagged commits incl. save-load epic in-sprint expansion)
**Scope**: closure-mode QA plan covering all 11 sprint-12 canonical stories (8 claude-owned closed + 1 blocker-bound + 2 USER-OWNED) + acknowledgement of in-sprint save-load epic graduation (S12-01 follow-on)
**Mode**: lean (`production/review-mode.txt` = `lean`)
**Smoke**: PASS WITH WARNINGS — `production/qa/smoke-sprint-12-2026-05-09.md` (1273/1273; 64th FFB)
**Filename naming**: per `.claude/skills/team-qa/SKILL.md` Phase 3 (codified S11-10 2026-05-08) — sprint-close gates use `qa-plan-sprint-[N]-closure-[date].md`
**Entry-time qa-plan precedent**: `production/qa/qa-plan-sprint-12-2026-05-08.md` (the entry-time forecast; this closure addendum supersedes it for close-gate evaluation)

---

This is a **mixed-mode sprint closure addendum**. Sprint-12 was structured as a closure-leaning mixed sprint — 1 greenfield Integration story (S12-02 Pillar-4 atmospheric demo) + 7 Config/Data closure/admin stories + 1 blocker-bound process story (S12-03 gate-check rerun) + 2 USER-OWNED carryovers. **In-sprint scope expansion**: S12-01 (`/create-stories save-load`) authored 3 story files; the same sprint also implemented all 3 via `/dev-story` flesh-out — save-load epic graduated Designed → Implemented in-sprint (epic-terminal at `3b2cb0d`).

Test count grew **1236 → 1273 (+37)** — +30 from save-load epic story-001/002/003 in-sprint implementation + +7 from S12-02 atmospheric_moment_test.gd. Two new CI lint scripts shipped (S12-04 + S12-09). One new Demo-layer epic terminated (chapter-prototype-demo, S12-02; first epic in the Demo layer).

Closure verdict is **APPROVED WITH CONDITIONS** preliminary: 8 of 8 claude-owned canonical stories Done; 0 MISSING evidence; 1273/1273 64th FFB; **conditions**: S12-03 close-gate rerun blocker-bound on USER-OWNED S12-10/S12-11 (gate-check path-to-PASS items 1+2 still pending; carryover-to-sprint-13 unavoidable).

---

## Story Classification Table

| Story | Type | Output artifact (NEW or EDIT) | Automated Required | Manual Required | Blocker? |
|---|---|---|---|---|---|
| **S12-01** — `/create-stories save-load` (+ in-sprint dev follow-on) | Config/Data (epic flesh-out) | NEW `production/epics/save-load/story-001..003-*.md` (3 story files per /create-stories convention; ALL 3 IMPLEMENTED in-sprint at `5357287` / `12a039f` / `3b2cb0d` — bonus scope; #17 epic graduated Designed → Implemented) | PASS — save-load story-001 +8 tests, story-002 +9 tests, story-003 +13 tests = +30 net new tests; 53rd → 56th FFB sustained | N/A — convention conformance + 3 lints in story-003 verif summary | NONE |
| **S12-02** — Pillar-4 atmospheric demo (CD path-to-PASS item 3) | **Integration** (greenfield) | NEW `tests/integration/chapter_prototype/atmospheric_moment_test.gd` (7 tests) + NEW `production/epics/chapter-prototype-demo/story-001-pillar-4-atmospheric-moment.md` + NEW `production/epics/chapter-prototype-demo/EPIC.md` (Demo-layer first epic) + impl on REWRITTEN destiny-branch + chapter-prototype scene wiring | PASS — atmospheric_moment_test.gd 7 tests; suite 1266 → 1273 (+7) at S12-02 close `17d3f84` (57th FFB) | DEFERRED to S12-10 user attestation (REPORT.md 4 VS Validation items); CD playtest gate pending USER-OWNED resolution | NONE (test PASS); CONDITION: CD playtest deferred |
| **S12-03** — `/gate-check pre-prod-to-prod` rerun | Config/Data (process artifact) | NEW `production/gate-checks/pre-prod-to-prod-2026-05-08-rerun.md` + EDIT 4 process-decision artifacts under `production/decisions/` (3a + 3b CD-refined items closed at `287e986`) | N/A — skill invocation produces gate-check artifact | N/A — director panel verdicts; 3a + 3b CLOSED; items 1 + 2 USER-OWNED pending | **BLOCKER-BOUND** on S12-10/S12-11 USER-OWNED |
| **S12-04** — `lint_story_status_consistency` 33-drift bulk cleanup + CI wire | Config/Data (lint cleanup + CI wire) | EDIT 33 drift items across `production/epics/*/EPIC.md` + `production/epics/index.md` + EDIT `tools/ci/lint_story_status_consistency.sh` + EDIT `.github/workflows/tests.yml` | PASS — lint Exit 0 post-cleanup verified at smoke time 2026-05-09 | N/A — drift count 33 → 0 verified by lint; spot-check during cleanup | NONE |
| **S12-05** — TODO triage Address actions bundle | Config/Data + smoke | 4 surgical edits across 3 files (TODO-02 `save_manager.gd:200` doc cleanup + TODO-04 `get_battle_state_snapshot()` removal + TODO-05 `grid_battle_controller.gd:424` stale TODO line + TODO-03 reformat) | PASS — `grep -rn TODO src/` = 2 (was 5; matches AC) verified at smoke time; 1273/1273 baseline preserved | N/A — `grep` verification | NONE |
| **S12-06** — §11 USER-OWNED 5th-carry HARD GATE rule | Config/Data (process doc extension) | EDIT `docs/process/decisions-convention.md` (+77 LoC; total 315; §11 NEW top-level section) | N/A — process doc | N/A — producer + user concurrence captured pre-write per Route c convention | NONE |
| **S12-07** — closure-mode HYBRID adoption | Config/Data (decision artifact) | NEW `production/decisions/closure-mode-sprint-pattern-2026-05-09.md` (HYBRID ≥3-of-5 signals + recurring per-sprint Trigger 1) | N/A — decision artifact per `docs/process/decisions-convention.md` template | N/A — producer call concurred per convention; sprint-11 retro AI #6 CLOSED | NONE |
| **S12-08** — POLISH-006 entry (lightweight path) | Config/Data (polish-backlog row) | EDIT `production/polish-backlog.md` POLISH-006 row (Guan Yu + Zhang Fei stubs deferred to commission-sprint forcing function) | N/A — ledger entry | N/A — entry format conformance per polish-backlog.md §Entry Format | NONE |
| **S12-09** — `lint_sprint_carryover_count.sh` + CI wire | Config/Data (new lint + CI wire) | NEW `tools/ci/lint_sprint_carryover_count.sh` + EDIT `.github/workflows/tests.yml` | PASS — lint Exit 0 (sprint-12 pre-carryover=2 vs sprint-11 retro forecast=2; <4 threshold) verified at smoke time 2026-05-09; sprint-11 retro AI #5 CLOSED | N/A — sprint-12 retro AI #10 NEW (vacuous-pass risk if future retros stop using canonical phrase) | NONE |
| **S12-10** — S7-11 USER-OWNED (5th-carry; HARD GATE candidate) | USER-OWNED | OUT OF SCOPE per refusal-to-fabricate posture | OUT OF SCOPE | User attestation in `prototypes/chapter-prototype/REPORT.md` 4 VS Validation items | **BLOCKING for S12-03 close-gate** |
| **S12-11** — S8-15 USER-OWNED (3rd-carry) | USER-OWNED | OUT OF SCOPE per refusal-to-fabricate posture | OUT OF SCOPE | User attestation in `production/qa/qa-signoff-sprint-8-2026-05-06.md` Batches 1+3 | **BLOCKING for S12-03 close-gate (gate-check path-to-PASS item 2)** |

---

## Automated Test Requirements

**Sprint-12 added +37 net new tests** (1236 → 1273). All tests PASS at 64th consecutive failure-free baseline.

### Test delta breakdown

| Source | Tests added | Cumulative count | FFB # |
|---|---:|---:|---|
| sprint-11 close baseline | — | 1236 | 52 |
| save-load story-001 (S12-01 follow-on; CP-1/2/3 emission integration; commit `5357287`) | +8 | 1244 | 53 |
| save-load story-002 (S12-01 follow-on; cross-chapter continuity + `save_loaded` signal; commit `12a039f`) | +9 | 1253 | 54 |
| save-load story-003 (S12-01 follow-on; failure surfacing + 3 lints + verif summary; commit `3b2cb0d` epic-terminal #17) | +13 | 1266 | 56 |
| S12-02 atmospheric_moment_test.gd (commit `aa55969` impl + `17d3f84` epic-terminal) | +7 | 1273 | 57 |
| S12-04 → S12-06 close-out chain (no test delta; 8 commits sustained 57th → 64th FFB) | 0 | 1273 | 64 |

### Test surface status

| Test surface | Status |
|---|---|
| Full headless suite via `addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode` | PASS — 1273/1273 / 130 suites / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0 (18s 792ms at smoke 2026-05-09) |
| **NEW** `tests/integration/chapter_prototype/atmospheric_moment_test.gd` (S12-02; 7 tests) | PASS — gates Pillar-4 demo path |
| **NEW** save-load epic story-001/002/003 integration tests (S12-01 follow-on; +30 tests) | PASS — gates ScenarioRunner CP-1/2/3 emission contract + cross-chapter continuity + failure surfacing |
| All sprint-11-anchored lints (battle-hud + scenario-progression + destiny-branch + ai-system + 5-platform + sprint-status hygiene) | PASS — pattern stable |
| **NEW** `tools/ci/lint_story_status_consistency.sh` (S11-03 lint, S12-04 cleanup target) | Exit 0 — drift count 33 → 0 (CI-wired) |
| **NEW** `tools/ci/lint_sprint_carryover_count.sh` (S12-09; sprint-11 retro AI #5) | Exit 0 — sprint-12 pre-carryover=2 matches retro forecast=2 (CI-wired) |
| **NEW** save-load story-003's 3 enforcement lints (S12-01 follow-on) | Exit 0 — wired in `.github/workflows/tests.yml` per S12-01 epic flesh-out |

**ObjectDB-leaked-at-exit warning** observed in headless run — cosmetic; benign across all 64 FFB runs.

---

## Manual QA Scope

**0 manual QA sessions required at sprint-12 close (claude-side).**

Rationale per qa-lead Phase 2 strategy:
- 8 of 11 canonical stories are Config/Data type — no gameplay surface to manually verify (process docs, ledger entries, lint scripts, decision artifacts, character-profile stubs)
- S12-02 (Integration) is the only canonical runtime addition; covered by `tests/integration/chapter_prototype/atmospheric_moment_test.gd` 7 tests at the integration test tier
- save-load epic story-001/002/003 (S12-01 follow-on; 30 tests) are integration-tier covered; no gameplay surface beyond signal contracts + lints
- S12-10 + S12-11 USER-OWNED items require user attestation; refusal-to-fabricate posture means claude cannot perform these on user's behalf
- Smoke check 2026-05-09 confirmed user opted to skip Batches 1/2/3 (closure-mode posture); manual NOT-RUN treated as warning per skill rule, not FAIL

**S12-02 CD playtest deferral**: the entry-time qa-plan called for ≥1 non-developer playtest session for S12-02 (CD verdict path). At close time, CD playtest is **deferred** to S12-10 user attestation cycle — when user runs `chapter.tscn` for the 4 VS Validation items, the same session can produce the CD-required playtest evidence. This consolidation is consistent with S12-06 §11 HARD GATE rule (5th-time threshold ⇒ user-attestation OR cancellation; carry-to-sprint-14 forbidden).

---

## ADVISORY Deferrals (carry forward to sprint-13)

Sprint-12 introduced **6 ADVISORY items** beyond the 5 inherited from battle-hud closure (now POLISH-001..005 + new POLISH-006 in `production/polish-backlog.md`):

1. **S12-04 EPIC.md table-row hygiene sweep** — `lint_story_status_consistency.sh` regex requires bolded Status text; balance-data + turn-order Stories tables contain unbolded Ready entries that pass lint vacuously. Sprint-12 retro candidate.
2. **TODO-01 (`map_grid` Dijkstra heuristic) + TODO-04 (Battle AI ADR-defer)** — both are well-formed deferrals to future ADRs (Battle AI ADR not yet written; TR-map-grid-006 perf benchmark not yet exercised). Will close when consumer ADRs land.
3. **Carryover-count lint vacuous-pass risk** — if future retros stop using canonical phrase `Carryover concentration into sprint-{N}`, lint downgrades to ADVISORY-only. Producer responsibility per sprint-12 retro AI #5 closure gate-check evaluation.
4. **POLISH-006 forcing function not yet fired** — Guan Yu + Zhang Fei stubs at AD-C5 partial-state; AD-C5 will fully close when both stubs ship + character-art commission sprint enters planning OR Polish gate fires.
5. **S7-11 5th-time HARD GATE bound** — sprint-13 entry MUST resolve via path (a) user-attested OR (b) formally cancelled per `production/decisions/{topic-slug}-cancel-decision-{date}.md`. Path (c) carry-to-sprint-14 is **forbidden** by §11 rule.
6. **S8-15 3rd-time normal carry** — below threshold; continues to sprint-13 if not user-attested (will be 4th-time at sprint-13 entry).

The 5 inherited POLISH-001..005 items + new POLISH-006 in `production/polish-backlog.md` carry forward unchanged.

---

## Out of Scope (sprint-12 closure)

Explicitly NOT covered by this QA plan + not blocking sprint close:

- **S12-10 + S12-11 USER-OWNED items** — refusal-to-fabricate posture preserves carryover; the §11 HARD GATE rule (S12-06) explicitly handles S12-10 5th-time at sprint-13 entry.
- **POLISH-001..006 ledger entries** — Polish-tier carry-forwards in `production/polish-backlog.md`; closure trigger is Polish-phase entry per ledger §Pickup Discipline.
- **Performance profiling** — S12-02 atmospheric demo introduces minimal runtime cost (1 visual treatment + 1 audio cue); no perf budget changed. `/perf-profile` deferred to Polish-tier.
- **5-platform CI lane verification** — POSTPONED per `production/decisions/ci-lane-gap-decision-2026-05-07.md`; reactivation triggers continue to monitor at every gate-check.
- **Pre-Production → Production stage flip** — S12-03 close-gate rerun verdict will be CONCERNS (not PASS) until S12-10/S12-11 resolve; `production/stage.txt` write deferred to sprint-13+ gate-check pass.

---

## Entry Criteria (already met)

- [x] All 2 of 3 claude-doable Must-Have canonical stories status=done in `production/sprint-status.yaml` (S12-01 + S12-02; S12-03 blocker-bound)
- [x] All 3 Should-Have stories status=done (S12-04 + S12-05 + S12-06)
- [x] All 3 Nice-claude stories status=done (S12-07 + S12-08 + S12-09)
- [x] **In-sprint scope expansion**: save-load epic 3/3 stories implemented (story-001 + story-002 + story-003); #17 graduated Designed → Implemented at `3b2cb0d`
- [x] Smoke check PASS WITH WARNINGS — `production/qa/smoke-sprint-12-2026-05-09.md` (1273/1273; 64th FFB)
- [x] All BLOCKING-tier automated tests PASS in headless run (validated 2026-05-09)
- [x] All required artifacts exist on disk (smoke check Phase 3 confirmed 4 COVERED + 7 EXPECTED + 0 MISSING)
- [x] All 8 claude-owned closed canonical sprint-12 stories COVERED or EXPECTED in coverage scan
- [x] No open S1/S2 bugs in `production/qa/bugs/` against sprint-12 work products (no bugs filed this sprint)
- [x] sprint-12 critical path Must-Have 2/3 closed; S12-03 blocker-bound disposition documented
- [x] Working tree clean post-push (commits today `c3f3ca9` → `1ca72a1` on origin/main; sprint-12 epoch starts at `779f614`)
- [x] 47-streak in-patch sprint-status hygiene preserved across all sprint-12 commits

---

## Exit Criteria (this QA cycle)

This QA cycle EXITS when:

- [x] qa-lead Phase 2 strategy confirms CLEAR TO CLOSE WITH CONDITIONS (delivered 2026-05-09 via this qa-plan + smoke PASS WITH WARNINGS verdict)
- [ ] qa-lead Phase 7 sign-off report authored at `production/qa/qa-signoff-sprint-12-2026-05-09.md` with verdict APPROVED WITH CONDITIONS
- [ ] Sign-off report committed to repo
- [ ] Sprint retrospective (`/retrospective sprint-12`) authored at `production/retrospectives/retro-sprint-12-2026-05-09.md` (15 AI seeds: 2 closed at S12-06/07, 13 active including 4 NEW)
- [ ] Sprint-status history archive landed in `production/sprint-status-history.md` Sprint 12 section
- [ ] Sprint-13 plan authoring obligations triggered per §11.4 (S7-11 disposition path (a) or (b) MUST be resolved at sprint-13 entry)

After exit: build advances to sprint-13 plan authoring (carries USER-OWNED S12-10 → S13-XX with §11 HARD GATE bound + S12-11 → S13-YY normal-carry + S12-03 close-gate rerun re-evaluation + 13 active retro AIs).

---

## Verdict (preliminary, pending Phase 7 sign-off)

Based on the strategy + smoke check + automated tests + artifact inventory:

**Recommendation**: **APPROVED WITH CONDITIONS**.

**APPROVED grounds**:
- All 8 of 8 claude-doable canonical sprint-12 stories Done with complete artifacts
- **In-sprint scope expansion**: save-load epic 3/3 stories implemented as bonus (S12-01 follow-on); save-load #17 graduated Designed → Implemented epic-terminal
- 1273/1273 64th consecutive FFB preserved (highest test count + longest streak in project history; +37 net new tests = +30 from save-load follow-on + +7 from S12-02)
- 0 MISSING test evidence
- 47-streak in-patch sprint-status hygiene preserved across all sprint-12 commits
- 2 NEW canonical CI lints (S12-04 + S12-09) + 3 NEW save-load enforcement lints (S12-01 follow-on) add forward-looking guard rails
- Sprint-11 retro AIs #1, #2, #3, #5, #6 CLOSED in-sprint; AI #7 codified at S12-06; mixed-mode velocity multiplier (AI #4) re-validated at ÷~4.8 actual vs ÷3 nominal (sprint-12 trended toward heavy-closure due to 8/9 Config/Data canonical stories + bonus save-load expansion)

**CONDITIONS**:
1. **S12-03 close-gate rerun blocker-bound** on USER-OWNED S12-10 + S12-11 — gate-check verdict will be CONCERNS (not PASS) until items resolve. Sprint-12 close ships with this CONCERNS verdict accepted.
2. **S12-10 (S7-11 5th-time) carries to sprint-13 with §11 HARD GATE binding** — sprint-13 plan authoring MUST resolve via path (a) user-attested OR (b) formally cancelled per `production/decisions/`. Path (c) carry-to-sprint-14 is forbidden.
3. **S12-11 (S8-15 3rd-time) carries normally** to sprint-13 (will be 4th-time at sprint-13 entry; below 5-time threshold).

The 6 ADVISORY items are NOT gating; they are tracked carryover items with explicit dispositions (sprint-13 sprint-plan absorption candidates).

**Final verdict** will be issued in the Phase 7 sign-off report (`/team-qa sprint-12 attestation-mode` → `production/qa/qa-signoff-sprint-12-2026-05-09.md`).

---

## References

- Smoke check (this cycle): `production/qa/smoke-sprint-12-2026-05-09.md`
- Entry-time qa-plan: `production/qa/qa-plan-sprint-12-2026-05-08.md` (forecast-time; this addendum supersedes for close-gate)
- Prior closure-mode qa-plan precedent: `production/qa/qa-plan-sprint-11-closure-2026-05-08.md`
- Sprint plan: `production/sprints/sprint-12.md`
- Sprint status (canonical): `production/sprint-status.yaml`
- Sprint history archive (pending Sprint 12 section): `production/sprint-status-history.md`
- Active session state: `production/session-state/active.md`
- Naming convention codification source: `.claude/skills/team-qa/SKILL.md` Phase 3 (sprint-N-closure- prefix; codified S11-10 commit `045ce98`)
- Polish backlog: `production/polish-backlog.md` (POLISH-001..005 inherited + POLISH-006 NEW at S12-08)
- Decisions convention: `docs/process/decisions-convention.md` §11 NEW (USER-OWNED 5th-carry HARD GATE; S12-06 commit `1ca72a1`)
- Closure-mode HYBRID decision: `production/decisions/closure-mode-sprint-pattern-2026-05-09.md` (S12-07 commit `784cef3`)
- TODO triage doc (sprint-11 inception): `production/process-audits/todo-triage-2026-05-08.md`
- chapter-prototype-demo Demo-layer first epic: `production/epics/chapter-prototype-demo/EPIC.md` (S12-02 epic-terminal)
- save-load Core epic stories (S12-01 follow-on): `production/epics/save-load/story-001..003-*.md` (epic-terminal at `3b2cb0d` 2026-05-08)
- Gate-check 2026-05-08 entry context: `production/gate-checks/pre-prod-to-prod-2026-05-08.md` (CONCERNS verdict; 3 path-to-PASS items)
- Gate-check 2026-05-08 rerun: `production/gate-checks/pre-prod-to-prod-2026-05-08-rerun.md` (CONCERNS; items 3a + 3b CLOSED at `287e986`; items 1 + 2 USER-OWNED pending)
