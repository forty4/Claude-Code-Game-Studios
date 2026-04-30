# Story 003: Per-system hardcoded-constant lint template

> **Epic**: Balance/Data
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: 1.5-2h (template extraction + CI wiring + silent-fail antipattern doc)
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/balance-data.md`
**Requirement**: `TR-balance-data-010` — AC-10 hardcoding ban: values in JSON must NOT exist as literal constants in `.gd` files. Lint extension pattern from AC-DC-48 precedent.

*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006 — Balance/Data — BalanceConstants Singleton (MVP scope)
**ADR Decision Summary**: §Decision 5 — UPPER_SNAKE_CASE keys grant 1:1 grep-ability across `.gd ↔ .json ↔ .md`. AC-DC-48 (`tools/ci/lint_damage_calc_no_hardcoded_constants.sh`) is the existing per-system lint instance; this story generalizes it into a reusable template/pattern for future consumers.

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: bash-only changes; no GDScript work. Watch for the **TG-2 sub-agent Bash blocking pattern** when invoking the lint script directly via Bash. Watch for the **damage-calc story-008 set-euo-pipefail antipattern** (codified in `production/epics/damage-calc/story-008-*.md`): `set -euo pipefail` + `var=$(cmd)` + `if [ -n "$var" ]` is a silent-fail trap; use `if ! var=$(cmd 2>&1); then exit_code=$?; fi` instead.

**Control Manifest Rules (Foundation layer)**:
- Required: hardcoded balance values forbidden in `.gd` source files; all values flow through `BalanceConstants.get_const(key)`
- Forbidden: silent lint failures (Ruby crash, missing file = match-zero, etc.); a lint that "passes" because it scans nothing must FAIL
- Guardrail: lint must distinguish between "tool failure" (exit ≥2) and "domain failure" (exit 1) for CI triage clarity

---

## Acceptance Criteria

*From ADR-0006 §Decision 7 + TR-010 + AC-DC-48 lint precedent generalization, scoped to this story:*

- [ ] **AC-1** (template extraction): a reusable lint template/pattern is extracted from `tools/ci/lint_damage_calc_no_hardcoded_constants.sh`. Two viable approaches — author judgement:
  - **Approach A — parameterized script**: `tools/ci/lint_no_hardcoded_balance_constants.sh` accepts `--system <name>` and `--source-dir <path>` args; existing `lint_damage_calc_*.sh` becomes a thin caller wrapping the parameterized version
  - **Approach B — template file**: `tools/ci/lint_no_hardcoded_balance_constants.sh.template` documents the reusable shape; future consumers copy + customize per AC-DC-48 precedent (mirrors `lint_per_frame_emit.sh` template pattern)
- [ ] **AC-2** (existing damage-calc lint preserved): `tools/ci/lint_damage_calc_no_hardcoded_constants.sh` continues to pass against current `src/feature/damage_calc/`; no regression
- [ ] **AC-3** (foundation-layer lint coverage extension): the template/parameterized script is invoked against `src/foundation/` (covering `unit_role.gd` + post-relocation `balance_constants.gd` itself if applicable) — passes; OR documented as scope-deferred to the unit-role epic close-out hardening with explicit TODO
- [ ] **AC-4** (CI wiring): `.github/workflows/tests.yml` invokes the generalized template at least once (either as the existing damage-calc lane or as a new foundation-layer lane); fails the workflow on lint exit ≥1
- [ ] **AC-5** (template documentation): a README or doc-comment in the script explains: (a) the AC-DC-48 origin, (b) how to instantiate the template for a new consumer (hp-status, turn-order, hero-database), (c) the silent-fail antipatterns codified in damage-calc story-008 (`set -euo pipefail` + capture-and-check)
- [ ] **AC-6** (smoke check): `production/qa/smoke-balance-data-story-003-YYYY-MM-DD.md` documents lint runs (damage-calc + foundation-layer) with their exit codes, distinguishing pass/fail/tool-error
- [ ] **AC-7** (regression PASS): full regression continues to pass; no test infrastructure changes from this story

---

## Implementation Notes

*Derived from ADR-0006 §Decision 7 + AC-DC-48 lint precedent (`tools/ci/lint_damage_calc_no_hardcoded_constants.sh`) + damage-calc story-008 shell-scripting gotcha:*

1. **Read the existing `lint_damage_calc_no_hardcoded_constants.sh`** before generalizing. Identify the parameterizable bits (constant-name list, source directory, allow-list of legitimate hardcoded references like `_ENTITIES_JSON_PATH`).

2. **Approach A vs B trade-off**:
   - Approach A (parameterized) keeps DRY (one source of truth) but requires careful CLI arg validation
   - Approach B (template) is simpler to copy-customize per consumer but creates 4-5 near-duplicate scripts as adoption grows
   - Recommend Approach B for now (mirrors AC-DC-48's instance-per-system pattern + simpler CI wiring); revisit when 3+ consumers exist

3. **Constant-name list source of truth** — the damage-calc lint hardcodes the keys it grep-checks (BASE_CEILING, P_MULT_COMBINED_CAP, etc.). The template should document how to derive the list:
   - Option α: parse `balance_entities.json` keys at lint runtime (jq dependency; cleaner)
   - Option β: hardcode the per-consumer constant subset in each lint instance (duplication; explicit)
   - Recommend Option α IF jq is already in the CI runner (`.github/workflows/tests.yml`); otherwise β

4. **Silent-fail antipattern guard** (story-008 codified):
   ```bash
   # ANTIPATTERN — bash aborts before the if-check runs
   matches=$(grep ... 2>/dev/null) || true
   if [ -n "$matches" ]; then
       # may never reach here if grep crashed
   fi

   # CORRECT — distinguish tool-crash (exit ≥2) from domain-fail (exit 1)
   if ! matches=$(grep -rn "PATTERN" "$SOURCE_DIR" 2>&1); then
       exit_code=$?
       if [ "$exit_code" -gt 1 ]; then
           echo "TOOL ERROR: grep exited with $exit_code" >&2
           exit 2
       fi
       # exit 1 = grep no-match, which is the PASS case for a "must not exist" lint
   fi
   ```

5. **Foundation-layer scope (AC-3)**:
   - `src/foundation/unit_role.gd` already uses `BalanceConstants.get_const(key)` for class-direction tables (per ADR-0009 + unit-role epic story-005)
   - `src/foundation/balance/balance_constants.gd` itself contains the constants by definition (the lint must allow-list this file or scope to "consumer" files only — i.e., everything OTHER than balance_constants.gd)
   - `src/foundation/hero_data.gd` (if present) is a Resource wrapper, no balance constants currently
   - Verify scope: `grep -l "BalanceConstants" src/foundation/` should return the expected consumer set

6. **CI wiring** — the existing damage-calc lint runs in `.github/workflows/tests.yml` under the gdunit4 job (per story-008 PR #68). New foundation-layer lint either: (a) extends the existing step to add a second invocation, or (b) adds a new step "Lint foundation-layer no hardcoded constants". Author choice; (a) is simpler.

7. **TG-1 (gh CLI fork-vs-upstream)** caveat carries forward — when this story's PR is opened, use `gh pr create --repo forty4/Claude-Code-Game-Studios --base main` per `.claude/rules/tooling-gotchas.md` TG-1.

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001/002**: file relocation + test suite extension
- **Story 004**: orphan-reference grep gate as a CI lint (different lint scope: this story is "no hardcoded constant values"; story 004 is "no orphan path references")
- **Future consumer adoption**: hp-status, turn-order, hero-database epics will instantiate the template per their own story files (this story documents the pattern; doesn't pre-implement for unwritten epics)

---

## QA Test Cases

*Lean mode — orchestrator-authored.*

**AC-1** (template extraction):
- Given: existing `lint_damage_calc_no_hardcoded_constants.sh`
- When: parameterizable bits are factored out per Approach A or B
- Then: a reusable artifact exists; the damage-calc lint either delegates to it (A) or is structurally a copy (B with explicit doc-comment cross-ref)
- Edge case: if Approach A introduces CLI arg parsing bugs, the existing damage-calc lint must continue passing — no regression tolerance

**AC-2** (damage-calc lint preserved):
- Given: pre-story state + post-story state
- When: `bash tools/ci/lint_damage_calc_no_hardcoded_constants.sh` runs against current `src/feature/damage_calc/`
- Then: exit 0 in both states; output identical or improved
- Edge case: if Approach A surfaces a previously-missed match, that's a separate bug-fix story, NOT a regression

**AC-3** (foundation-layer lint coverage):
- Given: `src/foundation/` consumers (`unit_role.gd`, post-relocation `balance_constants.gd`)
- When: the generalized lint runs against `src/foundation/` with appropriate allow-list
- Then: exit 0 OR documented scope-deferral with TODO + reason
- Edge case: `balance_constants.gd` itself MUST be allow-listed (the file BY DEFINITION contains the constants); without allow-list, the lint trivially fails

**AC-4** (CI wiring):
- Given: `.github/workflows/tests.yml` post-edit
- When: GitHub Actions runs the workflow on a PR
- Then: the lint step appears in the workflow log with explicit pass/fail status
- Edge case: a `set -euo pipefail` antipattern in the script causes silent failure — verify AC-5's documentation reads true by intentionally injecting a `false` exit and observing CI's red status

**AC-5** (template documentation):
- Given: the template/parameterized script + README/doc-comment
- When: a future consumer (e.g., hp-status epic) reads the doc
- Then: they can instantiate a new lint with no prior context
- Edge case: doc completeness check — list AC-DC-48 origin, parameterization mechanism, silent-fail antipattern, exit-code convention (0 pass / 1 domain fail / ≥2 tool fail)

**AC-6** (smoke check evidence):
- Given: full lint runs from the story
- When: results are captured in `production/qa/smoke-balance-data-story-003-YYYY-MM-DD.md`
- Then: each lint invocation reports its exit code, the directories scanned, and the constants checked
- Edge case: if a lint is "documented scope-deferred", the smoke doc explicitly notes which consumer + why

**AC-7** (regression PASS):
- Given: post-story state
- When: full GdUnit4 regression runs
- Then: ≥501 baseline maintained; this story does not touch test code or production code paths
- Edge case: any test failure surfaced post-story is a separate bug, not a regression of this story (since this story doesn't touch test/production code)

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- `production/qa/smoke-balance-data-story-003-YYYY-MM-DD.md` — smoke check documenting lint runs
- Reusable lint template/parameterized script in `tools/ci/`
- `.github/workflows/tests.yml` updated to invoke generalized lint

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None (independent of stories 001 + 002 — could parallelize, but recommended to land after Story 001 so foundation-layer scope (AC-3) targets the post-move location)
- Unlocks: future consumer adoption in hp-status / turn-order / hero-database / input-handling epics
