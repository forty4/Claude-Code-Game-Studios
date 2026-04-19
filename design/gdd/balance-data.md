# Balance/Data System (밸런스/데이터)

> **Status**: Designed
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-04-16
> **Implements Pillar**: All (infrastructure) — directly enforces Anti-Pillar "NOT 밸런스 붕괴 허용"

## Overview

밸런스/데이터 시스템은 천명역전의 모든 게임플레이 수치 — 스탯 범위, 지형 코스트,
데미지 공식 계수, 진형 보너스, 성장 곡선 — 를 외부 설정 파일에서 로딩하고
검증하여 런타임에 제공하는 Foundation 시스템이다. 코딩 표준의 "하드코딩 금지"
원칙을 시스템 수준에서 강제하며, 단일 데이터 파이프라인을 통해 5개 이상의
소비 시스템(Unit Role, Damage Calc, Scenario, Character Growth, Equipment)에
검증된 설정값을 배포한다.

이 시스템이 없으면 밸런스 조정마다 코드 수정이 필요하고, 80-100명의 무장과
40-50개 전투맵의 밸런싱이 사실상 불가능해진다. 플레이어는 이 시스템을 인식하지
않지만, "관우가 적절히 강하고 제갈량의 계략이 적절히 유용한" 모든 밸런스
판단의 데이터 근거가 여기에 있다. MVP에서는 핵심 설정 파일 3-5개로 시작하며,
Full Vision에서 전체 데이터 세트로 확장한다.

## Player Fantasy

서예가의 경지는 감탄할 획이 아니라 번지지 않는 먹에서 드러난다. 이 시스템은
붓 뒤의 절제다. 플레이어는 이것을 보지 못하지만, 사라지는 순간 즉시 알아챈다
— 한 무장이 모든 전장을 지배하는 순간, 진형 보너스가 자의적으로 느껴지는 순간,
성장 곡선이 초반 장을 사소하게 만드는 순간. 이 시스템이 제공하는 것은 일관성이다:
조운의 돌파와 제갈량의 계략과 황충의 노련한 활이 같은 전장에서 각자 뚜렷하고
의미 있는 자리를 차지한다는 조용한 확신. 80명의 무장이 80개의 진정한 선택지로
느껴지게 하는 보이지 않는 손이다 — 5명의 쓸 만한 무장과 75명의 장식이 아니라.
플레이어가 이 시스템을 경험하는 방식은 의심의 부재다.

*이 시스템은 Pillar 3(모든 무장에게 자리가 있다)과 Anti-Pillar(밸런스 붕괴 금지)를
직접 지탱하며, Pillar 1(형세의 전술 — 포지셔닝이 전투의 언어)의 전제 조건이다.
앵커 순간: 전투 준비 화면에서 플레이어가 세 가지 편성 사이에서 진심으로 고민할 때
— 그 고민 자체가 이 시스템이 작동하고 있다는 증거다.*

## Detailed Design

### Core Rules

**CR-1. System Scope**

밸런스/데이터 시스템은 세 가지를 소유한다:
1. **데이터 파일 포맷 표준** — 모든 게임 데이터 파일이 따라야 하는 JSON 봉투 형식
2. **로딩/검증 파이프라인** — 발견 → 파싱 → 검증 → 레지스트리 구축의 4단계 파이프라인
3. **크로스 시스템 상수** — 2개 이상의 GDD에서 참조하는 밸런스 상수 (`balance_constants.json`)

각 콘텐츠 시스템(Hero DB, Map/Grid, Unit Role 등)은 자체 데이터 스키마와 검증
규칙을 소유한다. Balance/Data는 프로토콜을 강제하고, 소유 시스템은 콘텐츠를 강제한다.

**CR-2. 데이터 카테고리 레지스트리**

| Category | File Pattern | Content | Schema Owner |
|----------|-------------|---------|------------|
| Hero Records | `assets/data/heroes/*.json` | 무장별 1파일 (hero_id 기준) | Hero Database GDD |
| Map Data | `assets/data/maps/{map_id}.json` | 맵별 1파일: 차원, 타일 배열, 지형 | Map/Grid GDD |
| Unit Role Config | `assets/data/config/unit_roles.json` | 병종 정의, 지형 통과 테이블 | Unit Role GDD |
| Growth Config | `assets/data/config/growth.json` | 레벨캡, XP 곡선, 성장 계수 | Character Growth GDD |
| Balance Constants | `assets/data/config/balance_constants.json` | 크로스 시스템 상수 전체 | Balance/Data (이 시스템) |
| Skill Definitions | `assets/data/skills/*.json` | 스킬 효과, 코스트, 범위 | Skill/Ability GDD (별도 작성) |
| Equipment Tables | `assets/data/config/equipment.json` | 아이템 스탯, 슬롯 규칙 | Equipment/Item GDD |
| Scenario Config | `assets/data/scenarios/{scenario_id}.json` | 챕터 데이터, 승리/패배 조건 | Scenario Progression GDD |
| Formation Config | `assets/data/config/formations.json` | 진형 보너스 정의, 인접 조건 | Formation Bonus GDD |

