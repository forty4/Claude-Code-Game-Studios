## Retrospective: Sprint 2

Period: 2026-04-30 -- 2026-05-13 (planned) / 2026-04-30 -- 2026-05-02 (actual close-out, 11 days early)
Generated: 2026-05-02

### Sprint Goal Recap

Pivot from design-heavy ADR pipeline to **implementation tempo**: close Foundation
to **4/5** by ratifying balance-data + hero-database; scaffold hp-status / turn-order /
input-handling to Ready; resolve turn-order GDD invariant violation. Position
sprint-3 for Vertical Slice scene wiring.

**Goal achievement**: Foundation 4/5 ✅, balance-data ratified ✅, hero-database
ratified ✅, turn-order GDD revised ✅, turn-order epic scaffolded **AND fully
implemented (7/7 stories Complete)** as bonus scope-up. hp-status + input-handling
epics NOT scaffolded (deferred). Net: primary goal met + ~3d of sprint-3 work
pre-delivered.

### Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Tasks (story-level) | 10 | 7 + bonus | -3 / +bonus |
| Must Have completion | 5/5 | 5/5 | 100% |
| Should Have completion | 3/3 | 2/3 | 67% (S2-07 skipped) |
| Nice to Have completion | 2/2 | 0/2 | 0% (both skipped) |
| Estimated effort (planned scope) | 8.5d | 6.5d planned + ~3d bonus = 9.5d delivered | +1.0d throughput |
| Calendar days used | 14 | 3 (of 14) | -11d (finished early) |
| Commits | -- | 21 | -- |
| Tests added (full regression delta) | -- | +147 (501 → 648) | -- |
| Test errors / orphans | 0 / 0 | 0 / 0 | -- |
| Carried test failures | 1 (pre-existing) | 1 (same, not introduced) | unchanged |
| Bugs introduced | -- | 0 | -- |
| Tech debt entries logged | -- | +8 (TD-041..049, 1 resolved in-sprint) | net +7 |

### Velocity Trend

| Sprint | Planned | Completed | Calendar Days | Rate |
|--------|---------|-----------|---------------|------|
| Sprint 1 | 12 (effective DoD) | 12/12 + 5 ADRs out-of-plan | full window | 100% + scope-up |
| Sprint 2 (current) | 10 | 7 of 10 + bonus turn-order epic 7/7 | 3 of 14 | 70% planned + scope-up |

**Trend**: **Stable-with-scope-up**. Both sprints over-delivered on planned scope
by absorbing adjacent work (sprint-1: 5 out-of-plan ADRs; sprint-2: turn-order
epic full implementation). Calendar usage is wildly under-budgeted — sprint-2
finished in 3 of 14 days. Estimation is consistently pessimistic by ~3-4× on
calendar dimension.

### What Went Well

- **Ratification epics shipped clean**: balance-data 5/5 + hero-database 5/5 closed
  with zero defect rollback in shipped wrapper code (BalanceConstants relocation,
  hero_data formalization). Test surface grew 506 → 564 (hero-database) and
  501 → 506 (balance-data) without introducing regressions. Confirms strategic
  insight that ratification > greenfield risk.
- **Turn-order epic full implementation as scope-up**: ~3 days of unscheduled work
  shipped at production quality. 7 stories Complete with 22/22 TRs traced, 23/23
  GDD ACs covered (19 in-sprint + 4 deferred via TD-048 to Vertical Slice
  cross-system tests). Decision to absorb this scope-up was correct — turn-order
  had LOW engine risk vs input-handling's HIGH risk; bonus delivery moved VS gate
  closer.
- **Lean-mode review precedent solidified**: 5+ occurrences of orchestrator-direct
  /code-review verdict (no qa-lead/lead-programmer subagent spawn). Pattern is
  now unambiguously stable across damage-calc, unit-role, terrain-effect,
  hero-database, and turn-order epics.
- **Process discipline held under accelerated pace**: G-1..G-15 + TG-1/TG-2
  gotchas preempted at story scaffolding (not at /code-review). Convergent
  /code-review (gdscript-specialist + qa-tester parallel) pattern stable. No
  TG-2 sync incidents this sprint despite multiple `/clear` boundaries.
- **Tech-debt hygiene**: 8 new TD entries logged with full Severity/Origin/Owner/
  Reactivation/Resolution/Cost/References fields per the standing template. 1 entry
  (TD-046) resolved in-sprint via story-004 declare_action production seam test.
- **Same-patch obligation closure**: S2-06 turn-order GDD §Domain Boundary AI
  symbol reference forbidden_pattern was deferred to story-007 then closed via
  6th pattern registration in architecture.yaml + lint script wired into CI.
  Cross-doc obligation discipline held under scope-up pressure.

