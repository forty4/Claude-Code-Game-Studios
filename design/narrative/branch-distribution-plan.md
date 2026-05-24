# Branch Distribution & Tragedy Preservation Plan

**Type**: Architecture (cross-chapter narrative design)
**Scope**: MVP 16ch (primary) + Full Vision ch17-25 (forecast)
**Status**: Draft — skeleton 2026-05-24
**Authors**: user + claude (incremental authoring per `.claude/rules/design-docs.md`)
**Anchors**:
  - `design/gdd/game-concept.md` — Pillars 2 (운명은 바꿀 수 있다) + 4 (삼국지의 숨결)
  - `design/gdd/destiny-branch.md` — CR-13 (Ch1 priming-null) + Ceremonial Witness fantasy
  - `design/gdd/scenario-progression.md` — CR-13 (echo_threshold) + hidden_branch_key system + F-SP-1 resolve_branch
  - `production/milestones/mvp-demo-16ch.md` — ship target (this doc supplies the branch architecture for that ship)

---

## 1. Overview

천명역전의 약속 — *"숨겨진 운명 분기로 역사의 비극을 뒤집는다"* — 은 두 가지 면에서 무게를 얻는다. 첫째, 분기는 **드물어야** 한다. 매 챕터에 분기가 있으면 사용자는 분기를 *발견* 하지 않고 *기대* 하게 되며, 그 순간 "운명을 거스른다" 는 감정은 "옵션을 선택한다" 로 격하된다. 분기는 16 챕터 중 4-5 개에만 자리한다. 둘째, 일부 비극은 **보존되어야** 한다. 모든 비극을 뒤집을 수 있다면 사용자는 "all-save 정답 루트" 를 추구하게 되고, 그 순간 비극의 무게는 무게가 아닌 *해결해야 할 퍼즐* 이 된다. 이 문서는 16 챕터 MVP 와 Full Vision (ch17-25) 의 ★ 분포를 그 두 원칙 위에서 정의하며, 도원결의의 세 형제 비극 (ch20-22) 을 cascade-block 메카닉으로 처리하여 *"한 자락은 반드시 끊긴다"* 의 narrative inevitability 를 사용자 선택의 결과로 felt 되게 한다. `design/gdd/game-concept.md` 의 Pillar 2 ("운명은 바꿀 수 있다") 와 Pillar 4 ("삼국지의 숨결") 는 분기의 **scarcity** 와 비극의 **partial preservation** 이 함께 있을 때 비로소 약속한 무게를 가진다.

## 2. Four Core Principles

### Principle 1 — Scarcity over Density

분기는 드물어야 한다. MVP 16 챕터 중 ★ 5 개 (≈31% 밀도), Full Vision 25 챕터 중 ★ 8 개 (32%). 평균 3-4 챕터 default 사이 ★ 1 개의 리듬. 사용자가 "다음 ★ 가 언제인가" 를 *기다리지* 않고 *발견* 하도록.

> **Design test**: "이 챕터에도 ★ 를 추가하면 안 될까?" 라는 질문이 나올 때, 이 원칙은 기본값으로 **NO** 를 답한다. ★ 추가는 (a) 해당 챕터가 narrative anchor (변곡, 정체성 정의 moment) 이고 (b) 인접 ★ 와 thematic register 가 명확히 다를 때만 허용. 그렇지 않으면 default 가 정답.

### Principle 2 — Tragedy Preserved by Design

비극의 일부는 시스템이 강제로 보존해야 한다. 사용자 의지로 "all-save" 가 불가능해야 비극이 무게를 유지한다. 도원결의 형제 cluster (ch20-22) 는 cascade-block 으로 처리 — ★ 한 명을 살리면 다음 ★ 가 disabled. 최대 2 명까지만 살릴 수 있고, *한 자락은 반드시 끊긴다*. 도원의 "동월동일에 죽기를 원함" 약속이 ch01 에서 정립되고 ch20-22 에서 inverse 로 화답된다.

> **Design test**: 새 ★ 추가 또는 기존 ★ trigger 완화 제안 시, "이 변경으로 사용자가 비극 N+1 명을 살릴 수 있게 되는가?" 를 확인. 만약 그렇다면 cascade-block exception 이 필요한지 명시적으로 정당화 필요. 비극을 줄이는 방향의 변경은 default 로 거부.

### Principle 3 — Decisive-Moment Recognition (Signaled, Not Announced)

★ 챕터에서 사용자는 "이 챕터는 다르다" 를 *직감* 으로 알게 되어야 한다. Beat 1/3 prose 의 sensory anchor, hero banter 의 unusual emotional register, BGM 의 미세 variation, optional UI subtle treatment. 그러나 "이 챕터는 운명 분기가 있습니다" 같은 explicit UI 는 금지 — 발견의 묘미가 죽는다. `design/gdd/destiny-branch.md` 의 Ceremonial Witness fantasy ("관측되는 것이지 선택되는 것이 아니다") 와 정합.

