# North Star — 천명역전 (Defying Destiny)

> **Lighthouse document**. Loaded into every session via `CLAUDE.md`.
> 모든 design 결정, code 변경, agent 작업의 기준점. 흔들릴 때 여기로 돌아온다.
> 상세 GDD: `design/gdd/game-concept.md` (339 lines). 본 문서는 그 정수만 추출.

---

## 🎮 게임 정체성 (한 문장)

**삼국지연의의 비극적 운명을 전략으로 뒤집는 그리드 기반 턴제 전술 RPG (SRPG).**

> "내가 거기 있었다면 관우를 살릴 수 있었을 텐데" — 그 기회를 주는 게임.

| Aspect | Detail |
|--------|--------|
| Genre | Turn-based Tactical RPG (SRPG) — KOEI 영걸전 정신적 계승작 |
| Platform | PC (Steam) + Mobile, single-player, Premium |
| Engine | Godot 4.6 / GDScript |
| Session | 30분-2시간, 12-18개월 솔로 개발 (Full Vision) |
| Reference | KOEI 영걸전 + Fire Emblem + Triangle Strategy + Into the Breach |

---

## 🏛️ 4 Pillar — 양보 불가

1. **형세의 전술 (Tactics of Formation)** — 개별 능력치보다 진형과 위치의 우위. 레벨 99 여포도 포위당하면 위험.
2. **운명은 바꿀 수 있다 (Destiny Can Be Rewritten)** — 비극이 디폴트, 치밀한 전략가만 거스를 수 있음. 분기 조건은 **숨겨져 있고 어렵다**.
3. **모든 무장에게 자리가 있다 (Every Hero Has a Role)** — 만능 캐릭터 없음. 역할 차별화 필수.
4. **삼국지의 숨결 (Spirit of Three Kingdoms)** — 전투는 역사 맥락 속에 존재. 스토리 이벤트가 의미를 부여.

---

## 🚫 Anti-Pillars — 이 게임이 **아닌** 것

- **NOT 가챠/캐릭터 수집** — "수집"이 아니라 "운용". 무장은 시나리오 따라 자연스럽게 합류.
- **NOT 실시간 전투** — 턴제의 "생각할 시간"이 핵심. 실시간 요소는 형세 읽기 깊이를 파괴.
- **NOT 오픈월드/샌드박스** — 시나리오 기반 선형 진행. 자유도는 전투 내 전략과 운명 분기에서.
- **NOT 밸런스 붕괴 허용** — "강캐 키워서 무쌍"은 적. 모든 무장이 가치 있는 밸런스가 필수.

---

## 🎯 현재 Ship Target — MVP Demo (ch01-16)

**Anchor**: `production/milestones/mvp-demo-16ch.md`

- ch01 (도원결의·황건적) → ch16 (낙봉파·방통 생존) **16 챕터 windowed-attested**
- 5대 ★ 시그니처 destiny branch 중 첫 번째 = **ch16 방통 생존** (`scout_first ≥ 2`)
- 입증 목표: **"player 의 선택이 史記를 바꾼다"** 의 demo 단계 작동
- 현재 상태: **MVP 5/5 ★ SHIP-READY mechanical 유지** (1996/1996 tests PASS, S87 기준)

**Out of scope for this ship**: ch17-25 / 5대 ★ 중 #2-#5 (관우·장비·유비·마속·제갈량) / Phase 4 hero attack frames / CombatResolver 추출 / Multi-step survival cascade.

---

## 🔥 사용자 raw feedback — 정직히 기록 (외면 금지)

S86 manual playtest 에서 사용자가 직접 던진 단어들. **이게 게임의 약점이다.**

1. **"전반적으로 난이도가 너무 낮음"** → atk_mult 0.55-0.80 → 0.95 → 1.15 → **1.50** (S88). 추가 verify 필요.
2. **"공격수단 평타뿐"** → S86 까지 14 skill 중 다수 unwired. S86-S87 에서 14/14 wire + S 키 routing fix (G-32 codify).
3. **"재미없음"** (raw) → root cause = layered UX gap (mechanical + discoverability + visual feedback). 단일 layer fix 로 해소 불가.
4. **"S 키 눌러도 차이 없음"** → InputRouter `_did_visible_work` gate silent drop. 3차 진단 끝에 fix (S86) + G-32 codify (S87).
5. **Visual feedback 부족** → "damage popup 만 보이고 skill 특별감 0" → S87 particle wave 14/14 완성.

**원칙**: 사용자 raw feedback 은 hypothesis 보다 우선. console log 의 정확한 telemetry > developer 추론.

---

## 📐 Design Test — 의사결정 시 참조

새 기능 / 변경 제안이 들어왔을 때 다음 질문에 답해 본다:

1. **Pillar 1 test**: "강력한 무장 한 명을 더 강하게 할까, 진형 시스템을 더 깊게 할까?" → **진형 시스템을 깊게 한다.**
2. **Pillar 2 test**: "운명 분기 조건을 쉽게 달성 가능하게 할까, 어렵지만 가능하게 할까?" → **어렵지만 가능하게 한다.** 쉬우면 드라마가 없다.
3. **Pillar 3 test**: "인기 무장에게 특별한 강화를 줄까, 모든 무장의 역할 차별화를 강화할까?" → **역할 차별화를 강화한다.**
4. **Pillar 4 test**: "전투 수를 늘릴까, 전투 사이의 스토리 이벤트를 풍부하게 할까?" → **스토리 이벤트를 풍부하게 한다.**
5. **Anti-pillar test**: 제안이 anti-pillar 4개 중 하나라도 위반하면 → **reject 또는 redesign.**

---

## 🧭 Collaboration anchor

- **Mode**: Build, not Ratify (per `WORKFLOW.md`) — sprint/gate/retro machinery dormant
- **Protocol**: Question → Options → Decision → Draft → Approval (per `CLAUDE.md`)
- **Session state**: `production/session-state/active.md` (ephemeral, gitignored)
- **Milestone anchor**: `production/milestones/mvp-demo-16ch.md`

---

*Last updated: 2026-05-25 (S87 close). 변경은 사용자 명시적 결정 후에만.*
