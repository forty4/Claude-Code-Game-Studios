# Epic: Save/Load System (#17)

> **Layer**: Core
> **GDD**: `design/gdd/save-load.md` (rev 1.0 — Designed 2026-05-05 sprint-8 S8-08; 22 CRs + 5 formulas + 11 edge cases + 20 ACs + 5 OQs)
> **Architecture Module**: Save/Load — Core layer Persistence contract surface (`docs/architecture/architecture.md` §Core layer; depends on Platform-layer SaveManager epic)
> **Status**: Ready (2026-05-08; updated 2026-05-08 sprint-12 S12-01 — 3 story files authored via `/create-stories save-load`; 0/3 stories Complete; ready for /story-readiness → /dev-story)
> **Tier**: Vertical Slice
> **Stories**: 3 decomposed + authored (table below); 0/3 Complete

---

## Why a separate Core epic from the Platform-layer save-manager epic

`save-manager` (Platform, 8/8 Complete since 2026-04-24) implemented the **persistence substrate**: typed `SaveContext` Resource + autoload at `/root/SaveManager` load order 3 + atomic write protocol + 3-slot management + `SaveMigrationRegistry` scaffold + 7 TR-save-load-001..007 covered.

This **Core epic** implements the **contract surface** the GDD §3.5..3.7 + §Implementation hooks 11/12/13/15 specify — the parts the save-manager epic explicitly **excludes** under its `## Scope > Does not implement` list. Specifically:

1. **ScenarioRunner emission of `save_checkpoint_requested(ctx)`** at the 3 CP boundaries (CP-1 Beat 1 entry, CP-2 SceneManager RETURNING_FROM_BATTLE → IDLE, CP-3 next-chapter Beat 1) per CR-SL-5..8. Save-manager epic line 53 explicitly: *"ScenarioRunner emission of `save_checkpoint_requested` — belongs to Scenario Progression epic"*. In practice scenario-progression epic is Complete but did NOT ship the 3-CP emission (only the 9-beat state machine + ChapterDefinition contracts).
2. **Cross-chapter continuity: Destiny State populator pattern** (CR-SL-15) — Destiny State subscribes to `save_checkpoint_requested` and populates `ctx.echo_count` + `ctx.echo_marks_archive` + `ctx.flags_to_set` before SaveManager fires the deferred-frame disk write.
3. **`save_loaded(ctx: SaveContext)` GameBus signal** (CR-SL-19) — declared in the GDD but NOT yet shipped in `game_bus.gd`. Sprint-12 implementation ships this as the 4th Persistence-domain signal via ADR-0001 minor amendment per Evolution Rule #4. Resolves OQ-SL-3 (signal-vs-method-call dispatch decision).
4. **Failure-surfacing tests + missing lints** (CR-SL-21/22 + GDD §Implementation hooks items 6/7/8) — disk-full simulation, corrupted-file handling, mid-write crash recovery, and the CACHE_MODE_IGNORE / migration-callable-purity / SaveContext-export-discipline lints.

