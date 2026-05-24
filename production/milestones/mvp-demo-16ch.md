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
- [x] Beat 8 revelation prose 16 챕터 win-side 모두 작성 (default 16/16 + alt-win 8/8 + ★ headline 6/6; loss-side deferred — ROI 낮음)
- [ ] ch16 방통 생존 trigger windowed-attested (scout_first ≥ 2 → 방통 살아남음 → Beat 8 revelation 발화)
- [x] Banter per-chapter context — ch01/05/13/16 × battle_start+outcome_win 변형 26 lines 적용 (S18 session 76)
- [x] 적측 voice minimal — 조조 / 하후돈 / 여포 / 장료 4 적장 × {battle_start, outcome_loss} = 8 lines (S18 session 76). "방통 적측" milestone 문구 ambiguous → 4번째 적장은 ch01-16 등장 빈도 2위 + ch16 ★ 챕터 primary 적장인 장료 채택.

### Visual & Audio
- [ ] World/environment 첫 tile set ship (Phase A-B 분위기 — 신야/형주 ambient)
- [x] 5 procedural music 테마 16 챕터 mapping 명시적 — `design/audio/music-themes.md` (S18 session 76, 248 lines, 25-ch table + repetition-awareness + playtest-watch)

### Macro-loop UI
- [ ] Chapter selection 화면 (user-facing, DEV menu 졸업)
- [ ] Post-battle outcome 화면 + branch reveal 시퀀스 (Beat 8 의 ceremonial witness 패턴 — 1.5s dwell)
- [ ] Next chapter unlock 시 chapter selection 화면으로 복귀

### Save / Migration
- [x] `scenario_id` rename (`shu_canon_full` → `shu_canon_main`) — S77 S19-B. JSON file `git mv` + 2 internal fields (`scenario_id` + `scenario_title_key`) + 30 file 일괄 치환 (src 7 + tests 17 + scenes 1 + design 3 + docs 2). 1949/1949 PASS 유지 (regression 0). SaveContext schema 변경 없음 (scenario_id field 미보유 — 선택된 Sub-scope A 範圍 외)
- [x] Cross-chapter persistence 검증 — S77 S19-B. 기존 integration tests 가 cover: `scenario_runner_chapter_2_advance_test.gd` (heroic/tragic deployment variant + roster preservation via branch_overrides) + `cross_chapter_continuity_test.gd` (save-load roundtrip). HP carry-over 는 디자인 비대상 (각 chapter battle = fresh full-HP roster, scenario JSON initial 값 기반). 합류 state 는 BattlePayload.unit_roster + deployment_positions 로 보존 검증됨

### Production
- [ ] `production/milestones/mvp-demo-16ch.md` (이 파일) maintained — 매 sprint 종결 시 attestation log 업데이트
- [x] Polish backlog 중 ship blocker 만 별도 분리 — inline 절 "Polish Backlog Ship-Blocker Triage" (S77, S19-A). 0 net new ship-blocker, 4 entries (POLISH-009/010/011/012) EFFECTIVELY-RESOLVED pending S19-D windowed attestation

## Out of Scope (explicit)

명시적으로 이번 ship 에서 **제외** — 추후 milestone 으로:

- **ch17-25** (성도 / 한중 / 이릉 / 남만 / 북벌 / 오장원) — Full Vision MVP 의 후속 milestone
- **5대 ★ 시그니처 중 #2~#5** (관우 ch20 / 장비 ch21 / 유비 ch22 / 마속 ch24 / 제갈량 ch25) — ch17+ milestone 의 핵심
- **외부 영웅 16 명 중 ch17+ 만 등장하는 영웅** (마초 / 강유) — 챕터 범위 외이므로 단지 데이터 stub 유지
- **Phase 4 hero attack frames** (Gemini chibi small-delta ceiling 으로 차단됨) — code-side VFX 로 대체, asset 작업 deferred
- **CombatResolver 추출** (Tech Director 추천) — 5번째 in-controller mechanic 추가 시점에 trigger, 이번 milestone 의 blocker 아님
- **Choice flatness Phase 4** (S71 진단) — Full Vision 의 후속 polish, MVP 의 4 pillar 진단 중 1개만 light entry (synergy)
- **Multi-step survival cascade** (관우/장비/유비 ch25 까지 chained) — single ch16 branch 만 시연

