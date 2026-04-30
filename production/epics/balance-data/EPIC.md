# Epic: Balance/Data

> **Layer**: Foundation
> **GDD**: `design/gdd/balance-data.md` (Designed; ratified by ADR-0006)
> **Architecture Module**: BalanceConstants — Foundation-layer data infrastructure (`src/foundation/balance/balance_constants.gd` post-relocation)
> **Status**: Ready
> **Stories**: 5/5 created (2026-04-30) — see Stories table below
> **Manifest Version**: 2026-04-20 (`docs/architecture/control-manifest.md`)
> **Created**: 2026-04-30 (Sprint 2 S2-01)

## Stories

| # | Story | Type | Status | Governing ADR | Depends on |
|---|-------|------|--------|---------------|------------|
| 001 | [Foundation-layer relocation + import path audit](story-001-foundation-layer-relocation.md) | Integration | Ready | ADR-0006 | None (gates 002 + 005) |
| 002 | [TR-traced unit test suite extension](story-002-tr-traced-test-suite.md) | Logic | Ready | ADR-0006 | 001 |
| 003 | [Per-system hardcoded-constant lint template](story-003-hardcoded-constant-lint-template.md) | Config/Data | Ready | ADR-0006 | None (recommended after 001) |
| 004 | [Orphan reference grep gate + Validation §1-§5 audit](story-004-orphan-grep-validation-audit.md) | Config/Data | Ready | ADR-0006 | 001, 005 (TD-041 verification) |
| 005 | [Perf baseline + TD-041 logging](story-005-perf-baseline-td041.md) | Logic | Ready | ADR-0006 | 001 |

**Stories total**: 5 — 2 Logic, 1 Integration, 2 Config/Data.

**Implementation order**: **001 → {002, 003, 005 parallel} → 004** (004 verifies TD-041 from 005 + post-Story-001 orphan grep). Story 003 is independent and can land any time after 001.

**AC coverage**: 7 MVP-COVERED TRs (007, 010, 016, 017, 018, 019, 020) all assigned across the 5 stories. 13 Alpha-deferred TRs remain documented in EPIC.md but no stories created (BY DESIGN per ADR-0006 §7).

## Overview

Balance/Data is the Foundation-layer data infrastructure that loads balance constants from `assets/data/balance/balance_entities.json` and exposes them via `BalanceConstants.get_const(key) -> Variant`. It enforces the project-wide "no hardcoded balance values in `.gd` source" rule (CR-10) by providing the canonical access path that consumers (damage_calc, terrain_config, future hp-status, turn-order, hero-database) call into.

This is a **ratification epic**: ADR-0006 was authored AFTER the shipped MVP wrapper landed in damage-calc story-006b PR #65 (2026-04-27). Ten downstream stories across 2 epics (terrain-effect + damage-calc) have already exercised the pattern through 388/388 GdUnit4 regression. Same-patch ratification obligations from `/architecture-review` delta #9 (commit `2fa178b`, 2026-04-30) are already complete: file rename `entities.json` → `balance_entities.json`, const path update, `data-files.md` Constants Registry Exception subsection, ADR-0008/ADR-0012 same-patch ratification cross-refs, and architecture.yaml registry updates.

The remaining epic scope is **(a) layer correctness** — relocating the module from `src/feature/balance/` to `src/foundation/balance/` per architecture.md layer invariants — and **(b) validation hardening**: TR-traced test suite, perf baseline, orphan-reference grep gate, reusable per-system lint template, and TD-041 (typed-accessor refactor) tracked as forward tech debt.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| **ADR-0006: Balance/Data — BalanceConstants Singleton MVP scope** (Accepted 2026-04-30) | Stateless static utility class `class_name BalanceConstants extends RefCounted` (NOT autoload-registered); single public static method `get_const(key: String) -> Variant`; lazy on-first-call loading via `FileAccess.get_file_as_string()` + `JSON.parse_string()`; flat JSON format with UPPER_SNAKE_CASE keys (documented `data-files.md` exception for grep-ability); idempotent `_cache_loaded: bool` guard. Ratifies shipped MVP wrapper; defers 7 GDD Core Rules (CR-2/3/4/5/6/8/9) to future Alpha-tier "DataRegistry Pipeline" ADR. | **LOW** — `FileAccess.get_file_as_string()` pre-Godot-4.4 stable; `JSON.parse_string()` pre-Godot-4.0 stable; static `class_name` + static vars + RefCounted pre-cutoff stable. The only post-cutoff change in this domain is `FileAccess.store_*` returning `bool` (Godot 4.4) — this ADR does NOT use the write path. |

