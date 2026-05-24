# Quick Design Spec: ch01 Vertical-Slice Uplift — 도원결의의 첫 무게

**Type**: Modification (ch01 한정 — lore + tension + Beat 8 seed)
**System**: Scenario data (ch01) + 황건적 hero records (신규)
**Date**: 2026-05-24
**Anchor doc**: `design/narrative/branch-distribution-plan.md` §8 (ch01 Redefinition)
**GDD Reference**:
  - `design/gdd/game-concept.md` — Pillar 4 (삼국지의 숨결) — ch01 첫 felt
  - `design/gdd/destiny-branch.md` CR-13 — Ch1 priming-null (분기 추가 거부)
  - `design/gdd/scenario-progression.md` — ChapterDefinition schema
  - `design/gdd/hero-database.md` — hero record schema

---

## 1. Change Summary

ch01 (도원결의·황건적 토벌) 의 enemy roster 를 위(魏) 4 장수 → 황건적 4 인 으로 교체하고, `enemy_atk_mult` 0.7 → 0.95 + chokepoint 보강으로 긴장감을 raise 하고, Beat 8 default-WIN prose 마지막에 ch05 ★ 를 미세하게 foreshadow 하는 1 sentence 를 추가한다. **분기는 추가하지 않음** — `destiny-branch.md` CR-13 의 Ch1 priming-null architecture 정합. ch01 = "약속의 무게" 챕터의 implementation.

## 2. Motivation

`design/gdd/game-concept.md` 의 3 pillar (형세의 전술 / 운명은 바꿀 수 있다 / 삼국지의 숨결) 가 현 ch01 에서 felt 되지 않는다:
- **삼국지의 숨결 (Pillar 4)** 위반: ch01 의 Beat 1 prose 는 "중평 원년 봄 · 탁군" + 황건적의 난 + 도원결의 motif 인데, `enemy_roster` 는 위(魏) 4 장수 (wei_005 하후돈 / wei_006 장요 / wei_007 우금 / wei_008 허저). 중평 원년에 등장 불가능한 인물들. prose 와 전장 사이 시대 불일치 — 첫판 첫 felt 가 dissonance.
- **형세의 전술 (Pillar 1)** 약화: `enemy_atk_mult = 0.7` (적 30% 깎임) + full-HP roster + chokepoint 2 칸만. 첫판 = relaxed tutorial. "한 수만 잘못 두면 무너진다" 의 형세 감각이 첫판부터 없음.
- **운명은 바꿀 수 있다 (Pillar 2)** 의 약속 부재: ch01 = priming-null 은 architecture 정합 (CR-13). 그러나 plan §8 가 요청한 "Beat 8 의 ch05 seed sentence" 가 현재 prose 에 없음 — ch05 ★ (백성 evacuation) 의 emotional anchor 가 미리 sourced 되지 않으면 ch05 도착 시 sudden 함.

본 spec 은 plan doc §8 의 3 의무 ("Lore 정합 / 긴장감 mechanical / Beat 8 의 ch05 seed") 를 implementation level 로 명세한다.

## 3. Design Delta (3 obligations)

### 3.1 Lore 정합 — 위 → 황건적 roster

**As-is**: `ch01.enemy_roster` = wei_005 / wei_006 / wei_007 / wei_008 (위 5명 hero records 중 4명). 중평 원년 시기 등장 불가.

**To-be**: 황건적 4 인 (정원지 / 등무 / 손중 / 황소) hero records 신규 작성. ch01 enemy_roster 가 이 4 인을 가리키도록 변경. 다른 챕터 (ch02+) 의 위 장수 roster 는 영향 없음 — `wei_005`~`wei_008` hero records 보존.

### 3.2 긴장감 mechanical — tuning

**As-is**: `enemy_atk_mult = 0.7`, chokepoints = `[[7,4],[8,4]]` (2 칸), 7-turn turn-limit 없음.

**To-be**:
- `enemy_atk_mult` 0.7 → **0.95** — 첫판부터 "데미지가 무겁다" 의 felt
- chokepoints 추가 — 3-4 칸 (예: `[[5,4],[6,4],[7,4],[8,4]]` 도로 4 칸 일렬). 형세의 *흐름* 을 만들 수 있는 길이.
- turn-limit **optional** (open question §8) — 7 턴 안에 종결 않으면 default-LOSS prose. 황건 증원 narrative 가 hard time pressure 로 felt. 본 spec 의 default 는 *적용 안 함* (단순 유지). user 가 채택 시 §8 open question 으로.

### 3.3 Beat 8 의 ch05 seed sentence

**As-is** (현재 `ch01.beat8.win_taoyuan_oath_held` body, 마지막 3 sentence):
> 제1회가 기록하는 도원결의의 세 형제는 이날을 출발점으로 삼았다. 형제의 이름이 한 줄에 묶인 그 맹세가 — 황건적의 함성보다 더 오래 남을 것임을 그들은 아직 알지 못했다.

