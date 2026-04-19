# Formation Bonus System (진형 보너스)

> **Status**: In Design — v1.0 draft (synthesizer-assembled from game-designer + systems-designer parallel specialist outputs 2026-04-19)
> **Author**: game-designer (narrative + content); systems-designer (formulas + edge cases + caps + AC)
> **Last Updated**: 2026-04-19 (v1.0 first draft — pre-`/design-review`)
> **Implements Pillar**: Pillar 1 (형세의 전술 — Tactics of Formation) primary; Pillar 4 (삼국지의 숨결 — historical bond resonance) supporting
> **Depends on**: Hero Database (`get_relationships`), Map/Grid (`get_adjacent_units`), Damage Calc (`ResolveModifiers` cross-doc obligation rev 2.9), Turn Order (`round_started` signal), Balance/Data (`config/formations.json`)
> **Coordinates with**: `design/gdd/grid-battle.md` CR-15 (Rally — architectural template; Formation Bonus is parallel additive modifier, NOT Rally), `design/gdd/unit-role.md` EC-12 (Rally Stacking Cap — distinct contract)
> **User-adjudicated design decisions (binding)**: (1) Scope = Pattern + Relationship hybrid; (2) Application = additive `ResolveModifiers.formation_atk_bonus`/`formation_def_bonus` fields; (3) Recalc = `round_started` only; (4) MVP content = 4 patterns + 4 relationship types

---

## 1. Overview

The Formation Bonus System rewards deliberate spatial positioning by granting small, additive combat bonuses when allied units arrange themselves into recognised historical battle formations (진형) or when heroes with established personal relationships fight in close proximity. It is the mechanical embodiment of Pillar 1 — that victory flows from 형세 (the momentum of position), not from individual might. The system fires once per round at the `round_started` signal, computes per-unit `{atk_bonus, def_bonus}` snapshots, and publishes them into Grid Battle's battle-state. Grid Battle CR-5 step 4 reads these into `ResolveModifiers.formation_atk_bonus` / `formation_def_bonus` for damage-calc consumption. Bonuses persist for the entire round; mid-round movement and death do not invalidate the snapshot. A hard combined-modifier cap (`P_MULT_COMBINED_CAP = 1.31` in damage-calc F-DC-5) ensures formation bonuses never push apex damage above the existing rev 2.8.1 ceiling-safe envelope (Cavalry REAR+Charge+Rally(+10%) = 179).

---

## 2. Player Fantasy

*Primary MDA Aesthetic: Challenge (tactical mastery), Expression (spatial creativity). Supporting: Fantasy (삼국지 hero bonds), Narrative (historical drama).*

### Vignette 1 — 어진형의 완성 (The Wedge Completes)

It is turn 3. 관우 anchors the spearhead, 장비 stands one tile diagonally back-left, and a nameless spearman holds one tile diagonally back-right — forming the 어진형 (V-shaped wedge). The player has been shuffling these three toward alignment for two turns, sacrificing a flanking opportunity. On `round_started` of turn 4, the board calculates: three allied units in a wedge — 어진형 recognised. A soft formation glyph pulses along the V. 관우 (the anchor) ticks up `formation_atk_bonus = 0.03`. On 관우's next attack the damage roll is +3% higher — not a massive swing, but visible, earned, and exactly the edge needed to crack the enemy's fortified tile.

The player feels the satisfaction Pillar 1 promises: a decision made two turns ago, maturing now. The formation bonus is not a reward for clicking correctly — it is proof that they read the 형세.

### Vignette 2 — 유관장 삼형제 (Brothers in the Same Row)

유비 is deployed adjacent to 관우 in the Battle Preparation screen. The player knows from prior playthroughs that these two share a SWORN_BROTHER relationship in the hero database. On `round_started`, the system queries 관우's relationship list (`get_relationships("guan_yu")`), finds 유비 at Manhattan distance ≤ 1, and writes `formation_atk_bonus += 0.02` to both. The battle-hud forecast panel shows a small bond icon on their action menu.

The player did not optimise for power — they composed a scene from the story they already love. The bonus is the game whispering: *"yes, this is how it should be."* Narrative and mechanics are briefly the same thing.

### Vignette 3 — 관우와 조조 (RIVAL Adjacency Across Factions)

관우 is cornered adjacent to 조조 — not by design, but by a skirmish that collapsed the center. `round_started` fires. The RIVAL tag between them activates per CR-FB-4 (cross-faction exception). Both receive `formation_atk_bonus += 0.02`. 관우 attacks and crests a damage tier he could not have reached alone. 조조 counter-attacks at the same elevation.

The player did not plan this. The board did. But the game makes the moment feel charged — the Rival tag turns an accident of positioning into a historical echo. Sometimes drama arrives from constraint, not design.

### Vignette 4 — 방진의 방패 (The Square Holds)

Four infantry occupy a 2×2 square in the strategic center. The enemy cavalry has Charge and REAR angle — but `round_started` has already issued the 방진 bonus: `formation_def_bonus += 0.04` (rev 2.9.1 increase from 0.02 per floori-visibility audit). All four units have DEF≈50 (mid-tier Infantry). The cavalry hit lands. The Infantry's `formation_def_bonus` adds `floori(50 × 0.04) = 2` to eff_def via F-DC-3, absorbing 2 points of incoming damage per attack. The player holds the square through the cavalry push, buys one more turn, and the battle hinges on it.

방진's fantasy is not offense — it is resilience purchased through discipline. The player who defends correctly is rewarded the same way as the player who attacks correctly: formation as the answer to every tactical question.

---

## 3. Detailed Rules

### Core Rules

**CR-FB-1. Pattern Detection Contract.**

A pattern bonus is granted when all required tile slots of a defined formation template are occupied by allied units belonging to the same faction.

1. **Template definition**: Each pattern is a set of relative tile offsets from an anchor tile. Anchor = lowest-index unit (by initiative order) in the candidate set. Per-pattern templates in CR-FB-7 through CR-FB-10.
2. **Faction restriction**: Only same-faction allied units count toward pattern recognition. Enemy units in pattern slots void the pattern. (Pillar 1: 형세 is a coalition property.)
3. **Unit occupancy**: A tile counts as occupied for pattern purposes iff a living unit of the correct faction stands on it at `round_started` evaluation time. Dead units and units with `is_departing == true` do not count.
4. **Multi-pattern overlap**: A unit may participate in multiple patterns simultaneously (e.g., anchor of 어진형 AND member of 방진). All contributions sum into raw_atk / raw_def, then per-unit cap (CR-FB-3 rule 4) applies.
5. **Pattern recalculation**: Called exactly once per round at `round_started` (see CR-FB-5).
6. **Data source**: Pattern shape definitions read from `assets/data/config/formations.json` (Balance/Data CR-2). The GDD is authoritative spec; JSON is tunable data layer.

