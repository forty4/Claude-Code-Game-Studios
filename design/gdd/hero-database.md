# Hero Database (무장 데이터베이스)

> **Status**: Designed
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 3 — 모든 무장에게 자리가 있다 (Every Hero Has a Role)

## Overview

무장 데이터베이스는 천명역전에 등장하는 모든 무장(武將)의 정적 속성과 기본
데이터를 정의하는 Foundation 시스템이다. 각 무장의 이름, 소속 세력, 병종,
기본 스탯(무력/지력/통솔/민첩), 고유 스킬, 역사적 관계(의형제, 군신, 라이벌),
시나리오 합류 조건 등을 하나의 중앙 레지스트리에 기록하며, 6개 이상의 시스템
(Unit Role, HP/Status, Turn Order, Story Event, Character Growth,
Equipment/Item)이 이 데이터를 읽기 전용으로 참조한다.

Full Vision 기준 80-100명의 무장 데이터를 관리하며, MVP에서는 8-10명으로
제한한다. 이 시스템은 데이터 정의만 소유하고, 런타임 변경(레벨업, 장비 착용,
상태이상 등)은 소비하는 시스템이 각자 관리한다. 플레이어는 이 시스템을 직접
인식하지 않지만, 무장마다 "다르게 느껴지는" 모든 것 — 관우의 무력, 제갈량의
지력, 조운의 돌파력 — 의 근거가 이 데이터베이스에 있다.

## Player Fantasy

플레이어는 데이터베이스를 보지 않는다. 플레이어가 경험하는 것은 모든 무장이
고유한 질문을 품고 있다는 감각이다. 역사는 이미 굵은 붓으로 기록했다 —
용맹한 자, 지혜로운 자, 비극의 주인공. 그러나 군사(軍師)인 플레이어는 더
세밀한 결을 본다. 마속이 산을 잃지 않는 조건, 위연의 무모함이 자산이 되는
진형, 황충의 노련함이 젊은 장수를 압도하는 지형. 무장 데이터베이스가 각
무장에게 심어놓는 것은 능력치가 아니라 하나의 질문이다 — "이 무장은 어디에
속하는가?" 플레이어가 그 답을 전장에서 찾아낼 때, 약하다고 무시했던 무장이
변모하고, Pillar 3(모든 무장에게 자리가 있다)이 체감으로 증명된다.

*먹은 이미 말랐지만, 이야기는 아직 끝나지 않았다(墨已乾而事未了).
이 시스템은 Pillar 3(모든 무장에게 자리가 있다 — 올바른 배치가 어떤 무장이든
가치 있게 만든다)을 직접 지탱하며, Pillar 2(운명은 바꿀 수 있다 — 무장의
정체성은 고정된 답이 아니라 플레이어가 풀어야 할 질문)로 확장된다.*

## Detailed Design

### Core Rules

**CR-1. Hero Identifier**

모든 무장은 `hero_id` 문자열로 고유 식별한다. 형식: `{faction}_{seq}_{slug}`

| Component | Type | Example | Description |
|-----------|------|---------|-------------|
| `faction` | string | `shu`, `wei`, `wu`, `qun` | 소속 세력 접두사 |
| `seq` | string | `001` | 세력 내 순번 (3자리 zero-pad) |
| `slug` | string | `liu_bei` | 인물 영문 슬러그 |

예시: `shu_001_liu_bei`, `wei_001_cao_cao`, `wu_003_zhou_yu`, `qun_001_lu_bu`

ID는 불변이다. 세력 변경(예: 여포의 독립→조조→유비) 시에도 최초 등록 세력의
ID를 유지하며, 런타임 소속은 `faction` 필드가 시나리오에 따라 별도 관리한다.

**CR-2. Hero Record Schema**

하나의 무장 레코드는 다음 블록으로 구성된다.

**Identity Block**

| Field | Type | Range / Values | Description |
|-------|------|----------------|-------------|
| `hero_id` | string | `{faction}_{seq}_{slug}` | 고유 식별자 (Primary Key) |
| `name_ko` | string | — | 한국어 표시 이름 (유비) |
| `name_zh` | string | — | 한자 이름 (劉備) |
| `name_courtesy` | string | — | 자(字) (玄德). 빈 문자열 허용 |
| `faction` | enum | SHU, WEI, WU, QUNXIONG, NEUTRAL | 기본 소속 세력 |
| `portrait_id` | string | asset key | 인물화 에셋 참조 |
| `battle_sprite_id` | string | asset key | 전장 스프라이트 에셋 참조 |