> **Design test**: 새 ★ 또는 signaling 메카닉 제안 시, "사용자가 이 챕터의 분기 가능성을 *발견하기 전에* 알 수 있는가?" 를 확인. 만약 explicit affordance (메뉴 항목, 별 표시, 알림) 가 있다면 거부. 미세한 sensory cue 만 허용.

### Principle 4 — ch01 ≠ First Branch Slot

ch01 은 운명 분기의 *첫 자리* 가 아니다. ch01 = 약속의 *무게* 챕터 — 도원결의 motif 정립, 황건적 lore 정합, 첫 전투의 긴장감. 첫 actual ★ 는 ch05 (신야 화공) 에서. `design/gdd/destiny-branch.md` CR-13 의 "Ch1 priming-null by design" 과 architectural 정합 — ch01 의 baseline 이 있어야 ch02+ 의 reserved-color contrast 가 felt 됨.

> **Design test**: ch01 에 ★ 또는 reserved-color-eliciting branch 추가 제안 시 default 거부. ch01 의 무게는 mechanical scarcity (분기 부재) + lore density (도원결의 + 황건적) + Beat 8 prose 의 ch05 seed 로 짊어진다. 분기로 짊어지지 않는다.

## 3. MVP 16ch ★ Distribution

| ch | 챕터 | thematic anchor | 역할 | ★ |
|----|------|-----------------|------|---|
| 01 | 도원결의·황건 | 형제 맹세의 무게 | **약속 정립** (priming-null per CR-13) | — |
| 02 | 호뢰관 여포 | 의병 vs 천하무쌍 | prelude (의병이 자기 자리를 알아감) | — |
| 03 | 서주 도겸 | 책임을 받는 자 | prelude (영지 부담의 첫 무게) | — |
| 04 | 박망파 | 諸葛亮 부임 | **변곡** (군사 합류 — 형제만의 시기 끝) | — |
| **05** | **신야 화공** | **백성을 지킨 의병** | **★ #1** — 도원 motif 와 직결 (의로움의 첫 mechanical 증명) | ★ 신규 |
| 06 | 장판파 | 떠나는 백성 + 흩어진 진 | prelude (흩어짐 → 호통의 setup) | — |
| 07 | 장판교 호통 | 단신의 의지 | prelude (장비의 단독 moment) | — |
| **08** | **하구 적의동맹** | **천하 분기의 결의 timing** | **★ #2** — 손유 동맹 결의의 perfect moment | ★ 신규 |
| 09 | 적벽 prelude | 강기슭 동맹 굳히기 | prelude (적벽 본 전투의 setup) | — |
| **10** | **적벽 본 전투** | **동남풍의 timing** | **★ #3** — perfect victory (불이 강을 다 식히기 전 종결) | ★ 신규 |
| 11 | 영릉·계양 | 첫 영토 | prelude (형주 4 군 정복 시작) | — |
| 12 | 무릉 사마가 | 형주 통합 가속 | prelude (형주 통일 직전) | — |
| **13** | **장사 황충** | **노장과 위연** | **★ #4** — 위연 합류 (기존 `WIN_changsha_wei_yan_defects`) | ★ 기존 |
| 14 | 형주 통합 | 첫 영토의 정착 | prelude (익주 진군의 setup) | — |
| 15 | 부수관 | 익주 첫 관문 + 방통 첫 등장 | **cluster prep** (ch16 ★ 의 emotional setup) | — |
| **16** | **낙봉파** | **방통 생존** | **★ #5** — `scout_first ≥ 2` (기존 `WIN_luofeng_pang_tong_lives`) | ★ 기존 |

### 분포 의도

- **★ 간격 리듬**: ch05 → ch08 (3 챕터 간격) → ch10 (2) → ch13 (3) → ch16 (3). 평균 ~2.75 챕터. 사용자가 "다음 ★ 가 곧이다" 를 *느끼되* 정확히 예측할 수 없는 리듬.
- **★ 의 register 다양성**: 백성 evacuation (ch05) / 동맹 결의 (ch08) / 自然 timing (ch10) / 인물 합류 (ch13) / 인물 생존 (ch16). 5 개 모두 **다른 결** — 사용자가 "★ = 항상 인물 살리기" 의 패턴 학습을 못 하게.
- **MVP 후반 weighting**: ★ 5 중 3 개가 ch10+ (적벽 이후). MVP 후반 = "전쟁의 정세가 깊어진다" 시기. 초반 (ch01-04) 은 형제 정체성 정립에 집중, ★ 부담을 늦게 가져옴.
- **비-★ 챕터의 4 역할**:
  - **약속 정립** (ch01) — 도원 motif baseline
  - **prelude** — 다음 ★ 의 emotional / mechanical setup
  - **변곡** (ch04) — 게임 정체성이 약간 바뀌는 transition
  - **cluster prep** (ch15) — 직후 ★ 의 emotional anchor (방통 첫 등장)

