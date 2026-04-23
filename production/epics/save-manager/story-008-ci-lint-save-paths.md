# Story 008: CI lint — user://-only + no-per-frame-emit + BattleOutcome append-only

> **Epic**: save-manager
> **Status**: Ready
> **Layer**: Platform
> **Type**: Config/Data
> **Estimate**: 2-3 hours (Ruby lint script + README + smoke evidence + workflow integration; follows gamebus story-008 template exactly)
> **Manifest Version**: 2026-04-20

## Context

**GDD**: — (infrastructure; lint gate for ADR-0003 §Atomicity Guarantees + §Schema Stability + ADR-0001 §7)
**Requirement**: `TR-save-load-005` + `TR-save-load-006`
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0003 — §Atomicity Guarantees (SAVE_ROOT must remain `user://`) + §Schema Stability (BattleOutcome.Result append-only) + §Validation Criteria V-10, V-13 + ADR-0001 §7 (no per-frame emits)
**ADR Decision Summary**: "Static grep lint rejects: (a) any occurrence of `/sdcard`, `content://`, or SAF APIs in save_manager.gd (V-10); (b) any `GameBus.*.emit()` inside `_process` / `_physics_process` body of save_manager.gd (V-13); (c) any non-append-only mutation of `BattleOutcome.Result` enum (TR-save-load-005) — detected by comparing enum declaration against a committed snapshot."

**Engine**: Godot 4.6 | **Risk**: LOW (bash + Ruby static analysis; no engine APIs touched)
**Engine Notes**: Follows gamebus story-008 Ruby-based indentation-aware parser pattern. `tools/ci/lint_per_frame_emit.sh` already scans all of `src/**/*.gd`; this story extends same template to 2 new checks (save-root validation + enum append-only snapshot). CI fail-fast ordering: lint BEFORE GdUnit4 runner (saves ~90s on violation PRs).

**Control Manifest Rules (Platform layer)**:
- Required: Save root is `user://saves` ONLY (TR-save-load-006)
- Required: `BattleOutcome.Result` enum is append-only (TR-save-load-005)
- Forbidden: SAF / external-storage paths in save code
- Forbidden: per-frame emits from save_manager.gd (ADR-0001 §7)

## Acceptance Criteria

*Derived from ADR-0003 §Validation Criteria V-10, V-13 + TR-save-load-005/006:*

- [ ] `tools/ci/lint_save_paths.sh` exists: Ruby-based scanner for forbidden path patterns in `src/core/save_manager.gd` + `src/core/save_context.gd` + `src/core/save_migration_registry.gd`
- [ ] Lint rejects any occurrence of:
  - `"/sdcard"` (hardcoded Android SAF root)
  - `"content://"` (Android Storage Access Framework URI)
  - `FileAccess.open_with_password` (out-of-scope; save is not password-protected)
  - Any string literal starting with `/` that is NOT `user://` (rejects absolute filesystem paths)
  - `OS.get_user_data_dir()` + string concat (should use `user://` prefix directly)
- [ ] `tools/ci/lint_enum_append_only.sh` exists: snapshot-based checker for `BattleOutcome.Result`
  - Committed snapshot file: `tools/ci/snapshots/battle_outcome_enum.txt` containing the current enum declaration
  - Script greps `src/core/payloads/battle_outcome.gd` for `enum Result` block, extracts declarations, compares line-by-line against snapshot
  - If snapshot has `WIN = 0, DRAW = 1, LOSS = 2` and source has `WIN = 0, DRAW = 1, LOSS = 2, SURRENDER = 3` (append) → lint PASSES (append-only)
  - If source has `DRAW = 0, WIN = 1, LOSS = 2` (reorder) → lint FAILS with message citing TR-save-load-005 + migration requirement
  - If source removes a value → lint FAILS
- [ ] Extend existing `tools/ci/lint_per_frame_emit.sh` scope to include `src/core/save_manager.gd` (already covers `src/**/*.gd` per gamebus story-008 — verify via test that save_manager.gd is scanned)
- [ ] `.github/workflows/tests.yml` runs both new lint scripts BEFORE GdUnit4 runner (fail-fast ordering)
- [ ] `production/qa/smoke-save-v10-v13-lint.md` — smoke test evidence doc with 6 tests:
  - Test 1: clean save_manager.gd → lint exit 0
  - Test 2: violator `/sdcard` string literal → lint exit 1 with file:line + TR citation
  - Test 3: violator `content://` string → lint exit 1
  - Test 4: violator `GameBus.save_persisted.emit()` inside `_process` → lint exit 1 (per-frame-emit covers this; smoke confirms coverage)
  - Test 5: clean enum snapshot match → lint exit 0
  - Test 6: reordered enum → lint exit 1 with TR-save-load-005 citation
- [ ] Smoke tests captured with actual timing (each lint <2s target; regression: 100+ tests still pass, 0 orphans, exit 0)
- [ ] `tools/ci/README.md` updated with new lint entries

## Implementation Notes

*From gamebus story-008 template + ADR-0003 §Validation Criteria:*

1. **Follows gamebus/story-008 pattern exactly** — same bash + Ruby structure, same `set -uo pipefail` (without `-e`) + `if ! result=$(ruby -e '...' 2>&1); then exit_code=$?; fi` pattern to distinguish violations (exit 1) from lint-infra crashes (exit 2+). Reuse the error-output template.

