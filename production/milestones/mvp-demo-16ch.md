# Milestone: MVP Demo — ch01-16 + 방통 생존 ★

> **Decided**: 2026-05-22 (S73, post 6-lens assessment)
> **Mode**: Build, not Ratify (WORKFLOW.md) — milestone tracking restored for ship-target focus, sprint/gate machinery remains dormant
> **Ship target estimate**: 6-10 weeks (S16 ~ S19)

## Ship Statement

**천명역전 MVP Demo** 는 ch01 (도원결의·황건적 토벌) 부터 ch16 (낙봉파·방통 생존) 까지 **16 개 챕터** 를 windowed-attested 상태로 ship 한다. 5대 영걸전 시그니처 destiny branch 중 첫 번째 (**ch16 방통 생존 ★** = `scout_first ≥ 2`) 가 player choice → windowed trigger → branch reveal 전체 흐름으로 실제 작동한다. 이를 통해 **"player 의 선택이 史記를 바꾼다"** 의 게임 정체성을 demo 단계에서 입증한다.

## Done Criteria (testable)

### Code & Test
- [ ] 1876+/1876+ tests PASS (S71 baseline 유지 or 상회)
- [ ] S72 3 신규 mechanic + S73 synergy v2 = **4 unit test 파일 backfill 완료**
- [ ] Windowed smoke harness ch01-16 cut PASS
- [ ] Orphan baseline ≤ 276 유지 (or POLISH-008 종결로 감소)
- [ ] Trace flag (`_SYNERGY_TRACE_ENABLED` / `_CRIT_CHAIN_TRACE_ENABLED`) 모두 `false`

### Content & Narrative
- [ ] Beat 8 revelation prose 16 챕터 모두 작성 (한국어 초안 가능)
- [ ] ch16 방통 생존 trigger windowed-attested (scout_first ≥ 2 → 방통 살아남음 → Beat 8 revelation 발화)
- [ ] Banter per-chapter context — 최소 ch01/05/13/16 변형 (반복감 완화)
- [ ] 적측 voice minimal — 최소 조조 / 하후돈 / 여포 / 방통 적측 (ch01-16 등장 적장)

### Visual & Audio
- [ ] World/environment 첫 tile set ship (Phase A-B 분위기 — 신야/형주 ambient)
- [ ] 5 procedural music 테마 16 챕터 mapping 명시적 (반복 인식 polish)

### Macro-loop UI
- [ ] Chapter selection 화면 (user-facing, DEV menu 졸업)
- [ ] Post-battle outcome 화면 + branch reveal 시퀀스 (Beat 8 의 ceremonial witness 패턴 — 1.5s dwell)
- [ ] Next chapter unlock 시 chapter selection 화면으로 복귀

### Save / Migration
- [ ] `scenario_id` rename (`shu_canon_full` → final) + SaveContext migration 검증
- [ ] Cross-chapter persistence 검증 (ch01 종결 후 ch02 시작 시 영웅 HP / 합류 state 유지)

### Production
- [ ] `production/milestones/mvp-demo-16ch.md` (이 파일) maintained — 매 sprint 종결 시 attestation log 업데이트
- [ ] Polish backlog 중 ship blocker 만 별도 분리 (`production/milestones/mvp-demo-16ch-ship-blockers.md` 또는 inline)

## Out of Scope (explicit)

명시적으로 이번 ship 에서 **제외** — 추후 milestone 으로:

- **ch17-25** (성도 / 한중 / 이릉 / 남만 / 북벌 / 오장원) — Full Vision MVP 의 후속 milestone
- **5대 ★ 시그니처 중 #2~#5** (관우 ch20 / 장비 ch21 / 유비 ch22 / 마속 ch24 / 제갈량 ch25) — ch17+ milestone 의 핵심
- **외부 영웅 16 명 중 ch17+ 만 등장하는 영웅** (마초 / 강유) — 챕터 범위 외이므로 단지 데이터 stub 유지
- **Phase 4 hero attack frames** (Gemini chibi small-delta ceiling 으로 차단됨) — code-side VFX 로 대체, asset 작업 deferred
- **CombatResolver 추출** (Tech Director 추천) — 5번째 in-controller mechanic 추가 시점에 trigger, 이번 milestone 의 blocker 아님
- **Choice flatness Phase 4** (S71 진단) — Full Vision 의 후속 polish, MVP 의 4 pillar 진단 중 1개만 light entry (synergy)
- **Multi-step survival cascade** (관우/장비/유비 ch25 까지 chained) — single ch16 branch 만 시연

