# Sprint 5 Retrospective — 2026-05-03

> **Format**: lean (per `production/review-mode.txt`). Single-doc capture.
> **Sprint window**: 2026-05-17 to 2026-05-23 (planned) → effectively closed 2026-05-03 (15-21 calendar days ahead of deadline)
> **Final state**: **13/13 done** (Must-have 11/11 + Should-have 2/2; no Nice-to-have planned)
> **The sprint that closed grid-battle-controller end-to-end + opened the Presentation layer** (first Presentation-layer ADR + first Presentation-layer epic).

## Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Stories | 13 | 13 | 0 |
| Completion rate | — | 100% | — |
| Story-points (nominal days) | 4.20 | ~2.0 (calendar) | -2.20 (~2× faster) |
| Test cases added | +25 to +35 (AC target ≥780 PASS) | **+84** (757 → 841) | +49 over upper target |
| Failure-free baselines added this sprint | — | +10 (9th → 19th consecutive) | — |
| Commits | — | 13 (all pushed green) | — |
| Unplanned tasks added | — | 0 | — |
| Tasks descoped | — | 0 | — |
| Code health (current src/) | — | 6 TODOs / 0 FIXMEs | — |

## Velocity Trend

| Sprint | Planned items | Completed | Rate | Calendar days actual | Nominal/actual ratio |
|--------|--------------|-----------|------|---------------------|----------------------|
| Sprint-2 | 5 | 5 | 100% | ~1 day | (no plan→actual ratio recorded) |
| Sprint-3 | 7 | 7 | 100% | ~5 calendar days | ~5× faster than 5d nominal |
| Sprint-4 | 7 | 5 | 71% | 1 calendar day | ~5× faster than 5d nominal |
| Sprint-5 (current) | 13 | 13 | 100% | 2 calendar days | ~2× faster than 4.2d nominal |