**CR-FB-2. Relationship Adjacency Contract.**

A relationship bonus is granted when two heroes with a declared relationship (Hero Database `relation_type` enum) are present on the grid as living units, satisfy faction restrictions (CR-FB-4), and are within adjacency threshold.

1. **Adjacency definition**: Manhattan distance ≤ 1, orthogonal-only (NORTH/EAST/SOUTH/WEST). Diagonal tiles do NOT qualify. Mirrors Rally adjacency (Grid Battle CR-15 rule 2) for system-wide consistency. (Source: `map-grid.md` `get_adjacent_units` orthogonal-only contract.)
2. **Hero Database query**: Formation Bonus queries `get_relationships(hero_id) → Array[Relationship]` (Hero Database line 202) for each unit at `round_started`.
3. **Symmetry**: If `is_symmetric == true`, both heroes receive the bonus. If `is_symmetric == false`, only the record-holding hero receives it. (Per Hero Database line 132 contract.)
4. **Multiple relationships**: A unit may simultaneously receive bonuses from multiple active relationships. Bonuses sum additively into `raw_atk` / `raw_def` before per-unit cap.

**CR-FB-3. Bonus Stacking Rules.**

1. **Additive ResolveModifiers fields**: Formation Bonus writes to `ResolveModifiers.formation_atk_bonus: float` and `ResolveModifiers.formation_def_bonus: float` (Damage Calc rev 2.9 cross-doc obligation). Mirrors `rally_bonus` field pattern (Grid Battle CR-15 rule 3 + Damage Calc rev 2.7 precedent).
2. **Pattern + relationship stack**: A unit may receive both a pattern bonus and one or more relationship bonuses simultaneously. They sum within the same `formation_atk_bonus` / `formation_def_bonus` field per-unit.
3. **Formation Bonus is NOT Rally**: `formation_atk_bonus` and `rally_bonus` are independent ResolveModifiers fields. The Rally stacking cap (Unit Role EC-12) applies ONLY to `rally_bonus`, not to formation fields.
4. **Per-unit formation cap**: `formation_atk_bonus ≤ 0.05` and `formation_def_bonus ≤ 0.05` per unit, enforced in F-FB-3 BEFORE handoff to ResolveModifiers. Caps are tunable knobs (Section 7).
5. **Combined P_mult cap (apex safety)**: Damage Calc F-DC-5 enforces `P_MULT_COMBINED_CAP = 1.31` AFTER all multiplicative composition (Charge × Rally × Formation). This guarantees `floori(83 × 1.64 × 1.31) = floori(178.1) = 178 ≤ 179` — DAMAGE_CEILING never fires on any primary path under any combination of Charge + Rally(+10%) + Formation(+5%). (Apex arithmetic verified: see Section 4 F-FB-5.)

**CR-FB-4. Faction Restriction (with RIVAL exception).**

Pattern and relationship bonuses require same-faction allies, with one exception:

- **RIVAL only**: The RIVAL bonus fires regardless of faction alignment. If 관우 (player faction) and 조조 (enemy faction) are both living on the grid and within Manhattan distance ≤ 1, both receive `formation_atk_bonus += 0.02`. This is a deliberate narrative exception — dramatic rivals are made more dangerous by proximity, not less. (Pillar 4: 삼국지의 숨결 — historical tension between named rivals is a first-class game event.)
- All other relationship types (SWORN_BROTHER / LORD_VASSAL / MENTOR_STUDENT) and ALL pattern bonuses require same-faction units.

**CR-FB-5. Recalculation Trigger.**

1. **Signal subscription**: Formation Bonus subscribes to `round_started(round_number: int)` from Turn Order Contract 4 → Grid Battle → Formation Bonus subscriber chain. (Resolves Turn Order OQ-3.)
2. **Persistence**: Bonuses written at `round_started` persist for the entire round. Movement, death, and combat within the round do not trigger recalculation.
3. **Mid-round invariance**: If a unit dies or moves mid-round, snapshot bonuses for all units (including the affected one) remain. Grid Battle resolves no attack for dead units, so stale entries cause no incorrect application.
4. **Rationale**: Round-only recalc ensures the player can read the board state once (at round start) and act with full information. Mid-round recalc would create unpredictable shifts after each move, breaking Pillar 1's "plan your round" intent.

**CR-FB-6. ResolveModifiers Handoff.**

At `round_started`, Formation Bonus writes computed bonuses into a snapshot dict published to Grid Battle. Grid Battle CR-5 step 4 reads this snapshot per-attack to populate `ResolveModifiers`.

1. **Write path**: `FormationBonusSystem.compute_and_publish_snapshot(units, round)` → `grid_battle.set_formation_bonuses(formation_bonuses: Dictionary[int, Dictionary])` where each entry is `{unit_id: {atk_bonus: float, def_bonus: float}}`.
2. **Read path**: At Grid Battle CR-5 step 4 (per-attack):
   - `modifiers.formation_atk_bonus = formation_bonuses.get(attacker_id, {}).get("atk_bonus", 0.0)`
   - `modifiers.formation_def_bonus = formation_bonuses.get(defender_id, {}).get("def_bonus", 0.0)`
3. **Default**: If a unit_id is missing from the snapshot dict (e.g., unit joined battle after snapshot), default both fields to `0.0`.
4. **Reset**: At next `round_started`, snapshot is recomputed and overwritten.

### Pattern Rules (4 MVP patterns)

**CR-FB-7. 어진형 (魚鱗陣 — Fish-Scale Wedge).**

*Three allied units in a V-shape: anchor at the spearhead tip, two flankers one tile diagonally back-left and back-right.*

Template (anchor at (0,0), facing NORTH = row decreasing):
```
              (0, 0)        ← anchor (tip of wedge)
   (-1, +1)         (+1, +1) ← flankers (one tile diagonally back)
```

