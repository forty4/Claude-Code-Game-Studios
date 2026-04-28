# Epic: Unit Role

> **Layer**: Foundation (per ADR-0009 §Engine Compatibility — "Foundation — stateless gameplay rules calculator")
> **GDD**: design/gdd/unit-role.md (Designed, rev 2026-04-16)
> **Architecture Module**: Unit Role (`src/foundation/unit_role.gd` per ADR-0009 §1)
> **Status**: Ready
> **Manifest Version**: 2026-04-20
> **Stories**: 10 created (2026-04-28); see Stories table below — all Ready

## Overview

Unit Role is the Foundation-layer stateless gameplay rules calculator that owns the 6 class profiles (CAVALRY, INFANTRY, ARCHER, STRATEGIST, COMMANDER, SCOUT) and their derived combat values: 5 stat-derivation formulas (F-1 ATK, F-2 DEF split into phys_def/mag_def, F-3 max_hp, F-4 initiative, F-5 effective_move_range), the 6×6 terrain cost matrix unit-class dimension, the 6×3 class direction multiplier table, the 6 canonical passive StringName tags, and the per-class equipment slot defaults. The module is `class_name UnitRole extends RefCounted` + `@abstract` + 8 all-static methods + 1 const Dictionary, with zero instance state, zero signal emissions, and zero signal subscriptions per ADR-0001's non-emitter list. Per-class coefficients load lazily from `assets/data/config/unit_roles.json` (instance-form `JSON.new().parse()` for line/col diagnostics + safe-default fallback per ADR-0008 precedent); global caps (ATK_CAP, DEF_CAP, HP_CAP, HP_SCALE, HP_FLOOR, INIT_CAP, INIT_SCALE, MOVE_RANGE_MIN, MOVE_RANGE_MAX, MOVE_BUDGET_PER_RANGE) read via `BalanceConstants.get_const(key)` per ADR-0006. Acceptance ratifies ADR-0008's cost-matrix unit-class dimension placeholder (was uniform `1` pending) and ADR-0012's `CLASS_DIRECTION_MULT[6][3]` table contract.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0009: Unit Role System | `class_name UnitRole extends RefCounted` + `@abstract` + 8 static methods + const PASSIVE_TAG_BY_CLASS Dictionary; lazy-init JSON config from `assets/data/config/unit_roles.json` + global caps via BalanceConstants; typed `UnitClass` enum parameter binding; PackedFloat32Array per-call copy COW for cost_table; runtime CLASS_DIRECTION_MULT read goes through unit_roles.json (per-class data locality, NOT BalanceConstants — entities.yaml registration is design-side cross-system tracking only) | LOW (no post-cutoff APIs; all APIs pre-Godot-4.4 stable) |
| ADR-0001: GameBus Autoload | UnitRole on non-emitter list (line 375) — zero `signal` declarations + zero `connect(`/`emit_signal(` calls; static-lint enforcement per §Validation Criteria §4 | LOW (inherited; pure data-calculation layer) |
| ADR-0006: Balance/Data | `BalanceConstants.get_const(key) -> Variant` is the canonical accessor for all 10 global caps consumed by F-1..F-5; G-15 test isolation obligation (`_cache_loaded = false` reset in `before_test()`) inherited | LOW (inherited; provisional contract, parameter-stable) |
| ADR-0008: Terrain Effect | Architectural-form precedent (RefCounted + all-static + JSON config + lazy-init); cost-matrix unit-class dimension placeholder (per ADR-0008 §Context item 5 deferral) ratified by this epic via `get_class_cost_table` returning a 6-entry PackedFloat32Array indexed by terrain_type enum | LOW (inherited) |

## GDD Requirements

