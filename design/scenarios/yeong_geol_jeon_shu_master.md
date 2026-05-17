# 영걸전식 Shu 라인 마스터 플랜 (mvp_shu 풀 캠페인)

> **상태**: DRAFT — 2026-05-17 작성. 구현 전 사용자 승인 단계.
> **목표**: 현재 5챕터(장판~적벽)인 `mvp_shu` 시나리오를 영걸전식 25챕터 풀 캠페인으로 확장 (도원결의 → 오장원).
> **범위**: 데이터 레이어 (JSON + .tres 맵 + story_content + heroes.json + 회귀 테스트). 시나리오 선택 UI / 기존 메뉴는 별건.

---

## 1. 25 챕터 타임라인

| #   | chapter_id                          | 제목 (KR)               | 승리 조건           | 영웅 합류             | Hidden Destiny                                  |
|-----|-------------------------------------|------------------------|---------------------|-----------------------|-------------------------------------------------|
| 01  | `ch01_taoyuan_yellow_turban`        | 도원결의·황건적 토벌    | ANNIHILATION        | 유비/관우/장비 (start) | —                                               |
| 02  | `ch02_hulao_gate`                   | 호뢰관 (여포)           | SURVIVE 5 OR REACH  | —                     | dmg_to_lubu ≥ 30 → 여포 직접 격퇴 인증           |
| 03  | `ch03_xuzhou_rescue`                | 서주 (도겸 구원)        | ANNIHILATION        | 조운 (zhao_yun)        | escort_alive → 도겸 사후 서주 안정              |
| 04  | `ch04_bowang_slope`                 | 박망파 (하후돈 격파)    | ANNIHILATION        | 제갈량 (zhuge_liang)   | turns ≤ 6 → 제갈량 신뢰 max                     |
| 05  | `ch05_xinye_fire`                   | 신야 화공               | SURVIVE 5           | —                     | civilians_saved ≥ 3 → 형주 백성 호의            |
| 06  | `ch06_changbanpo`                   | 장판파 (조운 단기필마)  | SURVIVE 5           | —                     | assassin_kills ≥ 2 → 유선 무사                  |
| 07  | `ch07_changban_bridge`              | 장판교 (장비 호통)      | SURVIVE 5           | —                     | —                                               |
| 08  | `ch08_xiakou_outskirts`             | 하구 외곽               | REACH_TILE          | 황충 (huang_zhong)     | formation_turns ≥ 3 → 초선 합류 (ch09)         |
| 09  | `ch09_chibi_prelude`                | 적벽 prelude (오 동맹)  | ANNIHILATION        | 손권/주유              | —                                               |
| 10  | `ch10_chibi_main`                   | 적벽 main (화공)        | ANNIHILATION        | —                     | wind_turns ≥ 2 → 화공 완전 성공                 |
| 11  | `ch11_jingzhou_pacify`              | 형주 평정 (영릉/계양)   | ANNIHILATION        | —                     | —                                               |
| 12  | `ch12_wuling_marsh`                 | 무릉 (사마가)           | ANNIHILATION        | —                     | —                                               |
| 13  | `ch13_changsha_veteran`             | 장사 (황충·위연)        | ANNIHILATION        | 위연 (wei_yan)         | huang_zhong_spared → 위연 합류 (영걸전 시그니처) |
| 14  | `ch14_jingzhou_consolidate`         | 형주 안정 (4군 통합)    | ANNIHILATION        | —                     | —                                               |
| 15  | `ch15_fushui_pass`                  | 부수관 (입촉 시작)      | REACH_TILE          | 방통 (pang_tong)       | —                                               |
| 16  | `ch16_luofeng_slope`                | 낙봉파 (방통 위기)      | SURVIVE 4           | —                     | scout_first ≥ 2 → **방통 생존** (영걸전 시그니처) |
| 17  | `ch17_chengdu_gates`                | 성도 (익주 완성)        | ANNIHILATION        | —                     | —                                               |
| 18  | `ch18_hanzhong_advance`             | 한중 진군 (마초 합류)   | ANNIHILATION        | 마초 (ma_chao)         | —                                               |
| 19  | `ch19_dingjun_peak`                 | 정군산 (황충·하후연)    | ANNIHILATION        | —                     | huang_zhong_kills_xiahou_yuan → 노장 인증        |
| 20  | `ch20_fancheng_pursuit`             | 번성·형주 함락          | SURVIVE 6           | —                     | retreat_path_clear → **관우 생환** (영걸전 시그니처) |
| 21  | `ch21_zhangfei_avenge`              | 장비의 출병 직전        | ANNIHILATION        | —                     | discipline_turns ≥ 4 → **장비 생존**            |
| 22  | `ch22_yiling_burn`                  | 이릉 화공 (육손)        | SURVIVE 6           | —                     | counter_fire_turns ≥ 2 → **유비 생환**          |
| 23  | `ch23_southern_pacify`              | 남만 정벌 (맹획)        | ANNIHILATION        | —                     | menghuo_captures ≥ 7 → 칠종칠금 인증            |
| 24  | `ch24_jieting_pass`                 | 가정 (1차 북벌)         | REACH_TILE          | 강유 (jiang_wei)       | masu_supervised → **마속 생존** (영걸전 시그니처) |
| 25  | `ch25_wuzhang_plains`               | 오장원 (제갈량 최후)    | SURVIVE 8           | —                     | qixing_turns ≥ 6 → **제갈량 회생** (영걸전 최종) |

