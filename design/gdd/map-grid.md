# Map/Grid System (맵/그리드 시스템)

> **Status**: Designed
> **CD-GDD-ALIGN**: Skipped — Lean mode
> **Author**: User + Claude Code agents
> **Last Updated**: 2026-04-16
> **Implements Pillar**: Pillar 1 — 형세의 전술 (Tactics of Formation)

## Overview

맵/그리드 시스템은 천명역전의 모든 전투가 펼쳐지는 2D 그리드 공간을 정의하고
관리하는 Foundation 시스템이다. 정방형(square) 타일로 구성된 전투 맵의 데이터
구조를 소유하며, 각 타일의 좌표, 지형 타입, 높이(고도), 점유 상태, 이동 가능
여부를 관리한다. 지형 효과, 진형 보너스, 데미지 계산, AI 등 9개 시스템이 이
시스템의 그리드 데이터를 기반으로 작동하며, 맵/그리드 없이는 전투 자체가
불가능하다. 플레이어는 이 시스템을 직접 인지하지 않지만, "언덕 위의 궁병",
"다리목을 막는 보병", "측면으로 우회하는 기병" — Pillar 1(형세의 전술)의 모든
순간이 이 그리드 위에서 발생한다.

## Player Fantasy

플레이어는 그리드를 인식하지 않는다. 플레이어가 느끼는 것은 전장에 깊이가
있다는 감각이다. 다리목은 한 칸의 타일이 아니라, 창병 3명이 난공불락의 벽이
되는 병목이다. 언덕은 보너스 수치가 아니라, 하급 궁병이 상급 검병을 압도하는
이유다. 그리드는 포지셔닝을 읽을 수 있게 만든다 — 전장을 한눈에 훑으면 진형,
위협, 기회가 보이는 것, 바둑 기사가 돌의 형세를 읽듯이. 모든 위치에 전술적
의미가 있을 때, 모든 무장은 자신이 빛나는 자리를 찾는다.

*이 시스템은 Pillar 1(형세의 전술 — 포지셔닝이 전투의 언어)과 Pillar 3(모든
무장에게 자리가 있다 — 올바른 위치가 어떤 무장이든 가치 있게 만든다)을 지탱한다.*

## Detailed Design

### Core Rules

**CR-1. 좌표 체계**

모든 타일은 `(col, row)` 정수 좌표로 표현한다. 원점 `(0, 0)` = 좌상단.
col은 오른쪽, row는 아래쪽으로 증가한다.

| Dimension | Min | Max | Note |
|-----------|-----|-----|------|
| col | 0 | map_cols - 1 | 0-indexed |
| row | 0 | map_rows - 1 | 0-indexed |
| map_cols | 15 | 40 | |
| map_rows | 15 | 30 | |

- 거리: Manhattan Distance = `|c2-c1| + |r2-r1|`
- 대각선 이동 없음 — 4방향(상/하/좌/우)만 허용

**CR-2. 타일 데이터 구조**

저장 방식: Flat Array, 인덱스 `row * map_cols + col` (O(1) 접근).

| Field | Type | Range | Description |
|-------|------|-------|-------------|
| `coord` | Vector2i | (0,0)~(max) | 그리드 좌표 |
| `terrain_type` | enum | CR-3 참조 | 지형 분류 |
| `elevation` | int | 0, 1, 2 | 0=평지, 1=구릉, 2=산지 |
| `tile_state` | enum | ST-1 참조 | 점유/접근 상태 |
| `occupant_id` | int | -1 or unit ID | -1=비어있음 |
| `occupant_faction` | enum | NONE / ALLY / ENEMY | tile_state와 동기화 |
| `is_passable_base` | bool | — | 지형 기본 통과 가능 여부 |
| `is_destructible` | bool | — | 파괴 가능 여부 |
| `destruction_hp` | int | 0–999 | is_destructible 시만 유효 |

**CR-3. 지형 타입**

| terrain_type | 한글 | elevation 허용 | 기본 passable | 이동 코스트 | 비고 |
|---|---|---|---|---|---|
| PLAINS | 평지 | 0 | true | 10 | 기준값 |
| HILLS | 구릉 | 1 | true | 15 | |
| MOUNTAIN | 산지 | 2 | true | 20 | 특정 병종 통과 불가 |
| FOREST | 숲 | 0–1 | true | 15 | |
| RIVER | 강 | 0 | false | — | 기본 통과 불가 |
| BRIDGE | 다리 | 0 | true | 10 | 폭 1칸, 병목 |
| FORTRESS_WALL | 성벽 | 1–2 | false | — | is_destructible 가능 |
| ROAD | 도로 | 0 | true | 7 | 이동 코스트 감소 |

