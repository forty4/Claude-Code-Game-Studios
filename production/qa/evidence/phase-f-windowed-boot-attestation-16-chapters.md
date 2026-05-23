# Phase F — 16챕터 MVP Demo Windowed Boot Attestation

> **Status**: 작성 — 2026-05-22 (S73, S16 Foundation). S18 deliverable checkpoint 추가 — 2026-05-24 (S77, S19-D 준비). 사용자 windowed attestation 대기 중.
> **Scope**: MVP Demo 16-ch (도원결의 ch01 → 낙봉파·방통 생존 ch16). DEV 챕터 점프 메뉴
> 활용. G-30 (`.claude/rules/godot-4x-gotchas.md`) 패턴 mitigation.
> **Anchor**: `production/milestones/mvp-demo-16ch.md` ship target.
> **Fork origin**: `phase-f-windowed-boot-attestation-25-chapters.md` (ch01-25 풀 캠페인). 이 16-ch cut 은 MVP Demo 범위만 — ch17-25 는 후속 milestone.

---

## 0. 헤드리스 자동화 커버리지 (이미 그린)

**663/663 PASS (foundation + grid_battle unit + integration scope)** · 0 errors · 0 failures · 276 orphans baseline (S73 시점, S72 3 신규 mechanic + S73 synergy v2 unit test 44개 backfill 후).

> **현재 baseline (S77, 2026-05-24)**: 전체 unit + integration scope **1949/1949 PASS** · 0 errors · 0 failures · 276 orphan baseline 유지. S74 macro-loop closure + S75 Beat 8 prose batches + S76 banter chapter-override + enemy voice + music palette doc + S77 ship-blocker triage + S77 `scenario_id` rename (`shu_canon_full` → `shu_canon_main`) 모두 반영. 회귀 0.

자동화로 검증된 사항 (ch01-16 범위 확인):
- 16 챕터 .tres 맵 모두 MapGrid validation 통과 (`map_grid_test.gd`)
- 16 챕터 .tscn 모두 instantiate + ChapterVisuals + map_resource 정상 마운트 (`all_chapters_scene_mount_smoke_test.gd`)
- 16 챕터 모두 `SoundManager.music_id_for_chapter` 신규 슬러그 매핑 + ambient fallback 금지 (`sound_manager_music_test.gd`)
- 16 챕터 모두 `BattleScene.CHAPTER_FLAVOR` title-card entry 존재 (`battle_scene_chapter_flavor_test.gd`)
- 16 챕터 모두 `story_content.json` beat 키 coverage (`story_content_test.gd`)
- 16 챕터 모두 `dev_jump_to_chapter` 점프 happy path (`scenario_runner_dev_jump_to_chapter_test.gd`)
- Phase A/B/C/D/E 각 hydration 가드 (chapter 4개 신규 hydration test)
- Fate field tracking — ch16 시그니처 `scout_first_turns` wireable (`grid_battle_controller_fate_test.gd`)
- **S16 backfill** — Hero banter (10) / Critical chain (15) / Synergy v1+v2 (19) = 44 신규 tests, 회귀 0

자동화로 **검증 불가** (G-30 windowed-only gap):
- 시각 렌더링 — Polygon2D / Sprite2D / `_draw()` 호출 발생
- Tween 진행 — 슬라이드, 셰이크, 페이드, walk bounce (G-31 `process_mode=DISABLED` 트랩)
- 입력 디스패치 — 마우스 클릭 → `InputRouter` → `GameBus` → `GridBattleController`
- 사운드 재생 — `AudioStreamPlayer` 실제 출력
- 객체 수명 — 배틀 종료 후 ObjectDB 누수 (POLISH-008 패턴)
- 카메라 클램프 — 맵 사이즈 변동에 따른 카메라 한계 적용
- **S72-S73 신규 mechanic 시각 가시화** — Synergy v2 badge (義/策/獨) / hero-specific bounce 차별화 / Skill drama parity / Banter popup

이 문서가 채우는 갭은 **시각 + 인풋 + 음악** 의 일회성 사용자 attestation — ship target 인 ch01-16 범위만.

