# Epic Close Report: save-manager

> **Scope**: save-manager epic close-out (NOT a project phase-gate advancement)
> **Date**: 2026-04-24
> **Context**: Platform-layer epic close — prerequisite infrastructure for future Vertical Slice
> **Related phase-gate**: Pre-Production → Production remains FAILED per `pre-prod-to-prod-2026-04-20.md` (Vertical Slice still absent; this epic advances the *prerequisites*, not the phase)

---

## Why this is an Epic Close report, not a Phase Gate report

The project's `/gate-check` skill validates project-phase advancement (e.g., Pre-Production → Production) per the 7-stage production lifecycle. This report documents a different scope: **save-manager epic closure** — an audit-trail artifact proving that one Platform-layer epic's 8 stories all shipped with the required evidence.

Attempting `/gate-check` Pre-Production → Production as of 2026-04-24 would partially improve on the 2026-04-20 FAIL (control manifest + epics now exist) but still FAIL on the auto-FAIL condition **Vertical Slice does not exist**. The Platform-layer work tracked in this report is prerequisite infrastructure enabling a future Vertical Slice — it is not itself the Vertical Slice.

This report exists so the audit trail for save-manager's close is preserved at the epic level without conflating it with phase-gate semantics.

---

## Epic Summary: save-manager

- **Layer**: Platform
- **Governing ADR**: ADR-0003 (Save/Load — Checkpoint Persistence via Typed Resource + ResourceSaver, Accepted 2026-04-18)
- **Story count**: 8 (all Status: Complete; story-007 Complete with sanctioned deferral)
- **Sprint span**: approx 2026-04-18 through 2026-04-24 (5 sprints)
- **Final test suite**: 162/162 PASS, 0 errors, 0 failures, 0 orphans, exit 0
- **Final CI lint gates**: 3/3 PASS (per_frame_emit, save_paths, enum_append_only)

## Story-by-Story Close Status

| # | Story | Type | PR | Result |
|---|-------|------|------|--------|
| 001 | SaveContext + EchoMark Resource classes | Logic | #10 (pre-session) | ✅ Complete |
| 002 | SaveManager autoload skeleton | Logic | #11 (pre-session) | ✅ Complete |
| 003 | SaveManagerStub for GdUnit4 | Logic | #13 (pre-session) | ✅ Complete |
| 004 | Save pipeline | Logic | #14 (pre-session) | ✅ Complete (4 ADR errata discovered → TD-024/025/026 + G-14/G-15) |
| 005 | Load pipeline | Logic | #17 (pre-session) | ✅ Complete (zero errata) |
| 006 | SaveMigrationRegistry + schema version chain | Logic | #18 | ✅ Complete (zero errata; hardening pass TD-029 A-1/A-2/A-3/A-4 applied in-cycle) |
| 007 | Perf baseline + target-device V-11 verification | Integration | #20 | ✅ Complete **WITH AC-TARGET DEFERRED** (desktop substitute PASS; on-device Polish-phase) |
| 008 | CI lint — V-10 + V-13 + TR-save-load-005 | Config/Data | #19 | ✅ Complete |

**PR sequence**: stories 006, 008, 007 closed end-to-end in single session 2026-04-24 (stories 001-005 closed in prior sessions).

## ADR-0003 Validation Criteria Coverage

| V-# | Criterion | Status | Source |
|-----|-----------|--------|--------|
| V-1 | Save cycle writes via atomic rename | PASS | story-004 `save_manager_test.gd` |
| V-2 | Load returns newest checkpoint | PASS | story-005 `save_manager_test.gd` |
| V-3 | SaveContext + EchoMark persist all @export fields | PASS | story-001 `save_context_test.gd` |
| V-4 | Tmp-cleanup on save failure | PASS | story-004 |
| V-5 | ResourceSaver error triggers tmp-cleanup | PASS | story-004 |
| V-6 | Schema migration chain reaches CURRENT | PASS | story-006 `save_migration_registry_test.gd` |
| V-7 | CACHE_MODE_IGNORE enforced (load pipeline) | PASS | story-005 |
| V-8 | `list_slots` returns 3-entry correct-shape array | PASS | story-005 |
| V-9 | Corrupt file returns null + emits `save_load_failed` | PASS | story-005 + story-006 bonus test |
| V-10 | SAF/external-storage paths rejected by lint | PASS | story-008 `lint_save_paths.sh` |
| V-11 | Full save cycle <50 ms on mid-range Android | **DEFERRED** | Desktop substitute = 0.96 ms p95 PASS (52× under budget); authoritative on-device measurement pending Polish phase per TD-031 |
| V-12 | `load_latest_checkpoint` returns newest CP | PASS | story-005 |
| V-13 | No per-frame GameBus emits from save_manager | PASS | story-008 `lint_per_frame_emit.sh` |