이동 코스트는 정수 전용. 모든 코스트 비교는 정수 연산으로 처리한다.
전투 보너스/패널티 수치는 Terrain Effect System 소관이며, 이 표의 값은
패스파인딩 전용 상대 비용이다.

**CR-4. 고도 규칙**

1. 타일의 `elevation`은 terrain_type에 따라 허용 범위가 고정된다 (CR-3 참조).
2. 맵 로딩 시 elevation + terrain_type 조합 유효성을 검증한다. 불일치 시 로딩 오류.
3. 고도 차이: `delta_elevation = target.elevation - source.elevation`
   - 양수: 오르막 (공격자 낮음 → 불리)
   - 음수: 내리막 (공격자 높음 → 유리)
4. 전투 수치 적용은 Terrain Effect System 소관. Grid는 `delta_elevation`만 제공.

**CR-5. Facing / Direction (4방향)**

| facing | 값 | 설명 |
|---|---|---|
| NORTH | 0 | 위 (row 감소 방향) |
| EAST | 1 | 오른쪽 |
| SOUTH | 2 | 아래 |
| WEST | 3 | 왼쪽 |

공격 방향 판정:
```
attack_dir = direction FROM attacker TO defender
relative_angle = (attack_dir - defender.facing + 4) % 4
```

| relative_angle | 판정 |
|---|---|
| 0 | 정면 공격 (FRONT) |
| 2 | 후방 공격 (REAR) |
| 1, 3 | 측면 공격 (FLANK) |

- 이동 완료 시 facing = 마지막 이동 방향으로 자동 갱신
- 이동 없이 공격만 할 경우 facing = 공격 대상 방향으로 갱신

**CR-6. 경로 탐색 (Movement Range)**

알고리즘: 커스텀 Dijkstra. Godot 내장 AStarGrid2D는 미사용 — 병종별
이동 코스트 차이를 지원하려면 커스텀 구현이 더 적합하다.

1. 출발 타일을 cost=0으로 open set에 추가
2. 인접 4방향 타일을 확인:
   - `tile_state == IMPASSABLE` → 건너뜀
   - `tile_state == ENEMY_OCCUPIED` → 건너뜀 (통과 불가, 착지 불가)
   - `tile_state == ALLY_OCCUPIED` → 통과 가능, 착지 불가
   - `is_passable_base == false` → 건너뜀
   - 병종별 지형 통과 제한: `can_traverse(unit_type, terrain_type)` 확인
3. 이동 코스트: `move_cost = terrain_cost(terrain_type)` (CR-3 정수값)
4. 이동 가능 조건: `accumulated_cost <= unit.move_range × 10`
   (unit.move_range는 타일 수 기준, ×10으로 코스트 스케일 맞춤)
5. 결과: `Array[Vector2i]` (이동 가능 타일), `Dictionary[Vector2i, int]` (최소 코스트)

계산 시점: 유닛 선택 시 온디맨드 계산 + 캐시. 그리드 변경(유닛 이동, 타일
상태 변화) 시 캐시 무효화.

**CR-7. 시야 (Line of Sight)**

공격 범위는 2단계로 결정한다.

**1단계 — Manhattan 거리 필터**: `dist(attacker, target) <= attack_range`

**2단계 — LoS 검사** (원거리 유닛에만 적용, 근접 공격은 LoS 생략):

Bresenham's line algorithm으로 attacker → target 직선 경로의 중간 타일 열거.
차단 조건 (하나라도 해당 시 LoS 차단):
- `is_passable_base == false` (성벽 등)
- `elevation > max(attacker.elevation, target.elevation)`

인접 타일(중간 타일 없음)은 항상 LoS 통과.

### States and Transitions

**ST-1. Tile State Machine**

| tile_state | 이동 착지 | 이동 통과 | 공격 대상 |
|---|---|---|---|
| EMPTY | O | O | X |
| ALLY_OCCUPIED | X | O | X |
| ENEMY_OCCUPIED | X | X | O |
| IMPASSABLE | X | X | X |
| DESTRUCTIBLE | X | X | O |
| DESTROYED | O | O | X |

