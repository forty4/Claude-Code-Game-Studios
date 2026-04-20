# Story 008: CI lint — per-frame emit ban

> **Epic**: gamebus
> **Status**: Ready
> **Layer**: Platform
> **Type**: Config/Data
> **Manifest Version**: 2026-04-20

## Context

**GDD**: — (infrastructure; CI enforcement of ADR-0001 per-frame emit ban)
**Requirement**: `TR-gamebus-001`

**ADR Governing Implementation**: ADR-0001 — §Implementation Guidelines §7 + §Validation Criteria V-7
**ADR Decision Summary**: "Per-frame forbidden check — code search for `GameBus\..*\.emit` inside `_process` or `_physics_process` returns zero matches (CI lint)."

**Engine**: Godot 4.6 | **Risk**: LOW (lint runs as grep/ripgrep in CI shell, not engine-dependent)
**Engine Notes**: None — this is a build-pipeline concern.

**Control Manifest Rules (Platform layer / Global cross-cutting)**:
- Required: Per-frame emits from `_process` / `_physics_process` forbidden; CI lint enforces
- Required: CI runs on every push + PR; no merge on failure; never skip failing tests
- Forbidden: Bypassing CI gate by disabling or commenting out lint step

## Acceptance Criteria

*Derived from ADR-0001 §Implementation Guidelines §7 + §Validation Criteria V-7:*

- [ ] `.github/workflows/tests.yml` — adds a new step `lint-per-frame-emit-ban` that runs before the GdUnit4 test runner
- [ ] Lint step uses `ripgrep` (pre-installed on GitHub ubuntu-latest runners) with multiline mode to detect `GameBus\..*\.emit(...)` calls inside `func _process(...)` or `func _physics_process(...)` bodies in `src/` tree
- [ ] Lint exits non-zero (fail CI) when any match found; exits zero when none
- [ ] Lint excludes `tests/` and `prototypes/` directories from scan (tests may legitimately simulate per-frame emits for stress testing; prototypes are throwaway)
- [ ] Lint report on failure: prints file path + line number + offending line; guides developer to fix
- [ ] Lint script committed at `tools/ci/lint_per_frame_emit.sh` — CI workflow invokes this script (testable locally without GitHub Actions)
- [ ] Script is idempotent, fast (<2 seconds on current src/), and produces zero output on clean code
- [ ] README update: `tools/ci/README.md` (or existing CI docs) documents the lint's purpose + how to run locally

## Implementation Notes

*From ADR-0001 §Implementation Guidelines §7 + coding-standards CI rules:*

1. **Detection strategy** — ripgrep multiline match:
   ```bash
   rg --multiline --multiline-dotall \
      'func\s+_(process|physics_process)\s*\([^)]*\)[^{]*?\{[^}]*?GameBus\.[^.]+\.emit\(' \
      src/
   ```
   Risk: GDScript doesn't use `{...}` for function bodies; it uses indentation. A line-oriented approach is more reliable.

2. **Line-oriented alternative** (recommended):
   ```bash
   #!/usr/bin/env bash
   # tools/ci/lint_per_frame_emit.sh
   set -euo pipefail

   violations=$(ruby -e '
     current_func = nil
     indent_base = nil
     violations = []
     Dir.glob("src/**/*.gd").each do |file|
       File.readlines(file).each_with_index do |line, idx|
         if line =~ /^\s*func\s+(_process|_physics_process)\b/
           current_func = $1
           indent_base = line[/^\s*/].length
         elsif current_func && line =~ /^\s+GameBus\.\w+\.emit\b/
           curr_indent = line[/^\s*/].length
           if curr_indent > indent_base
             violations << "#{file}:#{idx+1}: #{line.strip}"
           end
         elsif line =~ /^\S/ && current_func
           current_func = nil
         end
       end
     end
     puts violations
     exit violations.any? ? 1 : 0
   ')
   echo "$violations"
   ```
   Uses Ruby (pre-installed on GitHub runners) for indentation-aware parsing. Alternative: Python one-liner. Alternative: pure awk.

3. **Cross-platform note** — if the project ever runs CI on Windows, the shell script won't work. For now, target ubuntu-latest (matches `.github/workflows/tests.yml` existing runner).

4. **What counts as `src/`** — glob `src/**/*.gd` per coding-standards. Excludes `tests/`, `prototypes/`, `tools/` — only production code.

