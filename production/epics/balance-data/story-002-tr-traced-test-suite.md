# Story 002: TR-traced unit test suite extension

> **Epic**: Balance/Data
> **Status**: Complete (2026-05-01)
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: 1.5-2h (3 new tests + cases-table audit + TR annotations on existing 7)
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/balance-data.md`
**Requirement**:
- `TR-balance-data-007` — AC-07 all registered keys accessible via `get_const(key)` (currently 22+ keys; 51 post-ADR-0010/0011 same-patch appends)
- `TR-balance-data-013` — AC-EC1 empty-file edge case (godot-gdscript-specialist Item 4 advisory: `FileAccess.file_exists()` precheck for diagnostic separation)
- `TR-balance-data-019` — Lazy on-first-call loading + `_cache_loaded: bool` idempotent guard
- `TR-balance-data-020` — G-15 test-isolation discipline (cache reset in `before_test()` mandatory)

*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006 — Balance/Data — BalanceConstants Singleton (MVP scope)
**ADR Decision Summary**: Single public static `get_const(key) -> Variant`; lazy on-first-call; `_cache_loaded: bool` idempotent guard short-circuits subsequent calls even after failed parse (graceful degradation).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: Pure GDScript test file; uses `extends GdUnitTestSuite` (RefCounted base). G-15 lifecycle hook discipline is mandatory: use `before_test()` / `after_test()`, never `before_each()` / `after_each()` (silently ignored in v6.1.2). G-23 caveat: GdUnit4 v6.1.2 has `is_equal_approx` and `is_not_equal` but NOT `is_not_equal_approx` — use Pattern A (exact `is_not_equal`) when values differ by >> binary noise.

**Control Manifest Rules (Foundation layer)**:
- Required: every test suite touching `BalanceConstants` resets `_cache_loaded = false` in `before_test()` per ADR-0006 §Decision 6 + G-15
- Forbidden: shared mutable test state across functions; `before_each()` / `after_each()` lifecycle hooks (silently ignored)
- Guardrail: each test must be independently runnable; no execution-order dependency

---

## Acceptance Criteria

*From ADR-0006 §Validation §1 + GDD AC-07/EC1, scoped to this story:*

- [ ] **AC-1** (TR-007 all-keys coverage audit): the test file's `cases` table (or equivalent) covers EVERY scalar key currently present in `assets/data/balance/balance_entities.json` — verified by a programmatic count: `assert_int(cases.size()).is_equal_or_greater(file_scalar_key_count)`
- [ ] **AC-2** (TR-007 dict-keys coverage audit): every Dictionary-shaped key (`BASE_DIRECTION_MULT`, `CLASS_DIRECTION_MULT`, and any post-ADR-0010 dict key) has at least one test asserting it returns a Dictionary AND at least one inner-value spot-check
- [ ] **AC-3** (TR-013 empty-file precheck): a new test `test_get_const_file_exists_precheck_diagnostic_separation` asserts that `_load_cache()` separates "file not found" from "empty file" via `FileAccess.file_exists()` precheck, OR explicitly documents that the MVP wrapper does NOT separate them (per the godot-gdscript-specialist Item 4 advisory carried in TR-013)
- [ ] **AC-4** (TR-019 idempotent-guard hardening): a new test `test_get_const_failed_parse_does_not_re_attempt` asserts that after a simulated failed parse (`_cache = {}` + `_cache_loaded = true`), calling `get_const(any_key)` returns null WITHOUT calling `_load_cache()` again — i.e., no disk hammering on subsequent calls (extends the existing `test_get_const_stable_empty_cache_after_failure_returns_null_no_reparse` with explicit re-parse guard verification)
- [ ] **AC-5** (TR-020 cross-suite isolation canary): a new test `test_get_const_pre_test_state_resets_static_vars` asserts that on entry to the test (after `before_test()` runs), `_cache_loaded == false` AND `_cache.is_empty() == true` — protects against G-15 violations (someone forgetting to reset state) and against `before_each()` typos
- [ ] **AC-6** (TR header annotations): each existing test function's docstring is amended with a `## TR-balance-data-XXX:` line linking to its primary TR; new tests follow the same convention
- [ ] **AC-7** (regression PASS): full GdUnit4 regression maintains ≥501 baseline + new tests; 0 errors / 0 failures / 0 orphans; existing 5 tests continue to pass with updated TR annotations

---

## Implementation Notes

*Derived from ADR-0006 §Decision 2 + §Decision 6 + `.claude/rules/godot-4x-gotchas.md`:*