| TR-ID | Requirement (Summary) | ADR Coverage |
|-------|----------------------|--------------|
| TR-unit-role-001 | §1 Module form — `class_name UnitRole extends RefCounted` + `@abstract` (runtime-error guard on `.new()`) + all-static + lazy-init JSON config; 4-precedent stateless-calculator pattern (ADR-0008→0006→0012→0009) | ADR-0009 ✅ |
| TR-unit-role-002 | §2 UnitClass typed enum (CAVALRY=0..SCOUT=5) with typed parameter binding `unit_class: UnitRole.UnitClass`; improvement over ADR-0008's raw int terrain_type pattern | ADR-0009 ✅ |
| TR-unit-role-003 | §3 Public API — 8 static methods (5 derived stats + move_range + cost_table + direction_mult) + 1 const PASSIVE_TAG_BY_CLASS Dictionary; orthogonal per-stat (NOT bundled UnitStats Resource) | ADR-0009 ✅ |
| TR-unit-role-004 | §4 Per-class config schema — `assets/data/config/unit_roles.json` 6×12 schema; lazy-init `JSON.new().parse()` + safe-default fallback; session-persistent cache | ADR-0009 ✅ |
| TR-unit-role-005 | §4 + Engine Compat — Global caps via `BalanceConstants.get_const(key)` per ADR-0006 (10 caps: ATK_CAP, DEF_CAP, HP_CAP, HP_SCALE, HP_FLOOR, INIT_CAP, INIT_SCALE, MOVE_RANGE_MIN, MOVE_RANGE_MAX, MOVE_BUDGET_PER_RANGE); G-15 `_cache_loaded` reset obligation | ADR-0009 ✅ + ADR-0006 ✅ |
| TR-unit-role-006 | §5 Cost-matrix unit-class dim — 6×6 per CR-4; `get_class_cost_table(UnitClass) -> PackedFloat32Array` 6-entry; ratifies ADR-0008's deferred placeholder per §Context item 5 | ADR-0009 ✅ + ADR-0008 ✅ |
| TR-unit-role-007 | §6 Class direction mult — 6×3 CLASS_DIRECTION_MULT per CR-6a + EC-7 + entities.yaml; runtime read via unit_roles.json (per-class data locality), NOT BalanceConstants; STRATEGIST/COMMANDER all-1.0 no-op rows by design | ADR-0009 ✅ |
| TR-unit-role-008 | §5 R-1 mitigation — PackedFloat32Array per-call copy COW semantics; forbidden_pattern `unit_role_returned_array_mutation` + caller-mutation regression test mandatory | ADR-0009 ✅ |
| TR-unit-role-009 | §7 Passive tag canonicalization — 6 StringName tags locked (`&"passive_charge"..&"passive_ambush"`); Array[StringName] mandatory per ADR-0012 `damage_calc_dictionary_payload` | ADR-0009 ✅ |
| TR-unit-role-010 | Non-emitter invariant per ADR-0001 line 375; forbidden_pattern `unit_role_signal_emission`; static-lint enforcement zero `signal `/`connect(`/`emit_signal(` matches | ADR-0009 ✅ + ADR-0001 ✅ |
| TR-unit-role-011 | F-1..F-5 stat derivation — clamp ranges `[1, ATK_CAP]`, `[1, DEF_CAP]`, `[HP_FLOOR+1, HP_CAP]`, `[1, INIT_CAP]`, `[MOVE_RANGE_MIN, MOVE_RANGE_MAX]`; 100% test coverage required per technical-preferences | ADR-0009 ✅ |
| TR-unit-role-012 | Performance — derived-stat <0.05ms / cost_table <0.01ms / direction_mult <0.01ms / per-battle init <0.6ms total; headless CI baseline + on-device deferred per damage-calc story-010 Polish-deferral pattern | ADR-0009 ✅ |

**Untraced Requirements**: None. All 12 architectural TRs map to ADR-0009 §1-§7 + Engine Compatibility + Performance + Validation Criteria. Coverage of the 23 GDD ACs (AC-1..AC-23) is via ADR-0009 §GDD Requirements Addressed table.

## Scope