## GDD Requirements

20 TRs registered via `/architecture-review` delta #9 (2026-04-30). All traced to ADR-0006. **Zero untraced**.

### MVP-COVERED (7 TRs — Sprint 2 acceptance criteria)

| TR-ID | Requirement (excerpt) | ADR Coverage |
|-------|-----------------------|--------------|
| TR-balance-data-007 | AC-07 — All registered keys accessible via `get_const(key)`; `balance_entities.json` 22+ keys (51 post-ADR-0010/0011 same-patch appends) | ADR-0006 §Decision 2 ✅ |
| TR-balance-data-010 | AC-10 — Hardcoding ban enforced via lint pattern (AC-DC-48 precedent) | ADR-0006 §Decision 7 ✅ |
| TR-balance-data-016 | Module Form: `class_name BalanceConstants extends RefCounted` stateless static utility class; NOT autoload-registered | ADR-0006 §Decision 1 ✅ |
| TR-balance-data-017 | Data file rename + flat format + UPPER_SNAKE_CASE keys exception | ADR-0006 §Decision 3-5 ✅ |
| TR-balance-data-018 | Constants Registry Exception subsection in `.claude/rules/data-files.md` | ADR-0006 §Migration Plan §4 ✅ |
| TR-balance-data-019 | Lazy on-first-call loading + `_cache_loaded: bool` idempotent guard | ADR-0006 §Decision 6 ✅ |
| TR-balance-data-020 | G-15 test-isolation discipline — `before_test()` cache reset mandatory | ADR-0006 §Decision 6 + G-15 ✅ |

### Alpha-DEFERRED (13 TRs — BY DESIGN, NOT a gap)

Per ADR-0006 §7, the following GDD Core Rules + ACs reactivate when a future Alpha-tier "DataRegistry Pipeline" ADR is authored. **MVP scope intentionally narrows from full GDD pipeline.** No story files in this epic.

| TR-ID | Requirement (excerpt) | Defer Reason |
|-------|-----------------------|--------------|
| TR-balance-data-001 | AC-01 — READY-prior consumer access blocked | CR-4 4-phase pipeline state machine deferred |
| TR-balance-data-002 | AC-02 — 9-category Discovery scan with per-category logging | CR-2 9-category registry deferred (only `balance_constants` exists in MVP) |
| TR-balance-data-003 | AC-03 — JSON envelope `{schema_version, category, data}` FATAL on missing fields | CR-3 envelope deferred (flat ratified for MVP) |
| TR-balance-data-004 | AC-04 — Phase 4 (Build) FATAL-free completion gates downstream consumer init | CR-4 4-phase pipeline deferred |
| TR-balance-data-005 | AC-05 — ERROR-level partial rejection (severity-2 records rejected) | CR-5 4-tier severity classification deferred |
| TR-balance-data-006 | AC-06 — 3 access patterns (direct lookup / filtered query / constant access) | CR-6 3-pattern access deferred (only `constant_access` ratified) |
| TR-balance-data-008 | AC-08 — schema_version below MINIMUM_SCHEMA_VERSION rejected with FATAL | CR-3 envelope deferred (no schema_version field in MVP) |
| TR-balance-data-009 | AC-09 — Hot Reload disabled in release builds (HOT_RELOAD_ENABLED toggle) | CR-9 hot reload deferred (game restart suffices for MVP) |
| TR-balance-data-011 | AC-F1 — F-1 Schema Compatibility 4-case correctness | CR-3 envelope deferred (F-1 has no MVP applicability) |
| TR-balance-data-012 | AC-F2 — F-2 Validation Coverage Rate (VCR) CI gate | CR-5 severity tiers deferred (VCR depends on severity-2 mechanism) |
| TR-balance-data-013 | AC-EC1 — Empty file → severity-3 FATAL with file path | No severity-3 FATAL classification in MVP (push_error + null is MVP equivalent) |
| TR-balance-data-014 | AC-EC9 — Circular cross-reference detection (DFS) | CR-5 severity tiers + CR-4 Phase 3 Validate deferred (flat constants registry has no cross-refs) |
| TR-balance-data-015 | AC-PERF — `initialize()` to READY ≤ 5000 ms PIPELINE_TIMEOUT_MS | CR-4 pipeline init phase deferred (lazy on-first-call has no init phase to timeout) |

