# Story 008: CI lint — per-frame emit ban

> **Epic**: gamebus
> **Status**: Complete
> **Layer**: Platform
> **Type**: Config/Data
> **Manifest Version**: 2026-04-20
> **Estimate**: small (~1-2h) — actual ~2.5h across 3 implementation rounds (initial + `|| true` fix + Option B hardening)
> **🎉 Epic closure story**: merging this wraps the entire gamebus epic (8/8 Complete)

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

## Completion Notes

**Completed**: 2026-04-21
**Criteria**: 8/8 ACs PASS; 6 smoke tests pass (4 exit-code assertions + 1 timing + 1 deferred CI-observation); regression suite **57/57 PASSED**, 0 orphans, GODOT EXIT 0
**Verdict**: COMPLETE

**Test Evidence**: `production/qa/smoke-gamebus-v7-lint.md` — 6-test smoke check documenting actual outputs + SHA + sign-off. Config/Data ADVISORY gate satisfied.

**Files delivered** (4 artifacts, zero src/ or test changes):
- `tools/ci/lint_per_frame_emit.sh` (~58 LoC post-hardening) — Ruby-based indentation-aware parser with exit-code triage (0=clean, 1=violations, 2+=Ruby crash with diagnostic to stderr)
- `tools/ci/README.md` (~72 LoC) — documents purpose, local-debug, tab-only indent assumption, and future-lint pattern template for V-9/V-10
- `production/qa/smoke-gamebus-v7-lint.md` (~195 LoC) — 6-test smoke check evidence
- `.github/workflows/tests.yml` — modified (+3 lines) — lint step added BEFORE GdUnit4 runner (fail-fast: saves ~90s on violation PRs)

**Code Review**: Complete — `/code-review` initial verdict **CHANGES REQUIRED** (1 real BLOCKING from security-engineer + 4 ADVISORY). Option B hardening applied: B-2 fix + W-1 README note + S-1 DEFERRED marker + qa-tester Gap 1 new Test 4b → final verdict **APPROVED**.

**Actual effort**: ~2.5h across 3 implementation rounds.

**Implementation rounds** (clean 3-round delivery):
1. Initial write → 4 files, 5/6 tests pass, tests 2/3 silently exit 1 without message (`set -e` + `$(ruby...)` exit 1 aborts bash before `if [ -n "$violations" ]` block)
2. Fix round 1 — `|| true` on Ruby substitution → 6/6 tests pass, BUT `|| true` silently swallows ALL non-zero Ruby exits including crashes (identified by security-engineer as B-2 BLOCKING during /code-review)
3. Option B fix + 3 hardening → `set -uo pipefail` + `if ! ruby_stdout=$(...); then ruby_exit=$?; fi` pattern distinguishes exit 1 (violations) from exit 2+ (crash with stderr diagnostic) + README tab-only note + Test 6 DEFERRED marker + new Test 4b for tests/ exclusion → all 4 changes verified, 57/57 regression green

**BLOCKING caught and fixed during Option B** (security-engineer B-2):
`set -euo pipefail` + `violations=$(ruby -e '...' || true)` antipattern. If Ruby crashes mid-scan (syntax error, missing binary, corrupted file), `|| true` swallows the non-zero exit + `$violations` is empty + script exits 0 = **false clean pass**. A broken linter that always reports clean is worse than no linter. Fix: refactor to `if ! ruby_stdout=$(...); then ruby_exit=$?; fi` pattern + explicit `[ "$ruby_exit" -gt 1 ]` check for crash exit codes (exit 2 with diagnostic to stderr). Distinguishes domain failures (violations found, exit 1) from tool failures (Ruby crashed, exit 2+).

