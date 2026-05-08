## Smoke Check Report

**Date**: 2026-05-09
**Sprint**: 12 (close-out gate; 3-day window 2026-05-09 → 2026-05-11; Day 1 — claude-side saturation)
**Engine**: Godot 4.6.2 stable official
**QA Plan**: production/qa/qa-plan-sprint-12-2026-05-08.md
**Argument**: sprint
**Mode**: sprint-close (per S11-10 naming convention; sprint-N- prefix mandatory)

---

### Automated Tests

**Status**: PASS (1273 tests, 1273 passing, 130/130 suites)

- 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans
- Execution: 18s 792ms
- Runner: `godot --headless --path . -s addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a tests/unit -a tests/integration --continue` (env `SKIP_PERF_BUDGETS=1`)
- **64th consecutive failure-free baseline (FFB)** preserved (was 63rd at S12-06 close `1ca72a1`)
- ObjectDB-leaked-at-exit warning observed (cosmetic; benign across all 64 FFB runs)

---

### Test Coverage

| Story | Type | Test File / Evidence | Coverage Status |
|-------|------|---------------------|-----------------|
| S12-01 — /create-stories save-load | Config/Data | 3 story files at `production/epics/save-load/story-001..003-*.md` | EXPECTED |
| S12-02 — Pillar-4 atmospheric demo | Integration | `tests/integration/chapter_prototype/atmospheric_moment_test.gd` (7 tests) | COVERED |
| S12-03 — gate-check rerun | Config/Data | `production/gate-checks/pre-prod-to-prod-2026-05-08-rerun.md` (CONCERNS; items 3a + 3b CLOSED at `287e986`) | EXPECTED |
| S12-04 — lint_story_status_consistency 33-drift cleanup + CI wire | Config/Data | `tools/ci/lint_story_status_consistency.sh` (Exit 0 verified at smoke time); CI wired in `.github/workflows/tests.yml` | COVERED (lint serves as test evidence) |
| S12-05 — TODO triage Address bundle | Config/Data | `grep -rn TODO src/` returns 2 (was 5; matches AC) | COVERED (verified at smoke time) |
| S12-06 — §11 USER-OWNED 5th-carry HARD GATE | Config/Data | `docs/process/decisions-convention.md` §11 (315 LoC; +77) | EXPECTED |
| S12-07 — closure-mode sprint HYBRID adoption | Config/Data | `production/decisions/closure-mode-sprint-pattern-2026-05-09.md` | EXPECTED |
| S12-08 — POLISH-006 entry | Config/Data | `production/polish-backlog.md` POLISH-006 row (Guan Yu + Zhang Fei stubs deferred) | EXPECTED |
| S12-09 — lint_sprint_carryover_count.sh + CI wire | Config/Data | `tools/ci/lint_sprint_carryover_count.sh` (Exit 0 verified at smoke time); CI wired | COVERED (lint serves as test evidence) |
| S12-10 — S7-11 USER-OWNED (5th-carry) | USER-OWNED | OUT OF SCOPE per refusal-to-fabricate posture | EXPECTED (USER-OWNED) |
| S12-11 — S8-15 USER-OWNED (3rd-carry) | USER-OWNED | OUT OF SCOPE per refusal-to-fabricate posture | EXPECTED (USER-OWNED) |

**Summary**: 4 covered (S12-02 integration test; S12-04/09 lint scripts; S12-05 TODO grep), 7 expected (5 Config/Data process artifacts + 2 USER-OWNED), 0 missing, 0 manual-only.

**No MISSING entries.** All claude-owned stories have appropriate evidence per QA plan §Test Summary.

---

### Manual Smoke Checks

