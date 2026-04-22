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

## Future Pattern

New CI lints (e.g., V-9 pure-relay lint, V-10 SAF path lint) will follow the same pattern:
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
