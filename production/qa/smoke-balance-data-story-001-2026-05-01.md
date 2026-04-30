# Smoke check — balance-data story-001 — 2026-05-01

**Story**: Foundation-layer relocation + import path audit
**Implementation date**: 2026-05-01
**ADR**: ADR-0006 (Accepted 2026-04-30)
**Manifest Version**: 2026-04-20 (matches story header)

## Pre-flight audit (path occurrence inventory)

`grep -rn "res://src/feature/balance" src/ tests/ tools/` returned **14 matches** (initial pre-flight count — note: original story Implementation Notes #2 enumerated 2 examples; canonical audit pattern surfaced full count):

| # | File | Line | Form | Edit |
|---|---|---|---|---|
| 1 | `src/feature/balance/balance_constants.gd` | 21 | doc-comment example | post-move path update |
| 2 | `tests/unit/balance/balance_constants_test.gd` | 13 | `_BALANCE_CONSTANTS_PATH` const | path string |
| 3 | `tests/unit/damage_calc/damage_calc_test.gd` | 26 | inline `load()` | path string |
| 4 | `tests/unit/damage_calc/damage_calc_perf_test.gd` | 21 | inline `load()` | path string |
| 5 | `tests/unit/foundation/unit_role_perf_test.gd` | 19 | `_BC_PATH` const | path string |
| 6 | `tests/unit/foundation/unit_role_cost_table_test.gd` | 22 | `_BC_PATH` const | path string |
| 7 | `tests/unit/foundation/unit_role_skeleton_test.gd` | 22 | `_BC_PATH` const | path string |
| 8 | `tests/unit/foundation/unit_role_stat_derivation_test.gd` | 20 | `_BC_PATH` const | path string |
| 9 | `tests/unit/foundation/unit_role_passive_tags_test.gd` | 21 | `_BC_PATH` const | path string |
| 10 | `tests/unit/foundation/unit_role_direction_mult_test.gd` | 20 | `_BC_PATH` const | path string |
| 11 | `tests/unit/foundation/balance_constants_unit_role_caps_test.gd` | 14 | `_BC_PATH` const | path string |
| 12 | `tests/integration/damage_calc/damage_calc_integration_test.gd` | 143 | inline `load()` | path string (initially missed; head -10 truncation) |
| 13 | `tests/integration/foundation/unit_role_damage_calc_integration_test.gd` | 25 | `_BC_PATH` const | path string (initially missed; head -10 truncation) |
| 14 | `tools/ci/lint_unit_role.sh` | 109 | echo'd developer hint string | path string in lint hint |

## AC-1 file move

- `git mv src/feature/balance/balance_constants.gd → src/foundation/balance/balance_constants.gd`
- `git mv src/feature/balance/balance_constants.gd.uid → src/foundation/balance/balance_constants.gd.uid`
- Empty `src/feature/balance/` directory removed
- `git status` shows 2 renames (R), preserving history

## AC-3 source-header doc-comment update

- `src/foundation/balance/balance_constants.gd:21` updated: `res://src/feature/balance/balance_constants.gd` → `res://src/foundation/balance/balance_constants.gd`

## AC-2 load-path consumer audit

- 13 path string updates across 11 test files + 1 lint script (table above)
- Final state: `grep -rn "res://src/feature/balance" src/ tests/ tools/` returns 0 matches

## AC-4 G-14 class-cache refresh

- `godot --headless --import --path .` invoked between move and first regression run
- `update_scripts_classes` log confirms `BalanceConstants` re-registered in global class cache
- Mandatory per `.claude/rules/godot-4x-gotchas.md` G-14

## AC-5 regression PASS — with 1 pre-existing failure flagged

**Run 1 (incomplete; revealed 2 missed path edits)**:

- Overall Summary: 501 test cases | 18 errors | 4 failures | 0 orphans
- Root cause of 18 errors: missed integration test path edits at lines 143 + 25
- Subsequent triage: applied 3 missed edits (#12, #13, #14 above)

**Run 2 (final)**:

- Overall Summary: **501 test cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans**
- Test count baseline: 501 — exact match to active.md unit-role epic close-out baseline
- Errors: 0 — relocation work introduced zero errors
- Orphans: 0
- Remaining 1 failure: `test_hero_data_doc_comment_contains_required_strings` in `tests/unit/foundation/unit_role_skeleton_test.gd:231`

**Pre-existing failure flag** (NOT introduced by this story):

- Test asserts `src/foundation/hero_data.gd` contains the literal string `"ADR-0009 §Migration Plan §3"` (line 241)
- `grep` confirms hero_data.gd does NOT contain this exact phrase (contains "ADR-0009" elsewhere but not the §Migration Plan §3 sub-citation)
- Story 001 made zero edits to `hero_data.gd` (verified via `git diff --name-only`)
- Failure is a pre-existing doc-comment drift independent of this story's scope
- Recommend triage in unit-role epic close-out follow-up OR a separate hotfix story

## AC-6 orphan-path grep gate

- `grep -rn "res://src/feature/balance" src/ tests/ tools/` → **0 matches**
- `docs/` + `production/` markdown contain 511 historical references — acceptable per AC-6 ("explicitly enumerated historical references in story / sprint-1 / changelog markdown files")

## AC-7 consumer-class-name stability

- `damage_calc.gd`: 19 `BalanceConstants.*` references, **0 path imports** (`load("res://...balance...")` count = 0)
- `unit_role.gd`: 17 `BalanceConstants.*` references, **0 path imports**
- All consumer code uses the `class_name BalanceConstants` global identifier exclusively, validating ADR-0006 §Decision 1's "class_name is the locked contract" claim

## Process insight reinforced

**`head -N` after grep silently truncates audit results.** My pre-flight grep used `... 2>&1 | head -10` and missed 4 files that landed past the head limit (3 in tests/integration + 1 in tools/). Cost: one wasted regression run + ~3 min triage. Codified pattern: for audit-style greps, never use `head -N` unless explicitly counting only top matches; use `wc -l` to verify total before truncating.

## Acceptance criteria summary

- [x] AC-1 file moved with `.uid` sidecar via `git mv`
- [x] AC-2 path audit: 0 matches in src/ tests/ tools/
- [x] AC-3 source-header doc-comment example updated
- [x] AC-4 G-14 class-cache refresh ran before first test invocation
- [x] AC-5 Full regression baseline 501 maintained, 0 errors / 0 orphans (1 pre-existing failure flagged separately)
- [x] AC-6 `grep -rn "res://src/feature/balance" src/ tests/ tools/ docs/` returns 0 matches in src/tests/tools/; markdown historical refs acceptable
- [x] AC-7 `damage_calc.gd` + `unit_role.gd` use only `BalanceConstants` class-name access (0 path imports)