### What Went Poorly

- **Calendar estimation drastically pessimistic**: 14-day sprint completed in 3
  calendar days. Sprint-2 buffer (2 days for unplanned work) was 11d under-utilized.
  This is the second consecutive sprint where the calendar window was wildly
  loose. Risk: the buffer is masking estimation drift rather than absorbing
  variance — we don't know if a "real" 14d sprint would over-run because we keep
  finishing early. **Systemic cause**: estimates anchor to gut-feel hours, not
  calibrated against actual cycle time.
- **Should-Have items stratified poorly**: S2-07 (hp-status epic creation, 0.5d)
  was ready (S2-04 hero-database Complete unlocked the dependency) but got
  crowded out by turn-order scope-up. Should-Have priority discipline failed —
  bonus scope was implicitly elevated above declared Should-Have items without
  explicit re-plan. **Systemic cause**: no mid-sprint re-prioritization
  checkpoint when scope-up emerges.
- **Nice-to-Have items zero-delivered**: S2-09 (input-handling, HIGH engine risk)
  + S2-10 (hp-status story-001 begin) both 0/2. Defensible — input-handling
  HIGH risk warrants its own dedicated session — but the pattern of Nice-to-Have
  almost never landing means these slots are effectively decorative. Either tighten
  Nice-to-Have selection or stop including them.
- **Sprint-status.yaml `updated:` annotation has become a 2,500-character single
  line**: every story-done update concatenates context into a single field. The
  field is technically valid YAML but unreadable, defeats grep, and risks
  multi-line YAML parsing fragility. Pattern is observable in line 9 of the
  current file. **Systemic cause**: /story-done append-only updates don't have
  a rotation/truncation policy.
- **No mid-sprint /scope-check ran**: scope-up of turn-order full implementation
  doubled the sprint's actual delivery without a scope-check gate. The lean-mode
  PR-SPRINT skip was justified at kickoff but the absent mid-sprint check meant
  the scope expansion was ratified only retrospectively.

### Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| 1 carried test failure (`turn_order_advance_turn_test::test_round_lifecycle_emit_order_two_units`) | All sprint | NOT resolved this sprint — pre-existing from prior session, not introduced by sprint-2 work | Add to sprint-3 must-fix list; flag in /smoke-check as known-carry to prevent CI green-blocking confusion |
| Hero-database raw-JSON literal-duplicate-keys E2E test gap (story-002 EC-1 AC-7) | 1 story (story-003) | Story-002 marked AC-7 ADVISORY; story-003 BLOCKING follow-up; logged TD-043 for full Polish-phase coverage | Future raw-JSON validation epics: spike the literal-dup test seam in story-001 if validation pipeline is involved |
| Sprint-status.yaml updated-field length | All sprint | NOT addressed — pattern continued | See Action Items #3 below |

### Estimation Accuracy

| Task | Estimated | Actual | Variance | Likely Cause |
|------|-----------|--------|----------|--------------|
| Most underestimated: S2-08 turn-order /create-epics + /create-stories | 0.5d | 0.5d (epic creation) + ~3d (bonus full implementation) | +600% if counting bonus | Not a true overrun — explicit scope-up post-creation |
| Most overestimated: S2-04 hero-database implementation | 2.0d | ~1d actual | -50% | Ratification epics have lower implementation risk than estimated; provisional wrapper code already wired |
| S2-03 balance-data implementation | 2.0d | ~0.5d actual | -75% | Same — ratification, mostly path edits |
| S2-06 turn-order GDD revision | 0.75d | ~0.25d actual | -67% | Single Contract 5 prose block, not full GDD rewrite as estimated |

**Overall estimation accuracy on completed scope**: substantially overestimated
on per-task hours (5/5 Must-Have tasks finished at ~50-75% of estimate). Bonus
scope-up filled the gap without showing up in estimate-vs-actual since it was
unplanned.

**Adjustment recommendation**: cut ratification-epic implementation estimates
by 50%. Greenfield implementations should retain current estimate scale. Calendar
windows should shrink from 14d to 7d for design-pipeline-clean sprints.

### Carryover Analysis

| Task | Original Sprint | Times Carried | Reason | Action |
|------|----------------|---------------|--------|--------|
| S2-07 hp-status epic creation | Sprint 2 | 0 (skipped, not carried) | Crowded out by turn-order scope-up | Move to sprint-3 Must Have; trivial 0.5d |
| S2-09 input-handling epic creation | Sprint 2 | 0 (skipped, not carried) | HIGH engine risk warrants dedicated session | Move to sprint-3 or sprint-4 Should Have |
| S2-10 hp-status story-001 begin | Sprint 2 | 0 (skipped, not carried) | Depended on S2-07 | Roll forward as natural sequel to sprint-3 S2-07 equivalent |