**Trend**: Estimation accuracy **improving** (sprint-4 ~5× off → sprint-5 ~2× off). The deliberate scope-up to 13 items + the per-story commit cadence absorbed more nominal hours per actual day. Continued tightening is right call (retro AI #1 remains active for sprint-6).

## What Went Well

- **First Pillar 2 hidden semantic lock shipped** (`battle_hud_subscribes_to_hidden_fate_signal` forbidden_pattern in `docs/registry/architecture.yaml`). **First-of-kind project precedent**: a forbidden_pattern enforcing a *game-design pillar* (concept.md Pillar 2) at the source-code lint level. Prior lints were architectural; this one ratchets a *design constraint* to a *code constraint*. Establishes pattern for future pillar-anchored enforcement.
- **Pattern stability hit critical mass**: 5th invocation of battle-scoped Node form (HPStatus + TurnOrderRunner + Camera + GridBattleController + BattleHUD); 4th invocation of cross-ADR `_exit_tree` audit (TurnOrderRunner story-009 retrofit caught **actual latent leak** — not a false alarm; TD-057 RESOLVED with audit findings table); 10th invocation of `/architecture-review` delta cycle. Three patterns now declared *stable* with concrete repeat counts.
- **Drift-discovery-and-fix-during-implementation: 10 invocations across the epic, zero carry-forward debt**. Each story read shipped backend APIs fresh, flagged drift in ADR-0014 Implementation Notes amendment, shipped correct code + ADR amendment in same patch. The pattern is now the canonical integration-with-shipped-backends discipline for this codebase.
- **Per-story commit cadence held all 13 stories**. Same as sprint-4 camera epic. Reduces blast radius of regression rollback; enables clean TG-2 sync at every session boundary.
- **Sprint-4 retro AI #3 (godot-specialist as TD-ADR substitute) used in production for the first time on a UI-domain ADR** (ADR-0015 HIGH engine-risk Control + dual-focus + AccessKit). 3 BLOCKING revisions caught + resolved same-patch (`_exit_tree()` guard rationale + `_handle_signal args: Array` rationale + `_process` `set_process(false)` gating). Pattern stable at 3 invocations (ADR-0013 + ADR-0014 + ADR-0015).
- **`/clear` + active.md resume worked cleanly across 3 session boundaries** in this sprint (mid-sprint, post-must-haves, post-architecture-review). TG-2 sync gate caught no surprises. Pattern now stable at 3 invocations within sprint-5 alone.
- **Test additions beat plan by 2.4×**: qa-plan-grid-battle-controller projected +47-51 cases; actual was +84 (S5-02..S5-11 + S5-12 stub work). Coverage strength rather than scope creep.
- **Layer milestone**: Presentation layer 0/6 → 1/6 (battle-hud Ready); architecturally cracks open the 5 remaining Presentation modules (Battle Prep UI / Story Event UI / Main Menu / Battle VFX / Sound/Music) per architecture.md line 299.

## What Went Poorly

- **Estimation still 2× off** (4.2d nominal / ~2d actual). Improvement from sprint-4's 5× but retro AI #1 ratchet remains active. Sprint-6 must plan for 1.5-2d nominal max.
- **`/architecture-decision` + `/architecture-review` same-session ban is a real workflow tax**. ADR-0015 was authored S5-12 in one session; escalation Proposed → Accepted required `/clear` + fresh `/architecture-review` session (delta #10). Two-session ship instead of one. Workable but fragmented; affects the "ship an ADR" cycle time meaningfully.
- **Architecture-review structural backfill (~15 files + ~45 TRs across ADR-0013/0014/0015 era) DEFERRED** — explicit accepted debt. The lean delta-#10 architecture-review surfaced the gap but punted the work to a future explicit run. This debt now spans 3 ADRs (was 1 at ADR-0013 close); will get harder to backfill the longer it sits.
- **2 G-class gotchas re-hit during sprint** (G-4 lambda primitive-capture trap at story-007; G-7 silent skip at story-003 first attempt). Both already documented in `.claude/rules/godot-4x-gotchas.md`. The cost was low (caught + recovered in same patch each time) but it suggests the gotcha file isn't read pre-story-implementation. **The fix is procedural, not technical**: gotcha file should be skim-referenced at the start of each /dev-story for the affected category (lambda use → G-4; new test file → G-7).
- **`.claude/scheduled_tasks.lock` ephemeral file persists across sessions** without being in `.gitignore`. Harmless but visible in `git status -uno` at every session resume; produces low-grade noise. Not a sprint-5 issue per se but persistent.

## Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| ADR-0015 same-session ban (cannot `/architecture-decision` + `/architecture-review` in same session per skill rule) | ~1 session boundary (delta #10 ran fresh after S5-12 ship + commit) | Used the documented two-session pattern; checkpointed via active.md between sessions | None needed — this is a skill design rule, not a workflow defect. The cost is acceptable; alternative (combining the two skills) would weaken architectural review independence. |
| Story-009 cross-ADR `_exit_tree` audit found ACTUAL latent leak in TurnOrderRunner (not just a TD-057 false alarm) | Same patch (story-009: audit + retrofit + TD-057 RESOLVED in single commit `378adb5`) | Applied audit-then-retrofit Path B; shipped `_exit_tree()` retrofit + 2 GameBus disconnects + ADR-0008 amendment; full regression PASS | **Future cross-ADR audits should default to Path B** (audit + retrofit same patch) rather than Path A (audit + flag-for-future-fix). Path B is the now-validated pattern. |

## Estimation Accuracy

| Story | Estimated (days) | Actual (rough hours, calendar) | Variance | Likely Cause |
|-------|-----------------|-------------------------------|----------|--------------|
| S5-06 story-005 ATTACK chain (largest must-have) | 0.5d | ~1.5h | -3× | Drift-discovery pattern was already 4 invocations old by story-005; the integration shape was well-rehearsed. ResolveModifiers extension (R2 risk) was additive-only and hit no test breakage. |
| S5-09 story-008 hidden fate counters | 0.4d | ~1h | -3× | Counter logic was simpler than ADR §5 suggested once `_last_attacker_id` attribution pattern landed. The "hidden semantic preservation" structural test (AC-8) was the hardest part conceptually but small in code. |
| S5-12 ADR-0015 Battle HUD authoring | 0.4d | ~2h | -2× | Largest ADR in project to date for any single Presentation-layer module (~620 LoC). Came in faster than nominal because grid-battle-controller (~510 LoC ADR-0014) had set the template + 5-controller-LOCAL-signals contract was already real (not aspirational). |
| S5-13 battle-hud Presentation epic scaffold | 0.25d | ~1h | -2× | Scaffold pattern is ~5 invocations old now (turn-order + hp-status + camera + grid-battle + battle-hud); 530 LoC came together quickly from EPIC.md template. |

**Overall estimation accuracy**: 0/13 stories within ±20% of estimate (all came in 2-3× faster than planned). **Same direction as sprint-4 but smaller magnitude.** AI #1 (tighten estimation) remains the single most-needed process change.

## Carryover Analysis

| Task | Original Sprint | Times Carried | Reason | Action |
|------|----------------|---------------|--------|--------|
| Architecture-review structural backfill (~15 files + ~45 TRs) | sprint-5 (deferred from delta #10) | 0 (new debt) | Lean delta #10 explicitly deferred to "future explicit run" | Schedule explicit `/architecture-review` session in sprint-6 with ~2-3h budget; treat as standalone work item, not a delta |
| Hero portraits (8) | sprint-4 S4-05 → user-owner | 1 (sprint-4 → ongoing) | Taste-driven curation; user does in any spare 1-2h before sprint-6 chapter wiring | No action — user-owned; reminder in sprint-6 plan |
| BGM candidates (2-3) | sprint-4 S4-06 → user-owner | 1 (sprint-4 → ongoing) | Same as portraits | No action — user-owned; reminder in sprint-6 plan |

**Net carryover**: 1 new technical-debt item (architecture-review backfill), 0 incomplete work items.

## Technical Debt Status

- **Current TODOs in src/**: 6 (no prior recorded baseline — first explicit count)
- **Current FIXMEs in src/**: 0 (clean)
- **Current HACK markers in src/**: 0 (not measured this sprint; assumed 0)
- **Tech-debt register movement**: TD-057 RESOLVED 2026-05-03 (cross-ADR `_exit_tree` audit; ADR-0008 retrofit). Numbering jump 53 → 57 honored original cross-reference text. **Net debt: -1 register entry.**
- **New debt accepted**: architecture-review structural backfill (~45 TR-IDs + ~15 file edits across ADR-0013/0014/0015 era). Severity: **Low-Medium** (architectural traceability gap, not source-code defect; gets harder if untouched).
- **Trend**: **Slightly shrinking** for source-code debt (TD-057 closed, no new in src/); **slowly growing** for architectural-traceability debt (one new accepted-deferral item).

## Previous Action Items Follow-Up (Sprint-4)

| Action Item (from Sprint-4 retro) | Status | Notes |
|-----------------------------------|--------|-------|
| #1 Tighten estimation (sprint-5 plan for 2 working days max) | **PARTIAL** | Sprint-5 nominal was 4.2d (Must 3.55d + Should 0.65d); actual was ~2 days. Direction correct (sprint-4 was 5× off; sprint-5 is 2× off) but the Must+Should still ran 4.2d nominal, not 2d. **Carries to sprint-6 as AI #1.** |
| #2 Asset gathering (S4-05 + S4-06) to user before sprint-6 | DEFERRED — IN-FLIGHT | User-owned; not yet collected per active.md scan. **Reminder in sprint-6 plan.** Not blocking sprint-5 close. |
| #3 Standardize godot-specialist review as TD-ADR substitute for ALL future ADRs in lean mode | **DONE** | Used in ADR-0015 (S5-12); 3 BLOCKING revisions caught + resolved same-patch. Pattern now at 3 invocations. Skill amendment to `/architecture-decision` not yet applied — still opportunistic. |
| #4 Sprint-5 plan: ship grid-battle-controller + Battle HUD ADR + scaffold (target 757 → ~785 PASS) | **DONE — EXCEEDED** | 13/13 shipped; 757 → 841 PASS (+56 over the ~785 target); sprint-4 retro AI #4 fully discharged. |

**Score**: 3/4 actively addressed; AI #1 explicitly carries forward; AI #2 stays user-owned (passive deferral).

## Action Items for Next Iteration

| # | Action | Owner | Priority | Deadline |
|---|--------|-------|----------|----------|
| 1 | **Continue tightening estimation** (3rd consecutive carry) — sprint-6 plan for 1.5-2d nominal max. If shipped <1d, sprint-7 plans for 1d. Eventually converge on actual velocity. | claude (sprint-6 plan) | High | sprint-6 kickoff |
| 2 | **Schedule explicit `/architecture-review` structural-backfill session** — ~45 TR-IDs + ~15 file edits across ADR-0013/0014/0015 era. ~2-3h budgeted as standalone work item in sprint-6 (not as a delta tagged onto another session). | claude (in sprint-6 plan) | High | sprint-6 mid-sprint |
| 3 | **Sprint-6 primary work: Battle Scene wiring** — first true playable surface that consumes BattleCamera + GridBattleController + HPStatusController + TurnOrderRunner + (scaffold-stage) BattleHUD all together. The "playable-surface delta" target = +1 (sprint-4 was +1 with BattleCamera; sprint-5 was infrastructure with no +; sprint-6 returns to +1 or +2). | claude (sprint-6 plan) | Critical | sprint-6 first commit |
| 4 | **battle-hud `/create-stories` + `/qa-plan` early in sprint-6** (unblocked by ADR-0015 Accepted in delta #10). EPIC.md preview already documents 8-story decomposition; either ship now or include as sprint-6 first-week work. | claude (sprint-6 plan) | Medium | sprint-6 week 1 |
| 5 | **Procedural fix for G-class gotcha re-hits**: skim-reference `.claude/rules/godot-4x-gotchas.md` at the start of each `/dev-story` based on category (lambda use → G-4; new test file → G-7). Lightweight prevention vs. rediscover-and-fix. | claude (in `/dev-story` execution discipline) | Low-Medium | sprint-6 ongoing |

## Process Improvements

1. **Audit-then-retrofit Path B is now the canonical cross-ADR audit pattern** (validated at sprint-5 story-009 with TurnOrderRunner). Future TD-* entries that surface latent `_exit_tree`-style leaks should default to same-patch retrofit + register RESOLVED, not flag-for-future. Document in `.claude/rules/` next time the pattern fires.
2. **Pillar-anchored forbidden_pattern is a new architectural enforcement tier** — distinct from architectural-pattern lints. Ratchets *design constraints* into *code constraints*. Future pillars + design pillars in `design/gdd/game-concept.md` should be considered for forbidden_pattern coverage opportunistically (not exhaustively).

## Summary

Sprint-5 was **the sprint that closed the grid-battle-controller integration site and cracked open the Presentation layer**. 13/13 ships at 100% rate, +84 tests, 19 consecutive failure-free baselines, 0 carry-forward source-code debt, 1 latent leak found + fixed, and the **first Pillar 2 hidden semantic lock** establishes a new architectural enforcement tier. Estimation accuracy improved from 5× off to 2× off — the right direction; AI #1 carries to sprint-6.

The single most important thing for sprint-6: **return to playable-surface delta +1** (Battle Scene wiring) while paying down the deferred architecture-review structural-backfill debt before it spans 4 ADRs.

## Snapshot

- **Sprint 1**: Platform 3/3 + Foundation 1/5 + 1 carry test
- **Sprint 2**: Foundation 4/5 + Core 1/4 + bonus turn-order full impl
- **Sprint 3**: Foundation 4/5 + Core 3/4 + Foundation 1/5 input-handling Ready scaffold + 2 prototypes shipped + pivot to MVP First Chapter
- **Sprint 4**: ADR-0013 Camera + ADR-0014 Grid Battle Controller + camera Feature epic Complete (+1 playable-surface delta) + grid-battle-controller 10-story scaffold
- **Sprint 5**: grid-battle-controller 10/10 Complete + ADR-0015 Battle HUD Accepted + battle-hud Presentation epic Ready (Presentation 0/6 → 1/6)
- **Sprint 6 ahead**: Battle Scene wiring (the +1 or +2 playable-surface delta) + battle-hud impl + architecture-review structural backfill + 3 candidate ADRs (Battle Scene wiring / Scenario Progression / Destiny Branch)

## Cross-References

- Sprint plan: `production/sprints/sprint-5.md`
- Architecture-review delta #10: `docs/architecture/architecture-review-2026-05-03.md`
- ADR-0015 Battle HUD: `docs/architecture/ADR-0015-battle-hud.md`
- ADR-0014 Grid Battle Controller (10 Implementation Notes amendments): `docs/architecture/ADR-0014-grid-battle-controller.md`
- Battle HUD epic: `production/epics/battle-hud/EPIC.md`
- Grid Battle Controller epic (Complete): `production/epics/grid-battle-controller/EPIC.md`
- Tech-debt register (TD-057 RESOLVED): `docs/tech-debt-register.md`
- Verification summary (epic-terminal): `production/qa/evidence/grid_battle_controller_verification_summary.md`
- Sprint-status history: `production/sprint-status-history.md` (S5-* archive entries to be appended on next /story-done overflow)
- Prior retros: `production/retrospectives/retro-sprint-{2,3,4}-2026-05-02.md`