**12 of 13 criteria PASS**. V-11 is sanctioned DEFERRED per story-007 §7 pattern.

## TR Registry Coverage

| TR-ID | Text | Status |
|-------|------|--------|
| TR-save-load-001 | SaveManager autoload registered in project.godot | PASS — story-002 |
| TR-save-load-002 | SaveContext + EchoMark extend Resource with @export fields | PASS — story-001 |
| TR-save-load-003 | Save pipeline: duplicate_deep → ResourceSaver → atomic rename | PASS — story-004 |
| TR-save-load-004 | Load pipeline: list_slots + load_latest_checkpoint + newest-CP scan + migrate | PASS — stories 005/006 |
| TR-save-load-005 | BattleOutcome.Result enum is append-only | PASS — story-008 `lint_enum_append_only.sh` |
| TR-save-load-006 | Save root is `user://saves`; no SAF/external-storage paths | PASS — story-008 `lint_save_paths.sh` |
| TR-save-load-007 | Migration Callables in SaveMigrationRegistry are pure functions | PASS — story-006 (3-layer doc-header discipline + code-review gate; TD-029 A-5 lint evaluation deferred) |

**7 of 7 TRs satisfied**.

## QA Evidence Trail

Generated and signed off in this session:

- `production/qa/smoke-2026-04-24.md` — Smoke check: **PASS** (162/162 + 3/3 lints + 12/13 V-criteria)
- `production/qa/qa-plan-save-manager-2026-04-24.md` — QA plan (retrospective, entry/exit criteria all MET)
- `production/qa/qa-signoff-save-manager-2026-04-24.md` — QA sign-off: **APPROVED WITH CONDITIONS**
- `production/qa/smoke-save-v10-v13-lint.md` — Story-008 lint smoke (9/9 tests, pre-existing)

QA verdict rationale: all 8 stories Complete with matching test evidence; zero bugs filed; V-11 on-device authoritative measurement is the single outstanding condition (deferred per story-007 §7 sanctioned pattern).

## ADR Errata Discovered During Implementation

| ADR Errata | Story | Description | Status |
|-----------|-------|-------------|--------|
| TD-024 | 004 | `DEEP_DUPLICATE_ALL_BUT_SCRIPTS` enum value does not exist in Godot 4.6; use `DEEP_DUPLICATE_ALL` | Applied in-code; documented as ADR errata comment |
| TD-025 | 004 | `_save_root_override` trailing-slash normalization (G-14) | Applied via `.rstrip("/")` pattern; documented inline |
| TD-026 | 004 | ADR said tmp suffix `.res.tmp`; Godot 4.6 ResourceSaver picks serializer from trailing extension so `.tmp.res` is required | Applied; documented inline |
| G-14 | 004 | Trailing-slash normalization gotcha → `.claude/rules/godot-4x-gotchas.md` | Logged in gotcha file |
| G-15 | 004 | `.tmp.res` filename parse residue (`int("1.tmp")==0` silent coerce) → `.claude/rules/godot-4x-gotchas.md` | Logged in gotcha file |

All errata discovered in story-004. **Stories 005/006/007/008 each shipped with zero new ADR errata** — ADR-0003 reached stable state after story-004's discovery cycle.

## Tech-Debt Batches Logged (14 items total, all low-priority)

- **TD-028** (6 advisory items from story-005 /code-review; 3 closed in-cycle during story-006; **3 remain**: factory helper refactor, G-16 rule-file update, negative-chapter guard)
- **TD-029** (5 advisory items from story-006 /code-review; 4 applied in-cycle; **1 remains deferred**: A-5 migration-callable static-lint evaluation)
- **TD-030** (3 advisory items from story-008 /code-review: `lint_save_paths.sh` doc nitpick, legacy `if !` bash bug in `lint_per_frame_emit.sh`, batch refactor proposal)
- **TD-031** (7 advisory items from story-007 /code-review; all bundled with AC-TARGET Polish-phase session: rename call-form fidelity, advisory threshold tightening, comment precision, `_max()` guard, payload-builder calibration, AC-DESKTOP bound tightening, story-007 checkbox)

All 14 items tracked in `docs/tech-debt-register.md`. None BLOCKING. None critical.

## Session Productivity Metrics (2026-04-24)

- 3 stories closed end-to-end in single session (006, 008, 007 in that order)
- Implementation effort 30-90 min per story (vs 2-4 hour estimates)
- Each story followed full cycle: `/dev-story` → `/code-review` → `/story-done` → commit → PR → merge
- All three stories landed green on first try (zero test-suite failures across stories 005/006/007/008)
- Automated test suite grew from 127 → 143 → 143 → 162 across the session's 3 closes

## Outstanding Work (Post-Epic-Close)