유효한 전이:
- EMPTY → ALLY_OCCUPIED (아군 유닛 이동/배치)
- EMPTY → ENEMY_OCCUPIED (적군 유닛 이동/배치)
- ALLY_OCCUPIED → EMPTY (아군 유닛 이동 출발 또는 사망)
- ENEMY_OCCUPIED → EMPTY (적군 유닛 이동 출발 또는 사망)
- DESTRUCTIBLE → DESTROYED (destruction_hp ≤ 0)
- IMPASSABLE → IMPASSABLE (변경 불가)
- DESTROYED → EMPTY (잔해는 빈 타일로 취급)

금지: ALLY_OCCUPIED ↔ ENEMY_OCCUPIED 직접 전이 없음. 반드시 EMPTY 경유.
`occupant_id`와 `tile_state`는 항상 동기 갱신해야 한다.

### Interactions with Other Systems

Grid System이 외부에 노출하는 쿼리 인터페이스:

| Query | Used By | Return |
|-------|---------|--------|
| `get_tile(coord: Vector2i)` → TileData | Terrain Effect, Battle HUD | 타일 전체 데이터 |
| `get_movement_range(unit_id, origin, move_range)` → Array[Vector2i] | Grid Battle, AI | 이동 가능 타일 |
| `get_path(unit_id, from, to)` → Array[Vector2i] | Grid Battle, AI | 최단 경로 |
| `get_attack_range(origin, atk_range, apply_los)` → Array[Vector2i] | Grid Battle, AI | 공격 가능 타일 |
| `get_attack_direction(atk_coord, def_coord, def_facing)` → AttackDirection | Grid Battle, Damage Calc | FRONT / FLANK / REAR |
| `get_adjacent_units(coord, faction)` → Array[int] | Formation Bonus | 인접 유닛 ID |
| `get_occupied_tiles(faction)` → Array[Vector2i] | AI | 진영별 점유 타일 |
| `has_line_of_sight(from, to)` → bool | AI | LoS 확인 |
| `get_map_dimensions()` → Vector2i | Camera | (map_cols, map_rows) |

모든 외부 시스템은 읽기 전용 접근만 허용된다. Grid 상태 변경은 Grid Battle
System의 명시적 호출(move_unit, remove_unit 등)을 통해서만 발생한다.

## Formulas

### F-1. Manhattan Distance

```
D(A, B) = |col_B - col_A| + |row_B - row_A|
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Column A | col_A | int | 0 – map_cols-1 | Column of tile A |
| Row A | row_A | int | 0 – map_rows-1 | Row of tile A |
| Column B | col_B | int | 0 – map_cols-1 | Column of tile B |
| Row B | row_B | int | 0 – map_rows-1 | Row of tile B |
| Distance | D | int | 0 – 67 | Tile distance (max: 39+28 on 40×30 map) |

**Output Range:** 0 (same tile) to 67 (opposite corners). Never negative.

**Example:** A=(3,2), B=(7,5) → `|7-3|+|5-2|` = 4+3 = **7**

---

### F-2. Movement Cost Per Step

```
step_cost = base_terrain_cost(terrain_type) × cost_multiplier(unit_type, terrain_type)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Base cost | base_terrain_cost | int | 7, 10, 15, 20 | CR-3 정수값 |
| Unit multiplier | cost_multiplier | int | 1, 2 | 병종별 지형 패널티 (1=보통, 2=곤란) |
| Step cost | step_cost | int | 7 – 40 | 해당 타일 진입 비용 |

**Output Range:** 최소 7 (ROAD×1), 최대 40 (MOUNTAIN×2).
통과 불가 지형(RIVER, FORTRESS_WALL)은 이 공식 호출 전 필터됨.

**Example:** 기병이 MOUNTAIN 진입 → `20 × 2 = 40`. 보병이 ROAD 진입 → `7 × 1 = 7`.

---

### F-3. Movement Range Check

