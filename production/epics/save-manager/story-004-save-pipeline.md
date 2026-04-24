# Story 004: Save pipeline — duplicate_deep → ResourceSaver → atomic rename

> **Epic**: save-manager
> **Status**: Complete
> **Layer**: Platform
> **Type**: Logic
> **Estimate**: 4-5 hours (pipeline body + 4 failure paths + round-trip test; most mechanically rich story in the epic)
> **Manifest Version**: 2026-04-20

## Context

**GDD**: — (infrastructure; authoritative spec is ADR-0003 §Decision + §Atomicity Guarantees)
**Requirement**: `TR-save-load-003`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 — §Key Interfaces (SaveManager.save_checkpoint) + §Atomicity Guarantees + §Schema Stability
**ADR Decision Summary**: "All saves take a `duplicate_deep(DUPLICATE_DEEP_ALL_BUT_SCRIPTS)` snapshot before ResourceSaver. Write pipeline is `ResourceSaver.save(tmp_path)` → `DirAccess.rename_absolute(tmp, final)` — atomic on `user://` only. Failures emit `save_load_failed(op, reason)`; never crash."

**Engine**: Godot 4.6 | **Risk**: MEDIUM
**Engine Notes**: `Resource.duplicate_deep(DUPLICATE_DEEP_ALL_BUT_SCRIPTS)` is 4.5+ — verify against `docs/engine-reference/godot/modules/core.md`. `DirAccess.rename_absolute()` atomicity holds only on `user://` (POSIX rename(2)); SAF external paths NOT guaranteed (R-2). `ResourceSaver.FLAG_COMPRESS` is pre-cutoff stable but OFF by default pending payload-size benchmark (deferred-decision per control-manifest).

**Control Manifest Rules (Platform layer)**:
- Required: Save write pipeline: `duplicate_deep(DUPLICATE_DEEP_ALL_BUT_SCRIPTS)` → `ResourceSaver.save(tmp_path)` → `DirAccess.rename_absolute(tmp_path, final_path)` (TR-save-load-003)
- Required: Save root is `user://saves` ONLY (TR-save-load-006)
- Required: Failures never crash; emit `save_load_failed(op, reason)` on GameBus
- Forbidden: SAF / external-storage paths
- Forbidden: per-frame emits (ADR-0001 §7)

## Acceptance Criteria

*Derived from ADR-0003 §Key Interfaces + §Validation Criteria V-1, V-4, V-5, V-7:*

- [ ] `save_checkpoint(source: SaveContext) -> bool` implements pipeline exactly per ADR-0003 §Key Interfaces:
  1. `snapshot = source.duplicate_deep(Resource.DUPLICATE_DEEP_ALL_BUT_SCRIPTS) as SaveContext`
  2. Set `snapshot.schema_version = CURRENT_SCHEMA_VERSION`
  3. Set `snapshot.saved_at_unix = int(Time.get_unix_time_from_system())`
  4. Compute `final_path = _path_for(_active_slot, snapshot.chapter_number, snapshot.last_cp)`
  5. Compute `tmp_path = final_path + ".tmp"`
  6. `ResourceSaver.save(snapshot, tmp_path)` — on error, emit `save_load_failed("save", "resource_saver_error:%d" % err)`; return false
  7. `DirAccess.open(SAVE_ROOT)` — on null, emit `save_load_failed("save", "dir_access_open_failed")`; return false
  8. `da.rename_absolute(tmp_path, final_path)` — on error, emit `save_load_failed("save", "atomic_rename_failed:%d" % err)`; return false
  9. On success: emit `GameBus.save_persisted.emit(snapshot.chapter_number, snapshot.last_cp)`; return true
