# Story 004: Orphan reference grep gate + Validation §1-§5 audit

> **Epic**: Balance/Data
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Config/Data
> **Estimate**: 1.5-2h (new lint script + 6-section evidence doc + CI wiring; +AC-1 self-injection negative test)
> **Manifest Version**: 2026-04-20

## Context

**GDD**: `design/gdd/balance-data.md`
**Requirement**: ADR-0006 §Validation Criteria §1-§5 consolidated audit (orphan-reference grep gate as recurring CI lint; complements TR-balance-data-017 part 2 — file-rename verification)

*(Requirement text lives in `docs/architecture/tr-registry.yaml` — read fresh at review time)*

**ADR Governing Implementation**: ADR-0006 — Balance/Data — BalanceConstants Singleton (MVP scope)
**ADR Decision Summary**: §Validation §5 — `grep -r "entities.json" src/ tools/ docs/` returns 0 matches post-rename (excluding `balance_entities.json` matches and historical references in completed story-006b documentation).

**Engine**: Godot 4.6 | **Risk**: LOW
**Engine Notes**: bash + grep only; no GDScript work. Watch for **damage-calc story-008 silent-fail antipattern** when capturing grep output. Watch for **TG-1 gh CLI fork-vs-upstream** at PR-creation time.

**Control Manifest Rules (Foundation layer)**:
- Required: every same-patch obligation in an Accepted ADR's §Validation Criteria has a recurring verification path (CI lint OR test); one-time validations decay to fiction
- Forbidden: silent lint failures (capture-and-check antipattern); allow-listing without explicit rationale
- Guardrail: lint exit codes distinguish tool-failure (≥2) from domain-failure (1)

---

## Acceptance Criteria

*From ADR-0006 §Validation §1-§5, scoped to this story:*

- [ ] **AC-1** (orphan path lint): a CI lint script `tools/ci/lint_no_orphan_balance_data_paths.sh` fails the build if either of these patterns appear in `src/`, `tests/` (excluding intentional historical `production/epics/damage-calc/story-006b-*.md`-style refs), or `tools/`:
  - `res://src/feature/balance/` (orphan post-Story-001-relocation path)
  - `res://assets/data/balance/entities.json` (without the `balance_` prefix; orphan pre-rename path per ADR-0006 §Validation §5)
- [ ] **AC-2** (validation §1 evidence): full GdUnit4 regression PASS captured in evidence doc post-Story-001 + Story-003 landing — confirms ADR-0006 §Validation §1 ("All ratified consumers PASS regression")
- [ ] **AC-3** (validation §2 audit): every existing lint script under `tools/ci/lint_*.sh` is grep-audited for `entities.json` (without prefix) string-literals; any orphan reference is updated in same patch as this story OR documented as a known-orphan with rationale
- [ ] **AC-4** (validation §3 audit): same-patch documentation obligations from delta #9 verified present post-hoc:
  - `data-files.md` Constants Registry Exception subsection exists
  - ADR-0008 §Ordering Note has cross-ref to ADR-0006 (no "soft / provisional" qualifier)
  - ADR-0012 §Dependencies has cross-ref to ADR-0006 (no "soft / provisional" qualifier)
  - `docs/registry/architecture.yaml` line 262 + 573-574 ratified per ADR-0006 §Migration Plan §3
- [ ] **AC-5** (validation §4 audit): TD-041 entry exists in `docs/tech-debt-register.md` (this AC verifies presence; Story-005 is responsible for ADDING it if missing — coordination via Implementation Notes)
- [ ] **AC-6** (validation §5 grep gate): the AC-1 lint runs against current state, returns exit 0 (no orphans); evidence captured in `production/qa/evidence/balance-data-validation-audit-YYYY-MM-DD.md`
- [ ] **AC-7** (CI wiring): `.github/workflows/tests.yml` invokes `lint_no_orphan_balance_data_paths.sh` in the gdunit4 job (same lane as the existing AC-DC-44 F-GB-PROV lint)
- [ ] **AC-8** (regression PASS): full regression maintains baseline; new CI lint exits 0; evidence doc references the lint runs + their pass/fail status

