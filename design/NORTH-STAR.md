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

## 🏛️ 5 Pillar — 양보 불가

1. **형세의 전술 (Tactics of Formation)** — 개별 능력치보다 진형과 위치의 우위. 레벨 99 여포도 포위당하면 위험.
2. **운명은 바꿀 수 있다 (Destiny Can Be Rewritten)** — 비극이 디폴트, 치밀한 전략가만 거스를 수 있음. 분기 조건은 **숨겨져 있고 어렵다**.
3. **모든 무장에게 자리가 있다 (Every Hero Has a Role)** — 만능 캐릭터 없음. 역할 차별화 필수.
4. **삼국지의 숨결 (Spirit of Three Kingdoms)** — 전투는 역사 맥락 속에 존재. 스토리 이벤트가 의미를 부여.
5. **전략적 조합 (Strategic Combinations)** — 매 turn 의 결정 단위는 **단일 action 이 아닌 chain**: (이동 → 행동) × (아이템 / 책략권 / cross-hero 지원). KOEI 영걸전의 핵심 재미 — "이번 turn 에 누구를 누구로 어떻게 도울지" — 의 **조합 puzzle**. action 종류와 cross-hero 지원의 다양성이 곧 게임의 깊이. **이 layer 의 부재 = 평타뿐 = 재미없음** (S89 사용자 raw feedback). Anchor GDD: `design/gdd/strategy-systems.md`.

---

## 🚫 Anti-Pillars — 이 게임이 **아닌** 것

- **NOT 가챠/캐릭터 수집** — "수집"이 아니라 "운용". 무장은 시나리오 따라 자연스럽게 합류.
- **NOT 실시간 전투** — 턴제의 "생각할 시간"이 핵심. 실시간 요소는 형세 읽기 깊이를 파괴.
- **NOT 오픈월드/샌드박스** — 시나리오 기반 선형 진행. 자유도는 전투 내 전략과 운명 분기에서.
- **NOT 밸런스 붕괴 허용** — "강캐 키워서 무쌍"은 적. 모든 무장이 가치 있는 밸런스가 필수.

---

## 🎯 현재 Ship Target — MVP Demo (ch01-16 + Strategic depth foundation)

**Anchor**: `production/milestones/mvp-demo-16ch.md`

- ch01 (도원결의·황건적) → ch16 (낙봉파·방통 생존) **16 챕터 windowed-attested**
- 5대 ★ 시그니처 destiny branch 중 첫 번째 = **ch16 방통 생존** (`scout_first ≥ 2`)
- 입증 목표: **"player 의 선택이 史記를 바꾼다"** 의 demo 단계 작동
- **Strategic depth foundation (S90 부터 추가, 2026-05-26)**: Pillar #5 의 작동 — **Item / Scroll / cross-hero 지원** action chain 이 mechanical 으로 작동. minimum bar = 5-7 종 아이템 + 1-2 종 책략권 + UI + chapter-별 inventory + 모든 14 skill wired 상태에서 strategic chain combo 가 windowed 에서 의도대로 발화. (Phase 4 hero attack frame 은 S89 이미 5명 완료.)
- 현재 상태: **MVP 5/5 ★ SHIP-READY mechanical 유지** (1996/1996 tests PASS, S87 기준) — **단, S90 부터 strategic depth 추가로 ship-ready bar 가 raised**.

**Out of scope for this ship**: ch17-25 / 5대 ★ 중 #2-#5 (관우·장비·유비·마속·제갈량) / **나머지 9 hero attack frame** (S89 carry-over) / CombatResolver 추출 / Multi-step survival cascade / 아이템 영구 강화 시스템 (RPG progression) / 아이템 상점 / 아이템 크래프팅.

---

## 🔥 사용자 raw feedback — 정직히 기록 (외면 금지)

S86 manual playtest 에서 사용자가 직접 던진 단어들. **이게 게임의 약점이다.**

