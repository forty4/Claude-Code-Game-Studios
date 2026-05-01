# Sprint 3 — 2026-05-03 to 2026-05-09

> **Review mode**: lean (per `production/review-mode.txt`) — PR-SPRINT director gate skipped
> **Manifest Version**: 2026-04-20 (`docs/architecture/control-manifest.md`)
> **Generated**: 2026-05-02
> **Carries**: sprint-2 retrospective Action Items #1-#5 (`production/retrospectives/retro-sprint-2-2026-05-02.md`)

## Sprint Goal

Close the **last Core epic** (hp-status) to Complete — Foundation 4/5 + Core 2/4 + 1 Ready — clearing the final precondition for Vertical Slice scene wiring in sprint-4. Resolve the carried turn-order test failure as the first commit. Scaffold input-handling (HIGH engine risk) to Ready as Should-Have. Apply sprint-status.yaml hygiene from retro AI #3.

## Capacity (recalibrated per retro AI #1)

- Total days: **7 calendar → 5 working** (down from sprint-2's 14/10; sprint-2 finished in 3 calendar days, recalibration is empirically warranted)
- Buffer (20%): **1 day** for unplanned work / regression / discovery
- Available: **4 working days**

## Context

Project is in **mid Production phase**. As of 2026-05-02:

- **All 12 ADRs Accepted** since 2026-04-30
- **9 epics Complete**: gamebus, scene-manager, save-manager, map-grid, terrain-effect, unit-role, balance-data, hero-database, damage-calc (`production/epics/index.md` row stale — fix in S3-03), turn-order
- **Foundation 4/5 Complete**, **Core 1/4 Complete + 1 Ready (turn-order Ready→Complete pending index refresh)**, **Feature 1/13 Complete**
- Full regression: **648 testcases / 0 errors / 1 carried failure / 0 orphans** (carried failure resolved by S3-00)
- 1 epic remaining for "all-Foundation-and-Core" milestone: **hp-status** (Core)

After sprint-3 ships, Foundation will be 4/5 (input-handling scaffolded but not implemented) and Core will be 2/4 (hp-status Complete; save-load deferred to VS tier). The next bottleneck for Vertical Slice gate-PASS will be **(a) playable scene wiring + (b) save-load schema GDD authoring + (c) hp-status × turn-order × damage-calc cross-system integration tests** (the 4 deferred TR-048 ACs — POISON DoT, battle-end-via-DoT, Scout Ambush).

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S3-00 | **Carry-fix**: resolve `turn_order_advance_turn_test::test_round_lifecycle_emit_order_two_units` carried failure (per retro AI #4) | claude | 0.25 | — | Test PASS in headless run; full regression 648/648 / 0 errors / 0 carried failures / 0 orphans |
| S3-01 | `/create-epics hp-status` + `/create-stories hp-status` (ADR-0010, Core layer; greenfield — depends on ADR-0007 HeroData formal type now Complete) | claude | 0.5 | ADR-0010 Accepted ✓; hero-database epic Complete ✓ | EPIC.md + 6-8 stories Ready with embedded TRs/ACs; epics-index.md updated |
| S3-02 | Implement hp-status epic to Complete (~6-8 stories, greenfield — full estimate scale per retro AI #1; **NOT** ratification) | claude | 2.0 | S3-01 | All stories Complete; full regression PASS; epic Status=Complete; Core 2/4 Complete |
| S3-03 | Admin: refresh `production/epics/index.md` post-sprint-3 (Foundation 4/5 + Core 2/4; **fix stale damage-calc row** — index says Ready but epic is Complete; **fix stale turn-order row** — index says Ready, now Complete; update VS-readiness snapshot) | claude | 0.25 | S3-02 | Index reflects truth; damage-calc + turn-order rows fixed; changelog entry dated end-of-sprint |

**Must Have estimate**: **3.0 days**

### Should Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S3-04 | `/create-epics input-handling` + `/create-stories input-handling` (ADR-0005, Foundation, **HIGH** engine risk — 4.6 dual-focus + SDL3 + Android edge-to-edge) | claude | 0.75 | ADR-0005 Accepted ✓ | EPIC.md + 5-7 stories Ready with HIGH-risk callouts per story; **scaffolding only** (impl deferred to sprint-4) |
| S3-05 | Sprint-status.yaml hygiene refactor: cap `updated:` at 200 chars; archive older context to `production/sprint-status-history.md`; amend `/story-done` skill to enforce going forward (per retro AI #3) | claude | 0.5 | — | sprint-status.yaml `updated:` field <200 chars; history file created with sprint-2 archive; /story-done skill updated to enforce |

**Should Have estimate**: **1.25 days**

### Nice to Have (per retro AI #5 — single 0.5d slot only, no full-epic items)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S3-06 | TD-042 close-out: amend `data-files.md` Entity Data File Exception (snake_case JSON keys for typed-Resource-mapped data files) | claude | 0.5 | — | data-files.md amended; TD-042 marked RESOLVED in tech-debt-register.md |

**Nice to Have estimate**: **0.5 days**

## Mid-Sprint Checkpoint (NEW — per retro AI #2)

> **Non-skippable**: At the 50% calendar mark (Day 4, 2026-05-06), run `/scope-check sprint-3` AND `/sprint-status`. If scope-up >25% of original estimate has emerged (e.g. hp-status implementation surfaces unexpected work, or a fresh epic gets implemented as bonus), **explicit ratification required** before continuing. Lean-mode PR-SPRINT skip remains, but mid-sprint check is non-skippable going forward.

## Carryover from Previous Sprint

| Task | Reason | New Estimate |
|------|--------|-------------|
| S2-07 hp-status epic creation | Crowded out by turn-order scope-up; ready (S2-04 Complete unlocked dependency) | 0.5d → S3-01 |
| S2-09 input-handling epic creation | HIGH engine risk warranted dedicated session | 0.75d → S3-04 (Should-Have, not Nice-to-Have, per retro AI #5) |
| S2-10 hp-status story-001 begin | Depended on S2-07 | Absorbed into S3-02 |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| hp-status epic surfaces unexpected cross-system Integration ACs deferred from turn-order TD-048 (POISON DoT, battle-end-via-DoT) | MEDIUM | MEDIUM | TD-048 cross-system ACs are explicitly Vertical Slice scope per the deferral; hp-status epic should NOT pull them in. Risk is misclassification at /create-stories time — apply `/scope-check hp-status` before story-001 implementation. |
| Carry-fix S3-00 reveals deeper structural issue than the test name suggests | LOW | LOW | Buffer covers. Worst case: defer to hotfix story; do not block S3-01. |
| input-handling HIGH engine risk surfaces SDL3 / Android edge-to-edge requirements that conflict with map-grid or scene-manager assumptions | LOW | HIGH | S3-04 scoped to **scaffolding only** — defer implementation stories to sprint-4. Don't gate any Must Have on input-handling. |
| Estimate recalibration (50% on ratification, full on greenfield) under-shoots greenfield hp-status — first non-ratification Core epic since terrain-effect | MEDIUM | MEDIUM | Buffer absorbs. Greenfield hp-status estimate is 2.0d. If hp-status finishes in ≤1.5d, recalibration confirmed; if ≥2.5d, recalibrate again at sprint-3 retro. |
| Sprint-status.yaml hygiene refactor (S3-05) requires `/story-done` skill amendment — touches a load-bearing skill | LOW | MEDIUM | Amendment is cap-enforcement only (200-char limit on a single field). Does not change skill semantics. Test by running 1 story-done after amendment to verify no regression. |

## Dependencies on External Factors

- None. All required ADRs Accepted; all required GDDs Designed; full regression baseline 648 testcases stable (1 carried failure to be fixed in S3-00).

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed (4/4)
- [ ] hp-status epic: Status=Complete (Core 1/4 → 2/4)
- [ ] S3-00 carry-fix landed; full regression 0 carried failures
- [ ] input-handling epic: EPIC.md + ≥5 stories each Ready (Should-Have)
- [ ] sprint-status.yaml `updated:` field policy enforced (S3-05; ≤200 chars going forward)
- [ ] No S1 or S2 bugs in shipped code
- [ ] Full regression suite still passes (≥648 baseline + new tests from S3-02)
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] Per-epic QA plan exists for hp-status (`production/qa/qa-plan-hp-status-YYYY-MM-DD.md`)
- [ ] QA sign-off via `/team-qa hp-status` — APPROVED or APPROVED WITH CONDITIONS
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
- [ ] `production/epics/index.md` refreshed (S3-03)
- [ ] **NEW**: Mid-sprint `/scope-check` run logged at 2026-05-06 (Day 4)
- [ ] Sprint-3 retrospective written (`production/retrospectives/retro-sprint-3-YYYY-MM-DD.md`) — sprint-2 set the precedent

## Phase Gates Skipped (Lean Mode)

Per `production/review-mode.txt = lean`:

- **PR-SPRINT** (Producer feasibility gate, Phase 4): SKIPPED. Self-assessment: Must Have 3.0d against 4d available — 1d margin (25% buffer headroom). Should Have +1.25d (4.25d total) eats buffer; Nice to Have +0.5d eats more. Acceptable per lean precedent + retro AI #1 calibration.
- **Per-story phase-gates** during execution: continue to skip QL-STORY-READY + QL-TEST-COVERAGE + LP-CODE-REVIEW; convergent `/code-review` (godot-gdscript-specialist + qa-tester parallel) remains the minimum safe unit (validated 10+ times).

## Process Discipline Carried Forward

These load-bearing patterns from sprints 1-2 must be preserved:

1. **Sweep + narrow re-review** — minimum safe unit for numeric/contract changes touching 2+ documents (validated 4× damage-calc + 1× hero-database)
2. **Convergent /code-review** — gdscript-specialist + qa-tester spawned in parallel; convergent findings auto-applied
3. **G-1..G-15 + TG-1/TG-2 gotchas** — preempt at story scaffolding, not at /code-review
4. **R1 commit + PR pattern** — one feature branch per story; commit format `feat(<system>): story-NNN — short summary`
5. **Provisional-dependency strategy** — 5× validated (now stable as standing pattern)
6. **Polish-deferral pattern** — 5× validated (apply to S3-04 input-handling SDL3/Android stories)
7. **Per-epic QA plan** — `/qa-plan hp-status` BEFORE first /dev-story
8. **Lean-mode review** — orchestrator-direct verdict (5+ precedent stable)
9. **NEW (retro AI #2)**: Mid-sprint /scope-check at 50% calendar mark — non-skippable
10. **NEW (retro AI #3)**: sprint-status.yaml `updated:` field cap 200 chars — enforced after S3-05

## Next Steps

After sprint kickoff:

- **`/qa-plan hp-status`** — required before S3-02 implementation begins (per-epic QA plan strategy)
- `/story-readiness production/epics/hp-status/story-001-*.md` — validate before starting first story
- `/dev-story production/epics/hp-status/story-001-*.md` — begin S3-02 implementation
- `/sprint-status` — mid-sprint progress check (Day 4 mandatory per retro AI #2)
- `/scope-check hp-status` — verify no scope creep before implementation begins

> **Scope check**: If this sprint adds stories beyond the original epic scope (after `/create-stories` runs), run `/scope-check [epic]` to detect creep before implementation begins.