## Branch Distribution Anchor

> **Anchor doc**: `design/narrative/branch-distribution-plan.md` (2026-05-24). 본 milestone 의 ★ 분기 architecture 는 그 plan 의 4 Core Principles + 5 ★ distribution 에 종속.

**MVP 16ch ★ enumeration** (총 5 개):

| ch | ★ branch key | 상태 |
|----|--------------|------|
| 05 | `WIN_xinye_villagers_all_saved` — 백성 evacuation | **신규** (plan §4.1) — implementation pending |
| 08 | `WIN_xiakou_alliance_perfect_timing` — 동맹 결의 timing | **신규** (plan §4.2) — implementation pending |
| 10 | `WIN_chibi_perfect_southeast_wind` — 동남풍 perfect timing | **신규** (plan §4.3) — implementation pending |
| 13 | `WIN_changsha_wei_yan_defects` — 위연 합류 | **기존** ship-ready (plan §4.4 reference) |
| 16 | `WIN_luofeng_pang_tong_lives` — 방통 생존 | **기존** ship-ready (plan §4.5 reference, S19-D windowed attest 대상) |

**MVP default-only 챕터** (11 개): ch01 / ch02 / ch03 / ch04 / ch06 / ch07 / ch09 / ch11 / ch12 / ch14 / ch15. 각 챕터 prose 의 무게는 default 만으로 충족되어야 함 — 분기 추가 거부 (plan §10).

**Ship 영향**:
- 본 milestone 의 ship-ready ★ 는 2 개 (ch13/16). 신규 3 개 (ch05/08/10) 는 별도 후속 milestone 또는 ship 후 follow-up. S19 Ship 결정은 이 분포 위에서.
- ch01 vertical-slice uplift (plan §8 + 별도 `design/quick-specs/ch01-vertical-slice-uplift.md` — author pending) 는 본 milestone 안에 포함 가능 (분기 없음, lore + 긴장감 + Beat 8 seed 만).

## Polish Backlog Ship-Blocker Triage

> **Decided**: 2026-05-23 (S77, S19-A). `production/polish-backlog.md` 의 15 Open entries 를 ship-blocker 기준 (= MVP demo ship = ch01-16 windowed-attested + 방통 ★ 작동) 으로 triage. polish-backlog.md 자체는 미수정 (Build mode 의 POLISH-NNN 추적 dormant 원칙 유지) — 이 표가 ship-relevant 단일 view.

| POLISH ID | Tier | Ship-blocker 분류 | 근거 |
|-----------|------|-------------------|------|
| 001 / 002 / 003 | ADVISORY | NON-BLOCKER | Battle HUD doc nits, Polish-phase doc sweep 대상 |
| 004 / 005 | ADVISORY | NON-BLOCKER | Lint 5 whitelist + em-dash const, localization sprint trigger |
| 006 | ADVISORY→char-art | NON-BLOCKER (MVP scope) | Guan Yu/Zhang Fei profile stubs — MVP 는 commissioned art 없음, chibi pixel 사용. char-art commission 부재로 trigger 미발화 |
| 007 | ADVISORY (perf) | NON-BLOCKER | GameBus 391 emits/frame, 60fps 영향 0 (소프트 캡 calibration) |
| 008 | ADVISORY (LOW defect) | NON-BLOCKER | ObjectDB exit-time leak, in-session 영향 0 |
| 009 | DEFECT | **EFFECTIVELY-RESOLVED** | S14-02 visual fix 가 `mvp_chapter_01.tscn` ERROR 해소 (polish-backlog Amendment log 2026-05-09 PM late) |
| 010 | DEFECT (HIGH) | **EFFECTIVELY-RESOLVED** | S14-02 가 production main_scene 의 visual rendering 검증 (Amendment log 동일 entry) |
| 011 | DEFECT (CRITICAL) | **EFFECTIVELY-RESOLVED pending S19-D** | S15-A/B/C/J + S17 macro-loop closure (chapter_select→battle→ceremonial→back) 가 input + turn-loop 회로 검증. windowed re-attestation = S19-D |
| 012 | DEFECT (CRITICAL) | **EFFECTIVELY-RESOLVED pending S19-D** | S15-J production wiring (set_action_controller) + S17 macro-loop closure. S19-D windowed 가 formal 종결 |
| 013 | DEFECT HIGH (verif-gap) | NON-BLOCKER (test-side) | natural-loop integration test 환경의 deferred-chain stall — production main_scene 의 macro-loop 가 닫혀 있으므로 production 결로는 작동 확인됨. test infra 보강은 ship 후 polish |
| 014 | DEFECT (LOW) | NON-BLOCKER | BattleScene teardown ~270 orphan, exit code 101 warning. 1949 tests 모두 PASS, 276 orphan baseline 유지 |
| 015 | DEFECT (LOW visual) | NON-BLOCKER | 관우 chibi 90° 회전, gameplay 영향 0. Q5 Phase 3 walk-frame 또는 사용자 explicit request 시점 |

