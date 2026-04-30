# HP/Status System (HP/상태)

> **Status**: Accepted via ADR-0010 (Proposed 2026-04-30; pending /architecture-review delta for Foundation 5/5 + Core 2/2 closing)
> **Author**: user + Claude Code agents
> **Last Updated**: 2026-04-16 (Designed); 2026-04-30 (Status header refresh + CR-5b apply_status signature sync per ADR-0010 §5 — 3-arg → 4-arg + renamed `effect_id` → `effect_template_id`, `duration` → `duration_override`. Implemented as `HPStatusController` Battle-scoped Node child of BattleScene per ADR-0010 §1; canonical class name preserved.)
> **Implements Pillar**: Pillar 1 (형세의 전술) + Pillar 3 (모든 무장에게 자리가 있다)

## Overview

HP/Status System은 전투 중 모든 유닛의 체력(HP)과 상태 효과(Status Effect)를
런타임으로 관리하는 Core 시스템이다. Unit Role System이 `max_hp`를 산출하면,
이 시스템이 `current_hp`를 추적하고, 피해 수신/회복 파이프라인을 소유하며,
상태 효과(버프/디버프/상태이상)의 적용·지속·해제를 관리한다. 전투가 시작되면
모든 유닛의 HP를 `max_hp`로 초기화하고, Damage/Combat Calc이 산출한 최종
피해량을 받아 `current_hp`를 갱신하며, `current_hp ≤ 0`일 때 사망 판정을
내린다. 상태 효과는 턴 기반으로 지속 시간이 관리되며, 공격력·방어력·이동력·
회피율 등의 파생 스탯에 일시적 수정자(modifier)를 부여한다. Grid Battle,
Damage Calc, AI System, Battle HUD 등 6개 이상의 시스템이 이 시스템의
상태를 읽거나 쓰며, 플레이어는 HP 바와 상태 아이콘을 통해 전장 상황을
실시간으로 파악한다. MVP 범위: HP 추적, 피해/회복 파이프라인, 사망 판정,
3-5종 핵심 상태 효과.

## Player Fantasy

**먹이 마르기 전에 (The Ink Thins Before It Breaks)**

수묵화에서 먹의 농담(濃淡)은 생명의 무게다. 짙은 먹 한 획은 존재의 선언이고,
옅어지는 먹은 소멸의 예고다. 전장에서 HP는 그 먹의 농도다.

전투가 시작되면 모든 무장은 짙고 선명한 먹선으로 존재한다 — 가득 찬 체력,
흔들림 없는 자태. 적의 칼이 닿을 때마다 먹이 옅어진다. 한 방에 무너지는
것이 아니라, 한 획 한 획 흐려지는 것이다. 독은 화선지에 떨어진 물방울 —
선명했던 윤곽이 번지기 시작한다. 사기 저하는 먹이 갈라지는 균열. 방어
강화는 마르기 전에 덧칠한 새 먹 — 옅어진 선을 다시 짙게 만드는 군사의
의지다.

플레이어가 느끼는 것은 숫자의 감소가 아니라, 이야기가 끝나가는 긴박함이다.
관우의 체력이 30%일 때 — 그것은 "HP가 낮다"가 아니라, "이 영웅의 먹이
마르고 있다"이다. 회복 스킬을 쓰는 것은 수치를 올리는 것이 아니라,
끝나려는 이야기에 새 먹을 올리는 것이다. 버프를 거는 것은 마르지 말라는
군사의 명령이다.

그리고 먹이 다 마르면 — 획이 끊기고, 영웅이 쓰러진다. 역사는 그렇게
기록되어 있다. 하지만 Pillar 2가 약속한다: 충분히 치밀한 군사라면, 먹이
마르기 전에 운명을 다시 쓸 수 있다.

*먹이 옅어지는 것을 보는 것은 숫자가 줄어드는 것을 보는 것과 다르다.
이 시스템은 Pillar 1(형세의 전술 — 진형의 약한 곳은 먹이 옅은 곳이다)을
지탱하고, Pillar 2(운명은 바꿀 수 있다 — 먹이 마르기 전에 새 먹을 올리는
것이 운명 역전이다)와 연결되며, Pillar 3(모든 무장에게 자리가 있다 — 먹이
옅어진 무장도 올바른 자리에 있다면 진형의 일부다)을 보완한다.*

## Detailed Design

### Core Rules

**CR-1. HP Lifecycle**

1a. **Initialization**: 전투 시작 시 모든 참전 유닛의 `current_hp`를 `max_hp`(Unit Role F-3 산출)로 설정한다. 진형 보너스/전투 전 버프 적용 후, 첫 턴 처리 전에 원자적으로 실행.

1b. **비지속성 (MVP)**: HP는 전투 간 지속되지 않는다. 모든 전투는 `max_hp`에서 시작. 시나리오 기반 게임에서 HP 이월은 밸런스 부채를 누적시킨다.

1c. **리셋 조건**: `current_hp`가 `max_hp`로 리셋되는 경우: (a) 새 전투 시작, (b) 명시적 전체 회복 이벤트(시나리오 야영 등). 턴/라운드/페이즈 간에는 리셋하지 않는다.

---

**CR-2. HP Range Invariant**

모든 시점에서: `0 ≤ current_hp ≤ max_hp`. 외부 시스템이 `current_hp`를 직접 수정하는 것은 금지. 모든 HP 변경은 damage intake(CR-3) 또는 healing(CR-4) 파이프라인을 통해서만 수행.

---

**CR-3. Damage Intake Pipeline**

이 시스템은 intake 측만 소유한다. Damage/Combat Calc이 `resolved_damage`(ATK, DEF, 지형, 방향, 회피 등 모든 계산 완료 후)를 전달하면, HP/Status가 수신하여 `current_hp`를 갱신한다.

```
Step 1 — Passive flat reduction (방어 패시브)
  if (attack_type == PHYSICAL) AND ("passive_shield_wall" in defender.passive_tags):
    post_passive = resolved_damage - SHIELD_WALL_FLAT
  else:
    post_passive = resolved_damage

Step 2 — Status effect modifier (상태 효과 수정자)
  if defender has DEFEND_STANCE:
    post_passive = floor(post_passive × (1 - DEFEND_STANCE_REDUCTION / 100))
  if defender has VULNERABLE effect:
    post_passive = floor(post_passive × VULNERABLE_MULT)

Step 3 — Minimum damage floor
  final_damage = max(MIN_DAMAGE, post_passive)

Step 4 — HP reduction
  current_hp = max(0, current_hp - final_damage)
  if current_hp == 0: emit unit_died signal
```

계약: Damage Calc은 회피 체크 완료 후 `resolved_damage ≥ 1`을 전달한다. 회피(MISS)인 경우 HP/Status는 호출되지 않는다.

---

**CR-4. Healing Pipeline**

```
Step 1 — Raw heal value
  raw_heal = source.heal_value 또는 source.heal_formula 결과

Step 2 — Healing effectiveness modifier
  if target has EXHAUSTED: raw_heal = max(1, floor(raw_heal × EXHAUSTED_HEAL_MULT))

Step 3 — Overheal prevention
  heal_amount = min(raw_heal, max_hp - current_hp)

Step 4 — HP increase
  current_hp = current_hp + heal_amount
```

4a. **Overheal 금지**: `current_hp`는 절대 `max_hp`를 초과할 수 없다. 초과분은 폐기.
4b. **사망 유닛 회복 불가**: `current_hp == 0`인 유닛은 회복 대상이 될 수 없다(전장에서 제거됨).
4c. **MVP 회복 소스**: 스킬(active heal), 소모 아이템, 지형 재생(기본값 0 — MVP에서 비활성).

