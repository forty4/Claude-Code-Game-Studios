# Turn Order/Action Management (턴 순서/행동 관리)

> **Status**: Designed
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-04-17
> **Implements Pillar**: Pillar 1 (형세의 전술) + Pillar 3 (모든 무장에게 자리가 있다)

## Overview

Turn Order/Action Management는 전투 중 모든 유닛의 행동 순서를 결정하고, 각
유닛의 턴 내 행동 흐름(이동, 공격, 스킬, 방어, 대기)을 관리하는 Core 시스템이다.
Unit Role System이 산출한 initiative 값(F-4)을 기준으로 매 라운드의 행동 대기열을
구축하며, 라운드 카운터, 유닛별 행동 완료 상태(acted_this_turn), 턴 내 행동
예산(이동 + 행동)을 추적한다. 6개 이상의 시스템 — Grid Battle, Damage Calc,
HP/Status, AI, Battle HUD, Formation Bonus — 이 이 시스템의 순서 정보와 행동
상태를 참조하며, 특히 Scout의 Ambush 패시브(Unit Role CR-2)는 대상의
acted_this_turn 플래그에 직접 의존한다.

플레이어에게 이 시스템은 전투의 리듬이다. 턴 순서 표시줄을 읽고 "기병이
적 궁병보다 먼저 움직인다 — 지금 돌격하면 반격 전에 처치할 수 있다"는 판단을
내리는 것, 아군 척후가 가장 먼저 행동하여 적이 움직이기 전에 기습을 거는 것,
적 책사가 다음 차례인데 아군 보병이 아직 방어 태세에 들어가지 못한 긴장감 —
이 모든 전술적 시간 감각이 이 시스템에서 나온다. 진형이 공간의 전술이라면,
턴 순서는 시간의 전술이다.

MVP 범위: initiative 기반 개별 유닛 행동 순서, 라운드/턴 생명 주기 관리,
유닛당 이동+행동 예산, 행동 완료 상태 추적, 턴 순서 재계산 규칙.

## Player Fantasy

**선수를 잡는 자 (The One Who Seizes Initiative)**

바둑에서 선수(先手)를 잡으면 상대는 응수(應手)해야 한다. 내가 질문을 던지고,
상대는 답해야 한다. 답하는 동안 상대는 자기 계획을 실행할 수 없다. 전장의
턴 순서가 바로 그 선수와 후수(後手)의 구조다.

턴 순서 표시줄을 읽는 것은 바둑판의 흐름을 읽는 것이다. 적 책사가 아군
보병진에 계략을 쓰려 한다 — 하지만 아군 척후가 먼저 행동한다. 척후를 보내
책사를 치면, 적은 계략 대신 후퇴를 선택해야 한다. 그것이 선수다. 적의
기병 둘이 좌익을 위협하지만, 아군 기병이 그들보다 먼저 움직인다. 넓게
우회시키면, 적 기병은 원래 계획을 버리고 응전해야 한다. 적 보병은 재배치해야
하고, 적 궁병은 사선이 바뀐다. 아군 기병 하나의 선수가 적 세 유닛을
후수로 몰아넣었다. 강한 유닛을 가져서가 아니라, 먼저 질문을 던졌기 때문이다.

이것이 이 시스템의 판타지다: 빠르게 치는 것이 아니라, 먼저 생각하는 것.
속도가 아니라 주도권 — 상대의 계획을 시작되기도 전에 무의미하게 만드는,
더 깊은 차원의 선수. 그리고 선수를 잡는 것은 서예의 필순(筆順)과 같다 —
올바른 순서로 획을 그으면 글자가 자연스럽게 완성되고, 순서를 틀리면
글자가 무너진다. 전장에서 유닛의 행동 순서가 곧 필순이다. 올바른 순서로
유닛을 움직이면, 진형이 자연스럽게 완성된다.

*이 시스템은 Pillar 1(형세의 전술)에 시간의 축을 부여한다 — 형세는 유닛이
어디에 서 있는가뿐 아니라, 누가 선수를 쥐고 있는가이다. 공간의 우위와
시간의 우위가 합쳐질 때 형세가 완성된다. Pillar 3(모든 무장에게 자리가 있다)은
시간적 차원을 얻는다 — 척후는 첫 숨에서 가치 있고, 보병은 중반전에서 가치
있으며, 사령관은 진형이 완성되었을 때 빛난다. 모든 무장에게 자리가 있듯,
모든 무장에게 순간이 있다.*

## Detailed Design

### Core Rules

#### CR-1. Turn Structure: Interleaved Initiative Queue

**Rule CR-1a.** Combat uses an **interleaved** model. All units — player-controlled
and AI-controlled — act in a single unified queue ordered by `initiative` (Unit
Role F-4). There is no player phase / enemy phase alternation. One unit acts,
then the next-highest-initiative unit acts, regardless of allegiance.

**Rule CR-1b.** The queue contains exactly all ALIVE units at the moment queue
construction is performed. Dead units are never in the queue. Units that die
mid-round are removed immediately (CR-7).

**Rule CR-1c.** The system makes no architectural distinction between player and
AI units in queue management. `is_player_controlled: bool` is a flag read by the
input layer and AI system respectively, but is invisible to Turn Order logic.

**Design rationale:** A phase-based model would nullify class initiative differentiation
(Scout 1.2× vs. Infantry 0.7×). Interleaved structure makes the turn order bar the
primary tactical information layer, fulfilling the Player Fantasy (선수와 후수).

---

#### CR-2. Round Lifecycle

A **round** is one complete pass through the queue — every ALIVE unit has had the
opportunity to act once.

**Round Start Sequence** (executed once before the first unit acts):

```
R1 — Increment round counter
  current_round_number += 1
  (Initialized to 0 before battle; first round = 1.)

R2 — Reset per-unit acted flags
  For every ALIVE unit: unit.acted_this_turn = false

R3 — Build initiative queue
  Sort all ALIVE units descending by initiative.
  Tie-breaking per CR-5. Queue is a snapshot — not re-sorted mid-round.

R4 — Notify downstream
  Emit round_started(round_number). Battle HUD updates turn order bar.
```

**Per-Unit Turn Sequence** (for each unit as it reaches the front of the queue):

```
T1 — DoT tick (HP/Status)
  If unit has TICK effects (POISON): execute tick damage (HP/Status F-3).
  If current_hp == 0: emit unit_died. Remove from queue. Skip T2–T7.

T2 — Death safety check
  If current_hp == 0: remove from queue. Skip T3–T7.

T3 — Duration expiry (HP/Status)
  Decrement remaining_turns on TURN_BASED effects.
  Remove effects where remaining_turns == 0.
  Check CONDITION_BASED recovery (DEMORALIZED: ally hero within
  Manhattan ≤ 2 → remove).

T4 — Activate unit turn
  unit.turn_state = ACTING
  Emit unit_turn_started(unit_id).
  Player unit: present action menu (CR-3, CR-4).
  AI unit: AI system resolves action.

T5 — Execute action budget
  Unit spends tokens (CR-3). Actions resolve synchronously.

T6 — Mark acted
  If unit spent ≥ 1 token (MOVE or ACTION): acted_this_turn = true
  If unit WAITed without spending tokens: acted_this_turn = false
  unit.turn_state = DONE
  Emit unit_turn_ended(unit_id, acted_this_turn)

T7 — Victory-condition check
  If all enemy units DEAD: emit victory_condition_detected(PLAYER_WIN). Halt.
  If all player units DEAD: emit victory_condition_detected(PLAYER_LOSE). Halt.
  Else: proceed to next queue entry.
  (Turn Order detects; Grid Battle owns emission of battle_ended / battle_outcome_resolved
  per ADR-0001 single-owner rule. Grid Battle consumes victory_condition_detected and
  transitions to RESOLUTION.)
```

