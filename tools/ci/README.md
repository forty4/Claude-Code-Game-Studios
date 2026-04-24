# CI Pipeline Helper Scripts

This directory contains executable scripts that enforce code quality and architectural constraints at CI time. Each script is designed to run locally for immediate feedback and in GitHub Actions for blocking PRs.

## `lint_per_frame_emit.sh`

**Purpose**: Enforces ADR-0001 §Implementation Guidelines §7 — GameBus per-frame emit ban.

**What it does**:
- Scans `src/**/*.gd` for any `GameBus.<signal>.emit(...)` calls inside `func _process(...)` or `func _physics_process(...)` bodies
- Uses indentation-aware parsing (Ruby one-liner) to correctly identify function scope
- Exits with code 0 (pass) if no violations found; code 1 (fail) if violations found
- Excludes `tests/`, `prototypes/`, `tools/` — only scans production code in `src/`

**Why it matters**:
Per-frame emissions violate ADR-0001's design principle that GameBus is an event-driven relay, not a per-frame polling mechanism. Emitting every frame:
- Defeats the soft-cap diagnostic (50 emissions/frame budget)
- Couples game state to frame timing, making the codebase fragile
- Violates the reactive event paradigm

**How to run locally**:
```bash
bash tools/ci/lint_per_frame_emit.sh
echo "Exit code: $?"
```

Expected output on clean code:
```
ADR-0001 §Implementation Guidelines §7 lint: OK — no per-frame GameBus emits in src/.
```

Expected output on violation (file:line and offending line):
```
ADR-0001 §Implementation Guidelines §7 violation: per-frame GameBus emit forbidden.
The following lines emit GameBus signals inside _process or _physics_process:
src/my_system.gd:42: GameBus.tile_destroyed.emit(Vector2i.ZERO)

Fix: move the emit to an event-driven handler (signal, input, timer).
Or if the emit must fire periodically, use a Timer node with timeout signal.
```

**Performance**: Completes in <2 seconds on the current codebase (linear scan, Ruby built-in).

**CI integration**: Added as a step in `.github/workflows/tests.yml` that runs BEFORE the GdUnit4 test runner. Fails fast if violations are found, saving ~90 seconds of runner time.

## `lint_save_paths.sh`

**Purpose**: Enforces ADR-0003 §Atomicity Guarantees + §Validation Criteria V-10 + TR-save-load-006 — save root is `user://` only.

**What it does**:
- Scans `src/core/save_manager.gd`, `src/core/save_context.gd`, `src/core/save_migration_registry.gd` for forbidden path patterns
- Rejects `"/sdcard"` literals (Android external storage), `"content://"` literals (Android Storage Access Framework URIs), `FileAccess.open_with_password` calls (password-protected saves out of scope), any string literal starting with `/` followed by a path component (absolute filesystem path), and `OS.get_user_data_dir()` invocations (bypasses the `user://` VFS prefix)
- Exits with code 0 (pass) if clean; code 1 (fail) if violations found; code 2+ (infra error) if Ruby itself crashes

**Why it matters**:
External storage does NOT guarantee atomic rename. ADR-0003 §Atomicity Guarantees requires the `ResourceSaver.save` → `DirAccess.rename` durability guarantee, which only holds on the per-app sandbox that `user://` targets (app-internal storage on iOS/Android, XDG_DATA_HOME on Linux, APPDATA on Windows). SAF URIs, `/sdcard` paths, and password-protected file access all break that contract.

**How to run locally**:
```bash
bash tools/ci/lint_save_paths.sh
echo "Exit code: $?"
```

Expected output on clean code:
```
ADR-0003 §Atomicity + TR-save-load-006 lint: OK — save paths clean.
```

Expected output on violation (includes file:line + violating literal + fix suggestion).

**Performance**: <0.1s on current save-code size.

**CI integration**: Added as a step in `.github/workflows/tests.yml` between `lint_per_frame_emit.sh` and the GdUnit4 runner.

## `lint_enum_append_only.sh`

**Purpose**: Enforces ADR-0003 §Schema Stability §BattleOutcome Enum Stability + TR-save-load-005 — `BattleOutcome.Result` enum is append-only.

**What it does**:
- Reads the committed snapshot at `tools/ci/snapshots/battle_outcome_enum.txt` (one enum value per line, in declaration order)
- Parses the live `enum Result { ... }` block from `src/core/payloads/battle_outcome.gd` (handles both single-line and multi-line enum declarations; strips `= N` integer assignments)
- Compares element-by-element:
  - `length(source) < length(snapshot)` → FAIL (value removed)
  - any `source[i] != snapshot[i]` for `i < length(snapshot)` → FAIL (reorder or rename)
  - extra entries at `source[length(snapshot)..]` → PASS with `APPEND OK:` notice (snapshot must be updated in the same PR)
- Exits with code 0 (pass or append), 1 (reorder/removal), 2+ (infra error)

**Why it matters**:
`BattleOutcome` is `ResourceSaver`-serialized into save files via the chapter-completed chain. Godot encodes enum values as their underlying integer index. Reordering `{WIN=0, DRAW=1, LOSS=2}` to `{DRAW=0, WIN=1, LOSS=2}` would silently reinterpret every saved `BattleOutcome` — every `WIN` becomes a `DRAW`, every `DRAW` becomes a `WIN`. Removing a value orphans saves that stored that index.

**Schema-change workflow** (when you need to add a new enum value):
1. Author a migration Callable in `SaveMigrationRegistry` (pattern from story-006)
2. Append the new value to `BattleOutcome.Result` (never reorder)
3. Update `tools/ci/snapshots/battle_outcome_enum.txt` to include the new value
4. Bump `CURRENT_SCHEMA_VERSION` in `SaveManager`
5. Lint passes because the snapshot is now current

**How to run locally**:
```bash
bash tools/ci/lint_enum_append_only.sh
echo "Exit code: $?"
```

**Performance**: <0.1s.

**CI integration**: Added as a step in `.github/workflows/tests.yml` between `lint_save_paths.sh` and the GdUnit4 runner.

## Future Pattern

New CI lints will follow the same pattern:
1. Shell script in `tools/ci/` with a clear purpose and ADR reference
2. Indentation-aware parser (Ruby, Python, or awk) tailored to GDScript structure
3. Documentation in this README
4. Step added to `.github/workflows/tests.yml` in fail-fast order
5. Smoke check evidence in `production/qa/`

## Implementation Notes

- Scripts use defensive bash flags (`set -uo pipefail` at minimum) for safe execution. Exit codes are handled explicitly rather than relying on `set -e` to avoid false negatives on tool crashes.
- Ruby is pre-installed on GitHub ubuntu-latest runners
- Scripts are executable (`chmod +x`) and committed to version control
- Error messages guide developers to the root cause and fix strategy
- Parser assumes **tab-based indentation** (project GDScript convention). The indent-depth comparison uses `String#length` on the leading whitespace, which is character count — not column width. A file with mixed tabs and spaces at the function scope would produce incorrect `curr_indent > indent_base` comparisons. Not a concern under the project's tab-only convention, but worth knowing if the convention ever changes.