---

**CR-5. Status Effect Architecture**

5a. **효과 구조**: 모든 상태 효과는 다음 필드를 포함한다:

| Field | Type | Description |
|-------|------|-------------|
| `effect_id` | string | 고유 식별자 (예: `POISON`) |
| `effect_type` | enum | BUFF, DEBUFF |
| `duration_type` | enum | TURN_BASED, CONDITION_BASED, ACTION_LOCKED |
| `remaining_turns` | int | 남은 턴 수 (TURN_BASED) |
| `modifier_targets` | dict | 수정하는 스탯과 수정량 |
| `tick_effect` | dict/null | 턴 시작 시 DoT 등 틱 효과 |

5b. **적용 시점**: Damage Calc이 명중 판정 후, 스킬/아이템/시스템 이벤트가 `apply_status(unit_id, effect_template_id, duration_override, source_unit_id)`을 호출. (Synced 2026-04-30 to ADR-0010 §5 canonical 4-arg signature; renamed from prior 3-arg `apply_status(target, effect_id, duration)`. `duration_override == -1` uses template default per ADR-0010 §5.)

5c. **동일 효과 비중첩 (refresh)**: 같은 effect_id의 두 번째 적용 시, 기존 인스턴스의 지속 시간만 갱신(새 적용의 duration으로 교체). 중첩 금지.

5d. **다른 효과 공존**: 서로 다른 effect_id는 자유롭게 공존한다. POISON + DEMORALIZED + EXHAUSTED 동시 가능.

5e. **최대 효과 수**: 유닛당 최대 `MAX_STATUS_EFFECTS_PER_UNIT`(기본 3)개. 4번째 적용 시 가장 오래된 효과가 제거된 후 새 효과 적용.

5f. **수정자 합산 규칙**: 같은 스탯을 수정하는 복수 효과는 **가산** 후 클램프.

```
total_modifier = clamp(sum(modifier_i), MODIFIER_FLOOR, MODIFIER_CEILING)
modified_stat = max(1, floor(base_stat × (1 + total_modifier / 100)))
```

MODIFIER_FLOOR: -50%, MODIFIER_CEILING: +50%. 어떤 스탯도 1 미만 불가.

---

**CR-6. MVP Status Effect Definitions**

**SE-1. 독 (POISON)**
- 유형: Debuff | 지속: TURN_BASED (기본 3턴)
- 효과: 피해 유닛 턴 시작 시 DoT 피해. 방어 무시(true damage).
- DoT 산출: `dot_damage = clamp(floor(max_hp × DOT_HP_RATIO) + DOT_FLAT, DOT_MIN, DOT_MAX_PER_TURN)`
- 적용: 명중한 스킬/아이템의 `inflict_status: POISON`
- 해제: 지속 시간 만료, 정화 스킬, 사망
- 전술 의미: 지형 방어에 의존하는 정적 유닛을 침식. 척후가 적용 후 이탈하는 패턴 보상.

**SE-2. 사기저하 (DEMORALIZED)**
- 유형: Debuff | 지속: CONDITION_BASED + 턴 캡 (기본 4턴)
- 효과: ATK -25%
- 발동 조건: (a) 아군 Commander 사망 시 반경 `DEMORALIZED_RADIUS`(기본 4) 내 아군 전원에 적용, (b) `is_morale_anchor=true`인 아군 명명 영웅 사망 시 동일 적용, (c) 특정 스킬로 직접 부여
- 회복 조건: 아군 영웅(Commander 또는 명명 영웅)이 맨해튼 거리 ≤ 2 이내에 있으면, 다음 턴 시작 시 해제
- 전술 의미: Commander 보호의 중요성 강화(Pillar 3). 밀집 진형이 사기 회복에 유리.

**SE-3. 방어태세 (DEFEND_STANCE)**
- 유형: Buff | 지속: ACTION_LOCKED (이동/공격 시 해제); `grid-battle.md` CR-13 기준 1턴(다음 `unit_turn_started`에 해제)
- 효과: 모든 수신 피해 -50% (rev 2026-04-19 — 기존 30%에서 상향; `defend_stance_reduction` 레지스트리 참조), ATK -40% (`defend_stance_atk_penalty`) — **v5.0 pass-9b Q3: 현재 INERT** (reachable only on `is_counter=true` path; CR-13 rule 4 suppresses counters from DEFEND_STANCE 유닛이며 mid-turn DEFEND 스킬은 아직 설계되지 않음). 레지스트리 값은 speculative forward declaration으로 유지. 상세: `design/gdd/grid-battle.md` Tuning Knobs `DEFEND_STANCE_ATK_PENALTY` 행 참조.
- 반격: DEFEND_STANCE 유닛은 반격하지 않는다 (grid-battle.md CR-13 rule 4). CR-6 억제 조건에 포함 — 순수 방어 commitment. 공격 행동 선언 시점 해제 모델(구 v3.2 / 폐기된 EC-14·AC-20)은 v5.0에서 제거됨.
- 적용: 모든 병종이 "방어" 행동(범용 행동, 스킬 슬롯 아님)으로 자발적 진입. DEFEND 선언 시 `acted_this_turn = true`(grid-battle CR-13 v5.0) — Scout Ambush 대상에서 제외됨.
- 해제: (a) 유닛이 이동 또는 공격 행동을 취함, (b) 다음 턴 시작, (c) 사망, (d) CR-7 배타 규칙으로 EXHAUSTED 적용 시 강제 해제 (EC-13).
- 전술 의미: 지형과 중첩하여 초크포인트 생성. "다리목의 창병" 판타지. 방어 중 ATK 페널티로 commitment 비용 부과. 반격 불가와 -50% 피해 감소가 trade-off를 보장 — Pillar 3 방어 정체성의 핵심.

**SE-4. 고무 (INSPIRED)**
- 유형: Buff | 지속: TURN_BASED (기본 2턴)
- 효과: ATK +20%
- 적용: Commander 클래스 풀 스킬 또는 특정 영웅 고유 스킬. 인접 아군 대상.
- 해제: 지속 시간 만료, 사망
- 전술 의미: 밀집 진형 보상 — Commander가 중앙에 위치해야 최대 효과. 적 AI에게 INSPIRED 유닛 우선 처치 유도.

**SE-5. 피로 (EXHAUSTED)**
- 유형: Debuff | 지속: TURN_BASED (기본 2턴)
- 효과: effective_move_range -1 (최소 1), 수신 회복량 -50%
- 적용: 특정 스킬(강행군 등), 시나리오 이벤트
- 해제: 지속 시간 만료, 정화 스킬
- 전술 의미: 기병 돌격 무력화(이동 감소로 Charge 발동 예산 미달), 독+피로 치명적 조합.

---

**CR-7. DEFEND_STANCE + EXHAUSTED 배타성**

DEFEND_STANCE와 EXHAUSTED는 공존할 수 없다:
- EXHAUSTED 상태에서 방어 행동 시도 → 행동 실패 + "피로로 태세 유지 불가" 피드백
- DEFEND_STANCE 상태에서 EXHAUSTED 적용 → DEFEND_STANCE 해제(행동을 취한 것과 동일 처리)

---

**CR-8. Death / Defeat**