**Implements**:
- `src/foundation/unit_role.gd` — `class_name UnitRole extends RefCounted` + `@abstract` + `enum UnitClass { CAVALRY=0..SCOUT=5 }` + 8 public static methods (`get_atk`, `get_phys_def`, `get_mag_def`, `get_max_hp`, `get_initiative`, `get_effective_move_range`, `get_class_cost_table`, `get_class_direction_mult`) + `const PASSIVE_TAG_BY_CLASS: Dictionary` + private `_load_coefficients()` lazy-init helper + `static var _coefficients_loaded: bool` flag + safe-default fallback table matching GDD CR-1 + CR-4 + CR-6a values
- `assets/data/config/unit_roles.json` — 6 class entries (cavalry/infantry/archer/strategist/commander/scout) × 12-field schema per ADR-0009 §4 (primary_stat, secondary_stat, w_primary, w_secondary, class_atk_mult, class_phys_def_mult, class_mag_def_mult, class_hp_mult, class_init_mult, class_move_delta, passive_tag, terrain_cost_table[6], class_direction_mult[3])
- `src/foundation/hero_data.gd` — provisional `class_name HeroData extends Resource` with @export-annotated fields per `hero-database.md` §Detailed Rules (provisional shape; ADR-0007 will ratify). Migration parameter-stable per ADR-0009 §Migration Plan §From provisional HeroData
- `assets/data/balance/balance_entities.json` — single-line append: `"MOVE_BUDGET_PER_RANGE": 10` (cross-doc obligation per ADR-0009 §Migration Plan §4; consumers like Grid Battle read via `BalanceConstants.get_const("MOVE_BUDGET_PER_RANGE")`)
- `tests/unit/foundation/unit_role_test.gd` — F-1..F-5 formula coverage with min/max/median fixtures (100% per technical-preferences "balance formulas 100%"); R-1 caller-mutation isolation test (`test_get_class_cost_table_caller_mutation_isolated`); G-15 `_cache_loaded = false` reset in `before_test()`; non-emitter static-lint test (zero `signal `/`connect(`/`emit_signal(` matches in `src/foundation/unit_role.gd`); EC-1, EC-2, EC-13, EC-14 boundary tests
- `tests/unit/foundation/unit_role_perf_test.gd` — headless CI throughput baseline test (mirrors damage-calc story-010 pattern); per-method <0.05ms / cost_table <0.01ms / direction_mult <0.01ms; on-device measurement deferred per Polish-deferral pattern (5+ invocations stable)

**Does not implement**:
- `assets/data/skills/class_pools.json` schema (CR-5c — deferred to Battle Preparation epic per ADR-0009 §6 GDD Requirements Addressed AC-18..AC-19)
- On-device perf measurement (deferred to Polish phase per damage-calc story-010 Polish-deferral pattern; reactivation trigger: first Android export build green AND target device available)
- `equipment_slot_override` enforcement (owned by Equipment/Item system per EC-17; UnitRole only owns the default slot configuration per CR-1)
- Hot-reload on data change (AC-21 documented MVP limitation: requires editor restart, matches ADR-0006 §6 BalanceConstants behavior; editor-time reload deferred to a future Alpha-tier ADR)
- HeroData ratified field set (provisional wrapper ships per §Migration Plan §3; ADR-0007 ratifies the authoritative shape)

## Soft Dependencies

The provisional `src/foundation/hero_data.gd` wrapper ships with @export-annotated fields per `hero-database.md` §Detailed Rules. Migration parameter-stable when ADR-0007 ratifies (call sites unchanged; only the `HeroData` field set may extend, never rename without ADR-0007 amendment + propagate-design-change pass). Pattern is now stable at **3 invocations** of the provisional-dependency strategy (ADR-0008→0006 + ADR-0012→0006/0009/0010/0011 + ADR-0009→0007).

| Soft-dep | Status | Resolution Trigger |
|---|---|---|
| ADR-0007 Hero DB (HeroData Resource shape) | NOT YET WRITTEN | When ADR-0007 lands: `/propagate-design-change` against `unit-role.md` + ADR-0009 §Migration Plan + UnitRole call-sites + tests. If field-set expansion only (HIGH probability per `hero-database.md` GDD Designed status): no UnitRole changes; new HeroData fields are inert to UnitRole's read set. |

## Ratifies (now-resolved soft-deps from prior epics)

ADR-0009 acceptance + this epic's implementation will close two prior soft-dep callouts:

| Resolved Soft-dep | Action |
|---|---|
| ADR-0008's `cost_multiplier(unit_type, terrain_type)` placeholder uniform `1` | Replace `src/core/terrain_effect.gd::cost_multiplier` placeholder with `UnitRole.get_class_cost_table(unit_class)[terrain_type]` indexed read OR keep TerrainEffect's accessor as a thin pass-through to UnitRole (decision deferred to story authoring per `/create-stories unit-role`). Either way, the uniform `1` placeholder is retired. |
| ADR-0012's CLASS_DIRECTION_MULT[6][3] table (was soft-dep in ADR-0012) | Damage Calc consumes via `UnitRole.get_class_direction_mult(unit_class, direction)` per ADR-0012 §F-DC-3. Already locked by entities.yaml + GDD CR-6a + ADR-0009 §6; this epic ships the runtime accessor. |

