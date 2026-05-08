# Save/Load — Epic Verification Summary

> **Epic**: `production/epics/save-load/EPIC.md`
> **Sprint**: Sprint 12 (S12-01 follow-on through epic-terminal close — 2026-05-08)
> **Governing ADRs**: `docs/architecture/ADR-0003-save-load.md` + `docs/architecture/ADR-0001-gamebus-autoload.md` + `docs/architecture/ADR-0017-scenario-progression.md`
> **Closing Story**: `production/epics/save-load/story-003-failure-surfacing-and-lints.md`
> **Date**: 2026-05-08
> **Author**: Dowan Kim

---

## Epic Outcome — All 3 Stories Complete

| # | Story | Tests added | Sprint slot |
|---|---|---:|---|
| 001 | ScenarioRunner CP-1/2/3 emission contract | +8 | S12-01 follow-on |
| 002 | Cross-chapter continuity — Destiny State populator + `save_loaded` GameBus signal addition + idempotent hydration | +9 | S12-01 follow-on |
| 003 | Failure surfacing tests + 3 enforcement lints + systems-index row 17 flip (epic-terminal) | +11 | S12-01 follow-on |

**Total**: ~+28 tests across this epic. **Test baseline**: 1236 (sprint-11 close, 52nd FFB) → **1264** (post-story-003). **55 consecutive failure-free baselines** since sprint-3 close (53rd at story-001 / 54th at story-002 / 55th at story-003).

**Cross-system stack consumed**:
- save-manager Platform substrate (Complete 2026-04-24; 8/8 stories) — SaveManager autoload + atomic write protocol + 3-slot management + SaveMigrationRegistry scaffold
- scenario-progression Core epic (Complete 2026-05-07) — ScenarioRunner state machine + ChapterDefinition typed Resource + 9-beat per-chapter rhythm
- destiny-branch Core epic (Complete 2026-05-07) — DestinyBranchChoice 9-field typed Resource + branch_key field provider
- destiny-state autoload (S8-10 sprint-8) — populator subscriber pattern; Pillar 2 architectural lock 5th invocation

---

## Engine Verification Item 1 — `duplicate_deep` mode (HIGH risk, Godot 4.5+)

**Source**: ADR-0003 §Decision §Atomic Write step 1 + save-manager epic story-001
**Outcome**: **PASS — verified via save-manager epic round-trip tests**

`Resource.DEEP_DUPLICATE_ALL` mode is the canonical 4.6 deep-duplicate flag (replaces 4.4-era `DUPLICATE_DEEP_ALL_BUT_SCRIPTS` per ADR-0003 errata TD-024). SaveManager.save_checkpoint duplicates the source SaveContext in this mode before serialization, guaranteeing no shared references with live state (R-1 mitigation).

- Source story: save-manager epic story-001 (sprint-7)
- Round-trip test: `tests/unit/core/save_manager_test.gd` round-trip suite
- Story-002 + story-003 inherit this contract; populator + rehydration also use `mark.duplicate(true)` per CR-DS-16

**KEEP forever** — protected by ADR-0003 §Constraints + R-1 mitigation invariant.

---

## Engine Verification Item 2 — `DirAccess.rename_absolute` atomicity (MEDIUM risk, platform-scoped)

**Source**: ADR-0003 §Atomicity Guarantees + TR-save-load-006 + V-5 test seam
**Outcome**: **PASS — verified via SaveManager unit + integration tests**

`DirAccess.rename_absolute` is atomic on `user://` paths only. Save root MUST remain `user://` per CR-SL-9 (enforced by `tools/ci/lint_save_paths.sh` — pre-existing save-manager lint). Story-003's failure_surfacing_test.gd exercises the rename failure path via the `_test_force_rename_error` test seam (V-5 from save-manager epic) plus the `_test_force_dir_open_null` seam (DIRACCESS-FAIL).

- Source story: save-manager epic story-004 (atomic-rename pipeline)
- Test seams used by story-003: `_test_force_save_error` (V-4) + `_test_force_rename_error` (V-5) + `_test_force_dir_open_null` (DIRACCESS-FAIL)
- Lint: `tools/ci/lint_save_paths.sh` (pre-existing; enforces `user://` prefix)

**KEEP through**: Polish phase + multi-platform soak test (iOS/Android external-storage exclusion verification).