- **Bonus**: Anchor receives `formation_atk_bonus += 0.03`. Flankers receive `formation_atk_bonus += 0.01` each.
- **Minimum size**: Exactly 3 units in the specified pattern. Diagonal positions count for pattern shape (not for relationship adjacency in CR-FB-2).
- **Design intent** (Pillar 1): Rewards aggressive wedge-push tactics. The point unit doing the most dangerous work receives the larger bonus; flankers receive a small share for committing to the formation.

**CR-FB-8. 학익진 (鶴翼陣 — Crane Wing).**

*Three allied units in a horizontal line: anchor at center, two wingmen on either side.*

Template (anchor at (0,0)):
```
(-1, 0)    (0, 0)    (+1, 0)   ← all in same row; anchor at center
```

- **Bonus**: Anchor receives `formation_atk_bonus += 0.04`. Wingmen receive no bonus from this pattern (the V opens through the center).
- **Minimum size**: Exactly 3 units in the horizontal line.
- **Design intent** (Pillar 1): Rewards committed front-line setups. Historically 학익진 envelops; the center-anchor receives the payoff for holding the line as the focal point.

**CR-FB-9. 마름진 (菱形陣 — Diamond).**

*Four allied units in a diamond at four cardinal positions around a center tile (center may be empty or occupied by a non-pattern unit).*

Template (center at (0,0), members at):
```
              (0, -1)        ← north
   (-1, 0)             (+1, 0) ← west, east
              (0, +1)        ← south
```

- **Bonus**: All four members receive `formation_atk_bonus += 0.01` AND `formation_def_bonus += 0.01`.
- **Center tile**: May be occupied by a fifth allied unit or empty. A fifth unit on the center tile does NOT disqualify the pattern and does NOT receive the bonus.
- **Minimum size**: Exactly the four cardinal positions occupied.
- **Design intent** (Pillar 1): Balanced offensive-defensive formation. Rewards coordinated all-direction coverage with a small dual bonus.

**CR-FB-10. 방진 (方陣 — Square).**

*Four allied units in a 2×2 tile square.*

Template (anchor at (0,0)):
```
(0, 0)   (+1, 0)
(0, +1)  (+1, +1)
```

- **Bonus**: All four units receive `formation_def_bonus += 0.04` (rev 2.9.1 — increased from 0.02 per game-designer floori-visibility finding: at typical Infantry DEF=20, `floori(20 × 0.02) = 0` ate the bonus entirely; `floori(20 × 0.04) = 0` still rounds to zero at low DEF but `floori(50 × 0.04) = 2` is visible at mid-tier DEF, mirroring 마름진 magnitude). No ATK bonus.
- **Minimum size**: Exactly 4 units in 2×2.
- **Larger blocks**: A 3×2 or 2×3 contains multiple overlapping 2×2 candidates; only one instance is active per CR-FB-1 rule 4 (multi-pattern overlap allowed but per-unit cap applies).
- **Design intent** (Pillar 1): Pure-defensive formation rewarding hold-ground tactics. Choice between 방진 and 어진형 is a meaningful tactical decision (defense vs. advance).

### Relationship Rules (4 MVP relationship types)

**CR-FB-11. SWORN_BROTHER (의형제).**

- **is_symmetric**: `true` — both heroes receive the bonus.
- **Bonus**: `formation_atk_bonus += 0.02` to both units per pair.
- **Triad behavior**: For three sworn brothers all mutually adjacent, F-FB-2 generates 3 pairs; each unit receives bonus from 2 pair-mates → raw +0.04 ATK before per-unit cap (0.05). Cap absorbs.
- **Design intent** (Pillar 1 + Pillar 4): The highest-narrative-density relationship. The 유관장 sworn brothers are the game's primary emotional anchor. +0.02 per pair is meaningful but bounded.

**CR-FB-12. LORD_VASSAL (군신).**

- **is_symmetric**: `false` — vassal unit only receives bonus.
- **Bonus (vassal only)**: `formation_def_bonus += 0.02`.
- **Rationale**: The vassal fights to protect the lord — resilience and loyalty, not aggression. Asymmetry models the historical relationship: the lord inspires by presence; the vassal is emboldened to hold ground. Avoids making the lord stronger by positioning (which would conflict with Pillar 3 — every hero has a role, not "stack the strongest unit near the lord").

**CR-FB-13. RIVAL (숙적).**

- **is_symmetric**: `true` — both heroes receive the bonus, regardless of faction (CR-FB-4 exception).
- **Bonus**: `formation_atk_bonus += 0.02` to both units per pair.
- **Cross-faction**: Uniquely, this fires across faction lines. The player who deploys 관우 near 조조 is making a historically resonant choice that costs them the reciprocal boost to the enemy.
- **Design intent** (Pillar 1 + Pillar 4): Rivals create a local tactical drama node. The cross-faction trigger creates a strategic dilemma — the player must decide if triggering rival is worth the enemy's mirror boost.

**CR-FB-14. MENTOR_STUDENT (사제).**

- **is_symmetric**: `false` — student unit only receives bonus.
- **Bonus (student only)**: `formation_atk_bonus += 0.02`.
- **Rationale**: The student fights with the mentor's teachings fresh in mind — sharper, more precise. ATK chosen because the student's growth is expressed as combat effectiveness. (XP modifier was considered but deferred — XP gain belongs to Character Growth System scope.)

---

## 4. Formulas

### F-FB-1. Pattern Detection Algorithm

```
# Pattern definition (from formations.json):
# PatternDef {
#   id: StringName,
#   name: String,                           # display name e.g., "어진형"
#   anchor_bonus: { atk: float, def: float },
#   member_bonus: { atk: float, def: float },
#   offsets: Array[{ dc: int, dr: int }]    # offsets relative to anchor (0,0)
# }

detect_patterns(units: Array[UnitState],
                grid: MapGrid,
                patterns: Array[PatternDef]
                ) -> { anchors: Dictionary[int, Array[StringName]],
                       members: Dictionary[int, Array[StringName]] }:

    anchor_map: Dictionary[int, Array[StringName]] = {}
    member_map: Dictionary[int, Array[StringName]] = {}

    for unit_a in units:                                    # O(U)
        if not unit_a.is_alive: continue
        for pattern in patterns:                            # O(P)
            all_filled: bool = true
            occupants: Array[int] = [unit_a.unit_id]        # anchor itself

            for offset in pattern.offsets:                  # O(T)
                target: Vector2i = unit_a.coord + Vector2i(offset.dc, offset.dr)
                neighbor_id: int = grid.get_unit_at(target, unit_a.faction)
                if neighbor_id == -1:                       # tile empty or wrong faction
                    all_filled = false
                    break
                neighbor: UnitState = get_unit(neighbor_id)
                if neighbor == null or not neighbor.is_alive:
                    all_filled = false
                    break
                occupants.append(neighbor_id)

            if all_filled:
                if not anchor_map.has(unit_a.unit_id):
                    anchor_map[unit_a.unit_id] = []
                anchor_map[unit_a.unit_id].append(pattern.id)
                # Record members (excluding anchor)
                for i in range(1, occupants.size()):
                    member_id = occupants[i]
                    if not member_map.has(member_id):
                        member_map[member_id] = []
                    member_map[member_id].append(pattern.id)

    return { "anchors": anchor_map, "members": member_map }
```