8a. **사망 판정**: `current_hp == 0`일 때 즉시 `unit_died` 시그널 발생.
8b. **즉시 제거 (MVP)**: 사망 유닛은 전장에서 즉시 제거. 다운 상태/부활 없음.
8c. **사기 효과 전파**: Commander 사망 또는 `is_morale_anchor=true` 영웅 사망 시, 반경 내 아군에 DEMORALIZED 적용 (CR-6 SE-2).
8d. **적 유닛 동일 적용**: 적 Commander 사살 시 적 유닛도 DEMORALIZED. 전략적 암살 보상.
8e. **전투 종료 조건**: Grid Battle 소관. HP/Status는 `unit_died` 시그널로 데이터 제공.

---

**CR-9. Minimum Damage / Overkill Prevention**

9a. 모든 피해 이벤트의 최종 damage ≥ `MIN_DAMAGE`(기본 1). 0-damage 불가.
9b. `current_hp` 초과 overkill은 폐기. 스플래시/추가 효과 없음.
9c. 즉사 메카닉 없음(MVP). 모든 사살은 HP 0 도달을 통해서만 발생.

---

### States and Transitions

유닛 생존 상태:

| State | 조건 | 설명 |
|-------|------|------|
| ALIVE | `current_hp > 0` | 전투 참여 가능 |
| DEAD | `current_hp == 0` | 전장에서 제거됨 |

전이: ALIVE → DEAD (damage pipeline 또는 DoT에 의해 `current_hp`가 0 도달). 단방향 — MVP에서 DEAD → ALIVE 불가.

상태 효과 생명 주기:

| Lifecycle | 설명 |
|-----------|------|
| APPLIED | 스킬/이벤트에 의해 유닛에 부착. 수정자 즉시 활성화. |
| ACTIVE | 매 턴 틱 효과 실행, duration 카운트다운. |
| EXPIRED | remaining_turns == 0 또는 조건 충족. 즉시 제거, 수정자 해제. |

턴 내 처리 순서:
1. 턴 시작: DoT 틱(POISON) → 사망 체크 → duration 만료 체크/제거
2. 유닛 행동: 공격/스킬 → damage intake pipeline → 상태 효과 적용
3. 턴 종료: CONDITION_BASED 효과 회복 조건 체크

---

### Interactions with Other Systems

#### Upstream (읽기)

| System | Data Read |
|--------|-----------|
| Unit Role | `max_hp`(F-3), `passive_tags`(Shield Wall 등) |
| Hero DB | `base_hp_seed`(Unit Role 경유), `is_morale_anchor` |
| Damage Calc | `resolved_damage`, `attack_type` |

#### Downstream (제공)

| Consumer | Data Provided |
|----------|---------------|
| Grid Battle | `unit_died` signal, `is_alive(unit)` 쿼리 |
| Battle HUD | `current_hp`, `max_hp`, active status effect 목록(아이콘, 남은 턴) |
| Damage Calc | 상태 수정자에 의한 `modified_atk`, `modified_def` |
| AI System | `current_hp / max_hp` 비율(위협 평가), 상태 효과 현황 |
| Character Growth | 전투 후 생존 여부(VS scope) |
| Scenario Progression (`design/gdd/scenario-progression.md` — Approved pending review) | Boundary assertion only: HP reset ownership 이 Grid Battle 에 있음을 CR-1b 로 인용. Scenario 는 HP를 직접 읽거나 쓰지 않음. |

#### Interface Contracts

**Contract 1: Damage Calc → HP/Status** (피격 시)
- Input: `resolved_damage`(int ≥ 1), `attack_type`(enum), `source_flags`(set)
- HP/Status는 Shield Wall, 상태 수정자, min damage 적용 후 `current_hp` 갱신
- **Ratified 2026-04-18** by `design/gdd/damage-calc.md` §C CR-1 + §E EC-DC-12 +
  §J AC-DC-28: `attack_type ∈ {PHYSICAL, MAGICAL}` only. DoT/POISON/true-damage
  paths BYPASS `damage_calc.resolve()` entirely — HP/Status invokes its own
  F-3 (DoT Damage Per Turn) and applies directly to `current_hp` without
  routing through Damage Calc. Illegal `attack_type` (e.g., "POISON") passed
  to `resolve()` triggers `push_error` + `MISS()` sentinel (defense-in-depth
  against accidental DoT routing). `resolved_damage` is clamped to
  `[1, DAMAGE_CEILING=180]` by Damage Calc §F-DC-6 (pass-11a: value corrected 150→180 per registry `damage_ceiling` rev 2 2026-04-18); HP/Status can trust the
  upper bound. MIN_DAMAGE enforcement is dual: Damage Calc enforces at every
  floori() boundary (F-DC-3 / F-DC-6 / F-DC-7); HP/Status enforces again at
  apply_damage intake per this contract.

**Contract 2: HP/Status → Battle HUD** (매 프레임/턴)
- Output: `current_hp`, `max_hp`, `status_effects[]`(각 효과의 id, icon, remaining_turns)

**Contract 3: 스킬/아이템 → HP/Status** (상태 효과 적용)
- Input: `apply_status(target, effect_id, duration, source_unit)`
- HP/Status가 중첩/최대 수/배타성 규칙 적용 후 부착

## Formulas

모든 공식의 상수는 `assets/data/config/hp_status_config.json` 또는
`assets/data/config/balance_constants.json`에서 로딩. 하드코딩 금지.

---

### F-1. Damage Intake (HP 감소)

```
post_passive = resolved_damage - passive_flat_reduction(attack_type, passive_tags)
final_damage = max(MIN_DAMAGE, post_passive)
current_hp   = max(0, current_hp - final_damage)
```

`passive_flat_reduction`:
- `SHIELD_WALL_FLAT` if `attack_type == PHYSICAL` AND `passive_shield_wall` active
- `0` otherwise

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `resolved_damage` | int | [1, ∞) | Damage Calc 산출 최종 피해 (ATK/DEF/지형/방향/회피 적용 완료) |
| `attack_type` | enum | {PHYSICAL, MAGICAL} | 공격 유형 |
| `passive_tags` | set | — | 방어자의 활성 패시브 태그 |
| `SHIELD_WALL_FLAT` | int | [3, 8] default **5** | Config: `balance_constants.json` |
| `MIN_DAMAGE` | int | [1, 3] default **1** | Config: `balance_constants.json` |
| `current_hp` | int | [0, HP_CAP] | 피격 전 현재 HP |

**Output Range:** `final_damage` ∈ [1, ∞). `current_hp` ∈ [0, max_hp].

**Example — Physical hit on Infantry (Shield Wall):**
`resolved_damage=40`, PHYSICAL, Shield Wall active → `40 - 5 = 35` → `max(1, 35) = 35` → HP: 120 → 85

**Example — MIN_DAMAGE floor:**
`resolved_damage=3`, PHYSICAL, Shield Wall active → `3 - 5 = -2` → `max(1, -2) = 1` → HP: 120 → 119

---

### F-2. Healing Amount

```
heal_amount  = clamp(floor(HEAL_BASE + ceil(max_hp × HEAL_HP_RATIO)), 1, HEAL_PER_USE_CAP)
current_hp   = min(max_hp, current_hp + heal_amount)
```

EXHAUSTED 적용 시: `heal_amount = floor(heal_amount × EXHAUSTED_HEAL_MULT)` (Step 2 of CR-4)

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `HEAL_BASE` | int | [5, 30] default **15** | 고정 회복량. Config: `hp_status_config.json` |
| `max_hp` | int | [51, 300] | 대상의 최대 HP |
| `HEAL_HP_RATIO` | float | [0.05, 0.20] default **0.10** | max_hp 비례 회복 비율. Config: `hp_status_config.json` |
| `HEAL_PER_USE_CAP` | int | [30, 80] default **50** | 1회 회복 상한. Config: `hp_status_config.json` |
| `EXHAUSTED_HEAL_MULT` | float | [0.3, 0.7] default **0.5** | EXHAUSTED 상태 시 회복 효율. Config: `hp_status_config.json` |