**CR-3. JSON 봉투 형식**

모든 데이터 파일은 공통 봉투(envelope) 형식을 따른다:

```json
{
  "schema_version": "1.0",
  "category": "<category_name>",
  "data": { ... }
}
```

| Field | Type | Description |
|-------|------|-------------|
| `schema_version` | string | Semver. 로더가 MINIMUM_SCHEMA_VERSION 미만 파일 거부 |
| `category` | string | CR-2의 등록된 카테고리와 일치 필수 |
| `data` | object/array | 카테고리별 페이로드 — 스키마는 소유 GDD가 정의 |

봉투 불일치 시 파일명과 실패 필드를 명시하며 거부한다.

**CR-4. 로딩 파이프라인 (4단계)**

게임 시작 시 순차 실행. 4단계 완료 전 어떤 소비 시스템도 데이터에 접근 불가.

| Phase | Name | Action | 실패 시 |
|-------|------|--------|--------|
| 1 | Discovery | 등록된 데이터 디렉토리 스캔, 파일 경로 수집 | FATAL: 필수 디렉토리 누락 |
| 2 | Parse | 각 파일의 JSON 봉투 파싱, schema_version/category 검증 | FATAL: JSON 문법 오류 또는 봉투 불일치 |
| 3 | Validate | 카테고리별 검증 규칙 실행 (범위, 타입, 교차 참조) | 심각도별: FATAL/ERROR/WARNING/INFO |
| 4 | Build | 인메모리 조회 딕셔너리 구축, 시스템 READY 마킹 | FATAL: 필수 카테고리에 유효 레코드 0개 |

로딩 화면이 이 파이프라인을 커버한다. 전체 파이프라인은 첫 게임 프레임 렌더 전에 완료.

**CR-5. 검증 심각도 등급**

| Level | Label | Behavior |
|-------|-------|----------|
| 0 | INFO | 로그만. 로딩 영향 없음 |
| 1 | WARNING | 로그. 레코드 정상 로딩. 예: 고아 hero_b_id |
| 2 | ERROR | 해당 레코드 거부. 다른 레코드는 계속. 예: 스킬 배열 길이 불일치 |
| 3 | FATAL | 전체 파이프라인 중단. 게임 시작 불가. 예: 중복 hero_id, 필수 파일 누락 |

검증 규칙의 소유권은 각 콘텐츠 GDD에 있다. Balance/Data는 검증 프레임워크(등록/실행
방법)를 제공하고, Hero Database의 EC-1~EC-10 같은 구체적 규칙은 소유 GDD가 정의.

디버그/에디터 빌드: 전체 검증 (범위, 밸런스 규칙, SPI 체크 포함).
릴리즈 빌드: 타입/null 체크만. 밸런스 규칙 검증 생략.

**CR-6. 소비자 접근 패턴**

단일 DataRegistry 싱글턴을 통해 3가지 접근 패턴 제공:

| Pattern | Description | Example |
|---------|-------------|---------|
| Direct lookup | ID로 특정 레코드 요청 | `DataRegistry.get_hero("shu_001_liu_bei")` |
| Filtered query | 조건부 레코드 집합 요청 | `DataRegistry.get_heroes_by_faction(Faction.SHU)` |
| Constant access | 이름으로 밸런스 상수 요청 | `DataRegistry.get_const("terrain_cost_plains")` |

모든 반환 데이터는 읽기 전용. 레지스트리는 가변 참조를 노출하지 않는다.
반환값은 typed container 클래스 (raw Dictionary 사용 금지).
런타임 상태 추적(현재 HP, 장착 장비 등)은 Hero DB에서 확립한 "base + modifier" 패턴으로
각 소비 시스템이 자체 관리.

**CR-7. Balance Constants 파일**

Balance/Data가 소유하는 유일한 콘텐츠 파일. 2개 이상의 GDD에서 참조되는 모든
크로스 시스템 상수의 권위 출처.