**To-be**: 위 마지막 sentence 직후에 ch05 ★ seed 1 sentence 추가:
> 그리고 — 이 형제의 칼이 백성을 지킬 날이, 신야의 흙길 위에서 따로 찾아올 것임도 그들은 아직 알지 못했다.

이 sentence 가 ch05 (신야 화공) 의 ★ trigger "백성 evacuation" 의 emotional anchor 를 미리 sourced. 사용자가 ch05 도착 시 ch01 의 sentence 가 *기억 되었다* 의 callback. **★ 분기 자체는 ch01 에 추가 안 함** (priming-null 유지).

## 4. New Rules / Values

### 4.1 황건적 hero records (신규 4 개)

| hero_id | name_ko | 표 anchor (三國演義) | might | hp_seed | command | agility | default_class (UnitClass enum) |
|---------|---------|----------------------|-------|---------|---------|---------|--------------------------------|
| `yel_001_cheng_yuanzhi` | 정원지 | 제1회 — 관우 표적 (도원결의 후 첫 적장) | 70 | 75 | 55 | 60 | 1 (INFANTRY) — 보병 두목 |
| `yel_002_deng_mao` | 등무 | 제1회 — 장비 표적 (정원지의 부장) | 65 | 70 | 50 | 65 | 0 (CAVALRY) — 기마 부장 |
| `yel_003_sun_zhong` | 손중 | 제2회 — 황건 잔당 두목 | 60 | 80 | 60 | 50 | 1 (INFANTRY) — 방패 보병 |
| `yel_004_huang_shao` | 황소 | 제2회 — 황건 잔당 | 55 | 70 | 55 | 70 | 2 (ARCHER) — 궁병 |

- **Faction**: `HeroFaction.QUNXIONG` (3) 재사용 — 별도 enum 추가 없음 (palette 도 QUN 색조 사용 가능). 만약 황건 separate enum 필요 시 §8 OQ-1.
- **Stat 수준**: 위 4 장수 (might 75-92) 대비 *낮음* (might 55-70). 황건은 잡병 — 무위가 아닌 *수* 와 *지형 활용* 으로 위협. canonical 정합.
- **Skill set**: MVP 첫판 simplification — 각 yel_NNN 의 `innate_skill_ids` 는 empty array `[]`. 기본 attack 만. 첫판 = 시스템 학습 단계, skill complexity 없음.
- **Portrait / sprite**: placeholder ID (`portrait_yel_<name>` / `sprite_yel_<name>`) — asset 미작성 시 fallback 표시. Gemini chibi 천장 제약 (asset 생성 불가) 명시.

### 4.2 ch01 scenario data 변경

`assets/data/scenarios/shu_canon_main.json` 의 ch01 chapter 내 변경:

```json
{
  "enemy_roster": [
    {"unit_id": 2, "hero_id": "yel_001_cheng_yuanzhi", "archetype": "aggressor"},
    {"unit_id": 3, "hero_id": "yel_002_deng_mao",      "archetype": "skirmisher"},
    {"unit_id": 4, "hero_id": "yel_003_sun_zhong",     "archetype": "holder"},
    {"unit_id": 5, "hero_id": "yel_004_huang_shao",    "archetype": "skirmisher"}
  ],
  "enemy_atk_mult": 0.95,
  "chokepoints": [[5,4],[6,4],[7,4],[8,4]]
}
```

다른 ch01 fields 는 변경 없음 (`branch_table` 유지 = `WIN_default` + `LOSS_default` 만 — priming-null). `deployment_positions_default` 도 기존 그대로 (적은 동쪽 col 8-10 배치).

### 4.3 Beat 8 default-win prose seed sentence

`assets/data/story/*.json` 의 `ch01.beat8.win_taoyuan_oath_held.body` 마지막에 1 sentence append (§3.3 의 to-be sentence).

`ch01.beat8.loss_taoyuan_oath_broken` 는 변경 없음 (default-loss 는 ch05 seed 부적합 — 첫 패배 직후 ch05 의 미래 약속을 던지면 register dissonance).

`ch01` 의 banter (battle_start / outcome_win 의 by_chapter override) 는 S76 에서 작성된 26 lines 보존 — 이번 spec 의 변경 없음. (단 황건적 적측 voice 는 §8 OQ-2 — 위 적측 voice (S76 작성된 wei_001/005/006 등) 가 ch01 에서 더 이상 발화되지 않음, 황건 적측 voice 신규 작성 여부 결정 필요.)

## 5. Implementation Order (commits)

