# Quick Design Spec: ch05 Civilian Evacuation — 백성 호송의 첫 mechanical 증명

**Type**: Feature (new system + ch05 ★ trigger 의 mechanical 구현)
**System**: Civilian Token (신규) + ChapterDefinition schema (확장) + GridBattleController fate counter wiring
**Date**: 2026-05-24
**Anchor docs**:
  - `design/narrative/branch-distribution-plan.md` §4.1 (ch05 ★ #1 신야 화공 — 백성 evacuation), §9 (architecture gap — Civilian NPC entity), §11 (Implementation Order Step 3)
  - `design/gdd/game-concept.md` Pillar 2 (운명은 바꿀 수 있다) — ★ 첫 mechanical 증명
  - `design/gdd/destiny-branch.md` — hidden_branch_key + HiddenConditionEvaluator (`fate_threshold`)
**GDD Reference**:
  - `design/gdd/scenario-progression.md` — ChapterDefinition schema (ADR-0017 minor amendment 동반)
  - `design/gdd/hero-database.md` — N/A (civilian = non-hero)
**ADR Dependencies**: ADR-0017 (ChapterDefinition schema), ADR-0018 (DestinyBranchJudge / hidden_condition), ADR-0022 (Civilian System — 신규, 본 spec 와 함께 author)

---

## 1. Change Summary

ch05 (신야 화공) 의 ★ trigger `WIN_xinye_civilians_saved` (hidden_condition: `civilians_escorted >= 3`) 의 **mechanical 구현**. 현재 scenario data + Beat 8 prose + branch routing 은 모두 wired up; `_fate_civilians_escorted` 도 grid_battle_controller 에서 fate_data emit 까지 wired. 단 **counter increment site 가 없음** — token / civilian 개념 자체가 system 에 부재. 본 spec 은 **Stranded Escort Token** model (plan §9 Risk 의 simplification 채택 — 자율 NPC 거부) 로 system 신규 도입하여 plan §11 Step 3 의 design portion + first impl arc 를 deliver.

## 2. Motivation

`design/narrative/branch-distribution-plan.md` §4.1 의 ch05 ★ 는 MVP 의 **첫 신규 ★** — Pillar 2 의 "운명은 바꿀 수 있다" 의 첫 mechanical 증명. 현 ship 상태에서:

- **Scaffold 존재**: ch05 chapter 의 `branch_table`, `hidden_branch_key`, `hidden_condition: {field: civilians_escorted, op: >=, value: 3}`, Beat 8 3-variant prose (`win_xinye_burning_retreat` / `win_xinye_civilians_saved` / `loss_xinye_consumed_with_city`) 모두 wired up.
- **Counter stub 존재**: `grid_battle_controller.gd:419` `var _fate_civilians_escorted: int = 0`, line 3244 `"civilians_escorted": _fate_civilians_escorted` fate_data emit.
- **Gap**: counter 가 영원히 0 — increment site 부재. 사용자가 ch05 도착 시 ★ 가 mechanical 으로 unreachable. `# TODO ch05; needs civilian system` (line 414).

본 spec 은 그 gap 을 close — civilian token entity + state machine + ChapterDefinition civilian_config field + GridBattleController wiring + sentinel tests. design + ADR + first impl arc 본 세션 scope (plan §11 Step 3 의 4-6 세션 중 첫 ~2 세션).

## 3. Design Delta (3 obligations)

### 3.1 Civilian Token entity (신규 — ADR-0022)

**Model**: Stranded Escort Token. 맵 상에 N=5 static token 흩어져 있고, player unit 이 *player turn 종료 시 인접* 시 escort flag on (carrier 1:1 bind). carrier 가 evacuate-zone (col 0) 도달 시 token = SAVED 처리 + counter +1. carrier 사망 시 token 은 carrier 의 마지막 cell 로 IDLE 회귀.

**State machine**:
```
IDLE ──(player carrier ends turn adjacent)──> ESCORTED ──(carrier reaches col <= evacuate_zone_max_col)──> SAVED
                                                  │
                                                  └──(carrier dies)──> IDLE (at carrier's last cell)
```

**Properties**:
- 비전투 (non-combatant): HP 없음, FIRE tile 영향 없음, 적 인접 영향 없음 (passive)
- Single-token-per-carrier (carrier 가 이미 ESCORTED token 보유 시 추가 pickup 차단)
- Token-cell occupancy: IDLE 상태 token 의 cell 은 unit movement 차단 안 함 (token 위로 walk-over 가능 — pickup 은 *end-of-turn adjacency* 로만 trigger, walk-through 는 pickup 아님)
- SAVED → token despawn (UI 에서 제거 + counter +1, irreversible)

**비대상 (out of scope)**:
- 자율 이동 (plan §4.1 의 원안 "백성 자율 1칸/턴 서쪽 이동" 거부 — single-chapter ROI 부족)
- HP / damage / 적 공격
- Multi-token-per-carrier
- ChapterDefinition 외 chapter 에서 의 token 사용 (ch05 only — Future Vision 의 ch06 장판파 / ch20 맥성 등 재사용 시 본 ADR 재방문)

### 3.2 ChapterDefinition schema extension — `civilian_config`

**As-is**: ChapterDefinition 에 civilian-related field 없음.

**To-be** (ADR-0017 minor amendment):
```gdscript
## Optional civilian token config for chapters with stranded-escort ★ trigger.
## Empty Dictionary = no civilian system active (default for all chapters except ch05).
## Runtime shape: {"positions": Array[Array[int]] (each [col, row]), "evacuate_zone_max_col": int}
@export var civilian_config: Dictionary = {}
```

JSON authoring:
```json
"civilian_config": {
  "positions": [[3, 2], [4, 5], [4, 7], [5, 3], [6, 6]],
  "evacuate_zone_max_col": 0
}
```

기존 22 chapters 영향 없음 (Dictionary 가 비어있으면 civilian system inactive). Backwards-compatible. ADR-0017 minor amendment (Evolution Rule #4) — 본 spec 과 함께 same-patch.

### 3.3 GridBattleController fate_civilians_escorted increment wiring

**As-is**: `_fate_civilians_escorted: int = 0` 영원히 0.

**To-be**:
- Chapter init 시 civilian_config 읽고 N civilian token spawn (positions + state=IDLE).
- Player turn 종료 시 (turn_order_runner 의 player turn-end signal) — 각 player unit 의 8-neighbor cells 에서 IDLE token 찾고, 발견 시 first-found token → ESCORTED bind (carrier capacity check). 동시 다발 pickup 시 unit_id ascending 순서.
- Carrier movement 후 carrier.col <= civilian_config.evacuate_zone_max_col → token = SAVED + `_fate_civilians_escorted += 1` + token despawn.
- Carrier 사망 (BattleUnit HP <= 0) → ESCORTED token 분리, last cell 에 IDLE 복귀. last cell 이 unit-occupied 시 nearest non-occupied non-FIRE 4-neighbor cell.

**Single source-of-truth**: increment site = GridBattleController 내 single 함수 (예: `_civilian_commit_save(token_id)`). 다른 코드에서 `_fate_civilians_escorted` 직접 mutate 금지 (lint candidate).

## 4. New Rules / Values

### 4.1 ch05 civilian_config

| Token | Position [col, row] | 설정 이유 |
|-------|---------------------|-----------|
| 1 | [3, 2] | Near player start (col 1-2) — 1-2 turn round-trip — easy first save |
| 2 | [5, 3] | Mid-grid, chokepoint [5,4] adjacent — 약간의 위험 |
| 3 | [4, 5] | Mid-grid south flank — 우회 path 고려 |
| 4 | [4, 7] | South-mid, chokepoint 라인 회피 — 다른 path 가능 |
| 5 | [6, 6] | Deepest, near enemy line (col 9-10) — risk/reward — 가장 도전적 |

★ trigger 는 **3+** save — 5 token 중 3 save 가 minimum. Player 가 token 3 까지 (easy + 2 mid) 안전 path 로 가능, 4-5 까지는 combat risk 와 trade-off. 5-round survive 의 default WIN 과 별도 — 호송 안 해도 default WIN 가능.

### 4.2 Civilian token entity (`src/feature/grid_battle/civilian_token.gd`)

```gdscript
class_name CivilianToken
extends RefCounted

enum State { IDLE = 0, ESCORTED = 1, SAVED = 2 }

var token_id: int = -1
var state: State = State.IDLE
var grid_cell: Vector2i = Vector2i.ZERO  # IDLE 상태일 때 의 cell
var carrier_unit_id: int = -1            # ESCORTED 상태일 때 의 unit_id, IDLE/SAVED 시 -1

static func make(id: int, initial_cell: Vector2i) -> CivilianToken:
    var t := CivilianToken.new()
    t.token_id = id
    t.grid_cell = initial_cell
    return t
```

순수 data Resource — visualization 은 별도 (Polygon2D 또는 CharacterBody2D — 별도 commit).

### 4.3 Visualization (separate commit — Section 5 Step 5)

- IDLE token: small civilian icon (placeholder polygon — 회색 figure) at grid cell. Gemini chibi 천장 제약으로 polygon placeholder 만 (asset spec deferred).
- ESCORTED token: carrier unit 위에 small overlay marker (e.g., 작은 figure trailing).
- SAVED token: despawn animation (~0.3s fade) + counter HUD pulse.

본 spec 은 visualization 의 *behaviour* 만 specify. Pixel-level art 는 art-director domain (deferred).

### 4.4 fate_data wiring (no schema change)

`grid_battle_controller.gd:3244` `"civilians_escorted": _fate_civilians_escorted` 는 이미 emit. 신규 변경: increment site (§3.3). fate_data emit shape 변경 없음 → HiddenConditionEvaluator + DestinyBranchJudge + Beat 8 routing 모두 기존 path 그대로 통과 (✓ scaffold reuse).

## 5. Implementation Order (commits)

| # | Commit | Scope | 의존 |
|---|--------|-------|------|
| 1 | `design: ch05 civilian evacuation quick-spec` | 본 doc | — |
| 2 | `docs: ADR-0022 civilian system (stranded escort tokens)` | `docs/architecture/ADR-0022-civilian-system.md` 신규 + ADR-0017 minor amendment block | commit 1 |
| 3 | `data: ch05 civilian_config + ChapterDefinition schema extension` | `chapter_definition.gd` +1 field + ch05 json | commit 2 |
| 4 | `impl: civilian token entity + state machine + pickup wiring` | `civilian_token.gd` 신규 + GridBattleController fate wiring | commit 3 |
| 5 | `impl: civilian visualization (placeholder polygon + escort overlay)` | grid_battle layer 신규 visualization node + ChapterVisuals 통합 | commit 4 |
| 6 | `test: civilian sentinel tests + ch05 integration` | unit (state machine, config presence) + integration (★ trigger e2e) | commits 3-5 |

**본 세션 scope**: commits 1-4 (design + ADR + first impl arc — 데이터 + entity + counter wiring). Visualization (commit 5) + integration test (commit 6) 다음 세션. Plan §11 Step 3 의 4-6 세션 중 본 세션 ~50%.

## 6. Acceptance Criteria

- [ ] **AC-1**: `design/quick-specs/ch05-civilian-evacuation.md` 존재, 8 sections 완성.
- [ ] **AC-2**: `docs/architecture/ADR-0022-civilian-system.md` Accepted status, ADR-0017 §Amendment 블록 추가.
- [ ] **AC-3**: `ChapterDefinition.civilian_config: Dictionary` field 추가, default `{}`.
- [ ] **AC-4**: ch05 chapter JSON 의 `civilian_config.positions` = 5 entries `[[3,2],[5,3],[4,5],[4,7],[6,6]]`, `evacuate_zone_max_col` = 0.
- [ ] **AC-5**: `CivilianToken` RefCounted class 신규, State enum {IDLE, ESCORTED, SAVED}, factory `make()`.
- [ ] **AC-6**: GridBattleController chapter init 시 civilian_config 읽고 N token spawn at IDLE state.
- [ ] **AC-7**: Player turn-end 시 player unit 8-neighbor adjacency check, IDLE token 발견 시 ESCORTED bind (carrier capacity 1 enforcement).
- [ ] **AC-8**: Carrier movement → col <= evacuate_zone_max_col 도달 시 SAVED transition + `_fate_civilians_escorted += 1`.
- [ ] **AC-9**: Carrier death (HP<=0) → ESCORTED token IDLE 회귀, carrier last cell (or nearest non-occupied non-FIRE 4-neighbor).
- [ ] **AC-10**: ch05 ★ branch path end-to-end — 3+ civilian SAVE → fate_data `civilians_escorted >= 3` → HiddenConditionEvaluator true → DestinyBranchJudge route to `WIN_xinye_civilians_saved` (existing scaffold).
- [ ] **AC-11**: 1954+ tests PASS 유지 + 신규 sentinel tests 5+ (Section 7).
- [ ] **AC-12**: 기존 22 chapters (ch01-ch16 + Wei ch01-ch05 + mvp_wei chapters) civilian_config 없이 정상 작동 (regression sentinel).

## 7. Test Plan

**신규 unit tests** (`tests/unit/feature/grid_battle/`):
1. `test_civilian_token_factory_initializes_idle_with_cell` — `CivilianToken.make(1, Vector2i(3,2))` → token_id=1, state=IDLE, grid_cell=(3,2), carrier_unit_id=-1.
2. `test_civilian_token_state_transitions_valid_idle_to_escorted` — bind carrier_unit_id=0 → state=ESCORTED, carrier_unit_id=0.
3. `test_civilian_token_state_transitions_escorted_to_saved` — col <= 0 → state=SAVED, carrier_unit_id=-1.
4. `test_civilian_token_state_transitions_carrier_death_returns_idle` — carrier death → state=IDLE, grid_cell=last_cell, carrier_unit_id=-1.

**신규 sentinel tests** (`tests/unit/data/`):
5. `test_ch05_civilian_config_5_tokens_present` — ch05 `civilian_config.positions` length == 5, contains exact `[3,2]`/`[5,3]`/`[4,5]`/`[4,7]`/`[6,6]`.
6. `test_ch05_civilian_config_evacuate_zone_col_0` — `civilian_config.evacuate_zone_max_col == 0`.
7. `test_other_chapters_have_empty_civilian_config` — ch01-ch04, ch06-ch16 모두 `civilian_config == {}` (regression sentinel).

**신규 integration tests** (`tests/integration/grid_battle/`):
8. `test_civilian_pickup_on_player_end_turn_adjacency` — fixture: player unit at (3,3), token at (3,2) IDLE. Player turn end → token state=ESCORTED, carrier_unit_id=player.
9. `test_civilian_save_on_carrier_reaches_evacuate_zone` — fixture: carrier at (1, 3) carrying token. Move to (0, 3) → token state=SAVED, `_fate_civilians_escorted == 1`.
10. `test_ch05_three_civilians_saved_triggers_hidden_branch` — full ch05 fixture, 3 tokens force-SAVED, WIN outcome → DestinyBranchJudge resolves to `WIN_xinye_civilians_saved` branch_path_id.

**Regression baseline**: 1954 (current) + 10 신규 = 1964 PASS target. Commits 4 + 6 의 cumulative test deltas. Commit 4 (impl) 가 unit + sentinel tests (1-7) cover, Commit 6 integration tests (8-10) 별도 commit.

## 8. Risks / Open Questions

| ID | Question | Default 답 | 결정 시점 |
|----|----------|-----------|-----------|
| OQ-1 | Single-token-per-carrier OR multi-token (e.g. carrier 가 2 token 동시 escort)? | **Single (1/carrier)** — UI 단순 + narrative "한 아이를 어깨에 메고" 결과 같음 | Spec 확정 시 — 본 spec 으로 잠금 |
| OQ-2 | Carrier 사망 시 token 처리 — last cell IDLE return vs original spawn return vs LOST (counter -1)? | **Last cell IDLE return** — recoverable. LOST 는 너무 punitive (★ 시도가 binary fail). | Spec 확정 시 — 본 spec 으로 잠금 |
| OQ-3 | IDLE token cell occupancy — player unit walk-through OK? OR block movement? | **Walk-through OK** — pickup 은 end-of-turn adjacency 로만 trigger | Spec 확정 시 — 본 spec 으로 잠금 |
| OQ-4 | Token visualization detail — placeholder polygon 정확한 shape (gray figure / dot / "民" 한자)? | **Gray figure polygon** (`PolygonPrimitive` 또는 ColorRect) — asset spec deferred | Commit 5 visualization commit 시점 |
| OQ-5 | Escort overlay marker on carrier — 작은 figure trailing vs HUD badge vs token icon on unit polygon? | **Small figure trailing** (carrier polygon 옆 ~16px) — felt + KISS | Commit 5 visualization 시점 |
| OQ-6 | Multi-civilian SAVED 동시 (한 turn 에 carrier 가 col 0 도달 후 다른 carrier 도 도달) — emit order? | **unit_id ascending order, separate increments** — deterministic | Spec 확정 시 — 본 spec 으로 잠금 |
| OQ-7 | Enemy unit 이 IDLE token cell 진입 시 처리 — pickup blocked? OR token "lost" (counter cap 감소)? | **Pickup blocked only** — enemy 는 token 영향 없음 (passive). LOST 거부 (§OQ-2 일치) | Spec 확정 시 — 본 spec 으로 잠금 |
| OQ-8 | 5 token positions tuning — playtest 후 조정 가능? | **Yes — Open**, balance-tuning candidate post-impl manual test | Commit 4 후 manual playtest 시 |

---

> **Authoring note**: per `.claude/rules/design-docs.md` and S78 운영관찰 (incremental authoring batch rule), 본 spec 은 핵심 2 결정 (civilian model = stranded token + scope = design→ADR→first impl arc) 이 spec authoring 전 잠금되어 batch authoring 진행. ADR-0022 (Civilian System) 와 ADR-0017 §Amendment block 가 same-patch follow-up (commit 2).