## Sprint TOC

| Sprint | 기간 | 목표 | 주요 deliverables |
|--------|------|------|-------------------|
| **S16 — Foundation** | 1-2 w | QA 부채 상환 + 인프라 정비 | unit test backfill 4개 / windowed attestation 16-cut / trace cleanup / milestone tracking 복원 |
| **S17 — Macro-loop** | 2-3 w | chapter→branch→next 흐름 | Chapter select 화면 / outcome+branch reveal 화면 / Beat 8 prose 16 / ch16 방통 trigger 검증 |
| **S18 — Content Polish** | 2-3 w | 세계 + 목소리 차별화 | World/env first tile set / banter per-chapter / 적측 voice / 음악 mapping |
| **S19 — Ship** | 1-2 w | end-to-end + 출하 | Full windowed playthrough / Save migration / Bug bash / Polish backlog 최종 cull |

## Cross-lens Dependency Map

각 sprint 마다 어느 agent lens 가 권장한 작업인지 추적 (S73 6-lens 평가 출처):

| 작업 | Producer | Game Designer | Tech Director | QA Lead | Art Director | Narrative |
|------|----------|---------------|---------------|---------|--------------|-----------|
| Milestone file | ★ | | | | | |
| Unit test backfill | | | ◐ | ★ | | |
| Windowed smoke harness | | | ◐ | ★ | | |
| Macro-loop UI | | ★ | | | | ◐ |
| Beat 8 prose | | ◐ | | | | ★ |
| World/env tile | | | | | ★ | |
| Banter per-chapter | | | | | | ★ |
| 적측 voice | | | | | | ★ |
| Save migration | | ◐ | ★ | | | |
| ch16 branch trigger | | ★ | | ◐ | | ◐ |

(★ = primary advocate / ◐ = secondary support)

## Risk Register

| Risk | Owner lens | Mitigation |
|------|-----------|-----------|
| Polish loop drift — combat layer 의 marginal return 작업으로 시간 소진 | Producer | 매 sprint 종결 시 done criteria 진척 % 점검, 새 polish item 은 `production/polish-backlog.md` 로 격리 |
| Beat 8 prose 가 generic 하면 운명 분기 hook hollow | Narrative | ch16 1 chapter 부터 진심으로 작성 → 사용자 attestation → 나머지 15 chapter 결 정렬 |
| ch16 방통 trigger 가 windowed 환경에서 stall (G-30 가능성) | QA + Game Designer | S16 의 windowed attestation 에서 우선 검증, 안 되면 S17 의 핵심 blocker |
| Mechanic-spike pattern 재발 (in-controller 패치) | Tech Director | S18-S19 에서 새 mechanic 추가 금지 (oversea 예외 only), 추가 시 CombatResolver 추출 |
| Banter / Beat 8 / 적측 voice = 1인 작업 한계 | Producer + Narrative | S18 분량 우선순위 = ch01/05/13/16 4 챕터만 깊이, 나머지 12 챕터는 minimal pass |

## Attestation Log

각 sprint 종결 시 사용자 windowed attestation 결과 누적.

### S16 — Foundation (in progress, 2026-05-22 ~)

**Completed**:
- [x] Milestone file 작성 (이 문서) — `0511465`
- [x] Trace flag cleanup (`_SYNERGY_TRACE_ENABLED` / `_CRIT_CHAIN_TRACE_ENABLED` → false 후 attestation 완료) — `0511465`
- [x] Unit test backfill 4/4 (S72 + S73 mechanic) — `c2f11f5` + `ba5d11e`
  - Hero banter (10 tests / `hero_database_banter_test.gd`)
  - Critical chain (15 tests / `grid_battle_controller_critical_chain_test.gd`)
  - Synergy v1 + v2 (19 tests / `grid_battle_controller_synergy_test.gd`)
  - Total 44 신규 tests / 663/663 PASS unified
- [x] S73 사용자 windowed attestation: Synergy v1 (Peach Garden +5 ATK 3 영웅) + Critical chain (lv1 다회 + lv2 +25% 장비 245→306)

