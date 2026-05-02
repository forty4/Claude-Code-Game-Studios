# Epic: HP/Status System

> **Layer**: Core
> **GDD**: `design/gdd/hp-status.md` (Designed; CR-1..CR-9 + 4 sub-rules per CR-5; 4 formulas F-1..F-4; 17 Edge Cases EC-01..EC-17; 27 Tuning Knobs; 20 Acceptance Criteria AC-01..AC-20; 6 Open Questions OQ-1..OQ-6)
> **Architecture Module**: `HPStatusController` — battle-scoped Node child of `BattleScene`
> **Manifest Version**: 2026-04-20 (`docs/architecture/control-manifest.md`)
> **Status**: **Complete (2026-05-02)** — all 8 stories Complete; epic terminal closed; 743/0/0/0/0/0 Exit 0; 8th consecutive failure-free baseline; 5 forbidden_patterns enforced via CI lint scripts; cross-platform determinism fixture green; 3 Polish-tier TD entries logged (TD-050/051/052 + TD-053 test-factory hoisting)
> **Stories**: 8/8 created (2026-05-02 via `/create-stories hp-status`); 8/8 Complete (2026-05-02)
> **Created**: 2026-05-02 (Sprint 3 S3-01)
> **Closed**: 2026-05-02 (Sprint 3 S3-02 done — epic terminal via story-008)

## Stories

| # | Story | Type | Status | TR-IDs | GDD ACs | Estimate |
|---|-------|------|--------|--------|---------|----------|
| [001](story-001-module-skeleton-and-payloads.md) | Module skeleton + 4 payload classes + 27 BalanceConstants + 5 .tres templates | Logic | **Complete (2026-05-02)** | TR-002, TR-003, TR-004, TR-012 | (structural) | 4-5h |
| [002](story-002-initialize-unit-and-queries.md) | initialize_unit + 3 read-only queries + CR-1a/CR-2 invariants | Logic | **Complete (2026-05-02)** | TR-005 (partial), TR-018 | AC-01, AC-02 | 2-3h |
| [003](story-003-apply-damage-and-f1-pipeline.md) | F-1 apply_damage 4-step pipeline + unit_died emit + R-1 mitigation | Logic | **Complete (2026-05-02)** | TR-005, TR-006, TR-014 | AC-03..AC-06, AC-17 (emit) | 3-4h |
| [004](story-004-apply-heal-and-f2-pipeline.md) | F-2 apply_heal 4-step pipeline + EXHAUSTED multiplier + overheal prevention | Logic | **Complete (2026-05-02)** | TR-007 | AC-07..AC-10 | 2-3h |
| [005](story-005-apply-status-and-cr5-cr7-mutex.md) | apply_status + CR-5c refresh + CR-5d coexist + CR-5e slot eviction + CR-7 mutex + template load | Logic | **Complete (2026-05-02)** | TR-008, TR-010 | AC-11, AC-12, AC-15, AC-16 | 3-4h |
| [006](story-006-turn-start-tick-and-f3-f4-modifiers.md) | _apply_turn_start_tick + F-3 DoT + F-4 get_modified_stat + EXHAUSTED move-range + GameBus subscribe + MapGrid DI | Integration | **Complete (2026-05-02)** | TR-005, TR-008, TR-009, TR-013 | AC-13, AC-14, AC-19 | 3-4h |
| [007](story-007-demoralized-radius-and-r6-dual-invocation.md) | _propagate_demoralized_radius + CR-8c Commander auto-trigger + R-6 dual-invocation + EC-17 refresh | Integration | **Complete (2026-05-02)** | TR-011 | AC-17 (full integration), AC-18 | 3-4h |
| [008](story-008-perf-lints-and-td-entries.md) | Epic terminal — perf baseline + 5 forbidden_patterns + CI wiring + cross-platform determinism + AC-20 + 3 TD entries | Config/Data | **Complete (2026-05-02)** | TR-015, TR-016, TR-017 | AC-20 | 2-3h |