---

## Engine Verification Item 3 — `ResourceLoader.CACHE_MODE_IGNORE` discipline (CRITICAL)

**Source**: ADR-0003 §Decision §Atomic Write step 3 + CR-SL-11 + TR-save-load-018
**Outcome**: **PASS — automated forever via Lint #6 (story-003)**

Every `ResourceLoader.load(...)` call in save-load source files MUST pass `CACHE_MODE_IGNORE` flag. Cached loads return stale post-overwrite objects; CACHE_MODE_IGNORE forces a fresh disk read every time. AC-SL-20 idempotency contract depends on this — story-002 round-trip + idempotent-load tests would silently break without this guarantee.

- Lint script: `tools/ci/lint_save_resource_loader_cache_mode_ignore.sh` (NEW story-003)
- Files scanned: `src/core/save_manager.gd` + `src/core/save_migration_registry.gd`
- Result on main HEAD (2026-05-08): **PASS — all `ResourceLoader.load()` calls pass CACHE_MODE_IGNORE**
- Smoke test: `tests/unit/tools_ci/lint_save_load_smoke_test.gd::test_lint_save_resource_loader_cache_mode_ignore_passes_on_main`
- Negative test recipe: drop `CACHE_MODE_IGNORE` from one ResourceLoader.load call → re-run → assert exit 1 → revert

**KEEP forever** — automated CI gate; first dedicated save-load lint precedent.

---

## Engine Verification Item 4 — Migration Callable Purity (CR-SL-13 BLOCKING)

**Source**: ADR-0003 §Schema Stability §Migration Callable Purity + CR-SL-13 + TR-save-load-019
**Outcome**: **PASS — automated forever via Lint #7 (story-003)**

Migrations in `_migrations: Dictionary[int, Callable]` MUST be pure functions with no captured node/singleton/object references. Captured refs outlive the migration and leak for the process lifetime, producing dangling references into freed scenes (per ADR-0003 lifetime-leak failure mode).

- Lint script: `tools/ci/lint_save_migration_callable_purity.sh` (NEW story-003)
- Files scanned: `src/core/save_migration_registry.gd`
- MVP state: `_migrations` is empty `{}` — lint passes with "0 migrations to validate"
- Result on main HEAD (2026-05-08): **PASS — empty migration registry; no captured-reference patterns**
- Smoke test: `tests/unit/tools_ci/lint_save_load_smoke_test.gd::test_lint_save_migration_callable_purity_passes_on_main`
- Negative test recipe: introduce `var captured_singleton = SaveManager` outside a lambda + reference inside → re-run → assert exit 1 → revert
- **Heuristic acknowledgment**: this is a forward-looking lint with false-positive risk on complex migration bodies. The lint protects against future regressions when post-MVP schema changes activate `_migrations` entries.

**KEEP forever** — automated CI gate; first heuristic-pattern lint precedent for the project.

---

## Engine Verification Item 5 — `@export` Discipline (CR-SL-2 BLOCKING)

**Source**: ADR-0003 §Schema Stability + CR-SL-2 + TR-save-load-020
**Outcome**: **PASS — automated forever via Lint #8 (story-003)**

Every `var` in `SaveContext` and `EchoMark` MUST be `@export`-annotated. Non-exported fields are SILENTLY DROPPED by ResourceSaver — a regression here would corrupt saves without any error signal.

- Lint script: `tools/ci/lint_save_context_export_discipline.sh` (NEW story-003)
- Files scanned: `src/core/payloads/save_context.gd` + `src/core/payloads/echo_mark.gd`
- Result on main HEAD (2026-05-08): **PASS — all 12 SaveContext fields + 3 EchoMark fields are @export-annotated**
- Smoke test: `tests/unit/tools_ci/lint_save_load_smoke_test.gd::test_lint_save_context_export_discipline_passes_on_main`
- Negative test recipe: remove `@export` from one SaveContext field → re-run → assert exit 1 → revert

**KEEP forever** — automated CI gate; protects against silent data corruption regressions.

---

## Engine Verification Item 6 — Failure Surfacing Contract (CR-SL-21..22)

**Source**: ADR-0003 §Constraints "Failures never crash" + CR-SL-21 + CR-SL-22 + TR-save-load-016/017
**Outcome**: **PASS — verified via story-003 integration test**

