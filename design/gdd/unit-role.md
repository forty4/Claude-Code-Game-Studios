# Unit Role System (무장 역할)

> **Status**: Designed
> **Author**: user + game-designer, systems-designer
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 3 (모든 무장에게 자리가 있다) — every class plays differently

## Overview

The Unit Role System defines the combat identity and mechanical behavior of the
six classes (병종) in 천명역전: CAVALRY, INFANTRY, ARCHER, STRATEGIST, COMMANDER,
and SCOUT. Where the Hero Database establishes who each hero is — their stats,
faction, and personality — this system establishes what their class can do on the
battlefield. It owns class stat templates (base HP formulas, attack power
derivations, defense ratings), terrain movement cost multipliers per class
(cavalry pays double on mountains, infantry moves efficiently everywhere),
attack range definitions (melee vs. ranged vs. skill-based), equipment slot
configurations per class, and the combat behaviors that give each class its
tactical identity.

For the player, this system is what makes every unit placement a meaningful
choice. A cavalry unit is not simply "infantry but faster" — it's a flanking
weapon that excels on open ground and struggles in forests. An archer is not
"infantry but ranged" — it's a positional asset that dominates from elevation
but crumbles when engaged in melee. A strategist reshapes the battlefield
through area effects, not personal combat. The system ensures that no single
class dominates all situations (Anti-Pillar: NOT 밸런스 붕괴 허용), and that
the answer to "which unit should I place here?" always depends on the terrain,
the enemy composition, and the formation — never on a single "best class."

MVP scope: 6 classes with distinct stat derivations, terrain cost tables,
attack ranges, and equipment slots. Class-specific abilities (skills) reference
the Skill/Ability data defined in `assets/data/skills/` but this system owns
the class-to-skill mapping rules. Class Conversion (병종 변환) is deferred to
Vertical Slice.

## Player Fantasy

**Six Brushstrokes, One Painting (육필일화, 六筆一畵)**

수묵화에서 먹 한 획이 빠지면 그림이 무너지듯, 전장에서 한 무장의 자리가
비면 진형이 무너진다. 이 시스템이 전달하는 감각은 '누가 가장 강한가'가 아니라
'누가 빠지면 안 되는가'이다 — 그리고 그 답은 항상 전부다.

기병은 측면을 찢는 날카로운 먹선. 보병은 전선을 버티는 농묵(濃墨)의 획.
궁병은 높은 곳에서 전장을 눌러주는 담묵(淡墨)의 그림자. 군사(軍師)는
전장의 결을 바꾸는 발묵(潑墨). 사령관은 진형에 숨을 불어넣는 여백의 기운.
정찰병은 적의 의도를 읽어내는 첫 번째 점.

여섯 붓질이 하나의 전장화(戰場畵)를 이룬다. 플레이어는 화가다 — 무장이라는
먹을 전장이라는 화선지 위에 놓아 하나의 형세를 완성하는 화가. 어떤 먹도
쓸모없지 않다. 다만 올바른 곳에 놓이지 않았을 뿐이다.

*여섯 획이 모여 하나의 그림이 된다. 어떤 획도 빼면 안 된다.*

*Serves Pillar 3 (모든 무장에게 자리가 있다 — the painting where removing any
stroke ruins the whole), Pillar 1 (형세의 전술 — the player composes formations
like a painter composes brushstrokes), and connects to the art bible's core
principle: "먹(墨)으로 진형을 짜고, 역사의 무게로 색을 올린다."*

## Detailed Design

### Core Rules

#### CR-1. Class Profile Table

Each class defines a combat archetype. Hero DB provides base stats; this system
applies class-specific multipliers to derive combat values.

| Class | Primary Stat | Attack Type | Attack Range | Move Delta | Equipment Slots |
|---|---|---|---|---|---|
| CAVALRY (기병) | stat_might | PHYSICAL | 1 (melee) | +1 | WEAPON, ARMOR, ACCESSORY |
| INFANTRY (보병) | stat_might | PHYSICAL | 1 (melee) | +0 | WEAPON, ARMOR, ACCESSORY |
| ARCHER (궁병) | stat_might + stat_agility | PHYSICAL | 3 (ranged) | +0 | WEAPON, ARMOR, ACCESSORY |
| STRATEGIST (책사) | stat_intellect | MAGICAL | 3 (ranged) | -1 | WEAPON, ARMOR, ACCESSORY |
| COMMANDER (지휘관) | stat_command + stat_might | PHYSICAL | 1 (melee) | +0 | WEAPON, ARMOR, ACCESSORY |
| SCOUT (척후) | stat_agility + stat_might | PHYSICAL | 1 (melee) | +1 | WEAPON, ARMOR, ACCESSORY |

**Rule CR-1a.** Attack type determines which defense stat is targeted:
PHYSICAL attacks target the defender's `phys_def`. MAGICAL attacks target
the defender's `mag_def`. This gives the STRATEGIST a unique role — their
damage bypasses infantry's high physical defense.

**Rule CR-1b.** `effective_move_range = clamp(hero_move_range + class_move_delta, MOVE_RANGE_MIN, MOVE_RANGE_MAX)`. Move delta is clamped within [2, 6] bounds.

**Rule CR-1c.** All stat derivation formulas (ATK, DEF, HP, Initiative) are
specified in the Formulas section. CR-1 defines which stats each class uses;
Formulas defines the exact expressions.

---

#### CR-2. Class Passive Traits

Each class has exactly one passive. Passives are always active (no cost, no
trigger condition unless stated). They are tags read by Damage/Combat Calc.

| Class | Passive | Tag | Effect |
|---|---|---|---|
| CAVALRY | Charge (돌격) | `passive_charge` | First attack of a turn, if the unit moved ≥4 budget before attacking: +20% bonus damage. Requires the unit initiated combat (not counter-attack). |
| INFANTRY | Shield Wall (방패진) | `passive_shield_wall` | When attacked by PHYSICAL damage, reduce incoming damage by flat 5 (after percentage reductions). Does not apply to MAGICAL attacks. |
| ARCHER | High Ground Shot (원사) | `passive_high_ground_shot` | Ignores the elevation attack penalty when at lower elevation than the target (delta_elevation < 0). Still benefits from positive elevation bonuses. Does not bypass evasion. |
| STRATEGIST | Tactical Read (전술안) | `passive_tactical_read` | **Combat facet** (this GDD): skills used by this unit ignore the target's terrain evasion bonus (terrain evasion treated as 0); agility-derived evasion is unaffected. **UI facet** (`design/gdd/grid-battle.md` CR-14 v5.0): combat-forecast visibility extends by `tactical_read_extension_tiles = 1` beyond natural attack range — the Strategist sees counter-forecast for targets one tile outside its current attack range. Both facets belong to the same class-level passive; the registry constant `tactical_read_extension_tiles` is owned here. Commander no longer shares either facet post-grid-battle.md v5.0. |
| COMMANDER | Rally (독전) | `passive_rally` | Adjacent allied units (Manhattan distance ≤ 1) receive +5% ATK bonus (orthogonal adjacency only — 4 cardinal directions; diagonals excluded). Continuous while the Commander is alive and on the grid (no action cost). Stacks additively from multiple Commanders: `rally_bonus = min(0.10, N_adjacent_alive_commanders × 0.05)`. Cap: +10% (2 Commanders adjacent — rev 2.8 reduced from +15%/3 Commanders per damage-calc rev 2.8 ceiling-collision fix). Full mechanical specification: `design/gdd/grid-battle.md` CR-15 (v5.0 pass-11b + rev 2.8 cap update). *(v5.0 pass-11b upgrade: Rally promoted from shorthand passive prose to fully specified Grid Battle CR. The v5.1 upgrade gate for Rally is removed — CR-15 is the v5.0 canonical spec. This row now summarises; CR-15 governs in all conflict cases.)* |
| SCOUT | Ambush (기습) | `passive_ambush` | When attacking a unit that has not yet acted this turn: +15% bonus damage AND target cannot counter-attack. Does not apply on turn 1. |

