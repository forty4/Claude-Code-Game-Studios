# Game Concept: 천명역전 (Defying Destiny)

*Created: 2026-04-16*
*Status: Draft*

---

## Elevator Pitch

> 삼국지연의의 비극적 운명들 — 관우의 죽음, 장비의 최후, 제갈량의 한 — 을 전략으로
> 뒤집는 그리드 기반 턴제 전술 RPG. 치밀하게 진형을 짜고 전장을 지배하면,
> 역사가 바뀌고, 바뀐 역사는 이후 모든 것에 연쇄적 영향을 준다.

---

## Core Identity

| Aspect | Detail |
| ---- | ---- |
| **Genre** | Turn-based Tactical RPG (SRPG) |
| **Platform** | Cross-platform (PC + Mobile, 추후 확장) |
| **Target Audience** | 전략 게임 숙련자, 삼국지 팬, 클래식 SRPG 팬 (상세: Player Profile 참조) |
| **Player Count** | Single-player |
| **Session Length** | 30분 ~ 2시간 |
| **Monetization** | Premium (미정) |
| **Estimated Scope** | Large (12-18개월, 솔로 — Full Vision 기준) |
| **Comparable Titles** | KOEI 영걸전, Fire Emblem, Triangle Strategy, Into the Breach |

---

## Core Fantasy

삼국지연의를 읽으며 "내가 거기 있었다면 관우를 살릴 수 있었을 텐데"라고 상상한
적이 있다면 — 이 게임이 그 기회를 준다.

플레이어는 촉한의 군사(軍師)가 되어 전장을 지휘한다. 진형을 짜고, 지형을 읽고,
형세의 우위를 만들어 전투를 이끈다. 역사의 비극적 결말은 디폴트이지만, 충분히
치밀한 전략가라면 운명을 거스를 수 있다. 바뀐 역사는 이후 시나리오 전체에 연쇄적
영향을 미치며, 매 회차마다 다른 삼국지가 펼쳐진다.

**핵심 감정**: "내 전략이 역사를 바꿨다"는 전략적 성취감 + 삼국지 영웅들의
운명을 내 손으로 바꾸는 감정적 몰입.

---

## Unique Hook

KOEI 영걸전처럼 삼국지연의의 전장을 턴제 전술로 체험하면서, **AND ALSO**
"운명 분기 시스템"으로 숨겨진 조건을 충족하면 역사의 비극을 뒤집을 수 있고,
바뀐 역사가 이후 시나리오 전체에 연쇄적으로 영향을 미친다.

---

## Player Experience Analysis (MDA Framework)

### Target Aesthetics (What the player FEELS)

| Aesthetic | Priority | How We Deliver It |
| ---- | ---- | ---- |
| **Sensation** (sensory pleasure) | 6 | 전투 연출, 진형 완성 시 시각적 피드백 |
| **Fantasy** (make-believe, role-playing) | 2 | 촉한의 군사가 되어 영웅들을 지휘하는 역할 |
| **Narrative** (drama, story arc) | 3 | 삼국지연의의 드라마 + 운명 분기의 연쇄 변화 |
| **Challenge** (obstacle course, mastery) | 1 | 진형 전술의 깊이, 숨겨진 분기 조건 달성의 어려움 |
| **Fellowship** (social connection) | N/A | 싱글 플레이어 게임 |
| **Discovery** (exploration, secrets) | 4 | 완전 숨겨진 운명 분기 조건의 발견, 회차별 새로운 시나리오 |
| **Expression** (self-expression, creativity) | 5 | 자유로운 진형 구성, 나만의 전략으로 역사 개변 |
| **Submission** (relaxation, comfort zone) | N/A | 도전적인 게임 — 이완 목적이 아님 |

### Key Dynamics (Emergent player behaviors)

- 플레이어가 자연스럽게 "이 전투에서 다르게 하면 역사가 바뀔까?" 추측하기 시작
- 지형과 진형의 조합을 실험하며 최적의 전술을 탐구
- 1회차 실패를 바탕으로 2회차에서 전략을 수정하며 메타 지식 축적
- 커뮤니티에서 숨겨진 분기 조건을 공유하고 토론

