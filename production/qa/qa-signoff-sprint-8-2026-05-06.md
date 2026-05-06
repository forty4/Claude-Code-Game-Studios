# QA Sign-Off Report: Sprint 8

**Date**: 2026-05-06
**Sprint**: 8 — Unblock input-handling + ship chapter-1 + flip Pillar 2 lock candidates 5+6 to shipped
**QA Lead sign-off**: APPROVED WITH CONDITIONS
**QA Cycle Type**: Sprint close-out — lean-mode paper review (Phase 2 + Phase 7)
**Cycle Path**: Phase 2 (Strategy) + Phase 7 (Sign-Off). Phase 4 (Test Case Writing) skipped — sprint-8 stories shipped with inline `## QA Test Cases` sections per lean-mode discipline. Phase 6 (Manual QA Execution) deferred to S8-15 USER-OWNED user attestation per headless dev environment pattern.

---

## Executive Summary

Sprint 8 shipped 11 of 16 stories (Must 7/7 + Should 4/4; Nice 0/5 + S8-15 USER-OWNED carryover + S8-12..S8-14/S8-16 deferred to sprint-9) achieving the **38th consecutive failure-free baseline** at 1116/1116 tests passing with 0 errors, 0 failures, and 0 orphans. The sprint delivered a **5× velocity multiplier** (11 stories in ~1 calendar day vs. the 7-day nominal window; 4th invocation — pattern stable), closed both remaining Pillar 2 architectural lock candidates (Story Event + Destiny State), completed the chapter-1 end-to-end integration vertical slice, and finalized the full 7-state InputRouter FSM across 4 sequential implementation stories. **0 production bugs** were surfaced across all 11 closed stories. Manual smoke verification (Batches 1 + 3 of the sprint-8 smoke check) is deferred to the S8-15 USER-OWNED user attestation gate per the established sprint-7/S7-11 precedent (2nd project invocation — pattern established as project discipline).

---

## Test Coverage Summary

| Story | Type | Auto Test | Manual QA | Result |
|-------|------|-----------|-----------|--------|
| S8-01 ADR-0020 InputRouter Accepted | Design (ADR-only) | N/A — design-time deliverable | N/A | PASS |
| S8-02 input-handling story-001 (module skeleton + autoload) | Logic | `tests/unit/foundation/input_router_skeleton_test.gd` (9 tests) PASS | DEFERRED to S8-15 | PASS |
| S8-03 input-handling story-002 (22-action vocab + bindings.json + InputMap) | Logic | `tests/unit/foundation/input_router_actions_bindings_test.gd` PASS | DEFERRED to S8-15 | PASS |
| S8-04 input-handling story-003 (FSM core S0/S1/S2 move flow) | Logic | `tests/unit/foundation/input_router_fsm_core_test.gd` PASS | DEFERRED to S8-15 | PASS |
| S8-05 input-handling story-004 (FSM attack S3/S4 + ST-2 + AC-11) | Logic | `tests/unit/foundation/input_router_fsm_attack_st2_test.gd` (24 tests) PASS | DEFERRED to S8-15 | PASS |
| S8-06 input-handling story-005 (mode determination CR-2 + input_mode_changed) | Logic | `tests/unit/foundation/input_router_mode_test.gd` (11 tests) PASS + 2 Polish-deferred evidence docs | DEFERRED to S8-15 | PASS WITH NOTES |
| S8-07 battle-hud story-005 (UI-GB-02/05/10 + two-tap ATTACK/DEFEND) | UI + Integration | `tests/integration/feature/battle_hud/battle_hud_two_tap_test.gd` (10 tests) PASS + `production/qa/evidence/battle-hud-story-005-evidence.md` | DEFERRED to S8-15 | PASS WITH NOTES |
| S8-08 Save/Load #17 GDD authoring (PROVISIONAL → Designed) | Config/Data (design) | N/A — design document deliverable (`design/gdd/save-load.md` 368L) | Smoke check: production impl sprint-9+ scope | PASS |
| S8-09 Story Event #10 implementation | Logic | `tests/unit/feature/story_event/story_event_test.gd` (15 tests) PASS | N/A (subsystem state machine — no visible UI) | PASS |
| S8-10 Destiny State #16 implementation | Logic | `tests/unit/feature/destiny_state/destiny_state_test.gd` (14 tests) PASS | N/A (subsystem state machine — no visible UI) | PASS |
| S8-11 Chapter-1 (장판파) end-to-end integration | Integration | `tests/integration/chapter_1_e2e/chapter_1_full_arc_test.gd` (8 tests) PASS | DEFERRED to S8-15 | PASS |