각 비-★ 챕터는 default canonical prose 만으로 가치를 가진다 (default 결이 weak 하면 ★ 의 contrast 도 약해진다). 본 plan 은 "default 챕터 = 채워넣기" 라는 함정 거부.

## 4. ★ 5 개 Brief (MVP)

각 brief: **Thematic anchor** / **Trigger 조건 가설** / **Register 분류** / **Cluster impact** (다른 ★ 와의 관계).

### 4.1 ch05 신야 화공 — 백성 evacuation (신규 ★)

**Thematic anchor**: 의로움의 첫 mechanical 증명. 도원에서 "백성을 지킬 자가 된다" 의 맹세가 ch01 에서 *말* 이었다면, ch05 에서 *행동* 으로 시험된다. 신야 화공의 canonical reading 은 "유비가 백성을 버리지 못해 군세를 잃다" — 비극과 도덕의 동전 양면. ★ 는 그 양면을 *둘 다* 지킨 경우: 백성도 군세도.

**Trigger 조건 가설**: 맵 상의 평민 NPC 칸 (3-5 곳, 신야 마을 동남쪽 골목) 이 **전투 종료 시 모두 안전 지대로 evacuate** + WIN. "안전 지대" = 맵 서쪽 column 0-1 의 marked tiles (백성의 피난 경로). 평민 NPC 는 매 턴 자율로 1 칸 서쪽 이동, 적이 인접 시 멈춤. 사용자가 적의 진격을 늦춰 백성 도주 시간을 벌어야 ★.
- **Default WIN**: 적 격퇴 + 평민 일부 (≤2명) 도주 실패 → "다수는 살았으나 일부는 불길 속에"
- **Default LOSS**: 적 격퇴 실패 → "백성도 군세도 모두 화염에"
- **★ WIN**: 적 격퇴 + 평민 전원 evacuate → `WIN_xinye_villagers_all_saved` → Beat 8 의 "한 사람도 남기지 않았다"

**Register**: signature ★. Reserved color reveal. 도원 motif 의 *첫 mechanical 증명*. echo_threshold = 2 (한 번에 어려움, 학습 후 가능).

**Cluster impact**: ch05 ★ trigger → ch08 ★ "trust" hint 가 banter 에 추가 (관우/장비가 ch08 에서 동맹의 무게를 *더 진중하게* 발화). ch08 ★ trigger 조건 자체는 영향 없음 — 결만 강화.

### 4.2 ch08 하구 적의동맹 — 결의의 timing (신규 ★)

**Thematic anchor**: 천하 분기의 *순간* 을 알아본 자만이 trigger 할 수 있는 ★. canonical 적의동맹은 "유비가 흩어졌다 다시 모인 자리에 손권 사신 도착" — 늦지도 빠르지도 않은 timing 의 기적. ★ 는 사용자가 그 timing 을 *전투의 결과 속도* 로 증명한 경우.

**Trigger 조건 가설**: 적 격퇴를 **N 턴 이내** + 격퇴 시 player commander (유비) 의 HP **≥ 75%** + WIN. N 턴은 chapter tuning 으로 (예: 6 턴). "빠른 결단 + 자기 보존" 의 조합 = 손권 사신이 도착했을 때 *흔들리지 않는 모습* 으로 맞이할 수 있는 상태.
- **Default WIN**: 적 격퇴 — turn 또는 HP 조건 미달 → "흩어졌다 다시 모인 자리에 사신이 왔다" (canonical)
- **Default LOSS**: 적 격퇴 실패 → "동맹의 자리에 설 자격을 잃었다"
- **★ WIN**: 빠른 격퇴 + 유비 HP 보존 → `WIN_xiakou_alliance_perfect_timing` → Beat 8 의 "사신이 오기 전에 이미 준비되어 있었다"

**Register**: signature ★. Reserved color reveal. echo_threshold = 2.

**Cluster impact**: ch08 ★ trigger → ch10 적벽 의 동남풍 타이밍 hint 가 prose 에 추가 (제갈량 banter 가 "이번에도 timing 이다" 결). ★ trigger 자체는 ch10 에 독립.

### 4.3 ch10 적벽 — 동남풍 perfect timing (신규 ★)

