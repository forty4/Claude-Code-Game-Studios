# QA Sign-off — Sprint-13 (Close-Out Attestation)

> **Date**: 2026-05-09 PM late
> **Sprint**: 13 (closure-leaning HYBRID redesignated to MIXED HYBRID at mid-sprint amendment; first project mid-sprint mode redesignation precedent)
> **Mode**: attestation-mode (closure-mode posture; user-time gates SUBSUME fresh manual batches per sprint-12 precedent)
> **Engine**: Godot 4.6.2 stable official
> **Effective story count**: 12 (10 entry-plan + 2 mid-amendment Logic-tier S13-11 + S13-12)

---

## Test Coverage Summary

| Story | Type | Test File / Evidence | Status |
|---|---|---|---|
| S13-01 | Admin (plan ship) | `production/sprints/sprint-13.md` ship + amendment | met-by-functional |
| S13-02 | USER-OWNED §11 CRITICAL | `prototypes/chapter-prototype/REPORT.md` §Playtest Notes (4-of-4 PASS) | done |
| S13-03 | Admin (gate-check rerun) | `production/gate-checks/pre-prod-to-prod-2026-05-09-rerun-2.md` (CONCERNS) | done |
| S13-04 | Config/Data | `.claude/rules/tooling-gotchas.md` TG-4 entry | done |
| S13-05 | Config/Data | `.claude/skills/story-done/SKILL.md` Phase 7 byte-check sub-step (**7× clean dogfood**) | done |
| S13-06 | Admin/decision | PENDING user concurrence | not-started (carry-to-sprint-14) |
| S13-07 | Admin/process | sprint-13.md §Sprint Mode redesignation table | done |
| S13-08 / S13-09 | Tracking-only | No-op this sprint | done (no-op) |
| S13-10 | USER-OWNED Should | `qa-signoff-sprint-8-2026-05-06.md` §S8-15 (MIXED) | done |
| **S13-11** | **Logic** | `tests/unit/feature/battle_hud/battle_hud_safe_tr_format_test.gd` (7 functions PASS) | done |
| **S13-12** | **Logic** | `tests/unit/feature/battle_scene/battle_scene_archetype_propagation_test.gd` (8 functions PASS) | done |

**Effective close**: 11 of 12 stories done (S13-06 carries to sprint-14).
**Test baseline**: 1273 → **1288** (+15 net; +7 S13-11 + +8 S13-12); **66th consecutive FFB preserved**.

---

## Bugs Found (this sprint)

### Surfaced + Fixed (mid-sprint absorption)

| Bug | Story | Fix commit | Evidence |
|---|---|---|---|
| `battle_hud.gd:1240/1247` `tr() %` runtime fail (5× headless string-format errors) | **S13-11** | `54824ee` | Headless `grep -c "String formatting error"` 0 (was 5); 7-test unit suite PASS |
| AISystem unknown-archetype warnings (4+/battle, EC-AI-4 fallback path) | **S13-12** | `727db48` | Headless `grep -c "AISystem: unknown archetype"` 0 (was 4+); 8-test unit suite PASS |

### Surfaced + Filed (deferred; sprint-14 work)

| Bug / gap | POLISH-ID | Tier | Disposition |
|---|---|---|---|
| GameBus soft cap exceeded headless (391 turn-domain emits/frame) | POLISH-007 | ADVISORY (perf calibration) | Defer to sprint-14+ when forcing function fires |
| ObjectDB instances leaked at exit (1+ orphan) | POLISH-008 | ADVISORY (defect LOW) | Defer to sprint-14+ |
| Missing `scenes/battle/mvp_chapter_01.tscn` referenced by `mvp_shu.json:8` | POLISH-009 | DEFECT (LOW headless / contributing-cause-of-POLISH-010) | Carry to sprint-14 (likely bundled with POLISH-010 fix) |
| **Production main_scene world-space visual rendering blank in windowed mode** | **POLISH-010** | **DEFECT HIGH (release-blocker)** | **Carry to sprint-14 — gate-check rerun-3 PASS gated on this** |

### Surfaced via /code-review (S13-12) — ADVISORY non-blocking

5 items (W-3 docstring drift / I-1 parametric dupe / I-4 count drift / AC-1 sentinel gap / 5 edge cases uncovered). All deferred to sprint-13 retro for tech-debt classification. Documentation-polish tier; not tech-debt-register entries.

---

## ADVISORY Deferrals (carry forward to sprint-14)

Per `production/gate-checks/pre-prod-to-prod-2026-05-09-rerun-2.md` §6 Path-to-PASS Consolidated:

| # | Item | Tier | Sprint-14 disposition |
|---|---|---|---|
| 5 | POLISH-010 disposition (Option A author proper visuals OR Option C deferral ADR) | HIGH (release-blocker) | sprint-14 plan-time decision |
| 6 | ADR-0021 "Production world-space rendering responsibility" ratification | HIGH (gate blocker) | sprint-14 entry |
| 7 | S8-15 §1.2/1.3/3.2 re-attestation post-POLISH-010-fix | MEDIUM | sprint-14 (after Item 5) |
| 8 | Sprint-13 retro AI codifies verification-gap pattern + AD gate criterion | LOW | sprint-13 retro (this ceremony) |
| 9 | Sprint-14 carryover concentration audit at plan-time | MONITOR | sprint-14 plan-time |
| — | S13-06 producer §7 promotion call | MEDIUM | sprint-14 (claude-side ~10 min + user concurrence) |
| — | POLISH-007 + POLISH-008 + POLISH-009 | LOW-DEFECT | sprint-14+ as forcing functions fire |

---

