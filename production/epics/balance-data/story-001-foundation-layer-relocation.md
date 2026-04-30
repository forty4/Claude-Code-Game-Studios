# Story 001: Foundation-layer relocation + import path audit

> **Epic**: Balance/Data
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Integration
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/balance-data.md`
**Requirement**: `TR-balance-data-016` (module form ratification post-relocation), `TR-balance-data-017` (data file rename + flat format + UPPER_SNAKE_CASE keys exception)
*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006 — Balance/Data — BalanceConstants Singleton (MVP scope)
**ADR Decision Summary**: Stateless static utility class `class_name BalanceConstants extends RefCounted` (NOT autoload-registered) at the Foundation layer; single public static method `get_const(key: String) -> Variant`; lazy on-first-call loading.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: `FileAccess.get_file_as_string()` pre-Godot-4.4 stable; `JSON.parse_string()` pre-Godot-4.0 stable; `class_name` + static vars + RefCounted pre-cutoff stable. **G-14 class-cache refresh required**: between moving the file and running tests, run `godot --headless --import --path .` to refresh `.godot/global_script_class_cache.cfg` per the gotchas rule file.

**Control Manifest Rules (Foundation layer)**:
- Required: Foundation-layer modules live under `src/foundation/` per architecture.md layer invariants
- Forbidden: cross-layer reach-through; Feature-layer location for a Foundation-layer module
- Guardrail: relocation must not touch the call-site contract — consumers using `class_name BalanceConstants` (no path import) are structurally unaffected

---

## Acceptance Criteria

*From ADR-0006 §Validation Criteria §1 + §5, scoped to this story:*

- [ ] **AC-1** (TR-016 ratification): file `src/feature/balance/balance_constants.gd` is moved to `src/foundation/balance/balance_constants.gd`; `.uid` sidecar moves alongside (if present); the file's `class_name BalanceConstants extends RefCounted` declaration is unchanged
- [ ] **AC-2** (load-path consumer audit): all `load("res://src/feature/balance/balance_constants.gd")` references in `tests/` are updated to `load("res://src/foundation/balance/balance_constants.gd")` — verified via grep returning 0 matches at the old path
- [ ] **AC-3** (source-header doc comment update): the TEST ISOLATION DISCIPLINE block at `balance_constants.gd:18-24` is updated to reflect the new path in the load() incantation example
- [ ] **AC-4** (G-14 class-cache refresh): `godot --headless --import --path .` is run between the move and the first test invocation; first test run must complete with no `Identifier "BalanceConstants" not declared` parse errors
- [ ] **AC-5** (regression PASS): full GdUnit4 regression maintains the 501/501 baseline post-relocation; 0 errors / 0 failures / 0 orphans
- [ ] **AC-6** (orphan-path grep gate): `grep -rn "res://src/feature/balance" src/ tests/ tools/ docs/` returns 0 matches (excluding intentional historical references in completed story / sprint-1 documentation, which should be enumerated explicitly if surfaced)
- [ ] **AC-7** (consumer-class-name stability): `class_name BalanceConstants` continues to resolve in `damage_calc.gd` + `unit_role.gd` + all unit/integration tests without import edits — confirms the `class_name` global identifier (not the file path) is the locked contract per ADR-0006 §Decision 1

---

## Implementation Notes

*Derived from ADR-0006 §Decision 1 (Module Form), §Migration Plan, §Validation Criteria:*

1. **Use `git mv`** to preserve history when moving `balance_constants.gd` and its `.uid` sidecar. Pre-create `src/foundation/balance/` directory if it doesn't exist.

2. **Files known to load() the old path** (audit before moving; update in same commit):
   - `tests/unit/balance/balance_constants_test.gd:13` — `_BALANCE_CONSTANTS_PATH` const
   - `src/foundation/balance/balance_constants.gd:21` (post-move) — TEST ISOLATION DISCIPLINE doc comment example incantation
   - **Full audit pattern**: `grep -rn "res://src/feature/balance" tests/ src/ tools/ docs/` before AND after the move

3. **G-14 class-cache refresh is mandatory** (not optional): without it, the first test run will fail with `Identifier "BalanceConstants" not declared in the current scope` despite the file existing on disk. Run `godot --headless --import --path .` immediately after the file move, before any test invocation.

4. **Consumers using `class_name BalanceConstants`** require NO edits — they import via the global identifier registry, not via path. The damage_calc.gd ×8 sites, unit_role.gd ×N sites, and integration test sites all resolve through `class_name` registration (which is path-agnostic post-G-14 refresh).

5. **The `_ENTITIES_JSON_PATH` const (line 33)** stays unchanged: the JSON data file is at `res://assets/data/balance/balance_entities.json` regardless of where the loader code lives.

