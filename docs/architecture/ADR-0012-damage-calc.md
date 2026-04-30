# ADR-0012: Damage Calculation System

## Status

Accepted (2026-04-26, via `/architecture-review` delta)

## Date

2026-04-26

## Last Verified

2026-04-26

## Decision Makers

- Technical Director (architecture owner)
- User (Sprint 1 S1-03 authorization, 2026-04-26)
- godot-specialist (engine validation 2026-04-26 — `/architecture-decision` 5 findings + `/architecture-review` delta APPROVED WITH SUGGESTIONS, 12/12 PASS, 2 wording corrections applied AF-1 + Item 3, 1 advisory carried AF-3)

## Summary

`design/gdd/damage-calc.md` (rev 2.9.3 APPROVED, 2333 lines, 53 ACs, 9-pass review) specifies a synchronous deterministic damage-resolution pipeline; this ADR locks the architectural shape — stateless `class_name DamageCalc` with a single `resolve()` static method, four typed `RefCounted` wrapper classes (`AttackerContext`, `DefenderContext`, `ResolveModifiers`, `ResolveResult`), direct-call interface from Grid Battle (no signals emitted per ADR-0001 non-emitter list), per-call seeded RNG injection, and the test-infrastructure prerequisites (headless + headed CI matrix, GdUnitTestSuite-extends-Node base for AC-DC-51(b) bypass-seam). The decision retires `F-GB-PROV` (the provisional damage formula in `grid-battle.md` §CR-5 Step 7) and registers `damage_resolve` as the canonical formula in `entities.yaml`.

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6 |
| **Domain** | Core — gameplay rules calculator |
| **Knowledge Risk** | **LOW** — no post-cutoff APIs. `RefCounted`, `class_name`, `Array[StringName]` typed-array parameter binding, `randi_range`, `snappedf`, `@export`, `StringName` literals (`&"…"`), `RandomNumberGenerator` are all pre-Godot-4.4 and stable across the project's pinned 4.6 baseline. |
| **References Consulted** | `docs/engine-reference/godot/VERSION.md`, `docs/engine-reference/godot/breaking-changes.md`, `docs/engine-reference/godot/current-best-practices.md`, `design/gdd/damage-calc.md` (rev 2.9.3), `design/gdd/grid-battle.md` (sole caller), `design/gdd/hp-status.md`, `design/gdd/terrain-effect.md`, `design/gdd/unit-role.md`, `design/gdd/turn-order.md`, `design/gdd/formation-bonus.md`, `design/gdd/balance-data.md`, `docs/architecture/ADR-0001-gamebus-autoload.md`, `docs/architecture/ADR-0008-terrain-effect.md`, `docs/architecture/architecture.md` §Core layer, `docs/registry/architecture.yaml` |
| **Post-Cutoff APIs Used** | None. The `AttackerContext.unit_class` field was renamed from `class` to avoid GDScript's `class` reserved keyword — note: `class` has been reserved since **Godot 4.0 / GDScript 2.0** (used for inner-class declaration `class Foo: ...`), not introduced in 4.6 as the GDD's rev 2.4 changelog implies. The rename is correct; the version attribution in the GDD is misleading and should be amended in a future GDD revision. All other APIs are pre-4.4. |
| **Verification Required** | (1) `randi_range(from, to)` inclusive on both ends — pin via AC-DC-49 (mandatory CI test). (2) `snappedf(0.005, 0.01) == 0.01` AND `snappedf(-0.005, 0.01) == -0.01` (round-half-away-from-zero) — pin via AC-DC-50 (mandatory CI test). (3) Mobile p99 latency `resolve()` < 1ms on minimum-spec device (ARMv8, ≥4GB RAM, Adreno 610 / Mali-G57 class, Android 12+/iOS 15+) — AC-DC-40(b), KEEP-through-implementation. (4) Cross-platform determinism baseline (macOS Metal per-push; Windows D3D12 + Linux Vulkan weekly + `rc/*` tag) — AC-DC-37; softened contract: divergence = WARN, not hard ship-block (until/unless an integer-only-math superseding ADR opens). (5) GdUnit4 addon pinning — record version in `tests/README.md` matching Godot 4.6 LTS line. |