### Core Mechanics (Systems we build)

1. **그리드 기반 턴제 전투**: 지형 효과 + 진형 보너스 + 측면/후방 공격 보너스
2. **운명 분기 시스템**: 숨겨진 조건 판정 → 역사 변경 → 이후 시나리오 연쇄 영향
3. **무장 역할 시스템**: 병종별 뚜렷한 역할 차별화, 상성 관계
4. **시나리오 진행 시스템**: 삼국지연의 기반 선형 진행 + 운명 분기에 따른 변화
5. **전투 준비 시스템**: 무장 편성, 배치, 장비 배분

---

## Player Motivation Profile

### Primary Psychological Needs Served

| Need | How This Game Satisfies It | Strength |
| ---- | ---- | ---- |
| **Autonomy** (freedom, meaningful choice) | 자유로운 진형 구성, 다양한 전략 접근법, 운명 분기를 통한 역사 개변 | Core |
| **Competence** (mastery, skill growth) | 회차마다 더 나은 전략으로 이전에 불가능했던 것을 달성. 숨겨진 조건 발견 = 실력 증명 | Core |
| **Relatedness** (connection, belonging) | 삼국지 영웅들과의 감정적 유대. "관우를 살리고 싶다"는 감정이 전략적 동기가 됨 | Supporting |

### Player Type Appeal (Bartle Taxonomy)

- [x] **Achievers** (goal completion, collection, progression) — 운명 분기 100% 달성, 완벽 클리어, 모든 영웅 생존 도전
- [x] **Explorers** (discovery, understanding systems, finding secrets) — 숨겨진 분기 조건 탐구, 전술 조합 실험, "이렇게 하면 어떻게 될까?"
- [ ] **Socializers** (relationships, cooperation, community) — 싱글 플레이어 (커뮤니티 토론은 게임 외부에서 발생)
- [ ] **Killers/Competitors** (domination, PvP, leaderboards) — PvP 없음 (자기 자신과의 경쟁만 존재)

### Flow State Design

- **Onboarding curve**: 첫 1-2 전투는 삼국지연의 초반의 간단한 전투로, 이동/공격/지형 기본을 자연스럽게 학습. 진형 보너스는 3번째 전투에서 소개.
- **Difficulty scaling**: 시나리오 진행에 따라 적의 AI와 진형이 점점 정교해짐. 무장 수가 늘어나며 전략 옵션도 증가.
- **Feedback clarity**: 진형 보너스/지형 효과가 수치로 명확히 표시. 운명 분기 결과는 드라마틱한 스토리 이벤트로 표현.
- **Recovery from failure**: 전투 재시도 가능 (영걸전 방식). 실패는 교육적 — "이번에는 왜 졌는지" 분석 후 재도전.

---

## Core Loop

### Moment-to-Moment (30 seconds)

전장 전체를 읽는다. 지형, 적 배치, 아군 진형을 확인하고 — 유닛을 움직여 진형의
흐름을 만든다. 언덕 위의 궁병, 다리목을 막는 보병, 측면을 노리는 기병. 개별
유닛의 한 방이 아니라, 여러 유닛이 만드는 형세(形勢)의 우위가 승패를 결정한다.

한 턴의 배치가 3-4턴 뒤에 결실을 맺는 "씨앗 뿌리기" 느낌. 장기판의 흐름.

### Short-Term (5-15 minutes)

하나의 전투는 3개의 국면으로 흐른다:
1. **배치 (Opening)**: 초기 진형 설정. 지형 읽기. 전략 수립.
2. **전개 (Midgame)**: 진형 충돌. 적의 대응에 맞춰 계획 수정. 계책 발동 타이밍.
3. **결전 (Endgame)**: 승기를 잡거나 역전당하거나. 숨겨진 운명 조건이 이 시점에서 판정.

"한 턴만 더" 심리: 기병대가 측면에 도달하면 포위가 완성된다 → 전술적 계획이
점점 완성되어가는 긴장감.