---

## 1. 사전 준비 (한 번만)

```bash
# 클래스 캐시 새로 (`G-14` 가드 — 신규 hero/맵/씬 등록 보장)
godot --headless --import --path .

# 헤드리스 ULL 그린 확인 (663/663 PASS — S16 backfill 포함)
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --ignoreHeadlessMode -a res://tests/unit -a res://tests/integration -c
# → Overall Summary: 663 PASS · 0 errors · 0 failures.

# Godot 4.6 windowed 빌드 실행
godot --path . scenes/main_menu/main_menu.tscn
```

DEV 챕터 점프 버튼은 디버그 빌드(`OS.has_feature("debug")` = true)에서만 가시. 평소 `godot --path .` 호출이 디버그 빌드 — 별도 플래그 불필요.

---

## 2. 챕터별 시각 + 인풋 + 음악 체크 (16 챕터 × ~30초 = ~8분)

각 챕터마다 DEV 챕터 점프 → ChapterVisuals 렌더 → 1~2 턴 진행 → 마우스 클릭 응답 → BGM 청취 → 캠페인 메뉴 복귀.

검증 항목 (체크박스 — `[x]` 마크 후 milestone 인증):

### Phase A 프리퀄 (황건적~신야)

- [ ] **ch01_taoyuan_yellow_turban** — 12×9 평원. 도원결의 1진 (유비/관우/장비) 폴리곤 스폰. ROAD row 4 그려짐. CHAPTER_FLAVOR "제1장 · 도원결의" 타이틀카드. BGM: ch03 wandering 슬러그 재생.
- [ ] **ch02_hulao_gate** — 14×9 협곡. MOUNTAIN 양옆 벽. BGM: ch02 bridge.
- [ ] **ch03_xuzhou_rescue** — 14×10 성내. FORTRESS_WALL ring + 3 gates. 조운 합류 4명 폴리곤. BGM: ch04 warmth.
- [ ] **ch04_bowang_slope** — 14×9 협곡. 매복 FOREST. 제갈량 추가 5명 폴리곤. BGM: ch05 fire climax.
- [ ] **ch05_xinye_fire** — 12×9 도시. FORTRESS_WALL ring + 4 gates + FIRE 8 타일. BGM: ch05 fire.

### Main campaign (장판~적벽)

- [ ] **ch06_changbanpo** — 12×7 평원. 유비/장비 2명 deployment. BGM: ch01 D minor descending.
- [ ] **ch07_changban_bridge** — 8×7 다리. 장비 단신 holding. BGM: ch02 bridge.
- [ ] **ch08_xiakou_outskirts** — 16×9 강변. 황충 합류 5명. BGM: ch03 wandering.
- [ ] **ch09_chibi_prelude** — 14×9 동맹. 손권/주유 합류 6명. BGM: ch04 alliance warmth.
- [ ] **ch10_chibi_main** — 12×9 적벽. 화공 클라이맥스. BGM: ch05 fire.

### Phase B (형주 4군 + 통합)

- [ ] **ch11_jingzhou_pacify** — 14×9 영릉/계양. ROAD 동서축 + HILLS 클러스터 2 (마을). 6 Shu unit 폴리곤. BGM: ch02 bridge.
- [ ] **ch12_wuling_marsh** — 14×9 늪지. RIVER mid-map + BRIDGE [7,4] 단일 도하점. BGM: ch03 wandering.
- [ ] **ch13_changsha_veteran** — 14×10 장사성. FORTRESS_WALL ring + 3 gates. 위연 (unit 15) 적군 폴리곤 표시. **시그니처 시도**: 위연 사살 안 하고 3턴 버티기 → `wei_yan_spared_turns >= 3` → `WIN_changsha_wei_yan_defects` Beat 8. BGM: ch01 descending.
- [ ] **ch14_jingzhou_consolidate** — 15×9 도로망. ROAD cross. BGM: ch04 warmth.

### Phase C (익주 입성 — MVP demo 종착)