### Bundled with AC-TARGET Polish-phase session (TD-031)
- On-device Android perf measurement (Snapdragon 7-gen or equivalent)
- Evidence doc at `production/qa/evidence/save-v11-android-perf-<date>.md` per story-007 §7 template
- Story-007 status update from "Complete (with AC-TARGET DEFERRED)" to "Complete"
- 6 of 7 TD-031 items are polish-level code changes applied in the same session

### Deferred to future CI-infra polish cycle
- TD-028 items 4/5/6 (factory helper, G-16, negative-chapter)
- TD-029 A-5 (migration-callable static lint)
- TD-030 items 1/2/3 (CI lint polish batch)

## Relation to Pre-Production → Production Gate

Referring to `production/gate-checks/pre-prod-to-prod-2026-04-20.md` — the last formal phase-gate check:

| Artifact | 2026-04-20 Status | 2026-04-24 Status |
|----------|-------------------|-------------------|
| Art bible (9 sections) | ✅ | ✅ |
| ≥3 Foundation ADRs | ✅ | ✅ (4) |
| Master architecture doc | ✅ | ✅ |
| Accessibility requirements | ✅ | ✅ |
| Interaction pattern library | ✅ | ✅ |
| Test framework + CI workflow | ✅ | ✅ |
| HUD design doc | ⚠️ | ⚠️ |
| MVP GDDs complete | ✅ | ✅ |
| Character visual profiles | ❌ | ❌ |
| `prototypes/` with README | ❌ | ❌ |
| First sprint plan `production/sprints/` | ❌ | ❌ |
| Epics in `production/epics/` | ❌ | ✅ (4 Platform/Foundation epics, 2 fully closed) |
| Control manifest | ❌ | ✅ |
| Main menu UX spec | ❌ | ❌ |
| Pause menu UX spec | ❌ | ❌ |
| **Vertical Slice build — playable** | ❌ | ❌ (auto-FAIL unchanged) |
| Vertical Slice 3+ playtest reports | ❌ | ❌ |

**Progress since 2026-04-20**: 7/17 → 10/17 required artifacts present. Control manifest + epics unlocked. The Platform-layer work shipped in this window was prerequisite infrastructure for the eventual Vertical Slice.

**Remaining blockers** (same as 2026-04-20 FAIL):
1. Vertical Slice build (auto-FAIL condition)
2. No `prototypes/` directory
3. No `production/sprints/` directory (project uses `production/epics/` flow instead — may need reconciliation with gate-spec)
4. Character visual profiles not yet authored
5. Main menu + Pause menu UX specs not yet authored
6. Vertical Slice playtest reports (blocked on VS existing)

## Verdict: **EPIC CLOSED (Architecturally Complete)**

save-manager epic is architecturally complete with full QA sign-off APPROVED WITH CONDITIONS. V-11 on-device authoritative measurement is the only outstanding item, deferred per sanctioned pattern.

**This report does NOT advance the project phase.** Pre-Production → Production phase-gate remains FAILED pending Vertical Slice construction. Platform-layer work via additional Foundation/Gameplay epics is the path forward.

## Next Actions (Recommended Ordering)

1. **Commit this report** to preserve the epic-close audit trail on `main`
2. **Pick the next epic**: scenario-progression or another Foundation/Gameplay epic that moves toward Vertical Slice viability
3. **Author Vertical Slice prototype skeleton** at `prototypes/vertical-slice/` once a "start → challenge → resolution" loop becomes implementable from committed epics
4. **Defer full `/gate-check production` retry** until Vertical Slice exists and 3+ playtest reports are captured

## Chain-of-Verification

5 challenges checked:

1. *"Am I conflating epic close with phase advancement?"* — No. This report explicitly separates the two and defers phase-gate retry to when Vertical Slice exists.
2. *"Is V-11 DEFERRED correctly sanctioned or masking a real gap?"* — Sanctioned. Story-007 §7 allows deferral per scene-manager precedent; TD-031 has explicit closure conditions; desktop substitute at 52× under budget gives directional confidence.
3. *"Are the 14 tech-debt items actually low-priority or am I minimizing real gaps?"* — Actually low-priority. 3 are in-test polish, 7 are bundled with a Polish-phase session, 4 are deferred rule-file updates. None affect production behavior.
4. *"Do the 162 automated tests actually cover the 13 V-criteria, or is this a shallow mapping?"* — Real mapping. Each V-criterion cites specific test files. V-11 is the honest outlier (deferred, not shallow).
5. *"Is the 'architecturally complete' verdict too generous?"* — Honest. Epic-level architectural completion is measurably different from project-phase advancement. Report explicitly calls out that phase advancement remains blocked on Vertical Slice.

Verdict **unchanged**: EPIC CLOSED (Architecturally Complete) with V-11 condition tracked.