5. **False-positive tolerance** — a programmer writes `# GameBus.foo.emit(bar)` as a COMMENT in `_process` body. The lint flags it. Two options:
   - (a) Accept the false positive — force the commented-out line to be rewritten or removed (hygiene win)
   - (b) Strip comments before matching — more complex regex
   - **Recommendation**: (a) — simpler, and a commented-out per-frame emit is a smell worth investigating anyway.

6. **Integration with GitHub Actions** — add to `.github/workflows/tests.yml`:
   ```yaml
   - name: Lint per-frame emit ban (ADR-0001 V-7)
     run: bash tools/ci/lint_per_frame_emit.sh
   ```
   Place BEFORE the GdUnit4 runner step — fail fast on lint violations without wasting test runner time.

7. **Future lint additions** — this story establishes the `tools/ci/` pattern. Subsequent lints (V-9 pure-relay lint, V-10 Save path lint) will follow the same pattern: shell script + CI workflow step. Document pattern in README so future `/dev-story` runs of related lint work have a template.

## Out of Scope

- **V-9 pure-relay lint for `game_bus.gd`** — belongs to Story 002 (already covered there as AC-4). This story only covers V-7.
- **V-10 Save path lint for SAF paths** — belongs to save-manager epic's Story (TR-save-load-006 "no /sdcard, content://, SAF APIs in save_manager.gd"). Same pattern, different scope.
- **Per-frame subscriber lint** — subscribers CAN legitimately do work in `_process` (reading state, not emitting signals). This lint only forbids EMITS, not handlers.

## QA Test Cases

*Inline QA specification.*

**Test file**: `tools/ci/lint_per_frame_emit.test.sh` (optional shell test) + manual CI verification

- **AC-1** (clean src passes):
  - Given: src/ contains no GameBus emit in _process or _physics_process
  - When: `bash tools/ci/lint_per_frame_emit.sh`
  - Then: exit code 0, no output

- **AC-2** (violation detected in _process):
  - Given: temporary `src/_test_violator.gd` contains:
    ```gdscript
    extends Node
    func _process(_delta: float) -> void:
        GameBus.tile_destroyed.emit(Vector2i.ZERO)
    ```
  - When: lint runs
  - Then: exit code 1; output includes `src/_test_violator.gd:3: GameBus.tile_destroyed.emit(Vector2i.ZERO)`
  - Cleanup: remove `_test_violator.gd` after test

- **AC-3** (violation detected in _physics_process):
  - Given: same pattern as AC-2 but in `_physics_process`
  - When: lint runs
  - Then: detected and failed

- **AC-4** (nested function OK):
  - Given: `_ready` calls `_emit_helper()` which calls `GameBus.foo.emit()` — but `_emit_helper` is not `_process`/`_physics_process`
  - When: lint runs
  - Then: exit 0 (legitimate usage)

- **AC-5** (tests/ excluded):
  - Given: `tests/integration/core/cross_scene_emit_test.gd` emits from `_process` for simulation purposes
  - When: lint runs
  - Then: exit 0 (tests/ is excluded from scan)
  - Note: this is why Story 007's test fixtures are allowed to bend the rule

- **AC-6** (CI integration):
  - Given: `.github/workflows/tests.yml` has the lint step
  - When: a PR introduces a violation
  - Then: GitHub Actions fails the check; PR cannot merge

- **AC-7** (local runnable):
  - Given: developer checks out the repo locally
  - When: runs `bash tools/ci/lint_per_frame_emit.sh`
  - Then: same pass/fail behavior as CI; no GitHub-specific dependencies

- **AC-8** (speed):
  - Given: current src/ size
  - When: lint runs
  - Then: completes in <2 seconds (not a blocker for CI parallelism)

## Test Evidence

**Story Type**: Config/Data
**Required evidence**: smoke check pass — `tools/ci/lint_per_frame_emit.sh` invoked in CI with real commits and succeeds/fails correctly; `production/qa/smoke-gamebus-v7-lint.md` documenting the verification
**Status**: [ ] Not yet created

## Dependencies

- **Depends on**: Story 002 (GameBus must exist so that emits reference a real symbol — otherwise lint passes trivially on a project with no GameBus references)
- **Unlocks**: ongoing enforcement of ADR-0001 §7 per-frame ban for the life of the project; reusable pattern for future CI lints (V-9 pure-relay, V-10 Save path, etc.)