**Round End Sequence** (after last unit completes without victory_condition_detected):

```
RE1 — Emit round_ended(round_number)
RE2 — Draw check: if current_round_number >= ROUND_CAP (default 30):
       emit victory_condition_detected(DRAW)
       (Grid Battle consumes and emits battle_ended per ADR-0001 single-owner rule.)
RE3 — Return to Round Start (R1)
```

---

#### CR-3. Per-Unit Action Budget

**Rule CR-3a.** Each unit has exactly one **MOVE token** and one **ACTION token**
per turn. Tokens are binary (available or spent). No carry-over between turns.

**Rule CR-3b. MOVE token.** Allows movement up to `effective_move_range` (Unit
Role F-5) subject to terrain costs (Unit Role CR-4). Spent when the player/AI
confirms movement destination. Cancel before confirmation = no spend.

**Rule CR-3c. ACTION token.** Allows one of: Attack, Use Skill, or Defend.
Only one per turn.

**Rule CR-3d. Order flexibility.** Tokens may be spent in either order:
- Move → Attack (standard)
- Attack → Move (retreat after striking)
- Move → Defend (reposition into chokepoint, then hold)
- Move only (end turn without acting — ACTION unspent)
- Action only (attack without moving — MOVE unspent)
- Neither (WAIT — both unspent)

**Rule CR-3e. DEFEND spends ACTION token.** Entering DEFEND_STANCE (HP/Status
CR-6 SE-3) costs the ACTION token. A unit may Move then Defend.

**Rule CR-3f. acted_this_turn semantics.** `acted_this_turn = true` at T6 if
and only if the unit spent at least one token (MOVE, ACTION, or both) during T5.
A unit that WAITed without spending any token: `acted_this_turn = false`. This
is the precise flag Scout Ambush checks (Unit Role CR-2, EC-8, EC-9).

**Rule CR-3g. Irreversibility.** Once a token is spent (movement confirmed,
attack resolved), it cannot be unspent. UI must show confirmation before
irreversible token expenditure.

---

#### CR-4. Action Types

Exhaustive list of MVP action types:

| Action | Token | Conditions | Effect |
|--------|-------|-----------|--------|
| **MOVE** | MOVE | Unit ALIVE, MOVE available, not movement-locked | Traverse path within budget |
| **ATTACK** | ACTION | Unit ALIVE, target in attack range | Initiates Damage Calc pipeline |
| **USE_SKILL** | ACTION | Unit ALIVE, target in skill range, skill off cooldown | Passes to Damage Calc/status pipeline |
| **DEFEND** | ACTION | Unit ALIVE, not EXHAUSTED | Applies DEFEND_STANCE (HP/Status SE-3) |
| **WAIT** | none | Always available | Ends turn. Unspent tokens forfeit |

**Rule CR-4a.** ATTACK is the only action that triggers counter-attacks (by default).
USE_SKILL may or may not trigger counter-attack depending on skill definition (Damage
Calc GDD). DEFEND never triggers counter-attacks.

**Rule CR-4b.** DEFEND_STANCE release: When a DEFEND_STANCE unit selects MOVE or
ATTACK on a subsequent turn, DEFEND_STANCE is released at action declaration —
before resolution. Per HP/Status EC-14.

**Rule CR-4c.** DEFEND_STANCE movement lock: A unit in DEFEND_STANCE cannot MOVE.
MOVE is grayed out in the action menu. The unit may still ATTACK or USE_SKILL
(releasing DEFEND_STANCE per CR-4b) or WAIT.

**Rule CR-4d.** No multi-action skills (MVP). No skill allows spending the ACTION
token twice. Chain effects resolve within the single ACTION resolution.

---

#### CR-5. Tie-Breaking Rule

When units have identical `initiative`, the deterministic cascade is:

| Step | Criterion | Rationale |
|------|-----------|-----------|
| 0 | Higher `initiative` (F-4) | Primary ordering |
| 1 | Higher `stat_agility` (Hero DB) | Speed stat — Scout wins ties, Infantry loses. Readable by player |
| 2 | Player-controlled first | Ties feel fair. Only fires when stat_agility also tied (rare) |
| 3 | Lower `unit_id` (battle initialization order) | Deterministic, stable. Players never reach this step |

**Rule CR-5a.** Tie-breaking is computed once during queue construction at R3.
Fixed for the entire round.

**Rule CR-5b.** The same cascade is used in the Battle HUD turn order bar —
visual matches mechanical order exactly.

---

#### CR-6. Static Initiative (MVP)

**Rule CR-6a.** Initiative is calculated once at battle start (BI-2). The queue
is rebuilt each round from the same initiative values. No mid-battle recalculation.

**Rule CR-6b.** Status effects do NOT modify initiative in MVP. If future effects
modify initiative (post-MVP), they apply at the next Round Start R3 only — never
mid-round. This is a binding contract for future GDD authors.

**Rule CR-6c.** Unit death does not re-sort the queue. Dead units are removed;
remaining units keep their positions.

**Rule CR-6d.** No dynamic re-queuing in MVP. No mechanic allows "take another
turn immediately" or "skip to front of queue."

**Design rationale:** The Player Fantasy (선수를 잡는 자) requires the initiative
bar to be a promise, not a suggestion. Static initiative makes the full-battle
order readable — players can plan 3–4 turns ahead.

---

#### CR-7. Death Mid-Round

**Rule CR-7a.** When `unit_died` is received, Turn Order removes the unit from
the queue immediately. If the unit is currently acting (dies from counter-attack
during T5), T5 is interrupted — no further actions, T6/T7 execute with the dead
unit omitted.

**Rule CR-7b.** A dead unit's `acted_this_turn` flag is irrelevant. No system
should query it for dead units.

**Rule CR-7c.** Remaining units do not shift positions after a removal.

**Rule CR-7d. Acting unit dies from counter-attack sequence:**
1. Unit A attacks Unit B → Damage Calc resolves
2. Counter-attack: Unit B retaliates → Unit A takes damage
3. `unit_died` emitted for Unit A → Turn Order removes A from queue
4. T6 skipped (no `acted_this_turn` update — unit is dead)
5. T7 executes: check battle-end conditions

---

#### CR-8. No Delay Mechanic (MVP)

**Rule CR-8a.** There is no queue repositioning. WAIT ends the turn in place —
the unit does not move to the back of the queue.