**Thematic anchor**: 적벽의 canonical 은 "동남풍이 불었다, 불이 강을 건너 위군을 태웠다." ★ 는 그 불이 *강을 다 식히기 전에* 위군 본진을 종결한 경우. 동남풍은 자연 — 사용자가 자연의 timing 을 따라잡았는가의 시험.

**Trigger 조건 가설**: 적 격퇴를 **N 턴 이내** (예: 8 턴 — 동남풍 지속 시간 metaphor) + 격퇴 시 player roster *전원* 생존 + WIN. 동남풍 지속 시간 안에 끝낸다 = 자연의 호의를 낭비하지 않았다.
- **Default WIN**: 적 격퇴 — turn 조건 미달 또는 사상자 있음 → "강이 다 식을 때까지" (canonical, S75 prose)
- **Default LOSS**: 적 격퇴 실패 → "동남풍은 불었으나 우리가 자세를 잡지 못했다"
- **★ WIN**: 빠른 격퇴 + 전원 생존 → `WIN_chibi_perfect_southeast_wind` → Beat 8 의 "동남풍이 다 식기 전에"

**Register**: signature ★. Reserved color reveal. echo_threshold = 2.

**Cluster impact**: ch10 ★ trigger 는 ch11-12 형주 정복 의 banter 에 "적벽의 위엄" 결 추가. ch13 위연 ★ trigger 에 *완화* 영향 (적벽 perfect 의 momentum 으로 장사 황충 의 인정이 더 자연스러움) — 단 trigger 조건 자체는 변경 X.

### 4.4 ch13 장사 — 위연 합류 (기존 ★, reference)

**기존 구현**: `WIN_changsha_wei_yan_defects` (canonical: `WIN_changsha_taken`). echo_threshold = 2. hidden_branch_key = `WIN_hidden`. 본 plan 과 정합 — Principle 1 (scarcity) / 2 (preservation — 위연 합류 시 정사의 비극은 *연기* 됨, 후일 위연의 죽음은 별도 narrative) / 3 (decisive moment — 황충 노장과의 대치 상황). 변경 없음.

**Cluster impact**: ch13 ★ trigger 는 ch14-15 형주/익주 진군의 banter 에 위연 합류 후 register 추가 (cascade_join_prose 기존 wiring 활용). ch16 ★ 와 독립.

### 4.5 ch16 낙봉파 — 방통 생존 (기존 ★, reference)

**기존 구현**: `WIN_luofeng_pang_tong_lives` (canonical: `WIN_luofeng_kongming_arrives`). echo_threshold = 3. hidden_branch_key = `WIN_hidden`. Trigger = `scout_first_turns >= 2` (2 CAVALRY 가 FOREST 칸 2 턴 정찰). 본 plan 과 정합. 변경 없음.

**Cluster impact**: MVP 의 *terminal* ★ — 다른 MVP ★ 와 독립. 단 Full Vision 의 ch17+ (방통 생존 시 諸葛亮 + 龐統 dual-strategist 시기) cascade 의 entry point. MVP 범위 안에서는 standalone.

## 5. Full Vision Tragedy Cluster (ch20-22)

### 5.1 ch20 관우 麥城 — 형주 사수 + 정찰 신뢰

**Thematic anchor**: 三國演義 의 비극 중 가장 무거운 한 자락. 형주 함락 + 관우 패주 + 麥城 의 최후. 사용자가 그 비극을 *알아본 자* 만이 trigger 할 수 있는 ★. canonical 의 실패는 "관우가 정탐 보고를 무시했다" — 자기 무위에 대한 신뢰가 정찰병의 보고보다 컸다. ★ 는 그 신뢰의 자리에 *경청* 을 둔 경우.

**Trigger 조건 가설**: 전투 중 player 가 **CAVALRY 정찰 unit 의 보고 prompt 에 적극 응답** (정찰 정보로 deploy 변경) + 형주 column 0-2 의 hold 칸 N 턴 유지 + WIN. "정찰의 말을 듣는 자" 의 mechanical 증명.
- **Default LOSS** (canonical): 형주 함락 → 관우 麥城 죽음 → "사서가 적은 그대로 그 그림자에 깃들었다"
- **Default WIN** (canonical default): 적 격퇴 — 정찰/hold 조건 미달 → "형주는 잠시 지켰으나 그 그림자는 깊어졌다" (관우 큰 부상, 후일 회복 못 함)
- **★ WIN**: 적 격퇴 + 정찰 신뢰 + 형주 hold → `WIN_fancheng_guan_yu_survives` (signature) → Beat 8 의 "麥城의 그림자가 닿지 못한 자리에"

**Register**: signature ★. echo_threshold = 3 (가장 어려움, 비극 무게 정합).