**Triage summary**:
- 0 net new ship-blocker (ship gate 통과에 필요한 새 작업 없음)
- 4 entries (009/010/011/012) = EFFECTIVELY-RESOLVED 또는 pending-S19-D-attestation. S19-D 의 windowed playthrough 통과가 곧 formal closure trigger
- 11 entries = NON-BLOCKER (Polish-phase / post-MVP / cosmetic)

**Implication for S19**: ship gate = (a) S19-B Save migration 종결 + (b) S18 World/env tile set spec doc (S18 carryover) + (c) S19-D 사용자 windowed playthrough ch01-16 + ch16 ★ 통과. 그 3개가 통과하면 ship 준비 완료. polish-backlog 의 어떤 entry 도 별도 fix 작업 불필요.

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
| Beat 8 prose (win-side ✅) | | ◐ | | | | ★ |
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

**Beat 8 win-side prose 100% coverage — S75 session 75 (2026-05-22)**:
- `fa4a4a1` — MVP ch01-15 default win Beat 8 prose batch (15개, 3-4 단락 / 三國演義 회수 직접 소환 / dignified canonical register). narrative-director 1회 spawn (~87k tokens) → 사용자 일괄 review → python atomic JSON write → focused suite PASS.
- `2ac5c99` — MVP alt-win Beat 8 prose batch (6개: ch02/03/04/05/06/08, 3-4 단락 / "정사에 적히지 않은" / quiet alt-history reveal register). ch02/03/04/05 thin (162-232 chars) → expansion. ch06/08 light refine + 결 강화. 초선 motif (ch08) 보존. narrative-director 1회 spawn (~42k tokens).

**3-register clean differentiation 검증됨**: ★ (4-5 단락 / 多回 三國演義 / 강한 thematic anchor) ↔ default (3-4 단락 / 1-2회 三國演義 / dignified canonical) ↔ alt-win (3-4 단락 / "정사에 적히지 않은" / quiet alt-history reveal). 한 세션 안에서 default + alt 두 batch 모두 register leak 0.

**MVP Beat 8 win-side prose coverage = 100%**:
- default win 16/16 (ch01-15 from `fa4a4a1` + ch16 default from `4deb651` 의 paired entry)
- alt-win 8/8 (ch02/03/04/05/06/08 from `2ac5c99` + ch13 ★ `30db11d` + ch16 ★ `4deb651`)
- ★ headline 6/6 (ch16/13/20/21/22/ch25 from S74 paired suite)

Test gate: focused suite (story_event + core) 513/513 PASS × 2회 검증 (default + alt batch 각각).

**Remaining**:
- [ ] Beat 8 default-loss prose 16/16 — 우선순위 낮음 (loss outcome 회로 사용자 미관통 가능성 큼, alt-loss register 정의 필요)
- [ ] ch16 방통 생존 trigger windowed-attested (scout_first ≥ 2) — 코드 path 완성, **사용자 windowed 실행 대기**

### S18 — Content Polish (in progress, 2026-05-23 session 76 ~)