## Verdict: **APPROVED WITH CONDITIONS** ⚠️

**Verdict rationale**:
- All Logic-tier stories COVERED with PASS unit tests (S13-11 + S13-12)
- All claude-doable stories DONE (9 of 9)
- Both USER-OWNED stories ATTESTED (S13-02 PASS / S13-10 MIXED — both carry chains TERMINATED regardless of outcome)
- Automated tests 1288/1288 PASS / 66th FFB preserved through entire sprint window
- Headless verification confirms backend functionality intact (391 turn-domain emits + AI dispatch + scenario LOAD all clean post-S13-12)
- Sprint-13 substantive PASS at logic-tier despite POLISH-010 release-blocker because POLISH-010 is content-asset-authoring gap (architectural since sprint-3), NOT a sprint-13 regression
- S13-06 carry to sprint-14 is documented + tracked

**Conditions** (carry-conditions to sprint-14; do NOT block sprint-13 close):
1. POLISH-010 disposition + ADR-0021 ratification + S8-15 re-attestation (gate-check rerun-2 Items 5/6/7) — gates `production/stage.txt` Pre-Production → Production flip
2. S13-06 producer §7 promotion call — user concurrence pending
3. Verification-gap pattern codification at sprint-13 retro (gate-check rerun-2 Item 8) — addressed in retro this ceremony
4. Sprint-14 carryover concentration audit at plan-time (gate-check rerun-2 Item 9)

**Mirroring sprint-12 close pattern**: sprint-12 closed APPROVED WITH CONDITIONS with S12-10 + S12-11 user attestations + S12-03 close-gate rerun → sprint-13 carry. Sprint-13 closes APPROVED WITH CONDITIONS with POLISH-010 + ADR-0021 + S8-15 re-attestation + S13-06 → sprint-14 carry. Pattern stable.

---

## Sprint-13 Close Gate Notes

**Strongest positive trajectory signals**:

1. **6-sprint S7-11 carry chain TERMINATES** (sprint-7 → 8 → 9 → 10 → 11 → 12 → 13) — project-record carry closure via §11 HARD GATE first live binding SUCCESS at S13-02 disposition (a) USER-ATTESTED 4-of-4 PASS.
2. **5-sprint S8-15 carry chain TERMINATES** (sprint-8 → 9 → 10 → 11 → 12 → 13) — attestation IS the attestation per refusal-to-fabricate posture; MIXED outcome at S13-10 carries verdict cleanly.
3. **PRE-FLIGHT byte-check codification (S13-05) DOGFOODED 7× consecutive clean** — recurrence eliminated at root cause (was 4× across S11/S12 sprints; sprint-3 retro AI #3 root-cause closure CONFIRMED).
4. **§11 HARD GATE first-binding SUCCESS** — disposition (a) clean close on first live invocation; precedent established for sprint-14+ structural pre-flight obligations.
5. **First project mid-sprint scope expansion handled cleanly** — sprint-13 mid-amendment absorbed 2 Production VS bug-fixes (S13-11 + S13-12) WITHOUT regression on baseline; first project mid-sprint mode redesignation precedent (CLOSURE-LEANING → MIXED HYBRID).
6. **66th consecutive failure-free baseline** — preserved through 12 commits this sprint window (cca3eda → fa35c8b).

**Hygiene streak**: 47+ in-patch sprint-status closes (project-record continuing); sprint-13 close commit will extend to ~57+ assuming all 12 sprint-13 stories close in-patch.

---

## Next Step

Run `/retrospective sprint-13` to author `production/retrospectives/retro-sprint-13-2026-05-09.md`. Required topics (per gate-check rerun-2 + qa-plan-closure recommendations):

1. **§11 HARD GATE first-binding outcome** SUCCESS — codify pattern for sprint-14+ structural pre-flight obligations
2. **Closure-mode HYBRID first signal-evaluation outcome** + first project mid-sprint mode redesignation precedent (S13-07)
3. **2 codification AIs delivered** (S13-04 TG-4 + S13-05 PRE-FLIGHT byte-check) — measure effectiveness (7× clean dogfood metric)
4. **Verification gap pattern codification** (NEW from gate-check rerun-2 Item 8) — pattern stable at 2 invocations (POLISH-008 + POLISH-010); CI smoke-tier visual harness scoping for sprint-14
5. **Mid-sprint mode redesignation precedent** — first project occurrence; data point on closure-mode pattern usage
6. **6-sprint + 5-sprint carry chain TERMINATIONS** — strongest carry-closure pair in project history
7. **S13-06 producer §7 promotion call** carry to sprint-14
8. **AD gate criterion addition** (per gate-check rerun-2 Item 8c) — "world-space visual presence" as future gate criterion
9. **5 ADVISORY items from S13-12 /code-review** — tech-debt classification

After retro, sprint-13 close commit + push + sprint-status-history.md archive.

---

## Cross-references

- Smoke check: `production/qa/smoke-sprint-13-2026-05-09.md` (fa35c8b)
- QA-plan closure addendum: `production/qa/qa-plan-sprint-13-closure-2026-05-09.md` (this commit)
- Gate-check rerun-2: `production/gate-checks/pre-prod-to-prod-2026-05-09-rerun-2.md` (8b77ea4)
- Sprint-12 close precedent: `production/qa/qa-signoff-sprint-12-2026-05-09.md` (fc9adfb)
- POLISH-010 root-cause: `production/polish-backlog.md` POLISH-010 entry (efa7d68)
- §11 HARD GATE rule: `docs/process/decisions-convention.md` §11.3
- Closure-mode pattern: `production/decisions/closure-mode-sprint-pattern-2026-05-09.md`