- [ ] **ch15_fushui_pass** — 15×9 산악 협곡. 방통 (unit 16) 합류 7 unit. REACH_TILE target [14,4] 표시. BGM: ch02 bridge.
- [ ] **ch16_luofeng_slope** ★ — 14×10 narrow ridge. MOUNTAIN 양옆. **MVP Demo 핵심 시그니처**: 조운/마초 (CAVALRY) FOREST 타일 [5,3]/[6,3] 위치 → `scout_first_turns >= 2` → `WIN_luofeng_pang_tong_lives` Beat 8 revelation 발화. **방통 생존 = 5대 영걸전 ★ #1 가 windowed 에서 작동하는 demo 종료 조건**. BGM: ch01 descending.

---

## 3. S72-S73 신규 mechanic windowed-only 가시화 체크

ch01-16 진행 중 자연 발화 가능한 mechanic — windowed 환경에서만 시각 확인 가능 (자동화 불가):

### Mechanic 별 attestation (자연 발생 시점 도달 시 마크)

- [ ] **Hero banter 5 영웅** — battle_start / player_kill / low_hp / outcome_win / outcome_loss 발화
  - [ ] 장비 line (ch01 자연 발화 가능)
  - [ ] 유비 line
  - [ ] 관우 line
  - [ ] 위연 line (ch13 이후 자연 등장)
  - [ ] 방통 line (ch15 이후 자연 등장)
- [ ] **Critical chain momentum** — REAR CRIT 연속 시 "치명타 ×N!" 배너 + boost damage
  - [ ] lv1 (+10%) — 자연 발생 (rear angle 빈도)
  - [ ] lv2 (+25%) — 같은 라운드 REAR CRIT 2회 (S73 attestation 시 장비 245→306 확인됨, 이번엔 다른 영웅으로)
  - [ ] lv3+ (+50% cap) — rare event, optional
- [ ] **Synergy v1 (Peach Garden / Lone Wolf / Counsel)** — forecast damage delta + raw stat boost
  - [x] Peach Garden Bond (S73 attestation 완료: 장비/유비/관우 +5 ATK)
  - [ ] Lone Wolf (위연 인접 0 시 +5 ATK) — 위연 등장 챕터 (ch13+)
  - [ ] Strategist's Counsel (방통 4-dir 인접 +3 DEF) — 방통 등장 챕터 (ch15+)
- [ ] **Synergy v2 visual badge** — 義 (Peach Garden) / 策 (Counsel) / 獨 (Lone Wolf) badge unit 위 표시
  - [ ] 義 badge 가시 (ch01-12 도원결의 3 영웅 인접 시)
  - [ ] 策 badge 가시 (ch15+ 방통 등장 시)
  - [ ] 獨 badge 가시 (ch13+ 위연 등장 시)
- [ ] **Hero-specific bounce 차별화** — 5 영웅 walk 시 bounce 패턴 인지 가능
  - [ ] 관우 묵직 (3px×2hop, 짧고 무겁게)
  - [ ] 방통 통통 (6px×3hop, 빠르게)
  - [ ] 위연 sharp (7px×2hop, 날카롭게)
  - [ ] 유비 baseline (5px×2hop)
  - [ ] 장비 호쾌 (6px×2hop)
- [ ] **Skill drama parity (kill drama 강화 S73 batch)** — time_scale 0.4 / hit-stop 0.16s / zoom 1.10× / accent flash 0.24α
  - [ ] 위연 skill 발화 시 chapter 등장 시 (ch13+)
  - [ ] 방통 skill 발화 시 chapter 등장 시 (ch15+)

---

## 3.5 S18 Content Polish 가시화 체크

S18 (session 76) 완성 3 deliverable — windowed 환경에서만 가시 (자동화 cover 안 됨):

### Banter per-chapter context 변형 (ch01/05/13/16 × {battle_start, outcome_win}, 26 lines)

default banter 가 아닌 chapter-specific 결로 발화하는지 인지. 기존 default 와 결 비교 (e.g. ch01 결의 anchor / ch05 신야 백성 anchor / ch13 황충 anchor / ch16 능선 anchor).

