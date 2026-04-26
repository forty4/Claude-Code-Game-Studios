# Sprint 1 — 2026-04-26 to 2026-05-10

> **Review mode**: lean (per `production/review-mode.txt`)
> **Manifest Version**: 2026-04-20 (`docs/architecture/control-manifest.md`)
> **Generated**: 2026-04-26

## Sprint Goal

Close the last in-flight Foundation/Core story, restart the ADR pipeline by ratifying **ADR-0012 Damage Calc** (highest-value consumer of terrain-effect's just-shipped API), and stand up the Damage Calc Feature epic to Ready state.

## Capacity

- Total days: 14 (calendar) → 10 working days
- Buffer (20%): 2 days reserved for unplanned work / regression / discovery
- Available: 8 working days

## Context

Project is in **early Production phase**. As of 2026-04-26:

- 4 epics fully Complete (gamebus, map-grid, save-manager, terrain-effect — totalling 33 stories shipped)
- 1 epic 6/7 Complete (scene-manager — story-007 target-device verification remaining)
- 4 Accepted ADRs cover Foundation layer (ADR-0001..ADR-0004, ADR-0008)
- Damage Calc GDD ratified at rev 2.9.3 (2026-04-20) — design-ready for ADR authoring
- Full regression: 294/294 PASS, 0 errors / 0 failures / 0 flaky / 0 orphans

The bottleneck for downstream Feature epics (Damage Calc, Formation Bonus, AI, Battle HUD) is now **ADR authoring**, not implementation capacity. This sprint shifts gears from terrain-effect's implementation tempo (~3 stories per session) to a design+architecture+implementation hybrid cadence.

## Tasks

### Must Have (Critical Path)

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S1-01 | Close `scene-manager` story-007 (target-device verification) — last in-flight story across all 5 originally-Ready epics | claude | 1.0 | scene-manager story-006 ✓ | Story Status=Complete; full regression PASS; PR merged; epic close-out updated |
| S1-02 | Admin: flip stale EPIC.md statuses on gamebus + map-grid + save-manager (all 3 epics' stories already Complete) + refresh `production/epics/index.md` | claude | 0.25 | — | 3 EPIC.md files show `Status: Complete (YYYY-MM-DD) — N/N stories done`; epics-index.md updated |
| S1-03 | Author **ADR-0012 Damage Calc** via `/architecture-decision` — Damage Calc rev 2.9.3 GDD ratified 2026-04-20; consumes terrain-effect's `get_combat_modifiers` + `max_defense_reduction` shared cap; orchestrates Bridge FLANK→FRONT via ADR-0004 §5b constants; F-DC-5 Formation block consumer with `P_MULT_COMBINED_CAP = 1.31` | claude (godot-specialist + systems-designer collab) | 2.0 | terrain-effect epic ✓; ADR-0004 §5b erratum ✓ | ADR-0012 in Proposed status with §Decision/§Consequences/§Performance Implications/§Validation Criteria; 21+ TR-IDs registered; godot-specialist sign-off |
| S1-04 | `/architecture-review` ADR-0012 delta (single-ADR check pattern proven on ADR-0004) → Accepted | claude | 0.5 | S1-03 | ADR-0012 status flipped Proposed → Accepted; tr-registry updated; control-manifest cross-references added |
| S1-05 | `/create-epics damage-calc` + `/create-stories damage-calc` | claude | 1.5 | S1-04 (ADR Accepted) | EPIC.md created with §Scope + §DoD + §Cross-System contracts; 7-9 stories with embedded TRs + ADR refs + ACs; story-readiness check passes |

**Must Have estimate**: 5.25 days

### Should Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S1-06 | Author **ADR-0009 Unit Role** (LOW risk per epics-index) — populates terrain-effect cost_matrix unit-class dimension; consumed by Damage Calc CR-2 Cavalry REAR ×1.09; class-coefficient schema | claude | 1.5 | unit-role.md GDD ✓ | ADR-0009 Proposed status; class-coefficient schema documented |
| S1-07 | `/architecture-review` ADR-0009 delta → Accepted | claude | 0.5 | S1-06 | ADR-0009 Accepted; tr-registry updated |
| S1-08 | Begin damage-calc story-001 (foundation Resource classes — `ResolveModifiers`, `DamageBreakdown`) via `/dev-story` | claude | 1.5 | S1-05 | Story Complete; tests pass; first damage-calc PR merged |

**Should Have estimate**: 3.5 days

### Nice to Have

| ID | Task | Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------|-----------|--------------|---------------------|
| S1-09 | Author **ADR-0006 Balance/Data** (MEDIUM risk — FileAccess 4.4 post-cutoff) — terrain-effect's `JSON.new().parse()` config loading already partly maps to this; standardize to a Foundation pipeline | claude | 1.5 | balance-data.md GDD ✓ | ADR-0006 Proposed status |
| S1-10 | TG-2 codification: codify "sub-agent Bash blocking pattern" (6 occurrences in terrain-effect epic) into `.claude/rules/tooling-gotchas.md` per pattern-stable threshold | claude | 0.25 | terrain-effect epic ✓ | TG-2 entry added; cross-references updated |

**Nice to Have estimate**: 1.75 days

## Carryover from Previous Sprint

None — this is Sprint 1.

## Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| ADR-0012 Damage Calc complexity (rev 2.9.3 = 9 review passes, 53 ACs, F-DC-1..F-DC-5 Formation block) requires more than 2 days to author | MEDIUM | HIGH (cascades to S1-04, S1-05, S1-08) | If scope exceeds 2 days at end of day 2, defer S1-08 → Sprint 2; protect S1-03 + S1-04 + S1-05 as Must Have |
| ADR-0012 review uncovers ratified-GDD/ADR drift requiring damage-calc.md rev 2.9.4 | LOW | MEDIUM | Use `/propagate-design-change` if triggered; budget 0.5d in buffer |
| scene-manager story-007 target-device verification needs hardware that's not available | MEDIUM | LOW | Defer to Polish per save-manager/story-007 + map-grid/story-007 + terrain-effect/story-008 precedent (would be 4th reuse of the deferral pattern) |
| TD-034 §A-K consolidated hardening pass not addressed this sprint | LOW | LOW | Already deferred at story-008 close; standalone hardening pass when ADR-0009 lands or convenient |

## Dependencies on External Factors

- None — all required GDDs Designed; all governing prior ADRs Accepted; no external infrastructure dependencies

## Definition of Done for this Sprint

- [ ] All Must Have tasks completed (5/5)
- [ ] ADR-0012 Damage Calc: Proposed → Accepted via /architecture-review
- [ ] Damage Calc Feature epic: EPIC.md + ≥7 story files Ready
- [ ] scene-manager story-007 closed (or Polish-deferred per precedent if hardware unavailable)
- [ ] 3 stale EPIC.md statuses flipped (gamebus + map-grid + save-manager) + epics-index refreshed
- [ ] No S1 or S2 bugs in shipped code
- [ ] Full regression suite still passes (≥294/294 baseline + any new tests from S1-01 + S1-08)
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA plan exists for damage-calc epic at `production/qa/qa-plan-damage-calc-YYYY-MM-DD.md` — author via `/qa-plan damage-calc` **after S1-05 completes** (project pattern is per-epic QA plans, not per-sprint; existing artifacts: `qa-plan-save-manager-2026-04-24.md` precedent)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint` or `/team-qa damage-calc` post-implementation)
- [ ] Design documents updated for any deviations
- [ ] Code reviewed and merged

## Phase Gates Skipped (Lean Mode)

Per `production/review-mode.txt = lean`:

- **PR-SPRINT** (Producer feasibility gate, Phase 4): SKIPPED. Self-assessment: Must Have load is 5.25 days against 8 available — comfortable margin. Should Have load adds 3.5 days (total 8.75) leaving negative buffer if Should Have fully consumed; that's fine because Should Have is by definition skippable. Risk #1 (ADR-0012 complexity) is the dominant scope-control lever.
- **Phase-gate spawns** during sprint execution: per-story `/dev-story` runs continue to skip QL-STORY-READY + QL-TEST-COVERAGE + LP-CODE-REVIEW; standalone convergent `/code-review` (gdscript + qa-tester parallel) remains the minimum-safe-unit pattern (validated 7+ times in the terrain-effect epic).

## Process Discipline Carried Forward From Prior Epics

These are the load-bearing patterns established during gamebus + terrain-effect that this sprint must preserve:

1. **Sweep + narrow re-review** is the minimum safe unit for numeric changes touching 2+ documents (validated 4 times across damage-calc revs 2.8.1, 2.9.0, 2.9.2, 2.9.3) — apply to ADR-0012 if any cross-doc value updates land
2. **Convergent /code-review (lean mode)** — both gdscript-specialist + qa-tester spawned in parallel; convergent findings applied without further deliberation; divergent findings each get specialist-domain treatment
3. **G-1..G-15 Godot/GdUnit4 gotchas** all codified — preempt at story scaffolding time, not at /code-review
4. **TG-1 gh CLI fork-vs-upstream** — always pass `--repo forty4/Claude-Code-Game-Studios` on `gh pr create`
5. **R1 commit + PR pattern** — one feature branch per story; commit message format `feat(<system>): story-NNN — short summary`
6. **Engine constraint quick-reference recommendation** (outstanding 6 epics now) — story templates should pre-list the most common engine-min constraints (`MAP_COLS_MIN/MAP_ROWS_MIN=15`, etc.); add to `/create-stories` skill template if convenient
7. **Sub-agent Bash blocking pattern** — orchestrator-direct verification chain after specialist file authoring; 6 occurrences in terrain-effect epic; pattern is load-bearing, TG-2 candidate (S1-10 nice-to-have)

## Next Steps

After sprint kickoff:

- `/qa-plan sprint` — **required before implementation begins on S1-01 / S1-08** — defines test cases per story
- `/story-readiness production/epics/scene-manager/story-007-target-device-verification.md` — validate before starting S1-01
- `/dev-story production/epics/scene-manager/story-007-target-device-verification.md` — begin S1-01
- `/architecture-decision damage-calc` — begin S1-03 (ADR-0012 authoring)
- `/sprint-status` — mid-sprint progress check
