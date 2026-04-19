# Damage / Combat Calculation

> **Status**: In Design
> **Author**: systems-designer + user
> **Last Updated**: 2026-04-19 (rev 2.6 — seventh-pass BLK-7-1..10 resolution: direction_rel canonical type StringName per BLK-7-2; Archer FLANK class-mod 1.15→1.375 for Pillar-3 parity with Infantry REAR + HIT_DEVASTATING tier reach per BLK-7-9/10; Cross-System Patches #2 Archer row updated to current rev 2.6 endpoint per BLK-7-1; V-2 multiplier annotation extended to HIT_DIRECTIONAL per BLK-7-8; V-3 queue rule Reduce-Motion exception per BLK-7-7; AC-DC-46 frame-count→wall-clock deltas per BLK-7-3; AC-DC-47 opacity threshold 15%→10% with non-monotonic rationale per BLK-7-6; AC-DC-51(b) direct-call bypass-seam per BLK-7-4; AC-DC-21/28 bypass-seam via test-only RefCounted subclass per BLK-7-5)
> **Implements Pillar**: Pillar 1 (형세의 전술), Pillar 3 (Every Hero Has a Role)
> **Source Brief**: design/gdd/damage-calc-design-brief.md

## Overview

Damage Calculation is the synchronous, deterministic service that resolves a single
attack into an integer `resolved_damage` for HP/Status to consume. It owns four
stages of the attack pipeline — evasion roll, effective-stat read, terrain reduction,
and direction × class × passive multiplication — and stops short of HP subtraction,
Shield Wall flat reduction, and status-effect modifiers (those belong to HP/Status
intake per `hp-status.md` §F-1). Per ADR-0001 §Damage Calc (line 375), it is a
**consumer-only** system: it subscribes to no signal it must emit, and pulls all
per-attack context through direct calls (`get_modified_stat`, `get_combat_modifiers`,
`get_acted_this_turn`, `get_passive_tags`).

For the player, Damage Calc IS the feedback channel for Pillar 1 (형세의 전술).
The number that pops above a unit's head encodes whether positioning paid off —
a Cavalry rear-charge that prints `2.16×` of base damage is the moment the
player feels that turns of maneuvering converted into an irreversible swing.
The number is also the legibility surface for Pillar 3 (Every Hero Has a Role):
identical ATK on a Scout vs an Infantry produces visibly different outputs because
class-specific direction multipliers and passives gate where each role is decisive.
The system retires `F-GB-PROV` (the provisional formula in `grid-battle.md` §CR-5
Step 7) and replaces it with the canonical `damage_resolve` formula registered
in `entities.yaml`.

## Player Fantasy

**핵심 감정 / Anchor**: 형세의 결산 (The Reckoning of Formation).

The damage number is the moment a player's three-to-four-turn investment in
형세 becomes legible. When the Cavalry that has been wheeling around the enemy's
right flank since Turn 2 finally strikes the rear and the integer resolves at
`2.16×`, the player does not feel "powerful" — they feel **proven correct**.
The number is a verdict on the patience of their maneuvering, not a reward for
the click that triggered it. A bigger number means they read the board better
three turns ago.

This anchors **Pillar 1 (형세의 전술)**: the damage figure is the system's
confession that formation, not stats, decided this exchange. Damage Calc's
fantasy is intentionally narrower than Grid Battle's broader tactical fantasy
or HP/Status's life-and-death drama — its emotional surface is **only** the
moment of resolution, the integer that confirms what the previous turns earned.

**What this fantasy means for design**:
- The biggest numbers MUST be reachable only via positioning + class fit + timing,
  never via raw stat advantage. ATK 200 vs DEF 1 should not exceed a
  well-positioned ATK 80 with REAR + Charge.
- Direction × class multipliers are the legibility surface — they must be
  visible in the popup or its hover tooltip so the player can connect `2.16×`
  back to the four turns of work that earned it.
- Avoid JRPG crit-fest visual language. Damage popups inherit the ink-wash
  restraint: clean integers, restrained color, weighted typography.
  주홍/금색 are reserved for destiny branches and MUST NOT be used for
  damage popups (Visual/Audio section will lock the palette).

**What this fantasy is NOT**:
- The kill itself (Grid Battle / HP/Status owns death moments).
- The branch-changing payoff of saving 관우 (Destiny Branch).
- The completion of a formation pattern (Formation Bonus).
- A "decisive blow" cinematic — the moment is in the math, not in the animation.

## Detailed Design

### Core Rules

Damage Calc resolves a single attack into an integer in 12 ordered stages.
The pipeline is invoked by Grid Battle once per primary attack and once per
counter-attack (see CR-10). Every stage is deterministic, side-effect-free,
and re-runnable from identical inputs.

**CR-1 — Single synchronous service.** Damage Calc is exposed as a stateless
function `resolve(attacker: AttackerContext, defender: DefenderContext,
modifiers: ResolveModifiers) -> ResolveResult` (rev 2.3 — typed RefCounted
wrappers replace the prior Dictionary signature per ADR-0005; see §B
GDScript Implementation Shape). No internal mutable state, no signal
emission (per ADR-0001 §Damage Calc line 375), no I/O. Same inputs → same
output.

**CR-2 — Evasion roll (Stage 0).** On every non-counter attack, Damage Calc
clamps `defender.terrain_evasion` to `[0, MAX_EVASION]` and rolls the seeded
RNG handle injected via `modifiers.rng`. On MISS, returns
`ResolveResult.MISS` immediately; HP/Status is NOT called (preserves the
`hp-status.md:98` contract). Evasion is NOT rolled on counter-attacks
(counters are reactive — already gated by Grid Battle's CR-6 sequence).

**CR-3 — Effective-stat read.** Damage Calc calls
`hp_status.get_modified_stat(attacker.unit_id, "atk")` and
`hp_status.get_modified_stat(defender.unit_id, "phys_def" if PHYSICAL else "mag_def")`.
Raw stats from Hero DB are never read directly. Inputs are clamped:
`eff_atk ∈ [1, ATK_CAP]`, `eff_def ∈ [1, DEF_CAP]`.

**CR-4 — Terrain defense reduction.** Damage Calc clamps
`defender.terrain_def` to `[-TERRAIN_DEF_CAP, +TERRAIN_DEF_CAP]` (symmetric)
and computes `defense_mul = snappedf(1.0 - terrain_def / 100.0, 0.01)`.
**Sign convention** (matches `terrain-effect.md` §T_def contract):
**positive** `terrain_def` (defender on disadvantageous terrain — e.g.,
attacker has elevation) yields `defense_mul < 1.0`, **amplifying** damage;
**negative** `terrain_def` (defender elevation advantage) yields
`defense_mul > 1.0`, **reducing** damage. Range `[-30, +30]` matches
`entities.yaml:max_defense_reduction` symmetric clamp.

**CR-5 — DEFEND_STANCE counter penalty.** Applied **exactly once** during the
counter-attack resolution (never twice). When `modifiers.is_counter == true`
AND `attacker.defend_stance_active == true`, Damage Calc applies the
−`DEFEND_STANCE_ATK_PENALTY` (40%) to `eff_atk` before stage CR-6:
`eff_atk = floori(eff_atk × 0.60)`. Local variable mutation only — no
write-back to attacker state. The DEFEND_STANCE damage-taken reduction on
the **incoming** original attack (the attack that triggered the counter) is
HP/Status's responsibility (`hp-status.md` §F-1 intake pipeline) and is
never re-applied here. The Interactions table reflects this single-application
rule and overrides any prior text suggesting double-application.

**CR-6 — Stage 1 base damage with BASE_CEILING cap.**
`base = mini(BASE_CEILING, max(MIN_DAMAGE, floori(eff_atk - eff_def × defense_mul)))`.
The `BASE_CEILING = 83` cap (rev 2.4 — lowered from 100 per fifth-pass
CRITICAL-3 resolution) fires BEFORE direction multipliers. Value tuned
so the hardest primary-path hit (Cavalry REAR+Charge at max ATK =
`floori(83 × 1.80 × 1.20) = 179`) stays 1 under `DAMAGE_CEILING = 180`,
guaranteeing a 30-point differentiation between REAR-only (`floori(83 ×
1.80) = 149`) and REAR+Charge (179) at max ATK so Pillar-1 directional
payoff remains visible at the peak (see Section D rationale + D-4).

**CR-7 — Direction × class multiplier (EC-7 preserved).**
`D_mult = snappedf(base_direction_mult[direction_rel] × class_direction_mult[attacker.unit_class][direction_rel], 0.01)`.
The `snappedf` quantization happens BEFORE multiplying into base damage, to
kill IEEE-754 platform drift (per `grid-battle.md` §AC-GB-07). Multiplicative
order preserved per `unit-role.md` §EC-7 (non-negotiable).

**CR-8 — Passive multiplier (Charge / Ambush).**
- `P_mult = 1.0` initially.
- `if &"passive_charge" in attacker.passives AND attacker.charge_active AND attacker.unit_class == CAVALRY AND NOT modifiers.is_counter: P_mult *= CHARGE_BONUS` (1.20). Tags are `StringName` literals (`&"…"`) — NEVER `String`. See F-DC-5 typed `AttackerContext` contract and EC-DC-25. (rev 2.4: `class` → `unit_class` — `class` is a GDScript 4.6 reserved keyword.)
- `if &"passive_ambush" in attacker.passives AND attacker.unit_class in {SCOUT, ARCHER} AND NOT modifiers.is_counter AND ambush_round_gate_open(): P_mult *= AMBUSH_BONUS` (1.15).
  Where `ambush_round_gate_open()` queries
  `modifiers.round_number >= 2 AND turn_order.get_acted_this_turn(defender.unit_id) == false`.
  `modifiers.round_number` is supplied by Grid Battle at call-time (Grid Battle
  already owns round context); Damage Calc does NOT subscribe to `round_started`.
  **Class guards** prevent cross-class passive leakage: a misconfigured
  Infantry unit with `passive_ambush` in its tag array cannot trigger the
  multiplier. **`not is_counter` guard on Ambush** matches the Charge guard:
  passives never echo on the counter-attack path.
  Spatial Ambush gating (e.g., adjacency rules) is owned by Unit Role / Grid
  Battle and resolved BEFORE the `passive_ambush` tag reaches Damage Calc.

**CR-9 — Stage 2 raw damage with DAMAGE_CEILING cap.**
`raw = max(MIN_DAMAGE, mini(DAMAGE_CEILING, floori(base × D_mult × P_mult)))`.
The `DAMAGE_CEILING = 180` cap fires AFTER direction + passive multipliers.
The `MIN_DAMAGE = 1` floor is re-enforced here to guarantee the
`hp-status.md:98` contract holds even in degenerate combinations.
**Ceiling rationale (rev 2.4)**: DAMAGE_CEILING=180 is a **silent
defense-in-depth invariant**, not a player-facing clamp. The BASE_CEILING=83
tuning (CR-6) mathematically prevents primary-path raw from reaching 180
(max `floori(83 × 1.80 × 1.20) = 179`). The ceiling only fires under
synthetic class-guard-bypass test conditions (EC-DC-9 dual-passive stack,
`P_mult = 1.38` × D_mult = 1.80 × base = 83 → `floori(206.17) = 206` →
clamped to 180) or under future forward-compat scenarios (hero ability or
destiny branch pushes the peak higher — triggers ceiling-disclosure
re-authoring per rev 2.4 strip-and-defer decision; see review log).
Pillar-1 upper bound "no single attack > 60% of HP_CAP=300" holds at 179.

**CR-10 — Counter-attack modifier (Stage 3, conditional).**
When `modifiers.is_counter == true`:
`raw = max(MIN_DAMAGE, floori(raw × COUNTER_ATTACK_MODIFIER))`.
The `0.5` multiplier is the FINAL stage on the counter path so it composes
cleanly with all earlier multipliers. DEFEND_STANCE damage-taken reduction
(−50% on the original attack received by the defender, per registry `defend_stance_reduction = 50` owned by `design/gdd/hp-status.md` F-4) is HP/Status's job,
not applied here.

**CR-11 — Output contract.** Returns `ResolveResult.HIT(resolved_damage: int, attack_type: AttackType, source_flags: Array[StringName], vfx_tags: Array[StringName])`
or `ResolveResult.MISS(source_flags: Array[StringName] = [])`. `resolved_damage`
is guaranteed `≥ MIN_DAMAGE` on HIT. `source_flags` propagates passive and
provenance identity (e.g., `&"charge"`, `&"ambush"`, `&"counter"`) for
HP/Status downstream rules and VFX tagging.

**MISS `source_flags` vocabulary (rev 2.4 — flagged-MISS guard redesign).**
MISS can now carry a source_flag identifying why it was returned, which
replaces the rev 2.3 reliance on the fabricated `Engine.get_error_count()`
API for test assertions. Tests assert on the flag via
`result.source_flags.has(&"<reason>")`. Vocabulary:

| `source_flag` | Meaning | Raised by |
|---|---|---|
| `&"skill_unresolved"` | `modifiers.skill_id != ""` — Skill System not implemented (CR-12) | F-DC-1 entry |
| `&"invariant_violation:rng_null"` | `modifiers.rng == null` — determinism guard (EC-DC-13) | F-DC-1 entry |
| `&"invariant_violation:unknown_class"` | `attacker.unit_class` not in `CLASS_DIRECTION_MULT` (EC-DC-15) | F-DC-4 |
| `&"invariant_violation:unknown_direction"` | `modifiers.direction_rel` null or unrecognized (EC-DC-16) | F-DC-4 |
| `&"invariant_violation:bad_attack_type"` | `modifiers.attack_type` not in `{PHYSICAL, MAGICAL}` (EC-DC-12) | F-DC-1 entry |
| `&"evasion"` | Stage-0 evasion roll succeeded (legitimate dodge — NOT an invariant violation; flag is informational so Grid Battle / VFX can distinguish terrain dodges from guard-triggered misses). | F-DC-2 |

Every invariant-violation MISS also calls `push_error(<human-readable
reason>)` so the editor log surfaces the defect; the flag is the
programmatic testing surface. No engine error-count API is consulted —
tests are self-contained in the ResolveResult contract.

**GDScript implementation shape** (locked for implementer):

```gdscript
class_name ResolveResult extends RefCounted
enum Kind { HIT, MISS }
enum AttackType { PHYSICAL, MAGICAL }

var kind: Kind
var resolved_damage: int = 0
var attack_type: AttackType = AttackType.PHYSICAL
var source_flags: Array[StringName] = []   # NEVER Set, NEVER Dictionary
var vfx_tags: Array[StringName] = []

static func hit(damage: int, atk_type: AttackType,
                flags: Array[StringName],
                vfx: Array[StringName]) -> ResolveResult: ...
static func miss(flags: Array[StringName] = []) -> ResolveResult: ...
# rev 2.4 — MISS can now carry source_flags identifying its provenance
# (&"evasion", &"skill_unresolved", &"invariant_violation:<reason>").
# See §CR-11 MISS source_flags vocabulary.
```

**`ResolveModifiers` typed wrapper (rev 2.3 — BLK-3 resolution).** The
`modifiers` argument of `resolve()` is a `ResolveModifiers` RefCounted, NOT
a plain `Dictionary`. A Dictionary-typed field (`rng: RandomNumberGenerator`
inside `Dictionary`) has no static enforcement — GDScript returns `Variant`
on subscript access and the `: Type` annotation is a hint only. The wrapper
exists to make every field a real typed property, giving the F-DC-5 /
F-DC-6 pseudocode compile-time correctness for `modifiers.rng`, autocomplete
in Godot 4.6, and a single boundary for future additions.

```gdscript
class_name ResolveModifiers extends RefCounted

enum AttackType { PHYSICAL, MAGICAL }

var attack_type: AttackType = AttackType.PHYSICAL
var source_flags: Array[StringName] = []
var direction_rel: StringName = &"FRONT"        # FRONT / FLANK / REAR
var is_counter: bool = false
var skill_id: String = ""                        # "" = not a skill stub
var rng: RandomNumberGenerator                   # typed — not Variant
var round_number: int = 1                        # ≥ 1 (gate asserts)
var rally_bonus: float = 0.0                     # rev 2.7 — Grid Battle pass-11c CR-15
                                                 # value range [0.0, 0.15]; computed by Grid
                                                 # Battle via get_rally_bonus(attacker_id);
                                                 # consumed in F-DC-5 P_mult composition

static func make(attack_type: AttackType, rng: RandomNumberGenerator,
                 direction_rel: StringName, round_number: int,
                 is_counter: bool = false, skill_id: String = "",
                 source_flags: Array[StringName] = [],
                 rally_bonus: float = 0.0) -> ResolveModifiers: ...
```

**Phase-5 migration note — ADR candidate.** The switch from Dictionary to
`ResolveModifiers` is a cross-system ABI change: `grid-battle.md` lines
807–816 currently document a Dictionary-shaped payload. A new ADR
(`docs/architecture/ADR-0005-resolve-modifiers-wrapper.md`) is required
*before* implementation, covering (a) Grid Battle call-site migration,
(b) save/load RNG snapshot compatibility (unchanged — `rng` is still a
`RandomNumberGenerator` reference), and (c) test-fixture construction pattern
(`ResolveModifiers.make(...)` vs. prior `{rng: ..., …}` dict literals).
Tracked in §Cross-System Patches Queued (Phase 5).

`DamageCalc` is implemented as `class_name DamageCalc extends RefCounted`
with `static func resolve(...)` — **never an autoload Node**, since CR-1
mandates statelessness and ADR-0001 enforces no-emit. `AttackType` is owned
by this GDD (declared inside `ResolveResult` for colocation with consumers).

**`source_flags` mutation semantics (locked):** `resolve()` ALWAYS constructs
a NEW `Array[StringName]` for the returned `source_flags`, copying entries
from `modifiers.source_flags` and appending any internal flags (`"charge"`,
`"ambush"`, `"counter"`, `"skill_unresolved"`). It NEVER mutates the
caller's array.

**CR-12 — DoT and true damage bypass.** Damage Calc does NOT expose a
`resolve_true_damage()` path. DoT ticks and status-effect damage are
entirely owned by HP/Status (`apply_dot_tick(unit_id)` per
`hp-status.md:356`). The MIN_DAMAGE floor still applies to DoT but is
enforced inside HP/Status, not here. Skill damage (OQ-DC-4 deferred): if
`modifiers.skill_id != ""`, return `ResolveResult.MISS(source_flags:
[&"skill_unresolved"])` IMMEDIATELY (before evasion roll, before stat
reads — RNG NOT consumed). Grid Battle distinguishes real
terrain-evasion misses (source_flags contains `&"evasion"`) from stub
paths (contains `&"skill_unresolved"`) from invariant-violation guards
(contains `&"invariant_violation:*"`) for logging; HP/Status is
not called in any MISS case. (Amended 2026-04-18 per OQ-DC-9; see
EC-DC-11. Rev 2.4: MISS source_flags vocabulary expanded — see CR-11.)

### States and Transitions

**Damage Calc is purely stateless.** No per-battle, per-round, or per-attack
state is held across calls. The RNG handle for evasion is INJECTED via
`modifiers.rng` (a seeded `RandomNumberGenerator` owned by Grid Battle), so
save/load can snapshot Grid Battle's RNG and replay any attack identically
— a core requirement for the deterministic-replay invariant Pillar 2 needs.

What looks like state actually lives elsewhere:

| Apparent "state" | Actual owner | Read via |
|---|---|---|
| `charge_active` flag | Unit Role (per-unit data) | `attacker.charge_active` field in input dict |
| `acted_this_turn` for Ambush | Turn Order | `turn_order.get_acted_this_turn(unit_id)` |
| Terrain modifiers | Terrain Effect | `terrain.get_combat_modifiers(atk_coord, def_coord)` |
| `defend_stance_active` flag | HP/Status | `hp_status.get_modified_stat()` returns it as part of unit context |
| RNG seed state | Grid Battle | injected per call via `modifiers.rng` |

The "no mutable state" rule is what makes 100% unit-test coverage achievable
with no setup or teardown — every test call is `resolve(a, d, m) → result`
with no Damage Calc internals to mock.

### Interactions with Other Systems

| System | Direction | Method / Signal | Payload | Locked by |
|---|---|---|---|---|
| **Unit Role (#5)** | IN | `unit_role.get_class_modifiers(unit_id)` | `{class_atk_mult: float, direction_mults: {FRONT, FLANK, REAR}: float, passive_tags: Array[StringName]}` | `unit-role.md` §EC-7 lines 503–506; `grid-battle.md` lines 607–608 |
| **HP/Status (#12)** | IN | `hp_status.get_modified_stat(unit_id, stat_name)` | `int` — effective ATK/DEF with all buffs/debuffs and DEFEND_STANCE penalty folded in | `hp-status.md:508`; registry `damage_intake_pipeline` |
| **HP/Status (#12)** | OUT (via Grid Battle) | Grid Battle calls `hp_status.apply_damage(unit_id, resolved_damage, attack_type, source_flags)` after `resolve()` returns | `{resolved_damage: int ≥ 1, attack_type: AttackType, source_flags: Array[StringName]}` | `hp-status.md` §Contract 1 lines 271–273 |
| **Terrain Effect (#2)** | IN | `terrain.get_combat_modifiers(atk_coord, def_coord)` | `{defender_terrain_def: int [-30,+30], defender_terrain_eva: int [0,30], elevation_atk_mod: int, elevation_def_mod: int, special_rules: Array[StringName]}` | `terrain-effect.md` §Method 2 lines 178–183 |
| **Turn Order (#13)** | IN | `turn_order.get_acted_this_turn(unit_id) → bool` (O(1) contract — see `turn-order.md` §perf-AC) | Scout/Archer Ambush gate: `modifiers.round_number ≥ 2 AND defender.acted_this_turn == false`. **Round number is supplied via `modifiers.round_number`, NOT via signal subscription.** | `turn-order.md` lines 407–408; `unit-role.md` §EC-8 |
| **Grid Battle (#1)** | IN | `damage_calc.resolve(attacker, defender, modifiers)` — sole caller | `attacker: AttackerContext; defender: DefenderContext; modifiers: ResolveModifiers` (all typed `RefCounted` wrappers — rev 2.3 replaces prior Dictionary payload per ADR-0005). `ResolveModifiers` fields: `{attack_type, source_flags: Array[StringName], direction_rel: StringName, is_counter: bool, skill_id: String, rng: RandomNumberGenerator, round_number: int}` | `grid-battle.md` lines 807–816 (Phase-5 migration) |
| **Grid Battle (#1)** | OUT | Returns `ResolveResult` | `MISS()` OR `HIT(resolved_damage: int [1,180], attack_type, source_flags: Array[StringName], vfx_tags: Array[StringName])` | `grid-battle.md` line 815 |
| **Balance/Data (#26)** | IN | `DataRegistry.get_const_int(key) / get_const_float(key)` (typed getters; null-key returns trigger `push_error` once-per-key) | All cross-system constants — never hardcoded: `BASE_CEILING, DAMAGE_CEILING, COUNTER_ATTACK_MODIFIER, MIN_DAMAGE, MAX_DEFENSE_REDUCTION, MAX_EVASION, ATK_CAP, DEF_CAP, DEFEND_STANCE_ATK_PENALTY, CHARGE_BONUS, AMBUSH_BONUS`. Plus the **direction tables** `BASE_DIRECTION_MULT[3]` and `CLASS_DIRECTION_MULT[4][3]` accessed via `get_const_table(key)` (loaded once at scene-init, cached in DamageCalc). | `balance-data.md` lines 206, 334; registry constants block + `unit-role.md` §EC-7 (table values owned upstream) |
| **AI System (#8, future)** | OUT | Returns same `ResolveResult` (no separate AI path) | AI calls Grid Battle, which calls Damage Calc identically; AI reads `resolved_damage` from result for threat scoring | `turn-order.md` lines 397, 401 |
| **Battle VFX (#23, future)** | OUT | `vfx_tags` field in `ResolveResult` | `Array[StringName]` tags such as `"ambush"`, `"counter"`, `"terrain_penalty"` — Damage Calc labels; VFX interprets; Damage Calc never calls VFX directly | `systems-index.md:47` |

**Direction values**: `IN` = Damage Calc reads/receives; `OUT` = Damage Calc returns/writes (via Grid Battle for HP/Status — Damage Calc never calls HP/Status directly to apply damage).

**ADR-0001 confirmation**: Damage Calc emits ZERO signals AND subscribes to
ZERO signals. The earlier provisional `round_started` subscription is
**REMOVED** in revision 2 — it contradicted the stateless contract (CR-1)
and the consumer-only framing. Round number is now passed at call-time via
`modifiers.round_number` (Grid Battle already owns round context from its
own `round_started` subscription). All other data flows through the direct
calls above.

## Formulas

Damage Calc exposes one public formula, `damage_resolve` (F-DC-1), composed of
six named sub-stages (F-DC-2 through F-DC-7). Every sub-stage is deterministic
and integer-quantized at a defined boundary to prevent IEEE-754 platform drift.
All constants referenced in this section are registered in
`design/registry/entities.yaml` (or flagged below as new-candidate for Phase 5
registration).

**Stacking order (OQ-DC-7 ratified — Option C two-stage cap):**
`Stage 1 base → BASE_CEILING cap → Stage 2 (× D_mult × P_mult) → DAMAGE_CEILING
cap → Stage 3 counter halve`. The two-stage cap is non-negotiable: it protects
the directional-payoff fantasy at high ATK while preventing raw damage from
outrunning HP_CAP.

**F-GB-PROV ratification (OQ-DC-2):** F-DC-3 uses the provisional subtractive
form `eff_atk − eff_def × defense_mul` for MVP. A follow-up spec
(`damage-calc-ratio-v2.md`) will evaluate a ratio form post-MVP; until then
the subtractive form is canonical and `grid-battle.md` §CR-5 Step 7 MUST be
updated to point here.

### F-DC-1 — `damage_resolve` (master pipeline)

Master pipeline. Composes F-DC-2 through F-DC-7 in fixed order. Registered as
a new formula in `entities.yaml` (Phase 5 registration candidate).

```
damage_resolve(attacker, defender, modifiers) -> ResolveResult:
    # Rev 2.4 — invariant guards (flagged MISS pattern, CR-11 vocabulary)
    if modifiers.skill_id != "":                            # CR-12
        return ResolveResult.miss([&"skill_unresolved"])
    if modifiers.rng == null:                               # EC-DC-13
        push_error("damage_calc.resolve: modifiers.rng is null")
        return ResolveResult.miss([&"invariant_violation:rng_null"])
    if modifiers.attack_type not in [AttackType.PHYSICAL,
                                     AttackType.MAGICAL]:   # EC-DC-12
        push_error("damage_calc.resolve: unknown attack_type")
        return ResolveResult.miss([&"invariant_violation:bad_attack_type"])
    if modifiers.direction_rel not in [&"FRONT", &"FLANK", &"REAR"]:  # EC-DC-16
        push_error("damage_calc.resolve: unknown direction_rel: "
                   + str(modifiers.direction_rel))
        return ResolveResult.miss([&"invariant_violation:unknown_direction"])
    if attacker.unit_class not in CLASS_DIRECTION_MULT:     # EC-DC-15
        push_error("damage_calc.resolve: unknown unit_class: "
                   + str(attacker.unit_class))
        return ResolveResult.miss([&"invariant_violation:unknown_class"])

    # Stage 0 — evasion (skipped on counter-attacks, per CR-2)
    if not modifiers.is_counter:
        if evasion_check(defender, modifiers.rng):          # F-DC-2
            return ResolveResult.miss([&"evasion"])

    # Stage 1 — base damage with BASE_CEILING cap
    base = stage_1_base_damage(attacker, defender, modifiers)  # F-DC-3

    # Stage 2 — direction × passive multiplication with DAMAGE_CEILING cap
    D_mult = direction_multiplier(attacker, modifiers)          # F-DC-4
    P_mult = passive_multiplier(attacker, defender, modifiers)  # F-DC-5
    raw = stage_2_raw_damage(base, D_mult, P_mult)              # F-DC-6

    # Stage 3 — counter halving (conditional)
    if modifiers.is_counter:
        raw = counter_reduction(raw)                            # F-DC-7

    return ResolveResult.HIT(raw, modifiers.attack_type,
                             modifiers.source_flags, build_vfx_tags(...))
```

**Variable dictionary (inputs)**:

| Input | Field | Type | Range | Source |
|---|---|---|---|---|
| `attacker` | `.unit_id` | StringName | — | Grid Battle |
| | `.unit_class` | enum {CAVALRY, SCOUT, INFANTRY, ARCHER} (rev 2.4 — renamed from `.class` which is a GDScript 4.6 reserved keyword) | — | Unit Role |
| | `.charge_active` | bool | — | Unit Role |
| | `.defend_stance_active` | bool | — | HP/Status (inferred via `get_modified_stat`) |
| | `.passives` | Array[StringName] | — | Unit Role |
| `defender` | `.unit_id` | StringName | — | Grid Battle |
| | `.terrain_def` | int | `[-30, +30]` | Terrain Effect |
| | `.terrain_evasion` | int | `[0, 30]` | Terrain Effect |
| `modifiers` | `.attack_type` | `ResolveResult.AttackType` (PHYSICAL, MAGICAL) | — | Grid Battle |
| | `.source_flags` | `Array[StringName]` (NEVER Set/Dictionary) | — | Grid Battle |
| | `.direction_rel` | `StringName` — allowed literals `{&"FRONT", &"FLANK", &"REAR"}` (rev 2.6 — BLK-7-2 type reconciliation: prior "enum {FRONT, FLANK, REAR}" annotation contradicted F-DC-1 guard `not in [&"FRONT", &"FLANK", &"REAR"]` and the `ResolveModifiers` class declaration at §CR-1; StringName is canonical, matching existing project pattern for `source_flags`, `passives`, and `vfx_tags` typed arrays. Guards reject anything outside the three-literal set with `&"invariant_violation:unknown_direction"`) | — | Grid Battle (facing resolver) |
| | `.is_counter` | bool | — | Grid Battle (false on primary, true on reactive) |
| | `.skill_id` | String | — | Grid Battle (empty in MVP — OQ-DC-4 deferred) |
| | `.rng` | RandomNumberGenerator | seeded | Grid Battle |
| | `.round_number` | int | `≥ 1` | Grid Battle (consumed by Ambush gate; replaces removed `round_started` subscription) |

### F-DC-2 — `evasion_check` (Stage 0, CR-2)

```
evasion_check(defender, rng) -> bool:
    T_eva = clampi(defender.terrain_evasion, 0, MAX_EVASION)
    roll = rng.randi_range(1, 100)
    return roll <= T_eva
```

Returns `true` on MISS. Only called when `modifiers.is_counter == false` (CR-2
contract). The clamp upper bound `MAX_EVASION = 30` means evasion tops out at
30% — a deliberate ceiling so terrain never trivializes offense.

### F-DC-3 — `stage_1_base_damage` (CR-4, CR-5, CR-6)

```
stage_1_base_damage(attacker, defender, modifiers) -> int:
    # CR-3 — effective stats
    eff_atk = clampi(hp_status.get_modified_stat(attacker.unit_id, "atk"),
                     1, ATK_CAP)
    def_stat = "phys_def" if modifiers.attack_type == PHYSICAL else "mag_def"
    eff_def = clampi(hp_status.get_modified_stat(defender.unit_id, def_stat),
                     1, DEF_CAP)

    # CR-5 — DEFEND_STANCE counter penalty
    if modifiers.is_counter and attacker.defend_stance_active:
        eff_atk = floori(eff_atk * 0.60)   # 1 - DEFEND_STANCE_ATK_PENALTY/100

    # CR-4 — terrain defense reduction
    T_def = clampi(defender.terrain_def, -MAX_DEFENSE_REDUCTION,
                                          +MAX_DEFENSE_REDUCTION)
    defense_mul = snappedf(1.0 - T_def / 100.0, 0.01)

    # CR-6 — base with BASE_CEILING cap
    return mini(BASE_CEILING,
                max(MIN_DAMAGE,
                    floori(eff_atk - eff_def * defense_mul)))
```

**Expected ranges**:
- `eff_atk ∈ [1, 200]`; `eff_def ∈ [1, 100]`
- `defense_mul ∈ [0.70, 1.30]` (since `T_def ∈ [-30, +30]`)
- `base ∈ [1, 83]` — capped at `BASE_CEILING = 83` (rev 2.4, lowered from
  100) so the hardest primary-path hit stays 1 under DAMAGE_CEILING and
  Pillar-1 peak differentiation survives at max ATK (see D-2 / D-4).

### F-DC-4 — `direction_multiplier` (CR-7, EC-7 preserved)

```
direction_multiplier(attacker, modifiers) -> float:
    b_mult = BASE_DIRECTION_MULT[modifiers.direction_rel]
    c_mult = CLASS_DIRECTION_MULT[attacker.unit_class][modifiers.direction_rel]
    return snappedf(b_mult * c_mult, 0.01)
```

**Locked tables — owned by `unit-role.md` §EC-7 lines 180–193; Damage Calc is
a consumer, NOT an owner.** Changes require Unit Role GDD amendment + Phase 5
registry update.

`BASE_DIRECTION_MULT` (generic facing, all classes):

| direction_rel | multiplier |
|---|---|
| FRONT | 1.00 |
| FLANK | 1.20 |
| REAR | 1.50 |

`CLASS_DIRECTION_MULT` (class-specific bonus on top of base, per `unit-role.md` §EC-7):

| unit_class | FRONT | FLANK | REAR |
|---|---|---|---|
| CAVALRY | 1.00 | 1.10 | 1.20 |
| SCOUT | 1.00 | 1.00 | 1.10 |
| INFANTRY | 0.90 | 1.00 | 1.10 |
| ARCHER | 1.00 | 1.375 | 0.90 |

**Infantry asymmetry rationale (revision 2):** Infantry receives a small
directional gradient (`0.90 / 1.00 / 1.10`) instead of being directionally
flat (`1.00 / 1.00 / 1.00`). A flat row would leave 25% of the class matrix
Pillar-1-inert and reduce Infantry-vs-Infantry combat to a stat-check.
The mild gradient preserves Infantry's tank identity (smallest swing of
any class, FLANK still neutral) while ensuring positioning matters for
every class.

**Archer asymmetry rationale (rev 2.3 introduced; rev 2.4 rewrote;
rev 2.5 lifted FLANK for numerical FLANK-peak; rev 2.6 widened FLANK
to +37.5% for Pillar-3 role parity + HIT_DEVASTATING tier reach):**
Archer receives a FLANK-favored / REAR-penalized gradient (`1.00 /
1.375 / 0.90`) rather than the flat `1.00 / 1.00 / 1.00` that preceded
it. The flat row left Archer without damage-space identity, causing
Pillar 3 ("Every Hero Has a Role") to fail structurally for this
class. The rationale is **role-identity only** (rev 2.4 correction —
the rev 2.3 text cited "line-of-sight / cover penalty when shooting
through a target's rear arc into terrain shadow", a mechanic Terrain
Effect does not expose to Damage Calc; that false rationale was design
debt): Archer is optimized for mid-range flank arcs where the drawn
bow has a stable release window; close-quarters rear shots represent
weapon-handling disadvantage — the drawn bow cannot pivot fast at
short range and rear-target footwork fails (−10% on REAR). No Terrain
Effect field is consulted; the asymmetry is pure role-identity
expression per Pillar 3. The FLANK magnitude (+37.5%) is the largest
class-mod bonus in the matrix and expresses Archer's identity as the
**FLANK-dedicated damage specialist** — distinct from Cavalry (REAR
peak via Charge), Scout (REAR peak via Ambush), and Infantry (mild
all-direction gradient).

**Numerical FLANK-peak guarantee (rev 2.5 intro — BLK-6-1; rev 2.6
widened — BLK-7-9/10 Pillar-3 parity):** The class mod `1.375` on
FLANK combined with `BASE_DIRECTION_MULT[FLANK]=1.20` yields Archer
FLANK `D_mult = snappedf(1.20 × 1.375, 0.01) = 1.65`. Archer REAR
combines `1.50 × 0.90 = 1.35`. **FLANK (1.65) > REAR (1.35)** by 0.30
— a 30-point experiential spread (vs the rev 2.5 spread of 0.03
which was arithmetically-true-but-experientially-inert at base=83;
BLK-7-10). FLANK D_mult=1.65 also clears the HIT_DEVASTATING tier
threshold (D_mult > 1.50 per V-1) so Archer now reaches the
devastating-hit visual/audio tier, which the rev 2.5 value of 1.38
locked out. At max ATK=200, DEF=10, BASE=83: Archer FLANK no-passive
= `floori(83 × 1.65) = 136` (matches Infantry REAR anchor); Archer
FLANK+Ambush = `floori(83 × 1.65 × 1.15) = 157` (matches Scout
REAR+Ambush anchor, differs by spatial position not numerical peak
— Scout REAR vs Archer FLANK is a genuine role differentiation);
HIT_DEVASTATING tier reached even without Ambush. REAR max=112
(combat-noise floor). Do not revert FLANK below `1.25` (D_mult 1.50 —
HIT_DEVASTATING boundary) without rewriting Pillar-3 Archer identity.

**Pillar-3 peak hierarchy (rev 2.6):** Cavalry REAR+Charge=179 (apex);
Scout REAR+Ambush=157, Archer FLANK+Ambush=157 (parity at optimal
play, disjoint positions); Infantry REAR=136 no-passive baseline.
Archer > Infantry at optimal play holds the dedicated-damage-role
promise. Scout vs Archer at parity ATK is distinguished by position
(REAR vs FLANK) not by raw number — Ambush-access matrix intentional.

**Derived `D_mult` grid (snappedf to 0.01 per CR-7)**:

| unit_class | FRONT | FLANK | REAR |
|---|---|---|---|
| CAVALRY | 1.00 | 1.32 | 1.80 |
| SCOUT | 1.00 | 1.20 | 1.65 |
| INFANTRY | 0.90 | 1.20 | 1.65 |
| ARCHER | 1.00 | 1.65 | 1.35 |

Cavalry REAR `1.80` and Scout/Infantry REAR `1.65` are the "big number"
legibility anchors for Pillar 1. Archer's FLANK `1.65` is the Archer-class
"big number" anchor (rev 2.6 — widened from rev 2.5's 1.38 for Pillar-3
parity with Infantry REAR peak + HIT_DEVASTATING tier reach; see
BLK-7-9/10 resolution in the rationale block above and review-log rev
2.6 entry). Archer FLANK and Scout/Infantry REAR numerically match at
1.65 — intentional: Archer and Scout both reach the same peak via
distinct spatial positions (FLANK vs REAR) and distinct passive gates
(Ambush access-matrix), expressing Pillar-3 "every hero has a role"
through positioning identity, not through numerical exclusivity. These
values are locked and any tuning pass must go through `unit-role.md`
governance.

### F-DC-5 — `passive_multiplier` (CR-8)

```
# rev 2.3 — StringName type guard via TYPED PARAMETER SIGNATURE.
# Previously (rev 2.2) the assert was:
#   attacker.passives is Array
#   AND (is_empty() OR typeof([0]) == TYPE_STRING_NAME)
# This had two defects: (a) empty Array[String] passed silently because
# is_empty() short-circuited the typeof check, and (b) `is Array[StringName]`
# is not valid Godot 4.6 GDScript syntax (parameterized `is` on typed
# arrays is unsupported). The fix: contract the argument type on the
# caller-facing `resolve()` entry point as `attacker: AttackerContext`
# with `var passives: Array[StringName]` — GDScript enforces the inner
# type on assignment and parameter binding, and release builds stay
# correct via StringName literal comparisons (&"…") below.
const PASSIVE_CHARGE: StringName = &"passive_charge"
const PASSIVE_AMBUSH: StringName = &"passive_ambush"

# AttackerContext is a RefCounted with a typed passives field:
#   class_name AttackerContext extends RefCounted
#   var unit_class: UnitRole.Class   # rev 2.4 — `class` is GDScript 4.6 reserved keyword
#   var passives: Array[StringName] = []   # typed — not Array[String]
#   var charge_active: bool = false
#   var unit_id: StringName
# Grid Battle must construct via AttackerContext.make(...) — plain Dict
# or Array[String] cannot satisfy the signature, so the violation is
# caught at the call boundary, not inside F-DC-5.

passive_multiplier(attacker: AttackerContext,
                   defender: DefenderContext,
                   modifiers: ResolveModifiers) -> float:
    # No runtime assert needed — GDScript 4.6 type system guarantees
    # attacker.passives is Array[StringName] at this point. The prior
    # hand-rolled assert is replaced by the AttackerContext contract.
    P_mult = 1.0

    # Charge — Cavalry-only, primary attacks only
    # (Class enum is owned by Unit Role — see unit-role.md §EC-7 and the
    # Variable Dictionary in this section. Do NOT redeclare on ResolveResult.)
    if PASSIVE_CHARGE in attacker.passives \
       and attacker.charge_active \
       and attacker.unit_class == UnitRole.Class.CAVALRY \
       and not modifiers.is_counter:
        P_mult *= CHARGE_BONUS            # 1.20

    # Ambush — Scout/Archer only, primary attacks only, round-gated
    if PASSIVE_AMBUSH in attacker.passives \
       and attacker.unit_class in [UnitRole.Class.SCOUT,
                                    UnitRole.Class.ARCHER] \
       and not modifiers.is_counter \
       and ambush_round_gate_open(defender, modifiers):
        P_mult *= AMBUSH_BONUS            # 1.15

    # Rally — additive bonus from adjacent Commanders (rev 2.7 — Grid Battle pass-11c CR-15 propagation)
    # Rally is computed by Grid Battle via get_rally_bonus(attacker_id) and passed in
    # via modifiers.rally_bonus (float in [0.0, 0.15] inclusive; cap enforced upstream
    # in Grid Battle CR-15 rule 4 as min(0.15, N_adjacent_alive_commanders × 0.05)).
    # Damage Calc trusts the upstream value and does NOT re-cap or re-validate.
    # Applied as multiplicative composition with Charge + Ambush, mirroring the
    # existing P_mult assembly pattern. Counters do NOT receive Rally — counters
    # use COUNTER_ATTACK_MODIFIER only (rev 2.7 mirrors the Charge/Ambush counter guard).
    if modifiers.rally_bonus > 0.0 \
       and not modifiers.is_counter:
        P_mult *= (1.0 + modifiers.rally_bonus)

    return snappedf(P_mult, 0.01)

ambush_round_gate_open(defender, modifiers) -> bool:
    # round_number is supplied by Grid Battle via modifiers — no signal
    # subscription, no internal state. See §Interactions ADR-0001 note.
    return modifiers.round_number >= 2 \
       and turn_order.get_acted_this_turn(defender.unit_id) == false
```

**Class guards (revision 2; rev 2.5 — `class` → `unit_class` completion):** `passive_charge` requires `unit_class == CAVALRY`;
`passive_ambush` requires `unit_class ∈ {SCOUT, ARCHER}`. A misconfigured
Infantry unit with either tag will NOT trigger the multiplier — guard fail
is silent (no `push_error`) because the upstream tag-application is the
source of truth and Damage Calc is a pass-through consumer. Cross-class
tag leakage is treated as a Unit Role data bug, not a Damage Calc concern.

**`not is_counter` guard on Ambush (revision 2):** Mirrors the Charge
guard. Passives never echo on the counter-attack path — counters are pure
COUNTER_ATTACK_MODIFIER applications.

**NEW REGISTRY CANDIDATES (Phase 5 registration required)**:
- `CHARGE_BONUS = 1.20` — Cavalry Charge passive multiplier (disabled on counters)
- `AMBUSH_BONUS = 1.15` — Scout Ambush passive multiplier (gated on round ≥ 2 AND defender hasn't acted)

Spatial Ambush gating (adjacency rules, LoS, etc.) is owned upstream by Unit
Role / Grid Battle and resolved BEFORE the `passive_ambush` tag reaches the
`attacker.passives` array. Damage Calc trusts the tag's presence as
authoritative.

**Expected range**: `P_mult ∈ {1.00, 1.15, 1.20, 1.38}` — the four possible
states (no passive, Ambush only, Charge only, both stacked). Stacked value
is `snappedf(1.20 × 1.15, 0.01) = snappedf(1.379999…, 0.01) = 1.38` —
quantized at the boundary so platform IEEE-754 residue cannot leak.

### F-DC-6 — `stage_2_raw_damage` (CR-9)

```
stage_2_raw_damage(base, D_mult, P_mult) -> int:
    return max(MIN_DAMAGE,
               mini(DAMAGE_CEILING,
                    floori(base * D_mult * P_mult)))
```

**Expected range**: `raw ∈ [1, 179]` in MVP primary paths; `raw ∈ [1, 180]`
including DAMAGE_CEILING as the silent upper wall. Fires AFTER all
multipliers. The rev 2.4 BASE_CEILING=83 tuning (CR-6) mathematically
keeps the hardest primary-path hit at `floori(83 × 1.80 × 1.20) = 179`
— the DAMAGE_CEILING=180 cap never fires in normal play. It activates
only under synthetic class-guard-bypass scenarios (EC-DC-9 dual-passive
stack producing `P_mult = 1.38`, `floori(83 × 1.80 × 1.38) = 206` →
clamped to 180) and remains in place as a defense-in-depth wall + a
forward-compat upper bound for future buff pathways. Pillar-1 invariant
"no single attack > 60% of HP_CAP=300" holds at 179 (59.7%).

### F-DC-7 — `counter_reduction` (CR-10)

```
counter_reduction(raw) -> int:
    return max(MIN_DAMAGE, floori(raw * COUNTER_ATTACK_MODIFIER))
```

`COUNTER_ATTACK_MODIFIER = 0.5` halves the final post-cap damage. This is the
final stage on the counter path (OQ-DC-3 resolution) — composes cleanly with
Stage-2 ceiling, so a maxed-out counter caps at `floori(180 × 0.5) = 90`.

### Worked Examples (D-1 through D-10)

These examples double as test fixtures for `tests/unit/damage_calc_test.gd`.
Constants reference registry values as of 2026-04-18.

**D-1 — Baseline FRONT attack (no advantages)**
- Inputs: Cavalry ATK=80, target Infantry DEF=50, direction=FRONT, no passives,
  no terrain, primary attack.
- `eff_atk=80, eff_def=50, T_def=0, defense_mul=1.00`
- `base = min(83, max(1, 80 − 50×1.00)) = 30`
- `D_mult = 1.00 × 1.00 = 1.00`; `P_mult = 1.00`
- `raw = min(180, max(1, floori(30 × 1.00 × 1.00))) = 30`
- **Result: 30**

**D-2 — BASE_CEILING invariant (high ATK FRONT)**
- Inputs: ATK=190, DEF=10, FRONT, no passives.
- `base = min(83, max(1, 190 − 10×1.00)) = min(83, 180) = 83`
- `raw = min(180, floori(83 × 1.00 × 1.00)) = 83`
- **Result: 83** — confirms BASE_CEILING=83 (rev 2.4) prevents raw ATK
  from outstripping positional payoff (the same ATK on REAR + Charge
  prints 179; see D-4).

**D-3 — Cavalry REAR Charge (peak legibility anchor)**
- Inputs: Cavalry ATK=80 (charge_active), target Infantry DEF=50, REAR,
  passive_charge, no terrain, primary attack.
- `base = min(83, max(1, 80 − 50×1.00)) = 30`
- `D_mult = 1.50 × 1.20 = 1.80`; `P_mult = 1.20` (Charge on primary)
- `raw = min(180, floori(30 × 1.80 × 1.20)) = min(180, 64) = 64`
- **Result: 64** — 형세의 결산 in action: REAR + Charge converts a 30-baseline
  into 64, a 2.13× effective swing from positioning alone.

**D-4 — Hardest primary-path hit (max ATK + Cavalry REAR + Charge)**
- Inputs: Cavalry ATK=200, DEF=10, REAR, charge_active, passive_charge.
- `base = min(83, 200 − 10) = 83` (BASE_CEILING fires)
- `D_mult=1.80, P_mult=1.20`
- `raw = min(180, floori(83 × 1.80 × 1.20)) = min(180, 179) = 179`
  (DAMAGE_CEILING does NOT fire — 179 < 180)
- **Result: 179** — the maximum resolved damage reachable in MVP primary
  paths. Pillar-1 promise: no single attack exceeds 60% of HP_CAP=300;
  max Cavalry REAR+Charge (179) differentiates from REAR-only (`floori(83
  × 1.80) = 149`) by 30 points, giving directional+passive payoff a
  visible peak even when ATK is at the stat ceiling. DAMAGE_CEILING=180
  remains a silent defense-in-depth wall per CR-9 (rev 2.4); see EC-DC-9
  synthetic bypass case for the only path that actually triggers it.

**D-5 — MIN_DAMAGE floor (overwhelming DEF)**
- Inputs: ATK=30, DEF=100, FRONT, T_def=+30.
- `defense_mul = 1.0 − 30/100 = 0.70`
- `base = min(83, max(1, 30 − 100×0.70)) = max(1, −40) = 1`
- `raw = min(180, max(1, floori(1 × 1.00 × 1.00))) = 1`
- **Result: 1** — hp-status.md:98 contract preserved.

**D-6 — Defender elevation reduces damage (negative T_def)**
- Inputs: ATK=60, DEF=50, FRONT, T_def=−30 (defender has elevation advantage).
- `defense_mul = 1.0 − (−30)/100 = 1.30` (defender's effective defense
  amplified by 30%)
- `base = min(83, max(1, floori(60 − 50×1.30))) = max(1, floori(−5)) = 1`
- `raw = 1`
- **Result: 1** — Defender elevation **reduces** damage by amplifying
  `eff_def`. Sign convention per CR-4: **negative** `terrain_def` = defender
  benefits; **positive** = attacker benefits (see D-7 for the positive case).

**D-7 — Terrain PENALTY on defender**
- Inputs: ATK=80, DEF=50, FRONT, T_def=+20 (defender on disadvantageous terrain).
- `defense_mul = 1.0 − 20/100 = 0.80`
- `base = min(83, max(1, floori(80 − 50×0.80))) = 40`
- `raw = min(180, floori(40 × 1.00 × 1.00)) = 40`
- **Result: 40** — 33% uplift from baseline D-1 via terrain alone.

**D-8 — DEFEND_STANCE counter (revision 2 — retuned for tactical weight)**
- Inputs: ATK=120 (attacker is defend_stance_active and counter-attacking),
  DEF=40, FRONT, `is_counter=true`. No charge/ambush. `T_def=0`.
- `eff_atk = clampi(120, 1, 200) = 120` → DEFEND_STANCE penalty (CR-5
  applied **exactly once** per counter resolution) → `floori(120 × 0.60) = 72`
- `base = min(83, max(1, 72 − 40×1.00)) = 32`
- `D_mult=1.00, P_mult=1.00` (Charge/Ambush disabled on counter path per CR-8)
- `raw = min(180, floori(32 × 1.00 × 1.00)) = 32`
- `counter_final = max(1, floori(32 × 0.50)) = 16`
- **Result: 16** — DEFEND_STANCE counter is now **tactically meaningful**
  (creative-director synthesis: target 12-18 range) instead of cosmetic.
  Attackers must reconsider engaging guarded units; the counter is a real
  punish, not a flavor gesture. The DEFEND_STANCE_ATK_PENALTY is applied
  **once** (no double-count) — the original-attack damage reduction lives
  in HP/Status's intake pipeline and is never re-applied here.

**D-8 tactical-weight target:** ATK=120 is the canonical mid-game
DEFEND_STANCE counterer. The 12–18 counter-damage range makes the counter
a real punish (attackers reconsider engaging guarded units) rather than a
flavor gesture.

**D-9 — Scout Ambush on FLANK**
- Inputs: Scout ATK=70 (`passive_ambush`, unit_class==SCOUT), DEF=40, FLANK,
  `modifiers.round_number=3`, defender acted_this_turn=false,
  `is_counter=false`.
- `base = min(83, 70 − 40×1.00) = 30`
- `D_mult = 1.20 × 1.00 = 1.20`; `P_mult = 1.15` (Ambush class+counter+round
  gates all open per CR-8 rev 2)
- `raw = min(180, floori(30 × 1.20 × 1.15)) = min(180, 41) = 41`
- **Result: 41**

**D-10 — Evasion MISS path**
- Inputs: ATK=80, DEF=50, FRONT, `defender.terrain_evasion=30`,
  rng seeded so `randi_range(1,100) = 25`, `is_counter=false`.
- `T_eva = clampi(30, 0, 30) = 30`; `25 <= 30` → MISS.
- **Result: `ResolveResult.MISS()`** — HP/Status NOT called; hp-status.md:98
  contract preserved via bypass.

**Quantization invariant (ties to `grid-battle.md` §AC-GB-07)**: Every float
operation in F-DC-3 through F-DC-6 is immediately wrapped in `snappedf(·, 0.01)`
before the next multiplication, and every stage boundary is `floori`'d to int.
**Cross-platform determinism contract (revision 2 — softened):** the
quantization design is intended to minimize platform IEEE-754 divergence by
collapsing residue to 2 decimal places at every multiplicative boundary;
the CI matrix (Windows/D3D12, macOS/Metal, Linux/Vulkan) establishes a
**known-good baseline** for D-1 through D-10, and any divergence between
platforms is treated as a **regression to investigate** (not necessarily a
hard test failure with no fix path). Godot 4.6 does not provide a public
bit-identity guarantee for GDScript double arithmetic; if true bit-identity
is later required (networked replay, deterministic netcode), the migration
path is integer-only math (multipliers as int×100, integer division
replacing `snappedf`) — captured as a **deferred future ADR**, not
committed here.

## Edge Cases

25 edge cases organized in 9 categories (rev 2.4 removed EC-DC-26 —
Scout/Archer REAR+Ambush ceiling clamp — because BASE_CEILING=83 makes
the clamp scenario unreachable in MVP; see review log). BLOCKER cases
MUST have a unit-test fixture in `tests/unit/damage_calc_test.gd`
before shipping; IMPORTANT cases SHOULD have one; MINOR cases document
ownership/intent without requiring a Damage Calc test. Severity counts:
15 BLOCKER, 7 IMPORTANT, 3 MINOR.

**Carry-over decisions resolved during edge-case analysis (2026-04-18):**
- **OQ-DC-9 → CR-12 amended**: the `skill_id != ""` stub path returns
  `ResolveResult.MISS()` with `source_flags ∪ {"skill_unresolved"}`, NOT
  `HIT(0, …)`. Grid Battle distinguishes real misses (no flag) from stub
  paths (flag present) for logging. HP/Status is never called either way.
- **OQ-DC-10 → guard pattern locked**: null RNG, unknown class, or unknown
  `direction_rel` cause `push_error(reason)` + return `ResolveResult.MISS()`.
  `MISS()` is the safe no-op sentinel. CI surfaces the `push_error` line so
  caller-contract violations become visible without enlarging the
  `ResolveResult` union.

### A. Numeric Boundaries

**EC-DC-1** (BLOCKER) — `get_modified_stat` returns 0 or negative for ATK
(extreme debuff stack). CR-3's `clampi(result, 1, ATK_CAP)` re-floors to 1
before CR-5 operates. Damage Calc's clamp is the authoritative guard;
HP/Status modifier_floor cannot push a stat below 1 as seen here.
*Fixture*: raw=2, modifier_stack=−50% → eff_atk=1.

**EC-DC-2** (BLOCKER) — DEFEND_STANCE penalty applied to `eff_atk = 1`:
`floori(1 × 0.60) = 0`. There is intentionally NO second clamp after CR-5;
recovery happens at CR-6 via `max(MIN_DAMAGE, …)`. Specified path:
0 → base=1 → raw=1 → counter_final=1.
*Fixture*: is_counter=true, defend_stance_active=true, eff_atk_raw=1,
eff_def=50.

**EC-DC-3** (BLOCKER) — `terrain_def` boundary equality at ±30, and
out-of-range ±31. `clampi(±31, −30, +30)` yields ±30; +30/−30 pass through
unchanged. defense_mul = 0.70 / 1.30 respectively.
*Fixture*: T_def ∈ {−31, −30, 0, +30, +31} all produce expected defense_mul.

**EC-DC-4** (BLOCKER) — `terrain_evasion = 30` and roll = 30. `roll <= T_eva`
is INCLUSIVE: `30 <= 30 → MISS`. Switching to `<` would silently reduce
evasion to 29%. The inclusive boundary is the locked intent.
*Fixture*: seeded RNG producing roll=30 → MISS; roll=31 → pipeline continues.

**EC-DC-5** (IMPORTANT) — `terrain_evasion = 0`. `randi_range(1,100)` minimum
is 1; `1 <= 0 = false`. No MISS possible. RNG IS still consumed (replay
determinism requires stable call count: exactly 1 randi per non-counter,
0 per counter).
*Fixture*: terrain_evasion=0 → always HIT; assert RNG advanced exactly once.

**EC-DC-6** (MINOR) — snappedf rounding-tie cases. Under current
integer-only `T_def` input, no 0.005 ties arise. Documented as a future-risk
guard: any non-integer terrain input added later MUST re-validate this
invariant. Godot `snappedf` uses **round-half-away-from-zero** (delegates to `round()`; see AC-DC-50 for engine-reference pin).

**EC-DC-7** (BLOCKER) — `get_modified_stat` returns 201 (HP/Status cap bug).
`clampi(201, 1, 200) = 200`. Damage Calc's clamp is the LAST defense and
must never trust upstream caps.
*Fixture*: mock returning {199, 200, 201} → eff_atk = {199, 200, 200}.

### B. Conditional / Stage Interactions

**EC-DC-8** (BLOCKER) — Counter + Charge: `is_counter=true` AND
`passive_charge` AND `charge_active`. CR-8 explicitly guards
`not modifiers.is_counter`; Charge bonus is suppressed. P_mult stays 1.0
(or 1.15 if Ambush also fires).
*Fixture*: same inputs with is_counter ∈ {true, false} → P_mult ∈ {1.00, 1.20}.

**EC-DC-9** (IMPORTANT) — Both passives stacked degenerate scenario
(defense-in-depth check). The class-mutex guards in F-DC-5 (Charge requires
CAVALRY, Ambush requires SCOUT/ARCHER) make `P_mult = 1.20 × 1.15 = 1.38`
**impossible by design** — see AC-DC-27. This edge case is retained as a
*defense-in-depth* invariant: if a future bug ever removes a class guard,
the DAMAGE_CEILING=180 must still absorb the overflow. Synthetic fixture
(class guards bypassed via test seam): D_mult=1.80, P_mult=1.38, base=83
→ floori(83×1.80×1.38) = 206 → clamped to **180**. Two-stage cap is the
second wall behind the class mutex.
*Fixture*: bypass-guards test mode, REAR, eff_atk=200, eff_def=10,
charge+ambush both forced → raw=180.

**EC-DC-10** (BLOCKER) — Counter + DEFEND_STANCE + min-ATK degenerate stack.
eff_atk=1 → CR-5 floors to 0 → CR-6 saves to base=1 → F-DC-6 raw=1 →
F-DC-7 `max(1, floori(1×0.5)) = max(1,0) = 1`. End-to-end MIN_DAMAGE
contract holds across two suppression mechanics + counter halve.
*Fixture*: is_counter=true, defend_stance_active=true, eff_atk_raw=1,
eff_def=50, T_def=0 → final = 1.

### C. Skill-ID Stub Path (OQ-DC-4 deferred → OQ-DC-9 resolved)

**EC-DC-11** (BLOCKER) — `modifiers.skill_id != ""`. Per OQ-DC-9 resolution,
return `ResolveResult.MISS(source_flags: [&"skill_unresolved"])`
IMMEDIATELY — before evasion roll, before stat reads. RNG NOT consumed
(call count = 0). vfx_tags empty. Grid Battle reads the flag for logging
and treats as no-op. HP/Status not called.
*Fixture*: skill_id="fireball" → MISS, `result.source_flags.has(&"skill_unresolved")`,
RNG call count = 0.

### D. DoT / True Damage Bypass Invariant (OQ-DC-8)

**EC-DC-12** (IMPORTANT) — Forward-compatibility invariant. Damage Calc's
`attack_type` enum is `{PHYSICAL, MAGICAL}` — no `POISON` or `DOT` value
exists, so callers cannot accidentally route DoT through `resolve()`. Any
future enum extension is a BREAKING CHANGE requiring a Damage Calc GDD
amendment that adds an explicit guard returning an error sentinel for
non-instant damage types. HP/Status owns `apply_dot_tick()` exclusively.

### E. RNG Boundary

**EC-DC-13** (BLOCKER) — `modifiers.rng == null`. Per OQ-DC-10 resolution
(rev 2.4 flagged-MISS redesign), `push_error("damage_calc.resolve:
modifiers.rng is null")` AND return `ResolveResult.MISS(source_flags:
[&"invariant_violation:rng_null"])`. Silent default would break
determinism (different callers' null-handling diverging). MISS sentinel
is safe (no HP/Status call, no damage); the flag makes the violation
programmatically testable without any engine error-count API.
*Fixture*: rng=null → push_error fires AND
`result.source_flags.has(&"invariant_violation:rng_null")` returns true
(see AC-DC-19).

**EC-DC-14** (BLOCKER) — Replay determinism. Grid Battle owns RNG snapshot;
Damage Calc's contract is exactly 1 `randi_range` call per non-counter
attack, 0 per counter, 0 per skill stub. Any drift in call count breaks
save-load replay (cross-system contract with `save-load.md`).
*Fixture*: snapshot RNG state → call resolve() → restore → call again →
outputs identical **on the same platform** (same OS + same renderer
backend). Run for HIT, MISS, counter, and skill_unresolved paths; verify
call counts {1, 1, 0, 0}. Cross-platform replay is governed by the softened
determinism contract (§Formulas rev 2) — divergence is `WARN`, not a
per-push fail.

### F. Class / Direction Unknowns

**EC-DC-15** (BLOCKER) — `attacker.unit_class` not in `CLASS_DIRECTION_MULT`
(future GUARDIAN, corrupted Hero DB). Per OQ-DC-10 (rev 2.4 flagged-MISS
redesign): `push_error("unknown unit_class: " + str(attacker.unit_class))`
AND return `MISS(source_flags ∪ {&"invariant_violation:unknown_class"})`.
Do NOT silently default to Infantry — that would mask Hero DB / Unit Role
data bugs and produce wrong damage with no signal.
*Fixture*: attacker.unit_class = UnitRole.Class.GUARDIAN (hypothetical)
→ push_error, MISS with `&"invariant_violation:unknown_class"` flag
asserted on `result.source_flags`.

**EC-DC-16** (BLOCKER) — `modifiers.direction_rel` null or unrecognized.
Same guard pattern as EC-DC-15 (rev 2.4): `push_error(<reason>)` +
`MISS(source_flags: [&"invariant_violation:unknown_direction"])`.
*Fixture*: direction_rel ∈ {null, &"DIAGONAL"} →
`result.source_flags.has(&"invariant_violation:unknown_direction")`
returns true.

### G. Defender / Attacker Degenerate States

**EC-DC-17** (IMPORTANT) — Defender at 0 HP when resolve() is called.
Damage Calc does NOT check HP. Pre-condition gate is Grid Battle's. If
violated, resolve() returns valid damage; HP/Status clamps at 0. The
acceptance criterion belongs on Grid Battle, not here. Documented to make
ownership explicit.

**EC-DC-18** (MINOR) — Self-attack (attacker.unit_id == defender.unit_id).
Damage Calc has no relationship awareness; processes normally. Self-attack
gating is Grid Battle's responsibility.

**EC-DC-19** (MINOR) — Same-faction attack (friendly fire). Same as
EC-DC-18: Damage Calc has no faction concept. Friendly-fire gating belongs
to Grid Battle.

### H. Determinism / Cross-Platform

**EC-DC-20** (BLOCKER) — `floori` vs `int()` divergence on negative floats.
Every int conversion in F-DC-3 through F-DC-7 MUST use `floori()`, never
`int()`. `floori(-0.7) = -1`; `int(-0.7) = 0`. Code-review guard: any
contributor using `int()` in these formulas introduces a silent platform
bug.
*Fixture*: snappedf-and-floori chain on negative intermediate → matches
locked Windows/macOS/Linux baseline.

**EC-DC-21** (IMPORTANT) — snappedf precision LOCKED at 0.01. Changing to
0.001 would shift D-1 through D-10 outputs by ±1 in IEEE-754 residue cases
and re-balance the entire registry. The 0.01 value is a LOCKED constant,
NOT a tuning knob.
*Fixture*: re-run D-9 (Ambush + FLANK Scout) with snappedf precision =
0.001 and verify divergence; document divergence as proof the lock is
non-trivial.

### I. Additional / Cross-System

**EC-DC-22** (IMPORTANT) — Ambush gate vs dead defender. If Grid Battle
fails its dead-defender gate (EC-DC-17), Ambush could fire against a dead
unit. Owned upstream; documented here as a cross-system dependency.

**EC-DC-23** (BLOCKER) — Counter halve of minimum raw: `raw=1 →
floori(1×0.5) = 0 → max(1,0) = 1`. The MIN_DAMAGE floor in F-DC-7 must
catch this. Most likely path to produce a 0-damage event that violates
hp-status.md:98.
*Fixture*: synthetic raw=1 entering F-DC-7 → counter_final = 1.

**EC-DC-24** (IMPORTANT — softened from BLOCKER in rev 2) — IEEE-754 residue
in P_mult: `1.20 × 1.15` is `1.3799999999999999` in double precision.
`snappedf(1.3799…, 0.01)` rounds to `1.38` on the project's tested
platforms; the value is **not** a tie case (the argument is not exactly
1.385), so platform-specific tie-breaking does not apply. The CI fixture
runs on all three target backends and treats any divergence as a
**regression to investigate** per the §Formulas determinism contract — not
necessarily a hard fail with no fix path. If a future platform diverges,
the migration path is integer-only math (deferred ADR), not blocking ship.
*Fixture*: `assert(snappedf(1.20 * 1.15, 0.01) == 1.38)` runs on all three
target platforms; CI surfaces divergence with a `WARN` annotation, not a
build break, until the integer-math migration decision is made.

**EC-DC-25** (BLOCKER — rev 2.2) — StringName type-contract violation on
`attacker.passives`. The GDScript `in` operator matches by value **and
type**: `"passive_charge" in ["passive_charge"]` (String in Array[String])
returns `true`, but `StringName("passive_charge") in ["passive_charge"]`
returns **false**. If Grid Battle ever passes `Array[String]` instead of
`Array[StringName]` (direct array literal, mis-typed Dictionary field,
JSON deserialization without coercion), the Charge / Ambush passives
silently never fire — no error, no log, just quietly wrong damage values.
Damage Calc's F-DC-5 entry point resolves this by typing the argument as
`attacker: AttackerContext` (a RefCounted with `var passives:
Array[StringName]`) rather than a Dictionary. GDScript 4.6 enforces the
inner type on parameter binding and field assignment, so callers cannot
pass an `Array[String]` through the boundary — the type mismatch raises
at the Grid Battle call site, not silently inside F-DC-5. The body also
uses `StringName` literals (`&"passive_charge"`, `&"passive_ambush"`) so
comparisons stay type-correct in any path. A regression test in
`damage_calc_test.gd::test_ec25_passives_wrong_type` constructs an
`AttackerContext` via the bypass seam with a hand-built `Array[String]`
and asserts the resulting `P_mult` equals `1.00` (NOT `1.20`), proving
the StringName literal prevents the silent-wrong-answer regression even
if the type boundary is circumvented. See AC-DC-51.

### Verify-against-engine items (forwarded to Acceptance Criteria)

- Godot 4.6 `randi_range(from, to)` is documented inclusive on both ends in
  the Godot 4.x API stable since 4.0. EC-DC-4 depends on this. Add an AC
  test pinning the contract.
- Godot 4.6 `snappedf` **round-half-away-from-zero** behavior on tie cases
  (relevant to EC-DC-6 forward-risk and EC-DC-24 IEEE-754 residue). See
  AC-DC-50 for the pinned test + engine-reference source.

## Dependencies

Damage Calc is a **leaf consumer** in the runtime data graph: it reads from
five upstream systems and emits a single return value to one downstream
caller (Grid Battle), which fans the result out to HP/Status and VFX.
Per ADR-0001 §Damage Calc line 375, it owns ZERO signals and is therefore
not a dependency target for any signal subscriber.

Each entry below cites the source GDD and locks the bidirectional
reciprocal-update obligation. Any change here that breaks a contract
requires updating the cited GDD in the same patch (and vice versa).

### Upstream Dependencies (Damage Calc reads from these)

| # | System | GDD | Status | Contract Surface |
|---|---|---|---|---|
| 1 | **Grid Battle** (#1) | `grid-battle.md` lines 807–816 | ✅ Designed | Sole caller. Provides `attacker`, `defender`, `modifiers` dictionaries; sets `is_counter` and `skill_id`; owns `modifiers.rng` snapshot. Calls `resolve()` once per primary attack and again per counter. |
| 2 | **Unit Role** (#5) | `unit-role.md` §EC-7 lines 180–193, 503–506 | ✅ Designed | Owns `unit_class` (rev 2.5 — renamed from `class`, GDScript 4.6 reserved keyword), `direction_mults` table (Cavalry/Scout/Infantry/Archer × FRONT/FLANK/REAR), `passive_tags`, `charge_active` flag. Multiplicative ordering per EC-7 is non-negotiable. |
| 3 | **HP/Status** (#12) | `hp-status.md:508` (read API); §F-1 (intake pipeline ownership) | ✅ Designed | Provides `get_modified_stat(unit_id, stat_name) → int` with all buffs/debuffs and DEFEND_STANCE penalty pre-folded. Owns `damage_intake_pipeline` formula (registry-locked). MIN_DAMAGE ≥ 1 contract per `hp-status.md:98`. |
| 4 | **Terrain Effect** (#2) | `terrain-effect.md` §Method 2 lines 178–183 | ✅ Designed | Provides `get_combat_modifiers(atk_coord, def_coord)` → `{terrain_def, terrain_eva, elevation_atk_mod, elevation_def_mod, special_rules}`. Damage Calc consumes `terrain_def` ∈ [−30, +30] and `terrain_eva` ∈ [0, 30]; `elevation_*` consumed as opaque ints (OQ-DC-6 deferral). |
| 5 | **Turn Order** (#13) | `turn-order.md` lines 397, 401, 407–408 | ✅ Designed | Provides `get_acted_this_turn(unit_id) → bool` and `get_current_round_number() → int` for the Scout Ambush gate (`round ≥ 2 AND defender.acted_this_turn == false`). |
| 6 | **Balance/Data** (#26) | `balance-data.md` lines 206, 334; `entities.yaml` constants block | ⚠️ Pending | Provides `DataRegistry.get_const(key)` for all 9 + 2 cross-system constants: `BASE_CEILING, DAMAGE_CEILING, COUNTER_ATTACK_MODIFIER, MIN_DAMAGE, MAX_DEFENSE_REDUCTION, MAX_EVASION, ATK_CAP, DEF_CAP, DEFEND_STANCE_ATK_PENALTY, CHARGE_BONUS (NEW), AMBUSH_BONUS (NEW)`. NEVER hardcode in `damage_calc.gd`. |

### Downstream Dependents (these consume Damage Calc's output)

| # | System | GDD | Status | Contract Surface |
|---|---|---|---|---|
| 1 | **Grid Battle** (#1) | `grid-battle.md` line 815 | ✅ Designed | Receives `ResolveResult` (HIT or MISS) and either calls `hp_status.apply_damage(...)` on HIT or no-ops on MISS. Reads `source_flags` to detect `"skill_unresolved"` stub paths and to log `"counter"` / `"charge"` / `"ambush"` provenance. |
| 2 | **HP/Status** (#12) | `hp-status.md` §Contract 1 lines 271–273 | ✅ Designed | Indirect — receives `apply_damage(unit_id, resolved_damage, attack_type, source_flags)` from Grid Battle (NOT directly from Damage Calc). HP/Status applies Shield Wall flat reduction, status modifiers, and HP subtraction. |
| 3 | **AI System** (#8) | `ai-system.md` (not yet written) | ⏳ Future | Will call `resolve()` through Grid Battle (no separate AI path) for threat scoring. Reads `resolved_damage` from `ResolveResult.HIT`. Same RNG snapshot semantics as production calls. |
| 4 | **Battle VFX** (#23) | `battle-vfx.md` (not yet written) | ⏳ Future | Reads `vfx_tags: Array[StringName]` from `ResolveResult.HIT` (e.g., `"ambush"`, `"counter"`, `"terrain_penalty"`). Damage Calc labels; VFX interprets. Damage Calc never invokes VFX directly. |
| 5 | **Save / Load** (#21) | `save-load.md` (provisional) | ⏳ Future | Indirect — Save/Load snapshots Grid Battle's RNG handle. Determinism contract (EC-DC-14) requires that Damage Calc's RNG call count is stable per path: 1 randi per non-counter attack, 0 per counter, 0 per skill stub. |

### F-GB-PROV Retirement (cross-system contract)

`grid-battle.md` §CR-5 Step 7 currently defines `F-GB-PROV` as the
provisional damage formula. Per OQ-DC-2 ratification (Section D), Damage
Calc's `damage_resolve` formula REPLACES `F-GB-PROV` for MVP. Reciprocal
obligation: `grid-battle.md` §CR-5 Step 7 MUST be amended to point at this
GDD and remove the provisional formula in the same patch that registers
`damage_resolve` in `entities.yaml`.

### Bidirectional Citation Audit (must hold after Phase 5)

Each cited GDD MUST contain a back-reference to `damage-calc.md`. Phase 5
post-design validation will verify the following list and add missing
back-references:

- `grid-battle.md` — cites `damage-calc.md` §CR-1, §CR-11 (interface contract);
  must remove `F-GB-PROV` and cite F-DC-1 (Section D).
- `unit-role.md` — cites `damage-calc.md` §CR-7 (consumer of EC-7 ordering)
  and Section D direction tables (locked, owned upstream).
- `hp-status.md` — cites `damage-calc.md` §CR-11 (output contract surface
  for `apply_damage`) and EC-DC-12 (DoT bypass invariant).
- `terrain-effect.md` — cites `damage-calc.md` §CR-4 (terrain_def consumer)
  and EC-DC-3 (clamp boundary semantics).
- `turn-order.md` — cites `damage-calc.md` §CR-8 (Ambush gate consumer).
- `balance-data.md` — cites `damage-calc.md` Section D (constants consumer);
  registry entries for `damage_resolve`, `CHARGE_BONUS`, `AMBUSH_BONUS` add
  `referenced_by: [damage-calc.md]`.
- `entities.yaml` — every `referenced_by` field on the 9 consumed constants
  MUST include `damage-calc.md` (Phase 5 task).

### Cross-system Invariants Locked Here

1. **No HP/Status calls from Damage Calc.** `hp_status.apply_damage` is
   called by Grid Battle, never by Damage Calc. (ADR-0001 enforcement;
   §CR-11 contract.)
2. **Multiplicative direction × class ordering preserved.** Per
   `unit-role.md` §EC-7. Any future change requires Unit Role amendment +
   re-run of D-1 through D-10 + Phase 5 registry update.
3. **DoT routes around Damage Calc.** HP/Status owns `apply_dot_tick()`
   exclusively. (EC-DC-12, OQ-DC-8 resolution.)
4. **RNG ownership is Grid Battle's.** Damage Calc neither owns nor mutates
   RNG state — it only calls `randi_range` via the injected handle. Save/Load
   snapshots Grid Battle, which transitively covers Damage Calc replay.
5. **Constants live in `entities.yaml`, not GDScript.** Damage Calc reads
   via `DataRegistry.get_const(key)`. Hardcoded values are a blocker bug
   per `balance-data.md`.

### Provisional Status Markers

- AI System (#8) and Battle VFX (#23) GDDs do not exist yet. The contracts
  above are *forward declarations* — Damage Calc commits to the API surface
  it exposes today; downstream GDDs must respect it when authored.
- Save/Load (#21) integration is provisional pending its GDD; the
  determinism contract (EC-DC-14) is the binding interface.

## Tuning Knobs

11 knobs total: 2 owned by Damage Calc (TK-DC-1, TK-DC-2 — NEW), 7 consumed
from Balance/Data registry (read-only here, listed for blast-radius
visibility), and 2 locked-not-tunable invariants. Every Damage Calc-owned
knob lives in `entities.yaml` per Dependency invariant #5 — never hardcode.

### TK-DC-1 — `CHARGE_BONUS` (NEW, Damage Calc-owned)

| Field | Value |
|---|---|
| Current | 1.20 |
| Safe range | [1.05, 1.30] |
| Gameplay impact | Cavalry Charge passive multiplier (primary attacks only). Below 1.05 the passive becomes invisible to playtesters; above 1.30 a Cavalry REAR Charge (D_mult=1.80) saturates DAMAGE_CEILING from base ≥ 70, eroding Pillar 1's "earn the big number" feedback (D_mult differentiation flattens). |
| Owner | Damage Calc (this GDD) |
| Blast radius | Re-run D-3, D-4, D-9, EC-DC-9; re-balance Cavalry early-game tutorials. |
| Registry status | Phase 5 candidate. |

### TK-DC-2 — `AMBUSH_BONUS` (NEW, Damage Calc-owned)

| Field | Value |
|---|---|
| Current | 1.15 |
| Safe range | [1.05, 1.25] |
| Gameplay impact | Scout Ambush passive multiplier. Lower bound preserves Scout's role identity (assassinate slow targets pre-action); above 1.25 Scout overshadows Cavalry on FLANK at parity ATK, breaking Pillar 3 (every hero has a role). |
| Owner | Damage Calc (this GDD) |
| Blast radius | Re-run D-9, EC-DC-9; re-evaluate Scout vs Cavalry FLANK damage parity per role-balance matrix. |
| Registry status | Phase 5 candidate. |

### Consumed knobs (read-only here — owners listed for blast tracing)

These constants are consumed by Damage Calc but owned upstream. Tuning
changes require coordinated registry update + re-run of D-1 through D-10.

| ID | Constant | Value | Safe range | Owner | Damage Calc gameplay impact |
|---|---|---|---|---|---|
| TK-DC-3 | `BASE_CEILING` | 83 (rev 2.4 — lowered from 100) | [70, 83] | Balance/Data | Tuned to keep max Cavalry REAR+Charge = `floori(BASE_CEILING × 1.80 × 1.20) = 179` one under DAMAGE_CEILING=180, preserving 30-pt peak differentiation at max ATK. Below 70 → all high-ATK heroes saturate the Stage-1 cap and lose ATK-stat differentiation pre-direction. **Upper bound is exactly 83** (rev 2.5 — BLK-6-3 correction; prior rev 2.4 range `[70, 90]` was arithmetically wrong): at `BASE_CEILING=84`, `floori(84 × 1.80 × 1.20) = floori(181.44) = 181` — already clamped by `DAMAGE_CEILING=180`, which CR-9 and A-8 spec as "unreachable in MVP primary paths." Values 84-90 silently activate the ceiling and break that invariant. Safe range is narrow by design. |
| TK-DC-4 | `DAMAGE_CEILING` | 180 (rev 2: 150→180 raise; rev 2.4: repositioned as silent defense-in-depth wall, unreachable in MVP primary paths) | [160, 220] | Balance/Data | Pillar 1 upper bound: "no single attack > 60% of HP_CAP=300" — 180/300 = 60.0% exact. Rev 2.4: BASE_CEILING=83 tuning makes max primary-path raw = 179; DAMAGE_CEILING activates only under synthetic class-guard-bypass (EC-DC-9) or future forward-compat buffs. Lowering to <160 would start clamping real Cavalry REAR+Charge hits. Tied to HP_CAP=300; coordinated retune required if HP_CAP moves. |
| TK-DC-5 | `COUNTER_ATTACK_MODIFIER` | 0.5 | [0.25, 0.75] | Balance/Data | Below 0.25 counters become decoration; above 0.75 DEFEND_STANCE counter becomes a positive-EV exchange and players spam-defend. |
| TK-DC-6 | `MAX_EVASION` | 30 | [10, 40] | Balance/Data | Hard ceiling on evasion% from terrain. Above 40% feels slot-machine; below 10% terrain evasion becomes invisible. |
| TK-DC-7 | `MAX_DEFENSE_REDUCTION` | 30 | [10, 40] | Balance/Data | Symmetric clamp on `terrain_def`. Defines the band within which terrain_def can shift defense_mul from 0.70 to 1.30. |
| TK-DC-8 | `DEFEND_STANCE_ATK_PENALTY` | 40 | [25, 60] | Balance/Data | Counter-attack ATK reduction (%). Below 25 DEFEND_STANCE becomes pure upside; above 60 stance never lands meaningful counter damage. Composes with COUNTER_ATTACK_MODIFIER (×0.5). |
| TK-DC-9 | `ATK_CAP` / `DEF_CAP` | 200 / 100 | n/a | Balance/Data | Hard caps per Hero stat ceiling. Re-tuning is an economy decision, not a Damage Calc decision. |

### Locked-not-tunable invariants

These appear constant-shaped but are NOT tuning knobs. Changing them is a
breaking design change requiring design-review escalation, NOT a balance
patch.

- **`snappedf` precision = 0.01** (EC-DC-21). Locked per cross-platform
  determinism contract. Changing to 0.001 shifts D-1…D-10 outputs by ±1
  in IEEE-754 residue cases. Constitutes a breaking change to all
  registered worked-example fixtures.
- **`MIN_DAMAGE = 1`** (`entities.yaml` registry). Owned by HP/Status per
  `hp-status.md:98`. Damage Calc consumes only — any change requires
  HP/Status amendment first.
- **`BASE_DIRECTION_MULT` table (1.00 / 1.20 / 1.50)** — owned by
  `unit-role.md` §EC-7. Locked per Pillar 1 directional-payoff design.
- **`CLASS_DIRECTION_MULT` table (4 × 3 grid)** — owned by `unit-role.md`
  §EC-7. Locked per Pillar 3 role-identity design. Cavalry REAR=1.20 and
  Scout REAR=1.10 are the role-defining anchors and cannot move
  independently.

### Tuning Governance

1. **All Damage Calc-owned knobs (TK-DC-1, TK-DC-2)** are tunable via
   `entities.yaml` ONLY. Hardcoding them in `damage_calc.gd` is a
   blocker bug per Dependency invariant #5.
2. **Cross-system tuning (TK-DC-3 through TK-DC-9)** requires a coordinated
   change ticket: update `entities.yaml` + amend the owning GDD + re-run
   D-1 through D-10 + verify acceptance criteria still pass. Blast radius
   per knob is documented above.
3. **Locked-not-tunable invariants** require a design review and may not
   change in a balance patch. Any proposal must produce a written
   rationale and pass through the GDD amendment process.
4. **Out-of-range proposals** (values outside Safe Range) require a
   `creative-director` sign-off documenting the design intent that
   justifies the deviation — Pillar 1 / Pillar 3 are the typical
   constraints flagged.
5. **Worked-example regeneration**: any TK-DC-1 through TK-DC-9 change
   requires regenerating D-1 through D-10 in this GDD as the new test
   baseline before merging the registry update. The GDD and the registry
   are atomic: they ship in the same patch or neither.

## Visual/Audio Requirements

Two subsections: Visual (V-1…V-7) authored by `art-director`, Audio
(A-0…A-10) authored by `audio-director`. Combat category requires both.
Five new open questions (OQ-VIS-01/02, OQ-AUD-01/02/03) carried to
Section K with default resolutions documented inline.

### V — Visual: Damage Popup Specification

#### V-1. Damage Popup Palette

Four states. sRGB hex. 주홍 `#C0392B` and 금색 `#D4A017` are categorically
forbidden — destiny-branch reservation, see V-6.

| State | Trigger | Number | Backing | Rationale |
|---|---|---|---|---|
| HIT_NORMAL | D_mult ≤ 1.20 | 묵 `#1C1A17` | 지백 `#F2E8D4` @ 55%, 2px blur | Ink on parchment — quietest moment |
| HIT_DIRECTIONAL | 1.20 < D_mult ≤ 1.50 | 청회 `#5C7A8A` | 묵 `#1C1A17` @ 45%, 2px blur | Cool tactical confidence; matches "player control" UI register |
| HIT_DEVASTATING | D_mult > 1.50 (Cavalry REAR=1.80, Scout REAR=1.65) | 지백 `#F2E8D4` | 묵 `#1C1A17` @ 80%, 4px blur | Inverse contrast — severity in backing weight, no new hue |
| MISS | `ResolveResult.MISS()` | 소록-desat `#8A9A82` | none | Visually silent; not reward, not punishment |

#### V-2. Typography

- Weight Bold (700) or Black (900) only. Brush-style CJK-compatible sans
  with ink-stroke terminals.
- Base size 28sp (HIT_NORMAL); HIT_DIRECTIONAL 34sp (+21%); HIT_DEVASTATING
  42sp (+50%); MISS 22sp (smaller — absence of impact).
- Spawn at 85% scale → eases to 100% over 80ms (cubic ease-out, no overshoot).
- Shadow: single directional, offset (0px, 2px), color 묵 @ 40%. No glow.
- Letter-spacing 0; tracking spread reads as weakness.
- **Multiplier annotation (HIT_DEVASTATING + HIT_DIRECTIONAL; rev 2.5
  intro — BLK-6-5; rev 2.6 tier-extended — BLK-7-8 sub-DEVASTATING
  legibility)**: 16sp / Regular weight, `× combined` form, 청회
  `#5C7A8A`, 4px below the integer. The annotation shows the
  **combined** multiplier `snappedf(D_mult × P_mult, 0.01)` whenever
  that combined value > `1.00` (i.e., the hit has direction and/or
  passive provenance worth advertising). Prior rev 2.5 restricted
  annotation to HIT_DEVASTATING only (D_mult > 1.50), which hid
  Charge and Ambush contributions on HIT_DIRECTIONAL tier hits: Scout
  REAR+Ambush (combined 1.90, lands in DEVASTATING — covered), Archer
  REAR (combined 1.35, DIRECTIONAL — previously hidden), Cavalry FLANK
  (combined 1.32, DIRECTIONAL — previously hidden), Archer FLANK
  no-passive (combined 1.65 post rev 2.6 Archer retune, now in
  DEVASTATING — covered). Rev 2.6 extends annotation to HIT_DIRECTIONAL
  so the passive/direction contribution is on the primary legibility
  surface across both tiers that have non-trivial multipliers; only
  HIT_NORMAL (combined ≤ 1.20) and MISS suppress the annotation. The
  player reads `64` then `× 2.16` and connects to four turns of
  positioning + the Charge payoff. Canonical examples: Cavalry REAR +
  Charge = `× 2.16`; pure Cavalry REAR = `× 1.80`; Archer FLANK (rev
  2.6 post-retune, no passive) = `× 1.65`; Cavalry FLANK no-passive =
  `× 1.32`; Archer REAR = `× 1.35`; dual-passive synthetic bypass
  (EC-DC-9) = `× 2.48`. The full breakdown (Direction × Class × Passive
  decomposition) remains available in the on-demand UI-2 tooltip.

#### V-3. Animation Envelope

Cubic ease-in-out throughout. No bounce, no elastic, no stretch.

| State | Spawn | Rise | Hold | Fade | Total |
|---|---|---|---|---|---|
| HIT_NORMAL | 85→100% | 80ms | 400ms | 200ms | 680ms |
| HIT_DIRECTIONAL | 85→100% | 100ms | 450ms | 220ms | 770ms |
| HIT_DEVASTATING | 85→100% | 120ms | 600ms | 300ms | 1020ms |
| MISS | 90→100% | 60ms | 250ms | 180ms | 490ms |

- Upward drift 28px over full duration, linear Y.
- Queue rule (default): one popup per unit at any time. Second resolve
  cuts the first to fade phase (min 80ms). No stacking on the same unit.
- **Reduce Motion queue exception (rev 2.6 — BLK-7-7 accessibility
  regression fix):** When Reduce Motion is enabled (per UI-4), the
  default cut-to-fade policy would nullify the mandated 1200ms reading
  window on any AoE or rapid second-hit scenario — starving the very
  accessibility population the 1200ms hold is meant to serve. Under
  Reduce Motion, the queue rule is replaced: subsequent resolves on the
  same unit **queue sequentially**, up to **3 pending** popups, rendered
  back-to-back in resolution order. Each pending popup waits for the
  prior popup's full `max(baseline_hold, 1200ms) + 350ms fade = 1550ms`
  lifecycle before spawning. On queue overflow (4+ pending in the same
  burst), the **oldest pending** popup is dropped silently (the tier
  swell audio still fires so the hit is not audibly lost; screen-reader
  announcement still emits per UI-4 throttle rules). The visible
  consequence is that Reduce Motion users see slower sequential damage
  numbers during AoE rather than blurred cut-frames — preserves reading
  time, loses real-time pacing, which is the correct accessibility
  tradeoff per WCAG 2.1 SC 2.3.3 "Animation from Interactions" guidance
  (non-essential motion must be controllable by the user).
- Hard ceiling: 1020ms default / 1550ms per queued popup under Reduce Motion.

#### V-4. VFX-tag → Visual Mapping

| `vfx_tag` | Signal | Where | Rationale |
|---|---|---|---|
| `"counter"` | 반격 (半擊) brushstroke glyph, 청회 `#5C7A8A`, 14sp, top-left of number, 400ms, fades with popup | Overlay on popup | Identifies counter without elevating to spectacle |
| `"charge"` | NONE on popup body. The HIT_DEVASTATING state IS the signal. Edge case (FRONT Charge stays ≤ 1.50): apply 1px 황토 `#C8874A` border on backing. | Border only | Visual identity expressed via tier, not flourish |
| `"ambush"` | 200ms ink-wash vignette pulse on TARGET TILE (묵 `#1C1A17` @ 25%). Does NOT touch popup. | Tile, separate from popup | Spatial meaning: "they were caught" — anchored on position, not damage |
| `"terrain_penalty"` | NONE on popup. Tile hover tooltip surfaces detail. | — | Popup is verdict, not breakdown |
| `"skill_unresolved"` | NONE. No popup rendered at all. | — | Stub path; do not advertise unimplemented features |

#### V-5. Cross-Platform Constraints

- ≤ 3 draw calls per visible popup; worst case 30 added to <500 budget.
- `CanvasLayer` rendering only; no world-space post-processing dependency.
- No custom shaders. `CanvasItem` modulate, `Label`/`RichTextLabel` for
  numbers, `ColorRect`/`NinePatchRect` for backing. Keeps Android Vulkan
  pipeline clean.
- Font: Godot `FontFile`, `subpixel_positioning = DISABLED` on mobile.
  Logical-pixel sizing scales with display density.
- Popups offset above unit bounding box — must NOT obscure 44px touch
  target on tile.
- Glyph atlasing: `ui_atlas_*.png` to avoid texture bind switches.

#### V-6. Restraint Rules (Visual — FORBIDDEN)

- No screen shake (any state including HIT_DEVASTATING).
- No chromatic aberration.
- No elastic / bounce / overshoot easing.
- No squash-and-stretch on digits.
- No calligraphic decoration on the digits themselves.
- No 주홍 `#C0392B` (destiny reserved).
- No 금색 `#D4A017` (destiny reversal reserved).
- No simultaneous stacked popups on same unit (§V-3 queue rule).
- No particle burst on the number (Battle VFX domain only).
- No color-only differentiation — every state distinguishable by size +
  backing opacity (color-blind safety per art-bible §4.5).

#### V-7. Reference Language (Visual)

- **FF Tactics (1997)** — borrow: plain integer over unit, minimal
  animation, monochrome normal hits. Reject: yellow-on-black backing
  (generic JRPG register).
- **Triangle Strategy (2022)** — borrow: damage-as-functional-report,
  weighted typography. Reject: modern flat UI backing — ours must read as
  ink on parchment per art-bible §3.4 (목간/비단 지도 grammar).
- **Explicitly NOT a reference**: Disgaea, Tales Of, Marvel Snap — number
  size/bounce/screen coverage as core combat aesthetic. The "JRPG
  crit-fest" the Player Fantasy NOT-list bans.

---

### A — Audio: Damage Resolution Cues

#### A-0. Trigger Pipeline Disclaimer

Damage Calc emits ZERO signals (ADR-0001 §Damage Calc). Audio is
triggered downstream by Battle VFX (#23, future) reading `vfx_tags` from
`ResolveResult`, or by Grid Battle as MVP fallback. This GDD specifies
audio INTENT and perceptual targets, NOT the trigger pipeline.

#### A-1. Hit Cue Layering (3 layers max)

- **(a) Impact transient** — physical: dry wood-on-wood thump, attack <20ms,
  decay <80ms; magical: brief struck-metal chime, attack <15ms, decay <100ms.
  Always present on HIT.
- **(b) Tier swell** — textural (breath / low-shelf resonance / muted
  string harmonic) scaling by `raw / DAMAGE_CEILING`. NEVER melodic. NEVER
  rising. See A-2 band matrix.
- **(c) Provenance overlay** — at most one per hit. If multiple flags
  set, Charge takes priority for overlay; Ambush rides tier swell weight.
  See A-4.

#### A-2. Tier Bands

| Band | raw | Layer (b) family | RMS |
|---|---|---|---|
| SUBTLE | <30 | Near-silent dry brush / breath puff, no pitch | -28 dBFS |
| SOLID | 30–73 | Muted low-string pluck or dampened hand-drum | -22 dBFS |
| DECISIVE | 74–129 | Sustained low-shelf resonance, felt-muted attack | -18 dBFS |
| PEAK | ≥130 | Low bowed-string harmonic, 250ms hold, no crescendo | -14 dBFS |

PEAK pitch envelope: no rise. Peak hits sound definitive, not triumphant.
Ratio computed from raw, not D_mult/P_mult.

> **OQ-AUD-05 (open question, Alpha)** — The tier band thresholds above
> were calibrated against the pre-rev-2 DAMAGE_CEILING=150. With the rev 2
> raise to 180, the PEAK band (≥130) now covers a smaller *fraction* of the
> ceiling range (≥72% → ≥72% of 180), and the DECISIVE/PEAK boundary may
> no longer sit at the intended perceptual break. Audio Director should
> re-audition the bands against the new ceiling during Alpha and confirm
> either: (a) the absolute thresholds {30, 74, 130} still land correctly,
> or (b) they rescale to preserve the fractional bands. No MVP action —
> logged for Alpha.

#### A-3. MISS Cue

- Single short swish / cloth-movement. ≤120ms, no tail.
- RMS -30 dBFS. Quieter than SUBTLE hit transient.
- No descending "sad" glide. Not punishment — it is terrain evasion working.
- Listener must distinguish MISS vs SUBTLE in <100ms at -15 dBFS mix.
- `skill_unresolved` MISS → SILENT (see A-4).

#### A-4. Provenance Overlays

| flag | Sample family | Timing vs (a) | Mix priority |
|---|---|---|---|
| `"counter"` | Reversed-breath / "absorbed" transient | Simultaneous | -6 dB under (a), no duck |
| `"charge"` | Brief low-drum accent / felt-strike | Pre-transient (-40 to -60ms) | -4 dB under (a), no duck |
| `"ambush"` | Dry post-transient (blade-clears-sheath) | +20 to +30ms after (a) | -8 dB under (a), no duck |
| `"skill_unresolved"` | NONE | — | SILENT (no stub tone, no placeholder click) |

Stack rule (EC-DC-9): Charge + Ambush both set → Charge fires overlay,
Ambush expressed via PEAK tier swell weight.

#### A-5. Mix Bus / Voice Cap

- `SFX_Combat` bus, child of `SFX` (-3 dB under master). `AMB` bus separate
  — combat NEVER ducks ambience (ink-wash restraint).
- Polyphony cap: 6 pre-allocated `AudioStreamPlayer` voices.
- Stealing: PEAK > DECISIVE > SOLID > SUBTLE > MISS. PEAK never stolen.
- AoE collision (≥4 hits in <500ms): only highest-tier swell plays;
  remaining hits play layer (a) only.
- Layer (b) and layer (a) count separately in pool.

#### A-6. Loudness Targets

- LUFS-S target for layer (a + b combined, PEAK tier): **-18 LUFS-S** floor
  (mobile audibility — anchor to `entities.yaml beat_2_audio_lufs_min`).
- Operating band: [-18, -14] LUFS-S for combat. SUBTLE/MISS may sit below
  by design.
- True-peak ceiling: -1.0 dBTP on `SFX_Combat` (peak limiter active).
- **PEAK cap locked at -14 LUFS-S** to preserve drama hierarchy below
  destiny-branch events at -12 LUFS-S (provisional, pending Sound/Music #24
  authoring — see OQ-AUD-03).

#### A-7. Cross-Platform Constraints

- Mobile DSP: ≤2 effect processors on `SFX_Combat`. Single peak limiter
  permitted; NO reverb send on mobile combat.
- PC polish: light room sim (RT60 ≤80ms, -12 dB wet) post-MVP only.
- Reverb tail hard cap: 400ms any platform.
- 6-voice pool pre-allocated under `CombatAudioPool` node. **MVP owner:
  Grid Battle (#1)** — Grid Battle instantiates `CombatAudioPool` at
  battle-scene load (alongside its existing audio dispatch role per A-0)
  and tears it down at battle-scene exit. Damage Calc never touches the
  pool; it only labels via `vfx_tags`. Streaming from disk during combat
  FORBIDDEN. Bidirectional citation: `grid-battle.md` MUST be amended in
  Phase 5 to list `CombatAudioPool` ownership and lifecycle in its scene
  responsibilities.
- **Voice overflow policy (AoE 6+ targets):** When `vfx_tags` dispatch
  exceeds 6 concurrent voices in the pool, the pool stops the **oldest
  non-PEAK** voice to free a slot. PEAK-tier voices are never preempted;
  if the pool is fully PEAK-saturated (6 PEAK voices live, rare),
  additional PEAK requests are coalesced into the existing PEAK voice
  rather than opening a 7th. This protects the LUFS-S ceiling and the
  drama hierarchy.
- **Charge + Ambush overlay collision:** Per OQ-AUD-02 default — Charge
  wins the overlay slot; Ambush rides the underlying tier swell without a
  dedicated overlay asset for MVP. The two never collide on the counter
  path (CR-8 rev 2 disables both passives on counters).
- Asset format: `.ogg` Vorbis, VBR Q6, 44100 Hz mono.
- 2D pan: **disabled on mono sources by Godot audio engine semantics** —
  retained as a documentation-only flag for the (post-MVP) stereo polish
  pass. AoE collision collapses to center pan. 3D spatialization OFF.

#### A-8. Restraint Rules (Audio — FORBIDDEN)

- No orchestral stinger.
- No vocal sample on HIT (no grunt / shout / kiai / "haa!").
- No reverb tail >400ms.
- No rising pitch envelope on PEAK.
- No ascending musical motif at any tier.
- No anticipatory swell / drum roll before impact.
- No crit-style screen flash audio tie-in (we have no crits).
- No audio overlay for invariant-clamp events (DAMAGE_CEILING=180 is a
  silent safety wall, unreachable in MVP per F-DC-3/F-DC-6 math; kept for
  defense-in-depth against class-guard bypass).
- No audio on `skill_unresolved` path.
- No stereo widening on combat bus (mobile mono collapse causes phase
  cancellation).

#### A-9. Reference Language (Audio)

- **Into the Breach (2018)** — borrow: short, dry, mechanically legible
  hits. Drama is in grid consequence, not impact. Reject: sci-fi synth
  palette (we are brush + struck-wood).
- **Tactics Ogre: Reborn (2022)** — borrow: physical impact restraint,
  ambience priority over combat SFX. Reject: orchestral sting on crits
  (we have no crits).
- **KOEI 영걸전** (game-concept reference) — context only; sparse SFX is
  stylistic target not fidelity ceiling.

#### A-10. Cross-System Audio Dependencies

- Damage Calc emits NO signals — any audio call inside `damage_calc.gd`
  is an ADR-0001 violation.
- `vfx_tags` is the audio dispatch contract. Battle VFX (#23, future) is
  designated consumer; Grid Battle is MVP fallback (since Sound/Music #24
  is post-MVP).
- Bidirectional citation: `battle-vfx.md` MUST cite §A-4 + §A-10;
  `sound-music.md` MUST cite §A-6 (LUFS floor + dBTP ceiling) and
  reconcile if values conflict.

---

### Open Questions Forwarded to Section K

- **OQ-VIS-01** — `#E07020` (경고 주황) as HIT_DEVASTATING value-contrast
  fallback if playtesting shows insufficient differentiation. **Default**:
  defer, do NOT use; revisit after Vertical Slice. Risk if adopted: hue
  proximity to 주홍 dilutes destiny-branch signal.
- **OQ-VIS-02** — Priority when `"counter"` + `"charge"` co-occur
  (mechanically blocked today by CR-8). **Default**: counter glyph wins,
  charge border suppressed. Confirm with Battle VFX GDD authoring.
- **OQ-AUD-01** — PEAK sub-bass haptic layer on mobile. **Default**: skip
  for MVP (DSP cost vs likely speaker inaudibility), test at Vertical Slice.
- **OQ-AUD-02** — Dedicated stacked Charge+Ambush overlay asset.
  **Default**: deferred — Charge wins overlay, Ambush rides tier swell.
  Revisit if Vertical Slice surfaces feedback that the stack reads as
  Charge-only.
- **OQ-AUD-03** — PEAK LUFS cap reconciliation with Sound/Music #24.
  **Default**: lock at -14 LUFS-S provisionally; coordinated registry
  update required if Sound/Music #24 sets different targets.

## UI Requirements

Damage Calc's UI surface is narrow: damage popups (visual specced in §V),
the damage-breakdown tooltip (the legibility surface for Pillar 1), and
input/accessibility parity. Battle HUD chrome, action menus, and
damage-log panels belong to other systems and are out of scope here.

Use `/ux-design` to author detailed mockups; this section locks behavior
and constraints only.

### UI-1. Popup Placement

- **Anchor**: 24px above the attacker-facing edge of the defender's tile
  bounding box (NOT centered on the tile — must clear the 44px touch target
  per `.claude/docs/technical-preferences.md`).
- **Counter-attack popups**: anchored on the COUNTER-ATTACKER's tile, not
  on the original attacker's. Spatial truth wins over directional reading.
- **Edge-of-screen handling**: if the popup would clip the viewport edge,
  reflect to the opposite side of the tile (down/left/right). Reflection
  rule is deterministic (no per-frame layout solver) — choose by viewport
  quadrant the tile occupies.
- **Camera-pan exclusion**: popups are anchored to world coordinates, not
  screen coordinates. They drift upward in world space and remain pinned
  to the tile if the camera pans during the 1020ms HIT_DEVASTATING window.

### UI-2. Damage Breakdown Tooltip (Pillar 1 legibility surface)

The HIT_DEVASTATING multiplier annotation (§V-2) is the always-on
breakdown. The full breakdown tooltip is the on-demand companion.

**Trigger**:
- Touch: tap the defender tile within 1500ms of a HIT to surface the
  breakdown of the most recent attack on that tile.
- PC: hover the defender tile (also keyboard-focusable via Tab).

**Content** (no hand-waving — exact fields):

```
Attack Resolution
─────────────────
ATK 80 → eff_atk 80
DEF 50 → eff_def 50  (terrain_def +20 → defense_mul 0.80)
base = 80 − (50 × 0.80) = 40

Direction: REAR  × 1.50 (base) × 1.20 (Cavalry) = 1.80
Passive:   Charge × 1.20

raw = floori(40 × 1.80 × 1.20) = 86 → 86
```

- Numbers MUST mirror the exact integers from F-DC-3..F-DC-7.
  Discrepancy = bug.
- **Invariant clamp note (rev 2.4)**: DAMAGE_CEILING=180 is a silent
  safety wall, unreachable in MVP primary paths (max Cavalry REAR+Charge
  = `floori(83 × 1.80 × 1.20) = 179`, one under the ceiling by design
  per F-DC-3 BASE_CEILING=83 tuning). No player-facing "CAPPED" chip —
  the Pillar-1 differentiation is delivered by the 30-point gap between
  REAR-only (149) and REAR+Charge (179) at max ATK, not by clamp
  disclosure. Forward-compat: if a future hero ability or destiny branch
  pushes `raw_uncapped > 180`, this rule revisits and the tri-modal
  disclosure returns (see rev 2.2 history in review log).
- MISS path tooltip shows: `Evasion roll: 25 ≤ T_eva 30 → MISS` — the
  inclusive boundary is visible.
- `skill_unresolved` path: NO tooltip (consistent with no popup, no audio).

### UI-3. Touch + PC Parity (no hover-only interactions)

Per `.claude/docs/technical-preferences.md` Mixed Input policy:

- All UI-2 breakdown content reachable on BOTH touch and PC.
- The 1500ms tap window after HIT is the touch equivalent of PC hover.
- A "🛈 last hit" indicator chip appears on a tile for 1500ms after a HIT
  to communicate the affordance to touch users. Chip hit-area is **44×44**
  per `.claude/docs/technical-preferences.md` Mixed Input policy (rev 2.2
  — prior rev 2.1 text said 24×24 which directly violated the 44px touch
  target mandate). The visible glyph inside the chip may remain small
  (~20sp) for visual restraint, but the hit-area must be 44×44 with a
  transparent padding ring.
- Keyboard nav: Tab cycles through living units; Enter = same as
  hover/tap on focused tile.
- Gamepad (partial support per tech-prefs): right stick to cursor over
  tiles, A/X = inspect.

### UI-4. Accessibility

- **Color-blind safety** (per art-bible §4.5; reinforces V-6): every
  popup state distinguishable by SIZE + BACKING OPACITY in addition to
  color. HIT_NORMAL 28sp / 55% backing; HIT_DEVASTATING 42sp / 80%
  backing. A monochrome filter renders all four states distinguishable.
- **Text scaling**: respect Godot's UI scale setting. Popup sizes (28/34/42sp)
  are SP units that scale with the platform's accessibility text-scale
  preference up to 200%. Layout reflows; queue rule (§V-3) still holds.
- **Motion reduction** (Reduce Motion accessibility flag — rev 2.4 added
  activation-source spec): **Activation source**: (a) **Vertical Slice
  onward — in-game Settings toggle** under Accessibility panel (Settings
  system #28 was elevated from Full Vision → Alpha per
  `design/accessibility-requirements.md` OQ-3, so the toggle is
  player-exposable from Vertical Slice). (b) **OS-flag bridging deferred
  to Full Vision** — Godot 4.6 does not expose a stable "prefers reduced
  motion" OS API outside AccessKit (Godot 4.5+), and AccessKit integration
  is scoped to Full Vision tier. Players on iOS/Android/Windows with OS
  Reduce Motion enabled must still toggle the in-game setting manually
  until AccessKit ships. Documented gap — cross-ref
  `design/accessibility-requirements.md` §4 R-3 (Beat 2 reduced-motion
  alternative, closest authoritative motion-reduction spec) + §2
  "Reduced motion" toggle row. When enabled,
  popup spawn-scale animation is BYPASSED — popup appears at 100% scale
  immediately. **Hold duration (rev 2.3 BLK-4; rev 2.5 WCAG citation
  correction BLK-6-7):** the hold is `max(baseline_hold, 1200ms)` so
  Reduce Motion always **extends** the popup reading window to at least
  1.2s, never shortens it. The relevant WCAG criterion is **WCAG 2.1/2.2
  SC 2.3.3 "Animation from Interactions" (AAA)**, which requires that
  motion animation triggered by interaction can be disabled unless
  essential to the content — damage popup motion is not essential (the
  integer is the content, the drift is stylistic), so Reduce Motion
  must disable it while preserving the reading window. The rev 2.3 text
  cited SC 2.2.1 "Timing Adjustable," which applies to session-level
  time limits ≥20 seconds and is not applicable to a 1.5s popup
  lifecycle. Cognitive-accessibility research independently supports ≥1s
  of unhurried reading time — the population that toggles Reduce Motion
  typically needs *longer* dwell, not shorter. The rev 2.2 formulation `min(baseline_hold,
  400ms)` was inverted — it compressed HIT_DEVASTATING's hold from 800ms
  to 400ms, starving the very users the flag is meant to help. Concrete
  per-tier holds under rev 2.3: HIT_NORMAL = `max(400ms, 1200ms) = 1200ms`;
  HIT_DIRECTIONAL = `max(550ms, 1200ms) = 1200ms`; HIT_DEVASTATING =
  `max(800ms, 1200ms) = 1200ms`; MISS = `max(300ms, 1200ms) = 1200ms`.
  After the hold, popup fades over 350ms (motion-reduction-preserved fade
  timing — matches UI-6 rev 2.3 lifecycle). Drift distance remains reduced
  from 28px to 8px. Tier swell audio still plays. Player can still inspect
  via UI-2.
- **Screen reader / TalkBack**: each HIT emits an announcement
  `"<defender> hit for <raw>, <provenance>"` (e.g., `"Lu Bu hit for 64,
  REAR Charge"`). Throttled to one announcement per 500ms to avoid spam
  during AoE. MISS announces `"<defender> evaded"`. `skill_unresolved`
  → no announcement.
- **Captions for audio cues — MVP minimum (revision 2):** the provenance
  overlays (counter / charge / ambush) MUST have text caption equivalents
  by Beta. Damage Calc commits to providing the `vfx_tags` array as the
  caption-data source AND to surfacing a textual provenance string in the
  TalkBack announcement (already covered by the screen-reader bullet
  above, e.g., `"REAR Charge"`). Visual on-screen captions for hearing-
  impaired non-screen-reader players are owned by Sound/Music #24 but the
  Beta gate (AC-DC-45 rev 2) requires either (a) Sound/Music #24's caption
  pipeline shipped, or (b) a temporary Damage-Calc-side caption fallback
  that renders provenance text under each popup. Decision made at Beta
  scope-cut; default is (b).
- **`skill_unresolved` MISS path affordance (rev 2.3 — BLK-5; rev 2.5 —
  BLK-6-10 player-safe copy):** since this path emits no popup and no
  audio, blind / low-vision players would otherwise receive zero feedback
  on a skill button that silently fails, violating WCAG 2.1 SC 4.1.3
  "Status Messages". TalkBack/VoiceOver announces the **player-safe
  string** `"Skill unavailable"` on the `skill_unresolved` flag in
  **all builds** (production included) — the prior `OS.is_debug_build()`
  gate is removed per WCAG 2.1 SC 4.1.3. Rev 2.5 replaces the rev 2.3/2.4
  text `"<attacker_name> skill not yet implemented"` which leaked
  internal stub copy as production-exposed player text. `"Skill
  unavailable"` is short, player-safe, locale-ready, and carries no
  developer-implementation framing; combined with the no-popup + no-audio
  UX, the semantic is "the action you attempted cannot be performed right
  now" without advertising the unimplemented subsystem. Announcement is a
  polite-priority assertive status message (aria-live equivalent), not a
  disruptive alert, throttled to 1 per 500ms to avoid spam if the player
  repeatedly taps a skill button. Production sighted players remain
  silent-for-the-eye (no popup) but screen-reader users always receive
  the status text. Full sighted-player popup coverage arrives with
  OQ-DC-4 (Skill System GDD) and is not in Damage Calc's scope.
  **CI-lint guard (added rev 2.5 BLK-6-10):** a string-literal audit in
  `damage_calc.gd` and all screen-reader announcement paths forbids any
  occurrence of the tokens `"not yet implemented"`, `"TODO"`,
  `"placeholder"`, `"stub"`, and `"skill_unresolved"` in
  user-facing strings (the internal `StringName &"skill_unresolved"`
  flag used in `source_flags` is the programmatic identifier and stays —
  only player-facing announcement strings are audited). Enforcement is
  a separate CI AC tracked on the HUD/Sound Music GDDs at the point where
  the announcement text is centralized for localization; for MVP the
  damage-calc implementation PR adds the audit to its own file.

### UI-5. Damage Log (HUD chrome — out of scope, contract only)

- Damage Calc commits to the `ResolveResult` field shape (§CR-11) as the
  data contract for any future damage log UI. The log itself is owned by
  the HUD GDD (#22, future).
- Log MUST include `source_flags` so the player can filter to "all
  counters this turn" or "all skill_unresolved events" for debugging.

### UI-6. Performance / Reactivity Targets

- Popup spawn → first frame visible: ≤ 32ms (2 frames at 60fps) from
  `ResolveResult` return.
- Tooltip surface (touch tap or PC hover): ≤ 80ms to render content.
- Concurrent popups across units: up to 10 (max units on screen) in
  flight simultaneously. Tested in `tests/integration/damage_calc_ui_test.gd`.
- Reduce Motion mode: popup lifecycle = `max(baseline_hold, 1200ms) + 350ms
  fade` total (rev 2.3 — BLK-4 correction; replaces the prior 700ms cap,
  which starved the accessibility-flag population of adequate reading
  time — see UI-4 Reduce Motion for full rationale, WCAG SC 2.3.3
  citation per rev 2.5 BLK-6-7). Per-tier lifecycle: HIT_NORMAL /
  HIT_DIRECTIONAL / HIT_DEVASTATING / MISS all = 1550ms total under
  Reduce Motion.

### UI-7. Forwarded to UX

`/ux-design damage-calc` should produce mockups for:

- Default popup at all four states, mobile portrait + PC widescreen.
- Edge-of-screen reflection cases (4 viewport quadrants).
- Tooltip layout for HIT, MISS, and counter-with-DEFEND_STANCE (the
  most legible breakdown demonstrating −40% penalty + ×0.5 halve).
- Reduce Motion variant (compressed lifecycle).
- TalkBack / VoiceOver sample announcements.

This GDD locks the BEHAVIOR; UX owns the LAYOUT.

## Acceptance Criteria

### FORMULA — Worked Examples (D-1 through D-10)

Required coverage: 100% of all balance formulas (F-DC-1 through F-DC-7).
Every worked example is a mandatory test fixture in `tests/unit/damage_calc/damage_calc_test.gd`.

**AC-DC-01** [FORMULA] — D-1 baseline FRONT attack resolves to 30.
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_d1_baseline_front_hit`
- Method: automated unit
- Pass criteria: `resolve(atk=AttackerContext.make(unit_id:&"a", unit_class:CAVALRY, charge_active:false, defend_stance_active:false, passives:[]), def=DefenderContext.make(unit_id:&"b", terrain_def:0, terrain_evasion:0), mod=ResolveModifiers.make(attack_type:PHYSICAL, direction_rel:&"FRONT", is_counter:false, skill_id:"", rng:<seeded_no_miss>, round_number:1))` → `HIT(resolved_damage=30)`
- Blocker for: Vertical Slice

**AC-DC-02** [FORMULA] — D-2 BASE_CEILING invariant: ATK=190, DEF=10, FRONT resolves to 83, not 180 (rev 2.4 — BASE_CEILING lowered 100 → 83).
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_d2_base_ceiling_clamps_at_83`
- Method: automated unit
- Pass criteria: `resolve(eff_atk=190, eff_def=10, direction_rel=FRONT, no passives)` → `HIT(resolved_damage=83)`
- Blocker for: Vertical Slice

**AC-DC-03** [FORMULA] — D-3 Cavalry REAR Charge (primary) resolves to 64.
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_d3_cavalry_rear_charge_primary`
- Method: automated unit
- Pass criteria: `resolve(CAVALRY, ATK=80, DEF=50, REAR, charge_active=true, passive_charge, is_counter=false)` → `HIT(resolved_damage=64)`
- Blocker for: Vertical Slice

**AC-DC-04** [FORMULA] — D-4 hardest primary-path hit (rev 2.4): Cavalry REAR Charge ATK=200, DEF=10 resolves to 179 — DAMAGE_CEILING=180 does NOT fire since BASE_CEILING=83 caps the intermediate to `floori(83 × 1.80 × 1.20) = 179`. Pillar-1 peak differentiation = 30 pts (REAR-only 149 vs REAR+Charge 179).
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_d4_hardest_primary_path_hit`
- Method: automated unit
- Pass criteria: base=83, D_mult=1.80, P_mult=1.20 → floori(83×1.80×1.20)=179, ≤ DAMAGE_CEILING (no clamp) → `HIT(resolved_damage=179)`. Supplementary assertion: for same inputs with `charge_active=false`, resolved_damage=149 — proving the 30-pt differentiation.
- Blocker for: Vertical Slice

**AC-DC-05** [FORMULA] — D-5 MIN_DAMAGE floor: ATK=30, DEF=100, T_def=+30 resolves to 1.
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_d5_min_damage_floor`
- Method: automated unit
- Pass criteria: `resolve(eff_atk=30, eff_def=100, T_def=30, FRONT)` → `HIT(resolved_damage=1)`; confirms hp-status.md:98 contract.
- Blocker for: Vertical Slice

**AC-DC-06** [FORMULA] — D-6 negative T_def (attacker elevation): ATK=60, DEF=50, T_def=−30 resolves to 1 (amplifies eff_def, not eff_atk).
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_d6_negative_terrain_def_amplifies_defense`
- Method: automated unit
- Pass criteria: defense_mul = snappedf(1.0−(−30)/100, 0.01) = 1.30; base = max(1, floori(60−50×1.30)) = max(1,−5) = 1 → `HIT(resolved_damage=1)`
- Blocker for: Vertical Slice

**AC-DC-07** [FORMULA] — D-7 positive T_def defender terrain penalty: ATK=80, DEF=50, T_def=+20 resolves to 40.
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_d7_terrain_penalty_on_defender`
- Method: automated unit
- Pass criteria: defense_mul = 0.80; base = floori(80−50×0.80) = 40 → `HIT(resolved_damage=40)`
- Blocker for: Vertical Slice

**AC-DC-08** [FORMULA] — D-8 DEFEND_STANCE counter penalty (rev 2 retuned to 12–18 tactical-weight range): ATK=120, defend_stance_active=true, is_counter=true, DEF=40, FRONT, T_def=0 resolves to 16.
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_d8_defend_stance_counter_penalty`
- Method: automated unit
- Pass criteria: eff_atk→floori(120×0.60)=72; base=min(83, max(1, 72−40×1.00))=32; D_mult=1.00; P_mult=1.00 (Charge/Ambush disabled on counter per CR-8); raw=min(180, floori(32×1.00×1.00))=32; counter_final=max(1, floori(32×0.50))=16 → `HIT(resolved_damage=16)`
- Blocker for: Vertical Slice

**AC-DC-09** [FORMULA] — D-9 Scout Ambush on FLANK: Scout ATK=70, DEF=40, FLANK, round=3, defender not acted resolves to 41.
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_d9_scout_ambush_flank`
- Method: automated unit
- Pass criteria: base=30; D_mult=snappedf(1.20×1.00,0.01)=1.20; P_mult=1.15; floori(30×1.20×1.15)=41 → `HIT(resolved_damage=41)`
- Blocker for: Vertical Slice

**AC-DC-10** [FORMULA] — D-10 evasion MISS: terrain_evasion=30, seeded rng returning 25; is_counter=false → MISS, HP/Status never called.
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_d10_evasion_miss`
- Method: automated unit
- Pass criteria: `roll=25 <= T_eva=30` → `ResolveResult.MISS()`; mock hp_status.apply_damage call count = 0
- Blocker for: Vertical Slice

---

### EDGE_CASE — BLOCKER Edge Cases (must have unit-test fixture; 15 total)

**AC-DC-11** [EDGE_CASE] — EC-DC-1: get_modified_stat returns 0 or negative ATK (extreme debuff) → clamped to eff_atk=1 before CR-5.
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_ec1_atk_zero_clamped_to_1`
- Method: automated unit
- Pass criteria: mock returning raw_atk=0 → eff_atk=1; mock returning raw_atk=−5 → eff_atk=1; pipeline does not produce negative base.
- Blocker for: Vertical Slice

**AC-DC-12** [EDGE_CASE] — EC-DC-2: DEFEND_STANCE on eff_atk=1: floori(1×0.60)=0, but CR-6 max(MIN_DAMAGE,…) recovers to base=1; counter_final=1.
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_ec2_defend_stance_atk1_floor_recovery`
- Method: automated unit
- Pass criteria: is_counter=true, defend_stance_active=true, raw_atk=1, eff_def=50 → `HIT(resolved_damage=1)`
- Blocker for: Vertical Slice

**AC-DC-13** [EDGE_CASE] — EC-DC-3: terrain_def boundary equality at ±30 and out-of-range ±31 all produce correct defense_mul.
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_ec3_terrain_def_boundary_clamp`
- Method: automated unit
- Pass criteria: T_def=−31 → defense_mul=1.30; T_def=−30 → 1.30; T_def=0 → 1.00; T_def=+30 → 0.70; T_def=+31 → 0.70 (all via snappedf(1.0−clamped/100, 0.01))
- Blocker for: Vertical Slice

**AC-DC-14** [EDGE_CASE] — EC-DC-4: terrain_evasion=30 and roll=30 → MISS (inclusive ≤ boundary).
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_ec4_evasion_boundary_inclusive`
- Method: automated unit
- Pass criteria: seeded RNG producing roll=30 → MISS; seeded RNG producing roll=31 → HIT; confirms `<=` not `<`.
- Blocker for: Vertical Slice

**AC-DC-15** [EDGE_CASE] — EC-DC-7: get_modified_stat returns 201 (upstream cap bug) → clamped to eff_atk=200.
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_ec7_atk_over_cap_clamped`
- Method: automated unit
- Pass criteria: mock returning {199→199, 200→200, 201→200}; Damage Calc clamp is the last defense.
- Blocker for: Vertical Slice

**AC-DC-16** [EDGE_CASE] — EC-DC-8: is_counter=true AND passive_charge AND charge_active → Charge bonus suppressed; P_mult stays 1.00.
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_ec8_charge_suppressed_on_counter`
- Method: automated unit
- Pass criteria: same inputs, is_counter ∈ {true, false} → P_mult ∈ {1.00, 1.20} respectively; resolved_damage differs by exactly that factor.
- Blocker for: Vertical Slice

**AC-DC-17** [EDGE_CASE] — EC-DC-10: counter + DEFEND_STANCE + min-ATK degenerate stack → final output = 1 (MIN_DAMAGE holds end-to-end).
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_ec10_degenerate_counter_defend_stance_min_atk`
- Method: automated unit
- Pass criteria: is_counter=true, defend_stance_active=true, raw_atk=1, eff_def=50, T_def=0 → `HIT(resolved_damage=1)`
- Blocker for: Vertical Slice

**AC-DC-18** [EDGE_CASE] — EC-DC-11: skill_id != "" → returns MISS immediately (before evasion roll), source_flags contains `&"skill_unresolved"`, RNG call count = 0.
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_ec11_skill_stub_early_return`
- Method: automated unit
- Pass criteria: `modifiers.skill_id = "fireball"` → `result is ResolveResult` with `result.kind == MISS`; `assert_eq(result.source_flags.has(&"skill_unresolved"), true)`; RNG.randi_range call count = 0; vfx_tags is empty. No dependency on engine error-count APIs.
- Blocker for: Vertical Slice

**AC-DC-19** [EDGE_CASE] — EC-DC-13: rng == null → push_error fires, returns MISS with `&"invariant_violation:rng_null"` flag (no HP/Status call, no damage).
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_ec13_null_rng_guard`
- Method: automated unit
- Pass criteria (rev 2.4 — flagged-MISS redesign, replaces rev 2.3's fabricated `Engine.get_error_count()` + unverified `assert_error(...).is_push_error_message(...)` pattern): `modifiers.rng = null` → `resolve()` returns `MISS` with `result.source_flags.has(&"invariant_violation:rng_null") == true`. Assert via plain `assert_eq` on the flag — no engine error-count API consulted, no uninstalled-addon matcher. `push_error()` is still called so the editor log surfaces the defect; a developer verifies the log visually, but the automated test passes/fails on the flag alone. hp_status mock NOT called. This replaces rev 2.2's fabricated `tests/helpers/error_log_capture.gd` AND rev 2.3's fabricated `Engine.get_error_count()` — both sides of the recursive fabrication trap are eliminated by moving the testable surface into `result.source_flags` (which is already in the ResolveResult contract).
- Blocker for: Vertical Slice

**AC-DC-20** [EDGE_CASE] — EC-DC-14: RNG call count stable per path: non-counter → 1 randi call; counter → 0; skill_stub → 0.
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_ec14_rng_call_counts_per_path`
- Method: automated unit
- Pass criteria: snapshot RNG state before each call; call resolve(); restore and call again; outputs bit-identical. Assert call counts {non_counter=1, counter=0, skill_stub=0}.
- Blocker for: Vertical Slice

**AC-DC-21** [EDGE_CASE] — EC-DC-15: attacker.unit_class not in CLASS_DIRECTION_MULT (future GUARDIAN enum value) → push_error, returns MISS with `&"invariant_violation:unknown_class"` in source_flags (rev 2.4 flagged-MISS redesign).
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_ec15_unknown_class_guard`
- Method: automated unit
- Pass criteria (rev 2.4 — flagged-MISS redesign; rev 2.6 — BLK-7-5 bypass-seam mechanism citation): construct an AttackerContext via a **test-only RefCounted subclass** `class_name TestAttackerContextBypass extends AttackerContext` that redeclares `unit_class` as `var unit_class: int = 0` (untyped int shadowing the parent's `UnitRole.Class` enum field) — this is the engine-version-stable bypass mechanism for Godot 4.6, not `Object.set()` on a typed property which is version-sensitive and has observably inconsistent behavior across 4.5/4.6. Set `unit_class = 99` (outside any enum member) via the subclass, pass the subclass instance to `resolve()` (which accepts `AttackerContext` base class — subclass binds correctly per Godot 4.6 polymorphism contract). Expected: `resolve()` returns MISS with `result.source_flags.has(&"invariant_violation:unknown_class") == true`; NOT silently treated as Infantry. `push_error()` fires in the log (visual verification by developer; no test-level assertion on error-count). Error-log throttle behavior (same bad key triggers at most one push_error per session) is a **nice-to-have** — no longer a blocker assertion since the flag-based test is deterministic and does not depend on log-count side effects. Note: the bypass subclass lives in `tests/helpers/test_attacker_context_bypass.gd` and is used only from test code — production code must never instantiate it (grep-based CI lint: `TestAttackerContextBypass` must appear in 0 files under `src/`, 1+ files under `tests/`).
- Blocker for: Vertical Slice

**AC-DC-22** [EDGE_CASE] — EC-DC-16: direction_rel null or unrecognized (`&"DIAGONAL"`) → push_error, returns MISS with `&"invariant_violation:unknown_direction"` flag.
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_ec16_unknown_direction_guard`
- Method: automated unit
- Pass criteria (rev 2.4 — flagged-MISS redesign): `modifiers.direction_rel` ∈ {null, `&"DIAGONAL"`} → both cases return MISS with `result.source_flags.has(&"invariant_violation:unknown_direction") == true`. `push_error()` fires for each case (visual log check only). Same rationale as AC-DC-21: flag-based assertion replaces rev 2.3's `assert_error(...)` + `Engine.get_error_count()` pattern, which depended on a fabricated engine API and an uninstalled addon matcher.
- Blocker for: Vertical Slice

**AC-DC-23** [EDGE_CASE] — EC-DC-20: every int conversion in F-DC-3 through F-DC-7 uses floori(), not int().
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_ec20_floori_not_int_on_negative_intermediate`
- Method: automated unit
- Pass criteria: construct a case where the intermediate float is −0.7; assert result matches floori(−0.7)=−1 path, not int(−0.7)=0 path. Static code review (grep for `int(` in `damage_calc.gd`) must return 0 matches.
- Blocker for: Vertical Slice

**AC-DC-24** [EDGE_CASE] — EC-DC-23: counter halve of minimum raw: raw=1 → floori(1×0.5)=0 → max(1,0)=1 (MIN_DAMAGE floor in F-DC-7 catches this).
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_ec23_counter_halve_min_raw`
- Method: automated unit
- Pass criteria: synthetic raw=1 entering counter_reduction() → returns 1, not 0.
- Blocker for: Vertical Slice

**AC-DC-25** [EDGE_CASE] — EC-DC-24: snappedf(1.20 × 1.15, 0.01) == 1.38 on all three target platforms (not 1.37 from IEEE-754 truncation of 1.3799…).
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_ec24_snappedf_ieee754_residue` (rev 2.5 — BLK-6-9 platform reconciliation: runs in CI on **macOS Metal per-push** — same canonical baseline as AC-DC-37/38/50; Linux Vulkan + Windows D3D12 run on a **weekly schedule AND on every `rc/*` release-candidate tag** to control CI cost without leaving release candidates un-verified — see §Formulas determinism contract rev 2. Prior rev 2.4 text said "Linux Vulkan per-push," contradicting the macOS-Metal baseline declared in AC-DC-37.)
- Method: automated unit
- Pass criteria: `assert(snappedf(1.20 * 1.15, 0.01) == 1.38)` passes on the macOS Metal baseline runner per-push; weekly + rc-tag matrix surfaces any Linux/Windows divergence as a `WARN`-level annotation. Treated as a regression to investigate, NOT a hard build break (per the softened determinism contract). An `rc/*` tag MUST NOT be released without the full matrix having run green on that commit.
- Blocker for: Vertical Slice (advisory at Beta if integer-only-math ADR is opened)

---

### EDGE_CASE — IMPORTANT Edge Cases (SHOULD have unit-test fixture; 7 total)

**AC-DC-26** [EDGE_CASE] — EC-DC-5: terrain_evasion=0 → always HIT; RNG still consumed exactly once (replay determinism).
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_ec5_zero_evasion_always_hits`
- Method: automated unit
- Pass criteria: 100 calls with terrain_evasion=0 → 0 MISS results; assert RNG advanced exactly 1 call per invocation.
- Blocker for: MVP

**AC-DC-27** [EDGE_CASE] — EC-DC-9: dual-passive stacking is impossible by design (rev 2): Charge requires CAVALRY, Ambush requires SCOUT/ARCHER. The class-guard mutex means `P_mult ∈ {1.00, 1.15, 1.20}` only — never 1.38. The original 1.38 stacking case is moved to a contract-violation guard.
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_ec9_dual_passive_class_mutex`
- Method: automated unit
- Pass criteria: For each class ∈ {CAVALRY, SCOUT, INFANTRY, ARCHER}, attempt to fire both `passive_charge` AND `passive_ambush` simultaneously; assert `P_mult` is exactly one of {1.00, 1.15, 1.20} per the class-guard mutex (never 1.38). Cavalry+both-tags → P_mult=1.20 (Charge fires, Ambush blocked by class). Scout+both-tags → P_mult=1.15. Infantry+both-tags → P_mult=1.00.
- Blocker for: MVP

**AC-DC-28** [EDGE_CASE] — EC-DC-12: attack_type enum is {PHYSICAL, MAGICAL} only; passing a future-enum or Variant-coerced value is a caller-contract violation — guard returns flagged MISS.
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_ec12_dot_attack_type_rejected`
- Method: automated unit
- Pass criteria (rev 2.4 — flagged-MISS redesign; rev 2.6 — BLK-7-5 bypass-seam mechanism citation): construct `ResolveModifiers` via a **test-only RefCounted subclass** `class_name TestResolveModifiersBypass extends ResolveModifiers` that redeclares `attack_type` as `var attack_type: int = 0` (untyped int shadowing the parent's `AttackType` enum field — same pattern as AC-DC-21 `TestAttackerContextBypass`); set `attack_type = 99` via the subclass and pass to `resolve()`. Expected: result is MISS with `result.source_flags.has(&"invariant_violation:bad_attack_type") == true`; `push_error("damage_calc.resolve: unknown attack_type")` fires (visual log check only). Ensures no DoT accidentally routes through resolve(). Subclass lives in `tests/helpers/test_resolve_modifiers_bypass.gd`; same production-exclusion grep lint as AC-DC-21 applies.
- Blocker for: MVP

**AC-DC-29** [EDGE_CASE] — EC-DC-17: defender at 0 HP — Damage Calc does NOT check HP, returns valid HIT; pre-condition gate is Grid Battle's. Ownership documented.
- Test: integration test in `tests/integration/grid_battle_damage_calc_test.gd::test_dead_defender_gated_by_grid_battle`
- Method: integration
- Pass criteria: Damage Calc resolve() with HP=0 defender → valid HIT returned (not MISS); Grid Battle integration test verifies the dead-defender gate fires before resolve() is called.
- Blocker for: MVP

**AC-DC-30** [EDGE_CASE] — EC-DC-21: snappedf precision is 0.01 (locked constant); changing to 0.001 shifts D-9 output.
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_ec21_snappedf_precision_lock`
- Method: automated unit
- Pass criteria: D-9 re-run with snappedf precision=0.001 produces a different result than 0.01 (documenting the divergence as proof the lock is non-trivial); production code must use 0.01 only.
- Blocker for: MVP

**AC-DC-31** [EDGE_CASE] — EC-DC-22: Ambush gate vs dead defender — ownership documented in Grid Battle; Damage Calc has no guard here.
- Test: `tests/integration/grid_battle_damage_calc_test.gd::test_ec22_ambush_dead_defender_gated_upstream`
- Method: integration
- Pass criteria: Grid Battle blocks the ambush call before resolve() when defender is dead; Damage Calc itself has no dead-unit check.
- Blocker for: Beta

**AC-DC-32** [EDGE_CASE] — EC-DC-6: snappedf round-half-away-from-zero on tie cases — current integer T_def inputs produce no 0.005 ties; future-risk documented; non-integer terrain inputs are a breaking-change flag.
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_ec6_snappedf_no_tie_on_integer_inputs`
- Method: automated unit
- Pass criteria: all T_def ∈ {−30..+30} integer inputs produce exact rational defense_mul values with no 0.005 midpoint (verify via loop over full range); no MISS on any valid integer.
- Blocker for: Beta

---

### CONTRACT — Section F Dependency Contracts

**AC-DC-33** [CONTRACT] — resolve() is the sole public entry point for Damage Calc; no other public method exists that applies damage or mutates combat state.
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_contract_sole_entry_point` + static API audit (grep for `func ` in `damage_calc.gd`)
- Method: automated unit
- Pass criteria: `damage_calc.gd` exports exactly one public function: `resolve(attacker, defender, modifiers) -> ResolveResult`. All other functions are private (`_` prefix or inner). Grep returns exactly 1 public `func`.
- Blocker for: Vertical Slice

**AC-DC-34** [CONTRACT] — ZERO signals emitted by damage_calc.gd (ADR-0001 §Damage Calc line 375).
- Test: static analysis — grep `signal` and `emit_signal` in `src/**/damage_calc.gd`
- Method: automated unit (CI lint step)
- Pass criteria: grep returns 0 matches for `signal ` and `emit_signal` in `damage_calc.gd`. CI fails if any match is found.
- Blocker for: Vertical Slice

**AC-DC-35** [CONTRACT] — HP/Status.apply_damage is NEVER called from damage_calc.gd; HP/Status interaction is Grid Battle's responsibility only.
- Test: static analysis — grep `apply_damage` in `src/**/damage_calc.gd`
- Method: automated unit (CI lint step)
- Pass criteria: grep returns 0 matches. Any call to `apply_damage` or `hp_status` write-path inside `damage_calc.gd` is a blocking CI failure.
- Blocker for: Vertical Slice

**AC-DC-36** [CONTRACT] — vfx_tags array in ResolveResult.HIT is populated correctly from source_flags: "charge" tag present iff charge fired; "ambush" iff ambush fired; "counter" iff is_counter=true; "terrain_penalty" iff T_def > 0.
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_contract_vfx_tags_populated_per_source_flags`
- Method: automated unit
- Pass criteria: for each of the four provenance flags, assert tag present in `ResolveResult.HIT.vfx_tags` when its condition fires, and absent when it does not. Test all 8 combinations of {charge, ambush, counter}.
- Blocker for: MVP

---

### DETERMINISM — Cross-Platform and RNG Stability

**AC-DC-37** [DETERMINISM] — Same inputs → same resolved_damage on the **canonical baseline platform (macOS Metal)** per-push; Windows D3D12 + Linux Vulkan run weekly AND on every `rc/*` tag. Softened determinism contract per §Formulas rev 2 — cross-platform divergence is a `WARN`, not a hard ship block.
- Test: `tests/unit/damage_calc/damage_calc_test.gd` full suite in CI matrix (`.github/workflows/` platform matrix). Per-push: macOS runner only. Weekly + rc-tag: all three runners.
- Method: automated unit
- Pass criteria: (a) D-1 through D-10 outputs match the known-good baseline snapshot on macOS Metal per-push — failure here IS a ship blocker. (b) Weekly + rc-tag matrix cross-checks Windows and Linux against the baseline; any divergence emits a `WARN` annotation and opens an investigation ticket, but does NOT fail the build (unless the integer-only-math ADR is later opened, at which point this escalates to hard fail). (c) `rc/*` tags MUST have the full matrix green before release — the `WARN` becomes blocking only at release-candidate gate.
- Blocker for: Beta (baseline-platform only) / Release (full matrix)

**AC-DC-38** [DETERMINISM] — snappedf(x, 0.01) round-half-away-from-zero: snappedf(0.005, 0.01) == 0.01 AND snappedf(-0.005, 0.01) == -0.01. Godot 4.6 engine contract pinned (see AC-DC-50 source pin).
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_determinism_snappedf_round_half_away_from_zero`
- Method: automated unit
- Pass criteria: `assert(snappedf(0.005, 0.01) == 0.01)` AND `assert(snappedf(-0.005, 0.01) == -0.01)` both pass on the macOS Metal baseline runner (per-push). If this fails, EC-DC-6 forward-risk materializes and the snappedf precision lock must be re-evaluated.
- Blocker for: Vertical Slice

**AC-DC-39** [DETERMINISM] — RNG call count stable per execution path: replay by restoring RNG seed produces bit-identical results for HIT and MISS paths.
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_determinism_rng_replay`
- Method: automated unit
- Pass criteria: snapshot RNG → call resolve() → restore snapshot → call resolve() again; assert outputs identical for all four paths (HIT, MISS, counter, skill_stub).
- Blocker for: Vertical Slice

---

### PERFORMANCE — Stateless Function Benchmarks

**AC-DC-40** [PERFORMANCE] — Two-tier validation (revision 2 — split into CI-safe + manual gate):
- **(a) CI throughput check** — `tests/unit/damage_calc/damage_calc_test.gd::test_perf_resolve_throughput_ci`. Run 10,000 resolve() calls in headless CI on Linux runner; assert wall-clock total <500ms (50µs avg). This is a **regression gate**, not a mobile-perf claim. Blocker for: Vertical Slice.
- **(b) Manual mobile gate** — `production/qa/evidence/damage_calc_perf_mobile.md`. On a minimum-spec device matching the **mobile reference class** (ARMv8, ≥4GB RAM, Adreno 610 / Mali-G57 or better GPU class, Android 12+ or iOS 15+; 2020-era mid-tier Android such as Pixel 4a is one representative device, but pass/fail is bound to the device class, not that specific handset), run the 10,000-call benchmark via in-game debug command; assert p99 latency <1ms via `Time.get_ticks_usec()` deltas; capture screenshot of debug overlay with device model + OS version recorded in the evidence file header. Blocker for: Beta.
- Headless CI cannot validate ARMv8 perf — these are intentionally separate ACs (the previous combined formulation was untestable).

**AC-DC-41** [PERFORMANCE] — No Dictionary allocation inside `resolve()` (revision 2 — rewritten as static-analysis pass). The previous formulation relied on `Performance.OBJECT_COUNT` delta, which (a) cannot isolate Dictionary objects specifically in Godot 4.6, and (b) double-counts Array allocations from `build_vfx_tags`.
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_perf_no_dict_construction_in_resolve` (CI lint step)
- Method: automated unit (static analysis)
- Pass criteria: grep `src/**/damage_calc.gd` for `Dictionary(` and standalone `{` (literal Dictionary construction) inside the body of every function reachable from `resolve()` EXCLUDING `build_vfx_tags`. Expected match count = 0. Targets: `stage_1_base_damage`, `direction_multiplier`, `passive_multiplier`, `stage_2_raw_damage`, `counter_reduction`, `evasion_check`, `ambush_round_gate_open`, all helpers. `build_vfx_tags` is exempt — it must construct an `Array[StringName]` per HIT (CR-11). The `source_flags` Array returned in `ResolveResult.HIT` is also a permitted fresh allocation per HIT (CR-11 mutation-semantics contract).
- Blocker for: Vertical Slice (advisory at Beta if Godot adds Dictionary-specific perf monitor support, allowing return to runtime measurement)

---

### INTEGRATION — Cross-System Contracts

**AC-DC-42** [INTEGRATION] — Grid Battle calls resolve() exactly **2 times** per (primary HIT that triggers a counter) and exactly **1 time** per (primary HIT or MISS that does NOT trigger a counter).
- Test: `tests/integration/grid_battle_damage_calc_test.gd::test_integration_resolve_call_count`
- Method: integration
- Pass criteria: mock Damage Calc with call counter; run three scenarios: (1) primary HIT with counter-eligible defender → assert call count = 2; (2) primary HIT with non-counter-eligible defender → assert call count = 1; (3) primary MISS → assert call count = 1 (no counter on MISS per CR-2). All three counts must be exact, not "at least" or "at most".
- Blocker for: MVP

**AC-DC-43** [INTEGRATION] — HP/Status.apply_damage receives valid resolved_damage ≥ 1 on every HIT; apply_damage is never called on MISS. AoE coverage: when Grid Battle dispatches an AoE call to N targets, exactly N apply_damage calls are made — one per target with HIT result, none for targets with MISS result.
- Test: `tests/integration/grid_battle_damage_calc_test.gd::test_integration_apply_damage_valid_on_hit`
- Method: integration
- Pass criteria: mock hp_status.apply_damage; trigger 4 scenarios: (a) single HIT → 1 apply_damage call with `resolved_damage ≥ 1`; (b) single MISS → 0 apply_damage calls; (c) 6-target AoE all HIT → exactly 6 apply_damage calls each with `resolved_damage ≥ 1`; (d) 6-target AoE with 2 MISS results → exactly 4 apply_damage calls. Assert call count exact for all four; assert each call's `resolved_damage` argument ≥ 1.
- Blocker for: MVP

**AC-DC-44** [INTEGRATION] — F-GB-PROV provisional formula is REMOVED from grid-battle.md §CR-5 Step 7 in the same patch that registers damage_resolve in entities.yaml.
- Test: static analysis — grep for "F-GB-PROV" in `design/gdd/grid-battle.md` and `src/`
- Method: automated unit (CI lint step)
- Pass criteria: post-patch, `grep -r "F-GB-PROV" design/gdd/grid-battle.md src/` returns 0 matches. Presence of F-GB-PROV after the patch is a blocking CI failure.
- Blocker for: MVP

---

### ACCESSIBILITY — UI-4 Commitments

**AC-DC-45** [ACCESSIBILITY] — TalkBack/VoiceOver announcement format (rev 2.3 — BLK-5 production parity; rev 2.4 — BLK-6 reproducibility fix; rev 2.5 — BLK-6-10 player-safe copy): HIT emits `"<defender_name> hit for <raw>, <provenance>"` (e.g., "Lu Bu hit for 64, REAR Charge"); MISS emits `"<defender_name> evaded"` (for terrain evasion; invariant-violation MISSes produce no announcement per silent-guard policy); skill_unresolved emits the **player-safe** string `"Skill unavailable"` in **all builds** (the prior `OS.is_debug_build()` gate is removed per WCAG 2.1 SC 4.1.3; the rev 2.3/2.4 text `"<attacker_name> skill not yet implemented"` leaked internal stub copy and is replaced per rev 2.5 BLK-6-10).
- Test: `production/qa/evidence/damage_calc_talkback_walkthrough.md` (manual walkthrough with TalkBack/VoiceOver enabled on Android/iOS) executed against a **release-config build** (not debug) to confirm skill_unresolved announcement survives the removed debug gate. **Build-mode sentinel (rev 2.4 — BLK-6)**: release-config reproducibility requires a tester-visible signal that proves `OS.is_debug_build() == false`. Phase-5 DevOps story (see Cross-System Patches Queued #12) wires an autoload bootstrap that emits a one-time boot log line `"[BUILD_MODE] release"` or `"[BUILD_MODE] debug"` at app start in all builds AND renders the same string in a top-right accessibility-debug overlay chip that is present only when the in-game Accessibility → "Show build mode" toggle is enabled (defaults ON for QA builds). Tester captures the log line or the chip screenshot as evidence alongside the TalkBack walkthrough — proves release-config and release-config-only behavior is tested.
- Method: manual walkthrough
- Pass criteria: for each of the three paths (HIT with provenance, MISS, skill_unresolved), tester confirms announcement text matches the spec above exactly; no extra announcements; skill_unresolved path announces `"Skill unavailable"` (NOT `"not yet implemented"` — rev 2.5 BLK-6-10 stub-copy guard); announcement throttled to 1 per 500ms during rapid hits; walkthrough evidence file header must include the captured `"[BUILD_MODE] release"` log line or the build-mode-chip screenshot (rev 2.4 sentinel) — proves release-config. Additional static-analysis check: `grep -i "not yet implemented\|TODO\|placeholder\|stub" src/**/damage_calc.gd` returns 0 matches in user-facing string literals (rev 2.5 BLK-6-10 CI-lint guard).
- Blocker for: Beta

**AC-DC-46** [ACCESSIBILITY] — Reduce Motion: when the in-game Settings Reduce Motion toggle is enabled (rev 2.4 — OS-flag bridging deferred to AccessKit/Full Vision per UI-4), popup animation is bypassed — appears at 100% scale immediately; hold = `max(baseline_hold, 1200ms)` per UI-4 rev 2.3 (BLK-4 compliance with WCAG 2.1 SC 2.3.3 "Animation from Interactions"; rev 2.5 BLK-6-7 citation correction — prior SC 2.2.1 "Timing Adjustable" was the wrong criterion for sub-20-second popup lifecycle); drift ≤ 8px; total lifecycle = 1550ms (1200ms hold + 350ms fade).
- Test: `tests/integration/damage_calc_ui_test.gd::test_reduce_motion_lifecycle` (automated frame-trace — **run with display**, NOT headless; CI job configured with virtual display or `xvfb-run` on Linux so frame-trace recorder can observe Control nodes) + `production/qa/evidence/damage_calc_reduce_motion_walkthrough.md` (manual visual confirmation)
- Method: integration (automated, headed) + manual walkthrough (visual confirmation only)
- Pass criteria (rev 2.4 — headless runner coverage fix per BLK-9; rev 2.6 — BLK-7-3 wall-clock rewrite because frame-count assertions are non-deterministic under `xvfb-run` virtual-display environments where Godot does not vsync-lock): With Reduce Motion toggle enabled, trigger HIT_DEVASTATING via test harness in a **display-enabled CI job** (separate from the headless unit-test job — see Coverage Matrix footer for the split); integration test asserts via **wall-clock deltas** using `Time.get_ticks_msec()` snapshots at each lifecycle event (deterministic under virtual display): (a) popup `Control.scale.x == 1.0` at the first `process` tick after spawn (no spawn animation tween), (b) popup `Control.visible == true` at the first `process` tick, (c) total lifecycle `msec_free - msec_spawn` is ≥ 1517 ms AND ≤ 1583 ms (1550 ms ± 33 ms tolerance absorbs one-frame scheduling jitter at any FPS cap), (d) `popup_node.position.y` delta from spawn to free ≤ 8.0 in Godot units, (e) hold-phase wall-clock duration (from scale=1.0 event to fade-start event) is ≥ 1167 ms AND ≤ 1233 ms (1200 ms ± 33 ms) for every tier including HIT_NORMAL (confirms `max(baseline_hold, 1200ms)` elevation per UI-4). The test harness sets `Engine.max_fps = 60` and `Engine.physics_ticks_per_second = 60` at fixture setup to keep sched jitter bounded, but assertions are on Time deltas not frame counts so vsync behavior is irrelevant. Manual walkthrough captures screenshot at popup peak for visual record only — pass/fail is the integration test, not the stopwatch. Note: `tests/gdunit4_runner.gd` must discover `tests/integration/`; AC-DC-46 fails CI if the integration job is not wired (prerequisite Phase-5 DevOps work alongside the multi-platform matrix).
- Blocker for: Beta

**AC-DC-47** [ACCESSIBILITY] — Color-blind monochrome distinguishability: all four popup states (HIT_NORMAL, HIT_DIRECTIONAL, HIT_DEVASTATING, MISS) are distinguishable under monochrome filter by SIZE + BACKING OPACITY alone (revision 2 — preconditions made stagable).
- Test: `tests/integration/damage_calc_ui_test.gd::test_colorblind_monochrome_distinguishable` (automated, deterministic) + `production/qa/evidence/damage_calc_colorblind_screenshot.md` (lead sign-off on captured artifacts)
- Method: integration (automated stagable preconditions) + lead sign-off
- Pass criteria (rev 2.6 — BLK-7-6 opacity threshold reconciliation): Test harness instantiates each of the four popup nodes (HIT_NORMAL=28sp/55% backing, HIT_DIRECTIONAL=34sp/45% backing, HIT_DEVASTATING=42sp/80% backing, MISS=22sp/no-backing) using deterministic factory functions (no live combat needed — preconditions are now stagable, fixing the prior "structurally invalid" issue). Apply Godot's `Viewport.canvas_item_default_texture_filter` grayscale post-process; capture 4 screenshots; assert: (a) measured rendered text height of each popup differs by ≥ 4px from every other tier's height (size is the **primary** distinguishing channel: 22/28/34/42sp gives 6/6/8 px minimum deltas), (b) measured backing opacity differs by ≥ **10%** from every neighboring tier's opacity (lowered from ≥15% per rev 2.6 because V-1 intentionally uses a non-monotonic opacity sequence — DIRECTIONAL 45% is intentionally *lighter* than NORMAL 55% because the DIRECTIONAL 청회 blue number carries contrast at the glyph level while the DEVASTATING 지백 inverse uses heavy 80% backing for weight; forcing monotonic opacity would erase the design semantics). The 10% threshold means the NORMAL↔DIRECTIONAL 10% delta passes exactly, DIRECTIONAL↔DEVASTATING 35% delta has wide margin, DEVASTATING↔MISS 80% delta has maximum margin. Distinguishability is guaranteed by size+opacity composite, not opacity alone. QA lead reviews screenshots in evidence file and signs off on visual distinguishability; sign-off explicitly confirms the non-monotonic DIRECTIONAL opacity reads as intentional lightness, not as a visual bug.
- Blocker for: Beta

---

### TUNING — Damage Calc-Owned Knobs in entities.yaml

**AC-DC-48** [TUNING] — TK-DC-1 CHARGE_BONUS and TK-DC-2 AMBUSH_BONUS live in entities.yaml and are read via DataRegistry.get_const(); no hardcoded 1.20 or 1.15 values in damage_calc.gd.
- Test: static analysis — grep for `1.20` and `1.15` as literal floats in `src/**/damage_calc.gd`; plus `tests/unit/damage_calc/damage_calc_test.gd::test_tuning_knobs_read_from_registry`
- Method: automated unit
- Pass criteria: (a) grep returns 0 matches for `1.20` and `1.15` as literals in `damage_calc.gd`; (b) unit test mocks DataRegistry.get_const("CHARGE_BONUS") → 1.30, runs D-3 fixture, asserts resolved_damage changes accordingly (confirms live registry read, not cached literal).
- Blocker for: MVP

---

### VERIFY-AGAINST-ENGINE — Godot 4.6 Engine Contract Pins

**AC-DC-49** [VERIFY-AGAINST-ENGINE] — Godot 4.6 randi_range(from, to) is inclusive on BOTH ends: randi_range(1, 100) can return 100; randi_range(1, 100) can return 1. EC-DC-4 evasion boundary depends on this. Source pin: `docs/engine-reference/godot/` (RandomNumberGenerator / `@GlobalScope.randi_range` — stable since Godot 4.0, unchanged through 4.6).
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_engine_randi_range_inclusive_both_ends`
- Method: automated unit
- Pass criteria: seed RNG to produce known return of 1 → assert return == 1; seed to produce 100 → assert return == 100. If Godot changes this contract in a future version, EC-DC-4 fixture will break and surface the regression.
- Blocker for: Vertical Slice

**AC-DC-50** [VERIFY-AGAINST-ENGINE] — Godot 4.6 snappedf uses **round-half-away-from-zero** on tie (rev 2.2 correction — prior rev 2.1 text said "round-half-up", which is only correct for positive values and produced a wrong expected value for the negative-tie case below). snappedf(0.005, 0.01) == 0.01 AND snappedf(-0.005, 0.01) == -0.01. Pins the engine contract cited in EC-DC-6 and EC-DC-24. Source pin: `docs/engine-reference/godot/` (`@GlobalScope.snappedf` delegates to `round()` which is half-away-from-zero — stable since Godot 4.0).
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_engine_snappedf_round_half_away_from_zero` (same assertion as AC-DC-38; separate test function for engine-contract isolation)
- Method: automated unit
- Pass criteria: `snappedf(0.005, 0.01)` returns `0.01`; `snappedf(-0.005, 0.01)` returns `-0.01` (negative tie rounds AWAY from zero — this is Godot's `round()` semantics; see `docs/engine-reference/godot/`). Run on the macOS Metal baseline runner per AC-DC-37 per-push; full 3-platform matrix on `weekly` cron + `rc/*` tag push.
- Blocker for: Vertical Slice

---

### CONTRACT — Type Boundary (rev 2.2)

**AC-DC-51** [CONTRACT] — EC-DC-25: `attacker.passives` must be `Array[StringName]`; `Array[String]` is a silent-wrong-answer correctness hole. F-DC-5 contracts the input type via `attacker: AttackerContext` (RefCounted with typed `passives: Array[StringName]` field); GDScript 4.6 enforces the inner type at parameter binding, so the defect is caught at the Grid Battle call boundary. Release-build safety is additionally guaranteed by `StringName` literal (`&"passive_charge"`, `&"passive_ambush"`) comparisons inside F-DC-5 — so even if a test harness bypasses the type boundary with a hand-built wrong-typed array, the comparison returns `false` and `P_mult` stays `1.00`.
- Test: `tests/unit/damage_calc/damage_calc_test.gd::test_ec25_stringname_comparison_correctness` (bypass-seam semantic) + `test_ec25_positive_charge_fires` (positive path)
- Method: automated unit
- Pass criteria (rev 2.4 — simplified from rev 2.2's 3-part pattern; dropped (a) type-error-assertion pattern because GDScript 4.6 type errors raised at parameter binding / field assignment are NOT catchable by `Callable` wrappers at runtime — the type-boundary enforcement is verified manually by a developer who attempts the invalid assignment in the editor and observes the parse/bind error, not via automated assertion. Rev 2.6 — BLK-7-4 redesign: Variant-coercion bypass of `Array[StringName]` at field assignment is also not a reliable path in GDScript 4.6 — the inner-type check fires on assignment too, so the rev 2.4 "test-only factory that skips type-checking" was fictitious. The rev 2.6 redesign instead exercises the StringName-literal defense by calling `passive_multiplier()` **directly** with a locally-constructed, deliberately-untyped `Array` — bypassing `AttackerContext.passives` type enforcement by bypassing AttackerContext construction entirely): (b) **direct-call bypass-seam (rev 2.6)** — the test module declares a local helper `func _wrong_typed_passives() -> Array: return ["passive_charge"]` (return type is untyped `Array`, inner elements are plain `String`). Construct a Cavalry AttackerContext via `.make()` with an empty `passives` field, then call `passive_multiplier(attacker, defender, modifiers)` through a test-exposed `@onready var _passive_mul := Callable(DamageCalc, "_passive_multiplier_for_test")` that accepts an external passives Array parameter overriding the attacker's own. Inside the callable, the body still uses `if PASSIVE_CHARGE in passives_arg` where `PASSIVE_CHARGE: StringName = &"passive_charge"`. Assert `P_mult == 1.00` — because `&"passive_charge" in ["passive_charge"]` returns `false` under GDScript's `in` operator (StringName vs String mismatch), so the Charge branch does not fire even with the "tag present" from String perspective. Rationale: the StringName literal is the runtime correctness guard; this test exercises the guard without relying on any GDScript type-system defect. (c) **positive case** — `AttackerContext.make(passives=[&"passive_charge"], …)` on a Cavalry with charge_active=true returns `P_mult == 1.20` through the normal `resolve()` entry point. Together (b) and (c) prove the defense works at both the correct-type entry and the String-array test-harness bypass — the production defense is the StringName literal, not the type system.
- Blocker for: Vertical Slice

---

### Coverage Matrix

| Category | AC Count | Required Coverage (from coding-standards.md) | Notes |
|---|---|---|---|
| FORMULA | 10 (AC-DC-01–10) | **100%** — balance formulas | All 10 worked examples (D-1 through D-10) have fixtures. All 7 sub-formulas (F-DC-1 through F-DC-7) exercised across these 10. |
| EDGE_CASE (BLOCKER) | 15 (AC-DC-11–25) | **100%** — gameplay systems | All 15 BLOCKER edge cases (EC-DC-1,2,3,4,7,8,10,11,13,14,15,16,20,23,24) have unit-test ACs. |
| EDGE_CASE (IMPORTANT) | 7 (AC-DC-26–32) | **80%** — gameplay systems | All 7 IMPORTANT edge cases (EC-DC-5,9,12,17,21,22,6) have ACs. 5 automated, 2 integration. |
| CONTRACT | 4 (AC-DC-33–36) | **100%** — blocking system contracts | Sole entry point, zero signals, no HP/Status calls, vfx_tags population. |
| DETERMINISM | 3 (AC-DC-37–39) | **100%** — cross-platform requirement | Platform CI matrix (baseline per-push, matrix weekly + rc-tag), snappedf round-half-away-from-zero, RNG replay. |
| PERFORMANCE | 2 (AC-DC-40–41) | Advisory (no formal % target) | <1ms p99 on mobile; zero per-call Dictionary allocation. |
| INTEGRATION | 3 (AC-DC-42–44) | **100%** — integration stories are BLOCKING | resolve() call count, apply_damage valid on HIT, F-GB-PROV removal. |
| ACCESSIBILITY | 3 (AC-DC-45–47) | Advisory (ADVISORY gate per story type table) | TalkBack format, Reduce Motion lifecycle, monochrome distinguishability. |
| TUNING | 1 (AC-DC-48) | Advisory (Config/Data = smoke check) | Both TK-DC-1 and TK-DC-2 in single AC; registry read confirmed via mock substitution. |
| VERIFY-AGAINST-ENGINE | 2 (AC-DC-49–50) | **100%** — engine contracts are non-negotiable | randi_range inclusivity, snappedf round-half-away-from-zero. Both cite `docs/engine-reference/godot/`. |
| CONTRACT (rev 2.2 / 2.4) | 1 (AC-DC-51) | **100%** — silent-wrong-answer guard | EC-DC-25 StringName type boundary: rev 2.4 keeps (b) bypass-seam + (c) positive case; rev 2.2 (a) type-error-assertion pattern dropped (not catchable by GDScript Callable wrappers). |
| **TOTAL** | **51** | — | 25 items cover the mandatory 10+15 floor (worked examples + BLOCKER edge cases); 1 rev 2.2 item (AC-DC-51) covers the StringName silent-fail. Rev 2.4 removed AC-DC-52/53 (ceiling disclosure) since BASE_CEILING=83 makes the ceiling unreachable in MVP — see review-log rev 2.4 entry for history. AC-DC-40 is a two-tier AC (sub-blockers VS + Beta) but counted once in this total. |

**Release stage summary (rev 2.4 — post-body-vs-matrix reconciliation):**
- Vertical Slice sub-blockers: AC-DC-01–10, 11–25, 33–35, 38–39, 40(a) CI throughput, 41, 49–50, 51 (35 sub-blockers: 10 + 15 + 3 + 2 + 1 + 1 + 2 + 1)
- MVP blockers: AC-DC-26–30, 36, 42–44, 48 (10 items: 5 + 1 + 3 + 1)
- Beta blockers: AC-DC-31–32, 37, 40(b) mobile gate, 45–47 (7 items: 2 + 1 + 1 + 3)
- Ship: all **51 unique ACs** must be green (AC-DC-40 is a two-tier AC with (a) VS + (b) Beta; counted once in the unique total, twice in sub-blocker tallies); no open BLOCKER or IMPORTANT EDGE_CASE failures permitted.

**CI commands:**
```
# Headless job — unit + contract + determinism + perf + tuning + verify-engine + integration (non-UI)
godot --headless --script tests/gdunit4_runner.gd

# Headed job (rev 2.4 — BLK-9) — UI integration tests requiring Control-node observation
xvfb-run -a godot --script tests/gdunit4_runner.gd -- --only=tests/integration/damage_calc_ui_test.gd
```
All FORMULA, EDGE_CASE, CONTRACT, DETERMINISM, PERFORMANCE, INTEGRATION (non-UI), TUNING, and VERIFY-AGAINST-ENGINE ACs run headlessly on every push to main. **UI integration ACs** (AC-DC-46 Reduce Motion lifecycle, AC-DC-47 monochrome distinguishability) run **with display** via `xvfb-run` on the Linux CI runner — frame-trace assertions on Control nodes are not valid in headless Godot. ACCESSIBILITY ACs produce evidence files in `production/qa/evidence/` and require manual sign-off before Beta gate.

> ⚠️ **CI infrastructure prerequisite (rev 2.2 Phase-5 blocker, rev 2.4
> re-flagged) — BLOCKED BY: DevOps story (not a GDD defect):** AC-DC-25 /
> AC-DC-37 / AC-DC-50 reference a weekly + `rc/*` tag full-matrix
> (macOS-Metal, Windows-D3D12, Linux-Vulkan) for cross-platform
> determinism verification. AC-DC-46 / AC-DC-47 additionally require the
> headed `xvfb-run` job above. As of rev 2.4,
> `.github/workflows/tests.yml` exists but does NOT yet configure either
> (a) the multi-platform matrix or (b) the headed UI-integration job.
> **Actions required (producer → DevOps)**: (1) wire matrix + cron +
> `rc/*` tag trigger into the workflow; (2) add headed job with
> `xvfb-run` for UI integration tests; (3) ensure
> `tests/gdunit4_runner.gd` discovers `tests/integration/`. Tracked in
> Cross-System Patches Queued #10 + #11 (rev 2.4 expansion). Baseline
> macOS-Metal per-push runs are enforceable today; full-matrix
> weekly/rc-tag and headed UI-integration verification are gated on that
> DevOps story landing. **Without these, AC-DC-25/37/46/47/50 are
> un-enforceable at Beta gate — hard blocker.**

## Open Questions

This section consolidates every Open Question raised during damage-calc authoring. All BLOCKER OQs are resolved (status `RESOLVED`); deferred items carry an explicit default and a revisit trigger. The Damage Calc GDD ships with **zero open BLOCKER questions**.

### Resolved — From Pre-Authoring Brief (8)

| ID | Question (abbrev.) | Resolution | Resolved In | Status |
|---|---|---|---|---|
| **OQ-DC-1** | Does Damage Calc own the evasion roll, or receive a pre-rolled MISS flag? | **Damage Calc owns the evasion roll.** Single owner; deterministic call-site; `terrain-effect.md` exposes `terrain_evasion` as data only. Cross-ref correction queued for `terrain-effect.md` and `grid-battle.md` in Phase 5 back-references. | §C CR-3, §D F-DC-2 | RESOLVED |
| **OQ-DC-2** | Retain F-GB-PROV `ATK − DEF×m` subtraction, or migrate to ratio (`ATK² / (ATK + DEF)`)? | **Provisional ratification of subtractive form for MVP.** F-DC-3 uses `max(MIN_DAMAGE, floori(eff_atk − eff_def × defense_mul))`; ratio migration is a post-MVP TR with no current commitment. F-GB-PROV is REMOVED from `grid-battle.md` §CR-5 Step 7 in the same patch (AC-DC-44). | §D F-DC-3, §F F-GB-PROV retirement | RESOLVED (provisional — see Deferred OQ-DC-2-FOLLOWUP below) |
| **OQ-DC-3** | Counter-attack as first-class output (`{primary, counter}`) or as a second `resolve()` call? | **Second `resolve()` call from Grid Battle**, with `is_counter=true` flag. Damage Calc remains stateless and single-output; Grid Battle owns the call-graph. AC-DC-42 enforces exactly two calls per primary+counter exchange. | §C CR-9, §D F-DC-7 | RESOLVED |
| **OQ-DC-4** | Define skill damage in Damage Calc, or defer to a future Skill System GDD? | **Defer to future Skill System GDD.** MVP skill_id stub path returns `MISS()` + `source_flags ∋ "skill_unresolved"`; see OQ-DC-9. | §C CR-12 (amended), §E EC-DC-11, §J AC-DC-18 | RESOLVED |
| **OQ-DC-5** | Critical hits — in MVP or deferred? | **Deferred — out of MVP scope.** No crit modifier in F-DC-4 through F-DC-6; no `crit_chance` knob in §G. Re-evaluate at Beta gate per pillar 2 ("운명을 바꿀 수 있다") — crits are tonally compatible but add an RNG surface that competes with directional/passive provenance for player attention. | §D F-DC-4..6 absent crit, §G TK exclusions | RESOLVED |
| **OQ-DC-6** | Elevation attack bonus — percentage, tile-count, or elevation-delta? | **Opaque-int passthrough.** Damage Calc treats `terrain_def` ∈ [−30, +30] as a single signed integer that already encodes elevation impact. The percentage/tile-count debate is resolved inside `terrain-effect.md`; Damage Calc does not see the underlying elevation delta. Inconsistency between terrain-effect.md UI text "+8%" and AC-3 "+15%" is a `terrain-effect.md` bug, flagged for back-reference patch in Phase 5. | §C CR-4, §F upstream Terrain Effect contract | RESOLVED |
| **OQ-DC-7** | Stacking order: `(base × dir × passive) − def_term × T_def` vs. `(base − def_term) × dir × passive × T_def_mul`. | **Option C two-stage cap ratified.** F-DC-3 `base = clamp(eff_atk − eff_def × defense_mul, 1, BASE_CEILING=83)` (rev 2.4: 100→83 per CRITICAL-3 resolution); F-DC-6 `raw = floori(base × D_mult × P_mult)` then `clamp(_, 1, DAMAGE_CEILING=180)` (rev 2: 150→180; rev 2.4: repositioned as silent defense-in-depth wall). unit-role.md EC-7 multiplicative ordering for direction/Charge preserved. | §D F-DC-3 + F-DC-6 | RESOLVED |
| **OQ-DC-8** | True damage / DoT — `resolve_true_damage(amount) -> int` branch, or HP/Status DoT path bypasses Damage Calc entirely? | **HP/Status DoT bypasses Damage Calc entirely.** Damage Calc accepts `attack_type ∈ {PHYSICAL, MAGICAL}` only; passing `"POISON"` or `"DOT"` triggers `push_error` + `MISS()` (EC-DC-12 / AC-DC-28). Hp-status.md:356 contract honored. | §C CR-1, §E EC-DC-12, §J AC-DC-28 | RESOLVED |

### Resolved — Surfaced During Edge-Case Analysis (2)

| ID | Question | Resolution | Resolved In | Status |
|---|---|---|---|---|
| **OQ-DC-9** | When `modifiers.skill_id != ""` and Skill System is unimplemented, what does `resolve()` return? Three candidates: (a) `HIT(0, ...)`, (b) `MISS()` + flag, (c) `push_error` + abort. | **(b) `MISS()` + `source_flags ∋ "skill_unresolved"`, RNG not consumed, vfx_tags=[].** Avoids accidental zero-damage HIT routing through HP/Status, keeps RNG replay deterministic, and surfaces the skill stub explicitly to telemetry. CR-12 amended in §C. | §C CR-12 amended, §E EC-DC-11, §J AC-DC-18 | RESOLVED |
| **OQ-DC-10** | What does `resolve()` return when input invariants are violated (`rng == null`, unknown `attacker.unit_class`, unknown `direction_rel`, illegal `attack_type`)? | **`push_error` + flagged-MISS safe sentinel** for all four guards (rev 2.4 redesign). `MISS()` with `source_flags ∪ {&"invariant_violation:<reason>"}` where reason ∈ {`rng_null`, `unknown_class`, `unknown_direction`, `bad_attack_type`}. Tests assert on the flag (already in ResolveResult contract) — no dependency on any engine error-count API (rev 2.3's `Engine.get_error_count()` was fabricated; rev 2.2's `error_log_capture.gd` helper was also fabricated — the flagged-MISS redesign eliminates the need for either). No silent fallback to "Infantry" or `FRONT`; no exception throw (would break Grid Battle's exchange loop). MISS sentinel keeps HP/Status uncalled and combat advancing while error is loud in editor logs AND the flag is programmatically testable. | Guard logic is embedded in §C CR-8 (class-guards), CR-11 (output contract), CR-12 (skill stub); §E EC-DC-12/13/15/16; §J AC-DC-19/21/22/28 | RESOLVED (rev 2.4 redesign) |

### Deferred — With Default Resolution and Revisit Trigger (6)

| ID | Question | Default | Revisit Trigger | Owner |
|---|---|---|---|---|
| **OQ-DC-2-FOLLOWUP** | Migrate F-DC-3 from subtractive to ratio form (`ATK² / (ATK + DEF)`) post-MVP. | F-GB-PROV retired; subtractive F-DC-3 stays through MVP. No ratio form authored. | If Vertical Slice playtests show one-shot risk on any Cavalry-vs-Archer matchup OR counter-attack chip damage feels unrewarding (TK-DC governance log shows >3 tuning iterations on CHARGE_BONUS without convergence). | systems-designer + balance-data owner |
| **OQ-VIS-01** | Adopt `#E07020` (경고 주황) as HIT_DEVASTATING value-contrast fallback. | **Skip.** Hue proximity to 주홍 (`#C0392B`) dilutes destiny-branch reservation. HIT_DEVASTATING relies on size + backing opacity (UI-2). | Vertical Slice playtest evidence that DEVASTATING reads identically to NORMAL under monochrome OR colorblind mode. | art-director (color reservation owner) |
| **OQ-VIS-02** | Priority when `"counter"` + `"charge"` co-occur in `vfx_tags`. | **Counter glyph wins; charge border suppressed.** Mechanically blocked today by CR-8 (Charge gated off on counter), so this is a forward-compatibility default. | If a future passive enables Charge-on-counter (e.g., Hero ultimate, Destiny Branch effect), Battle VFX GDD must ratify before code change. | sound/visual VFX GDD author |
| **OQ-AUD-01** | PEAK sub-bass haptic layer on mobile. | **Skip for MVP.** DSP cost on min-spec Android vs. likely speaker inaudibility; haptic-only is platform-fragmented (iOS Core Haptics ≠ Android Vibrator API). | Vertical Slice mobile playtests on min-spec hardware show DEVASTATING reads as non-distinct from NORMAL on phone speakers. | audio-director |
| **OQ-AUD-02** | Dedicated stacked Charge+Ambush overlay asset. | **Charge wins overlay; Ambush rides tier swell.** No bespoke stack asset authored. | Vertical Slice feedback that the Cavalry REAR + Ambush stack reads as Charge-only and fails to communicate the Scout-class provenance. | audio-director + sound-designer |
| **OQ-AUD-03** | PEAK LUFS cap reconciliation with Sound/Music #24. | **−14 LUFS-S provisionally locked.** Section H A-7 ratifies this. | Sound/Music #24 GDD authoring sets a different mix bus target. Coordinated registry update required (entities.yaml audio constants). | audio-director (cross-GDD owner) |

### Open — None

Damage Calc GDD ships with **zero open BLOCKER questions** as of 2026-04-19.

### Cross-System Patches Queued (Phase 5)

The following back-reference patches must land in the same commit window as the damage-calc.md merge — tracked in Phase 5 of `/design-system damage-calc`:

1. **`grid-battle.md`** — remove F-GB-PROV from §CR-5 Step 7; cite F-DC-3/F-DC-6/F-DC-7 from `damage-calc.md`. (AC-DC-44 enforces.)
2. **`unit-role.md`** — back-reference EC-7 multiplicative ordering ratification at §D F-DC-6. **Archer CLASS_DIRECTION_MULT canonical row (rev 2.6 — BLK-7-9/10 Pillar-3 parity; merges rev 2.3–2.5 history):** Archer row is `1.00 / 1.375 / 0.90` — matches `damage-calc.md` F-DC-4 post rev 2.6. Rationale: role-identity FLANK specialist (drawn-bow release window stable at mid-range flank arcs, weapon-handling disadvantage at close-quarters rear). `unit-role.md` §CR-6a was updated in the rev 2.6 commit window to this row; implementer should verify both documents match before shipping. Also verify Infantry row is `0.90 / 1.00 / 1.10` (rev 2.5 desync fix, BLK-6-2). Do NOT regress to any prior row (`1.00 / 1.00 / 1.00` flat; `1.00 / 1.10 / 0.90` rev 2.3/2.4; `1.00 / 1.15 / 0.90` rev 2.5) — each was arithmetically defective for the Pillar it claimed to serve; see review-log rev 2.6 entry.
3. **`terrain-effect.md`** — flag the `+8%` UI vs `+15%` AC-3 elevation inconsistency as a separate bug (terrain-effect.md OQ); confirm Damage Calc treats `terrain_def` as opaque int.
4. **`hp-status.md`** — back-reference DoT bypass invariant (EC-DC-12 + AC-DC-28); confirm `apply_damage(int ≥ 1)` MIN_DAMAGE contract.
5. **`turn-order.md`** — back-reference round-counter ABI consumed by Ambush gate (D-9 worked example).
6. **`balance-data.md`** — back-reference CHARGE_BONUS, AMBUSH_BONUS registry entries authored by Phase 5 entities.yaml update.
7. **`design/registry/entities.yaml`** — register `damage_resolve` formula + `CHARGE_BONUS=1.20` + `AMBUSH_BONUS=1.15` constants; update `referenced_by` on 9 consumed constants. **Rev 2.4 update**: `BASE_CEILING` value `100 → 83` (CRITICAL-3 resolution); notes revision.
8. **`design/gdd/systems-index.md`** — row #11 status: `Not Started` → `Designed`.
9. **`docs/architecture/ADR-0005-resolve-modifiers-wrapper.md` (NEW — rev 2.3 / BLK-3 resolution)** — author a new ADR documenting the `Dictionary` → `ResolveModifiers` RefCounted wrapper for `damage_calc.resolve()`'s third argument. ADR must cover: (a) Grid Battle call-site migration (line 807–816 of grid-battle.md), (b) `AttackerContext` and `DefenderContext` companion wrappers (same pattern), (c) save/load RNG snapshot compatibility (unchanged — `rng` is still a `RandomNumberGenerator` reference), (d) test-fixture construction pattern `ResolveModifiers.make(...)` vs. prior dict-literal, (e) **rev 2.4** — `unit_class` field rename (GDScript 4.6 reserved keyword avoidance). Blocks implementation of F-DC-5 / F-DC-6 typed-signature pseudocode.
10. **`grid-battle.md` (§CR-5 lines 807–816)** — update damage_calc call-site payload description from Dictionary to typed `AttackerContext` / `DefenderContext` / `ResolveModifiers`. Depends on ADR-0005 landing first. **Rev 2.4**: field name `class` → `unit_class` in the typed wrapper.
11. **DevOps story (NEW — rev 2.4 / BLK-9+BLK-10 resolution)** — wire `.github/workflows/tests.yml` for (a) multi-platform matrix (macOS-Metal per-push baseline, Windows-D3D12 + Linux-Vulkan on weekly cron + `rc/*` tag trigger — required for AC-DC-25/37/50 enforceability) and (b) headed UI-integration job via `xvfb-run` on Linux runner (required for AC-DC-46/47). Additionally ensure `tests/gdunit4_runner.gd` discovers `tests/integration/`. Until this lands, AC-DC-25/37/46/47/50 are un-enforceable at Beta gate. Owner: producer → DevOps engineer.
12. **Build-mode sentinel (NEW — rev 2.4 / BLK-6 resolution)** — engine-programmer authors an autoload bootstrap that emits `"[BUILD_MODE] release"` / `"[BUILD_MODE] debug"` log line at boot in all builds, AND renders the string in a top-right accessibility-debug overlay chip when "Show build mode" toggle is enabled (Settings panel). Required for AC-DC-45 release-config walkthrough reproducibility.
13. **gdUnit4 addon installation (NEW — rev 2.4 / user action)** — user commits `addons/gdUnit4/` at a pinned version (ideally the latest 4.x matching the Godot 4.6 LTS line) and records the pinned version in `CLAUDE.md` or `tests/README.md`. Unblocks AC-DC-51(b) bypass-seam assertions and all `assert_eq` / `assert_that` usage across the test suite. Rev 2.4 flagged-MISS redesign has already removed dependency on gdUnit4's `assert_error(...)` matcher — so AC-DC-19/21/22 no longer require a specific gdUnit4 version, but the rest of the suite still does.

### OQ Lifecycle Summary

| Bucket | Count | Status |
|---|---|---|
| Resolved (brief) | 8 | All blockers closed |
| Resolved (mid-authoring) | 2 | All blockers closed |
| Deferred with default | 6 | Triggers + owners assigned |
| **Open BLOCKER** | **0** | — |
| **TOTAL OQs tracked** | **16** | — |

`/design-review damage-calc.md` validation: ready to run.