**Core Stats Block** — 모든 값: int, 범위 1–100

| Field | Symbol | Description | Low (1-30) | High (70-100) |
|-------|--------|-------------|------------|---------------|
| `stat_might` | 무력 | 물리 공격력/근접 전투력 | 문관, 책사 | 맹장, 돌격형 |
| `stat_intellect` | 지력 | 전술, 계략, 특수 스킬 효과 | 순수 무인 | 군사, 책사 |
| `stat_command` | 통솔 | 진형 보너스 기여, 주변 유닛 버프 | 고독한 무인 | 대군 지휘관 |
| `stat_agility` | 민첩 | 회피, 이동 관련 보조 | 중장 보병 | 경기병, 첩자 |

설계 의도: 4스탯 체계는 Pillar 3(모든 무장에게 자리가 있다)을 지탱한다.
"최강" 조합이 존재하지 않도록, 스탯 총합은 고정되지 않지만 권장 범위를
밸런스 가이드라인으로 설정한다 (Tuning Knobs 참조).

**Derived Stat Seeds Block** — HP/턴순서 시스템의 입력값

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `base_hp_seed` | int | 1–100 | HP 산출 기준값. stat_might와 독립 — 내구력 ≠ 공격력 |
| `base_initiative_seed` | int | 1–100 | 턴 순서 산출 기준값. stat_agility와 독립 — 반응속도 ≠ 이동속도 |

**Movement Block**

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `move_range` | int | 2–6 | 이동력 (타일 수). move_budget = move_range × 10 (Map/Grid 계약) |

**Role Block**

| Field | Type | Range / Values | Description |
|-------|------|----------------|-------------|
| `default_class` | enum | CAVALRY, INFANTRY, ARCHER, STRATEGIST, COMMANDER, SCOUT | 기본 병종. Unit Role GDD에서 상세 정의 |
| `equipment_slot_override` | string[] or null | WEAPON, ARMOR, MOUNT, ACCESSORY 부분집합 | null = 병종 기본 슬롯 사용. 값이 있으면 개별 오버라이드 |

**Growth Block** — Character Growth System 입력값

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `growth_might` | float | 0.5–2.0 | 레벨업 시 무력 성장 배율 |
| `growth_intellect` | float | 0.5–2.0 | 레벨업 시 지력 성장 배율 |
| `growth_command` | float | 0.5–2.0 | 레벨업 시 통솔 성장 배율 |
| `growth_agility` | float | 0.5–2.0 | 레벨업 시 민첩 성장 배율 |

**Skills Block**

| Field | Type | Description |
|-------|------|-------------|
| `innate_skill_ids` | string[] | 고유 스킬 ID 목록 (순서 = 해금 순서). MVP: 최대 3개 |
| `skill_unlock_levels` | int[] | 병렬 배열 — 각 스킬 해금 레벨 (예: [1, 5, 15]) |

두 배열의 길이는 항상 동일해야 한다. 불일치 시 로딩 에러.

**Relationships Block** — 배열, 각 원소:

| Field | Type | Description |
|-------|------|-------------|
| `hero_b_id` | string | 상대 무장의 hero_id |
| `relation_type` | enum | SWORN_BROTHER, LORD_VASSAL, RIVAL, MENTOR_STUDENT |
| `effect_tag` | string | 효과 참조 키 (예: `sworn_atk_boost`). Formation/Battle 시스템이 해석 |
| `is_symmetric` | bool | true = 쌍방 적용. false = 단방향 (예: LORD_VASSAL에서 vassal→lord 충성 효과만) |

기술적 제약: 관계는 hero_id 문자열로만 참조한다. 오브젝트 참조 금지 —
Godot Resource 간 순환 로드 의존성 방지 (GP 확인 완료).

**Scenario Block**

| Field | Type | Description |
|-------|------|-------------|
| `join_chapter` | int | 합류 가능 시나리오 장 (1-indexed) |
| `join_condition_tag` | string | 합류 조건 키 (Story Event GDD 참조). 빈 문자열 = 무조건 합류 |
| `is_available_mvp` | bool | true = MVP 로스터 포함 (8-10명) |

**CR-3. 스탯 밸런스 가이드라인**

Pillar 3 준수를 위해, 무장은 "만능"이 되어서는 안 된다.

