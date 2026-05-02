# Chapter Prototype — 장판파 (Changban Bridge)

> **PROTOTYPE — NOT FOR PRODUCTION.**
> Author: 2026-05-02 (post-S3-06, post-vertical-slice prototype)
> Question: Does the existing GAME CONCEPT (formation tactics + hidden fate branches + role differentiation + scenario story integration) work as a coherent loop?
> **Direct test of**: `design/gdd/game-concept.md` MVP Core Hypothesis (line 296):
> *"진형 기반 턴제 전투에서 숨겨진 운명 분기 조건을 발견하는 경험이 회차 플레이를 유발할 만큼 재미있는가?"*

## How to run

```bash
godot --path /Users/forty4/Works/forty4/my-game res://prototypes/chapter-prototype/chapter.tscn
```

Window auto-resizes to 820×760 on launch.

## What's different from the previous prototype

| Aspect | vertical-slice (1st) | chapter-prototype (this one) |
|---|---|---|
| Scope | 4 units, 1 battle, simple melee | 4-phase chapter (story → party → battle → fate) |
| Game pillars tested | 0 / 4 | 4 / 4 |
| Hidden fate branches | None | 5 conditions, 3 outcomes (Rewritten / Partial / Historical) |
| Formation bonus | None | +5% ATK per adjacent ally (max +20%) |
| Side / rear attack | None | +25% / +50% based on defender facing |
| Role differentiation | None | 4 distinct roles (tank / assassin / archer / commander) |
| Per-hero passives | None | bridge_blocker, hit_and_run, rear_specialist, command_aura |
| Turn limit | None | 5 turns (forces tactical decisions) |
| Replay loop | None | "다시 도전" button → fresh attempt with new party choices |

## The 4-phase loop

1. **Story (5 dialogs)** — Click to advance through the Changban Bridge backdrop. Establishes Liu Bei's retreat, Zhao Yun's solo run for Ah-dou, Zhang Fei's bridge defense, and the historical-tragedy default.
2. **Party select** — 5 hero pool, but 관우 is unselectable (소설상 양양으로 출정 중). 장비 + 조운 are forced (스토리 요구). Choose 2 of {유비, 황충} for the remaining slots — **a real tactical choice** (commander aura vs. ranged rear specialist).
3. **Battle** — 7×7 map with river bisecting east-west, bridge at (3,3). 4 enemy: 하후돈/장요/우금/허저(boss). 5-turn limit. Each player unit may take ONE action per turn (move OR attack OR move-then-attack-if-in-range). Click 턴 종료 to hand off (or auto-handoff after all units acted).
4. **Fate judgment** — 5 hidden conditions silently tracked during battle:
   - Zhang Fei alive at ≥60% HP
   - Zhao Yun killed ≥2 enemies
   - ≥2 rear attacks landed (any unit)
   - ≥3 turns where formation was active (any player unit had ≥1 adjacent ally)
   - Boss (허저) killed
   All 5 met → **REWRITTEN** branch (history changed, mid-section becomes possible)
   Player wiped → **DEFEAT**
   Otherwise → **PARTIAL** (some change, history mostly stands) or **HISTORICAL** (default tragedy)
   Stats panel shows the *final values* but does NOT name the hidden thresholds — player must reason from the data.

## Per-hero passives (production-stub equivalents)

| Hero | Passive | Tactical role |
|---|---|---|
| 장비 | bridge_blocker — 인접한 적 이동력 -1 | Tank holds the bridge choke; AI funnels |
| 조운 | hit_and_run — (declared in HERO_POOL but not coded for prototype tightness) | Assassin via raw stats (MOV 5, ATK 35) |
| 황충 | rear_specialist — 후방 공격 시 ×1.75 (vs. 일반 ×1.50) | Archer rewards positioning that flanks |
| 유비 | command_aura — 인접 아군 +15% ATK | Commander incentivizes formation-density |

## Damage formula (production-stub equivalent)

```
base = max(1, ATK - DEF - terrain_def_bonus)
formation_mult = 1.0 + 0.05 × adjacent_allies   # cap at +0.20
angle_mult = front:1.0 / side:1.25 / rear:1.50 (or 1.75 for 황충)
aura_mult = 1.15 if 인접 유비 else 1.0
final = floor(base × formation_mult × angle_mult × aura_mult), min 1
```

Multipliers stack multiplicatively — a perfectly-positioned 황충 rear attack adjacent to 유비 with 4 adjacent allies = `1.20 × 1.75 × 1.15 ≈ 2.41x` base damage. Compare to a lone front attack at 1.0x. **5x damage spread from positioning alone** = the tactical depth the GDD calls for.

## What's intentionally still missing (per prototype scope)

- Real sprites — placeholder ColorRect + Label (한글 텍스트 OK)
- Sound — none
- Camera controls — fixed
- Animations beyond simple position tween + damage flash
- Multiple chapters (just 장판파)
- Save/load
- Real character data loading (HeroDatabase.json bypassed; inline pool)
- Real autoload integration (no GameBus)
- Status effects from hp-status epic (defend_stance / poison etc.)
- Pathfinding (Manhattan distance only — terrain cost ignored)
- Multi-finger touch (mouse only)

## How to evaluate

Per the MVP Core Hypothesis, look for:

1. **Discovery moment**: After the first run (likely a HISTORICAL or PARTIAL ending), does the stats panel give you enough to *reason* about what to try differently? Without naming the conditions, can you guess which lever to pull?
2. **Replay motivation**: Does "다시 도전" feel like "I want to try X" or "I have to grind"?
3. **Role differentiation**: Does swapping 황충 for 유비 (or vice versa) feel like a meaningfully different battle?
4. **Pillar 1 (formation)**: Did adjacency / facing matter, or did it feel like decoration?
5. **Pillar 4 (story integration)**: Did the opening text + result text frame the battle emotionally? Or did they feel skippable?

After 2-3 runs, see `REPORT.md` for the prototyper's findings + recommendation.

## Cross-references

- Concept: `design/gdd/game-concept.md` (lines 169-208 = pillars; lines 296-322 = MVP definition)
- Previous prototype: `prototypes/vertical-slice/REPORT.md` (technical-only, didn't test the game pillars)
- Production backends NOT used (per prototype skill rules): TurnOrderRunner, HPStatusController, DamageCalc, HeroDatabase, MapGrid, TerrainEffect, UnitRole, BalanceConstants, GameBus
