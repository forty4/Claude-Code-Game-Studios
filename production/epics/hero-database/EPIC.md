# Epic: Hero Database

> **Layer**: Foundation
> **GDD**: `design/gdd/hero-database.md` (Approved; ratified by ADR-0007)
> **Architecture Module**: HeroDatabase + HeroData — Foundation-layer data infrastructure (`src/foundation/hero_database.gd` to-be-created + `src/foundation/hero_data.gd` shipped 2026-04-28 under ADR-0009 §Migration Plan §3 soft-dep)
> **Status**: Ready
> **Stories**: 5/5 created (2026-05-01) — see Stories table below
> **Manifest Version**: 2026-04-20 (`docs/architecture/control-manifest.md`)
> **Created**: 2026-05-01 (Sprint 2 S2-02)

## Stories

| # | Story | Type | Status | Governing ADR | Depends on |
|---|-------|------|--------|---------------|------------|
| 001 | [HeroDatabase module skeleton + lazy-init + 6 query API](story-001-database-module-skeleton.md) | Logic | Ready | ADR-0007 | None (gates 002+003+004+005) |
| 002 | [Validation pipeline FATAL severity (CR-1 + CR-2 + EC-1 + EC-2)](story-002-validation-pipeline-fatal.md) | Integration | Ready | ADR-0007 | 001 |
| 003 | [MVP roster authoring (`heroes.json`) + happy-path integration test](story-003-mvp-roster-authoring.md) | Integration | Ready | ADR-0007 | 001, 002 |
| 004 | [Relationship WARNING tier (EC-4/5/6) + R-1 consumer-mutation regression](story-004-warning-tier-and-r1-mitigation.md) | Logic | Ready | ADR-0007 | 001, 002, 003 |
| 005 | [Perf baseline + non-emitter lint + Polish-tier validation lint scaffold](story-005-perf-baseline-lints-td-entry.md) | Config/Data | Ready | ADR-0007 + ADR-0001 + ADR-0006 | 001, 002, 003, 004 |

**Stories total**: 5 — 2 Logic, 2 Integration, 1 Config/Data.