- 4스탯 합산 권장 범위: 180–280
- 최고 스탯 1개 + 최저 스탯 1개의 차이: 최소 30 이상
- 예외: 여포 같은 "역사적 최강" 무장도 지력이 현저히 낮아야 함
- stat_total이 280을 초과하는 무장은 설계 검토 필수 (High-Risk 플래그)

이 가이드라인은 밸런싱 도구이지 하드 제약이 아니다. 최종 값은 Balance/Data
System과 프로토타입 테스트에서 확정.

**CR-4. 병종(Class) 열거**

| Class | 한글 | 대표 무장 | 특징 키워드 |
|-------|------|----------|------------|
| CAVALRY | 기병 | 조운, 마초 | 높은 이동력, 돌파 |
| INFANTRY | 보병 | 관우, 장비 | 방어, 진형 유지 |
| ARCHER | 궁병 | 황충, 간옹 | 원거리, LoS 활용 |
| STRATEGIST | 책사 | 제갈량, 방통 | 계략, 범위 효과 |
| COMMANDER | 지휘관 | 유비, 조조 | 통솔 버프, 진형 코어 |
| SCOUT | 척후 | 위연, 마대 | 정찰, 기습 |

상세 능력치/상성은 Unit Role GDD 소관. Hero DB는 default_class만 기록.

### States and Transitions

무장 데이터베이스 자체는 정적 데이터 저장소이므로 런타임 상태 머신이 없다.
단, 무장의 **가용성 상태**는 시나리오 시스템과 연동한다:

| Availability State | 조건 | 설명 |
|-------------------|------|------|
| LOCKED | 현재 챕터 < join_chapter | 아직 등장하지 않음 |
| CONDITIONAL | 현재 챕터 ≥ join_chapter AND join_condition 미충족 | 조건 충족 시 합류 가능 |
| AVAILABLE | join_condition 충족 또는 빈 문자열 | 편성 가능 |
| IN_PARTY | AVAILABLE + 현재 파티에 편성됨 | 전투 투입 가능 |
| DEPARTED | 시나리오 이벤트로 퇴장 (사망, 배신 등) | 더 이상 사용 불가 |

전이:
- LOCKED → CONDITIONAL (챕터 진행)
- CONDITIONAL → AVAILABLE (조건 충족)
- AVAILABLE ↔ IN_PARTY (편성/해제)
- AVAILABLE / IN_PARTY → DEPARTED (시나리오 이벤트)
- DEPARTED → AVAILABLE (운명 분기로 역전 — Pillar 2)

가용성 상태는 Hero DB가 소유하지 않는다. Scenario Progression / Destiny
Branch 시스템이 관리하며, Hero DB는 join_chapter과 join_condition_tag만 제공.

### Interactions with Other Systems

Hero DB가 외부에 노출하는 쿼리 인터페이스:

| Query | Used By | Return |
|-------|---------|--------|
| `get_hero(hero_id)` → HeroRecord | All consumers | 전체 레코드 (읽기 전용) |
| `get_heroes_by_faction(faction)` → Array[HeroRecord] | Story Event, Battle Prep | 세력별 무장 목록 |
| `get_heroes_by_class(class)` → Array[HeroRecord] | Unit Role, AI | 병종별 무장 목록 |
| `get_relationships(hero_id)` → Array[Relationship] | Formation Bonus, Story Event | 해당 무장의 관계 목록 |
| `get_all_hero_ids()` → Array[string] | Save/Load, Scenario | 전체 무장 ID 목록 |
| `get_mvp_roster()` → Array[HeroRecord] | MVP 빌드 전용 | is_available_mvp=true인 무장만 |

데이터 흐름 방향:

```
Hero DB (읽기 전용 제공)
  ├→ Unit Role System: default_class, stat_might/intellect/command/agility
  ├→ HP/Status System: base_hp_seed, stat_might(보조)
  ├→ Turn Order System: base_initiative_seed, stat_agility(보조)
  ├→ Formation Bonus: relationships(SWORN_BROTHER 등), stat_command
  ├→ Story Event System: faction, join_chapter, join_condition_tag, relationships
  ├→ Character Growth: growth_might/intellect/command/agility, 현재 스탯 기준값
  ├→ Equipment/Item: default_class(슬롯 기본), equipment_slot_override
  ├→ Damage Calc: stat_might, stat_intellect (공격력 계산 입력)
  └→ AI System: 전체 스탯 + 병종 (AI 위협 평가)
```