| Key | Value | Unit | Original Source |
|-----|-------|------|-----------------|
| `terrain_cost_plains` | 10 | cost_units | Map/Grid |
| `terrain_cost_hills` | 15 | cost_units | Map/Grid |
| `terrain_cost_mountain` | 20 | cost_units | Map/Grid |
| `terrain_cost_forest` | 15 | cost_units | Map/Grid |
| `terrain_cost_road` | 7 | cost_units | Map/Grid |
| `map_cols_min` | 15 | tiles | Map/Grid |
| `map_cols_max` | 40 | tiles | Map/Grid |
| `map_rows_min` | 15 | tiles | Map/Grid |
| `map_rows_max` | 30 | tiles | Map/Grid |
| `stat_total_min` | 180 | stat_points | Hero DB |
| `stat_total_max` | 280 | stat_points | Hero DB |
| `stat_hard_cap` | 100 | stat_points | Hero DB |
| `move_range_min` | 2 | tiles | Hero DB |
| `move_range_max` | 6 | tiles | Hero DB |
| `l_cap` | 30 | levels | Hero DB (provisional) |
| `spi_warning_threshold` | 0.5 | dimensionless | Hero DB |

상수가 두 GDD에 다른 값으로 존재하면 안 된다. 이 파일이 단일 진실 출처.

**CR-8. 스키마 버전 관리**

각 데이터 파일의 `schema_version` 필드로 호환성 관리:
- 로더는 MINIMUM_SCHEMA_VERSION 미만 파일을 거부 (명시적 에러)
- Save/Load 시스템은 세이브 시점의 schema_version을 기록하여 호환성 감지
- 런타임 마이그레이션은 MVP에서 미지원 — 비호환 시 로딩 거부만
- 마이그레이션 스크립트는 오프라인 도구로 별도 관리 (post-MVP)

**CR-9. Hot Reload (개발 모드 전용)**

개발 중 게임 재시작 없이 데이터 파일을 다시 로드할 수 있다.
- 수동 트리거 (자동 감지 아님)
- 전체 파이프라인(Phase 1-4) 재실행 후 인메모리 레지스트리 교체
- 릴리즈 빌드에서는 비활성화

**CR-10. 하드코딩 금지 강제**

balance_constants.json 또는 카테고리별 설정 파일에 존재하는 값은 GDScript 코드에
리터럴 상수로 존재해서는 안 된다. 실용적 테스트: 밸런스 디자이너가 수치를
변경할 때 .gd 파일이 아닌 데이터 파일만 수정하면 된다.

### States and Transitions

| State | Description | Entry | Exit |
|-------|-------------|-------|------|
| `UNINITIALIZED` | 데이터 미로딩. 레지스트리 비어있음 | 게임 시작 | `initialize()` 호출 |
| `DISCOVERING` | 데이터 디렉토리 스캔 중 | `initialize()` 호출 | 모든 디렉토리 스캔 완료 |
| `PARSING` | JSON 파싱 중 | Discovery 완료 | 모든 파일 파싱 완료 |
| `VALIDATING` | 카테고리별 검증 실행 중 | Parsing 완료 | 모든 검증기 실행 완료 |
| `READY` | 레지스트리 구축 완료. 소비자 쿼리 가능 | 검증 완료 (FATAL 0건) | Hot reload 또는 게임 종료 |
| `HOT_RELOADING` | 파일 재로딩 중 (개발 전용) | 개발자가 reload 트리거 | 파이프라인 완료 → READY 복귀 |
| `ERROR` | FATAL 오류. 게임 진행 불가 | Phase 1-3 중 FATAL 오류 | 복구 불가 — 파일 수정 후 재시작 |

전이:
```
UNINITIALIZED → DISCOVERING → PARSING → VALIDATING → READY
                                                      ↕ (dev only)
                                               HOT_RELOADING
어느 단계에서든 FATAL → ERROR (terminal)
```

DataRegistry가 `READY` 상태가 아닌 한 어떤 게임 시스템도 자체 초기화를 진행할 수 없다.

### Interactions with Other Systems

