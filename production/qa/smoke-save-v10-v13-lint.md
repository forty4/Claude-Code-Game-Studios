# Smoke Evidence — save-manager story-008 CI lints (V-10 + V-13 + TR-save-load-005)

> **Story**: `production/epics/save-manager/story-008-ci-lint-save-paths.md`
> **Type**: Config/Data (smoke-check evidence model)
> **Executed**: 2026-04-24 on macOS 25.3.0 (Darwin, arm64)
> **Godot**: 4.6.2.stable.official
> **Ruby**: system default (macOS preinstalled; GitHub ubuntu-latest runners ship Ruby)

## Summary

All 9 smoke tests pass. Each lint completes <0.1s (well under the <2s target). Clean recheck after each violator injection confirms no source files were left modified. Full unit suite regression (story-006 baseline: 143/143 PASS) captured below.

## Test Results

### T1 — `lint_save_paths.sh` clean source exits 0

```
$ bash tools/ci/lint_save_paths.sh
ADR-0003 §Atomicity + TR-save-load-006 lint: OK — save paths clean.
EXIT=0
```

PASS.

### T2 — `/sdcard` literal exits 1 with file:line + citation

Injected `var bad: String = "/sdcard/save.res"` at line 1 of `save_manager.gd`.

```
$ bash tools/ci/lint_save_paths.sh
ADR-0003 §Atomicity Guarantees + TR-save-load-006 violation: forbidden save path pattern.
Save root MUST be user:// only. External storage does NOT guarantee atomic rename.

src/core/save_manager.gd:1: var bad: String = "/sdcard/save.res"
  reason: SAF external storage path "/sdcard/save.res" (Android /sdcard root)

Fix: use a user://saves/... path, or parameterize through _path_for().
EXIT=1
```

PASS. file:line reported, `/sdcard` reason-tag specific, TR-save-load-006 cited in header, fix hint present.

### T3 — `content://` literal exits 1 with citation

Injected `var bad: String = "content://com.example/doc.res"` at line 1.

```
$ bash tools/ci/lint_save_paths.sh
ADR-0003 §Atomicity Guarantees + TR-save-load-006 violation: forbidden save path pattern.
Save root MUST be user:// only. External storage does NOT guarantee atomic rename.

src/core/save_manager.gd:1: var bad: String = "content://com.example/doc.res"
  reason: SAF URI "content://com.example/doc.res" (Storage Access Framework)

Fix: use a user://saves/... path, or parameterize through _path_for().
EXIT=1
```

PASS.

### T4 — per-frame-emit coverage verification (save_manager.gd scanned)

Confirms `lint_per_frame_emit.sh` already extends to `save_manager.gd` (no script change needed — the existing `src/**/*.gd` glob covers it).

Injected `func _process(_delta: float): GameBus.save_persisted.emit(1, 1)` before `_on_save_checkpoint_requested`.

```
$ bash tools/ci/lint_per_frame_emit.sh
ADR-0001 §Implementation Guidelines §7 violation: per-frame GameBus emit forbidden.
The following lines emit GameBus signals inside _process or _physics_process:
src/core/save_manager.gd:362: GameBus.save_persisted.emit(1, 1)

Fix: move the emit to an event-driven handler (signal, input, timer).
Or if the emit must fire periodically, use a Timer node with timeout signal.
EXIT=1
```

PASS. Coverage confirmed — V-13 lint applies to save_manager.gd without requiring a scope extension.

### T5 — `lint_enum_append_only.sh` clean snapshot match exits 0

Source: `enum Result { WIN, DRAW, LOSS }` — matches `tools/ci/snapshots/battle_outcome_enum.txt` (`WIN\nDRAW\nLOSS\n`).

```
$ bash tools/ci/lint_enum_append_only.sh
ADR-0003 §Schema Stability + TR-save-load-005 lint: OK: enum matches snapshot exactly.
EXIT=0
```

PASS.

### T6 — enum reorder exits 1 with TR-save-load-005 citation

Modified source to `enum Result { DRAW, WIN, LOSS }` (swap WIN and DRAW).

```
$ bash tools/ci/lint_enum_append_only.sh
ADR-0003 §Schema Stability §BattleOutcome Enum Stability + TR-save-load-005 violation:
BattleOutcome.Result enum diverges from committed snapshot (append-only contract broken).

POSITION[0]: expected "WIN" (from snapshot); found "DRAW" (in source).
POSITION[1]: expected "DRAW" (from snapshot); found "WIN" (in source).

Fix: (a) do NOT reorder or remove enum values — saved payloads carry integer indices;
     (b) if adding a new value, APPEND it AND update tools/ci/snapshots/battle_outcome_enum.txt
         AND author a migration Callable in SaveMigrationRegistry AND bump CURRENT_SCHEMA_VERSION.
EXIT=1
```

PASS. Per-position diagnostic identifies exactly which slots diverged. Fix suggestion names all 4 required workflow steps.

### T7 — enum append (source only) passes with advisory notice

Modified source to `enum Result { WIN, DRAW, LOSS, SURRENDER }`. Snapshot unchanged.

```
$ bash tools/ci/lint_enum_append_only.sh
ADR-0003 §Schema Stability + TR-save-load-005 lint: APPEND OK: new values appended (snapshot must be updated in same PR): ["SURRENDER"]
EXIT=0
```

