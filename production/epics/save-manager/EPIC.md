# Epic: Save Manager

> **Layer**: Platform
> **GDD**: — (infrastructure; authoritative spec is ADR-0003; payload schema consumer: scenario-progression.md §Detailed Rules 3-CP policy)
> **Architecture Module**: SaveManager (docs/architecture/architecture.md §Platform layer)
> **Status**: Ready
> **Manifest Version**: 2026-04-20
> **Stories**: 8 decomposed (2026-04-22) — see table in §Stories

## Overview

SaveManager is the single autoload at `/root/SaveManager` (load order 3, after GameBus + SceneManager) that owns all save persistence: typed `SaveContext` Resource capture, atomic write-to-tmp → `DirAccess.rename_absolute` pattern, cache-bypass loads (`CACHE_MODE_IGNORE`), schema versioning with `SaveMigrationRegistry`, three-slot management at `user://saves/slot_{1,2,3}/ch_{MM}_cp_{N}.res`, and crash-recovery via newest-CP scan. All saves go through `duplicate_deep(DUPLICATE_DEEP_ALL_BUT_SCRIPTS)` before serialization (no live-state torn writes). The 3-CP policy captures checkpoints at Beat 1 entry (CP-1), post-Beat 7 on SceneManager's RETURNING_FROM_BATTLE → IDLE boundary (CP-2), and next-chapter Beat 1 entry (CP-3). Migration Callables are pure functions with no captured state. `BattleOutcome.Result` enum ordering is frozen as a persistence contract — reorder requires migration + schema_version bump.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0003: Save/Load — Checkpoint Persistence | `/root/SaveManager` autoload load order 3; SaveContext typed Resource with full `@export`; atomic tmp+rename on user:// only; CACHE_MODE_IGNORE loads; SaveMigrationRegistry pure Callables; 3 slots from MVP; append-only BattleOutcome enum | MEDIUM (`duplicate_deep` 4.5+; `DirAccess.rename_absolute` atomicity platform-scoped; `DirAccess.get_files_at` 4.6-idiomatic) |
| ADR-0001: GameBus Autoload | Consumed: `save_checkpoint_requested(SaveContext)`; Emitted: `save_persisted(int, int)`, `save_load_failed(String, String)` (all ratified via ADR-0001 amendment) | LOW |
| ADR-0002: Scene Manager | CP-2 timing boundary = SceneManager's RETURNING_FROM_BATTLE → IDLE transition; SaveManager observes via ScenarioRunner's `battle_outcome_resolved` handler, which emits the checkpoint request | MEDIUM (inherits) |

**Highest engine risk**: MEDIUM

## GDD Requirements

| TR-ID | Requirement | ADR Coverage |
|-------|-------------|--------------|
| TR-save-load-001 | `/root/SaveManager` autoload, load order 3 | ADR-0003 ✅ |
| TR-save-load-002 | All SaveContext + EchoMark fields `@export`-annotated; EchoMark extends Resource with `class_name` | ADR-0003 ✅ |
| TR-save-load-003 | Save pipeline: `duplicate_deep` → `ResourceSaver.save(tmp)` → `rename_absolute` (atomic) | ADR-0003 ✅ |
| TR-save-load-004 | All loads use `ResourceLoader.load(path, "", CACHE_MODE_IGNORE)` | ADR-0003 ✅ |
| TR-save-load-005 | `BattleOutcome.Result` append-only; reorder requires migration + schema_version bump | ADR-0003 ✅ |
| TR-save-load-006 | Save root `user://saves`; no SAF / external-storage paths | ADR-0003 ✅ |
| TR-save-load-007 | Migration Callables pure functions; no captured node/singleton/object state | ADR-0003 ✅ |

**Untraced Requirements**: None.

## Scope

**Implements**:
- `src/core/payloads/save_context.gd` — typed `SaveContext` Resource with all fields `@export` (REPLACES gamebus story-002 PROVISIONAL stub at same path)
- `src/core/payloads/echo_mark.gd` — typed `EchoMark` Resource with `class_name` + full `@export` coverage (blocking schema invariant) (REPLACES stub)
- `src/core/save_manager.gd` — autoload with `save_checkpoint()`, `load_latest_checkpoint()`, `list_slots()`, `set_active_slot()`, `_find_latest_cp_file()` using `DirAccess.get_files_at`
- `src/core/save_migration_registry.gd` — static migration registry (initially empty Dictionary; first entry lands on schema v2)
- `project.godot` — autoload registration at load order 3
- `tests/unit/core/save_manager_test.gd` — V-1..V-12 coverage (round-trip, atomic write, crash safety, CACHE_MODE_IGNORE, slot isolation, corrupt-file handling, migration chain)
- `tests/unit/core/save_context_test.gd` — field `@export` coverage lint (V-3 grep-check)
- `tests/integration/core/save_perf_test.gd` — V-11 full save cycle <50 ms on mid-range Android (100 iterations, 95th percentile)
- CI lint: no `GameBus.*.emit` in `_process` / `_physics_process` of save_manager.gd (V-13); no `/sdcard`, `content://`, SAF APIs in save code (V-10)