**Remaining**:
- [x] Windowed attestation 16-ch cut 파일 작성 (`production/qa/evidence/phase-f-windowed-boot-attestation-16-chapters.md` 신규 fork from 25-cut) — 사용자 windowed attestation 실행 대기
- [ ] 사용자 windowed attestation 실행 (~8분 + S72-S73 mechanic 자연 발화분)
- [ ] Sprint 16 retrospective (짧게, build mode 컨벤션)

### S17 — Macro-loop (in progress, 2026-05-22 session 74 ~)

**Completed**:
- [x] Chapter selection 화면 (DEV menu 졸업) — `eaa1a63` (NEW scenes/chapter_select/ + src/feature/chapter_select/ + ScenarioRunner.jump_to_chapter() sibling, +12 unit tests)
- [x] Post-battle outcome + branch reveal 시퀀스 (ceremonial witness pattern) — `7379e1e` (기존 ceremonial 시퀀스 재사용 + tail redirect to chapter_select, +6 sentinel tests). Beat 8 prose 의 사용자 input 대기 자체가 ceremonial dwell — 별도 timer 불필요.
- [x] Beat 8 revelation prose ch16 진심 작성 — `4deb651` (narrative-director Draft B: 삼국지연의 제63회 직접 소환 패턴)
- [x] Macro-loop closed: main_menu → chapter_select → battle → post-battle ceremonial → chapter_select 복귀. **MVP demo 사용자 흐름 처음으로 닫힘**.

**Beat 8 hidden ★ prose paired suite — 6 chapters 완성** (`4deb651` + `30db11d` + `0f04942` + `13a6535` + `2747467` + `f17f475`):
- [x] ch16 ★ #1 방통 (낙봉파, 제63회 직접 소환) — MVP scope
- [x] ch13 ★ #2 위연 (장사 반골, 제53회 메타) — MVP scope
- [x] ch20 ★ #3 관우 (번성, 제76/77회 + "빚") — out-of-scope (reference frame)
- [x] ch21 ★ #4 장비 (낭중 규율의 밤, 제81회, thematic anchor "살아 있는 자가 지키는 맹세는 끊어지지 않는다") — out-of-scope (reference frame)
- [x] ch22 (#) 유비 (이릉, 제85회, 공명 시점) — out-of-scope (reference frame)
- [x] ch25 closing 제갈량 (오장원, 제103/104회, 시리즈 anchor "출사표는 시작을 여는 표") — out-of-scope (reference frame)

같은 register / 4-5 단락 / 三國演義 직접 소환 / cascade ambiguity 흡수 / thematic line 결 정합. 6 ★ prose 모두 narrative-director drafts-without-writing 패턴 → 사용자 선택 → orchestrator Edit.

**Remaining**:
- [ ] MVP-scope default win Beat 8 prose (ch01-12 + ch14-15 — 9-12 chapters) — ★ prose register 보다 약한 contextual prose, 다음 세션 batch 작성 가능 (낮은 우선순위 — ★ 가 헤드라인)
- [ ] ch16 방통 생존 trigger windowed-attested (scout_first ≥ 2) — 코드 path 완성, **사용자 windowed 실행 대기**

### S18 — Content Polish (예정)
- [ ] World/environment 첫 tile set (Phase A-B 분위기, 신야/형주 ambient)
- [ ] Banter per-chapter context (ch01/05/13/16 최소 4 변형)
- [ ] 적측 voice minimal (조조 / 하후돈 / 여포 / 방통 적측)
- [ ] 5 procedural music 16 챕터 mapping

### S19 — Ship (예정)
- [ ] Full windowed playthrough ch01 → ch16
- [ ] Save migration (scenario_id rename)
- [ ] Bug bash
- [ ] Polish backlog 최종 cull

## Reference

- 6-lens assessment 원본: 2026-05-22 S73 session (Producer / Game Designer / QA Lead / Technical Director / Art Director / Narrative Director 병렬 spawn)
- Master scenario: `design/scenarios/yeong_geol_jeon_shu_master.md`
- Current state snapshot: `production/session-state/active.md` (S72 close-out)
- Active workflow mode: `WORKFLOW.md` (Build, not Ratify since 2026-05-10)