## Cross-doc Obligations

These are non-code obligations triggered by ADR-0009 acceptance + this epic's first story:

1. **`MOVE_BUDGET_PER_RANGE = 10`** — append to `assets/data/balance/balance_entities.json` (single-line, lint-script reference unchanged). Per ADR-0009 §Migration Plan §4. Pre-registered in unit-role.md GDD Global Constant Summary table (lines 451-462) this session.
2. **architecture.md §Foundation layer entry** — overdue update from ≥6 ADRs trigger (now 7 ADRs); not a unit-role epic blocker, but `/create-architecture` partial-update pass should run before next 2 ADRs land (ADR-0007 + ADR-0010 would push to 9).

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All 23 acceptance criteria from `design/gdd/unit-role.md` (AC-1..AC-23) are verified against ADR-0009 §GDD Requirements Addressed mapping
- All Logic stories (F-1..F-5 formulas + cost matrix + direction multiplier + passive tag set + R-1 isolation) have passing test files in `tests/unit/foundation/`
- All Integration stories (Damage Calc consumer integration + Map/Grid cost-table consumer integration) have passing test files in `tests/integration/foundation/` OR documented playtest evidence in `production/qa/evidence/`
- 100% test coverage on F-1..F-5 formulas (per technical-preferences "balance formulas 100%")
- 80%+ test coverage on cost table, direction mult, passive tag set, error/fallback paths
- `tests/unit/foundation/unit_role_test.gd::test_get_class_cost_table_caller_mutation_isolated` (R-1 mitigation regression test) passes
- Static lint: zero `signal `/`connect(`/`emit_signal(` matches in `src/foundation/unit_role.gd` (non-emitter invariant per ADR-0001 line 375 + forbidden_pattern `unit_role_signal_emission`)
- Static lint: zero hardcoded global caps in `src/foundation/unit_role.gd` (per §Validation Criteria §5; all reads via `BalanceConstants.get_const(...)`)
- G-15 obligation honored: every test suite calling any UnitRole method that transitively reads BalanceConstants resets `_cache_loaded = false` in `before_test()`. Static-lint check post-implementation: `grep -L "_cache_loaded = false" tests/unit/foundation/unit_role*.gd` returns empty
- `MOVE_BUDGET_PER_RANGE = 10` constant appended to `assets/data/balance/balance_entities.json` (cross-doc obligation §1)
- ADR-0008 `cost_multiplier` placeholder retired (uniform `1` replaced by UnitRole accessor or thin pass-through)
- Headless CI throughput baseline pass: per-method <0.05ms / cost_table <0.01ms / direction_mult <0.01ms (per-battle init <0.6ms total budget)
- On-device perf measurement marked Polish-deferred with documented reactivation trigger (per damage-calc story-010 pattern, 5+ invocations stable)

## Stories