| Consuming System | 읽는 데이터 | 접근 패턴 | 데이터 누락 시 |
|-----------------|-----------|---------|-------------|
| Hero Database | `heroes/*.json` | 초기화 시 일괄 로드 | FATAL: 영웅 없음 = 게임 시작 불가 |
| Map/Grid | `maps/{map_id}.json` | 전투별 단일 로드 | FATAL: 맵 파일 누락 시 전투 로드 중단 |
| Unit Role | `config/unit_roles.json` | 초기화 시 단일 로드 | FATAL: 병종 정의 없음 = 유닛 행동 미정의 |
| Damage/Combat Calc | `balance_constants.json` | 계산 시 상수 접근 | FATAL: 계수 누락 = 0으로 나누기 위험 |
| Character Growth | `config/growth.json` | 초기화 시 단일 로드 | FATAL: 성장 설정 없음 = 레벨업 미정의 |
| Skill/Ability | `skills/*.json` | 초기화 시 일괄 로드 | FATAL: 스킬 정의 없음 = 전투 스킬 미작동 |
| Equipment/Item | `config/equipment.json` | 초기화 시 단일 로드 | WARNING: Alpha 기능; MVP에서 비필수 |
| Scenario Progression | `scenarios/{id}.json` | 시나리오별 로드 | FATAL: 시나리오 누락 = 챕터 시작 불가 |
| Formation Bonus | `config/formations.json` | 초기화 시 단일 로드 | FATAL: 진형 정의 없음 = 진형 보너스 미작동 |
| Save/Load | `balance_constants.json` | 세이브 로드 시 버전 체크 | WARNING: 버전 불일치 알림 (MVP에서 비차단) |
| Localization | 모든 데이터 파일의 문자열 키 | 통과 참조 | WARNING: 누락 로케일 → 한국어 기본값 |

**초기화 순서**: Balance/Data (READY) → Hero Database → 나머지 모든 시스템.
모든 화살표는 DataRegistry에서 바깥으로 향한다. 소비자는 레지스트리에 쓰기 불가.

## Formulas

### F-1. Schema Version Compatibility Check

```
COMPATIBLE = (file_major == loader_major) AND (file_minor >= loader_minimum_minor)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| File major version | file_major | int | 1–99 | 파일의 `schema_version`에서 추출 (예: `"2.1"` → 2) |
| File minor version | file_minor | int | 0–99 | 파일의 `schema_version`에서 추출 (예: `"2.1"` → 1) |
| Loader major version | loader_major | int | 1–99 | 현재 로더가 지원하는 major version |
| Loader minimum minor | loader_minimum_minor | int | 0–99 | 로더가 수용하는 최소 minor version |
| Result | COMPATIBLE | bool | {true, false} | Phase 3(Validate) 진행 가능 여부 |

**Output Range:** Boolean. `false` → severity 3 FATAL, 해당 파일 파이프라인 중단.
Major 불일치는 항상 치명적 (breaking schema change). Minor 미달은 로더가 기대하는
필드가 파일에 없음을 의미하므로 역시 치명적.

**Example:**
Loader: `loader_major=1`, `loader_minimum_minor=0`
- File `"1.0"` → 1==1 AND 0>=0 → **COMPATIBLE** ✓
- File `"1.3"` → 1==1 AND 3>=0 → **COMPATIBLE** ✓ (newer minor, additive fields)
- File `"2.0"` → 2≠1 → **INCOMPATIBLE** ✗ FATAL
- File `"0.9"` → 0≠1 → **INCOMPATIBLE** ✗ FATAL

---

### F-2. Validation Coverage Rate (VCR)

```
VCR = records_passed / records_total
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Passed records | records_passed | int | 0–N | Phase 3 완료 시 severity-2/3 위반 없는 레코드 수 |
| Total records | records_total | int | 1–N | Phase 1에서 발견된 전체 레코드 수 |
| Coverage rate | VCR | float | 0.0–1.0 | 유효 레코드 비율 |

**Output Range:** 0.0–1.0. `records_total=0`이면 미정의 — 이 조건 자체가
Phase 4 FATAL("필수 카테고리에 유효 레코드 0개")이므로 실제로 0 나누기 불발생.

Severity-0(INFO)과 severity-1(WARNING)은 VCR에 영향 없음 — severity-2(ERROR)
이상만 `records_passed`에서 제외. "플레이 가능한 콘텐츠 비율"을 측정하는 지표.

**Example:**
Hero 디렉토리: 12레코드 발견. 10개 정상, 1개 WARNING(고아 hero_b_id — 로딩됨),
1개 ERROR(스킬 배열 불일치 — 거부).
- records_passed = 11 (정상 10 + WARNING 1)
- records_total = 12
- VCR = 11/12 ≈ **0.917**

CI 게이트 목표: 출시 시 `heroes` 카테고리 VCR ≥ 1.0 (거부 레코드 0개).

---

**Note:** 로딩 시간/메모리 예측은 하드웨어 종속적이므로 공식이 아닌 Acceptance
Criteria의 성능 제약으로 명시한다 (AC 섹션 참조).

## Edge Cases

**EC-1. 필수 디렉토리 누락**
- **If Phase 1에서 등록된 데이터 디렉토리가 디스크에 존재하지 않음**: severity 3 FATAL, 파이프라인 중단. 누락 경로를 에러 메시지에 명시. 전체 카테고리 부재는 READY 도달 불가.