모든 외부 시스템은 읽기 전용 접근만 허용. Hero DB의 값은 런타임에 변경되지
않는다. 레벨업/장비/버프에 의한 수치 변화는 각 소비 시스템이 "base + modifier"
패턴으로 자체 관리한다.

## Formulas

### F-1. Stat Total Validation

```
stat_total = stat_might + stat_intellect + stat_command + stat_agility
is_valid   = (STAT_TOTAL_MIN <= stat_total <= STAT_TOTAL_MAX)
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| stat_might | int | 1–100 | 무력 |
| stat_intellect | int | 1–100 | 지력 |
| stat_command | int | 1–100 | 통솔 |
| stat_agility | int | 1–100 | 민첩 |
| stat_total | int | 4–400 | 4스탯 합산 |
| STAT_TOTAL_MIN | int | const = 180 | 하한 (tuning knob) |
| STAT_TOTAL_MAX | int | const = 280 | 상한 (tuning knob) |

**Output Range:** bool. 180–280 = valid. 280 초과 시 High-Risk 플래그.

**Example:** 관우 — 무력 92, 지력 52, 통솔 75, 민첩 56 → total = 275.
180 ≤ 275 ≤ 280 → **PASS**.

---

### F-2. Stat Polarization Index (SPI)

```
SPI = (stat_max - stat_min) / stat_avg
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| stat_max | int | 1–100 | 4스탯 중 최댓값 |
| stat_min | int | 1–100 | 4스탯 중 최솟값 |
| stat_avg | float | 1.0–100.0 | 4스탯 평균 |
| SPI | float | 0.0–~3.3 | 전문화 지수. 높을수록 특화형 |

**Output Range:** 0.0 (완전 균등) ~ 이론 최대 ~3.3.
**SPI < 0.5 = "너무 평탄" 경고 플래그.** Max-min gap ≥ 30 요건과 별도 작동.

**Example (너무 평탄):** 모든 스탯 60 → (60-60)/60 = **0.0**. FLAG.

**Example (건강한 특화):** 제갈량 — 지력 97, 무력 18, 통솔 76, 민첩 55
→ max=97, min=18, avg=61.5 → SPI = 79/61.5 ≈ **1.28**. PASS.

---

### F-3. Growth Rate Balance Check

