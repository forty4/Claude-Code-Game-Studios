# QA Sign-Off Report: map-grid epic

**Date**: 2026-04-25
**QA Lead sign-off**: APPROVED WITH CONDITIONS (paper review per Path C hybrid)
**QA Cycle Type**: Foundation-only epic close-out — paper review, no manual execution phase
**Cycle Path**: Phase 1 (load) → Phase 2 (strategy) → Phase 7 (sign-off). Phases 3-6 skipped per qa-lead recommendation.

---

## Cycle Path Rationale

Standard `/team-qa sprint` cycles run Phases 4-6 (test plan write + test case scaffolding + manual QA execution) for stories that ship user-facing changes a tester can exercise. The map-grid epic is Foundation-only:

- 9 query methods (`get_movement_range`, `get_movement_path`, `has_line_of_sight`, etc.) consumed by future Core/Feature epics that don't exist yet
- No main scene wired up; no gameplay loop exercising the queries
- Per-story `## QA Test Cases` sections authored inline pre-implementation (lean mode shift-left)
- /code-review specialists (godot-gdscript-specialist + qa-tester) ran convergent reviews on stories 005-008 and returned CLEAN / APPROVED with all suggestions either applied inline or queued to TD-032

Phases 4-6 would produce 8 N/A manual-execution rows. The right artifact is a sign-off report that aggregates the existing evidence, which is what this document does.

---

## Test Coverage Summary

| Story | Type | Auto Test | Manual QA | Result |
|-------|------|-----------|-----------|--------|
| 001 MapResource + MapTileData | Logic | `tests/unit/core/map_resource_test.gd` | — | PASS |
| 002 MapGrid skeleton + 6 caches | Logic | `tests/unit/core/map_grid_test.gd` | — | PASS |
| 003 Loading validation + errors | Logic | `tests/unit/core/map_grid_validation_test.gd` | — | PASS |
| 004 Mutation API + signal | Integration | `tests/integration/core/map_grid_mutation_test.gd` | — | PASS |
| 005 Custom Dijkstra | Logic | `tests/unit/core/map_grid_pathfinding_test.gd` (16 tests; V-4 50-query equivalence) | — | PASS |
| 006 LoS + attack queries | Logic | `tests/unit/core/map_grid_queries_test.gd` (13 tests; V-3 20-case matrix) | — | PASS |
| 007 Perf baseline | Integration | `tests/integration/core/map_grid_perf_test.gd` (3 tests; V-1 desktop) | Mobile AC-TARGET DEFERRED to Polish | PASS WITH NOTES |
| 008 Inspector authoring | UI | `tests/integration/core/map_grid_inspector_fixtures_test.gd` (2 tests; 4 of 7 ACs programmatic) | `production/qa/evidence/map-grid-inspector-v7.md` 3 manual ACs PENDING USER SIGN-OFF | PASS WITH NOTES |

**Aggregate**: 231/231 automated PASS (0 errors, 0 failures, 0 flaky, 0 skipped, 0 orphans, exit 0). Story-007 + Story-008 carry advisory notes, both documented and tracked.

---

## /code-review Specialist Verdicts (per story)

| Story | godot-gdscript-specialist | qa-tester | Convergent finding? |
|-------|--------------------------|-----------|---------------------|
| 005 | APPROVED WITH SUGGESTIONS (3 doc fixes applied inline) | GAPS (1 advisory AC; 4 follow-up tests queued A-23..A-26) | YES — inverted assertion at line 200 caught both reviewers; resolved inline by restructuring AC-2a/2b at (3,0) for actual budget discriminator under standard Dijkstra cost model |
| 006 | CLEAN (5 specific findings, all positive; no red flags) | TESTABLE WITH GAPS (12/14 ACs covered; 3 follow-ups queued) | None |
| 007 | SUGGESTIONS (4 doc fixes applied inline; pattern fidelity 7-of-7 vs save_perf_test.gd) | GAPS (3 follow-ups queued A-27..A-29 for warmup polish + JSON artifact + reproducibility AC deferral) | None |
| 008 | CLEAN (5 specific findings, all positive; pattern fidelity 7-of-7 vs story-007 generator) | ACHIEVABLE WITH GAPS (5 of 6 manual-protocol improvements applied inline; 1 spec erratum A-31 queued) | None |