**EC-2. 빈 파일 (0바이트)**
- **If 파일이 발견되었으나 0바이트**: severity 3 FATAL, 파일명 명시. 0바이트 파일은 유효한 JSON 봉투를 생성할 수 없다. 건너뛰기 금지 — 카테고리 누락의 무음 발생 방지.

**EC-3. 비UTF-8 인코딩**
- **If 파일 바이트가 유효한 UTF-8이 아님**: Phase 2에서 severity 3 FATAL, 파일명 보고. GDScript `JSON.parse()`는 String 입력 필수 — 비UTF-8 바이트는 파싱 전 null 문자열 발생.

**EC-4. 유효 JSON이지만 봉투 불일치**
- **If JSON 파싱 성공이나 최상위 객체에 `schema_version`, `category`, `data` 중 하나 누락**: 해당 파일 severity 3 FATAL. 봉투 계약은 불가침 — 프로토콜 위반 파일은 카테고리 라우팅 불가.

**EC-5. schema_version 필드 자체 부재**
- **If 봉투에 `schema_version` 키가 없음**: `"0.0"`으로 취급. F-1에서 `file_major=0 ≠ loader_major=1` → COMPATIBLE=false → severity 3 FATAL. 누락 버전은 절대 묵인하지 않음.

**EC-6. 비Semver 버전 문자열 (예: `"v1"`, `""`, `"release"`)**
- **If `schema_version`을 `"."`로 분할하여 정수 2개를 추출할 수 없음**: severity 3 FATAL, 필드 값을 에러 메시지에 인용. 추측 파싱 시도 금지 — 형식 불량 문자열은 즉시 거부.

**EC-7. 필수 카테고리의 모든 레코드가 severity 2로 실패**
- **If Phase 3에서 필수 카테고리의 모든 레코드가 거부됨 (예: 전체 hero 파일이 stat_total 검증 실패)**: Phase 4에서 severity 3 FATAL ("0 valid records in required category: heroes"). 빈 필수 카테고리로는 READY 진입 불가.

**EC-8. 한 파일 내 혼합 심각도**
- **If 파일의 `data` 배열에 severity 0/1 레코드와 severity 2 레코드가 혼재**: severity-2 레코드만 개별 거부, severity-0/1 레코드는 정상 로딩. VCR(F-2)은 수용된 레코드만 반영. CR-5의 분리 처리 설계 의도.

**EC-9. 순환 교차 참조**
- **If 레코드 A가 레코드 B를 참조하고 레코드 B가 레코드 A를 참조 (예: 두 스킬이 상호 선행 조건)**: 양쪽 모두 severity 2 ERROR, "circular cross-reference detected between [id-A] and [id-B]". 양쪽 모두 로딩 거부. 참조 필드가 있는 레코드는 수용 전 DFS 사이클 체크 실행.

**EC-10. READY 이전 DataRegistry 쿼리**
- **If 소비 시스템이 `UNINITIALIZED`, `PARSING`, `VALIDATING`, `HOT_RELOADING` 상태에서 쿼리 호출**: 즉시 `null` 반환 + severity 0 INFO 로그 (호출자 스택 트레이스 포함). 크래시하지 않음. 초기화 순서 계약(CR-4)에 의해 READY 전 non-null 반환은 소비자 버그.

**EC-11. 전투 중 Hot Reload 트리거**
- **If 게임 상태가 `IN_BATTLE`일 때 hot reload 트리거**: reload를 큐에 넣되 전투 종료까지 실행하지 않음. 전투 중 레지스트리는 READY 유지. 강제 즉시 reload 시 `HOT_RELOADING` 전이; 이 창에서의 `get_*` 호출은 `null` 반환(EC-10과 동일) + severity 1 WARNING.

**EC-12. 단일 JSON 객체 내 중복 키**
- **If `data` 내 JSON 객체에 같은 키가 2번 등장 (예: `hero_id` 중복)**: GDScript `JSON.parse()`는 마지막 값만 유지 (무음 덮어쓰기). 무음 데이터 손상 방지를 위해 Phase 2에서 파싱된 딕셔너리의 키 수와 원시 문자열의 키 출현 횟수를 비교. 불일치 시 severity 3 FATAL, 중복 키를 메시지에 명시.

**EC-13. Balance Constants 타입 불일치**
- **If `balance_constants.json`의 키가 기대 타입과 다름 (예: `"stat_hard_cap": "100"` — int 기대, string 저장)**: Phase 3 검증 시 severity 2 ERROR. `DataRegistry.get_const()` 해당 키에 `null` 반환. 쿼리 시점이 아닌 로드 시점에 검출. `null`을 받은 소비자는 기본값으로 진행하지 않고 자체 severity 2 ERROR 로그.

