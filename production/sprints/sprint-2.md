# Sprint 2 — 2026-04-30 to 2026-05-13

> **Review mode**: lean (per `production/review-mode.txt`) — PR-SPRINT director gate skipped
> **Manifest Version**: 2026-04-20 (`docs/architecture/control-manifest.md`)
> **Generated**: 2026-04-30

## Sprint Goal

Pivot from the design-heavy ADR pipeline to **implementation tempo**: close the Foundation layer to **4/5 epics Complete** by ratifying balance-data + hero-database (both have provisional wrapper code already shipped during sprint-1); scaffold the 3 newly-unblocked epics to Ready (hp-status, turn-order, input-handling); resolve the last GDD architecture-invariant blocker (turn-order). Position sprint-3 for Vertical Slice scene wiring.

## Capacity

- Total days: 14 calendar → 10 working days
- Buffer (20%): 2 days for unplanned work / regression / discovery
- Available: 8 working days

## Context

Project is in **mid Production phase**. As of 2026-04-30:

- **All 12 ADRs Accepted** — clean architecture surface (sprint-1 closed ADR-0006 in commit `2fa178b`)
- **6 epics Complete** (gamebus, scene-manager, save-manager, map-grid, unit-role, terrain-effect, damage-calc — 50+ stories shipped)
- **Foundation 2/5 Complete** (3 unblocked: balance-data, hero-database, input-handling)
- **Core 1/4 Complete** (2 unblocked: hp-status, turn-order; 1 deferred to VS: save-load)
- **Feature 1/13 Complete** (damage-calc — first Feature epic shipped)
- Full regression: **501/501 PASS** (per active.md unit-role epic close-out evidence)

The bottleneck for VS gate-PASS is now **(a) Foundation closure + (b) Core implementation + (c) playable scene wiring**, in that order. Sprint-2 closes (a) and scaffolds (b); sprint-3 begins (b)/(c).

**Strategic insight**: balance-data and hero-database are *ratification* epics — they wrap already-shipped provisional code (`src/feature/balance/balance_constants.gd` from damage-calc story-006b; `src/foundation/hero_data.gd` from unit-role epic) into formal modules per their ADRs. Lower implementation risk than greenfield; primary work is migration + test surface + lint gates.

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S2-01 | `/create-epics balance-data` + `/create-stories balance-data` (ADR-0006; ratifies existing `src/feature/balance/balance_constants.gd` wrapper) | claude | 0.5 | ADR-0006 Accepted ✓ | EPIC.md + 4-6 stories Ready with embedded TRs/ACs; epics-index.md updated |
| S2-02 | `/create-epics hero-database` + `/create-stories hero-database` (ADR-0007; ratifies existing `src/foundation/hero_data.gd` provisional wrapper) | claude | 0.5 | ADR-0007 Accepted ✓ | EPIC.md + 4-6 stories Ready; epics-index.md updated |
| S2-03 | Implement balance-data epic to Complete (~5 stories — relocate BalanceConstants `src/feature/balance/` → `src/foundation/`; FileAccess JSON load per 4.4 contract; provisional `get_const()` consumer migration; perf baseline; CI lint) | claude | 2.0 | S2-01 | All stories Complete; full regression PASS; epic Status=Complete |
| S2-04 | Implement hero-database epic to Complete (~5 stories — formalize HeroData class_name + 26-field schema; remove "provisional" attribution from unit-role + damage-calc soft-deps; data-loader test; integration test; perf baseline) | claude | 2.0 | S2-02 | All stories Complete; full regression PASS; epic Status=Complete |
| S2-05 | Admin: refresh `production/epics/index.md` to reflect post-sprint-2 state (Foundation 4/5; Core 1/4 + 2 Ready; remove resolved Pending entries; verify dependency snapshot + changelog entry) | claude | 0.25 | S2-03, S2-04 | Index reflects truth; changelog entry dated end-of-sprint |

**Must Have estimate**: **5.25 days**

### Should Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S2-06 | `turn-order.md` GDD revision — resolve architecture.md §1 invariant #4 violation (line 442 direct call into AI must invert to GameBus signal pattern); same-patch ADR-0011 amendment if signal contract shifts | claude | 0.75 | — | GDD Status flips Needs Revision → Designed (APPROVED); ADR-0011 amended if needed; architecture.md §1 blocker resolved |
| S2-07 | `/create-epics hp-status` + `/create-stories hp-status` (ADR-0010, Core layer; consumes ADR-0007 HeroData typed Resource) | claude | 0.5 | S2-04 (hero-database epic Complete unlocks HeroData formal type) | EPIC.md + 6-8 stories Ready |
| S2-08 | `/create-epics turn-order` + `/create-stories turn-order` (ADR-0011, Core layer) | claude | 0.5 | S2-06 (GDD revision) | EPIC.md + 6-8 stories Ready |

**Should Have estimate**: **1.75 days**

### Nice to Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S2-09 | `/create-epics input-handling` + `/create-stories input-handling` (ADR-0005, Foundation, **HIGH** engine risk — 4.6 dual-focus + SDL3 + Android edge-to-edge) | claude | 0.75 | — | EPIC.md + 5-7 stories Ready with HIGH-risk callouts per story |
| S2-10 | Begin hp-status story-001 (likely foundation Resource classes — `StatusEffect`, `HPState`) via `/dev-story` | claude | 0.75 | S2-07 | Story Complete; first hp-status PR merged; full regression PASS |

**Nice to Have estimate**: **1.5 days**

## Carryover from Previous Sprint