Every save/load failure path emits `save_load_failed(op, reason)` with structured snake_case reason; SaveManager never crashes on failure (returns `false` from save_checkpoint, `null` from load_latest_checkpoint).

- Source story: story-003 failure_surfacing_test.gd
- Test gates:
  - AC-SL-15: disk-full simulation → false return + save_load_failed("save", "resource_saver_error:%d") + no partial file at final_path
  - AC-SL-16: truncated file → null return + save_load_failed("load", "invalid_resource:...")
  - AC-SL-17: orphan .tmp.res file → loader skips orphan + returns prior checkpoint OR null
  - Sentinel: failure path emits `save_load_failed` (NOT `save_loaded`) — story-002 contract verified post-hoc

**KEEP through**: GDD MVP regression suite.

---

## Engine Verification Item 7 — GameBus Signal Contract (`save_loaded` minor amendment 2026-05-08)

**Source**: ADR-0001 §Evolution Rule #1 + #4 + ADR-0003 §Decision + GDD CR-SL-19 + TR-save-load-014
**Outcome**: **PASS — verified via story-002 integration test + 4-test signal contract verification**

`save_loaded(ctx: SaveContext)` is the 4th Persistence-domain GameBus signal. SaveManager emits after `SaveMigrationRegistry.migrate_to_current(ctx)` succeeds in `load_latest_checkpoint`; failure path emits `save_load_failed` instead per CR-SL-22 never-crash invariant. Destiny State subscribes via `CONNECT_DEFERRED` for CR-SL-19/20 idempotent rehydration.

- Source story: story-002 cross_chapter_continuity_test.gd
- Test gates:
  - `test_save_loaded_signal_emits_after_load_and_rehydrates_destiny_state`
  - `test_save_loaded_handler_null_payload_guard_is_noop`
  - `test_save_loaded_handler_idempotent_on_repeat_invocation`
- Signal-list keepers updated: `signal_contract_test.gd` + `game_bus_diagnostics_test.gd` + `game_bus_declaration_test.gd` (33 → 34 signals; `_route_to_domain` regression map +1 entry)
- ADR-0001 changelog: `2026-05-08 — Minor amendment (Evolution Rule #1 + #4): added save_loaded(SaveContext) to Persistence domain (#9) — 4th signal in domain. Signal count 30 → 31.`

**KEEP forever** — protected by signal-list keeper tests; structurally enforced.

---

## TR Coverage Table

13 TRs (TR-save-load-008..020) covered across 3 stories:

| TR-ID | Requirement (1-line) | Story | AC | Test / Lint | Status |
|-------|----------------------|-------|-----|-------------|--------|
| TR-save-load-008 | ScenarioRunner emits `save_checkpoint_requested(ctx)` at CP-1 (Beat 1 entry) | story-001 | AC-SL-1 | `tests/integration/scenario_runner/save_checkpoint_emission_test.gd::test_cp_1_emits_at_beat_1_anchor_with_correct_payload` | COVERED |
| TR-save-load-009 | ScenarioRunner emits at CP-2 (RETURNING_FROM_BATTLE → IDLE post-Beat 7) | story-001 | AC-SL-2 | `test_cp_2_emits_at_beat_7_with_*_outcome_and_branch_key` (WIN/LOSS/DRAW × 3) | COVERED |
| TR-save-load-010 | ScenarioRunner emits at CP-3 (BEAT_9 of completing chapter) | story-001 | AC-SL-3 | `test_cp_3_emits_at_beat_9_with_completing_chapter_number` | COVERED |
| TR-save-load-011 | Per-chapter checkpoint files accumulate within slot (no pruning) | story-001 | AC-SL-4 | `test_two_chapter_cycle_writes_four_distinct_save_files` | COVERED |
| TR-save-load-012 | Destiny State populator fills `ctx.echo_count` + `ctx.echo_marks_archive` + `ctx.flags_to_set` | story-002 | AC-SL-12 | `cross_chapter_continuity_test.gd::test_ac_sl12_populator_*` (×2) | COVERED |
| TR-save-load-013 | `scenario_path_key` `"::"`-delimited per F-SP-4 | story-002 | AC-SL-14 | DEFERRED | DEFERRED to schema_v2 (no `scenario_path_key` field on SaveContext yet — story §AC-SL-14 explicit MVP-skip) |
| TR-save-load-014 | `save_loaded(ctx: SaveContext)` GameBus signal added per ADR-0001 minor amendment | story-002 | (signal contract) | `cross_chapter_continuity_test.gd::test_save_loaded_*` (×3) + signal-list keepers | COVERED |
| TR-save-load-015 | Hydration is idempotent (load twice yields field-identical SaveContext) | story-002 | AC-SL-20 | `cross_chapter_continuity_test.gd::test_ac_sl20_*` (×2) + handler idempotency test | COVERED |
| TR-save-load-016 | All save/load failure paths emit `save_load_failed(op, reason)` | story-003 | AC-SL-15/16 | `failure_surfacing_test.gd::test_ac_sl15_*` + `test_ac_sl16_*` | COVERED |
| TR-save-load-017 | SaveManager never crashes on save/load failure | story-003 | AC-SL-15/16/17 | `failure_surfacing_test.gd` (all 7 tests verify no-crash + structured return) | COVERED |
| TR-save-load-018 | CR-SL-11 enforcement lint — every `ResourceLoader.load` uses `CACHE_MODE_IGNORE` | story-003 | AC-LINT-CACHE_MODE_IGNORE | `tools/ci/lint_save_resource_loader_cache_mode_ignore.sh` + smoke test | COVERED |
| TR-save-load-019 | CR-SL-13 enforcement lint — migration Callables are pure | story-003 | AC-LINT-MIGRATION_PURITY | `tools/ci/lint_save_migration_callable_purity.sh` + smoke test | COVERED |
| TR-save-load-020 | CR-SL-2 enforcement lint — every SaveContext + EchoMark field has `@export` | story-003 | AC-LINT-EXPORT_DISCIPLINE | `tools/ci/lint_save_context_export_discipline.sh` + smoke test | COVERED |

**12 of 13 TRs COVERED. 1 of 13 DEFERRED** (TR-save-load-013 → schema_v2 future per story-002 spec; SaveContext field not yet present).

---

## AC Coverage Table

20 ACs (AC-SL-1..20) from `design/gdd/save-load.md` §8:

| AC | Story | Test / Evidence | Status |
|----|-------|-----------------|--------|
| AC-SL-1 (CP-1 emission) | story-001 | `save_checkpoint_emission_test.gd::test_cp_1_*` | COVERED |
| AC-SL-2 (CP-2 emission, 3 outcomes) | story-001 | `test_cp_2_emits_*_outcome_*` (×3 WIN/LOSS/DRAW) | COVERED |
| AC-SL-3 (CP-3 emission) | story-001 | `test_cp_3_emits_at_beat_9_*` | COVERED |
| AC-SL-4 (4 distinct files per cycle) | story-001 | `test_two_chapter_cycle_writes_four_distinct_save_files` | COVERED |
| AC-SL-5 (Resource serialization round-trip) | save-manager | `save_manager_test.gd` round-trip suite | COVERED (Platform substrate) |
| AC-SL-6 (atomic write tmp + rename) | save-manager | `save_manager_test.gd` atomic-write tests | COVERED (Platform substrate) |
| AC-SL-7 (3-slot independence) | save-manager | `save_manager_test.gd` slot-independence suite | COVERED (Platform substrate) |
| AC-SL-8 (slot enumeration list_slots) | save-manager | `save_manager_test.gd::test_list_slots_*` | COVERED (Platform substrate) |
| AC-SL-9 (newest-CP resolution) | save-manager | `save_manager_test.gd::_find_latest_cp_file` tests | COVERED (Platform substrate) |
| AC-SL-10 (schema migration chain) | save-manager | `save_migration_registry_test.gd` chain tests | COVERED (Platform substrate) |
| AC-SL-11 (CACHE_MODE_IGNORE on every load) | story-003 | Lint #6 + `lint_save_resource_loader_cache_mode_ignore.sh` | COVERED (lint enforcement) |
| AC-SL-12 (Destiny State populator) | story-002 | `cross_chapter_continuity_test.gd::test_ac_sl12_*` (×2) | COVERED |
| AC-SL-13 (round-trip preserves bitwise) | story-002 | `cross_chapter_continuity_test.gd::test_ac_sl13_*` (×2) | COVERED |
| AC-SL-14 (`scenario_path_key` `"::"` round-trip) | story-002 | DEFERRED | DEFERRED to schema_v2 |
| AC-SL-15 (disk-full failure surfacing) | story-003 | `failure_surfacing_test.gd::test_ac_sl15_*` (×2) | COVERED |
| AC-SL-16 (truncated/invalid file) | story-003 | `failure_surfacing_test.gd::test_ac_sl16_*` (×2) | COVERED |
| AC-SL-17 (mid-write crash → orphan .tmp skipped) | story-003 | `failure_surfacing_test.gd::test_ac_sl17_*` (×2) | COVERED |
| AC-SL-18 (determinism — same inputs yield same SaveContext) | save-manager | `save_manager_test.gd` determinism tests | COVERED (Platform substrate) |
| AC-SL-19 (round-trip equality outside Object identity) | save-manager + story-002 | `save_manager_test.gd` round-trip + `cross_chapter_continuity_test.gd::test_ac_sl13_*` | COVERED |
| AC-SL-20 (idempotent hydration — load twice) | story-002 | `cross_chapter_continuity_test.gd::test_ac_sl20_*` (×2) + handler idempotency | COVERED |