1. **"전반적으로 난이도가 너무 낮음"** → atk_mult 0.55-0.80 → 0.95 → 1.15 → 1.50 (S88) → **S95 검증 + 챕터별 램프 1.25→1.70** (flat 1.50 폐기). S95 balance 하니스(`tools/ci/balance/ttk_matrix.gd`, 실제 `DamageCalc.resolve` 기반)로 입증: mult 1.00 에선 소모전 margin **+0.89**(안 써도 이김 = "난이도 낮음"), 1.50 에선 **−1.16**(전략 레이어 안 쓰면 짐) — Pillar #5 가 작동. flat 1.50 은 초반(튜토리얼)이 climax 만큼 가혹 + 후반 로스터 증가로 역전 → 램프로 교정(ch01 1.25 onboarding ↔ ch16 1.70 ★). **S96 후속**: S95 가 진단한 한계 ① (후반 DEFEAT_ALL ch11-14 의 6v4 로스터 비대칭 → mult 로 불가) 해소 — 적 1명 추가로 6v5 전환(ch11/12/14 +조조·ch13 +서황, addition-only JSON). 하니스 입증: margin +1.27~+1.36(안 써도 압승) → **−0.24~−0.47**(초반 "전략 필수" 존 ch01 −0.43 에 안착). substrate 0·새 hero 0·`tools/ci/balance/whatif_late_roster.gd` 가 telemetry 근거. **S98 후속 (실플레이 telemetry 수집)**: auto-battle 하니스(`tools/ci/balance/g30_autobattle_telemetry.gd` — 실 battle_scene + 적 AISystem + greedy player auto-pilot, 자연 루프 완주)로 실엔진 telemetry 수집 → **핵심 발견: `MAX_TURNS_PER_BATTLE = 5` 가 진짜 난이도 결정 요인이며 S95/S96 모델이 무시한 것**. DEFEAT_ALL 은 5라운드 내 전멸해야 승리. ttk_matrix 에 5라운드 렌즈(`_print_turn_limit_lens`): 모델(낙관 하한)상 reqMult 전 챕터 ≤0.85 = ATTRITION, 그러나 auto-battle(naive 상한)은 전 DEFEAT_ALL draw/loss. **bracket**: 진실은 둘 사이 — 현실 갭(엇갈린 도착 + 근접 인접 제약)이 모델 낙관성을 무너뜨려 전략 레이어를 mechanical 필수로 만듦. **open question / 잔존**: ① MAX_TURNS=5 가 의도된 전투 길이인지(naive 근접이 ch01 도 draw — 짧을 가능성)는 미해결 설계 질문(이번엔 모델링만, 밸런스 변경 안 함). ② 인간 competent-play telemetry(상한)는 여전히 미수집 — auto-pilot 은 dumb melee 하한. **S99 후속 (open question ① 해소 — 챕터별 turn budget)**: S98 이 던진 "MAX_TURNS=5 가 의도된 길이인가" 를 재검토 → **단일 글로벌 5 가 두 모순된 역할을 겸직**했음이 핵심 발견. SURVIVE 챕터엔 5 가 정확한 라운드 예산(조화)이나, ANNIHILATION 챕터 중 **큰 맵(ch09/11/12/14, gap 9-10 → apprRnd 2)** 은 접근에 1라운드를 뺏겨 전투창이 3(타 챕터 4)으로 줄어드는 **우발적·비설계 난이도 축** — 이것이 ttk_matrix 가 ch11/12/14 를 NEEDS-BUFF(reqMult 1.11)로 표시한 이유. 해소: `victory_conditions.turn_budget` 신설(data-driven, 0=글로벌 폴백) + 원칙 `budget = apprRnd + COMBAT_WINDOW(=4)` → ch09/11/12/14 = 6 authoring, 나머지 ANNIHILATION 은 5 유지(재-소프트닝 0). 하니스 입증: 전 DEFEAT_ALL effCmbt 4 균일 + reqMult 0.65-0.98 ATTRITION 평탄화(NEEDS-BUFF 소멸). 의도 난이도 램프는 atk_mult(직교 축)에 잔류. **부수 latent 버그 동시 해소**: SURVIVE ch20/22(survive=6)·ch25(survive=8) 가 글로벌 5 < survive_rounds → TURN_LIMIT_REACHED DRAW 가 survive-win 보다 먼저 발화 = 승리 불가였음(post-MVP) → turn_budget=survive_rounds authoring. **G-30 catch**: 헤드리스 override 테스트는 PASS 였으나 windowed 에서 `_ready()` 가 글로벌 5 로 override 를 clobber(set_victory_conditions 후 add_child 순서) → `g30_turn_budget_smoke` 가 적발 → `_ready` 재적용 fix. ③ 인간 competent telemetry 상한은 여전히 미수집(잔존).
2. **"공격수단 평타뿐"** → S86 까지 14 skill 중 다수 unwired. S86-S87 에서 14/14 wire + S 키 routing fix (G-32 codify).
3. **"재미없음"** (raw) → root cause = layered UX gap (mechanical + discoverability + visual feedback). 단일 layer fix 로 해소 불가.
4. **"S 키 눌러도 차이 없음"** → InputRouter `_did_visible_work` gate silent drop. 3차 진단 끝에 fix (S86) + G-32 codify (S87).
5. **Visual feedback 부족** → "damage popup 만 보이고 skill 특별감 0" → S87 particle wave 14/14 완성.
6. **"전략적 조합이 없음"** (S89 명시) → "이동 이후 공격이나 책략이나 도구(아이템)를 사용해서 나의 공격력을 강화하거나 다른 장수를 도와주거나 본인 병종으로서는 불가능한 책략을 쓸 수 있게 되거나 하는 등 영걸전에서 제공하는 재미있고 전략적인 것들이 많이 있는데, 현재 이 게임에서는 그런 부분이 거의 없는 것과 같다. 이 부분이 제일 중요한 부분이고, 이런 것들이 조합이 되어서 게임 난이도와 밸런스가 결정된다." → audit 결과 정확: **아이템 시스템 0 / 책략권 시스템 0 / cross-class 책략 0**. Move-then-action chain 은 S86 부터 작동하나 action 종류가 제한적 (skill 14/14 wired 이지만 모두 class-locked). → Pillar #5 신설 + ship target 재정의 + `design/gdd/strategy-systems.md` GDD 신규.