### Session-Level (30-120 minutes)

한 세션은 2-4개 장(章)을 진행:

```
[스토리 이벤트] → [전투 준비/편성] → [전투] → [전투 결과/운명 판정] → [다음 장]
```

- **스토리 이벤트**: 삼국지연의의 드라마틱한 장면. 운명 분기의 단서가 숨어있을 수 있음.
- **전투 준비**: 무장 편성, 장비 배분, 진형 선택.
- **전투**: 코어 전술 플레이.
- **운명 판정**: 숨겨진 조건이 체크됨. 관우가 살거나, 역사대로 죽거나.

자연스러운 중단점: 장과 장 사이. 복귀 동기: "이번엔 관우를 살릴 수 있을지도..."

### Long-Term Progression

- **캐릭터 성장**: 전투 경험을 통한 무장 레벨업 및 능력 강화
- **운명 분기 발견**: 회차마다 새로운 분기 조건을 발견하고 달성
- **시나리오 확장**: 바뀐 역사에 따른 새로운 전투와 이벤트
- **완벽한 플레이 도전**: 모든 영웅 생존 + 모든 운명 역전의 궁극적 목표

| 회차 | 플레이어 상태 | 경험 |
|---|---|---|
| 1회차 | 역사를 모르고 플레이 | 역사대로 흘러감. 비극적이지만 드라마틱 |
| 2회차 | "바꿀 수 있다는 걸 안다" | 시행착오. 일부 성공, 일부 실패. 패턴 파악 |
| 3회차+ | 메타 지식 축적 | 숨겨진 조건을 하나씩 풀어감. 완벽한 플레이 도전 |

### Retention Hooks

- **Curiosity**: "2장에서 다르게 하면 어떻게 될까?" 숨겨진 분기 조건 탐구
- **Investment**: 시나리오 진행도, 발견한 분기 조건에 대한 메타 지식
- **Social**: 커뮤니티에서 분기 조건 추측과 공유 (게임 외부)
- **Mastery**: 더 효율적인 전술, 더 어려운 분기 조건 달성, 최소 턴 클리어

---

## Game Pillars

### Pillar 1: 형세의 전술 (Tactics of Formation)

개별 유닛의 능력치가 아니라, 진형과 위치의 우위가 승패를 결정한다. 레벨 99
여포도 포위당하면 위험하고, 레벨 1 병사도 좋은 위치에서는 가치가 있다.

*Design test*: "강력한 무장 한 명을 더 강하게 할까, 진형 시스템을 더 깊게 할까?"
→ **진형 시스템을 깊게 한다.**

### Pillar 2: 운명은 바꿀 수 있다 (Destiny Can Be Rewritten)

역사의 비극적 결말은 디폴트이지, 불가피하지 않다. 충분히 치밀한 전략가라면
역사를 거스를 수 있고, 바뀐 역사는 이후 모든 것에 연쇄적 영향을 준다.

*Design test*: "운명 분기 조건을 쉽게 달성 가능하게 할까, 어렵지만 가능하게 할까?"
→ **어렵지만 가능하게 한다.** 쉬우면 드라마가 없다.

### Pillar 3: 모든 무장에게 자리가 있다 (Every Hero Has a Role)

특정 "만능 캐릭터"가 게임을 독식하지 않는다. 무장마다 뚜렷한 역할이 있고,
상황과 지형에 따라 최적의 선택이 달라진다.

*Design test*: "인기 무장에게 특별한 강화를 줄까, 모든 무장의 역할 차별화를 강화할까?"
→ **역할 차별화를 강화한다.**

### Pillar 4: 삼국지의 숨결 (The Spirit of Three Kingdoms)

전투는 역사의 맥락 속에 존재한다. 전투 전후의 스토리, 무장 간 대화, 역사적
이벤트가 전투에 의미를 부여한다.

*Design test*: "전투 수를 늘릴까, 전투 사이의 스토리 이벤트를 풍부하게 할까?"
→ **스토리 이벤트를 풍부하게 한다.**

### Anti-Pillars (What This Game Is NOT)