---

## Implementation Notes

*Derived from ADR-0006 §Validation Criteria + AC-DC-44 F-GB-PROV lint precedent (`tools/ci/lint_fgb_prov_removed.sh`):*

1. **Lint script structure** — model on `tools/ci/lint_fgb_prov_removed.sh` (AC-DC-44 from damage-calc story-007 PR #67):
   - `set -euo pipefail` + the `if ! var=$(cmd 2>&1); then exit_code=$?; fi` pattern (story-008 codified antipattern fix)
   - Two grep invocations (one per orphan pattern); aggregate results
   - Allow-list explicit historical references via inline regex exclusions or a `KNOWN_ORPHANS` array
   - Exit codes: 0 pass, 1 domain (orphan found), ≥2 tool failure
   - Anti-self-trigger: the lint script itself must not contain the orphan string literal it grep-checks for; use fragment concatenation (`"res://" + "src/feature/balance/"`) per `lint_fgb_prov_removed.sh` precedent

2. **AC-3 audit method**:
   ```bash
   grep -rn "entities\.json" tools/ci/lint_*.sh | grep -v "balance_entities\.json"
   ```
   Output should be empty post-delta-#9. If non-empty, either fix the lint script or document the legitimate exception (e.g., a comment block referencing the historical name).

3. **AC-4 audit method** (one-shot verification at story execution):
   ```bash
   # Constants Registry Exception subsection
   grep -n "Constants Registry Exception" .claude/rules/data-files.md
   # ADR-0008 cross-ref
   grep -n "ADR-0006" docs/architecture/ADR-0008-terrain-effect.md
   # ADR-0012 cross-ref
   grep -n "ADR-0006" docs/architecture/ADR-0012-damage-calc.md
   # architecture.yaml ratification
   grep -nE "(line 262|line 573|line 574|ADR-0006)" docs/registry/architecture.yaml
   ```
   Each should return matches; missing matches indicate same-patch obligations from delta #9 didn't fully land.

4. **AC-5 coordination with Story-005** — TD-041 logging is THIS story's verify gate, but the actual TD entry is added by Story-005 per its scope. If Story-005 lands first, AC-5 here is a trivial pass. If Story-004 lands first, the TD-041 verification fails and the story is BLOCKED until Story-005 (or an equivalent fix) lands. Document the dependency in §Dependencies; recommend ordering 005 before 004 if planning sequentially.

5. **Anti-self-trigger pattern** for the lint script (AC-1):
   ```bash
   # ANTIPATTERN — script contains the literal it greps for; lint will match itself
   ORPHAN_PATTERN="res://src/feature/balance/"
   grep -rn "$ORPHAN_PATTERN" src/ tests/ tools/

   # CORRECT — fragment concatenation prevents self-trigger
   ORPHAN_PATTERN="res://src/feature/" "balance/"
   # OR explicit self-exclusion
   grep -rn "..." src/ tests/ tools/ | grep -v "lint_no_orphan_balance_data_paths.sh"
   ```

6. **Allow-list for historical refs** — production markdown files in `production/epics/damage-calc/story-006b*.md` and similar archive content legitimately reference the pre-rename `entities.json` and pre-relocation `src/feature/balance/`. The lint MUST NOT scan `production/`; scope to `src/`, `tests/`, `tools/`. Code comments in source files referencing the historical path are debatable — recommend updating them in the same patch as the lint introduction (Story-001's AC-3 covers the source-header doc comment, so by the time Story-004 lands, only legitimately-historical markdown refs remain).

7. **Evidence doc structure** — `production/qa/evidence/balance-data-validation-audit-YYYY-MM-DD.md`:
   - §1 Validation §1 — full regression result (count + 0 errors / 0 failures / 0 orphans)
   - §2 Validation §2 — lint scripts audit table (every `lint_*.sh` + its `entities.json` references status)
   - §3 Validation §3 — same-patch doc obligations checklist (4 items)
   - §4 Validation §4 — TD-041 entry presence verification
   - §5 Validation §5 — orphan grep gate run + result
   - §6 CI wiring evidence — workflow yml diff + first run log

---

## Out of Scope

*Handled by neighbouring stories — do not implement here:*

- **Story 001**: file relocation (this story's AC-1 verifies the post-relocation state; doesn't perform the move)
- **Story 002**: TR-traced test suite (this story's AC-2 verifies regression PASS; doesn't extend tests)
- **Story 003**: per-system hardcoded-constant lint template (different lint scope: hardcoded-value detection vs orphan-path detection)
- **Story 005**: TD-041 entry creation (this story verifies presence; Story-005 creates it)
- **Reactivation of Alpha-deferred TRs**: 13 PARTIAL TRs in tr-registry.yaml stay PARTIAL until future Alpha-tier "DataRegistry Pipeline" ADR; this story does not implement any of those features

---

## QA Test Cases

*Lean mode — orchestrator-authored.*

**AC-1** (orphan path lint):
- Given: clean post-Story-001 state
- When: `bash tools/ci/lint_no_orphan_balance_data_paths.sh`
- Then: exit 0; no output OR purely informational output
- Edge case: intentionally introduce a `res://src/feature/balance/` reference in `src/` and re-run; lint must exit 1 with clear domain-fail message; remove the test reference before merging

**AC-2** (validation §1 regression):
- Given: post-Story-001 + post-Story-003 state
- When: full GdUnit4 regression `godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd --ignoreHeadlessMode -a res://tests/unit -a res://tests/integration -c`
- Then: ≥501 baseline + new tests from Story-002 + Story-005 (when those stories also land); 0 errors / 0 failures / 0 orphans
- Edge case: G-7 silent-skip — verify Overall Summary count

**AC-3** (lint scripts audit):
- Given: `tools/ci/lint_*.sh` files
- When: `grep -rn "entities\.json" tools/ci/lint_*.sh | grep -v "balance_entities\.json"`
- Then: empty output (or explicit legitimate-historical-comment exceptions)
- Edge case: a future lint script intended to detect the OLD pattern would intentionally contain it; mark explicitly with comment

**AC-4** (same-patch doc obligations):
- Given: post-delta-#9 state
- When: 4 grep verifications run
- Then: each returns matches confirming the obligation landed
- Edge case: missing match indicates delta #9 didn't fully land; story is BLOCKED on the missing item being added

**AC-5** (TD-041 verification):
- Given: post-Story-005 state (recommended ordering)
- When: `grep -n "TD-041" docs/tech-debt-register.md`
- Then: at least 1 match with full TD entry below
- Edge case: if AC-5 fails because Story-005 hasn't landed yet, this story is BLOCKED until Story-005 closes; document the dependency in close-out

**AC-6** (validation §5 grep gate run):
- Given: clean post-state
- When: AC-1 lint runs in evidence doc context
- Then: exit 0; evidence doc captures the run command + output
- Edge case: edge case from AC-1 (intentional injection) is not run during evidence capture

**AC-7** (CI wiring):
- Given: `.github/workflows/tests.yml` post-edit
- When: GitHub Actions runs the workflow on a PR
- Then: the new lint step appears in the workflow log; passes
- Edge case: TG-1 gh CLI fork-vs-upstream — use `gh pr create --repo forty4/Claude-Code-Game-Studios --base main`

**AC-8** (regression + evidence):
- Given: full story complete
- When: evidence doc reviewed
- Then: all 6 §sections populated; no TODO placeholders remain
- Edge case: if §3 (same-patch obligations) finds a missing item, the story is BLOCKED — patch the gap before merging

---

## Test Evidence

**Story Type**: Config/Data
**Required evidence**:
- `production/qa/evidence/balance-data-validation-audit-YYYY-MM-DD.md` — 6-section evidence doc
- `tools/ci/lint_no_orphan_balance_data_paths.sh` — new CI lint script
- `.github/workflows/tests.yml` updated with new lint step

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on:
  - Story 001 (file relocation; AC-1's `res://src/feature/balance/` orphan check requires the move to have happened)
  - Story 005 (TD-041 entry; AC-5 verification needs the entry to exist) — recommend ordering 005 BEFORE 004 OR landing both together
- Unlocks: None (terminal in the validation-audit path)