**Rule CR-2a.** Scout's ambush is resolved by checking Turn Order's
acted-this-turn flag. Target acted = false → ambush conditions met.

---

#### CR-3. Tactical Identity

| Class | Tactical Identity |
|---|---|
| CAVALRY | Flanking weapon. High attack, highest mobility on open ground. Charge passive rewards aggressive repositioning. Terrain-dependent: forests and mountains nullify speed advantage, exposing thin defense. Best as a closing force after infantry holds the line. |
| INFANTRY | Formation spine. Balanced attack, highest defense and HP, Shield Wall absorbs physical hits. Terrain-efficient — pays no premium on rough ground. The class that makes every other class viable by holding space. |
| ARCHER | Positional power projection. Range 3 keeps them safe; High Ground Shot removes the usual low-ground penalty. Dominates from elevation but crumbles when reached in melee. |
| STRATEGIST | Battlefield reshaper. MAGICAL attack bypasses infantry's Shield Wall (targets mag_def, not phys_def). Tactical Read ignores terrain evasion. Lowest HP — losing the backline loses the battle. |
| COMMANDER | Force multiplier. Below-average personal damage, but Rally makes every adjacent ally hit harder. Removing the commander collapses the formation's damage output. High-value assassination target. |
| SCOUT | Tempo disruptor. Highest initiative (acts first), Ambush denies counter-attacks from surprised targets. Low durability — if the scout strikes second, the advantage evaporates. |

---

#### CR-4. Terrain Movement Cost Multiplier Table

Effective tile cost = `floor(base_terrain_cost × class_multiplier)`. Deducted
from `move_budget = effective_move_range × 10`.

| Class | ROAD (7) | PLAINS (10) | HILLS (15) | FOREST (15) | MOUNTAIN (20) | BRIDGE (10) |
|---|---|---|---|---|---|---|
| CAVALRY | ×1.0 → 7 | ×1.0 → 10 | ×1.5 → 22 | ×2.0 → 30 | ×3.0 → 60 | ×1.0 → 10 |
| INFANTRY | ×1.0 → 7 | ×1.0 → 10 | ×1.0 → 15 | ×1.0 → 15 | ×1.5 → 30 | ×1.0 → 10 |
| ARCHER | ×1.0 → 7 | ×1.0 → 10 | ×1.0 → 15 | ×1.0 → 15 | ×2.0 → 40 | ×1.0 → 10 |
| STRATEGIST | ×1.0 → 7 | ×1.0 → 10 | ×1.5 → 22 | ×1.5 → 22 | ×2.0 → 40 | ×1.0 → 10 |
| COMMANDER | ×1.0 → 7 | ×1.0 → 10 | ×1.0 → 15 | ×1.5 → 22 | ×2.0 → 40 | ×1.0 → 10 |
| SCOUT | ×1.0 → 7 | ×1.0 → 10 | ×1.0 → 15 | ×0.7 → 10 | ×1.5 → 30 | ×1.0 → 10 |

**Rule CR-4a.** RIVER tiles remain impassable for all classes. FORTRESS_WALL
is impassable to enemies until destroyed (garrison model per Terrain Effect EC-2).

**Rule CR-4b.** Multiplied costs are floored before deducting from move_budget.

**Rule CR-4c.** No partial tile entry — if effective cost exceeds remaining
budget, the unit cannot enter.

**Design rationale:**
- CAVALRY on MOUNTAIN (×3.0 → 60): Move-range-4 cavalry (budget=50 with +1 delta)
  cannot enter at all. Intentional — cavalry is useless in mountain passes.
- SCOUT in FOREST (×0.7 → 10): Same cost as plains. Scouts traverse forest
  freely — this is their defining terrain advantage.
- INFANTRY everywhere ×1.0 except MOUNTAIN (×1.5): Terrain does not punish
  infantry. Their trade-off is speed, not friction.

---

#### CR-5. Skill Slot Rules

**Rule CR-5a.** All classes have 2 active skill slots for MVP.

**Rule CR-5b.** Slot 1 (Innate): Reserved for `innate_skill_ids[0]` from Hero DB.
Cannot be changed by the player — hero-specific.

**Rule CR-5c.** Slot 2 (Class Pool): Accepts any skill from the class's skill pool
(`assets/data/skills/class_pools.json`, 3–5 skills per class for MVP). Player
selects before battle on the Battle Preparation screen.

**Rule CR-5d.** If a hero has no innate skill (`innate_skill_ids = []`), Slot 1
becomes a second Class Pool slot — player may equip class pool skills in both.

**Rule CR-5e.** Passives (CR-2) are not skill slots. Always active, not removable.

---

#### CR-6. Attack Direction Interaction

Base direction multipliers (applied before terrain defense):

| Direction | Base Multiplier |
|---|---|
| FRONT | ×1.0 |
| FLANK | ×1.2 |
| REAR | ×1.5 |

**Rule CR-6a. Class direction modifiers** (multiplicative on top of base):

