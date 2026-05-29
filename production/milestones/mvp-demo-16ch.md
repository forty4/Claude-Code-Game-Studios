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

### S81 — Civilian visualization (3-state polygons + carrier escort overlay) (2026-05-24 session 81)

> **Driver**: S80 핸드오프 vector #1 — ch05 ★ trigger 의 player-felt experience 가시화. mechanical + lint-locked + e2e proven invariants 위에 visual layer 추가 (counter HUD pulse 는 ADR-0015 BattleHUD 영역으로 S82+ deferred).

**Completed (1 commit, 1969/1969 PASS, push 완료)**:
- [x] **CivilianTokensVisuals + escort overlay + BattleScene wire** (`d602c11`) — 신규 `src/feature/battle_scene/civilian_tokens_visuals.gd` (Node2D, polling 기반, ChapterVisuals child mount). 3-state visuals 정합 (spec §4.3): IDLE = gray humanoid polygon visible at grid_cell / ESCORTED = polygon 숨김 (carrier overlay 인계) / SAVED = 0.3s alpha fade despawn (**G-31 tree-bound tween** + SceneTreeTimer failsafe — BattleScene PROCESS_MODE_DISABLED 대응). 4 새 unit tests (state-machine smoke + _ChapterVisualsStub 가 set_carrier_escort_overlay calls 기록). chapter_visuals.gd: `set_carrier_escort_overlay(carrier_unit_id, active)` 메소드 — EscortMarker child Polygon2D ~14px figure trailing on carrier polygon (warm-sand color, ~22px offset). battle_scene.gd: `_mount_civilian_tokens_visuals(visuals)` after `_mount_hp_bars`; refresh hooks on `_on_unit_turn_ended_visual` (controller pickup/save check runs before this re-emit) + `_on_unit_died_visual` (controller recovery runs before unit_visual_died.emit per grid_battle_controller.gd:1276). Empty civilian_config chapters get a cheap empty-visualization node (defensive). 1965 baseline + 4 = 1969 PASS / 0 errors / 0 failures / 0 regressions / 276 orphan baseline 유지.

**Outcome**: ch05 ★ trigger 가 mechanical (S79) + lint-locked (S80-A) + e2e proven (S80-B) + **player-felt visualized (S81)** 4-layer 안정성 완성. Polygon placeholder 는 향후 chibi sprite asset 으로 clean swap 가능 (rendering 분리 구조). Counter HUD pulse 는 S82+ candidate (ADR-0015 BattleHUD 의 hidden_fate_condition_progressed subscription 함수 wiring 필요).

**S81 carry-over to S82+** (사용자 합의 필요): #4 manual playtest (now with visualization — 자연 felt) / #5 ch08 ★ design (Plan §11 Step 4, entity-less) / #6 S19-D windowed playthrough / Counter HUD pulse (BattleHUD wiring).

**Operational observation**:
- **G-31 4번째 stable instance**: civilian SAVED fade tween 이 `get_tree().create_tween()` 사용. BattleScene 산하 (PROCESS_MODE_DISABLED 가능 노드 의 child) 의 tween 은 모두 tree-bound. SceneTreeTimer failsafe 동반 패턴 (death-fade 와 동일).
- **Visualization 분리 구조 ROI**: 사용자 design choice (별도 sibling node) 가 향후 chibi asset 교체 시 clean swap 가능하게 함. chapter_visuals 통합 변경 시 한 곳에서 모두 처리되지만 _draw() 가 grow 함. polling 기반 + state diff 가 lifecycle hook 으로 자연 trigger.

### S82 — Pillar 2 lock + ch08 ★ alliance timing impl (2026-05-25 session 82)

> **Driver**: S81 핸드오프 vector "Counter HUD pulse" → critical Pillar 2 conflict 발견 + ch05 spec amendment + S82 새 vector "#5 ch08 ★ design" 진입. 결과: 본 세션 ch05 amendment + ch08 spec authoring + impl arc 의 3 sub-vector 동시 진행.

**Completed (5 commits, 1969→1976 PASS, push 완료)**:
- [x] **ch05 spec §4.3 amendment** (`3c10ee1`) — counter HUD pulse 항목 제거 (Pillar 2 정합). `lint_battle_hud_hidden_fate_non_subscription.sh` zero-tolerance grep 위반 발견 ("If HUD subscribes and renders any visual at Beat 6 results screen, Pillar 2 contrast collapses"). S79 spec authoring 시 ADR-0015 + Pillar 2 lock 검토 누락. §4.3 inline Amendment block 추가 + §8 OQ-9 codification (spec authoring rule strengthening — Pillar lock + critical lint 사전 검토). 코드 변경 0 (S81 visualization impl 이 우연히 정합).
- [x] **ch08 spec authoring** (`cb53059`) — `design/quick-specs/ch08-alliance-timing.md` 신규 (151 lines, 8 sections). Plan §4.2 의 "결의의 timing" ★ entity-less light path. 핵심 design 결정 (turn-limit + REACH_TILE 유지 + echo_threshold 1 유지 + ★ branch name 유지) batch 잠금. ADR 신규 불필요 (ADR-0017/0018 재사용).
- [x] **ch08 spec correction** (`b23d825`) — `turn_count` (hypothetical) → `win_within_turns` (substrate-aligned, grid_battle_controller.gd:3362 VICTORY-outcome auto-set field). impl 전 substrate 검증 으로 발견. §2/§3.1/§3.3/§4.1/§6/§7/§8 일괄 정정. §8 OQ-8 codification (spec authoring 시 fate_data emit shape 의 정확한 field name 사전 검증 — ch05 OQ-9 와 same family). 코드 변경 0.
- [x] **ch08 data + sentinel + S59 test refresh** (`e8e3d1e`) — `assets/data/scenarios/shu_canon_main.json` ch08 hidden_condition 교체 (formation_turns >= 3 → win_within_turns <= 6). 신규 sentinel test (4 tests, 130 lines): hidden_condition exact shape / REACH_TILE [13,4] / branch_table+routing locks / `win_within_turns` substrate present in controller (grep-style). `scenario_runner_victory_conditions_hydration_test.gd:275` S59-era sentinel 도 amendment 반영 update (3 assertion 한꺼번에 refresh).
- [x] **ch08 integration tests** (`e9b842e`) — `tests/integration/destiny_branch/ch08_alliance_timing_branch_routing_test.gd` 신규 (3 tests, 130 lines). win_within_turns=6 → `WIN_xiakou_united_advance` (★) / =7 → `WIN_xiakou_breakthrough` (canonical) / LOSS → `LOSS_xiakou_pursuit_continues`. ch05 e2e pattern reuse (programmatic ChapterDefinition fixture + DefaultDestinyBranchJudge.resolve). 1969 baseline + 7 = 1976 PASS.

**Outcome**: **2 ★ trigger ship-ready** (out of MVP 5) — ch05 4-layer (mechanical + lint + e2e + visualization) + ch08 2-layer (substrate + e2e). ch08 는 entity-less 라 visualization 불필요 + lint 도 spec 변경 만 (forbidden_pattern 신규 없음). Pillar 2 lock 의 명시적 codification (ch05 §8 OQ-9 + ch08 §8 OQ-8) — 향후 spec authoring rule strengthening 의 2번째 instance.

**S82 carry-over to S83+** (사용자 합의 필요): #4 manual playtest (ch05 visualization 으로 자연 felt + ch08 의 turn-limit 조건 검증) / #6 S19-D windowed playthrough / #5 다음 단계 ch10 또는 ch13 또는 ch16 ★ design (entity-less recipe 가 ch08 처럼 가벼움 보장).

**Operational observation (codification value)**:
- **Spec authoring rule strengthening — 2nd instance**: ch05 OQ-9 (Pillar lock 검토) + ch08 OQ-8 (fate_data field name 사전 검증) 가 같은 pattern family (spec authoring time 의 substrate / lock 검토 누락). 향후 `.claude/rules/design-docs.md` 의 amendment 후보 — 새 spec 첫 commit 전에 `grep -l "Pillar\|CRITICAL" docs/architecture/ADR-*.md tools/ci/lint_*.sh` + `grep -n '"<expected_field>":' src/` 의 standard sub-checklist.
- **운 좋은 conflict 발견 cadence**: ch05 counter HUD pulse 가 S81 visualization 시점 not S79 spec authoring 시점에 발견 + ch08 substrate misalignment 가 impl 시점에 발견. 둘 다 *impl 전* 에 found 되어 silent bug 회피. spec authoring 의 design intent 와 substrate 의 정합은 manual review 가 아닌 codified pre-flight check 가 필요.
- **★ trigger weight 계층**: ch05 (entity 신규 = 8 commits + visualization layer + lint cluster) vs ch08 (entity-less = 3 commits, no visualization, no lint). 3-5배 차이. Plan §4 의 ch10/13/16 ★ 가 ch08-style entity-less 면 MVP 5 ★ 완성 의 작업량 예측 가능 — ch05+ch20-cluster (Full Vision cascade-block) 만 heavy.

### S83 — ch13 + ch16 sentinel-only ★ verification (2026-05-25 session 83)

> **Driver**: S82 핸드오프 vector "ch13/ch16 sentinel-only ★ trigger verification" (가장 light progress). 둘 다 기존 impl + chapter data + substrate 모두 wired — sentinel + integration tests 만 추가하여 ship-ready 가시화.

**Completed (1 commit, 1976→1989 PASS, push 완료)**:
- [x] **ch13 + ch16 sentinel + e2e routing** (`a94443d`) — 8 files / 308 lines / 13 tests:
  - **ch13 위연 합류** (Plan §4.4 reference ★) — 3 sentinel + 3 integration. hidden_condition `{wei_yan_spared_turns >= 3}` exact / branch_table+routing locks (echo_threshold=2) / substrate 3-layer grep in controller (decl + increment + emit). e2e: at 3 → `WIN_changsha_wei_yan_defects` (★) / at 2 → `WIN_changsha_taken` (canonical) / LOSS → `LOSS_changsha_repelled`.
  - **ch16 방통 생존** (Plan §4.5 reference ★) — 4 sentinel + 3 integration. hidden_condition `{scout_first_turns >= 2}` / branch_table+routing (echo_threshold=3, highest scarcity) / victory_conditions SURVIVE_N_ROUNDS+survive_rounds=4 unchanged / substrate 3-layer grep. e2e: at 2 → `WIN_luofeng_pang_tong_lives` / at 1 → `WIN_luofeng_kongming_arrives` / LOSS → `LOSS_luofeng_ambush_complete`.
  - **Substrate 정합 사전 검증** (S82 trap 재발 방지): 둘 다 `_fate_wei_yan_spared_turns` + `_fate_scout_first_turns` 의 3-layer (declaration / increment / fate_data emit) 완전 wired 확인 후 작업. S82 ch08 의 hypothetical field name 함정 회피.

**Outcome**: **MVP 4/5 ★ ship-ready 가시화 완성**.
  - ✅ ch05 (4-layer: mechanical + lint + e2e + visualization, S79-S81 8 commits 누적)
  - ✅ ch08 (2-layer: substrate-aligned + e2e, S82 3 commits)
  - ✅ ch13 (sentinel + e2e, existing impl verified, S83)
  - ✅ ch16 (sentinel + e2e, existing impl verified, S83)
  - ⏳ ch10 (Plan §4.3 동남풍, substrate 부재 — `_fate_all_player_units_alive` 또는 design simplification 필요)

**Entity-less e2e recipe pattern stable at 4 instances**: ch05 + ch08 + ch13 + ch16. programmatic ChapterDefinition fixture + DefaultDestinyBranchJudge.resolve, no controller wiring 필요. ch10 spec authoring + impl 시 같은 recipe 적용 (substrate 새 field 추가 후).

