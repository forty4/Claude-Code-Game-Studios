# Phase F — 25챕터 풀 캠페인 Windowed Boot Attestation

> **Status**: 작성 — 2026-05-18. 사용자 windowed attestation 대기 중.
> **Scope**: 영걸전식 mvp_shu 25 챕터 (도원결의 → 오장원). DEV 챕터 점프 메뉴
> 활용. G-30 (`.claude/rules/godot-4x-gotchas.md`) 패턴 mitigation.
> **Author**: Phase B/C/D/E/F 연속 세션 — 4 commits ahead at attestation time.

---

## 0. 헤드리스 자동화 커버리지 (이미 그린)

**1803/1803 PASS · 0 errors · 0 failures · 276 orphans** (Phase F 시점).

자동화로 검증된 사항:
- 25 챕터 .tres 맵 모두 MapGrid validation 통과 (`map_grid_test.gd`)
- 25 챕터 .tscn 모두 instantiate + ChapterVisuals + map_resource 정상 마운트 (`all_chapters_scene_mount_smoke_test.gd`)
- 25 챕터 모두 `SoundManager.music_id_for_chapter` 신규 슬러그 매핑 + ambient fallback 금지 (`sound_manager_music_test.gd`)
- 25 챕터 모두 `BattleScene.CHAPTER_FLAVOR` title-card entry 존재 (`battle_scene_chapter_flavor_test.gd`)
- 25 챕터 모두 `story_content.json` beat 키 coverage (`story_content_test.gd`)
- 25 챕터 모두 `dev_jump_to_chapter` 점프 happy path (`scenario_runner_dev_jump_to_chapter_test.gd`)
- 25 챕터 풀 chain 드라이브 (default WIN per chapter → SCENARIO_END) (`scenario_runner_chapter_2_advance_test.gd`)
- Phase A/B/C/D/E 각 hydration 가드 (chapter 4개 신규 hydration test)
- Fate field tracking 11/13 wireable + 2 aspirational (`grid_battle_controller_fate_test.gd`)

자동화로 **검증 불가** (G-30 windowed-only gap):
- 시각 렌더링 — Polygon2D / Sprite2D / `_draw()` 호출 발생
- Tween 진행 — 슬라이드, 셰이크, 페이드 (G-31 `process_mode=DISABLED` 트랩)
- 입력 디스패치 — 마우스 클릭 → `InputRouter` → `GameBus` → `GridBattleController`
- 사운드 재생 — `AudioStreamPlayer` 실제 출력
- 객체 수명 — 배틀 종료 후 ObjectDB 누수 (POLISH-008 패턴)
- 카메라 클램프 — 맵 사이즈 변동에 따른 카메라 한계 적용

이 문서가 채우는 갭은 **시각 + 인풋 + 음악**의 일회성 사용자 attestation.

---

## 1. 사전 준비 (한 번만)

```bash
# 클래스 캐시 새로 (`G-14` 가드 — 신규 hero/맵/씬 등록 보장)
godot --headless --import --path .

# 헤드리스 ULL 그린 확인
godot --headless --path . -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd \
    --ignoreHeadlessMode -a res://tests/unit -a res://tests/integration -c
# → Overall Summary: 1803 PASS · 0 errors · 0 failures.

# Godot 4.6 windowed 빌드 실행
godot --path . scenes/main_menu/main_menu.tscn
```

DEV 챕터 점프 버튼은 디버그 빌드(`OS.has_feature("debug")` = true)에서만 가시. 평소 `godot --path .` 호출이 디버그 빌드 — 별도 플래그 불필요.

---

## 2. 챕터별 시각 + 인풋 + 음악 체크 (25 챕터 × ~30초 = ~13분)

각 챕터마다 DEV 챕터 점프 → ChapterVisuals 렌더 → 1~2 턴 진행 → 마우스 클릭 응답 → BGM 청취 → 캠페인 메뉴 복귀.

검증 항목 (체크박스 — `[x]` 마크 후 master plan 100% 인증):

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

### Phase C (익주 입성)

- [ ] **ch15_fushui_pass** — 15×9 산악 협곡. 방통 (unit 16) 합류 7 unit. REACH_TILE target [14,4] 표시. BGM: ch02 bridge.
- [ ] **ch16_luofeng_slope** — 14×10 narrow ridge. MOUNTAIN 양옆. **시그니처 시도**: 조운/마초 (CAVALRY) FOREST 타일 [5,3]/[6,3] 위치 → `scout_first_turns >= 2` → `WIN_luofeng_pang_tong_lives`. BGM: ch01 descending.
- [ ] **ch17_chengdu_gates** — 16×10 성도. FORTRESS_WALL ring + 3 gates. BGM: ch04 warmth.

### Phase D (한중·이릉·시그니처 분기 3개)

