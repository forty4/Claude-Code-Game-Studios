# QA Plan — Sprint-13 Closure (Addendum to Entry-Time Plan)

> **Date**: 2026-05-09 PM late
> **Scope**: Sprint-13 close ceremony — delta from entry-time `production/qa/qa-plan-sprint-13-2026-05-09.md` (10-story 100% non-runtime closure-mode profile authored at sprint-13 entry per `cc83581`).
> **Reason for addendum**: mid-sprint amendment introduced 2 NEW Logic-tier stories (S13-11 + S13-12) NOT in entry plan; user-time attestation gates (S13-02 + S13-10) executed with mixed outcomes; gate-check rerun-2 surfaced new path-to-PASS items. Entry-plan's 100% non-runtime profile is no longer accurate at close.
> **Mode**: sprint-close (parallel to sprint-12 closure precedent at `production/qa/qa-plan-sprint-12-closure-2026-05-09.md`)

---

## Story Classification Table (post-amendment 12-story actual)

| ID | Type (entry plan) | Type (close-actual) | Test Evidence | Status |
|---|---|---|---|---|
| S13-01 | Admin (plan ship) | Admin | sprint-13.md ship at `cca3eda` + amendment at `567483a` | met-by-functional |
| S13-02 | USER-OWNED §11 CRITICAL | User-attestation | `prototypes/chapter-prototype/REPORT.md` §Playtest Notes (4-of-4 PASS at `35b8e3b`) | done |
| S13-03 | Admin (gate-check rerun) | Admin/process | `production/gate-checks/pre-prod-to-prod-2026-05-09-rerun-2.md` (CONCERNS at `8b77ea4`) | done |
| S13-04 | Config/Data (rule add) | Config/Data | `.claude/rules/tooling-gotchas.md` TG-4 entry (CODE `567483a`; YAML flip `5ed347a`) | done |
| S13-05 | Config/Data (skill edit) | Config/Data | `.claude/skills/story-done/SKILL.md` Phase 7 sub-step (CODE `567483a`; YAML flip `5ed347a`) — **7× consecutive clean dogfood** | done |
| S13-06 | Admin/decision | Admin/decision | PENDING user concurrence — Route a vs Route c | not-started (carry to sprint-14) |
| S13-07 | Admin/process | Admin/process | sprint-13.md §Sprint Mode (signal evaluation + first project mid-sprint mode redesignation precedent) | done |
| S13-08 | Tracking-only | Tracking-only | No-op this sprint | done (no-op) |
| S13-09 | Tracking-only | Tracking-only | No-op this sprint | done (no-op) |
| S13-10 | USER-OWNED Should | User-attestation | `production/qa/qa-signoff-sprint-8-2026-05-06.md` §S8-15 USER-OWNED (MIXED at `6275ed1`: 1.1 PASS / 1.2 FAIL / 1.3 + 3.2 BLOCKED) | done |
| **S13-11 (NEW)** | **Logic** | **Logic (BLOCKING gate)** | `tests/unit/feature/battle_hud/battle_hud_safe_tr_format_test.gd` (7 functions PASS) | done |
| **S13-12 (NEW)** | **Logic** | **Logic (BLOCKING gate)** | `tests/unit/feature/battle_scene/battle_scene_archetype_propagation_test.gd` (8 functions PASS) | done |

**Summary**: 8 done + 2 done-with-mixed-outcome (S13-02 PASS / S13-10 MIXED) + 1 carry (S13-06) + 1 no-op tracking sub-set within done. **Effective close: 11 of 12 done; S13-06 carries to sprint-14.**

---

## Closure-Mode Profile Update

**Entry-time profile** (`qa-plan-sprint-13-2026-05-09.md`): "100% non-runtime closure-mode profile — 0 Logic / 0 Integration / 0 Visual-Feel / 0 UI; 8 Config/Data + 2 USER-OWNED."

**Close-actual profile** (post-mid-amendment): **2 Logic + 1 process-admin + 5 Config/Data + 2 USER-OWNED + 2 tracking-only = 12 effective stories** (60% Config/Data + 17% Logic + 17% USER-OWNED + remainder admin/tracking).