> **Note**: Knowledge Risk is **LOW**. This ADR is unlikely to need re-validation on engine patch upgrades (4.6.x → 4.6.y). A move to Godot 4.7+ that touches `randi_range` / `snappedf` semantics or typed-array parameter binding would trigger Superseded-by review.

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0001 (GameBus, Accepted 2026-04-18) — Damage Calc is on the **non-emitter list**; ResolveResult is a pure return value, never a signal payload. ADR-0008 (Terrain Effect, Accepted 2026-04-25) — `terrain.get_combat_modifiers(atk, def) -> CombatModifiers` returning already-clamped `terrain_def ∈ [-30, +30]` and `terrain_evasion ∈ [0, 30]`; the cap constants `MAX_DEFENSE_REDUCTION = 30` and `MAX_EVASION = 30` are owned by ADR-0008, not this ADR. **ADR-0006 (Balance/Data, Accepted 2026-04-30 via /architecture-review delta #9 — RATIFIED)**: `BalanceConstants.get_const(key)` for 11 constants (9 consumed + 2 owned). ADR-0006 ratified the flat-JSON `BalanceConstants` wrapper pattern shipped in damage-calc story-006b PR #65 (2026-04-27); call sites at `assets/data/balance/balance_entities.json` are the locked MVP form. Future Alpha-pipeline migration is documented in ADR-0006 §Migration Path Forward (no calendar commitment); call-site `get_const(key) -> Variant` shape stable across the future migration. **ADR-0009 Unit Role (Accepted 2026-04-28 via `/architecture-review` delta)**: CLASS_DIRECTION_MULT[6][3] table + BASE_DIRECTION_MULT[3] vector, owned by Unit Role; Damage Calc consumes via Unit Role's read-only constant accessors. The 6×3 shape covers all 6 UnitClass enum members (CAVALRY, INFANTRY, ARCHER, STRATEGIST, COMMANDER, SCOUT); STRATEGIST and COMMANDER rows are all-1.0 no-ops by design per ADR-0009 §6 (their class identity is expressed elsewhere — Tactical Read evasion bypass + Rally adjacency aura, respectively). ADR-0012's earlier `[4][3]` reference was a stale documentation artifact corrected by ADR-0009 §6 ratification (one-line amendment applied 2026-04-28, no behavioral change). ADR-0009 ratified (did not negotiate) the table values locked by `unit-role.md` §EC-7 + `entities.yaml` registration; runtime read goes through `assets/data/config/unit_roles.json` per ADR-0009 §6 (per-class data locality), NOT through BalanceConstants. **ADR-0010 HP/Status (Accepted 2026-04-30 via /architecture-review delta #7 — RATIFIED)**: `hp_status.get_modified_stat(unit_id: int, stat_name: String) -> int` interface returning effective stats with all buffs/debuffs and DEFEND_STANCE penalty pre-folded; MIN_DAMAGE ≥ 1 contract per `hp-status.md:98`. **ADR-0011 Turn Order (Accepted 2026-04-30 via /architecture-review delta #8 — RATIFIED)**: `turn_order.get_acted_this_turn(unit_id: int) -> bool` for the Scout Ambush gate. **Cross-doc unit_id type advisory applied delta #8 (this patch)**: lines 91/109/340/343 `unit_id: StringName` → `unit_id: int` per ADR-0001 line 153 signal-contract source-of-truth lock; matches ADR-0010 UnitHPState `unit_id: int` + ADR-0011 UnitTurnState `unit_id: int` Dictionary key consistency. Internal Damage Calc ContextResource fields (lines 186/192/197/201) and call-site references (lines 260/352-353) retain implicit StringName semantics pending follow-up ADR-0012 amendment that will propagate `int` through AttackerContext/DefenderContext factories. |
| **Enables** | damage-calc Feature-layer epic creation (Sprint 1 S1-05 — `/create-epics damage-calc` + `/create-stories damage-calc`); replaces `grid-battle.md` §CR-5 Step 7's `F-GB-PROV` provisional formula in the same patch as `damage_resolve` registration in `entities.yaml`; unblocks AI Feature epic threat-scoring (calls `resolve()` through Grid Battle for damage previews); unblocks Battle HUD UI-2 damage-breakdown tooltip (consumes `ResolveResult.source_flags` for provenance display); unblocks Formation Bonus #3 implementation sprint (consumes `ResolveModifiers.formation_atk_bonus` / `formation_def_bonus` fields and the `P_MULT_COMBINED_CAP = 1.31` enforcement point in F-DC-5). |
| **Blocks** | damage-calc epic implementation (cannot start any story until this ADR is Accepted); AI Feature-layer epic stories that require damage previews; Battle HUD UI-2 tooltip implementation; Formation Bonus integration tests (D-7 Formation ATK sub-apex, D-8 Formation DEF path — AC-DC-52, AC-DC-53). |
| **Ordering Note** | Provisional-dependency strategy mirrors **ADR-0008 → ADR-0006 precedent** (ADR-0008 was Accepted 2026-04-25 with a soft-depend on the not-yet-written ADR-0006 Balance/Data; the workaround was direct `FileAccess` + `JSON.parse_string` config loading with a stable migration path when ADR-0006 lands). The same pattern applied here for ADR-0006 + 0009 + 0010 + 0011: ADR-0012 committed to the interface signatures **verbatim from the GDDs** that those four ADRs would eventually ratify. **All 4 upstream ADRs are now Accepted (ADR-0009 2026-04-28 / ADR-0010 2026-04-30 delta #7 / ADR-0011 2026-04-30 delta #8 / ADR-0006 2026-04-30 delta #9)** — the strategy proved sound; no narrowing changes occurred and no reciprocal ADR-0012 amendments were forced beyond the cross-doc `unit_id: int` type narrowing applied via deltas #7/#8 advisory batch (separate from the upstream ADRs' substantive contracts). |

## Context

### Problem Statement

`design/gdd/damage-calc.md` (Designed APPROVED, rev 2.9.3 close-out 2026-04-20, 53 ACs, 12 ordered Core Rules CR-1..CR-12, 7 sub-formulas F-DC-1..F-DC-7) is the most heavily reviewed gameplay-math GDD in the project — nine review passes, four user-adjudicated design decisions in the latest pass, and a fully-derived 12-cell apex-stack arithmetic verification. The math is settled. The architecture is not.

The architecture cannot proceed without locking nine questions:

1. **Module type** — autoload Node? Battle-scoped Node? Stateless static utility class? RefCounted singleton-by-convention? GDD §CR-1 says "stateless function `resolve(...)` … no internal mutable state, no signal emission, no I/O. Same inputs → same output." but does not lock the GDScript implementation form.
2. **Type boundary at the call site** — Grid Battle currently documents (lines 807–816) a Dictionary-shaped `modifiers` payload. GDD §CR-1 (rev 2.3) and §B GDScript Implementation Shape lock typed `RefCounted` wrappers (`AttackerContext`, `DefenderContext`, `ResolveModifiers`, `ResolveResult`). The migration is a cross-system ABI change.
3. **Direct-call vs. signal interface** — ADR-0001 lists Damage Calc on the non-emitter list, and §CR-1 / §CR-11 forbid signals on either side. But the boundary needs an explicit ADR commitment so future PRs cannot drift into "let's just emit a `damage_calculated` signal for VFX hooks."
4. **RNG ownership and injection** — Per-call seeded RNG via `ResolveModifiers.rng` (typed `RandomNumberGenerator`) is GDD-locked, but the architectural commitment that Damage Calc never owns RNG state, never subscribes to RNG signals, and never mutates RNG outside the injected handle's `randi_range` calls needs to be locked here.
5. **Tuning constant location** — All 11 constants (9 consumed + 2 owned: TK-DC-1 CHARGE_BONUS, TK-DC-2 AMBUSH_BONUS) must live in `assets/data/balance/entities.yaml`. Hardcoding would silently break Balance/Data's tuning governance. The ADR must lock this and forbid the alternative.
6. **Cap layering** — Three cap stages compose multiplicatively: `BASE_CEILING = 83` (pre-multipliers, F-DC-3 / CR-6), `P_MULT_COMBINED_CAP = 1.31` (post-passive-composition, F-DC-5 — rev 2.9 new), `DAMAGE_CEILING = 180` (post-direction-passive, F-DC-6 / CR-9). Order is non-negotiable; the ADR must lock the layering or apex-arithmetic verification will drift.
7. **Cross-system READ-ONLY interfaces** — Five upstream systems are read-only consumers (HP/Status, Terrain Effect, Unit Role, Turn Order, Balance/Data). Signature locking is required even for the four whose ADRs are not yet written.
8. **F-GB-PROV retirement** — `grid-battle.md` §CR-5 Step 7 currently defines `F-GB-PROV` as the provisional damage formula. Per OQ-DC-2 (Section D), `damage_resolve` REPLACES it for MVP. The ADR must commit to the same-patch obligation: `entities.yaml` registration of `damage_resolve` AND removal of `F-GB-PROV` from `grid-battle.md` ship together; static lint enforces post-patch.
9. **Test infrastructure prerequisites** — AC-DC-37 / AC-DC-46 / AC-DC-47 / AC-DC-50 / AC-DC-51(b) collectively require: (a) headless CI per push, (b) headed CI via `xvfb-run` weekly + `rc/*` tag, (c) cross-platform matrix macOS-Metal/Windows-D3D12/Linux-Vulkan, (d) GdUnitTestSuite extends Node base for `@onready` test helpers, (e) gdUnit4 addon pinned at version matching Godot 4.6 LTS line. Without these prerequisites, AC-DC-25/37/46/47/50 are un-enforceable at the Beta gate. The ADR must lock the prerequisites as Validation Criteria.

### Current State

`grid-battle.md` §CR-5 Step 7 documents `F-GB-PROV` (the provisional damage formula). It is a Dictionary-payload pseudocode that does not match the GDD-locked typed-RefCounted wrapper signatures, does not include rev 2.4 BASE_CEILING=83, does not include rev 2.7 Rally bonus, does not include rev 2.9 Formation bonus + P_MULT_COMBINED_CAP=1.31, and does not include rev 2.4 flagged-MISS source_flag vocabulary. Continuing to ship code against `F-GB-PROV` would (a) break the apex-arithmetic verification (179→178 pre/post P_MULT_COMBINED_CAP), (b) regress Pillar-1 differentiation, and (c) leave `Array[String]` payloads in attacker.passives — a silent-wrong-answer correctness hole per AC-DC-51 / EC-DC-25.

The `damage_calc.gd` source file does not yet exist in `src/core/` or `src/feature/`. No tests exist in `tests/unit/damage_calc/`. The `tests/integration/damage_calc/` directory is empty.

### Constraints

**From `design/gdd/damage-calc.md` (rev 2.9.3 APPROVED, locked by 9-pass review):**

- 12 ordered Core Rules (CR-1..CR-12) defining the resolution pipeline.
- 7 sub-formulas (F-DC-1..F-DC-7) with line-by-line GDScript skeletons.
- 53 unique acceptance criteria across 11 categories (FORMULA 12 / EDGE_CASE BLOCKER 15 / EDGE_CASE IMPORTANT 7 / CONTRACT 4 / DETERMINISM 3 / PERFORMANCE 2 / INTEGRATION 3 / ACCESSIBILITY 3 / TUNING 1 / VERIFY-ENGINE 2 / CONTRACT rev 2.2 1).
- 27 mandatory-coverage-floor ACs; 37 Vertical Slice blockers.
- Worked examples D-1 through D-10 are mandatory CI fixtures (AC-DC-01..10 + AC-DC-52, AC-DC-53).
- Apex hardest primary-path hit: Cavalry REAR + Charge + Rally(+10%) + Formation(+5%) ATK 200 vs DEF 10 → `floori(83 × 1.64 × 1.31) = 178` post P_MULT_COMBINED_CAP. DAMAGE_CEILING=180 silent (does NOT fire on primary path; fires only under EC-DC-9 synthetic dual-passive bypass).
- Pillar-1 peak differentiation: ≥27pt at no-Rally / ≥29pt at max-Rally between REAR-only and REAR+Charge.

**From `design/gdd/grid-battle.md` (sole caller, lines 807–816):**

- `damage_resolve` is invoked once per primary attack and once per counter-attack (CR-6 sequence).
- Counter halving (×0.5) is the FINAL stage on the counter path (composes cleanly with all earlier multipliers).
- `attacker_data`, `defender_data`, `modifiers` are the call-site fields — they migrate to typed RefCounted wrappers in the same patch as F-GB-PROV retirement.

**From `design/gdd/hp-status.md` lines 98, 271–273, 508; §F-1:**

- `get_modified_stat(unit_id: int, stat_name: String) -> int` returns effective stat with all buffs/debuffs and DEFEND_STANCE penalty pre-folded. (`unit_id: int` per ADR-0001 line 153 signal-contract lock + ADR-0010 UnitHPState Dictionary[int, UnitHPState] key — type narrowed from StringName via /architecture-review delta #8 same-patch advisory batch.)
- `MIN_DAMAGE = 1` is owned by HP/Status; Damage Calc enforces `≥ MIN_DAMAGE` at CR-9 floor.
- DEFEND_STANCE damage-taken reduction (-50%) is HP/Status's intake-pipeline responsibility, not Damage Calc's.

**From `design/gdd/terrain-effect.md` §Method 2 lines 178–183 (ratified by ADR-0008):**

- `terrain.get_combat_modifiers(atk_coord, def_coord) -> CombatModifiers` already-clamped: `terrain_def ∈ [-30, +30]`, `terrain_eva ∈ [0, 30]`.
- `MAX_DEFENSE_REDUCTION = 30` and `MAX_EVASION = 30` cap constants are owned by ADR-0008, not this ADR.
- `bridge_no_flank` flag (CR-5b) decorates `MapGrid.get_attack_direction` output for BRIDGE tiles — Damage Calc consumes; Terrain Effect produces.

**From `design/gdd/unit-role.md` §EC-7 lines 180–193, 503–506:**

- CLASS_DIRECTION_MULT[6 classes][3 directions] table — Cavalry/Infantry/Archer/Strategist/Commander/Scout × FRONT/FLANK/REAR (Strategist + Commander rows are all-1.0 no-ops by design per ADR-0009 §6; class identity expressed elsewhere — Tactical Read evasion bypass + Rally adjacency aura, respectively). Cavalry REAR = 1.09 (rev 2.8, was 1.20 pre-Rally-cap-fix). Ratified by ADR-0009 §6 (Accepted 2026-04-28).
- BASE_DIRECTION_MULT[3 directions] vector: FRONT 1.00 / FLANK 1.20 / REAR 1.50.
- Multiplicative ordering `D_mult = base × class` is non-negotiable.

**From `design/gdd/turn-order.md` lines 397, 401, 407–408:**

- `get_acted_this_turn(unit_id: int) -> bool` for Scout Ambush gate. (`unit_id: int` per ADR-0001 line 153 signal-contract lock + ADR-0011 UnitTurnState Dictionary[int, UnitTurnState] key — type narrowed from StringName via /architecture-review delta #8 same-patch advisory batch.)
- `modifiers.round_number` is supplied by Grid Battle (caller owns round context); Damage Calc does NOT subscribe to `round_started`.

**From `design/gdd/balance-data.md` lines 206, 334:**

- `DataRegistry.get_const(key) -> float | int` for the 9 consumed + 2 owned constants.
- Hardcoding any of `BASE_CEILING, DAMAGE_CEILING, COUNTER_ATTACK_MODIFIER, MIN_DAMAGE, MAX_DEFENSE_REDUCTION, MAX_EVASION, ATK_CAP, DEF_CAP, DEFEND_STANCE_ATK_PENALTY, CHARGE_BONUS, AMBUSH_BONUS, P_MULT_COMBINED_CAP` in `damage_calc.gd` is a blocker bug.

**From `docs/architecture/ADR-0001-gamebus-autoload.md` (Damage Calc non-emitter list, line 375):**

- Damage Calc is explicitly listed as a non-emitter. It owns ZERO signals, subscribes to ZERO signals, and is therefore not a dependency target for any signal subscriber.

**From `.claude/docs/technical-preferences.md`:**

- GDScript with static typing mandatory.
- Mobile performance budgets: 60 fps / 16.6 ms frame budget.
- Test coverage floor: 100% for balance formulas (Damage Calc included), 80% for gameplay systems.
- Naming conventions: PascalCase classes (`DamageCalc`, `AttackerContext`, etc.), snake_case fields, `&"foo"` StringName literals.

**From `docs/architecture/architecture.md` §Feature layer:**

- Damage Calc is a Feature-layer module (not Core, not Foundation): Core layer = Unit Role / HP/Status / Turn Order; Feature layer = Damage Calc / Grid Battle / AI / Formation Bonus.
- Layer-invariant verification: Damage Calc → HP/Status (Core ✅) + Terrain Effect (Core ✅) + Unit Role (Core ✅) + Turn Order (Core ✅) + Balance/Data (Foundation ✅) — clean downward dependencies.

### Requirements

**Functional**:

- Provide a single entry point `DamageCalc.resolve(attacker: AttackerContext, defender: DefenderContext, modifiers: ResolveModifiers) -> ResolveResult`.
- Define and expose the 4 typed `RefCounted` wrapper classes with `class_name` declarations and static factory methods (`AttackerContext.make(...)`, etc.).
- Implement the 12-stage pipeline (CR-1..CR-12) including the 3-tier cap layering (BASE_CEILING pre-multipliers, P_MULT_COMBINED_CAP post-passive-composition, DAMAGE_CEILING final).
- Read all tuning constants via `DataRegistry.get_const(key)` — never hardcode.
- Read upstream effective stats via `hp_status.get_modified_stat(...)`, `terrain.get_combat_modifiers(...)`, `turn_order.get_acted_this_turn(...)` — never read raw stats from Hero DB or `Unit.atk` / `Unit.phys_def`.
- Return `ResolveResult.HIT(...)` or `ResolveResult.MISS(source_flags)` per CR-11 contract; `source_flags` always a NEW `Array[StringName]` (never mutate caller).
- Retire `F-GB-PROV` in `grid-battle.md` §CR-5 Step 7 in the same patch as `entities.yaml` registration.

**Non-functional**:

- Stateless: zero fields on `DamageCalc`; zero per-battle initialization; zero per-battle teardown.
- Signal-free: ZERO emits, ZERO subscriptions (ADR-0001 enforcement).
- Deterministic: same inputs → same output across all platforms (softened: cross-platform divergence = WARN per AC-DC-37, not hard ship-block).
- Idempotent: re-calling with the same RNG snapshot reproduces the same result bit-identically.
- Performance: 10,000 calls in headless CI under 500ms (50µs avg per AC-DC-40(a)); mobile p99 < 1ms on minimum-spec device (AC-DC-40(b), KEEP-through-implementation).
- Zero Dictionary allocations inside `resolve()` body (excluding the `build_vfx_tags` helper) per AC-DC-41; static lint via grep for `Dictionary(` and standalone `{` in reachable functions returns 0 matches.

## Decision

### 1. Module Type — Stateless `class_name DamageCalc` with Static `resolve()` Method

`DamageCalc` is declared with `class_name DamageCalc` and `extends RefCounted`, exposing `resolve(attacker, defender, modifiers) -> ResolveResult` as a **static method**. No instance is ever constructed in production code paths. The class exists to give `class_name`-grep-able discoverability and to serve as the namespace for related private helpers (`_evasion_check`, `_stage_1_base_damage`, `_direction_multiplier`, `_passive_multiplier`, `_stage_2_raw_damage`, `_counter_reduction`).

```gdscript
class_name DamageCalc
extends RefCounted

# Static — called via DamageCalc.resolve(...)
static func resolve(attacker: AttackerContext,
                    defender: DefenderContext,
                    modifiers: ResolveModifiers) -> ResolveResult:
    # 12-stage pipeline per CR-1..CR-12. No state, no signals, no I/O.
    ...
```

**Why this form (vs. autoload, vs. Node, vs. plain GDScript module file):**

- **Stateless invariant is structurally enforced** — no instance state can leak because the call form forbids instances. Future `class_name DamageCalc` accidentally adding `var _last_result` as a "memoization" optimization is statically detectable via lint.
- **`class_name` discoverability** — Grid Battle code reads `DamageCalc.resolve(...)` not `damage_calc.resolve(...)`, matching project naming conventions and inspector-typed-constant semantics.
- **Test-bypass seams via private helpers** — `DamageCalc._passive_multiplier(...)` is callable from `tests/unit/damage_calc/damage_calc_test.gd` for AC-DC-51(b) StringName-literal bypass-seam coverage without exposing them in the public API.
- **Autoload form rejected** — `/root/DamageCalc` would tempt signal emissions, which violates ADR-0001's non-emitter list (line 375). Autoload is for systems that emit, subscribe, or hold cross-scene state; Damage Calc does none.
- **Node-extends form rejected** — A `Node` instance would have a SceneTree lifecycle (enter/exit notifications, free), implying state. The pure-function nature of the system makes Node form an architectural lie.

### 2. Type Boundary — 4 Typed `RefCounted` Wrapper Classes

Replace Grid Battle's current Dictionary-shaped payload (lines 807–816) with 4 typed `RefCounted` wrapper classes, each declared via `class_name` and with a static `make(...)` factory:

```gdscript
class_name AttackerContext extends RefCounted
var unit_id: StringName
var unit_class: UnitRole.Class      # rev 2.4 rename — `class` has been a reserved keyword since Godot 4.0 / GDScript 2.0 (inner-class declaration), NOT a 4.6 introduction
var charge_active: bool = false
var defend_stance_active: bool = false
var passives: Array[StringName] = []   # TYPED — Array[String] is a silent-wrong-answer hole

static func make(unit_id: StringName, unit_class: UnitRole.Class,
                 charge_active: bool, defend_stance_active: bool,
                 passives: Array[StringName]) -> AttackerContext: ...

class_name DefenderContext extends RefCounted
var unit_id: StringName
var terrain_def: int                # already clamped [-30, +30] by Terrain Effect
var terrain_evasion: int            # already clamped [0, 30] by Terrain Effect

static func make(unit_id: StringName, terrain_def: int,
                 terrain_evasion: int) -> DefenderContext: ...

class_name ResolveModifiers extends RefCounted
enum AttackType { PHYSICAL, MAGICAL }

var attack_type: AttackType = AttackType.PHYSICAL
var source_flags: Array[StringName] = []
var direction_rel: StringName = &"FRONT"   # FRONT / FLANK / REAR — StringName literals only
var is_counter: bool = false
var skill_id: String = ""                  # "" = not a skill stub
var rng: RandomNumberGenerator             # typed; never Variant
var round_number: int = 1                  # ≥ 1 (gate asserts); supplied by Grid Battle
var rally_bonus: float = 0.0               # [0.0, 0.10] — upstream-capped in Grid Battle CR-15
var formation_atk_bonus: float = 0.0       # [0.0, 0.05] — upstream-capped in Formation Bonus F-FB-3
var formation_def_bonus: float = 0.0       # [0.0, 0.05] — upstream-capped in Formation Bonus F-FB-3

static func make(attack_type: AttackType, rng: RandomNumberGenerator,
                 direction_rel: StringName, round_number: int,
                 is_counter: bool = false, skill_id: String = "",
                 source_flags: Array[StringName] = [],
                 rally_bonus: float = 0.0,
                 formation_atk_bonus: float = 0.0,
                 formation_def_bonus: float = 0.0) -> ResolveModifiers: ...

class_name ResolveResult extends RefCounted
enum Kind { HIT, MISS }
enum AttackType { PHYSICAL, MAGICAL }

var kind: Kind
var resolved_damage: int = 0               # [1, 180] on HIT; 0 on MISS (immaterial)
var attack_type: AttackType = AttackType.PHYSICAL
var source_flags: Array[StringName] = []   # NEVER Set, NEVER Dictionary
var vfx_tags: Array[StringName] = []

static func hit(damage: int, atk_type: AttackType,
                flags: Array[StringName],
                vfx: Array[StringName]) -> ResolveResult: ...

static func miss(flags: Array[StringName] = []) -> ResolveResult: ...
```

**Why typed RefCounted wrappers (vs. Dictionary):**

- **`Array[StringName]` parameter binding** is enforced by GDScript 4.6 at the call-site boundary. Mismatched `Array[String]` produces a **runtime type error or silent element-level mismatch** (NOT a hard parse error — typed-array binding is enforced at assignment / insertion / parameter-bind time, not at static parse time) at Grid Battle's `DamageCalc.resolve(...)` call rather than a silent-wrong-answer inside F-DC-5 where `&"passive_charge"` literal comparisons silently return `false` (P_mult stays 1.00 despite the unit having the passive — the canonical EC-DC-25 correctness hole). The release-build defense is the StringName literal comparison itself: even if the type boundary is bypassed (test seam or untyped Variant), `&"passive_charge" in attacker.passives` returns `false` against `Array[String]` elements.
- **Inspector authoring affordance** — typed RefCounted wrappers are inspectable in editor when used as test fixtures.
- **Static-typing discipline carries through** — `attacker.unit_class` returns `UnitRole.Class` enum, not `Variant`; misuse is caught at parse time.
- **`make(...)` factory pattern** — caller constructs via `AttackerContext.make(...)` rather than dict literal; signature mismatches are parse errors.

**Forbidden alternative: Dictionary payload** (REJECTED). The current `grid-battle.md:807–816` Dictionary form is an anti-pattern carried from rev 2.2 brief; rev 2.3 fix made it a typed-wrapper boundary. Reinstating Dictionary here would silently re-open EC-DC-25 (Array[String] passive leakage) and AC-DC-51 (silent-fail StringName guard). Banned per `forbidden_patterns` registry entry `damage_calc_dictionary_payload` (registered alongside this ADR).

### 3. Direct-Call Interface — Grid Battle → DamageCalc.resolve()

The Grid Battle → Damage Calc boundary is **direct-call**, not signal-driven.

```gdscript
# grid-battle.gd, inside Grid Battle's CR-5 Step 7 attack-resolution path
var result: ResolveResult = DamageCalc.resolve(attacker_ctx, defender_ctx, modifiers)
if result.kind == ResolveResult.Kind.HIT:
    hp_status.apply_damage(defender.unit_id, result.resolved_damage,
                           result.attack_type, result.source_flags)
# MISS path: no apply_damage call (per AC-DC-43, hp-status.md:98)
```

`hp_status.apply_damage(...)` is called **by Grid Battle, never by Damage Calc**. The cross-system invariant is locked here: Damage Calc has zero outbound calls into HP/Status's mutation API. This preserves the call-graph clarity Grid Battle owns (it is the orchestrator) and prevents Damage Calc from accumulating a signal-emission shortcut.

**Forbidden alternative: signal-driven resolution** (REJECTED). A `damage_resolved(result)` signal would (a) violate ADR-0001's non-emitter list, (b) decouple call-count discipline (AC-DC-42 requires exactly 2 calls per primary HIT → counter; signal subscribers cannot be reliably counted without a registry layer), and (c) split the responsibility for `apply_damage` between Grid Battle and the signal handler. Banned per `forbidden_patterns` registry entry `damage_calc_signal_emission`.

### 4. Stateless / Signal-Free Invariant

`DamageCalc` declares ZERO instance fields. The class body contains only `static func` declarations (the public `resolve` plus private helpers). No `_init` constructor, no `_ready`, no `_process` (it's not a Node), no autoload registration. ADR-0001 enforcement: Damage Calc emits ZERO signals and subscribes to ZERO signals. The architecture-registry entry `damage_resolution` is a `direct_call` interface, never a `signal` interface.

### 5. RNG Ownership — Per-Call Seeded Injection

`ResolveModifiers.rng: RandomNumberGenerator` is injected by the caller (Grid Battle) on every call. Damage Calc:

- Calls `modifiers.rng.randi_range(1, 100)` exactly **once per non-counter attack** (the Stage-0 evasion roll, F-DC-2).
- Calls `randi_range` exactly **zero times per counter attack** (counter path skips evasion entirely per CR-2).
- Calls `randi_range` exactly **zero times per skill-stub MISS** (F-DC-1 returns immediately on `modifiers.skill_id != ""`).
- NEVER subscribes to `round_started` or any RNG-related signal.
- NEVER mutates `modifiers.rng` outside the `randi_range` call (which advances the seed per Godot's `RandomNumberGenerator` contract).

**Determinism contract**: Save/Load (#21) snapshots Grid Battle's RNG handle; Damage Calc's call-count-stable contract (1/0/0 per path) means replaying from the snapshot reproduces identical outputs bit-for-bit. AC-DC-39 verifies this via snapshot-restore-replay.

### 6. Tuning Constants — `entities.yaml` Only

All 11 constants live in `assets/data/balance/entities.yaml` and are read via `DataRegistry.get_const(key)`:

| Constant | Owner | Value (rev 2.9) | Safe Range |
|---|---|---|---|
| `BASE_CEILING` | Damage Calc consumer (set by Balance/Data) | 83 | locked-not-tunable |
| `DAMAGE_CEILING` | Damage Calc consumer | 180 | locked-not-tunable |
| `COUNTER_ATTACK_MODIFIER` | Damage Calc consumer | 0.5 | [0.4, 0.6] |
| `MIN_DAMAGE` | HP/Status owner | 1 | locked-not-tunable |
| `MAX_DEFENSE_REDUCTION` | Terrain Effect owner (ADR-0008) | 30 | locked-not-tunable |
| `MAX_EVASION` | Terrain Effect owner (ADR-0008) | 30 | locked-not-tunable |
| `ATK_CAP` | HP/Status owner | 200 | game-design-tier |
| `DEF_CAP` | HP/Status owner | 105 | rev 2.9.2 [1,100]→[1,105] |
| `DEFEND_STANCE_ATK_PENALTY` | HP/Status owner | 0.40 | game-design-tier |
| **`CHARGE_BONUS`** (NEW, **TK-DC-1 — owned here**) | Damage Calc | 1.20 | [1.05, 1.30] |
| **`AMBUSH_BONUS`** (NEW, **TK-DC-2 — owned here**) | Damage Calc | 1.15 | [1.05, 1.25] |
| `P_MULT_COMBINED_CAP` | Damage Calc owner (rev 2.9 NEW) | 1.31 | locked-not-tunable |

**Forbidden alternative: hardcoded constants** (REJECTED). Any `const BASE_CEILING := 83` or `const CHARGE_BONUS := 1.20` literal in `damage_calc.gd` is a blocker bug per `balance-data.md`. Banned per `forbidden_patterns` registry entry `hardcoded_damage_constants`.

### 7. Cap Layering — Three-Tier Composition Order

```
base_damage = floori(eff_atk - eff_def × defense_mul)
            ↓ floor at MIN_DAMAGE=1, ceiling at BASE_CEILING=83
            ↓
base_damage ∈ [1, 83]
            ↓
            × D_mult       (CR-7: base_direction × class_direction, snappedf to 0.01)
            × P_mult       (CR-8: Charge × Ambush × Rally × Formation, all multiplicatively
                            composed, then clamped to P_MULT_COMBINED_CAP=1.31 — rev 2.9)
            ↓
raw_damage = floori(base_damage × D_mult × P_mult)
           ↓ floor at MIN_DAMAGE=1, ceiling at DAMAGE_CEILING=180
           ↓
raw_damage ∈ [1, 180]
           ↓
           × COUNTER_ATTACK_MODIFIER (CR-10, ONLY if is_counter=true)
           ↓
resolved_damage = floori(raw_damage × 0.5)   if is_counter
                = raw_damage                 otherwise
                ↓ floor at MIN_DAMAGE=1
                ↓
resolved_damage ∈ [1, 180]   (counter path: ∈ [1, 90])
```

Order is non-negotiable. Apex arithmetic verification: Cavalry REAR + Charge + Rally(+10%) + Formation(+5%): `D_mult = 1.50 × 1.09 = 1.6350 → snappedf = 1.64`; pre-cap `P_mult = 1.20 × 1.10 × 1.05 = 1.386`; clamp to `P_MULT_COMBINED_CAP = 1.31`; `raw = floori(83 × 1.64 × 1.31) = 178`. DAMAGE_CEILING=180 silent (does NOT fire on primary path; fires only under EC-DC-9 synthetic dual-passive bypass). Pillar-1 differentiation 29pt at peak.

### 8. Cross-System Read-Only Interfaces (5 Upstreams)

The five upstream interfaces are read-only, locked here, ratifiable by upstream ADRs. None of these are signal subscriptions; all are direct calls.

| Upstream | Call Signature | Source GDD | Future ADR |
|---|---|---|---|
| **HP/Status** | `hp_status.get_modified_stat(unit_id: int, stat_name: String) -> int` | `hp-status.md:508`, §F-1 | ADR-0010 (Accepted 2026-04-30 delta #7 — RATIFIED; type narrowed StringName → int delta #8) |
| **Terrain Effect** | `terrain.get_combat_modifiers(atk: Vector2i, def: Vector2i) -> CombatModifiers` returning `{terrain_def: int [-30,+30], terrain_eva: int [0,30], elevation_atk_mod: int, elevation_def_mod: int, special_rules: Dictionary}` | `terrain-effect.md` §Method 2, lines 178–183 | ADR-0008 (Accepted 2026-04-25 — locked) |
| **Unit Role** | Constants: `UnitRole.BASE_DIRECTION_MULT[3]`, `UnitRole.CLASS_DIRECTION_MULT[6][3]` (6 UnitClass enum members; Strategist + Commander rows all-1.0 no-ops by design). Both compile-time tables. | `unit-role.md` §EC-7, lines 180–193, 503–506 | ADR-0009 (Accepted 2026-04-28) |
| **Turn Order** | `turn_order.get_acted_this_turn(unit_id: int) -> bool` | `turn-order.md` lines 397, 401, 407–408 | ADR-0011 (Accepted 2026-04-30 delta #8 — RATIFIED; type narrowed StringName → int delta #8) |
| **Balance/Data** | `BalanceConstants.get_const(key: String) -> Variant` (typed by caller; MVP form per ADR-0006 §Decision 2; future Alpha rename to `DataRegistry.get_const(key)` is mechanical per ADR-0006 §Migration Path Forward) | `balance-data.md` lines 206, 334; `assets/data/balance/balance_entities.json` | ADR-0006 (Accepted 2026-04-30 via /architecture-review delta #9 — RATIFIED) |

**Provisional-dependency contract — RESOLVED 2026-04-30**: ADR-0009 (Accepted 2026-04-28), ADR-0010 (Accepted 2026-04-30 delta #7), ADR-0011 (Accepted 2026-04-30 delta #8), and **ADR-0006 (Accepted 2026-04-30 via delta #9)** ratified the interfaces above without behavioral modification — only `unit_id: StringName → int` type narrowing applied via /architecture-review delta #8 same-patch advisory batch (per ADR-0001 line 153 signal-contract source-of-truth lock + ADR-0010 / ADR-0011 Dictionary[int, *] key consistency). All 4 upstream provisional dependencies now Accepted. If any upstream ADR proposes a change to the interface, it must include a reciprocal ADR-0012 amendment in the same patch (`/architecture-review` cross-conflict detection enforces).

**Call-site ownership** *(added 2026-04-26 per damage-calc story-004 design-gap resolution)*: All 5 upstream interfaces above are invoked at the **Grid Battle orchestrator boundary**, not from within `DamageCalc.resolve()`. Grid Battle reads upstream values and passes the extracted data to `DamageCalc` via the typed `AttackerContext` / `DefenderContext` / `ResolveModifiers` wrappers. `DamageCalc` consumes pre-extracted data; it never holds a reference to any upstream singleton or invokes any upstream API.

Wrapper fields carrying upstream data (story-004 lockdown):

- `AttackerContext.raw_atk: int` — return value of `hp_status.get_modified_stat(unit_id, &"atk")`. Pre-clamp; CR-3 `clampi(raw_atk, 1, ATK_CAP)` applied inside `DamageCalc` (AC-DC-11/15).
- `DefenderContext.raw_def: int` — return value of `hp_status.get_modified_stat(unit_id, def_stat)` where `def_stat ∈ {&"phys_def", &"mag_def"}` is selected by Grid Battle from `modifiers.attack_type`. Pre-clamp; CR-3 `clampi(raw_def, 1, DEF_CAP)` applied inside `DamageCalc`.
- `DefenderContext.terrain_def`, `terrain_evasion` — pre-clamped per ADR-0008 (existing precedent for this convention).

This amendment is **non-substantive with respect to interface signatures**: the 5 row signatures above remain the contracts upstream ADRs (0006/0009/0010/0011) will ratify. It clarifies *who* invokes them (Grid Battle), not *what* the signatures are. Pseudocode in `damage-calc.md` §F-DC-3 line 465 (`eff_atk = clampi(hp_status.get_modified_stat(...), 1, ATK_CAP)`) is illustrative of the read-and-clamp logic flow; the actual call site for `get_modified_stat()` is in Grid Battle, with the result flowing through `AttackerContext.raw_atk`.

### 9. F-GB-PROV Retirement — Same-Patch Obligation

`grid-battle.md` §CR-5 Step 7 currently defines `F-GB-PROV` as the provisional damage formula with a Dictionary-payload pseudocode. Per OQ-DC-2 (Section D of damage-calc.md) and AC-DC-44, this ADR commits to:

1. Removing `F-GB-PROV` from `grid-battle.md` §CR-5 Step 7 in the **same patch** as `entities.yaml` registration of `damage_resolve`.
2. `grid-battle.md` §CR-5 Step 7 is rewritten to cite `damage-calc.md` §F-DC-1 and call `DamageCalc.resolve(...)` directly.
3. Static lint (CI grep) returns 0 matches for `F-GB-PROV` in `design/` post-patch.
4. The same-patch obligation is enforced by AC-DC-44 (CI gate).

### 10. Test Infrastructure Prerequisites — 5 Items

The following CI infrastructure prerequisites MUST exist before damage-calc Feature epic stories can begin:

1. **Headless CI matrix per push** — Linux runner, GdUnit4 + headless Godot, runs FORMULA / EDGE_CASE / CONTRACT / DETERMINISM / PERFORMANCE / TUNING / VERIFY-ENGINE / non-UI INTEGRATION ACs (44 of 53 ACs).
2. **Headed CI via xvfb-run** — Linux runner with virtual display, runs UI INTEGRATION ACs requiring Control-node observation: AC-DC-46 (Reduce Motion lifecycle frame-trace), AC-DC-47 (monochrome screenshot capture). Cadence: weekly + every `rc/*` tag.
3. **Cross-platform determinism matrix** — macOS Metal per-push (baseline), Windows D3D12 + Linux Vulkan weekly + every `rc/*` tag, runs AC-DC-37 / AC-DC-50. Softened contract: divergence = WARN, not hard ship-block (until/unless an integer-only-math superseding ADR opens).
4. **GdUnitTestSuite extends Node** as the test base class for AC-DC-51(b) bypass-seam. Rationale: `@onready` decorator only valid on Node subclasses; required for lazy initialization of test-exposed Callables (`@onready var _passive_mul := Callable(...)`). RefCounted base (default GdUnit4 testing class) is rejected for AC-DC-51(b) only — other tests may use either base.
5. **gdUnit4 addon pinning** — `addons/gdUnit4/` committed at the GdUnit4 4.x version matching Godot 4.6 LTS. Pinned version recorded in `tests/README.md` AND `CLAUDE.md` Engine Specialists section. Required for `assert_eq` / `assert_that` assertions across all 53 ACs.

Without items 1–3, AC-DC-25/37/46/47/50 are un-enforceable at the Beta gate (hard blocker per damage-calc.md lines 2248-2264). Item 4 is a per-test-class choice (only AC-DC-51(b) requires Node base). Item 5 is a project-wide dependency.

### 11. Engine-Pin Tests — AC-DC-49 + AC-DC-50 Mandatory

Two engine-contract pin tests MUST run on every push (headless CI) AND every cross-platform matrix run:

- **AC-DC-49** — `randi_range(from, to)` inclusive on both ends. Test pattern: `for i in 1000: assert(rng.randi_range(1, 1) == 1); assert(rng.randi_range(1, 100) ∈ [1, 100])`. Pin source: Godot 4.0+ stable, verified at 4.6 against `docs/engine-reference/godot/`.
- **AC-DC-50** — `snappedf(0.005, 0.01) == 0.01` AND `snappedf(-0.005, 0.01) == -0.01` (round-half-away-from-zero). Pin source: Godot 4.0+ stable, verified at 4.6 against `docs/engine-reference/godot/`.

Failure of either is a hard CI fail (per AC-DC-49/50 NOT advisory). Cross-platform matrix divergence on AC-DC-50 is a critical-tier WARN (Linux Vulkan and macOS Metal have known IEEE-754 residue differences at ±0.005 boundary; the round-half-away-from-zero contract holds on all three platforms but the pre-`snappedf` floating residue may differ — this is the AC-DC-37 softened-determinism contract).

### 12. `source_flags` Mutation Semantics — Always New Array

`resolve()` ALWAYS constructs a NEW `Array[StringName]` for `ResolveResult.source_flags`, copying from `modifiers.source_flags` and appending internal flags (e.g., `&"counter"`, `&"charge"`, `&"ambush"`, `&"evasion"`, `&"invariant_violation:<reason>"`). NEVER mutates the caller's `modifiers.source_flags` array.

```gdscript
# inside resolve()'s HIT path
var out_flags: Array[StringName] = modifiers.source_flags.duplicate()
out_flags.append(&"counter") if modifiers.is_counter else null
# ... append charge, ambush, etc.
return ResolveResult.hit(resolved_damage, modifiers.attack_type, out_flags, vfx_tags)
```

This preserves caller-owned array immutability across the call boundary; tests can re-call `resolve()` with the same `modifiers` without observing flag accumulation.

### Architecture

```
                               ┌─────────────────────────────────────┐
                               │     Grid Battle (sole caller)       │
                               │  (Feature layer; ADR-future-Grid)   │
                               └──────┬───────────────────────┬──────┘
                                      │                       │
        ┌─────────────────────────────┼───────────────────────┼─────────────────────┐
        │                             ▼                       │                     │
        │   ┌──────────────────────────────────────────┐      │                     │
        │   │         DamageCalc.resolve(...)          │      │                     │
        │   │  (stateless static; class_name DamageCalc) │     │                     │
        │   │                                          │      │                     │
        │   │  CR-1..CR-12 pipeline:                   │      │                     │
        │   │    Stage 0   invariant guards            │      │                     │
        │   │    Stage 0.5 evasion roll (F-DC-2)       │      │                     │
        │   │    Stage 1   base damage (F-DC-3)        │      │                     │
        │   │              ↑ BASE_CEILING=83 cap       │      │                     │
        │   │    Stage 2   direction multiplier (F-DC-4)│     │                     │
        │   │    Stage 2.5 passive multiplier (F-DC-5) │      │                     │
        │   │              ↑ P_MULT_COMBINED_CAP=1.31  │      │                     │
        │   │    Stage 3   raw damage (F-DC-6)         │      │                     │
        │   │              ↑ DAMAGE_CEILING=180 cap    │      │                     │
        │   │    Stage 4   counter halve (F-DC-7)      │      │                     │
        │   │                                          │      │                     │
        │   │   READS (direct call, no signals):       │      │                     │
        │   └──────┬──────┬──────┬──────┬──────────────┘      │                     │
        │          │      │      │      │                     │                     │
        │          ▼      ▼      ▼      ▼                     │                     │
        │ ┌─────────┐ ┌────────┐ ┌──────┐ ┌─────────────┐     │                     │
        │ │HP/Status│ │Terrain │ │ Turn │ │Balance/Data │     │                     │
        │ │ get_mod │ │ Effect │ │Order │ │get_const(.)│      │                     │
        │ │ _stat() │ │get_combat│ │get_acted│         │      │                     │
        │ │  (read) │ │_modifiers│ │this_turn│         │      │                     │
        │ │         │ │ (ADR-0008 │  (read) │         │      │                     │
        │ │ ADR-0010│ │ Accepted)│ │ADR-0011 │ ADR-0006│      │                     │
        │ │ Accepted│ │          │ │ Accepted│ Accepted│      │                     │
        │ └─────────┘ └────────┘ └──────┘ └─────────────┘     │                     │
        │     ▲           ▲                                   │                     │
        │     │           │   Unit Role tables (compile-time const)                 │
        │     │           │   UnitRole.BASE_DIRECTION_MULT[3]                       │
        │     │           │   UnitRole.CLASS_DIRECTION_MULT[6][3]                   │
        │     │           │   ADR-0009 (future — provisional)                       │
        │     │           │                                                         │
        │     ▼           │                                                         │
        │  ResolveResult.HIT(resolved_damage, attack_type,                          │
        │                    source_flags, vfx_tags)                                │
        │                  ┌──────────────────────────────┐                         │
        └──────────────────┤   Grid Battle dispatches:    ◀────────────────────────┘
                           │                              │
                           │   if HIT:                    │
                           │     hp_status.apply_damage(  │   ────►  HP/Status #12
                           │       unit_id, damage,       │           (ADR-0010 future)
                           │       attack_type, flags)    │
                           │                              │
                           │   vfx_tags consumed by       │   ────►  Battle VFX #23
                           │     Battle VFX (deferred)    │           (no ADR yet)
                           │                              │
                           │   resolved_damage AND        │
                           │   source_flags consumed by   │   ────►  Battle HUD UI-2
                           │     Battle HUD UI-2 tooltip  │           damage breakdown
                           └──────────────────────────────┘

                     ZERO signals emitted by DamageCalc.
                     ZERO signal subscriptions.
                     ZERO instance state.
                     (per ADR-0001 non-emitter list, line 375)
```

### Key Interfaces

See **Decision §2** for the four `RefCounted` wrapper class declarations (`AttackerContext`, `DefenderContext`, `ResolveModifiers`, `ResolveResult`). The single `DamageCalc.resolve(...)` static method is the sole public entry point.

**Architecture Registry stance** (to be appended to `docs/registry/architecture.yaml` after Acceptance):

```yaml
interfaces:
  - contract: damage_resolution
    status: active
    pattern: direct_call
    producer: damage-calc           # DamageCalc.resolve() — static method
    consumers:
      - grid-battle                 # sole caller (per CR-1, AC-DC-42)
    adr: docs/architecture/ADR-0012-damage-calc.md
    method_signatures:
      - "DamageCalc.resolve(attacker: AttackerContext, defender: DefenderContext, modifiers: ResolveModifiers) -> ResolveResult"
    notes: "Stateless static method on class_name DamageCalc. ZERO signals (per ADR-0001 non-emitter list). ZERO state. ZERO outbound calls into mutator APIs (HP/Status's apply_damage is invoked by Grid Battle, NOT DamageCalc). Per-call seeded RNG via ResolveModifiers.rng (typed RandomNumberGenerator, never Variant). Determinism contract: 1 randi_range per non-counter, 0 per counter, 0 per skill stub."
    referenced_by:
      - docs/architecture/ADR-0001-gamebus-autoload.md  # non-emitter list
      - docs/architecture/ADR-0008-terrain-effect.md    # Damage Calc consumer of get_combat_modifiers
      - docs/architecture/ADR-0012-damage-calc.md
    added: 2026-04-26
```

### Implementation Guidelines

1. **File location**: `src/feature/damage_calc/` (Feature layer per architecture.md). The 5 GDScript files:
   - `src/feature/damage_calc/damage_calc.gd` — `class_name DamageCalc`
   - `src/feature/damage_calc/attacker_context.gd` — `class_name AttackerContext`
   - `src/feature/damage_calc/defender_context.gd` — `class_name DefenderContext`
   - `src/feature/damage_calc/resolve_modifiers.gd` — `class_name ResolveModifiers`
   - `src/feature/damage_calc/resolve_result.gd` — `class_name ResolveResult`

2. **Test location**: `tests/unit/damage_calc/damage_calc_test.gd` (FORMULA / EDGE_CASE / CONTRACT / DETERMINISM / PERFORMANCE / TUNING / VERIFY-ENGINE) + `tests/integration/damage_calc/damage_calc_integration_test.gd` (INTEGRATION non-UI) + `tests/integration/damage_calc/damage_calc_ui_test.gd` (ACCESSIBILITY UI; xvfb-run).

3. **Factory enforcement** — All test fixtures construct contexts via `AttackerContext.make(...)` / `DefenderContext.make(...)` / `ResolveModifiers.make(...)`. Direct field-by-field construction (`var ctx = AttackerContext.new(); ctx.unit_id = &"foo"; ctx.passives = ["bad"]`) is reserved for AC-DC-51(b) bypass-seam tests only.

4. **Error-flag vocabulary** — All invariant violations return `ResolveResult.miss([..., &"invariant_violation:<reason>"])` AND call `push_error("<human-readable>")` once per guard. Reasons: `rng_null`, `bad_attack_type`, `unknown_direction`, `unknown_class`. Tests assert on `result.source_flags.has(&"invariant_violation:rng_null")` — never on `Engine.get_error_count()` (that API does not exist; use of which would constitute a fabricated-API regression per the rev 2.4 source-flag redesign).

5. **`build_vfx_tags` exception** — `build_vfx_tags(...)` is the single helper allowed to allocate Dictionary inside `resolve()`'s call graph (composes the VFX tag list from active passives + counter flag + provenance). Static lint AC-DC-41 grep excludes this helper.

6. **`snappedf` precision** — All multiplier compositions use `snappedf(value, 0.01)` (precision 0.01, NOT 0.001). Locked-not-tunable per EC-DC-21.

7. **`StringName` literal discipline** — All flag / direction / passive comparisons use `&"foo"` syntax (StringName literal), NEVER plain `"foo"` (String). The release-build defense layer relies on this: even if a test bypass-seam injects `Array[String]` with String elements, `&"passive_charge" in attacker.passives` returns `false` (StringName ≠ String comparison), so P_mult stays 1.00.

8. **`@abstract` decorator (optional, Godot 4.5+)** — `class_name DamageCalc` MAY be marked `@abstract` to reject `DamageCalc.new()` instantiation, structurally enforcing the no-instance contract. The exact failure mode (parse-time error vs. runtime error at `_init()` call) on a class with only `static func` declarations is not explicitly documented in `docs/engine-reference/godot/`; treat the failure as a runtime error and verify the precise level via story-001 implementation. Apply this decoration in story-001 if no instance-construction caller emerges. **Low-urgency**: the static-only call form is clear from this ADR; static-lint (CI grep for `DamageCalc.new(`) is the safer enforcement path and is recommended as the primary mechanism with `@abstract` as a secondary defense. Identified by godot-specialist `/architecture-decision` validation 2026-04-26 + `/architecture-review` consultation same day (Item 3 verdict).

## Alternatives Considered

### Alternative 1: Autoload Service `/root/DamageCalc`

- **Description**: Register `DamageCalc` as an autoload at `/root/DamageCalc`, expose `resolve()` as an instance method on the autoload Node.
- **Pros**: Discoverable via `/root/`; can hold cached references to upstream services; matches GameBus / SceneManager / SaveManager autoload pattern.
- **Cons**: Autoload form tempts signal emissions (the autoload Node has SceneTree presence, which encourages "let's emit a damage_resolved signal for VFX"). Violates ADR-0001 non-emitter list (line 375). Holds an instance reference, which is an architectural lie — the system is stateless. Loading order coupling with GameBus / SaveManager not justified by Damage Calc's call surface.
- **Rejection Reason**: ADR-0001 explicitly forbids signal emission from Damage Calc; autoload form structurally tempts the violation. Stateless static class form is unambiguously correct for a pure-function service.

### Alternative 2: Plain GDScript Module File (no `class_name`)

- **Description**: Author `damage_calc.gd` as a top-level GDScript file with module-level `func resolve(...)` (no `class_name`). Callers `preload("res://src/feature/damage_calc/damage_calc.gd")`.
- **Pros**: Lightest possible form; no class instance, no autoload registration, no SceneTree presence.
- **Cons**: Loses `class_name` discoverability — code reads `var damage_calc = preload(...); damage_calc.resolve(...)` rather than `DamageCalc.resolve(...)`. Inconsistent with project naming conventions (PascalCase classes, `class_name` declarations preferred per technical-preferences.md). No grep-able anchor for "where does damage resolution happen?". Test-bypass seam helpers (private `_passive_multiplier`) are trickier to access without a class scope.
- **Rejection Reason**: The discoverability cost outweighs the marginal weight savings. `class_name DamageCalc extends RefCounted` with static methods is the same wire weight as a module file but adds grep-anchor + namespace clarity.

### Alternative 3: Signal-Driven Resolution

- **Description**: Grid Battle emits a `damage_calc_requested(payload)` GameBus signal; Damage Calc subscribes, computes, emits `damage_calc_resolved(result)`; Grid Battle subscribes to the result.
- **Pros**: Decouples Grid Battle from Damage Calc's static-method call form; permits test interception via signal stubs; would allow future async resolution.
- **Cons**: Violates ADR-0001 non-emitter list (Damage Calc must not emit). Splits AC-DC-42 call-count discipline (signal subscribers cannot be reliably counted without a registry layer). Splits the `apply_damage` responsibility (Grid Battle cannot tell which signal handler is responsible). Asynchronous resolution defeats the stateless-deterministic invariant (signal-ordering races become a correctness hole). The sole caller is Grid Battle — there is no "fan-out" use case that would justify signal indirection.
- **Rejection Reason**: ADR-0001 enforcement + AC-DC-42 / AC-DC-43 discipline + the architectural philosophy of "calculator services use direct call, lifecycle services use signals" (the same philosophy that put Map/Grid queries on direct_call in ADR-0004).

## Consequences

### Positive

- **Deterministic, signal-free, stateless** — three compounding invariants make the system trivially testable, replayable, and reasoning-friendly. No "did a stale signal fire?" debugging surface.
- **Aligned with ADR-0001 non-emitter list** — no architectural drift risk; static-lint can enforce zero signal emissions in `damage_calc.gd`.
- **Type boundary enforced at the call-site boundary** — `Array[StringName]` parameter binding catches `Array[String]` bugs at runtime (assignment / insertion / parameter-bind time, NOT parse time per Decision §2 nuance), not via silent-wrong-answer EC-DC-25 hole at F-DC-5. The runtime catch is at Grid Battle's `DamageCalc.resolve(...)` call, before any multiplier composition runs. Per godot-specialist `/architecture-review` consultation 2026-04-26 (AF-1): wording corrected from earlier "compile-time" claim to align with Decision §2 — see also R-9 mitigation for the bypass-seam test pattern.
- **Lazy-tuneable via `entities.yaml`** — TK-DC-1 / TK-DC-2 movement is a balance-data edit, not a code change. Damage feel can be iterated without recompilation.
- **Test-bypass seams via private helpers** — AC-DC-51(b) StringName-literal bypass-seam coverage is achievable without exposing helpers in the public API.
- **Provisional-dependency strategy unblocked Sprint 1 successfully** — ADR-0006/0009/0010/0011 not-yet-written-at-ADR-0012-Acceptance-time status did not block ADR-0012 or the damage-calc Feature epic stories. All 4 are now Accepted (ADR-0009 2026-04-28; ADR-0010 + ADR-0011 + ADR-0006 all 2026-04-30 via deltas #7/#8/#9 respectively). Mirrors ADR-0008 → ADR-0006 precedent (proven across 4 ratification cycles).

### Negative

- **Verbose factory ceremony** — `ResolveModifiers.make(attack_type, rng, direction_rel, round_number, is_counter, skill_id, source_flags, rally_bonus, formation_atk_bonus, formation_def_bonus)` has 10 parameters. Constructing test fixtures requires explicit calls. Mitigation: standard test-fixture helpers in `tests/unit/damage_calc/fixtures.gd` reduce boilerplate; the factory cost is one-time-per-test, not per-call.
- **More types to maintain** — 5 classes (DamageCalc + 4 wrappers) versus a single Dictionary-payload form. Total LoC ≈ 600 vs. ≈ 400 for Dictionary form. Mitigation: type-safety dividend pays back the LoC cost the first time AC-DC-51 catches an Array[String] regression.
- **CI infrastructure prerequisite is non-trivial** — headed `xvfb-run` job + cross-platform matrix requires GitHub Actions configuration the project does not yet have (per damage-calc.md lines 2248-2264). Mitigation: damage-calc Feature epic story-001 includes the CI config delta as a Config/Data sub-story; the ADR locks the requirement so the prerequisite cannot be silently dropped.
- ~~**Provisional-dependency surface area**~~ **CLOSED 2026-04-30** — 4 future ADRs (ADR-0006/0009/0010/0011) all needed to ratify their interfaces verbatim. **All 4 now Accepted**: ADR-0009 (2026-04-28 delta), ADR-0010 (2026-04-30 delta #7), ADR-0011 (2026-04-30 delta #8), ADR-0006 (2026-04-30 delta #9). 0 narrowing changes; 0 reciprocal ADR-0012 amendments required beyond the cross-doc `unit_id: int` type narrowing applied via deltas #7/#8 advisory batch. `/architecture-review` cross-conflict detection successfully caught all stale references during the close-out passes.

### Risks

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| **R-1**: ADR-0009 / 0010 / 0011 / 0006 propose a contract narrower than ADR-0012-locked interface, forcing a reciprocal amendment. | LOW | MEDIUM | Each upstream GDD is APPROVED for the relevant section; the GDD locks the contract, the ADR ratifies it. `/architecture-review` cross-conflict detection catches narrowing changes during the upstream ADR's authoring. |
| **R-2**: Mobile p99 perf budget (<1ms) misses on minimum-spec device. | MEDIUM | HIGH | AC-DC-40(b) is KEEP-through-implementation. Story-008 of the damage-calc epic includes a Polish-deferral-precedent perf baseline + minimum-spec device measurement gate. CI matrix includes per-platform monitoring. |
| **R-3**: CI infrastructure prerequisite (headless + headed + cross-platform matrix) does not exist before damage-calc story-001 begins. | MEDIUM | HIGH | Damage-calc epic story-001 is gated on the CI-config Config/Data sub-story. ADR-0012 lists infrastructure as Validation Criteria; `/story-readiness` blocks story-001 if prerequisite unmet. |
| **R-4**: gdUnit4 addon version pinning drifts; tests pass on dev machine, fail on CI (or vice versa). | LOW | MEDIUM | Pinned version recorded in `tests/README.md` AND `CLAUDE.md`. CI workflow asserts the pinned version on every push. |
| **R-5**: `F-GB-PROV` removal patch ships without `entities.yaml` registration of `damage_resolve` (or vice versa) — temporary inconsistent state in main. | LOW | MEDIUM | AC-DC-44 is a CI gate enforced via grep: post-patch, `F-GB-PROV` returns 0 matches in `design/` AND `entities.yaml.damage_resolve` exists. CI fails the merge if either side is missing. |
| **R-6**: GdUnitTestSuite-extends-Node base requirement leaks into other test classes that should be RefCounted (slower init). | LOW | LOW | ADR specifies the Node base is required ONLY for AC-DC-51(b). Other tests may use either base. Code review gate (specialist) catches gratuitous Node-base usage. |
| **R-7**: AC-DC-37 cross-platform divergence escalates from WARN to hard-fail under future regression discovery. | MEDIUM | MEDIUM | The softened-determinism contract is explicit (WARN-not-fail) and reversible. If divergence becomes intolerable, an integer-only-math superseding ADR is the path forward; the AC re-classifies at that point. |
| **R-8**: Floating-point accumulation **upstream** of `snappedf` shifts apex arithmetic by 1 ULP across platforms (e.g., `D_mult = 1.50 × 1.09` evaluates to `1.6349999...` on one platform vs. `1.635` on another, then `snappedf(..., 0.01)` rounds to `1.63` vs. `1.64` — flipping apex damage from 178 to 177 or 179). AC-DC-50 only pins the boundary `snappedf(0.005, 0.01)` directly; it does NOT pin the multiplicative composition chain that *feeds* `snappedf`. Identified by godot-specialist validation 2026-04-26. | MEDIUM | MEDIUM | AC-DC-37 cross-platform matrix should include the apex-path D_mult composition specifically (`D_mult = snappedf(BASE_DIRECTION_MULT[REAR] * CLASS_DIRECTION_MULT[CAVALRY][REAR], 0.01)` end-to-end), not only isolated `snappedf` boundary values. Add as a follow-up CI test in damage-calc story-001 implementation; track as TD-0XX (assigned at Acceptance). |
| **R-9**: AC-DC-51(b) bypass-seam test relies on call-site type rejection that may not surface as a hard error (per Item 2 partial-confirmation). Test may pass without exercising the actual guard it intends to. Identified by godot-specialist validation 2026-04-26. | LOW | MEDIUM | Bypass-seam test must explicitly assign `Array[String]` at the field level (`var ctx = AttackerContext.new(); ctx.passives = ["passive_charge_string"]`) and assert downstream `P_mult == 1.00` — NOT rely on `AttackerContext.make()` rejecting the typed-array argument. Update test pattern in damage-calc story implementation guide. |

## GDD Requirements Addressed

The 53 ACs in `damage-calc.md` map to ADR-0012 sections as follows. Comprehensive traceability is maintained in `docs/architecture/architecture-traceability.md`.

| GDD AC Range | Category | ADR-0012 Section Addressing |
|---|---|---|
| AC-DC-01..10, 52, 53 | FORMULA (worked examples D-1..D-10 + D-7/8 Formation paths) | Decision §1 (resolve entry point), §7 (cap layering), §8 (upstream interfaces); test infrastructure §10 |
| AC-DC-11..25 | EDGE_CASE BLOCKER | Decision §1 (invariant guards), §5 (RNG), §7 (cap layering), §12 (source_flags semantics); error-flag vocabulary in Implementation Guidelines #4 |
| AC-DC-26..32 | EDGE_CASE IMPORTANT | Decision §1 (pipeline), §8 (upstream contracts) |
| AC-DC-33..36 | CONTRACT (sole entry, zero signals, no HP calls, vfx_tags) | Decision §1 (sole entry), §3 (direct-call interface), §4 (signal-free invariant), §12 (source_flags) |
| AC-DC-37..39 | DETERMINISM (CI matrix, snappedf, RNG replay) | Decision §5 (RNG ownership), §10 (CI matrix), §11 (engine-pin) |
| AC-DC-40, 41 | PERFORMANCE (advisory <1ms p99, zero Dict alloc) | Decision §1 (stateless), §2 (typed wrappers), Performance Implications |
| AC-DC-42..44 | INTEGRATION (call count, apply_damage valid, F-GB-PROV removal) | Decision §3 (direct call), §9 (F-GB-PROV retirement) |
| AC-DC-45..47 | ACCESSIBILITY (TalkBack, Reduce Motion, monochrome) | Decision §10 (headed CI prerequisite); ADR scope: locks the test infrastructure prerequisite, defers UI implementation to Battle HUD ADR |
| AC-DC-48 | TUNING (registry read confirmed) | Decision §6 (entities.yaml-only) |
| AC-DC-49, 50 | VERIFY-ENGINE (randi_range, snappedf) | Decision §11 (engine-pin tests mandatory) |
| AC-DC-51 | CONTRACT rev 2.2 (StringName boundary) | Decision §2 (typed wrapper boundary), §10 #4 (GdUnitTestSuite Node base for bypass-seam) |

## Performance Implications

- **CPU**: 50µs avg per `resolve()` call in headless CI (AC-DC-40(a), Vertical Slice blocker). 1ms p99 on minimum-spec mobile (AC-DC-40(b), Beta blocker, KEEP-through-implementation). The 16.6ms frame budget tolerates ~330 calls/frame at avg, ~16 calls/frame at mobile p99 — well above the expected 1-2 calls/frame in steady-state combat (1 primary attack + 0-1 counter per turn, with turns spaced 2-5 seconds apart).
- **Memory**: Zero Dictionary allocation inside `resolve()` body (excluding `build_vfx_tags`) per AC-DC-41. RefCounted wrapper allocations: 4 per call (1 each AttackerContext / DefenderContext / ResolveModifiers / ResolveResult), all freed by the end of Grid Battle's CR-5 Step 7 frame (no cross-frame retention). Static lint via grep enforces zero `Dictionary(` and zero standalone `{` matches in reachable functions.
- **Load Time**: N/A — stateless service has no per-battle initialization, no per-game initialization, no asset preload. Class loading is one-time at GDScript parse.
- **Network**: N/A — single-player MVP, no replication. Future multiplayer would replicate the seeded RNG handle via Save/Load snapshot semantics; Damage Calc itself is replication-agnostic.

## Migration Plan

### Same-patch obligations (must ship together):

1. `entities.yaml` registers `damage_resolve` formula + 11 constants (9 consumed + 2 owned).
2. `grid-battle.md` §CR-5 Step 7 removes `F-GB-PROV` provisional formula and cites `damage-calc.md` §F-DC-1.
3. `src/feature/damage_calc/damage_calc.gd` (NEW) implements the resolve pipeline.
4. `src/feature/damage_calc/{attacker,defender}_context.gd`, `resolve_modifiers.gd`, `resolve_result.gd` (NEW) declare the 4 wrapper classes.
5. `tests/unit/damage_calc/damage_calc_test.gd` (NEW) implements 44 of 53 ACs (headless).
6. `tests/integration/damage_calc/damage_calc_integration_test.gd` (NEW) implements non-UI INTEGRATION ACs.
7. `tests/integration/damage_calc/damage_calc_ui_test.gd` (NEW) implements UI INTEGRATION ACs (xvfb-run).
8. `.github/workflows/tests.yml` adds (a) cross-platform matrix (macOS Metal, Windows D3D12, Linux Vulkan) and (b) headed `xvfb-run` job.
9. `tests/README.md` records gdUnit4 addon pinned version.

### Cross-doc cleanup obligations (must ship before Acceptance — see Notes):

The damage-calc.md GDD currently cites **"ADR-0005"** at 4 locations (lines 82, 278, 341, 2317-2318). These were written when the project ADR mapping had not yet reassigned ADR-0005 to Input Handling. After ADR-0012 lands, the GDD's "ADR-0005" citations must be updated to "ADR-0012" via `/propagate-design-change`. This is a pure-rename cleanup; no semantic content changes.

The `/architecture-review` Phase 4.7 GDD-sync check (skill protocol) detects this as a sync issue. **Recommended write-approval option for `/architecture-decision`'s Step 5: select "[A] Write ADR + update GDD in the same pass"** so the citation cleanup ships with the ADR.

### Architecture-registry update (after Acceptance):

- New `interfaces` entry: `damage_resolution` (direct_call, producer=damage-calc, consumer=grid-battle) — see Decision §8 for full registry stanza.
- New `forbidden_patterns` entries: `damage_calc_signal_emission`, `damage_calc_state_mutation`, `damage_calc_dictionary_payload`, `hardcoded_damage_constants`.
- New `state_ownership` entry: NONE (Damage Calc has zero state — registering "stateless" is via the forbidden_patterns layer instead).

## Validation Criteria

ADR-0012 is correctly implemented when:

1. **All 27 mandatory-coverage-floor ACs pass on headless CI** — FORMULA (12) + EDGE_CASE BLOCKER (15) ACs in `tests/unit/damage_calc/`.
2. **All 37 Vertical Slice blockers pass** — adds CONTRACT (4) + DETERMINISM (3) + INTEGRATION (3) ACs to the mandatory floor.
3. **Performance gates**: AC-DC-40(a) <500ms for 10,000 calls in headless CI (Vertical Slice blocker); AC-DC-40(b) <1ms p99 on minimum-spec mobile (Beta blocker, KEEP-through-implementation).
4. **Engine-pin tests pass on every platform**: AC-DC-49 (randi_range inclusive both ends) + AC-DC-50 (snappedf round-half-away-from-zero) on macOS Metal, Windows D3D12, Linux Vulkan.
5. **AC-DC-51 StringName boundary** passes — both positive case (AttackerContext.make with `[&"passive_charge"]`) and negative bypass-seam case (test direct-construct with `Array[String]`).
6. **F-GB-PROV removal verified** — CI grep AC-DC-44 returns 0 matches for `F-GB-PROV` in `design/`.
7. **No Dictionary allocations** — CI grep AC-DC-41 returns 0 matches for `Dictionary(` and standalone `{` in reachable `resolve()` body (excluding `build_vfx_tags`).
8. **No signal emissions / no signal subscriptions** — static lint of `damage_calc.gd` finds zero `signal` declarations and zero `connect(` calls (per ADR-0001 enforcement, Decision §4).
9. **GDD ADR-0005 → ADR-0012 citation cleanup applied** — CI grep on `design/gdd/damage-calc.md` returns 0 matches for `ADR-0005` (post-cleanup).
10. **Architecture-registry updated** — new `damage_resolution` interface entry + 4 new forbidden_patterns entries appended.

## Related Decisions

- **ADR-0001 (GameBus Autoload — Cross-System Signal Relay)** — Damage Calc is on the non-emitter list (line 375). This ADR's Decision §4 (signal-free invariant) is the direct enforcement of ADR-0001's contract.
- **ADR-0008 (Terrain Effect)** — `terrain.get_combat_modifiers(atk, def) -> CombatModifiers` interface and the `MAX_DEFENSE_REDUCTION = 30` / `MAX_EVASION = 30` cap constants are owned here. Damage Calc consumes already-clamped values per Decision §8.
- **ADR-0006 Balance/Data (Accepted 2026-04-30 via /architecture-review delta #9 — RATIFIED)** — ratified `BalanceConstants.get_const(key)` interface for the 11 constants (9 consumed + 2 owned). Sprint 1 S1-09 Nice-to-Have closed.
- **ADR-0009 Unit Role (Accepted 2026-04-28 via `/architecture-review` delta — Sprint 1 S1-07 closure)** — ratifies `UnitRole.BASE_DIRECTION_MULT[3]` and `UnitRole.CLASS_DIRECTION_MULT[6][3]` table interfaces (6 UnitClass enum members; Strategist + Commander rows all-1.0 no-ops by design per ADR-0009 §6). Reciprocal-update obligation symmetric.
- **ADR-0010 HP/Status (Accepted 2026-04-30 via /architecture-review delta #7)** — ratified `hp_status.get_modified_stat(unit_id: int, stat_name)` + `hp_status.apply_damage(unit_id: int, ...)` interfaces. Type narrowed StringName → int via delta #8 same-patch advisory batch.
- **ADR-0011 Turn Order (Accepted 2026-04-30 via /architecture-review delta #8)** — ratified `turn_order.get_acted_this_turn(unit_id: int)` interface + added `turn_order.get_current_round_number() -> int` query for Scout Ambush round-2+ gate. Type narrowed StringName → int via delta #8 same-patch advisory batch.
- **Future Grid Battle ADR (Feature layer)** — when Accepted, will document the sole-caller contract (CR-1, AC-DC-42), the F-GB-PROV retirement (already obligated here), and the Grid Battle → HP/Status `apply_damage` dispatch on HIT.
- **Future AI ADR / Battle VFX ADR / Battle HUD ADR** — when Accepted, each will reference Damage Calc's `ResolveResult` API surface as a read-only consumer.
- **Future Save/Load Core GDD + ADR** — when Accepted, will reference the determinism contract (EC-DC-14) and the RNG snapshot semantics (Decision §5).

## Notes

### Cross-doc obligations on Acceptance

1. **GDD ADR-0005 → ADR-0012 citation cleanup** — `design/gdd/damage-calc.md` lines 82, 278, 341, 2317-2318 cite "ADR-0005" as the typed-wrapper ADR. The project ADR mapping has reassigned ADR-0005 = Input Handling (HIGH engine risk, dual-focus 4.6 + SDL3 + Android). The wrapper layer (AttackerContext / DefenderContext / ResolveModifiers / ResolveResult) is folded INTO ADR-0012 (Decision §2) rather than split out. **Action: replace 4 occurrences of "ADR-0005" → "ADR-0012" in `design/gdd/damage-calc.md` in the same pass as ADR-0012 write.**

2. **Bidirectional citation audit** (per `damage-calc.md` §Bidirectional Citation Audit, lines 1194-1213) — the following GDDs must contain back-references to `damage-calc.md`. ADR-0012 ratifies the obligation:
   - `grid-battle.md` — must remove `F-GB-PROV` and cite F-DC-1 (Section D).
   - `unit-role.md` — already cites damage-calc.md per §EC-7 references.
   - `hp-status.md` — must cite damage-calc.md §CR-11 and EC-DC-12.
   - `terrain-effect.md` — must cite damage-calc.md §CR-4 and EC-DC-3.
   - `turn-order.md` — must cite damage-calc.md §CR-8.
   - `balance-data.md` — must cite damage-calc.md Section D (constants consumer).

3. **`entities.yaml` registry update** — register `damage_resolve` formula + add `referenced_by: [damage-calc.md]` to all 9 consumed constants + register TK-DC-1 CHARGE_BONUS and TK-DC-2 AMBUSH_BONUS as new constants.

4. **`tr-registry.yaml` update** — append TR-damage-calc-001..NN entries (count derived during `/architecture-review` Phase 8 — typical: ~12-15 TRs for a 53-AC GDD).

5. **`architecture-traceability.md` update** — add the 53 AC → ADR-0012 §X mapping rows.

### Provisional-Dependency Strategy Audit Trail

This ADR explicitly soft-depended on 4 then-not-yet-written ADRs (0006, 0009, 0010, 0011) at ADR-0012's Acceptance 2026-04-26. **All 4 are now Accepted** (ADR-0009 2026-04-28; ADR-0010 + ADR-0011 + ADR-0006 all 2026-04-30 via deltas #7/#8/#9). The strategy mirrored ADR-0008 → ADR-0006 precedent (proven: ADR-0008 was Accepted 2026-04-25 with the same pattern; the workaround direct-loading code shipped cleanly and was migration-stable for ADR-0006). Audit trail:

- ADR-0012 commits to interface signatures **verbatim from APPROVED GDD sections** — not novel ADR-0012 invention.
- `/architecture-review` Phase 4 (cross-conflict detection) reviews ADR-0012 against ADR-0001 / ADR-0004 / ADR-0008 (Accepted) — provisional dependencies do not block Acceptance because the cited GDDs are the authoritative source.
- ~~When ADR-0006 / 0009 / 0010 / 0011 are authored~~ **CLOSED 2026-04-30**: all 4 upstream ADRs Accepted via /architecture-review deltas #5/#7/#8/#9; cross-conflict detection successfully ratified all interfaces with 0 narrowing changes. Carried advisories (5 cross-doc `unit_id: int` type narrowings) all resolved or queued for next ADR-0012 substantive amendment.
- Reciprocal-amendment cost is bounded — interface surface is small (5 method signatures across 5 systems). Worst case: 1 ADR-0012 §8 row update per upstream ADR.

### Test infrastructure deferred-tracking

The CI infrastructure prerequisites (Decision §10 items 1-5) require GitHub Actions workflow changes the project has not yet made. ADR-0012 locks the requirement; damage-calc Feature epic story-001 (`/create-stories damage-calc` Sprint 1 S1-05) MUST include the CI workflow delta as a Config/Data sub-story. If the prerequisite is unmet at story-001 implementation time, `/story-readiness` will block the story. This is the same gating pattern that worked for ADR-0008 → terrain-effect epic story-008 (perf baseline gated on CI matrix prerequisite).

### Manifest Version

This ADR is authored against `docs/architecture/control-manifest.md` Manifest Version **2026-04-20**. Future damage-calc story files must embed this version (per project staleness-detection convention).
