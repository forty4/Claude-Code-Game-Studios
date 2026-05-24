# Quick Design Spec: ch08 Alliance Timing — 결의의 timing (재집결의 속도)

**Type**: Tuning + sentinel (entity-less; 기존 HiddenConditionEvaluator `fate_threshold` + REACH_TILE substrate 재사용)
**System**: ch08 chapter data + DestinyBranchJudge routing (no new systems)
**Date**: 2026-05-24
**Anchor docs**:
  - `design/narrative/branch-distribution-plan.md` §4.2 (ch08 하구 적의동맹 — 결의의 timing)
  - `design/gdd/destiny-branch.md` — HiddenConditionEvaluator `fate_threshold` predicate
  - `design/gdd/game-concept.md` Pillar 2 (운명은 바꿀 수 있다)
**GDD Reference**:
  - `design/gdd/scenario-progression.md` — ChapterDefinition schema (변경 없음)
**ADR Dependencies**: ADR-0018 (DestinyBranchJudge), ADR-0017 (ChapterDefinition schema) — 신규 ADR 불필요 (재사용)

---

## 1. Change Summary

ch08 (하구 외곽) ★ trigger `WIN_xiakou_united_advance` (canonical: `WIN_xiakou_breakthrough`) 의 hidden_condition 을 **turn-limit 기반** (`turn_count <= 6`) 으로 spec 잠금. Plan §4.2 의 "결의의 timing — 빠른 재집결" 가설을 entity-less + light path 로 구현 — 기존 fate_threshold predicate + REACH_TILE victory + round counter substrate 재사용. ch05 처럼 신규 entity / state machine / visualization layer 불필요.

핵심: 사용자가 유비 (unit_id=0) 를 6턴 이내에 [13,4] (하구 재집결 지점) 도달 시 ★. "사신이 오기 전 이미 준비된 모습" 의 narrative felt.

## 2. Motivation

`design/narrative/branch-distribution-plan.md` §4.2 declares ch08 의 ★ 를 "결의의 timing" 의 mechanical 증명 — Plan §4.1 의 ch05 ★ ("백성 evacuation", S79 mechanical substrate 완성) 다음 ★. 현 ship 상태:

- **Scaffold 존재**: ch08 chapter 의 `branch_table` (default+hidden+loss), `hidden_branch_key` = `WIN_hidden`, `canonical_branch_key` = `WIN_xiakou_breakthrough`, `echo_threshold` = 1 모두 wired. `victory_conditions` = REACH_TILE [13,4] 유비 unit_id=0 도달.
- **Gap**: 기존 `hidden_condition` 은 `{type: fate_threshold, field: formation_turns, op: >=, value: 3}` — `formation_turns` 라는 counter 가 GridBattleController 에 존재하지 않음 (`formation_turns` field 부재). 즉 ★ 가 영원히 unreachable + spec authoring time 의 hypothetical hidden_condition 이 실제 substrate 와 불일치.

본 spec 은 그 gap 을 close — entity-less light path 채택. `formation_turns` (도원 형제 인접 대형 N 턴 유지 mechanic, 신규 substrate 필요) 거부, **turn_count <= 6** 만 사용 (HiddenConditionEvaluator + grid_battle_controller `_fate_round_count` 또는 동등 counter 의 기존 substrate 재사용).

## 3. Design Delta (3 obligations)

### 3.1 hidden_condition 변경 (chapter JSON only)

**As-is** (`assets/data/scenarios/shu_canon_main.json` ch08):
```json
"hidden_condition": {
  "type": "fate_threshold",
  "field": "formation_turns",
  "op": ">=",
  "value": 3
}
```

**To-be**:
```json
"hidden_condition": {
  "type": "fate_threshold",
  "field": "turn_count",
  "op": "<=",
  "value": 6
}
```