- [ ] **ch01 battle_start** — 유비/관우/장비 도원결의 결의 (default 와 결 다름, 황건적 첫 출진 anchor)
- [ ] **ch01 outcome_win** — 황건적 격파 결의
- [ ] **ch05 battle_start** — 신야 백성 보호 anchor
- [ ] **ch05 outcome_win** — 신야 화공 후 결
- [ ] **ch13 battle_start** — 장사 황충 노장 anchor
- [ ] **ch13 outcome_win** — 위연 ★ 합류 분기 시 default 결
- [ ] **ch16 battle_start** — 낙봉파 능선 anchor (방통 4번째 영웅)
- [ ] **ch16 outcome_win** — 방통 생존 ★ 분기 후 결 (★ 발화 시)

### 적측 voice minimal (4 적장 × {battle_start, outcome_loss} = 8 lines)

발화 시점: round 1 player banter 후 2.0s start_delay (battle_start) / outcome WIN 시 player banter 후 2.0s (outcome_loss).

- [ ] **조조** (wei_001) battle_start — 시인 거리 register
- [ ] **조조** outcome_loss — 시인 register
- [ ] **하후돈** (wei_005) battle_start — 충성 직진 register
- [ ] **하후돈** outcome_loss — 충성 register
- [ ] **여포** (qun_001) battle_start — 자만 외부귀인 register
- [ ] **여포** outcome_loss — 외부귀인 register
- [ ] **장료** (wei_006) battle_start — dignified 자기책임 register
- [ ] **장료** outcome_loss — 자기책임 register

### 5 procedural music palette (CH01-05 / 25-ch mapping)

`design/audio/music-themes.md` 의 5-theme palette + 25-ch mapping table reference.

- [ ] **CH01 D minor descending** — ch01/06/13/16 4 챕터 청취 (반복 분포 인지)
- [ ] **CH02 bridge** — ch02/07/11/12/15 5 챕터 청취
- [ ] **CH03 wandering** — ch01/08/12 3 챕터 (CH01 과 결 구별)
- [ ] **CH04 warmth** — ch04/09/14 3 챕터
- [ ] **CH05 fire climax** — ch05/10 2 챕터 (climax 결 강도)
- [ ] **Playtest-watch flag**: ch04→ch05 연속 CH05 (절정→fire) 자연스러움 / ch13→ch16 CH01 proximity 결 leak 없음

---

## 4. Boot fault 발생 시

각 챕터 점프 후 stderr 확인:

```bash
# 새 터미널에서 시작 시
godot --path . scenes/main_menu/main_menu.tscn 2> /tmp/windowed_boot.log
# 또는 별도 콘솔에서
```

stderr에 push_warning / push_error 발생 시:
1. 캡처: `tail /tmp/windowed_boot.log`
2. 챕터 ID 식별 (DEV 점프 직후 발생한 메시지)
3. 본 문서에 `[!]` 마크 + 1-line 증상 기록 후 보고

특히 주의:
- `WARNING: BattleHUD: grid_layer_path failed to resolve` — 헤드리스에선 정상이지만 windowed에선 fault
- `ERR_ELEVATION_TERRAIN_MISMATCH` — 맵 .tres 데이터 무결성 (이미 자동 테스트로 가드되지만 windowed에서 ResourceLoader 경로 다를 수 있음)
- `Trying to cast a freed object` (G-11) — Tween 또는 Polygon2D 수명 이슈
- Tween 진행 안 됨 (G-31) — `create_tween()` self-binding 트랩 재발 가능
- **`SpriteFrames already has 'default' animation`** — Godot 4.6 auto-create 트랩 (S73 `c158bab` 에서 fix). 재발 시 같은 패턴 회피 확인.

---

## 5. ch16 방통 생존 ★ 시그니처 in-battle 트리거 검증 (MVP Demo 종료 조건)

