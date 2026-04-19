# Terrain Effect System (지형 효과)

> **Status**: Designed
> **Author**: user + systems-designer, game-designer, ai-programmer
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 1 (형세의 전술) — terrain makes positioning meaningful

## Overview

The Terrain Effect System assigns combat modifiers to each terrain type and
elevation level defined by the Map/Grid System. Where the Map/Grid owns tile
structure, coordinates, and movement costs, this system owns what happens when
combat occurs *on* that terrain — defense bonuses for holding high ground,
evasion for fighting in forests, penalties for attacking uphill. It reads
`terrain_type` and `elevation` from the grid and provides modifier values that
the Damage/Combat Calculation system applies during combat resolution.

For the player, terrain effects are what make "where you fight" as important as
"how you fight." A low-stat spearman on a hilltop is more valuable than a
high-stat swordsman in the open plain. A forest tile isn't just an obstacle that
costs more to cross — it's cover that turns a vulnerable archer into a difficult
target. Every tile on the battlefield carries tactical weight, and this system
is what gives it that weight. Terrain modifiers are always visible to the player
(Pillar 1: read the battlefield before you act), displayed on hover/tap so
positioning decisions are informed, never guesswork.

The system's scope for MVP is focused: defense bonus (percentage damage
reduction), evasion bonus (chance to avoid attacks entirely), and elevation
modifiers (attack/defense adjustments based on height difference between
attacker and defender). Movement cost differences are Map/Grid's domain and
are not duplicated here.

## Player Fantasy

**The Land Fights For You (땅이 너를 위해 싸운다)**

The player is a 군사 who sees the battlefield not as scenery but as an
arsenal. Every hill, forest, river, and bridge is a weapon waiting to be
wielded by a commander wise enough to use it.

The fantasy is not "my unit gets +15% defense on a hill." The fantasy is:
"I did not beat the enemy with stronger soldiers. I beat them with the river
at their back and the forest at their flank. The land fought for me." A
low-rank archer on a hilltop holds off a cavalry charge — not because the
archer is strong, but because the player gave the archer an ally made of
earth. A spearman on a bridge becomes an immovable wall — one tile, one
hero, and the terrain's blessing turning weakness into fortress.

This feeling requires planning turns in advance. The satisfaction comes from
anticipatory mastery: positioning units three turns before the clash, reading
terrain like Zhuge Liang read the wind at Red Cliffs, and watching the plan
unfold as the land itself tips the scales. The emotion is resourceful
dominance — winning with less because you used *everything*, not just your
troops.

*Serves Pillar 1 (terrain is what makes positioning the language of victory),
Pillar 3 (the right terrain makes any hero indispensable — a weak unit on
strong ground outperforms a strong unit on open ground), and Pillar 4
(Three Kingdoms history is defined by battles won by terrain, not numbers).*

## Detailed Design

### Core Rules

#### CR-1. Terrain Modifier Table

Each terrain type provides combat modifiers to the **defender** standing on
that tile. Values are integers representing percentages.

| terrain_type | defense_bonus (%) | evasion_bonus (%) | Special Rule | Tactical Identity |
|---|---|---|---|---|
| PLAINS | 0 | 0 | — | Open ground — no advantage |
| HILLS | 15 | 0 | — | Defensive stronghold |
| MOUNTAIN | 20 | 5 | — | Maximum defense, minor evasion |
| FOREST | 5 | 15 | — | Evasion cover — hard to hit |
| RIVER | 0 | 0 | Impassable (Map/Grid) | Barrier, not a fighting position |
| BRIDGE | 5 | 0 | FLANK attacks blocked (CR-5) | Chokepoint — geometric advantage |
| FORTRESS_WALL | 25 | 0 | Impassable until destroyed | Siege defense (only for units on wall) |
| ROAD | 0 | 0 | — | Fast movement, no combat advantage |

**Rule CR-1a.** All modifiers apply to the **defender**. The attacker's tile
does not contribute terrain modifiers to the attack. Exception: elevation
attack bonus (CR-2) applies to the attacker.

**Rule CR-1b.** Defense bonus is a percentage reduction applied to incoming
damage. `effective_damage = base_damage × (1 - total_defense_reduction / 100)`.
The exact formula is owned by Damage/Combat Calculation GDD.

**Rule CR-1c.** Evasion bonus is a percentage chance to completely avoid an
incoming attack. If evasion triggers, the attack deals zero damage and applies
no status effects. Evasion is rolled once per attack, before damage calculation.

**Rule CR-1d.** Terrain modifiers are uniform across all unit types for MVP.
No class-specific terrain bonuses. Differentiation between classes is already
handled by Map/Grid movement costs (cavalry pays ×2 on MOUNTAIN).

---

#### CR-2. Elevation Combat Modifiers

Elevation modifiers are **asymmetric**: higher ground provides BOTH an attack
bonus (when striking downhill) AND a defense bonus (when defending from below).

`delta_elevation = attacker.elevation - defender.elevation`