`turn_count` field 는 GridBattleController 가 fate_data 에 emit 하는 round counter (또는 동등 — §3.3 verification 항목). `op: <=` 는 HiddenConditionEvaluator 의 fate_threshold 가 이미 지원 (cross-ref: hidden_condition_evaluator.gd `_eval_fate_threshold`).

### 3.2 victory_conditions 유지

ch08 의 `victory_conditions` = REACH_TILE (primary_condition_type=3, target_unit_ids=[0], target_tile=[13,4]) **변경 없음**. Plan §4.2 의 hypothetical "적 격퇴" 와 deviation 있지만 narrative ("도주→재집결") 정합으로 REACH_TILE 유지. ★ = "REACH_TILE 을 ≤6턴 이내 도달" 의 timing condition 으로 자연 결합.

### 3.3 fate_data emit shape 검증

GridBattleController 가 fate_data 에 `turn_count` field 를 emit 하는지 (또는 equivalent — `round_count`, `current_round` 등) 검증 필요. 만약 부재 시 본 spec 의 ADR 단계에서 1-line field 추가 (ADR-0014 minor amendment 후보, 또는 controller 의 `_fate_data` build 함수 1-line edit). impl 단계 의 첫 task.

## 4. New Rules / Values

### 4.1 turn_count threshold = 6

**6턴 선택 이유** (Plan §4.2 default):
- ch08 의 enemy_atk_mult 0.75 (moderate) + chokepoints 2칸 (col 4) — player 가 chokepoint 통과 + 평균 이동 거리 ~10칸 (시작 col 1-2 → 목표 col 13) ≈ 5-7 턴 합리.
- 6턴 = 사용자 평균 페이스의 *약간 빠른* 쪽. 너무 쉬우면 ★ 가치 falloff, 너무 어려우면 echo gate 필요.
- echo_threshold=1 의미: 첫 시도 실패 시 1회 echo 후 ★ 시도 가능. 처음에는 약간 어려움이 design intent.

**OQ-1**: 6턴 vs 5턴 vs 7턴 — Manual playtest 후 tuning (spec OQ).

### 4.2 echo_threshold = 1 (현재 데이터 유지)

Plan §4.2 hypothesis 는 `echo_threshold = 2` 권장 (★ scarcity 강화). 현재 데이터 = 1 유지 (deviation note). 이유:
- ch08 ★ 가 timing-based — 1회 시도 후 사용자가 "내가 너무 늦었다" 를 *명확히 깨달음* (turn count 가 결과 화면에 reveal). 즉시 학습 가능 → echo 1회로 충분.
- ch05 ★ (civilians_escorted) 는 spatial — 사용자가 어디 token 이 있는지 학습 필요 → echo 2 합리.
- ch08 의 echo=1 + ch05/ch10/ch13/ch16 의 echo=2 distribution 가 ★ 들 사이 difficulty curve 분산.

**OQ-2**: echo_threshold = 1 vs 2 — Manual playtest 후 결정.

### 4.3 ★ branch name 유지

현재 데이터 `WIN_xiakou_united_advance` 유지. Plan §4.2 hypothetical name `WIN_xiakou_alliance_perfect_timing` 거부 — 현재 name 이 narrative ("동맹 결의의 결의된 진군") 와 align + Beat 8 prose 가 이미 이 name 으로 wired (검증 필요 — spec impl 단계).

### 4.4 비대상 (out of scope)

- 신규 mechanic — `formation_turns` counter / multi-condition combo / commander HP threshold 등 거부.
- victory_conditions 변경 — REACH_TILE 유지.
- 신규 ChapterDefinition field — fate_data emit shape 가 turn_count 이미 보장 시 0 schema 변경.
- Wei roster / chokepoint / atk_mult / enemy 변경 — 본 spec scope 밖 (S78 의 ch01 vertical-slice 같은 felt tuning 은 별도 vector).

## 5. Implementation Order (commits)

