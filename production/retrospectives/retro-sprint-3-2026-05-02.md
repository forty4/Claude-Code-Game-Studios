# Sprint 3 Retrospective — 2026-05-02

> **Format**: lean (per `production/review-mode.txt`). Single-doc capture; no team interview phase. Compatible with sprint-2 retrospective format precedent.
> **Sprint window**: 2026-05-03 to 2026-05-09 (planned) → effectively closed 2026-05-02 (7 calendar days ahead of deadline)
> **Final state**: 7/7 items done (Must-have 3/3 + Should-have 2/2 + Nice-to-have 1/1)

## What shipped

| ID | Item | Outcome |
|---|---|---|
| S3-00 | Carry-fix turn-order test | DONE — full regression 648/0/0/0/0 PASS |
| S3-01 | hp-status epic + 8 stories + qa-plan | DONE |
| S3-02 | hp-status implementation 8/8 | DONE — single epic-terminal commit (`6731cc6`); 743/743 (8th failure-free baseline) |
| S3-03 | epics/index.md refresh | DONE |
| S3-04 | input-handling epic + 10 stories + qa-plan | DONE — first HIGH engine-risk epic; 17/17 TRs traced |
| S3-05 | sprint-status.yaml hygiene + /story-done amendment (retro AI #3) | DONE — 200-byte cap + sprint-status-history.md + skill amendment |
| S3-06 | TD-042 close-out (data-files.md Entity Data File Exception) | DONE — 75 LoC amendment + 3 ADR cross-links |

8 commits pushed, all green.

## What worked

- **Single-session epic delivery for hp-status** — 8 stories shipped in one epic-terminal commit (`6731cc6`) at 743 PASS. Repeat of the turn-order epic-terminal pattern from sprint-2. Pattern is now stable (3 invocations: turn-order + hp-status + would-have been input-handling impl if it weren't carried to sprint-4+).
- **Retro AI #1 estimation recalibration empirically validated** — sprint-3 7/7 done in 1 calendar day vs. 7-day window. Recalibration needs further tightening (5d → 1d empirical).
- **Retro AI #3 (sprint-status hygiene) was high-leverage** — closed within sprint, immediate ROI: future /story-done updates have a cap discipline preventing the 1280-byte single-line YAML pattern that was breaking grep-ability.
- **Per-epic /qa-plan discipline** — input-handling qa-plan (462 lines, largest in project) ahead of impl provides a self-contained brief any later session can execute against.

## What didn't work

- **Process-vs-code ratio** — 7 sprint items, but **4 of 7 were process work** (S3-03 index refresh + S3-04 docs+qa-plan + S3-05 yaml hygiene + S3-06 TD-042). Only S3-00 (1 test fix) + S3-02 (1 epic impl) + S3-04 partial were code-touching. **No item moved closer to a runnable scene** — `src/ui/` is still empty after 11 epics.
- **"Playable-surface delta" was zero** — no item this sprint advanced the project toward a Godot scene a user could click. The lean-mode `/sprint-plan` did not flag this absence. Pattern observed across all 3 sprints: backend density + zero playable surface.

## The pivot decision (THE major event of this sprint)

After S3-06 closed, the user asked: **"얼마나 더 개발해야 실제 게임을 확인해 볼 수 있어?"** ("how much more dev until I can actually see the game?"). Audit revealed: 11 backend epics shipped, 0 UI files in `src/ui/`, 1 test-fixture .tscn, no `main_scene` configured. Per-sprint estimate to first playable battle was 3-6 more sprints.

**Decision tree the session walked through**:

1. **Option B chosen**: `/prototype` mode — build wireframe quickly to validate game concept before more backend
2. **First prototype** (`prototypes/vertical-slice/`, ~470 LoC): 4-unit ColorRect grid battle. Headless smoke + visible run both passed. User played 23 turns to DEFEAT but said: **"이 정도로는 판단할 수 있는 게 너무 없어"** (not enough to make any judgment). Diagnostic: 1st prototype tested *technical execution*, not *game concept* — 0/4 game pillars in scope.
3. **Second prototype** (`prototypes/chapter-prototype/`, ~1200 LoC): full 4-phase chapter loop (story → party → battle → fate judgment) with formation/angle/passive math, hidden 5-condition fate branches, 4-hero role differentiation. User played briefly (1 turn) and reported: **"4가지 게임 필라 모두 별로 느껴지지 않음"** (none of the 4 game pillars came through).
4. **Root-cause framing** — User answered the deep questions:
   - Motivation: 10/10 (concept alive)
   - Genre experience: deep (KOEI 영걸전 extensively played)
   - Self-target: would play 30+ hours if shipped per concept
5. **Conclusion**: prototype iteration is *the wrong tool for SRPG concept validation*. SRPG appeal = visual character + animation + BGM + cutscenes — none of which prototype tooling captures. Color-rect wireframes literally cannot answer "is this 영걸전-quality?" for a player who's played 영걸전 extensively.
6. **Sprint-4 pivot**: drop prototype iteration; start production MVP First Chapter (3-sprint arc: sprint-4..6) with real ADRs (Camera + Grid Battle Controller + Battle HUD) + asset gathering (sprite portraits + BGM) + scenario data. The two prototypes serve as **design briefs** (not refactoring source) for the production code.

## Action Items for Next Iteration

| # | Action | Owner | Priority | Deadline |
|---|--------|-------|----------|----------|
| 1 | **Add "playable-surface delta" line to /sprint-plan output** — every sprint plan must explicitly answer: "does this sprint move us closer to a runnable scene?" If 0/N items do, the sprint has a structural problem and should be challenged. | claude (next /sprint-plan invocation) | High | sprint-4 kickoff (this sprint plan already includes the discipline) |
| 2 | Sprint-4..6 = MVP First Chapter (장판파). Sprint-4 starts with ADR-0013 Camera + ADR-0014 Grid Battle Controller. Asset gathering (8 hero portraits + 2-3 BGM candidates) parallel-tracked. | claude (sprint-4 kickoff) | Critical | sprint-4 first commit |
| 3 | Prototype iteration is NOT to be repeated for SRPG concept validation. If a future visual-feel question arises, the answer is "ship a thin production slice", not "build a third wireframe". | (process discipline) | Medium | ongoing |
| 4 | Tighten estimate recalibration (retro AI #1 follow-up) — sprint-3 was 5d planned / 1d actual. Sprint-4 capacity is 5 working days; if this sprint ships in 1-2 days, sprint-5 plans for 3 working days max. | claude (sprint-4 retro) | Medium | sprint-5 kickoff |

## Snapshot

- **Sprint 1**: Platform 3/3 + Foundation 1/5 + 1 carry test
- **Sprint 2**: Foundation 4/5 + Core 1/4 + bonus turn-order full impl
- **Sprint 3**: Foundation 4/5 + Core 3/4 + Foundation 1/5 input-handling Ready scaffold + 2 prototypes shipped + pivot to MVP First Chapter
- **Sprint 4 ahead**: Camera + Grid Battle Controller (ADRs + first impl) + asset gathering — opens the path to actually-evaluatable surface in sprint-6

## Cross-References

- Pivot trigger conversation: this session 2026-05-02
- Prototype outputs: `prototypes/vertical-slice/REPORT.md` + `prototypes/chapter-prototype/REPORT.md` (REPORT.md was not written for chapter-prototype because the playtest pre-empted it; this retrospective absorbs that role)
- Sprint-4 plan: `production/sprints/sprint-4.md`
- Game concept the prototypes validated against: `design/gdd/game-concept.md`