| delta_elevation | Attack Modifier | Defense Modifier for Defender | Interpretation |
|---|---|---|---|
| -2 | -15% attack | +15% defense for defender | Attacker far below — severe disadvantage |
| -1 | -8% attack | +8% defense for defender | Attacker below — moderate disadvantage |
| 0 | 0 | 0 | Same level — no elevation effect |
| +1 | +8% attack | -8% defense for defender | Attacker above — moderate advantage |
| +2 | +15% attack | -15% defense for defender | Attacker far above — severe advantage |

**Rule CR-2a.** Elevation attack modifier applies to the **attacker** based on
their height advantage. Positive delta = attacking downhill = bonus.

**Rule CR-2b.** Elevation defense modifier modifies the **defender's** terrain
defense. When the attacker is above, the defender's terrain defense is reduced;
when below, it is increased.

**Rule CR-2c.** Elevation modifiers per step: 8% for delta of ±1, 15% for
delta of ±2. This is slightly sub-linear (not 8×2=16) to keep the maximum
swing within the anti-pillar budget.

---

#### CR-3. Modifier Stacking Rules

**Rule CR-3a. Additive stacking with hard cap.**
```
total_defense_reduction = clamp(
    terrain_defense + elevation_defense + formation_defense + other_defense,
    0,
    MAX_DEFENSE_REDUCTION
)
```
`MAX_DEFENSE_REDUCTION = 30` (percent)

**Rule CR-3b. Separate evasion pool.**
```
total_evasion = clamp(
    terrain_evasion + agility_evasion + other_evasion,
    0,
    MAX_EVASION
)
```
`MAX_EVASION = 30` (percent)

Evasion and defense reduction are **independent**. Evasion is rolled first
(avoid the entire hit). If evasion fails, defense reduction applies to damage.

**Rule CR-3c. Cap visibility.** When the UI displays defense or evasion, if
the total has been capped, show "30% [MAX]" so the player knows additional
stacking is wasted. This informs positioning decisions.

**Rule CR-3d. Minimum damage rule.** Even at maximum defense reduction (30%),
the minimum damage dealt is 1. No attack deals zero damage through defense
alone — only evasion avoids all damage.

**Rule CR-3e. Negative defense values.** Elevation can reduce defender's
terrain defense below zero (e.g., PLAINS 0% defense + attacker above -8% =
-8%). Negative defense means the defender takes MORE damage than base.
Negative defense is NOT capped — it can go as low as -15% (worst case:
PLAINS + delta_elevation = +2).

---

#### CR-4. Terrain Query Interface

This system exposes three query methods for consumer systems:

**Method 1 — Raw modifiers (for HUD display, tile inspection):**
```
get_terrain_modifiers(coord: Vector2i) -> TerrainModifiers
```
Returns: `{ defense_bonus: int, evasion_bonus: int, special_rules: Array[StringName] }`

**Method 2 — Combat context (for Damage Calc, with elevation):**
```
get_combat_modifiers(attacker_coord: Vector2i, defender_coord: Vector2i) -> CombatModifiers
```
Returns: `{ defender_terrain_def: int, defender_terrain_eva: int,
elevation_atk_mod: int, elevation_def_mod: int, special_rules: Array[StringName] }`

This method reads both tiles from Map/Grid, calculates delta_elevation, and
returns the full modifier set for a single attack interaction.

**Method 3 — AI scoring (for positioning evaluation):**
```
get_terrain_score(coord: Vector2i) -> float
```
Returns: normalized 0.0–1.0 score combining defense and evasion bonuses.
AI uses this for fast tile ranking. AI applies its own unit-type weighting.

---

#### CR-5. Bridge Chokepoint Rule

**Rule CR-5a.** On a BRIDGE tile, the `get_attack_direction()` calculation
(owned by Map/Grid) is overridden: FLANK results are converted to FRONT.

| Raw attack_direction | On Bridge result |
|---|---|
| FRONT | FRONT |
| FLANK | → FRONT |
| REAR | REAR |

**Rule CR-5b.** This rule applies only when the **defender** is on a BRIDGE
tile. If the attacker is on a bridge and the defender is not, standard
direction rules apply.

**Rule CR-5c.** REAR attacks remain possible on bridges. A unit that crosses
the river elsewhere can still approach from behind. The rule only removes the
geometric impossibility of flanking on a 1-tile-wide structure.

**Rule CR-5d.** The bridge's FLANK protection is a `special_rule` returned by
`get_terrain_modifiers()` as `&"bridge_no_flank"`. Damage Calc checks this
flag when resolving attack direction.

---

### States and Transitions

The Terrain Effect System is **stateless**. It is a pure query layer — given a
tile coordinate, it returns modifiers. It does not maintain internal state,
timers, or buffs.

The only state that affects terrain modifiers is the tile's `terrain_type` and
`elevation`, which are owned by Map/Grid. If Map/Grid supports dynamic terrain
changes in the future (Open Question #3 in Map/Grid GDD: fire destroying forest,
flood converting plains to river), this system's modifiers automatically update
because it reads from Map/Grid on every query — no cache to invalidate.

**Exception:** If performance requires caching terrain modifiers, the cache must
subscribe to Map/Grid's `tile_destroyed(coord)` signal and any future
`terrain_changed(coord)` signal to invalidate affected entries.

---

### Interactions with Other Systems

#### Upstream (this system reads from)

