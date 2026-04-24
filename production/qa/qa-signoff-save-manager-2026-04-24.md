# QA Sign-Off Report: Save-Manager Epic

**Date**: 2026-04-24
**Epic**: save-manager (Platform layer, 8 stories, 5 sprints)
**Governing ADR**: ADR-0003
**QA Lead sign-off**: APPROVED WITH CONDITIONS (2026-04-24)

## Test Coverage Summary

| Story | Type | Test Evidence | Result |
|-------|------|---------------|--------|
| 001 — SaveContext + EchoMark Resource classes | Logic | `tests/unit/core/save_context_test.gd` — 7 tests | PASS |
| 002 — SaveManager autoload skeleton | Logic | `tests/unit/core/save_manager_test.gd` — 17 tests | PASS |
| 003 — SaveManagerStub for GdUnit4 | Logic | `tests/unit/core/save_manager_stub_self_test.gd` — 8 tests | PASS |
| 004 — Save pipeline (duplicate_deep → atomic rename) | Logic | `tests/unit/core/save_manager_test.gd` — 27 tests | PASS |
| 005 — Load pipeline (list_slots + crash-recovery) | Logic | `tests/unit/core/save_manager_test.gd` — 34 tests | PASS |
| 006 — SaveMigrationRegistry + schema chain | Logic | `tests/unit/core/save_migration_registry_test.gd` + `save_manager_test.gd` AC-INTEGRATION | PASS |
| 007 — Perf baseline + target-device V-11 | Integration | `tests/integration/core/save_perf_test.gd` — 4 tests (desktop); AC-TARGET pending | PASS WITH NOTES |
| 008 — CI lint (V-10 + V-13 + TR-005) | Config/Data | `production/qa/smoke-save-v10-v13-lint.md` — 9 smoke tests | PASS |

**Full automated suite**: 162/162 PASS. **CI lint gates**: 3/3 PASS.

## Bugs Found

No bugs filed in save-manager epic scope. All 8 PRs merged to main with clean history. Zero S1/S2/S3/S4 bugs opened against save-manager stories.

| ID | Story | Severity | Status |
|----|-------|----------|--------|
| — | — | — | — |

## Validation Criteria Coverage (ADR-0003 V-1 through V-13)

| V-# | Criterion | Status | Source |
|-----|-----------|--------|--------|
| V-1 | Round-trip preserves all SaveContext fields | PASS | story-004 `save_manager_test.gd` |
| V-2 | Array[EchoMark] survives serialization | PASS | story-005 `save_manager_test.gd` |
| V-3 | SaveContext + EchoMark @export coverage | PASS | story-001 `save_context_test.gd` |
| V-4 | Tmp file cleaned on save failure | PASS | story-004 `save_manager_test.gd` |
| V-5 | Crash during save leaves old file intact | PASS | story-004 `save_manager_test.gd` |
| V-6 | Schema migration chain reaches CURRENT | PASS | story-006 `save_migration_registry_test.gd` |
| V-7 | CACHE_MODE_IGNORE enforced | PASS | story-005 `save_manager_test.gd` |
| V-8 | list_slots returns 3 entries with correct shape | PASS | story-005 `save_manager_test.gd` |
| V-9 | Corrupt file returns null + emits save_load_failed | PASS | story-005 + story-006 bonus test |
| V-10 | SAF/external-storage paths rejected by lint | PASS | story-008 `lint_save_paths.sh` |
| V-11 | Full save cycle <50 ms on mid-range Android | DEFERRED | Desktop substitute = 0.96 ms p95 (52× under budget); authoritative on-device measurement pending Polish phase per TD-031 |
| V-12 | load_latest_checkpoint returns newest CP | PASS | story-005 `save_manager_test.gd` |
| V-13 | No per-frame GameBus emits from save_manager | PASS | story-008 `lint_per_frame_emit.sh` |

12 of 13 validation criteria PASS. V-11 is sanctioned DEFERRED, not a gap.

## Tech-Debt Advisories (14 items, all low-priority)

- **TD-028** (3 items remaining): factory helper refactor, G-16 gotcha rule-file update, negative-chapter filename guard — all low-priority, deferred
- **TD-029** (1 item deferred): A-5 migration-callable static-lint evaluation — deferred to next CI-infra polish cycle
- **TD-030** (3 items): `lint_save_paths.sh` comment-strip regex precision, legacy `if !` bash bug in `lint_per_frame_emit.sh`, batch refactor proposal — deferred to next CI polish cycle
- **TD-031** (7 items): AC-TARGET rename call form fidelity, advisory threshold tightening, comment precision, `_max()` guard, payload-builder calibration vs ADR projection, AC-DESKTOP bound tightening, story-007 checkbox — all bundled with AC-TARGET Polish-phase session

All 14 items are explicitly low-priority. None block epic closure or phase-gate advancement.

## Verdict: APPROVED WITH CONDITIONS

### Rationale

All 8 stories are Complete with matching test evidence per their Type. Automated suite 162/162 PASS. CI lint gates 3/3 PASS. 12 of 13 ADR-0003 validation criteria PASS. V-11 authoritative on-device measurement is DEFERRED under the story-007 §7 sanctioned pattern (scene-manager precedent); the desktop substitute result (0.96 ms p95) provides strong directional confidence at 52× under the mobile budget. Zero open bugs. Zero S1/S2 issues. All advisory items are low-priority and scoped to future cleanup cycles.

The verdict is APPROVED WITH CONDITIONS rather than APPROVED because V-11 on-device measurement is a condition of full epic closure — it must be completed before the save-manager epic can be declared V-11-authoritative. The epic is architecturally complete for phase-gate advancement.

### Conditions for Full APPROVED Status

1. Execute AC-TARGET on-device perf measurement on Snapdragon 7-gen Android (or equivalent mid-range device) during Polish phase
2. Apply TD-031 S-1 (rename call form fidelity in test) before measurement for accurate stage timings
3. Resolve TD-031 S-5 (payload-builder calibration vs ADR 5-15 KB projection) in the same session
4. Create evidence document at `production/qa/evidence/save-v11-android-perf-<date>.md` per story-007 §7 template
5. Update story-007 status to reflect V-11 authoritative completion

### Next Step

Epic is architecturally complete and approved for phase-gate advancement. Run `/gate-check` to validate progression to the next phase. V-11 Polish-phase measurement does not gate this advancement — it is a distinct milestone tracked in TD-031 with an explicit path to closure.