## Epic Scope — Residual Work (post same-patch ratification)

Same-patch ratification obligations from ADR-0006 §Migration Plan are **already complete** via `/architecture-review` delta #9 (commit `2fa178b`):

- ✅ File rename `assets/data/balance/entities.json` → `balance_entities.json`
- ✅ `_ENTITIES_JSON_PATH` const updated in `balance_constants.gd`
- ✅ `data-files.md` Constants Registry Exception subsection
- ✅ ADR-0008 §Ordering Note ratification cross-ref
- ✅ ADR-0012 §Dependencies provisional qualifier dropped
- ✅ `docs/registry/architecture.yaml` line 262 + 573-574 ratified

**Residual epic scope** (the work `/create-stories` will decompose; ~5-6 stories estimated):

1. **Layer correctness** — relocate `src/feature/balance/balance_constants.gd` → `src/foundation/balance/balance_constants.gd` per architecture.md layer invariants (Foundation-layer module currently sits in `src/feature/`); update all consumer imports (damage_calc.gd ×8 sites, terrain_config.gd ×3 sites)
2. **Validation Criteria audit** — execute ADR-0006 §Validation §1-§5: 388/388 regression PASS post-relocation; `grep -r "entities.json" src/ tools/ docs/` returns 0 matches (excluding `balance_entities.json` matches and historical story-006b documentation references); lint-script audit
3. **TR-traced unit test suite** — promote/extend `tests/unit/balance/balance_constants_test.gd` to formally cover TR-007 / TR-016 / TR-017 / TR-019 / TR-020; add coverage for edge cases (TR-013 empty file precheck per godot-gdscript-specialist Item 4 advisory)
4. **Per-system lint template** — generalize `tools/ci/lint_damage_calc_no_hardcoded_constants.sh` (AC-DC-48 lint precedent) into a reusable per-system template for future consumers (TR-010 names hp-status / turn-order / terrain-effect as next adopters)
5. **Perf baseline** — TR-015 MVP-equivalent measurement (lazy-load first-call cost ~0.5-2ms target per ADR-0006 §Performance Implications); headless throughput test
6. **TD-041 logged** — typed-accessor refactor (`get_const_int` / `get_const_float` / `get_const_dict`) as forward tech debt entry per ADR-0006 §Decision 2 + §Migration Plan §5

## Definition of Done

This epic is complete when:

- All stories implemented, reviewed, and closed via `/story-done`
- All 7 MVP-COVERED TRs verified via passing tests in `tests/unit/balance/`
- 13 Alpha-deferred TRs explicitly documented as out-of-scope in their respective story files (no stories created for them)
- `BalanceConstants` relocated to `src/foundation/balance/` per architecture invariants
- Full regression suite ≥501 baseline maintained (per active.md unit-role epic close-out evidence)
- `grep -r "entities.json" src/ tools/ docs/` returns 0 unintended matches (orphan-reference gate)
- Per-system lint template extracted to reusable form
- TD-041 entry logged in `docs/tech-debt-register.md`
- ADR-0006 §Validation Criteria §1-§5 all green

## Sprint Mapping

| Sprint | Story IDs | Goal |
|--------|-----------|------|
| Sprint 2 | S2-01 (epic + stories) + S2-03 (implementation) | Epic created, ~5-6 stories scaffolded, all stories shipped to Complete |

## Next Step

Run `/create-stories balance-data` to break this epic into implementable stories.