| System | Data Read | Method |
|--------|----------|--------|
| Map/Grid System | `terrain_type`, `elevation` per tile | `get_tile(coord)` |

#### Downstream (these systems read from this)

| Consumer | Method Used | Purpose |
|----------|-------------|---------|
| Damage/Combat Calculation | `get_combat_modifiers(atk, def)` | Apply defense reduction and evasion to damage formula. **Contract ratified 2026-04-18 by `design/gdd/damage-calc.md` §F**: `terrain_def` is an opaque signed integer ∈ [−30, +30] already clamped per MAX_DEFENSE_REDUCTION; `terrain_evasion` is an opaque integer ∈ [0, 30] already clamped per MAX_EVASION. Damage Calc owns the evasion roll (F-DC-2, OQ-DC-1 resolution). |
| Grid Battle System | `get_terrain_modifiers(coord)` | Display terrain info on tile selection |
| Battle HUD | `get_terrain_modifiers(coord)` | Show defense/evasion values in tile tooltip |
| AI System | `get_terrain_score(coord)` + `get_terrain_modifiers(coord)` | Evaluate tile quality for positioning |
| Formation Bonus | (indirect) | Formation defense stacks with terrain defense under the same cap |

#### Cross-System Contracts

- **Terrain → Damage Calc:** Defense reduction is a percentage passed to the
  damage formula. Damage Calc applies it as `base_damage × (1 - total_def / 100)`.
  This system provides the terrain component; Damage Calc owns the final formula.
- **Terrain → Map/Grid (bridge rule):** The FLANK → FRONT override (CR-5) modifies
  the output of Map/Grid's `get_attack_direction()`. Terrain Effect wraps or
  decorates the attack direction result for tiles with `special_rules`. This is
  an ADR candidate for implementation.