```
accumulated_cost = Σ step_cost (경로 상 각 타일)
move_budget = move_range × 10
reachable = (accumulated_cost <= move_budget)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Accumulated cost | accumulated_cost | int | 0+ | 경로 총 비용 |
| Move range | move_range | int | 1 – 10 | 유닛 이동력 (타일 수 기준) |
| Move budget | move_budget | int | 10 – 100 | 이동력 × 10 |
| Reachable | reachable | bool | — | 도달 가능 여부 |

**Output Range:** move_budget 10~100. ×10 스케일이 정수 타일 수와 정수
코스트 체계를 연결한다 (move_range=3이 평지 3칸 = 30 = 30 정확히 일치).

**Example:** move_range=3 (budget=30).
- PLAINS→HILLS→PLAINS = 10+15+10 = 35 > 30 → **이동 불가**
- PLAINS→ROAD→PLAINS = 10+7+10 = 27 ≤ 30 → **이동 가능**

---

### F-4. Line of Sight Check

```
has_los(A, B) = NOT EXISTS intermediate tile T on Bresenham(A, B)
                WHERE T.elevation > max(A.elevation, B.elevation)
                   OR T.is_passable_base == false
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Attacker elevation | A.elev | int | 0, 1, 2 | 공격자 타일 고도 |
| Target elevation | B.elev | int | 0, 1, 2 | 대상 타일 고도 |
| Intermediate elevation | T.elev | int | 0, 1, 2 | 중간 타일 고도 |
| Passable | T.passable | bool | — | 중간 타일 통과 가능 여부 |
| Sight clearance | max_elev | int | 0, 1, 2 | max(A.elev, B.elev) |
| Has LoS | has_los | bool | — | 시야 확보 여부 |

**Output Range:** Boolean. 인접 타일(D=1)은 중간 타일 없으므로 항상 true.

**Example:** 궁병(elev=1) → 대상(elev=0). 중간에 MOUNTAIN(elev=2).
max(1,0)=1, 2>1 → **LoS 차단**. 중간에 HILLS(elev=1) → 1>1=false,
passable=true → **LoS 통과**.

---

### F-5. Attack Direction Calculation

```
attack_dir = direction(attacker_coord → defender_coord)
relative_angle = (attack_dir - defender.facing + 4) % 4
attack_direction = lookup(relative_angle)
```

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| Attack direction | attack_dir | int | 0–3 | 공격자→방어자 방향 |
| Defender facing | facing | int | 0–3 | 방어자 facing (CR-5) |
| Relative angle | rel | int | 0–3 | 상대 각도 |
| Result | attack_direction | enum | FRONT/FLANK/REAR | 공격 판정 |

**Lookup:**

| relative_angle | Result |
|---|---|
| 0 | FRONT |
| 1 | FLANK |
| 2 | REAR |
| 3 | FLANK |

**Output Range:** 정확히 {FRONT, FLANK, REAR} 중 하나. `+4`가 음수를 방지.

**Example:** 방어자 facing=NORTH(0). 공격자가 EAST(1)에서 접근 →
`(1-0+4)%4 = 1` → **FLANK**. 공격자가 SOUTH(2)에서 접근 →
`(2-0+4)%4 = 2` → **REAR**.

## Edge Cases

### 1. 맵 경계

- **If 경로 탐색 중 인접 타일이 `col < 0`, `col >= map_cols`, `row < 0`, `row >= map_rows`**:
  해당 이웃을 건너뜀. 범위 밖 좌표는 open set에 추가되지 않는다.
- **If 맵 로딩 시 유닛 시작 위치가 범위 밖**: 맵 로딩 거부
  `ERR_UNIT_COORD_OUT_OF_BOUNDS(unit_id, coord)`. 클램핑하지 않음 — 데이터 손상 은폐 방지.
- **If `get_tile(coord)`에 범위 밖 좌표 전달**: `null` 반환. 호출자가 null 체크해야 함.

### 2. 이동

- **If 이동 가능 타일이 없음** (IMPASSABLE + ENEMY로 완전 포위):
  `get_movement_range()` → 빈 Array. UI는 "이동 불가" 표시. 유닛은 제자리에서 공격 가능.
- **If 도달 가능 타일이 모두 ALLY_OCCUPIED** (통과는 가능, 착지 불가):
  빈 Array 반환. 유닛은 현재 타일에 머묾. 아군에 의한 의도된 봉쇄 상태.
- **If `move_range = 0`**: `move_budget = 0`. 출발 타일만 비용 0으로 만족.
  Grid Battle System과의 계약에 따라 출발 타일 포함 여부 결정.
- **If 두 유닛이 같은 턴에 같은 타일로 이동 시도**: 먼저 커밋된 쪽이 점유.
  두 번째 이동은 거부. 턴 순서가 이동 전에 해결되어야 한다.

### 3. 시야(LoS)

- **If Bresenham 직선이 타일 코너를 대각선으로 통과** (두 타일이 모서리만 공유):
  양쪽 타일 모두를 중간 타일로 취급. 어느 한쪽이라도 차단 조건 충족 시 LoS 차단.
  "벽 틈으로 사격" 악용 방지를 위한 보수적 처리.