- **NOT 캐릭터 수집 게임**: 무장 "수집"이 아니라 "운용"이 핵심. 가챠형 수집 메카닉 없음. 시나리오에 따라 자연스럽게 합류.
- **NOT 실시간 전투**: 턴제의 "생각할 시간"이 핵심. 실시간 요소는 형세 읽기의 깊이를 파괴.
- **NOT 오픈월드/샌드박스**: 시나리오 기반 선형 진행이 기본. 자유도는 전투 내 전략과 운명 분기에서 제공.
- **NOT 밸런스 붕괴 허용**: "강캐 키워서 무쌍"은 이 게임의 적. 모든 무장이 가치 있는 밸런스가 필수.

---

## Visual Identity Anchor

> *AD-CONCEPT-VISUAL skipped — Lean mode. Visual identity to be defined via `/art-bible`.*

비주얼 아이덴티티는 `/art-bible` 실행 시 확정됩니다. 프로토타입 단계에서는
플레이스홀더 아트를 사용합니다.

---

## Inspiration and References

| Reference | What We Take From It | What We Do Differently | Why It Matters |
| ---- | ---- | ---- | ---- |
| KOEI 영걸전 | 삼국지 시나리오 기반 전술 RPG, 숨겨진 분기의 쾌감 | 현대적 밸런스, 진형 시스템 깊이 강화, 분기의 연쇄 영향 | 직접적 정신적 계승작 |
| Fire Emblem | 그리드 전술 RPG의 현대적 표준, 캐릭터 중심 서사 | 무장 간 상성 대신 진형/지형 기반 전투, 역사 시나리오 | 장르 메카닉의 현대적 레퍼런스 |
| Triangle Strategy | 지형 활용 전술 + 분기 스토리 | 분기 조건이 숨겨져 있음 (투표가 아님), 역사 기반 | 분기 + 전술의 조합 검증 |
| Into the Breach | 포지셔닝이 전부인 전술 게임의 정수 | 캐릭터 서사와 역사적 맥락 추가 | 진형 중심 전술의 재미 검증 |

**Non-game inspirations**:
- 삼국지연의 (나관중): 원작의 드라마, 캐릭터 관계, 역사적 사건 구조
- 요코야마 미츠테루의 삼국지: 전략과 지략 중심의 서사 해석
- 장기/바둑: 형세(形勢)와 포석의 개념 — 개별 수보다 전체 흐름의 우위

---

## Target Player Profile

| Attribute | Detail |
| ---- | ---- |
| **Age range** | 25-45 |
| **Gaming experience** | Mid-core ~ Hardcore (전략 게임 경험자) |
| **Time availability** | 세션당 30분-2시간. 회차 플레이를 위한 장기적 투자 의지 |
| **Platform preference** | PC (Steam) 우선, 모바일 보조 |
| **Current games they play** | Fire Emblem, Civilization, Total War, 삼국지 시리즈, XCOM |
| **What they're looking for** | 영걸전의 향수 + 현대적 전술 깊이 + 발견의 쾌감 |
| **What would turn them away** | 밸런스 붕괴, 과도한 그라인딩, 오토 전투, P2W 요소 |

---

## Technical Considerations

| Consideration | Assessment |
| ---- | ---- |
| **Recommended Engine** | 미정 — `/setup-engine` 실행 후 확정 |
| **Key Technical Challenges** | 운명 분기 상태 관리 (분기 조합 폭발), 진형 보너스 계산, AI 진형 전술 |
| **Art Style** | 미정 — `/art-bible` 실행 후 확정. 프로토타입은 플레이스홀더 |
| **Art Pipeline Complexity** | Medium (2D 기반 예상) |
| **Audio Needs** | Moderate (삼국지 분위기 BGM, 전투 효과음) |
| **Networking** | None (싱글 플레이어) |
| **Content Volume** | Full Vision: 전투 40-50개, 무장 80-100명, 운명 분기 15-20개 |
| **Procedural Systems** | 없음 — 모든 전투와 시나리오는 핸드크래프트 |

---

## Risks and Open Questions