**Output Range:** `heal_amount` ∈ [1, 50].

**Example — Strategist (max_hp=106):**
`floor(15 + ceil(106 × 0.10)) = floor(15 + 11) = 26` → 24.5% of max

**Example — Infantry (max_hp=232):**
`floor(15 + ceil(232 × 0.10)) = floor(15 + 24) = 39` → 16.8% of max

**EXHAUSTED 적용 시:** Infantry: `floor(39 × 0.5) = 19` → 8.2% of max

---

### F-3. DoT Damage Per Turn (독)

```
dot_damage = clamp(floor(max_hp × DOT_HP_RATIO) + DOT_FLAT, DOT_MIN, DOT_MAX_PER_TURN)
current_hp = max(0, current_hp - dot_damage)
```

방어 무시(true damage) — CR-3 intake pipeline을 거치지 않고 직접 `current_hp` 감소.

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `DOT_HP_RATIO` | float | [0.02, 0.08] | max_hp 비례 DoT. Config: `hp_status_config.json` |
| `DOT_FLAT` | int | [0, 10] | 고정 추가 DoT. Config: `hp_status_config.json` |
| `DOT_MIN` | int | [1, 3] default **1** | 최소 DoT. Config: `hp_status_config.json` |
| `DOT_MAX_PER_TURN` | int | [15, 30] default **20** | 턴당 DoT 상한. Config: `hp_status_config.json` |

**유형별 기본값:**

| Type | DOT_HP_RATIO | DOT_FLAT | Default Duration |
|------|-------------|---------|-----------------|
| POISON (독) | 0.04 | 3 | 3턴 |

**Output Range:** `dot_damage` ∈ [1, 20].

**Example — POISON on Infantry (max_hp=232):**
`clamp(floor(232 × 0.04) + 3, 1, 20) = clamp(9 + 3, 1, 20) = 12`
→ 12/turn × 3turns = 36 total (15.5% of max)

**Example — POISON on Strategist (max_hp=106):**
`clamp(floor(106 × 0.04) + 3, 1, 20) = clamp(4 + 3, 1, 20) = 7`
→ 7/turn × 3turns = 21 total (19.8% of max)

---

### F-4. Status Effect Modifier Application