## Dependencies

### 상위 의존성 (이 시스템이 의존하는 것)

없음 — Foundation 레이어. 파일 시스템 접근(Godot FileAccess)과 JSON 파서
(Godot JSON 클래스) 외에 외부 게임 시스템 없이 독립 작동한다.

### 하위 의존성 (이 시스템에 의존하는 것)

| System | 의존 유형 | 사용하는 패턴 | 데이터 인터페이스 |
|--------|----------|-------------|-----------------|
| Hero Database | Hard | 초기화 시 일괄 로드 | `heroes/*.json` 전체, `balance_constants.json` |
| Map/Grid | Hard | 전투별 단일 로드 | `maps/{map_id}.json` |
| Unit Role System | Hard | 초기화 시 단일 로드 | `config/unit_roles.json` |
| Damage/Combat Calc | Hard | 계산 시 상수 접근 | `balance_constants.json` |
| Character Growth | Hard | 초기화 시 단일 로드 | `config/growth.json` |
| Skill/Ability System | Hard | 초기화 시 일괄 로드 | `skills/*.json` |
| Formation Bonus | Hard | 초기화 시 단일 로드 | `config/formations.json` |
| Scenario Progression | Hard | 시나리오별 로드 | `scenarios/{scenario_id}.json` |
| Equipment/Item | Soft | 초기화 시 단일 로드 | `config/equipment.json` (Alpha — MVP 비필수) |
| Save/Load | Soft | 세이브 로드 시 버전 체크 | `balance_constants.json` schema_version |
| Localization | Soft | 문자열 키 통과 참조 | 모든 데이터 파일의 표시 문자열 |

Hard = 이 시스템 없이 작동 불가. Soft = 없어도 기능하지만 정보가 축소됨.

### 크로스 시스템 계약

이 GDD에서 결정된 규칙으로, 다른 GDD가 반드시 따라야 한다:

- **JSON 봉투 형식**: 모든 데이터 파일은 CR-3의 `{schema_version, category, data}` 봉투를 따라야 한다. 봉투 없는 데이터 파일은 파이프라인에서 거부.
- **초기화 순서**: Balance/Data(READY) → Hero Database → 나머지 모든 시스템. 이 순서를 어기면 EC-10(null 반환) 발생.
- **읽기 전용 계약**: Hero DB에서 확립한 "base + modifier" 패턴을 전체 파이프라인으로 확장. 소비 시스템은 DataRegistry의 데이터를 수정하지 않는다.
- **Balance Constants 단일 출처**: 2개 이상의 GDD에서 참조하는 수치 상수는 `balance_constants.json`에만 존재해야 한다. 각 GDD는 이 파일의 값을 참조하되 자체 복사본을 만들지 않는다.
- **검증 규칙 소유권**: 각 카테고리의 검증 규칙은 해당 콘텐츠 GDD가 정의. Balance/Data는 프레임워크만 제공.

## Tuning Knobs

| Knob | 현재 값 | 안전 범위 | 너무 높으면 | 너무 낮으면 | 영향 |
|------|---------|----------|-----------|-----------|------|
| `MINIMUM_SCHEMA_VERSION` | "1.0" | — | 기존 데이터 파일 대량 거부 | 오래된 스키마 허용 — 누락 필드 위험 | 파일 호환성 게이트 |
| `PIPELINE_TIMEOUT_MS` | 5000 | 2000–10000 | 느린 디바이스에서 불필요한 여유 | 모바일에서 정상 로딩이 timeout 실패 | 로딩 파이프라인 제한 시간 |
| `MAX_VALIDATION_ERRORS` | 100 | 50–500 | 에러 로그가 거대해져 디버깅 어려움 | 초기 오류만 보고하고 나머지 누락 | 로그 출력 상한 |
| `HOT_RELOAD_ENABLED` | true (dev) / false (release) | — | 릴리즈에서 활성화 시 보안/성능 위험 | 개발 중 비활성화 시 반복 작업 증가 | 데이터 핫 리로드 토글 |
| `REQUIRED_CATEGORIES` | heroes, maps, unit_roles, growth, balance_constants, skills, scenarios, formations | — | 비필수 카테고리를 필수로 만들면 MVP 블록 | 필수에서 빠지면 빈 카테고리로 시작 가능 — 런타임 null 위험 | 어떤 카테고리 누락이 FATAL인지 |
| `DEBUG_VALIDATION_LEVEL` | full | full / basic | — | basic = 타입 체크만, 밸런스 규칙 검증 건너뜀 → 설계 문제 조기 발견 실패 | 디버그 빌드 검증 깊이 |
| `RELEASE_VALIDATION_LEVEL` | basic | full / basic / none | full = 릴리즈 시작 느려짐 | none = 손상 데이터 무방비 | 릴리즈 빌드 검증 깊이 |
| `VCR_CI_THRESHOLD` | 1.0 | 0.9–1.0 | — | 1.0 미만 허용 시 거부 레코드와 함께 출시 위험 | CI 파이프라인의 검증 커버리지 게이트 |