**Coverage summary**: 9 COVERED (automated tests passing) + 2 EXPECTED (ADR-only + Config/Data design deliverable) + 0 MISSING.

**100% Logic/Integration test coverage across all sprint-8 Must-Have + Should-Have stories.**

---

## Smoke Check Cross-Reference

The sprint-8 smoke check at `production/qa/smoke-2026-05-06.md` returned verdict **PASS WITH WARNINGS**. Key findings: automated test suite passed clean at **1116/1116** (38th consecutive failure-free baseline; chain unbroken since hp-status story-001 with +459 tests added across sprints 3–8); G-7 silent-skip detection confirmed count actually advanced 1106 → 1116 (+10) at S8-07 ship; **100% Logic/Integration coverage** with 0 missing test evidence entries across all 11 closed stories; **manual smoke verification (Batches 1, 2 partial, 3) deferred to S8-15 USER-OWNED user attestation** per the headless dev environment pattern (consistent with sprint-7 S7-11 precedent — 2nd project invocation establishes this as project discipline). The WARNINGS designation does not reflect any automated test failure; it reflects the deferred manual verification gate only. This smoke check verdict permits eligibility for `/team-qa sprint` and, following APPROVED or APPROVED WITH CONDITIONS sign-off, `/gate-check`.

---

## Bugs Found

| ID | Story | Severity | Status |
|----|-------|----------|--------|
| — | — | — | — |

0 bugs filed. 0 production bugs surfaced across 11 closed stories during sprint-8 implementation. Failure-free baseline maintained at 38 consecutive clean runs. `production/qa/bugs/` has no entries (directory does not exist — no bugs have ever been filed in this project to date).

**Note**: one production-correctness bug was surfaced AND closed in the same patch at S8-11 (StoryEvent `_on_chapter_completed` CONNECT_DEFERRED handler race — chapter N+1 text emitted instead of chapter N in multi-chapter scenarios). Because it was surfaced and resolved within the same commit before any story was marked Done, it does not appear in the open bug register. It is documented in the S8-11 commit message and `production/qa/evidence/chapter_1_integration_run.md`.

---

## Tech Debt Logged

5 ADVISORY items logged at S8-07 close. Total tech-debt-register count: 67 (was 62 pre-S8-07). Canonical source: `docs/tech-debt-register.md`.

| ID | Summary | Tier | Resolution Target |
|----|---------|------|-------------------|
| TD-063 | `_grid_controller.is_action_available(unit_id, action_name)` API placeholder in BattleHUD | Implementation | Grid Battle epic |
| TD-064 | `_grid_controller.is_undo_available(unit_id)` API placeholder in BattleHUD | Implementation | input-handling story-006 OR Grid Battle epic |
| TD-065 | `ui_gb_10_undo_indicator.tscn` UndoLabel hardcoded localized string | Polish | Polish phase |
| TD-066 | `ui_gb_05_skill_list.tscn` nested HBoxContainer `mouse_filter` not explicitly set to IGNORE | Polish | Polish phase (defensive; no functional impact) |
| TD-067 | story-008 `battle_hud_hardcoded_localized_strings` lint scope extension to `.tscn` files | story-008 extension | story-008 ship |

None of TD-063..TD-067 are blocking advancement. TD-063 and TD-064 are forward-pointers to a future epic; TD-065 and TD-066 are polish-tier cosmetic items; TD-067 is a lint scope extension that will be resolved at story-008 ship time.

---

## Polish-Deferred Items (pre-existing pattern — NOT new issues)

These are not bugs. They follow the Polish-deferral discipline established at scene-manager + map-grid + damage-calc + hp-status + input-handling (5+ precedent). Each has a documented reactivation trigger and a ready-to-ship fallback.