**Does not implement**:
- Save Slot UI — belongs to Main Menu / Save Slot UI epic (Presentation layer)
- ScenarioRunner emission of `save_checkpoint_requested` — belongs to Scenario Progression epic
- FLAG_COMPRESS enablement — deferred-decision item pending first realistic benchmark (carried in control-manifest Implementation Decisions Deferred)
- iCloud backup exclusion — product decision deferred

## Dependencies

**Depends on (must be Accepted before stories can start)**:
- ADR-0001 (GameBus) ✅ Accepted 2026-04-18 — Persistence domain signals
- ADR-0002 (SceneManager) ✅ Accepted 2026-04-18 — CP-2 timing boundary

**Enables**:
- Scenario Progression implementation (#6 MVP — 3-CP recovery contract ratified)
- Save Slot UI implementation (#18 Alpha — slot enumeration + metadata contract)
- Crash-recovery QA test suite

## Implementation Decisions Deferred (from control-manifest)

- **`FLAG_COMPRESS` on/off**: decided after first realistic save payload benchmark. Default OFF until benchmark shows payloads >50 KB uncompressed.
- **iCloud backup exclusion**: set `NSUbiquitousItemIsExcludedFromBackupKey` on `user://saves/`? Default NO (saves backed up). Product decision deferred.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All acceptance criteria embedded in stories (derived from ADR-0003 V-1..V-13) are verified
- Round-trip test V-1 passes (all SaveContext fields preserved)
- V-2: Array[EchoMark] survives serialization (10 unique EchoMarks)
- V-3: lint-confirmed every EchoMark field has `@export`
- V-4, V-5: atomic write — tmp cleaned on failure; crash during save leaves old file intact
- V-6: schema migration chain reaches CURRENT for all versions 1..CURRENT
- V-7: `CACHE_MODE_IGNORE` enforced (overwrite + reload returns new content)
- V-8, V-9: slot isolation + corrupt-file resilience
- V-10: save path lint-confirmed `user://`-only
- V-11: full save cycle <50 ms on mid-range Android (100 iterations, 95th percentile)
- V-12: `load_latest_checkpoint` returns newest CP by chapter×cp ordering
- V-13: no per-frame GameBus emits in save_manager.gd

## Stories

| # | Story | Type | Status | ADR | Covers |
|---|-------|------|--------|-----|--------|
| 001 | SaveContext + EchoMark Resource classes | Logic | Complete | ADR-0003 | TR-save-load-002, V-3 |
| 002 | SaveManager autoload skeleton + project.godot registration | Logic | Complete | ADR-0003 | TR-save-load-001 |
| 003 | SaveManagerStub for GdUnit4 test isolation | Logic | Complete | ADR-0003 | V-4/V-5/V-7/V-8/V-9 prereq |
| 004 | Save pipeline — duplicate_deep → ResourceSaver → atomic rename | Logic | Complete | ADR-0003 | TR-save-load-003, V-1, V-4, V-5 |
| 005 | Load pipeline — list_slots + load_latest_checkpoint + crash-recovery scan | Logic | Complete | ADR-0003 | TR-save-load-004, V-2, V-7, V-8, V-9, V-12 |
| 006 | SaveMigrationRegistry + schema version chain | Logic | Complete | ADR-0003 | TR-save-load-007, V-6 |
| 007 | Perf baseline + target-device verification (V-11 <50ms) | Integration | Ready | ADR-0003 | V-11 |
| 008 | CI lint — user://-only + no-per-frame-emit + BattleOutcome append-only | Config/Data | Ready | ADR-0003 | TR-save-load-005, TR-save-load-006 (V-10), V-13 |

**Implementation order**: 001 → 002 → 003 → 004 → {005, 006 parallel} → {007, 008 parallel}

**Engine risk (highest)**: MEDIUM (`duplicate_deep` 4.5+, `rename_absolute` platform-scoped, `DirAccess.get_files_at` 4.6 idiom)

**Test evidence targets**:
- Logic: `tests/unit/core/save_[feature]_test.gd` (stories 001-006)
- Integration: `tests/integration/core/save_perf_test.gd` (story 007)
- Config/Data: `production/qa/smoke-save-v10-v13-lint.md` (story 008)

## Next Step

Run `/story-readiness production/epics/save-manager/story-001-save-context-echo-mark-classes.md` to validate story-001 readiness, then `/dev-story` to begin implementation. Stories 002-008 unlock progressively per the implementation order above.