- [ ] **ch18_hanzhong_advance** — 16×11 산악. MOUNTAIN 양옆. 마초 (unit 17) 합류 7 unit. BGM: ch02 bridge.
- [ ] **ch19_dingjun_peak** — 14×10 중앙 봉우리. MOUNTAIN 중앙 + HILLS approach. **시그니처 시도**: 황충 (unit 9) 직접 하후돈 (unit 2) kill → `huang_zhong_xiahou_yuan_kill = 1` → `WIN_dingjun_old_general_proven`. BGM: ch02 bridge.
- [ ] **ch20_fancheng_pursuit** — 16×10 번성. FORTRESS_WALL fragmentary + retreat FOREST. SURVIVE 6. **시그니처 시도**: [13,5] 게이트 주변 적 부재 3턴 → `retreat_path_clear_turns >= 3` → `WIN_fancheng_guan_yu_survives` (영걸전 시그니처 #3). BGM: ch05 fire climax.
- [ ] **ch21_zhangfei_avenge** — 14×9 군영. **시그니처 시도**: 친군 손실 없이 4턴 → `discipline_turns >= 4` → `WIN_zhangfei_survives` (영걸전 시그니처). BGM: ch01 descending.
- [ ] **ch22_yiling_burn** — 14×11 협곡 + RIVER + FIRE 8 타일. SURVIVE 6. **시그니처 시도**: FIRE 타일 2턴 이상 유지 → `counter_fire_turns >= 2` → `WIN_yiling_liu_bei_survives` (영걸전 시그니처 #4). BGM: ch05 fire climax.

### Phase E (남만·북벌·오장원·영걸전 finale)

- [ ] **ch23_southern_pacify** — 14×10 정글. FOREST heavy + RIVER + BRIDGE [7,5]. 맹획 (unit 14 = qun_001_lu_bu placeholder) boss 폴리곤. (`menghuo_captures` aspirational — 시그니처 트리거 불가, narrative 그대로.) BGM: ch03 wandering.
- [ ] **ch24_jieting_pass** — 14×11 산악. 강유 (unit 18) 합류 5 unit. REACH_TILE target [12,5]. **시그니처 시도**: 친군이 [7,5] 위치 사수 3턴 → `masu_supervised_turns >= 3` → `WIN_jieting_masu_survives`. BGM: ch02 bridge.
- [ ] **ch25_wuzhang_plains** — 16×11 오장원. HILLS 본진 cluster + 위수 RIVER. SURVIVE 8. **시그니처 최종 시도**: 제갈량 (unit 13) [7,5] 위치 사수 6턴 → `qixing_turns >= 6` → `WIN_wuzhang_kongming_revives` (영걸전 최종 시그니처 #5). BGM: ch05 fire climax — finale.

---

## 3. Boot fault 발생 시

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

---

## 4. 시그니처 5개 분기 in-battle 트리거 검증

마지막 시그니처 시도가 실제로 발화하는지는 [Beat 8 reveal] 텍스트로 확인 가능:

| # | 챕터 | 헤드리스 Field | Default Beat 8 | Hidden Beat 8 |
|---|------|--------|----------------|---------------|
| 1 | ch16 | scout_first_turns ≥ 2 | "낙봉파 — 공명의 도착, 봉추의 추모" | **"낙봉파 — 봉이 떨어지지 않다"** |
| 2 | ch20 | retreat_path_clear_turns ≥ 3 | "맥성 — 관우의 마지막 길" | **"관우 생환 — 청룡이 칼을 풀지 않다"** |
| 3 | ch21 | discipline_turns ≥ 4 | "낭중의 밤 — 장비의 마지막" | **"장비 생존 — 규율의 밤"** |
| 4 | ch22 | counter_fire_turns ≥ 2 | "백제성 — 유비의 마지막 자리" | **"유비 생환 — 맞불의 강"** |
| 5 | ch25 | qixing_turns ≥ 6 | "오장원 — 별이 떨어지다 (정사 canonical)" | **"제갈량 회생 — 별이 꺼지지 않다 (영걸전 최종)"** |

5개 모두 헤드리스 trigger 가능 — windowed에서도 (전투 시스템 결함 없으면) 동일 발화.

---

## 5. 인증 종료 조건

- [ ] 25 챕터 모두 windowed boot fault 0건
- [ ] 25 챕터 모두 ChapterVisuals 시각 렌더링 (FORTRESS_WALL / RIVER / FIRE / HILLS 시각 식별 가능)
- [ ] 5 시그니처 분기 1개 이상 실제 windowed에서 트리거 확인 (대표적으로 ch21 `discipline_turns >= 4` 가장 쉬움)
- [ ] BGM 5 슬러그 모두 청취 (CH01 / CH02 / CH03 / CH04 / CH05 — 챕터 사이 전환 자연스러움)
- [ ] DEV 챕터 점프 메뉴 자체 — 25 행 표시 + 클릭 응답 (메뉴 길이가 너무 길면 polish 후보)

전부 통과 시 본 문서에 `Status: PASS — attested YYYY-MM-DD by <user>` 헤더 추가하고 commit.

---

## 6. 향후 정식 windowed smoke harness (Sprint-N+1 candidate)

G-30 §6 "Wrapper script suggestion" 패턴:

```bash
tools/ci/windowed_chapter_smoke.sh
# godot --headless --path . scenes/battle/mvp_chapter_NN.tscn --quit-after 60
# stderr 캡처 + push_error / push_warning 없음 검증
# 25 챕터 모두 통과 시 exit 0
```

자동화 가능하지만 windowed 렌더링 (Polygon2D draw, 캡처)은 여전히 사람이 봐야 함. G-30 META 패턴은 — 자동화로 어디까지 커버하든 한 단계 위 META 갭이 남는다 — 정상.