**Rule CR-8b.** A unit that WAITs with tokens unspent simply forfeits them.
`acted_this_turn = false` (CR-3f). The unit remains in DONE state.

**Rule CR-8c.** No status effect in MVP causes automatic turn skipping. If STUN
is introduced post-MVP, Turn Order auto-selects WAIT at T4 for stunned units.

**Design rationale:** No delay prevents Scout Ambush degenerate loop (all Scouts
delay until every enemy has acted → Ambush always available). The 선수 fantasy
is about seizing initiative before battle, not renegotiating it during battle.

---

#### CR-9. Battle Initialization

Executed once before Round 1:

```
BI-1 — Collect participating units
  Build ALIVE set: all player + all enemy units.
  MVP size: 8–10 per side → 16–20 total.

BI-2 — Compute initiative
  For each unit: initiative = Unit Role F-4 (already computed during
  battle preparation, not recomputed).

BI-3 — Initialize per-unit flags
  For each unit: acted_this_turn = false, turn_state = IDLE

BI-4 — Initialize counters
  current_round_number = 0 (incremented to 1 at R1)

BI-5 — Apply battle-start effects
  Formation bonuses applied. No DEFEND_STANCE at start.

BI-6 — Proceed to Round 1
```

---

### States and Transitions

#### Round States

| State | Description |
|-------|-------------|
| `BATTLE_NOT_STARTED` | Initial state. Before BI-1 |
| `BATTLE_INITIALIZING` | BI-1 through BI-5 |
| `ROUND_STARTING` | R1–R4: counter increment, flag reset, queue build |
| `ROUND_ACTIVE` | Queue processing. Individual unit turns executing |
| `ROUND_ENDING` | RE1–RE2: bookkeeping and draw check |
| `BATTLE_ENDED` | Terminal. No further processing |

Transitions:
```
BATTLE_NOT_STARTED → BATTLE_INITIALIZING  (battle trigger)
BATTLE_INITIALIZING → ROUND_STARTING     (BI-6)
ROUND_STARTING → ROUND_ACTIVE            (R4 complete)
ROUND_ACTIVE → ROUND_ENDING              (queue exhausted, no victory_condition_detected)
ROUND_ACTIVE → BATTLE_ENDED              (T7: victory_condition_detected emitted — Grid Battle transitions to RESOLUTION)
ROUND_ENDING → ROUND_STARTING            (RE3: next round)
ROUND_ENDING → BATTLE_ENDED              (RE2: victory_condition_detected(DRAW) emitted — Grid Battle transitions to RESOLUTION)
```

#### Per-Unit Turn States

| State | Description |
|-------|-------------|
| `IDLE` | Alive, not currently acting. Waiting in queue |
| `ACTING` | This unit's turn (T4–T5). Action menu presented or AI resolving |
| `DONE` | Turn completed this round (T6). Waiting for round end |
| `DEAD` | `current_hp == 0`. Removed from queue permanently |

Transitions:
```
IDLE → ACTING     (unit reaches front of queue, T4)
ACTING → DONE     (T5 complete, T6 marks acted)
ACTING → DEAD     (unit dies during T5 — counter-attack)
DONE → IDLE       (next round R2 resets flags)
IDLE → DEAD       (DoT at T1 kills unit before T4)
DONE → DEAD       (DoT at T1 next round)
```

**IDLE vs. DONE:** Both describe units not currently acting. The distinction
matters for `acted_this_turn`: IDLE → `false`, DONE → `true` (unless WAIT
without token spend, which is DONE with `false`). This is the Scout Ambush flag.

#### Action Token States (per unit, per turn)

| State | MOVE | ACTION | Description |
|-------|------|--------|-------------|
| `FRESH` | available | available | Turn just started |
| `MOVED_ONLY` | spent | available | Moved, can still Attack/Skill/Defend |
| `ACTED_ONLY` | available | spent | Attacked/Defended, can still Move |
| `FULLY_SPENT` | spent | spent | Both tokens used |
| `TURN_ENDED` | varies | varies | WAIT selected, turn over |

---

### Interactions with Other Systems

#### Upstream (reads from)

| System | Data Read | When |
|--------|-----------|------|
| Unit Role | `initiative` (F-4) per unit | BI-2 (once at battle start) |
| Hero DB | `stat_agility` (tie-breaking CR-5) | R3 (per queue build) |
| HP/Status | `unit_died` signal | T1, T5 (on death events) |
| Balance/Data | `ROUND_CAP`, turn order config | BI-1, RE2 |

#### Downstream (provides to)

| Consumer | Data Provided | When |
|----------|---------------|------|
| Damage Calc / Unit Role | `acted_this_turn(unit_id)`, `current_round_number` | Per-attack (Scout Ambush) |
| HP/Status | DoT tick invocation at T1, duration decrement at T3 | Every unit turn |
| Grid Battle | `round_started`, `unit_turn_started`, `unit_turn_ended`, `battle_ended` signals | Round/turn events |
| Battle HUD | `TurnOrderSnapshot` (ordered queue with acted flags) | R4, T6, on death |
| AI System | `TurnOrderSnapshot`, `acted_this_turn` for all units | T4 (AI turn) |

#### Interface Contracts

**Contract 1: Turn Order → Damage Calc** (queried per attack)
```
get_acted_this_turn(unit_id) → bool
get_current_round_number() → int
```
Read-only. Damage Calc calls to evaluate Scout Ambush condition.

> **Ratified 2026-04-18** by `design/gdd/damage-calc.md` §F (upstream Turn
> Order dependency) + §D F-DC-5 Ambush gate: the Ambush passive fires iff
> `get_current_round_number() >= 2 AND NOT get_acted_this_turn(defender)`.
> Worked example D-9 (AC-DC-09) uses `round=3` + `defender not acted`.
> AMBUSH_BONUS=1.15 is owned by damage-calc.md; the gate predicate inputs
> are owned here. Turn Order must NOT change the semantics of these two
> getters without coordinated damage-calc.md patch — they are a locked
> cross-GDD ABI.

**Contract 2: HP/Status → Turn Order** (signal-driven)
```
signal unit_died(unit_id)  # Turn Order removes from queue (CR-7a)
hp_status.tick_dot_effects(unit_id) → bool  # returns true if unit died
```

**Contract 3: Turn Order → Battle HUD** (push on state change)
```
struct TurnOrderSnapshot:
  round_number: int
  queue: Array[TurnOrderEntry]

struct TurnOrderEntry:
  unit_id: int
  is_player_controlled: bool
  initiative: int
  acted_this_turn: bool
  turn_state: enum {IDLE, ACTING, DONE, DEAD}
```

**Contract 4: Turn Order → Grid Battle** (event signals)
```
signal round_started(round_number: int)
signal unit_turn_started(unit_id: int)
signal unit_turn_ended(unit_id: int, acted: bool)
signal victory_condition_detected(result: enum {PLAYER_WIN, PLAYER_LOSE, DRAW})
# `battle_ended` is NOT a Turn Order signal. Per ADR-0001 single-owner rule, Grid Battle
# is the sole emitter of `battle_ended` / `battle_outcome_resolved` (GameBus). Turn Order
# emits `victory_condition_detected` to notify Grid Battle that a terminal condition has
# been reached; Grid Battle evaluates and emits the authoritative result. See
# `grid-battle.md` §CR-7 and §Dependencies (Turn Order row, CLEANUP ownership annotation).
```