ch16 가 MVP Demo 의 시그니처 종료 조건 — 5대 영걸전 ★ #1 가 player choice → windowed trigger → branch reveal 전체 흐름으로 작동해야 함.

| 챕터 | 헤드리스 Field | Default Beat 8 | Hidden Beat 8 (★) |
|------|--------|----------------|---------------|
| ch16 | scout_first_turns ≥ 2 | "낙봉파 — 공명의 도착, 봉추의 추모" | **"낙봉파 — 봉이 떨어지지 않다"** |

**Trigger 시도 순서** (windowed 환경에서):
1. ch16 DEV 점프
2. 조운/마초 (CAVALRY) FOREST 타일 [5,3] / [6,3] 위치 (2 unit 모두)
3. **2턴 유지** (적이 그 위치 valid 한 동안 — `scout_first_turns += 1` per turn)
4. 전투 종료 시 → `WIN_luofeng_pang_tong_lives` outcome
5. Beat 8 revelation 텍스트 확인 — "낙봉파 — 봉이 떨어지지 않다" 표시
6. 방통 (unit 16) 가 outcome 시점에 alive 상태로 표시

ch13 (위연 합류) 도 같은 패턴 의 보조 시그니처 — `wei_yan_spared_turns >= 3` → `WIN_changsha_wei_yan_defects`. ch16 가 어려우면 ch13 으로 시그니처 발화 패턴 확인 가능 (ch16 ★ 보다 trigger 빈도 쉬움).

---

## 6. 인증 종료 조건

- [ ] 16 챕터 모두 windowed boot fault 0건
- [ ] 16 챕터 모두 ChapterVisuals 시각 렌더링 (FORTRESS_WALL / RIVER / FIRE / HILLS 시각 식별 가능)
- [ ] **ch16 방통 생존 ★ trigger 실제 windowed 에서 발화 확인** (또는 ch13 위연 fallback)
- [ ] BGM 5 슬러그 모두 청취 (CH01 / CH02 / CH03 / CH04 / CH05 — 챕터 사이 전환 자연스러움)
- [ ] DEV 챕터 점프 메뉴 — 16 행 표시 + 클릭 응답 (메뉴 길이 polish 후보)
- [ ] S72-S73 신규 mechanic 자연 발화 분 모두 인지 가능 (자연 발생 한도 내)
- [ ] **S18 banter chapter 변형** ch01/05/13/16 × {battle_start, outcome_win} 8 슬롯 인지 (§3.5)
- [ ] **S18 적측 voice** 4 적장 (조조/하후돈/여포/장료) × {battle_start, outcome_loss} 8 슬롯 인지 — round 1 player banter 후 2.0s staggered (§3.5)

전부 통과 시 본 문서에 `Status: PASS — attested YYYY-MM-DD by <user>` 헤더 추가하고 milestone `mvp-demo-16ch.md` 의 S16/S17/S18 attestation log 에 cross-link.

---

## 7. ch17-25 (out-of-scope)

이번 MVP Demo 범위 외 — 25-ch 풀 캠페인 attestation 은 `phase-f-windowed-boot-attestation-25-chapters.md` 원본 파일 참조. ch17-25 windowed attestation 은 ch16 ★ ship 후 후속 milestone 에서 수행.

남은 ★ 4개 (관우 ch20 / 장비 ch21 / 유비 ch22 / 마속 ch24 / 제갈량 ch25) 는 Full Vision 으로 후속.

---

## 8. 향후 정식 windowed smoke harness (Sprint-N+1 candidate)

G-30 §6 "Wrapper script suggestion" 패턴:

```bash
tools/ci/windowed_chapter_smoke.sh
# godot --headless --path . scenes/battle/mvp_chapter_NN.tscn --quit-after 60
# stderr 캡처 + push_error / push_warning 없음 검증
# 16 챕터 모두 통과 시 exit 0
```

자동화 가능하지만 windowed 렌더링 (Polygon2D draw, 캡처)은 여전히 사람이 봐야 함. G-30 META 패턴은 — 자동화로 어디까지 커버하든 한 단계 위 META 갭이 남는다 — 정상.