2. **Path validation scope** — scanner runs on save-related files only:
   - `src/core/save_manager.gd` (primary)
   - `src/core/save_context.gd` (defensive — no paths expected but cheap to scan)
   - `src/core/save_migration_registry.gd` (migration fns run at load; paths could sneak in)

3. **String literal detection** — use Ruby regex to find double-quoted strings; filter ones starting with `/` that are not `user://`. Handles both `"/sdcard"` and `'/sdcard'` (GDScript accepts both; be thorough).

4. **Enum snapshot is committed file** — `tools/ci/snapshots/battle_outcome_enum.txt` IS the source of truth for "what was approved". On schema change:
   1. Developer authors migration Callable in SaveMigrationRegistry (story-006 pattern)
   2. Updates snapshot file in same PR
   3. Bumps `CURRENT_SCHEMA_VERSION` in SaveManager
   4. Lint passes again because snapshot is now current
   This forces the migration-Callable + schema-version-bump discipline.

5. **Per-frame emit lint extension** — already-shipped `tools/ci/lint_per_frame_emit.sh` covers all `src/**/*.gd` per gamebus story-008. Verify via smoke test (deliberate violator in save_manager.gd → lint fails). No script changes needed; just verification.

6. **BattleOutcome.Result location** — as of scene-manager epic close, `BattleOutcome` is at `src/core/payloads/battle_outcome.gd`. Verify path hasn't drifted; adjust lint script if needed.

7. **Ruby-based indentation-aware parser** — same as gamebus story-008. Tab-only indent assumption documented in README. For path validation (simpler than per-frame-emit), plain regex grep sufficient — Ruby used for consistency with existing lint-pipeline pattern.

8. **Error message template** (match gamebus story-008 format):
   ```
   src/core/save_manager.gd:47: ResourceSaver.save(snapshot, "/sdcard/foo.res")
   ADR-0003 §Atomicity Guarantees + TR-save-load-006: save root MUST be user:// only.
   SAF external storage does NOT guarantee atomic rename.
   Fix: use user://saves/... path or parameterize via _path_for().
   ```

9. **Regression test** — after lint scripts land, full test suite must still pass (100+ tests in unit + integration, 0 orphans, exit 0). Smoke Test 6 of evidence doc records this.

## Out of Scope

- SaveContext / EchoMark classes — story 001
- Autoload skeleton — story 002
- Test stub — story 003
- Save pipeline — story 004
- Load pipeline — story 005
- Migration registry — story 006
- Perf validation — story 007

## QA Test Cases

*Test evidence*: `production/qa/smoke-save-v10-v13-lint.md` (Config/Data story — smoke check instead of automated test)

- **Test 1** (clean src/ exits 0):
  - Given: `src/core/save_manager.gd` uses only `user://saves` paths
  - When: `bash tools/ci/lint_save_paths.sh`
  - Then: exit 0, stdout contains "OK"

- **Test 2** (violator `/sdcard`):
  - Given: temporary deliberate violator `var bad = "/sdcard/save.res"` added to save_manager.gd
  - When: lint runs
  - Then: exit 1, stderr contains `file:line: "/sdcard/save.res"` + ADR-0003 §Atomicity Guarantees citation
  - Cleanup: revert violator

- **Test 3** (violator `content://`):
  - Given: temporary `ResourceLoader.load("content://com.example/doc.res")` in save_manager.gd
  - When: lint runs
  - Then: exit 1, file:line + TR-save-load-006 citation

- **Test 4** (per-frame emit violator — verify extension):
  - Given: temporary `GameBus.save_persisted.emit(1, 1)` inside `_process(delta)` in save_manager.gd
  - When: `bash tools/ci/lint_per_frame_emit.sh`
  - Then: exit 1, file:line + ADR-0001 §7 citation

- **Test 5** (clean enum snapshot match):
  - Given: `battle_outcome.gd` enum matches committed snapshot
  - When: `bash tools/ci/lint_enum_append_only.sh`
  - Then: exit 0

- **Test 6** (enum reorder rejection):
  - Given: temporary reorder `WIN = 0, DRAW = 1, LOSS = 2` → `DRAW = 0, WIN = 1, LOSS = 2`
  - When: lint runs
  - Then: exit 1, stderr contains TR-save-load-005 + §Schema Stability §BattleOutcome Enum Stability citation
  - Cleanup: revert reorder

- **Test 7** (enum append permitted):
  - Given: temporary append `SURRENDER = 3` after existing enum values + updated snapshot
  - When: lint runs
  - Then: exit 0 (append is allowed when snapshot also updated in same PR)

- **Test 8** (timing):
  - Given: full lint script suite
  - When: measure wall-clock
  - Then: each script <2s

- **Test 9** (regression):
  - Given: all lint scripts green on main
  - When: `godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests/unit -a res://tests/integration -c`
  - Then: 100+ tests pass, 0 orphans, exit 0

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: `production/qa/smoke-save-v10-v13-lint.md` — smoke check with 9 tests (ADVISORY per coding-standards.md Test Evidence table — Config/Data stories require smoke check pass, not unit tests)
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: story-002 (save_manager.gd exists to be linted)
- **Unlocks**: save-manager epic closure (8/8 Complete) — V-10 + V-13 + TR-save-load-005 validation in place as CI gates