**Completed**:
- [x] Banter per-chapter context — ch01/05/13/16 × {battle_start, outcome_win} = 26 lines, 4 heroes (liu_bei/guan_yu/zhang_fei/pang_tong) — session 76. Schema extension: `hero_id.by_chapter[chapter_id][event_key]` optional override, default fallback path 보존. `HeroDatabase.get_banter()` signature → optional `chapter_id` 인자; `battle_scene._active_chapter_id()` 헬퍼가 active chapter 전달. +8 unit tests for chapter-override semantics (1946/1946 PASS).
- [x] 5 procedural music 16 챕터 mapping 명시적 — `design/audio/music-themes.md` 신규 작성 (session 76, 248 lines). 5-theme palette (CH01-05) + 25-chapter mapping table (16 MVP-scope + 9 out-of-scope + 5 Wei line) + Repetition Awareness 분포 분석 (CH01×3 / CH02×4 / CH03×3 / CH04×3 / CH05×3) + playtest-watch 2개 flag (ch04→ch05 CH05 연속, ch13→ch16 CH01 proximity) + synthesis-layer mitigation 옵션. 코드 코멘트 산재 rationale 을 designer-facing canonical doc 으로 통합. 기존 5 sentinel tests (sound_manager_music_test.gd) 그대로 보호.
- [x] 적측 voice minimal — 4 적장 (wei_001 조조 / wei_005 하후돈 / qun_001 여포 / wei_006 장료) × {battle_start, outcome_loss} = 8 default lines (session 76). battle_scene `_fire_enemy_roster_banter()` 신규 sibling helper, EnemyUnits parent iterate + side==1 필터. Wire: round 1 battle_start (player 발화 후 2.0s start_delay) + outcome WIN 시 outcome_loss (player 발화 후 2.0s start_delay). +3 sentinel tests (8-line authored / battle_start no-dupe / outcome_loss no-dupe). "방통 적측" milestone 문구 ambiguous → 장료 채택 (16ch 등장 빈도 2위 + ch16 ★ primary). 1949/1949 PASS.

**Remaining**:
- [ ] World/environment 첫 tile set (Phase A-B 분위기, 신야/형주 ambient)

### S19 — Ship (in progress, 2026-05-24 session 77 ~)

**Completed**:
- [x] Polish backlog ship-blocker triage (S19-A) — `f998280` (inline 절 "Polish Backlog Ship-Blocker Triage", 15 entries 3 분류, 0 net new blocker, 4 EFFECTIVELY-RESOLVED pending S19-D)
- [x] Save migration / scenario_id rename `shu_canon_full` → `shu_canon_main` (S19-B) — `7d1f01c` (JSON `git mv` + 2 internal fields + 30 file 일괄 치환, 1949/1949 PASS 유지, Sub-scope A: SaveContext schema 미변경)
- [x] Cross-chapter persistence 검증 (S19-B) — 기존 integration tests cover (`scenario_runner_chapter_2_advance_test` heroic/tragic deployment variant + `cross_chapter_continuity_test` save-load roundtrip)
- [x] S19-D evidence prep (S19-D 준비) — `a124871` (phase-f-windowed-boot-attestation-16-chapters.md §3.5 신규 + §0 baseline + §6 종료 조건 갱신, +49 lines)

**Remaining**:
- [ ] Full windowed playthrough ch01 → ch16 (S19-D 사용자 실행) — evidence 파일 ready, 사용자 ~8분 실행 대기
- [ ] Bug bash (S19-E) — S19-D 결과 의존
- [ ] Polish backlog 최종 cull (S19-C 선택적) — Build mode POLISH-NNN dormant 원칙 고려 시 ROI 낮음, S19-A triage 가 ship-relevant view 만 추출했으므로 sufficient

### S78 — Branch architecture + ch01 vertical-slice (2026-05-24 session 78)

> **Driver**: 사용자 "긴장감 / 운명을 바꾸는 묘미 / 역사를 만드는 매력 이 첫판부터 안 felt" 진단 → ch01 redesign.