### Design Risks
- 운명 분기 조건이 "완전 숨김"일 때 플레이어가 좌절하고 포기할 수 있음 (HIGH)
- 진형 시스템의 깊이가 충분하지 않으면 전투가 단순해질 수 있음 (MEDIUM)
- "모든 무장에게 자리가 있다" 필라 실현을 위한 밸런싱 난이도 (HIGH)

### Technical Risks
- 분기에 따른 시나리오 상태 관리 복잡도 (MEDIUM)
- 크로스 플랫폼 지원 시 UI/UX 분리 필요 (MEDIUM)
- AI가 진형 전술을 의미 있게 활용하도록 만드는 난이도 (MEDIUM)

### Market Risks
- 삼국지 테마의 인디 게임이 글로벌 시장에서 주목받을 수 있는가 (MEDIUM)
- 영걸전 팬층의 고령화 — 신규 유입 동력 확보 필요 (MEDIUM)

### Scope Risks
- 운명 분기마다 별도 스토리/대화/맵이 필요해 콘텐츠 양 폭발 가능 (HIGH)
- Full Vision의 무장 80-100명 밸런싱 공수 (HIGH)

### Open Questions
- 운명 분기 조건의 적정 난이도는? → MVP에서 1-2개 분기로 프로토타입 테스트
- 진형 보너스의 최적 수치 범위는? → 프로토타입에서 밸런스 테스트
- 바뀐 역사의 연쇄 영향 범위를 어디까지 할 것인가? → Vertical Slice에서 결정
- 모바일 터치 UI로 진형 배치가 편한가? → 프로토타입에서 UX 테스트

---

## MVP Definition

**Core hypothesis**: "진형 기반 턴제 전투에서 숨겨진 운명 분기 조건을 발견하는
경험이 회차 플레이를 유발할 만큼 재미있는가?"

**Required for MVP**:
1. 그리드 기반 턴제 전투 시스템 (지형 효과, 진형 보너스, 측면/후방 보너스)
2. 3-5개 전투 맵으로 구성된 미니 시나리오 (촉한 초반부)
3. 8-10명의 무장 (역할 차별화 검증)
4. 1-2개 숨겨진 운명 분기 (핵심 메카닉 검증)
5. 최소한의 스토리 이벤트 (전투에 맥락 부여)
6. AI가 기본적 진형 전술을 사용

**Explicitly NOT in MVP** (defer to later):
- 레벨업/성장 시스템
- 장비/아이템 시스템
- 다수의 시나리오 (촉한 전체)
- 사운드/음악
- 완성된 아트
- 모바일 UI

### Scope Tiers (if budget/time shrinks)

| Tier | Content | Features | Timeline |
| ---- | ---- | ---- | ---- |
| **MVP** | 전투 3-5개, 무장 8-10명, 분기 1-2개 | 코어 전투 + 운명 분기 | 3-4주 (솔로) |
| **Vertical Slice** | 촉한 1장 (전투 8-12개), 무장 15-20명, 분기 3-5개 | 전투 + 스토리 + 성장 | 2-3개월 (솔로) |
| **Alpha** | 촉한 전체, 무장 40-50명, 분기 8-10개 | 모든 시스템, 러프 아트 | 6-9개월 (솔로) |
| **Full Vision** | 촉한 + 위/오, 무장 80-100명, 분기 15-20개 | 전체 완성, 폴리시 | 12-18개월 (솔로) |

---

## Next Steps

- [ ] Configure engine with `/setup-engine`
- [ ] Define visual identity with `/art-bible`
- [ ] Validate concept with `/design-review design/gdd/game-concept.md`
- [ ] Decompose into systems with `/map-systems`
- [ ] Author per-system GDDs with `/design-system`
- [ ] Create architecture with `/create-architecture`
- [ ] Record architectural decisions with `/architecture-decision`
- [ ] Validate readiness with `/gate-check`
- [ ] Prototype core loop with `/prototype`
- [ ] Validate with playtest `/playtest-report`
- [ ] Plan first sprint with `/sprint-plan new`