**Contract 5: Turn Order → AI System** (on AI turn)
```
ai_system.request_action(unit_id, queue_snapshot) → ActionDecision
```
AI returns action; Turn Order executes within T5.

## Formulas

모든 상수는 `assets/data/config/turn_order_config.json` 또는
`assets/data/config/balance_constants.json`에서 로딩. 하드코딩 금지.

---

### F-1. Queue Sort Order (Tie-Breaking Cascade)

Sort all ALIVE units by the following fields, in priority order:

`sort_order = (initiative DESC, stat_agility DESC, is_player_controlled DESC, unit_id ASC)`

| Variable | Source | Range | Description |
|----------|--------|-------|-------------|
| `initiative` | Unit Role F-4 | 1–200 | Primary ordering. Higher acts first |
| `stat_agility` | Hero DB | 1–100 | Secondary. Higher agility wins ties |
| `is_player_controlled` | Battle init | 0 or 1 | Tertiary. Player (1) before AI (0) |
| `unit_id` | Battle init | 1–N (N≤20) | Quaternary. Lower ID first (stable) |

**Output:** Deterministic total ordering of all ALIVE units. No two units share
the same position — `unit_id` is unique, so the cascade always resolves.

**Example — Scout vs. Infantry tied at initiative 120:**
- Scout: init=120, agi=85, player=1, id=2
- Infantry: init=120, agi=60, player=0, id=5
- Resolved at Step 1 (stat_agility): Scout (85) > Infantry (60) → **Scout first**

**Example — Two player Cavalry tied at init 108, agi 70:**
- Cavalry A: init=108, agi=70, player=1, id=3
- Cavalry B: init=108, agi=70, player=1, id=7
- Resolved at Step 4 (unit_id): A (3) < B (7) → **Cavalry A first**

---

### F-2. Charge Budget Accumulation

Turn Order tracks per-unit move cost accumulation for Cavalry's Charge passive
(Unit Role CR-2, EC-6).