- **If 공격자와 대상이 같은 고도이고 중간 타일도 같은 고도**:
  `elev > max(elev, elev)` = false → **LoS 통과**. 같은 고도의 중간 지형은 차단하지 않음.
- **If 공격자와 대상이 같은 타일 (D=0)**: `has_los` = true. 중간 타일 없음.
  호출자 버그이므로 경고 로그 출력.
- **If 인접 타일 (D=1)**: 항상 `has_los` = true. 루프 진입 없음.

### 4. Facing — 비인접/대각선 공격자

- **If 공격자와 방어자가 비인접** (원거리 공격, D>1):
  `attack_dir`은 더 큰 절대 델타 축으로 결정.
  `abs(dc) >= abs(dr)` → EAST/WEST, 그 외 → NORTH/SOUTH.
- **If 정확한 대각선 (`abs(dc) == abs(dr)`)**: 수평축 우선 (EAST/WEST).
  결정적이며 Damage Calc GDD에서도 동일 규칙을 따라야 한다.
- **If 같은 타일에서 공격 (`dc=0, dr=0`)**: `attack_dir` 정의 불가.
  FRONT를 기본값으로 반환, `ERR_SAME_TILE_ATTACK` 로그. 호출자 오류.

### 5. 파괴 가능 지형

- **If DESTRUCTIBLE 타일의 `destruction_hp <= 0`**: 즉시 DESTROYED로 전이.
  `is_passable_base` = true, `tile_state` = DESTROYED.
  `tile_destroyed(coord)` 시그널 발생 → AI, Formation, LoS 캐시 무효화.
- **If 유닛이 DESTRUCTIBLE 타일 위에 있을 때 파괴됨**: 타일은 DESTROYED가 되지만
  유닛은 유지. `tile_state`를 점유 상태(ALLY/ENEMY_OCCUPIED)로 즉시 재설정.
  파괴가 유닛 강제 이동을 유발하지 않음.
- **If IMPASSABLE이면서 `is_destructible = true`** (예: FORTRESS_WALL):
  유효한 상태. 파괴 전엔 경로 탐색에서 통과 불가, 파괴 후 통과 가능.
- **If `destruction_hp`가 음수로 저장됨**: 로딩 시 0으로 클램핑 + 경고.
  이미 파괴된 것으로 처리.

### 6. 타일 상태 동기화

- **If `tile_state = ALLY_OCCUPIED`이지만 `occupant_id = -1`**: 비동기 감지.
  `ERR_TILE_STATE_DESYNC(coord)` 로그, `tile_state` = EMPTY, `occupant_faction` = NONE으로 리셋.
- **If `occupant_id`가 존재하지 않는 유닛을 참조**: 동일 처리 — EMPTY로 리셋 + 에러 로그.
  그리드 상태는 유닛 레지스트리에서 추론하지 않는다.
- **If ALLY_OCCUPIED → ENEMY_OCCUPIED 직접 전이 시도**: 거부.
  `ERR_ILLEGAL_STATE_TRANSITION(coord, from, to)` 로그. 반드시 EMPTY 경유.

### 7. 맵 로딩

- **If `map_cols < 15` or `> 40` or `map_rows < 15` or `> 30`**:
  `ERR_MAP_DIMENSIONS_INVALID(cols, rows)`. 부분 로딩 없이 전체 거부.
- **If `map_cols = 0` or `map_rows = 0`**: 동일 거부. 0차원 맵은 유효하지 않음.
- **If 타일의 elevation이 terrain_type 허용 범위 밖**
  (예: PLAINS에 elevation=2): `ERR_ELEVATION_TERRAIN_MISMATCH(coord, terrain, elevation)`.
  모든 위반을 수집한 후 한 번에 거부 (맵 제작자가 모든 오류를 한 번에 확인).
- **If 타일 배열 길이 ≠ `map_cols × map_rows`**:
  `ERR_TILE_ARRAY_SIZE_MISMATCH(expected, actual)`.
- **If `is_destructible = true`이지만 `destruction_hp = 0`**:
  로딩 시 DESTROYED 상태로 처리 + 경고. 중간 파괴 상태 세이브 대응.
- **If `is_passable_base = false`이지만 타일이 점유 상태 (ALLY/ENEMY_OCCUPIED)**:
  로딩 거부. 통과 불가 타일에 유닛이 존재할 수 없다.

## Dependencies

### 상위 의존성 (이 시스템이 의존하는 것)

없음 — Foundation 레이어. 외부 시스템 없이 독립 작동한다.