**19 of 20 ACs COVERED. 1 of 20 DEFERRED** (AC-SL-14 → schema_v2 per story-002 spec).

---

## ADVISORY Deferrals Inventory

Items explicitly deferred by story scope or future schema work:

1. **AC-SL-14 / TR-save-load-013** (`scenario_path_key` `"::"`-delimiter round-trip test) — DEFERRED to schema_v2; `SaveContext` has no `scenario_path_key` field yet. Story-002 §AC-SL-14 explicit MVP-skip per scenario-progression epic SCENARIO_END epilogue not reached in 3-chapter MVP scope. Resolution path: future Save/Load schema_v2 cut adds the field + a v1→v2 migration in `_migrations`.

2. **TR-save-load-012..015 not registered in `tr-registry.yaml`** (Gap 2 carryover) — story-001 + story-002 both flagged this as ADVISORY. Resolution path: `/architecture-review` Phase 8 batch register-update.

3. **ADR-0003 + GDD §CR-SL-5 wording divergence on CP-3 timing** — story-001 + story-002 Completion Notes document this; current code path (CP-3 at BEAT_9 of completing chapter) is canonical per CR-SL-6 file-accumulation, but ADR-0003 + GDD §CR-SL-5 prose says "CP-3 at next-chapter Beat 1 entry". Resolution path: `/propagate-design-change` OR next `/architecture-review` Phase 8 prose-sync.

4. **OQ-SL-1 mid-battle autosave** — explicitly deferred to post-MVP per save-load.md GDD §OQ-SL-1.

5. **OQ-SL-2 cloud sync** — deferred to post-launch live-ops scope per save-load.md GDD §OQ-SL-2.

6. **OQ-SL-4 `echo_marks_archive` cap** — Polish-tier deferral; no immediate forcing function. Hard cap exists at runtime per `DESTINY_STATE_ECHO_ARCHIVE_HARD_CAP` BalanceConstants entry (FIFO eviction) but disk-size cap on `echo_marks_archive` field itself is unbounded.