| # | Commit | Scope | 의존 |
|---|--------|-------|------|
| 1 | `design: ch08 alliance timing quick-spec` | 본 doc | — |
| 2 | `data: ch08 hidden_condition turn-limit 6 + Beat 8 ★ prose verify` | shu_canon_main.json edit (3 lines) + Beat 8 substring sentinel 검증 | commit 1 |
| 3 | `verify: turn_count field in fate_data + ★ branch routing` | grid_battle_controller fate_data emit 검증 (필요 시 1-line add) + integration test 3 (★ trigger e2e + canonical contrast + LOSS) | commits 1-2 |
| 4 | `test: ch08 alliance sentinel — chapter data + ★ routing` | sentinel tests 3 (hidden_condition exact / echo_threshold / ★ branch name) + integration 3 (★ at 6 turns / default at 7+ turns / canonical vs hidden distinction) | commit 3 |

**본 세션 scope**: commit 1 (spec authoring only). commits 2-4 (impl arc) 다음 세션 — ch05 의 design+ADR+impl arc 가 4-5 sessions 였던 것에 비해 ch08 은 entity-less 라 ~1-2 sessions 예상. ADR 신규 불필요 (재사용).

## 6. Acceptance Criteria

- [ ] **AC-1**: `design/quick-specs/ch08-alliance-timing.md` 존재, 8 sections 완성.
- [ ] **AC-2**: ch08 chapter JSON 의 `hidden_condition` = `{type: fate_threshold, field: turn_count, op: <=, value: 6}`.
- [ ] **AC-3**: `victory_conditions` REACH_TILE [13,4] 변경 없음 (regression sentinel).
- [ ] **AC-4**: `branch_table` + `hidden_branch_key` + `canonical_branch_key` + `echo_threshold` 모두 현재 데이터 유지 (sentinel).
- [ ] **AC-5**: Beat 8 의 ★ branch prose (`win_xiakou_united_advance` 또는 equivalent) 가 "사신이 오기 전 이미 준비됨" 의미를 담음 — 신규 prose authoring 또는 기존 prose 검증.
- [ ] **AC-6**: GridBattleController fate_data 에 `turn_count` field 가 emit 됨 (또는 equivalent — round_count, current_round). 부재 시 1-line add.
- [ ] **AC-7**: HiddenConditionEvaluator `_eval_fate_threshold` 의 `op: <=` 동작 검증 — 기존 unit tests cover 확인 (cross-ref `tests/unit/feature/destiny_branch/hidden_condition_evaluator_test.gd`).
- [ ] **AC-8**: Integration test — fixture 에서 turn_count=6 + WIN outcome + REACH_TILE 도달 시 DestinyBranchJudge resolves to `WIN_xiakou_united_advance`. turn_count=7 시 `WIN_xiakou_breakthrough` (canonical).
- [ ] **AC-9**: 1969+ tests PASS 유지 + 신규 sentinel + integration 3-6.
- [ ] **AC-10**: 기존 22 chapters (ch01-ch07, ch09-ch16 + Wei + mvp_wei) regression 0.

## 7. Test Plan

**신규 sentinel tests** (`tests/unit/data/`):
1. `test_ch08_hidden_condition_turn_count_le_6` — exact shape `{type: fate_threshold, field: turn_count, op: <=, value: 6}`.
2. `test_ch08_echo_threshold_is_1` — regression sentinel for design decision §4.2.
3. `test_ch08_branch_table_unchanged_post_alignment` — 3 branches (default/hidden/loss) names locked.
4. `test_ch08_victory_conditions_reach_tile_13_4_unchanged` — REACH_TILE field set locked.

**신규 integration tests** (`tests/integration/feature/grid_battle/` 또는 `tests/integration/destiny_branch/`):
5. `test_ch08_alliance_timing_triggers_hidden_branch_at_turn_6` — fate_data `{turn_count: 6}` + WIN outcome → DefaultDestinyBranchJudge.resolve → `WIN_xiakou_united_advance`.
6. `test_ch08_alliance_timing_falls_back_to_canonical_at_turn_7` — fate_data `{turn_count: 7}` + WIN → `WIN_xiakou_breakthrough` (default WIN branch).
7. `test_ch08_loss_routes_to_pursuit_continues` — LOSS outcome → `LOSS_xiakou_pursuit_continues` (regression sentinel).

