# Quick Design Spec: ch10 Chibi Perfect Wind — 동남풍이 다 식기 전에 (전원 생존)

**Type**: Substrate add (1 fate_data field) + chapter ★ entry author + sentinel
**System**: GridBattleController fate_data (new `_fate_player_casualties` field) + ch10 chapter ★ trigger author
**Date**: 2026-05-25
**Anchor docs**:
  - `design/narrative/branch-distribution-plan.md` §4.3 (ch10 적벽 — 동남풍 perfect timing)
  - `design/gdd/destiny-branch.md` — HiddenConditionEvaluator `fate_threshold`
  - `design/gdd/game-concept.md` Pillar 2 (운명은 바꿀 수 있다)
**GDD Reference**:
  - `design/gdd/scenario-progression.md` — ChapterDefinition schema (변경 없음)
**ADR Dependencies**: ADR-0017/0018 reference. ADR-0014 minor amendment 후보 (fate_data emit field add — additive, not breaking).

---

## 1. Change Summary

ch10 (적벽 본전) ★ trigger `WIN_chibi_perfect_southeast_wind` (canonical: `WIN_chibi_main_burn`) 신규 author. Plan §4.3 의 "동남풍 perfect timing — 전원 생존" 가설을 substrate-add + entity-less path 로 구현. ch08 model 위에 *substrate 1-line add* (`_fate_player_casualties: int` field — fate_data 의 17번째 entry) — entity 신규 0, visualization 0. ch05 의 4-layer 대비 mid-weight (substrate add 만), ch08 의 entity-less 대비 약간 무거움 (substrate edit 필요).

핵심: 사용자가 ch10 적벽 본전에서 5턴 survive + 모든 player unit 생존 시 ★. "동남풍이 다 식기 전에 — 자세를 잡고 끝까지 버텼다" 의 narrative felt.

## 2. Motivation

`design/narrative/branch-distribution-plan.md` §4.3 declares ch10 ★ 를 "동남풍 perfect timing" 의 mechanical 증명 — Plan §4.1/§4.2 (ch05/ch08, S79-S82 ship-ready) 다음 ★. 현 ship 상태:

- **Partial scaffold**: ch10 chapter 의 `branch_table` = `{WIN_default: WIN_chibi_main_burn, LOSS_default: LOSS_chibi_main_wind_fails}` — **★ entry 자체 부재** (`WIN_hidden` 누락 + `hidden_branch_key` + `hidden_condition` 모두 부재). echo_threshold=2 + canonical_branch_key 만 set. victory_conditions = SURVIVE_N_ROUNDS+survive_rounds=5.
- **Substrate gap**: Plan §4.3 의 "전원 생존" 의 substrate (`_fate_all_player_units_alive` / `_fate_player_casualties` / etc.) 가 fate_data 에 emit 안 됨. `_compute_star_rating` (line 1149-1163) 에서 `all_alive: bool = (surviving == total and total > 0)` 계산 하지만 fate_data 에 expose 안 함.

본 spec 은 두 gap 모두 close — 1-line substrate add (declaration + increment in `_on_unit_died` + fate_data emit) + chapter JSON 의 ★ entry author. ch10 외 chapter 영향 0 (substrate 추가 만, default-only chapter 의 hidden_condition 사용 안 함 — fate_data 의 다른 field 처럼).

## 3. Design Delta (3 obligations)

### 3.1 Substrate add: `_fate_player_casualties` field (1 production source edit)

`grid_battle_controller.gd` 에 3-layer 추가:

```gdscript
# Layer 1 — declaration (alongside other _fate_* fields, line ~425):
var _fate_player_casualties: int = 0

# Layer 2 — increment site (in _on_unit_died, after existing handlers):
#   battle_unit = _units.get(unit_id)
#   if battle_unit != null and battle_unit.side == 0:  # player side
#       _fate_player_casualties += 1
#       hidden_fate_condition_progressed.emit(&"player_casualties", _fate_player_casualties)

# Layer 3 — fate_data emit (line ~3363+):
#   "player_casualties": _fate_player_casualties,
```

`_fate_player_casualties` 는 battle 시작 = 0, player-side unit 사망 시 +1 (enemy-side 영향 0). hidden_condition `{fate_threshold, player_casualties, <=, 0}` 가 "casualties == 0" (전원 생존) 와 정합. SURVIVE_N_ROUNDS 5턴 후 WIN outcome 시 fate_data emit + HiddenConditionEvaluator evaluation → ★ branch routing.

### 3.2 ch10 chapter JSON edit — ★ entry author

**As-is** (`assets/data/scenarios/shu_canon_main.json` ch10):
```json
"branch_table": {
  "WIN_default": "WIN_chibi_main_burn",
  "LOSS_default": "LOSS_chibi_main_wind_fails"
}
```