7. **OQ-SL-5 corrupted-file recovery** — fall-back-to-next-newer-CP behavior not implemented; loader currently surfaces error via `save_load_failed` and returns null. Save Slot UI epic (#18 Alpha) decides UX (retry / abandon / restore from backup).

8. **OQ-SL-3 (signal vs method-call dispatch)** — RESOLVED via story-002. Decision: signal-driven (`save_loaded` 4th GameBus signal). Rationale documented in ADR-0001 changelog 2026-05-08 entry.

9. **Save Slot UI metadata extensions** (per OQ-SL-4) — Save Slot UI authoring is Alpha-tier per systems-index #18; out of scope for this Core epic.

10. **Soft-delete vs hard-delete on Save Slot UI wipe** (per OQ-SL-5) — Save Slot UI's wipe button decision; out of scope for this Core epic.

---

## Cross-System Closure Markers

Save-load epic closure satisfies the following downstream / upstream contracts:

- **`scenario-progression.md` F-SP-4** (cross-doc downstream obligation): satisfied via CR-SL-16 `scenario_path_key "::"`-delimiter convention adopted in `SaveContext` schema; `scenario_path_key` field round-trip (AC-SL-14) deferred to schema_v2 since the field is not yet on SaveContext.
- **save-manager Platform substrate** (Complete 2026-04-24): consumed correctly. Story-001 emits via the existing `GameBus.save_checkpoint_requested(ctx)` signal; SaveManager's `_on_save_checkpoint_requested` handler (already shipped) receives the emission. Story-002 emits `GameBus.save_loaded.emit(migrated)` post-`migrate_to_current`. Story-003 lints + tests exercise SaveManager's atomic-write protocol via the V-4 / V-5 / DIRACCESS-FAIL test seams.
- **destiny-state populator pattern** (CR-DS-16 + CR-SL-15): integrated via existing `_on_save_checkpoint_requested` populator in `destiny_state.gd:175-187` (shipped sprint-8 S8-10) + new `_on_save_loaded` rehydrator in `destiny_state.gd:200-216` (shipped sprint-12 story-002).
- **GameBus signal contract** (ADR-0001 §9 Persistence domain): widened to 4 signals (was 3 before story-002 minor amendment). Total signal count: 30 → 31. Domain count unchanged at 11. PROVISIONAL count unchanged at 2.
- **Pillar 2 architectural lock** (Pillar 2 sole-carrier discipline): no Pillar 2 violations introduced by save-load implementation. Save/Load is Persistence-tier; Pillar 2 narrative-substrate signals (`hidden_fate_condition_progressed`) are NOT consumed by save-load code paths.
- **systems-index row 17** (epic-terminal closure): flipped Designed → Implemented at story-003 close 2026-05-08.

---

## Lint Master Inventory (3 NEW save-load lints)

| # | Lint | Source | Coverage | First-precedent kind |
|---|------|--------|----------|----------------------|
| 1 | `lint_save_resource_loader_cache_mode_ignore.sh` | CR-SL-11 + TR-save-load-018 | every `ResourceLoader.load(...)` in save-load source files passes `CACHE_MODE_IGNORE` | Bash + Ruby (lint_save_paths pattern) |
| 2 | `lint_save_migration_callable_purity.sh` | CR-SL-13 + TR-save-load-019 | `_migrations` Dictionary entries are pure (no captured refs) | Bash + Ruby (forward-looking heuristic; first heuristic-pattern lint precedent) |
| 3 | `lint_save_context_export_discipline.sh` | CR-SL-2 + TR-save-load-020 | every `var` in SaveContext + EchoMark is `@export`-annotated | Bash + Ruby (Resource serialization defense) |

CI wiring: `.github/workflows/tests.yml` lines ~158-164 (after battle-hud lint block; before GdUnit4 test runner).

Pre-existing save-load lint (NOT part of this epic; protected separately): `tools/ci/lint_save_paths.sh` (CR-SL-9 / TR-save-load-006 — `user://` save root enforcement; shipped at save-manager epic).

---

## Epic Status

**Complete** (3/3 stories shipped) — date 2026-05-08 — sprint-12 (S12-01..S12-03 follow-on track + story-001..story-003 close-out chain on commits `5357287` → `12a039f` → epic-terminal pending /story-done).

**Engine-graduation impact**:
- `design/gdd/systems-index.md` row 17 Status: **Designed → Implemented** (this story).
- `production/epics/save-load/EPIC.md` Status: In Progress → **Complete (epic-terminal)** (pending /story-done Phase 7).
- `production/epics/index.md` save-load row: 2/3 → **3/3 Complete** + Status `**Complete** (2026-05-08) 🎉` (pending /story-done Phase 7).

**Cross-pillar enabling effects**:
- Pillar 4 cross-session narrative continuity is now mechanically observable across game sessions (Destiny State flag + EchoMark archive persistence).
- Main Menu / Save Slot UI epic (#18 Alpha) is unblocked — slot enumeration via `SaveManager.list_slots()` + Continue button visibility logic can now be authored.
- 운명 분기 (Destiny Branch) outcomes from prior chapters carry forward through save/reload cycles — Pillar 2 + Pillar 4 substrate fully wired end-to-end.

---

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