**Variables:**

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `U` | int | 1–8 (MVP 4v4) | Alive unit count |
| `P` | int | 4 (MVP) | Pattern count loaded from formations.json |
| `T` | int | 2–4 | Template size per pattern (2 for 어진형/학익진/방진 anchor + offsets; 4 for 마름진) |
| `unit_a.coord` | Vector2i | grid bounds | Candidate anchor position |
| `offset.{dc, dr}` | int | -1 to +1 (MVP) | Relative position from anchor |
| `anchor_map` | Dictionary[int, Array] | — | unit_id → patterns where this unit is anchor |
| `member_map` | Dictionary[int, Array] | — | unit_id → patterns where this unit is non-anchor member |

**Complexity**: O(U × P × T) ≤ 8 × 4 × 4 = 128 iterations per `round_started`. Negligible cost.

### F-FB-2. Relationship Pair Detection

```
detect_relationship_bonuses(units: Array[UnitState],
                            hero_db: HeroDatabase,
                            rel_effect_table: Dictionary[StringName, BonusVal]
                            ) -> Dictionary[int, BonusVal]:
    # BonusVal { atk: float, def: float }

    contributions: Dictionary[int, BonusVal] = {}

    for i in range(units.size()):                    # O(U^2 × R)
        unit_a = units[i]
        if not unit_a.is_alive: continue

        for j in range(i + 1, units.size()):
            unit_b = units[j]
            if not unit_b.is_alive: continue
            if manhattan(unit_a.coord, unit_b.coord) > 1: continue

            # Faction check (CR-FB-4 RIVAL exception)
            same_faction: bool = unit_a.faction == unit_b.faction
            rels_a: Array[Relationship] = hero_db.get_relationships(unit_a.hero_id)

            for rel in rels_a:
                if rel.hero_b_id != unit_b.hero_id: continue
                if rel.relation_type != &"RIVAL" and not same_faction: continue
                # RIVAL fires cross-faction; all others same-faction only

                bonus: BonusVal = rel_effect_table[rel.effect_tag]

                if rel.is_symmetric:
                    apply_bonus(contributions, unit_a.unit_id, bonus)
                    apply_bonus(contributions, unit_b.unit_id, bonus)
                else:
                    # One-directional: record-holder (unit_a) only
                    apply_bonus(contributions, unit_a.unit_id, bonus)

    return contributions
```

**Variables:**

| Symbol | Type | Range | Description |
|--------|------|-------|-------------|
| `U` | int | 1–8 | Alive unit count |
| `R` | int | 0–4 | Max relationship records per hero |
| `rel.is_symmetric` | bool | — | If true, both units receive bonus |
| `rel.relation_type` | StringName | {SWORN_BROTHER, LORD_VASSAL, RIVAL, MENTOR_STUDENT} | Hero DB enum |
| `rel.effect_tag` | StringName | 4 MVP tags | Key into rel_effect_table |
| `BonusVal.atk` | float | 0.0–0.02 | Per-relationship ATK contribution |
| `BonusVal.def` | float | 0.0–0.02 | Per-relationship DEF contribution |

### F-FB-3. Bonus Aggregation Per Unit

```
const FORMATION_ATK_BONUS_CAP: float = 0.05    # Tuning Knob
const FORMATION_DEF_BONUS_CAP: float = 0.05    # Tuning Knob

aggregate_formation_bonuses(unit_id: int,
                             pattern_anchors: Dictionary[int, Array[StringName]],
                             pattern_members: Dictionary[int, Array[StringName]],
                             pattern_defs: Dictionary[StringName, PatternDef],
                             rel_contributions: Dictionary[int, BonusVal]
                             ) -> { atk_bonus: float, def_bonus: float }:

    raw_atk: float = 0.0
    raw_def: float = 0.0

    # Pattern anchor contributions
    if pattern_anchors.has(unit_id):
        for pid in pattern_anchors[unit_id]:
            raw_atk += pattern_defs[pid].anchor_bonus.atk
            raw_def += pattern_defs[pid].anchor_bonus.def

    # Pattern member contributions
    if pattern_members.has(unit_id):
        for pid in pattern_members[unit_id]:
            raw_atk += pattern_defs[pid].member_bonus.atk
            raw_def += pattern_defs[pid].member_bonus.def

    # Relationship contributions
    if rel_contributions.has(unit_id):
        raw_atk += rel_contributions[unit_id].atk
        raw_def += rel_contributions[unit_id].def

    # Per-unit cap (CR-FB-3 rule 4)
    capped_atk: float = minf(raw_atk, FORMATION_ATK_BONUS_CAP)
    capped_def: float = minf(raw_def, FORMATION_DEF_BONUS_CAP)

    return { "atk_bonus": capped_atk, "def_bonus": capped_def }
```

### F-FB-4. Snapshot Publication

```
compute_and_publish_snapshot(units: Array[UnitState], round_number: int) -> void:
    patterns = load_pattern_defs_cached()
    rel_effects = load_rel_effect_table_cached()

    detection = detect_patterns(units, grid, patterns)        # F-FB-1
    rel_map = detect_relationship_bonuses(units, hero_db, rel_effects)  # F-FB-2

    formation_bonuses: Dictionary[int, Dictionary] = {}

    for unit in units:
        if not unit.is_alive: continue
        bonus = aggregate_formation_bonuses(
            unit.unit_id, detection.anchors, detection.members, patterns, rel_map)
        formation_bonuses[unit.unit_id] = bonus

    # Publish to Grid Battle (line 905 scaffolding contract)
    grid_battle.set_formation_bonuses(formation_bonuses)
```