### 5.2 ch21 장비 巴西 — 부하 자제 + 술 절제

**Thematic anchor**: 형의 비보를 들은 자의 복수가 자기 자리를 잃게 만드는 비극. canonical 의 실패는 "관우의 부음을 들은 장비가 부하 학대 + 음주 + 그 부하들에게 암살" — 비통이 자기 절제를 무너뜨렸다. ★ 는 그 비통 속에서도 *자세* 를 잃지 않은 경우.

**Trigger 조건 가설**: 전투 중 player 가 장비 unit 의 **special action "자제 (自制)" 를 N 턴 이상 active 유지** (special action = HP 회복 stand, 단 ATK -20%) + WIN. 비통을 mechanical penalty (ATK 약화) 로 받아들이고도 이긴 자가 자기 자리를 지킨다.
- **Default LOSS** (canonical): 적 격퇴 실패 또는 장비 사망 → "巴西의 막사에서 더는 빛이 없었다"
- **Default WIN** (canonical default): 적 격퇴 — 자제 미사용 → "장비는 이겼으나 그 분노는 가라앉지 않았다" (canonical 死 시기 단축 prelude)
- **★ WIN**: 적 격퇴 + 자제 유지 → `WIN_zhangfei_survives` (signature) → Beat 8 의 "분노가 자기를 삼키지 않은 첫 밤"

**Register**: signature ★. echo_threshold = 3.

### 5.3 ch22 유비 이릉 — 諫言 채택 + 戰線 자제

**Thematic anchor**: 황제의 복수가 황제의 자리까지 잃게 만드는 비극. canonical 의 실패는 "관우/장비의 부음을 들은 유비가 諸葛亮 諫言 무시 + 이릉 全戰線 進撃 + 火攻 패배 + 백제성 託孤". ★ 는 *복수의 정당성을 인정하되 그 방식을 절제* 한 경우.

**Trigger 조건 가설**: 전투 중 player 가 **諸葛亮 unit 의 "諫言" special action 을 채택** (채택 시 deploy 가 守勢 formation 으로 강제 전환) + 戰線 N 칸 이내 유지 + WIN. "황제의 자리에서 諫言을 받는 자" 의 mechanical 증명.
- **Default LOSS** (canonical): 全戰線 進撃 + 火攻 패배 → "백제성의 託孤"
- **Default WIN** (canonical default): 守勢 미채택으로 적 격퇴 → "이릉을 이겼으나 황제의 자리는 흔들렸다" (canonical 死 시기 연장 prelude, 단 살아남지는 못함)
- **★ WIN**: 諫言 채택 + 戰線 자제 → `WIN_yiling_liu_bei_survives` (signature) → Beat 8 의 "황제의 자리를 지킨 첫 밤"

**Register**: signature ★. echo_threshold = 3.

### 5.4 Cascade-Block Mechanic 명세

**Rule**: 도원 형제 3 ★ 는 mutually-constrained. 사용자는 최대 2 명까지만 살릴 수 있고, *한 자락은 반드시 끊긴다*.

**구체 cascade 규칙**:
- ch20 ★ trigger (관우 생존) → ch21 의 ★ trigger 조건은 그대로지만 ch22 의 ★ trigger 가 **block** (관우가 살았으니 이릉 전투 자체가 다른 trigger 컨텍스트 — "관우 부음" emotional anchor 가 없음, prose 도 다른 결로 흐름)
- ch20 default (관우 死) + ch21 ★ trigger (장비 생존) → ch22 ★ trigger 는 그대로 (관우 부음 + 장비 살아있음 → 유비가 諫言 받기 더 쉬운 조건 — narrative 정합)
- ch20 default + ch21 default + ch22 ★ trigger (유비 생존) → 도원 형제 셋 중 유비만 살아남는 endings — 가장 무거운 "고독한 황제" register

→ 최대 trigger 조합 = 2 명 살림. 3 명 동시 살림 path 는 **존재하지 않음** (mechanical block).

**Architecture impact**:
- `ChapterDefinition` 에 신규 field 필요 — `block_if_prior_signature: PackedStringArray` (예: ch22 의 field = `["WIN_fancheng_guan_yu_survives"]`)
- `HiddenConditionEvaluator` 가 `resolve_branch` 진입 전에 `_persistent_branch_flags` 와 chapter.block_if_prior_signature 교집합 체크 — 비어있지 않으면 hidden_branch_key 라인 disabled (default 라인만 사용)
- 새 condition type 보다 chapter-level field 가 적합 (cascade 는 인접 ★ 관계, evaluator 의 inner condition 이 아닌 outer routing 결정)