**To-be**:
```json
"branch_table": {
  "WIN_default": "WIN_chibi_main_burn",
  "WIN_hidden": "WIN_chibi_perfect_southeast_wind",
  "LOSS_default": "LOSS_chibi_main_wind_fails"
},
"hidden_branch_key": "WIN_hidden",
"hidden_condition": {
  "type": "fate_threshold",
  "field": "player_casualties",
  "op": "<=",
  "value": 0
}
```

`canonical_branch_key` + `echo_threshold` + `victory_conditions` 모두 변경 없음. Beat 8 prose key `WIN_chibi_perfect_southeast_wind` (i18n text_key) 별도 verify (Plan §4.3 의 "동남풍이 다 식기 전에" anchor).

### 3.3 victory_conditions 유지

ch10 의 `victory_conditions` = SURVIVE_N_ROUNDS+survive_rounds=5 **변경 없음**. Plan §4.3 의 "빠른 격퇴" hypothesis 거부 — 적벽 본전은 본질적으로 "5턴 survive" 의 timing (동남풍 5턴 metaphor). ★ trigger 는 SURVIVE WIN 의 *부수 조건* (player_casualties == 0) 으로 자연 결합.

## 4. New Rules / Values

### 4.1 player_casualties threshold = 0

**0 선택 이유**:
- "전원 생존" 의 가장 직접적 mechanical lock — narrative 정합 (Plan §4.3 "동남풍이 다 식기 전에 — 자세를 잡고")
- 사용자에게 명확 — "single death = ★ fail" 의 clear feedback
- echo_threshold=2 가 difficulty balance (첫 시도 실패 후 학습 후 가능)

**OQ-1**: 0 (전원 생존) vs ≤1 (1명 사상 OK) — Manual playtest 후 tuning.

### 4.2 ★ branch_path_id = `WIN_chibi_perfect_southeast_wind`

Plan §4.3 가설 그대로. Beat 8 prose 신규 author 또는 기존 i18n key 검증 별도 task.

### 4.3 echo_threshold = 2 (현재 데이터 유지)

Plan §4.3 + 현재 데이터 정합. signature ★ scarcity.

### 4.4 비대상 (out of scope)

- 신규 entity 시스템 — civilian 같은 mechanic 없음.
- victory_conditions 변경 — SURVIVE_N_ROUNDS 유지.
- 신규 ChapterDefinition field — substrate 만 fate_data emit field add.
- ch10 외 chapter 영향 — substrate add 가 다른 chapter 에 visible 단 hidden_condition.field 가 chapter 별로 다르므로 단순 expose만.

## 5. Implementation Order (commits)

| # | Commit | Scope | 의존 |
|---|--------|-------|------|
| 1 | `design: ch10 chibi perfect wind quick-spec` | 본 doc | — |
| 2 | `impl: _fate_player_casualties substrate (3-layer add)` | grid_battle_controller.gd declaration + increment in _on_unit_died + fate_data emit | commit 1 |
| 3 | `data: ch10 ★ entry author + sentinel tests` | shu_canon_main.json ch10 의 branch_table.WIN_hidden + hidden_branch_key + hidden_condition + ch10 sentinel test (4 tests) | commit 2 |
| 4 | `test: ch10 perfect wind e2e — ★ routing` | integration test 3 (★ at casualties=0 / canonical at 1+ / LOSS) | commit 3 |

**본 세션 scope**: 4 commits (spec + impl). Plan §11 Step 5 의 ch10 ★ 전체 ship. MVP 5/5 ★ ship-ready 완성.

## 6. Acceptance Criteria

- [ ] **AC-1**: `design/quick-specs/ch10-chibi-perfect-wind.md` 존재, 8 sections.
- [ ] **AC-2**: ch10 chapter JSON 의 `branch_table.WIN_hidden = "WIN_chibi_perfect_southeast_wind"` + `hidden_branch_key = "WIN_hidden"` + `hidden_condition = {fate_threshold, player_casualties, <=, 0}`.
- [ ] **AC-3**: `victory_conditions` SURVIVE_N_ROUNDS+survive_rounds=5 변경 없음 (regression sentinel).
- [ ] **AC-4**: `canonical_branch_key` + `echo_threshold = 2` 변경 없음.
- [ ] **AC-5**: `grid_battle_controller.gd` 에 `_fate_player_casualties: int = 0` declaration + `_on_unit_died` 의 player-side casualty increment + fate_data emit 의 3-layer 모두 present.
- [ ] **AC-6**: 다른 16 chapters (ch01-09, ch11-16 + Wei + mvp_wei) 영향 0 (sentinel: substrate 추가가 default-only chapter 의 hidden_condition 사용 안 함).
- [ ] **AC-7**: Integration test — fate_data `{player_casualties: 0}` + WIN outcome → `WIN_chibi_perfect_southeast_wind` (★). `{player_casualties: 1}` + WIN → `WIN_chibi_main_burn` (canonical). LOSS → `LOSS_chibi_main_wind_fails`.
- [ ] **AC-8**: 1989+ tests PASS 유지 + 신규 sentinel (4) + integration (3) = 1996 target.