**Hidden destiny 총 14개** (현재 mvp_shu 2개 → 14개). 그 중 **시그니처 영걸전 분기 5개** (방통/관우/장비/유비/마속 생환 + 제갈량 회생).

---

## 2. 영웅 합류·이탈 매트릭스

| Hero ID             | 합류 챕터  | 이탈 챕터 (default)   | 생존 분기 (hidden)                |
|---------------------|-----------|----------------------|----------------------------------|
| `shu_001_liu_bei`   | ch01     | ch22 (이릉 사망)      | ch22 WIN_hidden → 끝까지 생존     |
| `shu_002_guan_yu`   | ch01     | ch20 (형주 함락)      | ch20 WIN_hidden → 끝까지 생존     |
| `shu_003_zhang_fei` | ch01     | ch21 (사망 컷씬)      | ch21 WIN_hidden → 끝까지 생존     |
| `shu_004_huang_zhong` | ch08   | (자연사 묘사 ch20+)   | —                                |
| `shu_005_zhao_yun` ★ | ch03    | —                    | —                                |
| `shu_006_zhuge_liang` ★ | ch04 | ch25 (오장원 사망)    | ch25 WIN_hidden → 회생            |
| `shu_007_pang_tong` ★ | ch15   | ch16 (낙봉파)         | ch16 WIN_hidden → 생존, 군사 2人 |
| `shu_008_ma_chao` ★  | ch18    | —                    | —                                |
| `shu_009_wei_yan` ★  | ch13    | —                    | —                                |
| `shu_010_jiang_wei` ★ | ch24   | —                    | —                                |

★ = 새 영웅 데이터 작성 필요 (6명). 기존 4명 (유비/관우/장비/황충) + 손권/주유/여포/초선 (이미 풀에 존재) 그대로.

**새 영웅 stat 시드 가이드** (default_class 참조 — `equipment_system.gd` 클래스 enum):
- 조운 자룡 — 균형형 무장 (만능): might 90 / int 70 / cmd 80 / agi 88, class=1(WARRIOR) or 3(LANCER)
- 제갈량 공명 — 전략가: might 50 / int 99 / cmd 95 / agi 60, class=4(STRATEGIST)
- 방통 사원 — 봉추: might 45 / int 95 / cmd 80 / agi 55, class=4
- 마초 맹기 — 서량 기병: might 95 / int 60 / cmd 75 / agi 90, class=3(LANCER)
- 위연 문장 — 야성 무장: might 88 / int 65 / cmd 70 / agi 75, class=1(WARRIOR)
- 강유 백약 — 후계 전략가: might 75 / int 90 / cmd 85 / agi 80, class=4 or 3

상세 stat은 ch11+ 구현 단계에서 systems-designer 위임 (밸런스 패스).