**Implementation order**: 001 → 002 → {003, 004, 005 in parallel after 002} → 006 → 007 → 008. Stories 003/004/005 have no inter-dependencies (each operates on a distinct method body); the parallel branch may converge at story-006.

**Total estimate**: ~22-30h across 4 Logic + 2 Integration + 1 Config/Data + 1 borderline-skeleton stories.

## Overview

The HP/Status epic implements the Core-layer system that tracks per-unit
`current_hp` + active `status_effects[]` for the duration of a single battle.
`HPStatusController` is a stateful battle-scoped Node child of `BattleScene`
(created on battle-init via Battle Preparation, freed automatically with
BattleScene per ADR-0002 SceneManager pattern; lifecycle aligned with ADR-0004
Map/Grid). It owns 8 public methods (3 mutators + 5 read-only queries), emits
exactly 1 GameBus signal (`unit_died(unit_id: int)` per ADR-0001), consumes
1 GameBus signal (`unit_turn_started(unit_id: int)` per ADR-0011) for DoT tick
+ duration decrement + DEFEND_STANCE/DEMORALIZED expiry, and routes all 27
tuning-knob reads through `BalanceConstants.get_const(key)` per ADR-0006.

The epic delivers: F-1 4-step damage intake pipeline (passive flat reduction →
DEFEND_STANCE-first status modifier → MIN_DAMAGE floor → HP reduction + emit);
F-2 4-step healing pipeline (EXHAUSTED multiplier → overheal prevention →
HP increase); F-3 POISON DoT (true damage, bypasses F-1 intake); F-4 modifier
application (`get_modified_stat`) with EXHAUSTED move-range special-case branch
+ DEFEND_STANCE_ATK_PENALTY pre-folded so Damage Calc consumes already-folded
values; CR-5 status-effect stacking (refresh-only on same `effect_id`, coexist
on different `effect_id`, MAX_STATUS_EFFECTS_PER_UNIT=3 slot cap with
`pop_front()` insertion-order eviction); CR-7 DEFEND_STANCE+EXHAUSTED mutex
enforcement; CR-8 Death + DEMORALIZED radius propagation (Commander class
auto-trigger via MapGrid query; `is_morale_anchor` branch deferred post-MVP
per OQ-2). The pattern boundary precedent established by ADR-0005 §Alternative 4
(stateless-static for systems CALLED; Node-based form for systems that LISTEN
AND/OR hold mutable state) is honored — HP/Status both listens to Turn Order
signals AND mutates per-unit state, satisfying both criteria for Node-based form.

## Governing ADRs