- **Stacking cap ownership:** This system defines `MAX_DEFENSE_REDUCTION = 30`
  and `MAX_EVASION = 30`. Damage Calc enforces the clamp. The cap values live
  in `assets/data/terrain/terrain_config.json` (this system's config), not in
  Damage Calc's config.

## Formulas

### F-1. Effective Defense Reduction

```
terrain_def = terrain_modifier_table[defender_terrain_type].defense_bonus
elevation_def = elevation_defense_table[delta_elevation]
total_defense = clamp(terrain_def + elevation_def + formation_def + other_def,
                      -MAX_DEFENSE_REDUCTION, MAX_DEFENSE_REDUCTION)
effective_damage = base_damage × (1 - total_defense / 100)
final_damage = max(1, effective_damage)
```

| Variable | Type | Range | Source |
|----------|------|-------|--------|
| terrain_def | int | 0–25 | CR-1 table |
| elevation_def | int | -15 to +15 | CR-2 table (defender perspective) |
| formation_def | int | 0–? | Formation Bonus GDD (future) |
| other_def | int | 0–? | Other systems (future) |
| MAX_DEFENSE_REDUCTION | int | 30 | Tuning knob |
| base_damage | int | 1+ | Damage Calc GDD (future) |
| effective_damage | float | 0.70–1.30 × base_damage | Output |
| final_damage | int | 1+ | Minimum 1 |

**Output Range:**
- Best case for defender: +30% reduction → `base_damage × 0.70`
- Worst case for defender: -30% (negative defense) → `base_damage × 1.30`
- Minimum: 1 (CR-3d minimum damage rule)
- Clamp is symmetric: -30 to +30, bounding both amplification and reduction

**Example:** Archer on HILLS (def=15) attacked from below (delta=-1, elev_def=+8).
`total_defense = clamp(15 + 8, -30, 30) = 23`. `effective = 50 × 0.77 = 38.5 → 39`.

**Example:** Infantry on PLAINS (def=0) attacked from above (delta=+2, elev_def=-15).
`total_defense = clamp(0 + (-15), -30, 30) = -15`. `effective = 50 × 1.15 = 57.5 → 58`.

---

### F-2. Evasion Check

```
total_evasion = clamp(terrain_eva + agility_eva + other_eva, 0, MAX_EVASION)
evaded = (random(0, 99) < total_evasion)
```

| Variable | Type | Range | Source |
|----------|------|-------|--------|
| terrain_eva | int | 0–15 | CR-1 table |
| agility_eva | int | 0–? | Unit stats (Hero DB / Unit Role GDD) |
| other_eva | int | 0–? | Other systems (future) |
| MAX_EVASION | int | 30 | Tuning knob |
| evaded | bool | — | Output |

**Output:** Boolean. If true, attack deals 0 damage and no status effects.

**Example:** Unit on FOREST (eva=15), agility bonus adds 10%.
`total_evasion = clamp(15 + 10, 0, 30) = 25`. 25% chance to evade.

---

### F-3. Terrain Score (AI)

```
terrain_score = (defense_bonus + evasion_bonus × EVASION_WEIGHT) / MAX_POSSIBLE_SCORE
```

| Variable | Type | Range | Source |
|----------|------|-------|--------|
| defense_bonus | int | 0–25 | CR-1 table |
| evasion_bonus | int | 0–15 | CR-1 table |
| EVASION_WEIGHT | float | 1.2 | Tuning knob — evasion slightly valued over defense |
| MAX_POSSIBLE_SCORE | float | 43.0 | 25 + 15 × 1.2 (FORTRESS_WALL theoretical max) |
| terrain_score | float | 0.0–1.0 | Output |

**Example:** FOREST → `(5 + 15 × 1.2) / 43 = 23 / 43 ≈ 0.53`.
HILLS → `(15 + 0) / 43 ≈ 0.35`. PLAINS → `0.0`.

## Edge Cases

### EC-1. CR-3e Clarification — Negative Defense Uses Symmetric Clamp

**Scenario:** CR-3e states negative defense is "NOT capped," but F-1 uses
`clamp(..., -30, +30)`. These conflict when future sources contribute
additional negative defense (e.g., terrain 0 + elevation -15 + formation
penalty -10 = -25, clamped to -25, not -30).

**Resolution:** F-1's symmetric clamp is authoritative. Negative defense is
clamped at -30, matching the positive cap. CR-3e's "not capped" means
negative values are not *floored to zero* — they pass through the formula
and amplify damage — but the symmetric clamp still bounds them. Maximum
amplification is 30% in either direction.

---

### EC-2. FORTRESS_WALL Occupancy — Garrison Model

**Scenario:** FORTRESS_WALL is listed as "Impassable until destroyed" but
grants 25% defense. If no unit can stand on it, the defense is unreachable.

**Resolution:** FORTRESS_WALL uses the **garrison model**. Friendly units
may occupy the wall tile (garrison). Enemy units cannot enter or pass through
until the wall segment is destroyed (HP reduced to 0 — wall HP is owned by
the Siege/Destructible subsystem, future GDD). The 25% defense applies to the
garrisoned defender. When the wall is destroyed, the tile's `terrain_type`
changes to PLAINS (or RUBBLE, if defined later), and `get_terrain_modifiers()`
automatically returns the new type's values.

---

### EC-3. Both Attacker and Defender on Bridge Tiles

**Scenario:** On a multi-tile bridge, the attacker occupies a BRIDGE tile and
attacks a defender on an adjacent BRIDGE tile.

**Resolution:** CR-5b is defender-centric. The bridge FLANK→FRONT override
applies whenever the **defender** is on a BRIDGE tile, regardless of the
attacker's tile type. The attacker's tile never contributes defensive modifiers
(CR-1a). Both-on-bridge produces the same result as only-defender-on-bridge.

---

### EC-4. Multi-Tile Bridge Width — Uniform Rule

**Scenario:** A 2-tile-wide bridge allows geometric flanking that a 1-tile-wide
bridge does not. Should wider bridges still block FLANK?

**Resolution:** The FLANK→FRONT override applies to **all BRIDGE tiles**
regardless of bridge width. The rule is tile-type-based, not geometry-based.
Level designers control tactical weight by choosing bridge width — a wide bridge
still blocks flanking but allows more units to cross simultaneously. This keeps
the rule simple, predictable, and consistent for the player.

---

### EC-5. AI Terrain Score Is Elevation-Agnostic

**Scenario:** `get_terrain_score()` returns 0.0 for PLAINS, but a unit on
PLAINS under an attacker at elevation +2 has effective defense of -15%. The
AI score does not reflect this danger.

**Resolution:** `get_terrain_score()` is intentionally elevation-agnostic —
it evaluates raw tile quality without an attacker reference point. The AI
system must call `get_combat_modifiers(atk_coord, def_coord)` when evaluating
specific attack matchups. Document this split: "get_terrain_score provides
base tile quality only. For positional evaluation against a specific threat,
AI must combine terrain score with `get_combat_modifiers()` elevation data."

---

### EC-6. Ranged Attacks and Elevation

**Scenario:** Does elevation advantage apply differently for ranged vs. melee
attacks? Is delta_elevation computed from tile positions only, or from the
projectile trajectory path?

**Resolution:** Elevation delta is always `attacker.elevation - defender.elevation`
regardless of attack range, unit type (melee/ranged), or intermediate tile
elevations. No trajectory calculation. This maintains the stateless pure-query
design — the system reads two coordinates, not a path.

---

### EC-7. Multiple Hits per Action — Evasion Rolls Per Hit

**Scenario:** A skill like "Double Strike" deals two hits in one action. Is
evasion rolled once for the action or once per hit?

**Resolution:** Each damage-dealing hit is one "attack" for evasion purposes.
Multi-hit skills trigger one evasion roll per hit. Area-of-effect attacks
trigger one evasion roll per affected defender. This system provides the
evasion value; Damage Calc enforces the per-hit roll policy.

---

### EC-8. Guaranteed-Hit Abilities Bypass Evasion

**Scenario:** Future skills may need to bypass the evasion check entirely.
The current formula has no override mechanism.

**Resolution:** This system's boundary is data provision, not roll execution.
`get_combat_modifiers()` always returns `defender_terrain_eva` as a raw value.
Whether the evasion roll is actually performed is owned by Damage Calc / Skill
System. A skill with a `guaranteed_hit` flag suppresses the roll at the caller
level. This system needs no modification for guaranteed-hit abilities.

---

### EC-9. Dynamic Terrain Change Mid-Combat

**Scenario:** If Map/Grid changes a tile during combat resolution (fire destroys
FOREST → PLAINS), which modifiers apply — the values at attack initiation or
the values after the change?

**Resolution:** Callers must snapshot modifier values at attack initiation (when
`get_combat_modifiers()` is called). This system returns current-state values on
every query with no temporal guarantees. Snapshot responsibility belongs to
Damage Calc. If a terrain change occurs between the evasion roll and the damage
calculation within the same attack resolution, the snapshotted values are used.

---

### EC-10. AoE Attacks — Per-Target Modifier Resolution

**Scenario:** An AoE ability targets a tile area. Multiple defenders stand on
different terrain types within the area.

**Resolution:** `get_combat_modifiers()` is called once per (attacker, defender)
pair. Each defender benefits from their own tile's modifiers, not the AoE center
tile's modifiers. The attacker coordinate remains the same for all targets in
the AoE; only the defender coordinate changes per target.

---

### EC-11. Damage Rounding — Floor Toward Zero

**Scenario:** F-1 produces `effective_damage = base_damage × (1 - total_defense / 100)`.
Fractional results (e.g., 7.5) need a rounding rule.

**Resolution:** Fractional damage is **truncated toward zero** (floor for positive
values). The `max(1, ...)` minimum rule is applied after truncation.
`floor(7.5) = 7`, `max(1, 7) = 7`. Floor favors the defender, reinforcing the
"terrain fights for you" fantasy. Damage Calc implements this; the rule is stated
here because the formula originates here.

---

### EC-12. Cap Display — Raw Values with Cap Indicator

**Scenario:** When stacking exceeds the cap (e.g., FORTRESS_WALL 25% + elevation
+8% + formation 5% = 38%, capped to 30%), the HUD breakdown does not sum to
the displayed total.

**Resolution:** `get_terrain_modifiers()` returns **raw (uncapped)** values for
display. `get_combat_modifiers()` returns the **clamped total** for combat.
The HUD shows raw component values (25 + 8 + 5) with a `[MAX: 30%]` indicator
when the sum exceeds the cap. Players see what each source contributes and
understand that the excess is wasted — informing future positioning decisions
(Pillar 1: informed, not guesswork).

---

### EC-13. RIVER Tile Queries — Future Flying/Boat Units

**Scenario:** RIVER is Impassable (Map/Grid), but a future flying or boat unit
may legally occupy it. Querying terrain modifiers for a RIVER tile should not
error.

**Resolution:** `get_terrain_modifiers()` returns valid data for all terrain
types, including RIVER (defense 0, evasion 0, no special rules). The Impassable
constraint is a movement rule owned by Map/Grid, not a modifier rule. If a unit
legally occupies a RIVER tile, it receives RIVER modifiers (0/0). No guard
clause or error for RIVER queries.

---

### EC-14. Elevation Delta Beyond ±2 — Defensive Clamp

**Scenario:** Current elevation range (0–2) bounds delta to ±2. A future
elevation level 3 would produce delta ±3, which has no table entry in CR-2.

**Resolution:** `get_combat_modifiers()` clamps `delta_elevation` to [−2, +2]
before table lookup. If a clamped value is used, the system logs a warning:
`"delta_elevation [value] clamped to ±2 — update CR-2 table for new elevation
range."` Any addition of elevation level 3+ requires a corresponding CR-2 table
update.

## Dependencies

### Upstream Dependencies (this system reads from)

| System | Priority | GDD Status | Data Consumed | Interface |
|--------|----------|------------|---------------|-----------|
| Map/Grid System | MVP | Designed | `terrain_type`, `elevation` per tile; `get_attack_direction()` output | `get_tile(coord: Vector2i) -> TileData` |

**Contract:** This system requires Map/Grid to provide `terrain_type: StringName`
and `elevation: int` for any valid coordinate. If Map/Grid returns null (out of
bounds), this system returns zero modifiers (defense 0, evasion 0, no special
rules). Map/Grid is the single source of truth for tile data — this system
never caches or duplicates tile definitions.

### Downstream Dependencies (these systems read from this)

| Consumer | Priority | GDD Status | Data Consumed | Interface Used |
|----------|----------|------------|---------------|----------------|
| Damage/Combat Calculation | MVP | Not Started | Defense reduction %, evasion %, elevation attack mod, special rules | `get_combat_modifiers(atk, def)` |
| Grid Battle System | MVP | Not Started | Terrain info for tile selection display | `get_terrain_modifiers(coord)` |
| Battle HUD | Alpha | Not Started | Defense/evasion values for tile tooltip | `get_terrain_modifiers(coord)` |
| AI System | MVP | Not Started | Terrain quality score + raw modifiers for positioning | `get_terrain_score(coord)` + `get_terrain_modifiers(coord)` |
| Formation Bonus | MVP | Not Started | (indirect) Formation defense stacks with terrain defense under shared cap | Shared cap values: `MAX_DEFENSE_REDUCTION`, `MAX_EVASION` |

### Cross-System Contracts

- **→ Damage Calc:** This system provides terrain/elevation components. Damage Calc
  owns the final formula, enforces the clamp, applies floor rounding (EC-11), and
  enforces the `max(1, ...)` minimum damage rule. Cap constants
  (`MAX_DEFENSE_REDUCTION = 30`, `MAX_EVASION = 30`) are defined in this system's
  config (`assets/data/terrain/terrain_config.json`) and read by Damage Calc.
- **→ Map/Grid (bridge rule):** The FLANK→FRONT override (CR-5) decorates Map/Grid's
  `get_attack_direction()` output. Implementation approach (wrapper vs. signal vs.
  decorator) is an ADR candidate.
- **→ AI System:** `get_terrain_score()` is elevation-agnostic (EC-5). AI must
  combine it with `get_combat_modifiers()` for positional decisions against
  specific threats.
- **← Map/Grid (future):** If Map/Grid adds `terrain_changed(coord)` signal for
  dynamic terrain (Open Question #3), this system subscribes if caching is implemented.
  Without caching, no subscription needed — queries always read live data.

### External Configuration

| File | Owned By | Contents |
|------|----------|----------|
| `assets/data/terrain/terrain_config.json` | This system | Terrain modifier table, elevation table, cap values, AI scoring weights |

## Tuning Knobs

| # | Knob | Current Value | Safe Range | Gameplay Effect | Config Location |
|---|------|---------------|------------|-----------------|-----------------|
| TK-1 | `MAX_DEFENSE_REDUCTION` | 30% | 20–40% | Higher → terrain dominance increases, positioning becomes more decisive. Lower → terrain matters less, raw stats dominate. Below 20% makes terrain feel irrelevant. Above 40% risks balance collapse (anti-pillar). | `terrain_config.json` |
| TK-2 | `MAX_EVASION` | 30% | 20–35% | Higher → evasion-based terrain (FOREST) becomes very strong, RNG frustration increases. Lower → evasion is a minor bonus, FOREST loses tactical identity. Above 35% creates coin-flip combat that feels unfair. | `terrain_config.json` |
| TK-3 | `EVASION_WEIGHT` (AI scoring) | 1.2 | 0.8–1.5 | Higher → AI prioritizes evasion tiles (FOREST) over defense tiles (HILLS). Lower → AI treats defense and evasion equally or prefers defense. At 1.0, pure parity. | `terrain_config.json` |
| TK-4 | Per-terrain `defense_bonus` | See CR-1 table | 0–25% per type | Each terrain type's defensive identity. HILLS at 15 vs. MOUNTAIN at 20 creates a 5-point gap — narrowing it merges their identity. Widening it makes MOUNTAIN strictly superior. | `terrain_config.json` |
| TK-5 | Per-terrain `evasion_bonus` | See CR-1 table | 0–20% per type | FOREST's evasion at 15% is its defining trait. Reducing it below 10% makes FOREST feel like bad HILLS. Adding evasion to HILLS would blur the defense/evasion split. | `terrain_config.json` |
| TK-6 | Elevation modifier per step | 8% (±1), 15% (±2) | 5–12% (±1), 10–20% (±2) | Higher → elevation dominance. A 2-level height advantage at 20% creates a 40% swing (attack + defense), approaching the cap by itself. Lower → height is a minor factor, reducing vertical map design value. | `terrain_config.json` |
| TK-7 | `MIN_DAMAGE` | 1 | 1 | Fixed at 1. Setting to 0 would allow defense to nullify attacks entirely, creating invulnerable positions. Not recommended for tuning — treat as a constant. | `terrain_config.json` |
| TK-8 | `BRIDGE_defense_bonus` | 5% | 0–10% | Higher → bridges become powerful defensive positions beyond just FLANK blocking. Lower → bridge value is purely the FLANK override, no raw defense. At 0%, bridges are only valuable for chokepoint geometry. | `terrain_config.json` |

### Tuning Guidelines

- **Terrain identity rule:** Each terrain type should have a clear "best at" trait.
  HILLS = defense, FOREST = evasion, MOUNTAIN = both (but costly to reach),
  BRIDGE = chokepoint. If tuning blurs these identities, the player loses the
  ability to read the battlefield at a glance (Pillar 1 violation).
- **Cap headroom rule:** No single terrain type + elevation combo should reach the
  cap alone. The cap should only be reachable by combining terrain + elevation +
  formation (3 sources). This ensures the player must work for maximum defense.
  Current worst case: FORTRESS_WALL (25) + elevation +8 = 33, capped to 30 — this
  is acceptable because FORTRESS_WALL is a rare siege tile.
- **Elevation sub-linearity:** The ±2 step is intentionally less than 2× the ±1 step
  (15 < 16). This keeps the maximum elevation swing within budget. If ±1 is tuned
  up, ±2 must be checked against the cap.

## Visual/Audio Requirements

### Visual Requirements

| Element | Description | Trigger | Priority |
|---------|-------------|---------|----------|
| **Terrain tint overlay** | Semi-transparent colored overlay on tiles showing defense (blue) and evasion (green) intensity. Opacity proportional to bonus value. | Player toggles "Terrain View" (Input: `G-8 TOGGLE_TERRAIN_OVERLAY`) | MVP |
| **Elevation shading** | Higher tiles are slightly brighter; lower tiles slightly darker. Subtle enough to not conflict with the ink-wash aesthetic. | Always on (baked into tileset or shader) | MVP |
| **Tile selection info** | When a tile is selected/hovered, terrain modifiers appear in the tile tooltip panel (owned by Battle HUD). | Tile cursor hover/selection | MVP |
| **Cap indicator** | When a unit's total defense or evasion is capped, display a small icon or "[MAX]" marker next to the value in the HUD. | Defense or evasion total reaches 30% | MVP |
| **Evasion dodge animation** | Brief dodge/sidestep animation when evasion triggers. Must be fast (<0.5s) to avoid slowing combat. | Evasion roll succeeds (F-2) | Vertical Slice |
| **Bridge chokepoint glow** | Subtle visual indicator on BRIDGE tiles when a unit is defending there — a faint ground glow or shield icon to signal FLANK protection is active. | Unit standing on BRIDGE tile | Vertical Slice |

### Audio Requirements

| Element | Description | Trigger | Priority |
|---------|-------------|---------|----------|
| **Evasion whoosh** | Short, satisfying whoosh/dodge sound when evasion triggers. Distinct from a miss — this is the terrain saving the unit. | Evasion roll succeeds | Vertical Slice |
| **Elevation advantage hit** | Slightly more impactful hit sound when attacking from elevation +2. Conveys the weight of a downhill strike. | `delta_elevation >= +2` on successful attack | Alpha |

### Art Direction Notes

- All terrain visual indicators must conform to the ink-wash (수묵화) aesthetic
  established in the art bible (`design/art/art-bible.md`).
- Terrain overlays use muted, desaturated tones — never saturated game-UI colors.
  Blue-gray for defense, green-gray for evasion.
- Reserved colors (주홍 #C0392B, 금색 #D4A017) are NEVER used for terrain
  indicators — those are exclusively for the Destiny Branch system.

## UI Requirements

### Tile Tooltip (Battle HUD responsibility)

When the player selects or hovers over a tile, the Battle HUD displays:

| Field | Format | Example |
|-------|--------|---------|
| Terrain type | Icon + localized name | 🏔 산지 (MOUNTAIN) |
| Defense bonus | `+N%` or `0%` | `+20%` |
| Evasion bonus | `+N%` or `0%` | `+5%` |
| Elevation | Level number | Lv.2 |
| Special rules | Icon + short text | 🛡 측면 공격 불가 (No Flank) |

### Combat Preview (Damage Calc → HUD responsibility)

When the player selects an attacker and targets a defender, the preview shows:

| Field | Format | Example |
|-------|--------|---------|
| Terrain defense | Source breakdown | 산지 +20%, 고지 +8% |
| Total defense | Clamped value | 방어 28% |
| Cap warning | Show only when capped | `[MAX: 30%]` |
| Evasion chance | Clamped value | 회피 5% |
| Elevation indicator | Arrow icon | ↑ 높은 곳에서 공격 (+8% 공격) |
| Bridge protection | Show only on bridge | 측면 공격 차단 |

### Terrain Overlay Toggle

- Input: `G-8 TOGGLE_TERRAIN_OVERLAY` (defined in Input Handling GDD)
- Overlay mode shows color-coded terrain values across the entire visible grid
- Must not obscure unit sprites — overlay is on the tile ground, beneath units
- Toggle state persists within a battle; resets to OFF at battle start

### Accessibility Notes

- Terrain type must be identifiable without color alone (icon + text label)
- Defense/evasion values are always numeric, never communicated solely through
  visual intensity
- Screen reader support (future): terrain tooltip content is structured text
  that can be exposed to AccessKit (Godot 4.5+)

## Acceptance Criteria

### Functional Criteria

| # | Criterion | Test Method | Pass Condition |
|---|-----------|-------------|----------------|
| AC-1 | Terrain defense applies to defender | Unit test | Unit on HILLS takes 15% less damage than unit on PLAINS from identical attack |
| AC-2 | Terrain evasion triggers correctly | Unit test (seeded RNG) | Unit on FOREST with 15% evasion avoids exactly 15/100 attacks with seeded random sequence |
| AC-3 | Elevation attack bonus applies | Unit test | Attacker at elevation 2 vs. defender at elevation 0 deals 15% more damage than same-level attack |
| AC-4 | Elevation defense modifier applies | Unit test | Defender at elevation 0 attacked from elevation 2 has terrain defense reduced by 15% |
| AC-5 | Defense cap enforced at 30% | Unit test | FORTRESS_WALL (25) + elevation +8 = 33% → clamped to 30%. Verify damage uses 30%, not 33% |
| AC-6 | Evasion cap enforced at 30% | Unit test | FOREST (15) + agility (20) = 35% → clamped to 30%. Verify evasion rate is 30%, not 35% |
| AC-7 | Negative defense amplifies damage | Unit test | PLAINS (0) + elevation -15 = -15% defense → damage is `base × 1.15` |
| AC-8 | Minimum damage of 1 | Unit test | Attack with base_damage=1 against FORTRESS_WALL (25% reduction) → `floor(1 × 0.75) = 0 → max(1, 0) = 1` |
| AC-9 | Bridge FLANK→FRONT override | Unit test | Defender on BRIDGE: attack from FLANK direction returns FRONT. Attack from REAR remains REAR |
| AC-10 | Bridge rule is defender-centric | Unit test | Attacker on BRIDGE, defender on PLAINS: standard FLANK rules apply (no override) |
| AC-11 | `get_terrain_modifiers()` returns correct values | Unit test per terrain type | All 8 terrain types return expected defense_bonus, evasion_bonus, and special_rules |
| AC-12 | `get_combat_modifiers()` returns full context | Unit test | Given two coordinates with known terrain/elevation, all 5 return fields match expected values |
| AC-13 | `get_terrain_score()` returns normalized value | Unit test per terrain type | All terrain types return value in [0.0, 1.0] matching F-3 formula |
| AC-14 | Out-of-bounds coordinate returns zeroes | Unit test | `get_terrain_modifiers(Vector2i(-1, -1))` returns `{ defense: 0, evasion: 0, special: [] }` |
| AC-15 | Floor rounding applied | Unit test | `base=10, defense=25%` → `10 × 0.75 = 7.5 → floor → 7` (not 8) |
| AC-16 | Evasion rolled per hit, not per action | Integration test | Multi-hit skill (2 hits) against FOREST unit: each hit has independent evasion roll |
| AC-17 | Cap display shows [MAX] | Manual / UI test | Unit on FORTRESS_WALL with formation bonus exceeding cap: HUD shows `[MAX: 30%]` |
| AC-18 | Terrain overlay toggle | Manual / UI test | Pressing `G-8` toggles terrain overlay on/off; overlay shows correct color intensity per tile |

### Data-Driven Criteria

| # | Criterion | Test Method | Pass Condition |
|---|-----------|-------------|----------------|
| AC-19 | All terrain values loaded from config | Unit test | Modify `terrain_config.json` HILLS defense from 15 to 20 → system returns 20 without code change |
| AC-20 | Config schema validated on load | Unit test | Invalid config (negative defense, missing field) → system logs error and falls back to defaults |

### Performance Criteria

| # | Criterion | Test Method | Pass Condition |
|---|-----------|-------------|----------------|
| AC-21 | Query latency | Performance test | `get_combat_modifiers()` completes in <0.1ms per call (budget: 100 calls per frame at 60fps) |

## Open Questions

| # | Question | Impact | Blocking? | Resolution Owner |
|---|----------|--------|-----------|------------------|
| OQ-1 | **Should elevation modifiers differ for ranged vs. melee?** EC-6 rules them identical for MVP. If ranged units get reduced elevation penalty (archers on low ground aren't as disadvantaged), this changes the elevation table. | Balance — affects ranged unit viability on flat maps | No (MVP uses uniform rule) | systems-designer + game-designer at Unit Role GDD |
| OQ-2 | **FORTRESS_WALL garrison capacity** — EC-2 establishes the garrison model, but how many units can garrison one wall tile? One unit (consistent with 1-unit-per-tile)? Or does the wall tile support 2 (archer + infantry)? | Siege balance — more garrisons = harder sieges | No (1-per-tile for MVP) | game-designer at Grid Battle GDD |
| OQ-3 | **Dynamic terrain timing** — Map/Grid's Open Question #3 defers dynamic terrain to Vertical Slice. When implemented, should terrain changes trigger a visual/audio cue (e.g., forest burning animation + modifier change notification)? | Player clarity — invisible modifier changes violate Pillar 1 | No (future) | art-director + game-designer |
| OQ-4 | **Weather interaction** — Should weather systems (rain, fog) modify terrain bonuses? Rain could reduce FOREST evasion (wet foliage), fog could add universal evasion. This would require a weather modifier layer on top of terrain. | Design complexity — adds a third modifier source | No (post-MVP at earliest) | systems-designer |
| OQ-5 | **Bridge FLANK override implementation** — CR-5 decorates Map/Grid's `get_attack_direction()` output. Should this be a wrapper pattern, a signal, or should Map/Grid check for bridge_no_flank internally? This is an architecture decision, not a design question. | Code architecture — affects system coupling | Yes (before implementation) | `/architecture-decision` ADR |
| OQ-6 | **Terrain config hot-reload** — Should `terrain_config.json` support hot-reload during development for live tuning? This affects whether the config is read once at battle start or re-read on signal. | Dev workflow only — no gameplay impact | No | tools-programmer |
| OQ-7 | **Elevation percentage inconsistency: UI text "+8%" (line 109/111) vs. AC-3 "+15%" (line 692).** The elevation table at line 108–112 defines the intended values (±8% / ±15% per delta_elevation step), but AC-3 tests `elevation 2 vs elevation 0 → +15% more damage`, which corresponds to `delta=+2` row, not `+1`. Raised by `design/gdd/damage-calc.md` §F during Phase 5 back-reference audit 2026-04-18 — Damage Calc treats `terrain_def` as an opaque signed integer ∈ [−30, +30] and does not see the underlying elevation delta, so inconsistency is contained entirely inside terrain-effect.md. | Correctness — AC-3 may be testing the wrong scenario or the UI text may understate the true elevation payoff | Yes (before Terrain Effect implementation + Damage Calc integration test lands) | systems-designer + qa-lead |