```
total_modifier = clamp(sum(modifier_i for active effects on stat), MODIFIER_FLOOR, MODIFIER_CEILING)
modified_stat  = max(1, floor(base_stat × (1 + total_modifier / 100)))
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| `modifier_i` | int | [-50, +50] | 개별 효과의 수정량 (%). Config: `hp_status_config.json` |
| `MODIFIER_FLOOR` | int | default **-50** | 총 디버프 하한. Config: `hp_status_config.json` |
| `MODIFIER_CEILING` | int | default **+50** | 총 버프 상한. Config: `hp_status_config.json` |
| `base_stat` | int | [1, 200] | Unit Role 공식 산출 기본값 |

**Output Range:** `modified_stat` ∈ [1, ∞). 실전 범위: base_stat의 50%~150%.

**Example — DEMORALIZED(-25%) + INSPIRED(+20%):**
`total_modifier = clamp(-25 + 20, -50, +50) = -5`
`modified_atk = max(1, floor(82 × 0.95)) = 77` (순 5% 감소)

## Edge Cases

### Pipeline & Damage

**EC-01. Shield Wall이 damage를 MIN_DAMAGE 이하로 감소**
- **If `resolved_damage=3`, PHYSICAL, Shield Wall active**: `3-5=-2` → `max(1,-2)=1`. Final damage는 1. Shield Wall은 MIN_DAMAGE 이하로 감소시킬 수 없다.

**EC-02. DEFEND_STANCE가 MIN_DAMAGE 입력을 수신**
- **If `resolved_damage=1`, DEFEND_STANCE active**: `floor(1×0.50)=0` → `max(1,0)=1`. DEFEND_STANCE는 damage를 0으로 만들 수 없다. MIN_DAMAGE가 최종 안전장치. (rev 2026-04-19: 0.70 → 0.50 per `defend_stance_reduction` 30→50.)

**EC-03. DEFEND_STANCE + VULNERABLE 동시 적용 시 순서 (바인딩 규칙)**
- **If 방어자에 DEFEND_STANCE와 VULNERABLE 효과 동시 활성**: Step 2에서 DEFEND_STANCE(-50%) 먼저 적용, VULNERABLE 후 적용. 이 순서는 바인딩 규칙이다. 비가환적 — 순서가 바뀌면 결과가 달라질 수 있으며, 방어자 유리(먼저 감소 후 증가)가 의도된 설계.

---

### Status Effect Slot Management

**EC-04. 4번째 상태 효과 적용 시 슬롯 퇴거**
- **If 유닛에 3개 효과(POISON + DEMORALIZED + INSPIRED)가 있고 EXHAUSTED 적용**: 가장 오래된 효과(POISON) 퇴거 → DEMORALIZED + INSPIRED + EXHAUSTED. 처리 순서: 배타성 체크 → 동일 효과 갱신 체크 → 슬롯 퇴거 → 적용.

**EC-05. 슬롯 퇴거로 DoT 소스 제거**
- **If POISON이 슬롯 퇴거로 제거됨**: 다음 턴 시작 시 POISON 틱 불발. 퇴거는 즉시 반영. 퇴거가 발생한 턴에 아직 틱이 실행되지 않았더라도, POISON이 효과 목록에 없으면 틱 없음.

---

### DoT & Death Sequencing

**EC-06. POISON 틱으로 `current_hp`가 정확히 0**
- **If POISON 틱이 `current_hp`를 0으로 만듦**: `unit_died` 시그널 즉시 발생. 남은 POISON 턴 무관(유닛 제거). Commander POISON 사망 시 DEMORALIZED 전파 정상 작동.

**EC-07. `current_hp=1`인 유닛에 POISON 틱**
- **If `current_hp=1`, POISON `dot_damage ≥ 1`**: `max(0, 1-1) = 0`. 유닛 사망. DoT는 F-1 intake pipeline을 거치지 않으므로 MIN_DAMAGE 규칙은 DoT에 적용되지 않는다. `dot_damage=1`이면 `current_hp=0`.

---

### Healing Boundaries

**EC-08. EXHAUSTED로 회복량이 0이 되는 경우**
- **If `heal_amount=1`(최소), EXHAUSTED 적용**: CR-4 Step 2에 `max(1, ...)` 적용. `max(1, floor(1×0.5)) = max(1, 0) = 1`. EXHAUSTED 상태에서도 회복 행동은 최소 1 HP를 회복한다.

**EC-09. `current_hp = max_hp`인 유닛에 회복**
- **If 대상이 풀 HP**: `heal_amount = min(raw_heal, 0) = 0`. HP 변동 없음. 스킬/아이템 소모는 발생. UI는 풀 HP 유닛에 회복 수치를 표시하지 않아야 함.

**EC-10. 사망 유닛(current_hp=0)에 회복 시도**
- **If 회복 대상의 `current_hp == 0`**: 회복 함수 진입점에서 거부. 파이프라인 미진입. CR-4b 규칙.

---

### Modifier Cap Interactions

**EC-11. DEMORALIZED(-25%) + DEFEND_STANCE(-40%) ATK 동시 적용**
- **If 두 효과 모두 활성**: F-4에서 합산: `clamp(-25 + -40, -50, +50) = -50`. 캡이 15%p를 흡수. DEFEND_STANCE의 ATK 비용이 DEMORALIZED와 겹칠 때 일부 무효화됨 — 의도된 동작.

**EC-12. INSPIRED(+20%) + DEFEND_STANCE(-40%) ATK**
- **If 두 효과 동시**: `clamp(+20 + -40, -50, +50) = -20`. DEFEND_STANCE가 여전히 지배. 순 ATK 80%.

---

### Mutual Exclusion & DEFEND_STANCE

**EC-13. EXHAUSTED가 적 스킬로 DEFEND_STANCE 유닛에 적용**
- **If 적이 DEFEND_STANCE 유닛에 EXHAUSTED 부여 스킬 사용**: CR-7에 따라 DEFEND_STANCE 강제 해제 → EXHAUSTED 적용. 방어자가 행동하지 않았어도 태세 소실. 배타성 규칙의 의도된 결과.

**EC-14. DEFEND_STANCE 유닛의 피격 (반격 없음)**
- **If DEFEND_STANCE 유닛이 피격됨**: CR-13 rule 4에 따라 DEFEND_STANCE 유닛은 반격하지 않는다. 수신 피해는 -50% 감소(SE-3) 적용, 태세는 해소 후에도 유지되며 다음 `unit_turn_started` 또는 CR-7/EC-13 배타 규칙에 의해서만 해제. 전투 예측(UI-GB-04) 사유: localization key `"forecast.no_counter.defend_stance"` (pass-11a — previously hardcoded Korean "반격 없음 — 방어 중"; key owned by `design/gdd/grid-battle.md` CR-13 rule 4; defaults KO: 반격 없음 — 방어 중 / EN: No counter — defending). (rev 2026-04-19: v3.2/v4.0의 "반격 시 태세 해제" 모델 폐기, `grid-battle.md` CR-13 v5.0 pure-defensive commitment 정책으로 통일.)

---

### Boundary Values

**EC-15. `max_hp=51`(Strategist 최소) POISON**
- **If Strategist(max_hp=51)에 POISON**: `clamp(floor(51×0.04)+3, 1, 20) = 5`. 3턴 합계 15 (29.4% of max). 저 HP 유닛에 POISON이 상대적으로 위험 — DOT_FLAT(3)의 고정분이 비율을 높임. 튜닝 참고.

**EC-16. POISON 갱신(refresh) 시 지속 시간만 초기화**
- **If POISON 2턴차(남은 1턴)에 재적용**: `remaining_turns`를 3으로 교체(누적 아님). dot_damage는 `max_hp`가 불변이므로 동일값. 향후 다른 소스의 POISON(다른 DOT_FLAT)이 추가되면, 새 적용의 `dot_damage` 재계산 필요.

**EC-17. DEMORALIZED 전파 반경 내에 이미 DEMORALIZED인 유닛**
- **If Commander 사망 시 반경 내 아군이 이미 DEMORALIZED**: CR-5c에 따라 refresh — `remaining_turns`만 4로 초기화. 이중 적용이나 추가 패널티 없음.

## Dependencies

### 상위 의존성 (이 시스템이 의존하는 것)

| System | 의존 유형 | 참조 데이터 | GDD Status |
|--------|----------|-----------|------------|
| **Hero Database** | Hard | `base_hp_seed`(Unit Role 경유), `is_morale_anchor` | Designed |
| **Unit Role System** | Hard | `max_hp`(F-3), `passive_tags`, `attack_type` | Designed |
| **Balance/Data System** | Hard | `balance_constants.json`, `hp_status_config.json`(신규) | Designed |

### 하위 의존성 (이 시스템에 의존하는 것)

| System | 의존 유형 | 사용 데이터 | GDD Status |
|--------|----------|-----------|------------|
| **Damage/Combat Calc** | Hard | `modified_atk`, `modified_def`(상태 수정자 반영) | Not Started |
| **Grid Battle System** | Hard | `unit_died` signal, `is_alive()`, `modified_move_range` | Not Started |
| **Battle HUD** | Hard | `current_hp`, `max_hp`, `status_effects[]` | Not Started |
| **AI System** | Soft | HP 비율, 상태 효과 현황(위협 평가) | Not Started |
| **Character Growth** | Soft | 전투 후 생존 여부(VS scope) | Not Started |

### 크로스 시스템 계약

- **Damage Calc → HP/Status**: `resolved_damage`(int ≥ 1), `attack_type`(enum), `source_flags`(set). 회피 MISS 시 HP/Status 미호출.
- **HP/Status → Battle HUD**: `current_hp`, `max_hp`, `status_effects[]`(id, icon, remaining_turns, modifier_values)
- **스킬/아이템 → HP/Status**: `apply_status(target, effect_id, duration, source_unit)`. 스킬 명중 후 호출.
- **HP/Status → Grid Battle**: `unit_died` signal. Grid Battle이 승패 조건 판정.
- **HP/Status → Damage Calc**: `get_modified_stat(unit, stat_name)` — 상태 효과 반영 스탯 조회.

### Hero DB 확장 필요 (is_morale_anchor)

DEMORALIZED 전파를 위해 Hero DB에 `is_morale_anchor: bool` 필드 추가 필요.
Commander 병종은 자동 발동이므로 이 필드는 Commander가 아닌 명명 영웅(예:
관우, 장비)에 사용. Hero DB GDD 업데이트는 이 GDD 승인 후 별도 진행.

## Tuning Knobs

모든 값은 `assets/data/config/hp_status_config.json` 또는
`assets/data/config/balance_constants.json`에서 로딩. 하드코딩 금지.

| Knob | Default | Safe Range | Too High | Too Low | Config File |
|------|---------|-----------|----------|---------|-------------|
| `MIN_DAMAGE` | 1 | 1–3 | 고방어 유닛도 무시 못할 피해 → 방어 투자 약화 | 의미 없음(1이 최소) | `balance_constants.json` |
| `SHIELD_WALL_FLAT` | 5 | 3–8 | 저ATK 공격자가 보병에 거의 피해 불가 → 초반 밸런스 붕괴 | 패시브 존재감 소멸 | `balance_constants.json` |
| `HEAL_BASE` | 15 | 5–30 | 저HP 유닛 회복이 과도 → 제거 불가 | 회복이 무의미 | `hp_status_config.json` |
| `HEAL_HP_RATIO` | 0.10 | 0.05–0.20 | 고HP 보병 회복이 너무 커 불사 | HP 비례 이점 소멸 | `hp_status_config.json` |
| `HEAL_PER_USE_CAP` | 50 | 30–80 | 1회 회복으로 전투 흐름 역전 | 회복 행동 가치 하락 | `hp_status_config.json` |
| `DOT_HP_RATIO` (POISON) | 0.04 | 0.02–0.08 | 독이 너무 치명적 → 즉사에 준함 | 독이 무시당함 | `hp_status_config.json` |
| `DOT_FLAT` (POISON) | 3 | 0–10 | 저HP 유닛에 독이 과도 (EC-15) | HP 비례만 남아 저HP 유닛에 미미 | `hp_status_config.json` |
| `DOT_MAX_PER_TURN` | 20 | 15–30 | 1틱이 과도 → 독이 즉사기 | 고HP 유닛에 독이 무의미 | `hp_status_config.json` |
| `DEMORALIZED_ATK_REDUCTION` | 25% | 15%–40% | 사기저하 유닛이 전투 불능 수준 | 사기저하가 무시당함 | `hp_status_config.json` |
| `DEMORALIZED_RADIUS` | 4 | 2–6 | 맵 전체에 영향 → Commander 암살이 게임 종결 | 밀집 진형만 영향 → 범위 좁아 전술 의미 감소 | `hp_status_config.json` |
| `DEMORALIZED_TURN_CAP` | 4 | 2–6 | 회복 기회 없이 게임 종료 | 즉시 회복 → 사기 시스템 무의미 | `hp_status_config.json` |
| `DEMORALIZED_RECOVERY_RADIUS` | 2 | 1–3 | 회복 너무 쉬움 → 사기 위협 약화 | 회복이 어려움 → 사기저하 사실상 턴 캡까지 영구 | `hp_status_config.json` |
| `DEFEND_STANCE_REDUCTION` | 50% | 30%–70% | 방어 태세가 무적에 가까움 → 공격자가 commit 안 함 | 방어 가치 하락 → WAIT와 동등, DEFEND 선택률 <5% 위험 (rev 2026-04-19: 30% → 50% per grid-battle v5.0 CR-13 Pillar-3) | `hp_status_config.json` |
| `DEFEND_STANCE_ATK_PENALTY` | 40% (provisional) | 25%–50% | commitment 비용 과도 → 방어 비선택 | trade-off 부족 → 방어가 항상 최적 | `hp_status_config.json` — **Provisional (pass-11b R-7).** 40%는 v3.2/v4.0 모델(DEFEND_STANCE 방어자가 -40% ATK으로 반격) 기준의 추측 값이다. v5.0 모델에서 이 경로는 **INERT** — `grid-battle.md` CR-13 rule 4가 DEFEND_STANCE 유닛의 반격을 전면 억제하므로 이 페널티가 실제 적용되는 코드 경로가 없다 (`grid-battle.md` Tuning Knobs v5.0 pass-9b Q3 INERT 주석 참조). 미래의 mid-turn DEFEND 스킬 설계 시 해당 스킬 맥락에서 재평가해야 하며, 현재 값(40%)을 "검증된 값"으로 이월하지 말 것. |
| `INSPIRED_ATK_BONUS` | 20% | 10%–30% | 버프 유닛이 일격사 → 전투 변동성 과다 | 버프 효과 미미 → Commander 가치 하락 | `hp_status_config.json` |
| `INSPIRED_DURATION` | 2 turns | 1–3 | 장기 버프 → 한 번 시전으로 충분 | 1턴 → 시전 후 즉시 소멸 → 타이밍 극단적 | `hp_status_config.json` |
| `EXHAUSTED_MOVE_REDUCTION` | 1 | 1–2 | 이동 불가 수준 → 게임 불가 | (1이 최소) | `hp_status_config.json` |
| `EXHAUSTED_HEAL_MULT` | 0.5 | 0.3–0.7 | 회복 거의 무효 → 독+피로 즉사 | 피로의 전술적 의미 소멸 | `hp_status_config.json` |
| `MODIFIER_FLOOR` | -50% | -60%–-20% | 디버프 영향 약화 | 스탯이 0 수준까지 떨어짐 → 유닛 무력화 | `hp_status_config.json` |
| `MODIFIER_CEILING` | +50% | +20%–+60% | 버프 누적이 과도 | 버프 효과 미미 | `hp_status_config.json` |
| `MAX_STATUS_EFFECTS_PER_UNIT` | 3 | 2–4 | 복잡한 다중 효과 → 가독성 하락 | 효과 간 시너지 불가 | `balance_constants.json` |

### 상호작용 주의

- `DEFEND_STANCE_REDUCTION(50%)` + 지형 방어(최대 30%) = 복합 피해 감소.
  Damage Calc에서 지형 방어를 `resolved_damage` 산출 시 적용하므로 이중 적용
  아님. 하지만 체감상 고방어 유닛 제거 불가 상황 발생 가능 → 테스트 필수.
  (rev 2026-04-19: 30% → 50% per grid-battle v5.0; 상한 지형(+30%)과 결합 시
  순 수신 피해는 최소 35% 수준까지 감소 — attacker-never-commit 임계값 위험은
  reviewer 테스트로 확인.)
- `DOT_FLAT` + `DOT_HP_RATIO`: 저HP 유닛(Strategist)에서 DOT_FLAT 비중이
  높아 POISON이 상대적으로 더 위험 (EC-15).
- `DEMORALIZED_RADIUS(4)` + 맵 크기(15-40칸): 작은 맵에서 Commander 사망 시
  거의 전 유닛 영향.
- `EXHAUSTED_HEAL_MULT(0.5)` + `POISON`: 독+피로 동시 적용 시 독 피해 축적 +
  회복 약화 = 치명적 조합.

### 튜닝 우선순위 (초기 밸런스 패스)

1. **HEAL_BASE + HEAL_HP_RATIO** — 회복량이 전투 길이를 결정
2. **DOT_HP_RATIO + DOT_FLAT** — 독의 위협도가 정적 플레이 vs. 기동 플레이 균형 결정
3. **DEFEND_STANCE_REDUCTION + ATK_PENALTY** — 방어 행동의 가성비
4. **DEMORALIZED_ATK_REDUCTION + RADIUS** — 사기 시스템의 전술적 무게
5. **MODIFIER_FLOOR / CEILING** — 후반부 튜닝. 다중 효과 밸런스

## Visual/Audio Requirements

### HP Bar Visual Treatment

HP 바는 유닛 스프라이트 하단에 4px 높이의 서예 먹선(brushstroke)으로 렌더링된다.
단순히 줄어드는 것이 아니라, 먹의 농담이 변한다:

- **Full HP (100%)**: 짙은 먹(#1C1A17). 선명하고 약간 불규칙한 먹선 — 자신감 있는 필획.
- **Mid HP (60–99%)**: 먹이 옅어짐(#5C5449). 가장자리 번짐 증가.
- **Low HP (30–59%)**: 얇아진 먹(#8C7A5A). 바 자체가 시각적으로 좁아짐 — 먹이 옅어지는 것을 표현. 가장자리 갈라짐.
- **Critical HP (<30%)**: 거의 마른 먹(#C8A878). 느린 불규칙 맥동(opacity 70%→100%, 1.5s). **주홍 금지** — 위험은 먹의 부재로 표현.

아군 HP 바: #4A8FBF 기반. 적군: #7A7A7A 기반. 수치는 항상 7pt 이상 표시(접근성).
44px 최소 터치 타겟 높이 보장.

### Status Effect Icons

16×16px(표시)/32×32px(원본) 단색 먹 드로잉, 반투명 배경.

| Effect | Icon | 먹 처리 | 색상 악센트 |
|--------|------|--------|-----------|
| 독 (POISON) | 먹선 위 물방울 — 아래쪽 번짐 | 하단 번짐, 상단 선명 | #4A6B3A (이끼색) |
| 사기저하 (DEMORALIZED) | 부러진 깃대의 늘어진 군기 | 건필, 꺾임점에서 끊긴 선 | 없음 (순수 묵) |
| 방어태세 (DEFEND_STANCE) | 정면 방패, 굵은 수평 먹선 | 두꺼운 필획, 균일한 가장자리 | 없음 (순수 묵 굵게) |
| 고무 (INSPIRED) | 위로 솟는 필획(勇 핵심 획 스타일) | 시작 얇고 끝에 올림 | #C8874A (황토) |
| 피로 (EXHAUSTED) | 오른쪽으로 처지는 수평 필획 | 왼→오 획 굵기 감소, 끝 갈라짐 | 없음 (순수 묵 옅게) |

버프(DEFEND_STANCE, INSPIRED): 1px #5C7A8A 테두리. 디버프: 테두리 없음 (색맹 안전).
남은 턴 수: 아이콘 우하단 6pt 묵색 숫자.

### Status Effect Sprite Overlays

- **독**: 스프라이트 하반부에 느린 먹 번짐 비네팅(#4A6B3A, 20% opacity). 매 틱마다 미세 확장.
- **사기저하**: 스프라이트 15% 탈색 + 수평 미세 흔들림(±1px, 2s 주기). 존재감 약화.
- **방어태세**: 스프라이트 내부에 #5C7A8A 1px 이중 윤곽선. "봉인된" 느낌.
- **고무**: 스프라이트 중심에서 #C8874A 방사형 미광(15% opacity). 8% 밝기 증가.
- **피로**: idle 호흡 애니메이션 정지. 10% opacity 교차선 텍스처 오버레이.

모든 오버레이는 셰이더/CanvasItem 효과 — 기본 텍스처 미수정.

### Damage Number Presentation

부유 숫자는 서예풍 숫자 스타일(목판 스탬프 느낌):

- **물리 피해**: 묵(#1C1A17), 18pt(기본)→24pt(강타). 0.8s 상승 후 페이드. 5° 우측 기울임.
- **독 틱**: 14pt, #4A6B3A. 1.2s 느린 상승 + ±2px 횡방향 미동.
- **회복**: 14pt, #4A8FBF. 위쪽 필획 마크 + 1.0s 상승. 기울임 없음.
- **회피**: "避" 12pt #8C7A5A 스탬프. 상승 없이 0.6s 제자리 페이드.
- **DEFEND_STANCE 감소**: 일반 물리 피해 숫자 + 1px #5C7A8A 테두리.

**주홍/금색 금지** — 강타는 크기와 무게로 표현.

### Death Visual

유닛 사망 시 먹선 소멸 연출:

1. **Beat (0–0.1s)**: 스프라이트 25% 밝기 플래시(단일 프레임) — 붓이 떠나기 직전 마지막 압력.
2. **Dissolve (0.1–1.2s)**: 묵화 전환(탈색) + 하단→상단 알파 페이드. 윤곽선이 마지막에 사라짐. 화선지가 인물을 흡수하듯.
3. **Remnant (1.2–3.0s)**: 10% opacity 먹 실루엣(잔영)이 타일에 남음. 명명 영웅은 20% opacity, 3.0s 지속.
4. **DEMORALIZED 전파**: Commander 사망 시, 용해 중 먹 균열선이 반경 내 영향받는 유닛으로 방사(0.3s 표시).

폭발/화면 플래시/주홍 없음. 죽음은 먹의 끝. 침묵과 소멸이 감정적 무게.

### Audio Cues

잉크워시 화구 소재 기반 음향: 종이, 붓, 먹, 고요. 전자 처리 없음.

| Event | Sound Spec | Duration |
|-------|-----------|----------|
| 물리 피해 | 화선지 붓 끌림 + 원거리 피고(皮鼓) 타격. 잔여 HP 낮을수록 북소리 음고 하강 | 0.3–0.5s |
| 강타 (≥150%) | 피해 동일 + 0.05s 간격 이중 북 | 0.5–0.7s |
| 회복 | 고금(古琴) 하모닉스 단음 + 먹 재충전(붓이 벼루에 닿는) 소리 | 0.4s |
| 독 적용 | 마른 종이 위 물방울 — 번짐. 종이가 수분을 흡수하는 소리 | 0.5s |
| 독 틱 | 짧은 물 묻은 붓 끌림. 물리 피해보다 조용함 | 0.2s |
| 독 해제 | 마른 종이 바스락 — 물이 증발, 종이만 남음 | 0.3s |
| 사기저하 적용 | 군기 천 접힘 소리 + 이호(二胡) 단2도 불협 | 0.6s |
| 사기저하 회복 | 이호 단2도→완전1도 해결 | 0.3s |
| 방어태세 적용 | 두꺼운 먹붓이 종이에 눌리는 소리. 짧고 건조 | 0.2s |
| 방어태세 해제 | 동일 누름 + 붓 들어올림 소리 | 0.3s |
| 고무 적용 | 대나무피리(笛) 또는 고금 상행 단음 | 0.3s |
| 고무 만료 | 적용 음의 잔향 감쇠 | 자연 감쇠 |
| 피로 적용 | 느린 호기 — 풀무/대나무 바람 소리 | 0.7s |
| 피로 만료 | 동일 호기 반속도, 조용히 | 0.4s |
| 병사 사망 | 지속 붓 끌림, 점점 얇아짐. 종이 속삭임. 북 없음 | 0.8s |
| 영웅 사망 | 병사 사망 + 고금 저음 개방현 한 음(장례) | 1.5–2.0s |

**글로벌 규칙**: 운명 분기 음향(오케스트라 스팅, 극적 강세)은 HP/Status에서 금지.
잉크와 종이 메타포만 사용. 침묵과 질감이 주요 도구.

## UI Requirements

### Battle HUD — HP Display

유닛 선택/호버 시 표시되는 **유닛 정보 패널**:

| Element | Spec |
|---------|------|
| HP Bar | 먹선 브러시스트로크 (Visual/Audio Requirements 참조). 너비 ≥ 80px, 높이 4px. |
| HP Text | `current_hp / max_hp` 서체 7pt 이상. 바 우측 또는 상단. |
| HP Change Feedback | 피해: 0.3s 슬라이드 감소 (이전 값→새 값). 회복: 0.3s 슬라이드 증가. 즉시 점프 금지. |
| Status Icons | HP 바 하단에 수평 배치. 최대 3개(MAX_STATUS_EFFECTS_PER_UNIT). 16×16px. |
| Remaining Turns | 각 아이콘 우하단 6pt 숫자. ACTION_LOCKED 효과는 숫자 대신 잠금 표시(鎖). |

**필드 위 미니 HP 바**: 그리드 타일 위 유닛 스프라이트 하단에 항시 표시. 아군: #4A8FBF 기반, 적군: #7A7A7A 기반. 터치 시 전체 유닛 정보 패널 확장.

### Status Effect Detail View

유닛 정보 패널에서 상태 아이콘을 **롱프레스(터치) / 호버(마우스)** 시 확장 뷰:

| Element | Spec |
|---------|------|
| Effect Name | 한글명 + 한자 (예: "독(毒)") |
| Effect Type | BUFF / DEBUFF 라벨. 버프: #5C7A8A 테두리, 디버프: 테두리 없음 |
| Duration | "N턴 남음" 또는 "행동 시 해제" |
| Modifier Values | 원본 → 수정값 표시 (예: "ATK: 82 → 77 (-5%)") |
| Description | 1줄 한글 설명 (예: "매 턴 독 피해. 방어 무시.") |

팝업은 화면 가장자리에서 잘리지 않도록 자동 배치. 닫기: 터치 바깥 탭 / 마우스 이탈.

### Defend Action UI

| Element | Spec |
|---------|------|
| Action Menu | 턴 행동 메뉴에 "방어(防禦)" 항목 표시. 모든 병종. |
| EXHAUSTED 비활성화 | EXHAUSTED 상태일 때 "방어" 항목 회색 처리 + "피로로 태세 유지 불가" 툴팁. |
| Active Indicator | DEFEND_STANCE 진입 시 유닛 스프라이트에 방패 아이콘 오버레이 + 유닛 정보 패널 상태 표시. |
| Release Feedback | 이동/공격 시 DEFEND_STANCE 해제 — 방패 오버레이 0.2s 페이드아웃. |

### Touch & Mouse Requirements

| Requirement | Spec |
|-------------|------|
| 최소 터치 타겟 | 44×44px (모든 인터랙티브 요소) |
| HP 바 터치 | 필드 미니 HP 바 탭 → 유닛 정보 패널 확장 |
| 상태 아이콘 상세 | 롱프레스(500ms, 터치) / 호버(마우스) → 상세 뷰 |
| 호버 전용 금지 | 모든 호버 정보는 롱프레스로도 접근 가능 |
| 피해 숫자 위치 | 유닛 스프라이트 상단. 동시 다수 발생 시 수직 스태킹 (겹침 방지) |
| 접근성 | HP 수치 항상 텍스트로 표시 (바 색상만 의존 금지). 색맹 안전: 버프/디버프 구분은 테두리 유무로. |

## Acceptance Criteria

### HP Lifecycle

**AC-01.** Given 전투 시작 시, When 모든 유닛 초기화, Then 모든 유닛의 `current_hp == max_hp`. 예외 없음.

**AC-02.** Given 전투 중 임의 시점, When `current_hp` 조회, Then `0 ≤ current_hp ≤ max_hp` 항상 성립.

### Damage Intake Pipeline

**AC-03.** Given Infantry(Shield Wall 보유)가 PHYSICAL `resolved_damage=40` 수신, When damage pipeline 통과, Then `post_passive = 40 - 5 = 35`, `final_damage = 35`, HP 35 감소.

**AC-04.** Given Infantry(Shield Wall 보유)가 MAGICAL `resolved_damage=40` 수신, When damage pipeline 통과, Then Shield Wall 미적용, `final_damage = 40`, HP 40 감소.

**AC-05.** Given `resolved_damage=3`, PHYSICAL, Shield Wall active, When damage pipeline 통과, Then `3-5=-2` → `max(1,-2)=1`. MIN_DAMAGE 적용, HP 1 감소.

**AC-06.** Given DEFEND_STANCE 활성 유닛이 `resolved_damage=20` 수신, When damage pipeline 통과, Then `floor(20×0.50)=10`, HP 10 감소. (rev 2026-04-19: 14 → 10 per `defend_stance_reduction` 30→50.)

### Healing Pipeline

**AC-07.** Given Strategist(max_hp=106)에 기본 회복 적용, When healing pipeline 통과, Then `floor(15 + ceil(106×0.10)) = 26`. current_hp 26 증가 (max_hp 미초과).

**AC-08.** Given current_hp == max_hp인 유닛에 회복, When healing pipeline 통과, Then HP 변동 없음. heal_amount = 0.

**AC-09.** Given EXHAUSTED 상태 유닛에 heal_amount=39 회복, When healing pipeline 통과, Then `max(1, floor(39×0.5)) = 19`. HP 19 증가.

**AC-10.** Given current_hp == 0 유닛에 회복 시도, When 회복 함수 호출, Then 파이프라인 미진입. 회복 거부.

### Status Effects

**AC-11.** Given 유닛에 POISON(3턴) 활성, When 동일 소스가 POISON 재적용, Then 기존 POISON의 remaining_turns가 3으로 갱신. 중첩 없음.

**AC-12.** Given 유닛에 3개 효과 활성(POISON+DEMORALIZED+INSPIRED), When EXHAUSTED 적용, Then 가장 오래된 효과(POISON) 퇴거, EXHAUSTED 적용. 총 3개 유지.

**AC-13.** Given DEMORALIZED(-25%) + INSPIRED(+20%) 동시 활성, When ATK 수정자 계산, Then `clamp(-25+20, -50, +50) = -5`. modified_atk = `floor(base×0.95)`.

**AC-14.** Given DEMORALIZED(-25%) + DEFEND_STANCE(-40%) 동시 활성, When ATK 수정자 계산, Then `clamp(-65, -50, +50) = -50`. 캡 적용.

### Mutual Exclusion

**AC-15.** Given EXHAUSTED 상태 유닛, When 방어 행동 시도, Then 행동 실패. "피로로 태세 유지 불가" 피드백.

**AC-16.** Given DEFEND_STANCE 활성 유닛, When EXHAUSTED 적용, Then DEFEND_STANCE 강제 해제 → EXHAUSTED 적용.

### Death & DEMORALIZED Propagation

**AC-17.** Given `current_hp == 0` 도달, When 사망 판정, Then `unit_died` 시그널 발생. 유닛 즉시 전장 제거.

**AC-18.** Given Commander 사망, When DEMORALIZED 전파, Then 맨해튼 거리 ≤ `DEMORALIZED_RADIUS`(4) 내 아군 전원에 DEMORALIZED(4턴) 적용.

**AC-19.** Given DEMORALIZED 유닛, When 아군 영웅이 맨해튼 거리 ≤ 2 이내 존재, Then 다음 턴 시작 시 DEMORALIZED 해제.

### Counter-Attack Interaction

**AC-20.** Given DEFEND_STANCE 활성 유닛이 피격, When 반격 조건(CR-6) 평가, Then 반격은 발생하지 않는다 (DEFEND_STANCE suppression per grid-battle.md CR-13 rule 4). `counter_attack_triggered` 미발화, 공격자는 무사. 수신 피해는 SE-3의 -50% 감소만 적용. (rev 2026-04-19: v3.2/v4.0의 "반격 시 태세 해제" 모델 폐기, pure-defensive commitment으로 재정의.)

## Open Questions

1. **부활 메카닉 (VS+ scope)**: MVP에서 DEAD→ALIVE 전이는 없다. VS 이후 부활 스킬/아이템 도입 시, 부활 HP 비율(25%? 50%?), 상태 효과 초기화 여부, 부활 무적 시간 등의 설계가 필요하다.

2. **HP 이월 (캠페인 연속 전투)**: MVP는 전투마다 풀 HP 리셋. 시나리오 모드에서 연속 전투(야영 없이 2-3연전) 도입 시, HP 이월/부분 회복 규칙이 필요하다. Balance/Data System과 협의.

3. **추가 상태 효과 (VS+ scope)**: MVP 5종 이후 확장 후보: VULNERABLE(수신 피해 +25%), BURN(지형 연동 DoT), STUN(1턴 행동 불가), REGENERATION(턴당 HP 회복). 우선순위는 Damage Calc 및 Grid Battle GDD 작성 후 결정.

4. **is_morale_anchor 기준**: Hero DB에 추가할 `is_morale_anchor` 플래그의 부여 기준 — 스토리 기반(5호장군 등)인지, 스탯 기반(특정 통솔 임계값)인지, 명시적 디자이너 태깅인지 확정 필요.

5. **DEMORALIZED 중첩 전파**: Commander 사망 + `is_morale_anchor` 영웅 사망이 동시 또는 연속 발생 시, 이미 DEMORALIZED인 유닛에 대한 처리는 refresh(CR-5c)로 정의했으나, 복수 전파원에 의한 "강화된 사기저하" 가능성은 Alpha scope에서 재검토.

6. **DoT 타입 확장**: MVP는 POISON 단일 DoT. BURN 등 추가 시 `dot_type` enum 확장과 타입별 DOT_HP_RATIO/DOT_FLAT 분리 필요. F-3 테이블에 예비 행 배치 완료.