| Class | FRONT | FLANK | REAR | Notes |
|---|---|---|---|---|
| CAVALRY | ×1.0 | ×1.1 | ×1.09 | Charge passive is separate from direction. REAR reduced ×1.20 → ×1.09 per `damage-calc.md` rev 2.8 Rally-ceiling fix: at prior ×1.20 with CHARGE_BONUS=1.20 and Rally cap +15%, Cavalry REAR+Charge+Rally max = `floori(83 × 1.80 × 1.38) = 206` → DAMAGE_CEILING=180 fires, collapsing Pillar-1+3 hierarchies. Reduced to ×1.09 (D_mult=1.64) in coordination with Rally cap 15%→10% keeps all 12 apex cells <180 with Pillar-1 differentiation 27-30pt preserved. (Ratified 2026-04-20 ninth-pass cross-doc desync audit — BLK-G-2.) |
| INFANTRY | ×0.9 | ×1.0 | ×1.1 | Shield Wall applies on defense, all directions. Mild gradient preserves tank identity while keeping Pillar 1 positional payoff legible per `damage-calc.md` §F-DC-4 Infantry asymmetry rationale. |
| ARCHER | ×1.0 | ×1.375 | ×0.9 | Role-identity asymmetry (ratified 2026-04-19 per `damage-calc.md` rev 2.6 BLK-7-9/10; prior rev 2.5 value 1.15 was arithmetically-true-but-experientially-inert at base=83, producing a 2-point FLANK-vs-REAR spread that was indistinguishable from combat noise, and also locked Archer out of the HIT_DEVASTATING tier entirely). Drawn-bow release window is most stable at mid-range flank arcs (+37.5% FLANK is the largest class-mod bonus in the matrix, expressing Archer's identity as the **FLANK-dedicated damage specialist**); close-quarters rear shots face weapon-handling disadvantage as the drawn bow cannot pivot fast (−10% REAR). FLANK class-mod of 1.375 combined with BASE_DIRECTION_MULT[FLANK]=1.20 yields FLANK `D_mult=1.65` — matches Scout REAR / Infantry REAR numerical anchor but via distinct spatial position, reaches HIT_DEVASTATING tier (D_mult > 1.50), and at max ATK=200/DEF=10/BASE=83 produces Archer FLANK+Ambush=157 (vs Infantry REAR no-passive=136, satisfying Pillar-3 dedicated-damage-role > tank-role promise). No Terrain Effect LoS field consulted — pure role expression. |
| STRATEGIST | ×1.0 | ×1.0 | ×1.0 | — |
| COMMANDER | ×1.0 | ×1.0 | ×1.0 | Rally is the contribution |
| SCOUT | ×1.0 | ×1.0 | ×1.1 | Stacks with Ambush if conditions met |

**Rule CR-6b.** Combined example — Scout REAR attack on unacted target:
`base_atk × 1.5 × 1.1 × 1.15 = base_atk × 1.897`

---

### States and Transitions

The Unit Role System is primarily a **stateless rule definition layer**. It
provides formulas and data that other systems apply.

The one state this system owns is the **equip state of Slot 2 (Class Pool):**

| State | Condition |
|---|---|
| SLOT_EMPTY | No skill equipped in Slot 2 |
| SLOT_EQUIPPED | Player selected a class pool skill |

Transition: SLOT_EMPTY ↔ SLOT_EQUIPPED on player selection during Battle
Preparation. Once battle begins, skill assignments are read-only.

---

### Interactions with Other Systems

#### Upstream (reads from)

| System | Data Read |
|---|---|
| Hero DB | `default_class`, `stat_*`, `base_hp_seed`, `base_initiative_seed`, `move_range`, `innate_skill_ids` |
| Balance/Data | `unit_roles.json` (class definitions), `balance_constants.json` |
| Map/Grid | `terrain_type` per tile (for movement cost resolution) |

#### Downstream (provides to)

| Consumer | Data Provided |
|---|---|
| Damage/Combat Calc | `atk`, `phys_def`, `mag_def`, attack_type, passive tags, direction multipliers |
| HP/Status | `max_hp` |
| Turn Order | `initiative` |
| Grid Battle | `effective_move_range`, terrain cost table |
| AI System | Class passive tags, attack range, cost table |
| Battle Preparation | Class pool skills for Slot 2 |
| Formation Bonus | Commander `passive_rally` range and effect |
| Equipment/Item | Slot configuration (uniform 3 slots) |

## Formulas

All formulas use values from `assets/data/config/unit_roles.json` (per-class
coefficients) and the `BalanceConstants` singleton (global caps and scaling
factors — backed by `assets/data/balance/balance_entities.json` per ADR-0006,
accessor `BalanceConstants.get_const(key) -> Variant`). No formula is hardcoded
— every coefficient and cap is data-driven.

> **Note (2026-04-28, ADR-0009 sync)**: References below to
> `balance_constants.json` reflect this GDD's pre-ADR-0006 authoring
> (rev 2026-04-16). At runtime, every such reference resolves to
> `BalanceConstants.get_const(KEY)`. The Source column in the Global
> Constant Summary table (below) lists the canonical accessor; legacy
> `balance_constants.json` mentions in §Tuning Knobs and per-formula
> tables remain as-is for traceability against the original design intent.

---

### F-1. Attack Power (ATK)

```
atk = clamp(
  floor((primary_stat × w_primary + secondary_stat × w_secondary) × class_atk_mult),
  1,
  ATK_CAP
)
```

| Variable | Source | Description |
|---|---|---|
| `primary_stat` | Hero DB `stat_*` | Primary stat for this class (see CR-1) |
| `secondary_stat` | Hero DB `stat_*` | Secondary stat, if any (0 for single-stat classes) |
| `w_primary` | `unit_roles.json` | Weight for primary stat |
| `w_secondary` | `unit_roles.json` | Weight for secondary stat |
| `class_atk_mult` | `unit_roles.json` | Class-specific ATK scaling multiplier |
| `ATK_CAP` | `balance_constants.json` | Hard cap on ATK. Default: **200** |

**Class coefficient table (default values):**

| Class | primary_stat | w_primary | secondary_stat | w_secondary | class_atk_mult |
|---|---|---|---|---|---|
| CAVALRY | stat_might | 1.0 | — | 0.0 | 1.1 |
| INFANTRY | stat_might | 1.0 | — | 0.0 | 0.9 |
| ARCHER | stat_might | 0.6 | stat_agility | 0.4 | 1.0 |
| STRATEGIST | stat_intellect | 1.0 | — | 0.0 | 1.0 |
| COMMANDER | stat_command | 0.7 | stat_might | 0.3 | 0.8 |
| SCOUT | stat_agility | 0.6 | stat_might | 0.4 | 1.05 |

**Example:** Cavalry with stat_might=75:
`atk = clamp(floor((75 × 1.0 + 0) × 1.1), 1, 200) = clamp(floor(82.5), 1, 200) = 82`

---

### F-2. Defense (phys_def, mag_def)

Defense is split into two values. PHYSICAL attacks target `phys_def`; MAGICAL
attacks target `mag_def` (see CR-1a).

**Base derivation (before class multiplier):**

```
phys_def_base = floor(stat_might × 0.3 + stat_command × 0.7)
mag_def_base  = floor(stat_intellect × 0.7 + stat_command × 0.3)
```

**Final values:**

```
phys_def = clamp(floor(phys_def_base × class_phys_def_mult), 1, DEF_CAP)
mag_def  = clamp(floor(mag_def_base × class_mag_def_mult), 1, DEF_CAP)
```

| Variable | Source | Description |
|---|---|---|
| `stat_might`, `stat_command`, `stat_intellect` | Hero DB | Base stats |
| `class_phys_def_mult` | `unit_roles.json` | Class physical defense multiplier |
| `class_mag_def_mult` | `unit_roles.json` | Class magical defense multiplier |
| `DEF_CAP` | `balance_constants.json` | Hard cap on each defense stat. Default: **100** |

**Class defense multiplier table:**

| Class | class_phys_def_mult | class_mag_def_mult |
|---|---|---|
| CAVALRY | 0.8 | 0.7 |
| INFANTRY | 1.3 | 0.8 |
| ARCHER | 0.7 | 0.9 |
| STRATEGIST | 0.5 | 1.2 |
| COMMANDER | 1.0 | 1.0 |
| SCOUT | 0.6 | 0.6 |

**Example:** Infantry with stat_might=60, stat_command=50, stat_intellect=30:
- `phys_def_base = floor(60 × 0.3 + 50 × 0.7) = floor(18 + 35) = 53`
- `phys_def = clamp(floor(53 × 1.3), 1, 100) = clamp(68, 1, 100) = 68`
- `mag_def_base = floor(30 × 0.7 + 50 × 0.3) = floor(21 + 15) = 36`
- `mag_def = clamp(floor(36 × 0.8), 1, 100) = clamp(28, 1, 100) = 28`

Infantry's high phys_def (68) vs. low mag_def (28) shows why STRATEGIST's
MAGICAL attacks bypass the frontline's physical wall.

---

### F-3. Hit Points (max_hp)

```
max_hp = clamp(
  floor(base_hp_seed × class_hp_mult × HP_SCALE) + HP_FLOOR,
  HP_FLOOR,
  HP_CAP
)
```

| Variable | Source | Description |
|---|---|---|
| `base_hp_seed` | Hero DB | Per-hero HP seed (1–100) |
| `class_hp_mult` | `unit_roles.json` | Class HP scaling multiplier |
| `HP_SCALE` | `balance_constants.json` | Global HP scaling. Default: **2.0** |
| `HP_FLOOR` | `balance_constants.json` | Minimum HP any unit can have. Default: **50** |
| `HP_CAP` | `balance_constants.json` | Maximum HP. Default: **300** |

**Class HP multiplier table:**

| Class | class_hp_mult |
|---|---|
| CAVALRY | 0.9 |
| INFANTRY | 1.3 |
| ARCHER | 0.8 |
| STRATEGIST | 0.7 |
| COMMANDER | 1.1 |
| SCOUT | 0.75 |

**Example:** Infantry with base_hp_seed=70:
`max_hp = clamp(floor(70 × 1.3 × 2.0) + 50, 50, 300) = clamp(floor(182) + 50, 50, 300) = clamp(232, 50, 300) = 232`

**Example:** Strategist with base_hp_seed=40:
`max_hp = clamp(floor(40 × 0.7 × 2.0) + 50, 50, 300) = clamp(floor(56) + 50, 50, 300) = clamp(106, 50, 300) = 106`

Infantry (232 HP) vs. Strategist (106 HP) — over 2× survivability difference.

---

### F-4. Initiative

```
initiative = clamp(
  floor(base_initiative_seed × class_init_mult × INIT_SCALE),
  1,
  INIT_CAP
)
```

| Variable | Source | Description |
|---|---|---|
| `base_initiative_seed` | Hero DB | Per-hero initiative seed (1–100) |
| `class_init_mult` | `unit_roles.json` | Class initiative multiplier |
| `INIT_SCALE` | `balance_constants.json` | Global initiative scaling. Default: **2.0** |
| `INIT_CAP` | `balance_constants.json` | Initiative hard cap. Default: **200** |

**Class initiative multiplier table:**

| Class | class_init_mult |
|---|---|
| CAVALRY | 0.9 |
| INFANTRY | 0.7 |
| ARCHER | 0.85 |
| STRATEGIST | 0.8 |
| COMMANDER | 0.75 |
| SCOUT | 1.2 |

**Example:** Scout with base_initiative_seed=80:
`initiative = clamp(floor(80 × 1.2 × 2.0), 1, 200) = clamp(floor(192), 1, 200) = 192`

Scout's 1.2 multiplier ensures they act first most turns — essential for
Ambush passive.

---

### F-5. Effective Move Range

```
effective_move_range = clamp(hero_move_range + class_move_delta, MOVE_RANGE_MIN, MOVE_RANGE_MAX)
move_budget = effective_move_range × 10
```

| Variable | Source | Description |
|---|---|---|
| `hero_move_range` | Hero DB `move_range` | Per-hero base move range (2–6) |
| `class_move_delta` | `unit_roles.json` | Class move adjustment |
| `MOVE_RANGE_MIN` | `balance_constants.json` | Minimum move range. Default: **2** |
| `MOVE_RANGE_MAX` | `balance_constants.json` | Maximum move range. Default: **6** |

**Class move delta table:** (repeated from CR-1b for formula completeness)

| Class | class_move_delta |
|---|---|
| CAVALRY | +1 |
| INFANTRY | +0 |
| ARCHER | +0 |
| STRATEGIST | -1 |
| COMMANDER | +0 |
| SCOUT | +1 |

**Example:** Cavalry with hero_move_range=4:
`effective_move_range = clamp(4 + 1, 2, 6) = 5; move_budget = 50`

**Example:** Strategist with hero_move_range=3:
`effective_move_range = clamp(3 + (-1), 2, 6) = 2; move_budget = 20`

---

### Global Constant Summary

| Constant | Default | Source | Notes |
|---|---|---|---|
| ATK_CAP | 200 | `BalanceConstants.get_const("ATK_CAP")` (ADR-0006) | Theoretical max; in practice ≤ ~110 |
| DEF_CAP | 100 | `BalanceConstants.get_const("DEF_CAP")` (ADR-0006) | Per-defense-type cap |
| HP_CAP | 300 | `BalanceConstants.get_const("HP_CAP")` (ADR-0006) | Absolute ceiling |
| HP_SCALE | 2.0 | `BalanceConstants.get_const("HP_SCALE")` (ADR-0006) | Amplifies HP seed differences |
| HP_FLOOR | 50 | `BalanceConstants.get_const("HP_FLOOR")` (ADR-0006) | No unit below 50 HP |
| INIT_CAP | 200 | `BalanceConstants.get_const("INIT_CAP")` (ADR-0006) | Theoretical max |
| INIT_SCALE | 2.0 | `BalanceConstants.get_const("INIT_SCALE")` (ADR-0006) | Amplifies initiative seed differences |
| MOVE_RANGE_MIN | 2 | `BalanceConstants.get_const("MOVE_RANGE_MIN")` (ADR-0006) | Already registered in entities.yaml |
| MOVE_RANGE_MAX | 6 | `BalanceConstants.get_const("MOVE_RANGE_MAX")` (ADR-0006) | Already registered in entities.yaml |
| MOVE_BUDGET_PER_RANGE | 10 | `BalanceConstants.get_const("MOVE_BUDGET_PER_RANGE")` (ADR-0006, ADR-0009 §Migration Plan) | Move budget = effective_move_range × this constant. Cross-doc obligation per ADR-0009 §Migration Plan §4 — appended to balance_entities.json on ADR-0009 Acceptance |

## Edge Cases

### Movement Edge Cases

**EC-1. Strategist Move Range Floor**
A Strategist with `hero_move_range=2` (Hero DB minimum): `clamp(2 + (-1), 2, 6) = 2`.
The class delta (-1) is absorbed by the clamp. The Strategist's minimum playable
budget is **20**, not 10. The clamp prevents sub-2 effective ranges.

**EC-2. Cavalry Move Range Cap Absorption**
A Cavalry hero with `hero_move_range=6` (Hero DB maximum): `clamp(6 + 1, 2, 6) = 6`.
The +1 delta is wasted. Budget remains 60, identical to a Cavalry hero with
`hero_move_range=5`. Cavalry's advantage comes from low terrain multipliers on
open ground, not uncapped range. Data authors: giving Cavalry `move_range=6`
gains no movement advantage from the class.

**EC-3. Cavalry Cannot Enter Mountain (budget=50)**
Cavalry with `effective_move_range=5` has `move_budget=50`. Mountain effective
cost = `floor(20 × 3.0) = 60`. Since 60 > 50, the unit cannot enter any Mountain
tile. CR-4c (no partial tile entry) blocks the path at the first Mountain tile.
This is intentional — cavalry is useless in mountain passes (CR-4 rationale).

**EC-4. Cavalry CAN Enter One Mountain (budget=60, path-order dependent)**
Cavalry with `effective_move_range=6` has `move_budget=60`. Mountain cost = 60.
The unit can enter exactly one Mountain tile **only if** zero budget has been
spent on prior tiles (i.e., the Mountain is the first tile in the path). Any
prior movement (even Road at cost 7) reduces available budget below 60.
Implementation must compare `remaining_budget >= tile_cost`, not
`total_budget >= tile_cost`.

**EC-5. Scout Forest Cost — Floor is Load-Bearing**
Scout in Forest: `floor(15 × 0.7) = floor(10.5) = 10`, matching Plains cost.
The CR-4b floor operation is not a rounding artifact — it is the mechanism that
delivers Scout's defining terrain advantage. Without `floor()`, the cost would
be 10.5, which the integer budget system cannot represent.

---

### Passive & Combat Edge Cases

**EC-6. Charge Budget Threshold Definition**
"Moved ≥4 budget" means `accumulated_move_cost_this_turn >= 40` (using the ×10
budget scale from F-5). Examples:
- Unit did not move (cost=0): **does not trigger**.
- Unit moved 3 Plains tiles (cost=30): **does not trigger**.
- Unit moved 4 Plains tiles (cost=40): **triggers**.
- Unit moved 1 Hills + 2 Plains (cost=35): **does not trigger**.
Counter-attacks never trigger Charge (CR-2 explicitly requires initiated combat).

**EC-7. Cavalry Charge + Direction — Multiplication Order**
All damage multipliers are multiplicative, consistent with CR-6b's Scout example.
Cavalry REAR attack with Charge active (rev 2.8 values):
`base_atk × 1.5 (base REAR) × 1.09 (class REAR) × 1.2 (Charge) ≈ base_atk × 1.96`
Charge is **not** additive on the final value. If it were additive, the result
would be `base_atk × 1.79` — a meaningfully different number (17% divergence).
The multiplicative interpretation is authoritative.

> **Ratified 2026-04-18** by `design/gdd/damage-calc.md` §D F-DC-5 + F-DC-6:
> `P_mult = snappedf(charge_factor × ambush_factor, 0.01)` then
> `raw = clamp(floori(base × D_mult × P_mult), 1, DAMAGE_CEILING)`. EC-7 is
> the non-negotiable ordering input to damage-calc OQ-DC-7 (two-stage cap).
> `CHARGE_BONUS=1.20` is now registered in `design/registry/entities.yaml` v2
> with `source: damage-calc.md` and `referenced_by: unit-role.md`.

**EC-8. Ambush Turn 1 Gate**
Ambush does not apply on turn 1 (CR-2). The full gate condition is:
`(current_turn_number >= 2) AND (target.acted_this_turn == false)`.
On turn 1, the `acted_this_turn` flag is irrelevant — Ambush is suppressed
regardless. Turn Order must maintain a `current_turn_number` counter.

**EC-9. Scout Attacks Already-Acted Target — Full Ambush Failure**
When `target.acted_this_turn == true`, **no** component of Ambush applies — neither
the +15% damage bonus nor the counter-attack suppression. Both effects are
all-or-nothing on the same condition. The target counter-attacks normally. This
is the "Scout strikes second, the advantage evaporates" scenario (CR-3).

**EC-10. Mutual Ambush (Scout vs. Scout)**
Scout A attacks Scout B; neither has acted. Scout A's Ambush fires: +15% damage,
Scout B cannot counter-attack. Scout B's `passive_ambush` is irrelevant to this
exchange — B is the defender, not the initiator. Passive resolution is
**attacker-centric**: the initiating unit's passives govern the attack; the
defender's offensive passives do not activate during a counter-attack.

**EC-11. Shield Wall vs. MAGICAL Damage**
When `attack_type == MAGICAL`, Shield Wall's flat -5 reduction is skipped entirely.
Do not apply 0; do not apply a partial amount — skip the Shield Wall check. The
MAGICAL attack targets `mag_def` (Infantry's weakest defense by design). This is
the explicit Strategist counter-synergy described in CR-3.

**EC-12. Rally Stacking Cap with 2+ Commanders (rev 2.8 — damage-calc Rally-ceiling fix)**
Rally bonus = `min(10, N_adjacent_commanders × 5)%` where `N_adjacent_commanders`
is the count of living Commanders within Manhattan distance ≤ 1 of the **affected
unit** (not relative to each other). **Two** adjacent Commanders = 10% (cap hit).
Three+ Commanders = still 10%. A Commander at distance 2 from the affected unit does not
contribute, even if adjacent to another Commander. Cap reduced from prior +15% per
damage-calc.md eighth-pass review BLK-8-1 (at +15% Rally, Cavalry REAR+Charge max ATK
hit DAMAGE_CEILING=180 collapsing Pillar-1+3 hierarchies; +10% cap preserves them).
Authoritative cross-ref: `design/gdd/grid-battle.md` CR-15 rule 4.

---

### Stat & Formula Edge Cases

**EC-13. phys_def Reaching DEF_CAP**
Infantry with `stat_might=100, stat_command=100`:
`phys_def_base = floor(100 × 0.3 + 100 × 0.7) = 100`
`phys_def = clamp(floor(100 × 1.3), 1, 100) = clamp(130, 1, 100) = 100`
DEF_CAP is reachable in theory but practically impossible — Hero DB stat balance
rules (stat_total 180–280, SPI ≥ 0.5) prevent both stats hitting 100. The clamp
is the correct resolution. `phys_def` and `mag_def` are each clamped to DEF_CAP
independently.

**EC-14. HP Floor — Minimum max_hp is 51, Not 50**
Strategist with `base_hp_seed=1`:
`max_hp = clamp(floor(1 × 0.7 × 2.0) + 50, 50, 300) = clamp(1 + 50, 50, 300) = 51`
Because HP_FLOOR is additive (inside the expression), the minimum possible
`max_hp` is `HP_FLOOR + 1 = 51` (for seed=1 with Scout or Strategist class mult).
No unit can have exactly `max_hp = 50`.

**EC-15. Tactical Read on Zero-Evasion Terrain**
Strategist uses a skill against a target on PLAINS (terrain evasion = 0%).
Tactical Read treats terrain evasion as 0 — this is a no-op. The passive is
only meaningful against FOREST (15%) or MOUNTAIN (5%). Critically, Tactical Read
does **not** affect agility-derived evasion (CR-2). On FOREST:
`total_evasion = clamp(0 + agility_eva + other_eva, 0, 30)` — only the terrain
component is zeroed.

---

### Skill & Equipment Edge Cases

**EC-16. Duplicate Skill Selection Prohibited (CR-5d)**
When a hero has `innate_skill_ids = []`, both Slot 1 and Slot 2 become Class Pool
slots. The player **may not** equip the same skill in both slots. Each slot must
hold a distinct skill ID. Battle Preparation UI must validate: if a skill is
already equipped in one slot, it is grayed out / unselectable for the other.

**EC-17. Equipment Slot Override Supersedes Class Default**
When `equipment_slot_override != null` in Hero DB, the Equipment/Item system uses
the override array verbatim — the Unit Role 3-slot default (WEAPON, ARMOR,
ACCESSORY) is ignored. A hero with `equipment_slot_override: [WEAPON, MOUNT]` has
2 slots, not 3. The Unit Role system does not validate or reject overrides;
ownership belongs to Hero DB (definition) and Equipment/Item (enforcement). The
class profile table's slot column is the default only.

## Dependencies

### Upstream Dependencies (reads from)

| System | Data Read | GDD Status |
|---|---|---|
| **Hero Database** | `default_class`, `stat_might`, `stat_intellect`, `stat_command`, `stat_agility`, `base_hp_seed`, `base_initiative_seed`, `move_range`, `innate_skill_ids`, `equipment_slot_override` | Designed |
| **Balance/Data System** | `unit_roles.json` (per-class coefficients, multipliers, passive_tag, terrain_cost_table, class_direction_mult); `BalanceConstants.get_const(...)` per ADR-0006 (ATK_CAP, DEF_CAP, HP_CAP, HP_SCALE, HP_FLOOR, INIT_CAP, INIT_SCALE, MOVE_RANGE_MIN, MOVE_RANGE_MAX, MOVE_BUDGET_PER_RANGE — backed by `assets/data/balance/balance_entities.json`); `class_pools.json` (per-class skill pool, CR-5c) | ADR-0006 Accepted, ADR-0009 Proposed |
| **Map/Grid System** | `terrain_type` per tile (for movement cost resolution via CR-4 table) | Designed |

**All three upstream GDDs are designed.** No provisional assumptions required.

### Downstream Dependencies (provides to)

| Consumer | Data Provided | GDD Status |
|---|---|---|
| **Damage/Combat Calculation** | `atk` (F-1), `phys_def` / `mag_def` (F-2), `attack_type` (CR-1a), passive tags (CR-2), direction multipliers (CR-6) | Not Started |
| **HP/Status System** | `max_hp` (F-3) | Not Started |
| **Turn Order/Action Management** | `initiative` (F-4), passive tags for `acted_this_turn` checks (EC-8, EC-9) | Not Started |
| **Grid Battle System** | `effective_move_range` (F-5), terrain cost multiplier table (CR-4), attack range (CR-1) | Not Started |
| **AI System** | Class passive tags, attack range, terrain cost table, tactical identity heuristics (CR-3) | Not Started |
| **Battle Preparation System** | Class pool skills for Slot 2 (CR-5c), Slot 1/2 assignment rules (CR-5a–5d) | Not Started |
| **Formation Bonus System** | Commander `passive_rally` range, effect, and stacking cap (CR-2, EC-12) | Not Started |
| **Equipment/Item System** | Default slot configuration (CR-1: WEAPON, ARMOR, ACCESSORY), override authority (EC-17) | Not Started |

### Interface Contracts

**Contract 1: Hero DB → Unit Role** (reads at battle initialization)
- Unit Role receives a `Hero` record and reads `default_class` to select the class profile
- All `stat_*` fields are guaranteed in [1, 100] by Hero DB validation rules
- `base_hp_seed` and `base_initiative_seed` guaranteed in [1, 100]
- `move_range` guaranteed in [2, 6]
- `innate_skill_ids` may be empty array (`[]`) — handled by CR-5d

**Contract 2: Unit Role → Damage Calc** (provides per-attack)
- `atk`: integer [1, 200]
- `phys_def`, `mag_def`: integer [1, 100] each
- `attack_type`: enum {PHYSICAL, MAGICAL}
- `passive_tags`: set of strings (e.g., `passive_charge`, `passive_shield_wall`)
- `direction_multiplier`: float, product of base direction × class direction modifier

**Contract 3: Unit Role → Grid Battle** (provides per-unit per-turn)
- `effective_move_range`: integer [2, 6]
- `move_budget`: integer [20, 60]
- `terrain_cost_table`: 6-entry dict mapping terrain_type → float multiplier
- `attack_range`: integer {1, 3}

## Tuning Knobs

Every value below lives in `assets/data/config/unit_roles.json` or
`assets/data/config/balance_constants.json`. No tuning knob is hardcoded.

---

### TK-1. ATK Formula Weights (`w_primary`, `w_secondary`)

| Knob | Default | Safe Range | Affects |
|---|---|---|---|
| `w_primary` | 0.6–1.0 (per class) | 0.4–1.2 | How much the primary stat dominates ATK |
| `w_secondary` | 0.0–0.4 (per class) | 0.0–0.6 | Contribution of secondary stat to ATK |

**Tuning guideline:** `w_primary + w_secondary` should stay in [0.8, 1.4]. Below
0.8 makes ATK feel unresponsive to stats; above 1.4 inflates ATK beyond DEF
scaling, breaking combat math.

### TK-2. Class ATK Multiplier (`class_atk_mult`)

| Knob | Default Range | Safe Range | Affects |
|---|---|---|---|
| `class_atk_mult` | 0.8–1.1 | 0.6–1.3 | Class-wide ATK scaling |

**Tuning guideline:** Infantry (0.9) and Commander (0.8) are intentionally low —
their value comes from durability and Rally. Pushing them above 1.0 undermines
class identity.

### TK-3. Class DEF Multipliers (`class_phys_def_mult`, `class_mag_def_mult`)

| Knob | Default Range | Safe Range | Affects |
|---|---|---|---|
| `class_phys_def_mult` | 0.5–1.3 | 0.3–1.5 | Physical survivability spread |
| `class_mag_def_mult` | 0.6–1.2 | 0.3–1.5 | Magical survivability spread |

**Tuning guideline:** The gap between Infantry phys_def_mult (1.3) and
Strategist phys_def_mult (0.5) is the core of the PHYSICAL/MAGICAL counter
triangle. Narrowing this gap below 0.5 difference weakens Strategist's role.

### TK-4. HP Scaling Constants (`HP_SCALE`, `HP_FLOOR`, `HP_CAP`)

| Knob | Default | Safe Range | Affects |
|---|---|---|---|
| `HP_SCALE` | 2.0 | 1.5–3.0 | How much HP spreads between classes |
| `HP_FLOOR` | 50 | 30–80 | Minimum survivability floor |
| `HP_CAP` | 300 | 200–500 | Maximum HP ceiling |

**Tuning guideline:** HP_SCALE × class_hp_mult determines the gap between
Infantry (tankiest) and Strategist (frailest). At 2.0, the gap is ~2.2×
(232 vs 106 in examples). Reducing HP_SCALE compresses this, making positional
play less important.

### TK-5. Initiative Scaling (`INIT_SCALE`, class_init_mult)

| Knob | Default | Safe Range | Affects |
|---|---|---|---|
| `INIT_SCALE` | 2.0 | 1.5–3.0 | Initiative value spread |
| `class_init_mult` (Scout) | 1.2 | 1.1–1.4 | How reliably Scout acts first |

**Tuning guideline:** Scout's Ambush depends on acting before targets. If
`class_init_mult` drops below 1.1, too many non-Scout units will occasionally
outspeed, making Ambush unreliable. Above 1.4, Scout always acts first regardless
of hero seed, removing per-hero differentiation.

### TK-6. Passive Effect Values

| Knob | Default | Safe Range | Affects |
|---|---|---|---|
| Charge bonus | +20% | 10%–30% | Cavalry alpha strike reward |
| Shield Wall flat reduction | 5 | 3–8 | Infantry physical tankiness |
| Rally ATK bonus | +5% per Commander | 3%–8% | Commander force multiplication |
| Rally cap | 10% (rev 2.8 — was 15%) | 5%–15% | Maximum stacking benefit; lowered to keep Cavalry REAR+Charge+Rally apex < DAMAGE_CEILING=180 per damage-calc rev 2.8 |
| Ambush bonus | +15% | 10%–25% | Scout first-strike reward |

**Tuning guideline:** Shield Wall's flat reduction is most impactful against
low-ATK attackers. At flat 8+, weak attackers deal negligible damage to Infantry,
which could make early-game combat feel unfair. At flat 3, the passive becomes
negligible in mid-game.

### TK-7. Terrain Cost Multipliers (per class)

| Knob | Default Range | Safe Range | Affects |
|---|---|---|---|
| Cavalry FOREST | ×2.0 | ×1.5–×3.0 | Cavalry forest penalty |
| Cavalry MOUNTAIN | ×3.0 | ×2.5–×4.0 | Cavalry mountain impassability threshold |
| Scout FOREST | ×0.7 | ×0.5–×1.0 | Scout forest advantage |

**Tuning guideline:** Cavalry MOUNTAIN at ×2.5 with budget=50 → cost=50
(barely passable). This fundamentally changes Cavalry's terrain weakness.
Adjust with extreme caution — CR-4 rationale treats ×3.0 as a hard design
decision, not a tuning suggestion. Scout FOREST at ×1.0 removes their terrain
identity entirely.

### TK-8. Direction Multipliers

| Knob | Default | Safe Range | Affects |
|---|---|---|---|
| Base FLANK | ×1.2 | ×1.1–×1.3 | Positioning reward for flanking |
| Base REAR | ×1.5 | ×1.3–×1.7 | Positioning reward for backstabbing |
| Cavalry class REAR | ×1.09 (rev 2.8 — was ×1.2) | ×1.0–×1.15 | Cavalry flanking specialization. Safe range narrowed per rev 2.8 Rally-ceiling fix: above ×1.15, Cavalry REAR+Charge+Rally(cap +10%) at max ATK activates DAMAGE_CEILING=180. |
| Scout class REAR | ×1.1 | ×1.0–×1.2 | Scout backstab bonus |

**Tuning guideline:** Base REAR × Cavalry class REAR × Charge = 1.5 × 1.09 × 1.20
= 1.96× at rev 2.8 defaults (was 2.16× at rev 2.7 pre Rally-ceiling fix;
`snappedf(1.5 × 1.09, 0.01) = 1.64` is the Cavalry REAR D_mult before passive).
Under rev 2.8 Rally cap +10% and rev 2.9 P_MULT_COMBINED_CAP=1.31, max combined
multiplier = 1.64 × 1.31 = 2.15× (annotated in V-2 damage popup). Above ×2.5 total,
a single Cavalry Charge can one-shot Strategists, which may be intended but must
be validated against HP ranges. **Do NOT raise Cavalry class REAR above ×1.15**
without re-running the apex arithmetic — doing so re-introduces the pre-rev-2.8
DAMAGE_CEILING activation bug.

### Summary: Tuning Priority Order

For initial balance passes, tune in this order:
1. **HP_SCALE + class_hp_mult** — sets survivability baseline
2. **class_atk_mult** — sets damage output baseline
3. **Passive effect values** — adjusts class identity sharpness
4. **DEF multipliers** — fine-tunes matchup spreads
5. **Terrain cost multipliers** — last, because these affect map design

## Visual/Audio Requirements

### Visual

**Class Silhouette Differentiation**
Each class must be instantly identifiable at grid zoom-out by silhouette alone,
before color or detail is visible. Requirements per art bible (먹선 ink-line
style):

| Class | Silhouette Key | Ink Weight |
|---|---|---|
| CAVALRY | Mounted figure, taller than 1-tile average | 중묵 (medium ink) — dynamic lines |
| INFANTRY | Shield + wide stance, widest silhouette | 농묵 (thick ink) — heavy, grounded lines |
| ARCHER | Tall/narrow with bow arc, vertical emphasis | 담묵 (light ink) — thin, precise lines |
| STRATEGIST | Fan or scroll in hand, robed, no weapon visible | 발묵 (splashed ink) — flowing, ethereal lines |
| COMMANDER | Banner or flag behind, tallest ground figure | 중묵 with gold accent on banner |
| SCOUT | Low/crouched, smallest ground silhouette | 담묵 — minimal, stealthy lines |

**Passive Effect Indicators**
- Charge: ink-trail motion lines behind Cavalry during movement (fade when move ends)
- Shield Wall: subtle ink-brush shield glow on hit (PHYSICAL only)
- High Ground Shot: elevation line connecting Archer to target (when passive activates)
- Tactical Read: ink ripple on target's terrain tile (when skill ignores evasion)
- Rally: ink-brush aura ring around Commander (Manhattan ≤ 1 radius visualization)
- Ambush: ink-shadow overlay on Scout sprite (when conditions met, before attack)

**Terrain Cost Feedback**
Movement range overlay must shade tiles by reachability:
- Reachable tiles: light ink wash fill
- Unreachable tiles (cost exceeds budget): no fill
- High-cost tiles within range: darker ink wash (proportional to cost fraction)

### Audio

**Class-Specific Movement SFX**
- CAVALRY: hoofbeats (tempo scales with remaining budget)
- INFANTRY: armored footsteps (heavy)
- ARCHER: light footsteps
- STRATEGIST: cloth rustle + light steps
- COMMANDER: armored footsteps + banner flutter
- SCOUT: near-silent steps (softest of all classes)

**Passive Trigger SFX**
Each passive activation gets a distinct audio cue:
- Charge: building percussion crescendo during qualifying movement
- Shield Wall: metallic impact dampening on hit
- High Ground Shot: bowstring pull with elevation echo
- Tactical Read: ink-brush sweep sound
- Rally: subtle war drum pulse (continuous while adjacent)
- Ambush: sharp silence break → strike accent

## UI Requirements

### Battle HUD — Class Information Display

**Unit Info Panel** (shown on unit selection):
- Class icon + class name (Korean + English)
- Current ATK / phys_def / mag_def / max_hp / initiative (derived values)
- Attack type indicator: 물리(PHYSICAL) or 마법(MAGICAL) with icon
- Attack range: numeric + visual indicator on grid
- Equipped skills: Slot 1 (innate icon, locked) + Slot 2 (class pool icon, selectable pre-battle)
- Passive name + tooltip with effect description

**Movement Overlay** (shown during move action):
- Reachable tiles highlighted per terrain cost table
- Per-tile cost displayed on hover/long-press (e.g., "15 → 30" for Cavalry in FOREST, showing base → effective)
- Remaining budget counter updating as path is drawn
- Path preview line with total cost

**Direction Indicator** (shown during attack targeting):
- Attacker-relative direction displayed: FRONT / FLANK / REAR
- Expected multiplier shown as damage modifier (e.g., "×1.5 REAR")
- Passive bonus preview if applicable (e.g., "+20% Charge")

### Battle Preparation Screen — Skill Selection

**Slot 2 Selection Panel**:
- Display 3–5 class pool skills with: name, cost, range, effect summary
- Innate skill (Slot 1) shown as locked/non-selectable with hero portrait
- If `innate_skill_ids = []`: both slots show as selectable with duplicate prevention (EC-16)
- Confirm button finalizes skill assignment (read-only once battle begins)

### Class Comparison View

**Pre-battle or roster screen**: Side-by-side class stat comparison:
- Radar chart or bar comparison: ATK / phys_def / mag_def / HP / Initiative / Move Range
- Terrain affinity summary: icons for favorable (green) / neutral / unfavorable (red) terrain
- Passive description with activation conditions

### Touch & Mouse Requirements

- All class info tooltips accessible via long-press (touch) and hover (mouse)
- Movement overlay tiles must meet 44px minimum touch target (per technical preferences)
- Direction indicator must be visible before attack confirmation
- Skill selection in Battle Preparation must support both tap and click

## Acceptance Criteria

### Stat Derivation (Formulas)

**AC-1.** Given a hero record from Hero DB with valid stats and a class assignment,
F-1 (ATK) produces an integer in [1, ATK_CAP=200]. Verified for all 6 classes with
min stats (all=1), max stats (all=100), and median stats (all=50).

**AC-2.** F-2 (DEF) produces `phys_def` and `mag_def` each in [1, DEF_CAP=100].
Infantry at max stats has the highest `phys_def`; Strategist at max stats has the
highest `mag_def`. The split is verifiable: PHYSICAL attacks use `phys_def`,
MAGICAL attacks use `mag_def` — never the wrong one.

**AC-3.** F-3 (HP) produces `max_hp` in [HP_FLOOR+1=51, HP_CAP=300]. No unit has
exactly 50 HP (EC-14). Infantry at `base_hp_seed=70` produces ~232 HP; Strategist
at `base_hp_seed=40` produces ~106 HP.

**AC-4.** F-4 (Initiative) produces values in [1, INIT_CAP=200]. Scout with
`base_initiative_seed=80` produces 192, higher than any other class with the
same seed.

**AC-5.** F-5 (Move Range) clamps to [MOVE_RANGE_MIN=2, MOVE_RANGE_MAX=6].
Strategist with `hero_move_range=2` produces effective_move_range=2, not 1 (EC-1).
Cavalry with `hero_move_range=6` produces 6, not 7 (EC-2).

### Class Passives

**AC-6.** Cavalry Charge triggers if and only if `accumulated_move_cost >= 40` AND
the unit initiated combat (not counter-attack). A unit that did not move (cost=0)
does not trigger Charge.

**AC-7.** Infantry Shield Wall reduces incoming PHYSICAL damage by flat 5. When
`attack_type == MAGICAL`, Shield Wall does not apply at all (EC-11).

**AC-8.** Archer High Ground Shot ignores elevation attack penalty when
`delta_elevation < 0`. Still benefits from positive elevation bonuses. Does not
bypass agility-derived evasion.

**AC-9.** Strategist Tactical Read sets terrain evasion to 0 for skill targets.
On zero-evasion terrain, the passive is a no-op (EC-15). Agility evasion is
unaffected.

**AC-10.** Commander Rally grants +5% ATK to allied units within Manhattan
distance ≤ 1. Stacking from multiple Commanders caps at 10% total (rev 2.8 — was 15%; EC-12).
A Commander at distance 2 does not contribute.

**AC-11.** Scout Ambush fires if `current_turn_number >= 2` AND
`target.acted_this_turn == false`. Grants +15% damage AND suppresses counter-attack.
Both effects are all-or-nothing (EC-9). Does not apply on turn 1 (EC-8).

### Terrain Movement

**AC-12.** Each class's terrain cost multiplier matches the CR-4 table exactly.
Effective tile cost = `floor(base_terrain_cost × class_multiplier)`.

**AC-13.** Cavalry with `move_budget=50` cannot enter MOUNTAIN tiles (cost=60).
Cavalry with `move_budget=60` can enter one MOUNTAIN tile only if it is the first
tile in the path (EC-3, EC-4).

**AC-14.** Scout FOREST cost = `floor(15 × 0.7) = 10`, equal to PLAINS. Scout
traverses forest with no penalty (EC-5).

**AC-15.** RIVER tiles are impassable for all classes. FORTRESS_WALL is impassable
to enemies (CR-4a).

### Attack Direction

**AC-16.** Base direction multipliers are FRONT ×1.0, FLANK ×1.2, REAR ×1.5.
Class modifiers multiply on top. Cavalry REAR + Charge = ×1.97 (rev 2.8 — was ×2.16 pre rev 2.8; CLASS_DIRECTION_MULT[CAVALRY][REAR] reduced 1.20 → 1.09 per damage-calc rev 2.8 Rally-ceiling fix; EC-7).

**AC-17.** Scout REAR + Ambush = `1.5 × 1.1 × 1.15 = 1.897×` (CR-6b). All
multipliers are multiplicative, not additive.

### Skill Slots

**AC-18.** All classes have exactly 2 active skill slots. Slot 1 is innate
(from Hero DB). Slot 2 accepts class pool skills. If `innate_skill_ids = []`,
both slots accept class pool skills with no duplicate selection (EC-16).

**AC-19.** Class pool contains 3–5 skills per class (from `class_pools.json`).
Skill assignment is read-only once battle begins.

### Data-Driven

**AC-20.** All class coefficients, multipliers, passive effect values, and caps
are loaded from `unit_roles.json` and `balance_constants.json`. No gameplay
value is hardcoded.

**AC-21.** Modifying a value in `unit_roles.json` (e.g., changing Cavalry
`class_atk_mult` from 1.1 to 1.0) takes effect on the next battle without
code changes.

### Cross-System Contracts

**AC-22.** Unit Role provides Damage Calc with: `atk` [1,200], `phys_def` [1,100],
`mag_def` [1,100], `attack_type` {PHYSICAL, MAGICAL}, passive tags (set of strings),
direction multiplier (float). Verified via integration test.

**AC-23.** Unit Role provides Grid Battle with: `effective_move_range` [2,6],
`move_budget` [20,60], terrain cost table (6 entries), `attack_range` {1, 3}.
Verified via integration test.

## Open Questions

**OQ-1. Charge Budget Threshold — Tile Count vs. Budget Scale?**
EC-6 defines "≥4 budget" as `accumulated_move_cost >= 40`. An alternative reading
is "moved ≥4 tiles regardless of cost." The budget-based interpretation rewards
moving through expensive terrain; the tile-based interpretation rewards any 4+
tile movement. **Decision needed before Damage Calc GDD.** Current resolution:
budget-based (40 cost units).

**OQ-2. Counter-Attack Mechanics — Owned by Which GDD?**
Ambush (EC-10) and Shield Wall (EC-11) both interact with counter-attack behavior,
but Unit Role does not define counter-attack rules. Counter-attack range, damage
formula, and trigger conditions are likely owned by **Damage/Combat Calculation**
(#10 in design order). Confirm ownership when designing Damage Calc.

> **RESOLVED 2026-04-18** — `design/gdd/damage-calc.md` §C CR-9 + §D F-DC-7
> confirms ownership: counter-attack is modeled as a second `resolve()` call
> from Grid Battle with `modifiers.is_counter=true`. Damage Calc applies
> `COUNTER_ATTACK_MODIFIER=0.5` internally (ownership transferred from
> grid-battle.md to damage-calc.md in registry v2). Ambush gate preserves
> EC-9/EC-10 semantics; Shield Wall flat reduction remains in HP/Status per
> the damage-intake pipeline.

**OQ-3. Class Pool Skill Definitions — Where Do They Live?**
CR-5c references `assets/data/skills/class_pools.json` (3–5 skills per class).
Hero DB OQ-2 raised the same question. The skill definitions themselves (damage,
cost, range, effects) need a home. Options:
- (a) Inline in `class_pools.json` — simple but creates a large flat file
- (b) Separate `assets/data/skills/[skill_id].json` per skill, with `class_pools.json` holding only ID references
- **Resolve at Damage Calc or Grid Battle GDD**, whichever defines skill execution.

**OQ-4. Ranged Attack Elevation Interaction**
Archer and Strategist have `attack_range=3`. Terrain Effect GDD OQ-1 asks whether
ranged attacks use the same elevation modifier as melee. If ranged attacks get
reduced elevation penalties, Archer's High Ground Shot passive becomes less
distinctive. **Resolve at Damage Calc GDD.**

> **RESOLVED 2026-04-18 (opaque-int passthrough)** — `design/gdd/damage-calc.md`
> §C CR-4 + OQ-DC-6: Damage Calc treats `terrain_def` ∈ [−30, +30] as a single
> signed integer provided by `terrain-effect.md get_combat_modifiers()`. The
> ranged-vs-melee elevation distinction is resolved inside terrain-effect.md
> (not damage-calc.md). Archer's distinctiveness is preserved by terrain-effect
> choosing its own elevation delta for ranged attacks before packaging into
> `terrain_def`. Damage Calc is agnostic.

**OQ-5. Equipment Slot Override Frequency**
Hero DB OQ-6 asks how common `equipment_slot_override` will be. If many heroes
override slots, the "uniform 3 slots" rule in CR-1 becomes misleading. Current
assumption: override is rare (1–2 heroes in MVP). **Re-evaluate when Equipment/Item
GDD is designed.**

**OQ-6. Class Conversion System Interface**
Class Conversion (#31, Vertical Slice priority) will allow heroes to change class.
When converted, all formulas re-derive with the new class's coefficients. Open:
does the hero keep their Slot 2 skill, or does it reset? Does the hero keep
passive progress (e.g., Charge state)? **Deferred to Class Conversion GDD.**

**OQ-7. Initiative Tie-Breaking**
F-4 produces integer initiative values. Two units can have the same initiative.
Turn Order GDD (#8) must define the tie-breaking rule (e.g., higher agility first,
or random). Unit Role does not own this — flagging for Turn Order.