### 하위 의존성 (이 시스템에 의존하는 것)

| System | 의존 유형 | 사용하는 쿼리 | 데이터 인터페이스 |
|--------|----------|-------------|-----------------|
| Terrain Effect | Hard | `get_tile()` | terrain_type, elevation |
| Grid Battle | Hard | `get_movement_range()`, `get_path()`, `get_attack_range()`, `get_attack_direction()` | 이동/공격 전체 |
| Formation Bonus | Hard | `get_adjacent_units()` | 인접 유닛 ID 목록 |
| Damage/Combat Calc | Hard | `get_attack_direction()` | FRONT / FLANK / REAR |
| AI System | Hard | `get_movement_range()`, `get_attack_range()`, `get_occupied_tiles()`, `has_line_of_sight()` | 전술 분석 전체 |
| Battle Preparation | Soft | `get_tile()` | 배치 가능 영역 확인 |
| Camera | Hard | `get_map_dimensions()` | 맵 크기 (col, row) |
| Battle HUD | Soft | `get_tile()` | 타일 정보 툴팁 |
| Battle Effects/VFX | Soft | 좌표 → 화면 위치 변환 | 타일 좌표 |

Hard = 이 시스템 없이 작동 불가. Soft = 없어도 기능하지만 정보가 축소됨.

### 크로스 시스템 계약

이 GDD에서 결정된 규칙으로, 다른 GDD가 반드시 따라야 한다:

- **대각선 facing 동률 규칙**: `abs(dc) == abs(dr)` 시 수평축(EAST/WEST) 우선
  → Damage Calc GDD에서 동일 규칙 적용 필수
- **이동 코스트 정수 체계**: 기준값 10 (PLAINS), move_budget = move_range × 10
  → Unit Role GDD에서 move_range 설정 시 이 스케일 사용
- **`tile_destroyed(coord)` 시그널**: 파괴 가능 타일 파괴 시 발생
  → AI, Formation Bonus, LoS 캐시를 소유한 시스템이 무효화 처리

## Tuning Knobs

| Knob | 현재 값 | 안전 범위 | 너무 높으면 | 너무 낮으면 | 영향 |
|------|---------|----------|-----------|-----------|------|
| `map_cols_min` | 15 | 10–20 | 소규모 전투가 넓어 산만 | 맵이 너무 좁아 배치 불가 | 최소 맵 너비 |
| `map_cols_max` | 40 | 30–50 | 모바일 성능/메모리 초과 | 대규모 전투 표현 불가 | 최대 맵 너비 |
| `map_rows_min` | 15 | 10–20 | 위와 동일 | 위와 동일 | 최소 맵 높이 |
| `map_rows_max` | 30 | 20–40 | 위와 동일 | 위와 동일 | 최대 맵 높이 |
| `terrain_cost_plains` | 10 | 8–12 | 평지 이동이 느려짐 | 도로와 차이 축소 | 기준 이동 코스트 |
| `terrain_cost_hills` | 15 | 12–20 | 구릉이 사실상 장벽 | 평지와 차이 없음 | 구릉 페널티 |
| `terrain_cost_mountain` | 20 | 15–30 | 산지 접근 불가에 가까움 | 산지가 너무 쉬움 | 산지 페널티 |
| `terrain_cost_forest` | 15 | 12–20 | 숲이 이동 장벽화 | 숲의 전술적 의미 감소 | 숲 페널티 |
| `terrain_cost_road` | 7 | 5–9 | 도로가 평지와 비슷 | 도로만 쓰는 최적 경로 | 도로 이점 |
| `destruction_hp_range` | 0–999 | 1–500 | 파괴 불가에 가까움 | 한 방에 부서짐 | 파괴 가능 지형 내구도 |

### 상호작용 주의

- `terrain_cost_plains` 변경 시 `move_range × 10`의 의미가 달라짐 — Unit Role
  시스템의 move_range 값과 반드시 연동 검증
- `terrain_cost_road`를 너무 낮추면 AI가 항상 도로를 선호 → AI 전술 다양성 감소
- `map_cols_max × map_rows_max` 조합이 모바일 메모리 예산(512MB) 내인지 확인 필요
  — 최대 맵(40×30=1200 타일)은 TileData 크기 × 1200으로 산출

## Visual/Audio Requirements

Foundation 시스템 — 직접적 시각/음향 요구사항 없음.
타일 시각화는 전투 HUD 및 Battle Effects GDD에서 정의.

## UI Requirements

