# Smoke check — balance-data story-003 — 2026-05-01

**Story**: Per-system hardcoded-constant lint template
**Implementation date**: 2026-05-01
**ADR**: ADR-0006 (Accepted 2026-04-30)
**TR**: TR-balance-data-010 (active; AC-DC-48 lint precedent)
**Manifest Version**: 2026-04-20 (matches story header)

## Locked design decisions (from /story-readiness 2026-05-01)

- **AC-1 → Approach B (template file)**: per story-body recommendation; AC-DC-48 instance-per-system pattern; 1 consumer currently (damage_calc) → revisit Approach A (parameterized) when 3+ consumers exist
- **Implementation Notes §3 → Option β (hardcoded subset)**: jq is NOT in `.github/workflows/tests.yml` (verified pre-flight); Option α (jq-runtime parsing) deferred until jq is added to CI
- **Implementation Notes §6 → Option (a) extend existing step**: tests.yml gdunit4 job has linear lint sequence (lines 44-72); adding one more step is the natural extension point (vs Option (b) new job lane)

## AC-1 — template extraction (Approach B)

**File created**: `tools/ci/lint_no_hardcoded_balance_constants.sh.template`

Header doc-comment covers:
- AC-DC-48 origin (cited at "## Origin" section)
- 3-step instantiation procedure (cited at "## How to instantiate" section): cp template → customize 2 INSTANTIATION points (TARGET + PATTERN) → add tests.yml step
- Exit-code convention (0 pass / 1 domain / ≥2 tool) per story-008 codification
- Story-008 silent-fail antipattern guard (cited at "## Story-008 silent-fail antipattern guard" section) — explains why `if grep ...; then` is correct vs the `var=$(grep) + [ -n "$var" ]` antipattern
- Cross-references to canonical instance + gotchas rules + story-008 source

2 INSTANTIATION points marked with `# INSTANTIATION:` comments + `<TODO: ...>` placeholders so a future consumer can find the customization sites by grep.

## AC-2 — existing damage-calc lint preserved

`tools/ci/lint_damage_calc_no_hardcoded_constants.sh` UNCHANGED (no edits this story).

Smoke run (pre-implementation baseline confirmation):
```
$ bash tools/ci/lint_damage_calc_no_hardcoded_constants.sh
PASS: no hardcoded balance constants in src/feature/damage_calc/damage_calc.gd (AC-DC-48).
exit: 0
```

Post-implementation re-run: see AC-7 below.

## AC-3 — foundation-layer lint coverage (NEW instance)

**File created**: `tools/ci/lint_foundation_balance_no_hardcoded_constants.sh`

Scope:
- TARGET_DIR: `src/foundation/`
- Allow-list: `--exclude-dir="balance"` (source-of-truth file at `src/foundation/balance/balance_constants.gd` — by definition contains the constants the lint forbids elsewhere)
- File filter: `--include="*.gd"`

Current foundation-layer consumers (verified 2026-05-01):
- `src/foundation/unit_role.gd` (uses `BalanceConstants.get_const(...)` per ADR-0009)
- `src/foundation/hero_data.gd` (Resource wrapper; no BalanceConstants refs currently)

Pre-flight dry-run (before lint script existed):
```
$ PATTERN="const (BASE_CEILING|...|MOVE_BUDGET_PER_RANGE) "
$ grep -rnE "$PATTERN" src/foundation --include="*.gd" --exclude-dir="balance"
(no output — 0 violations)
```

Post-implementation lint run: see AC-7 below.

## AC-4 — CI wiring

`.github/workflows/tests.yml` updated: new step inserted after the existing damage_calc no-hardcoded-constants step (line 63) in the gdunit4 job:

```yaml
      - name: Lint Foundation Balance no hardcoded constants (TR-balance-data-010 / story-003 AC-3)
        run: bash tools/ci/lint_foundation_balance_no_hardcoded_constants.sh
```

This step fails the workflow on lint exit ≥1 (per the gdunit4 job's default fail-fast behavior; no `continue-on-error` clause). First execution will be on the next PR / push to main.

## AC-5 — template documentation

The template file's header doc-comment (lines 1-65) documents:
- (a) **AC-DC-48 origin**: section "## Origin" cites the precedent file + landing PR
- (b) **How to instantiate**: section "## How to instantiate (Approach B per balance-data/story-003 AC-1)" — 3-step procedure with concrete commands
- (c) **Silent-fail antipatterns codified in damage-calc story-008**: section "## Story-008 silent-fail antipattern guard" — explains the `var=$(grep) + [ -n "$var" ]` antipattern + the correct `if grep ...; then` pattern + grep exit-code semantics
- (d) **Exit-code convention**: section "## Exit codes (story-008 codified)" — 0 pass / 1 domain / ≥2 tool
- (e) **Cross-references**: rules files, canonical instance, story-008 source

## AC-6 — smoke check evidence

This document.

## AC-7 — regression PASS

Post-implementation smoke run sequence:

**Damage-calc lint (regression — AC-2)**:
```
$ bash tools/ci/lint_damage_calc_no_hardcoded_constants.sh
PASS: no hardcoded balance constants in src/feature/damage_calc/damage_calc.gd (AC-DC-48).
exit: 0
```

**Foundation-layer lint (new — AC-3)**:
```
$ bash tools/ci/lint_foundation_balance_no_hardcoded_constants.sh
PASS: no hardcoded balance constants in src/foundation/ (excluding balance/) (TR-balance-data-010).
exit: 0
```

**Full GdUnit4 regression (no test infrastructure changes from this story)**:
```
Overall Summary: 506 test cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans
```

The 1 pre-existing failure (`test_hero_data_doc_comment_contains_required_strings` in `tests/unit/foundation/unit_role_skeleton_test.gd:231`) is unrelated to balance-data and was carried from story-001 close-out (orthogonal; flagged in story-001/002/005 Completion Notes).

This story does NOT touch test code or production GDScript code; the regression baseline 506 is unchanged from story-005's post-write state (story-003 only adds bash + workflow yml).

## Acceptance criteria summary

- [x] AC-1 reusable template extracted at `tools/ci/lint_no_hardcoded_balance_constants.sh.template`
- [x] AC-2 damage-calc lint exits 0 (no regression — pre + post implementation)
- [x] AC-3 foundation-layer lint exits 0 (passes against `src/foundation/` excluding allow-listed `balance/`)
- [x] AC-4 `.github/workflows/tests.yml` invokes generalized template via foundation-layer instance; fails workflow on exit ≥1
- [x] AC-5 template doc-comment explains origin (a) + instantiation (b) + silent-fail antipattern (c) + exit-code convention + cross-references
- [x] AC-6 smoke evidence doc populated (this document)
- [x] AC-7 full regression baseline 506 maintained (no test infrastructure changes from this story)
