# QA Plan — Sprint-10 Closure

**Date**: 2026-05-07
**Sprint**: sprint-10 (Must-Have 5/5 done ✓; commit `22b6039` final close)
**Scope**: closure-mode QA plan covering all 5 sprint-10 Must-Have stories
**Mode**: lean (`production/review-mode.txt` = `lean`)
**Smoke**: PASS — `production/qa/smoke-sprint-10-2026-05-07.md` (1236/1236; 51st FFB)

This is a sprint-scoped closure addendum, distinct from per-feature QA plans. It absorbs sprint-10 stories under the existing `production/qa/qa-plan-battle-hud-2026-05-03.md` plan per sprint-10 plan §207 absorption note ("battle-hud epic CLOSURE — existing qa-plan-battle-hud-2026-05-03.md already authored; sprint-10 stories 4-8 absorbed under existing plan"), and adds coverage for the scenario-progression epic graduation backfill (S10-04) + the CI lane gap binding decision (S10-05).

---

## Story Classification Table

| Story | Type | Automated Required | Manual Required | Blocker? |
|---|---|---|---|---|
| **S10-01** — battle-hud-006 Combat Forecast (UI-GB-04) | UI + Performance | PASS — 14 tests (12 integration + 2 unit) at `tests/integration/feature/battle_hud/battle_hud_forecast_test.gd`; perf gate p99 <120ms instrumented via Time.get_ticks_usec() | PASS — `production/qa/evidence/battle-hud-story-006-evidence.md` authored; AC-6 chevron PASS; AC-7 palette + AC-8 dual-focus ADVISORY-deferred | NONE |
| **S10-02** — battle-hud-007 Tile Tooltip + Results + Grid Overlays (UI-GB-06/09/12-14) | UI + Integration | PASS — 15 integration tests at `tests/integration/feature/battle_hud/battle_hud_overlays_test.gd`; Pillar 2 source-grep automated via recursive Label walker + literal-token absence test | PASS — `production/qa/evidence/battle-hud-story-007-evidence.md` authored; AC-9 Pillar 2 audit PASS; AC-10 dashed border + UI-GB-12/13/14 render fidelity ADVISORY-deferred | NONE |
| **S10-03** — battle-hud-008 Epic Terminal (7 CI lints + verification summary) | Config/Data + Audit | PASS — 8 smoke tests at `tests/unit/tools_ci/lint_battle_hud_smoke_test.gd`; all 7 lints wired in `.github/workflows/tests.yml` PASS on HEAD | PASS — `production/qa/evidence/battle_hud_verification_summary.md` (~10KB; 7-Engine-Verification-Item rollup) | NONE |
| **S10-04** — scenario-progression-001 BACKFILL CLOSE-OUT | Integration (doc-only graduation flip; original work shipped sprint-7 S7-02 ba02e02) | PASS — pre-existing 911/911 tests from sprint-7 ba02e02 + 6/6 lints PASS; tests still live at `tests/unit/core/scenario_runner_*_test.gd` (4 files) + `tests/integration/scenario_runner/scenario_runner_chapter_1_traversal_test.gd` | N/A — no manual evidence required; doc-only Status flip (EPIC.md Ready → Complete + index.md row Ready → Complete) | NONE |
| **S10-05** — CI lane gap binding decision (3-sprint deferral termination) | Config/Data (process / decision artifact) | N/A — no code shipped | N/A — decision artifact at `production/decisions/ci-lane-gap-decision-2026-05-07.md` (~250L); POSTPONE-TO-POST-MVP outcome with 4 explicit reactivation triggers; first artifact in NEW `production/decisions/` directory | NONE |

---

## Automated Test Requirements

All BLOCKING-tier automated test files exist on disk and PASS in the headless run:

| System | Test Path | Story Coverage | Status |
|---|---|---|---|
| battle_hud forecast | `tests/integration/feature/battle_hud/battle_hud_forecast_test.gd` | S10-01 | PASS — 12 tests |
| battle_hud forecast (unit) | `tests/unit/feature/battle_hud/` (2 unit tests for forecast helpers) | S10-01 | PASS — 2 tests |
| battle_hud overlays | `tests/integration/feature/battle_hud/battle_hud_overlays_test.gd` | S10-02 | PASS — 15 tests |
| battle_hud lints smoke | `tests/unit/tools_ci/lint_battle_hud_smoke_test.gd` | S10-03 | PASS — 8 tests (7 positive lint runs + 1 structural presence/chmod-x check) |
| scenario_runner state machine | `tests/unit/core/scenario_runner_state_machine_test.gd` | S10-04 (S7-02 origin) | PASS |
| scenario_runner signal contract | `tests/unit/core/scenario_runner_signal_contract_test.gd` | S10-04 (S7-02 origin) | PASS |
| scenario_runner retry loop | `tests/unit/core/scenario_runner_retry_loop_test.gd` | S10-04 (S7-02 origin) | PASS |
| scenario_runner save context | `tests/unit/core/scenario_runner_save_context_test.gd` | S10-04 (S7-02 origin) | PASS |
| scenario_runner chapter-1 traversal | `tests/integration/scenario_runner/scenario_runner_chapter_1_traversal_test.gd` | S10-04 (S7-02 origin) | PASS |
| 7 battle-hud CI lints | `tools/ci/lint_battle_hud_*.sh` (7 scripts) | S10-03 | PASS — Exit 0 each |
| 5 scenario-progression CI lints | `tools/ci/lint_scenario_runner_*.sh` (5 scripts) | S10-04 (S7-02 origin) | PASS — Exit 0 each |

**Aggregate**: 1236/1236 tests / 0 errors / 0 failures / 0 flaky / 0 skipped / 0 orphans / Exit 0. **51st consecutive failure-free baseline**.

---

## Manual QA Scope

**0 additional manual QA sessions required at sprint close.**

Rationale per qa-lead Phase 2 strategy:

- Per-story evidence docs (S10-01 + S10-02) were authored at `/story-done` time and document all mandatory manual checks as either PASS or ADVISORY-deferred.
- Verification summary doc (S10-03) covers all 7 engine verification items with explicit PASS / DEFERRED rows.
- S10-04 is a doc-only graduation backfill — no manual execution path applies (original story-001 manual checks were verified at sprint-7 S7-02 close 2026-05-05).
- S10-05 is a process / decision artifact — binding outcome verified by document existence + reactivation triggers documented; no manual execution path.

The 5 ADVISORY deferrals (below) are pre-recorded — they do not require new manual sessions before sprint close. They will be revisited at Polish-tier sign-off gates.

---

## ADVISORY Deferrals (carry forward to Polish phase)

These items are documented in `production/qa/evidence/battle_hud_verification_summary.md` and per-story Completion Notes. None block sprint close.

1. **Dual-focus end-to-end macOS Metal / Linux Vulkan** (Engine Verification Item 1; battle-hud verification summary §1) — structural contract verified via integration tests; end-to-end manual device test deferred to Polish phase.
2. **AccessKit screen reader VoiceOver / TalkBack** (Engine Verification Item 2; battle-hud verification summary §2) — structural `tooltip_text` + `metadata/_accessibility_label` fields verified at scene-author time; runtime VoiceOver (macOS) + TalkBack (Android) test deferred to Polish phase.
3. **UI-GB-12/13/14 grid-layer render fidelity** (S10-02 ADVISORY 1-4 in evidence doc) — opacity tiers (20%/30%/40% per Commander stack) + 2px logical dashed border + 청록 #3A7D6E 15% tint + 陣 corner glyph + 황토 25%/70% opacity tile fills + 讀 micro-glyph deferred. MVP ships visibility-toggle structural contract. Gated on GridBattleController snapshot schema amendment (separate epic).
4. **i18n locale key authoring** (S10-02 ADVISORY 5; S10-03 verification summary §i18n) — all strings routed through `tr()`; 20+ locale keys staged but locale .csv entries not yet authored. Deferred to dedicated Localization UI epic.
5. **Palette art-director sign-off** (S10-01 AC-7 / AC-UX-HUD-05) — no explicit color overrides in forecast .tscn; default theme ships. Art-director audit deferred before public playtest.

---

## Out of Scope (sprint-10 closure)

The following are explicitly NOT covered by this QA plan + are not blocking sprint close:

- **Sprint-10 Should-Have items (S10-06..S10-09)** — all 4 are status `backlog` (not implemented). Carryover absorption candidates for sprint-11.
- **Sprint-10 Nice-to-Have items (S10-10..S10-12)** — 3 items, all `backlog` (not implemented). Sprint-11 candidate set; CUT CANDIDATE flags noted in sprint-status.yaml on S10-10 + S10-12.
- **Sprint-10 USER-OWNED items (S10-13 + S10-14)** — 4th-time S7-11 carryover + 2nd-time S8-15 carryover. Awaiting user attestation; refusal-to-fabricate posture unchanged.
- **Companion epic potential drift** (destiny-branch + ai-system) — both shipped at sprint-7 S7-03 + S7-04 per sprint-status-history.md line 146-147; potential 3rd + 4th activation of retro-AI-3 if `/story-readiness` invoked on each. NOT touched this sprint per S10-04 backfill scope discipline. Sprint-10 retro AI #3 closure pass should validate.
- **Performance profiling beyond FORECAST_RENDER_BUDGET_MS gate** — frame budget validation is BalanceConstants-gate-enforced (`FORECAST_RENDER_BUDGET_MS=120` in safe range 50-300 via `tools/ci/lint_balance_entities_battle_hud.sh`); deeper perf profiling deferred to Polish-tier `/perf-profile` runs.
- **5-platform CI lane verification** (macOS Metal / iOS Metal / Android Vulkan) — POSTPONED per S10-05 binding decision; reactivation triggers monitor.

---

## Entry Criteria (already met)

- [x] All 5 Must-Have stories status=done in `production/sprint-status.yaml`
- [x] Smoke check PASS — `production/qa/smoke-sprint-10-2026-05-07.md` (1236/1236; 51st FFB)
- [x] All BLOCKING-tier automated tests PASS in headless run
- [x] All required evidence docs exist + reference correct artifacts
- [x] All 5 sprint-10 stories COVERED or EXPECTED in coverage scan (no MISSING)
- [x] No open S1/S2 bugs in `production/qa/bugs/` against sprint-10 work products
- [x] battle-hud Feature epic 8/8 status: Ready → Complete (per S10-03 close)
- [x] scenario-progression Core epic 1/1 status: Ready → Complete (per S10-04 BACKFILL close)
- [x] Sprint-10 critical path Must-Have 5/5 closed

---

## Exit Criteria (this QA cycle)

This QA cycle EXITS when:

- [x] qa-lead Phase 2 strategy confirms CLEAR TO CLOSE (delivered 2026-05-07)
- [ ] qa-lead Phase 7 sign-off report authored at `production/qa/qa-signoff-sprint-10-2026-05-07.md` with verdict APPROVED / APPROVED WITH CONDITIONS / NOT APPROVED
- [ ] Sign-off report committed to repo
- [ ] Sprint retrospective (`/retrospective sprint-10`) authored

After exit: build advances to `/retrospective sprint-10` then sprint-11 plan authoring.

---

## Verdict (preliminary, pending Phase 7 sign-off)

Based on the strategy + smoke check + automated tests + evidence docs + ADVISORY deferral inventory:

**Recommendation**: APPROVED. All 5 Must-Have stories are Done with complete evidence; no S1/S2 bugs open; no MISSING test evidence; smoke PASS. The 5 ADVISORY deferrals are Polish-tier carry-forwards, not gating blockers.

Final verdict will be issued in the Phase 7 sign-off report.

---

## References

- Smoke check: `production/qa/smoke-sprint-10-2026-05-07.md`
- Existing battle-hud QA plan: `production/qa/qa-plan-battle-hud-2026-05-03.md`
- Verification summary: `production/qa/evidence/battle_hud_verification_summary.md`
- Per-story evidence: `production/qa/evidence/battle-hud-story-006-evidence.md` + `battle-hud-story-007-evidence.md`
- Decision artifact: `production/decisions/ci-lane-gap-decision-2026-05-07.md`
- Sprint plan: `production/sprints/sprint-10.md`
- Sprint status (canonical): `production/sprint-status.yaml`
- Sprint history: `production/sprint-status-history.md` Sprint 10 section
- Active session state: `production/session-state/active.md`