```
accumulated_move_cost += floor(base_terrain_cost × class_multiplier)
charge_ready = (accumulated_move_cost >= CHARGE_THRESHOLD)
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `accumulated_move_cost` | int | 0–60 | Running sum of terrain costs this turn. Reset to 0 at T4 |
| `base_terrain_cost` | int | 7–20 | Tile base cost (Map/Grid, Unit Role CR-4) |
| `class_multiplier` | float | 0.7–3.0 | Class terrain multiplier (Unit Role CR-4) |
| `CHARGE_THRESHOLD` | const int | **40** | "≥4 Plains tiles" equivalent. Config: `turn_order_config.json` |
| `charge_ready` | bool | — | Evaluated once at ATTACK declaration, not per-tile |

**Output Range:** `accumulated_move_cost` ∈ [0, 60]. `charge_ready` = bool.

**Example — Cavalry (move_budget=50) path: Plains→Plains→Hills→Plains:**
- Tile 1 (Plains): floor(10×1.0) = 10 → accumulated=10
- Tile 2 (Plains): floor(10×1.0) = 10 → accumulated=20
- Tile 3 (Hills): floor(15×1.5) = 22 → accumulated=42
- Tile 4: cost=10 > remaining=8 → cannot enter. Movement stops.
- At attack: accumulated=42 ≥ 40 → **charge_ready = true**

**Reset rule:** `accumulated_move_cost = 0` at T4 (unit turn start). Does not
persist between turns.

---

### F-3. Round Cap — Constant

| Variable | Type | Value | Description |
|----------|------|-------|-------------|
| `ROUND_CAP` | const int | **30** | Maximum rounds before DRAW. Config: `turn_order_config.json` |

No formula — flat comparison at RE2: `current_round_number >= ROUND_CAP → DRAW`.
The cap guarantees battle termination in degenerate cases (e.g., two high-defense
units with no lethal paths). Not scaled to map size or unit count.

## Edge Cases

### Turn Sequence Timing

**EC-01. DoT kills unit at T1 — morale anchor propagation**
- **If POISON tick at T1 reduces a `is_morale_anchor` hero's HP to 0**: `unit_died`
  emitted immediately inside T1. DEMORALIZED propagation (HP/Status CR-8c) fires
  synchronously on the death signal. Unit removed from queue. T2–T7 entirely
  skipped. Battle-end check fires via `unit_died` signal (see EC-06).

**EC-02. DEFEND_STANCE survives being attacked — release only on holder's own turn**
- **If a DEFEND_STANCE unit is attacked during another unit's T5**: DEFEND_STANCE
  is NOT released. It is ACTION_LOCKED — released only when the holder declares
  MOVE or ATTACK on their own T4/T5 (HP/Status EC-14, CR-4b). At the holder's
  T3, DEFEND_STANCE is not touched (it is ACTION_LOCKED, not TURN_BASED or
  CONDITION_BASED). The unit enters T4 still in DEFEND_STANCE.

**EC-03. DEMORALIZED recovery timing — ally hero moves adjacent mid-round**
- **If an ally hero moves adjacent to a DEMORALIZED unit during another unit's T5**:
  The DEMORALIZED unit does NOT recover immediately. Recovery is checked at T3 of
  the DEMORALIZED unit's own turn. The unit may act this round with the debuff
  still active, even if the rescuing hero arrived earlier in the same round.

**EC-04. Mutual kill — both attacker and defender die**
- **If Unit A attacks Unit B, B dies from the attack, then A dies from B's
  counter-attack**: `unit_died` emitted for B first (primary attack resolves before
  counter-attack), then for A. T7 checks: **PLAYER_WIN is evaluated before
  PLAYER_LOSE**. If A was the last player unit and B was the last enemy unit,
  result is **PLAYER_WIN** (enemy died first in resolution order). This is an
  explicit binding rule, not an implied ordering.

---

### Death Timing

**EC-05. Dead unit was already DONE (acted earlier this round)**
- **If a DONE unit dies from DoT at next round's T1**: The unit was past the queue
  pointer for the current round. T1 only fires when the queue pointer reaches that
  unit in the new round's queue. R3 builds the queue from ALIVE units only — the
  unit was still alive at R3 but dies at T1. Queue removal at T1 is clean. No
  special handling for "past-pointer" entries needed.

**EC-06. Last enemy dies from DoT at T1 — T7 is skipped**
- **If the last enemy unit dies from POISON at T1 of its own turn**: T2–T7 are
  skipped (per CR-2 T1 spec). **Battle-end check must fire on `unit_died` signal,
  not exclusively at T7.** Implementation contract: Grid Battle listens to
  `unit_died` and evaluates `all_enemies_dead()` on every death event, regardless
  of where in the turn sequence it occurs. This is a binding contract for Grid
  Battle GDD.

**EC-07. All enemies die from DoT across multiple T1s in the same round**
- **If enemy units die one-by-one as each reaches T1**: Deaths are sequential by
  queue order, not simultaneous. After each death, battle-end check fires (EC-06).
  The round halts at the first battle-end trigger. No "simultaneous death" special case.

**EC-08. Acting unit dies from counter-attack — queue contains one more entry**
- **If the acting unit dies at T5 from counter-attack, and one more unit remains
  in queue**: T6 skipped for dead unit. T7 fires: checks battle-end. If no
  battle_ended, the next unit in queue proceeds normally to T1.

---

### Action Budget Corner Cases

**EC-09. DEFEND_STANCE unit selects MOVE next turn — release timing**
- **If a DEFEND_STANCE unit declares MOVE on its next turn**: DEFEND_STANCE releases
  at MOVE declaration, before path traversal (HP/Status EC-14, CR-4b). The unit
  traverses the path without DEFEND_STANCE. It may then declare ATTACK with the
  ACTION token — DEFEND_STANCE is already gone.

**EC-10. Double-DEFEND (unit already in DEFEND_STANCE selects DEFEND again)**
- **If DEFEND_STANCE unit spends ACTION token on DEFEND**: HP/Status CR-5c applies
  (same effect refresh). DEFEND_STANCE duration refreshes — no additional effect.
  ACTION token is spent. `acted_this_turn = true`. Wastes the token for no benefit.
  UI may show a tooltip warning but does not prevent the action.

**EC-11. ATTACK misses (evaded), then unit attempts MOVE**
- **If ATTACK resolves as MISS (evasion)**: ACTION token was spent at declaration,
  not contingent on hit. MISS does not refund the token. Unit may still spend MOVE
  token (Attack→Move per CR-3d). `acted_this_turn = true`.

**EC-12. Unit moves, then selects WAIT**
- **If unit spends MOVE token, then WAITs without using ACTION**: `acted_this_turn
  = true` at T6 (CR-3f: at least one token spent). ACTION token forfeited unspent.
  This is the standard "reposition without attacking" play.

---

### Scout Ambush Interactions

**EC-13. Round 1 — Scout attacks an unacted target**
- **If Scout attacks at Round 1 with target `acted_this_turn = false`**: Ambush
  does NOT fire. Unit Role EC-8: `current_round_number >= 2` gate suppresses
  Ambush regardless of the acted flag. The round-number gate fires first.

**EC-14. Target spent MOVE token only (moved but did not attack) — Scout attacks**
- **If target moved but did not use ACTION token**: `acted_this_turn = true`
  (CR-3f, any token spent). Ambush does NOT fire. A unit that relocated is no
  longer "unaware." Moving forfeits Ambush vulnerability.

**EC-15. Target WAITed (no tokens spent) — Scout attacks**
- **If target chose WAIT, `acted_this_turn = false`**: Ambush conditions met on
  Round 2+. +15% damage, no counter-attack. WAIT is the highest-risk choice
  against an opposing Scout. This creates meaningful tension around the WAIT option.

---

### Charge Accumulation

**EC-16. Cavalry moves 0 tiles then attacks**
- **If Cavalry spends ACTION on ATTACK without spending MOVE**: `accumulated_move_cost
  = 0` (reset at T4). `charge_ready = (0 >= 40) = false`. Charge does not trigger.

**EC-17. Cavalry path through expensive terrain — short net displacement but high cost**
- **If Cavalry path is Hills(22) + Plains(10) + Plains(10) = 42 total cost, ending
  only 3 tiles from start**: `accumulated_move_cost = 42 >= 40` → `charge_ready =
  true`. F-2 accumulates actual path cost, not straight-line distance. Tactical
  repositioning through rough terrain earns Charge budget. Intentional design.

---

### Round Cap

**EC-18. Round 30 ends without decisive outcome**
- **If the last unit in Round 30's queue completes T7 with no `battle_ended`**:
  RE1 emits `round_ended(30)`. RE2: `30 >= 30 = true` → `victory_condition_detected(DRAW)` emitted by Turn Order; Grid Battle emits `battle_ended(DRAW)` per ADR-0001 single-owner rule.
  RE3 never executes.

**EC-19. Last enemy dies in T7 of Round 30 — WIN or DRAW?**
- **If T7 detects all enemies dead during Round 30**: T7 emits `victory_condition_detected(PLAYER_WIN)`; Grid Battle emits `battle_ended(PLAYER_WIN)` per ADR-0001 single-owner rule.
  RE1/RE2/RE3 never execute. **PLAYER_WIN takes precedence** because T7 fires before
  RE2 in the execution sequence. ROUND_CAP DRAW is a fallback only when no decisive
  outcome occurs within the round.

## Dependencies

### 상위 의존성 (이 시스템이 의존하는 것)

| System | 의존 유형 | 참조 데이터 | 참조 시점 | GDD Status |
|--------|----------|-----------|----------|------------|
| **Hero Database** | Hard | `base_initiative_seed`, `stat_agility` (tie-breaking CR-5) | BI-2 (initiative 계산), R3 (큐 정렬) | Designed |
| **Unit Role System** | Hard | `initiative` (F-4), `effective_move_range` (F-5), terrain cost table (CR-4), passive tags (`passive_charge`, `passive_ambush`) | BI-2, T5 (Charge 누적, Ambush 판정) | Designed |
| **HP/Status System** | Hard | `unit_died` signal, `tick_dot_effects()`, duration expiry, DEFEND_STANCE state | T1 (DoT), T2 (death check), T3 (효과 만료), T5 (사망 시그널) | Designed |
| **Balance/Data System** | Hard | `ROUND_CAP` (turn_order_config.json), `CHARGE_THRESHOLD` (turn_order_config.json) | BI-1 (config 로딩), RE2 (라운드 캡 비교) | Designed |

**모든 상위 의존성 GDD가 설계 완료.** 잠정 가정 없음.

### 하위 의존성 (이 시스템에 의존하는 것)

| Consumer | 의존 유형 | 제공 데이터 | 참조 시점 | GDD Status |
|----------|----------|-----------|----------|------------|
| **Damage/Combat Calculation** | Hard | `get_acted_this_turn(unit_id)` → bool, `get_current_round_number()` → int | 공격 시 (Scout Ambush 판정) | Not Started |
| **Grid Battle System** | Hard | `round_started`, `unit_turn_started`, `unit_turn_ended`, `victory_condition_detected` signals | 라운드/턴 이벤트 — Grid Battle owns `battle_ended` emission per ADR-0001 single-owner rule | Not Started |
| **Battle HUD** | Hard | `TurnOrderSnapshot` (Contract 3) | R4, T6, 유닛 사망 시 | Not Started |
| **AI System** | Hard | `TurnOrderSnapshot`, `acted_this_turn` for all units | T4 (AI 턴 시작) | Not Started |
| **Formation Bonus System** | Soft | `round_started` signal (진형 보너스 재계산 트리거) | R4 | Not Started |

### 크로스 시스템 계약

이 GDD에서 정의된 계약:

1. **Contract 1: Turn Order → Damage Calc** — `get_acted_this_turn(unit_id)` → bool, `get_current_round_number()` → int. 읽기 전용. Scout Ambush 조건 판정용.
2. **Contract 2: HP/Status → Turn Order** — `unit_died(unit_id)` signal → 큐 즉시 제거 (CR-7a). `tick_dot_effects(unit_id)` → bool (사망 여부 반환).
3. **Contract 3: Turn Order → Battle HUD** — `TurnOrderSnapshot` struct 푸시. 상태 변경 시마다 갱신.
4. **Contract 4: Turn Order → Grid Battle** — 4개 이벤트 signal (`round_started`, `unit_turn_started`, `unit_turn_ended`, `victory_condition_detected`). Turn Order는 terminal 조건 감지 시 `victory_condition_detected` emit; Grid Battle이 `battle_ended` / `battle_outcome_resolved` 단독 emit (ADR-0001 single-owner rule). Grid Battle은 `unit_died` signal에서도 승리 조건 판정 수행 (EC-06 binding).
5. **Contract 5: Turn Order → AI System** — `ai_system.request_action(unit_id, queue_snapshot)` → `ActionDecision`. AI가 행동 결정, Turn Order가 T5 내 실행.

### 양방향 일관성 검증

| 이 GDD에서의 참조 | 상대 GDD 상태 | 일치 여부 |
|-----------------|-------------|----------|
| Hero DB → Turn Order: `base_initiative_seed`, `stat_agility` | Hero DB 하위 의존성: "Turn Order/Action Mgmt \| Hard \| `get_hero()` \| base_initiative_seed, stat_agility(보조)" | **일치** |
| Unit Role → Turn Order: `initiative` (F-4), passive tags | Unit Role 하위 의존성: "Turn Order/Action Management \| `initiative` (F-4), passive tags for `acted_this_turn` checks (EC-8, EC-9)" | **일치** |
| HP/Status → Turn Order: `unit_died` signal | HP/Status 하위 의존성 테이블에 Turn Order 미기재 | **GAP** |
| Balance/Data → Turn Order: `ROUND_CAP`, config 로딩 | Balance/Data 하위 의존성 테이블에 Turn Order 미기재 | **GAP** |

### 의존성 갭 수정 항목

1. **HP/Status GDD** (`design/gdd/hp-status.md`): 하위 의존성 테이블에 추가 필요 — `Turn Order/Action Mgmt | Hard | unit_died signal, tick_dot_effects() 호출 | T1 DoT 실행, T3 효과 만료`
2. **Balance/Data GDD** (`design/gdd/balance-data.md`): 하위 의존성 테이블에 추가 필요 — `Turn Order/Action Mgmt | Hard | 초기화 시 단일 로드 | turn_order_config.json (ROUND_CAP, CHARGE_THRESHOLD)`

## Tuning Knobs

모든 값은 `assets/data/config/turn_order_config.json`에서 로딩. 하드코딩 금지.

| Knob | Default | Safe Range | Too High | Too Low | Affects | Config Key |
|------|---------|-----------|----------|---------|---------|------------|
| `ROUND_CAP` | 30 | 20–50 | 느린 전투도 항상 끝까지 진행 — DRAW 실질 무효화. 고방어 교착 방치 | 10–15면 긴 전투가 강제 DRAW로 끝남. 전략적 방어 플레이 페널티 | 전투 최대 길이, DRAW 빈도 | `round_cap` |
| `CHARGE_THRESHOLD` | 40 | 25–60 | 높으면 Charge 발동 거의 불가능 — Cavalry 패시브 사문화. 60이면 Plains 6칸 필요 | 낮으면 1–2칸 이동으로 Charge 발동 — 기병 매턴 추가 데미지. 밸런스 붕괴 | Cavalry Charge 발동 빈도, 기병 기동 보상 | `charge_threshold` |
| `INIT_SCALE` | 2.0 | 1.5–3.0 | initiative 분포 확대 → 빠른 유닛과 느린 유닛 격차 극대화. Scout가 항상 1번 | initiative 분포 축소 → 모든 유닛 비슷한 순서. 병종 차별화 약화 | 턴 순서 예측 가능성, 병종 정체성 | `init_scale` |
| `INIT_CAP` | 200 | 150–300 | Cap 도달 유닛 감소 → 순서 분포 넓어짐 (기능적 변화 미미) | Cap 도달 유닛 증가 → 고 initiative 유닛 간 tie 다발. tie-breaker 의존도 상승 | initiative 상한, tie 빈도 | `init_cap` |

### 상호작용 경고

- **`INIT_SCALE` × `INIT_CAP`**: INIT_SCALE을 3.0으로 올리면서 INIT_CAP을 150으로 내리면, 대부분의 유닛이 cap에 도달하여 initiative가 사실상 무의미해진다.
- **`CHARGE_THRESHOLD` × Unit Role `move_budget`**: Cavalry의 `effective_move_range`(F-5)가 변경되면 CHARGE_THRESHOLD도 재검토 필요. 현재 기준: Cavalry move_range=5 → move_budget=50 → Plains 경로 4칸(40) ≥ threshold.

### 이 GDD에서 관리하지 않는 관련 Knob (타 GDD 소유)

| Knob | Owner GDD | 이 시스템에 미치는 영향 |
|------|-----------|---------------------|
| `class_init_mult` (병종별) | Unit Role | initiative 분포 직접 결정. Scout 1.2 → Infantry 0.7 범위 |
| `base_initiative_seed` (무장별) | Hero DB | initiative 입력값. 범위 1–100 |
| `POISON_TICK_DAMAGE` | HP/Status | T1 DoT 사망 빈도에 영향 → 전투 중 큐 변동 빈도 |
| `DEFEND_STANCE_DR` | HP/Status | DEFEND 선택 가치 결정 → ACTION 토큰 사용 패턴 |

## Visual/Audio Requirements

### 1. Turn Order Bar (턴 순서 표시줄)

목간(木簡) — 가로로 나열된 대나무 목찰 형태. 유닛당 1슬립: 최소 44×52px (터치 안전).
초상화 썸네일 중앙, 하단에 진영 색띠 (청회=아군, 묵회=적). 좌→우로 현재→미래 순서.
7+ 유닛 시 수평 스크롤 (스프링 감속). 전장과 시선을 경쟁하지 않을 것 — 장수의 명령
목록처럼 여백에 위치.

### 2. Active Unit Highlight (행동 유닛 강조)

행동 중 유닛의 목찰 1.2× 확대, 2px 청회 테두리 (opacity 85%→100%, 1.2초 루프).
전장: 유닛 스프라이트에 먹번짐 후광 — 발광 링이 아닌 실루엣 잉크의 외향 번짐.
붓을 들어올린 자리에 남은 유묵(遊墨)의 느낌.

### 3. Round Transition (라운드 전환)

수직 먹물 세척이 화면 전폭을 200ms에 통과 (군사 장부 페이지 넘김). 상단 구석에
라운드 번호 인장(印鑑) — 갈필 숫자, 사각 인감 프레임. 단일 저고(低鼓) 타격.
강조가 아닌 구두점.

**Audio**: 타이코 단타, 80–100ms 감쇠. 그 뒤의 정적이 핵심.

### 4. Action Token Feedback (행동 토큰 피드백)

MOVE/ACTION 토큰은 유닛 정보 패널 옆 소형 벼루 아이콘. 가용=먹 밀도 100%.
소진=opacity 30% + 가는 수평 취소선 (장부에서 연한 먹으로 지운 느낌).
소진 시 애니메이션 없음 — 1프레임 즉시 전환. 결단의 날카로움.

**Audio**: 짧은 종이 미끄러짐 — 건조하고, 절제되고, 최종적.

### 5. WAIT Action (대기)

목찰이 큐 끝으로 느리게 이동 (300ms, ease-out). Opacity 60% 감소, 구석에 모래시계
아이콘 (10×10px, 먹선). 전장: 스프라이트 약간 어두워지며 대기 자세 복귀.
벌이 아닌 물러남의 고요함.

**Audio**: 척팔(尺八) 반음 해방 — 매우 짧은 숨결. 음정 없이 바람만.

### 6. Battle End (전투 종료)

**WIN**: 전장 동작 정지. 하단에서 먹물 오버레이 상승 (0%→60%, 1.5초). 중앙에
전장 인장(印) 스탬프 256×256px, 깊은 먹. 서예 필체: **勝**. 2초에 걸쳐 암전.
Audio: 종(鐘) 단타, 긴 여운, 자연 감쇠.

**LOSE**: 동일 세척, 인장 스탬프 중 균열 — 중심에서 방사형 금 발생. **敗**.
Audio: 동일 종, 200ms에 즉시 차단.

**DRAW**: 인장 불완전 — 반쯤 찍고 들어올린 형태. **引分**.

### 7. Death Removal (사망 제거)

사망 유닛의 목찰이 400ms에 걸쳐 순수 먹회색으로 탈색, 이후 opacity 0%로 페이드
(빗물에 먹이 씻기는 느낌). 빈 공간은 200ms 유지 후 인접 목찰이 300ms에 걸쳐 채움.
부재가 시간을 차지한 뒤 사라지는 의도적 연출.

**Audio**: 고금(古琴) 담현(彈弦) 단음 + 정적.

### 총괄 원칙

색상은 이 시스템에서 감정 전달 수단이 아니다 — 운명 분기 시스템 전용. 턴 순서의
모든 피드백은 **먹 밀도, 투명도, 크기, 소리** 네 가지 레버만 사용한다. 색으로
긴급함을 전달하려는 디자인이 나오면 네 레버 중 하나로 전환할 것.

## UI Requirements

### Turn Order Bar Layout

- **Position**: 화면 상단 중앙, 전장 뷰 위 여백
- **방향**: 좌→우 (현재 행동 유닛 → 미래)
- **최대 표시**: 8슬립 동시 표시. 초과 시 수평 스크롤 + 끝단 "…" 인디케이터
- **터치 타겟**: 각 목찰 최소 44×52px (Input Handling GDD 터치 가이드라인 준수)
- **목찰 탭 동작**: 해당 유닛의 전장 위치 하이라이트 (카메라 이동 없음, 타일 강조만)

### Action Menu (행동 메뉴)

- **표시 조건**: 아군 유닛 T4 활성화 시 — 전장 유닛 위 또는 옆에 컨텍스트 메뉴
- **항목**: MOVE / ATTACK / SKILL / DEFEND / WAIT (CR-4 행동 목록)
- **비활성 표시**: 토큰 소진 항목 = 먹 30% opacity + 취소선. 탭 불가
- **DEFEND_STANCE 잠금**: MOVE 항목 비활성 (CR-4c). 툴팁: "방어 태세 중 이동 불가"
- **확인 단계**: 이동 경로 확정, 공격 대상 확정 전 확인 UI (CR-3g 비가역성)

### Token Status Display (토큰 상태)

- **위치**: 행동 메뉴 상단 또는 유닛 정보 패널 내
- **표시**: MOVE 아이콘 + ACTION 아이콘 (벼루 형태, Visual/Audio #4)
- **상태**: available (full), spent (30% + 취소선)

### Round Counter

- **위치**: 화면 상단 좌측 또는 우측 구석
- **형태**: 인장(印鑑) 스타일 (Visual/Audio #3)
- **표시**: "第 N 合" (제 N 합) 또는 단순 숫자

### Battle End Overlay

- **트리거**: `battle_ended` signal 수신 시
- **표시**: Visual/Audio #6 연출 후 결과 화면 전환 버튼
- **입력 차단**: 오버레이 중 전장 입력 비활성화

## Acceptance Criteria

### Core Rule Criteria

**AC-01. Interleaved Queue — No Phase Alternation** (CR-1)
- **GIVEN** 3 player units (init 120, 90, 60) and 3 enemy units (init 110, 80, 50), **WHEN** R3 queue is built, **THEN** queue order is [P:120, E:110, P:90, E:80, P:60, E:50] — no player-phase or enemy-phase grouping.

**AC-02. Round Lifecycle Sequence** (CR-2)
- **GIVEN** 2 alive units, **WHEN** both complete turns without battle-end, **THEN** system executes in strict order: R1→R2→R3→R4→[T1–T7 per unit]→RE1→RE2→RE3. No step skipped or reordered.

**AC-03. Action Budget — Order Flexibility** (CR-3)
- **GIVEN** a unit with both MOVE and ACTION tokens available, **WHEN** player selects Attack→Move order, **THEN** ATTACK resolves, ACTION token spent, unit may still spend MOVE token, `acted_this_turn = true` at T6.

**AC-04. acted_this_turn — MOVE-Only Sets True** (CR-3f)
- **GIVEN** a unit spends MOVE token only (no ACTION, no WAIT), **WHEN** T6 executes, **THEN** `acted_this_turn = true`, ACTION forfeited, `unit_turn_ended` emitted with `acted = true`.

**AC-05. acted_this_turn — WAIT Leaves False** (CR-3f)
- **GIVEN** a unit selects WAIT without spending any token, **WHEN** T6 executes, **THEN** `acted_this_turn = false`, both tokens forfeited, `unit_turn_ended` emitted with `acted = false`. No queue repositioning.

**AC-06. DEFEND Spends ACTION and Locks MOVE** (CR-4)
- **GIVEN** a unit with both tokens selects DEFEND, **WHEN** DEFEND resolves, **THEN** ACTION spent, DEFEND_STANCE applied, MOVE locked for remainder of turn, `acted_this_turn = true` at T6.

**AC-07. Tie-Breaking — stat_agility Resolution** (CR-5, F-1)
- **GIVEN** Unit A (init=120, agi=85, player, id=2) and Unit B (init=120, agi=60, AI, id=5), **WHEN** R3 queue built, **THEN** A precedes B — resolved at Step 1 (stat_agility 85 > 60).

**AC-08. Tie-Breaking — Player-Controlled Resolution** (CR-5, F-1)
- **GIVEN** Unit A (init=108, agi=70, player, id=3) and Unit B (init=108, agi=70, AI, id=7), **WHEN** R3 queue built, **THEN** A precedes B — resolved at Step 2 (is_player_controlled 1 > 0).

**AC-09. Static Initiative — No Mid-Battle Recalculation** (CR-6)
- **GIVEN** a battle in Round 3 where a status effect is applied to a unit, **WHEN** next R3 queue build executes, **THEN** affected unit's queue position is identical to Round 2. Initiative values from BI-2 snapshot, never recomputed.

**AC-10. Death Mid-Round — Immediate Queue Removal** (CR-7)
- **GIVEN** queue [A(ACTING), B, C] and A killed by counter-attack at T5, **WHEN** `unit_died` received, **THEN** A removed immediately, T6 skipped for A, T7 evaluates battle-end, B proceeds to T1 next.

**AC-11. No Delay — WAIT Does Not Reposition** (CR-8)
- **GIVEN** unit third in queue selects WAIT at T4, **WHEN** T6 completes, **THEN** unit in DONE state at original queue position. No queue-back movement. Pointer advances to fourth unit.

**AC-12. Battle Initialization — Clean State** (CR-9)
- **GIVEN** battle completes BI-1–BI-5, **WHEN** BI-3 executes, **THEN** all units: `acted_this_turn = false`, `turn_state = IDLE`, `current_round_number = 0`, no DEFEND_STANCE present.

### Formula Criteria

**AC-13. F-1 Deterministic Total Order**
- **GIVEN** 20 units where some share initiative and stat_agility values, **WHEN** R3 executes 100 times with same input, **THEN** identical output every time. No two units share position. Sole sorting mechanism: `(initiative DESC, stat_agility DESC, is_player_controlled DESC, unit_id ASC)`.

**AC-14. F-2 Charge Budget — Accumulation and Threshold**
- **GIVEN** Cavalry path Plains(10)+Plains(10)+Hills(22)=42 accumulated_move_cost, **WHEN** ATTACK declared, **THEN** `charge_ready = (42 >= 40) = true`. `accumulated_move_cost` was reset to 0 at T4.

**AC-15. F-2 Charge Budget — Zero-Move No Trigger**
- **GIVEN** Cavalry attacks without spending MOVE token, **WHEN** ATTACK declared, **THEN** `accumulated_move_cost = 0`, `charge_ready = false`.

**AC-16. F-3 Round Cap — DRAW at Round 30**
- **GIVEN** Round 30 with units alive on both sides, last unit completes T7 without victory-condition detection, **WHEN** RE2 evaluates, **THEN** `30 >= 30 = true`, Turn Order emits `victory_condition_detected(DRAW)`, Grid Battle emits `battle_ended(DRAW)`. RE3 never executes. (ADR-0001 single-owner rule: Turn Order detects; Grid Battle emits.)

### Edge Case Criteria

**AC-17. EC-01 — DoT Death at T1 Skips T2–T7** (Integration)
- **GIVEN** POISON unit (`is_morale_anchor = true`) reaches HP 0 at T1, **WHEN** T1 executes, **THEN** `unit_died` emitted, DEMORALIZED propagates synchronously, unit removed from queue, T2–T7 entirely skipped, battle-end checked via `unit_died` signal path.

**AC-18. EC-04 — Mutual Kill Results in PLAYER_WIN**
- **GIVEN** last player unit A attacks last enemy B, B dies from attack, A dies from counter-attack, **WHEN** T7 evaluates battle-end, **THEN** Turn Order emits `victory_condition_detected(PLAYER_WIN)`; Grid Battle emits `battle_ended(PLAYER_WIN)`. PLAYER_WIN is checked before PLAYER_LOSE. (ADR-0001 single-owner rule.)

**AC-19. EC-06 — Battle-End via DoT Death Signal** (Integration)
- **GIVEN** last enemy unit has POISON, HP→0 at T1 of its own turn, **WHEN** `unit_died` emitted, **THEN** Grid Battle evaluates `all_enemies_dead()` on signal, Grid Battle emits `battle_ended(PLAYER_WIN)` before T2 (Turn Order is not in this code path — Grid Battle owns DoT-driven termination per ADR-0001). T2–T7 never execute.

**AC-20. EC-13 — Scout Ambush Suppressed Round 1** (Integration)
- **GIVEN** Scout attacks target (`acted_this_turn = false`) on Round 1, **WHEN** Damage Calc evaluates Ambush, **THEN** Ambush does NOT fire. `current_round_number = 1 < 2` gate evaluated first.

**AC-21. EC-15 — Scout Ambush Fires on WAIT Target Round 2+** (Integration)
- **GIVEN** Scout attacks WAIT target (`acted_this_turn = false`) on Round 3, **WHEN** Damage Calc evaluates Ambush, **THEN** Ambush fires: +15% damage applied, counter-attack suppressed.

**AC-22. EC-19 — T7 WIN Beats RE2 DRAW in Round 30**
- **GIVEN** Round 30, last enemy dies at T7, **WHEN** T7 evaluates, **THEN** Turn Order emits `victory_condition_detected(PLAYER_WIN)`; Grid Battle emits `battle_ended(PLAYER_WIN)`. RE1/RE2/RE3 never execute. WIN takes precedence over DRAW because T7 fires before RE2 in execution sequence. (ADR-0001 single-owner rule.)

### Performance Criteria

**AC-23. Queue Sort Within Frame Budget** (ADVISORY)
- **GIVEN** 20 units (maximum per BI-1), **WHEN** R3 sort executes on main thread, **THEN** completes in under 1ms on minimum target hardware (mobile). Verified by profiler capture, not visual observation.

### Test Classification Summary

| Gate Level | Criteria | Test Location |
|------------|----------|---------------|
| **BLOCKING** (Logic) | AC-01–AC-16, AC-18, AC-22 | `tests/unit/turn-order/` |
| **BLOCKING** (Integration) | AC-17, AC-19, AC-20, AC-21 | `tests/integration/turn-order/` |
| **ADVISORY** (Performance) | AC-23 | `tests/integration/turn-order/` |

## Open Questions

**OQ-1. Dynamic Initiative (Post-MVP)**
Initiative는 MVP에서 전투 시작 시 1회 계산 (CR-6). Post-MVP에서 initiative를 수정하는
상태 효과(가속/감속)를 도입할 경우, 라운드 경계(R3)에서만 적용하는 현재 계약(CR-6b)이
충분한가, 아니면 큐 내 삽입이 필요한가?

**OQ-2. STUN Mechanic (Post-MVP)**
CR-8c에서 STUN 도입 시 T4에서 자동 WAIT를 명시했으나, STUN이 행동 전체를 건너뛰는가
(T1–T3도 스킵) 아니면 DoT/효과 만료는 정상 실행 후 T4만 스킵하는가? HP/Status GDD와
동시 설계 필요.

**OQ-3. Formation Bonus ↔ Turn Order Signal Contract**
Formation Bonus System이 `round_started` signal에서 진형 보너스를 재계산한다고
가정했으나 (Dependencies, Soft), Formation GDD 미작성. Grid Battle GDD 설계 시
이 계약 확정 필요.

**OQ-4. Battle Size Scaling**
현재 사양은 8–10 유닛/side (16–20 total). 대규모 전투(30+ 유닛)를 지원할 경우
Turn Order Bar UI의 스크롤/축소 전략과 R3 정렬 성능 재검증 필요.