**Regression baseline**: 1969 (current) + 7 신규 = 1976 PASS target. Commits 2-3-4 의 cumulative test deltas. Commit 2 가 sentinel (1-4), Commit 3-4 가 integration (5-7).

## 8. Risks / Open Questions

| ID | Question | Default 답 | 결정 시점 |
|----|----------|-----------|-----------|
| OQ-1 | turn_count threshold = 6 vs 5 vs 7? | **6** (Plan §4.2 default, mid-range 합리) — Open for manual playtest tuning | Commit 4 후 manual playtest |
| OQ-2 | echo_threshold = 1 vs 2? | **1** (현재 데이터 유지, ch08 의 timing-feedback 즉시성) — Plan §4.2 hypothesis 와 deviation note | Spec 확정 시 — 본 spec 으로 잠금 |
| OQ-3 | fate_data 에 `turn_count` field 가 존재하지 않을 경우 — 신규 add path? | **1-line add to `_build_fate_data` (controller 의 fate_data emit 함수)** — ADR amendment 불필요 (additive). 부재 시 impl 단계 첫 task | Commit 3 시점 검증 |
| OQ-4 | Beat 8 의 `WIN_xiakou_united_advance` prose 존재 여부 + "사신 이전 준비됨" 의미 정합 | **검증 후 결정** — 존재 시 그대로, 부재 시 narrative-director spawn (1 prose authoring) | Commit 4 후 prose audit |
| OQ-5 | `formation_turns` field 의 향후 처리 — chapter JSON 에서 *완전 제거* vs *legacy reference* 보존? | **완전 교체** — 본 amendment 이후 어떤 chapter 도 formation_turns 사용 안 함. `formation_turns` 가 substrate 에 없으므로 grep -r 으로 검증 (zero matches) | Commit 2 시점 |
| OQ-6 | ★ ch08 → ch10 cluster impact (Plan §4.2: "ch08 ★ trigger → ch10 banter prose 추가") | **본 spec scope 밖** — ch10 ★ design (Plan §4.3) 의 별도 chapter | ch10 spec authoring 시 |
| OQ-7 | 본 spec impl 의 ADR 영향 — 신규 ADR vs ADR-0017/0018 reference 만? | **ADR 신규 불필요** (재사용) — turn-limit fate_threshold path 가 ADR-0018 의 기존 vocabulary. ADR-0017 의 ChapterDefinition schema 변경 없음. impl 단계의 commit message 만 reference. | Spec 확정 시 — 본 spec 으로 잠금 |

---

> **Authoring note**: per `.claude/rules/design-docs.md` and S78/S79 codified rule (incremental authoring batch — core 2-3 decisions 잠근 후 spec 작성), 본 spec 은 핵심 3 결정 (hidden_condition = turn_count <=6 / victory_conditions REACH_TILE 유지 / echo_threshold 1 유지) 이 spec authoring 전 잠금되어 single-batch authoring. ADR 신규 불필요. Plan §4.2 의 "적 격퇴" hypothesis 는 narrative 정합 (도주→재집결) 위해 "REACH_TILE 도달" 로 변환 — 본 alignment 가 spec 의 decisive 결정.

> **S81 amendment cross-ref**: ch05 spec §4.3 의 "counter HUD pulse" 가 ADR-0015 Pillar 2 lock 위반으로 S81 amendment 로 제거된 사례 (codified at ch05 spec §8 OQ-9). 본 ch08 spec 은 인용 — `fate_threshold` predicate + `lint_battle_hud_hidden_fate_non_subscription.sh` zero-tolerance 와 정합. ★ 가 *Beat 8 results screen 에서만 reveal* 의 Pillar 2 원칙 유지.