| # | Story | Type | Status | ADR | TR Coverage |
|---|-------|------|--------|-----|-------------|
| [001](story-001-module-skeleton.md) | UnitRole module skeleton + UnitClass enum + provisional HeroData wrapper | Logic | **Complete** (2026-04-28) ✅ | ADR-0009 §1+§2+§Migration Plan §3 | TR-unit-role-001/002 |
| [002](story-002-json-config-loader.md) | unit_roles.json schema + lazy-init JSON loader + safe-default fallback | Logic | **Complete** (2026-04-28) ✅ | ADR-0009 §4 | TR-unit-role-004 |
| [003](story-003-stat-derivation-formulas.md) | F-1..F-5 stat derivation static methods + clamp discipline + G-15 test isolation | Logic | **Complete** (2026-04-28) ✅ | ADR-0009 §3 + ADR-0006 | TR-unit-role-005, 011 (AC-1..AC-5 + EC-1, EC-2, EC-13, EC-14) |
| [004](story-004-cost-table-r1-mitigation.md) | get_class_cost_table + R-1 caller-mutation isolation regression test | Logic | **Complete** (2026-04-28) ✅ | ADR-0009 §5 + R-1 | TR-unit-role-006, 008 (AC-12..AC-15) |
| [005](story-005-direction-mult-accessor.md) | get_class_direction_mult + 6×3 table read from unit_roles.json | Logic | **Complete** (2026-04-28) ✅ | ADR-0009 §6 | TR-unit-role-007 (AC-16, AC-17) |
| [006](story-006-passive-tags-const.md) | PASSIVE_TAG_BY_CLASS const Dictionary + Array[StringName] consumer pattern | Logic | **Complete** (2026-04-28) ✅ | ADR-0009 §7 + ADR-0012 damage_calc_dictionary_payload | TR-unit-role-009 (AC-6..AC-11 tag layer only) |
| [007](story-007-move-budget-balance-append.md) | Unit-role global caps balance_entities.json append (8 keys) + cross-doc obligation closure | Config/Data | **Complete** (2026-04-28) ✅ | ADR-0009 §4 + §Migration Plan §4 + ADR-0006 | TR-unit-role-005 cross-doc (AC-20) |
| [008](story-008-cost-multiplier-placeholder-retirement.md) | ADR-0008 cost_multiplier placeholder retirement (replace uniform=1 with UnitRole accessor) | Integration | **Complete** (2026-04-28) ✅ | ADR-0008 §Migration Plan + ADR-0009 §5 | TR-unit-role-006 (ratifies ADR-0008 §Context item 5) |
| [009](story-009-damage-calc-integration.md) | Damage Calc integration test (consumes get_class_direction_mult per F-DC-3) [SCOPE EXPANDED: + DamageCalc refactor] | Integration | **Complete** (2026-04-28) ✅ | ADR-0012 §F-DC-3 + ADR-0009 §6 | TR-unit-role-007 (ratifies ADR-0012 CLASS_DIRECTION_MULT[6][3]; AC-22) |
| [010](story-010-non-emitter-lint-perf-baseline.md) | Non-emitter static-lint + headless CI perf baseline (Polish-deferred on-device) | Logic | Ready | ADR-0009 §Validation Criteria §3-§5 + §Performance + ADR-0001 line 375 | TR-unit-role-010, 012 |

**Type breakdown**: 7 Logic / 2 Integration / 1 Config/Data
**Implementation order** (parallelism shown):
1. **Story 001** — module skeleton + UnitClass enum + provisional HeroData (foundation for all downstream stories)
2. **Story 002** — JSON config loader + lazy-init + safe-default fallback (depends on Story 001)
3. **Stories 003 / 004 / 005 / 006 in parallel** — F-1..F-5 + cost_table + direction_mult + passive tags (each depends on Story 002 for the data layer; mutually independent at the per-method level; Story 006 depends only on Story 001 since the const Dictionary doesn't need JSON loader)
4. **Story 007** — Unit-role global caps balance_entities.json append (8 keys; re-scoped 2026-04-28 from original "MOVE_BUDGET_PER_RANGE only" after story-003 readiness probe surfaced 7 missing caps). MUST RUN BEFORE Stories 003-005 (which depend on the 8 caps via BalanceConstants.get_const). Original "anytime after story-001" ordering revised
5. **Story 008** — ADR-0008 placeholder retirement (depends on Story 004's `get_class_cost_table`)
6. **Story 009** — Damage Calc integration test (depends on Story 005's `get_class_direction_mult` + damage-calc epic's `DamageCalc.resolve()` body existing — note potential cross-epic ordering dependency)
7. **Story 010** — non-emitter lint + perf baseline + Polish-deferral evidence (depends on all functional stories 003/004/005/006)

**Polish-deferred (per damage-calc story-010 pattern, 5+ invocations stable)**:
- Story 010 on-device perf measurement — reactivation trigger: first Android export build green AND target device available (Snapdragon 7-gen / Adreno 610 / Mali-G57 class)

## Next Step

Run `/story-readiness production/epics/unit-role/story-001-module-skeleton.md` to validate the first story, then `/dev-story` to begin implementation.

Work through stories in order — each story's `Depends on:` field tells you what must be DONE before you can start it. The recommended path:
1. Validate + implement Story 001 (skeleton)
2. Validate + implement Story 002 (JSON loader)
3. Parallelize Stories 003-006 across multiple sessions if developer capacity allows
4. Story 007 can run in parallel with anything after Story 001
5. Stories 008 + 009 are integration tests — schedule after their respective dependencies
6. Story 010 is the epic close-out — runs last; produces `/story-done` graduation to Status=Complete