None — sprint-1 effective DoD reached 12/12 by 2026-04-30 (per `production/sprint-status.yaml` updated 2026-04-30). The originally-planned S1-09 ADR-0006 Acceptance landed today via commit `2fa178b` and is no longer pending.

**Out-of-plan sprint-1 work that feeds sprint-2**: ADR-0005/0007/0010/0011 were originally sprint-2 backlog; all reached Accepted in the sprint-1 window. Sprint-2 now consumes their downstream epics rather than authoring the ADRs.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| balance-data / hero-database stories surface latent defects in shipped wrapper code (BalanceConstants / hero_data.gd) | MEDIUM | LOW | Atomic stories — fix wrapper divergence in same story, don't bundle. Test surface already partly exists from damage-calc + unit-role test suites. |
| turn-order GDD revision triggers cross-doc cascade (battle-hud, grid-battle, hp-status all reference turn-order signals) | MEDIUM | MEDIUM | "Sweep + narrow re-review" minimum-safe-unit pattern (validated 4× in damage-calc revs 2.8.1/2.9.0/2.9.2/2.9.3). Budget 0.5d in buffer. |
| input-handling HIGH engine-risk (4.6 dual-focus + SDL3 + Android edge-to-edge) surfaces requirements that block other epics | LOW | HIGH | S2-09 scoped to **epic creation only** — defer first impl stories to sprint-3. Don't gate any Must Have item on input-handling. |
| Velocity miscalibration — sprint-1 was design-heavy (ADR pipeline); sprint-2 is implementation-heavy (epic shipping). Estimates may be optimistic. | MEDIUM | MEDIUM | Buffer protects; defer S2-09 + S2-10 first if needed. Convergent /code-review (gdscript + qa-tester parallel) is minimum safe unit. |

## Dependencies on External Factors

- None — all required GDDs Designed except `turn-order.md` (Needs Revision; S2-06 addresses in-sprint); all required ADRs Accepted; full regression baseline 501/501 stable.

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed (5/5)
- [ ] balance-data epic: Status=Complete (Foundation 2/5 → 3/5)
- [ ] hero-database epic: Status=Complete (Foundation 3/5 → 4/5)
- [ ] hp-status, turn-order epics: EPIC.md + ≥6 stories each Ready
- [ ] turn-order.md GDD: Needs Revision → Designed (APPROVED) — architecture.md §1 invariant #4 blocker resolved
- [ ] No S1 or S2 bugs in shipped code
- [ ] Full regression suite still passes (≥501/501 baseline + new tests from S2-03 + S2-04 + optional S2-10)
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA plans exist for new epics: `production/qa/qa-plan-balance-data-YYYY-MM-DD.md`, `qa-plan-hero-database-YYYY-MM-DD.md` (per-epic pattern; precedents qa-plan-damage-calc / qa-plan-save-manager)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa balance-data` + `/team-qa hero-database`)
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged
- [ ] `production/epics/index.md` refreshed (S2-05)

## Phase Gates Skipped (Lean Mode)

Per `production/review-mode.txt = lean`:

- **PR-SPRINT** (Producer feasibility gate, Phase 4): SKIPPED. Self-assessment: Must Have 5.25d against 8d available — comfortable margin. Should Have adds 1.75d (7.0d total) leaves 1.0d buffer; Nice to Have +1.5d eats buffer if fully consumed (acceptable — Nice to Have is by definition skippable). Risk #4 (velocity miscalibration) is the dominant scope-control lever.
- **Per-story phase-gates** during execution: continue to skip QL-STORY-READY + QL-TEST-COVERAGE + LP-CODE-REVIEW; standalone convergent `/code-review` (godot-gdscript-specialist + qa-tester parallel) remains the minimum safe unit (validated 10+ times across damage-calc + unit-role + terrain-effect epics).

## Process Discipline Carried Forward

These load-bearing patterns from sprint-1 must be preserved:

1. **Sweep + narrow re-review** — minimum safe unit for numeric/contract changes touching 2+ documents (validated 4× in damage-calc; apply to S2-06 turn-order GDD revision)
2. **Convergent /code-review** — gdscript-specialist + qa-tester spawned in parallel; convergent findings auto-applied
3. **G-1..G-15 + TG-1/TG-2 gotchas** — preempt at story scaffolding, not at /code-review
4. **R1 commit + PR pattern** — one feature branch per story; commit format `feat(<system>): story-NNN — short summary`
5. **Provisional-dependency strategy** — proven 3× (ADR-0008→0006, ADR-0012→0006/0009/0010/0011, ADR-0009→0007). Sprint-2's ratification epics complete the migration triggers documented in those ADRs.
6. **Polish-deferral pattern** — proven 5× for hardware-dependent stories. Apply to S2-09 input-handling stories that touch SDL3/Android.
7. **Skill 7 fresh-session rule** — `/architecture-review` MUST run in a fresh session. (No Proposed ADRs remain — non-issue this sprint unless turn-order GDD revision triggers ADR-0011 amendment requiring re-review.)

## Next Steps

After sprint kickoff:

- **`/qa-plan balance-data`** + **`/qa-plan hero-database`** — required before S2-03 / S2-04 implementation begins
- `/story-readiness production/epics/balance-data/story-001-*.md` — validate before starting first story
- `/dev-story production/epics/balance-data/story-001-*.md` — begin S2-03 implementation
- `/sprint-status` — mid-sprint progress check
- `/scope-check balance-data` (or hero-database) — verify no scope creep before implementation

> **Scope check**: If this sprint adds stories beyond the original epic scope (after `/create-stories` runs), run `/scope-check [epic]` to detect creep before implementation begins.