**Implementation order**: **001 → 002 → 003 → {004, 005 parallel}** (story-005 lint scripts can land in parallel with story-004 once the test file inventory is stable; recommended to land 004 first so 005's G-15 grep gate scans the complete test corpus).

**TR coverage**: 15/15 traced to ADR-0007 — 11 MVP-runtime (TR-001..010 + TR-012..014) split across 5 stories; TR-011 (F-1..F-4) Polish-deferred via story-005 scaffold + tech-debt entry; TR-015 perf 10-hero baseline measured in story-005, 100-hero forward-compat extrapolation Polish-deferred.

**AC coverage**: 15/15 GDD ACs assigned — AC-01..AC-07 + AC-12..AC-15 across stories 001-004; AC-08..AC-11 Polish-deferred via story-005 lint scaffold per ADR-0007 §11 + N2 (5-precedent pattern).

## Overview

Hero Database is the Foundation-layer data infrastructure that defines the static
attributes of every playable 무장 (hero) in 천명역전: identity, faction, base
stats (might / intellect / command / agility), derived seeds (HP / initiative),
movement range, default class, growth rates, innate skills, scenario-join
conditions, and historical relationships. Six downstream systems — Unit Role,
HP/Status, Turn Order, Story Event, Character Growth, Equipment/Item — read
this catalog at battle preparation and during gameplay queries.

The system stores 8–10 hero records in MVP (Full Vision: 80–100), keyed in a
session-persistent `Dictionary[StringName, HeroData]` lazy-cache loaded from
`assets/data/heroes/heroes.json`. The 26-field `HeroData` Resource is
Inspector-authorable (all `@export`) and ResourceSaver-compatible. The
`HeroDatabase` static query layer exposes 6 read-only methods and is bound by
a strict no-mutation contract (R-1 mitigation: regression test asserts mutation
IS visible, proving convention is the only defense — `duplicate_deep()`
rejected for performance per §5).

This epic is a **build-from-scratch epic with one head-start**: ADR-0007's
§Migration Plan §1 (extend provisional `hero_data.gd` from 10 fields to 26)
already shipped same-patch with ADR-0007 acceptance 2026-04-30; the
`HeroDatabase` static query layer + `heroes.json` roster + test suites + Polish
lint scaffold remain. Pattern-wise, this is the **5th-precedent stateless-static
utility class** (ADR-0008 → 0006 → 0012 → 0009 → 0007); pattern is now
load-bearing project discipline for Foundation/Core data-layer ADRs.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| **ADR-0007: Hero Database — HeroData Resource + HeroDatabase Static Query Layer (MVP scope)** (Accepted 2026-04-30) | `class_name HeroDatabase extends RefCounted` + `@abstract` + all-static + lazy-init `_heroes: Dictionary[StringName, HeroData]`. 6 static query methods (`get_hero` / `get_heroes_by_faction` / `get_heroes_by_class` / `get_all_hero_ids` / `get_mvp_roster` / `get_relationships`). `HeroData extends Resource` with 26 `@export` fields + nested `HeroFaction` enum. Single-file JSON storage at `assets/data/heroes/heroes.json` with lazy-init `JSON.new().parse()`. 3-tier severity validation: load-reject FATAL (hero_id format `^[a-z]+_\d{3}_[a-z_]+$`, duplicate hero_id, parallel-array length mismatch); per-record FATAL (stat ranges [1,100] / seed ranges / move_range [2,6] / growth [0.5,2.0]); WARNING (relationship self-ref / orphan FK / asymmetric conflict — load continues). F-1..F-4 stat-balance + SPI + growth-ceiling + MVP-roster validation **Polish-deferred** to `tools/ci/lint_hero_database_validation.sh` (BalanceConstants thresholds via ADR-0006 forward-compat; runtime pipeline does NOT consume validation thresholds). Read-only contract: `forbidden_pattern hero_data_consumer_mutation`. Non-emitter per ADR-0001 line 372. | **LOW** — `JSON.new().parse()` instance form pre-Godot-4.0 stable; `FileAccess.get_file_as_string()` pre-4.4 stable (READ path only — 4.4 `store_*` change does NOT apply); `Dictionary[StringName, HeroData]` typed Godot 4.4+ stable; `Array[StringName]` + `Array[Dictionary]` typed-array discipline 4.4+ stable; `Resource.duplicate_deep()` 4.5+ available for relationships migration; `@abstract` + class_name + RefCounted pre-cutoff stable. 5th-precedent stateless-static pattern (ADR-0008→0006→0012→0009→0007). |
| **ADR-0001: GameBus Autoload Singleton** (Accepted) | Hero Database listed on non-emitter list (line 372). Zero `signal` declarations + zero `connect()` / `emit_signal()` calls in `hero_database.gd` + `hero_data.gd`. Static-lint enforcement per ADR-0007 §Validation §6. Mirrors ADR-0012 / ADR-0009 / ADR-0006 forbidden_pattern non-emitter discipline (4-precedent). **Carried advisory** (non-blocking): line 372 prose API name `hero_database.get(unit_id)` is stale relative to ADR-0007 §4 6-method API; defer to next ADR-0001 amendment. | **LOW** — signal-contract enforcement is grep-based static lint. |
| **ADR-0006: Balance/Data — BalanceConstants** (Accepted) | Forward-compat dependency only — `BalanceConstants.get_const(key)` for F-1..F-4 validation thresholds (`STAT_TOTAL_MIN`, `STAT_TOTAL_MAX`, `SPI_WARNING_THRESHOLD`, `STAT_HARD_CAP`, `MVP_FLOOR_OFFSET`, `MVP_CEILING_OFFSET`). **NOT consumed at MVP runtime** — Polish-tier lint script only. Threshold append to `balance_entities.json` ships same-patch with the Polish lint story (NOT this epic's runtime stories). G-15 `_heroes_loaded = false` reset in `before_test()` mirrors ADR-0006 `_cache_loaded` precedent. | **LOW** — accessor pattern stable; threshold append is data-only. |
| **ADR-0009: Unit Role** (Accepted) | Soft-dep ratified by ADR-0007. `HeroData.default_class: int` is 1:1 aligned with `UnitRole.UnitClass` enum int values (CAVALRY=0..SCOUT=5). UnitRole call sites bind `unit_class: UnitRole.UnitClass` at parameter level — type safety preserved at boundary. The 7 UnitRole-read fields (`stat_might/intellect/command/agility` + `base_hp_seed/base_initiative_seed` + `move_range`) preserved verbatim from provisional shape; ADR-0009 call sites parameter-stable. Same-patch obligation: ADR-0009 §Dependencies + §Migration Plan flipped from "soft / provisional" to ratified (already shipped). | **LOW** — value-alignment convention only; no call coupling. |

## GDD Requirements

15 TRs registered via `/architecture-review` delta #5 (2026-04-30). All traced to ADR-0007. **Zero untraced**. AC-08..AC-11 (F-1..F-4 stat-balance validation) Polish-deferred per §11.

| TR-ID | Requirement (excerpt) | ADR Coverage |
|-------|-----------------------|--------------|
| TR-hero-database-001 | §1 Module form — `class_name HeroDatabase extends RefCounted` + `@abstract` + all-static + lazy-init `_heroes: Dictionary[StringName, HeroData]`; 5th-precedent stateless-static pattern | ADR-0007 §1 ✅ |
| TR-hero-database-002 | §2 HeroData 26 @export fields per CR-2's 9 record blocks + nested HeroFaction enum; Resource overhead acknowledged | ADR-0007 §2 ✅ |
| TR-hero-database-003 | §3 Storage — single `assets/data/heroes/heroes.json`; lazy-init `JSON.new().parse()` line/col diagnostics | ADR-0007 §3 ✅ |
| TR-hero-database-004 | §4 Public API — 6 static query methods; G-2 typed-array construction MANDATORY for return values | ADR-0007 §4 ✅ |
| TR-hero-database-005 | Read-only contract — consumers MUST NOT mutate returned HeroData; R-1 mitigation regression test | ADR-0007 §2 + §7 ✅ |
| TR-hero-database-006 | CR-1 + AC-01 — hero_id format `^[a-z]+_\d{3}_[a-z_]+$` regex; FATAL full-load reject | ADR-0007 §5 ✅ |
| TR-hero-database-007 | CR-2 + AC-02..AC-05 — schema range checks per-record FATAL | ADR-0007 §5 ✅ |
| TR-hero-database-008 | EC-1 + AC-12 — duplicate hero_id full-load reject (FATAL) | ADR-0007 §5 ✅ |
| TR-hero-database-009 | EC-2 + EC-3 + AC-07 + AC-13 — skill parallel-array integrity per-record FATAL | ADR-0007 §5 ✅ |
| TR-hero-database-010 | EC-4 + EC-5 + EC-6 + AC-14 — relationship WARNING tier (load continues) | ADR-0007 §5 ✅ |
| TR-hero-database-011 | F-1..F-4 + AC-08..AC-11 — **Polish-deferred** to `lint_hero_database_validation.sh` | ADR-0007 §5 + N2 ✅ |
| TR-hero-database-012 | CR-4 — `default_class: int` (NOT typed enum) cross-doc convention; not a forbidden_pattern | ADR-0007 §2 + N3 ✅ |
| TR-hero-database-013 | Non-emitter invariant per ADR-0001 line 372; static-lint zero-match enforcement | ADR-0007 §7 + ADR-0001 ✅ |
| TR-hero-database-014 | §1 lazy-init lifecycle + G-15 test isolation — `_heroes_loaded = false` reset in `before_test()` | ADR-0007 §1 ✅ |
| TR-hero-database-015 | Performance budgets — `get_hero` <0.001ms; `_load_heroes()` <100ms target for 100-hero Alpha (10-hero MVP measured) | ADR-0007 §Performance ✅ |

## Epic Scope — Residual Work (post same-patch ratification)

ADR-0007 §Migration Plan same-patch obligations status:

- ✅ §1 `src/foundation/hero_data.gd` extended from 10 → 26 @export fields (shipped 2026-04-30 with ADR-0007 acceptance)
- ✅ §5 TR registry append (TR-hero-database-001..015 in `tr-registry.yaml` v6→v7)
- ✅ §6 Architecture registry append (state_ownership / interfaces / api_decisions / forbidden_patterns)
- ✅ Same-patch §1 ADR-0009 §Dependencies hard-ratified
- ✅ Same-patch §2 ADR-0009 §Migration Plan §"From provisional HeroData" marked COMPLETE
- ✅ Same-patch §3 `hero_data.gd` header doc-comment "Ratified by ADR-0007 (Accepted 2026-04-29)"
- ⏳ Same-patch §4 GDD `design/gdd/hero-database.md` Status field flip "Designed" → "Accepted via ADR-0007" — **VERIFY in story-001 readiness**

**Residual epic scope** (the work `/create-stories` will decompose; ~5 stories estimated):

1. **HeroDatabase module + 6 query API** — create `src/foundation/hero_database.gd` (~300 LoC):
   - `class_name HeroDatabase extends RefCounted` + `@abstract` (G-22)
   - `static var _heroes_loaded: bool` + `static var _heroes: Dictionary[StringName, HeroData] = {}`
   - `_load_heroes()` lazy-init: `FileAccess.get_file_as_string()` + `JSON.new().parse()` + per-record `HeroData` instantiation
   - 6 public static query methods per ADR-0007 §4 with **typed-array construction discipline** (G-2 — `var result: Array[HeroData] = []` + append loop, NOT `.values().duplicate()`)
   - `# RETURNS SHARED REFERENCE — consumers MUST NOT mutate fields. Use base+modifier pattern.` source comment above each query method (TR-005)

2. **Validation pipeline (CR-1 / CR-2 / EC-1 / EC-2)** — load-reject FATAL + per-record FATAL severity tiers:
   - hero_id regex match + duplicate-key Dictionary collision check (full-load reject; clear `_heroes` to ensure no partial state)
   - Per-field range validation: stats [1,100], seeds [1,100], move_range [2,6], growth [0.5,2.0]
   - Skill parallel-array length equality (per-record FATAL; max 3 innate skills CR-2 cap deferred to Polish lint)
   - `push_error` lists hero_id + field name + value + expected range

3. **Relationship WARNING tier (EC-4 / EC-5 / EC-6)** + **R-1 consumer-mutation regression test**:
   - Self-reference EC-4 + orphan FK EC-5 + asymmetric conflict EC-6 → drop offending entry + `push_warning`; record loads normally
   - `tests/unit/foundation/hero_database_consumer_mutation_test.gd` documents shared-reference contract (mutation IS visible — convention is sole defense)
   - `forbidden_pattern hero_database_signal_emission` + `hero_data_consumer_mutation` registered in `docs/registry/architecture.yaml` (already shipped same-patch §6, story verifies presence)

4. **MVP roster (`heroes.json`) + integration test suite** — author 8–10 hero records:
   - Faction coverage: SHU + WEI + WU + QUNXIONG (NEUTRAL optional)
   - 4-distinct-dominant_stat coverage per F-4 (lint enforces in Polish; manual authoring discipline at MVP)
   - All `is_available_mvp = true`
   - Per-AC test cases: AC-01 ID format / AC-02..AC-05 range checks / AC-06 relationship structure / AC-07 skill parallel arrays / AC-12 duplicate / AC-13 skill mismatch / AC-14 orphan WARNING / AC-15 6-method query interface

5. **Perf baseline + Polish-tier lint scaffold + non-emitter lint**:
   - `tests/unit/foundation/hero_database_perf_test.gd` headless throughput (<0.001ms get_hero; <100ms _load_heroes 100-hero Alpha forward-compat extrapolation; 10-hero MVP measured) — mirrors balance-data story-005 + damage-calc story-010 Polish-deferral pattern for on-device measurement
   - `tools/ci/lint_hero_database_no_signal_emission.sh` — 4-precedent non-emitter grep gate (mirrors damage-calc / unit-role / balance-data + ADR-0007 §Validation §6)
   - **F-1..F-4 validation lint scaffold (`tools/ci/lint_hero_database_validation.sh`)** — Polish-deferred per ADR-0007 §11 + N2 (5-precedent Polish-deferral pattern); story creates the scaffold + tech-debt entry; full implementation Alpha-tier

## Definition of Done

This epic is complete when:

- All stories implemented, reviewed, and closed via `/story-done`
- All 15 TRs verified — 11 via passing tests in `tests/unit/foundation/hero_database*.gd`; TR-011 (F-1..F-4) via Polish-deferred lint scaffold + tech-debt entry
- All 15 GDD ACs verified — AC-01..AC-07 + AC-12..AC-15 via runtime tests; AC-08..AC-11 via Polish-tier lint scaffold (deferred per ADR-0007 §11 + N2)
- `src/foundation/hero_database.gd` shipped (~300 LoC, 6 static query methods, lazy-init, per-record validation)
- `assets/data/heroes/heroes.json` shipped with 8–10 MVP records (4-faction coverage)
- Full regression suite ≥506 baseline maintained (per active.md balance-data story-004 close-out evidence)
- `grep -E '(signal\s|connect\(|emit_signal\()' src/foundation/hero_database.gd src/foundation/hero_data.gd` returns zero matches (TR-013 non-emitter static lint via `tools/ci/lint_hero_database_no_signal_emission.sh`)
- `grep -L '_heroes_loaded = false' tests/unit/foundation/hero_database*.gd` returns empty (TR-014 G-15 test-isolation static lint)
- `forbidden_pattern hero_database_signal_emission` + `hero_data_consumer_mutation` present in `docs/registry/architecture.yaml`
- GDD Status field flipped "Designed" → "Accepted via ADR-0007" (same-patch §4 verification)
- TD entry logged for F-1..F-4 Polish-tier validation lint
- ADR-0007 §Validation Criteria §1-§9 all green

## Sprint Mapping

| Sprint | Story IDs | Goal |
|--------|-----------|------|
| Sprint 2 | S2-02 (epic + stories) + S2-04 (implementation) | Epic created, ~5 stories scaffolded, all stories shipped to Complete |

## Next Step

Run `/create-stories hero-database` to break this epic into implementable stories.