- [ ] `_on_save_checkpoint_requested(source: SaveContext)` handler body: calls `save_checkpoint(source)` and ignores return value (signal-driven; result is observable via `save_persisted` or `save_load_failed`)
- [ ] Source SaveContext is NEVER mutated during save (verified by post-save field equality check on caller's instance)
- [ ] V-1: round-trip test — fill all 12 SaveContext fields with distinct values, save, load (via test helper that reads `.res` directly), assert deep-equal
- [ ] V-4: tmp file never survives a failed save — inject mid-save failure (mock ResourceSaver.save error) → tmp file cleaned up OR documented as "tmp file may linger on save failure; compensating cleanup is story-006 concern"; story authoritatively clarifies outcome
- [ ] V-5: crash during save leaves old file intact — save v1, trigger fake failure on v2 save → `DirAccess.file_exists_absolute(final_path)` returns true AND loading returns v1 content (atomic-rename contract)
- [ ] V-7: CACHE_MODE_IGNORE pre-requirement — this story does NOT implement load, but V-7 verification (overwrite file in same session, reload returns new content) is authored as a test stub here and completed in story-005
- [ ] Full save cycle stays under 50 ms on dev laptop (desktop substitute; target-device 50 ms validation in story-007)

## Implementation Notes

*From ADR-0003 §Key Interfaces + §Atomicity Guarantees + R-1 mitigation:*

1. **duplicate_deep is BLOCKING** — R-1 mitigation. Without `duplicate_deep`, gameplay code mutating `source` after `save_checkpoint` returns produces torn writes on the serialized file. `DUPLICATE_DEEP_ALL_BUT_SCRIPTS` is the correct flavor — scripts don't need re-duplication (shared class_name registry).

2. **schema_version stamped INSIDE save_checkpoint** — never trust source's schema_version; always stamp `CURRENT_SCHEMA_VERSION` at save time. Old saves in-memory may carry stale schema_version.

3. **saved_at_unix stamped INSIDE save_checkpoint** — auto-populated; caller does not set.

4. **Error code cascade** — 3 distinct failure modes each emit `save_load_failed` with distinguishable `reason` string:
   - `resource_saver_error:%d` — serialization failure (disk full, permission)
   - `dir_access_open_failed` — `DirAccess.open(SAVE_ROOT)` returned null (directory deleted externally)
   - `atomic_rename_failed:%d` — rename failed after tmp write succeeded (unusual; often permission)

5. **No FLAG_COMPRESS at MVP** — deferred-decision per control-manifest + ADR-0003 Open Questions #1. Default OFF until first realistic payload benchmark shows >50 KB uncompressed. Story-007 perf pass may revisit.

6. **Test infra** — this story's tests require SaveManagerStub from story-003 for temp-dir isolation. Do not pollute real `user://saves/`.

7. **Failure injection for V-4/V-5** — options:
   - **A**: Set `ResourceSaver`'s write target to a read-only path (trigger err). Harder in GDScript without mocking.
   - **B**: Inject a pre-write tmp file at the target location with `DirAccess` marked read-only. On rename, err != OK.
   - **C**: Use a test seam — stub method `_do_resource_saver_save(snapshot, tmp_path) -> Error` virtualized; override in test to return `FAILED`.
   - Option C recommended for clean test boundaries.

8. **Performance gate** — story-007 is the authoritative perf validation against target device (Snapdragon 7-gen). This story ensures desktop substitute baseline is <50 ms; flag if desktop exceeds 10 ms (would indicate worse-than-expected overhead for target).

9. **G-10 applies** — tests that use GameBus emit of `save_checkpoint_requested` must NOT combine `GameBusStub.swap_in` + `SaveManagerStub.swap_in` for handler-firing tests. Emit on REAL `/root/GameBus` and test handler on REAL `/root/SaveManager` (use SaveManagerStub for temp-root isolation only).

## Out of Scope

- SaveContext / EchoMark classes — story 001
- Autoload skeleton — story 002
- Test stub — story 003
- Load pipeline + crash-recovery scan + list_slots — story 005
- Migration registry — story 006
- Perf validation on target device — story 007
- CI lint — story 008

## QA Test Cases

*Test file*: `tests/unit/core/save_manager_test.gd` (additive — extends story-002 skeleton tests)

- **AC-V1** (round-trip preserves all SaveContext fields):
  - Given: SaveManagerStub with temp root; SaveContext filled with 12 distinct values (schema_version=7, slot_id=2, chapter_id=&"ch03", chapter_number=5, last_cp=2, outcome=1, branch_key=&"east", echo_count=3, echo_marks_archive=[3 unique EchoMarks], flags_to_set=["a","b"], saved_at_unix=1234567890, play_time_seconds=7200)
  - When: `save_checkpoint(ctx)` then `ResourceLoader.load(final_path, "", CACHE_MODE_IGNORE)`
  - Then: reloaded ctx equals source ctx field-by-field (schema_version overwritten to CURRENT; saved_at_unix overwritten to recent); `echo_marks_archive` elements are real EchoMark instances with matching fields

- **AC-V4** (tmp file never survives on ResourceSaver failure):
  - Given: stub; inject ResourceSaver failure via Option C seam
  - When: `save_checkpoint(ctx)`
  - Then: returns false; `save_load_failed` emitted with reason prefix "resource_saver_error:"; `DirAccess.file_exists_absolute(tmp_path) == false` OR documented as known limitation with compensating cleanup deferred

- **AC-V5** (crash during save leaves old file intact):
  - Given: stub; save v1 successfully (written to final_path); now inject failure on v2 save
  - When: `save_checkpoint(v2_ctx)`
  - Then: returns false; `save_load_failed` emitted; `DirAccess.file_exists_absolute(final_path) == true`; loading `final_path` via `ResourceLoader.load(..., CACHE_MODE_IGNORE)` returns v1 ctx unchanged

- **AC-NO-MUTATE** (source never mutated):
  - Given: source SaveContext with schema_version=99
  - When: `save_checkpoint(source)` returns
  - Then: `source.schema_version == 99` (unchanged); snapshot's schema_version was set to `CURRENT_SCHEMA_VERSION` but source is untouched (duplicate_deep contract)

- **AC-SIGNAL** (save_persisted emission on success):
  - Given: stub; save ctx with chapter_number=4, last_cp=2
  - When: capture GameBus.save_persisted via lambda; call `save_checkpoint(ctx)`
  - Then: signal fired with `(4, 2)` arg tuple
  - Edge: verify `save_checkpoint_requested` subscription flow (GameBus emit → handler → save_persisted emit)

- **AC-ATOMIC** (atomic rename verified):
  - Given: stub; watch filesystem pre/post save
  - When: `save_checkpoint(ctx)`
  - Then: `tmp_path` exists momentarily during save then disappears; `final_path` appears exactly once (rename atomicity — no intermediate partial-write state visible)
  - *Note: watching filesystem transition is tricky; minimally assert that on success, only `final_path` exists and `tmp_path` does not.*

- **AC-SCHEMA-STAMP** (schema_version stamped at save time):
  - Given: source ctx with `schema_version = 99` (stale)
  - When: `save_checkpoint(source)` succeeds; load from final_path
  - Then: loaded ctx has `schema_version == CURRENT_SCHEMA_VERSION` (=1 at MVP)

- **AC-TIME-STAMP** (saved_at_unix stamped at save time):
  - Given: source ctx with `saved_at_unix = 0`
  - When: `save_checkpoint(source)` at Time T; load from final_path
  - Then: loaded ctx has `saved_at_unix` within 2s of T (wall-clock tolerance)

- **AC-DIRACCESS-FAIL** (DirAccess.open failure reason):
  - Given: stub; delete SAVE_ROOT externally before save_checkpoint
  - When: `save_checkpoint(ctx)`
  - Then: returns false; `save_load_failed` emitted with `reason == "dir_access_open_failed"`

## Test Evidence

**Story Type**: Logic
**Required evidence**: `tests/unit/core/save_manager_test.gd` — V-1/V-4/V-5 + 6 AC tests pass (BLOCKING gate)
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: story-001 (SaveContext), story-002 (autoload skeleton), story-003 (stub for temp-root isolation)
- **Unlocks**: Stories 005 (load pipeline needs save to produce files first), 006 (migration tests use full save pipeline), 007 (perf validation), 008 (CI lint has a pipeline to lint)

## Completion Notes

**Completed**: 2026-04-23
**Verdict**: COMPLETE WITH NOTES
**Criteria**: 9/9 passing (AC-V7 stubbed — completes in story-005)
**Test Evidence**: Logic — `tests/unit/core/save_manager_test.gd` (1121 LoC, 27 tests); **127/127 PASSED**, 0 errors, 0 failures, 0 orphans, exit 0, full unit suite 1.1s
**Code Review**: Complete — godot-gdscript-specialist APPROVED, qa-tester ADEQUATE. Option A fix applied in-cycle (AC-PERF StringName style: `&"tag_%d" % i` → `StringName("tag_%d" % i)`). Re-run still 127/127 PASS.
**Deviations**:
- 4 ADR-0003 text errata documented in-situ + logged as TD-024 (`DEEP_DUPLICATE_ALL` enum), TD-025 (`FileAccess.file_exists` + `.rstrip("/")` path normalization), TD-026 (`.tmp.res` extension pattern). TD-023 `class_name SaveManager` errata pre-existing. Batch ADR errata pass planned at epic close.
- 6 advisory items deferred to TD-027 (batch): AC-NO-MUTATE field coverage (saved_at_unix), V-4 cleanup branch dead under seam, SaveContext factory helper, `_cleanup_tmp` DRY refactor, G-12..G-15 rule-file pending, null source guard. Natural fits for story-006 test sweep.
- Scope: `docs/tech-debt-register.md` append (3 new TDs — TD-024/025/026 + batch TD-027). Justified: canonical TD tracking location.

**Files delivered**:
- `src/core/save_manager.gd` (159 → 302 LoC) — `save_checkpoint` 9-step pipeline + 3 test seams (`_do_resource_saver_save`, `_do_rename_absolute`, `_do_dir_access_open`) + 3 test-only flags + V-4 best-effort cleanup with `push_warning` guard + `.rstrip("/")` path normalization + `_on_save_checkpoint_requested` delegation. Four inline ADR-errata comments reference TD-024/025/026.
- `tests/unit/core/save_manager_test.gd` (524 → 1121 LoC) — +11 new story-004 tests + `_save_and_load` helper; -1 retired stub-contract test (`test_save_manager_save_checkpoint_stub_returns_false`).
- `docs/tech-debt-register.md` — TD-024/025/026 + TD-027 appended.

**Implementation rounds**: 6 progressive debug rounds (drafts → 3 approvals + 1 seam correction → parse error file_exists_absolute → parse error DUPLICATE_DEEP_ALL_BUT_SCRIPTS → 7 failures double-slash → 7 failures tmp extension → GREEN). Most iterative story to date; 4 engine-API gotchas discovered.

**Implementation effort**: ~5h actual (est 4-5h; +1h for ADR errata discovery rounds).

**Next recommended**: commit + branch + PR for story-004 (R1 pattern), then `/story-readiness production/epics/save-manager/story-005-load-pipeline.md`.