**Completed (7 commits, 1954/1954 PASS, push 완료)**:
- [x] **Branch distribution plan** (`d26da92`) — `design/narrative/branch-distribution-plan.md` 신규 (286 lines, 11 sections): 4 Core Principles (Scarcity / Tragedy preservation / Decisive-moment signaling / ch01 priming-null) + MVP 16ch ★ 5 distribution (ch05/08/10/13/16) + Full Vision ch20-22 cascade-block + ch24/25 brief. `design/quick-specs/ch01-vertical-slice-uplift.md` 신규 (143 lines, 8 sections). 본 milestone 의 "Branch Distribution Anchor" 절 신규 +20 lines.
- [x] **ch01 황건적 hero records** (`2ac776f`) — yel_001 정원지 / yel_002 등무 / yel_003 손중 / yel_004 황소 4 records (HeroFaction.QUNXIONG=3, innate_skill_ids 비어있음, portrait/sprite placeholder). spec UnitClass enum (0=CAVALRY, 1=INFANTRY, 2=ARCHER) 정정.
- [x] **ch01 roster swap + tuning** (`99fcee9`) — 위 4 장수 → yel_001-004 (archetype aggressor/holder/skirmisher/coordinator 4 distinct 보존), `enemy_atk_mult` 0.7→0.95, chokepoints 2→4 칸 [[5,4],[6,4],[7,4],[8,4]] (도로 일렬, 형세의 흐름).
- [x] **ch01 Beat 8 ch05 seed** (`4b4f6a4`) — `ch01.beat8.win_taoyuan_oath_held` body 마지막에 1 sentence append: "그리고 — 이 형제의 칼이 백성을 지킬 날이, 신야의 흙길 위에서 따로 찾아올 것임도 그들은 아직 알지 못했다." (ch05 ★ trigger emotional anchor 미리 sourced).
- [x] **Regression fix** (`79ca4b1`) — yel_002 growth_intellect 0.4→0.5 (CR-2 `[0.5, 2.0]` 위반 fix, HeroDatabase 22→23 records 회복), archetype 4 distinct 복원, 3 test 갱신 (chokepoint 2→4 expectation / MVP roster 상한 20→25 / battle_scene 2개 test 의 MOCK_HERO_IDS 에 yel_001-004 추가).
- [x] **ch01 sentinel tests** (`769e52f`) — `tests/unit/feature/story_event/ch01_vertical_slice_sentinel_test.gd` 신규 (5 tests, 143 lines): 황건 hero records 존재 / roster yel_ prefix / tuning 값 / branch_table priming-null regression / Beat 8 ch05 seed substring. 1949 baseline +5 = 1954 PASS.

**Outcome**: ch01 = "약속의 무게" 챕터로 격상. Pillar 1 (긴장감 mechanical), Pillar 2 (Beat 8 seed로 ch05 ★ foreshadow, priming-null 유지), Pillar 4 (황건적 lore 정합) 셋 다 첫판에서 felt. **분기 추가 X** — `branch_table = {WIN_default, LOSS_default}` 보존 (sentinel test 가 미래 ★ leak 차단).

### S79 — ch05 ★ design + first impl arc (2026-05-24 session 79)

> **Driver**: S78 unlocked vector #1 — plan §11 Step 3 의 design portion + first impl arc (ch05 신야 화공 ★ "백성 evacuation" mechanical substrate).