Foundation 시스템 — 직접적 UI 없음.
타일 정보 툴팁, 이동/공격 범위 오버레이는 전투 HUD GDD에서 정의.

## Acceptance Criteria

### Core Rules

**AC-CR-1. 좌표 체계 — 맵 경계 내 유효 좌표**
- **GIVEN** 40×30 맵이 로드되어 있을 때
- **WHEN** `get_tile(Vector2i(39, 29))`를 호출하면
- **THEN** null이 아닌 TileData가 반환되고, `get_tile(Vector2i(40, 0))` 및
  `get_tile(Vector2i(0, 30))`는 null을 반환한다

**AC-CR-2. 타일 데이터 구조 — flat array 인덱싱**
- **GIVEN** 15×15 맵이 로드되어 있을 때
- **WHEN** `get_tile(Vector2i(3, 5))`를 호출하면
- **THEN** 내부 배열의 인덱스 `5 × 15 + 3 = 78`번 요소와 동일한 TileData가 반환된다

**AC-CR-3. 지형 타입 — 이동 코스트 정수값**
- **GIVEN** ROAD(7), PLAINS(10), HILLS(15), MOUNTAIN(20) 타일이 있을 때
- **WHEN** `step_cost`(multiplier=1)를 각 지형에 계산하면
- **THEN** 각각 정확히 7, 10, 15, 20이 반환되고 RIVER/FORTRESS_WALL은 제외된다

**AC-CR-4. 고도 — 유효성 검증**
- **GIVEN** PLAINS 타일에 `elevation=2`가 설정된 맵 데이터를 로드할 때
- **WHEN** 맵 로딩을 시도하면
- **THEN** 로딩이 거부되고 `ERR_ELEVATION_TERRAIN_MISMATCH` 에러가 기록된다

**AC-CR-5. Facing — 공격 방향 판정**
- **GIVEN** facing=NORTH(0)인 방어자 유닛이 있을 때
- **WHEN** 공격자가 SOUTH(2) 방향에서 공격하면
- **THEN** `relative_angle = (2-0+4)%4 = 2`이고 판정 결과는 REAR이다

**AC-CR-6. 경로 탐색 — 적군 차단 + 아군 통과**
- **GIVEN** move_range=3인 유닛이 PLAINS에 있고, 경로상 ENEMY_OCCUPIED 타일이 있을 때
- **WHEN** `get_movement_range()`를 호출하면
- **THEN** ENEMY_OCCUPIED 타일과 그 너머는 결과에 미포함, ALLY_OCCUPIED는
  통과 가능하지만 착지 목록에 미포함

**AC-CR-7. 시야 — LoS 차단**
- **GIVEN** 공격자(elev=0)와 대상(elev=0) 사이에 FORTRESS_WALL이 있을 때
- **WHEN** `has_line_of_sight()`를 호출하면
- **THEN** false가 반환된다

### Formulas

**AC-F-1. Manhattan Distance**
- **GIVEN** A=(3,2), B=(7,5) 두 타일이 있을 때
- **WHEN** 거리를 계산하면
- **THEN** 결과는 `|7-3|+|5-2| = 7`이고, 음수는 반환되지 않는다

**AC-F-2. 이동 코스트 — multiplier 적용**
- **GIVEN** cost_multiplier=2인 병종이 MOUNTAIN(20) 타일로 이동할 때
- **WHEN** step_cost를 계산하면
- **THEN** 결과는 `20 × 2 = 40`이다

**AC-F-3. 이동 범위 — 경계값**
- **GIVEN** move_range=3(budget=30)인 유닛이 있을 때
- **WHEN** PLAINS→HILLS→PLAINS 경로(cost=35)를 탐색하면
- **THEN** 이동 불가. PLAINS→ROAD→PLAINS(cost=27)는 이동 가능

**AC-F-4. LoS — 중간 타일 고도 차단**
- **GIVEN** 공격자(elev=1), 대상(elev=0), 중간 타일(elev=2)일 때
- **WHEN** `has_los`를 계산하면
- **THEN** `2 > max(1,0)=1` → false. 중간 타일 elev=1이면 `1>1`=false → true

**AC-F-5. 공격 방향 — 전체 각도**
- **GIVEN** facing=NORTH(0)인 방어자가 있을 때
- **WHEN** 공격 방향이 NORTH(0), EAST(1), SOUTH(2), WEST(3)일 때
- **THEN** 각각 FRONT, FLANK, REAR, FLANK가 반환된다

### 타일 상태 전이