| ADR | Decision Summary | Engine Risk |
|-----|-----------------|-------------|
| ADR-0010 HP/Status (primary, Accepted 2026-04-30 delta #7) | HPStatusController battle-scoped Node + per-unit RefCounted `UnitHPState` (6 fields) + `StatusEffect` typed Resource (7 @export fields) + separate `TickEffect` Resource for DoT formula reuse + 5 `.tres` templates + 8 public methods + 1 emitted signal + 1 consumed signal + 27 BalanceConstants entries + DI test seam (`_apply_turn_start_tick` direct call + `_map_grid` constructor injection) | LOW |
| ADR-0001 GameBus (Accepted 2026-04-18) | Single emitter of `unit_died(unit_id: int)` per §7 Signal Contract Schema line 155; HP/Status on non-emitter list line 365-376 for OTHER 21 GameBus signals (Validation §4 grep gate enforces) | LOW |
| ADR-0004 Map/Grid (Accepted 2026-04-20) | `MapGrid.get_tile(coord: Vector2i) -> TileData` consumed by `_propagate_demoralized_radius` (CR-6 SE-2 condition (a)) and `_has_ally_hero_within_radius` (CR-6 SE-2 recovery check); battle-scoped lifecycle alignment | LOW |
| ADR-0006 Balance/Data (Accepted 2026-04-30 delta #9) | `BalanceConstants.get_const(key) -> Variant` for all 27 tuning knobs; G-15 `_cache_loaded = false` reset obligation in every HPStatusController test suite | LOW |
| ADR-0007 Hero DB (Accepted 2026-04-30) | `HeroDatabase.get_hero(hero_id: StringName).base_hp_seed` consumed transitively via `UnitRole.get_max_hp`; `is_morale_anchor` field NOT YET in 26-field schema (OQ-2 deferred post-MVP) | LOW |
| ADR-0009 Unit Role (Accepted 2026-04-28) | `UnitRole.get_max_hp(hero, unit_class) -> int` cached at battle-init per ADR-0009 line 328 one-time-per-battle cadence; `UnitRole.PASSIVE_TAG_BY_CLASS[unit_class]` for `passive_shield_wall` lookup in F-1 Step 1; `get_atk / get_phys_def / get_mag_def / get_initiative / get_effective_move_range` for F-4 base-stat dispatch | LOW |
| ADR-0012 Damage Calc (Accepted 2026-04-26) | Soft-coupled — ADR-0012 line 260 commits Grid Battle (NOT Damage Calc) as sole caller of `apply_damage`; ADR-0012 lines 89-93 + 340-352 commit `get_modified_stat` read-only contract with DEFEND_STANCE_ATK_PENALTY pre-folded (HP/Status owns the pre-fold; Damage Calc does NOT separately apply penalty) | LOW |

**Highest Engine Risk among governing ADRs**: **LOW**.

## GDD Requirements

| TR-ID | Requirement (abridged) | ADR Coverage |
|-------|------------------------|--------------|
| TR-hp-status-001 | HP/Status emits `unit_died(unit_id: int)` consumed by Turn Order (queue removal), Grid Battle (victory), AI | ADR-0001 ✅ (signal contract source-of-truth; registry omits explicit `adr:` field per §7 emit-table convention) |
| TR-hp-status-002 | §1 Module form — `class_name HPStatusController extends Node` battle-scoped child of BattleScene; 5-precedent stateless-static + autoload + per-unit Component + ECS forms explicitly rejected via Alternatives 1-4 | ADR-0010 ✅ |
| TR-hp-status-003 | §3 Per-unit state schema — `class_name UnitHPState extends RefCounted` with 6 fields (unit_id: int / max_hp / current_hp / status_effects: Array[StatusEffect] / hero: HeroData / unit_class: int) | ADR-0010 ✅ |
| TR-hp-status-004 | §4 StatusEffect typed Resource schema — 7 @export fields + separate TickEffect Resource for DoT formula reuse; 5 `.tres` templates; shallow `.duplicate()` per delta-#7 Item 2 | ADR-0010 ✅ |
| TR-hp-status-005 | §5 Public API — 8 methods with locked signatures + 1 emitted signal + 1 consumed signal + non-emitter for OTHER 21 GameBus signals | ADR-0010 ✅ |
| TR-hp-status-006 | §6 + F-1 + EC-03 Damage intake 4-step pipeline (passive flat → DEFEND_STANCE-first status modifier → MIN_DAMAGE floor → HP reduction + emit) | ADR-0010 ✅ |
| TR-hp-status-007 | §7 + F-2 + CR-4a/b Healing 4-step pipeline (EXHAUSTED multiplier → overheal prevention → HP increase; returns actual heal_amount; dead-unit zero-return) | ADR-0010 ✅ |
| TR-hp-status-008 | §8 Status effect lifecycle (`apply_status` + CR-5c refresh / CR-5d coexist / CR-5e MAX 3 slots `pop_front()` eviction; turn-start tick DoT-before-decrement; reverse-index Array removal) | ADR-0010 ✅ |
| TR-hp-status-009 | §9 + F-4 `get_modified_stat` + EXHAUSTED move-range special-case + DEFEND_STANCE_ATK_PENALTY pre-fold | ADR-0010 ✅ |
| TR-hp-status-010 | §10 + CR-7 DEFEND_STANCE + EXHAUSTED mutex enforcement (force-remove on EXHAUSTED apply; rejection on DEFEND_STANCE attempt while EXHAUSTED) | ADR-0010 ✅ |
| TR-hp-status-011 | §11 + CR-8 + R-6 Death + DEMORALIZED radius propagation (Commander class auto-trigger via MapGrid query; explicit `_map_grid` DI; R-6 dual invocation from apply_damage Step 4 AND DoT-kill branch) | ADR-0010 ✅ |
| TR-hp-status-012 | §12 27 BalanceConstants entries — story-level same-patch obligation; CI lint validation; ATK_CAP/DEF_CAP ownership transferred from ADR-0012 line 297-299 | ADR-0010 ✅ |
| TR-hp-status-013 | §13 + Validation §5 DI test seam — `_apply_turn_start_tick` direct call bypasses GameBus subscription; `_map_grid` constructor-injected; `before_test()` G-15 reset obligations; static-lint check 0 | ADR-0010 ✅ |
| TR-hp-status-014 | §1 + R-1 Re-entrant `unit_died` emission — production CONNECT_DEFERRED + intra-scene Dictionary snapshot iteration + tests forbidden_pattern `hp_status_re_entrant_emit_without_deferred` | ADR-0010 ✅ |
| TR-hp-status-015 | R-5 + Validation §12 Consumer mutation forbidden_pattern — `get_status_effects` shallow Array copy with shared StatusEffect refs; convention-as-sole-defense documented FAIL-STATE regression test | ADR-0010 ✅ |
| TR-hp-status-016 | §Performance + Validation §8 — `apply_damage / get_modified_stat` <0.05ms; `apply_status` <0.10ms; `_apply_turn_start_tick` <0.20ms; ~10KB heap footprint; headless CI baseline mandatory; on-device deferred per Polish-deferral pattern | ADR-0010 ✅ |
| TR-hp-status-017 | §Verification §1 + §9 + Validation §9 Cross-platform determinism via integer arithmetic + `floor()` + `clamp()` — same call sequence produces identical state on macOS Metal + Linux Vulkan + Windows D3D12; headless CI deterministic-fixture mandatory before Polish | ADR-0010 ✅ |
| TR-hp-status-018 | Cross-doc unit_id type lock — ADR-0010 LOCKS `unit_id: int` per ADR-0001 signal-contract source-of-truth; ADR-0012 advisory **resolved 2026-04-30 delta #8** (lines 91/340 narrowed StringName → int) | ADR-0010 ✅ |

**Total**: 18/18 covered; **0 untraced**.

## Pattern Boundary Precedent

HPStatusController is the **2nd of 3-precedent battle-scoped Node form**
(ADR-0010 HPStatusController + ADR-0011 TurnOrderRunner; the autoload variant
ADR-0005 InputRouter is structurally similar but autoloaded for cross-scene
listening). Pattern boundary established by ADR-0005 §Alternative 4 — stateless-
static for systems CALLED; Node-based form for systems that LISTEN AND/OR hold
mutable state — is the project-wide discipline. Future Feature-layer state-
holders + signal-listeners (Grid Battle, AI System, Battle HUD likely candidates)
should adopt the battle-scoped Node variant when lifecycle is battle-bounded.

## Same-Patch Obligations from ADR-0010 Acceptance

The ADR was Accepted 2026-04-30 with the following story-level obligations
that this epic MUST satisfy before the epic can graduate to Complete:

1. **27 BalanceConstants entries** appended to `assets/data/balance/balance_entities.json`
   with provenance comments (mirrors hero-database 6-key + balance-data + turn-order
   2-key precedents). Keys: `MIN_DAMAGE / SHIELD_WALL_FLAT / HEAL_BASE / HEAL_HP_RATIO /
   HEAL_PER_USE_CAP / EXHAUSTED_HEAL_MULT / DOT_HP_RATIO / DOT_FLAT / DOT_MIN /
   DOT_MAX_PER_TURN / DEMORALIZED_ATK_REDUCTION / DEMORALIZED_RADIUS /
   DEMORALIZED_TURN_CAP / DEMORALIZED_RECOVERY_RADIUS / DEMORALIZED_DEFAULT_DURATION /
   DEFEND_STANCE_REDUCTION / DEFEND_STANCE_ATK_PENALTY / INSPIRED_ATK_BONUS /
   INSPIRED_DURATION / EXHAUSTED_MOVE_REDUCTION / EXHAUSTED_DEFAULT_DURATION /
   MODIFIER_FLOOR / MODIFIER_CEILING / MAX_STATUS_EFFECTS_PER_UNIT / ATK_CAP /
   DEF_CAP / POISON_DEFAULT_DURATION`. **ATK_CAP / DEF_CAP ownership transferred
   from ADR-0012 line 297-299**; **DEFEND_STANCE_ATK_PENALTY = -40 documented as
   provisional INERT** per grid-battle v5.0 CR-13 rule 4.
2. **5 `.tres` template files** at `assets/data/status_effects/{poison,demoralized,
   defend_stance,inspired,exhausted}.tres`.
3. **Forbidden-patterns registration** in `docs/registry/architecture.yaml` +
   matching CI lint scripts in `tools/ci/` + wiring into `.github/workflows/tests.yml`:
   `hp_status_static_var_state_addition` (R-4), `hp_status_consumer_mutation` (R-5,
   mirrors ADR-0007 hero_data_consumer_mutation), `hp_status_re_entrant_emit_without_deferred`
   (R-1), and signal-emission-outside-domain + external-state-mutation patterns
   by analogy with turn-order's 6-pattern set. Final pattern count locked at
   epic-terminal story.
4. **Validation lint** `tools/ci/lint_balance_entities_hp_status.sh` validating
   presence + safe-range per GDD §Tuning Knobs.

## Soft / Provisional Dependencies

- **Battle Preparation ADR (NOT YET WRITTEN)** — ratifies `BattleUnit` contract +
  `HPStatusController.initialize_battle(unit_roster: Array[BattleUnit])` invocation
  shape; HP/Status epic stories use a stub or interface-by-shape approach until
  Battle Preparation ADR lands.
- **Hero DB `is_morale_anchor: bool` field** (NOT YET in ADR-0007 ratified schema —
  DEFERRED post-MVP per OQ-2). MVP DEMORALIZED triggers ONLY via condition (a)
  Commander class auto-trigger and condition (c) direct skill apply; condition (b)
  is-morale-anchor heroes deferred.

## Definition of Done

This epic is complete when:
- All stories are implemented, reviewed, and closed via `/story-done`
- All 20 hp-status GDD ACs (AC-01..AC-20) verified — Logic + Integration story
  types per `tests/unit/core/` + `tests/integration/core/` test-evidence rules
- All 18 TRs (TR-hp-status-001..018) status remains `active`; any
  Polish-deferred items logged as TD entries with reactivation triggers
- 27 BalanceConstants entries present in `assets/data/balance/balance_entities.json`
  with provenance comments + `lint_balance_entities_hp_status.sh` exit 0
- 5 `.tres` status-effect templates authored at `assets/data/status_effects/`
- 5+ forbidden_patterns registered in `docs/registry/architecture.yaml` + CI lint
  scripts wired into `.github/workflows/tests.yml`
- DI test seam (`_apply_turn_start_tick` direct call + `_map_grid` constructor
  injection) verified per Validation §5 in tests
- Cross-platform determinism headless CI deterministic-fixture test PASS
  (Validation §9; on-device deferred per Polish pattern)

## Next Step

Run `/create-stories hp-status` to break this epic into implementable stories
(~6-8 stories estimated, comparable to turn-order/hero-database precedent;
~18-24h total estimate).