**Mode redesignation history**:
- 2026-05-09 AM (entry): CLOSURE-LEANING HYBRID (signal count 4-of-5 A/C/D/E)
- 2026-05-09 PM mid-amendment: MIXED HYBRID (signal A weakened by S13-11/12 absorption; 3-of-5 C/D/E satisfied; floor of HYBRID threshold)
- **First project mid-sprint mode redesignation precedent** (sprint-13 retro AI #7 first live data point on closure-mode pattern usage gains a 2nd data point on the redesignation mechanism itself)

---

## Automated Test Requirements

### Test delta breakdown

| Source | Tests added | Tests removed | Net |
|---|---:|---:|---:|
| Entry-plan baseline (sprint-12 close) | — | — | 1273 |
| S13-11 Logic addition | +7 | 0 | +7 → 1280 |
| S13-12 Logic addition | +8 | 0 | +8 → 1288 |
| **Sprint-13 close baseline** | **+15** | **0** | **1288** |

### Test surface status

- **All Logic story tests**: COVERED (S13-11 + S13-12 unit tests exist + PASS isolated + PASS in-suite)
- **All non-Logic stories**: EXPECTED (Admin / Config-Data / Tracking-only / User-attestation tiers — no automated test required)
- **66th consecutive failure-free baseline (FFB)** preserved through 12 commits this sprint window: `cca3eda` → `cc83581` → `567483a` → `54824ee` → `727db48` → `5ed347a` → `35b8e3b` → `6275ed1` → `efa7d68` → `8b77ea4` → `fa35c8b` (current)
- 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans across all runs

---

## Manual QA Scope

**Closure-mode posture** (sprint-12 precedent): manual smoke Batches 1/2/3 NOT RUN as fresh checks because user-time attestation gates were the substitute.

**User-time attestation gates executed this sprint**:
- **S13-02** USER-OWNED §11 HARD GATE — 4-of-4 VS Validation items PASS at `prototypes/chapter-prototype/REPORT.md`. Disposition (a) USER-ATTESTED SUCCESS — first live invocation of §11 disposition (a). 6-sprint S7-11 carry chain TERMINATES.
- **S13-10** USER-OWNED Should — Batches 1+3 attested at `production/qa/qa-signoff-sprint-8-2026-05-06.md`. **MIXED outcome**: 1.1 PASS (game launches) / 1.2 FAIL (battle visual blank — POLISH-010) / 1.3 + 3.2 BLOCKED-BY-1.2 / 3.1 N/A. 5-sprint S8-15 carry chain TERMINATES regardless of verdict.

**No fresh manual batch runs required for sprint-13 close.** Closure-mode posture honored per sprint-12 precedent.

---

## NEW path-to-PASS items (carry to sprint-14)

Per `production/gate-checks/pre-prod-to-prod-2026-05-09-rerun-2.md` §6 Path-to-PASS Consolidated:

| # | Item | Tier | Sprint-14 owner |
|---|---|---|---|
| 5 | POLISH-010 disposition (Option A author proper visuals OR Option C deferral ADR) | HIGH (release-blocker) | technical-artist + godot-gdscript-specialist |
| 6 | ADR-0021 "Production world-space rendering responsibility" ratification | HIGH (gate blocker) | technical-director |
| 7 | S8-15 §1.2/1.3/3.2 re-attestation post-POLISH-010-fix (MIXED → clean PASS) | MEDIUM | user (post-Item-5) |
| 8 | Sprint-13 retro AI codifies verification-gap pattern + AD gate criterion | LOW | retrospective + art-director |
| 9 | Sprint-14 carryover concentration audit at plan-time (≥5 triggers §11 closure rebind) | MONITOR | producer |

**Sprint-13 closure-time accept**: these 5 items are documented carry-conditions per gate-check rerun-2; they do NOT block sprint-13 close ceremony but DO gate the next /gate-check pre-prod-to-prod rerun (rerun-3) PASS verdict + `production/stage.txt` Pre-Production → Production flip.

---

## ADVISORY Deferrals (carry forward to sprint-14)

Beyond the 5 NEW path-to-PASS items above:

| Item | Source | Tier |
|---|---|---|
| **POLISH-007** GameBus soft cap exceeded headless (391 turn-domain emits/frame) | sprint-13 mid-amendment | ADVISORY (perf calibration) |
| **POLISH-008** ObjectDB instances leaked at exit | sprint-13 mid-amendment | ADVISORY (defect LOW) |
| **POLISH-009** Missing `mvp_chapter_01.tscn` | S13-11/S13-12/S13-10 verifications | DEFECT (LOW headless / contributing-cause-of-POLISH-010) |
| **POLISH-010** Production main_scene visual rendering blank | S13-10 attestation | **DEFECT HIGH (release-blocker)** |
| **S13-06** producer §7 promotion call | sprint-12 retro AI #4 | not-started (carry to sprint-14) |
| **5 ADVISORY items from S13-12 /code-review** (W-3 docstring drift / I-1 parametric dupe / I-4 count drift / AC-1 sentinel gap / 5 edge cases uncovered) | S13-12 code-review | LOW (documentation polish; not tech-debt-register tier) |

---

## Out of Scope (sprint-13 closure)

- Authoring `mvp_chapter_01.tscn` or any production world-space visual layer (sprint-14 work per gate-check rerun-2 Item 5)
- ADR-0021 ratification (sprint-14 entry per gate-check rerun-2 Item 6)
- POLISH-007 + POLISH-008 fix (sprint-14+ when forcing function fires)
- S13-06 producer §7 promotion paper (sprint-14 carry)

---

## Entry Criteria (already met before sprint-13 close)

- [x] All claude-doable sprint-13 stories DONE (S13-01/03/04/05/07/08/09/11/12 = 9 of 9 claude rows)
- [x] All USER-OWNED stories ATTESTED (S13-02 PASS / S13-10 MIXED — both carry chains TERMINATED)
- [x] §11 HARD GATE binding fulfilled — disposition (a) USER-ATTESTED SUCCESS at S13-02; sprint-13.md DoD line 169 [x]
- [x] Mid-sprint expansion DoD (S13-11 + S13-12) — both done; sprint-13.md DoD line 167 [x]
- [x] /gate-check rerun-2 executed — verdict CONCERNS documented at `pre-prod-to-prod-2026-05-09-rerun-2.md`
- [x] /smoke-check sprint executed — verdict PASS WITH WARNINGS at `smoke-sprint-13-2026-05-09.md`
- [x] 1288/1288 PASS / 66th FFB preserved
- [x] All Logic-tier stories have unit test files at canonical paths

---

## Exit Criteria (this QA cycle — sprint-13 close ceremony)

- [ ] /team-qa sprint-13 (attestation-mode) — `production/qa/qa-signoff-sprint-13-2026-05-09.md` authored; expected verdict APPROVED WITH CONDITIONS (5 NEW path-to-PASS items as carry-conditions per gate-check rerun-2)
- [ ] /retrospective sprint-13 — `production/retrospectives/retro-sprint-13-2026-05-09.md` authored; must address: §11 first-binding outcome SUCCESS / closure-mode first signal-evaluation outcome / 2 codification AIs delivered (S13-04 + S13-05) / verification-gap pattern codification (NEW Item 8) / Mid-sprint mode redesignation precedent / 6-sprint + 5-sprint carry chain TERMINATIONS / 7× PRE-FLIGHT byte-check dogfood SUCCESS metric / S13-06 carry to sprint-14
- [ ] Sprint-13 close commit + push
- [ ] `production/sprint-status-history.md` Sprint 13 section archive
- [ ] `production/sprint-status.yaml` top-level `updated:` rotated to "Sprint 13 CLOSED" message + S13-01 + S13-06 + S13-07/08/09 status flips backlog → done where appropriate

---

## Verdict (preliminary, pending /team-qa Phase 7 sign-off)

**Provisional**: APPROVED WITH CONDITIONS

**Conditions** (mirroring sprint-12 close pattern; sprint-12 was APPROVED WITH CONDITIONS with S12-10/S12-11 → sprint-13 carry):

1. **POLISH-010 disposition + ADR-0021 ratification + S8-15 re-attestation** carry to sprint-14 (gate-check rerun-2 Items 5/6/7) — release-blocker gating Production-stage advancement
2. **S13-06 producer §7 promotion call** carry to sprint-14 — user concurrence pending
3. **Verification-gap pattern codification** at sprint-13 retro AI (gate-check rerun-2 Item 8) — structural
4. **Sprint-14 carryover concentration audit** at plan-time (gate-check rerun-2 Item 9) — process

**No conditions block sprint-13 from CLOSING; all conditions are sprint-14 entry obligations.**

**Strongest positive signals this sprint** (carry to retro):
- 6-sprint S7-11 + 5-sprint S8-15 carry chains BOTH TERMINATED (project-record carry-closure pair)
- §11 HARD GATE first live binding SUCCESS — disposition (a) clean close on first invocation
- 7× consecutive clean PRE-FLIGHT byte-check dogfood — codification effective; recurrence eliminated at root cause
- 1288/1288 PASS / 66th FFB preserved through entire sprint window
- 2 Production VS bugs surfaced + fixed mid-sprint (S13-11 string-format + S13-12 archetype) — first project mid-sprint scope expansion handled cleanly

---

## References

- Entry-time qa-plan: `production/qa/qa-plan-sprint-13-2026-05-09.md` (cc83581)
- Sprint-13 plan: `production/sprints/sprint-13.md` (cca3eda + amendment 567483a)
- Smoke check: `production/qa/smoke-sprint-13-2026-05-09.md` (fa35c8b)
- Gate-check rerun-2: `production/gate-checks/pre-prod-to-prod-2026-05-09-rerun-2.md` (8b77ea4)
- Sprint-12 closure precedent: `production/qa/qa-plan-sprint-12-closure-2026-05-09.md` (fc9adfb)
- Polish-backlog: `production/polish-backlog.md` (POLISH-007/008/009/010)
- Decisions-convention §11 HARD GATE: `docs/process/decisions-convention.md`
- Closure-mode pattern: `production/decisions/closure-mode-sprint-pattern-2026-05-09.md`