**AC-ST-1. EMPTY → ALLY_OCCUPIED**
- **GIVEN** `tile_state=EMPTY`인 타일에 아군 유닛이 이동할 때
- **WHEN** `move_unit()`이 호출되면
- **THEN** `tile_state`, `occupant_id`, `occupant_faction`이 동기 갱신된다

**AC-ST-2. DESTRUCTIBLE → DESTROYED**
- **GIVEN** `destruction_hp=1`인 DESTRUCTIBLE 타일이 있을 때
- **WHEN** 1 이상의 피해가 적용되면
- **THEN** DESTROYED로 전환, `is_passable_base=true`, `tile_destroyed` 시그널 발생

**AC-ST-3. 직접 전이 금지**
- **GIVEN** `tile_state=ALLY_OCCUPIED`인 타일에 적군 직접 점유를 시도할 때
- **WHEN** 상태 변경이 요청되면
- **THEN** 거부되고 `ERR_ILLEGAL_STATE_TRANSITION` 로그, 상태 불변

**AC-ST-4. IMPASSABLE 불변성**
- **GIVEN** `tile_state=IMPASSABLE`인 타일이 있을 때
- **WHEN** 상태 변경이 시도되면
- **THEN** IMPASSABLE 유지 (is_destructible=true인 경우 hp<=0 시 DESTROYED 전이만 허용)

### 엣지 케이스

**AC-EDGE-1. 유닛 시작 위치 범위 초과**
- **GIVEN** 유닛 시작 위치가 `(41, 0)`인 맵 데이터를 로드할 때
- **WHEN** 로딩 시도 시
- **THEN** 전체 거부, `ERR_UNIT_COORD_OUT_OF_BOUNDS`, 클램핑 없음

**AC-EDGE-2. 완전 포위 — 이동 불가**
- **GIVEN** 유닛의 상하좌우가 모두 IMPASSABLE 또는 ENEMY_OCCUPIED일 때
- **WHEN** `get_movement_range()` 호출 시
- **THEN** 빈 Array 반환

**AC-EDGE-3. 인접 타일 LoS**
- **GIVEN** 두 타일이 인접(D=1)할 때
- **WHEN** `has_line_of_sight()` 호출 시
- **THEN** 항상 true 반환

**AC-EDGE-4. 파괴 타일 위 유닛 생존**
- **GIVEN** DESTRUCTIBLE 타일 위에 아군 유닛이 있을 때
- **WHEN** 타일이 파괴되면
- **THEN** 유닛 유지, `tile_state`가 ALLY_OCCUPIED로 즉시 재설정

### 성능

**AC-PERF-1. 60fps 유지**
- **GIVEN** 최대 맵(40×30) 전투가 진행 중일 때
- **WHEN** 표준 전투 턴(이동, 렌더, 상태 갱신 동시)이 실행되면
- **THEN** 16.6ms 초과 프레임이 3회 연속 발생하지 않는다 (모바일 최소 사양)

**AC-PERF-2. 경로 탐색 16ms 이내**
- **GIVEN** 40×30 맵에서 move_range=10인 유닛이 있을 때
- **WHEN** `get_movement_range()` 또는 `get_path()` 호출 시
- **THEN** 함수 실행 시간이 16ms를 초과하지 않는다 (캐시 미적중 포함)

## Open Questions

1. **병종별 이동 코스트 매트릭스의 정확한 값** — Unit Role GDD에서 정의 예정.
   현재는 cost_multiplier가 1 또는 2만 존재하나, 기병의 도로 보너스 같은
   추가 값이 필요할 수 있음. 정수 체계에서는 별도 코스트값(예: 5)으로 해결 가능.
   Owner: Unit Role GDD | Target: MVP 설계 시

2. **맵 에디터 / 맵 데이터 포맷** — 맵 저장 형태 미결정.
   Godot TileMap 리소스? JSON? CSV? 커스텀 Resource?
   Owner: Architecture (ADR) | Target: 프로토타입 전

3. **동적 지형 변화** — 화공(火攻)으로 숲 소실, 수공(水攻)으로 평지→강 등의
   동적 변화를 지원할 것인가? 현재 설계는 DESTRUCTIBLE→DESTROYED만 지원.
   Owner: Game Designer | Target: Vertical Slice

4. **안개(Fog of War)** — 시야 범위 밖 타일 숨김 기능 필요 여부.
   영걸전 원작에는 없으나 전술적 깊이 추가 가능.
   Owner: Game Designer | Target: Alpha