```
stat_projected(L) = stat_base + floor(stat_base × growth_rate × (L / L_cap))
growth_ceiling     = (STAT_HARD_CAP - stat_base) / (stat_base × 1.0)
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| stat_base | int | 1–100 | 해당 스탯의 기초값 |
| growth_rate | float | 0.5–2.0 | 해당 스탯의 성장 배율 |
| L | int | 1–L_cap | 현재 레벨 |
| L_cap | int | const = 30 | 레벨 상한 (**잠정** — Character Growth GDD에서 확정) |
| STAT_HARD_CAP | int | const = 100 | 스탯 절대 상한 |
| stat_projected | int | 1–100 | L레벨에서의 예측 스탯값 (100 클램프) |
| growth_ceiling | float | — | 해당 base에서 100을 초과하지 않는 최대 growth_rate |

**Output Range:** stat_projected는 100에 클램프.

**Example:** 관우 무력 base=92, growth_might=1.8, L_cap=30
→ projected(30) = 92 + floor(92 × 1.8 × 1) = 92 + 165 → **클램프 → 100**.
growth_ceiling = (100-92)/(92×1) ≈ 0.087 — growth=1.8은 매우 조기에 상한 도달.
설계 의도면 허용, 아니면 growth를 낮춰야 함.

---

### F-4. MVP Stat Budget

```
mvp_stat_budget_min = STAT_TOTAL_MIN + MVP_FLOOR_OFFSET   (= 180 + 10 = 190)
mvp_stat_budget_max = STAT_TOTAL_MAX - MVP_CEILING_OFFSET (= 280 - 20 = 260)
role_coverage_check = COUNT(DISTINCT dominant_stat per hero) >= 4
dominant_stat(hero)  = argmax(stat_might, stat_intellect, stat_command, stat_agility)
```

| Variable | Type | Range | Description |
|----------|------|-------|-------------|
| MVP_ROSTER_SIZE | int | 8–10 | MVP 포함 무장 수 (tuning knob) |
| MVP_FLOOR_OFFSET | int | const = 10 | MVP 하한 상향 보정 |
| MVP_CEILING_OFFSET | int | const = 20 | MVP 상한 하향 보정 |
| mvp_stat_budget_min | int | — | MVP 무장 stat_total 하한 = 190 |
| mvp_stat_budget_max | int | — | MVP 무장 stat_total 상한 = 260 |
| dominant_stat | enum | might/intellect/command/agility | 무장의 최고 스탯 카테고리 |
| role_coverage_check | bool | — | 로스터가 4개 dominant_stat을 모두 커버하면 true |

**Output Range:** MVP 무장 stat_total 190–260. role_coverage = true가 로스터 승인 조건.

**Example (8-hero roster):** 무력 dominant 2명, 지력 dominant 2명, 통솔 dominant 2명,
민첩 dominant 2명 → DISTINCT count = 4 ≥ 4 → **PASS**.
민첩 dominant가 0명이면 FAIL — 민첩 특화 무장을 로스터에 추가해야 함.

## Edge Cases

**EC-1. 중복 ID**
- **If 두 레코드가 동일한 `hero_id`를 사용**: 데이터베이스 로딩 전체 거부
  (fatal error). 중복 ID 명시. 무음 덮어쓰기 금지 — 런타임에서 재현 불가
  버그의 원인.

**EC-2. 스킬 배열 길이 불일치**
- **If `innate_skill_ids.size() != skill_unlock_levels.size()`**: 해당 hero
  레코드 로딩 거부 (fatal error). hero_id와 양쪽 배열 길이 명시. 패딩/자름
  금지 — 항상 저작 오류.

**EC-3. 빈 스킬 배열**
- **If 두 배열 모두 빈 배열 (`[]`)**: 유효. 고유 스킬 없는 무장 허용.
  길이 0은 에러가 아님 — 불일치만 불법.

**EC-4. 관계 자기 참조**
- **If `hero_b_id == hero_id` (자기 자신과의 관계)**: 해당 관계 항목 거부 +
  에러 로그. 자기 참조 관계 튜플은 어떤 게임 시스템에도 전달되지 않는다.

**EC-5. 관계 대상 미존재 (orphaned hero_b_id)**
- **If `hero_b_id`가 데이터베이스에 없는 hero_id를 참조**: 해당 관계 항목
  삭제 + 경고 (fatal 아님). hero 레코드 자체는 정상 로딩. MVP 빌드에서
  Full Vision 무장이 생략되면 고아 참조는 예상 가능한 상태이므로 로딩을
  차단하지 않는다.

**EC-6. 비대칭 관계 충돌**
- **If hero A→B가 RIVAL(is_symmetric=true)이고 hero B→A가
  SWORN_BROTHER(is_symmetric=true)**: 양쪽 관계 모두 독립 로딩. Hero DB는
  충돌 해소하지 않음 — Formation Bonus 시스템이 중재. 로드 시 설계 경고
  플래그를 발생시켜 검토 유도.

**EC-7. 스탯 전부 1 (극단값)**
- **If 모든 스탯이 1**: stat_total = 4. F-1 검증 FAIL (4 < 180). SPI = 0.0
  (F-2 경고). 레코드 로딩은 가능하나 High-Risk 플래그 + 로스터 승인 차단.

**EC-8. stat_total 경계값 (180, 280)**
- **If stat_total이 정확히 180 또는 280**: 유효 (닫힌 구간). 280은 High-Risk
  플래그 미발생 — 281부터 발생. off-by-one 방지를 위해 닫힌 구간임을 명시.

**EC-9. 성장률 오버슈트 (고 base + 고 growth)**
- **If stat_projected(L_cap) > 100**: 100에 클램프. 에러 없음 — 의도적 설계.
  단, growth_ceiling < 0.5 (growth_rate 최소값 미만)이면 경고: "해당 스탯의
  성장률이 실효성 없음 — 기초값만으로 상한 근접."

**EC-10. MVP 로스터 부족**
- **If `is_available_mvp == true`인 무장 < 8명**: `get_mvp_roster()`는 있는
  만큼만 반환. DB 레이어에서 차단하지 않음 — 로스터 크기 검증은 빌드
  파이프라인(Acceptance Criteria)의 책임.

## Dependencies

### 상위 의존성 (이 시스템이 의존하는 것)

없음 — Foundation 레이어. 외부 시스템 없이 독립 작동한다.

### 하위 의존성 (이 시스템에 의존하는 것)

| System | 의존 유형 | 사용하는 쿼리 | 참조 데이터 |
|--------|----------|-------------|-----------|
| Unit Role System | Hard | `get_hero()` | default_class, stat_might/intellect/command/agility |
| HP/Status System | Hard | `get_hero()` | base_hp_seed, stat_might(보조) |
| Turn Order/Action Mgmt | Hard | `get_hero()` | base_initiative_seed, stat_agility(보조) |
| Damage/Combat Calc | Hard | `get_hero()` | stat_might, stat_intellect |
| Formation Bonus | Hard | `get_relationships()` | relation_type, effect_tag, stat_command |
| Story Event System | Hard | `get_heroes_by_faction()`, `get_relationships()` | faction, join_chapter, join_condition_tag |
| Character Growth | Hard | `get_hero()` | growth_might/intellect/command/agility, base stats |
| Equipment/Item System | Hard | `get_hero()` | default_class, equipment_slot_override |
| AI System | Soft | `get_hero()`, `get_heroes_by_class()` | 전체 스탯 + 병종 (위협 평가) |
| Battle Preparation | Soft | `get_heroes_by_faction()`, `get_mvp_roster()` | 편성 가능 무장 목록 |
| Scenario Progression (`design/gdd/scenario-progression.md` — Approved pending review) | Soft | `get_all_hero_ids()`, `get_hero(unit_id)` | 무장 가용성 관리 + chapter 시작 시 `unit_roster[]` 해석 (`join_chapter` int 1-indexed 소비) |

Hard = 이 시스템 없이 작동 불가. Soft = 없어도 기능하지만 정보가 축소됨.

### 크로스 시스템 계약

이 GDD에서 결정된 규칙으로, 다른 GDD가 반드시 따라야 한다:

- **move_range 정수 스케일**: move_budget = move_range × 10 (Map/Grid GDD 계약
  준수). Unit Role GDD에서 병종별 move_range 기본값 설정 시 이 범위(2-6) 사용.
- **읽기 전용 계약**: 모든 소비 시스템은 Hero DB 데이터를 수정하지 않는다.
  수치 변화는 "base + modifier" 패턴으로 각 시스템이 자체 관리.
- **hero_id 문자열 참조**: 모든 시스템은 hero_id 문자열로 무장을 참조한다.
  오브젝트 참조 금지.
- **관계 효과 해석**: effect_tag의 실제 효과는 Formation Bonus / Battle
  시스템이 정의. Hero DB는 태그만 저장.

## Tuning Knobs

| Knob | 현재 값 | 안전 범위 | 너무 높으면 | 너무 낮으면 | 영향 |
|------|---------|----------|-----------|-----------|------|
| `STAT_TOTAL_MIN` | 180 | 150–200 | 약한 무장이 사라짐 — 전체 파워 상향 | 너무 약한 무장 허용 — 밸런스 붕괴 | 스탯 합산 하한 |
| `STAT_TOTAL_MAX` | 280 | 250–320 | "만능" 무장 등장 가능 — Pillar 3 위반 | 모든 무장이 평탄 — 영웅감 부족 | 스탯 합산 상한 |
| `SPI_WARNING_THRESHOLD` | 0.5 | 0.3–0.8 | 경고가 너무 느슨 — 평탄 무장 통과 | 경고가 너무 엄격 — 균형형 무장 설계 불가 | 전문화 지수 하한 |
| `MIN_STAT_GAP` | 30 | 20–50 | 극단적 특화만 허용 — 설계 폭 축소 | 차별화 부족 — 무장 간 차이 불명확 | 최고-최저 스탯 차이 |
| `STAT_HARD_CAP` | 100 | 80–120 | 스탯 인플레이션 — 수치 변별력 감소 | 성장 여지 부족 — 레벨업 보상감 약화 | 개별 스탯 절대 상한 |
| `L_CAP` | 30 (잠정) | 20–50 | 성장이 느려짐 — 장기 그라인딩 | 금방 만렙 — 성장 동기 부족 | 레벨 상한 |
| `MOVE_RANGE_MIN` | 2 | 1–3 | 최소 이동력이 높아 저기동 무장 부재 | 이동 1칸은 실질 무력화 | 이동력 하한 |
| `MOVE_RANGE_MAX` | 6 | 5–8 | 기병이 맵 반을 횡단 — 밸런스 붕괴 | 고기동 유닛의 차별성 부족 | 이동력 상한 |
| `MVP_ROSTER_SIZE` | 8–10 | 6–12 | 밸런싱 대상 증가 — MVP 공수 증가 | 역할 커버리지 부족 | MVP 무장 수 |
| `MAX_INNATE_SKILLS` | 3 (MVP) | 2–5 | 무장 간 스킬 조합 폭발 — 밸런싱 난이도 | 무장 개성 표현 부족 | 무장당 고유 스킬 수 |
| `GROWTH_RATE_MIN` | 0.5 | 0.3–0.8 | 성장이 느린 스탯도 의미 있는 상승 | 버린 스탯이 더 버려짐 — 양극화 심화 | 성장 배율 하한 |
| `GROWTH_RATE_MAX` | 2.0 | 1.5–3.0 | 약한 스탯도 빠르게 성장 — 특화 의미 퇴색 | 성장이 느림 — 레벨업 보상감 약화 | 성장 배율 상한 |

### 상호작용 주의

- `STAT_TOTAL_MAX` × `GROWTH_RATE_MAX` 조합이 만렙 시 "모든 스탯 100" 근접을
  허용하는지 검증 필요 — Pillar 3 위반 가능
- `MOVE_RANGE_MAX`와 Map/Grid의 `terrain_cost_plains(10)` 조합: move_range=6
  → budget=60 → 평지 6칸. 최대 맵 40칸의 15%를 1턴에 이동 — 기병의 전략적 의미 확인
- `MVP_ROSTER_SIZE`와 `role_coverage ≥ 4` 조합: 6명 이하 시 4개 dominant_stat
  커버 불가능

## Visual/Audio Requirements

Foundation 시스템 — 직접적 시각/음향 요구사항 없음.
portrait_id와 battle_sprite_id 필드가 에셋을 참조하며, 에셋 사양은
Art Bible 및 개별 시스템 GDD(Battle HUD, Battle Effects)에서 정의.

## UI Requirements

Foundation 시스템 — 직접적 UI 없음.
무장 정보 표시(스탯, 스킬, 관계)는 Battle Preparation UI 및 Story Event UI
GDD에서 정의. Hero DB는 표시할 데이터를 제공할 뿐 화면 레이아웃을 소유하지 않는다.

## Acceptance Criteria

### Core Rules

**AC-01. Hero ID 형식 검증**
- **GIVEN** hero_id가 `wei_007_zhang_liao`인 레코드
- **WHEN** 데이터베이스가 파싱하면
- **THEN** 수정 없이 수용. `^[a-z]+_\d{3}_[a-z_]+$` 패턴 불일치 ID는 fatal error

**AC-02. 코어 스탯 범위 검증**
- **GIVEN** stat_might/intellect/command/agility 중 하나가 0 또는 101인 레코드
- **WHEN** 로딩 시도 시
- **THEN** 범위 외 필드와 값을 명시하며 거부

**AC-03. 파생 시드 범위 검증**
- **GIVEN** base_hp_seed=0 또는 base_initiative_seed=101인 레코드
- **WHEN** 로딩 시
- **THEN** 거부. 1과 100은 수용

**AC-04. move_range 경계 검증**
- **GIVEN** move_range=1 또는 7인 레코드
- **WHEN** 로딩 시
- **THEN** 거부. 2와 6은 수용

**AC-05. 성장률 경계 검증**
- **GIVEN** growth_might=0.4 또는 growth_agility=2.1인 레코드
- **WHEN** 로딩 시
- **THEN** 거부. 0.5와 2.0은 수용

**AC-06. 관계 레코드 구조**
- **GIVEN** hero_b_id, relation_type, effect_tag, is_symmetric이 모두 채워진 관계 항목
- **WHEN** 로딩 후 `get_relationships(hero_id)` 호출 시
- **THEN** 원본과 동일한 4개 필드를 가진 항목이 반환

**AC-07. 스킬 병렬 배열 무결성**
- **GIVEN** innate_skill_ids 3개, skill_unlock_levels 2개인 레코드
- **WHEN** 로딩 시도 시
- **THEN** hero_id와 양쪽 길이를 명시하며 거부. 양쪽 길이 0은 수용

### Formulas

**AC-08. F-1 stat_total — 닫힌 구간 경계**
- **GIVEN** stat_total이 각각 180, 280, 179, 281인 레코드 4개
- **WHEN** 검증 시
- **THEN** 180과 280은 valid, 179는 검증 실패, 281은 High-Risk 플래그

**AC-09. F-2 SPI 경고 임계값**
- **GIVEN** 4스탯이 모두 60인 무장 (SPI=0.0)
- **WHEN** 검증 시
- **THEN** SPI < 0.5 설계 경고 발생. SPI ≥ 0.5인 무장은 경고 없음

**AC-10. F-3 stat_projected 100 클램프**
- **GIVEN** stat_might=92, growth_might=1.8, L_cap=30인 무장
- **WHEN** 성장 공식 적용 시
- **THEN** stat_projected는 정확히 100. 100 초과 값은 반환 불가

**AC-11. F-4 MVP 로스터 검증**
- **GIVEN** is_available_mvp 무장들의 stat_total이 190-260이고 dominant_stat이 4종 모두 커버
- **WHEN** MVP 로스터 검증 시
- **THEN** PASS. stat_total 189/261이거나 특정 dominant 0명이면 FAIL

### Edge Cases

**AC-12. EC-1 중복 ID — 전체 거부**
- **GIVEN** `shu_001_liu_bei`를 공유하는 레코드 2개
- **WHEN** 데이터베이스 초기화 시
- **THEN** 전체 로딩 거부. 어떤 레코드도 메모리에 커밋되지 않음. 중복 ID 명시

**AC-13. EC-2 스킬 배열 불일치 — 레코드 거부**
- **GIVEN** innate_skill_ids 길이 2, skill_unlock_levels 길이 0인 레코드
- **WHEN** 로딩 시
- **THEN** 해당 레코드만 거부 (다른 레코드 정상 로딩). hero_id와 양쪽 길이 명시

**AC-14. EC-5 고아 관계 — 비치명 경고**
- **GIVEN** hero_b_id가 `qun_099_fictional`(미존재)을 참조하는 관계 항목
- **WHEN** 로딩 시
- **THEN** hero 레코드는 정상 로딩, 고아 관계만 삭제, 경고 로그에 미해결 hero_b_id 명시

### 성능 + 쿼리

**AC-15. 쿼리 인터페이스 + 성능**
- **GIVEN** 100명의 무장 데이터와 is_available_mvp=true 6명
- **WHEN** `get_mvp_roster()` 호출 시
- **THEN** 정확히 6명 반환. `get_hero("shu_001_liu_bei")`는 원본과 일치하는
  전체 레코드 반환. 100명 로딩 + 딕셔너리 구축은 100ms 이내 완료 (PC 최소 사양)

## Open Questions

1. **레벨 상한 (L_cap) 확정** — 현재 30으로 잠정. Character Growth GDD에서 확정
   필요. 성장 공식(F-3)의 모든 예측값이 이 값에 의존한다.
   Owner: Character Growth GDD | Target: MVP 설계 시

2. **스킬 정의 데이터 위치** — Hero DB는 innate_skill_ids만 저장. 스킬의 효과,
   코스트, 범위, 애니메이션 등 상세 정의를 어디에 둘 것인가? 별도 Skill/Ability
   GDD? Balance/Data System 내?
   Owner: systems-designer | Target: Unit Role GDD 설계 시 결정

3. **관계 효과(effect_tag) 정의** — Hero DB는 태그만 저장. `sworn_atk_boost`
   같은 태그의 실제 수치 효과는 어느 시스템이 정의하는가? Formation Bonus?
   별도 Relationship Effects 데이터?
   Owner: Formation Bonus GDD | Target: Formation Bonus 설계 시

4. **세력 변동(faction change) 처리** — hero_id의 세력 접두사는 불변이지만
   런타임 소속이 바뀌는 무장(예: 여포, 마초)의 데이터 관리. 시나리오별 faction
   오버라이드를 Hero DB에 둘 것인가, Scenario System에 둘 것인가?
   Owner: Scenario Progression GDD | Target: Vertical Slice

5. **MVP 로스터 구체 인원** — 8-10명 범위 내 구체 인원과 인물 선정 미확정.
   Pillar 3 검증을 위해 6개 병종 × 4개 dominant_stat 조합을 커버해야 한다.
   Owner: Game Designer | Target: MVP 프로토타입 전

6. **equipment_slot_override 실제 사용 빈도** — 병종별 기본 슬롯 + 개별
   오버라이드 설계를 채택했으나, 오버라이드가 필요한 무장이 소수이면 complexity
   대비 가치가 낮을 수 있음. Unit Role GDD에서 병종 슬롯 정의 후 재평가.
   Owner: Unit Role GDD + Equipment/Item GDD | Target: Alpha