All 4 reviews ran in lean mode with parallel specialists; ~1.5 min combined runtime per story.

---

## Performance Verification

`get_movement_range(move_range=10)` on the 40×30 stress fixture (1200 tiles):

| Metric | Value | Threshold |
|--------|------:|----------:|
| p50 | 0.272 ms | — |
| **p95** | **0.288 ms** | **16 ms HARD (AC-PERF-2 mobile target)** |
| max | 0.376 ms | — |
| mean | 0.270 ms | — |
| warmup ratio | 1.08× | 3× advisory / 5× hard |
| Frame-time over-budget runs | 0/100 | 0 3-consecutive >16.6 ms |

**~17× under ADR-0004's <5 ms desktop expectation; ~55× under AC-PERF-2 16 ms mobile target.** ADR-0004 R-1 fallbacks (map cap 32×24, flow-field precompute, GDExtension C++) NOT triggered. Mobile remains plausible without invoking them.

---

## Bugs Found

| ID | Story | Severity | Status |
|----|-------|----------|--------|
| — | — | — | — |

**No bugs filed during the QA cycle.** All issues caught during implementation/review (3 algorithm bugs in story-006, 1 cost-model misalignment in story-005, 1 fixture drift in story-007, 5 manual-protocol gaps in story-008) were resolved inline before the story closed via `/story-done`.

---

## Spec-Implementation Drift Resolution (TD-032 Errata)