### F-FB-5. Damage Calc Handoff (Cross-Doc Obligation — Damage Calc rev 2.9)

Formation ATK bonus flows into `passive_multiplier` (F-DC-5) as a multiplicative factor, mirrored on the rev 2.7 Rally pattern:

```
# Addition to F-DC-5 passive_multiplier (after Rally block, before final return):
const P_MULT_COMBINED_CAP: float = 1.31    # Apex safety guard

if modifiers.formation_atk_bonus > 0.0 and not modifiers.is_counter:
    P_mult *= (1.0 + modifiers.formation_atk_bonus)

# Combined cap enforced AFTER all multiplications (Charge × Rally × Formation)
P_mult = minf(P_mult, P_MULT_COMBINED_CAP)
return snappedf(P_mult, 0.01)
```

Formation DEF bonus flows into F-DC-3 effective DEF (mirrors terrain DEF):

```
# Addition to F-DC-3 stage_1_base_damage:
eff_def = defender.def_stat + terrain_def_bonus + floori(defender.def_stat * modifiers.formation_def_bonus)
```

**Apex arithmetic verification (compute, don't read):**

| Scenario | P_mult composition | Pre-cap P_mult | Post-cap P_mult | raw_damage | Notes |
|---|---|---|---|---|---|
| Cavalry REAR+Charge no Rally no Formation | 1.20 | 1.20 | 1.20 | floori(83×1.64×1.20)=163 | Baseline |
| Cavalry REAR+Charge+Rally(+10%) no Formation | 1.20×1.10=1.32 | 1.32 | 1.31 | floori(83×1.64×1.31)=178 | Rev 2.8.1 apex (was 179 pre-cap) — minor regression of 1pt |
| Cavalry REAR+Charge+Rally(+10%)+Formation(+5%) | 1.20×1.10×1.05=1.386 | 1.39 | 1.31 | floori(83×1.64×1.31)=178 | Cap absorbs Formation; ceiling never fires |
| Cavalry REAR+Charge+Formation(+5%) no Rally | 1.20×1.05=1.26 | 1.26 | 1.26 | floori(83×1.64×1.26)=171 | Mid-range — Formation visible |

**Pillar verdict**: Cavalry apex damage drops from 179 → 178 (rev 2.8.1 → rev 2.9) due to combined-cap clamping at 1.31 vs 1.32. This is a 1-point regression on pure-Cavalry-apex but is the cost of allowing Formation Bonus to exist as a primary-path-safe modifier. Pillar-1 differentiation remains 29pt (REAR-only+Rally 149 vs REAR+Charge+Rally+Formation 178; previously 30pt). User-adjudicated trade-off: Formation Bonus visibility for non-apex units > 1pt apex preservation.

**Pillar-3 apex inversion note (rev 2.9.1 — user-ratified)**: At simultaneous max-everything (max ATK + max Rally + max Formation + Cavalry+Charge AND Archer+Ambush firing), Archer FLANK+Ambush+Rally+Formation cap = `floori(83 × 1.65 × 1.31) = 179` edges Cavalry REAR+Charge+Rally+Formation cap = `floori(83 × 1.64 × 1.31) = 178` by 1pt. Caused by P_MULT_COMBINED_CAP clamping both classes to identical P_mult=1.31; Archer's higher D_mult (1.65 from rev 2.6 Pillar-3 fix) edges Cavalry's (1.64 from rev 2.8 Rally cap fix). User-ratified as acceptable: Pillar-3 hierarchy holds in 23 of 24 cells (all typical play states), only the simultaneous-max-everything edge case inverts by 1pt. Strict apex ordering not required for Pillar-3 fidelity — distinct tactical roles + meaningful differentiation in common play are preserved. See damage-calc.md F-DC-4 Pillar-3 peak hierarchy note (rev 2.9 update).

---

## 5. Edge Cases

**EC-FB-1. Unit dies mid-round.** Snapshot computed at `round_started` is not recomputed. Surviving units retain round-R bonuses until `round_started(R+1)` triggers fresh snapshot. Dead unit's entry persists in dict but Grid Battle skips dead units in attack resolution. No special handling.

**EC-FB-2. Unit moves mid-round.** Identical to EC-FB-1. Snapshot captures positions at `round_started`. Mid-round movement does not trigger recalc. Unit moving out of formation retains pattern bonus for remainder of round. Unit moving into formation receives no bonus until next `round_started`.

**EC-FB-3. Same unit in two patterns simultaneously (e.g., anchor of 어진형 AND member of 방진).** Both contributions sum in F-FB-3 before cap. Per-unit cap (0.05) limits total. Intentional: rewards dense multi-unit coordination but bounded.

**EC-FB-4. Three SWORN_BROTHER units mutually adjacent (triangle).** F-FB-2 generates 3 pairs. With `is_symmetric=true`, each unit receives bonus from 2 pair-mates → raw +0.04 ATK. Per-unit cap (0.05) absorbs.

**EC-FB-5. Pattern partially formed at `round_started`, completes mid-round via movement.** No bonus that round (snapshot semantics). Bonus activates next `round_started`.

**EC-FB-6. Asymmetric conflicting relationships (A→B SWORN_BROTHER `is_symmetric=true`, B→A RIVAL `is_symmetric=true`).** Per Hero Database EC-6, both records load independently and emit a design-warning at load time. F-FB-2 processes each record independently: A's SWORN_BROTHER record applies sworn_atk_boost to both; B's RIVAL record applies rival_atk_boost to both. Both bonuses sum subject to per-unit cap. The load-time design-warning is the authoring-error mitigation; Formation Bonus does not arbitrate.

**EC-FB-7. `formations.json` parse failure or missing.** At init, missing file is FATAL (per Balance/Data CR-4). At runtime parse failure (e.g., file corruption mid-session): WARNING-level log; publish empty `formation_bonuses` dict; all units receive `{atk_bonus: 0.0, def_bonus: 0.0}`. Grid Battle proceeds without error.

**EC-FB-8. Pattern requires N units but only N−1 alive.** F-FB-1 checks all template offsets at `round_started`. Any unoccupied/wrong-faction offset → pattern not matched. No partial bonus.

**EC-FB-9. formation_atk_bonus + Rally + Charge stack.** P_MULT_COMBINED_CAP = 1.31 enforced in F-DC-5 after all multiplications. `floori(83 × 1.64 × 1.31) = 178 ≤ 179`. DAMAGE_CEILING never fires on primary path under any combination.

**EC-FB-10. Unit with no pattern and no adjacent relationship.** `aggregate_formation_bonuses` returns `{atk_bonus: 0.0, def_bonus: 0.0}`. Entry written to snapshot dict (simplifies null-check at Grid Battle read).

**EC-FB-11. Hero with no relationship records.** `hero_db.get_relationships(hero_id)` returns empty Array. F-FB-2 contributes zero. No error.

**EC-FB-12. RIVAL between same-faction units.** RIVAL `is_symmetric=true` applies regardless of faction (CR-FB-4 exception). Same-faction rivals (e.g., 위연 and 강유 if authored as RIVAL) receive bonus normally.

---

## 6. Dependencies

### Upstream (Formation Bonus depends on)

| System | GDD | Type | Contract | Data Consumed |
|--------|-----|------|----------|---------------|
| Hero Database | `design/gdd/hero-database.md` | Hard | `get_relationships(hero_id) → Array[Relationship]` (read-only) | `relation_type`, `effect_tag`, `is_symmetric`, `hero_b_id` |
| Map/Grid | `design/gdd/map-grid.md` | Hard | `get_adjacent_units(coord, faction) → Array[int]`; `get_unit_at(coord, faction) → int` (or -1 if empty/wrong-faction) | Unit positions at snapshot time |
| Turn Order | `design/gdd/turn-order.md` | Soft (signal) | `round_started(round_number: int)` subscriber. Resolves OQ-3 (line 946). | `round_number` for snapshot audit |
| Balance/Data | `design/gdd/balance-data.md` | Hard | `assets/data/config/formations.json` schema (pattern templates + rel effect bonuses + caps); FATAL on missing at boot per Balance/Data CR-4 | Pattern templates, `rel_effect_table`, `FORMATION_ATK_BONUS_CAP`, `FORMATION_DEF_BONUS_CAP`, `P_MULT_COMBINED_CAP` |

### Downstream (depend on Formation Bonus)

| System | GDD | Type | What Formation Bonus Provides |
|--------|-----|------|-------------------------------|
| Grid Battle | `design/gdd/grid-battle.md` | Hard | `formation_bonuses: Dictionary[int, {atk_bonus, def_bonus}]` snapshot via `set_formation_bonuses()`. Grid Battle CR-5 step 4 reads to populate `ResolveModifiers.formation_atk_bonus` / `formation_def_bonus`. **Cross-doc obligation**: grid-battle.md needs new CR (analogous to CR-15 Rally) covering Formation Bonus orchestration. |
| Damage Calc | `design/gdd/damage-calc.md` | Hard | **Cross-doc obligation rev 2.9**: ResolveModifiers wrapper adds `formation_atk_bonus: float`, `formation_def_bonus: float` fields + `make()` factory signature update. F-DC-5 adds Formation block (after Rally, before final cap). F-DC-3 adds formation_def_bonus to `eff_def`. New constant `P_MULT_COMBINED_CAP = 1.31` registered. |

### Cross-doc obligations summary (not yet propagated — pending implementation pass)

1. **damage-calc.md rev 2.9**: ResolveModifiers field additions + F-DC-5 Formation block + F-DC-3 eff_def addition + P_MULT_COMBINED_CAP constant + apex arithmetic re-verification (Cavalry apex 179 → 178).
2. **grid-battle.md**: New CR for Formation Bonus orchestration (subscribe to `round_started`, invoke `compute_and_publish_snapshot`, read snapshot in CR-5 step 4). Update Dependencies table Formation Bonus row from "Not Started" to "Designed (v1.0)".
3. **turn-order.md OQ-3**: Resolution note added — "RESOLVED via Formation Bonus GDD v1.0; direct subscription to `round_started`."
4. **balance-data.md**: Update formations.json schema spec to reflect MVP content (4 patterns + 4 relationship effect tags + 3 cap constants).
5. **design/registry/entities.yaml**: Register `P_MULT_COMBINED_CAP=1.31`, `FORMATION_ATK_BONUS_CAP=0.05`, `FORMATION_DEF_BONUS_CAP=0.05` constants.
6. **hero-database.md**: Confirm `effect_tag` values for the 4 MVP relationship types: `sworn_atk_boost`, `lord_vassal_def_boost_vassal`, `rival_atk_boost`, `mentor_student_atk_boost_student`.

---

## 7. Tuning Knobs

All values read from `assets/data/config/formations.json`. No value hardcoded in GDScript.

### Pattern Bonuses

| Knob | Key | Default | Category | Safe Range | Notes |
|------|-----|---------|----------|------------|-------|
| 어진형 anchor ATK | `pattern_yeojin_atk_anchor` | 0.03 | Feel | 0.01–0.04 | Anchor at wedge tip |
| 어진형 member ATK | `pattern_yeojin_atk_member` | 0.01 | Feel | 0.00–0.02 | Two flankers |
| 학익진 anchor ATK | `pattern_hakik_atk_anchor` | 0.04 | Feel | 0.02–0.05 | Center-anchor only; wingmen no bonus |
| 마름진 ATK (per member) | `pattern_mareum_atk_member` | 0.01 | Feel | 0.00–0.02 | All 4 members |
| 마름진 DEF (per member) | `pattern_mareum_def_member` | 0.01 | Feel | 0.00–0.02 | All 4 members |
| 방진 DEF (per member) | `pattern_bangjin_def_member` | 0.04 (rev 2.9.1 — was 0.02) | Feel | 0.02–0.05 | All 4 members; pure-defensive. Floori-visibility: `floori(eff_def × 0.04)` produces 0 below DEF=25, 1 at DEF 25-49, 2 at DEF 50-74. At typical mid-tier Infantry DEF≈50, +2 absorbed damage is the design target. Lower values (e.g., 0.02 pre rev 2.9.1) round to zero at typical DEF, making the bonus invisible. |

### Relationship Bonuses

| Knob | Key | Default | Category | Safe Range | Notes |
|------|-----|---------|----------|------------|-------|
| SWORN_BROTHER ATK | `rel_sworn_brother_atk` | 0.02 | Feel | 0.01–0.03 | Symmetric; both heroes per pair |
| LORD_VASSAL DEF (vassal) | `rel_lord_vassal_def_vassal` | 0.02 | Feel | 0.01–0.03 | Asymmetric; vassal only |
| RIVAL ATK | `rel_rival_atk` | 0.02 | Feel | 0.01–0.03 | Symmetric; cross-faction (CR-FB-4) |
| MENTOR_STUDENT ATK (student) | `rel_mentor_student_atk_student` | 0.02 | Feel | 0.01–0.03 | Asymmetric; student only |

### Caps and Gates

| Knob | Key | Default | Category | Safe Range | Notes |
|------|-----|---------|----------|------------|-------|
| Per-unit ATK cap | `formation_atk_bonus_cap` | 0.05 | Gate | 0.03–0.08 | Cap before P_MULT_COMBINED_CAP; prevents triad SWORN_BROTHER abuse |
| Per-unit DEF cap | `formation_def_bonus_cap` | 0.05 | Gate | 0.03–0.08 | Cap before damage application; prevents 방진+LORD_VASSAL stack abuse |
| Combined P_mult cap (damage-calc) | `p_mult_combined_cap` | 1.31 | **GATE — apex safety**; locked | 1.30–1.32 | Enforced in F-DC-5 after Charge × Rally × Formation. Math: `floori(83 × 1.64 × 1.31) = 178 ≤ 179`. Lower → more apex headroom but Formation becomes inert at full Rally. Higher → DAMAGE_CEILING risks firing on Cavalry+Charge+Rally+Formation. |
| Relationship adjacency distance | `rel_adjacency_distance` | 1 | Gate | 1–2 | Manhattan distance threshold. Value 1 = orthogonal only (matches Rally). Value 2 = one-step extension; dramatically increases activation rate — test before raising. |

### Tuning Notes

**Apex safety (locked)**: `P_MULT_COMBINED_CAP = 1.31` is the load-bearing constant that keeps Formation Bonus + Rally + Charge composition under DAMAGE_CEILING=180. Cavalry REAR+Charge+Rally(+10%)+Formation(+5%): pre-cap P_mult = 1.39 → clamped to 1.31 → raw = 178. Without this cap, Formation would push Cavalry apex to 189, collapsing Pillar-1 differentiation. Do NOT raise without re-verifying apex math.

**Tuning trade-off (rev 2.9 vs rev 2.8.1)**: Cavalry pure-apex no-Formation drops from 179 → 178 (1-point regression) due to combined-cap clamping at 1.31 vs 1.32. Pillar-1 differentiation: REAR-only+Rally 149 vs REAR+Charge+Rally+(any Formation) 178 = 29pt (was 30pt at rev 2.8.1). User-adjudicated trade-off: Formation Bonus visibility for non-apex units > 1pt apex preservation.

**Per-unit cap rationale**: Default 0.05 is set so that triad SWORN_BROTHER (raw 0.04) + 어진형 anchor (raw 0.03) = raw 0.07 → capped to 0.05. Prevents single-unit accumulation from exceeding the formation's clearly-subordinate register vs. Rally cap (+0.10).

**Feel vs Gate categorization**: Pattern + relationship magnitudes are "Feel" (affects moment-to-moment combat texture). Caps and adjacency distance are "Gate" (control activation frequency / maximum theoretical output). No "Curve" knobs — Formation Bonus is flat-rate regardless of progression.

---

## 8. Acceptance Criteria

**Coverage summary**: All 14 Core Rules + 5 Formulas + 12 Edge Cases covered by at least one AC below. Pattern + relationship parametric ACs use deferred-fixture pattern (`tests/fixtures/formation_bonus/*.yaml` files not yet on disk).

**Gate Summary (v1.0)**: 16 ACs total (AC-FB-01 through AC-FB-16). All BLOCKING. Sub-classification: 4 fixture-independent (inline params) + 12 deferred-fixture (require `formation_bonus/*.yaml` authoring at implementation sprint).

### Pattern detection (4 ACs)

**AC-FB-01** [LOGIC]: Given three same-faction alive units at (2,2), (1,3), (3,3); when `detect_patterns` runs; then unit at (2,2) is returned as anchor of pattern `wedge` (어진형) with members at (1,3) and (3,3).
- Type: Unit | Fixture: `tests/fixtures/formation_bonus/wedge_3unit.yaml` (deferred) | Gate: BLOCKING

**AC-FB-02** [LOGIC]: Given three same-faction alive units at (2,2), (1,2), (3,2); when `detect_patterns` runs; then unit at (2,2) is returned as anchor of pattern `crane_wing` (학익진) with no member bonus (CR-FB-8: anchor-only).
- Type: Unit | Fixture: `tests/fixtures/formation_bonus/crane_wing_3unit.yaml` (deferred) | Gate: BLOCKING

**AC-FB-03** [LOGIC]: Given four same-faction alive units at (2,1), (1,2), (3,2), (2,3); when `detect_patterns` runs; then all four units are members of pattern `diamond` (마름진); each receives `atk_bonus += 0.01 AND def_bonus += 0.01`.
- Type: Unit | Fixture: `tests/fixtures/formation_bonus/diamond_4unit.yaml` (deferred) | Gate: BLOCKING

**AC-FB-04** [LOGIC]: Given four same-faction alive units at (1,1), (2,1), (1,2), (2,2); when `detect_patterns` runs; then all four are members of pattern `square` (방진); each receives `def_bonus += 0.02` (no ATK).
- Type: Unit | Fixture: `tests/fixtures/formation_bonus/square_4unit.yaml` (deferred) | Gate: BLOCKING

### Relationship bonuses (4 ACs)

**AC-FB-05** [LOGIC]: Given two alive same-faction units at Manhattan distance 1, with `get_relationships(A.hero_id)` returning `[{hero_b_id: B.hero_id, relation_type: SWORN_BROTHER, effect_tag: "sworn_atk_boost", is_symmetric: true}]`; when `detect_relationship_bonuses` runs; then both units' `atk_bonus` contributions = 0.02.
- Type: Unit | Fixture: `tests/fixtures/formation_bonus/sworn_brother_pair.yaml` (deferred) | Gate: BLOCKING

**AC-FB-06** [LOGIC]: Given a LORD_VASSAL relationship where `is_symmetric = false` and unit A (vassal) holds the record pointing to unit B (lord); when `detect_relationship_bonuses` runs; then only unit A's `def_bonus` = 0.02; unit B receives no bonus from this record.
- Type: Unit | Fixture: `tests/fixtures/formation_bonus/lord_vassal_pair.yaml` (deferred) | Gate: BLOCKING

**AC-FB-07** [LOGIC]: Given a RIVAL pair on OPPOSITE factions with `is_symmetric = true`; when adjacent and processed; then both units (regardless of faction) receive `atk_bonus = 0.02` per CR-FB-4 cross-faction exception.
- Type: Unit | Fixture: `tests/fixtures/formation_bonus/rival_cross_faction_pair.yaml` (deferred) | Gate: BLOCKING

**AC-FB-08** [LOGIC]: Given a MENTOR_STUDENT pair with `is_symmetric = false` where unit A is the student (record-holder); when processed; then only unit A's `atk_bonus` = 0.02.
- Type: Unit | Fixture: `tests/fixtures/formation_bonus/mentor_student_pair.yaml` (deferred) | Gate: BLOCKING

### Aggregation + cap (3 ACs)

**AC-FB-09** [LOGIC]: Given a unit with raw_atk = 0.07 (어진형 anchor +0.03 + SWORN_BROTHER +0.02 + SWORN_BROTHER +0.02 from triad pair); when `aggregate_formation_bonuses` runs; then `capped_atk == 0.05` (FORMATION_ATK_BONUS_CAP enforced).
- Type: Unit | Fixture: inline constants (boundary value test) | Gate: BLOCKING

**AC-FB-10** [LOGIC]: Given F-DC-5 P_mult composition with Cavalry+Charge+Rally(+10%)+Formation(+5%); pre-cap P_mult = `snappedf(1.20×1.10×1.05, 0.01) = 1.39`; when P_MULT_COMBINED_CAP applied; then post-cap P_mult = 1.31 (clamp fires).
- Type: Unit (damage-calc) | Fixture: inline ResolveModifiers.make() | Gate: BLOCKING

**AC-FB-11** [LOGIC]: Given Cavalry ATK=200, DEF=10, REAR, charge_active=true, passive_charge, rally_bonus=0.10, formation_atk_bonus=0.05; when `resolve()` is called; then `raw == 178` (DAMAGE_CEILING does NOT fire); `floori(83 × 1.64 × 1.31) = 178`.
- Type: Unit (damage-calc) | Fixture: inline (boundary value — exact integers ARE the point) | Gate: BLOCKING

### Snapshot semantics (2 ACs)

**AC-FB-12** [LOGIC]: Given unit A in a valid `crane_wing` pattern at `round_started`; when unit A moves out of pattern position mid-round without a new `round_started` firing; then `formation_bonuses[A.unit_id].atk_bonus` remains at snapshot value (unchanged) until next `round_started`.
- Type: Unit | Fixture: `tests/fixtures/formation_bonus/snapshot_persistence.yaml` (deferred) | Gate: BLOCKING

**AC-FB-13** [LOGIC]: Given unit A in valid pattern at `round_started`; when A dies mid-round; then snapshot entry for A is not removed or zeroed mid-round. Grid Battle resolves no attack for dead A, so stale entry causes no incorrect application.
- Type: Unit | Fixture: inline state mutation | Gate: BLOCKING

### Edge cases (3 ACs)

**AC-FB-14** [INTEGRATION]: Given `config/formations.json` is replaced at runtime with empty `{}`; when `compute_and_publish_snapshot` is called; then (a) WARNING logged with substring `"EC-FB-7: formations.json"`, (b) `formation_bonuses` set to empty dict, (c) Grid Battle proceeds; all units receive `{atk_bonus: 0.0, def_bonus: 0.0}`.
- Type: Integration | Fixture: mock FileAccess returning `{}` | Gate: BLOCKING

**AC-FB-15** [LOGIC]: Given two same-faction units at Manhattan distance 2 with SWORN_BROTHER relationship; when `detect_relationship_bonuses` runs; then neither unit receives any contribution from this pair.
- Type: Unit | Fixture: inline coord setup | Gate: BLOCKING

**AC-FB-16** [LOGIC]: Given pattern `square` (4 units required) and only 3 same-faction units occupying 3 of the 4 corners; when `detect_patterns` runs; then no `square` pattern detected (CR-FB-1 rule 3 — all template offsets must be filled).
- Type: Unit | Fixture: inline coord setup | Gate: BLOCKING

---

## Cross-References

- **Pillar source**: `design/gdd/game-concept.md` (Pillar 1 형세의 전술; Pillar 4 삼국지의 숨결)
- **Upstream contracts**: `design/gdd/hero-database.md` lines 130-135, 200-220; `design/gdd/map-grid.md` lines 188+; `design/gdd/turn-order.md` Contract 4 + OQ-3 (line 946); `design/gdd/balance-data.md` lines 65, 211, 337
- **Downstream contracts**: `design/gdd/grid-battle.md` line 905 (formation_bonuses snapshot), Open Q4 line 1227; `design/gdd/damage-calc.md` rev 2.9 (cross-doc obligation pending)
- **Architectural template**: `design/gdd/grid-battle.md` CR-15 (Rally orchestration — parallel pattern for additive ResolveModifiers field)
- **Distinction**: `design/gdd/unit-role.md` EC-12 (Rally Stacking Cap — Formation Bonus is NOT Rally; separate cap)
- **Apex math precedent**: `design/gdd/damage-calc.md` rev 2.8.1 apex damage table; rev 2.9 will integrate Formation Bonus per F-FB-5 cross-doc obligation

## Open Questions

- **OQ-FB-01** [Vertical Slice]: Should pattern detection account for unit FACING direction? Currently pattern templates are absolute grid coordinates; a 어진형 wedge facing north vs south is the same template. If facing matters narratively (e.g., wedge must face the enemy), templates would need rotation logic. Defer to playtest — if players express confusion about formation orientation, revisit.
- **OQ-FB-02** [Alpha]: Per-faction pattern restrictions? E.g., 학익진 is historically a 蜀漢 (Shu) signature; should non-Shu factions get different bonuses for the same template? Defer until factional identity design solidifies.
- **OQ-FB-03** [VS]: Formation Bonus visualization on the battle HUD — separate spec? Currently relies on game-feel via damage popups + forecast panel. UI-FB-* needs dedicated battle-hud.md additions if pillar fidelity demands explicit formation indicators.