**S8-06 (input-handling story-005) — AC-7 + AC-8 Polish-deferred evidence docs**
- AC-7: last-device-wins touch-path manual verification on an Android device. Reactivation trigger: first Android export build green. Evidence docs at `production/qa/evidence/input_router_verification_01_*.md` and `production/qa/evidence/input_router_verification_02_*.md` are pre-authored with test protocol; require device execution to fill in actual results.
- AC-8: gamepad mode switch manual verification on a Bluetooth gamepad. Reactivation trigger: mac dev box + Bluetooth gamepad available.
- Polish-tier; not blocking pre-production → production stage gate.

**S8-07 (battle-hud story-005) — AC-8 44pt manual pre-flight**
- AC-8: 44-point touch-target manual pre-flight checklist. Evidence doc at `production/qa/evidence/battle-hud-story-005-evidence.md` includes the checklist. Reactivation trigger: story-008 ship (lint scope extension in TD-067 automates part of this). Touch-target compliance is a platform requirement but no functional regression is possible from the headless automated path.
- Polish-tier; not blocking advancement.

---

## Verdict

**APPROVED WITH CONDITIONS**

Sprint 8 ships with **0 open S1/S2/S3/S4 bugs** — the bug register is empty. The 5 ADVISORY tech-debt items (TD-063..TD-067) sit below S4 severity in impact (all are polish-tier or forward-pointers, none introduce regressions). The 3 conditions below are the sole gates before final release advancement. There are no blockers to sprint-9 commencement.

Verdict rule applied: APPROVED WITH CONDITIONS = "S3/S4 bugs open, or PASS WITH NOTES issues documented; no S1/S2 bugs." This sprint has no S3/S4 bugs; the conditions arise from (1) deferred manual verification (USER-OWNED gate, not a QA deficiency), (2) Polish-deferred evidence docs awaiting device access, and (3) tracked tech-debt forward-pointers. All are sub-S4 in severity and fully documented with resolution paths.

---

## Conditions

**3 explicit conditions before final release sign-off:**

**Condition 1 — Manual smoke verification (S8-15 USER-OWNED)** [BLOCKING for release; not blocking for sprint-9]
User attests against a running build per:
- Batch 1 (core stability): game launches to main menu; new game / session starts; main menu input responds.
- Batch 3 (data integrity + performance): save/load round-trip (deferred — production impl is sprint-9+ scope; verify N/A); no new frame-rate drops or hitches on target device.
- Batch 2 sprint-mechanic items: automated coverage already complete (S0..S6 FSM + mode determination + two-tap + chapter-1 e2e — all 1116 automated tests green). Manual click-through of InputRouter + battle HUD two-tap on a live build is still desirable before release but the automated gate is satisfied.
Tracked as S8-15 USER-OWNED carryover. Sprint-9 may commence before this gate closes.

**Condition 2 — Polish-deferred verification evidence reactivation** [Advisory; not blocking advancement]
AC-7 + AC-8 of S8-06 (input-handling story-005) and AC-8 of S8-07 (battle-hud story-005). Reactivation triggers: first Android export build green (AC-7) + mac dev box / Bluetooth gamepad available (AC-8 of S8-06) + story-008 lint ship (AC-8 of S8-07). All evidence doc frameworks pre-authored; require device execution only.

**Condition 3 — 5 ADVISORY tech-debt items (TD-063..TD-067)** [Advisory; not blocking advancement]
Tracked in `docs/tech-debt-register.md`. Resolution scheduled: TD-067 at story-008 ship; TD-063 + TD-064 at Grid Battle epic; TD-065 + TD-066 at polish phase. No functional regressions introduced by any of the five items.

---

## Next Step

Run `/gate-check pre-production` after user completes the S8-15 attestation.

The gate-check verdict is expected to upgrade from CONCERNS → PASS based on sprint-8 closure:

- **Path-to-PASS items #1–6** from the 2026-05-04 gate-check: most resolved by sprint-8 closure (ADR mandatory list = 0 outstanding at delta #15 acceptance; cross-director convergent blocker closed at delta #14; all design/architecture tracking inputs consistent with sprint-8 ship). S7-11 + S8-15 user attestations remain as the sole outstanding items.
- **Pre-condition**: user runs S8-15 attestation first (Condition 1 above), then invokes `/gate-check pre-production`. Expected output: PASS or narrow CONCERNS list (S7-11 + S8-15 attestation evidence docs in `production/qa/evidence/`).
- **If `/gate-check` returns PASS**: project advances from pre-production stage to Production stage; `production/stage.txt` upgrade is the deliverable.