### 상호작용 주의

- `REQUIRED_CATEGORIES` 변경 시 Equipment/Item이 MVP에서 빠져있는지 확인 — Alpha 전까지 required에 넣지 않아야 함
- `PIPELINE_TIMEOUT_MS`는 모바일 최소 사양(512MB 기기)에서 실측 필요 — 추정이 아닌 프로파일링 기반 설정
- `MINIMUM_SCHEMA_VERSION` 변경은 기존 세이브 파일의 호환성에 영향 — Save/Load GDD와 연동 필수

## Visual/Audio Requirements

Foundation 시스템 — 직접적 시각/음향 요구사항 없음.
로딩 화면 진행률 표시는 Main Menu / Scenario Select UI GDD에서 정의.

## UI Requirements

Foundation 시스템 — 직접적 UI 없음.
데이터 파일의 표시 문자열(무장 이름, 지형 이름 등)은 각 콘텐츠 시스템의 UI GDD에서 소비.
개발 모드의 검증 오류 오버레이는 디버그 도구이며 GDD 범위 밖.

## Acceptance Criteria

### Core Rules

**AC-01. READY 이전 소비자 접근 차단**
- **GIVEN** DataRegistry가 VALIDATING 상태, **WHEN** Hero Database가 `DataRegistry.get_hero("shu_001_liu_bei")` 호출, **THEN** `null` 반환, 호출자 스택 트레이스 포함 INFO 로그, 크래시 없음

**AC-02. 9개 카테고리 전체 스캔**
- **GIVEN** 신규 게임 빌드, **WHEN** Phase 1 (Discovery) 완료, **THEN** 등록된 9개 파일 패턴 모두 스캔되고 각 카테고리 파일 수가 discovery 로그에 출력 (0개 카테고리도 로그, 무음 건너뛰기 금지)

**AC-03. JSON 봉투 필수 필드 누락 시 FATAL**
- **GIVEN** 유효 JSON이지만 `category` 필드 누락 데이터 파일, **WHEN** Phase 2 처리 시, **THEN** severity 3 FATAL로 거부, 에러 메시지에 파일명과 누락 필드 명시

**AC-04. Phase 4 완료 전 소비자 초기화 차단**
- **GIVEN** 모든 데이터 파일 존재하는 게임 시작, **WHEN** Phase 4 (Build) FATAL 없이 완료, **THEN** READY 전이 후에만 Hero Database가 자체 초기화 진행

**AC-05. ERROR = 해당 레코드만 거부, 파이프라인 계속**
- **GIVEN** 5개 레코드 중 1개가 스킬 배열 길이 불일치인 hero 파일, **WHEN** Phase 3 실행, **THEN** 정확히 1개 레코드만 severity 2 ERROR 거부, 나머지 4개 정상 로딩, READY 도달

**AC-06. 3가지 접근 패턴 모두 typed container 반환**
- **GIVEN** READY 상태, **WHEN** `get_hero()`, `get_heroes_by_faction()`, `get_const()` 순차 호출, **THEN** 각각 typed container 반환 (raw Dictionary 아님), 내부 레지스트리에 대한 가변 참조 미노출

**AC-07. Balance Constants 16개 키 전체 접근 가능**
- **GIVEN** READY 상태, **WHEN** CR-7의 16개 키 (`terrain_cost_plains` ~ `spi_warning_threshold`) 각각에 `get_const()` 호출, **THEN** 16개 모두 기대 수치값 반환, `null` 반환 0건

**AC-08. schema_version 미달 파일 거부**
- **GIVEN** `MINIMUM_SCHEMA_VERSION="1.0"`, 데이터 파일 `schema_version: "0.9"`, **WHEN** Phase 2 처리, **THEN** severity 3 FATAL 거부, 에러에 파일 버전과 최소 요구 버전 명시

**AC-09. 릴리즈 빌드에서 Hot Reload 비활성**
- **GIVEN** 릴리즈 빌드, **WHEN** hot reload 트리거 호출, **THEN** 무시, READY 상태 유지, HOT_RELOADING 전이 없음

