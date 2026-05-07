# Sprint 11 — 2026-05-07 to 2026-05-09 (3-day window)

> **Generated**: 2026-05-07 (post-/retrospective sprint-10 close; commit `3481d18`)
> **Mode**: lean (`production/review-mode.txt` = `lean`)
> **Velocity model** (validated sprint-9 + sprint-10 + sprint-10 retro AI #4): closure ÷3, greenfield ÷5, admin/decision ÷3 — projected sprint-11 actual ~1 calendar day from ~2.2d nominal

## Sprint Goal

Codify the sprint-10 process patterns (drift-correction at /story-readiness + EPIC+index Status enforcement + production/decisions/ convention) + absorb sprint-10 carryover via cut/descope/keep sweep + run /story-readiness on destiny-branch + ai-system Core epics to catch potential 3rd + 4th activation of retro AI #3 — targets Core layer epic graduation completeness which may trigger Pre-Production → Production gate eligibility evaluation.

## Capacity

- Total days: 3
- Buffer (20%): 0.6d reserved
- Available: 2.4d nominal
- Projected actual via mixed-mode multiplier: ~0.7-1.0 calendar day (4 closure × ÷3 + 5 admin × ÷3 + 0 greenfield)

## Tasks

### Must Have (Critical Path) — sprint-10 retro AI codifications + carryover absorption + epic graduation backfills

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S11-01 | **Codify drift-correction at /story-readiness as standing pre-flight check** (BACKFILL CLOSE-OUT new verdict flavor) — extends `.claude/skills/story-readiness/SKILL.md` Phase 3 §Open Questions w/ "story-file Status header mismatch with sprint-status.yaml row" early-exit; bundles S10-11 sprint-plan template refinement (1st carryover) for `carryover-backlog` template section codification | claude | 0.3 | — | Skill file updated; new verdict BACKFILL CLOSE-OUT documented w/ trigger conditions + required actions; bundle S10-11 sprint-plan template carryover-backlog section codified per sprint-9 retro AI #2 (must list deferred items in dedicated section ahead of new scope) |
| S11-02 | **Run /story-readiness on destiny-branch + ai-system epics** — catch potential 3rd + 4th activation of retro AI #3; backfill EPIC.md + index.md Status flips if drift confirmed (orig work shipped at sprint-7 S7-03 + S7-04 per sprint-status-history line 146-147) | claude | 0.2 | S11-01 (BACKFILL CLOSE-OUT verdict in skill) | Both epics' /story-readiness verdicts documented; if drift confirmed, doc-only graduation flips applied (mirroring S10-04 BACKFILL pattern); Core layer epic count progresses toward 5/5 Complete |
| S11-03 | **Audit `.claude/skills/story-done/SKILL.md` Phase 7** for EPIC.md + index.md Status update enforcement (S10-04 root cause analysis); add post-close consistency lint OR explicit checklist step if gap found | claude | 0.3 | — | Audit doc at `production/process-audits/story-done-phase-7-audit-2026-05-XX.md`; if enforcement gap found, codify in skill or via new lint at `tools/ci/lint_story_status_consistency.sh` (compares story Status / sprint-status.yaml row / EPIC.md row / index.md row) |
| S11-04 | **Carryover absorption sweep** — execute cut + descope + keep + bundle decisions per sprint-10 retro AI #5: CUT S10-10 + S10-12; DESCOPE S10-07 (3 stubs → 1 stub); BUNDLE S10-08 with future chapter-1 first text rendering story; KEEP S10-06 (Should) + S10-09 (Should) + S10-07-descoped-1 (Nice); carry USER-OWNED S10-13 + S10-14 unchanged | claude | 0.1 | — | Sprint-10 retro AI #5 closed; sprint-11 backlog reflects cut/descope/keep decisions in sprint-status.yaml + this sprint plan; carryover-concentration AI #2 threshold reset to ≤4 |

**Must-have subtotal: 0.9d nominal → ~0.3d actual projected** (4 closure-mode tasks × ÷3 multiplier)

### Should Have — production/decisions/ convention + Polish-tier tracking + carryover absorption

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S11-05 | **Codify `production/decisions/` directory convention** — decide approach: (a) sibling skill `/decision-record`, (b) extend `/architecture-decision` for non-architectural binding decisions, OR (c) standalone process doc. Document artifact format (4-trigger reactivation + cost-benefit table + amendment log structure) | claude | 0.3 | S10-05 precedent (`production/decisions/ci-lane-gap-decision-2026-05-07.md`) | Convention doc written; artifact format codified; skill route decision recorded |
| S11-06 | **Establish `production/polish-backlog.md`** for 5 ADVISORY deferrals from battle-hud closure + future Polish-tier carry-forwards | claude | 0.2 | — | File created at `production/polish-backlog.md` w/ 5 ADVISORY entries from `production/qa/evidence/battle_hud_verification_summary.md` + entry format defined for future additions |
| S11-07 | **S10-06 carryover — Save/Load #17 Core epic creation OR ratification** (1st-time carryover) — verify against existing save-manager Platform epic (8/8 Complete since 2026-04-24); if Save/Load #17 GDD adds new schema/contract not implemented, run `/create-epics save-load`; if GDD ratifies existing impl, flip systems-index row 17 Designed → Implemented | claude | 0.3 | — | Either NEW save-load Core epic at `production/epics/save-load/EPIC.md` w/ 1-3 stories ready for sprint-12, OR systems-index row 17 confirmed ratified-by-existing-impl with no impl gap |
| S11-08 | **S10-09 carryover — Main menu UX spec stub** at `design/ux/main-menu.md` (2nd-time carryover) — minimal information architecture + key states + accessibility tier compliance per Intermediate tier | claude (or ux-designer) | 0.2 | — | UX spec created with 8-section template; references `accessibility-requirements.md` Intermediate tier; AD-C6 ADVISORY closed in next gate-check |

**Should-have subtotal: 1.0d nominal → ~0.3d actual projected**

### Nice to Have — TODO triage + naming convention + descoped stub + USER-OWNED carryover

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S11-09 | **S10-07 descoped — 1 character visual profile stub (유비)** — descoped from 3 stubs to 1; closes AD-C5 to "first-stub-shipped" partial state | claude (or art-director) | 0.1 | — | `design/art/characters/liu-bei.md` w/ Section 1-3 minimum (silhouette + costume + role-anchor) |
| S11-10 | **Codify same-day double-sprint-close naming convention** (`smoke-sprint-N-DATE.md` / `qa-plan-sprint-N-closure-DATE.md` / `qa-signoff-sprint-N-DATE.md`) per sprint-10 retro AI #6 | claude | 0.1 | — | Convention added to `.claude/skills/smoke-check/SKILL.md` + `.claude/skills/team-qa/SKILL.md` Phase 6 path-resolution rule |
| S11-11 | **TODO triage pass** — count stalled at 5 for 2 consecutive sprints (sprint-9 + sprint-10); classify each as Address / Defer-with-context / Remove | claude | 0.1 | — | TODO count documented per-item at `production/process-audits/todo-triage-2026-05-XX.md`; each carries Address/Defer/Remove decision + rationale |
| S11-12 | **S10-13 USER-OWNED carryover** — S7-11 user attestation pass on 4 VS Validation items in `prototypes/chapter-prototype/REPORT.md` (4th-time carryover; refusal-to-fabricate posture continues) | user | 0 | — | User attestation captured |
| S11-13 | **S10-14 USER-OWNED carryover** — S8-15 user attestation pass on sprint-8 manual smoke check Batches 1+3 (2nd-time carryover) | user | 0 | — | User attestation captured |

**Nice-to-have subtotal: 0.3d nominal → ~0.1d actual projected (excluding USER-OWNED)**

### Cuts (per S11-04 carryover absorption decision)

| Story | Reason for Cut |
|---|---|
| **S10-10** Pillar 4 chapter-2 scoping (2nd carryover; CUT CANDIDATE per sprint-status.yaml) | Out-of-scope for current MVP focus; sprint-9 retro AI #2 visibility threshold breached; chapter-2 authoring deferred to post-chapter-1-content sprint when forcing function appears |
| **S10-12** InputContext sentinel migration (1st carryover; CUT CANDIDATE per sprint-status.yaml) | No forcing function; hardening pass without urgency; awaits Vector2i.ZERO collision case before reactivation |
| **S10-08** 緣 font glyph check (BUNDLED, not cut) | Reactivates as part of future chapter-1 first-text-rendering story; not standalone in sprint-11 |
| **S10-07** (full 3 stubs DESCOPED to 1 stub via S11-09) | 2-carryover threshold breached; 1 stub closes AD-C5 to partial state without sprint-11 over-commitment |

## Carryover from Previous Sprint (sprint-10 → sprint-11)

| Sprint-10 Task | Reason | Sprint-11 Disposition |
|---|---|---|
| S10-06 Save/Load #17 ratification | 1st-time carryover from sprint-9 S9-06 | Sprint-11 S11-07 (Should; 0.3d) |
| S10-07 Character profile stubs | 2nd-time carryover; visibility threshold | Sprint-11 S11-09 DESCOPED (Nice; 0.1d) |
| S10-08 緣 font glyph check | 2nd-time carryover | BUNDLED into future story |
| S10-09 Main menu UX spec | 2nd-time carryover from S9-09 | Sprint-11 S11-08 (Should; 0.2d) |
| S10-10 Pillar 4 chapter-2 scoping | 2nd-time carryover; CUT CANDIDATE | **CUT** |
| S10-11 Sprint-plan template refinement | 1st-time carryover from S9-12 | BUNDLED into S11-01 (codification chunk) |
| S10-12 InputContext sentinel migration | 1st-time carryover; CUT CANDIDATE | **CUT** |
| S10-13 S7-11 user attestation | 4th-time USER-OWNED carryover | Sprint-11 S11-12 (USER-OWNED) |
| S10-14 S8-15 user attestation | 2nd-time USER-OWNED carryover | Sprint-11 S11-13 (USER-OWNED) |

## Risks

| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| **R1 — Backfill cascade**: S11-02 might trigger more drift catches than just destiny-branch + ai-system if /story-readiness audit reveals more old epics with stale status | Medium | Low (good problem) | Time-box S11-02 to 0.2d; if >2 backfills surface, defer overflow to sprint-12; document additional drift catches as sprint-11 retro AI seed |
| **R2 — /story-done Phase 7 audit (S11-03) may surface deeper skill bugs** requiring more than 0.3d to fix | Low-Medium | Medium | Descope S11-03 from "audit + add lint" → "audit only + document gaps" if 0.3d budget insufficient; lint authoring becomes sprint-12 candidate |
| **R3 — production/decisions/ convention codification (S11-05) may interact with /architecture-decision skill in unforeseen ways** | Low | Low | Design-only ratification acceptable as MVP; full skill integration deferrable to sprint-12 |
| **R4 — Carryover absorption cuts (S11-04) may face user pushback** on S10-10 or S10-12 | Low | Low | Surface cut decisions to user before applying; default to KEEP if user has not explicitly indicated cut preference |
| **R5 — Pre-Production → Production gate eligibility** depends on Core layer 5/5 Complete; if S11-02 backfill catches reveal additional design questions, gate trigger may slip | Medium | Medium | Sprint-11 retrospective will validate gate-check delta; if blocked, sprint-12 absorbs gate-check pass |
| **R6 — Mixed-mode velocity multiplier may degrade** under all-closure-mode sprint (sprint-11 has 0 greenfield stories) | Low | Low | Closure 3× baseline already validated in sprint-9; sprint-11 expected to track same |

## Dependencies on External Factors

- User attestation gates S11-12 + S11-13 require user direct action (refusal-to-fabricate posture unchanged; not a claude-side dependency)
- /story-readiness BACKFILL CLOSE-OUT verdict (S11-01) unblocks S11-02 — sequential dependency (S11-01 must ship before S11-02 starts)

## Sprint-11 Retro AI seed (carry from sprint-10 retro)

- **AI #1** (sustained from sprint-7→8→9→10→11): Codification debt MUST be paid at retro time
- **AI #2** (sustained from sprint-9→10→11): Carryover concentration threshold ≥4 — validate sprint-11 holds threshold post-absorption sweep
- **AI #3** (sustained from sprint-9→10→11): Story-spec doc-correction at /story-readiness time — sprint-11 codifies as standing check (S11-01) + applies to destiny-branch + ai-system (S11-02)
- **AI #4** (validated sprint-10): Mixed-mode velocity multiplier (closure 3× / greenfield 5× / admin 3×) — sprint-11 re-validate with new mix (sprint-11 is closure-only + admin-heavy)
- **AI #5 NEW**: Pre-Production → Production gate trigger evaluation — if S11-02 yields full Core layer 5/5 Complete, validate gate-check pass (potentially flips `production/stage.txt` Pre-Production → Production)

## Definition of Done for this Sprint

- [ ] All Must Have tasks (S11-01..S11-04 = 4 stories) completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists for sprint-11 (closure-style addendum or standard sprint plan acceptable; sprint-11 is process/skill/doc-heavy with minimal new-test requirements)
- [ ] All Logic/Integration stories have passing unit/integration tests (likely 0 sprint-11 stories require new tests — process/skill/doc work dominant)
- [ ] Smoke check passed (`/smoke-check sprint`) — 1236+ baseline preserved
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Code reviewed and merged
- [ ] **Sprint-10 retro AIs closed** (verify sprint-10 retro action items 1-7 status flips Open → Done)
- [ ] **Pre-Production → Production gate eligibility re-evaluated** if Core layer 5/5 Complete via S11-02 backfills

---

> **Pre-flight check applied** (sprint-7 retro improvement #1, now 5-sprint-stable discipline + sprint-10 retro AI #3 codification): S11-01..S11-13 verified — sprint-11 stories are ALL process/skill/doc work or carryover absorption (no greenfield implementation that would benefit from `/story-readiness` validation against story files; story-readiness applies at S11-02 against destiny-branch + ai-system EPIC files which are already authored). S10-04 BACKFILL precedent demonstrates `/story-readiness` works for already-shipped graduation backfills as well as fresh-impl readiness — sprint-11 leverages both verdicts (READY for fresh stories + BACKFILL CLOSE-OUT for already-shipped).

> **Scope check note**: If sprint-11 ends up adding any unplanned stories beyond this list, run `/scope-check [epic]` to detect scope creep before implementation begins. Per sprint-10 retro pattern of zero-blocker close-mode sprints, scope creep risk is low.