**Closure register**: ch01 의 "동월동일에 죽기를 원함" 의 도원 맹세가 ch20-22 의 inverse 로 화답된다. 셋 다 살리지 못한다는 systemic 사실이 결의의 *무게* 를 완성한다. *protected* 가 아닌 *cascade-block* 인 이유: 단순 protected 는 외부 강제 (사용자가 "왜 이건 안 됨?" 의 frustration), cascade-block 은 사용자 선택의 결과 (이미 한 명을 살렸기에 다른 명은 잃는다 — *trade-off* 의 felt experience).

## 6. ch24-25 추가 ★ (Full Vision)

### 6.1 ch24 마속 가정 — 王平 諫言 (independent)

**Thematic anchor**: 諸葛亮 의 신임이 가장 큰 부하의 자만으로 가장 큰 실패가 되는 비극. canonical 의 실패는 "마속이 王平 의 諫言 (산 아래 진영) 을 무시하고 산 위에 진을 친 결과 수원 차단 + 패주". ★ 는 마속이 그 자만을 자제하고 王平 諫言을 채택한 경우 — 諸葛亮 의 신임이 결과로 정당화된다.

**Trigger 조건 가설**: 전투 중 player 가 마속 unit 의 **deploy 를 산 아래 (低地) 칸으로 N 턴 유지** + WIN. 또는 王平 NPC 의 advice prompt 채택 + WIN. 산 위 (高地) deploy 는 ATK +X 보너스 (canonical 의 유혹), 산 아래 deploy 는 보너스 없음 — 사용자가 보너스를 *포기* 하고 諫言을 따른 경우 ★.
- **Default LOSS** (canonical): 산 위 deploy + 수원 차단 → "산이 그를 지키지 못했다"
- **Default WIN** (canonical default): 산 위 deploy + 격퇴 → "마속은 이겼으나 諸葛亮의 신임은 흔들렸다" (canonical 처형은 면했으나 후일 諸葛亮 의 후계 구도 변경)
- **★ WIN**: 산 아래 deploy + 격퇴 → `WIN_jieting_ma_su_listens` (signature) → Beat 8 의 "諸葛亮의 신임이 가장 빛난 첫 자리"

**Register**: signature ★. echo_threshold = 3.

**Cluster impact**: ch20-22 cluster 와 **독립** (마속은 도원 형제와 다른 narrative line). ch25 제갈량 ★ 에는 *완화* 영향 (마속 살렸을 경우 諸葛亮 의 마지막 부담이 가벼워짐 — prose 결만 변경, ★ trigger 자체는 독립).

### 6.2 ch25 제갈량 오장원 — 평안 종결 (salvage register)

**Thematic anchor**: *살리지 못함* 의 ★. canonical 은 "諸葛亮 五丈原 過勞死 — 죽음을 곁에 두고도 마지막 작전을 지휘". ★ 는 그 죽음을 *피할 수 없으나 평안하게* 종결한 경우 — *salvage register*. 비극을 뒤집지 못한 사용자에게도 무게 있는 closure 를 주는, Full Vision 의 narrative climax.

**Trigger 조건 가설**: 전투 중 player 가 諸葛亮 unit 의 **HP 를 N% 이상 유지** + **後事 작전 (별도 special action) 을 N 턴 active 유지** + WIN. 後事 작전 = 諸葛亮 의 action point 를 자기 공격이 아닌 *부하 buff* 로 사용 (자기 보존이 아닌 *후사를 위함*). 죽음을 피하지는 못하지만 마지막 작전이 *완성* 됨.
- **Default LOSS** (canonical): 諸葛亮 過勞 + 後事 미완 → "오장원의 별이 떨어졌다, 그러나 다음 자리가 비어 있었다"
- **Default WIN** (canonical default): 적 격퇴 — 後事 미완 → "諸葛亮은 그날 밤에 갔다, 後事는 흩어졌다" (canonical 결)
- **★ WIN (salvage)**: 적 격퇴 + 後事 완성 + 諸葛亮 HP 보존 → `WIN_wuzhang_kongming_peaceful_rest` (signature) → Beat 8 의 "오장원의 별이 떨어졌으나 다음 자리는 비어 있지 않았다"

**Register**: signature ★ — **salvage register**. Reserved color reveal, 그러나 색조는 *주홍 + 금색* 의 mute 한 variant (Marked Hand 의 정점 — *"운명을 다시 쓰는 자도 모든 것을 다시 쓰지는 못한다"*). echo_threshold = 3.

**Cluster impact**: ch25 ★ 는 게임 전체의 *terminal* ★. 다른 ★ 와 mechanically 독립. 단 직전 ★ trigger history (마속 살림 / 도원 형제 살림 횟수) 에 따라 Beat 8 prose 의 *결* 이 variant — 사용자가 살린 인물 수가 많을수록 後事 가 더 풍부한 register 로 표현됨 (살린 인물들이 諸葛亮의 후사를 잇는다는 reading).