**AC-10. 하드코딩 금지 검증**
- **GIVEN** `terrain_cost_plains: 10`으로 READY 상태, **WHEN** 디자이너가 JSON에서 `12`로 변경 후 재시작(또는 dev hot-reload), **THEN** `get_const("terrain_cost_plains")`가 `12` 반환, .gd 파일 수정 없음

### Formulas

**AC-F1. F-1 Schema Compatibility — 4개 케이스 정확성**
- **GIVEN** `loader_major=1, loader_minimum_minor=0`, **WHEN** `"1.0"`, `"1.3"`, `"2.0"`, `"0.9"` 파일 처리, **THEN** `"1.0"`, `"1.3"` = COMPATIBLE, `"2.0"`, `"0.9"` = severity 3 FATAL

**AC-F2. F-2 VCR — CI 게이트 판정**
- **GIVEN** hero 12레코드 중 1개 ERROR, 1개 WARNING, **WHEN** Phase 3 완료, **THEN** VCR = 11/12 ≈ 0.917 로그 출력, VCR_CI_THRESHOLD(1.0) 미달로 CI 실패

### Edge Cases

**AC-EC1. 빈 파일 → FATAL + 파일명 명시**
- **GIVEN** `assets/data/heroes/`에 0바이트 파일 존재, **WHEN** Phase 2 파싱, **THEN** severity 3 FATAL, 에러에 정확한 파일 경로 포함, 파이프라인 중단 (무음 건너뛰기 금지)

**AC-EC9. 순환 참조 → 양쪽 모두 거부**
- **GIVEN** 스킬 A→B 선행조건, 스킬 B→A 선행조건, **WHEN** Phase 3 DFS 사이클 감지 실행, **THEN** 양쪽 모두 severity 2 ERROR 거부, 메시지에 양쪽 ID 명시

### 성능

**AC-PERF. 최소 사양 모바일에서 파이프라인 완료**
- **GIVEN** 프로덕션 데이터 세트, 512MB 모바일 기기 (최소 사양), **WHEN** `initialize()` 호출, **THEN** READY 도달까지 5000ms(PIPELINE_TIMEOUT_MS) 이내

## Open Questions

1. **Skill/Ability GDD 작성 시점** — Hero DB Open Question #2를 이 GDD에서 "별도
   Skill/Ability GDD" 방향으로 해소했다. 해당 GDD를 systems-index에 추가하고 설계
   순서를 결정해야 한다.
   Owner: systems-designer | Target: Unit Role GDD 설계 전

2. **맵 데이터 포맷 상세** — Map/Grid Open Question #2와 연결. JSON 봉투 형식은
   확정했으나, 타일 배열의 구체적 직렬화 형식(flat array vs nested rows)은 미결정.
   Architecture Decision(ADR)에서 확정.
   Owner: Architecture (ADR) | Target: 프로토타입 전

3. **런타임 마이그레이션 전략** — MVP에서는 schema_version 미달 파일을 거부만 한다.
   Post-MVP에서 세이브 파일 호환성을 위한 마이그레이션 스크립트 필요 여부와 형태.
   Owner: Save/Load GDD | Target: Vertical Slice

4. **balance_constants.json 확장** — 현재 16개 상수. Unit Role, Damage Calc,
   Formation Bonus GDD 작성 시 추가 상수가 등록될 예정. 상수 수가 100개를 넘으면
   카테고리별 분리 검토 필요.
   Owner: Balance/Data (이 시스템) | Target: Alpha

   > **Partially resolved 2026-04-18** — `design/gdd/damage-calc.md` v1.0
   > Phase 5 added 2 new constants (`CHARGE_BONUS=1.20`, `AMBUSH_BONUS=1.15`)
   > and transferred ownership of 3 existing constants (`BASE_CEILING=83` — pass-11a:
   > was 100 pre-rev-2.4 2026-04-19; `DAMAGE_CEILING=180` — pass-11a: was 150 pre-rev-2
   > 2026-04-18; `COUNTER_ATTACK_MODIFIER=0.5`) from grid-battle.md to damage-calc.md
   > to damage-calc.md in `design/registry/entities.yaml` v2. All 5 live in
   > `balance_constants.json` (NOT hardcoded — AC-DC-48 enforces via grep).
   > Unit Role + Formation Bonus constants still pending their respective
   > GDDs. Current registered combat constants: 9 damage-pipeline + 13
   > prior + new additions. 100-constant threshold not yet approached.

5. **외부 밸런스 도구** — 스프레드시트 → JSON 자동 변환 파이프라인 필요 여부.
   80-100명 무장 밸런싱 시 수작업 JSON 편집은 비현실적. 도구 투자 시점 결정.
   Owner: tools-programmer | Target: Alpha