**Completed (5 commits, 1962/1962 PASS, push 완료)**:
- [x] **ch05 quick-spec** (`0bb7308`) — `design/quick-specs/ch05-civilian-evacuation.md` 신규 (201 lines, 8 sections): Stranded Escort Token model (autonomous NPC + terrain feature 둘 다 거부) + 5 token positions `[[3,2],[5,3],[4,5],[4,7],[6,6]]` + ★ trigger 3+ save + 8 OQ (5 spec-잠금 + 3 deferred).
- [x] **ADR-0022 Civilian System** (`26c1a6b`) — `docs/architecture/ADR-0022-civilian-system.md` 신규 (284 lines, Proposed per Build mode): CivilianToken = `class_name X extends RefCounted` + 3-state machine + assert-guard mutators (bind_to_carrier / commit_save / recover_to_idle). GridBattleController owns `_civilian_tokens` collection (battle-scoped, RefCounted RAII). ADR-0017 §Amendment 2026-05-24 (#1) inline (civilian_config field, Evolution Rule #4 minor amendment, 0 chapters require JSON update). 3 net-new forbidden_patterns: civilian_token_node_subclass / civilian_token_static_var / civilian_escorted_counter_direct_mutation. 6 alternatives rejected.
- [x] **Schema + JSON + hydration + validation** (`2e7dc88`) — `ChapterDefinition.civilian_config: Dictionary = {}` field 추가 + ScenarioRunner `_hydrate_chapter` deep-copy hydration + `_validate_chapter_record` 4 fault-ids (civilian_config_not_dict / positions_not_array / positions_exceeds_cap / evacuate_zone_not_number|negative). JSON.parse 의 number→float 자동 coercion 대응 — int/float 둘 다 수용 + `as int` cast. ch05 chapter JSON: `civilian_config = {positions: [[3,2],[5,3],[4,5],[4,7],[6,6]], evacuate_zone_max_col: 0}`. 다른 22 chapters 영향 0.
- [x] **CivilianToken entity + GridBattleController wiring** (`7151cd8`) — `src/feature/grid_battle/civilian_token.gd` 신규 (RefCounted + 3-state enum) + GridBattleController 6 methods: `set_civilian_config` (DI surface) / `get_civilian_tokens` (read-only snapshot) / `_civilian_commit_save` (SOLE mutator of `_fate_civilians_escorted`, lint-locked; emits `hidden_fate_condition_progressed`) / `_civilian_check_pickup_for_unit` (player turn-end 8-neighbor scan, capacity 1) / `_civilian_check_save_for_unit` (col ≤ zone_max_col → SAVED + counter) / `_civilian_recover_on_carrier_death` (ESCORTED → IDLE at death cell). 2 hooks: `_on_unit_turn_ended` fires save+pickup checks / `_on_unit_died` fires recovery. BattleScene chapter init 에 `set_civilian_config(chapter.civilian_config)` call 추가 (set_chokepoints 인접). 신규 `_fate_civilians_escorted` increment site — 이전 zero-stub `# TODO ch05; needs civilian system` 해소.
- [x] **Civilian sentinel tests** (`17425fd`) — 2 신규 test files (8 tests, 202 lines): `civilian_token_test.gd` (4 state machine unit tests — factory + 3 transitions, pure RefCounted, no SceneTree) + `ch05_civilian_evacuation_sentinel_test.gd` (4 data sentinels — token positions exact / evacuate_zone_max_col 0 / other 22 chapters empty civilian_config (ADR-0022 scope lock regression) / ★ scaffold hidden_branch_key + hidden_condition intact). 1954 baseline + 8 = 1962 PASS.

**Outcome**: ch05 ★ trigger (`WIN_xinye_civilians_saved`, `civilians_escorted >= 3`) 의 mechanical substrate 완성. Counter wiring + state machine + spawn-from-config + pickup/save/death hooks 모두 통과 (1962 PASS). Plan §11 Step 3 의 ~50% 진행 (4-6 sessions 중 본 세션 ~2 sessions 분량). **Pillar 2 의 첫 mechanical 증명** 의 substrate 완성 — 사용자가 ch05 도착 시 ★ branch 가 mechanically reachable.

**Deferred to next session**:
- Civilian visualization (Commit 5 — placeholder polygon + escort overlay, Gemini chibi 천장 제약으로 spec doc 까지만)
- GridBattleController integration tests (#8 pickup-on-end-turn / #9 save-on-zone-reach / #10 ★ trigger e2e fixture)
- 3 forbidden_pattern lint scripts (ADR-0022 §4 — 마지막은 awk flag/next TG-3 패턴)
- Manual playtest 후 token positions tuning (spec OQ-8)
- Plan §11 Step 4 진입 — ch08 적의동맹 ★ design (HiddenConditionEvaluator 재사용)

### S80 — ADR-0022 invariant lock + ★ trigger e2e mechanical proof (2026-05-24 session 80)

> **Driver**: S79 unlocked vector #3 (lint scripts ~30-50 min) + vector #2 (integration tests ~1 session). 사용자 결정 via AskUserQuestion 2회 — sequential vector pick. ADR-0022 의 invariant 가 lint-locked 되고 ★ trigger 가 mechanical 으로 e2e 증명된 상태로 S80 종결.

**Completed (3 commits, 1965/1965 PASS, push 완료)**:
- [x] **3 forbidden_pattern lint scripts + CI wire** (`726655d`) — ADR-0022 §4 의 모든 invariant 가 이제 CI gate. (1) `lint_civilian_token_no_node_subclass.sh` (bash grep — `extends Node/Node2D/Control/CanvasItem` 금지 + positive `extends RefCounted` assert). (2) `lint_civilian_token_no_static_var.sh` (bash grep 2-scope — civilian_token.gd 의 어떤 static var 도 금지 + grid_battle_controller.gd 의 `_civilian_*`/`_fate_civilians_*` static var 금지). (3) `lint_fate_civilians_escorted_single_mutator.sh` (**awk function-scope tracker, TG-3 family**) — `_fate_civilians_escorted = / += / -=` 는 `_civilian_commit_save()` body 안에서만; declaration line (`:` between name+`=`) / reads (`,`/`)`/etc.) / equality (`==`) 모두 정확히 excluded. 3 lint 모두 positive + negative test 통과 (synthetic violation injection → exit 1 + accurate `line:function:body` 컨텍스트 → revert PASS). `.github/workflows/tests.yml:127/129/131` 의 GBC lint cluster 에 wire.
- [x] **Civilian system e2e integration tests #8/9/10** (`a00a43e`) — `tests/integration/feature/grid_battle/grid_battle_controller_civilian_system_test.gd` 신규 (179 lines, 3 tests, spec §7 명세 그대로). (#8) `pickup_on_player_end_turn_adjacency` — 자연 turn-end pickup path 통과 (IDLE→ESCORTED + carrier_unit_id bind). (#9) `save_on_carrier_reaches_evacuate_zone` — two-phase (pickup→save) 로 `_on_unit_turn_ended` 의 save-before-pickup 순서 + SOLE mutator counter +1 path 검증. (#10) `ch05_three_civilians_saved_triggers_hidden_branch` — 3 force-SAVED → fate_data 의 controller-actual emit shape ↔ DefaultDestinyBranchJudge.resolve 의 HiddenConditionEvaluator fate_threshold 통과 → `WIN_xinye_civilians_saved` branch_key 정확히 routed. 1962 baseline + 3 = 1965 PASS / 0 errors / 0 failures / 0 regressions / 276 orphan baseline 유지.

**Outcome**: Pillar 2 의 "운명은 바꿀 수 있다" 가 **mechanical 증명 + lint-locked invariant** 양쪽 모두 확보. ADR-0022 §4 의 3 forbidden_patterns (Node 서브클래스 / static var / counter direct mutation) 가 CI gate 가 되어 미래 refactor / 다른 chapter civilian 재사용 시 invariants 가 자동 enforce. ★ trigger end-to-end mechanical proof (`_civilian_commit_save` → `_fate_civilians_escorted` → fate_data dict → HiddenConditionEvaluator → DestinyBranchJudge → `WIN_xinye_civilians_saved`) 가 1 integration test 로 결정. ch05 player 가 5 token 중 3+ escort 시 hidden ★ branch 가 mechanically reachable + 그 path 가 향후 regression 자동 차단됨.

**S79→S80 핸드오프 vector status**: #3 (lint) 종결 ✅ + #2 (integration) 종결 ✅. 잔존 4 vector — #1 visualization / #4 manual playtest / #5 ch08 ★ design / #6 S19 잔존 — S80→S81 핸드오프로 이관.

**Operational observation (codification candidate)**:
- **G-9 첫-run trap re-confirmed**: test #10 의 override_failure_message 가 `"...'%s'. " + "...%s,%s,%s,%d" % [args]` 패턴이라 `%` 연산자가 두번째 문자열에만 bind → 첫 `%s` 가 unmatched → `String formatting error: a number is required` stderr 폴루션 (assert pass 와 무관하지만 CI log 오염). 대응: concat 전체를 parens 로 감쌈. G-9 의 패턴이 1년 이상 stable — long string override_failure_message 작성 시 parens 디폴트 lint candidate.

## Reference

- 6-lens assessment 원본: 2026-05-22 S73 session (Producer / Game Designer / QA Lead / Technical Director / Art Director / Narrative Director 병렬 spawn)
- Master scenario: `design/scenarios/yeong_geol_jeon_shu_master.md`
- Current state snapshot: `production/session-state/active.md` (S72 close-out)
- Active workflow mode: `WORKFLOW.md` (Build, not Ratify since 2026-05-10)