Routing: this epic is the **Core-layer consumer** of save-manager's Platform substrate. `systems-index.md` row 17 (Save/Load #17) stays at **Designed** until this epic ships; only then does row 17 flip to **Implemented**.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Save/Load Checkpoint Persistence | SaveContext typed Resource + atomic write + 3-CP policy + multi-slot independence + migration scaffold (Platform substrate already shipped via save-manager epic; this epic ratifies the consumer contracts) | MEDIUM (inherits from save-manager epic — `duplicate_deep` 4.5+, `rename_absolute` platform-scoped, `DirAccess.get_files_at` 4.6 idiom — all already validated by save-manager epic green tests) |
| ADR-0017: ScenarioRunner Autoload | ScenarioRunner emits `save_checkpoint_requested(ctx)` at 3 CP boundaries via the GameBus relay; CP-2 timing tied to SceneManager RETURNING_FROM_BATTLE → IDLE transition | LOW (ScenarioRunner state machine already shipped at sprint-7 S7-02 commit `ba02e02`; this epic adds the 3 emission call sites) |
| ADR-0002: SceneManager | CP-2 timing boundary = SceneManager's RETURNING_FROM_BATTLE → IDLE post-Beat-7-seal transition; this epic observes the transition via ScenarioRunner subscriber pattern | LOW (state machine + transitions already shipped) |
| ADR-0001: GameBus Autoload | Consumed: `save_checkpoint_requested(SaveContext)` (already declared); Emitted: `save_persisted(int, int)`, `save_load_failed(String, String)` (already declared); **NEW** `save_loaded(SaveContext)` (4th Persistence-domain signal — ADR-0001 minor amendment per Evolution Rule #4 ships in story 002 of this epic) | LOW (signal addition; existing signals already in flight) |

**Highest engine risk**: MEDIUM (inherits from ADR-0003 substrate; this epic adds no new post-cutoff API surface)

## GDD Requirements (this epic implements)

| TR-ID | Requirement | ADR Coverage | Story |
|-------|-------------|--------------|-------|
| TR-save-load-008 | ScenarioRunner emits `save_checkpoint_requested(ctx)` at CP-1 (Beat 1 entry) | ADR-0003 + ADR-0017 | story-001 |
| TR-save-load-009 | ScenarioRunner emits `save_checkpoint_requested(ctx)` at CP-2 (RETURNING_FROM_BATTLE → IDLE post-Beat 7) | ADR-0003 + ADR-0017 + ADR-0002 | story-001 |
| TR-save-load-010 | ScenarioRunner emits `save_checkpoint_requested(ctx)` at CP-3 (next-chapter Beat 1 entry) | ADR-0003 + ADR-0017 | story-001 |
| TR-save-load-011 | Per-chapter checkpoint files accumulate within slot (no pruning at next-chapter advance) | ADR-0003 + GDD CR-SL-6 | story-001 |
| TR-save-load-012 | Destiny State populator populates `ctx.echo_count` + `ctx.echo_marks_archive` + `ctx.flags_to_set` before SaveManager fires disk write | ADR-0003 + GDD CR-SL-15 | story-002 |
| TR-save-load-013 | `scenario_path_key` field is `"::"`-delimited per F-SP-4 cross-doc bridge; `branch_path_id` regex `^[A-Za-z0-9_]+$` | ADR-0003 + GDD CR-SL-16 + scenario-progression F-SP-4 | story-002 |
| TR-save-load-014 | `save_loaded(ctx: SaveContext)` 4th Persistence-domain GameBus signal added per ADR-0001 minor amendment | ADR-0001 + GDD CR-SL-19 | story-002 |
| TR-save-load-015 | Hydration is idempotent (calling `load_latest_checkpoint()` twice with no intervening saves yields field-identical `SaveContext` instances) | ADR-0003 + GDD CR-SL-20 | story-002 |
| TR-save-load-016 | All save/load failure paths emit `save_load_failed(op, reason)`; `op ∈ {"save","load"}`; `reason` is structured snake_case identifier | ADR-0001 + GDD CR-SL-21 | story-003 |
| TR-save-load-017 | SaveManager never crashes on save/load failure (returns `false` from save_checkpoint, `null` from load_latest_checkpoint) | ADR-0003 + GDD CR-SL-22 | story-003 |
| TR-save-load-018 | CR-SL-11 enforcement lint — every `ResourceLoader.load` in save_manager.gd uses `CACHE_MODE_IGNORE` | GDD CR-SL-11 + Implementation hook 6 | story-003 |
| TR-save-load-019 | CR-SL-13 enforcement lint — no captured-reference patterns in `_migrations` Dictionary entries (migration callable purity) | ADR-0003 + GDD CR-SL-13 + Implementation hook 7 | story-003 |
| TR-save-load-020 | CR-SL-2 enforcement lint — every field on SaveContext + EchoMark has `@export` annotation | ADR-0003 + GDD CR-SL-2 + Implementation hook 8 | story-003 |

**Untraced Requirements**: None within this epic's scope. CR-SL-1..4 (schema) and CR-SL-9..14 (atomic write + migration purity) are covered by the save-manager Platform epic (TR-save-load-001..007).

## Scope

**Implements**:
- `src/feature/scenario_runner/scenario_runner.gd` — 3 emission call sites for `save_checkpoint_requested(ctx)` at the BEAT_1_INTRO entry + RETURNING_FROM_BATTLE → IDLE handler + next-chapter BEAT_1_INTRO transition (story-001)
- `src/feature/destiny_state/destiny_state.gd` (or autoload sibling per CR-DS-7 + CR-DS-16 — node not yet authored as of 2026-05-08; verify ADR ratification at story-readiness time) — populator subscriber for `save_checkpoint_requested` (story-002)
- `src/core/game_bus.gd` — declare `save_loaded(ctx: SaveContext)` 4th Persistence-domain signal + emit on `SaveManager.load_latest_checkpoint()` success (story-002, ADR-0001 minor amendment)
- `tests/integration/scenario_runner/save_checkpoint_emission_test.gd` — AC-SL-1..4 verification (story-001)
- `tests/integration/save_load/cross_chapter_continuity_test.gd` — AC-SL-12..14 verification (story-002)
- `tests/integration/save_load/failure_surfacing_test.gd` — AC-SL-15..17 verification (story-003)
- `tools/ci/lint_save_resource_loader_cache_mode_ignore.sh` — CR-SL-11 enforcement (story-003)
- `tools/ci/lint_save_migration_callable_purity.sh` — CR-SL-13 enforcement (story-003)
- `tools/ci/lint_save_context_export_discipline.sh` — CR-SL-2 enforcement (story-003)
- `systems-index.md` row 17 status flip Designed → Implemented (story-003 final close)

**Does not implement**:
- SaveContext schema, autoload, atomic write, multi-slot management, migration scaffold — these are owned by the save-manager Platform epic (already Complete)
- Save Slot UI, Continue button visibility, error toast UI — these belong to Main Menu / Save Slot UI epic (Presentation layer; gated by AD-C6 + sprint-11 S11-08 main-menu UX spec stub)
- FLAG_COMPRESS enablement — deferred-decision item per save-manager epic Implementation Decisions Deferred
- iCloud backup exclusion — product decision deferred per save-manager epic

## Dependencies

**Depends on (must be Complete before stories can start)**:
- save-manager epic ✅ Complete 2026-04-24 — Platform substrate
- scenario-progression epic ✅ Complete 2026-05-07 — ScenarioRunner state machine + 9-beat rhythm + ChapterDefinition Resource
- destiny-branch epic ✅ Complete 2026-05-07 — DestinyBranchChoice typed Resource (branch_key + is_canonical_history field providers for SaveContext)
- ai-system epic ✅ Complete 2026-05-07 — required for full BattleScene mount sequence integration test (AC-SL-12 cross-chapter continuity exercises the full mount sequence)
- destiny-state node implementation — provisional dependency; if destiny-state node is not yet implemented at sprint-12 start, this epic's story-002 may need to scaffold it OR the destiny-state contract is satisfied by an ADR-only ratification (verify at /story-readiness time)

**Enables**:
- Main Menu / Save Slot UI epic (#18 Alpha — slot enumeration + Continue button visibility unblocked)
- systems-index.md row 17 flip Designed → Implemented (epic-terminal closure)
- Pillar 4 cross-session narrative continuity (Destiny State flag + EchoMark archive persistence becomes mechanically observable across sessions)

## Stories

| # | Story | File | Type | Status | ADR | Covers |
|---|-------|------|------|--------|-----|--------|
| 001 | ScenarioRunner CP-1/2/3 emission contract | [story-001-scenario-runner-cp-emission.md](story-001-scenario-runner-cp-emission.md) | Integration | Ready | ADR-0017 + ADR-0003 + ADR-0002 | TR-save-load-008/009/010/011; AC-SL-1..4; CR-SL-5..8 |
| 002 | Cross-chapter continuity — Destiny State populator + `save_loaded` signal addition + idempotent hydration | [story-002-cross-chapter-continuity.md](story-002-cross-chapter-continuity.md) | Integration | Ready | ADR-0003 + ADR-0001 + ADR-0017 | TR-save-load-012/013/014/015; AC-SL-12..14 + AC-SL-20; CR-SL-15..20 |
| 003 | Failure surfacing tests + 3 enforcement lints + systems-index row 17 flip (epic-terminal) | [story-003-failure-surfacing-and-lints.md](story-003-failure-surfacing-and-lints.md) | Integration | Ready | ADR-0003 + ADR-0001 | TR-save-load-016/017/018/019/020; AC-SL-15..17 + 7 epic-terminal AC; CR-SL-2/11/13/21/22 |

**Implementation order**: 001 → 002 → 003 (sequential; story-002 depends on the 3-CP emission firing in story-001, story-003 depends on the full pipeline being operational for failure-injection tests)

**Estimated total**: ~1.8-3d nominal (Vertical Slice tier; matches save-load.md GDD §Implementation hooks scope)

**Engine risk (highest)**: MEDIUM (inherits from ADR-0003 substrate; this epic introduces NO new post-cutoff API surface — all primitives validated by save-manager green tests)

**Test evidence targets**:
- Integration: `tests/integration/scenario_runner/save_checkpoint_emission_test.gd` (story-001), `tests/integration/save_load/cross_chapter_continuity_test.gd` (story-002), `tests/integration/save_load/failure_surfacing_test.gd` (story-003)
- Lint smoke: `tests/unit/tools_ci/lint_save_load_smoke_test.gd` (story-003 — verifies all 3 new lints exist + are executable + return appropriate exit codes on positive/negative cases)

## Open Questions (carried from save-load.md GDD §OQ-SL-1..5)

- **OQ-SL-1**: Should `play_time_seconds` be wallclock-since-launch OR active-foreground-only? — resolve at story-001 time (affects which subsystem owns the field's increment).
- **OQ-SL-2**: Should ScenarioRunner emit a 4th CP at chapter-end (post-CP-3) for end-of-arc archival? — resolve at story-001 time (affects emission count + AC-SL-1..4 boundary).
- **OQ-SL-3**: `save_loaded` signal-based dispatch vs method-call distribution — resolve at story-002 time (affects ADR-0001 minor amendment vs caller-distributes-via-setters pattern).
- **OQ-SL-4**: Should `SaveContext.echo_marks_archive` be capped at N entries to bound disk size? — resolve at story-002 time OR Polish-tier deferral if no immediate forcing function.
- **OQ-SL-5**: Should corrupted-file recovery attempt the next-newer-CP fallback OR surface error directly to UI? — resolve at story-003 time (drives AC-SL-16 behavior).

## Definition of Done

This epic is Complete when:

- All 3 stories are implemented, reviewed, and closed via `/story-done`
- All 13 TRs (TR-save-load-008..020) traced and verified
- AC-SL-1..4 (3-CP emission contract) verified via story-001 integration test
- AC-SL-12..14 (cross-chapter continuity + idempotent hydration) verified via story-002 integration test
- AC-SL-15..17 (failure surfacing) verified via story-003 integration test (disk-full sim + corrupted file + crash recovery)
- All 3 new lints (CACHE_MODE_IGNORE + migration purity + export discipline) PASS on main HEAD
- ADR-0001 minor amendment for `save_loaded` signal landed + `game_bus.gd` declares the signal + smoke test verifies signal connectability
- `production/epics/index.md` row updated with Complete status + 🎉 marker
- `design/gdd/systems-index.md` row 17 status flipped Designed → Implemented
- All 5 OQs (OQ-SL-1..5) resolved (in story body or amendment log)
- Verification summary at `production/qa/evidence/save_load_verification_summary.md`

## Next Step

Run `/create-stories save-load` at sprint-12 kick-off to flesh out the 3 story files (story-001-scenario-runner-cp-emission.md, story-002-cross-chapter-continuity.md, story-003-failure-surfacing-and-lints.md). Then `/story-readiness` on story-001 → `/dev-story` to begin implementation.

---

## Cross-references

- GDD: `design/gdd/save-load.md` rev 1.0 (sprint-8 S8-08; 22 CRs + 5 formulas + 11 edge cases + 20 ACs + 5 OQs; §Implementation hooks 1-16 enumerated)
- Platform substrate: `production/epics/save-manager/EPIC.md` (Complete 2026-04-24; 8/8 stories; TR-save-load-001..007)
- ScenarioRunner Core epic: `production/epics/scenario-progression/EPIC.md` (Complete 2026-05-07; 1/1; ADR-0017 source-of-truth)
- DestinyBranch Core epic: `production/epics/destiny-branch/EPIC.md` (Complete 2026-05-07; 1/1; provides `branch_key` + `is_canonical_history` field providers)
- AI System Feature epic: `production/epics/ai-system/EPIC.md` (Complete 2026-05-07; 1/1; required for full BattleScene mount sequence integration test)
- Sprint task: sprint-11 S11-07 (this epic creation; sprint-status.yaml line 103-111)
- Epic graduation source: `design/gdd/systems-index.md` row 17 (currently Designed; flips to Implemented on epic-terminal)
- Cross-doc obligation source: `design/gdd/scenario-progression.md` F-SP-4 (scenario_path_key delimiter `::` migration; satisfied via CR-SL-16 in this epic's story-002)
- ADR-0001 amendment driver: GDD CR-SL-19 + OQ-SL-3 — sprint-12 story-002 ships
- Carryover chain: sprint-9 S9-06 (1st-time deferred) → sprint-10 S10-06 (2nd-time deferred) → sprint-11 S11-07 (epic created — NOT impl; sprint-12 will run /create-stories + ship)