---

## 3. 승리 조건 분포

| 조건            | 챕터 수 | 예시 챕터                              |
|----------------|---------|--------------------------------------|
| ANNIHILATION   | 12      | ch01, ch03, ch04, ch09, ch11, ch12, ch13, ch14, ch17, ch18, ch19, ch21, ch23 |
| SURVIVE N      | 8       | ch02, ch05, ch06, ch07, ch10, ch16, ch20, ch22, ch25 |
| REACH_TILE     | 4       | ch02 (alt), ch08, ch15, ch24             |

영걸전 원작 패턴 추종 — 단순 섬멸 절반 + 생존/도달 절반.

---

## 4. Hidden Destiny 체인 (영걸전 영혼)

**시그니처 분기 5개** 가 전체 캠페인 보상 체인:
1. **방통 생존 (ch16)** → ch17 부터 봉추+와룡 2軍師 동시 운용 가능 → ch24+ 가정 hidden 쉬워짐 (마속 살리는 슈퍼바이저로 방통 추가 가능)
2. **관우 생환 (ch20)** → ch22 이릉 hidden 조건 완화 (관우 진영 1人 보너스) → 유비 생환 더 쉬움
3. **유비 생환 (ch22)** → ch23+ 남만/북벌 chapter에서 유비 출전 가능 (장수 풀 +1)
4. **마속 생존 (ch24)** → ch25 오장원 hidden 조건 완화 (마속이 한 진영 holds → qixing_turns 누적 쉬움)
5. **제갈량 회생 (ch25)** → END 분기, 별도 ending 텍스트

체인 끝까지 5/5 달성 시 → 별도 ending key (`ENDING_perfect_destiny` — Shu 통일 추가 텍스트).
default (5/5 모두 fail) 시 → `ENDING_canonical_loyal` (정사 기반 — Shu 멸망 직전 묘사).

---

## 5. 맵 사이즈 가이드

기존 5챕터 사이즈 (10×7 ~ 16×9). `MapGrid` 검증 bounds 는 S60에서 (COLS_MIN=6, ROWS_MIN=5) 로 완화됨. 신규 챕터 권장:

| 챕터 타입            | 권장 사이즈        | 비고                                |
|---------------------|-------------------|------------------------------------|
| 초반 (ch01~ch05)    | 12×9 ~ 14×10      | 영웅 수 적음, narrow battlefield   |
| 중반 (ch06~ch17)    | 14×9 ~ 16×11      | 영웅 풀 늘어남, mid maps           |
| 후반 (ch18~ch25)    | 16×11 ~ 18×12     | 풀 로스터 (8~10인), wide maps      |
| 화공 챕터 (ch05/10/22) | 12×10 + FIRE 타일 | terrain decoration                |
| 산악 (ch24 가정)    | 14×11 + MOUNTAIN 타일 | hill-and-valley 전술 강조        |

---

## 6. 구현 단계 (Phase plan)

### Phase 0 — 현재 5챕터 index shift (ch01~ch05 → ch06~ch10) ★ 충돌 방지 선행
1. `mvp_shu.json` 챕터 ID rename
2. `story_content.json` 키 rename (`shu.ch01.*` → `shu.ch06.*` 등 — 기존 키 prefix 확인 후 일괄)
3. `sound_manager.gd::music_id_for_chapter` switch case 5 lines update
4. 회귀 테스트 expectation update (scenario_runner_victory_conditions_hydration_test 등)
5. 맵 .tres 파일명도 `mvp_shu_chapter_0[1-5].tres` → `..._0[6-10].tres` (rename + 참조 업데이트)
6. DEV 챕터 점프 UI 의 ch_id label 자동 반영 (코드 변경 X — JSON 읽음)
7. 1783 그린 유지 + 헤드리스 boot 검증 (ch06~ch10 chain)

