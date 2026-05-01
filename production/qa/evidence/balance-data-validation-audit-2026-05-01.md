# Balance/Data Validation §1-§5 Audit — 2026-05-01

> **Story**: `production/epics/balance-data/story-004-orphan-grep-validation-audit.md` (TR-balance-data-017 part 2 + ADR-0006 §Validation §1-§5)
> **Type**: Config/Data
> **Date**: 2026-05-01
> **ADR**: ADR-0006 (Balance/Data — BalanceConstants Singleton; Accepted 2026-04-30 via /architecture-review delta #9)
> **Manifest Version**: 2026-04-20

---

## §1 — Validation §1 (regression PASS post-Story-001 + Story-002 + Story-003 + Story-005)

Command:
```
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --ignoreHeadlessMode -a res://tests/unit -a res://tests/integration -c
```

Result (2026-05-01):
```
Overall Summary: 506 test cases | 0 errors | 1 failures | 0 flaky | 0 skipped | 0 orphans
Total execution time: 5s 285ms
```

**Test count delta vs sprint-2 baseline**: +5 cases since story-001 entry (501 → 506):
- story-002 added 3 tests in `balance_constants_test.gd` (TR-013/019/020)
- story-005 added 2 tests in `balance_constants_perf_test.gd` (TR-015 a/b)
- story-001 + story-003 + story-004 added zero test cases (pure data/path/config work)

**G-7 silent-skip check**: `grep -ac "Parse Error\|Failed to load"` returned `0` — zero parse failures; the test count is the actual count, not a silent-skip artifact.

**Pre-existing failure** (NOT introduced by this story; orthogonal):
- `tests/unit/foundation/unit_role_skeleton_test.gd::test_hero_data_doc_comment_contains_required_strings` — same carried-forward failure documented in story-001/002/005 closeouts. Asserts `src/foundation/hero_data.gd` contains literal `"ADR-0009 §Migration Plan §3"`; the file does not contain this exact phrase. Story-004 made zero edits to `hero_data.gd` (verified by `git diff --stat`). Recommend triage as a follow-up hotfix story OR during unit-role epic close-out.

**AC-2 + AC-8 verdict**: regression baseline maintained at 506/0/1/0/0; story-004 introduced zero new test failures. PASS.

---

## §2 — Validation §2 (lint scripts entities.json audit)

Audit command:
```
grep -rn "entities\.json" tools/ci/lint_*.sh | grep -v "balance_entities\.json"
```

Result (2026-05-01):
```
(no matches — clean)
```

| Lint script | Unprefixed `entities.json` refs | Status |
|---|---|---|
| `lint_damage_calc_no_apply_damage.sh` | 0 | PASS |
| `lint_damage_calc_no_dictionary_alloc.sh` | 0 | PASS |
| `lint_damage_calc_no_hardcoded_constants.sh` | 0 | PASS |
| `lint_damage_calc_no_signals.sh` | 0 | PASS |
| `lint_damage_calc_no_stub_copy.sh` | 0 | PASS |
| `lint_damage_calc_sole_entry_point.sh` | 0 | PASS |
| `lint_enum_append_only.sh` | 0 | PASS |
| `lint_fgb_prov_removed.sh` | 0 | PASS |
| `lint_foundation_balance_no_hardcoded_constants.sh` | 1 (in comment, prefix-safe) | PASS — see note |
| `lint_no_hardcoded_balance_constants.sh.template` | 0 | PASS |
| `lint_no_orphan_balance_data_paths.sh` (NEW) | 0 (fragment-concat per anti-self-trigger) | PASS |
| `lint_per_frame_emit.sh` | 0 | PASS |
| `lint_save_paths.sh` | 0 | PASS |
| `lint_unit_role.sh` | 0 | PASS |

Note: the one match in `lint_foundation_balance_no_hardcoded_constants.sh` is `assets/data/balance/balance_entities.json` in a comment block — properly prefixed live URI, not orphan. The `grep -v "balance_entities\.json"` filter correctly excludes it.

**AC-3 verdict**: zero unprefixed `entities.json` references in any `tools/ci/lint_*.sh` script. PASS.

---

## §3 — Validation §3 (delta #9 same-patch obligations verification)

| Obligation | Verification | Status |
|---|---|---|
| `.claude/rules/data-files.md` Constants Registry Exception subsection | `grep -n "Constants Registry Exception" .claude/rules/data-files.md` → `50:## Constants Registry Exception (named scope only)` | ✅ PRESENT |
| ADR-0008 §Ordering Note → ADR-0006 cross-ref (no "soft / provisional") | line 35 RATIFIED + lines 44, 210, 212, 213 (delta #9 wording flips) — all qualify as "Accepted 2026-04-30 via delta #9" or "RATIFIED" | ✅ PRESENT |
| ADR-0012 §Dependencies → ADR-0006 cross-ref (no "soft / provisional") | line 42 RATIFIED + lines 45, 344, 346, 438 (delta #9 wording flips) — "RATIFIED" / "Accepted 2026-04-30 via delta #9" | ✅ PRESENT |
| `docs/registry/architecture.yaml` ADR-0006 ratified | 7 references (changelog block lines 34-45 + body entries lines 239, 280, 286) | ✅ PRESENT |

All 4 same-patch obligations from /architecture-review delta #9 are landed. **AC-4 verdict**: PASS.

---

## §4 — Validation §4 (TD-041 entry presence)

Audit command:
```
grep -n "TD-041" docs/tech-debt-register.md
```

Result (2026-05-01):
```
2260:## TD-041 — `BalanceConstants.get_const(key) -> Variant` typed-accessor refactor (ADR-0006 forward TD)
2301:4. Update ADR-0006 §Decision #2 (Public API) to list the typed accessors; cross-reference TD-041 as resolved (PR #XXX).
```

TD-041 entry exists at `docs/tech-debt-register.md:2260`, with a full TD entry below covering the typed-accessor refactor. Story-005 confirmed the entry pre-existed (added at ADR-0006 acceptance 2026-04-30) and only fixed 2 stale paths post-Story-001 relocation.

**AC-5 verdict**: PASS.

---

## §5 — Validation §5 (orphan grep gate run)

### Pre-write audit (verifying clean baseline before lint introduction)

Pattern 1 — pre-relocation URI:
```
$ grep -rn "res://src/feature/balance" src/ tests/ tools/ 2>/dev/null
(no matches)
```

Pattern 2 — pre-rename URI (literal URI form):
```
$ grep -rnF "res://assets/data/balance/entities.json" src/ tests/ tools/ 2>/dev/null
(no matches)
```

Note on Pattern 2 scope: the AC-1 spec targets the LITERAL `res://assets/data/balance/entities.json` URI form, not the broader noun `entities.json`. Generic doc-comment references in source code (e.g., "the entities.json file" in `balance_constants.gd`, `damage_calc.gd`, and various test files) are conversational uses of the filename, not URI references, and are out of scope by AC-1 design.

### Post-write lint run (the canonical AC-6 gate)

```
$ bash tools/ci/lint_no_orphan_balance_data_paths.sh
lint_no_orphan_balance_data_paths: PASS (0 orphan URIs in src/, tests/, tools/)
$ echo $?
0
```

**AC-1 + AC-6 verdict**: PASS.

### AC-1 negative-path manual verification (lint must catch real orphans)

Per the AC-1 test cases edge case ("intentionally introduce a `res://src/feature/balance/` reference in `src/` and re-run; lint must exit 1 with clear domain-fail message"):

```
$ # 1. Inject a fixture file with literal orphan URIs
$ cat > src/foundation/balance/__lint_self_test.gd <<'EOF'
# Test fixture - DO NOT MERGE
const _ORPHAN_FEATURE: String = "res://src/feature/balance/foo.gd"
const _ORPHAN_DATA: String = "res://assets/data/balance/entities.json"
EOF

$ # 2. Run lint with orphans present
$ bash tools/ci/lint_no_orphan_balance_data_paths.sh
::error::lint_no_orphan_balance_data_paths: pre-relocation URI found -- TR-balance-data-017 violation
src/foundation/balance/__lint_self_test.gd:2:const _ORPHAN_FEATURE: String = "res://src/feature/balance/foo.gd"

::error::lint_no_orphan_balance_data_paths: pre-rename data URI found -- TR-balance-data-017 violation
src/foundation/balance/__lint_self_test.gd:3:const _ORPHAN_DATA: String = "res://assets/data/balance/entities.json"

Resolution:
  - Replace pre-relocation URI fragment with res://src/foundation/balance/ (post-story-001 layer).
  - Replace pre-rename URI fragment with res://assets/data/balance/balance_entities.json (post-ADR-0006-§Decision-4 prefix).
Reference: ADR-0006 §Validation Criteria §5; balance-data story-001 (relocation); story-004 (this lint).
$ echo $?
1

$ # 3. Cleanup
$ rm src/foundation/balance/__lint_self_test.gd

$ # 4. Re-run after cleanup
$ bash tools/ci/lint_no_orphan_balance_data_paths.sh
lint_no_orphan_balance_data_paths: PASS (0 orphan URIs in src/, tests/, tools/)
$ echo $?
0
```

Negative-path verified: lint correctly returns exit 1 (domain-fail) when literal orphan URIs are introduced, returns exit 0 (clean) after removal. Both error patterns flagged with clear resolution guidance. The test fixture was deleted after verification and is NOT present in the working tree.

**Process insight**: first injection attempt used fragment concatenation (`"res:" + "//src/feature/balance/foo.gd"`) — same anti-self-trigger trick the lint itself uses. The lint correctly did NOT match the fragmented form. Re-ran with literal URIs (no fragments) to simulate a real-world orphan reference; lint caught both. Lesson: anti-self-trigger via fragment-concat in the lint script is structurally sound, but injection tests must use literal URIs to validate the lint's positive-detection path.

---

## §6 — CI wiring evidence

`.github/workflows/tests.yml` updated — 3 lines inserted in the `gdunit4` job after the `lint_foundation_balance_no_hardcoded_constants.sh` step (TR-balance-data-010 / story-003 AC-3) and before the `lint_fgb_prov_removed.sh` step (AC-DC-44 TR-damage-calc-009):

```yaml
      - name: Lint Foundation Balance no hardcoded constants (TR-balance-data-010 / story-003 AC-3)
        run: bash tools/ci/lint_foundation_balance_no_hardcoded_constants.sh

      - name: Lint no orphan balance-data paths (TR-balance-data-017 / story-004 AC-1)    # NEW
        run: bash tools/ci/lint_no_orphan_balance_data_paths.sh                            # NEW
                                                                                            # (blank line — NEW)
      - name: Lint provisional formula retired (AC-DC-44 TR-damage-calc-009)
        run: bash tools/ci/lint_fgb_prov_removed.sh
```

Insertion position rationale: same lane as other balance-data lints (story-003's foundation-hardcoded-constants lint immediately precedes; the new step keeps balance-data linting grouped before damage-calc-specific lints).

First CI run will be triggered by the merge of this story's PR. Per TG-1 (`.claude/rules/tooling-gotchas.md`), PR creation MUST use `gh pr create --repo forty4/Claude-Code-Game-Studios --base main` to avoid the gh-CLI fork-vs-upstream auto-detection trap.

**AC-7 verdict**: PASS (CI step wired; first-run validation deferred to PR merge).

---

## AC summary

| AC | Description | Status | Evidence |
|---|---|---|---|
| AC-1 | Orphan path lint script created with 2 patterns + anti-self-trigger | ✅ PASS | `tools/ci/lint_no_orphan_balance_data_paths.sh`; §5 negative-path verification |
| AC-2 | Validation §1 regression PASS post-Story-001 + Story-003 | ✅ PASS | §1 (506/0/1/0/0; 1 failure pre-existing orthogonal) |
| AC-3 | Validation §2 lint scripts entities.json audit | ✅ PASS | §2 (14 scripts audited; 0 unprefixed refs) |
| AC-4 | Validation §3 delta-#9 same-patch doc obligations verified | ✅ PASS | §3 (4-row checklist all PRESENT) |
| AC-5 | Validation §4 TD-041 entry presence verified | ✅ PASS | §4 (line 2260 — pre-existing per Story-005) |
| AC-6 | Validation §5 orphan grep gate run + exit 0 | ✅ PASS | §5 (pre-write audit clean + post-write lint exit 0) |
| AC-7 | CI wiring — workflow yml step added | ✅ PASS | §6 (3-line insert in gdunit4 job) |
| AC-8 | Regression maintains baseline + new lint exits 0 | ✅ PASS | §1 (506/0/1/0/0 maintained) + §5 (lint exit 0) |

**All 8 acceptance criteria satisfied. Epic terminal step ready for close-out.**

---

## Out-of-scope items confirmed not addressed (per story `## Out of Scope`)

- ✅ Story-001 file relocation: NOT performed by this story; AC-1's `res://src/feature/balance/` orphan check verifies post-relocation state.
- ✅ Story-002 TR-traced test suite: NOT extended; this story does not touch test files.
- ✅ Story-003 hardcoded-constant lint template: separate lint scope; this lint targets URI orphans, not value hardcoding.
- ✅ Story-005 TD-041 entry creation: NOT created here; this story verifies presence only.
- ✅ Alpha-deferred TR reactivation: 13 PARTIAL TRs in `tr-registry.yaml` remain PARTIAL; this story does not touch them.

---

## Files changed in this story

1. **NEW** `tools/ci/lint_no_orphan_balance_data_paths.sh` (~95 LoC; bash + grep; AC-1)
2. **MODIFIED** `.github/workflows/tests.yml` (+3 lines; AC-7 CI wiring)
3. **NEW** `production/qa/evidence/balance-data-validation-audit-2026-05-01.md` (this file; 6-section evidence doc per AC-6 + AC-8)

Zero production code changes. Zero test file changes. Zero design doc changes (all delta-#9 obligations were already landed at ADR-0006 acceptance time).

---

## Tooling-gotcha references applied this story

- **TG-1** (gh CLI fork-vs-upstream): noted in §6 for PR-creation step (deferred to /story-done close-out).
- **G-7** (silent-skip on parse error): applied in §1 — verified `Overall Summary` count (506 cases) AND grep'd for `Parse Error` (zero) instead of relying on exit code alone (which is 100 due to the 1 carried-forward failure).
- **story-008 silent-fail antipattern**: applied in lint script — uses `2>/dev/null || true` capture pattern + explicit exit-code triage (0/1/≥2 distinction documented in script header).
- **story-005 anti-self-trigger discipline**: applied in lint script via fragment concatenation; literal orphan URIs never appear in script source text.