During the epic, 7 spec-vs-implementation drifts were identified and reconciled in a dedicated errata pass (`chore/map-grid-td-032-adr-errata` branch, PR #30):

| Errata ID | Description | Files updated | Status |
|-----------|-------------|---------------|--------|
| A-16 | TerrainCost integer ordering | none (deviation captured in story-005 Completion Notes + `terrain_cost.gd:13`) | RESOLVED |
| A-18 | `get_path` → `get_movement_path` rename (Node.get_path collision) | ADR-0004 §Decision 5 + §Key Interfaces, TR-map-grid-003, GDD cross-system contract table | RESOLVED |
| A-20 | Cost-model interpretation (standard Dijkstra vs origin-included) | ADR-0004 §Decision 7, GDD §F-3 example block, story-005 spec AC-F-3 | RESOLVED |
| A-21 | Extended query signatures (apply_los, defender_facing, faction filter) | ADR-0004 §Decision 5, TR-map-grid-003 | RESOLVED |
| A-22 | `get_attack_direction` sign convention errata | story-006 spec line 70-73, GDD §F-5 (formula + variable table + 4-direction example matrix) | RESOLVED |
| A-31 | Story-008 R-3 type= erratum (TileData → Resource) | story-008 spec AC-R3-INLINE-ASSERT + AC-5 | RESOLVED |
| A-17 | DESTRUCTIBLE skip-list defensive guard | not applied; `_passable_base_cache==0` orthogonal guard sufficient | CLOSED |

ADR-0004 is now fully aligned with the actual implementation. Cross-system contract with `damage-calc.md` (consumer of `get_attack_direction`) verified clean.

---

## Verification Matrix Coverage

| ID | Description | Method | Result |
|----|-------------|--------|--------|
| V-1 | `get_movement_range` <16ms on 40×30 m=10 | `map_grid_perf_test.gd::test_..._p95_under_desktop_budget` (desktop substitute) | ✅ p95=0.288ms |
| V-1 (mobile) | Mobile AC-TARGET on Snapdragon 7-gen Android | DEFERRED to Polish phase per story-007 §7 | 🟡 DEFERRED — reactivation trigger: first Android export build green |
| V-2 | `MapResource` round-trip via `duplicate_deep` | `map_grid_test.gd` (story-002) | ✅ |
| V-3 | LoS 20-case matrix | `map_grid_queries_test.gd::test_..._v3_matrix_20_cases` | ✅ 20/20 |
| V-4 | Dijkstra 50-query reference equivalence | `map_grid_pathfinding_test.gd::test_..._reference_equivalence_50_queries` | ✅ 50/50 |
| V-5 | Cache-sync per mutation | `map_grid_mutation_test.gd` | ✅ |
| V-6 | Signal emission (`tile_destroyed`) | `map_grid_mutation_test.gd` | ✅ |
| V-7 | 40×30 inspector load without hang (programmatic) | `map_grid_inspector_fixtures_test.gd::test_..._stress_40x30_loads_and_validates` | ✅ |
| V-7 | 40×30 inspector load without hang (manual stopwatch) | `production/qa/evidence/map-grid-inspector-v7.md` Manual AC-2 | 🟡 PENDING USER SIGN-OFF |
| V-8 | Memory profile ≤250 MB IN_BATTLE | OUT OF SCOPE — belongs to SceneManager integration story | — |

---

## Verdict: **APPROVED WITH CONDITIONS**

**Rationale**: All blocking Logic and Integration gates satisfied (231/231 automated PASS); all 4 stories that landed in this session reviewed clean by /code-review specialists; spec-implementation drift fully reconciled via TD-032 errata pass. Two non-technical conditions remain to fully close the epic:

### Conditions (must complete before next sprint begins)

1. **Story-008 manual sign-off** — Open Godot 4.6 editor, perform 3 manual ACs in `production/qa/evidence/map-grid-inspector-v7.md` (inspector load stopwatch ≤30s; TileData edit round-trip; capture 2 screenshots). Change evidence doc `Status:` to `COMPLETE — SIGNED OFF`. Estimated 10-15 min. **No re-run of `/story-done` needed** — story-008 is already Complete with the manual portion explicitly tracked.

2. **Merge PR queue** in dependency order:
   - PR #26 (story-005 Custom Dijkstra)
   - PR #27 (story-006 LoS + attack queries) — auto-rebases when #26 lands
   - PR #28 (story-007 perf baseline) — auto-rebases when #27 lands
   - PR #29 (story-008 inspector authoring) — auto-rebases when #28 lands
   - PR #30 (TD-032 ADR errata, doc-only) — independent of the chain; can merge any time

### Deferred (NOT conditions for this epic; tracked for future sprints)

- **TD-032 A-23..A-26** (story-006 advisory tests): destroyed-wall LoS restoration, defensive guards, full 4×4 direction matrix, tie-break × non-NORTH facing — ~75 min combined
- **TD-032 A-27..A-28** (story-007 advisory tests): warmup polish, frame-time symmetry — ~10 min combined
- **TD-032 A-29..A-30** (perf-trend infrastructure): JSON artifact + multi-run variance check — deferred until consumer dashboard exists, ~40 min combined
- **Story-007 mobile AC-TARGET**: on-device Snapdragon 7-gen Android benchmark — Polish phase per ADR-0004 R-1 precedent; reactivation trigger = first Android export build green on CI

### Next Step

Once conditions 1 + 2 are resolved, run `/gate-check` to validate stage advancement. Until then, the map-grid epic is provisionally APPROVED but not formally closed.

---

## Linked artifacts

- Smoke check report: `production/qa/smoke-2026-04-25.md`
- Epic index: `production/epics/map-grid/EPIC.md`
- Story files: `production/epics/map-grid/story-{001..008}-*.md`
- ADR: `docs/architecture/ADR-0004-map-grid-data-model.md`
- TR registry: `docs/architecture/tr-registry.yaml`
- Tech debt: `docs/tech-debt-register.md` TD-032 batch
- GDD: `design/gdd/map-grid.md`
- Inspector evidence (in-progress): `production/qa/evidence/map-grid-inspector-v7.md`
- This sign-off: `production/qa/qa-signoff-map-grid-2026-04-25.md`