**원칙**: 사용자 raw feedback 은 hypothesis 보다 우선. console log 의 정확한 telemetry > developer 추론.

---

## 📐 Design Test — 의사결정 시 참조

새 기능 / 변경 제안이 들어왔을 때 다음 질문에 답해 본다:

1. **Pillar 1 test**: "강력한 무장 한 명을 더 강하게 할까, 진형 시스템을 더 깊게 할까?" → **진형 시스템을 깊게 한다.**
2. **Pillar 2 test**: "운명 분기 조건을 쉽게 달성 가능하게 할까, 어렵지만 가능하게 할까?" → **어렵지만 가능하게 한다.** 쉬우면 드라마가 없다.
3. **Pillar 3 test**: "인기 무장에게 특별한 강화를 줄까, 모든 무장의 역할 차별화를 강화할까?" → **역할 차별화를 강화한다.** *책략권 도입 시도 class 제한으로 보호.*
4. **Pillar 4 test**: "전투 수를 늘릴까, 전투 사이의 스토리 이벤트를 풍부하게 할까?" → **스토리 이벤트를 풍부하게 한다.**
5. **Pillar 5 test**: "단일 강력한 action 을 추가할까, action 의 조합을 깊게 할까?" → **조합을 깊게 한다.** 새 action 단독 효과보다 기존 action 들과의 chain 가능성이 우선. **\"이동+아이템 vs 이동+공격 vs 이동+책략권 vs cross-hero 지원\" 의 선택 압박**이 매 turn 발생해야 함.
6. **Anti-pillar test**: 제안이 anti-pillar 4개 중 하나라도 위반하면 → **reject 또는 redesign.**

---

## 🧭 Collaboration anchor

- **Mode**: Build, not Ratify (per `WORKFLOW.md`) — sprint/gate/retro machinery dormant
- **Protocol**: Question → Options → Decision → Draft → Approval (per `CLAUDE.md`)
- **Session state**: `production/session-state/active.md` (ephemeral, gitignored)
- **Milestone anchor**: `production/milestones/mvp-demo-16ch.md`

---

*Last updated: 2026-05-26 (S89 close — Pillar #5 신설 + Strategic depth ship target 재정의 + raw feedback #6). 변경은 사용자 명시적 결정 후에만.*
