# QA Plan: Save-Manager Epic — 2026-04-24

## Scope

- Epic: save-manager (Platform layer)
- Stories: 001-008 (8 stories, all Complete; story-007 Complete with AC-TARGET deferred)
- Sprints: 5 (approx. 2026-04-18 through 2026-04-24)
- Governing ADR: ADR-0003 (Save/Load — Checkpoint Persistence via Typed Resource + ResourceSaver)

## Story Classification

| Story | Type | Automated Required | Manual Required | Test Evidence | Blocker? |
|-------|------|--------------------|-----------------|---------------|----------|
| 001 — SaveContext + EchoMark Resource classes | Logic | Yes — unit test | No | `tests/unit/core/save_context_test.gd` (7 tests, 107/107 PASS) | None |
| 002 — SaveManager autoload skeleton | Logic | Yes — unit test | No | `tests/unit/core/save_manager_test.gd` (17 tests, 124/124 PASS) | None |
| 003 — SaveManagerStub for GdUnit4 | Logic | Yes — unit test | No | `tests/unit/core/save_manager_stub_self_test.gd` (8 tests, 132/132 PASS) | None |
| 004 — Save pipeline (duplicate_deep → atomic rename) | Logic | Yes — unit test | No | `tests/unit/core/save_manager_test.gd` story-004 section (27 tests, 127/127 PASS) | None |
| 005 — Load pipeline (list_slots + crash-recovery) | Logic | Yes — unit test | No | `tests/unit/core/save_manager_test.gd` story-005 section (34 tests, 134/134 PASS) | None |
| 006 — SaveMigrationRegistry + schema chain | Logic | Yes — unit test | No | `tests/unit/core/save_migration_registry_test.gd` (5 tests) + `save_manager_test.gd` AC-INTEGRATION (143/143 PASS) | None |
| 007 — Perf baseline + target-device V-11 | Integration | Yes — integration test (desktop) | Yes — on-device Android evidence (DEFERRED) | `tests/integration/core/save_perf_test.gd` (4/4 PASS); AC-TARGET pending Polish phase | Advisory only |
| 008 — CI lint (V-10 + V-13 + TR-005) | Config/Data | No | Yes — smoke check | `production/qa/smoke-save-v10-v13-lint.md` (9/9 PASS) | None |

## Automated Test Requirements

All test files exist and pass as of 2026-04-24 (162/162 full suite).

| Story | Test File(s) |
|-------|-------------|
| 001 | `tests/unit/core/save_context_test.gd` |
| 002 | `tests/unit/core/save_manager_test.gd` (stories 002-006 share this file) |
| 003 | `tests/unit/core/save_manager_stub_self_test.gd` |
| 004 | `tests/unit/core/save_manager_test.gd` |
| 005 | `tests/unit/core/save_manager_test.gd` |
| 006 | `tests/unit/core/save_migration_registry_test.gd` + `tests/unit/core/save_manager_test.gd` |
| 007 | `tests/integration/core/save_perf_test.gd` |
| 008 | `production/qa/smoke-save-v10-v13-lint.md` (Config/Data — smoke evidence, not unit test) |

CI lint gates (all PASS): `tools/ci/lint_per_frame_emit.sh`, `tools/ci/lint_save_paths.sh`, `tools/ci/lint_enum_append_only.sh`

## Manual QA Scope

N/A — Platform-layer epic; no playable build. Standard manual-QA batches (core stability — "game launches to main menu", sprint mechanic + regression, save/load data integrity) assume a playable prototype that does not exist at this project stage.

Story-008 smoke evidence (`production/qa/smoke-save-v10-v13-lint.md`) captures 9 lint behaviors manually verified with verbatim CI outputs — this is the one applicable manual verification at the Platform layer.

## Out of Scope

- V-11 authoritative on-device Android perf measurement — explicitly DEFERRED per story-007 §7 pattern; tracked in TD-031; execute in Polish phase when Snapdragon 7-gen Android device + Godot 4.6 export template are available
- Performance regression baseline tightening (TD-031 S-6) — defer until several CI runs provide variance data
- Payload-builder calibration decision (TD-031 S-5) — bundled with AC-TARGET Polish-phase session
- Cross-epic regressions involving unlanded systems (scenario-progression, UI, gameplay) — not applicable at Platform layer

## Entry Criteria (all MET)

- Smoke check PASS (`production/qa/smoke-2026-04-24.md`)
- All 8 stories Status: Complete (or Complete with sanctioned deferral)
- Automated suite 162/162 PASS
- All 3 CI lint gates PASS
- Zero open bugs in save-manager scope

## Exit Criteria (all MET)

- Every story has matching test evidence per its Type (coding-standards.md Test Evidence table)
- Zero MISSING test evidence entries
- Zero S1/S2 severity bugs open
- V-1 through V-13 validation criteria addressed (V-11 with sanctioned deferral)
- Advisory tech-debt items tracked in TD-028, TD-029, TD-030, TD-031 (all low-priority, all explicitly scoped to future cleanup cycles)

## QA Methodology Notes

- Automated evidence is the QA signal for Platform-layer stories at this project stage
- Manual QA returns as a first-class activity once Foundation/Gameplay layers produce a playable prototype
- Epic-close QA cycle is compressed by design; full team-qa ceremony (manual batch execution, playtest questionnaires) resumes when vertical slice exists
- Shift-left was observed: Logic story test files were authored alongside implementation (not deferred to sprint end); CI lint gates were added as part of story-008 before epic close