PASS. Append advances gracefully; the `APPEND OK` message reminds the developer to update the snapshot in the same PR. Exit 0 because the enum ordering is still valid — the snapshot-update discipline is a PR-review gate, not a lint-gate.

### T8 — `FileAccess.open_with_password` exits 1

Injected `var f = FileAccess.open_with_password("foo", FileAccess.READ, "pw")` at line 1.

```
$ bash tools/ci/lint_save_paths.sh
ADR-0003 §Atomicity Guarantees + TR-save-load-006 violation: forbidden save path pattern.
Save root MUST be user:// only. External storage does NOT guarantee atomic rename.

src/core/save_manager.gd:1: var f = FileAccess.open_with_password("foo", FileAccess.READ, "pw")
  reason: FileAccess.open_with_password (password-protected saves out of scope)

Fix: use a user://saves/... path, or parameterize through _path_for().
EXIT=1
```

PASS. Out-of-scope password API correctly flagged.

### T9 — `OS.get_user_data_dir()` + absolute-path concat exits 1 (double violation)

Injected `var p = OS.get_user_data_dir() + "/saves"` at line 1.

```
$ bash tools/ci/lint_save_paths.sh
ADR-0003 §Atomicity Guarantees + TR-save-load-006 violation: forbidden save path pattern.
Save root MUST be user:// only. External storage does NOT guarantee atomic rename.

src/core/save_manager.gd:1: var p = OS.get_user_data_dir() + "/saves"
  reason: absolute filesystem path "/saves" (must use user:// prefix)

src/core/save_manager.gd:1: var p = OS.get_user_data_dir() + "/saves"
  reason: OS.get_user_data_dir() bypass (use user:// prefix directly)

Fix: use a user://saves/... path, or parameterize through _path_for().
EXIT=1
```

PASS. Both violations reported (the `/saves` literal AND the `OS.get_user_data_dir` bypass). Two reasons surfaced for the same line — helpful: developer sees exactly what needs to change.

## Timing

Each lint finishes well under the <2s target:

```
bash tools/ci/lint_save_paths.sh > /dev/null       0.082s total
bash tools/ci/lint_enum_append_only.sh > /dev/null 0.071s total
bash tools/ci/lint_per_frame_emit.sh > /dev/null   0.074s total
```

Total CI overhead added: ~0.15s (two new lints). Negligible compared to the ~60-90s GdUnit4 suite; fail-fast ordering saves full runner cost on violation PRs.

## Regression — Full Unit Suite

After all lint scripts land + workflow integration:

```
$ godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --ignoreHeadlessMode -a res://tests/unit -c
```

**Overall Summary: 143 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED**
**Exit code: 0**

Same baseline as story-006 close (no .gd files touched by story-008).

## Source Files Verified Clean After All Tests

```
$ diff src/core/save_manager.gd /tmp/sm.bak && echo "sm CLEAN"
sm CLEAN
$ diff src/core/payloads/battle_outcome.gd /tmp/bo.bak && echo "bo CLEAN"
bo CLEAN
```

No residual test-violator state left in the tree.

## Acceptance Criteria Coverage

| AC | Requirement | Evidence |
|----|-------------|----------|
| AC-1 | `tools/ci/lint_save_paths.sh` exists, Ruby-based scanner | File created, tests T1/T2/T3/T8/T9 |
| AC-2 | Lint rejects `/sdcard`, `content://`, `FileAccess.open_with_password`, `/*` literals, `OS.get_user_data_dir()` | T2/T3/T8/T9 each verified |
| AC-3 | `tools/ci/lint_enum_append_only.sh` + snapshot file at `tools/ci/snapshots/battle_outcome_enum.txt` | Files created, tests T5/T6/T7 |
| AC-4 | `lint_per_frame_emit.sh` covers `save_manager.gd` | T4 verified (existing `src/**/*.gd` glob is sufficient) |
| AC-5 | `.github/workflows/tests.yml` runs both new lints BEFORE GdUnit4 | Workflow updated; 2 new steps between existing per-frame-emit step and GdUnit4 runner |
| AC-6 | This smoke doc with 6+ tests | 9 tests executed with captured outputs |
| AC-7 | `tools/ci/README.md` updated with new lint entries | 2 new sections added (`lint_save_paths.sh`, `lint_enum_append_only.sh`) |

## Notes

- **Latent-bug fix**: during authoring, a latent bash bug was identified in the `lint_per_frame_emit.sh` template where `if ! ruby_stdout=$(...); then ruby_exit=$?; fi` does NOT correctly preserve Ruby's exit code (the `!` negation makes `$?` always 0 inside the then-branch). The new scripts use direct capture (`ruby_stdout=$(...); ruby_exit=$?`) which works correctly. The existing `lint_per_frame_emit.sh` is functionally unaffected (its violation detection relies on stdout being non-empty, not on the exit code triage branch) but the crash-triage branch is effectively dead code. Logged as TD entry in this session for a future refactor.

- **Godot 4.6 Ruby availability**: Ruby is preinstalled on both macOS (system Ruby) and GitHub `ubuntu-latest` runners; no workflow dependency installation step required.

- **Tab-only indentation convention**: the per-frame-emit parser assumes tab-based indent (documented in `tools/ci/README.md`). The new save-paths lint does NOT depend on indentation; the enum-append-only lint uses a full-block regex, also indent-agnostic.