No items recurring from prior sprints. Carryover discipline clean.

### Technical Debt Status

- Current TODO count in src/: **4** (no prior baseline — first measurement)
- Current FIXME count in src/: **0**
- Current HACK count in src/: **0**
- Tech debt register entries added this sprint: **8** (TD-041 through TD-049, of
  which TD-046 resolved in-sprint)
- Net debt growth: **+7 entries** (registry growth, not src/ comment growth)
- Trend: **Growing-but-tracked**. The register is the right place for non-trivial
  debt; the low src/ comment count (4 TODOs, 0 FIXMEs) suggests we are correctly
  promoting debt from inline comments to formal register entries.

**Areas of concern**:
- TD-035 (`save_perf_test.gd` flakes on shared CI runners) and TD-036 (gdUnit4-action
  Linux-only) carry over from sprint-1 — neither addressed this sprint.
- Polish-tier TDs (TD-044, TD-045, TD-047, TD-049) cluster around perf measurement
  on target devices. Vertical Slice gate will need a Polish-tier batch resolution
  pass.

### Previous Action Items Follow-Up

No prior retrospective exists. Sprint-1 effective DoD was reached without a
formal retrospective document. **This is the first formal retrospective** —
future sprints should reference this file's action items.

### Action Items for Next Iteration

| # | Action | Owner | Priority | Deadline |
|---|--------|-------|----------|----------|
| 1 | Recalibrate estimation: ratification-epic stories at 50% of current scale; calendar window 7d (not 14d) for design-clean sprints. Document in `/sprint-plan` skill or sprint-3 plan header. | claude (next /sprint-plan invocation) | High | sprint-3 kickoff |
| 2 | Add a mid-sprint `/scope-check` gate at the 50%-calendar mark. Even in lean mode, scope-up >25% of original estimate must be ratified before continuing. | claude (sprint-3 plan adds checkpoint) | High | sprint-3 kickoff |
| 3 | Refactor `production/sprint-status.yaml` `updated:` field policy: cap at 200 chars, archive older context to a sibling `sprint-status-history.md` file. Update `/story-done` skill to enforce. | claude (one-time housekeeping + skill edit) | Medium | sprint-3 mid-point |
| 4 | Sprint-3 must-fix: resolve `turn_order_advance_turn_test::test_round_lifecycle_emit_order_two_units` carried failure as story-001 of whichever epic touches the area, OR fix as a standalone hotfix story before sprint-3 main scope. | claude (sprint-3 plan includes carry-fix story) | High | sprint-3 first commit |
| 5 | Tighten Nice-to-Have selection: include only items that are credibly schedulable as 0.5d slots, not full epics. S2-09 (input-handling, HIGH engine risk) was misclassified as Nice-to-Have — should have been Should-Have or deferred. | claude (sprint-3 planning rule) | Medium | sprint-3 kickoff |

### Process Improvements

- **Mid-sprint scope-check gate** (Action Item #2): the strongest lever from this
  sprint. Even when finishing fast, an explicit checkpoint at the 50% mark
  catches scope-up drift and re-ranks Should-Have items against bonus work. Cost
  is ~10 minutes; benefit is preserving Should-Have integrity.
- **Estimation recalibration** (Action Item #1): ratification epics are now
  empirically 50% of estimated effort. Continued use of pre-calibrated estimates
  produces sprint windows that are 4× too long and erode the credibility of
  buffer planning.
- **Sprint-status.yaml hygiene** (Action Item #3): 2,500-char single-line YAML
  fields are a soft-fail of the human-readable contract. One-time cleanup +
  /story-done skill amendment is a small investment for ongoing audit clarity.

### Summary

**Sprint-2 was a strong over-delivery sprint**: primary goal (Foundation 4/5)
met on schedule, with a substantial scope-up (turn-order epic full implementation)
absorbed at production quality. The single most important change going forward
is **estimation recalibration with a mid-sprint scope-check gate** — finishing
in 3 of 14 calendar days twice in a row is a planning-discipline signal, not a
velocity badge. Sprint-3 should target a tighter 7-day window with explicit
mid-sprint checkpoint and pre-allocated capacity for the carried test failure
fix.

---

## File Provenance

- Generated by `/retrospective sprint-2`
- Source data: `production/sprints/sprint-2.md`, `production/sprint-status.yaml`,
  `git log 50a58d5^..HEAD`, `docs/tech-debt-register.md`, `production/session-state/active.md`
- Sprint-2 commit range: `50a58d5` (kickoff) → `66144d9` (turn-order epic terminal)