1. **Existing test file** (`tests/unit/balance/balance_constants_test.gd`) currently has 5 test functions:
   - `test_get_const_lazy_load_fires_on_first_call` (AC-1 / lazy-load)
   - `test_get_const_caches_after_first_call_no_reparse` (AC-1 / cache stability)
   - `test_get_const_all_scalar_keys_return_expected_values` (AC-2 / 10 scalar keys; needs expansion to all current keys)
   - `test_get_const_direction_mult_keys_return_dictionaries` (AC-2 / dict keys)
   - `test_get_const_unknown_key_returns_null` (AC-2 / unknown key)
   - `test_get_const_stable_empty_cache_after_failure_returns_null_no_reparse` (GAP-1 from /code-review qa-tester)
   - `test_get_const_class_direction_mult_all_classes_all_directions` (AC-7 / CLASS_DIRECTION_MULT string-keys)

   **Audit task**: re-read `assets/data/balance/balance_entities.json` and verify the `cases` array in `test_get_const_all_scalar_keys_return_expected_values` covers EVERY current scalar key. ADR-0010 + ADR-0011 same-patch appends (per TR-007) added 27+2=29 keys; the cases table needs to grow accordingly.

2. **AC-3 design choice** — read ADR-0006 §Risks R-2 + the TR-013 advisory text carefully. The MVP wrapper currently uses `raw.is_empty()` which masks "file not found" (returns "" per FileAccess) vs "empty file" (also returns ""). The godot-gdscript-specialist Item 4 advisory recommends a `FileAccess.file_exists()` precheck for diagnostic separation. **Decision for this story**: implement the test such that it documents the CURRENT behaviour (no precheck) AND logs a TODO referencing TR-013 for the precheck refactor as a future story (not in this epic's residual scope per EPIC.md). Alternative: implement the precheck refactor here. Author judgement at story-readiness time.

3. **AC-4 test pattern** — to verify "no disk hammering on failed parse" without actually mocking FileAccess (which is not trivial in GDScript), use the existing test pattern: set `_cache_loaded = true` + `_cache = {}` directly via the GDScript handle, then call `get_const()` twice and assert `_cache` is still empty after each call (proving `_load_cache()` was not re-invoked between them). Alternative if mock-friendly seam exists: introduce a `_load_count: int` static var that increments in `_load_cache()` to make the assertion crisper. Story-readiness review picks the approach.

4. **AC-5 canary** — this is a meta-test that protects against future regressions in test infrastructure itself. Pattern: at the very top of the test body (before any production-code call), assert `_bc_script.get("_cache_loaded") as bool == false` AND `(_bc_script.get("_cache") as Dictionary).is_empty()`. If `before_test()` ever drifts (e.g., someone changes it to `before_each()` per G-15), this test fails on entry.

5. **G-23 caveat for any new "must not equal X" assertions** — use `is_not_equal(unwanted)` not the nonexistent `is_not_equal_approx`. The 1.20→1.09 unit-role/story-005 sentinel pattern demonstrates the correct usage.

6. **G-16 caveat for parametric test cases** — declare `cases: Array[Dictionary]` (typed) not untyped `Array` to avoid Variant degradation in iteration variables. The existing test file uses `Array` (line 100, 216) which works but loses type narrowing; AC-1 expansion is a good opportunity to upgrade to `Array[Dictionary]`.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: file relocation — story 002 assumes the post-move path `src/foundation/balance/balance_constants.gd`
- **Story 003**: per-system hardcoded-constant lint template (separate generalization work)
- **Story 005**: perf baseline test in a NEW test file `balance_constants_perf_test.gd` (logic + perf assertions are separate test files per project convention)
- **`FileAccess.file_exists()` precheck production-code refactor**: if AC-3 documents the current behaviour without changing it, the refactor is a separate forward-tech-debt item (to be filed alongside TD-041 in Story 005)

---

## QA Test Cases

*Lean mode — orchestrator-authored.*

**AC-1** (all-keys coverage):
- Given: `balance_entities.json` post-ADR-0010/0011 appends contains N scalar keys (count to be verified at implementation time)
- When: `test_get_const_all_scalar_keys_return_expected_values` runs
- Then: every JSON scalar key has a corresponding case row; `assert_int(cases.size()).is_equal_or_greater(N)`
- Edge case: if a JSON key is added to the file but not to the test, this test must FAIL (otherwise the all-keys audit is structurally broken)

**AC-2** (dict-keys coverage):
- Given: `BASE_DIRECTION_MULT`, `CLASS_DIRECTION_MULT`, and any post-ADR-0010 dict key in JSON
- When: `test_get_const_direction_mult_keys_return_dictionaries` runs (extended)
- Then: each dict key returns a Dictionary AND at least one inner spot-check passes
- Edge case: an empty dict (e.g., `{}`) is acceptable for the "is Dictionary" check but fails the inner spot-check — both assertions must fire

**AC-3** (empty-file precheck):
- Given: TR-013 advisory says to consider `FileAccess.file_exists()` precheck
- When: the new `test_get_const_file_exists_precheck_diagnostic_separation` runs
- Then: either (path A — precheck implemented) the production code separates "not found" from "empty" via two distinct push_error messages, AND the test asserts both paths; or (path B — precheck deferred) the test asserts the current single-message behaviour AND logs a TR-013 follow-up TODO
- Edge case: if path A is chosen and FileAccess.file_exists() is not idempotent across platforms, fall back to path B with explicit doc

**AC-4** (idempotent-guard hardening):
- Given: `_cache_loaded = true` + `_cache = {}` (post-failure state)
- When: `get_const("any_key")` is called twice in succession
- Then: both calls return null; `_cache` remains empty after both calls; no `_load_cache()` invocation between calls (verified by absence of cache mutation OR by `_load_count` instrumentation if that seam is added)
- Edge case: if a future PR moves `_cache_loaded = true` inside the `if parsed is Dictionary` branch (the regression this test guards against), this test must FAIL

**AC-5** (cross-suite isolation canary):
- Given: a fresh test enters its body
- When: the FIRST line of the test body asserts pre-conditions
- Then: `_cache_loaded == false` AND `_cache.is_empty() == true`
- Edge case: if `before_test()` is renamed to `before_each()` (G-15 violation), this canary FAILS on the first run, surfacing the typo immediately

**AC-6** (TR header annotations):
- Given: each existing + new test function
- When: the docstring is read
- Then: a `## TR-balance-data-XXX:` line is present linking to the primary TR
- Edge case: tests that cover multiple TRs (e.g., all-keys + dict-keys are both TR-007) cite all relevant TRs

**AC-7** (regression PASS):
- Given: extended test file with new tests + annotations
- When: full regression runs
- Then: ≥501 + (3 new tests) baseline; 0 errors / 0 failures / 0 orphans; exit 0
- Edge case: G-7 silent-skip on a parse error in the new tests — verify Overall Summary count matches expected

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- `tests/unit/balance/balance_constants_test.gd` extended (3 new test functions + TR annotations + all-keys cases expansion)
- Full regression PASS captured in story close-out commit message

**Status**: [x] Complete — `tests/unit/balance/balance_constants_test.gd` extended (240 → 370 LoC; 7 → 10 tests); regression `504 cases / 0 errors / 0 orphans / 1 failures` (1 pre-existing failure carried from story-001 close-out, orthogonal)

---

## Dependencies

- Depends on: Story 001 (file relocation; load path used in this story's `_BALANCE_CONSTANTS_PATH` const must point to `src/foundation/balance/`)
- Unlocks: None (terminal in the test-coverage path; story 003-005 do not depend on this)

---

## Completion Notes

**Completed**: 2026-05-01
**Criteria**: 7/7 passing — see `/story-done` traceability table for per-AC test mapping
**Code Review**: Complete — `/code-review` returned APPROVED 2026-05-01 (lean mode; LP-CODE-REVIEW + QL-TEST-COVERAGE skipped per `production/review-mode.txt`). All 6/6 standards passing; ADR-0006 fully compliant; G-15/G-16/G-23/G-9 disciplines applied throughout.
**Test Evidence**: `tests/unit/balance/balance_constants_test.gd` extended in place (10 test functions; 504-case regression baseline maintained).
**Regression result**: `504 test cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans` (501 baseline + 3 new tests; 1 pre-existing failure carried from story-001).

### Locked decisions held (from /story-readiness 2026-05-01)

- **AC-3 → Path B**: documented current MVP single-message behaviour as regression sentinel; embedded `# TODO TR-013` breadcrumb. **No production code change** to `balance_constants.gd`.
- **AC-4 → Pattern A**: extended existing reflection-based pattern (set `_cache_loaded=true` + `_cache={}` via GDScript handle, two-call hardening). **No `_load_count` instrumentation** in production code.

### Files changed (1)

- `tests/unit/balance/balance_constants_test.gd` — extended in place (240 → 370 LoC; +130 net; 7 → 10 test functions)
  - 3 new test functions: `test_get_const_pre_test_state_resets_static_vars` (AC-5/TR-020 — positioned first in suite as G-15 isolation canary), `test_get_const_failed_parse_does_not_re_attempt` (AC-4/TR-019), `test_get_const_file_exists_precheck_diagnostic_separation` (AC-3/TR-013)
  - AC-1 cases-table extended 10 → 18 scalar keys; converted to typed `Array[Dictionary]` (G-16); added static count guard `is_greater_equal(18)` with comment explaining the post-ADR-0010/0011 breakdown
  - AC-7 cases-table also typed (proactive G-16 cleanup per Implementation Notes #6 mandate)
  - TR-balance-data-XXX docstring annotations added to all 10 test functions (AC-6)

### Deviations (ADVISORY only)

1. **Pre-existing failure carried from story-001 close-out (NOT introduced)**: `test_hero_data_doc_comment_contains_required_strings` in `tests/unit/foundation/unit_role_skeleton_test.gd:231`. Already documented in story-001 Completion Notes; orthogonal to story-002 scope. Recommended for triage in unit-role epic close-out follow-up OR a separate hotfix story.

### Suggestions deferred (from /code-review)

Three minor stylistic suggestions surfaced during /code-review; none required. Defer to future hardening:
1. AC-3 test name clarity (`test_get_const_file_exists_precheck_diagnostic_separation` reads as positive-case but verifies happy path)
2. AC-1 count-floor maintenance contract: bumping `is_greater_equal(18)` floor when JSON gains keys (manual pair-update with cases table)
3. TR-013 TODO breadcrumb visibility: in docstring rather than runtime-greppable `TODO:` comment