6. **Layer-invariant rationale**: ADR-0006 §Engine Compatibility classifies the domain as "Core — data infrastructure / file loading"; per architecture.md layer invariants (Platform → Foundation → Core → Feature → Presentation → Polish), data-loading utilities for tuning constants belong at the Foundation layer (ratifies the original Pending-list classification per `production/epics/index.md` 2026-04-25 changelog entry). The `src/feature/balance/` location was a sprint-1 expedience during damage-calc story-006b PR #65 (story closed before ADR-0006 had ratified the architectural layer); this story corrects the layer placement.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 002**: TR-traced test suite extension — adds new test functions, does NOT relocate files
- **Story 003**: per-system hardcoded-constant lint template generalization
- **Story 004**: orphan-reference grep gate as a CI lint (this story's AC-6 is a one-time verification; story 004 wires it as a recurring CI check)
- **Story 005**: perf baseline test + TD-041

---

## QA Test Cases

*Lean mode — orchestrator-authored. Convergent /code-review (godot-gdscript-specialist + qa-tester parallel) at story close-out validates these.*

**AC-1** (file moved):
- Given: `src/feature/balance/balance_constants.gd` exists pre-move
- When: `git mv src/feature/balance/balance_constants.gd src/foundation/balance/balance_constants.gd`
- Then: `git status` shows the rename; old path returns no file; new path opens the unchanged code
- Edge case: if `.uid` sidecar exists at `src/feature/balance/balance_constants.gd.uid`, it must move alongside

**AC-2** (load-path consumer audit):
- Given: all `tests/**/*.gd` files searched for `res://src/feature/balance/balance_constants.gd` literal
- When: each match is updated to `res://src/foundation/balance/balance_constants.gd`
- Then: `grep -rn "res://src/feature/balance" tests/ src/` returns 0 matches
- Edge case: in-source comments referencing the path (e.g., `balance_constants.gd:21` doc-comment example) are also updated

**AC-3** (source-header doc comment):
- Given: `src/foundation/balance/balance_constants.gd` post-move
- When: the TEST ISOLATION DISCIPLINE block (lines 18-24) is read
- Then: the example incantation reads `(load("res://src/foundation/balance/balance_constants.gd") as GDScript).set("_cache_loaded", false)`
- Edge case: the block's other instructional content (the WHY of resetting state) is unchanged

**AC-4** (G-14 class-cache refresh):
- Given: file moved, no class-cache refresh yet
- When: `godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests/unit/balance -c` is run
- Then: stderr contains `Parse Error: Identifier "BalanceConstants" not declared in the current scope` for the test file (this is the FAILURE case proving the gotcha)
- Recovery: `godot --headless --import --path .` followed by re-run produces clean test output

**AC-5** (regression PASS):
- Given: file moved + paths updated + class-cache refreshed
- When: full regression `godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests/unit -a res://tests/integration -c`
- Then: `Overall Summary` reports ≥501 tests, 0 errors, 0 failures, 0 orphans, exit 0
- Edge case: if any orphan or failure surfaces, suspect G-10 autoload binding (unlikely — BalanceConstants is not an autoload) or G-7 silent-skip on a parse error elsewhere

**AC-6** (orphan-path grep gate):
- Given: post-move state
- When: `grep -rn "res://src/feature/balance" src/ tests/ tools/ docs/`
- Then: 0 matches OR explicitly enumerated historical references in story / sprint-1 / changelog markdown files (acceptable; never code/tests)
- Edge case: matches in `production/epics/damage-calc/story-006b-*.md` (the ratified sprint-1 story file documenting the original location) are acceptable historical references

**AC-7** (consumer-class-name stability):
- Given: post-relocation state
- When: `damage_calc.gd`, `unit_role.gd`, and all consumer test files are inspected for any `load("res://src/feature/balance/...")` or `load("res://src/foundation/balance/...")` references
- Then: only test files (which need explicit reset-cache load() calls) reference the path; production source code uses `BalanceConstants.get_const(...)` exclusively (no path imports)
- Edge case: any production code path reference is a violation of ADR-0006 §Decision 1 and must be refactored to `class_name`-only access

---

## Test Evidence

**Story Type**: Integration
**Required evidence**:
- `tests/unit/balance/balance_constants_test.gd` continues to pass post-relocation (no new test added in this story; existing 5 tests must remain green with updated load path)
- Smoke check: `production/qa/smoke-balance-data-story-001-YYYY-MM-DD.md` documenting full regression result + grep audit output

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (first story in epic; ADR-0006 already Accepted)
- Unlocks: Story 002 (TR-traced test suite extension uses post-move path); Story 005 (perf baseline test references post-move path)