### Phase A — Prequel 5챕터 신규 작성 (ch01~ch05, 황건적~신야)
1. 새 영웅 2명 데이터 (`shu_005_zhao_yun`, `shu_006_zhuge_liang`) — heroes.json
2. 5 챕터 entry (mvp_shu.json) + 5 .tres 맵 (`mvp_shu_chapter_0[1-5].tres` 신규)
3. story_content.json 한국어 prose (각 5~9 beat × 5챕터)
4. SoundManager.music_id_for_chapter 5 새 챕터 매핑 (기존 5 테마 재활용)
5. 회귀 테스트 +N (scenario hydration / map .tres load / story coverage / BGM coverage)

### Phase B — Jingzhou/South 4군 (ch11~ch14)
1. 새 영웅 1명 (`shu_009_wei_yan`)
2. 4 챕터 + 4 맵 + story prose + tests
3. ch13 hidden destiny 유난히 영걸전스러움 (황충 spare → 위연 unlock) — 자세히 정성껏

### Phase C — Yi province (ch15~ch17)
1. 새 영웅 1명 (`shu_007_pang_tong`)
2. 3 챕터 + 3 맵 + story prose + tests
3. ch16 방통 생존 hidden — Pillar 2 시그니처

### Phase D — Hanzhong + Decline (ch18~ch22)
1. 새 영웅 1명 (`shu_008_ma_chao`)
2. 5 챕터 + 5 맵 + story prose + tests
3. ch20/21/22 시그니처 hidden 3개 (관우/장비/유비 생존)

### Phase E — Three Kingdoms End (ch23~ch25)
1. 새 영웅 1명 (`shu_010_jiang_wei`)
2. 3 챕터 + 3 맵 + story prose + tests
3. ch24/25 hidden 2개 (마속/제갈량) + 2개 ending key 분기

### Phase F — Polish + Attestation
1. Windowed playthrough attestation (G-30 패턴 — DEV 챕터 점프로 각 챕터 boot 검증)
2. ending key 텍스트 마무리 (5/5 perfect destiny vs canonical)
3. 음악 — 새 챕터 25개 모두 5개 procedural 테마 thematic mapping (별도 작곡 없이도 일관성)
4. README / production/session-state/active.md 업데이트

---

## 7. 위험 / 미해결 질문

1. **음악 다양성**: 25챕터를 5개 procedural 테마만으로 thematic mapping 하면 반복감 강할 수 있음. polish phase 에서 외부 OGG 도입 또는 +5 테마 procedural 추가 후보.
2. **밸런스**: 8~10인 풀 로스터 + 적 8~12명 챕터의 turn-order 처리 부담. `TurnOrderRunner` perf 회귀 가능 — polish phase 에서 perf-analyst 측정.
3. **방통/관우/장비/유비/마속/제갈량 생존 hidden 동시 달성** 시 ending text가 너무 보너스 위주가 될 수 있음. 영걸전 원작에서도 perfect ending 은 별도 보상 — narrative-director 위임 후 텍스트 결정.
4. **scenario_id="mvp_shu"** 이름 — 5챕터 시절엔 적절했지만 25챕터 풀 캠페인이라 `mvp_*` prefix 어색. 향후 rename 후보 (`shu_canon_full` 또는 `yeong_geol_jeon_shu`). 후방 호환은 SaveContext.scenario_id 마이그레이션 필요. Phase F 정리.
5. **DEV 챕터 점프** 현재 5챕터 JSON 파싱 — 25챕터로 늘면 메뉴 너무 김. submenu (5 phase × 5 ch) 또는 scroll 필요. main_menu.gd 의 PopupMenu 조정.

---

## 8. 승인 후 시작 시점

사용자 승인 시 **Phase 0 (인덱스 시프트)** 부터 즉시 진행 — 충돌 방지 선행 작업.
1. mvp_shu.json 의 ch01~ch05 chapter_id 를 ch06~ch10 으로 rename
2. 맵 .tres 5개 파일명 rename + JSON 참조 업데이트
3. story_content.json 키 rename (ch01.* → ch06.* 등)
4. sound_manager.gd switch case rename
5. 회귀 테스트 expectation 업데이트
6. 1783 그린 유지 + 헤드리스 boot 검증

Phase 0 완료 후 Phase A (prequel 5챕터 신규 작성) → ...

각 단계 완료마다 사용자 보고 + 다음 단계 승인.