**S83 carry-over to S84+** (사용자 합의 필요):
- **ch10 ★ design** (마지막 ★, ~3-4 commits) — spec + new substrate field `_fate_all_player_units_alive` (또는 design simplification: turn-limit only, Plan §4.3 의 "전원 생존" drop). chapter data 의 branch_table + hidden_condition 신규 author 필요. 가장 큰 progress next.
- **#4 Manual playtest** (사용자, ~10-15 min) — ch05 visualization felt + ch08/13/16 ★ trigger 검증.
- **#6 S19-D windowed playthrough** (사용자, ~8분 + Bug bash) — 전체 vertical-slice 재 attest.
- **Codification work** — `.claude/rules/design-docs.md` 의 spec authoring pre-flight check sub-checklist amendment (S82 운영 관찰 #1 codify). ~30분.

**Operational observation**:
- **Sentinel-only path 의 ROI**: 기존 impl + substrate 둘 다 wired 인 chapter 의 sentinel-only 작업 = 1 commit / 13 tests / +0 production code. 가장 가벼운 ★ ship-ready 가시화 방법. ch10 외 ch04/06/07/09/11/12/14/15 (default-only chapters, 8개) 도 sentinel 의 가치는 있으나 ★ 아니므로 명시적 priority 낮음 — branch_table 의 default-only regression sentinel 만 가능.
- **Substrate 3-layer grep pattern**: sentinel test 가 production source 의 declaration + increment + emit 3-layer 를 grep-style 검증. future refactor 가 어떤 layer 라도 drop 시 즉시 fail. ch08 의 `win_within_turns substrate present` test + ch13/16 의 `<field> substrate present` 모두 동일 패턴 — codification candidate (`tests/helpers/` 의 reusable substrate-check 헬퍼?).

### S84 — ch10 적벽 동남풍 perfect wind ★ — 🎯 MVP 5/5 ★ SHIP-READY 달성 (2026-05-25 session 84)

> **Driver**: S83 핸드오프 vector "ch10 ★ design + impl" — MVP 5/5 ★ ship-ready 의 마지막 step. 단일 권장 path (substrate 새 field `_fate_player_casualties` add + ch08 model entity-less impl) batch 잠금 + 4-commit arc 완성.

**Completed (4 commits, 1989→1996 PASS, push 완료)**:
- [x] **ch10 quick-spec** (`3cb91bd`) — `design/quick-specs/ch10-chibi-perfect-wind.md` 신규 (165 lines, 8 sections). Plan §4.3 "동남풍 perfect timing — 전원 생존" mechanical lock. 핵심 design 결정 single-batch 잠금: substrate `_fate_player_casualties` 신규 add / hidden_condition `player_casualties <= 0` / victory_conditions SURVIVE_N_ROUNDS+survive_rounds=5 유지 / ADR 신규 불필요 (ADR-0014 additive minor amendment). §8 OQ-8 — ch08 codification series 의 3번째 instance (ch05 §4.3 Pillar lock + ch08 §3.3 substrate verification + ch10 §3.1 substrate add 의 inverse case).
- [x] **Substrate 3-layer add** (`2f9beef`) — `grid_battle_controller.gd` +13 lines: declaration line 425+ / increment site in `_on_unit_died` BEFORE `unit_visual_died.emit` (`side==0` filter) / fate_data emit 17번째 entry. ch10 외 chapter 영향 0 (substrate expose 단 hidden_condition.field 가 chapter 별 다르므로 routing 영향 없음). 1989 PASS / 0 regression.
- [x] **ch10 ★ entry author + sentinel** (`05014c3`) — chapter JSON 의 branch_table 에 `WIN_hidden: "WIN_chibi_perfect_southeast_wind"` + `hidden_branch_key` + `hidden_condition` 신규 author. canonical_branch_key + echo_threshold=2 + victory_conditions 모두 변경 없음. 신규 sentinel test (4 tests, 120 lines, ch13/16 pattern reuse). 1993 PASS.
- [x] **ch10 integration e2e** (`e1fa181`) — `tests/integration/destiny_branch/ch10_chibi_perfect_wind_branch_routing_test.gd` 신규 (3 tests, 90 lines). player_casualties=0 + WIN → `WIN_chibi_perfect_southeast_wind` (★) / =1 + WIN → canonical / LOSS → loss. ch08/ch13/ch16 e2e pattern reuse (5th instance of entity-less recipe). 1996 PASS.

**Outcome**: 🎯 **MVP 5/5 ★ SHIP-READY 달성**. Plan §4 의 MVP ★ 5 모두 mechanically reachable + lint/sentinel-locked + e2e mechanical proof + (ch05) player-felt visualized. Pillar 2 의 "운명은 바꿀 수 있다" 의 핵심 mechanical substrate 완성.

**★ ship-ready 최종 표 (S84 close)**:
  - ✅ ch05 신야 백성 evacuation (4-layer: mechanical + lint + e2e + visualization, S79-S81 8 commits)
  - ✅ ch08 하구 적의동맹 timing (2-layer: substrate-aligned + e2e, S82 3 commits)
  - ✅ ch10 적벽 동남풍 perfect wind (substrate add + 2-layer, S84 4 commits)
  - ✅ ch13 장사 위연 합류 (sentinel-only, S83)
  - ✅ ch16 낙봉파 방통 생존 (sentinel-only, S83)

**S84 → S85+ carry-over** (사용자 합의 필요):
- **#4 Manual playtest** (사용자, ~10-15 min) — 5 ★ trigger 모두 felt validation. **가장 시급한 next**.
- **#6 S19-D windowed playthrough** (사용자, ~8분 + Bug bash) — 전체 vertical-slice 재 attest.
- **Codification work** — `.claude/rules/design-docs.md` amendment (spec authoring pre-flight check, S82+ codification series 3 instances 안정 base) + `tests/helpers/` reusable substrate-check 헬퍼 (`assert_fate_field_substrate(field_name)`). ~45분 합산.
- **Full Vision** — ch20-22 cascade-block ADR / hero balance / banter 확장 / Wei line / etc.

**Operational observation (S84)**:
- **Entity-less recipe pattern stable at 5 instances**: ch05 outlier (entity heavy) + ch08/10/13/16 모두 entity-less e2e (programmatic ChapterDefinition fixture + DefaultDestinyBranchJudge.resolve, no controller wiring). 5번째 invocation 으로 pattern strongly stable — `tests/helpers/` 의 `_make_chN_fixture` reusable helper 후보 (codification work 의 일부).
- **Substrate add pattern stable at 2 instances** (S79 civilian + S84 player_casualties): 3-layer (declaration + increment site + fate_data emit) 추가 + sentinel 3-layer grep. 둘 다 ch10 외 chapter 영향 0 (additive). 향후 Full Vision ch20-22 cascade-block 의 새 substrate (`_fate_brothers_lost: int` 같은) 도 same pattern 적용 가능.
- **본 컨버세이션 cumulative weight (S80→S84)**: 22 commits. 1962→1996 PASS (+34 tests / 0 regressions). 4-layer ★ (ch05) + 2-layer ★ × 4 (ch08/10/13/16) = MVP Pillar 2 mechanical complete. 다음 큰 MVP work = manual playtest 후 balance tuning + ch01 같은 default chapter 의 narrative polish (S78 pattern 확대) + Full Vision design.

### S85 — Codification work (FateSubstrateAssertions + design-docs pre-flight) (2026-05-25 session 85)

> **Driver**: S84 운영관찰 #1 "Codification work 의 stability 형성 완료" 시점 활용. 4 stable patterns 중 가장 명확 ROI 2개 (substrate 3-layer grep + spec authoring pre-flight check) 잠금. Refactor 만 (production behavior 0 change).

**Completed (1 commit, 1996 PASS 유지, push 완료)**:
- [x] **FateSubstrateAssertions helper + design-docs pre-flight checklist** (`013061e`) — 7 files / +143/-61:
  - `tests/helpers/fate_substrate_assertions.gd` 신규 (84 lines, `class_name FateSubstrateAssertions extends RefCounted`) — `assert_substrate_present(suite, field_name, var_name, chapter_label)` static method 가 production source 의 3-layer grep (declaration / `<var> += 1` increment / `"<field>": <var>` fate_data emit). chapter_label 가 failure message 에 포함 → cross-chapter 진단 명확.
  - ch10/ch13/ch16 sentinel test 의 3-layer grep tests refactor — 18-23 lines/test → 4 lines/test. unused `GRID_CONTROLLER_PATH` const 3 file 모두 제거. ch08 는 `_fate_win_within_turns = ` (`=` set 가 아닌 `+=` 패턴) 라 generic helper 적용 불가 — inline 유지 + comment cross-ref.
  - `.claude/rules/design-docs.md` amendment: paths 에 `design/quick-specs/**` 추가 (기존은 gdd/만 cover, 본 컨버세이션의 ch05/ch08/ch10 spec 들은 quick-specs/) + §"Pre-Flight Checklist" 신규 (50 lines, 3 checks before drafting):
    1. Pillar lock + critical lint inventory (`grep 'Pillar|CRITICAL|KEEP forever' ADR + lint`) — ch05 §8 OQ-9 codification
    2. fate_data emit substrate verification (`grep '"<field>":' grid controller`) — ch08 §8 OQ-8 codification
    3. Recommended path framing for design questions (single recommended + 3-option confirm, avoid stacked AskUserQuestion grids) — S82 mid-session feedback codification
  - 각 instance 의 historical cost 명시 (~30-90 min/instance vs ~2-5 min pre-flight). ROI heavily favors pre-flight discipline.

**Outcome**: 4 stable patterns 중 2개 codification 잠금 완료. 향후 spec authoring 작업 + chapter ★ sentinel work 모두 reusable helper + standardized pre-flight 활용 가능. Production behavior 0 change — pure infrastructure investment.

**Codification series status**:
- ✅ Spec authoring pre-flight checklist (3 instances → design-docs.md amendment)
- ✅ Substrate 3-layer grep sentinel (4 instances → FateSubstrateAssertions helper)
- ⏳ Entity-less e2e recipe (5 instances stable, helper extraction deferred — 5 file refactor 가 substantial work, S86 candidate)
- ⏳ Substrate add 3-layer pattern (2 instances, 3rd 가 lands 시 ADR template subsection)

**S85 → S86+ carry-over**:
- **#4 Manual playtest** (사용자, ~10-15 min) — 5 ★ trigger 모두 felt validation. **가장 시급한 next** — 본 컨버세이션 24 commits 의 player-felt 검증.
- **#6 S19-D windowed playthrough** (사용자, ~8분 + Bug bash) — 전체 vertical-slice 재 attest.
- **Entity-less e2e recipe helper extraction** (~30분, 5 file refactor) — `tests/helpers/destiny_branch_fixtures.gd` 의 `make_ch05_fixture` / `make_ch08_fixture` / ... 같은 reusable factory. ch05+ch08+ch10+ch13+ch16 e2e test 들 refactor.
- **Full Vision** — ch20-22 cascade-block ADR / hero balance / banter 확장 / Wei line / ch24/25 salvage register.

**Operational observation (S85)**:
- **Refactor commit 의 anatomical cleanness**: codification 의 refactor 가 단일 commit 으로 3 file behavior 변화 0, production code 변화 0, full suite PASS 유지. 안전한 infrastructure work 의 reference pattern — 향후 helper extraction / standardization work 도 같은 cadence (helper 신규 + 사용처 refactor + rule amendment + verify + commit) 가능.
- **Codification 의 ROI 명시**: design-docs.md amendment 의 pre-flight check 3개가 모두 본 컨버세이션의 spec authoring 실수 historical cost (30-90분 × 3 instance ≈ 1.5-4.5 hour debt) 위에 세워졌음. 본 amendment 작성에 ~10분 — 향후 1 instance 만 catch 해도 break-even, 그 이후는 모두 ROI.

### S86 — Manual playtest + gameplay depth pivot + input gate fix (2026-05-25 session 86)

> **Driver**: S85 핸드오프 #1 "Manual playtest 5 ★ trigger felt validation" 실행. 사용자 raw report 가 "재미없음 / 난이도 너무 낮음 / 공격수단 평타뿐 / S 키 차이 없음" — 단일 issue 가 아닌 layered UX gap. 3차 진단 끝에 critical root cause (InputRouter `_did_visible_work` gate) 확정 + fix. ★ ship-ready mechanical 은 유지 (S84 그대로), player-felt fun gap 정직히 인정.

**Completed (3 commits, 1996 PASS 유지, push 완료)**:

- [x] **gameplay: Shu 4 skill wire + ch02-25 atk_mult 0.95 + 제갈량 mobility** (`e987ac3`):
  - heroes.json: shu_006_zhuge_liang.move_range 3 → 4
  - shu_canon_main.json: ch02-25 enemy_atk_mult 0.55-0.8 → 0.95 통일 (ch01 baseline)
  - grid_battle_controller.gd: 4 Shu skill wire — skill_fire_strategy (제갈량, Manhattan ≤ 3 적 20 dmg + slow) / skill_lone_lance (조운, pending +75% if alone) / skill_xiliang_charge (마초, cardinal axis 20 dmg) / skill_successor_strategy (강유, 최저 HP ally 25 heal + action refund). 새 _lone_lance_pending var + _resolve_attack hook for lone-ness check.
  - 진단: 사용자 보고 "공격수단 평타뿐" root cause = 9 skill unwired (이번에 4 추가; Wei 5 남음).

- [x] **hud: i18n 활성 + ko.po + UI-GB-02 강조** (`f1779ff`):
  - assets/locale/ko.po 신규 (27 keys 완전 한국어 번역) + assets/locale/en.po 동일 keys
  - project.godot `[internationalization]` section + en.po + ko.po 등록 + fallback=en. **Pre-S86 nothing registered** → tr() 가 raw key 반환 → button "hud.action.move" 같은 invisible text 표시.
  - scenes/battle/elements/ui_gb_02_action_menu.tscn: anchors_preset 7 (bottom-center) + button 96×56 + grow_horizontal=2. **Pre-S86 layout 이 좌상단 (0,0) tiny** — 사용자 시선 안 닿음.
  - tests 3 file fix (battle_hud_unit_info / battle_hud_safe_tr_format / battle_hud_forecast): TranslationServer.set_locale 강제로 deterministic. unit_info 의 raw-key assertion 들 영문 expected ("Class: Cavalry", "ATK 17") 으로 변경.

- [x] **fix(input): use_skill/defend_stance emit gate + banner + 1.15 atk_mult** (`879dd2f`) — **🔴 Critical root cause fix**:
  - **InputRouter `_did_visible_work` emit gate**: `_handle_action_in_s0` + `_handle_action_in_s1` 의 match arm 에 use_skill + defend_stance arm **부재** → `_did_visible_work=false` → GameBus.input_action_fired.emit() gate (line 935) 가 silently 차단 → controller `_on_input_action_fired` 가 받지 못함. S0 + S1 arm 둘 다 추가하여 `_did_visible_work = true` set.
  - S/D 키 selection-less fallback (controller `_handle_use_skill_input` + `_handle_defend_stance_input`): unit click 없이 active turn unit (player) 의 skill/defend 발동.
  - 숫자 키 1/2 alternative binding (default_bindings.json): macOS IME 우회 대비 (실제 IME 영향 없음 confirmed via [KEY-DIAG] trace).
  - 화면 상단 큰 노란 turn banner (battle_hud.gd `_turn_banner: Label`): 활성 unit + skill name + skill desc + key hints `[S/1] [D/2] [Tab]`. Pre-S86 UI-GB-07 turn label (좌상단, font 14, "Turn: 조운") 가 사용자 시선 안 닿음.
  - ko.po + en.po: 18 skill display name keys + 18 skill desc keys + banner template `▶ %s의 턴   |   스킬: %s — %s [S/1]   |   방어 [D/2]   |   턴 종료 [Tab]`.
  - ch01-25 atk_mult 0.95 → 1.15 (추가 강화 +21%). ch01_vertical_slice_sentinel_test 도 1.15 expected 로 update.
  - test 1 update: grid_battle_controller_player_defend_test 의 "no-op when no selection" → "fallback to active turn unit" (design intent flip).

**Outcome**: **3차 진단 끝에 S/D/1/2 키 routing fix 확정**. user verify 로 관우 dragon_blade / 유비 inspire / 장비 thunder_roar 발동 확인 (console log: `[USE_SKILL] dispatching ... unit.skill_used=false → true`). 사용자 last battle 결과: TURN_LIMIT_REACHED (DRAW) — 1.15 도 부족 가능, 추가 bump candidate.

**S86 — 사용자 raw report 의 layered nature (codification candidate)**:

| Layer | Root cause | Status |
|---|---|---|
| Mechanical | 9 skill unwired + S 키 routing broken (emit gate) | ✅ 4 wire + gate fix 완료 |
| Discoverability | i18n raw key + UI-GB-02 좌상단 tiny + UI-GB-07 작은 글자 | ✅ ko.po + bottom anchor + 큰 banner |
| Visual feedback | damage popup 만, skill 특별감 0 (no particle / no SFX-specific) | ⏳ multi-session particle work (S87+) |
| Balance | atk_mult 0.55-0.8 (5 chapter) + 일관성 부재 | ✅ 1.15 통일 (추가 bump candidate 남음) |

**3차 진단 timeline** (S 키 routing fix 의 painstaking trace):
1. 1차 가설: macOS 한국어 IME 가 S 키 가로챔 → 숫자 1/2 alternative key 추가
2. user verify: 1/2 도 작동 안 함 → IME 반증
3. 2차 진단: input_router 에 `[KEY-DIAG]` trace 추가 → keycode 정상 도달 + InputMap MATCH 정상 → controller routing 문제 추정
4. 3차 진단: controller 에 `[USE_SKILL]` trace 추가 → handler 진입 trace 0건 → InputRouter 의 emit gate 가 silent block 추정
5. Source 읽기: `_handle_action` line 934 `if _did_visible_work: emit(...)` 발견 → `_handle_action_in_s1` match arm 에 use_skill 없음 확인 → root cause 확정

**S86 → S87 (next session) 핸드오프**:

1. **#1 Particle effect per skill** (multi-session, ~5-10h total, 사용자 명시적 선택) — 14+ skill 의 unique visual:
   - 화공 전략 (제갈량): Manhattan ≤ 3 cells 의 fire particle
   - 천둥 포효 (장비): adjacent cell lightning burst
   - 청룡의 칼날 (관우): caster yellow glow + sword swing trail
   - 단신 돌격 (조운): caster lone-position indicator + lance line
   - 격려 (유비): adjacent ally green pulse
   - 그 외 9+ skill. ~30-60min/skill.

2. **#2 InputRouter codification (~15분)** — process improvement:
   - `.claude/rules/godot-4x-gotchas.md` 의 새 G-N entry: "InputRouter emit gate — `_did_visible_work` flag must be set in per-state action arm OR action silently drops at line 935"
   - lint script `tools/ci/lint_input_router_action_arm_coverage.sh` — _GRID_ACTIONS 의 모든 action 이 _handle_action_in_s0/s1 match arm 에 표현되는지 검증

3. **#3 추가 atk_mult bump candidate** (data fix, ~5분) — 사용자 last battle TURN_LIMIT_REACHED (DRAW) = enemy wipe 못 함. 1.15 → 1.3 또는 1.5 후보. windowed verify 후 결정.

4. **#4 UI-GB-02 button click verify** — banner + S 키 작동 확인됨, 그러나 사용자가 자기 unit click 시 화면 하단 button 6개 실제 보이는지 미보고. anchor 좌상단 → bottom-center 변경 효과 verify 필요.

5. **#5 ch05 ★ manual playtest** (S85 핸드오프 #1 잔존) — civilians_escorted >= 3 trigger 시도. 사용자가 ch01-04 만 시도, ch05+ 미진행.

6. **#6 Full Vision** (multi-session) — S85 핸드오프 #4 그대로.

**Critical path ranking**:
- 가장 시급한 next: **#1 Particle effect** (사용자 명시적 선택)
- 가장 light next: **#2 codification + #3 atk_mult 1.5 bump**
- 가장 큰 future work: **#6 Full Vision**

**Operational observation (S86)**:
- **User telemetry > developer hypothesis**: IME 가설이 plausible 했지만 사용자 console log 의 정확한 [KEY-DIAG] data 가 그것 반증. user-reported reality 가 first-class. 첫 가설에 매몰되지 말고 user 가 직접 보낸 data 우선.
- **Layered UX gap diagnosis**: "재미없음" 같은 단일 사용자 보고가 actually 여러 layer 의 root cause 조합. 진단 시 surface-level fix 만 시도하면 underlying issue 누락 위험. mechanical + discoverability + visual + balance 의 4 layer 모두 inspect 필요.
- **Selection-less fallback pattern**: 사용자 UX flow 가 "click then key" 이 아닌 "key directly" 일 수도. controller handler 들에 active turn unit fallback 추가 = UX simplification + felt 향상 — 다른 systems 도 같은 pattern 가능 (예: 미리보기 dismiss, 카메라 control).

### S92 — G-30 windowed verify → Inventory Panel 다층 버그 연쇄 fix (2026-05-29 session 92)

> **Driver**: S91 핸드오프 #1 (G-30 windowed verify) 를 사용자가 직접 실행 → Inventory Panel 이 windowed 에서 작동 안 함 발견. 4-layer diagnostic (G-32 패턴) 으로 3개 연쇄 버그 추적. headless 2068/2068 PASS 인데 windowed 3중 실패 = G-30 교과서 사례. 세션 종료 시 button-click 1건 UNCONFIRMED 상태 핸드오프.

**상태: 2068/2068 PASS 유지 (0 errors / 0 failures / orphan 296→298 non-blocking). view-layer fix 라 headless test count 변동 없음 (G-30 — windowed 에서만 검증 가능).**

- [x] **버그 #1 — chapter starting_inventory_by_hero 미author (FIXED)** — Phase B step 8 loader 는 wired 됐으나 `assets/data/scenarios/shu_canon_main.json` 의 어떤 chapter 도 inventory field 미author → 모든 슬롯 빈 칸 (`inv_size=0`). ch01 에 추가: 유비 `[heal_potion]` / 장비 `[heal_potion, strength_scroll]` / 관우 `[strength_scroll, fire_scroll]` (사용자 결정 = fire_scroll 포함으로 G-30 (d) verify 가능). ch02-16 미author (후속 batch).
- [x] **버그 #2 — BattleHUD root size (0,0) → panel 음수 좌표 (FIXED, 중대)** — `battle_hud.gd:_ready()` 의 `set_anchors_preset(PRESET_FULL_RECT)` 가 keep_offsets=false 디폴트 → 인스턴스 시점 (0,0,0,0) rect 유지하려 offsets 재계산 → size (0,0) stuck → child anchor 계산이 parent_size=(0,0) 사용 → panel_pos=(-80,-148) 화면 밖. Fix: `set_anchors_and_offsets_preset(PRESET_FULL_RECT)` → (780,876) 정상화. UI-GB-15 positioning 도 명시적 anchor/offset 으로 변경. **godot-4x-gotchas G-33 codify 후보.**
- [ ] **버그 #3 — slot button click 무반응 (UNCONFIRMED — S93 BLOCKER)** — panel 보임 + button rect 정상인데 클릭 시 gui_input 자체 미수신 (grid unit click 은 정상). leading 가설 = Godot 4.x Container 디폴트 MOUSE_FILTER_STOP 가 자식 Button 전에 click swallow. 적용 fix (UNTESTED): UI-GB-15 PanelContainer=STOP, 내부 VBox/HBox=PASS 명시. **세션 종료 전 windowed 재검증 못 함 → S93 최우선.**
- [x] **UX clarity 개선 (사용자 선택)** — `ui_gb_15_inventory_panel.tscn` 전면 개편: StyleBoxFlat 배경 (검정 0.92 + 금색 테두리) + "인벤토리" 제목 + 360×120 확대 + 슬롯 균등분배. `_glyph_for_item` 가 "● 회복약" (glyph+이름). `_flash_inventory_success` = SELF 발화 성공 시 "● 회복약 사용 (+25)" 0.6초 표시 후 자동 close (기존 silent close 대체).

**S92 핵심 결정**: (1) CanvasLayer 자식 Control 풀-viewport 는 반드시 `set_anchors_and_offsets_preset` (set_anchors_preset 아님). (2) Container 자식에 click 통과는 컨테이너 PASS 명시 필요 (UNCONFIRMED). (3) ch01 fire_scroll 포함으로 G-30 (d) 즉시 검증. (4) 발화 0.6초 피드백 dwell = Pillar #5 작동 인지 최소 UX.

**S92 → S93 핸드오프**: **최우선 = 버그 #3 button-click windowed re-verify** (mouse_filter PASS fix 가 정답인지). 그 후 버그 #2 fix 의 HUD-01~14 regression 확인 → G-30 verify 4 동작 완주 → ch02-16 inventory authoring batch. 상세는 `production/session-state/active.md` S92 섹션.

### S91 (follow-up arc) — Phase B view-layer + save wiring polish (2026-05-27 session 91 follow-up)

> **Driver**: After step 6+9 push + session-end request, the user resumed with "다음 진행" + AskUserQuestion-picked sequence: UI-GB-17 tile-click → 8b save side → UI-GB-16 per-polygon → i18n + tooltips. 4 follow-up commits in this continuous arc; Phase B follow-up 4/5 closed (G-30 windowed verify + 8b LOAD side both deferred for user action / mid-battle save trigger).

**Completed (4 commits, 2051 → 2068/2068 PASS / 0 errors)**:

- [x] **UI-GB-17 target tile-click confirmation (commit `a89879d`, +6 tests)** — Closes the Phase B step 9 follow-up TODO inlined in 571210a. Controller `_item_target_armed: bool` field + `set_item_target_armed(armed)` setter + `_TILE_CLICK_ACTIONS` const (unit_select / move_target_select / move_confirm / attack_target_select / attack_confirm). When armed, `_on_input_action_fired` silently skips tile-click actions so HUD owns the click. Unit-scoped key actions (use_item / use_skill / defend_stance) stay live. BattleHUD `_handle_item_target_click(ctx)` validates ctx.target_coord against `get_item_target_tiles` whitelist + calls `use_item(uid, slot, coord)`. Out-of-range click flashes `item.reject.target_invalid`. Slot click arms; close/success disarms. GridBattleControllerStub extended with 4 spy recorders.
- [x] **8b SaveContext snapshot wiring — save side (commit `9656cad`, +10 tests)** — Closes the SAVE half of EC-SS-9 round-trip. BattleScene `get_per_unit_strategy_snapshot()` collects player-only (side==0) non-empty inventory + pending_buff from `_grid_controller._units` (G-2 safe copy via assign). Returns `{"inventory":{uid → Array}, "pending_buff":{uid → Dict}}`. BattleScene `apply_per_unit_strategy_snapshot()` restore-side helper for future mid-battle save resume — skips unknown unit_ids + enemy-side defensively. ScenarioRunner `_collect_active_battle_strategy_snapshot()` pull pattern queries `SceneManager._battle_scene_ref` (defensive has_method). `_make_save_context` populates `ctx.per_hero_inventory_snapshot` + `per_hero_pending_buff_snapshot`. LOAD side deferred (no mid-battle save trigger). New `FakeBattleSceneWithSnapshot` test helper.
- [x] **UI-GB-16 per-polygon multi-unit attachment (commit `cda5f94`, no new tests)** — Extends UI-GB-16 from single HUD-level glyph (active-unit-only) to per-polygon attachment per strategy-systems v0.3 §3.5.7 + battle-hud.md §3 UI-GB-16 spec. BattleScene subscribes to `_grid_controller.unit_pending_buff_changed`; handler `_on_unit_pending_buff_changed(uid, has_buff)` mirrors `_on_unit_defend_stance_applied` pattern — add/remove idempotent "BuffBadge" Label child with ▶ chevron, gold/black contrast, counter-rotated, Vector2(18, -18) upper-right corner (inward from DefendBadge's Vector2(18, -34) so they coexist). HUD-level UI-GB-16 stays as active-unit-emphasis hint. No round_started auto-clear (buffs persist across rounds until consumed/expired). G-30 windowed verify pattern (shared with all existing badge handlers).
- [x] **i18n + tooltips polish R-6-D (commit `8079d2f`, +1 test)** — Closes R-6-D from Phase B view-layer commit. 20 new locale keys in ko.po + en.po: `ui.inventory.empty_slot` + `read_only_label` + `item.<id>.name` + `effect` + `restriction_label` for 4 MVP items (heal/strength/march/fire) + `item.reject.<code>` for 6 reject codes. BattleHUD `_tooltip_for_item(item_id)` composes `name\neffect[\nrestriction]` body. `_refresh_inventory_panel` sets `Button.tooltip_text` per slot. R-6-D secondary path: Godot built-in tooltip (PC hover + mobile tap-and-hold). before_test forces `TranslationServer.set_locale("en")` per existing pattern.

**S91 (follow-up arc) — 핵심 design 결정 (잠금)**:

1. **Armed-state gate at controller**: HUD owns tile-click semantics when inventory panel armed; controller silently skips tile-actions via `_item_target_armed` flag. Unit-scoped key actions stay live so I-key cancel works while armed.
2. **8b LOAD side deferred**: production CP_1/CP_2/CP_3 checkpoints fire at chapter boundaries where snapshots are naturally empty (battle scene not live). Mid-battle save trigger needs separate design. apply_per_unit_strategy_snapshot helper is wired + tested so the LOAD hook lands cleanly when trigger added.
3. **UI-GB-16 two-tier visibility**: HUD-level glyph = "active unit has buff" (emphasis hint), per-polygon = "this specific unit has buff" (multi-unit visibility). Both update from same signal. Distinct purposes — both kept.
4. **R-6-D tooltip via Godot built-in**: Button.tooltip_text + built-in hover surface. No custom Control needed at MVP tier — built-in honors PC hover + mobile tap-and-hold both.
5. **Locale key naming**: `item.<id>.<aspect>` strictly per strategy-systems v0.3 §3.5.9. No alternate patterns.

**S91 (follow-up arc) — 결과 / Pillar 별 felt 변화**:

- **Pillar #5 (전략적 조합)**: VIEW LAYER FULLY POLISHED. Player 가 inventory panel 을 열어 슬롯 클릭으로 item 발화 → fire_scroll target 지정 → tile 클릭으로 AoE 정확한 위치에 떨어뜨림 → 버프 활성화 시 본인 폴리곤 위에 ▶ glyph + HUD top-right 에도 활성-단위 hint → tooltip 으로 item 효과 즉시 학습 가능. 4-layer UX gap (mechanical + discoverability + visual + balance) 모두 본 commit chain 으로 완비.
- **Phase B follow-up 4/5 CLOSED** — outstanding: G-30 windowed verify (user action) + 8b LOAD side (no trigger).
- **Test count progression (cumulative S91)**: S87 1996 → S90 2010 → S91 step 7 2015 → step 8 2024 → step 8b 2028 → step 6 2036 → step 9 2051 → UI-GB-17 follow-up 2057 → 8b save 2067 → i18n + tooltip **2068** (+72 cumulative S87→S91 across 9 commits, all green).

**S91 (follow-up arc) → S92 (next session) 핸드오프**:

Outstanding (NOT strict Phase B blockers):

1. **G-30 windowed verify** (highest priority, user action) — boot windowed game + verify the 4 UI behaviors (I-key panel open, slot click fires SELF items, fire_scroll target overlay + tile click commits, strength buff glyph appears HUD + polygon).
2. **8b LOAD side wiring** (deferred until mid-battle save trigger exists) — BattleScene subscribes to GameBus.save_loaded + caches snapshot + applies to BattleUnits after `_build_battle_units_from_chapter`. Needs design: when to apply (resume same chapter vs new chapter)? snapshot precedence vs chapter starting_inventory?

---

### S91 (continued) — Strategy Systems Phase B steps 6 + 9 finalization (2026-05-27 session 91 cont'd)

> **Driver**: After step 7+8+8b push + session-end request, the user resumed with "다음 진행" → AskUserQuestion step 6 선택 → OQ-DC-11 사용자 결정 (option b INT scaling) → step 6 완료 → step 9 (UI) 선택 → "세개 모두 한꺼번에" scope → step 9 완료 → 핸드오프 + 세션 종료. 5 total commits this continuous session; Phase B mechanical layer ends here.

**Completed (2 additional commits, 2028 → 2051/2051 PASS / 0 errors)**:

- [x] **Step 6 fire_scroll cross-class + INT scaling (commit `60f0526`, +8 AC-SS-6 + INT regression tests)** — OQ-DC-11 resolution = option (b): apply INT scaling formula per damage-calc rev 2.9.4 §F-DC-8. BattleUnit gains cached `stat_intellect: int = 60` (identity default at INT_BASELINE); BattleScene `_make_battle_unit` populates from hero_data. GridBattleController adds `INT_BASELINE=60` / `INT_SCALING_RATE=0.005` / `FIRE_BASE_DAMAGE=20` / `FIRE_RANGE=3` / `FIRE_SCROLL_ALLOWED_CLASSES=[INFANTRY, CAVALRY, COMMANDER]` constants + new `_apply_fire_aoe(caster, origin_pos, base_damage, range) -> int` shared helper consumed by both `_skill_fire_strategy` (native) and new `_use_item_fire_scroll(unit, target_pos)` — AC-SS-6 damage formula identity structural guarantee. `use_item` extended with optional `target_pos = Vector2i(-1, -1)` sentinel → fire_scroll resolves to caster.position when sentinel (MVP self-cast until UI-GB-17 click lands). Unwired-fixture rotation: fire_scroll → command_scroll (Phase 4+ DEFERRED per v0.2 user adjudication).
- [x] **Step 9 UI-GB-15/16/17 view layer (commit `571210a`, +15 tests: 5 controller + 10 HUD integration)** — Three new view-layer surfaces mounted into BattleHUD:
  - **UI-GB-15 Inventory Panel** (`scenes/battle/elements/ui_gb_15_inventory_panel.tscn`): bottom-center PanelContainer + 3 slot buttons (≥44pt R-6-A) + ReadOnlyBanner + FeedbackLabel. I-key toggles via `GameBus.input_action_fired(&"use_item")` subscription. Shape-distinct slot glyphs per R-6-B: heal=● str=★ fire=▲ march=→. Slot click for SELF item fires immediately; non-SELF (fire_scroll GROUND) arms target overlay.
  - **UI-GB-16 Active Buff Indicator** (`scenes/battle/elements/ui_gb_16_active_buff_indicator.tscn`): small ▶ Label top-right; visibility binds to new signal `GridBattleController.unit_pending_buff_changed(uid, has_buff)`. MVP active-unit only (per-polygon multi-unit attachment deferred per ADR-0015 §2 mirror of UI-GB-11 defend seal MVP).
  - **UI-GB-17 Item Target Selection Overlay**: ChapterVisuals extension — `set_item_target_tiles(tiles, palette)` + draw block + 3 palette constants (ALLY 금록 30% / ENEMY 황토 50% / GROUND 청회 50% + crosshair). Controller `begin_item_target_selection / clear_item_target_selection` emits `item_target_selection_updated(tiles, palette)` → BattleScene forwarder.
  - **`unit_pending_buff_changed` emission**: strength_scroll apply / fresh consume / stale clear all emit. **`get_item_target_tiles(unit, item_id)` helper**: returns Manhattan FIRE_RANGE disc for fire_scroll (gated by class + INT).
  - Lint update: `lint_battle_hud_connect_deferred.sh` EXPECTED_COUNT 15 → 18. `_exit_tree` block extended with 6 new disconnects (3 signals + 3 button pressed) per `battle_hud_missing_exit_tree_disconnect` lint (32 disconnects total).

**S91 (continued) — 핵심 design 결정 (잠금)**:

1. **OQ-DC-11 resolution = option (b)**: INT scaling formula `damage = floori(base × (1 + (INT - 60) × 0.005))` applied. No-behavior-change at INT_BASELINE=60 (factor=1.0 → 20 = pre-S91 fixed-20). 제갈량 INT=99 native fire_strategy → floori(20×1.195)=23 damage.
2. **fire_scroll target_pos sentinel**: `Vector2i(-1, -1)` from default 2-arg `use_item` call resolves to caster.position. MVP self-cast; full UI-GB-17 tile-click confirmation = Phase B step 9 follow-up TODO inline.
3. **UI-GB-16 MVP scope**: active-turn unit's buff only (single HUD-level glyph). Per-polygon multi-unit attachment migration target = ADR-0015 §2.
4. **UI-GB-17 palette differentiation**: opacity contrast + (GROUND only) crosshair glyph is the color-independent discriminator. Exact hex values provisional pending art-director sign-off.
5. **I-key behavior change**: was "fast-fire slot 0", now "toggle inventory panel". The `_handle_use_item_input` direct-fire path is kept for backward compat; production flow now goes panel → slot click → use_item.
6. **3 new signal subscriptions** (CONNECT_DEFERRED per ADR-0001 §5): `GameBus.input_action_fired` + `_grid_controller.unit_pending_buff_changed` + `_grid_controller.unit_item_used`. Explicit `_exit_tree` disconnects per lint.

**S91 (continued) — 결과 / Pillar 별 felt 변화**:

- **Pillar #5 (전략적 조합)**: VIEW LAYER COMPLETE. Player 가 inventory panel 을 열 수 있고, slot 을 클릭해 item 을 발화할 수 있고, buff 가 활성화되면 작은 glyph 으로 indicate, fire_scroll 의 AoE 범위 가 grid 에 visualized — Phase B 전체 mechanical loop "이동 + item + 다시 이동/공격" 이 UX 통해 작동.
- **Phase B 9/9 mechanical complete** — `design/gdd/strategy-systems.md` v0.3 의 모든 Phase B steps 구현 + 테스트.
- **G-30 windowed verify outstanding**: visual rendering (panel glyphs, buff indicator placement, fire-scroll target tint+crosshair) cannot be exercised headlessly. User to confirm in windowed mode that (a) I-key opens panel, (b) heal/strength/march slot click fires + closes panel, (c) strength buff glyph appears top-right post-fire, (d) fire_scroll slot click shows radius-3 Manhattan disc tint.
- **Test count progression (cumulative S91)**: S87 1996 → S90 2010 → S91 step 7 2015 → step 8 2024 → step 8b 2028 → step 6 2036 → step 9 **2051** (+55 cumulative S87→S91 across 7 commits across 2 sessions, all green).

**S91 (continued) → S92 (next session) 핸드오프**:

**Phase B = MECHANICAL COMPLETE 9/9.** All design/gdd/strategy-systems.md v0.3 Phase B steps implemented + tested.

Optional follow-up (NOT strict Phase B blockers):

1. **G-30 windowed verify** (user action, highest priority) — boot windowed game + verify the 4 UI behaviors above.
2. **UI-GB-17 target tile-click confirmation** (~80 LoC; narrow scope) — InputRouter `item_target_select` action + controller routing → `use_item(uid, slot, clicked_tile)`. Completes fire_scroll end-to-end.
3. **8b-followup SaveContext snapshot population/restore wiring** (architectural; needs design pass) — BattleScene ↔ ScenarioRunner cross-system query for per-unit inventory + pending_buff. EC-SS-9 actual round-trip.
4. **UI-GB-16 per-polygon multi-unit attachment** (post-MVP) — multi-unit buff visibility.
5. **Phase B i18n + tooltips** (R-6-D polish) — `item.<id>.name / effect / restriction / reject.<code>` keys.

---

### S91 — Strategy Systems Phase B steps 7 + 8 + 8b implementation (2026-05-27 session 91)

> **Driver**: S90 핸드오프 후 사용자 "이어서 진행" → AskUserQuestion step 7 선택 → 완료 후 step 8 → 완료 후 step 8b → 완료 후 세션 종료 요청 ("진행된 내용 문서에 반영 + commit push + 세션 클리어"). 매 step push 후 다음 결정 패턴 (S90 와 동일). 사용자 결정 의존 step (#6 OQ-DC-11) 회피하고 mechanical/data-layer step 만 batch.

**Completed (3 commits, 2028/2028 PASS 유지, code + tests)**:

- [x] **Step 7 march_scroll move-token re-grant (commit `428e334`, +5 AC-SS-4b tests)** — BattleUnit `move_range_bonus: int = 0` (transient, cleared at unit_turn_started). TurnOrderRunner public API `refresh_move_token(unit_id) -> bool` (resets move_token_spent for ACTING unit; distinct from retract_move — no accumulated_move_cost rollback). GridBattleController `is_tile_in_move_range` + `get_movable_tiles` 이 `unit.move_range + unit.move_range_bonus` 사용. `_use_item_march_scroll`: action_token pre-check (§4.4 Edge), bonus 추가, refresh_move_token, return 1. Stub `refresh_move_token_calls: Array[int]` test seam. Unwired-test fixture rotation: march_scroll → fire_scroll (step 6 pending).
- [x] **Step 8 chapter starting_inventory_by_hero (commit `2b9f9c5`, +9 tests: 4 hydration + 5 battle_scene)** — ChapterDefinition `@export var starting_inventory_by_hero: Dictionary = {}` (untyped per G-25). ScenarioRunner `_hydrate_chapter` JSON coerces String keys/values to StringName; EC-SS-1 surplus drop (>3 → discarded with push_warning). BattleScene `_apply_starting_inventory(unit, chapter)` helper called from `_build_battle_units_from_chapter`; copies (not aliases) authored array so in-battle decrements don't corrupt chapter resource. Enemy units 제외 (OQ-SS-2 MVP). Closes scenario-progression cross-doc obligation (row 5).
- [x] **Step 8b SaveContext per-hero snapshot fields (commit `0bdb6ff`, +4 round-trip tests)** — SaveContext 2 new @export Dictionary fields: `per_hero_inventory_snapshot` (`{unit_id_int -> Array[StringName]}` for EC-SS-9) + `per_hero_pending_buff_snapshot` (`{unit_id_int -> pending_buff Dict}` for EC-SS-3). Both untyped at @export per G-25. save_context_test.gd field-count guard 14 → 16. No CURRENT_SCHEMA_VERSION bump (additive, backward-compat with v2's branch_history landing pattern). Resource @export discipline lint 통과. Closes save-load cross-doc obligation (row 6) at data layer; population/restore wiring deferred.

**S91 — 핵심 design 결정 (잠금)**:

1. **march_scroll bonus expiry**: cleared at `_on_unit_turn_started` for THIS unit (turn-scoped). Bonus survives intervening enemy turns but resets when the unit's own next turn starts. 일관성 — `unit.move_range_bonus = 0` next-activate semantics.
2. **march_scroll stacking**: additive (`move_range_bonus += MARCH_SCROLL_BONUS`) — 2× march_scroll → +4. EC-SS-2 (Dictionary overwrite) 적용 안 함 — int field 이지 Dict 가 아니므로.
3. **march_scroll action_token pre-check**: rejected if `action_token_spent == true` (§4.4 Edge "이미 attack 함이면 거부"). Bonus + slot NOT consumed on reject — partial-side-effect leak 없음.
4. **starting_inventory per-unit copy isolation**: `_apply_starting_inventory` Array[StringName] copy 생성. In-battle mutations (slot decrement) chapter resource 까지 leak 안 됨 — retry/load 안전.
5. **EC-SS-1 surplus drop at hydration time**: ScenarioRunner._hydrate_chapter 에서 처리 (battle init 아님). Cap (3) hard-coded — BalanceConstants read 를 scenario-load hot path 에서 회피.
6. **SaveContext schema additive at v1-stamped layer**: per_hero_* fields 가 CURRENT_SCHEMA_VERSION bump 없이 land. v2's branch_history/persistent_branch_flags 동일 패턴 (CURRENT_SCHEMA_VERSION=1 stamped saves 안에 v2 fields 가 이미 살아있음). Drift acknowledged; 본 PR 범위에서 fix 안 함.

**S91 — 결과 / Pillar 별 felt 변화**:

- **Pillar #5 (전략적 조합)**: mechanism 확대. 4 MVP items 중 3개 wired (heal_potion + strength_scroll + march_scroll). "move + item + 다시 move" chain mechanically 작동. Chapter authoring layer 까지 완비 — designer 가 ch01-ch16 JSON 에 starting_inventory_by_hero 추가 가능.
- **Cross-doc obligations FULLY CLOSED** (Phase B pre-flight 6/6): damage-calc rev 2.9.4 ✅ / battle-hud UI-GB-15/16/17 ✅ / accessibility R-6 ✅ / hero-database INT ✅ / scenario-progression starting_inventory ✅ (S91 step 8) / save-load schema ✅ (S91 step 8b data layer).
- **Test count progression**: S87 1996 → S90 2010 → S91 step 7 2015 → step 8 2024 → step 8b **2028** (+18 across 3 commits all green).

**S91 → S92 (next session) 핸드오프**:

Phase B remaining (2/9):
1. **step 6 fire_scroll** — **OQ-DC-11 사용자 결정 필요** (defer fixed-20 / apply INT scaling with base_damage=20)
2. **step 9 UI view-layer** — UI-GB-15/16/17 implementation (spec authored S89 arc-F). windowed verify (G-30 risk).

Optional follow-up (deferred):
- **8b-followup SaveContext population/restore wiring** — `_make_save_context` 가 BattleScene 으로부터 active battle's per-unit inventory + pending_buff 수집 → ctx fields 채우기 + battle resume 시 BattleUnit 으로 복원. EC-SS-9 actual round-trip 작동을 위해 필요. ScenarioRunner ↔ BattleScene cross-system query pattern 설계 필요.

Critical path: step 6 사용자 결정 → step 9 UI → 8b-followup (optional).

### S90 — Strategy Systems Phase B steps 1-5 implementation (2026-05-26 session 90)

> **Driver**: S89 arc-F (Phase B pre-flight complete) 후 사용자 "이어서 진행" → Phase B steps 1-5 단일 세션 implementation. 마지막에 사용자 "진행된 내용 문서에 반영 + commit push + 세션 클리어" 요청.

**Completed (5 commits, 2010/2010 PASS 유지, code + tests)**:

- [x] **Step 1+2 BattleUnit fields + ActionType.USE_ITEM (commit `c137894`, +3 AC-SS-1 tests)** — `inventory: Array[StringName] = []` + `pending_buff: Dictionary = {}` (G-25 safe) added to BattleUnit. ActionType enum extended (5 → 6 values). declare_action arm: USE_ITEM joins ATTACK/USE_SKILL/DEFEND action_token category (shared economy — move+item OK, move+item+attack NOT OK).
- [x] **Step 3 InputRouter use_item arm + I/3 keys (commit `989aef2`)** — ACTIONS_BY_CATEGORY["grid"] +use_item (13 total). default_bindings.json use_item = I(73)+3(51). _handle_action_in_s0 + _s1 triple-action arm (use_skill, defend_stance, use_item) with `_did_visible_work = true`. G-32 lint passes (13/12 grid actions + grid_hover PC-only). 6 test count fixes + AC-7 reachability exempt list +use_item.
- [x] **Step 4 heal_potion immediate-effect (commit `4bdfc73`, +6 AC-SS-4 tests)** — Public API `use_item(unit_id, slot_idx) -> bool`. `_handle_use_item_input()` selection-less fallback (mirrors use_skill pattern). HEAL_POTION_AMOUNT=25 via HPStatusController.apply_heal. Reject at max HP (slot NOT consumed). New `unit_item_used` signal: (unit_id, item_id, slot_idx, actual_effect). End-to-end action chain validated.
- [x] **Step 5 strength_scroll buff multi-turn carry (commit `a2ddbea`, +5 AC-SS-5 tests)** — ResolveModifiers ABI extended: `pending_buff_magnitude: float = 1.0` field + factory positional param (G-21 safe identity). DamageCalc._passive_multiplier folds buff into pre-cap product with counter guard. STRENGTH_SCROLL_MULT=1.50. `_use_item_strength_scroll` sets pending_buff with expires_at_turn = current_round+1. `_resolve_pending_buff_magnitude` helper: read+clear (consume) or stale+clear (identity). 2 call sites: _resolve_attack CONSUMES, preview_attack PEEKS (forecast must not burn scroll).

**S90 — 핵심 design 결정 (잠금)**:

1. **Buff gate `expires_at_turn >= current_round`** (strict) — spec v0.3 text `>` was a bug; EC-SS-3 worked example requires `>=`. Implemented per example, spec text correction filed as v0.3.1 carry-over.
2. **Buff consumption ownership**: GridBattleController.`_resolve_pending_buff_magnitude` 명시적으로 clear. DamageCalc 는 BattleUnit 상태 mutate 안 함 (strategy-systems §3.3 마지막 bullet 준수).
3. **Preview vs Resolve dichotomy**: forecast = PEEK (read-only), resolve = CONSUME (clear). Player friendly — scroll 안 burned on preview.
4. **Counter guard**: pending_buff_magnitude 는 is_counter=true 경로에서 차단 (DamageCalc 내부, Charge/Ambush/Rally pattern 일관성).
5. **G-21 safe identity default 1.0**: 기존 damage_calc tests retroactive shift 없음. Apex cell Cavalry 178 보존.

**S90 — 결과 / Pillar 별 felt 변화**:

- **Pillar #5 (전략적 조합)**: 기초 mechanism 완성. 4 MVP items 중 2개 wired (heal_potion + strength_scroll). 행동 chain "move + item" 작동 검증. Multi-turn buff carry pattern 작동.
- **Pillar #3 (역할 차별화)**: 보호 4-mechanism (class 제한 + INT 임계 + 휴대 한계 + buff stacking 금지) 의 4번째 (buff stacking 금지) 가 EC-SS-2 + strength_scroll overwrite 로 작동 입증.
- **Test count progression**: S87 1996 → S88 1996 → S89 1996 → **S90 2010** (+14 across 5 commits all green).

**S90 → S91 (next session) 핸드오프**:

Phase B remaining order (locked):
1. **step 6 fire_scroll** — **OQ-DC-11 사용자 결정 필요** (defer fixed-20 / apply INT scaling)
2. **step 7 march_scroll** — no OQ blocker, mechanical only, G-30 windowed verify required
3. **step 8 chapter_resource** — last cross-doc obligation closing
4. **step 9 UI implementation** — UI-GB-15/16/17 view-layer (spec authored S89 arc-F)

Critical path: step 7 가장 light (mechanical-only, no decision pending) → step 8 (data wire-up) → step 6 (OQ resolution) → step 9 (UI).

### S89 — Phase B pre-flight COMPLETE + v0.3 INT alignment (2026-05-26 session 89, arc-F)

> **Driver**: arc-E v0.2 close-out 직후 사용자 "이어서 진행" → Phase B mandatory pre-flight 4 item 동시 진행 (damage-calc rev N + battle-hud UI-GB + accessibility R-6 + hero-database INT sweep). Parallel agent spawn 2개 + 직접 work 2개. 5 of 6 cross-doc obligations RESOLVED/COMPLETED.

**Completed (1 commit, 1996/1996 PASS 유지, docs only)**:

- [x] **3 parallel work tracks** (parallel agent + direct):
  - ux-designer spawn → battle-hud UI-GB-15/16/17 + accessibility R-6 token. cross-doc bidirectional 닫힘.
  - systems-designer spawn → damage-calc.md rev 2.9.3 → 2.9.4 (+109 LoC): pending_buff_magnitude field + F-DC-5 P_mult + new §F-DC-8 INT_BASELINE=60 + OQ-DC-11 (fire_strategy fixed-dmg desync flagged).
  - hero-database INT audit → `stat_intellect` field 이미 모든 19 hero 에 존재 (ADR-0007). Sweep 불필요.
- [x] **strategy-systems v0.2 → v0.3** patch: INT scale 0-100 통일 (abstract 5-9 폐기), INT_BASELINE=60 user adjudicated, §3.2.3 / §3.6 / §3.7 / §4.3 / §6.3 / §7 / §8 AC-SS-6 / footer update.
- [x] **2 post-spawn inconsistency fix**: damage-calc agent 가 v0.2 abstract 5-9 scale 보고 작업 → v0.3 0-100 scale alignment fix (worked example + TK-DC-10 description).
- [x] **review log v0.3 entry**: +34 LoC, cross-doc obligation count update (6 → 1 remaining).
- [x] **systems-index #15** → APPROVED v0.3 + Phase B pre-flight COMPLETE.

**S89 arc-F — 핵심 design 결정 (잠금)**:

1. **INT scale 0-100 (stat_intellect 직접)** — v0.2 abstract 5-9 폐기. Cross-doc grep 가능 + 데이터 중복 제거.
2. **INT_BASELINE = 60** — fire_scroll int_requirement + fire_strategy native baseline. User adjudicated (보더라인 — 장비/허저/여포 50 거부 + 관우/황충/마초 60 통과).
3. **OQ-DC-11**: 기존 fire_strategy 는 fixed 20 damage / no INT scaling. Phase B 진입 시 명시 선택 필요 — (a) defer fixed-20 / (b) INT scaling apply with base_damage=20 (no-behavior-change at INT_BASELINE).
4. **UI-GB-15/16/17 + R-6** authored — Phase B UI/a11y spec source 완비. 2 art-director sign-off 대기 (UI-GB-17 hex 값, R-6-B icon 모양).
5. **`pending_buff_magnitude: float = 1.0`** identity default in ResolveModifiers — G-21 safe (apex cell 178 보존).

**S89 arc-F — Cross-doc obligation status**: 6 → 1 remaining
- ✅ hero-database INT sweep (RESOLVED v0.3 — sweep 불필요)
- ✅ damage-calc rev 2.9.4 (systems-designer completed)
- ✅ battle-hud UI-GB-15/16/17 (ux-designer completed)
- ✅ accessibility R-6 (ux-designer completed)
- ⏳ scenario-progression starting_inventory_by_hero (Phase B impl 시 — ChapterDefinition field 추가, 작은 변경)

**S89 arc-F → S90 Phase B 진입**:

Phase B implementation order locked (v0.2 godot recommendation preserved):
1. BattleUnit field 추가
2. ActionType.USE_ITEM
3. InputRouter S0+S1 arm
4. heal_potion → strength_scroll → fire_scroll (OQ-DC-11 resolution 후) → march_scroll
5. command_scroll DEFER Phase 4+

### S89 — Strategy Systems GDD v0.2 narrow re-review close-out (2026-05-26 session 89, arc-E)

> **Driver**: arc-D v0.1 GDD draft 직후 사용자 "권장 순서대로 진행" → 3 specialist (godot-gdscript-specialist + ux-designer + qa-lead) narrow re-review parallel spawn → 11 blocking findings 도출 → 모든 specialist-authored fix language 적용 + 2 user adjudication.

**Completed (1 commit, 1996/1996 PASS 유지, docs only)**:

- [x] **3-specialist narrow re-review** (parallel background spawn): godot NEEDS REVISION (4 B + 3 R + 3 A) + ux NEEDS REVISION (4 B + 4 R + 3 A) + qa CONCERNS (3 B + 4 R + 4 A). 11 blocking findings 종합.
- [x] **2 user adjudications (binding)**: (A) Inventory panel = Option B (bottom-center modal) per ux 추천. (B) command_scroll DEFERRED to Phase 4+ per godot B-3 + qa R-3 convergent.
- [x] **strategy-systems.md v0.1 → v0.2** (~600 LoC 변경): §3.3 신규 sub-sections (BattleUnit field + G-32 arm coverage) / §3.5 9 sub-section 완전 rewrite (panel + flow + palette + SELF confirm + cancel + tooltip + buff indicator + a11y + i18n) / §4.2 cap fix (MAX_RAW_DAMAGE desync 제거) / §4.3 fire INT clarification / §4.5 command DEFER / §5 EC-SS-3 revive lifecycle + EC-SS-6 DEFER / §6 ResolveModifiers ABI obligation + G-32 explicit + 6-row cross-doc obligations checklist / §8 all AC rewrite per qa enhancement table / OQ-SS-6 RESOLVED / footer.
- [x] **신규 review log**: `design/gdd/reviews/strategy-systems-review-log.md` (~140 lines) — v0.1 entry + v0.2 close-out 완전.
- [x] **systems-index.md row #15**: In Design v0.1 → APPROVED v0.2 close-out.

**S89 arc-E — 핵심 design 결정 (잠금)**:

1. **command_scroll Phase 4+ defer**: TurnOrderRunner hard invariant 충돌 회피. 4 MVP items 으로 Pillar #5 입증.
2. **Buff multi-turn carry**: `expires_at_turn > current_turn` strict gate (same-turn 보호) + revive 재계산 안 함.
3. **ResolveModifiers.pending_buff_magnitude: float = 1.0** identity default + damage-calc.md rev N cross-doc obligation binding.
4. **G-32 use_item arm S0+S1 both** mandatory + lint enforcement.
5. **Panel = Option B (bottom-center modal)**: UI-GB-15/16/17 = battle-hud.md 신규 row obligation.

**S89 arc-E → S90 (next session) Phase B 진입 mandatory action**:

1. damage-calc.md narrow re-review (INT_BASELINE + pending_buff_magnitude field)
2. hero-database.md INT sweep (14+ hero)
3. battle-hud.md UI-GB-15/16/17 authoring (ux-designer follow-up)
4. accessibility-requirements.md R-6 token (ux-designer follow-up)

Phase B implementation order locked: BattleUnit fields → USE_ITEM enum → InputRouter arms → heal → strength (+damage-calc patch) → fire (+INT_BASELINE 확정) → march → ~~command~~ DEFER.

### S89 — Strategic depth pivot — Pillar #5 신설 + Strategy Systems GDD (2026-05-26 session 89, arc-D)

> **Driver**: S89 arc-A/B/C (hero attack frame 5명) 직후 사용자 raw feedback (강도 높음): "이동 이후 공격이나 책략이나 도구(아이템)를 사용해서 ... 영걸전에서 제공하는 재미있고 전략적인 것들이 ... 현재 이 게임에서는 그런 부분이 거의 없는 것과 같다. 이 부분이 제일 중요한 부분이고, 이런 것들이 조합이 되어서 게임 난이도와 밸런스가 결정된다." → 영걸전 핵심 전략 시스템의 전면 부재 자백 + ship target 재정의 명령. Explore agent audit 결과 정확 확인: Q3 Move→Item ❌ / Q4 Inventory ❌ / Q5 Scroll ❌ / Q6 Ally support ⚠ 14중 3개만.

**Completed (3 docs commit, code 0)**:

- [x] **docs: North Star Pillar #5 신설** — `design/NORTH-STAR.md` 5번째 Pillar "전략적 조합 (Strategic Combinations)" 추가. 4 Pillar → 5 Pillar 헤더 update. raw feedback #6 verbatim 정직히 등재. ship target 재정의 ("MVP Demo (ch01-16 + Strategic depth foundation)") + out-of-scope 명시. Design Test 5번째 질문 추가 ("단일 강력한 action vs 조합 깊이 → 조합").
- [x] **docs: Strategy Systems GDD v0.1 first draft** — 신규 `design/gdd/strategy-systems.md` (8 section 완비 / ~700 lines). 5 user adjudications binding: MVP 재정의 / Pillar #5 신설 / Item use = Action token 공유 (move+item OK, move+item+attack NOT OK) / per-hero 3-slot inventory / 챕터 단위 자동 회수. 7 prototype items + 1 scroll specified (heal_potion / revive_pill / strength_scroll / accuracy_scroll / march_scroll / fire_scroll / command_scroll). Pillar #3 (역할 차별화) 보호 4-mechanism (class 제한 + INT 임계 + 휴대 한계 + buff stacking 금지) 명문화. 9 AC cluster + 10 EC + 8 tuning knob + 7 OQ.
- [x] **docs: systems-index #15 row update** — Equipment/Item System (Alpha, Not Started) → Strategy Systems (MVP, In Design v0.1). Cross-doc obligations 명시 (damage-calc rev 2.9.3 / turn_order_runner / hero-database INT sweep / scenario-progression / save-load).

**S89 arc-D — Why now / 의미**:

- **Raw feedback intensity**: 사용자가 "이 부분이 제일 중요한 부분" 으로 명시. S86 "재미없음" raw feedback 의 진짜 layered root cause 의 마지막 layer 발견 (S86 visual + S86 discoverability + S86 mechanical hot-fix + S87 visual particle + S88 lighthouse + S89 hero attack frame ... 모두 surface). **진짜 root cause = 영걸전식 전략 조합의 부재**.
- **Pillar tension 정직 directive**: Pillar #3 "역할 차별화" 가 책략권 시스템으로 위반될 risk. GDD §3.6 에 4-mechanism 보호 명시 — Pillar #3 와 양립 가능하게 설계.
- **MVP scope upgrade**: ship target 재정의 — 1-2 세션 늦어지지만 진짜 ship-worthy 됨. "MVP 5/5 ★ ship-ready" 의 의미 자체가 strategic depth 포함하도록 raised.

**S89 arc-D — 핵심 design 결정 (잠금)**:

1. **Pillar #5 신설**: "전략적 조합 (Strategic Combinations)" — 매 turn 의 결정 단위가 단일 action 이 아닌 **chain**. (이동 → 행동) × (아이템 / 책략권 / cross-hero 지원) 의 조합 puzzle.
2. **Item use = Action token 공유**: USE_ITEM 이 attack/skill/defend 와 동일 token category. 이동+아이템 OK / 이동+아이템+공격 NOT OK / buff item 은 multi-turn carry (next attack 까지).
3. **Per-hero 3-slot inventory**: 영걸전 reference. Per-army shared bag 대신 per-hero 선택 — Pillar #3 강화 ("이 hero 에게 어떤 책을 들려줄지").
4. **챕터 단위 자동 회수**: 챕터 시작 보급 + 종료 회수. 영구 누적 없음. RPG progression 안 됨 (anti-pillar "밸런스 붕괴" 보호).
5. **Pillar #3 4-mechanism 보호**: class 제한 + INT 임계 + 휴대 한계 + buff stacking 금지. 책략권 도입 후도 "강캐 모든 책 spam 무쌍" 차단.

**S89 → S90 핸드오프 (재구성, strategic depth 우선)**:

1. **#1 Strategy Systems Phase B (next session — 가장 시급)** — `ActionType.USE_ITEM` enum + turn_order_runner arm + per-hero inventory data + UI scaffold + 첫 prototype 아이템 1-2개 (heal_potion + strength_scroll). 1-2 세션 work. AC-SS-1 ~ AC-SS-5 충족 목표.
2. **#2 Strategy Systems Phase B 계속** — fire_scroll (cross-class) + UI 완성 + chapter resource extension. AC-SS-6 ~ AC-SS-9 충족.
3. **#3 Windowed verify (사용자 ~15-20분)** — S87 particle + S88 atk_mult + S89 hero attack frame + S90 strategy systems 통합 verify. Pillar #5 작동 입증 (AC-SS-8): "turn 마다 선택할 게 있다" 가 "공격수단 평타뿐" 대체.
4. **#4 나머지 9 hero attack frame** (S89 carry-over) — strategy systems 와 평행 진행 가능.
5. **#5 atk_mult / particle / hero frame tuning** — windowed feedback 후.
6. **#6 Full Vision** (multi-session) — S85 핸드오프.

**Critical path**:
- 가장 시급한 next: **#1 Strategy Systems Phase B** (Pillar #5 mechanical 입증 위해 필수).
- ROI 최고: 강공권 + 화공권 둘만 작동해도 user playtest 변화 큰 가능성.
- 가장 큰 risk: Pillar #3 violation. Phase B 시작 시 narrow re-review (godot-gdscript + ux-designer + qa-lead) 권장.

### S89 — Hero attack frame Phase 4 — 5 main heroes (2026-05-26 session 89, arc-A/B/C)

> **Driver**: S88 close 후 첫 turn (cold-start). 사용자 "다음 중요한 게임 요소 진행하자" → AskUserQuestion (4 옵션 — Full Vision / ★ #2-5 branch / **Hero attack frame** / CombatResolver refactor) → "Hero attack frame (Phase 4)" 선택. 본 항목은 North Star "Out of scope for this ship" 명시 Phase 4 진입 — ship target 외 polish-track 의 선언적 진행. Scope follow-up: 5명 주용 hero 선택 (유비/관우/장비/조운/제갈량). **단, 본 arc 직후 사용자가 strategic depth feedback 던짐 → arc-D 로 이어짐** (위 entry 참조).

**Completed (1 commit, 1996 PASS 유지, +~380 LoC)**:

- [x] **feat: hero attack frame — 5 main heroes (Shu trio + Zhao Yun + Zhuge Liang)** — 신규 `src/feature/battle_scene/hero_attack_frame.gd` (~370 LoC) + battle_scene.gd `_on_damage_applied` wire (+12 LoC). 5 hero kinds: `twin_blade_cross` (유비 雙股劍 X cross) / `crescent_arc` (관우 청룡언월도 황금 sweep) / `spear_thrust` (장비 장팔사모 진홍 thrust + impact star) / `lance_dash` (조운 龍膽槍 cyan 3-slash flurry + cross-spark) / `fan_glyph` (제갈량 羽扇 indigo glyph + 4 diagonal sparks). Per-attack DURATION 0.30s (skill 0.70s 의 절반). `make_for_hero` dispatch returns null for unsupported hero_id → class-line attack visual 그대로 fallback. Position semantic: node anchored at defender; `_from_local` 으로 attacker offset 보존 → at-defender + from→to 두 패턴 동일 좌표계.

**S89 — 핵심 design 결정 (잠금)**:

1. **Sibling separation**: skill_particle = caster-centered (rings at 관우, sage at 유비, indigo wave at 제갈량), hero_attack_frame = defender-centered / from→to (X at target, sweep at target, glyph at target). 같은 hero 의 skill 과 basic attack 시각이 자연 구분.
2. **Position pivot**: defender world position 을 node anchor 채택 + `_from_local = attacker - defender` 로 방향 보존. 모든 _draw_<hero> 함수가 동일 좌표계 사용.
3. **DURATION 0.30s**: basic attack 빈도 (turn 마다 여러 번) 고려한 cap. 향후 hero 추가 시도 같은 budget 준수.
4. **3-pass rendering 재사용** (S87 lock #2): outline + glow + core 모든 5 kind 동일. terrain palette 무관 readability.
5. **null fallback in dispatch**: 14 hero / non-named enemy / 향후 추가 hero 모두 안전 — class-line attack 만 남음.

**S89 — Why now / 의미**:

- North Star Pillar #3 ("모든 무장에게 자리가 있다") + #4 ("삼국지의 숨결") 의 직접 응용 — hero 마다 weapon-specific signature 부여로 "이 적은 누구다" 시각 인지 강화. S87 의 skill particle wave 가 active ability 의 hero 차별화였다면 S89 는 basic attack 의 hero 차별화.
- S86 raw feedback "공격수단 평타뿐" 의 partial 보완: 평타가 hero 별로 시각상 differentiation 되면 "같은 공격" 단조로움이 5 main hero 한정 완화. 나머지 9 hero 는 S88 → S89 핸드오프 #6 으로 carry.

**S89 → S90 핸드오프**: S88 carry-over (#1-#6) + 신규 #6 (나머지 9 hero attack frame, S89 와 동일 패턴). #1 Windowed verify 가 여전히 가장 시급 — particle wave 14/14 + atk_mult 1.50 + UI-GB-02 + 5 hero frame 모두 windowed 동시 확인.

### S88 — North Star lighthouse codification (2026-05-25 session 88)

> **Driver**: S87 close 후 첫 turn (cold-start). 사용자 progression: "내가 말한 이 게임의 가장 중요한 것을 다시 정리해줘" → 4 pillar + anti-pillar + ship target + raw feedback 정리. 사용자 follow-up: "이 부분을 등대처럼 계속 고려할 수 있도록 문서에 반영" → lighthouse doc 위치 confirm (`design/NORTH-STAR.md` + `CLAUDE.md` @-include).

**Completed (1 commit, docs-only, 1996 PASS 유지)**:

- [x] **docs: North Star lighthouse — game identity + 4 pillar + anti-pillar + raw feedback** — 신규 `design/NORTH-STAR.md` (91 lines, 6 섹션) + `CLAUDE.md` +6 lines (## North Star section + @-include). 모든 세션의 system prompt 에 lighthouse 91 lines 자동 로드 → agent / skill / future session 이 4 pillar + anti-pillar 인지. Design Test 5 질문 (pillar 1-4 + anti-pillar) instant reference. code/test 영향 0.

**S88 — Why now / 의미**:

- S86 raw feedback "재미없음" 의 layered diagnosis → S87 의 3 player-facing arc (visual + codify + balance) 가 모두 4 Pillar 의 직접 응용. 의사결정의 anchor 가 명시화되어 있지 않으면 다음 layered gap 진단 시 다시 흔들릴 위험. lighthouse codification 으로 anchor 가 매 세션 system prompt 의 일부가 됨.
- Future value: 새 agent spawn / new feature proposal / scope creep risk 시점의 design test 가 instant accessible. 흔들릴 때 돌아오는 정점.

**S88 → S89 핸드오프**: S87 carry-over (#1-#6) 그대로. #1 Windowed verify 가 여전히 가장 시급한 next.

### S87 — Particle wave 14/14 + G-32 codification + atk_mult 1.50 bump (2026-05-25 session 87)

> **Driver**: S86 핸드오프 #1, #2, #3 모두 단일 세션 closed. 사용자 progression: "관우 dragon_blade 부터" → "바로 commit + 다음 skill 이어서" → "나머지 9개 모두 이어서 작업" → "active.md + milestone log 업데이트 후 push" → "2, 3 진행". S86 layered UX gap 의 마지막 3 layer (visual feedback + process improvement + balance) 모두 닫힘.

**Completed (9 commits, 1996 PASS 유지, +1373 LoC total)**:

- [x] **vfx: dragon_blade particle (관우 청룡언월도)** (`d630a5a`) — first per-skill particle 의 baseline pattern 확정:
  - 신규 `src/feature/battle_scene/skill_particle_effect.gd` (class_name SkillParticleEffect) — AttackLine / SkillPopup / DamagePopup 패밀리에 합류. Procedural `_draw()` 로 3 expanding golden rings + yellow crescent sweep. Tree-bound tween per G-31.
  - battle_scene `_on_unit_skill_used` 의 SkillPopup mount 뒤 `_make_skill_particle(skill_id, accent)` dispatch 추가. unwired skill_ids 는 null fallback (popup + SFX + shake 정상 동작).

- [x] **vfx: thunder_roar particle (장비 천둥 포효)** (`970f40e`) — adjacency-shape AoE visual pattern:
  - 중앙 burst (백색+청색 동심원) + 4 cardinal jagged lightning bolts (TILE_SIZE = 64). 8-segment polyline with pre-rolled jitter (`_roll_thunder_roar_jitter()` in `_ready`) 로 redraw 사이클 안정. 3-pass outline+glow+core 패턴 첫 도입.

- [x] **vfx: fire_strategy particle (제갈량 박망파/적벽 화공)** (`a584aaf`) — ring-staggered AoE visual pattern:
  - 3 concentric tile rings (Manhattan ≤ 3 = 64/128/192px) × 8/14/20 motes per ring. Outward stagger 0.12s/ring → 사용자에게 "spreading outward, not erupting at once" 의 felt 차별화. 각 mote = tear-drop triangle (`_draw_flame_mote` helper).

- [x] **vfx: lone_lance particle (조운 단신 돌격)** (`8caeb89`) — radial-spoke visual pattern (cyan SCOUT palette):
  - 8-neighbor boundary ring (R=44px) + 8 radial lance segments. Conditional buff (only +75% if alone) 의 visual semantics = "ready in every direction".

- [x] **vfx: inspire particle (유비 격려)** (`71c862a`) — center-aura + 8-neighbor pulse 패턴 (sage green):
  - Caster sage-green aura + 8 cardinal+diagonal pulse rings sharing timing (buff applies to all adjacent allies simultaneously). 첫 batch (5/5) 완료 — S86 핸드오프의 명시적 5 candidate.

- [x] **vfx: 9 remaining particles — S87 batch close** (`d93c34f`) — single commit 로 14/14 wired 달성:
  - **piercing_volley (황충)** — 8 radial gold arrow streaks with arrowhead triangles, range-3 (188px). ARCHER palette.
  - **charm (초선)** — rose-pink center pulse + 4 cardinal pink rings. 0-damage tempo skill 의 warm pink palette.
  - **strategist (조조)** — massive expanding indigo ring (R_MAX = 420px ≈ 6+ tiles, battlefield-wide) + center indigo flash. Mirrors AttackLine.COLOR_STRATEGIST.
  - **naval_strategy (주유)** — 4 cardinal positions × 3 staggered concentric blue water-ripples. Soft water palette differentiates from thunder_roar's sharp bolts (같은 adjacency shape, 다른 mechanic semantics).
  - **rebel_charge (위연)** — dragon_blade silhouette mirror with dark-blood-red palette ("blade waiting for the moment"). dragon_blade vs rebel_charge 의 visual sibling 관계.
  - **blunt_strategy (방통)** — 2 concentric indigo rings at radii 1+2 tiles + 4 cardinal dashed strokes. Range-2 AoE 의 indigo deception 톤.
  - **phoenix_chick (방통)** — 동일 hero 의 alternate signature visual — warm orange phoenix aura + 4 rising feather tear-drops (`_draw_phoenix_feather` helper). 방통의 2 skill 이 indigo vs orange 로 시각적 구분.
  - **xiliang_charge (마초)** — 4 long amber CAVALRY charge lines (188px) + dust trail echoes flanking each main line. AttackLine CAVALRY style mirror.
  - **successor_strategy (강유)** — expanding indigo scan-ring up to 4-tile reach (260px) + 6-pointed starburst at caster. 조조 strategist 와 lighter indigo 로 구분 (스승-제자 hierarchy 의 시각 표현).

- [x] **docs: S87 milestone Attestation log** (`1435228`) — arc A+B 의 6 commit narrative + 5 design 결정 잠금 + 핸드오프 prepare.

- [x] **codify: G-32 InputRouter emit-gate gotcha + arm-coverage lint** (`9d3113b`) — S86 핸드오프 #2 closed:
  - **`.claude/rules/godot-4x-gotchas.md` +G-32 entry** (~140 LoC): S86 의 `use_skill` + `defend_stance` arm 부재 → `_did_visible_work=false` → emit gate silent drop trap 의 full narrative. Symptom checklist 5-layer (InputMap MATCH / dispatch / arm / emit / subscriber) + 3차 hypothesis sequence (IME → input trace → controller trace → source read of emit gate) + 3-hour diagnostic cost 정직 기록. Codified at pattern stability 1 (eager codification) — 진단 비용 vs. 재발 비용 ROI 가 single-instance 도 정당화. Cross-refs: G-30 (headless≠windowed META-pattern instance) + G-4 (lambda capture) + TG-3 (awk flag/next).
  - **`tools/ci/lint_input_router_action_arm_coverage.sh`** (100 LoC): awk flag/next state machine (TG-3 적용) 으로 `ACTIONS_BY_CATEGORY["grid"]` vocabulary 추출 + 모든 `_handle_action_in_sN` body 의 match arm reference cross-check. PASS criteria = 모든 grid action 이 최소 한 state arm 에 매칭. KNOWN_EXCEPTIONS = `grid_hover` (PC-only synthesized per CR-1c — 명시적 documented). Exit code 0/1/2 triage. Current state PASS (12 grid actions / 11 dispatched / 1 documented exception). Future-proofing: 새 grid action 추가 시 자동으로 arm 누락 catch.

- [x] **tune: shu_canon_main enemy_atk_mult 1.15 → 1.50** (`54fa94b`) — S86 핸드오프 #3 closed:
  - 25/25 chapter entries in `shu_canon_main.json` bumped via sed. +30% from 1.15, +57% from 0.95 (S86 c1 baseline), +172% from pre-S86 0.55 floor.
  - `tests/unit/feature/story_event/ch01_vertical_slice_sentinel_test.gd` AC-3 expected 1.15 → 1.50 + comment 의 S86 baseline 기록 옆에 S88 next-iteration 기록 추가.
  - `mvp_wei.json` (Wei 5-chapter mini scenario, separate values 0.55-0.85) **미수정** — 사용자 playtest 는 shu_canon-only.
  - Trajectory: 0.55-0.80 (pre-S86) → 0.95 (S86 c1 통일) → 1.15 (S86 c3) → 1.50 (S88). 사용자 last battle TURN_LIMIT_REACHED DRAW + "전반적으로 난이도가 너무 낮음" raw report 의 decisive response. Over-tuned 면 다음 세션 1.30 또는 1.40 으로 sed 한 줄 roll-back 가능.

**Outcome**: 14/14 wired skill_id 모두 unique procedural visual identity 보유. S86 layered UX gap 의 마지막 3 layer (visual feedback + process improvement + balance) 모두 닫힘. **★ ship-ready mechanical 은 그대로 유지** (S84 5/5 ★). `skill_particle_effect.gd` 가 ~930 LoC per-skill catalog 파일로 확립. G-32 + lint 가 InputRouter 의 silent emit gate trap 의 재발 방지망 확립.

**S87 — design 결정 / 패턴 (잠금)**:

1. **Procedural `_draw()` + tween-driven `_progress` 패턴**: CPUParticles2D 대신 procedural 선택. 이유: (a) AttackLine / Popup 패밀리와 동일 — 일관성. (b) 각 skill 의 visual semantic 이 unique → 단일 particle config 로 표현 불가. (c) tween_property 가 var `_progress` 0→1 으로 진행 + `_process` 가 `queue_redraw()` 호출 = 모든 sub-effect 가 동일 progress 축에서 staggered overlap.

2. **3-pass rendering (outline + glow + core)**: thunder_roar 부터 정착된 패턴. 어떤 terrain palette (잔디/돌/물/모래) 위에서도 readability 보장. 단일 line/arc 가 아닌 3 stroke 로 visual depth + contrast.

3. **Visual-vs-mechanic mapping discipline**: 각 visual 이 mechanic 의 정확한 shape 을 표현 — strategist 가 battlefield-wide 면 ring 도 battlefield-wide (R_MAX=420), fire_strategy 가 Manhattan ≤ 3 이면 ring radii 도 64/128/192. 사용자가 visual 을 보면 mechanic 의 reach 를 추론 가능. visual = mechanic teaching tool.

4. **Sibling palette discipline**: 같은 mechanic 패밀리 의 visual sibling — dragon_blade vs rebel_charge (yellow vs blood-red, 같은 silhouette) / inspire vs charm (sage green vs rose pink, 같은 +adj shape, 다른 semantic) / thunder_roar vs naval_strategy (electric blue bolts vs soft water ripples, 같은 adjacency reach). 사용자가 visual 만으로 "같은 class, 다른 mood" 인식.

5. **Single-file catalog vs per-skill file 결정**: `skill_particle_effect.gd` 단일 파일에 14 skill 모두 — class_name SkillParticleEffect + _kind StringName dispatch. 이유: (a) shared rendering primitives (`_draw_flame_mote`, `_draw_phoenix_feather`, `_draw_bolt`) 활용. (b) factory pattern 일관성. (c) ~930 LoC 도 잘 organized. 향후 30+ skill 까지 확장 시 splitter (per-faction) 고려.

**S87 → S88 (next session) 핸드오프**:

S86 핸드오프 #1 (particle visual) + #2 (codification) + #3 (atk_mult bump) 모두 본 세션에 closed. 남은 carry-over:

1. **#1 Windowed verify (~10-15분 사용자)** — **가장 시급한 next**. headless 1996 PASS 가 windowed 의 visual + balance 둘 다 gate 하지 않음 (G-30). 사용자 windowed boot → ch01-04 → 14 skill 모두 S 키 발동 → visual readability 검증 + 1.50 atk_mult felt 난이도 검증 (이번엔 enemy wipe 가능? 또는 너무 빡센가?). 잘 안 보이는 effect / 너무 빡센 atk_mult 는 tuning 필요.

2. **#2 UI-GB-02 button click verify** — S86 핸드오프 #4 carry-over. 사용자가 자기 unit click 시 하단 6 button 실제 visible 인지 windowed inspect (#1 verify 시 동시 가능).

3. **#3 ch05 ★ manual playtest** — S85+S86 핸드오프 잔존. civilians_escorted ≥ 3 trigger. 사용자 ch01-04 만 시도 → ch05+ 진행 시점.

4. **#4 atk_mult roll-back candidate** (만약 1.50 이 over-tuned 면) — 1.30 또는 1.40 candidate. windowed verify (#1) 후 결정. 25 entries sed 한 줄 fix.

5. **#5 Particle visual tuning** (만약 일부 effect 가 안 보이거나 잘못 보이면) — radius / color / duration / alpha 조정. skill 별 `_draw_<skill>` 함수의 constants 조정.

6. **#6 Full Vision** (multi-session) — S85 핸드오프 #4 그대로. ch20-22 cascade-block ADR / hero balance / banter / Wei line / ch24-25 salvage.

**Critical path ranking**:
- 가장 시급한 next: **#1 Windowed verify** (S87 의 3 player-facing arc — particle + balance + button visibility — 의 ROI confirm)
- 가장 light next: tuning candidates (#4 atk_mult roll-back 또는 #5 particle tuning) — windowed feedback 후 ~5분 fix
- 가장 큰 future work: **#6 Full Vision**

**Operational observation (S87)**:
- **Headless 1996 PASS ≠ visual + balance 검증**: G-30 의 강력한 instance. particle effect 가 `_draw()` 호출 안 되어도 / wrong color render 해도 / off-screen 위치되어도 headless test 는 모두 PASS. 1.50 atk_mult 도 마찬가지 — headless test 가 적정 vs over-tuned 판단 불가. windowed verify 가 유일한 ground truth. 본 commit 전에 사용자 verify 못 한 책임 인정 — 사용자 명시적 "push first, verify after" 결정에 따랐지만 G-30 위험 noted.
- **Per-skill catalog file 의 scaling pattern**: 14 skill 의 visual config 가 단일 파일로 organized 가능 (~930 LoC). 향후 30+ skill 시 per-faction split 또는 SkillVisualDefinition resource 패턴 (visual constants를 .tres 로 outsource) 후보.
- **Visual sibling discipline 의 future value**: dragon_blade ↔ rebel_charge 같은 visual sibling pairing 이 사용자에게 "같은 mechanic class" 시각 학습 효과 — class-aware AttackLine 의 확장 가능 (PASSIVE-aware SkillParticleEffect 등). future hero balance work 의 reference.
- **Eager codification 의 ROI**: G-32 가 pattern stability 1 instance 만에 codified — 정상은 2-3 instance 후 codify. 결정 이유 = single-instance 의 diagnostic cost (3 hours, 3 incorrect hypotheses) 가 codification cost (~15분) 의 ~12배 → 재발 시 break-even immediate. high-cost / low-frequency trap class 는 eager codify 가 정당화. 향후 similar high-cost-low-freq trap 발견 시 같은 cadence 적용.
- **Decisive balance bump 의 가능성**: 0.95 → 1.15 (+21%) 가 충분치 않았던 trajectory — incremental bump 의 학습. 1.15 → 1.50 (+30%) 는 decisive 선택. 만약 over-tuned 면 1.30 도 가능. 어느 쪽이든 single-step decisive bump 가 multi-step incremental 보다 felt baseline 학습 빠름.

## Reference

- 6-lens assessment 원본: 2026-05-22 S73 session (Producer / Game Designer / QA Lead / Technical Director / Art Director / Narrative Director 병렬 spawn)
- Master scenario: `design/scenarios/yeong_geol_jeon_shu_master.md`
- Current state snapshot: `production/session-state/active.md` (S72 close-out)
- Active workflow mode: `WORKFLOW.md` (Build, not Ratify since 2026-05-10)