- [-] Game launches to main menu without crash — NOT CHECKED (closure-mode; relying on automated evidence)
- [-] Chapter-prototype scene loads end-to-end — NOT CHECKED (covered by S12-02 integration test)
- [-] Main menu responds to all inputs — NOT CHECKED
- [-] S12-02 Pillar-4 atmospheric demo player-facing — NOT CHECKED (automated integration test PASSED; CD playtest deferred to S12-10/11 gate)
- [-] Previous sprint's features still work (no regressions) — NOT CHECKED (1273/1273 automated suite confirms logic regressions absent)
- [x] **lint_story_status_consistency Exit 0** — PASS (verified at smoke time)
- [x] **lint_sprint_carryover_count Exit 0** — PASS (verified at smoke time)
- [-] Save / load round-trip — NOT CHECKED (sprint-12 introduced no save-substrate changes; sprint-11 baseline preserved)
- [-] Frame-rate / performance — NOT CHECKED (S12-02 atmospheric moment is the only runtime addition; integration test passes)
- [x] **47-streak in-patch sprint-status hygiene** — PASS (verified via active.md + git log; sustained across 5 commits today `c3f3ca9` → `1ca72a1`)
- [x] **TODO count drop 5 → 2** — PASS (verified at smoke time; S12-05 AC satisfied)
- [x] **47-streak hygiene close + 64 FFB** — PASS (test baseline reaffirmed at smoke time)

**Manual attestation rationale**: sprint-12 is dominantly closure/admin (8 Config/Data + 1 Integration + 2 USER-OWNED). The only runtime addition is S12-02 (Pillar-4 atmospheric moment), which is fully covered by `tests/integration/chapter_prototype/atmospheric_moment_test.gd` (7 tests; PASSED in suite run at smoke time). User opted to rely on automated evidence + claude-verified lints rather than perform per-batch manual attestations — consistent with closure-mode posture.

---

### Missing Test Evidence

**None.** All Logic and Integration stories have test coverage:
- S12-02 (Integration) → `tests/integration/chapter_prototype/atmospheric_moment_test.gd` (7 tests, all PASS)

Config/Data stories rely on suite preservation (1273/1273) + lint scripts (Exit 0); USER-OWNED stories are OUT OF SCOPE per refusal-to-fabricate posture.

---

### Verdict: PASS WITH WARNINGS

**Rationale**:
- Automated test suite: 1273/1273 PASS (FAIL condition NOT MET)
- All Batch 1 / Batch 2 / Batch 3 manual checks: NOT CHECKED (no FAIL recorded; treated as warning per skill rule "Never treat NOT RUN as automatic FAIL")
- Coverage: 0 MISSING entries; all stories have evidence per QA plan
- Lints: both newly-added lints (S12-04 + S12-09) verified Exit 0 at smoke time

**Warnings (advisory; not blocking sprint-close hand-off)**:
1. Manual smoke Batches 1/2/3 NOT RUN — closure-mode posture acknowledged; relying on automated evidence. If `/gate-check pre-prod-to-prod` rerun (S12-03) requires player-facing attestation, those user-time gates will surface there.
2. **S12-10 (S7-11 5th-carry) and S12-11 (S8-15 3rd-carry) USER-OWNED items still pending** — these are gate-check path-to-PASS items 1 + 2; smoke-check is silent on them per refusal-to-fabricate posture.
3. **S12-03 close-gate rerun** at sprint-12 close will return CONCERNS (not PASS) until items 1 + 2 above resolve.

**QA hand-off path**: clean to advance to `/qa-plan` (closure addendum) → `/qa-signoff` → `/retrospective` for sprint-12. The PASS WITH WARNINGS verdict does not block QA hand-off; it records advisory gaps for the gate-check rerun to surface.

---

### Cross-references

- QA plan source: `production/qa/qa-plan-sprint-12-2026-05-08.md`
- Sprint plan: `production/sprints/sprint-12.md`
- Sprint-status canonical: `production/sprint-status.yaml`
- Active session state: `production/session-state/active.md`
- Prior smoke (sprint-11 closure): `production/qa/smoke-sprint-11-closure-2026-05-08.md`
- Naming convention codification: `.claude/skills/team-qa/SKILL.md` Phase 3 (S11-10 commit `045ce98`)
- USER-OWNED 5th-carry HARD GATE rule: `docs/process/decisions-convention.md` §11 (S12-06 commit `1ca72a1`)
- Closure-mode HYBRID pattern: `production/decisions/closure-mode-sprint-pattern-2026-05-09.md` (S12-07 commit `784cef3`)