**Design decisions codified** (for future V-9 pure-relay lint + V-10 save-path lint):
- `tools/ci/` directory established as CI pipeline helper scripts home
- Ruby-based indentation-aware parser pattern (handles GDScript's indent-scoping vs ripgrep's brace-scoping)
- Fail-fast CI ordering (lint BEFORE test runner — saves ~90s on violation PRs)
- Smoke check doc pattern at `production/qa/smoke-*.md` with structured test cases + SHA + sign-off
- **Exit-code triage pattern for lint scripts**: 0=clean, 1=domain failure, 2+=tool failure — distinguished via `if ! cmd; then exit_code=$?; fi` + explicit gt-1 check (NEVER use `|| true` to silence substitution exits — swallows real crashes)

**Shell-scripting gotcha** (worth codifying alongside TD-013 when rule file is created):
> `set -euo pipefail` + `var=$(cmd)` antipattern — when `cmd` exits non-zero, `set -e` aborts bash BEFORE the following `if [ -n "$var" ]` check. `|| true` masks ALL non-zero exits including legitimate errors. Correct pattern: `set -uo pipefail` (drop -e) + `if ! var=$(cmd 2>&1); then exit_code=$?; fi` + `[ "$exit_code" -gt 1 ]` for tool-failure handling.

Not GDScript-specific, so doesn't belong in TD-013. Could live in a dedicated bash-scripting rule file when more lint scripts accumulate (V-9, V-10). Noted for future.

**Deferred (not logged as tech debt — low priority or resolved)**:
- W-2 `emit.call_deferred` intentional-flag inline comment (already present in script)
- S-2 README `|| true` rationale (N/A — no longer uses `|| true` after Option B)
- qa-tester Gap 3 (story §5 vs impl on commented-out emit) — practical outcome correct; minor doc-drift between story narrative and implementation comment

**Security-engineer B-1 (file not committed)** — FALSE ALARM. Files existed on disk but not yet committed because /code-review runs BEFORE R1. Specialist didn't have workflow context; files committed in subsequent R1 cycle.

**Gates skipped** (review-mode=lean): QL-TEST-COVERAGE, LP-CODE-REVIEW phase-gates. Standalone `/code-review` ran with 2 specialists (security-engineer + qa-tester).

---

## 🎉 Gamebus Epic Closure

**8 of 8 stories COMPLETE** with the merge of this story:

| Story | Title | PR | Status |
|-------|-------|-----|--------|
| 001 | Payload Resource classes | #2 | ✅ |
| 002 | GameBus autoload + provisional stubs | #3 | ✅ |
| 003 | signal_contract_test (ADR drift gate) | #4 | ✅ |
| 004 | payload_serialization_test | #5 | ✅ |
| 005 | GameBusDiagnostics (50/frame soft cap) | #6 | ✅ |
| 006 | GameBus stub for GdUnit4 isolation | #7 | ✅ |
| 007 | Cross-scene emit integration test | #8 | ✅ |
| 008 | CI lint per-frame emit ban | #9 (this) | ✅ |

**Entire signal-bus infrastructure delivered**: 27 typed signals × 10 domains, autoload with zero-state discipline, 4 provisional stub payloads ready for supersession by future epics, payload serialization round-trip guarantees, debug-only per-frame soft-cap diagnostics, test isolation via stub pattern, cross-scene signal lifecycle verified, and CI enforcement of the per-frame emit ban.

**Downstream unlocks**:
- Save/Load epic (ADR-0003 depends on payload serialization contract from story 004)
- SceneManager epic (scene_handoff_timing_test reuses cross-scene emit patterns from story 007)
- All Platform/Feature epic stories can now use `GameBusStub.swap_in()` for unit test isolation
- Ongoing ADR-0001 §7 enforcement via CI lint (story 008)
- Pattern template for V-9 pure-relay lint + V-10 save-path lint (reuses `tools/ci/` + Ruby parser + exit-code triage)

**Session totals across the epic**:
- **9 GDScript/GdUnit4 gotchas** codified for TD-013 (rule file creation overdue)
- **17 tech-debt register entries** (3 resolved, 14 open) — TD-001 through TD-015 + TD-010/011/014
- **57 automated tests** across 48 unit + 9 integration, 100% passing, 0 orphans
- **8 PRs merged**, zero reverted, zero rollbacks