**Salvage register 의 design rationale**: ch25 가 단순 "★ 못 trigger 시 비극" 이면 사용자가 마지막 챕터에서 좌절감만 가지고 game over. Salvage variant 는 *모든 사용자가* 어떤 형태의 closure 를 받음 — full save 한 사용자는 fullest variant, default-only 사용자도 dignified variant. Pillar 4 (삼국지의 숨결) 의 *마지막 약속*: 어떤 history 든 그 무게는 sourced.

## 7. Decisive-Moment Signaling

★ 챕터에서 사용자가 "이 챕터는 다르다" 를 알게 하는 signaling 채널 4 개. 모두 *미세* — explicit 한 "★ 있음" 알림 금지 (Principle 3).

**Channel A — Beat 1/3 prose 의 sensory anchor**: ★ 챕터의 prose 는 default 보다 1-2 line 더 dense 한 sensory detail (특정 냄새 / 빛 / 소리 anchor). 예: ch05 "매캐한 풀냄새와 마른 짚의 사각거림", ch10 "동남쪽 바람의 온도", ch16 "낙봉의 능선에 흐르는 안개". 사용자가 의식하지 않아도 register 가 바뀐다.

**Channel B — Hero banter 의 unusual emotional register**: ★ 챕터의 battle_start banter 는 default register 와 미세하게 다른 결 — 평소보다 *진중* 하거나 *예감* 의 ground note. 예: ch05 의 유비가 "이번엔 백성을 두고 가지 않는다" (도원 의 echo), ch10 의 諸葛亮 이 "바람의 시간이다" (chapter-by-chapter banter override schema 활용).

**Channel C — BGM 의 미세 variation**: 5-theme music palette (`design/audio/music-themes.md`) 안에서 ★ 챕터는 base theme 유지하되 intro 의 instrumentation 미세 변화 (예: solo strings 1 layer 추가) — `sound_manager.gd` 수준의 variant flag. 사용자가 "BGM 이 평소와 다르다" 를 의식하지 않게 *결의 다름* 만 felt.

**Channel D — UI subtle treatment (optional, V2)**: HUD 의 panel border 가 1px ink density 미세 변화. MVP V1 에서 skip 가능, V2 에서 추가. Reduce-Motion 모드에서는 channel A-C 만으로 충분.

**Anti-pattern**: "이 챕터는 운명 분기가 있습니다" UI / "운명 archive 진척도 N/5" badge / chapter select 의 ★ 표시. 이 모두 *discovery* 의 묘미 파괴. `signature_archive_popup.gd` 는 *trigger 된 ★ 의 collection view* 로만 작동 — pre-trigger 의 affordance 가 아닌 *post-trigger 의 trophy*.

## 8. ch01 Redefinition

ch01 = **분기 없음 + 약속의 무게** 챕터. 별도 quick-spec (`design/quick-specs/ch01-vertical-slice-uplift.md`) 가 본 절을 anchor 로 implementation detail 을 담당.

본 plan 의 ch01 의 3 의무:
1. **Lore 정합**: 현재 ch01 enemy_roster 의 위(魏) 4 장수 → 황건적 4 인 으로 교체. 중평 원년 황건적의 난 시기에 정합. ch01 의 "삼국지의 숨결" pillar 첫 felt.
2. **긴장감 mechanical**: `enemy_atk_mult` 0.7 → 0.95, chokepoint 보강, optional 7-turn turn-limit. 첫판부터 "한 수가 무겁다" 느낌. relaxed tutorial 거부.
3. **Beat 8 의 ch05 seed**: default WIN prose 마지막 sentence 에 "이 형제의 칼이 백성을 지킬 날이 — 그들은 아직 알지 못했다" 류의 ch05 ★ foreshadow 1 sentence. 사용자가 ch01→ch05 사이를 plays 하면서 그 sentence 가 *기억 되었다* 의 callback.

ch01 = priming-null 유지 (`destiny-branch.md` CR-13 architecture 정합). ★ 또는 reserved-color-eliciting branch 추가 거부.

## 9. New Mechanics Required (architecture gap analysis)

본 plan 이 트리거하는 architecture 변경 4 개:

| Gap | Scope | ADR 필요? |
|-----|-------|-----------|
| `ChapterDefinition.block_if_prior_signature: PackedStringArray` field 추가 — cascade-block routing (§5.4) | Full Vision ch22 | ADR amendment to ADR-0017 ChapterDefinition schema |
| `HiddenConditionEvaluator` 신규 condition types: `civilian_evacuation_complete` (ch05) / `turn_limit_and_hp_threshold` (ch08/10) / `scout_trust_count` (ch20) / `restraint_action_duration` (ch21) / `advisor_acceptance` (ch22/24) / `late_game_resource_save` (ch25 後事) | MVP ch05/08/10 + Full Vision ch20-25 | ADR amendment to ADR-0009 or 0018 (HiddenConditionEvaluator scope) |
| Civilian NPC entity (ch05 ★ trigger 의 core) — 새 unit type (`Side.CIVILIAN`), 자율 이동 + 적 인접 시 정지 + evacuate-zone 도달 판정 | MVP ch05 only | 신규 ADR (Civilian NPC system) |
| Signaling channel B (banter chapter override 활용) + C (`sound_manager` BGM variant flag) implementation surface | MVP ch05/08/10/13/16 | ADR 불필요 (기존 systems 활용) |

**Risk**: Civilian NPC entity 가 가장 무거운 architecture lift. ch05 ★ trigger 의 핵심이지만, 단 ch05 에만 사용되는 system 은 ROI 가 낮을 수 있음. 대안 — civilian 을 *map terrain feature* 로 (이동 안 함, 단 적 도달 시 turn-end 카운터 증가) 단순화. ch05 spec 작성 시 결정.

## 10. Out of Scope (explicit)

본 plan 은 다음 챕터를 **명시적으로 default-only** 로 declare — ★ 추가 거부:

- **MVP (default-only)**: ch01, ch02, ch03, ch04, ch06, ch07, ch09, ch11, ch12, ch14, ch15 — 11 챕터
- **Full Vision (default-only)**: ch17, ch18, ch19, ch23 — 4 챕터

→ 25 챕터 중 15 챕터 default-only (60%). ★ 8 (32%). Salvage ★ 1 (ch25, 8%).

이 default-only 챕터들은 *비어있는* 챕터가 아닌 *prelude / 변곡 / cluster prep* 역할을 함 (§3 참조). 각 챕터의 canonical Beat 8 prose 의 결이 weak 하면 다음 ★ 의 contrast 도 약해진다 — default prose 의 무게 보존이 의무.

미래 변경 요청 (예: "ch07 장판교 호통 의 장비 banter ★ 를 추가하자") 은 Principle 1 의 design test 를 통과해야 — narrative anchor + 인접 ★ 와 register 차별성 명시.

## 11. Implementation Order

| # | Step | Scope | 의존 | 추정 |
|---|------|-------|------|------|
| 1 | 본 plan 확정 + `production/milestones/mvp-demo-16ch.md` 에 "Branch Distribution Anchor" 절 추가 (본 doc 참조 + ★ 5 enumeration) | doc only | — | 0.5 세션 |
| 2 | **ch01 vertical-slice uplift** — 별도 quick-spec → 황건적 roster + 긴장감 tuning + Beat 8 ch05 seed | code + data | step 1 | 2-3 세션 |
| 3 | **ch05 신야 화공 ★ design + implement** — Civilian NPC system ADR + HiddenConditionEvaluator extension + ★ prose + banter override | code + data + ADR | step 2 | 4-6 세션 |
| 4 | **ch08 적의동맹 ★ design + implement** — turn-limit + HP threshold trigger + ★ prose + banter override | code + data | step 3 (HiddenConditionEvaluator 확장 재사용) | 2-3 세션 |
| 5 | **ch10 적벽 ★ design + implement** — turn-limit + roster-survival trigger + ★ prose + banter override | code + data | step 4 | 2-3 세션 |
| 6 | (ship 이후) **ch20-22 cluster + cascade-block** — ChapterDefinition schema extension ADR + scout/restraint/advisor condition types + ★ prose ×3 + cluster integration test | code + data + ADR | MVP ship 후 | 8-10 세션 |
| 7 | (ship 이후) **ch24-25 ★** — 王平 advisor + 後事 special action + salvage register prose | code + data | step 6 | 4-6 세션 |

**Critical path (MVP ship 안)**: step 1 → 2 → 3 → 4 → 5. 총 ~11-16 세션 (현재 S19 Ship 상태에서 분기 design 본격 진입 시 1-2 sprint 정도).

**S19 Ship 영향**: 본 plan 의 step 1-2 (ch01 vertical-slice) 는 MVP demo ship 안에 포함될 수 있음 (S19-D 사용자 windowed playthrough 시 ch01 이 felt 다르게). step 3-5 (ch05/08/10 ★) 는 MVP ship 후 별도 milestone. 결정은 사용자가 ship 일정과 trade-off.

---

> **Authoring note**: per `.claude/rules/design-docs.md`, this skeleton was written first; each section is filled one at a time with user approval, written immediately upon approval. All 11 sections complete.