## 7. Test Plan

**신규 sentinel tests** (`tests/unit/feature/story_event/ch10_chibi_perfect_wind_sentinel_test.gd`):
1. `test_ch10_hidden_condition_player_casualties_le_0` — exact shape `{fate_threshold, player_casualties, <=, 0}`.
2. `test_ch10_branch_table_includes_win_hidden_after_authoring` — `WIN_hidden` entry exists + 3 branches.
3. `test_ch10_victory_conditions_survive_5_unchanged` — SURVIVE_N_ROUNDS regression sentinel.
4. `test_ch10_player_casualties_substrate_present_in_controller` — 3-layer grep sentinel (decl + increment + emit).

**신규 integration tests** (`tests/integration/destiny_branch/ch10_chibi_perfect_wind_branch_routing_test.gd`):
5. `test_ch10_perfect_wind_triggers_hidden_branch_at_zero_casualties` — fate_data `{player_casualties: 0}` + WIN → `WIN_chibi_perfect_southeast_wind`.
6. `test_ch10_falls_back_to_canonical_at_any_casualty` — fate_data `{player_casualties: 1}` + WIN → `WIN_chibi_main_burn`.
7. `test_ch10_loss_routes_to_wind_fails` — LOSS → `LOSS_chibi_main_wind_fails`.

**Regression baseline**: 1989 + 7 = 1996 PASS target.

## 8. Risks / Open Questions

| ID | Question | Default 답 | 결정 시점 |
|----|----------|-----------|-----------|
| OQ-1 | player_casualties threshold = 0 vs ≤1 vs ≤2? | **0** (전원 생존 narrative 정합) — Open for manual playtest tuning | Commit 4 후 manual playtest |
| OQ-2 | `_fate_player_casualties` increment timing — `_on_unit_died` vs `_on_unit_visual_died` (re-emit)? | **`_on_unit_died`** (controller-internal, fire before unit_visual_died.emit per existing pattern e.g. _civilian_recover_on_carrier_death:1276) | Spec 확정 시 — 본 spec 으로 잠금 |
| OQ-3 | player-side filter — `battle_unit.side == 0` 확인 OR is_player_controlled? | **`side == 0`** (ADR-0014 §3 의 grid runtime field, more direct than is_player_controlled 의 legacy back-compat) | Spec 확정 시 — 본 spec 으로 잠금 |
| OQ-4 | Beat 8 의 `WIN_chibi_perfect_southeast_wind` prose 존재? | **검증 후 결정** — 부재 시 narrative-director spawn (1 prose authoring) | Commit 4 후 prose audit |
| OQ-5 | enemy-side death 의 영향 — counter += 0 OK? | **OK** — player_casualties 의 의미는 "우리 측 손실". enemy 사망 영향 없음 (그건 victory progress 일 뿐) | Spec 확정 시 — 본 spec 으로 잠금 |
| OQ-6 | friendly-fire death — counter += 1 포함? | **포함** — 어떤 player-side 사망이든 counter 증가. friendly fire 가 ch10 에서 일어날 시나리오 거의 없음 (REACH_TILE 아니라 SURVIVE) 단 defensive | Spec 확정 시 — 본 spec 으로 잠금 |
| OQ-7 | 본 spec 의 ADR 영향 — fate_data field add 는 ADR-0014 minor amendment? | **ADR amendment 1-line block 후보** — 또는 commit message inline reference 만 (Build mode dormant gate-check 이라 inline 충분) | Spec 확정 시 — 본 spec 으로 잠금 |
| OQ-8 | (S82 codification ref) Substrate field name 사전 검증 | **Done at spec authoring** — `player_casualties` 가 grid_battle_controller.gd 에 부재 (grep zero) 확인 + spec impl commit 2 가 substrate 추가. 신규 field 이므로 misalignment 위험 없음 (ch08 trap 과 inverse case — 부재 → 추가). | Spec 확정 시 — closed |

---

> **Authoring note**: per `.claude/rules/design-docs.md` and S78/S79/S82 codified rule (incremental authoring batch + substrate verification + single recommended path), 본 spec 은 핵심 3 결정 (substrate `_fate_player_casualties` 신규 add / hidden_condition `player_casualties <= 0` / victory_conditions SURVIVE_N_ROUNDS 유지) 이 spec authoring 전 잠금되어 single-batch authoring. ADR 신규 불필요 (ADR-0014 fate_data emit field add 는 additive minor amendment, commit message inline reference 로 충분).

> **S82 amendment cross-ref**: ch05 §4.3 (counter HUD pulse 거부 — Pillar 2 lock) + ch08 §3.3 (substrate verification — turn_count → win_within_turns) + ch10 (substrate add → fate_data field 신규 — substrate misalignment 의 inverse case) 의 3-instance series — spec authoring rule strengthening 의 stable pattern. `.claude/rules/design-docs.md` amendment 시 본 3-instance 가 reference cases.