| # | Commit | Scope | 의존 |
|---|--------|-------|------|
| 1 | `data: ch01 황건적 4 hero records 신규 (yel_001-004)` | `assets/data/heroes/heroes.json` +4 records | — |
| 2 | `data: ch01 roster swap (위 → 황건) + tuning (atk_mult 0.95, chokepoint 4칸)` | `assets/data/scenarios/shu_canon_main.json` ch01 chapter modify | commit 1 |
| 3 | `narrative: ch01 Beat 8 default-WIN ch05 seed sentence 추가` | `assets/data/story/*.json` `ch01.beat8.win_taoyuan_oath_held` body modify | — (병행 가능) |
| 4 | `test: ch01 황건 roster + tuning regression sentinel` | 신규 test 2-3 개 (§7) | commits 1-3 |
| 5 | (선택) `narrative: 황건 적측 voice 8 lines (4 적장 × battle_start + outcome_loss)` | `assets/data/heroes/hero_banter.json` +8 entries | §8 OQ-2 채택 시 |

총 4-5 commits, ~1-2 세션.

## 6. Acceptance Criteria

- [ ] **AC-1**: `assets/data/heroes/heroes.json` 에 `yel_001_cheng_yuanzhi` / `yel_002_deng_mao` / `yel_003_sun_zhong` / `yel_004_huang_shao` 4 hero records 존재. faction = 3 (QUNXIONG). innate_skill_ids = `[]`.
- [ ] **AC-2**: ch01 `enemy_roster` 가 4 yel_NNN hero_id 만 가리킴. 위 hero_id (`wei_*`) 가 ch01 에 나타나지 않음.
- [ ] **AC-3**: ch01 `enemy_atk_mult == 0.95` (정확값). chokepoints 가 4 칸 (length 4) 이고 `[[5,4],[6,4],[7,4],[8,4]]` 포함.
- [ ] **AC-4**: ch01 `branch_table` 에 hidden 또는 ★ branch 가 **추가되지 않음** — keys 는 `WIN_default` + `LOSS_default` 정확히 2 개 (priming-null regression).
- [ ] **AC-5**: `ch01.beat8.win_taoyuan_oath_held.body` 가 "신야의 흙길" 또는 "백성을 지킬 날" substring 을 포함 (ch05 seed sentence 추가됨).
- [ ] **AC-6**: 기존 1949+ tests PASS 유지. 신규 sentinel tests 3 개 추가 (§7).

## 7. Test Plan

**신규 unit tests** (`tests/unit/data/`):
1. `test_ch01_roster_is_yellow_turban` — ch01 enemy_roster 의 모든 hero_id 가 "yel_" prefix 확인.
2. `test_ch01_tuning_values_aligned` — `enemy_atk_mult == 0.95` + chokepoint length == 4 정확값 assertion.
3. `test_ch01_priming_null_branch_table` — `branch_table.keys()` == `{"WIN_default", "LOSS_default"}` 정확 (★ 추가 거부 regression sentinel).

**신규 narrative-data test** (`tests/unit/narrative/`):
4. `test_ch01_beat8_win_contains_ch05_seed` — `ch01.beat8.win_taoyuan_oath_held.body` substring 확인.

**Regression**: 기존 1949 PASS + 신규 4 tests = 1953+ PASS target. ch01 관련 기존 tests (scenario_runner_chapter_1_test 등) 모두 PASS 유지 — roster 변경이 logic path 에 영향 안 미침 (enemy hero_id 는 data, scenario_runner 는 unit_id 만 사용).

## 8. Risks / Open Questions

| ID | Question | Default 답 | 결정 시점 |
|----|----------|-----------|-----------|
| OQ-1 | 황건적 HeroFaction enum 별도 추가? (`HeroFaction.YELLOW_TURBAN = 5`) | **No** — QUNXIONG (3) 재사용 | implementation 시 godot-specialist 검토 |
| OQ-2 | 황건 적측 voice 8 lines (4 적장 × battle_start + outcome_loss) 신규 작성? | **Yes (권장)** — S76 작성된 위 적측 voice 가 ch01 에서 정지됨, 황건 적측 voice 가 없으면 ch01 에서 적측 발화 0 | spec 확정 후 narrative-director spawn |
| OQ-3 | 7-turn turn-limit 적용? (default-LOSS 의 hard time pressure) | **No (default)** — 단순 유지, design test 통과 명시 안 됨 | user 추가 의견 |
| OQ-4 | civilian terrain feature (적이 마을 칸 도달 시 LOSS prose variant) ch01 에 도입? | **No** — 그건 ch05 의 ★ trigger 영역, ch01 은 priming-null 유지 | plan §8 의 ch05 ★ design 시점 |
| OQ-5 | 황건 hero 의 portrait/sprite asset 작성? | **No (deferred)** — Gemini chibi 천장 제약. fallback placeholder 표시. asset spec 만 작성. | Full Vision asset milestone |

---

> **Authoring note**: skeleton-first per `.claude/rules/design-docs.md`; sections filled incrementally with user approval. `TBD` = pending.
